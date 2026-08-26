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
#define TOD_UPG_SPRINT_TIRELESS 5      // SPRINT/MOBILITY level that grants tireless sprint
// TIRELESS — what "unlimited sprint" ACTUALLY takes (v9.15, user 2026-08-22
// "we have tried to fix this multiple times"). The sprint meter is PREDICTED
// ON THE CLIENT from the client's own `player_sprintTime` dvar, which stock
// sets per client ONCE at connect to the gametype's 4s
// (zm/gametypes/_globallogic_player.gsc:125 `SetClientPlayerSprintTime`).
// The server-side `SetSprintDuration()` every earlier fix leaned on never
// reaches that dvar, so the meter kept draining at 4s no matter what we set.
// The lever is the per-client dvar setter itself — official API
// (docs_modtools/bo3_scriptapifunctions.htm): `<player>
// SetClientPlayerSprintTime(<time>)` "Sets player_sprintTime dvar only on
// this client". Both knobs get the SAME number so server and client agree on
// when a sprint may end. Seconds per full meter — 999 is ~16 min of
// continuous sprint and the meter recharges: reads as unlimited. (Stock
// Stamin-Up touches neither knob — it is purely the engine specialty.)
#define TOD_UPG_TIRELESS_SECS   999
// SCAVENGER (v9.10, user 2026-08-22: "max 1 bullet back on one shot ... 1
// bullet every N kills, N shrinking per level, 2 kills is the most it'll
// go"): a KILL COUNTER paid ONE round at a time. Kills per round =
// LV1 - (lvl-1), floored at MIN:
//   Lv1 7 / Lv2 6 / Lv3 5 / Lv4 4 / Lv5 3 / Lv6 (assault only) 2.
// History: 2 rounds/kill/Lv -> 1 (2026-08-20 "unlimited ammo") -> 0.25 banked
// fractionally (2026-08-21 "too strong") -> this ladder. The fractional bank
// paid 1.5 rounds PER KILL at Lv6, so one penetrating 3-kill shot landed 4
// rounds at once — the exact complaint.
#define TOD_SCAV_KILLS_LV1      7      // kills per refunded round at Lv1
#define TOD_SCAV_KILLS_MIN      2      // floor — the Lv6 (assault) ceiling
// (TOD_UPG_HP_PER_LVL removed 2026-08-20 — HEALTH became DMG REDUCTION,
// -4%/Lv, applied in _tod_bosses' player-damage chain.)
#define TOD_UPG_REGEN_PER_LVL   0.005  // +0.5% max HP regen per second per level (HEAVY)
// SECOND WIND (MP7, skirmisher T3 unique — user 2026-08-23: "you heal as you
// run. 5% health per second. starts at 1% up to level5 at 5%"). 1% of MAX HP
// per level per second WHILE SPRINTING, 5 levels => Lv1 1%/s .. Lv5 5%/s.
// Against TOD_UPG_BASE_HP 150 that is 1.5 HP/s at Lv1 and 7.5 HP/s at Lv5, so a
// full heal from near-death takes ~20s of sustained sprinting at cap.
// Gated on IsSprinting() rather than mere movement, which makes it a real
// decision: BO3 will not let you fire while sprinting, so healing costs you all
// your damage output. That is the trade — disengage and recover, or stand and
// shoot. It is also uncopyable by the other classes: SPRINT is skirmisher and
// slasher only, and only the skirmisher reaches tireless (SPRINT Lv5).
#define TOD_UPG_SECONDWIND_PER_LVL 0.01

