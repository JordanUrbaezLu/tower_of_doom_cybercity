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
//    boss_pause_watch RE-ASSERTS the freeze every tick while it holds (v17.94
//    — an edge stamp lost to the Fury's own rate writers), parks a Fury's
//    behaviour tree at idle (tod_bt_idle_on_pause -> zombie_think_done), and
//    restores each boss's anim rate on unpause; every script attack loop
//    gates on level.tod_upgrade_pause.
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
#using scripts\zm\zm_tower_of_doom\_tod_door_data;    // v18.76 — get_door_info (the door frontier; GENERATED leaf module, no cycle)
#using scripts\zm\zm_tower_of_doom\_tod_spire_data;   // in_box (v16.15 sealed-ring boss containment; leaf module, no cycle)
#using scripts\zm\zm_tower_of_doom\_tod_corpse_cleanup; // v17.96 — corpse_remove: a dead Protector leaves the actor pool (stock-only usings, no cycle)
// v14.48 — finale_roll_band / finale_road_y0 / finale_road_y1: ELITES follow the
// same three-band road distribution as the horde, from the same roll, so the two
// can never drift apart. One-way edge, verified: _tod_endless_rounds imports only
// shared modules and GENERATED leaf data modules, never this one.
#using scripts\zm\zm_tower_of_doom\_tod_endless_rounds;
#using scripts\zm\zm_tower_of_doom\_tod_classes;
#using scripts\zm\zm_tower_of_doom\_tod_upgrades;
#using scripts\zm\zm_tower_of_doom\_tod_upgrade_ui;

// THE KILL-FEED LABELS (v17.47, 2026-09-04). The three rows grant_elite_reward /
// grant_boss_reward send (v17.37) were NEVER precached, so every one of them
// reached the feed as an empty name: the user saw "+750" on a spire guard
// Panzer and "+50 ZOMBIE DOG" (the kit's own row) on a hound, with our ELITE
// row printing beside it blank. The kit precaches all fifteen of ITS labels in
// _zm_aetherium_hud.gsc; ours have to be precached HERE, in the module that
// sends them. And they MUST sit here, after ALL #using/#insert directives:
// between them it kills the compile with "No generated data" — live 2026-08-20.
#precache( "string", "ZM_AETHERIUM_KF_ELITE" );
#precache( "string", "ZM_AETHERIUM_KF_BOSS" );
#precache( "string", "ZM_AETHERIUM_KF_TRIAL" );

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
// ---- RAMPAGE INDUCER (v14.20) --------------------------------------------
// "Double the elites there would normally be" (user 2026-08-30). Consumed ONLY
// by elite_mult(); see the block comment there for why this scales DEBT and the
// DEBT CLAMP and never a concurrency roof.
#define TOD_RAMPAGE_ELITE_MULT   2
// THE COMBINED ELITE ROOF, enforced on every director by elites_over_roof()
// and read directly by _tod_spire's Warden loop through elite_roof_all().
//
// PARTY-AWARE SINCE v18.1 — 5 / 7 / 9 / 11 (user 2026-09-06: "elites at once
// we can drop so 5 solo, 7 duo, 9 trio, 11 quads", answering a solo-vs-trio
// audit). It was FLAT 12 from v14.20, and the note that shipped with it read
// "FLAT, not per-player, deliberately: the per-type roofs already scale with
// party size, so the combined figure is the one thing that must not." That
// reasoning protected the ACTOR POOL, which is a quad-sized worry, and in
// doing so it made the roof the map's single worst solo penalty: a lone
// player could face all 12 at once, the same wall a quad splits four ways —
// 12 elites per player against 3. Every other lever is per-player or close
// to it, so this one was tripling solo pressure on its own.
//
// THE ACTOR-POOL ARGUMENT STILL HOLDS AT THE TOP END, which is why quad only
// drops 12 -> 11: the original worst case was 1 panzer + 8 protectors + 3
// reavers + 6 hounds = 18 live elites at quad, ~63 actors against
// TOD_ACTOR_LIMIT 60. 11 is under the 12 that fixed it, so nothing regresses.
//
// WHAT ELSE MOVES, because three spire lanes share this ceiling and none of
// them is a director: door_guard_panzers, king_summons and trial_adds all
// skip while over the roof. So a SOLO Warden Trial and a SOLO Warden King
// fight get materially thinner — the trial's Wardens claim their slots first
// (level.tod_trial_reserve), leaving ~3 adds standing where 10 used to fit.
// That is the intended direction, but it is the biggest single feel change
// in this edit and the first solo run should be read with it in mind.
// The FINALE is exempt as it always was (elites_over_roof returns false
// under tod_finale_aggro / tod_finale_holdout), so the road ambush is
// untouched at every party size.
#define TOD_ELITE_ROOF_SOLO     5     // one player
#define TOD_ELITE_ROOF_PER      2     // per extra player: 5 / 7 / 9 / 11
// RAMPAGE (v18.74, user 2026-09-10: "Rampage increases elites at once by 3").
// Added by elite_roof_all() while the breaker is thrown: 8 / 10 / 12 / 14.
// Until now rampage doubled elite THROUGHPUT (elite_mult) but shared the base
// game's roof, so v18.1's 12 -> 5/7/9/11 relief thinned hard mode too — the
// user's 2026-09-10 report that rampage "feels easier". Quad lands at 14, over
// the 12 the actor-pool note above was protecting; the pool overflow is the
// documented-safe kind (stock clears corpses and waits), not a crash.
#define TOD_RAMPAGE_ELITE_ROOF_ADD 3
#define TOD_ELITE_CORPSE_LINGER 5.0   // v17.96 — seconds a dead Protector / Reaver body stays before Delete (trash: 2.0)
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
// RAMPAGE INDUCER (v14.27, user 2026-08-30: "Rampage should also spawn in 2
// panzers during boss rounds"). The ONE place this feature raises a concurrency
// roof, and it is a deliberate exception to the doctrine above — read
// panzer_max_alive() before touching it.
#define TOD_RAMPAGE_PANZER_MAX   2
// RAMPAGE HP (v14.25, user: "all elites and bosses get 1.25x health on
// rampage"; v18.74, user 2026-09-10: "Elites panzer and zombies health
// increase by 20%" — 1.25 x 1.20 = 1.5, a delta on the rampage figure, the
// same reading as the "+3 elites" and "+10 zombies" asks beside it). Applied in
// boss_hp() for the Panzer/Protector/Reaver/Hound, and re-read by _tod_sprinter
// for the one elite that does not come through there. The HORDE's own rampage
// health lives in _tod_zombie_speed (TOD_RAMPAGE_ZHEALTH_MULT), not here.
// LOCKSTEP: _tod_sprinter.gsc calls tod_bosses::rampage_hp_mult(), so this is
// still ONE constant with one owner — do not inline 1.5 anywhere.
#define TOD_RAMPAGE_HP_MULT      1.5
// THE ENDLESS SPIRE ELITE MULTIPLIER (v14.31, user 2026-08-30 after the first
// real spire run: "The endless spire is too easy. We need to add way more
// elites ... I would say 4x the elites of what we currently have").
// Read by elite_mult() ONLY — same debt/clamp lane as rampage, so it obeys the
// same doctrine: throughput scales, CONCURRENCY DOES NOT (TOD_ELITE_ROOF_ALL
// still bounds the standing count in every mode, spire included). What 4x
// actually buys is SATURATION: the roof refills the instant a slot frees,
// instead of the roof being touched once a wave and decaying.
#define TOD_SPIRE_ELITE_MULT     4
// THE LAST MILE: how far AHEAD of the player the Panzer's spawn query anchors.
// 700 is far enough that he materialises down the road rather than on top of
// you (his own clearance in pick_spawn_point is 400/800), and close enough that
// he is a wall you must deal with rather than distant scenery.
#define TOD_PANZER_FRONT_DIST    700
// v14.47 — how far BACK down the road from the citadel gate the crown-end elite
// anchor sits. The gate opening is geometry; anchoring on it would spend
// pick_spawn_point's 400u first pass querying a doorway. 480 puts the anchor on
// open deck just outside it, inside that first pass. See finale_far_anchor().
#define TOD_FINALE_FAR_ANCHOR_BACK 480
// dev (level.tod_dev): panzer arrives early for test sessions
// RETIRED v16.87 (dev must not change the cadence): TOD_PANZER_FIRST_DEV 3
// RETIRED v16.87: TOD_PANZER_INT_DEV 3

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
// THE ELITE HP KNOB (v18.2, user 2026-09-06: "we need to reduce the health of
// elites by ten percent ... the hellhound or dog is an elite").
//
// ONE OWNER FOR FOUR ELITES: the Rogue Protector, the Reaver and the Hellhound
// (all three scale the value boss_hp hands back) and the Armored Sprinter,
// which never comes through boss_hp at all - it converts a horde zombie and
// scales the trash HP, so it re-reads this the same way it already re-reads
// rampage_hp_mult. Read it through elite_hp_mult(); never re-spell the 0.90.
//
// THE PANZER IS DELIBERATELY OUT OF THIS CUT. This map's own vocabulary splits
// the two sets - grant_elite_reward pays "every ELITE (Protector/Reaver/Hound/
// Sprinter)" a flat 500 and the PANZER alone keeps the boss jackpot - and the
// same message asked for melee to improve "against those elites and bosses",
// i.e. naming them as two different things. If that reading was wrong, putting
// the Panzer in is ONE line: spawn_panzer's boss_hp call site. Do NOT "fix" it
// by moving the multiplier inside boss_hp - see elite_hp_mult() for why.
#define TOD_ELITE_HP_MULT        0.90
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
// MELEE vs THE PANZER ONLY (v15, 2026-09-01 — user: "Just give a 2x buff to
// panzer only"). Applied on the melee pass-through in tod_mechz_damage_wrap,
// which is the Panzer's own damage lane, so it CANNOT leak onto the Reaver, the
// Rogue Protector or the hellhounds - they share the TOD_MELEE_BOSS_MULT pair
// in _tod_upgrades.gsc but never reach that function.
//
// THIS BUFF IS CLASS-BLIND, and that is the one thing to know about it: it is
// scoped to the PANZER'S damage lane, so it doubles a heavy's bare knife just
// as it doubles a slasher's blade. The v18.3 +75% is the opposite - scoped to
// the SLASHER at every victim. Combined, melee on a Panzer pays
// 0.5775 x 2.0 = 1.155 for a slasher and 0.33 x 2.0 = 0.66 for anyone else;
// on every other elite it is 0.5775 and 0.33. READ THE CONSTANTS, do not trust
// these products - they are two knobs that move independently and this line
// has been stale once already. Note the slasher product is ABOVE 1.0: its
// blade hits a Panzer for slightly more than its raw number, which is what the
// +75% arithmetically is on top of this x2, not an oversight.
// Deliberately a SECOND multiplier rather than a change to the shared one —
// the user's call, and the only way to make it Panzer-specific without a
// per-enemy table nothing else needs.
#define TOD_MELEE_PANZER_BUFF    2.0
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
// HELLHOUND BITE (v18.2, user 2026-09-06: "we need to reduce the damage of the
// dog by twenty percent"). The bite is stock behavior_zombie_dog melee - the
// archetype exposes no per-attack damage number to author, so the shared
// player-damage callback is the only chokepoint the hit crosses. Applied in
// boss_player_damage below.
#define TOD_HOUND_DMG_MULT        0.80
#define TOD_BOSS_FIRE_ZDELTA     300   // boss ranged attacks only within ~1 floor of height (no through-floor sniping)

