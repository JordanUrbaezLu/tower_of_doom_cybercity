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
#using scripts\shared\clientfield_shared;         // dog_fx — the stock ACTOR field
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_ai_dogs;                    // dog_spawn_fx (the arrival burst)

#using scripts\zm\zm_tower_of_doom\_tod_bosses;   // boss_hp / anchor_player / pick_spawn_point / watchers / reward
#using scripts\zm\zm_tower_of_doom\_tod_luck;     // boss LAST-HIT luck
#using scripts\zm\zm_tower_of_doom\_tod_perk_scatter;   // play_sound_at_origin — the temp-emitter lane
#using scripts\zm\zm_tower_of_doom\_tod_spire_data;     // v17.92 — in_spire: a hound is never placed off the island the party is on (leaf module, no cycle)
#using scripts\zm\zm_tower_of_doom\_tod_corpse_cleanup; // v17.92 — corpse_remove: the delete-on-death lane the hound never had (stock-only usings, no cycle)

// THE ARRIVAL BOLT (v17.83). Stock precaches this at _zm_ai_dogs.gsc:31 and it
// is a REAL 53 KB effect, not one of the 298 stub .efx. We precache it AGAIN on
// our side and carry our own `fx,zombie/fx_dog_lightning_buildup_zmb` zone line,
// because a #precache whose asset no zone pulled in resolves to nothing and
// PlayFX no-ops SILENTLY (the v14.20 rampage-spark lesson). The map's `.ff`
// ledger has no fx_dog_* row today — they ride in zm_levelcommon, a fastfile
// this zone cannot see — so relying on that would be relying on something we
// cannot check from here.
#precache( "fx", "zombie/fx_dog_lightning_buildup_zmb" );

// --- cadence: anchored to the round the LAP 30 breather door was bought
// (_tod_doors::breather_unlock stamps level.tod_enemy_unlock_round["hellhound"]),
// then every 3rd round. Never a global grid — a fast climber and a slow climber
// must get the same fight relative to their own unlock. ------------------------
#define TOD_HOUND_INTERVAL       3
// RETIRED v16.87: TOD_HOUND_INTERVAL_DEV 2 (dev no longer changes cadence)
#define TOD_HOUND_MAX_ALIVE      4     // SOLO base since v13.22 — live roof is hound_max_alive() (4 + players/2: 4/5/5/6, so the quad pack of 5 is no longer clamped)

// COMBINED ELITE ROOF. The existing per-type roofs already permit 8 Protectors
// + 1 Panzer + 3 Reavers = 12 live elites, and the v10.4 audit established that
// ~12 starves stock's own 31-actor spawn gate and chokes the horde. A fourth
// type with a roof of 4 would make 16 reachable OUTSIDE the finale, where
// nothing trims zombie_ai_limit. Hounds therefore only ever fill SPARE capacity:
// they may not spawn while 9+ elites already stand. Legal one-directionally —
// this module imports _tod_bosses, never the reverse (the cycle the KB forbids).
// v13.22 (co-op elite scale-up): both roofs are per-player now — the defines
// stay as the SOLO bases. hound_max_alive() = 4+np/2 (4/5/5/6, the quad pack
// of 5 no longer clamps); hound_elite_roof() = 8+np (9/10/11/12). WHY THE
// ELITE ROOF HAD TO MOVE WITH THE OTHERS: elites_alive() counts
// protectors+panzer+reavers+hounds (sprinters deliberately absent — horde
// CONVERSIONS, zero extra actors), and the v13.22 quad worst case is
// 8+1+3 = 12 non-hound elites, which would sit permanently above a flat 9
// and STARVE hounds out of every quad confluence round. 12 is the historical
// reachable line the v10.4 audit measured (the pre-tankiness roofs permitted
// exactly 12); at quad it is brief, elite-kill throughput is four guns, and
// the horde-choke cost is one the map already carried at that line.
// (TOD_HOUND_ELITE_ROOF 9 RETIRED v18.9 — hound_elite_roof() returns the shared
// tod_bosses::elite_roof_all() now, so this had no readers left. The rationale
// block above is kept as the record of why hounds once had a private roof; it
// describes a retired flat-12 world and must not be read as current.)

