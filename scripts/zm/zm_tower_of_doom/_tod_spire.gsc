// =============================================================================
// _tod_spire.gsc — THE ENDLESS SPIRE (docs/44, user 2026-08-29: "once you beat
// the game you will get all perks and all power ups for your class maxed out.
// And you can continue playing" + "a teleporter in the crown room that
// activates once you beat the map ... a tower that goes up 100 floors ...
// Once players teleport they cant go back").
//
// THE FLOW. The finale's win no longer auto-departs: _tod_finale's choice
// phase offers EXTRACT (the existing ending) or ASCEND — this module owns the
// ASCEND half and everything after it. The two halves talk ONLY through level
// notifies ("tod_choice_begin" / "tod_ascend" / "tod_extract"), deliberately:
// _tod_finale does not #using this file and this file does not #using
// _tod_finale, so there is no import cycle and either module degrades to a
// no-op without the other (finale falls back to auto-depart when
// level.tod_spire_ready is unset).
//
// THE SEQUENCE on ascend:
//   1. the dais teleporter fires (the _tod_teleport recipe: charge -> flash ->
//      warp) and EVERYONE goes — living on the arrival ring, downed dragged
//      along like gather_to_centre does at the seal. One-way by construction:
//      no return pad exists.
//   2. THE TOWER DIES BEHIND YOU — the teardown deletes the old world's
//      script-spawned entity load (door slabs + triggers, teleporter triggers
//      + beams, the finale's props). This is an ENTITY BUDGET, not fiction:
//      the ~1024-slot gentity table is the spire's binding constraint
//      (docs/44 §4, map 1's G_Spawn crash) and the freed slots are what the
//      spire's own vendors spend.
//   3. THE GRANT: class tiers climbed to T3 via the real tier_up path, the
//      free-PaP latch set (reconcile pulls the _up form), every eligible
//      domain to its per-class cap through the same fields the card picker
//      writes, all perks the map sells, full ammo, full health.
//   4. THE SWAP: music -> the spire loop (single band row; the Panzer
//      override rides unchanged), perk machines -> the spire pad pool (the
//      scatter's own apply_scatter does the move), PaP vendors + crates ->
//      the hubs, spawn pacing -> hot (read by _tod_endless_rounds).
//   5. THE CLIMB: 100 doors at the original ladder's cap, sequential — so
//      exactly ONE door has live buy triggers at any moment; crates ride a
//      player-position window. Both are the lazy-entity discipline the
//      budget demands.
//   6. THE END: wipe -> the "THE CLIMB ENDS HERE" screen (they beat the game;
//      they fall as sovereigns) — or the SUMMIT EXTRACTION at floor 100
//      (7500, the roof door's price): the chosen ending, "YOU CONQUERED THE
//      SPIRE".
//
// Geometry + anchors ride in from GENERATED _tod_spire_data.gsc (the
// door-data no-drift contract). The spire brushes themselves are behind the
// generator's SPIRE_ENABLED flag — this module NO-OPS (init returns) when the
// door slabs are absent, so script and geometry can ship independently.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;

#using scripts\zm\zm_tower_of_doom\_tod_spire_data;
#using scripts\zm\zm_tower_of_doom\_tod_crown_data;
#using scripts\zm\zm_tower_of_doom\_tod_doors;         // door_price (one pricing rule map-wide)
#using scripts\zm\zm_tower_of_doom\_tod_teleport;      // pad assembly + fx recipe (proven)
#using scripts\zm\zm_tower_of_doom\_tod_perk_scatter;  // make_pad/apply_scatter + derez/sound hosts
#using scripts\zm\zm_tower_of_doom\_tod_perk_lights;   // set_glow (the aura clientfield)
#using scripts\zm\zm_tower_of_doom\_tod_atmosphere;    // channel_play / add_music_band
#using scripts\zm\zm_tower_of_doom\_tod_upgrades;      // tier_up + the domain fields (the grant)
#using scripts\zm\zm_tower_of_doom\_tod_upgrade_ui;    // domain_id (pause-menu sync on the grant)
#using scripts\zm\zm_tower_of_doom\_tod_classes;       // tier / tier_max
#using scripts\zm\zm_tower_of_doom\_tod_powerups;      // breather_pap_place (the hub vendors)
#using scripts\zm\zm_tower_of_doom\_tod_ammo_crate;    // crate_clips + use_loop (the hub/shelf crates)

#insert scripts\shared\shared.gsh;

// AFTER every #using/#insert — between them kills the compile ("No generated
// data", the map's own dialect trap).
#precache( "material", "tod_choice_banner" );
#precache( "material", "tod_spire_banner" );
#precache( "material", "tod_spire_over_banner" );
#precache( "material", "tod_spire_win_banner" );
#precache( "material", "tod_spire_emblem" );
#precache( "model", "p7_out_mech_spawn_pad_light_green" );   // summit extraction pad (zoned by the finale already)
#precache( "model", "west_ammo_crate_model" );               // shelf/hub crates (zoned by _tod_ammo_crate already)

