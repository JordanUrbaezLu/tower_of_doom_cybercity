#!/usr/bin/env node
// =============================================================================
// gen_tod_twins.js — batch-generate the twin-swap weapon variants for every
// gun in the CLASS TIER ladders (docs/25).
//
// Ports map 1's PROVEN gen_weapon_variant_gdt.js machinery (field sets, block
// extraction, INT-typed damage trap) into a one-shot batch. v2 (2026-08-22,
// CLASS TIERS) restructured the per-gun table into LADDERS — 4 classes x 3
// tiers — so a gun is ONE entry: where its GDT is, its asset forms, which
// variant axes (ladders) it carries, and its base tune. The tier machinery
// (DPS normalization, never-shrink clips, melee damage per tier) is computed
// here from the class's T1 gun; the GSC side (_tod_classes::register_gun +
// _tod_upgrades::twin_suffix) builds the same variant names from the same
// axis letters.
//
// AXES (the user rule 2026-08-19: any upgrade touching gun data = 3 levels):
//   f FIRE RATE   fireTime x0.92/0.84/0.76          h HANDLING  reload+swap+ADS x0.85/0.75/0.65
//   r RECOIL      kick x0.90/0.80 (2 lv)            m MAG SIZE  clipSize x1.3/1.6/1.9
//   p PENETRATION small > medium > large (2 lv)     k KNIFE SPEED meleeTime+charge -10%/Lv (5 lv)
// Variant name = <stem>[<pap suffix>]_<letter><level>...  (e.g. t9_mp5_up_f1h2,
// t9_krig6_r0m3, t9_stoner63_p1, t9_me_knife_american_k4); an axis-less gun
// has ONE base-tuned form "_b". Level-0 forms are REAL assets (they carry the
// base tune) — a player never holds the raw install asset.
//
// Emits, all idempotent (safe to re-run):
//   source_data/tod_weapon_twins.gdt      the variant weapon blocks
//   zone_source/tod_twins.zpkg            weapon, lines (+ include,tod_twins in main zone)
//   gamedata/.../zm_levelcommon_weapons.csv  variant->_up rows (keeps Pack-a-Punch working)
// and prints the REGISTRATION LEDGER (map 1 measured ~230 safe / 368 = boot
// AV, docs/21 §A) — and THROWS above LEDGER_GUARD.
//
// ONE GUN PER BUILD: flip a ladder entry's `enabled` to true, regenerate,
// build, boot-test, then the next (map 1's hard rule).
// =============================================================================

'use strict';

const fs = require('fs');
const path = require('path');

const REPO = path.join(__dirname, '..');
const TOOLS = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const OUT_GDT = path.join(REPO, 'source_data', 'tod_weapon_twins.gdt');
const OUT_ZPKG = path.join(REPO, 'zone_source', 'tod_twins.zpkg');
const CSV = path.join(REPO, 'gamedata', 'weapons', 'zm', 'zm_levelcommon_weapons.csv');

// ---- field sets (verbatim from map 1's proven tool) ------------------------
const RECOIL_KEYS = new Set([
  'hipGunKickPitchMin', 'hipGunKickPitchMax', 'hipGunKickYawMin', 'hipGunKickYawMax',
  'adsGunKickPitchMin', 'adsGunKickPitchMax', 'adsGunKickYawMin', 'adsGunKickYawMax',
  'hipViewKickPitchMin', 'hipViewKickPitchMax', 'hipViewKickYawMin', 'hipViewKickYawMax',
  'adsViewKickPitchMin', 'adsViewKickPitchMax', 'adsViewKickYawMin', 'adsViewKickYawMax',
]);
const FIRE_KEYS = new Set(['fireTime', 'holdFireTime', 'introFireTime']);
const RELOAD_KEYS = new Set([
  'reloadTime', 'reloadEmptyTime', 'reloadAddTime', 'reloadEmptyAddTime',
  'reloadStartTime', 'reloadStartAddTime', 'reloadEndTime',
  'reloadQuickTime', 'reloadQuickEmptyTime', 'reloadQuickAddTime', 'reloadQuickEmptyAddTime',
]);
const SWAP_KEYS = new Set([
  'raiseTime', 'firstRaiseTime', 'altRaiseTime', 'quickRaiseTime', 'emptyRaiseTime',
  'dropTime', 'emptyDropTime',
]);
// ADS transition — folded into HANDLING (user 2026-08-19 "add ADS to handling")
const ADS_KEYS = new Set(['adsTransInTime', 'adsTransOutTime']);
// Melee swing speed — map 1's ballistic Berzerker recipe (meleeTime/meleeChargeTime)
const MELEE_KEYS = new Set(['meleeTime', 'meleeChargeTime']);

// NO MELEE LUNGE, ROSTER-WIDE (user 2026-08-23: "Remove the lunge swing from
// all melee. It makes them inconsistent").
// meleeLungeRange is the automatic step-toward-the-target the engine adds to a
// swing. It was never set here, so each blade inherited whatever its port
// shipped — and they disagreed: Combat Knife 100, Wakizashi 70, Stormbreaker 0.
// Three blades, three different reach-on-swing behaviours, which is exactly the
// inconsistency the user felt: the same swing at the same distance connects on
// one tier and whiffs on the next. Forcing 0 makes every blade's reach purely
// its own meleeRange, so a promotion changes damage and speed and NOTHING about
// where the swing lands. Guns already ship 0, so this only ever touches melee.
// Applied as a str override (meleeLungeRange is quoted in the GDT) inside
// baseTune, which every form AND every k-ladder twin passes through.
// *** meleeChargeRange IS THE LUNGE. meleeLungeRange ALONE DOES NOTHING. ***
// 2026-08-23, second attempt. The first pass zeroed only meleeLungeRange and the
// user still lunged with the combat knife. The field that actually drives the
// charge-toward-target on a swing is meleeChargeRange, and MAP 1 ALREADY PROVED
// IT: its LIVE leviathanaxe.gdt carries meleeChargeRange "0" while the pristine
// pack copy — the one THIS generator reads as its source — still has "100".
// So the axe was fixed over there and our roster never inherited it.
// Both fields are zeroed here: meleeChargeRange kills the lunge, meleeLungeRange
// is kept at 0 for consistency (it was the roster's other inconsistency — knife
// 100 / wakizashi 70 / stormbreaker 0).
// Do NOT also zero meleeChargeTime / meleeChargeDelay: those are the swing's own
// animation timing, map 1 left them alone, and the k-ladder scales meleeTime.
const MELEE_NO_LUNGE = { meleeLungeRange: '0', meleeChargeRange: '0' };
// RESERVE +30% ON EVERY GUN (user 2026-08-23: "all guns need a reserve increase
// by 30%"). maxAmmo/startAmmo are in MAGAZINES (see the PaP note below), so
// x1.3 is rounded to whole mags by scaleSets (INT_KEYS). Applied in baseTune's
// base pass ONLY: the _up form copies maxAmmo/startAmmo verbatim from the
// TUNED base (PAP_COPY_KEYS, computePapSet), so every PaP form inherits the
// bump without a second scale; ladder variants never touch these keys; melee
// forms carry 0 and scaleSets keeps 0. The three ported SIDEARMS are not
// generated here — their install-side GDTs get the same x1.3 by hand (same
// rounding), see CHANGELOG v9.36.
// 1.3 -> 1.4 (user 2026-08-23: "increase reserve of all guns from 30% to 40%").
// THREE DOWNSTREAM EFFECTS, checked before changing it:
//  1. IT MULTIPLIES WITH CLASS_RESERVE_MULT, it does not replace it. Skirmisher
//     goes 1.3x1.3 = 1.69x -> 1.4x1.3 = 1.82x. That is intended: the class knob
//     was defined as "on top of global", so raising global raises it too.
//  2. SCAVENGER (the "reserve" upgrade domain) does NOT compound. It is a KILL
//     REFUND — one round per N kills — not a multiplier, so it cannot stack
//     multiplicatively here. It only gains headroom, because a refund is capped
//     by maxAmmo. Beneficial and bounded.
//  3. THE TWO REMAINING HAND-TUNED SIDEARMS FALL 7.7% BEHIND. t9_magnum and
//     t9_amp63 are NOT generated here — their reserves were multiplied by 1.3 by
//     hand in the mod-tools GDTs. They stay at 1.3 while everything else moves to
//     1.4. DELIBERATELY NOT FIXED: those GDTs live outside this repo and are
//     SHARED WITH MAP 1, so editing them would silently change that map's guns
//     too. 7.7% on a sidearm nobody empties is the cheaper error. (The Bulldog is
//     no longer in this group — v10.8 made it a generated variant, so it tracks
//     the multiplier automatically.)
// maxAmmo/startAmmo are counted in MAGAZINES and INT-rounded, so a small gun may
// not move at all while a large one gains a whole magazine.
// 1.4 -> 1.0 (user 2026-08-24: "Now that we have ammo crates lets reduce the
// ammo reserve constant ... we can just remove that now"). The global buff
// existed because this map has NO mystery box and NO wallbuys, so the reserve
// was the only ammo in the game. The breather AMMO CRATES (5,000, four of them,
// _tod_ammo_crate.gsc) are now that supply, so carried ammo goes back to the
// ports' own values and the crates become the answer to running dry.
// EFFECT: every gun loses ~29% of its carried rounds. The skirmisher keeps its
// own CLASS_RESERVE_MULT 1.3 (that knob is a decision about the SMG line and is
// unrelated to this one), so it lands at 1.3x source rather than 1.82x.
const RESERVE_MULT = 1.0;
const RESERVE_KEYS = new Set(['maxAmmo', 'startAmmo']);

// ---- PER-CLASS TUNING (user 2026-08-23, after the full playthrough) ---------
// "We need a buff on the skrimisher class. Mostly all around ammo pgrade by 30%
// on reserve for all skirmisher guns ... Damage on all skirmisher can get buffed
// by 10%."
//
// THESE STACK ON TOP OF THE GLOBAL PASS, deliberately and on the user's explicit
// confirmation ("Yes 30% on top of global"). RESERVE_MULT 1.3 already applies to
// every gun in the map, so a skirmisher gun ends at 1.3 x 1.3 = 1.69x its GDT
// reserve. Keeping the two as separate knobs rather than baking 1.69 into
// RESERVE_MULT matters: the global one is a map-wide economy decision and the
// class one is a balance decision about the SMG line, and they will move
// independently.
const CLASS_RESERVE_MULT = { skirmisher: 1.3 };

// DAMAGE IS APPLIED TO THE TIER-1 GUN ONLY — see the guard in baseTune. T2/T3
// damage is NORMALIZED from the tuned T1 inside computeTierOverrides
// (t1.damage x TIER_DPS x fireTime/t1.fireTime), so the bump propagates up the
// ladder by construction and the 1 / 1.5625 / 2.4414 tier relationship is
// preserved exactly. Scaling the higher tiers here as well would apply it TWICE
// on them (once inherited through normalization, once directly) and quietly turn
// a +10% class buff into +21% for the MP5 and MP7.
// 1.10 -> 1.15 (user 2026-08-23: "It needs an overall damage buff by 15%").
// READ AS THE TOTAL, NOT AS A SECOND BUMP: this replaces the earlier +10%, so
// the SMG line is +15% over its raw GDT damage, not 1.10 x 1.15 = +26.5%. Say so
// if a further +15% on top was meant — it is a one-digit change either way.
// SKIRMISHER *IS* THE SMG CLASS: MAC-10 / MP5 / MP7 are its three tiers, so this
// one knob is the whole SMG roster and nothing else moves.
// HEAVY -10% (user 2026-08-24: "The LMG class needs a damage nerf by 10%").
// Same T1-ONLY rule as the skirmisher line above, and for the same reason: 0.90
// lands on the STONER's damage/minDamage, and computeTierOverrides normalizes
// the HK21 and the Death Machine from that TUNED T1 — so the whole LMG line is
// exactly -10% and the 1 / 1.5625 / 2.4414 tier spacing is preserved. Scaling
// the higher tiers here as well would compound to -19% on them.
// HEAVY 0.90 -> 0.81 (user 2026-08-24: "nerf LMG class damage overall by 10%").
// A FURTHER 10% on top of the earlier one, i.e. 0.90 x 0.90 — the LMG line now
// sits 19% below its raw port damage. Context: the armory audit put HEAVY top of
// the DPS table at every tier (T1 3,187 vs assault 2,000) while ASSAULT sat
// 33-37% below both other classes, so this closes the gap from the top.
// Still T1-ONLY — computeTierOverrides normalizes the HK21 and Death Machine
// from the tuned Stoner, so it propagates by construction.
// SKIRMISHER 1.15 -> 1.3225 (user 2026-08-25: "give the smg class gun primaries
// and secondaries 15% damage increase"). 1.15 x 1.15 — a FURTHER 15% on top of
// the existing knob, so the SMG line now sits 32.25% above its raw port damage.
//
// THIS ONE KNOB MOVES THE SECONDARIES TOO, which is why there is no second
// entry for them. Every skirmisher secondary is CAPPED rather than
// ladder-derived: computeSecondaryOverrides clamps each one to
// PRIMARY_T1[cls].dps x SEC_CAP_REL[tier], and all three sit exactly on that
// ceiling (Bulldog 1,908 DPS = MAC-10 2,981 x 0.64). PRIMARY_T1 is measured
// from the TUNED T1 primary, so raising this multiplier raises the MAC-10, the
// MAC-10 raises the ceiling, and the Bulldog / SG12 / SPAS-12 all rise with it
// by exactly the same 15%. Adding a separate secondary knob would have applied
// the buff twice.
//
// The PaP forms need nothing either: papApply derives them as tuned-base x1.25,
// so +15% on the base is +15% on the PaP by construction.
const CLASS_DAMAGE_MULT  = { skirmisher: 1.3225, heavy: 0.81 };