// --- spawn placement --------------------------------------------------------
#define TOD_BOSS_CLEARANCE       150   // min distance from every living boss
#define TOD_XMAS_PANZER_SHOTS    20    // Gift of Death shots to kill a Panzer (user 2026-08-21, was 30)
#define TOD_XMAS_RP_SHOTS        6     // ...and a Rogue Protector (user 2026-08-21, was 10)
// ...AND THE WARDEN KING, who needed his own number the moment he existed
// (v18.7, user 2026-09-07: "The final warden boss should not be impacted by
// gift of death either. Gift of death should do 1/400th of his health per hit.
// We were accidently able to finish him in like 1 minute because someone had
// the death machine").
//
// THE BUG IN ONE LINE: the Gift's slice is a FRACTION OF MAX HEALTH, not a
// damage number, so it is round-independent BY DESIGN — and that design is
// exactly what made a 100,000,000 HP boss die in ~16 shots. Every health wall
// this map builds is invisible to it. The King is the first enemy whose whole
// identity is that wall, so he gets his own divisor rather than a carve-out:
// 400 shots, the user's figure, applied to HIS max health so it still scales
// with party size.
//
// TOD_XMAS_ELITE_BUFF IS DELIBERATELY NOT APPLIED to this one. "1/400th of his
// health per hit" is an exact instruction; the +30% would quietly make it
// 1/307th. If the King is ever meant to feel the elite buff, that is a separate
// ask with a separate number.
#define TOD_XMAS_KING_SHOTS      400
// v14.8 (user 2026-08-30: "buff the death machine by 30% for bosses and
// elites") — multiplies the per-shot slice at both sites below, so the shot
// counts above stay the readable historical baseline (effective: Panzer
// ~15.4 -> 16 shots, RP ~4.6 -> 5). LOCKSTEP: must equal XMAS_ELITE_BUFF in
// _tod_powerups.gsc, which owns the Reaver/hellhound Gift lanes.
#define TOD_XMAS_ELITE_BUFF      1.56   // v19.63: 1.3 x 1.2 (user: Gift of Death +20% on elites)
#define TOD_BOSS_ZONE_CHECKS     12    // max get_zone_from_position calls per spawn pick (each spawns a temp entity)
// v18.76 — THE DOOR FRONTIER (the v18.9 "boss behind an unbought door" finding,
// left out of that pass as its one regression risk; user 2026-09-10: fix it).
// Lap zone volumes overhang the next lap by 200 units, so the sealed flight
// above an unbought door reads as an ENABLED zone to get_zone_from_position
// and the zone gate in pick_spawn_point lets an elite land where nobody can
// reach it. The doors themselves are the authority: door n sits on the landing
// at lap n's floor (its generated org is 40 up from that floor), so any
// candidate whose feet are above the LOWEST unbought door's floor is behind
// it. The lift keeps that landing itself legal (navmesh points sit AT floor z;
// the first tread past the slab is 12 up). TOWER ONLY: the spire is boxed by
// in_spire / trial_box and its doors are a different chain.
#define TOD_BOSS_FRONTIER_DOOR_Z 40    // door org z above its landing floor (gen_tower_map: door centre height)
#define TOD_BOSS_FRONTIER_LIFT   4
#define TOD_BOSS_FRONTIER_LAPS   50    // enter_lap1..50, then enter_roof
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
// v18.96 — THE PERK BOTTLE (user 2026-09-13: "elite kills have a 10% chance of
// dropping a perk bottle on death"). Every elite death that pays the killer
// rolls this on the corpse's spot; the drop is the map's own `tod_free_pap`
// powerup (the perk-bottle model that grants a random MAP-TRUTH perk, or max
// ammo + luck when every sellable perk is held). Tower only — in the spire
// every perk is perma-granted, so a bottle there is pure consolation; and
// behind the same power gate every bottle drop in this map obeys.
#define TOD_ELITE_BOTTLE_PCT     10

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
	if ( IS_TRUE( level.tod_dev ) )
		level thread dev_ai_watch();
}

// Console-only diagnostics (2026-09-10: intermittent elite tracking stalls).
// Diagnostic readers only. All recorder writes use tod_ai_diag_* fields.
// Do not use CalcApproximatePathToPosition: it clears the actor's current path.
function dbg( msg )
{
	if ( IS_TRUE( level.tod_dev ) ) dev_ai_log( "EVENT " + msg );
}

function dev_ai_log( msg )
{
	// The native loader REQUIRES this block for PrintLn, even in a devmap.
	// Keep literal assembly outside it: mod devblock literals were blank in
	// the native console, while an already-built string is retained intact.
	line = "[TOD_AI] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}

function dev_ai_gate( ent, action )
{
	if ( !IS_TRUE( level.tod_dev ) || !isdefined( ent ) ) return;
	dev_ai_log( "EVENT GATE action=" + action + " id=" + dev_ai_ent( ent )
		+ " name=" + dev_ai_value( ent.targetname ) + " pos=" + dev_ai_pos( ent.origin ) );
}

function dev_ai_value( value )
{
	if ( !isdefined( value ) ) return "-";
	return "" + value;
}

function dev_ai_pos( org )
{
	if ( !isdefined( org ) ) return "-";
	return "(" + ( int( org[ 0 ] * 10 ) / 10.0 ) + "," + ( int( org[ 1 ] * 10 ) / 10.0 ) + "," + ( int( org[ 2 ] * 10 ) / 10.0 ) + ")";
}

function dev_ai_ent( ent )
{
	if ( !isdefined( ent ) ) return -1;
	return ent GetEntityNumber();
}

function dev_ai_age( stamp )
{
	if ( !isdefined( stamp ) ) return -1;
	return GetTime() - stamp;
}

function dev_ai_entities( ents )
{
	if ( !isdefined( ents ) ) return "-";
	result = "[";
	foreach ( ent in ents ) result += dev_ai_ent( ent ) + ",";
	return result + "]";
}

function dev_ai_kind( ai )
{
	if ( IS_TRUE( ai.tod_is_sprinter ) ) return "sprinter";
	if ( isdefined( ai.tod_boss_kind ) ) return ai.tod_boss_kind;
	return "ordinary";
}

function dev_ai_flags( ai )
{
	return " ignoreall=" + dev_ai_value( ai.ignoreall ) + " ignoreme=" + dev_ai_value( ai.ignoreme )
		+ " pacifist=" + dev_ai_value( ai.pacifist ) + " frozen=" + dev_ai_value( ai.tod_frozen )
		+ " ignore_flesh=" + dev_ai_value( ai.ignore_find_flesh )
		+ " dropping=" + dev_ai_value( ai.tod_dropping ) + " parked=" + dev_ai_value( ai.tod_bt_parked )
		+ " think=" + dev_ai_value( ai.zombie_think_done ) + " in_ground=" + dev_ai_value( ai.in_the_ground )
		+ " eslow=" + dev_ai_value( ai.tod_eslow_mult ) + " web=" + dev_ai_value( ai.b_widows_wine_slow )
		+ " cocoon=" + dev_ai_value( ai.b_widows_wine_cocoon );
}

function dev_ai_world()
{
	stock_pause = undefined;
	if ( level flag::exists( "world_is_paused" ) ) stock_pause = level flag::get( "world_is_paused" );
	return " round=" + dev_ai_value( level.round_number ) + " dev=" + dev_ai_value( level.tod_dev )
		+ " god=" + dev_ai_value( level.tod_god ) + " dev_doors=" + dev_ai_value( level.tod_dev_doors )
		+ " spire=" + dev_ai_value( level.tod_spire_active ) + " trial=" + dev_ai_value( level.tod_trial_active )
		+ " hub=" + dev_ai_value( level.tod_trial_hub ) + " pause=" + dev_ai_value( level.tod_upgrade_pause )
		+ " seal=" + dev_ai_value( level.tod_spire_trial_seal ) + " frenzy=" + dev_ai_value( level.tod_trial_frenzy )
		+ " stock_pause=" + dev_ai_value( stock_pause ) + " tp=" + dev_ai_value( level.tod_tp_stamp )
		+ " pause_on_ms=" + dev_ai_value( level.tod_ai_diag_pause_on ) + " pause_off_ms=" + dev_ai_value( level.tod_ai_diag_pause_off )
		+ " rampage=" + dev_ai_value( level.tod_rampage_on );
}

function dev_ai_player_flags( p )
{
	return " valid=" + zm_utility::is_player_valid( p ) + " targetable=" + zm_utility::is_player_valid( p, true )
		+ " notarget=" + p IsNoTarget() + " ignore=" + dev_ai_value( p.ignoreme )
		+ " ignore_count=" + dev_ai_value( p.ignorme_count ) + " blood=" + dev_ai_value( p.tod_in_blood )
		+ " ai_ignore_counter=" + dev_ai_value( p.ignore_counter )
		+ " state=" + dev_ai_value( p.sessionstate );
}

// Scan transitions at 500 ms; full context every 2 s. All species is explicit:
// the API's omitted species defaults to human, missing dogs and robots.
// Log ordinary actors too so native entity-number errors have a family and
// moving controls. The per-actor first-seen time disambiguates reused slots.
function dev_ai_watch()
{
	level endon( "end_game" );
	dev_ai_log( "START schema=2 build=20260910f scan_ms=500 detail_ms=2000 species=all" );
	previous = [];
	last_world = "";
	last_tick = GetTime();
	next_detail = 0;
	for ( ;; )
	{
		wait 0.5;
		if ( !IS_TRUE( level.tod_dev ) ) return;
		started = GetTime();
		detail = started >= next_detail;
		if ( detail ) next_detail = started + 2000;
		world_state = dev_ai_world();
		if ( detail || world_state != last_world ) dev_ai_log( "WORLD" + world_state );
		last_world = world_state;
		players = GetPlayers();
		foreach ( p in players )
		{
			if ( !isdefined( p ) || !isplayer( p ) ) continue;
			flags = dev_ai_player_flags( p );
			if ( !detail && isdefined( p.tod_ai_diag_flags ) && flags == p.tod_ai_diag_flags ) continue;
			p.tod_ai_diag_flags = flags;
			blood_left = undefined;
			if ( isdefined( p.zombie_vars ) ) blood_left = p.zombie_vars[ "zombie_powerup_zombie_blood_time" ];
			dev_ai_log( "PLAYER id=" + dev_ai_ent( p ) + " pos=" + dev_ai_pos( p.origin ) + flags
				+ " hp=" + p.health + " blood_left=" + dev_ai_value( blood_left )
				+ " lastnav=" + dev_ai_pos( p.last_valid_position )
				+ " mesh=" + dev_ai_pos( GetClosestPointOnNavMesh( p.origin, 64, 30 ) ) );
		}
		actors = GetAISpeciesArray( "all", "all" );
		current = [];
		seen = [];
		alive_count = 0;
		elite_count = 0;
		foreach ( ai in actors )
		{
			if ( !isdefined( ai ) || !isalive( ai ) ) continue;
			alive_count++;
			id = dev_ai_ent( ai );
			kind = dev_ai_kind( ai );
			elite = kind != "ordinary";
			if ( elite ) elite_count++;
			fresh = !isdefined( ai.tod_ai_diag_born );
			if ( fresh )
			{
				ai.tod_ai_diag_born = started;
				ai.tod_ai_diag_moved = started;
				ai.tod_ai_diag_anchor = ai.origin;
				dev_ai_log( "APPEAR id=" + id + " born_ms=" + started + " kind=" + kind
					+ " pos=" + dev_ai_pos( ai.origin ) + " species=" + dev_ai_value( ai.species )
					+ " archetype=" + dev_ai_value( ai.archetype ) + " team=" + dev_ai_value( ai.team ) );
			}
			// Accumulated displacement, so slow movement is not mislabeled stationary.
			if ( DistanceSquared( ai.origin, ai.tod_ai_diag_anchor ) >= 64 )
			{
				ai.tod_ai_diag_moved = started;
				ai.tod_ai_diag_anchor = ai.origin;
			}
			stamp = spawnstruct();
			stamp.id = id;
			stamp.born = ai.tod_ai_diag_born;
			stamp.ent = ai;
			stamp.kind = kind;
			stamp.org = ai.origin;
			current[ current.size ] = stamp;
			seen[ id ] = stamp.born;
			has_path = ai HasPath();
			flags = " kind=" + kind + " path=" + has_path + " fav=" + dev_ai_ent( ai.favoriteenemy )
				+ " enemy=" + dev_ai_ent( ai.enemy ) + dev_ai_flags( ai );
			if ( elite ) flags += " rate=" + ai GetEntityAnimRate() + " script=" + dev_ai_value( ai.scriptstate );
			changed = !isdefined( ai.tod_ai_diag_flags ) || flags != ai.tod_ai_diag_flags;
			ai.tod_ai_diag_flags = flags;
			if ( !detail && !fresh && !changed ) continue;
			tag = "ACTOR id=" + id + " born_ms=" + stamp.born;
			if ( elite ) tag = "ELITE id=" + id + " born_ms=" + stamp.born;
			dev_ai_log( tag + " pos=" + dev_ai_pos( ai.origin ) + " still_ms=" + ( started - ai.tod_ai_diag_moved )
				+ " hp=" + ai.health + flags );
			if ( elite ) dev_ai_detail( ai, players, has_path, detail );
		}
		foreach ( old in previous )
		{
			if ( isdefined( seen[ old.id ] ) && seen[ old.id ] == old.born ) continue;
			reason = "removed";
			if ( isdefined( old.ent ) && !isalive( old.ent ) ) reason = "dead";
			if ( isdefined( seen[ old.id ] ) ) reason = "slot_reused";
			dev_ai_log( "GONE id=" + old.id + " born_ms=" + old.born + " kind=" + old.kind
				+ " reason=" + reason + " lastpos=" + dev_ai_pos( old.org ) );
		}
		previous = current;
		elapsed = GetTime() - started;
		if ( detail || elapsed > 100 || started - last_tick > 1000 )
			dev_ai_log( "TICK gap_ms=" + ( started - last_tick ) + " cost_ms=" + elapsed
				+ " actors=" + actors.size + " live=" + alive_count + " elites=" + elite_count
				+ " ai_limit=" + dev_ai_value( level.zombie_ai_limit ) + " actor_limit=" + dev_ai_value( level.zombie_actor_limit ) );
		last_tick = started;
	}
}

function dev_ai_detail( ai, players, has_path, routes )
{
	id = " id=" + dev_ai_ent( ai ) + " born_ms=" + ai.tod_ai_diag_born;
	mesh = GetClosestPointOnNavMesh( ai.origin, 64, 30 );
	inside = undefined;
	if ( isdefined( level.tod_trial_box ) ) inside = tod_spire_data::in_box( ai.origin, level.tod_trial_box );
	path_length = undefined;
	if ( has_path ) path_length = ai GetPathLength();
	dev_ai_log( "NAV" + id + " mesh=" + dev_ai_pos( mesh ) + " inside=" + dev_ai_value( inside )
		+ " path_mode=" + ai GetPathMode()
		+ " goal=" + dev_ai_pos( ai.goalpos ) + " radius=" + dev_ai_value( ai.goalradius )
		+ " path_start=" + dev_ai_pos( ai.pathstartpos ) + " path_goal=" + dev_ai_pos( ai.pathgoalpos )
		+ " path_length=" + dev_ai_value( path_length ) + " path_wait=" + dev_ai_value( ai.pathwaittime )
		+ " last_path=" + dev_ai_value( ai.lastpathtime ) );
	dev_ai_log( "MOTION" + id + " vel=" + dev_ai_pos( ai GetVelocity() ) + " onground=" + ai IsOnGround()
		+ " linked=" + dev_ai_ent( ai GetLinkedEnt() ) + " move_type=" + dev_ai_value( ai.movementtype )
		+ " last_script=" + dev_ai_value( ai.lastscriptstate ) + " state_reason=" + dev_ai_value( ai.statechangereason )
		+ " anim=" + dev_ai_value( ai.animname ) + " script_anim=" + dev_ai_value( ai.script_animname )
		+ " anim_scale=" + dev_ai_value( ai.animtranslationscale ) + " gunblocked=" + dev_ai_value( ai.gunblockedbywall ) );
	dev_ai_log( "STATE" + id + " king=" + dev_ai_value( ai.tod_king ) + " guard=" + dev_ai_value( ai.tod_spire_guard )
		+ " asm_status=" + ai ASMGetStatus()
		+ " pause_write_ms=" + dev_ai_value( ai.tod_ai_diag_pause_write )
		+ " pause_pending=" + dev_ai_value( ai.tod_elite_pause_pending ) + " pause_resume_ms=" + dev_ai_value( ai.tod_ai_diag_pause_resume )
		+ " base_rate=" + dev_ai_value( ai.tod_elite_base_rate )
		+ " drop_age=" + dev_ai_age( ai.tod_drop_stamp ) + " eslow_age=" + dev_ai_age( ai.tod_eslow_until )
		+ " hit_age=" + dev_ai_age( ai.tod_actor_cb_ms ) + " dealt_age=" + dev_ai_age( ai.tod_dealt_ms )
		+ " flame=" + dev_ai_value( ai.isShootingFlame ) + " octobomb=" + isdefined( ai.destroy_octobomb )
		+ " ignored_players=" + dev_ai_entities( ai.ignore_player ) + " travel=" + dev_ai_value( ai.isTraveling )
		+ " pain_block=" + dev_ai_value( ai.blockingPain ) + " furious=" + dev_ai_value( ai.isFurious )
		+ " dog_seen=" + dev_ai_value( ai.hasSeenFavoriteEnemy ) + " dog_last=" + dev_ai_pos( ai.lastTargetPosition )
		+ " target_override=" + isdefined( ai.no_target_override ) + " goal_override=" + isdefined( ai.enemy_location_override_func ) );
	// Path existence and line of sight are different questions. Test both against
	// EVERY player, including ignored/downed players; their eligibility is above.
	// Never call setters or path recalculation. Expensive probes only on heartbeat.
	if ( !routes ) return;
	foreach ( p in players )
	{
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) ) continue;
		// Native failures between PROBE and ROUTE may belong to this diagnostic
		// query. Keep them separate from errors raised by the live goal driver.
		dev_ai_log( "PROBE" + id + " player=" + dev_ai_ent( p ) );
		pmesh = GetClosestPointOnNavMesh( p.origin, 64, 30 );
		raw_path = ai CanPath( ai.origin, p.origin );
		mesh_path = undefined;
		if ( isdefined( mesh ) && isdefined( pmesh ) ) mesh_path = ai CanPath( mesh, pmesh );
		trace = BulletTrace( ai.origin + ( 0, 0, 40 ), p.origin + ( 0, 0, 40 ), false, ai );
		dev_ai_log( "ROUTE" + id + " player=" + dev_ai_ent( p ) + " distance=" + int( Distance( ai.origin, p.origin ) )
			+ " dz=" + int( p.origin[ 2 ] - ai.origin[ 2 ] ) + " raw=" + raw_path + " projected=" + dev_ai_value( mesh_path )
			+ " see=" + ai CanSee( p ) + " ray=" + trace[ "fraction" ] + " hit=" + dev_ai_pos( trace[ "position" ] ) );
	}
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

