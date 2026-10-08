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
// 2026-10-01 (docs/167 item 6; lead tester: "Lunge attack takes to lonk and it
// slows down melee speed cause you canot cancel by knifing again"): THE LUNGE'S
// KILL RECOVERY RIDES THE SAME MULTIPLIERS NOW. A bat lunge that kills holds the
// blade for meleeChargeFatalTime, and that key was in no set: SLASHER_SWING_MULT,
// PaP and every KNIFE SPEED rung shortened the swing and left the lunge at 0.6 s
// (0.7 s on the PaP bat, whose form kept the PORT value) - so at PaP + KNIFE
// SPEED 5 a lunge kill held the blade about twice as long as a swing, and the
// engine lunges on its own whenever a zombie is in reach. The left-hand variants
// join for the same reason: no melee timing the engine may play runs on old time.
const MELEE_KEYS = new Set(['meleeTime', 'meleeChargeTime', 'meleeChargeFatalTime',
  'meleeLeftTime', 'meleeLeftChargeTime', 'meleeLeftChargeFatalTime']);
// ... and a second press QUEUES SOONER (the "cannot cancel by knifing again" half).
// meleeQueueMeleeEarlyTime is the window at the end of a melee in which the next
// press is held and fired the instant the blade is free; 0.2 -> 0.35 s on every
// blade, both forms. An absolute, not a scaled key: the window is how early you
// may press, not how long anything takes.
const MELEE_QUEUE_EARLY = 0.35;
// THE BLADES' "INSPECT" IS THEIR RELOAD (2026-10-01, docs/167 item 5; lead
// tester: "Holding the interact button to open a door shares the exact same
// button as the bat/katana inspection animations. You cannot interact with doors,
// buy ammo, or purchase perks while this animation plays, and you cannot attack
// during it"). BO3 has no inspect field (deffiles/bulletweapon.awi): the T9 melee
// ports put their inspect clip in reloadAnim (and lowReadyLoopAnim), so the
// RELOAD press played it - and a controller's X is +usereload, the same button as
// every buy. A reload cannot be cancelled from script (no API; IsReloading only
// reads it), and while one runs the blade cannot swing and the use is not taken:
// 1.8 s on the bat, 2.88 s on the katana, 1.5 s for Stormbreaker's taunt. So the
// clip comes OFF the reload lane - no reload animation and a one-frame reload,
// which leaves a blade's reload press nothing to do and the button free for the
// buy. lowReadyLoopAnim keeps the clip (nothing on this map enters low-ready).
const MELEE_NO_INSPECT_STR = { reloadAnim: '', reloadEmptyAnim: '' };
const MELEE_NO_INSPECT_SET = { reloadTime: 0.05, reloadEmptyTime: 0.05, reloadAddTime: 0.05, reloadEmptyAddTime: 0.05 };
// SLASHER SWING +10% ALL AROUND (user 2026-09-30: "Slasher needs a bit faster
// swing too all around"). A BASE multiplier on every melee form's swing and
// charge time (x0.90 = 11% more swings a second), applied in buildBase's tune
// sets so the PaP form (PAP_TRIM on the tuned base) and every KNIFE SPEED rung
// (the k-ladder composes on top) inherit it. One knob; docs/armory.html BLADES
// mirrors the resulting times.
const SLASHER_SWING_MULT = 0.90;

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

// +1 MAGAZINE ON EVERY GUN (user 2026-08-26: "all guns need to have 1 extra mag.
// Ammo is scarce even when we have an ammo crate. Many people are complaining").
//
// ADDITIVE, AND THAT IS THE WHOLE POINT. RESERVE_MULT is a ratio, and the
// 2026-08-23 pass above already recorded why a ratio is the wrong tool for this
// job: "a small gun may not move at all while a large one gains a whole
// magazine". Reserves here run from 2 magazines (Death Machine) to 24 (RPG), so
// any x-factor big enough to help the Death Machine hands the RPG a fistful of
// rockets. One flat magazine lands identically on both — which is exactly what
// "all guns need 1 extra mag" asks for.
//
// APPLIED AFTER the multiplicative pass — final = round(src x mults) + 1 — so it
// composes with CLASS_RESERVE_MULT and gun.reserveMult rather than being scaled
// by them. The skirmisher still gets its x1.3 AND the magazine.
//
// FOUR THINGS CHECKED BEFORE ADDING IT:
//  1. MELEE IS SAFE. Every blade form carries maxAmmo/startAmmo 0, and addSets
//     keeps 0 the same way scaleSets does. A knife must never be handed a
//     magazine, and the 0-guard is the only thing standing between it and one.
//  2. THE PaP FORM INHERITS IT FOR FREE, so do NOT add it again in the isUp
//     branch. computePapSet reads the TUNED base and maxAmmo/startAmmo are
//     PAP_COPY_KEYS (factor 1), so every _up form copies the already-bumped
//     value. A second add there would silently give PaP guns two magazines.
//  3. papKeepSource IS THE ONE EXCEPTION AND IT IS HANDLED IN baseTune. That
//     branch bypasses papApply outright, so the Magnum's _up form would have
//     been the only asset in the map to miss the magazine. The 2026-08-25 note
//     there deliberately keeps RESERVE_MULT and the class knob out of that
//     branch because they were silent balance changes to a gun nobody asked to
//     retune — this one is a roster-wide change the user asked for by name, so
//     it goes in, and the note now says so.
//  4. THE AMMO CRATE GAINS WITH IT. The crate refills to maxAmmo, so raising
//     maxAmmo raises what 5,000 points actually buys. That is the second half of
//     the complaint ("even when we have an ammo crate") and it is why this knob
//     answers it and a crate price cut would not have.
//
// NOT COVERED — the two secondaries that are not generated here: `pistol_standard`
// (heavy T1) and `t9_amp63` (slasher T1). Their GDTs are install-side and SHARED
// WITH MAP 1, so editing them would silently change that map's guns too — the
// same call the v9.36 and v10.x reserve passes made. Both are T1 SIDEARMS, never
// a class primary, so no player's main gun misses the magazine.
const RESERVE_ADD = 1;

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
// ⚠️ v14.32 then v14.33 (user 2026-08-30: "nerf skirmisher damage by 10%.
// Primary weapons only", then "reduce damage for skirmisher primary by another
// 10%") — SKIRMISHER 1.3225 -> 1.19025 -> 1.071225. That is x0.9 TWICE, i.e.
// x0.81 of where the class started the day, NOT x0.8: the second cut is 10% of
// the already-reduced number, which is what "another 10%" means. Both were
// primaries-only, and CLASS_SEC_CAP_MULT below is pinned to an ABSOLUTE value
// rather than a ratio precisely so a second cut needs no second edit — the
// shotgun ceiling stays where it was through any number of primary retunes.
// The "PRIMARY WEAPONS ONLY"
// clause is why CLASS_SEC_CAP_MULT below exists: the paragraph above is still
// true, this knob DOES move the secondaries, and that coupling was correct for
// the 2026-08-25 buff (which was explicitly "primaries and secondaries"). It is
// WRONG here. Left alone, the MAC-10 would drop 10%, drag PRIMARY_T1 down 10%,
// and the Bulldog / SG12 / SPAS-12 would fall 10% with it — the exact guns this
// order excluded. The cap is therefore pinned at the OLD multiplier.
const CLASS_DAMAGE_MULT  = { skirmisher: 1.01766375, heavy: 0.81, assault: 1.155 };   // assault 1.10 -> 1.155 (x1.05) 2026-09-23, user: "buff the assault primary gun damage by five percent, all three tiers" - PRIMARIES ONLY, so CLASS_SEC_CAP_MULT.assault pins the sidearm ceiling at the old 1.10
// skirmisher -5% 2026-09-03 (1.071225 x 0.95; THIRD cut - two -10% on 2026-08-30 took 1.3225 -> 1.071225); assault 1.10 = the 2026-08-29 "+10% damage buff" (user order); T1-only, tiers normalize from it
// THE MULTIPLIER THE SECONDARY CEILING IS MEASURED AT, when it must differ from
// the one the primaries ship at. computeSecondaryOverrides clamps each sidearm
// to PRIMARY_T1[cls].dps x SEC_CAP_REL[tier], and PRIMARY_T1 is measured off the
// TUNED T1 primary — so the cap normally rides CLASS_DAMAGE_MULT by
// construction. An entry here decouples the two: the cap is computed as if the
// class knob were still this value, while the primaries actually ship at
// CLASS_DAMAGE_MULT.
//
// ONLY ADD AN ENTRY FOR A KNOB THAT DELIBERATELY MOVES PRIMARIES ALONE. If a
// future order moves the whole class again, DELETE the entry rather than
// updating both numbers — an absent entry means "cap follows the primaries",
// which is the default and the safer state to fall back to. Two numbers that
// must be kept in a ratio are exactly the lockstep pair this codebase keeps
// getting burned by; this comment is the reason the ratio is not hidden in one.
// THE SKIRMISHER SIDEARM CEILING, and the pre-v17.4 baseline it is measured from.
//
// 1.3225 is the ABSOLUTE pin v14.32 introduced so the primaries' own cuts stop
// dragging the shotgun ceiling with them — which is why a secondary change is
// always a SEPARATE edit from a primary one, and why the -5% primary cut above
// does not touch these three guns.
//
// HISTORY, because this knob has now moved twice in one day and the second move
// REVERSED the first: v16.99 took it to x0.90 (1.19025) on "nerf skirmisher
// primaries by 5% and secondaries by 10%". The user played it and reversed the
// secondary half the same evening — "revert the skirmisher secondary nerf and
// instead buff by 10%. Except the spaz. That'll actually be 5% nerf instead."
// So the ceiling is now measured from the ORIGINAL 1.3225, not from the nerfed
// value: +10% for the Bulldog and the SG12, and the SPAS-12 alone lands at -5%.
const SKIRM_SEC_BUFF = 1.10;    // Bulldog + SG12: +10% on the 1.3225 baseline
const SKIRM_SPAS_NET = 0.95;    // SPAS-12 ALONE: -5% on that same baseline
const CLASS_SEC_CAP_MULT = { skirmisher: 1.3225 * SKIRM_SEC_BUFF,   // = 1.45475
                             assault: 1.10 };   // 2026-09-23: the +5% assault buff is PRIMARIES ONLY; pinned at the pre-buff multiplier so the assault sidearms stay byte-identical

