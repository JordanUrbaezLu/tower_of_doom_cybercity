// =============================================================================
// _tod_reaver.gsc — THE REAVER: elite #2 of the breather-door unlock ladder
// (docs/28). An Apothicon Fury (HB21 pack, already installed for map 1) driven
// as a TOWER ELITE — lighter than the Panzer, additive to the horde, unlocked
// by buying the LAP 20 breather door.
//
// WHY THIS ENEMY (docs/28 §1.2): it is the ONLY fully-formed unused AI on this
// machine. `<TOOLS>\share\raw\behavior\` ships eleven behaviour trees total and
// every other one is either already in use (mechz = Panzer, zod_robot_companion
// = Rogue Protector), a plain zombie, or a brain with no body (zm_avogadro has
// BT + ASM + animtables but its character GDT is gone). Margwa/thrasher/
// direwolf/riotshield have archetype SCRIPTS in share\raw and nothing else.
//
// THE VERB — it erases distance. Everything else on this map has to take the
// stairs behind you; the Reaver BAMFS: a 400–750u instant dash onto its enemy
// every ~4.5–6s. It is NOT a free teleport — the archetype demands mutual 50°
// FOV, both endpoints on the navmesh, a clear `TracePassedOnNavMesh` between
// them AND a successful `FindPath` (archetype_apothicon_fury.gsc:825). On a
// spiral that gates it by construction: a player one flight up has no straight
// navmesh line, so it CANNOT bamf through floors and needs no z-clamp of ours
// (contrast TOD_BOSS_FIRE_ZDELTA, which the ranged bosses do need). What it
// means in play: on the long straight flights and the open breather balconies
// you cannot hold a gap.
//
// SPAWN MECHANISM: the pack's own entry points, NOT a bare SpawnActor —
// `apothicon_fury_meteor_fx()` (sky meteor + ground tell, blocks ~1.5s) then
// `apothicon_fury_spawn()`. That path is map 1's proven one and it carries the
// archetype spawn funcs, so the Reaver arrives with behaviour instead of the
// "attacks but never walks" failure a direct SpawnActor causes.
//
// TRAPS HONOURED (each one already cost the sister map a session):
//  - ignore_enemy_count MUST be set the SAME FRAME as the spawn, never inside
//    the threaded tune (the pack spawns it is_zombie=1; a Reaver alive after
//    the horde clears otherwise counts toward the round).
//  - The pack threads apothicon_fury_health_init() — our HP set has to land
//    AFTER it or the pack's 1.2/1.5/1.7 round tier wins. Hence the wait in
//    reaver_tune().
//  - is_boss / acc_is_boss / acc_is_mini_boss are set SYNCHRONOUSLY on the
//    spawn frame so the frame-N+1 callback::on_ai_spawned speed hook already
//    sees them (map 1's Shielded spawn-order race). Those three fields are what
//    exempt it from the zombie speed curve, SUPPRESSING FIRE, IMPACT ROUNDS
//    splash, Thor's Thunder and the powerup drop roll — all eight consumers
//    read the same triad, so setting them is the whole integration.
//  - ignore_round_spawn_failsafe: the pack threads the stock 30s below-world
//    culler on every fury. The tower goes UP so this is belt-and-braces, but the
//    base arena sits at z≈0 and the check is `< -1000` on ANY actor.
//  - The bamf ghost failsafe lives in the vendored archetype (acc_bamf_ghost_
//    failsafe) — an interrupted bamf can otherwise strand it invisible AND
//    unhittable forever. Do not strip the [acc] tags out of that file.
// =============================================================================

#using scripts\shared\ai_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_utility;
#using scripts\zm\zm_genesis_apothicon_fury;

#using scripts\zm\zm_tower_of_doom\_tod_bosses;   // boss_hp / pick_spawn_point / anchor_player / reward / pause+stuck watchers
#using scripts\zm\zm_tower_of_doom\_tod_luck;     // boss LAST-HIT luck

// --- cadence: anchored to the round the LAP 20 breather door was bought
// (_tod_doors::breather_unlock stamps level.tod_enemy_unlock_round["reaver"]),
// then every 4th round. Never a global grid — a fast climber and a slow climber
// must get the same fight relative to their own unlock. ---------------------
#define TOD_REAVER_INTERVAL      4
#define TOD_REAVER_INTERVAL_DEV  2     // dev: repeats twice as often for testing
#define TOD_REAVER_MAX_ALIVE     3     // concurrency roof — the AI budget must keep
                                       // feeding zombies (endless rounds depend on it)

