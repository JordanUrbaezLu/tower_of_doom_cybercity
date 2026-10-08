// =============================================================================
// _tod_sprinter.gsc — THE ARMORED SPRINTER: elite #3 of the breather-door
// unlock ladder (user 2026-08-29), NEW enemy — NOT a Reaver replacement (user:
// "i actually wanted to add an anemey rather than replace"). The ladder now:
//   floor 10 Protector / 20 Reaver / 30 ARMORED SPRINTER / 40 hellhounds
// (the sprinter takes the lap-30 slot the hounds held; the hounds move into
// the lap-40 slot that had been reserved-empty since the ladder was built).
//
// ⚠️ THE NAME IS HISTORICAL. Since v14.44 this thing is SLOWER than a plain
// zombie of the same round, not faster (TOD_SPRINT_SPEED_ADD is -10; it was
// +15 when the name was chosen). It is a lumbering armored tank now, and that
// is the intent — the armor and the 10x health are the threat. Nothing
// player-facing carries the word (no hint string, no banner, no LUI text —
// checked), so the name was left alone rather than churning every reference.
// If it reads as a bug to you, it is not: read TOD_SPRINT_SPEED_ADD.
//
// THE SPEC (user, verbatim intent — originally phrased as a Reaver rework,
// re-scoped to a new enemy the same hour):
//   * "a lot of smoke coming from him"      -> two steam-jet FX, spine + head
//   * "run at +15 round speed"              -> tod_zspeed_round_add. THE SIGN
//     HAS SINCE FLIPPED: +15 -> +12 -> +10 -> -10 (user 2026-08-31), so they
//     now run SLOWER than the round, not faster. Read TOD_SPRINT_SPEED_ADD,
//     never this line. (_tod_zombie_speed::apply_speed_for_round reads it)
//   * "come every 3 rounds"                 -> TOD_SPRINT_INTERVAL 3
//   * health: launched as "regular health of a regular zombie" (conversion
//     gives that for free); RETUNED 2026-08-29 after the flood test to
//     TOD_SPRINT_HP_MULT 20 ("Give them 20x health for now") — a SHIP tune,
//     not a dev knob — then HALVED to 10 (v16.60, user 2026-09-02: "nerf the
//     armored sprinters health"). x10 stacks with the 1/3 armor: ~x30
//     effective against EVERY damage source since v14.20 (it was x20 vs
//     melee/explosives while the armor was bullets-only — see
//     TOD_SPRINT_DMG_FRAC). Read the define, never this line.
//   * "bullets do 1/4 damage"               -> level.tod_sprinter_dmg_frac,
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
// Dev preview (user 2026-10-07): ONE armored conversion per round from round
// 1, with no unlock/party/Rampage scaling. It uses the same settled-AI sweep;
// killing it never refills that round's quota. Finale and pause guards remain.
//
// Reference-three welder gear is exclusive to armored sprinters. Promotion
// replaces a recognized intact head with the SAME stock head wearing its new
// kit; the cosmetic helper removes the old helmet and respects native gibs.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_utility;
#using scripts\shared\ai\zombie_utility;
#using scripts\zm\zm_tower_of_doom\_tod_cyber_zombies;

#using scripts\zm\zm_tower_of_doom\_tod_bosses;   // grant_elite_reward (killer-only 500, v14.5)
#using scripts\zm\zm_tower_of_doom\_tod_luck;     // LAST-HIT luck
#using scripts\zm\zm_tower_of_doom\_tod_zombie_speed;   // v18.74 — rampage_horde_mult (leaf module: shared usings only, no cycle)

// --- cadence: anchored to the round the LAP 30 breather door was bought
// (_tod_doors::breather_unlock stamps level.tod_enemy_unlock_round["sprinter"]),
// then every 3rd round. Never a global grid. ---------------------------------
#define TOD_SPRINT_INTERVAL      3
// RETIRED v16.87: TOD_SPRINT_INTERVAL_DEV 2 (dev no longer changes cadence)
#define TOD_SPRINT_MAX_ALIVE     3     // SOLO base since v13.22 — the live roof is sprint_max_alive() (3 + players/2: 3/4/4/5)

