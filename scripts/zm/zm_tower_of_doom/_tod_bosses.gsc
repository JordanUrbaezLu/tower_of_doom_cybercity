// =============================================================================
// _tod_bosses.gsc — the two tower bosses: PANZER (Spiki mechz pack) and the
// ROGUE PROTECTOR (HB21 civil-protector re-teamed axis). Ported from map 1's
// _acc_boss_panzer + _acc_civil_protector (user 2026-08-19: "add a panzer to
// the map. And some rogue protector robots every so often... steal this from
// the other map"), condensed to a single de-acc'd driver. NO healthbars.
//
// WHAT KILLING THEM PAYS (v5 luck bar): POINTS to every player (protector
// unit +250 quiet, panzer +1000); LUCK to the LAST HIT ONLY
// (tod_luck::boss_kill — protector +4, panzer +20 on the 0..100% bar).
// THE PANZER OWNS THE MUSIC: his track plays while he lives, the ambient
// loop resumes on his death (tod_atmosphere::boss_track_start/end).
//
// SPAWN MECHANISM (map 1, proven): NO .map spawner entities — both aitypes
// crash them (Radiant bake AND load). Bare SpawnActor at a navmesh-queried
// point near a living player. WHICH player (v9.19, user 2026-08-22): the
// PANZER drops in near the HIGHEST living player, a PROTECTOR wave near the
// LOWEST (anchor_player; replaces the 2026-08-20 "both at the base ring,
// climbing" rule). Both ARRIVE FROM ABOVE via the shared drop_in entrance
// (proxy descent + slam; the real actor is revealed on impact).
//
// MAP 1 TRAPS HONOURED HERE (do not "simplify" these away):
//  - mechz_health_increases() MUST run before each Panzer spawn (HP=undefined
//    crash otherwise) and level.mechz_health must equal the spawn HP.
//  - Panzer SpawnActor targetname must be defined and != "mechz_tomb".
//  - Direct SpawnActor can miss the archetype spawn funcs -> he attacks but
//    never walks; the flameTrigger/is_mechz self-heal below re-runs them.
//  - RP fire loop uses self.weapon, NEVER GetWeapon("...companion...") — the
//    companion AR is not in the level weapon table (the zero-damage bug).
//  - RP landing splash must exclude ALL bosses incl. the lander (the live
//    spawn-die-reward infinite loop of 2026-07-03).
//  - Every boss carries is_boss + acc_is_mini_boss: the vendored
//    zm_zod_robot landing splash and the zombie-speed sweep key off them.
//  - Upgrade-pause: set_world_pause freezes all axis AI (bosses included);
//    boss_pause_watch restores each boss's anim rate on unpause, and every
//    script attack loop gates on level.tod_upgrade_pause.
// =============================================================================

#using scripts\shared\ai\archetype_utility;
#using scripts\shared\flag_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm_powerups;   // specific_powerup_drop (the Panzer's guaranteed Max Ammo)

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;
// get_zone_from_position — a boss must never be placed behind a closed door
// (user 2026-08-21: "Panzer spawned on first set of stairs even though the
// door was not opened"). See the ZONE GATE in pick_spawn_point.
#using scripts\zm\_zm_zonemgr;

#using scripts\zm\mechz_spiki;
#using scripts\zm\zm_zod_robot;

#using scripts\zm\zm_tower_of_doom\_tod_atmosphere;   // boss_track_start/end (Panzer music)
#using scripts\zm\zm_tower_of_doom\_tod_luck;         // boss LAST-HIT luck (user 2026-08-20)
#using scripts\zm\zm_tower_of_doom\_tod_boss_fx;
#using scripts\zm\zm_tower_of_doom\_tod_crown_data;   // in_hall (sealed-crown boss containment)
#using scripts\zm\zm_tower_of_doom\_tod_classes;
#using scripts\zm\zm_tower_of_doom\_tod_upgrades;
#using scripts\zm\zm_tower_of_doom\_tod_upgrade_ui;

// (The "tod_boss_banner" eventstring precache was removed 2026-08-22 with the
// spawn banners themselves — see the note above director(). This module no
// longer calls LuiNotifyEvent at all. If one is ever added back, the precache
// MUST sit here, after ALL #using/#insert directives: between them it kills the
// compile with "No generated data" — live 2026-08-20.)

// --- cadence (user 2026-08-19 final design) ---------------------------------
// PANZER: THE boss — one every 5 rounds (5, 10, 15, ...), with its own music
// (tod_atmosphere::boss_track_start/end — ambient resumes on death).
// ROGUE PROTECTORS: a WAVE every 3 rounds (3, 6, 9, ...), wave size =
// round × 2 (round 3 = 6, round 6 = 12, ...). The debt trickles them in one
// per director tick, and TOD_RP_MAX_ALIVE bounds how many stand at once
// (the engine's AI budget must keep feeding zombies — the endless-rounds
// flow depends on it); the remaining debt spawns as they die.
#define TOD_PROTECTOR_FIRST      3
#define TOD_PROTECTOR_INTERVAL   3
#define TOD_PANZER_FIRST         5
#define TOD_PANZER_INTERVAL      5
// 8 -> 5 (user 2026-08-25). Part of the PROTECTOR TANKINESS PASS below: this
// is both the concurrency roof AND the wave-size cap, so it cuts the late-game
// health pool ~38% on its own and thins how many stand on you at once.
#define TOD_RP_MAX_ALIVE         5     // SOLO base since v13.22 — the live roof is rp_max_alive() (4+players: 5/6/7/8)
// ---- THE LAST MILE: finale pressure (v10, 2026-08-23) ---------------------
// User: "they get ambushed in all directions max aggressivness on spawns and
// all types of enemies. Remember there is a limit on enemies so we dont want
// the game to crash here."
//
// THE CAP IS THE WHOLE PROBLEM, so read this before touching a number.
// Stock sets level.zombie_ai_limit = 24 and level.zombie_actor_limit = 31
// (_zm.gsc:337-343) and gates its OWN spawn queue on both. But our three
// bosses do NOT come from that queue — they are direct SpawnActor calls — so
// they are invisible to the stock gate. Zombies at the 24 ceiling PLUS the
// per-type roofs (1 Panzer + 8 Protectors + 3 Reavers = 12) is 36 actors, well
// past stock's own 31, and nothing in stock would stop it.
//
// So this pass does NOT raise a single limit. It buys aggression two other
// ways, both free of actor cost:
//   1. RATE — the spawn delay drops to its floor, so the 24 zombie slots refill
//      the instant you empty one. Saturation, not a bigger pool.
//   2. VARIETY + DIRECTION — all three boss types cycle instead of waiting for
//      their round multiples, and the causeway risers (gen_tower_map.js) put
//      them on alternating flanks down the road.
// TOD_FINALE_BOSS_ROOF is a COMBINED ceiling across all three types for the
// duration of the run, deliberately far below the sum of their individual
// roofs, so bosses + zombies stays under stock's 31 with headroom.
#define TOD_FINALE_BOSS_ROOF     4     // total live bosses of ALL types during the run
#define TOD_FINALE_PRESSURE_TICK 6     // seconds between top-ups
// PANZER CONCURRENCY ROOF (2026-08-23). He is THE boss — "one every 5 rounds",
// singular, per this module's own header — but the director had NO roof on his
// branch (the Protector branch one line below always had one), and nothing in
// this map or the vendored pack ever despawns or leashes a Panzer. So an
// unkilled Panzer was permanent and the next 5-round mark stacked another on
// top: #2 at r10, #3 at r15, #4 at r20, all alive at once. BOTH dev flags hid
// it perfectly — god meant the count never mattered, dev money meant each one
// died on arrival — so it only became reachable the moment ship state went in.
// level.tod_panzer_alive already existed and was maintained correctly at
// :init/:panzer_life; it was simply READ NOWHERE. This is that roof.
#define TOD_PANZER_MAX_ALIVE     1
// THE LAST MILE: how far AHEAD of the player the Panzer's spawn query anchors.
// 700 is far enough that he materialises down the road rather than on top of
// you (his own clearance in pick_spawn_point is 400/800), and close enough that
// he is a wall you must deal with rather than distant scenery.
#define TOD_PANZER_FRONT_DIST    700
// dev (level.tod_dev): panzer arrives early for test sessions
#define TOD_PANZER_FIRST_DEV     3
#define TOD_PANZER_INT_DEV       3

// --- HP curves (self-contained; anchored at each boss's FIRST round and
// compounding per round; tune here after live play) -------------------------
// Protectors are WAVE units now (round×2 of them) — per-unit HP is far below
// the old solo-boss curve or a wave is an unkillable wall.
// PROTECTOR TANKINESS PASS (user 2026-08-25: "People are complaing they are
// too tanky"). Measured before the change, solo, with a tier-appropriate PaP'd
// gun and perfect body-shot uptime: a wave took 17.3s at round 18 and 22.2s at
// round 24, against a PANZER at 6.9s and 7.4s. So the mini-boss outlasted the
// boss by 2.5-3x while arriving every 3 rounds instead of every 5.
//
// THE ROOT CAUSE WAS DOUBLE COMPOUNDING, and it is worth naming so nobody
// "fixes" this by moving one number again: per-unit HP compounds per round AND
// the wave size grows with the round. Those multiply. Dropping the base alone
// would have gutted rounds 3-9 (which measured fine, 1.0-1.5x a Panzer) and
// still left round 30 absurd; dropping the exponent alone leaves the early
// waves untouched but takes longer to bite. All four levers moved together:
//   base 7000 -> 4000, exponent 1.07 -> 1.05 -> 1.04 -> back to 1.05 (user,
//   TOD_RP_MAX_ALIVE 8 -> 5, and the wave count x0.8 (see rp_wave_size).
#define TOD_PROTECTOR_HP_BASE    4000    // at round 3, per unit
#define TOD_PROTECTOR_HP_EXP     1.05
#define TOD_PANZER_HP_BASE       15000   // at round 5 (user 2026-08-23: "that should be 15k";
                                        // was 25000, and 24000 before that)
#define TOD_PANZER_HP_EXP        1.08    // per-round compound from the round-5 anchor — map 1's Panzer
                                        // exponent was 1.09; 1.075 fell behind the horde. 1.09 -> 1.08
                                        // (user 2026-08-25) in the same pass that set the Protector to
                                        // 1.05 — the two elites are tuned against each other, so read
                                        // them together and re-measure BOTH if either moves.
                                        // Solo at 1.08: r5 15k / r10 22k / r20 47k / r30 102k / r40 221k
                                        // / r50 477k (zombies still compound faster, at 1.10);
                                        // co-op x1.7 / 2.3 / 2.6 via coop_hp_mult().
                                        // NOTE the effective TTK is higher than the raw number: body
                                        // hits are scaled to TOD_PANZER_BODY_SCALE 0.35 and the head to
                                        // 0.9, so r5 is ~43k of body damage or ~17k of faceplate.

// --- Panzer feel (map 1's live-tuned values, dvars folded to constants) -----
#define TOD_PANZER_ANIM_RATE     1.0   // BASE speed (user 2026-08-20: "too fast, put them back at base")
#define TOD_PANZER_BODY_SCALE    0.35  // stock scales body hits to 0.1 — rebuff
#define TOD_PANZER_HEAD_SCALE    0.9
// (the faceplate radius moved to TOD_FACEPLATE_RADIUS in _tod_upgrades.gsc
// 2026-08-24 — headshot_kind() is the single owner of "is this a head hit" now,
// so the two lanes cannot drift apart. Nothing here should re-declare it.)
// Mirror of LOC_NORM in tools/gen_tod_twins.js — every generated gun ships
// locHead/locHelmet/locNeck 3.0. Used ONLY to re-apply the head multiplier on a
// Panzer faceplate hit, which the engine classified as torso_upper and so
// multiplied by 1.0. See tod_mechz_damage_wrap. Keep in lockstep with LOC_NORM.
#define TOD_LOC_HEAD_NORM        3.0
#define TOD_PANZER_ZAP_RADIUS    220   // electroball slow radius

// --- Rogue Protector feel (map 1's values NERFED ~25% + slowed — user
// 2026-08-19 live test: "too good") ------------------------------------------
// 3.6 -> 4.5 (user 2026-08-25: "nerf the protectors max range, bullet damage,
// and fire rate by 20%. He is a bit op when he keeps shooting"). A 20% slower
// RATE is the interval divided by 0.8, not multiplied by it: 3.6 / 0.8 = 4.5.
// Second cut of this size — it was 3.0 before 2026-08-20 — so he now fires at
// 64% of his original cadence.
#define TOD_RP_FIRE_INTERVAL     4.5
// 1500 -> 1200 (-20%, user 2026-08-25). This is the hard "will not shoot past
// this" gate at :1623, i.e. his max range. TOD_RP_FAR_RANGE (1000, where the
// close-range bonus has fully decayed) is deliberately NOT scaled with it: it
// still sits inside the new max, so the falloff curve keeps its shape and the
// last 200 units are flat 1x damage.
#define TOD_RP_FIRE_RANGE        1200
#define TOD_RP_MAHEM_COOLDOWN    3.5   // was 3.0
#define TOD_RP_BULLET_DMG        12    // -20% (user 2026-08-25); was 15, and 21 before 2026-08-20
// 32 -> 26, AND THIS ONE WAS NOT ASKED FOR — it is what makes the asked-for
// bullet nerf actually land. Damage is BULLET_DMG x mult (3x inside 150 units,
// decaying to 1x by 1000) and is then CLAMPED here. At the new 12 damage the
// close-range product is 12 x 3 = 36, still over the old cap of 32 — so cutting
// BULLET_DMG alone would have changed point-blank damage by exactly nothing,
// which is the range he was reported oppressive at. Scaling the cap by the same
// 20% makes the nerf uniform: ~-19% close, -20% mid, -20% far.
#define TOD_RP_MAX_DMG           26    // -20% (user 2026-08-25); was 32, 45 before 2026-08-20
#define TOD_RP_CLOSE_MULT        3.0
#define TOD_RP_CLOSE_RANGE       150
#define TOD_RP_FAR_RANGE         1000
#define TOD_RP_MAHEM_DMG         52    // was 69 (-25%)
#define TOD_RP_ANIM_RATE         0.85  // user 2026-08-20: "slow down the protectors a bit more" (was 1.0)
#define TOD_RP_KNOCKBACK         200
#define TOD_RP_MAHEM_KNOCKBACK   400
#define TOD_RP_ZAP_INTERVAL      3.0
#define TOD_RP_ZAP_RANGE         250
#define TOD_RP_PULSE_DMG         7     // was 10 (-25%)
// (zap slow defines removed 2026-08-20 — no player stuns on this map)
// ELECTROBALL ("the zap"). HALVED 2026-08-23 (user: "He threw his zaps and i
// died in 2 hits. Lets cut that in half damage as well"): 1.1 -> 0.55.
//
// THE ARITHMETIC, because the per-ball number alone is misleading. The GDT
// (mechz_spiki.gdt "electroball_grenade_zm") does a FLAT 45 anywhere inside a
// 200u radius — explosionInnerDamage and explosionOuterDamage are both 45, so
// there is no falloff to hide behind. Applied damage = 45 x this x
// TOD_PANZER_DMG_MULT, and the player base is TOD_UPG_BASE_HP 150:
//     was  45 x 1.1  x 0.5 = 24/ball
//     now  45 x 0.55 x 0.5 = 12/ball
// But he throws a BURST OF THREE (stock MECHZ_GRENADE_BURST_SIZE 3, up to 9
// active, 6s between bursts) and electroball_bounce_detonate() — OUR addition —
// pops each one on its first bounce instead of letting it fuse, so all three
// land clustered at your feet. The real unit is therefore the BURST:
//     was  72/burst -> TWO bursts = 144 vs 150 HP = the user's 2-hit death
//     now  36/burst -> four-plus bursts, i.e. 24s+ of sustained exposure
// If it still bites, the next lever is the burst clustering, not this number.
#define TOD_PANZER_EXPLOSIVE_MULT 0.55 // was 1.1 (map 1 user 2026-07-18 +10%)
// PANZER DAMAGE NERF EASED 0.5 -> 0.6 (user 2026-08-24: "Previously we nerfed
// the panzers moves by 50% or something. Lets change that too 40%. So its a
// slight buff on the panzer"). A 40% cut instead of a 50% one, i.e. +20% on
// every number he actually deals.
//
// IT REACHES THE ELECTROBALL TOO, and that is the one to watch: the ball is
// 45 x TOD_PANZER_EXPLOSIVE_MULT x this, so the burst-of-three goes
// 36 -> 44 per burst against a 150 HP player (see the arithmetic above). Still
// four bursts to kill, where the 2-hit death that triggered the original nerf
// was 144 per two bursts. If the zaps start biting again, the next lever is the
// burst clustering (electroball_bounce_detonate), not this constant.
#define TOD_PANZER_DMG_MULT       0.6  // 0.5 -> 0.6 (user 2026-08-24); was "halve ALL panzer damage" 2026-08-20
#define TOD_BOSS_FIRE_ZDELTA     300   // boss ranged attacks only within ~1 floor of height (no through-floor sniping)