// --- HP: anchored to a FIXED round constant, exactly like the Protector
// (spawn_protector passes TOD_PROTECTOR_FIRST, not the unlock round) —
// the elite is scaled to the round you are ON, not to how late you unlocked it.
// 20000 -> 15000 (user 2026-08-29: "Make Reaver 15k @r20 instead of 20k", the
// balance pass that landed with the armored-sprinter ladder). New solo curve:
// r20 15k / r30 32.4k / r40 69.9k / r50 150.9k — still above the armored
// sprinter's effective-vs-bullets ceiling at every round (x3 regular HP after
// its same-day 1/3 retune), so the elite stays the bigger threat.
// Co-op rides coop_hp_mult() inside boss_hp. ---------------------------------
#define TOD_REAVER_HP_ANCHOR     20
#define TOD_REAVER_HP_BASE       15000
#define TOD_REAVER_HP_EXP        1.08

// (TOD_REAVER_PTS 400 team-wide: RETIRED v14.5 — elite payouts are the shared
// killer-only TOD_ELITE_PTS in _tod_bosses::grant_elite_reward; tune it THERE)
// (No spawn banner — the whole banner lane was removed 2026-08-22, user:
// "unnecessary". The Reaver's tell is its meteor entrance and the floor
// gauge's boss pip. See the note above _tod_bosses::director.)

#namespace tod_reaver;

function init()
{
	level endon( "end_game" );

	level flag::wait_till( "initial_blackscreen_passed" );
	wait 3;

	level.tod_reaver_debt = 0;

	level thread round_watch();
	level thread director();
}

// ---------------------------------------------------------------------------
// Cadence
// ---------------------------------------------------------------------------

// Returns how many Reavers this round owes. 0 until the lap-20 breather door
// is bought. Mirrors _tod_bosses::protector_due — same unlock-anchored shape.
function reaver_due( round )
{
	if ( !isdefined( level.tod_enemy_unlock_round ) || !isdefined( level.tod_enemy_unlock_round[ "reaver" ] ) )
		return 0;

	start = level.tod_enemy_unlock_round[ "reaver" ];
	if ( round < start )
		return 0;

	interval = ( ( IS_TRUE( level.tod_dev ) ) ? TOD_REAVER_INTERVAL_DEV : TOD_REAVER_INTERVAL );
	if ( ( ( round - start ) % interval ) != 0 )
		return 0;

	// v13.22 (user 2026-08-29 co-op scale-up, incremental): one per player —
	// 1/2/3/4 (was 1 + players/2 = 1/2/2/3). SOLO UNCHANGED — solo must stay
	// fair (the Protector wave was already nerfed once for it). The
	// concurrency roof is untouched; a quad wave trickles in as slots free.
	players = GetPlayers();
	np = players.size;
	if ( np < 1 )
		np = 1;
	n = np;
	return n;
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

		// THE LAST MILE owns all boss debts while it runs (v10.4 — same rule as
		// _tod_bosses::round_watch).
		if ( IS_TRUE( level.tod_finale_aggro ) )
			continue;

		n = reaver_due( r );
		// SET-TO-MAX, NEVER SUM, capped at the concurrency roof (v10.4): += banked
		// an unbounded backlog off unfinished waves — the ~30-protector bug of the
		// 2026-08-23 playtest, in reaver form. A new wave RAISES the debt to its
		// own size at most; the punishment for not clearing one is the reavers
		// still standing, not a queue.
		if ( n > TOD_REAVER_MAX_ALIVE )
			n = TOD_REAVER_MAX_ALIVE;
		if ( n > 0 && n > level.tod_reaver_debt )
			level.tod_reaver_debt = n;
	}
}

// Counted live off the AI list — a stored counter can leak on a pack-side
// Delete and stall the director at the cap forever (_tod_bosses::protectors_alive).
function reavers_alive()
{
	n = 0;
	a_ai = GetAISpeciesArray( "all" );
	for ( i = 0; i < a_ai.size; i++ )
	{
		ai = a_ai[ i ];
		if ( !isdefined( ai ) || !isalive( ai ) )
			continue;
		if ( isdefined( ai.tod_boss_kind ) && ai.tod_boss_kind == "reaver" )
			n++;
	}
	return n;
}

