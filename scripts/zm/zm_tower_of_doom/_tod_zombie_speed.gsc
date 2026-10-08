// =============================================================================
// _tod_zombie_speed.gsc — the tower speed curve (user spec 2026-08-17):
//
//   "Start them in the sprint animation but they will just move a bit slow.
//    Half sprint speed in sprint animation, ramp linearly to full sprint at
//    round 7. Then every round after that they gain 0.3% speed."
//
// Curve: ordinary zombies run the SPRINT gait from round 1. The armored
// sword zombie uses an arms-down WALK (v19.77c) at its existing offset rate.
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
// RAMPAGE INDUCER (v14.20, user 2026-08-30: "I want sprint speed to max at
// round 10 instead"). The ramp's end round while the breaker is thrown — read
// ONLY by full_round() below, which is read ONLY by rate_for_round(). See the
// delta table on full_round() before retuning: this steepens the ramp, it does
// not raise the tail.
#define TOD_RAMPAGE_FULL_ROUND  10
// 0.003 -> 0.0035 (user 2026-08-24: "Make the speed curve 0.35% instead of
// 0.3%"). UNBOUNDED and LINEAR on the animation RATE - rate_for_round returns
// 1.0 + ( round - FULL_ROUND ) * STEP - so the gap widens
// with depth rather than staying flat. At the v18.2 rate: round 30 is 1.025x
// full sprint, round 50 1.067x, round 80 1.130x. The floor and
// the round-18 ramp are untouched — this only steepens what happens after.
#define TOD_ZSPEED_STEP         0.0021 // +0.21% per round after FULL_ROUND, LINEAR (0.0028 x 0.75 - v18.2, user 2026-09-06: "there is a zombie speed multiplier ... we do need to lower that by twenty five percent"); 0.35 -> 0.28 (user 2026-08-26)
// RAMPAGE KEEPS THE OLD CLIMB (v18.11, user 2026-09-07: "Can we change the
// zombie speed as well? Can we have rampage vs regular values?"). 0.0028 is
// exactly what every player faced before v18.2 cut the base rate 25%, so hard
// mode is not a new number anybody has to guess at — it is the tuning the map
// shipped with, and the base game is what moved.
//
// The gap widens with depth, which is the point: at round 50 base is 1.067x full
// sprint and rampage 1.090x; by round 80 it is 1.130x against 1.174x.
#define TOD_RAMPAGE_ZSPEED_STEP 0.0028
#define TOD_ZSPEED_SWEEP_WAIT   1.5    // s between keep-alive sweeps