// SECONDARIES ARE 25% WEAKER THAN THEY SHIPPED (user 2026-08-24: "the current
// secondaries need an all around 25% nerf ... make sure they are all pretty
// weak compared to the primary slot"). ONE knob for every gun carrying
// `secondary: true`. The two RAW PORTS (pistol_standard, t9_amp63) have no GDT
// in this tree and take the same 0.75 script-side in
// _tod_upgrades::gun_balance_mult, which is the ONLY other place a secondary's
// damage is touched. Move both or neither.
//
// THIS IS THE SEAT THE COMING SEC_DPS LADDER TAKES. When secondaries go
// per-tier (4 classes x 3 tiers), the T1 rung keeps this multiplier and T2/T3
// normalize FROM the tuned T1 exactly the way CLASS_DAMAGE_MULT feeds
// computeTierOverrides — so this stays a T1-only knob and never gets applied a
// second time up the ladder.
//
// IT RE-NERFS THE BULLDOG DELIBERATELY. Its own x0.5 -> x0.75 -> removed
// history (see gun_balance_mult) was a decision about the Bulldog ALONE against
// the roster it sat in; this is a decision about the whole SECONDARY SLOT. The
// old script nerf is still gone and is not coming back — do not stack them.
//
// APPLIED IN BOTH BRANCHES OF baseTune, and it has to be. The base form takes
// it through the sets[] pass; the _up form cannot, because both of today's
// secondaries PIN their PaP damage as a literal in `tune.setUp` (the Bulldog's
// 240 so the uniform x1.25 cannot ship a PaP weaker than stock, the Magnum's
// 1750 so its headshot number does not move) and absSet writes those AFTER
// papApply. Scale only the base and the PaP forms keep their full pinned
// damage — the nerf would silently apply to exactly half of each gun.
const SECONDARY_DMG_MULT = 0.75;
const DAMAGE_KEYS = new Set(['damage', 'minDamage']);
// Splash damage. Deliberately NOT part of DAMAGE_KEYS: tier normalization
// derives `damage` from a DPS target and splash has no place in that math.
// But the flat SECONDARY_DMG_MULT must reach it, or a launcher secondary keeps
// 100% of the number that actually kills things while its direct hit — the
// number almost nobody lands with a rocket — takes the full -25%.
const EXPLOSION_KEYS = new Set(['explosionInnerDamage', 'explosionOuterDamage']);
// MAG SIZE as REAL twins (user 2026-08-20). clipSize ONLY. startAmmo/maxAmmo are
// counted in MAGAZINES, not rounds (krig = 8 mags x 30 = 240 reserve), so scaling
// them multiplied total ammo on top of the clip growth — the 'unlimited ammo' bug.
const MAG_KEYS = new Set(['clipSize']);
// Fields that must stay INTEGERS after scaling — clip/ammo counts (whole
// rounds) and damage (map 1's INT-typed damage trap: a float damage value
// silently reads as 0 in game).
const INT_KEYS = new Set([...MAG_KEYS, 'damage', 'damageMin', 'minDamage', 'startAmmo', 'maxAmmo']);

// ---- ladders (step tables; index = level) -----------------------------------
const FIRE_STEP = [1, 0.92, 0.84, 0.76];     // f0..f3
const HANDLING_STEP = [1, 0.85, 0.75, 0.65]; // h0..h3 (reload+swap+ADS)
// RECOIL ladder. History: -25/-45/-65% (2026-08-19) -> HALVED 2026-08-21 (user:
// "nerf the recoil upgrade by like 50%") to -10/-20/-30% -> v9.45 2026-08-23
// (user: "recoil should be two levels only. 8% and 16%") to TWO levels at
// -8/-16% -> 2026-08-26 ASSAULT BUFF (user: "Recoil will go to 10% per level")
// to -10/-20%, still two levels. The card art + the Lua DOMAIN desc + the Lua
// DETAIL val table + add_domain's max carry these numbers — keep all of them in
// lockstep, and note that AXIS.r.levels below is the one that decides how many
// weapon assets actually get emitted (unchanged at 2, so this retune changes
// gun DATA only: same asset names, same registration count, no dead forms).
const RECOIL_STEP = [1, 0.90, 0.80];         // r0..r2
// KNIFE SPEED — LOGARITHMIC, not linear (user 2026-08-23, after the full
// playthrough: "The melee class needs a nerf for sure. Its mostly the melee
// swing speed and the leech HP. Maybe we can increase logorithimcally for both
// instead of linearly per level. It ends up getting crazy.").
//
// WAS [1, .9, .8, .7, .6, .5] — a flat -10%/Lv reaching HALF swing time at k5,
// which stacked with the slasher's 1.1 move speed and one-hit kills to round 14
// is the "crazy" the user means. NOW 1 - 0.10*log2(1+Lv), tabulated:
//   k0 1.00   k1 0.90   k2 0.84   k3 0.80   k4 0.77   k5 0.74
// LEVEL 1 IS DELIBERATELY IDENTICAL to the old curve (-10%) — the first point
// a player spends must feel the same as it always did; it is the TAIL that is
// cut, from -50% down to -26%. Diminishing returns is the whole idea: every
// further level still helps, none of them doubles you.
// Kept as an explicit TABLE rather than computed so the shipped numbers are
// readable here and cannot drift with a Math change.
const KNIFE_STEP = [1, 0.90, 0.84, 0.80, 0.77, 0.74];   // k0..k5
const MAG_STEP = [1, 1.3, 1.6, 1.9];       // m0..m3 — +30%/Lv (user 2026-08-20)
// PENETRATION tiers (user 2026-08-21): the engine's three values are small /
// medium / large — there is no "low" (verified across the Skye pack).
const PEN_TIER = ['small', 'medium', 'large'];

// axis letter -> how a level scales a block. `sets` = [[keySet, stepTable]]
// (scaleSets); `pen` = the string-valued penetrateType ladder. The GSC side
// (_tod_classes::register_gun axes) uses the SAME letters.
const AXIS = {
  f: { domain: 'firerate',    levels: 3, sets: [[FIRE_KEYS, FIRE_STEP]] },
  h: { domain: 'handling',    levels: 3, sets: [[RELOAD_KEYS, HANDLING_STEP], [SWAP_KEYS, HANDLING_STEP], [ADS_KEYS, HANDLING_STEP]] },
  r: { domain: 'recoil',      levels: 2, sets: [[RECOIL_KEYS, RECOIL_STEP]] },   // v9.45: 3 -> 2 (user)
  m: { domain: 'magsize',     levels: 3, sets: [[MAG_KEYS, MAG_STEP]] },
  k: { domain: 'knifespeed',  levels: 5, sets: [[MELEE_KEYS, KNIFE_STEP]] },
  p: { domain: 'penetration', levels: 2, pen: true },
};

// ---- BASE OVERRIDES (user 2026-08-21) --------------------------------------
// Tuning that must apply to the gun ITSELF, not to an upgrade level: every
// gun's moveSpeedScale forced to 1.0, a +15% recoil bump across the roster,
// +20% ADS time, and per-gun clip/rate tunes.
//
// WHY THIS IS A TWIN AND NOT A GDT EDIT: the Skye GDTs live in the shared tools
// root and map 1 ALREADY rewrites their moveSpeedScale. Editing them here would
// silently retune map 1's guns.
//
// WHY MOVE SPEED MUST BE 1.0: the weapon's own moveSpeedScale MULTIPLIES with
// the player scale our class system sets, so a 0.95 gun made HEAVY really run
// at 0.8 x 0.95 = 0.76 — a hidden second penalty. With guns at 1.0,
// class_speed_base() is the single owner of move speed (user's call).
const RECOIL_BUMP = 1.15;              // +15% kick on every gun (user 2026-08-21)
const KRIG_RECOIL_BUMP = 1.5625;       // krig ONLY: kick on top of the roster bump
                                       // (1.25 -> 1.5625, user 2026-08-21, two passes of
                                       // "nerf the krig recoil by another 25%") -> x1.797 stock
const ADS_BUMP = 1.20;                 // ADS in/out TIME +20% = slower ADS, a deliberate
                                       // mobility nerf across every gun including the knife
// KRIG CLIP 25 (user 2026-08-21, was 30). RETIRE IT when the Krig becomes the
// assault T2 gun (user 2026-08-22 #7: "tier-2 clips smaller than tier-1 — fix
// this") — set KRIG_CLIP = undefined in that build; the never-shrink rule
// (CLIP_STEP) then lifts it to round(Enfield 30 x 1.10) = 33.
const KRIG_CLIP = undefined;           // RETIRED 2026-08-22 (Phase 2b): the Krig is assault T2 now; the
                                       // never-shrink rule sets its clip from the Enfield (30 x 1.10 = 33)
// KRIG RATE OF FIRE -> 600 rpm (user 2026-08-21). Stock fireTime is 0.092
// (652 rpm) and 600 rpm is 0.1s, so this is applied as a RATIO.
const KRIG_FIRE_SCALE = 0.1 / 0.092;
const STONER_CLIP = 60;                // Stoner base magazine -20%, was 75 (user 2026-08-21)

// ---- HIT-LOCATION MULTIPLIERS: NORMALIZED ACROSS THE ROSTER ---------------
// USER RULE (2026-08-21): "headshot multiplier needs to be 3x for all guns ...
// NO GUNS SHOULD VARY UNLESS I EXPLICITLY SAY SO." The ports ship these wildly
// uneven (mp5 3.0 / krig 6.0 / stoner 5.0 / enfield 5.0 / hk21 torso 2.0 ...).
// Helmet mirrors the head, neck is head-adjacent -> all three 3.0; every other
// body zone 1. Differentiation comes ONLY from the HEADSHOT upgrade domain.
// LOC_NORM only names the four keys every port already agreed on. LOC_FLAT is
// the REST of the hit-location table — every port in the roster ships these at
// 1 already, so they never needed setting until the Magnum arrived with 2.0
// limbs and a 4.0 torso-mid. Applied only where a gun asks for it.
const LOC_FLAT = {
  locTorsoMid: 1, locTorsoLower: 1,
  locLeftArmLower: 1, locLeftArmUpper: 1, locLeftFoot: 1, locLeftHand: 1,
  locLeftLegLower: 1, locLeftLegUpper: 1,
  locRightArmLower: 1, locRightArmUpper: 1, locRightFoot: 1, locRightHand: 1,
  locRightLegLower: 1, locRightLegUpper: 1,
};

const LOC_NORM = {
  locHead: 3.0,
  locHelmet: 3.0,
  locNeck: 3.0,
  locTorsoUpper: 1,
};

// ---- CLASS TIERS (docs/25 §6) ------------------------------------------------
// A tier's BASE form is "about as strong as the PaP'd version" of the tier
// below — in DPS. PaP is +25% damage AND +25% fire rate, so a PaP form is
// x1.5625 the DPS of its base; therefore T2 base = T1 base x1.5625 (= T1 PaP
// DPS) and T3 base = T2 PaP DPS = x1.5625^2 = x2.4414. (The first cut used
// x1.25 / x1.5625 — damage-only — which made every promotion a DPS DOWNGRADE
// until the new gun was PaP'd again; caught by the user 2026-08-22.)
// Applied to DAMAGE (minDamage keeps the port's own min/max ratio) at the
// gun's OWN fire time — the port keeps its feel. Only computed when the
// class's T1 gun is ENABLED.
const PAP_DPS = 1.25 * 1.25;                       // damage x rate
const TIER_DPS = [0, 1, PAP_DPS, PAP_DPS * PAP_DPS];   // 1 / 1.5625 / 2.4414
// A promotion never shrinks the magazine (user 2026-08-22 #7): each tier's
// clip >= round( previous tier's tuned clip x CLIP_STEP ).
const CLIP_STEP = 1.10;

// ---- THE SECONDARY LADDER (user 2026-08-24) --------------------------------
// "every tier for every class needs its own secondary ... each teir of
// secondsries will get better just like the primaries do". SAME steps as the
// primary ladder on purpose: reusing TIER_DPS means a secondary sits at a
// CONSTANT fraction of its class's primary at every tier, so "pretty weak
// compared to the primary slot" holds at T1 and still holds at T3 without a
// second knob to keep in sync. Split them only if the gap should CHANGE as you
// climb, which is not what was asked for.
const SEC_DPS = TIER_DPS;

// ---- THE CEILING: A SECONDARY MAY NOT BEAT THE PRIMARY ONE TIER BELOW -------
// (user 2026-08-24, after an audit of the shipped numbers: "These secondaries
// should not be competing with primary guns in DPS. I would say maybe the
// secondaries should be comparable to the primary of the tier below.")
//
// The audit was right and the margin was not subtle — measured on the build
// that shipped, every skirmisher sidearm sat at 1.86x its OWN SAME-TIER primary
// and every assault one at 1.63x. The tier-2 SG12 alone did 8,625 DPS against
// the MAC-10's 2,981.
//
// So each secondary tier is capped at the DPS of the primary ONE TIER BELOW it:
//   sec T2 <= primary T1     sec T3 <= primary T2
// Tier 1 has no primary below it, so the ladder is extended one step DOWN by
// the same ratio it climbs: 1 / PAP_DPS = 0.64 x primary T1. That is a choice,
// not a measurement — it is the only rung the user's rule does not name.
const SEC_CAP_REL = [0, 1 / PAP_DPS, 1, PAP_DPS];

