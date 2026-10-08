// =============================================================================
// _tod_stray.gsc — SILENT RELOCATION of zombies the tower has stranded.
//
// v14.45 — THEY CLIMB OUT OF THE GROUND NOW. User 2026-08-31: "if zombies are
// too far away from you they will spawn at you. Its pretty annoying actually
// cause they just appear. Can we have them have to spawn back in". They do:
// relocate() hands the zombie to _zm_spawner::do_zombie_rise at the destination
// riser, which is stock's own spawn-time climb-out — Ghost, move, face, riser
// FX, "ai_zombie_traverse_ground_climbout_fast" with its notetracks.
//
// THE VIEW-CONE TEST BELOW WAS NEVER THE PROBLEM, and that is worth stating so
// nobody "fixes" it next: destinations were already stock risers and already
// outside every player's cone. But a cone test only covers the instant of the
// move. The player turns around a second later and finds a zombie that was not
// there — the giveaway is the ABSENCE OF AN ARRIVAL, which no amount of
// visibility testing can supply. So the arrival is now supplied.
//
// THE PROBLEM (user 2026-08-30): "when you go all the way down the tower with
// teleporter the zombies try to run down and we have no system to kill them off
// silently and spawn them back down. ... I dont want to kill them off but have
// them spawn near the player if they are too far. It just stalls the game so
// much."
//
// WHY IT STALLS. A lap is LAP_RISE 384 of z bought with 2 flights x STEPS*TREAD
// (512) of tread plus two landings — call it ~1500 units walked per 384 climbed,
// a ~4:1 path-to-rise ratio. A breather teleport drops a player 3,840-15,360 z,
// so the horde chasing him owes 15k-60k units of spiral: two to ten minutes of
// nothing. The round clock does not care (the twist advances on the last SPAWN,
// not the last kill) but the PLAYER does — an empty map is the stall.
//
// WHY NOT THE STOCK SYSTEM. Stock's far-zombie handler is
// zm_giant_cleanup_mgr.gsc (The Giant's teleporters, same problem): a 3s sweep
// that DELETES anything out of an active zone, unseen and far, then credits it
// back with level.zombie_total++ / level.zombie_respawns++
// (zm_giant_cleanup_mgr.gsc:222-225) so round_spawning re-emits it near the
// players at a 0.1s delay (_zm.gsc:3814-3830). Both community precedents do the
// same (map 1 docs/16: zm_room_manager, zm_alien_isolation's elevator).
// WE CANNOT DRIVE IT, for two independent reasons:
//   1. THE TWIST. tod_round_wait (_tod_endless_rounds.gsc:428) returns when
//      level.zombie_total hits 0 — "every zombie of the round has SPAWNED". A
//      cleanup ++ on that field pushes the round clock backwards and makes the
//      round counter stutter. Round accounting is the one thing this map may
//      not touch.
//   2. THE ASK. "I dont want to kill them off." A delete+respawn loses the
//      zombie's health, its sprinter promotion (_tod_sprinter), its Widow's
//      cocoon and every upgrade-domain mark on it.
// So: TELEPORT, which changes no count at all.
//
// SAFETY OF ForceTeleport ON A LIVE ZOMBIE. Map 1's stock-API ledger
// (docs/14:59) records the verified recipe — "Clamp to navmesh first:
// GetClosestPointOnNavMesh then ForceTeleport", precedent shared/ai/zombie.gsc
// :1192-1212. Stock itself ForceTeleports regular zombies on every board tear
// (_zm_behavior.gsc:1493/1519/1560) and this map already does it to bosses
// (_tod_bosses.gsc:600). Nothing else has to be re-asserted: the behaviour
// tree's own find-flesh SERVICE (_zm_behavior.gsc:57 registers
// zombieFindFleshService -> zombieFindFleshCode at :385) re-picks the enemy and
// re-SetGoals on its own cadence, and _tod_zombie_speed's 1.5s keep-alive sweep
// re-asserts gait + anim rate. We still SetGoal at the target so it moves this
// frame rather than next service tick, and we copy stock's own spot.zone_name
// write (_zm_utility.gsc:205-208) so the zombie's zone stamp is not stale.
//
// WHERE THEY GO: level.zm_loc_types["zombie_location"] — the SAME riser pool
// stock spawns from, rebuilt every second by the zone manager from zones that
// are enabled AND active AND spawning_allowed (_zm_zonemgr.gsc:1152-1200).
// Because this map's zone graph is a chain (base -> lap1 -> ... -> lap50 ->
// roof, zm_tower_of_doom.gsc:414-419) "active" means the players' own lap and
// its neighbours. So the pool is, by construction, exactly "risers near a
// player" — no PositionQuery, no temp entities, no zone check.
//
// IT MUST NEVER BE SEEN. The user's other complaint the same session was elites
// "randomly spawn at you". So a relocation only happens when the destination is
// outside every living player's ~80 degree view cone (stock's own test,
// zm_giant_cleanup_mgr.gsc:250-263, cos40 = 0.766) and at least
// TOD_STRAY_DEST_MIN from every player. If nothing qualifies we simply skip and
// retry next sweep — the failure mode is "nothing happens", never a pop.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;

#using scripts\shared\array_shared;               // array::random — spread the destinations
#using scripts\shared\ai\zombie_utility;
// v14.45 — do_zombie_rise: stock's OWN riser climb-out, replayed on a relocated
// zombie so it emerges instead of materialising. It imports no tod module.
#using scripts\zm\_zm_spawner;

#using scripts\zm\zm_tower_of_doom\_tod_crown_data;
#using scripts\zm\zm_tower_of_doom\_tod_zombie_speed;   // gait re-assert after a teleport
#using scripts\zm\zm_tower_of_doom\_tod_spire_data;

#insert scripts\shared\shared.gsh;

#namespace tod_stray;

// ---------------------------------------------------------------------------
// THE POLICY
// ---------------------------------------------------------------------------

