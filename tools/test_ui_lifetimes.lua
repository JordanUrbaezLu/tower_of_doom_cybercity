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
function methods:getFirstChild() return self.children[1] end
function methods:getNextSibling()
    if not self.parent then return nil end
    for i,e in ipairs(self.parent.children) do if e==self then return self.parent.children[i+1] end end
end
function methods:close()
    assert(not self.closed, 'element closed twice: '..tostring(self.id))
    self.closed=true
    if self.parent then
        for i,e in ipairs(self.parent.children) do if e==self then table.remove(self.parent.children,i); break end end
        self.parent=nil
    end
end
function methods:registerEventHandler(k,v) self.handlers[k]=v end
function methods:completeAnimation() end
function methods:restoreState() return true end
function methods:playSound() end
function methods:getOwner() return 0 end
function methods:processEvent(e) if self.handlers[e.name] then return self.handlers[e.name](self,e) end end
function methods:getLocalLeftRight() return true,false,0,80 end
function methods:getLocalTopBottom() return true,false,0,20 end
function methods:beginAnimation(name,ms) self.anim={name=name,ms=ms} end
function methods:mergeStateConditions() end
local function enums() return setmetatable({}, {__index=function(t,k) local v=enums(); rawset(t,k,v); return v end}) end
Enum=enums()
Engine=setmetatable({
    Localize=function(s) return s end, GetModelForController=function() return 'ctrl' end,
    GetModel=function(m,k) return tostring(m)..'.'..tostring(k) end, CreateModel=function(m,k) return tostring(m)..'.'..tostring(k) end,
    GetModelValue=function() return 0 end, IsInGame=function() return true end,
    GetCurrentMap=function() return 'zm_tower_of_doom' end, GetClientNum=function() return 0 end,
}, {__index=function() return noop end})
DataSources={}
DataSourceHelpers={ListSetup=function(_,fn) return fn end}
function ListHelper_SetupDataSource(_,fn) return fn end
CoD={Menu={NewForUIEditor=newElement}, TweenType={Linear=0}, isZombie=true, TodOwned={}, TodClass=1, TodClassTier=1}
CoD.Menu.SetButtonLabel=noop; CoD.Menu.UpdateButtonShownState=noop
LUI={UIElement={new=newElement}, UIImage={new=newElement}, UIText={new=newElement}, UIList={new=newElement}, UITimer={new=newElement}, createMenu={}}
function LUI.OverrideFunction_CallOriginalSecond(e,key,fn)
    local old=e[key]; e[key]=function(...) fn(...); if old then return old(...) end end
end
function InheritFrom() return {} end
function RegisterImage(s) return s end
function IsPC() return true end
function IsGamepad() return false end
function IsInGame() return true end
function RegisterOpenedMenu() end
function IsPrimaryController() return true end
function IsModelValueEqualTo() return false end
function PlayClip(e,name) e:playClip(name) end
require=function() end

-- Clip dispatch from KingslayerKyle/T7LuaRepo PC_Ship_2025-05-31.
-- Native allocation is stubbed: these are explicit cleanup tests.
LUI.UIElement.playClip = function ( f116_arg0, f116_arg1 )
	f116_arg0.nextClip = nil
	f116_arg0.currentClipIsTransitionClip = false
	if not f116_arg0.currentState then
		f116_arg0.currentState = "DefaultState"
	end
	if f116_arg0.clipsPerState and f116_arg0.clipsPerState[f116_arg0.currentState] and f116_arg0.clipsPerState[f116_arg0.currentState][f116_arg1] then
		f116_arg0.clipsPerState[f116_arg0.currentState][f116_arg1]()
		return true
	else
		return false
	end
end

methods.playClip=LUI.UIElement.playClip
LUI.UIElement.setupElementClipCounter = function ( f118_arg0, f118_arg1 )
	f118_arg0.elementsPlayingClips = f118_arg1
	if f118_arg0.elementsPlayingClips == 0 then
		f118_arg0:processEvent( {
			name = "clip_over"
		} )
	end
end

methods.setupElementClipCounter=LUI.UIElement.setupElementClipCounter
LUI.UIElement.childClipFinished = function ( f119_arg0 )
	f119_arg0.elementsPlayingClips = f119_arg0.elementsPlayingClips - 1
	if f119_arg0.elementsPlayingClips == 0 then
		f119_arg0:processEvent( {
			name = "clip_over"
		} )
	end
end