// --- HP: the same anchored curve every other elite uses, so coop_hp_mult()
// rides in automatically inside boss_hp.
//
// WHY NOT THE LITERAL "5x" THE USER ASKED FOR: a stock hellhound's health is a
// flat stepped table that CAPS AT 1600 and never grows — a dog at round 5 and a
// dog at round 60 both have 1600. So 5x is 8,000 flat, and on this map's
// compounding horde that is 0.91x a TRASH ZOMBIE at round 30 and 0.35x at round
// 40. The literal number would ship an "elite" softer than the horde it spawns
// with, and the LAP 30 door would feel like it unlocked less than LAP 20 did.
// 16,000 on the standard curve kept the user's actual intent — a real threat —
// and landed the hound as the LIGHTEST elite, which is correct for the only one
// that arrives four at a time and outruns a sprinting player.
//
// -30% (user 2026-08-27: "nerf the dogs hellhounds health by 30%"), 16000 ->
// 11200. The curve multiplies off BASE from the anchor, so scaling the base is
// exactly -30% at EVERY round, not just at 30. Post-nerf reads:
//   solo r30  hound 11,200  vs  Reaver 43,178 / Protector 43,497 / Panzer 129,346
//   solo r30  trash zombie 8,788  ->  the hound is ~1.27x a zombie
// Still the lightest elite by far; its threat is the pack + the speed, not the
// pool. THE DIAL: this define alone, -GscOnly.
#define TOD_HOUND_HP_ANCHOR      30
#define TOD_HOUND_HP_BASE        11200
#define TOD_HOUND_HP_EXP         1.09

// THE SPAWN-IN (v17.83, user 2026-09-05: "they should target right away. Also
// they dont have a spawn animation. They just appear ... typically the game has
// an animation of them spawning in"). Seconds of lightning buildup before the
// hound is revealed — stock's own `dog_spawn_fx` waits 1.5; 1.2 keeps the tell
// without making a pack feel late.
#define TOD_HOUND_SPAWN_FX_SECS  1.2

// RETIRED v17.83: TOD_HOUND_SPAWN_HOLD_MS (2500). v17.43 withheld the hound's
// TARGET for 2.5 s to stop 306 throws of `pair '100' and 'undefined'` out of
// behavior_zombie_dog's GetYaw. That worked, and it cost the thing the enemy is
// for: a pack that stands still for three seconds after it lands. The correct
// guard was in stock all along and it is one field, not a timer —
// `ignoreme`. Read behavior_zombie_dog.gsc:378-400 in order:
//
//   :378  if ( ignoreall || pacifist || target invalid )  -> CLEARS favoriteenemy
//   :397  if ( IS_TRUE( ignoreme ) )                      -> plain `return`
//   :412  if ( isdefined( favoriteenemy ) && need_to_run() )   <- THE THROW SITE
//
// `ignoreme` returns from zombieDogTargetService BEFORE need_to_run() — the
// exact call that threw — and unlike `ignoreall` it does NOT wipe the target on
// its way past. So the hound can hold its enemy from the SpawnActor frame and
// still never run the yaw math while it is materialising. Stock reaches the
// same state by a different road (dog_init hides + shields, dog_spawn_fx clears
// ignoreme at the reveal); we do the half we can safely own.
//
// ⚠️ AND THAT SAME LINE :378 IS WHY A WORLD PAUSE COSTS EVERY DOG ITS TARGET:
// set_world_pause writes `ignoreall = true` on every axis AI, and the tree
// answers by clearing favoriteenemy. hound_target_watch re-picks within 0.5 s
// of the unpause, so it recovers — but nothing else in the map does, and that
// is worth knowing before adding another ignoreall writer.

