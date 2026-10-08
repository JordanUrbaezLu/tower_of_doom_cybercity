// =============================================================================
// _tod_upgrades.gsc — the upgrade tower system (the map's progression core).
//
// At rounds 1, 4, 8, 12... (dev: every round) the world PAUSES and every
// player gets TWO upgrade options for their class, each rolled with a RARITY:
//   REGULAR = +1 level    SUPER = +2 levels    ULTIMATE = +3 levels
// Rarity odds ride the 0..100% LUCK BAR (_tod_luck.gsc — kills/headshots/
// revives/doors/boss LAST HITS): 80/15/5 at 0% -> 20/50/30 at 100%, and the
// bar fully resets after each event. Choice UI: _tod_upgrade_ui.gsc
// (D-pad/stick moves focus, HOLD JUMP locks; 15s timeout locks the focused card).
//
// THE "NO TWIN MATRIX" ARCHITECTURE (the scalability answer):
// A 10-level × N-domain × M-class matrix of weapon variants would be thousands
// of weapon-table registrations — map 1 measured the engine hard-AVs past
// ~230 twins (docs/21 §A, silent 0xC0000005 at boot). So NO upgrade ever
// creates a weapon asset. One gun asset per class (+_up), and every domain is
// SCRIPT-side per-player state applied through engine levers:
//   DAMAGE   — zm::register_actor_damage_callback: scale the player's damage
//              when the hitting weapon is their class primary (+12%/Lv).
//   FIRERATE — same callback: 10%/Lv chance a bullet double-hits (an "echo"
//              round — DPS-equivalent; true ROF is baked into the weapon
//              asset, the one thing script cannot touch without twins. This
//              is the Double Tap 2 mechanism, stock-blessed).
//   MAGSIZE  — a virtual bottomless-mag pool (+20% of base clip per level):
//              when the clip runs dry mid-fight the pool instantly refeeds it
//              without a reload; a real reload refills the pool. No clip-size
//              field exists to edit at runtime — this is the lever that does.
// Adding a domain = one entry in register_domains + an apply hook here.
// Adding a class = _tod_classes::register_class. Nothing else scales with it.
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;   // v18.12 — TRAILBLAZER's burn tell sets the stock `arch_actor_fire_fx` actor field (see trail_burn_tick; was `zm_nuked` v16.87..v18.11)
#using scripts\shared\flag_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm;
#using scripts\zm\_zm_perks;      // v19.25 — axis_level reads Double Tap for the ice staff's `d` variant letter
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_equipment;   // is_equipment (v19.58 equipment_kill_pay: riot shield kills pay)
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_spawner;
#using scripts\shared\ai\zombie_utility;
// in_revive_trigger (the station: a revive press is not a purchase). NOT a
// cycle — scripts\zm\_zm_utility is stock, resolved from the modtools raw tree,
// and nothing under share/raw imports a zm_tower_of_doom module.
// NAMESPACE CARE: zombie_utility (imported directly above) ships an
// identically-shaped is_player_valid, so EVERY call into this module must be
// written zm_utility:: and never bare.
#using scripts\zm\_zm_utility;

#using scripts\zm\zm_tower_of_doom\_tod_classes;
// max_ammo_clip_watch — no cycle: _tod_powerups imports _tod_upgrade_ui, never
// this module (the KB cycle rule).
#using scripts\zm\zm_tower_of_doom\_tod_powerups;
#using scripts\zm\zm_tower_of_doom\_tod_upgrade_ui;
// crown terminal anchor (GENERATED leaf module — no #usings of its own, no cycle)
#using scripts\zm\zm_tower_of_doom\_tod_breather_data;   // GENERATED — lounge station anchors (v13)
#using scripts\zm\zm_tower_of_doom\_tod_crown_data;
#using scripts\zm\zm_tower_of_doom\_tod_zombie_speed; // SUPPRESSING FIRE's slow (it imports no tod module — no cycle)
// CLASS TIER floor gate — the per-player floor high-water (it imports only
// flag_shared + util_shared, no tod module, so no cycle).
#using scripts\zm\zm_tower_of_doom\_tod_gauge;

#insert scripts\shared\shared.gsh;
#insert scripts\zm\zm_tower_of_doom\_tod_toast.gsh;

// Upgrade cadence (user 2026-08-20): round 1 ALWAYS (dealt by the class
// draft the moment everyone locks — _tod_class_select calls
// run_upgrade_event directly), then DEV = every round / SHIP = every 4th
// round. Full ship sequence: 1, 4, 8, 12, ...
// ---------------------------------------------------------------------------
// UPGRADE TIERS (user 2026-08-21: "add a rarity on each upgrade ... which
// upgrades can make you OP — we want those to be S").
//
// A tier does TWO things, so an S upgrade is rare AND rarely stacked:
//   1. DRAW WEIGHT — how often the domain is even OFFERED as a card. B shows
//      up 3x as often as S (was 5x until 2026-09-08).
//   2. RARITY GATE — S/A cards shrink their SUPER+ULTIMATE slice toward
//      REGULAR, so "S domain at ULTIMATE (+3 levels)" is the rarest event in
//      the game even on a full luck bar.
//
// THE GAP NARROWED 2026-09-08 (user: "decrease the gap in general between S, A,
// B. Maybe something like 6%, 12%, 18%"). THOSE NUMBERS ARE A RATIO, NOT A
// SHARE, and the distinction matters if you retune this again: the weights are
// relative, so 6/12/18 is exactly 1:2:3, and the share a card actually gets
// depends on how many cards sit in its pool. With ~13 cards a pool lands near
// 4% / 8% / 12% per card, not 6 / 12 / 18. Ratios moved B:S 5.00 -> 3.00 and
// A:S 2.50 -> 2.00, so an S card is offered about 44% more often than before
// and a B card about 13% less.
//
// ⚠️ THIS IS THE DRAW HALF ONLY. The RARITY GATE below (TOD_TIER_R_*) is the
// band's other half and was NOT touched — an S card still halves its
// SUPER/ULTIMATE slice. If S still feels too rare after playing this, that is
// the second lever and it changes a different thing: how GOOD the S cards you
// do see are, rather than how often they appear.
// ---------------------------------------------------------------------------
#define TOD_TIER_B   1     // utility / incremental — common
#define TOD_TIER_A   2     // strong
#define TOD_TIER_S   3     // game-defining
#define TOD_TIER_W_B 18    // draw weight (RELATIVE — only the ratio matters). 100/50/20 until 2026-09-08
#define TOD_TIER_W_A 12
#define TOD_TIER_W_S 6
// THE RARITY GATE — the band's SECOND job, softened 2026-09-08 (user, after
// reading what luck actually buys: "Apply a small change"). S 0.50 -> 0.65 and
// A 0.75 -> 0.85. DELIBERATELY SMALL: the shape is unchanged, S is still the
// hardest card to roll well, and this is one define pair to walk back.
//
// WHY THIS ONE AND NOT THE DICE. A band does two jobs and BOTH taxed S: it is
// offered less often AND its good rolls were halved. The draw half was narrowed
// to 1:2:3 earlier the same day, so this is the matching half — it leaves the
// luck curve everyone already has a feel for completely alone and only stops S
// being penalised twice for the same reason.
#define TOD_TIER_R_A 0.85  // SUPER/ULTIMATE slice multiplier (0.75 until 2026-09-08)
#define TOD_TIER_R_S 0.65  //                                 (0.50 until 2026-09-08)

// ---------------------------------------------------------------------------
// LUCK GUARANTEES (user 2026-08-26: "max luck needs to guarentee at least one
// ultimate upgrade. And 50% guarentees one super").
//
// A FLOOR ON THE DEAL, NOT A REPLACEMENT FOR THE ROLL. Both cards still roll
// independently through roll_rarity exactly as before; guarantee_rarity() then
// looks at what came out and, if the bar earned better than the dice gave,
// promotes ONE card up to the floor. A deal that already beat the floor is left
// completely alone — this can only ever raise a card, never lower one.
//
// v14.6 — AND THE FLOOR CAN REDEAL (user 2026-08-30, after a max-luck game
// with no ULTIMATE): when neither dealt card has the HEADROOM to absorb the
// owed rarity (low-cap domains — PENETRATION/RECOIL max 2, SPRINT FIRE max 1
// — or anything near its cap), guarantee_rarity swaps the weakest dealt card
// for a pool domain that CAN absorb it, then promotes that. The full ladder
// of outcomes at a full bar: dice ultimate > promoted ultimate > redealt
// ultimate > (only when NO domain anywhere has +3 of headroom) the old
// clamped-and-honest label. Details at guarantee_rarity.
//
// THE THRESHOLDS MATCH THE HUD EXACTLY, and that is deliberate. The luck bar is
// drawn as 10 segments via set_luck_pct's int(pct/10), so the 10th segment lights
// at >= 100 and the 5th at >= 50 — the same two numbers below. A player who can
// see a full bar gets the ULTIMATE, and one who can see five segments gets the
// SUPER. Do not "helpfully" loosen these to 99.5 or 49.5: that would fire the
// guarantee on a bar the player can still see is short, which is a worse lie
// than the one it would be trying to fix.
//
// 100 IS REACHABLE — set_bar clamps anything over TOD_LUCK_MAX to exactly 100,
// so a full bar is exactly 100.0 and not 99.9997.
#define TOD_UPG_GUAR_ULT_BAR   100  // bar >= this: one card is ULTIMATE (+3)
#define TOD_UPG_GUAR_SUP_BAR    50  // bar >= this: one card is SUPER+ (+2)
// v14.9 THE OVERCHARGE PAYOUT (user 2026-08-30: at 150% "both options are
// guaranteed to be ultimates rarity"). The luck bar secretly tracks 100..150
// now (_tod_luck TOD_LUCK_OVERMAX — LOCKSTEP PAIR, the two defines must move
// together); at the ceiling the deal guarantees EVERY non-tier card ULTIMATE,
// not just one. The band between the two thresholds is deliberately invisible
// (same full-bar HUD) but still real: roll_rarity keeps riding the raw value,
// so 100..149 quietly improves both dice before the 150 floor takes over.
// The 105..111 "thresholds match the HUD" doctrine above still holds for THESE
// two numbers; 150 is the exception BY DESIGN — its tell is not a segment, it
// is the overcharge zap animation + sound, which fire at exactly this value.
#define TOD_UPG_GUAR_BOTH_BAR  150  // bar >= this: EVERY non-tier card is ULTIMATE
// v16.56 THE FULL-BAR PROMOTION (user 2026-09-02: "When you have max luck and
// your gun is pap and you are eligible for a class upgrade you should be
// guaranteed one. That means you must fulfill the floor condition as well").
// At or above this bar a deal to a FULLY tier-eligible player (PaP'd, floor
// gate cleared, next gun linked — tier_card_eligible, never the but-for-floor
// half) carries the TIER card 100% of the time instead of TOD_TIER_CARD_PCT.
// "Max luck" is the FULL VISIBLE BAR — the same 100 the ULTIMATE floor keys
// on, per the doctrine above (the 150 overcharge is a secret band; a guarantee
// the player cannot see they have earned is not a guarantee). A floor-blocked
// player keeps the ordinary 20% draw-and-show-locked path; the bar buys the
// promotion only once the climb is done. One owner: tier_card_guaranteed().
#define TOD_UPG_GUAR_TIER_BAR  100  // bar >= this + fully tier-eligible: the TIER card is dealt

// THE OPENING HAND (user 2026-08-26: "the first upgrade in the game for the
// player that comes after picking a class should always have at least one super
// card"). That is the round-1 deal the class draft hands out the moment everyone
// locks (_tod_class_select.gsc:106 calls run_upgrade_event directly).
//
// WHY IT NEEDS ITS OWN FLOOR: the luck bar is the ONLY thing that lifts rarity,
// and at that moment it is exactly 0 — nobody has killed anything yet. So the
// opening deal rolls the base 80/15/5 and comes up REGULAR+REGULAR about 64% of
// the time. The one hand that sets the tone for the whole run was the worst hand
// in the game.
//
// PER PLAYER, ONCE PER RUN, latched on player.tod_first_deal_done. Per-player
// rather than a level flag so a co-op late joiner still gets an opening hand,
// and so one player's deal cannot consume another's.
#define TOD_UPG_GUAR_FIRST      2   // first deal of the run: at least SUPER (+2)

#define TOD_UPG_EVERY_N_SHIP    4
#define TOD_UPG_CHOICE_TIMEOUT  15  // 15s window, then the focused card auto-locks
// v17.70 THE WARDEN KING'S DARK DEALS (user 2026-09-05): "prompt all the users
// the rest of their dark upgrade with a 10s timer and continue prompting
// everyone until everyone has all their cards" — the timer for those deals.
// Read through choice_timeout(): level.tod_upg_timeout_override is set only
// by king_dark_deals and cleared by it.
#define TOD_KING_DARK_SECS      10
// DAMAGE: +10% per level (v15, user 2026-08-31: "Can we lower damage upgrade to
// 10% instead of 12%"). At the 10-level cap that is +100%, down from +120%, so
// the peak additive multiplier falls 2.20x -> 2.00x = -9.1% on everything.
// THE HAND-COPIED LITERAL IN _tod_bosses::rp_damage_feed IS GONE (2026-09-08):
// that lane re-enters upgrade_damage_cb wholesale, so this rate has exactly ONE
// reader. Do NOT re-create a copy — a GSC
// #define is file-local and that lane cannot see this symbol. Its HEADSHOT twin
// was already stale once and overpaid 2.5x on the Rogue Protector for a day.
// Grep TOD_UPG_DMG_PER_LVL, never a line number.
// THE CARD ART IS ALREADY RE-BAKED AT THIS RATE (verified by opening the PNGs):
// they bake "+10% / +20% / +30% DAMAGE" by rarity and the dark card is numberless.
// Nothing carries 12/24/36. These three DO still bake a figure, so a rate change
// here owes three re-bakes — and per the generic-card-text rule they should come
// back NUMBERLESS, as HEADSHOT's already have.
#define TOD_UPG_DMG_PER_LVL     0.10   // +10% damage per level (was 0.12 until 2026-08-31)
#define TOD_UPG_ECHO_PCT_PER_LVL 10    // +10%/level chance to double-hit
#define TOD_UPG_MAG_PCT_PER_LVL 0.20   // +20% of base clip per level
#define TOD_UPG_BOUNTY_PER_LVL  0.05   // +5%/Lv (user 2026-08-20, was 3%)
// HEADSHOT: +12% per level over FIVE levels (user 2026-09-08: "change headshot
// upgrade to 12% per tier and only 5 tiers"). History of the RATE:
// 0.10 -> 0.04 (2026-08-22 nerf) -> 0.03 (v9.45, 2026-08-23) -> 0.04
// (2026-08-26 assault buff) -> 0.05 (2026-08-30) -> 0.12 here. History of the
// CAP: 10 -> 5 in this same pass, and the max lives on the add_domain call, not
// here — change both or the card offers levels the ladder no longer prices.
//
// THE CAP AND THE RATE MOVED TOGETHER AND THAT IS THE WHOLE POINT: +50% at ten
// levels becomes +60% at five. The ceiling barely moves (+10pp); what changes
// is the SHAPE — a card is worth 2.4x what it was, and the domain finishes in
// five picks instead of ten. This is a pacing change wearing a buff's clothes.
//
// WHAT IT IS ACTUALLY WORTH — quote this, never the headline. Every damage
// domain adds into ONE unclamped sum and DAMAGE alone contributes +1.00 at cap,
// so a maxed assault headshotting a boss moves 3.10x -> 3.20x = +3.2% real
// damage, and a headshot on the horde moves 2.50x -> 2.60x = +4.0%. "5% -> 12%"
// reads like +140% and is not. Same trap as the 2026-08-26 and 08-30 passes.
//
// THE HAND-COPIED LITERAL IN _tod_bosses::rp_damage_feed IS GONE (2026-09-08).
// It was the one this comment used to warn about — a GSC #define is file-local,
// that lane could not see this symbol, and it went stale once (0.10 there while
// this said 0.04) and paid 2.5x on the Rogue Protector for a day. It now calls
// headshot_bonus(), which owns the rate AND the dark add, exactly as
// boss_damage_bonus already did for GIANT SLAYER. Do not re-introduce a copy.
//
// STILL HAND-MAINTAINED, so change these in the same commit:
//   * tod_upgrade.lua DOMAIN[6].desc AND .max, DETAIL[6].val, dark DETAIL[6].val
//   * the CARD ART IS ALREADY NUMBERLESS AND OWES NOTHING (verified by opening
//     all four PNGs: every rarity bakes "HEADSHOTS HIT HARDER", no percentage), so
//     per the generic-card-text rule it should come back NUMBERLESS so the next
//     retune owes nothing. The pause plate (i_tod_pause_r06) is name-only and
//     needs no re-bake.
//   * docs/armory.html (the DOMAINS row, the Ceilings term, the Verdict row)
#define TOD_UPG_HS_PER_LVL      0.12
// MOVE SPEED IS A DIMINISHING LADDER, NOT A FLAT PER-LEVEL RATE (v15,
// 2026-08-31 — user: "We also need to nerf the speed boost upgrade in general.
// It should be 5%, 4%, 3%, then 3% each level after").
//
// Per-level INCREMENTS: 5, 4, 3, 3, 3, 3, ...  ->  cumulative totals
//   Lv1 +5%  Lv2 +9%  Lv3 +12%  Lv4 +15%  Lv5 +18%
//   Lv6 +21% Lv7 +24% Lv8 +27%  Lv9 +30%  Lv10 +33%
// (was a flat 5%/Lv, i.e. +50% at Lv10 — so the ceiling falls by a third.)
//
// ⚠️ THE CARD ART CONSEQUENCE, and it is the whole reason this is not a
// one-line change: the value is no longer LINEAR, so a card can no longer print
// "+5% / +10% / +15%" and be true at every rarity. Per the domain-retune
// checklist a stage-table domain must either print the whole ladder or say
// nothing — and the user chose nothing: "the assets probably need to be
// upgraded so they are generic. And the pause menu can show the exact upgrade
// number." So SPRINT and FORCED MARCH cards get GENERIC copy (no number) and
// the exact figure is served per-player by the pause menu (item 26).
//
// TOD_UPG_SPEED_PER_LVL IS GONE ON PURPOSE. Leaving it would have let a future
// reader multiply by it and silently get the old flat curve back; every caller
// must go through speed_pct_for_level().
#define TOD_UPG_SPEED_L1        0.05   // the first level's increment
#define TOD_UPG_SPEED_L2        0.04   // the second's
#define TOD_UPG_SPEED_LN        0.03   // every level from the third on
// SPRINT ARMOR (v9.28, user 2026-08-23: "take less damage when you are
// running, 5% each level, 5 levels max, only for melee and skirmisher"):
// incoming damage x (1 - this*Lv) WHILE the engine says the player is
// sprinting (IsSprinting, server builtin). Applied in _tod_bosses' two
// player-damage lanes right after DMG REDUCTION — the two stack
// multiplicatively (Lv5 of both while sprinting = x0.75 x 0.75).
#define TOD_UPG_SPRINT_ARMOR_PER_LVL 0.05
// DMG REDUCTION — THE DIMINISHING LADDER (v16, 2026-09-01, user: "damage
// reduction should go +6%, +5%, 4%, 3%, 2%"). PER-LEVEL INCREMENTS, so the
// CUMULATIVE reduction is 6 / 11 / 15 / 18 / 20% at Lv1..Lv5.
//
// This is a NERF AT THE CAP and a BUFF AT THE BOTTOM: the old flat 5%/Lv paid
// 5/10/15/20/25, so the first card is now worth +1pp more and the fifth is
// worth 5pp less. Paired in the same commit with the band move S -> A below,
// which makes the domain ~2.5x more likely to be dealt. Read together, DR stops
// being a rare game-definer you hoard and becomes a common early pick whose
// last two levels are deliberately not worth chasing.
//
// ⚠️ THIS KILLED THE HAND-COPIED-LITERAL PROBLEM, ON PURPOSE. Until v16 the two
// application lanes in _tod_bosses.gsc carried bare 0.05 literals, because a GSC
// #define is FILE-LOCAL and cannot reach across files — and this file used to
// carry a comment instructing the next person to edit both copies by hand. A
// diminishing ladder cannot be expressed as a literal multiply at all, so that
// arrangement was not merely fragile, it had stopped being possible. Both lanes
// now CALL dr_mult() instead, which is the same shape sprint_armor_mult and
// back_armor_mult have always had, and is what boss_damage_bonus already does.
// DO NOT reintroduce a per-level constant here for anyone to copy.
#define TOD_UPG_DR_L1           6
#define TOD_UPG_DR_L2           5
#define TOD_UPG_DR_L3           4
#define TOD_UPG_DR_L4           3
#define TOD_UPG_DR_LN           2    // every level past 5, if the cap ever rises
// GIANT SLAYER (v9.45, user 2026-08-23: "an upgrade where they do more damage
// to boss and elites. 3% per level, can go to level 5"; BUFFED to 4%/Lv
// 2026-08-26; BUFFED to 5%/Lv 2026-08-30; BUFFED to 8%/Lv 2026-08-31, user: "buff the headshot and boss
// damage upgrades for the assault class from 4% to 5% each level"). ASSAULT.
// +5%/Lv, added into the SAME additive mult sum as DAMAGE and HEADSHOT rather
// than multiplying on top of it — so Lv5 is +25% of BASE damage, not +25% of
// the already-multiplied total.
//
// WHAT COUNTS AS A BOSS OR ELITE: the map-wide triad is_boss / acc_is_boss /
// acc_is_mini_boss, which the Panzer, the Rogue Protector, the Reaver AND the
// hellhound all set synchronously on their spawn frame. ⚠️ The ARMORED SPRINTER
// does NOT — it carries tod_is_sprinter instead, so it is invisible to this lane. Eight other systems already gate on
// exactly those three fields (the zombie speed curve, IMPACT ROUNDS,
// SUPPRESSING FIRE, THOR'S THUNDER, the powerup drop roll, the floor gauge,
// CHAIN LUNGE, Electric Cherry), so a future elite that sets the triad is
// covered by this card for free, and one that does not is invisible to all
// nine at once. Read it through is_boss_or_elite() — never re-spell the triad.
#define TOD_UPG_BOSSDMG_PER_LVL 0.12   // 15% -> 12% v16.50 (user 2026-09-02: "nerf giant slayer to 12% each tier") = +60% at the Lv5 cap
// MELEE vs THE BOSS/ELITE TRIAD (user 2026-08-24: "we need to nerf melee. They
// will do 50% damage against bosses and elites"). WHY IT WAS NEEDED: melee
// damage is a FLAT per-weapon number (_tod_classes::register_melee_dmg —
// knife 2000/4000, wakizashi 4000/8000, Stormbreaker 6800/13600) that does not
// scale with the target, while boss HP compounds per round. A PaP'd
// Stormbreaker under DAMAGE Lv10 + DRAW CUT Lv3 + GIANT SLAYER swings for
// ~52k, which deletes a round-30 Panzer (129k) in three hits.
// Applied MULTIPLICATIVELY to the FINAL, so it scales the base hit, every
// damage domain and the insta-kill window alike, and it is read through
// melee_boss_mult() — never re-spelled — for the same reason the triad test is
// (see is_boss_or_elite above).
// 0.5 -> 0.33 (user 2026-08-30, alongside the -20% melee damage pass): melee
// now deals ONE THIRD against the triad. Compounded with that pass a blade
// swing lands at 0.264x its pre-2026-08-30 value against a Panzer / Rogue
// Protector / Reaver, and is unchanged in that ratio against ordinary zombies
// (which pay only the -20%).
// TWO RATES SINCE v18.3, split by the ATTACKER'S CLASS (user 2026-09-06,
// clarifying the +75% they had just asked for: "when i said melee i
// specifically meant slasher").
//
// v18.2 raised the SHARED constant to 0.5775 and so handed the buff to every
// class's bare knife as well - an assault player knifing a Panzer got the
// slasher's compensation. The knob is now two:
//
//   TOD_MELEE_BOSS_MULT           0.33    every other class's melee. Exactly
//                                         where it has sat since 2026-08-30 -
//                                         v18.3 restores it, it is not a nerf.
//   TOD_MELEE_BOSS_MULT_SLASHER   0.5775  the SLASHER only: 0.33 x 1.75, the
//                                         +75% as asked.
//
// Both are picked by melee_boss_mult(), which now takes the ATTACKER as its
// first argument. Never re-spell either value or the class test - the same
// rule the triad test has always carried, and this file has already shipped a
// stale hand-copied melee constant once.
#define TOD_MELEE_BOSS_MULT     0.33
#define TOD_MELEE_BOSS_MULT_SLASHER 0.5775
// THE SLASHER'S SIDEARM vs THE BOSS/ELITE TRIAD (v16, 2026-09-01 — user: "the
// secondaries of slasher should be 2.25x damage on elites and bosses").
//
// WHY THE SLASHER SPECIFICALLY NEEDED THIS. Its blade already pays
// TOD_MELEE_BOSS_MULT 0.33 against the triad, and of the eleven domains a T3
// slasher can roll exactly ONE raises boss damage: THOR'S THUNDER skips the
// triad outright, CLEAVE is splash onto other zombies, LEECH is kill-gated, and
// GIANT SLAYER and HEADSHOT are assault-only. So the class's answer to a Panzer
// was "swing fifteen times inside the flames". This turns the sidearm — the one
// tool it carries that is NOT scaled down against bosses — into the real answer,
// which is a play pattern (swap off the blade for the boss) rather than a
// number.
//
// MULTIPLICATIVE ON THE FINAL, not a term in the additive sum. Same placement
// and same reasoning as melee_boss_mult: it scales the base hit, DAMAGE and
// every other domain together instead of fighting them one at a time, and the
// crosshair number is pushed after it so what the player reads is what the boss
// took. "2.25x" in the ask is a multiplier, not a percentage to add.
#define TOD_SLASHER_SEC_BOSS_MULT  2.25
// GUNSLINGER (domain 44, v16.51 — user 2026-09-02: "Slashers need an ability
// that make their secondary do more boss and elite damage. 30% each tier up to
// 5 tiers. This will be B tier"). The DOMAIN half of the same lane: the
// slasher's class secondary vs the triad pays +30%/Lv.
//
// ADDITIVE SINCE v16.99 (user, after the balance review: "Yes make gunslinger
// additive"). gunslinger_bonus() returns lvl x TOD_UPG_GUNSLINGER_PER_LVL as a
// TERM IN THE SHARED mult SUM, next to DAMAGE and every other additive domain;
// slasher_sidearm_boss_mult() keeps ONLY the class baseline
// TOD_SLASHER_SEC_BOSS_MULT. Two callers, and both must add the term or the
// domain silently does nothing on that path: upgrade_damage_cb here, and
// _tod_bosses::rp_damage_feed (the aiOverrideDamage fallback).
//
// THE OLD COMMENT'S ARITHMETIC WAS RIGHT AND THAT WAS THE PROBLEM. It argued
// for multiplying because an additive term is "worth a third of that against a
// 2.25x hit" — true, and precisely the effect being removed. Compounding on the
// baseline made Lv5 a 5.625x hit, so one domain outran the whole additive pool
// and the slasher's boss damage stopped being readable against any other
// class's. Additive costs the domain its ceiling on purpose. Do NOT restore the
// multiply because the number "looks small": it is small, measured against a
// baseline that is already the largest single multiplier a class gets.
//
// The three gates (slasher, class secondary, boss/elite) live in
// slasher_sidearm_vs_boss() and are shared by both halves, so the baseline and
// the domain can never disagree about what counts as a qualifying hit.
#define TOD_UPG_GUNSLINGER_PER_LVL 0.30
// Radius around the Panzer's j_faceplate tag that counts as a head hit. Stock's
// own visor probe uses 12 (mechz.gsc `dist_sq <= 144`); 36 is deliberately
// wider because impact points land on the helmet SURFACE, not the tag. Owned
// here so headshot_kind() and _tod_bosses agree by construction.
#define TOD_FACEPLATE_RADIUS    36
// BACK ARMOR (v9.45, user 2026-08-23: "for AR and LMG we need a new upgrade
// where getting hit from behind does 10% less damage and can go 3 levels").
// ASSAULT + HEAVY, -10%/Lv, so Lv3 = -30% from behind.
//
// "BEHIND" = the attacker sits in a rear ARC around the player's VIEW forward,
// flattened to 2D (a zombie on the flight below you is not behind you, it is
// under you). The DOT is the cosine measured from the player's FORWARD vector:
// -0.34 opens a 140-degree rear arc, i.e. 70 degrees either side of due back.
// Wider than a literal "behind" cone on purpose — the horde surrounds you on a
// landing and a 90-degree cone would almost never pay out. Still strictly
// narrower than a hemisphere, so a hit square on the shoulder is not "behind".
//
// Applied MULTIPLICATIVELY after DMG REDUCTION in both of _tod_bosses'
// player-damage lanes, exactly like SPRINT ARMOR — see back_armor_mult().
#define TOD_UPG_BACK_ARMOR_PER_LVL 0.10
#define TOD_BACK_ARC_DOT           -0.34
// ---------------------------------------------------------------------------
// TIRELESS — REMOVED 2026-08-26. (user: "for sprint we are saying skirmisher
// gets unlimited. That does work and we tried to implement multiple times.
// Lets just remove that benefit so skirmisher doesnt get that extra benefit".)
//
// SPRINT is now +5% move speed per level and NOTHING ELSE, for both classes
// that can roll it. There is no Lv5 rider, no class gate on the domain, and no
// script anywhere sets `specialty_staminup` — Stamin-Up the perk machine is the
// only thing in the map that grants it again.
//
// WHAT WAS TRIED, so nobody spends a fourth session on it:
//   1. grant `specialty_staminup` only .......... no meter change at all
//   2. + server-side SetSprintDuration(60) ...... no meter change at all
//   3. + SetClientPlayerSprintTime(999) ......... the documented per-client
//      lever (docs_modtools/bo3_scriptapifunctions.htm: "Sets player_sprintTime
//      dvar only on this client"), set on grant AND re-sent on every spawn by a
//      dedicated watcher — and the user still reported the meter draining.
// The diagnosis in (3) is almost certainly right: the meter is PREDICTED ON THE
// CLIENT from that client's own `player_sprintTime` dvar, which stock writes
// once at connect (zm/gametypes/_globallogic_player.gsc:125), so the server-side
// duration can never reach it. What was never established is whether the setter
// actually sticks for a usermap client. If this is ever revived, THAT is the
// experiment to run first — print the client's live `player_sprintTime` after
// the call and confirm it reads 999 — not another round of re-asserting it from
// a new callback. Three passes have now re-sent the same value more often
// without once checking whether it landed.
//
// The card art carried "LV 5 TIRELESS · SKIRMISHER" on all three rarities and
// was re-baked without it in the same pass.
// ---------------------------------------------------------------------------
// SCAVENGER — v16.40 (user 2026-09-02: "Scavenger needs a nerf at higher
// levels so it needs to diminish enhancements every tier like most upgrades.
// The high tier is way too good."). THE SHAPE FLIPPED. The kill-counter
// ladder recorded below paid 0.20 / 0.25 / 0.33 / 0.50 / 1.00 / 1.50 rounds
// per kill — each level added MORE than the last, and Lv5-6 were infinite
// ammo whenever a kill cost a bullet or two. Now every primary kill BANKS a
// fraction of a round and a whole round pays out of the bank. THE LADDER IS
// AUTHORED IN KILLS PER ROUND (v16.42, the user's own numbers: "Lets do 4, 3,
// 2.4, 2, 1.8" ... "and 1.6"), stored as TENTHS so the bank stays integer
// (1 per 3 kills is not a whole percent — v16.40/41 kept a percent bank and
// could not express it):
//   Lv1 2.8  Lv2 2.3  Lv3 2.0  Lv4 1.8  Lv5 1.6  Lv6 1.4 (assault only)
//   kills per round; steps 0.5 / 0.3 / 0.2 / 0.2 / 0.2 — diminishing.
//   = 0.36 / 0.43 / 0.50 / 0.56 / 0.63 / 0.71 rounds per kill.
// v18.86 (2026-09-13) THE FRONT OF THE LADDER SHIFTED UP, THE TOP DID NOT
// (user: "early on it's almost not noticeable ... but we also don't want it
// to be super, super OP when it's maxed out ... shift over the earlier
// tiers"). Lv1 4.0 -> 3.0, Lv2 3.0 -> 2.5, Lv3 2.4 -> 2.2; Lv4/5/6 were
// UNTOUCHED in that pass.
// v18.88 (2026-09-13, same session, user: "Lets shift all by another 0.2")
// THEN SHIFTED THE WHOLE LADDER, TOP INCLUDED: every rung loses 0.2 kills,
// so Lv1 3.0 -> 2.8 and the assault capstone 1.6 -> 1.4 — the first time
// the ceiling has moved since v16.42. A UNIFORM shift, which is why the step
// table above is IDENTICAL to v18.86's: subtracting a constant cannot change
// the gaps. That is why the shape survived a retune nobody re-derived — the
// diminishing-step rule (0.5 / 0.3 / 0.2 / 0.2 / 0.2, never growing) is a
// property of the DIFFERENCES, not the values. Do not "fix" the three equal
// 0.2 steps at the top by re-accelerating them; that shape IS the v16.40
// nerf and it is deliberate. And WATCH THE FLOOR on any further shift: Lv6
// is 1.4 kills now, and no rung may reach 1.0 without becoming a round per
// kill, which is the exact thing v16.40 was written to kill. Past that point
// a shift has to become a re-shape.
// HISTORY OF THE DAY: v16.40 flipped the accelerating kill counter into a
// diminishing percent bank (20/30/38/44/48/52 per 100 kills = 5.0/3.3/2.6/
// 2.3/2.1/1.9 kills); v16.41 raised the anchor to 1 per 4 (25/35/43/49/53/57
// = 4.0/2.9/2.3/2.0/1.9/1.8; user: "The top end is pretty bad too"); v16.42
// is the user's ladder verbatim. Against the pre-v16.40 ladder: Lv1 +0.05,
// Lv2 +0.08, Lv3 +0.08, Lv4 level, Lv5 1.00 -> 0.56, capstone 1.50 -> 0.63.
// The two rules that always held it still do: ONE round per shot (the
// same-frame latch in on_class_gun_kill; a multi-kill banks, it never stacks
// payouts — the bank re-arms one kill short after a payout, the old "held at
// need-1" rule in fractional form) and maxAmmo. It is a refund, never a
// multiplier. The card art carries no numbers (docs/33, user: "our asset is
// generic enough"), so this owes only the pause-menu row (tod_upgrade.lua [8])
// and the armory row. scav_kills10() is the one reader.
#define TOD_SCAV_KILLS10_L1    28     // kills per refunded round x10 at Lv1 (= 1 per 2.8 kills) ...
#define TOD_SCAV_KILLS10_L2    23     // 1 per 2.3
#define TOD_SCAV_KILLS10_L3    20     // 1 per 2.0
#define TOD_SCAV_KILLS10_L4    18     // 1 per 1.8
#define TOD_SCAV_KILLS10_L5    16     // 1 per 1.6
#define TOD_SCAV_KILLS10_L6    14     // 1 per 1.4 — the assault's capstone rung (bonus_max 6)
//
// ⚠️ EVERYTHING FROM HERE TO TOD_SCAV_CAP_ROUNDS IS HISTORY (v9.10 → v16.39),
// kept as the tuning record in the file's "echo" pattern. Nothing reads the
// five DEAD defines; the live ladder is the six TOD_SCAV_KILLS10_* above.
//
// SCAVENGER (v9.10, user 2026-08-22: "max 1 bullet back on one shot ... 1
// bullet every N kills, N shrinking per level, 2 kills is the most it'll
// go"): a KILL COUNTER paid ONE round at a time. Kills per round =
// LV1 - (lvl-1), floored at MIN:
//   Lv1 6 / Lv2 5 / Lv3 4 / Lv4 3 / Lv5 2 / Lv6 (assault only) 1.
// History: 2 rounds/kill/Lv -> 1 (2026-08-20 "unlimited ammo") -> 0.25 banked
// fractionally (2026-08-21 "too strong") -> the 7..2 ladder -> 2026-08-26 BUFF
// (user: "we need a buff on scavenger. Move it down by 1 kill on each level"),
// shipped alongside the +1 magazine on every gun — the same ammo-scarcity
// complaint answered from both ends.
//
// BOTH CONSTANTS HAD TO MOVE, and that is the whole subtlety of this retune.
// `need` is LV1 - (lvl-1) CLAMPED UP to MIN, and the old MIN of 2 was not a
// safety rail — it was the exact Lv6 value (7-5 = 2). Dropping LV1 alone would
// have bought Lv1-Lv4 a kill each and then let the clamp eat the buff at
// exactly the two levels players grind for: Lv5 and the assault Lv6 would both
// have stayed at 2. MIN moves in lockstep so every level really does come down
// by one, which is what was asked for.
//
// Lv6 = 1 kill per round is the strongest this has ever been, and it is still
// bounded by the two rules that have always held it: ONE round per shot (the
// same-frame latch in on_class_gun_kill, so a penetrating multi-kill still pays
// exactly one) and maxAmmo (a refund cannot exceed the reserve cap). It is a
// refund, never a multiplier.
#define TOD_SCAV_KILLS_LV1      5      // DEAD (v16.40) — was kills per refunded round at Lv1
#define TOD_SCAV_KILLS_MIN      1      // DEAD (v16.40) — was the floor (Lv5: 1 kill, 1 round)
// THE CAPSTONE (user 2026-08-26, second buff of the night: "buff again by one
// kill. The final stage should be 3 bullet every 2 kills"). Shrinking `need`
// one more step per level runs out of room — Lv5 reaches 1 kill and Lv6 would
// need 0, which is not a thing. So the LAST rung stops shrinking the kill count
// and starts GROWING the payout instead: 2 kills -> 3 rounds, a rate of 1.5
// rounds/kill against Lv5's 1.0.
//
// IT IS ASSAULT-ONLY, because level 6 is. add_domain gives SCAVENGER max 5 with
// bonus_class "assault" at 6, so the 6th rung has always been the assault's
// alone — the capstone lands on the class whose signature this domain already
// is. Every other class tops out at Lv5 = one round per kill. If the capstone is
// ever wanted for everyone, the change is `TOD_SCAV_CAP_LVL 5` plus a new value
// for the assault's 6th; do NOT just lower the cap level and leave Lv6 equal to
// Lv5, or the assault's bonus rung silently becomes worthless.
#define TOD_SCAV_CAP_LVL        6      // DEAD (v16.40) — was the capstone rung (assault's bonus level)
#define TOD_SCAV_CAP_KILLS      2      // DEAD (v16.40) — was capstone: 2 kills...
#define TOD_SCAV_CAP_ROUNDS     3      // DEAD (v16.40) — ...paid 3 rounds
// (TOD_UPG_HP_PER_LVL removed 2026-08-20 — HEALTH became DMG REDUCTION,
// -4%/Lv, applied in _tod_bosses' player-damage chain.)
// REGEN REMOVED 2026-08-30, v14.11 (user: "Remove regen upgrade from Heavy
// class"). The define stays as the tuning record, the "echo" pattern; the
// body-loop hook and the add_domain call are gone. The heavy's sustain is now
// VITALITY (+max HP) and RECOVERY (regen starts sooner) below.
#define TOD_UPG_REGEN_PER_LVL   0.005  // DEAD — was +0.5% max HP/s per level (HEAVY)
// VITALITY (HEAVY, v14.11 — user 2026-08-30: "extra health. 5 levels and
// player keeps it for whole game. S tier. increase health by 10 for each
// [level]"). +10 max HP per level, 5 levels => +50 at cap on the 150 base.
// Scope "class" (set_scope below): survives every tier promotion, per the ask.
//
// ⚠️ THE "JUGG-SAFE BECAUSE JUGG IS ADDITIVE" CLAIM THAT USED TO LIVE HERE WAS
// WRONG, and shipped a live bug (v14.28, user: "Vitality upgrade breaks when
// you get jugg. I have 210 but level 3 vitality... went back down to 200").
// Jugg's PURCHASE is additive — but stock ALSO rebuilds max FROM SCRATCH via
// perk_set_max_health_if_jugg("health_reboot") on every ROUND TRANSITION
// (_zm.gsc:4521), on laststand revive, and on jugg loss, computing
// player_base_health (+jugg) and discarding vitality entirely. The trap's
// asymmetry: without jugg the rebuilt 100 sat BELOW the maintain floor and was
// silently repaired; with jugg the rebuilt 200 sat ABOVE a jugg-blind floor,
// so it looked like "vitality breaks when you get jugg" specifically.
// THE ACTUAL MECHANISM NOW (v14.28, two halves): entry main() pins
// level.zombie_vars["player_base_health"] = 150 (so stock's own rebuild lands
// on our base), and max_hp_floor() — the ONE owner of the minimum-max formula,
// used by the spawn grant and the body-loop maintain — counts an ACTIVE jugg,
// so the floor for a jugg holder is 250 + 10xVIT and any stock clobber is
// repaired within a second (raise-only, no free heal).
// THE SHARED 5-TIER DIMINISHING LADDER (v16, 2026-09-01 — user gave the same
// shape for RECOVERY, BACK ARMOR and VITALITY: "10%, 18%, 24%, 28%, 32%").
// Increments 10, +8, +6, +4, +4 — front-loaded, so the first card is the big
// one and the last two are top-ups. Same design language as the v15 move-speed
// ladder (5,4,3,3,3) but NOT a multiple of it; they are separate tables on
// purpose and must not be merged.
//
// UNIT-AGNOSTIC BY DESIGN. It returns a plain NUMBER and each caller decides
// what it means: RECOVERY and BACK ARMOR divide by 100 for a percentage,
// VITALITY uses it as FLAT HP (user's explicit call — "Flat HP", so Lv5 is
// +32 HP, not +32%). Do not bake a /100 in here.
//
// ⚠️ THE CARD ART FOR ALL THREE IS DELIBERATELY GENERIC (v16 doctrine, user:
// "lets make the prompts give generic assets so if we ever need to tweak
// numbers we dont need new assets"). A stage table cannot be printed as one
// honest number per rarity, and re-baking three cards every time a value moves
// is what docs/33 has recorded going wrong five times. The exact figure lives
// in the pause menu, which is server-fed and always current.
#define TOD_LADDER5_L1  10
#define TOD_LADDER5_L2  18
#define TOD_LADDER5_L3  24
#define TOD_LADDER5_L4  28
#define TOD_LADDER5_L5  32
#define TOD_UPG_VITALITY_HP_PER_LVL 10   // ⚠️ SUPERSEDED by ladder5() — kept only for the v14.28 stock-reboot comment that cites it by name
// RECOVERY (HEAVY, v14.11 — user 2026-08-30: "start regen faster 10% faster
// at each tier and goes to 3 tiers at 30% faster at max. A tier"). Stock zm
// regen is SCRIPT-side (_zm_playerhealth.gsc::playerHealthRegen): above the
// 20% healthOverlayCutoff it waits playerHealth_RegularRegenDelay (2400ms)
// after the last hit and then SNAPS to full; below the cutoff it waits
// longRegenTime (5000ms) and then climbs 0.1 ratio/frame. The delay var is
// LEVEL-GLOBAL, so it cannot be set per player — instead recovery_loop()
// EMULATES the stock outcome at the REDUCED delay: after
// stock_delay x (1 - ladder5(Lv)/100) without damage it delivers exactly what stock
// would deliver at the full delay (snap above the cutoff, the 0.2/tick climb
// below it). Stock's own loop still runs untouched and simply finds the
// player already healed. Both stock numbers are read LIVE off the level vars
// (fallbacks mirror the stock inits) so a stock retune propagates.
#define TOD_UPG_RECOV_PCT_PER_LVL 0.10   // ⚠️ DEAD since v16 — zero readers. recovery_loop uses ladder5( lvl ) = 10/18/24/28/32% sooner. Kept only as the v14.11 tuning record
#define TOD_RECOV_TICK_SECS       0.1     // emulation cadence; 0.1s error max on the poll-stamp lane
#define TOD_RECOV_CLIMB_PER_TICK  0.2     // veryHurt band: ratio climbed per tick (stock: 0.1/50ms frame)
// SECOND WIND (MP5, skirmisher T2 unique since v14.11 — user 2026-08-23: "you heal as you
// run. 5% health per second. starts at 1% up to level5 at 5%"). 1% of MAX HP
// per level per second WHILE SPRINTING, 5 levels => Lv1 1%/s .. Lv5 5%/s.
// Against TOD_UPG_BASE_HP 150 that is 1.5 HP/s at Lv1 and 7.5 HP/s at Lv5, so a
// full heal from near-death takes ~20s of sustained sprinting at cap.
// Gated on IsSprinting() rather than mere movement, which makes it a real
// decision: BO3 will not let you fire while sprinting, so healing costs you all
// your damage output. That is the trade — disengage and recover, or stand and
// shoot. It is also uncopyable by the other classes: SECOND WIND is the MP7's
// own T3 unique, so no other class can train it at all.
#define TOD_UPG_SECONDWIND_PER_LVL 0.01

// MOMENTUM REMOVED 2026-08-30, v14.11 (user: "Remove momentum upgrade").
// Was the MP5's unique (a skirmisher class domain until the 2026-08-24
// binding): up to +5%/Lv damage scaled linearly across 120..190 u/s 2D speed.
// Defines stay as the tuning record ("echo" pattern); the add_domain call,
// the set_guns binding and the unique_damage_mult hook are gone. Its niche —
// damage for moving — is RUN AND GUN's second half now (below), and the MP5
// inherits SECOND WIND off the MP7 in the same pass.
#define TOD_UPG_MOMENTUM_PER_LVL   0.05  // DEAD
#define TOD_MOMENTUM_MIN_SPEED     120   // DEAD — u/s 2D, no bonus below
#define TOD_MOMENTUM_FULL_SPEED    190   // DEAD — u/s 2D, full bonus at/above
// RUN AND GUN's DAMAGE HALF (v14.11 — user 2026-08-30: "Run and gun should
// increase damage while running too. At the same rates"; v16.50, user
// 2026-09-02: "make run and gun 5 tiers. 16% 28% 38% 46% 52%"). Flat while
// moving, not MOMENTUM's ramp — the ammo half is flat, so the card stays ONE
// condition with ONE ladder. The ladder is a STAGE TABLE (steps 12/10/8/6,
// diminishing), read through rng_dmg_add() — never a base + per-level rate.
// The percentages and the movement test are LOCKSTEP MIRRORS of
// _tod_runandgun.gsc (TOD_RNG_PCT_L1..L5 = these x100, TOD_RNG_MIN_SPEED 120,
// and is_running(): IsSprinting() OR 2D speed >= MIN_SPEED) — that module
// cannot be #used from here (it imports us; the KB cycle rule), so the numbers
// are duplicated on purpose. Change one file and you MUST change the other
// (and DETAIL[23] in tod_upgrade.lua), or the card's two halves trigger on
// different definitions of "moving" or pay different ladders.
#define TOD_UPG_RNG_DMG_L1         0.16
#define TOD_UPG_RNG_DMG_L2         0.28
#define TOD_UPG_RNG_DMG_L3         0.38
#define TOD_UPG_RNG_DMG_L4         0.46
#define TOD_UPG_RNG_DMG_L5         0.52
#define TOD_UPG_RNG_MIN_SPEED      120   // u/s 2D — LOCKSTEP with TOD_RNG_MIN_SPEED
#define TOD_UPG_LEECH_PER_LVL   4      // +4 HP per class-gun kill per level (SLASHER)
// SCAVENGER feedback throttle (user 2026-08-22 asked for a sound).
// The refund is at most ONE round per shot (v9.10), but a Lv6 assault on a
// dense train can still cross its 2-kill threshold shot after shot — only
// the SOUND is throttled to one per this many ms, per player; ammo always
// lands.
//
// MUST STAY ABOVE THE CLIP LENGTH. The wav is the user's gun-reload sample
// (tod\sfx\tod_scavenger.wav): the clink itself is ~370ms and the file is
// cut at 500ms (v9.10 — the old 945ms file carried 575ms of dead silence,
// which is what forced the old 1100ms gap). At a gap BELOW the clip length
// it retriggered ON TOP OF ITSELF and smeared. If the clip is ever swapped,
// re-check this.
#define TOD_SCAV_SND_GAP_MS     600
// BULLET FEED (user 2026-08-21): ONE round per tick, always — the LEVEL buys
// RATE, not amount. Lv1 every 3.0s ... Lv10 every 0.75s (floored).
// v8.9 buff (user 2026-08-21: "starts at 2s then improves linearly all the
// way to 0.4s"): Lv1 = 2.0s/round, linear over the 10 levels to 0.4s at Lv10.
// v14.14 2x BUFF (user 2026-08-30: "can you 2x buff bullet feed upgrade"). All
// three constants HALVED, so throughput exactly doubles at EVERY level — the
// amount is still ONE round per tick (that is what reads as a belt feeding);
// only the RATE moved, which is the domain's whole design. Ladder is now
// Lv1 1.0s/round -> Lv10 0.2s/round (was 2.0 -> 0.4).
// KEEP THESE THREE IN LOCKSTEP: base - step*(maxLv-1) must land ON min, or the
// floor clamps early and the top levels stop paying. 1.0 - 0.0889*9 = 0.1999.
#define TOD_UPG_FEED_BASE_SECS  1.0    // seconds per round at Lv 1... (3.0 -> 2.0 -> 1.0)
#define TOD_UPG_FEED_STEP_SECS  0.0889 // ...minus this per level (1.0 -> 0.2 across 9 steps)
#define TOD_UPG_FEED_MIN_SECS   0.2    // floor — Lv10 lands here (never zero: would spin the catch-up loop)
#define TOD_UPG_CLEAVE_RADIUS   60     // halved 2026-08-20 (user); extra melee victims within this range
// CLEAVE'S AUDIO TELL (user 2026-09-01: "so you can audibly hear when cleave
// triggers"). CLEAVE is otherwise INVISIBLE from the first person — the extra
// victim is off to the side and dies with no cue of its own — so a landed
// cleave now reads as a DOUBLE blade hit.
//
// EXACTLY TWO SOUNDS, NOT THREE. The engine already plays the melee
// flesh-impact on the primary hit (the weapon's meleeSurfaceSoundPlayer);
// that is the FIRST of the pair, so script plays only the ECHO. Playing our
// own copy at t=0 as well would land on the same frame as the engine's and
// just read as "louder hit", not as two hits.
//
// The alias is not invented: it is the literal `zombieBody` entry of
// `t9_melee_knife_surface_plr` in
// source_data/t9_weapons/melee/t9_me_surfacesounddef.gdt — i.e. the sound the
// combat knife and the wakizashi already make on a zombie — and it ships in
// our own sound/aliases/tod_combat_knife.csv, so it is guaranteed loaded in
// this zone. The STORMBREAKER (the Leviathan port) hits on a stock surface
// def whose aliases this zone does NOT carry; it borrows this blade slash,
// which is a generic blade-in-flesh and reads correctly on it.
#define TOD_UPG_CLEAVE_ECHO_SFX    "fly_melee_swipe_player_t9_knife_h"
#define TOD_UPG_CLEAVE_ECHO_SECS   0.2    // user-specified gap between the two hits
// CLEAVE KILL MONEY (user 2026-10-04: "Slashers cleave kills should be 75% of base
// kills ... make sure the display money is proper as well"). A cleave victim is
// killed by a script DoDamage with no hit type, so stock paid it as a bare kill
// (50, no melee bonus) under whatever label the kill feed guessed. Now a cleave
// KILL pays this fraction of the slasher's BASE kill - the stock melee kill,
// get_zombie_death_player_points() + zombie_score_bonus_melee (50 + 70 = 120) -
// so 90, and 180 under Double Points. It goes through stock player_add_points on
// its own score event (TOD_CLEAVE_SCORE_EVENT), so validity, the Double Points
// multiplier and the 10s rounding are stock's; the kill popup shows the same
// number (tod_popup_points) and BOUNTY's nominal for the kill is it too
// (bounty_kill_value). See cleave_kill_claim.
#define TOD_CLEAVE_KILL_FRAC       0.75
#define TOD_CLEAVE_SCORE_EVENT     "tod_cleave_death"
#define TOD_UPG_BASE_HP         150    // base player max HP (user 2026-08-20; stock 100; jugg stacks additively on top)
// CLASS TIERS (docs/25, user 2026-08-22): once the class gun is PaP'd AND the
// player has climbed high enough (the FLOOR GATE below), this percent of card
// deals carry a TIER card (the right slot; never auto-locked).
// Dev flag -> 100 (tier_card_pct) so the whole promotion flow is testable in
// one session. LUCK does NOT move it (user).
// v9.42 (user 2026-08-23: "Increase this to 20%. 10% was too low") — 10 -> 20.
#define TOD_TIER_CARD_PCT       20
// ---- THE CLASS TIER FLOOR GATE (v14.35, user 2026-08-30) ------------------
// "You must also reach floor 10 to get 2nd tier class upgrade and floor 20 for
// 3rd. I dont want players able to be tier 2 or 3 before even opening the first
// door to the tower."
//
// WHY IT WAS POSSIBLE AT ALL: the PaP requirement below was doing this job by
// accident, because the first Pack-a-Punch you can reach while climbing IS the
// floor-10 breather vendor (the crown machine sits above all 50 laps). The
// FREE-PAP POWERUP is the hole — it sets player.tod_pap_owned wherever it
// drops, so one lucky drop in the base arena made a tier-1 player eligible for
// the promotion without touching a door. This gate closes that, and for the
// normal route it costs nothing: floors 10 and 30 are the FIRST and THIRD
// breathers, which is where the PaP machines are anyway (T3 was the second
// breather, floor 20, until 2026-09-02 — user: "move tier 3 upgrade to floor
// 30"; every number below moved with it, incl. the Lua floor->tier table).
//
// Numbers, not a formula, because they are the user's numbers. A tier past 3
// (none exists — tod_classes::tier_max() is 3) keeps the ladder's own spacing
// rather than arriving ungated; see tier_floor_req().
#define TOD_TIER2_FLOOR         10
#define TOD_TIER3_FLOOR         30   // 2026-09-02 (user): T3 moved 20 -> 30; docs/72 re-baked the badge
// ---- CLASS TIER UNIQUES (docs/25 §9) — one per tier gun, script-side -----
// ADRENALINE (domain 25, skirmisher — bound to the MP7, NOT the MP5; the old
// comments here said MP5 and were wrong from 2026-08-24, when set_guns moved it).
//
// REWORKED v16 (2026-09-01, user: "5 tiers 3% each tier and it gives a speed
// boost when you get multi kills. It has a cool down as well. Each tier lowers
// the cool down a bit. 10s, 9s, 8s, 7s, 6s and it lasts for 3s everytime it
// triggers.")
//
// IT IS NO LONGER A STACKING SYSTEM. It was: every kill added a stack, up to 3,
// inside a rolling 4s window, worth +4/6/8% per stack. It is now a single
// cooldown-gated PROC: a multi-kill fires one fixed burst, then the domain is
// locked out for the cooldown. TOD_ADREN_STACKS and self.tod_adren_stacks are
// DELETED rather than stubbed to 1 — this file's own doctrine, stated twice
// (the retired MOBILITY term and the removed class_hs_scale): a term that can
// only ever be one value is how the next reader loses an hour.
//
// THE PERCENT IS POINTS OF SCALE, NOT A PERCENTAGE OF THE CLASS BASE. Move
// speed has been an ADDITIVE sum since v15, so "+3%/tier" means +0.03 of scale
// per tier, identical for every class. Writing it as 0.03 * class_speed_base()
// would quietly pay the skirmisher 0.033 and re-open the gap v15 closed.
#define TOD_ADREN_PCT_PER_LV    0.03   // +3% of SCALE per tier -> Lv5 = +0.15
// v17.67 (2026-09-05, user: "buff adrenaline so that it does extra damage
// while active as well. Same levels as the speed % increases"): the SAME
// adren_bonus() value is also added to the bullet-damage sum in
// unique_damage_mult while the burst is live -> +3%/tier damage, Lv5 = +15%,
// DARK = +25%.
//
// v17.85 (2026-09-05, user: "for adrenaline we need to add healing on trigger.
// It will match the percentage"): a THIRD lane -- the proc heals a percentage
// OF MAX HEALTH, once, at the moment it fires.
//
// AT DOUBLE THE OTHER TWO, same session, once it had been seen written down:
// "the health gain you get on trigger should be double the percentage. So 50%
// health gain one time on adrenaline trigger" -- then, on being shown the
// ladder, "thats for dark but of course its dynamic depending on % for that
// tier". So the heal is 2x adren_bonus() at every level:
//
//   Lv1 6%   Lv2 12%   Lv3 18%   Lv4 24%   Lv5 30%   DARK 50%
//
// THE MULTIPLIER IS A DEFINE, NOT A 2 IN THE EXPRESSION, and this file already
// said why before the ask arrived: one function feeds all three lanes so they
// cannot drift, and the moment one lane needs its own number it gets its own
// NAME rather than a second copy of the ladder. TOD_ADREN_HEAL_MULT is that
// name. Retune the percent and all three still move together; retune this and
// only the heal does.
//
// THE HEAL IS A PERCENTAGE, THE OTHER TWO ARE POINTS. Same source number,
// different units, and that is not sloppiness: move speed is points of additive
// scale (see the note below), bullet damage is a multiplier addend, and the
// heal is read against self.maxhealth -- so it follows Juggernog and VITALITY
// without anything here knowing they exist.
//
// AND IT IS ONE-SHOT, NOT A HEAL-TANK. A 30% top-up sounds enormous next to
// LEECH's flat 25 HP per blade kill, but LEECH pays on EVERY kill while this
// pays once per proc behind a 3-kill trigger AND a 12-20 s cooldown, i.e. at
// best once every 12 s. Read those two together before judging the number.
#define TOD_ADREN_HEAL_MULT     2.0    // the heal is DOUBLE the speed/damage percent (user 2026-09-05)
#define TOD_ADREN_MS            3000   // the burst lasts 3s, every time it fires
// MULTI-KILL = N kills inside a rolling window. THE DEFINITION IS A DESIGN
// CHOICE, NOT A DETAIL, so it is written down here.
//
// WHY A ROLLING WINDOW AND NOT "SAME SERVER FRAME": the death callback fires
// once per zombie, so a penetration or shotgun kill delivers several callbacks
// sharing one GetTime(). SCAVENGER already exploits that — to SUPPRESS extra
// payouts (its tod_scav_pay_ms frame stamp). Copying that shape here would
// invert its purpose and, worse, would make this domain nearly unproccable for
// the class that owns it: same-frame multi-kills come from PENETRATION (heavy),
// CLEAVE and THOR (slasher) and IMPACT (assault). A skirmisher holding the MP7
// has almost no way to produce one by shooting. A rolling window covers the
// same-frame case for free — kills sharing a frame share the timestamp — and
// also rewards what a player actually means by a multi-kill.
#define TOD_ADREN_MK_NEED       3      // kills required... (user: "3 kills within 1.5s")
#define TOD_ADREN_MK_WINDOW_MS  1500   // ...inside this window
// COOLDOWN LADDER: 20/18/16/14/12s at Lv1..Lv5. DOUBLED from the first spec
// (10/9/8/7/6s) on 2026-09-01 — user: "lets double the delay on the retrigger.
// I dont want it to proc too often". Same shape as
// thor_cooldown_ms — MAX minus STEP per level, with a FLOOR so a future 6th
// level is safe by construction rather than by nobody adding one.
#define TOD_ADREN_CD_MAX_MS    20000
#define TOD_ADREN_CD_STEP_MS    2000
#define TOD_ADREN_CD_MIN_MS    12000
// 3 synth heartbeats decaying, 1.42s, 2d/player-only.
// ⚠️ INAUDIBLE ON FIRST SHIP (user 2026-09-01: "on adrenaline trigger i cant hear
// the heartbeat"), and the cause was TWO COMPOUNDING ATTENUATIONS, neither of
// which is obviously wrong alone:
//   * the alias sat at vol 70 - the LOWEST row in tod_ui.csv, against 88-95 for
//     every other per-proc cue (tod_scavenger, tod_headshot_ding, tod_thor_zap)
//   * the wav peaked at -9.0 dBFS, from the trim pass that removed its lead-in
// Together ~11 dB under a comparable cue, i.e. masked by the player own gunfire.
// Fixed by raising BOTH: alias 70 -> 92, wav peak-normalised to -1.0 dBFS.
// The asset chain was never the problem - alias present, CSV in the .szc, wav in
// the .sabl, pointer set, call site reached. When a cue is "not playing", MEASURE
// THE LEVEL before re-checking the wiring.
#define TOD_ADREN_SFX          "tod_adren_pulse"
// LMG SPRINT / "FULL STEAM" (domain 42, v15 item 24). Unbroken sprint for this
// long arms the ladder bonus in lmg_sprint_bonus(); ANY break disarms it and
// restarts the clock. Watcher: _tod_uniques.gsc, 20 Hz (TOD_SPRINT_POLL).
#define TOD_LMGS_ARM_MS         800    // 1500 -> 1000 -> 800 (user 2026-09-01: "Full steam should work at 0.8s instead of 1s")
// FULL STEAM PAYS 20% MORE THAN THE SHARED LADDER (v16.8, user 2026-09-01:
// "improve the full steam upgrade by 20%"). The ladder itself is untouched -
// SPRINT and FORCED MARCH still read speed_pct_for_level() raw - only
// lmg_sprint_bonus() scales its result. Points on the scale, since the ladder
// is additive: Lv1 .06 / Lv2 .108 / Lv3 .144 / Lv4 .18 / Lv5 .216, so a rolling
// heavy tops out at 0.80 + 0.216 = 1.016 (was 0.98). LOCKSTEP with
// FULL_STEAM_MULT in tod_upgrade.lua - the pause menu prints ladder x this.
#define TOD_LMGS_MULT           1.2
// FULL STEAM's SCREEN AURA + SFX (v16, 2026-09-01 — user: "for full steam we
// need some indicator and sound when it triggers. On abandoned cyber city we
// had the generator that took electric moves and turned them into speed. It
// created a blueish aura around the players screen and made a sound. Lets take
// that exact implementation").
//
// PORTED FROM MAP 1'S **BATTERY** IMPLANT, not from anything called "generator"
// — worth writing down because the name misled the search. Map 1 has a "Plasma
// Generator" implant too, and it is a DIFFERENT item (+10% energy damage, no
// speed, no aura). The electric-zaps-become-speed one with the blue screen wash
// is Battery, implant #10; its model is a ceramic battery out of the Der
// Eisendrache generator apparatus, which is almost certainly where the name
// crossed over. Source: _acc_elites.gsc:944-981 (aura) and :912-930 (surge).
//
// IT IS A SERVER-SIDE HUDELEM, NOT A CLIENTFIELD/CSC OVERLAY. A 640x480 "white"
// icon with horzAlign/vertAlign "fullscreen" spans the whole screen at ANY
// aspect ratio — that is the stock fullscreen-overlay recipe
// (_remotemissile.gsc:464-467). Map 1 records that a CENTRE-anchored fixed-size
// icon did NOT reach the widescreen edges, so do not "simplify" it to one.
// No clientfield, no .csc, no new bits — which is why this costs nothing
// against the 61-bit clientuimodel ceiling.
//
// ALPHA 0.10 IS A TUNED VALUE, NOT A GUESS (v16 shipped 0.15 and the user called it
// "a bit too much" the same day — "i just want a slight wash 10%"). Map 1 shipped 0.35 and the user
// rejected it the same day: it "filled the whole screen + hid the player". The
// wanted read is a light edge-of-screen wash, not a colour fill.
#define TOD_LMGS_AURA_R         0.25   // map 1's exact aqua/teal — the "blueish" the user remembers
#define TOD_LMGS_AURA_G         0.95
#define TOD_LMGS_AURA_B         0.80
#define TOD_LMGS_AURA_ALPHA     0.10   // 0.35 rejected as too opaque (map 1, 2026-07-08); 0.15 -> 0.10 (user 2026-09-01: "slight 10% wash")
#define TOD_LMGS_AURA_IN        0.15   // quick flash in
#define TOD_LMGS_AURA_OUT       0.4    // gentle fade out when the sprint breaks
// THE WIND LOOP. Starts when FULL STEAM arms and runs until the sprint breaks
// (user 2026-09-01: "a continous wind against your hair sound ... Itll stop
// when the player stops sprinting"). The wav must be a SEAMLESS LOOP — a
// one-shot here would retrigger from the top and audibly stutter.
// ⚠️ THIS ALIAS DOES NOT EXIST YET. Until its row lands in sound/aliases/
// tod_ui.csv with a looping wav, PlayLoopSound is a silent no-op — the AURA
// still shows, so the feature is visible but mute. Wire the row and the wav
// together; see docs/57.
#define TOD_LMGS_SFX            "tod_full_steam_wind"
#define TOD_LMGS_SFX_FADE       0.35   // seconds — the wind falls away rather than cutting dead
#define TOD_STREAK_GAP_MS       500    // (mirrors _tod_uniques) a longer pause ends a fire streak
// OVERDRIVE (Death Machine, NOT the MP7 — the old comment was stale by two
// reworks). v16 (2026-09-01), user: "the longer you shoot the more damage you
// do ... uninterrupted shooting slowly increase till it gets to max ... should
// take about 3s to get there. So shooting for 3s or longer you will do 125%
// damage instead of 100%".
//
// SO THE LADDER IS THE **TOTAL AT FULL RAMP**, not the per-stack step:
// Lv1 +5% ... Lv5 +25%. overdrive_pct() returns the PER-STACK value, which is
// therefore the total divided by TOD_OVERDRIVE_STACKS — see it below.
//
// 15 ROUNDS PER STACK IS DERIVED FROM THE GUN, NOT PICKED. The Death Machine's
// emitted fireTime is 0.04 s/round (source_data/tod_weapon_twins.gdt), so
// 15 x 5 stacks = 75 rounds = exactly 3.00 s of held trigger. If the DM's fire
// rate is ever retuned THIS NUMBER MUST BE RE-DERIVED or the ramp silently
// stops being 3 s. It is safe to key on one gun because gun_keys binds
// OVERDRIVE to the Death Machine alone.
//
// ⚠️ UNVERIFIED INPUT, FLAGGED: the whole ramp rides self.tod_fire_streak, which
// counts the "weapon_fired" notify. The DM is the map's only fireType "Minigun"
// and nobody has confirmed that notify fires PER BULLET on that fire type — if
// it is per trigger-PULL the streak never climbs and OVERDRIVE pays zero at any
// percentage. The dev probe in _tod_uniques::fire_streak_watch prints the
// streak; read it before concluding a retune did nothing.
#define TOD_OVERDRIVE_PER       15     // rounds per stack — 15 x 5 = 75 rounds = 3.00s on the PaP'd Death Machine (fireTime 0.04); 3.75s unpacked (0.05) — the pause-menu row quotes both
#define TOD_OVERDRIVE_STACKS    5
// KILL RELOAD (assault) — RETIRED 2026-09-01 (user: "Lets remove it. No one
// likes it"). Its three TOD_KILLRELOAD_KILLS_LV* defines (55/40/30 kills per
// free magazine), killreload_kills_needed() and the block in unique_on_kill
// went with it, on the IMPACT ROUNDS form — see the note at its old add_domain.
// IMPACT ROUNDS (assault, all three guns since v9.38). v9.45 (user 2026-08-23:
// "impact rounds can be 10 levels but each level needs to be nerfed. Smaller
// steps per level"): 3% PER LEVEL over TEN levels — 3/6/9 ... 30% of hits burst.
// The Lv10 ceiling is exactly the old Lv3 ceiling, so the card got no stronger;
// what changed is that reaching it costs ten levels instead of three and each
// individual level is a third of the proc rate it used to buy.
// SUPPRESSING FIRE NERF (user 2026-08-24: "nerf supressing fire to 12%, 24%,
// 36%"): was 25/40/55 (base .25 + .15/Lv), now a clean 12/24/36 — base AND step
// are both .12, so the ladder is linear instead of front-loaded. Three places
// carry these numbers as TEXT and all three moved with it: the add_domain
// description, tod_upgrade.lua DOMAIN[29].desc, and its DETAIL[29].val.
#define TOD_SUPPRESS_BASE       0.12   // SUPPRESSING FIRE (HK21): slow 12/24/36%...
#define TOD_SUPPRESS_PER_LV     0.12
#define TOD_SUPPRESS_MS         1500   // ...for 1.5s
#define TOD_GRINDER_PER         5      // MEAT GRINDER (Death Machine): one stack per 5 consecutive rounds
#define TOD_DRAWCUT_MS          400    // DRAW CUT (katana): a swing inside 0.4s of a sprint...
#define TOD_DRAWCUT_PER_LV      0.5    // ...deals +50% per level
// (TOD_UPG_LUCK_CAP removed 2026-08-20 — rarity odds ride the 0..100% luck
// bar, see roll_rarity + _tod_luck.gsc.)

// LuiNotifyEvent REQUIRES its event string precached (stock does this for
// "zombie_notification") — without it the pause-menu owned-upgrades sync
// silently never fires and CoD.TodOwned stays empty (bug 2026-08-20).
#precache( "eventstring", "tod_upg_sync" );
// v14.35 — the CLASS TIER floor requirement for the deal about to be shown
// (0 = the floor is not what is stopping this player). Same zero-bit int lane;
// same precache trap, which is why it is here and not left implicit.
#precache( "eventstring", "tod_upg_tier_need" );
#precache( "eventstring", "tod_upg_class" );   // v16: the deal panel's CLASS badge (docs/59)
// v14.13 — the SURVIVES-PROMOTION bit rides INSIDE the max arg of the
// tod_upg_sync event: sync_max() adds this flag when THIS player's copy of
// the domain survives a tier card, and the Lua receiver strips it back off
// (m >= 100 -> safe, m -= 100). Packed rather than sent as a 4th int because
// no 4-arg LuiNotifyEvent exists anywhere in this tree — the 3-arg shape is
// the proven one (stock-API doctrine: never be the first caller of an
// unverified arity). Must stay ABOVE every real max (caps top out at 10).
#define TOD_SYNC_SAFE_FLAG 100
// DARK UPGRADES (v17.10): the SECOND bit packed into the same tod_upg_sync max
// arg, so the pause menu can print the dark value. 200 rather than another 100
// so the two are separable, and the Lua MUST strip this one FIRST — a row at
// 10 + 100 + 200 = 310 read safe-first would come out as safe + 210.
// Caps top out at 10, so 310 is the ceiling and the int stays small.
#define TOD_SYNC_DARK_FLAG 200
// v19.11 — how many tod_upg_sync writes the King's max-out sends before
// yielding a frame (see king_max_player). Preprocessor defines belong in this
// header block, never beside the function that uses them.
#define TOD_SYNC_BURST     8
// DARK UPGRADES (v17.10): the sentinel written into the 4-bit todUpg<slot>L
// clientfield to mark a dealt card as DARK. Domain levels top out at 10, so
// 11..15 are unreachable as real values and 15 is unambiguous. This is why the
// feature costs ZERO clientfield bits against a pool already at 60 of its 61
// proven-booted bits — see the DARK UPGRADES block above set_no_dark(), and
// note the TIER card packs class+tier into this same field already.
// LOCKSTEP: tod_upgrade.lua reads the same 15 (DARK_L) to pick the dark card
// art. Change both or neither.
#define TOD_UPG_DARK_L 15
// Chance the SECOND slot is also a dark card, when the player has more than one
// maxed domain and the tier card is not using that slot. Was 35 under the
// 2026-09-03 rule ("possible to get both ... the only guarantee is that one
// must be"). **100 since v17.46** — user 2026-09-04: "in no situation where you
// are eligible for two dark upgrades should you only get one." An EMPTY right
// slot is filled regardless of this number (deal_dark), so this knob only
// decides whether a second dark card displaces a REGULAR card.
#define TOD_DARK_BOTH_PCT 100
// ---- DARK UPGRADE VALUES (user 2026-09-04; docs/92 THE NUMBERS is the record).
// Every one is an ADDITIVE step on top of the domain's MAXED value, never a
// replacement for it — a dark bit implies the domain is already at its cap.
#define TOD_DARK_DMG_ADD        0.50   // DAMAGE       +100% -> +150%
#define TOD_DARK_HS_ADD         0.25   // HEADSHOT      +60% ->  +85%  (cap was +50% until the 2026-09-08 12%/Lv x 5 pass; the dark STEP is unchanged)
#define TOD_DARK_BOSSDMG_ADD    0.20   // GIANT SLAYER  +60% ->  +80% (was +85, user 2026-09-05)
#define TOD_DARK_GUNSLINGER_ADD 0.30   // GUNSLINGER   +150% -> +180% (cut from +100 on the 2026-09-04 balance pass)
#define TOD_DARK_BOUNTY_ADD     0.50   // BOUNTY        +50% -> +100%
// LUCK: NO DARK STEP since 2026-09-05 (user: "Remove dark luck"). Was TOD_DARK_LUCK_ADD 0.50 (x1.50 -> x2.00).
#define TOD_DARK_DR_ADD         10     // DMG REDUCTION +10 percentage points on the class cap (25/30/34/40)
#define TOD_DARK_VITALITY_HP    18     // VITALITY     +32HP -> +50HP (was +57, user 2026-09-05)
#define TOD_DARK_LADDER5_ADD    13     // RECOVERY and BACK ARMOR: 32% -> 45%
// [tod 2026-09-08] WAS 25, NOT 0.25 — A UNIT BUG, AND THE 200k-A-SHOT HEAVY.
// This value is added straight into the additive `mult` chain in
// upgrade_damage_cb, where every other damage-side dark add is a FRACTION
// (DMG 0.50, HS 0.25, BOSSDMG 0.20, GUNSLINGER 0.30, RNG 0.48, ADREN 0.10).
// At 25 it read as +2500%, so a full-ramp dark OVERDRIVE made `mult` 27.25
// instead of 2.50 — about 11x the intended output. On a PACK III PaP'd Death
// Machine that was 75,210 a headshot, or 225,630 under Insta-Kill, against the
// 6,900 / 20,700 the design asked for.
// THE STEP IS 0.40, NOT THE DESIGN'S 0.25 (user 2026-09-08: "instead of 0.25 we
// can give it 0.4"): dark OVERDRIVE at full ramp is +65%, not +50%. The BASE
// ladder is untouched at +25% (overdrive_total_pct, 0.05/Lv).
// It fired on EVERY Warden King fight rather than at random: king_max_out()
// caps every domain and king_dark_deals() then hands out dark cards until
// nobody has one left, so a heavy reaches that fight maxed AND dark by
// construction. The integer dark adds (DR 10, VITALITY_HP 18, LADDER5 13,
// LEECH_HP 25, TRAIL_PCT 10) are all correct — they live in integer-percent or
// flat-HP lanes. This one was the only outlier in the fractional lane, and its
// own comment said so: "+25% -> +50%" requires 0.25.
#define TOD_DARK_OVERDRIVE_ADD  0.40   // OVERDRIVE     +25% ->  +65% at full ramp (was +50%, user 2026-09-08)
#define TOD_DARK_LEECH_HP       25     // LEECH        FLAT 25HP per blade kill, REPLACES the ladder value (was 10+8, user 2026-09-05)
#define TOD_DARK_SPEED_ADD      0.15   // SPRINT        +33% ->  +48% of move scale (cut 5 points, user 2026-09-04)
#define TOD_DARK_MARCH_ADD      0.17   // FORCED MARCH  +18% ->  +35% (was +38, user 2026-09-05)
#define TOD_DARK_ADREN_ADD      0.10   // ADRENALINE    +15% ->  +25% burst
#define TOD_DARK_LMGS_ADD       0.20   // FULL STEAM  +21.6% -> +41.6%
#define TOD_DARK_RNG_ADD        0.48   // RUN AND GUN    52% ->  100% (was 77, user 2026-09-05) -- LOCKSTEP: _tod_runandgun.gsc adds the integer 48
#define TOD_DARK_BULLETFEED_RPS 7.0    // BULLET FEED   5.0/s ->  7.0/s
#define TOD_DARK_ATHLETE_LEVELS 2      // ATHLETE      computes as level 7
#define TOD_DARK_SCAV_MULT      0.60   // SCAVENGER    -40% of the kills you currently need (user: "40% reduction of what you are at")
// CLEAVE: a guaranteed SECOND extra target. The splash lane already takes a
// count and its author left the loop able to take 2 "in case the cap ever goes
// back up" — this is that case.
#define TOD_DARK_CLEAVE_EXTRA   2
// THOR'S THUNDER: +50% on every term. THE COOLDOWN FLOOR HAS TO MOVE WITH IT or
// a third of the buff is silently eaten — Lv5 already sits exactly on
// TOD_THOR_CD_MIN_MS 1500, so scaling the cooldown alone would change nothing.
#define TOD_DARK_THOR_MULT      1.50
#define TOD_DARK_THOR_CD_MIN_MS 1000   // the dark floor (1500 / 1.5), replacing TOD_THOR_CD_MIN_MS for a dark holder
// RIOT SHIELD: 700 HP / 1:30 — defined in _tod_riotshield.gsc beside its own
// ladder (TOD_DARK_SHIELD_HP / TOD_DARK_SHIELD_RECHARGE_SECS), not here.
// TRAILBLAZER: absolute values — 10%/s burn, a 50% slow, 100u radius. LIFE IS
// DELIBERATELY NOT RAISED (the node cap binds first, and the trail is meant to
// be attrition rather than a weapon). Units match the helpers they replace:
// trail_pct is an INTEGER PERCENT, trail_slow_mult is a playback MULTIPLIER.
#define TOD_DARK_TRAIL_PCT        10     // was 6 at Lv5
#define TOD_DARK_TRAIL_SLOW_MULT  0.625  // a 37.5% slow; Lv5 base is 0.745 = 25.5%. MOVES WITH THE BASE LADDER, ALWAYS (v18.6 took both down 25%, user 2026-09-07: "trail blazer needs a nerf on slowing down enemies ... 25%"; v17.84 doubled both, and the note it left is the reason this one is not left behind: a dark card that does not track the base is either a downgrade or an outlier).
#define TOD_DARK_TRAIL_RADIUS     100    // was 88 at Lv5
// TRAILBLAZER dark also BURNS BOSSES (user 2026-09-05: "Mega Trail Blaze impacts
// bosses") -- trail_burn_tick skips the boss/elite triad only for a non-dark holder.
// PERK SLOTS base cap — RESTORED v17.3 (user 2026-09-03: "we need to add back
// the perk limit as well. Assets and implementation", choosing the FULL revert
// of v16.80 with the base back at 4, told first that this is the exact shape
// the Workshop objected to).
//
// ⚠️ THE OBJECTION WAS NEVER THE CAP, IT WAS THE CARD. Bobby, three comments
// 09-01..09-03: "wasting these awesome upgrades on a DAMN PERK SLOT". At 50 of
// ~650-780 per-class draw weight this surfaced about once in seven two-card
// deals, so a normal run saw it once or twice, effectively never reached 9
// slots, and read the cap as a hard 4 while spending real card slots to get
// there. If it draws fire again, the lever to reach for is the DRAW WEIGHT or
// moving slots off the card entirely — not the base number.
#define TOD_PERK_SLOT_BASE 4
#precache( "model", "tod_heavenly_altar" );   // shared cyber altar: base, four breathers, crown
// THOR'S THUNDER fx (AFTER every #using — the "No generated data" trap)
#precache( "fx", "_ZoekMeMaar/powerups/thunderstorm_effect" );
#precache( "fx", "zombie/fx_tesla_shock_zmb" );
#precache( "fx", "zombie/fx_tesla_shock_eyes_zmb" );
#precache( "fx", "zombie/fx_thundergun_smoke_cloud" );
#precache( "fx", "dlc0/factory/fx_teleporter_elec_strike_os" );
#precache( "fx", "fire/fx_fire_ground_rubble_50x50" );   // TRAILBLAZER ground fire (v16.79; zone: fx,fire/fx_fire_ground_rubble_50x50). v16.62 shipped zombie/fx_dog_fire_trail_zmb, which is a 5 KB STUB in the mod tools (no material, draws nothing) — memory stub-efx-in-mod-tools
#precache( "fx", "fire/fx_fire_ground_rubble_sm_50x50" );   // v16.94 — the SMALL flame for Lv1-2 (zone line required too; see trail_fx)

// THOR'S THUNDER tuning (user 2026-08-21: "louder and stronger and more
// powerful every level up"). Damage is a FRACTION of each victim's max health
// so the strike stays relevant in late rounds (a flat number would not).
// v8.8 (user 2026-08-21: "reduce effect/impact of Lv1 — Lv1 & Lv3 too close").
// Lv1 is now a small localized zap; the storm builds toward Lv3+. Radius/dmg
// both start lower and climb steeper so the tiers read distinctly.
// v14.30 (user 2026-08-30: "nerf thors thunder all around by 20%"). Every
// lever moves by the same 20%, so the level curve keeps its shape and only its
// height changes: radius x0.8, damage fraction x0.8, cooldown x1.2 (20% longer
// = 20% fewer strikes). The per-strike VICTIM CAP is deliberately left at
// 2..6 — it is an integer ladder, and the domain blurb reads "2-6 nearest
// zombies", so shaving it would cost a text/art pass for a fractional change.
#define TOD_THOR_RADIUS_BASE   32     // Lv1 = 64u (was 80); Lv3 = 128, Lv5 = 192
#define TOD_THOR_RADIUS_PER_LV 32     //   +32u per level (was 40)
#define TOD_THOR_DMG_BASE      0.04   // Lv1 = 16% max hp (was 20%)...
#define TOD_THOR_DMG_PER_LV    0.12   //   +12%/Lv -> Lv3 = 40% (was 50%), Lv5 = 64% (was 80%)
// COOLDOWN RAMP (user 2026-08-21: "higher you upgrade, less of a cooldown").
// Per-player gate between strikes; scales DOWN with the thunder level.
//   cd(lvl) = max( MIN, MAX - (lvl-1)*STEP )   ->  Lv1 900ms ... Lv5 300ms
// INFINITE AMMO removes the gate entirely for the melee class (user
// 2026-08-21) — TOD_THOR_MAX_LIVE still caps concurrent bolts so an
// un-gated knife can't spawn unbounded fx/entities.
// Cooldown lengthened (user 2026-08-21 "no delay between when the lightning
// triggers on hit"): the old 900ms Lv1 was shorter than the ~1.1s bolt+cloud
// afterglow, so strikes blended into a continuous storm and read as no gate.
// Lv1 now clearly gaps (1.5s > the fx lifetime); Lv5 stays snappy.
// x2.5 on ALL THREE (user 2026-08-22: "procs way too often — double that time
// ... tempted to say 2.5x"): the ramp is MAX - (lvl-1)*STEP clamped at MIN, so
// scaling only MAX/STEP would let the floor swallow the nerf at Lv4-5.
// Lv1 3750 / Lv2 3125 / Lv3 2500 / Lv4 1875 / Lv5 1250 ms (was 1500..500).
// x1.2 on ALL THREE again (2026-08-30, the -20% pass): same reason as the x2.5
// before it — scaling MAX/STEP alone would let the MIN floor swallow the nerf
// at Lv4-5. Lv1 4500 / Lv2 3750 / Lv3 3000 / Lv4 2250 / Lv5 1500 ms.
#define TOD_THOR_CD_MAX_MS     4500   // Lv1 cooldown (was 3750)
#define TOD_THOR_CD_MIN_MS     1500   // floor (Lv5 lands here; was 1250)
#define TOD_THOR_CD_STEP_MS    750    // shaved per level (was 625)
// VICTIM CAP per strike (user 2026-08-22: "it just kills everything in that
// radius — limited amount, increasing with level"): the NEAREST cap zombies
// take the shock. Lv1 2 / Lv2 3 / Lv3 4 / Lv4 5 / Lv5 6.
#define TOD_THOR_MAX_HIT_BASE  2
#define TOD_THOR_MAX_HIT_PER_LV 1
#define TOD_THOR_MAX_LIVE      6      // level-wide concurrent strikes (fx + entity budget)

#namespace tod_upgrades;

function init()
{
	level.tod_upgrade_pause = false;

	// THOR'S THUNDER fx handles (map 1's level._effect idiom; all precached
	// above, all zoned).
	level._effect[ "tod_thor_bolt" ]   = "_ZoekMeMaar/powerups/thunderstorm_effect";   // the sky bolt (ZoekMeMaar)
	level._effect[ "tod_thor_strike" ] = "dlc0/factory/fx_teleporter_elec_strike_os";  // impact flash
	level._effect[ "tod_thor_shock" ]  = "zombie/fx_tesla_shock_zmb";                  // per-victim burst (Cyberjack)
	level._effect[ "tod_thor_eyes" ]   = "zombie/fx_tesla_shock_eyes_zmb";
	level._effect[ "tod_thor_cloud" ]  = "zombie/fx_thundergun_smoke_cloud";           // the lingering cloud
	level._effect[ "tod_trail_fire" ]    = "fire/fx_fire_ground_rubble_50x50";       // TRAILBLAZER (v16.79): one looping ground fire per patch, reaped on expiry (v16.62's dog-trail fx was a stub)
	level._effect[ "tod_trail_fire_sm" ] = "fire/fx_fire_ground_rubble_sm_50x50";    // v16.94: the Lv1-2 flame — see trail_fx()

	// PERSONAL UPGRADE STATION (user 2026-08-20): buy a solo upgrade at the
	// base — cost 2000 +250 per purchase (PER PLAYER), 15s timer, scheduled
	// rounds override + the same cards re-present. CO-OP has no world pause
	// (that is the risk); SOLO freezes the world like a round event as of
	// v16.84 — see station_freeze_wanted for why the risk model was always a
	// co-op argument.
	level thread station_spawn();

	register_domains();

	// Damage + fire-rate + headshot ride the actor damage chain (read-modify;
	// returns -1 when not ours — the KB chain contract).
	zm::register_actor_damage_callback( &upgrade_damage_cb );

	// Bounty/reserve/leech ride the per-zombie death callback (KB: the REAL
	// death hook — callback::on_ai_killed is register-only, never dispatched).
	zm_spawner::register_zombie_death_event_callback( &on_class_gun_kill );

	// Score-popup BOUNTY preview, exposed to the vendored Aetherium HUD as a
	// LEVEL FUNCTION POINTER rather than a #using — the same cycle-dodge the
	// mechz melee hook uses (level.tod_player_mitigations_fn). The kit must
	// never import a tod module.
	level.tod_bounty_preview_fn = &bounty_preview;
	level.tod_mage_kill_points_fn = &mage_kill_points;
	// Use the stock public hook. A usermap copy of _zm_score did not replace
	// the runtime's stock script, so adding public functions to it boot-fataled.
	zm_score::register_score_event( "death", &zombie_death_score );
	// CLEAVE KILLS pay 75% of a base slasher kill (2026-10-04, cleave_kill_claim).
	zm_score::register_score_event( TOD_CLEAVE_SCORE_EVENT, &cleave_death_score );
	// BOUNTY as a flat multiplier on a lump-sum payout (v14.5) — same pointer
	// pattern, first consumer _tod_bosses::grant_elite_reward (the killer-only
	// elite 500). See bounty_mult below.
	level.tod_bounty_mult_fn = &bounty_mult;

	// LMG SPRINT (domain 42, v15 item 24): the same pointer pattern again, for
	// the same reason. _tod_uniques.gsc owns the 20 Hz sprint poll and imports
	// NO tod module by design — that is precisely what lets THIS file read its
	// fields without a cycle — so it cannot #using its way to apply_move_speed.
	// It calls through here instead, on the frame the 1.5 s latch flips.
	//
	// WHY NOT JUST LET THE 1 s BODY TICK NOTICE: because a movement boost that
	// arrives up to a second after it is earned reads as broken, and the latch
	// it is watching flips in ~0.1 s. The pointer costs nothing and makes the
	// boost land on the arming frame.
	level.tod_apply_speed_fn = &apply_move_speed;
	// FULL STEAM feedback (v16): the aura + sound, same pointer pattern and same
	// reason — _tod_uniques owns the latch and imports no tod module.
	level.tod_lmgs_fx_fn = &lmg_steam_fx;
	// ADRENALINE proc cue (v16) — same pointer pattern; the kill hook calls it
	// through this so the sound and the speed land on the same frame.
	level.tod_adren_fx_fn = &adren_fx;

	// PERK SLOTS (restored v17.3). The base cap and the per-player hook stock
	// consults: zm_utility::get_player_perk_purchase_limit starts from
	// level.perk_purchase_limit and, when this pointer is set, replaces it with
	// `self [[ hook ]]()` — self is the PLAYER, no args (_zm_utility.gsc:5881).
	// Set here rather than in zm_tower_of_doom.gsc so the cap and the domain
	// that raises it live in one file.
	level.perk_purchase_limit = TOD_PERK_SLOT_BASE;
	level.get_player_perk_purchase_limit = &perk_slot_limit;

	callback::on_spawned( &player_upgrade_setup );

	// MAX AMMO also tops the CLIP (user 2026-08-21). Lives in _tod_powerups
	// but is threaded here because this module already owns the spawn hook.
	callback::on_spawned( &tod_powerups::max_ammo_clip_watch );

	level thread event_scheduler();
}

// Order here = the domain ids the Lua DOMAIN table mirrors (1-based). APPEND
// ONLY — reordering desyncs every card the client renders.
// class_key undefined = SHARED (every class rolls it); otherwise only that
// class sees the card. max = the domain's level cap (depths vary by design:
// deep 10-level grinds vs short punchy ladders — user 2026-08-19).
// Gun-bound domains scope themselves to the CURRENT class gun automatically
// (is_class_primary); body domains (sprint/mobility/health/regen) stay
// trained on the PLAYER even after a class switch.
// v4 matrix (user 2026-08-19). Ids 1..14 mirrored in _tod_upgrade_ui.gsc
// domain_id AND tod_upgrade.lua DOMAIN — keep all three in lockstep.
// PENDING (twin-swap phase, NOT registered so no dead cards): FIRE RATE +
// HANDLING (skirmisher), RECOIL (assault), KNIFE SPEED (slasher).
function register_domains()
{
	level.tod_domains = [];
	// TIERS (v8.9): the last arg. S = wins the run on its own (universal
	// multipliers, effective-HP doublers, the melee nukes, and LUCK — which
	// compounds into every future roll). A = strong but conditional or
	// capped low. B = economy / quality-of-life.
	//
	// -- shared core (all classes) --
	add_domain( "damage",     "DAMAGE",      "+10% damage / Lv",                    10, undefined, TOD_TIER_S );   // 12% -> 10% (v15, 2026-08-31)
	// DR CAPS AT 5 FOR EVERY CLASS (v15, 2026-08-31 — user: "Damage Reduction
	// needs a nerf"). It was the strongest survivability item in the map by a
	// wide margin: -5%/Lv x 10 = x2.00 effective HP, worth more than a second
	// Juggernog, and unlike Jugg it is class-agnostic, promotion-proof (scope
	// "class", below) and death-proof. Halving the CEILING rather than cutting
	// the per-level step was the deliberate choice — the card art prints a
	// per-card increment ("-5% / -10% / -15%") and the pips come from the server,
	// so -5%/Lv stays literally true at every rarity and NOTHING NEEDS RE-BAKING.
	// Cutting the step to -4% or -3% would have been three card re-bakes and a
	// full build for the same effect.
	//
	// WHAT WENT AWAY WITH IT: the bonus_class/bonus_max pair. Slasher (v14.11)
	// and skirmisher (v14.33) were each capped at 5 individually, using
	// bonus_class/bonus_max as a per-class OVERRIDE rather than a bonus
	// (domain_max() returns bonus_max for the named class and has never required
	// it to be higher — SCAVENGER still uses that lane UPWARD, so the mechanism
	// is alive and this is not the place to learn it from). With 5 now universal
	// those two args said nothing, so they are gone rather than left as a
	// no-op that reads like a live carve-out.
	// v17.3 — MAX IS 10 (the ceiling) BUT NO CLASS REACHES IT EXCEPT THE HEAVY.
	// The per-class caps are declared in set_class_max below: 3 / 5 / 7 / 10.
	// The desc carries no ladder any more BECAUSE the ladder now ends in a
	// different place for every class — the pause row prints the player's own.
	add_domain( "dr",         "DMG REDUCTION", "take less damage, always on", 10, undefined, TOD_TIER_A );   // v16: flat 5%/Lv -> diminishing ladder, and S -> A band (user: "move damage reduction to A tier")
	add_domain( "bounty",     "BOUNTY",      "+5% money per kill / Lv",             10, undefined, TOD_TIER_S );
	add_domain( "luck",       "LUCK",        "+10% luck gain rate / Lv",             5, undefined, TOD_TIER_A );
	// PERK SLOTS (id 40) — RETIRED 2026-09-03 (v16.80, user: "remove the perk
	// limit so revert back how it use to be"). v14.56 (2026-08-31) capped perks
	// at stock's 4 and sold the way past it as this universal A-band card
	// (+1 slot / Lv, max 5 = the 9-machine roster). It shipped without a change
	// note, and the Workshop thread's verdict was blunt (Bobby, 09-01..09-03:
	// "wasting these awesome upgrades on a DAMN PERK SLOT"): at 50 of ~650-780
	// per-class draw weight it surfaced about once in seven deals, so the cap
	// read as a hard 4 and every offer of it was a card spent on nothing. The
	// cap is gone (zm_tower_of_doom.gsc sets the limit above the roster), so
	// the domain has nothing to do; the id stays mapped in domain_id() and the
	// Lua tables (key-keyed, same form as 27/28/32/34), the r40 pause plate
	// stays zoned, the three card images are unzoned.
	// COPY 2026-09-11 (user: "it says one perk per level. That's unclear because
	// people think that it's per floor level"). This map has FIFTY floors and a
	// per-player floor high-water that gates class tiers, so "level" is a word
	// already spoken for — every other domain's "/ Lv" is read against a card,
	// but this one was read against the tower. The strings say CARRY and count
	// perks now; nothing about the mechanic moved.
	add_domain( "perkslots",  "PERK SLOTS",  "carry +1 more perk / Lv (base 4, cap 9)", 5, undefined, TOD_TIER_B );   // A -> B 2026-09-08 (user: "perk slots to B tier"). Weight 50 -> 100 and the SUPER/ULTIMATE slice x0.75 -> x1.00. Worth noting against its own history: the v16.80 RETIREMENT was argued from this card being too RARE to be worth a slot ("at 50 of ~650-780 per-class weight it surfaced about once in seven deals, so the cap read as a hard 4"). v17.3a brought it back; this halves that complaint directly by doubling how often it is offered
	// -- SKIRMISHER + SLASHER --
	// Move speed and nothing else since 2026-08-26 — the Lv5 TIRELESS rider was
	// removed (see the block comment where TOD_UPG_TIRELESS_SECS used to live).
	// Both classes that roll SPRINT now get exactly the same thing from it.
	add_domain( "sprint",     "SPRINT",      "move faster on foot / Lv",            10, array( "skirmisher", "slasher" ), TOD_TIER_S );   // v16: A -> S band (user: "sprint needs to be moved to S tier"). Desc carries NO number since v15 - the ladder is 5/4/3/3/3... via speed_pct_for_level
	// SPRINT FIRE (user 2026-08-21): promoted from a skirmisher INNATE to an
	// earned card — but still SKIRMISHER-ONLY (user, same day: "sprint fire is
	// only for smg class upgrades"). So it stays the SMG's identity; you just
	// have to earn it now instead of starting with it.
	// BINARY — the engine specialty is on/off, so max 1 (a SUPER/ULTIMATE roll
	// still just grants the single level).
	add_domain( "sprintfire", "SPRINT FIRE", "fire your weapon while sprinting",     1, array( "skirmisher" ), TOD_TIER_A );
	// SPRINT ARMOR (user 2026-08-23): -5%/Lv damage taken WHILE SPRINTING, 5
	// levels — the mobile class gets tougher in motion, never standing still.
	// Tier A: strong but conditional. Scope "class" below (it is damage
	// resistance, the one thing the user said survives a tier-up). The hook
	// lives in _tod_bosses' two damage lanes via sprint_armor_mult();
	// domain_id 32.
	// SKIRMISHER-ONLY since v14.11 (user 2026-08-30: "Remove sprint armor on
	// slasher" — with the DR cap above, the slasher's whole defensive stack is
	// deliberately shallower: max mitigation falls from x0.375 to x0.75).
	// SPRINT ARMOR REMOVED 2026-08-31 (user: "Retire sprint armor entirely").
	// Was: add_domain( "sprintarmor", "SPRINT ARMOR",
	//        "-5% damage taken while sprinting / Lv",
	//        5, array( "skirmisher" ), TOD_TIER_A );
	// Id 32 stays mapped in domain_id() and the Lua tables (key-keyed). Its
	// set_scope("sprintarmor","class") is gone with it. CARD_SLUG[32] and the
	// three i_tod_card_sprint_armor_* zone lines are removed on the CHAIN LUNGE
	// form; the PNGs stay in source_data.
	// sprint_armor_mult() SURVIVES as a permanent 1.0 — see its header. It is
	// called from two _tod_bosses damage lanes, and deleting it would mean
	// editing that file's damage chain on the eve of a publish build to remove a
	// call that is already a no-op. Not worth the risk; the header says so.
	// -- ASSAULT signatures --
	add_domain( "headshot",   "HEADSHOT",    "+12% headshot damage / Lv",            5, array( "assault" ), TOD_TIER_A );   // v9.45 nerf 4%->3%; RESTORED to 4% 2026-08-26; 4%->5% 2026-08-30 (user: assault buff); 5%->12% AND max 10->5 on 2026-09-08 (user: "change headshot upgrade to 12% per tier and only 5 tiers") — cap +50% -> +60%, but the domain now finishes in five picks. THE MAX LIVES HERE, the rate lives on TOD_UPG_HS_PER_LVL: move both or the card offers a level the ladder does not price
	// MAG SIZE = REAL twin variants now (user 2026-08-20: "no bottomless —
	// directly impact the gun's mag size"); 3 levels by the gun-data rule.
	// CLASS KEYS widened to the SKIRMISHER (review 2026-08-22): domain_available
	// is an AND of gun_keys and class_keys, so "assault"-only left the MP7's
	// m-ladder (T3 skirmisher) unreachable. gun_keys (set below) is what keeps
	// it off the MSMC/MP5 — every ASSAULT gun carries an m-ladder now (user
	// 2026-08-23), only the skirmisher half is partial.
	add_domain( "magsize",    "MAG SIZE",    "real mag +20/+40/+60%",                3, array( "assault" ), TOD_TIER_S );   // v9.44: skirmisher dropped (user: "Magsize we can remove from class"); +30 -> +20%/Lv 2026-09-01 (user: "mag size needs a nerf") — MAG_STEP in gen_tod_twins.js is the truth; this string, the Lua rows and the card art are its mirrors. BAND A -> S 2026-09-02 (user: "We need to move mag size upgrade to s tier"): weight 50 -> 20 and the SUPER/ULTIMATE slice x0.75 -> x0.50, same shape as SPRINT's v16 move. The LADDER IS UNTOUCHED, so no card re-bake — band is draw odds only, it is never drawn
	// GIANT SLAYER (v9.45, user 2026-08-23) — the assault class's answer to the
	// two things it cannot out-DPS with headshots: the Panzer and the Rogue
	// Protector wave. +8%/Lv against anything carrying the boss/elite triad,
	// five levels, so a maxed card is +40% on the only enemies with real HP.
	// Tier A, not S: it is worth nothing at all on the horde, which is the
	// literal definition of the A band ("strong but conditional").
	// Applied in BOTH boss-damage lanes — see boss_damage_bonus().
	add_domain( "bossdmg",    "GIANT SLAYER", "+12% damage to bosses and elites / Lv",  5, array( "assault" ), TOD_TIER_A );   // 3% -> 4% 2026-08-26; 4% -> 5% 2026-08-30 (user: assault buff); 5% -> 8% 2026-08-31; 8% -> 15% 2026-08-31 v15 (user: "boss damage should be 15% instead of 8%") = +75%; 15% -> 12% 2026-09-02 v16.50 (user: "nerf giant slayer to 12% each tier") = +60% at the Lv5 cap. Card art carries the number: re-bake owed per retune (docs/77)
	// BACK ARMOR (v9.45, user 2026-08-23) — the slow class gets the defence
	// the fast ones have. SPRINT ARMOR pays you for outrunning the horde; this
	// pays the class that cannot, for the hits it takes precisely because it
	// cannot turn around fast enough. -10%/Lv from a 140-degree rear arc, 3
	// levels. Scope "class" below — it is damage resistance, the one family
	// the user's tier rule says survives a promotion (with DR and SPRINT ARMOR).
	// HEAVY-ONLY since v14.11 (user 2026-08-30: "Remove back armor upgrade
	// from assault class"). The assault keeps no rear-arc defence — its
	// mitigation stack is DR alone now, which also un-does the "both slow
	// classes" symmetry above by design.
	add_domain( "backarmor",  "BACK ARMOR",  "take less damage from behind",            5, array( "heavy" ), TOD_TIER_A );   // v16: max 3 -> 5, ladder5() 10/18/24/28/32%
	// RESERVE (user 2026-08-22): the ammo-back-on-kills mechanic STAYS as-is
	// (a real capacity twin would blow the ~230-twin boot ceiling — see the
	// CHANGELOG v9.1 hold). Opened from assault-only to EVERY GUN CLASS at
	// max 5, with ASSAULT alone reaching 6 — the first per-class cap on this
	// map, see add_domain's bonus_class/bonus_max.
	// Slasher excluded: its primary is a knife with no reserve to refund.
	// DISPLAY NAME "SCAVENGER" (user 2026-08-22: "Reserve doesn't make sense").
	// It never increased your reserve CAPACITY — it refunds ammo off kills, so
	// the old name promised the wrong thing (and collided with the S-tier
	// capacity upgrade that got held on the twin ceiling). INTERNAL KEY STAYS
	// "reserve" on purpose: domain_id 8, CARD_SLUG[8] and every existing image
	// filename key off it, so a rename here costs zero wiring.
	// v18.88 rate (kills per round): a round every 2.8 / 2.3 / 2 / 1.8 / 1.6
	// primary kills, the assault-only Lv6 capstone every 1.4. Two moves the
	// same day off the v16.42 ladder (4 / 3 / 2.4 / 2 / 1.8 / 1.6): v18.86
	// raised the first three rungs only (user: Lv1 was "almost not
	// noticeable"), then v18.88 took another 0.2 kills off EVERY rung
	// ("Lets shift all by another 0.2"), moving the ceiling with them —
	// TOD_SCAV_KILLS10_* (tenths), read by scav_kills10. (v16.40 20/30/38/44/48/
	// 52 per 100 kills and v16.41 25/35/43/49/53/57 each lasted one build;
	// 2026-08-26 → v16.39 it was ONE round per 5 / 4 / 3 / 2 / 1 kills and 3
	// per 2 at the capstone — an accelerating ladder.)
	// The payout is CLASS PRIMARY ONLY since 2026-08-26; a sidearm kill pays
	// nothing and does not even feed the bank.
	add_domain( "reserve",    "SCAVENGER",   "primary kills bank ammo: a round per 2.8 / 2.3 / 2 / 1.8 / 1.6 kills; Lv6 1.4", 5, array( "skirmisher", "assault", "heavy" ), TOD_TIER_B, "assault", 6 );
	// -- HEAVY signatures --
	// MOBILITY RETIRED 2026-08-31, v15 (user: "We can remove mobility upgrade
	// from the lmg class but lets make its base speed 0.8 instead of 0.75").
	// Was: add_domain( "mobility", "MOBILITY", "+5% move speed / Lv",
	//                  5, array( "heavy" ), TOD_TIER_A );
	// Heavy was MOBILITY's only class, so unscoping it retires the domain
	// outright. Two things went with it and one did not:
	//   * class_speed_base() heavy 0.75 -> 0.80, so the floor rises even though
	//     the card is gone — a heavy who never draws a speed card is FASTER
	//     than before, which is the trade the user asked for.
	//   * LMG SPRINT (below) is the replacement: conditional, not passive.
	//   * Id 9 STAYS MAPPED in domain_id() and in the Lua DOMAIN/DETAIL tables.
	//     Those are KEY-keyed maps, so a stale entry is inert, and removing one
	//     risks disturbing ids the pause plates depend on. Same treatment as
	//     echo/regen/lunge/grinder/momentum/impact before it.
	// REMOVED WITH IT, on the IMPACT ROUNDS precedent (2026-08-31): CARD_SLUG[9]
	// and the three i_tod_card_mobility_* zone lines — an unreachable art slug
	// is dead weight in the .ff, where a Lua row costs nothing. The PNGs stay in
	// source_data.
	//
	// LMG SPRINT (domain 42, v15 — user 2026-08-31: "We also need an LMG upgrade
	// where when you run max speed for 1.5s you get a speed boost").
	// The heavy's signature movement card and the mirror of ADRENALINE: where the
	// skirmisher's burst is paid by KILLS, the heavy's is paid by COMMITMENT —
	// keep running in a straight line and the freight train winds up. Nothing at
	// a standstill; the full ladder after TOD_LMGS_ARM_MS of unbroken sprint.
	// Effect lives in lmg_sprint_bonus(); the latch is armed by the 20 Hz
	// watcher in _tod_uniques.gsc.
	// A-tier, matching ADRENALINE: strong, but conditional and capped.
	add_domain( "lmgsprint",  "FULL STEAM",  "sprint 0.8s without stopping for a speed boost", 5, array( "heavy" ), TOD_TIER_A );
	add_domain( "bulletfeed", "BULLET FEED", "reserve trickles into the mag: 1.0s -> 0.2s / round", 10, array( "heavy" ), TOD_TIER_A );
	// ECHO ROUNDS REMOVED 2026-08-23 (user: "we need to remove echo rounds").
	// Was: add_domain( "echo", "ECHO ROUNDS", "+10% / Lv chance to strike twice",
	//                  10, array( "heavy" ), TOD_TIER_S );
	// At Lv10 it was a FLAT DOUBLING of the heavy's damage (100% chance to strike
	// twice) stacked on top of DAMAGE's +120%, which is why the heavy's ceiling
	// ran away from the other three classes.
	// NOT deleted from domain_id() (_tod_upgrade_ui.gsc case "echo" -> 11) or
	// from the Lua DOMAIN[11] row, and that is deliberate: those two are a
	// KEY-KEYED map, not an ordered list, so leaving the entries costs nothing
	// and keeps every OTHER domain's id stable. Removing the add_domain call is
	// what takes it out of the pool — it can never be offered, rolled or held.
	// REGEN REMOVED 2026-08-30, v14.11 (user: "Remove regen upgrade from Heavy
	// class"). Was: add_domain( "regen", "REGEN", "+0.5%/s self-heal / Lv",
	//                           10, array( "heavy" ), TOD_TIER_A );
	// Same treatment as "echo"/"grinder"/"lunge": the add_domain call is what
	// puts a domain in the draw pool, so dropping this line removes it. Its
	// id 12 stays mapped in _tod_upgrade_ui::domain_id and in the Lua DOMAIN
	// table on purpose (key-keyed maps — disturbing them shifts ids the pause
	// plates depend on), and the card art stays zoned as dead .ff bytes. The
	// body-loop trickle hook is gone too. The heavy's sustain story is now
	// VITALITY + RECOVERY, registered directly below in its place (order in
	// this function is presentation only — ids live in _tod_upgrade_ui's
	// key-keyed domain_id map, where these two are 38 and 39).
	add_domain( "vitality",   "VITALITY",    "more max health",                      5, array( "heavy" ), TOD_TIER_S );   // v16: ladder5() as FLAT HP — 10/18/24/28/32 (user: "Flat HP")   // v14.11 — id 38; scope "class" set below
	add_domain( "recovery",   "RECOVERY",    "health regen starts sooner",           5, array( "heavy" ), TOD_TIER_A );   // v16: max 3 -> 5, ladder5() 10/18/24/28/32%   // v14.11 — id 39; see the define block for the emulation contract
	// PENETRATION (user 2026-08-21): REAL twin — walks the Stoner's
	// penetrateType small -> medium -> large. 2 levels by the gun-data rule.
	// HEAVY-ONLY AGAIN 2026-08-23: the AK-47 traded its p-ladder for r+m so the
	// whole ASSAULT class could roll RECOIL and MAG SIZE (see set_guns below).
	add_domain( "penetration", "PENETRATION", "shoot through more: small > medium > large", 2, array( "heavy" ), TOD_TIER_B );
	// THOR'S THUNDER (user 2026-08-21): every melee hit calls lightning down on
	// the victim — radius, damage and LOUDNESS all grow per level. Slasher.
	// TIER S -> B (user 2026-08-23: "can we make thors thunder common pull when
	// you have stormbreaker. This is the main power up and its a shame players
	// can get the storm breaker but never the actual power up for it").
	// Draw weight 20 -> 100, so it is offered 5x as often, and its SUPER/ULTIMATE
	// slice stops being halved (tier_rarity_factor 0.50 -> 1.00) — a thunder card
	// can now arrive worth +2 or +3 levels instead of almost always +1.
	// Safe to make common BECAUSE it is gun-bound: set_guns( "thunder",
	// array( "leviathan" ) ) below means it is only ever in the pool of a player
	// actually holding the Stormbreaker, so a common weighting cannot dilute any
	// other class's deals. It stays a 5-level ladder and still arrives at Lv1
	// free with the gun (register_gun's grant field) — what changes is that
	// levels 2-5 are now reachable inside one run.
	add_domain( "thunder",    "THOR'S THUNDER", "melee hits call down lightning on the 2-6 nearest zombies, bigger & more often / Lv", 5, array( "slasher" ), TOD_TIER_B );
	// -- SLASHER signatures --
	// LOG-SCALED (v10.13). The desc no longer quotes a per-level number because
	// there is no longer a per-level number — see leech_hp_for_level (4/6/8/9/10).
	// The card says STAGE, the pause menu discloses the actual amount for the
	// level you hold (tod_upgrade.lua DETAIL[13]) — the user's own split.
	add_domain( "leech",      "LEECH",       "melee kills heal you (+1 stage)",      5, array( "slasher" ), TOD_TIER_B );
	// CLEAVE v8.9 (user 2026-08-21 nerf): a CHANCE ladder, not a guaranteed
	// count — +33%/Lv for one extra target, every 3 levels banks it.
	// MAX 6 -> 3 (v14.11, user 2026-08-30: "Cleave can only go to tier 3 now.
	// It was 6 but this is too OP"): the ladder now ENDS at the first banked
	// extra — Lv3 = one guaranteed extra target, and the second block (Lv4-6,
	// +2 extras) is unreachable. The cb's arithmetic is untouched (int(3/3)=1
	// extra; the old `extra > 2` clamp is dead but harmless belt). Card art
	// says "33% CHANCE PER LEVEL" — level-agnostic, verified by opening the
	// PNG 2026-08-30, so no re-bake.
	add_domain( "cleave",     "CLEAVE",      "+33% / Lv chance to hit an extra zombie (max +1)", 3, array( "slasher" ), TOD_TIER_S );
	// -- TWIN domains (REAL gun-data changes via variant swap; 3 levels by
	//    rule — any upgrade touching gun data caps at 3) --
	// "TRULY fires faster" until 2026-09-11 (user: "We don't need the word truly
	// there. That's confusing. It just needs to be fire faster"). The word was
	// drawing a contrast with ECHO ROUNDS (id 11) — a proc that fired a second
	// bullet rather than raising the rate — and ECHO ROUNDS was REMOVED
	// 2026-08-23 (v9.35; see its own `// Was:` block ~70 lines above), so for
	// the 19 days since, the sentence has been distinguishing this domain from
	// nothing a player can see. The baked cards carried the same word and were
	// re-copied in the same pass (docs/134).
	//
	// THAT DATE WAS WRONG HERE FOR ONE AFTERNOON — written as v14.11 off
	// tod_upgrade.lua:272, whose REGEN note says "REMOVED v14.11 (2026-08-30,
	// with 11/22/30/34)" and sweeps id 11 in with a batch it predates by a
	// week. The SAME Lua file has it right at :558. v14.11 removed REGEN and
	// MOMENTUM; ECHO ROUNDS was already gone. Both Lua lines are corrected.
	add_domain( "firerate",   "FIRE RATE",   "fires faster (-10% fire time / Lv)",        3, array( "skirmisher" ), TOD_TIER_A );   // -8% -> -10% 2026-09-30 (user: "improve fire rate increase ... a bit"); FIRE_STEP in gen_tod_twins.js is the truth
	add_domain( "handling",   "HANDLING",    "faster reload, swap & ADS / Lv",            3, array( "skirmisher" ), TOD_TIER_B );
	// RECOIL v9.45 (user 2026-08-23: "recoil should be two levels only. 8% and
	// 16%"), BUFFED 2026-08-26 (user: "Recoil will go to 10% per level") to
	// -10/-20%. History: -25/-45/-65% (2026-08-19) -> halved to -10/-20/-30%
	// (2026-08-21) -> -8/-16% (v9.45) -> this. THE LEVEL COUNT IS A GENERATOR
	// FACT, not just a cap: gen_tod_twins.js AXIS.r must drop to levels 2 in the
	// same commit or the r3 forms it emits become dead weapon assets and a Lv3
	// that this cap can never reach. THE PERCENTAGES ARE A GENERATOR FACT TOO —
	// they live in RECOIL_STEP, so a change here without regenerating the twins
	// (and a FULL build, because that rewrites weapon GDT data) is display-only
	// and the card will lie.
	add_domain( "recoil",     "RECOIL",      "kick reduced -15/-30%",                     2, array( "assault" ), TOD_TIER_B );   // -10/-20 -> -15/-30 v16.50 (user 2026-09-02: "buff recoil to 15%"); the number lives in gen_tod_twins.js RECOIL_STEP (a twin domain: regen + FULL build), this string and the card art only mirror it (docs/78)
	// LOG-SCALED (v10.13). The swing-speed ladder lives in the GENERATOR
	// (tools/gen_tod_twins.js KNIFE_STEP, now 1/.90/.84/.80/.77/.74), so the
	// numbers here are display only — keep them in step with that table or the
	// card lies. Pause-menu actuals: tod_upgrade.lua DETAIL[18] (10/16/20/23/26%).
	add_domain( "knifespeed", "KNIFE SPEED", "faster melee swing (+1 stage)",             5, array( "slasher" ), TOD_TIER_A );
	// ATHLETE (v16, id 43, user 2026-09-01: "slide faster and jump higher ...
	// 5 tiers 10% slide speed each tier and 25% jump height increase each tier").
	// The WHOLE mechanic lives in _tod_athlete.gsc as per-player VELOCITY writes
	// (slide start speed x(1+0.10/Lv), jump z x sqrt(1+0.25/Lv), the jump edge
	// keeping exactly the pre-jump speed, and — v16.23, 2026-09-02 — AIR
	// STEERING: the velocity heading turns toward the movement stick at
	// 360 deg/s per level, speed unchanged). NOTHING of it touches the
	// move-speed scale — v16.1 (2026-09-01) retired the "+0.10 scale while
	// IsSliding" lane: SetMoveSpeedScale scales INPUT-driven movement, the
	// engine's slide is not input-driven, and two lanes for one number was a
	// double-count waiting to happen. This add_domain line is the domain's only
	// footprint in this file. Fills the mobility hole the retired chain lunge
	// (id 22) left in the kit.
	add_domain( "athlete",    "ATHLETE",     "+10% slide speed, +25% jump height, air steering and wall-run / Lv", 5, array( "slasher" ), TOD_TIER_A );
	// GUNSLINGER (v16.51, id 44, user 2026-09-02: "Slashers need an ability that
	// make their secondary do more boss and elite damage. 30% each tier up to 5
	// tiers. This will be B tier"). The mechanic is ONE line in
	// slasher_sidearm_boss_mult(): the slasher's class secondary vs the
	// boss/elite triad pays the class baseline x(1 + 0.30/Lv). Both boss lanes
	// (upgrade_damage_cb and _tod_bosses::rp_damage_feed) call that function,
	// so there is one number, TOD_UPG_GUNSLINGER_PER_LVL. Scope class (the
	// default) — the sidearm changes with the tier, the bonus follows the
	// player. Card art PENDING (docs/79): ships on the text fallbacks
	// (CARD_SLUG[44] unset, PAUSE_PLATE_MAX/TOD_UPG_PLATE_MAX stay 43) until the
	// four PNGs land.
	add_domain( "gunslinger", "GUNSLINGER",  "+30% sidearm damage to bosses and elites / Lv",   5, array( "slasher" ), TOD_TIER_B );
	// CHAIN LUNGE REMOVED 2026-08-24 (user: "we need to remove chain lunge from
	// the game. It doesnt work"). Same treatment as "echo" and "grinder": the
	// add_domain call is what puts a domain in the draw pool, so dropping this
	// line removes it. Its id 22 stays mapped in _tod_upgrade_ui::domain_id and
	// in the Lua DOMAIN table on purpose — those are key-keyed maps and
	// disturbing them would shift ids the pause plates depend on. _tod_lunge.gsc
	// is unlinked from the zone and the on_class_gun_kill hook is gone.
	// RUN AND GUN (user 2026-08-22: "shoot while you run, take up less bullets")
	// — id 23 in _tod_upgrade_ui::domain_id + tod_upgrade.lua DOMAIN. Mechanics
	// live in _tod_runandgun.gsc (it imports us for get_level; we never import
	// it). Skirmisher-only; tier B = the ammo-economy band (RESERVE, BULLET FEED).
	// v14.11 (user 2026-08-30): the card gained a DAMAGE half — same ladder,
	// same "moving" test, applied in unique_damage_mult. One card, one
	// condition, two payouts. v16.50 (user 2026-09-02): FIVE levels on a
	// stage table, 16/28/38/46/52% (was 20/35/50 over 3) — LOCKSTEP trio:
	// TOD_RNG_PCT_L* / TOD_UPG_RNG_DMG_L* / DETAIL[23]; max 5 here and in
	// DOMAIN[23]. Card art: the value line is generic (no number), so only the
	// pip row (3 -> 5) is owed — docs/76. Still tier B: it shares the ammo-economy band's
	// weight even though the damage half nudges it toward A — the user set the
	// rates, the band stays until they say otherwise. Card art re-bake PENDING
	// ("FREE SHOTS ON THE MOVE" is now half the story — see the v14.11 art
	// prompt doc); the desc + Lua rows carry the full text meanwhile.
	// v16.36: REQUIRES SPRINT FIRE — set_requires( "runandgun", "sprintfire" )
	// at the bottom of this function; the card never rolls before it is owned.
	add_domain( "runandgun",  "RUN AND GUN", "moving: 16/28/38/46/52% free shots, and that much more damage", 5, array( "skirmisher" ), TOD_TIER_B );
	// ---- CLASS TIER UNIQUES (docs/25 §9; ids 25..31 in _tod_upgrade_ui::domain_id
	//      + tod_upgrade.lua DOMAIN). Each is bound to ONE tier gun by gun_keys
	//      (set below) and resets on a tier-up like every gun domain. All
	//      script-side — zero weapon assets. Effects: unique_damage_mult /
	//      unique_on_hit (damage chain), on_class_gun_kill (kills),
	//      adren_bonus (move speed); inputs: _tod_uniques.gsc watchers.
	add_domain( "adrenaline", "ADRENALINE",       "multi-kills heal you and grant a 3s burst of speed and damage; each tier shortens the cooldown", 5, array( "skirmisher" ), TOD_TIER_A );   // v16: 5 tiers, +3%/tier, 3 kills in 1.5s, cd 20/18/16/14/12s; v17.67: the same % is also bullet damage during the burst; v17.85: and the same % of max health, healed on trigger
	// OVERDRIVE MOVED skirmisher/MP7 -> heavy/DEATH MACHINE (user 2026-08-23:
	// "overdrive should be an upgrade of the death machine. Remove meat grinder
	// and replace with overdrive"). OVERDRIVE and MEAT GRINDER were always the
	// same mechanic — "keep the trigger down, hit harder" — so the roster
	// carried a duplicate; the minigun is the natural home for it and the MP7
	// now needs an identity of its own.
	// This is also a real HEAVY NERF, which is the point: MEAT GRINDER capped at
	// +100% and a 150-round belt reached that cap trivially, so the heavy ran a
	// near-permanent x2 on top of the (now removed) ECHO ROUNDS x2. OVERDRIVE
	// tops out at +25%.
	add_domain( "overdrive",  "OVERDRIVE",        "hold the trigger: damage ramps up over 3.75s, 3s packed",                    5, array( "heavy" ), TOD_TIER_S );   // v16: max 3 -> 5, ramps to +5/10/15/20/25%
	// SECOND WIND — the MP5's unique since v14.11 (user 2026-08-30: "guve
	// second wind upgrade to the MP5 only instead of Mp7"; it was the MP7's
	// replacement unique from 2026-08-23). Gun-bound below.
	add_domain( "secondwind", "SECOND WIND",      "sprint to heal: 1% of your health per second per level",              5, array( "skirmisher" ), TOD_TIER_S );
	// MOMENTUM REMOVED 2026-08-30, v14.11 (user: "Remove momentum upgrade").
	// Was: add_domain( "momentum", "MOMENTUM",
	//        "damage scales with your speed: up to +5% per level while moving",
	//        5, array( "skirmisher" ), TOD_TIER_A );
	// Id 34 stays mapped in domain_id() and the Lua tables (key-keyed maps);
	// its card art stays zoned. The set_guns binding and the
	// unique_damage_mult hook are gone — RUN AND GUN's damage half is the
	// moving-damage card now, and SECOND WIND (above) takes the MP5 slot.
	// KILL RELOAD REMOVED 2026-09-01 (user asked "Didint we remove mag reload on
	// kill?" — it had NOT gone, IMPACT ROUNDS had — then: "Lets remove it. No one
	// likes it"). Same form as IMPACT ROUNDS below: id 27 stays mapped in
	// domain_id() and in the Lua tables (key-keyed, nothing renumbers, the id
	// cannot be reused); CARD_SLUG[27] and the three i_tod_card_kill_reload_*
	// zone lines are gone (an unreachable art slug is dead weight in the .ff, a
	// Lua row costs nothing; PNGs + GDT rows stay in source_data); the effect is
	// gone too (the block in unique_on_kill, killreload_kills_needed and the three
	// TOD_KILLRELOAD_KILLS_LV* defines) — a dead lane that still looks live is how
	// the next reader loses an hour. It was the assault's only B-band ammo card:
	// a magazine topped up FROM RESERVE every 55th/40th/30th kill (v9.43 frequency
	// ladder, buffed 2026-08-27 from 100/75/50 because nobody took it; still
	// nobody did). The assault pools go 12/12/13 -> 11/11/12 cards.
	// Was: add_domain( "killreload", "KILL RELOAD",
	//        "every 55th/40th/30th kill refills your magazine from reserve",
	//        3, array( "assault" ), TOD_TIER_B );
	// IMPACT ROUNDS REMOVED 2026-08-31 (user: "remove impact rounds from assault
	// class. Lets completely retire this upgrade. No one likes it").
	// Was: add_domain( "impact", "IMPACT ROUNDS",
	//        "3% of hits burst nearby zombies for 40% of the hit, per level",
	//        10, array( "assault" ), TOD_TIER_S );
	// Id 28 stays mapped in domain_id() and in the Lua tables (key-keyed maps),
	// so nothing renumbers. REMOVED WITH IT, unlike the MOMENTUM/REGEN form:
	// CARD_SLUG[28] and the three i_tod_card_impact_rounds_* zone lines, on the
	// CHAIN LUNGE precedent — an unreachable art slug is dead weight in the .ff,
	// where a Lua row costs nothing. The PNGs stay in source_data.
	// The effect is gone too (impact_splash + the block in unique_on_hit + the
	// four TOD_IMPACT_* defines): leaving it would have been inert, since
	// get_level returns 0 for an unrollable domain, but a dead lane that still
	// LOOKS live is how the next reader loses an hour.
	add_domain( "suppress",   "SUPPRESSING FIRE", "hits slow the horde 12/24/36% for 1.5s",                              3, array( "heavy" ),      TOD_TIER_A );
	// MEAT GRINDER REMOVED 2026-08-23 — superseded by OVERDRIVE on the same gun.
	// Was: add_domain( "grinder", "MEAT GRINDER",
	//        "keep firing, hit harder: +2/+3/+4% per 5 rounds, up to +50/75/100%",
	//        3, array( "heavy" ), TOD_TIER_S );
	// As with "echo", the key stays in domain_id() and in the Lua DOMAIN table
	// on purpose — those are key-keyed maps, so leaving the entries costs
	// nothing and keeps every other domain's id stable. Dropping the add_domain
	// is what removes it from the pool.
	add_domain( "drawcut",    "DRAW CUT",         "swings within 0.4s of a sprint deal +50/+100/+150%",                  3, array( "slasher" ),    TOD_TIER_B );
	// FORCED MARCH — the AK-47's unique (user 2026-08-24: "AK 47 will need a
	// speed boost. The only AR that gets a speed upgrade and it only goes 3
	// levels"). Assault had NO speed domain at all: SPRINT is skirmisher +
	// slasher, MOBILITY is heavy. Gun-bound to t9_ak47 below, so it is the
	// assault's T3 reward and not a class-wide one — and 5 levels of the shared
	// DIMINISHING ladder (5/4/3/3/3 points) cap it at +18, taking the assault from
	// 0.90 to 1.08 — ADDED to the scale, not multiplied: just past the
	// skirmisher's BASE, still short of a skirmisher who has spent anything on
	// SPRINT. It rides the SAME lane as SPRINT/MOBILITY in apply_move_speed()
	// rather than inventing a second speed multiplier — one owner for move speed.
	add_domain( "march",      "FORCED MARCH",     "move faster on foot / Lv",                                                 5, array( "assault" ),    TOD_TIER_A );   // max 3 -> 5 (user 2026-08-29); card text is LINEAR so no re-bake needed (domain-retune checklist), pips clamp at 3 by design

	// DISTRACTION (v14.59, user 2026-08-31: "Only assault will get these
	// upgrades. And they will persist through class upgrades. Also they will be
	// S tier." — RESHAPED v16.49, user 2026-09-02: "now it only is cymbal
	// monkeys and ... increases the max number of cymbal monkeys you can hold.
	// tier 1 is 1, tier 2 is 2, etc. And this goes up to 3.")
	//
	// ONE WEAPON, THE CYMBAL MONKEY, AND THE LEVEL IS THE CARRY CAP: Lv1 holds
	// 1, Lv2 holds 2, Lv3 holds 3. MAX AMMO adds exactly ONE at every level
	// (opted out of stock's refill). The whole weapon lane lives in
	// _tod_distraction.gsc; this is only the pool registration. The v14.59 Lv2
	// Li'l Arnies swap is GONE — nothing in the map hands out the octobomb now.
	//
	// max 3 LOCKSTEP: TOD_DISTRACT_MAX_CARRY (the module's safety ceiling, and
	// the monkey's own baked ammo ceiling), DOMAIN[41].max in tod_upgrade.lua,
	// and the THREE-pip card art. Linear (val(l) == l), so the per-rarity
	// number on the card (+1/+2/+3 carried) is honest at any level. max 3 also
	// means an ULTIMATE can be paid from Lv0, so this is no longer the deck's
	// unpromotable card (see guarantee_rarity).
	add_domain( "distraction", "DISTRACTION", "hold one more Cymbal Monkey per level (1 / 2 / 3)", 3, array( "assault" ), TOD_TIER_S );
	// TRAILBLAZER (v16.62, id 46, docs/80; user 2026-09-02: "Can the fire fx go on the
	// ground? And the higher tier the larger and more effective it is?"): the
	// skirmisher sprint leaves BURNING GROUND PATCHES behind it; any zombie that
	// runs through one burns for a fraction of the ROUND zombie health per
	// second (12..28%/Lv — the PhD-nova scaling rule, so it never one-shots
	// early and never falls off late). Per level it is LONGER (2..4 s), WIDER
	// (56..88 u radius; 1/2/3 fire patches across the trail) and HOTTER.
	// Mechanic: trail_loop() (end of file); the burn passes upgrade_damage_cb
	// on the tod_trail_hit mark. Class scope (the default) — survives
	// promotions; skirmisher only. Card art PENDING (docs/83): text fallbacks
	// (CARD_SLUG[46] unset, PAUSE_PLATE_MAX stays 44).
	add_domain( "trailblazer", "TRAILBLAZER", "sprinting leaves burning ground that slows everything on it and burns all but elites / Lv", 5, array( "skirmisher" ), TOD_TIER_A );   // v17.84: the elite rule is now part of the sentence (base slows elites, never burns them). NO CARD RE-BAKE IS OWED and the note that used to sit here saying one was is retired: it was written before the art shipped, and the shipped card (v16.65, docs/83) bakes the flavour line "FIRE FOLLOWS YOUR SPRINT" with no figures, per the generic-card-text rule. The pause DETAIL row is where every number lives.

	// -- RIOT SHIELD (v16.63, id 45, 2026-09-02 — user: "add a riot shield to the map.
	// It is for all classes and has 5 levels. Each level increasing the health
	// and decreasing the recharge. Once it breaks it needs to be recharged and
	// you will get it back automatically.") ---------------------------------
	// UNIVERSAL (class_keys undefined), max 5, scope "class" (the default: a
	// promotion never takes your shield). The LADDER is the user's table,
	// verbatim: 200 / 300 / 370 / 450 / 500 shield HP, recharge 4:00 / 3:30 /
	// 3:00 / 2:30 / 2:00. The numbers live in _tod_riotshield.gsc
	// (TOD_SHIELD_HP_L1..L5 / TOD_SHIELD_RECHARGE_L1..L5) and are MIRRORED in
	// tod_upgrade.lua's SHIELD_HP / SHIELD_RECHARGE tables — this desc and the
	// armory row are copies. Band A: it is survivability like DMG REDUCTION (A
	// since v16), not a run-winner on its own — a broken shield is gone for
	// minutes, and the first level is a 200 HP shield with a four-minute hole.
	// The whole weapon lane (give / break / recharge / re-give) is a RECONCILE
	// in _tod_riotshield.gsc, the DISTRACTION shape: the domain level is the
	// only input, so every path that writes a level (card, tier, spire, dev)
	// lands by construction. Pool registration ONLY here.
	add_domain( "riotshield", "RIOT SHIELD", "a riot shield that recharges after it breaks: 200/300/370/450/500 HP, 4:00 -> 2:00", 5, undefined, TOD_TIER_B );   // A -> B 2026-09-08 (user: "move riot shield to B tier for all classes"). It stays UNIVERSAL (class_keys undefined) — "for all classes" is the existing scope, not a change. Band is DRAW ODDS ONLY and is never drawn: weight 50 -> 100 (offered ~2x as often) and the SUPER/ULTIMATE slice x0.75 -> x1.00, so the copies you see also skew rarer. No card re-bake, no Lua row, no pause change

	// DEADSHOT — RETIRED v19.25 (2026-09-21, user: "we need to retire the
	// deadeye upgrade from the assault class. Its not liked or helpful").
	//
	// It shipped v16.64 as the assault's band-S always-ULTIMATE card: one level
	// of the engine's Deadshot head-snap aim assist (UseAlternateAimParams),
	// permanent, drawn in the perk bar, costing no perk slot. Two things made it
	// a bad card rather than a strong one, and both are worth remembering before
	// anyone proposes it again: UseAlternateAimParams is GAMEPAD-ONLY, so on
	// mouse and keyboard the rarest card in the assault deck did literally
	// nothing (memory `deadshot-aim-params-unauthorable`); and it was locked to
	// ULTIMATE, so it displaced the rarest draw an assault player gets.
	//
	// RETIRED WHOLE, per the standing rule: the add_domain call, its rarity
	// lock, the `_tod_deadshot.gsc|.csc` effect lane and its two scriptparsetree
	// lines, the card image and the perk-bar crest with their zone lines, the
	// Lua CARD_SLUG/CARD_ONE_IMAGE entries and the perk-bar mapping row are all
	// gone in this same commit. ID 47 STAYS MAPPED in domain_id() and the Lua
	// tables keep their keyed row — that is the retired-id rule, and it is what
	// stops the ids around it shifting under the pause plates.
	//
	// The PNGs and their GDT blocks are left on disk unzoned. They are not in
	// the `.ff` and cost neither download nor load RAM there, and the art is not
	// git-tracked, so deleting the blocks would make the images the only copy.
	// ---- THE MAGE (docs/114, 2026-09-07) -- REGISTERED BUT UNREACHABLE ------
	// Registered UNCONDITIONALLY on purpose. class_keys array( "mage" ) makes
	// these unreachable BY CONSTRUCTION -- domain_available()'s closing foreach
	// compares each key against player.tod_class, and no player can hold "mage"
	// while register_class( "mage" ) is behind TOD_MAGE_ENABLED -- so no flag is
	// needed here, and registering them means the ids, the Lua rows, the pause
	// row budget and the armory check are exercised by EVERY build from now
	// until the flip, instead of landing unproven on the day it turns on.
	// The one measurable cost is four zero entries per player from
	// player_upgrade_setup's zero-fill. Nothing reads them.
	//
	// KEYS ARE PREFIXED "mage_" DELIBERATELY. A domain keyed "fire" or "air"
	// would be un-greppable in a file that already contains sprintfire,
	// firerate, SPRINT FIRE and trail_fire -- the exact substring trap this
	// project has paid for before.
	//
	// THE MAX IS A LITERAL, NOT A CONSTANT. lint_tod_assets.js GATE C parses
	// add_domain with `,\s*\d+\s*,` for the max; a #define there makes the row
	// invisible to the pause-row capacity check.
	//
	// SIX LEVELS EACH on the elements (user 2026-09-07). Nothing in the deal,
	// sync or render path assumes a max from {1,2,3,5,10}: SCAVENGER already
	// reaches 6 through bonus_max and the pause pip run clamps at 10.
	//
	// ALL FOUR KEEP THE DEFAULT scope "class", so they SURVIVE a promotion --
	// the elements ARE the progression and resetting them would delete the
	// class. That costs nothing: domain_survives_tier returns true for the
	// default scope and sync_max already packs the survives bit.
	//
	// BANDS. AIR is B on the THOR'S THUNDER precedent -- it is gun-bound AND
	// class-bound, so a common weight cannot dilute another class's deals, and
	// it is the only thing a tier-1 mage can buy. FIRE and ICE are A: strong
	// but conditional, which is what an anti-family element is. ATTUNEMENT is A
	// because it multiplies all three at once.
	//
	// NO CARD_SLUG ENTRY, NO ZONE LINE, NO PLATE. All four ship on the LUI text
	// fallbacks -- the GUNSLINGER / TRAILBLAZER / DEADSHOT pattern. Ids 48-51
	// sit ABOVE PAUSE_PLATE_MAX 47, so the pause list draws them as TEXT ROWS
	// and no plate is owed either. See docs/115 for the art debt.
	// v18.30 (user 2026-09-07, the revamp): THE CARDS ARE PER STAFF. AIR BURST
	// (48) is RETIRED WHOLE -- there is no wind staff (its add_domain, slug,
	// three cards and plate r48 are gone; id 48 stays mapped in domain_id, the
	// retired-id rule). FIRE BLAST and ICE SHATTER keep their names -- the art
	// bakes them -- and are now the FIRE and ICE staff's own damage lines,
	// gated on holding the staff (set_tier_min 2 / 3 below). CHAIN LIGHTNING
	// (53) is the lightning staff's line, rollable from tier 1 and, like every
	// mage domain, scope "class" -- it PERSISTS through both promotions.
	add_domain( "mage_bolt",   "CHAIN LIGHTNING",   "50% base arc damage; +5% damage per Lv; +1 arc every 2 Lv; Dark: +1 arc", 10, array( "mage" ), TOD_TIER_B );
	add_domain( "mage_fire",   "FIRE BLAST",        "fire staff damage +15% per level, +90% at Lv6, and sets elites burning; Dark: +50%",                 6, array( "mage" ), TOD_TIER_A );
	add_domain( "mage_ice",    "ICE SHATTER",       "ice staff damage +15% per level, +90% at Lv6, and slows ELITES 20-35%; Dark: +50%",           6, array( "mage" ), TOD_TIER_A );
	// ATTUNEMENT -- MAX 5, and the 5 is argued rather than inherited. It is the
	// only card in the kit that scales the WHOLE class, so a sixth rung
	// compounds on top of three six-rung ladders. It rides the shared ladder5()
	// (10/18/24/28/32%), which is the shape of every other class-throughput
	// domain here (ADRENALINE, GUNSLINGER, VITALITY, RIOT SHIELD are all 5),
	// adds ZERO new constants, and its deceleration is what stops a maxed mage
	// reaching a zero cooldown. Not gun-bound: it is worth nothing until you
	// own an element, and AIR is rollable from tier 1.
	// ATTUNEMENT (51) RETIRED v18.41. After the v18.37 revamp it did one thing --
	// speed up HEALING AURA charge regen -- which is exactly what the HEALING AURA
	// card already buys. Its id stays mapped in domain_id (the retired-id rule);
	// only this registration goes.
	//
	// BLINK (id 55) takes its place in the deal: the mage AVOIDANCE move (user
	// 2026-09-08: "something for speed or avoidance, like a levitate or a quick
	// dash like a zap teleport"). A short teleport along your facing, on the
	// TACTICAL button -- free precisely because this class carries no grenades.
	add_domain( "mage_blink",  "BLINK",       "teleport a short way on tactical; further and more often / Lv; Dark: a third charge",       5, array( "mage" ), TOD_TIER_B );   // A -> B 2026-09-08 (user: "blink to B tier for mage"). Weight 50 -> 100 and the SUPER/ULTIMATE slice x0.75 -> x1.00. It lands in a 10-card tier-1 mage pool, so this is a bigger swing than the same move on a 13-card deck — see the mage note in docs/armory.html for the measured share

	// ARCHMAGE (id 54, user 2026-09-08: "We will call this max mana ability
	// archmage, with 6 levels and its S tier"). The MANA BAR's payoff: at a full
	// bar the aim button spends it and the mage becomes an ARCHMAGE.
	//
	// IT WORKS AT LEVEL 0 -- deliberately. The user specified the transformation
	// itself before this card existed ("it'll do double damage for 15 seconds"),
	// so level 0 IS that spec and the six levels deepen it. A mage who never
	// draws this card still has the ability; one who maxes it gets x3.0 for 25s.
	// Same shape as HEALING AURA, which is also usable before its card appears.
	//
	// S TIER because it is the only thing in the kit that changes what a fight
	// looks like -- it sits with DAMAGE and BOUNTY, not with the element cards.
	add_domain( "mage_arch",   "ARCHMAGE",    "archmage allows sprint fire; damage, speed, duration and mana gain improve / Lv; Dark: stronger, longer, faster",      6, array( "mage" ), TOD_TIER_S );
	add_domain( "mage_quickhands", "MYSTICAL HANDS", "all staff lowering and raising is 3x faster", 1, array( "mage" ), TOD_TIER_S );

	// HEALING AURA (id 52, user 2026-09-07: "a new move called healing aura ...
	// to support you and the team, whoever's near you"). NOT an element and so
	// NOT behind set_tier_min: the mage's DAMAGE REDUCTION
	// stops at 3, and the counterweight to that has to be draftable from the
	// first card, not from the second staff. Band A, six levels, matching the
	// elements — this is the fourth combat-stance move, not a minor perk.
	//
	// ITS LEVEL 6 IS THE REVIVE STAFF the user asked for the same day. Folding
	// that into an existing domain rather than minting a 53rd costs no id, no
	// card art and no clientfield, and prices it honestly at six picks.
	add_domain( "mage_heal",   "HEALING AURA", "team aura: 6.5-9.75 HP/s and 33-39% damage resistance by level; Dark: 13 HP/s, 42%",           6, array( "mage" ), TOD_TIER_A );

	// RAPID FLAME (v19.25, 2026-09-21) — user: "I want to add a firerate upgrade
	// card for the fire staff. 5 levels 10% each level."
	//
	// The fire staff's second knob, and its FIRST throughput one: FIRE BLAST
	// pays +15% damage a level and this pays -10% of the shot cooldown a level,
	// so a mage now chooses whether the fire staff hits harder or oftener. At
	// Lv5 the cooldown is 1.573 s -> 0.786 s, which is double the shots — read
	// the ladder table at TOD_MAGE_FIRE_RATE_PER_LV in _tod_mage_elements before
	// retuning either card, because the two multiply.
	//
	// set_tier_min 2 mirrors FIRE BLAST: both are about a staff a tier-1 mage
	// does not hold yet, and dealing a card for a weapon you cannot use is the
	// waste the tier gate exists to prevent.
	//
	// NO DARK RUNG. The dark pool doubles a domain's headline number and this one
	// is already the biggest per-level step on the class; a dark version would be
	// -15%/Lv and put the cooldown under half a second. It can be added later by
	// deleting the set_no_dark line and giving the reader a dark term — the point
	// is that it is a DECISION, not an oversight.
	//
	// ART: LANDED 2026-09-21 (docs/151). CARD_SLUG[57] is set, the three cards and
	// the r57 pause plate are zoned, and the plate ceiling moved 56 -> 57 in BOTH
	// readers. The paragraph below is the pre-drop state, kept as the record:
	// so the card and the pause row draw from the LUI text fallbacks until the
	// drop lands (docs/151). ⚠️ Do NOT add CARD_SLUG[57] before the images are
	// zoned — lint_tod_assets GATE A fails the build on a named-but-unzoned
	// image, and that gate is right: the alternative is a white square.
	add_domain( "mage_rate",   "RAPID FLAME",  "fire staff shoots 10% faster per level, twice as fast at Lv5",               5, array( "mage" ), TOD_TIER_A );

	// Thunder Smash (58): REMOVED FROM THE MAP 2026-09-23 (v19.39, user: "remove
	// the new upgrade we added for the slasher ... we might add it back later").
	// Id 58 stays mapped in domain_id() and the Lua; _tod_thunder_smash.gsc, its
	// zone lines, xanim and gmod7 attachments are all KEPT (the hammers' weapon
	// definitions reference the attachments). To restore: un-comment these five
	// lines and the init call + #using in _tod_main.gsc.
	// Was: add_domain( "thunder_smash", "THUNDER SMASH", "leap into a thunder slam; recharge 45/35/25s, elites take 2x/4x/6x round zombie health", 3, array( "slasher" ), TOD_TIER_A );
	// set_scope( "thunder_smash", "gun" );
	// set_guns( "thunder_smash", array( "leviathan" ) );
	// set_tier_min( "thunder_smash", 3 );
	// set_no_dark( "thunder_smash" );

	// ---- CLASS TIERS: WHAT A PROMOTION COSTS YOU ---------------------------
	// (docs/25 §2.3, §3. Rule REVERSED 2026-08-31, v15 — user: "We should remove
	// the idea of reseting upgrades unless its a gun specific upgrade. So if you
	// class tier upgrade your upgrades will stay. Things like draw cut since its
	// specific to a weapon would need to be removed.")
	//
	// THE DEFAULT IS NOW "class" (add_domain stamps it), i.e. PERSISTENCE IS THE
	// RULE AND RESETTING IS THE EXCEPTION. Everything below is the exception list.
	// Before v15 this was inverted and the list was the persisting ten; if you are
	// reading an older comment elsewhere that says "gun (default)", it is stale.
	//
	// WHAT A PROMOTION COSTS NOW — 13 domains, of which only 9 are ever really
	// losable (see the gun_keys note at the bottom of this block):
	//   6 REAL WEAPON-VARIANT LADDERS. These are not flavour — each is a literal
	//     per-gun stat axis the generator emitted (gen_tod_twins.js AXIS), so a
	//     level in one names a variant asset of ONE gun. Two independent reasons
	//     they must reset: a persisted level would be meaningless on a gun without
	//     that axis (the MP5/MP7 have no f-axis, the HK21 has no axes at all), and
	//     the pause menu would print a level that does nothing.
	//   7 GUN-BOUND UNIQUES. ⚠️ THIS IS THE LOAD-BEARING HALF. gun_keys gates what
	//     you can ROLL, never what FIRES — unique_damage_mult and unique_on_hit do
	//     no weapon test at all (see the comment on unique_damage_mult). So a
	//     persisted DRAW CUT would keep paying +150% on the STORMBREAKER, and
	//     SUPPRESSING FIRE would keep slowing the horde off the Death Machine.
	//     That is exactly the case the user named. DO NOT move one of these to
	//     "class" without first giving its effect a weapon test.
	//
	// KEEP tod_upgrade.lua's TIER_SAFE IN STEP. It is only the nil-fallback now
	// (sync_max packs a server-computed survives bit into every row), but a
	// fallback that disagrees with this list is a UI that lies when it is used.
	// ---- DMG REDUCTION: THE ONE DOMAIN WITH FOUR DIFFERENT CAPS (v17.3) ----
	// User 2026-09-03, on the finding that capping DR at 5 universally had left
	// the skirmisher, assault and slasher on IDENTICAL effective HP: "Yes lets
	// do 3, 5, 7, 10 as the max / Skirm, slash, assault, heavy".
	//
	// DR was the only mitigation three of the four classes had, so a shared cap
	// meant they differed by exactly nothing on defence — the fast, high-damage
	// classes were no squishier than the slow one. Now the cap IS the trade:
	//
	//   skirmisher 3   -15%   176.5 e-HP      the glass cannon (the mage too, below)
	//   slasher    5   -20%   187.5 e-HP
	//   assault    9   -28%   208.3 e-HP      (7 / -24% / 197.4 from v17.3 to v19.52)
	//   heavy     10   -30%   214.3 e-HP  (260.0 with VITALITY 5's 182 base)
	//
	// ASSAULT 9 (v19.52, user 2026-09-24: "make Assault go to 10 damage
	// reduction levels", then "it should go to 9 actually" before it was
	// played): one rung under the heavy, whose defensive edge is that rung plus
	// VITALITY (+32 HP) and RECOVERY, which the assault cannot roll. Nothing
	// else moves: the pause row reads its cap through domain_max -> sync_max,
	// the dark card is still +10 points on top (38% at the cap), and
	// dr_pct_for_level already ran to 10 for the heavy. LOCKSTEP by hand:
	// tod_upgrade.lua's cap comments and docs/armory.html's classMax table.
	//
	// NO LADDER WORK WAS NEEDED: dr_pct_for_level already ran past 5 on
	// TOD_UPG_DR_LN, a tail its own comment describes as "every level past 5,
	// if the cap ever rises". It diminishes 6/5/4/3 and then pays a flat 2 per
	// level, so the extra rungs are deliberately the cheapest ones.
	set_class_max( "dr", array( "skirmisher", 3, "slasher", 5, "assault", 9, "heavy", 10, "mage", 3 ) );
	// MAGE 3 (user 2026-09-07: "I want damage reduction to go to three"). It
	// lands in the glass-cannon band with the skirmisher, which is the right
	// company for a 0.85-speed caster whose whole kit is long-cooldown burst.
	// `pairs` is a FLAT class,max list -- see set_class_max's header for why --
	// so appending one pair is the whole edit, and domain_max() reads this
	// table BEFORE bonus_class, so sync_max and the pause row's own max follow
	// for free. The domain's own max stays 10, still the largest entry.
	//
	// DAMAGE NEEDS NO LINE, and that is verified rather than assumed (user:
	// "damage will go to ten like it always does"). add_domain registers
	// "damage" with max 10, class_keys undefined, and NO class_max and NO
	// bonus_class/bonus_max pair, so domain_max() falls through to d.max and
	// returns 10 for the mage. A set_class_max( "damage", array( "mage", 10 ) )
	// would be a no-op that reads like a live carve-out.
	// BOUNTY (max 10) and LUCK (max 5) likewise: both are class_keys undefined,
	// so domain_available returns true on its FIRST test before the player's
	// class is ever consulted. No edits.

	// ---- DARK UPGRADES: THE EXCEPTIONS (v17.10; LUCK joined 2026-09-05) ----
	// Everything else gets one. Six are the user's own call (2026-09-03/04);
	// four are blocked and cannot be un-blocked by a number.
	//
	set_no_dark( "sprintfire" );    // user: NONE
	set_no_dark( "secondwind" );    // user: NONE
	set_no_dark( "distraction" );   // user: NONE
	set_no_dark( "mage_quickhands" );
	set_no_dark( "mage_rate" );    // v19.25 — a DECISION, not an omission: see add_domain( "mage_rate" )
	set_no_dark( "suppress" );      // user: NONE (confirmed 2026-09-04)
	set_no_dark( "drawcut" );       // user: NONE (confirmed 2026-09-04); also Wakizashi-bound, a T3 slasher can never hold it
	set_no_dark( "luck" );          // user: NONE (2026-09-05, "Remove dark luck"; shipped x2.00 v17.10..v17.65)
	set_no_dark( "firerate" );      // blocked: weapon-variant ladder, +8 registrations, no per-player fire-time call exists
	set_no_dark( "penetration" );   // blocked: penetrateType enum already emits its top value "large" at Lv2
	set_no_dark( "perkslots" );     // blocked: no-op — perk_slot_limit() floors every spire player at the whole roster
	set_no_spire( "perkslots" );    // v19.38: and for the SAME reason the ordinary card is a no-op up there too — see set_no_spire
	// THE FOUR MAGE DOMAINS (docs/114) -- blocked while the effect lane does not
	// read has_dark(). A dark card whose lane does not read it is a card that
	// does nothing, silently: this repo's signature failure mode. TOD_DARK_ENABLED
	// is 1, so a maxed mage would otherwise be offered one in the spire.
	// SECOND, MECHANICAL REASON: lint_tod_assets.js GATE A demands an
	// i_tod_card_<slug>_dark zone line for every LIVE id that has a CARD_SLUG and
	// no set_no_dark. These four have no slug today, but the moment card art
	// lands the lint would ask for four more images nobody ordered.
	// When a dark rung is designed: delete the line, add the id to DARK_NONE's
	// complement in tod_upgrade.lua, and zone the _dark card.
	// 2026-09-09 (user, after the first Mage playtest: "There are no dark
	// upgrades for the mage"): the five set_no_dark lines that stood here are
	// GONE. Every mage domain except MYSTICAL HANDS now has a dark rung whose
	// effect lane reads has_dark(): CHAIN LIGHTNING +1 arc, FIRE BLAST / ICE
	// SHATTER +50 points on the card multiplier, HEALING AURA a seventh rung
	// (20 HP/s, 65%), ARCHMAGE +0.50 / +4 s / +15% speed, BLINK a third charge.
	// Card art: only HEALING AURA's dark card is baked; the other four wear the
	// composite DARK text card (DARK_TEXT_ONLY in tod_upgrade.lua) until the
	// docs/126 pack lands, and their red pause plates likewise (DARK_PLATE_NONE).

	// v17.10 — MAG SIZE, HANDLING, KNIFE SPEED and RECOIL are UNPARKED. Their
	// dark rungs are real weapon variants now: gen_tod_twins.js axisMaxUp puts
	// one on the PACKED form of each class TIER 3 gun only (AK-47 r3/m4, MP7 h4,
	// Leviathan k6), paid for by the Enfield and Krig 6 dropping the r axis.
	// Ledger 220 -> 198 against the 224 guard.

	set_scope( "magsize",    "gun" );
	set_scope( "firerate",   "gun" );
	set_scope( "handling",   "gun" );
	set_scope( "recoil",     "gun" );
	set_scope( "knifespeed", "gun" );
	set_scope( "penetration","gun" );
	// (v16.64's DEADSHOT rarity lock retired with the domain, v19.25.)
	set_rarity_lock( "mage_quickhands", 3 );
	set_scope( "adrenaline", "gun" );   // MP7  (skirmisher T3)
	set_scope( "overdrive",  "gun" );   // Death Machine (heavy T3)
	set_scope( "secondwind", "gun" );   // MP5  (skirmisher T2) — a REAL loss on the T2->T3 step
	set_scope( "suppress",   "gun" );   // HK21 (heavy T2)      — likewise
	set_scope( "drawcut",    "gun" );   // Wakizashi (slasher T2) — the user's own example
	set_scope( "march",      "gun" );   // AK-47 (assault T3)
	set_scope( "thunder",    "gun" );   // Leviathan (slasher T3)
	//
	// EVERYTHING ELSE PERSISTS, including several that used to reset: DAMAGE,
	// BOUNTY, GIANT SLAYER, BULLET FEED, RECOVERY, LEECH, CLEAVE, RUN AND GUN
	// and FULL STEAM (the new heavy domain; KILL RELOAD sat on this list until
	// its 2026-09-01 retirement). No set_scope call is
	// needed for any of them — that is the point of flipping the default.
	//
	// SCAVENGER WIDENED TO EVERY CLASS THAT ROLLS IT. The v14.13 line was
	// set_scope("reserve","class","assault") — a scope_class carve-out so it
	// survived for the assault ALONE. Under the v15 rule the domain is not
	// gun-specific for anybody, so the carve-out is gone and a skirmisher or heavy
	// keeps it through a promotion too. The 3-arg scope_class LANE still exists in
	// set_scope/domain_survives_tier and is still correct; it simply has no user
	// right now. Do not delete it.
	//
	// KNOWN CONSEQUENCE, flagged rather than discovered: a promotion is now nearly
	// free (a skirmisher's worst case falls from ~42 levels lost to <=11), so the
	// TIER card is close to strictly better than any other draw. That is the
	// user's call, made with the numbers in hand.
	// GUN_KEYS: a domain bound to specific gun STEMS — rollable only while the
	// player's current-tier gun is one of them. The twin ladders exist only on
	// the guns the generator built them for (a T2 SMG must never roll a dead
	// FIRE RATE card); THOR'S THUNDER is the STORMBREAKER's alone (the T3
	// slasher = the Leviathan port, stem "leviathan") — it leaves the knife's
	// pool now (user 2026-08-22 #5/#9). Add a stem here when a new tier gun
	// gets the same ladder (docs/25 §9 "reuse rule").
	// SMG CLASS UPDATE (user 2026-08-23, v9.44): FIRE RATE is the MSMC's alone
	// (the MP5's f-ladder is retired in gen_tod_twins.js). HANDLING is every
	// SMG — all three carry an h-ladder now and no gun outside the class does,
	// so its class_keys ( "skirmisher" ) is the exact gate and it needs NO
	// set_guns list (the RECOIL precedent: one less list to keep in sync).
	set_guns( "firerate",    array( "t6_msmc" ) );
	// MAG SIZE: every ASSAULT gun carries an m-ladder now (user 2026-08-23:
	// "mag size should be for all assault guns not just krig"). gun_keys stays
	// only because of the SKIRMISHER half — the MP7 has an m-ladder but the
	// MSMC and MP5 do not (they spend their axis budget on f/h), so dropping
	// the list would offer a dead card on two guns.
	// MAG SIZE: v9.44 the MP7 lost its m-ladder with the skirmisher class, so
	// the three assault guns are the only m-guns and class_keys ( "assault" )
	// gates it exactly — the old set_guns list existed only to keep it off the
	// MSMC/MP5 and is gone.
	// RECOIL: NO gun_keys any more (user 2026-08-23: "recoil upgrade should be
	// for all assault not just enfield and krig"). All three assault guns carry
	// an r-ladder and no gun outside the class does, so class_keys alone is the
	// exact gate. Re-add a list here only if a non-assault gun ever grows one.
	// PENETRATION IS HEAVY-ONLY AGAIN (2026-08-23): the AK-47 gave up its
	// p-ladder to pay for r+m. Three axes on one gun is 3 x 4 x 4 = 48 combos x
	// 2 forms = 96 registrations for the AK alone, which blows the boot ceiling
	// (see the LEDGER note in tools/gen_tod_twins.js). The AK loses nothing at
	// level 0 — every source GDT ships penetrateType "medium" and the p-ladder
	// STARTS at "small", so a p0 AK actually shot through LESS than every gun
	// with no ladder at all.
	// PENETRATION MOVED HK21 -> DEATH MACHINE (user 2026-08-24: "remove
	// penetration from HK21 and add to the death machine"). The p-ladder itself
	// moved with it in tools/gen_tod_twins.js and _tod_classes::register_gun —
	// this list must name exactly the guns that HAVE the axis, or the card rolls
	// on a gun with no variant to swap to.
	set_guns( "penetration", array( "t6_mk48", "t6_death_machine" ) );   // both p-ladder guns (the HK21 has no axes now)
	set_guns( "knifespeed",  array( "t9_me_baseballbat", "t9_me_wakizashi", "leviathan" ) );   // every k-ladder blade
	set_guns( "thunder",     array( "leviathan" ) );
	// the uniques: one gun each (the tier ladders' T2/T3 guns)
	// v14.11 (user 2026-08-30): MOMENTUM is gone and SECOND WIND moves
	// MP7 -> MP5, so each skirmisher rung is back to ONE unique — ADRENALINE
	// on the MP7 (T3), SECOND WIND on the MP5 (T2), and the MSMC keeps its
	// f-ladder as the T1 identity. (History: 2026-08-24 swapped ADRENALINE to
	// the MP7 and narrowed MOMENTUM to the MP5; the MP7 carried two uniques
	// from then until this pass.)
	set_guns( "adrenaline", array( "t6_mp7" ) );            // was t9_mp5 (2026-08-24)
	set_guns( "overdrive",  array( "t6_death_machine" ) );   // moved off the MP7 2026-08-23
	set_guns( "secondwind", array( "t9_mp5" ) );            // MP5 since v14.11 (was t6_mp7)
	// (KILL RELOAD and IMPACT ROUNDS were un-bound here on 2026-08-23 — class-
	// wide, not gun-bound, so no set_guns line for either. Both are RETIRED now:
	// IMPACT ROUNDS 2026-08-31, KILL RELOAD 2026-09-01. Nothing left to bind.)
	set_guns( "suppress",   array( "t5_hk21" ) );
	// (grinder binding removed 2026-08-23 with the domain — the Death Machine
	// now carries OVERDRIVE instead.)
	set_guns( "drawcut",    array( "t9_me_wakizashi" ) );
	set_guns( "march",      array( "t9_ak47" ) );   // FORCED MARCH is the AK-47's alone (user 2026-08-24)
	// THE MAGE'S ELEMENTS UNLOCK BY STAFF TIER (docs/114 B.3). AIR from the
	// draft, FIRE with the tipped staff, ICE with the upgraded tip -- a FLOOR,
	// so an element earned at tier 2 is still rollable at tier 3.
	//
	// NOT set_guns: gun_keys binds to the CURRENT stem and would REVOKE AIR on
	// promotion. gun_keys and scope are independent (d.gun_keys is read only by
	// domain_available, d.scope only by domain_survives_tier), but a floor is
	// the thing this design actually wants and set_tier_min is it.
	set_tier_min( "mage_fire", 2 );
	set_tier_min( "mage_ice",  3 );
	// RAPID FLAME follows FIRE BLAST: both are about a staff a tier-1 mage does not hold.
	set_tier_min( "mage_rate", 2 );
	// Staff swapping only becomes useful once the Mage owns a second staff.
	set_tier_min( "mage_quickhands", 2 );

	// PREREQUISITES (v16.36, user 2026-09-02): the skirmisher was drawing RUN
	// AND GUN — "shoot while you run, take up less bullets" — before it owned
	// SPRINT FIRE, the card that lets the gun fire mid-sprint at all. The
	// ammo/damage half still paid on a run-speed hip-fire, so the card was not
	// dead, but it read as a payout for a thing the player could not yet do.
	// Sequenced now: RUN AND GUN is dark until SPRINT FIRE is owned. Both are
	// scope "class" (they survive a promotion together), so a tier-up can never
	// strand a RUN AND GUN level behind a reset SPRINT FIRE. SPRINT FIRE is
	// registered ~200 lines above RUN AND GUN — set_requires checks that order.
	set_requires( "runandgun", "sprintfire" );
}

function add_domain( key, display, desc, max, class_keys, tier, bonus_class, bonus_max )
{
	d = SpawnStruct();
	d.key = key;
	d.display = display;
	d.desc = desc;
	d.max = max;
	d.class_keys = class_keys;   // undefined = shared (every class)
	d.tier = ( ( isdefined( tier ) ) ? tier : TOD_TIER_B );
	// PER-CLASS CAP (user 2026-08-22): ONE class may out-level the domain —
	// RESERVE caps at 5 but ASSAULT reaches 6. Both undefined = same cap for
	// everyone. Read through domain_max(player,d), NEVER d.max directly in a
	// per-player context, or the bonus class silently loses its extra level.
	d.bonus_class = bonus_class;
	d.bonus_max = bonus_max;
	// CLASS TIERS: scope + gun binding (set after registration, see above)
	// v15: PERSISTENCE IS THE DEFAULT. Was "gun" (reset on a tier promotion)
	// until 2026-08-31; the exception list lives in register_domains's CLASS
	// TIERS block. A new domain therefore SURVIVES a promotion unless you say
	// otherwise — if it is gun-specific, add a set_scope(key,"gun") line there.
	d.scope = "class";
	d.scope_class = undefined;   // v14.13 — scope "class" limited to ONE class (see set_scope)
	d.gun_keys = undefined;
	d.requires = undefined;      // v16.36 — key of a domain the player must OWN before this one can roll (see set_requires)
	d.tier_min = undefined;      // docs/114 -- class-tier FLOOR before this can roll (see set_tier_min)
	d.rarity_lock = undefined;   // v16.64 — when set, make_option forces the dealt card's rarity (frame + sting) to this value AFTER its headroom clamp (see set_rarity_lock). MYSTICAL HANDS is the only user since DEADSHOT was retired in v19.25
	level.tod_domains[ level.tod_domains.size ] = d;
}

function find_domain( key )
{
	for ( i = 0; i < level.tod_domains.size; i++ )
	{
		if ( level.tod_domains[ i ].key == key )
			return level.tod_domains[ i ];
	}
	return undefined;
}

// v14.13: the optional third arg limits a "class" scope to ONE class — the
// domain survives a tier promotion only for that class and resets like any
// gun domain for everyone else who rolls it. undefined = every class.
// GSC pads missing args with undefined, so the old 2-arg calls are unchanged.
function set_scope( key, scope, scope_class )
{
	d = find_domain( key );
	if ( isdefined( d ) )
	{
		d.scope = scope;
		d.scope_class = scope_class;
	}
}
// v16.64 (user 2026-09-02: "only way to pull it is an Ultimate card ... so we
// only need an Ultimate asset"). RARITY LOCK: every deal of `key` presents at
// rarity `r` — the ULTIMATE frame, sting and card art — regardless of the
// dice, the luck bar or the band. It is applied in make_option AFTER the
// band-honesty clamp, so a max-1 domain (DEADSHOT) keeps its +1 payout and
// still draws the ULTIMATE card; the TWO luck guarantees leave it alone by
// construction (both test `o.rarity >= want` BEFORE the headroom test, so a
// locked-3 card reads as "the dice already paid this slot" and is never
// redealt away — verified in guarantee_rarity / guarantee_both_ultimate).
// The draw FREQUENCY is not this: that is the band weight (DEADSHOT is S,
// the rarest draw).
function set_rarity_lock( key, r )
{
	d = find_domain( key );
	if ( isdefined( d ) )
		d.rarity_lock = r;
}

// =============================================================================
// DARK UPGRADES (v17.10, user 2026-09-03/04) — ONE step past a MAXED domain,
// dealt only in the Endless Spire. docs/92_dark_upgrades_design.md is the
// record; THE NUMBERS section there is the authority for every value.
//
// THREE THINGS THAT ARE NOT NEGOTIABLE, each paid for by a trap in this file:
//
// 1. A DARK UPGRADE IS **NOT A LEVEL**. It is a per-player BIT,
//    `player.tod_dark[ key ]`. Storing it as level max+1 breaks at six sites
//    that assume `o.levels == o.rarity`, and past those at ladder5's >= 5
//    clamp, leech_hp_for_level's `default: return 10`, overdrive_total_pct's
//    `if ( lvl > 5 ) lvl = 5`, speed_pct_for_level's deceleration (a level 11
//    SPRINT pays +0.03, a quarter of the intent) and twin_suffix's unclamped
//    concatenation — every one of which fails SILENTLY and in the player's
//    disfavour.
//
// 2. IT COSTS ZERO CLIENTFIELD BITS. The pool sits at 60 of the 61
//    PROVEN-BOOTED bits (see _tod_upgrade_ui::__init__), so a per-slot rarity
//    widening does not fit. Instead the 4-bit LEVEL field carries the sentinel
//    TOD_UPG_DARK_L — levels only ever reach 10, so 11..15 are free. This is
//    the TIER card's own idiom (id 24 packs (class-1)*2 + (tier-2) into the
//    same field), not a new trick.
//
// 3. TEN DOMAINS HAVE NO DARK STEP and are marked by set_no_dark() below.
//    Six are the user's call; four are blocked (three weapon-variant ladders
//    whose rung is an ASSET against a spent registration ledger, one saturated
//    engine enum, one no-op in the spire). The EXCEPTIONS are listed, not the
//    27 that qualify — same shape as the set_scope block.
// =============================================================================

// A domain with no dark step. Called for the exceptions only.
function set_no_dark( key )
{
	d = find_domain( key );
	if ( isdefined( d ) )
		d.no_dark = true;
}

// [v19.38] A domain that is NEVER DEALT once the party has ascended. For a card
// whose whole effect the spire already hands out for free: PERK SLOTS is the
// case — perk_slot_limit() floors every spire player at TOD_PERK_ROSTER and the
// ascension grant gives every perk, so a PERK SLOTS card dealt from a trial win
// (the spire's ONLY upgrade source) did nothing and cost the player the pick.
// Read by domain_available(), so every lane that asks "can this roll" (deals,
// the King max-out, domains-left, the deferred re-present) agrees. Levels
// already owned are untouched.
function set_no_spire( key )
{
	d = find_domain( key );
	if ( isdefined( d ) )
		d.no_spire = true;
}

// Does this player hold the dark upgrade for `key`?
function has_dark( player, key )
{
	if ( !isdefined( player ) || !isdefined( player.tod_dark ) )
		return false;
	return IS_TRUE( player.tod_dark[ key ] );
}

// self = player. The read every effect lane uses, so a lane never has to know
// how the bit is stored.
function dark( key )
{
	return has_dark( self, key );
}

// Every domain this player could take a dark upgrade on RIGHT NOW: available,
// MAXED, dark-capable, and not already dark.
//
// THE MAX TEST MUST GO THROUGH domain_max(), never d.max — DMG REDUCTION is
// per-class 3/5/7/10 and SCAVENGER gives the assault a 6th level, so d.max
// would report the wrong ceiling for exactly the domains most likely to be
// maxed first.
function dark_pool( player )
{
	pool = [];
	if ( !isdefined( level.tod_domains ) )
		return pool;

	for ( i = 0; i < level.tod_domains.size; i++ )
	{
		d = level.tod_domains[ i ];
		if ( IS_TRUE( d.no_dark ) )
			continue;
		if ( !domain_available( player, d ) )
			continue;
		if ( has_dark( player, d.key ) )
			continue;
		if ( get_level( player, d.key ) >= domain_max( player, d ) )
			pool[ pool.size ] = d;
	}
	return pool;
}

// Are dark cards live at all?
//
// ⚠️ TOD_DARK_ENABLED IS 0 WHILE THE FEATURE IS HALF-WIRED, AND THAT IS THE
// POINT. The deal path is complete — a dark card rolls, presents, and stores its
// bit correctly — but only the domains whose EFFECT LANE reads has_dark() are
// actually paid. Every other one would hand the player a card that does nothing,
// silently, which is this repo's signature failure mode and worth a hard gate
// rather than a note in a doc.
//
// FLIP IT TO 1 when the last effect lane lands. The wired list lives in one
// place only — grep has_dark( in this file — deliberately not duplicated here,
// because a hand-kept list of what is wired is exactly the thing that goes stale
// and then lies.
#define TOD_DARK_ENABLED 1
function dark_allowed()
{
	if ( !TOD_DARK_ENABLED )
		return false;
	return IS_TRUE( level.tod_spire_active );
}

// A dark card. Deliberately NOT built through make_option: every clamp in that
// function is keyed on headroom, and a dark card is by definition dealt on a
// domain with ZERO headroom — make_option would compute levels 0, the band
// clamp would demote the card to REGULAR, and apply_upgrade would refuse it.
function make_dark_option( player, domain )
{
	o = SpawnStruct();
	o.domain = domain.key;
	o.display = domain.display;
	o.desc = domain.desc;
	o.tier = domain.tier;
	o.dark = true;
	// The frame, sting and reveal HOLD all key off rarity, and a dark card
	// should build like an ultimate. The CARD ART is chosen by the sentinel
	// level, not by this.
	o.rarity = 3;
	o.rarity_name = "DARK UPGRADE";
	o.cur = get_level( player, domain.key );
	o.max = o.cur;
	o.levels = 0;   // it pays a BIT, not levels — see apply_upgrade's dark branch
	return o;
}

// THE GUARANTEE (user 2026-09-04): *"If you have an upgrade maxed then you must
// get the dark upgrade as an option after you defeat a trial and get upgrade
// rewards. If you have multiple it is possible to get both cards as dark
// upgrades but the only guarantee is that one must be a dark upgrade."*
//
// So: dark cards appear on the TRIAL deal only, `level.tod_dark_guarantee` is
// the latch that says this deal is one, and ONE slot is forced when the player
// has anything maxed. A second dark card is possible but never promised.
//
// SLOT CHOICE. The dark card takes the LEFT slot. Focus starts left and a
// timeout locks the focused card, which is exactly right here — a dark upgrade
// is a pure buff, so taking it by timeout can never cost the player anything
// (the reason the TIER card is pinned to the right slot is that a weapon swap
// CAN). It also means a tier card in the right slot survives untouched, and the
// player gets the choice the design wants: promotion, or go dark.
function deal_dark( player, opts )
{
	if ( !dark_allowed() || !IS_TRUE( level.tod_dark_guarantee ) )
		return opts;

	dpool = dark_pool( player );
	if ( dpool.size == 0 )
		return opts;

	// Accepts an EMPTY hand on purpose: the fully-maxed player reaches this with
	// nothing rolled at all (roll_options' pool.size == 0 path), and they are the
	// audience the whole feature exists for.
	if ( !isdefined( opts ) )
		opts = [];
	had_tier = ( isdefined( opts[ 1 ] ) && opts[ 1 ].domain == "tier" );

	// Weighted like any other draw so a rare band stays rare even here.
	first = weighted_draw( dpool );
	opts[ 0 ] = make_dark_option( player, dpool[ first ] );

	// A SECOND dark card — never over the tier card, which owns the right slot
	// when it is dealt at all.
	//
	// v17.46 (user 2026-09-04): *"when you have max upgrades only one Dark
	// Upgrade shows up. There should still be two cards ... in no situation
	// where you are eligible for two dark upgrades should you only get one."*
	// Two rules, both enforced here:
	//  (1) STRUCTURAL — if the right slot is EMPTY (the fully-maxed player, who
	//      arrives with no regular card at all) and a second dark exists, it is
	//      dealt, full stop. Before this, the 35 % roll left that player looking
	//      at a one-card panel two times in three.
	//  (2) THE USER'S RULE — eligible for two means dealt two: TOD_DARK_BOTH_PCT
	//      is 100 now, so a regular card in the right slot is replaced by the
	//      second dark card as well. The knob is kept as a knob; the empty-slot
	//      guarantee above does NOT depend on it, so lowering it again can never
	//      bring the one-card panel back.
	if ( dpool.size > 1 && !had_tier && ( !isdefined( opts[ 1 ] ) || RandomInt( 100 ) < TOD_DARK_BOTH_PCT ) )
	{
		rest = [];
		for ( i = 0; i < dpool.size; i++ )
		{
			if ( i == first )
				continue;
			rest[ rest.size ] = dpool[ i ];
		}
		opts[ 1 ] = make_dark_option( player, rest[ weighted_draw( rest ) ] );
	}
	return opts;
}

// v16.36 (user 2026-09-02: "you may not have the upgrade that allows shooting
// while running ... sequence it correct where you cant get those specific
// upgrades until you have [sprint fire]"). PREREQUISITE: `key` can only be
// ROLLED once the player owns at least one level of `prereq_key`. Read by
// domain_available, which is the single gate under eligible_pool (the deal and
// the luck-floor redeal), player_has_domains_left (the station's "anything to
// sell?" test) and the deferred-card revalidation — so the dependent card
// never appears anywhere before the prerequisite is owned.
//
// REGISTRATION ORDER IS LOAD-BEARING: the two grant-all lanes (dev_grant_maxed
// here, and _tod_spire's ascension grant) walk level.tod_domains in
// registration order through domain_available, so the prerequisite must be
// registered BEFORE its dependent or the grant skips the dependent on the one
// pass it gets. Checked here, at init, rather than trusted.
function set_requires( key, prereq_key )
{
	d = find_domain( key );
	p = find_domain( prereq_key );
	if ( !isdefined( d ) || !isdefined( p ) )
	{
		/# PrintLn( "^1[tod] set_requires( " + key + ", " + prereq_key + " ): unknown domain — prerequisite NOT installed" ); #/
		return;
	}
	if ( domain_index( prereq_key ) > domain_index( key ) )
	{
		/# PrintLn( "^1[tod] set_requires( " + key + ", " + prereq_key + " ): prerequisite registered AFTER its dependent — the grant-all lanes would skip " + key ); #/
	}
	d.requires = prereq_key;
}

// PUBLIC (docs/114) -- declare a CLASS-TIER FLOOR: this domain cannot be ROLLED
// until the player's class tier reaches `t`. Read only by domain_available,
// which is the single gate under eligible_pool, dark_pool,
// player_has_domains_left, dev_grant_maxed, king_max_player and
// solo_refresh_option -- so a floored card never appears anywhere before the
// tier that earns it, including a spire max-out.
//
// WHY THIS AND NOT set_guns. gun_keys gates on the CURRENT-TIER gun stem, so
// binding AIR to the tier-1 staff would make AIR UNROLLABLE the moment the
// player is promoted -- the exact opposite of "the ladder unlocks elements".
// This is a floor: at tier 2 you can still top AIR up.
//
// A floor can never strand a level. Levels persist across a promotion by
// default (the v15 rule) and tier() only ever rises.
//
// tod_classes::tier() returns 1 for a classless or un-promoted player, so an
// unset floor and a pre-draft player both fall through unchanged. INERT for
// every existing domain -- none calls this.
function set_tier_min( key, t )
{
	d = find_domain( key );
	if ( isdefined( d ) )
		d.tier_min = t;
}

function domain_index( key )
{
	for ( i = 0; i < level.tod_domains.size; i++ )
	{
		if ( level.tod_domains[ i ].key == key )
			return i;
	}
	return -1;
}

// v14.13 — does THIS player's copy of the domain survive a tier promotion?
// The single authority: tier_up's reset loop skips on it, and sync_max()
// stamps it into every pause-menu row so the reset badge can never disagree
// with what tier_up will actually do. A classless player (pre-draft) fails
// the scope_class test and keeps nothing — irrelevant in practice, since no
// promotion can happen before the draft.
function domain_survives_tier( player, d )
{
	if ( !isdefined( d.scope ) || d.scope != "class" )
		return false;
	if ( isdefined( d.scope_class ) )
		return ( isdefined( player.tod_class ) && player.tod_class == d.scope_class );
	return true;
}

// v14.13 — the max arg every tod_upg_sync send must carry: the per-player cap
// plus TOD_SYNC_SAFE_FLAG when the domain survives promotion FOR THIS PLAYER.
// One owner; _tod_spire's grant sync calls it too. Reset rows come out plain
// by construction (they are being reset precisely because survives is false).
function sync_max( player, d )
{
	mx = domain_max( player, d );
	if ( domain_survives_tier( player, d ) )
		mx += TOD_SYNC_SAFE_FLAG;
	if ( has_dark( player, d.key ) )
		mx += TOD_SYNC_DARK_FLAG;   // v17.10 — the pause row needs to print the DARK value, not the maxed one
	return mx;
}

function set_guns( key, stems )
{
	d = find_domain( key );
	if ( isdefined( d ) )
		d.gun_keys = stems;
}

// PUBLIC (v17.3) — declare a PER-CLASS level cap for a domain. Read by
// domain_max BEFORE bonus_class, and by sync_max, so the pause menu's own max
// readout follows it for free.
//
// `pairs` is a FLAT list — class, max, class, max — because GSC's array()
// builds a NUMERIC-INDEXED array, not a keyed map: array( "heavy", 10 ) is
// [0]="heavy", [1]=10, and a lookup by class name on it returns undefined.
// The keyed map is built here instead, which keeps the call site one line and
// puts the one place that could get this wrong behind a function.
//
// The domain's own `max` stays the CEILING across all classes — the
// All-domains table and any player-less caller read that — so keep it equal to
// the largest entry here or the registry will under-report the domain.
function set_class_max( key, pairs )
{
	d = find_domain( key );
	if ( !isdefined( d ) || !isdefined( pairs ) )
		return;
	caps = [];
	for ( i = 0; i + 1 < pairs.size; i += 2 )
		caps[ pairs[ i ] ] = pairs[ i + 1 ];
	d.class_max = caps;
}

// SCAVENGER feedback clink. self = the player being paid. Throttled per
// player (see TOD_SCAV_SND_GAP_MS) so a high-level assault does not machine-gun
// it. PlayLocalSound = the grabber hears it only — never the whole lobby.
function scavenger_feedback()
{
	if ( !isdefined( self ) || !isplayer( self ) )
		return;
	now = GetTime();
	if ( isdefined( self.tod_scav_snd_next ) && now < self.tod_scav_snd_next )
		return;
	self.tod_scav_snd_next = now + TOD_SCAV_SND_GAP_MS;
	self PlayLocalSound( "tod_scavenger" );
}

// (killreload_kills_needed() lived here until KILL RELOAD was retired 2026-09-01.)

// The cap for THIS player (honours a domain's per-class bonus).
function domain_max( player, d )
{
	// PER-CLASS CAP TABLE (v17.3) — checked FIRST, and it is the general form
	// the bonus_class/bonus_max pair below could never express: that lane maps
	// ONE alternate max onto a set of classes, so it cannot say
	// "3 / 5 / 7 / 10, one per class". DMG REDUCTION is the first domain that
	// needs four different numbers; set_class_max() is how a domain declares
	// them. A class absent from the table falls through to the rules below, so
	// a partial table is legal.
	if ( isdefined( d.class_max ) && isdefined( player.tod_class )
	  && isdefined( d.class_max[ player.tod_class ] ) )
		return d.class_max[ player.tod_class ];

	// bonus_class is EITHER a single key OR an array of keys (v14.33 — the DR
	// cap now covers slasher AND skirmisher). Array form first; a bare string
	// still works, which is what SCAVENGER's "assault" uses.
	if ( isdefined( d.bonus_class ) && isdefined( d.bonus_max ) && isdefined( player.tod_class ) )
	{
		if ( IsArray( d.bonus_class ) )
		{
			foreach ( c in d.bonus_class )
			{
				if ( player.tod_class == c )
					return d.bonus_max;
			}
		}
		else if ( player.tod_class == d.bonus_class )
			return d.bonus_max;
	}
	return d.max;
}

// Can this player roll this domain right now?
function domain_available( player, d )
{
	// GUN-BOUND domains (twin ladders, per-gun uniques, Thor's Thunder): only
	// while the player's current-tier gun is one of the listed stems.
	if ( isdefined( d.gun_keys ) )
	{
		stem = tod_classes::gun_stem( player );
		if ( !isdefined( stem ) )
			return false;
		ok = false;
		foreach ( s in d.gun_keys )
		{
			if ( s == stem )
				ok = true;
		}
		if ( !ok )
			return false;
	}
	// PREREQUISITE (v16.36): not rollable until the player OWNS the domain it
	// builds on — RUN AND GUN after SPRINT FIRE (see set_requires). Checked
	// before the class test so a dependent domain is dark for every lane that
	// asks this question, not just the deal.
	if ( isdefined( d.requires ) && get_level( player, d.requires ) <= 0 )
		return false;
	// CLASS-TIER FLOOR (docs/114) -- set_requires' sibling. Checked here, beside
	// the prerequisite, so a floored domain is dark for EVERY lane that asks
	// this question and not just the deal.
	if ( isdefined( d.tier_min ) && tod_classes::tier( player ) < d.tier_min )
		return false;
	// SPIRE-DEAD (v19.38, set_no_spire): the spire already gives this for free.
	if ( IS_TRUE( d.no_spire ) && IS_TRUE( level.tod_spire_active ) )
		return false;
	if ( !isdefined( d.class_keys ) )
		return true;
	if ( !isdefined( player.tod_class ) )
		return false;
	foreach ( k in d.class_keys )
	{
		if ( k == player.tod_class )
			return true;
	}
	return false;
}

// ---------------------------------------------------------------------------
// Per-player state
// ---------------------------------------------------------------------------

// self = player (on_spawned; fields persist across respawns, only init once)
function player_upgrade_setup()
{
	// v16: no life ever starts holding FULL STEAM's wind loop or its screen wash.
	// This runs per SPAWN (unlike the tod_levels init below, which is guarded
	// init-once on purpose), which is exactly what a per-life audio reset needs.
	self lmg_steam_silence();

	self thread ensure_upgrade_list();

	// THE TIER GATE TOASTS (2026-09-02) — once per player; the thread endons
	// only on disconnect, so it rides through every respawn.
	if ( !IS_TRUE( self.tod_tier_toasts_on ) )
	{
		self.tod_tier_toasts_on = true;
		self thread tier_gate_toasts();
	}

	if ( !isdefined( self.tod_levels ) )
	{
		self.tod_levels = [];
		for ( i = 0; i < level.tod_domains.size; i++ )
			self.tod_levels[ level.tod_domains[ i ].key ] = 0;
		// (the LUCK BAR — player.tod_luck_bar — is owned by _tod_luck.gsc)
	}
	if ( !isdefined( self.tod_tier ) )
		self.tod_tier = 1;   // CLASS TIERS: everyone starts at tier 1 (survives respawns like tod_levels)

	// (mag_watcher REMOVED 2026-08-20 — MAG SIZE is real twin variants now,
	// no virtual pool; the todMagBonus clientfield stays registered but 0.)

	// BASE 150 HP (user 2026-08-20) + VITALITY (v14.11: +10/Lv rides the same
	// floor). Stock jugg is ADDITIVE on the current maxhealth and restores
	// preMaxHealth on loss (_zm_perks.gsc:801/848), so raising the base
	// BEFORE jugg stacks cleanly (jugg = floor + bonus). The body loop below
	// maintains it against stock 100-resets; only the spawn grant heals the
	// difference (the maintain never free-heals) — so a respawning heavy
	// comes back with their vitality HP filled, same doctrine as the base 150.
	// (tod_levels is initialised above, so get_level is safe here.)
	want = self max_hp_floor();
	if ( self.maxhealth < want )
	{
		self.maxhealth = want;
		self SetMaxHealth( want );
		if ( self.health < want )
			self.health = want;
	}

	if ( !IS_TRUE( self.tod_body_systems_on ) )
	{
		self.tod_body_systems_on = true;
		self thread body_systems_loop();
		self thread recovery_loop();          // RECOVERY (v14.11) — its own 0.1s cadence
		self thread recovery_damage_watch();  // exact last-hit stamps for it
		// v14.16 — runs for EVERY player, not just RECOVERY holders: VITALITY's
		// purchase heal desyncs the same vignette. See the block comment.
		self thread health_overlay_sync();
		self thread trail_loop();             // TRAILBLAZER (v16.62) — its own 0.1 s cadence; inert until the domain is owned
		// (tireless_spawn_watch removed 2026-08-26 with TIRELESS itself.)
	}

	// move scale must be re-applied on every spawn (it resets)
	self apply_move_speed();
}

// ---------------------------------------------------------------------------
// self = player. THE ONE OWNER of "what should this player's max HP be at
// minimum, right now" (v14.28) — the spawn grant and the body-loop maintain
// both read it; never re-spell the sum at a call site (the jugg term is the
// part a copy silently drops).
//
//   150 base + 10 x VITALITY level + (active jugg ? its bonus : 0)
//
// THE JUGG TERM IS THE v14.28 FIX (user: "I have 210 but level 3 vitality...
// went back down to 200"): stock's health_reboot rebuilds max from
// player_base_health on every round flip / revive / jugg loss, discarding
// vitality. A jugg-blind floor (180 at Lv3) sat BELOW the rebuilt 200, so the
// raise-only maintain was satisfied while 80 real HP were missing. Counting
// the active jugg makes the floor 280 there, and the maintain repairs within
// a second of any stock clobber. Entry main() pins player_base_health to 150
// (v14.28, lockstep with TOD_UPG_BASE_HP) so the reboot itself now lands at
// 250 with jugg — the floor covers what stock cannot know about: VITALITY.
//
// HasPerk only — a PAUSED jugg (power down, machine moved) reads false here,
// which is correct: stock restored the pre-jugg max on pause, and raise-only
// means resume's re-add is never fought. The bonus rides the zombie_var so a
// future jugg retune has one owner too (isdefined-guarded: the var is seeded
// by _zm_perk_juggernaut's autexec init, which beats every caller of this).
function max_hp_floor()
{
	floor = TOD_UPG_BASE_HP + ladder5( get_level( self, "vitality" ) );
	// DARK UPGRADE (v17.10): +25 flat HP. Applied HERE and not inside ladder5(),
	// which is shared with RECOVERY and BACK ARMOR -- moving the table would drag
	// both of those with it, and BACK ARMOR multiplies with DR.
	if ( has_dark( self, "vitality" ) )
		floor += TOD_DARK_VITALITY_HP;
	if ( self HasPerk( "specialty_armorvest" ) )   // PERK_JUGGERNOG (_zm_perks.gsh — not #insert'd here)
	{
		jugg = 100;
		if ( isdefined( level.zombie_vars ) && isdefined( level.zombie_vars[ "zombie_perk_juggernaut_health" ] ) )
			jugg = level.zombie_vars[ "zombie_perk_juggernaut_health" ];
		floor += jugg;
	}
	return floor;
}

// ---------------------------------------------------------------------------
// BODY DOMAINS (persist across class switches — trained on the player):
// SPRINT/MOBILITY (move scale), HEALTH (max HP maintain,
// jugg-aware), REGEN (trickle heal), BULLET FEED (reserve -> mag). 1s cadence.
// ---------------------------------------------------------------------------

function apply_move_speed()
{
	// Menu soft-freeze pins movement (see menu_freeze below).
	if ( IS_TRUE( self.tod_menu_frozen ) )
	{
		self SetMoveSpeedScale( 0.001 );
		return;
	}
	// THIS SUM IS SPRINT + FORCED MARCH ONLY, and that pair is what "summing the
	// levels is safe" refers to: SPRINT is skirmisher/slasher, FORCED MARCH is
	// assault, so no player can hold both and adding their levels can never
	// double-count. The other speed sources are SEPARATE TERMS in the scale
	// expression below, each with its own gate — LMG SPRINT (heavy,
	// conditional) and ADRENALINE (skirmisher, timed burst).
	// ATHLETE (slasher) is NOT in this expression at all since v16.1: it is a
	// pure VELOCITY mechanic in _tod_athlete.gsc (slide start speed, jump z, the
	// slide-jump carry) and never touches the scale. It used to add +0.10/Lv
	// here while IsSliding(); that lane was retired because the engine's slide
	// is not input-driven, so a scale term could not honestly be "+10% slide
	// speed" — see the header of _tod_athlete.gsc.
	//
	// DO NOT ADD A DOMAIN TO THIS SUM WITHOUT CHECKING CLASS OVERLAP. The old
	// wording here said the speed domains were per-class "so no player can hold
	// two", which was true when only SPRINT/MARCH/MOBILITY existed and is FALSE
	// now: a slasher can hold SPRINT and ATHLETE at once. Nothing is broken by
	// that — ATHLETE never enters this sum — but the sentence was one edit away
	// from inviting someone to fold a same-class domain in here on the strength
	// of a guarantee that had quietly stopped holding.
	// (MOBILITY was the heavy's entry here until v15; it is retired, replaced by
	// the conditional LMG SPRINT below. get_level on a retired domain returns 0,
	// so dropping it from this sum is cosmetic — but a term that can only ever
	// be zero is how the next reader loses an hour.)
	//
	// ⚠️ SPEED BONUSES ARE ADDED TO THE SCALE, NOT MULTIPLIED INTO IT (v15,
	// 2026-08-31 — user: "if lmg has 80 speed then should boost up to .85 if
	// they get 5% it shouldnt be 5% of 0.8"). So "+5%" means +0.05 of SCALE, a
	// flat five points, identical for every class. It used to be
	// base * (1 + bonus), which paid the fast classes more for the same card:
	// +5% was worth 0.055 to a skirmisher and 0.0375 to a heavy, quietly
	// widening the gap the speed cards are supposed to help close.
	//
	// CEILINGS UNDER THIS MODEL (base + max ladder), for anyone recomputing
	// balance: heavy 0.80 + 0.216 = 1.016 while rolling (FULL STEAM = ladder x TOD_LMGS_MULT, v16.8) · assault 0.90 + 0.18 =
	// 1.08 · slasher 1.00 + 0.33 = 1.33 · skirmisher 1.10 + 0.33 = 1.43, plus
	// ADRENALINE's burst on top of that.
	lvl = get_level( self, "sprint" ) + get_level( self, "march" );
	scale = self class_speed_base()
	      + speed_pct_for_level( lvl )
	      + self dark_speed_bonus()
	      + self lmg_sprint_bonus()
	      + self adren_bonus()
	      + self arch_speed_bonus();
	// (the boss zap slow was removed 2026-08-20 — no player stuns)
	self SetMoveSpeedScale( scale );
}

// PUBLIC — the MOVE SPEED LADDER (v15 item 25). Cumulative bonus for `lvl`
// levels of any speed domain, as an ADDITIVE offset to the move-speed scale.
//
// Increments are 5, 4, 3, 3, 3, ... so the totals run
//   Lv1 .05 · Lv2 .09 · Lv3 .12 · Lv4 .15 · Lv5 .18 · ... · Lv10 .33
// A closed form rather than a table so it cannot go out of range: SPRINT caps
// at 10 today but nothing here breaks if a domain is ever given more.
//
// THE ONE OWNER. Every speed domain routes through this — do not reintroduce a
// per-level constant, and do not let a caller multiply by it.
// (ONE sanctioned exception, v16.8: lmg_sprint_bonus() multiplies the result by
// TOD_LMGS_MULT - FULL STEAM's own +20%, a user order - mirrored by
// fullSteamPct() in tod_upgrade.lua. SPRINT and FORCED MARCH stay raw.)
function speed_pct_for_level( lvl )
{
	if ( !isdefined( lvl ) || lvl <= 0 )
		return 0;
	if ( lvl == 1 )
		return TOD_UPG_SPEED_L1;
	return TOD_UPG_SPEED_L1 + TOD_UPG_SPEED_L2 + ( lvl - 2 ) * TOD_UPG_SPEED_LN;
}

// PUBLIC — THE SHARED 5-TIER LADDER (v16). Cumulative value at `lvl`:
//   Lv1 10 · Lv2 18 · Lv3 24 · Lv4 28 · Lv5 32
// Unit-agnostic (see the #define block): percent for RECOVERY and BACK ARMOR,
// FLAT HP for VITALITY. THE ONE OWNER — do not re-spell the table.
function ladder5( lvl )
{
	if ( !isdefined( lvl ) || lvl <= 0 ) return 0;
	if ( lvl == 1 ) return TOD_LADDER5_L1;
	if ( lvl == 2 ) return TOD_LADDER5_L2;
	if ( lvl == 3 ) return TOD_LADDER5_L3;
	if ( lvl == 4 ) return TOD_LADDER5_L4;
	return TOD_LADDER5_L5;
}

// LMG SPRINT (domain 42, v15 item 24 — user 2026-08-31: "an LMG upgrade where
// when you run max speed for 1.5s you get a speed boost"). The heavy's
// replacement for MOBILITY: nothing at a standstill, the full ladder once the
// party's slowest class has been running flat out for TOD_LMGS_ARM_MS.
//
// Shaped exactly like adren_bonus() — a level lookup plus a latch this function
// only READS. The latch is armed by the 20 Hz sustained-sprint watcher in
// _tod_uniques.gsc, which also edge-calls apply_move_speed() so the boost
// arrives on the frame it is earned rather than on the next 1 s body tick.
//
// FREIGHT-TRAIN IDENTITY, deliberately: the heavy is the slowest class from a
// standstill (0.80) and one of the fastest once rolling (1.016 at Lv5 since v16.8 - the ladder x TOD_LMGS_MULT). Losing
// sprint — a corner, a hit, a reload-strafe — drops the whole bonus and the
// 1.5 s clock restarts.
// (ATHLETE's athlete_slide_bonus() + TOD_ATH_SLIDE_PER_LV lived here from v16
// until v16.1, 2026-09-01. The slide-speed number now lives in _tod_athlete.gsc
// as a velocity multiply on the slide-start edge, and the self.tod_athlete_sliding
// flag no longer exists — nothing in this file should read it.)

// DARK UPGRADES (v17.10) — SPRINT and FORCED MARCH, as a SEPARATE ADDEND rather
// than extra levels in the sum above. That is not a style choice: this ladder
// DECELERATES (TOD_UPG_SPEED_LN is 0.03 against L1's 0.05), so a dark step
// expressed as levels would pay a fraction of its intent and would do it
// silently. Points of SCALE, matching the model documented above.
//
// The two can never both be held — SPRINT is skirmisher/slasher, FORCED MARCH is
// assault — but they are summed rather than branched so that stops being a
// correctness assumption the next class change could quietly break.
// ARCHMAGE (mage) — the demigod form moves faster while it runs. The value is
// LATCHED onto the player by _tod_mage_elements::demigod_run at transformation
// time and cleared when the form ends; that module edge-calls apply_move_speed
// at both ends, so this is read exactly when it changes and never polled.
// Reading a plain field rather than the mage's constants is deliberate: this
// module must not #using _tod_mage_elements (that module imports THIS one, and
// the cycle is what the guarded level pointers exist to avoid).
function arch_speed_bonus()
{
	if ( isdefined( self.tod_mage_demigod_speed ) )
		return self.tod_mage_demigod_speed;
	return 0;
}

function dark_speed_bonus()
{
	b = 0;
	if ( has_dark( self, "sprint" ) )
		b += TOD_DARK_SPEED_ADD;    // +33% -> +48% of move scale
	if ( has_dark( self, "march" ) )
		b += TOD_DARK_MARCH_ADD;    // +18% -> +35%
	return b;
}

function lmg_sprint_bonus()
{
	lvl = get_level( self, "lmgsprint" );
	if ( lvl <= 0 )
		return 0;
	if ( !isdefined( self.tod_lmgs_hot ) || !IS_TRUE( self.tod_lmgs_hot ) )
		return 0;
	bonus = speed_pct_for_level( lvl ) * TOD_LMGS_MULT;   // v16.8: the shared ladder x1.2 (see the #define)
	if ( has_dark( self, "lmgsprint" ) )
		bonus += TOD_DARK_LMGS_ADD;   // DARK: +21.6% -> +41.6% of move scale while the latch is hot
	return bonus;
}

// PUBLIC — FULL STEAM's FEEDBACK: the blue screen wash + the trigger sound.
// self = player. `on` = the latch state the 20 Hz watcher just flipped to.
// Reached through level.tod_lmgs_fx_fn, never a #using (_tod_uniques imports no
// tod module by design).
//
// ⚠️ THE SOUND IS A PLACEHOLDER AND SHOULD BE REPLACED. Map 1 plays its own
// `acc_battery_zap`, whose wav is flagged in that repo's CREDITS.md as
// "source site/licence unrecorded — ⚠️ VERIFY before publish". I did NOT copy
// it here: importing an asset with an unknown licence into a map that is about
// to be published is not a call to make silently. TOD_LMGS_SFX therefore points
// at `tod_luck_overmax_zap`, an electric zap this map already ships and already
// credits, so the feature is complete and audible today with zero licence risk
// and no sound-bank rebuild. Swap in a dedicated alias when one exists.
function lmg_steam_fx( on )
{
	if ( !isdefined( self ) || !isplayer( self ) )
		return;
	// Non-holders never see it. Cheap, and it also means a player who loses the
	// domain (there is no such path today, but tier_up's reset loop is one edit
	// away from creating one) cannot be left with a lit aura.
	if ( get_level( self, "lmgsprint" ) <= 0 )
		on = false;

	if ( !isdefined( self.tod_lmgs_aura ) )
	{
		// COOP CRASH GUARD — map 1's, and it is not theoretical: hud::create*
		// returns UNDEFINED when the shared hudelem pool is exhausted (which a
		// 4-player game can do), and every field write below would then throw.
		self.tod_lmgs_aura = self hud::createIcon( "white", 640, 480 );
		if ( !isdefined( self.tod_lmgs_aura ) )
			return;                       // pool full — skip the aura this proc
		self.tod_lmgs_aura.horzAlign = "fullscreen";
		self.tod_lmgs_aura.vertAlign = "fullscreen";
		self.tod_lmgs_aura.alignX = "left";
		self.tod_lmgs_aura.alignY = "top";
		self.tod_lmgs_aura.x = 0;
		self.tod_lmgs_aura.y = 0;
		self.tod_lmgs_aura.color = ( TOD_LMGS_AURA_R, TOD_LMGS_AURA_G, TOD_LMGS_AURA_B );
		self.tod_lmgs_aura.alpha = 0;
		self.tod_lmgs_aura.sort = 0;      // behind HUD text
		self.tod_lmgs_aura.hidewheninmenu = true;
	}

	if ( on )
	{
		self.tod_lmgs_aura fadeovertime( TOD_LMGS_AURA_IN );
		self.tod_lmgs_aura.alpha = TOD_LMGS_AURA_ALPHA;

		// CONTINUOUS WIND FOR AS LONG AS THE BOOST HOLDS (v16, user: "It needs to
		// be a continous wind against your hair sound ... Itll stop when the
		// player stops sprinting"). A LOOP, not a one-shot.
		//
		// ⚠️ HARD-STOP THE PREVIOUS GENERATION FIRST, ALWAYS. This is the map's
		// standing loop-sound rule and it is not defensive padding: once a SECOND
		// generation of the same alias starts on the same entity, the first is no
		// longer addressable and rings forever. Stopping unconditionally here
		// makes an orphan unreachable rather than merely unlikely — and this edge
		// CAN fire twice without an intervening off if a future caller changes.
		// v17.93: PLAYER-ONLY. The server PlayLoopSound that used to sit here put a
		// 2D alias on every client at full volume (user: "Other players shouldnt be
		// able to hear it"). The owner's client VM runs the loop off this toplayer
		// bit (_tod_upgrade_ui.csc steam_wind_cb); nothing is played server-side.
		self clientfield::set_to_player( "todSteamWind", 1 );   // 2026-09-22 (F25): a "toplayer" field takes the player-state setter, never clientfield::set
		self.tod_lmgs_loop = true;
		return;
	}
	self.tod_lmgs_aura fadeovertime( TOD_LMGS_AURA_OUT );
	self.tod_lmgs_aura.alpha = 0;

	// ⚠️ SERVER-SIDE StopLoopSound TAKES A FADE TIME, NOT A HANDLE. The client
	// (.csc) signature is the opposite — it takes the handle PlayLoopSound
	// returned — and writing one VM's signature in the other fails SILENTLY:
	// no error, no log, the voice just keeps running. That cost two rounds of
	// fixes on the Gift of Death before anyone checked stock. This is .gsc, so
	// it is a fade time.
	if ( IS_TRUE( self.tod_lmgs_loop ) )
	{
		self clientfield::set_to_player( "todSteamWind", 0 );   // v17.93: the client stops its own handle (no server fade any more — TOD_LMGS_SFX_FADE is unused)
		self.tod_lmgs_loop = false;
	}
}

// PUBLIC — ADRENALINE's proc cue (v16). self = player.
// PlayLocalSound, NOT PlaySound: the user asked for "a 2d sound only heard by
// the player". PlaySound emits from the player ENTITY and carries to teammates
// in earshot; PlayLocalSound plays only for that client, which is what a sound
// representing your OWN pulse should do. The alias is 2d for the same reason —
// it has no world position to attenuate from.
// Pitch variation lives in the alias row (0.94/1.06), not here: this fires
// every 6-10s for a whole run and identical repeats are what turn a cue into
// an irritant.
function adren_fx()
{
	if ( !isdefined( self ) || !isplayer( self ) )
		return;
	self PlayLocalSound( TOD_ADREN_SFX );
}

// PUBLIC — kill the wind and the wash outright, no fade, no questions.
// Called on spawn so a fresh life can never inherit a ringing loop from the
// last one: the sprint watcher's edge normally stops it (a dead player is not
// sprinting, so the latch drops and the off-edge fires), but a loop that
// outlives its owner is exactly the failure this map has already paid for once,
// and a spawn-time reset makes it unreachable instead of unlikely.
function lmg_steam_silence()
{
	if ( !isdefined( self ) || !isplayer( self ) )
		return;
	if ( IS_TRUE( self.tod_lmgs_loop ) )
	{
		self clientfield::set_to_player( "todSteamWind", 0 );   // v17.93: player-only loop, cleared through the same bit
		self.tod_lmgs_loop = false;
	}
	if ( isdefined( self.tod_lmgs_aura ) )
		self.tod_lmgs_aura.alpha = 0;
}

// DMG REDUCTION — THE LADDER. Returns the CUMULATIVE percent reduction at
// `lvl`: 6 / 11 / 15 / 18 / 20 at Lv1..Lv5, from increments 6/5/4/3/2.
//
// A closed form rather than a table so it cannot go out of range if the cap is
// ever raised — same discipline as speed_pct_for_level(), and note this is a
// SEPARATE table from ladder5() (10/18/24/28/32, used by RECOVERY / BACK ARMOR
// / VITALITY). The two look alike and must not be merged: they were given
// different shapes by the user on purpose.
//
// UNIT-AGNOSTIC: returns a plain number of PERCENT. dr_mult() below is the only
// thing that turns it into a multiplier.
function dr_pct_for_level( lvl )
{
	if ( !isdefined( lvl ) || lvl <= 0 )
		return 0;
	if ( lvl == 1 )
		return TOD_UPG_DR_L1;
	if ( lvl == 2 )
		return TOD_UPG_DR_L1 + TOD_UPG_DR_L2;
	if ( lvl == 3 )
		return TOD_UPG_DR_L1 + TOD_UPG_DR_L2 + TOD_UPG_DR_L3;
	if ( lvl == 4 )
		return TOD_UPG_DR_L1 + TOD_UPG_DR_L2 + TOD_UPG_DR_L3 + TOD_UPG_DR_L4;
	return TOD_UPG_DR_L1 + TOD_UPG_DR_L2 + TOD_UPG_DR_L3 + TOD_UPG_DR_L4
	     + ( lvl - 4 ) * TOD_UPG_DR_LN;
}

// PUBLIC — DMG REDUCTION: the incoming-damage multiplier for `player` right
// now. 1.0 unless they own the domain. Both of _tod_bosses' player-damage lanes
// multiply by this: boss_player_damage for the normal chain, and
// apply_player_mitigations for Panzer melee, which short-circuits that chain.
//
// ⚠️ THIS FUNCTION EXISTS TO END A HAND-COPY. Until v16 those two lanes carried
// bare `1.0 - 0.05 * dr_lvl` literals, because a GSC #define is FILE-LOCAL and
// the constant in this file could not reach them — so the constant was
// "documentation" and the real numbers lived in two places that had already
// drifted once (one of them still said "-4%" months after the retune). The v16
// diminishing ladder cannot be written as a literal multiply at all, which
// forced the fix that should always have been here. Call this; never re-derive.
// Floored so a future cap raise can never reach zero or invert.
function dr_mult( player )
{
	if ( !isdefined( player ) || !isplayer( player ) )
		return 1.0;
	lvl = get_level( player, "dr" );
	if ( lvl <= 0 )
		return 1.0;
	pct = dr_pct_for_level( lvl );
	// DARK UPGRADE (v17.10): a flat +10 POINTS on top of the class cap, so every
	// class gets the same step off a different base -- 15/20/24/30 -> 25/30/34/40.
	if ( has_dark( player, "dr" ) )
		pct += TOD_DARK_DR_ADD;
	m = 1.0 - ( pct / 100.0 );
	if ( m < 0.05 )
		m = 0.05;
	return m;
}

// PUBLIC — SPRINT ARMOR (v9.28): the incoming-damage multiplier for `player`
// right now. 1.0 unless the player owns the domain AND the engine says they
// are sprinting at this instant (IsSprinting — the server-side builtin). Both
// of _tod_bosses' player-damage lanes (boss_player_damage for the normal
// chain, apply_player_mitigations for Panzer melee) multiply by this right
// after DMG REDUCTION. Floored so a future level bump can never reach zero.
// ⚠️ ALWAYS RETURNS 1.0 SINCE 2026-08-31 — the SPRINT ARMOR domain was retired
// and get_level can no longer report a level for it. Kept, not deleted, because
// _tod_bosses calls it from both player-damage lanes; the multiply is now a
// permanent identity. Delete the function and its two call sites together, or
// not at all.
function sprint_armor_mult( player )
{
	if ( !isdefined( player ) || !isplayer( player ) )
		return 1.0;
	lvl = get_level( player, "sprintarmor" );
	if ( lvl <= 0 )
		return 1.0;
	if ( !( player IsSprinting() ) )
		return 1.0;
	m = 1.0 - TOD_UPG_SPRINT_ARMOR_PER_LVL * lvl;
	if ( m < 0.05 )
		m = 0.05;
	return m;
}

// PUBLIC — the map's ONE definition of "is this hit a HEADSHOT". Returns
// "loc"       the ENGINE already scored it as a head hit (hitLoc head/helmet/
//             neck) and has therefore ALREADY applied the 3.0 hit-location
//             multiplier before any script saw the damage;
// "faceplate" it landed on the PANZER's visor, which stock classifies as
//             `torso_upper` (mechz.gsc tracks faceplate damage from inside the
//             torso_upper case), so the engine applied locTorsoUpper 1.0 and
//             the damage arriving in script is a BODY-rate number;
// "none"      anything else.
//
// WHY THIS EXISTS (user 2026-08-24: "some guns will get headshots even when
// [the faceplate] is on"). Two guns aimed at the SAME point on the Panzer's
// face can produce different hitLocs, and the map then paid them differently:
// a "head" hit was worth 2.7x base while a visor hit was worth 0.9x — a silent
// 3x gap between weapons, plus no crit number, no HEADSHOT domain and no 1.5x
// luck on the visor hit. Callers must treat "faceplate" as a headshot and
// supply the missing 3.0 themselves (see _tod_bosses::tod_mechz_damage_wrap).
//
// The faceplate probe is gated on `has_faceplate` — a field only stock's mechz
// defines — so this costs one field read per hit on everything else in the map.
function headshot_kind( victim, hitloc, point )
{
	if ( isdefined( hitloc ) && ( hitloc == "head" || hitloc == "helmet" || hitloc == "neck" ) )
		return "loc";
	if ( !isdefined( victim ) || !isdefined( point ) || !isdefined( victim.has_faceplate ) )
		return "none";
	face = victim GetTagOrigin( "j_faceplate" );
	// height guard: a missing tag falls back to the entity origin (the feet),
	// which would otherwise turn every leg hit into a headshot.
	if ( !isdefined( face ) || ( face[ 2 ] - victim.origin[ 2 ] ) <= 20 )
		return "none";
	if ( DistanceSquared( face, point ) > TOD_FACEPLATE_RADIUS * TOD_FACEPLATE_RADIUS )
		return "none";
	return "faceplate";
}

// PUBLIC — the map's ONE definition of "boss or elite". The triad is set
// synchronously on the spawn frame by the Panzer (_tod_bosses::spawn_panzer),
// the Rogue Protector (rp_spawn) and the Reaver (_tod_reaver), and nine
// systems gate on it. Call this instead of re-spelling three fields.
function is_boss_or_elite( ent )
{
	if ( !isdefined( ent ) )
		return false;
	return ( IS_TRUE( ent.is_boss ) || IS_TRUE( ent.acc_is_boss ) || IS_TRUE( ent.acc_is_mini_boss ) );
}

// PUBLIC — "an ELITE as the CARDS mean it" (v19.58, user 2026-09-27:
// "gunslinger and giant slayer should count towards armored since they are
// elite"). The triad above PLUS the armored sprinter, which the kill feed
// already calls an ELITE KILL and which FIRE BLAST / ICE SHATTER / Thunder
// Smash already treat as one. Only the two "vs bosses and elites" damage
// cards read this; is_boss_or_elite stays the triad for the other systems
// (insta-kill, nuke, boss pacing ...), where the sprinter is horde by design
// (_tod_sprinter.gsc header).
function is_card_elite( ent )
{
	if ( !isdefined( ent ) )
		return false;
	return ( is_boss_or_elite( ent ) || IS_TRUE( ent.tod_is_sprinter ) );
}

// PUBLIC — HEADSHOT (domain 6): the ADDITIVE damage bonus this attacker gets on
// a HEAD HIT. The CALLER owns the "was this a head hit" test — both lanes have
// already answered it by the time they add this, and neither has a hitLoc to
// hand over — so this function owns the RATE and the DARK step and nothing else.
//
// IT EXISTS BECAUSE THE ALTERNATIVE ALREADY FAILED. _tod_bosses::rp_damage_feed
// carried a literal copy of TOD_UPG_HS_PER_LVL (a GSC #define is file-local, so
// that lane could not see the symbol), the 2026-08-22 nerf missed it, and a
// headshot on the Rogue Protector paid 2.5x for a day. GIANT SLAYER dodged the
// same fate by being a function from the start — boss_damage_bonus, right
// below. This is that fix applied to the one domain still doing it by hand
// (2026-09-08, the +12%/Lv x 5-level pass). Do not re-introduce a literal.
function headshot_bonus( attacker )
{
	if ( !isdefined( attacker ) || !isplayer( attacker ) )
		return 0;
	b = get_level( attacker, "headshot" ) * TOD_UPG_HS_PER_LVL;
	if ( has_dark( attacker, "headshot" ) )
		b += TOD_DARK_HS_ADD;   // DARK: +60% -> +85% on a head hit
	return b;
}

// PUBLIC — GIANT SLAYER (domain 35, v9.45): the ADDITIVE damage bonus this
// attacker gets against this victim. 0 unless the victim is a card elite (the
// boss/elite triad or, since v19.58, the armored sprinter - is_card_elite)
// AND the attacker owns the domain, so every call site can add it
// unconditionally. BOTH boss-damage lanes call it — upgrade_damage_cb (the
// actor chain, which is what fires for the Panzer and the Reaver) and
// _tod_bosses::rp_damage_feed (the Rogue Protector's aiOverrideDamage
// fallback). Exposing it as a function instead of a constant is deliberate:
// rp_damage_feed cannot see a file-local #define, and every hand-copied
// literal in that lane has gone stale at least once.
function boss_damage_bonus( attacker, victim )
{
	if ( !isdefined( attacker ) || !isplayer( attacker ) )
		return 0;
	if ( !is_card_elite( victim ) )
		return 0;
	b = get_level( attacker, "bossdmg" ) * TOD_UPG_BOSSDMG_PER_LVL;
	if ( has_dark( attacker, "bossdmg" ) )
		b += TOD_DARK_BOSSDMG_ADD;   // DARK: +60% -> +80% vs the boss/elite triad
	return b;
}

// PUBLIC — MELEE vs the boss/elite triad (user 2026-08-24). The MULTIPLIER a
// melee hit on `victim` pays: TOD_MELEE_BOSS_MULT_SLASHER if `attacker` is a
// SLASHER, TOD_MELEE_BOSS_MULT for every other class, 1.0 against a non-triad
// victim and 1.0 for any non-melee hit. See the #defines for the split.
//
// ⚠️ THE ATTACKER PARAMETER IS v18.3 AND ALL FOUR CALL SITES PASS IT. It was
// (victim, is_melee) for two years of sessions, so a hand-written call copied
// from an old file will silently pass the VICTIM as the attacker - which fails
// the isplayer test and quietly hands back the non-slasher rate rather than
// throwing. The arity lint catches the shape; nothing catches the meaning.
//
// PUBLIC for the same reason boss_damage_bonus is: _tod_bosses::rp_damage_feed
// is a SECOND damage lane in another file, a GSC #define is file-local, and
// every hand-copied literal in that lane has gone stale at least once. Call
// this; never re-spell the 0.5 or the triad test.
//
// THREE CALL SITES, and all three are needed:
//   1. upgrade_damage_cb   — the main actor chain (covers the Panzer, whose
//                            hit-location wrap passes melee through untouched,
//                            and the Reaver, which has no lane of its own).
//   2. cleave_splash       — a CLEAVE extra target re-enters upgrade_damage_cb
//                            already marked tod_cleave_hit, which passes through
//                            untouched by design, so the splash has to scale
//                            itself or a slasher could tag a normal zombie and
//                            splash a boss for the full swing.
//   3. rp_damage_feed      — the Rogue Protector's fallback lane, for the hits
//                            that do not go through the actor chain.
// PUBLIC — the multiplier a SLASHER'S SIDEARM pays against the boss/elite
// triad: TOD_SLASHER_SEC_BOSS_MULT, or 1.0 for anyone and anything else.
//
// Three gates, all of which must hold, and each is doing real work:
//   * the attacker's class is SLASHER — this is a class answer, not a weapon
//     buff; the same pistols on another class are untouched.
//   * the weapon is that player's CURRENT-TIER class secondary
//     (tod_classes::is_class_secondary — a STEM match, so the PaP'd AMP63's
//     dual-wield '_rdw' form still counts).
//   * the victim carries the boss/elite triad. Read through is_boss_or_elite,
//     never re-spelled — the same rule the other eight consumers use.
//
// NOT gated on melee: a melee hit is never the class secondary, so the two
// lanes cannot both fire on one hit by construction.
// THE ONE GATE both halves below share: is this a SLASHER hitting a boss or
// elite with the CLASS SIDEARM? Split out in v16.99 so the baseline and the
// GUNSLINGER term can never disagree about when they apply.
// card_elite (v19.58): GUNSLINGER passes true so its CARD counts the armored
// sprinter (the user's call); the 2.25 class baseline passes nothing and keeps
// the triad, so the baseline did not change - the two halves now differ on
// exactly that one enemy, on purpose.
function slasher_sidearm_vs_boss( attacker, victim, weapon, card_elite = false )
{
	if ( !isdefined( attacker ) || !isplayer( attacker ) )
		return false;
	if ( !isdefined( attacker.tod_class ) || attacker.tod_class != "slasher" )
		return false;
	if ( IS_TRUE( card_elite ) )
	{
		if ( !is_card_elite( victim ) )
			return false;
	}
	else if ( !is_boss_or_elite( victim ) )
		return false;
	return ( tod_classes::is_class_secondary( attacker, weapon ) );
}

// THE CLASS BASELINE — still MULTIPLICATIVE on the final, unchanged since v16.
// This is the slasher's compensation for the blade's x0.33 boss tax, not an
// upgrade, and nothing a player buys moves it.
function slasher_sidearm_boss_mult( attacker, victim, weapon )
{
	if ( !slasher_sidearm_vs_boss( attacker, victim, weapon ) )
		return 1.0;
	return TOD_SLASHER_SEC_BOSS_MULT;
}

// GUNSLINGER (domain 44) — ADDITIVE SINCE v16.99 (user 2026-09-03: "Yes make
// gunslinger additive").
//
// IT USED TO MULTIPLY THE FINAL, and that is why it was the largest outlier in
// the map. As `baseline x (1 + 0.30*Lv)` a maxed level turned the whole boss
// multiplier into x5.625 AFTER every other term had already been summed — so
// it scaled DAMAGE, the head crit and the baseline all at once and was diluted
// by nothing. Measured at the cap that put a maxed slasher's sidearm at ~220k
// boss DPS against the ASSAULT's ~82k, and the assault is the class whose whole
// identity is boss damage.
//
// It now returns an ADDITIVE term that joins the same sum GIANT SLAYER lives in
// (mult = 1 + DAMAGE + headshot + uniques + boss bonus + this), so a level of
// GUNSLINGER is worth the same KIND of thing as a level of GIANT SLAYER and is
// diluted by the same denominator. Same +0.30/Lv rate, same three gates, same
// max 5 — only the arithmetic changed, so no card, ladder or pause row moves.
//
// The 2.25 baseline is deliberately left multiplicative: it is the class's
// structural compensation for the blade tax, not something a card buys. If the
// slasher still reads too strong on bosses after this, THAT constant is the
// next lever, not this rate.
function gunslinger_bonus( attacker, victim, weapon )
{
	if ( !slasher_sidearm_vs_boss( attacker, victim, weapon, true ) )   // v19.58: the card counts the armored sprinter
		return 0.0;
	g = get_level( attacker, "gunslinger" ) * TOD_UPG_GUNSLINGER_PER_LVL;
	if ( has_dark( attacker, "gunslinger" ) )
		g += TOD_DARK_GUNSLINGER_ADD;   // DARK: +150% -> +180%. Deliberately the smallest step in the set: this lane was reshaped in v16.99 and moved again in v17.4
	return g;
}

function melee_boss_mult( attacker, victim, is_melee )
{
	if ( !IS_TRUE( is_melee ) )
		return 1.0;
	if ( !is_boss_or_elite( victim ) )
		return 1.0;
	// THE CLASS TEST (v18.3). Keyed on the attacker's CLASS and not on the
	// weapon, for the same reason slasher_sidearm_vs_boss is: a slasher's melee
	// is its class primary at every tier, and a bare-knife swing while the
	// sidearm is out is the same class's swing. The gun classes keep the shared
	// tax on the knife they all carry.
	if ( isdefined( attacker ) && isplayer( attacker )
	     && isdefined( attacker.tod_class ) && attacker.tod_class == "slasher" )
		return TOD_MELEE_BOSS_MULT_SLASHER;
	return TOD_MELEE_BOSS_MULT;
}

// PUBLIC — BACK ARMOR (domain 36, v9.45): the incoming-damage multiplier for a
// hit on `player` from `attacker`. 1.0 unless the domain is owned AND the
// attacker is inside the rear arc of the player's view. Same contract and the
// same two call sites as sprint_armor_mult (boss_player_damage for the normal
// chain, apply_player_mitigations for Panzer melee), floored the same way.
//
// The attacker may legitimately be undefined (world damage, a fall, splash with
// no owner) — that is NOT from behind, so it pays nothing.
function back_armor_mult( player, attacker )
{
	if ( !isdefined( player ) || !isplayer( player ) )
		return 1.0;
	lvl = get_level( player, "backarmor" );
	if ( lvl <= 0 )
		return 1.0;
	if ( !isdefined( attacker ) || !isdefined( attacker.origin ) )
		return 1.0;

	// 2D only: the spiral stacks enemies vertically and a Panzer two flights
	// below is not behind you. Zeroing z before normalizing is what makes the
	// arc a compass bearing rather than a sphere.
	to = attacker.origin - player.origin;
	to = ( to[ 0 ], to[ 1 ], 0 );
	if ( LengthSquared( to ) < 1 )
		return 1.0;                       // standing inside you — no bearing to read
	to = VectorNormalize( to );

	// VIEW angles, not the body's: "behind" means behind where the player is
	// LOOKING. GetPlayerAngles is the server-side view; a player who spins round
	// to shoot loses the bonus the moment the enemy is in front of them, which
	// is the whole point of the card. YAW ONLY (stock's colors_shared idiom) —
	// building the forward vector from a zeroed pitch is exact, where flattening
	// a full 3D forward degenerates to nothing when you look straight down.
	ang = player GetPlayerAngles();
	fwd = AnglesToForward( ( 0, ang[ 1 ], 0 ) );

	if ( VectorDot( fwd, to ) > TOD_BACK_ARC_DOT )
		return 1.0;                       // in front of, or beside, the player

	pct = ladder5( lvl );
	if ( has_dark( player, "backarmor" ) )
		pct += TOD_DARK_LADDER5_ADD;   // DARK: -32% -> -45% from behind
	m = 1.0 - ( pct / 100.0 );
	if ( m < 0.05 )
		m = 0.05;
	return m;
}

// ADRENALINE (MP7 unique): the live burst bonus — a FLAT +3%/tier while a
// proc is live, otherwise nothing. No stacks — one burst, one value. Read by
// THREE lanes, all the same number on purpose: the move-speed sum
// (apply_move_speed), the bullet-damage sum (unique_damage_mult, v17.67) and
// the on-trigger heal (v17.85, at the proc site, x TOD_ADREN_HEAL_MULT).
//
// THE HEAL READS IT THROUGH THE SAME LIVE-BURST TEST as the other two, which
// is why the proc site must set tod_adren_until BEFORE calling this — it
// returns 0 outside a burst by design, and a heal computed one line too early
// would silently be zero. That ordering is asserted by comment at the call.
// self = player.
function adren_bonus()
{
	lvl = get_level( self, "adrenaline" );
	if ( lvl <= 0 || !isdefined( self.tod_adren_until ) )
		return 0;
	if ( GetTime() > self.tod_adren_until )
		return 0;
	b = lvl * TOD_ADREN_PCT_PER_LV;
	if ( has_dark( self, "adrenaline" ) )
		b += TOD_DARK_ADREN_ADD;   // DARK: +15% -> +25% for the 3s burst
	return b;
}

// One-shot: wait out the burst then re-apply move speed ONCE, so the 3s is
// really 3s. Notify-cancelled so a proc landing inside an existing burst does
// not leave two threads racing to un-apply it.
function adren_expire()
{
	self endon( "disconnect" );
	level endon( "end_game" );
	self notify( "tod_adren_expire" );      // newest proc owns the clock
	self endon( "tod_adren_expire" );
	wait ( TOD_ADREN_MS / 1000 );
	self apply_move_speed();
}

// The per-tier cooldown: 20/18/16/14/12 seconds at Lv1..Lv5. Shaped like
// thor_cooldown_ms and floored for the same reason — the floor, not the level
// cap, is what makes a future 6th tier safe.
function adren_cooldown_ms( lvl )
{
	cd = TOD_ADREN_CD_MAX_MS - ( lvl - 1 ) * TOD_ADREN_CD_STEP_MS;
	if ( cd < TOD_ADREN_CD_MIN_MS )
		cd = TOD_ADREN_CD_MIN_MS;
	return cd;
}

// Per-class BASE move speed (user 2026-08-20, retuned same day: 0.65-1.05
// felt too punishing): HEAVY/LMG 0.8, ASSAULT/AR 0.9, SKIRMISHER/SMG 1.0,
// SLASHER/melee 1.1. Script-side via the speed owner (the weapon-GDT
// moveSpeedScale fields are install-side and SHARED with map 1 — never edit
// those). SPRINT/MOBILITY multiply on top.
//
// 2026-08-23 (user, from the first ship-state run): "Lower the speed of AR and
// LMG by 0.05" — ASSAULT/AR 0.9 -> 0.85, HEAVY/LMG 0.8 -> 0.75. Speed is keyed
// on the CLASS, not the gun, so this holds across the whole tier ladder
// (Enfield/Krig/AK-47 and Stoner/HK21/Death Machine) and survives any roster
// swap.
//
// 2026-08-23 LATER (user: "Make assault move speed multiplier 0.9 instead of
// 0.85"): ASSAULT reverted to 0.9 — HALF the cut above is undone. HEAVY stays
// at 0.75, so the two heavy-weapon classes no longer move as one block: the AR
// sits midway between the LMG and the SMG rather than next to the LMG.
//
// 2026-08-30 (user: "we need to switch base speed of the skirmisher class and
// melee. Melee is too fast and skirmisher should be the fastest"): SKIRMISHER
// and SLASHER SWAPPED — skirmisher 1.0 -> 1.1, slasher 1.1 -> 1.0. A straight
// exchange, not a retune: the pair still occupies the same two rungs, so the
// spread and every relative gap in the map are unchanged and only the two
// labels moved. The SMG class is now the fastest thing in the map, which is
// what the class fantasy always said it was.
// Knock-on worth knowing rather than discovering: SPRINT (+5%/Lv, max 10) is
// scoped to BOTH of these classes, so the top speed the map can reach follows
// the swap too — the skirmisher's ceiling goes 1.50 -> 1.65 and the slasher's
// 1.65 -> 1.50. Nothing else keys on these numbers; class_speed_base is the
// single source and apply_move_speed is its only caller.
// Current spread, slowest to fastest: HEAVY 0.80 · ASSAULT 0.9 ·
// MAGE 0.85 (gated, docs/114) · SLASHER 1.0 · SKIRMISHER 1.1.
// ⚠️ SPEED DOMAINS ADD TO THESE, THEY DO NOT MULTIPLY THEM (v15) — see
// apply_move_speed. So a "+5%" card is +0.05 of scale for every class alike.
function class_speed_base()   // self = player
{
	c = tod_classes::get_class( self );
	if ( !isdefined( c ) )
		return 1.0;   // classless (pre-draft)
	switch ( c.key )
	{
		case "heavy":      return 0.80;   // 0.8 -> 0.75 -> 0.80 again (v15, 2026-08-31: MOBILITY retired, so the FLOOR rises to pay for the lost passive)
		case "assault":    return 0.9;    // 0.9 -> 0.85 -> 0.9 again (user 2026-08-23)
		case "skirmisher": return 1.1;    // was 1.0 — swapped with slasher (user 2026-08-30)
		case "slasher":    return 1.0;    // was 1.1 — "melee is too fast"
		case "mage":       return 1.0;    // 0.85 -> 1.0 (user 2026-09-07: "the speed of the mage should be 1 as well ... not 0.85"). Was set between HEAVY 0.80 and ASSAULT 0.9 on the theory that a robed caster reads slow; playing it, that just made the class feel bad. Set on the CLASS, never the weapon, so it survives any staff-roster change
	}
	return 1.0;
}

// HEADSHOTS ARE 3x FOR EVERY CLASS. There was a class_hs_scale() here for one
// build (2026-08-24) giving the ASSAULT 4x; the user reverted it the same day
// after playing it ("Assault class had a 3x and we moved headshot to 4x. Lets
// move that back down to 3x actually"). Removed rather than stubbed to 1.0 — it
// was called from two per-hit damage callbacks and a multiply-by-one in that
// path earns nothing.
//
// To bring it back: one function keyed on tod_classes::get_class( player )
// returning ( wanted / 3.0 ), multiplied into the RAW damage in
// upgrade_damage_cb and in _tod_bosses::rp_damage_feed, on each lane's own
// existing headshot test. The 3.0 divisor is LOC_NORM in tools/gen_tod_twins.js
// — every generated gun ships locHead/locHelmet/locNeck 3.0 and the ENGINE has
// applied it before any callback sees the hit, so script only ever supplies the
// RATIO. Differentiation today comes solely from the HEADSHOT upgrade domain.

// PUBLIC — the MENU SOFT-FREEZE (live-test find 2026-08-19: FreezeControls
// zeroes the ENTIRE input snapshot — D-pad/stick/jump reads all go dead, the
// menus were unnavigable and timeouts random-picked). Instead: movement
// pinned via the move-speed owner above + weapons disabled so nav inputs
// can't fire/aim — but the raw button/stick reads STAY LIVE for the menu
// loops. self = player. (Jumping in place while locking is possible — known
// and accepted; JUMP is the lock button.)
function menu_freeze( on )
{
	if ( on )
	{
		// Never freeze a downed player (frozen laststand = stuck).
		if ( self laststand::player_is_in_laststand() )
			return;
		self.tod_menu_frozen = true;
		self DisableWeapons();
		self DisableOffhandWeapons();
		self AllowJump( false );   // JUMP is the lock button — the press must
		                           // not hop the player (stock builtin,
		                           // _zm.gsc:2508; reads still work)
		self apply_move_speed();
	}
	else
	{
		// v17.70 THE KING'S HOLD: while the summit's dark deals run, NOBODY
		// unfreezes — "If you are already maxed you will stay frozen until all
		// players are done". king_dark_deals lifts the hold and unfreezes
		// everyone itself; a laststand player was never frozen (above).
		if ( IS_TRUE( level.tod_king_hold ) )
			return;
		if ( !IS_TRUE( self.tod_menu_frozen ) )
			return;
		self.tod_menu_frozen = undefined;
		self EnableWeapons();
		self EnableOffhandWeapons();
		// DON'T HAND JUMP BACK TO A CRAWLING PLAYER (audit 2026-08-26). This ran
		// unconditionally, so unfreezing a player who went DOWN while the cards
		// were up undid stock's own last-stand restriction (_zm.gsc:2497) and
		// left them hopping around while crawling until revived or bled out.
		// Safe to skip: stock restores jump itself on every revive path
		// (_zm_laststand.gsc:965 — its comment is literally "player couldn't
		// jump - allow this again now that they are revived" — and :1372), so
		// there is no path where a revived player is left unable to jump.
		// EnableOffhandWeapons above is deliberately NOT guarded the same way:
		// it would need its own stock-restore audit for a smaller payoff, and
		// stock's revive_give_back_weapons already calls it (:400-401).
		if ( !( self laststand::player_is_in_laststand() ) )
			self AllowJump( true );
		self apply_move_speed();
	}
}

// (tireless_apply / tireless_clear / stock_sprint_time / tireless_spawn_watch
// all REMOVED 2026-08-26 with the TIRELESS feature — see the block comment
// where TOD_UPG_TIRELESS_SECS used to live for the full history and for what to
// try first if it is ever revived. Nothing in the map now calls
// SetSprintDuration or SetClientPlayerSprintTime, so both sprint knobs stay at
// the gametype's stock 4s for every player, which is what they read as anyway.)

// Shared native Gung-Ho permission. Archmage refreshes this immediately at
// start/end and while active; the normal upgrade loop must not strip it.
function apply_sprint_fire()   // self = player
{
	arch = IS_TRUE( self.tod_mage_demigod ) && IS_TRUE( self.tod_mage_armed )
	    && IsAlive( self ) && !( self laststand::player_is_in_laststand() );
	if ( get_level( self, "sprintfire" ) > 0 || arch )
	{
		if ( !( self HasPerk( "specialty_sprintfire" ) ) )
			self SetPerk( "specialty_sprintfire" );
	}
	else if ( self HasPerk( "specialty_sprintfire" ) )
		self UnsetPerk( "specialty_sprintfire" );
}

function body_systems_loop()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	self.tod_feed_t = 0;

	for ( ;; )
	{
		wait 1;

		if ( !IsAlive( self ) || ( self laststand::player_is_in_laststand() ) )
			continue;

		// MOVE SPEED: re-assert every tick — the scale now depends on the
		// CLASS (station switches change it), and stock respawn/perk code
		// stomps SetMoveSpeedScale (last-writer-wins). Idempotent.
		self apply_move_speed();

		// BASE 150 HP + VITALITY maintain — the floor is max_hp_floor(), and
		// since v14.28 that floor COUNTS AN ACTIVE JUGG. It has to: stock's
		// health_reboot (round transitions, revives, jugg loss) rebuilds max
		// from player_base_health, and before v14.28 a jugg holder's rebuilt
		// 200 sat ABOVE the old jugg-blind floor (150+10xVIT), so a raise-only
		// maintain could never see the stolen vitality — that was the user's
		// "210 back down to 200". Still raise-only, still no free healing.
		want = self max_hp_floor();
		if ( self.maxhealth < want )
		{
			self.maxhealth = want;
			self SetMaxHealth( want );
		}

		// (The TIRELESS grant/clear pair lived here until 2026-08-26. It was the
		// only thing in the map that called SetPerk("specialty_staminup"), so
		// with it gone the specialty is once again purely the perk machine's —
		// no script grants it, and nothing needs to strip it. See the block
		// comment where TOD_UPG_TIRELESS_SECS used to live.)

		// One owner for the permanent card and temporary Archmage permission.
		self apply_sprint_fire();

		// (HEALTH became DMG REDUCTION 2026-08-20 — applied in the player
		// damage chain (_tod_bosses::boss_player_damage + the panzer-melee
		// mitigation hook), not here; maxhealth is stock's again.)

		// (REGEN's trickle hook lived here until 2026-08-30 — removed with the
		// domain, v14.11. RECOVERY replaces the heavy's sustain and runs on
		// its own faster thread, recovery_loop — a 1s tick is too coarse for
		// a 240..1500ms delay reduction.)

		// SECOND WIND (skirmisher, MP5-bound since v14.11): heal WHILE SPRINTING, 1% of max
		// HP per level per second. This loop is the 1s tick REGEN already rides,
		// so the per-second wording is literal. Sprint-gated on purpose — you
		// cannot fire while sprinting in BO3, so the heal costs you your damage
		// output for as long as you take it.
		sw = get_level( self, "secondwind" );
		if ( sw > 0 && self IsSprinting() )
			self trickle_heal( self.maxhealth * TOD_UPG_SECONDWIND_PER_LVL * sw );

		// TWIN RECONCILE: keep the held class gun on the exact variant the
		// player's twin levels demand (covers respawn re-gives, class
		// switches, and PaP — the CSV maps every variant to its _up twin).
		self reconcile_twin();

		// CLASS-GUN WATCHDOG (2026-08-22). The class gun is only ever GIVEN at
		// spawn (tod_classes::give_class_loadout), so ANY path that takes it
		// strands the player on the pistol for the rest of the run — and with
		// god mode on there is no down/respawn to re-give it. That is exactly
		// what the stock too-many-weapons confiscation did (now disabled in
		// zm_tower_of_doom.gsc), but a box trade, a powerup-gun restore that
		// misses, or any future stock path would do the same. Belt and braces:
		// if no form of the class gun is in the inventory for 3 consecutive
		// ticks, give it back at the form the player's levels + PaP latch
		// demand. Never mid-swap, never in last stand, never while a powerup
		// gun is out (its own restore would fight us).
		// (powerup-gun check reads the same per-player var tier_card_eligible and
		// grab_pap use — a plain zombie_vars field, no helper call)
		if ( IS_TRUE( self.tod_swap_busy ) || IS_TRUE( self.tod_tier_busy )
		  || self laststand::player_is_in_laststand()
		  || ( isdefined( self.zombie_vars ) && IS_TRUE( self.zombie_vars[ "zombie_powerup_minigun_on" ] ) ) )
		{
			self.tod_noclassgun_ticks = 0;
		}
		else if ( isdefined( self class_primary_in_inventory() ) )
		{
			self.tod_noclassgun_ticks = 0;
		}
		else
		{
			if ( !isdefined( self.tod_noclassgun_ticks ) )
				self.tod_noclassgun_ticks = 0;
			self.tod_noclassgun_ticks++;
			if ( self.tod_noclassgun_ticks >= 3 )
			{
				self.tod_noclassgun_ticks = 0;
				g = tod_classes::gun( self );
				if ( isdefined( g ) )
				{
					// variant_name() + weapon_or_zm(), never hand-concatenation or a
					// bare GetWeapon — see the naming block in _tod_classes.
					want = tod_classes::weapon_or_zm( tod_classes::variant_name( g, IS_TRUE( self.tod_pap_owned ), self twin_suffix( IS_TRUE( self.tod_pap_owned ) ) ) );
					if ( !isdefined( want ) || want == level.weaponNone )
						want = tod_classes::base_weapon( g );   // fall back to the level-0 form
					if ( isdefined( want ) && want != level.weaponNone )
					{
						want = self tod_classes::give_camo_weapon( want );
						self GiveStartAmmo( want );
						self SwitchToWeapon( want );
					}
				}
			}
		}

		// BULLET FEED (heavy) — REWORKED AGAIN 2026-08-21 (user): "should pull
		// in 1 bullet at a time but the upgrade will make it go faster and
		// faster. It will work when gun is away too."
		//   * ALWAYS exactly ONE round per tick — the amount never scales, the
		//     RATE does. That is what reads as a belt feeding.
		//   * Interval = TOD_UPG_FEED_BASE_SECS - TOD_UPG_FEED_STEP_SECS*(Lv-1)
		//     -> Lv1 every 1.0s ... Lv10 every 0.2s, floored so it can never
		//     hit zero. (This comment said 3.0s/0.75s until 2026-08-30 — it was
		//     never updated through the v8.9 retune OR the 2x buff. The DEFINES
		//     are the source of truth; distrust the prose.)
		//   * Runs on the CLASS GUN whether or not it is in hand — we look the
		//     weapon up in the player's inventory instead of reading
		//     GetCurrentWeapon, so the belt keeps loading while the pistol (or
		//     the Gift of Death) is out.
		// This loop ticks once a second, so the sub-second rates at high level
		// are reached by feeding on consecutive ticks; tod_feed_t carries the
		// fractional debt.
		feed = get_level( self, "bulletfeed" );
		if ( feed > 0 )
		{
			w = self class_primary_in_inventory();
			if ( isdefined( w ) )
			{
				iv = TOD_UPG_FEED_BASE_SECS - TOD_UPG_FEED_STEP_SECS * ( feed - 1 );
				floor_iv = TOD_UPG_FEED_MIN_SECS;
				// DARK UPGRADE (v17.10): 5.0 -> 7.0 rounds/s. Expressed as an INTERVAL
				// floor because that is this lane's unit; 1/7 = 0.142857s. The floor has
				// to move with it -- Lv10 already sits exactly on TOD_UPG_FEED_MIN_SECS,
				// so scaling the interval alone would be eaten by the clamp (the same
				// trap as THOR'S THUNDER's cooldown).
				// v18.9 — AND THE INTERVAL ITSELF, which is what the card was always
				// supposed to buy. Lowering the floor alone bought 0.05%: at the cap
				// iv = 1.0 - 0.0889*9 = 0.1999, which is already ABOVE the dark floor
				// 0.142857, so the clamp never fired and dark BULLET FEED delivered
				// 5.003 rounds/s against the plain card's 5.000. The comment above
				// names this exact trap and then fell into it; thor_cooldown_ms is the
				// lane that does it right, and this now matches it — scale the value
				// AND lower the floor. Safe at every level because dark_pool only ever
				// offers a MAXED domain and tier_up clears the dark bit in lockstep
				// with the level, so no path reaches here with dark on a sub-cap feed.
				if ( has_dark( self, "bulletfeed" ) )
				{
					floor_iv = 1.0 / TOD_DARK_BULLETFEED_RPS;
					iv = floor_iv;
				}
				if ( iv < floor_iv )
					iv = floor_iv;

				if ( !isdefined( self.tod_feed_t ) )
					self.tod_feed_t = 0;
				self.tod_feed_t += 1.0;   // this loop's period

				// Feed one round per whole interval elapsed (catches up the
				// sub-second rates without ever batching more than the debt).
				while ( self.tod_feed_t >= iv )
				{
					self.tod_feed_t -= iv;
					clip = self GetWeaponAmmoClip( w );
					stock = self GetWeaponAmmoStock( w );
					if ( clip >= w.clipSize || stock <= 0 )
					{
						self.tod_feed_t = 0;   // full or dry — no debt to bank
						break;
					}
					self SetWeaponAmmoClip( w, clip + 1 );
					self SetWeaponAmmoStock( w, stock - 1 );
				}
			}
		}
	}
}

function trickle_heal( amount )   // self = player
{
	if ( self.health >= self.maxhealth )
		return;
	n = self.health + int( amount + 0.5 );
	if ( n > self.maxhealth )
		n = self.maxhealth;
	if ( n > self.health )
		self.health = n;
}

// ---------------------------------------------------------------------------
// RECOVERY (HEAVY, v14.11) — "health regen starts 10% sooner / Lv", 3 levels.
// Stock zm regen is script-side in _zm_playerhealth.gsc::playerHealthRegen and
// its delay is LEVEL-GLOBAL, so it cannot be shortened for one player. This
// pair EMULATES the stock outcome at the reduced delay instead — see the
// contract at the TOD_UPG_RECOV_* defines. Stock's loop is untouched: when it
// wakes at the full delay it finds the player already healed and idles.
//
// Two damage stamps feed tod_last_dmg_ms, belt and braces:
//   * recovery_damage_watch — the engine's own "damage" notify, the same
//     input stock's playerHurtcheck trusts. Exact timing, every source
//     (Panzer flame, falls, everything that actually costs health).
//   * the poll below — any health DROP between ticks stamps too, so a
//     damage path that somehow skipped the notify is still caught within
//     one 0.1s tick. Our own heals only ever raise health, never re-stamp.
// ---------------------------------------------------------------------------

// self = player. One thread per player for the whole game (started once from
// player_upgrade_setup, same lifetime contract as body_systems_loop).
function recovery_loop()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	self.tod_last_dmg_ms = 0;
	last_hp = ( ( isdefined( self.health ) ) ? self.health : 0 );

	for ( ;; )
	{
		wait TOD_RECOV_TICK_SECS;

		// poll-stamp BEFORE any gating — a drop is a drop even at level 0
		// (levels can arrive mid-fight; the stamp must already be honest)
		hp = ( ( isdefined( self.health ) ) ? self.health : 0 );
		if ( hp < last_hp )
			self.tod_last_dmg_ms = GetTime();
		last_hp = hp;

		lvl = get_level( self, "recovery" );
		if ( lvl <= 0 )
			continue;
		if ( !IsAlive( self ) || ( self laststand::player_is_in_laststand() ) )
			continue;   // never heal the downed — stock's own regen never does
		if ( !isdefined( self.maxhealth ) || self.maxhealth <= 0 )
			continue;
		if ( self.health <= 0 || self.health >= self.maxhealth )
			continue;

		// Which band? Mirrors stock's healthOverlayCutoff split: above it a
		// finished delay SNAPS to full; below it the (longer) delay gates a
		// climb. Read the stock numbers LIVE so a retune there propagates.
		ratio = self.health / self.maxhealth;
		cutoff = ( ( isdefined( level.healthOverlayCutoff ) ) ? level.healthOverlayCutoff : 0.2 );
		if ( ratio > cutoff )
			delay = ( ( isdefined( level.playerHealth_RegularRegenDelay ) ) ? level.playerHealth_RegularRegenDelay : 2400 );
		else
			delay = ( ( isdefined( level.longRegenTime ) ) ? level.longRegenTime : 5000 );

		rec_pct = ladder5( lvl );
		if ( has_dark( self, "recovery" ) )
			rec_pct += TOD_DARK_LADDER5_ADD;   // DARK: regen starts 32% -> 45% sooner
		if ( ( GetTime() - self.tod_last_dmg_ms ) < int( delay * ( 1.0 - ( rec_pct / 100.0 ) ) ) )
			continue;

		// Window earned early — deliver what stock would deliver at the full
		// delay. SetNormalHealth takes a RATIO (stock's own idiom in this
		// exact spot, _zm_playerhealth.gsc:243).
		if ( ratio > cutoff )
			self SetNormalHealth( 1 );
		else
		{
			nr = ratio + TOD_RECOV_CLIMB_PER_TICK;
			if ( nr > 1.0 )
				nr = 1.0;
			self SetNormalHealth( nr );
		}
		last_hp = self.health;   // our heal is a rise; never let it read as anything else
	}
}

// self = player. The exact-timing stamp lane (see the block comment above).
function recovery_damage_watch()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	for ( ;; )
	{
		self waittill( "damage", amount, attacker );
		// FRIENDLY FIRE DOES NOT OPEN A REGEN WINDOW — mirrors stock's own
		// filter in playerHurtcheck (_zm_playerhealth.gsc:101) and map 1's
		// qr_damage_time_watcher. Without it a teammate's splash (or your own
		// PHD dive) would delay your regen where stock would not.
		if ( isdefined( attacker ) && isplayer( attacker )
		  && isdefined( attacker.team ) && attacker.team == self.team )
			continue;
		self.tod_last_dmg_ms = GetTime();
	}
}

// ---------------------------------------------------------------------------
// RED-VIGNETTE SYNC (v14.16) — the downstream cost of ANY recovery modifier.
//
// PORTED FROM MAP 1, WHERE IT WAS A USER-REPORTED BUG (acc _acc_perks.gsc
// health_overlay_sync, 2026-07-25: "the screen keeps flashing red for seconds
// at 100% HP"). Their Mega Quick Revive shortens the same stock regen delay
// RECOVERY does, so they hit this first and paid for the diagnosis.
//
// THE MECHANISM (verified in the stock tree, not assumed): the red vignette
// (_zm_playerhealth.gsc::redFlashingOverlay) is TIME-based and NEVER re-reads
// self.health — once you dip under healthOverlayCutoff it pulses until
// hurtTime + longRegenTime plus a fixed fade tail. Stock got away with that
// because stock's "very hurt" regen ALSO waits exactly longRegenTime, so the
// overlay ending and the heal completing land together BY CONSTRUCTION.
//
// WE BREAK THAT ALIGNMENT TWICE OVER:
//   * RECOVERY starts the heal at longRegenTime x (1 - 0.10 x Lv) — at Lv3
//     that is 3.5s, and the 0.2/tick climb tops off ~0.4s later, while the
//     vignette runs on past 5s + its tail. Seconds of red screen at full HP.
//   * VITALITY's apply_upgrade HEALS on purchase, which can top a critical
//     player off instantly — same desync, no RECOVERY required.
//
// THE LEVER IS STOCK'S OWN KILL SWITCH: "clear_red_flashing_overlay", which
// watchHideRedFlashingOverlay waits on (:396) and redFlashingOverlay endons
// (:414); _zm_laststand.gsc:1370 fires it on revive, so this is a blessed
// lane rather than a hack. Fired EDGE-TRIGGERED on not-full -> full.
//
// DELIBERATELY NOT GATED on the player_has_red_flashing_overlay flag: stock's
// regen loop clears that flag at full health WITHOUT stopping the visual, so
// "flag off, overlay still pulsing" is precisely the broken state being fixed.
// A notify with no overlay up is a no-op (fades an alpha-0 element).
//
// THREAD LIFETIME — one difference from map 1, and it is deliberate. They
// re-thread per life and needed a custom "acc_perk_life" notify to kill the
// previous copies, because a BO3 ZM player NEVER notifies "death" during play
// so endon("death") leaks a loop per respawn (their 2026-06-27 crash-hunt).
// OURS CANNOT LEAK: player_upgrade_setup latches on tod_body_systems_on and
// starts these threads exactly ONCE per player (the latch is set and never
// cleared — grep-verified), so they simply survive death and respawn. Do NOT
// "fix" this by re-threading on spawn without adding a kill notify first.
// ---------------------------------------------------------------------------

// self = player.
function health_overlay_sync()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	was_full = true;   // spawns land at full — only a real recovery may edge-trigger

	for ( ;; )
	{
		wait TOD_RECOV_TICK_SECS;

		if ( !isdefined( self.maxhealth ) || self.maxhealth <= 0 )
			continue;
		if ( self.health <= 0 )
			continue;   // downed/dead — laststand's revive path clears the overlay itself

		is_full = ( self.health >= self.maxhealth );
		if ( is_full && !was_full )
			self notify( "clear_red_flashing_overlay" );
		was_full = is_full;
	}
}

// ---------------------------------------------------------------------------
// TWIN SWAP — the REAL gun-data upgrades (fire rate / handling / recoil).
// The generator (tools/gen_tod_twins.js) authors a variant weapon per level
// combo; this reconciles the player's held class gun onto the exact variant
// their levels demand, preserving clip/reserve/PaP-form/held state. Naming
// contract: <base>[_up]_f{F}h{H} (skirmisher) / <base>[_up]_r{R} (assault).
// self = player. Runs every body tick (self-healing) + instantly on upgrade.
// ---------------------------------------------------------------------------

// self = player -> the variant suffix its class gun must be on.
//
// GENERIC since CLASS TIERS (2026-08-22): the suffix is built from the gun's
// registered axes (_tod_classes::register_gun) — one letter + level per axis,
// in registration order: "_f1h2" (mp5 fire x handling), "_r0m3" (krig recoil
// x mag), "_p1" (stoner penetration), "_k4" (knife swing). An axis-less gun
// returns "_b" — its single base-tuned form. A new gun never touches this.
//
// NO EARLY-OUT (user 2026-08-21): the level-0 variants (_f0h0 / _r0m0 / _p0 /
// _k0 / _b) are REAL assets — they carry the base tune that cannot go in the
// shared install GDT (move 1.0, LOC_NORM, recoil/ADS bumps, per-gun clips).
// Returning "" would hand the player the untuned stock asset.
// `is_up` = is the PACKED form in hand. DARK UPGRADES (v17.10) live one rung
// past the ladder and exist ONLY on the packed form of the class TIER 3 gun
// (gen_tod_twins.js axisMaxUp), so the bump is applied only when packed.
//
// THIS FUNCTION DOES NOT KNOW WHICH GUN HAS WHICH RUNG, ON PURPOSE. Mirroring
// the generator's axisMaxUp table here would be a second source of truth that
// nothing regenerates -- the exact drift this repo keeps paying for. Instead
// the caller ASKS FOR the dark name, and falls back to the plain one when the
// asset does not link (see reconcile_twin). A Krig 6 holder with dark MAG SIZE
// therefore keeps working: m4 exists on the AK only, the lookup misses, and the
// plain suffix is used.
function twin_suffix( is_up )
{
	g = tod_classes::gun( self );
	return self twin_suffix_for( g, is_up );
}

function twin_suffix_for( g, is_up )
{
	if ( !isdefined( g ) )
		return "";
	if ( !isdefined( g.axes ) || g.axes.size == 0 )
		return "_b";
	s = "_";
	for ( i = 0; i < g.axes.size; i++ )
	{
		lvl = self axis_level( g.axes[ i ].domain );
		if ( IS_TRUE( is_up ) && has_dark( self, g.axes[ i ].domain ) )
			lvl++;
		s += g.axes[ i ].letter + lvl;
	}
	return s;
}

// ONE AXIS IN THIS MAP IS NOT A DOMAIN (v19.25). self = player.
//
// Every variant letter but one reads an upgrade LEVEL — "recoil" 0..2, "magsize"
// 0..3, and so on. The ice staff's `d` letter reads a PERK instead: Double Tap
// buys the ice staff a faster cadence (fireTime 0.80 -> 0.60), because BO3 has
// no per-player fire-rate call and a second weapon asset is the only lane that
// exists (see DTAP_STEP in gen_tod_twins.js for the whole finding).
//
// THIS IS THE ONLY PLACE THE TRANSLATION LIVES, and it is here rather than in
// `get_level` on purpose: `get_level` is the upgrade ladder's own reader and is
// called by cards, the pause list, the scoreboard and every effect lane. A perk
// that reported itself as an upgrade level through it would show up in all of
// them as a phantom domain nobody can see or spend on.
//
// NO EXTRA WATCHER IS OWED. `reconcile_twin` already runs on the shared 1 s
// player loop, so buying Double Tap swaps the staff within a second — and so
// does LOSING it, which matters more than it sounds: stock strips every perk on
// a down, so a downed-and-revived mage would otherwise keep firing the fast
// staff for the rest of the run.
//
// `has_perk_paused` is read alongside HasPerk deliberately — a perk is PAUSED,
// not removed, while the power is off or during the stock pause windows, and a
// staff that silently slowed down there would read as the rate buff breaking.
function axis_level( domain )   // self = player
{
	if ( isdefined( domain ) && domain == "doubletap" )
	{
		if ( !isdefined( self ) || !isplayer( self ) )
			return 0;
		if ( self HasPerk( "specialty_doubletap2" ) || ( self zm_perks::has_perk_paused( "specialty_doubletap2" ) ) )
			return 1;
		return 0;
	}
	return get_level( self, domain );
}

// self = player -> the class primary from the player's INVENTORY (held or
// holstered), or undefined. BULLET FEED needs this: the belt keeps loading
// while another weapon is out (user 2026-08-21 "it will work when gun is away
// too"), so we cannot read GetCurrentWeapon.
function class_primary_in_inventory()
{
	g = tod_classes::gun( self );   // the CURRENT tier's gun
	if ( !isdefined( g ) )
		return undefined;
	weapons = self GetWeaponsListPrimaries();
	foreach ( w in weapons )
	{
		if ( isdefined( w ) && IsSubStr( w.name, g.stem ) )
			return w;
	}
	// ADDITIVE CLASS (v18.30, the mage): any staff of a lower tier still counts
	// as the class primary -- for the watchdog, the PaP latch and the tier gate.
	foreach ( w in weapons )
	{
		if ( isdefined( w ) && tod_classes::name_is_class_stem( self, w.name ) )
			return w;
	}
	return undefined;
}

// ---------------------------------------------------------------------------
// DEV ONLY — SPAWN STRAIGHT INTO A MAXED CLASS (user 2026-09-01: "in dev mode
// spawn me in with maxed out mp7 skirmisher class").
// ---------------------------------------------------------------------------
// WHY THIS EXISTS: a balance change is judged at its CEILING, and reaching the
// ceiling honestly is a 40-minute climb. Every number retuned this session —
// the DR ladder, the SPRINT and DR band swap, the class-tier DPS steps — only
// becomes visible with the domains actually maxed.
//
// IT IS NOT A SECOND COPY OF _tod_spire::grant_all(). Both are POLICIES over the
// same PRIMITIVES: tier_up, domain_max, sync_max, apply_move_speed,
// reconcile_twin. The caps and ladders live in those and nowhere here, so a
// retune reaches this path for free. The differences from the spire grant are
// deliberate, not drift:
//   * NO PERKS. The spire grants all nine because ascension is a reward. Here
//     they would be a CONFOUND — Juggernog changes max HP, which is exactly
//     what a DMG REDUCTION test is measuring. Buy them if you want them.
//   * NO teardown, no music, no vendors. This is a loadout, not an event.
//
// ⚠️ THE FLOOR GATE IS STAMPED, NOT WAIVED. tier_up refuses a promotion until
// the player's own climb high-water clears floor 10 / 20 (v14.35), and that gate
// is deliberately NOT waived by tod_dev. So this stamps mark_top_reached() the
// same way the spire grant does — going through the real gate rather than
// around it, which is what keeps this path honest about the shipping rules.
//
// Gated by the dev callers in _tod_main. The normal class draft chooses the
// class; dev_class_max_loadout grants and logs its caps after the card pause.
// This primitive does not re-check level.tod_dev; keep callers guarded.
function dev_grant_maxed( player )
{
	// Threaded on the player, so self == player. The endons matter because this
	// function WAITS (for the loadout, and between promotions) and a disconnect
	// or game end mid-grant would otherwise run the rest against a dead entity -
	// the same guard _tod_spire::grant_all carries for the same reason.
	self endon( "disconnect" );
	level endon( "end_game" );

	if ( !isdefined( player ) || !isplayer( player ) )
		return;
	if ( !isdefined( player.tod_class ) )
		return;   // classless: nothing to promote or scope domains against

	// The class loadout is threaded off the spawn callback and waits 0.5s for
	// stock's own give to finish. tier_up resolves the CURRENT primary out of
	// inventory and bails if it is not there yet, so wait for the gun rather
	// than racing it.
	for ( i = 0; i < 40 && !isdefined( player class_primary_in_inventory() ); i++ )
		wait 0.05;

	// TIER to the top (skirmisher: MSMC -> MP5 -> MP7; slasher: Combat Knife
	// -> Katana -> Stormbreaker — the class comes from the caller). tier_card_eligible
	// wants the current gun PaP'd; the tod_pap_owned latch satisfies it and
	// reconcile pulls the _up form within a second.
	tod_gauge::mark_top_reached( player );
	for ( guard = 0; guard < 4 && tod_classes::tier( player ) < tod_classes::tier_max(); guard++ )
	{
		tod_classes::pap_first_grant( player, player class_primary_in_inventory() );
		if ( !( tier_up( player ) ) )
			break;
		wait 0.1;
	}

	// PaP the promoted primary, then the sidearm — which needs its own call,
	// because the latch is consumed by reconcile_twin and that stem-matches the
	// class PRIMARY only. Same reason the spire grant needs both.
	tod_classes::pap_first_grant( player, player class_primary_in_inventory() );
	player tod_classes::pap_secondary();

	// EVERY eligible domain to this player's cap, through the same fields and
	// the same LUI sync the card system uses, so the pause list stays truthful.
	if ( isdefined( level.tod_domains ) && isdefined( player.tod_levels ) )
	{
		for ( i = 0; i < level.tod_domains.size; i++ )
		{
			d = level.tod_domains[ i ];
			if ( !( domain_available( player, d ) ) )
				continue;
			cap = domain_max( player, d );
			if ( get_level( player, d.key ) >= cap )
				continue;
			player.tod_levels[ d.key ] = cap;
			player LuiNotifyEvent( &"tod_upg_sync", 3, tod_upgrade_ui::domain_id( d.key ), cap, sync_max( player, d ) );
		}
	}

	player apply_move_speed();
	player reconcile_twin();
	// DISTRACTION writes a level with no inventory; the guarded pointer is the
	// same lane the two shipping call sites use.
	if ( isdefined( level.tod_distract_reconcile ) )
		player [[ level.tod_distract_reconcile ]]();
	// RIOT SHIELD (domain 45): same lane, same reason — equipment is inventory
	// and this path writes a level. Pointer set in _tod_riotshield::init.
	if ( isdefined( level.tod_shield_reconcile ) )
		player [[ level.tod_shield_reconcile ]]();
	player refresh_upgrade_list();

	if ( IS_TRUE( level.tod_dev ) )
		player IPrintLnBold( "^2DEV^7: maxed " + player.tod_class + " T" + tod_classes::tier( player ) );
}

function reconcile_twin()   // self = player
{
	// SWAP LATCH (2026-08-22): a swap in flight (this walk from another thread,
	// or a tier-up) waits up to 1s for the switch to take — the body loop's
	// tick must not start a SECOND swap on the same player meanwhile (a third
	// primary = the engine silently drops one: the inventory-overflow trap).
	if ( IS_TRUE( self.tod_swap_busy ) || IS_TRUE( self.tod_tier_busy ) )
		return;
	g = tod_classes::gun( self );   // the CURRENT tier's gun (CLASS TIERS)
	if ( !isdefined( g ) )
		return;

	weapons = self GetWeaponsListPrimaries();
	foreach ( w in weapons )
	{
		g = tod_classes::gun_for_weapon( self, w );
		if ( !isdefined( g ) )
			continue;

		// PaP suffix differs per gun family ("_up" skye / "_upgraded" ballistic).
		// tod_pap_owned is the FREE-PaP DROP's latch (_tod_powerups::grab_pap):
		// once set, reconcile pulls the class gun to its _up form on the next
		// tick. Routing PaP through here instead of the stock upgrade path is
		// deliberate — the stock path worked on the PISTOL but not the class
		// guns (user 2026-08-21), and this builds a variant name we KNOW is
		// generated, then reuses the proven swap order below.
		is_up = tod_classes::pap_tier( self, w ) > 0;

		// DARK UPGRADES (v17.10): ask for the dark variant, and FALL BACK to the
		// plain one when it does not link. The dark rung only exists on the packed
		// TIER 3 gun of each class, so a player holding dark MAG SIZE on a Krig 6,
		// or dark anything while un-packed, asks for a name with no asset.
		//
		// THE FALLBACK IS THE WHOLE POINT. The bail below is "never take the
		// player's gun", which is right for a genuinely missing asset but would
		// FREEZE a dark holder on their old variant forever -- no error, no log
		// line, the pause menu reporting an upgrade that never applied. This is
		// also why no axisMaxUp mirror lives in GSC: the lookup IS the check.
		suffix = self twin_suffix_for( g, is_up );
		want_name = tod_classes::variant_name( g, is_up, suffix );
		if ( w.name == want_name && tod_classes::pap_staff_id( w ) == 0 )
			continue;

		want = tod_classes::weapon_or_zm( want_name );
		if ( !isdefined( want ) )
		{
			plain = self twin_suffix_for( g, false );
			if ( plain == suffix )
				return;   // variant not linked and no dark rung was asked for — never take the player's gun
			suffix = plain;
			want_name = tod_classes::variant_name( g, is_up, suffix );
			if ( w.name == want_name )
				return;
			want = tod_classes::weapon_or_zm( want_name );
			if ( !isdefined( want ) )
				return;   // neither links — never take the player's gun
		}

		// PAP CROSSING = FULL AMMO (v13.18, Workshop report "Yikes" 2026-08-29:
		// "i pap the stoner and my bullet size went from 60-25"). The delta
		// copy below preserved his 10 remaining rounds: 10 + (75-60) = the
		// exactly-25 on his screen, read as a capacity nerf. The delta is the
		// RIGHT rule for twin LEVEL walks — an upgrade card must never mint
		// free ammo — but base->_up here is the player's paid Pack-a-Punch,
		// and stock PaP has returned a FULL gun in every zombies title: the
		// 5000 buys the refill too. Detected as: the wanted form is _up while
		// the HELD form is not. (_up-to-_up level walks and base-to-base walks
		// keep the delta; the tier-up path already passes fresh=true itself.)
		want = tod_classes::staff_presentation( self, want );
		if ( is_up && tod_classes::pap_staff_id( w ) > 0 && !tod_classes::staff_is_packed( want ) )
			return;   // unresolved presentation must not strip an already packed staff
		if ( w == want )
			continue;
		crossing = ( is_up && !IsSubStr( w.name, g.up_suffix ) );
		if ( tod_classes::pap_staff_id( w ) > 0 )
			crossing = is_up && !tod_classes::staff_is_packed( w ) && tod_classes::staff_is_packed( want );
		self swap_primary( w, want, crossing );
		return;
	}
}

// self = player. THE swap: replace primary `w` with `want` — the twin walk
// (fresh = false, ammo DELTA-copied) and the tier-up (fresh = true, full
// start ammo: a promotion is a gift). Returns false if the player vanished
// mid-swap.
//
// MAP 1's PROVEN SWAP ORDER (_acc_weapon_variants.gsc:775-848): GIVE first
// (old form still in hand), IMMEDIATE switch, ammo set AFTER the switch (mag
// twins change clipSize — the delta keeps the copy from clamping), TAKE the
// old form LAST (take-first made the engine auto-raise another gun).
//
// THE HOLE THAT ORDER STILL HAD (user 2026-08-21: "it takes away your gun and
// places it in your inventory... always switches to my pistol"):
// SwitchToWeaponImmediate is silently EATEN in several player states
// (mid-sprint, mid-raise, mid-reload, ADS transition). When it is, `want`
// lands holstered, TakeWeapon(w) then removes the CURRENT gun, and the engine
// falls back to the pistol — and nothing ever corrects it, because the next
// reconcile sees the right twin already owned and returns early. Map 1
// survived this only because its reconcile re-fired on weapon_change_complete.
// FIX: VERIFY the switch took, retrying every frame BEFORE we take the old
// form (so the pistol never even flashes), and keep a short trailing
// re-assert after the take as the last line of defence.
// showcase (optional, v19.76 review): true ONLY from tier_up - the new gun
// keeps its first-raise flourish as the promotion's showcase (user: "I like the
// first draw only for showcase on tier promo"). Every other caller passes three
// arguments, so it is undefined and the flourish stays off.
function swap_primary( w, want, fresh, showcase )
{
	self.tod_swap_busy = true;   // reconcile_twin skips while a swap is in flight (cleared on EVERY exit)
	clip  = self GetWeaponAmmoClip( w );
	stock = self GetWeaponAmmoStock( w );
	cur   = self GetCurrentWeapon();
	// HELD = the engine's current weapon is the old form. A transitional
	// "none" (mid weapon-change) is treated as held too: if the player is
	// between weapons while we swap their CLASS primary, raising the new
	// form is the only outcome that never strands them on the pistol.
	// (If they are genuinely holding the pistol, cur == pistol -> not
	// held -> the swap happens silently in the holster, as it should.)
	held  = ( cur == w || cur == level.weaponNone );

	// THE CAMO RIDES IN THIS GIVE (v17.35). Weapon options are per-give and
	// nothing re-reads them, so a one-argument GiveWeapon here is what stripped
	// the packed look off the class primary on every twin swap — i.e. on every
	// gun-scoped level-up after the pack.
	// Attachment changes share one native root slot. Remove it before giving
	// the new attachment set; taking the old object afterward can remove both.
	// Different-root handling twins retain their established swap order.
	same_root = ( w.rootWeapon == want.rootWeapon );
	if ( same_root )
		self TakeWeapon( w );
	want = self tod_classes::give_camo_weapon( want );
	// v19.76 — NO FIRST-RAISE FLOURISH ON AN UPGRADE SWAP (lead tester Nikolai,
	// Oct 2026: "When you get upgraded swing it will give you a animation of him
	// testing out his bat. During that animation you cant cancel to swing bat, this
	// can cause a death ... This same thing happens when you upgrade to your tier 2
	// or tier 3 primary weapon also"). Every swap here hands over a NEW weapon
	// object, and the engine plays a new weapon's first-raise clip the first time
	// it comes up — the bat's showcase twirl, a gun's inspect — and nothing cancels
	// it. A card's twin walk, a tier promotion and a Pack-a-Punch DROP all land
	// here, usually mid-fight. Staffs are left to give_camo_weapon, which decides
	// their first raise on purpose (the packed-head presentation, Mystical Hands).
	// THE PAID MACHINE IS THE EXCEPTION (review, same day): a 5,000 tower PaP of a
	// class gun also lands here (zm_cwpap -> pap_first_grant -> reconcile_twin), and
	// that purchase always showed the packed gun's first raise. zm_cwpap stamps
	// tod_pap_flourish_ms at the buy; a fresh crossing inside 3 s of it keeps the
	// engine's flourish, and the stamp is spent either way.
	// AND THE TIER PROMOTION (user, on the review: "I like the first draw only for
	// showcase on tier promo"): tier_up passes showcase, and the new tier's gun
	// comes up with its first raise. So the flourish plays on exactly two
	// occasions - a promotion and the paid machine - and never on a card's level
	// swap or the free PaP drop (the tester's report).
	machine_show = ( IS_TRUE( fresh ) && isdefined( self.tod_pap_flourish_ms ) && ( GetTime() - self.tod_pap_flourish_ms ) <= 3000 );
	self.tod_pap_flourish_ms = undefined;
	if ( tod_classes::pap_staff_id( want ) == 0 && !machine_show && !IS_TRUE( showcase ) )
		self ShouldDoInitialWeaponRaise( want, false );
	if ( held )
	{
		for ( i = 0; i < 20; i++ )   // up to 1s of frames
		{
			self SwitchToWeaponImmediate( want );
			if ( self GetCurrentWeapon() == want )
				break;
			wait 0.05;
			if ( !isdefined( self ) )
				return false;   // player gone mid-swap (the latch dies with the entity)
			// WENT DOWN MID-SWAP (audit 2026-08-26): the ENGINE owns the weapon in
			// last stand — it has just forced the crawl pistol — so re-issuing
			// SwitchToWeaponImmediate here is a fight we cannot win and would only
			// yank the pistol out of a downed player's hands.
			// `break`, NEVER `return false`: the swap must still complete
			// atomically through the TakeWeapon( w ) below, or the player is left
			// holding BOTH gun forms, which is strictly worse than the status quo.
			// ensure_equipped already bails on laststand, so nothing downstream
			// fights the pistol either.
			if ( self laststand::player_is_in_laststand() )
				break;
			if ( !( self HasWeapon( want ) ) )
			{
				self.tod_swap_busy = undefined;
				return false;   // weapon stripped mid-swap — bail clean
			}
		}
	}
	if ( IS_TRUE( fresh ) )
	{
		self GiveStartAmmo( want );
	}
	else
	{
		new_clip  = clip  + ( want.clipSize - w.clipSize );
		new_stock = stock + ( want.maxAmmo  - w.maxAmmo );
		if ( new_clip < 0 )
			new_clip = 0;
		if ( new_stock < 0 )
			new_stock = 0;
		self SetWeaponAmmoStock( want, new_stock );
		self SetWeaponAmmoClip( want, new_clip );
	}
	if ( !same_root )
		self TakeWeapon( w );
	self tod_classes::staff_presentation_log( want, "swap complete fresh=" + fresh );
	if ( held )
		self thread ensure_equipped( want );
	self.tod_swap_busy = undefined;
	return true;
}

// self = player. Trailing re-assert after a twin swap: if the engine STILL
// ended up on another gun (it can auto-raise a fallback in the same frame as
// the take), pull the twin back up. Bounded, frame-paced, stops the moment
// it lands; never fights last stand (the engine owns the weapon there).
function ensure_equipped( want )
{
	self endon( "disconnect" );
	level endon( "end_game" );
	self notify( "tod_ensure_equipped" );   // newest swap wins
	self endon( "tod_ensure_equipped" );

	for ( i = 0; i < 30; i++ )   // up to 1.5s
	{
		wait 0.05;
		if ( !isdefined( want ) || !( self HasWeapon( want ) ) )
			return;
		if ( self laststand::player_is_in_laststand() )
			return;
		if ( self GetCurrentWeapon() == want )
			return;
		self SwitchToWeaponImmediate( want );
	}
}

function get_level( player, key )
{
	if ( !isdefined( player.tod_levels ) || !isdefined( player.tod_levels[ key ] ) )
		return 0;
	return player.tod_levels[ key ];
}

// PERK SLOTS — the per-player cap (restored v17.3). self = PLAYER, no args:
// stock calls it as `self [[ level.get_player_perk_purchase_limit ]]()`
// (_zm_utility.gsc:5881), so the signature is not ours to choose.
//
// THE SPIRE FLOOR (v14.60's rule, kept). Ascension grants EVERY perk the map
// sells and `perma_perks_watch` re-gives the roster after every revive and
// respawn — none of that is a purchase, but stock's own validation and the
// perk bottle both read this limit, so a 4-cap in the spire would start
// refusing perks the player is supposed to already have. The floor is the
// ROSTER SIZE, counted from the .map (nine zm_perk_machine entities) rather
// than assumed: if a tenth machine is ever added this number must move with
// it, which is exactly the lockstep v16.80 complained about — so it is stated
// here once and nowhere else.
#define TOD_PERK_ROSTER 9
function perk_slot_limit()
{
	n = TOD_PERK_SLOT_BASE + get_level( self, "perkslots" );
	if ( IS_TRUE( level.tod_spire_active ) && n < TOD_PERK_ROSTER )
		n = TOD_PERK_ROSTER;
	return n;
}

// (add_luck REMOVED 2026-08-20 — the integer event-luck became the 0..100%
// LUCK BAR, owned by _tod_luck.gsc; sources call tod_luck::add/boss_kill.)

// ---------------------------------------------------------------------------
// UPGRADE LIST — PAUSE MENU ONLY (user 2026-08-20: the always-on hudelem
// column cluttered the play HUD). Channel = map 1's PROVEN per-player
// LuiNotifyEvent lane (its kill feed: LuiNotifyEvent -> scriptNotify
// PerController model -> CoD.GetScriptNotifyData). SetClientDvar does NOT
// exist in T7 (stock has it commented "TODO T7 - function port if needed"),
// and host SetDvar never replicates to co-op peers — this lane does.
// INT-ONLY args (domain id / level / max): string args ride the
// CS_LOCALIZED_STRINGS config-string table, and unique dynamic strings
// would leak slots forever on an endless map. tod_upgrade.lua accumulates
// the pairs into CoD.TodOwned; AetheriumStartMenu.lua renders that table
// (same client Lua VM) on every pause-menu open.
// ---------------------------------------------------------------------------

function ensure_upgrade_list()   // self = player
{
	self endon( "disconnect" );
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );
	wait 1;   // the HUD menu hosts the scriptNotify listener — let it open first
	self tod_upgrade_ui::ensure_menu();
	self refresh_upgrade_list();
}

function refresh_upgrade_list()   // self = player
{
	for ( i = 0; i < level.tod_domains.size; i++ )
	{
		d = level.tod_domains[ i ];
		lvl = get_level( self, d.key );
		if ( lvl > 0 )
			self LuiNotifyEvent( &"tod_upg_sync", 3, tod_upgrade_ui::domain_id( d.key ), lvl, sync_max( self, d ) );
	}
	// CLASS TIER row (id 24): pips = the tier. Same int-only lane.
	//
	// SENT FROM TIER 1 SINCE v14.35 (was tier 2 on, "tier 1 is the baseline,
	// not an upgrade"). The row is no longer just a trophy — its detail line
	// now states what the NEXT promotion costs (Pack-a-Punch + the floor gate),
	// and a tier-1 player is precisely the one who needs to read it. A missing
	// row cannot explain anything.
	//
	// SAFE FOR THE PANEL'S atTopTier TEST, checked rather than assumed: that
	// test is `lvl >= max` with an explicit nil path documented as "ABSENT
	// MEANS TIER 1". Sending 1 of 3 takes the same branch the nil path took,
	// so the reset badges still show for a tier-1 player exactly as before.
	t = tod_classes::tier( self );
	self LuiNotifyEvent( &"tod_upg_sync", 3, tod_upgrade_ui::domain_id( "tier" ), t, tod_classes::tier_max() + TOD_SYNC_SAFE_FLAG );   // the tier row IS the promotion — always "safe"
}

// ---------------------------------------------------------------------------
// Event scheduling — every Nth round boundary (rounds 4, 7, 10, ...)
// ---------------------------------------------------------------------------

function event_scheduler()
{
	level endon( "end_game" );

	last = 1;
	for ( ;; )
	{
		wait 0.5;
		r = level.round_number;
		if ( !isdefined( r ) || r == last )
			continue;
		last = r;
		// THE LAST MILE (v10): no upgrade events once the finale run starts.
		// The run's clock is the closing song, and an upgrade freeze stops the
		// world but NOT a music stream — every card pick would slide the ending
		// further out of sync with the track. `last` is still advanced above, so
		// nothing queues up and fires in a burst afterwards; the events are
		// SKIPPED, not deferred. (_tod_finale sets the flag; the game ends before
		// it would ever need clearing.)
		if ( IS_TRUE( level.tod_upgrades_suppressed ) )
			continue;
		// NOT INSIDE A SEALED TRIAL OR THE KING'S LANDING (bug review
		// 2026-09-22, F02/F03). Rounds keep turning over under the trial
		// trickle; a scheduled deal opening there ate trial-clock seconds,
		// raced the trial's own reward deal (run_upgrade_event is not
		// re-entrant) and, during the King's countdown, held the pause that
		// made his landing fail. SKIPPED like the finale, not deferred. The
		// King FIGHT itself (tod_king_active after the landing) still deals.
		if ( IS_TRUE( level.tod_king_landing ) )
			continue;
		if ( IS_TRUE( level.tod_trial_active ) && !IS_TRUE( level.tod_king_active ) )
			continue;
		// DEV: an upgrade every round from round 2. SHIP: every 4th round.
		// [tod v19.9] tod_dev_upgrades, not tod_dev — see the flag block in
		// zm_tower_of_doom::tod_resolve_dev_flags. A dev session that wants god +
		// money + doors does not want a card panel every round on top.
		if ( IS_TRUE( level.tod_dev_upgrades ) )
		{
			if ( r > 1 )
				run_upgrade_event();
		}
		else if ( r >= TOD_UPG_EVERY_N_SHIP && ( r % TOD_UPG_EVERY_N_SHIP ) == 0 )
		{
			run_upgrade_event();
		}
	}
}

function run_upgrade_event()
{
	// Only players with something left to upgrade participate. If NOBODY has
	// (late-game, everything maxed) skip the whole event — no pause, no spam.
	participants = [];
	players = GetPlayers();
	foreach ( p in players )
	{
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		// The native dev preview player cannot choose a card. Humans and normal
		// matches retain the usual participation rules.
		if ( IS_TRUE( level.tod_dev ) && IS_TRUE( p.tod_dev_mage_dummy ) )
			continue;
		// A CRAWLER PARTICIPATES; A DEAD/SPECTATING PLAYER DOES NOT (v15 item 9,
		// user 2026-08-31: "When you are down and an upgrade round comes by you
		// should still be able to select a card").
		//
		// LAST STAND WAS EXCLUDED HERE FROM 2026-08-23, and that reason has since
		// been paid off. The original argument was that stock's bleedout loop does
		// not pause with the world, so a crawler dealt a card burned up to 20s of
		// a ~30s clock while every teammate stood frozen at
		// SetMoveSpeedScale(0.001) and could not reach them. That is now REFUNDED
		// explicitly further down this same function (the bleedout_time += waited
		// line), so the freeze costs a crawler nothing and the exclusion was
		// outliving its justification. The pause is capped at
		// TOD_UPG_CHOICE_TIMEOUT either way.
		//
		// IsAlive() IS TRUE IN LAST STAND (stock contract), so !isalive(p) alone
		// is exactly the dead/spectating test and nothing more.
		//
		// DEAD PLAYERS STAY OUT, for a reason no refund can fix: the engine
		// closes a player's LUI menus on death->spectate, so there is no panel to
		// draw a card on. Dealing to them would be the 2026-08-23 bug in a new
		// costume — a card nobody can pick, holding the world open.
		//
		// menu_freeze still refuses to freeze a laststand player (see it above),
		// which is now a FEATURE rather than a mismatch: the crawler keeps
		// crawling — and keeps being revivable — while they read their two cards.
		if ( !isalive( p ) )
			continue;
		p.tod_tier_deal_pre = undefined;
		// v17.70 THE KING'S DARK DEALS: only the dark pool decides who plays —
		// every regular domain is already at cap (king_max_out ran first) and
		// the tier card is not this deal's business.
		if ( IS_TRUE( level.tod_dark_only ) )
		{
			if ( dark_allowed() && dark_pool( p ).size > 0 )
				participants[ participants.size ] = p;
			continue;
		}
		if ( player_has_domains_left( p ) )
			participants[ participants.size ] = p;
		// DARK UPGRADES (v17.10) — THE THIRD ARM, and the feature does not work
		// without it. A player who has maxed everything they can reach falls
		// straight past the first test, and before this line the only thing that
		// could still admit them was a tier-card roll. That is precisely the
		// player a dark card is for: `trial_upgrade_deal` would have dealt them
		// nothing at all.
		else if ( dark_allowed() && dark_pool( p ).size > 0 )
			participants[ participants.size ] = p;
		else if ( tier_card_eligible( p ) && tier_card_roll( p ) )   // v16.56: full bar = guaranteed, else TOD_TIER_CARD_PCT
		{
			// CLASS TIERS: a MAXED player is only here for the tier chance — it is
			// rolled NOW (consumed by roll_options) so a miss never pauses the
			// world for an empty deal.
			p.tod_tier_deal_pre = true;
			participants[ participants.size ] = p;
		}
		else
		{
			// DEV ONLY (v16.70): a maxed player dealt nothing — say WHY the tier
			// card did not come (the reason ladder in tier_deny_reason).
			if ( IS_TRUE( level.tod_dev ) )
				tod_quiet_print( p.name + ": no deal - tier card: " + tier_deny_reason( p ) );
			if ( !IS_TRUE( p.tod_upg_maxed_told ) )
			{
				p.tod_upg_maxed_told = true;   // tell them ONCE, not every round
				// (on-screen text removed 2026-08-20 — user: no floaty text)
			}
		}
	}
	if ( participants.size == 0 )
		return;

	// ONE DEAL AT A TIME (bug review 2026-09-22, F02). This function shares
	// level.tod_upg_pending, the card clientfields and the single menu_freeze
	// flag across every participant; a second call over a live one reset the
	// counter, started a second flow on players still deciding and released
	// the world pause under a teammate still frozen. Queue behind the live
	// deal instead (bounded: every deal ends within choice_timeout()+5).
	while ( IS_TRUE( level.tod_upg_event_live ) )
		level waittill( "tod_upg_event_over" );
	level.tod_upg_event_live = true;
	level.tod_upg_event_takeover = true;   // solo_present_interruptible: a REAL takeover, not a raw pause

	set_world_pause( true );

	// The round event OWNS the shared card UI: any in-flight PERSONAL STATION
	// pick dies on this notify (synchronous — its thread is dead before our
	// per-player flows below touch the fields) and re-presents after we end.
	//
	// AND IT OWNS THE WORLD PAUSE TOO (v16.84). A SOLO station pick now freezes
	// the world itself, so a takeover can land on a pause this function did not
	// open — and the set_world_pause( false ) at the bottom would then clear a
	// station's freeze out from under a player still reading cards. Claiming it
	// here, before any yield and in the same synchronous block as the notify,
	// turns that station's station_pause_end() into a no-op: this event now
	// owns both lanes, and its player_choice_flow re-freezes and unfreezes the
	// player like any other participant. (Solo only ever has ONE owner, so
	// there is nothing to iterate.)
	level.tod_station_pause_owner = undefined;
	level notify( "tod_global_upg_takeover" );

	level.tod_upg_pending = 0;
	foreach ( p in participants )
	{
		p.tod_upg_done = false;
		level.tod_upg_pending++;
		p thread player_choice_flow();
	}

	// Co-op: everyone sees who is still deciding.
	if ( participants.size > 1 )
		level thread waiting_display( participants );

	// Wait for every participant (each flow decrements; 15s timeout inside).
	waited = 0;
	while ( level.tod_upg_pending > 0 && waited < ( choice_timeout() + 5 ) )
	{
		wait 0.25;
		waited += 0.25;

		// REFUND THE BLEEDOUT LIVE (bug review 2026-09-22, F08). The lump refund
		// below only reaches players still crawling when the deal ends; a
		// crawler whose clock was shorter than the freeze bled out under it,
		// with every teammate frozen. Stock's Laststand_Bleedout re-reads
		// bleedout_time every second, so crediting each tick simply extends it.
		foreach ( p in GetPlayers() )
		{
			if ( isdefined( p ) && ( p laststand::player_is_in_laststand() ) && isdefined( p.bleedout_time ) )
				p.bleedout_time += 0.25;
		}

		// A PLAYER WHO LEAVES MID-PICK NEVER DECREMENTS (audit 2026-08-26).
		// player_choice_flow carries `self endon( "disconnect" )` and does its
		// level.tod_upg_pending-- as the LAST thing it does, so a disconnect
		// anywhere in the pick loses that decrement and this loop then burns the
		// FULL TOD_UPG_CHOICE_TIMEOUT + 5 = 20s with the world frozen: zombies
		// standing still, spawning halted, and every pause-gated device
		// (teleporters, ammo crate, the stations) refusing. Nothing on screen
		// explains it, because the leaver's card panel left with them.
		//
		// Re-derive the count from who is actually still here and still
		// deciding. This is the sibling of the downed/dead participant filter
		// above: both say "only wait on players who can actually answer".
		//
		// CLAMP DOWN ONLY, never assign — that keeps the counter authoritative
		// against any future path that increments it, and it cannot resurrect a
		// pause that has already ended. tod_upg_done is set immediately before
		// each decrement with no yield in between, so `live` equals the counter
		// for every connected player.
		//
		// player_choice_flow, both its endons and both decrement sites are
		// deliberately left byte-identical — no pick behaviour changes. Do NOT
		// "fix" this by replacing the disconnect endon with a watcher (double
		// decrement), and do NOT add endon( "end_game" ) to this function: that
		// would skip the set_world_pause( false ) below and freeze the world
		// permanently.
		live = 0;
		foreach ( p in participants )
		{
			if ( isdefined( p ) && !IS_TRUE( p.tod_upg_done ) )
				live++;
		}
		if ( live < level.tod_upg_pending )
			level.tod_upg_pending = live;
	}

	level notify( "tod_upg_event_over" );

	players = GetPlayers();
	foreach ( p in players )
	{
		if ( !isdefined( p ) )
			continue;
		// GIVE THE PAUSED SECONDS BACK TO ANYONE STILL DOWN (audit 2026-08-26).
		// Stock's Laststand_Bleedout decrements self.bleedout_time on a REAL-TIME
		// wait(1) and knows nothing about our world pause, so a player who was
		// already crawling when the event fired just burned up to 20s of a ~30s
		// clock during a window in which every living teammate was frozen at
		// SetMoveSpeedScale( 0.001 ) and could not physically reach them.
		//
		// SAFE AGAINST STOCK'S ANTI-CHEESE CLAMP: Laststand_Bleedout captures
		// n_bleedout_time = self.bleedout_time ONCE (_zm_laststand.gsc:538),
		// before either of its loops, so the snap-back at :545-551 — which fires
		// only when that CAPTURED value exceeds the dvar default and no
		// multiplier is set — cannot be tripped by a later write to the field.
		// Both loops re-read self.bleedout_time each iteration, so raising it
		// simply extends the timer.
		//
		// KNOWN COSMETIC LIMIT, ACCEPTED: the Aetherium bleedout bar animates a
		// fixed linear tween client-side, so credited seconds do not show — the
		// bar can read empty while the player is still revivable. Do NOT extend
		// the Lua to chase this.
		// (2026-09-22: the credit is now paid per tick inside the loop above —
		// see the F08 note there. Nothing is owed here any more.)
		// clear the waiting line (the display thread may have died mid-loop).
		// v19.58: the line is the HUD's now; 0 hides it.
		p tod_upgrade_ui::choosing_push( 0 );
		p.tod_upg_wait_text = undefined;
	}

	// THE LUCK BAR IS SPENT BY PARTICIPANTS ONLY (audit 2026-08-26). This used
	// to ride the GetPlayers() loop above, so a player who was DOWN or DEAD when
	// the event fired — and was therefore deliberately excluded from it at the
	// participant filter, dealt no cards and given no roll — still had their
	// entire luck bar zeroed. Going down at a round boundary silently cost them
	// everything they had banked toward the next event's odds.
	//
	// `participants` is already in scope and is exactly the right set; do NOT
	// invent a per-player "was a participant" marker, which would go stale
	// across events.
	foreach ( p in participants )
	{
		if ( isdefined( p ) )
			p.tod_luck_bar = 0;   // fully spent on this event's rolls (user: full reset)
	}

	// v17.70: the king's dark deals hold the freeze ACROSS deals (the world
	// must not thaw for a frame between two panels) — king_run releases it.
	if ( !IS_TRUE( level.tod_upg_hold_pause ) )
		set_world_pause( false );
	level.tod_upg_event_takeover = undefined;
	level.tod_upg_event_live = undefined;
	level notify( "tod_upg_event_over" );   // wakes a queued deal (the first notify above is for the station lanes)
}

// The pick window for THIS deal: the king's 10 s override, else the define.
function choice_timeout()
{
	if ( isdefined( level.tod_upg_timeout_override ) )
		return level.tod_upg_timeout_override;
	return TOD_UPG_CHOICE_TIMEOUT;
}

// ---------------------------------------------------------------------------
// THE WARDEN KING (v17.70, user 2026-09-05): "the game will behind the scenes
// make sure all players have all their upgrades maxed out. Then it will prompt
// all the users the rest of their dark upgrade with a 10s timer and continue
// prompting everyone until everyone has all their cards. If you are already
// maxed you will stay frozen until all players are done."
// _tod_spire::king_run calls the two in order under its own world pause.
// ---------------------------------------------------------------------------

// Every living player: every domain they can reach to its cap — the
// dev_grant_maxed domain loop, minus the tier/PaP half (the build stays the
// build; only the CARDS are filled in). Silent: no cards, no sting.
function king_max_out()
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		king_max_player( p );   // v19.11: yields internally, so co-op players no longer stack their bursts into one frame
	}
}

// v19.11 — THE KING'S SYNC BURST IS SPREAD OVER FRAMES (Workshop, barn
// 2026-09-15: "we finally got to the warden king and immediately crashed").
//
// NOT A PROVEN CAUSE — no log, never reproduced. It is the SUSPECT because it
// is the map's largest single-frame client-event burst and it happens at
// exactly that moment. king_max_player sent one LuiNotifyEvent per eligible
// domain with no yield (43 domains) and then called refresh_upgrade_list,
// which sends another per OWNED domain plus the tier row — so ~87 scriptNotify
// writes per player in ONE server frame, and king_max_out looped every player
// with no yield between them either: ~174 in a frame for a duo, ~350 for a
// quad. Nothing else in normal play comes close (the only other 40-at-once
// sender, dev_grant_maxed, is dev-only and nothing threads it in a ship build;
// refresh_upgrade_list on its own runs once per card pick).
//
// THE FIX COSTS NOTHING HERE, which is why it is worth taking on a suspicion:
// the whole max-out runs inside king_run's world pause, so the extra fraction
// of a second is spent on a frozen board that the player cannot act on, and
// the freeze is released by the caller after the dark deals either way.
//
// Waiting inside this function is safe: every caller is king_max_out, which is
// called from king_run's own thread and has nothing time-critical after it.

function king_max_player( player )
{
	if ( !isdefined( player.tod_class ) || !isdefined( level.tod_domains ) )
		return;
	if ( !isdefined( player.tod_levels ) )
		player.tod_levels = [];
	sent = 0;
	for ( i = 0; i < level.tod_domains.size; i++ )
	{
		d = level.tod_domains[ i ];
		if ( !( domain_available( player, d ) ) )
			continue;
		cap = domain_max( player, d );
		if ( get_level( player, d.key ) >= cap )
			continue;
		player.tod_levels[ d.key ] = cap;
		player LuiNotifyEvent( &"tod_upg_sync", 3, tod_upgrade_ui::domain_id( d.key ), cap, sync_max( player, d ) );
		sent++;
		if ( sent % TOD_SYNC_BURST == 0 )
		{
			wait 0.05;
			if ( !isdefined( player ) || !isplayer( player ) )
				return;   // left mid-burst; the rest of this player's writes are moot
		}
	}
	player apply_move_speed();
	player reconcile_twin();
	if ( isdefined( level.tod_distract_reconcile ) )
		player [[ level.tod_distract_reconcile ]]();
	if ( isdefined( level.tod_shield_reconcile ) )
		player [[ level.tod_shield_reconcile ]]();
	// The list refresh is its OWN burst of the same size — give it its own frame
	// rather than landing it on the last one of the loop above.
	wait 0.05;
	if ( !isdefined( player ) || !isplayer( player ) )
		return;
	player refresh_upgrade_list();
}

// Does any living player still have a dark card to take?
function king_any_dark_left()
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		if ( dark_pool( p ).size > 0 )
			return true;
	}
	return false;
}

function king_freeze_all( on )
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) )
			continue;
		p menu_freeze( on );
	}
}

// The dark deals: THE REAL run_upgrade_event, dark-only, 10 s a pick, again
// and again until nobody alive has a dark card left. Everyone is frozen for
// the whole of it (the hold makes every menu_freeze( false ) a no-op), the
// world pause is held across deals, and both are released here — the caller
// releases the world pause it opened.
function king_dark_deals()
{
	level endon( "end_game" );

	level.tod_king_hold = true;
	level.tod_upg_hold_pause = true;
	level.tod_upg_timeout_override = TOD_KING_DARK_SECS;
	level.tod_dark_only = true;
	level.tod_dark_guarantee = true;
	king_freeze_all( true );
	// a player can hold at most one dark card per domain, two per deal
	for ( guard = 0; guard < 40 && king_any_dark_left(); guard++ )
	{
		run_upgrade_event();
		king_freeze_all( true );   // a late joiner / a revive since the last deal
		wait 0.5;
	}
	level.tod_dark_only = undefined;
	level.tod_dark_guarantee = undefined;
	level.tod_upg_timeout_override = undefined;
	level.tod_upg_hold_pause = undefined;
	level.tod_king_hold = undefined;
	king_freeze_all( false );
}

// LEECH — LOGARITHMIC, not linear (user 2026-08-23: "the leech HP ... increase
// logorithimcally for both instead of linearly per level. It ends up getting
// crazy"). WAS TOD_UPG_LEECH_PER_LVL * lvl = 4/8/12/16/20 HP per blade kill —
// at Lv5 that is a full fifth of a base health bar PER KILL, and the slasher
// one-hits into the teens, so it healed faster than the horde could hurt it.
// NOW round( 4 * log2(1+Lv) ), tabulated: 4 / 6 / 8 / 9 / 10.
// LEVEL 1 IS UNCHANGED at 4 on purpose — the first point spent feels exactly as
// it did; the TAIL is halved (20 -> 10). Same shape as the k-ladder nerf in
// tools/gen_tod_twins.js (KNIFE_STEP), and the two were tuned together.
// A TABLE, not a log() call: GSC has no reliable log2, the shipped numbers
// should be readable here, and the pause-menu detail row in tod_upgrade.lua
// DETAIL[13] must mirror these exactly.
function leech_hp_for_level( lvl )
{
	switch ( lvl )
	{
		case 0:  return 0;
		case 1:  return 4;
		case 2:  return 6;
		case 3:  return 8;
		case 4:  return 9;
		default: return 10;   // Lv5 (and any future cap raise clamps here)
	}
}

// Any rollable DOMAIN below its cap?
function player_has_domains_left( player )
{
	for ( i = 0; i < level.tod_domains.size; i++ )
	{
		d = level.tod_domains[ i ];
		if ( !domain_available( player, d ) )
			continue;
		if ( get_level( player, d.key ) < domain_max( player, d ) )
			return true;
	}
	return false;
}

function player_has_upgrades_left( player )
{
	if ( player_has_domains_left( player ) )
		return true;
	// DARK UPGRADES (v17.10): a player with every domain maxed is exactly who
	// the feature exists for, and without this they are dropped from the event
	// by run_upgrade_event's participant filter BEFORE the roll ever happens.
	if ( dark_allowed() && dark_pool( player ).size > 0 )
		return true;
	// CLASS TIERS: a player with every domain maxed still has the promotion to
	// play for — they can still buy at a station for the tier chance alone
	// (run_upgrade_event pre-rolls that chance before pausing the world).
	return tier_card_eligible( player );
}

// self = player
function player_choice_flow()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	opts = roll_options( self );
	if ( !isdefined( opts ) )   // belt+braces (participants are pre-filtered)
	{
		self.tod_upg_done = true;
		level.tod_upg_pending--;
		return;
	}

	// (card luck banner now reads player.tod_luck_bar directly in
	// present_choice — the old combined event+domain integer is gone)

	self push_panel_hints();   // v14.35 — "CLASS TIER 2 - REACH FLOOR 10" under the cards, or nothing
	self menu_freeze( true );
	choice = self tod_upgrade_ui::present_choice( opts, choice_timeout() );   // v17.70: the king's 10 s override, else 15
	self menu_freeze( false );

	picked = opts[ 0 ];
	other = opts[ 1 ];   // may be undefined (single-card deal)
	if ( choice == 2 && isdefined( opts[ 1 ] ) )
	{
		picked = opts[ 1 ];
		other = opts[ 0 ];
	}

	// (timeout text removed 2026-08-20 — user: no floaty text)

	// A REFUSED TIER PICK (timed out on the tier card, or the promotion could
	// not land) must not forfeit the deal — the other card pays out instead.
	ok = apply_upgrade( self, picked );
	if ( !ok && picked.domain == "tier" && isdefined( other ) && other.domain != "tier" )
		apply_upgrade( self, other );
	self.tod_upg_done = true;
	level.tod_upg_pending--;
}

// One small line on every player's screen: who is still deciding. Since v19.58
// the HUD draws it in the map's typeface (tod_upgrade.lua "tod_choosing"); this
// thread only pushes a change-gated bitmask of the players still picking.
function waiting_display( participants )
{
	level endon( "end_game" );
	level endon( "tod_upg_event_over" );

	for ( ;; )
	{
		wait 0.3;

		// v19.58 (the typography pass): the line is drawn by the HUD in the map's
		// typeface (tod_upgrade.lua, "tod_choosing"); the server only sends WHO,
		// as a bitmask of entity numbers, and only when it changes. The old
		// y 74 (above the UPGRADE AVAILABLE banner, audit 2026-08-25) is the
		// Lua's CHOOSING_T now.
		mask = 0;
		bits = array( 1, 2, 4, 8 );
		foreach ( p in participants )
		{
			if ( !isdefined( p ) || IS_TRUE( p.tod_upg_done ) )
				continue;
			n = p GetEntityNumber();
			if ( n >= 0 && n < 4 )
				mask += bits[ n ];
		}
		if ( mask == 0 )
			return;

		players = GetPlayers();
		foreach ( viewer in players )
		{
			if ( !isdefined( viewer ) )
				continue;
			if ( !isdefined( viewer.tod_upg_wait_text ) || viewer.tod_upg_wait_text != mask )
			{
				viewer tod_upgrade_ui::choosing_push( mask );
				viewer.tod_upg_wait_text = mask;
			}
		}
	}
}

// ---------------------------------------------------------------------------
// Rolls
// ---------------------------------------------------------------------------

// Returns array of 1-2 option structs { domain, display, desc, rarity,
// rarity_name, levels, cur }, or undefined if everything is maxed.
function roll_options( player )
{
	// v17.70 THE KING'S DARK DEALS: the hand is the dark pool and nothing else
	// (participants were filtered on it; deal_dark fills both slots when two
	// are owed — TOD_DARK_BOTH_PCT).
	if ( IS_TRUE( level.tod_dark_only ) )
	{
		if ( !dark_allowed() || dark_pool( player ).size == 0 )
			return undefined;
		return deal_dark( player, [] );
	}
	pool = eligible_pool( player );
	// CLASS TIER card (docs/25 §4.2): once the class gun is PaP'd, this deal
	// carries the promotion TOD_TIER_CARD_PCT of the time — rolled ONCE per
	// deal, here, so a maxed-out player (empty pool) gets exactly the same
	// chance as anyone else.
	if ( isdefined( player.tod_tier_deal_pre ) )
	{
		tier_deal = IS_TRUE( player.tod_tier_deal_pre );   // pre-rolled by run_upgrade_event (maxed player)
		player.tod_tier_deal_pre = undefined;
	}
	else
	{
		// v14.39 — the roll asks tier_card_ready_but_for_floor, NOT the full
		// eligibility, so a floor-blocked player still DRAWS the promotion and
		// is shown it locked. Everything else about the roll is unchanged: the
		// same TOD_TIER_CARD_PCT, once per deal. What the floor decides now is
		// whether the dealt card is takeable, not whether it exists.
		tier_deal = ( tier_card_ready_but_for_floor( player ) && tier_card_roll( player ) );   // v16.56: full bar + fully eligible = guaranteed (tier_card_roll)
	}
	// DEV ONLY (v16.70, user 2026-09-03: "when you have max luck and are
	// eligible ... guaranteed the class upgrade card. I think that's not working
	// properly"): the card's ABSENCE looks the same for every reason it can be
	// withheld, so name the reason on every dev deal that lacks it.
	if ( IS_TRUE( level.tod_dev ) && !tier_deal )
		tod_quiet_print( "tier card not dealt: " + tier_deny_reason( player ) );

	if ( pool.size == 0 )
	{
		// DARK UPGRADES (v17.10): this early return is exactly where a
		// fully-maxed player used to be turned away with nothing, which is the
		// player the feature is for. If a dark card is owed, the hand is built
		// from the dark pool instead of refused.
		if ( dark_allowed() && IS_TRUE( level.tod_dark_guarantee ) && dark_pool( player ).size > 0 )
		{
			opts = deal_dark( player, [] );
			// The tier card still owns the RIGHT slot when it is dealt AND
			// takeable. A floor-blocked (locked) tier card is simply not shown on
			// this path — the normal path deals it locked beside another card, but
			// here the dark card is the deal and a locked companion adds nothing.
			if ( tier_deal && tier_floor_pending( player ) == 0 )
				opts[ 1 ] = make_tier_option( player );
			return opts;
		}
		if ( !tier_deal )
			return undefined;
		// A LOCKED CARD CANNOT BE THE WHOLE DEAL. With no domains left and the
		// promotion out of reach, presenting it alone would freeze the world for
		// a panel with nothing selectable on it — the player would sit through
		// the full timeout unable to answer, which is the leaver-stall bug's
		// shape with a different cause. Deal nothing instead; the round event's
		// participant filter already declines to pause for this player
		// (player_has_upgrades_left asks the FULL eligibility), and this guards
		// the station path that does not go through that filter.
		if ( tier_floor_pending( player ) > 0 )
			return undefined;
		opts = [];
		opts[ 0 ] = make_tier_option( player );   // the only card left — still opt-in (a timeout never takes it)
		return opts;
	}

	// v8.9 TIER DRAW (user 2026-08-21): no longer a flat shuffle — each domain
	// is offered in proportion to its tier weight, so S cards surface ~5x less
	// often than B. Drawn WITHOUT replacement so the two cards stay distinct.
	opts = [];
	first = weighted_draw( pool );
	opts[ 0 ] = make_option( player, pool[ first ] );
	if ( pool.size > 1 )
	{
		rest = [];
		for ( i = 0; i < pool.size; i++ )
		{
			if ( i == first )
				continue;
			rest[ rest.size ] = pool[ i ];
		}
		opts[ 1 ] = make_option( player, rest[ weighted_draw( rest ) ] );
	}

	// The TIER card ALWAYS takes the RIGHT slot: the left card is focused by
	// default and a timeout locks the focused card — a weapon swap the player
	// did not choose must never happen (apply_upgrade also refuses a timed-out
	// tier pick, belt and braces).
	if ( tier_deal )
		opts[ 1 ] = make_tier_option( player );

	// DARK UPGRADES (v17.10) — after the tier card so it can never be spent on a
	// slot the tier card is about to overwrite, and BEFORE the luck floor so the
	// floor sees the final hand. Both luck guarantees skip dark cards outright.
	opts = deal_dark( player, opts );

	// THE LUCK FLOOR — LAST, and it has to be last. The tier card overwrites
	// slot 1 directly above, so a guarantee applied any earlier could be spent
	// on a card that no longer exists by the time the deal is presented.
	//
	// The OPENING-HAND latch is read and set here rather than inside
	// guarantee_rarity, so it is spent exactly once even on the paths where the
	// guarantee itself returns early (dice already cleared the floor, or every
	// candidate was maxed). Reading it inside and setting it outside would let a
	// satisfied first deal hand the floor to the second one as well.
	first = !IS_TRUE( player.tod_first_deal_done );
	player.tod_first_deal_done = true;
	// v14.6: the pool rides along so the guarantee can REDEAL a slot when
	// neither dealt card has the headroom to absorb the owed rarity.
	guarantee_rarity( player, opts, first, pool );

	return opts;
}

// The LUCK GUARANTEE (see TOD_UPG_GUAR_ULT_BAR). opts = the 1-2 card structs,
// already rolled. Promotes ONE card up to the floor the bar has earned, or does
// nothing at all if the dice already met it.
//
// THE TIER CARD IS NOT AN ULTIMATE FOR THIS PURPOSE, on both sides of the test.
// It carries rarity 3 so it draws the ULTIMATE frame and sting, but it is a gun
// promotion, not "an ultimate upgrade" — so it neither SATISFIES the guarantee
// nor is eligible to be promoted (there is nothing to promote it to; its levels
// mean a tier, not a count). The player who draws one on a full bar gets a
// genuine choice: the promotion, or a guaranteed ULTIMATE in the other slot.
//
// HEADROOM IS REQUIRED WHEN THE POOL CAN SUPPLY IT (v14.6, user 2026-08-30:
// "if you have max luck you should get an ultimate at least 1 of the cards
// 100% of the time. And at 50% luck at least 1 super 100% of the time" —
// after a max-luck game dealt no ULTIMATE). The old behavior promoted only
// WITHIN the dealt cards: a deal of low-cap/near-cap domains (PENETRATION and
// RECOIL cap at 2, SPRINT FIRE at 1, anything one level from its cap) had no
// card that could hold a +3, so the promotion clamped and the band-honesty
// pass relabeled it DOWN — a full bar paying out as "SUPER". Honest, but it
// broke the promise the bar makes. NOW: when no dealt card can absorb the
// owed rarity, ONE slot is REDEALT (weighted draw, same as the original
// deal) from the pool's domains that CAN absorb it, then promoted — so the
// guarantee is met with a real, full-paying card. The redeal replaces the
// dealt card with the LEAST headroom (keeping the stronger card and the tier
// card untouched) and never duplicates the kept card's domain. Only when NO
// available domain has the headroom (deep late-game, everything near max)
// does it fall back to the old clamped-and-honest promotion — at that point
// a full ULTIMATE is arithmetically impossible, not merely unlucky. Among
// equal candidates every pick is RANDOM, so the floor never trains players
// to expect it in a fixed slot.
function guarantee_rarity( player, opts, first_deal, deal_pool )
{
	if ( !isdefined( player ) || !isdefined( opts ) )
		return;

	// Field-read, never #using — _tod_luck imports this module (the KB cycle
	// rule), the same way roll_rarity reads the bar.
	b = 0;
	if ( isdefined( player.tod_luck_bar ) )
		b = player.tod_luck_bar;

	// v14.9 OVERCHARGE (see TOD_UPG_GUAR_BOTH_BAR): at the secret ceiling the
	// floor covers the WHOLE deal — every non-tier slot, each with its own
	// per-slot redeal when it lacks the +3 headroom. Handled by its own pass
	// because everything below is single-promotion logic ("promotes ONE card")
	// and its early-return on any satisfied slot is exactly wrong here.
	if ( b >= TOD_UPG_GUAR_BOTH_BAR )
	{
		guarantee_both_ultimate( player, opts, deal_pool );
		return;
	}

	want = 0;
	if ( b >= TOD_UPG_GUAR_ULT_BAR )
		want = 3;
	else if ( b >= TOD_UPG_GUAR_SUP_BAR )
		want = 2;
	// THE OPENING HAND floors the run's first deal at SUPER. Raises `want`,
	// never lowers it — a full bar on a first deal (only reachable at a station,
	// never at the round-1 draft) still guarantees the ULTIMATE.
	if ( IS_TRUE( first_deal ) && want < TOD_UPG_GUAR_FIRST )
		want = TOD_UPG_GUAR_FIRST;
	if ( want == 0 )
		return;

	cands = [];
	full = [];
	for ( i = 0; i < opts.size; i++ )
	{
		o = opts[ i ];
		// DARK UPGRADES (v17.10): skipped for the same reason the tier card is —
		// it is not a rarity the floor can raise or should be spent on. It carries
		// rarity 3 for its FRAME, so without this the "o.rarity >= want" test one
		// line below would read a dark card as "the dice already cleared the floor"
		// and silently cancel the ULTIMATE the other slot was owed.
		if ( !isdefined( o ) || o.domain == "tier" || IS_TRUE( o.dark ) )
			continue;
		if ( o.rarity >= want )
			return;                      // the dice already cleared the floor
		room = o.max - o.cur;
		if ( room <= 0 )
			continue;                    // maxed while deferred — nothing to raise
		cands[ cands.size ] = o;
		if ( room >= want )
			full[ full.size ] = o;
	}

	// THE REDEAL (v14.6 — the user quote in the header). No dealt card can
	// absorb the whole promotion, so swap the weakest one for a domain that
	// can, IN PLACE (the struct is aliased by the caller's opts array, so
	// field-overwrite propagates without relying on array-reference
	// semantics). The kept card's domain is excluded so the two cards stay
	// distinct; the victim's own domain excludes itself by headroom (if it
	// could absorb `want` it would be in `full` and we would not be here).
	if ( full.size == 0 && cands.size > 0 && isdefined( deal_pool ) )
	{
		// victim = the dealt card with the LEAST headroom; ties random.
		victim = cands[ 0 ];
		for ( i = 1; i < cands.size; i++ )
		{
			ri = cands[ i ].max - cands[ i ].cur;
			rv = victim.max - victim.cur;
			if ( ri < rv || ( ri == rv && RandomInt( 2 ) == 0 ) )
				victim = cands[ i ];
		}
		// the kept non-tier card's domain (at most one — deals are 2 cards)
		kept_key = undefined;
		for ( i = 0; i < opts.size; i++ )
		{
			o = opts[ i ];
			if ( isdefined( o ) && o.domain != "tier" && o != victim )
				kept_key = o.domain;
		}

		sub = [];
		for ( i = 0; i < deal_pool.size; i++ )
		{
			d = deal_pool[ i ];
			if ( domain_max( player, d ) - get_level( player, d.key ) < want )
				continue;
			if ( isdefined( kept_key ) && d.key == kept_key )
				continue;
			sub[ sub.size ] = d;
		}
		if ( sub.size > 0 )
		{
			no = make_option( player, sub[ weighted_draw( sub ) ] );
			victim.domain      = no.domain;
			victim.display     = no.display;
			victim.desc        = no.desc;
			victim.tier        = no.tier;
			victim.cur         = no.cur;
			victim.max         = no.max;
			victim.rarity      = no.rarity;
			victim.levels      = no.levels;
			victim.rarity_name = no.rarity_name;
			full[ 0 ] = victim;          // absorbs `want` by construction
		}
	}

	// HEADROOM FIRST: a promotion clamped down to +1 by the level cap would
	// defeat the guarantee outright, so cards that can absorb the whole thing
	// win over cards that cannot. Fall back to the clamped ones rather than
	// doing nothing (only reachable now when NO available domain has the
	// headroom — see the redeal above).
	pool = full;
	if ( pool.size == 0 )
		pool = cands;
	if ( pool.size == 0 )
		return;                          // tier-card-only deal: nothing to promote

	// THEN THE LOWEST RARITY, which is what stops the floor wasting itself.
	// Promoting a card that ALREADY rolled SUPER spends the guarantee on the
	// half of the deal that was already good and leaves the player holding
	// ULTIMATE + REGULAR; promoting the REGULAR instead leaves ULTIMATE + SUPER,
	// which is strictly better and costs nothing. This is not a rare corner: at
	// a full bar, 36% of deals come up one SUPER and one REGULAR, so picking
	// blind between them degraded almost 18% of ALL max-luck deals.
	lo = 4;                              // above every real rarity (1..3)
	for ( i = 0; i < pool.size; i++ )
	{
		if ( pool[ i ].rarity < lo )
			lo = pool[ i ].rarity;
	}
	best = [];
	for ( i = 0; i < pool.size; i++ )
	{
		if ( pool[ i ].rarity == lo )
			best[ best.size ] = pool[ i ];
	}

	pick = best[ RandomInt( best.size ) ];   // random among true ties only

	pick.rarity = want;
	// Re-clamp exactly as make_option does — the per-class cap still wins.
	pick.levels = want;
	if ( pick.cur + pick.levels > pick.max )
		pick.levels = pick.max - pick.cur;

	// ...AND THE SAME BAND-HONESTY CLAMP, or this function would be the one hole
	// left in it. The headroom preference above means we normally promote a card
	// that can absorb the whole thing, but when NO candidate can (everything on
	// the deal is near its cap) it deliberately falls back to a clamped one — and
	// without this the guarantee would stamp "ULTIMATE +3" on a card paying +1,
	// which is exactly the label this pass exists to remove. A floor that has to
	// lie to hit its number is not a floor worth having; showing the best rarity
	// actually deliverable is the honest outcome.
	if ( pick.levels >= 1 && pick.levels < pick.rarity )
		pick.rarity = pick.levels;

	if ( pick.rarity == 3 )      pick.rarity_name = "ULTIMATE";
	else if ( pick.rarity == 2 ) pick.rarity_name = "SUPER";
	else                         pick.rarity_name = "";
}

// v14.9 THE OVERCHARGE PAYOUT (TOD_UPG_GUAR_BOTH_BAR — user 2026-08-30: at
// 150% luck "both options are guaranteed to be ultimates rarity"). EVERY
// non-tier slot is raised to ULTIMATE, each slot independently, composing with
// the v14.6 redeal per slot: a slot without +3 of headroom is redealt (same
// weighted draw, same in-place field overwrite — the struct is aliased by the
// caller's opts array) from the pool domains that CAN absorb it, always
// excluding the OTHER slot's CURRENT domain so the two cards stay distinct
// through any sequence of redeals.
//
// THE TIER CARD KEEPS ITS EXEMPTION (the guarantee_rarity header owns that
// contract): it is neither promotable nor "an ultimate" here, so an
// overcharged deal that draws one presents promotion-vs-guaranteed-ULTIMATE —
// the same genuine choice as at 100, just with the other slot certain.
//
// Each slot that cannot redeal (no pool domain anywhere with +3 headroom —
// deep late-game) falls back to the clamped promotion UNDER the band-honesty
// clamp, exactly like the single path: the card pays every level it can and
// wears the rarity it actually pays. A slot already rolled ULTIMATE, or maxed
// while deferred (room 0, the station re-present corner), is left alone.
function guarantee_both_ultimate( player, opts, deal_pool )
{
	if ( !isdefined( opts ) )
		return;

	for ( i = 0; i < opts.size; i++ )
	{
		o = opts[ i ];
		// DARK UPGRADES: never demote one. This loop forces every non-tier slot to
		// rarity 3 / levels 3, which on a dark card would overwrite its zero-levels
		// contract and hand apply_upgrade three levels of an already-maxed domain.
		if ( !isdefined( o ) || o.domain == "tier" || IS_TRUE( o.dark ) )
			continue;
		if ( o.rarity >= 3 )
			continue;                    // the dice already paid this slot
		room = o.max - o.cur;
		if ( room <= 0 )
			continue;                    // maxed while deferred — nothing to raise

		if ( room < 3 && isdefined( deal_pool ) )
		{
			// PER-SLOT REDEAL. kept_key = the other slot's domain AS IT
			// STANDS NOW (a slot 0 redeal has already landed by the time
			// slot 1 runs), so distinctness holds through both.
			kept_key = undefined;
			for ( j = 0; j < opts.size; j++ )
			{
				k = opts[ j ];
				if ( isdefined( k ) && k != o && k.domain != "tier" )
					kept_key = k.domain;
			}

			sub = [];
			for ( j = 0; j < deal_pool.size; j++ )
			{
				d = deal_pool[ j ];
				if ( domain_max( player, d ) - get_level( player, d.key ) < 3 )
					continue;
				if ( isdefined( kept_key ) && d.key == kept_key )
					continue;
				sub[ sub.size ] = d;
			}
			if ( sub.size > 0 )
			{
				no = make_option( player, sub[ weighted_draw( sub ) ] );
				o.domain      = no.domain;
				o.display     = no.display;
				o.desc        = no.desc;
				o.tier        = no.tier;
				o.cur         = no.cur;
				o.max         = no.max;
				o.rarity      = no.rarity;
				o.levels      = no.levels;
				o.rarity_name = no.rarity_name;
			}
		}

		// Promote — same re-clamp as make_option, same band-honesty clamp as
		// guarantee_rarity (a card that can only pay +1 is labeled REGULAR,
		// never a lying "ULTIMATE +3").
		o.rarity = 3;
		o.levels = 3;
		if ( o.cur + o.levels > o.max )
			o.levels = o.max - o.cur;
		if ( o.levels >= 1 && o.levels < o.rarity )
			o.rarity = o.levels;

		if ( o.rarity == 3 )      o.rarity_name = "ULTIMATE";
		else if ( o.rarity == 2 ) o.rarity_name = "SUPER";
		else                      o.rarity_name = "";
	}
}

// -> an INDEX into `pool`, picked with probability proportional to tier weight.
function weighted_draw( pool )
{
	total = 0;
	for ( i = 0; i < pool.size; i++ )
		total += tier_weight( pool[ i ] );
	if ( total <= 0 )
		return RandomInt( pool.size );

	roll = RandomInt( total );
	acc = 0;
	for ( i = 0; i < pool.size; i++ )
	{
		acc += tier_weight( pool[ i ] );
		if ( roll < acc )
			return i;
	}
	return pool.size - 1;   // float/rounding belt+braces
}

function tier_weight( d )
{
	if ( !isdefined( d ) || !isdefined( d.tier ) )
		return TOD_TIER_W_B;
	if ( d.tier == TOD_TIER_S )
		return TOD_TIER_W_S;
	if ( d.tier == TOD_TIER_A )
		return TOD_TIER_W_A;
	return TOD_TIER_W_B;
}

// S/A cards shrink their SUPER+ULTIMATE slice (the rest falls back to REGULAR).
function tier_rarity_factor( tier )
{
	if ( !isdefined( tier ) )
		return 1.0;
	if ( tier == TOD_TIER_S )
		return TOD_TIER_R_S;
	if ( tier == TOD_TIER_A )
		return TOD_TIER_R_A;
	return 1.0;
}

function make_option( player, domain )
{
	o = SpawnStruct();
	o.domain = domain.key;
	o.display = domain.display;
	o.desc = domain.desc;
	o.tier = domain.tier;

	o.rarity = roll_rarity( player, domain.tier );

	o.cur = get_level( player, domain.key );
	o.max = domain_max( player, domain );   // per-class cap (RESERVE: assault 6)
	o.levels = o.rarity;
	if ( o.cur + o.levels > o.max )
		o.levels = o.max - o.cur;

	// THE BAND NEVER PROMISES MORE THAN IT PAYS (user 2026-08-27).
	//
	// `levels` has always been clamped to the headroom; `rarity` was not, so the
	// two could disagree and the card said so out loud. A domain capped below 3
	// could deal an "ULTIMATE +3" that paid +2 every single time it appeared:
	// PENETRATION and RECOIL are max 2, SPRINT FIRE is max 1, and near its cap
	// ANY domain does it — a player at Lv9 of a 10-level domain drawing an
	// ULTIMATE got "+3" and one level. The value line stayed truthful about the
	// EFFECT (that is why RECOIL could ship saying `· MAX`), but the number on
	// the band was simply wrong, and the band is the thing players compare two
	// cards on.
	//
	// CLAMPS DOWN ONLY, NEVER UP. rarity follows levels, so the card shows the
	// rarity it can actually deliver — a 2-level payout presents as SUPER, a
	// 1-level payout as REGULAR. Nothing is taken from the player: the LEVELS
	// paid are identical either way, and this only ever relabels a card that was
	// going to underdeliver. It also picks the right art, since the frame/sting
	// key off `rarity`.
	//
	// CONSEQUENCE, DELIBERATE: four card files become unreachable —
	// penetration_ultimate, recoil_ultimate, sprint_fire_super and
	// sprint_fire_ultimate. They stay zoned and installed on purpose: they cost
	// nothing but .ff bytes, they cannot render, and if a cap is ever raised the
	// art is already there. Do NOT "clean them up" — unzoning them is real risk
	// (a CARD_SLUG miss) for no gain.
	//
	// THE TIER CARD IS EXEMPT BY CONSTRUCTION: it is built by make_tier_option,
	// never here, and its `levels` means a tier rather than a count.
	if ( o.levels >= 1 && o.levels < o.rarity )
		o.rarity = o.levels;

	// v16.64 RARITY LOCK (DEADSHOT): the frame is fixed by the domain, not the
	// dice — placed AFTER the clamp on purpose (the clamp would demote a max-1
	// domain's ULTIMATE to REGULAR; the lock is the one exception the user asked
	// for). `levels` is untouched: the card still pays exactly its headroom.
	if ( isdefined( domain.rarity_lock ) )
		o.rarity = domain.rarity_lock;

	if ( o.rarity == 3 )      o.rarity_name = "ULTIMATE";
	else if ( o.rarity == 2 ) o.rarity_name = "SUPER";
	else                      o.rarity_name = "";

	return o;
}

// 1 = regular, 2 = super, 3 = ultimate — rolled PER CARD (both slots roll
// independently). Exact odds (user 2026-08-18):
//   base           ULTIMATE 5%   SUPER 15%   REGULAR 80%
//   per luck tier  +5%           +5%         -10%      (always sums to 100)
//   e.g. 2 boss kills = luck 2:  15% / 25% / 60%
//   luck caps at 8 (REGULAR bottoms out at 0% -> 45% ULT / 55% SUPER)
function roll_rarity( player, tier )
{
	// v5 LUCK BAR (user 2026-08-20): the 0..100% bar (player.tod_luck_bar,
	// earned in _tod_luck — kills/headshots/revives/doors/boss LAST HITS)
	// MULTIPLIES the SUPER/ULTIMATE chances: x1 at 0%, x2 at 50%, x3 at 100%
	// (user 2026-08-20 nerf — was 20/50/30 at full, now 40/45/15).
	//   bar   0% -> 80 / 15 /  5
	//   bar  50% -> 60 / 30 / 10
	//   bar 100% -> 40 / 45 / 15
	//   bar 150% -> 20 / 60 / 20  (v14.9: the raw bar secretly runs to 150 —
	//                              _tod_luck TOD_LUCK_OVERMAX. The linear
	//                              formula stays positive the whole way, so no
	//                              clamp is needed here; the band that matters
	//                              to THESE dice is 101..149, because at 150
	//                              guarantee_both_ultimate overrides the deal.)
	// Field-read, never #using — _tod_luck imports this module (the KB
	// cycle rule).
	b = 0;
	if ( isdefined( player.tod_luck_bar ) )
		b = player.tod_luck_bar;

	reg = 80 - 0.40 * b;
	sup = 15 + 0.30 * b;

	// v8.9 TIER GATE (user 2026-08-21: "make rare upgrades harder to get and
	// then even harder to get stacked"). S/A shrink BOTH upper slices toward
	// REGULAR, so an S domain at ULTIMATE (+3 levels) is the rarest event in
	// the game even on a full luck bar: 15% * 0.65 = 9.75% at bar 100 (it was
	// 15% * 0.5 = 7.5% until the 2026-09-08 gate softening).
	ult = 100 - reg - sup;
	f = tier_rarity_factor( tier );
	if ( f < 1.0 )
	{
		sup = sup * f;
		ult = ult * f;
		reg = 100 - sup - ult;
	}

	roll = RandomInt( 100 );
	if ( roll < reg )
		return 1;
	if ( roll < reg + sup )
		return 2;
	return 3;
}

// ---------------------------------------------------------------------------
// CLASS TIERS — the TIER card (docs/25 §4; user 2026-08-22)
// ---------------------------------------------------------------------------

function tier_card_pct()
{
	// [tod v19.9] tod_dev_upgrades, not tod_dev — the 100% tier card is a
	// promotion-flow test, not something a normal-play dev session wants.
	if ( IS_TRUE( level.tod_dev_upgrades ) )
		return 100;   // DEV: every deal carries it — the promotion flow is testable in one session
	return TOD_TIER_CARD_PCT;
}

// v16.56 — is the promotion OWED rather than rolled? See TOD_UPG_GUAR_TIER_BAR.
// Asks the FULL eligibility on purpose: the user's rule is "max luck + PaP +
// eligible, floor included". A floor-blocked player is not owed anything here
// and falls through to the ordinary roll (which may still deal them the card
// LOCKED, v14.39 — that path is unchanged).
function tier_card_guaranteed( player )
{
	if ( !tier_card_eligible( player ) )
		return false;
	// Field-read, never #using — _tod_luck imports this module (the KB cycle
	// rule), the same way roll_rarity and guarantee_rarity read the bar.
	b = 0;
	if ( isdefined( player.tod_luck_bar ) )
		b = player.tod_luck_bar;
	return ( b >= TOD_UPG_GUAR_TIER_BAR );
}

// THE ONE TIER-CARD ROLL (v16.56). Both deal paths — roll_options and the
// maxed-player pre-roll in run_upgrade_event — ask this and nothing else, so
// the guarantee cannot hold on one path and miss on the other. Callers still
// own the eligibility test in front of it (but-for-floor on the deal so a
// locked card can be shown; full eligibility on the pre-roll, where a locked
// card alone would be an empty pause). READ THE BAR BEFORE IT IS SPENT: both
// callers run before the participants' post-event reset, and the station
// resets only after a successful pick.
function tier_card_roll( player )
{
	if ( tier_card_guaranteed( player ) )
		return true;
	return ( RandomInt( 100 ) < tier_card_pct() );
}

// THE DRAFTABLE-DOMAIN RULE, IN ONE PLACE (v14.24). Returns every domain this
// player could still be dealt: available to them, and not yet at its max.
// roll_options and has_upgrade_headroom both call this — deliberately ONE
// owner rather than two copies kept in step by discipline, which is the exact
// shape that has burned this codebase before (the hand-copied 0.04 in
// _tod_bosses, the RUN AND GUN constants across two files). Change what makes
// a domain draftable HERE and both callers follow by construction.
function eligible_pool( player )
{
	pool = [];
	if ( !isdefined( level.tod_domains ) )
		return pool;

	for ( i = 0; i < level.tod_domains.size; i++ )
	{
		d = level.tod_domains[ i ];
		if ( !domain_available( player, d ) )
			continue;
		if ( get_level( player, d.key ) < domain_max( player, d ) )
			pool[ pool.size ] = d;
	}
	return pool;
}

// TRUE when an upgrade deal could still GIVE this player something: a domain
// with headroom, or the class-tier promotion.
//
// WHY IT EXISTS (v14.24, user: "player has no more upgrades so they cant even
// get rid of the luck sfx"): a fully-maxed player's luck bar can reach the
// overcharge ceiling and then never spend, because the thing that clears the
// bar is taking a card and there is no card to take. _tod_luck's
// overcharge_driver polls this so the zap SFX goes quiet in that state instead
// of firing every ~3 seconds for the rest of the run. Polled live, never
// latched: a tier promotion resets the gun-scoped domains and hands the player
// real headroom again, and the cue must come back on its own when it does.
//
// *** IT IS NOT THE SAME TEST AS roll_options, AND THAT IS DELIBERATE — DO NOT
// "CORRECT" IT TO MATCH. *** roll_options returns undefined when the pool is
// empty AND its tier_deal ROLL missed (RandomInt(100) < tier_card_pct()); this
// asks the roll-free question tier_card_eligible( player ). The difference is
// the whole point: a maxed-but-tier-eligible player WILL draw the promotion
// eventually and clear their bar, so the cue must keep playing for them even
// though any single deal may hand them nothing. Gating on the random roll
// would silence the zap for players who can still spend it. (Caught in review
// by a peer session, 2026-08-30 — the divergence was intended but undocumented,
// which is how it would have been "fixed" into a bug.)
function has_upgrade_headroom( player )
{
	if ( !isdefined( player ) || !isplayer( player ) )
		return false;

	pool = eligible_pool( player );
	if ( pool.size > 0 )
		return true;

	return tier_card_eligible( player );
}

// THE FLOOR REQUIREMENT for a promotion INTO next_tier. 0 = none.
//
// Read by tier_floor_ok only. Kept as its own function so the two numbers the
// user gave live in exactly one place; the fallthrough extends the ladder's
// own spacing (t4 -> 30) so a fourth tier can never arrive ungated by silence.
function tier_floor_req( next_tier )
{
	if ( next_tier < 2 )
		return 0;                                          // tier 1 is where everyone starts
	if ( next_tier == 2 )
		return TOD_TIER2_FLOOR;
	if ( next_tier == 3 )
		return TOD_TIER3_FLOOR;
	return ( next_tier - 1 ) * ( TOD_TIER3_FLOOR - TOD_TIER2_FLOOR );
}

// Has this player CLIMBED far enough for their next promotion?
//
// The high-water is a per-player, alive-only, monotonically rising record of
// the real floor they have stood on (_tod_gauge). It never falls, so the gate
// asks "have you been up there", not "are you up there now" — you can promote
// at a base station or on a teleporter pad, as long as you earned it. It is
// also NOT re-checked by anything after a card is dealt for the same reason:
// a card that was legal when dealt stays legal.
//
// NOT waived by level.tod_dev. A dev session that skips its own gate cannot
// test it, and the dev build already gets there fast (money loop + 100% tier
// odds); the climb to floor 10 is the thing being verified.
function tier_floor_ok( player )
{
	need = tier_floor_req( tod_classes::tier( player ) + 1 );
	if ( need <= 0 )
		return true;
	return tod_gauge::floor_reached( player ) >= need;
}

// Can this player be dealt a TIER card right now? ALL of: below the top tier,
// HIGH ENOUGH UP THE TOWER for the tier they are promoting into (v14.35 — see
// the TOD_TIER2_FLOOR block), a next gun registered AND its level-0 asset
// linked (never deal a card that cannot pay out), the CURRENT class gun PaP'd
// (by name, or the free-PaP latch that reconcile turns into the _up form
// within 1s), and no powerup gun in hand (its restore would fight the swap).
//
// tier_up() re-asks this whole question before promoting, which is what makes
// the floor gate hold on every path into a promotion rather than just on the
// deal — including the personal station's deferred cards.
function tier_card_eligible( player )
{
	return ( tier_card_ready_but_for_floor( player ) && tier_floor_ok( player ) );
}

// Everything a TIER card needs EXCEPT the climb.
//
// Split out so the panel hint can ask the one question it actually cares about
// — "is the FLOOR the only thing stopping this player?" — without a second copy
// of the other four conditions drifting away from this one. There is still
// exactly ONE implementation of each rule: this function owns the four, and
// tier_floor_ok owns the floor. Never inline either back into a caller.
//
// v16.70: the rules themselves moved into tier_not_ready_reason (one string per
// refusal, "" when ready) so the dev deny-print can NAME the refusal without a
// second copy of the ladder — this is now the boolean view of that one owner.
function tier_card_ready_but_for_floor( player )
{
	return ( tier_not_ready_reason( player ) == "" );
}

// DEV ONLY — why is this player NOT being dealt the TIER card? Composes the
// not-ready ladder, then the floor, then the bar/odds, in the order the deal
// asks them. Free lane (IPrintLn — no triggerstring, no art); never shown to
// a player in a shipping build.
function tier_deny_reason( player )
{
	why = tier_not_ready_reason( player );
	if ( why != "" )
		return why;
	if ( !tier_floor_ok( player ) )
		return "floor " + tod_gauge::floor_reached( player ) + " < " + tier_floor_req( tod_classes::tier( player ) + 1 ) + " (dealt LOCKED at most)";
	b = 0;
	if ( isdefined( player.tod_luck_bar ) )
		b = player.tod_luck_bar;
	return "eligible; luck " + int( b ) + "/" + TOD_UPG_GUAR_TIER_BAR + " -> " + ( ( b >= TOD_UPG_GUAR_TIER_BAR ) ? "GUARANTEED" : ( "rolled at " + tier_card_pct() + "%" ) );
}

// THE ONE OWNER of "everything a TIER card needs except the climb" (the header
// above tier_card_ready_but_for_floor). Returns "" when every rule passes, or
// the first failing rule as a short reason string.
function tier_not_ready_reason( player )
{
	if ( !isdefined( player ) || !isplayer( player ) || !isdefined( player.tod_class ) )
		return "no class";
	// NEVER PROMOTE A CRAWLER (v15, shipped with item 9 — the change that first
	// let a downed player be dealt cards at all).
	//
	// Normal last stand does NOT take your weapons (_zm_laststand.gsc:212-228
	// only calls TakeAllWeapons on the is_zombie branch) — it leaves the whole
	// inventory and SwitchToWeapon's the last-stand pistol, then re-asserts that
	// switch a second later via wait_switch_weapon. So without this test
	// class_primary_in_inventory() still finds the class gun and a crawler looks
	// perfectly eligible, while tier_up's swap_primary would be taking and
	// giving primaries underneath stock's pistol handling. Two systems writing
	// the same inventory a second apart is not a race worth having for a card
	// that will still be there when they are revived.
	//
	// This sits in tier_card_ready_but_for_floor rather than tier_card_eligible
	// ON PURPOSE: this function owns the "everything except the climb" rules, so
	// putting it here ALSO suppresses the "TIER 2 AT FLOOR 10" badge for a
	// downed player — the floor is not what is stopping them, and saying so
	// would be exactly the misdirection this function's header warns about.
	if ( player laststand::player_is_in_laststand() )
		return "in last stand";
	if ( IS_TRUE( player.tod_tier_busy ) || IS_TRUE( player.tod_swap_busy ) )
		return "weapon swap in progress";
	if ( tod_classes::tier( player ) >= tod_classes::tier_max() )
		return "already top tier";
	next = tod_classes::next_gun( player );
	if ( !isdefined( next ) )
		return "no next gun registered";
	if ( !isdefined( tod_classes::base_weapon( next ) ) )
		return "next gun not linked";
	g = tod_classes::gun( player );
	w = player class_primary_in_inventory();
	if ( !isdefined( g ) || !isdefined( w ) )
		return "class gun not in inventory";
	if ( !IsSubStr( w.name, g.stem ) || tod_classes::pap_tier( player, w ) == 0 )
		return "class gun not Pack-a-Punched (" + w.name + ")";
	if ( isdefined( player.zombie_vars ) && IS_TRUE( player.zombie_vars[ "zombie_powerup_minigun_on" ] ) )
		return "powerup gun in hand";
	return "";
}

// -> the floor this player still has to REACH before a TIER card can be dealt,
// or 0 when the floor is not what is stopping them.
//
// THE PANEL LINE ANSWERS EXACTLY ONE QUESTION — "I Pack-a-Punched, so where is
// my tier card?" — and it has to stay silent for every other reason or it
// becomes noise that misdirects: a player who has not PaP'd yet would be told
// to climb, which is true and useless, and a top-tier player would be told to
// climb toward a promotion that does not exist. So this returns non-zero ONLY
// when every other condition is already satisfied.
function tier_floor_pending( player )
{
	if ( !tier_card_ready_but_for_floor( player ) )
		return 0;
	if ( tier_floor_ok( player ) )
		return 0;
	return tier_floor_req( tod_classes::tier( player ) + 1 );
}

// ---------------------------------------------------------------------------
// THE TIER GATE TOASTS (2026-09-02, user: "make sure players are somehow aware
// of this through UI triggers on pap or some way").
//
// Two per-player HUD toasts (since v19.58 tod_upgrade_ui::toast in the map's
// typeface; IPrintLnBold before, engine font): no triggerstring slot (the PaP
// prompt is a DEAD lane for custom copy — isPAPHint, see _tod_powerups'
// REQUIRES POWER note) and no art. Each fires AT MOST ONCE PER
// TIER per player, latched on the tier it was said for, so a revive (which
// flips tier_card_ready_but_for_floor off and back on) cannot repeat it:
//   (a) "CLASS TIER 3 UNLOCKS AT FLOOR 30" — the moment the class gun is
//       PaP'd (or the free-PaP latch lands) while the climb is still short.
//       Same rule as the panel badge: tier_floor_pending() > 0.
//   (b) "FLOOR 30 REACHED - CLASS TIER 3 UNLOCKED" — the moment the
//       high-water clears the next promotion's floor; "- PACK-A-PUNCH TO
//       PROMOTE" is appended while the gun is still dry. It also fires right
//       after a promotion for a player already above the NEXT floor, which is
//       simply true at that moment.
// Held while the upgrade panel is up (tod_menu_frozen): the panel carries the
// badge, and a toast under the cards would fight the deal. 0.5 s poll on the
// same functions the panel reads — ONE authority (tier_floor_req /
// tier_floor_pending / tier_card_ready_but_for_floor), never a second copy.
// self = player; threaded once from player_upgrade_setup.
function tier_gate_toasts()
{
	self endon( "disconnect" );

	told_a_tier = 0;   // the next_tier line (a) was said for
	told_b_tier = 0;   // the next_tier line (b) was said for

	while ( true )
	{
		wait 0.5;
		if ( !isdefined( self.tod_class ) || IS_TRUE( self.tod_menu_frozen ) )
			continue;
		next_tier = tod_classes::tier( self ) + 1;
		if ( next_tier > tod_classes::tier_max() )
			continue;
		need = tier_floor_req( next_tier );
		if ( need <= 0 )
			continue;

		// (a) packed, climb short
		if ( told_a_tier != next_tier && tier_floor_pending( self ) > 0 )
		{
			told_a_tier = next_tier;
			self tod_upgrade_ui::toast( TOD_TOAST_TIER_AT_FLOOR, next_tier, need );   // v19.58: map typeface
		}

		// (b) climb cleared
		if ( told_b_tier != next_tier && tod_gauge::floor_reached( self ) >= need )
		{
			told_b_tier = next_tier;
			// v19.58: map typeface (the words are the Lua TOAST rows 2 / 3)
			if ( !( self class_gun_packed() ) )
				self tod_upgrade_ui::toast( TOD_TOAST_FLOOR_TIER_PAP, need, next_tier );
			else
				self tod_upgrade_ui::toast( TOD_TOAST_FLOOR_TIER, need, next_tier );
		}
	}
}

// self = player. Is the class primary Pack-a-Punched (or latched as packed by
// the free-PaP drop)? The same test tier_card_ready_but_for_floor applies,
// without its laststand / powerup-gun / top-tier terms — so the toast's
// "PACK-A-PUNCH TO PROMOTE" suffix answers only the question it names.
function class_gun_packed()
{
	g = tod_classes::gun( self );
	w = self class_primary_in_inventory();
	if ( !isdefined( g ) || !isdefined( w ) )
		return false;
	return ( IsSubStr( w.name, g.stem ) && tod_classes::pap_tier( self, w ) > 0 );
}

// self = player. Push the panel's tier-requirement line for the deal that is
// about to be presented.
//
// ZERO-BIT LANE, deliberately: the clientuimodel pool is at its PROVEN 61-bit
// ceiling (18 fields, APPEND ONLY), so this rides the int-only LuiNotifyEvent
// channel the tower gauge, the max-HP feed and the owned-upgrades sync already
// use. tod_upgrade.lua parks it in CoD.TodTierNeed and the choice panel reads
// it while it paints.
//
// SENT UNCONDITIONALLY, INCLUDING 0, before EVERY deal — that is what keeps a
// stale value from surfacing on a later deal, and it is why nothing has to
// clear the line when the panel closes. Called from the two present_choice
// sites (the round event and the personal station); a third presenter must
// call it too.
function push_panel_hints()
{
	self LuiNotifyEvent( &"tod_upg_tier_need", 1, tier_floor_pending( self ) );

	// v16: the CLASS BADGE, docs/59. Same zero-bit lane and the same
	// unconditional-every-deal rule as the line above -- the clientuimodel pool
	// is at 60 of its PROVEN 61, so a new field was not affordable and is not
	// needed. class_id() returns 0 for a classless (pre-draft) player, which
	// tod_upgrade.lua reads as "hide the plate", so no case needs special-casing.
	//
	// RENAMED from push_tier_hint(): it pushes two facts now, and a name that
	// says "tier" would be the next reader's wrong turn. Two call sites, both
	// present_choice presenters; a third presenter must call this too.
	self LuiNotifyEvent( &"tod_upg_class", 1, tod_classes::class_id( self.tod_class ) );
}

// The card's "level" field (todUpgAL/BL, 4 bits) carries
// (class_id - 1) * 2 + (target_tier - 2) -> 0..7, so tod_upgrade.lua can name
// the gun the promotion hands out (its TIER_LADDER table).
function tier_card_code( player )
{
	cid = tod_classes::class_id( player.tod_class );
	nt = tod_classes::tier( player ) + 1;
	code = ( cid - 1 ) * 2 + ( nt - 2 );
	if ( code < 0 )
		code = 0;
	if ( code > 15 )
		code = 15;
	return code;
}

function make_tier_option( player )
{
	o = SpawnStruct();
	o.domain = "tier";
	o.display = "CLASS TIER";
	o.desc = "promote your class: a new weapon, gun upgrades reset";
	o.tier = TOD_TIER_S;
	o.rarity = 3;               // the ULTIMATE frame + sting carry it until the tier art lands
	o.rarity_name = "TIER";
	o.cur = tier_card_code( player );
	o.max = tod_classes::tier_max();
	o.levels = 1;
	// THE LOCK (v14.39, user 2026-08-31: "a design where you get the card but
	// you cant select it"). A floor-blocked player is now DEALT the promotion
	// and shown which gun it is — the card just cannot be taken, and the Lua
	// draws it dimmed with the gate badge under it. Seeing the thing you are
	// climbing toward beats an absence you have to infer.
	//
	// The user was told, and accepted, that this spends the deal's right slot:
	// on the ~20% of deals where the tier card rolls below the gate floor they
	// get one real card instead of two. It is bounded by that roll and by how
	// few events happen below floor 10 — it is NOT every deal.
	o.locked = ( tier_floor_pending( player ) > 0 );
	return o;
}

// THE PROMOTION. self = nothing; player = the promoted player. Order matters:
//   1. every GUN-scoped domain to 0 (CLASS-scoped — DMG REDUCTION, LUCK — kept)
//      + the live effects those levels were driving un-applied;
//   2. tier++ and the free-PaP latch CLEARED (mandatory — reconcile would
//      otherwise pull the new gun straight to its _up form on the next tick
//      and skip the "PaP it again" step the whole design rests on);
//   3. the weapon: the next gun's level-0 form, given with FULL start ammo
//      (a tier-up is a gift), via the proven swap order; alt weapons swapped
//      if they differ; a `grant` domain (the Stormbreaker's THOR'S THUNDER)
//      set to Lv1 the moment the gun arrives;
//   4. the pause list re-synced and the sting.
// Returns false if nothing happened (not eligible / assets missing).
function tier_up( player )
{
	if ( !tier_card_eligible( player ) )
		return false;
	g_old = tod_classes::gun( player );
	g_new = tod_classes::next_gun( player );
	want = tod_classes::base_weapon( g_new );
	if ( !isdefined( g_old ) || !isdefined( g_new ) || !isdefined( want ) )
		return false;

	player.tod_tier_busy = true;   // holds the body loop's reconcile off until the promotion has fully landed
	// An in-flight twin swap (the body loop's walk, up to 1s) must finish
	// first — two GIVE-before-TAKE swaps at once could leave 3-4 primaries
	// and the engine silently drops one. Bounded wait, then bail if still busy.
	for ( i = 0; i < 30 && IS_TRUE( player.tod_swap_busy ); i++ )
		wait 0.05;
	if ( !isdefined( player ) || IS_TRUE( player.tod_swap_busy ) )
	{
		if ( isdefined( player ) )
			player.tod_tier_busy = undefined;
		return false;
	}
	old = player class_primary_in_inventory();   // resolve AFTER the wait, BEFORE the tier changes
	if ( !isdefined( old ) )
	{
		player.tod_tier_busy = undefined;
		return false;
	}

	player notify( "tod_tier_up" );

	// 1. THE WEAPON FIRST — if the swap cannot land (player stripped mid-swap)
	//    nothing else is committed: no reset, no tier, no latch change.
	if ( IS_TRUE( level.tod_classes[ g_new.class_key ].additive ) )
	{
		// ADDITIVE CLASS (v18.30, the mage): the promotion ADDS the next staff
		// and takes nothing. Raised in hand so the player sees what they got.
		if ( !( player HasWeapon( want ) ) )
		{
			want = player tod_classes::give_camo_weapon( want );
			player GiveStartAmmo( want );
			// The new staff keeps the first raise give_camo_weapon asks for: a
			// promotion is the one swap that shows its weapon off (user, on the
			// v19.76 review: "I like the first draw only for showcase on tier
			// promo" - the first cut had turned it off here too).
		}
		player SwitchToWeapon( want );
	}
	else if ( want != old )
	{
		ok = player swap_primary( old, want, true, true );   // showcase: the promotion keeps its first raise (v19.76 review)
		if ( !ok || !isdefined( player ) )
		{
			if ( isdefined( player ) )
				player.tod_tier_busy = undefined;
			return false;
		}
	}
	else
		player GiveStartAmmo( old );   // same asset (cannot happen past the null ladder) — still a refill

	// 2. reset every domain that does not survive for THIS player —
	// domain_survives_tier is the one authority (v14.13: scope "class" can be
	// limited to a single class; SCAVENGER survives for the assault alone)
	for ( i = 0; i < level.tod_domains.size; i++ )
	{
		d = level.tod_domains[ i ];
		if ( domain_survives_tier( player, d ) )
			continue;
		// DARK UPGRADES (v17.10): the dark BIT dies with the levels. Cleared
		// BEFORE the level test below, because a domain can hold a dark bit while
		// sitting at level 0 is impossible today but the ordering costs nothing and
		// a stale bit would be worse than a stale level: twin_suffix would keep
		// asking for a dark rung on a gun that has none.
		if ( isdefined( player.tod_dark ) && IS_TRUE( player.tod_dark[ d.key ] ) )
			player.tod_dark[ d.key ] = undefined;
		if ( get_level( player, d.key ) <= 0 )
			continue;
		player.tod_levels[ d.key ] = 0;
		// the pause list hides level-0 rows (AetheriumStartMenu.lua filters lvl > 0)
		player LuiNotifyEvent( &"tod_upg_sync", 3, tod_upgrade_ui::domain_id( d.key ), 0, sync_max( player, d ) );
	}
	player reset_gun_state();

	// 3. promote + clear the latch
	player.tod_tier = tod_classes::tier( player ) + 1;
	player.tod_pap_owned = undefined;
	player.tod_upg_maxed_told = undefined;   // there is a whole new ladder to climb

	// alt weapons: swap if they differ between the two guns
	if ( isdefined( g_old.alt ) && ( !isdefined( g_new.alt ) || g_new.alt != g_old.alt ) )
	{
		a = GetWeapon( g_old.alt );
		if ( isdefined( a ) && a != level.weaponNone && ( player HasWeapon( a ) ) )
			player TakeWeapon( a );
	}
	if ( isdefined( g_new.alt ) && ( !isdefined( g_old.alt ) || g_new.alt != g_old.alt ) )
	{
		a = GetWeapon( g_new.alt );
		if ( isdefined( a ) && a != level.weaponNone && !( player HasWeapon( a ) ) )
			player GiveWeapon( a );
	}
	if ( isdefined( g_new.grant ) && isdefined( player.tod_levels[ g_new.grant ] ) && player.tod_levels[ g_new.grant ] < 1 )
		player.tod_levels[ g_new.grant ] = 1;

	// THE SIDEARM IS PART OF THE PROMOTION (user 2026-08-24: "every tier for
	// every class needs its own secondary"). Before this, tier_up moved the
	// primary, the alt and the grant and left the sidearm alone — which was
	// correct while there was one sidearm per class and wrong the moment there
	// were three.
	//
	// AFTER player.tod_tier is written, not before: give_secondary resolves the
	// name from the tier, so running it any earlier hands back the sidearm the
	// player is being promoted OUT of. It is also after the primary swap has
	// already committed (step 1 returns false and changes nothing if that fails),
	// so the sidearm can never be the only thing that moved.
	//
	// The NEW sidearm arrives in its BASE form even if the old one was
	// Pack-a-Punched — the same rule the primary follows, where a TIER card
	// hands you the new gun at its level-0 form. take_foreign_secondaries inside
	// give_secondary reaps the old one in either form.
	player tod_classes::give_secondary( g_new.class_key, player.tod_tier );

	// 4. feedback
	player.tod_tier_busy = undefined;
	player apply_move_speed();
	player refresh_upgrade_list();
	player notify( "tod_tier_up_done", player.tod_tier );
	// v18.9 — SAY WHAT IT COST, because nothing else does. Three separate
	// Workshop reports describe the same surprise (.vers 2026-09-02 "taking the
	// kit upgrade wipes your PaP on your guns"; Nello 2026-08-29 "a class upgrade
	// can actually feel like a downgrade"). The card art carries no warning, the
	// LUI fallback that once did is dead behind USE_TIER_CARD_ART, and
	// "tod_tier_up_done" has no listener anywhere. This is the free lane: a
	// HUD toast (v19.58, was IPrintLnBold) costs no triggerstring slot and no
	// clientfield bit.
	//
	// It names BOTH weapons because the sidearm is swapped in the same breath
	// (give_secondary, a few lines up) and arrives in its base form too.
	// On the spire it is also the only notice that the PACK II / PACK III stack
	// just reset — pap_tier is keyed on the gun's stem, so a promotion silently
	// spends up to 80,000 points of re-packing.
	player tod_upgrade_ui::toast( TOD_TOAST_NEW_WEAPONS );   // v19.58: map typeface
	// DISTRACTION (domain 41): a grenade is INVENTORY, and this path writes a
	// LEVEL without touching inventory. Guarded level pointer, set in
	// _tod_distraction::init - never a #using (that module imports us for
	// get_level; importing it back is the KB cycle rule). Undefined = the module
	// is not in the build, and the grenade simply reconciles on next spawn.
	// Ours SURVIVES the promotion (set_scope "class"), so this is not a re-grant
	// but a re-assert: the reconcile re-stamps the tactical slot pointer, which
	// nothing else in tier_up touches.
	if ( isdefined( level.tod_distract_reconcile ) )
		player [[ level.tod_distract_reconcile ]]();
	// RIOT SHIELD (domain 45): same lane, same reason — equipment is inventory
	// and this path writes a level. Pointer set in _tod_riotshield::init.
	if ( isdefined( level.tod_shield_reconcile ) )
		player [[ level.tod_shield_reconcile ]]();
	player PlayLocalSound( "tod_ultimate_sting" );   // tod_tier_sting once the alias exists
	return true;
}

// self = player. Un-apply the live effects the reset levels were driving —
// the 1s body loop only ever SETS most of them.
function reset_gun_state()
{
	// ⚠️ v15 AUDIT (item 19). This function clears RUNNING COUNTERS, not levels
	// — tier_up's loop above owns the levels. When persistence became the
	// default, four of the six lines here were quietly clearing progress toward
	// a payout on a domain the player now KEEPS, which reads in play as "my
	// upgrade got reset" even though the level survived.
	//
	// KEPT (the domain still resets, so its counter must too):
	//   tod_thor_next_ms  — THOR'S THUNDER is Leviathan-bound, still "gun".
	// KEPT FOR A DIFFERENT REASON (not a progress counter):
	//   tod_feed_t        — BULLET FEED's DEBT, i.e. fractional ammo owed
	//                       against the OLD gun's fire rate. The domain
	//                       persists now, but carrying a debt across a weapon
	//                       swap would pay it at the new gun's rate. Zeroing
	//                       loses at most one round.
	//   tod_scav_pay_ms   — a same-frame de-dupe stamp, meaningless after a
	//                       promotion; clearing it can only ever be correct.
	// NO LONGER CLEARED (the domain persists, so the progress does too):
	//   tod_bounty_bank      — BOUNTY's sub-10-point remainder. Confiscating it
	//                          was always odd; now the domain survives, it is
	//                          simply theft.
	//   tod_scav_bank        — SCAVENGER's bank (tenths of a kill toward the
	//                          next round, v16.42; the kill counter before). A player one
	//                          kill from a reserve round lost it to a promotion.
	//   (tod_killreload_kills was the third and the worst case — a 55-kill
	//   accumulator at Lv1 — until KILL RELOAD was retired 2026-09-01.)
	self.tod_thor_next_ms = undefined;
	// ADRENALINE (v16): the domain is scope "gun", so tier_up wipes its LEVEL —
	// a cooldown stamp or a half-built multi-kill streak must not outlive it.
	// Listed here under the same rule as thor above: the domain still resets, so
	// its counters must too.
	self.tod_adren_next_ms = undefined;
	self.tod_adren_mk_n = 0;
	self.tod_adren_mk_ms = undefined;
	self.tod_adren_until = undefined;
	self.tod_feed_t = 0;              // BULLET FEED debt — see the audit note above
	self.tod_scav_pay_ms = undefined;
	// (The TIRELESS un-apply lived here until 2026-08-26. Nothing to undo now:
	// no script touches the sprint knobs or grants specialty_staminup.)
	// SPRINT FIRE: the body loop's UnsetPerk branch strips it within 1s.
}

// Returns true when the card actually paid out, false when it did not (a
// refused TIER pick, a dead/maxed card). Callers fall back to the OTHER card
// on a refused tier pick so a deal (or a station buy) is never forfeited.
function apply_upgrade( player, o )
{
	// DARK UPGRADE (v17.10) — FIRST, above every levels test. A dark card is
	// dealt on a domain with ZERO headroom by definition, so `o.levels` is 0 and
	// every branch below would refuse it. It pays a BIT, not levels; see the
	// DARK UPGRADES block for why it must never be stored as level max+1.
	if ( IS_TRUE( o.dark ) )
	{
		if ( !isdefined( player.tod_dark ) )
			player.tod_dark = [];
		if ( IS_TRUE( player.tod_dark[ o.domain ] ) )
			return false;   // already held — the pool should have filtered it, but a concurrent deal can race
		player.tod_dark[ o.domain ] = true;
		player notify( "tod_upgrade_applied", o.domain );
		player notify( "tod_dark_applied", o.domain );
		// Inventory domains reconcile off a LEVEL write; a dark bit is not one,
		// so poke the same two pointers by hand. Both are guarded — undefined
		// means the module is not in this build.
		if ( isdefined( level.tod_distract_reconcile ) )
			player [[ level.tod_distract_reconcile ]]();
		if ( isdefined( level.tod_shield_reconcile ) )
			player [[ level.tod_shield_reconcile ]]();
		// AND RE-SYNC THE PAUSE ROWS (fix 2026-09-04, user: "I have both dark
		// luck and dark riot shield and neither of them are in the pause menu
		// showing the dark version"). The dark bit reaches the client ONLY as
		// sync_max()'s +200 on a tod_upg_sync row, and this early return skipped
		// the refresh_upgrade_list() every other apply path ends with — so a dark
		// pick was invisible until some OTHER domain gained a level and re-sent
		// the whole table. In the spire that can be a long time or never: a won
		// trial is the only deal, and a dark card is by definition dealt on a
		// domain with no headroom left.
		//
		// THE LESSON: an early return past the tail of a function inherits none
		// of its obligations. Every payout lane owes the same three — the level
		// write (here, the bit), the inventory reconcile, and the client sync.
		player refresh_upgrade_list();
		return true;
	}
	if ( o.levels <= 0 )
		return false;
	// CLASS TIER card: OPT-IN only. A timeout locks the focused card for every
	// other domain, but a weapon swap the player did not choose must never
	// happen — a timed-out tier pick is refused (docs/25 §4.2) and the caller
	// applies the other card instead.
	if ( o.domain == "tier" )
	{
		if ( IS_TRUE( player.tod_upg_timed_out ) )
			return false;
		return tier_up( player );
	}
	// MONOTONIC (verify 2026-08-20): never trust o.cur — it was snapshotted
	// at roll time, and a concurrent apply (personal-station pick landing in
	// the same window a round event rolled, or vice versa) makes it stale.
	// Re-read, add ON TOP, clamp at max, and never write downward.
	cur = get_level( player, o.domain );
	lv = cur + o.levels;
	if ( isdefined( o.max ) && lv > o.max )
		lv = o.max;
	if ( lv <= cur )
		return false;   // the domain already advanced past this card — nothing to add
	player.tod_levels[ o.domain ] = lv;
	player notify( "tod_upgrade_applied", o.domain );
	// DISTRACTION (domain 41): a grenade is INVENTORY, and this path writes a
	// LEVEL without touching inventory. Guarded level pointer, set in
	// _tod_distraction::init - never a #using (that module imports us for
	// get_level; importing it back is the KB cycle rule). Undefined = the module
	// is not in the build, and the grenade simply reconciles on next spawn.
	if ( isdefined( level.tod_distract_reconcile ) )
		player [[ level.tod_distract_reconcile ]]();
	// RIOT SHIELD (domain 45): same lane, same reason — equipment is inventory
	// and this path writes a level. Pointer set in _tod_riotshield::init.
	if ( isdefined( level.tod_shield_reconcile ) )
		player [[ level.tod_shield_reconcile ]]();
	player refresh_upgrade_list();

	// body domains apply instantly, not on the next spawn/tick
	if ( o.domain == "sprint" || o.domain == "mobility" )
		player apply_move_speed();
	// VITALITY (v14.11): the new max HP lands NOW, additively — the same
	// shape stock jugg uses (+= on the current max), so it composes with an
	// active jugg instead of being swallowed by it. The gained HP is also
	// HEALED in (a card is a payoff, the jugg-purchase precedent), unlike the
	// body loop's floor, which only ever raises the ceiling. If stock later
	// clobbers the max (jugg loss restore, spawn reboot), the body-loop floor
	// re-raises it within a second.
	if ( o.domain == "vitality" )
	{
		hp_add = ladder5( lv ) - ladder5( cur );
		player.maxhealth = player.maxhealth + hp_add;
		player SetMaxHealth( player.maxhealth );
		if ( IsAlive( player ) && !( player laststand::player_is_in_laststand() ) )
		{
			player.health = player.health + hp_add;
			if ( player.health > player.maxhealth )
				player.health = player.maxhealth;
		}
	}
	// twin domains swap the gun in place immediately — reconcile is generic
	// now (it compares the held variant to the axes' levels), so every apply
	// may call it; it returns in one compare when nothing changed.
	player reconcile_twin();

	// (apply print removed 2026-08-20 — the card flash IS the confirmation)
	return true;
}

// ---------------------------------------------------------------------------
// World pause — spawning halts via the stock world_is_paused flag
// (round_spawning waits on it, _zm.gsc:3747); live zombies get frozen +
// ignoreall so they stand down while everyone chooses.
//
// AND EVERY UPRIGHT PLAYER IS INVULNERABLE FOR AS LONG AS IT HOLDS (v17.94,
// user 2026-09-05: "During these upgrades we should make players invincible
// as well just in case"). The freeze is built from per-actor writes — rate,
// ignoreall, a parked tree — and the Fury just proved that an actor with its
// own writers can slip one for a while. The engine's invulnerability is the
// net UNDER all of that: no melee notetrack, no flame tick, no splash and no
// script DoDamage lands while it is on. It is the same call the zombie-blood
// window, the finale's depart and the summit win already lean on. Applied to
// players alive and upright (a downed player was never frozen and is
// bleeding, not being hit); released only for players THIS function armed
// (tod_pause_invuln) and only when no other lane still holds the flag —
// stock uses the same call for its out-of-bounds kill and nothing else in
// play, so the lanes to respect are ours: zombie blood, depart, summit_win.
// Symmetric with upgrade_damage_cb's return 0: nobody hits anybody.
// A player who spawns INTO a pause is not covered (the world is frozen around
// them); the next set_world_pause( true ) covers them — trial_win and
// run_upgrade_event both call it, idempotently.
// ---------------------------------------------------------------------------

function set_world_pause( on )
{
	// Keep both edges even when an entire pause falls between recorder samples.
	if ( IS_TRUE( level.tod_dev ) )
	{
		if ( on ) level.tod_ai_diag_pause_on = GetTime();
		else level.tod_ai_diag_pause_off = GetTime();
	}
	if ( on )
	{
		level.tod_upgrade_pause = true;
		if ( !( level flag::exists( "world_is_paused" ) ) )
			level flag::init( "world_is_paused" );
		level flag::set( "world_is_paused" );
	}

	players = GetPlayers();
	foreach ( p in players )
	{
		if ( !isdefined( p ) || !isplayer( p ) )
			continue;
		if ( on )
		{
			if ( !isalive( p ) || ( p laststand::player_is_in_laststand() ) )
				continue;
			p EnableInvulnerability();
			p.tod_pause_invuln = true;
		}
		else if ( IS_TRUE( p.tod_pause_invuln ) )
		{
			p.tod_pause_invuln = undefined;
			if ( !( p pause_invuln_held_elsewhere() ) )
				p DisableInvulnerability();
		}
	}

	team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
	zombies = GetAITeamArray( team );
	foreach ( z in zombies )
	{
		if ( !isdefined( z ) || !isalive( z ) )
			continue;
		if ( on )
		{
			z.tod_frozen = true;
			z.ignoreall = true;
			z ASMSetAnimationRate( 0.05 );
			// Empty dev/dark deals can open and close in one frame. Latch the
			// write so the elite's 250 ms watcher cannot miss its restore.
			if ( isdefined( z.tod_elite_base_rate ) ) z.tod_elite_pause_pending = true;
			if ( IS_TRUE( level.tod_dev ) ) z.tod_ai_diag_pause_write = GetTime();
		}
		else
		{
			z.tod_frozen = undefined;
			z.ignoreall = false;
			// anim rate restored by _tod_zombie_speed's keep-alive sweep...
			// ...EXCEPT FOR A ZOMBIE MID-CLIMB-OUT (2026-09-04). That sweep
			// early-returns on `in_the_ground` (_tod_zombie_speed.gsc:313,
			// correctly — it must not fight a scripted animation), and
			// _tod_stray::eligible refuses the same field, so NOTHING restored
			// the 0.05 this function stamped on a riser that was mid-rise when
			// the pause began. The freeze half is symmetric and stays; only the
			// restore was missing, and the cost of missing it is severe out of
			// all proportion to the write: while `in_the_ground` holds, stock's
			// zombie_think is still blocked on waittill("risen")
			// (_zm_spawner.gsc:581), so `zombie_think_done` is never set, and
			// the ROOT of the behaviour tree runs `idlespawnbehavior` — a
			// looping idle@zombie gated on condition_script_negate
			// zombieisthinkdone (behavior/zm_zombie.ai_bt:117-137) that sits
			// ABOVE the playable-area branch carrying findfleshservice (:552).
			// The zombie therefore has NO enemy, NO goal and NO FindFlesh tick
			// — and hide_pop already Show()ed it half a second into the rise
			// (zombie_utility.gsc:1592-1607). That is a fully visible zombie
			// standing still and never targeting anyone: the reported bug,
			// verbatim. 1 is the neutral clip rate; the keep-alive sweep takes
			// the zombie back over the moment the climb-out completes.
			// ...but never over a slow effect the player paid for: Widow's Wine's
			// cocoon and Time Warp both own the rate, and every other anim-rate
			// writer in the tree checks this before touching it.
			if ( IS_TRUE( z.in_the_ground ) && !( z tod_zombie_speed::under_anim_slow() ) )
				z ASMSetAnimationRate( 1 );
		}
	}

	if ( !on )
	{
		if ( level flag::exists( "world_is_paused" ) )
			level flag::clear( "world_is_paused" );
		level.tod_upgrade_pause = false;
	}
}

// self = player. True while another lane owns this player's invulnerability,
// so the pause's release must not clear it: the zombie-blood window
// (_tod_powerups, tod_in_blood), the finale's depart (tod_finale_state) and
// the summit win (tod_spire_won). Each of those clears or never clears the
// flag on its own terms; the pause only ever undoes its own arm.
function pause_invuln_held_elsewhere()
{
	if ( IS_TRUE( self.tod_in_blood ) )
		return true;
	if ( IS_TRUE( level.tod_spire_won ) )
		return true;
	if ( isdefined( level.tod_finale_state )
	     && ( level.tod_finale_state == "departing" || level.tod_finale_state == "done" ) )
		return true;
	return false;
}

// ---------------------------------------------------------------------------
// DAMAGE + FIRE RATE — the actor damage chain. self = the zombie victim.
// Return -1 = untouched (lets later callbacks run); returning a value is the
// final damage (legitimate here — we ARE the modifier).
// ---------------------------------------------------------------------------

// SPRINTER ARMOR — the fraction of a hit that reaches an Armored Sprinter, and
// 1.0 for every other victim. ONE OWNER since v14.20, because the armor stopped
// being a single inline read the moment it stopped being bullets-only: TWO
// lanes need it now, and the second one is the reason the user could feel a
// hole here at all.
//   1. the main damage path in upgrade_damage_cb, below.
//   2. the tod_cleave_hit PASS-THROUGH at the top of that function. CLEAVE
//      splash and IMPACT ROUNDS splash both mark the victim and return -1
//      ("the splash already carries the final damage") — so they slipped the
//      armor completely, before AND after this change. For CLEAVE that is the
//      biggest melee leak of the set: it is the SLASHER's own splash, i.e.
//      exactly the class the user reports as too strong against this enemy.
// The WISP TEA pass-through is deliberately NOT armored — see the note there.
function sprinter_armor_frac( victim )
{
	if ( !isdefined( victim ) || !IS_TRUE( victim.tod_is_sprinter ) )
		return 1.0;
	// The level field is the live source; the literal only fires if the
	// sprinter module somehow never init'd. Tracks TOD_SPRINT_DMG_FRAC
	// (1/3 since the 2026-08-29 same-day retune; was 1/4).
	return ( ( isdefined( level.tod_sprinter_dmg_frac ) ) ? level.tod_sprinter_dmg_frac : 0.3333 );
}

function upgrade_damage_cb( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, psOffsetTime, boneIndex, surfaceType )
{
	// Event stamp: proves to _tod_bosses::rp_damage_feed (the per-boss
	// aiOverrideDamage callback, which stock dispatches AFTER this chain in
	// the SAME damage event) that this chain already handled the hit — so
	// the feed never double-applies the multipliers or double-pushes the
	// crosshair number. self = the damaged actor.
	self.tod_actor_cb_ms = GetTime();

	// No free hits on the frozen horde while everyone picks upgrades — a
	// zero-risk damage window every round would be THE degenerate strategy.
	if ( IS_TRUE( level.tod_upgrade_pause ) )
		return 0;

	// The Double Tap machine credits its buyer, but its authored shots are
	// independent of the buyer's held weapon and upgrade procs. Victim armor
	// still applies; no remote melee/Thor/chain effects or crosshair numbers.
	if ( IS_TRUE( self.tod_perk_machine_hit ) )
	{
		self.tod_perk_machine_hit = undefined;
		return int( Max( 1, damage * sprinter_armor_frac( self ) ) );
	}

	// INSTA-KILL window (level.tod_dmg_mult 3 while active; default 1). Two
	// halves, both below: the ONE-HIT on non-boss actors (the "INSTA-KILL = A
	// REAL ONE-HIT" block, user 2026-08-30), and x3 on the FINAL of every path
	// for the boss/elite triad, so it lifts class, non-class and knife alike.
	dmult = ( isdefined( level.tod_dmg_mult ) ? level.tod_dmg_mult : 1 );

	// A cleave splash re-enters this callback — consume the mark, pass through
	// untouched (the splash already carries the final damage). IMPACT ROUNDS
	// splash borrows the same mark for the same reason.
	//
	// EXCEPT FOR SPRINTER ARMOR (v14.20). "Pass through untouched" was written
	// against the ATTACKER's multipliers — the splash already carries them, so
	// re-applying them would square the bonus. The armor is the VICTIM's, it
	// was never in the splash figure, and skipping it here handed both splash
	// lanes a silent full bypass: a slasher's CLEAVE dealt 3x what the swing
	// that caused it dealt, which is the sharpest edge of the "melee is too
	// strong against it" the user reported. Returning a value instead of -1 is
	// the normal contract (FIRST-NON-(-1)-WINS = this is the final damage).
	// Floor at 1, same as the main lane. push_dmg_num is deliberately still
	// skipped — a splash has never drawn its own crosshair number — so the
	// RICOCHET is the whole feedback that the hit was deflected.
	if ( IS_TRUE( self.tod_cleave_hit ) )
	{
		self.tod_cleave_hit = undefined;
		if ( IS_TRUE( self.tod_is_sprinter ) )
		{
			PlaySoundAtPosition( "tod_sprint_ricochet", self.origin );
			splash = int( damage * sprinter_armor_frac( self ) );
			return ( ( splash < 1 ) ? 1 : splash );
		}
		return -1;
	}
	// v16.62 TRAILBLAZER burn re-enters here (trail_burn_tick -> DoDamage as the
	// runner). The figure is already the design number — a fraction of the
	// ROUND zombie health — so NO attacker multipliers; the VICTIM sprinter
	// armor DOES apply (the cleave rule above; a documented decision, not an
	// omission — see damage-passthrough-marks). Bosses never reach here: the
	// tick skips them upstream with the thunder exclusion set.
	// v18.30 THE MAGE's CHAIN LIGHTNING re-enters here (staff_hit -> DoDamage on
	// the arced zombie with the mark set). The share is already derived from a
	// hit this callback scaled, so NO attacker multipliers; the VICTIM's
	// sprinter armor applies (the cleave rule). INERT while the class is gated
	// off: nothing writes tod_mage_chain_hit.
	if ( IS_TRUE( self.tod_mage_chain_hit ) )
	{
		self.tod_mage_chain_hit = undefined;
		if ( IS_TRUE( level.tod_upgrade_pause ) )
			return 0;
		arc = int( damage );
		if ( IS_TRUE( self.tod_is_sprinter ) )
			arc = int( damage * sprinter_armor_frac( self ) );
		if ( arc < 1 )
			arc = 1;
		if ( isdefined( attacker ) && IsPlayer( attacker ) )
			attacker tod_upgrade_ui::push_dmg_num( arc, false, IS_TRUE( self.tod_is_sprinter ), self );
		return arc;
	}
	if ( IS_TRUE( self.tod_trail_hit ) )
	{
		self.tod_trail_hit = undefined;
		// THE CROSSHAIR NUMBER (v16.94, user 2026-09-03: "I also dont see damage
		// numbers for these"). The burn had none because BOTH exits here skip the
		// normal push site further down: the sprinter arm returns its own value,
		// and the ordinary arm returns -1 to stay silent in the chain. Same shape
		// as the insta-kill branch above, which pushes here for the same reason.
		//
		// Pushed with the value THIS victim actually takes, so a burn on an
		// armored sprinter reads as the reduced number it really is — and it
		// passes the reduced flag, so that one comes up RED like every other
		// armor-cut hit. Never a headshot: fire has no hit location.
		//
		// It rides the same 0.05 s accumulation window as everything else, so a
		// trail lying across a train sums into ONE number per tick rather than
		// one per zombie.
		if ( IS_TRUE( self.tod_is_sprinter ) )
		{
			burn = int( damage * sprinter_armor_frac( self ) );
			if ( burn < 1 )
				burn = 1;
			attacker tod_upgrade_ui::push_dmg_num( burn, false, true, self, true );   // v19.50: burn = ORANGE (wins over red)
			return burn;
		}
		attacker tod_upgrade_ui::push_dmg_num( damage, false, false, self, true );   // v19.50: burn = ORANGE
		return -1;
	}

	// A WISP TEA hit re-enters here WEARING THE OWNER'S NAME — consume the
	// mark and pass through untouched (v14.24; user report: "the wisp will
	// call down lightning ... some bug with thors thunder where it randomly
	// triggers").
	//
	// THE BUG, and it was a live one the moment Wisp Tea shipped: the perk's
	// companion damages with `DoDamage( dmg, wisp.origin, PLAYER, PLAYER,
	// "none", "MOD_MELEE", ... )`. Attacker is the OWNER and the means is
	// MELEE — so every wisp tick arrived at this chain indistinguishable from
	// the player swinging a knife, at a zombie the player may be nowhere near.
	// Everything melee-gated then fired off it:
	//   * THOR'S THUNDER — a Slasher with the Stormbreaker called lightning
	//     down on whatever the wisp touched, which is exactly the "randomly
	//     triggers" the user saw: real strikes, correct code, wrong cause.
	//   * CLEAVE — wisp ticks rolled splash hits of their own.
	//   * the melee CLASS-TIER uniques (DRAW CUT et al) and melee_boss_mult.
	//   * push_dmg_num — crosshair damage numbers for hits the player never
	//     made.
	// It also broke the perk's OWN balance: the wisp's damage is a fraction of
	// the victim's max health (WISP_TEA_*_SEGMENTS = hits-to-kill), so letting
	// the upgrade multipliers scale it made the tier ceilings — including
	// "a wisp can never solo a Panzer" — silently untrue.
	//
	// A companion's damage is not the player's swing. It passes through raw,
	// which makes the .gsh's hits-to-kill numbers mean exactly what they say.
	// The mark rides the VICTIM for one hit, same idiom as tod_cleave_hit
	// above; _zm_perk_wisp_tea sets it immediately before the DoDamage and
	// clears it immediately after, so it can never swallow a real swing.
	//
	// NOT ARMORED AGAINST THE SPRINTER, unlike the cleave/impact mark above,
	// and this is a decision rather than an oversight (v14.20). The wisp deals
	// a FRACTION OF THE VICTIM'S MAX HEALTH — WISP_TEA_*_SEGMENTS is literally
	// hits-to-kill — so it already pays the sprinter's x20 health in full and
	// kills it in exactly the tier's advertised number of ticks. Layering the
	// 1/3 armor on top would make it 3x that, i.e. the sprinter would become
	// the most wisp-proof thing in the map, ahead of the Panzer, off a knob
	// that was never meant to touch percentage damage. Flagged to the user with
	// the v14.20 change; if they want the wisp armored too it is one call to
	// sprinter_armor_frac() here, and the .gsh hits-to-kill numbers stop being
	// true for this one enemy.
	if ( IS_TRUE( self.tod_wisp_hit ) )
	{
		self.tod_wisp_hit = undefined;
		return -1;
	}

	// v19.26 FIRE BLAST's ELITE BURN re-enters here (_tod_mage_elements::
	// elite_burn -> DoDamage with the mark set). The tick is a share of the
	// victim's MAX health, so it is already the design number: NO attacker
	// multipliers and NO sprinter armor (the wisp's reasoning, one branch up --
	// percent-of-max already paid the sprinter's health in full). Unlike the
	// wisp it is the PLAYER's damage, so the crosshair number is pushed. The
	// burn also stamps tod_mage_hit_ms for the Panzer's own wrap; that branch
	// below would otherwise apply the sprinter armor, which is why this one
	// sits ABOVE it. Under a world pause the tick is skipped upstream.
	if ( IS_TRUE( self.tod_mage_burn_hit ) )
	{
		self.tod_mage_burn_hit = undefined;
		if ( IS_TRUE( level.tod_upgrade_pause ) )
			return 0;
		mg = int( damage );
		if ( mg < 1 )
			mg = 1;
		if ( isdefined( attacker ) && IsPlayer( attacker ) )
			attacker tod_upgrade_ui::push_dmg_num( mg, false, IS_TRUE( self.tod_is_sprinter ), self, true );   // v19.50: burn = ORANGE
		return mg;
	}

	// The slam owns its damage figure. Keep this mark for the Panzer wrapper;
	// the caller clears it synchronously after DoDamage. Never trigger melee procs.
	if ( isdefined( self.tod_smash_hit_ms ) && self.tod_smash_hit_ms == GetTime()
	     && isdefined( attacker ) && IsPlayer( attacker ) && self.tod_smash_attacker == attacker )
	{
		if ( IS_TRUE( level.tod_upgrade_pause ) ) return 0;
		smash_damage = int( damage );
		if ( IS_TRUE( self.tod_is_sprinter ) ) smash_damage = int( damage * sprinter_armor_frac( self ) );
		if ( smash_damage < 1 ) smash_damage = 1;
		attacker tod_upgrade_ui::push_dmg_num( smash_damage, false, IS_TRUE( self.tod_is_sprinter ), self );
		return smash_damage;
	}

	// THE MAGE'S ELEMENTS re-enter here. mage_hit() stamps tod_mage_hit_ms and
	// DoDamages as MOD_UNKNOWN; the figure is ALREADY the design number (a share
	// of the victim's max health, doubled for a matched elite family), so NO
	// ATTACKER MULTIPLIERS -- the TRAILBLAZER contract, for the same reason.
	//
	// A SAME-FRAME MILLISECOND STAMP, NEVER CONSUMED: this chain runs FIRST, so a
	// consumed mark would be gone by the time the Panzer's wrap in _tod_bosses
	// needs it. Same idiom as tod_xmas_hit_ms.
	//
	// The VICTIM's sprinter armor DOES apply (the cleave rule) and the crosshair
	// number is pushed with what the victim actually takes. Never a headshot: a
	// blast has no hit location.
	//
	// NO #using OF _tod_mage_elements HERE, EVER -- that module imports this one,
	// so a call in this direction is a cycle. The mark is the whole interface.
	// INERT while the class is gated off: nothing writes tod_mage_hit_ms.
	if ( isdefined( self.tod_mage_hit_ms ) && self.tod_mage_hit_ms == GetTime()
	     && isdefined( attacker ) && IsPlayer( attacker ) )
	{
		if ( IS_TRUE( level.tod_upgrade_pause ) )
			return 0;
		mg = int( damage );
		if ( IS_TRUE( self.tod_is_sprinter ) )
			mg = int( damage * sprinter_armor_frac( self ) );
		if ( mg < 1 )
			mg = 1;
		attacker tod_upgrade_ui::push_dmg_num( mg, false, IS_TRUE( self.tod_is_sprinter ), self );
		return mg;
	}

	if ( !isdefined( attacker ) || !IsPlayer( attacker ) || !isdefined( weapon ) )
		return -1;

	// HEADSHOT — one owner, headshot_kind(). Two things changed here 2026-08-24,
	// both from "only some guns can hit panzer for headshots":
	//   NECK now counts. LOC_NORM stamps locNeck 3.0 on every generated gun, so
	//   the ENGINE had already paid a full 3x crit on a neck hit before this
	//   callback ran — but the old test omitted it, so the HEADSHOT domain paid
	//   nothing and push_dmg_num drew a plain number on an already-tripled hit,
	//   on EVERY enemy in the map. _tod_bosses::rp_damage_feed's b_head has
	//   always included "neck", so the two lanes openly disagreed.
	//   THE PANZER VISOR now counts. A visor hit arrives as `torso_upper`, so
	//   this callback used to call it a body shot: no crit, no domain, no luck —
	//   while _tod_bosses' wrap was separately treating it as a head hit for
	//   damage. The two halves of our own code disagreed about the same bullet.
	// The wrap supplies the 3.0 the engine skipped, so a visor hit and a true
	// head hit now come out to exactly the same number.
	headshot = ( headshot_kind( self, sHitLoc, vpoint ) != "none" );

	// INSTA-KILL = A REAL ONE-HIT ON THE TRASH HORDE (user 2026-08-30: "make
	// instakill a one hit on normal zombies but keep the 3x for everything
	// else"). While the window is live (dmult > 1), any player hit on a
	// non-boss actor is simply lethal; the boss triad — Panzer, Rogue
	// Protector, Reaver, AND the hellhounds (they carry all three flags,
	// _tod_hellhounds.gsc:345-347) — falls through to the normal math below,
	// where dmult still multiplies the final: that IS the kept 3x. Armored
	// sprinters carry no boss flag, so they one-hit too — "insta-kill treat
	// them as the zombies they are" was accepted at their design
	// (_tod_sprinter.gsc:41), and returning the lethal value directly is what
	// lets the hit bypass their 1/4 bullet armor further down.
	// Placed AFTER the cleave-consume (a splash must pass through untouched,
	// mark cleared) and AFTER the player-attacker guard (a boss clubbing a
	// zombie is not an insta-kill). Skipping the rest of the chain skips
	// on-hit procs (SUPPRESSING FIRE et al.) for the window — irrelevant, the
	// victim is dead. The crosshair number is pushed here because the normal
	// push site is never reached on this path (the xmas_fixed_shots_cb
	// pattern).
	if ( dmult > 1 &&
	     !IS_TRUE( self.is_boss ) && !IS_TRUE( self.acc_is_boss ) && !IS_TRUE( self.acc_is_mini_boss ) )
	{
		kill = ( ( isdefined( self.health ) && self.health > 0 ) ? self.health : 32767 ) + 666;
		attacker tod_upgrade_ui::push_dmg_num( kill, headshot, false, self );
		return kill;
	}

	// GUN BALANCE PASS (user 2026-08-20: "pistol was doing like 6 damage a
	// shot while m60 was doing 100+ — apply an evenly spread balance"):
	// per-gun multipliers on the RAW damage, script-side ONLY — the Skye GDTs
	// are install-side and SHARED with map 1, never edit them. GDT bases:
	// ak74u 180 / krig 195 / m60 290(no falloff) / stock pistol ~25 w/ heavy
	// falloff. Applied to every weapon before the class multipliers.
	balance = gun_balance_mult( weapon );
	damage = damage * balance;

	// PACK-A-PUNCH TIERS (v17.33) — the spire's 25,000 / 50,000 re-packs. See
	// the define block at the top of _tod_classes.gsc for why this is a
	// multiplier and not a weapon asset (the twin ledger is at 229 of 229).
	//
	// APPLIED HERE, BESIDE gun_balance_mult, AND NOT IN THE `mult` SUM BELOW.
	// The sum is where DAMAGE, HEADSHOT, GIANT SLAYER and the dark adds live;
	// dropping a +50% into it would make the tier worth progressively less the
	// more DAMAGE levels a player owns (against a maxed +100% it would land as
	// +25% real), which is not what a 50,000-point pack should feel like.
	// Multiplying the raw damage scales the base hit AND every one of those
	// domains together, exactly the way the stock pack's own +25% does.
	//
	// Returns 1.0 at tier 0 and tier 1, so this line is inert for the whole
	// tower and costs one array lookup per hit there.
	//
	// CAPTURED, because the "nothing modified -> return -1" guard at the bottom
	// has to test it. Without that test a PACK II/III holder with no
	// attacker-side term (dmg_lvl 0, no Insta-Kill, ordinary victim) hits the
	// guard, `final` is discarded and stock applies the UNPACKED damage -- the
	// spire re-pack silently doing nothing for exactly the players who have not
	// drawn DAMAGE yet. Same shape as the v16.3 sprinter_armor_frac miss below.
	pap_mult = tod_classes::pap_tier_mult( attacker, weapon );
	damage = damage * pap_mult;


	// ONE DAMAGE LANE FOR EVERY WEAPON (user 2026-08-23: "there is a damage
	// upgrade. Your secondary should get that upgrade as well" -> "lets widen as
	// much as we can without twins"). The non-class-primary branch that used to
	// sit here applied DAMAGE and nothing else; it is GONE. A sidearm — and a
	// powerup gun — now runs the SAME lane as the class gun, which hands it
	// DAMAGE, HEADSHOT, GIANT SLAYER, the script-side uniques (MOMENTUM,
	// OVERDRIVE) and unique_on_hit (SUPPRESSING FIRE, IMPACT ROUNDS). Every one
	// of those is arithmetic over levels the player already owns, so opening the
	// lane costs zero weapon assets — which is the whole reason it can be done.
	//
	// WHAT STAYS CLASS-GUN-ONLY, and why neither is an oversight:
	//   * the TWIN domains (FIRE RATE, HANDLING, RECOIL, MAG SIZE, PENETRATION,
	//     KNIFE SPEED) are weapon-VARIANT ladders. gen_tod_twins.js builds those
	//     forms for the class guns alone, and building them for four more
	//     sidearms multiplies registrations straight into the ~230-twin boot
	//     ceiling. The NO-TWIN rule forbids it, not this function.
	//   * CLEAVE and THOR gate on MELEE further down, which no sidearm deals.
	//     The mechanic is its own gate; it needs no weapon test.
	//
	// One consequence to know rather than discover: the gun_keys comment below
	// ("a level > 0 here means the right gun is in hand") was true only while
	// this branch existed. gun_keys gates what you can ROLL, never what fires —
	// so a heavy holding OVERDRIVE now gets it on the pistol too. Intended.

	dmg_lvl = get_level( attacker, "damage" );
	hs_lvl = get_level( attacker, "headshot" );

	mult = 1.0 + dmg_lvl * TOD_UPG_DMG_PER_LVL;
	// headshot_bonus owns the rate AND the dark step (2026-09-08) — the dark add
	// that used to sit in the block below has moved inside it, so this one call
	// is the whole HEADSHOT contribution on this lane. hs_lvl stays because the
	// silent-return fast path at the end of this function still tests it.
	if ( headshot )
		mult += headshot_bonus( attacker );
	// DARK UPGRADES (v17.10) — flat adds into the SAME additive sum, so they are
	// worth exactly what their table row says and cannot double-apply. There is
	// no upper clamp anywhere on the path from here to `swing`, so the whole step
	// lands. A dark bit implies the domain is MAXED, so these stack on top of
	// dmg_lvl 10 / hs_lvl 10, never instead of them.
	if ( has_dark( attacker, "damage" ) )
		mult += TOD_DARK_DMG_ADD;
	// (DARK HEADSHOT moved into headshot_bonus() on 2026-09-08, so the boss lane
	// gets it too — it never did while this was an inline add here.)
	// (ECHO ROUNDS removed 2026-08-23 — see the note at its old add_domain.)

	// CLASS TIER UNIQUES (docs/25 §9): OVERDRIVE / MEAT GRINDER (sustained
	// fire) and DRAW CUT (a swing out of a sprint). gun_keys already bind each
	// domain to its gun, so a level > 0 here means the right gun is in hand.
	is_melee = ( isdefined( meansofdeath ) && IsSubStr( meansofdeath, "MELEE" ) );
	umult = unique_damage_mult( attacker, is_melee );
	mult += umult;

	// GIANT SLAYER (domain 35, v9.45; 12%/Lv since v16.50): +12%/Lv, and ONLY against the boss/elite
	// triad and (v19.58) the armored sprinter - is_card_elite. This is the lane that fires for the Panzer (his actor_damage_func
	// wrap runs after us and re-scales by hit-location ratios, so a bonus
	// applied here survives it) and for the Reaver. The Rogue Protector's own
	// aiOverrideDamage fallback carries the same call — see rp_damage_feed.
	bmult = boss_damage_bonus( attacker, self );
	mult += bmult;

	// GUNSLINGER (v16.99) — the slasher's sidearm-vs-boss ladder joins the sum
	// HERE, beside GIANT SLAYER, instead of multiplying the final further down.
	// See gunslinger_bonus for why it moved. The 2.25 class baseline is still
	// applied multiplicatively below; only the per-level term is additive.
	gmult = gunslinger_bonus( attacker, self, weapon );
	mult += gmult;

	// THE MAGE'S STAFFS (v18.30): tier ladder x matchup x the staff's own card,
	// through the guarded pointer _tod_mage_elements sets (that module imports
	// this one -- no #using the other way). 1.0 for anything that is not a
	// staff; undefined while the class is gated off.
	// CAPTURED for the same reason as pap_mult above: the guard at the bottom
	// tests it. The mage is the ONE class whose whole power budget lives in a
	// multiplier the guard did not enumerate -- tier ladder x matchup x
	// ARCHMAGE x the fire charge x FIRE BLAST / ICE SHATTER, all of it. A mage
	// can never satisfy umult (skirmisher/heavy uniques) or bmult (assault's
	// GIANT SLAYER), splash takes no hit location so the headshot clause is
	// always true, and gun_balance_mult has no staff branch -- so before this
	// was added EVERY mage without a DAMAGE level dealt raw GDT staff damage to
	// every victim but an armored sprinter, while push_dmg_num below had
	// already shown them the multiplied figure. 1.0 while the class is gated
	// off, so this costs the other four classes one comparison.
	mage_mult = 1.0;
	mage_pierce = false;
	if ( isdefined( level.tod_mage_staff_mult ) )
	{
		mage_mult = [[ level.tod_mage_staff_mult ]]( attacker, self, weapon );
		mult = mult * mage_mult;
		mage_pierce = [[ level.tod_mage_pierce_armor ]]( weapon );
	}

	// MELEE vs BOSSES (user 2026-08-24): halved, and applied to the FINAL so it
	// scales the base hit, DAMAGE, GIANT SLAYER, DRAW CUT and the insta-kill
	// window together rather than fighting them one at a time. Non-melee hits
	// and non-boss victims both return 1.0, so this line is inert everywhere
	// else. The crosshair number below is pushed AFTER it, so what the player
	// reads is what the boss actually took.
	//
	// TWO VALUES ON PURPOSE. `swing` is the swing BEFORE the boss scale;
	// `final` is what THIS victim takes. CLEAVE is handed `swing`, because each
	// splash victim applies its OWN melee_boss_mult in cleave_splash — pass
	// `final` and a boss standing next to another boss would be scaled twice
	// (0.25x). Every other consumer wants `final`.
	swing = int( damage * mult * dmult );
	final = int( swing * melee_boss_mult( attacker, self, is_melee ) );

	// THE SLASHER'S SIDEARM vs BOSSES AND ELITES (v16, 2026-09-01): x2.25.
	// Applied to `final` for exactly the reasons melee_boss_mult is — it scales
	// the base hit and every damage domain together, and the crosshair number is
	// pushed after it, so what the player reads is what the boss took.
	//
	// NOT applied to `swing`, deliberately, and the distinction is the same one
	// the CLEAVE note above is about: `swing` is what splash consumers are
	// handed so each victim can apply its OWN boss scale. A sidearm deals no
	// splash today, so passing either would work — but putting it on `final`
	// keeps the rule uniform ("swing is pre-boss-scale, final is what THIS
	// victim takes") instead of creating an exception the next reader has to
	// notice.
	//
	// The two boss multipliers cannot both fire: melee_boss_mult needs a MELEE
	// hit and this needs the class SECONDARY, which is never melee.
	final = int( final * slasher_sidearm_boss_mult( attacker, self, weapon ) );

	// SPRINTER ARMOR (v13.7, user 2026-08-29: "bullets do 1/4 damage on them
	// ... you can hear bullets bouncing off" — spec'd for the Reaver rework,
	// re-scoped the same hour to the NEW Armored Sprinter, lap-30 door; the
	// Fury Reaver is back at lap 20 and never reads these fields). It lives
	// HERE and not in a second register_actor_damage_callback because stock's
	// dispatch (_zm.gsc:5822) is FIRST-NON-(-1)-WINS — this callback returns a
	// final for every player hit, so anything registered after it never runs.
	// Same integration point as melee_boss_mult above, same reason: applied
	// BEFORE push_dmg_num so the crosshair number is what the sprinter took.
	// Fields, not an import (_tod_sprinter sets tod_is_sprinter and publishes
	// level.tod_sprinter_dmg_frac) — the KB cycle rule.
	//
	// ALL DAMAGE TYPES since v14.20 (user 2026-08-30: "Armored sprinter should
	// be resistant to all damage not just bullets. Melee is too strong against
	// it so we need this buff on them"). The old guard was BULLETS ONLY —
	// bullet MODs plus MOD_HEAD_SHOT — with melee/explosives left at full
	// damage as deliberate counter-play (map 1's Shielded contract). That
	// carve-out is what the slasher was exploiting: x20 HP with no armor is
	// x20 to a knife against x60 to a gun, so melee killed a sprinter three
	// times faster than the class the enemy was tuned against. There is no MOD
	// test left at all now — every source that reaches this callback is scaled,
	// which is the whole point, so do not reintroduce one without a fresh ask.
	// Floor at 1 so armor can never make a zombie chip-proof.
	// The RICOCHET and the RED NUMBER now fire for melee and explosive hits
	// too, deliberately: they ARE the "your damage is being deflected" read,
	// and a hit that is quietly cut to a third with no feedback is the version
	// of this that players call a bug. If the metal ricochet reads wrong on a
	// knife swing, split the SOUND on is_melee — never the damage scale.
	b_sprint_armor = false;
	if ( IS_TRUE( self.tod_is_sprinter ) && !mage_pierce )   // v18.30: the FIRE staff burns through the plating -- no cut, no ricochet, no red number
	{
		b_sprint_armor = true;
		final = int( final * sprinter_armor_frac( self ) );
		if ( final < 1 )
			final = 1;
		// THE RICOCHET (v13.9, user: "when you shoot them they will make a
		// sound in the 3D world like a metal ricochet. I have 3 wav downloads
		// ... every shot will trigger one at random. So spraying into it will
		// trigger a whole bunch"). tod_sprint_ricochet = ONE alias, THREE rows
		// in tod_ui.csv — the engine's own multi-row random pick, the same
		// mechanism every multi-take fire sound uses. NO DEBOUNCE, per the
		// spec: per-HIT, so an LMG spray rattles and a shotgun blast lands one
		// per pellet. The old zmb_rocketshield_imp + 200ms debounce is
		// REPLACED, not kept alongside.
		PlaySoundAtPosition( "tod_sprint_ricochet", self.origin );
	}

	// The third arg is the RED-NUMBER flag (v13.9, user: "those damage numbers
	// ... should be red too. Specific for this type of enemy to show you are
	// doing reduced damage"). Only the sprinter armor branch above sets it.
	// Wrapped Panzers publish staff hits after their final armor calculation.
	if ( !tod_upgrade_ui::defer_staff_damage_number( self, weapon ) )
		attacker tod_upgrade_ui::push_dmg_num( final, headshot, b_sprint_armor, self );

	// v18.30 THE MAGE's on-hit: burn tell (fire), slow (ice), CHAIN LIGHTNING
	// (lightning). Threaded, after the figure is final, on the victim.
	if ( isdefined( level.tod_mage_staff_hit ) )
		self thread [[ level.tod_mage_staff_hit ]]( attacker, weapon, final );

	// SUPPRESSING FIRE + IMPACT ROUNDS ride bullet hits only (never the cleave
	// re-entry above, never melee).
	//
	// `swing`, NOT `final` — the same two-value rule cleave_splash follows, and
	// for the same reason (v14.29 follow-up, fixing a defect this change itself
	// introduced). IMPACT ROUNDS builds its splash as a FRACTION of what it is
	// handed, and each splash victim then applies its OWN sprinter armor in the
	// pass-through at the top of this callback. Handing it `final` — which is
	// already armored when the DIRECT victim is a sprinter — made a
	// sprinter→sprinter burst pay the 1/3 twice: ~11% of the raw hit instead of
	// the intended 33%. Exactly the double-scale the "TWO VALUES ON PURPOSE"
	// note above warns about for melee_boss_mult; cleave was written against
	// that trap on purpose and this lane was not.
	// Free of side effects by construction: this call is gated on `!is_melee`,
	// and melee_boss_mult returns 1.0 for non-melee, so `swing` and the
	// pre-armor `final` are the SAME NUMBER — nothing changes except that the
	// armor is no longer applied twice. SUPPRESSING FIRE never reads the value
	// at all (it is a level-scaled slow), so IMPACT ROUNDS is the only consumer.
	if ( !is_melee )
		self unique_on_hit( attacker, swing );

	// CLEAVE (slasher): a melee swing carries into +1 nearby zombie per level.
	// The tod_cleave_hit mark (consumed above) stops the extra hits recursing.
	if ( isdefined( meansofdeath ) && IsSubStr( meansofdeath, "MELEE" ) )
	{
		cleave = get_level( attacker, "cleave" );
		if ( cleave > 0 )
		{
			// v8.9 nerf (user 2026-08-21): CHANCE ladder, not guaranteed count.
			// Within a block of 3 levels the chance climbs +33%/Lv
			// (Lv1 33% / Lv2 67% / Lv3 always +1). Max level is 3 since
			// v14.11 (user: "too OP"), so the second block (Lv4-6, a second
			// extra) is unreachable — the `extra > 2` clamp below is dead
			// belt, kept in case the cap ever goes back up.
			extra = int( cleave / 3 );              // guaranteed extras
			rem = cleave % 3;                        // 0/1/2 -> 0%/33%/67%
			if ( rem > 0 && RandomInt( 3 ) < rem )
				extra++;
			// DARK UPGRADE (v17.10): a GUARANTEED second extra target -- the second
			// block of the ladder that the v14.11 cap made unreachable, handed over
			// whole rather than as another chance roll. This is the case the clamp
			// below and cleave_splash's count argument were both left in place for:
			// its loop already takes 2 and its echo already fires once per swing
			// rather than once per victim, so nothing downstream changes.
			if ( has_dark( attacker, "cleave" ) )
				extra = TOD_DARK_CLEAVE_EXTRA;
			if ( extra > 2 )
				extra = 2;
			if ( extra > 0 )
				self thread cleave_splash( attacker, swing, extra, weapon );   // `swing`, not `final` — see the two-value note above
		}

		// THOR'S THUNDER: the melee hit calls lightning down on the victim.
		// Skipped for cleave-splash hits (tod_cleave_hit) so one swing is one
		// strike, and rate-limited per player.
		thor = get_level( attacker, "thunder" );
		if ( thor > 0 && !IS_TRUE( self.tod_cleave_hit ) )
		{
			now = GetTime();
			// Infinite Ammo drop = no cooldown for the melee class (user
			// 2026-08-21). MAX_LIVE still caps the bolt storm.
			inf = ( isdefined( level.zombie_vars ) && IS_TRUE( level.zombie_vars[ "zombie_powerup_infiniteammo_on" ] ) );
			if ( inf || !isdefined( attacker.tod_thor_next_ms ) || now >= attacker.tod_thor_next_ms )
			{
				cd = ( inf ? 0 : thor_cooldown_ms( thor, attacker ) );
				attacker.tod_thor_next_ms = now + cd;
				level thread thor_strike( self.origin, attacker, weapon, thor );
			}
		}
	}

	// MELEE vs BOSSES must be part of this test (user 2026-08-24). The halving
	// is the ONE multiplier here that fires on a player holding zero upgrades —
	// a fresh slasher swinging at a Panzer has dmult 1, balance 1.0 and every
	// level at 0, so without this clause the guard below would return -1 and the
	// chain would keep the UNHALVED stock damage. The nerf would then apply only
	// to players who already had upgrades, which is exactly backwards.
	//
	// v16.3 (repo review 2026-09-01): the two VICTIM-side terms applied above —
	// sprinter_armor_frac (v13.7) and slasher_sidearm_boss_mult (v16) — were
	// missing from this test. A player with no attacker-side term active
	// (dmg_lvl 0, no headshot level, no unique, no bounty: every fresh player,
	// and every player right after a promotion until v15) hit the -1 here and
	// stock applied the UNARMORED damage — while the crosshair had already
	// pushed the red one-third number. Same shape as the melee clause, same fix.
	// v18.59 (2026-09-09): the MAGE STAFF MULTIPLIER and the script-paid
	// PACK II/III were the third and fourth terms to be applied above and left
	// out of this test — the same omission as v16.3, two builds after the mage
	// shipped. Both are captured at their application sites; read the comments
	// there for what each one silently discarded.
	if ( dmult == 1 && balance == 1.0 && dmg_lvl == 0 && ( hs_lvl == 0 || !headshot ) && umult == 0 && bmult == 0
	  && mage_mult == 1.0
	  && pap_mult == 1.0
	  && melee_boss_mult( attacker, self, is_melee ) == 1.0
	  && sprinter_armor_frac( self ) == 1.0
	  && slasher_sidearm_boss_mult( attacker, self, weapon ) == 1.0
	  && gunslinger_bonus( attacker, self, weapon ) == 0.0 )
		return -1;   // nothing modified — stay silent in the chain
	return final;
}

// ---------------------------------------------------------------------------
// CLASS TIER UNIQUES — the effects (docs/25 §9). Inputs: _tod_uniques.gsc
// keeps tod_fire_streak / tod_fire_last_ms / tod_sprint_end_ms on the player.
// ---------------------------------------------------------------------------

// PER-STACK damage bonus. The user specifies the TOTAL at full ramp (5/10/15/
// 20/25% for Lv1..Lv5), and the ramp is TOD_OVERDRIVE_STACKS stacks, so the
// per-stack value is that total / 5 — i.e. a clean 1%/2%/3%/4%/5%.
// Written as the division rather than as 0.01/0.02/... so the relationship to
// the user's numbers stays visible and changing STACKS cannot silently change
// the ceiling.
function overdrive_pct( lvl )   // per stack
{
	return overdrive_total_pct( lvl ) / TOD_OVERDRIVE_STACKS;
}

// The advertised ceiling: what a fully-ramped OVERDRIVE is worth at this level.
// v16: 5 tiers, +5% each, so Lv5 = +25% ("125% damage instead of 100%").
function overdrive_total_pct( lvl )
{
	if ( lvl <= 0 ) return 0;
	if ( lvl > 5 ) lvl = 5;
	return 0.05 * lvl;
}

// DEAD as of 2026-08-23 — MEAT GRINDER was removed and the Death Machine now
// carries OVERDRIVE. grinder_pct/grinder_cap and TOD_GRINDER_PER are kept,
// unreferenced, purely as the record of its tuning (+2/3/4% per 5 rounds,
// capped +50/75/100%) in case it is ever wanted back. Nothing calls them.
function grinder_pct( lvl )     // per stack — DEAD, see above
{
	if ( lvl >= 3 ) return 0.04;
	if ( lvl == 2 ) return 0.03;
	return 0.02;
}

function grinder_cap( lvl )     // total cap
{
	if ( lvl >= 3 ) return 1.0;
	if ( lvl == 2 ) return 0.75;
	return 0.5;
}

// -> the ADDITIVE damage multiplier the uniques contribute to this hit.
// RUN AND GUN's damage stage table (v16.50). LOCKSTEP MIRROR of
// _tod_runandgun::rng_pct() (x0.01). Clamped at both ends so a level past the
// domain max, or a stale 0, can never index off the ladder.
function rng_dmg_add( lvl )
{
	if ( lvl <= 1 ) return TOD_UPG_RNG_DMG_L1;
	if ( lvl == 2 ) return TOD_UPG_RNG_DMG_L2;
	if ( lvl == 3 ) return TOD_UPG_RNG_DMG_L3;
	if ( lvl == 4 ) return TOD_UPG_RNG_DMG_L4;
	return TOD_UPG_RNG_DMG_L5;
}

function unique_damage_mult( attacker, is_melee )
{
	add = 0;
	now = GetTime();
	if ( is_melee )
	{
		// DRAW CUT (katana): the swing landed inside the window of a sprint.
		// Three engine orderings are possible for a sprint-initiated melee and
		// the code covers all of them (review 2026-08-22; stock _challenges.gsc
		// hedges the same way with `attackerWasSprinting || sprint_end + N`):
		//   still sprinting at impact       -> IsSprinting() is true NOW;
		//   sprint cleared in the same frame -> tod_sprint_seen_ms (the last
		//       poll that SAW sprinting) is <= 50ms old;
		//   sprint-out gated the swing       -> same stamp, within the window.
		lvl = get_level( attacker, "drawcut" );
		if ( lvl > 0 )
		{
			in_win = ( isplayer( attacker ) && attacker IsSprinting() );
			if ( !in_win && isdefined( attacker.tod_sprint_seen_ms ) && ( now - attacker.tod_sprint_seen_ms ) <= TOD_DRAWCUT_MS )
				in_win = true;
			if ( in_win )
				add += TOD_DRAWCUT_PER_LV * lvl;
		}
		return add;
	}
	// (MOMENTUM removed 2026-08-30, v14.11 — see the note at its old
	// add_domain. Its slot in this function belongs to RUN AND GUN now.)
	// RUN AND GUN's damage half (v14.11): flat +16/28/38/46/52% (v16.50 stage
	// table, rng_dmg_add) on bullets fired while MOVING. Computed BEFORE the fire-streak gate below on purpose —
	// it has nothing to do with holding the trigger, so a lapsed streak must
	// not suppress it (the rule MOMENTUM established in this exact spot).
	// The movement test is a LOCKSTEP MIRROR of _tod_runandgun::is_running()
	// — IsSprinting() OR 2D speed >= the shared 120 floor — so the ammo half
	// and this half fire on the same trigger pull, always together. Applies
	// to any weapon (the ammo half was widened the same way 2026-08-23) and,
	// like MOMENTUM before it, to bosses too.
	// ADRENALINE's damage half (v17.67): while the 3s burst is live, bullets
	// also hit +3%/tier harder (+25% dark) — the SAME adren_bonus() value the
	// move-speed sum reads, so speed and damage can never drift apart. Computed
	// before the fire-streak gate for the same reason RUN AND GUN is: the burst
	// is a kill-streak proc, not a trigger-hold streak.
	if ( isplayer( attacker ) )
		add += attacker adren_bonus();
	lvl = get_level( attacker, "runandgun" );
	if ( lvl > 0 && isplayer( attacker ) )
	{
		moving = ( attacker IsSprinting() );
		if ( !moving )
		{
			v = attacker GetVelocity();
			moving = ( ( v[ 0 ] * v[ 0 ] + v[ 1 ] * v[ 1 ] ) >= ( TOD_UPG_RNG_MIN_SPEED * TOD_UPG_RNG_MIN_SPEED ) );
		}
		if ( moving )
		{
			add += rng_dmg_add( lvl );
			// v18.9 — THE DARK STEP, which only ever reached half this domain. The
			// free-shot half in _tod_runandgun.gsc:109 took its +48 on 2026-09-05;
			// the damage half never did, so TOD_DARK_RNG_ADD sat with ZERO readers
			// while the pause row advertised +100% against a delivered 52%.
			// INSIDE the moving branch deliberately: RUN AND GUN is a movement
			// condition, and adding it outside would pay the dark bonus standing
			// still, which is the one thing this domain must never do.
			if ( has_dark( attacker, "runandgun" ) )
				add += TOD_DARK_RNG_ADD;
		}
	}

	streak = ( isdefined( attacker.tod_fire_streak ) ? attacker.tod_fire_streak : 0 );
	last = ( isdefined( attacker.tod_fire_last_ms ) ? attacker.tod_fire_last_ms : 0 );
	if ( ( now - last ) > TOD_STREAK_GAP_MS )
		return add;   // streak lapsed — streak-based uniques contribute nothing,
		              // but RUN AND GUN above still stands (it is speed, not streak)
	// OVERDRIVE (MP7): +X% per 10 consecutive rounds, 5 stacks
	lvl = get_level( attacker, "overdrive" );
	if ( lvl > 0 )
	{
		stacks = int( streak / TOD_OVERDRIVE_PER );
		if ( stacks > TOD_OVERDRIVE_STACKS )
			stacks = TOD_OVERDRIVE_STACKS;
		od_total = overdrive_total_pct( lvl );
		if ( has_dark( attacker, "overdrive" ) )
			od_total += TOD_DARK_OVERDRIVE_ADD;   // DARK: +25% -> +65% at full ramp
		add += stacks * ( od_total / TOD_OVERDRIVE_STACKS );
	}
	// (MEAT GRINDER removed 2026-08-23 — the Death Machine now carries
	// OVERDRIVE above, which is the same "hold the trigger" mechanic with a
	// +25% ceiling instead of +100%.)
	return add;
}

// self = the zombie that took a BULLET hit from its killer-to-be. Bosses are
// exempt from both (the map's boss-damage doctrine + no boss slows).
// `swing` is the PRE-victim-multiplier damage. IMPACT ROUNDS was its only
// reader and was retired 2026-08-31, so THE PARAMETER IS NOW UNUSED — kept
// rather than dropped because the arg is free, the call site's two-value note
// still governs CLEAVE next door, and changing an arity in the damage chain to
// delete an unused name is a worse trade than an explained spare parameter.
// (History, still load-bearing for cleave: it used to be `final`, which
// double-armored sprinter→sprinter bursts — v14.29.)
function unique_on_hit( attacker, swing )
{
	if ( !isdefined( self ) || !isalive( self ) )
		return;
	if ( IS_TRUE( self.is_boss ) || IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) )
		return;
	// SUPPRESSING FIRE (HK21): a timed playback-rate slow (_tod_zombie_speed owns the rate)
	lvl = get_level( attacker, "suppress" );
	if ( lvl > 0 )
		self tod_zombie_speed::slow( 1.0 - ( TOD_SUPPRESS_BASE + TOD_SUPPRESS_PER_LV * ( lvl - 1 ) ), TOD_SUPPRESS_MS );
	// (IMPACT ROUNDS' burst was the second consumer here and was REMOVED
	// 2026-08-31 — see the retirement note at its old add_domain.)
}

// (IMPACT ROUNDS' impact_splash() was removed 2026-08-31 with the domain —
// see the retirement note at its old add_domain call.)

// The tower's per-gun balance table (see the balance-pass comment above).
// Tune HERE — one number per gun family, applies to base + PaP + twins
// (substring match covers all variant names).
function gun_balance_mult( weapon )
{
	if ( !isdefined( weapon ) || !isdefined( weapon.name ) )
		return 1.0;
	n = weapon.name;
	// CLASS GUNS ARE AT STOCK GDT DAMAGE (user 2026-08-20: "restore back to
	// original GDT — we will tweak from there. Only thing I want to keep is
	// speed with gun"). The v6 balance pass (m60 x0.85 / ak74u x1.1 / krig
	// x1.05) is retired along with the ak74u and m60 themselves; the per-class
	// MOVE SPEED is untouched and lives in class_speed_base(), keyed on the
	// class rather than the gun, so it carried across the roster swap.
	// The starter PISTOL keeps its multiplier — it is not a class gun, and
	// without it the opening rounds are unplayable (stock base ~25 damage).
	// Starter pistol (the MR6) — the HEAVY class's sidearm since secondaries
	// went per-class. ×9.6 (user 2026-08-23: "buff the original pistol that LMG
	// class use by 20% damage"; was ×8.0 from 2026-08-20). Its stock GDT is not
	// in the tools tree, so this multiplier is the only damage number anyone
	// can actually verify about it.
	// PAP FORM NERFED 40% (user 2026-08-23: "mr6 needs a nerf... 40% damage
	// nerf. Only the pap version"): 9.6 × 0.6 = 5.76. The BASE pistol is
	// untouched — it is what carries the opening rounds. This is a split of one
	// family, so it MUST be tested before the generic "pistol_standard"
	// substring: "pistol_standard_upgraded" matches both, and the base branch
	// would swallow the PaP form if it came first.
	// SECONDARY SLOT -25% (user 2026-08-24: "the current secondaries need an all
	// around 25% nerf ... make sure they are all pretty weak compared to the
	// primary slot"). 9.6 x 0.75 = 7.2 base, 5.76 x 0.75 = 4.32 PaP. The PaP
	// form's own 40% nerf is UNTOUCHED and still folded in here — 4.32 is
	// 9.6 x 0.6 x 0.75, so the two nerfs compose rather than replacing each
	// other. THE OPENING ROUNDS RIDE ON THE BASE NUMBER: this is the gun every
	// player holds before the first door, so if round 1-3 starts feeling like
	// chip damage, 7.2 is the digit to move, not the twins' knob.
	// PaP FORM NERFED A FURTHER 50% (user 2026-08-28: "The MR6 pap needs a 50%
	// damage nerf"): 4.32 x 0.5 = 2.16. THE NERFS COMPOSE, they do not replace —
	// 2.16 is 9.6 x 0.6 (the 2026-08-23 40%) x 0.75 (the secondary-slot 25%)
	// x 0.5 (this one). Read the chain before changing any single factor: each
	// one was asked for separately and the product is the shipped number.
	// The BASE pistol stays at 7.2, untouched again — it is the gun every player
	// holds before the first door and it is what carries rounds 1-3. Only the
	// PaP form was named, both times.
	// PaP FORM NERFED A FURTHER 50% (user 2026-09-01: "Death and Taxes need a
	// 50% damage nerf. They are just too good"): 2.16 x 0.5 = 1.08. "Death &
	// Taxes" is the PaP MR6's in-game name (ZMWEAPON_PISTOL_STANDARD_UPGRADED in
	// stock's zombie.str), so the ask names THIS branch and not the base.
	//
	// ⚠️ A CLAIM THAT LIVED HERE FOR THREE DAYS WAS FALSE, AND THE USER'S PLAY
	// REPORT IS WHAT DISPROVED IT. This comment used to read: "NOTE THIS IS NOW
	// BELOW THE BASE: a Pack-a-Punched MR6 does LESS damage than an un-packed one
	// (2.16 vs 7.2)." docs/armory.html repeated it as fact.
	//
	// It does not follow. These multipliers scale each form's OWN GDT damage, and
	// the two forms do not share one — a stock PaP weapon ships a substantially
	// higher base damage than its un-packed form. So comparing 2.16 against 7.2
	// only tells you the PaP is weaker IF the two GDT numbers are equal, which
	// was never checked and is almost certainly untrue. The comment silently
	// assumed it.
	//
	// AND IT CANNOT BE CHECKED FROM HERE. pistol_standard is stock; its GDT is
	// not in this mod-tools install (verified 2026-09-01 — no .gdt in the tools
	// root defines it). So the multiplier really is the only damage number
	// anyone can verify about this gun, which is exactly why an unstated
	// assumption about the other factor survived unchallenged.
	//
	// The user has now played it twice and called it "too good" both times. A
	// play report beats an unverifiable inference: the ratio between the forms
	// is whatever the stock GDTs make it, and the only honest statement is that
	// 1.08 is HALF of what was there yesterday. Do not re-derive "the PaP is
	// weaker than the base" from these two numbers again.
	if ( IsSubStr( n, "pistol_standard" ) )
	{
		if ( IsSubStr( n, "_upgraded" ) ) return 1.08;
		return 7.2;
	}

	// PER-CLASS SECONDARIES (2026-08-23). Only the starter pistol needs a big
	// multiplier — its GDT damage is ~25, which is why it carries ×8. The three
	// Skye ports arrive with real numbers, read straight from their GDTs, so
	// they need no help:
	//   t9_amp63     135 dmg, fireTime 0.092 (~650 RPM), 15-round clip
	//   t9_magnum_b  417 dmg, 6-round clip  (v10.23: was a 250-dmg gun with a
	//                4.0 TORSO / 5.0 head multiplier, the only hit-location
	//                table in the map that was not 1x body / 3x head. Now
	//                normalized with the damage folded in, so HEADSHOT damage
	//                is unchanged at 1,251 and body drops 1,000 -> 417.)
	//   s1_bulldog   120 dmg/pellet, maxDamageRange 325 (falls off fast)
	// The BULLDOG is the one deliberate nerf. SOFTENED to ×0.75 (user
	// 2026-08-23: "Reduce the nerf of bulldog from 50% to 75% damage"; the
	// emergency-only ×0.5 lasted one build). At ×0.75 it is 90/pellet base and
	// 180/pellet PaP, still inside a maxDamageRange of 325 — so it stays a
	// point-blank answer rather than a ranged one, just a less punishing one.
	// NERF REMOVED (user 2026-08-23, after the full playthrough: "Bulldog damage
	// nerf can go to 0. We tried to reduce but it just needs to be removed").
	// The ×0.5 -> ×0.75 softening was not enough to make it worth carrying: the
	// Bulldog is the SKIRMISHER's emergency secondary, its maxDamageRange is 325
	// so it already falls off hard, and a point-blank answer that cannot actually
	// answer anything is dead weight in a slot the class depends on. Full GDT
	// damage now: 120/pellet base, 240/pellet PaP.
	// The branch is kept (returning 1.0) rather than deleted so the next person
	// reading damage_mult_for sees that the Bulldog was CONSIDERED and is
	// deliberately unmodified, instead of assuming it was overlooked.
	// THE BULLDOG AND THE MAGNUM ARE NOT NERFED HERE, AND THAT IS NOT AN
	// OVERSIGHT. Both are GENERATED twins (s1_bulldog_b / t9_magnum_b), so the
	// secondary-slot -25% lands on their GDT damage via SECONDARY_DMG_MULT in
	// tools/gen_tod_twins.js — 120 -> 90 and 240 -> 180 on the Bulldog, 417 ->
	// 313 and 1750 -> 1313 on the Magnum, all verified in the emitted GDT.
	// Adding a x0.75 here as well would apply the nerf TWICE to exactly the two
	// guns that already took it, landing them at 56% instead of 75%.
	if ( IsSubStr( n, "s1_bulldog" ) ) return 1.0;

	// THE AMP63 — the slasher's sidearm, and the one secondary that had no
	// tuning surface at all until now. It is a RAW PORT (no generated twin), so
	// its GDT is outside this repo and this multiplier is the only place its
	// damage can be moved: 135 -> ~101 base. The substring catches all three of
	// its asset names — t9_amp63, t9_amp63_rdw_up, t9_amp63_ldw_up — so the
	// dual-wield halves and the PaP form all take the same 0.75 and the gun
	// cannot end up nerfed in one hand and not the other.
	// v16.12 (user 2026-09-01: slasher secondaries +25% on five numbers, all tiers):
	// 0.75 -> 0.9375. This raw port has NO other tuning surface from this repo -
	// its fire rate, clip, reserve and reload live in the install-side
	// skye_t9_amp63.gdt shared with map 1, so DAMAGE is the one of the five that
	// reaches the T1; the generated T2/T3 (UDM, RK7) take all five. LOCKSTEP:
	// SEC_T1_REF.slasher in gen_tod_twins.js is 135 x THIS number.
	// v19.63 (user 2026-09-30: "Slasher needs a 10% buff all around"):
	// 0.9375 -> 1.03125, and the melee ladder took the same x1.1.
	if ( IsSubStr( n, "t9_amp63" ) ) return 1.03125;

	return 1.0;
}

// ---------------------------------------------------------------------------
// THOR'S THUNDER — the strike (user 2026-08-21)
// ---------------------------------------------------------------------------
// A fusion of two proven recipes:
//   * ZoekMeMaar's Thunderstorm powerup: a bolt mover that drops from +500z
//     onto the victim playing thunderstorm_effect, plus the thundergun smoke
//     cloud on the head.
//   * Map 1's Cyberjack micro-storm (server-side half only): tesla shock +
//     shock-eyes bursts on every victim in radius, the cj_thunder clap and
//     per-victim cj_zap. (Its DE funnel/orb/bolt visuals ride the hb21 bow's
//     scriptmover clientfields, which this map does not load — NOT portable.)
// SCALING per level: radius, damage fraction, and LOUDNESS (Lv1-2 one storm
// roll; Lv3+ the big clap stacks on top; Lv5 both storm rolls + clap).
// Bosses are EXEMPT, per the map's boss-damage doctrine (their damage is
// fixed/round-independent by design).
// Per-player gate between strikes — shrinks as thunder levels up.
// DARK UPGRADE (v17.10): the +50% rate step needs its own FLOOR or it buys
// nothing. Lv5 already lands exactly on TOD_THOR_CD_MIN_MS (4500 - 4*750 =
// 1500), so dividing the cooldown by 1.5 and re-clamping against the same
// floor would return 1500 again -- the buff would be eaten silently by a clamp
// that looks correct. TOD_DARK_THOR_CD_MIN_MS is the dark floor.
function thor_cooldown_ms( lvl, attacker )
{
	cd = TOD_THOR_CD_MAX_MS - ( lvl - 1 ) * TOD_THOR_CD_STEP_MS;
	floor_ms = TOD_THOR_CD_MIN_MS;
	if ( isdefined( attacker ) && has_dark( attacker, "thunder" ) )
	{
		cd = int( cd / TOD_DARK_THOR_MULT );
		floor_ms = TOD_DARK_THOR_CD_MIN_MS;
	}
	if ( cd < floor_ms )
		cd = floor_ms;
	return cd;
}

function thor_strike( v_org, attacker, weapon, lvl )
{
	level endon( "end_game" );

	if ( !isdefined( level.tod_thor_live ) )
		level.tod_thor_live = 0;
	if ( level.tod_thor_live >= TOD_THOR_MAX_LIVE )
		return;
	level.tod_thor_live++;

	// --- the bolt from the sky + impact flash: Lv2+ ONLY -------------------
	// Lv1 is a small localized zap (just the per-victim shock below), so the
	// dramatic descending sky bolt reads as an upgrade, not the baseline.
	bolt = undefined;
	if ( lvl >= 2 )
	{
		bolt = Spawn( "script_model", v_org + ( 0, 0, 500 ) );
		if ( isdefined( bolt ) )
		{
			bolt SetModel( "tag_origin" );
			PlayFxOnTag( level._effect[ "tod_thor_bolt" ], bolt, "tag_origin" );
			bolt MoveTo( v_org, 0.25 );
		}
		PlayFX( level._effect[ "tod_thor_strike" ], v_org );
	}

	// --- the sound: Lv1 a small crackle; the storm boom is Lv2+ ------------
	if ( lvl >= 2 )
	{
		roll = ( ( RandomInt( 2 ) == 0 ) ? "tod_thor_storm1" : "tod_thor_storm2" );
		PlaySoundAtPosition( roll, v_org );
		if ( lvl >= 3 )
			PlaySoundAtPosition( "tod_thor_clap", v_org );
		if ( lvl >= 5 )
			PlaySoundAtPosition( ( ( roll == "tod_thor_storm1" ) ? "tod_thor_storm2" : "tod_thor_storm1" ), v_org );
	}
	else
	{
		PlaySoundAtPosition( "tod_thor_zap", v_org );   // Lv1: quiet localized zap
	}

	// --- the splash: the NEAREST victims only, capped per level ----------------
	// (user 2026-08-22: "it just kills everything in that radius which is too
	// strong — a limited amount, increasing with level"). Gather every live
	// non-boss in radius, then shock the closest `cap` of them (Lv1 2 .. Lv5 6).
	// A `used` mask instead of array removal — no reliance on GSC array
	// shrink semantics.
	radius = TOD_THOR_RADIUS_BASE + TOD_THOR_RADIUS_PER_LV * lvl;
	frac   = TOD_THOR_DMG_BASE + TOD_THOR_DMG_PER_LV * lvl;
	cap    = TOD_THOR_MAX_HIT_BASE + ( lvl - 1 ) * TOD_THOR_MAX_HIT_PER_LV;
	// DARK UPGRADE (v17.10): "+50% all around" — radius, damage fraction and
	// victim cap together, with the COOLDOWN handled at its own site because its
	// floor has to move as well (see thor_cooldown_ms).
	//
	// The cap is the term that actually pays here. At Lv5 the fraction is already
	// 0.64 of a victim's MAX HEALTH and this lane re-enters upgrade_damage_cb
	// with no pass-through mark, so with DAMAGE stacked it is a guaranteed kill
	// on trash long before the multiplier applies — bosses are excluded outright
	// a few lines down, so nothing here can one-shot one. Raising frac is
	// therefore mostly headroom against a future nerf; cap 6 -> 9 and the wider
	// radius are what the player feels.
	if ( has_dark( attacker, "thunder" ) )
	{
		radius = radius * TOD_DARK_THOR_MULT;
		frac   = frac   * TOD_DARK_THOR_MULT;
		cap    = int( cap * TOD_DARK_THOR_MULT );
	}
	r2     = radius * radius;   // AFTER the dark scale — computing it earlier would silently keep the base radius
	team   = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
	zs     = GetAITeamArray( team );
	cands  = [];
	cd2    = [];
	for ( i = 0; i < zs.size; i++ )
	{
		z = zs[ i ];
		if ( !isdefined( z ) || !isalive( z ) )
			continue;
		if ( IS_TRUE( z.is_boss ) || IS_TRUE( z.acc_is_boss ) || IS_TRUE( z.acc_is_mini_boss ) )
			continue;
		d2 = DistanceSquared( v_org, z.origin + ( 0, 0, 32 ) );
		if ( d2 > r2 )
			continue;
		cands[ cands.size ] = z;
		cd2[ cd2.size ] = d2;
	}
	used = [];
	hit  = 0;
	while ( hit < cap )
	{
		best = -1;
		for ( i = 0; i < cands.size; i++ )
		{
			if ( IS_TRUE( used[ i ] ) )
				continue;
			if ( best < 0 || cd2[ i ] < cd2[ best ] )
				best = i;
		}
		if ( best < 0 )
			break;   // fewer in range than the cap
		used[ best ] = true;
		if ( isdefined( cands[ best ] ) && isalive( cands[ best ] ) )
			cands[ best ] thread thor_shock( attacker, weapon, frac, lvl );
		hit++;
	}

	// Bolt lifetime + lingering storm cloud — only when a bolt exists (Lv2+);
	// the cloud itself is a Lv3+ flourish so Lv2 and Lv3 stay distinct.
	if ( isdefined( bolt ) )
	{
		wait 0.5;
		if ( lvl >= 3 && isdefined( bolt ) )
			PlayFxOnTag( level._effect[ "tod_thor_cloud" ], bolt, "tag_origin" );
		wait 0.6;
		if ( isdefined( bolt ) )
			bolt Delete();
	}
	level.tod_thor_live--;
}

// self = a zombie in the splash. Isolated per victim (a pack damage handler
// throwing mid-chain must never kill the whole strike — the Fire Bow DoT
// hardening from map 1).
function thor_shock( attacker, weapon, frac, lvl )
{
	self endon( "death" );
	level endon( "end_game" );

	PlayFxOnTag( level._effect[ "tod_thor_shock" ], self, "j_spinelower" );
	PlayFxOnTag( level._effect[ "tod_thor_eyes" ], self, "J_Eyeball_LE" );
	if ( lvl >= 3 )
		PlaySoundAtPosition( "tod_thor_zap", self.origin );

	dmg = int( self.maxhealth * frac );
	if ( dmg < 1 )
		dmg = 1;
	if ( !isdefined( attacker ) || !isplayer( attacker ) )
		return;
	// Stock/map-1 proven DoDamage arity: (amount, origin, attacker[, inflictor]).
	// The prior 8-arg form (with a STRING where boneIndex is an int, plus two
	// trailing args DoDamage does not take) was a wrong-arity builtin call —
	// the exact "Unresolved external" class that hangs the load behind a modal.
	// LEECH DOES NOT STACK (user 2026-09-05): a kill the lightning finishes is
	// not a blade kill for healing purposes -- same mark as a cleave-splash victim.
	self.tod_no_leech = true;
	self DoDamage( dmg, self.origin, attacker );
}

// self = the zombie that took the primary melee hit.
function cleave_splash( attacker, dmg, count, weapon )
{
	team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
	zombies = GetAITeamArray( team );
	hit = 0;
	foreach ( z in zombies )
	{
		if ( hit >= count )
			break;
		if ( !isdefined( z ) || z == self || !isalive( z ) )
			continue;
		if ( Distance( z.origin, self.origin ) > TOD_UPG_CLEAVE_RADIUS )
			continue;
		z.tod_cleave_hit = true;   // consumed by the damage callback (no recursion)
		z.tod_no_leech = true;   // PERSISTENT: LEECH reads it at death (one heal per swing; thor_shock stamps it too)
		// MELEE vs BOSSES (user 2026-08-24). The tod_cleave_hit mark makes
		// upgrade_damage_cb pass this hit through UNTOUCHED, so the splash is
		// the only place that can scale it — without this a slasher could swing
		// at a normal zombie and cleave a Panzer standing next to it for the
		// full undivided swing. Per-victim, because one splash can land on a
		// boss and a normal zombie in the same swing.
		// CLEAVE KILL MONEY (2026-10-04): claim this kill's payout BEFORE the hit
		// lands (the kill popup and stock's death award both run inside the
		// DoDamage), settle it after: paid if the hit killed, handed back to
		// stock if the zombie lived.
		pts = cleave_kill_claim( z, attacker );
		z DoDamage( int( dmg * melee_boss_mult( attacker, z, true ) ), z.origin, attacker );
		if ( pts > 0 )
			cleave_kill_settle( z, attacker, pts, weapon );
		hit++;
	}

	// The tell fires on a LANDED cleave only, never on the roll. `extra > 0`
	// upstream means the chance ladder paid out, but with nothing inside
	// TOD_UPG_CLEAVE_RADIUS the swing hit exactly one zombie and sounded like
	// one — an echo there would be a lie about what the upgrade just did.
	// Once per swing, not once per victim: at the current cap (CLEAVE max 3)
	// `count` is 1, but the loop can take 2 if the cap ever goes back up, and
	// two echoes 0.2 s apart would read as a stutter rather than a double hit.
	if ( hit > 0 && isdefined( attacker ) && isplayer( attacker ) )
		attacker thread cleave_echo( weapon );
}

// ---------------------------------------------------------------------------
// CLEAVE KILL MONEY (2026-10-04, TOD_CLEAVE_KILL_FRAC). A cleave kill pays 75% of
// the slasher's base kill (the stock melee kill, 120 -> 90), x Double Points.
//
// THE TRAILBLAZER LANE (v16.94/v19.58, trail_burn_tick): stock's
// zombie_death_points rolls the powerup drop, THEN returns if the zombie carries
// `deathpoints_already_given` - so claiming that latch before the lethal hit keeps
// the drop and skips stock's award, and `tod_popup_points` makes the Aetherium kill
// popup (fired on the same killing blow) show what this pays. Kill counts are
// stock's own (zombie_death_event) and do not ride the latch.
//
// THE DIFFERENCE FROM TRAILBLAZER: nothing predicts lethality. Sprinter armor and
// the boss/pause damage rules run inside the callback chain, so a health test
// before the hit can be wrong. The claim is made on EVERY cleave hit and SETTLED
// after the synchronous DoDamage: if the zombie is still alive the latch, the
// popup stamp and the BOUNTY nominal are cleared again and its real kill pays as
// stock always did.
//
// ORDINARY ZOMBIES ONLY (archetype "zombie" on the horde team) - the same test as
// the kill popup's normal-kill arm, which is the arm that reads tod_popup_points.
// Elites keep their own rewards (the killer-only ELITE KILL lump is unaffected).
//
// Returns the claimed nominal points (before Double Points), 0 = not claimed.
function cleave_kill_claim( z, attacker )
{
	if ( !isdefined( z ) || !isdefined( attacker ) || !IsPlayer( attacker ) )
		return 0;
	if ( !IS_EQUAL( z.team, level.zombie_team ) || !IS_EQUAL( z.archetype, "zombie" ) )
		return 0;
	// Someone else already owns this kill's money (TRAILBLAZER, a nuke, an earlier claim).
	if ( IS_TRUE( z.deathpoints_already_given ) || isdefined( z.tod_popup_points ) )
		return 0;
	// Stock pays nothing to a downed killer or a player barred from scoring; neither does this.
	if ( !zm_utility::is_player_valid( attacker ) || !( attacker zm_spawner::player_can_score_from_zombies() ) )
		return 0;
	pts = cleave_kill_points();
	if ( pts <= 0 )
		return 0;
	z.deathpoints_already_given = true;
	z.tod_popup_points = pts * zm_score::get_points_multiplier( attacker );   // what player_add_points will pay
	z.tod_cleave_kill_pts = pts;   // BOUNTY's nominal for this kill (bounty_kill_value)
	return pts;
}

function cleave_kill_settle( z, attacker, pts, weapon )
{
	// "Did the hit kill?" is stock's own test: _zm_weap_thundergun claims the same
	// latch, DoDamages, then reads `self.health <= 0` to pay its fling kill. A
	// survivor needs BOTH health left and IsAlive; anything else counts as the kill.
	if ( isdefined( z ) && z.health > 0 && IsAlive( z ) )
	{
		// The hit did not kill: give the kill back to stock untouched.
		z.deathpoints_already_given = undefined;
		z.tod_popup_points = undefined;
		z.tod_cleave_kill_pts = undefined;
		return;
	}
	if ( !isdefined( attacker ) || !IsPlayer( attacker ) )
		return;
	before = attacker.score;
	attacker zm_score::player_add_points( TOD_CLEAVE_SCORE_EVENT, pts, undefined, undefined, level.zombie_team, weapon );
	if ( IS_TRUE( level.tod_dev ) )
	{
		mod = "none";
		if ( isdefined( z ) && isdefined( z.damagemod ) )
			mod = z.damagemod;
		line = "[TOD_CLEAVE] ms=" + GetTime() + " KILL_PAY ent=" + attacker GetEntityNumber() + " nominal=" + pts + " mult=" + zm_score::get_points_multiplier( attacker ) + " score " + before + " -> " + attacker.score + " mod=" + mod;
		/# PrintLn( line ); #/
	}
}

// The nominal cleave kill: TOD_CLEAVE_KILL_FRAC of stock's melee kill, in stock's 10s.
function cleave_kill_points()
{
	base = zm_score::get_zombie_death_player_points() + level.zombie_vars[ "zombie_score_bonus_melee" ];
	return zm_utility::round_up_score( base * TOD_CLEAVE_KILL_FRAC, 10 );
}

// self = scorer. Stock player_add_points' registered-event lane: the amount rides
// the `mod` argument (stock's own death_mechz / bonus_points_powerup idiom); stock
// applies Double Points, the 10s rounding and the award after this returns.
function cleave_death_score( event, mod, hit_location, zombie_team, damage_weapon )
{
	if ( !isdefined( mod ) )
		return 0;
	return int( mod );
}

// self = the CLEAVING PLAYER, and deliberately not the victim: the primary
// zombie usually dies on the very frame that spawned the splash, and a thread
// on a deleted entity takes the cue with it.
//
// PlayLocalSound is the same per-client lane every luck cue uses — full
// volume, no world falloff, and no other player's mix is touched by a hit
// they did not land. (The alias is a 2D/quad 1p alias, which is what this
// call wants; the 3D `fly_melee_swipe_t9_knife_h` sibling is the world copy
// the engine is already playing for everyone else.)
function cleave_echo( weapon )
{
	self endon( "disconnect" );
	level endon( "end_game" );
	// Latch the actual strike weapon before the delay; switching weapons must
	// not change a hit that already happened. Other blades retain their sound.
	sfx = TOD_UPG_CLEAVE_ECHO_SFX;
	if ( isdefined( weapon ) && isdefined( weapon.name ) && IsSubStr( weapon.name, "t9_me_baseballbat_" ) )
		sfx = "fly_melee_swipe_player_t9_bat";
	wait TOD_UPG_CLEAVE_ECHO_SECS;
	self PlayLocalSound( sfx );
}

// ---------------------------------------------------------------------------
// BOUNTY — +5%/Lv money per kill with the class gun (TOD_UPG_BOUNTY_PER_LVL;
// this comment said 3% until 2026-08-26 — stale since the 2026-08-20 buff).
// self = the dead zombie,
// attacker = the killer. Stock kill money varies by hit type, so the bonus is
// computed off the matching nominal value (melee 120 / headshot 100 / bullet
// 60) and BANKED: zm_score::add_to_player_score rounds UP to multiples of 10
// (KB trap), so fractional bonuses accumulate on the player and pay out in
// exact 10s — over time the payout is exactly 3%/Lv, never inflated.
// ---------------------------------------------------------------------------

// The kill's NOMINAL money, shared by the payout above and the score-popup
// preview below so they can never drift apart.
function mage_kill_points( player )
{
	if ( isdefined( player ) && isdefined( player.tod_class ) && player.tod_class == "mage" )
		return 80;   // 70 -> 80 on 2026-09-09 (user: "Mage needs to get 80 per kill")
	return 0;
}

// self = scorer, via stock player_add_points' registered-event invocation.
// Mirror its death branch's stats/bonus work; stock still owns point scaling,
// rounding, score splitting and the actual award after this returns.
// Stock team points are always zero. Dogs omit zombie_team at their call site;
// ordinary zombie_death_points supplies it, allowing dogs to retain stock pay.
function zombie_death_score( event, mod, hit_location, zombie_team, damage_weapon )
{
	player_points = zm_score::get_zombie_death_player_points();
	points = self zm_score::player_add_points_kill_bonus( mod, hit_location, damage_weapon, player_points );
	if ( level.zombie_vars[self.team]["zombie_powerup_insta_kill_on"] == 1 && mod == "MOD_UNKNOWN" )
		points *= 2;
	player_points += points;
	if ( mod == "MOD_GRENADE" || mod == "MOD_GRENADE_SPLASH" )
	{
		self zm_stats::increment_client_stat( "grenade_kills" );
		self zm_stats::increment_player_stat( "grenade_kills" );
	}
	// v19.58 (display-vs-reality audit): stock's zombie_death_points passes
	// self._race_team as the team, which is UNDEFINED outside race mode - so the
	// old "isdefined( zombie_team ) &&" gate failed on EVERY ordinary kill and a
	// Mage was paid stock 50/60/100 while the kill popup said +80. Undefined now
	// counts as the horde. KNOWN SIDE EFFECT, accepted: stock's hound death
	// (_zm_ai_dogs dog_death) also pays "death" with no team, so a Mage's stock
	// hound kill money is 80 now too. That money has no popup of its own (the
	// hound's row is the +500 ELITE KILL), so nothing shown disagrees with it;
	// the callback cannot tell a dog apart (player_add_points does not forward
	// its is_dog argument to score events).
	if ( ( !isdefined( zombie_team ) || zombie_team == level.zombie_team ) && mage_kill_points( self ) > 0 )
		return mage_kill_points( self );
	return player_points;
}

function bounty_kill_value( mod, hitloc, attacker = undefined, zombie = undefined )
{
	if ( mage_kill_points( attacker ) > 0 )
		return mage_kill_points( attacker );
	// A CLEAVE kill's nominal is what it paid (cleave_kill_claim stamps it on the
	// victim before the hit) - 90, not the 60 its hit-type-less damage reads as.
	if ( isdefined( zombie ) && isdefined( zombie.tod_cleave_kill_pts ) )
		return zombie.tod_cleave_kill_pts;
	// 130 -> 120 (user 2026-08-26: "knife kills go down from 130 to 120"). This
	// number is NOT the source of truth — the engine pays
	// get_zombie_death_player_points() 50 + zombie_vars["zombie_score_bonus_melee"],
	// and that bonus is set to 70 in zm_tower_of_doom.gsc::main(). This mirror
	// exists so BOUNTY's percentage and the HUD's popup preview are computed off
	// the same number the player is actually paid. THE TWO MOVE TOGETHER OR THE
	// HUD LIES: 50 + the zombie_var must always equal what is returned here.
	if ( isdefined( mod ) && IsSubStr( mod, "MELEE" ) )
		return 120;
	if ( isdefined( hitloc ) && ( hitloc == "head" || hitloc == "helmet" ) )
		return 100;
	return 60;
}

// PUBLIC, via the level.tod_bounty_preview_fn pointer — what BOUNTY is about to
// pay for THIS kill. READ-ONLY: it does not bank, does not award, and changes
// no state, so calling it can never affect the economy.
//
// WHY A PREVIEW AND NOT THE REAL PAYOUT (user 2026-08-23: "the points display
// in center of screen should take into account if you have a money upgrade. So
// im getting 110 on headshot but it shows +100. It should show +110"):
// the Aetherium kit draws that popup from a zm::register_zombie_damage_override
// callback, which fires on the KILLING BLOW — while BOUNTY pays from a
// zm_spawner::register_zombie_death_event callback, which fires AFTER. So at
// popup time the bonus does not exist yet and no same-frame stash can reach
// backwards for it. Rather than move the payout across callbacks (which would
// migrate live economy state to a different event and risk double-paying), the
// popup asks what is coming. The prediction is exact: the bank is deterministic
// given its current value plus this kill, and on_class_gun_kill runs the
// identical arithmetic off the same helper milliseconds later.
//
// Returns 0 for anything that will not pay — wrong weapon, no levels, or a
// bank that has not yet reached the 10-point granularity that
// add_to_player_score rounds to.
function bounty_preview( attacker, weapon, mod, hitloc, zombie = undefined )
{
	if ( !isdefined( attacker ) || !IsPlayer( attacker ) )
		return 0;
	// ANY weapon, matching on_class_gun_kill since BOUNTY was widened — these
	// two run the same arithmetic and the header above says outright that the
	// HUD lies if they ever disagree. A CLEAVE kill needs no weapon at all
	// (on_class_gun_kill banks it ahead of its weapon gate, 2026-10-04).
	if ( !isdefined( weapon ) && !( isdefined( zombie ) && isdefined( zombie.tod_cleave_kill_pts ) ) )
		return 0;

	lvl = get_level( attacker, "bounty" );
	if ( lvl <= 0 )
		return 0;

	bank = ( ( isdefined( attacker.tod_bounty_bank ) ) ? attacker.tod_bounty_bank : 0 );
	rate = TOD_UPG_BOUNTY_PER_LVL * lvl;
	if ( has_dark( attacker, "bounty" ) )
		rate += TOD_DARK_BOUNTY_ADD;   // DARK -- LOCKSTEP with the real bank below; a preview on a different rate is a visible lie
	bank += bounty_kill_value( mod, hitloc, attacker, zombie ) * rate;
	if ( bank < 10 )
		return 0;
	return int( bank / 10 ) * 10;
}

// PUBLIC via level.tod_bounty_mult_fn (the tod_bounty_preview_fn pattern —
// consumers must not import this module). BOUNTY as a FLAT MULTIPLIER for a
// lump-sum payout: 1.0 + 5%/Lv, the same TOD_UPG_BOUNTY_PER_LVL rate the
// per-kill bank pays — so the card's "+5% money per kill / Lv" promise holds
// for lump rewards too. First consumer: the killer-only elite 500
// (_tod_bosses::grant_elite_reward, v14.5). Weapon-agnostic on purpose,
// matching the widened domain (see bounty_preview above).
function bounty_mult( player )
{
	if ( !isdefined( player ) || !IsPlayer( player ) )
		return 1;
	b = get_level( player, "bounty" ) * TOD_UPG_BOUNTY_PER_LVL;
	if ( has_dark( player, "bounty" ) )
		b += TOD_DARK_BOUNTY_ADD;   // DARK: +50% -> +100% money
	return 1.0 + b;
}

// SCAVENGER's ladder (v16.42): kills per refunded round at `lvl`, in TENTHS.
// A pure function of the level so the GSC payout and the LUI's DETAIL readout
// can never disagree about what a level is worth — keep tod_upgrade.lua's [8]
// SCAV_KPR table in step (it holds the same six numbers as kills, not tenths).
//   Lv1 28   Lv2 23   Lv3 20   Lv4 18   Lv5 16   Lv6 14 (assault only)
//   = a round every 2.8 / 2.3 / 2.0 / 1.8 / 1.6 / 1.4 kills.
function scav_kills10( lvl )
{
	if ( !isdefined( lvl ) || lvl <= 0 ) return 0;
	if ( lvl == 1 ) return TOD_SCAV_KILLS10_L1;
	if ( lvl == 2 ) return TOD_SCAV_KILLS10_L2;
	if ( lvl == 3 ) return TOD_SCAV_KILLS10_L3;
	if ( lvl == 4 ) return TOD_SCAV_KILLS10_L4;
	if ( lvl == 5 ) return TOD_SCAV_KILLS10_L5;
	return TOD_SCAV_KILLS10_L6;
}

// Every class-gun kill funnels through here: BOUNTY (shared), SCAVENGER
// (assault), LEECH (slasher). self = the dead zombie, attacker = the killer.
// NUKE-CAUGHT KILLS PAY (2026-09-27, user: "getting kills during a nuke says you
// get money on the display but doesnt actually give you money ... Just so they
// can be aligned"). Stock's nuke stamps every zombie `.nuked` the moment it goes
// off and then kills them one at a time over ~0.1-0.7 s each; a zombie a PLAYER
// finishes inside that window hits stock's "nuked zombies don't give points"
// branch (_zm_spawner zombie_death_animscript) and pays nothing, while the kill
// popup (_zm_aetherium_hud) has already shown the full kill value. This pays
// exactly what stock's zombie_death_points would have: the same player_add_points
// call (so the Mage rate, double points and the point scalar all apply, as in
// the popup), guarded by stock's own deathpoints_already_given latch. It skips
// zombie_death_points itself on purpose - that also rolls a powerup drop, and
// the nuked branch has already rolled one. Kills made BY the nuke carry no
// attacker and still pay nothing (stock's flat 400 per player covers them).
// BOUNTY already pays on these kills (it rides this same death hook).
// Dev log `[TOD_NUKE_PAY]` (tod_dev).
function nuke_kill_pay( attacker )   // self = the dead zombie
{
	if ( !isdefined( self.nuked ) )
		return;
	if ( IS_TRUE( self.deathpoints_already_given ) )
		return;
	if ( !IS_EQUAL( self.team, level.zombie_team ) )
		return;
	if ( !( attacker zm_spawner::player_can_score_from_zombies() ) )
		return;
	self.deathpoints_already_given = true;
	weapon = attacker.currentweapon;
	if ( isdefined( self.damageweapon ) )
		weapon = self.damageweapon;
	before = attacker.score;
	attacker zm_score::player_add_points( "death", self.damagemod, self.damagelocation, undefined, self._race_team, weapon );
	if ( IS_TRUE( level.tod_dev ) )
	{
		mod = "none";
		if ( isdefined( self.damagemod ) )
			mod = self.damagemod;
		loc = "none";
		if ( isdefined( self.damagelocation ) )
			loc = self.damagelocation;
		line = "[TOD_NUKE_PAY] ms=" + GetTime() + " ent=" + attacker GetEntityNumber() + " mod=" + mod + " loc=" + loc + " score " + before + " -> " + attacker.score;
		/# PrintLn( line ); #/
	}
}

// RIOT SHIELD KILLS PAY (v19.58, display-vs-reality audit). Both shields
// (zod_riotshield Lv1..4, log_riotshield_zm Lv5) are registered EQUIPMENT, and
// stock's zombie_death_points returns before paying for any equipment kill
// (_zm_spawner: `if ( zm_equipment::is_equipment( zombie.damageweapon ) )
// return;`) - while the kill popup showed the value. This pays exactly what
// stock pays a weapon kill (player_add_points "death": Mage rate, double
// points, scalar), once (tod_equip_paid). A nuked victim is nuke_kill_pay's.
function equipment_kill_pay( attacker )   // self = the dead zombie
{
	if ( IS_TRUE( self.tod_equip_paid ) || isdefined( self.nuked ) || isdefined( self.tod_popup_points ) )
		return;
	if ( !isdefined( self.damageweapon ) || !zm_equipment::is_equipment( self.damageweapon ) )
		return;
	if ( !IS_EQUAL( self.team, level.zombie_team ) )
		return;
	if ( !( attacker zm_spawner::player_can_score_from_zombies() ) )
		return;
	self.tod_equip_paid = true;
	attacker zm_score::player_add_points( "death", self.damagemod, self.damagelocation, undefined, self._race_team, self.damageweapon );
}

// BOUNTY's real bank for one kill. self = the dead zombie. Base value via the
// SHARED helper - the score popup previews the same number (bounty_preview), and
// if these two ever disagreed the HUD would lie.
function bounty_bank_kill( attacker )
{
	lvl = get_level( attacker, "bounty" );
	if ( lvl <= 0 )
		return;
	kill_value = bounty_kill_value( self.damagemod, self.damagelocation, attacker, self );

	if ( !isdefined( attacker.tod_bounty_bank ) )
		attacker.tod_bounty_bank = 0;
	rate = TOD_UPG_BOUNTY_PER_LVL * lvl;
	if ( has_dark( attacker, "bounty" ) )
		rate += TOD_DARK_BOUNTY_ADD;   // DARK: +50% -> +100% money per kill
	attacker.tod_bounty_bank += kill_value * rate;

	if ( attacker.tod_bounty_bank >= 10 )
	{
		pay = int( attacker.tod_bounty_bank / 10 ) * 10;
		attacker.tod_bounty_bank -= pay;
		attacker zm_score::add_to_player_score( pay );
	}
}

function on_class_gun_kill( attacker )
{
	if ( !isdefined( attacker ) || !IsPlayer( attacker ) )
		return;
	self nuke_kill_pay( attacker );
	self equipment_kill_pay( attacker );
	// A CLEAVE kill banks its BOUNTY HERE, ahead of the weapon gate (2026-10-04,
	// user: cleave kills "should also take into account any bounty addition"):
	// the cleave's extra hit is a script DoDamage that names no weapon, so its
	// BOUNTY must not hang on what the engine fills into damageweapon. Every
	// other kill banks it below, unchanged. bounty_preview takes the same
	// exemption, so the kill popup and this payout stay in lockstep.
	if ( isdefined( self.tod_cleave_kill_pts ) )
		self bounty_bank_kill( attacker );
	if ( !isdefined( self.damageweapon ) )
		return;
	// WIDENED TO EVERY WEAPON (user 2026-08-23: "lets widen as much as we can
	// without twins"). This hook used to return early unless the kill came from
	// the class primary, which silently switched OFF four upgrades the moment
	// you drew your sidearm. BOUNTY, SCAVENGER and ADRENALINE (and KILL RELOAD,
	// until its 2026-09-01 retirement) are
	// all weapon-agnostic script — SCAVENGER even refunds onto self.damageweapon,
	// so it was already written to pay whichever gun made the kill.
	// LEECH is the one hold-back and it keeps this flag: "blade kills heal you"
	// is the SLASHER's risk model — healing must cost you the range the blade
	// costs. is_primary rather than a MELEE test on purpose, so the gate cannot
	// regress if the Stormbreaker ever reports a non-MELEE damagemod.
	// (CHAIN LUNGE needs no flag — it already gates on MELEE at the bottom.)
	is_primary = tod_classes::is_class_primary( attacker, self.damageweapon );

	// THE MAGE'S MANA (v18.37): one point per kill, through the guarded pointer
	// _tod_mage_elements sets. Undefined -- and inert -- while the class is off.
	if ( isdefined( level.tod_mage_on_kill ) )
		[[ level.tod_mage_on_kill ]]( attacker );

	// --- BOUNTY: % of the kill's nominal money, banked, paid in exact 10s ---
	// (a CLEAVE kill already banked it above the weapon gate)
	if ( !isdefined( self.tod_cleave_kill_pts ) )
		self bounty_bank_kill( attacker );

	// --- SCAVENGER ("reserve"): kills refund reserve ammo on the killing gun -
	// v16.42: every primary kill deposits TEN (tenths of a kill) and a round pays
	// out once the bank reaches scav_kills10(lvl) — the ladder authored in kills
	// per round, tenths so the bank stays INTEGER and 1-per-3 is exact (no float
	// sum can ever land at 0.99999 and pay a kill late); ONE per shot: a penetrating /
	// echo multi-kill delivers several of these callbacks in the SAME server
	// frame, so a payout latches the frame time and later kills in that frame
	// only bank. Anything banked past a whole round by that multi-kill is
	// forfeit — the bank re-arms one kill short of the next round (the v9.10
	// "held at need-1" rule in fractional form), so a 10-kill penetration shot
	// is one round now and one on the next kill, never a stack of pre-paid
	// rounds. The bank survives level-ups (the per-kill deposit just grows
	// under it) and tier promotions (the domain is scope "class"; see tier_up's
	// reset list).
	// PRIMARIES ONLY (user 2026-08-26: "it will not apply to secondaries. Only
	// primaries guns for each class"). A sidearm kill pays NOTHING — it does
	// not refund the sidearm, and it does not divert a refund to the primary
	// either. Gating here rather than on the weapon the refund lands on is the
	// whole point: `w` below is self.damageweapon, so without this gate a kill
	// made with the pistol topped the PISTOL up. A sidearm kill does not even
	// feed the bank, which is the honest reading of "does not apply to
	// secondaries" — the upgrade is a reward for fighting with your class
	// weapon.
	lvl = get_level( attacker, "reserve" );
	if ( lvl > 0 && is_primary )
	{
		need = scav_kills10( lvl );
		if ( has_dark( attacker, "reserve" ) )
		{
			need = int( need * TOD_DARK_SCAV_MULT );   // DARK: Lv1 2.8 -> 1.6, Lv5 1.6 -> 0.9 kills (assault 1.4 -> 0.8); int() truncates the tenths
			if ( need < 1 )
				need = 1;
		}
		if ( !isdefined( attacker.tod_scav_bank ) )
			attacker.tod_scav_bank = 0;
		attacker.tod_scav_bank += 10;
		if ( attacker.tod_scav_bank >= need )
		{
			now = GetTime();
			if ( !isdefined( attacker.tod_scav_pay_ms ) || attacker.tod_scav_pay_ms != now )
			{
				attacker.tod_scav_pay_ms = now;
				attacker.tod_scav_bank -= need;
				w = self.damageweapon;
				stock = attacker GetWeaponAmmoStock( w );
				if ( stock < w.maxAmmo )
				{
					attacker SetWeaponAmmoStock( w, stock + 1 );
					// the clink only fires when ammo ACTUALLY landed — never on
					// a payout wasted against a full reserve
					attacker scavenger_feedback();
				}
			}
			// NO PRE-PAID STACK (see above): re-arm one kill short.
			if ( attacker.tod_scav_bank >= need )
				attacker.tod_scav_bank = need - 10;
		}
	}

	// --- LEECH (slasher): the blade feeds you ------------------------------
	// LEECH DOES NOT STACK (user 2026-09-05: "Leach goes to 25HP but doesnt
	// stack. This is a change to leech overall." and "it can stack healing if it
	// kills multiple zombies like thors thunder. That cant happen"): ONE heal per
	// swing. Every CLEAVE-splash and THOR-shock victim carries tod_no_leech (set
	// at the splash/strike, never cleared -- tod_cleave_hit is consumed by the
	// damage callback before death, so it cannot serve) and pays no heal.
	lvl = get_level( attacker, "leech" );
	if ( is_primary && lvl > 0 && !IS_TRUE( self.tod_no_leech ) && IsAlive( attacker ) && !( attacker laststand::player_is_in_laststand() ) )
	{
		heal = leech_hp_for_level( lvl );
		if ( has_dark( attacker, "leech" ) )
			heal = TOD_DARK_LEECH_HP;   // DARK: a FLAT 25 HP per blade kill (replaces, never adds)
		attacker trickle_heal( heal );
	}

	// --- ADRENALINE (MP7 unique): a MULTI-KILL fires a 3s speed burst ------
	// v16. Count kills in a rolling window; when the count reaches
	// TOD_ADREN_MK_NEED and the cooldown has expired, fire one fixed burst.
	//
	// ⚠️ NO WEAPON GATE, AND THAT IS INHERITED RATHER THAN CHOSEN. This block
	// has never tested is_primary (the 2026-08-23 widening deliberately made
	// BOUNTY / SCAVENGER / ADRENALINE / KILL RELOAD weapon-agnostic; KILL RELOAD
	// itself retired 2026-09-01), and
	// gun_keys gates what you can ROLL, never what FIRES. So the proc counts
	// sidearm, grenade and even Panzer kills. Left as-is because for a
	// skirmisher those are most of the multi-kill lanes the class has — but it
	// is now load-bearing for the trigger rather than incidental to a per-kill
	// stack, so it is written down instead of being rediscovered.
	lvl = get_level( attacker, "adrenaline" );
	if ( lvl > 0 )
	{
		now = GetTime();
		// Rolling window: a gap longer than the window restarts the count.
		// Same shape as _tod_uniques::fire_streak_watch's gap test.
		if ( !isdefined( attacker.tod_adren_mk_ms ) || ( now - attacker.tod_adren_mk_ms ) > TOD_ADREN_MK_WINDOW_MS )
			attacker.tod_adren_mk_n = 0;
		if ( !isdefined( attacker.tod_adren_mk_n ) )
			attacker.tod_adren_mk_n = 0;
		attacker.tod_adren_mk_n++;
		attacker.tod_adren_mk_ms = now;

		// The !isdefined arm is what removes the need for any spawn-time init —
		// thor_next_ms's trick. Stamp the cooldown BEFORE firing.
		ready = ( !isdefined( attacker.tod_adren_next_ms ) || now >= attacker.tod_adren_next_ms );
		if ( attacker.tod_adren_mk_n >= TOD_ADREN_MK_NEED && ready )
		{
			attacker.tod_adren_next_ms = now + adren_cooldown_ms( lvl );
			attacker.tod_adren_mk_n = 0;               // consume the streak
			attacker.tod_adren_until = now + TOD_ADREN_MS;
			attacker apply_move_speed();               // instant onset

			// THE HEAL (v17.85) — DOUBLE the speed/damage percent, once, now.
			// It reads adren_bonus(), so it MUST come after tod_adren_until is
			// stamped above: outside a live burst that function returns 0 and the
			// heal would be a silent no-op. Percentage OF MAX HEALTH, so it follows
			// Juggernog and VITALITY without naming either.
			//
			// trickle_heal is the map's one heal lane (LEECH uses it too): it clamps
			// to maxhealth, never lowers, and only ever RAISES health -- which is
			// what keeps RECOVERY's health-drop poll from reading a heal as damage.
			//
			// THE LASTSTAND GUARD IS LEECH'S, AND IT IS NOT OPTIONAL. A downed
			// player can still kill with a pistol and so can still fire this proc;
			// self.health in last stand belongs to the down system, and writing it
			// from here would be a partial self-revive nobody designed. The speed and
			// damage halves are left ungated exactly as they have always been -- they
			// write no health.
			if ( IsAlive( attacker ) && !( attacker laststand::player_is_in_laststand() ) )
			{
				heal_pct = attacker adren_bonus();
				if ( heal_pct > 0 && isdefined( attacker.maxhealth ) )
					attacker trickle_heal( attacker.maxhealth * heal_pct * TOD_ADREN_HEAL_MULT );
			}
			// EXACT 3s EXPIRY. Without this the burst ends only when the 1s body
			// tick next runs, so a nominal 3s proc really lasts 3-4s — a 33%
			// overrun, and far more visible against a 6s cooldown than the old
			// 4s window ever was. One-shot thread, self-cancelling if a new proc
			// lands first.
			attacker thread adren_expire();
			// SOUND HOOK — WIRED SINCE v16 (2026-09-01). The pointer is set in
			// register_domains beside level.tod_lmgs_fx_fn; adren_fx() PlayLocalSounds
			// TOD_ADREN_SFX (3 synth heartbeats, 1.42s, 2d/player-only). Called through
			// the pointer so the cue and the speed land on the SAME frame.
			//
			// This comment said "DELIBERATELY UNWIRED TODAY" for a day after the wiring
			// landed, and that cost real debugging time: the user reported the cue
			// inaudible, and a comment at the call site saying the hook does not exist
			// points the next reader at the one part that was fine. The cause was
			// ATTENUATION, not wiring — see the TOD_ADREN_SFX #define.
			if ( isdefined( level.tod_adren_fx_fn ) )
				attacker [[ level.tod_adren_fx_fn ]]();
		}
	}

	// --- KILL RELOAD (assault): REMOVED 2026-09-01 with the domain -----------
	// (user: "Lets remove it. No one likes it"). The proc lived here: every Nth
	// kill (55/40/30 by level) topped the magazine back up FROM RESERVE, never
	// creating ammo. Its two 2026-08-23 reworks (v9.41 reserve-fed, v9.43
	// frequency ladder) and the arithmetic for why 10/7/5 was still broken are
	// in the CHANGELOG under those versions.

	// (The CHAIN LUNGE hook that used to close this function was removed
	// 2026-08-24 with the domain — see the note at its old add_domain.)
}

// ---------------------------------------------------------------------------
// MAG SIZE — REMOVED as a virtual pool 2026-08-20 (user: "I don't want
// bottomless magsize — this should be a twin and directly impact the gun's
// mag size"). It is now REAL twin variants: the krig r{R}m{M} matrix in
// gen_tod_twins.js scales clipSize/startAmmo/maxAmmo (+50/+100/+150%), and
// twin_suffix/reconcile_twin swap the asset in place. The todMagBonus
// clientfield stays registered (budget stability) but is never set — the
// MAG +N HUD chip simply never shows.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// PERSONAL UPGRADE STATION (user 2026-08-20)
// ---------------------------------------------------------------------------
// A buyable terminal at the base (Chaos PaP mesh against the core's south
// face): pay 2000 +250 per PURCHASE — the escalation is PER PLAYER, not
// team — to roll a solo upgrade menu on the spot.
//
// WHETHER THE WORLD FREEZES NOW DEPENDS ON PARTY SIZE (v16.84, 2026-09-03 —
// the full argument is on station_freeze_wanted, below). CO-OP is unchanged
// and is what the rest of this comment describes: the world does NOT pause,
// the buyer is NOT frozen (user 2026-08-20), full movement + weapons while
// the cards are up, the horde keeps coming (that is the risk) and the 15s
// auto-lock timer still runs. SOLO freezes the world and the buyer exactly
// like a round event does — one player has no teammate to absorb that risk —
// with the FINALE as the single carve-out, since the closing song is a clock
// no freeze can stop. If a SCHEDULED
// upgrade round starts mid-pick, the round event OVERRIDES: the takeover
// notify (fired inside run_upgrade_event) kills the solo menu synchronously,
// the round event runs normally (the buyer participates like everyone else),
// then the SAME solo cards re-present with a fresh timer. Cards deferred
// across a round event re-clamp vs CURRENT levels at apply time — the event
// may have advanced the same domain, and a stale cur must never LOWER a
// level; if both cards die maxed, the purchase refunds and the price steps
// back one notch.
//
// PER-STATION USE CAP (user 2026-08-21: "each player can only use a specific
// upgrade station 3 times; after that they need to go up and use the next
// one — to push players up the tower"). Every terminal gets an id at spawn
// (base 0, breathers 1-4, crown 5) and each player carries a per-id use
// count; a depleted terminal refuses that player (hint says so) while
// staying live for everyone else. The PRICE ladder is untouched — it keeps
// counting across stations — so the cap changes WHERE you buy, not what
// you pay. A refunded buy (both cards dead) gives the use back.
// Per-PLAYER, per-STATION buy cap. 5 (user 2026-08-23: "lets make that increase
// by 2"; was 3). Six terminals — base 0, breathers 1-4, crown 5 — so a full
// climb now offers 30 station buys per player instead of 18. Still capped per
// terminal on purpose: the station is a reason to keep climbing, not a farm you
// can park at. NOTE this cap has only actually been enforceable since ship state
// went in (v9.22) — station_depleted() returns false outright while
// level.tod_dev is on, so every dev build had unlimited uses.
#define TOD_STATION_USES_PER  5

// THE CROWN ALTAR IS CAPPED AT 3 (user 2026-09-04: "max alter use on the
// crown room should be 3"). It was UNLIMITED from 2026-08-29 ("The heavenly
// alter in the crown room shouldnt have a limit") — but that call was made
// while the altar still had the price LADDER binding it economically, and the
// ladder went FLAT 3000 with the triggerstring-250 crash fix, leaving the one
// vendor at the top of the map uncapped AND flat-priced. Three, not the
// terminals' five: the crown altar is the LAST vendor of the run and the only
// one nothing further up can push you off, so it buys a finish, not a farm.
#define TOD_STATION_USES_CROWN  3
#define TOD_STATION_CROWN_ID    5

// THE CROWN ALTAR FIX (v16.27, 2026-09-02) — THE TRIGGER ORIGIN FLOATS 32u OFF
// THE FLOOR. The crown altar had never shown a buy prompt in any build (user,
// 2026-08-30: "never had the buy prompt and still doesnt"), through two
// "fixes" that never cleared it (the v14.1 slab cut and the manager
// reordering above). The static audits all read SCRIPT; the answer was in the
// .map: station_trig_org() = (-624, 8308, 19392) lies INSIDE the hall's
// 'crown ring inlay W' brush — x[-632..-584] y[8024..9192] z[19392..19393],
// a 1u glowing floor decal that has ringed the hall since the v9 crown, the
// same release that placed this station. This map has paid for exactly that
// twice before: a solid brush on a trigger_radius_use ORIGIN kills the buy
// (the extraction obelisk and the hall crate's clip column, both recorded in
// _tod_finale::spawn_props). The BASE station's origin sits on the bare
// ground slab's top face with nothing above it, which is why it always
// worked — and the point query that found this (a 60-line node script over
// the .map's axis-aligned brushes) also found that the v16.7 lounge inlay
// SPOKES run under every breather station trigger (spoke s, 40u from the
// machine — the trigger is 56u out) and every breather PaP trigger (spoke
// e), so the four lounge stations were on course to die the same way in the
// first build anyone bought at them after v16.7. Every other script vendor in
// the map already floats its origin (ammo crates +40, doors +40, teleporters
// +32 — "raised 32u so the cursor lands" — uplink/exfil +30, spire buys
// +24/+32); the stations were the last at floor level. 32 is the teleporter's
// proven number. The player's bounding box, not their origin, is what the
// cylinder [z, z+100] tests (the +40 crate is the standing proof), so a
// crouched buyer still reaches it. The Pack-a-Punch stubs lift too
// (zm_cwpap, TOD_PAP_TRIG_LIFT).
// TEST AT SPAWN FIRST: the base station is the live canary for "a lifted
// station trigger still prompts"; the crown is the proof of the diagnosis.
#define TOD_STATION_TRIG_LIFT  32

function station_spawn()
{
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );
	level.tod_station_count = 0;

	// BASE station — backed on the core south face, facing spawn. yaw ~0 =
	// front toward -y is the LIVE-VERIFIED vending convention (same as the
	// perk pads; 270 faced WEST). v19.71: FLUSH against the core and GENERATED
	// (gen_tower_map.js BASE_STATION, which also emits the altar's perch cap) -
	// it stood at a hand-typed (0,-320), 45 units off the face, and players ran
	// behind it (Workshop tester, 2026-10-03).
	station_place( tod_breather_data::base_station_org(), tod_breather_data::base_station_trig(), tod_breather_data::base_station_yaw() );

	// ONE PER BREATHER (user 2026-08-21: "add a card update station on each
	// platform"). v13: the terminal owns the lounge's NORTH wall — the
	// entrance side — facing south into the room, so it is the first fixture
	// an arriving player walks past (the W wall it used to back now belongs
	// to the Pack-a-Punch). Anchors are GENERATED (_tod_breather_data.gsc);
	// the generator asserts every lounge trigger pair clears by both radii
	// + 64. Yaw convention on this map (live-verified): 0/359.999 = front
	// toward -y, 180 = +y, 90 = +x, 270 = -x; the trigger sits 56u in front
	// of the machine face, same as the base station below.
	zs = tod_breather_data::breather_zs();
	foreach ( z in zs )
		station_place( tod_breather_data::station_org( z ), tod_breather_data::station_trig( z ), tod_breather_data::station_yaw() );

	// THE CROWN (v9): one terminal inside the citadel, on the west wall south
	// of the pilaster — the last chance to spend before the uplink. Anchors
	// are GENERATED (parity-mirrored with the rest of the crown).
	station_place( tod_crown_data::station_org(), tod_crown_data::station_trig_org(), tod_crown_data::station_yaw() );
	// (The 2026-08-29 diagnosis instruments — floating anchor marker,
	// "stations placed" bold print, per-second trig-state heartbeat — were
	// REMOVED for the v14.1 publish. If the crown altar needs diagnosing
	// again, the recipe: bold-print level.tod_station_count here; thread a
	// spinning chaos_pack_a_punch mesh 160u above station 5's trig_org; and
	// in station_triggers_manager bold-print "trig=UP/none d=N" once a
	// second for any player above z=19000. Ships-dormant diagnostics that
	// STAY: the manager's spawn-fail retry print, the use-loop press/deny
	// narration, the manager's station-5 trigger-up print.)
}

// One terminal: the model plus its own use trigger. Every station charges the
// same FLAT 3000 (station_cost, 2026-08-30 — the escalating per-player ladder
// is gone), so building more of them never makes upgrades cheaper — only
// closer. The per-station use cap is what still pushes players UP the tower.
function station_place( model_org, trig_org, yaw )
{
	// THE TRIGGER MANAGER LAUNCHES FIRST — BEFORE ANY OTHER SPAWN IN THIS
	// FUNCTION (2026-08-29, the crown altar's second no-trigger report, made
	// AFTER the entity-relief build). The manager is the only thing the
	// altar's USABILITY depends on, yet it used to launch LAST — below one
	// model spawn and three clip spawns, none of them guarded. Any of those
	// four Spawn() calls returning undefined killed this thread on the very
	// next line's method call, and the manager then never started: a station
	// with a VISIBLE MESH and NO TRIGGER, forever, with nothing to self-heal
	// it (the guard added earlier today lives INSIDE the manager and cannot
	// help a manager that never ran). That is the crown altar's exact
	// signature — the last station placed, standing at the entity-pressure
	// peak, model present, untriggerable. Launched first, the trigger's
	// existence now depends on nothing but the manager's own guarded,
	// 1s-retrying spawn loop; the mesh and clips below are cosmetics and
	// collision, and a failure there costs looks, not function.
	level thread station_triggers_manager( trig_org, level.tod_station_count );   // base 0, breathers 1-4, crown 5
	level.tod_station_count++;

	m = Spawn( "script_model", model_org );
	if ( !isdefined( m ) )
	{
		// Pool pressure ate the mesh. The trigger manager above is already
		// running and unaffected — the station works, it just has no prop.
		if ( IS_TRUE( level.tod_dev ) )
			tod_quiet_print( "station " + ( level.tod_station_count - 1 ) + ": MODEL SPAWN FAILED" );
		return;
	}
	m.angles = ( 0, yaw, 0 );
	m SetModel( "tod_heavenly_altar" );

	// THE HEAVENLY AURA (user 2026-08-29: "a awwwwwww heanly aura sounds on loop
	// always so when you get close you hear it ... very subtle but adds
	// atmosphere"). One looping 3D emitter per altar, played ON THE MODEL rather
	// than a spawned script_origin: the model already lives for the whole game at
	// exactly the right spot, and a loop that dies with its machine is the
	// behaviour we want anyway. Placed HERE, in the shared placer, so all six
	// altars — base + four breathers + crown — get it by construction, and any
	// altar added later inherits it without a second edit.
	//
	// THE ALIAS IS WHERE THE TUNING LIVES, not this line: DistMin 64 (the altar's
	// own trigger radius, so full level exactly where the buy prompt appears)
	// falling to nothing by 320, at volume 68. Widening the audible ring or
	// changing the level is a one-row CSV edit and a -GscOnly.
	//
	// LimitCount is set to 8 ON THE ROW, deliberately overriding the UIN_MOD
	// template's default of 2 — six of these loop simultaneously for the whole
	// game, and at the default the emitters would steal each other's voices
	// (LimitType oldest) and some altars would fall silent.
	m PlayLoopSound( "tod_altar_aura" );

	// COLLISION (user 2026-08-23: "the Heavenly Altar doesnt have a clip. In all
	// locations its walk through"). A script_model is a VISUAL ONLY — the xmodel
	// carries no collision the player can stand against, which is why every
	// stock vendor spawns a SECOND entity to be its solid. This is stock’s own
	// recipe, copied field for field from the two places that use it:
	//   _zm_pack_a_punch.gsc:113-118  (the PaP — the same machine shape as ours)
	//   _zm_perks.gsc:1551-1555       (every perk machine)
	// both spawn a script_model at the vendor’s origin+angles, SetModel
	// "zm_collision_perks1", tag it script_noteworthy "clip" and DisconnectPaths.
	// The model needs no #precache here: it is already in the fastfile because
	// stock spawns one of these for each of our eight perk machines (we never set
	// level._no_vending_machine_auto_collision, and _tod_perk_scatter is built
	// around those clips existing).
	// DisconnectPaths is MANDATORY, not decoration — the navmesh ignores entity
	// collision entirely (KB: "Navmesh ignores ALL entity collision"), so without
	// it zombies path INTO the altar footprint and grind on a prop they cannot
	// walk through. Stock disconnects on the same line for the same reason.
	// Safe to solidify at spawn: station_spawn runs at init, long before a player
	// can be standing in the footprint (the crush-safety rule that governs door
	// slabs applies to things that solidify DURING play).
	// THE FLARE (user 2026-08-24: "please double check the clips of the heavenly
	// alter ... The top flares out and I dont think we took that to acconut").
	// MEASURED, not guessed: chaos_pack_a_punch.xmodel_bin is an LZ4-wrapped
	// binary xmodel; decompressed, its 957,902 vertex records binned by height
	// give this profile (scale 1, so model units ARE game units) —
	//     z   0..24   x +-44   the plinth
	//     z  36..84   x +-52   <<< THE FLARE, and it sits at PLAYER CHEST HEIGHT
	//     z  96..120  x +-36   the crown taper
	// i.e. 104 units across at its widest (z=60) against 89 at the base, and
	// 127 tall overall. zm_collision_perks1 is sized for a stock VENDING
	// MACHINE, so the 8-16 units of overhang per side at chest height had NO
	// collision on it at all — which is precisely the "talking through parts of
	// it" that was reported.
	//
	// THREE clips instead of one, spaced along the machine's WIDE axis. The
	// mesh's local +X is its width (extent 104) and local Y its depth (53), and
	// an entity with angles (0,yaw,0) maps local +X onto AnglesToForward — so
	// the row lies ACROSS the machine's face whichever way a station is turned.
	// Do not "simplify" this to world-axis offsets: the six stations do not
	// share a yaw.
	//
	// +-32 IS DELIBERATELY ROBUST RATHER THAN EXACT. zm_collision_perks1 is a
	// packed stock asset with no source in the mod-tools raw tree, so its true
	// width cannot be measured here the way the altar's was; whatever its half
	// width W is, the union spans W+64 and therefore covers the measured 104 for
	// any W >= 20. Over-covering slightly is safe — every station backs a wall,
	// a core face or a terrace edge — while under-covering is the bug being
	// fixed. It also uses ONLY the asset already proven resident (see above), so
	// this needs no new zone line and no precache.
	fwd = AnglesToForward( m.angles );
	clip_offs = array( -32, 0, 32 );
	clips = [];
	for ( ci = 0; ci < clip_offs.size; ci++ )
	{
		c = Spawn( "script_model", model_org + VectorScale( fwd, clip_offs[ ci ] ), 1 );
		if ( !isdefined( c ) )           // pool-guard: a lost clip is a cosmetic
			continue;                    // hole, never a dead thread (see header)
		c.angles = m.angles;             // same yaw as the mesh, so the boxes line up
		c SetModel( "zm_collision_perks1" );
		c.script_noteworthy = "clip";
		c DisconnectPaths();
		clips[ clips.size ] = c;
	}
	if ( clips.size == 0 )
		return;                          // no clips spawned; trigger manager unaffected
	m.tod_clip = clips[ 0 ];             // a surviving clip — handle kept because
	                                     // anything that later hides a station must
	                                     // NotSolid + ConnectPaths it (Hide() !=
	                                     // NotSolid — the QR invisible wall bug,
	                                     // docs/KB and qr_clip_watch)
	m.tod_clips = clips;                 // ...and the full set, which is what such a
	                                     // teardown actually has to walk now

	// PER-PLAYER TRIGGERS (2026-08-27). The altar used to run ONE shared trigger
	// whose hint showed the NEAREST player's price — and when two players in
	// range owed different amounts it fell back to a priceless generic
	// ("HEAVENLY GIFT ALTAR - per player"), because a single global hint showing
	// one player's number would lie to the other. The user read that generic as
	// a bug ("It just says something like heavenly alter. No price or anything"),
	// and they were right that it is a worse experience, honest or not.
	//
	// THE FIX IS MAP 1'S MEGA-BOTTLES PATTERN (_acc_mega_bottles.gsc:687 /
	// _acc_perk_scatter.gsc:651): N overlapping triggers at the same origin,
	// each SetInvisibleToPlayer-hidden from everyone except its OWNER. An
	// invisible trigger shows no hint and takes no use from the hidden player,
	// so every player sees exactly one prompt — theirs — carrying THEIR price,
	// THEIR spent state, THEIR maxed state. The mixed-party generic is dead
	// because the situation it papered over no longer exists.
	//
	// The altar is the only per-player-priced buyable in the map (doors and
	// extraction are party-wide prices), which is why only this vendor needs it.
	// (The trigger manager itself launches at the TOP of this function — see
	// the header comment: its start must not sit downstream of any Spawn.)
}

// One manager per station: keeps one live trigger per connected player, spawns
// for late joiners, prunes when an owner disconnects. 6 stations x 4 players =
// 24 triggers at most — nothing by entity-count standards.
function station_triggers_manager( trig_org, station_id )
{
	level endon( "end_game" );

	trigs = [];
	for ( ;; )
	{
		// prune triggers whose owner left (entity refs go undefined on disconnect)
		alive = [];
		for ( i = 0; i < trigs.size; i++ )
		{
			t = trigs[ i ];
			if ( !isdefined( t ) )
				continue;
			if ( !isdefined( t.tod_owner ) )
			{
				t Delete();
				continue;
			}
			alive[ alive.size ] = t;
		}
		trigs = alive;

		players = GetPlayers();
		foreach ( p in players )
		{
			if ( !isdefined( p ) )
				continue;
			have = false;
			for ( i = 0; i < trigs.size; i++ )
			{
				if ( isdefined( trigs[ i ].tod_owner ) && trigs[ i ].tod_owner == p )
					have = true;
			}
			if ( have )
				continue;
			t = spawn( "trigger_radius_use", trig_org + ( 0, 0, TOD_STATION_TRIG_LIFT ), 0, 64, 100 );   // lifted: see the define (the crown altar fix)
			// ENTITY POOL GUARD (the 2026-08-29 crown-altar failure: G_Spawn
			// returned undefined at init pressure and the unguarded method call
			// below KILLED this manager thread — that altar then never got a
			// trigger for the whole game). Skip and retry on the next 1s pass:
			// the pool frees as temp ents die, and the manager self-heals.
			if ( !isdefined( t ) )
			{
				// LOUD in dev (2026-08-29 second report): a silent skip here
				// is indistinguishable from a healthy station to the tester.
				if ( IS_TRUE( level.tod_dev ) )
					tod_quiet_print( "altar " + station_id + ": TRIG SPAWN FAILED (pool) - retrying" );
				continue;
			}
			t TriggerIgnoreTeam();      // REQUIRED for a script-spawned use-trigger
			t SetCursorHint( "HINT_NOICON" );
			t.tod_station_id = station_id;
			t.tod_owner = p;
			// DEV: prove the crown altar's trigger EXISTS and where (the
			// 2026-08-29 "cant trigger it" diagnosis lane — no spawn print +
			// no press print = station_place never ran; spawn print but no
			// press = the trigger is not receiving).
			if ( IS_TRUE( level.tod_dev ) && station_id == 5 )
				tod_quiet_print( "altar 5: trigger up at " + trig_org[ 0 ] + " " + trig_org[ 1 ] + " " + trig_org[ 2 ] );
			t thread station_visibility_loop();
			t thread station_hint_loop();
			t thread station_use_loop();
			trigs[ trigs.size ] = t;
		}
		wait 1;
	}
}

// self = trigger. RE-ASSERTED on a cadence rather than set once, exactly as map
// 1 does — visibility is per-(trigger,player) state the engine can lose on a
// roster change, and a new joiner must be hidden from every trigger that is not
// theirs before they can wander into range of six stations' worth of them.
function station_visibility_loop()
{
	level endon( "end_game" );

	for ( ;; )
	{
		if ( !isdefined( self.tod_owner ) )
			return;   // manager will Delete() us on its next pass
		players = GetPlayers();
		foreach ( p in players )
		{
			if ( !isdefined( p ) )
				continue;
			self SetInvisibleToPlayer( p, p != self.tod_owner );
		}
		wait 0.25;
	}
}

// FLAT 3000, ALWAYS (user 2026-08-30: "Make the alter 3000 then all the time").
//
// THE ESCALATING LADDER IS GONE, AND IT WAS THE LAST UNBOUNDED TRIGGERSTRING
// ACCUMULATOR IN THE MAP. History: +1000/buy -> +500 -> +250 (2026-08-23), as
// `2000 + 250 * n` with n a GLOBAL per-player lifetime buy count and no clamp.
// station_hint_loop:4050 interpolates this straight into the prompt, so EVERY
// purchase minted a hint string no previous purchase had produced — one
// permanent BG-cache 'triggerstring' slot each, cap 250 match-wide, never freed
// (see the shipped crash two players reported 2026-08-29/30). It was
// structurally identical to map 1's 2026-06-25 soul-box crash: a live counter
// baked into a hint and re-set per event. The crown altar's 5-use cap coming
// off on 2026-08-29 removed the last thing bounding it.
//
// A flat price makes the prompt ONE string for the whole match, so the map's
// entire hint budget is now STATIC — run length no longer moves it at all,
// which is what actually fixes the crash rather than deferring it. Unlimited
// buys are UNTOUCHED (station_depleted exempted the crown altar at the time —
// v17.37 caps it at 3, which is a use cap and still touches no hint string);
// only the escalation is gone. Economically this is a straight buff — buy #10 was 4,250
// and every buy past #5 now costs less than it did.
//
// player.tod_station_buys is still counted (and still decremented on a refunded
// buy at :4415); it simply no longer prices anything. Left in place rather than
// ripped out — it is harmless and something may want the tally later.
//
// IF THIS EVER GOES BACK TO A LADDER: the price must NOT go back into the hint
// literal. Bound it, bucket what is DISPLAYED, or move the number to
// IPrintLnBold / a clientfield. Memory: triggerstring-250-cap.
function station_cost( player )
{
	return 3000;
}

// How many times this player has bought at terminal `id` (per-player, per-station).
function station_uses( player, id )
{
	if ( !isdefined( player ) || !isdefined( player.tod_station_uses ) || !isdefined( player.tod_station_uses[ id ] ) )
		return 0;
	return player.tod_station_uses[ id ];
}

function station_depleted( player, id )
{
	// DEV: no per-station cap (user 2026-08-21) — test any terminal endlessly.
	// tod_dev_altar (2026-09-07) is the same lane on its own flag, because
	// tod_dev is a BUNDLE nobody wants armed just to buy a second upgrade —
	// same split, and same publish gate, as tod_dev_money and tod_dev_doors.
	// [tod v19.9] tod_dev_altar ONLY — the bundle half is gone, same reason as
	// the maxed loadout and the upgrade cadence. Arm tod_dev_altar for it.
	if ( IS_TRUE( level.tod_dev_altar ) )
		return false;
	// Station ids: base 0, breathers 1-4, crown 5 (station_place call order).
	// v17.37: the crown altar is CAPPED AT 3 — it ran unlimited from
	// 2026-08-29 to today. See TOD_STATION_USES_CROWN for why that reverted.
	return ( station_uses( player, id ) >= station_use_cap( id ) );
}

// -> true while the finale is waiting on EXTRACT / ASCEND: the one world pause
// that is not a card deal and under which the crown altar stays open.
function finale_choice_open()
{
	return ( isdefined( level.tod_finale_state ) && level.tod_finale_state == "choice" );
}

// -> how many buys THIS terminal allows one player. The crown altar's own
// number is the only exception, and it lives here so nothing has to test the
// id twice (the hint loop reads depletion through station_depleted).
function station_use_cap( id )
{
	if ( id == TOD_STATION_CROWN_ID )
		return TOD_STATION_USES_CROWN;
	return TOD_STATION_USES_PER;
}

// self = trigger. One shared trigger, PER-PLAYER price -> show the NEAREST
// player's cost (map 1's shared-trigger hint rule). Only re-set the hint
// when the shown cost actually changes — every distinct hint string costs a
// config string (bounded here: one per price tier ever displayed).
function station_hint_loop()
{
	level endon( "end_game" );

	// -999, NOT -1 (audit 2026-08-25). The state codes are >=0 price, -1 mixed
	// party, -2 spent, -3 all maxed — so a sentinel of -1 is a VALUE THE LOOP CAN
	// LEGITIMATELY COMPUTE. If the first evaluation of a given altar landed on
	// the mixed-party case, "cost == shown" was already true and the loop
	// skipped before ever calling SetHintString: that altar then had NO hint
	// at all, permanently, because shown never changes again either. Every other
	// sentinel-guarded loop in this map (uplink_hint_loop, teleport refresh —
	// and _tod_doors::door_price_watch, until it was deleted 2026-08-30 for the
	// 250-triggerstring cap) seeds outside its own domain; this one did not.
	// PER-PLAYER SINCE 2026-08-27: self.tod_owner is the ONE player who can see
	// this trigger (station_visibility_loop hides it from everyone else), so
	// the hint answers one question for one person — no nearest-player search,
	// and the mixed-party -1 state is GONE because two players can no longer be
	// reading the same hint. STATE CODES now: >=0 a live price, -2 this station
	// is spent for them, -3 they have nothing left to buy anywhere.
	//
	// -3 IS CHECKED AFTER -2 AND WINS (live report 2026-08-25: "When you hit
	// max it should tell you"): "nothing left to buy anywhere" outranks "you
	// have spent this particular one".
	shown = -999;
	for ( ;; )
	{
		wait 0.3;

		if ( !isdefined( self.tod_owner ) )
			return;   // owner disconnected; the manager will Delete() us

		cost = station_cost( self.tod_owner );
		if ( station_depleted( self.tod_owner, self.tod_station_id ) )
			cost = -2;
		if ( !player_has_upgrades_left( self.tod_owner ) )
			cost = -3;
		if ( cost == shown )
			continue;
		// Wording is deliberate (2026-08-21). It must NOT collide with the
		// Aetherium hint dispatcher's keyword routing (ZMCursorHintNew.lua):
		// "door"/"open" -> the door card, "pack"+"punch" or "upgrade"+"weapon"
		// -> the PaP card, "[cost:" WITH an icon -> the wall-buy card. We use
		// HINT_NOICON and never say "weapon", so this lands on the default
		// prompt — which now renders the live text (it used to show the
		// hardcoded placeholder "Hint text here").
		shown = cost;
		// THE HEAVENLY GIFT ALTAR (user 2026-08-23: "We can call it the heavnly
		// gift alter"), and a COPY BUG fixed with it.
		//
		// THE BUG: PromptDefault.lua strips the leading "Hold [{+activate}]"
		// before drawing, because it renders its own button glyph. The old line
		// "Hold [{+activate}] for an Upgrade Card [Cost: N]" therefore reached the
		// screen as the fragment **"for an Upgrade Card [Cost: 2000]"** — a
		// dangling preposition, which is the "copy bugs" the user reported.
		// So the visible text has to READ CORRECTLY WITH "Hold [btn]" REMOVED:
		// lead with the noun, never with "for"/"to"/"at".
		//
		// Two routing constraints this wording also has to satisfy
		// (ZMCursorHintNew.lua): isWallBuyHint needs BOTH "[cost:" AND an icon,
		// and the trigger is HINT_NOICON, so the price bracket is safe to keep.
		// isPerkHint needs "hold" AND "for" AND a perk-name word — dropping "for"
		// takes us further from that collision than the old wording was.
		if ( cost == -3 )
			self SetHintString( "^1ALL UPGRADES MAXED^7" );
		else if ( cost == -2 )
			self SetHintString( "^1ALTAR SPENT^7 - try another" );
		else
			// (The mixed-party "- per player" generic died with the shared
			// trigger, 2026-08-27 — this hint is visible to exactly one player,
			// so the price is always THEIRS.)
			// v14.58 — the shared prompt grammar, "Hold [btn] <TITLE> - <detail>
			// [Cost: N]" (PromptDefault.lua). The card splits on the FIRST
			// " - ", so the title band reads HEAVENLY GIFT ALTAR and the line
			// under it finally says what the 3000 points buy. Note the
			// paragraph above is now WRONG about one thing and kept only as
			// history: the claim that "[cost:" is safe because the wallbuy
			// router "needs [cost:] AND an icon" was FALSE — the icon guard
			// never fired and this altar drew the "Wall Weapon" card in game
			// (user 2026-08-31). The router no longer has a wallbuy route at
			// all, and "heavenly gift altar" is in its TOD_NOUNS list, so this
			// prompt is claimed by name before any keyword test runs. Keep the
			// noun if you reword this.
			self SetHintString( "Hold ^3[{+activate}]^7 ^5HEAVENLY GIFT ALTAR^7 - take an upgrade card ^2[Cost: " + cost + "]" );
	}
}

// self = trigger
function station_use_loop()
{
	level endon( "end_game" );

	for ( ;; )
	{
		self waittill( "trigger", player );

		// DEV DIAGNOSIS LANE (live report 2026-08-29: the crown altar "doesnt
		// even work. I cant trigger it" — none of the six guards below says
		// which one ate the press, so an armed run now narrates. Behind
		// tod_dev like every debug print on this map; ships silent.)
		if ( IS_TRUE( level.tod_dev ) )
			tod_quiet_print( "altar " + self.tod_station_id + ": press" );

		if ( !isdefined( player ) || !isplayer( player ) )
			continue;
		// PER-PLAYER TRIGGER (2026-08-27): only the owner may buy through this
		// one. SetInvisibleToPlayer should already stop anyone else using it,
		// but that is an engine behaviour this loop does not get to assume —
		// a charge landing on the wrong player's ladder would be a real bug.
		if ( !isdefined( self.tod_owner ) )
			return;   // owner disconnected; manager will Delete() us
		if ( player != self.tod_owner )
		{
			if ( IS_TRUE( level.tod_dev ) )
				tod_quiet_print( "altar " + self.tod_station_id + ": deny NOT-OWNER" );
			continue;
		}
		if ( !IS_TRUE( level.tod_class_select_done ) )    // never during the draft
			continue;
		// MID-PICK NOW OUTRANKS THE PAUSE DENY (v16.84). A SOLO pick freezes the
		// world, so this player's own two cards make level.tod_upgrade_pause
		// true — and in the old order the branch below would answer a second
		// press with the round-event deny sound: the wrong reason, and a noise
		// in the ear of someone who is only holding a key while they read. The
		// more specific state wins, and it stays SILENT for the same reason the
		// laststand branch is.
		if ( IS_TRUE( player.tod_solo_upg_active ) )      // already mid-pick
		{
			if ( IS_TRUE( level.tod_dev ) )
				tod_quiet_print( "altar " + self.tod_station_id + ": deny MID-PICK" );
			continue;
		}
		// A round event is live — refuse, but SAY SO. Mute refusals read as dead
		// triggers (the 2026-08-26 "teleporter wasn't activated" report; the full
		// note lives on _tod_teleport.gsc's copy of this branch). Note the
		// laststand branch below stays SILENT on purpose: a downed player is
		// holding the use key trying to get revived, and a deny sound there would
		// machine-gun in their ear for the whole crawl.
		//
		// EXCEPT THE FINALE'S CHOICE PHASE (user 2026-09-22: "Crown altar should
		// also be buyable even after the fight is over ... but it should still
		// have a max limit"). _tod_finale::choice_phase sets the raw pause flag
		// itself (the board is wiped and frozen while the party decides between
		// EXTRACT and ASCEND) - no deal is live, so the crown altar refused
		// every press with the round-event deny sound from the last chord on.
		// The pick runs on the live-world lane it always used up here
		// (station_freeze_wanted is false under tod_upgrades_suppressed) and
		// solo_present_interruptible only yields to a REAL deal. The per-player
		// cap (TOD_STATION_USES_CROWN, 3) is untouched and counts road,
		// hold-out and choice buys together.
		if ( IS_TRUE( level.tod_upgrade_pause ) && !finale_choice_open() )
		{
			if ( IS_TRUE( level.tod_dev ) )
				tod_quiet_print( "altar " + self.tod_station_id + ": deny PAUSE" );
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
		if ( player laststand::player_is_in_laststand() )
			continue;
		// A revive press is not a purchase (_zm_blockers.gsc:307). Reviving polls
		// the raw USE button (_zm_laststand.gsc:1129), so without this the press
		// that revives a teammate at a terminal also spends 2000+ points AND
		// burns one of this station's limited uses. Silent, like the branch
		// above: the player is holding use.
		if ( player zm_utility::in_revive_trigger() )
		{
			if ( IS_TRUE( level.tod_dev ) )
				tod_quiet_print( "altar " + self.tod_station_id + ": deny REVIVE-TRIG" );
			continue;
		}
		if ( !player_has_upgrades_left( player ) )        // everything maxed
		{
			if ( IS_TRUE( level.tod_dev ) )
				tod_quiet_print( "altar " + self.tod_station_id + ": deny ALL-MAXED" );
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
		if ( station_depleted( player, self.tod_station_id ) )   // per-station cap (5, crown altar 3)
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}

		cost = station_cost( player );
		if ( !( player zm_score::can_player_purchase( cost ) ) )
		{
			if ( IS_TRUE( level.tod_dev ) )
				tod_quiet_print( "altar " + self.tod_station_id + ": deny POOR (" + cost + ")" );
			player PlaySound( "zmb_no_purchase" );
			continue;
		}

		player PlaySound( "zmb_cha_ching" );
		player zm_score::minus_to_player_score( cost );
		if ( !isdefined( player.tod_station_buys ) )
			player.tod_station_buys = 0;
		player.tod_station_buys++;
		player.tod_station_paid = cost;   // held for the both-cards-dead refund
		// per-station use count (the cap); remember WHICH terminal so a refund
		// can hand the use back to the right one
		if ( !isdefined( player.tod_station_uses ) )
			player.tod_station_uses = [];
		player.tod_station_uses[ self.tod_station_id ] = station_uses( player, self.tod_station_id ) + 1;
		player.tod_station_last_id = self.tod_station_id;

		player thread solo_upgrade_flow();
		wait 0.5;
	}
}

// ---------------------------------------------------------------------------
// THE SOLO STATION FREEZE (v16.84, user 2026-09-03: "on solo when you use the
// alter can we freeze the game like on the round based upgrades. I only want
// this applied on solo")
// ---------------------------------------------------------------------------
// The station shipped deliberately UNFROZEN from 2026-08-20 — "the world does
// NOT pause; that is the risk" is written into this file's header, into init(),
// into CLAUDE.md and into two release notes. That risk was always a CO-OP
// argument: with a teammate up, fifteen seconds of standing still is a cost
// somebody else absorbs. Alone it is nobody's, so the solo buyer paid 3000
// points for a choice they could not afford to read — and the map's own
// concession to that (the reveal runs at half speed while the world is live,
// TOD_REVEAL_LIVE_SCALE) only ever shortened the exposure instead of removing
// it.
//
// SOLO NOW GETS THE ROUND-EVENT TREATMENT, both lanes, through the SAME two
// functions the round event uses — no second implementation of a freeze:
//   set_world_pause( true )  — stock's world_is_paused (round_spawning waits on
//                              it, _zm.gsc:3747) plus every tod boss director
//                              and spawner that reads level.tod_upgrade_pause,
//                              plus ignoreall + a 0.05 anim rate on live AI.
//   menu_freeze( true )      — weapons off, jump off, movement pinned.
// THREE THINGS FOLLOW FOR FREE, all already keyed on level.tod_upgrade_pause
// and all of them wanted here:
//   * the reveal plays at FULL speed (_tod_upgrade_ui::reveal_deal stops
//     applying TOD_REVEAL_LIVE_SCALE) — the show was only rushed because the
//     world was live;
//   * upgrade_damage_cb returns 0, so nobody farms a frozen horde through the
//     card panel;
//   * EVERY input lane opens on the panel (_tod_upgrade_ui, v16.81) — the
//     d-pad-only station rule was earned by the player being mid-fight, and
//     they are not mid-fight any more.
// CO-OP IS BYTE-FOR-BYTE UNCHANGED: station_freeze_wanted() is the only gate,
// and with two or more players connected it answers false before anything in
// this block runs.
//
// NO self: the three questions this asks are all LEVEL state (party size, the
// finale flag, who owns the pause), and a "self = the buying player" line on a
// function that never reads self is a comment that will be believed and is
// false. Every other function in this block does take a player.
function station_freeze_wanted()
{
	// SOLO = ONE CONNECTED PLAYER. Deliberately not "one player ALIVE": a
	// partner who bled out is still in the match, still watching this screen and
	// still waiting on the round-change respawn, and freezing the world under
	// them is a behaviour change they never asked for and cannot see the cause
	// of. Read at present time, so a late joiner mid-pick cannot flip it —
	// station_pause_end releases whatever was actually claimed either way.
	if ( GetPlayers().size != 1 )
		return false;

	// THE FINALE IS THE ONE SOLO CARVE-OUT, for exactly the reason
	// event_scheduler skips its own events there: the closing song IS the run's
	// clock, a freeze stops the world but NOT a music stream, and every frozen
	// second of card-reading slides the ending further out of sync with the
	// track. _tod_finale sets this flag at the top of the run. So the CROWN
	// altar stays live-world once extraction is called — the old risk model, in
	// the one place it is still the right one. (_tod_spire sets the same flag
	// and has no stations at all: station_spawn places base 0, breathers 1-4
	// and crown 5, nothing on the spire.)
	// v17.10: TWO flags, because the two suppressions are no longer the same
	// question. tod_upgrades_suppressed is the FINALE's (its song is the run's
	// clock, so nothing may freeze the world); tod_stations_suppressed is the
	// SPIRE's, which stops station buys while leaving the round clock dealing.
	if ( IS_TRUE( level.tod_upgrades_suppressed ) || IS_TRUE( level.tod_stations_suppressed ) )
		return false;

	// Somebody else already owns a pause — a round event, or the finale's
	// ascend/extract choice phase. Unreachable today (station_use_loop refuses
	// a buy outright in that state), and kept so set_world_pause can never get
	// a second owner if a future path ever arrives here.
	if ( IS_TRUE( level.tod_upgrade_pause ) )
		return false;

	return true;
}

// self = player. TRUE while THIS player's own station pick is the thing holding
// the world pause open. It is the one question that separates "a round event
// took the UI over" from "I froze the world myself" — before v16.84 a raw
// level.tod_upgrade_pause read answered both, because only one of them existed.
function station_owns_pause()
{
	return ( isdefined( level.tod_station_pause_owner ) && level.tod_station_pause_owner == self );
}

// self = player
function station_pause_begin()
{
	level.tod_station_pause_owner = self;
	if ( !isdefined( level.tod_station_pause_seq ) )
		level.tod_station_pause_seq = 0;
	level.tod_station_pause_seq++;

	set_world_pause( true );
	self menu_freeze( true );   // refuses on a laststand player, by its own rule

	level thread station_pause_watchdog( self, level.tod_station_pause_seq );
}

// self = player. Releases ONLY what we still own. A round event that took over
// cleared the owner at its takeover notify and now owns BOTH lanes, and calling
// set_world_pause( false ) here would unfreeze the world in the middle of its
// deal — which is the same rule the "never call menu_freeze(false) on the
// takeover path" corollary in solo_upgrade_flow has always stated, now enforced
// in one place instead of asserted in a comment.
function station_pause_end()
{
	if ( !( self station_owns_pause() ) )
		return;

	level.tod_station_pause_owner = undefined;
	self menu_freeze( false );
	set_world_pause( false );
}

// A PERMANENTLY FROZEN WORLD IS THE WORST THING THIS FILE CAN LEAVE BEHIND —
// run_upgrade_event's wait loop carries the same warning in capitals. Its own
// caller, solo_upgrade_flow, carries self endon( "disconnect" ), so a
// disconnect between begin and end kills the only thread that would ever have
// released the pause. In SOLO that disconnect is the match ending anyway, which
// is precisely the kind of reasoning that stops being true the day somebody
// adds a path — so this is the belt to that argument's braces.
//
// KEYED ON A SEQUENCE, NOT ON THE PLAYER: buy, release, buy again inside the
// ceiling and a player-keyed watchdog would tear down the SECOND pick's pause.
// Every begin mints a new seq and only that seq may release.
function station_pause_watchdog( player, seq )
{
	level endon( "end_game" );

	// The 15s pick window, the reveal and the confirm flash, with room to spare.
	wait( TOD_UPG_CHOICE_TIMEOUT + 12 );

	if ( !isdefined( level.tod_station_pause_seq ) || level.tod_station_pause_seq != seq )
		return;                                   // a later pick owns the pause now
	if ( !isdefined( level.tod_station_pause_owner ) )
		return;                                   // released normally, or a round event claimed it

	level.tod_station_pause_owner = undefined;
	if ( isdefined( player ) && isplayer( player ) )
		player menu_freeze( false );
	set_world_pause( false );
}

// self = player
function solo_upgrade_flow()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	self.tod_solo_upg_active = true;

	opts = roll_options( self );
	if ( !isdefined( opts ) )
	{
		// NOT belt+braces (repo review 2026-09-01): this is the NORMAL exit for a
		// player whose every domain is maxed but who is still tier-eligible —
		// player_has_upgrades_left() admits them for the promotion chance, and
		// roll_options deals nothing on the (100 - TOD_TIER_CARD_PCT)% of buys
		// where the tier card is not drawn (v16.56: a FULL luck bar makes that
		// 0% — tier_card_guaranteed — so a maxed, eligible player who banks the
		// bar never buys silence here). It used to be cha-ching, -3000,
		// +3000, silence: the Workshop report "hold F to buy, I do and nothing
		// happens" (2026-08-30). The refund stands; the refusal is now AUDIBLE
		// (map doctrine: a deny is the sound, no floaty captions).
		self solo_refund();
		self PlaySound( "zmb_no_purchase" );
		if ( IS_TRUE( level.tod_dev ) )
			tod_quiet_print( "altar: no card drawn (domains maxed, promotion not rolled) - refunded" );
		self.tod_solo_upg_active = false;
		return;
	}

	for ( ;; )
	{
		// A scheduled round event owns the shared card UI — hold until it is
		// fully over, then re-present the SAME cards with a fresh timer.
		//
		// THE RAW FLAG IS THE RIGHT READ *HERE*, unlike the poll inside
		// solo_present_interruptible (v16.84): we can never own the pause at
		// the top of this loop. First pass, nothing has begun; and both
		// `continue` paths that come back here have already relinquished — the
		// takeover branch below is entered only when the pause is somebody
		// else's, and the choice == -1 path runs station_pause_end first. No
		// station_owns_pause() guard is added for that reason: a guard nobody
		// can watch fire is not a guard.
		if ( IS_TRUE( level.tod_upg_event_takeover ) )   // 2026-09-22 (F09): a real deal, not the finale's raw pause
		{
			level waittill( "tod_upg_event_over" );
			wait 0.5;   // let the event's unfreeze/unpause settle

			// The event may have advanced/maxed the SAME domains these cards
			// hold — refresh both NOW and drop any dead card (verify
			// 2026-08-20: never present a card that can no longer pay out).
			// Both dead -> refund without presenting anything.
			alive = [];
			if ( self solo_refresh_option( opts[ 0 ] ) )
				alive[ alive.size ] = opts[ 0 ];
			if ( isdefined( opts[ 1 ] ) && ( self solo_refresh_option( opts[ 1 ] ) ) )
				alive[ alive.size ] = opts[ 1 ];
			if ( alive.size == 0 )
			{
				// TAKE THE PANEL DOWN — this is the ONE exit that can leave it lit
				// (audit 2026-08-26). The round event's takeover killed the
				// in-flight present_choice with todUpgShow still 1, and normally
				// the event's OWN present_choice repaints/clears the fields for
				// this player a moment later. But a player who was DOWN when the
				// event fired is excluded from it entirely, so no repaint ever
				// comes, and this branch refunds and breaks without clearing —
				// leaving a lit card panel until their next deal.
				//
				// SAFE HERE AND NOWHERE ELSE: this runs AFTER the
				// waittill( "tod_upg_event_over" ) + wait 0.5 above, so the
				// event's own field writes are finished. Do NOT "fix" this
				// instead by clearing on the pause check's early return, or by
				// reordering the pause and laststand checks — that fires while
				// run_upgrade_event has only just threaded its choice flows and
				// would blank the event's freshly painted cards, which is exactly
				// what the takeover comment above warns about.
				self tod_upgrade_ui::set_field( "todUpgShow", 0 );
				self solo_refund();
				break;
			}
			opts = alive;
			continue;
		}

		// CO-OP: NO FREEZE (user 2026-08-20: "it pauses you but doesn't pause
		// zombies so you are helpless") — but JUMP IS LOCKED (user 2026-08-21:
		// "when using the manual card upgrade you should not be able to jump"),
		// since jump is the hold-to-lock button and hopping while choosing both
		// fires the lock and launches you off a balcony. Movement and weapons
		// stay fully live; only the jump input is taken, and it is restored on
		// every exit path below including the takeover.
		// That is the whole risk model: you fight WHILE you choose, or you let
		// the 15s timer auto-lock the focused card. The lock button is HOLD
		// jump, so an ordinary hop never locks a card by accident.
		//
		// SOLO: THE WORLD FREEZES, EXACTLY LIKE A ROUND EVENT (v16.84, user
		// 2026-09-03: "on solo when you use the alter can we freeze the game
		// like on the round based upgrades. I only want this applied on solo").
		// The risk model above is a CO-OP argument that never applied to one
		// player: with a teammate up, fifteen seconds of standing still is a
		// cost somebody else absorbs; alone it is nobody's, so the solo buyer
		// either read their cards or survived, never both. station_freeze_wanted
		// owns the "is this solo" question and the finale carve-out; the
		// station_pause_begin/end pair owns the two lanes.
		//
		// Corollary that SURVIVES the freeze: we must never call
		// menu_freeze(false) on the takeover path — on a round-event takeover
		// the EVENT's own flow owns the freeze flag (it is flat, not nested)
		// and unfreezes at its end. station_pause_end() is a NO-OP once the
		// event has claimed the pause, which is exactly what keeps that true.
		// Jump is taken for exactly the duration of the card prompt and given
		// back the instant it returns — a tight window on EVERY path (normal
		// lock, timeout, down, takeover), so a thread that dies mid-present
		// can never strand the player unable to jump. In the frozen lane
		// menu_freeze owns jump instead, and it deliberately does NOT hand it
		// back to a player who went down mid-pick (stock's revive restores it).
		froze = station_freeze_wanted();
		if ( froze )
			self station_pause_begin();
		else
		{
			self AllowJump( false );
			// v18.9 — AND THE OFFHANDS, which this lane never took. The card panel
			// advertises the offhand PAIR as its switch control (tod_upgrade.lua
			// draws "[{+smoke}] < SWITCH > [{+frag}]" unconditionally), and the
			// comment in _tod_upgrade_ui.gsc's focus lane asserted that menu_freeze
			// held DisableOffhandWeapons() so a press could never throw one — true
			// in the FROZEN lane and false here, because the co-op arm was
			// AllowJump( false ) and nothing else. Switching cards in co-op threw a
			// lethal and a tactical. Live from any Max Ammo onward, and immediately
			// with Widow's Wine or DISTRACTION's monkey.
			//
			// This is a small, deliberate softening of the co-op risk model — you
			// still fight while you choose, you just keep your grenades.
			self DisableOffhandWeapons();
		}
		choice = self solo_present_interruptible( opts );
		if ( froze )
			self station_pause_end();   // no-op if a round event claimed the pause
		else
		{
			// GUARDED, both of them (v18.9). A scheduled round event can take the
			// UI over and thread menu_freeze( true ) synchronously before this
			// lane's 0.05 s poll wakes — handing jump and offhands back here would
			// undo the freeze that is now holding the player. menu_freeze's own
			// exit guards the identical call for the identical reason.
			//
			// AND NOT TO A DOWNED PLAYER: solo_present_interruptible returns from
			// inside last stand, and the 2026-08-26 audit already fixed this exact
			// shape in menu_freeze ("left them hopping around while crawling").
			// Stock's revive restores both. The altars sit on open balconies and
			// the crown terrace, so a crawler with jump back is a fall, not a joke.
			if ( !IS_TRUE( self.tod_menu_frozen ) && !( self laststand::player_is_in_laststand() ) )
			{
				self AllowJump( true );
				self EnableOffhandWeapons();
			}
		}

		if ( choice == -1 )
			continue;   // takeover — the event owns the UI; re-present after

		picked = opts[ 0 ];
		other = opts[ 1 ];   // may be undefined (only one domain was left)
		if ( choice == 2 && isdefined( opts[ 1 ] ) )
		{
			picked = opts[ 1 ];
			other = opts[ 0 ];
		}

		// Deferred cards re-clamp vs current levels (see header comment).
		if ( !( self solo_refresh_option( picked ) ) )
		{
			picked = undefined;
			if ( isdefined( other ) && ( self solo_refresh_option( other ) ) )
				picked = other;
		}

		ok = false;
		if ( isdefined( picked ) )
		{
			ok = apply_upgrade( self, picked );
			// a refused TIER pick (timed out / could not land) falls back to the
			// other card — the buy must pay out or be refunded, never vanish
			if ( !ok && picked.domain == "tier" && isdefined( other ) && other.domain != "tier"
			  && ( self solo_refresh_option( other ) ) )
				ok = apply_upgrade( self, other );
		}
		if ( ok )
		{
			self.tod_luck_bar = 0;   // solo rolls spend the luck bar too (the odds rode it)
			self.tod_station_paid = 0;
		}
		else
			self solo_refund();

		break;
	}

	self.tod_solo_upg_active = false;
}

// self = player -> 1|2, or -1 = a round event took the UI over. The takeover
// notify fires synchronously inside run_upgrade_event BEFORE it threads its
// per-player flows, so the solo present thread is already dead when the
// event's present_choice first touches the shared fields — never two writers.
function solo_present_interruptible( opts )
{
	self.tod_solo_result = undefined;
	self thread solo_present_run( opts );

	for ( ;; )
	{
		if ( isdefined( self.tod_solo_result ) )
			break;
		// A ROUND EVENT TOOK THE UI OVER — unless the pause is OUR OWN. v16.84
		// gave the solo station a world freeze, so the raw flag stopped being a
		// takeover test the moment it became self-inflicted: read like that, a
		// solo pick would hand back -1 on its very first poll and re-present
		// itself forever. station_owns_pause() is the whole difference.
		//
		// AND ONLY A REAL EVENT COUNTS (bug review 2026-09-22, F09): the
		// finale's choice phase sets level.tod_upgrade_pause directly, with no
		// takeover notify and no tod_upg_event_over to follow, so a crown-altar
		// pick open when the song ended returned -1 here and then slept in
		// solo_upgrade_flow for a notify only run_upgrade_event sends — the
		// purchase was lost on EXTRACT and re-presented mid-fight after ASCEND.
		// tod_upg_event_takeover is set by run_upgrade_event and nobody else.
		if ( IS_TRUE( level.tod_upg_event_takeover ) && !( self station_owns_pause() ) )
			return -1;
		if ( self laststand::player_is_in_laststand() )
		{
			// Downed mid-pick. GRACE FIRST (verify 2026-08-20): if the down
			// landed during present_choice's 0.7s confirm flash the pick is
			// already DECIDED — wait out the flash and take the real result
			// instead of stomping a locked card 2 with the default.
			for ( g = 0; g < 16; g++ )
			{
				if ( isdefined( self.tod_solo_result ) )
					break;
				wait 0.05;
			}
			if ( isdefined( self.tod_solo_result ) )
				break;
			// Truly mid-browse: kill the menu, clear the stranded card UI,
			// lock the DEFAULT card — they paid, they keep the upgrade.
			self notify( "tod_solo_down_abort" );
			self tod_upgrade_ui::set_field( "todUpgShow", 0 );
			return 1;
		}
		wait 0.05;
	}

	r = self.tod_solo_result;
	self.tod_solo_result = undefined;
	return r;
}

// self = player
function solo_present_run( opts )
{
	self endon( "disconnect" );
	level endon( "end_game" );
	level endon( "tod_global_upg_takeover" );
	self endon( "tod_solo_down_abort" );

	self push_panel_hints();   // v14.35 — the station deals the same cards, so it owes the same line
	r = self tod_upgrade_ui::present_choice( opts, TOD_UPG_CHOICE_TIMEOUT );
	self.tod_solo_result = r;
}

// self = player. Refresh a rolled option vs the CURRENT level and re-clamp;
// false = the domain maxed while we were deferred (the card is dead).
function solo_refresh_option( o )
{
	// A deferred TIER card is alive only while the promotion is still possible
	// — and never for a downed player (the solo down-abort locks the default
	// card; a swap must not ride that path). Re-encode the class/tier code.
	if ( o.domain == "tier" )
	{
		if ( self laststand::player_is_in_laststand() )
			return false;
		// v14.39 — asks the floor-blind question, then RE-STAMPS the lock. A
		// card that was dealt locked must come back locked, not vanish: the
		// deferred path re-presents the same deal after a round event takes
		// over, and a card disappearing between the two showings would read as
		// the takeover having stolen it. Re-stamped rather than carried so a
		// player who CLIMBED during the takeover gets it back unlocked, which
		// is the one direction this can legitimately change.
		if ( !tier_card_ready_but_for_floor( self ) )
			return false;
		o.locked = ( tier_floor_pending( self ) > 0 );
		o.cur = tier_card_code( self );
		return true;
	}
	// A deferred card is dead if its domain is no longer ROLLABLE — a tier-up
	// during the takeover changes the gun, and gun-bound domains (the twin
	// ladders, Thor's Thunder) may have gone dark with it.
	d = find_domain( o.domain );
	if ( !isdefined( d ) || !domain_available( self, d ) )
		return false;
	o.max = domain_max( self, d );
	o.cur = get_level( self, o.domain );
	if ( o.cur + o.levels > o.max )
		o.levels = o.max - o.cur;

	// BAND HONESTY on the deferred path too — the third and last place `levels`
	// can shrink out from under `rarity`. This card was rolled BEFORE a scheduled
	// round event took over, and the player may have levelled this very domain in
	// that event; re-presenting it still wearing its original band would show
	// "ULTIMATE +3" over a payout the takeover just cut to +1. Same clamp-down
	// rule as make_option, and the TIER card never reaches here (it returns
	// above).
	if ( o.levels >= 1 && o.levels < o.rarity )
	{
		o.rarity = o.levels;
		if ( o.rarity == 3 )      o.rarity_name = "ULTIMATE";
		else if ( o.rarity == 2 ) o.rarity_name = "SUPER";
		else                      o.rarity_name = "";
	}
	return ( o.levels > 0 );
}

// self = player
function solo_refund()
{
	if ( !isdefined( self.tod_station_paid ) || self.tod_station_paid <= 0 )
		return;
	self zm_score::add_to_player_score( self.tod_station_paid );
	self.tod_station_paid = 0;
	if ( isdefined( self.tod_station_buys ) && self.tod_station_buys > 0 )
		self.tod_station_buys--;   // that buy never happened — the price steps back
	// ...and the per-station use comes back too (the cap counts real buys only)
	if ( isdefined( self.tod_station_last_id ) && station_uses( self, self.tod_station_last_id ) > 0 )
		self.tod_station_uses[ self.tod_station_last_id ]--;
}

// ---------------------------------------------------------------------------
// TRAILBLAZER (v16.62, id 46 — skirmisher; docs/80). SPRINTING LEAVES BURNING
// GROUND; zombies that run through it burn.
//
// TWO HALVES, DELIBERATELY SEPARATE. The DAMAGE is a list of NODES on the
// player (structs: origin, expiry, radius, burn) — a node every
// one PATCH WIDTH of travel (trail_spacing, v16.92 -- it was a 350 ms timer),
// so spinning in place makes no trail. Every TOD_TRAIL_TICK_MS each live node
// burns every non-boss zombie inside its radius for half its per-second figure,
// credited to the runner (DoDamage -> kills pay points, BOUNTY, luck, the elite
// reward), and a zombie is burned by AT MOST ONE node per tick, so an
// overlapping trail is a line, not a pile. The VISUAL is one tag_origin
// script_model per fire patch with a stock looping GROUND FIRE on it
// (level._effect["tod_trail_fire"] = fire/fx_fire_ground_rubble_50x50 since
// v16.79 — v16.62 named the hellhound's trail fire, which turned out to be one
// of the 298 five-kilobyte STUB .efx files in the mod tools: one default
// element, no material, links clean, draws nothing; memory
// stub-efx-in-mod-tools), 1/2/3 patches across the trail by level,
// reaped by ONE level-wide reaper on their own expiry — so a disconnect, a
// death or a node dropped early can never strand a burning entity. Hosts are
// capped MAP-WIDE (TOD_TRAIL_MAX_HOSTS) because they are gentities; nodes are
// free.
//
// THE SOUND (v16.79, user: "We need some sfx for this too") rides the node's
// FIRST patch, so it is 3D at the fire and dies with the entity when the
// reaper deletes it (an entity takes its voices with it — memory
// loop-sound-stop-by-handle): a crackle LOOP on every node (the alias caps the
// voices at 6, oldest stolen first, so the newest fire always has the sound
// and it follows the runner), an IGNITE whoosh only when a node starts a NEW
// segment (>= TOD_TRAIL_SEG_GAP_MS since the last node — a continuous sprint
// ignites once), and a SIZZLE on a zombie the tick burns, rate-limited per
// zombie and per tick. Aliases in sound/aliases/tod_ui.csv, wavs generated
// with ffmpeg (sound_assets/tod/sfx/tod_trail_*.wav).
//
// The burn is a fraction of the ROUND's zombie health (level.zombie_health —
// the PhD-nova rule), so it neither one-shots at round 1 nor fades at round
// 40; elites take the same ABSOLUTE damage as trash and so burn slowly, by
// design; the boss set is thunder's (is_boss / acc_is_boss / acc_is_mini_boss).
// ---------------------------------------------------------------------------
#define TOD_TRAIL_TICK_MS        500   // burn cadence; each tick deals half the per-second figure
// [v16.92] SPACING IS DERIVED FROM THE PATCH WIDTH, NOT FROM A TIMER.
// User 2026-09-03: "the fire trail fx is delayed ... tighten the latency of
// when I run over a spot and it gets burned".
//
// THE OLD DESIGN SET SPACING AND COVERAGE FROM TWO UNRELATED NUMBERS: a node
// every 350 ms of sprint (~105 u) while a patch only covers trail_radius,
// 56 u at Lv1 rising to 88 at Lv5. So at low levels the patches landed FURTHER
// APART THAN THEY WERE WIDE and the trail read as discrete blobs dropping in
// behind the player -- which is what "delayed" was. At Lv5 the 88 radius
// nearly closed the gap, which is why it looked acceptable there and nowhere
// else.
//
// Now the gate is DISTANCE, and the distance IS the patch width
// (trail_spacing), so the trail is continuous by construction at every level
// and adapts to however fast the player is actually moving. The old time gate
// survives only as a spam floor.
//
// LENGTH IS UNCHANGED, and this is the part to understand before retuning:
// trail length = sprint speed x trail_life_ms, INDEPENDENT of spacing --
// tighter spacing buys more nodes over the same ground, not less ground. It
// only shortens if the per-player node CAP binds first, i.e. when
// life_ms / cadence > TOD_TRAIL_MAX_NODES. At Lv5 the new cadence wants ~13.6
// nodes against the old cap of 12, so the cap goes to 14 purely to stop the
// cap becoming the new limiter. Host cost at Lv5 rises 36 -> 42 of the
// map-wide 60; every other level spawns ONE host per node and stays cheap.
//
// DENSITY DOES NOT CHANGE DAMAGE. trail_burn_tick dedupes on
// z.tod_trail_burn_ms == now -- one node per zombie per tick, map-wide --
// precisely so overlapping nodes read as a line instead of stacking. Do NOT
// "fix" that dedupe thinking it is dropping damage: it is what lets spacing
// be tuned on looks alone.
#define TOD_TRAIL_NODE_MIN_MS    80    // spam floor only (was a 350 ms cadence gate)
#define TOD_TRAIL_MAX_NODES      14    // live nodes per player; the oldest is dropped early past this
#define TOD_TRAIL_MAX_HOSTS      60    // live fire hosts MAP-WIDE (script_models) — the entity budget's share
#define TOD_TRAIL_HOST_LIFT      2     // host z above the feet so the fire sits ON the floor
#define TOD_TRAIL_SEG_GAP_MS     1000  // a node this long after the previous one starts a NEW segment -> the ignite cue (v16.79)
// (TOD_TRAIL_BURN_TELL_MS 3000 RETIRED v18.12 — the tell is now a ONE-SHOT
// IGNITION per zombie, not a 3 s cadence. The corpse-burn lane lights a body for
// 10 s of burn loop and holds its FX for 20 s before its own cleanup, which
// already outlasts any cadence this loop could run; the old 3 s repeat existed
// only because the nuke lane's counter clientfield re-fired per hit. See the
// block in trail_burn_tick.)
#define TOD_TRAIL_BURN_TELL_PER_TICK 3 // burn ignitions per tick per runner — a train through the fire is a few bodies alight, not a wall of them
// BURN_CORPSE from shared/ai/archetype_damage_effects.gsh. Spelled as our own
// constant rather than the stock macro because that header is #insert-ed by the
// stock AI files and not by this one; the VALUE is the contract, and it is the
// only one of the four burn states that draws anything on a zombie (see the
// block in trail_burn_tick).
#define TOD_TRAIL_BURN_STATE     2

function trail_life_ms( lvl )   // 2.0 .. 4.0 s
{
	return 1500 + 500 * lvl;
}

function trail_radius( lvl )    // 56 .. 88 u
{
	return 48 + 8 * lvl;
}

// THE TRAIL IS ATTRITION, NOT A WEAPON (v16.94, user 2026-09-03: "the burn
// should do pretty little damage that increase ... We need the damage low
// enough where players wouldnt dare wasting time getting kills like this").
//
// WAS 12/16/20/24/28 % of the round's zombie health PER SECOND, which killed a
// full-health trash zombie in roughly four seconds of standing in it — well
// inside the 2-4 s a patch lives, so running circles round a train really was
// a viable way to farm, and the fire did the work the gun is supposed to do.
//
// NOW 2/3/4/5/6 %/s. At the Lv5 cap that is ~17 seconds of continuous contact
// to kill one trash zombie, against a patch that lives 4. The trail can now
// only FINISH something already hurt, or wear down a train that keeps running
// through it — which is the whole point of pairing it with the SLOW below.
// Read this ladder, never a number quoted in prose; the pause-menu DETAIL row
// and the card art are the two places that must move with it.
function trail_pct( lvl )       // 2 .. 6 % of the round's zombie health per second
{
	return 1 + lvl;
}

// THE SLOW (v16.94; DOUBLED v17.84; -25% v18.6). Playback-rate multiplier per
// level:
//
//   Lv1 0.925   Lv2 0.88   Lv3 0.835   Lv4 0.79   Lv5 0.745
//
// i.e. 7.5% to 25.5% slower. THE LADDER'S HISTORY IS THE WHOLE ARGUMENT FOR
// READING IT HERE AND NOWHERE ELSE: v16.94 shipped 5%..17% and the user called
// it "not much" — under the threshold where a player can SEE the trail doing
// anything; v17.84 doubled it to 10%..34% on "double the slow rate"; v18.6 took
// 25% back off (user 2026-09-07: "trail blazer needs a nerf on slowing down
// enemies ... 25%"), landing between the two. The slow IS the payload; the fire
// is the tell that marks the ground it covers.
//
// TWO LANES, BECAUSE AN ELITE IS NOT A ZOMBIE (v17.84). Trash rides
// tod_zombie_speed::slow(), the SAME public lane SUPPRESSING FIRE uses, which
// buys three behaviours for free: a zombie already under a STRONGER slow
// (Widow's cocoon, Time Warp, a trap) is never stomped up to ours, the
// keep-alive sweep multiplies it back in on every re-assert instead of a
// one-shot rate write decaying away — and it REFUSES anything boss-flagged.
// That refusal is why the user's "slow elites but do not burn them" could not
// just delete an early-out: elites go through slow_elite() in the same module,
// a narrower lane that writes their own ASM rate and puts it back. See the
// block above it for why that is proven safe rather than assumed.
function trail_slow_mult( lvl )
{
	// 0.04 + 0.06*lvl until v18.6; x0.75 = 0.03 + 0.045*lvl. The half-percent
	// steps at odd levels are real and the pause row prints them — do not round
	// this to keep the readout tidy, round the READOUT.
	return 1.0 - ( 0.03 + 0.045 * lvl );
}

// Duration per application. Longer than the 500 ms burn tick on purpose, so a
// zombie standing in fire is re-slowed before the previous one lapses and the
// effect reads as continuous; short enough that walking out of the fire gives
// the speed back within about a second.
#define TOD_TRAIL_SLOW_MS  1200

// THE FIRE BED (v16.96) — ONE looping voice per player for as long as that
// player has any live trail, rather than one per fire patch. Same shape as
// FULL STEAM's wind (TOD_LMGS_SFX / TOD_LMGS_SFX_FADE): PlayLoopSound on the
// PLAYER, StopLoopSound with a fade so it falls away instead of cutting dead.
// That is the proven per-player loop lane in this map, and the user named it as
// the model. The alias stays 3D so a teammate hears it positionally from the
// runner while the runner themself sits at distance 0 and hears it full.
#define TOD_TRAIL_LOOP_SFX     "tod_trail_loop"      // Lv3+ — vol 82
#define TOD_TRAIL_LOOP_SFX_SM  "tod_trail_loop_sm"   // Lv1-2 — the SAME wav at vol 68
#define TOD_TRAIL_LOOP_FADE    0.45   // seconds — a fire bed should die away slower than a wind gust

// WHICH BED A LEVEL PLAYS — the audible half of the same tier ramp trail_fx()
// draws (user: "You should be encouraged to go to higher tiers visually and
// impact wise"), and it is deliberate rather than inherited.
//
// The OLD per-patch loop scaled with level only BY ACCIDENT: more live nodes
// meant more overlapping copies, so Lv5 was louder than Lv1 because it was
// stacking harder. That was never a design, it was the artefact this build
// removes — and v16.92's spacing change had just made it about twice as bad at
// Lv1 (roughly 5.7 -> 10.7 live nodes). Collapsing to ONE voice would have made
// every level sound identical, so the ramp is re-created on purpose: two alias
// rows over the SAME wav, differing only in volume, split at the SAME Lv3
// boundary as the small/large flame. One knob, two rows, no second asset.
//
// Chosen when the bed STARTS and held for that burst. A level-up mid-sprint
// keeps the quieter bed until the next burst, which is a fair trade against
// stopping and restarting a loop underneath the player mid-stride.
function trail_loop_alias( lvl )
{
	if ( lvl >= 3 )
		return TOD_TRAIL_LOOP_SFX;
	return TOD_TRAIL_LOOP_SFX_SM;
}

// A kill the FIRE finished pays this flat, instead of the round's normal kill
// money (v16.94, user: "should only reward 30 per kill"). The second half of
// "do not farm this": the damage makes it slow, this makes it worthless.
#define TOD_TRAIL_KILL_PTS 30

// Node spacing = ONE PATCH WIDTH, so consecutive patches just touch and the
// trail is continuous at every level. Keyed to trail_radius deliberately: a
// radius retune must move the spacing with it or the gaps come straight back.
function trail_spacing( lvl )
{
	return trail_radius( lvl );
}

function trail_hosts( lvl )     // fire patches across the trail's width
{
	if ( lvl >= 5 )
		return 3;
	if ( lvl >= 3 )
		return 2;
	return 1;
}

// WHICH FIRE A LEVEL DRAWS (v16.94, user 2026-09-03: "fx needs to be smaller on
// smaller tiers. You should be encouraged to go to higher tiers visually and
// impact wise"). Levels already differed in COUNT (1/2/3 patches across) and in
// the radius they cover; they all drew the same size flame, so a Lv1 trail read
// almost as loud as a Lv5 one.
//
// An .efx cannot be scaled from script — PlayFxOnTag takes no scale — so the
// size ladder has to be separate AUTHORED effects. Both of these are real
// stock ground fires from the base-game `fire/` directory, both carry proper
// flame materials, and NEITHER references a `_pcloud` (the crash class that
// killed map 1's fungus pod):
//
//   Lv1-2  fire/fx_fire_ground_rubble_sm_50x50   the small one
//   Lv3+   fire/fx_fire_ground_rubble_50x50      what every level drew before
//
// Together with the host count that gives a real visual ramp: one small patch
// at Lv1, two full ones at Lv3, three at Lv5. Both are precached AND zoned —
// an effect needs both or PlayFx silently draws nothing, and this map has now
// shipped that exact bug twice (v16.62's dog trail, and the placeholder trap in
// memory stub-efx-in-mod-tools).
function trail_fx( lvl )
{
	if ( lvl >= 3 )
		return level._effect[ "tod_trail_fire" ];
	return level._effect[ "tod_trail_fire_sm" ];
}

// self = player. Threaded once from the body-systems latch; inert until the
// domain is owned, and again the moment the player is not a skirmisher.
function trail_loop()
{
	self endon( "disconnect" );
	level endon( "end_game" );
	self.tod_trail_nodes = [];
	if ( !IS_TRUE( level.tod_trail_reaper_on ) )
	{
		level.tod_trail_reaper_on = true;
		level.tod_trail_host_list = [];
		level thread trail_reaper();
	}
	last_ms  = 0;
	tick_ms  = 0;
	last_org = undefined;
	for ( ;; )
	{
		// [v16.92] 0.1 -> 0.05: the poll is pure latency stacked on top of the
		// spacing gate, and at sprint speed a tenth of a second is most of a
		// patch width. The body is a handful of cheap tests until the domain is
		// owned, so the extra tick costs nothing for anyone who lacks it.
		wait 0.05;
		now = GetTime();
		self trail_expire( now, false );
		// v16.96 — reconciled HERE, above every early-continue below, so the bed
		// is correct in states that skip the rest of the loop entirely: no
		// domain, wrong class, downed, dead, or the world paused for a card. In
		// all of those the nodes still expire above and the sound must follow
		// them down rather than hang.
		self trail_sound_reconcile();
		lvl = get_level( self, "trailblazer" );
		if ( lvl <= 0 )
			continue;
		if ( !isdefined( self.tod_class ) || self.tod_class != "skirmisher" )
			continue;
		if ( !isalive( self ) || ( self laststand::player_is_in_laststand() ) )
			continue;
		if ( IS_TRUE( level.tod_upgrade_pause ) || IS_TRUE( self.tod_menu_frozen ) )
			continue;
		if ( ( self IsSprinting() ) && ( self IsOnGround() ) && ( now - last_ms ) >= TOD_TRAIL_NODE_MIN_MS )
		{
			org = self.origin;
			// DISTANCE IS THE GATE NOW. gap = one patch width, so the next patch
			// starts where the last one ends. This also subsumes the old 48 u
			// anti-spin guard: standing still never travels a patch width, so
			// spinning on the spot still lays nothing.
			gap = trail_spacing( lvl );
			if ( !isdefined( last_org ) || DistanceSquared( org, last_org ) >= ( gap * gap ) )
			{
				// a node long after the last one opens a NEW segment: that is the ignite
				b_ignite = ( last_ms == 0 || ( now - last_ms ) >= TOD_TRAIL_SEG_GAP_MS );
				self trail_drop_node( org, lvl, now, b_ignite );
				last_ms  = now;
				last_org = org;
			}
		}
		if ( self.tod_trail_nodes.size > 0 && ( now - tick_ms ) >= TOD_TRAIL_TICK_MS )
		{
			tick_ms = now;
			self trail_burn_tick( now );
		}
	}
}

// self = player. One node + its fire patches, laid ACROSS the direction of
// travel so the wider levels read as a wider trail, not a longer one.
// b_ignite (v16.79): this node opens a new segment — play the ignite cue.
function trail_drop_node( org, lvl, now, b_ignite )
{
	n = SpawnStruct();
	n.org    = org;
	n.expire = now + trail_life_ms( lvl );
	r        = trail_radius( lvl );
	n.pct    = trail_pct( lvl );
	n.slow   = trail_slow_mult( lvl );   // v16.94 — precomputed like n.pct, so the tick never re-reads a level that may have changed
	// DARK UPGRADE (v17.10): 6%/s -> 10%/s burn, 17% -> 25% slow, 88u -> 100u.
	// Baked into the NODE at drop time, like everything else here, so a node laid
	// before the card was taken keeps the values it was dropped with.
	if ( has_dark( self, "trailblazer" ) )
	{
		n.pct  = TOD_DARK_TRAIL_PCT;
		n.slow = TOD_DARK_TRAIL_SLOW_MULT;
		r      = TOD_DARK_TRAIL_RADIUS;
	}
	n.r2     = r * r;   // AFTER the dark radius — squaring first would keep the base
	n.hosts  = [];
	perp = ( 0, 0, 0 );
	v = self GetVelocity();
	v = ( v[ 0 ], v[ 1 ], 0 );
	if ( Length( v ) > 1 )
	{
		d = VectorNormalize( v );
		perp = ( 0 - d[ 1 ], d[ 0 ], 0 );
	}
	k = trail_hosts( lvl );
	for ( i = 0; i < k; i++ )
	{
		off = 0;
		if ( k == 2 )
			off = ( ( i == 0 ) ? -0.5 : 0.5 ) * r;
		else if ( k == 3 )
			off = ( i - 1 ) * 0.6 * r;
		if ( !isdefined( level.tod_trail_host_list ) || level.tod_trail_host_list.size >= TOD_TRAIL_MAX_HOSTS )
			break;   // the entity budget's share is spent — the DAMAGE node still lands
		h = Spawn( "script_model", org + perp * off + ( 0, 0, TOD_TRAIL_HOST_LIFT ) );
		if ( !isdefined( h ) )
			continue;
		h SetModel( "tag_origin" );
		h.tod_trail_expire = n.expire;
		PlayFxOnTag( trail_fx( lvl ), h, "tag_origin" );   // v16.94: small flame below Lv3 — see trail_fx
		n.hosts[ n.hosts.size ] = h;
		level.tod_trail_host_list[ level.tod_trail_host_list.size ] = h;
	}
	// THE IGNITE (v16.79) — a ONE-SHOT on the node's first patch, so it fires at
	// the world position the fire actually started. No host (entity budget
	// spent) = no ignite; the damage still lands.
	//
	// THE SUSTAINED FIRE BED IS NOT PLAYED HERE ANY MORE (v16.96, user
	// 2026-09-03: "The sound seems off and not continuous. Stops after like 2
	// seconds"). It used to be a PlayLoopSound on this same host, and that was
	// wrong in two compounding ways:
	//
	//   1. A HOST IS DELETED AT ITS NODE'S EXPIRY, and deleting an entity takes
	//      its voices with it. trail_life_ms is 1500 + 500*lvl, so at Lv1 the
	//      host — and its sound — died at EXACTLY 2000 ms. That is the two
	//      seconds, measured, not guessed.
	//   2. Even while sprinting it never summed into a bed. Each new node
	//      restarted the same 4 s file FROM ITS START every ~56 units of travel
	//      (a few times a second), against an alias capped at 6 voices stealing
	//      the oldest — a phasey pile of restarts, not continuous fire.
	//
	// The bed is now ONE voice per player, reconciled in trail_loop; see
	// trail_sound_reconcile.
	if ( n.hosts.size > 0 && IS_TRUE( b_ignite ) )
		n.hosts[ 0 ] PlaySound( "tod_trail_ignite" );
	self.tod_trail_nodes[ self.tod_trail_nodes.size ] = n;
	while ( self.tod_trail_nodes.size > TOD_TRAIL_MAX_NODES )
		self trail_expire( now, true );
}

// self = player. THE FIRE BED — one looping voice, on for exactly as long as
// this player has live trail on the ground (v16.96; see the TOD_TRAIL_LOOP_SFX
// block for what it replaced and why).
//
// LATCHED, so PlayLoopSound is called ONCE per burst rather than every 50 ms
// poll: a second PlayLoopSound of the same alias on the same entity starts a
// SECOND generation, and the first is then no longer addressable by alias and
// rings forever (memory loop-sound-stop-by-handle). The latch is what makes
// that unreachable rather than merely unlikely.
//
// `isalive` is part of the want test, so death stops the bed even though the
// player entity survives into spectate. A disconnect takes the voice with the
// entity, so the endon on the caller cannot strand it.
function trail_sound_reconcile()
{
	want = ( isdefined( self.tod_trail_nodes ) && self.tod_trail_nodes.size > 0 && isalive( self ) );

	if ( want && !isdefined( self.tod_trail_snd_alias ) )
	{
		// Remember WHICH alias is playing, not merely that one is: the stop
		// below must name nothing, but a future reader adding a mid-burst
		// swap needs to know which row is live, and storing the name makes
		// the wrong assumption impossible to make silently.
		self.tod_trail_snd_alias = trail_loop_alias( get_level( self, "trailblazer" ) );
		self PlayLoopSound( self.tod_trail_snd_alias );
		return;
	}
	if ( !want && isdefined( self.tod_trail_snd_alias ) )
	{
		self.tod_trail_snd_alias = undefined;
		self StopLoopSound( TOD_TRAIL_LOOP_FADE );   // SERVER signature: a FADE TIME, not a handle
	}
}

// self = player. Drops expired nodes; b_oldest also drops the oldest live one
// (the per-player cap). A dropped node's fire is told to die NOW so the visual
// never outlives the damage.
function trail_expire( now, b_oldest )
{
	if ( !isdefined( self.tod_trail_nodes ) || self.tod_trail_nodes.size == 0 )
		return;
	keep = [];
	took_oldest = false;
	for ( i = 0; i < self.tod_trail_nodes.size; i++ )
	{
		n = self.tod_trail_nodes[ i ];
		drop = ( now >= n.expire );
		if ( b_oldest && !took_oldest )
		{
			drop = true;
			took_oldest = true;
		}
		if ( !drop )
		{
			keep[ keep.size ] = n;
			continue;
		}
		foreach ( h in n.hosts )
		{
			if ( isdefined( h ) )
				h.tod_trail_expire = now;   // the reaper takes it on its next pass
		}
	}
	self.tod_trail_nodes = keep;
}

// Level thread, ONE for the map: deletes every fire host past its expiry.
// Owning the hosts here rather than on the player is what makes a disconnect
// mid-sprint leak nothing.
function trail_reaper()
{
	level endon( "end_game" );
	for ( ;; )
	{
		wait 0.25;
		if ( !isdefined( level.tod_trail_host_list ) || level.tod_trail_host_list.size == 0 )
			continue;
		now = GetTime();
		keep = [];
		foreach ( h in level.tod_trail_host_list )
		{
			if ( !isdefined( h ) )
				continue;
			if ( isdefined( h.tod_trail_expire ) && now >= h.tod_trail_expire )
				h Delete();
			else
				keep[ keep.size ] = h;
		}
		level.tod_trail_host_list = keep;
	}
}

// self = player. One burn pass over the horde: a zombie inside ANY of this
// player's live nodes takes one tick, from the first node found.
function trail_burn_tick( now )
{
	hp   = ( ( isdefined( level.zombie_health ) ) ? level.zombie_health : 150 );
	team = ( ( isdefined( level.zombie_team ) ) ? level.zombie_team : "axis" );
	zs   = GetAITeamArray( team );
	tells = 0;   // v16.87: per-tick budget for the burn tell (flame + sound)
	// WHO THE FIRE IS ALLOWED TO HURT, AND WHO IT MERELY HOLDS UP (v17.84,
	// user 2026-09-05: "make the base slow elites but not burn").
	//
	// TRASH takes the burn and the slow. An ELITE (the is_boss / acc_is_boss /
	// acc_is_mini_boss triad -- Panzer, Rogue Protector, Reaver, hellhound, and
	// every Warden) takes ONLY the slow, so the trail becomes a tool for making
	// ground during a boss wave without becoming a way to kill a boss with a
	// percentage of TRASH health per second. Armored sprinters are trash-flagged
	// and burn like anything else.
	//
	// DARK TRAILBLAZER lifts the exemption and burns the triad too (user
	// 2026-09-05: "Mega Trail Blaze impacts bosses"). Same tick, same node maths.
	burn_bosses = has_dark( self, "trailblazer" );
	foreach ( z in zs )
	{
		if ( !isdefined( z ) || !isalive( z ) )
			continue;
		// NOT an early-out any more: an elite still walks the node list below,
		// it just leaves with the slow and nothing else.
		b_elite = ( IS_TRUE( z.is_boss ) || IS_TRUE( z.acc_is_boss ) || IS_TRUE( z.acc_is_mini_boss ) );
		b_burn  = ( !b_elite || burn_bosses );
		// THE EMERGE GATE IS A TRASH GATE, and applying it to elites would have
		// made the whole elite lane dead on arrival (v17.84). It is STOCK's field,
		// set by the zombie behaviour tree when a riser clears its barricade
		// (_zm_spawner::zombie_complete_emerging_into_playable_area) -- every elite
		// here is a direct SpawnActor on its OWN behaviour tree and arrives by its
		// own entrance, so nothing was ever going to set it on a Panzer. An elite
		// mid-entrance is covered instead by slow_elite() declining while
		// tod_dropping owns the rate.
		if ( !b_elite && !IS_TRUE( z.completed_emerging_into_playable_area ) )
			continue;
		if ( isdefined( z.tod_trail_burn_ms ) && z.tod_trail_burn_ms == now )
			continue;   // one node per tick, map-wide
		zo = z.origin;
		foreach ( n in self.tod_trail_nodes )
		{
			if ( DistanceSquared( zo, n.org ) > n.r2 )
				continue;
			dmg = int( hp * ( n.pct / 100.0 ) * ( TOD_TRAIL_TICK_MS / 1000.0 ) );
			if ( dmg < 1 )
				dmg = 1;
			// Claimed for this tick whether or not the burn lands, so an elite
			// standing on overlapping nodes is slowed ONCE per tick like everything
			// else -- the dedupe is what keeps a stacked trail a line, not a pile.
			z.tod_trail_burn_ms = now;

			// THE SLOW, FIRST AND UNCONDITIONALLY (v17.84) -- it is the half every
			// zombie in the fire gets. Two lanes because an elite drives a custom
			// locomotion ASM that tod_zombie_speed::slow() refuses to touch by
			// design; slow_elite() is the narrow lane for those, and it declines
			// while an owner (the drop-in entrance, the upgrade pause, a menu
			// freeze) holds the rate. Re-applied on every tick a body is in fire,
			// so it refreshes ahead of its own 1.2 s expiry and reads as continuous.
			//
			// This is also the first build in which DARK TRAILBLAZER actually slows
			// a boss: v17.10 passed them to slow(), which had already returned on
			// the boss guard before reading the multiplier.
			if ( b_elite )
				z tod_zombie_speed::slow_elite( n.slow, TOD_TRAIL_SLOW_MS );
			else
				z tod_zombie_speed::slow( n.slow, TOD_TRAIL_SLOW_MS );

			if ( !b_burn )
				break;   // slowed, not burned: no tell, no points, no damage
			// THE BURN TELL (v16.87, user 2026-09-03: "when a zombie is burned
			// can we give it the nuke burn effect ... reusing what nuke has sfx
			// and fx would be great"). BEFORE the damage, so a burn that kills
			// never plays on an entity the engine is already tearing down.
			//
			// OFF THE NUKE'S LANE (v18.12, user 2026-09-07: "for trailblazer we
			// give them the nuke effect. Can we give them something else").
			//
			// It used to increment `zm_nuked`, which is literally the nuke's own
			// actor clientfield, and play `evt_nuked`, the nuke's own per-zombie
			// sound. That was v16.87's explicit ask ("reusing what nuke has sfx
			// and fx would be great") and it worked — too well: a trail kill read
			// as somebody having pulled a Nuke.
			//
			// NOW: `arch_actor_fire_fx` = 2 = BURN_CORPSE, the stock staged
			// burn. Verified before writing, and each of these was a real
			// question:
			//
			//   REGISTERED? YES, in both VMs, and NOTHING is owed for it. It is
			//   an autoexec register in shared/ai/archetype_damage_effects, pulled
			//   in by archetype_shared from _load in BOTH zm_tower_of_doom.gsc and
			//   .csc, and it lives in the core_patch base zone. Do NOT register it
			//   ourselves (a duplicate register is the load-abort hazard) and do
			//   NOT add a zone line (zoning stock FX is how this map once
			//   inherited a 5,092-byte stub over a working stock effect —
			//   zm_tower_of_doom.csc:100-123). Proof it works here: mechz_spiki
			//   already sets this exact field to 1 for the Panzer's napalm
			//   zombies, and that ships.
			//
			//   VALUE 2 AND NOT 1. Value 1 (BURN_BODY) builds its FX key with a
			//   "_loop" postfix and stock defines no `fire_zombie_*_loop` entries
			//   at all — it renders NOTHING on a zombie. Value 2 takes the "_os"
			//   postfix, and those ten keys DO exist (they alias the human fire
			//   set: torso, arms, hips, knees, head), with real .efx sources.
			//
			//   ⚠️ AND IT IS AN "int", NOT A "counter" — WHICH IS WHY THIS IS A
			//   ONE-SHOT NOW. An int clientfield is delta-driven: setting 2 on a
			//   zombie already holding 2 sends nothing and draws nothing. A
			//   drop-in swap of the old 3 s cadence would have fired once per
			//   zombie and been silently inert forever after, which is a bug you
			//   only see in play. Re-firing would need set(0), a snapshot's wait,
			//   then set(2) — and that fights BURN_CORPSE's own 20 s cleanup and
			//   re-runs the char ramp every time. The cadence is not needed
			//   anyway: one set lights the body for a 10 s burn loop and holds
			//   its FX for 20 s, far longer than a zombie survives standing in
			//   fire. So: light each body ONCE, and let the stock lane run.
			//
			//   THE SOUND IS THE MAP'S OWN NOW. BURN_CORPSE starts
			//   `chr_burn_npc_loop1` on the victim itself and stops it on a 10 s
			//   timer, so the sustained burn needs nothing from us — adding a
			//   server loop would just double it. `tod_trail_sizzle` is played
			//   once as the IGNITION cue: a 3D non-looping alias that has been in
			//   this map's own tod_ui.csv since v16.79 with nothing playing it.
			//   It is what makes the trail sound like the trail instead of like a
			//   powerup.
			//
			// TOD_TRAIL_BURN_TELL_PER_TICK still caps how many bodies light in one
			// tick, so a train through the fire is a few bodies going up rather
			// than a wall of them.
			if ( tells < TOD_TRAIL_BURN_TELL_PER_TICK && !IS_TRUE( z.tod_trail_lit ) )
			{
				z.tod_trail_lit = true;
				tells++;
				z clientfield::set( "arch_actor_fire_fx", TOD_TRAIL_BURN_STATE );
				z PlaySound( "tod_trail_sizzle" );
			}
			// A KILL THE FIRE FINISHED PAYS A FLAT 30 (v16.94). Decided HERE,
			// before the damage lands, because stock's own scoring reads a flag
			// on the zombie: _zm_spawner.gsc sets `deathpoints_already_given`
			// and returns early if it is already true. Claiming it first is what
			// makes stock skip its normal kill award entirely — no subtracting
			// points back off the player after the fact, and no dependence on
			// whether the death-event callback runs before or after the award.
			//
			// `z.health <= dmg` is the lethality test and it is exact: this is
			// the only damage in flight for this zombie this tick (the dedupe
			// above guarantees one node per zombie per tick), and DoDamage is
			// synchronous.
			if ( isdefined( z.health ) && z.health <= dmg && !IS_TRUE( z.deathpoints_already_given ) )
			{
				z.deathpoints_already_given = true;
				z.tod_popup_points = TOD_TRAIL_KILL_PTS;   // v19.58: the kill popup shows what this paid
				self zm_score::add_to_player_score( TOD_TRAIL_KILL_PTS );
			}

			z.tod_trail_hit = true;   // consumed by upgrade_damage_cb (no attacker multipliers)
			z DoDamage( dmg, zo, self );
			break;
		}
	}
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