// Hot pacing (docs/44 §6a, user: "aggression picks up ... rounds will fly by
// but zombies just keep coming non stop and quickly"). Read by
// _tod_endless_rounds::tod_spawn_delay while level.tod_spire_active. 0.18 =
// sustained finale pressure (the finale's own phased band is 0.4 -> 0.1);
// tune HERE, nowhere else.
#define TOD_SPIRE_SPAWN_FLOOR     0.18
// The crate window: shelves exist on floors 5+ (hubs excluded); crates
// materialize for floors within this many of any player and de-rez beyond it.
#define TOD_SPIRE_CRATE_WINDOW    3
// aura colour indices (tod_perk_lights::perk_color_index table)
#define TOD_SPIRE_GLOW_RED        1
#define TOD_SPIRE_GLOW_GREEN     2

#namespace tod_spire;

function init()
{
	level endon( "end_game" );

	// GEOMETRY GATE: no spire slabs in the .map (generator SPIRE_ENABLED off)
	// = this whole module stands down. Script and geometry ship independently.
	probe = GetEnt( "tod_spire_door1", "targetname" );
	if ( !isdefined( probe ) )
		return;

	level flag::wait_till( "initial_blackscreen_passed" );

	// TWO PARITY SLABS, NOT 100 (the G_Spawn-at-init lesson, 2026-08-29 — see
	// the generator's spire door block). Odd slab starts at door 1, even at
	// door 2; door_manager SLIDES each +768z to its next same-parity doorway
	// after every buy. Both sealed + navmesh-cut now, the door contract.
	level.tod_spire_slab_odd = GetEnt( "tod_spire_door1", "targetname" );
	level.tod_spire_slab_even = GetEnt( "tod_spire_door2", "targetname" );
	level.tod_spire_slab_off_odd = 0;    // accumulated z offset per mover
	level.tod_spire_slab_off_even = 0;
	if ( isdefined( level.tod_spire_slab_odd ) )
	{
		level.tod_spire_slab_odd Solid();
		level.tod_spire_slab_odd DisconnectPaths();
	}
	if ( isdefined( level.tod_spire_slab_even ) )
	{
		level.tod_spire_slab_even Solid();
		level.tod_spire_slab_even DisconnectPaths();
	}

	// The zone-chain flags. The tower's enter_lapN flags are flag::init'd by
	// stock door_init off the map triggers; the spire has no map triggers, so
	// it inits its own. tod_ascension is the chain's root (roof_zone ->
	// spire_base_zone in the entry script's zone graph).
	if ( !( level flag::exists( "tod_ascension" ) ) )
		level flag::init( "tod_ascension" );
	for ( n = 1; n <= tod_spire_data::spire_laps(); n++ )
	{
		if ( !( level flag::exists( "enter_spire" + n ) ) )
			level flag::init( "enter_spire" + n );
	}

	level.tod_spire_ready = true;      // read by _tod_finale: choice replaces auto-depart
	level.tod_spire_active = false;
	level.tod_spire_door_max_z = 100;  // arena risers (z=0) only, until door 1

	level thread choice_watch();
}

// ---------------------------------------------------------------------------
// THE CHOICE — the ASCEND half. _tod_finale owns the EXTRACT half and the
// choice banners; this listens for the phase and stands the dais pad up.
// ---------------------------------------------------------------------------

function choice_watch()
{
	level endon( "end_game" );
	level waittill( "tod_choice_begin" );

	org = tod_spire_data::ascension_pad_org();

	// The dais teleporter — the Der Eisendrache assembly on the crown's focal
	// point (the dais the uplink left behind in v10), ignited only now.
	tod_teleport::spawn_der_teleporter( org, 0 );
	beam = tod_teleport::spawn_beam( org );
	tod_perk_scatter::derez_burst( org );
	tod_perk_scatter::play_sound_at_origin( org, "zmb_cha_ching", 4 );

	t = Spawn( "trigger_radius_use", org + ( 0, 0, 32 ), 0, 110, 96 );
	t TriggerIgnoreTeam();      // REQUIRED for a script-spawned use-trigger
	t SetCursorHint( "HINT_NOICON" );
	// Leads with the noun (PromptDefault strips the hold prefix). No cost —
	// they paid for this in blood already.
	t SetHintString( "Hold ^3[{+activate}]^7 ^5ASCEND^7 - to THE ENDLESS SPIRE ^1(one way)" );

	for ( ;; )
	{
		t waittill( "trigger", player );
		if ( !isdefined( player ) || !isplayer( player ) )
			continue;
		if ( !( zm_utility::is_player_valid( player ) ) )
			continue;
		if ( player zm_utility::in_revive_trigger() )
			continue;
		break;   // FIRST COMMITTED HOLD WINS for the whole party (approved design)
	}

	// Committed. The extract half stands down on this notify.
	level notify( "tod_ascend" );
	t SetHintString( "" );
	t TriggerEnable( false );

	// The teleport theater — the pad recipe at ascension scale.
	level thread tod_teleport::fx_burst( "tod_tp_charge", org + ( 0, 0, 40 ), 1.3 );
	tod_perk_scatter::play_sound_at_origin( org, "tod_teleport_fire", 4 );
	wait 0.8;
	tod_teleport::discharge( org );
	if ( isdefined( beam ) )
		beam Delete();
	t Delete();

	level thread ascend_run();
}

// ---------------------------------------------------------------------------
// THE ASCENSION
// ---------------------------------------------------------------------------

