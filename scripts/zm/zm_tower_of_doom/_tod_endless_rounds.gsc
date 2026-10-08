// =============================================================================
// _tod_endless_rounds.gsc — THE TWIST: rounds never pause.
//
// Stock round flow (_zm.gsc round_think): spawn round -> [[round_wait_func]]
// waits until every zombie is DEAD -> round_over() waits
// func_get_delay_between_rounds() -> next loop iteration -> round_one_up()
// waits 2.5s of chalk fanfare -> spawning resumes.
//
// This map: the next round starts the moment the last zombie of the current
// round SPAWNS. Three stock override points, all verified against the stock
// mirror (tmp/bo3_stock_ref/scripts/zm/_zm.gsc):
//   level.round_wait_func            — DEFAULT'd only if undefined (:4130);
//                                      ours returns when zombie_total hits 0
//                                      (all SPAWNED), not when all are dead.
//   level.zombie_round_change_custom — replaces round_one_up (:4380) so there
//                                      is no 2.5s fanfare stall (round 1 keeps
//                                      the stock intro pacing).
//   level.func_get_delay_between_rounds — assigned unconditionally in zm::init
//                                      (:308); we re-assign AFTER
//                                      zm_usermap::main() so ours wins ->
//                                      round_over() waits 0.
//
// Self-regulating: round_spawning throttles on the zombie AI limit, so
// zombie_total only drains as zombies actually spawn. If players stop killing,
// spawning stalls at the cap and the round clock stalls with it.
//
// Call tod_endless_rounds::init() from the entry main() AFTER zm_usermap::main().
// =============================================================================

#using scripts\shared\array_shared;   // array::random (spawn-location fallback)
#using scripts\shared\flag_shared;
// player_is_in_laststand — the finale spawn focus must be UPRIGHT (isalive is
// true in last stand). Stock shared module, imports no tod module: no cycle.
#using scripts\shared\laststand_shared;
#using scripts\zm\_zm;
#using scripts\zm\_zm_audio;
#using scripts\shared\ai\zombie_utility;   // default_max_zombie_func (the stock budget curve tod_max_zombies wraps)
#using scripts\zm\zm_tower_of_doom\_tod_crown_data;   // beyond_gate (the sealed-road spawn filter)
#using scripts\zm\zm_tower_of_doom\_tod_breather_data;   // v13.21 — lounge z-levels (the breather calm-down check)
#using scripts\zm\zm_tower_of_doom\_tod_spire_data;   // v14 — in_spire (the endless-mode spawn filter; leaf module, no cycle)

#insert scripts\shared\shared.gsh;

