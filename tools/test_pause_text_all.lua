-- test_pause_text_all.lua (v19.59b, user 2026-09-27: "Make sure you dont miss
-- anything ... Check all classes and pause menu and scoreboard menu").
-- Runs EVERY upgrade row the pause menu / scoreboard can draw - every domain
-- id in the live DETAIL table, every level 1..max, plain and dark - through
-- the REAL TodGlyphText at the REAL row boxes (pause normal + compact preset,
-- scoreboard), and fails on:
--   * a letter or digit the copy net DROPS (a word the player would lose);
--   * a line that is BLANK after cleaning when the source was not;
--   * a line that shrinks-to-fit below a readable cap (MIN_CAP);
--   * an act line with a [{+bind}] token whose remainder is not in the typeface.
-- Every distinct cleaned line is written to tmp/pause_text_20260927/all_lines.txt
-- so a person can read the whole set. Lua 5.1 (lupa).
local noop = function() end
local function newElement()
	local e = { children = {}, alpha = 1 }
	function e:addElement( c ) self.children[ #self.children + 1 ] = c end
	function e:setAlpha( a ) self.alpha = a end
	function e:setImage( i ) self.img = i end
	function e:setLeftRight( a, b, l, r ) self.l, self.r = l, r end
	function e:setTopBottom( a, b, t, bt ) self.t, self.b = t, bt end
	function e:setText( s ) self.text = s end
	function e:close() self.closed = true end
	-- stand-in for the engine's own text measure: ENGINE_KEY_W per key token
	function e:getTextWidth()
		if type( ENGINE_KEY_W ) == "table" then
			local cmd = string.match( self.text or "", "%[%{(.-)%}%]" )
			return ENGINE_KEY_W[ cmd ] or ENGINE_KEY_W.default or 0
		end
		return ENGINE_KEY_W or 0
	end
	return setmetatable( e, { __index = function() return noop end } )
end
LUI = { UIElement = { new = newElement }, UIImage = { new = newElement }, UIText = { new = newElement } }
function LUI.OverrideFunction_CallOriginalSecond( e, k, fn ) local o = e[ k ]; e[ k ] = function( ... ) fn( ... ); if o then return o( ... ) end end end
function InheritFrom() return {} end
function RegisterImage( s ) return s end
Enum = { LUIAlignment = { LUI_ALIGNMENT_LEFT = 0, LUI_ALIGNMENT_CENTER = 1, LUI_ALIGNMENT_RIGHT = 2 } }
Engine = setmetatable( {
	Localize = function( x ) return x end,
	LastInput_Gamepad = function() return PAD_MODE end,
	GetKeyBindingLocalizedString = function( c, cmd ) return KEYS and KEYS[ cmd ] end,
	SendMenuResponse = function( c, m, r ) DIAG[ #DIAG + 1 ] = r end,
}, { __index = function() return function() return nil end end } )
DIAG = {}
CoD = {}
require = function() end
dofile( 'ui/uieditor/widgets/HUD/AetheriumWidgets/TodGlyphMetrics.lua' )
dofile( 'ui/uieditor/widgets/HUD/AetheriumWidgets/TodGlyphRow.lua' )
dofile( 'ui/uieditor/widgets/HUD/AetheriumWidgets/TodGlyphText.lua' )

-- the DOMAIN .. TodDomainDesc block of tod_upgrade.lua, executed as-is
local src = io.open( 'ui/uieditor/menus/hud/tod_upgrade.lua' ):read( '*a' )
local a = string.find( src, "\nlocal PAL = {", 1, true )
local b = string.find( src, "\nCoD.TodDomainInfo = DOMAIN", 1, true )
assert( a and b, "tod_upgrade.lua anchors moved" )
local chunk = assert( loadstring( string.sub( src, a, b ) .. "\nreturn DOMAIN, DETAIL\n", "tod_upgrade_block" ) )
local DOMAIN, DETAIL = chunk()

local S = CoD.TodGlyphText.Sanitize
-- A line wider than its box shrinks to fit. Measured as the drawn glyph-cell
-- height against the same box's unshrunk height: below MIN_FIT the line is
-- noticeably smaller than its neighbours (the "too small to read" failure).
local MIN_FIT = 0.80
local fails, lines, seen, worst = 0, {}, {}, {}
local function fail( m ) fails = fails + 1; print( "FAIL: " .. m ) end

local function alnum( s )
	s = string.gsub( s, "%^%d", "" )
	s = string.gsub( s, "%[%{.-%}%]", "" )
	return ( string.gsub( string.upper( s ), "[^A-Z0-9]", "" ) )
end

-- the box a line is drawn in, and its scale (copied from the menus; LOCKSTEP)
local BOXES = {
	{ tag = "pause eff",         w = 369 - 6,       h = 14, s = 1.0 },
	{ tag = "pause act",         w = 369 - 6,       h = 14, s = 0.94 },
	{ tag = "pause eff compact", w = 369 - 6,       h = 13, s = 1.0 },
	{ tag = "pause act compact", w = 369 - 6,       h = 12, s = 0.94 },
	{ tag = "pause act+key",     w = 369 - 6 - 136, h = 12, s = 0.94 },
	{ tag = "scoreboard eff",    w = 389 - 6 - 19,  h = 16, s = 1.0 },
}
local function drawnCap( text, box )
	local L = CoD.TodGlyphText.Label()
	L:setLeftRight( true, false, 0, box.w )
	L:setTopBottom( true, false, 0, box.h )
	L:setScale( box.s )
	L:setText( text )
	local capMax = 0
	for _, c in ipairs( L.children ) do
		if c.alpha == 1 and c.img and c.t and c.b and ( c.b - c.t ) > capMax then capMax = c.b - c.t end
	end
	return capMax
end

local function check( where, raw, isAct )
	if raw == nil or raw == "" then return end
	local hasKey = string.find( raw, "[{", 1, true ) ~= nil
	local text = raw
	if hasKey then
		-- what the pause menu draws in glyphs when the key stays engine text
		text = string.gsub( raw, "%[%{.-%}%]", "" )
		text = string.gsub( text, "%^%d", "" )
		text = string.gsub( text, "^[%s;,]+", "" )
	end
	local clean = S( text )
	if alnum( text ) ~= alnum( clean ) then
		fail( where .. " drops characters: '" .. raw .. "' -> '" .. clean .. "'" )
	end
	if clean == "" and alnum( text ) ~= "" then fail( where .. " blank after cleaning: " .. raw ) end
	local boxes = isAct and { BOXES[ 2 ], BOXES[ 4 ] } or { BOXES[ 1 ], BOXES[ 3 ], BOXES[ 6 ] }
	if hasKey then boxes = {} end   -- v19.60: a keyed line is sized by layoutCheck (the real TodActLine)
	for _, box in ipairs( boxes ) do
		local fit = drawnCap( text, box ) / drawnCap( "A", box )
		if clean ~= "" and fit < MIN_FIT then
			fail( string.format( "%s shrinks to %d%% in %s: %s", where, math.floor( fit * 100 ), box.tag, clean ) )
		end
		if clean ~= "" and ( worst[ box.tag ] == nil or fit < worst[ box.tag ][ 1 ] ) then worst[ box.tag ] = { fit, clean } end
	end
	if not seen[ clean ] then
		seen[ clean ] = true
		lines[ #lines + 1 ] = string.format( "%-14s %s%s", where, clean, hasKey and "   [+ engine key]" or "" )
	end
end

-- THE REAL LAYOUT (v19.60): TodLabel .. TodActLine executed out of the pause
-- menu itself, so this proves the code that ships, not a copy of its maths.
local menuSrc = io.open( 'ui/uieditor/menus/StartMenu/AetheriumStartMenu.lua' ):read( '*a' )
local ma = string.find( menuSrc, "\nlocal function TodLabel()", 1, true )
local mb = string.find( menuSrc, "\n-- Configuration", 1, true )
assert( ma and mb and mb > ma, "AetheriumStartMenu anchors moved" )
local TodActLine = assert( loadstring( string.sub( menuSrc, ma, mb ) .. "\nreturn TodActLine\n", "pause_menu_block" ) )()

-- The three ways a key reaches the screen. Engine widths are ESTIMATES of the
-- engine font (the real ones come from getTextWidth in game): the user's own
-- binds read E / G OR MIDDLE MOUSE / RIGHT MOUSE.
local DEVICES = {
	{ tag = "keyboard name",  pad = false, keys = { [ "+smoke" ] = "E", [ "+frag" ] = "G or Middle Mouse", [ "+speed_throw" ] = "Right Mouse" } },
	-- the stock keyboard config (the user's bindings_0.cfg): aim is MOUSE2
	-- "+toggleads_throw" and "+speed_throw" answers "Unbound" (v19.61 screenshot)
	{ tag = "keyboard stock", pad = false, keys = { [ "+smoke" ] = "E", [ "+frag" ] = "G or Middle Mouse", [ "+speed_throw" ] = "Unbound", [ "+toggleads_throw" ] = "Right Mouse" } },
	-- lookup fails: the engine draws the name; orbitron at a 14-unit box runs
	-- ~7.3 units a character, so E ~10, RIGHT MOUSE ~85, G OR MIDDLE MOUSE ~125
	{ tag = "keyboard engine", pad = false, keys = {},
	  engineW = { [ "+smoke" ] = 10, [ "+frag" ] = 125, [ "+speed_throw" ] = 85, default = 125 } },
	{ tag = "controller",     pad = true,  keys = {}, engineW = 20 },    -- a button picture, 1.25x
}
-- the act-line boxes, read out of the menu (both presets) so they cannot drift
local actBoxes = {}
for t, b in string.gmatch( menuSrc, "ACT_T, ACT_B, ACT_S = (%d+), (%d+)," ) do actBoxes[ #actBoxes + 1 ] = { tonumber( t ), tonumber( b ) } end
assert( #actBoxes == 2, "expected the normal + compact ACT_T/ACT_B assignments, found " .. #actBoxes )
local LAYOUTS = {
	{ tag = "normal",  top = actBoxes[ 1 ][ 1 ], bottom = actBoxes[ 1 ][ 2 ], gs = 0.94 },
	{ tag = "compact", top = actBoxes[ 2 ][ 1 ], bottom = actBoxes[ 2 ][ 2 ], gs = 0.94 },
}
local LEFT, RIGHT = 62, 62 + 369 - 6
local layoutChecks, keyLines = 0, {}

local function absSpan( el )
	local lo, hi = 1e9, -1e9
	for _, c in ipairs( el.children or {} ) do
		if c.alpha == 1 and c.img and c.img ~= "blacktransparent" and c.l then
			if el.l + c.l < lo then lo = el.l + c.l end
			if el.l + c.r > hi then hi = el.l + c.r end
		end
	end
	return lo, hi
end
local function maxCell( el )
	local m = 0
	for _, c in ipairs( el.children or {} ) do
		if c.alpha == 1 and c.img and c.t and ( c.b - c.t ) > m then m = c.b - c.t end
	end
	return m
end

local function layoutCheck( where, act )
	if not string.find( act, "[{", 1, true ) then return end
	keyLines[ #keyLines + 1 ] = act
	for _, dev in ipairs( DEVICES ) do
		for _, lay in ipairs( LAYOUTS ) do
			PAD_MODE, KEYS, ENGINE_KEY_W = dev.pad, dev.keys, dev.engineW
			local owner = { kids = {} }
			function owner:addElement( e ) self.kids[ #self.kids + 1 ] = e end
			TodActLine( owner, 0, act, LEFT, RIGHT, lay.top, lay.bottom, lay.gs, 0.67, { 1, 1, 1 } )
			local tag = where .. " [" .. dev.tag .. ", " .. lay.tag .. "]"
			layoutChecks = layoutChecks + 1
			-- order and overlap, left to right; nothing past the column
			local prevR = LEFT - 1
			local words = {}
			local nominal = nil
			for i, e in ipairs( owner.kids ) do
				if e.children and #e.children > 0 then
					local lo, hi = absSpan( e )
					if hi > -1e8 then
						if lo < prevR - 0.5 then fail( tag .. " piece " .. i .. " overlaps the one before (" .. lo .. " < " .. prevR .. ")" ) end
						if hi > RIGHT + 1 then fail( tag .. " runs past the column (" .. hi .. " > " .. RIGHT .. ")" ) end
						prevR = hi
						words[ #words + 1 ] = CoD.TodGlyphText.Sanitize( e.getText and e:getText() or "" )
						local cell = maxCell( e )
						if not nominal then nominal = cell end
					end
				else
					-- the engine key: its box must start after PRESS and end before the rest
					if e.l < prevR - 0.5 then fail( tag .. " engine key overlaps PRESS" ) end
					prevR = e.r - 4
					if dev.pad and ( e.b - e.t ) < ( lay.bottom - lay.top ) * 1.25 - 0.01 then fail( tag .. " controller key not 25% larger" ) end
					if not dev.pad and ( e.b - e.t ) > ( lay.bottom - lay.top ) + 0.01 then fail( tag .. " keyboard engine key was enlarged" ) end
					words[ #words + 1 ] = "<" .. tostring( e.text ) .. ">"
				end
			end
			-- shrink: the whole line may shrink together, but not below 80%
			local full = CoD.TodGlyphText.Label()
			full:setLeftRight( true, false, 0, 2000 ); full:setTopBottom( true, false, lay.top, lay.bottom ); full:setScale( lay.gs ); full:setText( "A" )
			local fit = ( nominal or 0 ) / maxCell( full )
			if fit < MIN_FIT then fail( string.format( "%s shrinks to %d%%", tag, math.floor( fit * 100 ) ) ) end
			for _, w in ipairs( words ) do
				if string.find( string.upper( w ), "UNBOUND", 1, true ) then fail( tag .. " draws an UNBOUND key: " .. table.concat( words, " " ) ) end
			end
			if string.sub( words[ 1 ] or "", 1, 5 ) ~= "PRESS" then fail( tag .. " does not start with PRESS: " .. table.concat( words, " " ) ) end
			if lay.tag == "compact" then
				lines[ #lines + 1 ] = string.format( "%-44s %3d%%  %s", tag, math.floor( fit * 100 ), table.concat( words, " " ) )
			end
		end
	end
end

local rows = 0
for id = 1, 63 do
	if DETAIL[ id ] then
		local max = ( DOMAIN[ id ] and DOMAIN[ id ].max ) or 10
		for _, dark in ipairs( { false, true } ) do
			for lvl = 1, max do
				local eff, act = CoD.TodDomainDesc( id, lvl, dark )
				if eff == nil then
					fail( "id " .. id .. " lvl " .. lvl .. ( dark and " dark" or "" ) .. " returns no effect line (row would fall back to the generic desc)" )
				else
					rows = rows + 1
					check( "id " .. id .. " L" .. lvl .. ( dark and "D" or "" ), CoD.TodRoundText( eff ), false )
					check( "id " .. id .. " L" .. lvl .. ( dark and "D" or "" ), CoD.TodRoundText( act ), true )
					if act then layoutCheck( "id " .. id .. " L" .. lvl .. ( dark and "D" or "" ), CoD.TodRoundText( act ) ) end
				end
			end
		end
	end
	-- the plate-less text label and the fallback desc
	if DOMAIN[ id ] then
		check( "id " .. id .. " name", DOMAIN[ id ].name, false )
		-- no DETAIL row: the pause menu prints DOMAIN.desc as the effect line
		if not DETAIL[ id ] and DOMAIN[ id ].desc then
			check( "id " .. id .. " desc", DOMAIN[ id ].desc, false )
		end
	end
end

for _, act in ipairs( keyLines ) do
	if not string.find( act, "^Press %^3%[%{[^}]+%}%]%^7 to %a+ %- " ) then
		fail( "ability line is not 'Press <key> to <verb> - ...': " .. act )
	end
end
if #keyLines == 0 then fail( "no ability lines found - the DETAIL table moved?" ) end
-- the dev key report fires once per command
local diagCmds = {}
for _, r in ipairs( DIAG ) do local c = string.match( r, "^tod_keydiag|([^|]+)|" ); if c then diagCmds[ c ] = ( diagCmds[ c ] or 0 ) + 1 end end
for c, n in pairs( diagCmds ) do if n ~= 1 then fail( "key report for " .. c .. " sent " .. n .. " times" ) end end
if not diagCmds[ "+smoke" ] then fail( "no key report for +smoke" ) end
print( "ability layout: " .. layoutChecks .. " line/device/layout cases, " .. #keyLines .. " keyed lines" )
local f = io.open( 'tmp/pause_text_20260927/all_lines.txt', 'w' )
if f then f:write( table.concat( lines, "\n" ) .. "\n" ); f:close() end
for tag, w in pairs( worst ) do print( string.format( "  tightest in %-18s %3d%%  %s", tag, math.floor( w[ 1 ] * 100 ), w[ 2 ] ) ) end
if fails > 0 then error( "pause text test: " .. fails .. " failure(s)" ) end
print( "pause text test passed: " .. rows .. " domain/level rows, " .. #lines .. " distinct lines, every letter drawn, no line under " .. MIN_FIT * 100 .. "% size" )