// Debt drains one per tick while under the roof — trickle, never same-frame.
function director()
{
	level endon( "end_game" );

	for ( ;; )
	{
		wait 3;

		// PUBLISH the live count for _tod_bosses::finale_pressure_loop. It reads
		// a level field rather than calling reavers_alive() because THIS file
		// imports _tod_bosses, so an import back would be the cycle the KB
		// forbids. Written here, on the tick that already pays for the count.
		level.tod_reaver_alive_n = reavers_alive();

		// Never spawn into the upgrade-choice freeze (players are frozen).
		if ( IS_TRUE( level.tod_upgrade_pause ) )
			continue;

		if ( level.tod_reaver_debt > 0 && level.tod_reaver_alive_n < TOD_REAVER_MAX_ALIVE )
		{
			e = spawn_reaver();
			if ( isdefined( e ) && isalive( e ) )
				level.tod_reaver_debt--;
		}
	}
}

// ---------------------------------------------------------------------------
// Spawn
// ---------------------------------------------------------------------------

function spawn_reaver()
{
	if ( IS_TRUE( level.tod_upgrade_pause ) )
		return undefined;

	// Any living player — unlike the Panzer (highest) and the wave (lowest),
	// the Reaver has no altitude preference: its whole point is that where you
	// are in the climb does not protect you.
	target = tod_bosses::anchor_player( "reaver" );
	if ( !isdefined( target ) )
		return undefined;

	// Same vetted placement the bosses use: navmesh scatter around the anchor,
	// clear of players and living bosses, and ZONE-GATED so it can never land
	// behind a door the players have not bought.
	v_ground = tod_bosses::pick_spawn_point( target.origin );
	ang      = VectorToAngles( VectorNormalize( target.origin - v_ground ) );
	ang      = ( 0, ang[ 1 ], 0 );

	// The pack's meteor entrance: ground tell + a mover falling from +1000 on
	// the spawn_meteor clientfield, ~1.5s. Deliberately the pack's own function
	// rather than the tower's drop_in() — this one is what the archetype's
	// client FX are authored around, and on an open spiral the streak is
	// visible from floors away, which is exactly the vertical telegraph the
	// map wants.
	zm_genesis_apothicon_fury::apothicon_fury_meteor_fx( v_ground );

	boss = zm_genesis_apothicon_fury::apothicon_fury_spawn( v_ground, ang, 0 );
	if ( !isdefined( boss ) )
		return undefined;

	// --- SAME-FRAME flags. Order matters (see the header). -------------------
	// Round accounting: the pack spawns it is_zombie=1 and never sets this.
	boss.ignore_enemy_count = true;
	// The pack threads the stock below-world culler on every fury.
	boss.ignore_round_spawn_failsafe = true;
	// The boss triad — this is the whole integration with the map's systems.
	boss.is_boss = true;
	boss.acc_is_boss = true;
	boss.acc_is_mini_boss = true;
	boss.tod_boss_custom_speed = true;   // _tod_zombie_speed keep-alive skips it
	boss.tod_boss_kind = "reaver";
	boss.ignore_nuke = true;
	boss.allow_zombie_to_target_ai = 0;
	boss.disableAmmoDrop = true;

	boss thread reaver_tune();
	boss thread death_watch();
	boss thread tod_bosses::boss_pause_watch( 1.0 );
	boss thread tod_bosses::tod_boss_stuck_watch();

	return boss;
}

// Post-spawn tune. MUST run after the pack's threaded apothicon_fury_health_init
// or its round tier overwrites our curve.
function reaver_tune()
{
	self endon( "death" );

	wait 1;
	if ( !isdefined( self ) || !isalive( self ) )
		return;

	// Hunt immediately (the pack only sets this on its own find-flesh path).
	self.zombie_think_done = 1;

	rn = ( ( isdefined( level.round_number ) ) ? level.round_number : 1 );
	hp = tod_bosses::boss_hp( rn, TOD_REAVER_HP_ANCHOR, TOD_REAVER_HP_BASE, TOD_REAVER_HP_EXP );
	self.maxhealth = hp;
	self.health = hp;

	// Gait: always sprint. The horde's exact speed is a per-zombie xanim
	// playback rate owned by _tod_zombie_speed that a different archetype
	// cannot share, so the gait attribute is the right knob here (and
	// tod_boss_custom_speed keeps that module from fighting us for it).
	self ai::set_behavior_attribute( "move_speed", "sprint" );
}

function death_watch()
{
	level endon( "end_game" );

	self waittill( "death", attacker );

	// COOP CRASH GUARD (map 1): the corpse can be reaped the same frame the
	// death notify fires — any self deref then throws and ends the match.
	tod_luck::boss_kill( attacker, "reaver" );   // LAST HIT takes the luck
	tod_bosses::grant_elite_reward( "REAVER", attacker );   // v14.5: killer-only 500 (×2x ×BOUNTY)
}
