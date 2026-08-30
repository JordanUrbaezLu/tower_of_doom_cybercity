// =============================================================================
// _tod_zombie_speed.gsc — the tower speed curve (user spec 2026-08-17):
//
//   "Start them in the sprint animation but they will just move a bit slow.
//    Half sprint speed in sprint animation, ramp linearly to full sprint at
//    round 7. Then every round after that they gain 0.3% speed."
//
// Curve: EVERY zombie runs the SPRINT gait from round 1.
//   rounds 1..7:  playback rate 0.5 -> 1.0 linear (+1/12 per round)
//   rounds 8+:    rate 1.0 + 0.003 * (round - 7)   (unbounded; stock precedent
//                 for >1.0 rates: siegebot 1.429, apothicon 2.0)
//
// ENGINE MECHANISM (inherited from map 1's _acc_zombie_speed — do not re-learn):
// BO3 zombie movement is ROOT-MOTION / animation-driven; there is no "move at
// X%" knob. The two levers are the gait TIER (walk/run/sprint xanims, set via
// zombie_utility::set_zombie_run_cycle_override_value) and
// ASMSetAnimationRate(f) (playback rate — scales cadence AND ground speed by
// the same factor; rates < 1.0 therefore read as slow-motion sprinting, which
// is exactly the requested look here). SetMoveSpeedScale is PLAYER-only.
//
// KEEP-ALIVE (load-bearing, map 1 lesson): a one-shot run-cycle override
// DECAYS (stock re-evaluates locomotion and clobbers it) while the anim rate
// PERSISTS — a spawn-only application drifts to the wrong gait at our rate.
// So a 1.5s sweep continuously re-asserts gait + rate on every live zombie,
// skipping any zombie under an active slow (Widow's Wine / traps own the rate
// while running, then restore it) and anything boss-flagged (bosses drive
// custom locomotion ASMs — touching their speed freezes them; map 1's Brutus
// bug).
// =============================================================================

#using scripts\shared\ai\zombie_utility;
#using scripts\shared\callbacks_shared;

#insert scripts\shared\shared.gsh;

// RETUNED 2026-08-18 (user live test: "practically frozen on round 1" at 0.5 —
// root-motion playback scales ground speed too, so low rates read far slower
// than intended): floor lifted to 0.8, still reaching full sprint at round 7.
#define TOD_ZSPEED_START_RATE   0.8    // round-1 sprint playback rate
// First round at full sprint. History: 7 -> 10 ("too aggressive", user
// 2026-08-20) -> 12 (user 2026-08-23, from the first ship-state run: "the
// zombies speed ramp needs to be nerfed. They are actually too fast") -> 15
// (user 2026-08-23, same day, having confirmed the live value was 12: "lets
// change sprint speed to round 15").
//
// 18 IS THE END OF THIS LEVER (was 15; user 2026-08-29 "sprint speed at
// round 18", part of the same-day aggression tone-down). The ramp is
// (FULL_ROUND - round) steps from the 0.8 floor: at 18 the per-round
// increment is ~1.2% — still legible round to round. Pushing further makes
// it so small the early game stops escalating at all (rounds 1-8 read as
// one flat speed), so if it STILL reads fast after a live run, the next
// lever is lowering TOD_ZSPEED_START_RATE (but not below ~0.7 — 0.5 read as
// "practically frozen" in the 2026-08-18 test) or flattening
// TOD_ZSPEED_STEP, NOT this number.
#define TOD_ZSPEED_FULL_ROUND   18
// 0.003 -> 0.0035 (user 2026-08-24: "Make the speed curve 0.35% instead of
// 0.3%"). UNBOUNDED and compounding on the animation RATE, so the gap widens
// with depth rather than staying flat: round 30 goes 1.045x -> 1.053x full
// sprint, round 50 1.105x -> 1.123x, round 80 1.195x -> 1.228x. The floor and
// the round-15 ramp are untouched — this only steepens what happens after.
#define TOD_ZSPEED_STEP         0.0028 // +0.28% per round after FULL_ROUND (0.35 -> 0.28, user 2026-08-26: "slight nerf on zombies")
#define TOD_ZSPEED_SWEEP_WAIT   1.5    // s between keep-alive sweeps