// CEILING, NOT TARGET (user's explicit pick over "every secondary moves to the
// rule"). Only guns ABOVE the cap come down; guns already under it are left
// exactly where they are, so this nerfs the skirmisher and assault lines and
// does not touch heavy or slasher.
//
// THE BASELINE IS THE EXISTING SECONDARY LADDER, AND IT HAS TO STAY. "Already
// under the cap, so leave it alone" is only true relative to what the gun
// CURRENTLY SHIPS — which is the SEC_DPS ladder value, not the raw port number.
// Delete that ladder and call the cap the whole rule and the under-cap guns
// fall back to their port damage: the Klauser would ship at 15 and the RPG at
// 5,250. The two passes compose — ladder first, then clamp.
const SEC_CAP_ONLY = true;

// Measured primary T1 per class, filled in by computeTierOverrides — the thing
// the cap is computed FROM. { dps } only; the caller supplies its own fireTime
// and shotCount when converting a DPS target back into a damage number.
// Every class has one, INCLUDING the melee slasher, so unlike SEC_T1_REF below
// there is nothing declared here and nothing to keep in sync by hand.
const PRIMARY_T1 = {};

// T1 REFERENCE DPS PER CLASS — what T2/T3 are normalized FROM.
//
// Two of the four T1 secondaries are GENERATED twins and are MEASURED like any
// primary T1 (skirmisher Bulldog, assault Magnum) — they are absent from this
// table for that reason. The other two are RAW PORTS the map hands out as-is,
// so there is no tuned block to measure and their reference is DECLARED here:
//
//   slasher  t9_amp63        READ from skye_t9_amp63.gdt (damage 135,
//                            fireTime 0.092) times the 0.75 script nerf in
//                            gun_balance_mult = 101. Measured once, by hand,
//                            2026-08-24 — re-read it if that GDT ever moves.
//   heavy    pistol_standard NOT MEASURABLE AT ALL. The MR6 is stock and its
//                            GDT is not in this tools tree, so its ~25 base
//                            damage times the x7.2 script multiplier (180) and
//                            its fire time are both DECLARED, not read. This is
//                            the one number in the whole ladder nobody can
//                            verify from a file; treat the heavy secondary line
//                            as hand-tuned and judge it by play, not by the log.
//                            The moment the MR6 is replaced by a twinned gun,
//                            delete this row and let it be measured.
// `shot` = shotCount, the projectiles per trigger pull. It is part of the
// reference because `damage` in a GDT is PER PROJECTILE: a shotgun's 250 is
// 250 x 8 pellets on target, a revolver's 250 is 250. Both raw-port T1s here
// are single-projectile, so both are 1 — but state it, because the moment one
// of them is replaced by a shotgun an omitted 1 becomes an 8x error that
// nothing in the log would flag.
const SEC_T1_REF = {
  slasher: { damage: 101, fireTime: 0.092, shot: 1 },
  heavy:   { damage: 180, fireTime: 0.150, shot: 1 },
};

// Melee has no DPS: damage per tier [base, PaP]. The knife keeps its shipped
// 1700/20000 (user 2026-08-21, exempt from the uniform PaP rule); each step
// doubles so a tier buys ~7 more one-shot rounds (zombie HP x1.1/round).
// MUST STAY IN LOCKSTEP with register_melee_dmg() in _tod_classes.gsc — this
// value drives the ASSET's meleeDamage, that one drives DoDamage. Retuned
// 2026-08-23 from 1700/20000, 20000/40000, 40000/80000: the old first step was
// a x11.8 jump (knife PaP == katana base), so a PaP'd tier-1 knife already
// one-hit to round 38. Now a clean x2 ladder, tier N base = tier N-1 PaP,
// mirroring the gun rule. See the comment block at _tod_classes.gsc for the
// one-hit-reach table this was tuned against.
// STORMBREAKER -15% (user 2026-08-24: "Storm breaker needs an all around nerf
// by like 15%"). Tier 3 only: 8000/16000 -> 6800/13600, base and PaP alike, so
// the axe is 15% weaker in every form it can be held in. One-hit reach against
// this map's HP curve drops storm r29 -> r28 and PaP r36 -> r35.
// KNOWN AND ACCEPTED: this is the one rung that now breaks the "tier N base =
// tier N-1 PaP" ladder — the katana's PaP (8000) out-damages a fresh
// Stormbreaker (6800) until the axe is PaP'd. That is a ~1-round dip in one-hit
// reach, not the x11.8 cliff the ladder was built to kill, and it is the direct
// consequence of nerfing the top rung alone.
const MELEE_TIER_DMG = { 1: [2000, 4000], 2: [4000, 8000], 3: [6800, 13600] };

// BACKSTAB (user 2026-08-24: "BACKSTAB DAMAGE IS COMPLETELY UN-NORMALIZED
// ACROSS THE BLADES"). meleeFromBehindDamage came straight off each port and
// was incoherent in three separate ways:
//     knife       2,000 front / 1,700 behind   <- backstab WEAKER than a frontal hit
//     knife PaP   4,000 front / 20,000 behind  <- a TIER 1 weapon's 5x one-shot
//     wakizashi   4,000 / 1,700                <- backstab less than half a frontal hit
//     stormbreaker 6,800 / 0 and PaP 13,600 / 0 <- the TOP blade had none at all
// so the T1 PaP knife out-backstabbed the T3 Stormbreaker by infinity, and two
// of the six forms punished the player for flanking.
//
// DERIVED FROM MELEE_TIER_DMG, never authored: a uniform x1.5 of whatever that
// form's frontal damage is. That keeps the bonus a real mechanic (flanking is
// the slasher's only positioning skill) while making it monotonic up the ladder,
// and it stays in lockstep automatically the next time the tier damages move.
//
// x1.5 SPECIFICALLY so the map's backstab CEILING DOES NOT RISE: the highest
// backstab in the game today is the PaP knife's 20,000, and the highest after
// this is the PaP Stormbreaker's 20,400 — the same number, moved onto the
// weapon that should own it. One knob if you want a bigger or smaller bonus.
const BACKSTAB_MULT = 1.5;
// Registration ledger: every `weapon,` line the map links.
//
// GUARD RAISED 200 -> 220 (2026-08-23) to pay for ASSAULT AXIS PARITY: r + m on
// all three assault guns is 3 x 32 = 96 registrations (was 46), landing the
// real ledger at 216. Map 1 shipped a BOOTING .ff carrying 229 weapon assets
// total (docs/21 §A: "the total table, twins + base + PaP + stock cooked WWs")
// and its measured wall sits between 230 (booted) and 368 (crashed) — so 216
// total is under a known-good TOTAL, with ~14 of margin.
// DO NOT RAISE THIS AGAIN to buy a THIRD axis on any gun: axes MULTIPLY, so a
// third axis on a 2-axis gun costs +64 by itself (the skirmisher's f/h/m would
// need 384). Buy budget back by retiring an axis instead.
const LEDGER_GUARD = 220;

// THE FIXED COUNT USED TO BE A HARDCODED 15 AND IT ROTTED (caught 2026-08-23):
// the six per-class secondaries (v9.29) and the AMP63 dual-wield `ldw` half
// (v9.29a) were zoned without anyone bumping it, so the tool under-reported by
// 7 and the guard was not guarding — at the old 200 the true figure was already
// 216 with the ledger printing green. It is COUNTED now: the main zone plus
// every zpkg it `include,`s, minus our own generated output (those are
// `total`). Nothing left to keep in sync.
function countFixedRegistrations() {
  const ZONE_DIR = path.join(REPO, 'zone_source');
  const mainZone = path.join(ZONE_DIR, 'zm_tower_of_doom.zone');
  const files = [mainZone];
  const zoneText = fs.readFileSync(mainZone, 'utf8');
  for (const m of zoneText.matchAll(/^include,(\S+)\s*$/gm)) {
    const f = path.join(ZONE_DIR, m[1] + '.zpkg');
    if (path.resolve(f) === path.resolve(OUT_ZPKG)) continue;   // our own output
    if (fs.existsSync(f)) files.push(f);
    else console.warn(`  ledger: include,${m[1]} has no .zpkg — not counted`);
  }
  let n = 0;
  const detail = [];
  for (const f of files) {
    const c = (fs.readFileSync(f, 'utf8').match(/^weapon,/gm) || []).length;
    if (c) detail.push(`${path.basename(f)} ${c}`);
    n += c;
  }
  console.log(`  ledger: fixed registrations = ${n}  (${detail.join(', ')})`);
  return n;
}

// ---- PACK-A-PUNCH = BASE +25% ACROSS THE BOARD (user 2026-08-21) -----------
// The _up asset keeps its own model/fx/camo lines; every TUNED stat is
// overwritten with the tuned base's value made 25% better:
//   bigger-is-better  x1.25 : damage, damageMin/minDamage, clipSize, meleeDamage
//   fire times        /1.25 : fireTime family (= +25% rpm)
//   smaller-is-better x0.75 : reload, swap, ADS, recoil, melee-swing times
//   copied verbatim    x1   : maxAmmo/startAmmo (reserve is in MAGAZINES),
//                             moveSpeedScale (class owns speed, stays 1.0),
//                             hit-location multipliers (never out-multiply base)
// Variant ladders compose ON TOP of the papped values.
const PAP_UP   = 1.25;        // damage/clip multiplier (+25%)
const PAP_FAST = 1 / 1.25;    // fire-time divisor (+25% rate)
const PAP_TRIM = 0.75;        // time/kick reduction (-25%)
const PAP_COPY_KEYS = new Set(['maxAmmo', 'startAmmo', 'moveSpeedScale',
  'locHead', 'locHelmet', 'locNeck', 'locTorsoUpper']);
// v2 (2026-08-22): `minDamage` (the Skye field; `damageMin` never existed)
// joins the +25% rule — the port's own PaP falloff floors were arbitrary
// (the MAC-10's doubled, the MP7's +86%), and "every gdt stat" was the order.
const PAP_UP_KEYS   = new Set(['damage', 'minDamage', 'clipSize', 'meleeDamage']);

// =============================================================================
// THE LADDERS (user-locked 2026-08-22):
//   SKIRMISHER  MAC-10 -> MP5 -> MP7        ASSAULT  Enfield -> Krig 6 -> AK-47
//   HEAVY       Stoner 63 -> HK21 -> Death Machine
//   SLASHER     Combat Knife -> katana (port pending) -> STORMBREAKER (Leviathan)
// `enabled`: emitted or not (ONE GUN PER BUILD). The four shipped guns are on.
// `forms`: [base, pap] source assets + the variant NAME builder (asset ids may
//   carry a trailing _zm the engine strips — the knife/enfield-PaP/leviathan
//   do; the suffix goes BEFORE it). `up` marks the PaP form.
// `axes`: the variant letters, outermost first (the GSC registers the same).
// `tune`: per-gun base overrides on top of the parity pass.
// `csv`: the weapon-table row (cost / VO / class; melee rows differ).
// =============================================================================
const T9 = (f) => path.join(TOOLS, 'source_data', f);