// THE LAST MILE finale spawn floor (v10) — see tod_spawn_delay below.
#define TOD_FINALE_SPAWN_DELAY   0.1
// ---- RAMPAGE INDUCER (v14.20) --------------------------------------------
// The spawn-pacing half of hard mode. Applied in tod_spawn_delay() below; see
// the comment there for why this is round-granular rather than instant.
//
// 0.80 lands the effective multiplier at 0.83 x 0.80 = 0.664x stock, which is
// almost exactly the 0.65x the map ran as its MIDDLE setting before the two
// 2026-08-29 tone-downs — a pace this map has already shipped and been played
// at, rather than a new guess. That is the whole design of this feature: hand
// the pre-tone-down difficulty back to the players who wanted it, without
// taking it from the ones who did not.
#define TOD_RAMPAGE_SPAWN_MULT   0.80
// The floor has to come down with the multiplier or the squeeze is swallowed at
// depth (stock's own curve decays below 0.30 by round ~20, so a 0.25 floor
// would already be binding and 0.80 x anything would change nothing). 0.20 is
// the pre-tone-down floor, and it stays deliberately ABOVE the spire's 0.18.
#define TOD_RAMPAGE_SPAWN_FLOOR  0.20
// THE SPIRE (user 2026-08-30: rampage must work there too). Its own 0.18 is
// already the hottest pacing on the map, so rampage tightens it by one notch
// rather than by the multiplier — 0.18 x 0.80 = 0.144 is below anything this
// map has ever run and there is no play data anywhere near it.
#define TOD_RAMPAGE_SPIRE_FLOOR  0.16
// v16.15 — the Warden trials' trickle (sealed hub arenas, 2-minute hold-outs).
// LOCKSTEP PAIR with _tod_spire.gsc TOD_TRIAL_SPAWN_FLOOR. Below every other
// floor in the map by design: the trial is the spire's own hard mode.
#define TOD_SPIRE_TRIAL_SPAWN_FLOOR 0.12
// v18.78 — THE HORDE RISES WHERE YOU STAND (the trial halls; user 2026-09-10:
// "Everyone just bunker up in the little cubby and withstands the trial"). Of
// every spawn inside a sealed hall, TOD_TRIAL_NEAR_PCT percent roll a random
// upright player and rise at one of the TOD_TRIAL_NEAR_K risers nearest THEM;
// the rest stay uniform over the hall so the room keeps filling. The generator
// puts a riser INSIDE every pocket a hall has (the porch behind the gate always
// gets two; tools/lint_tod_hall_bunkers.js is the proof), so hiding in one is
// what draws the rise behind you. 100 / 1 would be pure spawn-on-the-player;
// 0 is the old uniform hall. Read by trial_near_spots.
#define TOD_TRIAL_NEAR_PCT       70
#define TOD_TRIAL_NEAR_K         3
// v18.75 — THE WARDEN KING UNDER RAMPAGE runs one notch below the trial floor.
// LOCKSTEP PAIR with _tod_spire.gsc TOD_KING_RAMPAGE_SPAWN_FLOOR (written into
// zombie_vars at the seal; this copy is what each rollover re-resolves).
#define TOD_SPIRE_KING_RAMPAGE_SPAWN_FLOOR 0.10
// ---- THE SPIRE ROUND BUDGET (v16.9) ---------------------------------------
// User 2026-09-01, after a real spire run: "each round was like 15 minutes. We
// need to triple the speed". THE TRICKLE WAS NEVER THE CLOCK AT DEPTH. Under
// the twist a round ends when its budget is SPENT, and round_spawning stalls
// on level.zombie_ai_limit (30-45 by party since v18.11, 45 on rampage — see
// _tod_corpse_cleanup::ai_limit_for_party) whenever that many stand — so past the point
// where the party cannot out-kill the cap, round time = budget / kill rate and
// the 0.18 floor is irrelevant. Stock's budget past round 10 grows as
// round^2 (get_zombie_count_for_round: 24 + 6 x players' x round/5 x round x
// 0.15): round 40 is 168 solo and 888 for four, round 50 is 249 / 1374. A
// party ascends at round 30-60 and every spire round asks for that many
// kills. Dividing the budget is the one lever that moves the clock in that
// regime — spawn delay cannot. Applied through stock's own max_zombie_func
// hook (tod_max_zombies below), so _tod_luck's fair-share normalization
// (KILL_BUDGET x players / round total) follows by construction: a smaller
// round pays more luck per kill and a full clear still lands +40.
// ⚠️ The hook is resolved ONCE per round at round_spawning's top. The round
// already running at ascension keeps the tower's full budget unless it is
// clamped there — _tod_spire::ascend does that (its own lesson: the 0.18
// direct write exists for the same reason). Read this as a divisor of the
// stock curve, not a count: the ai_limit still decides how many stand at once.
// LEDGER — and this one HAS been played now.
//   3   shipped (the literal "triple"), never tested.
//   2   user dialed it down the same session, before any test — "Make it 1/2
//       and not 1/3".
//   1.25 user 2026-09-04, after playing 2: "the rounds progress too fast in the
//       endless spire ... I dont want to revert but I do want to half it. Maybe
//       even 60% less faster." Taken as the far end of that range: undo 60% of
//       the v16.9 speed-up, not all of it.
// READ IT AS A DIVISOR OF THE STOCK CURVE, and reason in ROUND LENGTH, which is
// what the player feels — length is proportional to budget in the budget-bound
// regime described above:
//       DIV 1     stock          round length L      (pre-v16.9)
//       DIV 2     budget 50%     0.50 L              (what was played)
//       DIV 1.25  budget 80%     0.80 L              <- here: 60% LONGER than
//                                                       DIV 2, still 20%
//                                                       shorter than pre-v16.9
//       DIV 1.333 budget 75%     0.75 L              (the milder "half it")
// The round COUNTER is the thing that was racing: a smaller budget is fewer
// kills per round, so the number climbs faster and every per-round ramp — the
// +0.28%/round zombie speed, the boss cadence — ramps with it against a climb
// that has not moved.
// A NON-INTEGER DIVISOR IS FINE: the one use site is int( n / DIV ), the
// division is float and int() truncates. There is no second copy of this
// number — _tod_spire::ascend clamps the in-progress round by RE-RESOLVING
// through zm::get_zombie_count_for_round, which comes back through this hook,
// so it follows any change here by construction.
#define TOD_SPIRE_BUDGET_DIV     1.25
// Floor under the divided budget so a dev-flag ascension at round 2 (stock
// budget 9) does not roll rounds on three zombies.
#define TOD_SPIRE_BUDGET_MIN     12
// HOW CLOSE IN FRONT IS TOO CLOSE. The selector below takes the NEAREST riser
// in the half-plane the player faces, and on the causeway the risers sit on the
// road itself — so "nearest ahead" can be the one under his feet, and a zombie
// claws up inside his hull with no travel time and no chance to react. That is
// not difficulty, it is a coin flip, and the finale is the one part of the map
// where a cheap death cannot be walked back.
// 280 is a bit over one second of sprint: far enough to see it come up, close
// enough that it is still in your face. Squared because that is what the
// comparison below uses.
#define TOD_FINALE_MIN_AHEAD_SQ  ( 280 * 280 )

