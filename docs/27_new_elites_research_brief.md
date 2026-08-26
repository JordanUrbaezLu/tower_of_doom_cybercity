# TASK BRIEF — three new ELITE enemies for `zm_tower_of_doom`

> Hand this whole document to the AI doing the work. It is self-contained.
> Written 2026-08-22 against build v9.18.

---

## 0. YOUR ROLE AND WHAT "DONE" MEANS

You are working on a **Call of Duty: Black Ops III custom zombies map**
(`zm_tower_of_doom`), a real, shipping project with a long history of
hard-won engine lessons. Your job in this task is **research and design
first, implementation second.**

**Deliverable, in this order:**

1. **A research report** — what enemy AI this game/toolset can actually give
   us, what is already installed on this machine, and what the sister map
   already built. Include what you ruled out and *why*.
2. **Three concrete recommendations** — the 3 elites to add, each with a
   one-line pitch, the assets it needs, and an honest difficulty/risk rating.
3. **A design spec per enemy** — behaviour, threat model, HP curve, rewards,
   how it reads on a vertical map, how it differs from what we already have.
4. **An implementation plan** — exact files, exact zone lines, build order,
   and a test script the user can follow.
5. **Only then**, if the user approves the picks, implement them **one enemy
   per build**.

**Do not start writing GSC before step 2 is agreed with the user.** Enemy
work touches the most crash-prone parts of this engine, and the user has
already lost play sessions this week to changes that "built fine" and then
broke at runtime.

---

## 1. THE MAP IN ONE PARAGRAPH

A **spiral tower, 50 floors**. A solid core with an open-air staircase
spiralling around the outside; you climb, buying a door per floor
(52 doors), fighting an endless horde. **The twist: rounds never pause** —
the moment the last zombie of a round *spawns*, the next round starts.
Four **breather balconies** at floors **10 / 20 / 30 / 40** are the rest
stops (they emit no zombie risers) and carry the perk machines, an upgrade
station and a Pack-a-Punch. At the very top is a floating citadel (the
"Crown") with the finale. Players pick one of **4 classes** (Skirmisher /
Assault / Heavy / Slasher), each with a **3-gun tier ladder**, and level up
through a **card-based upgrade system** (18+ domains, rarities, a luck bar).

Vertical space is the map's identity. **Any enemy you add has to make sense
on a staircase**: narrow treads, long sightlines straight up and down, and
players who are frequently above or below the thing hunting them.

---

## 2. WHAT ENEMIES EXIST TODAY (and the hook that is waiting for you)

Two, both ported from the sister map:

| Enemy | Cadence | Notes |
|---|---|---|
| **Panzer** (`archetype_zm_mechz_genesis`, Spiki mechz pack) | every 5th round | The heavy boss. Own music track, flamethrower, electroball, grapple. HP 25000 @ round 5, ×1.09/round. |
| **Rogue Protector** (`archetype_acc_zod_robot_boss`, HB21 civil-protector clone re-teamed axis) | a **wave** every 3rd round, size ≈ round×2 | Ranged robot. HP 7000 @ round 3 per unit, ×1.07/round. Concurrency roof 8. |

Everything lives in **`scripts/zm/zm_tower_of_doom/_tod_bosses.gsc`**
(cadence, HP curves, spawn placement, damage dispatch, rewards).

### ⭐ THE IMPORTANT PART — the map is ALREADY pre-wired for exactly this task

`scripts/zm/zm_tower_of_doom/_tod_doors.gsc::breather_unlock()` implements
"**every breather door you open introduces a new enemy type**", and **three
slots are reserved and commented out, waiting**:

```gsc
switch ( flag )
{
    case "enter_lap10": kind = "protector"; break;
    // case "enter_lap20": kind = "<enemy 2>"; break;
    // case "enter_lap30": kind = "<enemy 3>"; break;
    // case "enter_lap40": kind = "<enemy 4>"; break;
}
```

It stamps `level.tod_enemy_unlock_round[ kind ] = <the round it was opened>`
and fires `level notify( "tod_enemy_unlocked", kind )`. The cadence for that
enemy then **anchors to the round the door was opened**, not to a global
grid — see `_tod_bosses.gsc::protector_due()` for the reference
implementation. Never re-stamp an already-unlocked kind (it would shift the
cadence).

**So the intended shape of this feature already exists.** Your 3 enemies
should almost certainly fill `enter_lap20`, `enter_lap30`, `enter_lap40`.

### ⚠️ Resolve this with the user before designing