const LADDER = {
  skirmisher: [
    {
      tier: 1, stem: 't9_mac10', enabled: true,    // Phase 2a (2026-08-22)
      src: T9('skye_t9_mac-10.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't9_mac10', name: s => 't9_mac10' + s, up: false },
              { srcAsset: 't9_mac10_up', name: s => 't9_mac10_up' + s, up: true }],
      // SMG CLASS UPDATE (user 2026-08-23, v9.44): "Fire rate increase is
      // mac10 only. Handling is for all smgs. Magsize we can remove from
      // class." The MAC-10 is the ONLY f-ladder gun now and gains h.
      axes: ['f', 'h'],
      tune: { recoil: RECOIL_BUMP, ads: ADS_BUMP },
      csv: { cost: 1350, vo: 'smg', cls: 'smg' },
    },
    {
      tier: 2, stem: 't9_mp5', enabled: true,
      src: T9('skye_t9_mp5.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't9_mp5', name: s => 't9_mp5' + s, up: false },
              { srcAsset: 't9_mp5_up', name: s => 't9_mp5_up' + s, up: true }],
      // v9.44: f retired here (FIRE RATE is MAC-10 only); h stays. Was the
      // 32-asset f x h matrix, now the 8-asset h ladder.
      axes: ['h'],
      tune: { recoil: RECOIL_BUMP, ads: ADS_BUMP },
      csv: { cost: 1300, vo: 'smg', cls: 'smg' },
    },
    {
      tier: 3, stem: 't6_mp7', enabled: true,    // Phase 2d (2026-08-22)
      src: T9('skye_t6_mp7.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't6_mp7', name: s => 't6_mp7' + s, up: false },
              { srcAsset: 't6_mp7_up', name: s => 't6_mp7_up' + s, up: true }],
      // v9.44: m retired (MAG SIZE is off the skirmisher class — assault only
      // now); h replaces it (HANDLING is every SMG). 8 assets either way, so
      // the skirmisher ladder stays 32 + 8 + 8 = 48 and the ledger is unchanged.
      axes: ['h'],
      // PENETRATION small -> MEDIUM (user 2026-08-24). The MP7 is the TIER 3
      // skirmisher gun and its port shipped "small", while the MAC-10 (T1) and
      // MP5 (T2) both ship "medium" — so the class's final promotion was a
      // permanent penetration DOWNGRADE with no way back (PENETRATION is not a
      // skirmisher domain, so no upgrade can recover it). Medium puts the top
      // of the ladder level with the two rungs below it.
      tune: { recoil: RECOIL_BUMP, ads: ADS_BUMP, str: { penetrateType: 'medium' } },
      csv: { cost: 1300, vo: 'smg', cls: 'smg' },
    },
    {
      // THE BULLDOG — the skirmisher's SECONDARY, not a ladder rung (hence
      // `secondary: true`, which skips it in computeTierOverrides so it can
      // neither become the T1 the SMGs normalize from nor be normalized itself).
      //
      // WHY IT IS GENERATED AT ALL (user 2026-08-23: "Why cant we increase
      // bulldog clip. Isnt this what we alwyads do? Same provess for twins?" —
      // and they were right, I was wrong to say it could not be done). The stock
      // s1_bulldog asset cannot be edited, but its GDT sits in the SAME mod-tools
      // source_data this generator already reads every Skye port from, so it
      // clones exactly like a twin. `axes: []` gives one base-tuned "_b" form,
      // the Death Machine's shape.
      //
      // CLIP DOUBLED, base AND PaP, per the ask: source is 6 / 9, emitted 12 /
      // 18. maxAmmo/startAmmo are counted in MAGAZINES, so doubling the clip
      // already doubles total carried rounds (96 -> 192 at the stock 16 mags)
      // WITHOUT touching the reserve keys — which is why this deliberately takes
      // only the global x1.3 reserve and NOT the skirmisher class x1.3 on top.
      // Stacking both would have put it near 324 rounds on an emergency shotgun.
      // Say the word if you want the class multiplier on it too.
      tier: 9, stem: 's1_bulldog', enabled: true, secondary: true, secTier: 1, reserveMult: 0.5,
      src: T9('skye_s1_bulldog.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 's1_bulldog',    name: s => 's1_bulldog' + s,    up: false },
              { srcAsset: 's1_bulldog_up', name: s => 's1_bulldog_up' + s, up: true }],
      axes: [],
      // PaP DAMAGE IS PINNED TO STOCK'S 240, and that is not cosmetic. The
      // generator derives every PaP form as tuned-base x PAP_UP (1.25), which is
      // correct for a ladder gun — but the AW Bulldog's stock PaP is a 2x jump
      // (120 -> 240), so the uniform 1.25 would have emitted 150 and quietly
      // shipped a PACK-A-PUNCHED BULLDOG WEAKER THAN THE STOCK ONE, right after
      // the user asked for it to be stronger. Caught by reading the emitted GDT
      // rather than trusting the regen log.
      tune: { set: { clipSize: 12 }, setUp: { clipSize: 18, damage: 240 } },
      csv: { cost: 500, vo: 'shotgun', cls: 'shotgun' },
    },
    {
      // SG12 (BO4) — skirmisher secondary T2. Port ships damage 270 / clip 10 /
      // fireTime 0.128; damage is REPLACED by the secondary-ladder normalization
      // (see computeSecondaryOverrides), so the port number is a starting point,
      // not the shipped one.
      tier: 9, stem: 't8_sg12', enabled: true, secondary: true, secTier: 2, reserveMult: 1.2,
      src: T9('skye_t8_sg12.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't8_sg12',    name: s => 't8_sg12' + s,    up: false },
              { srcAsset: 't8_sg12_up', name: s => 't8_sg12_up' + s, up: true }],
      axes: [],
      tune: {},
      csv: { cost: 500, vo: 'shotgun', cls: 'shotgun' },
    },
    {
      // SPAS-12 (BO2) — skirmisher secondary T3. NOTE the asset is `t6_spas12`
      // while its GDT file is `skye_t6_spas-12.gdt` (hyphen in the filename, none
      // in the asset). Getting that pair wrong is the MAC-10 trap from
      // gen_tod_sounds: the lookup silently misses instead of throwing.
      tier: 9, stem: 't6_spas12', enabled: true, secondary: true, secTier: 3, reserveMult: 1.4,
      src: T9('skye_t6_spas-12.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't6_spas12',    name: s => 't6_spas12' + s,    up: false },
              { srcAsset: 't6_spas12_up', name: s => 't6_spas12_up' + s, up: true }],
      axes: [],
      tune: {},
      csv: { cost: 500, vo: 'shotgun', cls: 'shotgun' },
    },
  ],
  assault: [
    {
      // THE MAGNUM — the assault SECONDARY, generated for ONE reason: its
      // HIT-LOCATION TABLE was the only one in the map that was not 1x body /
      // 3x head (user 2026-08-24: "THE PACK-A-PUNCHED MAGNUM HAS A 6.0 TORSO
      // MULTIPLIER AND AN 8.0 HELMET MULTIPLIER ... Fix this to match other
      // secondary multipliers"). Measured across all 172 emitted assets the
      // roster is uniformly torso/limb 1 and head/helmet/neck 3; the Magnum
      // port shipped 4.0 torso / 2.0 limb / 5.0 head on the base form and
      // 6.0 / 4.0 / 7.0 with a stray 8.0 HELMET on the PaP form. Effect at the
      // muzzle: a PaP body shot was 750 x 6 = 4,500 against the AMP63's 135 and
      // the PaP Bulldog's 300 — the strongest weapon in the map was a sidearm.
      //
      // DAMAGE IS COMPENSATED SO THE HEADSHOT NUMBER DOES NOT MOVE. Folding the
      // old head multiplier into `damage` (250 x 5 / 3 = 417, 750 x 7 / 3 =
      // 1750) leaves head damage at 1,251 and 5,250 — where it is today — while
      // body drops 1,000 -> 417 and 4,500 -> 1,750. So the gun's CEILING is
      // untouched and only the spray-the-torso case is nerfed, which is what
      // being the one weapon with a 6x torso multiplier was buying.
      //
      // WHY GENERATED AND NOT EDITED IN PLACE: skye_t9_magnum.gdt lives in the
      // shared mod-tools source_data. Map 1 has zero references to it (checked),
      // so an install-side edit would have been safe on that axis — but it is
      // still outside the repo, where a Mod Tools verify reverts it silently.
      // Cloning is the same move the Bulldog made in v10.8 and it is repo-owned.
      //
      // papKeepSource: the PaP form keeps every stat the port shipped. This gun
      // is NOT on the ladder and was not asked to be retuned — without the flag
      // the uniform PaP rule would have re-derived its damage (750 -> 312), clip
      // (12 -> 8), reserve (23 -> 16), reload, ADS and recoil off the base form.
      // Everything the PaP form should change is pinned in setUp, and nothing
      // else moves. The loc values are repeated there for the same reason: with
      // papApply bypassed there is nothing to copy them from.
      tier: 9, stem: 't9_magnum', enabled: true, secondary: true, secTier: 1, reserveMult: 0.75, papKeepSource: true,
      src: T9('skye_t9_magnum.gdt'), gdf: 'bulletweapon.gdf', encoding: 'latin1',
      forms: [{ srcAsset: 't9_magnum',    name: s => 't9_magnum' + s,    up: false },
              { srcAsset: 't9_magnum_up', name: s => 't9_magnum_up' + s, up: true }],
      axes: [],
      tune: {
        set:   Object.assign({ damage: 417,  minDamage: 367  }, LOC_FLAT),
        setUp: Object.assign({ damage: 1750, minDamage: 1447 }, LOC_FLAT, LOC_NORM),
      },
      csv: { cost: 500, vo: 'pistol', cls: 'pistol' },
    },
    {
      // MOG 12 (BO4) — assault secondary T2. Asset `t8_mog12`, GDT file
      // `skye_t8_mog_12.gdt` — underscore in the filename, none in the asset.
      tier: 9, stem: 't8_mog12', enabled: true, secondary: true, secTier: 2, reserveMult: 1.2,
      src: T9('skye_t8_mog_12.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't8_mog12',    name: s => 't8_mog12' + s,    up: false },
              { srcAsset: 't8_mog12_up', name: s => 't8_mog12_up' + s, up: true }],
      axes: [],
      tune: {},
      csv: { cost: 500, vo: 'shotgun', cls: 'shotgun' },
    },
    {
      // EXECUTIONER (BO2) — assault secondary T3, and the one gun on this list
      // that is NOT a clean base/_up pair. Its PaP form is DUAL WIELD: the port
      // declares `t6_executioner_rdw_up_zm` (bulletweapon, the right hand, which
      // is the one the player fires) and `t6_executioner_ldw_up_zm`
      // (dualwieldweapon, the left). Only the RIGHT half is twinned here — the
      // left half is referenced BY it and is zoned as the STOCK asset in
      // zm_tower_of_doom.zone, exactly the shape the AMP63 already ships in.
      // That is why this gun costs 3 registrations and every other one costs 2.
      tier: 9, stem: 't6_executioner', enabled: true, secondary: true, secTier: 3, reserveMult: 1.4,
      src: T9('skye_t6_executioner.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      // BOTH PaP HALVES ARE TWINNED, and that is what keeps this gun off the
      // install-side dependency list. The engine APPENDS _zm to a DualWieldWeapon
      // reference itself, so the field must hold the RUNTIME name — the port ships
      // "t6_executioner_ldw_up_zm", which the engine turns into
      // 't6_executioner_ldw_up_zm_zm' and aborts the map load with
      // "Com_ERROR: could not find alt dualwield". That is the exact failure the
      // AMP63 hit twice on 2026-08-23, and it was fixed there by editing
      // skye_t9_amp63.gdt INSIDE THE MOD TOOLS — outside the repo, where a Mod
      // Tools "verify" silently reverts it and the map stops loading again.
      // Generating both halves lets form.str write the corrected cross-reference
      // into our own emitted blocks instead, so nothing outside this repo has to
      // stay edited. Cost is 3 registrations rather than 2.
      // BOTH PaP HALVES KEEP A TRAILING _zm ON THE ASSET NAME, and the
      // DualWieldWeapon fields must NOT have it. That asymmetry is the whole
      // contract and getting it backwards is what stopped the map loading on
      // 2026-08-24 (first build of this gun):
      //   asset / zone line      t6_executioner_rdw_up_b_zm   KEEPS _zm
      //   DualWieldWeapon field  t6_executioner_ldw_up_b      NO _zm
      //   CSV upgrade_name       t6_executioner_rdw_up_b      NO _zm
      // The engine APPENDS _zm to a DualWieldWeapon reference itself, so the
      // field holds the RUNTIME name and the asset it resolves to is that plus
      // _zm. Name the halves without _zm — which looks tidier and is what the
      // first version did — and the engine goes looking for
      // 't6_executioner_ldw_up_b_zm', finds nothing, and aborts with
      // "Com_ERROR: could not find alt dualwield". Exactly the AMP63's failure
      // on 2026-08-23, reached from the opposite direction: that gun had the
      // suffix in the FIELD, this one was missing it on the ASSET.
      // The CSV needs no special-casing — the emitter already strips a trailing
      // _zm to build the script name (see scriptName in the csvRows loop), the
      // same way it does for the blades and the Enfield's PaP.
      forms: [{ srcAsset: 't6_executioner',           name: s => 't6_executioner' + s,        up: false },
              { srcAsset: 't6_executioner_rdw_up_zm', name: s => 't6_executioner_rdw_up' + s + '_zm', up: true,
                str: s => ({ DualWieldWeapon: 't6_executioner_ldw_up' + s }) },
              { srcAsset: 't6_executioner_ldw_up_zm', name: s => 't6_executioner_ldw_up' + s + '_zm', up: true,
                gdf: 'dualwieldweapon.gdf',
                str: s => ({ DualWieldWeapon: 't6_executioner_rdw_up' + s }) }],
      axes: [],
      tune: {},
      csv: { cost: 500, vo: 'pistol', cls: 'pistol' },
    },
    {
      tier: 1, stem: 't5_enfield', enabled: true,    // Phase 2b (2026-08-22)
      src: T9('skye_t5_enfield.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      // the PaP asset is `t5_enfield_up_zm` (runtime `t5_enfield_up`); its
      // altWeapon "t5_enfield_shotty_zm" (a Masterkey) is BLANKED: the
      // map-1 boot trap class + the roster parity rule (user 2026-08-22).
      forms: [{ srcAsset: 't5_enfield', name: s => 't5_enfield' + s, up: false },
              { srcAsset: 't5_enfield_up_zm', name: s => 't5_enfield_up' + s + '_zm', up: true }],
      // ASSAULT AXIS PARITY (user 2026-08-23): every assault gun carries r + m.
      axes: ['r', 'm'],
      tune: { recoil: RECOIL_BUMP, ads: ADS_BUMP, str: { altWeapon: '' } },
      csv: { cost: 1250, vo: 'rifle', cls: 'rifle' },
    },
    {
      tier: 2, stem: 't9_krig6', enabled: true,
      src: T9('skye_t9_krig_6.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't9_krig6', name: s => 't9_krig6' + s, up: false },
              { srcAsset: 't9_krig6_up', name: s => 't9_krig6_up' + s, up: true }],
      axes: ['r', 'm'],
      tune: { recoil: RECOIL_BUMP * KRIG_RECOIL_BUMP, ads: ADS_BUMP, fire: KRIG_FIRE_SCALE,
              set: (KRIG_CLIP !== undefined ? { clipSize: KRIG_CLIP } : {}) },
      csv: { cost: 1500, vo: 'rifle', cls: 'rifle' },
    },
    {
      // MAP 1 PATCHED skye_t9_ak-47.gdt IN PLACE (its box-gun recoil overhaul:
      // kick x1.75, maxAmmo 8->10/11, moveSpeedScale 0.93). Read the `.acc-orig`
      // backup instead — it carries the same hipSpread scheme as the other live
      // t9 GDTs the roster is built from, but none of the AK-only patches, so
      // the roster recoil bump is not stacked on a hidden x1.75.
      tier: 3, stem: 't9_ak47', enabled: true,    // Phase 2e (2026-08-22)
      src: T9('skye_t9_ak-47.gdt.acc-orig'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't9_ak47', name: s => 't9_ak47' + s, up: false },
              { srcAsset: 't9_ak47_up', name: s => 't9_ak47_up' + s, up: true }],
      // ASSAULT AXIS PARITY (user 2026-08-23): r + m like the Enfield and Krig.
      // The p-ladder had to GO — axes multiply, and p x r x m is 3 x 4 x 4 = 48
      // combos x 2 forms = 96 registrations for this gun alone (the whole map
      // is 194). PENETRATION is heavy-only again; _tod_upgrades::set_guns
      // matches. The AK is not weaker for it: every source GDT ships
      // penetrateType "medium" and the ladder STARTED at "small".
      axes: ['r', 'm'],
      tune: { recoil: RECOIL_BUMP, ads: ADS_BUMP },
      csv: { cost: 1500, vo: 'rifle', cls: 'rifle' },
    },
  ],
  heavy: [
    {
      // RPG (BO2) — heavy secondary T2, and the only PROJECTILE weapon on the
      // secondary ladder. Read this before retuning it.
      // 
      // THE DIRECT HIT IS NORMALIZED, THE SPLASH IS NOT. `damage` (port 7000)
      // goes through computeSecondaryOverrides like every other T2, so the rocket
      // cannot out-DPS the primary it is supposed to sit under. Its
      // explosionInnerDamage/OuterDamage take only the flat -25% secondary nerf
      // and keep their shape, so the gun still kills a crowd with the blast —
      // which is the whole reason to carry a launcher. DPS is capped; the
      // FANTASY is not. If you want the port's full 7000 direct hit back, this
      // is the gun to give a `secNoNormalize: true` and a case in
      // computeSecondaryOverrides; it is deliberately not wired up, because one
      // exempt gun quietly becomes three.
      // 
      // AMMO IS THE REAL LIMITER and it is untouched: clipSize 1, 20 rockets
      // total. explosionRadius 250 is also untouched — the user was shown the
      // self-damage risk on a narrow spiral staircase and said to proceed
      // (2026-08-24), so this is a known, accepted sharp edge, not an oversight.
      tier: 9, stem: 't6_rpg', enabled: true, secondary: true, secTier: 2, reserveMult: 1.2,
      src: T9('skye_t6_rpg.gdt'), gdf: 'projectileweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't6_rpg',    name: s => 't6_rpg' + s,    up: false },
              { srcAsset: 't6_rpg_up', name: s => 't6_rpg_up' + s, up: true }],
      axes: [],
      tune: {},
      csv: { cost: 500, vo: 'lmg', cls: 'lmg' },
    },
    {
      // NAIL GUN (BOCW) — heavy secondary T3. Typed `projectileweapon` but every
      // explosion value is 0, so it is a bullet gun that fires nails and it
      // normalizes like any other. damage 250 / clip 40 / fireTime 0.157.
      // ITS WAV DIRECTORY IS `t9_nailgun`, NOT `t9_nail_gun` — see GDT_OF in
      // tools/gen_tod_sounds.js. Same class of trap as the MAC-10's hyphen.
      tier: 9, stem: 't9_nail_gun', enabled: true, secondary: true, secTier: 3, reserveMult: 1.4,
      src: T9('skye_t9_nail_gun.gdt'), gdf: 'projectileweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't9_nail_gun',    name: s => 't9_nail_gun' + s,    up: false },
              { srcAsset: 't9_nail_gun_up', name: s => 't9_nail_gun_up' + s, up: true }],
      axes: [],
      tune: {},
      csv: { cost: 500, vo: 'lmg', cls: 'lmg' },
    },
    {
      tier: 1, stem: 't9_stoner63', enabled: true,
      src: T9('skye_t9_stoner_63.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't9_stoner63', name: s => 't9_stoner63' + s, up: false },
              { srcAsset: 't9_stoner63_up', name: s => 't9_stoner63_up' + s, up: true }],
      axes: ['p'],
      tune: { recoil: RECOIL_BUMP, ads: ADS_BUMP, set: { clipSize: STONER_CLIP } },
      csv: { cost: 1500, vo: 'lmg', cls: 'lmg' },
    },
    {
      tier: 2, stem: 't5_hk21', enabled: true,    // Phase 2c (2026-08-22)
      src: T9('skye_t5_hk21.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't5_hk21', name: s => 't5_hk21' + s, up: false },
              { srcAsset: 't5_hk21_up', name: s => 't5_hk21_up' + s, up: true }],
      // PENETRATION MOVED OFF THIS GUN to the Death Machine (user 2026-08-24:
      // "remove penetration from HK21 and add to the death machine"). Axis-less
      // now -> one "_b" form. Ledger-neutral: the p-ladder's 3 levels x 2 forms
      // = 6 registrations simply move from this stem to t6_death_machine.
      // _tod_classes::register_gun and _tod_upgrades::set_guns( "penetration" )
      // were changed in the same pass — all three have to agree or the variant
      // suffix the script asks GetWeapon for stops existing.
      axes: [],
      // CLIP -25% (user 2026-08-24: "HK needs a clip and reserve nerf by 25%",
      // then "clip only" when asked which reading was meant). This gun was the
      // ammo king of the map by a wide margin: a 125-round belt over 6 magazines,
      // 875 rounds carried.
      //
      // WHY ONE KNOB DELIVERS BOTH HALVES OF THE ASK: maxAmmo/startAmmo are
      // counted in MAGAZINES, not rounds, so shrinking the clip shrinks the
      // reserve by the same 25% without touching them — 125/750 -> 94/564, and
      // BOTH numbers on the HUD fall exactly 25%. Scaling the mag count as well
      // would have compounded to -46% of carried rounds, which is not what was
      // asked for. (gun.reserveMult exists in baseTune for the day a gun really
      // does need its magazine COUNT cut; nothing sets it today.)
      //
      // clipMult is applied AFTER the never-shrink floor in computeTierOverrides,
      // so it is a real cut rather than one the floor silently undoes.
      clipMult: 0.75,
      // PENETRATION large -> MEDIUM (user 2026-08-24). Losing the p-ladder left
      // this gun frozen at its port's "large", which made the promotion to the
      // Death Machine (p0 = "small") a TWO-level penetration downgrade — the
      // player had to spend two upgrades to get back what tier 2 gave free. At
      // medium the promotion still starts a step down, but one level recovers it.
      tune: { recoil: RECOIL_BUMP, ads: ADS_BUMP, str: { penetrateType: 'medium' } },
      csv: { cost: 2750, vo: 'lmg', cls: 'lmg' },
    },
    {
      tier: 3, stem: 't6_death_machine', enabled: true,    // Phase 2f (2026-08-22)
      src: T9('skye_t6_death_machine.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't6_death_machine', name: s => 't6_death_machine' + s, up: false },
              { srcAsset: 't6_death_machine_up', name: s => 't6_death_machine_up' + s, up: true }],
      // PENETRATION LIVES HERE NOW (user 2026-08-24), taken off the HK21. The
      // spin-up used to be "the gun" and this rung carried no ladder at all;
      // with the p-axis it emits 3 forms x 2 = 6 registrations, exactly the 6
      // the HK21 gave up, so the ledger does not move.
      axes: ['p'],
      tune: { recoil: RECOIL_BUMP, ads: ADS_BUMP },
      csv: { cost: 5000, vo: 'lmg', cls: 'lmg' },
    },
  ],
  slasher: [
    {
      // UDM (Infinite Warfare) — slasher secondary T2.
      //
      // REPLACED THE VG KLAUSER (user 2026-08-25: "Replace the klauser with the
      // IW UDM"). The Klauser was the map's only gun with BROKEN ART: its port
      // declares mtl_malpha96_trigger_00 and mtl_optic_nydar_00 against
      // roughness images (i_malpha96_trigger_00_r, i_optic_nydar_00_r) that ship
      // nowhere in the tools tree, plus mtl_grip_fabric_00 and
      // mtl_pi_gen_optic_attach_00 which are declared in no GDT at all. Four
      // unresolvable material slots = white patches on a published usermap, and
      // they were the ONLY 6 unexpected linker errors this map had.
      //
      // The UDM is a clean port by comparison: a plain base/_up bulletweapon
      // pair, blank altWeapon, shotCount 1, and — unlike six of the eight
      // secondaries — it ships its OWN first_raise wav, so it needs no borrowed
      // draw sound. Ledger-neutral: 2 registrations in, 2 out.
      // CREDIT the port author (Skye_IW_UDM README: "add the people on my modme
      // post") before publish; see CREDITS.md.
      tier: 9, stem: 'iw7_udm', enabled: true, secondary: true, secTier: 2, reserveMult: 1.2,
      src: T9('skye_iw7_udm.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 'iw7_udm',    name: s => 'iw7_udm' + s,    up: false },
              { srcAsset: 'iw7_udm_up', name: s => 'iw7_udm_up' + s, up: true }],
      axes: [],
      tune: {},
      csv: { cost: 500, vo: 'pistol', cls: 'pistol' },
    },
    {
      // RK7 GARRISON (BO4) — slasher secondary T3. The ASSET is `t8_rk7`; only
      // the GDT FILE carries the `_garrison`. A fast auto pistol (fireTime
      // 0.066), which is why the slasher line ends here: the class that has to
      // close distance gets the sidearm that covers the walk.
      tier: 9, stem: 't8_rk7', enabled: true, secondary: true, secTier: 3, reserveMult: 1.4,
      src: T9('skye_t8_rk7_garrison.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't8_rk7',    name: s => 't8_rk7' + s,    up: false },
              { srcAsset: 't8_rk7_up', name: s => 't8_rk7_up' + s, up: true }],
      axes: [],
      tune: {},
      csv: { cost: 500, vo: 'pistol', cls: 'pistol' },
    },
    {
      // The BOCW combat knife (vendored to repo source_data 2026-08-20;
      // ASCII/CRLF; bulletweapon.gdf, pure melee). Asset ids carry _zm.
      tier: 1, stem: 't9_me_knife_american', enabled: true, melee: true,
      src: path.join(REPO, 'source_data', 't9_weapons', 'melee', 'wpn_t9_me_knife_combat.gdt'),
      gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't9_me_knife_american_zm',    name: s => 't9_me_knife_american' + s + '_zm', up: false },
              { srcAsset: 't9_me_knife_american_up_zm', name: s => 't9_me_knife_american_up' + s + '_zm', up: true }],
      axes: ['k'],
      tune: { ads: ADS_BUMP },   // the knife takes the ADS bump too ("that is for all guns")
      csv: { cost: 3000, vo: 'wpck_bowie', cls: 'special', melee: true },
    },
    {
      // KATANA = pmr360's BOCW Wakizashi ("Yamikirimaru" PaP), vendored to repo
      // source_data 2026-08-22 like the combat knife; same _zm naming, same
      // melee GDF, meleeTime/meleeChargeTime present (k-ladder OK), altWeapon "".
      tier: 2, stem: 't9_me_wakizashi', enabled: true, melee: true,    // Phase 2h (2026-08-22)
      src: path.join(REPO, 'source_data', 't9_weapons', 'melee', 'wpn_t9_me_wakizashi.gdt'),
      gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't9_me_wakizashi_zm',    name: s => 't9_me_wakizashi' + s + '_zm', up: false },
              { srcAsset: 't9_me_wakizashi_up_zm', name: s => 't9_me_wakizashi_up' + s + '_zm', up: true }],
      axes: ['k'],
      tune: { ads: ADS_BUMP },
      csv: { cost: 3000, vo: 'wpck_bowie', cls: 'special', melee: true },
    },
    {
      // STORMBREAKER = the Leviathan Axe port (wetegg), asset ids carry _zm.
      // The GDT lives in <tools>\_custom and links ONLY because
      // bin\converter_gdt_dirs_0.txt line 1 is `_custom` (a Mod Tools verify
      // resets that file — the axe would silently drop). Do NOT vendor a copy
      // (two definitions = gdtdb duplicate). The LIVE file is map-1-patched
      // (continuousFire 1 paired with its _acc_leviathan_swing.gsc, move 1.07,
      // meleeChargeRange 0); the pristine pack copy is the source here.
      tier: 3, stem: 'leviathan', enabled: true, melee: true,    // Phase 2g (2026-08-22) — STORMBREAKER
      src: path.join(TOOLS, '_custom', 'wetegg', 'leviathanaxe', 'leviathanaxe.gdt.acc-balance0709-orig'),
      gdf: 'bulletweapon.gdf', encoding: 'latin1',
      forms: [{ srcAsset: 'leviathan_zm',    name: s => 'leviathan' + s + '_zm', up: false },
              { srcAsset: 'leviathan_up_zm', name: s => 'leviathan_up' + s + '_zm', up: true }],
      axes: ['k'],
      // HUD NAME (user 2026-08-23: "change the name of the leviathan axes to
      // stormbreaker ... Both base and pap version"). The port ships as
      // "Leviathan Axe" / "Colossal Headtaker", which is what the weapon HUD was
      // printing while every menu we author already called it the STORMBREAKER.
      // Fixed HERE rather than in the .gdt because the .gdt is generated — a
      // hand-edit there dies at the next regen.
      tune: { ads: ADS_BUMP, name: 'Stormbreaker', nameUp: 'Stormbreaker EX' },
      csv: { cost: 3000, vo: 'wpck_bowie', cls: 'special', melee: true },
    },
  ],
};