// MOMENTUM (skirmisher CLASS domain — user 2026-08-23: "I like momentum too.
// Lets add both one as skirmisher upgrade and one unique to MP7"). Damage
// scales with how fast you are ACTUALLY moving: nothing below MIN_SPEED, full
// bonus at FULL_SPEED, linear between. +5% per level at full speed, 5 levels
// => +25% at cap.
// KEYED ON RUN VELOCITY, NOT SPRINT, and that is load-bearing: BO3 does not
// let you fire while sprinting, so a sprint-gated damage bonus would be dead on
// arrival. This rewards firing ON THE MOVE, which is the skirmisher's whole
// identity and is exactly what RUN AND GUN already pays for in ammo.
// Speed constants mirror _tod_runandgun's calibration (TOD_RNG_MIN_SPEED 120,
// base run ~190) so the two domains agree on what "moving" means.
#define TOD_UPG_MOMENTUM_PER_LVL   0.05
#define TOD_MOMENTUM_MIN_SPEED     120    // u/s 2D — below this, no bonus at all
#define TOD_MOMENTUM_FULL_SPEED    190    // u/s 2D — at or above this, full bonus
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
#define TOD_UPG_FEED_BASE_SECS  2.0    // seconds per round at Lv 1... (was 3.0)
#define TOD_UPG_FEED_STEP_SECS  0.1778 // ...minus this per level (2.0 -> 0.4 across 9 steps)
#define TOD_UPG_FEED_MIN_SECS   0.4    // floor — Lv10 lands here (never zero: would spin the catch-up loop)
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
#define TOD_KILLRELOAD_KILLS_LV1  100
#define TOD_KILLRELOAD_KILLS_LV2   75
#define TOD_KILLRELOAD_KILLS_LV3   50
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
	add_domain( "dr",         "DMG REDUCTION", "-5% damage taken / Lv",             10, undefined, TOD_TIER_S );
	add_domain( "bounty",     "BOUNTY",      "+5% money per kill / Lv",             10, undefined, TOD_TIER_B );
	add_domain( "luck",       "LUCK",        "+10% luck gain rate / Lv",             5, undefined, TOD_TIER_S );
	// -- SKIRMISHER + SLASHER --
	// TIRELESS at Lv5 is SKIRMISHER-ONLY (user 2026-08-22) even though the
	// slasher also rolls SPRINT — the grant is class-gated in body_systems_loop.
	add_domain( "sprint",     "SPRINT",      "+5% speed / Lv; Lv 5 tireless (skirmisher)", 10, array( "skirmisher", "slasher" ), TOD_TIER_A );
	// SPRINT FIRE (user 2026-08-21): promoted from a skirmisher INNATE to an
	// earned card — but still SKIRMISHER-ONLY (user, same day: "sprint fire is
	// only for smg class upgrades"). So it stays the SMG's identity; you just
	// have to earn it now instead of starting with it.
	// BINARY — the engine specialty is on/off, so max 1 (a SUPER/ULTIMATE roll
	// still just grants the single level).
	add_domain( "sprintfire", "SPRINT FIRE", "fire your weapon while sprinting",     1, array( "skirmisher" ), TOD_TIER_A );
	// SPRINT ARMOR (user 2026-08-23): -5%/Lv damage taken WHILE SPRINTING, 5
	// levels, skirmisher + slasher only — the mobile classes get tougher in
	// motion, never standing still. Tier A: strong but conditional. Scope
	// "class" below (it is damage resistance, the one thing the user said
	// survives a tier-up). The hook lives in _tod_bosses' two damage lanes via
	// sprint_armor_mult(); domain_id 32.
	add_domain( "sprintarmor", "SPRINT ARMOR", "-5% damage taken while sprinting / Lv", 5, array( "skirmisher", "slasher" ), TOD_TIER_A );
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
	// BACK ARMOR (v9.45, user 2026-08-23) — the two SLOW classes (assault 0.9,
	// heavy 0.8 move speed) get the defence the two FAST ones already have.
	// SPRINT ARMOR pays you for outrunning the horde; this pays the classes
	// that cannot, for the hits they take precisely because they cannot turn
	// around fast enough. -10%/Lv from a 140-degree rear arc, 3 levels.
	// Scope "class" below — it is damage resistance, the one family the user's
	// tier rule says survives a promotion (with DR and SPRINT ARMOR).
	add_domain( "backarmor",  "BACK ARMOR",  "-10% damage taken from behind / Lv",     3, array( "assault", "heavy" ), TOD_TIER_A );
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
	// v9.10 rate: ONE round per 7 kills at Lv1, one kill fewer per level, floor
	// 2 (TOD_SCAV_KILLS_LV1/MIN) — never more than one round per shot.
	add_domain( "reserve",    "SCAVENGER",   "1 round back per 7 kills, 1 kill fewer / Lv", 5, array( "skirmisher", "assault", "heavy" ), TOD_TIER_B, "assault", 6 );
	// -- HEAVY signatures --
	add_domain( "mobility",   "MOBILITY",    "+5% move speed / Lv",                 10, array( "heavy" ), TOD_TIER_A );
	add_domain( "bulletfeed", "BULLET FEED", "reserve trickles into the mag: 2.0s -> 0.4s / round", 10, array( "heavy" ), TOD_TIER_B );
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
	add_domain( "regen",      "REGEN",       "+0.5%/s self-heal / Lv",              10, array( "heavy" ), TOD_TIER_A );
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
	// count — +33%/Lv for one extra target, every 3 levels banks it and starts
	// the next. 6 levels, hard cap +2 extras (3 zombies per swing).
	add_domain( "cleave",     "CLEAVE",      "+33% / Lv chance to hit an extra zombie (max +2)", 6, array( "slasher" ), TOD_TIER_S );
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
	add_domain( "runandgun",  "RUN AND GUN", "shots fired on the move cost no ammo: 20/35/50%", 3, array( "skirmisher" ), TOD_TIER_B );
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
	// SECOND WIND — the MP7's replacement unique (gun-bound below).
	add_domain( "secondwind", "SECOND WIND",      "sprint to heal: 1% of your health per second per level",              5, array( "skirmisher" ), TOD_TIER_S );
	// MOMENTUM — the MP5's unique since 2026-08-24 (it was a skirmisher CLASS
	// domain, any gun, until the ADRENALINE swap; see set_guns below).
	add_domain( "momentum",   "MOMENTUM",         "damage scales with your speed: up to +5% per level while moving",     5, array( "skirmisher" ), TOD_TIER_A );
	// KILL RELOAD: TIER S -> B (user 2026-08-23: "kill reload is B or A tier").
	// B is the right one of the two they offered. The v9.43 rework left it an
	// AMMO-ECONOMY card — a magazine topped up from your own reserve every 100th
	// / 75th / 50th kill, which creates no ammo and, by that build's arithmetic,
	// never outruns consumption at any level or round. That is exactly the band
	// SCAVENGER, BULLET FEED and RUN AND GUN sit in. It kept its S weighting
	// only because it was S when it WAS game-defining, before the rework.
	// Effect of the move: draw weight 20 -> 100 (offered 5x as often) and its
	// SUPER/ULTIMATE slice stops being halved (tier_rarity_factor 0.5 -> 1.0).
	add_domain( "killreload", "KILL RELOAD",      "every 100th/75th/50th kill refills your magazine",                    3, array( "assault" ),    TOD_TIER_B );
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
	add_domain( "march",      "FORCED MARCH",     "+5% move speed / Lv",                                                 3, array( "assault" ),    TOD_TIER_A );

	// ---- CLASS TIERS (docs/25 §2.3, §3 — user 2026-08-22) ------------------
	// SCOPE: "gun" (default) = reset to 0 when a TIER card promotes the class;
	// "class" = survives. User rule: "almost no perks will [persist] but damage
	// resistance, luck, maybe only those two" — applied strictly (the BODY
	// domains sprint/mobility/regen/sprintfire reset too, user 2026-08-22 #1).
	set_scope( "dr",   "class" );
	set_scope( "luck", "class" );
	set_scope( "sprintarmor", "class" );   // damage resistance — persists like DR (v9.28)
	set_scope( "backarmor",   "class" );   // damage resistance — persists like DR (v9.45)
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
	// ADRENALINE <-> MOMENTUM SWAPPED (user 2026-08-24: "Adrenaline and momentum
	// upgrades will be swapped on mp5 and mp7. MP7 will get adrenaline and mp5
	// momentum"). Note what changed for MOMENTUM specifically: it was NOT
	// gun-bound at all — a skirmisher CLASS domain rollable on all three rungs —
	// so this does not just move it, it NARROWS it to the MP5. That is the only
	// reading under which "mp5 momentum" is not a no-op.
	// SECOND WIND stays on the MP7, which now carries two uniques; nothing was
	// asked about it and the MP5 is the rung that gained a binding.
	set_guns( "adrenaline", array( "t6_mp7" ) );            // was t9_mp5 (2026-08-24)
	set_guns( "momentum",   array( "t9_mp5" ) );            // was class-wide (2026-08-24)
	set_guns( "overdrive",  array( "t6_death_machine" ) );   // moved off the MP7 2026-08-23
	set_guns( "secondwind", array( "t6_mp7" ) );            // the MP7's replacement unique
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

