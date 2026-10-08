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
#using scripts\shared\ai\zombie_utility;                 // spawn_zombie + get_current_zombie_count (v17.47 road seed wave)

#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;

#using scripts\zm\zm_tower_of_doom\_tod_crown_data;
#using scripts\zm\zm_tower_of_doom\_tod_doors;           // door_price (party-size scaling for the extraction buy)
#using scripts\zm\zm_tower_of_doom\_tod_perk_lights;     // set_glow (the aura clientfield)
#using scripts\zm\zm_tower_of_doom\_tod_perk_scatter;    // derez_burst + play_sound_at_origin (host-based FX/SFX)
#using scripts\zm\zm_tower_of_doom\_tod_atmosphere;      // finale_track_start (the music channel)
#using scripts\zm\zm_tower_of_doom\_tod_bosses;          // finale_pressure_start (the ambush)
#using scripts\zm\zm_tower_of_doom\_tod_gameover;   // end_screen_push (v19.58, the end-screen lines in the map typeface)
#using scripts\zm\zm_tower_of_doom\_tod_upgrade_ui;      // set_finale_warn (the road banner)
#using scripts\zm\zm_tower_of_doom\_tod_rocket;          // v19.68r THE ROCKETS: ride_extract, the extract ship's send-off (docs/170)

#insert scripts\shared\shared.gsh;

// Models: carved T7 props already in the Mod Tools GDT DB (source_data/
// acc_t7_props_*.gdt, binaries verified on disk 2026-08-21), plus the v19.69
// uplink terminal (map-owned, source_data/tod_fan_props.gdt). Script-spawned
// (SetModel) + `xmodel,` zone lines — never baked misc_models.
#precache( "model", "tod_uplink_terminal" );
// THE WIN SCREEN ART (2026-08-25). MATERIALS, not images: the game-over screen
// is a server HUDELEM and SetShader takes a material. The 2d_blend wrappers
// live in source_data/tod_ui_images.gdt beside the images they point at.
#precache( "material", "tod_win_banner" );
#precache( "material", "tod_win_emblem" );   // the uplink console
#precache( "material", "tod_choice_banner" );   // v14: the EXTRACT-or-ASCEND plate (docs/44)
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

// ---------------------------------------------------------------------------
// THE BEAT TABLE (v12.13, docs/41: A1 THE DEREZ TIDE + A2 AUTHORED BOSS BEATS
// + A4 THE ARRIVAL + riders + B1 THE LANE LOTTERY). ONE table, ONE tuning
// surface — every timed thread below keys off level.tod_finale_song_start, so
// the road can never show two disagreeing clocks. The song timestamps are
// MEASURED off tod_music_finale.wav (ffmpeg ebur128, 2026-08-27): the track
// opens hot, dips into a breakdown at 23-25s with its first big hit at ~25s,
// and enters its sustained climax section at ~60s (the big drop proper is
// ~114s, usually inside the hold-out).
// ---------------------------------------------------------------------------
// A1 THE DEREZ TIDE — REMOVED 2026-08-27, the same day it shipped, after two
// verdicts from the user: invisible it read as nothing ("Red wave?"), and with
// the full visible body (v12.14: three red-aura riders + 88 deck-point derez
// eruptions walking the road) it still did not land ("Okay im not a big fan").
// DELETED, not dormant (the TIRELESS doctrine): tide_run/curtain_advance/
// tide_players/tide_forward_warp/avenue_flip, the TOD_TIDE_* defines, the
// endless-rounds front filter + heel relax, and the generator's tide emits
// (tide_start_y/tide_end_y/road_north_yaw/tide_curtain_orgs) are all gone.
// KNOWN CONSEQUENCE, accepted: the loiter exploit returns — hold = song_end -
// now still rewards waiting out the road phase (docs/41 §1.2). If a counter is
// ever wanted again, the full recipe is docs/41 §A1; the sign-off history
// (lethal + forward warp) is in this file's git-era... in CHANGELOG v12.13-15.
// A2 — the Panzer drops astride the Narrows lip on the song's first hit, gated
// on the leader actually reaching the throat; fired regardless by the cap so a
// slow party still meets him as a mid-road wall.
#define TOD_BEAT_PANZER_SECS      20
#define TOD_BEAT_PANZER_CAP       40
// A2 — the phased spawn floor (read by _tod_endless_rounds::tod_spawn_delay):
// 0.4 overture until the first hit, 0.2 through the build, 0.1 from the
// sustained section on (and the pressure tick tightens 6 -> 4 with it).
#define TOD_PHASE2_SECS           25
#define TOD_PHASE3_SECS           60
// aura colour indices used by the beat system (perk_color_index table)
#define TOD_GLOW_BLUE             6

// ARRIVAL RADIUS — how close to the extraction pad counts as "inside the Crown".
// 1536 is the hall's own dimension, measured from the pad: it reaches every
// corner of the 1536-sq interior (the far south corners are ~1486 away) and the
// south gate at y=6900 (~1252). So it means "you are in the citadel", not "you
// are standing on the pad" — the pad has been a DESTINATION, not a control,
// since v10 deleted the gather-and-hold flow, and this keeps it that way.
#define TOD_FINALE_ARRIVE_RAD     1536