// Emission ORDER = the order the shipped v1 table used (mp5, krig, stoner,
// knife) so a no-ladder-change regen diffs clean; new guns append after.
const EMIT_ORDER = ['t9_mp5', 't9_krig6', 't9_stoner63', 't9_me_knife_american'];

// ---- machinery (ported) ----------------------------------------------------
function fmt(n) {
  if (Number.isInteger(n)) return String(n);
  return parseFloat(n.toFixed(4)).toString();
}

// String-valued setter (absSet only matches numeric fields; penetrateType /
// altWeapon are strings).
function strSet(line, map) {
  const m = line.match(/^(\s*)"([A-Za-z0-9_]+)"\s+"([^"]*)"\s*$/);
  if (!m) return line;
  const [, indent, key] = m;
  if (!(key in map)) return line;
  return `${indent}"${key}" "${map[key]}"`;
}

function absSet(line, map) {
  const m = line.match(/^(\s*)"([A-Za-z0-9_]+)"\s+"(-?\d+(?:\.\d+)?)"\s*$/);
  if (!m) return line;
  const [, indent, key] = m;
  if (!(key in map)) return line;
  return `${indent}"${key}" "${fmt(map[key])}"`;
}

function scaleSets(line, sets) {
  const m = line.match(/^(\s*)"([A-Za-z0-9_]+)"\s+"(-?\d+(?:\.\d+)?)"\s*$/);
  if (!m) return line;
  const [, indent, key, valStr] = m;
  for (const [keys, factor] of sets) {
    if (factor !== 1 && keys.has(key)) {
      const v = parseFloat(valStr);
      if (v === 0) return line;   // 0 stays 0
      // INT_KEYS (clip/ammo/damage): the engine wants whole rounds — round, never truncate
      const scaled = INT_KEYS.has(key) ? Math.round(v * factor) : v * factor;
      return `${indent}"${key}" "${fmt(scaled)}"`;
    }
  }
  return line;
}

