-- =============================================================================
-- TodRocketCine.lua — THE ROCKET RIDES, the screen half (docs/170).
--
-- User 2026-10-02: "use the rocket ships built in the props ... they view from the
-- rocket POV as it flies to the endless spire. Then it crashes into the ground and
-- they spawn in and it starts" + "if you extract same thing but the extract ship goes
-- straight up and the game ends few seconds later". _tod_rocket.gsc owns the whole
-- timeline (the boarding, the camera on the hull, the crash); this widget only draws
-- what the server tells it to, per player, on the scriptNotify lane:
--     tod_rocket_cine ( 1, ms )   letterbox in, HUD hidden (the shared veil, key "rocket")
--     tod_rocket_cine ( 0, ms )   letterbox out, HUD back, every overlay off
--     tod_rocket_cine ( 3, ms )   fade TO BLACK over ms and hold (boarding: the cut onto the hull)
--     tod_rocket_cine ( 4, ms )   fade FROM black over ms
--     tod_rocket_cine ( 5, ms )   WHITE in over ms and HOLD (the crash: nothing can be seen while the
--                                 riders are set down at the Spire)
--     tod_rocket_cine ( 6, ms )   the white OUT over ms, cooling through fire-orange (the reveal)
-- Ported from Tower of Doom II's TodJumpCine.lua (the first jump's letterbox and flash, played
-- there): same bars, same veil, same watchdog and close-releases-the-veil rules. The overlays
-- sit UNDER the bars (added first), so the letterbox stays black through a white-out.
-- A DUMB RENDERER: the server sends 0 on every exit path (the end of a ride, a death, a
-- disconnect, the extract ending the game). Belt and braces: a WATCHDOG drops everything if
-- the 0 never arrives, and closing the HUD releases the veil, so the HUD can never stay hidden.
-- =============================================================================

require( "ui.uieditor.widgets.HUD.AetheriumWidgets.TodUIOwnership" )
pcall( require, "ui.uieditor.widgets.HUD.AetheriumWidgets.TodHudVeil" )