// ---- THE CROWN-END WALL (v14.47) -----------------------------------------
// User 2026-08-31: "the biggest issue with the final run for the crown is that
// zombies are spawning as you run so if you are fast enough you can just run by
// all of them ... most of them and elites should spawn at the end of the path
// towards the crown. The issue we are trying to prevent is a fast player running
// through and not seeing a single zombie."
//
// WHY THE OLD BEHAVIOUR HAD THIS HOLE, precisely: the aggro picker below spawns
// at the NEAREST riser ahead of a rolled player. Nearest-ahead is a *trailing*
// pressure model — it is always relative to where you are now, so a player
// moving faster than the spawn cadence outruns his own wave and every zombie
// behind him is a zombie he never meets. The road is ~8,220 units; at sprint
// that is under a minute.
//
// THE FIX IS AN ABSOLUTE ANCHOR, NOT A BIGGER RATE — spawns are placed by where
// they are on the ROAD, not by where the player currently is, so the horde
// cannot be outrun because it is not chasing. That principle survives; the
// v14.47 *implementation* of it (a binary far/near split with a scaled
// percentage) did not survive its first play-test and was replaced. Read on.
//
// ---- v14.48: THE THREE BANDS REPLACE THE BINARY SPLIT ---------------------
// The v14.47 far/near split shipped and the user play-tested it. Two defects,
// both real, both fixed here:
//
//   1. "are you spawning them inside the crown. The furthest they should spawn
//      is right at the crown gate." — YES, WE WERE. finale_far_spots took the
//      FURTHEST CANDIDATE and accepted anything within 1400 of it. The hall
//      risers at y~8600 are the furthest, so the band swallowed the crown room.
//      ⚠️ THE CAP IS NOW A FIXED WORLD Y FROM gate_org(), NOT A DISTANCE FROM
//      THE CANDIDATE SET. That is the whole lesson of the bug: anything
//      expressed relative to "the furthest riser" drifts the instant a riser is
//      added somewhere new. (Peer caught the same class of error in my first
//      draft of this fix.)
//   2. "I basically ran 85% of the way there before I saw any of them." —
//      a CONSEQUENCE of (1): the wall existed, but it was inside a building the
//      player cannot see into, so the road read empty until he was on top of it.
//
// THE USER'S OWN DISTRIBUTION REPLACES MINE, and it is a better design: "40%
// crown gate spawn 30% middle of bridge and 30% beginning of bridge". Continuous
// contact along the whole road instead of one clump at the end — you meet
// something early, something in the middle, and the heaviest concentration
// waiting at the objective.
//
// v18.5 REWEIGHTED IT TO 25/25/50 (user 2026-09-06: "reduce the aggression of
// spawn at front of crown ... by like 25%", then the exact split: "25, 25,
// 50"). The three-band MECHANISM is untouched; only the weights moved. The
// objective is now the LIGHTEST band and half the road's spawns meet you at the
// bridge mouth. See the define.
//
// Bands are thirds of the road, derived from the two AUTHORITATIVE gate
// constants (causeway_gate_org y~492 -> gate_org y~7860), never literals — the
// v12 rebuild moved every lane and a hardcoded y would have rotted.
// 40/30/30 -> 30/30/40 (v18.4) -> 25/25/50 (v18.5, the user's own numbers,
// 2026-09-06: "25, 25, 50", after "reduce the aggression of spawn at front of
// crown ... by like 25%"). HALF the road's spawns now start at the bridge
// mouth and the gate band is the LIGHTEST of the three — the exact inversion of
// the v14.48 design, and deliberate.
//
// WHAT THIS DOES AND DOES NOT DO, because the bands are a DISTRIBUTION and not
// a volume: the road's total spawn pressure is UNCHANGED — every riser still
// spawns, the freed share just lands in the beginning band (which is the
// remainder), i.e. BEHIND the party for most of the run instead of waiting at
// the objective. That is the ask read literally: less waiting for you at the
// crown, not an easier road. The volume knob is TOD_FINALE_SPAWN_DELAY (0.1)
// and the elite one is TOD_FINALE_BOSS_ROOF (4) — neither moved.
//
// The scaling shift below still stacks on top, so 4 players + rampage is 37% at
// the gate (was 52 before v18.4) and the beginning band never falls below 38%.
#define TOD_FINALE_BAND_GATE_PCT     25   // nearest the crown gate — was the heaviest third at 40 until v18.4
#define TOD_FINALE_BAND_MID_PCT      25   // middle of the bridge
                                          // beginning = the remainder (50), so the three always total 100
// SCALING (user's earlier ask, kept): more players / rampage move weight OUT of
// the beginning and INTO the crown gate, so the objective gets harder to reach
// rather than the road getting uniformly busier. Deliberately small — the
// 40/30/30 above is an explicit instruction and this must not drown it. Solo
// with rampage off is EXACTLY 40/30/30, which is the condition it was specified
// in. Worst case (4 players + rampage) is 52/30/18.
#define TOD_FINALE_BAND_SHIFT_PLAYER 3
#define TOD_FINALE_BAND_SHIFT_RAMP   6
#define TOD_FINALE_BAND_SHIFT_MAX    12   // beginning never falls below 18%

#namespace tod_endless_rounds;

function init()
{
	level.round_wait_func = &tod_round_wait;
	level.zombie_round_change_custom = &tod_round_change;
	level.func_get_delay_between_rounds = &tod_between_round_delay;
	level.zombie_vars[ "zombie_between_round_time" ] = 0;   // belt + braces
	// v16.9 — the per-round spawn budget. Stock only DEFAULTS this hook when it
	// is undefined at first use (_zm.gsc:3867), so setting it here wins; nothing
	// else in the tree (vendored packs included) assigns it — grep before
	// adding a second writer. Outside the spire it is stock's curve verbatim.
	level.max_zombie_func = &tod_max_zombies;

	// FASTER SPAWN TRICKLE (user 2026-08-17 "rounds didn't seem to start up as
	// quickly"): with seamless rounds the real pacing clock is the per-zombie
	// spawn delay — stock starts at 2.0s (solo) and decays 0.95/round, so early
	// rounds trickle in and the round counter crawls. Chain the stock resolver
	// (KB pattern: save + delegate, never replace wholesale) and HALVE it,
	// floored at 0.15s. Also pre-set round 1's value directly — the resolver is
	// only consulted from round 2 on, and calling the stock func at init time
	// would crash (it switches on level.players.size, which is 0 here).
	level.tod_stock_spawn_delay_func = level.func_get_zombie_spawn_delay;
	level.func_get_zombie_spawn_delay = &tod_spawn_delay;
	level.zombie_vars[ "zombie_spawn_delay" ] = 1.66;   // stock solo round 1 = 2.0, at 0.83x. PING-PONG LEDGER: 0.5x too hot (08-20) -> 0.8x "too slow" (08-22) -> 0.65x -> 0.75x (08-29 first tone-down) -> 0.83x (08-29 SECOND tone-down, Workshop difficulty comments — DELIBERATELY past the old 0.8 bound: that bound predates sprinters, scaled co-op elites and the faster speed curve, and live player feedback outranks it. New working band 0.65-0.90.)

	// v13.24 (same order): TRASH ZOMBIE HP -10% AT EVERY ROUND. Scaling the
	// stock start (150->135) and per-round increase (100->90) by 0.9 with the
	// compounding multiplier untouched is EXACTLY -10% at every round number
	// (pre-10 linear and post-10 exponential alike). Bosses keep their own
	// curves (deliberate); sprinters read level.zombie_health x20 at
	// conversion so they inherit the -10% automatically, as do all
	// %-of-health effects. The vendored packs that read zombie_health_start
	// (mechz, fury) use it as a RATIO base, which a uniform scale preserves.
	level.zombie_vars[ "zombie_health_start" ]    = 135;
	level.zombie_vars[ "zombie_health_increase" ] = 90;

	// One-time pre-round-1 stall (stock waits 2s before the first spawn pass).
	level.zombie_round_start_delay = 1;

	// THE LAST MILE — spawn IN FRONT of the player (user 2026-08-23: "the
	// zombies need to aggressively spawn in front of you"). This is stock's own
	// supported override (_zm_spawner.gsc:2950, shipped precedent
	// zm_giant.gsc:1014), so we are not patching the spawn path — just choosing
	// from the candidate list stock already built.
	level.zm_custom_spawn_location_selection = &finale_spawn_selection;
}