// =============================================================================
// RAMPAGE INDUCER (v14.20) — the elite-count multiplier. User 2026-08-30:
// "I want double the elites there would normally be."
//
// READ-ONLY here: _tod_rampage.gsc is the ONE WRITER of level.tod_rampage_on.
// Every elite module already reaches this file, so nothing new is imported and
// no cycle is created. An absent field returns 1, so the whole feature no-ops
// in any build where the inducer is not installed or not toggled.
//
// *** IT SCALES DEBT AND THE DEBT CLAMP ONLY — NEVER A CONCURRENCY ROOF. ***
// rp_max_alive() / sprint_max_alive() / hound_max_alive() are each read at TWO
// different sites: the WAVE CLAMP inside *_due()/round_watch (how many a wave
// OWES — throughput), and the DIRECTOR'S STANDING GATE (how many may STAND at
// once — concurrency). Only the clamp site may be scaled. Scaling the function
// itself would raise the standing roof at every gate too, which is precisely
// what the block comment at :93-111 forbids ("this pass does NOT raise a single
// limit"). Doubling the roofs was measured at 81 concurrent actors against a
// 60 limit — it does not fit, and the horde gets squeezed to stock's own 24.
//
// EXACTNESS: delivered = min(n, R). Scaling BOTH arms gives min(2n, 2R) =
// 2*min(n, R) — exactly 2x at every party size and every round, because the
// min() can never truncate asymmetrically. Scaling only ONE arm makes the
// feature invisible at one end of the game: solo/early waves sit UNDER the roof
// so only the formula moves them, while quad waves are pinned AT the roof from
// round 8 so only the clamp does.
//
// PANZER IS NOT A CONSUMER OF THIS MULTIPLIER — but he IS doubled, by his own
// lever. See panzer_max_alive(). This comment used to say the Panzer could not
// be doubled at all "because the only way is the roof itself, and that is the
// bug the cap was added to stop"; the user then asked for exactly that
// (2026-08-30: "Rampage should also spawn in 2 panzers during boss rounds"), and
// the objection turned out to be wrong in an instructive way — the 2026-08-23
// bug was debt ACCUMULATION under a `+=` with no roof, not a pair under a
// clamped one. A flat 2 is bounded; a queue was not.
//
// He stays off elite_mult() on purpose: he is the BOSS, not an elite (:284-293),
// and tying the two together would silently double him again the day the elite
// number is retuned to 3.
//
// SPIRE: ON. Asked for explicitly (user 2026-08-30: "lets also make sure
// rampage inducer works with Endless Spire"), overriding the cautious default
// this shipped with for one afternoon.
//
// The caution was NOT baseless and is worth keeping written down: the spire runs
// the map's hottest spawn pacing, and its post-win ladder had never had a real
// play-through as of v14.19 (it had no navmesh at all until then). What makes
// carrying the multiplier in there defensible anyway is that the thing actually
// protecting the actor budget is elites_over_roof() below, NOT this exemption —
// the combined roof is enforced on every director in every mode, spire
// included, so the standing elite count is bounded at TOD_ELITE_ROOF_ALL
// wherever this multiplier is read. Throughput doubles; concurrency does not.
//
// If a spire run ever reads as unsurvivable rather than hard, this is the first
// lever to pull, and `if ( IS_TRUE( level.tod_spire_active ) ) return 1;` at the
// top of this function is the one-line revert.
// =============================================================================
// v14.31 — THE SPIRE STACKS WITH RAMPAGE (4x, or 8x with the inducer on).
// Multiplying rather than max()ing is safe for the same reason the doctrine
// above holds: this value only ever scales DEBT and the DEBT CLAMP, and
// elites_over_roof() bounds what may STAND at TOD_ELITE_ROOF_ALL regardless.
// Past saturation a bigger number buys backlog, not bodies — so 8x reads as
// "the roof never gets a gap" rather than 8x the actors. The revert lever is
// still one line: `if ( IS_TRUE( level.tod_spire_active ) ) return 1;` here.
function elite_mult()
{
	m = 1;
	if ( IS_TRUE( level.tod_rampage_on ) )
		m = TOD_RAMPAGE_ELITE_MULT;
	if ( IS_TRUE( level.tod_spire_active ) )
		m = m * TOD_SPIRE_ELITE_MULT;
	return m;
}

// RAMPAGE (v14.20) — the COMBINED elite roof, now enforced on every director.
//
// Until this existed the roof was ONE-SIDED: only the hound director checked the
// combined count, while the Panzer, Protector and Reaver directors each checked
// their OWN type and nothing else. So if hounds landed first the combined
// reading stayed low, and the other three could add 1 + 8 + 3 on top —
// worst-case 18 live elites at quad, not the 12 the hound gate implies. On a
// 45-zombie horde that is ~63 actors against TOD_ACTOR_LIMIT 60.
//
// That was survivable while it was a rare transient. Doubling elite THROUGHPUT
// makes each type sit pinned at its roof for roughly twice as long, which turns
// the worst case into the standing late-game board — and under THE TWIST the
// horde never drains at a round boundary, so "45 zombies already up, elites
// arriving on top" is the DEFAULT ordering, not the unlucky one.
//
// Capping the sum at TOD_ELITE_ROOF_ALL takes worst-case elites 18 -> 12 and
// live actors 63 -> 57, which fits under 60 with corpse headroom. Delivery is
// unaffected: a blocked director simply waits and pays its debt a tick later.
// This is a NEW CEILING ON AN EXISTING SUM, not a raised limit — the one thing
// the doctrine above does allow.
// Field names taken from finale_beat_panzer() below, which already builds this
// exact sum — NOT invented here. They are singular and inconsistent by history
// (level.tod_panzer_alive, a protectors_alive() FUNCTION, level.tod_reaver_alive_n,
// level.tod_hound_alive_n); _tod_hellhounds::elites_alive() builds the same sum
// a fourth way. Copy from a call site, never from the pattern of the other names.
function elites_all_alive()
{
	rv = ( ( isdefined( level.tod_reaver_alive_n ) ) ? level.tod_reaver_alive_n : 0 );
	hd = ( ( isdefined( level.tod_hound_alive_n ) ) ? level.tod_hound_alive_n : 0 );
	pz = ( ( isdefined( level.tod_panzer_alive ) ) ? level.tod_panzer_alive : 0 );
	return pz + protectors_alive() + rv + hd;
}

// TRUE while the combined roof is full. The FINALE IS EXEMPT: it runs its own
// tighter TOD_FINALE_BOSS_ROOF through finale_beat_*, and layering a second
// ceiling under it would silently thin the road ambush the ending depends on.
function elites_over_roof()
{
	if ( IS_TRUE( level.tod_finale_aggro ) || IS_TRUE( level.tod_finale_holdout ) )
		return false;
	// v16.15 — THE WARDENS' FIRST CLAIM (the spire's trial arenas). While a
	// trial runs, _tod_spire::trial_wardens publishes how many Warden slots
	// are still OWED (want minus standing); every director backs off by that
	// many, so the boss fight always has its boss. This is a LOWER ceiling
	// for the adds, never a higher one for anything: the Wardens themselves
	// drop only under elite_roof_all() (the trial loop checks it directly).
	roof = elite_roof_all();   // v18.1 — party-aware; ONE owner, read it, never the define
	if ( isdefined( level.tod_trial_reserve ) )
		roof = roof - level.tod_trial_reserve;
	return ( elites_all_alive() >= roof );
}