// --- spawn placement --------------------------------------------------------
#define TOD_BOSS_CLEARANCE       150   // min distance from every living boss
#define TOD_XMAS_PANZER_SHOTS    20    // Gift of Death shots to kill a Panzer (user 2026-08-21, was 30)
#define TOD_XMAS_RP_SHOTS        6     // ...and a Rogue Protector (user 2026-08-21, was 10)
// v14.8 (user 2026-08-30: "buff the death machine by 30% for bosses and
// elites") — multiplies the per-shot slice at both sites below, so the shot
// counts above stay the readable historical baseline (effective: Panzer
// ~15.4 -> 16 shots, RP ~4.6 -> 5). LOCKSTEP: must equal XMAS_ELITE_BUFF in
// _tod_powerups.gsc, which owns the Reaver/hellhound Gift lanes.
#define TOD_XMAS_ELITE_BUFF      1.3
#define TOD_BOSS_ZONE_CHECKS     12    // max get_zone_from_position calls per spawn pick (each spawns a temp entity)
#define TOD_BOSS_PLAYER_CLEAR    100   // min distance from every player
// DROP-IN ENTRANCE (v9.19, user 2026-08-22: "the spawn in animations need to
// be implemented"). A script_model PROXY wearing the boss's own model (+ his
// attachments) descends on the zod sky-trail FX and slams down; the REAL
// actor is spawned first at the landing point — ghosted, undamageable, goal
// pinned, anim rate frozen — and is revealed on impact. Deliberately NO scene
// bundles: the pack's cin_zm_castle_mechz_entrance needs a .map spawner
// (crashes this map) and the zod entrance scene spawns a duplicate frozen
// robot (map 1, live). No new assets either — every FX/sound below is already
// precached by the vendored zm_zod_robot.gsc and was used by the old RP
// slam-down.
#define TOD_DROP_H_MAX           320   // max fall height — the lap above is LAP_RISE 384u up
#define TOD_DROP_H_MIN           120   // less clear air than this: no descent, just the slam
#define TOD_DROP_SECS            0.8   // proxy fall time (accelerating)
#define TOD_DROP_TELL_SECS       2.0   // ground-tell FX lead-in before impact
// RELOCATION LANDING (user 2026-08-30: "occassionally elites and boss will
// randomly spawn at you when you are too far away"). pick_spawn_point's ONLY
// player filter is TOD_BOSS_PLAYER_CLEAR = 100 — arm's reach — and its last
// resort is `return anchor;`, the player's own origin. 450 is deliberately just
// above pick_spawn_point's 400-unit pass-0 radius, so a rejected roll falls
// through to its wider 800-unit pass instead of re-rolling the same ring.
#define TOD_RELOC_MIN_DIST       450

// --- rewards (v14.5, user 2026-08-30: "elites give 500 on kill. Only the
// person who kills gets the money. The payout is still effected by double
// points and bounty upgrade"):
//   ELITES (Protector / Reaver / Hellhound / Sprinter) — TOD_ELITE_PTS to the
//   KILLER ONLY, scaled by double points + the BOUNTY domain; one shared
//   number, one function (grant_elite_reward). The old per-module team-wide
//   values (RP 250 / Reaver 400 / Hound 150 / Sprinter 400) are RETIRED.
//   PANZER — he is the BOSS, not an elite: keeps the 1000 team-wide jackpot.
// LUCK is separate everywhere: last hit only, values in _tod_luck.gsc
// (TOD_LUCK_PROTECTOR / TOD_LUCK_PANZER). --------------------------------------
#define TOD_ELITE_PTS            500
#define TOD_PANZER_PTS           1000

#namespace tod_bosses;

function init()
{
	level endon( "end_game" );

	level flag::wait_till( "initial_blackscreen_passed" );
	wait 3;

	level.tod_protector_debt = 0;
	level.tod_panzer_debt = 0;
	level.tod_panzer_alive = 0;

	// Seed the mechz pack's health-scaler base fields ONCE (map 1 recipe —
	// mechz_health_increases() reads all of these and THROWS on undefined).
	level.mechz_base_health          = 4000;
	level.mechz_health_increase      = 250;
	level.var_fa14536d               = 1500;    // faceplate base
	level.var_1a5bb9d8               = 100;     // faceplate per-round increase
	level.mechz_powercap_cover_health = 750;    // read-modify-write — pre-seed
	level.var_a1943286               = 50;      // powercap-cover increase
	level.mechz_powercap_health      = 500;     // read-modify-write — pre-seed
	level.var_9684c99e               = 50;      // powercap increase
	level.var_3f1bf221               = 350;     // knee/shoulder armor base
	level.var_158234c                = 25;      // armor increase
	level.var_f4dc2834               = 3062.5;  // Thundergun clamp (load-bearing
	                                            // only if a thundergun ever ships
	                                            // — seeded anyway, it is inert)

	// The vendored mechz melee callback reads level.acc_god (map 1's demigod
	// flag — damage floors the player at 1 HP). Bridge the tower's dev god.
	level.acc_god = IS_TRUE( level.tod_god );

	// Player-mitigation hook for the vendored mechz melee callback — a LEVEL
	// FUNCTION POINTER, not a #using (the KB cycle rule: mechz_spiki must
	// never import this module back while we import it).
	level.tod_player_mitigations_fn = &apply_player_mitigations;

	// RP bullet/rocket lanes + the tower demigod clamp (see the function).
	zm::register_player_damage_callback( &boss_player_damage );

	level thread round_watch();
	level thread director();
	level thread electroball_watch();
}

// Boss diagnostics. NO ON-SCREEN TEXT (user 2026-08-21: "there is text on the
// screen when panzer spawns — remove that"). Dev mode is armed, so the old
// dev-gated IPrintLnBold was printing every boss event to the HUD; the map
// standing rule is no floaty gameplay text at all. Kept as a call-site no-op
// so every existing dbg() line stays valid and can be re-pointed at a log
// later without touching them.
function dbg( msg )
{
}

// ---------------------------------------------------------------------------
// Cadence — debt-based (map 1's director pattern): round_watch adds this
// round's owed spawns, director spends one per ~3s tick, a failed spawn
// leaves the debt untouched and retries.
// ---------------------------------------------------------------------------

// Rogue Protectors: every 3rd round owes a WAVE. Size = round( players/3 ×
// round ) to the nearest whole (user 2026-08-20: "too many on solo"). Solo
// r3=1/r6=2/r9=3; duo r3=2; quad r3=4. Never below 1 on a due round.
// v13.22 (user 2026-08-29: "coop scale appropriately... more elites for more
// players", incremental): the protector roof is per-player — 4+np = 5/6/7/8.
// Solo is BYTE-UNCHANGED (5, the tankiness-pass value); a full lobby returns
// to the pre-tankiness 8, which the actor-budget note above already carried.
// Both live consumers (the wave clamp and the director's standing gate) go
// through this; the define stays as the documented solo base.
function rp_max_alive()
{
	np = GetPlayers().size;
	if ( np < 1 )
		np = 1;
	return 4 + np;
}

function protector_due( round )
{
	// ENEMY UNLOCK GATE (user 2026-08-21: "it gets harder the higher you go —
	// every breather door you open introduces a new enemy type; first is the
	// protector"). Protectors do not exist until the FIRST breather door is
	// bought; the wave cadence then anchors to THAT round, so they arrive on
	// the round you open it and every 3rd round after — not on the global
	// round-3 grid. level.tod_enemy_unlock_round is stamped by
	// _tod_doors::breather_unlock when the flag sets.
	if ( !isdefined( level.tod_enemy_unlock_round ) || !isdefined( level.tod_enemy_unlock_round[ "protector" ] ) )
		return 0;
	start = level.tod_enemy_unlock_round[ "protector" ];
	if ( round < start )
		return 0;
	if ( ( ( round - start ) % TOD_PROTECTOR_INTERVAL ) != 0 )
		return 0;
	players = GetPlayers();
	np = players.size;
	if ( np < 1 )
		np = 1;
	// x0.8 = the "reduce counts that spawn per wave by like 20%" half of the
	// 2026-08-25 tankiness pass (comment continues below). Applied to the RAW np*round/3 figure BEFORE the
	// TOD_RP_MAX_ALIVE clamp below, so it thins the mid rounds (where the wave is
	// still under the roof) and the clamp keeps owning the late ones.
	n = int( ( np * round ) / 3.0 * 0.8 + 0.5 );
	if ( n < 1 )
		n = 1;
	// WAVE CAP (playtest 2026-08-23: "I saw like 30 on round 18"): np*round/3
	// is unbounded — a duo at round 18 rolls a 12-wave, a quad 24. No wave may
	// ask for more than the concurrency roof can even stand up at once.
	roof = rp_max_alive();
	if ( n > roof )
		n = roof;
	return n;
}

// SPAWN ANCHOR (v9.19, user 2026-08-22): the PANZER arrives near the HIGHEST
// living player, a PROTECTOR near the LOWEST. (Was: both at a base-ring
// point, climbing the spiral — user 2026-08-20, superseded.) Height = origin
// z: on the spiral, z IS "how far up the climb". Any other kind = a random
// living player. undefined when nobody is valid (downed players excluded by
// is_player_valid — never anchor a boss on a body).
function anchor_player( kind )
{
	if ( kind != "panzer" && kind != "protector" )
		return pick_target_player();
	best = undefined;
	best_z = 0;
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !zm_utility::is_player_valid( p ) )
			continue;
		z = p.origin[ 2 ];
		if ( !isdefined( best )
		  || ( kind == "panzer" && z > best_z )
		  || ( kind == "protector" && z < best_z ) )
		{
			best = p;
			best_z = z;
		}
	}
	return best;
}

// Clear air above a landing point, capped at TOD_DROP_H_MAX (on the spiral
// the lap above sits ~384u up; a breather is no taller).
function drop_clearance( v_ground )
{
	start = v_ground + ( 0, 0, 24 );
	end   = v_ground + ( 0, 0, 24 + TOD_DROP_H_MAX );
	tr = BulletTrace( start, end, false, undefined );
	h = TOD_DROP_H_MAX;
	if ( isdefined( tr ) && isdefined( tr[ "fraction" ] ) )
		h = tr[ "fraction" ] * TOD_DROP_H_MAX;
	return h;
}

// GROUND SNAP (v13.3, user live report 2026-08-28: "the protector will
// sometimes spawn in the floor"). The navmesh over the spiral's flights is a
// SMOOTHED RAMP through the treads, so a PositionQuery point mid-flight sits
// up to a tread-height BELOW the step top — and both spawners place the actor
// at the query point verbatim, burying his feet in the step. (Landings and
// the road are flat, which is why it is "sometimes".) Trace from knee height
// down past a full step: the first solid IS the walk surface; stand him ON
// it. A point already on flat ground round-trips unchanged (+1u).
function ground_snap( v )
{
	tr = BulletTrace( v + ( 0, 0, 48 ), v - ( 0, 0, 96 ), false, undefined );
	if ( isdefined( tr ) && isdefined( tr[ "fraction" ] ) && tr[ "fraction" ] < 1 && isdefined( tr[ "position" ] ) )
		return ( v[ 0 ], v[ 1 ], tr[ "position" ][ 2 ] + 1 );
	return v;
}

// Ground-tell FX at the landing point for `secs`. Own model + own timer: the
// vendored zod_robot_spawn_fx retires on a LEVEL notify ("robot_landed"),
// which a concurrent entrance (Panzer + wave unit) would trip early.
function tell_fx( v_ground, secs )
{
	level endon( "end_game" );
	e = Spawn( "script_model", v_ground );
	e SetModel( "tag_origin" );
	PlayFXOnTag( level._effect[ "robot_ground_spawn" ], e, "tag_origin" );
	wait secs;
	if ( isdefined( e ) )
		e Delete();
}

