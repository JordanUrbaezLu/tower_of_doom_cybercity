// Dev-only native test client for inspecting the actual co-op staff pose.
// Stock ZM _zm::zbot_spawn uses AddTestClient; shared/bots/_bot uses
// BotDropClient and manual control. No replacement player animations or props.
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm;
#using scripts\zm\zm_tower_of_doom\_tod_classes;
#using scripts\zm\zm_tower_of_doom\_tod_mage_elements;
#insert scripts\shared\shared.gsh;
#namespace tod_dev_mage;

// THE ARCHMAGE LOOK FROM OUTSIDE (level.tod_dev_arch_test, 2026-10-01): the
// dummy shows the form's effect every this-many ms (visual only).
#define TOD_DEV_ARCH_PREVIEW_EVERY   30000
#define TOD_DEV_ARCH_PREVIEW_FIRST   8000

// THE CO-OP RESTART STAND-IN (level.tod_dev_coop_mock, 2026-10-01): the round the
// bot joins as a "teammate on another PC". Rounds before it are a solo game.
#define TOD_DEV_COOP_MOCK_ROUND   4

function enabled()
{
	return IS_TRUE( level.tod_dev ) && GetDvarInt( "tod_mage_dummy" ) == 1;
}

function log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) ) return;
	line = "[TOD_MAGE_DUMMY] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}

function remove( bot, reason )
{
	log( "REMOVE reason=" + reason );
	if ( isdefined( bot ) && bot IsTestClient() ) bot BotDropClient();
	level.tod_dev_mage_bot = undefined;
}

// The nearest clear ground beside the tester; refuse walls/ledge jumps.
function place( owner )
{
	angles = owner GetPlayerAngles();
	for ( i = 0; i < 4; i++ )
	{
		direction = AnglesToForward( ( 0, angles[1] + i * 90, 0 ) );
		point = GetClosestPointOnNavMesh( owner.origin + direction * 128, 64, 64 );
		if ( !isdefined( point ) || Abs( point[2] - owner.origin[2] ) > 32 ) continue;
		if ( DistanceSquared( point, owner.origin ) < 5184 ) continue;
		trace = BulletTrace( owner.origin + ( 0, 0, 48 ), point + ( 0, 0, 48 ), false, owner );
		if ( trace["fraction"] < 0.98 ) continue;
		return point + ( 0, 0, 2 );
	}
	return undefined;
}

function ready( bot )
{
	return isdefined( bot ) && IsAlive( bot ) && bot.sessionstate == "playing"
		&& IS_TRUE( bot.player_initialized ) && isdefined( bot.tod_levels );
}

function spawn_state( bot )
{
	if ( !isdefined( bot ) ) return "client=gone";
	return "player=" + bot GetEntityNumber() + " state=" + bot.sessionstate
		+ " alive=" + IsAlive( bot ) + " initialized=" + IS_TRUE( bot.player_initialized )
		+ " levels=" + isdefined( bot.tod_levels ) + " respawn=" + isdefined( bot.spectator_respawn );
}

function wait_ready( bot, owner )
{
	if ( !isdefined( bot ) || !IS_TRUE( bot.tod_dev_mage_dummy ) || !( bot IsTestClient() ) ) return false;
	// A late join briefly reports playing before stock parks it as a spectator.
	// User log: playing at 36.5s, spectator at 37s, old READY+REMOVE at 37.5s.
	// Wait for settled initialization, then use stock's normal spectator return
	// on ONLY our bot (_zm::spectator_respawn_player). Never fake sessionstate.
	stable_since = -1;
	last_state = "";
	attempts = 0;
	retry_at = GetTime() + 1500;
	for ( tick = 0; tick < 120 && enabled() && isdefined( owner ) && isdefined( bot ); tick++ )
	{
		state = spawn_state( bot );
		if ( state != last_state )
		{
			log( "WAIT " + state );
			last_state = state;
		}
		if ( ready( bot ) )
		{
			if ( stable_since < 0 ) stable_since = GetTime();
			if ( GetTime() - stable_since >= 1500 ) return true;
		}
		else
		{
			stable_since = -1;
			if ( bot.sessionstate == "spectator" && IS_TRUE( bot.player_initialized )
				&& isdefined( bot.spectator_respawn ) && attempts < 3 && GetTime() >= retry_at
				&& !IS_TRUE( level.tod_upgrade_pause ) )
			{
				attempts++;
				retry_at = GetTime() + 3000;
				log( "RESPAWN attempt=" + attempts + " " + state );
				bot thread zm::spectator_respawn_player();
			}
		}
		wait 0.25;
	}
	log( "FAIL spawn_not_settled enabled=" + enabled() + " host=" + isdefined( owner )
		+ " attempts=" + attempts + " " + spawn_state( bot ) );
	return false;
}