// v13.21 — TRUE while any player stands inside a breather lounge (the
// "extra tone down in breather rooms"). The lounge footprint is one box in
// the even/mirrored frame (all four breathers share it — deck + teleporter
// spur, generous margins) at the four generated z-levels. Checked per
// spawn-delay resolve, so a player stepping out re-arms full pace within one
// spawn. Co-op note, deliberate: one resting player calms the whole spawn
// clock — the alternative (per-zone rate) does not exist in stock's single
// global delay, and a team regrouping at a lounge is exactly when the map
// should breathe.
function tod_player_in_breather()
{
	foreach ( p in GetPlayers() )
	{
		if ( !isdefined( p ) || !IsAlive( p ) ) continue;
		if ( tod_breather_data::lounge_index_at( p.origin ) >= 0 ) return true;
	}
	return false;
}

// -> the spawn location stock should use, from the candidates it offers.
//
// OUTSIDE THE FINALE THIS MUST BEHAVE EXACTLY LIKE STOCK. The hook is GLOBAL —
// it is consulted on every zombie of every round — so the non-finale path
// returns array::random(spots), which is verbatim what stock does when no
// override is set. Getting that wrong would silently re-pace the whole map.
// v18.78 — the TOD_TRIAL_NEAR_K risers nearest a random UPRIGHT player (last
// stand excluded: stock leaves a crawler at health 1, so bare isalive would
// let a downed player draw the whole hall onto the teammate reviving them —
// the finale focus's own lesson below). Empty when nobody qualifies; the
// caller then takes the uniform pick. Selection-sorted: a hall has ~10 risers.
function trial_near_spots( spots )
{
	alive = [];
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( isdefined( p ) && isplayer( p ) && isalive( p )
		     && !( p laststand::player_is_in_laststand() ) )
			alive[ alive.size ] = p;
	}
	if ( alive.size == 0 )
		return [];
	focus = alive[ RandomInt( alive.size ) ];
	near = [];
	used = [];
	for ( k = 0; k < TOD_TRIAL_NEAR_K && k < spots.size; k++ )
	{
		best = -1;
		best_d = 0;
		for ( i = 0; i < spots.size; i++ )
		{
			if ( IS_TRUE( used[ i ] ) || !isdefined( spots[ i ] ) || !isdefined( spots[ i ].origin ) )
				continue;
			d = DistanceSquared( spots[ i ].origin, focus.origin );
			if ( best < 0 || d < best_d )
			{
				best = i;
				best_d = d;
			}
		}
		if ( best < 0 )
			break;
		used[ best ] = true;
		near[ near.size ] = spots[ best ];
	}
	return near;
}