// CLASS HANDLING KNOBS - PRIMARIES ONLY, EVERY TIER, BASE AND PaP (user
// 2026-09-23: "for all assault primary weapons. The hip fire spread needs to be
// tightened by 20%. And the strafe speed while aiming down needs to be
// increased by 25%").
//
// UNLIKE CLASS_DAMAGE_MULT THESE ARE NOT T1-ONLY: nothing in the tier ladder is
// derived from spread or ADS move speed, so each tier's gun takes the factor on
// its OWN port value. And neither stat is in a papFactor set, so the _up form
// keeps the port's values unless baseTune's PaP branch scales them too - it
// does, once, through the same classHandlingSets().
//
// SPREAD = THE MIN/MAX CONE ANGLES ONLY. The engine draws the cone as
// min + (max - min) x the aim-spread fraction, and the fire/move/turn/sprint
// adds and the decay rate move that FRACTION, not an angle - so scaling every
// min and max by 0.8 tightens the cone by exactly 20% in every stance at every
// moment while the bloom timing stays the port's. Scaling the adds as well
// would ALSO slow the bloom, which is a second change nobody asked for.
//
// ADS MOVE = adsMoveSpeedScale, the per-weapon multiplier the engine applies
// while aiming (in every direction; strafing is where players feel it). The
// ports disagree on it - the Enfield ships 1.9, the Krig 6 and AK-47 ship 1.
// First pass was x1.25 on each (2.375 / 1.25 / 1.25); the user then set the
// numbers directly: "Make it 2.0, 1.5, and 1.5 respectively". So they are
// PINNED per stem (every form, base and PaP), not a class ratio.
const HIP_SPREAD_KEYS = new Set([
  'hipSpreadStandMin', 'hipSpreadMax',
  'hipSpreadDuckedMin', 'hipSpreadDuckedMax',
  'hipSpreadProneMin', 'hipSpreadProneMax',
  'hipSpreadSlideMin', 'hipSpreadSlideMax',
]);
const CLASS_HIP_SPREAD_MULT = { assault: 0.80 };   // 2026-09-23: -20% hip cone
const ADS_MOVE_PIN = { t5_enfield: 2.0, t9_krig6: 1.5, t9_ak47: 1.5 };   // 2026-09-23 (ports: 1.9 / 1 / 1)
function classHandlingSets(gun) {
  if (gun.secondary) return [];
  const out = [];
  const hs = CLASS_HIP_SPREAD_MULT[gun.cls] || 1;
  if (hs !== 1) out.push([HIP_SPREAD_KEYS, hs]);
  return out;
}
function adsMovePin(line, gun) {
  if (gun.secondary || ADS_MOVE_PIN[gun.stem] === undefined) return line;
  return absSet(line, { adsMoveSpeedScale: ADS_MOVE_PIN[gun.stem] });
}

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
// SLASHER SIDEARMS +25% ON FIVE NUMBERS (user 2026-09-01: "Pick the 5 most
// important GDT numbers and buff 5 of them by 25% for the slashers secondaries.
// All tiers base and pap"). The five: damage, fire rate (fireTime), clipSize,
// reserve magazines, reload times. ONE knob, applied per gun on the two GENERATED
// slasher sidearms (UDM T2, RK7 T3) as: tune.fire = tune.reload = 1/BUFF (the
// FIRE_KEYS / RELOAD_KEYS sets), clipMult = BUFF (sidearm clipMult lives in
// computeSecondaryOverrides), reserveMult x BUFF, and dmgMult = BUFF. WHY dmgMult
// IS EXACTLY BUFF AND NOT MORE: the T1 reference (SEC_T1_REF.slasher) already
// carries the AMP63's +25% (its script multiplier 0.75 -> 0.9375), so the
// ladder hands T2/T3 the +25% damage by construction - but the ladder holds DPS
// against the gun's OWN fireTime, and fireTime x0.8 would pull that damage back
// x0.8. dmgMult, applied AFTER the cap, restores it: final damage = +25%, final
// fire rate = +25%, so DPS is x1.5625 - the user asked per NUMBER, and that is
// the consequence, stated in the CHANGELOG. The T1 AMP63 is a RAW PORT (shared
// install-side GDT): only its DAMAGE moves (gun_balance_mult); its other four
// numbers cannot be touched from this repo - flagged to the user, not done.
const SLASHER_SEC_BUFF = 1.25;
// SLASHER SIDEARMS RELOAD 30% SLOWER (user 2026-10-04: "increase the reload time
// on the slashe secondaries by 30% all of them"). A multiplier on every reload
// TIME, applied on top of the v16.12 buff above: tune.reload = 1.3 / 1.25 = 1.04,
// so each reload is 1.3x what it was yesterday (and 4% over the port's own). The
// PaP form inherits it through computePapSet (PAP_TRIM on the TUNED base), so
// base and PaP move together. The T1 AMP63 is NOT generated here (a raw port
// shared with Tower II) - it takes the SAME constant through its own map-owned
// copy, tools/gen_tod_amp63.js (TOD_AMP63_RELOAD_MULT, LOCKSTEP with this one).
const SLASHER_SEC_RELOAD_MULT = 1.3;
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
// v19.63 (user 2026-09-30: "Improve fire rate increase from fire rate upgrade
// a bit"): -8% -> -10% shot time per level, so Lv3 is x0.70 (was x0.76) =
// +43% shots/s at the cap (was +32%). LOCKSTEP: the FIRE RATE add_domain copy
// in _tod_upgrades.gsc and docs/armory.html state the same steps.
const FIRE_STEP = [1, 0.90, 0.80, 0.70];     // f0..f3
// DOUBLE TAP -> THE ICE STAFF'S RATE (v19.25, 2026-09-21) - user: "can we make
// sure that double tap effects the ice staff fire rate as well".
//
// ⚠️ THIS HAD TO BE A WEAPON TWIN AND THERE WAS NO CHEAPER LANE. BO3 HAS NO
// PER-PLAYER FIRE-RATE CALL - this map established that when it made FIRE RATE
// a variant ladder and when it refused that domain a Dark rung ("+8
// registrations, no per-player fire-time call exists"). Script can only ever
// make a gun SLOWER (DisableWeaponFire), never faster, and the ice staff's
// cadence is the ENGINE's own `fireTime` since v18.99c. The fire staff's new
// rate card gets to be pure script only because fire is a `Charge Shot` weapon
// whose every shot is a fresh trigger press the script flag is read on; ice is
// `Single Shot` and v18.94 already proved the flag does not hold it (the staff
// fired as fast as the trigger could be clicked). So: a second ice asset.
//
// -25% fire time = x1.33 rate, 0.80 s -> 0.60 s. That is Double Tap's classic
// rate figure, and it is OURS: the engine's own Double Tap bonus is not a
// number this repo can read, and whatever the engine may or may not already do
// to a projectileweapon is not something to stack a guess on top of. If the
// user's playtest says the staff is faster than 0.60 s, the engine IS also
// applying one and this step is what to cut.
const DTAP_STEP = [1, 0.75];                 // d0 = no perk, d1 = holding Double Tap
const HANDLING_STEP = [1, 0.85, 0.75, 0.65, 0.45]; // h0..h3, h4 = DARK -55% (MP7 PaP only, v17.10)
// RECOIL ladder. History: -25/-45/-65% (2026-08-19) -> HALVED 2026-08-21 (user:
// "nerf the recoil upgrade by like 50%") to -10/-20/-30% -> v9.45 2026-08-23
// (user: "recoil should be two levels only. 8% and 16%") to TWO levels at
// -8/-16% -> 2026-08-26 ASSAULT BUFF (user: "Recoil will go to 10% per level")
// to -10/-20%, still two levels -> v16.50 2026-09-02 (user: "buff recoil to
// 15%") to -15/-30%, still two levels. The card art + the Lua DOMAIN desc + the Lua
// DETAIL val table + add_domain's max carry these numbers — keep all of them in
// lockstep, and note that AXIS.r.levels below is the one that decides how many
// weapon assets actually get emitted (unchanged at 2, so this retune changes
// gun DATA only: same asset names, same registration count, no dead forms).
// RECOIL (v17.10, user 2026-09-04: "First level can be 20% and dark upgrade
// will be 30% at 50% improvement total. And should only be on AK 47").
//   r0 = none, r1 = the domain's ONE level (-20%), r2 = the DARK rung (-50%).
// The domain max is therefore 1, not 2 — r2 is not reachable by levelling, only
// by the dark upgrade (see twin_suffix). Was [1, 0.85, 0.70] = -15/-30 over two
// levels on all three assault guns.
const RECOIL_STEP = [1, 0.85, 0.70, 0.40];   // r0 / r1 -15% / r2 -30% / r3 DARK -60% (AK-47 PaP only, v17.10)
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
const KNIFE_STEP = [1, 0.90, 0.84, 0.80, 0.77, 0.74, 0.54];   // k0..k5, k6 = DARK -46% swing time (Stormbreaker PaP only, v17.10)
// MAG SIZE NERFED 2026-09-01 (user: "mag size needs a nerf so should be 20% per
// tier instead of 30%"). Was [1, 1.3, 1.6, 1.9] from 2026-08-20. Same four
// m-forms, same registration count — the ledger does not move; only the
// clipSize inside each m-form changes (Math.round of base x step: the Krig's 33
// goes 40/46/53 instead of 43/53/63). Mirrors that must follow: the add_domain
// desc + Lua DOMAIN[7]/DETAIL[7] (+20/+40/+60%), the armory row, and the three
// i_tod_card_mag_size_* PNGs, which bake +30/+60/+90% as pixels (docs/65 is
// the re-bake prompt).
const MAG_STEP = [1, 1.2, 1.4, 1.6, 1.9];  // m0..m3 +20%/Lv, m4 = DARK +90% (AK-47 PaP only, v17.10)
// PENETRATION tiers (user 2026-08-21): the engine's three values are small /
// medium / large — there is no "low" (verified across the Skye pack).
const PEN_TIER = ['small', 'medium', 'large'];

