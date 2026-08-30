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
#using scripts\zm\zm_tower_of_doom\_tod_breather_data;   // v13.21 — lounge z-levels (the breather calm-down check)
#using scripts\zm\zm_tower_of_doom\_tod_spire_data;   // v14 — in_spire (the endless-mode spawn filter; leaf module, no cycle)

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
	players = GetPlayers();
	zs = tod_breather_data::breather_zs();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !IsAlive( p ) )
			continue;
		o = p.origin;
		if ( o[ 0 ] < -900 || o[ 0 ] > -200 || o[ 1 ] < -1550 || o[ 1 ] > -400 )
			continue;
		for ( j = 0; j < zs.size; j++ )
		{
			if ( o[ 2 ] >= zs[ j ] - 64 && o[ 2 ] <= zs[ j ] + 256 )
				return true;
		}
	}
	return false;
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
		return 0.18;

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
	if ( d < 0.25 )
		d = 0.25;
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