// (TOD_HOUND_PTS 150 team-wide: RETIRED v14.5 — elite payouts are the shared
// killer-only TOD_ELITE_PTS in _tod_bosses::grant_elite_reward; tune it THERE)

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
		tod_quiet_print( "[hound] " + msg );
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

	// [v16.87] Ship cadence in every build — the dev interval is gone (user:
	// dev must not add elites). LOCKSTEP with _tod_bosses / _tod_reaver /
	// _tod_sprinter; the full note is on panzer_due in _tod_bosses.gsc.
	interval = TOD_HOUND_INTERVAL;
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
		// RAMPAGE (v14.20): wave and clamp both scaled, delivery exactly 2x.
		// hound_max_alive() is NOT scaled — the director's standing gate still
		// admits at most 4..6 hounds, and its combined elites_alive() check is
		// likewise untouched. Rampage only lets the pack re-feed for longer.
		m = tod_bosses::elite_mult();
		n = n * m;
		roof = hound_max_alive() * m;
		if ( n > roof )
			n = roof;
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
// v13.25 BOOT FIX (the "hound_max_alive unresolved external" fatal, caught
// by the user on the PUBLISHED build): in v13.22 these two functions were
// inserted ABOVE the #namespace directive. The LINKER accepts that silently,
// but the GAME's loader does not — calls made after `#namespace
// tod_hellhounds;` resolve inside that namespace, and a pre-namespace
// definition never joins it, so every call site was an unresolved external
// and the map fataled at load. It shipped in builds #12 through the publish
// because NO build in that window was ever booted (each battery checked
// deploy-state, not bootability), and lint_tod_arity does not model
// namespace boundaries. RULES: functions go BELOW #namespace, always; and a
// battery is not a boot.
function hound_max_alive()
{
	np = GetPlayers().size;
	if ( np < 1 )
		np = 1;
	return 4 + int( np / 2 );
}

