// WISP TEA SETTINGS (vendored from WetEgg's SATPerksCode pack, 2026-08-30 —
// tower deltas: the localized-hint + machine-anim defines are GONE, see the
// .gsc header for why; everything else is the pack's own tuning).

#define WISP_TEA_PERK_COST					            3000  // user 2026-09-03 (2000 -> 3000, priced up for the two-wisp version); 4000 (pack) -> 300 -> 2000 before. LOCKSTEP: AetheriumPerks.lua's WISP TEA cost row shows this number on the card. The in-world hint takes it by &&1 substitution, so it needs no edit.

#define WISP_TEA_PERK_BOTTLE_WEAPON			            "sat_perk_can_wisp_tea"

#define WISP_TEA_MACHINE_DISABLED_MODEL		            "sat_zm_machine_w_mod_fxanim"
#define WISP_TEA_MACHINE_ACTIVE_MODEL			        "sat_zm_machine_w_mod_fxanim_on"
#define WISP_TEA_RADIANT_MACHINE_NAME			        "sat_vending_wisp_tea"

#define WISP_TEA_WISP_MODEL                             "vfx_sat_fxp_zm_ai_wisp_tea_mask_airflow_01"

#define WISP_TEA_MACHINE_LIGHT_FX			            "_wetegg/sat/perks/fx_wisp_tea_light"
#define WISP_TEA_MACHINE_LIGHT_FX_NAME			        "sat_wisp_tea_light"

#define WISP_TEA_SPECIALTY                              "specialty_nomotionsensor"

#define WISP_TEA_JINGLE                                 "mus_perk_wisptea_jingle"
#define WISP_TEA_STING                                  "mus_perk_wisptea_stinger"

#define WISP_TEA_CLIENTFIELD         			        "hudItems.perks.wisp_tea"

#define WISP_TEA_WISP_DURATION                          30
#define WISP_TEA_WISP_MOVE_SPEED                        225
#define WISP_TEA_WISP_MAX_DISTANCE_TO_PLAYER            400

#define WISP_TEA_COOLDOWN_TIME                          120 //BO7 time is 120 (2 minutes)

// --- HOW MANY WISPS AT ONCE (v17.8, user 2026-09-03: "wisp tea spawn in two
// at once max ... prioritize bosses") -------------------------------------
// A CAP ON CONCURRENCY, NOT A PAIR: a summon still produces ONE wisp, but a
// second lucky hit can put a second one out while the first is still alive.
// Each summon spends a CHARGE, and that charge comes back
// WISP_TEA_COOLDOWN_TIME after ITS OWN wisp expires, so the two slots run
// independent clocks (the pack's single boolean could only ever hold one).
// LOCKSTEP: the buy card's description in
// ui/uieditor/widgets/HUD/Mappings/AetheriumPerks.lua says "two wisps max" in
// words -- the cap is a number here and a promise there, and the player only
// ever reads the promise.
#define WISP_TEA_MAX_WISPS                              2

// Idle parking spots, relative to the owner's tag_origin: 120 ahead and 100
// out to EITHER SIDE, so a pair flanks the player instead of stacking into one
// silhouette. Each live wisp claims a free slot (wisp.wispSlot / .wispIdleOffset,
// assigned in spawnWisp); a lone wisp always takes slot 0, which is the exact
// spot the pack shipped.
//
// WHICH ONE IS PHYSICALLY LEFT: slot 0 is (120,-100,0) — the pack's original —
// and the user reports the single wisp riding on their RIGHT, which makes -y
// right and +y left (the usual Quake basis: local +x forward, +y left, +z up).
// That is an OBSERVATION, not something proven here: stock's siegebot pins
// AnglesToRight to +60 for its right arm and -60 for its left, which proves
// the FUNCTION points right but says nothing about what a LinkTo tuple's y
// means, and _straferun.gsc:1052 pairs its own offset_y with AnglesToRight,
// which reads the opposite way. NOTHING DOWNSTREAM DEPENDS ON THE ANSWER —
// the two spots are symmetric, and the wisps are split across targets by
// wisp_target_is_free(), not by any side test. If they turn out mirrored from
// the names below, swap these two vectors and nothing else moves.
#define WISP_TEA_WISP_IDLE_OFF_A                        (120,-100,0)   // slot 0 — the pack's spot; reported as the player's RIGHT
#define WISP_TEA_WISP_IDLE_OFF_B                        (120,100,0)    // slot 1 — its mirror; the player's LEFT