function ascend_run()
{
	level endon( "end_game" );

	arrival = tod_spire_data::arrival_org();

	// 1. EVERYONE GOES — living on the ring, downed dragged along (the
	// gather_to_centre precedent: a crawler who survived the siege has earned
	// the ride, and leaving one behind in a dead world is not a choice).
	players = GetPlayers();
	n = 0;
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		ang = n * 90;
		off = ( cos( ang ) * 56, sin( ang ) * 56, 0 );
		p SetOrigin( arrival + off );
		p SetPlayerAngles( ( 0, 0, 0 ) );   // facing +x: the first door, the climb
		n++;
	}
	tod_teleport::discharge( arrival );
	level thread tod_teleport::fx_burst( "tod_tp_kino", arrival + ( 0, 0, 4 ), 3.0 );

	// 2. THE WORLD FLIPS. Order matters: state fields first (the spawn systems
	// read them this frame), then the teardown, then the grant/vendors (which
	// SPEND the slots the teardown freed).
	level notify( "tod_ascension" );          // kills the finale pressure loop
	level flag::set( "tod_ascension" );       // roof_zone -> spire_base_zone chain root
	level.tod_spire_active = true;            // hot pacing + the spire spawn filter
	level.tod_choice_pending = undefined;

	// EVERY ZOMBIE DIES WITH THE TOWER (live test 2026-08-29: "we need to kill
	// all zombies on map and they need to start spawning on the endless spire").
	// Anything alive right now is 9,500+ units behind the party in a world
	// they left — stranded actors holding slots the spire needs.
	wipe_all_zombies();

	// SPAWNING RESUMES AT SPIRE PACE, THIS FRAME. Three writes, all needed:
	// the choice froze zombies via stock's world_is_paused and the boss
	// directors via tod_upgrade_pause (clear both), and
	// zombie_vars["zombie_spawn_delay"] is what round_spawning actually SLEEPS
	// on mid-round — the per-round resolver alone leaves the old delay
	// marinating until the next rollover (the live-test no-spawn deadlock).
	// 0.18 = TOD_SPIRE_SPAWN_FLOOR, the lockstep pair in _tod_endless_rounds.
	level.tod_upgrade_pause = false;
	if ( level flag::exists( "world_is_paused" ) )
		level flag::clear( "world_is_paused" );
	level.zombie_vars[ "zombie_spawn_delay" ] = TOD_SPIRE_SPAWN_FLOOR;

	// TARGETABILITY INSURANCE: re-derive ignoreme from stock's own refcount
	// (the _tod_powerups pattern — never stomp the count, the laststand trap).
	// A latched ignoreme is the classic every-enemy-ignores-you cause; the
	// dev probe below reports it if it ever recurs.
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		p.ignoreme = ( isdefined( p.ignorme_count ) && p.ignorme_count > 0 );
	}
	level.tod_finale_aggro = false;
	level.tod_finale_holdout = false;
	level.tod_crown_sealed = false;           // the hall-only spawn filter dies with the tower
	level.tod_finale_spawn_floor = undefined;
	level.tod_finale_pressure_tick = undefined;
	level.tod_rp_force_orgs = undefined;
	level.tod_boss_force_org = undefined;
	// The song clock is over — stale fields would leave the tower gauge
	// drawing a dead finale bar for the whole endless run.
	level.tod_finale_song_start = undefined;
	level.tod_finale_song_end = undefined;
	level.tod_upgrades_suppressed = true;     // every card is maxed; there is nothing to roll
	level.custom_game_over_hud_elem = &spire_game_over;

	// MUSIC: the finale latch dies, the band table becomes ONE row, the latch
	// resets, and the spire loop takes the channel. The Panzer override rides
	// the same boss_track_start/end refcount it always did.
	level.tod_finale_music = undefined;
	level.tod_music_bands = [];
	tod_atmosphere::add_music_band( 0, "tod_music_spire" );
	level.tod_music_floor = 0;
	tod_atmosphere::channel_play( "tod_music_spire" );

	teardown_tower();

	// 3. THE GRANT — every player, sequenced (tier_up serializes weapon swaps
	// internally; two players granting in parallel is fine, one player's own
	// steps are not).
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		p thread grant_all();
	}

	// 4. THE SPIRE'S OWN SYSTEMS.
	scatter_to_spire();
	spawn_hub_vendors();
	level thread door_manager();
	level thread crate_window();
	level thread summit_station();

	// 5. Say where they are. One banner, six seconds, then the climb speaks
	// for itself.
	level thread arrival_banners();

	// DEV DIAGNOSIS (live report 2026-08-29: "Zombies are spawning but do not
	// target me. No enemy targets me."). Names the mechanism instead of
	// guessing at it: per tick, the nearest zombie's distance, whether it holds
	// a target, and the player's own validity flags. tod_dev-gated; ships silent.
	if ( IS_TRUE( level.tod_dev ) )
		level thread dev_target_probe();
}

function dev_target_probe()
{
	level endon( "end_game" );
	for ( ;; )
	{
		wait 3;
		players = GetPlayers();
		p = undefined;
		for ( i = 0; i < players.size; i++ )
		{
			if ( isdefined( players[ i ] ) && isplayer( players[ i ] ) && isalive( players[ i ] ) )
			{
				p = players[ i ];
				break;
			}
		}
		if ( !isdefined( p ) )
			continue;
		zs = GetAISpeciesArray( "all" );
		best = undefined;
		bd = 999999;
		n = 0;
		for ( i = 0; i < zs.size; i++ )
		{
			z = zs[ i ];
			if ( !isdefined( z ) || !isalive( z ) )
				continue;
			n++;
			d = Distance( z.origin, p.origin );
			if ( d < bd )
			{
				bd = d;
				best = z;
			}
		}
		line = "probe: ai=" + n + " ign=" + ( ( IS_TRUE( p.ignoreme ) ) ? 1 : 0 ) + " valid=" + ( ( zm_utility::is_player_valid( p, true ) ) ? 1 : 0 );
		if ( isdefined( best ) )
			line = line + " near=" + int( bd ) + " fav=" + ( ( isdefined( best.favoriteenemy ) ) ? 1 : 0 ) + " ignall=" + ( ( IS_TRUE( best.ignoreall ) ) ? 1 : 0 );
		IPrintLn( line );
	}
}