// PATH COST, not distance. Vertical separation on this map costs ~4x its own
// length to walk (2 flights x 512 tread + two landings buys LAP_RISE 384), so a
// straight-line check would read a zombie 10 floors up as "3,840 away" when he
// owes 15,000 units of stairs. cost = 2D distance + 4 x |dz|.
#define TOD_STRAY_Z_WEIGHT   4

// TOO FAR. 6000 estimated units is ~60s of walking at zombie sprint, and in
// pure vertical terms it is 1536 z = FOUR LAPS. Chosen against the zone graph:
// the zone manager keeps the player's lap plus its neighbours active, so 1-2
// laps of separation is ORDINARY (a party climbing at sprint is 2 laps ahead of
// its tail for ~30s) and must never trigger. Four laps is the first separation
// that cannot happen by climbing — it means a teleport, a long descent, or a
// co-op split. Horizontally nothing in the tower reaches 6000 (arena half 540,
// crown hall 1536 square), so this is effectively a vertical rule, which is
// what the shape of the map asks for.
#define TOD_STRAY_COST       6000

// HOW LONG IT MUST STAY TOO FAR. Four sweeps. Deliberately NOT the boss
// watcher's "did you make progress" test (_tod_bosses.gsc:588-594): a zombie
// descending 40 floors IS making progress and is exactly the case the user
// wants moved. The cost threshold does that work — anything genuinely closing
// drops under 6000 inside the window and is spared.
#define TOD_STRAY_PATIENCE   8000

// Stock's own grace period for a fresh spawn (zm_giant_cleanup_mgr.gsc:23,
// N_CLEANUP_AGE_MIN). A zombie that just rose has not had a chance to walk.
#define TOD_STRAY_MIN_AGE    5000

// ...and stock's own escape from its "has it entered play yet" guard
// (N_CLEANUP_AGE_TIMEOUT, zm_giant_cleanup_mgr.gsc:24/140-147). Past this age
// the stamp is no longer required. THIS IS THE INERT-SHIP INSURANCE: if
// completed_emerging_into_playable_area ever stopped landing on this map's
// risers, without the timeout every zombie would fail the guard and the whole
// system would ship doing nothing at all.
#define TOD_STRAY_AGE_TIMEOUT 45000

// After a move, leave it alone for this long — one relocation per zombie per
// arrival, never a stutter of them.
#define TOD_STRAY_COOL       6000

// If it has been stray this long and the view cone has never once been clear,
// take the best available spot anyway. Stock has the same escape hatch
// (N_CLEANUP_AGE_TIMEOUT, zm_giant_cleanup_mgr.gsc:24/141-147) — without it a
// player who spins on the spot can wedge the system forever.
#define TOD_STRAY_DESPERATE  12000   // v16.77: 30000 -> 12000, and NOW ACTUALLY WIRED (see stray_sweep) — it was defined and never read, so the hatch it documents did not exist

#define TOD_STRAY_SWEEP      2.0     // seconds between sweeps (stock cleanup: 3.0)
#define TOD_STRAY_RUSH_SWEEP 0.5     // ...while a teleport pump is draining
#define TOD_STRAY_RUSH_MS    12000   // how long a pump keeps the fast cadence (v16.77: 6000 -> 12000 — a 6 s window ended before the horde had drained; see the post-teleport note in stray_sweep)
#define TOD_STRAY_PER_TICK   4       // relocations per normal sweep
#define TOD_STRAY_RUSH_TICK  10      // ...per rushed sweep

// cos(40) — stock's FOV test, verbatim.
#define TOD_STRAY_FOV_COS    0.766
// Never land one closer than this to ANY player. Same number the finale
// selector uses for "in his hull" (_tod_endless_rounds.gsc:54): a bit over one
// second of sprint.
#define TOD_STRAY_DEST_MIN   280

// ---------------------------------------------------------------------------
// THE IDLE LANE (2026-09-04) — user: "enemies just cant target you so they
// just stand still", especially at random spots on the Endless Spire.
//
// THE DISTANCE LANE ABOVE CANNOT SEE THAT BUG, BY CONSTRUCTION. Its only
// admission test is `stray_cost > TOD_STRAY_COST` (6000), and cost is
// Distance2D + 4*|dz| on a tower whose cross-section never reaches 1700 — so
// it is a pure "four laps of vertical separation" rule. A zombie standing 300
// units from a player scores ~300, and the sweep does not merely skip it: it
// actively re-marks it HEALTHY (`z.tod_stray_since = undefined`) every pass,
// so the patience accumulator can never build. Elites are excluded from this
// module entirely (eligible()) and their own watchdog exempts anything inside
// 1500 units (_tod_bosses::tod_boss_stuck_watch), which on the spire is the
// whole hub hall. NOTHING in this map rescued an actor idling next to a
// player. That absence is why an intermittent strand reads as a permanent bug
// rather than a one-second hitch.
#define TOD_STRAY_IDLE_MS     6000   // no meaningful movement for this long = idle
#define TOD_STRAY_IDLE_DIST   48     // movement under this between sweeps is "not moving"
#define TOD_STRAY_IDLE_MELEE  96     // this close = swinging at someone, not stuck
#define TOD_STRAY_IDLE_TRIES  2      // free re-goal/clamp passes before paying for a relocation
// ITS OWN BUDGET, NOT THE DISTANCE LANE'S. idle_rescue's cheap passes (a re-goal
// and a navmesh clamp) return FALSE, so charging them to the shared relocation
// budget would be free — every eligible zombie could run up to four navmesh
// queries and a ForceTeleport inside one server frame on a horde-wide stall.
// Sharing the shared budget instead would be worse: it is 4 (10 while a teleport
// pump drains) and the distance lane needs all of it after a ride.
#define TOD_STRAY_IDLE_PER_TICK 2    // idle_rescue ATTEMPTS per sweep, success or not

