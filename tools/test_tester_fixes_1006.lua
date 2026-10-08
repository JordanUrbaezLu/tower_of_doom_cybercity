-- tools/test_tester_fixes_1006.lua — the lead tester's Oct 4-6 2026 list, HUD half (v19.76).
-- EXECUTES the real HUD Lua under Lua 5.1 (lupa) with a RECORDING mock:
--   7   the King bar (tod_upgrade.lua): hidden until the fight, the fill and the
--       trailing chunk, the floor gauge + luck bar step aside and come back
--   8   the dual-wield clip (AetheriumLoadout.lua): BOTH hands, falling on either
--       gun's shot; the doubled fallback only when the engine has no off-hand model
--   10  the scoreboard ROUND header (AetheriumScoreboard.lua): follows tod_round
--       live, and at game over shows exactly the banner's number
-- (9, the Mage badge above its tile, is test_mage_hud.lua.)
-- Run: python -c "from lupa.lua51 import LuaRuntime; LuaRuntime().execute(open(r'tools/test_tester_fixes_1006.lua', encoding='utf-8').read())"
local noop=function() end
local elements={}
local methods={}
local notifySubs={}
local modelSubs={}
local modelValues={}
local notifyData=nil
local function newElement()
    local e=setmetatable({children={}, handlers={}, alpha=1, sv={}}, {__index=function(t,k)
        if methods[k] then return methods[k] end
        local cls=rawget(t,'todClass')
        if cls and cls[k] ~= nil then return cls[k] end
        if k:match('^set') or k:match('^make') or k:match('^link') or k:match('^Add') then return noop end
    end})
    elements[#elements+1]=e
    return e
end
function methods:addElement(e) self.children[#self.children+1]=e; e.parent=self end
function methods:getParent() return self.parent end
function methods:getFirstChild() return self.children[1] end
function methods:getNextSibling()
    if not self.parent then return nil end
    for i,e in ipairs(self.parent.children) do if e==self then return self.parent.children[i+1] end end
end
function methods:close() self.closed=true end
function methods:setAlpha(a) self.alpha=a end
function methods:setTopBottom(a,b,t,bt) self.tb={a,b,t,bt} end
function methods:setLeftRight(a,b,l,r) self.lr={a,b,l,r} end
function methods:setImage(i) self.image=i end
function methods:setRGB(r,g,b) self.rgb={r,g,b} end
function methods:setShaderVector(i,x) self.sv[i]=x end
function methods:beginAnimation(name,ms) self.anim={name=name,ms=ms} end
function methods:completeAnimation() end
function methods:registerEventHandler(k,v) self.handlers[k]=v end
function methods:processEvent(e) if self.handlers[e.name] then return self.handlers[e.name](self,e) end end
function methods:subscribeToGlobalModel(c,root,name,fn) if name=='scriptNotify' then notifySubs[#notifySubs+1]=fn end end
function methods:subscribeToModel(m,fn) if m then modelSubs[m]=modelSubs[m] or {}; table.insert(modelSubs[m],fn) end end
function methods:mergeStateConditions() end
function methods:getOwner() return 0 end
function methods:updateDataSource() end
function methods:restoreState() return true end
function methods:playSound() end
function methods:getLocalLeftRight() return true,false,0,80 end
function methods:getLocalTopBottom() return true,false,0,20 end
function methods:setClass(c) rawset(self,'todClass',c) end
local function enums() return setmetatable({}, {__index=function(t,k) local v=enums(); rawset(t,k,v); return v end}) end
Enum=enums()
local NO_DW_MODEL=false
Engine=setmetatable({
    Localize=function(s) return s end, GetModelForController=function() return 'ctrl' end,
    GetModel=function(m,k)
        if NO_DW_MODEL and k=='currentWeapon.ammoInDWClip' then return nil end
        return tostring(m)..'.'..tostring(k)
    end,
    CreateModel=function(m,k) return tostring(m)..'.'..tostring(k) end,
    GetModelValue=function(m) local v=modelValues[m]; if v==nil then return 0 end; return v end,
    IsInGame=function() return true end, GetCurrentMap=function() return 'zm_tower_of_doom' end,
    GetClientNum=function() return 0 end,
}, {__index=function() return noop end})
DataSources={}
DataSourceHelpers={ListSetup=function(_,fn) return fn end}
function ListHelper_SetupDataSource(_,fn) return fn end
CoD={Menu={NewForUIEditor=newElement}, TweenType={Linear=0}, isZombie=true, TodOwned={}, TodClass=1, TodClassTier=1,
     Zombie={CommonHudRequire=noop}, UsermapName='Tower of Doom'}
CoD.Menu.SetButtonLabel=noop; CoD.Menu.UpdateButtonShownState=noop
CoD.GetScriptNotifyData=function() return notifyData end
LUI={UIElement={new=newElement}, UIImage={new=newElement}, UIText={new=newElement}, UIList={new=newElement}, UITimer={new=newElement}, createMenu={}}
function LUI.OverrideFunction_CallOriginalSecond(e,key,fn)
    local old=e[key]; e[key]=function(...) fn(...); if old then return old(...) end end
end
function InheritFrom() return {} end
function RegisterImage(s) return s end
function IsPC() return true end
function IsGamepad() return false end
function IsInGame() return true end
function IsModelValueEqualTo() return false end
function RegisterOpenedMenu() end
function IsPrimaryController() return true end
require=function() end
LUI.UIImage.GetCachedMaterial=function(s) return s end

local function notify(name, data)
    notifyData=data
    modelValues.notify=name
    for _,fn in ipairs(notifySubs) do fn('notify') end
    modelValues.notify=nil
end
local function setModel(path, v)
    modelValues[path]=v
    for _,fn in ipairs(modelSubs[path] or {}) do fn(path) end
end
local function find(pred) for _,e in ipairs(elements) do if pred(e) then return e end end end
local function near(a,b) return math.abs(a-b)<1e-6 end

dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodGlyphMetrics.lua')
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodGlyphRow.lua')
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodGlyphText.lua')
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodUIOwnership.lua')
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodHealthTint.lua')

-- =============================================================================
-- 7. THE KING BAR
-- =============================================================================
CoD.TextWithBg={new=function()
    local e=newElement(); CoD.TodUIOwnership.Attach(e)
    e.Text=newElement(); e.Bg=newElement(); e:addElement(e.Text); e:addElement(e.Bg)
    return e
end}
Enum.UIVisibilityBit.BIT_SCOREBOARD_OPEN=1
Enum.UIVisibilityBit.BIT_GAME_ENDED=2
Enum.UIVisibilityBit.BIT_UI_ACTIVE=3
Enum.UIVisibilityBit.BIT_HUD_VISIBLE=4
dofile('ui/uieditor/menus/hud/AetheriumHud.lua')
dofile('ui/uieditor/menus/hud/tod_upgrade.lua')
notifySubs={}; modelSubs={}; elements={}
local Hud=LUI.createMenu.tod_upgrade(0)
local plate=find(function(e) return e.image=='i_tod_boss_bar' end)
assert(plate,'the King bar plate exists')
local King=plate.parent
local fills={}
for _,c in ipairs(King.children) do if c.image=='i_tod_boss_bar_fill' then fills[#fills+1]=c end end
assert(#fills==2,'a trail and a fill')
local trail, fill = fills[1], fills[2]
assert(trail.alpha<1 and fill.alpha==1,'the trail is the pale one, drawn first (under the fill)')
local luck=find(function(e) return e.image=='i_tod_luck_00' end)
assert(luck,'the luck bar')
local gaugeRoot=find(function(e) return e.image=='i_tod_gauge_dark' end).parent
assert(gaugeRoot and gaugeRoot~=Hud,'the floor gauge sits in its own container (one alpha hides the instrument)')
local gaugeKids=#gaugeRoot.children
-- dark + crown + base + summit + spire base, 25 + 35 lit cells, 4 pips, 25 + 35 down cells
assert(gaugeKids==5+25+35+4+25+35,'every gauge piece is inside it ('..gaugeKids..')')
assert(King.alpha==0,'no bar before the fight')
-- the layout is the art's (tools/boss_bar/build_boss_bar.py --check pins the numbers)
assert(plate.lr[3]==384 and plate.lr[4]==896 and plate.tb[3]==8 and plate.tb[4]==72,'plate at KB_X..KB_X+KB_W / KB_Y..KB_Y+KB_H')
assert(fill.lr[3]==447.5 and fill.lr[4]==884.5 and fill.tb[3]==41 and fill.tb[4]==60,'fill over the trough')
notify('tod_floor',{5,0})
assert(King.alpha==0,'another event never shows it')
notify('tod_king_bar',{1,1000})
assert(King.alpha==1 and luck.alpha==0 and gaugeRoot.alpha==0,'the fight: bar up, luck bar and floor gauge step aside')
assert(near(fill.sv[0],1) and near(trail.sv[0],1),'full health')
notify('tod_king_bar',{1,620})
assert(near(fill.sv[0],0.62),'the fill drops with him')
assert(near(trail.sv[0],0.62+(1-0.62)*0.6),'the trail holds where the hit took him from and closes 40% of the gap')
local t1=trail.sv[0]
notify('tod_king_bar',{1,620})   -- the heartbeat, no change
assert(trail.sv[0]<t1 and trail.sv[0]>=fill.sv[0],'the trail keeps closing on the heartbeat and never passes the fill')
for _=1,30 do notify('tod_king_bar',{1,620}) end
assert(near(trail.sv[0],0.62) or trail.sv[0]-0.62<1e-4,'the trail settles on the fill')
notify('tod_king_bar',{1,700})
assert(near(trail.sv[0],0.7),'a heal (never happens, but) pulls the trail up with the fill')
notify('tod_king_bar',{1,1400}); assert(near(fill.sv[0],1),'clamped high')
notify('tod_king_bar',{1,-5});  assert(near(fill.sv[0],0),'clamped low')
notify('tod_king_bar',{0,0})
assert(King.alpha==0 and luck.alpha==1 and gaugeRoot.alpha==1,'the win: bar gone, luck bar and floor gauge back')
notify('tod_king_bar',{0,0})
assert(King.alpha==0 and luck.alpha==1,'a repeated off is idempotent')
-- a respawned HUD (a fresh menu) picks the fight up on the next heartbeat
notifySubs={}; modelSubs={}
local Hud2=LUI.createMenu.tod_upgrade(0)
local King2=find(function(e) return e.image=='i_tod_boss_bar' and e~=plate end).parent
notify('tod_king_bar',{1,450})
assert(King2.alpha==1,'a rebuilt HUD shows the bar on the next push')
print('king bar: hidden until the fight, fill + trailing chunk, clamps, gauge + luck bar step aside and return, rebuilt HUD recovers - PASS')

-- =============================================================================
-- 8. THE DUAL-WIELD CLIP
-- =============================================================================
dofile('ui/uieditor/widgets/HUD/Mappings/AetheriumPerks.lua')
CoD.PowerUps={}
CoD.AetheriumWeapons={}
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodAbilityFeedback.lua')
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumPerkItem.lua')
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumPerksContainer.lua')
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumLoadout.lua')
local DIG={}
for d=0,9 do DIG['i_tod_hud_d'..d]=tostring(d) end
local function clipText(L)
    local vis={}
    for _,e in ipairs(L.clip_row.img) do if e.alpha==1 and DIG[e.image] then vis[#vis+1]=e end end
    table.sort(vis,function(a,b) return a.lr[3]<b.lr[3] end)
    local s=''
    for _,e in ipairs(vis) do s=s..DIG[e.image] end
    return s
end
local W, C, DW = 'ctrl.currentWeapon.weaponName', 'ctrl.currentWeapon.ammoInClip', 'ctrl.currentWeapon.ammoInDWClip'
local function build()
    notifySubs={}; modelSubs={}; modelValues={}
    return CoD.AetheriumLoadout.new({},0)
end
local L=build()
-- Tokyo & Rose: both hands full
setModel(W,'TOKYO & ROSE'); setModel(DW,8); setModel(C,8)
assert(clipText(L)=='16','both hands, 8 + 8 (got '..clipText(L)..')')
setModel(DW,7)
assert(clipText(L)=='15','THE BUG: a LEFT-hand shot counts now (was frozen at 16) - got '..clipText(L))
setModel(C,7)
assert(clipText(L)=='14','a right-hand shot counts')
setModel(DW,0); setModel(C,3)
assert(clipText(L)=='3','left empty, three in the right')
-- NEGATIVE CONTROL: the v19.75 formula read the right hand twice
assert(tostring(7*2)~='15','negative control: right x 2 = 14 where the pair holds 15')
-- Death and Taxes: a pair the old table never listed (it read ONE hand)
setModel(W,'DEATH & TAXES'); setModel(DW,6); setModel(C,6)
assert(clipText(L)=='12','an unlisted pair (the down pistol) shows both hands - got '..clipText(L))
setModel(DW,5)
assert(clipText(L)=='11','and counts its left hand')
-- a single gun: the engine sends -1 for the off hand
setModel(W,'MR6'); setModel(DW,-1); setModel(C,30)
assert(clipText(L)=='30','a single gun reads its own clip')
setModel(C,29); assert(clipText(L)=='29')
-- THE PAIR FLIPS TO ONE GUN (review): the switch's models land in no promised order,
-- so the single gun's first paint can still see the pair's old left hand. The learned
-- magazine must re-learn when the pair state flips, or the low-ammo flash (25% of the
-- LEARNED magazine) fires early for as long as the single gun is held.
local function flashing(L)
    local before=L.clip_row.img[1].rgb
    L:processEvent({name='tod_clip_pulse'})
    local r=L.clip_row.img[1].rgb
    local on=(r~=nil and near(r[2],0.16))
    if on then L:processEvent({name='tod_clip_pulse'}) end   -- back to the white phase
    return on
end
local function flipScenario(L)
    setModel(W,'TOKYO & ROSE'); setModel(DW,8); setModel(C,8)      -- learned 16
    setModel(W,'MR6'); setModel(C,10)                               -- DW still 8: one paint of 18
    setModel(DW,-1)                                                 -- now a single gun: 10
    assert(clipText(L)=='10','the single gun reads its own clip - got '..clipText(L))
    setModel(C,3)
    return flashing(L)
end
local L3=build()
assert(flipScenario(L3)==false,'THE EDGE: 3 of a 10 magazine is above 25% - no flash (the 18 learned on the stale paint is gone)')
setModel(C,2); assert(flashing(L3)==true,'2 of 10 does flash')
-- NEGATIVE CONTROL: without the pair-state reset the stale 18 holds the threshold at 4
do
    local f=io.open('ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumLoadout.lua','rb'); local src=f:read('*a'); f:close()
    local old,n=src:gsub('if curWeapon ~= clipWeapon or pair ~= clipPair then','if curWeapon ~= clipWeapon then')
    assert(n==1,'negative control built')
    assert(loadstring(old))()
    local L4=build()
    assert(flipScenario(L4)==true,'negative control: the old reset flashed 3 of 10 (learned 18 on the stale paint)')
    dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumLoadout.lua')   -- restore the real widget
end
-- THE FALLBACK: an engine with no off-hand model keeps the old doubling for the two listed pairs only
NO_DW_MODEL=true
local L2=build()
setModel(W,'TOKYO & ROSE'); setModel(C,8)
assert(clipText(L2)=='16','no model: the listed pair doubles, as before')
setModel(W,'MR6'); setModel(C,30)
assert(clipText(L2)=='30','no model: a single gun is untouched')
NO_DW_MODEL=false
print('dual wield: both hands summed and falling on EITHER gun (Tokyo & Rose, the down pistol), single guns untouched, doubled fallback without the model - PASS')

-- =============================================================================
-- 10. THE SCOREBOARD ROUND
-- =============================================================================
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumScoreboard.lua')
notifySubs={}; modelSubs={}; modelValues={}
local sb=CoD.AetheriumScoreboard.new({},0)
assert(sb.round_number and sb.round_number.getText,'the ROUND header is a glyph label')
-- the stock model flips FIRST, while the HUD's own round still reads the old one
CoD.TodRound=3
setModel('ctrl.gameScore.roundsPlayed',5)
assert(sb.round_number.getText()=='3','the header painted from the HUD round at the stock flip (the v19.75 state)')
notify('tod_round',{4})
assert(sb.round_number.getText()=='4','THE BUG: the header now follows the tod_round push that lands a beat later - got '..sb.round_number.getText())
notify('tod_round',{0})
assert(sb.round_number.getText()=='4','a nonsense round is refused')
-- game over: the board is forced and the banner says 4 - the header says 4
modelValues['ctrl.forceScoreboard']=1
notify('tod_gameover',{1,4,1})
assert(sb.todEndSurvived.getText()=='YOU SURVIVED 4 ROUNDS','the banner line')
assert(sb.round_number.getText()=='4','the header shows the banner\'s own number')
notify('tod_round',{5})
assert(sb.round_number.getText()=='4','a late push never moves the header off the end number while the board is forced')
-- the next game (the HUD survives map_restart; CoD.TodEndScreen is never cleared)
modelValues['ctrl.forceScoreboard']=0
notify('tod_round',{1})
assert(sb.round_number.getText()=='1','after a restart the header follows the new game again')
print('scoreboard round: follows tod_round live, refuses nonsense, matches the banner at game over, recovers after a restart - PASS')
print('tester fixes 1006 (HUD half): all checks PASS')