// THE ROAD CULL (v17.37, user 2026-09-04: "the final run across the bridge. We
// planned on having zombie spawn on other side of bridge when the extraction
// starts. Thats not working ... I can just run across no problem ... Could be
// im at max AI already").
//
// THE DIAGNOSIS IS THE USER'S AND IT IS RIGHT. The ambush was never a spawn
// bug: _tod_endless_rounds::finale_spawn_selection picks the riser AHEAD of a
// random living player and tod_spawn_delay drops the trickle to its floor, but
// both are RATE controls. level.zombie_ai_limit (ai_limit_for_party, 30-45 by
// party size since v18.11 and 45 on rampage, _tod_corpse_cleanup) caps
// how many trash zombies STAND AT ONCE, and under the endless-rounds twist a
// deep run sits at that cap permanently — 45 zombies spread over 19,200 units
// of tower that no longer has anybody in it. Every one of them holds a slot,
// none of them can reach the causeway in 90 seconds, and the spawner has
// nothing left to put in front of the party. "Max aggressiveness on spawns"
// against a full cap buys exactly nothing.
//
// So the last mile takes the map back: WIPE at the buy (in finale_run — the
// same wipe_the_map() the seal already runs, now at both ends of the road), and
// then KEEP it clear with this cull, because one wipe only buys the first few
// seconds: the party outruns what spawns behind them and the cap silently
// refills with stragglers over a 90-second road.
//
// DISTANCE ONLY, never geometry: a zombie is culled when it is further than
// this from EVERY living player. That covers the tower (19,000 units below),
// the base, and anything the party has left behind on the road, and it can
// never touch the wave in front of them. 2500 is well past the fog and past
// the longest sightline on the causeway, so nothing vanishes on screen.
// ELITES ARE EXEMPT (ignore_enemy_count, the field every one of them sets):
// they are outside this cap by definition, the pressure loop owns their roof,
// and a Panzer despawning behind you is a robbery, not a relief.
#define TOD_FINALE_CULL_DIST      2500
#define TOD_FINALE_CULL_TICK      2
//
// v17.47 (user 2026-09-04: "the new ones still take time to come in ... player
// can just run the bridge no problem") — THE CULL WAS KILLING THE AMBUSH. The
// band picker in _tod_endless_rounds sends 40% of road spawns to the third
// nearest the crown gate, up to ~7000 units AHEAD of a party that has just
// bought; distance-only, the cull above reaped every one of them within 2 s of
// rising, before it could close a single step. "It can never touch the wave in
// front of them" was wrong for the whole life of the cull. NOW: anything ON THE
// ROAD (z above TOD_FINALE_ROAD_Z_MIN) at or ahead of the FRONT-MOST living
// player — less a short grace behind him — is exempt; the tower, the base and
// the stragglers behind the party are culled exactly as before.
// TOD_FINALE_ROAD_Z_MIN is the same 18928 the lane-band filter in
// _tod_endless_rounds::finale_spawn_selection uses for "on the road" (the
// undercroft, the road's deepest lane, sits at TOP2 - 384 = 19008) — LOCKSTEP.
#define TOD_FINALE_ROAD_Z_MIN     18928
#define TOD_FINALE_CULL_BEHIND    512
// THE SEED WAVE (v17.47, same report). After the wipe the cap is empty and the
// trickle refills it one riser at a time, so the party was walking a road that
// only STARTED filling as they left it. At the buy, TOD_FINALE_SEED_N trash rise
// at once on road risers between MIN and MAX ahead of the party's front (capped
// at the crown gate, lane-lottery slabs excluded, under the ai_limit like every
// spawn). Direct zombie_utility::spawn_zombie, the way stock's own
// round_spawning does it; not counted against the round budget on purpose —
// the finale's rounds are irrelevant and this is the road's own wave.
#define TOD_FINALE_SEED_N         12
#define TOD_FINALE_SEED_MIN_AHEAD 400
#define TOD_FINALE_SEED_MAX_AHEAD 2200

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
	lane_seals_init();

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
	// THE UPLINK TERMINAL (v19.69, user 2026-10-02: "Replace the activation for run
	// for the crown model to the Door Terminal Idea prop"). Nikolai's terminal from
	// his Meshy pack (`tod_uplink_terminal`, tools/fan_props/build_fan_props.py): an
	// 84-tall console whose screen and keyboard face model +X, footprint centred on
	// its origin. At uplink_yaw() 0 that is EAST — toward the crown stair the party
	// climbs onto the terrace by. The Stalingrad data terminal it replaced showed its
	// screen at model -X, i.e. to the terrace's empty west end: everyone arriving saw
	// the back of the one thing they had to use. Trigger, clip, beacon and glow are
	// unchanged (the glow plays on tag_origin, which the new model carries).
	level.tod_finale_uplink = prop( "tod_uplink_terminal", tod_crown_data::uplink_org(), tod_crown_data::uplink_yaw() );
	finale_log( "UPLINK_MODEL rev=fan_props_2 model=tod_uplink_terminal org=" + tod_crown_data::uplink_org()
		+ " yaw=" + tod_crown_data::uplink_yaw() + " spawned=" + isdefined( level.tod_finale_uplink ) );

	// DO NOT REPLACE THIS WITH A WORLD BRUSH. Tried and REVERTED 2026-08-27: an
	// "extraction obelisk" built from cboxes on uplink_org()'s own coordinates
	// looked right and linted clean, and it KILLED THE BUY — a solid brush
	// sitting on a trigger_radius_use origin swallows the trigger, so extraction
	// could not be bought at all. This map had already paid for that lesson once:
	// see the ammo crate note in lint_tod_geometry.js (MODEL_CLIP_COLUMNS), where
	// a solid brush "swallowed the crate's trigger_radius_use origin so the crate
	// could not be bought". The prop is VISUAL and the clip below is a script
	// entity precisely because both leave the trigger's origin in open space.
	// If this model is ever replaced, replace it with another MODEL.

	// COLLISION (user 2026-08-25: "Add a clip to the extraction station. Its walk
	// through currently"). A script_model is VISUAL ONLY — the xmodel carries no
	// collision a player can stand against — so every vendor in this map spawns a
	// second entity to be its solid. Same recipe as the HEAVENLY GIFT ALTAR
	// (_tod_upgrades::station_place) and as stock's own perk machines
	// (_zm_perks.gsc:1551): a script_model wearing zm_collision_perks1, tagged
	// script_noteworthy "clip", DisconnectPaths'd.
	//
	// ONE BOX, NOT THE ALTAR'S THREE. The altar needed three because its mesh
	// FLARES to 104 wide at chest height; this terminal is a single console. The
	// v19.69 terminal is MEASURED (art/fan_props/manifest.json, from the shipped
	// binary): about 46 deep x 48 wide x 84 tall, centred on its origin — the same
	// vending-machine footprint class as the 48 x 34 x 78 Stalingrad terminal this
	// box was sized for (PyCoD read that one fine in 2026-10: x -26.6..21.6,
	// y -14.0..20.1, z 0..78.4). The terrace's open floor absorbs any overhang.
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

	// wall sconces down both long walls. HANDLES ARE KEPT now (v12.13): A4's
	// acceptance sequence lights them in order as the first survivor crosses
	// the gold portal — before that they are exactly the props they always were.
	level.tod_finale_sconces = [];
	so = tod_crown_data::sconce_orgs();
	sy = tod_crown_data::sconce_yaws();
	for ( i = 0; i < so.size; i++ )
	{
		s = prop( "p7_zm_moo_light_panel_01_long", so[ i ], sy[ i ] );
		if ( isdefined( s ) )
			level.tod_finale_sconces[ level.tod_finale_sconces.size ] = s;
	}
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
		// The buy line carries a party-scaled number, so a party-size change has
		// to re-stamp it even though the STATE has not moved. That is affordable
		// HERE and only here: this is ONE trigger with at most four distinct
		// strings (one per party size), against the engine's 250-entry
		// triggerstring cache.
		//
		// The 53 TOWER doors had the same shape and it was NOT affordable — 53
		// destinations x every multiplier a lobby walks through, which is what
		// overflowed the cache in co-op. Their re-stamp watcher was deleted
		// outright on 2026-08-30 (see the block above buy_trigger_wait in
		// _tod_doors.gsc); their hints are now minted once at load and never
		// again. Do not generalise this loop back onto anything that has more
		// than a handful of instances.
		cost = finale_cost();
		if ( key == shown && ( key != "buy" || cost == shown_cost ) )
			continue;
		shown = key;
		shown_cost = cost;
		switch ( key )
		{
			// v19.3 — LEAD WITH THE NOUN, and do NOT reintroduce the stock-style
			// wording this used to carry. ZMCursorHintNew::classifyHint tests for
			// the generic must-turn-on-the-power sentence at STEP 1, before the
			// TOD_NOUNS pass at step 3, so a hint phrased that way is routed to
			// PromptPowerRequired — a card that reads no hint text at all. The
			// uplink lost its title, its icon and this copy. The teleporter solved
			// the same problem the same way; see its 'power required' literal.
			// (The offending sentence is deliberately NOT quoted here: this repo
			// has already had a scanner read a quoted word out of a comment and
			// treat it as live data — memory `comments-are-data-to-a-scanner`.)
			case "nopower":   self SetHintString( "^5UPLINK^7 - ^1power required" ); break;
			// GRAMMAR (v14.58): "Hold [btn] <TITLE> - <detail> [Cost: N]" — see
			// PromptDefault.lua. The card splits on the FIRST " - ", so the
			// title band reads CALL EXTRACTION and the line under it says what
			// buying actually does. It used to be the noun and a price with no
			// explanation of either.
			case "buy":       self SetHintString( "Hold ^3[{+activate}]^7 ^2CALL EXTRACTION^7 - opens the road to the crown ^2[Cost: " + cost + "]" ); break;
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
		// v13.3b: made AUDIBLE (map-wide trigger audit). This branch is not the
		// holding-USE case the silent branches below are: the uplink's hint loop
		// keeps advertising "CALL EXTRACTION [Cost: 12000]" throughout, so a
		// totally silent refusal on the map's most expensive and most important
		// buy is indistinguishable from a broken trigger — and it is the last
		// thing a player wants to doubt before committing to the ending. One
		// deny sound, matching every other refusal lane on the map.
		if ( IS_TRUE( level.tod_upgrade_pause ) )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
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

	// THE LANE LOTTERY (v12.13, docs/41 §B1) rolls BEFORE the gate opens: the
	// party is still behind the solid causeway gate, so no player can be inside
	// a slab when it solidifies (the dev harness opens the gate early, so the
	// roll also occupancy-checks each slab and re-rolls around anyone found).
	lane_lottery();

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
	tod_atmosphere::finale_weather_turn();   // rider: the sky turns ember over 15s
	tod_perk_scatter::derez_burst( tod_crown_data::uplink_org() );

	// UPGRADE EVENTS ARE SUPPRESSED FOR THE WHOLE RUN. A freeze stops the world
	// but NOT the music stream, so the clock and the song would drift apart by
	// the length of every card pick — and the song is the only countdown the
	// player has. This is also why the loop below is a plain wait and no longer
	// wait_unpaused().
	level.tod_upgrades_suppressed = true;

	// THE MAP LETS GO. Every zombie still standing in the tower is 19,000 units
	// from a road nobody will walk again, and each one holds a slot under
	// level.zombie_ai_limit that the ambush needs (TOD_FINALE_CULL_DIST carries
	// the whole diagnosis). The seal already ENDS the road with this exact call;
	// the road now starts with it too, so the first wave in front of the party
	// spawns into an empty cap instead of queueing behind a tower full of zombies
	// that can no longer reach anyone.
	wipe_the_map();

	// THE AMBUSH — max spawn rate plus all three boss types cycling, every bit
	// of it under the existing actor caps. See _tod_bosses::finale_pressure_loop
	// for why this raises no limit.
	tod_bosses::finale_pressure_start();
	level thread road_seed_wave();           // v17.47: the road is populated BEFORE the party reaches it

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
	level.tod_finale_utc_start  = GetUTC();   // v19.76: wall time, for finale_clock_log
	finale_clock_log( "START" );

	// THE BEAT SYSTEM (v12.13, docs/41). All of these key off the song fields
	// just published, all die on "tod_finale_sealed" or "end_game", and every
	// one degrades to "the run as it was before v12.13" if its data or its
	// request is refused. See the beat table at the top of the file.
	level thread avenue_ignite();            // the avenue lights the road blue (green on the win)
	// (tide_run() was threaded here for one day — see the post-mortem at the
	// top of the beat table for what it was and why it is GONE.)
	level thread spawn_floor_phases();       // A2: pressure escalates with the score
	level thread beat_panzer_narrows();      // A2: the Narrows finally chokes
	level thread beat_protectors_flare();    // A2: the approach gets its fight
	level thread arrival_watch();            // A4: the citadel accepts you
	level thread heartbeat_run();            // rider: the crown's heartbeat
	level thread road_cull_run();            // the cap stays clear for the road ahead

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
	// 4. Wipe the map, once nothing else can add to it.
	// 5. Put the count-in pillars out LAST: the count is settled the moment the
	//    door is shut, and its glow used to burn through the whole hold-out.
	warn_banner( false );
	gather_to_centre();
	crown_door_close();
	// A4 (v12.13): the seal is a scored DOWNBEAT, not a click — the quake sells
	// the slam. Decoration only: the gather -> close -> stragglers order above
	// is byte-identical and stays that way (see the load-bearing note above).
	Earthquake( 0.6, 1.5, tod_crown_data::crown_door_org(), 1600 );
	// The road is gone: the phased floor hands the siege back to full pressure
	// on stock cadence — and every UNCONSUMED beat dies with the road (review
	// FIX 2/4): a surviving rp force-org would land a protector on the sealed
	// causeway behind the shut door, where in_hall filters starve it and the
	// stuck-watch reads d<=1500 as "engaging" — a stranded actor holding a
	// TOD_FINALE_BOSS_ROOF slot for the whole siege.
	level.tod_finale_spawn_floor = 0.1;
	level.tod_finale_pressure_tick = undefined;
	level.tod_rp_force_orgs = undefined;
	level.tod_boss_force_org = undefined;
	level.tod_beat_panzer_armed = undefined;
	level.tod_beat_prot_armed = undefined;
	kill_stragglers();
	wipe_the_map();
	pillar_countin_clear();   // 5. the count-in is settled — put the pillars out

	// NOBODY MADE IT. Without this the siege ran its full length in an empty
	// sealed hall and then printed YOU ESCAPED THE TOWER (peer review, and the
	// other half of the kill_stragglers blocker). If the citadel is empty the run
	// is over and it is a loss - stock's own wipe would normally have fired
	// already, but a straggler killed on this same frame may not have resolved
	// into it yet, so say it explicitly.
	if ( !anyone_sealed_in() )
	{
		finale_log( "SEAL nobody upright inside the crown -> end_game" );
		level notify( "end_game" );
		return;
	}
	finale_log( "SEAL holdout begins" );

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
		// A4 (v12.13): the hold-out OPENS with the Panzer crashing through the
		// open crown top onto the hall floor — holdout_start just banked his
		// debt; the force-org seam makes the director land him on the authored
		// mark (clear of the gather ring/dais/pillars/crate) with the full
		// drop-in theater. wipe_the_map above cleared every slot, so the roof
		// cannot refuse him.
		level.tod_boss_force_org = tod_crown_data::siege_panzer_org();
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
		finale_clock_log( "SEAL hold_s=" + hold );
		for ( i = 0; i < 4; i++ )
		{
			wait quarter;
			ignite_pylon( i );
			finale_clock_log( "PYLON " + ( i + 1 ) );
		}
	}

	// --- the song ends: you made it -----------------------------------------
	finale_clock_log( "READY" );
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
	//
	// v14 — THE ENDLESS SPIRE (docs/44): when the spire module is armed the win
	// no longer auto-departs. THE CHOICE takes over: two stations glow —
	// EXTRACT (this pad, the ending above) or ASCEND (the dais teleporter,
	// owned by _tod_spire via the notify contract; no #using either way, so
	// either module degrades to a no-op without the other).
	if ( IS_TRUE( level.tod_spire_ready ) )
		level thread choice_phase();
	else
		level thread depart();
}