// ZOMBIE HEALTH SCALE (user 2026-08-22: "scale the zombies health a bit
// more"). A FLAT multiplier applied per-spawn on top of the STOCK health
// curve — the curve's shape is untouched, every round just lands harder.
// This is the single knob: 1.0 = stock, 1.15 = +15%.
// 1.25 -> 1.15 (user 2026-08-29: "Move zombie health down by 0.10", the
// balance pass that landed with the armored-sprinter ladder). The co-op
// +0.15/player below is UNTOUCHED — the ask named the base.
#define TOD_ZHEALTH_MULT        1.15
// CO-OP DIFFICULTY (user 2026-08-23: "Should get harder more players").
//
// The audit found the map scaled its BOSSES with party size (HP 1.0/1.7/2.3/2.6,
// wave sizes by player count) but not the horde itself, while stock's own
// concurrency cap is FLAT — so pressure per player fell as players were added.
// Two levers, chosen because neither can raise the actor count:
//
//   1. HEALTH, here: +15% per extra player on top of the 1.25 base, so solo
//      1.25 / duo 1.40 / trio 1.55 / quad 1.70. Zombies stay just as numerous
//      and just as fast; they take longer to drop, which is pressure that costs
//      nothing in AI slots. Bosses are exempt (they already scale their own HP,
//      and stacking both would double-dip).
//   2. CONCURRENCY, in coop_ai_limit() below.
#define TOD_ZHEALTH_PER_PLAYER  0.15
// SUPERSEDED v10.26 - READ _tod_corpse_cleanup.gsc INSTEAD. These three defines
// and coop_ai_limit() below are inert; the live numbers are TOD_AI_LIMIT 45 and
// TOD_ACTOR_LIMIT 60 over there.
//
// AND THE REASONING BELOW WAS PARTLY WRONG, which is worth leaving visible. It
// says "the true ceiling stays 31 no matter what this says" and that
// actor_limit must not be raised. Both stock values are only DEFAULTS - guarded
// by isdefined() at _zm.gsc:337-343, not engine limits - and map 1 has shipped
// 50/56 for months. What actually makes raising actor_limit safe is DELETING
// CORPSES, because get_current_actor_count() counts every body on the floor;
// without that, the raised cap just fills up with corpses instead of zombies.
// That is the whole reason _tod_corpse_cleanup exists and why both numbers live
// in one file with the delete that makes them safe.
//
// The original note, for the record:
// zombie_ai_limit by party size: 24 solo, +2 per extra player, capped 30.
#define TOD_ZAI_LIMIT_BASE      24
#define TOD_ZAI_LIMIT_PER_PLAYER 2
#define TOD_ZAI_LIMIT_CAP       30

#namespace tod_zombie_speed;

function init()
{
	callback::on_ai_spawned( &on_zombie_spawned_speed );
	level thread speed_keepalive();
	// coop_ai_limit() IS RETIRED (v10.26) and must NOT be threaded again. It was
	// a 2-second loop that rewrote level.zombie_ai_limit by party size, and
	// _tod_corpse_cleanup now owns that field with a flat 45 for the whole game.
	// Two writers on one field is the drift that makes a limit unreadable - and
	// this one would win, because it is a LOOP: it would stomp the 45 back down
	// to 24-30 within two seconds of the first spawn.
	// level thread coop_ai_limit();
}

// Track party size and hand stock's own gate a bigger zombie allowance as
// players join. Polled rather than hooked on connect/disconnect: stock reads
// level.zombie_ai_limit fresh on every spawn pass, so a 2s cadence is exact
// enough and needs no callback plumbing.
// DEAD SINCE v10.26 - not called from anywhere. Kept rather than deleted because
// the comment block above it is the record of WHY concurrency was ever ramped by
// party size, and that reasoning is what a future retune of the flat 45 will want
// to read. Re-threading it would fight _tod_corpse_cleanup for the field.
function coop_ai_limit()
{
	level endon( "end_game" );
	last = -1;
	for ( ;; )
	{
		n = GetPlayers().size;
		if ( n < 1 )
			n = 1;
		lim = TOD_ZAI_LIMIT_BASE + ( n - 1 ) * TOD_ZAI_LIMIT_PER_PLAYER;
		if ( lim > TOD_ZAI_LIMIT_CAP )
			lim = TOD_ZAI_LIMIT_CAP;
		// v10.4 (audit find): during THE LAST MILE up to 4 bosses (the finale
		// roof) share stock's 31-actor gate with the horde — a co-op limit of
		// 28-30 zombies + 4 bosses busy-loops the stock spawner against the
		// gate. Leave the bosses' headroom out of the zombie allowance.
		if ( IS_TRUE( level.tod_finale_aggro ) && lim > 27 )
			lim = 27;
		if ( lim != last )
		{
			last = lim;
			level.zombie_ai_limit = lim;
			// level.zombie_actor_limit is DELIBERATELY not touched — see the
			// note on the defines above.
		}
		wait 2;
	}
}

// PUBLIC — the horde health multiplier for the current party size.
function health_mult()
{
	n = GetPlayers().size;
	if ( n < 1 )
		n = 1;
	return TOD_ZHEALTH_MULT + ( n - 1 ) * TOD_ZHEALTH_PER_PLAYER;
}