// PUBLIC — the combined roof's value for THIS party size, and since v18.1 the
// single owner of it: elites_over_roof() above calls this rather than reading
// the define, so the two can never disagree. Also read directly by the one
// spawner that does not go through a director (_tod_spire's Warden loop).
function elite_roof_all()
{
	np = GetPlayers().size;
	if ( np < 1 )
		np = 1;
	roof = TOD_ELITE_ROOF_SOLO + ( np - 1 ) * TOD_ELITE_ROOF_PER;
	if ( IS_TRUE( level.tod_rampage_on ) )
		roof = roof + TOD_RAMPAGE_ELITE_ROOF_ADD;   // v18.74 — hard mode's own roof
	return roof;
}

// PUBLIC — v17.96: how long a dead elite body lingers before corpse_remove
// Deletes it (_tod_reaver reads it here so the number lives in one file).
function elite_corpse_linger()
{
	return TOD_ELITE_CORPSE_LINGER;
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
	// RAMPAGE (v14.20): BOTH halves take the multiplier, and that is NOT a
	// double-dip — the second is a MIN BOUND, not a product. min(2n,2R) is
	// exactly 2*min(n,R). Scaling only one arm would make the feature invisible
	// at one end of the game: solo and early waves sit UNDER the roof so only
	// the formula moves them, while quad waves are pinned AT the roof from
	// round 8 (int(4*8/3*0.8+0.5) = 9 > 8) so only the clamp does.
	m = elite_mult();
	n = n * m;
	// WAVE CAP (playtest 2026-08-23: "I saw like 30 on round 18"): np*round/3
	// is unbounded — a duo at round 18 rolls a 12-wave, a quad 24. No wave may
	// ask for more than the concurrency roof can even stand up at once.
	//
	// THIS IS THE DEBT CLAMP, NOT THE STANDING ROOF. rp_max_alive() itself is
	// untouched, so the director's own gate at :895 still admits at most 5..8
	// protectors at a time — rampage only lets the wave keep re-feeding them
	// for twice as long.
	roof = rp_max_alive() * m;
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

	// THE JANITOR (2026-09-04). Everything below this line is on the far side
	// of two waits, and this function's own header already warned what that
	// costs — "a script_model wearing the boss model plus a tag_origin playing
	// robot_sky_trail forever". drop_in has no endon of its own, so it inherits
	// whatever the CALLER carries, and a caller with `level endon(...)` can be
	// killed mid-fall and take this frame with it: the proxy stands there for
	// the rest of the match looping an engine sound, and the real boss stays
	// Ghosted, undamageable and slot-holding. That happened on the Warden lane
	// (fixed at its own site too); this closes the class so no future caller can
	// reintroduce it. Threaded on LEVEL so a boss that dies mid-fall still gets
	// its litter cleared.
	boss.tod_drop_stamp = GetTime();   // identifies THIS drop to the janitor
	level thread drop_janitor( boss, proxy, trail, base_rate, boss.tod_drop_stamp );

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

// Clears a drop_in whose calling thread was killed mid-fall. On the normal path
// every one of these is already undefined or already cleared, so it is a no-op —
// which is the property that makes it safe to run after EVERY drop.
//
// The wait is drop_in's own full length (tell lead + fall) plus a wide margin,
// so this can never race the legitimate teardown.
function drop_janitor( boss, proxy, trail, base_rate, stamp )
{
	level endon( "end_game" );

	wait ( TOD_DROP_TELL_SECS + 8 );

	if ( isdefined( trail ) )
		trail Delete();
	if ( isdefined( proxy ) )
	{
		proxy StopLoopSound();
		proxy Delete();
	}
	// A boss still flagged dropping this long after the drop began was
	// abandoned in the invisible/undamageable/ignoreall state drop_in only ever
	// leaves it in DURING the fall. Restore exactly what drop_in's impact block
	// restores — anything less leaves an enemy nobody can see or shoot.
	if ( !isdefined( boss ) || !isalive( boss ) || !IS_TRUE( boss.tod_dropping ) )
		return;
	// ...and only if it is still OUR drop. A relocation can start a second
	// drop_in on the same boss inside this janitor's window; clearing that one's
	// state would reveal a boss mid-fall and hand it back its collision in the
	// air, which is worse than the leak this function exists to clear.
	if ( isdefined( stamp ) && boss.tod_drop_stamp !== stamp )
		return;
	boss.tod_dropping = undefined;
	boss Show();
	boss SetCanDamage( true );
	if ( !IS_TRUE( level.tod_upgrade_pause ) && !IS_TRUE( boss.tod_frozen ) )
	{
		boss.ignoreall = false;
		if ( isdefined( base_rate ) )
			boss ASMSetAnimationRate( base_rate );
	}
	dbg( "drop janitor cleared an abandoned drop id=" + dev_ai_ent( boss ) );
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
#define TOD_BOSS_NEAR_PLAYER     1500   // within this = engaging, never relocate...

// ...PROVIDED IT IS ALSO DOING SOMETHING (2026-09-04). The bare distance test
// above made this entire watchdog UNREACHABLE inside any enclosed room: a
// spire hub hall's trial box is ~1,220 units corner to corner
// (_tod_spire_data::trial_box) against a 1,500-unit exemption, so a Warden
// pinned on geometry during a 70 s sealed hold-out could never accrue a single
// second of stall time — the watchdog was switched off by architecture, at the
// exact place the user reports enemies standing still. On the open spiral the
// same sphere blankets ~4 laps in every direction.
//
// TWO INDEPENDENT SIGNS OF LIFE, and an elite must fail BOTH to be relocated:
//   DISPLACEMENT — 256 units over the whole TOD_BOSS_STUCK_SECS window is
//   ~14 u/s, far under any elite's ground speed, so anything actually walking
//   clears it. Measured against a re-anchoring origin rather than per tick, so
//   a Rogue Protector holding a firing position is not chopped into "stalls".
//   DAMAGE — tod_actor_cb_ms is stamped unconditionally on every damaged actor
//   by _tod_upgrades::upgrade_damage_cb, so "someone is shooting it" costs one
//   field read. An elite the party is fighting is engaging by definition, even
//   if it never moves, and must never be teleported out of that fight.
#define TOD_BOSS_STUCK_MOVE      256    // displacement over the window that counts as moving
#define TOD_BOSS_PINNED_QUIET    8000   // ms since the last hit on it before "pinned" is believed

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
			best = -1;   stalled = 0;   self.tod_stuck_org0 = undefined;   continue;   // the PLAYER moved, not us
		}

		d = nearest_player_dist( self.origin );
		if ( d < 0 )
			continue;   // no living players

		// DISPLACEMENT WINDOW — see TOD_BOSS_STUCK_MOVE. org0 re-anchors the
		// moment the elite covers real ground, so `moved` means "has moved 256
		// units since it last did", not "has moved since the last tick".
		moved = ( !isdefined( self.tod_stuck_org0 )
		       || Distance( self.origin, self.tod_stuck_org0 ) > TOD_BOSS_STUCK_MOVE );
		if ( moved )
			self.tod_stuck_org0 = self.origin;
		// EITHER DIRECTION COUNTS. tod_actor_cb_ms is damage TAKEN (stamped by
		// _tod_upgrades::upgrade_damage_cb on every damaged actor); tod_dealt_ms
		// is damage DEALT (stamped in boss_player_damage). A boss is engaging if
		// either is recent.
		fought = ( ( isdefined( self.tod_actor_cb_ms )
		          && ( GetTime() - self.tod_actor_cb_ms ) < TOD_BOSS_PINNED_QUIET )
		        || ( isdefined( self.tod_dealt_ms )
		          && ( GetTime() - self.tod_dealt_ms ) < TOD_BOSS_PINNED_QUIET ) );

		if ( d <= TOD_BOSS_NEAR_PLAYER )
		{
			if ( moved || fought )
			{
				best = d;   stalled = 0;   continue;   // close and alive-looking — engaging
			}
			// Close, motionless and untouched: fall through and accrue. This is
			// the lane that did not exist, and the one a sealed hub hall needs.
		}
		else if ( best < 0 || d < best - TOD_BOSS_STUCK_IMPROVE )
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
				dbg( "boss stalled — relocating with an entrance id=" + dev_ai_ent( self ) );
			}
			best = -1;   stalled = 0;   self.tod_stuck_org0 = undefined;
		}
	}
}

// Panzer: ONE every 5th round.
// PUBLIC — the PANZER concurrency roof. 1 normally, TOD_RAMPAGE_PANZER_MAX (2)
// while the inducer is on.
//
// THIS IS THE ONE PLACE THE RAMPAGE FEATURE RAISES A CONCURRENCY ROOF, and it
// is a deliberate exception to the ":93-111 raise nothing" doctrine, asked for
// by name (user 2026-08-30: "Rampage should also spawn in 2 panzers during boss
// rounds"). Every other lever scales THROUGHPUT only. Four things make the
// exception safe, and if any of them stops being true this must go back to 1:
//
//   1. THE HISTORICAL BUG WAS ACCUMULATION, NOT A PAIR. The 2026-08-23 stack
//      (#2 at r10, #3 at r15, #4 at r20) came from debt SUMMING with `+=` and
//      no roof at all. Debt is SET-to-max and clamped now, so the ceiling is a
//      flat 2 no matter how many boss rounds pass unkilled — a deliberate pair,
//      never a queue.
//   2. THE COMBINED ELITE ROOF GATES HIM. elites_over_roof() is checked at the
//      top of the director, so the second Panzer costs one of the 12 shared
//      elite slots rather than being additive on top of them. Worst-case actor
//      count is unchanged.
//   3. THE MUSIC IS ALREADY REFCOUNTED. tod_atmosphere::boss_track_start/end
//      count references (tod_panzer_music_count) — the track starts on the
//      first and resumes ambient only on the last. panzer_life's own comment
//      says it "survives a raised roof"; this is that raise.
//   4. THEY CANNOT STACK ON ONE SPOT. pick_spawn_point collects every living
//      boss and scatters clear of them, and the director spawns one per 3 s
//      tick, so the second drops in elsewhere three seconds later.
//
// THE FINALE IS **NOT** EXCLUDED (corrected 2026-09-14; the old line here said it
// was, and cited a :1081 that has since rotted into pick_spawn_point).
// finale_beat_panzer() and the hold-out top-up in finale_pressure_loop() do still
// read the raw constant — but only to decide whether to BANK a debt. director()
// SPENDS every finale debt under THIS function, and the pressure loop's rotation
// arm banks one with no alive check, so a rampage finale can stand two. Full
// reasoning in the block above finale_holdout_start().
function panzer_max_alive()
{
	if ( IS_TRUE( level.tod_rampage_on ) )
		return TOD_RAMPAGE_PANZER_MAX;
	return TOD_PANZER_MAX_ALIVE;
}