// ---------------------------------------------------------------------------
// THE STALLED CLIMB-OUT (2026-09-04) — the other half of the same report, and
// the one the idle lane cannot reach because eligible() refuses in_the_ground.
//
// A riser that never finishes its climb-out is a STATUE, and every piece of
// that is stock's own machinery:
//   _zm_spawner::do_zombie_rise sets `in_the_ground`, threads hide_pop (which
//   Show()s the zombie 0.5 s in, unconditionally), runs AnimScripted
//   "rise_anim" and then blocks in zombie_shared::DoNoteTracks — a bare
//   `for(;;) waittill(flagName)` with NO TIMEOUT (shared.gsc:387-405). Only
//   after it returns does the function clear in_the_ground and fire "risen".
//   zombie_think is parked on that same waittill (_zm_spawner.gsc:581), so
//   `zombie_think_done` is never set — and the ROOT of the behaviour tree runs
//   `idlespawnbehavior`, a looping idle@zombie gated on condition_script_negate
//   zombieisthinkdone (behavior/zm_zombie.ai_bt:117-137), which sits ABOVE the
//   playable-area branch that carries findfleshservice (:552).
// Result: visible, alive, holding an ai_limit slot, with no enemy, no goal and
// no FindFlesh service, forever. It cannot target you and it will not move.
//
// WE DO NOT NEED TO KNOW WHAT STALLED IT. The anim rate being stomped by a
// world pause was one proven producer (fixed at its source in
// _tod_upgrades::set_world_pause), but StopAnimScripted from a nullified
// rise-death, a missing end notetrack, or a spawn("script_origin") that failed
// under gentity pressure all land in the identical state. A bounded escape
// makes the whole class self-healing, which is the only property worth having
// here — every one of those causes is invisible in a live run.
#define TOD_STRAY_RISE_MS    14000   // a climb-out is ~2 s; 14 is "this is never finishing"
#define TOD_STRAY_RISE_SWEEP 2.0

function init()
{
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );
	level thread stray_sweep();
	level thread pump_watch();
	level thread rise_watch();
}

// ---------------------------------------------------------------------------
// THE STALLED CLIMB-OUT WATCHDOG. Deliberately its OWN sweep and not a lane in
// stray_sweep: that function stands down for the upgrade pause, the finale and
// the sealed crown, and a rise stalls most easily during exactly those states.
// It also reads GetAITeamArray rather than get_round_enemy_array so a zombie
// that never joined the round's enemy set is still covered.
// ---------------------------------------------------------------------------
function rise_watch()
{
	level endon( "end_game" );

	for ( ;; )
	{
		wait TOD_STRAY_RISE_SWEEP;

		team = ( ( isdefined( level.zombie_team ) ) ? level.zombie_team : "axis" );
		ai = GetAITeamArray( team );
		if ( !isdefined( ai ) )
			continue;

		now = GetTime();
		for ( i = 0; i < ai.size; i++ )
		{
			z = ai[ i ];
			if ( !isdefined( z ) || !isalive( z ) )
				continue;
			if ( !IS_TRUE( z.in_the_ground ) )
			{
				z.tod_rise_since = undefined;
				continue;
			}
			// A boss is never a riser (they are direct SpawnActor drops) and
			// drop_in owns its own anim rate — never reach into that.
			if ( IS_TRUE( z.is_boss ) || isdefined( z.tod_boss_kind ) || IS_TRUE( z.tod_dropping ) )
				continue;
			// NOR ANYTHING A SLOW EFFECT LEGITIMATELY OWNS. Widow's Wine's
			// cocoon and Time Warp both scale the animation rate, so a climb-out
			// under one is SUPPOSED to take longer than 14 s — forcing it would
			// cancel the effect the player paid for. Same carve-out eligible()
			// and _tod_zombie_speed's sweep already make; hold the clock so the
			// zombie is still covered once the effect ends.
			if ( IS_TRUE( z.b_widows_wine_cocoon ) || ( z tod_zombie_speed::under_anim_slow() ) )
			{
				z.tod_rise_since = now;
				continue;
			}

			if ( !isdefined( z.tod_rise_since ) )
			{
				z.tod_rise_since = now;
				continue;
			}
			// A world pause is not a stall — set_world_pause deliberately slows
			// the climb-out and restores it on the unpause edge. HOLD the clock
			// by pushing the start forward one sweep, rather than re-stamping it
			// to now: re-stamping would let a run with frequent card picks and
			// station buys defer the rescue indefinitely, which is precisely the
			// run where a rise is most likely to have stalled.
			if ( IS_TRUE( level.tod_upgrade_pause ) )
			{
				z.tod_rise_since = z.tod_rise_since + ( TOD_STRAY_RISE_SWEEP * 1000 );
				continue;
			}
			if ( ( now - z.tod_rise_since ) < TOD_STRAY_RISE_MS )
				continue;

			z force_risen();
			WAIT_SERVER_FRAME;
		}
	}
}

