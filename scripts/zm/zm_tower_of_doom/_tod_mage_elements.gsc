// =============================================================================
// _tod_mage_elements.gsc — THE MAGE's three staffs, their matchups, and the
// HEALING AURA on the lethal button. docs/114 §C (v18.30 revamp).
//
// THE DESIGN (user 2026-09-07, "completely revamp the mage"):
//   * THREE STAFFS, held at once, switched like any weapon, EACH ONE ITS OWN
//     ELEMENT: LIGHTNING (tier 1) -> + FIRE (tier 2) -> + ICE (tier 3). A tier
//     promotion ADDS a staff and takes nothing away. No sidearm. No combat
//     stance, no face-button spells -- the trigger IS the spell.
//   * EACH STAFF IS GOOD AT ITS OWN THING: lightning answers the horde, fire
//     answers the robots and the armored, ice answers the hounds and the Fury.
//     Every staff is WEAK against the Panzer.
//   * UPGRADES ARE PER STAFF: CHAIN LIGHTNING (53) on the lightning staff,
//     FIRE BLAST (49, tier 2+) on the fire staff, ICE SHATTER (50, tier 3+) on
//     the ice staff, ATTUNEMENT (51) on the aura's recharge, HEALING AURA (52)
//     on the aura itself. All scope "class": a promotion never resets them.
//   * HEALING AURA must be unlocked by its first card, then casts with LETHAL.
//     BLINK uses TACTICAL; ARCHMAGE uses AIM. Staffs have no aim-down-sights.
//
// WHAT THIS MODULE OWNS vs WHAT IT ARMS. The staffs are ordinary weapons: the
// engine fires the bolt, stock delivers the hit, and _tod_upgrades'
// upgrade_damage_cb is the ONE damage chain on this map (FIRST-NON-(-1)-WINS,
// so a second callback would never run). That module cannot #using this one
// (it is imported here -- the KB cycle rule), so the interface is TWO GUARDED
// LEVEL POINTERS set in init() and read by the callback:
//   level.tod_mage_staff_mult( attacker, victim, weapon ) -> the multiplier
//     (tier ladder x matchup x the staff's own upgrade card)
//   level.tod_mage_staff_hit( attacker, victim, weapon, dmg ) -> the on-hit
//     effect (burn tell / slow / chain lightning)
//   level.tod_mage_pierce_armor( weapon ) -> true for the FIRE staff, so the
//     callback skips the armored sprinter's damage cut for it
// Both pointers are undefined while TOD_MAGE_ENABLED is 0, and the callback's
// arms are `isdefined` guarded, so a shipped build with the class off runs
// none of it.
//
// CHAIN LIGHTNING re-enters the callback through the tod_mage_chain_hit mark
// (the CLEAVE idiom): the extra hits are DoDamage'd with the mark set, the
// callback consumes it and passes the figure through untouched (the victim's
// sprinter armor still applies -- the cleave rule).
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_utility;
#using scripts\zm\zm_tower_of_doom\_tod_classes;
#using scripts\zm\zm_tower_of_doom\_tod_upgrades;
#using scripts\zm\zm_tower_of_doom\_tod_upgrade_ui;
#using scripts\zm\zm_tower_of_doom\_tod_zombie_speed;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\zm_tower_of_doom\_tod_mage.gsh;
#insert scripts\zm\zm_tower_of_doom\_tod_toast.gsh;

// #precache MUST come AFTER every #using/#insert (dialect rule) and the
// paths must match the fx, lines in zone_source/zm_tower_of_doom.zone exactly.
// THE GREEN HEALTH BAR notify. A LuiNotifyEvent name must be a PRECACHED
// eventstring or the & reference resolves to nothing. PAIR THIS WITH THE
// LuiNotifyEvent IN aura_bar: a precache with no reference is an orphan and the
// linker dies on it with no message (paid for in v18.38c).
#precache( "eventstring", "tod_mage_aura" );
#precache( "eventstring", "tod_arch_bars" );
#precache( "eventstring", "tod_aura_bars" );   // 2026-09-09: the aura green for PARTY rows
// THE MANA BAR's channel — same rule as the line above: a LuiNotifyEvent name
// must be a PRECACHED eventstring, and a precache with no reference is an
// orphan the linker dies on with no message. Referenced in mana_send().
#precache( "eventstring", "tod_mage_mana" );
// THE TWO ABILITY TILES' channel: healing aura and Blink charge counts.
#precache( "eventstring", "tod_mage_abil" );
#precache( "eventstring", "tod_mage_recharge" );
#precache( "eventstring", "tod_mage_blink_blocked" );
// v19.11 — THE CONTROLS OVERLAY's channel (Workshop, Bigfsi 2026-09-15: "Class
// needs more explanation"): per-ability USE COUNTS, so the HUD can show each
// ability's button beside its tile until it has been cast TOD_MAGE_TUT_USES
// times. Referenced in tut_send(). Three ints: heal, blink, archmage.
#precache( "eventstring", "tod_mage_tut" );
// 2026-10-01 (docs/167 item 2) — the green "+" burst on a player Healing Aura's
// Lv6 revive stood up. Referenced in heal_revive(); the HUD half is
// CoD.TodHealBurst in tod_upgrade.lua. Same orphan rule as the lines above.
#precache( "eventstring", "tod_heal_burst" );
#precache( "fx", "tod/mage/fx_healing_aura_player" );
// 2026-10-01 (second pass): the aura's ground AREA, one per radius (heal_area_start;
// tools/gen_heal_area_fx.py). LOCKSTEP: heal_radius() values = these names.
#precache( "fx", "tod/mage/fx_healing_aura_area_256" );
#precache( "fx", "tod/mage/fx_healing_aura_area_288" );
#precache( "fx", "tod/mage/fx_healing_aura_area_320" );
#precache( "fx", "tod/mage/fx_healing_aura_area_352" );
#precache( "fx", "tod/mage/fx_healing_aura_area_384" );
#precache( "fx", "tod/mage/fx_healing_aura_area_416" );
#precache( "fx", "tod/mage/fx_staff_lightning_chain_clean" );
#precache( "fx", "zombie/fx_bgb_anywhere_but_here_teleport_zmb" );

#namespace tod_mage_elements;

// THE STAFF GLOW (v18.32). A toplayer field the .csc twin turns into the
// element aura on the held staff's viewmodel (PlayViewmodelFX is client-only).
// Registered UNCONDITIONALLY from the REGISTER_SYSTEM window (memory
// clientfield-registration-window) -- the field must exist in both VMs on
// every build; only its WRITER below is behind TOD_MAGE_ENABLED.
#define TOD_STAFF_GLOW_FIELD   "tod_staff_glow"   // LOCKSTEP with _tod_mage_elements.csc

// ARCHMAGE ON THE WORLD (2026-10-01): one "allplayers" field the .csc twin turns
// into the form's circle / column / light, per viewer (arch_fx_set; the effects
// are tools/gen_archmage_fx.py). 2 bits: OFF / ON / FADE (the timer ran out - the
// rings collapse; OFF alone = cut by death or a class change: they just go).
#define TOD_ARCH_FX_FIELD     "tod_arch_form"     // LOCKSTEP with _tod_mage_elements.csc
#define TOD_ARCH_FX_OFF       0
#define TOD_ARCH_FX_ON        1
#define TOD_ARCH_FX_FADE      2
#define TOD_ARCH_DEV_PREVIEW_SECS   10   // the dev Mage dummy's form preview (tod_dev_arch_test)
#define TOD_ARCH_DEV_REFILL_MS      3000 // tod_dev_arch_test: a full bar this long after a form

REGISTER_SYSTEM( "tod_mage_elements", &__init__, undefined )

function __init__()
{
	clientfield::register( "toplayer", TOD_STAFF_GLOW_FIELD, VERSION_SHIP, 2, "int" );
	clientfield::register( "actor", "tod_mage_chain_fx", VERSION_SHIP, 2, "int" );
	clientfield::register( "allplayers", TOD_ARCH_FX_FIELD, VERSION_SHIP, 2, "int" );
}

// ---- TUNING ---------------------------------------------------------------
// LOCKSTEP WITH tod_upgrade.lua DETAIL[49..53]. Those rows are the ONLY place
// a player ever reads these numbers -- the cards bake no figures.

// THE TIER LADDER, script-side. gen_tod_twins.js emits the three staffs FLAT
// (`flat: true` on the fire and ice rungs -- no TIER_DPS normalization),
// because the tiers here are held TOGETHER, not one after another: a tier-3
// mage's lightning staff must be as strong as their ice staff. So the class
// tier scales EVERY staff, and it uses the SAME 1 / 1.5625 / 2.4414 ladder the
// other four classes climb through their generated tiers (TIER_DPS in the
// generator -- LOCKSTEP PAIR).
// =============================================================================
// THE CLASS TIER LADDER -- AND IT IS DELIBERATELY NOT THE GUN LADDER (v18.51).
//
// ⚠️ THIS USED TO BE A LOCKSTEP PAIR WITH TIER_DPS IN gen_tod_twins.js
// (1 / 1.5625 / 2.4414) AND IT IS NOT ONE ANY MORE. Do not "fix" the drift:
// the divergence IS the design. A future reader who restores the gun numbers
// here deletes the whole class curve and will see nothing fail.
//
// User 2026-09-08: "I want the mage to be medium ranked at early mid game,
// late game High ranked and Very late game OP." Ranked among the five classes
// on sustained horde output, packed, no cards -- the shipped v18.50 ladder had
// the curve upside down:
//
//              was (1 / 1.5625 / 2.4414)        now (0.92 / 2.00 / 3.95)
//   tier 1     rank 2 of 5   HIGH               rank 3 of 5   MEDIUM
//   tier 2     rank 3 of 5   MEDIUM             rank 3 of 5   MEDIUM
//   tier 3     rank 4 of 5   LOW                rank 2 of 5   HIGH
//
// The guns step x1.5625 per rung, evenly. The mage steps x2.17 then x1.98 off
// a base cut 8%, so its promotions are the two biggest single power steps in
// the map and its floor-30 tier card is the most valuable card any class can
// be dealt. That is what "back-loaded" has to mean when the only thing a class
// can spend a tier on is the same three weapons it already holds.
//
// VERY LATE is NOT on this ladder -- there is no tier 4. It is carried by three
// mage-only multipliers that all grow with how deep the run is: ARCHMAGE uptime
// (fed by kills, see TOD_MAGE_ARCH_MANA_KILL_LV), the per-staff card ladders
// (+60% each at cap, and the spire's won trials are the only place a build gets
// finished), and CHAIN LIGHTNING, whose arcs land more often the denser the
// horde. No gun class has an analogue for any of the three.
// =============================================================================
#define TOD_MAGE_TIER1_MULT      0.6256 // 2026-09-09 playtest: the whole ladder x0.85. ⚠️ The 2026-09-21 x0.92 pass was REVERTED the same day: the user re-cut it PER STAFF (fire -5%, lightning unchanged, ice -10% vs horde+Panzer), and this ladder is SHARED, so a cut here can never leave lightning alone.
#define TOD_MAGE_TIER2_MULT      1.36   // 1.60 before the playtest pass
#define TOD_MAGE_TIER3_MULT      2.686  // 3.16 before the playtest pass

// THE MATCHUPS (user: "lightning will be good against zombies and hordes. Fire
// will be good against robots and the armor, and then the ice will be good
// against the hounds, the dogs, and the furies. And overall, the mage will be
// pretty weak against the Panzers.")
// v18.44 REBUILT THIS AS ONE FAMILY TABLE (user: "I want this class to be more
// skilled so each staff is good against what they are good against and bad
// against the rest"). Before this the off-matchup case was NEUTRAL — fire and ice
// did full damage to the horde — so there was never a reason to swap BACK, and a
// tier-3 mage could hold one staff all match. Now every victim belongs to exactly
// one family and the staff either owns it or is punished for it.
//
//                   horde   robot/armored   hound/Fury   Panzer
//   lightning       x1.25       x0.45          x0.45      x0.40
//   fire            x0.45       x2.00          x0.45      x0.40
//   ice             x0.45       x0.45          x2.00      x0.40
//
// THE PANZER TAX REPLACES THE OFF-FAMILY PENALTY, it does not stack with it.
// He is nobody's target, so stacking would have taken every staff to x0.16 —
// and the Warden King is a Panzer at 25M HP per player. "Weak against Panzers"
// was never meant to read as "cannot participate".
//
// LIGHTNING'S OWN FAMILY PAYS LESS THAN THE OTHER TWO, and that is deliberate:
// it fires roughly seven times for every fire-staff shot and CHAIN LIGHTNING
// arcs on top, so its reward is RATE. A x2.00 here would double the class's
// bread-and-butter damage rather than sharpen a choice.
// =============================================================================
// THE PANZER IS LIGHTNING'S TARGET (v18.52). IT USED TO BE NOBODY'S.
//
// ⚠️ EVERY PROSE DESCRIPTION OF THIS CLASS SAID "the worst Panzer answer in the
// map" AND THAT IS NOW THE OPPOSITE OF TRUE. User 2026-09-08: "Best weapon
// against panzers should be the lightning staff." The universal x0.40 was an
// implementation reading of "each staff is good against what they are good
// against and bad against the rest" -- it left the Panzer with no right answer
// at all, which is the same hole family_answerable() was written to close one
// version ago: a matchup table that punishes every choice is not a choice.
//
// So the table is symmetric at last. Three families, three staffs, one owner
// each, and the Panzer sits in lightning's:
//     horde + PANZER          -> lightning
//     protector + sprinter    -> fire
//     hellhound + Fury        -> ice
//
// WHY THE BONUS IS SO MUCH BIGGER THAN x2.00. Two reasons, and both are
// arithmetic rather than taste:
//   (1) A STAFF CANNOT CRIT. Every gun figure it is measured against assumes
//       head hits and therefore carries the engine's flat x3.0 hit-location
//       crit; a staff hit is splash and takes none. A third of the multiplier
//       below is buying that back, not buying power.
//   (2) Lightning's own family pays x1.25, not x2.00, because its reward is
//       RATE -- so it starts from the lowest matchup number in the table.
// Historical PRE-ARMOR estimate: x5.60 gives about 76,245 -- RANK 3,
// a hair under the Death Machine's 77,625 and above the MP7. That placement is
// the user's own ("you can place him right under death machine DPS"), and
// v18.53 made it the rule for all four families rather than a one-off.
//
// IT IS DELIBERATELY NOT THE BIGGEST NUMBER IN THE MAP. The first pass at this
// put it at 108,900, above every primary; the user pulled it back. What makes
// the class strong against a Panzer is not the figure, it is that the figure
// EXISTS -- every other class has an enemy it has no answer to, and the mage
// has none. With ARCHMAGE running it reaches ~244,000 and is first outright,
// which is the payoff for spending the bar on the fight it was saved for.
//
// THE WARDEN KING IS A PANZER, so this is also the spire's climax fight. That
// is deliberate and it lines up with the class's stated curve: the mage is
// meant to be OP very late, and the King is what very late means.
// =============================================================================
#define TOD_MAGE_LIGHTNING_VS_PANZER 4.76   // v18.53: a DIRECT multiplier now; 5.60 -> 4.76 (v18.77, user 2026-09-10: "Lightning needs 15% nerf against panzers")
// TOD_MAGE_OFF_PANZER (0.40) RETIRED v18.56 -- the Panzer arm reads each staff's
// own off_family_mult() now, which is how ice became okay against him.
// =============================================================================
// ONE MULTIPLIER PER FAMILY, AND THEY ARE ALL CALIBRATED TO ONE RULE (v18.53).
//
// User 2026-09-08, on what the class IS: "what makes him OP is that his best
// staff is always top 3 against the weakness enemy" -- and, for the Panzer,
// "you can place him right under death machine DPS".
//
// THE CONTRACT IS TWO STATES, NOT ONE (corrected v18.54, user: "his maxed out
// fire blast should be 1 against their weakness. Easily"). The first pass folded
// the maxed card INTO the rank-3 target, which left a fully-invested mage still
// third -- so the six cards you spend on a staff bought nothing but parity.
//
//   UNINVESTED (the staff's own card at 0)  -> RANK 3, just under the Death
//                                              Machine. The user's placement.
//   FULLY INVESTED (that card maxed)        -> RANK 1, and not narrowly.
//
// So the class is never worse than third to ANYTHING, and it is first against
// whatever it has actually paid to specialise in. Breadth by default, peak by
// investment. Every other class has a target it is helpless against; this one
// has none, and has one it is best at. Tier-3, packed, DAMAGE 10:
//
// THE WHOLE MATRIX, maxed cards (rN = rank among the five classes' primaries):
//
//                lightning        fire            ice        best gun
//   horde      70,799 r3*     28,146 r5      61,904 r4       DM 77,625
//   armour      6,127 r5     122,418 r1*     61,904 r4       AK 84,749
//   beast       6,127 r5      28,146 r5      87,925 r1*      AK 84,749
//   panzer     76,245 r3*     28,146 r5      61,904 r4       AK 84,749
//                                                  (* = owns that family)
//
// Read the COLUMNS, not the rows -- they are what the class is. Lightning covers
// two families and is nothing outside them. Fire is a 4.3x spike. Ice is flat:
// never rank 1 except at home, never below rank 4 anywhere, INCLUDING the
// Panzer. So there is always a right answer, and usually a safe one too.
//
// The UNINVESTED half of the contract still holds on the diagonal: with its own
// card at 0 each staff sits at rank 3, just under the Death Machine.
//
// (rank 1 needs to clear the AK's 84,749 on elites, the Death Machine's 77,625
// on trash.) LIGHTNING HAS NO DAMAGE CARD OF ITS OWN, so its growth lever is
// ARCHMAGE rather than a staff card -- which is why the two lightning rows climb
// further, and why the Panzer figure the user pinned "right under death machine"
// is the UNINVESTED one and is not raised here.
//
// THE FOUR NUMBERS DIFFER BECAUSE THE STAFFS DO, and a shared ON_FAMILY could
// not express that -- it was 2.00 for both fire and ice, which landed them at
// rank 4 and rank 4 while the same constant put lightning at rank 5 on the
// horde. Ice needs the most because its raw DPS is the lowest of the three;
// lightning needs the most of all against a Panzer because it has no damage
// card of its own and no crit. Retune by RANK, never by copying one of these
// onto another: tools/... the checker lives in the armory's Mage tab.
//
// WHY THE NUMBERS LOOK BIG NEXT TO A GUN'S. Every figure above gives the guns
// the engine's flat x3.0 HEAD CRIT, because that is how the Verdict tab prices
// them and it is what perfect play does. A staff hit is SPLASH and takes no
// hit-location multiplier at all, so roughly a third of each constant below is
// buying back a crit the weapon can never land, not buying power.
//
// LIGHTNING'S HORDE NUMBER WAS TUNED with six arcs at half the hit (x4.0).
// The 2026-09-09 nerf caps Lv6 at four arcs; Dark makes it five (six until the ceiling pass).
// Keep the direct-hit multiplier unchanged. The original comparison counts
// OVERDRIVE and the skirmisher's counts RUN AND GUN: it is that class's maxed
// card for that exact situation. Against a lone trash zombie lightning is far
// weaker than this row, and that is correct -- it is the HORDE staff.
// =============================================================================
// [tod 2026-09-09] LANES (user: "We really want each to have its own lane"; "Ice
// just seems too strong rn"; "I dont want ice horrible against the horde. It
// should suck on panzers"). Measured at tier 3 before this: ice vs a zombie was
// 13,100 per missile per second (22,700 with the volley overlapping) against
// lightning's 5,900 -- the HORDE staff was rank 3 on hordes, because ICE_OFF 2.36
// was calibrated for ONE missile and the v18.x volley made it three. Now:
// lightning vs horde 1.30 -> 1.75 (base 2,506/s), ice general 2.36 -> 1.00 (one
// missile 1,760/s = 70% of lightning; the close-range volley ~3,000/s, a touch
// above, which is the shotgun identity and fair for standing in the pile). Ice
// vs beasts untouched. Ice vs Panzer / armour rides the same general number
// times the 0.30 cut = ~530 per missile: it SUCKS there, on purpose.
#define TOD_MAGE_VS_HORDE        1.75   // lightning, its own family (+ CHAIN on top); 1.30 until 2026-09-09
// ⚠️ THESE TWO ARE THE UNINVESTED NUMBERS. Each is multiplied by its own card
// (FIRE BLAST x2.20 / ICE SHATTER x1.90 at Lv6 -- they are NOT the same rate,
// see TOD_MAGE_ICE_DMG_PER_LV) further down staff_mult, so
// raising fire raises its maxed figure by 2.2x as much. Calibrated 2026-09-08 so
// that Lv0 lands rank 3 and Lv6 lands rank 1; do not tune them against the maxed
// number alone or the uninvested state slides under the roster.
// [tod 2026-09-09] CEILING PASS (user: "Fire does way too much against the
// armored. Make it 15k tap. Most of the time you will hold it"; "Numbers look
// crazy ... I want this to be the best class but not like insanely the best.
// Especially late game its the best"). Tier 3 tap = 3,800 x 3.16 x this = 15,000
// (was 43,300 at 3.61); held x2.5 = 37,500; FIRE BLAST Lv6 x2.2 on top; tier-2
// tap 7,600. The same pass trimmed the ARCHMAGE ladder (arch_damage_mult) and the
// dark CHAIN arcs (chain_targets) -- the three mage-only multipliers that stacked
// a maxed staff to ~10x a maxed gun. Matchup lanes themselves are unchanged.
#define TOD_MAGE_FIRE_VS_ARMOUR  1.75   // fire on protector + armored sprinter; 3.61 -> 1.25 -> 1.75 on 2026-09-09 (playtest: "fire blast was too weak")
#define TOD_MAGE_ICE_VS_BEAST    2.85   // hellhound + Fury; 4.19 -> 3.352 -> 2.85 on 2026-09-09 (playtest: "ice a bit OP")
                                        // in v18.56: ice maxed is 87,925 now,
                                        // 72% of fire's 122,418 rather than the
                                        // 85% v18.55 left it at. It buys the
                                        // breadth above with its peak.