// v18.9 — THE SHARED ROOF, not a private one. This returned 8 + players
// (9/10/11/12), a number tuned against the retired flat 12, while every OTHER
// elite director calls tod_bosses::elite_roof_all(). v18.1 lowered the shared
// roof to 5/7/9/11 as a SOLO RELIEF pass and this function quietly kept solo at
// 9 — about 80% of that pass eroded at solo and 9% at quad, the exact inversion
// of the intent. Hounds also never read level.tod_trial_reserve, so the Wardens'
// first claim did not hold against the one family that most needed it in THE
// KENNEL; going through the shared roof fixes that too.
//
// elite_roof_all() and NOT !elites_over_roof(): that function carries a finale
// exemption, and inheriting it would silently remove the hounds' only combined
// ceiling on the crown road.
//
// TOD_HOUND_ELITE_ROOF is retired with this — grep found it only on its own
// #define line.
function hound_elite_roof()
{
	roof = tod_bosses::elite_roof_all();
	// THE WARDENS' FIRST CLAIM (bug review 2026-09-22, F14): every other
	// director honours level.tod_trial_reserve through elites_over_roof();
	// this one read the bare roof, so KENNEL hounds refilled the slot a fallen
	// or frenzy Warden was waiting for. Subtracted here rather than switching
	// to elites_over_roof, which carries the finale exemption (see above).
	if ( isdefined( level.tod_trial_reserve ) )
		roof -= level.tod_trial_reserve;
	if ( roof < 0 )
		roof = 0;
	return roof;
}

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
		  && level.tod_hound_alive_n < hound_max_alive()
		  && elites_alive() < hound_elite_roof() )
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
	// x elite_hp_mult (v18.2): the -10% elite pass, one owner in _tod_bosses.
	// Scaled HERE and not after level.dog_health is written - that assignment
	// IS the health knob and the reveal clamp reads it (TRAP 1 below), so the
	// reduced number has to be the one it sees.
	hp = int( tod_bosses::boss_hp( rn, TOD_HOUND_HP_ANCHOR, TOD_HOUND_HP_BASE, TOD_HOUND_HP_EXP ) * tod_bosses::elite_hp_mult() );
	if ( hp < 1 )
		hp = 1;

	// Any kind that is not panzer/protector falls through to a random living
	// player — correct here: a pack should not all converge from one bearing.
	target = tod_bosses::anchor_player( "hellhound" );
	if ( !isdefined( target ) )
		return undefined;

	v_ground = tod_bosses::pick_spawn_point( target.origin );
	if ( !isdefined( v_ground ) )
		v_ground = target.origin;
	// v17.92 — NEVER OFF THE ISLAND. Once the party has ascended, the tower is a
	// place no player can ever stand again, so a hound placed there is a slot
	// spent for the rest of the match: it cannot reach anyone, so it never dies.
	// pick_spawn_point filters for this too now; this is the belt over it, and it
	// falls back to the target rather than to nothing.
	if ( IS_TRUE( level.tod_spire_active ) && !( tod_spire_data::in_spire( v_ground ) ) )
		v_ground = target.origin;
	// v17.43 — NEVER ON THE TARGET'S EXACT ORIGIN. The stock dog tree's
	// GetYaw() is VectorToAngles( enemy.origin - self.origin ); a zero vector
	// there hands back undefined and `self.angles[1] - undefined` THROWS,
	// every think tick, until the dog moves. The console log of 2026-09-04
	// carried 306 of exactly that throw, all inside 2 s of a hound spawn.
	// A fallback spawn at the target's own origin is the zero-vector case.
	if ( Distance2D( v_ground, target.origin ) < 8 )
		v_ground += ( 48 * Cos( RandomInt( 360 ) ), 48 * Sin( RandomInt( 360 ) ), 0 );
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
	// v17.92 — THE 306 THROWS, PINNED BY COUNT. Stock behavior_zombie_dog's
	// need_to_run() opens with `self.health < self.maxhealth`, every frame the
	// tree runs. The tree starts at the reveal (TOD_HOUND_SPAWN_FX_SECS, 1.2 s)
	// and hound_tune wrote maxhealth at +2.5 s — so for 1.3 s the compare was
	// `100 < undefined` (100 = the dog's stock default health), which is the
	// exact text of the exception: "pair '100' and 'undefined'", and 1.3 s /
	// 50 ms = the 27-frame runs console_mp.log shows after every spawn. v17.83
	// read it as a yaw and moved the target guard; the count did not move.
	// Stamped HERE, on the spawn frame, before any wait. hound_tune still
	// re-stamps at +2.5 s (stock's reveal clamp order) and level.dog_health was
	// set to hp above SpawnActor, so the clamp is a no-op by construction.
	dog.health                      = hp;
	dog.maxhealth                   = hp;
	dog.ignore_enemy_count          = true;   // exempt from zombie_ai_limit like every elite
	dog.ignore_round_spawn_failsafe = true;   // must precede dog_init's failsafe thread
	dog.ignore_nuke                 = true;
	dog.allow_zombie_to_target_ai   = 0;
	dog.disableAmmoDrop             = true;
	// v17.83 — TARGETED FROM THE SPAWN FRAME, and safe because of the line
	// below it. `ignoreme` is stock's "not in the playable area yet" gate and
	// it returns out of the dog tree ABOVE need_to_run(), which is the only
	// thing that ever threw; it does not wipe favoriteenemy the way `ignoreall`
	// does. See the TOD_HOUND_SPAWN_FX_SECS block for the line numbers.
	// (v17.43's tod_hound_spawn_ms / tod_hound_first_target pair is retired
	// with the hold — the target is simply set, and hound_target_watch's job
	// goes back to being RE-acquisition only.)
	dog.favoriteenemy               = target;
	dog.ignoreme                    = true;   // cleared by hound_spawn_in's reveal
	dog Hide();                               // ...and shown there too

	dog thread hound_spawn_in( v_ground, target );
	dog thread hound_tune( hp );
	dog thread hound_death_watch();
	dog thread hound_target_watch();
	dog thread tod_bosses::tod_boss_stuck_watch();
	// v16.3 (repo review 2026-09-01) — the UPGRADE-PAUSE restore. set_world_pause
	// writes ASMSetAnimationRate( 0.05 ) on every axis AI, hounds included, and
	// leaves the restore to _tod_zombie_speed's sweep — which skips anything
	// carrying is_boss (TRAP 3 above). Panzer, Protector and Reaver each thread
	// this watcher for exactly that reason; the hound was the one elite without
	// it, so any pack alive at a round-4n boundary stayed at 5% speed for the
	// rest of its life, still counted by hounds_alive(), and the director never
	// spawned another ("dog rounds bugged", Workshop 2026-08-29). Rate 1.0 is
	// the dog's own locomotion rate — this only puts back what the pause took.
	dog thread tod_bosses::boss_pause_watch( 1.0 );

	dbg( "spawned hp=" + hp + " round=" + rn + " alive=" + hounds_alive() );
	return dog;
}