methods.childClipFinished=LUI.UIElement.childClipFinished
LUI.UIElement.clipFinished = function ( f120_arg0, f120_arg1 )
	local f120_local0 = f120_arg0:getParent()
	if f120_local0 ~= nil and (not f120_arg1.interrupted or f120_local0.currentClipIsTransitionClip) then
		f120_local0:childClipFinished()
	end
end

methods.clipFinished=LUI.UIElement.clipFinished
local function live() local n=0; for _,e in ipairs(elements) do if not e.closed then n=n+1 end end; return n end

-- Run the complete pause constructor/close; UIList internals are omitted.
dofile('ui/uieditor/menus/StartMenu/AetheriumStartMenu.lua')
for _,rows in ipairs({0,5,18,56}) do
    CoD.TodOwned={}
    for i=1,rows do CoD.TodOwned[i]={lvl=3,max=6,safe=(i%2==0),dark=(i%3==0)} end
    for pass=1,100 do
        local before=live()
        local menu=LUI.createMenu.StartMenu_Main(0)
        menu:close()
        assert(live()==before,'unclosed pause elements, rows='..rows..' pass='..pass)
        elements={}
    end
end
-- Negative control: omit OptionsList cleanup as the previous code did.
local menu=LUI.createMenu.StartMenu_Main(0)
local realClose=menu.OptionsList.close
menu.OptionsList.close=noop
local options=menu.OptionsList
menu:close()
assert(live()==1 and not options.closed,'missing OptionsList close must be detected')
realClose(options)
assert(live()==0)
elements={}

dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodGlyphMetrics.lua')
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodGlyphRow.lua')
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodGlyphText.lua')
-- v19.59b: the pause menu again, now WITH the typeface loaded, so every glyph
-- label (effect / act / key slot / GAME TIME clock) is in the count. Before
-- this pass the pause cycles above ran with the widget absent and proved only
-- the engine-text fallback.
do
    CoD.TodGameSecs = { [0] = 3725 }
    local savedDesc = CoD.TodDomainDesc
    CoD.TodDomainDesc = function( id, lvl ) return "+" .. ( 10 * lvl ) .. "% damage, any weapon", ( id % 2 == 0 ) and "^3[{+frag}]^7 casts; 3 use" or "once per swing" end
    for _,rows in ipairs({0,5,18,56}) do
        CoD.TodOwned={}
        for i=1,rows do CoD.TodOwned[i]={lvl=3,max=6,safe=(i%2==0),dark=(i%3==0)} end
        for pass=1,50 do
            local before=live()
            local menu=LUI.createMenu.StartMenu_Main(0)
            menu:close()
            assert(live()==before,'unclosed pause elements WITH the typeface, rows='..rows..' pass='..pass..' ('..(live()-before)..')')
            elements={}
        end
    end
    CoD.TodDomainDesc = savedDesc
    CoD.TodGameSecs = nil
    print('Pause lifetimes with the typeface passed: 200 cycles incl. key slots and the glyph clock.')
end
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumPlusPoints.lua')
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumPlusPointsContainer.lua')
local owner=newElement()
owner.pointsDeltaContainer=newElement()
local show=CoD.AetheriumPlusPointsContainer.Show
local function finish(p,interrupted)
    p.AetheriumPlusPoints.Label:processEvent({name='transition_complete_keyframe',interrupted=interrupted})
    p.AetheriumPlusPoints:processEvent({name='transition_complete_keyframe',interrupted=interrupted})
