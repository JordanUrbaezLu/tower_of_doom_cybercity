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
#using scripts\shared\flag_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm;
#using scripts\zm\_zm_score;
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

#insert scripts\shared\shared.gsh;

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
//      up 5x as often as S.
//   2. RARITY GATE — S/A cards shrink their SUPER+ULTIMATE slice toward
//      REGULAR, so "S domain at ULTIMATE (+3 levels)" is the rarest event in
//      the game even on a full luck bar.
// ---------------------------------------------------------------------------
#define TOD_TIER_B   1     // utility / incremental — common
#define TOD_TIER_A   2     // strong
#define TOD_TIER_S   3     // game-defining
#define TOD_TIER_W_B 100   // draw weight (relative)
#define TOD_TIER_W_A 50
#define TOD_TIER_W_S 20
#define TOD_TIER_R_A 0.75  // SUPER/ULTIMATE slice multiplier
#define TOD_TIER_R_S 0.50

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
#define TOD_UPG_DMG_PER_LVL     0.12   // +12% damage per level
#define TOD_UPG_ECHO_PCT_PER_LVL 10    // +10%/level chance to double-hit
#define TOD_UPG_MAG_PCT_PER_LVL 0.20   // +20% of base clip per level
#define TOD_UPG_BOUNTY_PER_LVL  0.05   // +5%/Lv (user 2026-08-20, was 3%)
// HEADSHOT: +4% per level (user 2026-08-26: "the Assault class need a minor
// buff. The headshot damage needs to be 4% for each level"). History:
// 0.10 -> 0.04 (2026-08-22 nerf) -> 0.03 (v9.45, 2026-08-23) -> 0.04 here,
// which restores the v9.45-era value. At the 10-level cap that is +40% on a
// head hit, up from +30%. THE LITERAL COPY IN _tod_bosses::rp_damage_feed MUST
// MOVE WITH IT — a GSC #define is file-local and that lane cannot see this
// symbol; it was already stale once (0.10 there while this said 0.04) and paid
// 2.5x on the Rogue Protector for a day. Grep TOD_UPG_HS_PER_LVL, never a line
// number. The CARD ART carries "+4/+8/+12%" and "4% PER LEVEL" baked in, and
// tod_upgrade.lua carries it twice more (DOMAIN[6].desc, DETAIL[6].val).
#define TOD_UPG_HS_PER_LVL      0.04
#define TOD_UPG_SPEED_PER_LVL   0.05   // +5% move speed per level (SPRINT / MOBILITY; buffed from 3% — user 2026-08-21 "buff mobility for skirmisher")
// SPRINT ARMOR (v9.28, user 2026-08-23: "take less damage when you are
// running, 5% each level, 5 levels max, only for melee and skirmisher"):
// incoming damage x (1 - this*Lv) WHILE the engine says the player is
// sprinting (IsSprinting, server builtin). Applied in _tod_bosses' two
// player-damage lanes right after DMG REDUCTION — the two stack
// multiplicatively (Lv5 of both while sprinting = x0.75 x 0.75).
#define TOD_UPG_SPRINT_ARMOR_PER_LVL 0.05
// GIANT SLAYER (v9.45, user 2026-08-23: "an upgrade where they do more damage
// to boss and elites. 3% per level, can go to level 5"; BUFFED to 4%/Lv
// 2026-08-26, user: "boss damage also 4% per level"). ASSAULT. +4%/Lv, added
// into the SAME additive mult sum as DAMAGE and HEADSHOT rather than
// multiplying on top of it — so Lv5 is +20% of BASE damage, not +20% of the
// already-multiplied total.
//
// WHAT COUNTS AS A BOSS OR ELITE: the map-wide triad is_boss / acc_is_boss /
// acc_is_mini_boss, which the Panzer, the Rogue Protector AND the Reaver all
// set synchronously on their spawn frame. Eight other systems already gate on
// exactly those three fields (the zombie speed curve, IMPACT ROUNDS,
// SUPPRESSING FIRE, THOR'S THUNDER, the powerup drop roll, the floor gauge,
// CHAIN LUNGE, Electric Cherry), so a future elite that sets the triad is
// covered by this card for free, and one that does not is invisible to all
// nine at once. Read it through is_boss_or_elite() — never re-spell the triad.
#define TOD_UPG_BOSSDMG_PER_LVL 0.04
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
#define TOD_MELEE_BOSS_MULT     0.5
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
#define TOD_SCAV_KILLS_LV1      5      // kills per refunded round at Lv1
#define TOD_SCAV_KILLS_MIN      1      // floor — Lv5 lands here (1 kill, 1 round)
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
#define TOD_SCAV_CAP_LVL        6      // the capstone rung (assault's bonus level)
#define TOD_SCAV_CAP_KILLS      2      // capstone: 2 kills...
#define TOD_SCAV_CAP_ROUNDS     3      // ...pays 3 rounds
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
// JUGG-SAFE BY THE SAME MECHANISM AS THE 150 BASE: stock jugg is ADDITIVE
// (_zm_perks.gsc — preMaxHealth snapshot + jugg_health added on top), so a
// vitality level bought BEFORE jugg is inside the snapshot and survives the
// loss-restore; one bought DURING jugg is added immediately by apply_upgrade
// and, when jugg's restore clobbers it, re-raised (max only, no free heal)
// by the body loop's want-floor within a second.
#define TOD_UPG_VITALITY_HP_PER_LVL 10
// RECOVERY (HEAVY, v14.11 — user 2026-08-30: "start regen faster 10% faster
// at each tier and goes to 3 tiers at 30% faster at max. A tier"). Stock zm
// regen is SCRIPT-side (_zm_playerhealth.gsc::playerHealthRegen): above the
// 20% healthOverlayCutoff it waits playerHealth_RegularRegenDelay (2400ms)
// after the last hit and then SNAPS to full; below the cutoff it waits
// longRegenTime (5000ms) and then climbs 0.1 ratio/frame. The delay var is
// LEVEL-GLOBAL, so it cannot be set per player — instead recovery_loop()
// EMULATES the stock outcome at the REDUCED delay: after
// stock_delay x (1 - 0.10 x Lv) without damage it delivers exactly what stock
// would deliver at the full delay (snap above the cutoff, the 0.2/tick climb
// below it). Stock's own loop still runs untouched and simply finds the
// player already healed. Both stock numbers are read LIVE off the level vars
// (fallbacks mirror the stock inits) so a stock retune propagates.
#define TOD_UPG_RECOV_PCT_PER_LVL 0.10
#define TOD_RECOV_TICK_SECS       0.1     // emulation cadence; 0.1s error max on the poll-stamp lane
#define TOD_RECOV_CLIMB_PER_TICK  0.2     // veryHurt band: ratio climbed per tick (stock: 0.1/50ms frame)
// SECOND WIND (MP7, skirmisher T3 unique — user 2026-08-23: "you heal as you
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
// increase damage while running too. At the same rates so 20%, 35%, and
// 50%."). Flat while moving, not MOMENTUM's ramp — the ammo half is flat, so
// the card stays ONE condition with ONE ladder. The percentages and the
// movement test are LOCKSTEP MIRRORS of _tod_runandgun.gsc
// (TOD_RNG_PCT_BASE 20 / TOD_RNG_PCT_PER_LV 15 / TOD_RNG_MIN_SPEED 120 and
// is_running(): IsSprinting() OR 2D speed >= MIN_SPEED) — that module cannot
// be #used from here (it imports us; the KB cycle rule), so the four numbers
// are duplicated on purpose. Change one file and you MUST change the other,
// or the card's two halves trigger on different definitions of "moving".
#define TOD_UPG_RNG_DMG_BASE       0.20  // Lv1 +20% damage while moving...
#define TOD_UPG_RNG_DMG_PER_LV     0.15  // ...+15%/Lv -> Lv2 +35%, Lv3 +50%
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
#define TOD_UPG_BASE_HP         150    // base player max HP (user 2026-08-20; stock 100; jugg stacks additively on top)
// CLASS TIERS (docs/25, user 2026-08-22): once the class gun is PaP'd, this
// percent of card deals carry a TIER card (the right slot; never auto-locked).
// Dev flag -> 100 (tier_card_pct) so the whole promotion flow is testable in
// one session. LUCK does NOT move it (user).
// v9.42 (user 2026-08-23: "Increase this to 20%. 10% was too low") — 10 -> 20.
#define TOD_TIER_CARD_PCT       20
// ---- CLASS TIER UNIQUES (docs/25 §9) — one per tier gun, script-side -----
#define TOD_ADREN_PCT_BASE      0.04   // ADRENALINE (MP5): +4% speed per stack at Lv1...
#define TOD_ADREN_PCT_PER_LV    0.02   // ...+2% per level (Lv3 = +8% per stack)
#define TOD_ADREN_STACKS        3      // stacks cap
#define TOD_ADREN_MS            4000   // each kill re-arms the 4s window
#define TOD_STREAK_GAP_MS       500    // (mirrors _tod_uniques) a longer pause ends a fire streak
#define TOD_OVERDRIVE_PER       10     // OVERDRIVE (MP7): one stack per 10 consecutive rounds
#define TOD_OVERDRIVE_STACKS    5
// KILL RELOAD (assault) — kills per FREE MAGAZINE, one ladder step per level.
// v9.43 (user 2026-08-23: "its still crazy even if it comes out of reserve ...
// you basically never have to reload"). See the block in unique_on_kill for
// why the old per-kill percentage could not be rescued by any number.
// KILL RELOAD — BUFFED 4x (user 2026-08-27: "no one ever chooses kill reload.
// That needs a buff"). Was 100/75/50, which is why: 100 kills is roughly a whole
// round's fair share at mid rounds, so Lv1 paid out about once every two rounds
// and the card was strictly worse than anything next to it on the deal.
//
// 55/40/30 (user's number, 2026-08-27: "55 40 30 makes more sense" — my first
// cut was 25/15/10 and was too hot). Still close to a 2x buff at every level,
// and it keeps the card a steady quality-of-life pick rather than something that
// removes reloading from the class outright. THIS DOMAIN DOES NOT CREATE AMMO:
// the proc tops the clip up FROM RESERVE (want = cap - clip) and is capped by
// what the reserve holds, so what it really buys is the RELOAD TIME and never
// being caught mid-animation. That is why it can be generous without touching
// the ammo economy, and why it pairs rather than competes with SCAVENGER, which
// is the one that actually puts rounds back.
#define TOD_KILLRELOAD_KILLS_LV1   55
#define TOD_KILLRELOAD_KILLS_LV2   40
#define TOD_KILLRELOAD_KILLS_LV3   30
// IMPACT ROUNDS (assault, all three guns since v9.38). v9.45 (user 2026-08-23:
// "impact rounds can be 10 levels but each level needs to be nerfed. Smaller
// steps per level"): 3% PER LEVEL over TEN levels — 3/6/9 ... 30% of hits burst.
// The Lv10 ceiling is exactly the old Lv3 ceiling, so the card got no stronger;
// what changed is that reaching it costs ten levels instead of three and each
// individual level is a third of the proc rate it used to buy.
#define TOD_IMPACT_PCT_PER_LV   3
#define TOD_IMPACT_RADIUS       64
#define TOD_IMPACT_FRAC         0.4    // ...for 40% of the hit
#define TOD_IMPACT_MAX_VICTIMS  6
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
// v14.13 — the SURVIVES-PROMOTION bit rides INSIDE the max arg of the
// tod_upg_sync event: sync_max() adds this flag when THIS player's copy of
// the domain survives a tier card, and the Lua receiver strips it back off
// (m >= 100 -> safe, m -= 100). Packed rather than sent as a 4th int because
// no 4-arg LuiNotifyEvent exists anywhere in this tree — the 3-arg shape is
// the proven one (stock-API doctrine: never be the first caller of an
// unverified arity). Must stay ABOVE every real max (caps top out at 10).
#define TOD_SYNC_SAFE_FLAG 100
#precache( "model", "chaos_pack_a_punch" );   // personal upgrade station terminal
// THOR'S THUNDER fx (AFTER every #using — the "No generated data" trap)
#precache( "fx", "_ZoekMeMaar/powerups/thunderstorm_effect" );
#precache( "fx", "zombie/fx_tesla_shock_zmb" );
#precache( "fx", "zombie/fx_tesla_shock_eyes_zmb" );
#precache( "fx", "zombie/fx_thundergun_smoke_cloud" );
#precache( "fx", "dlc0/factory/fx_teleporter_elec_strike_os" );

