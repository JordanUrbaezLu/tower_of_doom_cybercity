// =============================================================================
// _tod_finale.gsc — THE ENDING (v9, user 2026-08-21: "design the top of the
// map and design the ending ... a path way to a sick looking crown house ...
// boss fight we wouldn't implement, maybe a buyable ending for now").
//
// WHERE: the CROWN — the floating citadel at the top of the tower (geometry in
// tools/gen_tower_map.js §5; every anchor point this file uses comes from the
// GENERATED _tod_crown_data.gsc, so the script can never drift from the .map).
//
// v10 — THE LAST MILE (user 2026-08-23: "the music starts and game ends when
// songs ends and you win ... players get to the top and players have around
// 3:40 minutes to get to the building so that road needs to be long and they
// get ambushed in all directions max aggressivness on spawns and all types of
// enemies").
//
// THE SEQUENCE (all diegetic — no on-screen text until the stock end screen,
// the map's standing rule):
//   1. THE UPLINK — the terminal on the TERRACE, where the crown stair puts you
//      down. Needs power, costs TOD_FINALE_COST, hold USE to buy. It sits at
//      the START of the road now, not the far end of it, because the thing it
//      starts is the run.
//   2. THE RUN — the closing song takes the music channel and IS the clock
//      (TOD_FINALE_SONG_SECS, measured off the wav). The causeway walks ~8220 units
//      (v12; the generator prints the live number on every regen) of open
//      road; _tod_bosses::finale_pressure_start drives the spawn rate to
//      its floor and cycles all three boss types, and the road's own risers
//      (gen_tower_map.js) put them on alternating flanks the whole way. Upgrade
//      events are suppressed so the clock cannot drift from the track.
//      THE CROWN ITSELF lights up one corner point per quarter — a progress
//      read visible from the road, from inside the hall and from the tower,
//      but the song is the real countdown. (v11: these used to be four coil
//      props on plinths in the middle of the hall. The user called them weird
//      and they were; the read moved out onto the circlet.)
//      >>> FUTURE BOSS FIGHT goes HERE: a module that sets
//      level.tod_finale_boss_fn owns the run and the win lands when it returns.
//   3. THE SONG ENDS — you survived it, so you won. The four crown beacons
//      flip green, the
//      EXTRACTION PAD swaps red->green, then TOD_FINALE_DEPART_SECS of
//      invulnerable departure (pylons strobe, strike bursts) and the game ends
//      on a custom "YOU ESCAPED THE TOWER" screen (stock still prints rounds).
//      There is no pad to hold and no gather-everyone check any more — see the
//      note above exfil_beacon for why that had to be DELETED rather than left.
//
// MECHANISMS REUSED (nothing new to trust): script-spawned trigger_radius_use
// with TriggerIgnoreTeam (doors/stations), the todPerkGlow clientfield aura
// (_tod_perk_lights::set_glow — server PlayFX never renders, the client
// aura does), the scatter's host-based strike burst + sound emitter, the
// atmosphere's stoppable music primitive, and stock _zm's
// level.custom_game_over_hud_elem callback (verified tmp/bo3_stock_ref
// _zm.gsc:6064). Hint strings only change on STATE change (config-string
// discipline: every distinct hint costs one).
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;

#using scripts\zm\zm_tower_of_doom\_tod_crown_data;
#using scripts\zm\zm_tower_of_doom\_tod_doors;           // door_price (party-size scaling for the extraction buy)
#using scripts\zm\zm_tower_of_doom\_tod_perk_lights;     // set_glow (the aura clientfield)
#using scripts\zm\zm_tower_of_doom\_tod_perk_scatter;    // derez_burst + play_sound_at_origin (host-based FX/SFX)
#using scripts\zm\zm_tower_of_doom\_tod_atmosphere;      // finale_track_start (the music channel)
#using scripts\zm\zm_tower_of_doom\_tod_bosses;          // finale_pressure_start (the ambush)
#using scripts\zm\zm_tower_of_doom\_tod_upgrade_ui;      // set_finale_warn (the road banner)

#insert scripts\shared\shared.gsh;

// Models: all carved T7 props already in the Mod Tools GDT DB (source_data/
// acc_t7_props_*.gdt, binaries verified on disk 2026-08-21). Script-spawned
// (SetModel) + `xmodel,` zone lines — never baked misc_models.
#precache( "model", "p7_zm_sta_dragon_network_data_terminal" );
// THE WIN SCREEN ART (2026-08-25). MATERIALS, not images: the game-over screen
// is a server HUDELEM and SetShader takes a material. The 2d_blend wrappers
// live in source_data/tod_ui_images.gdt beside the images they point at.
#precache( "material", "tod_win_banner" );
#precache( "material", "tod_win_emblem" );   // the uplink console
#precache( "model", "p7_out_mech_spawn_pad_light_red" );          // extraction pad, locked
#precache( "model", "p7_out_mech_spawn_pad_light_green" );        // extraction pad, live
#precache( "model", "p7_zm_asc_light_cage_warning_red" );         // mast beacon + the crown's 4 quarter beacons
#precache( "model", "p7_zm_moo_light_panel_01_long" );            // wall sconces