// ---------------------------------------------------------------------------
// THE CHOICE (v14, docs/44). The hall is quiet — zombies wiped, spawns starved
// (tod_choice_pending, read by _tod_endless_rounds), the song over and the
// channel stopped — while the party decides. FIRST COMMITTED HOLD WINS for the
// whole party (approved design): the extract loop below, or the spire's own
// ascend loop, whichever lands first; each retires the other by notify.
// ---------------------------------------------------------------------------

function choice_phase()
{
	level endon( "end_game" );
	level endon( "tod_ascend" );

	level.tod_finale_state = "choice";
	level.tod_choice_pending = true;
	// A COMPLETELY QUIET DECISION (user 2026-08-29: "when you are picking
	// between ascending and [extracting] can we not have any enemies spawn
	// in"). BOTH pause lanes, because they gate different spawners:
	//   world_is_paused    — stock round_spawning waits on it (_zm.gsc:3747):
	//                        ZOMBIES halt this frame. (Not a spawn-delay trick:
	//                        the live test proved a 999s resolver return is
	//                        consumed per-round and deadlocked the spire.)
	//   tod_upgrade_pause  — the boss DIRECTOR and the finale pressure loop
	//                        both check it: PANZERS/PROTECTORS/etc. stop too.
	// Both cleared on either exit (extract below; ascend in _tod_spire).
	if ( !( level flag::exists( "world_is_paused" ) ) )
		level flag::init( "world_is_paused" );
	level flag::set( "world_is_paused" );
	level.tod_upgrade_pause = true;
	wipe_the_map();
	tod_atmosphere::channel_stop();
	level thread choice_banners();
	level notify( "tod_choice_begin" );
	// v19.68r THE ROCKETS (docs/170): the extract SHIP stands over this pad and carries its own EXTRACT prompt
	// (_tod_rocket::rockets_arm, the same string), so the pad's trigger stands down - it is inside the ship's
	// clip. Without the rockets (no rocket data in the generated crown file) the pad is the way out, as before.
	if ( IS_TRUE( level.tod_rockets_ready ) )
	{
		if ( isdefined( level.tod_finale_pad_trig ) )
		{
			level.tod_finale_pad_trig SetHintString( "" );
			level.tod_finale_pad_trig TriggerEnable( false );
		}
	}
	else
		level thread extract_use_loop();

	level waittill( "tod_extract" );
	level.tod_choice_pending = undefined;
	level.tod_upgrade_pause = false;
	if ( level flag::exists( "world_is_paused" ) )
		level flag::clear( "world_is_paused" );
	level thread depart();
}

