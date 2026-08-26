// =============================================================================
// _tod_hellhounds.gsc — THE HELLHOUNDS: elite #3 of the breather-door unlock
// ladder, bought with the LAP 30 breather door (user 2026-08-23: "add
// hellhounds with lots of health").
//
// WHY THIS ENEMY: it is the last complete, unused AI on this machine.
// <TOOLS>\share\raw\behavior ships ELEVEN behaviour trees and every other one
// is already spoken for — mechz = Panzer, zod_robot_companion = Rogue
// Protector, zm_genesis_apothicon_fury = Reaver, the rest are plain zombies,
// and zm_avogadro is a brain with no body. zm_factory_zombie_dog has the full
// chain: .ai_bt / .ai_asm / .ai_am / .ai_ast, an archetype + spawner aitype,
// a character, and a stock driver script (_zm_ai_dogs.gsc) that is ALREADY
// running in this build via zm_usermap.
//
// THIS IS NOT A DOG ROUND, and must never become one. level.dog_rounds_allowed
// stays 0 (zm_tower_of_doom.gsc) — that flag gates ONLY
// zm_usermap -> zm_ai_dogs::enable_dog_rounds(), which is never called here.
// The endless-round twist has no room for a special round; hounds arrive as a
// PACK alongside the horde, the same shape as the Protector and the Reaver.
//
// -----------------------------------------------------------------------------
// FOUR TRAPS, every one verified in stock source. Do not "simplify" past them.
// -----------------------------------------------------------------------------
//  1. level.dog_health IS UNDEFINED IN THIS MAP, AND IT IS THE REAL HP KNOB.
//     zm_ai_dogs::dog_spawner_init returns early when the map has no
//     zombie_dog_spawner entities (ours has none), so its `level.dog_health =
//     100` line never runs. Then dog_init reads `int( level.dog_health * mult )`
//     — an undefined in arithmetic THROWS, and it throws MID-dog_init, before
//     the death handler and the failsafe thread are attached. Half-built enemy,
//     no death event, no reward. Worse, dog_run_think CLAMPS health DOWN to
//     level.dog_health when the dog becomes visible, so even a successful
//     SetHealth is undone ~1.6s later. We therefore set level.dog_health to the
//     hp we want IMMEDIATELY BEFORE SpawnActor, which makes that clamp a no-op
//     by construction instead of a nerf.
//  2. scr_dog_health_walk_multiplier DEFAULTS TO 4.0 (stock, in _zm_ai_dogs).
//     dog_init multiplies by it, and the reveal clamp then erases it. Harmless
//     in play (the dog is ghosted and shielded through that window) but it makes
//     live HP unreadable during a test, so init() pins it to 1.0.
//  3. _tod_zombie_speed's "is_zombie() gates out dogs/specials" COMMENT IS
//     WRONG. dog_init sets self.is_zombie = true, so on_ai_spawned DOES pick a
//     hound up: it would double-dip the co-op health multiplier on top of
//     boss_hp's own coop_hp_mult, and ASMSetAnimationRate the dog's own
//     locomotion. The is_boss / acc_is_boss / acc_is_mini_boss triad plus
//     tod_boss_custom_speed exempt both, and they MUST be set on the SPAWN
//     FRAME — the callback fires one waittillframeend later.
//  4. NEVER CALL zm_ai_dogs::special_dog_spawn(). Its comment advertises
//     "spawn dogs independent of the round", but it discards the spawn point it
//     is handed, two of its three branches index level.dog_spawners[0] on an
//     array this map leaves empty (a silent no-op that spins at the 0.05s
//     floor), its default branch throws on the absent dog_location struct, and
//     it hard-caps at 9. Bare SpawnActor on the spawner_ aitype is the path —
//     the same one _tod_bosses uses for the Rogue Protector.
//
// CLIENT SIDE: nothing to add, deliberately. _zm_ai_dogs.csc already rides in
// via zm_usermap.csc and registers the "dog_fx" clientfield (the eyes + fire
// trail). Adding a #using on the server half only would BREAK the lockstep this
// already has — so we add neither. ZERO new clientfield bits.
// =============================================================================