// THE ENTRANCE. boss = a freshly spawned, fully set-up actor standing at
// v_ground. Returns true once he is revealed and live; false if he vanished
// mid-fall (pack-side Delete) — the caller must treat that as a failed spawn.
// While the proxy falls the real actor is: invisible (Ghost), undamageable
// (no shooting an invisible boss), ignoreall + goal pinned (he cannot wander
// off the mark) and anim-frozen (the same freeze the upgrade pause uses).
// If the upgrade pause starts mid-fall he stays frozen on impact —
// boss_pause_watch, which the caller threads right after, restores him on the
// unpause edge (its first tick re-applies the freeze, then watches).
function drop_in( boss, v_ground, ang, base_rate, b_relocate )
{
	boss Ghost();
	// b_relocate = a LIVE boss being un-stranded by tod_boss_stuck_watch, not a
	// fresh spawn. The watcher used to ForceTeleport BARE — no entrance, no FX,
	// no ground_snap — and pick_spawn_point can legally land him 100 units from
	// your face. Ghosted first, so the fall IS the arrival. Every caller that
	// omits this argument gets undefined, so the shipped spawn path is unchanged.
	if ( IS_TRUE( b_relocate ) )
		boss ForceTeleport( v_ground, ang );
	boss SetCanDamage( false );
	boss.ignoreall = true;
	boss ASMSetAnimationRate( 0.05 );
	boss SetGoal( v_ground, true );
	boss.tod_dropping = true;

	h = drop_clearance( v_ground );
	level thread tell_fx( v_ground, TOD_DROP_TELL_SECS );

	proxy = undefined;
	trail = undefined;
	if ( h >= TOD_DROP_H_MIN )
	{
		proxy = Spawn( "script_model", v_ground + ( 0, 0, h - 16 ) );
		proxy SetModel( boss.model );
		proxy.angles = ang;
		// His attachments (armor plates, faceplate, head) ride along — a bare
		// body would read as a stripped boss for the whole fall.
		n = boss GetAttachSize();
		for ( i = 0; i < n; i++ )
			proxy Attach( boss GetAttachModelName( i ), boss GetAttachTagName( i ) );
		trail = Spawn( "script_model", proxy.origin );
		trail SetModel( "tag_origin" );
		PlayFXOnTag( level._effect[ "robot_sky_trail" ], trail, "tag_origin" );
		trail LinkTo( proxy );
		proxy PlayLoopSound( "fly_civil_protector_loop" );
	}

	lead = TOD_DROP_TELL_SECS - TOD_DROP_SECS;
	if ( lead > 0 )
		wait lead;
	if ( isdefined( proxy ) )
		proxy MoveTo( v_ground, TOD_DROP_SECS, TOD_DROP_SECS * 0.6, 0 );
	wait TOD_DROP_SECS;

	// impact
	if ( isdefined( trail ) )
		trail Delete();
	if ( isdefined( proxy ) )
	{
		proxy StopLoopSound();
		proxy Delete();
	}
	if ( !isdefined( boss ) || !isalive( boss ) )
		return false;

	boss.tod_dropping = undefined;
	boss Show();
	boss SetCanDamage( true );
	if ( !IS_TRUE( level.tod_upgrade_pause ) && !IS_TRUE( boss.tod_frozen ) )
	{
		boss.ignoreall = false;
		boss ASMSetAnimationRate( base_rate );
	}
	PlayFX( level._effect[ "robot_landing" ], v_ground );
	// NEVER ON A RELOCATION: landing_kill_splash DoDamages every non-boss axis AI
	// within 350u for health+10000 with NO attacker — no points, no luck. On the
	// spawn path that is the intended arrival shockwave; on an un-stranding it
	// would be a silent AoE nuke going off next to whichever player the boss was
	// sent to. landing_rumble likewise shakes EVERY player wherever they are.
	// Both are spawn-scale events; an un-stranding gets a smaller quake and
	// nothing else.
	if ( IS_TRUE( b_relocate ) )
	{
		Earthquake( 0.4, 0.9, v_ground, 900 );
	}
	else
	{
		Earthquake( 0.55, 1.2, v_ground, 1200 );
		level thread landing_kill_splash( v_ground, boss );
		level thread landing_rumble();
	}
	return true;
}

// Anti-strand watchdog (verify 2026-08-20): a base-spawned boss must climb the
// 25-floor spiral. If it makes NO progress toward the players for a while and
// isn't already engaging, relocate it to a navmesh point near a living player
// (map 1's anti-strand net) — a stuck boss otherwise never dies, leaking the
// Panzer music/luck and stacking the next one. Never fires while a boss is
// climbing normally or fighting close.
#define TOD_BOSS_STUCK_SECS      18
#define TOD_BOSS_STUCK_STEP      2
#define TOD_BOSS_STUCK_IMPROVE   120    // must close this much toward a player to count as progress
#define TOD_BOSS_NEAR_PLAYER     1500   // within this = engaging, never relocate

// A RELOCATION landing spot. The case that actually bites is pick_spawn_point's
// own last resort — `return anchor;`, the player's exact origin — which one
// re-roll cannot fix by chance, so test the distance explicitly. ground_snap
// too: the old bare teleport never did, and that is the same feet-in-the-tread
// bug ground_snap was written for.
function pick_reloc_point( anchor )
{
	p = ground_snap( pick_spawn_point( anchor ) );
	if ( nearest_player_dist( p ) >= TOD_RELOC_MIN_DIST )
		return p;
	p2 = ground_snap( pick_spawn_point( anchor ) );
	if ( nearest_player_dist( p2 ) >= TOD_RELOC_MIN_DIST )
		return p2;
	return p;   // both close — the ENTRANCE is what makes that survivable, and a
	            // boss we fail to un-strand never dies at all.
}

// PANZER + PROTECTOR. Runs as its OWN thread and deliberately carries NO
// self endon("death"): drop_in deletes its proxy and trail INLINE and handles a
// boss that died mid-fall, but tod_boss_stuck_watch carries self endon("death")
// — calling drop_in from inside it would strand a script_model wearing the boss
// model plus a tag_origin playing robot_sky_trail forever, every time a boss
// died during its own arrival.
function relocate_entrance( v_ground )   // self = the boss
{
	level endon( "end_game" );
	drop_in( self, v_ground, self.angles, self.tod_base_rate, true );
}

// HELLHOUND + REAVER. The ground tell, then the move — no Ghost, no
// ASMSetAnimationRate, no SetGoal pin, no invulnerability window. A dog falling
// out of the ceiling reads as a bug, the hound's whole contract is that nothing
// writes its ASM (_tod_hellhounds.gsc trap 3), its behaviour tree never
// re-SetGoals (which is exactly the frozen-hound bug hound_target_watch fixes),
// and the Reaver never called drop_in at all — its spawn entrance is the
// apothicon meteor. tell_fx is level-threaded and self-deletes, so nothing leaks.
function relocate_tell( v_ground )   // self = hound / reaver
{
	level endon( "end_game" );
	level thread tell_fx( v_ground, 0.8 );
	wait 0.8;
	if ( !isdefined( self ) || !isalive( self ) )
		return;
	self ForceTeleport( v_ground, self.angles );
	PlayFX( level._effect[ "robot_landing" ], v_ground );
}

function nearest_player_dist( org )
{
	best = -1;
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isalive( p ) )
			continue;
		d = Distance( org, p.origin );
		if ( best < 0 || d < best )
			best = d;
	}
	return best;
}

function tod_boss_stuck_watch()   // self = boss
{
	self endon( "death" );
	level endon( "end_game" );

	best = -1;         // best (smallest) distance-to-nearest-player seen
	stalled = 0;
	// A PLAYER TELEPORT IS NOT A BOSS STALL — and this is the real reason the
	// user sees elites "randomly spawn at you when you are too far away".
	// `best` only ever ratchets DOWN, so the moment a player takes a breather
	// ride, d jumps by thousands and can never beat the stale best again; the
	// accumulator then runs out ~18s later and relocates a boss that was never
	// stuck. _tod_teleport bumps this counter on every ride with riders aboard.
	tp = ( ( isdefined( level.tod_tp_stamp ) ) ? level.tod_tp_stamp : 0 );
	for ( ;; )
	{
		wait TOD_BOSS_STUCK_STEP;
		if ( !isdefined( self ) || !isalive( self ) )
			return;
		if ( IS_TRUE( level.tod_upgrade_pause ) || IS_TRUE( self.tod_frozen ) )
			continue;   // the freeze isn't "stuck"
		now_tp = ( ( isdefined( level.tod_tp_stamp ) ) ? level.tod_tp_stamp : 0 );
		if ( now_tp != tp )
		{
			tp = now_tp;
			best = -1;   stalled = 0;   continue;   // the PLAYER moved, not us
		}

		d = nearest_player_dist( self.origin );
		if ( d < 0 )
			continue;   // no living players
		if ( d <= TOD_BOSS_NEAR_PLAYER )
		{
			best = d;   stalled = 0;   continue;   // engaging — reset
		}
		if ( best < 0 || d < best - TOD_BOSS_STUCK_IMPROVE )
		{
			best = d;   stalled = 0;   continue;   // real progress toward a player
		}
		stalled += TOD_BOSS_STUCK_STEP;
		if ( stalled >= TOD_BOSS_STUCK_SECS )
		{
			// Relocate by KIND (v9.19): a stalled Panzer goes back up to the
			// highest player, a stalled Protector to the lowest — the same
			// anchor rule as the spawn.
			kind = ( isdefined( self.tod_boss_kind ) ? self.tod_boss_kind : "any" );
			target = anchor_player( kind );
			if ( !isdefined( target ) )
				target = pick_target_player();
			if ( isdefined( target ) )
			{
				dest = pick_reloc_point( target.origin );
				// tod_base_rate present = an actor whose ASM we are allowed to
				// write (Panzer, Protector) -> the real sky-drop entrance.
				// Absent = hound or Reaver -> ground tell only. The hound opts
				// out by having nothing set, the same shape as its speed exemption.
				if ( isdefined( self.tod_base_rate ) )
					self thread relocate_entrance( dest );
				else
					self thread relocate_tell( dest );
				dbg( "boss stalled — relocating with an entrance" );
			}
			best = -1;   stalled = 0;
		}
	}
}

// Panzer: ONE every 5th round.
function panzer_due( round )
{
	first    = ( IS_TRUE( level.tod_dev ) ? TOD_PANZER_FIRST_DEV : TOD_PANZER_FIRST );
	interval = ( IS_TRUE( level.tod_dev ) ? TOD_PANZER_INT_DEV   : TOD_PANZER_INTERVAL );
	if ( round < first )
		return 0;
	if ( ( round % interval ) != 0 )
		return 0;
	return 1;
}

function round_watch()
{
	level endon( "end_game" );

	last = ( isdefined( level.round_number ) ? level.round_number : 1 );
	for ( ;; )
	{
		wait 1;
		r = level.round_number;
		if ( !isdefined( r ) || r == last )
			continue;
		last = r;

		// THE LAST MILE owns all boss debts while it runs (see
		// finale_pressure_start) — the round schedule stands down.
		if ( IS_TRUE( level.tod_finale_aggro ) )
			continue;

		rp = protector_due( r );
		pz = panzer_due( r );

		// DEBT IS SET, NOT SUMMED (playtest 2026-08-23, the other half of the
		// ~30-protector round): += stacked every unfinished wave — rounds
		// 12+15+18 uncleared banked 8+8+8 and the director drained them all,
		// 8 alive at a time, for minutes. A new wave now REPLACES whatever is
		// left owing (same rule the Panzer debt cap encodes below): the
		// punishment for not clearing a wave is the protectors still standing,
		// not a backlog on top of them. (Precisely: the write RAISES the debt
		// to the new wave's size and never lowers it — set-to-max, so a big
		// owed wave is not cancelled by a later smaller one.)
		if ( rp > 0 && rp > level.tod_protector_debt )
			level.tod_protector_debt = rp;
		if ( pz > 0 )
		{
			level.tod_panzer_debt += pz;
			// DEBT CAP (2026-08-23), the other half of the roof: without it a
			// player who stalls on one Panzer through rounds 10/15/20 banks a
			// queue that all pops the instant he finally dies — the same flood
			// by a slower route. Owing at most one means the punishment for a
			// slow kill is the Panzer you already have, not a backlog.
			if ( level.tod_panzer_debt > TOD_PANZER_MAX_ALIVE )
				level.tod_panzer_debt = TOD_PANZER_MAX_ALIVE;
		}
	}
}

// SPAWN BANNERS REMOVED 2026-08-22 (user: "remove all the announcement banners
// for the enemies spawning in — it's unnecessary"). Deleted with them:
// banner()/banner_notify_all()/boss_banner_show()/boss_banner_show_seq(), the
// "tod_boss_banner" eventstring precache, the whole LUI block in
// tod_upgrade.lua, and the i_tod_banner_panzer / i_tod_banner_protectors zone
// image lines. The enemies now announce themselves the way everything else on
// this map does — the Panzer's music channel, the Reaver's meteor streak, the
// Protectors' drop-in slam, and the floor gauge's boss pip. This is the same
// doctrine that already stripped the floaty kill text and the dev IPrintLnBold:
// NO on-screen gameplay text. If an enemy ever needs a tell, give it a sound or
// an FX, not a caption. Do NOT re-add a banner lane for elites 2 and 3.

function director()
{
	level endon( "end_game" );

	for ( ;; )
	{
		wait 3;

		// Never spawn into the upgrade-choice freeze (players are frozen).
		if ( IS_TRUE( level.tod_upgrade_pause ) )
			continue;

		// Panzer outranks the wave for the next slot (his music + presence
		// define the round; the RP debt keeps draining right after).
		// ROOF (2026-08-23): never more than TOD_PANZER_MAX_ALIVE standing —
		// the branch below had this from day one and this one did not. A debt
		// held here is NOT lost: it drains on the next tick after he dies.
		if ( level.tod_panzer_debt > 0 && level.tod_panzer_alive < TOD_PANZER_MAX_ALIVE )
		{
			boss = spawn_panzer();
			if ( isdefined( boss ) && isalive( boss ) )
				level.tod_panzer_debt--;
			continue;   // one spawn per tick — trickle, never same-frame
		}

		// Wave debt drains while under the concurrency roof — the AI budget
		// must keep feeding zombies (endless rounds depend on it), so the
		// rest of the wave enters as the front line dies.
		if ( level.tod_protector_debt > 0 && protectors_alive() < rp_max_alive() )
		{
			boss = spawn_protector();
			if ( isdefined( boss ) && isalive( boss ) )
				level.tod_protector_debt--;
		}
	}
}