function set_scope( key, scope )
{
	d = find_domain( key );
	if ( isdefined( d ) )
		d.scope = scope;
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

	// BASE 150 HP (user 2026-08-20). Stock jugg is ADDITIVE on the current
	// maxhealth and restores preMaxHealth on loss (_zm_perks.gsc:801/848), so
	// raising the base BEFORE jugg stacks cleanly (jugg = 150 + bonus). The
	// body loop below maintains it against stock 100-resets; only the spawn
	// grant heals the difference (the maintain never free-heals).
	if ( self.maxhealth < TOD_UPG_BASE_HP )
	{
		self.maxhealth = TOD_UPG_BASE_HP;
		self SetMaxHealth( TOD_UPG_BASE_HP );
		if ( self.health < TOD_UPG_BASE_HP )
			self.health = TOD_UPG_BASE_HP;
	}

	if ( !IS_TRUE( self.tod_body_systems_on ) )
	{
		self.tod_body_systems_on = true;
		self thread body_systems_loop();
		self thread tireless_spawn_watch();
	}

	// move scale must be re-applied on every spawn (it resets)
	self apply_move_speed();
}

// ---------------------------------------------------------------------------
// BODY DOMAINS (persist across class switches — trained on the player):
// SPRINT/MOBILITY (move scale + tireless sprint), HEALTH (max HP maintain,
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

