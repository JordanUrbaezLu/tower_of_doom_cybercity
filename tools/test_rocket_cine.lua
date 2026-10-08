-- Lua 5.1 harness for TodRocketCine.lua (docs/170, the rocket rides' screen half), ported from Tower of Doom II's
-- test_jump_cine.lua. Loads the real module under BO3's no-new-globals rule, builds it on mocked LUI elements and
-- drives it through its scriptNotify subscription exactly as _tod_rocket.gsc's cine_all does
-- (tod_rocket_cine <state>, <ms>). Asserts: the HUD veil key "rocket" is held for exactly a ride (on -> off, the
-- watchdog, the close hook); the black (boarding) and the white (the crash) draw UNDER the letterbox bars; an
-- overlay state never blanks a free screen; black in / out, white in + HOLD / white out through fire-orange; OFF
-- clears every overlay; interrupted watchdog completions are ignored; junk arguments are harmless.
-- Negative controls: a module that never releases the veil, one that ignores its watchdog, and one that lets an
-- overlay play on a free screen must all FAIL this harness.
local path = "ui/uieditor/widgets/HUD/AetheriumWidgets/TodRocketCine.lua"
local f = assert( io.open( path, "r" ) )
local source = f:read( "*a" ); f:close()

local function newEl( kind )
    local el = { kind = kind, children = {}, alpha = 1, anims = {}, handlers = {} }
    local m = {}
    function m.setLeftRight( self, a, b, l, r ) self.lr = { a, b, l, r } end
    function m.setTopBottom( self, a, b, t, bo ) self.tb = { a, b, t, bo } end
    function m.setAlpha( self, a ) self.alpha = a end
    function m.setRGB( self, r, g, b ) self.rgb = { r, g, b } end
    function m.addElement( self, c ) table.insert( self.children, c ); c.parent = self end
    function m.beginAnimation( self, name, ms ) table.insert( self.anims, { name = name, ms = ms } ) end
    function m.registerEventHandler( self, name, fn ) self.handlers[ name ] = fn end
    function m.subscribeToGlobalModel( self, inst, a, b, fn ) self.notify = fn end
    function m.setClass( self ) end
    function m.close( self ) if self.onClose then self:onClose() end end
    setmetatable( el, { __index = function( t, k )
        if m[ k ] then return m[ k ] end
        if type( k ) == "string" and ( string.find( k, "^set" ) or string.find( k, "^get" ) ) then return function() end end
        return nil
    end } )
    return el
end

local function build( src )
    local owners = {}
    local CoD = {
        TodUIOwnership = { Attach = function() end },
        GetScriptNotifyData = function( model ) return model.data end,
        TweenType = { Linear = 0 },
        TodHudVeil = { Set = function( key, on ) owners[ key ] = on or nil end },
    }
    local LUI = { UIElement = { new = function() return newEl( "el" ) end },
                  UIImage = { new = function() return newEl( "img" ) end },
                  OverrideFunction_CallOriginalSecond = function( el, fname, fn ) el.onClose = function( self ) fn( self ) end end }
    local env = {
        CoD = CoD, LUI = LUI,
        Engine = { GetModelValue = function( m ) return m.name end },
        InheritFrom = function() return {} end,
        require = function() end,
        pcall = pcall, type = type, pairs = pairs, ipairs = ipairs, string = string, table = table, math = math, tonumber = tonumber,
    }
    setmetatable( env, { __index = _G, __newindex = function( _, k ) error( "LUI Error: Tried to create global variable " .. k ) end } )
    local chunk = assert( loadstring( src, "@" .. path ) )
    setfenv( chunk, env )
    assert( pcall( chunk ) )
    local w = CoD.TodRocketCine.new( nil, 0 )
    assert( w.notify, "subscribed to scriptNotify" )
    local byId = {}
    for i, c in ipairs( w.children ) do
        if c.id then byId[ c.id ] = c; c.index = i end
    end
    local E = { top = byId.TodRocketCineTop, bot = byId.TodRocketCineBot, watch = byId.TodRocketCineWatch,
                black = byId.TodRocketCineBlack, white = byId.TodRocketCineWhite }
    assert( E.top and E.bot and E.watch and E.black and E.white, "two bars, a watchdog, the black and the white" )
    local function send( name, data ) w.notify( { name = name, data = data } ) end
    return w, owners, E, send
end

local function lastAnim( el ) return el.anims[ #el.anims ] and el.anims[ #el.anims ].name end

local function check( src )
    local w, owners, E, send = build( src )
    assert( E.black.index < E.top.index and E.white.index < E.top.index and E.black.index < E.bot.index, "the overlays draw UNDER the bars" )
    assert( E.top.rgb[ 1 ] == 0 and E.top.alpha == 1, "the top bar is solid black" )
    assert( E.top.tb[ 4 ] == 0 and E.bot.tb[ 3 ] == 0, "the bars start open (0 tall)" )
    assert( E.black.alpha == 0 and E.white.alpha == 0, "the overlays start invisible" )
    assert( not owners.rocket, "no veil before a ride" )

    -- other events and overlay states on a FREE screen do nothing
    send( "tod_jump_cine", { 1 } )
    send( "tod_rocket_cine_other", { 1 } )
    assert( not owners.rocket, "other events are ignored" )
    send( "tod_rocket_cine", { 3, 350 } )
    send( "tod_rocket_cine", { 5, 60 } )
    assert( E.black.alpha == 0 and E.white.alpha == 0 and #E.black.anims == 0 and #E.white.anims == 0, "an overlay never blanks a free screen" )

    -- THE BOARDING: on (bars + veil), black in, black out
    send( "tod_rocket_cine", { 1, 400 } )
    assert( owners.rocket == true, "a ride holds the veil" )
    assert( E.top.tb[ 4 ] == 86 and E.bot.tb[ 3 ] == -86, "the bars close to 86 of 720 (2.35:1)" )
    assert( E.top.anims[ #E.top.anims ].ms == 400, "the bars close over the server's ms" )
    assert( lastAnim( E.watch ) == "tod_rk_watch", "the watchdog starts with the ride" )
    send( "tod_rocket_cine", { 1, 400 } )
    assert( #E.top.anims == 1, "a repeated ON does not restart the bars" )
    send( "tod_rocket_cine", { 3, 350 } )
    assert( E.black.alpha == 1 and E.black.anims[ #E.black.anims ].ms == 350, "boarding fades TO BLACK over the server's ms" )
    send( "tod_rocket_cine", { 4, 500 } )
    assert( E.black.alpha == 0 and E.black.anims[ #E.black.anims ].ms == 500, "and back FROM black" )
    assert( owners.rocket == true and E.top.tb[ 4 ] == 86, "the ride stays up through the cut" )

    -- THE CRASH: white in and HOLD, then out through fire-orange
    send( "tod_rocket_cine", { 5, 60 } )
    assert( E.white.alpha == 1 and lastAnim( E.white ) == "tod_rk_white_hold", "the crash goes white and holds" )
    assert( E.white.rgb[ 1 ] >= 0.9 and E.white.rgb[ 2 ] >= 0.9, "white-hot" )
    send( "tod_rocket_cine", { 6, 1500 } )
    assert( E.white.alpha == 0 and lastAnim( E.white ) == "tod_rk_white_out" and E.white.anims[ #E.white.anims ].ms == 1500, "then it burns away" )
    assert( E.white.rgb[ 1 ] == 1 and E.white.rgb[ 2 ] < 0.7 and E.white.rgb[ 3 ] < 0.4, "through fire-orange" )
    assert( owners.rocket == true, "the white does not end the ride" )

    -- OFF clears everything and releases the veil
    send( "tod_rocket_cine", { 3, 300 } )
    send( "tod_rocket_cine", { 5, 60 } )
    send( "tod_rocket_cine", { 0, 650 } )
    assert( not owners.rocket, "OFF releases the veil" )
    assert( E.top.tb[ 4 ] == 0 and E.bot.tb[ 3 ] == 0, "the bars open" )
    assert( E.black.alpha == 0 and E.white.alpha == 0, "OFF clears the black and the white" )
    assert( lastAnim( E.watch ) == "tod_rk_watch_off", "the watchdog is stopped" )

    -- the watchdog: an interrupted completion is not a timeout; a real one gives the HUD back
    send( "tod_rocket_cine", { 1, 400 } )
    send( "tod_rocket_cine", { 3, 300 } )
    E.watch.handlers[ "transition_complete_tod_rk_watch" ]( E.watch, { interrupted = true } )
    assert( owners.rocket == true, "an interrupted watchdog keeps the ride" )
    E.watch.handlers[ "transition_complete_tod_rk_watch" ]( E.watch, {} )
    assert( not owners.rocket and E.top.tb[ 4 ] == 0 and E.black.alpha == 0, "the watchdog releases a lost ride, opens the bars and lifts the black" )

    -- missing / junk arguments read as OFF, never as an error
    send( "tod_rocket_cine", { 1, 400 } )
    send( "tod_rocket_cine", nil )
    assert( not owners.rocket, "a missing argument reads as OFF" )
    send( "tod_rocket_cine", { 1 } )
    assert( owners.rocket == true, "ON with no ms uses the default" )
    send( "tod_rocket_cine", { "x" } )
    assert( not owners.rocket, "a junk state reads as OFF" )

    -- the HUD closing mid-ride (death -> spectate, a rebuild) releases the veil
    send( "tod_rocket_cine", { 1, 400 } )
    w:close()
    assert( not owners.rocket, "closing the HUD releases the veil" )
    return true
end

check( source )

-- NEGATIVE CONTROLS
local bad1, n1 = string.gsub( source, "st%.on = on\n\t\tveilSet%( on %)", "st.on = on\n\t\tif on then veilSet( on ) end", 1 )
assert( n1 == 1, "negative control 1 applies" )
assert( not pcall( check, bad1 ), "NEGATIVE CONTROL: a module that never releases the veil must fail" )
local bad2, n2 = string.gsub( source, "\t\tallOff%( 400 %)\n\tend %)", "\tend )", 1 )
assert( n2 == 1, "negative control 2 applies" )
assert( not pcall( check, bad2 ), "NEGATIVE CONTROL: a module that ignores its watchdog must fail" )
local bad3, n3 = string.gsub( source, "elseif not st%.on then\n\t\t\treturn", "elseif false then\n\t\t\treturn", 1 )
assert( n3 == 1, "negative control 3 applies" )
assert( not pcall( check, bad3 ), "NEGATIVE CONTROL: an overlay on a free screen must fail" )

-- THE WIRING: zoned (a require of an unzoned rawfile fails SILENTLY in game), built LAST by the HUD (over every
-- HUD piece) with the veil listened to, the event precached, and every send through cine_all (one sender)
local zf = assert( io.open( "zone_source/zm_tower_of_doom.zone", "r" ) )
local zone = zf:read( "*a" ); zf:close()
assert( string.find( zone, "\nrawfile,ui/uieditor/widgets/HUD/AetheriumWidgets/TodRocketCine.lua", 1, true ), "TodRocketCine.lua is zoned" )
assert( string.find( zone, "\nrawfile,ui/uieditor/widgets/HUD/AetheriumWidgets/TodHudVeil.lua", 1, true ), "TodHudVeil.lua is zoned" )
local hf = assert( io.open( "ui/uieditor/menus/hud/AetheriumHud.lua", "r" ) )
local hud = hf:read( "*a" ); hf:close()
local at = string.find( hud, "CoD.TodRocketCine.new( self, controller )", 1, true )
assert( at, "AetheriumHud builds the rocket letterbox" )
local add = string.find( hud, "self:addElement( self.TodRocketCine )", 1, true )
assert( add and add > at, "AetheriumHud adds the letterbox it built" )
assert( not string.find( hud, ":addElement(", add + 10, true ), "and builds it LAST (no element added after it)" )
assert( string.find( hud, "CoD.TodHudVeil.Listen( self", 1, true ), "AetheriumHud listens to the veil" )
local gf = assert( io.open( "scripts/zm/zm_tower_of_doom/_tod_rocket.gsc", "r" ) )
local gsc = gf:read( "*a" ); gf:close()
assert( string.find( gsc, '#precache( "eventstring", "tod_rocket_cine" );', 1, true ), "_tod_rocket.gsc precaches tod_rocket_cine" )
assert( select( 2, string.gsub( gsc, 'LuiNotifyEvent%( &"tod_rocket_cine"', "" ) ) == 1, "exactly one sender (cine_all)" )
local wd = string.match( gsc, "#define TOD_RK_CINE_WATCHDOG_MS%s+(%d+)" )
local wl = string.match( source, "local WATCHDOG_MS = (%d+)" )
assert( wd and wl and wd == wl, "LOCKSTEP: TOD_RK_CINE_WATCHDOG_MS (" .. tostring( wd ) .. ") == WATCHDOG_MS (" .. tostring( wl ) .. ")" )
print( "test_rocket_cine OK: veil held for exactly a ride, overlays under the bars and never on a free screen, black in/out, white hold/out, OFF clears, watchdog, close, 3 negative controls, zoned + built last + precached + one sender" )