// Counted live off the AI list (a stored counter could leak on a pack-side
// actor Delete and stall the director at the cap forever).
// PUBLIC — _tod_finale calls this when the run starts. Owns nothing but the
// debt counters: each type's own director still drains its debt under its own
// MAX_ALIVE roof, so this can never spawn more than those already allow.
function finale_pressure_start()
{
	level.tod_finale_aggro = true;   // read by _tod_endless_rounds::tod_spawn_delay
	// v10.4 (audit find): the roof only ever gated THIS loop's top-ups —
	// round_watch and the reaver's round_watch kept writing their own debts
	// during the run, so 8 protectors + 1 panzer + 3 reavers were all
	// simultaneously reachable (12 bosses = zombie spawns starved at stock's
	// 31-actor gate, at the exact moment the run promises saturation). The
	// aggro flag now SUSPENDS both round-scheduled debt writers (they check
	// it), and any debt banked before the buy is clamped here so the run
	// starts inside the roof.
	// v12.13 (review FIX 4, the spec's "zero the type's debt"): pre-buy OWED
	// panzer debt is dropped outright, not clamped — with the beat armed from
	// the run's first frame, the first Panzer of the run IS the Narrows drop.
	// (A Panzer already ALIVE at the buy still legitimately blocks the beat;
	// that is the designed degrade.) Protector debt keeps the old clamp: the
	// road's opening wave is theirs.
	level.tod_panzer_debt = 0;
	if ( level.tod_protector_debt > 2 )
		level.tod_protector_debt = 2;
	if ( isdefined( level.tod_reaver_debt ) && level.tod_reaver_debt > 1 )
		level.tod_reaver_debt = 1;
	// The isdefined guard is required: tod_hellhounds::init assigns the debt
	// only after initial_blackscreen_passed + 3s, and this can be called before
	// then if a player somehow buys extraction that early.
	if ( isdefined( level.tod_hound_debt ) && level.tod_hound_debt > 2 )
		level.tod_hound_debt = 2;
	level thread finale_pressure_loop();
}

// PUBLIC — THE CROWN HOLD-OUT (v10.26). Called by _tod_finale the moment the
// citadel door seals. The road ambush cycles all four elite types evenly so no
// one kind dominates the run; the hold-out is a BOSS FIGHT, so the PANZER stops
// taking its turn in that rotation and is kept on the floor continuously while
// the other three keep cycling around it as adds.
//
// It raises NO limit. TOD_PANZER_MAX_ALIVE is still 1, so this can only ever add
// a single actor beyond what the rotation was already allowed, and the roof
// still gates every other type.
function finale_holdout_start()
{
	level.tod_finale_holdout = true;
	if ( level.tod_panzer_debt < 1 )
		level.tod_panzer_debt = 1;
}

// PUBLIC — AUTHORED BOSS BEATS (v12.13, docs/41 §A2/§A4). _tod_finale asks for
// a drop at a specific point; THIS file answers, because the roof arithmetic
// lives here and must stay in one place. Both REPLACE scheduled pressure
// rather than adding to it: debts cap at the same values the pressure loop
// writes, the per-type MAX_ALIVE roofs still gate the director, and a request
// that would breach TOD_FINALE_BOSS_ROOF is refused (returns false — the
// caller may retry a beat later or let it go; the road is already loud).
function finale_beat_panzer( org )
{
	if ( level.tod_panzer_alive >= TOD_PANZER_MAX_ALIVE )
		return false;
	rv = ( ( isdefined( level.tod_reaver_alive_n ) ) ? level.tod_reaver_alive_n : 0 );
	hd = ( ( isdefined( level.tod_hound_alive_n ) ) ? level.tod_hound_alive_n : 0 );
	live = level.tod_panzer_alive + protectors_alive() + rv + hd;
	if ( live >= TOD_FINALE_BOSS_ROOF )
		return false;
	level.tod_boss_force_org = org;
	if ( level.tod_panzer_debt < 1 )
		level.tod_panzer_debt = 1;
	return true;
}

function finale_beat_protectors( orgs )
{
	if ( !isdefined( orgs ) || orgs.size == 0 )
		return false;
	rv = ( ( isdefined( level.tod_reaver_alive_n ) ) ? level.tod_reaver_alive_n : 0 );
	hd = ( ( isdefined( level.tod_hound_alive_n ) ) ? level.tod_hound_alive_n : 0 );
	live = level.tod_panzer_alive + protectors_alive() + rv + hd;
	if ( live >= TOD_FINALE_BOSS_ROOF )
		return false;
	level.tod_rp_force_orgs = orgs;
	if ( level.tod_protector_debt < 2 )
		level.tod_protector_debt = 2;
	return true;
}

function finale_pressure_loop()
{
	level endon( "end_game" );
	level endon( "tod_ascend" );   // v14: the spire retires the finale's pressure — its own hot pacing takes over
	// Cycle the type we top up so no single kind dominates the road — the ask
	// was "all types of enemies", and topping every debt at once would just
	// fill TOD_FINALE_BOSS_ROOF with whichever director ticks first.
	which = 0;
	for ( ;; )
	{
		// v12.13 (docs/41 §A2): the tick is a level field so the finale can
		// tighten it (6 -> 4) as the song enters its sustained half. Absent
		// field = the old constant, byte-for-byte.
		tick = TOD_FINALE_PRESSURE_TICK;
		if ( isdefined( level.tod_finale_pressure_tick ) )
			tick = level.tod_finale_pressure_tick;
		wait tick;
		if ( IS_TRUE( level.tod_upgrade_pause ) )
			continue;

		// Reaver count is read through a LEVEL FIELD, not an import: _tod_reaver
		// imports THIS file, so importing it back would be the cycle the KB
		// forbids. It publishes the count; we only ever read it.
		// HOLD-OUT: the Panzer is the centrepiece, not one quarter of a rotation.
		// Topped up BEFORE the roof check on purpose - its own per-type max of 1
		// is the real bound, so at worst this puts one Panzer on the floor while
		// the roof keeps gating the adds around it.
		if ( IS_TRUE( level.tod_finale_holdout ) && level.tod_panzer_alive < TOD_PANZER_MAX_ALIVE
		     && level.tod_panzer_debt < 1 )
			level.tod_panzer_debt = 1;

		rv = ( ( isdefined( level.tod_reaver_alive_n ) ) ? level.tod_reaver_alive_n : 0 );
		// Hounds are read through their PUBLISHED LEVEL FIELD, never by importing
		// _tod_hellhounds — that module imports THIS one, so the reverse would be
		// the cycle the KB forbids.
		hd = ( ( isdefined( level.tod_hound_alive_n ) ) ? level.tod_hound_alive_n : 0 );
		live = level.tod_panzer_alive + protectors_alive() + rv + hd;
		if ( live >= TOD_FINALE_BOSS_ROOF )
			continue;

		switch ( which % 4 )
		{
			case 0:
				// v12.13 (review FIX 4): while the Narrows beat is ARMED this
				// turn is skipped, so the beat's Panzer replaces the rotation's
				// rather than queueing behind a roving one. The hold-out top-up
				// above is unaffected (it runs before the switch).
				if ( IS_TRUE( level.tod_beat_panzer_armed ) )
					break;
				if ( level.tod_panzer_debt < 1 )
					level.tod_panzer_debt = 1;
				break;
			case 1:
				if ( IS_TRUE( level.tod_beat_prot_armed ) )
					break;
				if ( level.tod_protector_debt < 2 )
					level.tod_protector_debt = 2;
				break;
			case 2:
				if ( !isdefined( level.tod_reaver_debt ) )
					level.tod_reaver_debt = 0;
				if ( level.tod_reaver_debt < 1 )
					level.tod_reaver_debt = 1;
				break;
			case 3:
				// 2, not a full pack: one arm of the cycle must never be able to
				// eat the whole TOD_FINALE_BOSS_ROOF on its own. Literal rather
				// than the define because that define is file-local to
				// _tod_hellhounds (the reaver arm above hardcodes 1 for the same
				// reason).
				if ( !isdefined( level.tod_hound_debt ) )
					level.tod_hound_debt = 0;
				if ( level.tod_hound_debt < 2 )
					level.tod_hound_debt = 2;
				break;
		}
		which++;
	}
}

function protectors_alive()
{
	n = 0;
	a_ai = GetAISpeciesArray( "all" );
	for ( i = 0; i < a_ai.size; i++ )
	{
		ai = a_ai[ i ];
		if ( !isdefined( ai ) || !isalive( ai ) )
			continue;
		if ( isdefined( ai.tod_boss_kind ) && ai.tod_boss_kind == "protector" )
			n++;
	}
	return n;
}

// ---------------------------------------------------------------------------
// Spawn placement — anchored to a random living player (the fight climbs the
// tower with them), navmesh-scattered, clear of players + living bosses.
// ---------------------------------------------------------------------------

function pick_target_player()
{
	candidates = [];
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		if ( isdefined( players[ i ] ) && zm_utility::is_player_valid( players[ i ] ) )
			candidates[ candidates.size ] = players[ i ];
	}
	if ( candidates.size == 0 )
		return undefined;
	return candidates[ RandomInt( candidates.size ) ];
}

function pick_spawn_point( anchor )
{
	// Living bosses to keep clear of.
	bosses = [];
	a_ai = GetAISpeciesArray( "all" );
	for ( i = 0; i < a_ai.size; i++ )
	{
		ai = a_ai[ i ];
		if ( !isdefined( ai ) || !isalive( ai ) )
			continue;
		if ( IS_TRUE( ai.is_boss ) || IS_TRUE( ai.acc_is_boss ) || IS_TRUE( ai.acc_is_mini_boss ) )
			bosses[ bosses.size ] = ai;
	}
	players = GetPlayers();

	// Two passes (v9.19): 400u, then 800u. Anchors are PLAYER positions now,
	// and on a narrow flight — every near candidate behind a closed door or
	// inside the player/boss clearance — the old single pass fell straight
	// through to "spawn on the player". The wider pass reaches the flight
	// below/above first.
	for ( pass = 0; pass < 2; pass++ )
	{
		radius = ( ( pass == 0 ) ? 400 : 800 );
		queryResult = PositionQuery_Source_Navigation( anchor, 0, radius, 40, 32 );
		if ( !isdefined( queryResult ) || queryResult.data.size == 0 )
			continue;

		clear = [];
		checks = 0;
		for ( i = 0; i < queryResult.data.size; i++ )
		{
			p = queryResult.data[ i ].origin;
			ok = true;
			// SEALED CROWN: only inside the hall (peer review 2026-08-25). The
			// anchor is a player, who is sealed in — but the 800u query pass
			// reaches straight through the shut door onto the causeway, and a
			// boss that lands out there is stranded AND holds one of the four
			// hold-out slots for the rest of the fight, which starves the siege
			// of the very thing it is made of. Cheap test, no temp entity, so it
			// runs before the budgeted zone checks below.
			if ( IS_TRUE( level.tod_crown_sealed ) && !( tod_crown_data::in_hall( p ) ) )
				ok = false;
			for ( j = 0; j < bosses.size; j++ )
			{
				if ( DistanceSquared( p, bosses[ j ].origin ) < TOD_BOSS_CLEARANCE * TOD_BOSS_CLEARANCE )
				{
					ok = false;
					break;
				}
			}
			if ( ok )
			{
				for ( j = 0; j < players.size; j++ )
				{
					if ( isdefined( players[ j ] ) &&
					     DistanceSquared( p, players[ j ].origin ) < TOD_BOSS_PLAYER_CLEAR * TOD_BOSS_PLAYER_CLEAR )
					{
						ok = false;
						break;
					}
				}
			}
			// ZONE GATE (user 2026-08-21: "Panzer spawned on first set of stairs
			// even though the door was not opened"). PositionQuery_Source_Navigation
			// searches a RADIUS and DisconnectPaths does NOT delete navmesh
			// polys — it only blocks pathing THROUGH the slab — so the query
			// happily returns points behind a closed door. Reject any candidate
			// that is not inside a currently ENABLED zone (ignore_enabled_check
			// = false). Capped at TOD_BOSS_ZONE_CHECKS per pass because each call
			// spawns (and deletes) a temp script_origin.
			if ( ok && checks < TOD_BOSS_ZONE_CHECKS )
			{
				checks++;
				zn = zm_zonemgr::get_zone_from_position( p, false );
				if ( !isdefined( zn ) )
					ok = false;
			}
			else if ( ok )
				ok = false;   // out of budget — do not risk an unvetted point

			if ( ok )
				clear[ clear.size ] = p;
		}

		if ( clear.size > 0 )
			return clear[ RandomInt( clear.size ) ];
	}

	// Nothing vetted in either pass: fall back to the ANCHOR itself rather
	// than an unvetted query point — it is a living player's position, a spot
	// we already trust to be on the mesh and inside an enabled zone.
	return anchor;
}

// exp^(round - anchor), integer-loop pow (GSC has no reliable Pow builtin).
function boss_hp( round, anchor, base, exp_per_round )
{
	mult = 1.0;
	for ( r = anchor; r < round; r++ )
		mult = mult * exp_per_round;
	hp = int( base * mult * coop_hp_mult() );
	if ( hp < 1 )
		hp = 1;
	return hp;
}

function coop_hp_mult()   // map 1's boss coop table verbatim
{
	n = 0;
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
		if ( isdefined( players[ i ] ) )
			n++;
	if ( n <= 1 ) return 1.0;
	if ( n == 2 ) return 1.7;
	if ( n == 3 ) return 2.3;
	// 2.6 -> 2.8 (user 2026-08-28: "make 4 players 2.8x", from the Panzer HP
	// review). NOTE this table is shared by boss_hp(), so the +7.7% at 4
	// players reaches the PROTECTORS too, not just the Panzer — accepted, one
	// coop table for all bosses is the map-1 doctrine this function ports.
	return 2.8;
}

// ---------------------------------------------------------------------------
// PANZER
// ---------------------------------------------------------------------------