local BAR_H = 86           -- canvas units of 720: 12% top + 12% bottom = 2.35:1 (Tower II's)
local IN_MS = 500
local OUT_MS = 650
-- The longest ride (the ascend, ~17 s) plus the boarding and the reveal; if the "off" is
-- ever lost the watchdog opens the frame and gives the HUD back. LOCKSTEP with
-- _tod_rocket.gsc TOD_RK_CINE_WATCHDOG_MS (tools/rocket/test_rocket_ride.js reads both).
local WATCHDOG_MS = 32000
local HOT = { 1.0, 0.97, 0.9 }      -- white-hot
local BURN = { 1.0, 0.55, 0.22 }    -- it cools to fire as it clears

local function veilSet( on )
	if CoD.TodHudVeil then
		CoD.TodHudVeil.Set( "rocket", on )
	end
end

local function msOf( v, dflt )
	local n = math.floor( tonumber( v ) or dflt )
	if n < 1 then
		n = 1
	end
	return n
end

CoD.TodRocketCine = InheritFrom( LUI.UIElement )

function CoD.TodRocketCine.new( HudRef, InstanceRef )
	local self = LUI.UIElement.new()
	CoD.TodUIOwnership.Attach( self )
	self:setClass( CoD.TodRocketCine )
	self.id = "TodRocketCine"
	self:setLeftRight( true, true, 0, 0 )
	self:setTopBottom( true, true, 0, 0 )

	-- THE BLACK (boarding) and THE WHITE (the blast / the crash): first, so they draw under the bars.
	local Black = LUI.UIImage.new()
	Black.id = "TodRocketCineBlack"
	Black:setLeftRight( true, true, 0, 0 )
	Black:setTopBottom( true, true, 0, 0 )
	Black:setRGB( 0, 0, 0 )
	Black:setAlpha( 0 )
	self:addElement( Black )

	local White = LUI.UIImage.new()
	White.id = "TodRocketCineWhite"
	White:setLeftRight( true, true, 0, 0 )
	White:setTopBottom( true, true, 0, 0 )
	White:setRGB( HOT[ 1 ], HOT[ 2 ], HOT[ 3 ] )
	White:setAlpha( 0 )
	self:addElement( White )

	local Top = LUI.UIImage.new()
	Top.id = "TodRocketCineTop"
	Top:setLeftRight( true, true, 0, 0 )
	Top:setTopBottom( true, false, 0, 0 )
	Top:setRGB( 0, 0, 0 )
	Top:setAlpha( 1 )
	self:addElement( Top )

	local Bot = LUI.UIImage.new()
	Bot.id = "TodRocketCineBot"
	Bot:setLeftRight( true, true, 0, 0 )
	Bot:setTopBottom( false, true, 0, 0 )
	Bot:setRGB( 0, 0, 0 )
	Bot:setAlpha( 1 )
	self:addElement( Bot )

	-- The watchdog: an empty element whose long tween is the timer (no UITimers in this
	-- tree). A new beginAnimation interrupts the old one; an interrupted completion is ignored.
	local Watch = LUI.UIElement.new()
	Watch.id = "TodRocketCineWatch"
	Watch:setLeftRight( true, false, 0, 1 )
	Watch:setTopBottom( true, false, 0, 1 )
	Watch:setAlpha( 0 )
	self:addElement( Watch )

	local st = { on = false }

	local function barsTo( h, ms )
		Top:beginAnimation( "tod_rk_bars", ms, false, false, CoD.TweenType.Linear )
		Top:setTopBottom( true, false, 0, h )
		Bot:beginAnimation( "tod_rk_bars", ms, false, false, CoD.TweenType.Linear )
		Bot:setTopBottom( false, true, -h, 0 )
	end

	local function blackTo( a, ms )
		Black:beginAnimation( "tod_rk_black", ms, false, false, CoD.TweenType.Linear )
		Black:setAlpha( a )
	end

	-- the white: one named tween per step, so a new white or the ride ending interrupts it cleanly
	local function whiteStop()
		st.flash = nil
		White:beginAnimation( "tod_rk_white_stop", 1, false, false, CoD.TweenType.Linear )
		White:setAlpha( 0 )
	end

	local function whiteHold( ms )
		st.flash = "hold"
		White:setRGB( HOT[ 1 ], HOT[ 2 ], HOT[ 3 ] )
		White:beginAnimation( "tod_rk_white_hold", ms, false, false, CoD.TweenType.Linear )
		White:setAlpha( 1 )
	end

	local function whiteOut( ms )
		st.flash = "out"
		White:beginAnimation( "tod_rk_white_out", ms, false, false, CoD.TweenType.Linear )
		White:setRGB( BURN[ 1 ], BURN[ 2 ], BURN[ 3 ] )
		White:setAlpha( 0 )
	end

	local function setOn( on, ms )
		if on == st.on then
			return
		end
		st.on = on
		veilSet( on )
		if on then
			barsTo( BAR_H, ms or IN_MS )
			Watch:setAlpha( 0 )
			Watch:beginAnimation( "tod_rk_watch", WATCHDOG_MS, false, false, CoD.TweenType.Linear )
			Watch:setAlpha( 0.01 )
		else
			barsTo( 0, ms or OUT_MS )
			Watch:beginAnimation( "tod_rk_watch_off", 50, false, false, CoD.TweenType.Linear )
			Watch:setAlpha( 0 )
		end
	end

	-- every overlay off (the ride is over, or the watchdog fired)
	local function allOff( ms )
		whiteStop()
		blackTo( 0, msOf( ms, 250 ) )
		setOn( false, nil )
	end

	Watch:registerEventHandler( "transition_complete_tod_rk_watch", function ( element, event )
		if event and event.interrupted then
			return
		end
		allOff( 400 )
	end )

	self:subscribeToGlobalModel( InstanceRef, "PerController", "scriptNotify", function ( model )
		if Engine.GetModelValue( model ) ~= "tod_rocket_cine" then
			return
		end
		local d = CoD.GetScriptNotifyData( model ) or {}
		local s = math.floor( tonumber( d[ 1 ] ) or 0 )
		local ms = d[ 2 ]
		if s == 0 then
			allOff( ms )
		elseif s == 1 then
			setOn( true, msOf( ms, IN_MS ) )
		elseif not st.on then
			return   -- an overlay only ever plays inside a live ride: a stray state never blanks a free screen
		elseif s == 3 then
			blackTo( 1, msOf( ms, 350 ) )
		elseif s == 4 then
			blackTo( 0, msOf( ms, 450 ) )
		elseif s == 5 then
			whiteHold( msOf( ms, 60 ) )
		elseif s == 6 then
			whiteOut( msOf( ms, 1400 ) )
		end
	end )

	-- The HUD closes with its menu (death -> spectate, a rebuild): never leave the veil held
	-- by bars that no longer exist.
	LUI.OverrideFunction_CallOriginalSecond( self, "close", function ( element )
		st.flash = nil
		if st.on then
			st.on = false
			veilSet( false )
		end
	end )

	return self
end