// self = a zombie whose climb-out has stalled. Complete the rise by hand, in
// do_zombie_rise's own order, so the zombie joins the behaviour tree.
//
// EVERY CALL HERE IS ONE STOCK ALREADY MAKES ON THIS PATH, which is why none of
// them needs an engine experiment to justify:
//   unlink()          — do_zombie_rise:3007, unconditional, so it is safe on an
//                       entity that is not linked (the anchor is normally gone
//                       by the time the anim starts; we cover the early window).
//   StopAnimScripted  — zombie_utility::zombie_rise_death:1654 stops the very
//                       same "rise_anim" clip, guarded only by isdefined.
//   Show              — hide_pop:1601 has already done it; harmless and makes
//                       the outcome independent of where the stall happened.
//   notify "risen"    — do_zombie_rise:3057's own last line. zombie_think reads
//                       the argument straight into self.find_flesh_struct_string
//                       (_zm_spawner.gsc:582); every riser this map emits carries
//                       script_string "find_flesh" (gen_tower_map.js:4377/5850),
//                       so that is the faithful value.
// A late-returning DoNoteTracks would then run the same three lines a second
// time — a second "risen" with nothing waiting on it is a no-op, so the race is
// benign in both orders.
function force_risen()
{
	if ( isdefined( self.anchor ) )
	{
		self Unlink();
		self.anchor Delete();
	}
	self StopAnimScripted();
	self Show();
	// STOCK'S OWN LINE, AND NOT OPTIONAL (_zm_spawner.gsc:3052). Without it,
	// zombie_utility::zombie_rise_death — threaded on LEVEL by do_zombie_rise
	// with `zombie endon( "rise_anim_finished" )` — stays parked for the rest of
	// the zombie's life. It is waiting for the zombie's health to fall to 1, and
	// on that day it stamps `deathanim = get_rise_death_anim()` (the sink-back-
	// into-the-ground clip) and calls StopAnimScripted on a zombie that has been
	// walking for minutes. Rescuing a rise means replaying stock's exit IN FULL,
	// not just the two lines that unblock zombie_think.
	self notify( "rise_anim_finished" );
	self.in_the_ground = false;
	self.tod_rise_since = undefined;
	self notify( "risen", "find_flesh" );

	// The gait/rate the climb-out was holding is not restored by anything else
	// on this path — apply_speed_for_round's own in_the_ground guard has just
	// stopped applying, so ask it now rather than waiting up to 1.5 s for the
	// keep-alive sweep with a zombie standing next to a player.
	if ( !( self tod_zombie_speed::under_anim_slow() ) )
		self tod_zombie_speed::apply_speed_for_round( tod_zombie_speed::current_round() );

	if ( IS_TRUE( level.tod_dev ) )
		tod_quiet_print( "stray rise: forced a stalled climb-out at ("
		        + int( self.origin[ 0 ] ) + " " + int( self.origin[ 1 ] ) + " " + int( self.origin[ 2 ] ) + ")" );
}

// THE TELEPORTER PUMP. _tod_teleport::do_teleport fires "tod_stray_pump" after
// a ride, which is the one moment we KNOW a party just left a floor. Waiting
// out the 8s patience there would be wrong twice over: it is the user's actual
// complaint, and the zone manager needs ~1s to rebuild the riser pool around
// the arrival (_zm_zonemgr.gsc:1146 waits 1s per pass) — so we hold 1.5s, then
// run hot for 6s with patience waived. Stock has the same idea:
// giant_cleanup::force_check_now (zm_giant_cleanup_mgr.gsc:45-48).
function pump_watch()
{
	level endon( "end_game" );
	for ( ;; )
	{
		level waittill( "tod_stray_pump" );
		// RE-ARM ON THE SAME FRAME. The old shape held the loop for 1.5s inside
		// waittill's own body, so a SECOND ride inside that window was dropped
		// entirely — and with five porters at spawn, two rides within 1.5s is
		// ordinary co-op, not an edge case.
		level thread pump_arm();
	}
}

// The zone manager needs ~1s to rebuild the riser pool around the arrival, so
// the rush starts after that rather than immediately.
function pump_arm()
{
	level endon( "end_game" );
	wait 1.5;
	level.tod_stray_rush = GetTime() + TOD_STRAY_RUSH_MS;
}

function rushing()
{
	return ( isdefined( level.tod_stray_rush ) && GetTime() < level.tod_stray_rush );
}