function finale_spawn_selection( spots )
{
	if ( !isdefined( spots ) || spots.size == 0 )
		return undefined;

	// WHILE THE GATE IS SHUT, the causeway and the citadel behind it are
	// pathing-severed from the terrace (_tod_finale::gate_init DisconnectPaths).
	// roof_zone spans all three, though, so the moment a player buys the roof
	// door those risers join the pool — and anything that rose on them would be
	// stranded on a bridge with no route to a player, holding a slot under the
	// actor cap until the map ended. Drop them until gate_open() says otherwise.
	if ( !IS_TRUE( level.tod_gate_open ) )
	{
		inside = [];
		for ( i = 0; i < spots.size; i++ )
		{
			sp = spots[ i ];
			if ( !isdefined( sp ) || !isdefined( sp.origin ) )
				continue;
			if ( tod_crown_data::beyond_gate( sp.origin ) )
				continue;
			inside[ inside.size ] = sp;
		}
		// If EVERY candidate is past the gate something upstream is wrong; take
		// stock behaviour over refusing to spawn at all.
		if ( inside.size > 0 )
			spots = inside;
	}
	// THE LANE LOTTERY (v12.13, docs/41 §B1): risers inside a SEALED lane's
	// band are dropped — the lane is walled off at its mouth, so anything
	// rising there is the stranded-actor trap the gate filter above exists to
	// prevent (path-connected via the merge, yes, but with no player ever
	// inside). _tod_finale publishes the two rolled bands as WORLD-space AABB
	// vector pairs; absent fields = no lottery = stock behaviour.
	if ( isdefined( level.tod_lane_seal_mins ) && isdefined( level.tod_lane_seal_maxs ) )
	{
		open_spots = [];
		for ( i = 0; i < spots.size; i++ )
		{
			sp = spots[ i ];
			if ( !isdefined( sp ) || !isdefined( sp.origin ) )
				continue;
			sealed = false;
			for ( b = 0; b < level.tod_lane_seal_mins.size; b++ )
			{
				mn = level.tod_lane_seal_mins[ b ];
				mx = level.tod_lane_seal_maxs[ b ];
				if ( sp.origin[ 0 ] >= mn[ 0 ] && sp.origin[ 0 ] <= mx[ 0 ]
				  && sp.origin[ 1 ] >= mn[ 1 ] && sp.origin[ 1 ] <= mx[ 1 ]
				  && sp.origin[ 2 ] > 18928 )
				{
					sealed = true;
					break;
				}
			}
			if ( sealed )
				continue;
			open_spots[ open_spots.size ] = sp;
		}
		// Same fail-safe shape as every filter in this function.
		if ( open_spots.size > 0 )
			spots = open_spots;
	}
	// (THE DEREZ TIDE's dead-road filter lived here for one day — removed
	// 2026-08-27 with the tide itself; post-mortem in _tod_finale's beat table.)
	// ONCE THE CROWN IS SEALED, only risers INSIDE the hall are eligible. The
	// party is locked in a 1536-square room and the causeway behind them is
	// pathing-severed by the shut door, so a zombie rising out there is the
	// same stranded-actor trap beyond_gate() exists to prevent - except now it
	// would starve the siege itself, because those slots are exactly what the
	// hold-out needs to put enemies in the room.
	if ( IS_TRUE( level.tod_crown_sealed ) )
	{
		hall = [];
		for ( i = 0; i < spots.size; i++ )
		{
			sp = spots[ i ];
			if ( !isdefined( sp ) || !isdefined( sp.origin ) )
				continue;
			if ( !( tod_crown_data::in_hall( sp.origin ) ) )
				continue;
			hall[ hall.size ] = sp;
		}
		// Same fail-safe as the gate filter above: if the hall has no risers at
		// all, take stock behaviour over refusing to spawn and leaving the siege
		// silent.
		if ( hall.size > 0 )
			spots = hall;
	}
	// v14 — THE ENDLESS SPIRE (docs/44): once ascended, only spire risers at
	// or below the highest bought door are eligible. A riser above the door
	// line is the stranded-actor trap the gate filter exists to prevent, one
	// flight up: path-severed by the slab, holding a slot forever. The z gate
	// (level.tod_spire_door_max_z) is maintained by _tod_spire's door manager.
	if ( IS_TRUE( level.tod_spire_active ) )
	{
		up = [];
		for ( i = 0; i < spots.size; i++ )
		{
			sp = spots[ i ];
			if ( !isdefined( sp ) || !isdefined( sp.origin ) )
				continue;
			if ( !( tod_spire_data::in_spire( sp.origin ) ) )
				continue;
			if ( isdefined( level.tod_spire_door_max_z ) && sp.origin[ 2 ] > level.tod_spire_door_max_z )
				continue;
			up[ up.size ] = sp;
		}
		// Same fail-safe shape as every filter in this function.
		if ( up.size > 0 )
			spots = up;

		// v16.15 — THE SEALED RING (the Warden trials): while a trial runs,
		// only the arena's own risers are eligible — a zombie risen on the
		// spiral outside the shut gate is the stranded-actor trap in its
		// purest form. The box is published by _tod_spire::trial_run from the
		// generated anchors; the sealed-crown filter above is the precedent.
		if ( isdefined( level.tod_trial_box ) )
		{
			ring = [];
			for ( i = 0; i < spots.size; i++ )
			{
				sp = spots[ i ];
				if ( !isdefined( sp ) || !isdefined( sp.origin ) )
					continue;
				if ( tod_spire_data::in_box( sp.origin, level.tod_trial_box ) )
					ring[ ring.size ] = sp;
			}
			if ( ring.size > 0 )
				spots = ring;
			// v18.78 — THE HORDE RISES WHERE YOU STAND. Uniform over the hall's
			// risers, a party in a three-walled pocket saw everything arrive
			// through its one mouth. Now most spawns rise at the risers nearest
			// a random upright player (TOD_TRIAL_NEAR_PCT / _K) — and every
			// pocket has a riser inside it, so hiding is what draws the rise.
			// Re-rolled per spawn, like the finale's focus: nobody is safe for a
			// wave. Falls through to the uniform pick when nobody is upright.
			// v19.76: A FIGHT ONLY. The summit keeps its box after the King now
			// (the gate stays shut, so every riser must be on the deck), but the
			// survival that follows is not a trial: uniform over the deck's
			// risers, the nearest thing to the old "they come up the stair".
			if ( IS_TRUE( level.tod_trial_active ) && spots.size > 1 && RandomInt( 100 ) < TOD_TRIAL_NEAR_PCT )
			{
				near = trial_near_spots( spots );
				if ( near.size > 0 )
					return array::random( near );
			}
		}
	}

	if ( !IS_TRUE( level.tod_finale_aggro ) || spots.size == 1 )
		return array::random( spots );

	// NOTHING PAST THE CROWN GATE (v14.48, user: "The furthest they should spawn
	// is right at the crown gate"). A HARD WORLD-Y CAP, not a distance from the
	// candidate set — see the define block for why that distinction is the whole
	// bug. Applied before the band pick AND before the nearest-ahead picker, so
	// neither path can put a zombie inside the hall during the road run.
	if ( !IS_TRUE( level.tod_crown_sealed ) )
	{
		on_road = [];
		for ( i = 0; i < spots.size; i++ )
		{
			sp = spots[ i ];
			if ( !isdefined( sp ) || !isdefined( sp.origin ) )
				continue;
			if ( sp.origin[ 1 ] > finale_road_y1() )
				continue;
			on_road[ on_road.size ] = sp;
		}
		// Same fail-safe shape as every filter above: if the cap leaves nothing,
		// take what we had rather than refusing to spawn.
		if ( on_road.size > 0 )
			spots = on_road;
	}

	// THE THREE BANDS (v14.48) — 40% crown gate / 30% middle / 30% beginning,
	// rolled per spawn so the split is statistical rather than alternating and a
	// party cannot time their sprint against a pattern.
	//
	// DELIBERATELY NOT APPLIED ONCE THE CROWN IS SEALED. By then everyone is
	// locked in a 1536-square room and the hall filter above has already reduced
	// `spots` to that room; banding it by road-y would bunch the whole siege
	// against one wall. The hold-out wants the room, evenly.
	if ( !IS_TRUE( level.tod_crown_sealed ) )
	{
		picked = finale_band_spots( spots, finale_roll_band() );
		if ( picked.size > 0 )
			return array::random( picked );
		// The rolled band is empty on this road/at this moment — fall through to
		// the nearest-ahead picker rather than refusing to spawn. Same fail-safe
		// shape as every filter above.
	}

	// WHOSE front? A RANDOM LIVING PLAYER, re-rolled for every single spawn.
	//
	// The first cut picked the player furthest along the road, reasoning that the
	// run is decided at the front of the party. In solo that is the same thing.
	// In co-op it is a bug: the hook fires once per zombie, so EVERY zombie in
	// the run would target one player, and the other three could jog the whole
	// gauntlet with nothing spawning near them at all. The user asked for "they
	// get ambushed in all directions" — that has to mean each of them, not the
	// leader on everyone else's behalf.
	//
	// Re-rolling per spawn (rather than, say, round-robin) also means the party
	// cannot learn the pattern and stack on whoever is "safe" this wave.
	alive = [];
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		// THE FOCUS MUST BE UPRIGHT. `isalive` is TRUE in last stand — stock sets
		// health to 1, not 0 (_zm_laststand.gsc:199-200) — so a CRAWLER could be
		// rolled as the focus and his view angles then steered the whole wave.
		// Doubly wrong during the finale: stock has already set_ignoreme(true) on
		// him (_zm_laststand.gsc:201), so those zombies will not even target the
		// man they spawned in front of, while the upright players get a lull and
		// the teammate trying to revive him gets a wave in the back. At a 0.1s
		// spawn floor on the road that is 1/N of every spawn (half of them in a
		// 2-player game) for the length of his bleedout.
		// Every other player pick in this map already excludes downed players;
		// this one read bare isalive. Deliberately NOT zm_utility::is_player_valid
		// with the ignoreme flag — that would also drop an upright player holding
		// Zombie Blood, who should still draw spawns.
		if ( isdefined( p ) && isplayer( p ) && isalive( p )
		     && !( p laststand::player_is_in_laststand() ) )
			alive[ alive.size ] = p;
	}
	if ( alive.size == 0 )
		return array::random( spots );
	focus = alive[ RandomInt( alive.size ) ];

	// AHEAD = in the half-plane the player is FACING, nearest first. Facing
	// rather than road-direction is deliberate: a player who turns to fight
	// the ones behind him should get the next wave in his face too, which is
	// what "aggressively in front of you" means in play. YAW ONLY — and note the
	// road is no longer flat (v12 envelope: ridge/broken-stair at +/-CW_HUMP
	// 256, the plank at +256, THE UNDERCROFT at -CW_DEEP 384 — the deepest the
	// road goes; the generator's CW_DEEP comment points HERE before anyone
	// deepens it), so this is load-bearing: with a pitch component, a player on
	// a crest would read the risers in the trough beside him as "behind" and
	// stop drawing spawns from the lane he is about to walk into.
	ang = focus GetPlayerAngles();
	fwd = AnglesToForward( ( 0, ang[ 1 ], 0 ) );

	// Nearest ahead that is not ON TOP OF HIM. Two candidates are tracked: the
	// nearest at a fair distance (what we want), and the nearest at any distance
	// (the fallback). Without the fallback a player standing on the only riser
	// ahead of him would get stock random instead, which on the causeway means a
	// spawn somewhere behind — the pressure would drop off exactly when he is
	// cornered, which is backwards.
	best = undefined;
	best_d = 0;
	close = undefined;
	close_d = 0;
	for ( i = 0; i < spots.size; i++ )
	{
		sp = spots[ i ];
		if ( !isdefined( sp ) || !isdefined( sp.origin ) )
			continue;
		to = sp.origin - focus.origin;
		to = ( to[ 0 ], to[ 1 ], 0 );
		d2 = LengthSquared( to );
		if ( d2 < 1 )
			continue;
		if ( VectorDot( fwd, VectorNormalize( to ) ) < 0.35 )
			continue;                     // behind or beside — not "in front"
		if ( !isdefined( close ) || d2 < close_d )
		{
			close = sp;
			close_d = d2;
		}
		if ( d2 < TOD_FINALE_MIN_AHEAD_SQ )
			continue;                     // in his hull — not a spawn, an ambush he cannot answer
		if ( !isdefined( best ) || d2 < best_d )
		{
			best = sp;
			best_d = d2;
		}
	}
	if ( !isdefined( best ) )
		best = close;                     // everything ahead is close; take it anyway
	// Nothing ahead of the player we rolled (he is facing back down the road with
	// the whole causeway behind him) — stock's own behaviour rather than forcing
	// a bad spawn. The next spawn re-rolls, so this costs one zombie, not the
	// pressure on him.
	if ( !isdefined( best ) )
		return array::random( spots );
	return best;
}

