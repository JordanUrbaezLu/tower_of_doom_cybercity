// =============================================================================
// _tod_atmosphere.gsc — the tower's air: a cold neon city smog.
//
// SetVolFog( startDist, halfwayDist, halfwayHeight, baseHeight, r,g,b,
// maxOpacity ) — the stock 8-arg volumetric fog builtin (VERIFIED map 1,
// load_shared.gsc:807; RGB/opacity are 0..1 floats; bare global call).
// Pure script -> ships with a linker-only build, can never regress the bake.
//
// DESIGN: the haze is densest at street level (baseHeight 0) and halves every
// TOD_FOG_HALFWAY_HEIGHT units of altitude — so the base arena sits in thick
// purple-blue smog, the low laps fade the city below into glow, and by the
// mid-tower you have CLIMBED OUT of it into clear night air under the Miami
// skyline dome. Height-as-progress, told through the air.
// Color must stay LIGHTER than scene-black or it reads as nothing (map 1
// lesson: near-black fog = invisible).
// =============================================================================

#using scripts\shared\flag_shared;

#insert scripts\shared\shared.gsh;

#define TOD_FOG_START_DIST      300    // units from camera where haze begins
#define TOD_FOG_HALFWAY_DIST    2600   // distance to half opacity (open-air scale)
#define TOD_FOG_HALFWAY_HEIGHT  1200   // altitude falloff — thick low, clear by mid-tower
#define TOD_FOG_BASE_HEIGHT     0      // densest at street level
#define TOD_FOG_R               0.16   // cold purple-blue neon smog
#define TOD_FOG_G               0.14
#define TOD_FOG_B               0.30
#define TOD_FOG_OPACITY         0.55

// ---- MUSIC BANDS (v9.46, user 2026-08-23) --------------------------------
// LAP_RISE mirrored from tools/gen_tower_map.js (and from _tod_gauge's own
// copy of it). Duplicated rather than imported: _tod_gauge::floor_of returns a
// gauge CELL (2 floors per cell, 1..26), not a floor, so there is nothing there
// to reuse — and a #using into the gauge would couple the music channel to the
// HUD for one integer.
#define TOD_MUSIC_LAP_RISE      384
#define TOD_MUSIC_POLL_SECS     2      // how often the band watcher re-reads the party's high point

#namespace tod_atmosphere;

function init()
{
	level thread apply_fog();
	level thread ambient_music();
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
		if ( level.tod_panzer_music_count > 0 || IS_TRUE( level.tod_finale_music ) )
			continue;
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
function boss_track_start()
{
	if ( !isdefined( level.tod_panzer_music_count ) )
		level.tod_panzer_music_count = 0;
	level.tod_panzer_music_count++;
	if ( level.tod_panzer_music_count == 1 && !IS_TRUE( level.tod_finale_music ) )
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
		if ( !IS_TRUE( level.tod_finale_music ) )
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

// Hard-swap the channel to `alias` (stop-then-play — never two streams).
// Emitter sits in OPEN AIR at the spawn area — (0,0,0) is INSIDE the solid
// core brush (the aliases are 2d so it should not matter, but a possibly
// occluded emitter was one suspect in the silent-music live test).
function channel_play( alias )
{
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

function apply_fog()
{
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );

	SetVolFog( TOD_FOG_START_DIST, TOD_FOG_HALFWAY_DIST, TOD_FOG_HALFWAY_HEIGHT,
		TOD_FOG_BASE_HEIGHT, TOD_FOG_R, TOD_FOG_G, TOD_FOG_B, TOD_FOG_OPACITY );

	// Re-assert once — some stock art paths stomp fog during the first seconds.
	wait 5;
	SetVolFog( TOD_FOG_START_DIST, TOD_FOG_HALFWAY_DIST, TOD_FOG_HALFWAY_HEIGHT,
		TOD_FOG_BASE_HEIGHT, TOD_FOG_R, TOD_FOG_G, TOD_FOG_B, TOD_FOG_OPACITY );
}
