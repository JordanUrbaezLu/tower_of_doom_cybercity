#using scripts\codescripts\struct;

#using scripts\shared\system_shared;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;
#using scripts\shared\lui_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\shared\ai\zombie_death;
#using scripts\shared\ai\zombie_utility;   // [tod] is_zombie() — the slow targets REGULAR zombies only

#using scripts\zm\_zm_bgb;
#using scripts\zm\_zm_pers_upgrades_functions;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;

#insert scripts\zm\_zm_powerups.gsh;
#insert scripts\zm\_zm_utility.gsh;

#insert scripts\zm\logical\powerups\_zm_powerup_timewarp.gsh;

// [tod 2026-08-24] DURATION -30% (user: "Infinite ammo and timewarp last way
// too long. Can we reduce time by 30% on both") — 30 s -> 21 s.
//
// A LOCAL CONSTANT, NOT N_POWERUP_DEFAULT_TIME. That #define is stock's 30 and it
// is SHARED with INSTA-KILL (this map's 3x damage window, _tod_powerups.gsc),
// DOUBLE POINTS, FIRE SALE and BONFIRE SALE — editing it would have silently cut
// four powerups nobody asked about. Both modules the user named are vendored into
// this repo, so each carries its own number instead.
//
// The HUD countdown reads level.zombie_vars[ "zombie_powerup_timewarp_time" ], which
// powerup_grab sets FROM this value, so the on-screen timer follows with no
// second edit. #define placement: after every #using/#insert and before
// #precache — the "No generated data" trap is about #precache, not #define, but
// keeping the order canonical costs nothing.
#define TOD_TIMEWARP_SECS   21   // was N_POWERUP_DEFAULT_TIME (30)

#precache( "material", TIMEWARP_POWERUP_ICON );
#precache( "string", TIMEWARP_POWERUP_STRING );

#namespace zm_powerup_timewarp;

REGISTER_SYSTEM( "zm_powerup_timewarp", &init, undefined )

//*****************************************************************************
// MAIN
//*****************************************************************************

function init()
{
	level.zombie_vars[ "zombie_powerup_timewarp_on" ] = 0;
	level.zombie_vars[ "zombie_powerup_timewarp_time" ] = 0;

	zm_powerups::register_powerup( "timewarp", &powerup_grab );
	zm_powerups::add_zombie_powerup( "timewarp", TIMEWARP_POWERUP_MODEL, &TIMEWARP_POWERUP_STRING, &zm_powerups::func_should_always_drop, !TIMEWARP_POWERUP_EFFECTS_TEAM, !POWERUP_ANY_TEAM, !POWERUP_ZOMBIE_GRABBABLE, undefined, TIMEWARP_POWERUP_CLIENTFIELD, "zombie_powerup_timewarp_time", "zombie_powerup_timewarp_on" );
	// [tod 2026-08-20] moved AFTER add_zombie_powerup: the setter writes
	// level.zombie_powerups[name].field, and that struct only exists once
	// add_zombie_powerup ran (pre-add = "undefined is not a field object"
	// server crash at load, _zm_powerups.gsc:531 — live-hit on this map).
	zm_powerups::powerup_set_can_pick_up_in_last_stand( "timewarp", 0 );
	
	callback::on_connect( &powerup_init );
}

function powerup_init()
{
	self thread solo_hud_fix();
} 

function solo_hud_fix()
{
	while( 1 )
	{
		// [tod 2026-08-21] NULL-GUARD — see the twin fix in
		// _zm_powerup_infiniteammo.gsc: the undefined operand is
		// zombie_powerup_minigun_on (Death Machine redirected to Gift of Death,
		// so its var is never set); 0 || undefined threw every frame per player
		// and black-screened the load.
		if( ( IS_TRUE( level.zombie_vars[ "zombie_powerup_timewarp_on" ] ) || IS_TRUE( level.zombie_vars[ "zombie_powerup_minigun_on" ] ) ) && !IS_TRUE( self._show_solo_hud ) )
		{
			self._show_solo_hud = 1;
		}
		WAIT_SERVER_FRAME;
	}
}

function powerup_grab( player )
{	
	array::run_all( GetPlayers(), &PlaySound, TIMEWARP_POWERUP_SOUND );
    level thread powerup_activate( self, player );
}

//*****************************************************************************
// LOGIC
//*****************************************************************************