The user asked for elites at "**floors 20, 40, 60**". Two problems:

- **The tower is 50 floors.** There is no floor 60.
- **The breather/unlock slots are 20, 30, 40.**

Ask which they want:
- **(a) 20 / 30 / 40** — matches the existing hook and the rest stops. Recommended.
- **(b) Round-based instead of floor-based** (e.g. every Nth round after
  round 20/40/60), which is how Panzer and Protector cadence actually works
  once unlocked.
- **(c) Extend the tower** — a much larger change; do not assume this.

Note that unlock is *floor-gated* but cadence is *round-based* — both
concepts are live, so state clearly which you are using for each enemy.

---

## 3. WHERE TO SEARCH (paths that actually exist on this machine)

**Mod tools root:** `C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130`
(referred to below as `<TOOLS>`).

### Already installed enemy/character assets — start here, this is free work
`<TOOLS>\source_data\`:

| GDT | What it is | Status |
|---|---|---|
| `mechz_spiki*.gdt` (4 files) | Panzer | **in use** |
| `c_zom_zod_robot_protector.gdt` | Rogue Protector / Civil Protector | **in use** |
| `c_zom_dlc4_apothicon_fury.gdt` | **Apothicon Fury** — flying/charging Apothicon | installed, **unused here** |
| `_charred_zombies.gdt` | charred zombie models (sister map's Brutus rides `archetype_charred_zombie`) | installed, unused here |
| `acc_sat_toxic_zombies.gdt` | toxic zombie variants | installed, unused here |
| `c_zom_chomper.gdt` | Chomper | installed, unused |
| `c_zom_dlc3_dragon.gdt` | Dragon | installed, unused |
| `wpn_t7_zmb_dlc2_keeper_head.gdt`, `zm_zod_sword_egg_keeper.gdt` | Keeper assets | installed, unused |
| `p7_zm_zod_robot_gibs.gdt`, `zombietron_gib_chunk.gdt` | gib assets | support |
| `nsz_zombie_blood.gdt`, `t6_zombie_anims.gdt`, `t7_zombie_animations.gdt` | anims/misc | support |

`<TOOLS>\_custom\` also holds community packs (`_wetegg`, `_coolyer`,
`_moicesttom`, `westchief596`) — **audit these**, they may contain more.

### Stock behaviour trees / archetypes you can build on
`<TOOLS>\share\raw\scripts\shared\ai\archetype_*.gsc` — notable:
`archetype_apothicon_fury`, `archetype_thrasher`, `archetype_direwolf`,
`archetype_robot`, `archetype_warlord`, `archetype_clone`,
`archetype_human_riotshield`, `archetype_mannequin`, `archetype_civilian`.

`<TOOLS>\share\raw\scripts\zm\_zm_ai_*.gsc` — `_zm_ai_dogs`,
`_zm_ai_faller`, `_zm_ai_raps`, `_zm_ai_wasp`.

Also read `<TOOLS>\share\raw\scripts\zm\` broadly for margwa / parasite /
keeper / spider handling that DLC zones use.

### The sister map — the knowledge base, read it before designing
`c:\Users\jorda\Repositories\abandoned_cyber_city_zombies`

- **`docs/08_enemies.md`** — the full cast with tuned numbers and design
  rules. Its roster: regular zombie, **Shielded "Riot" elite**, **Brutus
  ("Trench Warden")**, **"Glitch Stalker"**, **Avogadro (cyberhacker)**,
  Panzer, Rogue Protector, **Apothicon Fury**. Several of these are *already
  built, tuned and play-tested* — porting one is far cheaper than inventing
  one, and this project's standing rule is to reuse that work.
- `docs/14_stock_api_verification.md` — stock-API traps ledger.
- `docs/16_community_techniques.md` — community techniques incl. AI/navmesh.
- Its `zone_source/zm_abandoned_cyber_city.zone` — shows the **exact zone
  lines** each enemy needs (aitype, spawner, character, scriptbundle,
  scriptparsetree, fx, beam...). Copy that pattern.
- Its `CHANGELOG.md` — searchable history of what broke and why.

### This map's own knowledge base
- `CLAUDE.md` (repo root) — conventions, doctrine, build commands. **Read first.**
- `docs/BO3_MAPMAKING_KB.md` — the canonical engine lessons.
- `CHANGELOG.md` — newest first; v9.13–v9.18 are this week and relevant.

---

## 4. HARD CONSTRAINTS AND TRAPS (each one cost a real play session)

These are non-negotiable. Violating them produces builds that **link
successfully and then fail at runtime**, which is the worst failure mode
here.

**AI / spawning**
- **`SpawnActor` only.** Map-authored actor spawners are dead for generated
  maps. Spawn bare at a navmesh-queried point. See `_tod_bosses.gsc` header
  comments — they list the exact traps (targetname must be defined and
  `!= "mechz_tomb"`; direct SpawnActor can miss archetype spawn funcs so the
  actor attacks but has no behaviour).
- **Naming is load-bearing:** spawner classname `actor_spawner_<X>` resolves
  to aitype `archetype_<X>`. A clone GDT whose first name lacks the
  `archetype_` prefix makes the engine derive the wrong name. (Sister map's
  zod-boss note documents this.)
- **The navmesh ignores ALL entity collision.** Any script-spawned solid
  needs `DisconnectPaths()` (and `ConnectPaths()` when cleared).
- **Every boss must carry `is_boss`** — the map's own systems key off it:
  zombie speed curve exemption, SUPPRESSING FIRE slow exemption, IMPACT
  ROUNDS splash exemption, Thor's Thunder immunity, luck-bar "last hit takes
  all". If you add an elite and forget `is_boss`, player upgrades will
  behave wrongly against it.
- **Endless rounds**: there is no gap between rounds
  (`_tod_endless_rounds.gsc` overrides `level.round_wait_func`,
  `level.zombie_round_change_custom`, `level.func_get_delay_between_rounds`).
  The next round starts when the last zombie **spawns**, not dies. Elites
  must not assume a round-end lull, and must not starve the AI budget — the
  engine has to keep feeding normal zombies. Respect the existing
  concurrency roof pattern (Protectors cap at 8).

**Build / assets**
- **A second stock `zm_pack_a_punch` zbarrier fatals the map load** — stock
  renames every one to a shared targetname then does a singular `GetEnt`.
  The general lesson: **before placing a second instance of any stock
  machine/entity, grep the stock script for a singular `GetEnt` on its shared
  targetname.** (Cost: one full rebuild this week.)
- **`level.player_too_many_weapons_monitor = false;`** is set in
  `zm_tower_of_doom.gsc::main()` and must stay off. Do not re-enable it.
- Weapon registrations are capped: ledger is **159 / 200 guard** (measured
  ceiling ~230 good / 368 boot-crash). If an elite needs weapons, count them.
- Every new script module needs a `scriptparsetree` line in
  `zone_source/zm_tower_of_doom.zone`; every new asset needs its own line.
- **Install-side pack dependency is real**: some archetypes only link because
  a GDT lives under `<TOOLS>\_custom` and `bin\converter_gdt_dirs_0.txt`
  line 1 is `_custom` (a Mod Tools "verify" resets it). If you depend on a
  pack, say so explicitly in the plan and credit the author before publish.
- **The `.map` is GENERATED** by `tools/gen_tower_map.js`. Never hand-edit
  `map_source/zm/zm_tower_of_doom.map` — it will be clobbered. Put changes in
  the generator and regenerate.
- **The LED bake is the gate** after any geometry/entity change to the .map.
  A crashed bake means you hit the lightmap-atlas ceiling.

**GSC dialect (this compiler is strict)**
- `function` keyword; `#using` before `#namespace`; **`#precache` only AFTER
  every `#using`/`#insert`** (between them = a "No generated data" compile
  kill); ternaries fully paren-wrapped; no `.field` on a parenthesized
  expression; `class` is reserved; `"power_on"` /
  `"initial_blackscreen_passed"` are FLAGS (`flag::wait_till`), not vars;
  never write `player.score` (use `zm_score::`); read-only damage callbacks
  **must `return -1`**.
