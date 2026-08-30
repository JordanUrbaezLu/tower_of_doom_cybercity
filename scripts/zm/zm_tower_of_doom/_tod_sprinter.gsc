// =============================================================================
// _tod_sprinter.gsc — THE ARMORED SPRINTER: elite #3 of the breather-door
// unlock ladder (user 2026-08-29), NEW enemy — NOT a Reaver replacement (user:
// "i actually wanted to add an anemey rather than replace"). The ladder now:
//   floor 10 Protector / 20 Reaver / 30 ARMORED SPRINTER / 40 hellhounds
// (the sprinter takes the lap-30 slot the hounds held; the hounds move into
// the lap-40 slot that had been reserved-empty since the ladder was built).
//
// THE SPEC (user, verbatim intent — originally phrased as a Reaver rework,
// re-scoped to a new enemy the same hour):
//   * "a lot of smoke coming from him"      -> two steam-jet FX, spine + head
//   * "run at +15 round speed"              -> tod_zspeed_round_add (12 since
//     the same-day retune; the curve reads round+12 — see the RETUNED block)
//     (_tod_zombie_speed::apply_speed_for_round reads the field)
//   * "come every 3 rounds"                 -> TOD_SPRINT_INTERVAL 3
//   * health: launched as "regular health of a regular zombie" (conversion
//     gives that for free); RETUNED 2026-08-29 after the flood test to
//     TOD_SPRINT_HP_MULT 20 ("Give them 20x health for now") — a SHIP tune,
//     not a dev knob. x20 stacks with the 1/3 bullet armor: ~x60 effective
//     vs bullets, x20 vs melee/explosives.
//   * "bullets do 1/4 damage"               -> level.tod_sprinter_bullet_frac,
//     applied inside _tod_upgrades::upgrade_damage_cb — NOT a second
//     registered callback, because stock's dispatch (_zm.gsc:5822) is
//     FIRST-NON-(-1)-WINS, not a chain: upgrade_damage_cb returns a final for
//     every player hit, so a callback registered after it never runs. Field
//     lane, no import (the cycle rule).
//   * "armored zombie skin ... map 1"       -> SetModel c_t8_zmb_mob_zombie_
//     body3 (the BOTD chain-armor body, map 1 _acc_elites promote_to_shielded)
//     + no_gib so the armor never comes off (map 1's user rule).
//   * "bullets bouncing off"                -> zmb_rocketshield_imp at the
//     victim, 200ms debounce — the same stock alias map 1's Shielded deflect
//     used (_acc_damage.gsc "Shielded deflect").
//
// WHAT CONVERSION BUYS OVER SPAWNING (and what it costs):
//   + native pathing (they ARE horde zombies — no archetype, no behaviour
//     tree, none of the "attacks but never walks" class of failure)
//   + regular health with zero code, exactly as asked
//   + they count toward the round total (a sprinter kill advances the round)
//   - no boss triad, so: no gauge pip (the SMOKE is the tell), GIANT SLAYER
//     does not apply (they are horde-strength, not elites), and nuke /
//     insta-kill treat them as the zombies they are. All accepted.
//   - NO finale role, deliberately: nothing raises sprinter debt during THE
//     LAST MILE and they never occupy a FINALE_BOSS_ROOF slot — the road's
//     pressure stays Panzer/Protector/Reaver/hound, all real elites.
//
// CONVERSION IS A 1s DIRECTOR SWEEP, NOT A SPAWN CALLBACK (v13.9 — the flood
// test caught the callback version converting NOTHING: on_ai_spawned fires
// before zombie_spawn_init sets is_zombie/model/health, so every guard
// rejected every actor and every write would have been clobbered anyway; the
// full record is at init()). The sweep sees only settled actors. The dev
// round-1 flood harness that proved all of this is REMOVED (recipe below the
// defines) — ship state can only raise debt via the lap-30 stamp in
// round_watch, by construction.
//
// HEAD DELIBERATELY NOT SWAPPED (v1 simplification): map 1 detached/attached
// heads tuned to ITS character set; this map's stock zombies wear different
// attached heads, and attaching mob_zombie_head1 without knowing them risks a
// double head. A mismatched stock head on the chain-armor body is cosmetic
// and the smoke carries the read. If it looks wrong in play, port map 1's
// full detach list (_acc_elites.gsc:363-372) with THIS map's head names.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_utility;
#using scripts\shared\ai\zombie_utility;

#using scripts\zm\zm_tower_of_doom\_tod_bosses;   // grant_elite_reward (killer-only 500, v14.5)
#using scripts\zm\zm_tower_of_doom\_tod_luck;     // LAST-HIT luck