// ZOMBIE HEALTH SCALE (user 2026-08-22: "scale the zombies health a bit
// more"). A multiplier applied per-spawn on top of the STOCK health curve —
// the curve's shape is untouched, every round just lands harder. Bosses are
// exempt (apply_health_scale skips the is_boss triad; they carry
// coop_hp_mult instead, and stacking both would double-dip).
//
// A TABLE SINCE v18.1, NOT A FORMULA, and that is the whole reason it looks
// like this. User 2026-09-06, after a solo-vs-trio audit: "Health drop to 1x,
// drop duo trio quad by 0.1" — solo 1.15 -> 1.00 (-0.15) and the rest -0.10
// each. That set is 1.00 / 1.20 / 1.35 / 1.50, whose steps are +0.20, +0.15,
// +0.15. No single base-plus-step reproduces it, so writing one would have
// meant quietly changing a number the user named. coop_hp_mult() in
// _tod_bosses.gsc is the in-tree precedent for a per-size table.
//
// LADDER: 1.25 base at v9 ("scale the zombies health a bit more"), 1.15 at
// v14.10 ("Move zombie health down by 0.10"), this table at v18.1. The co-op
// rise is deliberate and predates all of it (user 2026-08-23: "Should get
// harder more players") — a trio still pays 35% more health than stock, it
// just brings three guns to it. Solo pays nothing extra now.
#define TOD_ZHEALTH_1P          1.00
#define TOD_ZHEALTH_2P          1.20
#define TOD_ZHEALTH_3P          1.35
#define TOD_ZHEALTH_4P          1.50
// RAMPAGE (v18.74, user 2026-09-10: "Elites panzer and zombies health increase
// by 20%"). The horde had NO rampage health lever until now — hard mode's HP
// side was elites only (_tod_bosses TOD_RAMPAGE_HP_MULT). Multiplies the party
// table above; read ONLY through rampage_horde_mult() so the ARMORED SPRINTER
// (which multiplies an already-scaled horde zombie) can divide it back out and
// take exactly the elite figure once.
#define TOD_RAMPAGE_ZHEALTH_MULT 1.20
// CO-OP DIFFICULTY (user 2026-08-23: "Should get harder more players") — the
// REASON the table above rises, kept because the reason outlived the numbers.
//
// The v10 audit found the map scaled its BOSSES with party size (HP
// 1.0/1.7/2.3/2.8, wave sizes by player count) but not the horde itself, while
// stock's own concurrency cap is FLAT — so pressure per player FELL as players
// were added. Two levers, chosen because neither can raise the actor count:
// HEALTH (the table above) and CONCURRENCY (now
// _tod_corpse_cleanup::ai_limit_for_party(), v18.11).
//
// (TOD_ZHEALTH_PER_PLAYER 0.15 lived here and is retired with v18.1's table —
// the asked-for set is not a constant step. The figures this comment used to
// quote, "solo 1.25 / duo 1.40 / trio 1.55 / quad 1.70", were already two
// base changes stale when they were read on 2026-09-06: a comment that quotes
// a computed set is a second source of truth that nothing regenerates. Read
// the four defines.)
// SUPERSEDED v10.26 - READ _tod_corpse_cleanup.gsc INSTEAD. It owns
// level.zombie_ai_limit, and since v18.11 that field is PARTY-AWARE again
// (ai_limit_for_party(), 30/35/40/45) with TOD_ACTOR_LIMIT 60 beside it. The
// defines and the function that used to sit here are gone - see the end of this
// block for what was kept and why.
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
//
// v18.11 — THE DEFINES AND coop_ai_limit() ARE DELETED. Party-aware concurrency
// came back, but in _tod_corpse_cleanup where the field's owner lives, so a
// second set of numbers here is exactly the drift this file spent forty lines
// warning about. The idea outlived the code: read ai_limit_for_party().
//
// ONE CLAUSE FROM THE DELETED BODY IS DELIBERATELY NOT PORTED — it clamped the
// limit to 27 during the finale, because "up to 4 bosses share stock's 31-actor
// gate with the horde". That premise is retired: the actor gate is
// TOD_ACTOR_LIMIT 60 now, and corpses are deleted rather than left to fill it,
// which is the change that made the higher ceiling safe. If the finale ever does
// busy-loop against the gate again, the clause belongs in ai_limit_for_party().

#namespace tod_zombie_speed;

function init()
{
	callback::on_ai_spawned( &on_zombie_spawned_speed );
	level thread speed_keepalive();
// coop_ai_limit() WAS RETIRED (v10.26) and DELETED (v18.11). It was a
	// 2-second loop that rewrote level.zombie_ai_limit by party size, and
	// _tod_corpse_cleanup owns that field. Two writers on one field is the drift
	// that makes a limit unreadable, and this one would have won, because it is a
	// LOOP. Party-aware concurrency is back as of v18.11 — in the owning file,
	// where there is still exactly one writer. Do not add a second here.
}

// PUBLIC — the horde health multiplier for the current party size (v18.1: a
// table, see the defines). A 5th body cannot exist in ZM, but clamp anyway so
// a bad count can never return undefined into an int() multiply.
function health_mult()
{
	n = GetPlayers().size;
	if ( n <= 1 )
		m = TOD_ZHEALTH_1P;
	else if ( n == 2 )
		m = TOD_ZHEALTH_2P;
	else if ( n == 3 )
		m = TOD_ZHEALTH_3P;
	else
		m = TOD_ZHEALTH_4P;
	return m * rampage_horde_mult();
}

