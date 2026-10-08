# v15 — the 26-item work list (user 2026-08-31)

Master tracker for the batch of asks opened 2026-08-31. **This file is the
checklist; the per-item detail lives in the cited source lines.** Status keys:
`OPEN` · `DECIDED` (design settled, not built) · `BLOCKED` (needs a user
observation or a probe) · `DONE` · `NO-OP` (already true in shipped code).

Research provenance: 11 parallel read-only investigators + synthesis,
2026-08-31. Every file:line below was read, not grepped.

> **BUILD 1 SHIPPED 2026-09-01 00:18** — `-GscOnly`, fresh .ff 112.55 MB, all
> four lints green (arity, lua, hints 83/250, weapon/PaP), freshness proven by
> the three-way diff (scripts/ + zone_source/ + ui/ all clean).
> **In this build:** 3 · 6 · 7 · 9 · 11 · 12 · 13 · 14 · 15 · 17 · 19 · 21 ·
> 23 · 24 · 25 · 26, plus item 2's roof-bypass fix and three dev probes
> (items 2, 4, 20).
> **Card art still owed** for 21/23/25 + the DR pip change — see `docs/56`.

---

## 0. The items at a glance

| # | Ask | Status | Build | Effort |
|---|-----|--------|-------|--------|
| 1 | Spire hubs → mini-boss rooms | DEFERRED — after item 2 is verified in a real run | GscOnly | S |
| 2 | Spire rounds don't continue | **PARTIAL** — roof-bypass fixed + probe shipped; watchdog pending your observation | GscOnly | M |
| 3 | DR nerf | **DONE** — cap 5 + 5-pip card art installed | full | S |
| 4 | Overdrive buff on Death Machine | **PROBE SHIPPED** — measure before buffing | GscOnly | S |
| 27 | Melee too weak on the Panzer | **DONE** — x2 on the Panzer lane only (15 swings -> 8) | GscOnly | S |
| 28 | HANDLING to 4-5 tiers | **CLOSED, NOT SHIPPED** — user chose to leave it at 3 tiers (2026-09-01), see below | — | — |
| 5 | Death Machine bullets wrong | BLOCKED on one observation | ? | S–M |
| 6 | Low-clip guns flash red at full mag | **DONE** — clip size learned, engine dep removed | Lua | S |
| 7 | Dual-wield shows one clip | **DONE** — combined doubled number via `_rdw` test | Lua | S |
| 8 | UI error when a player goes down | PARTIAL — 3 real races, error unattributed | GscOnly | M |
| 9 | Downed player should get a card | **DONE** — crawler in, dead out, tier card refused | GscOnly | S |
| 10 | Class art rework + show secondary | OPEN — art batch scope | art / full | L |
| 11 | Secondaries don't pack at the spire | **DONE** — `pap_secondary()` | GscOnly | S |
| 12 | HUD +15% | **DONE** — `TodScaleHud` + per-widget anchors; verify in play | Lua | M |
| 13 | Upgrades on the scoreboard | **DONE** — text rows, personal, 16-row pool | Lua | M |
| 14 | Teleporter slows zombies | **DONE** — 256u / 0.5 / 3s via `slow()` | GscOnly | S |
| 15 | Downed player still teleports | **DONE** — ride-along; ⚠️ TEST REVIVE AT ARRIVAL | GscOnly | S |
| 16 | Left stick still moves upgrade menu | **CLOSED — user: no changes for now** | none | — |
| 17 | Class select → 60 s | **DONE** — quarter-second encoding, no new bit | GscOnly | S |
| 18 | Max luck + tier card | **NO-OP — already exactly this** | none | — |
| 19 | Tier promotion stops resetting upgrades | **DONE** — default flipped, 13 exceptions, `reset_gun_state` audited, Lua inverted | GscOnly | L |
| 21 | DAMAGE 12% → 10% | **DONE** — art installed + packed 2026-09-01 | full | M |
| 22 | Scavenger primary only | **DONE** — card now reads PRIMARY KILLS: AMMO BACK | art | S |
| 23 | GIANT SLAYER 8% → 15% | **DONE** — art installed + packed 2026-09-01 | full | S |
| 24 | New LMG sustained-sprint speed domain | **DONE** — FULL STEAM id 42 + art, MOBILITY retired, heavy 0.80 | full | M |
| 25 | Speed upgrades → 5/4/3/3… ladder | **DONE** — generic art installed + packed | full | M |
| 26 | Pause menu shows the exact upgrade number | **DONE** — `speedPct()` in the DETAIL rows | GscOnly | S |