function panzer_due( round )
{
	// [v16.87] THE DEV CADENCE IS GONE — SHIP TIMING IN EVERY BUILD.
	// User 2026-09-03: *"I think dev mode has all these xtra elites spawning
	// in ... I want to remove that specific thing"*, with dev and god staying
	// ON. Every elite family used to run a dev cadence about twice the
	// shipping one (Panzer r3/3, Reaver 2, hound 2, sprinter 2 against ship
	// 5/5, 4, 3, 3), which made an armed session a measurably different game
	// and, worse, made every armed playtest a test of numbers the map does
	// not ship. Those families are all play-proven now, so the acceleration
	// has no job left.
	//
	// THE FOUR SITES ARE LOCKSTEP — `_tod_bosses` (here), `_tod_hellhounds`,
	// `_tod_reaver`, `_tod_sprinter`. Do not re-add a dev branch to one of
	// them alone. To test a family again, drop its ship #define for the
	// session rather than reintroducing a second cadence that only some
	// builds see.
	first    = TOD_PANZER_FIRST;
	interval = TOD_PANZER_INTERVAL;
	if ( round < first )
		return 0;
	if ( ( round % interval ) != 0 )
		return 0;
	// RAMPAGE: the boss round owes TWO. Deliberately NOT elite_mult() — that
	// multiplier is the throughput lane and the Panzer is the BOSS, not an
	// elite; tying them together would silently double him again if the elite
	// number is ever retuned to 3.
	return panzer_max_alive();
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
			// by a slower route. Owing at most the roof means the punishment
			// for a slow kill is the Panzer you already have, not a backlog.
			//
			// RAMPAGE (v14.27): the cap is panzer_max_alive() now, so hard mode
			// owes 2 and normal still owes 1. THIS CLAMP IS WHAT KEEPS THE PAIR
			// A PAIR — `+=` above still sums, so without it a party that skips
			// two boss rounds would bank 4. The ceiling is flat at the roof no
			// matter how many rounds pass unkilled.
			if ( level.tod_panzer_debt > panzer_max_alive() )
				level.tod_panzer_debt = panzer_max_alive();
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

		// COMBINED ELITE ROOF (v14.20) — see elites_over_roof(). Until this
		// existed only the hound director checked the combined figure, so this
		// director could stack a Panzer and 8 Protectors on top of a full board
		// of reavers and hounds. A debt held here is NOT lost: it drains on the
		// next tick once something dies, exactly like the per-type roofs above.
		if ( elites_over_roof() )
			continue;

		// Panzer outranks the wave for the next slot (his music + presence
		// define the round; the RP debt keeps draining right after).
		// ROOF (2026-08-23): never more than panzer_max_alive() standing — the
		// branch below had this from day one and this one did not. A debt held
		// here is NOT lost: it drains on the next tick after he dies.
		// RAMPAGE (v14.27): 1 normally, 2 while the inducer is on. The second
		// arrives on the NEXT 3 s tick, never the same frame, and
		// pick_spawn_point scatters it clear of the first.
		// v18.9 — NOT INTO A SEALED HALL. level.tod_king_active was written and
		// never read anywhere in the tree (the comment in _tod_spire.gsc claimed
		// this director read it; grep returned only the write and the clear), so a
		// Panzer debt banked before a trial seal was spent on the next 3 s tick —
		// INSIDE the sealed hall. It is not stamped tod_spire_guard, so it paid the
		// 1000-point boss jackpot and a guaranteed Max Ammo mid-holdout, and
		// trial_wardens counts Wardens by level.tod_panzer_alive, so it was read AS
		// the Warden and suppressed the redrop.
		//
		// ONLY THE PANZER BRANCH IS GATED, never the whole loop: the protector
		// branch below DELIVERS the trials' adds (trial I is prot 2 / reaver 0 /
		// hound 0 — a 'continue' here would run it with no adds at all).
		// tod_trial_active covers the Warden King too; king_run sets both flags at
		// its seal.
		if ( level.tod_panzer_debt > 0 && level.tod_panzer_alive < panzer_max_alive()
		     && !IS_TRUE( level.tod_trial_active ) )
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
//
// CORRECTED 2026-09-14 — THE FINALE IS NOT EXCLUDED FROM RAMPAGE, and the
// v14.27 claim that used to sit here was never true. The two raw-constant reads
// it named are real (finale_beat_panzer() below, and the hold-out top-up in
// finale_pressure_loop()), but NEITHER IS THE CONCURRENCY BOUND: they only
// decide whether to BANK a debt. director() is the only thing that spends one,
// and it spends under panzer_max_alive() — which answers 2 whenever the inducer
// is on. Nothing clears that flag for the last mile (_tod_rampage owns it: false
// at init, flipped at the breaker), so the causeway and the sealed crown hall CAN
// carry two Panzers. v19.0 did not cause this; it only widened WHEN the switch
// can be thrown, by retiring the round seal that used to freeze it from round 9.
// TOD_FINALE_BOSS_ROOF does not stop it either — only the debt writers read it,
// never the spawn — and elites_over_roof() returns false outright once
// tod_finale_aggro is set, so the combined elite roof is off for the whole run.
// The most reachable second Panzer is finale_pressure_loop()'s rotation arm
// (case 0), which banks a Panzer debt after the COMBINED roof check with no
// per-Panzer alive check, on the road and inside the sealed hall alike.
//
// Whether a rampage finale SHOULD stand two is a design question, still open —
// it is not a correctness bug, and nothing here has been changed to alter it.
//
// And THIS function is the one additive write in the lane — it banks the siege
// debt with neither an alive check nor a roof check; wipe_the_map() has just
// emptied the hall, which is why it has never needed one.
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

// `targetable` (2026-09-24): true for an AGGRO pick (who to chase), which must
// honour .ignoreme — Zombie Blood, stock's post-revive grace. Spawn anchoring
// leaves it false: WHERE a boss drops in is not who it attacks, and a party all
// in Zombie Blood must not stall a boss wave.
function pick_target_player( targetable = false )
{
	candidates = [];
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		if ( isdefined( players[ i ] ) && zm_utility::is_player_valid( players[ i ], targetable ) )
			candidates[ candidates.size ] = players[ i ];
	}
	if ( candidates.size == 0 )
		return undefined;
	return candidates[ RandomInt( candidates.size ) ];
}

// v14.47 — THE CROWN-END WALL, ELITE HALF. -> the anchor to actually query
// around: usually the one passed in, but during the finale ROAD phase, most of
// the time, the far end of the causeway instead.
//
// WHY IT HOOKS HERE AND NOT AT THE FOUR CALL SITES: every elite type resolves
// its spawn through pick_spawn_point — the Panzer with a
// TOD_PANZER_FRONT_DIST offset, the Protector, the Reaver and the hounds with
// the player's own origin, the last two from their own modules. One seam covers
// all four and cannot be forgotten by a fifth added later. The Panzer's
// front-offset is intentionally discarded on a far roll: "in front of the
// player" is the trailing model the user asked us to move away from.
//
// NOT DURING THE SEALED HOLD-OUT. `pick_spawn_point` already refuses anything
// outside the hall once the crown seals, so a crown-end anchor there would push
// every query at a wall it is then required to reject — burning both passes and
// falling through to "spawn on the player", which is the exact failure the
// two-pass ladder exists to prevent.
//
// The anchor sits BACK from the gate, on the road side: the query has a 400u
// first pass, and anchoring on the doorway itself spends it on geometry.
// v14.48 — the same THREE BANDS the horde uses (40% crown gate / 30% middle /
// 30% beginning, rolled by tod_endless_rounds::finale_roll_band so trash and
// elites can never drift apart).
function finale_far_anchor( anchor )
{
	if ( !IS_TRUE( level.tod_finale_aggro ) || IS_TRUE( level.tod_crown_sealed ) )
		return anchor;

	b = tod_endless_rounds::finale_roll_band();

	// BAND 0 (beginning) KEEPS THE PLAYER-RELATIVE ANCHOR, and this is the one
	// place elites deliberately differ from the horde.
	//
	// A trash zombie spawned at the road's start while the party is at the crown
	// costs nothing — it walks, and if it never arrives the spawner simply makes
	// another. AN ELITE IS NOT FUNGIBLE: the finale roof is FOUR, so a Panzer
	// that spawns ~7,000 units behind the party spends one of four slots on
	// something that will not reach the fight before it ends. Anchoring band 0
	// on the player keeps that share of elites "near and behind you" — which IS
	// the beginning of the bridge early in the run, and stays useful later —
	// without burning the roof on a walker that never lands.
	if ( b == 0 )
		return anchor;

	y0 = tod_endless_rounds::finale_road_y0();
	y1 = tod_endless_rounds::finale_road_y1();

	// BAND 2 sits BACK from the gate, on open deck: pick_spawn_point's first
	// pass is only 400u and anchoring on the doorway itself spends it querying
	// geometry. BAND 1 is the road's midpoint.
	if ( b == 2 )
		y = y1 - TOD_FINALE_FAR_ANCHOR_BACK;
	else
		y = y0 + ( y1 - y0 ) * 0.5;

	// x = 0 is the road's centre line. The road forks (ridge / broken stair /
	// undercroft / plank / weave), so this can land off-deck on a fork — which
	// is exactly what pick_spawn_point's 400u then 800u navigation query is for:
	// it resolves to real walkable ground near the anchor, or falls through to
	// the caller's own fallback. The anchor is a HINT, not a spawn point.
	return ( 0, y, tod_crown_data::crown_z() );
}

function pick_spawn_point( anchor )
{
	anchor = finale_far_anchor( anchor );

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
	frontier = door_frontier_z();   // v18.76 — once per pick; undefined off the tower

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
			// v16.15 — THE SEALED RING: while a spire trial runs nothing may
			// land outside its arena. Same failure as the crown above — the
			// 800u pass reaches through the shut gate onto the stairs, and a
			// boss out there is stranded AND holds a roof slot for the whole
			// hold-out. The box comes from _tod_spire (generated anchors).
			// v17.92 — once ascended, nothing spawns off the spire island: a body on
			// the tower can never reach a player again and never dies, and the actor
			// pool is the spire's binding constraint (console_mp.log 2026-09-05).
			if ( ok && IS_TRUE( level.tod_spire_active ) && !( tod_spire_data::in_spire( p ) ) )
				ok = false;
			if ( ok && isdefined( level.tod_trial_box ) && !( tod_spire_data::in_box( p, level.tod_trial_box ) ) )
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
			// v18.76 — THE DOOR FRONTIER (see the define): above the lowest
			// unbought door is behind it, whatever the overhanging zone says.
			if ( ok && isdefined( frontier ) && p[ 2 ] > frontier )
				ok = false;
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

// v18.76 — the z above which a candidate is behind an unbought door, or
// undefined when there is no frontier to enforce (spire, every door bought, or
// a flag stock has not initialised yet -- door_init flag::init's them, and an
// unknown flag is treated as "no frontier", never as "sealed": a missing
// reading must not empty the spawn pick). Walks the lap doors bottom-up and
// stops at the first shut one, so it spawns at most ONE door-info struct.
function door_frontier_z()
{
	if ( IS_TRUE( level.tod_spire_active ) )
		return undefined;
	for ( n = 1; n <= TOD_BOSS_FRONTIER_LAPS + 1; n++ )
	{
		flag = ( ( n <= TOD_BOSS_FRONTIER_LAPS ) ? ( "enter_lap" + n ) : "enter_roof" );
		if ( !( level flag::exists( flag ) ) )
			return undefined;
		if ( level flag::get( flag ) )
			continue;
		info = tod_door_data::get_door_info( flag );
		if ( !isdefined( info ) || !isdefined( info.org ) )
			return undefined;
		return info.org[ 2 ] - TOD_BOSS_FRONTIER_DOOR_Z + TOD_BOSS_FRONTIER_LIFT;
	}
	return undefined;
}

// exp^(round - anchor), integer-loop pow (GSC has no reliable Pow builtin).
// PUBLIC — RAMPAGE INDUCER (v14.25, user 2026-08-30: "all elites and bosses get
// 1.25x health on rampage").
//
// Read by boss_hp() below, which is THE single choke point for the Panzer, the
// Rogue Protector, the Reaver and the Hellhound — all four call it and use its
// return directly, so one multiplier here reaches every one of them exactly
// once. The ARMORED SPRINTER is the one elite that does NOT come through here
// (it converts a horde zombie and multiplies the trash HP by TOD_SPRINT_HP_MULT
// instead), so it applies this itself — see _tod_sprinter.gsc.
//
// APPLIED INSIDE boss_hp AND NOT AT THE CALL SITES, deliberately: the Panzer's
// spawn path must keep level.mechz_health EQUAL to the spawn HP or the pack
// crashes (the contract at the top of this file). Multiplying inside the shared
// function keeps both in step by construction; multiplying at the four call
// sites would need the Panzer's copy remembered separately, which is exactly
// the kind of hand-synced pair this map has been bitten by before.
//
// COMPOSES WITH coop_hp_mult() rather than replacing it — a quad rampage
// Panzer is 2.8 x 1.5 = 4.2x the solo baseline (2.8 x 1.25 = 3.5x before v18.74).
function rampage_hp_mult()
{
	if ( IS_TRUE( level.tod_rampage_on ) )
		return TOD_RAMPAGE_HP_MULT;
	return 1.0;
}

// PUBLIC - THE ELITE HP KNOB (see TOD_ELITE_HP_MULT). Public for exactly the
// reason rampage_hp_mult is: two of the four elites live in other files and a
// GSC #define is file-local, so a copied 0.90 would be a second source of
// truth that nothing regenerates.
//
// APPLIED AT THE CALL SITES, which is the OPPOSITE of rampage_hp_mult and is
// deliberate. boss_hp is shared with the PANZER, and the Panzer is out of this
// cut; it is also the one caller that must keep level.mechz_health equal to
// its spawn HP, so it can never be scaled by a shared multiplier without a
// per-caller flag. The three elite call sites each set maxhealth and health
// from the same local, so scaling there cannot desync anything.
function elite_hp_mult()
{
	return TOD_ELITE_HP_MULT;
}

function boss_hp( round, anchor, base, exp_per_round )
{
	mult = 1.0;
	for ( r = anchor; r < round; r++ )
		mult = mult * exp_per_round;
	// v16.15 — THE TRIAL MULTIPLIER (_tod_spire's TOD_TRIAL_HP_MULT, published
	// as a level field for the trial's duration). Applied HERE for the same
	// reason rampage_hp_mult is: this is the single choke point, so the
	// Panzer's level.mechz_health stays equal to its spawn HP by construction.
	// It reaches every elite spawned inside a trial, not only the Wardens —
	// intended: the trial is "harder than the endless spire" on every axis.
	if ( isdefined( level.tod_trial_hp_mult ) )
		mult = mult * level.tod_trial_hp_mult;
	f = base * mult * coop_hp_mult() * rampage_hp_mult();
	// CLAMP BEFORE int() (bug review 2026-09-22, F19): the compounding passes
	// int32 around round 140-160 in a deep quad spire run, and an overflowed
	// int() would read negative and then be clamped to 1 HP by the guard below.
	if ( f > 2000000000 )
		f = 2000000000;
	hp = int( f );
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
	boss.tod_staff_damage_number_final = true;

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
	result = self tod_mechz_damage_calc( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex );
	// The level callback runs BEFORE stock armor and hit-location reductions.
	// Report the value returned to the engine, once, including direct+splash
	// as separate actual hits which the existing crowd accumulator can merge.
	if ( tod_upgrade_ui::defer_staff_damage_number( self, weapon )
	  && isdefined( attacker ) && IsPlayer( attacker )
	  && isdefined( result ) && result > 0 )
	{
		headshot = ( tod_upgrades::headshot_kind( self, hitLoc, point ) != "none" );
		attacker tod_upgrade_ui::push_dmg_num( int( result ), headshot, false, self );
	}
	return result;
}

// Existing damage calculation and stock armor side effects remain authoritative.
function tod_mechz_damage_calc( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex )
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
		// THE WARDEN KING gets his own divisor (v18.7) — see TOD_XMAS_KING_SHOTS
		// for why a percent-of-max-health weapon is the one thing his health wall
		// cannot stop. king_setup stamps tod_king; he is a Panzer in every other
		// respect, so he arrives here through the same branch every Panzer does
		// and this test is the whole separation.
		if ( IS_TRUE( self.tod_king ) )
			return int( self.maxhealth / TOD_XMAS_KING_SHOTS ) + 1;
		return int( ( self.maxhealth / TOD_XMAS_PANZER_SHOTS ) * TOD_XMAS_ELITE_BUFF ) + 1;
	}

	// Thunder Smash has no bone hit location, which stock otherwise rejects.
	if ( isdefined( self.tod_smash_hit_ms ) && self.tod_smash_hit_ms == GetTime()
	     && isdefined( attacker ) && self.tod_smash_attacker == attacker && damage > 0 )
		return int( damage );

	// THE MAGE'S ELEMENTS -- MUST COME BEFORE THE STOCK CALL. This is not
	// defensive coding, it is the only lane that works.
	//
	// A script DoDamage passes hitLoc "none". Stock's mechzDamageCallback tests
	// `if ( hitloc !== "none" )`, then MOD_PROJECTILE, then MOD_PROJECTILE_SPLASH,
	// and falls off the end with a literal `return 0`. So a MOD_UNKNOWN DoDamage
	// on a Panzer is worth ZERO from stock -- and the `result <= 0` early-out
	// below would return that zero and hide it. FIRE is the anti-Panzer element;
	// without this branch it does nothing to the one enemy it exists for.
	//
	// `damage` here is what the LEVEL CHAIN returned, so upgrade_damage_cb's mage
	// arm has already applied everything that should apply. Returning it unchanged
	// is the whole job -- the same shape as the Gift of Death branch above.
	// INERT while the class is gated off: nothing writes tod_mage_hit_ms.
	if ( isdefined( self.tod_mage_hit_ms ) && self.tod_mage_hit_ms == GetTime()
	     && isdefined( damage ) && damage > 0 )
		return int( damage );

	result = self [[ level.tod_mechz_stock_damage_func ]]( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex );
	if ( !isdefined( result ) || result <= 0 )
		return result;

	projectile_direct = ( isdefined( mod ) && mod == "MOD_PROJECTILE" );
	if ( is_splash_mod( mod ) && !projectile_direct )
		return result;

	// Melee pass-through: stock DEFAULTs melee hitlocs into the 0.1x body
	// family — return the incoming damage so script-final melee values stand.
	//
	// ⚠️ AND A FLAT x2 FOR THE PANZER ALONE (v15, 2026-09-01 — user: "Just give
	// a 2x buff to panzer only. I know we have so many multipliers but thats the
	// easiest way").
	//
	// WHY HERE AND NOWHERE ELSE: this wrap is installed on the mechz callback,
	// which is the PANZER'S OWN damage lane and nothing else's. Putting the buff
	// on this line is what makes it Panzer-only by construction — the Reaver,
	// the Rogue Protector and the hellhounds share TOD_MELEE_BOSS_MULT but never
	// reach this function, so none of them is touched. Raising that shared
	// constant instead would have hit all four.
	//