// THOR'S THUNDER tuning (user 2026-08-21: "louder and stronger and more
// powerful every level up"). Damage is a FRACTION of each victim's max health
// so the strike stays relevant in late rounds (a flat number would not).
// v8.8 (user 2026-08-21: "reduce effect/impact of Lv1 — Lv1 & Lv3 too close").
// Lv1 is now a small localized zap; the storm builds toward Lv3+. Radius/dmg
// both start lower and climb steeper so the tiers read distinctly.
#define TOD_THOR_RADIUS_BASE   40     // Lv1 = 80u (was 120); Lv3 = 160, Lv5 = 240
#define TOD_THOR_RADIUS_PER_LV 40     //   +40u per level
#define TOD_THOR_DMG_BASE      0.05   // Lv1 = 20% max hp (was 27%)...
#define TOD_THOR_DMG_PER_LV    0.15   //   +15%/Lv -> Lv3 = 50% (unchanged, "fine"), Lv5 = 80%
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
#define TOD_THOR_CD_MAX_MS     3750   // Lv1 cooldown (was 1500)
#define TOD_THOR_CD_MIN_MS     1250   // floor (Lv5 lands here; was 500)
#define TOD_THOR_CD_STEP_MS    625    // shaved per level (was 250)
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

	// PERSONAL UPGRADE STATION (user 2026-08-20): buy a solo upgrade at the
	// base — cost 2000 +250 per purchase (PER PLAYER), no world pause (the
	// risk), 15s timer, scheduled rounds override + the same cards re-present.
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
	// BOUNTY as a flat multiplier on a lump-sum payout (v14.5) — same pointer
	// pattern, first consumer _tod_bosses::grant_elite_reward (the killer-only
	// elite 500). See bounty_mult below.
	level.tod_bounty_mult_fn = &bounty_mult;

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
	add_domain( "damage",     "DAMAGE",      "+12% damage / Lv",                    10, undefined, TOD_TIER_S );
	// DR: SLASHER CAPS AT 5 (v14.11, user 2026-08-30: "Dmaage reduction on
	// slasher will go 5 levels now instead of 10" — half of the slasher
	// tone-down, with SPRINT ARMOR leaving the class below). This RE-PURPOSES
	// the bonus_class/bonus_max pair as a per-class OVERRIDE rather than
	// strictly a bonus: domain_max() just returns bonus_max for the named
	// class and has never required it to be higher (SCAVENGER uses it upward,
	// this uses it downward). Every consumer reads through
	// domain_max(player,d) — audited 2026-08-30: make_option, roll_options,
	// both guarantee paths, tier_up's sync, refresh_upgrade_list, the spire
	// grant and player_has_domains_left — so a slasher's deals, clamps,
	// redeals and pause menu all see 5 while everyone else sees 10.
	add_domain( "dr",         "DMG REDUCTION", "-5% damage taken / Lv",             10, undefined, TOD_TIER_S, "slasher", 5 );
	add_domain( "bounty",     "BOUNTY",      "+5% money per kill / Lv",             10, undefined, TOD_TIER_B );
	add_domain( "luck",       "LUCK",        "+10% luck gain rate / Lv",             5, undefined, TOD_TIER_S );
	// -- SKIRMISHER + SLASHER --
	// Move speed and nothing else since 2026-08-26 — the Lv5 TIRELESS rider was
	// removed (see the block comment where TOD_UPG_TIRELESS_SECS used to live).
	// Both classes that roll SPRINT now get exactly the same thing from it.
	add_domain( "sprint",     "SPRINT",      "+5% speed / Lv",                      10, array( "skirmisher", "slasher" ), TOD_TIER_A );
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
	add_domain( "sprintarmor", "SPRINT ARMOR", "-5% damage taken while sprinting / Lv", 5, array( "skirmisher" ), TOD_TIER_A );
	// -- ASSAULT signatures --
	add_domain( "headshot",   "HEADSHOT",    "+4% headshot damage / Lv",            10, array( "assault" ), TOD_TIER_A );   // v9.45 nerf 4%->3%; RESTORED to 4% 2026-08-26 (user: assault buff)
	// MAG SIZE = REAL twin variants now (user 2026-08-20: "no bottomless —
	// directly impact the gun's mag size"); 3 levels by the gun-data rule.
	// CLASS KEYS widened to the SKIRMISHER (review 2026-08-22): domain_available
	// is an AND of gun_keys and class_keys, so "assault"-only left the MP7's
	// m-ladder (T3 skirmisher) unreachable. gun_keys (set below) is what keeps
	// it off the MAC-10/MP5 — every ASSAULT gun carries an m-ladder now (user
	// 2026-08-23), only the skirmisher half is partial.
	add_domain( "magsize",    "MAG SIZE",    "real mag +30/+60/+90%",                3, array( "assault" ), TOD_TIER_A );   // v9.44: skirmisher dropped (user: "Magsize we can remove from class")
	// GIANT SLAYER (v9.45, user 2026-08-23) — the assault class's answer to the
	// two things it cannot out-DPS with headshots: the Panzer and the Rogue
	// Protector wave. +4%/Lv against anything carrying the boss/elite triad,
	// five levels, so a maxed card is +20% on the only enemies with real HP.
	// Tier A, not S: it is worth nothing at all on the horde, which is the
	// literal definition of the A band ("strong but conditional").
	// Applied in BOTH boss-damage lanes — see boss_damage_bonus().
	add_domain( "bossdmg",    "GIANT SLAYER", "+4% damage to bosses and elites / Lv",  5, array( "assault" ), TOD_TIER_A );   // 3% -> 4% 2026-08-26 (user: assault buff)
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
	add_domain( "backarmor",  "BACK ARMOR",  "-10% damage taken from behind / Lv",     3, array( "heavy" ), TOD_TIER_A );
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
	// 2026-08-26 rate (second buff): ONE round per 5 kills at Lv1, one kill fewer
	// per level to Lv5 = every kill, then the assault-only Lv6 CAPSTONE pays 3
	// rounds per 2 kills. See scav_kills_needed/scav_rounds_paid — and note the
	// payout is CLASS PRIMARY ONLY since the same pass; a sidearm kill pays
	// nothing and does not even advance the counter.
	add_domain( "reserve",    "SCAVENGER",   "primary kills: 1 round per 5, 1 fewer / Lv; Lv6 3 per 2", 5, array( "skirmisher", "assault", "heavy" ), TOD_TIER_B, "assault", 6 );
	// -- HEAVY signatures --
	// MOBILITY max 10 -> 5 (v14.11, user 2026-08-30: "Mobility will only go to
	// 5 tiers on Heavy"). Card text is LINEAR (+5%/Lv) so no re-bake — the
	// domain-retune checklist's safe case. Ceiling falls 0.75 x 1.50 = 1.125
	// to 0.75 x 1.25 = 0.9375, which makes the heavy the slowest CEILING in
	// the map (below the assault's 1.125 FORCED MARCH cap) — the intended
	// trade for VITALITY/RECOVERY below: the heavy tanks, it does not run.
	add_domain( "mobility",   "MOBILITY",    "+5% move speed / Lv",                  5, array( "heavy" ), TOD_TIER_A );
	add_domain( "bulletfeed", "BULLET FEED", "reserve trickles into the mag: 1.0s -> 0.2s / round", 10, array( "heavy" ), TOD_TIER_B );
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
	add_domain( "vitality",   "VITALITY",    "+10 max health / Lv",                  5, array( "heavy" ), TOD_TIER_S );   // v14.11 — id 38; scope "class" set below
	add_domain( "recovery",   "RECOVERY",    "health regen starts 10% sooner / Lv",  3, array( "heavy" ), TOD_TIER_A );   // v14.11 — id 39; see the define block for the emulation contract
	// PENETRATION (user 2026-08-21): REAL twin — walks the Stoner's
	// penetrateType small -> medium -> large. 2 levels by the gun-data rule.
	// HEAVY-ONLY AGAIN 2026-08-23: the AK-47 traded its p-ladder for r+m so the
	// whole ASSAULT class could roll RECOIL and MAG SIZE (see set_guns below).
	add_domain( "penetration", "PENETRATION", "shoot through more: small > medium > large", 2, array( "heavy" ), TOD_TIER_A );
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
	add_domain( "leech",      "LEECH",       "blade kills heal you (+1 stage)",      5, array( "slasher" ), TOD_TIER_A );
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
	add_domain( "firerate",   "FIRE RATE",   "truly fires faster (-8% fire time / Lv)",   3, array( "skirmisher" ), TOD_TIER_A );
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
	add_domain( "recoil",     "RECOIL",      "kick reduced -10/-20%",                     2, array( "assault" ), TOD_TIER_B );
	// LOG-SCALED (v10.13). The swing-speed ladder lives in the GENERATOR
	// (tools/gen_tod_twins.js KNIFE_STEP, now 1/.90/.84/.80/.77/.74), so the
	// numbers here are display only — keep them in step with that table or the
	// card lies. Pause-menu actuals: tod_upgrade.lua DETAIL[18] (10/16/20/23/26%).
	add_domain( "knifespeed", "KNIFE SPEED", "faster blade swing (+1 stage)",             5, array( "slasher" ), TOD_TIER_A );
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
	// v14.11 (user 2026-08-30): the card gained a DAMAGE half — same 20/35/50
	// ladder, same "moving" test, applied in unique_damage_mult. One card, one
	// condition, two payouts. Still tier B: it shares the ammo-economy band's
	// weight even though the damage half nudges it toward A — the user set the
	// rates, the band stays until they say otherwise. Card art re-bake PENDING
	// ("FREE SHOTS ON THE MOVE" is now half the story — see the v14.11 art
	// prompt doc); the desc + Lua rows carry the full text meanwhile.
	add_domain( "runandgun",  "RUN AND GUN", "moving: 20/35/50% free shots, +20/35/50% damage", 3, array( "skirmisher" ), TOD_TIER_B );
	// ---- CLASS TIER UNIQUES (docs/25 §9; ids 25..31 in _tod_upgrade_ui::domain_id
	//      + tod_upgrade.lua DOMAIN). Each is bound to ONE tier gun by gun_keys
	//      (set below) and resets on a tier-up like every gun domain. All
	//      script-side — zero weapon assets. Effects: unique_damage_mult /
	//      unique_on_hit (damage chain), on_class_gun_kill (kills),
	//      adren_bonus (move speed); inputs: _tod_uniques.gsc watchers.
	add_domain( "adrenaline", "ADRENALINE",       "kills grant a burst of speed: +4/+6/+8% per stack (x3, 4s)",          3, array( "skirmisher" ), TOD_TIER_A );
	// OVERDRIVE MOVED skirmisher/MP7 -> heavy/DEATH MACHINE (user 2026-08-23:
	// "overdrive should be an upgrade of the death machine. Remove meat grinder
	// and replace with overdrive"). OVERDRIVE and MEAT GRINDER were always the
	// same mechanic — "keep the trigger down, hit harder" — so the roster
	// carried a duplicate; the minigun is the natural home for it and the MP7
	// now needs an identity of its own.
	// This is also a real HEAVY NERF, which is the point: MEAT GRINDER capped at
	// +100% and a 150-round belt reached that cap trivially, so the heavy ran a
	// near-permanent x2 on top of the (now removed) ECHO ROUNDS x2. OVERDRIVE
	// tops out at +60%.
	add_domain( "overdrive",  "OVERDRIVE",        "sustained fire hits harder: +5/+8/+12% per 10 rounds (x5)",           3, array( "heavy" ), TOD_TIER_S );
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
	// KILL RELOAD: TIER S -> B (user 2026-08-23: "kill reload is B or A tier").
	// B is the right one of the two they offered. The v9.43 rework left it an
	// AMMO-ECONOMY card — a magazine topped up from your own reserve every 100th
	// / 75th / 50th kill, which creates no ammo and, by that build's arithmetic,
	// never outruns consumption at any level or round. That is exactly the band
	// SCAVENGER, BULLET FEED and RUN AND GUN sit in. It kept its S weighting
	// only because it was S when it WAS game-defining, before the rework.
	// Effect of the move: draw weight 20 -> 100 (offered 5x as often) and its
	// SUPER/ULTIMATE slice stops being halved (tier_rarity_factor 0.5 -> 1.0).
	add_domain( "killreload", "KILL RELOAD",      "every 55th/40th/30th kill refills your magazine from reserve",       3, array( "assault" ),    TOD_TIER_B );
	// IMPACT ROUNDS v9.45 (user 2026-08-23): TEN levels at 3%/Lv, so the ramp is
	// 3/6/9...30% instead of 10/20/30%. Same ceiling, ten times the climb.
	add_domain( "impact",     "IMPACT ROUNDS",    "3% of hits burst nearby zombies for 40% of the hit, per level",      10, array( "assault" ),    TOD_TIER_S );
	add_domain( "suppress",   "SUPPRESSING FIRE", "hits slow the horde 12/24/36% for 1.5s",                              3, array( "heavy" ),      TOD_TIER_A );
	// MEAT GRINDER REMOVED 2026-08-23 — superseded by OVERDRIVE on the same gun.
	// Was: add_domain( "grinder", "MEAT GRINDER",
	//        "keep firing, hit harder: +2/+3/+4% per 5 rounds, up to +50/75/100%",
	//        3, array( "heavy" ), TOD_TIER_S );
	// As with "echo", the key stays in domain_id() and in the Lua DOMAIN table
	// on purpose — those are key-keyed maps, so leaving the entries costs
	// nothing and keeps every other domain's id stable. Dropping the add_domain
	// is what removes it from the pool.
	add_domain( "drawcut",    "DRAW CUT",         "swings within 0.4s of a sprint deal +50/+100/+150%",                  3, array( "slasher" ),    TOD_TIER_S );
	// FORCED MARCH — the AK-47's unique (user 2026-08-24: "AK 47 will need a
	// speed boost. The only AR that gets a speed upgrade and it only goes 3
	// levels"). Assault had NO speed domain at all: SPRINT is skirmisher +
	// slasher, MOBILITY is heavy. Gun-bound to t9_ak47 below, so it is the
	// assault's T3 reward and not a class-wide one — and 3 levels at the shared
	// +5%/Lv caps it at +15%, taking the assault from 0.9 to 1.035: just past the
	// skirmisher's BASE, still short of a skirmisher who has spent anything on
	// SPRINT. It rides the SAME lane as SPRINT/MOBILITY in apply_move_speed()
	// rather than inventing a second speed multiplier — one owner for move speed.
	add_domain( "march",      "FORCED MARCH",     "+5% move speed / Lv",                                                 5, array( "assault" ),    TOD_TIER_A );   // max 3 -> 5 (user 2026-08-29); card text is LINEAR so no re-bake needed (domain-retune checklist), pips clamp at 3 by design

	// ---- CLASS TIERS (docs/25 §2.3, §3 — user 2026-08-22) ------------------
	// SCOPE: "gun" (default) = reset to 0 when a TIER card promotes the class;
	// "class" = survives. User rule: "almost no perks will [persist] but damage
	// resistance, luck, maybe only those two" — applied strictly (the BODY
	// domains sprint/mobility/regen/sprintfire reset too, user 2026-08-22 #1).
	set_scope( "dr",   "class" );
	set_scope( "luck", "class" );
	set_scope( "sprintarmor", "class" );   // damage resistance — persists like DR (v9.28)
	set_scope( "backarmor",   "class" );   // damage resistance — persists like DR (v9.45)
	// SKIRMISHER BUFF, 2026-08-27 (user: "buff skrimisher so that sprint doesnt
	// reset after class tier and also shooting while running doesnt reset").
	// This REVERSES the 2022-08-22 #1 call recorded in the comment above for two
	// of the four body domains it named.
	//
	// WHY THESE TWO AND NOT ALL THE BODY DOMAINS: neither describes the GUN. A
	// tier-up hands you a new weapon, so everything about that weapon reasonably
	// starts over — but how fast the PLAYER runs, and whether the PLAYER can
	// fire on the move, are facts about the body carrying the gun. SPRINT FIRE
	// is the sharper case: it is a binary engine specialty (max 1) and it is the
	// skirmisher's whole identity, so losing it to a promotion cost the class its
	// character at the exact moment the promotion was supposed to reward it.
	//
	// SPRINT IS SHARED WITH THE SLASHER and so this buffs that class too. That is
	// intended rather than tolerated: the argument above is about bodies, not
	// about skirmishers, and it applies identically to a slasher. SPRINT FIRE is
	// skirmisher-only, so that half lands where it was aimed.
	//
	// NOT CHANGED, and worth stating so the asymmetry is a decision and not an
	// oversight: MOBILITY (heavy) and FORCED MARCH (assault) ride the SAME
	// move-speed lane in apply_move_speed() and are still gun-scoped. FORCED
	// MARCH genuinely belongs to the gun (it is AK-47-bound, so a promotion off
	// the AK is meant to take it). MOBILITY has the same body argument as SPRINT
	// and is the obvious next candidate if the heavy ever needs the same buff.
	//
	// KEEP tod_upgrade.lua's TIER_SAFE IN STEP — that table drives the pause
	// menu's "this will be destroyed" badge, and a domain that survives here
	// while still being badged there is a UI that lies.
	set_scope( "sprint",     "class" );
	set_scope( "sprintfire", "class" );
	// VITALITY (v14.11): "player keeps it for whole game" — the user's own
	// words, so this is the FIRST non-defensive, non-luck domain to persist
	// through a promotion. The body argument that carried SPRINT applies at
	// least as strongly to bone and muscle. RECOVERY is deliberately NOT
	// here: the user gave persistence to vitality alone, so recovery resets
	// on a tier-up like MOBILITY does — flip it to "class" here if that ever
	// reads wrong in play (the body argument covers it too).
	set_scope( "vitality",   "class" );
	// HEADSHOT + SCAVENGER PERSIST FOR THE ASSAULT (v14.12, user: "stay even
	// between class tier upgrades"; v14.13 same night, user: "Scavenger
	// should only stay for assault"). v14.12 shipped scavenger's persistence
	// for every class that rolls it (scope was per-domain, the SPRINT
	// precedent); the correction adds the scope_class lane so persistence can
	// target ONE class. HEADSHOT needs no qualifier — it is assault-only by
	// class_keys, so plain scope "class" already lands exactly there.
	// SCAVENGER survives for the ASSAULT ALONE: a skirmisher or heavy taking
	// a tier card still loses it, exactly as before v14.12.
	// The pause badge is SERVER-COMPUTED now (sync_max packs the bit), so
	// tod_upgrade.lua's TIER_SAFE is only the fallback and needs no per-class
	// knowledge.
	set_scope( "headshot",   "class" );
	set_scope( "reserve",    "class", "assault" );
	// GUN_KEYS: a domain bound to specific gun STEMS — rollable only while the
	// player's current-tier gun is one of them. The twin ladders exist only on
	// the guns the generator built them for (a T2 SMG must never roll a dead
	// FIRE RATE card); THOR'S THUNDER is the STORMBREAKER's alone (the T3
	// slasher = the Leviathan port, stem "leviathan") — it leaves the knife's
	// pool now (user 2026-08-22 #5/#9). Add a stem here when a new tier gun
	// gets the same ladder (docs/25 §9 "reuse rule").
	// SMG CLASS UPDATE (user 2026-08-23, v9.44): FIRE RATE is the MAC-10's alone
	// (the MP5's f-ladder is retired in gen_tod_twins.js). HANDLING is every
	// SMG — all three carry an h-ladder now and no gun outside the class does,
	// so its class_keys ( "skirmisher" ) is the exact gate and it needs NO
	// set_guns list (the RECOIL precedent: one less list to keep in sync).
	set_guns( "firerate",    array( "t9_mac10" ) );
	// MAG SIZE: every ASSAULT gun carries an m-ladder now (user 2026-08-23:
	// "mag size should be for all assault guns not just krig"). gun_keys stays
	// only because of the SKIRMISHER half — the MP7 has an m-ladder but the
	// MAC-10 and MP5 do not (they spend their axis budget on f/h), so dropping
	// the list would offer a dead card on two guns.
	// MAG SIZE: v9.44 the MP7 lost its m-ladder with the skirmisher class, so
	// the three assault guns are the only m-guns and class_keys ( "assault" )
	// gates it exactly — the old set_guns list existed only to keep it off the
	// MAC-10/MP5 and is gone.
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
	set_guns( "penetration", array( "t9_stoner63", "t6_death_machine" ) );   // both p-ladder guns (the HK21 has no axes now)
	set_guns( "knifespeed",  array( "t9_me_knife_american", "t9_me_wakizashi", "leviathan" ) );   // every k-ladder blade
	set_guns( "thunder",     array( "leviathan" ) );
	// the uniques: one gun each (the tier ladders' T2/T3 guns)
	// v14.11 (user 2026-08-30): MOMENTUM is gone and SECOND WIND moves
	// MP7 -> MP5, so each skirmisher rung is back to ONE unique — ADRENALINE
	// on the MP7 (T3), SECOND WIND on the MP5 (T2), and the MAC-10 keeps its
	// f-ladder as the T1 identity. (History: 2026-08-24 swapped ADRENALINE to
	// the MP7 and narrowed MOMENTUM to the MP5; the MP7 carried two uniques
	// from then until this pass.)
	set_guns( "adrenaline", array( "t6_mp7" ) );            // was t9_mp5 (2026-08-24)
	set_guns( "overdrive",  array( "t6_death_machine" ) );   // moved off the MP7 2026-08-23
	set_guns( "secondwind", array( "t9_mp5" ) );            // MP5 since v14.11 (was t6_mp7)
	// KILL RELOAD + IMPACT ROUNDS: CLASS-WIDE, NOT GUN-BOUND (user 2026-08-23:
	// "impact rounds should be for all assault not just AK", "kill reload should
	// be for all assault not just krig"). Both effects are pure script
	// (unique_on_kill / unique_on_hit read the attacker level and the damage
	// weapon), so opening them costs nothing but the deleted set_guns lines —
	// class_keys array( "assault" ) on the add_domain is now the only gate.
	// They stay scope "gun", so a TIER card still resets them like every other
	// gun upgrade.
	set_guns( "suppress",   array( "t5_hk21" ) );
	// (grinder binding removed 2026-08-23 with the domain — the Death Machine
	// now carries OVERDRIVE instead.)
	set_guns( "drawcut",    array( "t9_me_wakizashi" ) );
	set_guns( "march",      array( "t9_ak47" ) );   // FORCED MARCH is the AK-47's alone (user 2026-08-24)
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
	d.scope = "gun";
	d.scope_class = undefined;   // v14.13 — scope "class" limited to ONE class (see set_scope)
	d.gun_keys = undefined;
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
	return mx;
}

