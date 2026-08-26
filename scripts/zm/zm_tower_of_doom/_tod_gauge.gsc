// =============================================================================
// _tod_gauge.gsc — the TOWER GAUGE feed (the HUD floor indicator).
//
// Publishes two numbers to each player's HUD: the floor THEY are on, and the
// floor the nearest live boss is on (0 = none). The Lua (tod_upgrade.lua)
// draws the gauge from those — dark backing, one lit cell stamped per climbed
// floor, a marker on the player's cell, a red pip on the boss's.
//
// WHY LuiNotifyEvent AND NOT A CLIENTFIELD: the clientuimodel budget is at
// its PROVEN 61-bit ceiling (18 fields, APPEND ONLY — see _tod_upgrade_ui).
// A floor + boss-floor pair would cost ~10 more bits. The int-only
// LuiNotifyEvent lane costs ZERO clientuimodel bits, which is exactly why the
// boss banner and the owned-upgrades sync already ride it.
//
// TRAP (paid for twice on this map): the event string MUST be #precache'd or
// LuiNotifyEvent silently never fires.
//
// Floors: the tower is 25 laps of LAP_RISE 384 starting at z=0, roof at 9600.
//   z < 0            -> 0  (base arena; gauge shows no lit cells)
//   0 <= z < 9600    -> 1..25
//   z >= 9600        -> 26 (roof — the crown lights)
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

// v8 (user 2026-08-21): the tower DOUBLED to 50 floors but the gauge art still
// has 25 cells, so ONE CELL = TWO FLOORS — "you need to open double the doors
// to see progress on the tower bar". floor_of() reports the CELL, not the
// floor: cell = ceil(floor / 2).
#define TOD_GAUGE_LAP_RISE   384
#define TOD_GAUGE_LAPS       50    // real floors
#define TOD_GAUGE_CELLS      25    // cells on the bar art
#define TOD_GAUGE_ROOF_ID    26    // = CELLS + 1
#define TOD_GAUGE_TICK       0.35   // push cadence; only sends on CHANGE

#precache( "eventstring", "tod_floor" );
// [tod 2026-08-21] real MAX HP for the Aetherium HP text (the kit's health
// field is a 0..1 fraction and its Lua multiplied by a hardcoded 100, so
// the map's 150-HP players read "100 HP"). Same zero-bit int lane, sent
// only when a player's maxhealth changes (spawn, jugg, upgrades).
#precache( "eventstring", "tod_maxhp" );

#namespace tod_gauge;

function init()
{
	level thread gauge_loop();
}

function gauge_loop()
{
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );

	for ( ;; )
	{
		wait TOD_GAUGE_TICK;

		boss_f = boss_floor();

		foreach ( p in GetPlayers() )
		{
			if ( !isdefined( p ) || !isplayer( p ) )
				continue;

			// MAX HP feed (change-only; a fresh HUD reads the default until the
			// first push, which lands on this tick's change from undefined)
			if ( isdefined( p.maxhealth ) && p.maxhealth > 0 )
			{
				mh = int( p.maxhealth );
				if ( !isdefined( p.tod_gauge_mh ) || p.tod_gauge_mh != mh )
				{
					p.tod_gauge_mh = mh;
					p LuiNotifyEvent( &"tod_maxhp", 1, mh );
				}
			}

			// THE FINALE OWNS THE BAR once the clock is running: it stops being
			// an altimeter and becomes the run's timer. The boss pip is forced
			// off with it — everyone is sealed in one room by then, so a "which
			// floor is the boss on" marker means nothing and would only muddy a
			// bar that now has exactly one job.
			fc = finale_cell();
			if ( fc >= 0 )
			{
				f = fc;
				boss_f = 0;
			}
			else
			{
				f = floor_of( p.origin[ 2 ] );
			}

			// Send only on change — this loop runs forever, and a per-tick
			// event for every player would be pure config-string churn.
			if ( isdefined( p.tod_gauge_f ) && p.tod_gauge_f == f
			  && isdefined( p.tod_gauge_bf ) && p.tod_gauge_bf == boss_f )
				continue;

			p.tod_gauge_f = f;
			p.tod_gauge_bf = boss_f;
			p LuiNotifyEvent( &"tod_floor", 2, f, boss_f );
		}
	}
}