// OFF-FAMILY IS PER STAFF NOW (v18.56, user: "It should also be okay against
// panzers and all other enemies. Fire is the one thats pretty bad against
// anything but its weakness"). One shared 0.45 made all three staffs the same
// SHAPE -- a spike on one family and useless elsewhere -- so the only thing that
// distinguished them was which cell they spiked in. They are different KINDS of
// weapon now, and the off-family number is what says which:
//
//              own family      everything else     spread
//   FIRE        122,418            28,146           4.3x   THE SPIKE
//   ICE          87,925            61,904           1.4x   THE GENERALIST  (v18.56 figures; ICE_OFF went 2.36 -> 1.00 on 2026-09-09, see LANES above: ice is the BEAST staff now, okay on hordes)
//
// FIRE is the reward for reading the fight: nothing else in the map touches
// 122,418, and it is rank 5 the moment it is pointed anywhere else. ICE never
// wins big and never embarrasses you -- rank 1 on its own family, rank 4 on
// every other INCLUDING THE PANZER, which is the point: it is the staff you hold
// when you do not know what is coming.
//
// ⚠️ ICE'S IS ABOVE 1.0, so it is a BONUS, not a penalty -- see the guard in
// staff_mult. The staffs' raw damage sits far below the gun roster and ALL of
// their competitiveness comes from these multipliers, so "okay against
// everything" cannot be expressed by a number under 1.
#define TOD_MAGE_LIGHTNING_OFF   0.45   // it already owns TWO families
#define TOD_MAGE_FIRE_OFF        0.83   // pretty bad at anything but armour (the horde arm; beasts have their own constant below)
// 2026-09-09 playtest (user: "fire needs to be weaker against dogs and hounds"):
// fire on hellhound + Fury is its OWN arm and it is NOT gated on
// family_answerable -- a tier-2 mage has no ice staff yet, but it has
// lightning at neutral, so fire is never the hound answer at any tier.
#define TOD_MAGE_FIRE_VS_BEAST   0.2625 // 0.50 -> 0.35 (v18.77) -> 0.2625 (2026-09-21, user: "fire staff 25% weaker againts hounds and furys" = 0.35 x 0.75). Hounds + Furys are the "ice"/beast family. This STACKS with TOD_MAGE_FIRE_NERF 0.95, so fire lands at 0.7125 of its old damage on a beast.
#define TOD_MAGE_ICE_OFF         0.80   // 2026-09-09: 2.36 -> 1.00 (lanes) -> 0.80 (playtest); ice is okay on the horde, not the horde staff

// THE STAFF CARDS
// THE TWO STAFF CARDS NO LONGER SHARE A RATE (v18.55, user: "Ice Shatter should
// not be as good as the fire staff against the weakness but still solid").
//
// They were both +10%/Lv, which put fire and ice within 0.03% of each other at
// max -- two cards, one outcome, and no reason to prefer either. THE RATE IS THE
// ONLY LEVER THAT CAN SEPARATE THEM: the family multipliers are pinned by the
// uninvested half of the contract (rank 3, just under the Death Machine), so
// moving one of those drags the un-carded staff off the roster with it.
//
// And the split is what the cards already ARE, priced honestly. FIRE BLAST buys
// damage and a burn. ICE SHATTER buys damage AND CONTROL -- its level also runs
// the hit's 45% slow longer, 1.0 s + 0.4 s per level, so at Lv6 every ice hit
// holds a target for 3.4 s. A card that buys two things should pay less for the
// one they share, or the utility is free.
//
//   Historical pre-2026-09-09 figures (superseded by the card buffs below):
//   maxed, vs its own family:  FIRE 122,418  ·  ICE 104,082  (85% of fire)
//   rank 1 needs 84,749, so ice clears the best gun by 23% -- "still solid".
// v19.26 (user 2026-09-21): "fire blast should be 15% per level. Also it should
// apply burn to elites ... ice slow ability should only work for elites and
// also increase slow rate per level." The two cards now split by KIND, not
// only by rate: FIRE BLAST is damage + an ELITE BURN, ICE SHATTER is damage +
// an ELITE SLOW. Neither utility touches the horde any more.
#define TOD_MAGE_FIRE_DMG_PER_LV 0.15   // FIRE BLAST: +15% per level; +90% at Lv6 (0.20 until v19.26)
#define TOD_MAGE_ICE_DMG_PER_LV  0.15   // ICE SHATTER: +15% per level; +90% at Lv6
// DARK rungs for the two staff cards (2026-09-09, user: "there are no dark
// upgrades for the mage"). +50 points on the card multiplier, the DAMAGE
// card's own dark step: FIRE BLAST 1.90 -> 2.40, ICE SHATTER 1.90 -> 2.40.
#define TOD_MAGE_FIRE_DARK_ADD   0.50
#define TOD_MAGE_ICE_DARK_ADD    0.50
// THE ELITE BURN (v19.26). Every fire staff hit on an ELITE (the boss triad --
// Panzer, Rogue Protector, Reaver, hellhound, every Warden -- plus the armored
// sprinter) lights a burn that ticks a share of the victim's MAX health:
// 0.5% per FIRE BLAST level every 2 s, so Lv1 0.5% ... Lv6 3.0% per tick. No
// card, no burn. A fresh hit RESTARTS the burn at the shooter's current level
// (no stacking; the newest hit owns the clock), and it runs TOD_MAGE_BURN_TICKS
// ticks after the last hit -- 6 s, enough that a mage cycling staffs does not
// lose it between fire shots. Percent-of-max is the ONE kind of damage the
// Warden King's health wall cannot stop (Gift of Death and Wisp Tea both
// learned this and both carry a King divisor), so the King takes the burn at
// TOD_MAGE_BURN_KING_MULT of the rate -- 3.0% -> 0.75% per tick at Lv6, a
// ~4.4-minute solo burn-down instead of ~67 s. Trash is untouched: the fire
// staff's burn tell on the horde stays a visual.
#define TOD_MAGE_BURN_PCT_PER_LV  0.5    // % of maxhealth per tick per FIRE BLAST level
#define TOD_MAGE_BURN_TICK_MS     2000   // one tick every 2 s
#define TOD_MAGE_BURN_TICKS       3      // ticks after the LAST hit (6 s), refreshed per hit
#define TOD_MAGE_BURN_KING_MULT   0.25   // the Warden King burns at a quarter rate
// THE ELITE SLOW (v19.26, RESCALED 2026-09-21). ELITES ONLY, and the RATE
// climbs with the card as well as the duration.
// ⚠️ IT IS A BONUS, NOT A DEFINING FACTOR (user: "This is way too strong ...
// It was already a top tier staff. I just wanted another bonus to it").
// The v19.26 ladder ran 0.45 -> 0.27 (a 55% -> 73% slow) and made ice the
// control answer outright; it now runs 0.80 -> 0.65, a 20% -> 35% slow.
// TOD_MAGE_ICE_SLOW_MIN IS THE CAP THE USER NAMED (65% speed) and Lv6 lands
// exactly on it, so raising the level cap cannot make this stronger.
// Duration is unchanged: 1.0 s + 0.4 s per level. Elites drive a custom
// locomotion ASM, so the slow goes through tod_zombie_speed::slow_elite (the
// TRAILBLAZER / King-stagger lane); the armored sprinter is trash-flagged and
// takes the same numbers through slow(). The horde is no longer slowed at all.
#define TOD_MAGE_ICE_SLOW_MULT   0.80   // the ice hit's slow at Lv0 (20% slower) ...
#define TOD_MAGE_ICE_SLOW_MULT_PER_LV 0.025  // ... 0.025 stronger per ICE SHATTER level ...
#define TOD_MAGE_ICE_SLOW_MIN    0.65   // ... never below 65% speed = a 35% slow, the CAP (Lv6 sits on it)
#define TOD_MAGE_ICE_SLOW_BASE   1.0    // ... for 1.0 s + 0.4 s per ICE SHATTER level
#define TOD_MAGE_ICE_SLOW_PER_LV 0.4
// THE FIRE STAFF'S CHARGE (v18.36, user: "it needs to do more damage the longer
// it's charged, and it can't just be linear ... a little bit more than linear.
// Not exponential"). The ENGINE owns the charge INPUT (fireType "Charge Shot"
// holds the shot until release); it does not scale damage, because a charge
// LEVEL resolves to a separate weapon def and the ledger has no room for one.
// So the payoff is script-side: the hold is timed here and the multiplier is
// applied in staff_mult, on the one damage chain this map has.
//
// THE CURVE. frac^EXP with EXP just above 1 is "a little more than linear":
// at half charge you get 38% of the bonus, not 50%, so the last third of the
// hold is where it pays -- which is what makes holding feel worth it. EXP 2+
// would be the exponential the user ruled out.
#define TOD_MAGE_CHARGE_MIN_MS   200    // below this it is a tap, no bonus (matches chargeShotMinTime 0.20)
#define TOD_MAGE_CHARGE_FULL_MS  900    // full charge (matches chargeShotMaxTime 0.90)
#define TOD_MAGE_CHARGE_BONUS    1.50   // full charge = x2.5 damage
#define TOD_MAGE_CHARGE_EXP      1.40   // the "a bit more than linear" bend
#define TOD_MAGE_CHARGE_KEEP_MS  1500   // a charge is spent on the shot it launched, not the next one
#define TOD_MAGE_FIRE_RECOVERY_MS 1573 // shot cooldown; independent of the short native firing state
// RAPID FLAME (domain 57, v19.25, 2026-09-21) - user: "I want to add a firerate
// upgrade card for the fire staff. 5 levels 10% each level."
//
// LINEAR ON THE COOLDOWN, which is this map's convention for every rate ladder
// it already ships (the skirmisher's FIRE RATE card is "-8% fire time / Lv" and
// HEADSHOT is "+12% / Lv" - both straight multiples of the base, not compounded
// steps). So Lv5 is -50% of the cooldown, not 0.9^5:
//
//   Lv  0     1      2      3      4      5
//   ms  1573  1415   1258   1101   943    786
//   /s  0.64  0.71   0.79   0.91   1.06   1.27       = DOUBLE the shots at Lv5
//
// THAT IS A BIG CARD AND IT IS MEANT TO BE - it is the fire staff's only
// throughput knob, against FIRE BLAST's +120% damage on the same six picks.
// Judge them together in the armory's mage rows before retuning either.
//
// WHY THIS IS PURE SCRIPT AND THE ICE STAFF'S DOUBLE TAP COULD NOT BE: the fire
// staff's cadence is OURS (the DisableWeaponFire controller below), because
// fire is a `Charge Shot` weapon whose every shot is a fresh trigger press the
// flag is read on. The ice staff is `Single Shot` on the engine's own fireTime
// and needed a second weapon asset. Same feature, two different lanes, and the
// reason is the fireType - not a preference.
#define TOD_MAGE_FIRE_RATE_PER_LV 0.10  // -10% of the BASE cooldown per level
#define TOD_MAGE_FIRE_RATE_MAX_LV 5     // LOCKSTEP: add_domain( "mage_rate", ... 5 ) + Lua DOMAIN[57].max
// v18.99c — ICE IS BACK ON ITS NATIVE fireTime AND OFF THIS CONTROLLER.
// (0.8 s since v18.99d — user: "Move the ice staff to 0.9s per shot then",
// then "0.8s actually". The cadence and the post-shot weapon-switch pause are
// THE SAME NUMBER, so that call buys back 0.31 s of both at once. It is also a
// ~39% rate buff on the ice staff, which is a real damage change; see the
// armory's mage rows before retuning anything else on this staff.)
// v18.94 moved ice here to free the weapon switch, copying the fire staff. IT
// DOES NOT TRANSFER, and the user named the reason: "They worked for the fire
// staff because it had a charge up shot where the ice staff doesn't." FIRE is
// `fireType Charge Shot` — the engine fires on RELEASE, so the player must
// press again for every shot and DisableWeaponFire is read on that press. ICE
// is `Single Shot`: with fireTime cut to 0.1 the engine's own gate was 0.1 s
// and the script flag did not hold the next press, so the staff fired as fast
// as the trigger could be clicked ("we made the rate of fire super super
// fast"). The cadence is the ENGINE's again — one owner, no race, and exactly
// the engine's own gate, one number, no race.
// THE COST IS KNOWN AND IS NOT A BUG: the engine holds the weapon switch for
// the firing state, so the post-shot switch pause comes back with the timing.
// The only native lever that could give both is a SHORT fireTime plus
// `shotsBeforeRechamber` 1 + `rechamberTime` ~1.01 (the bolt-action split,
// both fields present on this asset and both 0 today) — UNPROVEN on a
// projectileweapon here, so it is not being guessed at in a publish build.

#define TOD_MAGE_CHAIN_RADIUS    220    // CHAIN LIGHTNING arcs to zombies this close to the hit
#define TOD_MAGE_CHAIN_FRAC      0.50   // base share of the already-scaled hit
#define TOD_MAGE_CHAIN_DMG_PER_LV 0.05 // bonus to the half-damage base, not percentage points
#define TOD_MAGE_CHAIN_MAX       10

// HEALING AURA (domain 52). A PULSE TRAIN, NOT A ONE-SHOT: ten ticks over five
// seconds is what lets a teammate RUN INTO a running aura. LEVEL 6 REVIVES one
// downed teammate per cast -- the "revive staff", as the capstone of a domain
// that already exists.
// ---- THE LETHAL SLOT, MANA AND DEMIGOD (v18.37, user 2026-09-08) ----------
//
// "I need to move the healing move into the lethal spot. So mages will have no
// grenades ... they'll get up to three uses, and it'll recharge over time. And
// it'll max out at three, but that'll depend on what level your ability is."
//
// So HEALING AURA is the mage's LETHAL: press the lethal button to cast, and
// the domain level buys CHARGES rather than a shorter cooldown. Grenades are
// taken from the class entirely (DisableOffhandWeapons on arm), which is what
// frees the button -- the same lane the card panel uses to hold offhands.
#define TOD_MAGE_CHG_RECHARGE_S  22     // seconds per charge regained (x cooldown_scale(), a flat 1.0 since ATTUNEMENT was retired in v18.41)
#define TOD_MAGE_CHG_MAX         3      // the ceiling the user set

// ---- BLINK (domain 55) ----------------------------------------------------
// A SHORT TELEPORT, not a dash. See the header of this build's patch note: a
// grounded velocity write is overwritten by the movement code every frame
// (memory per-player-movement-levers), so a dash would have to re-assert
// SetVelocity every 50 ms for its whole flight, with the player a passenger
// resolving collision mid-air over a 19,000-unit stairwell. SetOrigin is one
// write, it is the lane this map's teleporters already use, and the landing
// spot is chosen by a trace BEFORE anyone moves.
//
// LEVEL 0 STILL WORKS, like ARCHMAGE: the card buys distance and
// a shorter wait, it does not unlock the move.
#define TOD_MAGE_BLINK_DIST      280    // level 0 reach ...
#define TOD_MAGE_BLINK_DIST_LV   40     // ... + this per level (Lv5 = 480)
#define TOD_MAGE_BLINK_CD        9      // level 0 cooldown, seconds ...
#define TOD_MAGE_BLINK_CD_LV     1      // ... - this per level (Lv5 = 4 s)
#define TOD_MAGE_BLINK_RECHARGE_SCALE 1.8   // 1.5 -> 1.8 on 2026-09-09 (playtest: "blink recharges a bit too fast"); Lv1..5 base 14.4/12.6/10.8/9/7.2 s
#define TOD_MAGE_BLINK_BACKOFF   28     // stop this far short of whatever the trace hit
#define TOD_MAGE_BLINK_DROP      420    // refuse a landing with no floor within this
#define TOD_MAGE_BLINK_RISE      40     // trace at knee height, not at the feet
#define TOD_MAGE_BLINK_STEP      16     // resample ground before a stair can meet the knee trace
#define TOD_MAGE_BLINK_STEP_UP   18     // allow stair risers, never climb a wall or rail