function extractBlock(text, asset, gdf) {
  const decl = `"${asset}" ( "${gdf}" )`;
  const start = text.indexOf(decl);
  if (start === -1) throw new Error(`asset ${asset} (${gdf}) not found`);
  let i = text.indexOf('{', start);
  let depth = 0, end = -1;
  for (let j = i; j < text.length; j++) {
    const c = text[j];
    if (c === '{') depth++;
    else if (c === '}') { depth--; if (depth === 0) { end = j; break; } }
  }
  if (end === -1) throw new Error('unbalanced braces');
  const lineStart = text.lastIndexOf('\n', start) + 1;
  return text.slice(lineStart, end + 1);
}

function makeVariant(block, asset, newName, gdf, scaleFn) {
  let scaled = 0;
  const out = block.split(/\r?\n/).map(line => {
    if (line.includes(`"${asset}" ( "${gdf}" )`))
      return line.replace(`"${asset}"`, `"${newName}"`);
    const r = scaleFn(line);
    if (r !== line) scaled++;
    return r;
  });
  return { text: out.join('\n'), scaled };
}

// numeric field reader on a (possibly tuned) block
function readNum(block, key) {
  const m = block.match(new RegExp(`^\\s*"${key}"\\s+"(-?\\d+(?:\\.\\d+)?)"\\s*$`, 'm'));
  return m ? parseFloat(m[1]) : undefined;
}

// DISPLAY NAME override — the string the in-game HUD shows for the weapon.
// PER FORM, which is why it cannot ride tune.str (that map applies to base and
// PaP alike): a gun’s PaP form wants its own name. Both names come from the
// port’s source GDT unless a gun sets tune.name / tune.nameUp.
function nameSet(gun, line, isUp) {
  if (!gun.tune || !gun.tune.name) return line;
  return strSet(line, { displayName: isUp ? (gun.tune.nameUp || gun.tune.name) : gun.tune.name });
}

// ---- the base tune -----------------------------------------------------------
// Every variant of a gun passes through this BEFORE its ladder scaling. The
// base form gets the hand tune (parity pass + per-gun overrides + the tier
// overrides computed below); the PaP form gets papApply() — every tuned stat
// overwritten with the TUNED-BASE value made 25% better — then the melee tier
// damage (exempt from the uniform rule) set explicitly.
function baseTune(gun, line, isUp) {
  if (isUp) {
    // `papKeepSource` OPTS A GUN OUT OF THE UNIFORM PaP DERIVATION entirely, so
    // its _up form keeps every value the port shipped and only tune.setUp moves.
    // Needed by the Magnum: it is generated for ONE reason (its hit-location
    // table), and papApply would otherwise re-derive ~40 of its stats from the
    // base x the PaP factors — quietly rewriting its damage, clip, reserve,
    // reload, ADS and recoil on a gun nobody asked to retune.
    let l = gun.papKeepSource ? line : papApply(gun.stem, line);
    if (gun.melee && gun.override && gun.override.meleeDamageUp !== undefined)
      l = absSet(l, { meleeDamage: gun.override.meleeDamageUp,
                      meleeFromBehindDamage: gun.override.meleeBehindUp });
    // string overrides apply to EVERY form — the Enfield's PaP form is the one
    // carrying the Masterkey altWeapon (caught 2026-08-22: the first 2b build
    // left it on the _up variants = the boot-trap class, never shipped)
    // ABSOLUTE PaP-SIDE VALUES (v10.8). The PaP form is otherwise derived
    // entirely from the SOURCE _up block times PAP_UP, so there was no way to
    // pin a number on it — fine for a ladder gun, wrong for the Bulldog, whose
    // PaP clip the user specified directly ("clip size can double for base and
    // pap bulldog"). Applied AFTER papApply so it wins over the x1.25.
    if (gun.tune.setUp) l = absSet(l, gun.tune.setUp);
    // SPLASH ONLY — and the asymmetry with `damage` is the whole point.
    //
    // BUG THIS FIXES (shipped 2026-08-24, caught the same day): this used to
    // scale DAMAGE_KEYS here too, which double-applied the secondary nerf to
    // every PaP form that derives its damage through papApply. papApply reads
    // the TUNED BASE — which already carries the nerf, or an override.damage
    // that embeds it — and multiplies by PAP_UP. Scaling again here made the
    // PaP form 1.25 x 0.75 = 0.9375 of the base, i.e. EVERY Pack-a-Punched
    // secondary was WEAKER THAN ITS OWN BASE FORM: the RPG went 563 -> 528, the
    // Nail Gun 460 -> 431, the SG12 138 -> 130, the Klauser 165 -> 155.
    //
    // It was correct when it was written and the only secondaries were the
    // Bulldog and the Magnum, because BOTH pin their PaP damage as a literal
    // and so bypass papApply entirely. Adding eight secondaries that do not pin
    // turned a targeted fix into a roster-wide bug. Those two guns now get
    // their pin DERIVED from the final base damage in computeSecondaryOverrides
    // instead, so PaP = base x PAP_UP for every secondary by one rule.
    //
    // EXPLOSION KEYS STILL BELONG HERE. They are in no papFactor set, so
    // papApply never touches them and the _up form would otherwise keep the raw
    // PORT splash — the RPG's 2500/1000 rather than the nerfed 1875/750. Here
    // the scaling applies exactly once, which is what it did before and still
    // does. (Note this also means PaP grants no splash increase; that follows
    // the existing PAP_UP_KEYS design and is not changed here.)
    if (gun.secondary && SECONDARY_DMG_MULT !== 1)
      l = scaleSets(l, [[EXPLOSION_KEYS, SECONDARY_DMG_MULT]]);

    // RESERVE ON A papKeepSource GUN — the Magnum, and only the Magnum today.
    //
    // papKeepSource bypasses papApply entirely, so the _up form keeps the PORT's
    // own maxAmmo instead of inheriting the tuned base's. That means a per-gun
    // reserveMult lands on the base and NOT on the PaP form: the 2026-08-25 "cut
    // the Magnum by 25%" pass moved base 96 -> 72 and left PaP sitting at 276.
    //
    // Only gun.reserveMult is applied here, deliberately — NOT the global
    // RESERVE_MULT or the class knob. Those have never reached a papKeepSource
    // _up form (which is why the Magnum's PaP reserve is 23 raw magazines against
    // a 12-magazine base), and folding them in now would be a silent balance
    // change to a gun nobody asked to retune beyond the 25%.
    if (gun.papKeepSource && gun.reserveMult && gun.reserveMult !== 1)
      l = scaleSets(l, [[RESERVE_KEYS, gun.reserveMult]]);
    if (gun.tune.str) l = strSet(l, gun.tune.str);
    // v10.23: was `if (gun.melee)`, which left meleeChargeRange 120 on all 136
    // non-melee emitted assets — every bullet weapon still LUNGED on a gun bash,
    // despite the roster-wide "remove the lunge swing" pass. That pass only ever
    // reached the blades. meleeLungeRange is already 0 on the ports; this zeroes
    // the charge lunge too. The bash itself is unaffected — it still connects at
    // meleeRange, exactly as it does on the blades, which have run at 0 since
    // that pass shipped.
    l = strSet(l, MELEE_NO_LUNGE);
    l = nameSet(gun, l, true);
    return l;
  }
  const set = Object.assign({ moveSpeedScale: 1 }, LOC_NORM, gun.tune.set || {});
  if (gun.override) {
    for (const k of ['damage', 'minDamage', 'damageMin', 'clipSize'])
      if (gun.override[k] !== undefined) set[k] = gun.override[k];
    if (gun.melee && gun.override.meleeDamage !== undefined) {
      set.meleeDamage = gun.override.meleeDamage;
      set.meleeFromBehindDamage = gun.override.meleeBehind;
    }
  }
  let l = absSet(line, set);
  const sets = [];
  if (gun.tune.recoil) sets.push([RECOIL_KEYS, gun.tune.recoil]);
  if (gun.tune.ads) sets.push([ADS_KEYS, gun.tune.ads]);
  if (gun.tune.fire) sets.push([FIRE_KEYS, gun.tune.fire]);
  // Global +30% reserve (v9.36) TIMES the class knob (v10.8) — skirmisher ends
  // at 1.69x its GDT reserve. gun.cls is stamped in computeTierOverrides.
  // Secondaries take the GLOBAL reserve bump only — the class knobs are a
  // decision about the SMG LINE, and the Bulldog's own clip change already
  // doubles its carried rounds (see its LADDER entry).
  // gun.reserveMult is the PER-GUN knob (the HK21's -25%), folded into the SAME
  // factor as the other two on purpose: scaleSets returns on its first matching
  // set, so a second [RESERVE_KEYS, x] push would be silently ignored.
  const crm = gun.secondary ? 1 : (CLASS_RESERVE_MULT[gun.cls] || 1);
  sets.push([RESERVE_KEYS, RESERVE_MULT * crm * (gun.reserveMult || 1)]);
  // CLASS DAMAGE — T1 ONLY. `gun.override.damage` is set for T2/T3 by
  // computeTierOverrides and absSet has already written it above, so scaling
  // here would compound on top of the value that was ALREADY derived from the
  // buffed T1. Guarding on the override is what keeps the buff exactly +10%
  // across the whole ladder instead of +10% / +21% / +21%.
  const cdm = gun.secondary ? SECONDARY_DMG_MULT : (CLASS_DAMAGE_MULT[gun.cls] || 1);
  if (cdm !== 1 && !(gun.override && gun.override.damage !== undefined))
    sets.push([DAMAGE_KEYS, cdm]);
  // Splash always takes the secondary nerf, override or not — a normalized
  // `damage` says nothing about explosionInnerDamage.
  if (gun.secondary && SECONDARY_DMG_MULT !== 1)
    sets.push([EXPLOSION_KEYS, SECONDARY_DMG_MULT]);
  if (sets.length) l = scaleSets(l, sets);
  if (gun.tune.str) l = strSet(l, gun.tune.str);
  l = strSet(l, MELEE_NO_LUNGE);   // v10.23: every gun, not just melee — see the PaP path
  l = nameSet(gun, l, false);
  return l;
}

// the ladder scaling for one variant (levels = { letter: level })
function ladderScale(gun, line, levels) {
  let l = line;
  for (const letter of gun.axes) {
    const ax = AXIS[letter];
    const lv = levels[letter];
    if (ax.pen) l = strSet(l, { penetrateType: PEN_TIER[lv] });
    else l = scaleSets(l, ax.sets.map(([keys, steps]) => [keys, steps[lv]]));
  }
  return l;
}

// PaP stat sets, per stem, derived from the TUNED base block.
const PAP_SETS = {};
const PAP_EXEMPT = {};   // stem -> Set(keys) the uniform rule must not touch

function papFactor(key) {
  if (PAP_UP_KEYS.has(key)) return PAP_UP;
  if (FIRE_KEYS.has(key)) return PAP_FAST;
  if (RELOAD_KEYS.has(key) || SWAP_KEYS.has(key) || ADS_KEYS.has(key)
    || RECOIL_KEYS.has(key) || MELEE_KEYS.has(key)) return PAP_TRIM;
  if (PAP_COPY_KEYS.has(key)) return 1;
  return undefined;   // not a papped stat — the _up form keeps its own value
}