// Base price; charged through finale_cost() so it scales with party size like
// every door. (The old note here said "~270k of doors stand between spawn and
// this" — that was stale by 44%. The ladder was 186,975 when the audit summed
// it, and is 114,930 after the v10.4 rebalance.)
//
// 25,000 -> 12,000 (v10.11, user 2026-08-23: "at the end you need to call in
// extraction. Lets make that cheaper"). The price is no longer the gate it was:
// EXTRACTION now physically opens the causeway gate, so buying it is not the
// last thing you do with your points, it is the thing that lets you attempt the
// run at all. A player who saved 25k on top of a 114,930 ladder had already won
// the economy; the road is supposed to be what decides this, not the wallet.
#define TOD_FINALE_COST           12000
// THE LAST MILE (v10, user 2026-08-23): the closing song IS the clock. "the
// music starts and game ends when songs ends and you win."
//
// THE ARITHMETIC MATTERS, so do not "round it up" to the track length:
//
//   TOD_FINALE_SONG_SECS (191) + TOD_FINALE_DEPART_SECS (6) = 197
//   tod_music_finale.wav                                    = 197.395s
//
// The RUN is 191s; depart() then plays a 6s invulnerable flourish and ends the
// game. So the win screen lands with ~0.4s of track left — on the last chord,
// not after it. Setting this to the full 197 was the first cut and it was
// WRONG: the alias is LOOPING (it has to be — a non-looping streamed one-shot
// is engine-unstoppable, see _tod_atmosphere), so the departure would have
// played over the song's SECOND INTRO. If the track is ever replaced,
// re-measure it and re-derive this as (length - TOD_FINALE_DEPART_SECS) in the
// same commit.
// (The user asked for "around 3:40"; the track they chose is 3:17, and the
// track wins — it is the thing the player actually hears ending.)
#define TOD_FINALE_SONG_SECS      191
// REMOVED — THERE IS NO DEV CLOCK ANY MORE (2026-08-25). A shortened dev timer
// was added unasked and it was a mistake twice over: it shortened the TIMER but
// not the 197.4s WAV, so every dev run ended the game with most of the song
// still playing, and the ending could not be judged at all. The map now runs one
// clock in every build. If a future test needs to reach the ending quickly, warp
// the player — do NOT compress the clock, because the clock IS the ending.
#define TOD_FINALE_DEPART_SECS    6       // confirmed extract -> end screen

// THE TWO-PHASE ENDING (v10.26, user 2026-08-25). The run is no longer one long
// road - it is a RUN and then a SIEGE:
//   phase 1  THE ROAD      90s, or less if everyone reaches the Crown early
//   phase 2  THE HOLD-OUT  the rest of the song, sealed inside the citadel
//
// 90 + 101 = 191 = TOD_FINALE_SONG_SECS, and that is the whole point: the song
// is still the only clock, so the two phases MUST sum to it. The ask was
// 1:30 + 2:00, which is 210s against a 197.4s track - the track would have
// looped its intro under the ending, the exact failure the 191 was chosen to
// avoid. The 1:30 was kept and the hold-out takes the remainder.
// IF THE SONG EVER CHANGES: re-derive SONG_SECS from the wav's byte length,
// and HOLD_SECS falls out of it. Never set HOLD_SECS by hand.
#define TOD_FINALE_ROAD_SECS      90
#define TOD_FINALE_HOLD_SECS      ( TOD_FINALE_SONG_SECS - TOD_FINALE_ROAD_SECS )
// Where the party lands when the door seals. A RING, not a point: four players
// teleported onto one coordinate stack and shove each other apart.
// 160, NOT 72 (peer review 2026-08-25): the hall centre IS the uplink dais, a
// 112-half-width step 16 tall, so a 72 ring put every survivor inside the dais
// brush. 160 clears the dais completely. The four hall PILLARS returned in v12
// (bare posts, no coil models — pure scenery/cover): their footprints sit at
// (+-448, HYC+-448), nearest solid point 554 from hall centre, so the 160 ring
// plus a ~32 player hull clears them by >300 — the ring only has to beat DAIS.
#define TOD_FINALE_GATHER_RING    160
// Banner blink period. See warn_banner.
#define TOD_FINALE_WARN_BLINK     0.4

// ARRIVAL RADIUS — how close to the extraction pad counts as "inside the Crown".
// 1536 is the hall's own dimension, measured from the pad: it reaches every
// corner of the 1536-sq interior (the far south corners are ~1486 away) and the
// south gate at y=6900 (~1252). So it means "you are in the citadel", not "you
// are standing on the pad" — the pad has been a DESTINATION, not a control,
// since v10 deleted the gather-and-hold flow, and this keeps it that way.
#define TOD_FINALE_ARRIVE_RAD     1536

// How close a player has to be to the TERRACE uplink for it to start pulsing.
// 900 covers the terrace and the mouth of the causeway without firing while
// somebody is still on the crown stair below.
#define TOD_UPLINK_BEACON_RAD     900

// aura colour indices (tod_perk_lights::perk_color_index table)
#define TOD_GLOW_RED              1
#define TOD_GLOW_GREEN            2
#define TOD_GLOW_YELLOW           3
#define TOD_GLOW_TEAL             10

#namespace tod_finale;

function init()
{
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );

	// idle -> charging -> ready -> departing -> done
	level.tod_finale_state = "idle";

	spawn_props();
	gate_init();
	crown_door_init();


	level thread uplink_power_glow();
	level thread uplink_station();
	level thread exfil_beacon();
}

// ---------------------------------------------------------------------------
// Props
// ---------------------------------------------------------------------------

function prop( model, org, yaw )
{
	m = Spawn( "script_model", org );
	if ( !isdefined( m ) )
		return undefined;   // entity pool full — a missing prop is cosmetic, never throw
	m.angles = ( 0, yaw, 0 );
	m SetModel( model );
	return m;
}