// DEV ONLY - HARNESS #8 (docs/170, the rockets' test path): THE CHOICE opened as if the crown fight had just
// been won, so both rides can be tried without the whole finale. The band music latched off (choice_phase
// stops the channel), the crown a playable zone, the party on the gather ring in the hall, the pylons and the
// pad green - then the REAL choice_phase: the wipe, the pause, the banners, and the ships coming down.
// Delete with the harness.
function dev_open_choice()
{
	level.tod_finale_music = true;
	if ( level flag::exists( "enter_roof" ) )
		level flag::set( "enter_roof" );   // roof_zone (the crown: stair, terrace, causeway, hall) is live
	players = GetPlayers();
	n = 0;
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		p SetOrigin( gather_spot( n ) );
		p SetPlayerAngles( ( 0, n * 90 + 180, 0 ) );   // face the middle
		n++;
	}
	level.tod_finale_state = "ready";
	if ( isdefined( level.tod_finale_pylons ) )
	{
		for ( i = 0; i < level.tod_finale_pylons.size; i++ )
			tod_perk_lights::set_glow( level.tod_finale_pylons[ i ], TOD_GLOW_GREEN );
	}
	if ( isdefined( level.tod_finale_pad ) )
	{
		level.tod_finale_pad SetModel( "p7_out_mech_spawn_pad_light_green" );
		tod_perk_lights::set_glow( level.tod_finale_pad, TOD_GLOW_GREEN );
	}
	finale_log( "DEV_OPEN_CHOICE players=" + n + " rockets=" + IS_TRUE( level.tod_rockets_ready ) );
	level thread choice_phase();
}

// Re-arming a use path on the exfil pad is safe NOW and only now: the deleted
// v10 exfil_use_loop raced the song timer's automatic depart — with the
// auto-depart gone (choice_phase above), this is once again the only road in.
function extract_use_loop()
{
	level endon( "end_game" );
	level endon( "tod_ascend" );

	t = level.tod_finale_pad_trig;
	if ( !isdefined( t ) )
		return;
	t SetHintString( "Hold ^3[{+activate}]^7 ^2EXTRACT^7 - leave the tower" );
	for ( ;; )
	{
		t waittill( "trigger", player );
		if ( !isdefined( player ) || !isplayer( player ) )
			continue;
		if ( !( zm_utility::is_player_valid( player ) ) )
			continue;
		if ( player zm_utility::in_revive_trigger() )
			continue;
		level notify( "tod_extract" );
		return;
	}
}

// One banner per player for the whole decision window — a server hudelem with
// baked art (the images-over-LUI rule; zero clientuimodel bits).
function choice_banners()
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
		// 600x150 at y-130 (live report 2026-08-29: "too big and off the
		// screen on the top. Just a bit is cut off") — 720x180 at y-170 put
		// the top edge at -260 vs the 480-unit virtual screen's -240 edge;
		// this tops out at -205 with margin.
		e.y -= 130;
		e.foreground = true;
		e.color = ( 1, 1, 1 );
		e.hidewheninmenu = true;
		e.alpha = 0;
		e SetShader( "tod_choice_banner", 600, 150 );
		e FadeOverTime( 1 );
		e.alpha = 1;
		elems[ elems.size ] = e;
		p tod_upgrade_ui::banner_track( e );   // steps aside while this player holds the scoreboard (2026-09-27)
	}

	level util::waittill_any( "tod_extract", "tod_ascend" );
	for ( i = 0; i < elems.size; i++ )
	{
		if ( isdefined( elems[ i ] ) )
			elems[ i ] Destroy();
	}
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
		p DoDamage( p.health + 1000, p.origin );
		// AFTER the damage, exactly as stock orders it (_zm.gsc:2097-2101). In
		// co-op the hit puts an upright straggler into last stand, and stock's
		// Laststand_Bleedout writes the FULL bleedout_time as its first act —
		// a zero written BEFORE the damage was overwritten, so the straggler
		// got a ~30 s crawl and the containment watch teleported them into the
		// sealed hall to be revived (bug review 2026-09-22, F06).
		p.bleedout_time = 0;      // no crawling, no waiting
		p thread straggler_bleed_zero();   // belt: re-assert a frame later if last stand landed late
		finale_log( "STRAGGLER player=" + p GetEntityNumber() + " killed at seal" );
	}
}

function straggler_bleed_zero()   // self = the straggler
{
	self endon( "disconnect" );
	wait 0.05;
	if ( isdefined( self ) && ( self laststand::player_is_in_laststand() ) )
		self.bleedout_time = 0;
}