function spawn_panzer()
{
	// Never START a spawn inside the upgrade freeze (set_world_pause only
	// freezes AI alive at pause time — a mid-pause arrival runs unfrozen).
	if ( IS_TRUE( level.tod_upgrade_pause ) )
		return undefined;

	// ANCHOR (v9.19, user 2026-08-22): the HIGHEST living player — he drops in
	// at the front of the climb. (Was the base ring, climbing up — user
	// 2026-08-20, superseded.) pick_spawn_point scatters on enabled zones
	// only, clear of every player and living boss.
	target = anchor_player( "panzer" );
	if ( !isdefined( target ) )
		return undefined;

	ang    = ( 0, RandomInt( 360 ), 0 );
	// THE LAST MILE: he blocks the road (user 2026-08-23: "Panzer included
	// should spawn in front of you"). Anchoring the nav query AHEAD of the
	// player instead of ON him turns him from something chasing the party up
	// the tower into the thing standing between them and the Crown — which is
	// the whole point of a road with one exit.
	// YAW-ONLY forward, same rule as the spawn selector. The road is NOT flat any
	// more — v12 envelope: ridge and broken stair at +/-CW_HUMP 256, the plank
	// at +256, the undercroft at -CW_DEEP 384 — so this is a deliberate choice
	// rather than a shortcut: a pitch component would swing the anchor into the
	// air above a crest or into the deck below a trough. Project onto the
	// horizontal and let the navmesh query find the floor.
	//
	// AND THE FALLBACK HAS TO BE RE-ANCHORED, which the first cut missed (review
	// 2026-08-23). pick_spawn_point's last resort is `return anchor` — safe by
	// construction everywhere else in this file, because every other caller passes
	// target.origin, a living player's position that is by definition on the mesh
	// and in an enabled zone. This caller does not: it passes a point 700 units
	// along the player's facing, and on a 160-wide road that forks, jogs, dives
	// and pinches, that point is off the deck more often than on it. Both navmesh passes then
	// find nothing, the fallback hands back the offset anchor unvetted, and a
	// Panzer is spawned in open air to fall 19,000 units — costing the run its
	// boss and leaving the pressure loop's slot occupied by a corpse.
	//
	// So: try forward, and if the fallback fired (it returns the anchor verbatim,
	// which is how we can tell), ask again from the player himself. He is still
	// the thing standing between the party and the Crown; he just enters from
	// beside them instead of ahead.
	// THE BEAT SEAM (v12.13, docs/41 §A2/§A4): a consume-once forced landing
	// point. The pressure loop only writes DEBT and this director picks its own
	// point on its own cadence — so without this, an authored drop lands ±a
	// tick and anywhere. The org comes from GENERATED _tod_crown_data (deck-
	// centre, navmesh by construction); if SpawnActor still refuses it, the
	// existing retry-at-the-target's-feet below is the net, same as ever.
	force = undefined;
	if ( isdefined( level.tod_boss_force_org ) )
	{
		force = level.tod_boss_force_org;
		level.tod_boss_force_org = undefined;
	}
	anchor_org = target.origin;
	if ( isdefined( force ) )
	{
		org = force;
	}
	else
	{
		if ( IS_TRUE( level.tod_finale_aggro ) )
		{
			t_ang = target GetPlayerAngles();
			t_fwd = AnglesToForward( ( 0, t_ang[ 1 ], 0 ) );
			anchor_org = target.origin + VectorScale( t_fwd, TOD_PANZER_FRONT_DIST );
		}
		org = pick_spawn_point( anchor_org );
		if ( org == anchor_org && anchor_org != target.origin )
			org = pick_spawn_point( target.origin );
	}
	// Mid-flight navmesh points sit below the tread tops — see ground_snap.
	org = ground_snap( org );

	// Refresh the pack's per-round part-health fields BEFORE setup reads them
	// (defined-but-never-called in the pack — HP undefined without this).
	mechz_spiki::mechz_health_increases();

	rn = ( isdefined( level.round_number ) ? level.round_number : 1 );
	hp = boss_hp( rn, TOD_PANZER_FIRST, TOD_PANZER_HP_BASE, TOD_PANZER_HP_EXP );
	// level.mechz_health must carry the SAME number — acc_setup_mechz copies
	// it onto the actor and the pack's special-weapon formulas read it live.
	level.mechz_health = hp;

	// targetname MUST be defined (`!=` on undefined throws in the pack's tomb
	// spawn function) and MUST NOT be "mechz_tomb" (enables the broken claw).
	boss = SpawnActor( "archetype_zm_mechz_genesis", org, ang, "tod_panzer", true );
	if ( !isdefined( boss ) )
	{
		// Retry at the TARGET PLAYER's feet — genuinely navmesh-guaranteed (the
		// base ring anchor can miss the mesh if PositionQuery returned nothing).
		// The stuck-watch then walks him back down/toward the fight.
		dbg( "panzer SpawnActor undefined — retrying at target player origin" );
		boss = SpawnActor( "archetype_zm_mechz_genesis", target.origin, ang, "tod_panzer", true );
	}
	if ( !isdefined( boss ) )
	{
		dbg( "panzer spawn FAILED" );
		return undefined;
	}

	// PRE-ENTRANCE SHIELD (v13.3, user live report 2026-08-28: "panzers will
	// spawn and insta die and then respawn"). Between this SpawnActor and
	// drop_in's Ghost (the 0.1s + 0.25s waits and setup below) he used to
	// stand VISIBLE, DAMAGEABLE, at the ARCHETYPE'S DEFAULT HEALTH (the real
	// hp lands in acc_setup_mechz), with NO boss identity flags — so players
	// mid-fight could shred him before setup ran, and a concurrent
	// protector's landing_kill_splash saw an unflagged axis AI inside its
	// 350u radius and killed him outright (solo makes that overlap routine:
	// the panzer anchors the HIGHEST player and the wave the LOWEST — the
	// same person). Either death made this function return undefined at the
	// isalive checks below, the debt was never decremented, and the
	// director's next 3s tick spawned the "respawn" the user watched.
	// Shield + flag him on the SPAWN FRAME. drop_in re-applies the same
	// Ghost/SetCanDamage pair and its reveal path restores both, so this
	// only extends the entrance state backward over the init window; the
	// identity block after acc_setup_mechz re-sets the flags harmlessly.
	boss Ghost();
	boss SetCanDamage( false );
	boss.ignoreall        = true;
	boss.is_boss          = true;
	boss.acc_is_boss      = true;
	boss.acc_is_mini_boss = true;   // landing_kill_splash's filter reads these

	// Let the archetype spawn funcs run before our overrides land on top.
	wait 0.1;
	if ( !isdefined( boss ) || !isalive( boss ) )
		return undefined;

	// SPAWN-FUNC SELF-HEAL (map 1: "he attacks but never walks"): a direct
	// SpawnActor can miss spawner::spawn_think's dispatch — without stock
	// ArchetypeMechzBlackboardInit every movement state is starved.
	ran = ( isdefined( boss.flameTrigger ) && IS_TRUE( boss.is_mechz ) );
	if ( !ran )
	{
		dbg( "panzer spawn funcs missed — self-healing" );
		boss thread spawner::run_spawn_functions();
		wait 0.25;
		if ( !isdefined( boss ) || !isalive( boss ) )
			return undefined;
	}

	// The pack's per-ai block: damage callbacks, part healths, goalRadius 64
	// (the statue-bug fix), ambient vox.
	boss mechz_spiki::acc_setup_mechz();

	// BODY-DAMAGE REBUFF: capture the stock damage func acc_setup_mechz just
	// installed, then wrap it (body rebuff + honest headshots — see the wrap).
	if ( !isdefined( level.tod_mechz_stock_damage_func ) )
		level.tod_mechz_stock_damage_func = boss.actor_damage_func;
	boss.actor_damage_func = &tod_mechz_damage_wrap;

	// Boss identity — the landing-splash filter, zombie-speed sweep skip and
	// nuke/round-count exemptions all key off these. Set immediately.
	boss.is_boss               = true;
	boss.acc_is_boss           = true;    // vendored pack filters read acc_ names
	boss.acc_is_mini_boss      = true;
	boss.acc_is_panzer         = true;
	boss.tod_boss_kind         = "panzer";
	boss.ignore_enemy_count    = true;    // fights ALONGSIDE the wave
	boss.ignore_nuke           = true;
	boss.disableAmmoDrop       = true;

	boss ASMSetAnimationRate( TOD_PANZER_ANIM_RATE );
	boss.tod_base_rate = TOD_PANZER_ANIM_RATE;   // relocate_entrance restores this

	boss.maxhealth = hp;
	boss.health    = hp;

	// PANZER MUSIC (user 2026-08-19): his track owns the channel while any
	// Panzer lives; the ambient loop resumes when the last one dies
	// (panzer_life calls boss_track_end). Started as the tell appears so the
	// first hit of "Data Spike" lands with the slam; panzer_life starts now
	// too — a mid-fall pack-side Delete must still release the music + count.
	tod_atmosphere::boss_track_start();
	level thread panzer_life( boss );

	// ENTRANCE (v9.19): the shared drop-in. Nothing below may run on a boss
	// that is still falling — every driver thread starts after the reveal.
	if ( !drop_in( boss, org, ang, TOD_PANZER_ANIM_RATE ) )
	{
		dbg( "panzer lost mid-entrance" );
		return undefined;
	}

	tod_boss_fx::attach( boss, 2 );
	boss thread goal_driver();
	boss thread retarget_loop();
	boss thread boss_pause_watch( TOD_PANZER_ANIM_RATE );
	boss thread tod_boss_stuck_watch();   // anti-strand: relocates toward the highest player

	dbg( "panzer up — round " + rn + ", " + hp + " hp @ " + org );
	return boss;
}

// Hit-location damage wrapper (map 1's acc_mechz_damage_wrap, dvars folded):
// stock scales EVERY body hit to 0.1 (pure sponge) — delegate to stock first
// (all side effects intact) then rebuff the body family to BODY_SCALE, make
// the head an honest weak spot for aimed shots, and pass melee through
// untouched (script melee like CLEAVE carries final values).
function tod_mechz_damage_wrap( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex )
{
	// LAST-HIT ledger (user 2026-08-20: "last hit will get all points for
	// luck") — the poll-based panzer_life has no death attacker, so the wrap
	// records the most recent player to damage him.
	if ( isdefined( attacker ) && isplayer( attacker ) )
		self.tod_last_attacker = attacker;

	// [tod] Gift of Death: fixed 30 shots on the Panzer, round-independent.
	// This wrap is self.actor_damage_func (runs LAST, after the level chain +
	// the stock mechz scaling), so returning here is authoritative — no rescale.
	// Guard damage>0 + per-target same-frame dedupe (verify 2026-08-20): the
	// weapon's contact damage is 0 today so one explosion lands per shot, but
	// if a direct impact + splash ever co-fire the same frame this keeps it
	// exactly 30 shots (the 2nd event is a negligible chip, not a 2nd 1/30).
	if ( isdefined( weapon ) && isdefined( weapon.name ) && IsSubStr( weapon.name, "xmas_gun" ) && isdefined( damage ) && damage > 0 )
	{
		now = GetTime();
		if ( isdefined( self.tod_xmas_hit_ms ) && self.tod_xmas_hit_ms == now )
			return 1;
		self.tod_xmas_hit_ms = now;
		return int( ( self.maxhealth / TOD_XMAS_PANZER_SHOTS ) * TOD_XMAS_ELITE_BUFF ) + 1;
	}

	result = self [[ level.tod_mechz_stock_damage_func ]]( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex );
	if ( !isdefined( result ) || result <= 0 )
		return result;

	projectile_direct = ( isdefined( mod ) && mod == "MOD_PROJECTILE" );
	if ( is_splash_mod( mod ) && !projectile_direct )
		return result;

	// Melee pass-through: stock DEFAULTs melee hitlocs into the 0.1x body
	// family — return the incoming damage so script-final melee values stand.
	if ( isdefined( mod ) && IsSubStr( mod, "MELEE" ) )
		return damage;

	ref = mechz_weapon_mod( damage, weapon );
	if ( ref <= 0 )
		return result;

	// HEADSHOT: hitLoc head/helmet/neck, or proximity to j_faceplate (impact
	// points land on the helmet SURFACE — radius 36 covers it; height-guarded
	// so a missing tag falling back to the feet can't false-positive).
	//
	// WHY THERE ARE TWO CASES AND WHY THEY PAY DIFFERENTLY (user 2026-08-24:
	// "only some guns can hit panzer for headshots"). While the FACEPLATE IS
	// STILL ON, stock's mechz callback classifies a hit on the visor as
	// `torso_upper`, not `head` (mechz.gsc:1146 — it tracks faceplate damage
	// from inside the torso_upper case). hitLoc is what the ENGINE keys the
	// hit-location multiplier off, so on those hits it already applied
	// locTorsoUpper 1.0 instead of locHead 3.0 — the incoming `damage` is a
	// BODY-rate number. The old code then handed it the head SCALE anyway, so a
	// face hit paid 0.9x base while a real head hit paid 3.0 x 0.9 = 2.7x base.
	// That 3x step is the whole of the reported symptom: a gun only "gets
	// headshots" on the Panzer once it has broken the faceplate (1500 hp base,
	// +100/round — see level.var_fa14536d), and a gun that cannot break it
	// never sees a crit at all.
	//
	// So: normalize the faceplate case by the head multiplier the engine did
	// NOT apply, then scale both cases identically. A visor hit is now worth
	// what a head hit is worth, which is what the fallback was always for.
	//
	// TOD_LOC_HEAD_NORM IS A HAND-COPIED CONSTANT — it mirrors LOC_NORM in
	// tools/gen_tod_twins.js, which stamps locHead/locHelmet/locNeck 3.0 on
	// every generated gun. A GSC #define is file-local and the generator is
	// JavaScript, so it cannot be referenced symbolically. If LOC_NORM moves,
	// move this in the SAME commit — this file has already shipped a stale
	// hand-copied damage constant once (see the block in rp_damage_feed).
	kind = tod_upgrades::headshot_kind( self, hitLoc, point );
	if ( kind == "loc" )
		return ref * TOD_PANZER_HEAD_SCALE;
	if ( kind == "faceplate" )
	{
		// A DIRECT PROJECTILE never received a hit-location multiplier from the
		// engine in the first place, so there is nothing to normalize — pay it
		// exactly as it paid before this fix. Only bullets are corrected.
		if ( projectile_direct )
			return ref * TOD_PANZER_HEAD_SCALE;
		return ref * TOD_LOC_HEAD_NORM * TOD_PANZER_HEAD_SCALE;
	}

	if ( projectile_direct )
		return result;

	// BODY: the 0.1 family maxes at 0.1, the next family floors at 0.25 — a
	// 0.2 cut cleanly separates body from weak spot.
	scale = result / ref;
	if ( scale >= 0.2 )
		return result;   // exposed core — stock behavior stands
	return result * ( TOD_PANZER_BODY_SCALE / 0.1 );
}

function is_splash_mod( mod )
{
	if ( !isdefined( mod ) )
		return false;
	return ( mod == "MOD_GRENADE" || mod == "MOD_GRENADE_SPLASH" || mod == "MOD_PROJECTILE" || mod == "MOD_PROJECTILE_SPLASH" || mod == "MOD_EXPLOSIVE" );
}