// The seal's own wipe recipe (_tod_finale::wipe_the_map — cloned, not
// imported: the notify contract keeps these modules import-free of each other).
function wipe_all_zombies()
{
	ai = GetAISpeciesArray( "all" );
	for ( i = 0; i < ai.size; i++ )
	{
		e = ai[ i ];
		if ( !isdefined( e ) || !isalive( e ) )
			continue;
		e Kill();
	}
}

// ---------------------------------------------------------------------------
// THE TEARDOWN — "the tower dies behind you" (docs/44 §4 rule 2). Deletes the
// old world's TRACKED script-spawned entity load. Untracked cosmetics (crate
// models, teleporter assemblies, station meshes) stay — they cost nothing we
// need back, and nobody is ever there to see them again.
// ---------------------------------------------------------------------------

function teardown_tower()
{
	// Every tower door: both buy triggers, the slab (bought slabs are Hidden
	// but still hold gentity slots), and the dead map trigger.
	if ( isdefined( level.tod_doors_by_flag ) )
	{
		keys = GetArrayKeys( level.tod_doors_by_flag );
		for ( i = 0; i < keys.size; i++ )
		{
			d = level.tod_doors_by_flag[ keys[ i ] ];
			if ( !isdefined( d ) )
				continue;
			if ( isdefined( d.tod_trigs ) )
			{
				for ( j = 0; j < d.tod_trigs.size; j++ )
				{
					if ( isdefined( d.tod_trigs[ j ] ) )
						d.tod_trigs[ j ] Delete();
				}
			}
			if ( isdefined( d.tod_slab ) )
			{
				// An unbought slab is Solid + DisconnectPaths — reconnect
				// before deleting or the navmesh stays cut at a doorway that
				// no longer exists (ConnectPaths is not refcounted, but the
				// slab's cut is its own).
				d.tod_slab ConnectPaths();
				d.tod_slab Delete();
			}
			d Delete();
			if ( ( i % 8 ) == 0 )
				wait 0.05;   // spread the navmesh reconnects
		}
		level.tod_doors_by_flag = undefined;
	}

	// The teleporter network: triggers + idle beams (the assemblies are
	// untracked cosmetics and stay).
	if ( isdefined( level.tod_tp_trigs ) )
	{
		for ( i = 0; i < level.tod_tp_trigs.size; i++ )
		{
			t = level.tod_tp_trigs[ i ];
			if ( !isdefined( t ) )
				continue;
			if ( isdefined( t.tod_tp_beam ) )
				t.tod_tp_beam Delete();
			t Delete();
		}
		level.tod_tp_trigs = [];
	}

	// The finale's props and triggers.
	if ( isdefined( level.tod_finale_uplink ) )
		level.tod_finale_uplink Delete();
	if ( isdefined( level.tod_finale_uplink_clip ) )
	{
		level.tod_finale_uplink_clip ConnectPaths();
		level.tod_finale_uplink_clip Delete();
	}
	if ( isdefined( level.tod_finale_uplink_trig ) )
		level.tod_finale_uplink_trig Delete();
	if ( isdefined( level.tod_finale_pad_trig ) )
		level.tod_finale_pad_trig Delete();
	if ( isdefined( level.tod_finale_pad ) )
		level.tod_finale_pad Delete();
	if ( isdefined( level.tod_finale_beacon ) )
		level.tod_finale_beacon Delete();
	if ( isdefined( level.tod_finale_pylons ) )
	{
		for ( i = 0; i < level.tod_finale_pylons.size; i++ )
		{
			if ( isdefined( level.tod_finale_pylons[ i ] ) )
				level.tod_finale_pylons[ i ] Delete();
		}
		level.tod_finale_pylons = [];
	}
	if ( isdefined( level.tod_finale_sconces ) )
	{
		for ( i = 0; i < level.tod_finale_sconces.size; i++ )
		{
			if ( isdefined( level.tod_finale_sconces[ i ] ) )
				level.tod_finale_sconces[ i ] Delete();
		}
		level.tod_finale_sconces = [];
	}
	if ( isdefined( level.tod_avenue_hosts ) )
	{
		for ( i = 0; i < level.tod_avenue_hosts.size; i++ )
		{
			if ( isdefined( level.tod_avenue_hosts[ i ] ) )
				level.tod_avenue_hosts[ i ] Delete();
		}
		level.tod_avenue_hosts = [];
	}
}

// ---------------------------------------------------------------------------
// THE GRANT. self = player. Uses the REAL paths for everything — tier_up for
// promotions, the free-PaP latch reconcile consumes, the same tod_levels
// fields the card picker writes — so no second progression system exists to
// drift from the first.
// ---------------------------------------------------------------------------