// "a mana bar that is used in place of the ammo section ... as you get kills, it
// goes up ... one point per second, and you get one point per kill ... max is
// 100. Then you can use your demigod move."
//
// DELIBERATELY PLAIN NUMBERS FOR NOW (user: "You can build the mana bar out with
// numbers for now"). The real bar is baked art + a LUI widget in the ammo bay;
// this is the mechanic underneath it, so the art lands on a working system.
#define TOD_MAGE_MANA_MAX        100
// v19.11 — how many casts of an ability before its on-HUD control hint retires
// (per ability, per player, for the match; the counts live on the player
// entity so they survive a death). The Lua mirrors the number: TUT_USES in
// AetheriumLoadout.lua — LOCKSTEP.
#define TOD_MAGE_TUT_USES        3
#define TOD_MAGE_MANA_PER_SEC    0.8    // 1 -> 0.8 on 2026-09-09 (playtest: "archmage recharges a bit too fast")
// RETIRED 2026-09-09, kept as the record of what the flat rate was: kills now
// pay mana_per_kill(), normalised by the round's zombie count. NOTHING READS IT.
#define TOD_MAGE_MANA_PER_KILL   1
// ARCHMAGE (domain 54, six levels + a dark 7th, S tier). FOUR things scale:
// DAMAGE, DURATION, MOVE SPEED and how fast the bar refills.
//   Lv1   x1.30 /  8s / +15% speed / 1.25 mana/s / 50 per round share
//   Lv3   x1.75 / 13s / +23% speed / 1.75 mana/s / 70 per round share
//   Lv6   x2.20 / 16s / +30% speed / 2.50 mana/s / 100 per round share
//   DARK  x2.70 / 20s / +45% speed                 (the 7th rung; see below)
// The per-second column fills 100 in 100 s at Lv0 and 40 s at Lv6. The kill
// column is NORMALISED by the round's zombie count, so "per round share" is
// what clearing your fair share of ANY round pays -- see the budget define.
// Lv0 is UNREACHABLE in play -- the first card is what unlocks activation at all
// (demigod_try gates on ready("mage_arch")) -- so it exists only as the tables'
// zero entry and demigod_mult's floor.
// [tod 2026-09-09] DURATION IS A TABLE AND IT STARTS AT 8 (user: "Duration
// starts at 8, 11, 13, 14, 15, dark is 18", Lv6 = 16 confirmed separately since
// that list covered Lv1-Lv5; dark then raised to 20 the same evening). It was
// 15 + 2/Lv = 17s..27s, so this HALVES the form early and still cuts a third
// off the top. Increments +3/+2/+1/+1/+1 decelerate like damage and speed.
#define TOD_MAGE_DEMIGOD_SECS     8     // the lv0 floor; see arch_duration()
#define TOD_MAGE_ARCH_DARK_SECS   4     // dark: 16 -> 20 s at Lv6
// [tod 2026-09-08] THE LADDER STARTS AT 100%, NOT 200% (user: "No damage should
// be 130%, etc. Not 230% to start"). This was x2.0 -- the form DOUBLED damage
// before a single card -- and the 30/25/20/15/15/15 increments were then stacked
// on top, so Lv1 read x2.30. They now build from x1.00, so the increments ARE
// the bonus: Lv1 x1.30 ... Lv6 x2.20.
#define TOD_MAGE_DEMIGOD_MULT    1.0
// [tod 2026-09-08] THE DAMAGE RAMP DECELERATES (user: "Damage needs a way slower
// ramp. 30%, 25%, 20%, 15%, 15%, 15%"). It was a flat +0.20/Lv; the increments
// are now 30/25/20/15/15/15 points of multiplier, so the first card is worth
// twice the last. Same idiom as speed_pct_for_level's 5/4/3/3/3 ladder.
// DARK IS THE 7TH RUNG, NOT A PER-LEVEL BONUS: dark_pool only offers a dark card
// once get_level >= domain_max, and a domain reset clears the flag -- so x2.70
// is reachable ONLY on top of a maxed Lv6. There is no x1.80 state.
#define TOD_MAGE_ARCH_MAX        6
#define TOD_MAGE_ARCH_DARK_MULT  0.50   // dark: +0.50 multiplier  -> x2.35 on the 1.85 top (x2.70 before the ceiling pass)
// [tod 2026-09-08] ARCHMAGE MOVES YOU FASTER (user: "Archmage upgrade use will
// now enhance speed"). MOVE-SCALE POINTS, not a percentage of your own speed —
// apply_move_speed ADDS every bonus to the scale so one card is worth the same
// to every class (see its header). The mage's base is 1.00, so the form runs at
// 1.12 with the first card and 1.22 at Lv6 — between an assault at full FORCED
// MARCH (1.08) and a slasher (1.33), for 15-27 s.
// The speed ladder decelerates the same way and TOPS OUT AT +30% (user: "Move
// speed max at 30% dark 15% so 45% max max"). Increments 5/4/4/3/2/2 from the
// 10 an activation is worth on its own. Lv0 is unreachable -- the first card is
// what unlocks activation at all -- so the range a player sees is +15%..+30%,
// or +45% with the dark rung.
#define TOD_MAGE_ARCH_DARK_SPEED 0.15   // dark: +0.15 scale points -> +45% at Lv6
#define TOD_MAGE_ARCH_MANA_LV    0.25   // + this much mana PER SECOND per level (user: "lowers mana timer")
// ... and the same again PER KILL (v18.51). THIS IS THE CLASS'S VERY-LATE-GAME
// ENGINE, and it is the only one, so it is worth saying what it is for.
//
// The per-SECOND half is a constant: it pays a mage standing in an empty room
// exactly what it pays one in a trial, so it cannot express "later is stronger".
// The per-KILL half is the opposite -- it is fed by how much is in front of you,
// and that is precisely what deepening rounds and the spire's trials supply.
// Kills are already worth mana; each ARCHMAGE level now makes them worth more.
//
// At Lv6 a kill is worth 2.5 mana instead of 1, and the bar refills in:
//   early-mid (~0.4 kills/s)   29 s -> ARCHMAGE up 49% of the time, avg x2.07
//   late      (~1.2 kills/s)   18 s -> up 60%, avg x2.31
//   very late (~3.0 kills/s)   10 s -> up 73%, avg x2.61
// So the SAME maxed card is worth about a quarter more at spire depth than in
// the tower, on top of a tier-3 class that already ranks second. Nothing else
// in the kit scales with the round; without this the class simply stops
// climbing once the ladder above runs out.
// [tod 2026-09-09] MANA PER KILL IS NORMALISED BY THE ROUND'S ZOMBIE COUNT,
// exactly like the luck bar (user: "the bar for arch mage should match the round
// volume like the luck bar does ... how long it takes to fill depending on
// amount of zombies in the rounds").
//
// It was a FLAT 1 + 0.25/Lv per kill, so a round's contribution scaled with the
// round: ~40 mana from a 40-zombie round and ~200 from a 200-zombie spire round.
// The bar therefore filled faster and faster the deeper you went, for no reason
// a player chose. Now a fair-share round clear pays TOD_MAGE_MANA_KILL_BUDGET
// whatever the round number or lobby size, on the same
// budget x players / round_total shape as TOD_LUCK_KILL_BUDGET.
//
// ⚠️ THIS IS A NERF AT DEPTH BY DESIGN, and it voids the armory's old
// "10 s to refill at spire depth" figure. The per-SECOND half is untouched.
//
// TOD_MAGE_ARCH_MANA_KILL_LV CHANGED MEANING with it: it was +0.25 mana per kill
// per level (1 -> 2.5 at Lv6); it is now a +25%/level MULTIPLIER on the budget,
// which is the same 1x -> 2.5x ratio expressed against a moving base.
#define TOD_MAGE_MANA_KILL_BUDGET  32   // a fair-share round clear, at Lv0; 40 -> 32 on 2026-09-09 with the per-second cut
#define TOD_MAGE_ARCH_MANA_KILL_LV 0.25
// [tod 2026-09-09] ELITES AND PANZERS ARE WORTH A CHUNK OF THE BAR (user:
// "Elite and panzer kills fill mana more than zombies. Like a good chunk. Maybe
// 5% per elite and 15% per panzer. but late game this is OP so we need to scale
// properly so it doesnt go crazy").
//
// A flat 5/15 would go crazy exactly where the user said: the Protector wave
// is players x round / 3 (cap 8) every third round, a trial drops up to four
// Wardens plus adds, and the spire's honour guard is a Panzer per door. So the
// reward is FULL through round TOD_MAGE_MANA_ELITE_FULL_ROUND and then decays
// as FULL_ROUND / round, with a floor of TOD_MAGE_MANA_ELITE_FLOOR of the
// base value so a late elite is never worthless:
//   elite   5.00 to round 10, 2.50 at 20, 1.67 at 30, 1.25 from 40 on
//   panzer 15.00 to round 10, 7.50 at 20, 5.00 at 30, 3.75 from 40 on
// A capped 8-Protector wave is therefore ~15-20 mana at any depth rather than
// 40, and a four-Warden trial ~15 from the Wardens themselves. Paid to the
// KILLER only (same rule as the elite money), NOT scaled by ARCHMAGE level --
// the class's depth engine is the per-round budget above, and this is a
// bounded bonus on top of it. The bar's own rules still apply: no gain before
// the first ARCHMAGE card and none while the form is running.
// [tod 2026-09-09] LIGHTNING NERF (user: "nerf lightning staff damage by 10% and
// pap version by 20%"). Applied in staff_mult to the lightning element only,
// AFTER tier/matchup (lightning has no damage card): unpacked hits are x0.90
// of before; a packed staff (pap_tier >= 1, any PACK level) is x0.80 of its
// previous packed value -- the second define is the packed TOTAL, not a step
// on top of the first. Chain shares are cut from the scaled hit, so they
// follow. Panzer/horde matchup constants and the GDT 215 are untouched.
// [tod 2026-09-09] ICE NERF (user: "Ice staff needs to be super weak against
// armored and robots. Like 30% of current damage. And also it needs another 20%
// damage nerf"). Both in staff_mult, ice element only, after tier/matchup and
// the ICE SHATTER card: x0.80 on every target, and ANOTHER x0.30 when the
// victim is the armour family (Rogue Protector, armored sprinter -- what
// victim_family calls "fire") or the Panzer, so those land at x0.24 of before.
// The beast matchup (hellhound / Fury) and horde keep the full x0.80. The
// ICE_VS_BEAST / ICE_OFF constants above are left as they were so the ranking
// record stays readable; these two are cuts ON TOP of them.
// FIRE: -5% on every fire hit (user 2026-09-21: "Fire should be 5% weaker").
// Its own constant rather than the shared ladder, because the same message
// left lightning alone and cut ice only on two families.
#define TOD_MAGE_FIRE_NERF          0.95
// ICE: -10% against the HORDE and the PANZER ONLY (user 2026-09-21: "Ice 10%
// weaker to zombies and panzers specifically"). ⚠️ THE HORDE'S FAMILY STRING
// IS "lightning", not "zombie" -- victim_family() names each family after the
// staff that owns it, so ordinary trash reads as "lightning". Beasts and the
// armour family are deliberately untouched by this one.
#define TOD_MAGE_ICE_VS_HORDE_PANZER 0.90
#define TOD_MAGE_ICE_NERF           0.646  // 0.68 -> 0.646 (x0.95) 2026-09-23, user: "now that the ice staff can get double tap ... nerf the ice staff's damage another five percent". WAS: all ice hits, vs before; 0.80 -> 0.68 (v18.77, user 2026-09-10: three piercing missiles hit whole hordes -- "a nerf is needed damage wise")
#define TOD_MAGE_ICE_VOLLEY_START 88   // v18.93: side-missile launch distance from the eye (tip tag_flash ~40 + 48 shift)
// 2026-09-09 (user: "Ice is now too weak against panzer and armored" after
// ICE_OFF went to 1.00): 0.30 -> 0.60. Tier 3 per missile = 2,200 x 3.16 x 1.00
// x 0.80 x 0.60 = 3,340/s (close volley ~5,800): 13% of lightning on the Panzer,
// 35% of fire's new tap on armour. Weak, not nothing.
#define TOD_MAGE_ICE_VS_ARMOUR_ROBOT 0.35  // extra, armour family + Panzer; 0.30 until 2026-09-09, 0.60 until v18.77 (user 2026-09-10: "still too strong against protectors and armored")
#define TOD_MAGE_LIGHTNING_NERF     0.90   // unpacked lightning, vs before
#define TOD_MAGE_LIGHTNING_PAP_NERF 0.80   // packed lightning, vs before
#define TOD_MAGE_MANA_ELITE            5     // per elite kill, at full value
#define TOD_MAGE_MANA_PANZER           15    // per Panzer kill, at full value
#define TOD_MAGE_MANA_ELITE_FULL_ROUND 10    // full value through this round
#define TOD_MAGE_MANA_ELITE_FLOOR      0.25  // never below this share of full

#define TOD_MAGE_RELOAD_MANA 5   // complete a staff reload to recover 5/100 mana
// v18.77 — THE LIGHTNING STAFF RELOADS EVERY N SHOTS (user 2026-09-10: "needs
// to reload every 15 shots to avoid spamming. Still has unlimited but we need
// to track shots so we can force a reload. Any reload will reset the invisible
// counter"). The clip is normally pinned one short so the reload is optional
// (staff_ammo_watch); at N lightning shots the pin becomes ZERO instead, the
// engine refuses to fire an empty clip and its own trigger-pull auto-reload
// takes over -- no script animation, no forced switch. reload_start (ANY
// staff, ANY reload, finished or not) resets the count and lifts the pin.
// Lightning only: fire and ice have their own cadence brakes.
// 2026-09-11: 15 -> 20 at the user's word. THE DOUBLE RELOAD reported with it
// was NOT this counter: the staffs are segmentedReload with reloadAmmoAdd 999
// against clipSize 1000, so a reload that starts EMPTY came up one round short
// and the engine ran a second segment to top it off. Fixed in
// source_data/tod_staff.gdt (reloadAmmoAdd = clipSize). The optional reload
// never showed it: it starts at clipSize-1 and clamps full on the first pass.
#define TOD_MAGE_BOLT_SHOTS_PER_RELOAD 20
// v18.76 — PACED. staff_ammo_watch pins the clip one short so an optional
// reload is always available, and a 1.5 s reload paid 5 mana every time: ~3.3
// mana/s standing still against the 0.8/s passive tick, a full bar in ~30 s of
// mashing R. The reward now lands at most once per this window (0.5 mana/s at
// the limit); the reload itself is never refused, only re-paid.
#define TOD_MAGE_RELOAD_MANA_WINDOW_MS 10000

#define TOD_MAGE_HEAL_MAX        6
// DARK HEALING AURA (2026-09-09): a seventh rung the cast reads when the
// player holds the dark card -- 20 HP/s and 65% resistance for the same
// five seconds. Charges, radius and the Lv6 revive are unchanged.
#define TOD_MAGE_HEAL_DARK_LV    7
#define TOD_MAGE_HEAL_DARK_HP    3.25   // on top of the Lv6 9.75 HP/s -> 13
#define TOD_MAGE_HEAL_DARK_DR    0.0325 // on top of the Lv6 39% resistance -> 42.25%
// THE AURA'S CONTRACT (v18.38, user 2026-09-08: "healing aura should work in a
// radius and affect your team as well. It grants 10HP per second and 50% damage
// reduction while in radius of the player. Lasts for 5 seconds").
//
// FLAT HP, NOT A SHARE OF MAX. Every earlier version healed a fraction of each
// target's own maxhealth, which quietly made the aura worth more to a VITALITY
// heavy than to the mage. Each aura now uses its caster's latched card level:
// 10-15 HP/s and 50-60% resistance over Lv1-6, the same for all recipients.
// 2026-09-09 playtest ("healing aura was crazy. Probably needs a 35% nerf"):
// every strength number x0.65. HP/s 10..15 -> 6.5..9.75, resistance 50..60%
// -> 32.5..39%, dark 20 / 65% -> 13 / 42.25%. Fractional HP/s is fine:
// heal_tick_amount already carries the running total as int() steps.
#define TOD_MAGE_HEAL_HP_PER_SEC 6.5
#define TOD_MAGE_HEAL_HP_PER_LV  0.65   // Lv1-6: 6.5 / 7.15 / 7.8 / 8.45 / 9.1 / 9.75 HP per second (was 10..15)
#define TOD_MAGE_AURA_DR_PER_LV  0.013  // +1.3 points resistance after Lv1 (was 2)
#define TOD_MAGE_AURA_DR         0.675  // damage TAKEN multiplier inside the radius = 32.5% resistance (was 0.50)
#define TOD_MAGE_AURA_GRACE_MS   700    // a stamp lasts this long -- longer than one 500ms tick, so the DR never flickers between pulses

#define TOD_MAGE_HEAL_TICKS      10
#define TOD_MAGE_HEAL_TICK_SECS  0.5
#define TOD_MAGE_HEAL_REVIVE_LV  6
// THE AURA'S GROUND AREA (2026-10-01, docs/167 item 1, second pass) - heal_area_start.
#define TOD_MAGE_HEAL_AREA_PITCH -90   // the host faces UP: a flat effect's forward is the ground's up (dom.csc)

// ---- STATE ----------------------------------------------------------------

function init()
{
	// THE GATE. At TOD_MAGE_ENABLED 0 this registers NOTHING -- no callback,
	// no level pointer. Do NOT "simplify" it into a per-player check.
	if ( !TOD_MAGE_ENABLED )
		return;

	level._effect[ "tod_mage_heal" ]     = "tod/mage/fx_healing_aura_player";
	foreach ( r in array( 256, 288, 320, 352, 384, 416 ) )   // LOCKSTEP: heal_radius()
		level._effect[ "tod_mage_heal_area_" + r ] = "tod/mage/fx_healing_aura_area_" + r;
	level._effect[ "tod_mage_chain" ]    = "tod/mage/fx_staff_lightning_chain_clean";
	level._effect[ "tod_mage_blink" ]    = "zombie/fx_bgb_anywhere_but_here_teleport_zmb";

	// GUARDED LEVEL POINTERS, never a #using from _tod_upgrades / _tod_bosses
	// (both are imported by this module -- a call the other way is a cycle).
	level.tod_mage_elite_mana   = &elite_mana;
	level.tod_mage_max_ammo     = &max_ammo;
	level.tod_mage_staff_mult   = &staff_mult;
	level.tod_mage_on_kill      = &on_kill;
	level.tod_mage_aura_dr      = &aura_dr;
	level.tod_mage_staff_hit    = &staff_hit;
	level.tod_mage_pierce_armor = &pierce_armor;

	// THREE STAFFS NEED THREE PRIMARY SLOTS (plus the start pistol). Stock's
	// limit is 2 + Mule Kick, read through this pointer by every stock give
	// path (_zm_utility::get_player_weapon_limit). Nothing else on the map sets
	// it (grep'd 2026-09-07), so this is the one owner; non-mages get stock's
	// own answer back.
	level.get_player_weapon_limit = &weapon_limit;

	callback::on_spawned( &on_player_spawned );
	level thread arch_bar_watch();
}

// A four-player snapshot reaches EVERY controller, not just the caster.
// Send on changes and every two seconds for late joins / reconstructed HUDs.
// Color animation stays in LUI; no clientfield bits or per-color network spam.
function arch_bar_watch()
{
	previous = -1;
	aura_prev = -1;
	refresh = 0;
	for ( ;; )
	{
		players = GetPlayers();
		mask = 0;
		foreach ( player in players )
		{
			index = player GetEntityNumber();
			if ( index < 0 || index > 3 || !IsAlive( player ) )
				continue;
			if ( IS_TRUE( player.tod_mage_demigod ) && IS_TRUE( player.tod_mage_armed )
			  && !player laststand::player_is_in_laststand() )
				mask += int( pow( 2, index ) );
		}
		// THE AURA MASK RIDES THE SAME WATCHER (2026-09-09, user: "when your
		// teammates are inside I don't see their HP bar turn green"). The green
		// only ever reached the protected player's OWN bar: aura_bar() notifies
		// self, and TodHealthTint accepts tod_mage_aura on the local widget only,
		// so a party row had nothing to read. Same four-player snapshot shape as
		// the ARCHMAGE mask, same change-gate, same two-second hydrate; the
		// per-player edge notify stays because the local bar reads it first.
		aura = 0;
		foreach ( player in players )
		{
			index = player GetEntityNumber();
			if ( index < 0 || index > 3 || !IsAlive( player ) )
				continue;
			if ( isdefined( player.tod_mage_aura_bar ) && player.tod_mage_aura_bar == 1 )
				aura += int( pow( 2, index ) );
		}
		if ( mask != previous || aura != aura_prev || GetTime() >= refresh )
		{
			foreach ( player in players )
			{
				player LuiNotifyEvent( &"tod_arch_bars", 1, mask );
				player LuiNotifyEvent( &"tod_aura_bars", 1, aura );
			}
			previous = mask;
			aura_prev = aura;
			refresh = GetTime() + 2000;
		}
		wait 0.1;
	}
}

function weapon_limit( player )
{
	if ( isdefined( player ) && isdefined( player.tod_class ) && player.tod_class == "mage" )
		return 4;
	limit = 2;
	if ( isdefined( player ) && player HasPerk( "specialty_additionalprimaryweapon" ) )
		limit++;
	return limit;
}

function on_player_spawned()   // self = player
{
	self endon( "disconnect" );
	self.tod_mage_cd = [];   // key -> GetTime() the aura is ready again
	self.tod_mage_blink_charges = undefined;
	self.tod_mage_blink_cap = undefined;
	self bolt_reload_reset();   // v18.77: a fresh body starts a fresh count
	self thread class_arm_watch();
}

// THE DRAFT LANDS ON AN ALREADY-SPAWNED PLAYER, so a class test taken at spawn
// is taken before the player has a class at all (memory
// class-check-at-spawn-is-always-wrong). Arm on the SIGNAL: tod_class_assigned
// is fired by assign_class, the ONE site every path goes through.
function class_arm_watch()   // self = player
{
	self endon( "disconnect" );
	self notify( "tod_mage_arm_watch" );
	self endon( "tod_mage_arm_watch" );

	for ( ;; )
	{
		cls = tod_classes::get_class( self );
		is_mage = isdefined( cls ) && cls.key == "mage";

		if ( is_mage )
		{
			// THE STAFFS HAVE NO AIM-DOWN-SIGHTS: aim activates ARCHMAGE.
			// Set the stock FIELD as well as calling AllowAds:
			// enable_player_move_states re-enables ADS on every Pack-a-Punch
			// and every perk buy, and it reads _allow_ads to decide whether to.
			self._allow_ads = false;
			self AllowAds( false );
			// NO GRENADES FOR THE MAGE. This is what frees the lethal button for
			// HEALING AURA; it is the same call the card panel uses to hold
			// offhands, and stock re-enables offhands on some paths, so the
			// ability watcher re-asserts it.
			self DisableOffhandWeapons();
			self thread ability_watch();
			self thread glow_watch();
			self thread charge_watch();
			self thread fire_recovery_watch();
			// v19.25 dev diagnostics: RAPID FLAME's cooldown and the ice staff's
			// Double Tap twin, both change-gated. Returns immediately off dev.
			self thread cadence_watch();
			self thread shot_id_watch();
			self thread ice_volley_watch();
			self thread mana_watch();
			self thread dev_arch_first_fill();   // tod_dev_arch_test only; returns at once otherwise
			self thread reload_mana_watch();
			self thread staff_ammo_watch();
			self thread mage_hud_watch();
			self thread cd_pause_watch();
			// Force the first push through the change-gate, so the ammo bay
			// switches to the bar the moment the class does rather than on the
			// next value change.
			self mana_forget();

			if ( IS_TRUE( level.tod_dev ) || IS_TRUE( level.tod_god ) || IS_TRUE( level.tod_dev_money ) )
				self IPrintLnBold( "^2[mage] staffs armed" );
			// v18.76 — ONE hint, once per player, and only while there is
			// something locked to explain: the bar is empty and both tiles are
			// dim until the first ARCHMAGE / HEALING AURA / BLINK card, and every
			// refusal is silent by design (2026-09-09). A HUD toast (v19.58,
			// TOD_TOAST_MAGE_HINT; was IPrintLnBold), no hint slot.
			if ( !IS_TRUE( self.tod_mage_hint_shown ) && ( self arch_level() < 1 || self charges_max() < 1 || self blink_capacity() < 1 ) )
			{
				self.tod_mage_hint_shown = true;
				self thread mage_first_hint();
			}
		}
		else if ( IS_TRUE( self.tod_mage_armed ) )
		{
			// Switched away from mage: hand ADS back ONLY to a player we took
			// it from -- never touch another class's state.
			self notify( "tod_mage_disarm" );
			self._allow_ads = undefined;
			self AllowAds( true );
			self EnableOffhandWeapons();
			self mage_hud_hide();
			// STATE 2: put the clip/reserve numbers back. Without this the new
			// class would carry the mage's bar over its own ammunition.
			self mana_forget();
			self mana_send( 0, 2 );
			self clientfield::set_to_player( TOD_STAFF_GLOW_FIELD, 0 );
		}

		self.tod_mage_armed = is_mage;
		self tod_upgrades::apply_sprint_fire();
		self waittill( "tod_class_assigned" );
	}
}

// v18.76 — the first-arm hint (see class_arm_watch). Delayed past the draft's
// own toasts so it is not lost under them; endon disarm so a quick re-draft to
// another class never prints a mage line on it.
function mage_first_hint()   // self = player
{
	self endon( "disconnect" );
	self endon( "tod_mage_disarm" );
	wait 4;
	self tod_upgrade_ui::toast( TOD_TOAST_MAGE_HINT );   // v19.58: map typeface
}

// ---- ABILITY BUTTONS ------------------------------------------------------

