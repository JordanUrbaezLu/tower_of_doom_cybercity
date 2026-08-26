// =============================================================================
// _tod_main.gsc — orchestrator for the small stuff (proof-of-life banner,
// dev sandbox). Grows as [tod] systems are added; each new module gets its own
// file + a scriptparsetree line in zone_source/zm_tower_of_doom.zone.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm_score;
// DEV-ONLY reach (dev_crown_test): the stock power entry point and the perk
// unpause it is always paired with, plus the crown's generated anchors and the
// finale's gate. All four are behind level.tod_dev; with it false nothing here
// runs, but the #usings stay so the file always compiles either way.
#using scripts\zm\_zm_power;
#using scripts\zm\_zm_perks;
#using scripts\zm\zm_tower_of_doom\_tod_crown_data;
#using scripts\zm\zm_tower_of_doom\_tod_doors;
#using scripts\zm\zm_tower_of_doom\_tod_finale;

#using scripts\zm\zm_tower_of_doom\_tod_zombie_speed;
#using scripts\zm\zm_tower_of_doom\_tod_perk_lights;
#using scripts\zm\zm_tower_of_doom\_tod_classes;
#using scripts\zm\zm_tower_of_doom\_tod_upgrades;
#using scripts\zm\zm_tower_of_doom\_tod_runandgun;   // RUN AND GUN (skirmisher ammo saver, domain 23)
#using scripts\zm\zm_tower_of_doom\_tod_uniques;     // CLASS TIER uniques: fire-streak + sprint watchers (docs/25 §9)
#using scripts\zm\zm_tower_of_doom\_tod_atmosphere;
#using scripts\zm\zm_tower_of_doom\_tod_ammo_crate;   // buyable ammo at every breather (2026-08-24)

#insert scripts\shared\shared.gsh;

#namespace tod_main;

function init()
{
	level endon( "end_game" );

	// Sprint-from-round-1 speed curve (registers its spawn callback; safe pre-blackscreen)
	tod_zombie_speed::init();
	// Perk machine + PaP power-on glow auras (waits for the power flag itself)
	tod_perk_lights::init();
	// Class system (3 classes, base-arena select stations) + the upgrade tower
	tod_classes::init();
	tod_upgrades::init();
	// (CHAIN LUNGE removed 2026-08-24 — user: "it doesnt work". _tod_lunge.gsc
	// is off the zone; see the note at its old add_domain in _tod_upgrades.gsc.)
	// RUN AND GUN: per-player weapon_fired watcher (registers on_spawned; safe pre-blackscreen)
	tod_runandgun::init();
	// CLASS TIER uniques: fire-streak + sprint-edge watchers (on_spawned; safe pre-blackscreen)
	tod_uniques::init();
	// The neon city smog (thick at street level, clear by mid-tower)
	tod_atmosphere::init();
	// AMMO CRATE on each breather balcony (waits for the blackscreen itself)
	tod_ammo_crate::init();

	level flag::wait_till( "initial_blackscreen_passed" );

	// Proof-of-life: the build is live and module init ran.
	welcome_banner();

	if ( IS_TRUE( level.tod_dev ) )
	{
		// dev_crown_test() REMOVED AGAIN 2026-08-26, after the user's ending
		// retest passed. It is a throwaway harness for testing the top of the
		// map (open every door, force power through the stock entry point, open
		// the causeway gate, warp everyone to the terrace on spawn and on every
		// respawn) and it has now been written-then-deleted twice. Do NOT re-add
		// it inline or leave it dormant behind tod_dev; write it fresh if the
		// ending needs testing again. Recipe, so it is cheap to re-derive:
		//   tod_doors::dev_open_all_doors()          — flags AND slabs AND navmesh
		//   zm_power::turn_power_on_and_open_doors() — never poke "power_on" by
		//   zm_perks::perk_unpause_all_perks()         hand; it leaves perks paused
		//   tod_finale::gate_open()                  — else risers past it are cut
		//   callback::on_spawned( &warp )            — respawn too, not just spawn
		// Terrace centre is ( 0, 368, 19400 ), yaw 90, clear of the station.
		level thread dev_money_loop();
	}

}


// (welcome text removed 2026-08-20 — user: no floaty text; the stub stays
// because init() still calls it as a proof-of-life marker.)
function welcome_banner()
{
}

// DEV ONLY (level.tod_dev hardcoded true + rebuild): keep everyone rich so
// doors/perks/box can be tested without farming.
function dev_money_loop()
{
	level endon( "end_game" );
	for ( ;; )
	{
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			player = players[ i ];
			if ( isdefined( player ) && isdefined( player.score ) && player.score < 100000 )
				player zm_score::add_to_player_score( 100000 - player.score );
		}
		wait 2;
	}
}