function stray_sweep()
{
	level endon( "end_game" );

	for ( ;; )
	{
		wait ( ( rushing() ) ? TOD_STRAY_RUSH_SWEEP : TOD_STRAY_SWEEP );

		// THREE STAND-DOWNS, all cleared again on ascension (_tod_spire.gsc
		// :262/271/273) so the spire keeps the system:
		//   tod_upgrade_pause  — the world is frozen (card pick, or the finale's
		//                        CHOICE); moving anything now is visible in a
		//                        still frame and fights the freeze.
		//   tod_finale_aggro   — THE LAST MILE owns spawning: a 0.1s floor plus
		//                        finale_spawn_selection already puts the horde in
		//                        front of every player, so a straggler behind
		//                        costs nothing, and the road's lane seals
		//                        (_tod_finale::lane_lottery) make relocation
		//                        destinations genuinely hazardous.
		//   tod_crown_sealed   — the party is locked in the hall and the
		//                        hall-only spawn filter already does this job.
		// A STAND-DOWN MUST NOT LOOK LIKE IDLING. The motion stamp below reads
		// wall-clock time, and every one of these three states holds zombies
		// still ON PURPOSE — so without re-baselining, the first live sweep
		// after a 15 s card pick would find the whole horde "motionless for 15
		// seconds" and relocate up to a full budget of them at once. Bank the
		// need to re-stamp; the sweep clears it on the pass that acts on it.
		if ( IS_TRUE( level.tod_upgrade_pause ) )
		{
			level.tod_stray_rebase = true;
			continue;
		}
		if ( IS_TRUE( level.tod_finale_aggro ) || IS_TRUE( level.tod_crown_sealed ) )
		{
			level.tod_stray_rebase = true;
			continue;
		}
		// A WARDEN TRIAL IS THE FOURTH STAND-DOWN, and it is the exact analogue
		// of tod_crown_sealed above: the party is locked inside the hub hall and
		// the trial's own box filter already owns every spawn in there. Without
		// this the module would work against itself in both directions — the
		// zombies stranded OUTSIDE the shut gate are the ones the idle lane most
		// wants to rescue, and pick_destination's new trial-box filter would
		// answer by teleporting them INTO the sealed hold-out, quietly stacking
		// the whole outside horde onto a fight that is meant to be sized by
		// trial_recipe. They are no worse off waiting; the lane picks them up
		// the moment the gate opens.
		if ( IS_TRUE( level.tod_trial_active ) )
		{
			level.tod_stray_rebase = true;
			continue;
		}

		zombies = zombie_utility::get_round_enemy_array();
		if ( !isdefined( zombies ) || zombies.size == 0 )
			continue;

		budget = ( ( rushing() ) ? TOD_STRAY_RUSH_TICK : TOD_STRAY_PER_TICK );
		idle_budget = TOD_STRAY_IDLE_PER_TICK;
		now = GetTime();

		// THE MOTION STAMP — the idle lane's only input, and it gets its OWN
		// unbudgeted pass over every zombie. It must not live inside the loop
		// below: that loop breaks the moment the relocation budget runs out, so
		// on a busy sweep the tail of the array would keep a stale stamp and
		// read as "motionless" on the next pass purely because nobody looked at
		// it. One Distance() per zombie is cheap; a false relocation is not.
		// Stamping runs for ineligible zombies too, so one becomes eligible with
		// a fresh clock rather than an inherited one.
		rebase = IS_TRUE( level.tod_stray_rebase );
		level.tod_stray_rebase = undefined;
		for ( i = 0; i < zombies.size; i++ )
		{
			z = zombies[ i ];
			if ( !isdefined( z ) || !isalive( z ) )
				continue;
			if ( rebase || !isdefined( z.tod_idle_org ) || Distance( z.origin, z.tod_idle_org ) > TOD_STRAY_IDLE_DIST )
			{
				z.tod_idle_org   = z.origin;
				z.tod_idle_since = now;
				z.tod_idle_tries = undefined;
			}
		}

		for ( i = 0; i < zombies.size; i++ )
		{
			if ( budget <= 0 )
				break;
			z = zombies[ i ];
			if ( !isdefined( z ) || !isalive( z ) )
				continue;
			if ( !( z eligible( now ) ) )
				continue;

			target = nearest_upright( z.origin );
			if ( !isdefined( target ) )
				break;              // nobody upright — leave the map alone entirely

			if ( stray_cost( z.origin, target.origin ) <= TOD_STRAY_COST )
			{
				z.tod_stray_since = undefined;
				// NEAR IS NOT THE SAME AS HEALTHY. This early-out used to be the
				// whole of the module's opinion about a nearby zombie, and it is
				// how a statue standing in front of a player stayed a statue for
				// the rest of the match. See the TOD_STRAY_IDLE_* block.
				if ( idle_budget > 0 && z idle_stuck( now, target ) )
				{
					idle_budget--;               // charged per ATTEMPT, not per move
					if ( z idle_rescue( now, target ) )
						budget--;
					WAIT_SERVER_FRAME;           // ...and every attempt costs a frame
				}
				continue;
			}

			// Patience. Waived while a teleport pump is draining.
			if ( !isdefined( z.tod_stray_since ) )
			{
				z.tod_stray_since = now;
				continue;
			}
			waited = now - z.tod_stray_since;
			if ( waited < TOD_STRAY_PATIENCE && !( rushing() ) )
				continue;

			// DESPERATION DISARMED for v1. The base arena holds only ~8 risers
			// below z=200, so "every candidate is inside someone's 80-degree
			// cone" is a routine state down there, not a wedge — and taking a
			// SEEN spot would manufacture exactly the materialise-in-your-face
			// pop the boss-relocation work just removed. The failure mode stays
			// "nothing happens", which is today's behaviour anyway. Re-arm only
			// if a live run shows the system wedged by a player holding still.
			// v16.77 (user 2026-09-03: "Once I take the porters sometimes they just
			// wont target me"). THE HATCH WAS NEVER WIRED: every call here passed
			// desperate=false, so the TOD_STRAY_DESPERATE escape the header promises
			// did not exist, and the failure mode was not "nothing happens, retry"
			// but "nothing happens, ever" for a player who keeps the risers in view.
			// After an UP teleport that is the default posture: you land on the
			// gantry FACING the room, both deck risers sit inside the 80-degree cone
			// and the gantry riser sits inside TOD_STRAY_DEST_MIN, so no destination
			// was ever legal and the horde stayed forty floors down.
			// TWO LANES NOW: (a) a zombie stray for TOD_STRAY_DESPERATE takes a SEEN
			// riser (still >= DEST_MIN from everyone; the v14.45 climb-out means a
			// seen arrival is just a zombie rising from a riser, the look every riser
			// has all game); (b) while a TELEPORT PUMP is draining, seen risers are
			// allowed at once — the player just jumped and wants the horde to catch
			// up, and "unseen" was never achievable from the arrival pose anyway.
			desperate = ( rushing() || waited >= TOD_STRAY_DESPERATE );
			spot = pick_destination( target, desperate );
			if ( !isdefined( spot ) )
				continue;           // nothing legal right now (all inside DEST_MIN, or unseen-only and all seen) — try again next sweep

			dest = GetClosestPointOnNavMesh( spot.origin, 48, 32 );
			if ( !isdefined( dest ) )
				continue;

			z relocate( dest, spot, target );
			budget--;
			WAIT_SERVER_FRAME;      // spread the work, stock's own pacing habit
		}
	}
}

// self = a live trash zombie. get_round_enemy_array() already excludes every
// elite in this map (Panzer, Protector, Reaver, hellhound — all of them set
// ignore_enemy_count, _tod_bosses.gsc:1204/1628, _tod_hellhounds.gsc:350,
// _tod_reaver.gsc:250, and all four run tod_boss_stuck_watch instead). The rest
// of these are STATE guards: an actor mid-animation must not be moved out from
// under the animation.
function eligible( now )
{
	if ( IS_TRUE( self.is_boss ) || isdefined( self.tod_boss_kind ) )
		return false;                       // belt + braces over ignore_enemy_count
	if ( IS_TRUE( self.tod_frozen ) )
		return false;
	if ( IS_TRUE( self.in_the_ground ) )
		return false;                       // still climbing out (stock's own exclusion)

	// AGE, stock's two-stage shape (zm_giant_cleanup_mgr.gsc:129-147): a grace
	// period always, and "has it entered play yet" only while young — see the
	// TOD_STRAY_AGE_TIMEOUT note for why the second stage must expire.
	age = ( ( isdefined( self.spawn_time ) ) ? ( now - self.spawn_time ) : TOD_STRAY_AGE_TIMEOUT );
	if ( age < TOD_STRAY_MIN_AGE )
		return false;
	// Stock's gate is a THREE-way AND and the third term was dropped here. On this
	// map every riser is a find_flesh riser, so without it a freshly-risen zombie
	// waits on a 1 Hz IsTouching poll to flip completed_emerging_into_playable_area
	// instead of clearing immediately.
	if ( age < TOD_STRAY_AGE_TIMEOUT
	  && !IS_TRUE( self.completed_emerging_into_playable_area )
	  && self.script_string !== "find_flesh" )
		return false;

	if ( isdefined( self.tod_stray_cool ) && now < self.tod_stray_cool )
		return false;
	// IsTraversing() has exactly ONE stock call site in the whole tree
	// (shared/challenges_shared.gsc:1675) and self.is_traversing is never SET by
	// BO3 stock. A throw here would kill eligible(), kill stray_sweep with it, and
	// ship the whole feature doing nothing with no tell — on a module that has
	// never once executed, that is not a risk worth taking for a belt-and-braces
	// check. The field read cannot throw.
	if ( IS_TRUE( self.is_traversing ) )
		return false;                       // mid-traversal: the anim owns the origin
	if ( IS_TRUE( self.isInMantleAction ) )
		return false;
	if ( self GetPathMode() == "dont move" )
		return false;                       // a mocomp has it pinned
	// Widow's Wine owns a cocooned zombie's position and its FX are anchored to
	// it — the same carve-out _tod_zombie_speed::under_anim_slow makes.
	if ( IS_TRUE( self.b_widows_wine_cocoon ) )
		return false;
	if ( IS_TRUE( self.tod_dropping ) )
		return false;
	return true;
}