function grant_all()
{
	level endon( "end_game" );
	self endon( "disconnect" );

	// 1. TIERS to the top. tier_card_eligible wants the current gun PaP'd —
	// the tod_pap_owned latch satisfies it (and reconcile then pulls the _up
	// form), which is exactly the lane the free-PaP drop proved.
	for ( guard = 0; guard < 4 && tod_classes::tier( self ) < tod_classes::tier_max(); guard++ )
	{
		self.tod_pap_owned = true;
		ok = tod_upgrades::tier_up( self );
		if ( !ok )
			break;   // ineligible (no class picked?) — grant what we can and move on
		wait 0.1;
	}

	// 2. The T3 gun Pack-a-Punched: the latch again; the body loop's reconcile
	// turns it into the _up form within a second.
	self.tod_pap_owned = true;

	// 3. Every eligible domain to this player's cap — through the same fields
	// + syncs tier_up's reset uses, so the pause-menu list stays truthful.
	if ( isdefined( level.tod_domains ) && isdefined( self.tod_levels ) )
	{
		for ( i = 0; i < level.tod_domains.size; i++ )
		{
			d = level.tod_domains[ i ];
			if ( !( tod_upgrades::domain_available( self, d ) ) )
				continue;
			cap = tod_upgrades::domain_max( self, d );
			if ( tod_upgrades::get_level( self, d.key ) >= cap )
				continue;
			self.tod_levels[ d.key ] = cap;
			// v14.13: sync_max packs the survives-promotion bit into the max
			// arg (the pause badge is server-computed now). Post-grant the
			// party is at top tier so every badge is suppressed anyway, but
			// the row data stays truthful either way.
			self LuiNotifyEvent( &"tod_upg_sync", 3, tod_upgrade_ui::domain_id( d.key ), cap, tod_upgrades::sync_max( self, d ) );
		}
	}
	self tod_upgrades::apply_move_speed();
	self tod_upgrades::reconcile_twin();
	self tod_upgrades::refresh_upgrade_list();

	// 4. EVERY PERK THE MAP SELLS: the live scatter roster (never a hardcoded
	// list — the lineup changed twice this week) plus the roof's Mule Kick.
	// (perk_purchase_limit is raised to cover the full roster at wiring.)
	specs = [];
	if ( isdefined( level.tod_scatter_machines ) )
		specs = GetArrayKeys( level.tod_scatter_machines );
	specs[ specs.size ] = "specialty_additionalprimaryweapon";
	for ( i = 0; i < specs.size; i++ )
	{
		if ( !isdefined( self ) )
			return;
		if ( self HasPerk( specs[ i ] ) )
			continue;
		self zm_perks::give_perk( specs[ i ], 0 );
		wait 0.15;   // stagger the grant FX/sounds
	}

	// 5. Ammo + health + the luck bar (irrelevant now — zeroed for the HUD).
	if ( !isdefined( self ) )
		return;
	weapons = self GetWeaponsListPrimaries();
	for ( i = 0; i < weapons.size; i++ )
		self GiveMaxAmmo( weapons[ i ] );
	if ( isalive( self ) && self.health < self.maxhealth )
		self SetNormalHealth( self.maxhealth );
	self.tod_luck_bar = 0;

	self PlayLocalSound( "tod_ultimate_sting" );
}

// ---------------------------------------------------------------------------
// THE PERK MACHINES CLIMB WITH YOU — the scatter's pad pool becomes the
// spire's (arena + 2 per hub), and its own every-4-rounds reshuffle carries on
// over the new table untouched. QR keeps its pin (now the arena pad): the
// solo-safety carve-out matters MORE up here, where a down costs every perk.
// ---------------------------------------------------------------------------

function scatter_to_spire()
{
	pads = [];
	arena = tod_spire_data::arena_perk_pads();
	// Machines back the arena N wall, facing south — the base row's exact
	// grammar (yaw 269.999 for the BO7 meshes, front = world -y).
	pads[ pads.size ] = tod_perk_scatter::make_pad( "spire arena (QR pin)", arena[ 0 ], 269.999, ( 0, -1, 0 ), "specialty_quickrevive", false );
	pads[ pads.size ] = tod_perk_scatter::make_pad( "spire arena (east)", arena[ 1 ], 269.999, ( 0, -1, 0 ), undefined, false );
	hubs = tod_spire_data::hub_laps();
	for ( i = 0; i < hubs.size; i++ )
	{
		z = tod_spire_data::hub_z( hubs[ i ] );
		hp = tod_spire_data::hub_perk_pads( z );
		// Hub pads back the balcony's S rail facing north — the breathers'
		// exact mirrored-frame grammar (yaw 90, front +y). Priority pads:
		// hubs fill before the arena spare, like breathers did.
		pads[ pads.size ] = tod_perk_scatter::make_pad( "spire hub " + hubs[ i ] + " (east)", hp[ 0 ], 90, ( 0, 1, 0 ), undefined, true );
		pads[ pads.size ] = tod_perk_scatter::make_pad( "spire hub " + hubs[ i ] + " (west)", hp[ 1 ], 90, ( 0, 1, 0 ), undefined, true );
	}
	level.tod_scatter_pads = pads;
	level.tod_scatter_where = [];    // machine_floor() reads undefined = fresh deal
	tod_perk_scatter::apply_scatter( true );   // b_initial: silent, fixed QR seated
}

