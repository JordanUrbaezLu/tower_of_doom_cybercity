// =============================================================================
// _tod_atmosphere.gsc — the tower's air: a cold neon city smog.
//
// ⚠️ THE 8-ARG OVERLOAD HAS NO OPACITY ARGUMENT. The header here used to read
// "SetVolFog( ..., r,g,b, maxOpacity ) — the stock 8-arg builtin", and that was
// WRONG for the life of this map. The 8th slot is <transition time>. Corrected
// 2026-08-30 (v14.37) against three independent sources:
//   1. <modtools>/docs_modtools/bo3_scriptapifunctions.htm — the 8-arg form
//      ends `<red>,<green>,<blue>,<TRANSITION TIME>`; <fog max opacity> exists
//      only in the 18-arg form, as arg 17.
//   2. Stock's ONLY call site, load_shared.gsc:807, passes 0.4 there — a
//      0.4-SECOND blend for a fog-volume trigger. (This is the very cite the
//      old header used to claim the opposite; it was misread.)
//   3. <modtools>/source_data/fog.gdt "default" ships "fogopacity" "0", and
//      our worldspawn declares `"fsi" "default"` — so max opacity booted at
//      ZERO and no 8-arg call could ever raise it.
// USER CONFIRMED LIVE: "Yes this map has never rendered fog." Every fog value
// in this file was tuned against a preview tool and had never been seen.
//
// ⚠️⚠️ AND THE ARG COUNT WAS NOT THE ROOT CAUSE ANYWAY (v14.41, the real one).
// `fsi` — the FOG SETTINGS asset baked from worldspawn — was `default`, whose
// fog.gdt entry carries "fogopacity" "0". The fog system was CLAMPED OFF at
// asset level, so no SetVolFog of any arity could ever have drawn. Fixed in
// tools/gen_tower_map.js: fsi -> `zm_factory_volumetric` (stock zm_factory's
// own entry, fogopacity 1). THAT is why the map now has air.
//
// SO WE ARE BACK ON THE 8-ARG FORM, DELIBERATELY (set_fog / spire_set_fog):
//   1 startDist 2 halfwayDist 3 halfwayHeight 4 baseHeight
//   5 red 6 green 7 blue 8 TRANSITION TIME
// v14.37 briefly moved to the 18-arg overload to reach <fogMaxOpacity>. It was
// reverted before shipping because that overload is used NOWHERE in the entire
// mod tools install (the only SetVolFog anywhere is load_shared.gsc:807, and it
// is 8-arg) — an unverified signature is not what you ship on the one feature
// the user said must not come back broken. With the fsi fixed it buys nothing.
// DENSITY IS CONTROLLED BY halfwayDist / halfwayHeight, real args of the proven
// call: shorter halfwayDist = thicker; larger halfwayHeight = holds with
// altitude. Opacity is the fsi's job now, map-wide.
// Pure script -> ships with a linker-only build, can never regress the bake.
//
// DESIGN: the haze is densest at street level (baseHeight 0) and halves every
// TOD_FOG_HALFWAY_HEIGHT units of altitude — so the base arena sits in thick
// purple-blue smog, the low laps fade the city below into glow, and by the
// mid-tower you have CLIMBED OUT of it into clear night air under the night
// skyline dome. Height-as-progress, told through the air. AS OF v14.37 THIS
// DESCRIBES SOMETHING THAT ACTUALLY RENDERS — read every value below as
// unproven-in-game until the first live look.
// Color must stay LIGHTER than scene-black or it reads as nothing (map 1
// lesson: near-black fog = invisible).
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\zm\zm_tower_of_doom\_tod_breather_data;   // GENERATED — lounge z list + pad anchor (v16.7 lounge FX / arrival chime)

#insert scripts\shared\shared.gsh;

#define TOD_FOG_START_DIST      300    // units from camera where haze begins
#define TOD_FOG_HALFWAY_DIST    2600   // distance to half opacity (open-air scale)
#define TOD_FOG_HALFWAY_HEIGHT  1200   // altitude falloff — thick low, clear by mid-tower
#define TOD_FOG_BASE_HEIGHT     0      // densest at street level
#define TOD_FOG_R               0.16   // cold purple-blue neon smog
#define TOD_FOG_G               0.14
#define TOD_FOG_B               0.30
// ⚠️ NOT AN OPACITY — this is passed as arg 8 of the 8-arg form, which is the
// TRANSITION TIME. Kept under its historical name only because it is threaded
// through set_fog's callers; read it as "the fog blend takes 0.38s". THE MAP'S
// ACTUAL OPACITY IS THE fsi ASSET (zm_factory_volumetric, fogopacity 1) — to
// make the tower's fog thinner or thicker, move TOD_FOG_HALFWAY_DIST (bigger =
// thinner) or switch the fsi to zm_factory_afog (fogopacity 0.5) in the
// generator. Do NOT expect changing this number to change density.
#define TOD_FOG_OPACITY         0.38
// Blend time for every ordinary fog write. Short enough to feel immediate,
// long enough that the two apply_fog asserts do not visibly pop.
#define TOD_FOG_TRANSITION      0.5