// axis letter -> how a level scales a block. `sets` = [[keySet, stepTable]]
// (scaleSets); `pen` = the string-valued penetrateType ladder. The GSC side
// (_tod_classes::register_gun axes) uses the SAME letters.
const AXIS = {
  q: { domain: 'mage_quickhands', levels: 1, sets: [[new Set([...SWAP_KEYS, 'quickDropTime', 'altDropTime', 'adsAltDropTime', 'adsAltRaiseTime', 'swimDropTime']), [1, 1 / 3]]] },
  // DOUBLE TAP ON THE ICE STAFF (v19.25) — the ONE axis whose level is a PERK,
  // not a domain. See DTAP_STEP and _tod_upgrades::axis_level.
  d: { domain: 'doubletap',   levels: 1, sets: [[FIRE_KEYS, DTAP_STEP]] },
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

// ---- NAIL GUN NERF (user 2026-09-09) --------------------------------------
// "The nail gun base and pap need a 15% damage nerf and 10% fire rate nerf and
// clip nerf by 25%."
//
// ONE SET OF KNOBS COVERS BOTH FORMS. computePapSet builds the _up block from
// the TUNED BASE (x PAP_UP on damage/clip, x PAP_FAST on fireTime), so a base
// nerf propagates to the PaP form by construction -- which is why there is no
// tune.setUp here and must not be one. Proof it derives rather than ships its
// own numbers: the pre-nerf pair was 460/575 damage (x1.25), 0.157/0.1256
// fireTime (x0.8) and 40/50 clip (x1.25), exactly the PaP factors.
//
// RATE: fireTime is an INTERVAL, so "10% fewer shots per second" is x1/0.9, not
// x0.9. Same convention as the ice staff's 0.80 -> 1.00 (20% fewer shots).
const NAIL_RATE_NERF = 1 / 0.90;
// DAMAGE: the number the user asked to see move, applied to the SHIPPED value.
const NAIL_DMG_NERF  = 0.85;
// ⚠️ THE FIRE-RATE NERF WOULD OTHERWISE CANCEL THE DAMAGE NERF. A secondary's
// damage is NOT the port's -- computeSecondaryOverrides normalizes it to a DPS
// target held against the gun's OWN fireTime (round(2929.6875 x fireTime) for
// this rung), so slowing the gun 10% RAISES its normalized damage by the same
// 10% before dmgMult ever runs. Divide that back out, or the two instructions
// fight and the gun ships at 0.944 damage instead of 0.85. This is the same
// trap the PaP +25% case documents at CLASS_DAMAGE_MULT: the ladder holds DPS,
// so anything that moves fireTime must pay the difference back explicitly.
const NAIL_DMG_MULT  = NAIL_DMG_NERF * 0.90;   // = 0.765, i.e. 0.85 / NAIL_RATE_NERF
// CLIP: applied to the tuned base; the PaP clip derives from it.
const NAIL_CLIP_NERF = 0.75;

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
//                            fireTime 0.092) times the 0.9375 script mult in
//                            gun_balance_mult = 126.5625 (0.75 -> 0.9375 in v16.12,
//                            the slasher-sidearm +25%). Measured once, by hand,
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
  slasher: { damage: 135 * 1.03125, fireTime: 0.092, shot: 1 },  // v19.63: 135 x 1.03125 = 139.21875 (slasher +10%; was 0.9375 from v16.12, 0.75 before); tracks gun_balance_mult
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
// MELEE -20% ACROSS THE BOARD (user 2026-08-30: "nerf damage on melee by 20%").
// Applied to EVERY rung, base and PaP alike, so the ladder's shape is unchanged
// and only its height moves: 2000/4000 -> 1600/3200, 4000/8000 -> 3200/6400,
// 6800/13600 -> 5440/10880. Against this map's HP curve (~x1.1/round) a x0.8
// damage cut is worth ~2 rounds of one-hit reach at every rung, so the top form
// (PaP Stormbreaker) stops one-hitting around r33 instead of r35. BACKSTAB
// follows automatically (BACKSTAB_MULT x1.5 of these numbers), so the map's
// backstab ceiling drops 20400 -> 16320 with no second edit.
// LOCKSTEP: register_melee_dmg() in _tod_classes.gsc carries the same six
// numbers and must move with this line.
// SLASHER +10% ALL AROUND (user 2026-09-30). Every rung x1.1, base and PaP:
// 1600/3200 -> 1760/3520, 3200/6400 -> 3520/7040, 5440/10880 -> 5984/11968.
// The sidearm line takes the same +10% through SEC_T1_REF.slasher below (the
// AMP63's script multiplier, which the UDM/RK7 ladder is normalized from).
const MELEE_TIER_DMG = { 1: [1760, 3520], 2: [3520, 7040], 3: [5984, 11968] };

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
// RAISED 220 -> 223 (2026-09-01) TO THE FIGURE THE MAP ALREADY SHIPS AT, NOT
// FOR HEADROOM. v14.17's nine BO7 perk-can weapons took the fixed count 21 -> 30
// and the ledger 214 -> 223; every build since has BOOTED at 223 (v14.17 through
// v16.5). Once the 2026-09-01 tooling fix moved this throw above the writes, the
// generator could no longer regenerate EVEN THE UNCHANGED ROSTER — the first
// weapon retune after it (Death Machine spinMinigunOnADS, nail gun explosion)
// hit the hard stop with ZERO registrations added. 223 = zero net headroom: the
// next weapon,line ADDED anywhere (a gun, an axis, a can) trips it again, and
// must be paid for by retiring one — the rule above stands.
// v16.63 (2026-09-02): 224. The RIOT SHIELD upgrade's Lv5 form is Logical's
// standalone weapon def (weapon,log_riotshield_zm in the main zone) — ONE new
// registration, the first since the perk cans, paid for deliberately: the
// alternative (five per-level shield assets) was five, and the base shield
// (stock zod_riotshield) costs nothing because its CSV row is the inclusion lane.
// Map 1 booted at 229; 224 leaves five under that and the rule above still
// stands for the NEXT one.
// v17.10 (2026-09-04): 229, RAISED DELIBERATELY AND AS AN EXPERIMENT.
// The user restored the r axis to the Enfield and Krig 6 on top of the four
// dark rungs, which lands the ledger on exactly 229 — the figure map 1's .ff
// actually PACKED AND BOOTED (old repo docs/21 §A). So this is not new ground;
// it is the known-good line with zero margin.
//
// WHAT IS AND IS NOT KNOWN, because the difference matters here: the measured
// points are 230 twins BOOT, 368 CRASH, 414 CRASH. Everything from 231 to 367
// is UNTESTED — a 137-wide unknown band, not a gentle slope. ~230 is a floor of
// confidence, not a ceiling of capacity, and the failure is a boot AV that
// takes the whole map load down rather than degrading.
//
// ✅ BOOT-CONFIRMED 2026-09-04 — zm_tower_of_doom loads at ledger 229 with its
// OWN asset mix, not map 1's. That is a THIRD measured point and the first on
// this map: 229 (this map, boots) / 230 (map 1 twins, boots) / 368 (boot AV).
// The untested band is now 231..367 and the rule below is unchanged — the next
// weapon,line anywhere must still be paid for by retiring one, because 229 is
// the line with ZERO margin, not a budget with room in it.
//
// ORIGINAL NOTE: 229 needs a BOOT TEST, not just a green build. If it boots, this is the
// proven line and the old rule stands — the next weapon,line anywhere must be
// paid for by retiring one. If it does not, drop the r axis from the Enfield
// and Krig again (one edit each here and in _tod_classes.gsc) for 197.
// 229 -> 232 (2026-09-07): the MAGE's three BASE staff rungs, +1 each.
//
// THIS IS THE USER'S CALL AND IT IS AN EXPERIMENT, NOT A KNOWN-SAFE NUMBER:
// *"Let's see what happens if we go to two thirty. If it crashes, then
// I'll try to make room for you."* ~230 is the last count this engine is
// KNOWN to have booted (map 1); it is NOT the proven break point, and the
// failure mode above the real ceiling is a boot-time AV, not a script
// error. If the map fails to load, this is the first thing to move --
// retire weapon rungs (the four dark rungs free 10) rather than raising it.
// 235 -> 237 (v19.25, 2026-09-21): the ice staff's DOUBLE TAP `d` axis, +2.
// The user was shown the cost and the risk and chose to spend it ("Build the
// twin now") with nothing offered to retire, so this is the same experiment the
// paragraph above describes, two rungs further out. 235 is a count this map is
// KNOWN to boot at; 237 is not yet. ⚠️ IF THE MAP STOPS LOADING, THIS IS THE
// FIRST SUSPECT AND THE FIX IS ONE LINE: put the ice staff back to
// `axes: ['q']` (here and in _tod_classes::register_gun), drop this to 235, and
// Double Tap simply stops touching the ice staff again. Do that before touching
// anything else - a boot-time AV names no asset and blames nobody.
const LEDGER_GUARD = 237; // Quick Hands experiment (3) + the ice staff's Double Tap twin (2).

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
    const c = (fs.readFileSync(f, 'utf8').match(/^weapon(?:full)?,/gm) || []).length;
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

// ---- THE MAGE GATE (docs/114) ----------------------------------------------
// ONE flag, READ FROM THE GSC HEADER rather than duplicated here. At 0 the three
// staff rows below are enabled:false, so they are filtered out of allGuns,
// short-circuit in computeTierOverrides BEFORE its only readFileSync, and emit
// no GDT block, no zone line, no CSV row and ZERO registrations.
// source_data/tod_staff.gdt does not have to exist yet.
//
// AT 1 THIS THROWS UNTIL THE LEDGER IS PAID, and that is the guard working:
// 201 generated + 28 fixed = 229 against LEDGER_GUARD 229. Three tiers with
// `axes: []` cost 2 each = 6, the run lands at 235, and the throw sits above
// every writeFileSync. docs/114 has the payment options.
//
// existsSync-guarded so a checkout without the header degrades to OFF rather
// than taking the generator down.
const MAGE_GSH = path.join(REPO, 'scripts', 'zm', 'zm_tower_of_doom', '_tod_mage.gsh');
const MAGE_ON = fs.existsSync(MAGE_GSH) &&
  /^\s*#define\s+TOD_MAGE_ENABLED\s+1\b/m.test(fs.readFileSync(MAGE_GSH, 'utf8'));

// ---------------------------------------------------------------------------
// PaP OPTIC REMOVAL (v18.94, 2026-09-13) - user: "remove the red dot sight from
// the RPD and the MP7 and MP5. Pap version has the sight."
//
// READ THIS BEFORE TOUCHING AN _up FORM'S SIGHT. On every Skye port in this map
// the BASE gun ships iron sights and no optic at all; the PaP half is the one
// that bolts a reflex onto tag_reflex / tag_aimpoint. So "remove the red dot"
// is a change to the _up form ONLY, and the base guns were never involved.
//
// AND IT IS TWO EDITS, NOT ONE. Deleting the attachment alone is the trap: the
// _up form ALSO swaps in the port's optic-specific ADS animations
// (am_*_snappoint_ads_up, am_*_reflex_ads_up, am_*_quickdot_ads_up), which
// raise the gun to the OPTIC's eye height rather than the iron sights'. Clear
// the model and keep those anims and the player aims down an empty rail with
// the irons sitting below the eye line - a worse gun than either state, and it
// would have looked correct in every screenshot of the hip pose. So the ads
// anims go back to the port's own non-optic pair, which the BASE form of the
// same gun already uses and already packs: PaP then aims exactly like base.
//
// The ONLY things that change are the optic and the ADS pose. Extended mag,
// heavy barrel/stock, PaP camo, damage, reload anims and the upgraded muzzle
// flash all stay - they live in other slots and other fields. Ledger-neutral:
// no weapon asset is added or removed, so the 223-registration guard does not
// move; the reflex xmodels simply stop being referenced by these three guns
// (vm_t9_reflex_quickdot_* still ships for the MAC-10 and the Stoner 63, which
// were deliberately NOT included - the user named three guns, and the Stoner is
// the other LMG whose PaP carries a dot).
//
// noOptic() writes through form.str, so it lands AFTER every ladder scale and
// cannot be undone by one. Empty string is a real clear here - strSet's value
// group is [^"]* and the altWeapon:'' precedent above proves it round-trips.
//
// ⚠️ THE THIRD EDIT, AND IT WAS MISSING FOR TWO PASSES (v19.22, 2026-09-21,
// user: "remove sights from all skirmisher and heavy primary guns base and pap
// ... make sure we dont break the ADS. Sometimes that happens").
//
// A PORT'S PaP FORM HIDES THE IRON SIGHTS BECAUSE THE OPTIC REPLACED THEM.
// v18.94 and v19.10 cleared the optic model and pointed the ADS anims back at
// the irons - and left `hideTags` alone, so on the PaP MP7, Mk48 and HK21 the
// irons stayed HIDDEN and the restored ADS pose raised the gun to a sight that
// was not being drawn: ADS onto bare metal. The PaP MP5 had the mirror of it -
// the base hides `tag_rail` and the PaP did not, so its optic rail stood empty
// on the gun. None of this shows in the hip pose, which is why two passes of
// screenshots missed it.
//
// So a sight removal is THREE edits, and the third is: THE PaP FORM'S SIGHT
// TAGS BECOME THE BASE FORM'S. That is the rule, not a per-gun judgement - the
// base form is the proven-good state (its irons are visible and its ADS anims,
// which the PaP now borrows, were authored against them). Tags that are NOT
// about sights stay as the PaP authored them: the HK21 keeps hiding `tag_clip`
// because its extended mag is still attached over that geometry, so its value
// is the base's sight tags PLUS that one.
//
// hideTags is a single GDT string with literal \r\n escapes between tag names
// (not real newlines), so strSet's line-based [^"]* value group round-trips it.
const noOptic = (adsUp, adsDown, hideTags, extra) => Object.assign({
  // slot 1 = the hip optic, slot 2 = the ADS optic (ports that split them).
  // Tags and offsets go too: a stale tag_reflex with no model is harmless, but
  // leaving the MP7's Z-offset behind would strand a 2.5-unit lift in the file
  // for the next reader to wonder about.
  attachViewModel1: '',  attachViewModelTag1: '',
  attachViewModel2: '',  attachViewModelTag2: '',
  attachWorldModel1: '', attachWorldModelTag1: '',
  attachViewModelOffsetX1: '0',  attachViewModelOffsetY1: '0',  attachViewModelOffsetZ1: '0',
  attachWorldModelOffsetX1: '0', attachWorldModelOffsetY1: '0', attachWorldModelOffsetZ1: '0',
  // the half that makes it a sight removal rather than a sight deletion
  adsUpAnim: adsUp, adsDownAnim: adsDown,
  // ...and the half that gives the restored pose something to aim down
  hideTags,
}, extra || {});

// ---------------------------------------------------------------------------
// THE ASSAULT ARs WEAR A 2x ACOG (v19.25, 2026-09-21) - user: "remove the 1x
// sights from all the ARs primaries on assault and see if we can seemlessly
// add in a 2x acog or something?"
//
// ⚠️ IT DOES NOT MAGNIFY, AND THAT IS NOT A BUG TO GO FIX. BO3's weapon format
// HAS NO ADS-FOV FIELD. Measured, not assumed: every one of the 1,230 weapon
// assets in the mod tools' source_data was read and there is no adsZoomFov, no
// magnification knob on bulletweapon.gdf OR attachment.gdf, `dualRenderADS` is
// 0 on all of them, and the pack's own ZRG 20mm anti-materiel sniper differs
// from an AR only in `adsScopeBlurAmount` and two depth-of-field focal lengths.
// `adsZoomInFrac`/`adsZoomOutFrac` are the ADS TRANSITION fractions, not the
// zoom. The user was told and chose the look anyway. Do not "restore" a zoom by
// guessing at a field - there is nothing to restore it to.
//
// THE SEAM, AND WHY THERE ISN'T ONE. An ADS animation raises the gun until the
// optic's reticle sits at screen centre, so it is authored against ONE reticle
// HEIGHT. None of the three guns ships an ACOG ADS anim (checked on disk: each
// has irons + exactly one optic pair), so the PaP form keeps the optic anim it
// already had and the ACOG is nudged in Z until its reticle lands on the SAME
// height the anim was authored for. Measured off the xmodel_bin geometry - the
// reticle bone `tag_reticle_attach` where the model has one, the reticle/lens
// material centroid where it does not - in gun space:
//
//   AK-47    tag_reflex -7.911,0,2.056 + kobra reticle +5.364,0,1.759 = z 3.815
//            tag_acog_2 -6.396,0,2.056 + acog  reticle -0.314,0,1.274 = z 3.330  -> +0.485
//   Krig 6   tag_holo   -8.895,0,3.495 + holo  reticle +2.327,0,1.093 = z 4.588
//            tag_acog_2 -8.103,0,3.495 + acog  reticle -0.314,0,1.274 = z 4.769  -> -0.181
//   Enfield  tag_elbit  -1.039,0,4.210 + reddot lens   +1.924,0,0.821 = z 5.031
//            tag_susat   0.603,0,4.938 + acog   lens   -2.654,0,0.327 = z 5.265  -> -0.234
//
// X IS DELIBERATELY LEFT AT 0. The reticle moves a unit or two along the barrel
// on every one of these, and that is the one axis the eye is already looking
// down - it changes apparent size, not where the reticle sits on screen. Only Z
// displaces the reticle in the frame, so only Z is corrected. If the scope ever
// reads as FLOATING off the rail in hand, the AK's +0.485 is the one to try
// zeroing first (it is the only lift big enough to see); the cost is a reticle
// that sits about two degrees low.
//
// EACH GUN MOUNTS ON ITS OWN AUTHORED ACOG TAG, not on the 1x tag with a shove.
// Both Cold War guns carry `tag_acog_2` at EXACTLY the same height as the optic
// tag they use today (AK 2.056, Krig 3.495), so the mount is where the rail was
// modelled to take it and only the scope's own internal reticle height is being
// corrected. The Enfield is a BO1 rifle and gets the BO1 glass its own port
// ships - `vm/wm_t5_enfield_acog` on `tag_susat` - rather than a Cold War optic
// bolted to a 1957 rifle.
// ⚠️ THE ENFIELD LEFT THIS SET IN v19.51 (2026-09-23): the user played the SUSAT
// and its aim point did not match the shots ("the tip of the ACOG is not
// aligned with where it actually shoots"), so the packed Enfield aims down its
// irons like the base (noOptic in its ladder entry; the Enfield row of the
// table above is history). The Krig 6 and AK-47 ACOGs stand - if the same
// report comes in for them, the fix is the same one-line swap, never a nudge.
//
// hideTags is UNTOUCHED here and that is the difference from noOptic(): an
// optic is still present, so a PaP form that hides its irons should keep hiding
// them. v19.22's third-edit rule ("the PaP form's sight tags become the base
// form's") is about a gun left with NO sight; this is a gun with a better one.
//
// Ledger-neutral: no weapon asset is added or removed. The ACOG xmodels and all
// eleven of their materials are already declared in the same shared GDTs the
// current optics come from (skye_t9_wepcommon / skye_t5_wepcommon) and ride in
// as xmodel dependencies of the weapon, so no zone line is owed either.
//
// `ads` is '' for a port that draws ONE optic model in both poses (the
// Enfield's BO1 glass); slot 2's tag is cleared with it, because a mount tag
// naming no model is the kind of leftover v19.22 had to go back and clean up.
// ⚠️ THE OFFSET GOES ON BOTH VIEW SLOTS, AND SLOT 2 IS THE ONE THAT MATTERS.
// These ports split the optic in two: slot 1 is the HIP model and slot 2 is the
// ADS model - and the reticle is on the ADS model (the AK's ACOG carries
// `mtl_attach_t9_optic_acog_reticle` only on `..._ads_scope`). Correcting slot 1
// alone would move the scope you SEE on the gun and leave the reticle you AIM
// THROUGH exactly where it was wrong, then jump the scope the moment you ADS.
const withOptic = (hip, ads, world, tag, dz, extra) => Object.assign({
  attachViewModel1: hip,   attachViewModelTag1: tag,
  attachViewModel2: ads,   attachViewModelTag2: (ads ? tag : ''),
  attachWorldModel1: world, attachWorldModelTag1: tag,
  // the reticle-height correction that keeps the port's own ADS pose honest
  attachViewModelOffsetX1: '0',  attachViewModelOffsetY1: '0',  attachViewModelOffsetZ1: String(dz),
  attachViewModelOffsetX2: '0',  attachViewModelOffsetY2: '0',  attachViewModelOffsetZ2: (ads ? String(dz) : '0'),
  attachWorldModelOffsetX1: '0', attachWorldModelOffsetY1: '0', attachWorldModelOffsetZ1: String(dz),
}, extra || {});

const LADDER = {
  skirmisher: [
    {
      tier: 1, stem: 't6_msmc', enabled: true,    // Phase 2a (2026-08-22)
      src: T9('skye_t6_msmc.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't6_msmc', name: s => 't6_msmc' + s, up: false },
              // v19.10: PaP loses vm_t6_reflex and aims down the irons. The v18.94
              // optic pass spared the gun this one replaced, so the dot came back in
              // with the new roster. User 2026-09-15: "Pap versions have red dots and
              // i dont want that". Base forms never had an optic; only _up changes.
              { srcAsset: 't6_msmc_up', name: s => 't6_msmc_up' + s, up: true,
                // hideTags already matched the base form here - the MSMC's reflex
                // clipped onto a rail it hides in both states, so it never hid the
                // irons. Passed explicitly anyway so the contract is enforced, not
                // relied upon: a port update that changes it fails the gate.
                str: () => noOptic('am_t6_msmc_ads_up', 'am_t6_msmc_ads_down',
                                   'tag_rails\\r\\n') }],
      // SMG CLASS UPDATE (user 2026-08-23, v9.44): "Fire rate increase is
      // mac10 only. Handling is for all smgs. Magsize we can remove from
      // class." The MAC-10 is the ONLY f-ladder gun now and gains h.
      axes: ['f', 'h'],
      // Preserve DPS at the new port's own fire rate, including packed forms.
      dpsReference: { damage: 142, minDamage: 122, fireTime: 0.054, clipSize: 32,
                      upDamage: 178, upMinDamage: 153, rawDamage: 140 },
      tune: { recoil: RECOIL_BUMP, ads: ADS_BUMP, set: { clipSize: 32 }, reserveMags: 11 },
      csv: { cost: 1350, vo: 'smg', cls: 'smg' },
    },
    {
      tier: 2, stem: 't9_mp5', enabled: true,
      src: T9('skye_t9_mp5.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't9_mp5', name: s => 't9_mp5' + s, up: false },
              // v18.94: PaP loses the snappoint reflex and aims down the irons.
              // v19.22: + tag_rail, which only the base was hiding - with the
              // snappoint gone the PaP was wearing an empty optic rail.
              { srcAsset: 't9_mp5_up', name: s => 't9_mp5_up' + s, up: true,
                str: () => noOptic('am_t9_mp5_ads_up', 'am_t9_mp5_ads_down',
                                   'tag_laser_show\\r\\ntag_laser_show2\\r\\ntag_rail') }],
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
              // v18.94: PaP loses vm_t6_reflex and aims down the irons.
              // v19.22: -tag_sights. The port hid the MP7's irons under the
              // reflex, so from v18.94 to here its PaP aimed at nothing.
              { srcAsset: 't6_mp7_up', name: s => 't6_mp7_up' + s, up: true,
                str: () => noOptic('am_t6_mp7_ads_up', 'am_t6_mp7_ads_down',
                                   'tag_grip_off\\r\\n') }],
      // DARK UPGRADE RUNG (v17.10): h4 = dark HANDLING, -55% reload/swap/ADS.
      // The MP7 is the skirmisher TIER 3 gun and the only one that gets it; the
      // MAC-10 and MP5 keep h0..h3. Packed form only, so this costs ONE extra
      // registration (8 -> 9).
      axisMaxUp: { h: 4 },
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
      // v17.4: the ceiling above carries +10% for the whole class, but the user
      // singled this gun out for a NET -5% instead. dmgMult is applied AFTER
      // the cap (see the SLASHER_SEC_BUFF note), so the correction is the RATIO
      // between the two targets — 0.95 / 1.10 — never a second absolute value.
      // Written as the division so the relationship survives a retune of either
      // number; hard-coding 0.8636 would silently decouple them.
      tier: 9, stem: 't6_spas12', enabled: true, secondary: true, secTier: 3, reserveMult: 1.4,
      dmgMult: SKIRM_SPAS_NET / SKIRM_SEC_BUFF,
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
              // v19.51 (2026-09-23, user, first play of the ACOG: "the tip of the
              // ACOG is not aligned with where it actually shoots ... hard to get
              // headshots because you don't even know where the shot is going"):
              // THE PACKED ENFIELD HAS NO SIGHT, LIKE ITS BASE. v19.25 had put the
              // port's BO1 SUSAT on tag_susat under the RED DOT's ADS anims with a
              // -0.234 lens nudge (see withOptic); the user's aim disagreed with
              // that arithmetic and the call is irons on both forms. The Krig 6 and
              // AK-47 keep their ACOGs - the user named this gun. Three edits, per
              // the v19.24 rule: optic slots cleared; ADS anims = the base's iron
              // anims, up/down AND fire/last-shot (the port's `shotty_ads_fire` is
              // the red dot form's pair, so it goes with the red dot's up/down);
              // hideTags = the base's (''), so the first-person irons draw again.
              // The world model gets the base's iron-sight attachment back in the
              // free slot 2 (the port's packed form dropped it for the red dot);
              // the masterkey (slot 4) and mag (slot 5) stay as the PaP look.
              { srcAsset: 't5_enfield_up_zm', name: s => 't5_enfield_up' + s + '_zm', up: true,
                str: () => noOptic('am_t5_enfield_ads_up', 'am_t5_enfield_ads_down', '', {
                  adsFireAnim: 'am_t5_enfield_ads_fire', adsLastShotAnim: 'am_t5_enfield_ads_fire',
                  attachWorldModel2: 'wm_t5_enfield_iron_sights', attachWorldModelTag2: 'tag_iron_sights',
                }) }],
      // ASSAULT AXIS PARITY (user 2026-08-23): every assault gun carries r + m.
      axes: ['r', 'm'],
      tune: { recoil: RECOIL_BUMP, ads: ADS_BUMP, str: { altWeapon: '' } },
      csv: { cost: 1250, vo: 'rifle', cls: 'rifle' },
    },
    {
      tier: 2, stem: 't9_krig6', enabled: true,
      src: T9('skye_t9_krig_6.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't9_krig6', name: s => 't9_krig6' + s, up: false },
              // v19.25: the PaP's 1x Holoscout becomes the VisionTech 2x on
              // tag_acog_2 - same rail height as tag_holo - lowered
              // 0.181 so its reticle sits where the holo's did, which is what
              // lets `am_t9_krig6_holoscout_ads_*` stay exactly as authored.
              { srcAsset: 't9_krig6_up', name: s => 't9_krig6_up' + s, up: true,
                str: () => withOptic('vm_t9_acog_visiontech2x_hip_scope',
                                     'vm_t9_acog_visiontech2x_ads_scope',
                                     'vm_t9_acog_visiontech2x_hip_scope',
                                     'tag_acog_2', -0.181) }],
      axes: ['r', 'm'],
      // BUFF (user 2026-08-30: "Lets increase the damage of the AK and Krig by
      // 5%"). Same hook and same contract as the Death Machine's 2026-08-28
      // bump: applied AFTER the TIER_DPS normalization (which SETS
      // override.damage outright, so a tune.set here would be overwritten), and
      // the PaP form inherits it EXACTLY ONCE via papApply reading the tuned
      // base — never re-apply in the isUp branch.
      //
      // This deliberately breaks the 1 / 1.5625 / 2.4414 ladder for the two
      // upper assault rungs, which is what a per-gun bump IS. It cannot
      // propagate: every tier normalizes from T1 (the Enfield), never from the
      // tier below, so the Enfield is untouched and the AK's own normalization
      // never sees the Krig's bump.
      dmgMult: 1.05,
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
              // v19.25: the PaP's 1x Kobra becomes the VisionTech 2x on
              // tag_acog_2 - same rail height as tag_reflex - raised 0.485 so
              // its reticle sits where the Kobra's front glass did, which is
              // what `am_t9_ak47_kobra_ads_*` was authored against. This is the
              // biggest of the three lifts: if the scope reads as floating off
              // the rail in hand, zero this one first (see withOptic).
              { srcAsset: 't9_ak47_up', name: s => 't9_ak47_up' + s, up: true,
                str: () => withOptic('vm_t9_acog_visiontech2x_hip_scope',
                                     'vm_t9_acog_visiontech2x_ads_scope',
                                     'vm_t9_acog_visiontech2x_hip_scope',
                                     'tag_acog_2', 0.485) }],
      // ASSAULT AXIS PARITY (user 2026-08-23): r + m like the Enfield and Krig.
      // The p-ladder had to GO — axes multiply, and p x r x m is 3 x 4 x 4 = 48
      // combos x 2 forms = 96 registrations for this gun alone (the whole map
      // is 194). PENETRATION is heavy-only again; _tod_upgrades::set_guns
      // matches. The AK is not weaker for it: every source GDT ships
      // penetrateType "medium" and the ladder STARTED at "small".
      axes: ['r', 'm'],
      // DARK UPGRADE RUNGS (v17.10). The AK is the assault TIER 3 gun, so it is
      // the only gun carrying them, and only on its PACKED form:
      //   r3 = dark RECOIL   -60% kick  (base ladder unchanged: r0..r2, -15/-30)
      //   m4 = dark MAG SIZE +90%       (base ladder unchanged: m0..m3, +20%/Lv)
      //
      // ⚠️ BOTH AXES EXTEND, WHICH IS THE WHOLE POINT — a player can hold BOTH
      // dark upgrades at once, so the packed form must contain r3m4. Adding the
      // two rungs as one-off variants instead of raising both ceilings would
      // leave that one combination with no asset behind it, and twin_suffix
      // would build a name that does not link: the player keeps their old gun
      // forever while the pause menu reports both upgrades. Cartesian, always.
      //
      // Cost: base 3x4 = 12, packed 4x5 = 20, so 32 against 24 — eight more,
      // paid for many times over by the Enfield and Krig 6 dropping r.
      axisMaxUp: { r: 3, m: 4 },
      // BUFF (user 2026-08-30: "Lets increase the damage of the AK and Krig by
      // 5%") — see the Krig's note above for the full contract. Independent of
      // the Krig's bump: this gun normalizes from the Enfield T1, not from the
      // Krig, so the two 1.05s do not compound into 1.1025 on the AK.
      dmgMult: 1.05,
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
      // DAMAGE x2 (user 2026-08-28: "The RPG needs a 100% damage buff. Base and
      // pap."). Applied AFTER the SEC_CAP_REL ceiling in computeSecondaryOverrides
      // — the cap is what was holding this gun at 563 against a port that ships
      // 7000, and a buff placed before it would have been clamped straight back
      // to 563 and read as "the knob did nothing".
      // BOTH HALVES MOVE: direct `damage` 563 -> 1126 base / 704 -> 1408 PaP, AND
      // the two explosion-damage keys x2, because on a launcher the splash is
      // what actually kills and the direct hit is the number almost nobody lands
      // (the reasoning already written at EXPLOSION_KEYS). explosionRadius is NOT
      // in that key set, so the blast hits twice as hard over the SAME 250 units.
      // SELF-DAMAGE SCALES WITH IT — the 2026-08-24 note below records that the
      // user was shown the self-damage risk on a narrow spiral staircase and said
      // to proceed; that risk is now doubled at the same radius.
      tier: 9, stem: 't6_rpg', enabled: true, secondary: true, secTier: 2, reserveMult: 1.2, dmgMult: 2.0,
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
      // NERFED 2026-09-09 — see the NAIL_* block near KRIG_FIRE_SCALE for why
      // dmgMult is 0.765 and not 0.85. Base and PaP both move; the PaP form
      // derives from the tuned base.
      tier: 9, stem: 't9_nail_gun', enabled: true, secondary: true, secTier: 3, reserveMult: 1.4,
      dmgMult: NAIL_DMG_MULT, clipMult: NAIL_CLIP_NERF,
      src: T9('skye_t9_nail_gun.gdt'), gdf: 'projectileweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't9_nail_gun',    name: s => 't9_nail_gun' + s,    up: false },
              { srcAsset: 't9_nail_gun_up', name: s => 't9_nail_gun_up' + s, up: true,
                // EXPLOSION OFF (user 2026-09-01: "take away the explosion fx on the
                // pap nail gun"). The port dresses the PaP form as a launcher —
                // impactType grenade_explode, a rocket-burst efx, the grenade boom and
                // a 0.5 camera shake — over ZERO explosion damage, so it was pure
                // presentation. Blanked back to the base form's bolt impact; damage,
                // clip and the pap shot sound are untouched. Per-form by construction
                // (form.str), since the base form never had any of it.
                //
                // RED DOT OFF (2026-09-23, user: "take the red dot off of the nail
                // gun. Both base and pap" -> "I only saw it on pap. Just make sure
                // its on neither"). Only this _up form carried one: the port's
                // Microflex reflex on tag_reflex (slots 1+2) plus its own
                // am_t9_nailgun_microflex_ads_* pair. The base form has no optic
                // in any slot and no reticle/lens material on vm_t9_nailgun. All
                // three noOptic() edits: slots cleared, ADS back to the base form's
                // own am_t9_nailgun_ads_* pair, and the sight tags become the
                // base form's (it hides tag_rail, the optic mount). Gated by
                // tools/test_no_optics.js.
                str: s => noOptic('am_t9_nailgun_ads_up', 'am_t9_nailgun_ads_down', 'tag_rail\\r\\n',
                           { impactType: 'bolt', projExplosionEffect: '', projExplosionSound: '',
                             projExplosionSoundPlayer: '', explosionCameraShakeDuration: '0',
                             explosionCameraShakeRadius: '0', explosionCameraShakeScale: '0' }) }],
      axes: [],
      tune: { fire: NAIL_RATE_NERF },
      csv: { cost: 500, vo: 'lmg', cls: 'lmg' },
    },
    {
      tier: 1, stem: 't6_mk48', enabled: true,
      src: T9('skye_t6_mk48.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't6_mk48', name: s => 't6_mk48' + s, up: false },
              // v19.10: PaP loses vm_t6_reflex and aims down the irons. The v18.94
              // optic pass spared the gun this one replaced, so the dot came back in
              // with the new roster. User 2026-09-15: "Pap versions have red dots and
              // i dont want that". Base forms never had an optic; only _up changes.
              // v19.22: -tag_sights, same hidden-irons bug as the MP7. The
              // foregrip (slot 4) and its whole am_t6_mk48_grip_* anim family
              // stay - the grip is not a sight, and the port has no grip+reflex
              // ADS-fire variant, so that pose was always the irons pose.
              { srcAsset: 't6_mk48_up', name: s => 't6_mk48_up' + s, up: true,
                str: () => noOptic('am_t6_mk48_ads_up', 'am_t6_mk48_ads_down',
                                   '\\r\\n') }],
      axes: ['p'],
      dpsReference: { damage: 215, minDamage: 194, fireTime: 0.075, clipSize: 60,
                      upDamage: 269, upMinDamage: 243, rawDamage: 265 },
      // Match the old Stoner total reload duration; scale Mk 48 ammo-add beats
      // proportionally so they stay aligned with its own animation/foley.
      tune: { recoil: RECOIL_BUMP, ads: ADS_BUMP, reload: 6.6 / 8.0, set: { clipSize: 60 }, reserveMags: 6 },
      csv: { cost: 1500, vo: 'lmg', cls: 'lmg' },
    },
    {
      tier: 2, stem: 't5_hk21', enabled: true,    // Phase 2c (2026-08-22)
      src: T9('skye_t5_hk21.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't5_hk21', name: s => 't5_hk21' + s, up: false },
              // v18.94: PaP loses the aimpoint reflex AND the world-model scope
              // rail it was mounted on (slot 4) - clearing only the optic would
              // leave an empty rail standing on the dropped/third-person gun.
              // v19.22: the HK21 carries TWO iron sights - a tall `tag_iron_sight`
              // and a low `tag_iron_sight_short` that clears an optic. The port's
              // PaP hid the tall one and showed the short one plus the rail; the
              // base does the opposite and its ADS anim, which the PaP now uses,
              // aims at the TALL one. So the sight tags become the base's, and
              // tag_clip stays because the extended mag still covers it.
              { srcAsset: 't5_hk21_up', name: s => 't5_hk21_up' + s, up: true,
                str: () => noOptic('am_t5_hk21_ads_up', 'am_t5_hk21_ads_down',
                                   'tag_clip\\r\\ntag_scope_rail\\r\\ntag_iron_sight_short',
                                   { attachWorldModel4: '', attachWorldModelTag4: '' }) }],
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
      // BUFF (user 2026-08-28: "give the death machine one extra mag and 5% more
      // damage. Base and pap version."). Both knobs land on the BASE form and
      // the PaP form inherits each exactly once — damage through papApply
      // reading the tuned base, magazines through PAP_COPY_KEYS (factor 1) — so
      // neither is re-applied in baseTune's isUp branch. Re-applying either
      // there is the double-count trap RESERVE_ADD's note 2 documents.
      //   damage   350 -> 368 base, 438 -> 460 PaP
      //   reserve    3 -> 4 magazines on both forms
      // This gun was already the roster's thinnest on ammo (3 magazines against
      // the RPG's 25), which is why the magazine is additive and per-gun rather
      // than a reserveMult.
      dmgMult: 1.05,
      reserveAdd: 1,
      // SPIN ON ADS (user 2026-09-01: "charge with aim button so you can prep
      // shots ... and shoot right away"). spinMinigunOnADS is a real GDF field
      // (0 in the port); with it on, holding AIM spins the barrels through the
      // 0.25 s spinUpTime so the trigger fires instantly. gun.tune.str writes it
      // to base AND PaP alike, which is what is wanted here. spinDownTime 0.5.
      // v16.58 (user 2026-09-02: "we tried to fix aiming to start up the death
      // machine but doesnt work"): the v16.6 flag could never fire because the
      // port ships aimDownSight 0 — bulletweapon.awi: "Must be turned on for
      // ... a weapon that can be Aimed Down the Sight" — so the engine never
      // entered ADS and "spin on ADS" had nothing to hook. aimDownSight 1 turns
      // the aim button into a real ADS (the port carries am_t6_death_machine_
      // ads_up/_down and both are packed); keepCrosshairWhenADS 1 because the
      // ADS pose has no sight to look down. adsFire stays 0 (hip fire allowed).
      tune: { recoil: RECOIL_BUMP, ads: ADS_BUMP, str: { spinMinigunOnADS: '1', aimDownSight: '1', keepCrosshairWhenADS: '1' } },
      csv: { cost: 5000, vo: 'lmg', cls: 'lmg' },
    },
  ],
  // Mage: three independent staffs, each with q0/q1 Mystical Hands handling.
  // PaP damage remains in script. Its model/flourish is the neutral gmod6
  // attachment (source_data/tod_staff_pap.gdt), shared by both handling roots.
  // Six registered weapons total; do not add a second packed weapon roster.
  mage: [
    // v18.30 THE REVAMP: the three rungs are THREE STAFFS HELD TOGETHER
    // (lightning -> +fire -> +ice), so `flat: true` on tiers 2 and 3 -- NO
    // TIER_DPS normalization. A tier-3 mage holds all three, and its lightning
    // staff must hit as hard as its ice staff; the class TIER scales every
    // staff in script instead (_tod_mage_elements TOD_MAGE_TIER2/3_MULT, the
    // SAME 1 / 1.5625 / 2.4414 ladder -- LOCKSTEP PAIR with TIER_DPS).
    // 2026-09-23: THE STAFF ASSETS CARRY THE ENGINE'S _zm TAIL, LIKE EVERY OTHER
    // WEAPON IN THE GAME. The packed look (gmod6 attachment: upgraded head +
    // first-raise flourish, docs/150) never rendered: the linker's own .deps
    // file showed every `weaponfull,leviathan*_zm` pulling its gmod7 uniques in
    // and every `weaponfull,tod_staff_*` (the map's only unsuffixed weapons)
    // pulling NOTHING from the same mapping table, and stock connects gmod
    // uniques to _zm/_mp-named projectile weapons (launchers, crossbow). The
    // linker derives its table key from the mode tail; a name without one never
    // matches its own row. Script names, CSV keys and the mapping rows stay
    // unsuffixed (the engine strips _zm, weapon_or_zm tolerates it, and
    // verify_weapon_attachments removesuffix()es it) - only the ASSET is tailed.
    { tier: 1, stem: 'tod_staff_lightning', enabled: MAGE_ON,
      src: path.join(REPO, 'source_data', 'tod_staff.gdt'), gdf: 'projectileweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 'tod_staff_lightning', name: s => 'tod_staff_lightning' + s + '_zm', up: false }],
      axes: ['q'], tune: {},
      csv: { cost: 3000, vo: 'wpck_ray', cls: 'special' } },
    { tier: 2, stem: 'tod_staff_fire', enabled: MAGE_ON, flat: true,
      src: path.join(REPO, 'source_data', 'tod_staff.gdt'), gdf: 'projectileweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 'tod_staff_fire',      name: s => 'tod_staff_fire' + s + '_zm',      up: false }],
      axes: ['q'], tune: {},
      csv: { cost: 3000, vo: 'wpck_ray', cls: 'special' } },
    // v19.25: the ice staff is the ONLY gun in the map with a two-letter axis
    // where one letter is a PERK. q x d = 4 assets instead of 2 (+2 on the
    // ledger, which is why LEDGER_GUARD moved to 237). Both letters have to be
    // real: a mage can hold MYSTICAL HANDS and Double Tap at the same time, so
    // q1d1 must exist or twin_suffix builds a name that does not link and the
    // player keeps the staff they had while the HUD says otherwise.
    { tier: 3, stem: 'tod_staff_ice', enabled: MAGE_ON, flat: true,
      src: path.join(REPO, 'source_data', 'tod_staff.gdt'), gdf: 'projectileweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 'tod_staff_ice',       name: s => 'tod_staff_ice' + s + '_zm',       up: false }],
      axes: ['q', 'd'], tune: {},
      csv: { cost: 3000, vo: 'wpck_ray', cls: 'special' } },
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
      tier: 9, stem: 'iw7_udm', enabled: true, secondary: true, secTier: 2, reserveMult: 1.2 * SLASHER_SEC_BUFF, dmgMult: SLASHER_SEC_BUFF, clipMult: SLASHER_SEC_BUFF,   // v16.12 +25% x5
      // VENDORED (v16.12): the port GDT lives in the REPO now, same filename, so the
      // sync owns the root copy. Two edits ride in it: the 2026-08-28 reflex-slot
      // remaps (root-only until now, backup skye_iw7_udm.gdt.tod-reflex-orig at
      // the root) and v16.12's SIGHT REMOVAL - every reflex_* slot on all four UDM
      // meshes maps to `tod_clear` (source_data/tod_materials.gdt, a fully
      // transparent lit_transparent material over a 16x16 alpha-0 png). The grey
      // square on ADS was the sight: the port's reflex_stencil_outline slot landed
      // on a reticle_dynamic material with NO colorMap, and the lens glass sat
      // under it. Map 1 never referenced this port, so vendoring it is cross-map safe.
      src: path.join(REPO, 'source_data', 'skye_iw7_udm.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      // ⚠️ v19.24 (2026-09-21): THE "UDM HAS ADS ISSUES" REPORT, AND IT IS THE
      // SAME DEFECT AS THE MP7 / Mk 48 / HK21 ABOVE - HALF A SIGHT REMOVAL.
      //
      // v16.12 removed the grey square by painting every reflex slot with
      // `tod_clear`, which makes the red dot INVISIBLE. It never touched the ADS
      // animation, so the packed UDM kept raising to `am_iw7_udm_reflex_ads_up` -
      // the OPTIC's eye height - with nothing drawn there. The player aims and
      // the sight picture is empty, which is the report.
      //
      // The base form has always used the irons pair and has always been fine,
      // which is both the proof the pair works and the model for what the PaP
      // should do. hideTags is '' on both forms, so no sight was ever hidden
      // here - this gun needs the anim half of noOptic() only.
      forms: [{ srcAsset: 'iw7_udm',    name: s => 'iw7_udm' + s,    up: false },
              { srcAsset: 'iw7_udm_up', name: s => 'iw7_udm_up' + s, up: true,
                str: () => noOptic('am_iw7_udm_ads_up', 'am_iw7_udm_ads_down', '') }],
      axes: [],
      tune: { fire: 1 / SLASHER_SEC_BUFF, reload: SLASHER_SEC_RELOAD_MULT / SLASHER_SEC_BUFF },   // v16.12: +25% fire rate, -20% reload times; 2026-10-04: reload x1.3 (SLASHER_SEC_RELOAD_MULT)
      csv: { cost: 500, vo: 'pistol', cls: 'pistol' },
    },
    {
      // RK7 GARRISON (BO4) — slasher secondary T3. The ASSET is `t8_rk7`; only
      // the GDT FILE carries the `_garrison`. A fast auto pistol (fireTime
      // 0.066), which is why the slasher line ends here: the class that has to
      // close distance gets the sidearm that covers the walk.
      tier: 9, stem: 't8_rk7', enabled: true, secondary: true, secTier: 3, reserveMult: 1.4 * SLASHER_SEC_BUFF, dmgMult: SLASHER_SEC_BUFF, clipMult: SLASHER_SEC_BUFF,   // v16.12 +25% x5
      src: T9('skye_t8_rk7_garrison.gdt'), gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't8_rk7',    name: s => 't8_rk7' + s,    up: false },
              { srcAsset: 't8_rk7_up', name: s => 't8_rk7_up' + s, up: true }],
      axes: [],
      tune: { fire: 1 / SLASHER_SEC_BUFF, reload: SLASHER_SEC_RELOAD_MULT / SLASHER_SEC_BUFF },   // v16.12: +25% fire rate, -20% reload times (burstFireDelay is not a FIRE_KEY, same as PaP); 2026-10-04: reload x1.3
      csv: { cost: 500, vo: 'pistol', cls: 'pistol' },
    },
    {
      // pmr360 BOCW Baseball Bat. Full port presentation, original T1 damage.
      // Replaces the knife without extra slots.
      // NO LUNGE SINCE 2026-10-02 (user: "i think we need to remove the lunge on
      // the bat. We tried to fix multiple times where we can animate out of the
      // lunge if we have a swing ready ... but just doesnt seem we can solve"):
      // `lunge: false` puts the bat on the roster-wide MELEE_NO_LUNGE
      // (meleeChargeRange 0 = no charge-toward-target, meleeLungeRange 0 = no
      // step), so every swing is the plain meleeAnim swing and a second press
      // never waits out a charge. The charge/fatal timings in `set` below are
      // kept (harmless with no charge; the k-ladder still scales them).
      // The INSPECT came back the same day on the LOW-READY lane
      // (_tod_bat_inspect.gsc) - the reload lane stays one-frame (item 5 below).
      tier: 1, stem: 't9_me_baseballbat', enabled: true, melee: true, lunge: false,
      src: path.join(REPO, 'source_data', 'tod_baseball_bat.gdt'),
      gdf: 'bulletweapon.gdf', encoding: 'utf8',
      forms: [{ srcAsset: 't9_me_baseballbat_zm',    name: s => 't9_me_baseballbat' + s + '_zm', up: false },
              { srcAsset: 't9_me_baseballbat_up_zm', name: s => 't9_me_baseballbat_up' + s + '_zm', up: true }],
      axes: ['k'],
      tune: { ads: ADS_BUMP, set: { meleeChargeTime: 0.23, meleeLeftChargeTime: 0.23, meleeChargeFatalTime: 0.6, meleeLeftChargeFatalTime: 0.6 } }, // knife balance, bat presentation
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
      // DARK UPGRADE RUNG (v17.10): k6 = dark KNIFE SPEED, -46% swing time.
      // The Stormbreaker is the slasher TIER 3 blade and the only one that gets
      // it; the Combat Knife and Wakizashi keep k0..k5. Packed form only, so
      // this costs ONE extra registration (12 -> 13).
      axisMaxUp: { k: 6 },
      // HUD NAME (user 2026-08-23: "change the name of the leviathan axes to
      // stormbreaker ... Both base and pap version"). The port ships as
      // "Leviathan Axe" / "Colossal Headtaker", which is what the weapon HUD was
      // printing while every menu we author already called it the STORMBREAKER.
      // Fixed HERE rather than in the .gdt because the .gdt is generated — a
      // hand-edit there dies at the next regen.
      tune: { ads: ADS_BUMP, name: 'Stormbreaker', nameUp: 'Stormbreaker EX',
              str: { attachmentUnique: 'au_tod_thunder_smash' } },
      csv: { cost: 3000, vo: 'wpck_bowie', cls: 'special', melee: true },
    },
  ],
};

