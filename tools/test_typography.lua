-- test_typography.lua — v19.58, the map-wide typography pass.
-- Loads the REAL TodGlyphMetrics / TodGlyphRow / TodGlyphText under a mock LUI
-- and proves: the copy net (colour codes, commas, semicolons, & and brackets),
-- the + and / routing onto the digit sheet, the % and : composites, pool
-- growth, the drop-in UIText surface (box, alignment, TTF no-op), and the
-- player-name TTF fallback. Run under Lua 5.1 (lupa.lua51 works):
--   python -c "from lupa.lua51 import LuaRuntime; LuaRuntime().execute(open('tools/test_typography.lua').read())"

local noop = function() end
local all = {}
local function newElement()
	local e = { children = {}, alpha = 1, img = nil }
	all[ #all + 1 ] = e
	function e:addElement( c ) self.children[ #self.children + 1 ] = c; c.parent = self end
	function e:setAlpha( a ) self.alpha = a end
	function e:setImage( i ) self.img = i end
	function e:setLeftRight( a, b, l, r ) self.l, self.r = l, r end
	function e:setTopBottom( a, b, t, bt ) self.t, self.b = t, bt end
	function e:setText( s ) self.text = s end
	function e:close() self.closed = true end
	return setmetatable( e, { __index = function() return noop end } )
end
LUI = { UIElement = { new = newElement }, UIImage = { new = newElement }, UIText = { new = newElement } }
function LUI.OverrideFunction_CallOriginalSecond( e, key, fn )
	local old = e[ key ]; e[ key ] = function( ... ) fn( ... ); if old then return old( ... ) end end
end
function InheritFrom() return {} end
function RegisterImage( s ) return s end
Enum = { LUIAlignment = { LUI_ALIGNMENT_LEFT = 0, LUI_ALIGNMENT_CENTER = 1, LUI_ALIGNMENT_RIGHT = 2 } }
CoD = {}
require = function() end

dofile( 'ui/uieditor/widgets/HUD/AetheriumWidgets/TodGlyphMetrics.lua' )
dofile( 'ui/uieditor/widgets/HUD/AetheriumWidgets/TodGlyphRow.lua' )
dofile( 'ui/uieditor/widgets/HUD/AetheriumWidgets/TodGlyphText.lua' )

local fails = 0
local function check( cond, msg )
	if not cond then fails = fails + 1; print( 'FAIL: ' .. msg ) end
end

-- the images a label is drawing right now, in order
local function drawn( label )
	local out = {}
	for _, c in ipairs( label.children ) do
		if c.alpha == 1 and c.img and c.img ~= "blacktransparent" then out[ #out + 1 ] = c.img end
	end
	return out
end
local function has( list, name ) for _, v in ipairs( list ) do if v == name then return true end end return false end
local function count( list, name ) local n = 0 for _, v in ipairs( list ) do if v == name then n = n + 1 end end return n end

-- 1. the copy net
local S = CoD.TodGlyphText.Sanitize
check( S( "^3CHOOSING:^7 BOB" ) == "CHOOSING: BOB", "colour codes stripped, colon kept: " .. S( "^3CHOOSING:^7 BOB" ) )
check( S( "16% of shots free, +16% damage" ) == "16% OF SHOTS FREE +16% DAMAGE", "comma -> space: " .. S( "16% of shots free, +16% damage" ) )
check( S( "tier 2: PaP + floor 10; new gun" ) == "TIER 2: PAP + FLOOR 10 - NEW GUN", "semicolon -> dash: " .. S( "tier 2: PaP + floor 10; new gun" ) )
check( S( "Voice & Muting" ) == "VOICE AND MUTING", "& -> AND" )
check( S( "(x2) done!" ) == "X2 DONE", "brackets and bangs dropped: " .. S( "(x2) done!" ) )
check( S( "A / B" ) == "A - B", "spaced slash is a divider" )
check( S( "6.5 HP/s" ) == "6.5 HP/S", "unspaced slash stays" )

-- 2. drop-in label: + / % : all draw, nothing is dropped
local L = CoD.TodGlyphText.Label()
L:setLeftRight( true, false, 100, 500 )
L:setTopBottom( true, false, 10, 24 )
L:setTTF( "fonts/orbitron.ttf" )
L:setAlignment( Enum.LUIAlignment.LUI_ALIGNMENT_LEFT )
L:setText( "+30% damage, back in 4:00 - 6.5 HP/s" )
local d = drawn( L )
check( has( d, "i_tod_hud_dplus" ), "+ drawn from the digit sheet" )
check( has( d, "i_tod_hud_dslash" ), "/ drawn from the digit sheet" )
check( count( d, "i_tod_hud_d0" ) >= 4, "% composite uses two small zeros (plus the 0s in 30 and 4:00)" )
check( count( d, "i_tod_hud_ldot" ) >= 3, ": composite uses two dots (+ the 6.5 dot)" )
-- exact image count: every non-space char is 1, % is 3, : is 2
local clean = "+30% DAMAGE BACK IN 4:00 - 6.5 HP/S"
check( #d == CoD.TodGlyphRow.imageCount( clean ), "image count " .. #d .. " == " .. CoD.TodGlyphRow.imageCount( clean ) )

-- 3. growth: a longer string grows the pool, never truncates
local before = #L.children
L:setText( "A MUCH LONGER LINE OF TEXT THAT NEEDS MORE GLYPH SLOTS THAN BEFORE" )
check( #L.children > before, "pool grew" )
check( #drawn( L ) == CoD.TodGlyphRow.imageCount( "A MUCH LONGER LINE OF TEXT THAT NEEDS MORE GLYPH SLOTS THAN BEFORE" ), "long line fully drawn" )
local grown = #L.children
L:setText( "SHORT" )
check( #L.children == grown, "pool never shrinks" )
check( #drawn( L ) == 5, "short line draws exactly its glyphs" )

-- 4. fits the box: a very long line shrinks instead of overflowing
local W = CoD.TodGlyphText.Label()
W:setLeftRight( true, false, 0, 60 )
W:setTopBottom( true, false, 0, 14 )
W:setText( "THIS IS FAR TOO LONG FOR SIXTY UNITS" )
local maxR = 0
for _, c in ipairs( W.children ) do if c.alpha == 1 and c.r and c.r > maxR then maxR = c.r end end
check( maxR <= 60 + 14, "shrink-to-fit keeps the row inside its box (right edge " .. maxR .. ")" )

-- 4b. setScale shrinks the TYPE and keeps the box edge (v19.58: the pause menu's
-- 0.79 lines used to walk right when the whole element scaled about its centre)
local SC = CoD.TodGlyphText.Label()
SC:setLeftRight( true, false, 100, 460 )
SC:setTopBottom( true, false, 0, 14 )
SC:setText( "ONCE PER SWING" )
local function firstLeft( label )
	local m = 1e9
	for _, c in ipairs( label.children ) do if c.alpha == 1 and c.l and c.l < m then m = c.l end end
	return m
end
local function rightMost( label )
	local m = -1e9
	for _, c in ipairs( label.children ) do if c.alpha == 1 and c.r and c.r > m then m = c.r end end
	return m
end
local l0, r0 = firstLeft( SC ), rightMost( SC )
SC:setScale( 0.79 )
local l1, r1 = firstLeft( SC ), rightMost( SC )
check( math.abs( l1 - l0 ) < 1, "scaled line keeps its left edge (" .. l0 .. " -> " .. l1 .. ")" )
check( ( r1 - l1 ) < ( r0 - l0 ) * 0.85, "scaled line is narrower" )

-- 5. a name with nothing drawable falls back to a real font, not blank
local N = CoD.TodGlyphText.Label( { fallbackTTF = "fonts/orbitron.ttf" } )
N:setLeftRight( true, false, 0, 200 )
N:setTopBottom( true, false, 0, 16 )
N:setText( "\230\151\165\230\156\172" )   -- two CJK characters
local fb = N.children[ 1 ]
check( fb.alpha == 1 and fb.text ~= nil, "all-CJK name shows in the fallback font" )
N:setText( "Bob_42" )
check( fb.alpha == 0 and has( drawn( N ), "i_tod_hud_lb" ), "normal name draws in the typeface" )

-- 6. the digit set is untouched: a digit readout still refuses letters
local D = CoD.TodGlyphText.new( { left = 0, right = 100, top = 0, bottom = 14, set = "digits", pool = 8 } )
D:setText( "1/3+" )
check( #drawn( D ) == 4, "digit readout draws 1/3+" )

if fails > 0 then
	error( "typography test: " .. fails .. " failure(s)" )
end
print( "typography test passed: copy net, + / % : glyphs, growth, fit, name fallback, digit set" )