// ---- THE SPIRE'S FOG — the whole feature ---------------------------------
// ⚠️ THESE LIVE UP HERE FOR A REASON. They used to sit ~450 lines down, next
// to the spire functions, and apply_fog() references them — so the file was
// USING A #define BEFORE IT WAS DECLARED. GSC's preprocessor is strictly
// ordered and the linker's answer to that is:
//     SCRIPT ERROR: No generated data for '..._tod_atmosphere.gsc'
// i.e. the same opaque whole-file rejection as a misplaced #precache or a
// dangling variable. Cost one build. **Every #define this file uses must be
// declared above the first function that reads it.**
// ⚠️ THESE ARE NOW LIVE-TUNED VALUES — the first fog numbers in this map's
// history that anyone has actually SEEN. 2026-08-31: the user confirmed fog
// visible on the spire ("I do see it now") and asked for "way thicker and
// little bit more red". Everything above this line was theory; this is
// feedback. Treat these as the baseline and tune from here, not from the
// commented reasoning further up.
//
// MORE RED: R 0.30 -> 0.46, G/B held near zero so the extra energy all goes
// into the red channel rather than washing toward pink. Raising R also makes
// the fog MORE visible, not less — map 1's rule is that fog darker than the
// scene reads as nothing, so brighter red is both redder and more present.
#define TOD_SPIRE_FOG_R          0.46   // blood red — the spire's own monochrome
#define TOD_SPIRE_FOG_G          0.03
#define TOD_SPIRE_FOG_B          0.05
// Arg 8. Map 1 passes its opacity in this slot and its fog renders, which is
// the only evidence that outranks the API doc's "transition time" label —
// its working implementation beats our reading of the manual.
#define TOD_SPIRE_FOG_OPACITY    0.90
// ⚠️ NO ALTITUDE FALLOFF AT ALL — the fog must be EVEN from the arena floor to
// the summit (user, live, 2026-08-31: "make sure the fog spawns the entire
// endless spire tower evenly and all the way to top").
//
// Density falls as 2^(-(z - baseHeight) / halfHeight). The previous 42,000 was
// chosen to "hold most of the way up", but the arithmetic says otherwise:
// at the summit z=38,592 that is 2^(-38592/42000) = 2^-0.92 ≈ **0.53** — the
// top of the spire was running at HALF the density of the bottom, which is
// exactly the uneven look being reported. 42,000 sounded generous next to the
// tower's 1,200 and was still nowhere near flat.
//
// One million makes the exponent 2^(-0.039) ≈ **0.97**, i.e. within 3% from
// floor to beacon — even by any visual standard. This is the correct way to
// express "no height falloff": the parameter has no disable value, so you
// defeat it by making the halving distance vastly larger than the world.
// The TOWER keeps its 1,200 (height-as-progress) — that constant is separate
// and untouched.
#define TOD_SPIRE_FOG_HALFHEIGHT 1000000
// ⚠️ THESE TWO NOW MIRROR MAP 1'S PROVEN, VISIBLE-IN-GAME VALUES rather than
// numbers reasoned out here. Map 1 (_acc_atmosphere.gsc:41-48) ships
// START_DIST 0 / HALFWAY_DIST 550 / MAX_OPACITY 0.80 and its haze is thick and
// unmistakable. Ours was START 300 / HALF 1400 — fog that begins 300 units out
// and only reaches half density at 1400 is subtle even when it IS drawing,
// which is a terrible place to be while debugging "is it drawing at all".
// Start at the camera and go dense fast; back it off later if it is too much.
// WAY THICKER (user, live, 2026-08-31): halfway distance 600 -> 260. This is
// THE density knob and it is inverse — smaller = thicker. At 260 you are 50%
// fogged at 260 units, ~75% at 520, ~94% at 1000, so the far side of the
// spire's own staircase is already dissolving. Denser than map 1's proven 550
// on purpose: map 1's is an interior, the spire is open void where haze has to
// carry a much longer sightline. If it ever reads as a white-out, this single
// number is the whole fix — raise it.
#define TOD_SPIRE_FOG_STARTDIST  0
#define TOD_SPIRE_FOG_HALFDIST   260

// ---- MUSIC BANDS (v9.46, user 2026-08-23) --------------------------------
// LAP_RISE mirrored from tools/gen_tower_map.js (and from _tod_gauge's own
// copy of it). Duplicated rather than imported: _tod_gauge::floor_of returns a
// gauge CELL (2 floors per cell, 1..26), not a floor, so there is nothing there
// to reuse — and a #using into the gauge would couple the music channel to the
// HUD for one integer.
#define TOD_MUSIC_LAP_RISE      384
#define TOD_MUSIC_POLL_SECS     2      // how often the band watcher re-reads the party's high point
#define TOD_MUSIC_EE_GAP        3.0    // v18.96b (user: "3 seconds of silence ... Give some tension"): the old track stops, the room goes quiet, then the song
#define TOD_MUSIC_EE_SECS       279.3  // v18.96: the teddy-bear song's measured length (tod_music_ee.wav = "Falling To Pieces", ffprobe 279.33 s) — the channel is handed back after it

// v16.7 LOUNGE AMBIENCE — every one of these ALSO has an `fx,` line in
// zone_source (the pairing rule: a precache without the zone line resolves
// to nothing and PlayFX silently no-ops — the rampage spark's lesson).
#precache( "fx", "env/light/fx_light_god_rays_dust_motes" );
#precache( "fx", "dirt/fx_dust_linger_int_sector" );
#precache( "fx", "fog/fx_fog_ground_wind_lt_sm" );
#precache( "fx", "steam/fx_steam_leak_sm_soft_slow" );
#define TOD_LOUNGE_CHIME_ALIAS   "tod_lounge_arrive"   // sound/aliases/tod_ui.csv, 2D non-looping
#define TOD_LOUNGE_POLL_SECS     0.5
// ONE SWITCH for the script half of the v16.7 lounge pass (user: "I may want
// to revert"): 0 = no lounge FX, no arrival chime. The zone fx lines and the
// alias stay (harmless unused). The geometry half is BR_POLISH in the
// generator. This is a -GscOnly change.
#define TOD_LOUNGE_AMBIENCE      1

#namespace tod_atmosphere;

function init()
{
	level thread apply_fog();
	level thread ambient_music();
	if ( TOD_LOUNGE_AMBIENCE )
	{
		level thread lounge_fx();
		level thread lounge_arrival_watch();
	}
}

// ---------------------------------------------------------------------------
// v16.7 — THE LOUNGES BREATHE (user 2026-09-01: "continue enhance however we
// can"). The script half of the breather polish pass; the brushwork half is
// gen_tower_map.js §v16.7 and the record is docs/42.
//
// 1. AMBIENT FX per lounge — persistent LOOPING effects placed with server
//    PlayFX at fixed points after the blackscreen. THE RENDER LANE, PROVEN:
//    map 1's _acc_atmosphere::fx_at placed ~40 of these exactly this way and
//    they draw (its own note: "loops via fx_at DO, proven" — it is one-shot
//    server PlayFX that does not, which is why every burst in this map rides
//    a tag_origin host). Each asset has BOTH the #precache above AND an `fx,`
//    line in zone_source. All four are stock, map-1-proven on this same tools
//    install, and none carries a particlecloud reference (the pcloud crash
//    class that took out the green fungus pod on map 1).
//      motes  env/light/fx_light_god_rays_dust_motes  a shaft of drifting
//             motes falling from the open top into the room, lit by the
//             lounge's theme lights
//      haze   dirt/fx_dust_linger_int_sector          slow interior dust —
//             the "subtle life" layer map 1 gave every zone
//      fog    fog/fx_fog_ground_wind_lt_sm            ground fog curling over
//             the teleporter pad floating in the void
//      vent   steam/fx_steam_leak_sm_soft_slow        one soft vent at the
//             foot of the spur gate's east post
//    Placed under the blackscreen so they are alive at fade-in (map 1: "start
//    everything at once"); a late joiner sees an ongoing loop like any map FX.
//    Coordinates are the EVEN/mirrored frame every lounge sits in, z and the
//    pad point from the generated breather data — the furniture's own
//    no-drift contract.
//
// 2. ARRIVAL CHIME — the first time each player walks INTO each lounge they
//    hear a short 2D chime (tod_lounge_arrive, a rising synth arpeggio; the
//    non-caption lane, per the user's no-floaty-text rule). Nothing else marks
//    reaching a breather except the floor-10 music change, and the full-map
//    review's A8 asked for exactly this beat. At most four per player per run.
//    The footprint box is _tod_endless_rounds::tod_player_in_breather's
//    (LOCKSTEP: same x/y box, same z band) — that one calms the spawn clock,
//    this one plays a sound; both answer "is this player in a lounge".
// ---------------------------------------------------------------------------