function spawn_props()
{
	// the uplink console on the dais
	level.tod_finale_uplink = prop( "p7_zm_sta_dragon_network_data_terminal", tod_crown_data::uplink_org(), tod_crown_data::uplink_yaw() );

	// COLLISION (user 2026-08-25: "Add a clip to the extraction station. Its walk
	// through currently"). A script_model is VISUAL ONLY — the xmodel carries no
	// collision a player can stand against — so every vendor in this map spawns a
	// second entity to be its solid. Same recipe as the HEAVENLY GIFT ALTAR
	// (_tod_upgrades::station_place) and as stock's own perk machines
	// (_zm_perks.gsc:1551): a script_model wearing zm_collision_perks1, tagged
	// script_noteworthy "clip", DisconnectPaths'd.
	//
	// ONE BOX, NOT THE ALTAR'S THREE. The altar needed three because its mesh
	// FLARES to 104 wide at chest height; this terminal is a single console and
	// there is no measurement to justify widening it. I could not read its
	// bounds reliably — the model is a Greyhound export whose binary layout my
	// altar parser does not fit, and the fallback scan returned identical
	// distributions on all three axes, which is nonsense — so rather than size a
	// clip off a number I do not trust, this uses the standard vendor box and
	// leaves the terrace's open floor to absorb any overhang.
	//
	// DisconnectPaths is MANDATORY: the navmesh ignores entity collision
	// entirely, so without it the horde paths straight through the terminal.
	// Safe to solidify at init — nobody can be standing on the terrace yet.
	uclip = Spawn( "script_model", tod_crown_data::uplink_org(), 1 );
	if ( isdefined( uclip ) )
	{
		uclip.angles = ( 0, tod_crown_data::uplink_yaw(), 0 );
		uclip SetModel( "zm_collision_perks1" );
		uclip.script_noteworthy = "clip";
		uclip DisconnectPaths();
		level.tod_finale_uplink_clip = uclip;
	}

	// THE FOUR QUARTER BEACONS — one lights per quarter of the closing song.
	// Until v11 these were deathray coils on four 176-tall plinths in the middle
	// of the hall; the user's verdict was "4 pillars with this weird looking pipe
	// level model on top ... So weird". The COILS are gone for good; the bare
	// PILLARS returned in v12 as scenery/cover with no script contract — do not
	// hang anything on them. pylon_orgs() returns the CIRCLET's four corner
	// point caps (gen_tower_map.js 5f.4), so the progress read is the crown
	// lighting up around you rather than four pipes in the room. Same model as
	// the mast beacon: it is 2,432 units above the floor, the AURA is the read,
	// and reusing it costs no new asset.
	level.tod_finale_pylons = [];
	orgs = tod_crown_data::pylon_orgs();
	for ( i = 0; i < orgs.size; i++ )
	{
		p = prop( "p7_zm_asc_light_cage_warning_red", orgs[ i ], 0 );
		if ( isdefined( p ) )
			level.tod_finale_pylons[ level.tod_finale_pylons.size ] = p;
	}

	// the extraction pad light — red until the uplink is online
	level.tod_finale_pad = prop( "p7_out_mech_spawn_pad_light_red", tod_crown_data::exfil_org(), 0 );

	// the mast beacon: a warning light at the spire tip with a red aura — the
	// tower's own "you are here" seen from every lap below
	beacon = prop( "p7_zm_asc_light_cage_warning_red", tod_crown_data::mast_tip_org(), 0 );
	if ( isdefined( beacon ) )
	{
		level.tod_finale_beacon = beacon;
		tod_perk_lights::set_glow( beacon, TOD_GLOW_RED );
	}

	// wall sconces down both long walls
	so = tod_crown_data::sconce_orgs();
	sy = tod_crown_data::sconce_yaws();
	for ( i = 0; i < so.size; i++ )
		prop( "p7_zm_moo_light_panel_01_long", so[ i ], sy[ i ] );
}

// ---------------------------------------------------------------------------
// THE CAUSEWAY GATE (v10.11)
// ---------------------------------------------------------------------------
// user 2026-08-23: "the bridge should be completely cut off by a wall/door.
// Basically the extraction opens the door."
//
// The road does not exist until EXTRACTION is bought. This is not decoration:
// it is what makes the terrace a THRESHOLD instead of a fork in the path. The
// old shape let a player walk out onto 6,400 units of causeway, look at the
// citadel, walk back, and never touch the uplink — the run was opt-in and the
// uplink was a thing you could miss (which is exactly what happened in the live
// test that produced uplink_beacon below). With the gate closed there is one
// way forward and it is through the terminal.
//
// Same contract as every buyable door in _tod_doors: a generated
// script_brushmodel that starts Solid() + DisconnectPaths() and opens with
// Hide() + NotSolid() + ConnectPaths(). The DisconnectPaths half is the
// load-bearing one — navmesh ignores entity collision entirely, so without it
// the horde would happily path the road while the slab still blocks players.
function gate_init()
{
	level.tod_causeway_gate = GetEnt( "tod_causeway_gate", "targetname" );
	if ( !isdefined( level.tod_causeway_gate ) )
		return;   // generator drift — an open road is survivable, a script error is not

	level.tod_causeway_gate Solid();
	level.tod_causeway_gate DisconnectPaths();
	level.tod_gate_open = false;   // read by _tod_endless_rounds spawn filter
}

// Opened by finale_run, and by nothing else.
function gate_open()
{
	if ( !isdefined( level.tod_causeway_gate ) )
		return;

	// the brushmodel has no origin brush, so ask the generated data where it is
	org = tod_crown_data::causeway_gate_org();
	level.tod_causeway_gate Hide();
	level.tod_causeway_gate NotSolid();
	level.tod_causeway_gate ConnectPaths();
	level.tod_gate_open = true;    // the road is now a legal spawn destination

	// the same derez/chime pair every other opening in this map uses, so the
	// player on the terrace sees the road appear rather than just finding it gone
	tod_perk_scatter::derez_burst( org );
	tod_perk_scatter::play_sound_at_origin( org, "zmb_cha_ching", 4 );
}
// The uplink reads as LIVE once the power is on — the same aura convention as
// every perk machine (teal = generic/PaP).
// THE CROWN DOOR — the citadel's own gate, and the MIRROR IMAGE of the causeway
// gate above. That one starts SEALED and opens when you pay. This one starts
// OPEN, because the whole ending depends on being able to walk in, and it slams
// shut when the hold-out begins.
//
// It is generated (tools/gen_tower_map.js, "crown door") to fill the gate
// opening exactly: 256 wide by 256 tall between the two gate posts, which is
// the hole the south wall leaves. Nothing else is in that rectangle.
function crown_door_init()
{
	level.tod_crown_door = GetEnt( "tod_crown_door", "targetname" );
	if ( !isdefined( level.tod_crown_door ) )
	{
		// FAIL OPEN, AND SAY SO. A missing door means the siege never seals,
		// which is a worse ending but still a playable one; a script error here
		// would take the whole finale with it. (The causeway gate's equivalent
		// branch had the opposite bug - it returned before setting its flag, so
		// the road read as permanently shut to the spawn filter.)
		level.tod_crown_sealed = false;
		/# PrintLn( "^1[tod] crown door entity MISSING - the citadel cannot seal" ); #/
		return;
	}
	// OPEN at map start: hidden, non-solid, and the navmesh joined so the horde
	// can path in and out of the hall exactly as it could before this existed.
	level.tod_crown_door Hide();
	level.tod_crown_door NotSolid();
	level.tod_crown_door ConnectPaths();
	level.tod_crown_sealed = false;
}