// PaP at every hub — the ALXS vendor lane, registered late (the pack's
// register path is init-time-agnostic; its power watch finds power_on already
// set and lights up within a second).
function spawn_hub_vendors()
{
	hubs = tod_spire_data::hub_laps();
	for ( i = 0; i < hubs.size; i++ )
	{
		z = tod_spire_data::hub_z( hubs[ i ] );
		tod_powerups::breather_pap_place( tod_spire_data::hub_pap_org( z ), tod_spire_data::hub_pap_trig( z ), tod_spire_data::hub_pap_yaw() );
		// The hub crate — its collision clip is generator-cut into the .map
		// (label "spire hub lapN ammo crate body"), so this is model+trigger
		// only, exactly like the breather crates.
		spawn_crate( tod_spire_data::hub_crate_org( z ), tod_spire_data::hub_crate_yaw(), false );
	}
	// The arena crate: script clips (no generator clip at this spot — the
	// arena's own crate brush belongs to the arrival slab region).
	spawn_crate( tod_spire_data::arena_crate_org(), tod_spire_data::arena_crate_yaw(), true );
}

// One crate: model + use trigger (riding _tod_ammo_crate's own use_loop, so
// pricing/refusals stay one implementation) + optional script clips. Returns
// a struct so the window manager can de-rez shelf crates.
function spawn_crate( org, yaw, b_script_clips )
{
	c = SpawnStruct();
	m = Spawn( "script_model", org );
	if ( !isdefined( m ) )
		return undefined;   // entity pool full — a missing crate is buyable elsewhere
	m.angles = ( 0, yaw, 0 );
	m SetModel( "west_ammo_crate_model" );
	m SetScale( 2.5 );      // the map's tuned crate scale (TOD_CRATE_SCALE)
	if ( IS_TRUE( b_script_clips ) )
		tod_ammo_crate::crate_clips( m );

	t = Spawn( "trigger_radius_use", org + ( 0, 0, 40 ), 0, 72, 80 );
	t TriggerIgnoreTeam();
	t SetCursorHint( "HINT_NOICON" );
	// Keep in LOCKSTEP with _tod_ammo_crate's hint (TOD_CRATE_COST_BASE/PAP).
	t SetHintString( "Hold ^3[{+activate}]^7 ^5AMMO CRATE ^2[Cost: 2500 / PaP'd 5000]" );
	t thread tod_ammo_crate::use_loop();

	c.m = m;
	c.t = t;
	return c;
}

function delete_crate( c )
{
	if ( !isdefined( c ) )
		return;
	if ( isdefined( c.m ) )
	{
		if ( isdefined( c.m.tod_clips ) )
		{
			for ( i = 0; i < c.m.tod_clips.size; i++ )
			{
				if ( isdefined( c.m.tod_clips[ i ] ) )
				{
					c.m.tod_clips[ i ] ConnectPaths();
					c.m.tod_clips[ i ] Delete();
				}
			}
		}
		c.m Delete();
	}
	if ( isdefined( c.t ) )
		c.t Delete();
}

// ---------------------------------------------------------------------------
// THE DOORS — 100, sequential, ONE live at a time. The climb is strictly
// ordered (door n stands behind door n-1), so only the next door ever needs
// buy triggers: ~4 live gentities instead of 200 resident. The slab contract,
// the guards and the live pricing are _tod_doors' own, cloned because that
// module's per-door state machine assumes map triggers this lap has none of.
// ---------------------------------------------------------------------------

function door_manager()
{
	level endon( "end_game" );

	for ( n = 1; n <= tod_spire_data::spire_laps(); n++ )
	{
		info = tod_spire_data::get_spire_door_info( n );
		if ( !isdefined( info ) )
			return;

		t1 = spire_door_trigger( info.org + info.off, info );
		t2 = spire_door_trigger( info.org - info.off, info );

		// Whichever trigger lands the buy notifies; both then retire.
		level waittill( "tod_spire_door_bought" );
		if ( isdefined( t1 ) )
			t1 Delete();
		if ( isdefined( t2 ) )
			t2 Delete();

		if ( level flag::exists( info.flag ) )
			level flag::set( info.flag );   // zone chain + respawn groups

		// THE PARITY MOVER: open this doorway, then SLIDE the slab up to its
		// next same-parity door (+2 laps = pure +768z — same x/y by parity)
		// and re-seal there. Past the last serve, hide it for good. A brush
		// entity's .origin is an OFFSET from its authored position, so the
		// accumulated offset is tracked in a level field, never read back.
		if ( ( n % 2 ) == 1 )
			advance_parity_slab( level.tod_spire_slab_odd, n, "odd" );
		else
			advance_parity_slab( level.tod_spire_slab_even, n, "even" );

		// The riser gate: spawns may now rise up to this floor's landings —
		// and past the last door, the summit itself.
		if ( n >= tod_spire_data::spire_laps() )
			level.tod_spire_door_max_z = tod_spire_data::spire_summit_z() + 600;
		else
			level.tod_spire_door_max_z = tod_spire_data::spire_door_z( n ) + 400;
	}
}

function advance_parity_slab( slab, n, parity )
{
	if ( !isdefined( slab ) )
		return;
	slab Hide();
	slab NotSolid();
	slab ConnectPaths();
	if ( n + 2 > tod_spire_data::spire_laps() )
		return;   // no further door on this side — the mover retires open
	off = 2 * 384 * ( ( n + 1 ) / 2 );   // doors 1,3,5.. -> offsets 768,1536.. (int math: n odd => (n+1)/2 steps)
	if ( parity == "even" )
		off = 2 * 384 * ( n / 2 );
	slab.origin = ( 0, 0, off );
	slab Show();
	slab Solid();
	slab DisconnectPaths();
}