function lounge_fx()
{
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );
	if ( !isdefined( level._effect ) )
		level._effect = [];
	level._effect[ "tod_lounge_motes" ] = "env/light/fx_light_god_rays_dust_motes";
	level._effect[ "tod_lounge_haze" ]  = "dirt/fx_dust_linger_int_sector";
	level._effect[ "tod_lounge_fog" ]   = "fog/fx_fog_ground_wind_lt_sm";
	level._effect[ "tod_lounge_vent" ]  = "steam/fx_steam_leak_sm_soft_slow";
	zs = tod_breather_data::breather_zs();
	for ( i = 0; i < zs.size; i++ )
	{
		z = zs[ i ];
		// Room centre (-528,-704): the motes fall from just under the cap
		// band (z+260 of a 296 wall), the haze sits at chest height. The pad
		// point is the porter's own anchor; the vent sits at the foot of the
		// gate's east post (even frame x[-804,-784] y[-1060,-1012]).
		lounge_fx_at( "tod_lounge_motes", ( -528, -704, z + 260 ) );
		lounge_fx_at( "tod_lounge_haze", ( -528, -704, z + 100 ) );
		pad = tod_breather_data::tp_pad_org( z );
		lounge_fx_at( "tod_lounge_fog",   ( pad[ 0 ], pad[ 1 ], z + 4 ) );
		lounge_fx_at( "tod_lounge_vent",  ( -794, -1036, z + 8 ) );
	}
}

function lounge_fx_at( key, origin )
{
	if ( isdefined( level._effect[ key ] ) )
		PlayFX( level._effect[ key ], origin );
}

function lounge_arrival_watch()
{
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );
	zs = tod_breather_data::breather_zs();
	for ( ;; )
	{
		wait TOD_LOUNGE_POLL_SECS;
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isdefined( p ) || !IsAlive( p ) )
				continue;
			// ALIVE + PLAYING ONLY — a spectator's origin rides the camera
			// (the gauge's own rule), and a chime for a dead player is noise.
			if ( isdefined( p.sessionstate ) && p.sessionstate != "playing" )
				continue;
			j = lounge_index_at( p.origin, zs );
			if ( j < 0 )
				continue;
			if ( !isdefined( p.tod_lounge_seen ) )
				p.tod_lounge_seen = [];
			if ( IS_TRUE( p.tod_lounge_seen[ j ] ) )
				continue;
			p.tod_lounge_seen[ j ] = true;
			p PlayLocalSound( TOD_LOUNGE_CHIME_ALIAS );
		}
	}
}

// -> the lounge index (0..3) whose room + spur box holds this point, else -1.
// The box is _tod_endless_rounds::tod_player_in_breather's (LOCKSTEP): it
// takes in the 16u doorway threshold of the landing on purpose, so the chime
// lands as you step through the door, not three strides later.
function lounge_index_at( o, zs )
{
	return tod_breather_data::lounge_index_at( o );
}

// ---------------------------------------------------------------------------
// MUSIC — this module is the ONE owner of the music channel.
//
// Base state (user 2026-08-19): ONE low background track on repeat. v9.46
// (user 2026-08-23) makes that the FIRST of several — the track changes as the
// party climbs past the breather floors, see register_music_bands(). PANZER
// OVERRIDE (user 2026-08-19, reaffirmed 2026-08-23 "boss music will always
// override this"):
// while any Panzer is alive the boss track (tod_boss_music, vol 75) owns the
// channel — the ambient stops on the first Panzer's spawn and RESUMES when
// the last one dies (a stream can't pause, so it restarts — by design).
// Refcounted over Panzers only; Rogue Protectors never touch the music.
//
// THE STOPPABLE PRIMITIVE (map 1's 5-fix music saga): a streamed track is
// only stoppable as PlayLoopSound of a LOOPING alias on a script_origin;
// stop = StopLoopSound(0) + StopSound(alias) + StopSounds() + a Delete
// DEFERRED one frame. NONLOOPING streamed one-shots are engine-unstoppable.
// ---------------------------------------------------------------------------

function ambient_music()
{
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );
	level.tod_panzer_music_count = 0;
	level.tod_music_floor = 0;          // party high-water mark, latched (see below)
	register_music_bands();
	level thread music_end_watch();
	channel_play( band_alias() );
	level thread music_band_watch();
}

// ---------------------------------------------------------------------------
// MUSIC BANDS (v9.46, user 2026-08-23: "at each 10 level there is a breather
// station. On each of these levels we will change the background track").
//
// THE TABLE IS THE WHOLE FEATURE. Each row is (first floor, alias); the base
// track covers everything below the lowest row. band_alias() picks the HIGHEST
// row whose floor the party has reached, so a band with no track yet simply
// has no row and the previous one keeps playing — never silence, never an
// alias that does not exist. Adding the missing breather tracks later is one
// line here + one alias row in sound/aliases/tod_ui.csv + one wav.
//
// ROWS ARE ORDERED LOW -> HIGH and band_alias() scans BACKWARDS. Keep them
// sorted; an out-of-order row would shadow the ones above it.
function register_music_bands()
{
	level.tod_music_bands = [];
	// EVENLY DISTRIBUTED ACROSS 10-50 (user 2026-08-25: "Those 3 songs from 10-50.
	// Distribute evenly through the 40 rounds"). Was 20/30/40, briefly 10/30/40.
	//
	// 41 floors (10..50) over 3 tracks = 13.67 each, so the split cannot be exact:
	//   city    10-22   13 floors
	//   relay   23-36   14 floors
	//   eclipse 37-50   14 floors
	// The SHORT band is deliberately first, so the opening change still lands on
	// the floor-10 breather; putting it last would have made the final stretch of
	// the climb the one that felt clipped.
	//
	// NOTE THIS DECOUPLES THE MUSIC FROM THE BREATHERS. Only floor 10 is still a
	// rest stop; 23 and 37 land mid-climb, so the track now changes while the
	// party is moving. That is the cost of an even split and it is intentional —
	// the breather-aligned alternative is 10/20/30, which leaves eclipse carrying
	// 21 floors.
	add_music_band( 10, "tod_music_city" );    // "cyberpunk futuristic city" (lnplusmusic)
	add_music_band( 23, "tod_music_relay" );   // "cyber relay" (Psychronic)
	add_music_band( 37, "tod_music_eclipse" ); // "cyber eclipse" (bykenneth)
	// Adding another band is one line here + an alias row + a wav, nothing else.
	// Keep the rows in ASCENDING floor order: band_alias() walks the array
	// backwards and returns the first row at or below the current floor.
}

function add_music_band( first_floor, alias )
{
	b = SpawnStruct();
	b.floor = first_floor;
	b.alias = alias;
	level.tod_music_bands[ level.tod_music_bands.size ] = b;
}

// -> the alias the CURRENT band wants. Base track when below every row.
function band_alias()
{
	if ( !isdefined( level.tod_music_bands ) )
		return "tod_ambient_music";
	f = ( ( isdefined( level.tod_music_floor ) ) ? level.tod_music_floor : 0 );
	for ( i = level.tod_music_bands.size - 1; i >= 0; i-- )
	{
		if ( f >= level.tod_music_bands[ i ].floor )
			return level.tod_music_bands[ i ].alias;
	}
	return "tod_ambient_music";
}