- **No circular `#using`.** `_tod_upgrades` imports `_tod_powerups`, so
  `_tod_powerups` must never import `_tod_upgrades` — the codebase uses
  function pointers / latched flags to cross that boundary.
- Verify a namespace is imported before using it. `node tools/lint_tod_arity.js`
  passes arity but will NOT catch a missing `#using`.
- **No dev dvars, ever.** Dev/test is ONE compile-time flag,
  `level.tod_dev` in `zm_tower_of_doom.gsc::tod_resolve_dev_flags()`.
  Never tell the user to type console commands.

**Process**
- **Build it yourself; the user's job is to TEST.** `.\tools\build_map.ps1`
  (full) or `-GscOnly` for script/zone-only changes. Success = a **fresh
  `.ff`**, not the linker exit code. Check the errorlog.
- **One builder at a time across sessions.** Another Claude session works on
  this repo concurrently. Announce **BUILD START** and **BUILD DONE**, and
  check `tasklist` for `BlackOps3.exe` / `linker_modtools.exe` first —
  building while the game runs corrupts the sound banks.
- **`_tod_bosses.gsc` may be claimed by the other session.** Coordinate
  before editing it.
- **ONE ENEMY PER BUILD.** Never batch three new AI types into one build.

---

## 5. DESIGN CONSTRAINTS FOR THE ENEMIES THEMSELVES

