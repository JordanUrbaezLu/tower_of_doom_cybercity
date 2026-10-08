-- docs/172 THE LEVEL PIPS: EXECUTE the real card panel (tod_upgrade.lua) under
-- Lua 5.1 (lupa) with a RECORDING mock, drive whole deals through it the way
-- _tod_upgrade_ui.gsc does (tod_upg_pips, the card fields, the reveal, the pick)
-- and assert what every dot ends up showing.
--   user: "you are level 2 and get a super card ... Fill Fill Purple Purple Empty"
-- Run: python -c "from lupa.lua51 import LuaRuntime; LuaRuntime().execute(open(r'tools/test_card_pips.lua', encoding='utf-8').read())"
local noop=function() end
local elements={}
local methods={}
local notifySubs={}
local modelSubs={}
local modelValues={}
local notifyData=nil
local function newElement()
    local e=setmetatable({children={}, handlers={}, alpha=1, anims={}}, {__index=function(t,k)
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
function methods:close()
    assert(not self.closed,'element closed twice')
    self.closed=true
    if self.parent then
        for i,e in ipairs(self.parent.children) do if e==self then table.remove(self.parent.children,i); break end end
        self.parent=nil
    end
end
function methods:setAlpha(a) self.alpha=a end
function methods:setTopBottom(a,b,t,bt) self.tb={a,b,t,bt} end
function methods:setLeftRight(a,b,l,r) self.lr={a,b,l,r} end
function methods:setImage(i) self.image=i end
function methods:setRGB(r,g,b) self.rgb={r,g,b} end
function methods:beginAnimation(name,ms,ei,eo,tt) self.anim={name=name,ms=ms,easeIn=ei,easeOut=eo,tween=tt}; self.anims[#self.anims+1]=name end
function methods:completeAnimation() self.completed=(self.completed or 0)+1; self.anim=nil end
function methods:registerEventHandler(k,v) self.handlers[k]=v end
function methods:processEvent(e) if self.handlers[e.name] then return self.handlers[e.name](self,e) end end
function methods:subscribeToGlobalModel(c,root,name,fn) if name=='scriptNotify' then notifySubs[#notifySubs+1]=fn end end
function methods:subscribeToModel(m,fn) modelSubs[m]=modelSubs[m] or {}; table.insert(modelSubs[m],fn) end
function methods:mergeStateConditions() end
function methods:getOwner() return 0 end
function methods:setClass(c) rawset(self,'todClass',c) end
local function enums() return setmetatable({}, {__index=function(t,k) local v=enums(); rawset(t,k,v); return v end}) end
Enum=enums()
Engine=setmetatable({
    Localize=function(s) return s end, GetModelForController=function() return 'ctrl' end,
    GetModel=function(m,k) return tostring(m)..'.'..tostring(k) end, CreateModel=function(m,k) return tostring(m)..'.'..tostring(k) end,
    GetModelValue=function(m) local v=modelValues[m]; if v==nil then return 0 end; return v end,
    IsInGame=function() return true end, GetCurrentMap=function() return 'zm_tower_of_doom' end,
    GetClientNum=function() return 0 end,
}, {__index=function() return noop end})
DataSources={}
DataSourceHelpers={ListSetup=function(_,fn) return fn end}
function ListHelper_SetupDataSource(_,fn) return fn end
CoD={Menu={NewForUIEditor=newElement}, TweenType={Linear=0, Elastic=1, Back=2, Bounce=3}, isZombie=true, TodOwned={}, TodClass=1,
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
require=function() end
LUI.UIImage.GetCachedMaterial=function(s) return s end

local function notify(name, data)
    notifyData=data
    modelValues.notify=name
    for _,fn in ipairs(notifySubs) do fn('notify') end
    modelValues.notify=nil
end
local function field(name, v)
    local path='ctrl.'..name
    modelValues[path]=v
    for _,fn in ipairs(modelSubs[path] or {}) do fn(path) end
end

dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodUIOwnership.lua')
CoD.TextWithBg={new=function()
    local e=newElement(); CoD.TodUIOwnership.Attach(e)
    e.Text=newElement(); e.Bg=newElement(); e:addElement(e.Text); e:addElement(e.Bg)
    return e
end}
dofile('ui/uieditor/menus/hud/tod_upgrade.lua')
local CP=CoD.TodCardPips
assert(CP and CP.Plan and CP.Info and CP.Decode and CP.Sync,'tod_upgrade.lua exposes CoD.TodCardPips')

-- ---- 1. the layout fits the art's own band, for every cap -------------------
local src=io.open('ui/uieditor/menus/hud/tod_upgrade.lua'):read('*a')
local function num(name) return tonumber(src:match('local '..name..' = ([0-9.]+)')) end
local CX, PITCH, USABLE, HALO = num('PIP_CX'), num('PIP_PITCH'), num('PIP_USABLE_W'), num('PIP_HALO_R')
assert(CX==384 and PITCH==58 and USABLE==428 and HALO==22.1,'the measured dot geometry')
for n=1,10 do
    local xs,k=CP.Plan(n)
    assert(#xs==n,'plan '..n..' places '..#xs)
    assert(math.abs((xs[1]+xs[n])/2-CX)<1e-9,'row '..n..' is centred on the card')
    assert(xs[1]-HALO*k>=CX-USABLE/2-1e-6 and xs[n]+HALO*k<=CX+USABLE/2+1e-6,'row '..n..' stays between the screws')
    if n<=7 then assert(k==1 and (n==1 or math.abs(xs[2]-xs[1]-PITCH)<1e-9),'rows up to 7 keep the art pitch and size') end
    if n>1 then assert(xs[2]-xs[1]>=2*HALO*k+3-1e-6,'row '..n..': halos never touch') end
    assert(k>=0.89,'row '..n..': dots never shrink below 89% ('..k..')')
end
print('layout: 1..10 dots centred, inside the band, art pitch up to 7, halos never touch - PASS')

-- ---- 2. the wire ------------------------------------------------------------
for _,c in ipairs({{6,5,2},{1,10,3},{24,3,1},{56,1,1},{63,15,15}}) do
    local d=CP.Decode(c[1]*256+c[2]*16+c[3])
    assert(d.dom==c[1] and d.max==c[2] and d.lvl==c[3],'decode round trip '..table.concat(c,'/'))
end
assert(CP.Decode(0)==nil and CP.Decode(nil)==nil,'an empty slot decodes to nil')
local gsc=io.open('scripts/zm/zm_tower_of_doom/_tod_upgrade_ui.gsc'):read('*a')
assert(gsc:find('#precache%( "eventstring", "tod_upg_pips" %)'),'GSC precaches tod_upg_pips')
assert(gsc:find('self LuiNotifyEvent%( &"tod_upg_pips", 2, a, b %)'),'GSC sends both slots in one event')
assert(gsc:find('return domain_id%( o%.domain %) %* 256 %+ mx %* 16 %+ lv;'),'GSC packs domain_id * 256 + max * 16 + levels')
local pc=gsc:find('function present_choice')
local pushAt=gsc:find('self pips_push%( opts %);',pc)
local showAt=gsc:find('self set_field%( "todUpgShow", 1 %);',pc)
assert(pushAt and showAt and pushAt<showAt,'the pips event goes out BEFORE the panel opens')
print('wire: round trip, precached, one event, sent before the panel opens - PASS')

-- ---- 3. what a card shows -----------------------------------------------------
local function info(dom,rar,cur,ev) return CP.Info(dom,rar,cur,ev) end
local i=info(6,2,2,{dom=6,max=5,lvl=2})                 -- the user's example
assert(i.n==5 and i.owned==2 and i.gain==2,'HEADSHOT Lv2 + SUPER = fill fill purple purple empty')
i=info(2,3,6,{dom=2,max=9,lvl=3}); assert(i.n==9 and i.owned==6 and i.gain==3,'the assault DR cap (9) comes off the wire')
i=info(2,3,1,nil); assert(i.n==10,'no wire: DOMAIN.max')
CoD.TodOwned={[2]={lvl=1,max=5}}
i=info(2,1,1,nil); assert(i.n==5 and i.gain==1,'no wire: the synced per-player cap beats DOMAIN.max')
i=info(2,1,1,{dom=7,max=3,lvl=1}); assert(i.n==5,'a wire value for another domain is ignored')
CoD.TodOwned={}
assert(info(6,3,15,{dom=6,max=5,lvl=0})==nil,'a DARK card gets no live row (it keeps its own)')
assert(info(0,1,0,nil)==nil and info(99,1,0,nil)==nil,'empty slot / unknown id: no row')
i=info(24,3,2,{dom=24,max=3,lvl=1}); assert(i.tier and i.n==3 and i.owned==1 and i.gain==1,'a TIER 2 card: hold 1 of 3, gain 1')
i=info(24,1,3,{dom=24,max=3,lvl=1}); assert(i.owned==2 and i.gain==1,'a TIER 3 card: hold 2 of 3, gain 1')
i=info(56,3,0,{dom=56,max=1,lvl=1}); assert(i.n==1 and i.gain==1,'MYSTICAL HANDS: an ULTIMATE frame paying one level')
i=info(1,3,9,nil); assert(i.n==10 and i.owned==9 and i.gain==1,'no wire near the cap: the gain clamps to the room left')
i=info(7,3,2,nil); assert(i.n==3 and i.gain==1,'MAG SIZE (cap 3) at Lv2: one dot of room')
i=info(6,3,4,{dom=6,max=3,lvl=3}); assert(i.n==4 and i.owned==4 and i.gain==0,'a cap below what is owned grows to hold it, never hides a level')
i=info(56,3,0,nil); assert(i.n==1 and i.gain==1,'no wire: MYSTICAL HANDS still shows one dot, not the frame\'s +3')
print('card info: user example, per-class cap, fallbacks, dark, tier, one-image card, clamps - PASS')

-- ---- 4. whole deals through the real panel -------------------------------------
notifySubs={}; modelSubs={}; modelValues={}
local panel=CoD.TodUpgradePanel.new({},0)
local rows=panel.todPipRows
assert(rows and rows.a and rows.b,'both cards build a pip row')
local A,B=rows.a,rows.b
local n=0; for _ in ipairs(A.root.children) do n=n+1 end
assert(n==18,'a row root holds 3 glows + 10 dots + 3 shines + 2 metronomes (got '..n..')')
assert(A.root.parent==panel,'the row hangs off the panel')
assert(A.glow[1].parent==A.root and A.body[1].parent==A.root,'children under the row root')
local idx={}; for k,e in ipairs(A.root.children) do idx[e]=k end
assert(idx[A.glow[3]]<idx[A.body[1]] and idx[A.body[10]]<idx[A.shine[1]],'draw order: glow under the dot, shine over it')
local function img(e) return e.image end
local function lit(P) local s={}; for k=1,10 do if P.body[k].alpha>0 then s[#s+1]=(P.body[k].image:gsub('i_tod_cardpip_','')) end end; return table.concat(s,' ') end
local function tick(e,name,interrupted) e:processEvent({name='transition_complete_'..name, interrupted=interrupted or false}) end

-- the server's present_choice, then its reveal
local HEADSHOT, DAMAGE, TIER = 6, 1, 24
local function deal(a, b)
    notify('tod_upg_pips',{a.dom*256+a.max*16+a.lvl, b and (b.dom*256+b.max*16+b.lvl) or 0})
    field('todUpgAD',0); field('todUpgAR',1); field('todUpgAL',a.cur)
    field('todUpgBD',0)
    if b then field('todUpgBR',1); field('todUpgBL',b.cur) else field('todUpgBR',0) end
    field('todUpgFocus',0); field('todUpgTime',15); field('todUpgHold',0); field('todUpgShow',1)
end
deal({dom=HEADSHOT,max=5,lvl=2,cur=2},{dom=DAMAGE,max=10,lvl=3,cur=4})
assert(lit(A)=='' and lit(B)=='','nothing before a card lands')
field('todUpgAR',2)                              -- slot A charges SUPER
assert(lit(A)=='','still a socket')
field('todUpgAD',HEADSHOT)                       -- slot A lands
assert(A.sig and A.seqOn and A.seq.anim and A.seq.anim.name=='tod_pip_seq','the landing starts the light-up')
assert(lit(A)=='','the row waits for the card face to open')
tick(A.seq,'tod_pip_seq')                        -- the row fades in with the face
assert(lit(A)=='owned owned empty empty empty','first the room: fill fill empty empty empty ('..lit(A)..')')
assert(A.body[1].anim and A.body[1].anim.name=='tod_pip_in','the row fades in')
tick(A.seq,'tod_pip_seq')                        -- the first added level lights
assert(lit(A)=='owned owned gain_super empty empty','one at a time ('..lit(A)..')')
assert(A.body[3].anim.name=='tod_pip_pop' and A.body[3].anim.tween==CoD.TweenType.Bounce,'it stamps in')
assert(A.glow[1].anim.name=='tod_pip_flash' and A.shine[1].anim.name=='tod_pip_flash','with a glow and core flash')
tick(A.seq,'tod_pip_seq','interrupted')
assert(lit(A)=='owned owned gain_super empty empty','an interrupted tick never advances the chain')
tick(A.seq,'tod_pip_seq')
assert(lit(A)=='owned owned gain_super gain_super empty','FILL FILL PURPLE PURPLE EMPTY ('..lit(A)..')')
assert(A.glow[2].image=='i_tod_cardpip_glow_super','the glow wears the rarity')
tick(A.seq,'tod_pip_seq')                        -- the rest, then the breathing
assert(not A.seqOn and A.pulseOn,'the light-up hands over to the breathing')
assert(A.beat.anim and A.beat.anim.name=='tod_pip_beat','the breath metronome runs')
for j=1,2 do
    local g=A.glow[j]
    assert(g.anim and g.anim.name=='tod_pip_breathe' and g.anim.easeIn and g.anim.easeOut,'dot '..j..' breathes, eased')
end
assert(A.glow[3].alpha==0,'only the added levels glow')
local hiA=A.glow[1].alpha
tick(A.beat,'tod_pip_beat')
assert(A.glow[1].alpha<hiA,'the breath swings back (in '..hiA..' out '..A.glow[1].alpha..')')
tick(A.beat,'tod_pip_beat')
assert(A.glow[1].alpha==hiA,'and again')
-- slot B: ULTIMATE onto DAMAGE Lv4 of 10
field('todUpgBR',3); field('todUpgBD',DAMAGE)
tick(B.seq,'tod_pip_seq'); tick(B.seq,'tod_pip_seq'); tick(B.seq,'tod_pip_seq'); tick(B.seq,'tod_pip_seq')
assert(lit(B)=='owned owned owned owned gain_ultimate gain_ultimate gain_ultimate empty empty empty','DAMAGE Lv4 + ULTIMATE: 4 cyan, 3 gold, 3 empty ('..lit(B)..')')
local w=B.body[1].lr[4]-B.body[1].lr[3]
assert(w<A.body[1].lr[4]-A.body[1].lr[3] and w>0.89*(A.body[1].lr[4]-A.body[1].lr[3]),'ten dots run slightly smaller')
tick(B.seq,'tod_pip_seq'); assert(B.pulseOn,'B breathes too')
-- input opens: ~7 Hz renders must not restart anything
local seqA, beatA = A.seq.completed or 0, A.beat.completed or 0
for r=1,20 do field('todUpgFocus',(r%2==0) and 1 or 2); field('todUpgHold',r%4) end
field('todUpgTime',14)
assert((A.seq.completed or 0)==seqA and (A.beat.completed or 0)==beatA and A.pulseOn,'20 focus renders left the breathing alone')
-- the cap arrives late for B (a re-sent event): settles instantly, no replay
notify('tod_upg_pips',{HEADSHOT*256+5*16+2, DAMAGE*256+9*16+3})
assert(lit(B)=='owned owned owned owned gain_ultimate gain_ultimate gain_ultimate empty empty','a late cap re-lays the row ('..lit(B)..')')
assert(not B.seqOn and B.pulseOn,'without replaying the light-up')
-- the pick: A taken, B passed over
field('todUpgFocus',0); field('todUpgTime',0); field('todUpgShow',2)
assert(lit(A)=='owned owned owned owned empty','the taken card: its new levels turn cyan ('..lit(A)..')')
assert(A.body[3].anim.name=='tod_pip_pop' and not A.pulseOn,'with a pop, and the breathing stops')
assert(not B.pulseOn and B.glow[1].alpha==0 and B.shine[1].alpha==0,'the passed card goes quiet')
assert(lit(B):find('gain_ultimate'),'and keeps showing what it offered')
field('todUpgShow',0)
assert(lit(A)=='owned owned owned owned empty','the dots stay up while the panel fades')
assert(A.sig==nil and not A.pulseOn,'the panel down: motion off, the next deal starts clean')
print('deal 1: fill/purple/empty, one-at-a-time light-up, breathing, quiet at 7 Hz, late cap, pick -> cyan - PASS')

-- deal 2: a lone card, REGULAR, on a domain the player does not own yet
deal({dom=HEADSHOT,max=5,lvl=1,cur=0},nil)
assert(lit(A)=='' and lit(B)=='','a new deal clears the last one before anything lands ('..lit(A)..'|'..lit(B)..')')
field('todUpgAR',1); field('todUpgAD',HEADSHOT)
tick(A.seq,'tod_pip_seq'); tick(A.seq,'tod_pip_seq')
assert(lit(A)=='gain_regular empty empty empty empty','REGULAR on a new domain: one white dot of five ('..lit(A)..')')
assert(lit(B)=='','no second card, no second row')
field('todUpgShow',0)

-- deal 3: a LOCKED promotion in slot B and a DARK card in slot A
CoD.TodTierNeed=10
deal({dom=HEADSHOT,max=5,lvl=0,cur=15},{dom=TIER,max=3,lvl=1,cur=2})
field('todUpgAR',3); field('todUpgAD',HEADSHOT)
field('todUpgBR',1); field('todUpgBD',TIER)
assert(lit(A)=='','a DARK card keeps its own baked row: no live dots')
assert(lit(B)=='' and B.seqOn,'the locked card waits for its face to open like any other')
tick(B.seq,'tod_pip_seq')
assert(B.locked and lit(B)=='owned gain_tier empty','the locked TIER 2 card: tier 1 held, tier 2 shown, room for 3 ('..lit(B)..')')
assert(not B.seqOn and not B.pulseOn and B.glow[1].alpha==0,'a locked card never lights or breathes')
assert(B.body[2].anim and B.body[2].anim.name=='tod_pip_in','it only fades in (no stamp)')
assert(B.body[1].rgb[1]==0.55 and B.body[2].rgb[3]==0.72,'and wears the locked card tint')
field('todUpgFocus',1)
assert(not B.pulseOn,'still quiet once input opens')
notify('tod_upg_pips',{HEADSHOT*256+5*16+0, TIER*256+4*16+1})   -- a late cap: the instant (non-landing) layout
assert(lit(B)=='owned gain_tier empty empty' and not B.pulseOn and not B.seqOn,'a locked card laid out instantly stays quiet ('..lit(B)..')')
field('todUpgShow',0)
CoD.TodTierNeed=0
-- deal 4: the same card unlocked: the tint is undone
deal({dom=TIER,max=3,lvl=1,cur=3},nil)
field('todUpgAR',3); field('todUpgAD',TIER)
assert(A.body[1].rgb[1]==1,'an unlocked card wears no tint')
tick(A.seq,'tod_pip_seq'); tick(A.seq,'tod_pip_seq')
assert(lit(A)=='owned owned gain_tier','TIER 3: two held, the third lights ('..lit(A)..')')
field('todUpgShow',0)
print('deals 2-4: lone REGULAR, DARK skipped, locked promotion quiet + tinted, unlocked tier lights - PASS')

-- ---- 5. the art the Lua names is the art the tool builds and zones --------------
local zone=io.open('zone_source/zm_tower_of_doom.zone'):read('*a')
local names={'empty','owned','gain_regular','gain_super','gain_ultimate','gain_tier','glow_regular','glow_super','glow_ultimate','shine'}
for _,s in ipairs(names) do
    local nm='i_tod_cardpip_'..s
    assert(src:find('RegisterImage%( "'..nm..'" %)'),'the Lua registers '..nm)
    assert(zone:find('image,'..nm,1,true),'the zone carries '..nm)
end
local tool=io.open('tools/card_pips/build_card_pips.py'):read('*a')
for _,k in ipairs({'PIP_CX','PIP_PITCH','PIP_USABLE_W','PIP_HALO_R','PIP_SPRITE','PIP_GLOW'}) do
    assert(tool:find("'"..k.."'"),'the tool lockstep-checks '..k)
end
print('art: 10 sprites registered, zoned, and lockstep-checked by the tool - PASS')

-- ---- 6. the panel closes every pip element -------------------------------------
local live=0; for _,e in ipairs(elements) do if not e.closed then live=live+1 end end
panel:close()
local after=0; for _,e in ipairs(elements) do if not e.closed then after=after+1 end end
assert(after==0 or after<live-38,'closing the panel releases the rows')
for _,P in ipairs({A,B}) do
    for k=1,10 do assert(P.body[k].closed,'dot '..k..' closed') end
    for j=1,3 do assert(P.glow[j].closed and P.shine[j].closed,'glow/shine '..j..' closed') end
    assert(P.seq.closed and P.beat.closed and P.root.closed,'metronomes + root closed')
end
print('lifetimes: both rows close with the panel (38 elements) - PASS')
print('card pips: all checks PASS')