// self = the hound. THE ARRIVAL (v17.83) — stock's dog_spawn_fx, rebuilt for a
// map that cannot call it.
//
// WHY NOT JUST CALL dog_spawn_fx: it asserts a magic bullet shield, calls
// util::stop_magic_bullet_shield on an actor that never got one, and runs
// zombie_setup_attack_properties_dog — all of it the tail of dog_init, which
// this map deliberately never runs (Ghosted + shielded + ignoreme, with only
// dog_spawn_fx's own tail to undo it, plus a second death handler fighting
// hound_death_watch). This is the half that is ours to own: the tell, the
// bolt, the shake, and the reveal.
//
// ONE-SHOT FX RIDE A tag_origin HOST. A bare server-side PlayFX draws for
// LOOPING effects only; one-shot bursts need a script_model host and
// PlayFxOnTag (this map's derez_burst_run / zap_burst_run are the proven
// lane). Stock gets away with `Playfx` here because its call sits in a
// different lane entirely — do not copy that line.
//
// NO `level endon( "end_game" )`: the only thing this thread owes the world is
// the Show() and the ignoreme clear, and a hound left hidden and untargetable
// forever is a worse outcome than a stray reveal at the end of a match. The
// `self endon( "death" )` is the one that matters — a hound killed mid-buildup
// is dead either way.
//
// The three `zmb_hellhound_*` aliases are stock's own (the game ships a
// `hellhound` sound loadspec). They are NOT in the mod tools' raw alias CSVs,
// so this is unverified from disk: if a bolt lands in silence, the aliases are
// the first thing to look at, not the fx.
function hound_spawn_in( org, target )   // self = the hound, hidden and ignoreme
{
	self endon( "death" );

	if ( !isdefined( org ) )
		org = self.origin;

	host = Spawn( "script_model", org );
	if ( isdefined( host ) )
	{
		host SetModel( "tag_origin" );
		PlayFxOnTag( level._effect[ "lightning_dog_spawn" ], host, "tag_origin" );
		// The host's lifetime is the LEVEL's, not the hound's (bug review
		// 2026-09-22, F18): `self endon( "death" )` above ends this thread
		// before the Delete at the bottom when the hound dies mid-arrival (a
		// wipe, splash near the spawn), and the entity stayed for the match.
		level thread hound_fx_host_delete( host, TOD_HOUND_SPAWN_FX_SECS + 0.1 );
	}
	tod_perk_scatter::play_sound_at_origin( org, "zmb_hellhound_prespawn", 4 );

	wait TOD_HOUND_SPAWN_FX_SECS;

	tod_perk_scatter::play_sound_at_origin( org, "zmb_hellhound_bolt", 4 );
	tod_perk_scatter::play_sound_at_origin( org, "zmb_hellhound_spawn", 4 );
	Earthquake( 0.5, 0.75, org, 1000 );

	if ( isdefined( self ) && isalive( self ) )
	{
		// Face the enemy on arrival, exactly as stock does — a hound that lands
		// looking away reads as broken even when it turns a frame later. Yaw
		// only; the dog's pitch and roll are its own.
		if ( isdefined( target ) && isdefined( target.origin ) && Distance2D( target.origin, org ) > 8 )
		{
			a = VectorToAngles( target.origin - org );
			self ForceTeleport( org, ( self.angles[ 0 ], a[ 1 ], self.angles[ 2 ] ) );
		}
		// v17.92 — if anything moved us off the island between spawn and reveal,
		// come back to the spot the entrance FX played at. Same in_spire rule as
		// the spawn; a stranded reveal is the whole-match slot leak.
		if ( IS_TRUE( level.tod_spire_active ) && !( tod_spire_data::in_spire( self.origin ) ) )
			self ForceTeleport( org, self.angles );
		self Show();
		self.ignoreme = false;   // the tree's movement service opens here
		self notify( "visible" );
	}
	// (the FX host is deleted by hound_fx_host_delete, on the level's clock)
}