// SEAL. Called only from finale_run, and only AFTER gather_to_centre() has
// pulled everyone out of the doorway - see the ordering comment there.
function crown_door_close()
{
	if ( !isdefined( level.tod_crown_door ) )
		return;
	level.tod_crown_door Show();
	level.tod_crown_door Solid();
	level.tod_crown_door DisconnectPaths();   // MANDATORY: the navmesh ignores
	                                          // entity collision entirely, so
	                                          // without this the horde walks
	                                          // straight through the shut door
	org = tod_crown_data::crown_door_org();
	tod_perk_scatter::derez_burst( org );
	tod_perk_scatter::play_sound_at_origin( org, "zmb_cha_ching", 4 );
}

function uplink_power_glow()
{
	level endon( "end_game" );
	while ( !( level flag::exists( "power_on" ) && level flag::get( "power_on" ) ) )
		wait 0.5;
	if ( isdefined( level.tod_finale_uplink ) )
		tod_perk_lights::set_glow( level.tod_finale_uplink, TOD_GLOW_TEAL );
}

function power_is_on()
{
	return ( level flag::exists( "power_on" ) && level flag::get( "power_on" ) );
}

// ---------------------------------------------------------------------------
// THE UPLINK — buy the ending
// ---------------------------------------------------------------------------

function uplink_station()
{
	level endon( "end_game" );

	t = spawn( "trigger_radius_use", tod_crown_data::uplink_org() + ( 0, 0, 30 ), 0, 110, 96 );
	t TriggerIgnoreTeam();       // REQUIRED for a script-spawned use-trigger
	t SetCursorHint( "HINT_NOICON" );
	level.tod_finale_uplink_trig = t;

	t thread uplink_hint_loop();
	t thread uplink_use_loop();
	level thread uplink_beacon();
}

// THE UPLINK HAS TO ANNOUNCE ITSELF (live test 2026-08-23). Its use-trigger is
// radius 110 on a terrace the player crosses in a couple of seconds, and the
// thing they can SEE from there is the causeway and the citadel at the end of
// it — so the natural line is to run the road, which is exactly backwards: the
// road is what the uplink STARTS. The user ran it, reached the pad, and could
// not finish the map.
//
// So while the run has not been bought, the terminal pulses whenever somebody is
// on the terrace: a derez burst and a chime, every few seconds, at the one thing
// they need to touch. No floaty text (standing rule) — this is the same
// host-based FX/SFX pair the scatter and the pylons already use, so it costs no
// new assets and nothing new to trust. It stops the moment the run starts.
function uplink_beacon()
{
	level endon( "end_game" );
	level endon( "tod_finale_start" );

	org = tod_crown_data::uplink_org();
	for ( ;; )
	{
		wait 4;
		if ( level.tod_finale_state != "idle" )
			continue;
		// Only when somebody is actually up here to see it — no pulsing to an
		// empty terrace for the whole run.
		near = false;
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
				continue;
			if ( DistanceSquared( p.origin, org ) <= ( TOD_UPLINK_BEACON_RAD * TOD_UPLINK_BEACON_RAD ) )
			{
				near = true;
				break;
			}
		}
		if ( !near )
			continue;
		tod_perk_scatter::derez_burst( org );
		tod_perk_scatter::play_sound_at_origin( org, "zmb_cha_ching", 3 );
	}
}

// self = trigger. One string per STATE, re-set only on change.
function uplink_hint_loop()
{
	level endon( "end_game" );
	shown = "";
	shown_cost = -1;
	for ( ;; )
	{
		wait 0.3;
		s = level.tod_finale_state;
		if ( s == "idle" )
		{
			if ( power_is_on() )
				key = "buy";
			else
				key = "nopower";
		}
		else
			key = s;
		// The buy line carries a party-scaled number now, so a party-size change
		// has to re-stamp it even though the STATE has not moved. One trigger, at
		// most four distinct strings — nothing like the 52-door case that made
		// _tod_doors::door_price_watch need a proximity gate.
		cost = finale_cost();
		if ( key == shown && ( key != "buy" || cost == shown_cost ) )
			continue;
		shown = key;
		shown_cost = cost;
		switch ( key )
		{
			case "nopower":   self SetHintString( "^1NO POWER^7 - you must turn on the power first" ); break;
			case "buy":       self SetHintString( "Hold ^3[{+activate}]^7 ^2CALL EXTRACTION ^2[Cost: " + cost + "]" ); break;
			case "charging":  self SetHintString( "^1RUN FOR THE CROWN^7" ); break;
			// "ready" now means the song is over and the ending is WAITING on a
			// survivor reaching the citadel — so this has to say go, not stand by.
			case "ready":     self SetHintString( "^2REACH THE CROWN^7" ); break;
			default:          self SetHintString( "" ); break;
		}
	}
}

// self = trigger
function uplink_use_loop()
{
	level endon( "end_game" );
	for ( ;; )
	{
		self waittill( "trigger", player );

		if ( !isdefined( player ) || !isplayer( player ) )
			continue;
		if ( level.tod_finale_state != "idle" )
			continue;
		// v10.4 (audit find): never start the run during an upgrade-event world
		// pause — the song clock would run while every picker stands frozen in
		// a menu.
		if ( IS_TRUE( level.tod_upgrade_pause ) )
			continue;
		if ( player laststand::player_is_in_laststand() )
			continue;
		// A revive press is not a purchase (_zm_blockers.gsc:307). This is the
		// most expensive mis-fire on the map: reviving polls the raw USE button
		// (_zm_laststand.gsc:1129), so without this the press that revives a
		// teammate on the terrace ALSO spends 12,000 points AND starts the
		// 191-second finale — irreversible, with a downed player on the ground.
		// Silent, like the branch above: the player is holding use.
		if ( player zm_utility::in_revive_trigger() )
			continue;
		if ( !power_is_on() )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
		// LIVE price, re-read on every attempt — same discipline as the doors, so
		// the number on the hint and the number charged can never disagree.
		price = finale_cost();
		if ( !( player zm_score::can_player_purchase( price ) ) )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}

		player zm_score::minus_to_player_score( price );
		player PlaySound( "zmb_cha_ching" );
		level thread finale_run( player );
		return;   // one purchase per game
	}
}

// ---------------------------------------------------------------------------
// The sequence
// ---------------------------------------------------------------------------