// TIRELESS helpers (v9.15) — self = player. See TOD_UPG_TIRELESS_SECS for why
// BOTH calls are needed: the server duration alone never changed the meter.
function tireless_apply()
{
	self.tod_tireless_on = true;
	self SetSprintDuration( TOD_UPG_TIRELESS_SECS );
	self SetClientPlayerSprintTime( TOD_UPG_TIRELESS_SECS );
}

// Back to stock on both sides. The specialty is stripped only if the player
// did not BUY Stamin-Up (stock tracks purchases in perks_active,
// _zm_perks.gsc:778). Idempotent — safe from the body loop AND reset_gun_state.
function tireless_clear()
{
	self.tod_tireless_on = undefined;
	self SetSprintDuration( 4 );
	self SetClientPlayerSprintTime( stock_sprint_time() );
	if ( !( isdefined( self.perks_active ) && IsInArray( self.perks_active, "specialty_staminup" ) ) )
	{
		if ( self HasPerk( "specialty_staminup" ) )
			self UnsetPerk( "specialty_staminup" );
	}
}

// The gametype's per-client sprint seconds (zm/gametypes/_globallogic.gsc:2200
// reads it from the gametype table; 4 for zclassic). Fallback 4.
function stock_sprint_time()
{
	if ( isdefined( level.playerSprintTime ) && level.playerSprintTime > 0 )
		return level.playerSprintTime;
	return 4;
}