// self = an eligible trash zombie the distance lane has just cleared as
// "near enough". -> true if it is a statue rather than a combatant.
//
// FIVE TESTS, AND EVERY ONE OF THEM IS THERE TO STOP A FALSE POSITIVE. The
// module's whole reputation is that relocations are never seen; a net that
// fires on a zombie which is merely busy would re-open the user's older
// complaint ("they just appear") in a new costume.
function idle_stuck( now, target )
{
	if ( !isdefined( self.tod_idle_since ) )
		return false;
	if ( ( now - self.tod_idle_since ) < TOD_STRAY_IDLE_MS )
		return false;
	// IN MELEE RANGE THE ORIGIN IS SUPPOSED TO BE STILL and HasPath() is
	// supposed to be false — that is an attack cycle, not a strand. This test
	// is the reason the lane cannot fire on a zombie beating on a player.
	//
	// MEASURED AGAINST THE NEAREST PLAYER OF ANY POSTURE, not against `target`.
	// `target` is nearest_upright(), which drops crawlers on purpose — a correct
	// rule for choosing where to SEND a zombie and the wrong one for asking
	// whether one is BUSY. Zombies target downed players by stock design
	// (get_closest_valid_player's ignore_laststand_players defaults to false),
	// so a mob on a downed teammate is healthy behaviour; measuring to the
	// upright teammate instead would read every one of them as a statue and
	// relocate the whole mob off him mid-bleedout.
	victim = nearest_any( self.origin );
	if ( isdefined( victim ) && Distance( self.origin, victim.origin ) < TOD_STRAY_IDLE_MELEE )
		return false;
	// NOTE: there is deliberately NO upper distance test here. The caller's
	// `stray_cost <= TOD_STRAY_COST` / `> TOD_STRAY_COST` split IS the divider
	// between the two lanes, so one constant owns the boundary and a double bid
	// is impossible by construction. An earlier cut had its own 4000 cap, which
	// left everything in (4000, 6000] owned by NEITHER lane — the distance lane
	// had already cleared it as near, and this one refused it as far.
	// HasPath() is a real builtin on this codebase (_tod_bosses.gsc:1904 and
	// scripts/zm/archetype_zod_companion.gsc:300 both call it, and stock leans
	// on it throughout archetype_human_locomotion) — so unlike the IsTraversing
	// case documented in eligible(), this cannot throw and take the sweep with
	// it. A zombie holding a route is walking; it is just not walking far.
	if ( self HasPath() )
		return false;
	return true;
}

// self = an idle zombie. Cheapest remedy first, and only the last one moves it.
// -> true if a relocation budget slot was spent.
function idle_rescue( now, target )
{
	// (a) RE-GOAL through the loosening projection ladder. Verbatim the shape
	// _tod_bosses::goal_driver uses on elites, whose header names this exact
	// failure: when stock's strict navmesh projection finds no point it
	// silently goals the actor AT ITS OWN ORIGIN and it idles forever.
	g = GetClosestPointOnNavMesh( target.origin, 64, 30 );
	if ( !isdefined( g ) )
		g = GetClosestPointOnNavMesh( target.origin, 128, 15 );
	if ( !isdefined( g ) )
		g = GetClosestPointOnNavMesh( target.origin, 256, 0 );

	// (b) CLAMP IN PLACE. If the ZOMBIE is what is off the mesh — the shape a
	// pruned Havok region leaves behind — nudge it onto the nearest mesh point.
	// A few units at this range is invisible and needs no arrival animation.
	here = GetClosestPointOnNavMesh( self.origin, 48, 32 );
	if ( isdefined( here ) && Distance( here, self.origin ) > 4 )
		self ForceTeleport( here, self.angles );

	if ( isdefined( g ) )
		self SetGoal( g );

	self.tod_idle_tries = ( ( isdefined( self.tod_idle_tries ) ) ? self.tod_idle_tries + 1 : 1 );
	if ( self.tod_idle_tries < TOD_STRAY_IDLE_TRIES )
	{
		self.tod_idle_org   = self.origin;
		self.tod_idle_since = now;          // one more window for (a)+(b) to take
		return false;
	}

	// (c) LAST RESORT — the module's own relocation, with its v14.45 climb-out
	// arrival. desperate = true so a player standing still cannot wedge the
	// rescue by keeping every riser inside his view cone (the v16.77 lesson);
	// TOD_STRAY_DEST_MIN is never waived even then, so it can never land in
	// anyone's face.
	spot = pick_destination( target, true );
	if ( !isdefined( spot ) )
	{
		self.tod_idle_since = now;
		return false;
	}
	dest = GetClosestPointOnNavMesh( spot.origin, 48, 32 );
	if ( !isdefined( dest ) )
	{
		self.tod_idle_since = now;
		return false;
	}

	if ( IS_TRUE( level.tod_dev ) )
		tod_quiet_print( "stray idle: relocating a zombie stuck " + int( ( now - self.tod_idle_since ) / 1000 )
		        + "s at (" + int( self.origin[ 0 ] ) + " " + int( self.origin[ 1 ] ) + " " + int( self.origin[ 2 ] ) + ")" );

	self.tod_idle_org   = undefined;
	self.tod_idle_since = undefined;
	self.tod_idle_tries = undefined;
	self relocate( dest, spot, target );
	return true;
}