function ability_watch()   // self = player
{
	self endon( "disconnect" );
	self notify( "tod_mage_ability_watch" );
	self endon( "tod_mage_ability_watch" );
	self endon( "tod_mage_disarm" );

	tick = 0;
	for ( ;; )
	{
		wait 0.05;

		// A MENU OWNS THE BUTTONS (the card panel polls ads AND the offhand
		// pair); a crawler casts nothing.
		if ( IS_TRUE( level.tod_upgrade_pause ) || IS_TRUE( self.tod_menu_frozen ) )
			continue;
		if ( self laststand::player_is_in_laststand() )
			continue;
		// THE CO-OP ALTAR PANEL (bug review 2026-09-22, F10): the live-world
		// station lane sets neither flag above, only tod_solo_upg_active, and
		// its card switch reads the same offhand pair — so comparing cards
		// cast Blink and Healing Aura. A spectator casts nothing either (F11):
		// bleed-out never sends "death", so the watcher outlived the body.
		if ( IS_TRUE( self.tod_solo_upg_active ) )
			continue;
		// A ROCKET RIDER (2026-10-02 review): linked to the ride's camera with
		// nothing under them - an aura, a Blink or the Archmage form cast from
		// the sky would go off beside every rider's camera. Cast after landing.
		if ( IS_TRUE( self.tod_rocket_riding ) )
			continue;
		if ( !IsAlive( self ) || ( isdefined( self.sessionstate ) && self.sessionstate != "playing" ) )
			continue;

		// The keepers: stock re-enables ADS and the offhands behind our back on
		// a PaP or a perk buy. 5 Hz is plenty for both.
		tick++;
		if ( tick >= 4 )
		{
			tick = 0;
			self._allow_ads = false;
			self AllowAds( false );
			self DisableOffhandWeapons();
		}

		// LETHAL = HEALING AURA (v18.37).
		if ( self FragButtonPressed() )
		{
			self cast_heal();
			while ( self FragButtonPressed() )
				wait 0.05;
			continue;
		}

		// TACTICAL = BLINK. The button is free precisely because this class has
		// no grenades (DisableOffhandWeapons on arm), so nothing else can want it.
		if ( self SecondaryOffhandButtonPressed() )
		{
			self cast_blink();
			while ( self SecondaryOffhandButtonPressed() )
				wait 0.05;
			continue;
		}

		// AIM = DEMIGOD, and only on a full bar.
		if ( self AdsButtonPressed() )
		{
			self demigod_try();
			while ( self AdsButtonPressed() )
				wait 0.05;
		}
	}
}

// PUBLIC -- the incoming-damage multiplier for a player standing in a healing
// aura RIGHT NOW. Read by BOTH of _tod_bosses' player-damage lanes, beside
// tod_upgrades::dr_mult, which is the one place this map applies mitigation.
// Called through a guarded level pointer: _tod_bosses does not import this
// module and must not (the KB cycle rule).
// Dark improves strength, while retaining the maximum normal radius.
function heal_radius( lv )
{
	if ( lv < 1 ) lv = 1;
	if ( lv > TOD_MAGE_HEAL_MAX ) lv = TOD_MAGE_HEAL_MAX;
	return ( array( 256, 288, 320, 352, 384, 416 ) )[ lv - 1 ];
}

// Pure per-cast strengths. Level 1 preserves the original aura.
function heal_hp_per_second( lv )
{
	if ( lv < 1 ) lv = 1;
	if ( lv > TOD_MAGE_HEAL_DARK_LV ) lv = TOD_MAGE_HEAL_DARK_LV;
	if ( lv > TOD_MAGE_HEAL_MAX )   // the dark rung: Lv6 plus the dark step
		return TOD_MAGE_HEAL_HP_PER_SEC + TOD_MAGE_HEAL_HP_PER_LV * ( TOD_MAGE_HEAL_MAX - 1 ) + TOD_MAGE_HEAL_DARK_HP;
	return TOD_MAGE_HEAL_HP_PER_SEC + TOD_MAGE_HEAL_HP_PER_LV * ( lv - 1 );
}

function heal_damage_taken( lv )
{
	if ( lv < 1 ) lv = 1;
	if ( lv > TOD_MAGE_HEAL_DARK_LV ) lv = TOD_MAGE_HEAL_DARK_LV;
	if ( lv > TOD_MAGE_HEAL_MAX )
		return TOD_MAGE_AURA_DR - TOD_MAGE_AURA_DR_PER_LV * ( TOD_MAGE_HEAL_MAX - 1 ) - TOD_MAGE_HEAL_DARK_DR;
	return TOD_MAGE_AURA_DR - TOD_MAGE_AURA_DR_PER_LV * ( lv - 1 );
}

// Health is integer-valued. Alternate 5/6 HP at 11 HP/s instead of rounding
// every half-second pulse up to 6; a full five-second aura must heal exactly 55.
function heal_tick_amount( lv, tick )
{
	rate = heal_hp_per_second( lv ) * TOD_MAGE_HEAL_TICK_SECS;
	return int( rate * ( tick + 1 ) ) - int( rate * tick );
}

// One expiry per card level: the strongest recent aura wins for resistance.
// A weaker caster cannot overwrite it or keep its higher strength alive after
// it leaves. This is server-only state; no extra network fields are needed.
function aura_touch( lv )   // self = recipient
{
	if ( lv < 1 ) lv = 1;
	if ( lv > TOD_MAGE_HEAL_DARK_LV ) lv = TOD_MAGE_HEAL_DARK_LV;
	if ( !isdefined( self.tod_mage_aura_levels ) )
		self.tod_mage_aura_levels = [];
	self.tod_mage_aura_ms = GetTime();
	self.tod_mage_aura_levels[ lv ] = self.tod_mage_aura_ms;
}

function aura_level( player )
{
	if ( !isdefined( player ) || !isplayer( player )
	  || !isdefined( player.tod_mage_aura_levels ) )
		return 0;
	for ( lv = TOD_MAGE_HEAL_DARK_LV; lv >= 1; lv-- )
	{
		stamp = player.tod_mage_aura_levels[ lv ];
		if ( isdefined( stamp ) && GetTime() - stamp <= TOD_MAGE_AURA_GRACE_MS )
			return lv;
	}
	return 0;
}

function aura_dr( player )
{
	lv = aura_level( player );
	if ( lv < 1 )
		return 1.0;
	return heal_damage_taken( lv );
}

// THE GREEN HEALTH BAR (user: "any player in radius will have their health bar
// turn green ... dark ish green, not complete dark green").
//
// NO NEW ART. The bar is i_tod_hud_health_fill, a neutral strip that is TINTED
// at runtime -- the shield bar next to it is the same image at 0.4/0.7/1.0
// blue. So this is a colour, pushed on the map's proven int-only notify lane
// (LuiNotifyEvent -> AetheriumPlayerInfo's scriptNotify subscription, the twin
// of "tod_maxhp" already living there).
//
// EDGE-TRIGGERED: one notify when you enter the aura and one when you leave,
// never one per tick -- the notify lane is shared with the score feed and the
// upgrade sync, and a 2 Hz per-player spam would be rude to all of it.
function aura_bar( on )   // self = player
{
	want = 0;
	if ( on )
		want = 1;
	if ( isdefined( self.tod_mage_aura_bar ) && self.tod_mage_aura_bar == want )
		return;
	self.tod_mage_aura_bar = want;
	// THE GREEN HEALTH BAR (v18.39). Two notifies, IN THIS ORDER:
	//   1. the aura flag, received by tod_upgrade.lua's chain -> CoD.TodMageAura
	//   2. tod_maxhp, which makes AetheriumPlayerInfo repaint the health plate
	//      through CoD.TodAuraTint -- the ONE line that widget could spare.
	// The second is what makes the first visible: nothing else repaints that
	// plate when only a colour has changed. Sending the player's REAL max health
	// keeps it a no-op for the value it already carries.
	self LuiNotifyEvent( &"tod_mage_aura", 1, want );
	mh = 150;
	if ( isdefined( self.maxhealth ) && self.maxhealth > 0 )
		mh = int( self.maxhealth );
	self LuiNotifyEvent( &"tod_maxhp", 1, mh );
	if ( want == 1 )
		self thread aura_bar_clear();
}

// Nothing tells a player they have LEFT the radius, so the clear is a watcher:
// once the stamp goes stale, put the bar back.
function aura_bar_clear()   // self = player
{
	self endon( "disconnect" );
	self notify( "tod_mage_aura_bar_clear" );
	self endon( "tod_mage_aura_bar_clear" );

	for ( ;; )
	{
		wait 0.25;
		if ( !isdefined( self.tod_mage_aura_ms ) || GetTime() - self.tod_mage_aura_ms > TOD_MAGE_AURA_GRACE_MS )
		{
			self aura_bar( false );
			return;
		}
	}
}

// ---- BLINK ----------------------------------------------------------------

function blink_level()   // self = player
{
	lv = tod_upgrades::get_level( self, "mage_blink" );
	if ( lv < 0 )
		lv = 0;
	return lv;
}

function blink_capacity()   // self = player
{
	lv = self blink_level();
	if ( lv < 1 )
		return 0;
	if ( lv >= 3 )
		return 2 + ( tod_upgrades::has_dark( self, "mage_blink" ) ? 1 : 0 );   // dark BLINK (2026-09-09): a third stored charge
	return 1;
}

function blink_recharge_ms()   // self = player
{
	lv = self blink_level();
	secs = TOD_MAGE_BLINK_CD - TOD_MAGE_BLINK_CD_LV * lv;
	if ( secs < 1 )
		secs = 1;
	return int( secs * TOD_MAGE_BLINK_RECHARGE_SCALE * 1000 * self cooldown_scale() );
}

// Shared by casting and HUD. One running recharge; using a stored second
// charge never restarts it. (The elite-kill refund that used to edit this timer was removed 2026-09-09.)
function blink_charges_now()   // self = player
{
	cap = self blink_capacity();
	if ( !isdefined( self.tod_mage_cd ) )
		self.tod_mage_cd = [];
	if ( !isdefined( self.tod_mage_blink_charges ) )
	{
		self.tod_mage_blink_charges = cap;
		self.tod_mage_blink_cap = cap;
		self.tod_mage_cd[ "mage_blink" ] = 0;
	}
	// Unlock grants the first charge; reaching Lv3 grants the new second slot.
	if ( cap > self.tod_mage_blink_cap )
		self.tod_mage_blink_charges += cap - self.tod_mage_blink_cap;
	self.tod_mage_blink_cap = cap;
	if ( self.tod_mage_blink_charges > cap )
		self.tod_mage_blink_charges = cap;
	if ( self.tod_mage_blink_charges >= cap )
	{
		self.tod_mage_cd[ "mage_blink" ] = 0;
		return self.tod_mage_blink_charges;
	}

	now = GetTime();
	interval = self blink_recharge_ms();
	while ( self.tod_mage_blink_charges < cap && now >= self.tod_mage_cd[ "mage_blink" ] )
	{
		self.tod_mage_blink_charges++;
		self.tod_mage_cd[ "mage_blink" ] += interval;
	}
	if ( self.tod_mage_blink_charges >= cap )
		self.tod_mage_cd[ "mage_blink" ] = 0;
	return self.tod_mage_blink_charges;
}

function blink_spend()   // self = player; only after a valid landing
{
	charges = self blink_charges_now();
	if ( charges < 1 )
		return;
	cap = self blink_capacity();
	interval = self blink_recharge_ms();
	if ( charges == cap )
		self.tod_mage_cd[ "mage_blink" ] = GetTime() + interval;
	self.tod_mage_blink_charges--;
	self abil_send( self charges_now(), self.tod_mage_blink_charges );
}

function cast_blink()   // self = player
{
	if ( !self ready( "mage_blink" ) )
		return;
	if ( self laststand::player_is_in_laststand() )
		return;

	lv   = self blink_level();
	dist = TOD_MAGE_BLINK_DIST + TOD_MAGE_BLINK_DIST_LV * lv;

	// FLATTENED HEADING, deliberately. Blinking along the view PITCH would fire
	// you into a ceiling looking up and into the floor looking down; on a tower
	// of open stairs that is a death sentence either way. The move goes where
	// you are FACING; the floor samples below supply the changing stair height.
	fwd = AnglesToForward( self GetPlayerAngles() );
	fwd = ( fwd[ 0 ], fwd[ 1 ], 0 );
	if ( LengthSquared( fwd ) < 0.01 )
		return;
	fwd = VectorNormalize( fwd );

	land = self blink_landing( fwd, dist );
	// No text: a short amber icon pulse acknowledges a blocked landing.
	// Nothing is spent until a valid landing exists.
	if ( !isdefined( land ) )
	{
		self LuiNotifyEvent( &"tod_mage_blink_blocked", 1, 1 );
		return;
	}

	self blink_spend();
	self tut_count( "blink" );   // v19.11: a blocked landing above spends nothing and counts nothing
	blink_fx( self.origin, "zmb_bgb_abh_teleport_out" );
	self SetOrigin( land );
	blink_fx( land, "" );
	// Both ABH aliases live in stock zm_common.ff (verified in its inflated
	// asset strings). The departure stays in the world; arrival follows you.
	self PlayLocalSound( "zmb_bgb_abh_teleport_in" );
}

// v18.43: the old fixed-height ray hit the ascending stairs after ~100u.
// Follow their floor in short segments, computing the entire route BEFORE
// SetOrigin. Tower treads are 12 high / 32 deep; the road permits 18u steps.
// All rays ignore characters so the horde still cannot block the teleport.
function blink_landing( fwd, dist )   // self = player
{
	land = self.origin;
	moved = 0;
	while ( moved < dist )
	{
		step = TOD_MAGE_BLINK_STEP;
		if ( moved + step > dist )
			step = dist - moved;
		probe = land + VectorScale( fwd, step );
		top = probe + ( 0, 0, TOD_MAGE_BLINK_STEP_UP + 1 );
		down = BulletTrace( top, probe - ( 0, 0, TOD_MAGE_BLINK_DROP ), false, self );
		// Missing floor cancels the cast, including its cooldown. Never accept
		// the trace endpoint over the void as if it were a surface.
		if ( !isdefined( down[ "position" ] ) || down[ "fraction" ] >= 1 )
			return undefined;
		if ( down[ "fraction" ] <= 0 )
			break;
		next = down[ "position" ];
		if ( next[ 2 ] - land[ 2 ] > TOD_MAGE_BLINK_STEP_UP )
			break;

		// Check each segment at the current floor height, with the original
		// wall clearance ahead. Re-basing every 16u lets stairs pass without
		// raising a single long ray over closed doors or parapets.
		start = land + ( 0, 0, TOD_MAGE_BLINK_RISE );
		end = next + ( 0, 0, TOD_MAGE_BLINK_RISE );
		end += VectorScale( fwd, TOD_MAGE_BLINK_BACKOFF );
		tr = BulletTrace( start, end, false, self );
		if ( tr[ "fraction" ] < 1 )
			break;
		// A floor sample alone does not prove there is room to stand on it.
		head = BulletTrace( next + ( 0, 0, 1 ), next + ( 0, 0, 72 ), false, self );
		if ( head[ "fraction" ] < 1 )
			break;
		land = next;
		moved += step;
	}
	// A blocked cast must not spend the cooldown to teleport on the spot.
	if ( moved < TOD_MAGE_BLINK_STEP )
		return undefined;
	return land;
}

// Anywhere But Here at both ends, independent of CHAIN LIGHTNING's hit FX.
// The source effect has smoke particles lasting up to 4s, so do not use the
// shared 1.5s combat-hit cleanup. Keep the host through their full lifetime.
function blink_fx( org, sound_alias )
{
	host = Spawn( "script_model", org + ( 0, 0, 32 ) );
	if ( !isdefined( host ) )
		return;
	host SetModel( "tag_origin" );
	if ( sound_alias != "" )
		host PlaySound( sound_alias );
	host thread blink_fx_run();
}

function blink_fx_run()   // self = temporary FX host, never the player
{
	// The breather teleporter's snapshot fix: give the new host and the
	// player's new position two server frames before emitting the one-shot.
	// No player endon: disconnecting must not strand either temporary host.
	WAIT_SERVER_FRAME;
	WAIT_SERVER_FRAME;
	if ( !isdefined( self ) )
		return;
	PlayFxOnTag( level._effect[ "tod_mage_blink" ], self, "tag_origin" );
	wait 4.5;
	if ( isdefined( self ) )
		self Delete();
}

// ---- MANA, AND DEMIGOD ----------------------------------------------------

function mana_now()   // self = player
{
	if ( self arch_level() < 1 || !isdefined( self.tod_mage_mana ) )
		self.tod_mage_mana = 0;
	return self.tod_mage_mana;
}

function mana_add( n )   // self = player
{
	if ( self arch_level() < 1 )
	{
		self.tod_mage_mana = 0;
		return;
	}
	if ( !isdefined( self.tod_mage_mana ) )
		self.tod_mage_mana = 0;
	// Mana does not build while DEMIGOD is running -- the bar is the cost, so
	// letting it refill mid-transformation would let one bar buy two.
	if ( IS_TRUE( self.tod_mage_demigod ) )
		return;
	self.tod_mage_mana += n;
	if ( self.tod_mage_mana > TOD_MAGE_MANA_MAX )
		self.tod_mage_mana = TOD_MAGE_MANA_MAX;
}

// Keep shooting free, but leave one round of space for an optional native
// reload. Real reserve ammo and a nonzero reloadAmmoAdd are required for the
// engine to complete the reload and apply Speed Cola's animation multiplier.
// Never touch the clip while reloading; that could finish/cancel it early.
function staff_ammo_watch()
{
	self endon( "disconnect" );
	self endon( "death" );
	self notify( "tod_mage_ammo_watch" );
	self endon( "tod_mage_ammo_watch" );
	self endon( "tod_mage_disarm" );
	for ( ;; )
	{
		weapon = self GetCurrentWeapon();
		if ( isdefined( staff_element( weapon ) ) && !self IsReloading()
		  && !self IsSwitchingWeapons() && !self laststand::player_is_in_laststand() )
		{
			if ( self GetWeaponAmmoStock( weapon ) < weapon.clipSize )
				self SetWeaponAmmoStock( weapon, weapon.clipSize );
			target = self staff_clip_target( weapon );   // v18.77: 0 while a lightning reload is owed
			if ( self GetWeaponAmmoClip( weapon ) != target )
				self SetWeaponAmmoClip( weapon, target );
		}
		wait 0.25;
	}
}

// v18.99 — INFINITE AMMO SUSPENDS THE LIGHTNING STAFF'S FORCED RELOAD (user:
// "on infinite ammo, it should be able to shoot without needing to reload").
// The drop's whole promise is that nothing interrupts your shooting, and
// stock's powerup could not honour it here: every other gun in the map is
// covered because stock stops DEDUCTING ammo, while this staff's reload is
// not an ammo state at all — it is a counter this module keeps and a clip it
// pins to 0. So the map's own invention was the one thing Infinite Ammo did
// not cover. Read the same level var the slasher's THOR cooldown reads
// (_tod_upgrades), guarded the same way: no #using, no new state to keep in
// step with the powerup's own lifetime.
function bolt_reload_suspended()
{
	return ( isdefined( level.zombie_vars ) && IS_TRUE( level.zombie_vars[ "zombie_powerup_infiniteammo_on" ] ) );
}

// v18.77 — where the clip is pinned: one short for an optional reload, ZERO
// for the lightning staff once TOD_MAGE_BOLT_SHOTS_PER_RELOAD shots are owed.
// v18.99: never zero while Infinite Ammo holds — a reload owed when the drop
// lands is lifted within the watcher's 0.25 s, mid-debt, without a reload.
function staff_clip_target( weapon )   // self = player
{
	element = staff_element( weapon );
	if ( IS_TRUE( self.tod_mage_bolt_reload_due ) && isdefined( element ) && element == "lightning"
	  && !bolt_reload_suspended() )
		return 0;
	return weapon.clipSize - 1;
}

// v18.77 — one lightning shot on the invisible counter (weapon_fired, any
// lightning variant). At the limit the clip is emptied on the spot so the
// very next trigger pull is the engine's own reload.
function bolt_count_shot( weapon )   // self = player
{
	// weapon_fired also carries non-staff weapons. GSC throws when undefined
	// is compared to a string, ending shot_id_watch (native log, 2026-09-10).
	element = staff_element( weapon );
	if ( !isdefined( element ) || element != "lightning" )
		return;
	// v18.99 — Infinite Ammo: the shot does not count AND any standing debt is
	// wiped, so the drop ending does not hand back a reload the player had
	// stopped owing. The counter restarts from zero on the first shot after it.
	if ( bolt_reload_suspended() )
	{
		self bolt_reload_reset();
		return;
	}
	if ( !isdefined( self.tod_mage_bolt_shots ) )
		self.tod_mage_bolt_shots = 0;
	self.tod_mage_bolt_shots++;
	if ( self.tod_mage_bolt_shots < TOD_MAGE_BOLT_SHOTS_PER_RELOAD )
		return;
	self.tod_mage_bolt_reload_due = true;
	self SetWeaponAmmoClip( weapon, 0 );
}

// v18.77 — any reload start resets the counter (the user's rule), whatever
// staff is held and whether or not the reload completes.
function bolt_reload_reset()   // self = player
{
	self.tod_mage_bolt_shots = 0;
	self.tod_mage_bolt_reload_due = undefined;
}

// A reload is a small mana ritual. Stock Electric Cherry uses "reload_start"
// and "reload" to distinguish a started reload from one that loaded. Wait for
// IsReloading to clear too: the ammo notification can precede the animation's
// tail. Starting another reload replaces the attempt; interruption never pays.
function reload_mana_watch()
{
	self endon( "disconnect" );
	self endon( "death" );
	self notify( "tod_mage_reload_watch" );
	self endon( "tod_mage_reload_watch" );
	self endon( "tod_mage_disarm" );
	for ( ;; )
	{
		self waittill( "reload_start" );
		self notify( "tod_mage_reload_attempt" );
		self bolt_reload_reset();   // v18.77: any reload resets the lightning counter
		weapon = self GetCurrentWeapon();
		if ( isdefined( staff_element( weapon ) ) )
			self thread reload_mana_complete( weapon );
	}
}