function set_guns( key, stems )
{
	d = find_domain( key );
	if ( isdefined( d ) )
		d.gun_keys = stems;
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

// KILL RELOAD: how many kills buy one magazine refill at this level.
// 100 / 75 / 50 (user 2026-08-23: "lets make it unrealistic like 100 / 75 /
// 50"). Deliberately a LADDER OF RARITY, not of size — a proc always refills to
// FULL, so the level buys FREQUENCY. That is what makes the three levels
// distinguishable; the old 25/50/75% ladder was three ways to spell the same
// thing (see unique_on_kill).
//
// THESE NUMBERS ARE THE WHOLE FIX — do not tune them back down without redoing
// the arithmetic in unique_on_kill. At 50 kills per refill the card cannot
// remove reloading at ANY round number: even in the cheapest case a player can
// construct (one-round headshot kills) 50 kills costs 50 rounds and hands back
// at most one 33-round magazine, so the drain is guaranteed. Raising these is
// safe; lowering them re-opens the hole.
function killreload_kills_needed( lvl )
{
	if ( lvl >= 3 )
		return TOD_KILLRELOAD_KILLS_LV3;
	if ( lvl == 2 )
		return TOD_KILLRELOAD_KILLS_LV2;
	return TOD_KILLRELOAD_KILLS_LV1;
}

// The cap for THIS player (honours a domain's per-class bonus).
function domain_max( player, d )
{
	if ( isdefined( d.bonus_class ) && isdefined( d.bonus_max )
	  && isdefined( player.tod_class ) && player.tod_class == d.bonus_class )
		return d.bonus_max;
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
	self thread ensure_upgrade_list();

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
	want = TOD_UPG_BASE_HP + TOD_UPG_VITALITY_HP_PER_LVL * get_level( self, "vitality" );
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
		// (tireless_spawn_watch removed 2026-08-26 with TIRELESS itself.)
	}

	// move scale must be re-applied on every spawn (it resets)
	self apply_move_speed();
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
	// One speed lane for every domain that grants move speed: SPRINT
	// (skirmisher/slasher), MOBILITY (heavy) and FORCED MARCH (assault, AK-47).
	// They are per-class by construction — no player can hold two of them — so
	// summing is safe and each level is worth TOD_UPG_SPEED_PER_LVL.
	lvl = get_level( self, "sprint" ) + get_level( self, "mobility" ) + get_level( self, "march" );
	scale = self class_speed_base() * ( 1.0 + lvl * TOD_UPG_SPEED_PER_LVL + self adren_bonus() );
	// (the boss zap slow was removed 2026-08-20 — no player stuns)
	self SetMoveSpeedScale( scale );
}