// Real floor 1..LAPS for a world z (the gauge's cell math deliberately not
// reused — see the TOD_MUSIC_LAP_RISE note).
function music_floor_of( z )
{
	if ( z < 0 )
		return 0;
	return 1 + int( z / TOD_MUSIC_LAP_RISE );
}

// The band watcher. Reads the HIGHEST floor any live player stands on and
// LATCHES it — walking back down the stairs never rewinds the music. That is
// deliberate: the bands are progression, not a location, and an un-latched
// version would re-cue the stream every time someone crossed a threshold at a
// breather (a stream cannot seek, so every re-cue restarts the track from 0).
//
// BOSS ALWAYS WINS (user: "boss music will always override this"). While a
// Panzer holds the channel, or the finale has latched it, the band still
// UPDATES but never swaps the stream — boss_track_end() then resumes into
// whatever band we have climbed into by the time he dies.
function music_band_watch()
{
	level endon( "end_game" );
	for ( ;; )
	{
		wait TOD_MUSIC_POLL_SECS;

		high = level.tod_music_floor;
		players = GetPlayers();
		foreach ( p in players )
		{
			if ( !isdefined( p ) || !isplayer( p ) )
				continue;
			// No laststand check on purpose: the mark is LATCHED, and a player
			// who went down on floor 31 did reach floor 31. Filtering them would
			// only matter if the mark could fall, which it cannot.
			f = music_floor_of( p.origin[ 2 ] );
			if ( f > high )
				high = f;
		}
		if ( high == level.tod_music_floor )
			continue;

		was = band_alias();
		level.tod_music_floor = high;
		now = band_alias();
		if ( now == was )
			continue;                   // climbed, but inside the same band

		// Boss / finale owns the channel: keep the latch, leave the stream.
		if ( level.tod_panzer_music_count > 0 || IS_TRUE( level.tod_finale_music ) || IS_TRUE( level.tod_music_ee ) )
			continue;   // (v18.96: the teddy-bear song too — ee_song_run resumes into band_alias() when it ends)
		channel_play( now );
	}
}

// GAME OVER STOP (v9.26, session 2a's ship-state audit 2026-08-23):
// channel_stop was only ever reached THROUGH channel_play, so the looping
// emitter outlived end_game and kept playing under stock's game-over sting —
// and under the v9.24 Restart Map / End Game menu. Stop the channel the moment
// the game ends, win or wipe. Nothing can restart it afterwards: every caller
// of channel_play (the Panzer refcount in _tod_bosses, the finale latch) runs
// under a level endon("end_game"). Own thread on purpose — ambient_music's
// endon would kill this watcher with it.
function music_end_watch()
{
	level waittill( "end_game" );
	channel_stop();
}

// PUBLIC — _tod_bosses calls on each Panzer spawn. First ref: ambient out,
// boss track in. (If the FINALE already owns the channel the track is already
// playing — never restart the stream under it.)
// -> true when something OUTRANKS the Panzer track and owns the channel, so
// neither boss_track_start nor boss_track_end may touch the stream.
//
// ONE PREDICATE, BOTH ENDS. Written as a function rather than repeated inline
// because the start and the end must agree exactly: if the boss track was never
// allowed to take the channel, the last death must not "restore" anything
// either — that restore would be an audible restart of a stream that never
// stopped. The refcount still runs on both paths regardless, so the bookkeeping
// stays correct whichever mode the party is in.
//
//   FINALE  — the uplink latch (v9): once bought, the boss track plays to the
//             end screen, Panzer or not.
//   SPIRE   — v14.46, user 2026-08-31: "No boss music at the spire. Lets keep
//             the music that the spire specifically has." The spire's door
//             honour guard spawns up to 4 Panzers PER DOOR across ~100 doors,
//             so the Panzer override would not be an override up there — it
//             would be the permanent soundtrack, and the spire's own track
//             would essentially never be heard.
function boss_music_blocked()
{
	// v18.96: and the teddy-bear song — it holds the channel for its length
	// and hands it back itself (ee_song_run resumes into the boss track if a
	// Panzer is still up, else the band).
	return ( IS_TRUE( level.tod_finale_music ) || IS_TRUE( level.tod_spire_active ) || IS_TRUE( level.tod_music_ee ) );
}

function boss_track_start()
{
	if ( !isdefined( level.tod_panzer_music_count ) )
		level.tod_panzer_music_count = 0;
	level.tod_panzer_music_count++;
	if ( level.tod_panzer_music_count == 1 && !boss_music_blocked() )
		channel_play( "tod_boss_music" );
}

// PUBLIC — _tod_bosses calls when a Panzer dies. Last ref: boss track out,
// ambient back in — unless the FINALE has latched the channel (v9): once the
// uplink is bought the boss track plays to the end screen, Panzer or not.
function boss_track_end()
{
	if ( !isdefined( level.tod_panzer_music_count ) )
		level.tod_panzer_music_count = 0;
	level.tod_panzer_music_count--;
	if ( level.tod_panzer_music_count <= 0 )
	{
		level.tod_panzer_music_count = 0;
		// v9.46: resume into the CURRENT BAND, not the base track — the party
		// may have climbed a breather (or three) while he was alive.
		// Same predicate as the start (v14.46) — see boss_music_blocked().
		if ( !boss_music_blocked() )
			channel_play( band_alias() );
	}
}

// PUBLIC (v9) — _tod_finale calls when the uplink is bought. The boss track
// takes the channel and KEEPS it: the Panzer refcount above can no longer
// swap it back to ambient. If a Panzer already has it playing, leave the
// stream alone (a restart would be an audible hiccup for nothing).
function finale_track_start()
{
	level.tod_finale_music = true;
	// v10: its OWN track, not the boss track. The song is the finale's clock —
	// _tod_finale::TOD_FINALE_SONG_SECS is its measured length — so it has to be
	// this exact stream, started HERE, at second zero. The latch above then
	// keeps it: boss_track_start/end and the band watcher both check
	// tod_finale_music and leave the channel alone for the rest of the game.
	if ( !isdefined( level.tod_music_cur ) || level.tod_music_cur != "tod_music_finale" )
		channel_play( "tod_music_finale" );
}