// Dev log for the crown run. Assembled outside the developer block, printed
// inside it (the proven pattern).
// v19.76 — THE PAUSE PROBE (lead tester Nikolai, Oct 2026: "on solo you can pause
// during the boss fight and it will continue to play the music when you un pause it
// would show you Extract or Ascend"). Half of that is settled in the data: every
// music alias carried an empty Pauseable column, so the closing song played on
// through a solo pause while the fight's clock stood still, and the two came apart
// (tod_music_finale is Pauseable since v19.76). This line settles the other half -
// whether the GAME clock (GetTime, every wait in this file) runs through a pause:
// GetUTC is wall time, so a pause shows as real_s well ahead of game_s. Printed in
// every developer run, tod_dev or not: about seven lines per finale.
function finale_clock_log( tag )
{
	if ( !isdefined( level.tod_finale_song_start ) || !isdefined( level.tod_finale_utc_start ) )
		return;
	game_s = ( GetTime() - level.tod_finale_song_start ) / 1000.0;
	real_s = GetUTC() - level.tod_finale_utc_start;
	line = "[TOD_FINALE] CLOCK " + tag + " game_s=" + game_s + " real_s=" + real_s + " drift_s=" + ( real_s - game_s );
	/#
	PrintLn( line );
	#/
}

function finale_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	line = "[TOD_FINALE] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
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
		// A crawler does not count — UNLESS stock's solo Quick Revive is about
		// to stand them up (waiting_to_revive is stock's own marker, set for
		// the 10 s self-revive and nowhere else). all_living_in_crown() counts
		// a crawler as inside, so a solo player who went down at the gate and
		// crawled in was sealed and then handed GAME OVER by finale_run while
		// their banked revive was seconds away (bug review 2026-09-22, F01).
		// Stock's own out-of-bounds kill carves out the same case (_zm.gsc:2092).
		if ( p laststand::player_is_in_laststand() && !IS_TRUE( p.waiting_to_revive ) )
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
			// v19.68r: a rocket rider is off the ground by design, and the riders the crash sets down at the Spire
			// are where they belong (docs/170) - pulling either back into the hall would break the ride.
			if ( IS_TRUE( p.tod_rocket_riding ) || IS_TRUE( level.tod_ascend_by_rocket ) )
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
// THE ROAD CULL — TOD_FINALE_CULL_DIST carries why this exists at all. Runs
// only between the buy and the seal: after the seal every zombie is inside the
// hall with the party by construction (the sealed-crown filter in
// finale_spawn_selection), so there is nothing left behind to cull.
function road_cull_run()
{
	level endon( "end_game" );
	level endon( "tod_finale_sealed" );

	for ( ;; )
	{
		wait TOD_FINALE_CULL_TICK;

		// THE FOCUS SET IS EVERY LIVING PLAYER, crawlers included. A downed
		// player is a place his team is coming back to, and the wave around him
		// is the reason that revive is hard — culling it would quietly make going
		// down safer than staying up. (Contrast finale_spawn_selection, which
		// excludes laststand from the SPAWN focus, for the opposite reason.)
		alive = [];
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( isdefined( p ) && isplayer( p ) && isalive( p ) )
				alive[ alive.size ] = p;
		}
		if ( alive.size == 0 )
			continue;

		// THE FRONT OF THE PARTY on the road (v17.47, see TOD_FINALE_ROAD_Z_MIN).
		// Only players actually up on the road envelope count; a player still on
		// the crown stair below leaves it undefined and the cull runs as before.
		front_y = undefined;
		for ( j = 0; j < alive.size; j++ )
		{
			if ( alive[ j ].origin[ 2 ] <= TOD_FINALE_ROAD_Z_MIN )
				continue;
			if ( !isdefined( front_y ) || alive[ j ].origin[ 1 ] > front_y )
				front_y = alive[ j ].origin[ 1 ];
		}

		ai = GetAISpeciesArray( "all" );
		for ( i = 0; i < ai.size; i++ )
		{
			e = ai[ i ];
			if ( !isdefined( e ) || !isalive( e ) )
				continue;
			if ( IS_TRUE( e.ignore_enemy_count ) )   // every elite sets it — they are not on this cap
				continue;
			// AHEAD OF THE PARTY ON THE ROAD = THE WAVE. Never culled (v17.47).
			if ( isdefined( front_y ) && e.origin[ 2 ] > TOD_FINALE_ROAD_Z_MIN
			     && e.origin[ 1 ] >= front_y - TOD_FINALE_CULL_BEHIND )
				continue;
			near = false;
			for ( j = 0; j < alive.size; j++ )
			{
				if ( DistanceSquared( e.origin, alive[ j ].origin ) <= ( TOD_FINALE_CULL_DIST * TOD_FINALE_CULL_DIST ) )
				{
					near = true;
					break;
				}
			}
			if ( !near )
				e Kill();
		}
	}
}

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

// ===========================================================================
// THE BEAT SYSTEM (v12.13, docs/41 — A1/A2/A4/riders/B1). Everything below is
// authored theater over EXISTING contracts: the aura clientfield, the derez
// pair, the door slab contract, the boss debt/roof system, the spawn filters.
// Nothing here raises a limit, adds a HUD element, or introduces a new death
// path except the tide's (which reuses the seal's own, by design).
// ===========================================================================

// Seconds into the closing song. 0 before the run starts.
function song_t()
{
	if ( !isdefined( level.tod_finale_song_start ) )
		return 0;
	return ( ( GetTime() - level.tod_finale_song_start ) / 1000.0 );
}

// The furthest UPRIGHT player's road_y, or undefined if nobody is past the
// gate. Hall players count (their road_y is past every road threshold), which
// is exactly right for beats keyed on "the leader has passed X".
function leader_road_y()
{
	best = undefined;
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		if ( p laststand::player_is_in_laststand() )
			continue;
		if ( !( tod_crown_data::beyond_gate( p.origin ) ) )
			continue;
		ry = tod_crown_data::road_y( p.origin );
		if ( !isdefined( best ) || ry > best )
			best = ry;
	}
	return best;
}

// --- THE AVENUE ------------------------------------------------------------
// Glow hosts on the three portal frames and the eight avenue pylon pips, all
// ignited BLUE at the buy — the road lights the way to the citadel — and
// strobed GREEN by depart_show on the win. (Their tide-era red flipping went
// with the tide; see the post-mortem at the beat table.)
function avenue_ignite()
{
	level endon( "end_game" );

	level.tod_avenue_hosts = [];
	po = tod_crown_data::portal_orgs();
	for ( i = 0; i < po.size; i++ )
		avenue_host( po[ i ] + ( 0, 0, 120 ) );
	ao = tod_crown_data::avenue_pylon_orgs();
	for ( i = 0; i < ao.size; i++ )
		avenue_host( ao[ i ] );
}

function avenue_host( org )
{
	h = prop( "tag_origin", org, 0 );
	if ( !isdefined( h ) )
		return;
	tod_perk_lights::set_glow( h, TOD_GLOW_BLUE );
	level.tod_avenue_hosts[ level.tod_avenue_hosts.size ] = h;
}