function finale_run( buyer )
{
	level endon( "end_game" );

	level.tod_finale_state = "charging";
	level.tod_finale_buyer = buyer;
	level notify( "tod_finale_start" );

	// THE ROAD OPENS. First thing, before the music and before the ambush: the
	// gate is what the player just paid for, and the ambush spawns onto the very
	// deck it was sealing.
	gate_open();

	// The closing song takes the channel and keeps it to the end screen. The
	// finale latch in _tod_atmosphere means a Panzer spawning mid-run cannot
	// steal it — during THE LAST MILE the song is the clock, so nothing may
	// interrupt it. (The "boss music always overrides" rule from v9.46 governs
	// the BAND tracks, not this one.)
	tod_atmosphere::finale_track_start();
	tod_perk_scatter::derez_burst( tod_crown_data::uplink_org() );

	// UPGRADE EVENTS ARE SUPPRESSED FOR THE WHOLE RUN. A freeze stops the world
	// but NOT the music stream, so the clock and the song would drift apart by
	// the length of every card pick — and the song is the only countdown the
	// player has. This is also why the loop below is a plain wait and no longer
	// wait_unpaused().
	level.tod_upgrades_suppressed = true;

	// THE AMBUSH — max spawn rate plus all three boss types cycling, every bit
	// of it under the existing actor caps. See _tod_bosses::finale_pressure_loop
	// for why this raises no limit.
	tod_bosses::finale_pressure_start();

	// THE ONE ANNOUNCEMENT (user: "we just need one announcement once extraction
	// starts and that is for everyone to get to the crown"). Banner up, one
	// stinger, and that is the entire instruction a player gets. There is NO
	// timer anywhere on screen, deliberately.
	warn_banner( true );
	level thread announce_run();



	// --- PHASE 1: THE ROAD --------------------------------------------------
	// Ends EARLY the moment every living player is inside the Crown - no reason
	// to make a party that sprinted it stand around waiting - and otherwise at
	// the hard 90s. Polled rather than event-driven because "everyone is inside"
	// is a property of four moving players, not something that notifies.
	// THE SONG'S DEADLINE IS ABSOLUTE, captured once here. Phase 2 is then
	// whatever is LEFT of it (peer review 2026-08-25): the road can end early,
	// and a fixed 101s hold-out after a 45s sprint would have ended the run at
	// 152s of a 197s track - the win screen landing mid-verse instead of on the
	// last chord, which is the one thing this whole clock exists to get right.
	// BOTH ENDS OF THE SONG are published, because the TOWER GAUGE reads them as
	// the run's clock (see _tod_gauge::finale_cell). The end alone is not enough:
	// a progress bar needs the span.
	level.tod_finale_song_start = GetTime();
	level.tod_finale_song_end   = GetTime() + int( song_secs() * 1000 );

	t_end = GetTime() + int( road_secs() * 1000 );
	while ( GetTime() < t_end )
	{
		if ( all_living_in_crown() )
			break;
		wait 0.25;
	}

	// --- THE SEAL - THE ORDER HERE IS LOAD-BEARING --------------------------
	// 1. Banner down: its job ends the instant the door moves.
	// 2. GATHER first, CLOSE second. The door brush fills the gate opening
	//    exactly, so anyone still walking through it is standing INSIDE that
	//    brush - closing on them is the crush case every door slab in this map
	//    is careful about. Called out directly in the ask: "teleport them in the
	//    middle and then close the door so it doesnt kill anyone."
	// 3. Stragglers die AFTER the door is shut, so the seal is visibly what
	//    took them rather than an unexplained death mid-road.
	// 4. Wipe the map LAST, once nothing else can add to it.
	warn_banner( false );
	gather_to_centre();
	crown_door_close();
	kill_stragglers();
	wipe_the_map();

	// NOBODY MADE IT. Without this the siege ran its full length in an empty
	// sealed hall and then printed YOU ESCAPED THE TOWER (peer review, and the
	// other half of the kill_stragglers blocker). If the citadel is empty the run
	// is over and it is a loss - stock's own wipe would normally have fired
	// already, but a straggler killed on this same frame may not have resolved
	// into it yet, so say it explicitly.
	if ( !anyone_sealed_in() )
	{
		level notify( "end_game" );
		return;
	}

	level.tod_finale_state = "holdout";
	level.tod_crown_sealed = true;     // read by the endless-rounds spawn filter
	level notify( "tod_finale_sealed" );
	level thread crown_containment_watch();

	// --- PHASE 2: THE HOLD-OUT ----------------------------------------------
	// A module may still own the fight outright via tod_finale_boss_fn. It now
	// runs INSIDE the sealed hall with the clock already part-spent, so it has
	// to return promptly or the song runs out from under it.
	if ( isdefined( level.tod_finale_boss_fn ) )
	{
		level [[ level.tod_finale_boss_fn ]]();
		for ( i = 0; i < level.tod_finale_pylons.size; i++ )
			ignite_pylon( i );
	}
	else
	{
		tod_bosses::finale_holdout_start();
		// Whatever is left of the song, not a constant — see the deadline above.
		// Floored so an absurdly late seal still gives the siege a real beat
		// rather than a negative wait.
		hold = ( level.tod_finale_song_end - GetTime() ) / 1000.0;
		if ( hold < 8 )
			hold = 8;
		// The four pylons now ignite across the FIGHT rather than the whole run,
		// so they read as the siege's own progress bar - and unlike on the road,
		// everyone can actually see them from in here.
		quarter = hold / 4.0;
		for ( i = 0; i < 4; i++ )
		{
			wait quarter;
			ignite_pylon( i );
		}
	}

	// --- the song ends: you made it -----------------------------------------
	level.tod_finale_state = "ready";
	level notify( "tod_finale_charged" );
	for ( i = 0; i < level.tod_finale_pylons.size; i++ )
		tod_perk_lights::set_glow( level.tod_finale_pylons[ i ], TOD_GLOW_GREEN );
	if ( isdefined( level.tod_finale_pad ) )
	{
		level.tod_finale_pad SetModel( "p7_out_mech_spawn_pad_light_green" );
		tod_perk_lights::set_glow( level.tod_finale_pad, TOD_GLOW_GREEN );
	}
	tod_perk_scatter::derez_burst( tod_crown_data::exfil_org() );
	tod_perk_scatter::play_sound_at_origin( tod_crown_data::exfil_org(), "zmb_cha_ching", 4 );

	// WIN. There is deliberately NO arrival check here any more: the only way to
	// still be alive at this line is to have been SEALED INSIDE the Crown a
	// hold-out ago and to have survived the siege. Anyone who missed the road is
	// already dead (kill_stragglers), and if the whole party died in the hall
	// then stock's end_game fired and this thread died on the endon at the top -
	// a loss, which is the right outcome for not making it.
	//
	// This also retires the unbounded stalemate the old spin allowed: buy the
	// uplink, walk back down the tower, and `while(!survivor_at_crown())` never
	// returned - the song looped forever, upgrades stayed suppressed forever and
	// the ambush ran forever with nothing able to end it.
	level thread depart();
}