// VERIFIED (map 1): callback::on_ai_spawned dispatches with NO args ON the
// spawned actor. is_zombie() gates out dogs/specials.
function on_zombie_spawned_speed()
{
	if ( !( self zombie_utility::is_zombie() ) )
		return;

	self apply_speed_for_round( current_round() );
	// v10.4 (audit find — the health multiplier was INERT since it was
	// written): this on_ai_spawned dispatch fires BEFORE the spawner's own
	// spawn_funcs, and stock zombie_spawn_init (registered there) writes
	// self.health/maxhealth = level.zombie_health with no wait — so an inline
	// write here was clobbered on every stock-queued zombie, and neither the
	// 1.25 base (requested 2026-08-22) nor the co-op +15%/player ever landed.
	// One server frame of deferral applies AFTER stock's write.
	self thread apply_health_scale_deferred();
}

// self = the zombie. Deferred one frame past stock's own health write.
function apply_health_scale_deferred()
{
	self endon( "death" );
	wait 0.05;
	if ( !isdefined( self ) || !isalive( self ) )
		return;
	self apply_health_scale();
}

// Flat multiplier on the STOCK per-round health (user 2026-08-22). Stock sets
// self.health from level.zombie_health at spawn; we scale health AND maxhealth
// together so everything that reads maxhealth stays consistent — Thor's
// %-of-max-health splash and the Electric Cherry damage clamp both do.
// BOSSES ARE EXEMPT: Panzers/Protectors carry their own HP ladder
// (mechz_health_increases + _tod_bosses), and double-scaling them would make
// the boss curve diverge from the design. Same is_boss guard the speed path
// uses; the flag may not be set this early, but is_zombie() already screens
// the mechz archetype out, so this is belt-and-braces.
function apply_health_scale()
{
	if ( IS_TRUE( self.is_boss ) || IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) )
		return;   // bosses carry their own coop_hp_mult — never double-dip
	if ( !isdefined( self.health ) || self.health < 1 )
		return;

	m = health_mult();
	if ( m == 1 )
		return;
	h = int( self.health * m );
	if ( h < 1 )
		h = 1;
	self.health = h;
	self.maxhealth = h;
}

function current_round()
{
	r = level.round_number;
	if ( !isdefined( r ) || r < 1 )
		return 1;
	return r;
}

// Sprint-gait playback rate for a round (the whole curve lives here).
function rate_for_round( round )
{
	if ( round <= TOD_ZSPEED_FULL_ROUND )
	{
		// TOD_ZSPEED_START_RATE at round 1 -> 1.0 at TOD_ZSPEED_FULL_ROUND,
		// linear. Written against the CONSTANTS, never their values, because the
		// original comment ("0.5 at round 1 -> 1.0 at round 7") outlived three
		// retunes of both numbers before anyone noticed.
		return TOD_ZSPEED_START_RATE +
			( round - 1 ) * ( ( 1.0 - TOD_ZSPEED_START_RATE ) / ( TOD_ZSPEED_FULL_ROUND - 1 ) );
	}
	// TOD_ZSPEED_STEP per round past full speed, no cap (the define carries the
	// live percentage — this comment stated a stale number for three retunes
	// running, which is exactly the drift the block above warns about)
	return 1.0 + ( round - TOD_ZSPEED_FULL_ROUND ) * TOD_ZSPEED_STEP;
}

// self = a live regular zombie
function apply_speed_for_round( round )
{
	// NEVER touch a boss's speed — custom locomotion ASMs freeze if stomped
	// (map 1's Brutus lesson; no bosses on this map yet, cheap insurance).
	if ( IS_TRUE( self.is_boss ) || IS_TRUE( self.tod_boss_custom_speed ) )
		return;
	// Don't fight the upgrade-choice freeze (_tod_upgrades owns the rate then).
	if ( IS_TRUE( level.tod_upgrade_pause ) || IS_TRUE( self.tod_frozen ) )
		return;

	// (Re)lock the SPRINT gait only when it has drifted (avoid re-rolling the
	// body variant every sweep).
	if ( self.zombie_move_speed != "sprint" ||
	     !isdefined( self.zombie_move_speed_override ) ||
	     self.zombie_move_speed_override != "sprint" )
	{
		self.zombie_move_speed_override = undefined;
		self zombie_utility::set_zombie_run_cycle_override_value( "sprint" );
	}

	// PER-ZOMBIE ROUND OFFSET (v13.7, the ARMORED SPRINTER — _tod_sprinter sets
	// tod_zspeed_round_add=15; user 2026-08-29 "run at +15 round speed. So if on
	// round 20 the[y] run ... as if it was round 35"). A round OFFSET, not a
	// rate multiplier, ON PURPOSE: the curve is piecewise (linear ramp to
	// TOD_ZSPEED_FULL_ROUND, then +STEP/round), so
	// "+15 rounds" and "x1.something" are different claims — the user asked
	// for the former. Riding through rate_for_round also keeps this inside the
	// one-writer rule and composes with slow_mult()/SUPPRESSING FIRE for free.
	add = 0;
	if ( isdefined( self.tod_zspeed_round_add ) )
		add = self.tod_zspeed_round_add;
	self ASMSetAnimationRate( rate_for_round( round + add ) * self slow_mult() );
	self.tod_zspeed_round = round;
}