// Mirror of stock mechzWeaponDamageModifier — kept in lockstep so the scale
// inference divides by the EXACT base stock used.
function mechz_weapon_mod( damage, weapon )
{
	if ( isdefined( weapon ) && isdefined( weapon.name ) )
	{
		if ( IsSubStr( weapon.name, "shotgun_fullauto" ) )  return damage * 0.5;
		if ( IsSubStr( weapon.name, "lmg_cqb" ) )           return damage * 0.65;
		if ( IsSubStr( weapon.name, "lmg_heavy" ) )         return damage * 0.65;
		if ( IsSubStr( weapon.name, "shotgun_precision" ) ) return damage * 0.65;
		if ( IsSubStr( weapon.name, "shotgun_semiauto" ) )  return damage * 0.75;
	}
	return damage;
}

// GOAL DRIVER (map 1): the BT's movement is gated on HasPath() — when stock's
// strict navmesh projection finds no point it silently goals him AT his own
// origin and he idles forever. Re-goal with progressively looser projections.
function goal_driver()
{
	self endon( "death" );
	level endon( "end_game" );
	fail_streak = 0;
	for ( ;; )
	{
		wait 0.5;
		if ( !isdefined( self ) || !isalive( self ) )
			return;
		if ( IS_TRUE( level.tod_upgrade_pause ) )
			continue;
		if ( IS_TRUE( self.tod_dropping ) )
			continue;   // mid-entrance: drop_in owns the goal
		if ( self HasPath() )
		{
			fail_streak = 0;
			continue;
		}
		t = self.favoriteenemy;
		if ( !isdefined( t ) )
			continue;
		fail_streak++;
		if ( fail_streak < 2 )
			continue;   // give the stock service one beat to recover

		goal = GetClosestPointOnNavMesh( t.origin, 64, 30 );
		if ( !isdefined( goal ) ) goal = GetClosestPointOnNavMesh( t.origin, 128, 15 );
		if ( !isdefined( goal ) ) goal = GetClosestPointOnNavMesh( t.origin, 256, 0 );
		if ( !isdefined( goal ) ) goal = t.origin;
		self SetGoal( goal );
	}
}

// CLOSEST-PLAYER RETARGET (map 1: "he only chases one person the whole time").
function retarget_loop()
{
	self endon( "death" );
	level endon( "end_game" );

	for ( ;; )
	{
		wait 0.5;
		if ( !isdefined( self ) || !isalive( self ) )
			return;
		if ( IS_TRUE( self.ignoreall ) )
			continue;   // pack scripted-ignore window (or the upgrade pause)

		best = undefined;
		best_d = 999999999;
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isdefined( p ) || !zm_utility::is_player_valid( p ) )
				continue;
			d = DistanceSquared( self.origin, p.origin );
			if ( d < best_d )
			{
				best_d = d;
				best = p;
			}
		}
		if ( !isdefined( best ) )
			continue;
		if ( isdefined( self.favoriteenemy ) && self.favoriteenemy == best )
			continue;

		self.favoriteenemy = best;
		goal = GetClosestPointOnNavMesh( best.origin, 64, 30 );
		if ( !isdefined( goal ) ) goal = GetClosestPointOnNavMesh( best.origin, 128, 15 );
		if ( !isdefined( goal ) ) goal = GetClosestPointOnNavMesh( best.origin, 256, 0 );
		if ( !isdefined( goal ) ) goal = best.origin;
		self SetGoal( goal );
	}
}

// Poll-isalive (not waittill "death"): robust whether the pack's death anim
// Delete()s the actor or the corpse lingers (map 1 lesson).
function panzer_life( boss )
{
	level endon( "end_game" );
	level.tod_panzer_alive++;

	killer = undefined;
	org = boss.origin;
	while ( isdefined( boss ) && isalive( boss ) )
	{
		if ( isdefined( boss.tod_last_attacker ) )
			killer = boss.tod_last_attacker;   // polled — survives a pack-side Delete
		org = boss.origin;                      // last known spot (drop lands here)
		wait 0.25;
	}
	if ( isdefined( boss ) && isdefined( boss.tod_last_attacker ) )
		killer = boss.tod_last_attacker;       // the killing blow lands after the last poll

	level.tod_panzer_alive--;
	if ( level.tod_panzer_alive < 0 )
		level.tod_panzer_alive = 0;

	// Ambient resumes only when the LAST Panzer is down. The comment always
	// claimed this; the code did not check, so with the roof missing the first
	// death cut the boss track while others were still hunting you. Correct
	// even with the roof at 1 — it costs nothing and survives a raised roof.
	if ( level.tod_panzer_alive <= 0 )
		tod_atmosphere::boss_track_end();

	tod_luck::boss_kill( killer, "panzer" );   // LAST HIT takes the luck
	grant_boss_reward( "PANZER", TOD_PANZER_PTS, false );

	// GUARANTEED MAX AMMO on every Panzer kill (user 2026-08-20). level thread
	// — specific_powerup_drop can wait internally (map 1's blocking-callers rule).
	if ( isdefined( org ) )
		level thread zm_powerups::specific_powerup_drop( "full_ammo", org );
}

// The vendored mechz melee callback calls this ON THE HIT PLAYER before its
// own demigod clamp (map 1 applied Exo/Savior armor here). The tower's
// armor = the DMG REDUCTION upgrade domain — applied here for Panzer melee
// because the mechz callback short-circuits the normal player-damage chain.
// MUST return an int.
//
// ATTACKER (v9.45): the second parameter arrived with BACK ARMOR, which needs a
// bearing rather than a player state. mechz_spiki.gsc passes its eattacker (the
// Panzer) through the level.tod_player_mitigations_fn pointer. It stays OPTIONAL
// — GSC pads a missing argument with undefined and back_armor_mult returns 1.0
// for an undefined attacker, so an older call site degrades to the pre-v9.45
// behaviour instead of erroring.
function apply_player_mitigations( dmg, attacker )
{
	// PANZER melee is halved (user 2026-08-20: "hitting too hard"). This lane
	// is the mechz pack's player-damage short-circuit — Panzer melee only.
	dmg = int( dmg * TOD_PANZER_DMG_MULT );

	dr_lvl = tod_upgrades::get_level( self, "dr" );
	if ( dr_lvl > 0 )
	{
		dmg = int( dmg * ( 1.0 - 0.05 * dr_lvl ) );   // -5%/Lv (user 2026-08-20)
	}
	// SPRINT ARMOR (domain 32, session f2e3ffc8 2026-08-23) — the Panzer-melee
	// twin of the boss_player_damage hunk. This lane exists because the mechz
	// callback SHORT-CIRCUITS the normal chain, so without it Panzer melee would
	// be the one attack the domain never protected against.
	dmg = int( dmg * tod_upgrades::sprint_armor_mult( self ) );
	// BACK ARMOR (domain 36, v9.45) — the Panzer-melee twin, for the same reason
	// SPRINT ARMOR needed one: this lane short-circuits the normal chain, so
	// without it a Panzer swinging at your back would be the one attack the
	// domain never covered.
	dmg = int( dmg * tod_upgrades::back_armor_mult( self, attacker ) );
	if ( dmg < 1 )
		dmg = 1;
	return dmg;
}

// ---------------------------------------------------------------------------
// Electroball (the Panzer's 115 grenade): impact-detonate + the boss zap slow
// — without this it cooks its full fuse on the ground (map 1 recipe).
// ---------------------------------------------------------------------------

function electroball_watch()
{
	level endon( "end_game" );
	for ( ;; )
	{
		wait 0.25;
		grenades = GetEntArray( "grenade", "classname" );
		for ( i = 0; i < grenades.size; i++ )
		{
			g = grenades[ i ];
			if ( !isdefined( g ) || IS_TRUE( g.tod_eball_watched ) )
				continue;
			if ( !isdefined( g.model ) || g.model != "p7_zm_ctl_115_grenade_lod0" )
				continue;
			g.tod_eball_watched = true;
			g thread electroball_impact();
		}
	}
}

function electroball_impact()   // self = the grenade
{
	level endon( "end_game" );
	self thread electroball_bounce_detonate();
	// (the explosion's SLOW/zap on players was removed 2026-08-20 — user:
	// no stun moves; the grenade's own GDT explosion damage stands alone)
	self waittill( "explode", pos );
}

function electroball_bounce_detonate()   // self = the grenade
{
	self endon( "explode" );   // fused naturally first — stand down
	level endon( "end_game" );
	self waittill( "grenade_bounce" );
	if ( isdefined( self ) )
		self Detonate();
}

// ---------------------------------------------------------------------------
// ROGUE PROTECTOR
// ---------------------------------------------------------------------------

function spawn_protector()
{
	if ( IS_TRUE( level.tod_upgrade_pause ) )
		return undefined;

	// ANCHOR (v9.19, user 2026-08-22): the LOWEST living player — the wave
	// comes up from behind the climb. (Was the base ring — user 2026-08-20,
	// superseded.) The old 3s level-notify telegraph + pop-in is replaced by
	// the shared drop_in entrance below (the actor exists first, hidden).
	target = anchor_player( "protector" );
	if ( !isdefined( target ) )
		return undefined;

	// THE BEAT SEAM, protector flavour (v12.13, docs/41 §A2): a QUEUE rather
	// than a single field, because the flare beat lands TWO of them and the
	// director drains one per tick. Pop-from-front; empty/absent = stock path.
	force = undefined;
	if ( isdefined( level.tod_rp_force_orgs ) && level.tod_rp_force_orgs.size > 0 )
	{
		force = level.tod_rp_force_orgs[ 0 ];
		rest = [];
		for ( fi = 1; fi < level.tod_rp_force_orgs.size; fi++ )
			rest[ rest.size ] = level.tod_rp_force_orgs[ fi ];
		level.tod_rp_force_orgs = rest;
	}
	if ( isdefined( force ) )
		v_ground = force;
	else
		v_ground = pick_spawn_point( target.origin );
	// Mid-flight navmesh points sit below the tread tops — see ground_snap.
	// This is THE "protector in the floor" fix: he spends the whole entrance
	// pinned at v_ground (SetGoal in drop_in) and is revealed standing there.
	v_ground = ground_snap( v_ground );
	ang      = ( 0, RandomInt( 360 ), 0 );

	boss = SpawnActor( "spawner_acc_zod_robot_boss", v_ground, ang, "tod_protector", true );
	if ( !isdefined( boss ) )
	{
		// FALLBACK (map 1): the load-proven ALLY gold spawner + a runtime team
		// flip — stock's Thrasher does exactly this. Size-guarded (the tower
		// places no callbox spawners, so this array is normally empty).
		dbg( "RP SpawnActor undefined — trying ally-spawner + team flip" );
		if ( isdefined( level.zombie_robot_gold_spawners ) && level.zombie_robot_gold_spawners.size > 0 )
		{
			boss = level.zombie_robot_gold_spawners[ 0 ] SpawnFromSpawner( "tod_protector", 1 );
			if ( isdefined( boss ) )
			{
				boss.team = "axis";
				boss ForceTeleport( v_ground );
			}
		}
	}
	if ( !isdefined( boss ) )
	{
		dbg( "RP spawn FAILED" );
		return undefined;
	}

	// --- make the companion archetype behave as a boss (map 1's exact set) ---
	boss.b_robot_finished = 1;      // kills the companion revive/follow services
	boss.reviving_a_player = 0;
	boss.combatmode = "no_cover";   // archetype hardwires "cover"; coverless map
	boss.is_boss = true;
	boss.acc_is_boss = true;
	boss.acc_is_mini_boss = true;   // vendored landing-splash filter reads this
	boss.acc_is_rogue_protector = true;   // boss_player_damage lanes key off it
	boss.tod_boss_kind = "protector";
	boss.tod_base_rate = TOD_RP_ANIM_RATE;   // relocate_entrance restores this
	boss.ignore_enemy_count = true;
	boss.ignore_nuke = true;
	boss.allow_zombie_to_target_ai = 0;
	boss DisableAimAssist();
	boss.disableAmmoDrop = true;
	boss.can_gib_zombies = 0;

	rn = ( isdefined( level.round_number ) ? level.round_number : 1 );
	hp = boss_hp( rn, TOD_PROTECTOR_FIRST, TOD_PROTECTOR_HP_BASE, TOD_PROTECTOR_HP_EXP );
	boss.maxhealth = hp;
	boss.health = hp;

	// Crosshair damage numbers + upgrade-domain scaling: he does NOT route
	// through the zombie damage pipeline (map 1 finding) — feed from his own
	// AI damage callback chain.
	AiUtility::AddAIOverrideDamageCallback( boss, &rp_damage_feed );

	// --- ENTRANCE (v9.19): the shared drop-in (proxy fall on the sky trail,
	// slam, reveal). Still never scene::play the pack's entrance bundle — it
	// spawns a duplicate frozen robot (map 1, live). drop_in restores the
	// base anim rate on impact (the slowed run — user nerf: anim playback
	// scales root motion = ground speed).
	if ( !drop_in( boss, v_ground, ang, TOD_RP_ANIM_RATE ) )
	{
		dbg( "RP lost mid-entrance" );
		return undefined;
	}
	boss PlayLoopSound( "fly_civil_protector_loop" );   // the hover hum (death_watch stops it)
	boss.v_robot_land_position = v_ground;
	level thread zm_zod_robot::zod_robot_play_vox( boss, "activated" );

	tod_boss_fx::attach( boss, 1 );

	boss thread hunt_players();
	boss thread fire_loop();
	// (zap_loop REMOVED 2026-08-20 — user: "he will only have his bullet shot")
	boss thread death_watch();
	boss thread boss_pause_watch( TOD_RP_ANIM_RATE );
	boss thread tod_boss_stuck_watch();   // anti-strand: relocates toward the lowest player

	dbg( "RP up — round " + rn + ", " + hp + " hp @ " + v_ground );
	return boss;
}

// Landing kill-splash: every axis AI in radius EXCEPT bosses dies with a
// ragdoll fling (the pack's splash killed the landing boss itself — the live
// spawn-die-reward loop; and a sibling boss on multi-boss rounds).
function landing_kill_splash( v_origin, e_boss )
{
	level endon( "end_game" );
	n_radius = 350;
	a_ai = GetAITeamArray( "axis" );
	for ( i = 0; i < a_ai.size; i++ )
	{
		ai_zombie = a_ai[ i ];
		if ( !isdefined( ai_zombie ) || !isalive( ai_zombie ) )
			continue;
		if ( isdefined( e_boss ) && ai_zombie == e_boss )
			continue;
		if ( IS_TRUE( ai_zombie.is_boss ) || IS_TRUE( ai_zombie.acc_is_boss ) || IS_TRUE( ai_zombie.acc_is_mini_boss ) )
			continue;
		if ( DistanceSquared( ai_zombie.origin, v_origin ) > n_radius * n_radius )
			continue;

		v_fling = ai_zombie.origin - v_origin;
		v_fling = v_fling + ( 0, 0, 15 );
		v_fling = VectorNormalize( v_fling );
		v_fling = ( v_fling[ 0 ], v_fling[ 1 ], abs( v_fling[ 2 ] ) );
		v_fling = VectorScale( v_fling, 60 );

		ai_zombie DoDamage( ai_zombie.health + 10000, ai_zombie.origin );
		ai_zombie StartRagdoll();
		ai_zombie LaunchRagdoll( v_fling );
	}
}