// THE GAUGE BECOMES THE SONG CLOCK DURING EXTRACTION (user 2026-08-25: "once
// the extraction starts we can reset the tower bar on the right and that will be
// the song timer so players know when the map ends").
//
// WHY THIS BAR AND NOT A NEW ONE: it is already the right shape (25 cells that
// fill), it is already on screen, and it rides LuiNotifyEvent — which costs ZERO
// clientuimodel bits, and the pool is at 58 of its proven 61. A dedicated timer
// widget would have cost bits the map does not have.
//
// IT ALSO RESETS ITSELF FOR FREE. You buy Extraction standing at the crown, so
// the bar is full and the crown light is on; the first finale tick reports cell
// 0 and the whole thing empties. That drop IS the "reset" — no extra signal.
//
// FILLS rather than drains, keeping the bar's one meaning: full = you are done.
// Climbing it filled toward the crown; now it fills toward the last chord.
//
// -> 0..CELLS while the finale clock runs, or -1 when it is not running (in
// which case the caller falls back to altitude).
function finale_cell()
{
	if ( !isdefined( level.tod_finale_song_start ) || !isdefined( level.tod_finale_song_end ) )
		return -1;

	span = level.tod_finale_song_end - level.tod_finale_song_start;
	if ( span <= 0 )
		return -1;

	done = GetTime() - level.tod_finale_song_start;
	if ( done < 0 )
		done = 0;

	c = int( done * TOD_GAUGE_CELLS / span );
	if ( c > TOD_GAUGE_CELLS )
		c = TOD_GAUGE_CELLS;
	return c;
}

// -> the CELL index on the bar (1..25), 0 = base arena, 26 = roof.
function floor_of( z )
{
	if ( z >= TOD_GAUGE_LAPS * TOD_GAUGE_LAP_RISE )
		return TOD_GAUGE_ROOF_ID;
	if ( z < 0 )
		return 0;
	f = 1 + int( z / TOD_GAUGE_LAP_RISE );      // real floor 1..50
	if ( f > TOD_GAUGE_LAPS )
		f = TOD_GAUGE_LAPS;
	if ( f < 1 )
		f = 1;
	c = int( ( f + 1 ) / 2 );                   // 2 floors per cell (ceil)
	if ( c > TOD_GAUGE_CELLS )
		c = TOD_GAUGE_CELLS;
	if ( c < 1 )
		c = 1;
	return c;
}

// The LOWEST live boss (they spawn at the base and climb, so the lowest one is
// the one still coming for you). 0 = no boss alive.
//
// There is no level-side boss array — _tod_bosses marks the entities
// themselves with `.is_boss` (Panzer :599, Rogue Protector :956) and the
// module's own sweeps identify them the same way (:457, :1021). Match that.
function boss_floor()
{
	team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
	ai = GetAITeamArray( team );

	best = 0;
	foreach ( b in ai )
	{
		if ( !isdefined( b ) || !IsAlive( b ) )
			continue;
		if ( !IS_TRUE( b.is_boss ) && !IS_TRUE( b.acc_is_boss ) && !IS_TRUE( b.acc_is_mini_boss ) )
			continue;
		f = floor_of( b.origin[ 2 ] );
		// CLAMP BOTH ENDS (audit 2026-08-25). floor_of() returns 26 (ROOF_ID) for
		// anything at or above the roof, and the Lua only draws the pip for
		// 1..CELLS(25) — so a Panzer on the rooftop arena made the pip VANISH,
		// reading as "no boss" at the exact moment there certainly is one.
		// Pinning it to the top cell puts it where the crown is, which is true.
		if ( f <= 0 )
			f = 1;
		if ( f > TOD_GAUGE_CELLS )
			f = TOD_GAUGE_CELLS;
		if ( best == 0 || f < best )
			best = f;
	}
	return best;
}