end
for i=1,5000 do
    local value=(i%2==0) and 100 or -150
    show(owner,{},0,value)
    local p=owner.todPointPopups[1]
    assert(p.AetheriumPlusPoints.Label:getText()==((value>0) and '+100' or '-150'))
    finish(p,false)
    assert(#owner.todPointPopups==0 and live()==2,'normal popup completion leaked')
    elements={owner,owner.pointsDeltaContainer}
end
for i=1,2500 do
    show(owner,{},0,50)
    local p=owner.todPointPopups[#owner.todPointPopups]
    finish(p,true) -- interrupted clips deliberately never close themselves
    assert(#owner.todPointPopups<=8 and live()<=82,'burst allocation unbounded')
end
local other=newElement(); other.pointsDeltaContainer=newElement()
for i=1,10 do show(other,{},1,10) end
assert(#other.todPointPopups==8 and #owner.todPointPopups==8)
owner:close()
assert(#owner.todPointPopups==0)
assert(#other.todPointPopups==8)
other:close(); owner.pointsDeltaContainer:close(); other.pointsDeltaContainer:close()
assert(live()==0,'owner teardown leaked popups')
elements={}

print('UI lifetimes passed: 400 pause cycles, 5000 completed popups, 2500 interrupted/burst popups, independent owners and teardown; missing-close negative control detected.')

-- Exercise the actual shared prompt builder and every shipping shell. Closing
-- only the shell is insufficient: native UIElement.close does not recurse.
dofile('ui/uieditor/widgets/HUD/ZM_CursorHint/Prompts/TodPromptCard.lua')
dofile('ui/uieditor/widgets/HUD/ZM_CursorHint/Prompts/TodTeleportFeedback.lua')
local promptNames={'PromptDefault','PromptDoors','PromptPerks','PromptPAP','PromptPowerSwitch','PromptPowerRequired'}
for _,name in ipairs(promptNames) do
    dofile('ui/uieditor/widgets/HUD/ZM_CursorHint/Prompts/'..name..'.lua')
    for pass=1,25 do
        local before=live()
        local card=CoD[name].new({},0)
        local allocated=live()-before
        card:close()
        assert(live()==before,name..' leaked '..(live()-before)..' of '..allocated..' elements')
    end
end
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumPerkItem.lua')
for pass=1,500 do
    local before=live()
    local item=CoD.AetheriumPerkItem.new({},0)
    item:close()
    assert(live()==before,'perk item leaked its icon on removal')
end
print('Prompt/perk lifetimes passed: 150 card lifetimes and 500 perk item removals, zero unclosed elements.')

dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodUIOwnership.lua')
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodHealthTint.lua')
dofile('ui/uieditor/widgets/HUD/Mappings/AetheriumPerks.lua')
LUI.UIImage.GetCachedMaterial=function(s) return s end
local ownerNames={'AetheriumPerksContainer','AetheriumRoundCounter','AetheriumPlayerInfo','AetheriumLoadout','AetheriumScoreboard','AetheriumPowerupsContainer','AetheriumPowerupNotification'}
CoD.PowerUps={}
Enum.UIVisibilityBit.BIT_SCOREBOARD_OPEN=1
CoD.AetheriumWeapons={}
dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/TodAbilityFeedback.lua')
for _,name in ipairs(ownerNames) do
    dofile('ui/uieditor/widgets/HUD/AetheriumWidgets/'..name..'.lua')
    for pass=1,20 do
        local before=live()
        local widget=CoD[name].new({},0)
        widget:close()
        assert(live()==before,name..' leaked '..(live()-before)..' elements')
    end
end
print('HUD owner lifetimes passed: 140 widget lifetimes, no leaks or double close.')

CoD.TextWithBg={new=function()
    local e=newElement()
    CoD.TodUIOwnership.Attach(e)
    e.Text=newElement(); e.Bg=newElement()
    e:addElement(e.Text); e:addElement(e.Bg)
    return e
end}
dofile('ui/uieditor/menus/hud/tod_upgrade.lua')
dofile('ui/uieditor/menus/hud/tod_class_select.lua')
Enum.UIVisibilityBit.BIT_GAME_ENDED=2
Enum.UIVisibilityBit.BIT_UI_ACTIVE=3
Enum.UIVisibilityBit.BIT_HUD_VISIBLE=4
for _,name in ipairs({'tod_upgrade','tod_class_select'}) do
    for pass=1,25 do
        local before=live()
        local menu=LUI.createMenu[name](0)
        local allocated=live()-before
        menu:close()
        assert(live()==before,name..' leaked '..(live()-before)..' of '..allocated..' elements')
    end
end
print('Upgrade/class menu lifetimes passed: 50 complete menu rebuilds with zero unclosed elements.')

-- Prove the new ownership hook is load-bearing, using the real constructors.
-- Disable it only for one construction; stock stubs retain their own cleanup.
local attach=CoD.TodUIOwnership.Attach
CoD.TodUIOwnership.Attach=noop
for _,name in ipairs({'AetheriumPlayerInfo','AetheriumLoadout','AetheriumScoreboard'}) do
    elements={}
    local widget=CoD[name].new({},0)
    local allocated=live()
    widget:close()
    assert(live()>0,'missing ownership hook must fail for '..name)
    print('Negative control '..name..': '..live()..' of '..allocated..' elements unclosed')
end
CoD.TodUIOwnership.Attach=attach
elements={}