function landing_rumble()
{
	level endon( "end_game" );
	for ( i = 0; i < 5; i++ )
	{
		players = GetPlayers();
		for ( j = 0; j < players.size; j++ )
		{
			if ( isdefined( players[ j ] ) && isplayer( players[ j ] ) )
				players[ j ] PlayRumbleOnEntity( "damage_heavy" );
		}
		wait 0.1;
	}
}

// RELENTLESS CHASE (map 1): goal re-pinned to the closest player every 0.5s;
// the SPRINT LOCK pins v_robot_land_position far below the map so the BT's
// walk/sprint chooser (>512u from "land position" = sprint) always sprints.
function hunt_players()
{
	self endon( "death" );
	level endon( "end_game" );

	for ( ;; )
	{
		if ( IS_TRUE( self.tod_dropping ) )
		{
			wait 0.5;
			continue;   // drop_in owns the goal until the reveal
		}
		if ( IS_TRUE( level.tod_upgrade_pause ) )
		{
			wait 0.5;
			continue;
		}

		// (map 1's permanent sprint lock — v_robot_land_position pinned far
		// below the map — REMOVED 2026-08-20: base speed, natural gait; the
		// BT walks near his real landing spot and sprints when far.)

		target = undefined;
		best = 999999999;
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isdefined( p ) || !zm_utility::is_player_valid( p ) )
				continue;
			d = DistanceSquared( self.origin, p.origin );
			if ( d < best )
			{
				best = d;
				target = p;
			}
		}

		if ( isdefined( target ) )
		{
			self.favoriteenemy = target;
			self SetGoal( target.origin, 1 );
		}

		wait 0.5;
	}
}

// SCRIPT-DRIVEN FIRE (map 1: the engine's CanShootEnemy() verdict is 0
// permanently for this archetype — so WE pull the trigger). Pattern: 4 chip
// bullets then a real s1_mahem rocket, then a cooldown.
function fire_loop()
{
	self endon( "death" );
	level endon( "end_game" );

	// ZERO-DAMAGE BUG FIX (map 1): the companion AR is AI-only — GetWeapon on
	// its name returns 'none' at runtime and MagicBullet with 'none' throws.
	// The engine-resolved object is on self.weapon — use THAT.
	w = self.weapon;
	if ( !isdefined( w ) || w == level.weaponNone || !isdefined( w.name ) || w.name == "none" )
		w = GetWeapon( "ar_standard_upgraded_companion_zm" );   // last-ditch (guarded at fire)
	n_shots = 0;

	for ( ;; )
	{
		wait TOD_RP_FIRE_INTERVAL;

		if ( IS_TRUE( level.tod_upgrade_pause ) )
			continue;
		if ( IS_TRUE( self.tod_dropping ) )
			continue;   // no shooting from inside the fall

		target = undefined;
		if ( isdefined( self.enemy ) && isplayer( self.enemy ) && zm_utility::is_player_valid( self.enemy ) )
			target = self.enemy;
		else if ( isdefined( self.favoriteenemy ) && isplayer( self.favoriteenemy ) && zm_utility::is_player_valid( self.favoriteenemy ) )
			target = self.favoriteenemy;
		if ( !isdefined( target ) )
			continue;

		if ( Distance( self.origin, target.origin ) > TOD_RP_FIRE_RANGE )
			continue;
		if ( !( self CanSee( target ) ) )
			continue;
		// HORIZONTAL LOS (user 2026-08-23: "the panzer and protectors are
		// shooting through walls"). CanSee above is the archetype's AWARENESS
		// read, not a world trace, so it happily returns true through solid
		// geometry — and the only other gate we had was the VERTICAL one below.
		// Both together still miss the shape this map is actually built from:
		// the CORE is a solid 512-wide column running the full 19,200 units, so
		// a boss and a player at the SAME height on opposite sides of it have a
		// z-delta of ~0 and passed every check. Same for the breather parapets,
		// the arena walls and the crown hall.
		// bHitCharacters = false so ONLY world geometry blocks — the horde
		// standing between the boss and its target never eats a legitimate shot.
		// Traced eye-to-chest, matching the aim point used below.
		if ( !SightTracePassed( self.origin + ( 0, 0, 55 ), target.origin + ( 0, 0, 45 ), false, self ) )
			continue;
		// VERTICAL GATE (user 2026-08-20: "shot through walls, don't see any
		// enemies"): base-spawned bosses must CLIMB to you — never snipe up
		// through the open spiral / splash rockets through the floor slabs.
		if ( Abs( self.origin[ 2 ] - target.origin[ 2 ] ) > TOD_BOSS_FIRE_ZDELTA )
			continue;

		// Muzzle: tag_flash -> tag_weapon_right -> chest fallback.
		v_muzzle = self GetTagOrigin( "tag_flash" );
		if ( !isdefined( v_muzzle ) )
			v_muzzle = self GetTagOrigin( "tag_weapon_right" );
		if ( !isdefined( v_muzzle ) )
			v_muzzle = self.origin + ( 0, 0, 55 );

		// Chest aim + small spread.
		v_aim = target.origin + ( 0, 0, 45 );
		v_aim = v_aim + ( RandomInt( 17 ) - 8, RandomInt( 17 ) - 8, RandomInt( 11 ) - 5 );

		// Re-resolve late-populating self.weapon; HARD-GUARD against 'none'.
		if ( !isdefined( w ) || w == level.weaponNone || !isdefined( w.name ) || w.name == "none" )
		{
			if ( isdefined( self.weapon ) && self.weapon != level.weaponNone && isdefined( self.weapon.name ) && self.weapon.name != "none" )
				w = self.weapon;
		}
		if ( !isdefined( w ) || w == level.weaponNone || !isdefined( w.name ) || w.name == "none" )
			continue;

		// BULLETS ONLY (user 2026-08-20: no rockets, no zap — "only his
		// bullet shot"); the mahem/zap machinery below is retired.
		MagicBullet( w, v_muzzle, v_aim, self );
		tod_boss_fx::shot_pulse( self );
	}
}

// The 5th shot: a real, visible s1_mahem rocket (model, trail, boom). Its raw
// playerDamage would one-shot — hard-capped in boss_player_damage.
function mahem_shot( v_muzzle, v_aim, w )   // self = the boss
{
	w_rocket = GetWeapon( "s1_mahem" );
	if ( isdefined( w_rocket ) && w_rocket != level.weaponNone && isdefined( w_rocket.name ) && w_rocket.name != "none" )
	{
		MagicBullet( w_rocket, v_muzzle, v_aim, self );
		tod_boss_fx::mahem_pulse( self );
		return;
	}
	// Fallback only (s1_mahem unresolvable): exact scripted blast.
	RadiusDamage( v_aim, 180, TOD_RP_MAHEM_DMG, int( TOD_RP_MAHEM_DMG / 3 ), self, "MOD_PROJECTILE_SPLASH", w );
	if ( isdefined( level._effect[ "robot_landing" ] ) )
		PlayFX( level._effect[ "robot_landing" ], v_aim );
	tod_boss_fx::mahem_pulse( self );
}

// Close-range ZAP: every ZAP_INTERVAL, every valid player within ZAP_RANGE
// (no LOS — a proximity burst) gets the slow + a small AoE chip.
function zap_loop()
{
	self endon( "death" );
	level endon( "end_game" );

	for ( ;; )
	{
		wait TOD_RP_ZAP_INTERVAL;

		if ( IS_TRUE( level.tod_upgrade_pause ) )
			continue;

		w_zap = self.weapon;
		if ( !isdefined( w_zap ) || w_zap == level.weaponNone )
			w_zap = GetWeapon( "ar_standard_upgraded_companion_zm" );

		// (the SLOW was removed 2026-08-20 — user: "the stun moves... need to
		// be removed"; the zap is now pure chip damage + FX)
		players = GetPlayers();
		any = false;
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isdefined( p ) || !zm_utility::is_player_valid( p ) )
				continue;
			if ( DistanceSquared( self.origin, p.origin ) > TOD_RP_ZAP_RANGE * TOD_RP_ZAP_RANGE )
				continue;
			any = true;
			p PlaySound( "acc_phantom_zap" );   // the zap SFX stays (no slow)
		}
		if ( !any )
			continue;

		tod_boss_fx::zap_pulse( self );
		if ( TOD_RP_PULSE_DMG > 0 && isdefined( w_zap ) && w_zap != level.weaponNone )
			RadiusDamage( self.origin, TOD_RP_ZAP_RANGE, TOD_RP_PULSE_DMG, TOD_RP_PULSE_DMG, self, "MOD_GRENADE_SPLASH", w_zap );
	}
}

function death_watch()
{
	level endon( "end_game" );

	self waittill( "death", attacker );

	// COOP CRASH GUARD (map 1): the corpse can be reaped the same frame the
	// death notify fires — any self deref then throws and ends the match.
	if ( isdefined( self ) )
		self StopLoopSound();   // the hover hum otherwise loops on the corpse forever

	tod_luck::boss_kill( attacker, "protector" );   // LAST HIT takes the luck
	grant_elite_reward( "ROGUE PROTECTOR", attacker );   // v14.5: killer-only 500
}

// ---------------------------------------------------------------------------
// Shared: pause watch, zap slow, damage plumbing, rewards
// ---------------------------------------------------------------------------

// The upgrade-choice pause freezes all axis AI (set_world_pause: ignoreall +
// anim rate 0.05) — but it only enumerates AI alive AT pause time, and rate
// restore is left to the zombie sweep, which skips bosses by design. This
// watcher is the boss-side symmetric half: it APPLIES the freeze too (covers
// a boss that finished spawning mid-pause) and restores on the unpause edge.
function boss_pause_watch( base_rate )   // self = the boss
{
	self endon( "death" );
	level endon( "end_game" );

	was_paused = false;
	for ( ;; )
	{
		wait 0.25;
		if ( !isdefined( self ) || !isalive( self ) )
			return;
		if ( IS_TRUE( self.tod_dropping ) )
			continue;   // mid-entrance: drop_in owns ignoreall + the anim rate,
			            // and it re-reads tod_upgrade_pause itself on reveal. An
			            // unpause edge landing inside the 2s fall would otherwise
			            // clear ignoreall and restore the rate on a Ghosted,
			            // undamageable boss.
		now = IS_TRUE( level.tod_upgrade_pause );
		if ( now && !was_paused )
		{
			self.ignoreall = true;
			self ASMSetAnimationRate( 0.05 );
		}
		else if ( was_paused && !now )
		{
			self.ignoreall = false;
			self ASMSetAnimationRate( base_rate );
		}
		was_paused = now;
	}
}

// (boss_zap / boss_zap_clear REMOVED 2026-08-20 — the player-slow stun was
// a map-1 mechanic; the user cut it. The zap attack is chip damage + SFX.)

