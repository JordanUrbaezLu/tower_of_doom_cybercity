-- docs/167 (2026-10-01 tester fixes): EXECUTE the new HUD logic under Lua 5.1
-- (lupa) with a RECORDING mock - alpha, boxes, animations and subscriptions are
-- kept, so the assertions read what the real code did, not what it says.
--   item 2   the Healing Aura revive burst (tod_upgrade.lua CoD.TodHealBurst)
--   item 3   the Mage's Widow's Wine tile (AetheriumLoadout.lua self.web)
--   item 11  the party rows sit one pitch above the local row (AetheriumPartyPlayers)
--   item 12  the floor label decoder (AetheriumHud.lua CoD.TodFloorLabelText)
-- Run: python -c "from lupa.lua51 import LuaRuntime; LuaRuntime().execute(open(r'tools/test_tester_fixes_1001.lua', encoding='utf-8').read())"
local noop=function() end
local elements={}
local methods={}
local notifySubs={}    -- every scriptNotify subscription, in creation order
local modelSubs={}     -- model path -> { fn, ... }
local modelValues={}
local notifyData=nil
local function newElement()
    local e=setmetatable({children={}, handlers={}, alpha=1}, {__index=function(t,k)
        if methods[k] then return methods[k] end
        local cls=rawget(t,'todClass')     -- LUI's setClass: class methods (TodSetRank)
        if cls and cls[k] ~= nil then return cls[k] end
        if k:match('^set') or k:match('^make') or k:match('^link') or k:match('^Add') then return noop end
    end})
    elements[#elements+1]=e
    return e
end
function methods:addElement(e) self.children[#self.children+1]=e; e.parent=self end
function methods:getParent() return self.parent end
function methods:close() self.closed=true end
function methods:setAlpha(a) self.alpha=a end
function methods:setTopBottom(a,b,t,bt) self.tb={a,b,t,bt} end
function methods:setLeftRight(a,b,l,r) self.lr={a,b,l,r} end
function methods:setImage(i) self.image=i end
function methods:setRGB(r,g,b) self.rgb={r,g,b} end
function methods:beginAnimation(name,ms) self.anim={name=name,ms=ms} end
function methods:completeAnimation() self.completed=(self.completed or 0)+1 end
function methods:registerEventHandler(k,v) self.handlers[k]=v end
function methods:processEvent(e) if self.handlers[e.name] then return self.handlers[e.name](self,e) end end
function methods:subscribeToGlobalModel(c,root,name,fn) if name=='scriptNotify' then notifySubs[#notifySubs+1]=fn end end
function methods:subscribeToModel(m,fn) modelSubs[m]=modelSubs[m] or {}; table.insert(modelSubs[m],fn) end
function methods:mergeStateConditions() end
function methods:getOwner() return 0 end
function methods:updateDataSource() end   -- the perks row's list (AetheriumPerksContainer)
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
require=function() end
LUI.UIImage.GetCachedMaterial=function(s) return s end

-- fire one scriptNotify at every subscriber (the engine's own fan-out)
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

dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodGlyphMetrics.lua')
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodGlyphRow.lua')
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodGlyphText.lua')
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodUIOwnership.lua')
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodHealthTint.lua')

-- ---- item 12: the floor label decoder --------------------------------------
dofile('ui/uieditor/menus/hud/AetheriumHud.lua')
assert(type(CoD.TodFloorLabelText)=='function','AetheriumHud defines CoD.TodFloorLabelText')
assert(CoD.TodFloorLabelText(0)==nil,'no push yet -> nil (the readers fall back to the map name)')
local cases={ {1,'FLOOR 1'}, {23,'FLOOR 23'}, {50,'FLOOR 50'}, {100,'THE CROWN'},
              {1001,'SPIRE FLOOR 1'}, {1070,'SPIRE FLOOR 70'}, {1100,'THE SUMMIT'} }
for _,c in ipairs(cases) do
    CoD.TodFloorLabelBy={[0]=c[1]}
    assert(CoD.TodFloorLabelText(0)==c[2],'code '..c[1]..' -> '..tostring(CoD.TodFloorLabelText(0)))
    -- every label is drawable in the map's typeface (A-Z 0-9 space)
    assert(not c[2]:find('[^A-Z0-9 ]'),'label outside the typeface: '..c[2])
end
CoD.TodFloorLabelBy={[0]=23,[1]=1007}
assert(CoD.TodFloorLabelText(0)=='FLOOR 23' and CoD.TodFloorLabelText(1)=='SPIRE FLOOR 7','per controller (split-screen)')
CoD.TodFloorLabelBy=nil
print('floor label decoder: 7 codes, per-controller, typeface-safe - PASS')

-- ---- item 2: the revive burst ------------------------------------------------
CoD.TextWithBg={new=function()
    local e=newElement(); CoD.TodUIOwnership.Attach(e)
    e.Text=newElement(); e.Bg=newElement(); e:addElement(e.Text); e:addElement(e.Bg)
    return e
end}
notifySubs={}
dofile('ui/uieditor/menus/hud/tod_upgrade.lua')
assert(CoD.TodHealBurst and CoD.TodHealBurst.new,'tod_upgrade.lua defines CoD.TodHealBurst')
notifySubs={}
local burst=CoD.TodHealBurst.new({},0)
assert(#notifySubs==1,'the burst holds exactly one scriptNotify subscription')
local glyphs=burst.children
assert(#glyphs>=12,'a shower, not a sprinkle ('..#glyphs..' glyphs)')
for _,g in ipairs(glyphs) do assert(g.alpha==0,'every "+" starts hidden') end
notify('tod_dmg',{5,0})
for _,g in ipairs(glyphs) do assert(g.alpha==0 and g.anim==nil,'another event never fires the burst') end
notify('tod_heal_burst',{1})
local seenCaps, seenLives = {}, {}
for i,g in ipairs(glyphs) do
    assert(g.anim and g.anim.ms>=1000 and g.anim.ms<=1600,'glyph '..i..' animates for ~1-1.6 s')
    assert(g.alpha==0,'glyph '..i..' fades to 0 at the end of its keyframe')
    assert(g.tb and g.tb[1]==false and g.tb[2]==false,'glyph '..i..' stays centre-anchored')
    assert(g.tb[3]<0 or g.tb[4]<300,'glyph '..i..' box is a centre offset')
    assert((g.completed or 0)>=1,'glyph '..i..' completes any running burst first')
    seenLives[g.anim.ms]=true
end
local n=0; for _ in pairs(seenLives) do n=n+1 end
assert(n>=4,'lives vary across the burst (got '..n..')')
-- the rise: each glyph's final box is ABOVE the box it was reset to
local tod=io.open('ui/uieditor/menus/hud/tod_upgrade.lua'):read('*a')
assert(tod:find('local HealBurst = CoD.TodHealBurst.new%( Hud, Instance %)'),'the burst is added to the tod_upgrade menu')
local gsc=io.open('scripts/zm/zm_tower_of_doom/_tod_mage_elements.gsc'):read('*a')
assert(gsc:find('#precache%( "eventstring", "tod_heal_burst" %)'),'GSC precaches tod_heal_burst')
assert(gsc:find('self LuiNotifyEvent%( &"tod_heal_burst", 1, 1 %)'),'GSC sends tod_heal_burst to the revived player')
assert(gsc:find('p thread heal_revive%( self %)'),'heal_pulse revives through heal_revive')
print('heal burst: '..#glyphs..' green "+" glyphs, one subscription, fires only on tod_heal_burst, varied lives, wired both sides - PASS')

-- ---- item 3: the Mage's Widow's Wine tile ----------------------------------
dofile('ui/uieditor/widgets/HUD/Mappings/AetheriumPerks.lua')
CoD.PowerUps={}
CoD.AetheriumWeapons={}
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodAbilityFeedback.lua')
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumPerkItem.lua')
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumPerksContainer.lua')
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumLoadout.lua')
notifySubs={}; modelSubs={}; modelValues={}
local W='ctrl.hudItems.perks.widows_wine'
local PHD='ctrl.hudItems.perks.electric_cherry'
local CNT='ctrl.currentPrimaryOffhand.primaryOffhandCount'
local L=CoD.AetheriumLoadout.new({},0)
assert(L.web and L.web.tile and L.web.icon,'the loadout builds a web tile')
assert(L.web.tile.lr[3]>=1100 and L.web.tile.lr[4]<=1160,'the web tile sits in the free band left of Blink')
local function shown() return L.web.tile.alpha end
assert(shown()==0,'not a mage: no web tile')
setModel(W,1); setModel(CNT,3)
assert(shown()==0,'a non-mage with Widow\'s keeps it on the LETHAL tile - no second tile')
notify('tod_mage_mana',{40,0})          -- the class turns mage (state 0 = filling)
assert(shown()==1,'mage + Widow\'s + 3 webs: bright (protected)')
setModel(CNT,1); assert(shown()==1,'one web left still protects')
setModel(CNT,0); assert(shown()==0.4,'zero webs: DIM - the next hit lands')
setModel(CNT,2); assert(shown()==1,'a refill lights it again')
assert(L.web.icon.image=='i_tod_hud_off_spider','the spider icon')
setModel(PHD,1); assert(L.web.icon.image=='i_tod_hud_off_spider_phd','PhD swaps to the purple spider')
notify('tod_mage_mana',{40,4})          -- downed mage: the ability tiles stay
assert(shown()==1,'a downed mage keeps the tile')
setModel(W,0); assert(shown()==0,'perk lost: tile gone')
setModel(W,1); assert(shown()==1,'perk back: tile back')
notify('tod_mage_mana',{0,2})           -- class change away from mage
assert(shown()==0,'not a mage any more: tile hidden')
print('mage web tile: hidden off-mage, bright with webs, dim at zero, PhD icon, survives the down, follows the perk - PASS')

-- ---- item 11: the party rows against the local row ---------------------------
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumPartyPlayers.lua')
local LOCAL_NAME_TOP=618   -- AetheriumPlayerInfo.lua: the local name box, top 618
local info=io.open('ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumPlayerInfo.lua'):read('*a')
assert(info:find('left = 90, right = 176, top = 618, bottom = 630'),'the local name still starts at 618')
local rows={}
for i=1,3 do rows[i]=CoD.AetheriumPartyPlayers.new({},0,i) end
local function nameTop(r) local dy=(r.tb and r.tb[3]) or 0; return r.name.tb[3]+dy end
local function portraitBottom(r) local dy=(r.tb and r.tb[3]) or 0; return r.portrait.tb[4]+dy end
-- every party size: occupied rows stacked rank 1.. from the bottom (TodPartyRelayout)
for _,occupied in ipairs({{1},{1,2},{1,2,3},{2},{3},{2,3},{1,3}}) do
    local rank=0
    for j=1,3 do
        local isOn=false
        for _,k in ipairs(occupied) do if k==j then isOn=true end end
        if isOn then rank=rank+1; rows[j]:TodSetRank(rank) else rows[j]:TodSetRank(j) end
    end
    local first=nil
    for _,k in ipairs(occupied) do if not first then first=rows[k] end end
    local gap=LOCAL_NAME_TOP-nameTop(first)
    assert(math.abs(gap-43)<0.01,'nearest teammate name sits one 43 pitch above the local name (got '..gap..')')
    assert(portraitBottom(first)<LOCAL_NAME_TOP,'the nearest teammate row ends above the local row')
    local prev=nil
    for _,k in ipairs(occupied) do
        if prev then
            local pitch=nameTop(prev)-nameTop(rows[k])
            assert(pitch>=42 and pitch<=43,'teammate rows keep the 42-43 pitch (got '..pitch..')')
        end
        prev=rows[k]
    end
end
print('party rows: for all 7 occupancy shapes the nearest teammate is one 43 pitch above the local row, no gap - PASS')
print('docs/167 HUD logic: all checks PASS')