function spire_door_trigger( pos, info )
{
	t = Spawn( "trigger_radius_use", pos, 0, 96, 100 );
	if ( !isdefined( t ) )
		return undefined;
	t TriggerIgnoreTeam();
	t SetCursorHint( "HINT_NOICON" );
	// CONSTANT DESTINATION — the 250-triggerstring cap (2026-08-30). This used to
	// interpolate info.dest ("the Spire - Floor 1".."Floor 100"), minting ONE
	// PERMANENT BG-cache 'triggerstring' slot per floor climbed. The engine caps
	// that cache at 250 UNIQUE strings for the WHOLE MATCH and never frees a slot
	// — not on trigger Delete(), not between rounds — and the overflow blames
	// whoever registers NEXT, not the accumulator (map 1's Thundergun trap).
	// The tower already sits near ~242 by the time the finale is won, so the
	// spire did not need 100 floors to hard-error; it needed about EIGHT. This
	// mode was broken on arrival and nobody had reached it to report it.
	// The price stays: spire doors are a flat 3000, so it costs ONE string.
	// "Open Door to <dest>" shape kept EXACTLY — PromptDoors.lua parses the
	// destination out of it for the card title; "the Spire" is what it reads now.
	// If the floor number is ever wanted on screen, put it in an IPrintLnBold on
	// buy — chat prints provably do NOT feed this cache.
	t SetHintString( "Hold ^3[{+activate}]^7 Open Door to the Spire ^2[Cost: " + tod_doors::door_price( info.cost ) + "]" );
	t thread spire_door_buy( info );
	return t;
}

// self = trigger. The tower door loop's guards, verbatim — every one of them
// was paid for (revive presses, upgrade freezes, menu freezes).
function spire_door_buy( info )
{
	level endon( "end_game" );
	level endon( "tod_spire_door_bought" );
	for ( ;; )
	{
		self waittill( "trigger", player );
		if ( !isdefined( player ) || !IsPlayer( player ) )
			continue;
		if ( player zm_utility::in_revive_trigger() )
			continue;
		if ( !( zm_utility::is_player_valid( player ) ) )
			continue;
		if ( IS_TRUE( level.tod_upgrade_pause ) || IS_TRUE( player.tod_menu_frozen ) )
			continue;
		price = tod_doors::door_price( info.cost );
		if ( !( player zm_score::can_player_purchase( price ) ) )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
		player zm_score::minus_to_player_score( price );
		player PlaySound( "zmb_cha_ching" );
		level notify( "tod_spire_door_bought" );
		return;
	}
}

// ---------------------------------------------------------------------------
// THE CRATE WINDOW — "an ammo crate at every floor", at ~5 floors of live
// entities. Shelf crates materialize for floors near any player and de-rez
// beyond the window; their collision is script clips (a resident .map clip on
// an empty shelf would be the invisible-blocker defect the lint hunts).
// ---------------------------------------------------------------------------

function crate_window()
{
	level endon( "end_game" );

	crates = [];   // floor -> crate struct
	for ( ;; )
	{
		wait 2;

		// Which floors should hold a live crate right now?
		want = [];
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
				continue;
			if ( !( tod_spire_data::in_spire( p.origin ) ) )
				continue;
			f = 1 + int( p.origin[ 2 ] / 384 );
			for ( d = f - TOD_SPIRE_CRATE_WINDOW; d <= f + TOD_SPIRE_CRATE_WINDOW; d++ )
			{
				if ( isdefined( tod_spire_data::shelf_crate_org( d ) ) )
					want[ d ] = true;
			}
		}

		// De-rez crates that fell out of the window.
		keys = GetArrayKeys( crates );
		for ( i = 0; i < keys.size; i++ )
		{
			f = keys[ i ];
			if ( IS_TRUE( want[ f ] ) )
				continue;
			delete_crate( crates[ f ] );
			crates[ f ] = undefined;
		}

		// Materialize the window's missing crates.
		wkeys = GetArrayKeys( want );
		for ( i = 0; i < wkeys.size; i++ )
		{
			f = wkeys[ i ];
			if ( isdefined( crates[ f ] ) )
				continue;
			org = tod_spire_data::shelf_crate_org( f );
			if ( !isdefined( org ) )
				continue;
			crates[ f ] = spawn_crate( org, tod_spire_data::shelf_crate_yaw( f ), true );
		}
	}
}

// ---------------------------------------------------------------------------
// THE SUMMIT — floor 100's chosen ending (approved): extraction at the roof
// door's price. Survive the climb, buy the ride, win the mode.
// ---------------------------------------------------------------------------