**Two items need no code at all** (18, 22). Resist writing a second guard on
top of a working one — that is how the boss-music refcount bug was made.

---

## 1. Spire hubs → mini-boss rooms — OPEN

**There are no breather rooms in the spire.** The hubs are open gold balconies
(`tools/gen_tower_map.js:4750-4766`) — no roof, no walls, no doorway. The
CLAUDE.md phrase "gold hubs every 10th floor" is the whole truth.

An arrive-fight-then-buy loop **already exists on every spire floor**: a 30 s
door seal plus up to 4 honour-guard Panzers.

Two very different builds:
- **(A) Kill-gated boss on the existing balcony** — script only, one `-GscOnly`.
- **(B) Actually build rooms** — generator change, geometry, LED bake gate,
  `lint_tod_geometry.js`, `.map` regen, full build.

⚠️ **DO NOT SHIP BEFORE ITEM 2 IS FIXED AND VERIFIED IN A REAL RUN.** A hub boss
spends from the exact actor pool item 2 is starving, and must count into
`elites_all_alive()` (`_tod_bosses.gsc:521-530`) or it repeats the honour
guard's existing roof bypass — which is candidate #2 for the stall.

---

## 2. Spire rounds don't continue — BLOCKED (highest priority)

Under the endless-rounds twist **a spawn-throughput stall *is* a round freeze**:
the next round starts when the last zombie *spawns*, so if nothing can spawn,
the round counter simply stops. `_tod_endless_rounds.gsc:682-685` is an
unbounded drain loop with no watchdog.

Root cause **not reduced to one line.** Ranked candidates:
1. Actor-pool saturation — the spire runs `TOD_SPIRE_ELITE_MULT` 4 against a
   60-actor ceiling (`_tod_bosses.gsc:100-111`: `TOD_ELITE_ROOF_ALL` 12 +
   `zombie_ai_limit` 45 ≈ 57 of 60).
2. The door honour-guard's roof bypass — `_tod_spire.gsc:899` checks only
   `tod_panzer_alive`, never `elites_over_roof()`.
3. A `tod_lane_seal_*` that never clears.
4. **Navmesh coverage per floor** — the spire was seeded in v14.19 with 22
   `node_pathnodes` (generator §6f), which may not cover all 100 floors.
5. Spawn-point selection starving on the detached island.

**Ship the watchdog regardless** — it makes the reported symptom impossible
whichever candidate is true. Plus the roof-guard fix and a dev probe printing
`zombie_total` / `get_current_zombie_count` / `get_current_actor_count`.

**BLOCKING OBSERVATION NEEDED:** did the round number freeze *while zombies kept
spawning and dying*, or did zombies *stop arriving / stand still ignoring you*?
First = throughput wedge (candidates 1-3, all `-GscOnly`). Second = navmesh
(candidate 4, a **full build** with per-floor seeding).

---

## 3. DAMAGE REDUCTION nerf — DECIDED

**Cap everyone at Lv5 (−25%).** Today `-5%/Lv × 10 = ×2.00 effective HP`,
class-agnostic, promotion-proof, death-proof — worth more than a second
Juggernog, and the strongest survivability item in the map.

- `_tod_upgrades.gsc:681` — `max 10 → 5`; the `bonus_class`/`bonus_max` args
  (slasher+skirmisher capped at 5) become redundant → drop both.