function powerup_activate( drop_item, player )
{
	time = TOD_TIMEWARP_SECS;   // [tod] 21 s, see the note at the #define

	if( level.zombie_vars[ "zombie_powerup_timewarp_on" ] )
	{
		if ( level.zombie_vars["zombie_powerup_timewarp_time"] < time )
		{
			level.zombie_vars["zombie_powerup_timewarp_time"] = time;
		}
		return;
	}
	level notify( "powerup_timewarp_notif" );
	level endon( "powerup_timewarp_notif" );

	level.zombie_vars["zombie_powerup_timewarp_on"] = 1;
	level.zombie_vars["zombie_powerup_timewarp_time"] = time;

	level thread powerup_logic();
	
	while( level.zombie_vars["zombie_powerup_timewarp_time"] > 0 )
	{
		wait( 0.05 );
		// [tod v19.76] the clock stops while the upgrade cards hold the world
		// (_tod_powerups::powerup_pause_hold has the map-wide list)
		if ( IS_TRUE( level.tod_upgrade_pause ) )
			continue;
		level.zombie_vars["zombie_powerup_timewarp_time"] = level.zombie_vars["zombie_powerup_timewarp_time"] - 0.05;
	}
	level thread powerup_deactivate( player );
}

function powerup_deactivate( player )
{
	level.zombie_vars["zombie_powerup_timewarp_on"] = 0;
	// [tod] v17.47: the pack's `player._show_solo_hud = 0` is REMOVED. That flag
	// is the one gate stock's powerup_hud_monitor reads for EVERY grabber-only
	// tray icon, and Time Warp is a level-wide powerup that never needed it —
	// the write blanked a running ZOMBIE BLOOD icon the moment Time Warp ended
	// (user 2026-09-04: "zombie blood wont show in the HUD sometimes"). The
	// grabber-only owners (_tod_powerups::zombie_blood_clear, stock's minigun
	// end) drop the flag themselves.

	a_zombies = GetAISpeciesArray( "axis" );

	for( i = 0; i < a_zombies.size; i++ )
	{
		// [tod] don't pop the upgrade-event FREEZE: a zombie the world-pause
		// pinned (tod_frozen) stays pinned; _tod_zombie_speed's sweep restores
		// the normal curve for the rest within 1.5s.
		if ( !( a_zombies[i] tod_warp_target() ) )
			continue;
		a_zombies[i] ASMSetAnimationRate( 1 );
	}

	level notify( "powerup_timewarp_notif" );
}

// [tod 2026-08-21] WHO the warp slows (user: "it slows down the whole game
// now and not just the zombies"): REGULAR zombies only. The pack's original
// loop hit every "axis" AI — including the Panzer and the Rogue Protectors,
// whose custom locomotion ASMs freeze/stutter when their rate is stomped
// (map 1's Brutus lesson, _tod_zombie_speed) — and it also called the
// PLAYER-ONLY SetMoveSpeedScale on AI every frame. Bosses, frozen (upgrade
// pause) zombies and non-zombie actors are now left alone. self = an AI.
function tod_warp_target()
{
	if ( !isdefined( self ) || !isalive( self ) )
		return false;
	if ( IS_TRUE( self.tod_frozen ) )
		return false;
	if ( IS_TRUE( self.is_boss ) || IS_TRUE( self.tod_boss_custom_speed ) ||
	     IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) )
		return false;
	if ( !( self zombie_utility::is_zombie() ) )
		return false;
	return true;
}

function powerup_logic()
{
	level endon( "powerup_timewarp_notif" );

	while( level.zombie_vars[ "zombie_powerup_timewarp_on" ] )
	{
		// [tod] yield to the upgrade-event world pause — re-slowing to 0.75
		// every frame would un-freeze the horde (the freeze pins them at 0.05)
		// onto movement-locked, weapons-disabled players (verify 2026-08-20).
		if ( !IS_TRUE( level.tod_upgrade_pause ) )
		{
			a_zombies = GetAISpeciesArray( "axis" );

			for( i = 0; i < a_zombies.size; i++ )
			{
				// [tod] regular zombies only (see tod_warp_target); the anim
				// rate is the ONE lever — root motion scales ground speed with
				// it, and SetMoveSpeedScale is player-only anyway.
				if ( !( a_zombies[i] tod_warp_target() ) )
					continue;
				a_zombies[i] ASMSetAnimationRate( TIMEWARP_POWERUP_ZOMBIE_SLOW_SPEED );
			}
		}

		// [tod] 4 Hz re-assert instead of every server frame (20 Hz): the rate
		// persists on the actor between calls (keep-alive lesson), so the
		// per-frame loop over the whole horde bought nothing but server time.
		wait 0.25;
	}
}