function show_staff( bot, index )
{
	names = array( "tod_staff_lightning_q0", "tod_staff_fire_q0", "tod_staff_ice_q0d0" );
	element = index % 3;
	packed = ( index >= 3 );
	base = tod_classes::weapon_or_zm( names[element] );
	if ( !isdefined( base ) || base == level.weaponNone )
	{
		log( "FAIL missing_weapon=" + names[element] );
		return false;
	}

	// Use normal per-owner PaP state, so upkeep cannot strip the displayed head.
	tod_classes::pap_tier_set( bot, base, Int( packed ) );
	want = tod_classes::staff_presentation( bot, base );
	if ( packed && !tod_classes::staff_is_packed( want ) )
	{
		log( "FAIL missing_packed_attachment=" + names[element] );
		return false;
	}
	foreach ( owned in bot GetWeaponsListPrimaries() )
	{
		if ( tod_classes::pap_staff_id( owned ) == element + 1 && owned != want )
			bot TakeWeapon( owned );
	}
	if ( !( bot HasWeapon( want ) ) ) bot give_staff( want );
	bot SwitchToWeaponImmediate( want );
	bot staff_log( want );
	log( "SHOW slot=" + ( index + 1 ) + " weapon=" + want.name + " packed=" + packed );
	return true;
}

function give_staff( weapon )
{
	self tod_classes::give_camo_weapon( weapon );
	self GiveStartAmmo( weapon );
}

function staff_log( weapon )
{
	self tod_classes::staff_presentation_log( weapon, "dev_dummy" );
}

function run()
{
	if ( !IS_TRUE( level.tod_dev ) ) return;
	level endon( "end_game" );
	SetDvar( "tod_mage_dummy", 1 );
	SetDvar( "tod_mage_dummy_slot", 0 ); // 0 = cycle; 1..3 base, 4..6 packed.
	log( "INIT rev=2 automatic=1 native_test_client=1 staff_assembly=base_tip_socket_3 world_crystal_glow=16_world_only" );
	while ( enabled() && !IS_TRUE( level.tod_class_select_done ) ) wait 0.25;
	if ( IS_TRUE( level.tod_dev_coop_mock ) ) coop_mock_wait();
	// Let the first deal / dev-max loadout finish before introducing a second slot.
	wait 6;
	while ( enabled() && IS_TRUE( level.tod_upgrade_pause ) ) wait 0.25;
	if ( !enabled() ) return;
	owner = util::GetHostPlayer();
	if ( !isdefined( owner ) || !IsAlive( owner ) || GetPlayers().size >= 4 )
	{
		log( "FAIL no_live_host_or_free_slot" );
		return;
	}
	if ( isdefined( level.tod_dev_mage_bot ) ) return;
	point = place( owner );
	if ( !isdefined( point ) )
	{
		log( "FAIL no_clear_ground_near_host" );
		owner IPrintLnBold( "DEV: no clear ground for Mage dummy" );
		return;
	}
	bot = AddTestClient();
	if ( !isdefined( bot ) )
	{
		log( "FAIL AddTestClient returned undefined" );
		owner IPrintLnBold( "DEV: could not add Mage test player" );
		return;
	}
	level.tod_dev_mage_bot = bot;
	bot.tod_dev_mage_dummy = true;
	bot.pers["isBot"] = true;
	bot.equipment_enabled = false;
	bot.tod_class = "mage"; // Set before native on_spawned can randomize a late join.
	bot.tod_tier = 3;
	bot.ignoreme = true; // Stock ZM's player protection flag (_zm.gsc).
	log( "ADD player=" + bot GetEntityNumber() );
	if ( !wait_ready( bot, owner ) )
	{
		remove( bot, "spawn_timeout_or_cancel" );
		return;
	}
	// The host may have walked away while stock initialized/respawned the bot.
	point = place( owner );
	if ( !isdefined( point ) )
	{
		owner IPrintLnBold( "DEV: no clear ground for Mage dummy" );
		remove( bot, "no_clear_ground_after_spawn" );
		return;
	}
	tod_classes::assign_class( bot, "mage" );
	bot BotTakeManualControl();
	bot BotSetMoveMagnitude( 0 );
	bot BotReleaseButtons();
	bot SetOrigin( point );
	angles = VectorToAngles( owner.origin - point );
	bot SetPlayerAngles( ( 0, angles[1], 0 ) );
	bot EnableInvulnerability();
	log( "READY " + spawn_state( bot ) + " origin=" + point );
	owner IPrintLnBold( "DEV: Mage dummy ready - cycling staffs every 12 seconds" );
	if ( IS_TRUE( level.tod_dev_coop_mock ) ) coop_mock_joined( owner, bot );
	index = 0;
	shown = -1;
	next = 0;
	arch_next = GetTime() + TOD_DEV_ARCH_PREVIEW_FIRST;
	if ( IS_TRUE( level.tod_dev_arch_test ) )
		owner IPrintLnBold( "DEV: the dummy shows the Archmage effect every 30 seconds" );
	while ( enabled() && isdefined( owner ) && ready( bot ) )
	{
		// Pause our display changes with the real game, including upgrade cards.
		if ( !IS_TRUE( level.tod_upgrade_pause ) )
		{
			if ( IS_TRUE( level.tod_dev_arch_test ) && GetTime() >= arch_next )
			{
				level thread tod_mage_elements::dev_arch_preview( bot );
				arch_next = GetTime() + TOD_DEV_ARCH_PREVIEW_EVERY;
			}
			bot BotSetMoveMagnitude( 0 );
			bot BotReleaseButtons();
			bot.ignoreme = true;
			bot EnableInvulnerability();
			selected = GetDvarInt( "tod_mage_dummy_slot" );
			if ( selected >= 1 && selected <= 6 ) index = selected - 1;
			else if ( GetTime() >= next && shown >= 0 ) index = ( index + 1 ) % 6;
			if ( shown != index )
			{
				if ( !show_staff( bot, index ) ) break;
				shown = index;
				next = GetTime() + 12000;
			}
		}
		wait 0.25;
	}
	log( "STOP enabled=" + enabled() + " host=" + isdefined( owner ) + " " + spawn_state( bot ) );
	remove( bot, "disabled_disconnected_or_dead" );
}