function computePapSet(stem, tunedBaseBlock) {
  const set = {};
  for (const line of tunedBaseBlock.split(/\r?\n/)) {
    const m = line.match(/^\s*"([A-Za-z0-9_]+)"\s+"(-?\d+(?:\.\d+)?)"\s*$/);
    if (!m) continue;
    const [, key, valStr] = m;
    if (PAP_EXEMPT[stem] && PAP_EXEMPT[stem].has(key)) continue;
    const f = papFactor(key);
    if (f === undefined) continue;
    const v = parseFloat(valStr);
    if (v === 0) continue;                  // 0 stays 0 (scaleSets convention)
    const scaled = v * f;
    // meleeDamage joins the INT set here — map 1's INT-typed damage trap
    set[key] = (INT_KEYS.has(key) || key === 'meleeDamage') ? Math.round(scaled) : scaled;
  }
  set.moveSpeedScale = 1;   // class_speed_base owns speed on every form
  PAP_SETS[stem] = set;
}

function papApply(stem, line) {
  const set = PAP_SETS[stem];
  if (!set) throw new Error(`papApply before computePapSet for ${stem}`);
  return absSet(line, set);
}

// cartesian enumeration of a gun's variants: [{ suffix, levels }]
function variantsOf(gun) {
  if (!gun.axes.length) return [{ suffix: '_b', levels: {} }];
  let combos = [{}];
  for (const letter of gun.axes) {
    const next = [];
    for (const c of combos)
      for (let lv = 0; lv <= AXIS[letter].levels; lv++)
        next.push(Object.assign({}, c, { [letter]: lv }));
    combos = next;
  }
  return combos.map(levels => ({
    suffix: '_' + gun.axes.map(l => l + levels[l]).join(''),
    levels,
  }));
}

// ---- tier overrides ------------------------------------------------------------
// Walk each class in tier order. With the T1 gun ENABLED, every enabled higher
// tier gets damage normalized to T1's tuned DPS x TIER_DPS and a clip no
// smaller than the tier below x CLIP_STEP. Melee guns get MELEE_TIER_DMG.
function computeTierOverrides() {
  for (const [cls, guns] of Object.entries(LADDER)) {
    // Stamp the class onto every gun BEFORE any baseTune call — the per-class
    // reserve/damage knobs read it, and computeTierOverrides calls baseTune to
    // measure the tuned T1, so the stamp has to exist by then or the T1 the
    // whole ladder is normalized from would be measured un-buffed.
    for (const g of guns) g.cls = cls;
    const sorted = guns.slice().sort((a, b) => a.tier - b.tier);
    let t1 = null;        // { damage, fireTime } of the tuned T1 base
    let prevClip = null;
    for (const gun of sorted) {
      gun.override = {};
      // SECONDARIES ARE NOT LADDER RUNGS (v10.8). The Bulldog is the
      // skirmisher's sidearm, not a tier of its ladder: it must never become
      // `t1` for normalization, never be normalized FROM t1, and never move
      // `prevClip` (the never-shrink floor belongs to the primary line only).
      // It is emitted with its own tune and nothing else.
      if (gun.secondary) continue;
      if (gun.melee) {
        gun.override.meleeDamage = MELEE_TIER_DMG[gun.tier][0];
        gun.override.meleeDamageUp = MELEE_TIER_DMG[gun.tier][1];
        gun.override.meleeBehind   = Math.round(MELEE_TIER_DMG[gun.tier][0] * BACKSTAB_MULT);
        gun.override.meleeBehindUp = Math.round(MELEE_TIER_DMG[gun.tier][1] * BACKSTAB_MULT);
        // meleeFromBehindDamage is in NO papFactor set, so the uniform PaP rule
        // never touches it and the _up form would otherwise keep the port's own
        // number — which is exactly how 20,000 and 0 survived. It is listed here
        // anyway so that adding it to PAP_UP_KEYS later cannot silently
        // double-apply on top of the explicit set below.
        PAP_EXEMPT[gun.stem] = new Set(['meleeDamage', 'meleeFromBehindDamage']);
        // MELEE PRIMARY T1 -> a DPS the secondary cap can be computed from.
        // The slasher's whole primary line is melee, so without this the class
        // has no PRIMARY_T1 entry at all and its sidearms would be uncapped.
        // Swing damage over swing time (fireTime IS the swing interval on these
        // blades, 0.6s on the level-0 knife).
        //
        // TREAT THE RESULT WITH SUSPICION when you are tuning by it. 2000/0.6 =
        // 3,333 "DPS" is real only in contact range, on one zombie, while you
        // are being hit. A RANGED sidearm at the same number is strictly
        // stronger in practice, which is why the user chose ceiling mode: the
        // slasher's sidearms are all comfortably under this cap today and this
        // number never actually binds. If a future slasher sidearm does hit it,
        // scale it down here rather than trusting the equivalence.
        if (gun.tier === 1) {
          const mtext = fs.readFileSync(gun.src, gun.encoding);
          const mraw = extractBlock(mtext, gun.forms[0].srcAsset, gun.forms[0].gdf || gun.gdf);
          const mSwing = readNum(mraw.split(/\r?\n/).map(l => baseTune(gun, l, false)).join('\n'), 'fireTime');
          if (mSwing) PRIMARY_T1[cls] = { dps: MELEE_TIER_DMG[1][0] / mSwing, melee: true };
        }
        continue;
      }
      if (!gun.enabled) { t1 = (gun.tier === 1) ? null : t1; continue; }
      const text = fs.readFileSync(gun.src, gun.encoding);
      const raw = extractBlock(text, gun.forms[0].srcAsset, gun.forms[0].gdf || gun.gdf);
      // the tuned base WITHOUT tier overrides (override is still {} here)
      const tuned = raw.split(/\r?\n/).map(l => baseTune(gun, l, false)).join('\n');
      const damage = readNum(tuned, 'damage');
      const minDamage = readNum(tuned, 'minDamage');
      const fireTime = readNum(tuned, 'fireTime');
      const clip = readNum(tuned, 'clipSize');
      if (gun.tier === 1) {
        t1 = { damage, fireTime };
        // BULLET PRIMARY T1 -> the DPS the secondary cap is computed from.
        // shotCount belongs in it for the same reason it belongs in the
        // secondary math: `damage` is PER PROJECTILE. No primary is a shotgun
        // today, so every one of these is x1 — recording it anyway is what stops
        // a future shotgun primary silently capping its class's sidearms 8x too
        // low.
        PRIMARY_T1[cls] = { dps: damage * (readNum(tuned, 'shotCount') || 1) / fireTime };
        prevClip = clip;
        continue;
      }
      if (!t1) {
        console.log(`  note: ${gun.stem} (tier ${gun.tier}) emitted UN-normalized — the ${cls} T1 gun is not enabled yet`);
        prevClip = clip;
        continue;
      }
      // DPS normalization at the gun's own fire time
      const dmg = Math.round(t1.damage * TIER_DPS[gun.tier] * fireTime / t1.fireTime);
      gun.override.damage = dmg;
      if (minDamage !== undefined && damage) gun.override.minDamage = Math.round(dmg * minDamage / damage);
      // never-shrink clip
      const floor = Math.round(prevClip * CLIP_STEP);
      gun.override.clipSize = Math.max(clip, floor);
      // PER-GUN CLIP NERF, applied AFTER the never-shrink floor. Order matters:
      // the floor exists to stop a promotion shrinking your magazine, but an
      // explicit nerf has to be able to win over it or it would be silently
      // clamped back up. prevClip below takes the NERFED value, so the next
      // tier's floor derives from what this gun actually ships with.
      if (gun.clipMult) gun.override.clipSize = Math.round(gun.override.clipSize * gun.clipMult);
      console.log(`  tier ${gun.tier} ${gun.stem}: damage ${damage} -> ${dmg} (T1 ${t1.damage}@${t1.fireTime}s x${TIER_DPS[gun.tier]} at ${fireTime}s), clip ${clip} -> ${gun.override.clipSize} (floor ${floor})`);
      prevClip = gun.override.clipSize;
    }
  }
}

// ---- the SECONDARY ladder --------------------------------------------------
// Runs AFTER computeTierOverrides and is deliberately a separate pass: the two
// ladders share nothing but their DPS steps. computeTierOverrides `continue`s on
// every `secondary` gun so a sidearm can never become the T1 a primary line
// normalizes from, and this pass ignores every non-secondary for the same
// reason in reverse.
//
// WHAT IT DOES, per class: find the T1 reference DPS, then give each T2/T3 an
// override.damage equal to ref.damage x SEC_DPS[secTier] x (its own fireTime /
// ref.fireTime) — the identical formula the primary ladder uses, so a fast gun
// and a slow gun at the same tier land on the same damage-per-second rather
// than the same damage-per-shot.
//
// THE REFERENCE COMES FROM ONE OF TWO PLACES and the difference matters when
// you are reading a number that looks wrong:
//   * a MEASURED T1 (skirmisher, assault) — its tuned block is read exactly the
//     way computeTierOverrides reads a primary T1, so it already includes the
//     -25% SECONDARY_DMG_MULT and any tune.set on the gun.
//   * a DECLARED T1 (heavy, slasher) — SEC_T1_REF, because those two T1s are raw
//     ports with no generated block to measure. See the table's comment.
// A class with neither is a hard error, not a silent pass-through: a secondary
// emitted un-normalized would ship its raw port damage, and the raw ports here
// range from 20 (Klauser) to 7000 (RPG).
//
// NO never-shrink clip floor, on purpose. That rule exists so a PRIMARY
// promotion cannot shrink the magazine you just earned. Secondaries cross
// weapon classes between tiers by design (revolver -> shotgun, pistol ->
// launcher), where a monotonic clip is meaningless: the RPG's clip of 1 is the
// gun, not a downgrade.
function computeSecondaryOverrides() {
  for (const [cls, guns] of Object.entries(LADDER)) {
    const secs = guns.filter(g => g.secondary && g.enabled)
                     .sort((a, b) => a.secTier - b.secTier);
    if (!secs.length) continue;
    let ref = SEC_T1_REF[cls];
    const t1 = secs.find(g => g.secTier === 1);
    if (t1) {
      // measured, exactly as the primary T1 is
      const text = fs.readFileSync(t1.src, t1.encoding);
      const raw = extractBlock(text, t1.forms[0].srcAsset, t1.forms[0].gdf || t1.gdf);
      const tuned = raw.split(/\r?\n/).map(l => baseTune(t1, l, false)).join('\n');
      ref = { damage: readNum(tuned, 'damage'), fireTime: readNum(tuned, 'fireTime'),
              shot: readNum(tuned, 'shotCount') || 1 };
      console.log(`  sec T1 ${cls} ${t1.stem}: measured damage ${ref.damage} x${ref.shot} @ ${ref.fireTime}s`);
    } else if (ref) {
      console.log(`  sec T1 ${cls}: DECLARED ref damage ${ref.damage} @ ${ref.fireTime}s (raw-port T1, not measurable)`);
    }
    for (const gun of secs) {
      // TIER 1 IS NO LONGER SKIPPED. It used to be, because it WAS the ladder's
      // reference and shipped its own tuned value. The cap changed that: the
      // Bulldog measured 5,538 DPS against a MAC-10 doing 2,981, so the rung the
      // whole ladder was measured from was itself the worst offender.
      if (gun.secTier !== 1 && !ref) throw new Error(`secondary tier ${gun.secTier} (${gun.stem}) has no T1 reference for class ${cls} — add a SEC_T1_REF row or enable the T1`);
      const text = fs.readFileSync(gun.src, gun.encoding);
      const raw = extractBlock(text, gun.forms[0].srcAsset, gun.forms[0].gdf || gun.gdf);
      const tuned = raw.split(/\r?\n/).map(l => baseTune(gun, l, false)).join('\n');
      const damage = readNum(tuned, 'damage');
      const minDamage = readNum(tuned, 'minDamage');
      const fireTime = readNum(tuned, 'fireTime');
      // PELLETS ARE PART OF THE DPS, and this is the line that stops the
      // assault ladder shipping an 8x error. `damage` in a GDT is PER
      // PROJECTILE, so a shotgun at damage D does D x shotCount per pull. The
      // assault line normalizes a shotCount-8 shotgun (Mog 12, Executioner)
      // from a shotCount-1 revolver (Magnum) — without dividing by the gun's
      // own shotCount, each pellet got the whole revolver's damage and the
      // Mog 12 emitted 978 x 8 = 7,824 per shot against a T2 target of 978.
      // Caught on the first regen, 2026-08-24. The skirmisher line (shotgun
      // to shotgun) cancels out and is unaffected either way.
      const shot = readNum(tuned, 'shotCount') || 1;

      // ---- PASS 1: the ladder baseline -----------------------------------
      // T1 is its own baseline (it ships what it is tuned to); T2/T3 normalize
      // off it. This is what the gun WOULD ship with no cap, and it is the
      // number the cap clamps — never the raw port damage. Clamping the port
      // number instead would drop every under-cap gun to its unnormalized value
      // (the Klauser ships damage 20, the RPG 7000).
      let dmg = (gun.secTier === 1)
        ? damage
        : Math.round(ref.damage * ref.shot * SEC_DPS[gun.secTier] * fireTime / ref.fireTime / shot);
      const ladder = dmg;

      // ---- PASS 2: the ceiling -------------------------------------------
      const p = PRIMARY_T1[cls];
      let capDmg;
      if (p) {
        // primary DPS one tier below -> this gun's damage per projectile
        capDmg = Math.max(1, Math.round(p.dps * SEC_CAP_REL[gun.secTier] * fireTime / shot));
        if (!SEC_CAP_ONLY || dmg > capDmg) dmg = capDmg;
      }
      const capped = capDmg !== undefined && dmg === capDmg && capDmg < ladder;

      gun.override.damage = dmg;
      if (minDamage !== undefined && minDamage !== 0 && damage)
        gun.override.minDamage = Math.round(dmg * minDamage / damage);

      // ---- the PaP pin, DERIVED not literal --------------------------------
      // The Bulldog and the Magnum pin their Pack-a-Punched damage in tune.setUp
      // (the Magnum also runs papKeepSource, which bypasses papApply outright),
      // so nothing downstream would carry a retune of the base onto their PaP
      // form — it would keep shipping the old hand-written literal. Rewriting
      // the pin here keeps PaP = base x PAP_UP for all twelve secondaries under
      // one rule. Guns that do not pin need nothing: papApply already derives
      // their PaP from this tuned base.
      if (gun.tune.setUp && gun.tune.setUp.damage !== undefined) {
        const before = gun.tune.setUp.damage;
        gun.tune.setUp.damage = Math.round(dmg * PAP_UP);
        if (gun.tune.setUp.minDamage !== undefined && gun.override.minDamage !== undefined)
          gun.tune.setUp.minDamage = Math.round(gun.override.minDamage * PAP_UP);
        console.log(`      PaP pin re-derived: ${before} -> ${gun.tune.setUp.damage} (base x${PAP_UP})`);
      }

      console.log(`  sec T${gun.secTier} ${gun.stem}: ${damage} -> ${dmg} x${shot} pellet(s)`
        + ` = ${Math.round(dmg * shot / fireTime)} DPS`
        + (capped ? `  CAPPED (ladder wanted ${ladder}, cap ${capDmg})` : `  (under cap ${capDmg})`));
    }
  }
}