// Player-damage callback: the RP's bullet/rocket lanes (his raw MagicBullet
// damage is uncontrolled — override, ramp by proximity, hard-cap) + the tower
// demigod clamp. Return -1 = no opinion (the chain contract).
function boss_player_damage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime )
{
	if ( !isdefined( iDamage ) || iDamage <= 0 )
		return -1;
	if ( !zm_utility::is_player_valid( self ) )
		return -1;

	// THROUGH-FLOOR SHIELD (user 2026-08-20: "getting shot through walls"):
	// any boss ranged damage from more than ~a floor of height difference is
	// voided — catches rocket/electroball splash bleeding through the 16u
	// walkway slabs from bosses climbing far below (melee is same-level by
	// nature, so this can't eat legitimate hits).
	if ( isdefined( eAttacker ) &&
	     ( IS_TRUE( eAttacker.acc_is_rogue_protector ) || IS_TRUE( eAttacker.acc_is_panzer ) ) &&
	     Abs( eAttacker.origin[ 2 ] - self.origin[ 2 ] ) > TOD_BOSS_FIRE_ZDELTA )
		return 0;

	// THROUGH-WALL SHIELD (user 2026-08-23: "the panzer and protectors are
	// shooting through walls"). The shield above is VERTICAL ONLY — it was
	// written for bosses sniping up through the walkway slabs and cannot see a
	// wall standing beside you. This is the horizontal half, and it lives HERE
	// rather than only in rp_fire_loop because that loop governs OUR scripted
	// attack; the Panzer and the Rogue Protector are vendored archetypes whose
	// OWN behaviour-tree attacks never pass through it. The damage callback is
	// the one chokepoint both lanes must cross.
	//
	// SPLASH TRACES FROM THE BLAST, NOT THE SHOOTER: a rocket that lands
	// legitimately in the open must still hurt even if the boss has since
	// stepped behind cover, so when there is a distinct inflictor we trace from
	// where it actually went off.
	// bHitCharacters = false: only WORLD geometry blocks, so a wall of zombies
	// between the boss and the player can never void a legitimate hit.
	// MELEE IS EXEMPT — a point-blank grab has no meaningful line to trace, and
	// a degenerate trace out of a boss clipped into geometry must never make it
	// harmless.
	// DAMAGE-OVER-TIME IS EXEMPT TOO (verification pass 2026-08-23). The Panzer's
	// FLAMETHROWER applies a burn that keeps ticking after the attack; gating those
	// ticks on line of sight means running behind a wall EXTINGUISHES you, which is
	// not a through-wall fix — it is a silent nerf to one of his two main attacks.
	// A tick has no meaningful line to trace, same argument as melee: fail-OPEN on
	// attacks already landed, fail-CLOSED only on fresh ranged ones.
	//
	// SOURCE HEIGHT MATCHES rp_fire_loop's (+55, verification pass 2026-08-23). It
	// was +45 here against +55 there, so a Rogue Protector could pass the FIRE gate
	// and fail this one — firing with full FX and muzzle flash for exactly zero
	// damage, which reads as broken hit detection rather than as cover working.
	if ( isdefined( eAttacker ) &&
	     ( IS_TRUE( eAttacker.acc_is_rogue_protector ) || IS_TRUE( eAttacker.acc_is_panzer ) ) &&
	     isdefined( sMeansOfDeath ) && sMeansOfDeath != "MOD_MELEE" && sMeansOfDeath != "MOD_BURNED" )
	{
		v_src = eAttacker.origin + ( 0, 0, 55 );
		if ( isdefined( eInflictor ) && eInflictor != eAttacker && isdefined( eInflictor.origin ) )
			v_src = eInflictor.origin;
		if ( !SightTracePassed( v_src, self.origin + ( 0, 0, 45 ), false, eAttacker ) )
			return 0;
	}

	final = iDamage;
	touched = false;

	if ( isdefined( eAttacker ) && IS_TRUE( eAttacker.acc_is_rogue_protector ) && isdefined( sMeansOfDeath ) )
	{
		b_mahem = ( ( isdefined( weapon ) && isdefined( weapon.name ) && IsSubStr( weapon.name, "mahem" ) )
		            || sMeansOfDeath == "MOD_PROJECTILE_SPLASH" );
		if ( b_mahem )
		{
			// ROCKET CAP: keep the engine's blast falloff shape, never exceed
			// the design value + the big knockback.
			if ( final > TOD_RP_MAHEM_DMG ) final = TOD_RP_MAHEM_DMG;
			if ( final < 1 ) final = 1;
			// (mahem knockback removed 2026-08-20 — no RP knockback at all;
			// this cap lane only guards residual splash, rockets are retired)
			touched = true;
		}
		else if ( sMeansOfDeath != "MOD_GRENADE_SPLASH" )
		{
			// BULLETS: override the raw with a fixed base, proximity-ramp it,
			// hard-cap so he can never one-shot.
			final = TOD_RP_BULLET_DMG;
			dist = Distance( eAttacker.origin, self.origin );
			if ( dist <= TOD_RP_CLOSE_RANGE )
				mult = TOD_RP_CLOSE_MULT;
			else if ( dist >= TOD_RP_FAR_RANGE )
				mult = 1.0;
			else
				mult = 1.0 + ( TOD_RP_CLOSE_MULT - 1.0 ) * ( ( TOD_RP_FAR_RANGE - dist ) / ( TOD_RP_FAR_RANGE - TOD_RP_CLOSE_RANGE ) );
			final = int( TOD_RP_BULLET_DMG * mult );
			if ( final > TOD_RP_MAX_DMG ) final = TOD_RP_MAX_DMG;
			if ( final < 1 ) final = 1;
			// (bullet knockback REMOVED — user 2026-08-20 "remove the knock
			// back on the protector shooting"; the mahem rocket keeps its punch)
			touched = true;
		}
		// (MOD_GRENADE_SPLASH = the zap pulse — exact scripted value, untouched.)
	}

	// PANZER electroball +10% (map 1 live tuning 2026-07-18): the 115-grenade
	// explosion is engine/GDT-side — the one Panzer damage source not shaped
	// by the pack's own callbacks, so it gets its lane here.
	if ( isdefined( eAttacker ) && IS_TRUE( eAttacker.acc_is_panzer ) && isdefined( sMeansOfDeath )
	     && IsSubStr( sMeansOfDeath, "GRENADE" ) )
	{
		// electroball, also halved (user 2026-08-20: Panzer hits too hard).
		final = int( final * TOD_PANZER_EXPLOSIVE_MULT * TOD_PANZER_DMG_MULT );
		if ( final < 1 ) final = 1;
		touched = true;
	}

	// DMG REDUCTION domain (the shared upgrade, replaced HEALTH 2026-08-20):
	// -4% per level on ALL incoming damage. Panzer MELEE takes the
	// apply_player_mitigations path instead (the pack's callback
	// short-circuits this chain) — never both, no double-dip.
	dr_lvl = tod_upgrades::get_level( self, "dr" );
	if ( dr_lvl > 0 )
	{
		reduced = int( final * ( 1.0 - 0.05 * dr_lvl ) );   // -5%/Lv (user 2026-08-20)
		if ( reduced < 1 )
			reduced = 1;
		if ( reduced != final )
		{
			final = reduced;
			touched = true;
		}
	}

	// SPRINT ARMOR (domain 32, session f2e3ffc8 2026-08-23): -5%/Lv while the
	// player is actually sprinting THIS INSTANT. Multiplies AFTER the DR domain,
	// so the two stack multiplicatively rather than summing to a bigger flat cut
	// (tod_upgrades::sprint_armor_mult returns 1.0 when not sprinting, when the
	// domain is unowned, or for a non-player, and floors at 0.05).
	sa = tod_upgrades::sprint_armor_mult( self );
	if ( sa < 1.0 )
	{
		reduced = int( final * sa );
		if ( reduced < 1 )
			reduced = 1;
		if ( reduced != final )
		{
			final = reduced;
			touched = true;
		}
	}

	// BACK ARMOR (domain 36, v9.45): -10%/Lv when eAttacker is inside the rear
	// arc of this player's view. Same shape and the same slot as SPRINT ARMOR,
	// so all three defensive domains stack MULTIPLICATIVELY rather than summing
	// into one flat cut (DR Lv10 + SPRINT ARMOR Lv5 + BACK ARMOR Lv3, all at
	// once and from behind while sprinting, is 0.5 x 0.75 x 0.7 = x0.2625 —
	// deep, but it takes three maxed cards and a specific situation to reach).
	// The attacker is passed in because "behind" is a bearing, not a state.
	ba = tod_upgrades::back_armor_mult( self, eAttacker );
	if ( ba < 1.0 )
	{
		reduced = int( final * ba );
		if ( reduced < 1 )
			reduced = 1;
		if ( reduced != final )
		{
			final = reduced;
			touched = true;
		}
	}

	// Tower demigod (level.tod_god): damage lands for real, health floors at
	// 1 HP. Same clamp shape as map 1's acc_god.
	if ( IS_TRUE( level.tod_god ) )
	{
		if ( final >= self.health )
			final = self.health - 1;
		if ( final < 0 )
			final = 0;
		return final;
	}

	if ( touched && final != iDamage )
		return final;
	return -1;
}

// One horizontal impulse away from the boss + a small pop of lift (the stock
// jump-pad idiom — reads as recoil, not a launch).
function rp_knockback( boss, strength, z_pop )   // self = the hit player
{
	if ( !isdefined( self ) || !isplayer( self ) || !isdefined( boss ) )
		return;
	if ( strength <= 0 )
		return;

	dir = self.origin - boss.origin;
	dir = ( dir[ 0 ], dir[ 1 ], 0 );
	if ( LengthSquared( dir ) < 1 )
		dir = AnglesToForward( ( 0, self.angles[ 1 ] + 180, 0 ) );
	dir = VectorNormalize( dir );

	self SetVelocity( self GetVelocity() + VectorScale( dir, strength ) + ( 0, 0, z_pop ) );
}

// AI-damage feed ON the Rogue Protector (aiOverrideDamage — stock dispatches
// it AFTER check_actor_damage_callbacks in the same event). Whether the
// zombie-archetype chain (upgrade_damage_cb) fires for this archetype is
// engine-dependent — so this feed is the FALLBACK: if the chain stamped this
// exact event (tod_actor_cb_ms == now), the multipliers + crosshair number
// are already handled and we pass through untouched; otherwise we apply them
// here, mirroring upgrade_damage_cb's shape (constants duplicated — sync).
function rp_damage_feed( inflictor, attacker, damage, flags, meansOfDeath, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex )
{
	if ( !isdefined( attacker ) || !isplayer( attacker ) )
		return damage;

	// [tod] Gift of Death: fixed 10 shots on the Rogue Protector. MUST precede
	// the tod_actor_cb_ms early-return below (upgrade_damage_cb stamps that
	// field unconditionally, which would otherwise skip this branch). Same
	// damage>0 + same-frame dedupe guard as the Panzer wrap (verify 2026-08-20).
	if ( isdefined( weapon ) && isdefined( weapon.name ) && IsSubStr( weapon.name, "xmas_gun" ) && isdefined( damage ) && damage > 0 )
	{
		now = GetTime();
		if ( isdefined( self.tod_xmas_hit_ms ) && self.tod_xmas_hit_ms == now )
			return 1;
		self.tod_xmas_hit_ms = now;
		return int( ( self.maxhealth / TOD_XMAS_RP_SHOTS ) * TOD_XMAS_ELITE_BUFF ) + 1;
	}

	if ( isdefined( self.tod_actor_cb_ms ) && self.tod_actor_cb_ms == GetTime() )
		return damage;   // the actor chain already ran for this event

	b_head = ( isdefined( hitLoc ) && ( hitLoc == "head" || hitLoc == "helmet" || hitLoc == "neck" )
	           && ( !isdefined( meansOfDeath ) || !IsSubStr( meansOfDeath, "MELEE" ) ) );

	// ---------------------------------------------------------------------
	// HAND-COPIED CONSTANTS — READ THIS BEFORE TUNING.
	// The upgrade constants are `#define`s in _tod_upgrades.gsc, and a GSC
	// #define is FILE-LOCAL (there is no project .gsh — only stock
	// shared.gsh is #insert'd). So this fallback lane cannot reference them
	// symbolically the way the actor chain (upgrade_damage_cb, in that same
	// file) does, and carries literal copies instead.
	//
	// THAT HAS ALREADY BITTEN ONCE: the 2026-08-22 headshot nerf changed
	// TOD_UPG_HS_PER_LVL 0.10 -> 0.04 in _tod_upgrades.gsc but missed the
	// copy here, so from then until 2026-08-23 a headshot on the Rogue
	// Protector paid 2.5x the intended bonus (+10%/Lv instead of +4%/Lv,
	// i.e. +100% vs +40% at Lv10) on whichever lane fired. The `// =` comments
	// asserted an equality that had silently stopped being true.
	//
	// If you change TOD_UPG_DMG_PER_LVL or TOD_UPG_HS_PER_LVL, change the
	// literals below IN THE SAME COMMIT and re-check these comments.
	// Source of truth: the #defines TOD_UPG_DMG_PER_LVL and TOD_UPG_HS_PER_LVL
	// in _tod_upgrades.gsc. Grep those NAMES — do not cite a line number, that
	// file changes often and the number rots (it already did while this fix
	// was being written).
	// ---------------------------------------------------------------------
	final = int( damage );
	// EVERY WEAPON takes this lane now (user 2026-08-23 widening). It used to
	// split: class primary got DAMAGE + HEADSHOT + GIANT SLAYER, everything else
	// got a DAMAGE-only else-branch. Both halves computed the same shape, so the
	// split only ever meant "your sidearm loses two domains against the one
	// enemy type they matter most against". Merged.
	if ( isdefined( weapon ) )
	{
		mult = 1.0 + tod_upgrades::get_level( attacker, "damage" ) * 0.12;   // copy of TOD_UPG_DMG_PER_LVL — verified equal 2026-08-23
		if ( b_head )
			mult += tod_upgrades::get_level( attacker, "headshot" ) * 0.04;  // copy of TOD_UPG_HS_PER_LVL — 0.10 -> 0.04 (2026-08-22) -> 0.03 (v9.45) -> 0.04 (2026-08-26 assault buff); this copy has gone stale once already
		// GIANT SLAYER (domain 35, v9.45; 4%/Lv since 2026-08-26): +4%/Lv against the boss/elite triad,
		// and self IS a boss here. NOT a hand-copied literal — it comes through
		// tod_upgrades::boss_damage_bonus, which owns the constant AND the triad
		// test. That is the whole point: the two literals above this line are
		// the reason this lane needed a comment block warning about drift, so a
		// new one gets a function call instead.
		mult += tod_upgrades::boss_damage_bonus( attacker, self );
		// (ECHO ROUNDS removed 2026-08-23 — this lane carried its own copy of
		// the roll, so it had to be deleted here too or the domain would have
		// kept firing on this path alone.)
		// MELEE vs BOSSES (user 2026-08-24): halved. `self` IS a boss on this
		// lane, so the test that matters is "was this a melee hit" — but the
		// call still passes self, because melee_boss_mult owns BOTH halves and
		// this file is the one that has already shipped a stale hand-copied
		// constant. Do not inline the 0.5. b_head above already excludes melee,
		// so a melee hit reaching here carries no headshot bonus to scale.
		is_melee = ( isdefined( meansOfDeath ) && IsSubStr( meansOfDeath, "MELEE" ) );
		mult = mult * tod_upgrades::melee_boss_mult( self, is_melee );
		final = int( damage * mult );
	}

	attacker tod_upgrade_ui::push_dmg_num( final, b_head );
	return final;
}

// (Music lives in _tod_atmosphere — the ambient loop is the base state and
// the PANZER's boss_track_start/end swap the channel. Refcount + the
// stoppable-loop primitive are all in that module.)

// BOSS down (the PANZER only, since v14.5): POINTS to every player
// (team-wide); LUCK goes to the LAST HIT only (user 2026-08-20) via
// tod_luck::boss_kill at the call sites. quiet = no per-kill banner.
function grant_boss_reward( name, pts, quiet )
{
	// (kill text removed 2026-08-20 — points award silently; the drop tells)
	players = GetPlayers();
	foreach ( p in players )
	{
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		p zm_score::add_to_player_score( pts );
	}
}

// ELITE down (v14.5 — the user quote at the TOD_ELITE_PTS define): the flat
// 500 goes to THE KILLER ALONE, scaled by
//   1. DOUBLE POINTS — level.zombie_vars[team]["zombie_point_scalar"], the
//      exact multiplier stock applies to normal kill money (_zm_score.gsc:341,
//      set 2/1 by _zm_powerup_double_points.gsc:79/:97), and
//   2. the BOUNTY domain — 1.0 + 5%/Lv via level.tod_bounty_mult_fn (the
//      pointer pattern tod_bounty_preview_fn established; no _tod_upgrades
//      import from this module, no cycle). Weapon-agnostic like the widened
//      domain itself.
// NO KILLER = NO MONEY, on purpose ("Only the person who kills gets the
// money"): an elite reaped by cleanup, a trap, another boss or the void pays
// nobody. `attacker` comes from each module's waittill("death", attacker)
// watcher — all four elite watchers carry it. Callers: the Rogue Protector
// death_watch below, _tod_reaver, _tod_hellhounds, _tod_sprinter. Silent
// like every kill payout since 2026-08-20 (the score delta tells).
function grant_elite_reward( name, attacker )
{
	if ( !isdefined( attacker ) || !isplayer( attacker ) )
		return;

	pts = TOD_ELITE_PTS;
	if ( isdefined( attacker.team )
	  && isdefined( level.zombie_vars[ attacker.team ] )
	  && isdefined( level.zombie_vars[ attacker.team ][ "zombie_point_scalar" ] ) )
	{
		pts = pts * level.zombie_vars[ attacker.team ][ "zombie_point_scalar" ];
	}
	if ( isdefined( level.tod_bounty_mult_fn ) )
		pts = pts * [[ level.tod_bounty_mult_fn ]]( attacker );

	attacker zm_score::add_to_player_score( int( pts ) );
}