// PUBLIC — the road's two ends in world Y. +Y is toward the crown. These are the
// ONLY place the band maths touches geometry, and both come from the generated
// crown data rather than from literals or from the candidate set.
//
// ⚠️ IF THE ROAD IS EVER RE-AUTHORED ALONG ANOTHER AXIS, these two functions and
// finale_road_band() are what has to change — nothing else in the band system
// knows which way the causeway runs.
function finale_road_y0() { return tod_crown_data::causeway_gate_org()[ 1 ]; }   // terrace gate, ~492
function finale_road_y1() { return tod_crown_data::gate_org()[ 1 ]; }            // CROWN GATE, ~7860 — the hard cap

// -> which third of the road a world Y sits in. 0 beginning / 1 middle / 2 gate.
// Anything at or past the crown gate is band 2 (it is already capped out of the
// pool by the filter in finale_spawn_selection; this is belt and braces).
function finale_road_band( y )
{
	y0 = finale_road_y0();
	y1 = finale_road_y1();
	span = y1 - y0;
	if ( span <= 0 )
		return 2;                       // degenerate road — treat everything as the gate
	f = ( y - y0 ) / span;
	if ( f < 0.33333 )
		return 0;
	if ( f < 0.66667 )
		return 1;
	return 2;
}

// -> points moved OUT of the beginning band and INTO the crown gate band by
// party size and rampage. See the define block: deliberately small, so the
// user's explicit 40/30/30 still reads as 40/30/30 in the case they specified it
// for (solo, rampage off -> 0).
//
// Counts only UPRIGHT players, matching every other player pick in the finale: a
// downed teammate is not applying pressure and should not make the objective
// harder for the ones still standing.
function finale_band_shift()
{
	shift = 0;

	n = 0;
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( isdefined( p ) && isplayer( p ) && isalive( p )
		     && !( p laststand::player_is_in_laststand() ) )
			n++;
	}
	if ( n > 1 )
		shift += ( n - 1 ) * TOD_FINALE_BAND_SHIFT_PLAYER;

	if ( IS_TRUE( level.tod_rampage_on ) )
		shift += TOD_FINALE_BAND_SHIFT_RAMP;

	if ( shift > TOD_FINALE_BAND_SHIFT_MAX )
		shift = TOD_FINALE_BAND_SHIFT_MAX;
	return shift;
}