function summit_station()
{
	level endon( "end_game" );

	org = tod_spire_data::summit_exfil_org();
	pad = Spawn( "script_model", org );
	if ( isdefined( pad ) )
	{
		pad SetModel( "p7_out_mech_spawn_pad_light_green" );
		tod_perk_lights::set_glow( pad, TOD_SPIRE_GLOW_GREEN );
	}
	beacon = Spawn( "script_model", tod_spire_data::beacon_org() );
	if ( isdefined( beacon ) )
	{
		beacon SetModel( "tag_origin" );
		tod_perk_lights::set_glow( beacon, TOD_SPIRE_GLOW_RED );
	}

	t = Spawn( "trigger_radius_use", org + ( 0, 0, 24 ), 0, 110, 96 );
	t TriggerIgnoreTeam();
	t SetCursorHint( "HINT_NOICON" );
	price = tod_doors::door_price( tod_spire_data::summit_cost() );
	t SetHintString( "Hold ^3[{+activate}]^7 ^2CALL EXTRACTION ^2[Cost: " + price + "]" );

	for ( ;; )
	{
		t waittill( "trigger", player );
		if ( !isdefined( player ) || !isplayer( player ) )
			continue;
		if ( !( zm_utility::is_player_valid( player ) ) )
			continue;
		if ( player zm_utility::in_revive_trigger() )
			continue;
		price = tod_doors::door_price( tod_spire_data::summit_cost() );
		if ( !( player zm_score::can_player_purchase( price ) ) )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
		player zm_score::minus_to_player_score( price );
		player PlaySound( "zmb_cha_ching" );
		break;
	}

	t SetHintString( "^2EXTRACTING...^7" );
	level thread summit_win( org, beacon );
}

function summit_win( org, beacon )
{
	// NO endon(end_game): this thread IS what ends the game (depart's rule).
	level.tod_spire_won = true;

	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		p EnableInvulnerability();
		p.ignoreme = true;
	}

	// Six seconds of send-off: the beacon strobes green over the world it
	// conquered, strike bursts walk the pad — depart_show's grammar.
	for ( k = 0; k < 15; k++ )
	{
		on = ( ( k % 2 ) == 0 );
		if ( isdefined( beacon ) )
			tod_perk_lights::set_glow( beacon, ( ( on ) ? TOD_SPIRE_GLOW_GREEN : 0 ) );
		if ( ( k % 3 ) == 0 )
			tod_perk_scatter::derez_burst( org );
		wait 0.4;
	}

	level notify( "end_game" );
}

// ---------------------------------------------------------------------------
// SCREENS. spire_game_over serves BOTH endings the spire owns — the summit
// win and the climb's death — switched on tod_spire_won. Geometry mirrors
// _tod_finale::escaped_game_over exactly (the proven layout).
// ---------------------------------------------------------------------------

function spire_game_over( player, game_over, survived )
{
	banner = "tod_spire_over_banner";
	if ( IS_TRUE( level.tod_spire_won ) )
		banner = "tod_spire_win_banner";

	game_over.alignX = "center";
	game_over.alignY = "middle";
	game_over.horzAlign = "center";
	game_over.vertAlign = "middle";
	game_over.y -= 130;
	game_over.foreground = true;
	game_over.alpha = 0;
	game_over.color = ( 1, 1, 1 );   // WHITE — the art carries its own colours
	game_over.hidewheninmenu = true;
	game_over SetShader( banner, 900, 225 );
	game_over FadeOverTime( 1 );
	game_over.alpha = 1;

	emblem = NewClientHudElem( player );
	if ( isdefined( emblem ) )
	{
		emblem.alignX = "center";
		emblem.alignY = "middle";
		emblem.horzAlign = "center";
		emblem.vertAlign = "middle";
		emblem.y = game_over.y - 150;
		emblem.foreground = true;
		emblem.color = ( 1, 1, 1 );
		emblem.hidewheninmenu = true;
		emblem.alpha = 0;
		emblem SetShader( "tod_spire_emblem", 128, 128 );
		emblem FadeOverTime( 1.4 );
		emblem.alpha = 1;
	}

	survived.alignX = "center";
	survived.alignY = "middle";
	survived.horzAlign = "center";
	survived.vertAlign = "middle";
	survived.y += 40;   // below the banner (the escaped screen's measured offset)
	survived.foreground = true;
	survived.fontScale = 2;
	survived.alpha = 0;
	survived.color = ( 1.0, 1.0, 1.0 );
	survived.hidewheninmenu = true;

	if ( player isSplitScreen() )
	{
		game_over SetShader( banner, 600, 150 );
		game_over.y += 40;
		survived.fontScale = 1.5;
		survived.y += 40;
	}
}

// The arrival announcement: one banner per player, six seconds, gone. A
// server hudelem (baked art, zero LUI bits — the 61-bit ceiling untouched).
function arrival_banners()
{
	level endon( "end_game" );

	elems = [];
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		e = NewClientHudElem( p );
		if ( !isdefined( e ) )
			continue;
		e.alignX = "center";
		e.alignY = "middle";
		e.horzAlign = "center";
		e.vertAlign = "middle";
		// 600x150 at y-130 (live report 2026-08-29 on the choice banner's
		// identical geometry: "too big and off the screen on the top") — the
		// old 720x180 at y-170 put the top edge at -260 against the 480-unit
		// virtual screen's -240; this tops out at -205 with margin.
		e.y -= 130;
		e.foreground = true;
		e.color = ( 1, 1, 1 );
		e.hidewheninmenu = true;
		e.alpha = 0;
		e SetShader( "tod_spire_banner", 600, 150 );
		e FadeOverTime( 1 );
		e.alpha = 1;
		elems[ elems.size ] = e;
	}

	wait 5;
	for ( i = 0; i < elems.size; i++ )
	{
		if ( isdefined( elems[ i ] ) )
		{
			elems[ i ] FadeOverTime( 1 );
			elems[ i ].alpha = 0;
		}
	}
	wait 1.1;
	for ( i = 0; i < elems.size; i++ )
	{
		if ( isdefined( elems[ i ] ) )
			elems[ i ] Destroy();
	}
}