// ---------------------------------------------------------------------------
// SUPPRESSING FIRE (docs/25 §9.3 — the HK21's unique, 2026-08-22): a TIMED
// playback-rate multiplier on ONE zombie. The keep-alive sweep multiplies it
// in (slow_mult), so a re-assert never wipes a live slow and an expired one
// restores itself. Bosses are exempt (their ASMs freeze if stomped).
// ---------------------------------------------------------------------------

// self = zombie -> the current slow factor (1.0 = none)
function slow_mult()
{
	if ( isdefined( self.tod_slow_until ) && isdefined( self.tod_slow_mult ) && GetTime() < self.tod_slow_until )
		return self.tod_slow_mult;
	return 1.0;
}

// PUBLIC. self = zombie. mult < 1 slows; ms = duration. A stronger slow
// replaces a weaker one; a weaker one never shortens a stronger one's clock.
function slow( mult, ms )
{
	if ( !isdefined( self ) || !isalive( self ) )
		return;
	if ( IS_TRUE( self.is_boss ) || IS_TRUE( self.tod_boss_custom_speed ) )
		return;
	// Never stomp a slow another system owns (Widow's Wine web/cocoon, trap
	// slowdowns, Time Warp) — their rate is far below ours and they restore it
	// themselves; the sweep skips these zombies for the same reason (review
	// 2026-08-22: an HK21 hit used to pop a cocooned zombie to 0.75x, then
	// slow_expire to FULL rate while the cocoon flag was still set).
	if ( self under_anim_slow() )
		return;
	now = GetTime();
	if ( isdefined( self.tod_slow_until ) && isdefined( self.tod_slow_mult )
	  && now < self.tod_slow_until && self.tod_slow_mult < mult )
		return;
	self.tod_slow_mult = mult;
	self.tod_slow_until = now + ms;
	self apply_speed_for_round( current_round() );
	self thread slow_expire( self.tod_slow_until );
}

// self = zombie. Restores the round rate when the slow lapses (the sweep
// would too, within TOD_ZSPEED_SWEEP_WAIT — this just makes it prompt).
function slow_expire( until )
{
	self endon( "death" );
	self notify( "tod_slow_expire" );   // newest slow owns the clock
	self endon( "tod_slow_expire" );
	d = ( until - GetTime() ) / 1000.0;
	if ( d > 0 )
		wait d;
	// same guard as the sweep: a Widow's/trap slow that began DURING our 1.5s
	// owns the rate now — it restores itself, the sweep re-asserts ours after.
	if ( isdefined( self ) && isalive( self ) && !( self under_anim_slow() ) )
		self apply_speed_for_round( current_round() );
}

function speed_keepalive()
{
	level endon( "end_game" );

	for ( ;; )
	{
		wait TOD_ZSPEED_SWEEP_WAIT;

		r = current_round();
		team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
		zombies = GetAITeamArray( team );

		for ( i = 0; i < zombies.size; i++ )
		{
			z = zombies[ i ];
			if ( !isdefined( z ) || !isalive( z ) )
				continue;
			if ( !( z zombie_utility::is_zombie() ) )
				continue;
			if ( z under_anim_slow() )
				continue;   // don't fight an active slow the player paid for

			z apply_speed_for_round( r );
		}
	}
}

// True while another system owns this zombie's anim rate.
function under_anim_slow()
{
	if ( IS_TRUE( self.b_widows_wine_slow ) )   return true;
	if ( IS_TRUE( self.b_widows_wine_cocoon ) ) return true;
	if ( isdefined( self.a_n_slowdown_timeouts ) &&
	     getarraykeys( self.a_n_slowdown_timeouts ).size > 0 )
		return true;   // generic trap slowdown
	// TIME WARP powerup active (Logical's pack re-slows every frame; without
	// this the sweep would pop zombies to full rate for 1 frame every 1.5s).
	// Its deactivate hard-resets everyone to rate 1.0 — the next sweep pass
	// (<=1.5s) restores our curve.
	if ( isdefined( level.zombie_vars ) &&
	     IS_TRUE( level.zombie_vars[ "zombie_powerup_timewarp_on" ] ) )
		return true;
	return false;
}