// Stock sets the client dvar only at CONNECT (not at spawn), so a respawn
// should not touch it — this is insurance, not a known reset path. Re-sends
// the pair only while the latch is on; one per player, threaded once beside
// body_systems_loop.
function tireless_spawn_watch()
{
	self endon( "disconnect" );
	level endon( "end_game" );
	for ( ;; )
	{
		self waittill( "spawned_player" );
		if ( IS_TRUE( self.tod_tireless_on ) )
			self tireless_apply();
	}
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

		// BASE 150 HP maintain (jugg-aware: only ever RAISES a sub-150 max,
		// so an active jugg's 150+bonus is never touched; no free healing).
		if ( self.maxhealth < TOD_UPG_BASE_HP )
		{
			self.maxhealth = TOD_UPG_BASE_HP;
			self SetMaxHealth( TOD_UPG_BASE_HP );
		}

		// TIRELESS — v9.15 (user 2026-08-22: "unlimited running with sprint lv
		// 5 ... doesn't work still"). History: the first cut granted only the
		// staminup specialty (no meter change); the second added the
		// server-side SetSprintDuration(60) — ALSO no effect, because the meter
		// is predicted on the CLIENT from the client's `player_sprintTime`
		// dvar (see TOD_UPG_TIRELESS_SECS). tireless_apply() now sets BOTH the
		// server duration and, via SetClientPlayerSprintTime, that client dvar.
		// Latched (tod_tireless_on): applied once on grant, re-sent on every
		// spawn by tireless_spawn_watch, CLEARED here the moment eligibility is
		// lost (class switch at the station, tier-up level reset) — the old
		// code had no un-apply path outside reset_gun_state. The specialty
		// stays too (Stamin-Up's engine speed/sprint multiplier + the glow/HUD
		// systems that read it).
		//
		// SKIRMISHER ONLY (user 2026-08-22: "I want only skirmisher to be able
		// to get tireless"). SPRINT is ALSO on the slasher, so the level alone
		// is not sufficient — the grant is CLASS-GATED. Keep it that way: if a
		// future edit drops this gate, the slasher silently inherits tireless.
		c = tod_classes::get_class( self );
		if ( isdefined( c ) && c.key == "skirmisher"
		  && get_level( self, "sprint" ) >= TOD_UPG_SPRINT_TIRELESS )
		{
			if ( !( self HasPerk( "specialty_staminup" ) ) )
				self SetPerk( "specialty_staminup" );
			if ( !IS_TRUE( self.tod_tireless_on ) )
				self tireless_apply();
		}
		else if ( IS_TRUE( self.tod_tireless_on ) )
		{
			self tireless_clear();
		}

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

		// REGEN (heavy): trickle self-heal.
		rgn = get_level( self, "regen" );
		if ( rgn > 0 )
			self trickle_heal( self.maxhealth * TOD_UPG_REGEN_PER_LVL * rgn );

		// SECOND WIND (skirmisher, MP7-bound): heal WHILE SPRINTING, 1% of max
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
		//     -> Lv1 every 3.0s ... Lv10 every 0.75s, floored so it can never
		//     hit zero.
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

		self swap_primary( w, want, false );
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
			self LuiNotifyEvent( &"tod_upg_sync", 3, tod_upgrade_ui::domain_id( d.key ), lvl, domain_max( self, d ) );
	}
	// CLASS TIER row (id 24): pips = the tier, shown from tier 2 on (tier 1 is
	// the baseline, not an upgrade). Same int-only lane.
	t = tod_classes::tier( self );
	if ( t >= 2 )
		self LuiNotifyEvent( &"tod_upg_sync", 3, tod_upgrade_ui::domain_id( "tier" ), t, tod_classes::tier_max() );
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

	return opts;
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
	if ( o.rarity == 3 )      o.rarity_name = "ULTIMATE";
	else if ( o.rarity == 2 ) o.rarity_name = "SUPER";
	else                      o.rarity_name = "";

	o.cur = get_level( player, domain.key );
	o.max = domain_max( player, domain );   // per-class cap (RESERVE: assault 6)
	o.levels = o.rarity;
	if ( o.cur + o.levels > o.max )
		o.levels = o.max - o.cur;

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

	// 2. reset every GUN-scoped domain (CLASS-scoped — DR, LUCK — kept)
	for ( i = 0; i < level.tod_domains.size; i++ )
	{
		d = level.tod_domains[ i ];
		if ( isdefined( d.scope ) && d.scope == "class" )
			continue;
		if ( get_level( player, d.key ) <= 0 )
			continue;
		player.tod_levels[ d.key ] = 0;
		// the pause list hides level-0 rows (AetheriumStartMenu.lua filters lvl > 0)
		player LuiNotifyEvent( &"tod_upg_sync", 3, tod_upgrade_ui::domain_id( d.key ), 0, domain_max( player, d ) );
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
	// TIRELESS (v9.15): the body loop would clear it on its next tick (level
	// gone = latch off), but do it NOW — both the server duration and the
	// client `player_sprintTime` dvar go back to stock, and the specialty is
	// stripped unless the player BOUGHT Stamin-Up (perks_active check inside).
	if ( IS_TRUE( self.tod_tireless_on ) )
		self tireless_clear();
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
	attacker tod_upgrade_ui::push_dmg_num( final, headshot );

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
			// Each block of 3 levels buys one extra target: within a block the
			// chance climbs +33%/Lv (Lv1 33% / Lv2 67% / Lv3 always +1), then
			// Lv4-6 repeat the ladder for a SECOND extra. Hard cap +2 extras
			// (3 zombies per swing). Max level is 6 (add_domain).
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
	// MOMENTUM (skirmisher, any gun): scales with 2D ground speed. Computed
	// BEFORE the fire-streak gate below on purpose — it has nothing to do with
	// holding the trigger, so a lapsed streak must not suppress it.
	lvl = get_level( attacker, "momentum" );
	if ( lvl > 0 && isplayer( attacker ) )
	{
		v = attacker GetVelocity();
		sp = Sqrt( v[ 0 ] * v[ 0 ] + v[ 1 ] * v[ 1 ] );
		if ( sp > TOD_MOMENTUM_MIN_SPEED )
		{
			f = ( ( sp - TOD_MOMENTUM_MIN_SPEED ) / ( TOD_MOMENTUM_FULL_SPEED - TOD_MOMENTUM_MIN_SPEED ) );
			if ( f > 1.0 )
				f = 1.0;
			add += f * TOD_UPG_MOMENTUM_PER_LVL * lvl;
		}
	}

	streak = ( isdefined( attacker.tod_fire_streak ) ? attacker.tod_fire_streak : 0 );
	last = ( isdefined( attacker.tod_fire_last_ms ) ? attacker.tod_fire_last_ms : 0 );
	if ( ( now - last ) > TOD_STREAK_GAP_MS )
		return add;   // streak lapsed — streak-based uniques contribute nothing,
		              // but MOMENTUM above still stands (it is speed, not streak)
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
	if ( IsSubStr( n, "pistol_standard" ) )
	{
		if ( IsSubStr( n, "_upgraded" ) ) return 4.32;
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
// computed off the matching nominal value (melee 130 / headshot 100 / bullet
// 60) and BANKED: zm_score::add_to_player_score rounds UP to multiples of 10
// (KB trap), so fractional bonuses accumulate on the player and pay out in
// exact 10s — over time the payout is exactly 3%/Lv, never inflated.
// ---------------------------------------------------------------------------

// The kill's NOMINAL money, shared by the payout above and the score-popup
// preview below so they can never drift apart.
function bounty_kill_value( mod, hitloc )
{
	if ( isdefined( mod ) && IsSubStr( mod, "MELEE" ) )
		return 130;
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
	lvl = get_level( attacker, "reserve" );
	if ( lvl > 0 )
	{
		need = TOD_SCAV_KILLS_LV1 - ( lvl - 1 );
		if ( need < TOD_SCAV_KILLS_MIN )
			need = TOD_SCAV_KILLS_MIN;
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
					attacker SetWeaponAmmoStock( w, stock + 1 );
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
	// platform"). Breather laps are 10/20/30/40 — all EVEN, so every balcony
	// is the mirrored (SW) one. REAL FOOTPRINT from the generator (line 291,
	// even-parity branch): floor x[-640,-256], y[-816,-416]; players ARRIVE at
	// the NE corner off the SW landing and walk south/west into it.
	//
	// LAYOUT (fixed 2026-08-21 — the first pass put the terminal mid-floor
	// with its trigger BEHIND the machine, so you had to squeeze between it
	// and the perk machines to use it):
	//   south wall  y=-783 : the two PERK machines (x -360 / -536), facing north
	//   west wall   x=-600 : the UPGRADE STATION, facing EAST into the balcony
	// Yaw convention on this map (live-verified): 0/359.999 = front toward -y,
	// 180 = +y, 90 = +x (east), 270 = -x (west). So yaw 90 faces the terminal
	// into the open floor, and the trigger sits 56u EAST of it — in front of
	// the machine, on the walking line from the entrance, clear of both perk
	// machines (nearest is ~185u away, well outside the 64u radius).
	// Breather mid z = (lap-1)*384 + 192.
	// v9.37: the breathers grew (BR_EAST 224 -> 384): the W wall moved from
	// x=-640 to x=-800, so the terminal backs it at -760 (was -600) and its
	// trigger sits 56u east at -704. The teleporter pad (_tod_teleport) takes
	// the SE quarter at (-640,-800) — 210u from this trigger.
	zs = array( 3648, 7488, 11328, 15168 );
	foreach ( z in zs )
		station_place( ( -760, -600, z ), ( -704, -600, z ), 90 );

	// THE CROWN (v9): one terminal inside the citadel, on the west wall south
	// of the pilaster — the last chance to spend before the uplink. Anchors
	// are GENERATED (parity-mirrored with the rest of the crown).
	station_place( tod_crown_data::station_org(), tod_crown_data::station_trig_org(), tod_crown_data::station_yaw() );
}

// One terminal: the model plus its own use trigger. Every station shares the
// per-PLAYER price ladder (station_cost reads player.tod_station_buys), so
// building more of them never makes upgrades cheaper — only closer.
function station_place( model_org, trig_org, yaw )
{
	m = Spawn( "script_model", model_org );
	m.angles = ( 0, yaw, 0 );
	m SetModel( "chaos_pack_a_punch" );

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
		c.angles = m.angles;             // same yaw as the mesh, so the boxes line up
		c SetModel( "zm_collision_perks1" );
		c.script_noteworthy = "clip";
		c DisconnectPaths();
		clips[ clips.size ] = c;
	}
	m.tod_clip = clips[ 1 ];             // the CENTRE clip — handle kept because
	                                     // anything that later hides a station must
	                                     // NotSolid + ConnectPaths it (Hide() !=
	                                     // NotSolid — the QR invisible wall bug,
	                                     // docs/KB and qr_clip_watch)
	m.tod_clips = clips;                 // ...and the full set, which is what such a
	                                     // teardown actually has to walk now

	t = spawn( "trigger_radius_use", trig_org, 0, 64, 100 );
	t TriggerIgnoreTeam();      // REQUIRED for a script-spawned use-trigger
	t SetCursorHint( "HINT_NOICON" );
	t.tod_station_id = level.tod_station_count;   // base 0, breathers 1-4, crown 5
	level.tod_station_count++;
	t thread station_hint_loop();
	t thread station_use_loop();
}

function station_cost( player )
{
	n = 0;
	if ( isdefined( player ) && isdefined( player.tod_station_buys ) )
		n = player.tod_station_buys;
	// +250 per prior buy (user 2026-08-23; was +500, and +1000 before that).
	// The ladder is GLOBAL per player: n counts every station buy anywhere, so
	// extra terminals only ever make upgrades CLOSER, never cheaper. Ladder is
	// now 2000 / 2250 / 2500 / 2750 ... Across all 30 available buys that is
	// ~168,750 points (was ~277,500 at +500), and buy #10 is 4,250 (was 6,500):
	// the whole curve stays inside the range a mid-tower run can actually pay.
	return 2000 + 250 * n;
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
	// sentinel-guarded loop in this map (door_price_watch, uplink_hint_loop,
	// teleport refresh) seeds outside its own domain; this one did not.
	shown = -999;
	for ( ;; )
	{
		wait 0.3;

		near = undefined;
		best = 160 * 160;
		foreach ( p in GetPlayers() )
		{
			if ( !isdefined( p ) || !IsAlive( p ) )
				continue;
			d = DistanceSquared( p.origin, self.origin );
			if ( d < best )
			{
				best = d;
				near = p;
			}
		}
		if ( !isdefined( near ) )
			continue;

		// Co-op honesty (verify 2026-08-20): the trigger hint is GLOBAL but
		// the price is per-player — if 2+ players in range owe DIFFERENT
		// prices, show the priceless generic instead of the nearest player's
		// number (which would lie to the other one). cost -1 = generic.
		// PER-STATION CAP: a player who has spent their TOD_STATION_USES_PER
		// buys HERE sees the depleted line (cost -2) — unless someone else in
		// range still can buy, in which case the honest answer is the generic.
		// STATE CODES: >=0 a live price, -1 mixed party (show the generic),
		// -2 this station is spent for them, -3 they have nothing left to buy.
		//
		// -3 IS NEW (live report 2026-08-25: "When you hit max it should tell
		// you"). station_use_loop has always refused a maxed-out player with
		// player_has_upgrades_left() and a deny SOUND — but the hint kept
		// advertising "HEAVENLY GIFT ALTAR [Cost: N]", so the altar looked buyable
		// and simply did not work. Checked BEFORE depleted: "you have nothing
		// left to buy anywhere" outranks "you have spent this particular one".
		cost = station_cost( near );
		if ( station_depleted( near, self.tod_station_id ) )
			cost = -2;
		if ( !player_has_upgrades_left( near ) )
			cost = -3;
		foreach ( p in GetPlayers() )
		{
			if ( !isdefined( p ) || !IsAlive( p ) || p == near )
				continue;
			if ( DistanceSquared( p.origin, self.origin ) >= 160 * 160 )
				continue;
			pc = station_cost( p );
			if ( station_depleted( p, self.tod_station_id ) )
				pc = -2;
			if ( !player_has_upgrades_left( p ) )
				pc = -3;
			if ( pc != cost )
			{
				cost = -1;
				break;
			}
		}
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
		else if ( cost == -1 )
			// MIXED PARTY. The price is per-player and two people in range owe
			// different amounts, so a single number would lie to one of them.
			// It still says WHY there is no figure — a buyable with no price and
			// no explanation reads as broken (audit 2026-08-25).
			self SetHintString( "Hold ^3[{+activate}]^7 ^5HEAVENLY GIFT ALTAR^7 - per player" );
		else
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

		if ( !isdefined( player ) || !isplayer( player ) )
			continue;
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
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
		if ( IS_TRUE( player.tod_solo_upg_active ) )      // already mid-pick
			continue;
		if ( player laststand::player_is_in_laststand() )
			continue;
		// A revive press is not a purchase (_zm_blockers.gsc:307). Reviving polls
		// the raw USE button (_zm_laststand.gsc:1129), so without this the press
		// that revives a teammate at a terminal also spends 2000+ points AND
		// burns one of this station's limited uses. Silent, like the branch
		// above: the player is holding use.
		if ( player zm_utility::in_revive_trigger() )
			continue;
		if ( !player_has_upgrades_left( player ) )        // everything maxed
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
		if ( station_depleted( player, self.tod_station_id ) )   // 3 buys here — climb (user 2026-08-21)
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}

		cost = station_cost( player );
		if ( !( player zm_score::can_player_purchase( cost ) ) )
		{
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