// PUBLIC — the horde's RAMPAGE health factor (v18.74), 1.0 with the breaker
// off. Field-reads level.tod_rampage_on like every other consumer; _tod_rampage
// is the only writer and nothing is imported in either direction.
function rampage_horde_mult()
{
	if ( IS_TRUE( level.tod_rampage_on ) )
		return TOD_RAMPAGE_ZHEALTH_MULT;
	return 1.0;
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

// RAMPAGE INDUCER (v14.20) — the round at which the sprint ramp COMPLETES.
// TOD_ZSPEED_FULL_ROUND (18) normally; TOD_RAMPAGE_FULL_ROUND (10) while the
// breaker is thrown (user 2026-08-30: "I want sprint speed to max at round 10
// instead").
//
// A STEEPER RAMP, NOT AN OFFSET AND NOT A MULTIPLIER — deliberately, because
// this is what was asked for in the units it was asked in. Know the shape it
// buys before retuning it: the ramp is the only part of the curve that moves,
// so the gain peaks mid-climb and thins out at depth.
//
//        round     normal (18)   rampage (10)    delta
//          1          0.800         0.800        +0.0%
//          5          0.847         0.889        +5.0%
//         10          0.906         1.000       +10.4%
//         18          1.000         1.022        +2.2%
//         40          1.062         1.084        +2.1%
//
// Past the kink both curves climb at the same TOD_ZSPEED_STEP, so the rampaged
// horde stays a flat ~2% ahead forever. THE ELITE DOUBLING is what carries this
// feature at depth (_tod_bosses::elite_mult) — if a live run reads "too easy
// after round 20", that is the lever to pull, not this one. Making the tail
// bite would need a rate MULTIPLIER at the ASMSetAnimationRate call below,
// which is a different feature with a different risk profile (map 1's F4: a raw
// 1.7 rate read as cartoonish).
//
// ONE READER — rate_for_round, immediately below. _tod_rampage.gsc is the sole
// writer of level.tod_rampage_on; nothing is imported in either direction.
function full_round()
{
	if ( IS_TRUE( level.tod_rampage_on ) )
		return TOD_RAMPAGE_FULL_ROUND;
	return TOD_ZSPEED_FULL_ROUND;
}

// The per-round climb past full sprint, split the same way and for the same
// reason (v18.11). Resolved through a function rather than read inline so the
// two branches can never drift, exactly like full_round() above.
//
// ⚠️ TOD_ZSPEED_FULL_ROUND IS DELIBERATELY NOT PART OF THIS PASS. The block on
// that define is explicit that 18 is the END of that lever — pushing it further
// makes the per-round increment so small the early game stops escalating at all
// — and it names THIS constant and TOD_ZSPEED_START_RATE as the next levers
// instead. That advice is being followed rather than overridden.
function zspeed_step()
{
	if ( IS_TRUE( level.tod_rampage_on ) )
		return TOD_RAMPAGE_ZSPEED_STEP;
	return TOD_ZSPEED_STEP;
}

// Sprint-gait playback rate for a round (the whole curve lives here).
function rate_for_round( round )
{
	// Resolved ONCE per call: the flag can flip between the two reads below
	// (the keep-alive sweep runs every 1.5 s while a player is on the trigger),
	// and a curve that used 18 for the branch and 10 for the arithmetic would
	// emit a discontinuity at the seam.
	fr = full_round();

	if ( round <= fr )
	{
		// TOD_ZSPEED_START_RATE at round 1 -> 1.0 at fr, linear. Written
		// against the CONSTANTS, never their values, because the original
		// comment ("0.5 at round 1 -> 1.0 at round 7") outlived three retunes
		// of both numbers before anyone noticed.
		return TOD_ZSPEED_START_RATE +
			( round - 1 ) * ( ( 1.0 - TOD_ZSPEED_START_RATE ) / ( fr - 1 ) );
	}
	// TOD_ZSPEED_STEP per round past full speed, no cap (the define carries the
	// live percentage — this comment stated a stale number for three retunes
	// running, which is exactly the drift the block above warns about)
	return 1.0 + ( round - fr ) * zspeed_step();
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
	// NOR A RISER MID-CLIMB-OUT (v14.45). `in_the_ground` is STOCK's own field,
	// set by _zm_spawner::do_zombie_rise for the duration of the scripted
	// climb-out and cleared when it finishes. While it is set the zombie is
	// under AnimScripted, and re-asserting the gait override + animation rate
	// underneath a scripted animation is a fight this sweep cannot win cleanly.
	//
	// Stock's field rather than a tod flag ON PURPOSE: it covers _tod_stray's
	// relocation rise AND every ordinary spawn-time riser, so nothing new has to
	// remember to opt in. _tod_stray re-asserts the rate itself the moment the
	// climb-out completes, so no zombie is left at the wrong gait.
	if ( IS_TRUE( self.in_the_ground ) )
		return;
	// Also needed for callers outside the keep-alive (promotion, unpause and
	// relocation). A Widow's Wine web / trap / Time Warp owns the rate until it
	// releases the actor; promotion must not free an already-slowed zombie.
	if ( self under_anim_slow() )
		return;

	// Native arms-down walking makes the armored silhouette distinct and
	// keeps its sword forearms low. Stock picks a valid walk variant once;
	// reassert only on drift, so the keep-alive never rerolls it every sweep.
	// Root motion means this is a slower approach as well as a new animation.
	gait = "sprint";
	arms_drift = false;
	if ( IS_TRUE( self.tod_is_sprinter ) )
	{
		gait = "walk";
		arms_drift = self.zombie_arms_position != "down";
		self.zombie_arms_position = "down";
	}
	gait_drift = arms_drift || self.zombie_move_speed != gait ||
	     !isdefined( self.zombie_move_speed_override ) ||
	     self.zombie_move_speed_override != gait;
	if ( gait_drift )
	{
		self.zombie_move_speed_override = undefined;
		self zombie_utility::set_zombie_run_cycle_override_value( gait );
	}

	// PER-ZOMBIE ROUND OFFSET (v13.7, the ARMORED SPRINTER — _tod_sprinter sets
	// tod_zspeed_round_add; the value has moved +15 -> +12 -> +10 -> **-10**
	// (v14.44, 2026-08-31) and is now NEGATIVE, so read TOD_SPRINT_SPEED_ADD
	// rather than any number written here. The offset is signed on purpose:
	// nothing in this function assumes it makes a zombie faster). A round
	// OFFSET, not a
	// rate multiplier, ON PURPOSE: the curve is piecewise (linear ramp to
	// TOD_ZSPEED_FULL_ROUND, then +STEP/round), so
	// "+15 rounds" and "x1.something" are different claims — the user asked
	// for the former. Riding through rate_for_round also keeps this inside the
	// one-writer rule and composes with slow_mult()/SUPPRESSING FIRE for free.
	add = 0;
	if ( isdefined( self.tod_zspeed_round_add ) )
		add = self.tod_zspeed_round_add;
	rate = rate_for_round( round + add ) * self slow_mult();
	self ASMSetAnimationRate( rate );
	self.tod_zspeed_round = round;
	self log_armored_walk( gait_drift, round, add, rate );
}

// Change-only dev evidence: promotion, restored gait, a new round, rampage or
// suppressing-fire rate. No extra watcher, native calls or gameplay decisions.
function log_armored_walk( gait_drift, round, add, rate )
{
	if ( !IS_TRUE( level.tod_dev ) || !IS_TRUE( self.tod_is_sprinter ) )
		return;
	if ( !gait_drift && isdefined( self.tod_armored_walk_log_rate ) && self.tod_armored_walk_log_rate == rate )
		return;
	self.tod_armored_walk_log_rate = rate;
	variant = "unset";
	if ( isdefined( self.variant_type ) )
		variant = self.variant_type;
	line = "[TOD_ARMORED_WALK] ms=" + GetTime() + " APPLY rev=1 ent=" + self GetEntityNumber()
		+ " gait=" + self.zombie_move_speed + " override=" + self.zombie_move_speed_override
		+ " arms=" + self.zombie_arms_position + " variant=" + variant + " repaired=" + gait_drift
		+ " round=" + round + " round_add=" + add + " rate=" + rate + " slow=" + self slow_mult()
		+ " rampage=" + IS_TRUE( level.tod_rampage_on );
	/#
	PrintLn( line );
	#/
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

// ---------------------------------------------------------------------------
// THE ELITE SLOW (v17.84, user 2026-09-05: TRAILBLAZER "should slow elites but
// not burn them"). slow() above REFUSES anything boss-flagged and always will:
// the sweep, the gait override and slow_mult() are the horde's lane and an
// elite drives a custom locomotion ASM. This is a SEPARATE, NARROWER lane —
// no gait, no sweep, no slow_mult, just a timed playback rate and a restore.
//
// WHY THIS IS SAFE, AND IT IS NOT AN ASSUMPTION: the upgrade pause already
// writes ASMSetAnimationRate( 0.05 ) on EVERY axis AI including all four
// elites (_tod_upgrades.gsc set_world_pause), and every one of them threads
// tod_bosses::boss_pause_watch, which restores its own base rate on the
// unpause edge. Every card event in this map's history has slowed the Panzer,
// the Protector, the Reaver and the hounds to 5% and put them back. A 34%
// slow for 1.2 s is the same lever, gentler.
//
// THE BASE RATE COMES FROM ONE STAMP. boss_pause_watch already receives each
// elite's true rate (1.0 hound/Reaver, TOD_PANZER_ANIM_RATE, TOD_RP_ANIM_RATE)
// and now records it as .tod_elite_base_rate — so the restore here can never
// drift from the pause watcher's restore. Deliberately NOT .tod_base_rate:
// that field is also the gate that picks a sky-drop relocation over a ground
// tell (_tod_bosses.gsc ~:1018), and stamping it on a hound or a Reaver would
// silently give them an entrance they are not built for.
//
// WE NEVER FIGHT AN OWNER. Three states own an elite's rate outright — the
// drop-in entrance (tod_dropping), the upgrade pause and a menu freeze — and
// this lane declines to write in all three, on the way in AND on the way out.
// The cost of losing to them is one lapsed slow; TRAILBLAZER re-applies every
// 500 ms tick a zombie stands in fire.
// ---------------------------------------------------------------------------

// True while another system owns this ELITE's animation rate.
function elite_rate_owned()
{
	if ( IS_TRUE( level.tod_upgrade_pause ) ) return true;
	if ( IS_TRUE( self.tod_dropping ) )       return true;
	if ( IS_TRUE( self.tod_frozen ) )         return true;
	return false;
}

// PUBLIC. self = a boss-flagged actor. mult < 1 slows; ms = duration.
// A no-op on anything that never stamped a base rate, so a future elite opts
// IN by threading boss_pause_watch (which every one of them already does)
// rather than by being remembered here.
function slow_elite( mult, ms )
{
	if ( !isdefined( self ) || !isalive( self ) )
		return;
	if ( !isdefined( self.tod_elite_base_rate ) )
		return;
	if ( self elite_rate_owned() )
		return;
	// Same precedence rule as slow(): a stronger slow replaces a weaker one,
	// a weaker one never shortens a stronger one's clock.
	now = GetTime();
	if ( isdefined( self.tod_eslow_until ) && isdefined( self.tod_eslow_mult )
	  && now < self.tod_eslow_until && self.tod_eslow_mult < mult )
		return;
	self.tod_eslow_mult  = mult;
	self.tod_eslow_until = now + ms;
	self ASMSetAnimationRate( self.tod_elite_base_rate * mult );
	self thread slow_elite_expire( self.tod_eslow_until );
}

// self = the elite. Puts the base rate back when the slow lapses — unless an
// owner took the rate meanwhile, in which case that owner restores it (the
// pause watcher on its unpause edge, drop_janitor on reveal) and writing here
// would un-freeze a boss in the middle of a card event.
function slow_elite_expire( until )
{
	self endon( "death" );
	level endon( "end_game" );
	self notify( "tod_eslow_expire" );   // newest slow owns the clock
	self endon( "tod_eslow_expire" );
	d = ( until - GetTime() ) / 1000.0;
	if ( d > 0 )
		wait d;
	if ( !isdefined( self ) || !isalive( self ) )
		return;
	self.tod_eslow_mult  = undefined;
	self.tod_eslow_until = undefined;
	if ( self elite_rate_owned() )
		return;
	self ASMSetAnimationRate( self.tod_elite_base_rate );
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
