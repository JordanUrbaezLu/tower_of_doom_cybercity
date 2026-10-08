CoD = CoD or {}
dofile("ui/uieditor/widgets/HUD/AetheriumWidgets/TodAbilityFeedback.lua")
-- Execute the actual HUD setters with fake images/slots. Run from repo root.
local f = assert(io.open("ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumLoadout.lua", "r"))
local source = f:read("*a"); f:close()
assert(loadstring(source)) -- includes the large widget's real Lua closure limits
local function span(first, last)
    local a = assert(source:find(first, 1, true))
    local b = assert(source:find(last, a + #first, true))
    return source:sub(a, b-1)
end
local chunk = [[
local self, image, slot = {}, {}, {}
-- Fake elements record visibility; setters below are extracted from the live HUD.
function self:addElement() end
TEXTS = {}
LUI = LUI or {}
LUI.UIText = { new = function()
    local t = { alpha = 0 }
    for _, m in ipairs({'setLeftRight','setTopBottom','setTTF','setScale','setRGB','setAlignment'}) do t[m] = function() end end
    t.setText = function(_, v) t.text = v end
    t.setAlpha = function(_, v) t.alpha = v end
    TEXTS[#TEXTS+1] = t
    return t
end }
Enum = { LUIAlignment = { LUI_ALIGNMENT_RIGHT = 2, LUI_ALIGNMENT_CENTER = 1 } }
local HUD_DX = 4
-- The stock key-binding API resolves one keyboard key; Localize stays deferred.
KEY = { ['+smoke']='E', ['+frag']='G OR MIDDLE MOUSE' }
PAD = false
Engine = { Localize = function( t ) return KEY[ t ] or t end }
local todNameSet = {}
local function todMakeGlyphRow( owner, n )
    local row = { drawn = nil, n = n }
    row.measure = function( str, cap ) if string.byte( str, 1 ) >= 128 then return -1 end return #str * cap * 0.6 end
    row.set     = function( str, cap, right ) row.drawn = str; row.cap = cap; row.right = right; row.draws = (row.draws or 0) + 1 end
    row.hide    = function() row.drawn = nil end
    return row
end
function image:setAlpha(v) self.alpha = v end
function image:setRGB(...) end
function image:setImage(v) self.image = v end
function image:setText(v) self.text = v end
function image:setLeftRight(_,_,l,r) self.l, self.r = l, r end
function image:setTopBottom(_,_,t,b) self.t, self.b = t, b end
function image:setShaderVector(_,v) self.fraction = v end
function image:hide() self.hidden = true end
local function newImage()
    local e=setmetatable({}, {__index=image})
    e.hide=function() e.hidden=true end
    return e
end
local function newSlot()
    local s = {icon=newImage(), everHad=true, keyPlate=newImage(), keyText=newImage(), keyMidX=0}
    s.keyRow = todMakeGlyphRow(nil, 12)
    s.keyRight = 43
    s.keyPlate.alpha, s.keyText.alpha = 0, 0
    s.setCount = function(n)
        s.charges = n or 0     -- v19.13: the real setCount records this for the badge
        s.count = n
        if n > 0 then s.everHad=true; s.alpha=1
        elseif s.everHad then s.alpha=.4 else s.alpha=0 end
    end
    return s
end
self.lethal, self.tactical = newSlot(), newSlot()
for _, k in ipairs({'panel','mana_mask','mana_track','mana_fill','mana_rule','clip_row','stock_row'}) do self[k]=newImage() end
local manaOn, cue = false, false
-- 2026-09-24: state 4 (downed mage) + the two named ammo painters it repaints.
local manaDowned = false
PULSE_STOPS, CLIP_PAINTS, STOCK_PAINTS, MODEL_ON = 0, 0, 0, false
local function stopPulse() PULSE_STOPS = PULSE_STOPS + 1 end
local function paintClip( m ) CLIP_PAINTS = CLIP_PAINTS + 1 end
local function paintStock( m ) STOCK_PAINTS = STOCK_PAINTS + 1 end
local function setManaCue(on) cue=on end
local Engine={
    GetModelValue=function() return 0 end,
    -- Exact native probe result: localization wraps the UNEXPANDED token.
    Localize=function(v) return string.char(21)..v..string.char(20) end,
    LastInput_Gamepad=function(c) return PAD end,
    GetKeyBindingLocalizedString=function(c,command,index,a,b)
        assert(index==0 and a==false and b==false, 'use stock player binding context')
        return KEY[command]
    end,
}
local function model( name ) if MODEL_ON then return { name = name } end return nil end
local PANEL_STOCK,PANEL_MAGE,FILL_ARCH,FILL_MANA,OFF_HEAL,OFF_BLINK,OFF_FRAG,OFF_MONKEY=1,2,3,4,5,6,7,8
]] .. span("local TUT_USES = 3", "\t-- [tod 2026-09-09] THE FULL-BAR CUE")
  .. span("local function setMana( value, state )", "\t-- ONE subscription for both mage notifies.") .. [[
setMana(100,3); setAbilities(-1,-1)
assert(self.mana_fill.fraction==0 and not cue)
assert(self.lethal.alpha==0 and self.tactical.alpha==0)
setMana(0,0); setAbilities(1,-1)
assert(self.lethal.alpha==1 and self.tactical.alpha==0)
setAbilities(0,2)
assert(self.lethal.alpha==.4 and self.tactical.alpha==1 and self.tactical.count==2)
setAbilities(0,0)
assert(self.lethal.alpha==.4 and self.tactical.alpha==.4)
setMana(100,0); assert(cue)
setMana(100,1); assert(not cue)
setMana(0,2); setAbilities(3,2)
assert(self.lethal.alpha==0 and self.tactical.alpha==0, 'other class ignores stale mage charges')
setMana(0,3); setAbilities(-1,-1)
assert(self.lethal.alpha==0 and self.tactical.alpha==0, 'class swap cannot leak previous ownership')
-- v19.12 THE ABILITY KEY BADGES. On the tile, key only, retiring after 3 casts.
local function badge(slot) return slot.keyRow.drawn, slot.keyPlate.alpha end
setMana(0,3); setAbilities(-1,-1)
assert(select(2,badge(self.lethal))==0 and select(2,badge(self.tactical))==0, 'no badge while every ability is locked')
setMana(0,0); setAbilities(1,-1)
assert(badge(self.lethal)=='G', 'heal badge carries the live lethal bind in our typeface')
assert(math.abs(select(2,badge(self.lethal))-0.35)<1e-6, 'the plate behind the key is a see-through wash, so the ability icon shows (user, v19.76 review)')
assert(select(2,badge(self.tactical))==0, 'blink badge stays hidden until blink unlocks')
setAbilities(1,2)
assert(badge(self.tactical)=='E', 'blink badge appears with its first charge')
-- Ready only: a spent or locked ability cannot advertise an available cast.
setAbilities(0,2)
assert(select(2,badge(self.lethal))==0, 'spent heal hides its key')
assert(badge(self.tactical)=='E', 'the other ready ability keeps its key')
setAbilities(0,0)
assert(select(2,badge(self.tactical))==0, 'spent blink hides its key')
setAbilities(2,1)
assert(badge(self.lethal)=='G' and badge(self.tactical)=='E', 'both badges return when the charges do')
-- ...and it retires per ability, on that ability only.
tutUses.heal = 3; refreshTut()
assert(select(2,badge(self.lethal))==0, 'heal badge retires after three casts')
assert(badge(self.tactical)=='E', 'blink badge is untouched by the heal count')
tutUses.blink = 3; refreshTut()
assert(select(2,badge(self.tactical))==0, 'blink badge retires on its own count')
tutUses.heal, tutUses.blink = 0, 0
-- Native byte wrappers must never reach the baked glyph row.
tutUses.heal, tutUses.blink = 0, 0
refreshTut()
assert(self.lethal.keyRow.drawn == 'G', 'the primary binding draws in the map font')
assert(self.tactical.keyRow.drawn == 'E', 'a single-bound key is unchanged')
assert(self.lethal.keyText.alpha == 0, 'a keyboard key never uses the engine font')
assert(self.lethal.keyRow.cap == 20, 'the key is drawn at tile size (v19.15, restored after the v19.76 review: over the whole tile)')
local draws = self.lethal.keyRow.draws
for i=1,100 do setMana(0,0); setAbilities(2,1); refreshTut() end
assert(self.lethal.keyRow.draws == draws, 'unchanged state never redraws or flashes the key')
-- A controller binding token is deferred: pass it to the native text renderer.
PAD = true
refreshTut()
assert(self.lethal.keyRow.drawn == nil and self.lethal.keyText.alpha == 1, 'controller uses native text')
assert(self.lethal.keyText.text == string.char(21)..'[{+frag}]'..string.char(20), 'native deferred token remains intact')
PAD = false
KEY['+frag'] = string.char(21)..'[{+frag}]'..string.char(20)
refreshTut()
assert(self.lethal.keyText.text == KEY['+frag'], 'deferred keyboard token is preserved without uppercasing its command')
KEY['+frag'] = 'F10'; refreshTut()
assert(self.lethal.keyRow.drawn == 'F10', 'rebound function key is not truncated to F')
KEY['+frag'] = 'MIDDLE MOUSE'; refreshTut()
assert(self.lethal.keyRow.drawn == 'MIDDLE MOUSE' and self.lethal.keyRow.cap < 20, 'long single key fits the badge')
KEY['+frag'] = 'G'; refreshTut()
for uses=0,2 do
    tutUses.heal=uses; refreshTut()
    assert(badge(self.lethal)=='G', 'key visible before each of first three uses')
end
tutUses.heal=3; refreshTut()
assert(select(2,badge(self.lethal))==0, 'third successful use retires key')
-- 2026-09-24 STATE 4, THE DOWNED MAGE: the down pistol's ammo readout comes
-- back, the ability tiles stay the mage's, and a revive restores the bar.
setMana(40,0); setAbilities(1,2)
assert(self.panel.image==PANEL_MAGE and manaOn and not manaDowned)
MODEL_ON = true
local clip0, stock0 = CLIP_PAINTS, STOCK_PAINTS
setMana(0,4)
assert(self.panel.image==PANEL_STOCK, 'a downed mage gets the stock ammo panel')
assert(self.mana_fill.alpha==0 and not cue, 'no mana bar or ready cue while downed')
assert(manaOn and manaDowned, 'the ability tiles stay the mage\'s while downed')
assert(self.lethal.icon.image==OFF_HEAL and self.tactical.icon.image==OFF_BLINK, 'ability icons unchanged while downed')
assert(CLIP_PAINTS==clip0+1 and STOCK_PAINTS==stock0+1, 'entering state 4 repaints the down pistol ammo once')
setMana(0,4)
assert(CLIP_PAINTS==clip0+1 and STOCK_PAINTS==stock0+1, 'a repeated state 4 push does not repaint again')
MODEL_ON = false
self.clip_row.hidden, self.stock_row.hidden = nil, nil
local stops0 = PULSE_STOPS
setMana(40,0)
assert(self.panel.image==PANEL_MAGE and not manaDowned, 'revive restores the mage panel')
assert(self.clip_row.hidden and self.stock_row.hidden and self.mana_fill.alpha==1, 'revive hides the ammo rows under the bar again')
assert(PULSE_STOPS==stops0+1, 'revive stops a low-ammo pulse left from the down pistol')
-- Negative control: old Localize/sub(1,1) path picks invisible byte 21.
assert(string.byte(string.sub(Engine.Localize('[{+frag}]'),1,1))==21)
setMana(0,2)
assert(select(2,badge(self.lethal))==0 and select(2,badge(self.tactical))==0, 'badges hidden for another class')
]]
assert(loadstring(chunk))()
print("Mage HUD passed: locked, cooldown, charges, ready cue, active form and class transitions.")

-- Replay an already-published scriptNotify synchronously during construction.
-- Keep the real setter/subscription bodies and their source ordering; the old
-- layout runs the callback before newSlot() and crashes on self.lethal.
local subscribeStart = assert(source:find('self:subscribeToGlobalModel( controller, "PerController", "scriptNotify", function ( notifyModel )', 1, true))
local subscribeEnd = assert(source:find("\n\tend )", subscribeStart, true)) + #"\n\tend )"
local subscribe = source:sub(subscribeStart, subscribeEnd)
local slotsAt = assert(source:find('self.tactical = makeOffhandSlot(', 1, true))
local readyAt = assert(source:find('CoD.TodAbilityFeedback.Attach( self, HUD_DX )', 1, true))
assert(subscribeStart > readyAt, 'live notify subscribed before HUD initialization')
local prefix = chunk:sub(1, assert(chunk:find('setMana(100,3)', 1, true))-1)
prefix = prefix:gsub('self.lethal, self.tactical = newSlot%(%), newSlot%(%)', '')
for _, event in ipairs({
    {"tod_mage_mana",0,2}, {"tod_mage_mana",0,3},
    {"tod_mage_mana",75,0}, {"tod_mage_mana",90,1},
    {"tod_mage_abil",0,0}, {"tod_mage_recharge",-1,-1},
    {"tod_mage_blink_blocked",1,0},
}) do
    local setup = string.format([[
local notify = {name=%q, data={%d,%d}}
Engine.GetModelValue=function(m) if m then return m.name end return 0 end
CoD.GetScriptNotifyData=function(m) return m.data end
function self:subscribeToGlobalModel(_,__,___,callback) callback(notify) end
]], event[1],event[2],event[3])
    local slots = 'self.lethal, self.tactical = newSlot(), newSlot()\n'
    local ordered = slotsAt < subscribeStart and (slots .. subscribe) or (subscribe .. slots)
    assert(loadstring(prefix .. setup .. ordered))()
    if event[1] == "tod_mage_mana" then
        local ok = pcall(assert(loadstring(prefix .. setup .. subscribe .. slots)))
        assert(not ok, 'negative control must reproduce the old startup crash')
    end
end
print("Mage HUD startup passed: seven eager notify cases; old ordering reproduces nil-slot crash.")