// PUBLIC (v18.96) — THE TEDDY BEAR SONG (_tod_secret: shoot all three bears).
// USER RULE: "make sure it cant be overridden by boss music. No music can
// overtake this EE song." So it OUTRANKS EVERYTHING — the Panzer track, the
// finale, the spire, the trials, the King. The gate is in channel_play itself:
// while the song holds, any other request is PARKED (the newest wins) and
// replayed the moment the song ends; nothing else in this file needs to know.
// Once per match (the secret is once per match). -> true if the song started.
//
// The one cost, stated: the FINALE's song is the run's clock (started at the
// extraction buy). If the third bear is shot inside the finale, the finale
// track starts late by whatever is left of this song. The bears are at the
// base and floors 10/20, so that is a deliberate act, not an accident.
// lead_secs (v18.96c, optional): extra silence BEFORE the gap — the third
// bear's rise-and-flight plays under it, then TOD_MUSIC_EE_GAP of true quiet.
function ee_song_start( lead_secs )
{
	if ( IS_TRUE( level.tod_music_ee ) || IS_TRUE( level.tod_music_ee_played ) )
		return false;
	level.tod_music_ee_lead = 0;
	if ( isdefined( lead_secs ) && lead_secs > 0 )
		level.tod_music_ee_lead = lead_secs;
	level.tod_music_ee = true;
	level.tod_music_ee_played = true;
	level.tod_music_ee_pending = undefined;
	// THE GAP: silence first (the latch above already holds the channel, so
	// nothing can slip in during it), then the song.
	channel_stop();
	level thread ee_song_run();
	return true;
}

function ee_song_run()
{
	level endon( "end_game" );
	if ( isdefined( level.tod_music_ee_lead ) && level.tod_music_ee_lead > 0 )
		wait level.tod_music_ee_lead;
	wait TOD_MUSIC_EE_GAP;
	channel_play( "tod_music_ee" );
	wait TOD_MUSIC_EE_SECS;
	level.tod_music_ee = false;
	// Whoever asked last while the song held gets the channel back; nobody
	// asked = the state the channel would be in anyway.
	next = level.tod_music_ee_pending;
	level.tod_music_ee_pending = undefined;
	if ( !isdefined( next ) )
	{
		if ( IS_TRUE( level.tod_finale_music ) )
			next = "tod_music_finale";
		else if ( isdefined( level.tod_panzer_music_count ) && level.tod_panzer_music_count > 0 && !boss_music_blocked() )
			next = "tod_boss_music";
		else
			next = band_alias();
	}
	// THE FINALE'S CLOCK HAS ALREADY RUN OUT (bug review 2026-09-22, F13): the
	// closing song is wall-time (_tod_finale sets tod_finale_song_end at the
	// buy) and the choice phase stops the channel on purpose. Replaying the
	// parked finale track from zero over that silence was the one part of the
	// bear-song rule nobody accepted; the rule itself (nothing overtakes the
	// song while it holds) is unchanged.
	if ( next == "tod_music_finale" && isdefined( level.tod_finale_song_end ) && GetTime() >= level.tod_finale_song_end )
		return;
	channel_play( next );
}

// Hard-swap the channel to `alias` (stop-then-play — never two streams).
// v18.96: WHILE THE TEDDY BEAR SONG HOLDS, NOTHING ELSE PLAYS — the request
// is parked and replayed when the song ends (ee_song_run). See ee_song_start.
// Emitter sits in OPEN AIR at the spawn area — (0,0,0) is INSIDE the solid
// core brush (the aliases are 2d so it should not matter, but a possibly
// occluded emitter was one suspect in the silent-music live test).
function channel_play( alias )
{
	if ( IS_TRUE( level.tod_music_ee ) && isdefined( alias ) && alias != "tod_music_ee" )
	{
		level.tod_music_ee_pending = alias;   // v18.96: parked until the teddy-bear song ends (user: no music can overtake it)
		return;
	}
	channel_stop();
	e = Spawn( "script_origin", ( 0, -490, 100 ) );
	level.tod_music_ent = e;
	level.tod_music_cur = alias;
	e PlayLoopSound( alias );
}

function channel_stop()
{
	if ( !isdefined( level.tod_music_ent ) )
		return;
	e = level.tod_music_ent;
	alias = level.tod_music_cur;
	level.tod_music_ent = undefined;
	level.tod_music_cur = undefined;
	e StopLoopSound( 0 );
	if ( isdefined( alias ) )
		e StopSound( alias );
	e StopSounds();
	level thread music_ent_delete( e );
}

function music_ent_delete( e )
{
	wait 0.05;
	if ( isdefined( e ) )
		e Delete();
}

// v14.42 — THE TOWER GETS NO FOG. STANDING RULE (user 2026-08-31, twice:
// "All of this is only for the spire correct... I dont want any changes on the
// regular play through tower" and "No all these changes only apply to endless
// spire. Ive been sayong that the whole time").
//
// This is why the tower is EXPLICITLY DISABLED rather than simply left alone:
// v14.41 fixed `fsi` to zm_factory_volumetric so the fog system finally works,
// and that asset is a WORLDSPAWN key — it is map-wide and the SPIRE needs it.
// With fog capable map-wide, doing nothing here would have handed the tower a
// visual change it must not get. So the tower actively pushes fog beyond the
// world, and the SPIRE is the only thing that ever brings it back.
//
// The push is map 1's proven kill (there is no fog-off builtin): start the fog
// a hundred million units away. Precedent: _acc_atmosphere.gsc:419-422, and
// stock does the same with setExpFog in _art.gsc.
//
// The authored smog constants (TOD_FOG_R/G/B, HALFWAY_*) are KEPT, not deleted:
// they are the map's designed cyber-city haze and the only thing standing
// between them and the screen is one call. If the tower is ever wanted foggy,
// restore the two set_fog lines this function used to make — they are in git
// history at v14.41 — and change nothing else.
// =============================================================================
// THE SINGLE FOG AUTHORITY — ported from map 1's proven implementation
// (_acc_atmosphere.gsc:262-300), because this map's two-shot version did not
// work and map 1's has worked for months.
//
// WHY A LOOP AND NOT TWO CALLS. This function used to call SetVolFog at the
// blackscreen and again 5s later, then exit — and the user's live test found NO
// FOG AT ALL. Map 1 hit the same wall and its own comments name the cause: a
// one-shot SetVolFog does not stick ("a frame-0 SetVolFog was the original 'no
// haze' bug"), so it runs a permanent 0.1s loop it calls "the SINGLE fog
// authority ... so nothing fights it". Stock art paths, fog volumes and the
// client-side visionset monitor all touch fog during and after the fade; the
// only reliable answer is to keep asserting.
//
// TWO THEORIES THIS REPLACES, BOTH MINE AND BOTH WRONG — recorded so nobody
// re-runs them:
//   1. "The 8-arg 8th slot is transition time, not opacity." The API doc does
//      say that, but MAP 1 PASSES OPACITY THERE AND ITS FOG RENDERS. Whatever
//      the doc means, the working reference wins.
//   2. "fsi `default` ships fogopacity 0, so fog is clamped off at asset
//      level." Map 1 uses `fsi "default"`. So does stock zm_giant. Reverted.
// Both were plausible, both were derived from documentation and asset files
// rather than from the working map sitting on the same disk. THE REFERENCE
// IMPLEMENTATION OUTRANKS THE DOCUMENTATION — check it first.
//
// SPIRE-ONLY, per the standing instruction: the tower's asserted state is fog
// OFF, so regular play is visually identical to every build before this. The
// spire is the only state that turns fog on.
function apply_fog()
{
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );

	// Change-gated (map 1's own refinement at _acc_atmosphere.gsc:454): only
	// call SetVolFog when the wanted state actually differs, because
	// re-asserting identical params every tick buried a real fatal under tens
	// of thousands of console lines on that map. The spire's lerp writes
	// through the same recorder, so this loop sees its values and stays quiet
	// while it runs.
	// NO CHANGE-GATE HERE — but NOT for the reason an earlier version of this
	// comment claimed. It asserted "map 1 re-asserts every tick and that IS the
	// mechanism". THAT IS FALSE, and an audit against the working map caught it:
	// map 1 funnels every write through acc_set_vol_fog()
	// (_acc_atmosphere.gsc:454-470), which builds a key from all 8 args and
	// RETURNS EARLY on a match — so map 1 calls SetVolFog exactly once per
	// parameter CHANGE, and its fog renders fine. Its 0.1s loop exists to notice
	// changes (dvar retunes, the power-on settle), not to re-issue identical
	// values. So a gate is not what broke us.
	//
	// We run ungated anyway, deliberately: it is strictly more robust (it also
	// recovers from any external stomp, which a gate cannot), and at these
	// values it costs one builtin call per 0.1s. The v14.42 gate is still worth
	// naming as a bug — it gated on a value set_fog itself had just written, so
	// it could only ever fire once, which is a broken gate rather than a wrong
	// design. 0.1s matches map 1's cadence.
	said = false;
	for ( ;; )
	{
		if ( IS_TRUE( level.tod_spire_active ) )
		{
			// SPIRE = FOG ON, one fixed state, re-asserted forever.
			set_fog( TOD_SPIRE_FOG_STARTDIST, TOD_SPIRE_FOG_HALFDIST, TOD_SPIRE_FOG_HALFHEIGHT,
				TOD_FOG_BASE_HEIGHT, TOD_SPIRE_FOG_R, TOD_SPIRE_FOG_G, TOD_SPIRE_FOG_B,
				TOD_SPIRE_FOG_OPACITY );

			// DEV INSTRUMENT (v14.43). Three builds have now shipped a fog fix
			// that produced no fog, so this reports FACTS instead of another
			// theory: if this line appears, the loop is running and SetVolFog
			// is being called with these exact numbers — which would mean the
			// call itself is not the problem and the next suspect is the
			// engine/asset side. If it does NOT appear, the loop never reached
			// the spire branch and the bug is upstream in tod_spire_active.
			// Prints ONCE on entering the spire, not every tick.
			if ( !said && IS_TRUE( level.tod_dev ) )
			{
				said = true;
				tod_quiet_print( "^3fog: SPIRE assert start=" + TOD_SPIRE_FOG_STARTDIST
					+ " half=" + TOD_SPIRE_FOG_HALFDIST + " op=" + TOD_SPIRE_FOG_OPACITY );
			}
		}
		else
		{
			// TOWER = NO FOG, also re-asserted, so nothing can leak fog into
			// regular play either.
			fog_off();
		}

		wait 0.1;
	}
}