// NET EFFECT (v18.3, the +75% melee pass now scoped to the SLASHER):
	// a slasher's swing lands at 0.5775 x 2.0 = 1.155 on a Panzer and 0.5775 on
	// every other elite; every OTHER class's knife is back at 0.33 x 2.0 = 0.66
	// here and 0.33 elsewhere, exactly where it sat before v18.2. On the
	// round-30 solo Panzer measured below the slasher is ~25,130 per swing
	// against 102,727 HP - 5 swings, from 8 at the old rate and 15 before this
	// x2 existed.
	//
	// WHY THE PANZER SPECIFICALLY NEEDED IT — worth recording, because the
	// numbers are not obvious. A slasher's damage ceiling is 2.00 while every
	// gun class reaches 2.50-3.25: GIANT SLAYER and HEADSHOT are assault-only,
	// DRAW CUT is Wakizashi-bound and resets on the promotion that hands you the
	// Stormbreaker, and THOR'S THUNDER skips the boss triad outright. Exactly one
	// of the eleven domains a T3 slasher can roll raises Panzer damage. On top of
	// that the Panzer's weak point is bullets-only — this pass-through returns
	// BEFORE the faceplate branch below, so a swing to the visor and a swing to
	// the shin are the same number, while a bullet on the visor is worth x2.70.
	// A gunner needed only ~16% of shots on the faceplate to out-damage a maxed
	// blade.
	if ( isdefined( mod ) && IsSubStr( mod, "MELEE" ) )
		return int( damage * TOD_MELEE_PANZER_BUFF );

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
//
// ZOMBIE BLOOD (2026-09-24, lead tester: "I have zombie blood but panzer still
// is trying to hit me with flame thrower, or melee etc. He is still chasing me
// with agro"). This picked with is_player_valid( p ) — which only reads
// .ignoreme when its second argument is true (_zm_utility.gsc) — so every
// 0.5 s it re-pinned favoriteenemy onto the Zombie Blood player, and the flame
// and claw both aim at favoriteenemy. It now asks the TARGETABLE question,
// and with nobody targetable it lets go of a target that no longer is.
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
			if ( !isdefined( p ) || !zm_utility::is_player_valid( p, true ) )
				continue;
			d = DistanceSquared( self.origin, p.origin );
			if ( d < best_d )
			{
				best_d = d;
				best = p;
			}
		}
		if ( !isdefined( best ) )
		{
			self drop_untargetable( "panzer" );
			continue;
		}
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

// self = a boss whose retarget found NOBODY targetable (every player in Zombie
// Blood, downed, or in stock's post-revive grace). Let go of a player target
// that no longer qualifies and stand still, stock's own no-target answer
// (mechz.gsc mechzTargetService: SetGoal( entity.origin )). The next retarget
// tick picks the player up again the moment the window ends. Logged on the
// drop only, never per tick.
function drop_untargetable( kind )
{
	fe = self.favoriteenemy;
	if ( !isdefined( fe ) || !isplayer( fe ) || zm_utility::is_player_valid( fe, true ) )
		return;
	blood_dev_log( kind + " " + self GetEntityNumber() + " dropped player " + fe GetEntityNumber()
		+ " (not targetable: ignoreme=" + IS_TRUE( fe.ignoreme ) + " blood=" + IS_TRUE( fe.tod_in_blood ) + ")" );
	self.favoriteenemy = undefined;
	self SetGoal( self.origin );
}

function blood_dev_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) ) return;
	line = "[TOD_BLOOD] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}

function panzer_flame_trigger_release( ft )
{
	wait 3.0;
	if ( isdefined( ft ) )
		ft Delete();
}

// Poll-isalive (not waittill "death"): robust whether the pack's death anim
// Delete()s the actor or the corpse lingers (map 1 lesson).
function panzer_life( boss )
{
	level endon( "end_game" );
	level.tod_panzer_alive++;

	killer = undefined;
	org = boss.origin;
	// v14.31 — DOOR-GUARD PANZERS PAY THE ELITE RATE, NOT THE BOSS JACKPOT.
	// POLLED like killer/org above, and for the same reason plus one more: the
	// caller stamps .tod_spire_guard immediately AFTER spawn_panzer() returns,
	// which is after this thread has already started, so reading it once up
	// front would race and lose. Latching in the loop closes that by the first
	// 0.25s tick and still survives a pack-side Delete.
	b_guard = false;
	ft = undefined;
	while ( isdefined( boss ) && isalive( boss ) )
	{
		if ( isdefined( boss.tod_last_attacker ) )
			killer = boss.tod_last_attacker;   // polled — survives a pack-side Delete
		if ( IS_TRUE( boss.tod_spire_guard ) )
			b_guard = true;
		if ( isdefined( boss.flameTrigger ) )
			ft = boss.flameTrigger;             // polled: king_setup swaps it after spawn
		org = boss.origin;                      // last known spot (drop lands here)
		wait 0.25;
	}
	if ( isdefined( boss ) && isdefined( boss.tod_last_attacker ) )
		killer = boss.tod_last_attacker;       // the killing blow lands after the last poll
	// THE FLAME CONE OUTLIVED HIM (bug review 2026-09-22, F04): stock
	// mechzSpawnSetup Spawns a trigger_box and LinkTo's it; the pack deletes
	// the actor on death and nothing deleted the trigger, so every Panzer left
	// one entity behind — a slow drain on the ~1024 gentity table over a long
	// spire run. Released on its own thread after a grace so the pack's
	// death-frame reads (all isdefined-guarded) are long finished.
	if ( isdefined( ft ) )
		level thread panzer_flame_trigger_release( ft );

	level.tod_panzer_alive--;
	if ( level.tod_panzer_alive < 0 )
		level.tod_panzer_alive = 0;

	// AMBIENT RESUMES WHEN THE LAST PANZER IS DOWN — and the REFCOUNT is what
	// decides that, not this call site.
	//
	// v14.44 BUGFIX (user 2026-08-31: "on rampage mode the music gets stuck on
	// boss music even after killing both panzers"). This used to be wrapped in
	// `if ( level.tod_panzer_alive <= 0 )`, which broke the pairing the refcount
	// depends on: boss_track_start() is called ONCE PER SPAWN, so two Panzers
	// push the count to 2, while the guard let only ONE end() through — count
	// lands on 1, never reaches 0, and the boss track owns the channel for the
	// rest of the match.
	//
	// THE GUARD WAS SOLVING A PROBLEM THE REFCOUNT ALREADY SOLVES. Its comment
	// said "the first death cut the boss track while others were still hunting
	// you", but boss_track_end() only swaps back when the count hits zero — the
	// first of two deaths takes it 2 -> 1 and correctly changes nothing. A
	// second, cruder gate on top of a working counter is what produced the bug.
	//
	// ONE START, ONE END, ALWAYS. That is the whole contract; anything that
	// spawns a Panzer inherits it for free. Which matters well beyond rampage:
	// _tod_spire's door honour guard spawns up to TOD_SPIRE_GUARD_MAX (4) per
	// door, so under the old guard the music would have stuck permanently after
	// the FIRST spire door — 4 starts against 1 end.
	tod_atmosphere::boss_track_end();

	if ( isdefined( boss ) ) org = boss.origin;
	tod_luck::boss_kill( killer, "panzer", org );   // killer-only soul; includes guards and the King

	// v14.31 — TWO PAYOUT LANES. A scheduled boss-round Panzer is still THE
	// boss: 1000 team-wide + a guaranteed max ammo. A door-guard Panzer
	// (_tod_spire's honour guard, up to 4 per door across ~50 doors) pays the
	// flat elite rate to its KILLER instead, because the boss lane at that
	// volume would print roughly 200,000 team-wide points and carpet the
	// climb in full-ammo drops — the climb's own economy (flat 3000 doors)
	// would stop existing. The luck grant above is deliberately NOT split:
	// last-hitting a Panzer should always be worth the bar.
	if ( b_guard )
	{
		grant_elite_reward( "PANZER", killer, org );   // v18.96: + the bottle roll at his last known spot
	}
	else
	{
		grant_boss_reward( "PANZER", TOD_PANZER_PTS, false );
		// RIOT SHIELD (v17.16): the SECOND call site, and the only one. The
		// user's rule is "every elite you kill", and a player counts the Panzer
		// — but the money forked here for economy reasons the recharge cut does
		// not share, so this branch has to say it itself. The GUARD Panzer takes
		// the same cut through grant_elite_reward on the other side of this if,
		// which is why the call is inside the else and not above it: exactly one
		// cut per Panzer, either way.
		if ( isdefined( level.tod_shield_elite_kill ) )
			[[ level.tod_shield_elite_kill ]]( killer );
		// MAGE MANA (2026-09-09): the boss Panzer is the map's biggest single
		// mana payout, and it forks here for the same reason the shield does.
		if ( isdefined( level.tod_mage_elite_mana ) )
			[[ level.tod_mage_elite_mana ]]( killer, "PANZER" );
		// GUARANTEED MAX AMMO on every Panzer kill (user 2026-08-20). level thread
		// — specific_powerup_drop can wait internally (map 1's blocking-callers rule).
		if ( isdefined( org ) )
			level thread zm_powerups::specific_powerup_drop( "full_ammo", org );
	}
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

	// DMG REDUCTION (domain 2). v16: this used to be a hand-copied
	// `1.0 - 0.05 * dr_lvl` literal, because a GSC #define is file-local and the
	// constant in _tod_upgrades.gsc could not reach here. The v16 ladder is
	// DIMINISHING (6/11/15/18/20% cumulative) and cannot be a literal multiply,
	// so both lanes now call the one owner — the same shape sprint_armor_mult
	// and back_armor_mult below have always had. Do not re-inline it.
	dmg = int( dmg * tod_upgrades::dr_mult( self ) );
	// THE MAGE'S HEALING AURA (v18.38): 50% while standing in one. Sits beside
	// DMG REDUCTION because it is the same kind of thing -- an incoming-damage
	// multiplier -- and this lane short-circuits the normal chain, so without a
	// copy here Panzer melee would be the one attack the aura never softened.
	// Guarded pointer: inert while the mage class is off.
	if ( isdefined( level.tod_mage_aura_dr ) )
		dmg = int( dmg * [[ level.tod_mage_aura_dr ]]( self ) );
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
	// x TOD_ELITE_HP_MULT (v18.2): the -10% elite pass. Outside boss_hp so the
	// Panzer, which shares that function, keeps its own curve.
	hp = int( boss_hp( rn, TOD_PROTECTOR_FIRST, TOD_PROTECTOR_HP_BASE, TOD_PROTECTOR_HP_EXP ) * elite_hp_mult() );
	if ( hp < 1 )
		hp = 1;
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
		// death_watch (the only corpse_remove caller) never started, so a
		// Protector killed mid-drop by a wipe stayed a dead Actor in the
		// 64-slot pool for the match (bug review 2026-09-22, F17).
		if ( isdefined( boss ) )
			boss thread tod_corpse_cleanup::corpse_remove( TOD_ELITE_CORPSE_LINGER );
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
		if ( zm_zod_robot::landing_splash_immune( ai_zombie ) )
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

		// TARGETABLE players only (2026-09-24, the Zombie Blood report — see
		// retarget_loop): this overwrote the Protector's own stock target, which
		// does honour .ignoreme, with a Zombie Blood player every 0.5 s.
		target = undefined;
		best = 999999999;
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isdefined( p ) || !zm_utility::is_player_valid( p, true ) )
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
		else
			self drop_untargetable( "protector" );

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

		// Never fire at a player Zombie Blood hides (2026-09-24): targetable only.
		target = undefined;
		if ( isdefined( self.enemy ) && isplayer( self.enemy ) && zm_utility::is_player_valid( self.enemy, true ) )
			target = self.enemy;
		else if ( isdefined( self.favoriteenemy ) && isplayer( self.favoriteenemy ) && zm_utility::is_player_valid( self.favoriteenemy, true ) )
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