// (wait_unpaused removed with the old hold-out: the run suppresses upgrade
// events outright, because a pause that stops the clock but not the music
// stream would desync the two — see finale_run.)

// EXTRACTION SCALES WITH PARTY SIZE, like every door does (co-op audit
// 2026-08-23). It was the one party-wide price the v9.x scaling pass missed: a
// flat 25,000 charged to a single wallet while the 52-door ladder in front of it
// scaled x1.00 / x1.27 / x1.82 / x2.36 by party size. Running it through the
// doors' own door_price() keeps one rule for the whole map rather than a second
// pricing scheme nobody would remember to keep in sync — solo is untouched by
// construction (the multiplier is exactly 1.0 below two players).
// THE ANNOUNCEMENT. One stinger and one burst at each player, fired once when
// extraction starts. Deliberately minimal: the ask was "just need one
// announcement ... for everyone to get to the crown", and this map's doctrine is
// no floaty captions - the BANNER carries the words, this carries the alarm.
function announce_run()
{
	level endon( "end_game" );
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		p PlaySound( "zmb_cha_ching" );
	}
	tod_perk_scatter::derez_burst( tod_crown_data::causeway_gate_org() );
}

// THE WARNING BANNER — a blinking "RUN FOR THE CROWN" plate across the top of
// every player's screen for the whole road phase, gone the instant the door
// seals. NO TIMER ANYWHERE, by explicit instruction: the urgency comes from the
// blink and the music, not from a number counting down.
//
// THE BLINK IS SERVER-DRIVEN, and that is this map's rule rather than my
// preference — tod_upgrade.lua's own header says "SERVER-driven blink (no
// UITimers client-side) ... keyframe tweens, never UITimers", which is how the
// upgrade panel's focus blink already works. So the server toggles the single
// todFinaleWarn bit and the Lua does nothing but show or hide.
//
// Cost is trivial: one bit, ~2.5 writes a second for 90 seconds. The crosshair
// damage numbers push more than that in a single shotgun burst.
function warn_banner( on )
{
	if ( IS_TRUE( on ) )
	{
		if ( IS_TRUE( level.tod_warn_on ) )
			return;
		level.tod_warn_on = true;
		level thread warn_banner_loop();
		level thread warn_clear_on_end();
		return;
	}
	level.tod_warn_on = false;
	level notify( "tod_warn_off" );
	warn_push( false );
}

// self = level. Ends on its own notify, on the seal, or on the game — belt and
// braces, because a banner left blinking over the hold-out would be worse than
// one that never appeared.
function warn_banner_loop()
{
	level endon( "end_game" );
	level endon( "tod_warn_off" );
	level endon( "tod_finale_sealed" );

	on = true;
	for ( ;; )
	{
		warn_push( on );
		on = !on;
		wait TOD_FINALE_WARN_BLINK;
	}
}

// NO endon, deliberately. warn_banner_loop dies on end_game with whatever it
// last pushed still on screen, so a party that wipes ON THE ROAD kept a blinking
// RUN FOR THE CROWN plate over the game-over text (peer review 2026-08-25).
// This is the one path that is guaranteed to run on every exit.
function warn_clear_on_end()
{
	level waittill( "end_game" );
	level.tod_warn_on = false;
	warn_push( false );
}

function warn_push( on )
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		p tod_upgrade_ui::set_finale_warn( on );
	}
}

// The two clock numbers, in one place, so the dev readout can never disagree
// with what the run actually does.
// ONE CLOCK, EVERY BUILD (2026-08-25). These used to branch on level.tod_dev and
// must not again: the dev clock shortened the timer but not the 197.4s wav, so
// the ending arrived with most of the song still playing. The run is always
// ROAD 90s then whatever is left of the 191s song, so "the game ends when the
// song ends" holds in every build, and arriving early buys a LONGER siege rather
// than a shorter ending.
function road_secs() { return TOD_FINALE_ROAD_SECS; }
function song_secs() { return TOD_FINALE_SONG_SECS; }

function finale_cost()
{
	return tod_doors::door_price( TOD_FINALE_COST );
}

// Are ALL living players inside the Crown? This is what can end the road phase
// early, so it has to be every one of them, not any of them.
//
// DOWNED PLAYERS COUNT AS LIVING AND DO BLOCK IT. That is deliberate: a crawler
// out on the road cannot walk himself in, and sealing early because we ignored
// him would kill him with 80 seconds still on the clock. Blocking means the
// party gets the full 90s to go back for him. If nobody does, the hard timeout
// seals anyway and he dies - the same outcome, just not one we chose early.
//
// Returns false for an empty party so a wipe can never be read as "everyone is
// inside" and trip the seal on a dead lobby.
function all_living_in_crown()
{
	players = GetPlayers();
	n_live = 0;
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		n_live++;
		if ( !( tod_crown_data::in_crown( p.origin ) ) )
			return false;
	}
	return ( n_live > 0 );
}

// One seat on the gather ring. Shared by the seal and the containment watch so
// a respawning player lands the same way the original party did.
function gather_spot( n )
{
	fwd = AnglesToForward( ( 0, n * 90, 0 ) );
	return tod_crown_data::hall_center() + VectorScale( fwd, TOD_FINALE_GATHER_RING ) + ( 0, 0, 8 );
}

