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
#using scripts\zm\zm_tower_of_doom\_tod_crown_data;   // beyond_gate (the sealed-road spawn filter)

#insert scripts\shared\shared.gsh;

// THE LAST MILE finale spawn floor (v10) — see tod_spawn_delay below.
#define TOD_FINALE_SPAWN_DELAY   0.1
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

#namespace tod_endless_rounds;

function init()
{
	level.round_wait_func = &tod_round_wait;
	level.zombie_round_change_custom = &tod_round_change;
	level.func_get_delay_between_rounds = &tod_between_round_delay;
	level.zombie_vars[ "zombie_between_round_time" ] = 0;   // belt + braces

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
	level.zombie_vars[ "zombie_spawn_delay" ] = 1.3;   // stock solo round 1 = 2.0, at 0.65x (1.6/0.8x -> 1.3/0.65x, user 2026-08-22 "spawn more aggressively"; 1.0/0.5x was rejected as too hot 2026-08-20)

	// One-time pre-round-1 stall (stock waits 2s before the first spawn pass).
	level.zombie_round_start_delay = 1;

	// THE LAST MILE — spawn IN FRONT of the player (user 2026-08-23: "the
	// zombies need to aggressively spawn in front of you"). This is stock's own
	// supported override (_zm_spawner.gsc:2950, shipped precedent
	// zm_giant.gsc:1014), so we are not patching the spawn path — just choosing
	// from the candidate list stock already built.
	level.zm_custom_spawn_location_selection = &finale_spawn_selection;
}

// -> the spawn location stock should use, from the candidates it offers.
//
// OUTSIDE THE FINALE THIS MUST BEHAVE EXACTLY LIKE STOCK. The hook is GLOBAL —
// it is consulted on every zombie of every round — so the non-finale path
// returns array::random(spots), which is verbatim what stock does when no
// override is set. Getting that wrong would silently re-pace the whole map.
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

	if ( !IS_TRUE( level.tod_finale_aggro ) || spots.size == 1 )
		return array::random( spots );

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

// Per-round spawn delay: stock curve at 0.8x, floor 0.3s (was 0.5x/0.15 —
// "rounds are actually too aggressive", user 2026-08-20; the seamless-round
// twist stays, the trickle just breathes more).
function tod_spawn_delay( n_round )
{
	// v9.9 (user 2026-08-22: "zombies need to spawn more aggressively — they
	// take too long entering the map"). 0.8x/0.3 -> 0.65x/0.2. NOTE the
	// history so this does not ping-pong: 0.5x/0.15 was tried and REJECTED as
	// "too aggressive" (2026-08-20); this is a measured step between the two,
	// not a swing back to the rejected value.
	d = [[ level.tod_stock_spawn_delay_func ]]( n_round );
	d = d * 0.65;
	if ( d < 0.2 )
		d = 0.2;

	// THE LAST MILE (v10): during the finale run the trickle goes to its floor —
	// "max aggressivness on spawns" (user 2026-08-23). This is a RATE change
	// only: level.zombie_ai_limit still caps how many stand at once, so the
	// effect is that the 24 slots refill the instant one empties, not that
	// there are more of them. See _tod_bosses::finale_pressure_loop for why
	// raising the cap itself is the one thing this feature must not do.
	if ( IS_TRUE( level.tod_finale_aggro ) && d > TOD_FINALE_SPAWN_DELAY )
		d = TOD_FINALE_SPAWN_DELAY;
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

	level thread zm_audio::sndMusicSystem_PlayState( "round_end" );
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