// Emission ORDER = the order the shipped v1 table used (mp5, krig, stoner,
// knife) so a no-ladder-change regen diffs clean; new guns append after.
const EMIT_ORDER = ['t9_mp5', 't9_krig6', 't6_mk48', 't9_me_baseballbat'];

// ---- machinery (ported) ----------------------------------------------------
function fmt(n, precision = 4) {
  if (Number.isInteger(n)) return String(n);
  return parseFloat(n.toFixed(precision)).toString();
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

function scaleSets(line, sets, precision = 4) {
  const m = line.match(/^(\s*)"([A-Za-z0-9_]+)"\s+"(-?\d+(?:\.\d+)?)"\s*$/);
  if (!m) return line;
  const [, indent, key, valStr] = m;
  for (const [keys, factor] of sets) {
    if (factor !== 1 && keys.has(key)) {
      const v = parseFloat(valStr);
      if (v === 0) return line;   // 0 stays 0
      // INT_KEYS (clip/ammo/damage): the engine wants whole rounds — round, never truncate
      const scaled = INT_KEYS.has(key) ? Math.round(v * factor) : v * factor;
      return `${indent}"${key}" "${fmt(scaled, precision)}"`;
    }
  }
  return line;
}

// scaleSets' additive twin — same line contract, same first-match-wins rule,
// same 0-guard. The 0-guard is load-bearing here in a way it is not for a
// multiplier: x1.3 leaves a blade's 0 magazines at 0 all by itself, but +1 would
// hand every knife in the map a magazine of ammunition it has no weapon to fire.
// Values are whole magazines already, so the INT_KEYS rounding scaleSets needs
// has nothing to do — Math.round is kept only so a fractional source value
// (none today) could never emit a float into an INT-typed field.
function addSets(line, sets) {
  const m = line.match(/^(\s*)"([A-Za-z0-9_]+)"\s+"(-?\d+(?:\.\d+)?)"\s*$/);
  if (!m) return line;
  const [, indent, key, valStr] = m;
  for (const [keys, delta] of sets) {
    if (delta !== 0 && keys.has(key)) {
      const v = parseFloat(valStr);
      if (v === 0) return line;   // 0 stays 0 — melee forms carry no reserve
      const added = INT_KEYS.has(key) ? Math.round(v + delta) : v + delta;
      return `${indent}"${key}" "${fmt(added)}"`;
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
    // Class handling (hip cone / ADS move): papApply leaves both keys at the
    // port's _up value, so this is their one application on the PaP form.
    {
      const ch = classHandlingSets(gun);
      if (ch.length) l = scaleSets(l, ch);
      l = adsMovePin(l, gun);
    }
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
    // (per-gun dmgMult folded into the SAME factor for the same first-match-wins
    // reason as the base branch — and it must be here too, because explosion
    // keys are in no papFactor set, so without this line the _up form keeps the
    // raw PORT splash and a buffed base would ship a WEAKER Pack-a-Punched
    // launcher than its own base form. That exact inversion is the 2026-08-24
    // bug recorded above; this is the same hazard from the other direction.)
    {
      const explUp = (gun.secondary ? SECONDARY_DMG_MULT : 1) * (gun.dmgMult || 1);
      if (explUp !== 1) l = scaleSets(l, [[EXPLOSION_KEYS, explUp]]);
    }

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
    // ...and the +1 MAGAZINE, for the same reason and with the opposite verdict
    // to the paragraph above. RESERVE_MULT stays out of this branch because it
    // was a map-wide economy default that had never reached a papKeepSource _up
    // form; RESERVE_ADD goes IN because the user asked for one extra magazine on
    // ALL guns by name (2026-08-26), and without this line the Magnum's PaP form
    // is the single asset in the map that does not get it. Every other _up form
    // inherits the magazine through papApply/PAP_COPY_KEYS, which this branch
    // bypasses — so this is not a second application, it is the only one.
    // gun.reserveAdd rides along for the same reason and by the same rule (one
    // summed delta — addSets is first-match-wins). No papKeepSource gun sets it
    // today; carrying it here is what stops the next one silently missing its
    // per-gun magazine on the PaP form, which is the exact bug this branch
    // exists to fix for RESERVE_ADD.
    if (gun.papKeepSource && (RESERVE_ADD + (gun.reserveAdd || 0)) !== 0)
      l = addSets(l, [[RESERVE_KEYS, RESERVE_ADD + (gun.reserveAdd || 0)]]);
    if (gun.tune.str) l = strSet(l, gun.tune.str);
    // 2026-10-01 (docs/167 items 5 + 6): the blades' inspect off the reload lane
    // (the one-frame reload TIMES arrive through papApply from the tuned base),
    // and the queue window, which papApply does not carry.
    if (gun.melee) {
      l = strSet(l, MELEE_NO_INSPECT_STR);
      l = absSet(l, { meleeQueueMeleeEarlyTime: MELEE_QUEUE_EARLY });
    }
    // v10.23: was `if (gun.melee)`, which left meleeChargeRange 120 on all 136
    // non-melee emitted assets — every bullet weapon still LUNGED on a gun bash,
    // despite the roster-wide "remove the lunge swing" pass. That pass only ever
    // reached the blades. meleeLungeRange is already 0 on the ports; this zeroes
    // the charge lunge too. The bash itself is unaffected — it still connects at
    // meleeRange, exactly as it does on the blades, which have run at 0 since
    // that pass shipped.
    if (!gun.lunge) l = strSet(l, MELEE_NO_LUNGE);
    l = nameSet(gun, l, true);
    return l;
  }
  const set = Object.assign({ moveSpeedScale: 1 }, LOC_NORM, gun.tune.set || {});
  // 2026-10-01 (docs/167 items 5 + 6): every blade - one-frame reload (its
  // inspect is off the reload lane, MELEE_NO_INSPECT_STR below) and the wider
  // melee queue window. Before the scale sets, like every other absolute.
  if (gun.melee) Object.assign(set, MELEE_NO_INSPECT_SET, { meleeQueueMeleeEarlyTime: MELEE_QUEUE_EARLY });
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
  if (gun.melee) sets.push([MELEE_KEYS, SLASHER_SWING_MULT]);   // v19.63b: every blade swings 10% faster (see the constant)
  if (gun.tune.reload) sets.push([RELOAD_KEYS, gun.tune.reload]);   // v16.12: every reload time; the PaP form inherits it through computePapSet (PAP_TRIM on the TUNED base)
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
  // ...AND the per-gun dmgMult rides the SAME factor, never a second push:
  // scaleSets is first-match-wins, so a separate [EXPLOSION_KEYS, x] entry
  // would be silently dropped (the identical trap reserveAdd documents).
  // The guard is no longer secondary-only — a PRIMARY with splash and a
  // dmgMult would otherwise get its direct hit buffed and its splash left
  // behind. EXPLOSION_KEYS holds only explosionInner/OuterDamage;
  // explosionRadius is deliberately NOT in it, so this scales how hard the
  // blast hits and never how far it reaches.
  const secExpl = gun.secondary ? SECONDARY_DMG_MULT : 1;
  const explMult = secExpl * (gun.dmgMult || 1);
  if (explMult !== 1)
    sets.push([EXPLOSION_KEYS, explMult]);
  sets.push(...classHandlingSets(gun));   // hip cone (key set disjoint from the rest)
  if (sets.length) l = scaleSets(l, sets);
  l = adsMovePin(l, gun);
  // +1 MAGAZINE, AFTER every reserve multiplier (RESERVE_ADD's header). Order is
  // the contract: round(src x mults) + 1, never (src + 1) x mults, or the class
  // knob would quietly turn one magazine into 1.3 of one.
  // gun.reserveAdd is the PER-GUN extra magazine (the Death Machine's +1), and
  // it is SUMMED INTO THE SAME DELTA rather than pushed as a second entry:
  // addSets is first-match-wins exactly like scaleSets, so a second
  // [RESERVE_KEYS, x] would be silently dropped. Additive, not multiplicative,
  // for the reason in RESERVE_ADD's header — reserves here run 2 to 24
  // magazines, so a factor that helps the 2 hands the 24 a fistful.
  const radd = RESERVE_ADD + (gun.reserveAdd || 0);
  if (radd !== 0) l = addSets(l, [[RESERVE_KEYS, radd]]);
  // Starter replacements retain the previous emitted reserve AFTER global/class
  // multipliers. PaP copies these tuned values through PAP_COPY_KEYS.
  if (gun.tune.reserveMags !== undefined)
    l = absSet(l, { maxAmmo: gun.tune.reserveMags, startAmmo: gun.tune.reserveMags });
  if (gun.tune.str) l = strSet(l, gun.tune.str);
  if (gun.melee) l = strSet(l, MELEE_NO_INSPECT_STR);   // 2026-10-01: inspect off the reload lane (docs/167 item 5)
  if (!gun.lunge) l = strSet(l, MELEE_NO_LUNGE); // Bat alone retains its authored lunge.
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
    // Staff thirds need five decimals (0.28125 / 3 = 0.09375).
    else l = scaleSets(l, ax.sets.map(([keys, steps]) => [keys, steps[lv]]), letter === 'q' ? 5 : 4);
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
// PER-GUN AXIS CEILING (v17.10). `gun.axisMax = { m: 4 }` raises (or lowers)
// how many rungs THIS gun gets on that axis, instead of every gun that carries
// it. Added for the DARK UPGRADES: the user's rule is that a dark twin exists
// only on the class's TIER 3 gun, so the AK-47 needs an m4 the Enfield and Krig
// 6 must not have, the MP7 an h4 the MAC-10 and MP5 must not have, and the
// Leviathan a k6 the other two blades must not have.
//
// WITHOUT THIS THE FEATURE IS UNAFFORDABLE: raising AXIS.m.levels globally adds
// a rung to all three assault guns (+18 registrations, against a guard with 4
// free) to buy one that only the AK can ever use.
// `gun.axisMaxUp = { m: 4 }` raises that axis by the DARK rung on the PACKED
// form ONLY. Two user rules stack here (2026-09-04): a dark twin exists only on
// the class TIER 3 gun, and only on its Pack-a-Punch version.
//
// FORM-AWARE ON PURPOSE. The base form must NOT carry the rung, or half the
// saving disappears and an un-packed player could be handed a variant that
// exists but should not.
function axisLevels(gun, letter, isUp) {
  if (isUp && gun.axisMaxUp && typeof gun.axisMaxUp[letter] === 'number')
    return gun.axisMaxUp[letter];
  return AXIS[letter].levels;
}

function variantsOf(gun, isUp) {
  if (!gun.axes.length) return [{ suffix: '_b', levels: {} }];
  let combos = [{}];
  for (const letter of gun.axes) {
    const next = [];
    for (const c of combos)
      for (let lv = 0; lv <= axisLevels(gun, letter, isUp); lv++)
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
      if (gun.dpsReference) {
        const ref = gun.dpsReference;
        const ratio = readNum(raw, 'fireTime') / ref.fireTime;
        gun.override.damage = Math.round(ref.damage * ratio);
        gun.override.minDamage = Math.round(ref.minDamage * ratio);
        gun.tune.setUp = Object.assign({}, gun.tune.setUp, {
          damage: Math.round(ref.upDamage * ratio),
          minDamage: Math.round(ref.upMinDamage * ratio),
        });
      }
      // the tuned base WITHOUT tier overrides (override is still {} here)
      const tuned = raw.split(/\r?\n/).map(l => baseTune(gun, l, false)).join('\n');
      const damage = readNum(tuned, 'damage');
      const minDamage = readNum(tuned, 'minDamage');
      const fireTime = readNum(tuned, 'fireTime');
      const clip = readNum(tuned, 'clipSize');
      if (gun.tier === 1) {
        // The replacement's integer rounding and larger magazine must not
        // rebalance later tiers or their sidearm ceilings.
        t1 = gun.dpsReference || { damage, fireTime };
        // BULLET PRIMARY T1 -> the DPS the secondary cap is computed from.
        // shotCount belongs in it for the same reason it belongs in the
        // secondary math: `damage` is PER PROJECTILE. No primary is a shotgun
        // today, so every one of these is x1 — recording it anyway is what stops
        // a future shotgun primary silently capping its class's sidearms 8x too
        // low.
        // capDps — THE BASIS THE SECONDARY CEILING USES, recorded separately so
        // a primaries-only knob cannot move the sidearms (v14.32). It is derived
        // by UNDOING CLASS_DAMAGE_MULT and re-applying CLASS_SEC_CAP_MULT on the
        // damage BEFORE it was rounded to an integer. Doing it here rather than
        // scaling p.dps at the cap site matters: `damage` is already rounded, so
        // multiplying it back up by 1.3225/1.19025 overshot and moved the
        // SPAS-12 from 128 to 129 — a gun the order excluded. Absent entry =
        // capDps is dps, i.e. the default coupling, exactly as before.
        const shotC = readNum(tuned, 'shotCount') || 1;
        const dps = t1.damage * shotC / t1.fireTime;
        let capDps = dps;
        if (CLASS_SEC_CAP_MULT[cls]) {
          // Re-derive from the RAW PORT damage, applying the pinned multiplier
          // and rounding exactly as baseTune's DAMAGE_KEYS scale does. Going
          // back to `raw` is what makes this exact: `damage` above is already
          // rounded at the NEW multiplier, and un-dividing it lands between
          // integers (167/1.19025x1.3225 = 185.55 -> 186, against a true 185),
          // which moved the SPAS-12 128 -> 129. A gun the order excluded must
          // come back byte-identical, so the basis is reconstructed, not scaled.
          const rawDmg = gun.dpsReference?.rawDamage ?? readNum(raw, 'damage');
          if (rawDmg) capDps = Math.round(rawDmg * CLASS_SEC_CAP_MULT[cls]) * shotC / (gun.dpsReference?.fireTime || fireTime);
        }
        PRIMARY_T1[cls] = { dps, capDps };
        prevClip = gun.dpsReference?.clipSize || clip;
        continue;
      }
      if (!t1) {
        console.log(`  note: ${gun.stem} (tier ${gun.tier}) emitted UN-normalized — the ${cls} T1 gun is not enabled yet`);
        prevClip = clip;
        continue;
      }
      // FLAT RUNG (v18.30, the mage's staffs): held TOGETHER with T1, not
      // instead of it, so it ships the source block's own damage and clip --
      // no TIER_DPS, no never-shrink floor. The class tier scales it in script.
      if (gun.flat) {
        console.log(`  tier ${gun.tier} ${gun.stem}: FLAT (held with T1; no normalization)`);
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
      // PER-GUN DAMAGE BUMP, applied AFTER the DPS normalization for the same
      // reason clipMult is applied after the clip floor: normalization SETS
      // override.damage outright, so a tune.set or a scaleSets factor upstream
      // would simply be overwritten by the line above. This is the only hook on
      // a T2/T3 primary that survives.
      //
      // DELIBERATELY BREAKS THE TIER_DPS RELATIONSHIP for this one gun — that is
      // what a per-gun bump IS. Everything else on the ladder is unaffected:
      // each tier normalizes from `t1`, never from the previous tier, so unlike
      // clipMult (which feeds prevClip) this cannot propagate. If a whole class
      // needs moving, use CLASS_DAMAGE_MULT on its T1 instead and let
      // normalization carry it up — that keeps 1 / 1.5625 / 2.4414 intact.
      //
      // THE PaP FORM INHERITS IT EXACTLY ONCE, so never re-apply it in the isUp
      // branch: papApply reads the TUNED base (which carries override.damage)
      // and multiplies by PAP_UP. Same contract as RESERVE_ADD's note 2.
      if (gun.dmgMult && gun.dmgMult !== 1) {
        gun.override.damage = Math.round(gun.override.damage * gun.dmgMult);
        if (gun.override.minDamage !== undefined)
          gun.override.minDamage = Math.round(gun.override.minDamage * gun.dmgMult);
        console.log(`  tier ${gun.tier} ${gun.stem}: per-gun dmgMult x${gun.dmgMult} -> damage ${gun.override.damage}`);
      }
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
        // CAP BASIS — p.capDps, recorded at the T1 site. It equals p.dps unless
        // the class has a CLASS_SEC_CAP_MULT entry pinning the ceiling above a
        // primaries-only knob (v14.32). Read capDps, never dps, or a
        // primary-only nerf drags every sidearm down with it.
        const capDps = (p.capDps !== undefined) ? p.capDps : p.dps;
        // primary DPS one tier below -> this gun's damage per projectile
        capDmg = Math.max(1, Math.round(capDps * SEC_CAP_REL[gun.secTier] * fireTime / shot));
        if (!SEC_CAP_ONLY || dmg > capDmg) dmg = capDmg;
      }
      const capped = capDmg !== undefined && dmg === capDmg && capDmg < ladder;

      // PER-GUN DAMAGE BUMP ON A SECONDARY — APPLIED AFTER THE CEILING, and the
      // order is the whole point. SEC_CAP_REL exists to stop a sidearm out-DPSing
      // the primary line, but an explicit per-gun instruction has to be able to
      // WIN over it or the knob is a silent no-op: clamp first, buff second.
      // Exactly the same argument as clipMult-after-the-clip-floor above.
      //
      // `dmg` itself is scaled, not just gun.override.damage, because the PaP
      // pin a few lines down derives from this local (Math.round(dmg * PAP_UP))
      // and minDamage derives from it too. Scaling only the override would leave
      // the Bulldog/Magnum pins on the pre-buff number.
      //
      // SPLASH IS SCALED SEPARATELY, IN baseTune — see the EXPLOSION_KEYS push
      // there. It has to be, because explosion damage never passes through this
      // normalization at all (EXPLOSION_KEYS is deliberately not in DAMAGE_KEYS),
      // and on a launcher the splash IS the damage. A dmgMult that moved only
      // `damage` would be a rounding error on the RPG.
      if (gun.dmgMult && gun.dmgMult !== 1) {
        dmg = Math.round(dmg * gun.dmgMult);
        console.log(`  sec ${gun.stem}: per-gun dmgMult x${gun.dmgMult} (after cap) -> damage ${dmg}`);
      }

      gun.override.damage = dmg;
      if (minDamage !== undefined && minDamage !== 0 && damage)
        gun.override.minDamage = Math.round(dmg * minDamage / damage);

      // SIDEARM CLIP (v16.12). computeTierOverrides skips secondaries before its
      // clipMult line, so a sidearm clipMult had no seat until now. Applied to the
      // TUNED base clip; the PaP form derives round(clip x PAP_UP) from this via
      // computePapSet, so base and PaP both move. No CLIP_STEP floor here - that
      // is a primary-ladder promise.
      if (gun.clipMult && gun.clipMult !== 1) {
        const clip = readNum(tuned, 'clipSize');
        if (clip) {
          gun.override.clipSize = Math.round(clip * gun.clipMult);
          console.log(`  sec ${gun.stem}: clipMult x${gun.clipMult} -> clipSize ${clip} -> ${gun.override.clipSize}`);
        }
      }

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

// =============================================================================
// PACK III CAMO — THE TABLE-COPY LANE (v17.89, 2026-09-05; CAMO_PAP3_TABLE)
//
// User: "making one camo for the map ... sick and cyber colorful for 3rd pap".
// Every packed twin gets ITS OWN COPY of its port's weaponcamotable in which
// the base-121 sub-table is copied with ONE row changed per experiment slot:
//   index 123 (PACK III, TOD_PAP_CAMO_T3) -> tod_camo_pap3        our camo (tools/gen_tod_camo.js)
//   index 122                              -> mtl_origins_camo_alt  THE CONTROL: MadGaz's material, in this build for months
//   index 121 and every other row          -> untouched stock
// The other four sub-tables are listed by their ORIGINAL names, so PACK I (22)
// and PACK II (126) keep rendering exactly as they do today, and the port's
// base_material / camo_mask rows for THIS gun's model are byte-identical.
// Guns whose table has no base-121 sub-table (the two knives) or whose table
// is not defined in this install (the Leviathan) keep the port table. Read the
// result with the dev camo browser: 123 / 122 / 121 on a PACK III gun.
//
// PACK-A-PUNCH CAMO (v17.35, 2026-09-04) — one weaponcamo per gun, ours.
//
// Read the header of tools/gen_tod_camo.js for WHY this exists: the ports' own
// camo tables link fine but every material they name is a stock asset absent
// from the gdtDB, so all 124 of them resolve to nothing and every camo index —
// including stock's default 42 — has always been a no-op on this map. The fix
// is to point the `_up` forms at a table whose materials WE ship.
//
// The emitted asset keeps the port's own `base_material_*` / `camo_mask_*` rows
// (copied verbatim from that gun's ship table, both material parts): those name
// the materials on THIS gun's model and the masks that shape the camo over it,
// and getting them from anywhere but the port's own table would be guesswork.
// Only `_material` moves — to our three tier camos.
//
// SLOT 4 IS A CONTROL, deliberately. It points at `mtl_origins_camo_alt`, a
// MadGaz camo material that is ALREADY proven to link and render in this build
// (the Leviathan pulls it). If tiers 1-3 show nothing in game and slot 4 shows
// a camo, the fault is our material; if slot 4 is blank too, the fault is the
// pipeline. One build answers which — point TOD_PAP_CAMO_T1 at 4 in
// _tod_classes.gsc to look at it.
// =============================================================================
const CAMO_ENABLED = false;   // v17.58: the tod_camo_* tables were unreferenced since v17.50 (tiers ride stock slots on the port tables)
const CAMO_TIER_MATERIALS = ['tod_camo_pap1', 'tod_camo_pap2', 'tod_camo_pap3'];
const CAMO_CONTROL_MATERIAL = 'mtl_origins_camo_alt';

// THE COUNTRYSIDE CONTROL (v17.48 experiment, 2026-09-04). With the give lane
// PROVEN (the dev print reads `idx 3` on a bare MP7 — screenshot, 18:5x), the
// fault is downstream of the give: our material, or the camo mechanism on
// these twins. A sister map (countryside, docs/16 in map 1's KB) renders a
// camo on these same Skye packs using the PORT'S OWN table and stock index 28
// (`mtl_wpn_t7_camo_cwl` — slot 28 of every t5/t6/t9 ship table here). With
// this switch ON every _up twin KEEPS the port's table (our tod_camo_* tables
// are still emitted, unreferenced) and `_tod_classes::pap_camo_index` returns
// TOD_PAP_CAMO_STOCK_CONTROL in a dev build. One match then reads:
//   camo on the packed gun  -> mechanism + stock materials WORK; our table or
//                              material is the fault (and the "stub" theory
//                              of v17.35 is dead)
//   still bare              -> the mechanism itself is broken on the twins;
//                              stop touching art
// THE ANSWER IS IN (v17.50, same evening): "tier 1 works". The mechanism and
// the stock materials render; only our tod_camo_pap* materials never drew. So
// this flag is now the SHIPPED STATE, not an experiment: every _up twin keeps
// its port's camo table and _tod_classes' TOD_PAP_CAMO_T1..3 name three stock
// slots of it (28 / 42 / 22). The tod_camo_* tables below are still emitted
// but nothing references them; set CAMO_ENABLED = false at the next FULL
// build to drop them and their three materials + nine textures from the pack.
const CAMO_KEEP_PORT_TABLE = true;
const CAMO_PAP3_TABLE = true;              // v17.89: the table-copy lane above; a gun that got a copy points its _up forms at it
const CAMO_PAP3_MATERIAL = 'tod_camo_pap3';
const CAMO_PAP3_CONTROL = 'mtl_origins_camo_alt';
const CAMO_PAP3_INDEX = 124, CAMO_PAP3_CONTROL_INDEX = 122;   // LOCKSTEP: TOD_PAP_CAMO_T3 in _tod_classes.gsc is 124 (v17.91: 123 went back to stock Revelations 3 for PACK II)

// Where a gun's camo table is DEFINED when it is not in the gun's own source
// GDT. Resolved by name, never by scanning: the install's source_data is 1.1 GB
// across 438 GDTs and a full scan per run is not a thing to do every build.
const CAMO_TABLE_FILES = {
  't9_camo_ak47_table':      T9('skye_t9_ak-47.gdt'),        // gun.src is the .acc-orig copy
  'camo_t9_me_knife_combat': T9('t9_weapons/melee/wpn_t9_me_knife_combat.gdt'),
  'camo_t9_me_wakizashi':    T9('t9_weapons/melee/wpn_t9_me_wakizashi.gdt'),
  'skye_up_camo':            T9('skye_up_camo.gdt'),   // the Bulldog's, and the
                                                       // ports' generic PaP set
};

const camoAsset = (stem) => `tod_camo_${stem}`;
const camoEmitted = new Set();   // stems that got a table — the ONE authority
                                 // for whether a variant's camo field is rewritten

function tryBlock(text, asset, gdf) {
  try { return extractBlock(text, asset, gdf); } catch (e) { return null; }
}

// the camo table named by a gun's source block, if any
function sourceCamoName(block) {
  const m = block.match(/^\s*"camo"\s+"([^"]+)"\s*$/m);
  return m && m[1] ? m[1] : null;
}

// find a weaponcamo/weaponcamotable asset's text, wherever it lives
function camoAssetText(name, ownText) {
  for (const text of [ownText, ...(CAMO_TABLE_FILES[name] && fs.existsSync(CAMO_TABLE_FILES[name])
        ? [fs.readFileSync(CAMO_TABLE_FILES[name], 'utf8')] : [])]) {
    if (!text) continue;
    const tbl = tryBlock(text, name, 'weaponcamotable.gdf');
    if (tbl) {
      // a table is a list of weaponcamo tables; slot 1 is the SHIP set, which is
      // the one whose base materials/masks cover the gun's own model
      const ship = tbl.match(/^\s*"table_01_name"\s+"([^"]+)"\s*$/m);
      if (!ship || !ship[1]) return null;
      return camoAssetText(ship[1], text);
    }
    const camo = tryBlock(text, name, 'weaponcamo.gdf');
    if (camo) return camo;
  }
  return null;
}

// slot 1 of every material PART, as `key -> value` rows keyed without the slot
function slotOneRows(camoBlock) {
  const parts = new Map();   // part number -> [ [suffix, value], ... ]
  for (const line of camoBlock.split(/\r?\n/)) {
    const m = line.match(/^\s*"material(\d+)_1_([A-Za-z0-9_]+)"\s+"(.*)"\s*$/);
    if (!m) continue;
    if (!parts.has(m[1])) parts.set(m[1], []);
    parts.get(m[1]).push([m[2], m[3]]);
  }
  return parts;
}

function buildCamoBlock(stem, parts) {
  const slots = [...CAMO_TIER_MATERIALS, CAMO_CONTROL_MATERIAL];
  const out = [`\t"${camoAsset(stem)}" ( "weaponcamo.gdf" )`, '\t{',
               '\t\t"baseIndex" "1"', '\t\t"configstringFileType" "WEAPONCAMO"'];
  for (const [part, rows] of [...parts.entries()].sort()) {
    for (let s = 0; s < slots.length; s++) {
      for (const [key, value] of rows)
        out.push(`\t\t"material${part}_${s + 1}_${key}" "${key === 'material' ? slots[s] : value}"`);
    }
  }
  out.push(`\t\t"numCamos" "${slots.length}"`, '\t\t"type" "weaponcamo"', '\t}');
  return out.join('\n');
}

// the text a weaponcamotable / weaponcamo asset lives in — the gun's own GDT or the table file map
function camoTextsFor(name, ownText) {
  const out = [ownText];
  if (CAMO_TABLE_FILES[name] && fs.existsSync(CAMO_TABLE_FILES[name])) out.push(fs.readFileSync(CAMO_TABLE_FILES[name], 'utf8'));
  return out;
}
function findIn(texts, asset, gdf) { for (const t of texts) { const b = tryBlock(t, asset, gdf); if (b) return b; } return null; }

// THE TABLE-COPY LANE (v17.89). Returns [tableBlock, subTableBlock, tableName] or null.
function buildPap3Copy(stem, tableName, ownText) {
  const texts = camoTextsFor(tableName, ownText);
  const table = findIn(texts, tableName, 'weaponcamotable.gdf');
  if (!table) return null;                                     // names a weaponcamo directly, or undefined here
  const entries = [...table.matchAll(/^\s*"(table_\d\d_name)"\s+"([^"]+)"\s*$/gm)].map(m => [m[1], m[2]]);
  let hit = null;
  for (const [key, asset] of entries) {
    const sub = findIn(texts, asset, 'weaponcamo.gdf');
    if (!sub) continue;
    const bi = sub.match(/^\s*"baseIndex"\s+"(\d+)"\s*$/m);
    if (bi && parseInt(bi[1], 10) === 121) { hit = { key, asset, sub }; break; }
  }
  if (!hit) return null;                                       // no base-121 sub-table (the knives)
  const slotOf = idx => idx - 121 + 1;
  const subName = 'tod_camo_' + stem + '_base121', tableCopy = 'tod_camo_' + stem + '_table';
  // header renames and row swaps are done with replacer FUNCTIONS: a string replacement
  // treats $-sequences specially, and a GDT row's regex ends in "$" (2026-09-05, this file's own prefix
  // was spliced into this function twice by a patch that forgot that)
  let sub = hit.sub.replace('"' + hit.asset + '" ( "weaponcamo.gdf" )', () => '"' + subName + '" ( "weaponcamo.gdf" )');
  let moved = 0;
  for (const [idx, mat] of [[CAMO_PAP3_INDEX, CAMO_PAP3_MATERIAL], [CAMO_PAP3_CONTROL_INDEX, CAMO_PAP3_CONTROL]]) {
    const re = new RegExp('^(\\s*)"material1_' + slotOf(idx) + '_material"\\s+"[^"]*"\\s*$', 'm');
    if (!re.test(sub)) throw new Error(stem + ': ' + hit.asset + ' has no material1_' + slotOf(idx) + '_material row');
    sub = sub.replace(re, (m0, indent) => indent + '"material1_' + slotOf(idx) + '_material" "' + mat + '"'); moved++;
  }
  if (moved !== 2) throw new Error(stem + ': expected 2 rows moved, got ' + moved);
  let tbl = table.replace('"' + tableName + '" ( "weaponcamotable.gdf" )', () => '"' + tableCopy + '" ( "weaponcamotable.gdf" )');
  tbl = tbl.replace(new RegExp('^(\\s*)"' + hit.key + '"\\s+"' + hit.asset + '"\\s*$', 'm'), (m0, indent) => indent + '"' + hit.key + '" "' + subName + '"');
  if (!tbl.includes('"' + subName + '"')) throw new Error(stem + ': table entry swap failed');
  return [tbl, sub, tableCopy];
}
const camoTableOf = new Map();   // stem -> the table copy its _up forms should name

// rewrite an _up variant's camo field onto our table
function camoSet(gun, line) {
  if (CAMO_PAP3_TABLE && camoTableOf.has(gun.stem))
    return line.replace(/^(\s*)"camo"\s+"[^"]*"\s*$/, `$1"camo" "${camoTableOf.get(gun.stem)}"`);
  if (CAMO_KEEP_PORT_TABLE) return line;   // the countryside control — see the flag
  if (!camoEmitted.has(gun.stem)) return line;
  return line.replace(/^(\s*)"camo"\s+"[^"]*"\s*$/, `$1"camo" "${camoAsset(gun.stem)}"`);
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
let nCamoTables = 0;

for (const gun of allGuns) {
  const text = fs.readFileSync(gun.src, gun.encoding);
  // per-FORM: the dark rung exists on the packed form only (axisMaxUp).
  // PaP stat set from the TUNED base form (base tune + tier overrides; the
  // level-0 ladder is the identity) BEFORE any _up variant is generated.
  computePapSet(gun.stem, extractBlock(text, gun.forms[0].srcAsset, gun.forms[0].gdf || gun.gdf)
    .split(/\r?\n/).map(l => baseTune(gun, l, false)).join('\n'));

  // PaP CAMO — build this gun's own table BEFORE any variant is emitted, so
  // camoSet() below knows whether it has one to point at. A gun whose source
  // names no camo table (or whose table is not in this install — the Leviathan's
  // is referenced by every port that uses it and DEFINED by none) simply keeps
  // what it had: no camo, exactly as it ships today.
  if (CAMO_PAP3_TABLE) {
    const upForm = gun.forms.find(f => f.up) || gun.forms[0];
    const srcName = sourceCamoName(extractBlock(text, upForm.srcAsset, upForm.gdf || gun.gdf));
    const copy = srcName ? buildPap3Copy(gun.stem, srcName, text) : null;
    if (copy) { blocks.push(copy[0], copy[1]); camoTableOf.set(gun.stem, copy[2]); nCamoTables++; }
    else console.log(`  camo: ${gun.stem} keeps ${srcName || '(no table)'} — ${srcName ? 'no base-121 sub-table resolvable here' : 'no camo field'}`);
  }
  if (CAMO_ENABLED) {
    const upForm = gun.forms.find(f => f.up) || gun.forms[0];
    const srcName = sourceCamoName(extractBlock(text, upForm.srcAsset, upForm.gdf || gun.gdf));
    const camoText = srcName ? camoAssetText(srcName, text) : null;
    const parts = camoText ? slotOneRows(camoText) : null;
    if (parts && parts.size) {
      blocks.push(buildCamoBlock(gun.stem, parts));
      camoEmitted.add(gun.stem);
    } else if (srcName) {
      console.log(`  camo: ${gun.stem} SKIPPED — ${srcName} not resolvable in this install`);
    }
  }

  for (const form of gun.forms) {
    const variants = variantsOf(gun, form.up);
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
          if (form.up) l = camoSet(gun, l);   // PaP forms only — a base gun wears no camo
          return l;
        });
      if (scaled === 0) throw new Error(`no fields scaled for ${name} — key set mismatch?`);
      blocks.push(twin);
      // Attachment uniques are only connected by weaponfull + the linker's
      // mapping table. Zoning an AU separately leaves GetWeapon bare in game.
      const presentation = /"attachmentUnique"\s+"au_tod_(?:thunder_smash|staff_[^"]+)"/.test(twin);
      zoneLines.push(`${presentation ? 'weaponfull' : 'weapon'},${name}`);
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
  if (!fBase) throw new Error(`${gun.stem}: needs a base form`);
  // A GUN WITH NO PACKED FORM GETS NO UPGRADE ROW, AND THAT IS THE POINT.
  // Every row in this table means "this gun packs into that gun", so a gun
  // that packs into nothing has nothing to say here. Stock can_upgrade then
  // refuses it at the machine, which is exactly the intent for the MAGE staff
  // (user 2026-09-07: "let's not let it [PaP]").
  //
  // THIS USED TO THROW. The assertion was right for every gun that had ever
  // existed here -- all of them packed -- but it encoded "no upgrade row" as
  // impossible rather than as a case. It is a case now.
  //
  // THE CLASS-GUN PaP LANE IS UNAFFECTED: zm_cwpap.gsc buys class primaries
  // through its own path precisely BECAUSE they fail stock can_upgrade by
  // roster design, and that path only sets player.tod_pap_owned. It never
  // consults this table.
  if (!fUp) {
    console.log(`  ${gun.stem}: base-only, no PaP form -> no weapons-table upgrade row`);
    continue;   // CONTINUE, NOT RETURN: this block is inside a top-level
                // `for (const gun of allGuns)`, not a function. A `return` here
                // ends the MODULE -- the run exits 0 with the ledger never
                // printed and the emit phase never reached. Cost one run to find.
  }
  // ...then STRIP a trailing "_zm": the engine drops that suffix, so the script
  // name and the weapons-table name are the asset name without it. See the
  // evidence block in _tod_classes.gsc register_guns — writing the tailed name
  // here is what broke the blades on 2026-08-23.
  const scriptName = n => n.replace(/_zm$/, '');
  // THE BASE SET, DELIBERATELY (v17.10). Each row is "this gun packs into that
  // gun", so it must be keyed on variants that EXIST unpacked. Since the dark
  // rungs are packed-only (axisMaxUp), the two sets are different sizes now, and
  // iterating the packed set would pair a base variant with a DARK packed one —
  // Pack-a-Punch would hand out the dark gun to anyone who bought a pack.
  //
  // Dark-only variants therefore get no row, which is correct: they are only
  // ever reached by a player who is ALREADY packed, reconcile_twin swaps them in
  // directly by asset name, and this map's is_weapon_upgraded check pairs the
  // table lookup with IsSubStr(name, "_up") — which a dark name satisfies.
  for (const v of variantsOf(gun, false)) {
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

// ---- the ledger — GUARDS THE WRITES, AND MUST STAY ABOVE THEM ---------------
// MOVED HERE 2026-09-01. It used to sit AFTER all three writeFileSync calls, so
// a run that exceeded the guard had ALREADY rewritten the weapon GDT, the zpkg
// and the weapons CSV before it threw. "It throws" therefore did not mean "it
// did nothing" — a guard that runs after the writes is not a guard on the
// writes, it is a report. That fired for real: an over-budget run at 01:36 on
// 2026-09-01 left all three outputs rewritten (harmlessly, because the
// generator is deterministic and the inputs had not changed — but the next
// person to edit an axis and run this would have been left holding an
// over-budget tree that still looked generated).
//
// It also means the ledger NUMBER can now be read without mutating anything:
// run the generator, read the printed figure, and if it throws nothing on disk
// has moved. That is what makes "what would HANDLING at 4 tiers cost?" a
// question you can answer instead of estimate.
//
// KEEP THIS ABOVE THE writeFileSync CALLS. `total` is final long before this
// point (nothing mutates it after the generation loop) and
// countFixedRegistrations() deliberately skips OUT_ZPKG, so neither depends on
// the writes having happened.
const LEDGER_FIXED = countFixedRegistrations();
const ledger = total + LEDGER_FIXED;
console.log(`PACK III CAMO TABLES: ${nCamoTables} gun(s) got a table copy (index ${CAMO_PAP3_INDEX} -> ${CAMO_PAP3_MATERIAL}, ${CAMO_PAP3_CONTROL_INDEX} -> ${CAMO_PAP3_CONTROL})`);
console.log(`REGISTRATION LEDGER: ${total} generated + ${LEDGER_FIXED} fixed = ${ledger}  (guard ${LEDGER_GUARD}; map 1 shipped a BOOTING 229-asset table, 368 = boot-AV)`);
if (ledger > LEDGER_GUARD) throw new Error(`ledger ${ledger} exceeds the ${LEDGER_GUARD} guard — NOTHING WAS WRITTEN. Retire an axis or a gun before adding more.`);

// Idempotent CSV patch — NO marker/comment lines (the weapon-table parser
// reads every line as a row; a "## comment" row would feed GetWeapon garbage).
// Strip every row that LOOKS like a generated variant of ANY ladder stem
// (enabled or not — a gun that was disabled again must lose its rows), then
// append the current set. Variant rows = <stem>(_up)?(_<letter><digit>...|_b),
const stems = Object.values(LADDER).flat().map(g => g.stem).concat(["t9_me_knife_american", "t9_mac10", "t9_stoner63"]).sort((a, b) => b.length - a.length);
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
// These inherited stock gun rows are unobtainable here: Tower has no
// wallbuys/box and its gun classes use generated variants. Keep utility,
// wonder-weapon, starting-pistol and explicitly imported rows intact.
const unusedStockCostRows = new Set([
  'ar_accurate', 'ar_cqb', 'ar_damage', 'ar_longburst', 'ar_marksman', 'ar_standard',
  'lmg_cqb', 'lmg_heavy', 'lmg_light', 'lmg_slowfire', 'pistol_burst', 'pistol_fullauto',
  'shotgun_fullauto', 'shotgun_precision', 'shotgun_pump', 'shotgun_semiauto',
  'smg_burst', 'smg_capacity', 'smg_fastfire', 'smg_standard', 'smg_versatile',
  'sniper_fastbolt', 'sniper_fastsemi', 'sniper_powerbolt', 'smg_sten', 'ar_famas',
  'ar_garand', 'smg_mp40', 'smg_ppsh', 'ar_peacekeeper', 'pistol_energy',
  'shotgun_energy', 'smg_thompson',
]);
csv = csv.split(/\r?\n/).filter(l => !variantRe.test(l) && !unusedStockCostRows.has(l.split(',')[0])).join('\n');
if (!csv.endsWith('\n')) csv += '\n';
csv += csvRows.join('\n') + '\n';
const costBudget = require('./verify_weapon_costs').verifyWeaponCosts(csv);
console.log(`WEAPON COST TABLE: ${costBudget.costs}/240 entries (separate from asset registrations)`);

// latin1 superset of ascii — safe for the mixed sources
fs.writeFileSync(OUT_GDT, '{\n' + blocks.join('\n') + '\n}\n', 'latin1');
console.log(`wrote ${OUT_GDT}  (${total} variant weapon assets)`);

fs.writeFileSync(OUT_ZPKG, [
  '// GENERATED by tools/gen_tod_twins.js — twin-swap weapon variants.',
  '// Included from zm_tower_of_doom.zone via `include,tod_twins`.',
  ...zoneLines, '',
].join('\n'));
console.log(`wrote ${OUT_ZPKG}  (${zoneLines.length} weapon lines)`);

fs.writeFileSync(CSV, csv);
console.log(`patched ${CSV}  (${csvRows.length} PaP-mapping variant rows, marker-free)`);