// ---- generate --------------------------------------------------------------
computeTierOverrides();
computeSecondaryOverrides();

const allGuns = Object.values(LADDER).flat().filter(g => g.enabled);
allGuns.sort((a, b) => {
  const ia = EMIT_ORDER.indexOf(a.stem), ib = EMIT_ORDER.indexOf(b.stem);
  return (ia === -1 ? 999 : ia) - (ib === -1 ? 999 : ib);
});

const blocks = [];
const zoneLines = [];
const csvRows = [];
const emittedNames = new Set();
let total = 0;

for (const gun of allGuns) {
  const text = fs.readFileSync(gun.src, gun.encoding);
  const variants = variantsOf(gun);
  // PaP stat set from the TUNED base form (base tune + tier overrides; the
  // level-0 ladder is the identity) BEFORE any _up variant is generated.
  computePapSet(gun.stem, extractBlock(text, gun.forms[0].srcAsset, gun.forms[0].gdf || gun.gdf)
    .split(/\r?\n/).map(l => baseTune(gun, l, false)).join('\n'));
  for (const form of gun.forms) {
    // form.gdf overrides gun.gdf — the Executioner's PaP half is declared
    // under dualwieldweapon.gdf while its base is a bulletweapon. Without
    // this, extractBlock looks for the wrong decl and throws.
    const block = extractBlock(text, form.srcAsset, form.gdf || gun.gdf);
    for (const v of variants) {
      const name = form.name(v.suffix);
      // form.str( suffix ) — PER-FORM string overrides, applied last. gun.tune.str
      // cannot do this job: it writes the SAME value to every form, and the one
      // thing that needs writing here differs between them by construction — each
      // half of a dual-wield PaP has to name the OTHER half.
      const { text: twin, scaled } = makeVariant(block, form.srcAsset, name, form.gdf || gun.gdf,
        (line) => {
          let l = ladderScale(gun, baseTune(gun, line, form.up), v.levels);
          if (form.str) l = strSet(l, form.str(v.suffix));
          return l;
        });
      if (scaled === 0) throw new Error(`no fields scaled for ${name} — key set mismatch?`);
      blocks.push(twin);
      zoneLines.push(`weapon,${name}`);
      emittedNames.add(name);
      total++;
    }
  }
  // CSV rows: base-variant -> up-variant, so PaP works.
  //
  // THE NAMES MUST COME FROM form.name(), NOT be re-spelled here. This block
  // used to hardcode the up name as stem + '_up' + suffix, which is right for
  // most ports and WRONG for any whose PaP asset carries a trailing suffix: the
  // Enfield's up-form is t5_enfield_up_r0m0_zm and all three blades are
  // <stem>_up_k<N>_zm. Those four stems advertised an upgrade_name that existed
  // nowhere, and stock PaP silently refused every one of them — the entire
  // SLASHER class plus the assault T1 gun could not be Pack-a-Punched (user
  // 2026-08-23: "why couldnt i pap my enfield"). form.name() is the same
  // function that writes the zone line and the GDT block name, so the three
  // can no longer disagree.
  const fBase = gun.forms.find(f => !f.up), fUp = gun.forms.find(f => f.up);
  if (!fBase || !fUp) throw new Error(`${gun.stem}: needs a base form and an _up form`);
  // ...then STRIP a trailing "_zm": the engine drops that suffix, so the script
  // name and the weapons-table name are the asset name without it. See the
  // evidence block in _tod_classes.gsc register_guns — writing the tailed name
  // here is what broke the blades on 2026-08-23.
  const scriptName = n => n.replace(/_zm$/, '');
  for (const v of variants) {
    const b = scriptName(fBase.name(v.suffix)), u = scriptName(fUp.name(v.suffix));
    const c = gun.csv;
    csvRows.push(c.melee
      ? `${b},${u},,${c.cost},${c.vo},,,,,FALSE,FALSE,FALSE,,,FALSE,FALSE,${c.cls},,,`
      : `${b},${u},,${c.cost},${c.vo},,,,,FALSE,FALSE,FALSE,,,FALSE,TRUE,${c.cls},,,`);
  }
}

// GUARD (2026-08-23): every name the weapons table advertises must be an asset
// this run actually emitted. The Enfield/blade PaP bug survived weeks because
// nothing cross-checked the CSV against the zone list — the map built clean,
// linked clean, and only failed at the PaP machine in game. Cheap check, and it
// fails the BUILD instead of the playthrough.
{
  const missing = [];
  for (const row of csvRows) {
    const parts = row.split(",");
    // an emitted asset may carry a trailing "_zm" the script name drops
    const linked = n => emittedNames.has(n) || emittedNames.has(n + "_zm");
    if (!linked(parts[0])) missing.push("base " + parts[0]);
    if (!linked(parts[1])) missing.push("upgrade " + parts[1]);
  }
  if (missing.length)
    throw new Error("weapons CSV references " + missing.length + " name(s) with no emitted asset:" + String.fromCharCode(10) + "  " + missing.join(String.fromCharCode(10) + "  "));
  console.log("  csv/zone cross-check OK (" + csvRows.length + " rows, every base + upgrade name is an emitted asset)");
}

// GUARD (2026-08-24): every DualWieldWeapon reference must resolve to an asset
// this run emitted, REMEMBERING THAT THE ENGINE APPENDS "_zm" TO THE FIELD.
// This is the check that would have caught the Executioner before it shipped:
// its halves were emitted as t6_executioner_rdw_up_b / _ldw_up_b and named each
// other correctly, so every existing cross-check passed — but the engine went
// looking for "<field>_zm", found nothing, and aborted the map load with
// "Com_ERROR: could not find alt dualwield". The map built clean and linked
// clean; the only symptom was a map that would not load.
//
// Both directions matter: the field must not carry _zm (the AMP63's 2026-08-23
// failure) and the asset it points at must (the Executioner's, 2026-08-24).
{
  const bad = [];
  for (const block of blocks) {
    const name = (block.match(/^\t"([A-Za-z0-9_]+)" \( "[a-z]+\.gdf" \)/m) || [])[1];
    const m = block.match(/"DualWieldWeapon"\s+"([A-Za-z0-9_]*)"/);
    if (!name || !m || !m[1]) continue;               // blank = not dual wield
    if (/_zm$/.test(m[1]))
      bad.push(name + ' names "' + m[1] + '" — the field must NOT carry _zm, the engine appends it');
    // The "_zm" asset is the ONLY valid resolution — do not also accept the bare
    // name as a fallback. Accepting it is what made the first version of this
    // guard pass the exact bug it was written to catch: with both halves emitted
    // WITHOUT _zm they satisfied each other, while the engine still resolved
    // "<field>_zm" and found nothing.
    else if (!emittedNames.has(m[1] + "_zm"))
      bad.push(name + ' names "' + m[1] + '" -> engine resolves "' + m[1] + '_zm", which nothing emitted');
  }
  if (bad.length)
    throw new Error("dual-wield cross-reference is broken (the map will not load):" + String.fromCharCode(10) + "  " + bad.join(String.fromCharCode(10) + "  "));
  console.log("  dual-wield cross-check OK");
}

// GUARD (2026-08-24): A PACK-A-PUNCHED SECONDARY MUST OUT-DAMAGE ITS OWN BASE.
// Written because the opposite shipped. When the secondary nerf was applied to
// DAMAGE_KEYS in baseTune's isUp branch it double-counted against every PaP form
// that derives through papApply, landing them all at 1.25 x 0.75 = 0.9375 of
// base: the RPG at 563 -> 528, the Nail Gun 460 -> 431, the SG12 138 -> 130.
// Nothing caught it. The build was clean, the linker was clean, the ledger was
// clean, and the only way to notice was to Pack-a-Punch a sidearm in game and
// feel it get worse.
{
  const dmgOf = {};
  for (const block of blocks) {
    const n = (block.match(/^\t"([A-Za-z0-9_]+)" \( "[a-z]+\.gdf" \)/m) || [])[1];
    const d = block.match(/"damage"\s+"(-?\d+(?:\.\d+)?)"/);
    if (n && d) dmgOf[n] = parseFloat(d[1]);
  }
  const bad = [];
  for (const gun of allGuns) {
    if (!gun.secondary || gun.melee) continue;
    const fBase = gun.forms.find(f => !f.up), fUp = gun.forms.find(f => f.up);
    if (!fBase || !fUp) continue;
    for (const v of variantsOf(gun)) {
      const b = dmgOf[fBase.name(v.suffix)], u = dmgOf[fUp.name(v.suffix)];
      if (b === undefined || u === undefined) continue;
      if (u <= b)
        bad.push(`${gun.stem}${v.suffix}: PaP ${u} <= base ${b} — Pack-a-Punch makes this gun WORSE`);
    }
  }
  if (bad.length)
    throw new Error("secondary PaP is not an upgrade:" + String.fromCharCode(10) + "  " + bad.join(String.fromCharCode(10) + "  "));
  console.log("  secondary PaP-beats-base check OK");
}

// latin1 superset of ascii — safe for the mixed sources
fs.writeFileSync(OUT_GDT, '{\n' + blocks.join('\n') + '\n}\n', 'latin1');
console.log(`wrote ${OUT_GDT}  (${total} variant weapon assets)`);

fs.writeFileSync(OUT_ZPKG, [
  '// GENERATED by tools/gen_tod_twins.js — twin-swap weapon variants.',
  '// Included from zm_tower_of_doom.zone via `include,tod_twins`.',
  ...zoneLines, '',
].join('\n'));
console.log(`wrote ${OUT_ZPKG}  (${zoneLines.length} weapon lines)`);

// Idempotent CSV patch — NO marker/comment lines (the weapon-table parser
// reads every line as a row; a "## comment" row would feed GetWeapon garbage).
// Strip every row that LOOKS like a generated variant of ANY ladder stem
// (enabled or not — a gun that was disabled again must lose its rows), then
// append the current set. Variant rows = <stem>(_up)?(_<letter><digit>...|_b),
const stems = Object.values(LADDER).flat().map(g => g.stem).sort((a, b) => b.length - a.length);
// The optional `(?:_zm)?` is load-bearing (co-op audit 2026-08-23). Without it
// the tail after the ladder suffix had to be the comma itself, so a row written
// in the `_zm`-suffixed era — `t9_me_knife_american_k0_zm,` — never matched
// (`_z` is not `[a-z]\d`). Those rows survived every purge AND the current set
// was appended beside them, so each regen added 18 duplicate blade rows: the
// CSV was observed growing 145 -> 163 lines with 18 duplicated column-0 names.
// The stale rows name assets that no longer exist, which is harmless only for
// as long as nothing looks them up — the day a blade is retired or re-laddered,
// a GetWeapon() on a dead name at level init is the frontend-dump case.
const variantRe = new RegExp(`^(?:${stems.map(s => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|')})(?:_up)?(?:_(?:[a-z]\\d)+|_b)(?:_zm)?,`);
let csv = fs.readFileSync(CSV, 'utf8');
csv = csv.split(/\r?\n/).filter(l => !variantRe.test(l)).join('\n');
if (!csv.endsWith('\n')) csv += '\n';
csv += csvRows.join('\n') + '\n';
fs.writeFileSync(CSV, csv);
console.log(`patched ${CSV}  (${csvRows.length} PaP-mapping variant rows, marker-free)`);

// ---- the ledger ------------------------------------------------------------
const LEDGER_FIXED = countFixedRegistrations();
const ledger = total + LEDGER_FIXED;
console.log(`REGISTRATION LEDGER: ${total} generated + ${LEDGER_FIXED} fixed = ${ledger}  (guard ${LEDGER_GUARD}; map 1 shipped a BOOTING 229-asset table, 368 = boot-AV)`);
if (ledger > LEDGER_GUARD) throw new Error(`ledger ${ledger} exceeds the ${LEDGER_GUARD} guard — retire an axis or a gun before adding more`);