#define WISP_TEA_WISP_SPAWN_CHANCE                      20 //One in x chance of activating when hitting a zombie
// --- WISP DAMAGE: HITS-TO-KILL BY TIER (v14.20, user: "make sure they dont
// kill bosses or elites crazy fast") ---------------------------------------
// The wisp hits every 0.75s and lives WISP_TEA_WISP_DURATION (30s), so ONE
// wisp lands AT MOST 40 hits. Each tier below is "how many hits to kill a
// full-health target of that tier", so the numbers ARE the time-to-kill:
// hits x 0.75s, and any tier above 40 can never be soloed by one wisp.
//
// !! THE CEILING IS PER WISP, AND THERE ARE TWO OF THEM NOW (v17.8) !! One
// wisp lands at most 40 hits; a PAIR lands at most 80. Every segment count
// below was multiplied by 4/3 in the same version, because the user asked for
// the per-hit damage to drop to 75% now that two wisps are out
// ("make their damage 75% since we have two now") -- and damage here is
// maxhealth/SEGMENTS, so 75% damage is SEGMENTS x 1.3333, not x0.75. Getting
// that backwards would have DOUBLED the damage instead of cutting it.
//
// WHAT 80 BUYS AT THE PANZER TIER: exactly the 80 hits a full pair can ever
// land, so two wisps kill a Panzer only with 100% uptime for the whole 30s of
// both their lives -- never in practice, since they have to fly to him and he
// moves. The v14.20 invariant "wisps alone can never kill a Panzer" is
// therefore back, on the buzzer rather than by a wide margin. It also barely
// matters any more: since v17.8 wisps seek ELITES BEFORE the Panzer
// (wisp_seek_rank), so a pair only piles onto him when nothing else is in
// range.
//
// The pack shipped only the first and last of these and BOTH were wrong for
// this map (see the .gsc's damage note): trash-percentage applied to the
// 20x-health Armored Sprinter, and a flat 1000/hit deleted Panzers.
#define WISP_TEA_DAMAGE_SEGMENTS                        4 //TRASH zombies: 4 hits (3.0s). Was 3 (the pack/BO7 behaviour) until the v17.8 75% damage cut
#define WISP_TEA_ELITE_SEGMENTS                         16 //ELITES (sprinter/hound/reaver/protector): 16 hits = 12s of one wisp, 6s of a pair — and the pair now comes here FIRST. Was 12
#define WISP_TEA_BOSS_SEGMENTS                          80 //PANZER: 80 hits = exactly what a PAIR can land in 30s at 100% uptime, so wisps alone still cannot finish one. Was 60
// THE WARDEN KING (v18.8, user 2026-09-07). The SAME defect the Gift of Death
// had, found while fixing that one: percentage damage cannot see a health wall,
// and the King's whole identity IS the wall (25,000,000 per player). At the
// Panzer's 80 he died in 80 ticks like any other Panzer — and every spire player
// holds Wisp Tea, because ascension grants the entire roster, so a pair could
// take him in about 30 s of uptime with nobody firing a shot.
//
// 1600 = the Panzer tier x20, matching the factor the user chose for the Gift
// that same night (20 shots -> 400). What it buys, in the units the block above
// uses: one wisp lands at most 40 hits per 30 s life and a pair 80, so a solo
// player's pair needs 20 full lifetimes at 100% uptime and a four-player party's
// eight wisps need five. Wisps CONTRIBUTE to this fight; they cannot decide it —
// which is the same invariant WISP_TEA_BOSS_SEGMENTS 80 encodes for the Panzer,
// re-stated for a boss three orders of magnitude bigger.
//
// In practice it is looser still: wisps seek ELITES BEFORE the Panzer
// (wisp_seek_rank), and the King summons elites every 18 s, so they will spend
// most of the fight on his adds rather than on him.
#define WISP_TEA_KING_SEGMENTS                          1600 //THE WARDEN KING: the Panzer tier x20 — see the block above
#define WISP_TEA_NON_ZOMBIE_DAMAGE                      1000 //last-resort fallback: something with no maxhealth and no tier (nothing on this map today)

#define WISP_TEA_WISP_FX    			                "_wetegg/sat/perks/fx_wisp_tea_wisp"
#define WISP_TEA_WISP_TRAIL_FX  			            "_wetegg/sat/perks/fx_wisp_tea_wisp_trail"
