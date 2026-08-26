# 28 — THREE NEW ELITES: research, picks, design, implementation plan

> Answers `docs/27_new_elites_research_brief.md`. Written 2026-08-22 against
> v9.19 (the build the peer session shipped shortly before this research).
>
> **STATUS:** picks agreed with the user 2026-08-22. **BUILD 1 (REAVER) IS
> SHIPPED** (v9.20). Builds 2 (BREACHER) and 3 (BULWARK) are specified and not
> yet written — one enemy per build, per brief §4. Section 9 records the
> answers given.
>
> **v9.21 SUPERSEDES PART OF THIS DOC:** all enemy **spawn banners are gone**
> (user: "unnecessary"). Anywhere below that specifies a banner, a banner id or
> banner art is struck through and is **not** to be implemented. Elites 2 and 3
> ship with no banner.

---

## 1. RESEARCH REPORT

### 1.1 What the map actually is today (one correction)

| Brief says | Reality (verified) | Source |
|---|---|---|
| 50 floors, breathers 10/20/30/40 | **Correct** | `tools/gen_tower_map.js:76` `LAPS = 50`, `:220` `BREATHER_LAPS = {10,20,30,40}` |
| — | `CLAUDE.md` still describes the **v6 25-floor** tower with breathers at 5/10/15/20 | repo root — **stale, worth a fix pass** |