// Put everyone who made it into the middle of the hall, on a ring so they do not
// stack. Runs BEFORE the door closes - see the seal comment in finale_run.
// Downed players are moved too: a crawler who got inside has earned the seal,
// and leaving him in the doorway is exactly the crush this ordering avoids.
function gather_to_centre()
{
	// GATHER ON in_hall, KILL ON in_crown, and the difference is a person's life
	// (peer review 2026-08-25). in_crown()'s south bound is the INNER face of the
	// south wall (y >= 7880), but the doorway the crown door fills is y
	// 7840..7880 - entirely outside it. So a player mid-stride under the lintel
	// failed the gather, and was then killed by kill_stragglers() a line later,
	// having actually made it through the gate. in_hall() starts at the door's
	// own south face, so it covers the whole archway.
	players = GetPlayers();
	n = 0;
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		if ( !( tod_crown_data::in_hall( p.origin ) ) )
			continue;
		p SetOrigin( gather_spot( n ) );
		p SetPlayerAngles( ( 0, n * 90 + 180, 0 ) );   // face the middle
		n++;
	}
	tod_perk_scatter::derez_burst( tod_crown_data::hall_center() );
}

// The tower takes anyone who did not make it.
//
// STOCK'S OWN RECIPE, NOT Kill() (peer review, 2026-08-25 — this was a BLOCKER).
// The first cut used p Kill() with a comment claiming a damage kill would route
// through laststand and let a solo player with a banked Quick Revive stand back
// up outside a sealed door. The reasoning was backwards: a script Kill() on a
// player is invisible to EVERY stock system. level.callbackPlayerKilled is
// deliberately blank (_zm.gsc:6359 - it just waits on "forever"), and the only
// end_game check in the whole game lives inside player_damage_override
// (_zm.gsc:5445), reachable ONLY through damage. So a solo player killed here
// produced no game over, no laststand, no respawn - and finale_run carried on to
// run a 101-second siege in an empty hall and print YOU ESCAPED THE TOWER for a
// corpse.
//
// This is exactly what stock does to a player who walks out of the playable
// area (_zm.gsc:2096-2101), and the lives = 0 line is the part that actually
// solves the Quick Revive worry the original comment was reaching for.
function kill_stragglers()
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		if ( tod_crown_data::in_crown( p.origin ) )
			continue;
		p DisableInvulnerability();
		p.lives = 0;              // no self-revive out of this one
		p.bleedout_time = 0;      // no crawling, no waiting
		p DoDamage( p.health + 1000, p.origin );
	}
}

// -> true if at least one UPRIGHT player is inside the Crown right now. The seal
// and the win both gate on this: an empty citadel must never be able to "escape".
function anyone_sealed_in()
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		if ( p laststand::player_is_in_laststand() )
			continue;
		if ( tod_crown_data::in_crown( p.origin ) )
			return true;
	}
	return false;
}

// SEALED-IN CONTAINMENT (peer review 2026-08-25). Stock respawns bled-out co-op
// players at every round boundary (_zm.gsc:4467), this map's rounds turn over
// constantly (delay 0), and the only crown respawn group is on the TERRACE -
// the far side of the door that just shut. Without this, a player who died on
// the road comes back outside the seal, cannot get in, cannot be reached by the
// hall-only spawn filter, and is then handed the win as a bystander.
//
// Rather than special-case the respawn system, this just keeps the invariant:
// while the Crown is sealed, every living player is inside it. Polled, because
// a respawn is not something we get notified about.
function crown_containment_watch()
{
	level endon( "end_game" );

	for ( ;; )
	{
		if ( !IS_TRUE( level.tod_crown_sealed ) )
			return;
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
				continue;
			if ( tod_crown_data::in_hall( p.origin ) )
				continue;
			// He respawned outside. Put him in the fight rather than leaving him
			// to spectate a siege he cannot reach or affect.
			p SetOrigin( gather_spot( i ) );
			tod_perk_scatter::derez_burst( p.origin );
		}
		wait 0.5;
	}
}

// Clear the board for the siege (user: "We would need to kill all enemies on map
// before fight"). Players cannot realistically do that themselves - the map is
// 19,000 units tall and most of what is alive at this moment is stranded on a
// road they can no longer reach - so the seal does it for them.
//
// This is also a REAL requirement, not a flourish: everything still alive out
// there is holding a slot under stock's 31-actor gate, and the hold-out needs
// those slots to put enemies in the hall.
function wipe_the_map()
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

// Is there at least one UPRIGHT survivor inside the citadel? Downed players do
// not count: a crawler in the hall has not escaped, and if he is the last one
// standing the bleedout resolves the run the honest way. Dead/spectating players
// are filtered by isalive.
// KEPT but no longer on the win path (see finale_run) - the exfil hint loop
// still reads it.
function survivor_at_crown()
{
	org = tod_crown_data::exfil_org();
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		if ( p laststand::player_is_in_laststand() )
			continue;
		if ( DistanceSquared( p.origin, org ) <= ( TOD_FINALE_ARRIVE_RAD * TOD_FINALE_ARRIVE_RAD ) )
			return true;
	}
	return false;
}

function ignite_pylon( i )
{
	if ( !isdefined( level.tod_finale_pylons ) || i >= level.tod_finale_pylons.size )
		return;
	p = level.tod_finale_pylons[ i ];
	if ( !isdefined( p ) )
		return;
	tod_perk_lights::set_glow( p, TOD_GLOW_YELLOW );
	tod_perk_scatter::derez_burst( p.origin );
	tod_perk_scatter::play_sound_at_origin( p.origin, "zmb_cha_ching", 4 );
	level notify( "tod_finale_pylon", i );
}

// ---------------------------------------------------------------------------
// THE EXTRACTION PAD — a DESTINATION now, not a control (v10)
// ---------------------------------------------------------------------------
// The old ending was: hold USE here with every living survivor gathered on the
// pad. The ending is the SONG now (user: "game ends when songs ends and you
// win"), so there is nothing left to activate. The pad lights up, tells you
// that you made it, and the citadel walls around it are the reason you wanted
// to reach it in the first place.
//
// DELETED with the old flow, not left dormant: exfil_use_loop,
// all_survivors_on_pad, refuse_flash, and the TOD_FINALE_PAD_ZBAND /
// TOD_FINALE_REFUSE_SECS defines. A live use-trigger that still called
// depart() would be a SECOND path into the end screen, racing the song timer —
// two threads both notifying "end_game" is exactly the kind of double-fire
// that is invisible until it happens in front of the user.
function exfil_beacon()
{
	level endon( "end_game" );

	t = spawn( "trigger_radius_use", tod_crown_data::exfil_org() + ( 0, 0, 30 ), 0, tod_crown_data::exfil_radius() + 24, 96 );
	t TriggerIgnoreTeam();
	t SetCursorHint( "HINT_NOICON" );
	level.tod_finale_pad_trig = t;
	t thread exfil_hint_loop();
}