// PUBLIC (also read by _tod_bosses, so ELITES follow the same distribution as
// the horde) -> the band this spawn belongs to: 0 beginning / 1 middle / 2 gate.
//
// ONE ROLL FUNCTION FOR BOTH so trash and elites can never drift apart — the
// user described a single distribution for "them and elites", and two copies of
// this arithmetic would be two things to retune and one to forget.
function finale_roll_band()
{
	shift = finale_band_shift();
	gate  = TOD_FINALE_BAND_GATE_PCT + shift;
	mid   = TOD_FINALE_BAND_MID_PCT;

	r = RandomInt( 100 );
	if ( r < gate )
		return 2;
	if ( r < gate + mid )
		return 1;
	return 0;                           // the remainder — beginning of the bridge
}

// -> the candidates sitting in band `b`. Empty is a legitimate answer (a band
// may hold no risers on this road, or none currently offered by stock); the
// caller falls through rather than forcing a bad spawn.
function finale_band_spots( spots, b )
{
	out = [];
	for ( i = 0; i < spots.size; i++ )
	{
		sp = spots[ i ];
		if ( !isdefined( sp ) || !isdefined( sp.origin ) )
			continue;
		if ( finale_road_band( sp.origin[ 1 ] ) != b )
			continue;
		out[ out.size ] = sp;
	}
	return out;
}

// v16.9 — the per-round SPAWN BUDGET (stock's max_zombie_func hook, consulted
// by get_zombie_count_for_round for the round total AND by _tod_luck for its
// per-kill normalization AND by _tod_doors for its party-size ratio — a
// uniform divisor leaves that ratio untouched). Stock's curve verbatim
// everywhere except the spire, where it is cut by TOD_SPIRE_BUDGET_DIV —
// see the define's comment for why the budget, not the trickle, is the
// spire's round clock.
function tod_max_zombies( max_num, n_round )
{
	n = zombie_utility::default_max_zombie_func( max_num, n_round );
	if ( IS_TRUE( level.tod_spire_active ) )
	{
		n = int( n / TOD_SPIRE_BUDGET_DIV );
		if ( n < TOD_SPIRE_BUDGET_MIN )
			n = TOD_SPIRE_BUDGET_MIN;
	}
	return n;
}