// Fog pushed past the world = fog off (map 1's proven kill at
// _acc_atmosphere.gsc:419-422 — there is no fog-off builtin, so you start the
// fog beyond the world). Shared by the tower's default state and the spire's
// emergency revert.
// v19.40 THE BLACK SCREEN AT THE CLASS DRAFT (Workshop: "everything goes black
// ... other than shadows ... when someone else is hosting it works fine", Aug 31;
// "as soon as the weapon classes pop up it goes black", Sep 16; Sep 23). These
// numbers came from stock _art.gsc:231 `setExpFog( 100000000, 100000001, 0, 0,
// 0, 0 )` via map 1's disable_fog - but setExpFog has NO height arguments (the
// zeros there are r, g, b, transition), and copied into the 8-arg SetVolFog the
// 3rd zero became the HALFWAY HEIGHT. A zero height falloff divides by zero in
// the fog maths; most GPUs shrug it off, some turn the frame black. The tower
// wrote it for the whole match from initial_blackscreen_passed - the same
// frame the class draft opens. Map 1 only ever hit it in a rarely-used branch.
// The height is now TOD_FOG_OFF_HALFHEIGHT (= the spire fog's own, proven in
// game); the start stays 100,000,000 units out, so no fog reaches anything.
// v19.63 THE SECOND DIVIDE-BY-ZERO (Workshop, Sep 23 + a converted PS4 report
// Sep 29, both AFTER the v19.40 height fix shipped): 100,000,000 and
// 100,000,001 are THE SAME float32 (its spacing at 1e8 is 8), so the fog's
// distance term (d - start) / (halfway - start) divided by zero on every GPU
// that does not clamp it - the same failure shape as the height, one slot
// over. Stock's setExpFog survives the pair because exp fog never forms that
// quotient. The halfway point is now 200,000,000: the density ramp begins
// 100,000,000 units past the tallest geometry (the world is under 50,000), so
// nothing in the world is ever fogged and the maths stays finite.
#define TOD_FOG_OFF_START      100000000
#define TOD_FOG_OFF_HALFDIST   200000000
#define TOD_FOG_OFF_HALFHEIGHT 1000000
function fog_off()
{
	set_fog( TOD_FOG_OFF_START, TOD_FOG_OFF_HALFDIST, TOD_FOG_OFF_HALFHEIGHT, 0, 0, 0, 0, 0 );
}

// PUBLIC — THE WEATHER TURN (v12.13, docs/41 Tier-A rider). The extraction buy
// turns the sky: over 15 seconds the cold purple-blue smog warms toward EMBER
// and its altitude falloff rises toward the crown, so the void under the
// causeway fills with a dim red sea for the whole run. Owned by THIS file
// because fog is (apply_fog above proves mid-game re-assert works; the
// visionset traps on the memory record are why this is fog, not a visionset).
// Deliberately modest: opacity and start distance UNCHANGED, halfway-height
// capped 5,000 under the crown deck — docs/34's legibility doctrine outranks
// the weather, so the crown must still read through it. No revert path needed:
// the game ends while the ember sky is still the right sky.
// v14.42 — DISABLED, and deliberately NOT deleted. The ember turn is a TOWER
// change: it repaints the sky over the causeway and the crown, which is regular
// play. It has never actually rendered (fog was clamped off at asset level for
// the map's whole life), so switching it on now would introduce a brand-new
// look to the ending under a standing "spire-only" instruction. Enabling it is
// one uncommented line, whenever the tower is allowed to change.
function finale_weather_turn()
{
	// level thread finale_weather_lerp();
}

function finale_weather_lerp()
{
	level endon( "end_game" );
	// THE SPIRE OVERRIDES THIS. If the party ascends mid-turn the ember lerp
	// must not keep writing fog underneath the spire's own sky (last writer
	// wins on a global SetVolFog, and this loop ticks for 15s).
	level endon( "tod_ascend" );
	steps = 15;
	for ( i = 1; i <= steps; i++ )
	{
		f = i / 15.0;
		r  = TOD_FOG_R + ( 0.52 - TOD_FOG_R ) * f;
		g  = TOD_FOG_G + ( 0.15 - TOD_FOG_G ) * f;
		b  = TOD_FOG_B + ( 0.10 - TOD_FOG_B ) * f;
		hh = TOD_FOG_HALFWAY_HEIGHT + ( 14300 - TOD_FOG_HALFWAY_HEIGHT ) * f;
		set_fog( TOD_FOG_START_DIST, TOD_FOG_HALFWAY_DIST, hh,
			TOD_FOG_BASE_HEIGHT, r, g, b, TOD_FOG_OPACITY );
		wait 1;
	}
}