- **NO CARD RE-BAKE** — the card text is per-card increments and the pips come
  from the server. This is the cheap shape on purpose.
- ⚠️ The value is a **bare `0.05` literal in two places** with no `#define`:
  `_tod_bosses.gsc:1984` and `:2578` (the latter carries a stale "−4%" comment).
  Add the `#define` while here.

## 21. DAMAGE 12% → 10%/Lv — DECIDED

12 sites, 2 load-bearing. Peak multiplier ×2.20 → ×2.00 = −9.1% on everything.

⚠️ **The lockstep that bites: the hand-copied `0.12` at `_tod_bosses.gsc:2721`**
(Rogue Protector `aiOverrideDamage`). Its HEADSHOT twin already went stale once
and overpaid 2.5×.

Re-bake `i_tod_card_damage_{regular,super,ultimate}.png` (+10/+20/+30).

## 23. GIANT SLAYER 8% → 15%/Lv — DECIDED

`_tod_upgrades.gsc:768`, max 5 → **+75% vs the boss/elite triad**.
Re-bake `i_tod_card_giant_slayer_{regular,super,ultimate}.png`.
Update the stale `domain_id` comment at `_tod_upgrade_ui.gsc` ("8% since
2026-08-31") and `docs/51_giant_slayer_8pct.md`.

⚠️ **Coupling C4:** items 3, 21, 4 and 23 all move the same additive sum in
`upgrade_damage_cb` (`_tod_upgrades.gsc:3959-3982`). Lowering DAMAGE makes every
*conditional* term relatively stronger. **Tune item 4 after item 21 lands.**
All four feed `docs/armory.html` — one republish at the existing URL covers them.

---

## 4. Overdrive buff on the Death Machine — BLOCKED

⚠️ **THE PREMISE IS UNVERIFIED AND IT IS THE WHOLE ITEM.** OVERDRIVE's only
input is the per-shot `weapon_fired` notify, and **the Death Machine is the only
`fireType "Minigun"` weapon in the map** (everything else is Full Auto / Melee /
Single). If that notify is per-trigger-*pull* rather than per-*bullet*,
OVERDRIVE pays **zero** and no percentage helps.

Two GSC files assert per-bullet in comments **with no cited source**, and both
were written when OVERDRIVE lived on the MP7 — a Full Auto SMG. The `#define`
comment still says "OVERDRIVE (MP7)". This is the `check-passes-wrong-question`
shape: the symptom is an absence.

**Probe first** (dev print: fire streak + `ammoInClip` + weapon name while
holding the trigger). Then, real regardless of the probe: +60% is additive into
a 2.20 sum = **+27% actual DPS**. Proposed `overdrive_pct`
`0.05/0.08/0.12 → 0.08/0.14/0.20`. **No card re-bake** — the cards read
"SUSTAINED FIRE HITS HARDER" with no numbers.

## 5. Death Machine bullets — BLOCKED

Root cause **not determined**; the investigator refused to guess. Weapon data is
byte-identical to the port, and every bullet gun in the map shares
`tracerType "smg"`, so a DM-only tracer bug is ruled out.

**BLOCKING OBSERVATION NEEDED:** is it the **ammo numbers** (should read 150/600
unpacked, 188/752 packed), the **red flash** on that number, or the **tracers /
muzzle flash / impacts** in the world?

Note it does **not** share a cause with item 6 — at threshold 7 the DM reds at
7 of 150. It **may** share a cause with item 4 (both are the minigun fire path);
one dev print covers both.

---

## 6/7. `AetheriumLoadout.lua` — READY (ship as ONE commit)

**Item 6 — low-clip guns flash red at full mag.** Two defects in five lines at
`ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumLoadout.lua:294-301`:
an unverified `currentWeapon.maxAmmoInClip` with an `or 30` fallback (making the
threshold a constant 7 for *every* gun) and a `math.max(3,…)` floor (the RPG is
red at full, always). Confirmed target: PaP'd MR6 = **"Death & Taxes"**
(`ZMWEAPON_PISTOL_STANDARD_UPGRADED`). Fix by deriving clip size from a running
max per weapon — that removes the engine dependency entirely, so it is correct
whichever branch is live.

**Item 7 — dual-wield shows one clip.** Not a bug, a missing feature: the left
hand is a separate weapon object (`weapon.dualWieldWeapon`, stock
`player_shared.gsc:268-270`) that no model in our widget subscribes to.
**Exactly two guns affected:** PaP'd `t9_amp63` (slasher T1 sidearm) and PaP'd
`t6_executioner` (assault T3 sidearm) — both PaP to `_rdw_up` forms.
**Decision: one combined doubled number** (Lua-only, `_rdw` name test). Two
separate numbers needs 5-6 clientfield bits that do not exist (see C3).

⚠️ **C6:** item 6's threshold rewrite must consume item 7's doubled number, or a
PaP'd AMP63 flashes red against the wrong denominator. Both must preserve the
two hand-applied STATE-POOL LEAK fixes at `:170-182` and `:256-264`. Kill the
stale comment at `:527-528` in the same pass.

---

## 8/9. The down path — ship 8 first or with 9, never 9 alone

**Item 8 — UI error on going down.** Three real races proven on that exact
transition. **But no unguarded nil exists in either Lua panel** — both audited
line by line — so the reported error number is still **unattributed**. Highest
value: stop handing a known-dead menu handle to `CloseLUIMenu`
(`_tod_upgrade_ui.gsc:441-442`) and stop relying on the 0.4 s coincidence
between `ensure_upgrade_list`'s `wait 1` and `player_lui_life`'s 0.6 s reopen.
*Ask the user for the error number and whether the player was crawling or
spectating.*

**Item 9 — downed player gets a card.** Four deliberate gates. The strongest
original justification (the bleedout clock) is **already refunded** at
`_tod_upgrades.gsc:2579-2580`, and the pause is capped at 20 s at `:2513`.
**Defaults taken:** last stand participates (`:2470` drops the laststand
clause); dead/spectating stays out (their LUI menu does not exist); **the TIER
card is refused while crawling** — `tier_up` runs `swap_primary` on a player
holding the last-stand pistol.

⚠️ **C7:** item 9 puts *more* players through the transition item 8's races live
on.

---

## 10. Class art + show the secondary — OPEN

The class cards are the **oldest surviving art in the map** — only skirmisher
and assault were ever re-baked for the tier roster. **Every player-visible
string on that panel is baked into a PNG**; the Lua text stack is dead fallback.

Four 224×196 `i_tod_class_*` icons ship in the `.ff` and are **unreachable** —
`tod_class_select.lua:54-56` forces the flag false.

**The secondary is shown nowhere, in art or text** — but it costs **zero
clientfield bits**, being a pure function of (class, tier), both already
client-side. The twelve sidearms are at `_tod_classes.gsc:99-110`.

Naming drift to fix: the art says "KATANA", the registration is
`t9_me_wakizashi`.

## 22. Scavenger primary only — NO-OP

**Already implemented since 2026-08-26.** The gate is `_tod_upgrades.gsc:4691`
(`lvl > 0 && is_primary`), fed by `tod_classes::is_class_primary`
(`_tod_classes.gsc`), and a sidearm kill does not even advance the counter.
Verified independently: all twelve secondary stems checked against all twelve
primary stems — no substring collision, so the gate cannot leak.

**The only real work is art:** four of five user-facing strings say "primary";
the card (`i_tod_card_reserve_*`) is the one that just says "AMMO BACK ON KILLS".

*If the user insists they saw otherwise, the discriminator is a dev print of
`is_primary` + `damageweapon.name`.*

## 18. Max luck + tier card — NO-OP

**Already exactly this, at both 100 and 150 luck.** `roll_options` puts the tier
card in the right slot (`_tod_upgrades.gsc:2821-2822`), and both guarantee paths
skip `o.domain == "tier"` (`:2911-2912`, `:3059-3060`), leaving slot 0 a real
full-paying ULTIMATE.

Most likely source of the mismatch: **the invisible 101-149 luck band.** The HUD
caps at 100, so a bar that looks "full" may be the single-promotion path, not
overcharge. *Discriminator: the **raw** luck value at the deal.*

---

## 11. Secondaries don't pack at the spire — READY

Confirmed: `grant_all` (`_tod_spire.gsc:549-655`) never touches the sidearm.
`tod_pap_owned` is consumed only by `reconcile_twin`, which stem-matches the
**class primary** (`_tod_upgrades.gsc:2150-2151`).

Fix: new `tod_classes::pap_secondary()` called at `_tod_spire.gsc:575`, after
the tier climb. Verified all twelve secondaries have a valid `upgrade_name` row
in `gamedata/weapons/zm/zm_levelcommon_weapons.csv`, so PaP is possible on every
one.

## 12. HUD +15% — READY after a 1-line probe

Layout is **~640 hard-coded pixel rects in a 1280×720 canvas with no scale
factor anywhere.** A single root `setScale` is **not** a partial win — content
is pinned to four corners, and scaling up pushes it off-screen.

Fix = per-widget `setScale(1.15)` **plus a derived box offset per anchor**:
`L = (xa − 640)(1 − s)`.

**The cursor-hint prompts are the one genuine one-liner** — all nine cards are
children of one container (`AetheriumHud.lua:204`). That covers the ammo crate
and altar trigger UI the user named.

⚠️ Unproven: whether `setScale` propagates to children and scales about the
element's centre. **There is no LUI core Lua anywhere on this machine** — the
runtime is compiled into the game. One 1-line probe build settles it.
**Default scope:** Aetherium chrome + prompt cards only; gauge, luck bar, damage
numbers, scoreboard and reticle left alone.

## 13. Upgrades on the scoreboard — READY

**`CoD.TodOwned` is already populated for a client whose pause menu was never
opened** — the push chain is GSC spawn → the always-open `tod_upgrade` HUD menu,
and `AetheriumStartMenu.lua:532` is a plain read. The scoreboard is a HUD widget
with **no focus lock**, so the user's premise (players can move and read) holds.

Build rows in the `Visible` clip (re-runs per open), not in `new()`. Free band
y ≈ 95-390. Reuse the zoned `i_tod_pause_*` art = no GDT, no zone lines.
**Default: personal list only** — all-players needs an untested 4th
`LuiNotifyEvent` int arg.

⚠️ **C8:** the item-12 pass explicitly leaves `AetheriumScoreboard` at scale 1.0,
so these new rows must be authored at native size.

## 14/15. Teleporters — one file, one build

**Item 14 — slow zombies in the radius.** Feature absent; nothing in
`_tod_teleport.gsc` touches zombies. The lane already exists and is
keep-alive-safe: `tod_zombie_speed::slow()` (`_tod_zombie_speed.gsc:361-382`) is
re-multiplied in by the 1.5 s sweep at `:340`. ⚠️ **Must go through `slow()`,
never a raw `ASMSetAnimationRate`** — the sweep would stomp it within 1.5 s.
Elites immune by construction. **Defaults: 256 u / 0.5 rate / 3 s, departure pad
only.**

**Item 15 — downed player still teleports.** Two gates, both in
`_tod_teleport.gsc`: `is_player_valid` at `:328`/`:513` (its laststand branch)
and `in_revive_trigger()` at `:338-342` (a crawler always stands in their own
bubble). **Precedent exists twice** — `_tod_finale.gsc:1090-1116` and
`_tod_spire.gsc:253-275` both move downed players deliberately.
**Default: ride-along only, no self-activation** (a crawler yanking their own
body out from under a reviver is the risk). One-line change at `:513`.

⚠️ **HIGHEST-COST UNPROVEN LINK IN THE WHOLE LIST:** whether a `LinkTo`'d revive
trigger follows a hard `SetOrigin`. `_zm_laststand.gsc:849-852` links it, which
*should* track, but this cannot be proven from source. **If it does not follow,
the teleported crawler is unrevivable at the destination.** Test in game:
crawler on pad → ride → teammate revives at arrival.

## 16. Left stick still moves the upgrade menu — OPEN

Root cause is a **circular latch**: the stick lane is gated on
`self.tod_input_pad` (`_tod_upgrade_ui.gsc:1022`), which **only a d-pad press
can arm** (`:1004`, `_tod_class_select.gsc:247`). So a player who never touches
the d-pad keeps the stick forever — exactly the reported symptom.

Fix = **delete the movement lane outright** (`:1032-1043`, `:1054-1064`), don't
tighten the latch.

⚠️ **This kills the left stick AND WASD/arrows for everyone.** Keyboard keeps
MOUSE1/MOUSE2/V/R and hold-SPACE/F — the only lane the UI actually advertises.
That contradicts the 2026-08-24 "WASD, up left down right" ask. **There is no
server-side device detection**, so both directives cannot hold at once.

## 17. Class select → 60 s — READY

One `#define` (`_tod_class_select.gsc:39`) — **but 30 was chosen to exactly fill
4 bits.** `todUpgTime` is halved into a 4-bit field (max 15) and decoded ×2 in
`tod_class_select.lua:340`. **60/2 = 30 does not fit.**

**Recommendation: do not spend the last free clientfield bit** (see C3). Use
4-second ticks (60/4 = 15, fits exactly) or ride the idle 6-bit `todUpgAD`.

Side effect: an early-locking player now stares at an empty base for ~59 s. The
specced `i_tod_hint_waiting` plate was never made.

## 19. Tier promotion stops resetting upgrades — OPEN (the large one)

Fully mapped: **33 live domains** (CLAUDE.md's "34" is stale). One authority,
`domain_survives_tier` (`_tod_upgrades.gsc:1200-1207`).

Fix = **flip the default at `_tod_upgrades.gsc:1164`** and list the ones that
still reset. **Do not touch the authority function.**

**Proposed reset list — 13 domains:**
- 6 real weapon-variant ladders: MAG SIZE, FIRE RATE, HANDLING, RECOIL,
  KNIFE SPEED, PENETRATION
- 7 uniques bound by `gun_keys` to a specific tier gun: ADRENALINE, OVERDRIVE,
  SECOND WIND, SUPPRESSING FIRE, **DRAW CUT** (the user's own example),
  FORCED MARCH, THOR'S THUNDER

**The other 20 persist** — including DAMAGE and BOUNTY, and SCAVENGER for the
skirmisher and heavy too, not just the assault.

⚠️ **THE GUN-BOUND UNIQUES MUST KEEP RESETTING.** `unique_damage_mult` does no
weapon test — `:3953`: *"gun_keys gates what you can ROLL, never what fires"* —
so a persisted DRAW CUT would pay **+150% on the STORMBREAKER**.

Also audit `reset_gun_state()` (`:3630-3641`), which still wipes SCAVENGER /
KILL RELOAD / BOUNTY counters.

⚠️ **C2:** this makes a tier promotion cost almost nothing (a skirmisher's worst
case falls from ~42 lost levels to ≤8). Combined with item 18's guaranteed
ULTIMATE alongside the tier card, the tier card becomes close to strictly better
than any other draw. It also breaks the pause panel's arithmetic:
`AetheriumStartMenu.lua:644` `ROWS_MAX 7` × 2 columns = 14, justified at
`:628-633` by "gun-bound domains zero out on promotion" — **a maxed HEAVY now
reaches 15 rows.** Degrades gracefully to "+1 MORE", but the comment must be
rewritten and **item 13's scoreboard pool must be sized for 16 rows, not 14.**

✅ **C10 — item 19 does NOT force a tier-card re-bake.** The footer on all eight
`i_tod_card_tier_*` PNGs reads "NEW WEAPON · GUN UPGRADES RESET", which stays
literally true (gun-scoped domains still reset). Verified by opening the PNGs.

---

## 24. New LMG sustained-sprint speed domain — DECIDED

**User decisions:** 5 levels × 10%/Lv; **MOBILITY retired**; heavy base
`class_speed_base()` **0.75 → 0.80**.

- New domain id **42** (41 = `distraction` is the highest used).
- MOBILITY id 9 **stays mapped** in `domain_id()` and the Lua tables (key-keyed
  maps — a stale case is inert, and removing one risks disturbing ids the pause
  plates depend on). Only the `add_domain` call goes. Heavy is MOBILITY's only
  class, so unscoping it retires the domain outright.
- Art slug: follow the **IMPACT ROUNDS precedent** (2026-08-31) — an unreachable
  slug is dead weight in the `.ff`, so drop `CARD_SLUG[9]` and the three
  mobility zone lines; keep the PNGs in `source_data`.
- **Implementation lane:** an additive term in `apply_move_speed()`
  (`_tod_upgrades.gsc:1414`), shaped exactly like `adren_bonus()` (`:1601`).
  **NEVER call `SetMoveSpeedScale` directly** — `apply_move_speed` is the single
  owner, `body_systems_loop` re-asserts it every second, and a direct writer
  would defeat the `menu_freeze` 0.001 pin at `:1417-1421`.
- Drive it from the existing 20 Hz watcher in `_tod_uniques.gsc:69-86`
  (`TOD_SPRINT_POLL 0.05`), edge-triggered — 1 s is far too coarse.

⚠️ **KEYED ON SUSTAINED SPRINT:** `IsSprinting` drops when the movement input
goes off-axis, so a strafe mid-run breaks the latch and restarts the arm clock.
Engine behaviour, no script lever — accepted, and documented at the latch.

⚠️ **CONFLICTS WITH ITEM 25** — see below.

## 25. Speed upgrades → 5/4/3/3… ladder — OPEN

User: *"nerf the speed boost upgrade in general. It should be 5%, 4%, 3%, then
3% each level after."*

Today `TOD_UPG_SPEED_PER_LVL 0.05` (`_tod_upgrades.gsc:171`) is a **flat shared
constant**, summed at `:1427` as `lvl * TOD_UPG_SPEED_PER_LVL` where `lvl` is
sprint + mobility + march (safe today because they are per-class exclusive).

New ladder — cumulative: **5 / 9 / 12 / 15 / 18 / 21 / 24 / 27 / 30 / 33%**.
Replace the multiply with a `speed_pct_for_level()` stage table.

**Affected domains:** SPRINT (skirmisher/slasher, max 10 → 33%), FORCED MARCH
(assault, max 5 → 18%). MOBILITY is retired by item 24.

**Art consequence:** the value stops being linear, so per the
domain-retune checklist the cards **must become level-agnostic** — re-bake
SPRINT and FORCED MARCH cards to generic copy ("MOVE FASTER"), no number.

❗ **DIRECT CONFLICT WITH ITEM 24.** Item 24 was specced at 10%/Lv × 5 = **+50%**.
If the 5/4/3/3/3 ladder applies to it too, it becomes **+18%** — and combined
with the heavy base rising to 0.80, the sprinting ceiling changes from
`0.80 × 1.50 = 1.20` to `0.80 × 1.18 = 0.944`. **These are very different
designs and the user must pick.**

## 26. Pause menu shows the exact upgrade number — READY

Rides item 25. The lane is `DETAIL[id].val` via `CoD.TodDomainDesc` (per the
domain-retune checklist). Server-computed values are already packed into the
`tod_upg_sync` max args, so the number can be shown per player without new
clientfield bits.

---

## 5. Build batching

**Build 1 — `-GscOnly`, GSC only. "Bugs and probes." SHIP FIRST.**
Items **2** (watchdog + roof guard + lane-seal clear) · **11** · **16** · **8** ·
**9** · **15** · **14**. Plus two dev-gated probes that cost nothing and
unblock two items: the spire three-counter print (item 2) and the OVERDRIVE
fire-streak print (item 4).
Gates: `lint_tod_arity.js` + the automatic hint/Lua lints. **Zero new hint
strings** — the 140/250 triggerstring budget does not move.

**Build 2 — `-GscOnly`, Lua only. "HUD."**
Items **6** + **7** (one commit, same file) · the item **12** `setScale` probe ·
the item 12 prompt-card one-liner · item **13** if approved.
⚠️ Freshness proof **must** include the `diff -rq ui` line — a Lua-carrying
change is invisible to the old two-line check (v14.18 postmortem).

**Build 3 — `-GscOnly`. "Balance and rework," after the probes report.**
Items **19** (own commit) · **3** · **23** · **24** · **25** GSC half · **26** ·
**4** tuning · **20** if the dvars are registered · **17** · **12** full scaling.
Republish `docs/armory.html` at its existing URL after 3/4/19/21/23/24/25.

**Build 4 — FULL. "Art and geometry."**
Card re-bakes (**21** DAMAGE, **23** GIANT SLAYER, **22** SCAVENGER wording,
**25** generic speed cards, **10** class + tier cards) · **1B** hub rooms if
rooms were chosen · **2** per-floor navmesh seeding if the observation points
there · **5** if it turns out to be a generator/GDT change.
⚠️ After it, prove the images actually packed with a **fresh content-hash `.iwi`
plus an untouched control** — a `.ff` raw grep is invalid and a stale `.iwi`
passes every other gate. LED bake is **pass/fail only**; run
`measure_lit_area.js` for the budget question.

## Item 28 — HANDLING stays at 3 tiers (user decision, 2026-09-01)

Asked for 4, then 5. Neither fits: the map ships **223** weapon-asset
registrations (191 generated + 32 fixed — MEASURED, see below), the empirical
wall is ~230 (map 1 shipped a booting 229 and boot-AVed at 368), and HANDLING
at 4 levels costs **235**, at 5 **247**. `gen_tod_twins.js` says it in as many
words: *"DO NOT RAISE THIS AGAIN to buy a THIRD axis... Buy budget back by
retiring an axis instead."* Presented to the user as leave-at-3 / retire-an-axis
/ re-implement in script / raise-and-test; they chose **leave it at 3**
(15 / 25 / 35%).

> ⚠️ **223 IS LIVE AND BELIEVED FINE, NOT BOOT-PROVEN.** It is in every `.ff`
> since 2026-09-01 01:36, but nobody has pointed at a boot of a 223-ledger
> build. The ~7 units of margin are assumed, not measured. One reported boot
> converts it, and it is worth asking for explicitly rather than waiting.

**To revisit this cheaply** — a workflow that did not exist before 2026-09-01:
the generator now runs its ledger check **before** its three `writeFileSync`
calls. It used to write all three and throw afterwards, so *"it throws"* was
never *"it did nothing"* — all three outputs carried the mtime of a failed run,
and the ledger could not be read without mutating the tree. Now you can set
`AXIS.h.levels` to 4, run it, read the number, and if it is over budget
**nothing on disk moves**.

> The general shape, worth keeping: **a guard that runs after the writes is not
> a guard on the writes, it is a report.** It fired visibly every time and
> protected nothing.

**Sequencing constraints:** 2 before 1 (shared actor pool) · 8 before or with 9
(shared transition) · 21 before 4's tuning (shared additive sum) · 19 before
13's row sizing · 6 and 7 together · 25 decided before 24 is built.
