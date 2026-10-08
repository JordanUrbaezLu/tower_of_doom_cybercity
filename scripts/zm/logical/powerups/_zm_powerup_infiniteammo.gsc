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

#using scripts\zm\_zm_bgb;
#using scripts\zm\_zm_pers_upgrades_functions;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;

#insert scripts\zm\_zm_powerups.gsh;
#insert scripts\zm\_zm_utility.gsh;

#insert scripts\zm\logical\powerups\_zm_powerup_infiniteammo.gsh;

// [tod 2026-08-24] DURATION -30% (user: "Infinite ammo and timewarp last way
// too long. Can we reduce time by 30% on both") — 30 s -> 21 s.
//
// A LOCAL CONSTANT, NOT N_POWERUP_DEFAULT_TIME. That #define is stock's 30 and it
// is SHARED with INSTA-KILL (this map's 3x damage window, _tod_powerups.gsc),
// DOUBLE POINTS, FIRE SALE and BONFIRE SALE — editing it would have silently cut
// four powerups nobody asked about. Both modules the user named are vendored into
// this repo, so each carries its own number instead.
//
// The HUD countdown reads level.zombie_vars[ "zombie_powerup_infiniteammo_time" ], which
// powerup_grab sets FROM this value, so the on-screen timer follows with no
// second edit. #define placement: after every #using/#insert and before
// #precache — the "No generated data" trap is about #precache, not #define, but
// keeping the order canonical costs nothing.
#define TOD_INFINITEAMMO_SECS   21   // was N_POWERUP_DEFAULT_TIME (30)

#precache( "material", INFINITEAMMO_POWERUP_ICON );
#precache( "string", INFINITEAMMO_POWERUP_STRING );

#namespace zm_powerup_infiniteammo;

REGISTER_SYSTEM( "zm_powerup_infiniteammo", &init, undefined )

//*****************************************************************************
// MAIN
//*****************************************************************************

function init()
{
	level.zombie_vars[ "zombie_powerup_infiniteammo_on" ] = 0;
	level.zombie_vars[ "zombie_powerup_infiniteammo_time" ] = 0;

	zm_powerups::register_powerup( "infiniteammo", &powerup_grab );
	zm_powerups::add_zombie_powerup( "infiniteammo", INFINITEAMMO_POWERUP_MODEL, &INFINITEAMMO_POWERUP_STRING, &zm_powerups::func_should_always_drop, !INFINITEAMMO_POWERUP_EFFECTS_TEAM, !POWERUP_ANY_TEAM, !POWERUP_ZOMBIE_GRABBABLE, undefined, INFINITEAMMO_POWERUP_CLIENTFIELD, "zombie_powerup_infiniteammo_time", "zombie_powerup_infiniteammo_on" );
	// [tod 2026-08-20] moved AFTER add_zombie_powerup (same crash-order fix
	// as the timewarp module — see its init comment).
	zm_powerups::powerup_set_can_pick_up_in_last_stand( "infiniteammo", 0 );
	
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
		// [tod 2026-08-21] NULL-GUARD — was the boot-hang: this raw || threw
		// "cannot cast undefined to bool" EVERY server frame, per player. The
		// pack assumes the stock minigun powerup inits
		// zombie_vars["zombie_powerup_minigun_on"], but this map redirects the
		// Death Machine to the Gift of Death so that var is never set. With
		// infiniteammo_on = 0 (falsy) the || falls through to the undefined
		// minigun var and throws — a per-frame error storm that stalls the
		// load at a black screen. IS_TRUE (shared.gsh) is (isdefined && x).
		if( ( IS_TRUE( level.zombie_vars[ "zombie_powerup_infiniteammo_on" ] ) || IS_TRUE( level.zombie_vars[ "zombie_powerup_minigun_on" ] ) ) && !IS_TRUE( self._show_solo_hud ) )
		{
			self._show_solo_hud = 1;
		}
		WAIT_SERVER_FRAME;
	}
}

function powerup_grab( player )
{	
	array::run_all( GetPlayers(), &PlaySound, INFINITEAMMO_POWERUP_SOUND );
    level thread powerup_activate( self, player );
}

//*****************************************************************************
// LOGIC
//*****************************************************************************

function powerup_activate( drop_item, player )
{
	time = TOD_INFINITEAMMO_SECS;   // [tod] 21 s, see the note at the #define

	if( level.zombie_vars[ "zombie_powerup_infiniteammo_on" ] )
	{
		if ( level.zombie_vars["zombie_powerup_infiniteammo_time"] < time )
		{
			level.zombie_vars["zombie_powerup_infiniteammo_time"] = time;
		}
		return;
	}
	level notify( "powerup_infiniteammo_notif" );
	level endon( "powerup_infiniteammo_notif" );

	level.zombie_vars["zombie_powerup_infiniteammo_on"] = 1;
	level.zombie_vars["zombie_powerup_infiniteammo_time"] = time;

	foreach( player in GetPlayers() )
		player thread powerup_logic();
	
	while( level.zombie_vars["zombie_powerup_infiniteammo_time"] > 0 )
	{
		wait( 0.05 );
		// [tod v19.76] the clock stops while the upgrade cards hold the world
		// (_tod_powerups::powerup_pause_hold has the map-wide list)
		if ( IS_TRUE( level.tod_upgrade_pause ) )
			continue;
		level.zombie_vars["zombie_powerup_infiniteammo_time"] = level.zombie_vars["zombie_powerup_infiniteammo_time"] - 0.05;
	}
	level thread powerup_deactivate( player );
}

function powerup_deactivate( player )
{
	level.zombie_vars["zombie_powerup_infiniteammo_on"] = 0;
	// [tod] v17.47: the pack's `player._show_solo_hud = 0` is REMOVED — same
	// reason as the timewarp module: a level-wide powerup was clearing the one
	// flag every grabber-only tray icon (ZOMBIE BLOOD) is gated on.

	level notify( "powerup_infiniteammo_notif" );
}

function powerup_logic()
{
	level endon( "powerup_infiniteammo_notif" );

	while( level.zombie_vars[ "zombie_powerup_infiniteammo_on" ] )
	{
		gun = self GetCurrentWeapon(); 
		goal = gun.clipsize; 
		self SetWeaponAmmoClip( gun, goal );

		WAIT_SERVER_FRAME;
	}
}