function hound_fx_host_delete( host, secs )
{
	wait secs;
	if ( isdefined( host ) )
		host Delete();
}

// self = the hound. RE-ACQUIRE THE TARGET — the frozen-hound bug (player report
// "dog rounds bugged", 2026-08-30).
//
// favoriteenemy was set ONCE at spawn above and nothing ever refreshed it. The
// dog behaviour tree deliberately does not re-acquire in zombies mode:
// behavior_zombie_dog.gsc:404 guards its own retarget with
// (!SessionModeIsZombiesGame() || team == "allies"), which is always false for
// an axis dog here, and its comment says "zombie mode does this in another
// script". That other script is _zm_ai_dogs::dog_run_think — and IT NEVER RUNS
// ON THIS MAP: it is threaded only from dog_init, which is registered solely at
// _zm_ai_dogs.gsc:147 onto level.dog_spawners, and dog_spawner_init returns
// early because this map has ZERO zombie_dog_spawner ents (we SpawnActor
// directly). So a hound gets the blackboard and nothing else.
//
// The failure: the moment the anchored player stops being valid — last stand
// (stock set_ignoreme), death/spectate, or the ignoreme powerup —
// zombieDogTargetService (behavior_zombie_dog.gsc:378-392) clears favoriteenemy
// and calls SetGoal(self.origin), "stay at the spot". Nothing reassigns it, so
// that hound stands still FOR THE REST OF THE MATCH, even after a revive. In
// solo one down freezes the pack. Worse, frozen hounds are alive, so
// hounds_alive() keeps counting them and once hound_max_alive() are stuck the
// director never spawns another hound again.
//
// This is stock dog_run_think's only load-bearing behaviour, restored. The Rogue
// Protector has had exactly this loop all along (tod_bosses::hunt_players) — the
// hound was the only elite in the map without one.
function hound_target_watch()
{
	self endon( "death" );
	level endon( "end_game" );

	for ( ;; )
	{
		wait 0.5;
		if ( !isdefined( self ) || !isalive( self ) )
			return;
		// v17.83 — the v17.43 spawn hold and its first_target handoff are GONE:
		// spawn_hound sets favoriteenemy on the spawn frame and `ignoreme`
		// keeps the tree off it until the arrival finishes. This loop is back
		// to the one job it was written for — RE-acquisition after the tree
		// drops a target (a down, a spectate, the ignoreme powerup, or any
		// world pause, which clears it via ignoreall).
		// TARGETABLE (2026-09-24, the Zombie Blood report): the tree drops a
		// Zombie Blood target (behavior_zombie_dog.gsc:378-392), and this used to
		// hand the same player straight back every 0.5 s, so the hound stalled
		// on them instead of hunting a teammate. Nobody targetable -> no pick;
		// the next tick re-acquires the moment the window ends.
		if ( isdefined( self.favoriteenemy ) && zm_utility::is_player_valid( self.favoriteenemy, true ) )
			continue;
		t = tod_bosses::pick_target_player( true );
		if ( isdefined( t ) )
			self.favoriteenemy = t;
	}
}