function reload_mana_complete( weapon )
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "tod_mage_reload_watch" );
	self endon( "tod_mage_reload_attempt" );
	self endon( "tod_mage_disarm" );
	self endon( "weapon_change" );
	self endon( "weapon_fired" );
	self endon( "sprint_begin" );
	self endon( "melee_swipe" );

	self waittill( "reload" );
	while ( self IsReloading() )
	{
		if ( self IsSprinting() || self IsMeleeing() || self laststand::player_is_in_laststand() )
			return;
		wait 0.05;
	}
	if ( self GetCurrentWeapon() != weapon || !IS_TRUE( self.tod_mage_armed ) )
		return;
	if ( self IsSprinting() || self IsMeleeing() || self laststand::player_is_in_laststand() )
		return;
	if ( IS_TRUE( level.tod_upgrade_pause ) || IS_TRUE( self.tod_menu_frozen ) )
		return;
	if ( isdefined( self.tod_mage_reload_paid_ms ) && GetTime() < self.tod_mage_reload_paid_ms + TOD_MAGE_RELOAD_MANA_WINDOW_MS )
		return;   // v18.76: paid within the window -- the reload still plays, the mana does not
	self.tod_mage_reload_paid_ms = GetTime();
	self mana_add( TOD_MAGE_RELOAD_MANA );
	self mana_push( int( self mana_now() ) );
}

// ONE POINT PER SECOND. Real seconds, not a frame count, so a hitch cannot
// cheat the bar in either direction.
function mana_watch()   // self = player
{
	self endon( "disconnect" );
	self notify( "tod_mage_mana_watch" );
	self endon( "tod_mage_mana_watch" );
	self endon( "tod_mage_disarm" );

	for ( ;; )
	{
		wait 1;
		if ( IS_TRUE( level.tod_upgrade_pause ) )
			continue;   // the world is frozen; so is the bar
		// AND NOT WHILE DOWNED (v18.49 audit). This tick is the only PASSIVE
		// income in the class -- it needs no input at all -- so without this a
		// crawler charges ARCHMAGE while contributing nothing, and can be
		// revived straight into it. Kills are self-limiting (a crawler gets
		// none); a per-second trickle is not. The other two timers are left
		// running on purpose: charge_regen is a cooldown the player already
		// paid for, and a demigod form is a spent resource whose clock should
		// not be extended by going down.
		if ( self laststand::player_is_in_laststand() )
			continue;
		// NOR WHILE SPECTATING (2026-09-22, F11): a bled-out mage kept filling the
		// bar until the round respawn.
		if ( !IsAlive( self ) || ( isdefined( self.sessionstate ) && self.sessionstate != "playing" ) )
			continue;
		// ARCHMAGE shortens the wait for the next transformation as well as making
		// it bigger: +0.25 mana/s per level, so a maxed mage fills in 40 s of
		// standing still instead of 100 (kills still add on top). Mana is carried
		// as a FLOAT for this and only rounded where it is drawn.
		self mana_add( TOD_MAGE_MANA_PER_SEC + TOD_MAGE_ARCH_MANA_LV * self arch_level() );
	}
}

// PUBLIC -- called from _tod_upgrades::on_class_gun_kill through the guarded
// level pointer (that module imports this one, so no #using in this direction).
function on_kill( attacker )
{
	if ( !isdefined( attacker ) || !IsPlayer( attacker ) )
		return;
	if ( !IS_TRUE( attacker.tod_mage_armed ) )
		return;
	attacker mana_add( attacker mana_per_kill() );
}

// What ONE kill is worth to this player's bar right now. See the budget define.
// level.tod_round_zombie_total is published by _tod_luck's per-round loop; the 24
// fallback is that loop's own, so a missing value degrades identically here.
function mana_per_kill()   // self = player
{
	total = level.tod_round_zombie_total;
	if ( !isdefined( total ) || total < 1 )
		total = 24;
	p = GetPlayers().size;
	if ( p < 1 )
		p = 1;
	base = TOD_MAGE_MANA_KILL_BUDGET * p / total;
	return base * ( 1.0 + TOD_MAGE_ARCH_MANA_KILL_LV * self arch_level() );
}

// PUBLIC -- the damage arm reads this. x2 while DEMIGOD is running.
function arch_level()   // self = player
{
	lv = tod_upgrades::get_level( self, "mage_arch" );
	if ( lv < 0 )
		lv = 0;
	return lv;
}

// TOTAL damage multiplier at ARCHMAGE level lv. Cumulative sums of the
// 30/25/20/15/15/15 increments -- written out rather than computed so the
// number a card promises can be read straight off the line.
function arch_damage_mult( lv )
{
	if ( !isdefined( lv ) || lv < 0 )
		lv = 0;
	if ( lv > TOD_MAGE_ARCH_MAX )
		lv = TOD_MAGE_ARCH_MAX;
	// 2026-09-09 ceiling pass: 1.30..2.20 -> 1.25..1.85 (Lv6 -16%). ARCHMAGE is
	// the only damage multiplier in the map no gun class has, so it is the one
	// that decides how far past the roster a maxed mage lands. Lockstep: the M
	// table in tod_upgrade.lua row 55 and the armory ladder.
	tot = array( TOD_MAGE_DEMIGOD_MULT, 1.25, 1.40, 1.55, 1.65, 1.75, 1.85 );
	return tot[ lv ];
}

// TOTAL seconds of form at ARCHMAGE level lv.
function arch_duration( lv )
{
	if ( !isdefined( lv ) || lv < 0 )
		lv = 0;
	if ( lv > TOD_MAGE_ARCH_MAX )
		lv = TOD_MAGE_ARCH_MAX;
	tot = array( TOD_MAGE_DEMIGOD_SECS, 8, 11, 13, 14, 15, 16 );
	return tot[ lv ];
}

// TOTAL move-speed bonus at ARCHMAGE level lv, in SCALE POINTS (apply_move_speed
// adds these, so +0.30 is thirty points for every class alike -- not 30% of the
// mage's own 1.00 base, though for the mage those happen to coincide).
function arch_speed_scale( lv )
{
	if ( !isdefined( lv ) || lv < 0 )
		lv = 0;
	if ( lv > TOD_MAGE_ARCH_MAX )
		lv = TOD_MAGE_ARCH_MAX;
	tot = array( 0.10, 0.15, 0.19, 0.23, 0.26, 0.28, 0.30 );
	return tot[ lv ];
}

function demigod_mult()   // self = player
{
	if ( !IS_TRUE( self.tod_mage_demigod ) )
		return 1.0;
	// The multiplier is LATCHED at transformation time (demigod_run), so a card
	// taken mid-form cannot change a fight already in progress -- and neither
	// can a tier reset. Falls back to the base if the latch is somehow missing.
	if ( isdefined( self.tod_mage_demigod_mult ) )
		return self.tod_mage_demigod_mult;
	// Recompute rather than return the lv0 floor: a missing latch should still
	// pay what the player's cards are worth. (This returned a hardcoded x2.0
	// until 2026-09-08 -- the OLD base, and now simply wrong.)
	return arch_damage_mult( self arch_level() );
}

function demigod_try()   // self = player
{
	if ( !self ready( "mage_arch" ) )
		return;   // the first ARCHMAGE card unlocks activation
	if ( IS_TRUE( self.tod_mage_demigod ) )
		return;
	if ( self mana_now() < TOD_MAGE_MANA_MAX )
	{
		// [tod 2026-09-09] SILENT (user: "remove the arch mage text on sreen when
		// it activates and the text that shows how to use it"). The bar in the
		// ammo bay already IS this number, and it now flashes PRESS AIM BUTTON
		// of its own accord the moment it is full -- so a refusal print was
		// telling the player what they were already looking at.
		return;
	}
	self.tod_mage_mana = 0;
	self tut_count( "arch" );   // v19.11
	self ability_first_raise();
	self thread demigod_run();
}

function demigod_run()   // self = player
{
	self endon( "disconnect" );
	self notify( "tod_mage_demigod_run" );
	self endon( "tod_mage_demigod_run" );
	// v18.76 — THE FORM DIES WITH THE BODY AND LEAVES WITH THE CLASS. This
	// thread used to end only on disconnect, so dying or re-drafting at the base
	// station mid-form left tod_mage_demigod_speed and the sprint-fire grant
	// latched on the next body / the new class until the timer ran out. An
	// endon here would be no better (endon is not cleanup -- the fields would
	// stay set), so a guard thread waits for either event and runs the same
	// teardown the timer runs.
	self thread demigod_guard();

	lv = self arch_level();
	self.tod_mage_demigod = true;
	self tod_upgrades::apply_sprint_fire();
	self.tod_mage_demigod_mult = arch_damage_mult( lv );
	// LATCHED like the multiplier above, and for the same reason: a card taken
	// mid-form must not change a fight already running. apply_move_speed only
	// reads this field, so _tod_upgrades needs no knowledge of the mage at all.
	self.tod_mage_demigod_speed = arch_speed_scale( lv );
	// THE DARK RUNG IS DEALT SINCE 2026-09-09 (set_no_dark("mage_arch") removed;
	// the card wears the ULTIMATE-frame DARK text until its art lands). Before: set_no_dark("mage_arch")
	// still stands in _tod_upgrades, because a dark card needs
	// i_tod_card_mage_arch_dark + i_tod_pause_r54_dark and NEITHER EXISTS -- the
	// asset lint's GATE A would fail the build, and shipping past it draws a
	// white square. Reading has_dark here is the half that is safe to land now:
	// when the art arrives, deleting that one set_no_dark line is the whole
	// change. UNEXERCISED until then, by construction.
	if ( tod_upgrades::has_dark( self, "mage_arch" ) )
	{
		self.tod_mage_demigod_mult  += TOD_MAGE_ARCH_DARK_MULT;
		self.tod_mage_demigod_speed += TOD_MAGE_ARCH_DARK_SPEED;
	}
	self tod_upgrades::apply_move_speed();   // instant onset (the ADRENALINE pattern)
	// The "ARCHMAGE" banner is GONE (same user note). The bar turning gold and
	// draining is the activation tell, and the sound below is the punctuation.
	self PlayLocalSound( "tod_mage_stance_on" );   // donor cue (sword_raise); docs/118 owes a bespoke one

	// Real seconds, and the world pause does not tick them away.
	total = arch_duration( lv );
	if ( tod_upgrades::has_dark( self, "mage_arch" ) )
		total += TOD_MAGE_ARCH_DARK_SECS;
	left  = total;
	// 2026-10-01: the form on the world - circle, runes, rainbow column and light
	// for everyone, a quieter version in the Mage's own view (the .csc).
	self arch_fx_set( TOD_ARCH_FX_ON, "start lv=" + lv + " secs=" + total );
	// THE BAR IS THE TIMER (v18.42). While the form runs, the mana bar turns
	// gold and drains — the mana was spent, so the trough is free to carry the
	// one number that now matters. mana_push reads this.
	self.tod_mage_demigod_pct = 100;
	while ( left > 0 )
	{
		wait 0.25;
		self tod_upgrades::apply_sprint_fire();
		if ( IS_TRUE( level.tod_upgrade_pause ) )
			continue;
		left -= 0.25;
		self.tod_mage_demigod_pct = int( left * 100 / total );
	}

	self notify( "tod_mage_demigod_end" );   // v18.76: stand the guard down first
	self demigod_end( true );
}

// v18.76 — the ONE teardown, shared by the timer and the guard. `sound` is
// false on death / class change: the body is gone or the class is, and a
// stance cue on a corpse or on a fresh Heavy reads as a bug.
function demigod_end( sound )   // self = player
{
	self.tod_mage_demigod = undefined;
	self tod_upgrades::apply_sprint_fire();
	self.tod_mage_demigod_mult = undefined;
	self.tod_mage_demigod_speed = undefined;
	self.tod_mage_demigod_pct = undefined;
	self tod_upgrades::apply_move_speed();   // and back down when the form ends
	if ( sound )
		self PlayLocalSound( "tod_mage_stance_off" );
	// The timer's end collapses the rings; a death or a class change just cuts them.
	if ( sound )
		self arch_fx_set( TOD_ARCH_FX_FADE, "timer" );
	else
		self arch_fx_set( TOD_ARCH_FX_OFF, "cut" );
	if ( IS_TRUE( level.tod_dev ) && IS_TRUE( level.tod_dev_arch_test ) && sound )
		self thread dev_arch_refill();
}

// ---- ARCHMAGE ON THE WORLD: the server's half (2026-10-01) ----------------------
// The server only flips the player's tod_arch_form field; the .csc draws the
// form from it, per viewer. [TOD_ARCH_FX] logs every flip here and
// [TOD_ARCH_FX_C] logs what each client actually started / stopped - a server
// line alone proves only that the server asked (memory flat-ground-fx-rules).
function arch_fx_set( state, why )   // self = player
{
	if ( !isdefined( self ) )
		return;
	self clientfield::set( TOD_ARCH_FX_FIELD, state );
	arch_fx_log( "SET state=" + state + " player=" + self GetEntityNumber() + " bot=" + self IsTestClient() + " " + why );
}

function arch_fx_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	line = "[TOD_ARCH_FX] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}

// TEST SETUP ONLY (level.tod_dev_arch_test): a full mana bar a few seconds after
// each form, so the look can be judged form after form. Never armed in a publish
// (build_map.ps1 -Publish refuses every tod_dev* flag).
function dev_arch_refill()   // self = player
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "tod_mage_disarm" );
	wait TOD_ARCH_DEV_REFILL_MS / 1000.0;
	if ( IS_TRUE( self.tod_mage_demigod ) || self arch_level() < 1 )
		return;
	self.tod_mage_mana = TOD_MAGE_MANA_MAX;
	arch_fx_log( "DEV_REFILL player=" + self GetEntityNumber() + " mana=" + self.tod_mage_mana );
}

// TEST SETUP ONLY: the first form needs no grinding either - a full bar once the
// first ARCHMAGE card is owned (the dev class max deals it).
function dev_arch_first_fill()   // self = player
{
	if ( !IS_TRUE( level.tod_dev ) || !IS_TRUE( level.tod_dev_arch_test ) )
		return;
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "tod_mage_disarm" );
	self notify( "tod_dev_arch_first_fill" );
	self endon( "tod_dev_arch_first_fill" );
	if ( self IsTestClient() )
		return;
	while ( self arch_level() < 1 )
		wait 0.5;
	wait 1;
	if ( IS_TRUE( self.tod_mage_demigod ) || self mana_now() >= TOD_MAGE_MANA_MAX )
		return;
	self.tod_mage_mana = TOD_MAGE_MANA_MAX;
	arch_fx_log( "DEV_REFILL first player=" + self GetEntityNumber() + " arch_lv=" + self arch_level() );
}

// TEST SETUP ONLY: the form's look on the dev Mage dummy, so it can be seen from
// outside (the Mage only ever sees their own feet). Visual only - the dummy gets
// no form, no damage, no speed. Called by _tod_dev_mage.
function dev_arch_preview( bot )
{
	if ( !isdefined( bot ) )
		return;
	bot endon( "disconnect" );
	arch_fx_log( "PREVIEW bot=" + bot GetEntityNumber() + " secs=" + TOD_ARCH_DEV_PREVIEW_SECS );
	bot arch_fx_set( TOD_ARCH_FX_ON, "dev_preview" );
	wait TOD_ARCH_DEV_PREVIEW_SECS;
	bot arch_fx_set( TOD_ARCH_FX_FADE, "dev_preview_end" );
}

// v18.76 — ends the form on death or on leaving the class (tod_mage_disarm is
// class_arm_watch's notify when the player stops being a mage). Ends itself
// when the timer finishes first (tod_mage_demigod_end) or a new form starts.
function demigod_guard()   // self = player
{
	self endon( "disconnect" );
	self endon( "tod_mage_demigod_run" );
	self endon( "tod_mage_demigod_end" );

	// "bled_out" too (2026-09-22, F11): stock's bleed-out path never sends
	// "death" for a player, so a form outlived the body into the spectator.
	self util::waittill_any( "death", "bled_out", "tod_mage_disarm" );
	// Teardown FIRST, notify SECOND: this thread endons the same event it is
	// about to raise, so anything after the notify may never run.
	self demigod_end( false );
	self notify( "tod_mage_demigod_run" );   // kills the timer loop (its own restart notify)
}

// ---- THE MANA BAR'S DATA CHANNEL ------------------------------------------
//
// The bar lives in the AMMO BAY (AetheriumLoadout.lua) because that is where
// the user put it — "a mana bar that is used in place of the ammo section" —
// so the value has to reach LUI.
//
// IT RIDES LuiNotifyEvent, NOT A CLIENTFIELD. The clientuimodel pool is at its
// PROVEN 61-bit ceiling with one bit spare and is APPEND ONLY; a 0..100 value
// needs seven. Overflowing that pool is not a degraded readout, it is
// Com_ERROR "clientuimodel is out of space" and a load that aborts to the
// lobby. So this uses the int-only notify lane the green health bar, the tower
// gauge and the owned-upgrade sync already share.
//
// TWO INTS — the value 0..100 and a STATE the widget switches on:
//   0  FILLING    mint bar, value = mana
//   1  ARCHMAGE   gold bar, value = the share of the form's duration left
//   2  NOT A MAGE put the clip/reserve readout back
//   3  LOCKED     mage with an empty bar until the first Archmage card
//   4  DOWNED     a mage in last stand: the clip/reserve readout comes back for
//                 the down pistol (a real gun with real ammo), while the two
//                 ability tiles stay the mage's. Revive -> the next push is 0/1/3.
//                 (2026-09-24, lead tester: a downed mage saw no ammo count —
//                 the bar owned those cells for ANY weapon held, pistol included.)
function mana_push( value )   // self = player
{
	state = 0;
	if ( self laststand::player_is_in_laststand() )
	{
		state = 4;
		value = 0;
	}
	else if ( self arch_level() < 1 )
	{
		state = 3;   // mage, but Archmage locked: empty bar, no ready cue
		value = 0;
	}
	else if ( IS_TRUE( self.tod_mage_demigod ) )
	{
		state = 1;
		value = 100;
		if ( isdefined( self.tod_mage_demigod_pct ) )
			value = self.tod_mage_demigod_pct;
	}
	self mana_send( value, state );
}

// THE ONE WRITER, and it is CHANGE-GATED: mana climbs about once a second, so
// calling this at 4 Hz from the HUD watcher costs a couple of notifies a second
// at worst on a lane shared with the score feed. Everything that moves the bar
// goes through here so the gate cannot be bypassed.
function mana_send( value, state )   // self = player
{
	if ( value < 0 )
		value = 0;
	if ( value > 100 )
		value = 100;
	if ( isdefined( self.tod_mage_bar_v ) && self.tod_mage_bar_v == value
	  && isdefined( self.tod_mage_bar_s ) && self.tod_mage_bar_s == state )
		return;
	self.tod_mage_bar_v = value;
	self.tod_mage_bar_s = state;
	self LuiNotifyEvent( &"tod_mage_mana", 2, value, state );
}

// THE TWO ABILITY TILES (v18.43). The mage carries no grenades, so the lethal
// and tactical slots in the HUD's corner would sit empty for the one class with
// the most to put in them. They now draw HEALING AURA and BLINK — which is
// exactly what those two buttons do for a mage.
//
// TWO INTS: zero means the tile draws DIM -- locked (no card yet) or cooling
// down; a positive count draws it lit. -1 (hidden) is no longer sent for a
// mage since v18.76 (user 2026-09-10, on "a fresh Mage is told nothing": the
// tiles were HIDDEN until the first card, so lethal and tactical looked like
// they did not exist). A dim tile from the first spawn says "there is
// something here"; the first-arm hint below says what unlocks it.
function abil_send( charges, blink_charges )   // self = player
{
	if ( self charges_max() < 1 || charges < 0 )
		charges = 0;
	if ( self blink_capacity() < 1 || blink_charges < 0 )
		blink_charges = 0;
	// v18.76 (item 6): the aura's own 5 s lock (arm_cooldown in cast_heal)
	// refused a second cast while the tile still showed 2-3 charges. The tile
	// now dims for the lock; heal_lock_tell re-sends when it lifts.
	if ( charges > 0 && !self ready( "mage_heal" ) )
		charges = 0;
	if ( isdefined( self.tod_mage_ab_c ) && self.tod_mage_ab_c == charges
	  && isdefined( self.tod_mage_ab_b ) && self.tod_mage_ab_b == blink_charges )
		return;
	self.tod_mage_ab_c = charges;
	self.tod_mage_ab_b = blink_charges;
	self LuiNotifyEvent( &"tod_mage_abil", 2, charges, blink_charges );
	// v19.19 - LOG WHAT THE HUD WAS ACTUALLY TOLD. The ability key badge has been
	// reported missing three builds running and every diagnosis so far has been a
	// reading of the Lua, which is a statement about what SHOULD arrive. This is
	// the value that DOES arrive, on the PrintLn lane a dev run already captures.
	// Both numbers are post-clamp, so what is printed here is exactly what the
	// two tiles and their badges are drawn from.
	self tut_dev_log( "abil heal=" + charges + " blink=" + blink_charges
		+ " heal_cap=" + self charges_max() + " blink_cap=" + self blink_capacity() );
}