// --- cadence: anchored to the round the LAP 30 breather door was bought
// (_tod_doors::breather_unlock stamps level.tod_enemy_unlock_round["sprinter"]),
// then every 3rd round. Never a global grid. ---------------------------------
#define TOD_SPRINT_INTERVAL      3
#define TOD_SPRINT_INTERVAL_DEV  2     // dev: repeats faster for testing
#define TOD_SPRINT_MAX_ALIVE     3     // SOLO base since v13.22 — the live roof is sprint_max_alive() (3 + players/2: 3/4/4/5)

// RETUNED SAME DAY (user 2026-08-29, off the first balance table): speed
// +15 -> +12, bullet armor 1/4 -> 1/3. Both SOFTEN the sprinter — the user
// chose this with the "+15 is only ~+4% because the curve is shallow past
// round 15" fact in front of them, so do not "fix" the offset upward without
// a fresh ask. Effective bullet HP is now x3 a regular zombie (was x4),
// which keeps the r40 sprinter (~63k vs bullets) clearly BELOW the r40
// Reaver (69.9k after its same-day 15k retune) — separation the x4 had lost.
#define TOD_SPRINT_SPEED_ADD     10    // sprint curve reads (round + this). +15 -> +12 (08-29 retune) -> +10 (user, same evening: "the armored will be +10 rounds not 12")
#define TOD_SPRINT_BULLET_FRAC   0.3333  // 1/3 of bullet damage gets through
                                       // (published as level.tod_sprinter_bullet_frac;
                                       // consumed in _tod_upgrades::upgrade_damage_cb)
#define TOD_SPRINT_BODY_MODEL    "c_t8_zmb_mob_zombie_body3"   // zone: xmodel line
#define TOD_SPRINT_HP_MULT       20   // x regular round HP (user 2026-08-29 "20x health for now")

// (TOD_SPRINT_PTS 400 team-wide: RETIRED v14.5 — elite payouts are the shared
// killer-only TOD_ELITE_PTS in _tod_bosses::grant_elite_reward; tune it THERE)

// DEV TEST HARNESS: REMOVED (2026-08-29, user: "remove the dev changes and
// everything for this new enemy... im done testing the armored sprinter") —
// the same remove-don't-disarm doctrine as _tod_main's dev_crown_test. What
// it was, so it can be rebuilt in minutes if the sprinter ever needs live
// verification again (it CAUGHT the dead on_ai_spawned lane, and its
// diagnostics named the working one):
//   * #define TOD_SPRINT_DEV_R1 5, and in post_blackscreen_init (dev only):
//     level.tod_sprinter_debt = TOD_SPRINT_DEV_R1  — floods round 1, no
//     unlock needed; round_watch never re-raises pre-stamp so it fires once.
//   * a max_alive_cap() helper returning DEV_R1 in dev so all five stand
//     (both the round_watch clamp and the director guard read it).
//   * dev-gated IPrintLnBold at three stages: seed / director tick
//     (debt+ai+eligible counts, throttled x5) / converted — the self-naming
//     failure stages that ended the guess cycle.
// CONFIRMED LIVE 2026-08-29 (~3:40am): five converts at round 1 — armor,
// smoke, +12 sprint, 1/3 bullets with red numbers, random ricochets, x20 HP.

#namespace tod_sprinter;

function init()
{
	level.tod_sprinter_debt = 0;
	level.tod_sprinter_bullet_frac = TOD_SPRINT_BULLET_FRAC;

	if ( !isdefined( level._effect ) )
		level._effect = [];
	// Already zoned (the Panzer's damage steam) — no new fx zone line needed.
	level._effect[ "tod_sprinter_smoke" ] = "dlc1/castle/fx_mech_dmg_steam";

	// v13.9 — THE CALLBACK LANE IS GONE, replaced by the director sweep below.
	// WHY (found by the user's round-1 flood test: debt forced to 5, ZERO
	// conversions): callback::on_ai_spawned dispatches BEFORE the spawner's
	// spawn_funcs, and stock zombie_spawn_init (_zm_spawner.gsc:231) is what
	// sets self.is_zombie — so at dispatch time EVERY zombie failed the
	// is_zombie() guard and was silently rejected. The speed module's :169
	// comment records the WRITE half of this ordering (health clobbered); this
	// was the READ half of the same trap, and its own on-spawn application has
	// the same dead guard — it survives only because its 1.5s sweep re-applies.
	// A sweep sees only SETTLED actors (is_zombie set, archetype set, model
	// final), which retires the whole timing class. Do not "optimize" this back
	// to the spawn callback.

	level thread post_blackscreen_init();
}