// --- A2: THE PHASED PRESSURE ------------------------------------------------
function spawn_floor_phases()
{
	level endon( "end_game" );
	level endon( "tod_finale_sealed" );

	set_spawn_floor( 0.4 );   // the overture — the one moment you get to LOOK at it
	while ( song_t() < TOD_PHASE2_SECS )
		wait 0.25;
	set_spawn_floor( 0.2 );   // the build
	while ( song_t() < TOD_PHASE3_SECS )
		wait 0.25;
	set_spawn_floor( 0.1 );   // the sustained section: full pressure
	level.tod_finale_pressure_tick = 4;   // and tighter boss top-ups with it
}

// v17.47: the floor is written STRAIGHT INTO zombie_vars as well as published
// for the resolver. Stock consults func_get_zombie_spawn_delay ONCE per round
// (_zm.gsc:4502) and sleeps on zombie_vars["zombie_spawn_delay"] for the whole
// of it, so until now every phase change here landed on the NEXT round flip —
// the road ran at whatever the last round stamped. The spire's ascension and
// the Warden seal do exactly this direct write for the same reason
// (_tod_spire.gsc, "a mid-round change lands late").
function set_spawn_floor( f )
{
	level.tod_finale_spawn_floor = f;
	if ( isdefined( level.zombie_vars ) )
		level.zombie_vars[ "zombie_spawn_delay" ] = f;
}

// THE SEED WAVE (v17.47) — see the TOD_FINALE_SEED_* block. Runs once, at the
// buy, right after the wipe has emptied the cap.
function road_seed_wave()
{
	level endon( "end_game" );
	level endon( "tod_finale_sealed" );

	if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 )
		return;
	if ( !isdefined( level.zm_loc_types ) )
		return;
	spots = level.zm_loc_types[ "zombie_location" ];
	if ( !isdefined( spots ) || spots.size == 0 )
		return;

	// The party's front, upright players on the road envelope only (the same
	// read as road_cull_run). Nobody up there yet = no wave to seed.
	front_y = undefined;
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		if ( p laststand::player_is_in_laststand() )
			continue;
		if ( p.origin[ 2 ] <= TOD_FINALE_ROAD_Z_MIN )
			continue;
		if ( !isdefined( front_y ) || p.origin[ 1 ] > front_y )
			front_y = p.origin[ 1 ];
	}
	if ( !isdefined( front_y ) )
		return;

	y_lo = front_y + TOD_FINALE_SEED_MIN_AHEAD;
	y_hi = front_y + TOD_FINALE_SEED_MAX_AHEAD;
	gate_y = tod_crown_data::gate_org()[ 1 ];   // nothing past the crown gate (v14.48's rule)
	if ( y_hi > gate_y )
		y_hi = gate_y;

	cand = [];
	for ( i = 0; i < spots.size; i++ )
	{
		sp = spots[ i ];
		if ( !isdefined( sp ) || !isdefined( sp.origin ) )
			continue;
		if ( sp.origin[ 2 ] <= TOD_FINALE_ROAD_Z_MIN )
			continue;
		if ( sp.origin[ 1 ] < y_lo || sp.origin[ 1 ] > y_hi )
			continue;
		// A sealed lane's risers are the stranded-actor trap — the same AABB
		// test _tod_endless_rounds::finale_spawn_selection applies.
		if ( isdefined( level.tod_lane_seal_mins ) && isdefined( level.tod_lane_seal_maxs ) )
		{
			sealed = false;
			for ( b = 0; b < level.tod_lane_seal_mins.size; b++ )
			{
				mn = level.tod_lane_seal_mins[ b ];
				mx = level.tod_lane_seal_maxs[ b ];
				if ( sp.origin[ 0 ] >= mn[ 0 ] && sp.origin[ 0 ] <= mx[ 0 ]
				  && sp.origin[ 1 ] >= mn[ 1 ] && sp.origin[ 1 ] <= mx[ 1 ] )
				{
					sealed = true;
					break;
				}
			}
			if ( sealed )
				continue;
		}
		cand[ cand.size ] = sp;
	}
	if ( cand.size == 0 )
		return;

	for ( n = 0; n < TOD_FINALE_SEED_N; n++ )
	{
		// Under the cap like every spawn — this raises no limit.
		while ( zombie_utility::get_current_zombie_count() >= level.zombie_ai_limit )
			wait 0.1;
		spawner = level.zombie_spawners[ RandomInt( level.zombie_spawners.size ) ];
		sp = cand[ RandomInt( cand.size ) ];
		guy = zombie_utility::spawn_zombie( spawner, spawner.targetname, sp );
		if ( isdefined( guy ) )
			guy thread zombie_utility::round_spawn_failsafe();
		wait 0.15;
	}
}

// --- A2: THE NARROWS DROP ---------------------------------------------------
function beat_panzer_narrows()
{
	level endon( "end_game" );
	level endon( "tod_finale_sealed" );

	// THE ARMED FLAG (review FIX 4 — this IS the "replace, don't add"
	// interlock the spec demanded): while armed, the pressure loop's panzer
	// rotation turn is SKIPPED, so no roving Panzer can occupy the 1-alive
	// roof before the beat fires — without it the loop's first tick (~t=6s)
	// landed one and the flagship drop silently no-op'd every run.
	level.tod_beat_panzer_armed = true;

	for ( ;; )
	{
		wait 0.25;
		t = song_t();
		if ( t >= TOD_BEAT_PANZER_CAP )
			break;
		if ( t >= TOD_BEAT_PANZER_SECS )
		{
			ly = leader_road_y();
			if ( isdefined( ly ) && ly >= tod_crown_data::beat_narrows_trigger_y() )
				break;
		}
	}
	// the roof arithmetic answers in _tod_bosses; retry a few ticks if it is
	// momentarily full, then let the beat go — the road is already loud
	for ( k = 0; k < 4; k++ )
	{
		if ( tod_bosses::finale_beat_panzer( tod_crown_data::beat_narrows_org() ) )
			break;
		wait 3;
	}
	level.tod_beat_panzer_armed = undefined;
}

// --- A2: THE FLARE DROP -----------------------------------------------------
function beat_protectors_flare()
{
	level endon( "end_game" );
	level endon( "tod_finale_sealed" );

	// same interlock as the panzer beat — the loop's protector turn holds off
	// so the flare drop is the wave that was scheduled, not one on top of it
	level.tod_beat_prot_armed = true;

	for ( ;; )
	{
		wait 0.25;
		ly = leader_road_y();
		if ( isdefined( ly ) && ly >= tod_crown_data::beat_flare_trigger_y() )
			break;
	}
	for ( k = 0; k < 4; k++ )
	{
		if ( tod_bosses::finale_beat_protectors( tod_crown_data::beat_flare_orgs() ) )
			break;
		wait 3;
	}
	level.tod_beat_prot_armed = undefined;
}

// --- A4: THE ARRIVAL --------------------------------------------------------
// Portal 3 stands inside the crown's throat and is gold precisely because "the
// colour change IS the arrival" — until now you ran through it and nothing
// happened. The first survivor across it trips THE ACCEPTANCE: the hall lights
// itself for you, front to back, and the pillars count your people in.
function arrival_watch()
{
	level endon( "end_game" );
	level endon( "tod_finale_sealed" );

	po = tod_crown_data::portal_orgs();
	p3y = tod_crown_data::road_y( po[ po.size - 1 ] );
	for ( ;; )
	{
		wait 0.25;
		ly = leader_road_y();
		if ( isdefined( ly ) && ly >= p3y )
			break;
	}
	level thread acceptance_show();
	level thread pillar_countin();
}