#using scripts\shared\ai_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_ai_dogs;                    // dog_spawn_fx (the arrival burst)

#using scripts\zm\zm_tower_of_doom\_tod_bosses;   // boss_hp / anchor_player / pick_spawn_point / watchers / reward
#using scripts\zm\zm_tower_of_doom\_tod_luck;     // boss LAST-HIT luck

// --- cadence: anchored to the round the LAP 30 breather door was bought
// (_tod_doors::breather_unlock stamps level.tod_enemy_unlock_round["hellhound"]),
// then every 3rd round. Never a global grid — a fast climber and a slow climber
// must get the same fight relative to their own unlock. ------------------------
#define TOD_HOUND_INTERVAL       3
#define TOD_HOUND_INTERVAL_DEV   2     // dev: repeats faster for testing
#define TOD_HOUND_MAX_ALIVE      4     // concurrency roof for hounds alone

// COMBINED ELITE ROOF. The existing per-type roofs already permit 8 Protectors
// + 1 Panzer + 3 Reavers = 12 live elites, and the v10.4 audit established that
// ~12 starves stock's own 31-actor spawn gate and chokes the horde. A fourth
// type with a roof of 4 would make 16 reachable OUTSIDE the finale, where
// nothing trims zombie_ai_limit. Hounds therefore only ever fill SPARE capacity:
// they may not spawn while 9+ elites already stand. Legal one-directionally —
// this module imports _tod_bosses, never the reverse (the cycle the KB forbids).
#define TOD_HOUND_ELITE_ROOF     9

// --- HP: the same anchored curve every other elite uses, so coop_hp_mult()
// rides in automatically inside boss_hp.
//
// WHY NOT THE LITERAL "5x" THE USER ASKED FOR: a stock hellhound's health is a
// flat stepped table that CAPS AT 1600 and never grows — a dog at round 5 and a
// dog at round 60 both have 1600. So 5x is 8,000 flat, and on this map's
// compounding horde that is 0.91x a TRASH ZOMBIE at round 30 and 0.35x at round
// 40. The literal number would ship an "elite" softer than the horde it spawns
// with, and the LAP 30 door would feel like it unlocked less than LAP 20 did.
// 16,000 on the standard curve keeps the user's actual intent — a real threat —
// and lands the hound as the LIGHTEST elite, which is correct for the only one
// that arrives four at a time and outruns a sprinting player:
//   solo r30  hound 16,000  vs  Reaver 43,178 / Protector 43,497 / Panzer 129,346
//   solo r30  trash zombie 8,788  ->  the hound is just under 2x a zombie
// THE DIAL: drop BASE to 8000 for the literal 5x reading. One define, -GscOnly.
#define TOD_HOUND_HP_ANCHOR      30
#define TOD_HOUND_HP_BASE        16000
#define TOD_HOUND_HP_EXP         1.09

#define TOD_HOUND_PTS            150   // team-wide on death (luck goes to the last hit only)

#namespace tod_hellhounds;

function init()
{
	level endon( "end_game" );

	level flag::wait_till( "initial_blackscreen_passed" );
	wait 3;

	// Trap 2: stock defaults this to 4.0 and the reveal clamp erases it. Pin it
	// so a live HP read means what it says.
	SetDvar( "scr_dog_health_walk_multiplier", "1.0" );

	// Trap 1 crash guard: dog_init does arithmetic on level.dog_health. This is
	// belt-and-braces — spawn_hound() sets it per spawn — but an undefined here
	// throws inside stock code where we have no handler.
	if ( !isdefined( level.dog_health ) )
		level.dog_health = TOD_HOUND_HP_BASE;

	level.tod_hound_debt = 0;
	level.tod_hound_alive_n = 0;

	level thread round_watch();
	level thread director();
}

function dbg( msg )
{
	if ( IS_TRUE( level.tod_dev ) )
		IPrintLn( "[hound] " + msg );
}