function post_blackscreen_init()
{
	level endon( "end_game" );

	level flag::wait_till( "initial_blackscreen_passed" );
	wait 3;

	// (The v13.15 TEMPORARY smoke-verification seed was removed with the
	// 2026-08-29 disarm, like the flood harness before it — the linked-host
	// smoke is user-confirmed live.)
	level thread round_watch();
	level thread director();
}

// ---------------------------------------------------------------------------
// THE DIRECTOR SWEEP (v13.9) — drains the debt against SETTLED zombies
// ---------------------------------------------------------------------------
// 1s cadence, the speed keep-alive's proven shape. Converting a zombie that
// has been alive a second (or thirty) instead of at its spawn frame changes
// nothing the player can see except that it WORKS — and it means every guard
// below reads post-zombie_spawn_init state, where is_zombie/archetype/model
// are all final. Skips the upgrade freeze so a conversion never fights the
// pause's anim-rate ownership.
function director()
{
	level endon( "end_game" );

	for ( ;; )
	{
		wait 1;

		if ( !isdefined( level.tod_sprinter_debt ) || level.tod_sprinter_debt <= 0 )
			continue;
		if ( IS_TRUE( level.tod_upgrade_pause ) )
			continue;

		alive = sprinters_alive();
		if ( alive >= sprint_max_alive() )
			continue;

		team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
		a_ai = GetAITeamArray( team );

		for ( i = 0; i < a_ai.size; i++ )
		{
			if ( level.tod_sprinter_debt <= 0 || alive >= sprint_max_alive() )
				break;
			z = a_ai[ i ];
			if ( !eligible( z ) )
				continue;
			level.tod_sprinter_debt--;
			alive++;
			z thread promote_to_sprinter();
		}
	}
}

// A settled, regular, un-promoted horde zombie. All fields are trustworthy
// here BECAUSE the director only ever sees actors past their spawn_funcs.
function eligible( z )
{
	if ( !isdefined( z ) || !isalive( z ) )
		return false;
	if ( !( z zombie_utility::is_zombie() ) )
		return false;
	if ( !isdefined( z.archetype ) || z.archetype != "zombie" )
		return false;
	if ( IS_TRUE( z.is_boss ) || IS_TRUE( z.acc_is_boss ) || IS_TRUE( z.acc_is_mini_boss ) )
		return false;
	if ( isdefined( z.tod_boss_kind ) )
		return false;
	if ( IS_TRUE( z.tod_is_sprinter ) )
		return false;
	return true;
}

// ---------------------------------------------------------------------------
// Cadence — the reaver/protector shape (unlock-anchored, debt SET never summed)
// ---------------------------------------------------------------------------

// Returns how many sprinters this round owes. 0 until the lap-30 breather
// door is bought.
function sprinter_due( round )
{
	if ( !isdefined( level.tod_enemy_unlock_round ) || !isdefined( level.tod_enemy_unlock_round[ "sprinter" ] ) )
		return 0;

	start = level.tod_enemy_unlock_round[ "sprinter" ];
	if ( round < start )
		return 0;

	interval = ( ( IS_TRUE( level.tod_dev ) ) ? TOD_SPRINT_INTERVAL_DEV : TOD_SPRINT_INTERVAL );
	if ( ( ( round - start ) % interval ) != 0 )
		return 0;

	// v13.22 (user 2026-08-29 co-op scale-up, incremental): one per player —
	// 1/2/3/4 (was 1 + players/2 = 1/2/2/3; solo unchanged, the trio/quad
	// plateau removed). The sprint_max_alive() roof still bounds the
	// standing count, so bigger waves trickle in as slots free.
	players = GetPlayers();
	np = players.size;
	if ( np < 1 )
		np = 1;
	n = np;
	return n;
}

// v13.22 — per-player concurrency roof: 3 + players/2 = 3/4/4/5. Solo is
// the old define; both director gates and the wave clamp route through here.
function sprint_max_alive()
{
	np = GetPlayers().size;
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

		// THE LAST MILE owns the ending (v10.4 rule) — and sprinters have no
		// finale role at all (see header), so no debt accrues under it.
		if ( IS_TRUE( level.tod_finale_aggro ) )
			continue;

		n = sprinter_due( r );
		// SET-TO-MAX, NEVER SUM, capped at the roof (v10.4): += banked an
		// unbounded backlog off unfinished waves. A new wave RAISES the debt to
		// its own size at most; the punishment for not clearing one is the
		// sprinters still standing, not a queue.
		roof = sprint_max_alive();
		if ( n > roof )
			n = roof;
		if ( n > 0 && n > level.tod_sprinter_debt )
			level.tod_sprinter_debt = n;
	}
}

