-- tools/test_restart_menu.lua - PRESS THE RESTART BUTTONS (2026-10-01, docs/167
-- item 9 follow-up; user: "MY main issue people are complaining about is the
-- restart button ... I want to make sure we have this correct").
--
-- Loads the REAL AetheriumStartMenu.lua under Lua 5.1 (lupa), builds its button
-- list for every party shape, presses Restart Level / Restart Map / End Game and
-- records exactly which engine calls each press makes:
--   solo / split-screen (every human at this machine) -> the Aetherium kit's own
--     GoBack + Engine.Exec(controller, "map_restart") / the kit's disconnect lane;
--     NO server request (the v19.63 server lane froze a paused solo game)
--   online co-op host -> cl_paused 0 + StartMenuGoBack, THEN the server request
--     tod_go|restart / tod_go|end; NO console map_restart (it drops the teammate)
--   online co-op peer -> no Restart button; End Game = its own disconnect
-- plus: the host-machine dvar tod_party_remote decides before the first event,
-- nothing known at all (a teammate's machine) never runs the console restart,
-- and a restart clears the cached game-over flag.
-- The static contract (and 28 negative controls) is tools/test_coop_restart_lane.js.

local noop=function() end
local elements={}
local methods={}
local function newElement()
    local e=setmetatable({children={}, handlers={}}, {__index=function(_,k)
        if methods[k] then return methods[k] end
        if k:match('^set') or k:match('^make') or k:match('^subscribe') or k:match('^link') or k:match('^Add') then return noop end
    end})
    elements[#elements+1]=e
    return e
end
function methods:addElement(e) self.children[#self.children+1]=e; e.parent=self end
function methods:getParent() return self.parent end
function methods:close() self.closed=true end
function methods:registerEventHandler(k,v) self.handlers[k]=v end
function methods:completeAnimation() end
function methods:processEvent(e) if self.handlers[e.name] then return self.handlers[e.name](self,e) end end
function methods:getLocalLeftRight() return true,false,0,80 end
function methods:getLocalTopBottom() return true,false,0,20 end
function methods:beginAnimation() end
function methods:mergeStateConditions() end
local function enums() return setmetatable({}, {__index=function(t,k) local v=enums(); rawset(t,k,v); return v end}) end
Enum=enums()

-- THE RECORDER: every engine call a press can make.
local log={}
local dvars={}
local function rec(s) log[#log+1]=s end
Engine=setmetatable({
    Localize=function(s) return s end, GetModelForController=function() return 'ctrl' end,
    GetModel=function(m,k) return tostring(m)..'.'..tostring(k) end, CreateModel=function(m,k) return tostring(m)..'.'..tostring(k) end,
    GetModelValue=function() return 0 end, IsInGame=function() return true end,
    GetCurrentMap=function() return 'zm_tower_of_doom' end, GetClientNum=function() return 0 end,
    Exec=function(c,cmd) rec('exec:'..tostring(c)..':'..cmd) end,
    SendMenuResponse=function(c,m,r) rec('response:'..tostring(c)..':'..m..':'..r) end,
    SetDvar=function(k,v) rec('setdvar:'..k..'='..tostring(v)) end,
    DvarString=function(a,b) local k=b or a; return dvars[k] end,
    GetDvarString=function(k) return dvars[k] end,
}, {__index=function() return noop end})
DataSources={}
DataSourceHelpers={ListSetup=function(_,fn) return fn end}
function ListHelper_SetupDataSource(_,fn) return fn end
CoD={Menu={NewForUIEditor=newElement}, TweenType={Linear=0}, isZombie=true, TodOwned={}, TodClass=1, TodClassTier=1}
CoD.Menu.SetButtonLabel=noop; CoD.Menu.UpdateButtonShownState=noop
LUI={UIElement={new=newElement}, UIImage={new=newElement}, UIText={new=newElement}, UIList={new=newElement}, UITimer={new=newElement}, createMenu={}}
function LUI.OverrideFunction_CallOriginalSecond(e,key,fn) local old=e[key]; e[key]=function(...) fn(...); if old then return old(...) end end end
function InheritFrom() return {} end
function RegisterImage(s) return s end
function IsPC() return true end
function IsGamepad() return false end
function IsInGame() return true end
function RegisterOpenedMenu() end
function IsPrimaryController() return true end
function IsModelValueEqualTo() return false end
function PlayClip() end
require=function() end
-- the stock menu helpers the actions call, recorded
function GoBack(m,c) rec('GoBack:'..tostring(c)) end
function StartMenuGoBack(m,c) rec('StartMenuGoBack:'..tostring(c)) end
function RefreshLobbyRoom() end

dofile('ui/uieditor/menus/StartMenu/AetheriumStartMenu.lua')
local Buttons=DataSources.AetheriumStartMenuButtons
assert(type(Buttons)=='function','AetheriumStartMenuButtons datasource not built')

local menu=newElement()
local function setup(by, shared, dv)
    CoD.TodPartyBy=by; CoD.TodParty=shared; dvars=dv or {}
end
local function list(c)
    local out={}
    for _,b in ipairs(Buttons(c)) do out[b.models.displayText]=b.models.action end
    return out
end
local function press(c, name)
    local acts=list(c)
    assert(acts[name], 'no "'..name..'" button for controller '..c)
    log={}
    acts[name](nil, nil, c, nil, menu)
    return table.concat(log,' | ')
end
local function has(s, pat) return s:find(pat, 1, true) ~= nil end
local function kitRestart(s, c, why)
    assert(has(s,'GoBack:'..c) and has(s,'exec:'..c..':map_restart'), why..': expected the kit restart, got '..s)
    assert(not has(s,'tod_go|'), why..': the kit restart must not also ask the server: '..s)
    local gb=s:find('GoBack:'..c,1,true); local ex=s:find('exec:'..c..':map_restart',1,true)
    assert(gb<ex, why..': the kit closes the menu BEFORE map_restart: '..s)
    local mk=s:find('setdvar:tod_go_restart_mark=kit',1,true)
    assert(mk and mk<ex, why..': the kit restart must leave its log mark before map_restart: '..s)
end
-- The server lane (2026-10-01): the request FIRST on both lanes - the host
-- machine's dvar tod_go_request (the one that works at game over) and the menu
-- response - THEN unpause + StartMenuGoBack.
local function serverLane(s, c, what, why)
    local dv=s:find('setdvar:tod_go_request='..what,1,true)
    local rq=s:find('response:'..c..':StartMenu_Main:tod_go|'..what,1,true)
    local pz=s:find('setdvar:cl_paused=0',1,true); local gb=s:find('StartMenuGoBack:'..c,1,true)
    assert(dv and rq and pz and gb, why..': expected dvar tod_go_request + tod_go|'..what..' + unpause + StartMenuGoBack, got '..s)
    assert(dv<pz and dv<gb and rq<gb, why..': the request must go out BEFORE the menu closes: '..s)
    assert(not has(s,'map_restart'), why..': no console map_restart on the server lane: '..s)
end
local function leave(s, c, why)
    assert(has(s,'exec:'..c..':disconnect'), why..': expected the kit leave (disconnect), got '..s)
    assert(not has(s,'tod_go|'), why..': the kit leave must not ask the server: '..s)
end
local n=0
local function ok(msg) n=n+1; print('  PASS '..msg) end

-- 1. a solo game before its first party push: the host machine already has the
-- dvars (party_dvar_watch writes them at level start) -> Restart is the kit's
setup(nil, nil, {tod_party='1', tod_party_remote='0'})
kitRestart(press(0,'Restart Level'),0,'solo, only the host dvars'); ok('solo before any party push (host dvars only) -> kit restart')
-- 1b. nothing at all = a teammate's machine in its first seconds (a SetDvar never
-- reaches it): the button may show, but it only sends the request the server
-- ignores for a non-host - never a console map_restart on a teammate's PC
setup(nil, nil, {})
serverLane(press(0,'Restart Level'),0,'restart','nothing known'); ok('nothing known (teammate machine, first seconds) -> server lane, never the console restart')

-- 2. solo with the server's answer (host value 2)
setup({[0]={n=1,host=true,localOnly=true,go=false}}, nil, {})
kitRestart(press(0,'Restart Level'),0,'solo'); ok('solo -> kit restart')

-- 3. split-screen: BOTH local players see Restart, both use the kit restart
setup({[0]={n=2,host=true,localOnly=true,go=false},[1]={n=2,host=true,localOnly=true,go=false}}, {n=2,host=true,localOnly=true,go=false}, {})
kitRestart(press(0,'Restart Level'),0,'split-screen host'); kitRestart(press(1,'Restart Level'),1,'split-screen guest')
ok('split-screen host AND guest -> kit restart')

-- 4. online co-op host (host value 1): the server request after unpause + close
setup({[0]={n=2,host=true,localOnly=false,go=false}}, nil, {})
serverLane(press(0,'Restart Level'),0,'restart','online host'); ok('online co-op host -> unpause, close, tod_go|restart')

-- 5. online co-op peer (host value 0): no Restart at all
setup({[0]={n=2,host=false,localOnly=false,go=false}}, nil, {})
assert(list(0)['Restart Level']==nil,'an online peer must not get Restart'); assert(list(0)['Leave Game'],'the peer keeps Leave Game')
ok('online co-op peer -> no Restart button')

-- 6. before the first event, the host machine's dvar decides
setup(nil, nil, {tod_party='2', tod_party_remote='1'})
serverLane(press(0,'Restart Level'),0,'restart','host dvar says remote'); ok('dvar tod_party_remote=1 -> server lane')
setup(nil, nil, {tod_party='2', tod_party_remote='0'})
kitRestart(press(0,'Restart Level'),0,'host dvar says local'); ok('dvar tod_party_remote=0 -> kit restart')

-- 7. game-over menu, solo: Restart Map = kit; End Game = kit leave; the go flag clears
setup({[0]={n=1,host=true,localOnly=true,go=true}}, nil, {})
assert(list(0)['Return To Game']==nil,'game-over mode has no Return To Game')
kitRestart(press(0,'Restart Map'),0,'game-over solo'); assert(CoD.TodPartyBy[0].go==false,'restart must clear the cached game-over flag')
setup({[0]={n=1,host=true,localOnly=true,go=true}}, nil, {})
leave(press(0,'End Game'),0,'game-over solo End Game'); ok('game over, solo -> kit Restart Map / kit End Game, flag cleared')

-- 8. game-over menu, online host: both choices go to the server
setup({[0]={n=2,host=true,localOnly=false,go=true}}, nil, {})
serverLane(press(0,'Restart Map'),0,'restart','game-over online host'); assert(CoD.TodPartyBy[0].go==false,'server restart must clear the flag too')
setup({[0]={n=2,host=true,localOnly=false,go=true}}, nil, {})
serverLane(press(0,'End Game'),0,'end','game-over online host End Game'); ok('game over, online host -> tod_go|restart / tod_go|end')

-- 9. game-over menu, online peer: only End Game, its own disconnect
setup({[0]={n=2,host=false,localOnly=false,go=true}}, nil, {})
assert(list(0)['Restart Map']==nil,'an online peer must not get Restart Map')
leave(press(0,'End Game'),0,'game-over online peer'); ok('game over, online peer -> End Game leaves alone')

print(('restart menu test passed: %d cases, every press recorded against the real menu file'):format(n))