// ---------------------------------------------------------------------------
// Cadence
// ---------------------------------------------------------------------------

// How many hounds this round owes. 0 until the lap-30 breather door is bought.
function hound_due( round )
{
	if ( !isdefined( level.tod_enemy_unlock_round ) || !isdefined( level.tod_enemy_unlock_round[ "hellhound" ] ) )
		return 0;

	start = level.tod_enemy_unlock_round[ "hellhound" ];
	if ( round < start )
		return 0;

	interval = ( ( IS_TRUE( level.tod_dev ) ) ? TOD_HOUND_INTERVAL_DEV : TOD_HOUND_INTERVAL );
	if ( ( ( round - start ) % interval ) != 0 )
		return 0;

	// A PACK: solo 3, duo 4, trio 4, quad 5. Hounds are the cheapest elite and
	// the only one that arrives as a group — the pack IS the threat, not the
	// individual.
	players = GetPlayers();
	np = players.size;
	if ( np < 1 )
		np = 1;
	return 3 + int( np / 2 );
}

function round_watch()
{
	level endon( "end_game" );

	last = ( ( isdefined( level.round_number ) ) ? level.round_number : 1 );
	for ( ;; )
	{
		wait 1;
		r = level.round_number;
		if ( !isdefined( r ) || r == last )
			continue;
		last = r;

		// THE LAST MILE owns all boss debts while it runs (same rule as
		// _tod_bosses::round_watch and _tod_reaver::round_watch).
		if ( IS_TRUE( level.tod_finale_aggro ) )
			continue;

		n = hound_due( r );
		// SET-TO-MAX, NEVER SUM, CLAMPED FIRST. `+=` banked an unclearable
		// backlog under endless rounds — the ~30-protector round of the
		// 2026-08-23 playtest. A new pack RAISES the debt to its own size at
		// most; the punishment for not clearing one is the hounds still
		// standing, not a queue behind them. Clamping n BEFORE the compare is
		// what keeps the debt itself under the roof.
		if ( n > TOD_HOUND_MAX_ALIVE )
			n = TOD_HOUND_MAX_ALIVE;
		if ( n > 0 && n > level.tod_hound_debt )
			level.tod_hound_debt = n;
	}
}

// Counted live off the AI list — a stored counter can leak on a pack-side
// Delete and stall the director at the cap forever (_tod_bosses::protectors_alive).
function hounds_alive()
{
	n = 0;
	a_ai = GetAISpeciesArray( "all" );
	for ( i = 0; i < a_ai.size; i++ )
	{
		ai = a_ai[ i ];
		if ( !isdefined( ai ) || !isalive( ai ) )
			continue;
		if ( isdefined( ai.tod_boss_kind ) && ai.tod_boss_kind == "hellhound" )
			n++;
	}
	return n;
}

// Every live elite of every type — the combined-budget guard. Reads the Reaver's
// count through its published LEVEL FIELD, never by importing the module (that
// direction would be the cycle).
function elites_alive()
{
	n = hounds_alive();
	if ( isdefined( level.tod_panzer_alive ) )
		n += level.tod_panzer_alive;
	n += tod_bosses::protectors_alive();
	if ( isdefined( level.tod_reaver_alive_n ) )
		n += level.tod_reaver_alive_n;
	return n;
}

function director()
{
	level endon( "end_game" );

	for ( ;; )
	{
		wait 3;

		// Publish FIRST — _tod_bosses::finale_pressure_loop reads this field.
		level.tod_hound_alive_n = hounds_alive();

		// Never spawn into the upgrade-choice freeze (players are frozen).
		if ( IS_TRUE( level.tod_upgrade_pause ) )
			continue;

		if ( level.tod_hound_debt > 0
		  && level.tod_hound_alive_n < TOD_HOUND_MAX_ALIVE
		  && elites_alive() < TOD_HOUND_ELITE_ROOF )
		{
			e = spawn_hound();
			// Only ever decrement on a LIVE actor — a failed spawn must keep the
			// debt so the next tick retries.
			if ( isdefined( e ) && isalive( e ) )
				level.tod_hound_debt--;
		}
	}
}