// RETUNED SAME DAY (user 2026-08-29, off the first balance table): speed
// +15 -> +12, bullet armor 1/4 -> 1/3. Both SOFTEN the sprinter — the user
// chose this with the "+15 is only ~+4% because the curve is shallow past
// round 15" fact in front of them, so do not "fix" the offset without a fresh
// ask. (One came 2026-08-31 and took it NEGATIVE — see the sign-flip block
// below.) Effective armored HP is now x3 a regular zombie (was x4),
// which keeps the r40 sprinter (~63k) clearly BELOW the r40 Reaver (69.9k
// after its same-day 15k retune) — separation the x4 had lost. Since v14.20
// that ~63k is what MELEE sees too; the melee lane used to read ~21k.
// SIGN FLIPPED v14.44 (user 2026-08-31: "the armored sprinters should actually
// move -10 round speed instead of +10 round speed"). They are now SLOWER than
// the round they appear in, not faster — the armor and the health are what make
// them a threat, and a heavy thing that lumbers reads as heavier than one that
// outruns you. The offset is still an offset, not a multiplier, for the reason
// the block below has always given.
//
// WHAT IT ACTUALLY COSTS THEM, computed against the live constants rather than
// estimated (START_RATE 0.8, FULL_ROUND 18, STEP 0.0028):
//   round 15  0.965 plain ->  0.847      round 20  1.006 -> 0.906
//   round 30  1.034 plain ->  1.006      round 40  1.062 -> 1.034
// The gap narrows with altitude because the curve flattens past round 18, so
// this is a big early nerf and a small late one — the same shape the +15 -> +12
// retune had, and the reason "+N rounds" was chosen over a rate multiplier.
//
// UNDER RAMPAGE THE TABLE ABOVE DOES NOT APPLY — full_round() returns
// TOD_RAMPAGE_FULL_ROUND (10), not 18, so the ramp is steeper and the -10 bites
// harder early: round 15 reads 0.889 and round 20 lands at 1.000. Still no
// degenerate values, but do not quote the 18-based numbers for a rampage run.
//
// NO DEGENERATE VALUES IN A SHIP BUILD: sprinters unlock on the FLOOR-30 door,
// so the earliest realistic appearance is ~round 15 and the floor is 0.847,
// above the live-tested round-1 rate of 0.8. (A dev build with every door
// forced open at round 1 can reach ~0.68 — visibly slow, not broken, and it
// cannot happen in a real match.)
#define TOD_SPRINT_SPEED_ADD     -10   // sprint curve reads (round + this). +15 -> +12 (08-29) -> +10 -> -10 (08-31, sign flip)
// v14.20 (user 2026-08-30: "resistant to all damage not just bullets. Melee is
// too strong against it"): the SAME fraction now scales EVERY damage source —
// bullets, melee, explosives, the blades. Renamed from TOD_SPRINT_BULLET_FRAC
// so the name cannot go on claiming a bullets-only gate that is gone; the
// consumer's MOD test in _tod_upgrades::upgrade_damage_cb went with it.
#define TOD_SPRINT_DMG_FRAC      0.3333  // 1/3 of ALL damage gets through
                                       // (published as level.tod_sprinter_dmg_frac;
                                       // consumed in _tod_upgrades::upgrade_damage_cb)
#define TOD_SPRINT_BODY_MODEL    "tod_cyber_sprinter"   // Same armored donor/rig with baked cosmetic hardware.
#define TOD_SPRINT_HP_MULT       10   // x regular round HP. 20 (user 2026-08-29 "20x health for now") -> 10 (v16.60, user 2026-09-02 "nerf the armored sprinters health")

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

// v17.43 — the smoke fx is PRECACHED here (the server threw "effect ... was not
// precached" on every sprinter until now, so no sprinter has ever smoked) and
// REPOINTED: dlc1/castle/fx_mech_dmg_steam is a 4 KB placeholder that draws
// nothing (see the stub-efx note in memory); fx_steam_hpressure_md_castle is
// the real 70 KB castle steam jet from the same DLC.
#precache( "fx", "dlc1/castle/fx_steam_hpressure_md_castle" );

#namespace tod_sprinter;