The reserved hook is real and exactly as described —
[_tod_doors.gsc:153-176](scripts/zm/zm_tower_of_doom/_tod_doors.gsc#L153-L176):
three commented `case "enter_lap20/30/40"` slots, a round stamp into
`level.tod_enemy_unlock_round[kind]`, a `tod_enemy_unlocked` notify, and a
never-re-stamp guard. `protector_due()` is the reference cadence consumer.

**One inconsistency found in the shipped code, worth a decision:** cadence
anchors to the *unlock round*, but **HP does not** —
[_tod_bosses.gsc:1163](scripts/zm/zm_tower_of_doom/_tod_bosses.gsc#L1163) calls
`boss_hp( rn, TOD_PROTECTOR_FIRST, ... )`, i.e. the curve is anchored to the
constant `3`, not to when you bought the door. So a player who opens lap 10 at
round 25 meets a 30k Protector, not a 7k one. That is defensible (the elite is
scaled to the round you are on, not to how late you unlocked it) and the three
new elites below **mirror it** — but it is a silent asymmetry and it should be
a conscious choice, not an accident. See question 6.

### 1.2 Every candidate found, with a call

**Installed on this machine (`<TOOLS>\source_data`) — audited by extracting the
`aitype` / `character` / `xmodel` asset declarations out of each GDT.** The
distinction that decides everything: *does the GDT declare an `aitype`?* An
aitype ships behaviour (behaviour tree + ASM + animtables). An xmodel-only GDT
is a **reskin**, nothing more.

| Candidate | What the GDT actually declares | Call | Why |
|---|---|---|---|
| **Apothicon Fury** `c_zom_dlc4_apothicon_fury.gdt` | `aitype archetype_zm_genesis_apothicon_fury` + `character c_zom_dlc4_apothicon_fury(_dissolve)` + bamf / swipe / death xanims | **REUSE — pick 1** | The **only fully-formed unused AI on the machine.** Behaviour tree, ASM and animtables are all present in `<TOOLS>\share\raw\{behavior,animstatemachines,animtables}\zm_genesis_apothicon_fury.*`. The sister map has a **proven 390-line driver** (`_acc_fury.gsc`) with every robustness fix already paid for. |
| **Charred zombies** `_charred_zombies.gdt` | `aitype archetype_charred_zombie` (= stock factory-zombie behaviour, charred body) + `c_zom_dlc3_zombie_sentinel_body` + full gib set | **REUSE as a SKIN — pick 2** | Adds no behaviour, but gives an elite a distinct silhouette for one `xmodel,` zone line. |
| **SAT toxic zombies** `acc_sat_toxic_zombies.gdt` | `xmodel c_sat_zmb_zombie_toxic_1 / _2` only | **REUSE as a SKIN — pick 3** | The sister map's Glitch Stalker skin. `SetModel` on a live zombie AI is **proven safe** there (unlike `SetScale`, a confirmed `0xC0000005` crasher). |
| **Chomper** `c_zom_chomper.gdt` | `xmodel c_zom_chomper`, `c_zom_chomper_projectile` — **no aitype** | **REJECT** | Models only; there is no `archetype_chomper` in `share\raw\scripts\shared\ai\`. Would mean authoring a behaviour tree from scratch. |
| **Dragon** `c_zom_dlc3_dragon.gdt` | `xmodel c_zom_dlc3_dragon_small` — no aitype | **REJECT** | Model only, and a dragon has no navmesh story on a 224-deep stair tread. |
| **Keeper** `wpn_t7_zmb_dlc2_keeper_head.gdt`, `zm_zod_sword_egg_keeper.gdt` | weapon / xmodel assets | **REJECT** | These are the keeper *weapon* and quest props, not a keeper AI. |
| Gib packs, blood, anim libs | support | n/a | Dependencies, not candidates. |

**`<TOOLS>\_custom` audit** (brief said to check): `_coolyer` = gambling UI +
number FX; `_moicesttom` = Ghosts alien **props** (gargoyle, plants, dead
brutes — static models, no AI); `_wetegg/ai/sat` = the toxic zombie bodies
above; `westchief596` = ammo crate + Electric Cherry machine; `wetegg` =
Leviathan Axe. **No further enemy AI in the community packs.**

**Stock archetypes in `<TOOLS>\share\raw\scripts\shared\ai\`** —
`apothicon_fury`, `thrasher`, `direwolf`, `robot`, `clone`, `human_riotshield`,
`mannequin`, `civilian`, `margwa`, `mechz`. Of these only `apothicon_fury`
(pick 1), `robot` (already in use as the Protector) and `mechz` (already the
Panzer) have their **character GDT installed**. Margwa / thrasher / direwolf /
clone are script-only here — no model, no character, no anims. **REJECT all:
the scripts exist, the assets do not.**

**Stock `_zm_ai_*` in `<TOOLS>\share\raw\scripts\zm\`:**

- `_zm_ai_wasp` and `_zm_ai_raps` — **REJECT.** Both are **vehicle** AI
  (`#using scripts\shared\vehicles\_parasite` / `_raps`), not actor AI. They
  need vehicle bundles, vehicle spawners and a vehicle asset pipeline this map
  does not have, and `_zm_ai_wasp` additionally pulls `zm_zod_idgun_quest`.
  Neither has a GDT installed. Genuinely disappointing, because a true flyer is
  the single most on-theme enemy for a tower.
- `_zm_ai_faller` — **REJECT as an elite, NOTE as a future mechanic.** It is
  actor AI with no new assets (a stock zombie doing a ceiling-drop), but it is
  an *entrance style*, not a threat model. The tower already owns a better
  version of that idea: `_tod_bosses::drop_in()` (proxy descent on the zod
  sky-trail, slam, reveal). Worth revisiting later as "the horde stops only
  coming from below", which would be a genuinely tower-specific twist.
- `_zm_ai_dogs` — **REJECT.** Hellhounds are a stock every-N-rounds *round
  type*; they would collide head-on with the endless-rounds override and add a
  fourth "runs at you" verb.

### 1.3 The sister map's roster — reuse assessment

| Sister enemy | Port cost here | Call |
|---|---|---|
| **Apothicon Fury** | vendor 6 script files, ~14 zone lines, port `_acc_fury.gsc` (390 lines). GDT installed. | **TAKE — pick 1** |
| **Glitch Stalker** | script-only, skin installed | **REJECT — redundant with the Fury.** Both verbs are "it teleports to you". Taking both would make the map's two newest elites read as the same enemy. The Fury wins: it is a *committed charge* with a real animation set and a knockdown; the Stalker is a *flank* implemented as a position rewrite. |
| **Avogadro** (the disabler) | **model pack NOT installed.** Its BT, ASM, animtables, an FX and a sound CSV are all still in `share\raw` from map 1, but the Dick_Nixon character GDT is gone from `source_data` — a brain with no body, so `archetype_zm_avogadro` cannot resolve | **REJECT the enemy.** The verb ("disable a machine") was proposed as pick 3 on an installed skin — the SAPPER — and the **user cut it on 2026-08-22** as too risky for what it reached into (`_zm_perks`, the perk scatter, the perk glow; a perk stuck off ends a session). Replaced by the BULWARK, §5. |
| **Brutus / Trench Warden** | needs the NSZ Brutus pack — **not installed** (only `_charred_zombies.gdt` and `nsz_zombie_blood.gdt` are here) | **REJECT.** Also a third "big thing that walks at you", which brief §5 explicitly forbids. |
| **Shielded "Riot"** | script-only; needs `c_t8_zmb_mob_zombie_body*` zone lines | **REJECT, reluctantly.** Its whole design is *flank the front armour* — and **a staircase has no flank.** It would degrade into an unflankable HP wall corking a 224-wide tread. It is the one sister enemy whose design is actively broken by this map's geometry. |

### 1.4 Traps this task will hit (verified, not assumed)

1. **`animation_state_machine_utility.gsc` is an install-side dependency.**
   `<TOOLS>\share\raw\scripts\shared\ai\systems\animation_state_machine_utility.gsc`
   is **617 bytes** — that is HB21's override implementing `RequestState` /
   `SearchAnimationMap` (stock ships them as no-ops). The **Panzer already
   depends on it**, and the Fury will too. This repo does **not** vendor it; the
   sister map does, precisely because a Mod Tools "verify" reverts it. **A
   verify would break the Panzer today, silently.** Recommend vendoring it at
   the stock path here as part of build 1 — one file, one zone line, and it
   removes a live single point of failure.
2. **`aitype,spawner_<X>` is the load-bearing line**, not `archetype_<X>`. The
   GDT declares `archetype_zm_genesis_apothicon_fury`; the sister map's working
   zone line is `aitype,spawner_zm_genesis_apothicon_fury` and the call is
   `SpawnActor("spawner_zm_genesis_apothicon_fury", ...)`. Copy that exactly.
3. **~~The boss banner LUI is hardcoded to two ids.~~ MOOT — banners removed
   2026-08-22.** Kept for the record because it explains the v9.20 Lua churn.
   The whole spawn-banner lane (LUI elements, subscription, server functions,
   eventstring, and the two `image,` zone lines) was deleted in v9.21 at the
   user's request: "remove all the announcement banners for the enemies
   spawning in. Its unnecessary." **Elites 2 and 3 must NOT add a banner.**
   The original finding was:
   [tod_upgrade.lua:972-985](ui/uieditor/menus/hud/tod_upgrade.lua#L972-L985) —
   `id == 1` selects `i_tod_banner_panzer`, and **anything else** falls through
   to `i_tod_banner_protectors`. Three new elites need ids 3/4/5, a table lookup
   in place of that ternary, and **three new baked banner images** (standing
   rule: baked art beats LUI drawing — prompts supplied at build time, user
   generates).
4. **The floor gauge is already the vertical-legibility system.**
   `_tod_gauge.gsc` publishes a red pip at the nearest live boss's floor cell,
   keyed off the `is_boss` / `acc_is_boss` / `acc_is_mini_boss` triad. Every
   elite carrying those flags appears on it **for free** — but the gauge shows
   only the *nearest* one, so three simultaneous elites still read as one pip.
5. **`is_boss` is consumed in 8 places** — the timewarp powerup, `_tod_gauge`,
   `_tod_lunge`, `_tod_perk_electric_cherry`, `_tod_powerups`, `_tod_upgrades`
   (suppressing fire, impact-rounds splash, Thor's Thunder), `_tod_zombie_speed`,
   and the vendored `zm_zod_robot` landing splash. All read the same triad. Set
   all three fields on every elite (exactly what the Protector does) and every
   one of those systems handles the new enemies correctly with **zero edits**.
6. **`SetModel` on a live zombie is proven; `SetScale` is a confirmed crasher.**
   Skin-swapped elites are safe; resized elites are not.

---

## 2. THE THREE PICKS

Threat-model gap: the map has a **sprinting melee horde**, a **ranged swarm**
(Protector) and a **heavy bruiser** (Panzer). All three use the staircase and
all three come at you. The three genuinely missing verbs on a vertical map are
**"ignores the stairs"**, **"denies the ground you are standing on"** and
**"takes something away from you"**.

| Slot | Name | One-line pitch | Verb | Assets | Difficulty | Risk |
|---|---|---|---|---|---|---|
| `enter_lap20` | **REAVER** | An Apothicon that blinks straight to you — the climb no longer protects you. | ignores the staircase | HB21 Fury pack (**installed**), 6 vendored scripts, ~14 zone lines | **Medium** | **Medium** — new aitype and a pack dependency, but a proven sister-map driver |
| `enter_lap30` | **BREACHER** | A charging zombie that detonates on arrival — it takes the tread away from you. | denies ground / punishes camping | none new (charred sentinel body + existing aura FX) | **Low** | **Low** — promoted stock zombie, no new AI |
| `enter_lap40` | **BULWARK** | Armoured against fire from above — to kill it you have to give up altitude. | costs you ground | none new (SAT toxic body + existing aura FX) | **Low** | **Low** — one damage callback, touches zero systems |

Each is an **elite, not a boss**: lighter than the Panzer, additive to the
horde, and none of them stops the climb.

---

## 3. DESIGN SPEC — REAVER (`enter_lap20`)

- **Chassis**: `SpawnActor("spawner_zm_genesis_apothicon_fury", ...)`, driven by
  a new `_tod_reaver.gsc` ported from `_acc_fury.gsc`.
- **Unlock**: buying the **lap-20 breather door**. Cadence anchors to that round.
- **Cadence**: every **4th round** from the unlock round (unlock, +4, +8, …).
- **Count / concurrency**: `1 + int(players/2)` per event → solo 1, duo 2,
  quad 3. Concurrency roof **3**. Debt-drained one per director tick, same as
  the wave — the AI budget must keep feeding zombies or endless rounds starves.
- **HP**: `boss_hp( round, 20, 20000, 1.08 )` × `coop_hp_mult()`.
  Solo r20 20k · r30 43k · r40 93k · r50 201k. (A Panzer at r40 is 511k, a
  Protector 71k — the Reaver sits between them. First pass; tune after live play.)
- **Behaviour**: the pack's bamf — it vanishes and rematerialises on its enemy,
  melees for a knock-push, and knocks nearby zombies down on arrival.
  **CORRECTED AT BUILD TIME (this is better than the design assumed):** the bamf
  is *not* a free teleport. `archetype_apothicon_fury.gsc:825` requires range
  **400–750u**, **mutual 50° FOV**, both endpoints on the navmesh, a clear
  `TracePassedOnNavMesh` between them **and** a successful `FindPath`, on a
  4.5–6s cooldown. On a spiral that gates it **by construction**: a player one
  flight up has no straight navmesh line, so it cannot bamf through floors.
  The planned ±600u z-clamp was therefore **dropped as unnecessary** — the
  geometry already does it, with no code of ours to maintain. (Contrast the
  ranged bosses, which genuinely need `TOD_BOSS_FIRE_ZDELTA 300`.)
  What it means in play: on the long straight flights and the open breather
  balconies, **you cannot hold a gap**.
- **Threat model**: it is the answer to "I will just keep climbing". Everything
  else in the map has to take the stairs behind you; this does not.
- **Reads as**: a purple Apothicon with a bright teleport-impact FX at both ends
  of every bamf (`fx_apothicon_fury_teleport_impact`, already in the pack), plus
  the boss pip on the floor gauge.
- **Rewards**: **400 pts** to every player; **luck +6** to the last hit.
- **Flags**: `is_boss`, `acc_is_boss`, `acc_is_mini_boss`, `ignore_enemy_count`,
  `ignore_nuke`, `tod_boss_kind = "reaver"`.
- **Ported-in robustness (already solved in `_acc_fury.gsc` — do not re-derive)**:
  the Ghost/NotSolid bamf watchdog (force `Show()` / `Solid()` after 4s so an
  interrupted bamf cannot strand it invisible-and-unhittable);
  `ignore_enemy_count`; zero damage taken until the spawn-in completes.
- **Deliberately NOT ported**: "Furious mode" (self-doubling HP + super-sprint).
  That is a boss mechanic and this is an elite.

## 4. DESIGN SPEC — BREACHER (`enter_lap30`)

- **Chassis**: **promote a live normal zombie** near the anchor player — no new
  spawn machinery, and it inherits co-op HP scaling for free. Re-entrancy
  guarded (`tod_is_breacher`).
- **Unlock**: the lap-30 breather door. **Cadence**: every **3rd round** from
  unlock; count `max(1, int(players * round / 6))`, concurrency roof **4**.
- **HP**: flat **×3 the round's current normal-zombie health** — read
  `self.maxhealth` at promote time, which already carries co-op scaling. Do
  **not** stack a second co-op multiplier; that double-count is a documented
  sister-map bug.
- **Behaviour**: it sprints (fast, not tanky). Inside **150u** of a player it
  commits to a **1.5s wind-up** — audible tell plus an amber aura ramp — then
  detonates: **radius 200**, up to **80 damage** at the centre with distance
  falloff, and it **kills the normal zombies caught in the blast**.
  - Kill it *before* the wind-up starts = clean.
  - Kill it *during* the wind-up = **it still detonates.** Back off or eat it.
  - Let it reach a packed stairwell = it clears the stairwell for you.
- **Threat model**: it is the answer to "I will hold this landing". The breather
  balconies emit no risers by design, which makes them the natural camp spot;
  this is the enemy that makes standing still on one cost something. The
  zombie-clearing blast is deliberate counter-play, not a bug — a good player
  baits it into the horde.
- **Reads as**: charred sentinel body (`c_zom_dlc3_zombie_sentinel_body`) plus an
  **amber** `_tod_perk_lights` aura that brightens through the wind-up. The aura
  is the real tell at range on a dark tower; the body confirms it up close.
- **Rewards**: **300 pts**; **luck +4**. No powerup drop (it is frequent).
- **Flags**: the full `is_boss` triad — critical here, or SUPPRESSING FIRE would
  slow a detonating enemy and IMPACT ROUNDS splash would chain-trigger a cluster.
- **Damage safety**: the blast must exclude bosses (the Protector landing-splash
  precedent) and must respect `level.tod_god` and the demigod clamp in
  `boss_player_damage`.

## 5. DESIGN SPEC — BULWARK (`enter_lap40`)

> Replaces the originally proposed SAPPER (a perk-machine hacker), which the
> user cut on 2026-08-22 as too risky: it reached into stock `_zm_perks`, the
> perk scatter and the perk glow, and its failure mode — a perk stuck off — ends
> a play session. The Bulwark keeps a distinct verb at a fraction of the risk.

- **Chassis**: promoted live zombie, as the Breacher. Re-entrancy guarded
  (`tod_is_bulwark`).
- **Unlock**: the lap-40 breather door. **Cadence**: every **4th round** from
  unlock; count `max(1, int(players/2 + 0.5))`, concurrency roof **3**.
- **HP**: flat **×4** the round's normal-zombie health (read `self.maxhealth` at
  promote time — it already carries co-op scaling; do **not** stack a second
  multiplier).
- **Behaviour**: normal zombie speed and melee. Its entire mechanic is
  **positional damage resistance**: a shot whose attacker is **above** it (the
  attacker's z exceeds the Bulwark's by more than a small deadband) does
  **25%** damage. From level or below, **100%**.
  - Running up the stairs while shooting behind you — the default behaviour on
    this map — barely scratches it.
  - To kill it efficiently you must **let it pass you, or drop below it**, and
    shoot up. That costs altitude on a map whose whole currency is altitude.
- **Threat model**: it is the answer to "I will kite everything upward forever".
  It never blocks the climb (you can always outrun it — it just stays alive and
  accumulates), so it pressures without ever creating an unwinnable cork. That
  is deliberately the inverse of the sister map's Shielded elite, whose
  flank-the-front-armour design **a staircase breaks** (§1.3): a staircase has
  no lateral flank, but it has a very real **vertical** one.
- **Reads as**: SAT toxic body (`c_sat_zmb_zombie_toxic_1`) plus a **teal**
  `_tod_perk_lights` aura. **Self-teaching**, which is why the resistance needs
  no tutorial: the map already draws crosshair damage numbers
  (`tod_upgrade_ui::push_dmg_num`), so the player literally sees small numbers
  from above and big ones from below.
- **Rewards**: **450 pts**; **luck +5**.
- **Flags**: full `is_boss` triad, `ignore_enemy_count`, `ignore_nuke`.
- **Implementation note**: the resistance is one branch inside the existing
  actor damage callback — compare `attacker.origin[2]` to `self.origin[2]`,
  scale, return. No new systems, no spawning, no perks, no FX authoring. This
  is the cheapest of the three by a wide margin.



---

## 6. IMPLEMENTATION PLAN — one enemy per build

### Shared prerequisites (folded into BUILD 1)

| File | Change |
|---|---|
| `scripts/zm/zm_tower_of_doom/_tod_doors.gsc` | uncomment slot 2 only: `case "enter_lap20": kind = "reaver"; break;` |
| ~~`ui/uieditor/menus/hud/tod_upgrade.lua`~~ | ~~banner id → image table lookup~~ — **superseded v9.21: the banner block is deleted entirely** |
| ~~`zone_source/zm_tower_of_doom.zone`~~ | ~~one `image,` line per banner~~ — **superseded v9.21: no banner art is needed at all** |
| `CLAUDE.md` | fix the stale v6 paragraph (25 floors → 50; breathers 5/10/15/20 → 10/20/30/40) |

### BUILD 1 — REAVER  ✅ SHIPPED 2026-08-22 (v9.20)

> Built and verified: `lint_tod_arity` clean, `-GscOnly` BUILD OK, fresh
> `zm_tower_of_doom.ff` **88.21 MB** (was 84.14 MB — the Fury assets are the
> +4 MB), **283** apothicon_fury asset rows in the packed assetinfo, errorlog =
> exactly the 9 known-waived errors with **zero** fury / reaver / ASM lines.
> Two deviations from the plan below, both improvements — see the ✎ notes.


1. Vendor from the sister repo, unchanged, at the pack's own paths:
   `scripts/shared/ai/archetype_apothicon_fury.gsc|.csc|.gsh`,
   `scripts/shared/ai/archetype_apothicon_fury_interface.gsc`,
   `scripts/zm/zm_genesis_apothicon_fury.gsc|.csc|.gsh`.
2. Vendor `scripts/shared/ai/systems/animation_state_machine_utility.gsc`
   (the 617-byte HB21 override — closes the live Panzer single point of failure
   found in §1.4.1).
3. New `scripts/zm/zm_tower_of_doom/_tod_reaver.gsc` — a de-`acc`'d
   `_acc_fury.gsc`: unlock gate plus `reaver_due()` modelled on
   `protector_due()`, debt/director drain, `pick_spawn_point` reuse, the
   `is_boss` triad, `tod_luck::boss_kill`, `grant_boss_reward`.
   ✎ **Deviation 1 — no z-clamp.** Reading the archetype showed the bamf is
   already geometry-gated (§3), so the planned clamp was dropped rather than
   written: less code, nothing to maintain, same outcome.
   ✎ **Deviation 2 — the pack+s meteor entrance, not `drop_in`.**
   `apothicon_fury_meteor_fx()` is what the archetype+s client FX are authored
   around, and on an open spiral the falling streak telegraphs from floors
   away — better vertical legibility than the generic proxy descent.
4. Zone lines (mirroring the sister map's verified block):
   ```
   scriptparsetree,scripts/shared/ai/archetype_apothicon_fury_interface.gsc
   scriptparsetree,scripts/shared/ai/archetype_apothicon_fury.gsc
   scriptparsetree,scripts/shared/ai/archetype_apothicon_fury.csc
   scriptparsetree,scripts/shared/ai/systems/animation_state_machine_utility.gsc
   scriptparsetree,scripts/zm/zm_genesis_apothicon_fury.gsc
   scriptparsetree,scripts/zm/zm_genesis_apothicon_fury.csc
   scriptparsetree,scripts/zm/zm_tower_of_doom/_tod_reaver.gsc
   aitype,spawner_zm_genesis_apothicon_fury
   fx,dlc4/genesis/fx_apothicon_fury_impact
   fx,dlc4/genesis/fx_apothicon_fury_breath
   fx,dlc4/genesis/fx_apothicon_fury_smk_body
   fx,dlc4/genesis/fx_apothicon_fury_foot_amb
   fx,dlc4/genesis/fx_apothicon_fury_teleport_impact
   fx,dlc4/genesis/fx_apothicon_fury_footstep
   fx,dlc4/genesis/fx_apothicon_fury_footstep_ch
   fx,dlc4/genesis/fx_apothicon_fury_spawn_in
   fx,dlc4/genesis/fx_apothicon_fury_spawn_in_exp
   fx,dlc4/genesis/fx_apothicon_fury_death
   character,c_zom_dlc4_apothicon_fury_dissolve
   ```
   ✎ **Correction to the first draft of this plan:** it proposed omitting
   `spawn_in_exp`. That was a misread — the sister map DOES zone it; what it
   swapped off that FX was its PhD Flopper nova, an unrelated consumer. The
   pack+s `.csc` `#precache`s `spawn_in_exp` unconditionally, so omitting the
   line would have been a dangling reference (fatal). `fx_apothicon_fury_death`
   is added for the same reason — the client archetype precaches it and map 1
   never listed it. All ten FX were verified present on disk before zoning.
5. `zm_tower_of_doom.gsc` `#using` + `tod_reaver::init()`; the matching
   `#using` in `zm_tower_of_doom.csc` (clientfield lockstep for
   `apothicon_fury_spawn_meteor`); `_tod_doors.gsc` slot 2;
   `_tod_luck.gsc` `TOD_LUCK_REAVER`. (Banner id 3 shipped in v9.20 and was
   removed again in v9.21 — see below.)
   ✎ The banner Lua was a **two-enemy** design — `id == 1 and panzer or
   protectors` drew the Protector banner for ANY other id. Replaced with id→art
   tables, and the text element is now built always, so an elite whose baked
   banner has not shipped yet announces in words instead of drawing a blank
   material. **The Reaver ships on the text path until `i_tod_banner_reaver`
   art exists** — adding an elite is now one row per table.
6. `node tools/lint_tod_arity.js`, then `.\tools\build_map.ps1 -GscOnly`
   (the zone changes but no geometry does, so **no LED bake is needed**;
   `-GscOnly` covers zone + GSC). Verify a **fresh `.ff`** and an errorlog equal
   to the 9 waived warnings.

### BUILD 2 — BREACHER

`_tod_breacher.gsc`, a zone `scriptparsetree` line,
`xmodel,c_zom_dlc3_zombie_sentinel_body`, door slot 3. **No banner** (v9.21).
`-GscOnly`. No new AI, no new aitype.

### BUILD 3 — BULWARK

`_tod_bulwark.gsc`, a zone `scriptparsetree` line,
`xmodel,c_sat_zmb_zombie_toxic_1`, door slot 4. **No banner** (v9.21).
`-GscOnly`. One damage-callback branch; touches no other system.

### Per-build gates (all three)

- `node tools/lint_tod_arity.js` clean (it checks arity, **not** a missing
  `#using` — verify imports by eye).
- `tasklist` shows no `BlackOps3.exe` / `linker_modtools.exe`; announce
  **BUILD START** and **BUILD DONE** to the peer session.
- Success = a **fresh `.ff`**, never the linker exit code.
- A `CHANGELOG.md` entry per build.

---

## 7. TEST SCRIPT (per enemy, `level.tod_dev = true`)

**Common**: dev build, solo, `PLAY_NORMAL.bat`. Watch for the elite appearing on
the floor gauge as the red pip, no floaty text, and no zombie laugh (that is the
too-many-weapons monitor, which must stay off).

**REAVER** — climb and buy the lap-20 door. Expect **no banner** (removed
v9.21) — the first tell is the meteor. Within ~3s expect a
drop-in entrance near you. Confirm: (1) it bamfs to you when you run *up* — the
whole point; (2) it never bamfs more than ~1.5 laps of height; (3) it is never
invisible-and-unhittable for more than ~4s (the watchdog); (4) killing it pays
points to you and moves the luck bar; (5) the next appearance is exactly 4
rounds after the unlock round.

**BREACHER** — buy the lap-30 door. Expect fast charred sprinters with an amber
aura. Confirm: (1) the 1.5s wind-up is audible and visible *before* the blast;
(2) killing it mid-wind-up still detonates; (3) the blast kills nearby normal
zombies but **no** Panzer / Protector / Reaver; (4) SUPPRESSING FIRE (HK21) does
not slow it and IMPACT ROUNDS does not chain-detonate a cluster; (5) standing on
a breather balcony is no longer free.

**BULWARK** — buy the lap-40 door. Expect a teal toxic zombie at normal pace.
Confirm: (1) shooting it from **above** shows visibly smaller crosshair damage
numbers than shooting it from level or below — that contrast IS the tutorial;
(2) it can always be outrun and never corks the stairs; (3) SUPPRESSING FIRE
does not slow it and Thor's Thunder does not one-shot it; (4) the resistance
never applies to a **melee** hit (the Slasher has to stay viable against it).

---

## 8. ACCEPTANCE CHECKLIST (brief §7)

- [x] Every candidate named, with source path and a reuse / build / reject call — §1.2, §1.3
- [x] Three picks mapped to unlock slots, with HP, cadence, cap, rewards and verb — §2–§5
- [x] Implementation plan: exact files, zone lines, build order, one per build — §6
- [x] `is_boss` on all three, and the 8 consumer systems audited — §1.4.5
- [x] `lint_tod_arity.js` clean / fresh `.ff` / errorlog — **BUILD 1 done**
      (88.21 MB fresh, 9 waived errors, 0 new); builds 2-3 pending
- [x] Test script per enemy — §7
- [x] `CHANGELOG.md` entry plus this doc — v9.20 entry landed with build 1;
      builds 2-3 get their own

---

## 9. DECISIONS (user, 2026-08-22)

1. **Slots: 20 / 30 / 40.** Floor 60 does not exist on a 50-floor tower;
   matching the three reserved `breather_unlock` cases. ✅
2. **Repeating cadence, anchored to the unlock round** — like the Protectors,
   not a global round grid. A fast climber and a slow climber get the same
   fight relative to their own unlock. ✅
3. **Additive**, not replacing. The endless-rounds flow needs the horde to keep
   spawning for the next round to start, so nothing throttles zombie feed. ✅
4. **Picks: REAVER (20) / BREACHER (30) / BULWARK (40).** The originally
   proposed SAPPER was cut — see §5. ✅
5. **Pack dependency accepted.** The Reaver rides HB21's Apothicon Fury pack —
   already installed, and the same class of dependency as the shipped Panzer and
   Rogue Protector. ⚠️ **HarryBo21 must be credited before publish** (add to the
   credits alongside Spiki and the Civil Protector pack author).
6. **HP anchoring: keep the shipped asymmetry** — cadence anchors to the unlock
   round, HP to a fixed round constant, exactly as the Protector already does.
   Left as-is deliberately rather than by accident.

### Still open / owed

- ~~**Banner art.**~~ **CLOSED, and the whole lane with it (v9.21).** The user:
  "remove all the announcement banners for the enemies spawning in. Its
  unnecessary." No banner art is owed for any elite, and **builds 2 and 3 must
  not add a banner**. Enemies announce diegetically: Panzer music, the Reaver's
  meteor streak, the Protector slam, and the floor gauge's boss pip.
- **`CLAUDE.md` is stale** (§1.1): still describes the v6 25-floor tower with
  breathers at 5/10/15/20. Not touched in this build — it is a shared file and
  a doc-only change, worth its own pass.
- **Live tuning.** Every number in §3 is a first pass. The Reaver's HP curve
  (20k @ r20, ×1.08), the 4-round cadence and the roof of 3 all want a play
  session before they are trusted.