// ---------------------------------------------------------------------------
// Spawn
// ---------------------------------------------------------------------------

function spawn_hound()
{
	rn = ( ( isdefined( level.round_number ) ) ? level.round_number : 1 );
	hp = tod_bosses::boss_hp( rn, TOD_HOUND_HP_ANCHOR, TOD_HOUND_HP_BASE, TOD_HOUND_HP_EXP );

	// Any kind that is not panzer/protector falls through to a random living
	// player — correct here: a pack should not all converge from one bearing.
	target = tod_bosses::anchor_player( "hellhound" );
	if ( !isdefined( target ) )
		return undefined;

	v_ground = tod_bosses::pick_spawn_point( target.origin );
	if ( !isdefined( v_ground ) )
		v_ground = target.origin;
	ang = ( 0, RandomInt( 360 ), 0 );

	// TRAP 1. This assignment is the health knob AND the crash guard, and it has
	// to land before SpawnActor: dog_init reads it, and dog_run_think clamps
	// health down to it on reveal. Setting it to hp makes that clamp a no-op.
	level.dog_health = hp;

	dog = SpawnActor( "spawner_zm_factory_zombie_dog", v_ground, ang, "tod_hound", true );
	if ( !isdefined( dog ) )
		dog = SpawnActor( "spawner_zm_factory_zombie_dog", target.origin, ang, "tod_hound", true );
	if ( !isdefined( dog ) )
	{
		dbg( "spawn FAILED (no actor)" );
		return undefined;
	}

	// TRAP 3 — SAME FRAME, before any wait. callback::on_ai_spawned dispatches
	// one waittillframeend from now, and dog_init sets self.is_zombie = true, so
	// _tod_zombie_speed WILL pick this actor up unless the triad is already on
	// it. Without these: the co-op health multiplier double-dips on top of
	// boss_hp's own coop_hp_mult, and the zombie gait override fights the dog's
	// own locomotion.
	dog.is_boss                     = true;
	dog.acc_is_boss                 = true;
	dog.acc_is_mini_boss            = true;
	dog.tod_boss_custom_speed       = true;
	dog.tod_boss_kind               = "hellhound";
	dog.ignore_enemy_count          = true;   // exempt from zombie_ai_limit like every elite
	dog.ignore_round_spawn_failsafe = true;   // must precede dog_init's failsafe thread
	dog.ignore_nuke                 = true;
	dog.allow_zombie_to_target_ai   = 0;
	dog.disableAmmoDrop             = true;
	dog.favoriteenemy               = target;

	dog thread hound_tune( hp );
	dog thread hound_death_watch();
	dog thread tod_bosses::tod_boss_stuck_watch();

	dbg( "spawned hp=" + hp + " round=" + rn + " alive=" + hounds_alive() );
	return dog;
}

// self = the hound. The pack threads its own health init, so our set has to land
// AFTER it — the same ordering the Reaver documents. The reveal clamp is already
// neutralised by level.dog_health, this is the belt-and-braces re-assert.
function hound_tune( hp )
{
	self endon( "death" );
	level endon( "end_game" );

	wait 2.5;
	if ( !isdefined( self ) || !isalive( self ) )
		return;

	self.health    = hp;
	self.maxhealth = hp;
}

// self = the hound. NOTE: stock dog_death deletes the actor on this same notify,
// so nothing may dereference `self` after the waittill returns.
function hound_death_watch()
{
	level endon( "end_game" );

	self waittill( "death", attacker );

	if ( isdefined( attacker ) && isplayer( attacker ) )
		tod_luck::boss_kill( attacker, "hellhound" );

	// Quiet, team-wide, per-unit — hounds die in packs, so a full boss reward
	// per head would be a points fountain.
	tod_bosses::grant_boss_reward( "HELLHOUND", TOD_HOUND_PTS, true );
}