// =============================================================================
// THE SPIRE SKY (v14.37, user 2026-08-30: "can we dynamically change the
// skybox wants the team enters the endless spire? That would be sick").
//
// WHAT IS AND IS NOT POSSIBLE, so nobody re-researches this: the SKYBOX ITSELF
// CANNOT CHANGE. `skyboxmodel` (skybox_t9_mp_miami) and `ssi`
// (acc_ssi_miami_night) are WORLDSPAWN KEYS baked into the .d3dbsp at compile;
// there is one worldspawn per map and T7 exposes no runtime setter for either
// (searched the stock tree — no SetSkyMaterial/SetSkyboxModel exists).
//
// WHAT WE DO INSTEAD — and it is the stronger effect anyway: SWALLOW the sky.
// The spire stands in the void at x=+10240 and climbs 38,592 units, so what
// reads as "sky" up there is almost entirely VOLUMETRIC FOG, which is fully
// runtime-controllable and already proven mid-game by apply_fog and the
// finale's ember turn above. Taking the fog to a dense blood-red and RAISING
// the altitude falloff past the summit means the Miami skyline is never
// visible from the spire at all: you have climbed out of that city and into
// somewhere else. That is a bigger change than a second skybox model would be.
//
// A VISIONSET WAS CONSIDERED AND REJECTED, for a recorded reason: the engine
// force-restores the MAP-NAME vision (vision/zm_tower_of_doom.vision, which
// ships deliberately neutral) on every revive, so a scripted grade would be
// stomped the first time anyone is revived on the spire — and an unregistered
// visionset name kills the calling thread mid-function. Fog has neither trap.
// (memories: mapname-vision-must-exist, visionset-unregistered-strands-state)
// =============================================================================

// ⚠️ THE 8-ARG FORM HAS NO OPACITY ARGUMENT. VERIFIED 2026-08-30 against three
// independent sources, and it invalidates a belief both this map and map 1
// were built on:
//   1. <modtools>/docs_modtools/bo3_scriptapifunctions.htm documents TWO
//      overloads. The 8-arg one ends `<red>,<green>,<blue>,<TRANSITION TIME>`.
//      `<fog max opacity>` exists ONLY in the 18-arg form (as arg 17).
//   2. Stock's only call site, load_shared.gsc:807, passes 0.4 as arg 8 — a
//      0.4-SECOND BLEND for a fog-volume trigger, not an opacity.
//   3. <modtools>/source_data/fog.gdt "default" ships "fogopacity" "0", and our
//      worldspawn declares `"fsi" "default"` — so the baseline max opacity this
//      map boots with is ZERO and no 8-arg call can raise it.
// So TOD_FOG_OPACITY 0.55 has always been a 0.55-second transition, and map 1's
// blood-paid "zeroing opacity does NOT clear it" was right about the symptom
// and wrong about the mechanism — it was setting a 0-second fade.
// CONSEQUENCE, UNPROVEN AND WORTH ONE LIVE LOOK: this map may never have
// rendered volumetric fog at all. The v12.4 discriminator in CHANGELOG was
// never answered, and the "20-25% fog wash" figure came from the OFFLINE
// preview tool, not from the game.
// THE SPIRE THEREFORE USES THE 18-ARG FORM (spire_set_fog below) — the only
// way to actually set opacity. The tower's 8-arg calls are left EXACTLY as
// they are: if they have been inert all along, changing them is a separate,
// whole-map decision that deserves its own build and its own live read.


// PUBLIC — called by _tod_spire::ascend_run in the same breath as the music
// swap. Lerps over `secs` so the change reads as arrival, not a hard cut; the
// teleport flash covers the first second of it.
// The spire's fog is owned entirely by apply_fog's authority loop, keyed on
// level.tod_spire_active — so this is a no-op kept only so _tod_spire's call
// site stays valid. NOTHING MOVES: no lerp, no per-floor variation, no
// re-timing (user 2026-08-31: "just put fog on the endless spire and call it a
// day... We dont need to move it"). The loop picks it up within 0.5s of the
// ascension flag.
function spire_weather_turn()
{
}

// THE 18-ARG FORM — the only one with a max-opacity argument. Order, straight
// 8-arg proven form (see set_fog's note). NO opacity parameter, deliberately:
// opacity is not a SetVolFog argument in this overload and now lives in the
// fsi asset, so density here comes from halfd/halfh. An `op` param survived
// one revision as a no-op and was removed rather than left to mislead the next
// reader into thinking this function controls opacity.
function spire_set_fog( halfd, halfh, r, g, b, transition )
{
	SetVolFog( TOD_FOG_START_DIST, halfd, halfh, TOD_FOG_BASE_HEIGHT, r, g, b, transition );
	level.tod_fog_r = r;
	level.tod_fog_g = g;
	level.tod_fog_b = b;
	level.tod_fog_hh = halfh;
	level.tod_fog_hd = halfd;
}