// Counted live off the AI list — a stored counter can leak on an engine-side
// Delete and stall conversion at the cap forever (_tod_bosses::protectors_alive
// learned this; same defence here).
function sprinters_alive()
{
	n = 0;
	a_ai = GetAISpeciesArray( "all" );
	for ( i = 0; i < a_ai.size; i++ )
	{
		ai = a_ai[ i ];
		if ( !isdefined( ai ) || !isalive( ai ) )
			continue;
		if ( IS_TRUE( ai.tod_is_sprinter ) )
			n++;
	}
	return n;
}

// ---------------------------------------------------------------------------
// Promotion
// ---------------------------------------------------------------------------
// (The on_ai_spawned claim function that used to live here is DELETED, not
// commented — its entire guard chain ran before zombie_spawn_init and rejected
// every actor; see the init() note. The director sweep above owns the claim.)

// self = the claimed zombie — SETTLED (past spawn_funcs) by construction.
function promote_to_sprinter()
{
	self endon( "death" );

	// No settle-wait any more: the director hands us actors PAST spawn_funcs
	// (that ordering bug is the whole reason the callback lane died — init()).
	if ( !isdefined( self ) || !isalive( self ) )
		return;

	self.tod_is_sprinter = true;

	// THE ARMOR (map 1's Shielded body — the SPIKES + CHAIN-ARMOR one, body3,
	// which map 1's own comment names the Shielded's exclusive look; map 1's
	// no_gib rule). Head untouched — see the header note before "fixing" that.
	self SetModel( TOD_SPRINT_BODY_MODEL );
	self.no_gib = true;

	// 20x HEALTH (user 2026-08-29, after the flood test: "Give them 20x health
	// for now"). REPLACES the launch spec's "regular health of a regular
	// zombie" — "for now" is the user's own marker that this is a test tune.
	// Applied to LIVE health so a part-damaged convert keeps its wounds
	// proportionally; maxhealth follows so healthbars and any percent-based
	// logic stay sane. NOTE the STACK: x20 health TIMES the 1/3 bullet armor =
	// ~x60 effective vs bullets; melee/explosives see x20. Flagged to the user
	// at the time; the two knobs are TOD_SPRINT_HP_MULT here and
	// TOD_SPRINT_BULLET_FRAC above.
	self.maxhealth = int( self.maxhealth * TOD_SPRINT_HP_MULT );
	self.health    = int( self.health    * TOD_SPRINT_HP_MULT );

	// +12 ROUNDS OF SPRINT (retuned from +15 same day). The keep-alive sweep and the next
	// apply_speed_for_round pick the field up — no direct rate write here, the
	// speed module owns the rate (one writer, its own rule).
	self.tod_zspeed_round_add = TOD_SPRINT_SPEED_ADD;

	// THE TELL — smoke ("a lot of smoke", user). v13.15: NOT PlayFxOnTag on
	// the ACTOR — that rendered NOTHING live (user, post-flood-test: "I dont
	// see any smoke on them"), consistent with the map's oldest FX lesson:
	// server-side FX on an AI does not draw in this build (the perk-glow
	// clientfield exists for exactly this reason). Instead, the PROVEN server
	// lane: tag_origin script_model HOSTS linked to the actor, fx played on
	// the host (_tod_teleport's throwaway-host pattern, live-verified
	// nightly). Both hosts link to j_spine4 — a bone map 1 attach-proved on
	// these zombies — one at the spine, one offset up to read as head-height;
	// j_head is NOT risked, because a LinkTo on a missing tag errors the
	// thread and strands an orphan host smoking at the spawn point.
	self thread smoke_host( ( 0, 0, 0 ) );
	self thread smoke_host( ( 0, 0, 24 ) );

	self thread death_watch();
}

// self = the sprinter. One linked smoke host, deleted with its owner — the
// corpse stops smoking on the kill, which is also the kill-confirm read.
function smoke_host( v_off )
{
	level endon( "end_game" );

	h = Spawn( "script_model", self.origin + v_off );
	h SetModel( "tag_origin" );
	h LinkTo( self, "j_spine4", v_off, ( 0, 0, 0 ) );
	PlayFxOnTag( level._effect[ "tod_sprinter_smoke" ], h, "tag_origin" );

	self waittill( "death" );
	if ( isdefined( h ) )
		h Delete();
}

function death_watch()
{
	level endon( "end_game" );

	self waittill( "death", attacker );

	// COOP CRASH GUARD (map 1): the corpse can be reaped the same frame the
	// death notify fires — any self deref then throws and ends the match.
	tod_luck::boss_kill( attacker, "sprinter" );   // LAST HIT takes the luck
	tod_bosses::grant_elite_reward( "SPRINTER", attacker );   // v14.5: killer-only 500 (×2x ×BOUNTY)
}
