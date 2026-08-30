// =============================================================================
// _tod_stray.gsc — SILENT RELOCATION of zombies the tower has stranded.
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
#define TOD_STRAY_DESPERATE  30000

#define TOD_STRAY_SWEEP      2.0     // seconds between sweeps (stock cleanup: 3.0)
#define TOD_STRAY_RUSH_SWEEP 0.5     // ...while a teleport pump is draining
#define TOD_STRAY_RUSH_MS    6000    // how long a pump keeps the fast cadence
#define TOD_STRAY_PER_TICK   4       // relocations per normal sweep
#define TOD_STRAY_RUSH_TICK  10      // ...per rushed sweep

// cos(40) — stock's FOV test, verbatim.
#define TOD_STRAY_FOV_COS    0.766
// Never land one closer than this to ANY player. Same number the finale
// selector uses for "in his hull" (_tod_endless_rounds.gsc:54): a bit over one
// second of sprint.
#define TOD_STRAY_DEST_MIN   280

function init()
{
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );
	level thread stray_sweep();
	level thread pump_watch();
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
		if ( IS_TRUE( level.tod_upgrade_pause ) )
			continue;
		if ( IS_TRUE( level.tod_finale_aggro ) || IS_TRUE( level.tod_crown_sealed ) )
			continue;

		zombies = zombie_utility::get_round_enemy_array();
		if ( !isdefined( zombies ) || zombies.size == 0 )
			continue;

		budget = ( ( rushing() ) ? TOD_STRAY_RUSH_TICK : TOD_STRAY_PER_TICK );
		now = GetTime();

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
			spot = pick_destination( target, false );
			if ( !isdefined( spot ) )
				continue;           // nothing unseen right now — try again next sweep

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

	// Move THIS frame rather than on the next find-flesh service tick. Same
	// navmesh ladder _tod_bosses::goal_driver uses (:1386-1388).
	g = GetClosestPointOnNavMesh( target.origin, 64, 30 );
	if ( !isdefined( g ) )
		g = GetClosestPointOnNavMesh( target.origin, 128, 15 );
	if ( isdefined( g ) )
		self SetGoal( g );

	// ForceTeleport can transiently reset the ASM animation rate. The 1.5s
	// keep-alive sweep in _tod_zombie_speed would heal it, but 1.5s at the wrong
	// gait right next to a player is precisely the window this feature exists to
	// close. GUARDED: apply_speed_for_round has NO under_anim_slow check of its
	// own — that guard lives in the SWEEP — so calling it bare here would wipe a
	// live Widow's Wine cocoon / Time Warp slow off this zombie.
	if ( !( self tod_zombie_speed::under_anim_slow() ) )
		self tod_zombie_speed::apply_speed_for_round( tod_zombie_speed::current_round() );

	self.tod_stray_since = undefined;
	self.tod_stray_cool = GetTime() + TOD_STRAY_COOL;
}