// Per-round spawn delay: stock curve at 0.8x, floor 0.3s (was 0.5x/0.15 —
// "rounds are actually too aggressive", user 2026-08-20; the seamless-round
// twist stays, the trickle just breathes more).
function tod_spawn_delay( n_round )
{
	// v14 — THE ENDLESS SPIRE (docs/44): the spire runs hot (user: "aggression
	// picks up ... rounds will fly by but zombies just keep coming non stop and
	// quickly"). 0.18 = sustained finale pressure — keep in lockstep with
	// _tod_spire.gsc's TOD_SPIRE_SPAWN_FLOOR, which ALSO writes it straight
	// into zombie_vars at ascension (this resolver is only consulted per
	// round, live-test lesson 2026-08-29 — a mid-round change lands late).
	// Deliberately ABOVE the base curve's tone-downs below: the base game got
	// gentler for the Workshop audience BECAUSE the spire is the hard mode.
	// (THE CHOICE no longer starves spawning here: a 999 return marinated in
	// zombie_vars and deadlocked the spire's first round — the choice rides
	// stock's world_is_paused flag now, _tod_finale::choice_phase.)
	if ( IS_TRUE( level.tod_spire_active ) )
	{
		// v16.15 — THE WARDEN TRIALS run the hottest floor on the map, rampage
		// or not (it is already below the rampage-spire floor). LOCKSTEP with
		// _tod_spire.gsc's TOD_TRIAL_SPAWN_FLOOR, which also writes it straight
		// into zombie_vars at the seal — the same mid-round reason as 0.18.
		if ( IS_TRUE( level.tod_king_active ) && IS_TRUE( level.tod_rampage_on ) )
			return TOD_SPIRE_KING_RAMPAGE_SPAWN_FLOOR;   // v18.75 — the King's rampage trickle
		if ( IS_TRUE( level.tod_trial_active ) )
			return TOD_SPIRE_TRIAL_SPAWN_FLOOR;
		// RAMPAGE IN THE SPIRE (v14.20, user 2026-08-30: "lets also make sure
		// rampage inducer works with Endless Spire"). The spire's 0.18 is
		// already sustained-finale pressure, so rampage tightens it only to
		// TOD_RAMPAGE_SPIRE_FLOOR rather than applying the full multiplier —
		// 0.18 x 0.80 would be 0.144, below anything this map has ever run.
		if ( IS_TRUE( level.tod_rampage_on ) )
			return TOD_RAMPAGE_SPIRE_FLOOR;
		return 0.18;
	}

	// v13.24 (user 2026-08-29, SECOND tone-down, driven by Workshop
	// difficulty comments: "another 10% less aggressive" + "breather zone
	// gets an extra 5%"): 0.75x/0.23 -> 0.83x/0.25, breather x1.13 -> x1.19
	// (lounges now run at ~0.99x ≈ STOCK pace — a true rest). FULL PING-PONG
	// LEDGER: 0.5x/0.15 too hot (08-20), 0.8x/0.3 "too slow" (08-22),
	// 0.65x/0.2 middle, 0.75x/0.23 first tone-down (08-29). 0.83 sits PAST
	// the old 0.8 bound DELIBERATELY — that bound predates sprinters, scaled
	// co-op elites and the round-18 speed ramp, and live player feedback
	// outranks a stale measurement. New working band 0.65-0.90. Player-count
	// scaling rides the STOCK resolver underneath, so these percentages hold
	// at every lobby size.
	d = [[ level.tod_stock_spawn_delay_func ]]( n_round );
	d = d * 0.83;
	// RAMPAGE INDUCER (v14.20, user 2026-08-30: "I also want spawn
	// aggressiveness to be buffed with rampage inducer. Not sure if we can make
	// that dynamic").
	//
	// YES, IT IS DYNAMIC — but at ROUND granularity, not instantly. This
	// resolver is consulted ONCE PER ROUND by stock (_zm.gsc:4502) and its
	// result is stamped into zombie_vars["zombie_spawn_delay"] for the whole
	// round, so a toggle lands on the NEXT round rollover. Under THE TWIST that
	// is seconds away, which is why this is a resolver change and not a direct
	// zombie_vars write: the spire's ascension needed the direct write only
	// because it could not wait for a rollover (live-test lesson 2026-08-29).
	//
	// A MULTIPLIER, applied BEFORE the floor so the floor still binds. The
	// floor tightens too (0.25 -> TOD_RAMPAGE_SPAWN_FLOOR 0.20) or the
	// multiplier would be swallowed whole at depth, where stock's own curve has
	// already decayed past it — but it stays ABOVE the spire's 0.18, which
	// remains the hottest pacing on the map.
	fl = 0.25;
	if ( IS_TRUE( level.tod_rampage_on ) )
	{
		d = d * TOD_RAMPAGE_SPAWN_MULT;
		fl = TOD_RAMPAGE_SPAWN_FLOOR;
	}
	if ( d < fl )
		d = fl;
	// The breather relief is applied AFTER the rampage squeeze on purpose: the
	// lounges stay a real rest even in hard mode, just a less generous one
	// (0.83 x 0.80 x 1.19 ~= 0.79x stock, against 0.99x normally).
	if ( tod_player_in_breather() )
		d = d * 1.19;

	// THE LAST MILE (v10): during the finale run the trickle goes to its floor —
	// "max aggressivness on spawns" (user 2026-08-23). This is a RATE change
	// only: level.zombie_ai_limit still caps how many stand at once, so the
	// effect is that the 24 slots refill the instant one empties, not that
	// there are more of them. See _tod_bosses::finale_pressure_loop for why
	// raising the cap itself is the one thing this feature must not do.
	//
	// v12.13 (docs/41 §A2): the floor is PHASED — _tod_finale publishes
	// tod_finale_spawn_floor as the song builds (0.4 quiet overture -> 0.2 ->
	// 0.1 from the sustained section on), so the run ESCALATES with the score
	// instead of starting at 11. When the field is not published (any build
	// where the finale module did not set it) this is byte-for-byte the old
	// flat TOD_FINALE_SPAWN_DELAY behaviour.
	if ( IS_TRUE( level.tod_finale_aggro ) )
	{
		f = TOD_FINALE_SPAWN_DELAY;
		if ( isdefined( level.tod_finale_spawn_floor ) )
			f = level.tod_finale_spawn_floor;
		d = f;
	}
	return d;
}

// Replaces stock round_wait (waits for all DEAD). Ours: wait until the round's
// spawn budget is fully spent — every zombie has spawned — then hand the round
// loop straight on. Carry-over zombies from the previous round stay alive and
// blend into the next wave: "the round never ended."
function tod_round_wait()
{
	level endon( "restart_round" );

	wait 0.5;   // let the round_spawning thread establish totals (trimmed from stock's 1s)

	// Wait for round_spawning to set this round's zombie_total (bounded so a
	// hiccup can never wedge the round loop forever).
	waited = 0;
	while ( ( !isdefined( level.zombie_total ) || level.zombie_total <= 0 ) && waited < 10 )
	{
		wait 0.1;
		waited += 0.1;
	}

	// THE TWIST: return once every zombie of this round has SPAWNED.
	while ( isdefined( level.zombie_total ) && level.zombie_total > 0 && !( level flag::get( "end_round_wait" ) ) )
	{
		wait 0.1;
	}

	// NO ROUND-OVER JINGLE (2026-09-24, lead tester: "Audio overlap is still at
	// start of game where you hear zombies music overlap with the music you have
	// played"). A call to stock's music-state player for the "round_end" state
	// lived here and played the "roundend1" music cue every time a round's last
	// zombie SPAWNED — on top of _tod_atmosphere's own track, which owns the
	// music channel. The early rounds are short, so it stacked right at the
	// start. docs/24 (ER-11, 2026-08-21) already said to remove it: "the BO3
	// round-over jingle plays over our loop every minute, contradicting the
	// twist". There is no round end to announce on this map.
}

// Replaces the round_one_up fanfare block. Round 1 keeps the stock intro
// (level-start vox + HUD timing); after that, no stall — the round number HUD
// still updates (SetRoundsPlayed drives it, not this hook).
function tod_round_change()
{
	if ( level.first_round )
	{
		zm::round_one_up();
		return;
	}
}

// round_over() waits this between rounds. Zero = seamless.
function tod_between_round_delay()
{
	return 0;
}