function acceptance_show()
{
	level endon( "end_game" );

	// a ground ripple walking gate -> dais, five 0.3s steps, world-safe by
	// construction (interpolated between two generated anchors)
	a = tod_crown_data::crown_door_org();
	b = tod_crown_data::hall_center();
	for ( i = 0; i <= 4; i++ )
	{
		f = i / 4.0;
		pt = ( a[ 0 ] + ( b[ 0 ] - a[ 0 ] ) * f, a[ 1 ] + ( b[ 1 ] - a[ 1 ] ) * f, b[ 2 ] + 8 );
		tod_perk_scatter::derez_burst( pt );
		wait 0.3;
	}
	// the sconces ignite in sequence toward the pad — the room lighting itself
	if ( isdefined( level.tod_finale_sconces ) )
	{
		for ( i = 0; i < level.tod_finale_sconces.size; i++ )
		{
			s = level.tod_finale_sconces[ i ];
			if ( isdefined( s ) )
				tod_perk_lights::set_glow( s, TOD_GLOW_TEAL );
			if ( ( i % 2 ) == 1 )
				wait 0.15;
		}
	}
	tod_perk_scatter::play_sound_at_origin( tod_crown_data::hall_center(), "zmb_cha_ching", 4 );
}

// The four hall pillars count the party in: one burns red per living player,
// each snaps green as that many teammates make it inside.
//
// IT GOES OUT AT THE SEAL (v17.37, user 2026-09-04: "there is a green glow sfx
// in the room during the fight on top of a piller. lets remove that as well").
// This thread's endon fires at the seal, so it STOPPED updating and left its
// last frame lit — a green aura burning over a crossing pier for the whole
// hold-out, long after it meant anything. A count-in is a thing you read while
// people are still arriving; once the door is shut the count is settled and
// the glow is just an FX nobody can turn off. An endon is not a cleanup: any
// thread that leaves world state behind needs someone to clear it, and that is
// pillar_countin_clear() in the seal block (heartbeat_run does its own, by
// polling instead of endon-ing — the other half of this lesson).
function pillar_countin()
{
	level endon( "end_game" );
	level endon( "tod_finale_sealed" );

	orgs = tod_crown_data::hall_pillar_orgs();
	hosts = [];
	for ( i = 0; i < orgs.size; i++ )
	{
		h = prop( "tag_origin", orgs[ i ], 0 );
		if ( isdefined( h ) )
			hosts[ hosts.size ] = h;
	}
	if ( hosts.size == 0 )
		return;
	level.tod_pillar_hosts = hosts;   // the seal puts these out — pillar_countin_clear()

	shown = [];
	for ( i = 0; i < hosts.size; i++ )
		shown[ i ] = -1;
	for ( ;; )
	{
		n_live = 0;
		n_in = 0;
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
				continue;
			n_live++;
			if ( tod_crown_data::in_hall( p.origin ) )
				n_in++;
		}
		if ( n_live > hosts.size )
			n_live = hosts.size;
		if ( n_in > n_live )
			n_in = n_live;
		for ( i = 0; i < hosts.size; i++ )
		{
			want = 0;
			if ( i < n_in )
				want = TOD_GLOW_GREEN;
			else if ( i < n_live )
				want = TOD_GLOW_RED;
			if ( want == shown[ i ] )
				continue;
			shown[ i ] = want;
			tod_perk_lights::set_glow( hosts[ i ], want );
			if ( want == TOD_GLOW_GREEN )
				tod_perk_scatter::play_sound_at_origin( hosts[ i ].origin, "zmb_cha_ching", 3 );
		}
		wait 0.25;
	}
}

// The seal's half of pillar_countin: every host dark AND deleted, so nothing
// can relight them and they stop costing an entity for the rest of the match
// (the ~1024-gentity budget is this map's binding constraint). Safe to call
// twice and safe if the count-in never ran.
function pillar_countin_clear()
{
	if ( !isdefined( level.tod_pillar_hosts ) )
		return;
	hosts = level.tod_pillar_hosts;
	level.tod_pillar_hosts = undefined;
	for ( i = 0; i < hosts.size; i++ )
	{
		if ( !isdefined( hosts[ i ] ) )
			continue;
		tod_perk_lights::set_glow( hosts[ i ], 0 );
		hosts[ i ] Delete();
	}
}

// --- rider: THE CROWN'S HEARTBEAT -------------------------------------------
// A red pulse at the girandole — the ruby pendant under the vortex bell — on
// an 8s beat that halves at each portal the leader crosses, and STOPS when the
// door slams: the crown's heart stops because you are inside it now.
function heartbeat_run()
{
	level endon( "end_game" );

	h = prop( "tag_origin", tod_crown_data::girandole_org(), 0 );
	if ( !isdefined( h ) )
		return;
	portals = tod_crown_data::portal_orgs();

	for ( ;; )
	{
		if ( IS_TRUE( level.tod_crown_sealed ) || level.tod_finale_state == "departing" || level.tod_finale_state == "done" )
		{
			tod_perk_lights::set_glow( h, 0 );
			return;
		}
		crossed = 0;
		ly = leader_road_y();
		if ( isdefined( ly ) )
		{
			for ( i = 0; i < portals.size; i++ )
			{
				if ( ly >= tod_crown_data::road_y( portals[ i ] ) )
					crossed++;
			}
		}
		period = 8.0;
		if ( crossed == 1 )
			period = 4.0;
		else if ( crossed == 2 )
			period = 2.0;
		else if ( crossed >= 3 )
			period = 1.0;
		tod_perk_lights::set_glow( h, TOD_GLOW_RED );
		wait 0.4;
		tod_perk_lights::set_glow( h, 0 );
		rest = period - 0.4;
		if ( rest < 0.2 )
			rest = 0.2;
		wait rest;
	}
}

// --- B1: THE LANE LOTTERY ---------------------------------------------------
// The road you paid for is never the same road twice: one lane per fork is
// rolled dead each run, sealed at its SOUTH mouth in the causeway gate's own
// visual grammar. South-mouth-only keeps every lane path-connected via its
// merge (nothing strands, player or zombie); the riser filter in
// _tod_endless_rounds keeps spawns out of the dead band.
function lane_seals_init()
{
	level.tod_lane_seals = [];
	for ( i = 0; i < 5; i++ )
	{
		e = GetEnt( "tod_lane_seal_" + i, "targetname" );
		if ( !isdefined( e ) )
		{
			// generator drift — a road with every lane open is survivable,
			// a script error is not (the causeway gate's own rule)
			level.tod_lane_seals = undefined;
			return;
		}
		e Hide();
		e NotSolid();
		e ConnectPaths();
		level.tod_lane_seals[ i ] = e;
	}
}