// self = the hound. The pack threads its own health init, so our set has to land
// AFTER it — the same ordering the Reaver documents. The reveal clamp is already
// neutralised by level.dog_health, this is the belt-and-braces re-assert.
function hound_tune( hp )
{
	self endon( "death" );
	level endon( "end_game" );

	// THE EYES AND THE FIRE TRAIL (user 2026-08-30: "lets fix the hell hounds
	// visual issue"). Stock drives BOTH off one 1-bit ACTOR clientfield,
	// "dog_fx", which is ALREADY registered on both VMs and needs nothing from
	// us: server _zm_ai_dogs.gsc:44, client _zm_ai_dogs.csc. Both halves ride in
	// via zm_usermap on their own side, so this adds ZERO new clientfield bits,
	// no .csc change and no .zone line. The client callback does the whole job —
	// eye glow on the eyeball tag, PlayFxOnTag of the fire trail on the spine —
	// and both fx are client-precached in stock and ship in zm_levelcommon.
	//
	// WHY OUR HOUNDS RENDER PLAIN: the ONLY place stock sets this field is
	// _zm_ai_dogs.gsc:937, inside dog_run_think, threaded from dog_init, which is
	// registered ONLY onto level.dog_spawners — and dog_spawner_init returns
	// early because this map has ZERO zombie_dog_spawner ents. Exactly the same
	// root cause as the frozen-hound bug fixed by hound_target_watch().
	//
	// DO NOT "just call dog_init" instead: it Ghosts the actor, gives it a magic
	// bullet shield and sets ignoreme, and the ONLY code that undoes all three is
	// the tail of dog_spawn_fx (_zm_ai_dogs.gsc:346-353), which we never run.
	// dog_init alone = an invisible, invulnerable, non-aggro hound, plus a second
	// death handler fighting hound_death_watch().
	//
	// The 0.5s is courtesy, not a guarantee — stock's own set lands ~1.6s in
	// (it waits on "visible"). If the trail is missing in game, RAISING THIS
	// NUMBER WILL NOT FIX IT; suspect the model tags instead.
	wait 0.5;
	if ( !isdefined( self ) || !isalive( self ) )
		return;
	self clientfield::set( "dog_fx", 1 );
	dbg( "dog_fx set" );

	wait 2.0;
	if ( !isdefined( self ) || !isalive( self ) )
		return;

	// v18.9 — THE RE-STAMP IS GONE, AND 'hp' IS DELIBERATELY STILL A PARAMETER.
	// This used to write 'self.health = hp; self.maxhealth = hp;' here, which by
	// this point is a FULL HEAL of everything the player did in the hound's first
	// ~1.3 s of visible life. It also cleared stock behavior_zombie_dog's
	// damage-driven run flag ('self.health < self.maxhealth'), so a hound you had
	// hurt stopped being flagged "needs to run".
	//
	// It was written to defend dog_run_think's reveal clamp — a clamp that CANNOT
	// RUN on this map, as the block at the top of this file already establishes
	// (no dog spawners; we SpawnActor directly, so dog_init never runs). v17.92
	// then added the spawn-frame stamp before SpawnActor, which made this a belt
	// on a belt.
	//
	// ⚠️ THE HEADERS ABOVE (TRAP 1 / TRAP 3) ARE WRITTEN AS IF dog_init RUNS.
	// A future reader following TRAP 1 will re-add exactly the two lines removed
	// here. It is safe to delete them because level.dog_health is set to the same
	// hp before SpawnActor and the spawn frame stamps maxhealth directly. The
	// parameter stays so the call site keeps documenting what this thread was
	// tuned against.
}

// self = the hound. NOTE: stock dog_death deletes the actor on this same notify,
// so nothing may dereference `self` after the waittill returns.
function hound_death_watch()
{
	level endon( "end_game" );

	source = tod_luck::track_source( self );
	self waittill( "death", attacker );

	// v14.5: killer-only 500 (×2x ×BOUNTY) like every elite. The old "points
	// fountain" worry inverts under killer-only: hounds die in packs, but each
	// head now pays ONE player, so the team-wide multiplication is gone.
	org = source.org;
	if ( isdefined( self ) )
		org = self.origin;   // v18.96: the bottle roll's spot (guarded — dog_death deletes the actor on this notify)
	tod_luck::boss_kill( attacker, "hellhound", org );
	tod_bosses::grant_elite_reward( "HELLHOUND", attacker, org );

	// v17.92 — THE DELETE THE HOUND NEVER HAD. _tod_corpse_cleanup skips the
	// is_boss triad on purpose (the Panzer runs its own death sequence), and
	// until tonight nothing else ever Deleted a hound: every corpse held an
	// actor slot for the rest of the match. console_mp.log 2026-09-05: act=
	// 43 -> 60 in five minutes, then "no free actor entities" every 1-4 s for
	// the remaining eight. corpse_remove is the same lane trash uses:
	// NotSolid, a short linger (or an immediate Ghost when the pool is near
	// the cap), then Delete, re-checking existence at every step.
	if ( isdefined( self ) )
		self thread tod_corpse_cleanup::corpse_remove();
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