// Drop the change-gate's memory, so the next push is sent whatever it says.
// Needed wherever the WIDGET may have reset underneath us — the ammo bay's
// whole lifecycle re-runs on a death, which puts the bar back to hidden while
// this side still believes it sent that value.
function mana_forget()   // self = player
{
	self.tod_mage_bar_v = undefined;
	self.tod_mage_bar_s = undefined;
	self.tod_mage_ab_c  = undefined;
	self.tod_mage_ab_b  = undefined;
	self.tod_mage_recharge_h = undefined;
	self.tod_mage_recharge_b = undefined;
	self.tod_mage_tut_sent = undefined;   // v19.11
}

// ---- THE LETHAL'S CHARGES -------------------------------------------------

// The domain level buys CHARGES: 1 at Lv1-2, 2 at Lv3-4, 3 at Lv5-6.
function charges_max()   // self = player
{
	lv = tod_upgrades::get_level( self, "mage_heal" );
	if ( lv < 1 )
		return 0;   // no charges until HEALING AURA is unlocked
	n = 1 + int( ( lv - 1 ) / 2 );
	if ( n > TOD_MAGE_CHG_MAX )
		n = TOD_MAGE_CHG_MAX;
	return n;
}

function charges_now()   // self = player
{
	mx = self charges_max();
	if ( !isdefined( self.tod_mage_charges ) )
		self.tod_mage_charges = mx;   // arrive full
	// First unlock and capacity upgrades grant only the newly unlocked slots.
	// Polling the HUD or re-entering the class cannot refill spent charges.
	if ( isdefined( self.tod_mage_charge_cap ) && mx > self.tod_mage_charge_cap )
		self.tod_mage_charges += mx - self.tod_mage_charge_cap;
	self.tod_mage_charge_cap = mx;
	if ( self.tod_mage_charges > mx )
		self.tod_mage_charges = mx;
	return self.tod_mage_charges;
}

// One charge back every TOD_MAGE_CHG_RECHARGE_S, shortened by ATTUNEMENT.
// Threaded from the cast so nothing runs while the player is full.
function charge_regen()   // self = player
{
	self endon( "disconnect" );
	self notify( "tod_mage_charge_regen" );
	self endon( "tod_mage_charge_regen" );
	self endon( "tod_mage_disarm" );

	while ( self charges_now() < self charges_max() )
	{
		secs = TOD_MAGE_CHG_RECHARGE_S * self cooldown_scale();
		left = secs;
		// v19.38 RESUME, NEVER RESTART. Every cast re-threads this (the notify
		// above kills the old copy), and it used to start the countdown over at
		// 22 s — a recast with a charge half-returned threw that progress away.
		// Carry on from where the killed copy left off, the way Blink keeps its
		// deadline. A finished charge leaves `left` at <= 0, so the next one
		// starts full as before.
		if ( isdefined( self.tod_mage_heal_recharge_left ) && self.tod_mage_heal_recharge_left > 0 && self.tod_mage_heal_recharge_left < secs )
			left = self.tod_mage_heal_recharge_left;
		self.tod_mage_heal_recharge_secs = secs;
		self.tod_mage_heal_recharge_left = left;
		while ( left > 0 )
		{
			wait 0.25;
			if ( IS_TRUE( level.tod_upgrade_pause ) )
				continue;
			left -= 0.25;
			self.tod_mage_heal_recharge_left = left;
		}
		self.tod_mage_charges = self charges_now() + 1;
	}
}

// 0..99 while a charge is returning; -1 hides a full/locked ability.
// Read the actual recharge timers, including the existing pause handling.
function recharge_percent( left, total )
{
	if ( !isdefined( left ) || !isdefined( total ) || total <= 0 ) return 0;
	pct = int( 100 - 100.0 * left / total );
	if ( pct < 0 ) pct = 0;
	if ( pct > 99 ) pct = 99;
	return pct;
}

function recharge_send()   // self = player
{
	heal = -1;
	blink = -1;
	if ( self charges_now() < self charges_max() )
		heal = recharge_percent( self.tod_mage_heal_recharge_left, self.tod_mage_heal_recharge_secs );
	if ( self blink_charges_now() < self blink_capacity() )
		blink = recharge_percent( self.tod_mage_cd[ "mage_blink" ] - GetTime(), self blink_recharge_ms() );
	if ( isdefined( self.tod_mage_recharge_h ) && self.tod_mage_recharge_h == heal
	  && isdefined( self.tod_mage_recharge_b ) && self.tod_mage_recharge_b == blink ) return;
	self.tod_mage_recharge_h = heal;
	self.tod_mage_recharge_b = blink;
	self LuiNotifyEvent( &"tod_mage_recharge", 2, heal, blink );
}

// ---- MAGE HUD UPDATES ----------------------------------------------------
// Mana and ability charges use LUI. Healing Aura has no text overlay.

// ---------------------------------------------------------------------------
// v19.11 — THE CONTROLS OVERLAY (Workshop, Bigfsi 2026-09-15: "The grenade 'G'
// button is healing, 'E' is blink forward. Then theres another icon that
// suggests a 3rd ability ... Right clicking with the staff after its charged up
// does....something ... Class needs more explanation please").
//
// The server's whole part is a USE COUNT per ability, pushed to the HUD on the
// tod_mage_tut eventstring. The HUD draws each ability's button beside its tile
// (Blink / Healing Aura) and under the mana bar (Archmage) until that ability
// has been cast TOD_MAGE_TUT_USES times, then retires that one line.
//
// NO DEVICE BRANCH ANYWHERE: the Lua writes the [{+smoke}] / [{+frag}] /
// [{+speed_throw}] tokens and the ENGINE expands them into the live device's
// own key or button picture (the same lane as every prompt footer and the
// card-panel plates — v16.29 / v17.55). Pad or keyboard, rebinds included.
//
// Counted at the SPEND, never at the press: a refused cast (locked, empty,
// blocked landing, bar not full) teaches nothing and does not count.
// ---------------------------------------------------------------------------
function tut_count( key )   // self = player
{
	if ( !isdefined( self.tod_mage_tut ) )
		self.tod_mage_tut = [];
	if ( !isdefined( self.tod_mage_tut[ key ] ) )
		self.tod_mage_tut[ key ] = 0;
	if ( self.tod_mage_tut[ key ] >= TOD_MAGE_TUT_USES )
		return;   // already retired; stop counting so the number means something in the log
	self.tod_mage_tut[ key ]++;
	tut_dev_log( "use " + key + " -> " + self.tod_mage_tut[ key ] + "/" + TOD_MAGE_TUT_USES
		+ ( ( self.tod_mage_tut[ key ] >= TOD_MAGE_TUT_USES ) ? " (hint retired)" : "" ) );
	self tut_send();
}

function tut_uses( key )   // self = player
{
	if ( !isdefined( self.tod_mage_tut ) || !isdefined( self.tod_mage_tut[ key ] ) )
		return 0;
	return self.tod_mage_tut[ key ];
}

// Change-gated like mana_send / abil_send; mana_forget clears the gate so the
// 5 s self-heal re-hydrates a HUD the engine rebuilt on a death.
function tut_send()   // self = player
{
	h = self tut_uses( "heal" );
	b = self tut_uses( "blink" );
	a = self tut_uses( "arch" );
	packed = h * 100 + b * 10 + a;
	if ( isdefined( self.tod_mage_tut_sent ) && self.tod_mage_tut_sent == packed )
		return;
	self.tod_mage_tut_sent = packed;
	self LuiNotifyEvent( &"tod_mage_tut", 3, h, b, a );
}

function tut_dev_log( msg )   // self = player
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	line = "[TOD_MAGE_TUT] ms=" + GetTime() + " " + self.name + " " + msg;
	/#
	PrintLn( line );
	#/
}

// ---- v19.25 STAFF CADENCE DIAGNOSTICS -------------------------------------
//
// Two features shipped in one build that both change how often a staff fires,
// by two COMPLETELY different mechanisms, and only one of them is visible in
// script. This logs both so one dev playtest settles both:
//
//   [TOD_STAFF_RATE] RAPID FLAME — the fire staff's script cooldown. Logged on
//       CHANGE only (a card taken, a class change, a tier reset), never per
//       shot: the value is a pure function of the level, so a per-shot line
//       would be the same number a hundred times.
//   [TOD_STAFF_RATE] DTAP — the ice staff's Double Tap twin. This is the one
//       that can fail SILENTLY: the swap is a weapon asset change, so if the
//       d1 variant did not link, reconcile_twin's "never take the player's
//       gun" fallback keeps the old staff and NOTHING says so. `want` vs
//       `held` is exactly that check — if they ever differ after a perk flip
//       has settled, the twin is missing, not the perk.
//
// ⚠️ IT RUNS WITH DEV OFF, ON ITS OWN SWITCH, AND THAT IS DELIBERATE. The ship
// state is `tod_dev = false` (the user tests normal builds), so gating this on
// tod_dev would have printed NOTHING in the one playtest it exists for - the
// same trap TOD_HOOP_LOG was given its own switch to avoid. The user's launcher
// already passes `developer 1` + `scr_mod_enable_devblock 1`, so a wrapped
// PrintLn records in their run. **TEMPORARY: zero TOD_STAFF_RATE_LOG before a
// publish.** Change-gated and bounded, so even left on it is a handful of lines
// per match; it touches no gameplay state.
#define TOD_STAFF_RATE_LOG 0   // 0 = SHIP (zeroed 2026-09-23 for the v19.50 publish); 1 for a normal-mode playtest

// Change-gated, bounded, no history kept, and it touches no gameplay state.
function cadence_dev_log( msg )   // self = player
{
	if ( !TOD_STAFF_RATE_LOG )
		return;
	line = "[TOD_STAFF_RATE] ms=" + GetTime() + " " + self.name + " " + msg;
	/#
	PrintLn( line );
	#/
}

// Threaded per armed mage from init_player. One tick a second, which is the
// same cadence reconcile_twin runs at, so a swap is seen on the tick after it.
function cadence_watch()   // self = player
{
	self endon( "disconnect" );
	self notify( "tod_mage_cadence_watch" );
	self endon( "tod_mage_cadence_watch" );
	if ( !TOD_STAFF_RATE_LOG )
		return;
	for ( ;; )
	{
		wait 1;
		if ( !IS_TRUE( self.tod_mage_armed ) || !IsAlive( self ) )
			continue;

		ms = self fire_recovery_ms();
		if ( !isdefined( self.tod_rate_log_ms ) || self.tod_rate_log_ms != ms )
		{
			self.tod_rate_log_ms = ms;
			self cadence_dev_log( "RAPID_FLAME lv=" + tod_upgrades::get_level( self, "mage_rate" )
			                      + " cooldown_ms=" + ms + " base_ms=" + TOD_MAGE_FIRE_RECOVERY_MS );
		}

		// The ice half. `held` is read off the inventory rather than the held
		// weapon so a mage with the fire staff out is still reported.
		perk = self HasPerk( "specialty_doubletap2" );
		held = "none";
		weapons = self GetWeaponsListPrimaries();
		for ( i = 0; i < weapons.size; i++ )
		{
			if ( isdefined( weapons[ i ] ) && IsSubStr( weapons[ i ].name, "tod_staff_ice" ) )
				held = weapons[ i ].name;
		}
		stamp = ( perk ? "1" : "0" ) + " " + held;
		if ( !isdefined( self.tod_dtap_log ) || self.tod_dtap_log != stamp )
		{
			self.tod_dtap_log = stamp;
			self cadence_dev_log( "DTAP perk=" + ( perk ? 1 : 0 )
			                      + " want_suffix=d" + ( perk ? 1 : 0 ) + " held=" + held );
		}
	}
}

function mage_hud_hide()   // self = player
{
	if ( !isdefined( self.tod_mage_hud ) )
		return;
	for ( i = 0; i < self.tod_mage_hud.size; i++ )
	{
		if ( isdefined( self.tod_mage_hud[ i ] ) )
			self.tod_mage_hud[ i ] Destroy();
	}
	self.tod_mage_hud = undefined;
}

function mage_hud_watch()   // self = player
{
	self endon( "disconnect" );
	self notify( "tod_mage_hud_watch" );
	self endon( "tod_mage_hud_watch" );
	self endon( "tod_mage_disarm" );

	self mage_hud_hide();
	heal_tick = 0;
	// Retain the lifecycle marker so mage_hud_hide stops this update loop.
	self.tod_mage_hud = [];

	for ( ;; )
	{
		wait 0.25;
		if ( !isdefined( self.tod_mage_hud ) )
			return;

		m = int( self mana_now() );
		self mana_push( m );

		// SELF-HEALING, every 5 s. The ammo bay's whole widget lifecycle re-runs
		// on a death, so the bar can go blank while the change-gate still holds
		// the value it last sent. Forgetting periodically means the worst case
		// is a bar that is blank for five seconds, not for the rest of the life.
		heal_tick++;
		if ( heal_tick >= 20 )
		{
			heal_tick = 0;
			self mana_forget();
		}

		self abil_send( self charges_now(), self blink_charges_now() );
		self tut_send();   // v19.11: change-gated; re-sent after every mana_forget so a rebuilt HUD hydrates
		if ( !IS_TRUE( level.tod_upgrade_pause ) )
			self recharge_send();

	}
}

// ---- THE FIRE STAFF'S CHARGE ----------------------------------------------

// The native 1.43s firing state blocked use prompts as well as switching.
// Keep that cadence with the FIRE-ONLY native flag, not DisableWeapons: doors,
// altars, reload, melee and cycling retain their own normal input paths.
// This controller survives death/disarm long enough to release its flag. It
// owns no other lock, and never enables weapons disabled by a menu or laststand.
function fire_recovery_watch()   // self = player
{
	self endon( "disconnect" );
	self notify( "tod_mage_fire_recovery_watch" );
	self endon( "tod_mage_fire_recovery_watch" );
	self thread fire_recovery_shots();
	for ( ;; )
	{
		self fire_recovery_update();
		wait 0.05;
	}
}

function fire_recovery_shots()   // self = player
{
	self endon( "disconnect" );
	self endon( "tod_mage_fire_recovery_watch" );
	for ( ;; )
	{
		self waittill( "weapon_fired", weapon );
		element = staff_element( weapon );
		if ( isdefined( element ) && element == "fire" && IS_TRUE( self.tod_mage_armed ) )
		{
			self.tod_mage_fire_ready_ms = GetTime() + self fire_recovery_ms();
			self fire_recovery_update();
		}
	}
}

// RAPID FLAME's one owner (v19.25). self = player -> this shot's cooldown in ms.
//
// READ AT THE SHOT, not latched at the card: a deal mid-fight takes effect on
// the next shot rather than the next life, and a class change away from the
// mage simply stops asking. The level is CLAMPED here as well as at the card,
// because the DARK pool and dev_grant_maxed both write levels through paths
// that do not re-read a domain's max.
function fire_recovery_ms()   // self = player
{
	lv = tod_upgrades::get_level( self, "mage_rate" );
	if ( lv > TOD_MAGE_FIRE_RATE_MAX_LV )
		lv = TOD_MAGE_FIRE_RATE_MAX_LV;
	if ( lv < 0 )
		lv = 0;
	ms = TOD_MAGE_FIRE_RECOVERY_MS * ( 1.0 - TOD_MAGE_FIRE_RATE_PER_LV * lv );
	// The engine's own firing state is the floor no script cooldown can go
	// under, and a cooldown at or below it would hand the cadence back to the
	// weapon without saying so. Nothing on this ladder reaches it (Lv5 is 786),
	// but a future retune must not be able to silently uninstall the controller.
	if ( ms < 100 )
		ms = 100;
	return Int( ms );
}

function fire_recovery_update()   // self = player
{
	element = staff_element( self GetCurrentWeapon() );
	blocked = IS_TRUE( self.tod_mage_armed ) && IsAlive( self )
	    && !self laststand::player_is_in_laststand()
	    && isdefined( element )
	    && element == "fire" && isdefined( self.tod_mage_fire_ready_ms )
	    && GetTime() < self.tod_mage_fire_ready_ms;
	if ( blocked && !IS_TRUE( self.tod_mage_fire_blocked ) )
	{
		self DisableWeaponFire();
		self.tod_mage_fire_blocked = true;
	}
	else if ( !blocked && IS_TRUE( self.tod_mage_fire_blocked ) )
	{
		self EnableWeaponFire();
		self.tod_mage_fire_blocked = false;
	}
}

// Time the trigger hold and stamp the charge the RELEASE earned. The engine
// fires on release for a "Charge Shot" weapon, so the damage event lands within
// a projectile flight of the stamp -- TOD_MAGE_CHARGE_KEEP_MS is the window in
// which staff_mult will still honour it, so a charge can never be banked and
// spent on a later shot.
function charge_watch()   // self = player
{
	self endon( "disconnect" );
	self notify( "tod_mage_charge_watch" );
	self endon( "tod_mage_charge_watch" );
	self endon( "tod_mage_disarm" );

	for ( ;; )
	{
		wait 0.05;
		if ( !self AttackButtonPressed() )
			continue;

		// Only the charge staff banks a hold; the others fire on press.
		el = staff_element( self GetCurrentWeapon() );
		if ( !isdefined( el ) || el != "fire" )
		{
			while ( self AttackButtonPressed() )
				wait 0.05;
			continue;
		}

		// Holding attack during recovery/menu/reload cannot pre-bank a charge.
		if ( IS_TRUE( self.tod_mage_fire_blocked ) || self IsReloading()
		  || self IsSwitchingWeapons() || IS_TRUE( self.tod_menu_frozen )
		  || IS_TRUE( level.tod_upgrade_pause ) )
			continue;

		held = 0;
		while ( self AttackButtonPressed() )
		{
			wait 0.05;
			held += 50;
			if ( held > TOD_MAGE_CHARGE_FULL_MS )
				held = TOD_MAGE_CHARGE_FULL_MS;
		}
		self.tod_mage_charge_ms   = held;
		self.tod_mage_charge_time = GetTime();
	}
}

// The multiplier the last release earned, or 1.0. Consumed by TIME, never by a
// flag: one charged shot can hit several zombies in one blast and every one of
// them must read the same charge.
function charge_mult()   // self = player
{
	if ( !isdefined( self.tod_mage_charge_time ) || !isdefined( self.tod_mage_charge_ms ) )
		return 1.0;
	if ( GetTime() - self.tod_mage_charge_time > TOD_MAGE_CHARGE_KEEP_MS )
		return 1.0;
	if ( self.tod_mage_charge_ms <= TOD_MAGE_CHARGE_MIN_MS )
		return 1.0;

	span = TOD_MAGE_CHARGE_FULL_MS - TOD_MAGE_CHARGE_MIN_MS;
	frac = ( self.tod_mage_charge_ms - TOD_MAGE_CHARGE_MIN_MS ) / span;
	if ( frac > 1 )
		frac = 1;
	// pow() is a real engine builtin (13 stock call sites, fractional bases
	// included: `pow( 1 - t, 3 )` in the bezier helpers). exp() is NOT -- zero
	// stock uses -- so do not "simplify" this back into exp/log.
	curved = pow( frac, TOD_MAGE_CHARGE_EXP );
	return 1.0 + TOD_MAGE_CHARGE_BONUS * curved;
}

// ---- ICE VOLLEY ----------------------------------------------------------

// ONE SHOT, ONE IDENTITY (2026-09-09).
//
// upgrade_damage_cb threads staff_hit once per DAMAGED ACTOR, and a staff bolt
// is splash -- so a bolt landing in a crowd ran CHAIN LIGHTNING's whole arc
// selection once for every zombie the blast touched. A Lv6 mage clearing a
// stairwell was paying out 4 arcs per splash victim rather than 4 per shot, and
// the denser the horde the further it ran away from the card's own text.
//
// A counter is the cheapest exact answer: splash callbacks for one bolt all see
// the same id, and the next trigger pull changes it. A time window would have
// worked at the lightning staff's ~229 ms cadence (195 until 2026-09-09) and
// broken the moment anyone touched the fire rate.
function shot_id_watch()
{
	self endon( "disconnect" );
	self endon( "death" );
	self notify( "tod_mage_shot_id_watch" );
	self endon( "tod_mage_shot_id_watch" );
	self endon( "tod_mage_disarm" );
	for ( ;; )
	{
		self waittill( "weapon_fired", weapon );
		if ( !isdefined( self.tod_mage_shot_id ) )
			self.tod_mage_shot_id = 0;
		self.tod_mage_shot_id++;
		self bolt_count_shot( weapon );   // v18.77: the lightning reload counter
	}
}

function ice_volley_watch()
{
	self endon( "disconnect" );
	self endon( "death" );
	self notify( "tod_mage_ice_volley_watch" );
	self endon( "tod_mage_ice_volley_watch" );
	self endon( "tod_mage_disarm" );
	for ( ;; )
	{
		self waittill( "weapon_fired", weapon );
		self ice_side_shots( weapon );
	}
}