function lane_lottery()
{
	if ( !isdefined( level.tod_lane_seals ) )
		return;

	picks = [];
	f1 = lottery_pick( 0, 2 );
	if ( isdefined( f1 ) )
		picks[ picks.size ] = f1;
	f2 = lottery_pick( 2, 5 );
	if ( isdefined( f2 ) )
		picks[ picks.size ] = f2;
	if ( picks.size == 0 )
		return;

	bm = tod_crown_data::lane_band_mins();
	bx = tod_crown_data::lane_band_maxs();
	so = tod_crown_data::lane_seal_orgs();
	mins = [];
	maxs = [];
	for ( i = 0; i < picks.size; i++ )
	{
		idx = picks[ i ];
		e = level.tod_lane_seals[ idx ];
		if ( !isdefined( e ) )
			continue;
		e Show();
		e Solid();
		e DisconnectPaths();
		tod_perk_scatter::derez_burst( so[ idx ] );
		tod_perk_scatter::play_sound_at_origin( so[ idx ], "zmb_cha_ching", 4 );
		h = prop( "tag_origin", so[ idx ], 0 );
		if ( isdefined( h ) )
			tod_perk_lights::set_glow( h, TOD_GLOW_RED );
		mins[ mins.size ] = bm[ idx ];
		maxs[ maxs.size ] = bx[ idx ];
	}
	if ( mins.size > 0 )
	{
		// read by _tod_endless_rounds::finale_spawn_selection
		level.tod_lane_seal_mins = mins;
		level.tod_lane_seal_maxs = maxs;
	}
}

// A random un-occupied lane index in [lo, hi), or undefined if every candidate
// has a player standing in its slab (dev-harness case — the gate opens early
// there, so someone can genuinely be at a mouth when extraction is bought).
function lottery_pick( lo, hi )
{
	n = hi - lo;
	start = lo + RandomInt( n );
	for ( k = 0; k < n; k++ )
	{
		idx = lo + ( ( ( start - lo ) + k ) % n );
		if ( !seal_occupied( idx ) )
			return idx;
	}
	return undefined;
}

function seal_occupied( idx )
{
	mn = tod_crown_data::lane_seal_slab_mins();
	mx = tod_crown_data::lane_seal_slab_maxs();
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		if ( p.origin[ 0 ] >= ( mn[ idx ][ 0 ] - 48 ) && p.origin[ 0 ] <= ( mx[ idx ][ 0 ] + 48 )
		  && p.origin[ 1 ] >= ( mn[ idx ][ 1 ] - 48 ) && p.origin[ 1 ] <= ( mx[ idx ][ 1 ] + 48 )
		  && p.origin[ 2 ] > 19300 && p.origin[ 2 ] < 19800 )
			return true;
	}
	return false;
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
			// "^3HOLD THE CROWN^7" until 2026-09-11. User: "it says hold the
			// crown, but that confuses people. They think they need to hold
			// something ... they are just defending for a certain amount of
			// time." HOLD reads as "hold out" to anyone fluent in zombies and
			// as "press and hold" to everyone else, and this map spends the
			// word that second way on every buy prompt in it — so players stood
			// at the pad hunting for the thing to hold. DEFEND cannot be read
			// two ways, and the detail line says the part the old string never
			// did: that this ends on a clock, not on an objective.
			//
			// STILL A STATUS LINE: no [{+activate}] token, so PromptDefault
			// hides the whole footer and there is nothing to press. The " - "
			// splits it into the title band DEFEND THE CROWN over one detail
			// line, the grammar every other hint in the map uses.
			//
			// TOD_NOUNS in ZMCursorHintNew.lua carried "hold the crown" and now
			// carries "defend the crown". THE OBVIOUS REASON FOR THAT IS WRONG
			// TWICE OVER, so here is what is actually true — checked against
			// classifyHint, not assumed:
			//
			//   1. A stale noun would NOT have misrouted this line.
			//      classifyHint's last statement returns DefaultHint anyway, so
			//      an unclaimed status string lands on the same card. And
			//      nothing gates the pairing: reverting the noun on 2026-09-11
			//      left lint_tod_hints passing at 96/190, exit 0.
			//   2. "defend the crown" is not even what claims this string.
			//      The nouns are scanned IN ORDER and "extract" sits five
			//      entries earlier — it matches "extraction" in the detail line
			//      below, so the loop returns at "extract" and never reaches
			//      the crown nouns at all.
			//
			// It stays paired because the noun tracks the TITLE, and the title
			// is the half that survives a reword of the detail. Drop the detail
			// line's "extraction" and "defend the crown" becomes the claimant
			// for real. What the table buys either way is CLAIM ORDER: nouns
			// match at step 3, ahead of the perk-machine and Pack-a-Punch tests
			// at 4 and 5 — so a future reword containing a perk name, or the
			// words pack and punch, is misrouted without a matching noun.
			case "holdout":
			case "charging":   self SetHintString( "^3DEFEND THE CROWN^7 - survive until extraction arrives" ); break;
			// v14: extract_use_loop stamps this trigger's hint itself the moment
			// the choice opens — the case exists so the default's "back at the
			// TERRACE" line can never overwrite it.
			case "choice":     break;
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
			// " - " added v14.58 so PromptDefault splits this into the title
			// UPLINK over the detail line, instead of running the whole
			// sentence through the narrow title band as one string.
			default:           self SetHintString( "^3UPLINK^7 - it is back at the TERRACE" ); break;
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

	// v19.68r THE ROCKETS (docs/170; user 2026-10-02: "if you extract same thing but the extract ship goes
	// straight up and the game ends few seconds later"): the extract ship IS the send-off - the party boards, it
	// lifts off and climbs straight up, and ride_extract returns at its END beat a few seconds into the climb
	// (the ship keeps climbing behind the end screen). No ship (the pool refused it) = the old send-off.
	rode = false;
	if ( IS_TRUE( level.tod_rockets_ready ) )
		rode = tod_rocket::ride_extract();
	if ( !rode )
	{
		level thread depart_show();
		wait TOD_FINALE_DEPART_SECS;
	}

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
		// v12.13: the countdown avenue joins the send-off — every light the
		// tide turned red strobes green down the length of the dead road.
		if ( isdefined( level.tod_avenue_hosts ) )
		{
			for ( i = 0; i < level.tod_avenue_hosts.size; i++ )
			{
				a = level.tod_avenue_hosts[ i ];
				if ( isdefined( a ) )
					tod_perk_lights::set_glow( a, ( on ? TOD_GLOW_GREEN : 0 ) );
			}
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
	// 2026-09-27: +40 -> +10. The game-end scoreboard is FORCED up under this
	// screen now, and with four players its column header tops out at 397 of
	// 720 - the +40 line (720-y ~420) sat on it. +10 still clears the banner's
	// bottom edge (-18) by the text's own half-height.
	survived.y += 10;
	survived.foreground = true;
	survived.fontScale = 2;
	survived.alpha = 0;
	survived.color = ( 1.0, 1.0, 1.0 );
	survived.hidewheninmenu = true;

	// v19.58: "YOU SURVIVED N ROUNDS" in the map's typeface, under the banner
	// (the end scoreboard draws it; the stock line is faded out).
	player tod_gameover::end_screen_push( survived, 2, 0 );

	if ( player isSplitScreen() )
	{
		// Half the vertical room, so the banner shrinks with the text it replaced.
		game_over SetShader( "tod_win_banner", 600, 150 );
		game_over.y += 40;
		survived.fontScale = 1.5;
		survived.y += 40;
	}
}