- **Three distinct threat models.** We already have a slow bruiser (Panzer)
  and a ranged swarm (Protectors). Do not propose a third "big thing that
  walks at you". Aim for genuinely different verbs — e.g. something that
  **denies ground**, something that **forces you to move up/down**, something
  that **punishes camping a landing**, something **airborne** that ignores
  the staircase, something that **disables** (the sister map's Avogadro hacks
  machines).
- **They are ELITES, not bosses.** Lighter than Panzer. They should escalate
  the climb, not stop it. Give per-unit HP curves anchored at their unlock
  round with a per-round exponent (see the existing `*_HP_BASE` / `*_HP_EXP`
  pattern; zombies compound at ~1.10, Panzer 1.09, Protector 1.07).
- **Vertical legibility.** The player must understand where the threat is on
  a spiral. Note the existing `TOD_BOSS_FIRE_ZDELTA 300` rule — bosses only
  make ranged attacks within ~1 floor of height, so nothing snipes through
  floors. Respect or deliberately revisit that.
- **Co-op scaling** exists (`coop_hp_mult()`); solo must stay fair. The
  Protector wave size was already nerfed once for solo.
- **Rewards**: killing bosses pays points to every player and moves the
  **luck bar** (boss LAST HIT takes all). Say what each elite pays.
- **Audio/FX budget**: prefer FX and sounds that are already precached.
  New sound aliases mean CSV + `.szc` work and a bank rebuild.
- **No new art unless justified.** If an enemy needs a card/HUD banner,
  note it — the project's standing rule is that baked images beat LUI
  drawing, and the user generates art from prompts you supply.

---

## 6. QUESTIONS TO PUT TO THE USER (ask before implementing)

1. **Floors 20 / 30 / 40** (matching the reserved unlock slots) — confirm,
   since floor 60 does not exist on a 50-floor tower.
2. Should each elite, once unlocked, appear on a **repeating cadence**
   (like Protectors every 3rd round) or only in **scripted bursts**?
3. Should they **replace** some normal-zombie pressure or be **additive**?
4. Any enemy from the sister map they specifically want (Brutus / Glitch
   Stalker / Avogadro / Apothicon Fury / Shielded Riot elite), or all-new?
5. Is a **pack dependency** acceptable (external author, needs crediting),
   or stock/already-installed assets only?

---

## 7. ACCEPTANCE CRITERIA

- [ ] Research report names every candidate found, with source path and a
      reuse/build/reject call and reasoning.
- [ ] Three picks, each mapped to an unlock slot, with HP curve, cadence,
      concurrency cap, rewards, and threat verb.
- [ ] Implementation plan lists exact files, zone lines, and build order,
      one enemy per build.
- [ ] Every enemy carries `is_boss` (or a documented reason not to) and is
      exempt/handled correctly by: zombie speed curve, SUPPRESSING FIRE slow,
      IMPACT ROUNDS splash, Thor's Thunder, luck bar.
- [ ] `node tools/lint_tod_arity.js` clean; build produces a **fresh `.ff`**;
      errorlog shows no new lines beyond the 9 known-waived warnings.
- [ ] A test script the user can follow (dev flag on: what to do, what to
      expect, per enemy).
- [ ] `CHANGELOG.md` entry and, if the design is non-obvious, a `docs/` page.

## 8. EXPLICIT DON'TS

- Don't hand-edit the generated `.map`.
- Don't batch multiple new AI types into one build.
- Don't add dev dvars or ask the user to type console commands.
- Don't re-enable `player_too_many_weapons_monitor`.
- Don't place a second instance of a stock machine without checking for a
  singular `GetEnt` on its shared targetname.
- Don't claim it works because the linker said BUILD OK — runtime script
  fatals produce a clean linker log and a map that will not load.
- Don't re-learn lessons the sister map already paid for. Search its
  `CHANGELOG.md` and `docs/` first.