// PUBLIC — SPRINT ARMOR (v9.28): the incoming-damage multiplier for `player`
// right now. 1.0 unless the player owns the domain AND the engine says they
// are sprinting at this instant (IsSprinting — the server-side builtin). Both
// of _tod_bosses' player-damage lanes (boss_player_damage for the normal
// chain, apply_player_mitigations for Panzer melee) multiply by this right
// after DMG REDUCTION. Floored so a future level bump can never reach zero.
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

// PUBLIC — GIANT SLAYER (domain 35, v9.45): the ADDITIVE damage bonus this
// attacker gets against this victim. 0 unless the victim carries the boss/elite
// triad AND the attacker owns the domain, so every call site can add it
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
	if ( !is_boss_or_elite( victim ) )
		return 0;
	return get_level( attacker, "bossdmg" ) * TOD_UPG_BOSSDMG_PER_LVL;
}

// PUBLIC — MELEE vs the boss/elite triad (user 2026-08-24). The MULTIPLIER a
// melee hit on `victim` pays: TOD_MELEE_BOSS_MULT against a Panzer, a Rogue
// Protector or a Reaver, 1.0 against anything else and 1.0 for any non-melee
// hit. See the #define for why melee needed its own lane against bosses.
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
function melee_boss_mult( victim, is_melee )
{
	if ( !IS_TRUE( is_melee ) )
		return 1.0;
	if ( !is_boss_or_elite( victim ) )
		return 1.0;
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

	m = 1.0 - TOD_UPG_BACK_ARMOR_PER_LVL * lvl;
	if ( m < 0.05 )
		m = 0.05;
	return m;
}