// Estimated WALKING cost from org to p_org (see TOD_STRAY_Z_WEIGHT).
function stray_cost( org, p_org )
{
	dz = org[ 2 ] - p_org[ 2 ];
	if ( dz < 0 )
		dz = 0 - dz;
	return Distance2D( org, p_org ) + dz * TOD_STRAY_Z_WEIGHT;
}

// The nearest UPRIGHT player by estimated walking cost. Downed players are
// excluded on purpose (the same rule finale_spawn_selection uses,
// _tod_endless_rounds.gsc:281-283): a crawler must not be able to summon the
// horde onto himself, and if NOBODY is upright the caller stands the whole
// sweep down rather than relocating onto a bleedout.
function nearest_upright( org )
{
	best = undefined;
	best_c = 0;
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		if ( p.sessionstate == "spectator" )
			continue;
		if ( p laststand::player_is_in_laststand() )
			continue;
		c = stray_cost( org, p.origin );
		if ( !isdefined( best ) || c < best_c )
		{
			best = p;
			best_c = c;
		}
	}
	return best;
}

// The nearest player of ANY posture, INCLUDING last stand. nearest_upright's
// crawler exclusion is a rule about where we may SEND a zombie; it is the wrong
// rule for asking whether one is BUSY (see idle_stuck).
function nearest_any( org )
{
	best = undefined;
	best_d = 0;
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		if ( p.sessionstate == "spectator" )
			continue;
		d = DistanceSquared( org, p.origin );
		if ( !isdefined( best ) || d < best_d )
		{
			best = p;
			best_d = d;
		}
	}
	return best;
}

// -> true if ANY living, non-spectating player could have this point on screen.
// Stock's test verbatim (zm_giant_cleanup_mgr.gsc:250-263): FOV only, no trace.
// Full 3D angles rather than yaw-only, which is stricter on a tower — a player
// looking straight up the spiral is looking at the floors above him.
function seen_by_anyone( org )
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		if ( p.sessionstate == "spectator" )
			continue;
		to = org - p.origin;
		if ( LengthSquared( to ) < 1 )
			return true;
		fwd = AnglesToForward( p GetPlayerAngles() );
		if ( VectorDot( fwd, VectorNormalize( to ) ) >= TOD_STRAY_FOV_COS )
			return true;
	}
	return false;
}

// -> a riser struct to move a stray onto, or undefined.
//
// The pool is stock's own active-zone riser list. The filters below are the
// same three the spawn selector applies (_tod_endless_rounds::
// finale_spawn_selection): never past a shut causeway gate, never off the spire
// once ascended, never above the spire's highest bought door. All three are the
// stranded-actor trap in a different costume — a zombie behind a
// DisconnectPaths'd slab holds an actor slot forever.
function pick_destination( target, desperate )
{
	if ( !isdefined( level.zm_loc_types ) )
		return undefined;
	spots = level.zm_loc_types[ "zombie_location" ];
	if ( !isdefined( spots ) || spots.size == 0 )
		return undefined;

	unseen = [];
	seen   = [];
	players = GetPlayers();

	for ( i = 0; i < spots.size; i++ )
	{
		sp = spots[ i ];
		if ( !isdefined( sp ) || !isdefined( sp.origin ) )
			continue;
		org = sp.origin;

		if ( !IS_TRUE( level.tod_gate_open ) && tod_crown_data::beyond_gate( org ) )
			continue;
		if ( IS_TRUE( level.tod_spire_active ) )
		{
			if ( !( tod_spire_data::in_spire( org ) ) )
				continue;
			if ( isdefined( level.tod_spire_door_max_z ) && org[ 2 ] > level.tod_spire_door_max_z )
				continue;
			// THE SEALED RING (2026-09-04). The same rule the other two spawn
			// selectors already apply — _tod_endless_rounds::
			// finale_spawn_selection and _tod_bosses::pick_spawn_point both
			// filter on level.tod_trial_box — and this module was the one that
			// did not. While a Warden trial runs the hall gate is Solid +
			// DisconnectPaths, so a riser outside it is the stranded-actor trap
			// this whole file exists to prevent: we would have been RELOCATING
			// zombies into it. The hall's own seven risers are inside the box by
			// construction, so the filter has candidates whenever a trial runs.
			if ( isdefined( level.tod_trial_box )
			  && !( tod_spire_data::in_box( org, level.tod_trial_box ) ) )
				continue;
		}
		else if ( tod_spire_data::in_spire( org ) )
			continue;

		c = stray_cost( org, target.origin );
		if ( c > TOD_STRAY_COST )
			continue;               // still stranded there — not a destination

		clear = true;
		for ( j = 0; j < players.size; j++ )
		{
			p = players[ j ];
			if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
				continue;
			if ( DistanceSquared( org, p.origin ) < TOD_STRAY_DEST_MIN * TOD_STRAY_DEST_MIN )
			{
				clear = false;
				break;
			}
		}
		if ( !clear )
			continue;               // never waived, not even when desperate

		if ( seen_by_anyone( org ) )
			seen[ seen.size ] = sp;
		else
			unseen[ unseen.size ] = sp;
	}

	// SPREAD THEM. This used to be a pure argmin with no memory, so every zombie
	// in one sweep got the SAME lowest-cost spot — up to ten ForceTeleports onto
	// one identical tile across ten frames. That is a zombie pile, and it is the
	// "random ugliness" of the boss-relocation complaint wearing a different hat.
	// Stock's own spawner randomises its pick for exactly this reason.
	if ( unseen.size > 0 )
		return array::random( unseen );
	if ( desperate && seen.size > 0 )
		return array::random( seen );
	return undefined;
}