// self = trigger. One string per STATE, re-set only on change.
function exfil_hint_loop()
{
	level endon( "end_game" );
	shown = "";
	for ( ;; )
	{
		wait 0.3;
		key = level.tod_finale_state;
		if ( key == shown )
			continue;
		shown = key;
		switch ( key )
		{
			// "holdout" falls together with "charging" deliberately: this is the
			// sealed-in siege and the line already says the right thing. Without
			// the case the state fell to default, which tells the party the uplink
			// is "back at the TERRACE" - through a door they cannot open (peer
			// review 2026-08-25).
			case "holdout":
			case "charging":   self SetHintString( "^3HOLD THE CROWN^7" ); break;
			case "ready":      self SetHintString( "^2EXTRACTION INBOUND^7" ); break;
			case "departing":  self SetHintString( "^2EXTRACTING...^7" ); break;
			case "done":       self SetHintString( "" ); break;
			// SAY WHERE (live test 2026-08-23 — the map could not be finished).
			// The uplink is at the TERRACE (y=368) and this pad is at the far end
			// of the hall: the length of the causeway apart, with the whole
			// causeway between them. A player climbs 50 floors, arrives at the
			// terrace, runs the road they can see, reaches this pad and is told to
			// "activate the Uplink" with no hint that it is all the way back where
			// they started. That is the whole road as a walk of shame, and the user hit it:
			// "game couldn't end cause of some uplink issue".
			default:           self SetHintString( "^3UPLINK^7 is back at the TERRACE" ); break;
		}
	}
}

// ---------------------------------------------------------------------------
// Departure + the end screen
// ---------------------------------------------------------------------------

function depart()
{
	// NO endon(end_game): this thread IS what ends the game.
	level.tod_finale_state = "departing";
	level notify( "tod_finale_depart" );

	// the survivors are leaving — nothing can touch them now
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		p EnableInvulnerability();
		p.ignoreme = true;
	}

	level thread depart_show();
	wait TOD_FINALE_DEPART_SECS;

	level.tod_finale_state = "done";
	level.tod_escaped = true;
	level.custom_game_over_hud_elem = &escaped_game_over;
	level notify( "end_game" );
}

// Pylons strobe green/off, strike bursts walk the pad. Ends itself.
function depart_show()
{
	org = tod_crown_data::exfil_org();
	steps = int( TOD_FINALE_DEPART_SECS / 0.4 );
	for ( k = 0; k < steps; k++ )
	{
		on = ( ( k % 2 ) == 0 );
		for ( i = 0; i < level.tod_finale_pylons.size; i++ )
		{
			p = level.tod_finale_pylons[ i ];
			if ( isdefined( p ) )
				tod_perk_lights::set_glow( p, ( on ? TOD_GLOW_GREEN : 0 ) );
		}
		if ( ( k % 3 ) == 0 )
			tod_perk_scatter::derez_burst( org );
		wait 0.4;
	}
}

// Stock _zm::end_game calls this per player INSTEAD of its own game_over/
// survived setup when it is defined ( player, game_over_elem, survived_elem ).
// It then sets the survived text + fade itself, so this only needs to style
// both elems and put our line on game_over. Mirrors the stock geometry.
function escaped_game_over( player, game_over, survived )
{
	game_over.alignX = "center";
	game_over.alignY = "middle";
	game_over.horzAlign = "center";
	game_over.vertAlign = "middle";
	game_over.y -= 130;
	game_over.foreground = true;
	game_over.alpha = 0;
	// WHITE, so the art shows its own colours — SetShader tints by .color, and
	// the old mint-green was for TEXT. Tinting baked gold/cyan art green would
	// muddy every hue in it.
	game_over.color = ( 1, 1, 1 );
	game_over.hidewheninmenu = true;
	// BAKED ART INSTEAD OF TEXT (user 2026-08-25: "We have some horrible UI when
	// you win"). The words are IN the image, so this elem draws a shader rather
	// than a string — the map's standing rule that baked art beats anything the
	// HUD can draw itself. 2048x512 source at 900x225 keeps the 4:1 aspect; the
	// contact sheet confirmed the slab cut still reads at 500 wide, so 900 has
	// margin.
	game_over SetShader( "tod_win_banner", 900, 225 );
	game_over FadeOverTime( 1 );
	game_over.alpha = 1;

	// THE EMBLEM sits above the banner — crown over tower, 1:1 art at 128.
	// Its own elem because a hudelem draws one shader. Parented to the player so
	// it dies with them and inherits the same intermission lifetime.
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
		emblem SetShader( "tod_win_emblem", 128, 128 );
		emblem FadeOverTime( 1.4 );
		emblem.alpha = 1;
	}

	survived.alignX = "center";
	survived.alignY = "middle";
	survived.horzAlign = "center";
	survived.vertAlign = "middle";
	// BELOW THE BANNER (user 2026-08-25: "The You Survived XX Rounds text should
	// be moved down more. It overlaps with the new asset for winning"). The
	// banner is 225 tall centred on game_over.y (which is -130), so it occupies
	// roughly -242..-18 — and this line used to sit at -100, i.e. straight
	// through the middle of the artwork. +40 clears the banner's bottom edge
	// with ~58 to spare.
	survived.y += 40;
	survived.foreground = true;
	survived.fontScale = 2;
	survived.alpha = 0;
	survived.color = ( 1.0, 1.0, 1.0 );
	survived.hidewheninmenu = true;

	if ( player isSplitScreen() )
	{
		// Half the vertical room, so the banner shrinks with the text it replaced.
		game_over SetShader( "tod_win_banner", 600, 150 );
		game_over.y += 40;
		survived.fontScale = 1.5;
		survived.y += 40;
	}
}