// ADRENALINE (MP5 unique): the live speed bonus — stacks x per-stack %, only
// inside the 4s window the last kill re-armed. The 1s body tick re-applies
// move speed, so an expired burst fades within a second. self = player.
function adren_bonus()
{
	lvl = get_level( self, "adrenaline" );
	if ( lvl <= 0 || !isdefined( self.tod_adren_until ) || !isdefined( self.tod_adren_stacks ) )
		return 0;
	if ( GetTime() > self.tod_adren_until )
		return 0;
	return self.tod_adren_stacks * ( TOD_ADREN_PCT_BASE + TOD_ADREN_PCT_PER_LV * ( lvl - 1 ) );
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
// Current spread, slowest to fastest: HEAVY 0.75 · ASSAULT 0.9 ·
// SKIRMISHER 1.0 · SLASHER 1.1. SPRINT/MOBILITY multiply on top of this.
function class_speed_base()   // self = player
{
	c = tod_classes::get_class( self );
	if ( !isdefined( c ) )
		return 1.0;   // classless (pre-draft)
	switch ( c.key )
	{
		case "heavy":      return 0.75;   // was 0.8
		case "assault":    return 0.9;    // 0.9 -> 0.85 -> 0.9 again (user 2026-08-23)
		case "skirmisher": return 1.0;
		case "slasher":    return 1.1;
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

		// BASE 150 HP + VITALITY maintain (v14.11: the floor is now
		// 150 + 10 x the heavy's VITALITY level). Jugg-aware exactly as
		// before: only ever RAISES a max below the floor, so an active jugg's
		// floor+bonus is never touched; no free healing. This floor is also
		// what re-lands a vitality level after stock's jugg-loss restore or
		// spawn reboot clobbers the additive apply (see apply_upgrade).
		want = TOD_UPG_BASE_HP + TOD_UPG_VITALITY_HP_PER_LVL * get_level( self, "vitality" );
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

		// SHOOT WHILE SPRINTING — the SPRINT FIRE upgrade (user 2026-08-21:
		// "fire while sprinting is an upgrade ... it's not just part of the
		// class"). WAS a skirmisher innate keyed on c.key; now it must be
		// EARNED from a card, and any gun class can roll it.
		// The engine's Gung-Ho specialty (`specialty_sprintfire`, MP's perk;
		// util_shared::has_gung_ho_perk_purchased_and_equipped names it) lets
		// the held weapon fire mid-sprint with no sprint-out. Script-side, no
		// twin: it is a player specialty, so it rides the same 1s re-assert as
		// staminup (perks are stripped on death/respawn). The unset branch
		// matters now — a player without the upgrade must never keep it.
		if ( get_level( self, "sprintfire" ) > 0 )
		{
			if ( !( self HasPerk( "specialty_sprintfire" ) ) )
				self SetPerk( "specialty_sprintfire" );
		}
		else if ( self HasPerk( "specialty_sprintfire" ) )
		{
			self UnsetPerk( "specialty_sprintfire" );
		}

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
					want = tod_classes::weapon_or_zm( tod_classes::variant_name( g, IS_TRUE( self.tod_pap_owned ), self twin_suffix() ) );
					if ( !isdefined( want ) || want == level.weaponNone )
						want = tod_classes::base_weapon( g );   // fall back to the level-0 form
					if ( isdefined( want ) && want != level.weaponNone )
					{
						self GiveWeapon( want );
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
				if ( iv < TOD_UPG_FEED_MIN_SECS )
					iv = TOD_UPG_FEED_MIN_SECS;

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

		if ( ( GetTime() - self.tod_last_dmg_ms ) < int( delay * ( 1.0 - TOD_UPG_RECOV_PCT_PER_LVL * lvl ) ) )
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
function twin_suffix()
{
	g = tod_classes::gun( self );
	if ( !isdefined( g ) )
		return "";
	if ( !isdefined( g.axes ) || g.axes.size == 0 )
		return "_b";
	s = "_";
	for ( i = 0; i < g.axes.size; i++ )
		s += g.axes[ i ].letter + get_level( self, g.axes[ i ].domain );
	return s;
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
	return undefined;
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

	suffix = self twin_suffix();

	weapons = self GetWeaponsListPrimaries();
	foreach ( w in weapons )
	{
		if ( !isdefined( w ) || !IsSubStr( w.name, g.stem ) )
			continue;

		// PaP suffix differs per gun family ("_up" skye / "_upgraded" ballistic).
		// tod_pap_owned is the FREE-PaP DROP's latch (_tod_powerups::grab_pap):
		// once set, reconcile pulls the class gun to its _up form on the next
		// tick. Routing PaP through here instead of the stock upgrade path is
		// deliberate — the stock path worked on the PISTOL but not the class
		// guns (user 2026-08-21), and this builds a variant name we KNOW is
		// generated, then reuses the proven swap order below.
		is_up = ( IsSubStr( w.name, g.up_suffix ) || IS_TRUE( self.tod_pap_owned ) );
		want_name = tod_classes::variant_name( g, is_up, suffix );
		if ( w.name == want_name )
			return;

		want = tod_classes::weapon_or_zm( want_name );
		if ( !isdefined( want ) )
			return;   // variant not linked — never take the player's gun

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
		crossing = ( is_up && !IsSubStr( w.name, g.up_suffix ) );
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
function swap_primary( w, want, fresh )
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

	self GiveWeapon( want );
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
	self TakeWeapon( w );
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
	// CLASS TIER row (id 24): pips = the tier, shown from tier 2 on (tier 1 is
	// the baseline, not an upgrade). Same int-only lane.
	t = tod_classes::tier( self );
	if ( t >= 2 )
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
		// DEV: an upgrade every round from round 2. SHIP: every 4th round.
		if ( IS_TRUE( level.tod_dev ) )
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
		// DOWNED AND DEAD PLAYERS ARE NOT PARTICIPANTS (co-op audit 2026-08-23).
		// The filter used to be domains-left only, so a player in laststand — or
		// a dead one sitting in spectate — was dealt cards nobody could pick, and
		// run_upgrade_event held the world paused waiting on them for the full
		// TOD_UPG_CHOICE_TIMEOUT. Two ways that bites:
		//   * the downed player IS the one being waited on, and stock's bleedout
		//     loop does not pause with the world, so the freeze he is stuck in is
		//     the freeze running his own clock out;
		//   * a tabbed-out dead teammate pins the whole lobby on EVERY event for
		//     the rest of the run.
		// A player who is down or dead simply sits this event out. menu_freeze
		// already refuses to freeze a laststand player, so this is the other half
		// of that same rule applied one level up.
		if ( !isalive( p ) || p laststand::player_is_in_laststand() )
			continue;
		p.tod_tier_deal_pre = undefined;
		if ( player_has_domains_left( p ) )
			participants[ participants.size ] = p;
		else if ( tier_card_eligible( p ) && RandomInt( 100 ) < tier_card_pct() )
		{
			// CLASS TIERS: a MAXED player is only here for the tier chance — it is
			// rolled NOW (consumed by roll_options) so a miss never pauses the
			// world for an empty deal.
			p.tod_tier_deal_pre = true;
			participants[ participants.size ] = p;
		}
		else if ( !IS_TRUE( p.tod_upg_maxed_told ) )
		{
			p.tod_upg_maxed_told = true;   // tell them ONCE, not every round
			// (on-screen text removed 2026-08-20 — user: no floaty text)
		}
	}
	if ( participants.size == 0 )
		return;

	set_world_pause( true );

	// The round event OWNS the shared card UI: any in-flight PERSONAL STATION
	// pick dies on this notify (synchronous — its thread is dead before our
	// per-player flows below touch the fields) and re-presents after we end.
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
	while ( level.tod_upg_pending > 0 && waited < ( TOD_UPG_CHOICE_TIMEOUT + 5 ) )
	{
		wait 0.25;
		waited += 0.25;

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
		if ( p laststand::player_is_in_laststand() && isdefined( p.bleedout_time ) )
			p.bleedout_time += waited;
		// clear the waiting line (the display thread may have died mid-loop)
		if ( isdefined( p.tod_upg_wait_elem ) )
		{
			p.tod_upg_wait_elem Destroy();
			p.tod_upg_wait_elem = undefined;
		}
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

	set_world_pause( false );
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

	self menu_freeze( true );
	choice = self tod_upgrade_ui::present_choice( opts, TOD_UPG_CHOICE_TIMEOUT );
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

// One small line on every player's screen: who is still deciding. Server
// hudelems + SetText is safe here — the distinct strings are subsets of at
// most 4 player names (bounded, nowhere near the 2048 string-cache cap).
function waiting_display( participants )
{
	level endon( "end_game" );
	level endon( "tod_upg_event_over" );

	for ( ;; )
	{
		wait 0.3;

		names = "";
		n = 0;
		foreach ( p in participants )
		{
			if ( !isdefined( p ) || IS_TRUE( p.tod_upg_done ) )
				continue;
			if ( n > 0 )
				names += ", ";
			names += p.name;
			n++;
		}
		if ( n == 0 )
			return;

		text = "^3CHOOSING:^7 " + names;
		players = GetPlayers();
		foreach ( viewer in players )
		{
			if ( !isdefined( viewer ) )
				continue;
			if ( !isdefined( viewer.tod_upg_wait_elem ) )
			{
				viewer.tod_upg_wait_elem = viewer hud::createFontString( "objective", 1.1 );
				if ( isdefined( viewer.tod_upg_wait_elem ) )
					// y 96 -> 74 (audit 2026-08-25). The baked UPGRADE AVAILABLE banner
					// occupies 122..215 of the 720-tall safe area, so at 96 this line
					// landed INSIDE the artwork and read as part of it. There is no gap
					// below the banner either — the cards start at 230 — so it moves
					// ABOVE instead, ending just clear of the banner top.
					viewer.tod_upg_wait_elem hud::setPoint( "TOP", "TOP", 0, 74 );
			}
			if ( isdefined( viewer.tod_upg_wait_elem ) &&
			     ( !isdefined( viewer.tod_upg_wait_text ) || viewer.tod_upg_wait_text != text ) )
			{
				viewer.tod_upg_wait_elem SetText( text );
				viewer.tod_upg_wait_text = text;
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
	pool = [];
	for ( i = 0; i < level.tod_domains.size; i++ )
	{
		d = level.tod_domains[ i ];
		if ( !domain_available( player, d ) )
			continue;
		if ( get_level( player, d.key ) < domain_max( player, d ) )
			pool[ pool.size ] = d;
	}
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
		tier_deal = ( tier_card_eligible( player ) && RandomInt( 100 ) < tier_card_pct() );

	if ( pool.size == 0 )
	{
		if ( !tier_deal )
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
		if ( !isdefined( o ) || o.domain == "tier" )
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
		if ( !isdefined( o ) || o.domain == "tier" )
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
	// the game even on a full luck bar: 15% * 0.5 = 7.5% at bar 100.
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
	if ( IS_TRUE( level.tod_dev ) )
		return 100;   // DEV: every deal carries it — the promotion flow is testable in one session
	return TOD_TIER_CARD_PCT;
}

// Can this player be dealt a TIER card right now? ALL of: below the top tier,
// a next gun registered AND its level-0 asset linked (never deal a card that
// cannot pay out), the CURRENT class gun PaP'd (by name, or the free-PaP latch
// that reconcile turns into the _up form within 1s), and no powerup gun in
// hand (its restore would fight the swap).
function tier_card_eligible( player )
{
	if ( !isdefined( player ) || !isplayer( player ) || !isdefined( player.tod_class ) )
		return false;
	if ( tod_classes::tier( player ) >= tod_classes::tier_max() )
		return false;
	next = tod_classes::next_gun( player );
	if ( !isdefined( next ) )
		return false;
	if ( !isdefined( tod_classes::base_weapon( next ) ) )
		return false;
	g = tod_classes::gun( player );
	w = player class_primary_in_inventory();
	if ( !isdefined( g ) || !isdefined( w ) )
		return false;
	if ( !IsSubStr( w.name, g.up_suffix ) && !IS_TRUE( player.tod_pap_owned ) )
		return false;
	if ( isdefined( player.zombie_vars ) && IS_TRUE( player.zombie_vars[ "zombie_powerup_minigun_on" ] ) )
		return false;
	return true;
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
	if ( want != old )
	{
		ok = player swap_primary( old, want, true );
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
	player PlayLocalSound( "tod_ultimate_sting" );   // tod_tier_sting once the alias exists
	return true;
}

// self = player. Un-apply the live effects the reset levels were driving —
// the 1s body loop only ever SETS most of them.
function reset_gun_state()
{
	self.tod_thor_next_ms = undefined;
	self.tod_feed_t = 0;              // BULLET FEED debt
	self.tod_bounty_bank = 0;
	self.tod_scav_kills = 0;          // SCAVENGER kill counter (v9.10)
	self.tod_killreload_kills = 0;    // KILL RELOAD kill counter (v9.43)
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
		hp_add = TOD_UPG_VITALITY_HP_PER_LVL * ( lv - cur );
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
// ---------------------------------------------------------------------------

function set_world_pause( on )
{
	if ( on )
	{
		level.tod_upgrade_pause = true;
		if ( !( level flag::exists( "world_is_paused" ) ) )
			level flag::init( "world_is_paused" );
		level flag::set( "world_is_paused" );
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
		}
		else
		{
			z.tod_frozen = undefined;
			z.ignoreall = false;
			// anim rate restored by _tod_zombie_speed's keep-alive sweep
		}
	}

	if ( !on )
	{
		if ( level flag::exists( "world_is_paused" ) )
			level flag::clear( "world_is_paused" );
		level.tod_upgrade_pause = false;
	}
}

// ---------------------------------------------------------------------------
// DAMAGE + FIRE RATE — the actor damage chain. self = the zombie victim.
// Return -1 = untouched (lets later callbacks run); returning a value is the
// final damage (legitimate here — we ARE the modifier).
// ---------------------------------------------------------------------------

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

	// INSTA-KILL 3x window (user 2026-08-20): all players deal 3x while the
	// map's insta-kill is active (level.tod_dmg_mult; default 1) — applied to
	// the FINAL of every path so it lifts class, non-class, and knife alike.
	dmult = ( isdefined( level.tod_dmg_mult ) ? level.tod_dmg_mult : 1 );

	// A cleave splash re-enters this callback — consume the mark, pass through
	// untouched (the splash already carries the final damage).
	if ( IS_TRUE( self.tod_cleave_hit ) )
	{
		self.tod_cleave_hit = undefined;
		return -1;
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
		attacker tod_upgrade_ui::push_dmg_num( kill, headshot );
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
	if ( headshot )
		mult += hs_lvl * TOD_UPG_HS_PER_LVL;
	// (ECHO ROUNDS removed 2026-08-23 — see the note at its old add_domain.)

	// CLASS TIER UNIQUES (docs/25 §9): OVERDRIVE / MEAT GRINDER (sustained
	// fire) and DRAW CUT (a swing out of a sprint). gun_keys already bind each
	// domain to its gun, so a level > 0 here means the right gun is in hand.
	is_melee = ( isdefined( meansofdeath ) && IsSubStr( meansofdeath, "MELEE" ) );
	umult = unique_damage_mult( attacker, is_melee );
	mult += umult;

	// GIANT SLAYER (domain 35, v9.45; 4%/Lv since 2026-08-26): +4%/Lv, and ONLY against the boss/elite
	// triad. This is the lane that fires for the Panzer (his actor_damage_func
	// wrap runs after us and re-scales by hit-location ratios, so a bonus
	// applied here survives it) and for the Reaver. The Rogue Protector's own
	// aiOverrideDamage fallback carries the same call — see rp_damage_feed.
	bmult = boss_damage_bonus( attacker, self );
	mult += bmult;

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
	final = int( swing * melee_boss_mult( self, is_melee ) );

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
	// level.tod_sprinter_bullet_frac) — the KB cycle rule.
	// BULLETS ONLY, deliberately: melee, explosives and the blades stay full —
	// they are the counter-play, exactly map 1's Shielded contract. Floor at 1
	// so armor can never make a zombie chip-proof.
	// MOD_HEAD_SHOT is a BULLET for armor purposes: the engine substitutes it
	// for the bullet MOD on head hits, and matching "BULLET" alone would hand
	// headshot builds a silent full bypass of the whole armor (the exact shape
	// of leak the ELEMENTAL POP gate accepts on purpose — this one must not).
	b_sprint_armor = false;
	if ( IS_TRUE( self.tod_is_sprinter ) && !is_melee
	     && isdefined( meansofdeath )
	     && ( IsSubStr( meansofdeath, "BULLET" ) || meansofdeath == "MOD_HEAD_SHOT" ) )
	{
		b_sprint_armor = true;
		// Fallback tracks TOD_SPRINT_BULLET_FRAC (1/3 since the 2026-08-29
		// same-day retune; was 1/4) — the level field is the live source, this
		// only fires if the sprinter module somehow never init'd.
		frac = ( isdefined( level.tod_sprinter_bullet_frac ) ? level.tod_sprinter_bullet_frac : 0.3333 );
		final = int( final * frac );
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
	attacker tod_upgrade_ui::push_dmg_num( final, headshot, b_sprint_armor );

	// SUPPRESSING FIRE + IMPACT ROUNDS ride bullet hits only (never the cleave
	// re-entry above, never melee).
	if ( !is_melee )
		self unique_on_hit( attacker, final );

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
			if ( extra > 2 )
				extra = 2;
			if ( extra > 0 )
				self thread cleave_splash( attacker, swing, extra );   // `swing`, not `final` — see the two-value note above
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
				cd = ( inf ? 0 : thor_cooldown_ms( thor ) );
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
	if ( dmult == 1 && balance == 1.0 && dmg_lvl == 0 && ( hs_lvl == 0 || !headshot ) && umult == 0 && bmult == 0
	  && melee_boss_mult( self, is_melee ) == 1.0 )
		return -1;   // nothing modified — stay silent in the chain
	return final;
}

// ---------------------------------------------------------------------------
// CLASS TIER UNIQUES — the effects (docs/25 §9). Inputs: _tod_uniques.gsc
// keeps tod_fire_streak / tod_fire_last_ms / tod_sprint_end_ms on the player.
// ---------------------------------------------------------------------------

function overdrive_pct( lvl )   // per stack
{
	if ( lvl >= 3 ) return 0.12;
	if ( lvl == 2 ) return 0.08;
	return 0.05;
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
	// RUN AND GUN's damage half (v14.11): flat +20/35/50% on bullets fired
	// while MOVING. Computed BEFORE the fire-streak gate below on purpose —
	// it has nothing to do with holding the trigger, so a lapsed streak must
	// not suppress it (the rule MOMENTUM established in this exact spot).
	// The movement test is a LOCKSTEP MIRROR of _tod_runandgun::is_running()
	// — IsSprinting() OR 2D speed >= the shared 120 floor — so the ammo half
	// and this half fire on the same trigger pull, always together. Applies
	// to any weapon (the ammo half was widened the same way 2026-08-23) and,
	// like MOMENTUM before it, to bosses too.
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
			add += ( TOD_UPG_RNG_DMG_BASE + TOD_UPG_RNG_DMG_PER_LV * ( lvl - 1 ) );
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
		add += stacks * overdrive_pct( lvl );
	}
	// (MEAT GRINDER removed 2026-08-23 — the Death Machine now carries
	// OVERDRIVE above, which is the same "hold the trigger" mechanic with a
	// +60% ceiling instead of +100%.)
	return add;
}

// self = the zombie that took a BULLET hit from its killer-to-be. Bosses are
// exempt from both (the map's boss-damage doctrine + no boss slows).
function unique_on_hit( attacker, final )
{
	if ( !isdefined( self ) || !isalive( self ) )
		return;
	if ( IS_TRUE( self.is_boss ) || IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) )
		return;
	// SUPPRESSING FIRE (HK21): a timed playback-rate slow (_tod_zombie_speed owns the rate)
	lvl = get_level( attacker, "suppress" );
	if ( lvl > 0 )
		self tod_zombie_speed::slow( 1.0 - ( TOD_SUPPRESS_BASE + TOD_SUPPRESS_PER_LV * ( lvl - 1 ) ), TOD_SUPPRESS_MS );
	// IMPACT ROUNDS (AK-47): the hit bursts into nearby zombies
	lvl = get_level( attacker, "impact" );
	if ( lvl > 0 && RandomInt( 100 ) < TOD_IMPACT_PCT_PER_LV * lvl )
		self thread impact_splash( attacker, int( final * TOD_IMPACT_FRAC ) );
}

// self = the burst centre (the zombie hit). The cleave mark makes the damage
// callback pass each splash hit through untouched (no recursion, no echo).
function impact_splash( attacker, dmg )
{
	if ( dmg < 1 || !isdefined( attacker ) )
		return;
	team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
	zombies = GetAITeamArray( team );
	r2 = TOD_IMPACT_RADIUS * TOD_IMPACT_RADIUS;
	hit = 0;
	foreach ( z in zombies )
	{
		if ( hit >= TOD_IMPACT_MAX_VICTIMS )
			break;
		if ( !isdefined( z ) || z == self || !isalive( z ) )
			continue;
		if ( IS_TRUE( z.is_boss ) || IS_TRUE( z.acc_is_boss ) || IS_TRUE( z.acc_is_mini_boss ) )
			continue;
		if ( DistanceSquared( z.origin, self.origin ) > r2 )
			continue;
		z.tod_cleave_hit = true;
		z DoDamage( dmg, z.origin, attacker );
		hit++;
	}
}

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
	// NOTE THIS IS NOW BELOW THE BASE: a Pack-a-Punched MR6 does LESS damage
	// than an un-packed one (2.16 vs 7.2). That is what the two nerfs
	// arithmetically produce and it is not a typo — but it does mean packing the
	// MR6 is now a downgrade, so if that reads wrong in play, this is the digit,
	// and the base 7.2 is the one to compare it against.
	if ( IsSubStr( n, "pistol_standard" ) )
	{
		if ( IsSubStr( n, "_upgraded" ) ) return 2.16;
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
	if ( IsSubStr( n, "t9_amp63" ) ) return 0.75;

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
function thor_cooldown_ms( lvl )
{
	cd = TOD_THOR_CD_MAX_MS - ( lvl - 1 ) * TOD_THOR_CD_STEP_MS;
	if ( cd < TOD_THOR_CD_MIN_MS )
		cd = TOD_THOR_CD_MIN_MS;
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
	r2     = radius * radius;
	cap    = TOD_THOR_MAX_HIT_BASE + ( lvl - 1 ) * TOD_THOR_MAX_HIT_PER_LV;
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
	self DoDamage( dmg, self.origin, attacker );
}

// self = the zombie that took the primary melee hit.
function cleave_splash( attacker, dmg, count )
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
		// MELEE vs BOSSES (user 2026-08-24). The tod_cleave_hit mark makes
		// upgrade_damage_cb pass this hit through UNTOUCHED, so the splash is
		// the only place that can scale it — without this a slasher could swing
		// at a normal zombie and cleave a Panzer standing next to it for the
		// full undivided swing. Per-victim, because one splash can land on a
		// boss and a normal zombie in the same swing.
		z DoDamage( int( dmg * melee_boss_mult( z, true ) ), z.origin, attacker );
		hit++;
	}
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
function bounty_kill_value( mod, hitloc )
{
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
function bounty_preview( attacker, weapon, mod, hitloc )
{
	if ( !isdefined( attacker ) || !IsPlayer( attacker ) )
		return 0;
	// ANY weapon, matching on_class_gun_kill since BOUNTY was widened — these
	// two run the same arithmetic and the header above says outright that the
	// HUD lies if they ever disagree.
	if ( !isdefined( weapon ) )
		return 0;

	lvl = get_level( attacker, "bounty" );
	if ( lvl <= 0 )
		return 0;

	bank = ( ( isdefined( attacker.tod_bounty_bank ) ) ? attacker.tod_bounty_bank : 0 );
	bank += bounty_kill_value( mod, hitloc ) * TOD_UPG_BOUNTY_PER_LVL * lvl;
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
	return 1.0 + get_level( player, "bounty" ) * TOD_UPG_BOUNTY_PER_LVL;
}

// SCAVENGER's ladder, split in two because the last rung changes shape rather
// than continuing the pattern (see TOD_SCAV_CAP_LVL). Both are pure functions of
// the level so the GSC payout and the LUI's DETAIL readout can never disagree
// about what a level is worth — keep tod_upgrade.lua's [8] val() in step.
//   Lv1 1/5   Lv2 1/4   Lv3 1/3   Lv4 1/2   Lv5 1/1   Lv6 3/2 (assault only)
function scav_kills_needed( lvl )
{
	if ( lvl >= TOD_SCAV_CAP_LVL )
		return TOD_SCAV_CAP_KILLS;
	need = TOD_SCAV_KILLS_LV1 - ( lvl - 1 );
	if ( need < TOD_SCAV_KILLS_MIN )
		need = TOD_SCAV_KILLS_MIN;
	return need;
}

function scav_rounds_paid( lvl )
{
	if ( lvl >= TOD_SCAV_CAP_LVL )
		return TOD_SCAV_CAP_ROUNDS;
	return 1;
}

// Every class-gun kill funnels through here: BOUNTY (shared), SCAVENGER
// (assault), LEECH (slasher). self = the dead zombie, attacker = the killer.
function on_class_gun_kill( attacker )
{
	if ( !isdefined( attacker ) || !IsPlayer( attacker ) )
		return;
	if ( !isdefined( self.damageweapon ) )
		return;
	// WIDENED TO EVERY WEAPON (user 2026-08-23: "lets widen as much as we can
	// without twins"). This hook used to return early unless the kill came from
	// the class primary, which silently switched OFF four upgrades the moment
	// you drew your sidearm. BOUNTY, SCAVENGER, ADRENALINE and KILL RELOAD are
	// all weapon-agnostic script — SCAVENGER even refunds onto self.damageweapon,
	// so it was already written to pay whichever gun made the kill.
	// LEECH is the one hold-back and it keeps this flag: "blade kills heal you"
	// is the SLASHER's risk model — healing must cost you the range the blade
	// costs. is_primary rather than a MELEE test on purpose, so the gate cannot
	// regress if the Stormbreaker ever reports a non-MELEE damagemod.
	// (CHAIN LUNGE needs no flag — it already gates on MELEE at the bottom.)
	is_primary = tod_classes::is_class_primary( attacker, self.damageweapon );

	// --- BOUNTY: % of the kill's nominal money, banked, paid in exact 10s ---
	lvl = get_level( attacker, "bounty" );
	if ( lvl > 0 )
	{
		// Base value via the SHARED helper — the score popup previews the same
		// number, and if these two ever disagreed the HUD would lie.
		kill_value = bounty_kill_value( self.damagemod, self.damagelocation );

		if ( !isdefined( attacker.tod_bounty_bank ) )
			attacker.tod_bounty_bank = 0;
		attacker.tod_bounty_bank += kill_value * TOD_UPG_BOUNTY_PER_LVL * lvl;

		if ( attacker.tod_bounty_bank >= 10 )
		{
			pay = int( attacker.tod_bounty_bank / 10 ) * 10;
			attacker.tod_bounty_bank -= pay;
			attacker zm_score::add_to_player_score( pay );
		}
	}

	// --- SCAVENGER ("reserve"): kills refund reserve ammo on the killing gun -
	// v9.10 (user 2026-08-22): a KILL COUNTER, ONE round per `need` kills
	// (TOD_SCAV_KILLS_LV1 - (lvl-1), floor TOD_SCAV_KILLS_MIN) and NEVER more
	// than one round per shot: a penetrating / echo multi-kill delivers several
	// of these callbacks in the SAME server frame, so a payout latches the frame
	// time and later kills in that frame only COUNT. Past the threshold the
	// counter is held at need-1 ("one kill away") — a 10-kill penetration shot
	// is one round now and one on the next kill, never a stack of pre-paid
	// rounds. The counter survives level-ups (need just shrinks under it).
	// PRIMARIES ONLY (user 2026-08-26: "it will not apply to secondaries. Only
	// primaries guns for each class"). A sidearm kill now pays NOTHING — it does
	// not refund the sidearm, and it does not divert a refund to the primary
	// either. Gating here rather than on the weapon the refund lands on is the
	// whole point: `w` below is self.damageweapon, so without this gate a kill
	// made with the pistol topped the PISTOL up. Note this also means a sidearm
	// kill no longer even ADVANCES the counter, which is the honest reading of
	// "does not apply to secondaries" — the upgrade is a reward for fighting
	// with your class weapon.
	lvl = get_level( attacker, "reserve" );
	if ( lvl > 0 && is_primary )
	{
		need = scav_kills_needed( lvl );
		if ( !isdefined( attacker.tod_scav_kills ) )
			attacker.tod_scav_kills = 0;
		attacker.tod_scav_kills++;
		if ( attacker.tod_scav_kills >= need )
		{
			now = GetTime();
			if ( !isdefined( attacker.tod_scav_pay_ms ) || attacker.tod_scav_pay_ms != now )
			{
				attacker.tod_scav_pay_ms = now;
				attacker.tod_scav_kills -= need;
				w = self.damageweapon;
				stock = attacker GetWeaponAmmoStock( w );
				if ( stock < w.maxAmmo )
				{
					// CLAMP: the capstone pays 3, so stock+pay can overshoot the
					// reserve cap where the old flat +1 never could.
					give = stock + scav_rounds_paid( lvl );
					if ( give > w.maxAmmo )
						give = w.maxAmmo;
					attacker SetWeaponAmmoStock( w, give );
					// the clink only fires when ammo ACTUALLY landed — never on
					// a payout wasted against a full reserve
					attacker scavenger_feedback();
				}
			}
			if ( attacker.tod_scav_kills > need - 1 )
				attacker.tod_scav_kills = need - 1;
		}
	}

	// --- LEECH (slasher): the blade feeds you ------------------------------
	lvl = get_level( attacker, "leech" );
	if ( is_primary && lvl > 0 && IsAlive( attacker ) && !( attacker laststand::player_is_in_laststand() ) )
		attacker trickle_heal( leech_hp_for_level( lvl ) );

	// --- ADRENALINE (MP5 unique): a kill stacks a 4s speed burst -----------
	lvl = get_level( attacker, "adrenaline" );
	if ( lvl > 0 )
	{
		now = GetTime();
		if ( !isdefined( attacker.tod_adren_until ) || now > attacker.tod_adren_until || !isdefined( attacker.tod_adren_stacks ) )
			attacker.tod_adren_stacks = 0;
		s = attacker.tod_adren_stacks + 1;
		if ( s > TOD_ADREN_STACKS )
			s = TOD_ADREN_STACKS;
		attacker.tod_adren_stacks = s;
		attacker.tod_adren_until = now + TOD_ADREN_MS;
		attacker apply_move_speed();   // instant — the body tick only keeps it current
	}

	// --- KILL RELOAD (assault): every Nth kill slams in a FRESH MAGAZINE -----
	// TWO REWORKS IN ONE DAY (2026-08-23) — read both, the second needs the first.
	//
	// v9.41 fixed the ECONOMY. The original did SetWeaponAmmoClip( clip + 25%·Lv
	// of the mag ) and never touched the stock, so it MINTED ammo out of nothing.
	// Rounds now come OUT OF THE RESERVE, so your total ammo is exactly what you
	// carried and an empty reserve means you are genuinely dry. SCAVENGER is the
	// map's ONE ammo-creating domain again.
	//
	// v9.43 fixed the GAMEPLAY, which v9.41 did not touch (user: "its still
	// crazy even if it comes out of reserve ... you basically never have to
	// reload"). They were right, and no percentage could have saved it:
	//
	//   A per-kill refund removes reloading whenever refund-per-kill >=
	//   rounds-SPENT-per-kill. On the Krig (33 rounds, 313 dmg) at round 20 a
	//   headshot kill costs 4 rounds while Lv1 alone handed back 8. The refund
	//   only lost that race once ONE kill cost more than 75% of a magazine —
	//   round ~29 on body shots, round ~40+ on headshots, later still with
	//   DAMAGE stacked. So all three "levels" spelled the same single effect,
	//   "you never reload", and the 25/50/75% ladder was decoration.
	//
	// The ladder is now RARITY, not size: a proc always tops the magazine back
	// up to FULL (`want = cap - clip`, so at 3/4 full you get a quarter mag, not
	// a whole one) and the LEVEL buys FREQUENCY — 100 / 75 / 50 kills, see
	// killreload_kills_needed. Between procs you reload like everyone else.
	//
	// THE FIRST CUT OF THIS REWORK USED 10 / 7 / 5 AND WAS STILL BROKEN (user,
	// same day: "yeah this is still broken"), which is worth recording because
	// the reasoning is not obvious. A refill every 5 kills still outran
	// consumption early on: a kill can cost as little as 1 round in the opening
	// rounds, so 5 kills spent 5 rounds and handed back up to 33. The card only
	// began to lose that race around round ~16 (body) / ~26 (headshot), so it
	// STILL deleted reloading for the whole early game — a smaller hole than the
	// percentage version, but the same hole.
	//
	// 100 / 75 / 50 has NO hole, and that is arithmetic rather than taste. Take
	// the cheapest kill a player can ever construct — a one-round headshot — and
	// Lv3 still spends 50 rounds to earn at most one 33-round refill: net -17 per
	// cycle, and less than that whenever the proc lands on a part-full mag.
	// Every level, every round number, the magazine drains.
	//
	// Scope unchanged: all three assault guns (user 2026-08-23). Reads clipSize
	// off the killing weapon, so a MAG SIZE twin makes each free magazine
	// bigger — more rounds per proc, still not more total ammo.
	lvl = get_level( attacker, "killreload" );
	if ( lvl > 0 )
	{
		if ( !isdefined( attacker.tod_killreload_kills ) )
			attacker.tod_killreload_kills = 0;
		attacker.tod_killreload_kills++;
		need = killreload_kills_needed( lvl );
		if ( attacker.tod_killreload_kills >= need )
		{
			attacker.tod_killreload_kills = 0;
			w = self.damageweapon;
			cap = undefined;
			if ( isdefined( w ) )
				cap = w.clipSize;
			if ( isdefined( cap ) && cap > 0 )
			{
				clip  = attacker GetWeaponAmmoClip( w );
				stock = attacker GetWeaponAmmoStock( w );
				want  = cap - clip;         // a WHOLE magazine, never past full
				if ( want > stock )
					want = stock;           // never more than the reserve holds
				if ( want > 0 )
				{
					attacker SetWeaponAmmoClip( w, clip + want );
					attacker SetWeaponAmmoStock( w, stock - want );
				}
			}
		}
	}

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
// team — to roll a solo upgrade menu on the spot. The world does NOT pause;
// the buyer is NOT frozen (user 2026-08-20) — full movement + weapons while
// the cards are up; the horde keeps coming (that is the risk) and the 15s
// auto-lock timer still runs. If a SCHEDULED
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

function station_spawn()
{
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );
	level.tod_station_count = 0;

	// BASE station — backed on the core south face, facing spawn. yaw ~0 =
	// front toward -y is the LIVE-VERIFIED vending convention (same as the
	// perk pads; 270 faced WEST).
	station_place( ( 0, -320, 0 ), ( 0, -360, 0 ), 359.999 );

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
			IPrintLn( "station " + ( level.tod_station_count - 1 ) + ": MODEL SPAWN FAILED" );
		return;
	}
	m.angles = ( 0, yaw, 0 );
	m SetModel( "chaos_pack_a_punch" );

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
			t = spawn( "trigger_radius_use", trig_org, 0, 64, 100 );
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
					IPrintLn( "altar " + station_id + ": TRIG SPAWN FAILED (pool) - retrying" );
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
				IPrintLn( "altar 5: trigger up at " + trig_org[ 0 ] + " " + trig_org[ 1 ] + " " + trig_org[ 2 ] );
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
// buys are UNTOUCHED (station_depleted still exempts the crown altar); only the
// escalation is gone. Economically this is a straight buff — buy #10 was 4,250
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
	if ( IS_TRUE( level.tod_dev ) )   // DEV: no per-station cap (user 2026-08-21) — test any terminal endlessly
		return false;
	// THE CROWN ALTAR IS UNLIMITED (user 2026-08-29: "The heavenly alter in
	// the crown room shouldnt have a limit"). It is the last-chance vendor
	// before the ending and the only one on the crown — the per-station cap
	// exists to push players UP the tower, and there is no further up.
	// (2026-08-30 correction, peer audit: this comment used to claim "the
	// price ladder (+250 per buy) still binds it economically" — VOID since
	// station_cost() went FLAT 3000 for the triggerstring-250 crash fix. The
	// crown altar is now uncapped AND flat-priced: the only binder is the
	// player's points. Deliberate — deep crown runs are exactly when a
	// last-chance vendor should stay open; re-cap here if that reads wrong.)
	// Station ids: base 0, breathers 1-4, crown 5 (station_place call order).
	if ( id == 5 )
		return false;
	return ( station_uses( player, id ) >= TOD_STATION_USES_PER );
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
			self SetHintString( "Hold ^3[{+activate}]^7 ^5HEAVENLY GIFT ALTAR ^2[Cost: " + cost + "]" );
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
			IPrintLn( "altar " + self.tod_station_id + ": press" );

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
				IPrintLn( "altar " + self.tod_station_id + ": deny NOT-OWNER" );
			continue;
		}
		if ( !IS_TRUE( level.tod_class_select_done ) )    // never during the draft
			continue;
		// A round event is live — refuse, but SAY SO. Mute refusals read as dead
		// triggers (the 2026-08-26 "teleporter wasn't activated" report; the full
		// note lives on _tod_teleport.gsc's copy of this branch). Note the
		// laststand branch below stays SILENT on purpose: a downed player is
		// holding the use key trying to get revived, and a deny sound there would
		// machine-gun in their ear for the whole crawl.
		if ( IS_TRUE( level.tod_upgrade_pause ) )
		{
			if ( IS_TRUE( level.tod_dev ) )
				IPrintLn( "altar " + self.tod_station_id + ": deny PAUSE" );
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
		if ( IS_TRUE( player.tod_solo_upg_active ) )      // already mid-pick
		{
			if ( IS_TRUE( level.tod_dev ) )
				IPrintLn( "altar " + self.tod_station_id + ": deny MID-PICK" );
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
				IPrintLn( "altar " + self.tod_station_id + ": deny REVIVE-TRIG" );
			continue;
		}
		if ( !player_has_upgrades_left( player ) )        // everything maxed
		{
			if ( IS_TRUE( level.tod_dev ) )
				IPrintLn( "altar " + self.tod_station_id + ": deny ALL-MAXED" );
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
		if ( station_depleted( player, self.tod_station_id ) )   // per-station cap (crown 5 exempt)
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}

		cost = station_cost( player );
		if ( !( player zm_score::can_player_purchase( cost ) ) )
		{
			if ( IS_TRUE( level.tod_dev ) )
				IPrintLn( "altar " + self.tod_station_id + ": deny POOR (" + cost + ")" );
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

// self = player
function solo_upgrade_flow()
{
	self endon( "disconnect" );
	level endon( "end_game" );

	self.tod_solo_upg_active = true;

	opts = roll_options( self );
	if ( !isdefined( opts ) )   // belt+braces (the trigger pre-filtered)
	{
		self solo_refund();
		self.tod_solo_upg_active = false;
		return;
	}

	for ( ;; )
	{
		// A scheduled round event owns the shared card UI — hold until it is
		// fully over, then re-present the SAME cards with a fresh timer.
		if ( IS_TRUE( level.tod_upgrade_pause ) )
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

		// NO FREEZE (user 2026-08-20: "it pauses you but doesn't pause zombies
		// so you are helpless") — but JUMP IS LOCKED (user 2026-08-21: "when
		// using the manual card upgrade you should not be able to jump"), since
		// jump is the hold-to-lock button and hopping while choosing both fires
		// the lock and launches you off a balcony. Movement and weapons stay
		// fully live; only the jump input is taken, and it is restored on every
		// exit path below including the takeover.
		// That is the whole risk model: you fight WHILE you choose, or you let
		// the 15s timer auto-lock the focused card. The lock button is HOLD
		// jump, so an ordinary hop never locks a card by accident.
		// Corollary: we must never call menu_freeze(false) here either — on a
		// round-event takeover the EVENT's own flow owns the freeze flag (it
		// is flat, not nested) and unfreezes at its end.
		// Jump is taken for exactly the duration of the card prompt and given
		// back the instant it returns — a tight window on EVERY path (normal
		// lock, timeout, down, takeover), so a thread that dies mid-present
		// can never strand the player unable to jump.
		self AllowJump( false );
		choice = self solo_present_interruptible( opts );
		self AllowJump( true );

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
		if ( IS_TRUE( level.tod_upgrade_pause ) )
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
		if ( !tier_card_eligible( self ) )
			return false;
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