function spire_weather_lerp()
{
	level endon( "end_game" );
	steps = 12;
	// SNAPSHOT THE START, do not assume the tower's constants: the party may
	// ascend from the finale's EMBER sky (that lerp may even have been running
	// when they took the teleporter), so lerping from TOD_FOG_* would jump the
	// colour backwards on the first tick. These are the map's own published
	// current values, maintained by every writer in this file.
	sr = ( ( isdefined( level.tod_fog_r ) ) ? level.tod_fog_r : TOD_FOG_R );
	sg = ( ( isdefined( level.tod_fog_g ) ) ? level.tod_fog_g : TOD_FOG_G );
	sb = ( ( isdefined( level.tod_fog_b ) ) ? level.tod_fog_b : TOD_FOG_B );
	sh = ( ( isdefined( level.tod_fog_hh ) ) ? level.tod_fog_hh : TOD_FOG_HALFWAY_HEIGHT );
	sd = ( ( isdefined( level.tod_fog_hd ) ) ? level.tod_fog_hd : TOD_FOG_HALFWAY_DIST );
	// ⚠️ CLAMP THE START DISTANCE. Since v14.42 the tower runs fog_off(), which
	// parks halfwayDist at 100,000,001 — lerping linearly from that to 1400
	// would leave the fog effectively absent for eleven of twelve steps and
	// then SNAP in on the last one. Starting from the tower's ordinary 2600
	// makes the ascension a real six-second close-in from clear air, which is
	// the effect that was wanted. Any sane inherited value passes through.
	if ( sd > TOD_FOG_HALFWAY_DIST )
		sd = TOD_FOG_HALFWAY_DIST;

	// NO OPACITY TERM IN THIS LERP. Opacity is not a SetVolFog argument in the
	// proven overload — it now comes from the fsi asset — so the void closing
	// in is expressed as DISTANCE: halfwayDist walks the tower's 2600 down to
	// the spire's 1400, which thickens the near field, while halfwayHeight
	// climbs to 42000 so it never thins with altitude.
	for ( i = 1; i <= steps; i++ )
	{
		f = i / 12.0;
		r  = sr + ( TOD_SPIRE_FOG_R - sr ) * f;
		g  = sg + ( TOD_SPIRE_FOG_G - sg ) * f;
		b  = sb + ( TOD_SPIRE_FOG_B - sb ) * f;
		hh = sh + ( TOD_SPIRE_FOG_HALFHEIGHT - sh ) * f;
		hd = sd + ( TOD_SPIRE_FOG_HALFDIST - sd ) * f;
		// 0.6s transition per step on a 0.5s cadence = each step is still
		// blending when the next lands, so the climb-in reads continuous
		// rather than as 12 visible increments.
		spire_set_fog( hd, hh, r, g, b, 0.6 );
		wait 0.5;
	}

	// HOLD THE FINAL STATE with a long transition of its own — a stock art path
	// or a fog-volume trigger re-asserting mid-climb would otherwise snap the
	// spire sky back to the tower's. Cheap insurance; apply_fog's own re-assert
	// is the precedent.
	wait 5;
	spire_set_fog( TOD_SPIRE_FOG_HALFDIST, TOD_SPIRE_FOG_HALFHEIGHT,
		TOD_SPIRE_FOG_R, TOD_SPIRE_FOG_G, TOD_SPIRE_FOG_B, 1.0 );
}

// THE EMERGENCY OFF — map 1's proven kill (there is no fog-off builtin; you
// push the fog beyond the world). Kept as a named function so a live session
// that finds the spire sky unplayable has a one-call revert instead of
// inventing one. Not called anywhere today, deliberately.
function spire_fog_kill()
{
	spire_set_fog( 100000001, TOD_FOG_OFF_HALFHEIGHT, 0, 0, 0, 1.0 );   // v19.40: never a zero halfway height (see fog_off)
}

// ONE WRITER, ONE RECORD. Every fog write in this file should go through here
// so level.tod_fog_* stays the truth about what is currently on screen — that
// is what lets the spire lerp start from the ember sky instead of guessing.
// v14.37 — THE TOWER'S FOG NOW ACTUALLY RENDERS (user confirmed live: "Yes
// this map has never rendered fog"). Every call in this file used the 8-arg
// overload, whose 8th slot is TRANSITION TIME, not opacity — so max opacity
// stayed at the fog.gdt "default" value of 0 and the whole cyber-city smog
// design has been invisible since the map was authored. Routed through the
// 18-arg form, which is the only one carrying <fogMaxOpacity>.
// ARG ORDER IS LOAD-BEARING — see spire_set_fog's block comment for the full
// list; sun fog is pinned to the fog colour so it can introduce no hue we did
// not choose, and fogColorScale is the DARKNESS knob (1 = darkest possible).
// v14.41 — BACK TO THE 8-ARG FORM, ON PURPOSE. v14.37 moved to the 18-arg
// overload to reach <fogMaxOpacity>, having correctly worked out that the
// 8-arg 8th slot is TRANSITION TIME. That diagnosis stands — but the 18-arg
// form is used NOWHERE in the entire mod tools install (checked
// share/raw/scripts: the only SetVolFog anywhere is load_shared.gsc:807, and
// it is 8-arg), so shipping it would have been an unverified signature on the
// one feature the user explicitly said must not come back broken.
// It is also unnecessary now: the real reason fog never drew was `fsi
// "default"` carrying fogopacity 0 (see gen_tower_map.js). With the fsi fixed,
// the PROVEN call is enough — and `op` becomes the TRANSITION TIME it always
// literally was, passed honestly instead of by accident.
// DENSITY IS NOW CONTROLLED BY halfwayDist / halfwayHeight, which are real
// arguments of the proven call: shorter halfwayDist = thicker.
function set_fog( startd, halfd, halfh, baseh, r, g, b, transition )
{
	// v17.43 — CHANGE-GATED, map 1's way (_acc_atmosphere.gsc:454-470: one
	// key from all 8 args, return early on a match). The ungated 0.1 s
	// re-assert in apply_fog() was one engine call AND one console error
	// ("setVolFog: Old syntax used") every 100 ms for the whole match — 1,957
	// lines in a five-minute session on 2026-09-04, on a tower that has no
	// fog at all. The v14.42 gate failed because it compared against a value
	// this function had just written; this key is written ONLY after the
	// builtin call, so the first call of every new state always goes through.
	key = startd + "|" + halfd + "|" + halfh + "|" + baseh + "|" + r + "|" + g + "|" + b + "|" + transition;
	if ( isdefined( level.tod_fog_key ) && level.tod_fog_key == key )
		return;
	SetVolFog( startd, halfd, halfh, baseh, r, g, b, transition );
	level.tod_fog_key = key;
	// v19.40 dev log: change-gated above, so a handful of lines per match.
	if ( IS_TRUE( level.tod_dev ) )
	{
		line = "[TOD_FOG] ms=" + GetTime() + " SET start=" + startd + " half=" + halfd + " halfh=" + halfh + " base=" + baseh + " rgb=" + r + "," + g + "," + b + " t=" + transition;
		/#
		PrintLn( line );
		#/
	}
	level.tod_fog_r = r;
	level.tod_fog_g = g;
	level.tod_fog_b = b;
	level.tod_fog_hh = halfh;
	level.tod_fog_hd = halfd;
	// NOTE: there is deliberately no level.tod_fog_op. Opacity is not a
	// SetVolFog argument at all (it lives in the fsi asset), so publishing one
	// would be recording a number this file does not control. The v14.37
	// version of this line read `= op` and survived only because `op` was then
	// a parameter; the v14.41 rename to `transition` turned it into a dangling
	// reference and the linker refused the whole file with "No generated data"
	// — which is the compile-kill this map's dialect note warns about, showing
	// up for a reason other than a misplaced #precache.
}

// ---------------------------------------------------------------------------
// v17.97 — DEV PRINTS ARE MUTABLE. level.tod_dev_quiet (set beside tod_dev in
// zm_tower_of_doom::tod_resolve_dev_flags) silences every bottom-left IPrintLn
// in this file — screenshot sessions want dev + god with a clean HUD. Each
// print site's own tod_dev gate is unchanged; this is one extra gate under it.
// IPrintLnBold (real game toasts) is not routed here.
function tod_quiet_print( msg )
{
	if ( IS_TRUE( level.tod_dev_quiet ) )
		return;
	IPrintLn( msg );
}

function tod_quiet_print_to( msg )   // self = the player to print to
{
	if ( IS_TRUE( level.tod_dev_quiet ) )
		return;
	self IPrintLn( msg );
}