function ice_side_shots( weapon )
{
	element = staff_element( weapon );
	if ( !isdefined( element ) || element != "ice" )
		return;

	// The engine already fired the center bolt. Add two REAL missiles using
	// that exact weapon variant and owner, so normal damage, PaP, matchup,
	// Insta-Kill and ice slow callbacks apply to their hits as well.
	// Stock _gadget_multirocket uses weapon_fired -> MagicBullet too: these
	// launches do not consume more ammo or recursively fire the held weapon.
	angles = self GetPlayerAngles();
	forward = AnglesToForward( angles );
	right = AnglesToRight( angles );
	// v18.93 (user: "just move where the shot starts"): these two missiles used to
	// launch from the EYE, so their trail sprites bloomed on the shooter's camera
	// every shot -- the "flash in my face" that survived three effect trims. Start
	// them TOD_MAGE_ICE_VOLLEY_START units out, level with the shifted tag_flash
	// the centre bolt leaves from (fitted ice clips, tools/bo6_extraction/shift_ice_flash.py).
	start = self GetEye() + forward * TOD_MAGE_ICE_VOLLEY_START;
	// tan(8 degrees): a symmetric fan in view space, including steep aim.
	for ( side = -1; side <= 1; side += 2 )
	{
		direction = VectorNormalize( forward + right * ( side * 0.140540835 ) );
		MagicBullet( weapon, start, start + direction * 16384, self );
	}
}

// ---- THE STAFF GLOW (server half) -----------------------------------------

// 0 none / 1 lightning / 2 fire / 3 ice -- LOCKSTEP with the .csc's
// level._effect[ "tod_staff_glow_<n>" ] table.
function staff_glow_value( weapon )
{
	el = staff_element( weapon );
	if ( !isdefined( el ) )
		return 0;
	if ( el == "lightning" )
		return 1;
	if ( el == "fire" )
		return 2;
	return 3;
}

// Retain the replicated element and field layout. First-person aura timing
// now follows client weapon_change directly, without a replicated delay.
function glow_watch()   // self = player
{
	self endon( "disconnect" );
	self notify( "tod_mage_glow_watch" );
	self endon( "tod_mage_glow_watch" );
	self endon( "tod_mage_disarm" );

	self clientfield::set_to_player( TOD_STAFF_GLOW_FIELD, staff_glow_value( self GetCurrentWeapon() ) );
	for ( ;; )
	{
		self waittill( "weapon_change", w );
		self clientfield::set_to_player( TOD_STAFF_GLOW_FIELD, staff_glow_value( w ) );
	}
}

// ---- COOLDOWN --------------------------------------------------------------

function ready( key )   // self = player
{
	if ( key == "mage_blink" )
	{
		charges = self blink_charges_now();
		return charges > 0;
	}
	// Missing cooldown means ready only AFTER the ability's card is unlocked.
	// Both the cast and the HUD ask here, so locked Blink stays dim and blocked.
	if ( tod_upgrades::get_level( self, key ) < 1 )
		return false;
	// Cooldowns are gameplay rules even with money/god/test flags enabled.
	if ( !isdefined( self.tod_mage_cd ) || !isdefined( self.tod_mage_cd[ key ] ) )
		return true;
	return GetTime() >= self.tod_mage_cd[ key ];
}

function arm_cooldown( key, secs )   // self = player
{
	if ( !isdefined( self.tod_mage_cd ) )
		self.tod_mage_cd = [];
	self.tod_mage_cd[ key ] = GetTime() + int( secs * 1000 * self cooldown_scale() );
}

// COOLDOWNS DO NOT RUN WHILE THE WORLD IS PAUSED (2026-09-09).
//
// Every value in tod_mage_cd is an ABSOLUTE GetTime() stamp -- BLINK's recharge
// deadline and HEALING AURA's post-cast lock -- and GetTime() keeps running
// through a world pause. So a mage came out of a card event, a won trial or the
// Warden King's max-out with Blink charges it had not waited for: the round
// event alone is 15 s against a 6-9 s recharge, and the King's dark deals run
// far longer than that. The player is frozen, invulnerable and unable to cast,
// so the recharge is pure profit for standing still.
//
// The other two mage timers already got this right and are the precedent: the
// per-second mana tick skips a paused tick outright (mana_watch), and the aura's
// charge regen holds its countdown (charge_regen). Both do it by not advancing
// while paused, which a GetTime() deadline cannot -- so instead of teaching four
// call sites to subtract, ONE watcher pushes the deadlines forward and every
// existing `GetTime() >= deadline` read stays correct as written.
//
// A deadline of 0 means idle/ready (blink_charges_now stamps that at full
// charges) and must never be pushed: `> now - delta` is false for 0, so it is
// skipped by construction rather than by a special case.
function cd_pause_watch()   // self = player
{
	self endon( "disconnect" );
	self notify( "tod_mage_cd_pause_watch" );
	self endon( "tod_mage_cd_pause_watch" );
	self endon( "tod_mage_disarm" );

	last = GetTime();
	for ( ;; )
	{
		wait 0.25;
		now = GetTime();
		delta = now - last;
		last = now;
		// Read the flag AFTER the wait: the tick that straddles the start of a
		// pause over-credits by up to one poll, the tick that ends it
		// under-credits by the same, and they cancel. A quarter second of slop
		// on a multi-second cooldown is not worth a second timestamp.
		if ( !IS_TRUE( level.tod_upgrade_pause ) || delta <= 0 )
			continue;
		if ( !isdefined( self.tod_mage_cd ) )
			continue;
		keys = GetArrayKeys( self.tod_mage_cd );
		for ( i = 0; i < keys.size; i++ )
		{
			k = keys[ i ];
			if ( self.tod_mage_cd[ k ] > now - delta )
				self.tod_mage_cd[ k ] = self.tod_mage_cd[ k ] + delta;
		}
	}
}

// ATTUNEMENT shortens the aura's recharge. ladder5() is the shared
// 10/18/24/28/32% curve.
// ⚠️ ALWAYS 1.0 SINCE v18.41 -- ATTUNEMENT, the only domain that ever moved it,
// is retired. Kept rather than deleted because two live call sites multiply by
// it (the heal charge regen and arm_cooldown), so this is a permanent identity
// until something is given the job. Delete the function and both call sites
// together, or not at all -- the sprint_armor_mult precedent.
function cooldown_scale()   // self = player
{
	return 1.0;
}

// ELITE-KILL COOLDOWN REFUND: REMOVED 2026-09-09 (user: "Elite kills refund
// blink cool down. Remove that feature"). elite_kill() and the
// level.tod_mage_elite_kill pointer are gone; _tod_bosses still guards the
// pointer with isdefined, so its call site needs no change. Mana per elite
// (elite_mana, below) is a separate lane and stays.

// PUBLIC -- called from _tod_bosses through the guarded level pointer, from
// grant_elite_reward (every elite family and the guard Panzer) AND from the
// boss-round Panzer's own payout lane, which never reaches grant_elite_reward.
// `kind` is the reward label ("PANZER" or any elite). Killer only. See the
// TOD_MAGE_MANA_ELITE block for the curve.
function elite_mana( attacker, kind )
{
	if ( !isdefined( attacker ) || !IsPlayer( attacker ) )
		return;
	if ( !IS_TRUE( attacker.tod_mage_armed ) )
		return;
	attacker mana_add( elite_mana_value( kind, level.round_number ) );
}

// PUBLIC -- called from _tod_powerups::max_ammo_clip_watch through the guarded
// level pointer, after stock full_ammo has refilled every gun (user 2026-09-09:
// "Max ammo needs to fill archmage mana bar. But player must have the upgrade
// of course"). The mage has no ammunition to refill, so the bar IS its Max
// Ammo. Requires the first ARCHMAGE card (mana_add zeroes a locked bar and the
// HUD shows state 3 -- nothing to fill). Written directly rather than through
// mana_add so a grab DURING the form still banks a full bar for the next one:
// the trickle/kill guard against "one bar buys two" is about regeneration, and
// a Max Ammo is a discrete drop that refills everyone else outright too. The
// HUD push is immediate; while the form runs mana_push draws the form timer
// instead, and the full bar shows the moment it ends.
function max_ammo()   // self = player
{
	if ( !isdefined( self ) || !IsPlayer( self ) || !IS_TRUE( self.tod_mage_armed ) )
		return;

	// v18.99 — A MAX AMMO CLEARS THE LIGHTNING STAFF'S OWED RELOAD (user: "max
	// ammo, the lightning staff. Reload needs to reset, or the lightning staff
	// clip needs to reset"). Stock's full_ammo refills every real gun, so the
	// staff was the ONE weapon in the map a Max Ammo did nothing for: its
	// forced reload is script's counter plus a clip pinned to 0, invisible to
	// the powerup. Reset sits ABOVE the ARCHMAGE gate on purpose — the mana
	// fill is what the card buys; getting your ammo back is not.
	self bolt_reload_reset();
	held = self GetCurrentWeapon();
	if ( isdefined( held ) && isdefined( staff_element( held ) ) && !self IsReloading() )
		self SetWeaponAmmoClip( held, self staff_clip_target( held ) );

	if ( self arch_level() < 1 )
		return;
	self.tod_mage_mana = TOD_MAGE_MANA_MAX;
	self mana_push( TOD_MAGE_MANA_MAX );
}

// What one elite or Panzer kill is worth to the bar in round `r`. Pure, so the
// test can sweep it: full through FULL_ROUND, then FULL_ROUND / r, floored.
function elite_mana_value( kind, r )
{
	base = TOD_MAGE_MANA_ELITE;
	if ( isdefined( kind ) && kind == "PANZER" )
		base = TOD_MAGE_MANA_PANZER;
	if ( !isdefined( r ) || r < 1 )
		r = 1;
	scale = 1.0;
	if ( r > TOD_MAGE_MANA_ELITE_FULL_ROUND )
		scale = TOD_MAGE_MANA_ELITE_FULL_ROUND / r;
	if ( scale < TOD_MAGE_MANA_ELITE_FLOOR )
		scale = TOD_MAGE_MANA_ELITE_FLOOR;
	return base * scale;
}

// ---- THE STAFFS' DAMAGE ARM (called from _tod_upgrades::upgrade_damage_cb) --

// Which staff fired. Every generated form of a staff embeds its stem
// ("tod_staff_lightning_b"), so a substring on the element is exact.
function staff_element( weapon )
{
	if ( !isdefined( weapon ) || !isdefined( weapon.name ) || !IsSubStr( weapon.name, "tod_staff_" ) )
		return undefined;
	if ( IsSubStr( weapon.name, "lightning" ) )
		return "lightning";
	if ( IsSubStr( weapon.name, "fire" ) )
		return "fire";
	if ( IsSubStr( weapon.name, "ice" ) )
		return "ice";
	return undefined;
}


function boss_kind( ai )
{
	if ( !isdefined( ai ) || !isdefined( ai.tod_boss_kind ) )
		return "";
	return ai.tod_boss_kind;
}

// The whole multiplier for one staff hit: tier ladder x matchup x the staff's
// own card. Returns 1.0 for anything that is not a staff.
// WHICH STAFF WAS BUILT FOR THIS VICTIM. One classifier, so the table above is
// the whole truth and a new enemy type is one line here rather than a branch in
// every staff. Anything unmarked is TRASH, which is lightning's family — that
// default is the right way round: the horde is what the map is mostly made of.
function victim_family( victim )
{
	// GUARD FIRST. boss_kind() checks isdefined itself, but the sprinter test
	// below reads a FIELD, and a .field on an undefined entity throws in this
	// dialect. Treating a missing victim as trash is the safe default: it is
	// the neutral-to-slightly-favourable arm, never a free x2.
	if ( !isdefined( victim ) )
		return "lightning";
	kind = boss_kind( victim );
	if ( kind == "panzer" )
		return "panzer";
	if ( kind == "protector" || IS_TRUE( victim.tod_is_sprinter ) )
		return "fire";
	if ( kind == "hellhound" || kind == "reaver" )
		return "ice";
	return "lightning";
}

// THE OFF-FAMILY PENALTY NEEDS A CHOICE TO PUNISH (v18.50).
//
// The user's ask for the matchup table was "each staff is good against what
// they are good against and bad against the rest" -- and "the rest" presupposes
// that a right answer was available and not taken. It is not available for the
// whole first tier: a tier-1 mage holds ONE staff, so from round 1 it ate a
// flat x0.45 on every Rogue Protector wave, every hellhound round and every
// armored sprinter with nothing whatsoever it could have done differently.
// That is not skill expression, it is a tax on not having been promoted yet.
//
// So the penalty now asks whether this mage HOLDS the staff that owns the
// victim's family. It does not at tier 1 (fire and ice unowned) or at tier 2
// (ice unowned), and at tier 3 it always does -- which is exactly where the
// full table was designed to live. The Panzer arm is untouched: it is nobody's
// family by design, so being weak to it is never a mistake the player made.
//
// The family names ARE the element names, which is what keeps this three lines.
function family_answerable( t, fam )
{
	if ( fam == "fire" )
		return ( t >= 2 );
	if ( fam == "ice" )
		return ( t >= 3 );
	return true;   // lightning's family -- the first staff, always held
}

// What a staff does to somebody else's target -- the number that decides whether
// it is a SPECIALIST or a GENERALIST. See the block on TOD_MAGE_FIRE_OFF.
function off_family_mult( el )
{
	if ( el == "fire" )
		return TOD_MAGE_FIRE_OFF;
	if ( el == "ice" )
		return TOD_MAGE_ICE_OFF;
	return TOD_MAGE_LIGHTNING_OFF;
}

// The right staff on its own target. One value per staff rather than one shared
// constant, because the three have different raw damage and the contract is
// about WHERE EACH LANDS, not about them sharing a number. See the block on
// TOD_MAGE_VS_HORDE.
function on_family_mult( el )
{
	if ( el == "fire" )
		return TOD_MAGE_FIRE_VS_ARMOUR;
	if ( el == "ice" )
		return TOD_MAGE_ICE_VS_BEAST;
	return TOD_MAGE_VS_HORDE;
}

function staff_mult( attacker, victim, weapon )
{
	el = staff_element( weapon );
	if ( !isdefined( el ) || !isdefined( attacker ) || !IsPlayer( attacker ) )
		return 1.0;

	// ⚠️ MULTIPLY, DO NOT ASSIGN (fixed v18.42, 2026-09-08). These two branches
	// read `m = TOD_MAGE_TIER*_MULT` from v18.37 until now, which THREW AWAY the
	// demigod multiplier the line above had just computed. ARCHMAGE — the
	// headline ability of the whole class, and the thing the mana bar is spent
	// on — therefore did NOTHING above tier 1. It survived testing because
	// tier 1 is the one tier that takes neither branch, and tier 1 is where a
	// new class gets tried.
	m = attacker demigod_mult();   // v18.37: x2 while ARCHMAGE runs
	t = tod_classes::tier( attacker );
	if ( t >= 3 )
		m *= TOD_MAGE_TIER3_MULT;
	else if ( t == 2 )
		m *= TOD_MAGE_TIER2_MULT;
	else
		m *= TOD_MAGE_TIER1_MULT;   // v18.51: tier 1 is a rung like the others now

	// THE MATCHUP — exactly one of these arms fires. See the table above.
	//
	// ⚠️ REORDERED IN v18.53 TO FIX A FALL-THROUGH, and the bug is worth keeping
	// written down because it was invisible: v18.50's `fam != el && answerable`
	// guard meant a wrong-staff hit on a family the mage CANNOT yet answer fell
	// past the penalty and into the on-family arm below it -- so a tier-2 mage
	// pointing the FIRE staff at a hellhound was paid the full on-family x2.00
	// for using the wrong staff, and a tier-1 mage pointing lightning at a
	// Protector got x1.25. The neutral case has to be its own arm, not the
	// bottom of an else chain: `fam == el` is now tested explicitly.
	fam = victim_family( victim );
	if ( fam == "panzer" )
	{
		// v18.52: lightning OWNS this target; the other two are simply wrong for
		// it. Exclusive -- the off-family penalty never stacks on top.
		if ( el == "lightning" )
			m *= TOD_MAGE_LIGHTNING_VS_PANZER;
		else
			m *= off_family_mult( el );   // v18.56: ice is OKAY here, fire is not
	}
	else if ( fam == el )
		m *= on_family_mult( el );        // the right staff, on its own target
	else
	{
		// A BONUS ALWAYS APPLIES; A PENALTY NEEDS A CHOICE TO PUNISH (v18.56).
		// family_answerable() exists so a mage is not taxed for a staff it
		// cannot own yet -- but ice's off-family value is now ABOVE 1.0, and
		// withholding a bonus on that rule would make "no choice available"
		// WORSE than "chose wrong", which is backwards. So the gate applies to
		// the penalty case only.
		off = off_family_mult( el );
		if ( el == "fire" && fam == "ice" )
			m *= TOD_MAGE_FIRE_VS_BEAST;   // 2026-09-09 playtest: its own arm, never tier-gated (see the define)
		else if ( off >= 1.0 || family_answerable( t, fam ) )
			m *= off;
	}

	// THE PER-STAFF CARDS scale their own staff wherever it is pointed. They are
	// bought with a card, not earned by aiming at the right thing, so they are
	// deliberately outside the matchup: FIRE BLAST makes the fire staff better,
	// including at the things the fire staff is bad at.
	//
	// FIRE BLAST IS THE BIGGEST NUMBER IN THE CLASS AND THAT IS PAID FOR IN RATE
	// (user 2026-09-08: "Fire blast should be quite strong but its fire rate is
	// what will prevent people from using it"). Worth being precise about,
	// because it is easy to read the multiplier as unpriced: the staff's DPS is
	// computed over its REAL cycle -- recovery 1.573 s PLUS the 0.90 s charge hold
	// its x2.5 payoff requires -- so 2.473 s per shot is already inside every
	// figure this class is ranked on. The rate then costs a SECOND time in a way
	// no DPS column can show: a charge is a commitment, and a horde that closes
	// mid-hold is a shot you do not get to take.
	if ( el == "fire" )
	{
		m *= 1.0 + TOD_MAGE_FIRE_DMG_PER_LV * tod_upgrades::get_level( attacker, "mage_fire" )
		     + ( tod_upgrades::has_dark( attacker, "mage_fire" ) ? TOD_MAGE_FIRE_DARK_ADD : 0 );
		m *= attacker charge_mult();   // v18.36: the longer the hold, the bigger the hit
		m *= TOD_MAGE_FIRE_NERF;       // 2026-09-21: -5% on every fire hit
	}
	else if ( el == "ice" )
	{
		m *= 1.0 + TOD_MAGE_ICE_DMG_PER_LV * tod_upgrades::get_level( attacker, "mage_ice" )
		     + ( tod_upgrades::has_dark( attacker, "mage_ice" ) ? TOD_MAGE_ICE_DARK_ADD : 0 );
		// 2026-09-09: -20% everywhere, and 30% of that against armour and the robot.
		m *= TOD_MAGE_ICE_NERF;
		if ( fam == "fire" || fam == "panzer" )
			m *= TOD_MAGE_ICE_VS_ARMOUR_ROBOT;
		// 2026-09-21: a further -10% on the horde and the Panzer ONLY. "lightning"
		// IS the horde family (see the define) -- beasts and armour are untouched.
		if ( fam == "lightning" || fam == "panzer" )
			m *= TOD_MAGE_ICE_VS_HORDE_PANZER;
	}
	else if ( el == "lightning" )
	{
		// 2026-09-09: -10% unpacked, -20% packed (see the defines). pap_tier reads
		// the per-stem level, so it is right on q0/q1 and every PACK tier.
		if ( tod_classes::pap_tier( attacker, weapon ) >= 1 )
			m *= TOD_MAGE_LIGHTNING_PAP_NERF;
		else
			m *= TOD_MAGE_LIGHTNING_NERF;
	}

	return m;
}

// The FIRE staff burns through the armored sprinter's plating: the callback
// skips its damage cut (and the ricochet) for it.
// v19.26 -- WHO THE STAFF CARDS' UTILITY HALVES APPLY TO. The map's one
// "boss or elite" predicate (the triad: Panzer, Rogue Protector, Reaver,
// hellhound, every Warden incl. the King) PLUS the armored sprinter, which is
// trash-flagged on purpose (memory: it is a sprinter the horde lane may slow)
// but pays the elite reward and is an elite to the player. One function so the
// burn and the slow can never disagree about who is an elite.
function staff_elite( victim )
{
	if ( !isdefined( victim ) )
		return false;
	return ( tod_upgrades::is_boss_or_elite( victim ) || IS_TRUE( victim.tod_is_sprinter ) );
}

// The ice slow's SPEED multiplier at a card level: 0.45 at Lv0, 0.03 less per
// level, floored. mult < 1 slows; 0.27 at Lv6.
function ice_slow_mult( lv )
{
	if ( !isdefined( lv ) || lv < 0 )
		lv = 0;
	m = TOD_MAGE_ICE_SLOW_MULT - TOD_MAGE_ICE_SLOW_MULT_PER_LV * lv;
	if ( m < TOD_MAGE_ICE_SLOW_MIN )
		m = TOD_MAGE_ICE_SLOW_MIN;
	return m;
}

// The burn's damage for ONE tick on this victim at a card level: a share of
// MAX health, the King at a quarter rate, never under 1. Pure, so the test
// can walk it.
function burn_tick_damage( victim, lv )
{
	if ( !isdefined( victim ) || !isdefined( victim.maxhealth ) || victim.maxhealth < 1 )
		return 1;
	pct = TOD_MAGE_BURN_PCT_PER_LV * lv;
	if ( IS_TRUE( victim.tod_king ) )
		pct *= TOD_MAGE_BURN_KING_MULT;
	dmg = int( victim.maxhealth * ( pct / 100.0 ) );
	if ( dmg < 1 )
		dmg = 1;
	return dmg;
}