// The 5th-shot ROCKET (mahem_shot: a real s1_mahem MagicBullet) was DELETED
// 2026-09-03 (docs/86 §8). It had no caller since the user's 2026-08-20
// "only his bullet shot" order retired it, and the s1_mahem weapon it named
// cost 77 MB of pack for a projectile nobody could see; both zone lines are
// gone with it. The TOD_RP_MAHEM_* damage cap and the todBossMahem pulse
// stay — dead but harmless (the clientfield table must not shift).

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
			// Targetable only (2026-09-24): no zap pulse for a Zombie Blood player.
			if ( !isdefined( p ) || !zm_utility::is_player_valid( p, true ) )
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

	source = tod_luck::track_source( self );
	self waittill( "death", attacker );

	// COOP CRASH GUARD (map 1): the corpse can be reaped the same frame the
	// death notify fires — any self deref then throws and ends the match.
	if ( isdefined( self ) )
		self StopLoopSound();   // the hover hum otherwise loops on the corpse forever

	org = source.org;
	if ( isdefined( self ) )
		org = self.origin;   // v18.96: the bottle roll lands here (guarded — the corpse can be reaped this frame)
	tod_luck::boss_kill( attacker, "protector", org );
	grant_elite_reward( "ROGUE PROTECTOR", attacker, org );   // v14.5: killer-only 500 (+ v18.96 bottle roll)

	// v19.58 (display-vs-reality audit): the end scoreboard's ELIMINATIONS /
	// CRITICAL KILLS columns are attacker.kills / .headshots, which stock only
	// counts inside zm_spawner::zombie_death_event. Every other elite runs it
	// (dog_init, mechz_spiki, the Fury, the sprinter's horde spawner); this
	// SpawnActor'd Protector never did, so its kills were missing from the board.
	// Count them here (stats only - no second payout: the elite 500 above is it).
	if ( isdefined( attacker ) && IsPlayer( attacker ) )
	{
		if ( !isdefined( attacker.kills ) )
			attacker.kills = 0;
		attacker.kills++;
		if ( isdefined( self ) && isdefined( self.damagelocation ) && isdefined( self.damageweapon ) && isdefined( self.damagemod ) &&
		     zm_utility::is_headshot( self.damageweapon, self.damagelocation, self.damagemod ) )
		{
			if ( !isdefined( attacker.headshots ) )
				attacker.headshots = 0;
			attacker.headshots++;
		}
	}

	// v17.96 — THE BODY LEAVES THE POOL. console_mp.log 2026-09-05 (first Warden
	// King run): at every one of the 30 "no free actor entities" the engine's own
	// entity table held 64 actors — 12..16 Protectors and 2..3 Reavers among them —
	// while elites_all_alive() read 5..8 at the same instant. The difference is
	// DEAD elite bodies: a dead Protector / Reaver stays an Actor entity, is no
	// longer in the AI array and never becomes a corpse, so neither stock's
	// clear-corpses-at-the-cap gate nor get_current_actor_count() can see it. The
	// King's summons (a Protector debt of 2 every 18 s) piled them up until every
	// spawn failed — and each failure printed the entity table for ~1.3 s of
	// frozen server (23 of them = the "connection interrupted" banner). The hound
	// got this lane in v17.92; only the Panzer ever deleted itself. Same lane as
	// trash, longer linger so the death still reads; Ghosted at once near the cap.
	if ( isdefined( self ) )
		self thread tod_corpse_cleanup::corpse_remove( TOD_ELITE_CORPSE_LINGER );
}

// ---------------------------------------------------------------------------
// Shared: pause watch, zap slow, damage plumbing, rewards
// ---------------------------------------------------------------------------