function init()
{
	level.tod_sprinter_debt = 0;
	level.tod_armored_test_wait_reason = undefined;
	level.tod_sprinter_dmg_frac = TOD_SPRINT_DMG_FRAC;
	dev_log( "START rev=1 per_round=1 from_round=1 unlock_bypass=1 wave_scaling=0 god=" + IS_TRUE( level.tod_god ) );

	if ( !isdefined( level._effect ) )
		level._effect = [];
	// Already zoned (the Panzer's damage steam) — no new fx zone line needed.
	level._effect[ "tod_sprinter_smoke" ] = "dlc1/castle/fx_steam_hpressure_md_castle";   // v17.43: was the 4 KB stub fx_mech_dmg_steam

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
		{
			dev_wait( "upgrade_pause", -1 );
			continue;
		}

		alive = sprinters_alive();
		if ( alive >= sprint_max_alive() )
		{
			dev_wait( "alive_cap", alive );
			continue;
		}

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
		if ( level.tod_sprinter_debt > 0 )
			dev_wait( "no_eligible_zombie", alive );
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

	// [v16.87] Ship cadence in every build — the dev interval is gone (user:
	// dev must not add elites). LOCKSTEP with _tod_bosses / _tod_hellhounds /
	// _tod_reaver; the full note is on panzer_due in _tod_bosses.gsc.
	interval = TOD_SPRINT_INTERVAL;
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
	// Dev preview includes the CURRENT round, even if the watcher starts after
	// round 1 began. Ship mode retains its unlock-anchored, later-round cadence.
	if ( IS_TRUE( level.tod_dev ) )
		last = -1;
	for ( ;; )
	{
		wait 1;
		r = level.round_number;
		if ( !isdefined( r ) || r < 1 || r == last )
			continue;
		last = r;

		// THE LAST MILE owns the ending (v10.4 rule) — and sprinters have no
		// finale role at all (see header), so no debt accrues under it.
		if ( IS_TRUE( level.tod_finale_aggro ) )
		{
			dev_log( "ROUND_SKIP rev=1 round=" + r + " reason=finale" );
			continue;
		}

		// User 2026-10-07: ONE armored preview each round, including round 1.
		// Replace the quota, never add to it. Bypass unlock/player/rampage wave
		// scaling; the existing director still converts a settled round zombie.
		if ( IS_TRUE( level.tod_dev ) )
		{
			level.tod_sprinter_debt = 1;
			level.tod_armored_test_wait_reason = undefined;
			dev_log( "ROUND_ARM rev=1 round=" + r + " quota=1 alive=" + sprinters_alive() );
			continue;
		}

		n = sprinter_due( r );
		// RAMPAGE (v14.20): wave and clamp both scaled, delivery exactly 2x.
		// sprint_max_alive() itself is untouched, so the conversion sweep's own
		// gate still holds the standing count at 3..5.
		//
		// SPRINTERS ARE THE ONE FREE ELITE: they are CONVERTED horde zombies,
		// not SpawnActor'd, so a sprinter already occupies its AI and actor slot
		// as a zombie and promotion adds ZERO to either count. Doubling them
		// costs nothing in the budget at any roof — the cost is HP (x10 health
		// and a 0.3333 damage fraction), which is pressure, not actors. This is
		// also why the combined elite roof does not gate them.
		m = tod_bosses::elite_mult();
		n = n * m;
		roof = sprint_max_alive() * m;
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
	// no_gib rule). The welder kit preserves head identity and never restores
	// a head that was already removed.
	self SetModel( TOD_SPRINT_BODY_MODEL );
	self tod_cyber_zombies::apply_sprinter_equipment();
	self tod_cyber_zombies::log_sprinter_promotion();
	self.no_gib = true;

	// TOD_SPRINT_HP_MULT x HEALTH — 20 from 2026-08-29 (after the flood test:
	// "Give them 20x health for now", replacing the launch spec's "regular
	// health of a regular zombie"), HALVED to 10 in v16.60 (user 2026-09-02:
	// "nerf the armored sprinters health"). Why a halving and not a trim: v16.3
	// fixed the armor never applying to a player with NO damage upgrade, which
	// tripled what an un-upgraded gun felt overnight (x20 -> x60 effective);
	// x10 puts that baseline player back between the two.
	// Applied to LIVE health so a part-damaged convert keeps its wounds
	// proportionally; maxhealth follows so healthbars and any percent-based
	// logic stay sane. NOTE the STACK: x10 health TIMES the 1/3 armor = ~x30
	// effective against EVERY source since v14.20 (melee and explosives saw a
	// bare x20 while the armor was bullets-only — that gap is exactly what the
	// user's "melee is too strong against it" was reading). The two knobs are
	// TOD_SPRINT_HP_MULT here and TOD_SPRINT_DMG_FRAC above.
	// RAMPAGE (v14.25, user: "all elites and bosses get 1.25x health"). The
	// sprinter is an ELITE but it is the ONLY one that does not come through
	// tod_bosses::boss_hp — it converts a horde zombie and scales the trash HP
	// instead — so the multiplier has to be re-read here. It is the SAME
	// function, not a copied 1.25: one constant, one owner.
	//
	// This lands on top of the x10 and therefore on top of the ~x30 effective
	// noted above, so a rampage sprinter is ~x37.5 (it was ~x75 in the x20
	// era). That is the intended shape of hard mode, but it is still the
	// biggest number in this feature and the first place to look if elites
	// read as spongy. SINCE v14.20 THAT FIGURE IS AGAINST EVERY DAMAGE
	// SOURCE — the armor covers all MODs, so melee sees the same sponge as a
	// bullet. Anyone tuning rampage or spire elite scaling should price that
	// in before adding another multiplier on top.
	// x elite_hp_mult (v18.2, the -10% elite pass). Same argument as the
	// rampage multiplier one line up: the sprinter is an ELITE that never
	// crosses boss_hp, so it re-reads the shared knob rather than carrying a
	// copied 0.90.
	// / rampage_horde_mult (v18.74): the horde zombie this converts ALREADY
	// carries the rampage horde factor from apply_health_scale, and the elite
	// figure above is the whole rampage bump an elite should take. Dividing it
	// out keeps the sprinter at exactly x1.5 under rampage like the other four
	// elites instead of x1.5 x 1.2 = x1.8. Breaker off, both are 1.0.
	hpm = TOD_SPRINT_HP_MULT * tod_bosses::rampage_hp_mult() * tod_bosses::elite_hp_mult() / tod_zombie_speed::rampage_horde_mult();
	self.maxhealth = int( self.maxhealth * hpm );
	self.health    = int( self.health    * hpm );

	// Signed round offset is unchanged. The speed owner selects this actor's
	// arms-down walk immediately, then keeps it through rounds / slow restores.
	// Its guards defer this application during a rise, freeze or native slow.
	self.tod_zspeed_round_add = TOD_SPRINT_SPEED_ADD;
	self tod_zombie_speed::apply_speed_for_round( tod_zombie_speed::current_round() );
	dev_log( "PROMOTED rev=1 round=" + level.round_number + " ent=" + self GetEntityNumber()
		+ " body=" + self.model + " hp=" + self.health + " maxhp=" + self.maxhealth
		+ " debt=" + level.tod_sprinter_debt + " alive=" + sprinters_alive() );

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

	source = tod_luck::track_source( self );
	self waittill( "death", attacker );

	// COOP CRASH GUARD (map 1): the corpse can be reaped the same frame the
	// death notify fires — any self deref then throws and ends the match.
	org = source.org;
	if ( isdefined( self ) )
		org = self.origin;   // v18.96: the bottle roll's spot (guarded — same-frame reap)
	tod_luck::boss_kill( attacker, "sprinter", org );
	tod_bosses::grant_elite_reward( "SPRINTER", attacker, org );   // v14.5: killer-only 500 (×2x ×BOUNTY) + v18.96 bottle roll
}

// Change-only wait records diagnose a queued preview without per-second spam.
function dev_wait( reason, alive )
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	if ( isdefined( level.tod_armored_test_wait_reason ) && level.tod_armored_test_wait_reason == reason )
		return;
	level.tod_armored_test_wait_reason = reason;
	dev_log( "WAIT rev=1 round=" + level.round_number + " reason=" + reason
		+ " debt=" + level.tod_sprinter_debt + " alive=" + alive + " cap=" + sprint_max_alive() );
}

function dev_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	line = "[TOD_ARMORED_TEST] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}