// self = the stray. dest is already navmesh-clamped.
function relocate( dest, spot, target )
{
	self zombie_utility::reset_attack_spot();   // release the claimed spot back there

	yaw = 0;
	to = target.origin - dest;
	to = ( to[ 0 ], to[ 1 ], 0 );
	if ( LengthSquared( to ) > 1 )
	{
		a = VectorToAngles( to );
		yaw = a[ 1 ];
	}
	self ForceTeleport( dest, ( 0, yaw, 0 ) );

	// Stock's own zone stamp for a spawn location (_zm_utility.gsc:205-208) —
	// without it the riser FX / faller logic read a zone the zombie left.
	if ( isdefined( spot.zone_name ) )
	{
		self.zone_name = spot.zone_name;
		self.previous_zone_name = spot.zone_name;
	}

	self.tod_stray_since = undefined;
	self.tod_stray_cool = GetTime() + TOD_STRAY_COOL;

	// THEY CLIMB OUT NOW — they do not blink into existence (v14.45, user
	// 2026-08-31: "if zombies are too far away from you they will spawn at you.
	// Its pretty annoying actually cause they just appear. Can we have them have
	// to spawn back in").
	//
	// The destination was ALREADY a stock riser and already outside every
	// player's view cone — so the complaint was never about where they land, it
	// was that they stand there fully formed. A player who turns around a second
	// later sees a zombie that was not there, and no amount of view-cone testing
	// fixes that, because the giveaway is the absence of an arrival.
	self thread rise_in( spot, target );
}

// self = the relocated zombie. Play stock's own riser climb-out at `spot`, then
// hand the zombie back to the behaviour tree.
//
// WHY THIS IS STOCK'S FUNCTION AND NOT AN IMITATION: _zm_spawner::do_zombie_rise
// is fully self-contained — it spawns its own anchor, links the zombie, Ghosts
// it, moves the anchor to the spot, faces the goal, unlinks, deletes the anchor,
// runs hide_pop, fires the riser FX and AnimScripted's
// "ai_zombie_traverse_ground_climbout_fast" with its notetracks. It has NO
// spawn-time preconditions (verified by reading it, not assumed: the anchor is
// created at :2980, inside the function). So a live, walking zombie can be put
// through it, which is exactly what the stock board-traversal paths already do
// to live zombies elsewhere.
//
// CALLED SYNCHRONOUSLY, INSIDE OUR OWN THREAD, so the SetGoal below lands AFTER
// the climb-out instead of fighting it. do_zombie_rise carries `self
// endon("death")`, which therefore also ends this thread — correct, and the
// reason nothing here needs its own death cleanup.
function rise_in( spot, target )
{
	self endon( "death" );

	self thread rise_cleanup_guard();
	self zm_spawner::do_zombie_rise( spot );

	// Move THIS frame rather than on the next find-flesh service tick. Same
	// navmesh ladder _tod_bosses::goal_driver uses (:1386-1388). AFTER the rise,
	// not before — a goal set while the climb-out anim owns the zombie is a goal
	// set into a scripted animation.
	if ( isdefined( target ) )
	{
		g = GetClosestPointOnNavMesh( target.origin, 64, 30 );
		if ( !isdefined( g ) )
			g = GetClosestPointOnNavMesh( target.origin, 128, 15 );
		if ( isdefined( g ) )
			self SetGoal( g );
	}

	// ForceTeleport and the scripted rise can both leave the ASM animation rate
	// reset. The 1.5s keep-alive sweep in _tod_zombie_speed would heal it, but
	// 1.5s at the wrong gait right next to a player is precisely the window this
	// feature exists to close. GUARDED: apply_speed_for_round has NO
	// under_anim_slow check of its own — that guard lives in the SWEEP — so
	// calling it bare here would wipe a live Widow's Wine cocoon / Time Warp
	// slow off this zombie.
	if ( !( self tod_zombie_speed::under_anim_slow() ) )
		self tod_zombie_speed::apply_speed_for_round( tod_zombie_speed::current_round() );
}

// self = the relocated zombie. Deletes the rise ANCHOR if the zombie dies
// mid-climb-out.
//
// THIS PLUGS A REAL LEAK IN STOCK'S OWN FUNCTION (found by tracing every exit,
// prompted by a peer review 2026-08-31). do_zombie_rise opens with
// `self endon("death")`, spawns a `script_origin` anchor at :2980, and does not
// delete it until :3013 — with two `waittill`s in between (`movedone`,
// `rotatedone`, ~0.05s each). A zombie killed inside that ~0.1s window ends the
// thread before the delete line, and the anchor is orphaned FOREVER: a
// script_origin with nothing referencing it and nothing to clean it up.
//
// Stock carries the same exposure at spawn time and gets away with it, because
// spawn-time rises are bounded by the round's spawn rate and a zombie is rarely
// killed during its own emergence. WE DO NOT GET AWAY WITH IT: relocations fire
// continuously, and on the SPIRE they fire against a 0.18s spawn floor and a
// saturated elite roof — the mode with the tightest entity budget on the map,
// where the ~1024-slot gentity table is the binding constraint. A slow leak of
// invisible script_origins there is exactly the class of bug that presents,
// hours later, as something else entirely failing to spawn.
//
// `endon("risen")` is the normal path: do_zombie_rise notifies it after its own
// anchor delete, so this guard costs one short-lived thread per relocation and
// does nothing in the common case.
function rise_cleanup_guard()
{
	self endon( "risen" );

	self waittill( "death" );

	if ( !isdefined( self ) )
		return;
	if ( isdefined( self.anchor ) )
		self.anchor Delete();
	// Cosmetic rather than load-bearing — a dead zombie needs no gait, and
	// fields cannot leak between zombies (every spawn is a fresh actor, not a
	// pooled one). Cleared anyway so a corpse never reads as mid-rise to
	// anything that inspects it later.
	self.in_the_ground = undefined;
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