// The upgrade-choice pause freezes all axis AI (set_world_pause: ignoreall +
// anim rate 0.05) — but it only enumerates AI alive AT pause time, and rate
// restore is left to the zombie sweep, which skips bosses by design. This
// watcher is the boss-side symmetric half: it APPLIES the freeze too (covers
// a boss that finished spawning mid-pause) and restores on the unpause edge.
//
// THE FREEZE IS RE-ASSERTED EVERY TICK, NOT STAMPED AT THE EDGE (v17.94, user
// 2026-09-05, the first real Warden King run: "the apothican furys didnt
// freeze during the dark upgrades. Meaning a player could just die"). The
// edge stamp was correct for an actor whose only rate writer is this file;
// the Apothicon Fury is not one. Its archetype writes the rate ITSELF on
// every teleport/bamf/traversal terminate (archetype_apothicon_fury.gsc:
// mocompApothiconFuryTeleportTerminate, apothiconBamfIn — both
// ASMSetAnimationRate( 1 )), so one bamf in flight when the pause landed put
// it back to full speed for the rest of the freeze, with was_paused already
// true and nothing here ever writing again. Now every tick under the pause
// writes ignoreall + 0.05, so the longest a re-stamp can survive is 0.25 s.
//
// AND A FURY IS PARKED AT ITS TREE'S IDLE BRANCH (tod_bt_idle_on_pause, set by
// _tod_reaver::spawn_reaver). Rate 0.05 slows a behaviour, it does not stop
// the tree CHOOSING one: apothiconCanBamf/apothiconShouldMeleeCondition are
// evaluated every frame regardless of rate, a bamf is a ForceTeleport that
// needs no animation time, and ignoreall only stops zombieTargetService
// from picking a NEW enemy (zombie.gsc:443) — the one it already had stays in
// .enemy, which is all the melee and bamf conditions read. The one switch
// that stops the WHOLE tree is the root's own spawn gate: idlespawnbehavior
// runs a looping idle@zombie while zombieIsThinkDone is false, above every
// combat branch (zm_genesis_apothicon_fury.ai_bt:135-152; _zm_behavior.gsc
// :1138 reads zombie_think_done) — the exact mechanism that made a parked
// riser a statue (memory parked-riser-idle-behavior; a bug there, the lever
// here). So the park writes zombie_think_done = false, the un-park writes it
// back to 1, and _tod_reaver::reaver_tune's own delayed write of 1 defers to
// the park (a Fury whose meteor was in flight when the pause began would
// otherwise un-park itself one second later). The Fury's damage callback
// also reads this field and returns 0 while it is false — which under the
// pause is what upgrade_damage_cb returns anyway. Opt-in per elite ON
// PURPOSE: the Panzer, the Protector and the hound run trees this file has
// not read for that gate, and all three have frozen correctly in every played
// pause since August; nothing changes for them beyond the per-tick re-assert.
function boss_pause_watch( base_rate )   // self = the boss
{
	self endon( "death" );
	level endon( "end_game" );

	// v17.84 — THE ONE STAMP OF AN ELITE'S TRUE ANIMATION RATE. Every elite
	// already threads this watcher with its own rate (hound/Reaver 1.0,
	// TOD_PANZER_ANIM_RATE, TOD_RP_ANIM_RATE), so recording it here is the only
	// way tod_zombie_speed::slow_elite's restore can never disagree with this
	// watcher's restore. NOT .tod_base_rate: that field also picks a sky-drop
	// relocation over a ground tell (tod_boss_stuck_watch above), and a hound or
	// a Reaver must not acquire an entrance by becoming slowable.
	self.tod_elite_base_rate = base_rate;

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
		if ( now )
		{
			// every tick, not the edge — see the header (v17.94)
			self.ignoreall = true;
			self ASMSetAnimationRate( 0.05 );
			if ( IS_TRUE( self.tod_bt_idle_on_pause ) && !IS_TRUE( self.tod_bt_parked ) )
			{
				self.tod_bt_parked = true;
				self.zombie_think_done = false;
			}
		}
		else if ( was_paused || IS_TRUE( self.tod_elite_pause_pending ) )
		{
			self.ignoreall = false;
			// The freeze writer owns this latch; a sub-tick pause still needs
			// its rate restored. Keep an unexpired elite slow across the pause.
			self.tod_elite_pause_pending = undefined;
			resume_rate = base_rate;
			if ( isdefined( self.tod_eslow_until ) && isdefined( self.tod_eslow_mult )
			  && GetTime() < self.tod_eslow_until )
				resume_rate *= self.tod_eslow_mult;
			self ASMSetAnimationRate( resume_rate );
			if ( IS_TRUE( level.tod_dev ) )
			{
				self.tod_ai_diag_pause_resume = GetTime();
				dbg( "PAUSE_RESTORE id=" + dev_ai_ent( self ) + " rate=" + resume_rate + " missed_edge=" + !was_paused );
			}
			if ( IS_TRUE( self.tod_bt_parked ) )
			{
				self.tod_bt_parked = undefined;
				self.zombie_think_done = 1;
			}
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
	// LAST STAND IS DELIBERATELY OUT OF SCOPE HERE, AND THE OMITTED THIRD ARGUMENT
	// IS WHAT PUTS IT THERE. zm_utility::is_player_valid( player,
	// checkIgnoreMeFlag, ignore_laststand_players ) returns FALSE for a crawler
	// when the third is absent, so this bails on line two for a downed player and
	// every lane below is skipped.
	//
	// THAT IS CORRECT, AND IT WAS BRIEFLY "FIXED" ON 2026-09-07 BEFORE THE READ
	// WAS FINISHED. The reasoning was that a downed player must be taking raw,
	// uncapped boss damage with no DR and no through-wall shield, which would
	// make the ten-second solo self-revive unsurvivable next to a Panzer. Every
	// step of that is true except the premise: stock zeroes the damage outright,
	// AFTER running this callback chain and BEFORE anything can be applied —
	// _zm.gsc:5136-5140, "Sledgehammer fix for Issue 43492. This should stop the
	// player from taking any damage while in laststand", a bare
	//     if ( self laststand::player_is_in_laststand() ) return 0;
	// sitting 26 lines below check_player_damage_callbacks. A downed player in
	// this game takes NO damage from anything. Nothing below this line could ever
	// have reached a crawler, so there was never a gap to close.
	//
	// AND PASSING THE ARGUMENT WOULD HAVE MADE THINGS SLIGHTLY WORSE, which is
	// the part worth keeping. The first thing past this guard is
	// `eAttacker.tod_dealt_ms = GetTime()`, the "this boss is engaging" stamp
	// tod_boss_stuck_watch reads. Let a Panzer stamp it by swinging at a body and
	// the stuck-watch stops counting it as stalled — so it is NOT teleported off,
	// and it is still standing there when the player gets up. The guard keeps a
	// boss that is only "fighting" a crawler eligible to be moved along.
	//
	// THE WRONG LESSON WAS DRAWN FROM THE RIGHT SEARCH: Callback_PlayerDamage
	// (_zm.gsc:1415-1567) really does contain no last-stand early-out, and that
	// was read as proof there is none. The zero lives in a DIFFERENT function.
	// If you are about to change this line, open _zm.gsc:5136 first.
	if ( !zm_utility::is_player_valid( self ) )
		return -1;

	// AN ELITE THAT IS HITTING SOMEBODY IS ENGAGING, even if nobody is shooting
	// back and even if it has not moved. tod_boss_stuck_watch's "is it doing
	// anything" test reads tod_actor_cb_ms, which is stamped on the DAMAGED
	// actor — so without this it can only ever see damage TAKEN, and a boss
	// cornering a player it is beating on would accrue stall time and be
	// teleported out of the fight. Cheapest possible stamp on a path that
	// already runs for every hit a boss lands.
	if ( isdefined( eAttacker ) && isdefined( eAttacker.tod_boss_kind ) )
		eAttacker.tod_dealt_ms = GetTime();

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

	// HELLHOUND BITE -20% (v18.2, user 2026-09-06). Keyed on tod_boss_kind,
	// which spawn_hound stamps on the SPAWN FRAME before any wait (its TRAP 3),
	// so no dog can land a hit this cannot see. There is no second hound damage
	// lane to keep in step - the dog has no scripted attack of its own, unlike
	// the Rogue Protector.
	//
	// PLACED BEFORE the defensive domains on purpose: DR, SPRINT ARMOR and BACK
	// ARMOR then multiply the already-reduced number, so the cut composes with
	// them instead of being partly eaten by an int() floor after them.
	if ( isdefined( eAttacker ) && isdefined( eAttacker.tod_boss_kind )
	     && eAttacker.tod_boss_kind == "hellhound" )
	{
		final = int( final * TOD_HOUND_DMG_MULT );
		if ( final < 1 ) final = 1;
		touched = true;
	}

	// DMG REDUCTION domain (the shared upgrade, replaced HEALTH 2026-08-20):
	// v16 ladder — 6/11/15/18/20% cumulative at Lv1..Lv5 (was a flat 5%/Lv to
	// -25%). Panzer MELEE takes the apply_player_mitigations path instead (the
	// pack's callback short-circuits this chain) — never both, no double-dip.
	//
	// The number is NOT written here any more. It used to be a bare
	// `1.0 - 0.05 * dr_lvl` literal duplicated across both lanes, and the comment
	// on this one still claimed "-4%" long after the retune — which is exactly
	// what a second copy of a constant does. tod_upgrades::dr_mult() is the one
	// owner now; it returns 1.0 for an unowned domain, so the > 0 guard moved
	// inside it.
	dr = tod_upgrades::dr_mult( self );
	// THE MAGE'S HEALING AURA (v18.38) folds into the SAME multiplier, so the
	// two stack multiplicatively and the existing "did anything change" test
	// below reports both. Guarded pointer: inert while the class is off.
	if ( isdefined( level.tod_mage_aura_dr ) )
		dr = dr * [[ level.tod_mage_aura_dr ]]( self );
	if ( dr < 1.0 )
	{
		reduced = int( final * dr );
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
// here by calling upgrade_damage_cb itself; no second multiplier table.
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
	{
		self.tod_actor_cb_ms = undefined; // consume this event, not every hit this frame
		return damage;
	}

	// Use the same calculation if stock bypassed the actor chain. The old
	// hand-copied fallback omitted Insta-Kill and the staff matchup/tier
	// multipliers. The stamp above prevents applying this twice to one hit.
	final = self tod_upgrades::upgrade_damage_cb( inflictor, attacker, damage,
	    flags, meansOfDeath, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex );
	// The fallback also stamps the callback. It has already handled THIS hit;
	// do not let that stamp exempt the next ice bolt or splash in this frame.
	self.tod_actor_cb_ms = undefined;
	if ( final == -1 )
		return damage;   // actor callback's unchanged sentinel, not negative damage
	return final;
}

// (Music lives in _tod_atmosphere — the ambient loop is the base state and
// the PANZER's boss_track_start/end swap the channel. Refcount + the
// stoppable-loop primitive are all in that module.)

// BOSS down (the PANZER only, since v14.5): POINTS to every player
// (team-wide); LUCK goes to the LAST HIT only (user 2026-08-20) via
// tod_luck::boss_kill at the call sites. quiet = no per-kill banner.
// THE KILL-FEED ROWS for an elite or boss payout (v17.37, user 2026-09-04: "I
// dont think elites and bosses show up in the money gained section. I would
// expect something like +500 ELITE or +1000 BOSS").
//
// THREE LABELS, NOT SIX (user, same day: "It should be generic ELITE AND BOSS
// thats all no reaver or sprinter", then "Trial win should read +5000 TRIAL
// WIN"). The first cut named each family — Reaver, Sprinter, Rogue Protector,
// Hellhound, Panzer — and those five strings are RETIRED WHOLE from
// localizedstrings/zm_aetherium.str, not just unreferenced. What is left is
// ELITE (killer only), BOSS (team-wide) and TRIAL WIN (team-wide, and the only
// payout here that is not a kill). `name` is read in grant_boss_reward to tell
// the last two apart, and nowhere else — grant_elite_reward has exactly one
// label, so it takes the literal.
//
// The label is an ISTRING because that is what the feed reads:
// AetheriumKillFeed.lua resolves arg 1 through
// Engine.GetIString( ..., "CS_LOCALIZED_STRINGS" ), so a plain GSC string would
// arrive as nothing. NOT the SetHintString cache — these ride the same lane as
// the kit's fifteen existing KF_* rows, and the 250-triggerstring cap is a
// different cache entirely.
function grant_boss_reward( name, pts, quiet )
{
	// (kill text removed 2026-08-20 — points award silently; the drop tells)
	//
	// THE FEED LABEL, decided ONCE before the loop because it cannot vary per
	// player. Only two callers reach here: the boss-round Panzer, and a spire
	// TRIAL win — which is not a boss kill at all, and reads "+5000 TRIAL WIN"
	// on the user's call (2026-09-04). That is the whole reason `name` is read
	// again after being dead since 2026-08-20.
	feed = &"ZM_AETHERIUM_KF_BOSS";
	if ( name == "TRIAL" )
		feed = &"ZM_AETHERIUM_KF_TRIAL";

	players = GetPlayers();
	foreach ( p in players )
	{
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		p zm_score::add_to_player_score( pts );
		// THE FEED ROW, per player, because this payout is TEAM-WIDE: everyone
		// got the money, so everyone should see it. `quiet` has been an unused
		// parameter since the kill text went away and this is exactly the job it
		// was named for.
		if ( !IS_TRUE( quiet ) )
			p LuiNotifyEvent( &"score_event", 2, feed, pts );
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
function grant_elite_reward( name, attacker, org )
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

	// v19.58: round HERE, as add_to_player_score does internally (up to 10s),
	// so the feed row below shows the banked 530, not 525 (odd BOUNTY levels).
	pts = zm_utility::round_up_score( int( pts ), 10 );
	attacker zm_score::add_to_player_score( int( pts ) );

	// THE FEED ROW (v17.37). KILLER ONLY, matching who the money went to — the
	// same rule the payout itself follows. The value sent is the FINAL one,
	// after double points and BOUNTY, so the row can never disagree with the
	// score it just added; the kit's own arms recompute a nominal value instead
	// and that is what made the +100/+110 bug of 2026-08-23.
	//
	// A trash-kill row may appear ALONGSIDE this one for the same corpse (a
	// sprinter is archetype "zombie", a hellhound matches the kit's dog arm).
	// That is not a duplicate: those are two separate payouts — stock's kill
	// money and this 500 — and the feed's running total is the sum a player
	// actually banked.
	attacker LuiNotifyEvent( &"score_event", 2, &"ZM_AETHERIUM_KF_ELITE", int( pts ) );

	// v18.96 — the perk bottle roll (org = where the elite died; undefined = no drop).
	elite_bottle_roll( name, attacker, org );

	// RIOT SHIELD (v17.16, user 2026-09-04: "every elite you kills takes off 2
	// seconds from the recharge time"). This function is where that hangs
	// because it is the ONE place every elite death already resolves to a
	// single killer — every alternative would have meant five separate hooks
	// and five chances to miss one. Guarded level pointer, set in
	// _tod_riotshield::init; never a #using (the KB cycle rule, exactly like
	// tod_bounty_mult_fn above). No-ops unless that player is mid-recharge.
	if ( isdefined( level.tod_shield_elite_kill ) )
		[[ level.tod_shield_elite_kill ]]( attacker );

	// ATTUNEMENT (THE MAGE) -- an elite kill hands part of every running
	// elemental cooldown back. Same hook and same reasoning as the shield line
	// above: this is the ONE place where every elite death in the map already
	// resolves to exactly one killer, so the alternative is five hooks and five
	// chances to miss one. Guarded level pointer, set in
	// _tod_mage_elements::init -- which returns on !TOD_MAGE_ENABLED, so in a
	// shipped build this is one isdefined() per elite death. NEVER a #using.
	if ( isdefined( level.tod_mage_elite_kill ) )
		[[ level.tod_mage_elite_kill ]]( attacker );
	// MANA (2026-09-09): an elite kill is worth a round-scaled chunk of the
	// mage's bar. Same one-place reasoning; `name` tells a guard Panzer apart
	// from the four elite families. The boss-round Panzer pays this in its own
	// lane (panzer death watch), since it never reaches here.
	if ( isdefined( level.tod_mage_elite_mana ) )
		[[ level.tod_mage_elite_mana ]]( attacker, name );
}

// =============================================================================
// v18.96 — THE PERK BOTTLE ROLL (see TOD_ELITE_BOTTLE_PCT). Called from
// grant_elite_reward with the corpse's spot. Tower only, power on, 10%.
// =============================================================================
function elite_bottle_roll( name, attacker, org )
{
	if ( !isdefined( org ) )
		return;
	if ( IS_TRUE( level.tod_spire_active ) )
	{
		elite_dev_log( "bottle: " + name + " died in the spire — no roll (perma perks)" );
		return;
	}
	if ( !( level flag::exists( "power_on" ) ) || !( level flag::get( "power_on" ) ) )
	{
		elite_dev_log( "bottle: " + name + " died before power — no roll" );
		return;
	}
	roll = RandomInt( 100 );
	if ( roll >= TOD_ELITE_BOTTLE_PCT )
	{
		elite_dev_log( "bottle: " + name + " roll " + roll + " >= " + TOD_ELITE_BOTTLE_PCT + " — no drop" );
		return;
	}
	// level thread — specific_powerup_drop can wait internally (map 1's blocking-callers rule).
	level thread zm_powerups::specific_powerup_drop( "tod_free_pap", org );
	elite_dev_log( "bottle: " + name + " roll " + roll + " < " + TOD_ELITE_BOTTLE_PCT + " — PERK BOTTLE dropped at " + org + " for player " + attacker GetEntityNumber() );
}

function elite_dev_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) ) return;
	line = "[TOD_ELITE_DROP] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}
