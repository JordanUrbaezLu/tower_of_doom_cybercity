// =============================================================================
// _tod_corpse_cleanup.gsc — delete zombie bodies so they never eat the actor cap
//
// WHY THIS EXISTS (user 2026-08-25: "can we go to 45 for the whole game not just
// boss. I think we need to be carefull and make sure bodies get clean up
// quickly. Maybe couple seconds after dying.")
//
// THE CAP IS TWO NUMBERS, NOT ONE, and they count different things:
//   level.zombie_ai_limit     stock 24 -> TOD_AI_LIMIT 45
//       gates get_current_zombie_count() = GetAITeamArray(zombie_team) MINUS
//       anything carrying ignore_enemy_count. Every boss in this map sets that,
//       so this number is LIVE ZOMBIES ONLY — bosses are invisible to it.
//   level.zombie_actor_limit  stock 31 -> TOD_ACTOR_LIMIT 60
//       gates get_current_actor_count() = GetAiSpeciesArray(zombie_team,"all")
//       PLUS GetCorpseArray() (zombie_utility.gsc:2264-2276). That one counts
//       EVERYTHING: zombies, bosses, and every body still lying on the floor.
// Neither is an engine limit — both are `if (!isdefined(...))` defaults in
// _zm.gsc:337-343. The real ceiling is 64, netcode-imposed.
//
// SO THE BODIES ARE THE PROBLEM. Raise the live cap to 45 without touching
// corpses and the actor count is 45 zombies + up to a dozen elites + every body
// killed in the last few seconds — straight through 60 and into stock's spawn
// stall. A merely Ghost()'d corpse is invisible but STILL COUNTS. Only Delete()
// takes it out of the array.
//
// THIS IS NOT A MEMORY LEAK, AND THE DISTINCTION MATTERS (user: "This is where
// possible memory leak can break the game"). A corpse is a normal server entity
// on stock's own timer — the engine recycles it, and stock's spawn gate calls
// clear_all_corpses() the moment the actor count is hit (_zm.gsc:3740-3744), so
// bodies can never accumulate without bound even with this file deleted. What
// they CAN do is sit in the count long enough to throttle spawning, which reads
// in game as the horde going thin. Deleting them early strictly REDUCES entity
// pressure; it never adds any.
// The one genuine unbounded-growth risk in this design would be the per-corpse
// thread itself, so it is a straight line with one wait and no loop, it holds no
// reference after Delete(), and it cannot outlive the entity (see below).
//
// PORTED from map 1's _acc_corpse_cleanup.gsc, which ships this to run
// ACC_AI_LIMIT 50 / ACC_ACTOR_LIMIT 56. Two deliberate changes:
//   * LINGER 2s, not 0. Map 1 vanishes bodies on the death frame. The ask here
//     was "a couple seconds after dying", so the body drops, reads as a kill,
//     and then goes.
//   * THE LINGER IS ADAPTIVE. Two seconds of visible body is a luxury, and it is
//     the first thing given up when the board is full — see corpse_remove().
//     Map 1 did not need this because its linger was zero.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#using scripts\shared\ai\zombie_utility;
#using scripts\zm\_zm_spawner;

#insert scripts\shared\shared.gsh;

#namespace tod_corpse_cleanup;

// LIVE ZOMBIES. 45 (user 2026-08-25), against stock 24 and map 1's proven 50.
// Under map 1's own note — "4-player netcode may strain near the ceiling; if it
// rubber-bands, drop toward ~40" — 45 sits between its shipped 50 and that
// floor, which is the cautious read of a number that is already known to work
// one map over.
#define TOD_AI_LIMIT        45

// LIVE ZOMBIES + BOSSES + BODIES. The headroom over TOD_AI_LIMIT is 15, and it
// is sized for the worst realistic board rather than the average one:
//     45 live zombies
//   +  up to ~12 elites (panzer 1 + protectors 8 + reavers 3; the hound
//      director's own combined guard is 9)
//   +  bodies killed inside the linger window
// which can exceed 60 in a quad late round — and that is FINE, because going
// over does not crash: stock's gate calls clear_all_corpses() and waits 0.1s
// (_zm.gsc:3740). The adaptive linger below is what keeps it from getting there
// in the first place. 60 also leaves 4 under the 64 engine ceiling.
#define TOD_ACTOR_LIMIT     60

// How long a body stays visible before it is deleted, when there is room for it.
#define TOD_CORPSE_LINGER   2.0

// THE SAFETY VALVE. When the actor count is within this many of TOD_ACTOR_LIMIT,
// the linger is skipped and the body is deleted on the spot. This is what makes
// the 2s cosmetic rather than structural: at a quiet moment you get bodies on
// the floor, and the instant the board fills they stop existing, so corpses can
// never be the reason a zombie fails to spawn.
#define TOD_CORPSE_PANIC    10

// Let the engine finish its own death processing (notetracks, drops) before the
// entity goes. Stock's giant-cleanup uses the same brief wait before Delete
// (zm_giant_cleanup_mgr.gsc:236-241).
#define TOD_CORPSE_SETTLE   0.05

function init()
{
	// THE CAPS ARE SET HERE, not in the entry script, so the number and the
	// mechanism that makes it safe live in one file. Live values — stock's spawn
	// loop re-reads both every iteration (_zm.gsc:3735/3740), so this does not
	// need to beat any particular init to the punch.
	level.zombie_ai_limit    = TOD_AI_LIMIT;
	level.zombie_actor_limit = TOD_ACTOR_LIMIT;

	zm_spawner::register_zombie_death_event_callback( &on_zombie_death );
}

// self = the killed zombie. One dispatch per death, synchronous with the rest of
// the death chain (points, luck, class-gun kill credit), so this must not block:
// it threads and returns.
function on_zombie_death( attacker )
{
	if ( !isdefined( self ) )
		return;

	// BOSSES OWN THEIR DEATHS. Every boss in this map is stamped is_boss +
	// acc_is_boss + acc_is_mini_boss (_tod_bosses.gsc:1010-1012, :1415-1417),
	// and the vendored packs run their own death sequences — a Panzer spawns a
	// death-anim clone and deletes itself. Deleting the body out from under that
	// is how you lose the animation, or worse. They are also a handful of
	// entities, not forty-five, so they are not what the cap is about.
	if ( IS_TRUE( self.is_boss ) || IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) )
		return;

	self thread corpse_remove();
}

// self = the corpse. A straight line: no loop, one conditional wait, and every
// step re-checks that the entity still exists — the engine can recycle a corpse
// underneath us at any time, and after Delete() nothing here holds a reference.
function corpse_remove()
{
	// DE-COLLIDE ON THE DEATH FRAME, always, whatever the linger. A fresh body
	// that still blocks movement is the thing players actually feel — 45 of them
	// on a 160-wide staircase would be a wall. This is free and immediate.
	self NotSolid();

	// ADAPTIVE: only spend the two seconds if the board can afford them.
	// Re-checked here rather than at death time because the interesting case is
	// a burst of kills — the first few bodies linger, and by the time the count
	// climbs the rest are going straight out.
	if ( zombie_utility::get_current_actor_count() < ( TOD_ACTOR_LIMIT - TOD_CORPSE_PANIC ) )
	{
		wait TOD_CORPSE_LINGER;
		if ( !isdefined( self ) )
			return;   // the engine already recycled it — nothing to do
	}
	else
	{
		// Board is full: hide it now so the delete does not read as a body
		// blinking out of existence in front of the player.
		self Ghost();
	}

	wait TOD_CORPSE_SETTLE;
	if ( isdefined( self ) )
		self Delete();
}