// ============================================================================
// THE CO-OP RESTART STAND-IN (level.tod_dev_coop_mock, 2026-10-01; user: "Ill
// also need a way to test coop so maybe we can mock players best possible. I need
// to test the restart button"). Only reachable from run() above, which is
// tod_dev-only. _tod_gameover::coop_mock_teammate is what makes the bot count as
// a teammate on ANOTHER PC; these three only pace and stage it.

// Solo until the stand-in's round, so one build tests both restart lanes.
function coop_mock_wait()
{
	log( "COOP_MOCK solo until round " + TOD_DEV_COOP_MOCK_ROUND );
	host = util::GetHostPlayer();
	if ( isdefined( host ) )
		host IPrintLnBold( "DEV CO-OP TEST: solo until round " + TOD_DEV_COOP_MOCK_ROUND + ", then a fake teammate joins" );
	while ( enabled() && ( !isdefined( level.round_number ) || level.round_number < TOD_DEV_COOP_MOCK_ROUND ) )
		wait 0.5;
}

function coop_mock_joined( owner, bot )
{
	log( "COOP_MOCK JOINED player=" + bot GetEntityNumber() + " counts_as=remote_teammate restart_lane=server" );
	owner IPrintLnBold( "DEV CO-OP TEST: fake teammate joined - Restart now uses the online co-op path" );
	level thread coop_mock_wipe_watch( bot );
}

// The stand-in cannot die, and stock ends the game only when EVERY player is down
// (_zm.gsc player_damage_override), so it alone would keep the game going for
// ever. Once every real player is down, end it the way stock ends a wiped party,
// as if the remote teammate were down too: the game-over menu then opens with the
// stand-in still connected, so Restart Map / End Game take the online co-op lane.
function coop_mock_wipe_watch( bot )
{
	level endon( "end_game" );
	while ( isdefined( bot ) )
	{
		if ( coop_mock_all_down() )
		{
			wait 1.5;
			if ( !isdefined( bot ) || !coop_mock_all_down() )
				continue;
			log( "COOP_MOCK WIPE every real player down -> end_game (the stand-in counts as down too)" );
			level notify( "pre_end_game" );
			util::wait_network_frame();
			level notify( "end_game" );
			return;
		}
		wait 0.25;
	}
}

function coop_mock_all_down()
{
	humans = 0;
	foreach ( p in GetPlayers() )
	{
		if ( !isdefined( p ) || ( p IsTestClient() ) )
			continue;
		humans++;
		if ( !( p laststand::player_is_in_laststand() ) && p.sessionstate != "spectator" )
			return false;
		// stock's solo Quick Revive is about to get them back up
		if ( ( p HasPerk( "specialty_quickrevive" ) ) && level flag::get( "solo_game" ) )
			return false;
	}
	return ( humans > 0 );
}