// self = an elite. FIRE BLAST's burn: TOD_MAGE_BURN_TICKS ticks, one every
// TOD_MAGE_BURN_TICK_MS, from the shooter's level at the hit. The newest hit
// owns the clock (notify/endon), so a second fire hit restarts rather than
// stacks -- two mages burning one Panzer is one burn at the last shooter's
// level, and that is the intended ceiling for a percent-of-max weapon.
//
// THE DAMAGE LANE is the wisp's: the tick is ALREADY the design number, so it
// must reach the victim raw. tod_mage_burn_hit is consumed by
// tod_upgrades::upgrade_damage_cb (pass-through + the crosshair number, NO
// attacker multipliers, NO sprinter armor -- the same decision the wisp made
// and for the same reason: a percent of max health already paid for the
// sprinter's health). tod_mage_hit_ms is stamped alongside it because the
// Panzer's OWN wrap (_tod_bosses::tod_mechz_damage_calc) reads that stamp to
// return the level chain's figure before stock's mechz callback can zero a
// hitLoc-"none" DoDamage. Both are same-frame marks; DoDamage is synchronous.
//
// A tick is SKIPPED, not spent, under a world pause: the callback returns 0
// there anyway, and a burn should not run down its clock during a card deal
// the victim is frozen for.
function elite_burn( attacker, lv )   // self = victim
{
	self endon( "death" );
	level endon( "end_game" );
	self notify( "tod_mage_burn" );
	self endon( "tod_mage_burn" );

	id = GetTime();
	burn_dev_log( "BURN_START " + attacker.name + " lv=" + lv + " kind=" + boss_kind( self ) + " sprinter=" + IS_TRUE( self.tod_is_sprinter ) + " king=" + IS_TRUE( self.tod_king ) + " maxhp=" + ( ( isdefined( self.maxhealth ) ) ? self.maxhealth : "undefined" ) + " id=" + id );
	ticks = 0;
	while ( ticks < TOD_MAGE_BURN_TICKS )
	{
		wait( TOD_MAGE_BURN_TICK_MS / 1000.0 );
		if ( !isdefined( self ) || !IsAlive( self ) )
			return;
		if ( !isdefined( attacker ) || !IsPlayer( attacker ) )
		{
			burn_dev_log( "BURN_END reason=attacker_gone id=" + id );
			return;
		}
		if ( IS_TRUE( level.tod_upgrade_pause ) )
			continue;   // frozen world: the clock holds, the tick is not spent
		dmg = burn_tick_damage( self, lv );
		hp_before = self.health;
		self.tod_mage_burn_hit = true;
		self.tod_mage_hit_ms   = GetTime();
		self DoDamage( dmg, self.origin, attacker, attacker, "none", "MOD_UNKNOWN", 0, GetWeapon( "none" ) );
		if ( isdefined( self ) )
			self.tod_mage_burn_hit = undefined;   // never let a stale mark ride into a real hit
		ticks++;
		burn_dev_log( "BURN_TICK " + ticks + "/" + TOD_MAGE_BURN_TICKS + " dmg=" + dmg + " hp=" + hp_before + "->" + ( ( isdefined( self ) && isdefined( self.health ) ) ? self.health : "dead" ) + " id=" + id );
	}
	burn_dev_log( "BURN_END reason=expired id=" + id );
}

function burn_dev_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	line = "[TOD_MAGE_BURN] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}

function pierce_armor( weapon )
{
	el = staff_element( weapon );
	return ( isdefined( el ) && el == "fire" );
}

// The on-hit effect, threaded by the callback AFTER the figure is final.
// self = the victim.
// One initial arc, plus one every two levels. Dark adds one extra arc (two until 2026-09-09).
function chain_targets( player )
{
	lv = tod_upgrades::get_level( player, "mage_bolt" );
	if ( lv < 1 )
		return 0;
	if ( lv > TOD_MAGE_CHAIN_MAX )
		lv = TOD_MAGE_CHAIN_MAX;
	n = 1 + int( lv / 2 );
	if ( tod_upgrades::has_dark( player, "mage_bolt" ) )
		n += 1;   // 2026-09-09 ceiling pass: +2 -> +1 (Lv6 four arcs, dark five)
	return n;
}

// +5% per card level scales the 50% base: Lv1 52.5%, Lv10 75%.
function chain_fraction( player )
{
	lv = tod_upgrades::get_level( player, "mage_bolt" );
	if ( lv < 0 )
		lv = 0;
	if ( lv > TOD_MAGE_CHAIN_MAX )
		lv = TOD_MAGE_CHAIN_MAX;
	return TOD_MAGE_CHAIN_FRAC * ( 1.0 + TOD_MAGE_CHAIN_DMG_PER_LV * lv );
}

function staff_hit( attacker, weapon, dmg )   // self = victim
{
	el = staff_element( weapon );
	if ( !isdefined( el ) || !isdefined( self ) || !isdefined( attacker ) )
		return;

	if ( el == "fire" )
	{
		// The burn tell is the STOCK actor field TRAILBLAZER already writes.
		// VALUE 2, NOT 1 (state 1 keys a "_loop" FX stock never defines).
		if ( IsAlive( self ) )
			self clientfield::set( "arch_actor_fire_fx", 2 );
		// v19.26 THE ELITE BURN -- FIRE BLAST's second half. Elites only; the
		// tell above is all the horde ever gets.
		lv = tod_upgrades::get_level( attacker, "mage_fire" );
		if ( lv > 0 && IsAlive( self ) && staff_elite( self ) )
			self thread elite_burn( attacker, lv );
		return;
	}

	if ( el == "ice" )
	{
		// v19.26: ELITES ONLY (user: "ice slow ability should only work for
		// elites"). The horde is not slowed any more; slow() used to land on
		// trash and refuse the triad, which was exactly backwards for this card.
		if ( !IsAlive( self ) || !staff_elite( self ) )
			return;
		lv = tod_upgrades::get_level( attacker, "mage_ice" );
		secs = TOD_MAGE_ICE_SLOW_BASE + TOD_MAGE_ICE_SLOW_PER_LV * lv;
		mult = ice_slow_mult( lv );
		// Two lanes for one number: the triad drives a custom locomotion ASM
		// that slow() refuses by design, so it goes through slow_elite (which
		// declines while an entrance / pause / freeze owns the rate); the
		// armored sprinter is trash-flagged and slow() is its lane.
		if ( tod_upgrades::is_boss_or_elite( self ) )
			self tod_zombie_speed::slow_elite( mult, int( secs * 1000 ) );
		else
			self tod_zombie_speed::slow( mult, int( secs * 1000 ) );
		burn_dev_log( "ICE_SLOW " + attacker.name + " lv=" + lv + " mult=" + mult + " secs=" + secs + " kind=" + boss_kind( self ) + " sprinter=" + IS_TRUE( self.tod_is_sprinter ) );
		return;
	}

	// LIGHTNING: CHAIN LIGHTNING (domain 53) hits additional nearby zombies.
	// Lv2/4/6/8/10: 2/3/4/5/6 targets; Dark adds one. Never the Panzer.
	n = chain_targets( attacker );
	if ( n <= 0 || dmg < 2 )
		return;

	// ONCE PER SHOT, NOT ONCE PER SPLASH VICTIM (2026-09-09). See shot_id_watch.
	// CLAIMED AFTER THE ELIGIBILITY TESTS ABOVE, deliberately: a splash victim
	// that took under 2 damage must not consume the shot's one arc selection and
	// leave the real hit unable to chain.
	//
	// The FIRST eligible victim of the bolt seeds the arcs, and which one that
	// is comes from the engine's damage order, not from anything decided here.
	// Stating it rather than implying the direct hit always wins -- that is a
	// claim nobody in this repo has watched happen.
	if ( isdefined( attacker.tod_mage_shot_id ) )
	{
		if ( isdefined( attacker.tod_mage_chain_shot ) && attacker.tod_mage_chain_shot == attacker.tod_mage_shot_id )
			return;
		attacker.tod_mage_chain_shot = attacker.tod_mage_shot_id;
	}

	share = int( dmg * chain_fraction( attacker ) );
	if ( share < 1 )
		share = 1;

	near = [];
	foreach ( ai in GetAITeamArray( level.zombie_team ) )
	{
		if ( !isdefined( ai ) || ai == self || !IsAlive( ai ) )
			continue;
		// Keep chain damage on the horde; the Panzer takes direct hits only.
		if ( boss_kind( ai ) == "panzer" )
			continue;
		if ( Distance( ai.origin, self.origin ) > TOD_MAGE_CHAIN_RADIUS )
			continue;
		near[ near.size ] = ai;
	}
	if ( near.size == 0 )
		return;
	near = ArraySortClosest( near, self.origin, n );

	for ( i = 0; i < near.size && i < n; i++ )
	{
		ai = near[ i ];
		if ( !isdefined( ai ) || !IsAlive( ai ) )
			continue;
		// The CLEAVE idiom: the mark makes the callback pass the figure through
		// untouched instead of re-applying the attacker's multipliers.
		ai.tod_mage_chain_hit = true;
		ai DoDamage( share, ai.origin, attacker, attacker, "none", "MOD_UNKNOWN", 0, weapon );
		// Do not start a standing torso effect on an already-lethal hit.
		if ( isdefined( ai ) && IsAlive( ai ) )
			ai thread chain_fx();
	}
}

// One refreshable effect per actor. The client attaches it to the torso and
// kills all particles on death/shutdown, rather than leaving a floating host.
function chain_fx()
{
	self notify( "tod_mage_chain_refresh" );
	self endon( "tod_mage_chain_refresh" );
	state = 1;
	if ( isdefined( self.tod_mage_chain_state ) && self.tod_mage_chain_state == 1 )
		state = 2;
	self.tod_mage_chain_state = state;
	self clientfield::set( "tod_mage_chain_fx", state );
	self util::waittill_any_timeout( 1.5, "death" );
	if ( isdefined( self ) )
	{
		self.tod_mage_chain_state = 0;
		self clientfield::set( "tod_mage_chain_fx", 0 );
	}
}

// ---- HEALING AURA ---------------------------------------------------------

// InitialWeaponRaise alone did not replay on an already-held staff in game.
// Re-equip the same asset using the existing ammo/camo-preserving path, then
// explicitly mark its NEXT raise as the first-draw animation.
function ability_first_raise()   // self = player
{
	weapon = self GetCurrentWeapon();
	if ( !isdefined( staff_element( weapon ) ) || !self HasWeapon( weapon ) )
		return;
	self notify( "tod_mage_reload_attempt" );
	self tod_classes::camo_regive( weapon, false );
	self ShouldDoInitialWeaponRaise( weapon, true );
	self thread ability_first_raise_equip( weapon );
}

function ability_first_raise_equip( weapon )   // self = player
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "tod_mage_disarm" );
	self notify( "tod_mage_ability_raise" );
	self endon( "tod_mage_ability_raise" );
	// Let the take/give settle before requesting the new equip. A same-frame
	// switch can be swallowed by the engine (also handled by camo_regive).
	for ( i = 0; i < 30; i++ )
	{
		wait 0.05;
		if ( !self HasWeapon( weapon ) || self laststand::player_is_in_laststand() )
			return;
		if ( i > 0 && self GetCurrentWeapon() == weapon )
			return;
		self SwitchToWeaponImmediate( weapon );
	}
}

function cast_heal()   // self = player
{
	lv = tod_upgrades::get_level( self, "mage_heal" );
	if ( lv < 1 )
		return;   // the first HEALING AURA card unlocks the cast
	if ( lv > TOD_MAGE_HEAL_MAX )
		lv = TOD_MAGE_HEAL_MAX;
	if ( tod_upgrades::has_dark( self, "mage_heal" ) )
		lv = TOD_MAGE_HEAL_DARK_LV;   // dark HEALING AURA: the seventh rung (see the define)
	// CHARGES, NOT A COOLDOWN (v18.37). The lethal slot holds 1..3 uses and they
	// refill on their own; ready() still refuses a second cast while an aura is
	// running so two cannot be stacked on one spot.
	if ( !self ready( "mage_heal" ) )
		return;
	if ( self charges_now() <= 0 )
	{
		return;   // 2026-09-09 release review: silent, like Blink / Archmage refusals; the tile dims
	}
	self.tod_mage_charges = self charges_now() - 1;
	self thread charge_regen();
	self tut_count( "heal" );   // v19.11: the controls overlay counts real casts only

	self ability_first_raise();
	self PlayLocalSound( "tod_mage_heal_activate" );
	self arm_cooldown( "mage_heal", TOD_MAGE_HEAL_TICKS * TOD_MAGE_HEAL_TICK_SECS );
	self thread heal_lock_tell( TOD_MAGE_HEAL_TICKS * TOD_MAGE_HEAL_TICK_SECS );   // v18.76
	foreach ( p in GetPlayers() )
		p.tod_mage_healed_tell = undefined;   // so the NEXT aura pings again
	self thread heal_pulse( lv );
}

// v18.76 — the lethal tile dims for exactly the aura lock and relights when
// it lifts (abil_send clamps to 0 while ready() is false, so both pushes go
// through the same gate and the change-gate sees a real change each way).
function heal_lock_tell( secs )   // self = player
{
	self endon( "disconnect" );
	self endon( "tod_mage_disarm" );
	self abil_send( self charges_now(), self blink_charges_now() );
	wait secs + 0.05;
	self abil_send( self charges_now(), self blink_charges_now() );
}

// One Near Death Experience-style green revive effect per protected player.
// The host owns cleanup so disconnect cannot strand a looping effect.
function heal_visual_touch()   // self = recipient
{
	if ( isdefined( self.tod_mage_heal_host ) ) return;
	host = Spawn( "script_model", self.origin );
	if ( !isdefined( host ) ) return;
	host SetModel( "tag_origin" );
	host LinkTo( self, "j_spineupper", ( 0, 0, 0 ), ( 0, 0, 0 ) );
	self.tod_mage_heal_host = host;
	PlayFxOnTag( level._effect[ "tod_mage_heal" ], host, "tag_origin" );
	host thread heal_visual_lifetime( self );
}

function heal_visual_lifetime( player )   // self = independent FX host
{
	self endon( "entityshutdown" );
	while ( isdefined( player ) && IsAlive( player ) )
	{
		if ( player laststand::player_is_in_laststand() || aura_level( player ) <= 0 ) break;
		wait 0.1;
	}
	if ( isdefined( player ) && player.tod_mage_heal_host == self )
		player.tod_mage_heal_host = undefined;
	self Delete();
}

// HEALING AURA'S LV6 REVIVE, WITH THE GREEN "+" BURST (2026-10-01, docs/167
// item 2; lead tester: "When you are at level 6 and you revive someone with
// healing aura it should put a bunch of green + signs on screen to indicate you
// were healed by the mage ability"). Stock's auto_revive is unchanged and still
// does the whole revive - it can WAIT while a teammate is mid-revive on the same
// body (its beingRevived loop), so the burst goes out after it RETURNS, and only
// if the player is actually standing: a body the bleed-out took first gets
// nothing. The event goes to the REVIVED player alone; the caster already has
// the activation sound and their own tiles.
function heal_revive( caster )   // self = the downed teammate
{
	self endon( "disconnect" );
	self zm_laststand::auto_revive( caster );
	if ( !isdefined( self ) || !IsAlive( self ) || self laststand::player_is_in_laststand() )
		return;
	self LuiNotifyEvent( &"tod_heal_burst", 1, 1 );
	if ( IS_TRUE( level.tod_dev ) )
	{
		cid = -1;
		if ( isdefined( caster ) )
			cid = caster GetEntityNumber();
		line = "[TOD_HEAL] ms=" + GetTime() + " REVIVE_BURST revived=" + self GetEntityNumber() + " caster=" + cid;
		/#
		PrintLn( line );
		#/
	}
}

// THE AURA'S GROUND AREA (2026-10-01, docs/167 item 1; lead tester: "Add a green
// ground visual to the Mage Aura to clearly show its range and active duration";
// second pass after the user's test: "Should be a green pulse or area that looks
// nice for the radius of the effect"). ONE looping effect drawn FLAT on the floor
// at THIS cast's radius - tod/mage/fx_healing_aura_area_<radius>
// (tools/gen_heal_area_fx.py): a green rim exactly on the radius, a soft green
// fill, a pulse sweeping from the caster to the rim each second, and green motes.
// It shows for exactly as long as the aura heals. The v19.68 ring of 12 tiny
// markers sat half inside the floor and read as nothing.
//
// ONE HOST follows the caster by MoveTo each server frame. It FACES UP (pitch
// TOD_MAGE_HEAL_AREA_PITCH): a flat effect lays its sprites across its forward
// axis, which is how stock draws Domination's zone (dom.csc passes the ground's
// up vector as the effect's forward). Not LinkTo'd to the player: a link inherits
// the player's turn. The host's own thread deletes it on expiry, the caster's
// death or disconnect (an endon is not cleanup); the effect stops with its host
// and clears within half a second. The aura measures from the caster's origin on
// every pulse, so the area is drawn exactly where it counts. A spawn failure costs
// the visual, never the aura: heal_pulse never waits on this.
function heal_area_start( radius, secs )   // self = caster
{
	key = "tod_mage_heal_area_" + radius;
	if ( !isdefined( level._effect[ key ] ) )
	{
		heal_area_log( "AREA_FAIL no_fx radius=" + radius );
		return;
	}
	host = Spawn( "script_model", self.origin );
	if ( !isdefined( host ) )
	{
		heal_area_log( "AREA_FAIL no_entity radius=" + radius );
		return;
	}
	host SetModel( "tag_origin" );
	host.angles = ( TOD_MAGE_HEAL_AREA_PITCH, 0, 0 );
	host thread heal_area_run( self, secs, key );
	heal_area_log( "AREA_ON caster=" + self GetEntityNumber() + " radius=" + radius
		+ " secs=" + secs + " fx=" + key );
}

// THE EFFECT STARTS TWO SERVER FRAMES AFTER ITS HOST EXISTS (user, 2026-10-01: "No
// visual still. I dont see anything" - the server logged AREA_ON with the right
// effect on every cast). An effect played on a host created in the SAME frame
// reaches the client before the host does and is dropped: that is why neither
// the v19.68 ring nor the first area ever drew. The map's working lanes all wait -
// _tod_teleport::fx_burst (two WAIT_SERVER_FRAMEs, docs/143) and the luck soul
// (its host is made one tick, its effect attached on the next). Same rule here.
function heal_area_run( caster, secs, key )   // self = the area's host
{
	t0 = GetTime();
	total = int( secs * 1000 );
	why = "expired";
	WAIT_SERVER_FRAME;
	WAIT_SERVER_FRAME;
	if ( isdefined( caster ) )
		self.origin = caster.origin;
	PlayFXOnTag( level._effect[ key ], self, "tag_origin" );
	heal_area_log( "AREA_FX emitted fx=" + key + " after_ms=" + ( GetTime() - t0 ) );
	for ( ;; )
	{
		if ( !isdefined( caster ) || !IsAlive( caster ) )
		{
			why = "caster_gone";
			break;
		}
		if ( GetTime() - t0 >= total )
			break;
		self MoveTo( caster.origin, 0.1 );
		wait 0.05;
	}
	heal_area_log( "AREA_OFF why=" + why + " ms=" + ( GetTime() - t0 ) );
	self Delete();
}

// Dev-only, assembled outside the developer block (the proven pattern).
function heal_area_log( msg )
{
	if ( !IS_TRUE( level.tod_dev ) )
		return;
	line = "[TOD_HEAL] ms=" + GetTime() + " " + msg;
	/#
	PrintLn( line );
	#/
}

// The aura follows the caster; each recipient owns one body effect for the
// duration of their protection, including the caster and overlapping casts.
function heal_pulse( lv )   // self = player
{
	self endon( "disconnect" );

	// The cast latches its level for radius, healing and resistance; changing
	// cards mid-aura affects the next cast.
	radius = heal_radius( lv );
	raised = ( lv < TOD_MAGE_HEAL_REVIVE_LV );
	// 2026-10-01: the green ground area shows this radius for as long as this aura heals.
	self heal_area_start( radius, TOD_MAGE_HEAL_TICKS * TOD_MAGE_HEAL_TICK_SECS );

	for ( i = 0; i < TOD_MAGE_HEAL_TICKS; i++ )
	{
		if ( !isdefined( self ) || !IsAlive( self ) )
			break;

		foreach ( p in GetPlayers() )
		{
			if ( !isdefined( p ) || !IsAlive( p ) )
				continue;
			if ( Distance( p.origin, self.origin ) > radius )
				continue;

			if ( p laststand::player_is_in_laststand() )
			{
				// A downed player cannot be healed into standing up (memory
				// downed-players-take-zero-damage); only a revive helps.
				if ( !raised && p != self )
				{
					raised = true;
					p thread heal_revive( self );   // stock auto_revive + the green "+" burst (2026-10-01)
				}
				continue;
			}

			// Refresh this cast's resistance strength and green health-bar tell.
			p aura_touch( lv );
			p aura_bar( true );
			p heal_visual_touch();

			if ( !isdefined( p.maxhealth ) )
				continue;
			// Whole-HP pulses preserve the exact per-second rate at odd levels.
			p tod_upgrades::trickle_heal( heal_tick_amount( lv, i ) );

			// One receipt ping; the body effect persists across healing pulses.
			if ( !IS_TRUE( p.tod_mage_healed_tell ) )
			{
				p.tod_mage_healed_tell = true;
				// The caster already heard the activation WAV; teammates keep
				// the short receipt ping when they first enter this aura.
				if ( p != self )
					p PlayLocalSound( "tod_mage_heal" );
			}
		}

		wait TOD_MAGE_HEAL_TICK_SECS;
	}

}
