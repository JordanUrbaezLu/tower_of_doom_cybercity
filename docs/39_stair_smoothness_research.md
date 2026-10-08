# 39 — STAIR SMOOTHNESS: research report

> User, 2026-08-27: *"We are getting a lot of complaints about how our stairs
> interact with players as they go up and down. On the way down they feel
> slippery and on the way up sometimes you get stuck on a stair. Those are just
> some examples of complaints. Overall the complaint is that they are not smooth
> enough when players go up and down."*
>
> And: *"Just report back. Don't solve yet."*
>
> **STATUS: RESEARCH ONLY. NOTHING IN THIS DOCUMENT HAS BEEN BUILT.** §6 is a
> proposal awaiting the author's decision, not a work log. No generator, script,
> GDT or lint file was modified for this report.

Seven research lanes fed this document; four were adversarially fact-checked and
the fact-check won every disagreement. Where the lanes could not settle a
question, **this document says so** rather than guessing. Read §8 before acting
on anything — several of the most attractive-sounding claims in this space are
unverified, and one of them (whether BO3's movement code snaps a descending
player back down onto the next tread) decides which half of the option space is
even relevant.

---

## 1. THE COMPLAINT, TRANSLATED

The complaint is two symptoms plus one summary. They are almost certainly not
the same defect.

| what the player says | mechanical hypothesis | where it is examined |
|---|---|---|
| "on the way down they feel **slippery**" | H1 — the player is *airborne* for most of a descent: no ground friction, air-acceleration only, no braking. | §3.2, §4 #2 |
| | H2 — every walk surface plays the **glass** footstep family. "Slippery" is what the ear says. | §3.4, §4 #3 |
| | H3 — sprint-slide auto-triggers on a 20.556° slope. | §3.5, §4 #5 |
| "on the way up sometimes you get **stuck on a stair**" | H4 — a step-up is refused or a diagonal move is zeroed at the riser. | §3.3, §4 #4 |
| | H5 — you were body-blocked by a zombie on a 160-wide walkway. | §4 #4b |
| | H6 — you were airborne (from a previous hop or a knockback) and a step-up requires being grounded. | §3.3 |
| "overall **not smooth**" | H7 — 1,616 discrete 12-unit step-up events per climb, each triggering a camera step-offset correction. | §3.6, §4 #2 |
| | H8 — the guard rail top strobes across the eyeline every two steps. | §4 #6 |

**One finding sits upstream of nearly all of them and is the reason this
document exists:** this map is, as far as the shipped Treyarch content on this
machine can tell us, **the only BO3 staircase a player actually walks on stepped
collision.** Every stock stair carries a sloped clip ramp over the treads (§3.1).
Ours has none — 30,960 faces in the `.map`, **zero of them non-axial** (verified,
§2.5). Whatever the exact mechanism turns out to be, the map is running an
untested configuration for 6 minutes of continuous play per climb.

---

## 2. WHAT THE GEOMETRY ACTUALLY IS

All figures below were re-derived from `tools/gen_tower_map.js` and the emitted
`map_source/zm/zm_tower_of_doom.map` during this research. Anything not
independently reproduced is labelled.

### 2.1 The constants

`tools/gen_tower_map.js:71-73, 158-166`:

```
CORE 256   PX 416   PARA 20   PARA_H 56   SLAB 16   RAIL_CAP_H 112
LAPS 50    STEPS 16   TREAD 32   RISE 12
FLIGHT_RISE 192 (= STEPS*RISE)   LAP_RISE 384   TOP 19200   TOP2 19392
PARA_EVERY 2
```

* Walkway width = `PX - CORE` = **160**, clear for its full width — the parapet
  is emitted at `x[PX, PX+PARA] = [416,436]`, entirely **outside** the deck
  (`:836`, `:840`).
* Slope = `atan(12/32)` = **20.556°**.
* Total stair run = 100 flights × 512 = **51,200 units** horizontal for 19,200
  vertical.

### 2.2 The binding constraint nobody wrote down

A flight spans `y ∈ [-CORE, +CORE]` along a core face (`:772-780`). Therefore:

> **`STEPS × TREAD` must equal `2 × CORE` = 512, and `STEPS × RISE` must equal
> `FLIGHT_RISE` = 192.**

`FLIGHT_RISE` is derived (`:159`); the 512 run is **not** — it is a
hand-maintained coincidence, and **there is no assert on it anywhere in the
spiral section.** (The blast-radius lane demonstrated this: setting `TREAD 48`
produced a 50-storey map with the climb severed, silently, with no throw; only
`lint_tod_geometry.js` caught it.)

The consequence is the most important design fact in this report:

> **At fixed `LAP_RISE` and `CORE`, the stair ANGLE is locked at 20.556°.
> `STEPS` is the only free knob and it scales rise and tread together. You
> cannot make this staircase shallower without moving the tower's footprint
> (`CORE`/`PX`), its height (`LAP_RISE`/`TOP`, which drives every crown, door,
> zone and teleport constant), or its walking distance.**

And walking distance is not free: total run = height / tan(slope), so halving
the slope **doubles** the walk from 51,200 to 102,400 units. The author already
rejected that direction by name ("4 stairs per floor is way too much",
CLAUDE.md).

### 2.3 The tread geometry is not defective

`:757` `slabZ(top) => [top - SLAB, top]`; `:773-775` emits odd-lap E tread *i* as
`x[256,416] y[-256+32(i-1), -256+32i] z[b+12i-16, b+12i]`.

* Consecutive treads are **flush-adjacent in Y** and **overlap 4 units in Z**.
  Verified in the shipped `.map`: `lap3 E step 1` = z[764,780], `lap3 E step 2`
  = z[776,792]. **No gap, no lip, no overhang.**
* All coordinates are integers on a 4-unit lattice. No float seams are possible.
* The 4-unit overlap produces ~1,600 coplanar face pairs and T-junctions. These
  are lightmap/CSG artefacts. CoD brush collision is plane-based; **they have no
  movement effect.** (Two lanes gave two different counts here — 1,584 vs 1,600
  — and neither reproduced the other's convention. The number does not matter;
  the conclusion does.)

### 2.4 Every transition on the climb is 0 or +12. There are no exceptions.

Measured on the emitted brushes, lap 3 (`b = 768`):

```
lap3 E step 16    z top 960     lap3 NE landing  z top 960   <- FLUSH, delta 0
lap3 N step 1     z top 972                                  <- +12 off the landing
lap3 N step 16    z top 1152    lap3 NW landing  z top 1152  <- FLUSH
lap4 W step 1     z top 1164                                 <- +12
```

A 4-unit-grid standable-surface diff over the whole tower found **exactly two**
adjacent deltas: `0` and `+12`. Zero anomalies. A 1-unit centreline probe from
the base arena to the terrace returned the histogram `{ +12: 1616, -1: 1 }` —
the lone −1 is the 1-unit `base inlay` decal (`:711-714`).

**There is no hitching geometry. Whatever players feel is produced by 1,616
correct 12-unit steps.**

### 2.5 Nothing intrudes on the walkable column, and nothing is sloped

* **0 non-axial planes out of 30,960.** 0 `patchDef`. Every brush is exactly 6
  axis-aligned planes. (Re-verified for this report.)
* A 30×30×[+2,+70] hull sweep along the full centreline found only the 53
  buyable door slabs (entities; `Hide+NotSolid+ConnectPaths` on purchase,
  `_tod_doors.gsc:315-317`, `:423-425`) and the power-room north wall. Ceiling
  clearance nowhere under 100 units.
* Door **clips** (`:3423`, `:3434/:3443`) span `x[256,436]` in plan — i.e. they
  *do* cover the deck — but their `z1` is `b+128`, 116 above the first tread's
  top. A 72-tall hull on step 1 has ~44 units of clearance. Not a head-bump.
  (One lane stated "zero clip brushes touch the walkway"; that is wrong as
  written and is corrected here.)
* Rail caps (`:920-934`, 202 brushes) live in the parapet band, never on deck.
* Breather balcony floors are emitted at the same `slabZ(mid)` as the landing —
  **flush, no lip.**
* Perk pads and teleport pads on breathers are **script-spawned models, not
  brushes** — invisible to every static tool. See §4 #4b.

### 2.6 Counts (from the emitted `.map`, re-counted for this report)

| | |
|---|---|
| worldspawn brushes | **4,839** |
| tower tread brushes | **1,600** (33% of the whole map's brushes) |
| crown-stair treads | 16 |
| landing floors | 100 |
| flight parapet segments | 793 |
| landing parapets | 196 |
| rail caps (`clip`) | 202 |
| door clips | 53 |
| `clip` faces | 3,870 (all axis-aligned, all material `clip`) |
| total faces | **30,960** |
| discrete +12 step-ups, base arena → terrace | **1,616** |
| walking distance base → terrace | **~68,000 units** |

Control budget (`node tools/measure_lit_area.js`, run for this report):

```
the spiral        2709 brushes     51.6M u²    4.6%
crown (all)                       945M u²      85%
TOTAL             4188 brushes   1117.5M u²
651 unlit/degenerate brush(es) excluded (clip, sky, tool materials)
```

Control gate (`node tools/lint_tod_geometry.js`, run for this report):
`floor surfaces 66217 (54124 standable) · misplaced walls 0 · unguarded edges 0
· detached road 0 tower 0 · base→terrace YES · terrace→citadel YES · OK — no
regression against baseline.`

### 2.7 The causeway, for comparison

`CW_TREAD 40 / CW_RISE 16` (`:1171-1172`) = **21.80°**, marginally steeper than
the tower. `ROAD_STEP_MAX 18` (`:1170`, commented "stock stepSize") leaves 2
units of margin, asserted at `:1227`. 144 treads emitted across 9 `roadStair()`
spans; the shortest route makes ~64 discrete 16-unit level changes.

**The road already solved a problem the tower did not.** `roadStair()` declares
one cell **per tread**, so `roadEmit()` guards each tread at its own height and
causeway rails sit flush. The generator says why, at `:1231-1234`: *"pretending
otherwise is how the ankle-gap under a stepped parapet got shipped in v10.11."*
The tower was never retrofitted — see §4 #7.

---

## 3. HOW THE ENGINE MOVES A PLAYER OVER IT

**BO3's game binary is packed** — a string scan for `sprint|stepSize|g_speed`
returns zero. No pmove constant can be read from it, and no CoD pmove source is
public. Everything below is sorted into three confidence tiers and labelled.

### 3.1 BO3-CONFIRMED, from Treyarch's own shipped content on this machine

**(a) Every shipped Treyarch staircase has a sloped clip ramp over the treads.**
Verified directly for this report at
`<tools>\map_source\_prefabs\zm\zm_giant\geo\zm_giant_zone_a_staircase_1.map`:
a `metal_clip` wedge running 96 rise over 144 run = `atan(8/12)` = **33.69°**,
*plus* a second parallel `clip_missile_no_player` wedge on the same slope so
projectiles slide instead of detonating on step faces. The pattern repeats
across the Giant's stair prefabs (`zone_a_staircase_2`, `zone_c_stairs_1/2`,
`zoneb_garage_stair_set`) and — most relevantly for a spiral — `stairs_curved.map`
clips a **helical** stair with a 16-brush `concrete_clip` triangle fan.
A whole-tree scan of the 931 shipped `.map` files finds sloped clip in ~95-97 of
them; **`zm_tower_of_doom.map` has zero.**

**(b) Treyarch's published stair spec has rise 8 and nothing else.**
`<tools>\docs_modtools\Scale_Standards.pdf`, verbatim: *Default Stairs Rise 8",
Run 12" · Shallow 8"/16" · Steep 8"/8" · Global Width minimum 80" · Standing
Player Height 72", Width 32" ("For all intents and purposes, these are the
collision sizes of the player") · Standing Jump ~100 units distance, 39 units
height · Sprinting Jump (Leap) ~220 units, 50 units height · 1in = 1unit.*
**Our `RISE 12` is 1.5× the only rise Treyarch ships. Our `TREAD 32` is 2× their
deepest run. Our slope, 20.556°, is *shallower* than anything they ship** —
steepness is not the problem; jolt size and exposure are.

**(c) Gravity is 800.** `"gravity" "800"` at `map_source/zm/zm_tower_of_doom.map:16`
and in every stock `.map`; corroborated by `<tools>\share\raw\scripts\zm\_zm_jump_pad.gsc:85`
(`GetDvarInt("bg_gravity"); // 800`).

**(d) Navmesh limits.** `<tools>\bin\default_navmesh_settings.json`, verified:
`maxWalkableSlope 46`, `maxStepHeight 18`, `characterHeight 72`,
`minCharacterWidth 31`. Our 20.556° slope and 12-unit rise are both comfortably
inside. **Neither the current stairs nor a ramp is anywhere near a navmesh limit.**

**(e) Which clip materials cut the navmesh.** `<tools>\radiant\configs\navmesh.json`
`"exclusions"` block, verified line by line: it excludes `clip_player`,
`clip_missile`, `clip_weapon`, `clip_vehicle`, `clip_physics`, `clip_stairs`,
the three `*_carver`s, `clip_ai_wallrun*`, `metal_clip_nosight_noai`,
`clip_utility` and the vehicle variants — and it does **not** contain plain
`clip`, `clip_ai`, `metal_clip` or `concrete_clip`. So:

| ramp material | player | zombies / navmesh |
|---|---|---|
| `clip` | walks the ramp | **walks the ramp** (navmesh cuts on it) |
| `clip_player` | walks the ramp | **ignores it — keeps walking the 16 treads** |

This is the single most useful lever found by any lane: **the player-side fix
and the AI-side change are separable by one material name.**
(Caveat: this is inferred from *absence in an exclusion list*, which is
consistent with `docs/BO3_MAPMAKING_KB.md:89` but was never directly observed.
`clip_stairs` is in the exclusion list but has **zero uses across all 931
shipped source files** — treat it as nonexistent.)

**(f) The movement dvar names are real.** Recovered from the `cod2map64.exe`
string table (the same table map 1 mined), verified for this report:
`slide_angle1`, `slide_angle2`, `slide_downhillFriction_amount`,
`phys_player_step_on_actors_zm`, `jump_stepSize`, `player_sprintSpeedScale`,
`bg_viewBobAmplitudeSprinting`. **The table stores names and descriptions, not
defaults — no value can be read from it.**

**(g) The script APIs exist.** `<tools>\docs_modtools\bo3_scriptapifunctions.htm`
contains `AllowSlide`, `IsSliding`, `AllowSprint`, `SetMovingPlatformEnabled`,
`PlayerSetGroundReferenceEnt`, `SetSprintDuration`.

### 3.2 LINEAGE-INFERRED (id Tech 3 / Quake III source, read directly)

BO3 is an idTech3 descendant (CoD2 → CoD4 → … ). The Q3 source facts below were
fetched and verified by two lanes; **their transfer to T7 is inference.**

* `bg_local.h` — `STEPSIZE 18`, `MIN_WALK_NORMAL 0.7f` (max walkable slope
  `acos(0.7)` = 45.57°), `OVERCLIP 1.001f`. The repo's own `ROAD_STEP_MAX = 18`
  and BO3's `maxStepHeight 18` both corroborate the 18.
* `bg_pmove.c` — `pm_friction 6.0`, `pm_accelerate 10.0`, `pm_airaccelerate 1.0`,
  `pm_stopspeed 100.0`. `PM_GroundTrace` traces **0.25 units** down. `PM_Friction`
  applies drag **only** inside `if (pml.walking && !SURF_SLICK)`. `PM_Accelerate`
  opens with `addspeed = wishspeed - currentspeed; if (addspeed <= 0) return;`
  — **it can only add speed along wishdir; you cannot brake in the air.**
* `PM_StepSlideMove` (`bg_slidemove.c`) — opens with
  `if (PM_SlideMove(gravity) == 0) return;` (the step machinery engages only
  *after* the frame's move was blocked); refuses to step while
  `velocity[2] > 0`; and **restores `start_v` after the step-up** — so the
  common "step-ups cost you speed" claim is a myth in this lineage.

**The descent arithmetic that follows from this** (`g = 800`, `RISE 12`,
`TREAD 32`): a player leaving a tread nose falls 12 units in
`sqrt(2·12/800) = 0.1732 s`. They land on the next tread only if
`v ≤ TREAD·sqrt(g/(2·RISE))`:

> **v_grounded_max = 32 × 5.7735 = 184.75 u/s**

Against the map's own speeds (base run ~190 u/s — the repo's figure, asserted at
`_tod_runandgun.gsc:37` "base run ~190" and `_tod_upgrades.gsc:298`
`TOD_MOMENTUM_FULL_SPEED 190`; **not engine-verified**):

| class | `class_speed_base()` | run u/s | grounded on descent? |
|---|---|---|---|
| HEAVY | 0.75 | 142.5 | **yes** |
| ASSAULT | 0.90 | 171.0 | **yes**, 13.7 u/s of margin |
| SKIRMISHER | 1.00 | 190.0 | **no** — 2.8% over the line |
| SLASHER | 1.10 | 209.0 | **no** |
| anyone sprinting | ~214-314 | | **no** |

(`class_speed_base()` at `_tod_upgrades.gsc:1185-1199`; `SetMoveSpeedScale` is
written in exactly one place, `apply_move_speed()` at `:975-991`, as
`class_speed_base() × (1 + lvl×0.05 + adren_bonus())` with
`TOD_UPG_SPEED_PER_LVL 0.05` at `:141`. Max scales: SKIRMISHER 1.74,
SLASHER 1.65, HEAVY 1.125, ASSAULT 1.035.)

Above the threshold, hop length is `2·s·v²/g` with `s = 0.375`: 34 units at 190,
76 at 285, 122 at 360 — i.e. 1 to 4 treads skipped per bound, with an impact
every 0.18-0.33 s. **No ground friction, one-tenth the steering authority, and
no ability to brake — on a 160-wide walkway with a 90° turn every 512 units.
That is what "slippery" describes.**

### 3.3 THE ONE UNKNOWN THAT DECIDES ALL OF THIS

**Does BO3 snap a descending player back down onto the next tread?** Source has
`StayOnGround` (traces up to `StepSize` = 18 below and re-plants the player);
GoldSrc snaps 2 units; **idTech3 has neither.** If Treyarch added a step-down of
≤18 to T7's pmove, then both the tower's 12 and the causeway's 16 are fully
absorbed and **§3.2's entire ballistic model evaporates.**

The fact-check raised a reductio against the model: apply it to Treyarch's own
default 8/12 stair and you get `12·sqrt(800/16) = 84.9 u/s` — below crouch
speed — implying nobody could ever descend a stock CoD stair grounded, which is
absurd.

**But the reductio is weaker than it looks, and this is the key synthesis
point:** Treyarch's stairs are all **clip-ramped** (§3.1a). A player never walks
their stepped collision, so the 84.9 figure is never exercised in shipped
content. The reductio establishes that *if* stepped collision were exposed at
stock scale it would behave absurdly — which is an argument that stepped
collision is not meant to be walked, not an argument that the model is wrong.

**Verdict: H1 stays as the leading descent hypothesis, explicitly UNVERIFIED,
with a 30-second falsification test (§7.1).** It is the highest-leverage unknown
in this document.

### 3.4 THE FOOTSTEP SURFACE — a confirmed fact with an unverified consequence

**Verified for this report.** Every material used for a walkable surface in this
map comes from the Nastian/emox Vertigo pack: treads are
`mwiii_vertigo_retro_synth_<colour>_tinted` (`gen_tower_map.js:435`), landings
and breathers `_tinted_edge` (`:441`), arena ground `dark_blue_tinted` (`:445`),
crown deck and causeway the same family. In
`<tools>\source_data\_emox\emox_mwiii_vertigo_assets.gdt` there are **30
`mwiii_vertigo_retro_synth_*` materials and all 30 carry
`"surfaceType" "glass"`, `"slick" "0"`, `"noSteps" "0"`.**

So `slick 0` means the engine is **not** applying reduced friction — the
material is not literally slippery. But **every one of the ~1,600 footfalls in a
50-floor climb plays the glass footstep family, and every bullet impact on the
tower is a glass impact.**

By contrast, Treyarch's stair ramps are `metal_clip` / `concrete_clip` — the
surface-typed clips — precisely because on a clip-ramped stair the *clip* is the
surface the player stands on and it supplies the footstep material. Plain `clip`
has `surfaceType "<none>"`.

**Unverified:** that `surfaceType` alone selects the footstep alias family in
T7. It does in every prior CoD, and the GDF exposes `slick` as a *separate*
friction flag, which is strong circumstantial evidence that `glass` is
audio/FX-only. `material.awi:510`'s own tooltip says surfaceType "Sets the
bullet collision particle" and says nothing about footsteps — so the mod tools
do not close this.

This is a candidate root cause for the literal word "slippery" that involves no
geometry at all, and nobody had considered it.

### 3.5 THE SLIDE — Treyarch's own description names slopes

BO3 zombies **has the sprint-slide**. `<tools>\share\raw\scripts\zm\_zm.gsc:217-224`
disables double-jump, juke, player-energy, wallrun and sprint-leap for ZM;
**slide is deliberately not on that list**, and `_tod_perk_phd.gsc:50-52` states
it in-repo: *"BO3 zombies has the sprint-slide but NO dolphin-dive."*

From the cod2map64 string table, verbatim (verified for this report):

> `slide_angle1` — *"This value represents the sin of the angle of the slope.
> Slide is slightly longer or shorted based on the slope. Up to this threshold
> the player needs to initiate the slide."*
>
> `slide_angle2` — *"This value represents the sin of the angle of the slope.
> The slide will automaticly trigger if the slope is in {slide_angle1,
> slide_angle2}"*

Also present: `slide_downhillFriction_amount`, `slide_min_required_airVelocity`,
`slide_min_continue_velocity`, `slide_outSpeedScale`.

**`sin(20.556°) = 0.351`.** If that lands inside the engine's
`{slide_angle1, slide_angle2}` band, sprinting down this staircase auto-slides,
with a dedicated *downhill friction* term. **I could not read the defaults** —
the string table has names and descriptions only. Note also that a slope-based
trigger implies the engine is resolving a *slope* from the stepped surface at
all, which is itself uncertain on axis-aligned treads.

Nothing in this map uses the slide: `grep AllowSlide|IsSliding` over
`scripts/zm/zm_tower_of_doom/` returns zero hits.

### 3.6 THE CAMERA — up-smoothing only, and it never settles

In the Q3 client, `CG_StepOffset` (`cg_view.c`) sinks the view by
`stepChange × (STEP_TIME - timeDelta) / STEP_TIME` with `STEP_TIME 200` ms and
`MAX_STEP_CHANGE 32` (`cg_local.h`); `cg.stepChange` is written **only** by
`EV_STEP_4/8/12/16`, which `PM_StepSlideMove` emits only for an **upward** delta
> 2. **There is no down equivalent anywhere in the codebase.**

Applied to this map (with the fact-check's corrected arithmetic — one lane
claimed the offset pins at the 32 clamp; it does not):
`s* = 12 / (Δ/200)` where Δ is the inter-step interval.

| class / state | Δ (ms) | fixed-point sink |
|---|---|---|
| HEAVY run (4.45 steps/s) | 225 | 12 (no accumulation) |
| SKIRMISHER run (5.94/s) | 168 | 14.3 |
| SKIRMISHER sprint (~8.9/s) | 112 | 21.4 |
| SLASHER sprint (~9.8/s) | 102 | 23.5 |

So the camera runs a *time-averaged* 8-13 units below true eye height for the
length of a flight, peaking at 12-24, and snaps back on a landing — **it never
reaches the 32 clamp at any speed this map can produce.** On a clip ramp,
`EV_STEP` never fires and the effect does not exist.

**Also corrected here:** one lane argued the *frequency* of steps is the
problem. It is not — a stock 8/12 stair steps at `v/12` (15.8/s at 190 u/s)
versus this map's `v/32` (5.94/s). **This map steps 2.7× LESS often than a
stock CoD staircase.** What actually differentiates it is **jolt size (12 vs 8)
and exposure (1,616 events over ~6 minutes of continuous climbing, versus a
dozen anywhere else in the franchise)**.

### 3.7 What GSC provably cannot do

* **No player friction API and no player ground-friction dvar.** The whole
  friction family in the dvar table is slide, slick-surface, wallrun, juke,
  slam, jetpack, water and vehicle. Normal ground friction is not exposed.
* **No player `stepSize` dvar.** The only "step" dvars are `jump_stepSize`
  ("maximum step up to the top of a jump arc"), `bg_vehicle_stepsize`,
  `trm_stepDistance` and navmesh `maxStepHeight`. The walking step-up is a
  hardcoded engine constant. (Irrelevant anyway: 12 < 18.)
* **No client-side view-height / step-smoothing / camera-damping hook in `.csc`.**
  The `.csc` player-camera surface is `EnableSpeedBlur`/`DisableSpeedBlur` and
  vision sets.
* **`SetClientDvar` does not exist in T7** (MEMORY: *lui-data-channels*), so
  there is no server→client lane to a client bob dvar. `bg_viewBob*` are
  settable via `SetDvar` on the server, but see §5-S6 for the replication trap.
* **No server frame faster than 20 Hz.** `SERVER_FRAME .05`; `waitframe()` does
  not exist. **Any per-frame script correction of movement is impossible by
  construction** — 20 discrete corrections/second *is* jank.
* **Clientfields cannot alter movement.** They are a one-way data channel.

---

## 4. ROOT-CAUSE RANKING

> **Plainly: I believe the single largest cause is that this map walks the
> player on stepped collision at all — every shipped BO3 staircase carries a
> sloped clip ramp and ours has none.** That is upstream of the descent
> ballistics, the ascent hitching, and the camera step-offset simultaneously,
> and it is the one property of this map that is provably divergent from 100% of
> Treyarch's own stairs. I hold that at **high confidence as a diagnosis** and
> **medium-high confidence that a ramp fixes the complaint**, because the exact
> mechanism (§3.3) is still unproven.

### #1 — NO CLIP RAMP. Confidence: HIGH (diagnosis) / MEDIUM-HIGH (fix)

**For:** verified in shipped Treyarch content (§3.1a) — `metal_clip` /
`concrete_clip` ramps on every stock stair including a helical one; 0 sloped
faces in this map out of 30,960. Rise 12 is 1.5× the only rise Treyarch ships.
Community BO3 guidance says the same thing (*"Put a clip … on the stairs on the
same angle like a ramp"*, [Steam / BO3 Mod Tools](https://steamcommunity.com/app/455130/discussions/0/340412122415898009/)).
A ramp removes all 1,616 step-up events, all `EV_STEP` camera corrections, all
riser planes, and — if H1 is real — the entire airborne descent, in one change.

**Against:** it is an *architectural* diagnosis, not a measured mechanism. It
does not by itself tell you which of H1/H4/H7 the player is feeling. And the
repo's tooling makes it more expensive than it sounds (§5-G1).

### #2 — BALLISTIC DESCENT above 184.75 u/s ("slippery"). Confidence: MEDIUM

**For:** arithmetic from the map's own constants and confirmed gravity 800;
`v_grounded_max` = 184.75 sits *2.8% below base run speed*, which is exactly the
signature of a complaint that is inconsistent between players. Q3-verified
friction/acceleration/braking behaviour makes "airborne" and "slippery"
synonymous. Predicts a **class ordering** (HEAVY/ASSAULT fine walking,
SKIRMISHER knife-edge, SLASHER worst, everyone worse sprinting).

**Against:** rests entirely on BO3 having **no step-down snap**, which is
unverified (§3.3). If T7 snaps down ≤18, this drops to zero.

**Corrections made to the lanes:** (a) the map does **not** grant unlimited
sprint — `_tod_upgrades.gsc:1259-1266` records TIRELESS removed 2026-08-26 and a
grep confirms `SetSprintDuration`/`SetClientPlayerSprintTime` appear only in
comments. Sprint is the gametype's stock ~4 s burst. So the ballistic regime is
**intermittent**, not constant — which fits "sometimes" better than "always".
(b) One lane's "% of descent grounded" column was arithmetically wrong in four
of six rows; corrected, the descent is *more* airborne than claimed (73-98%, not
73-92%). (c) There is **no fall damage risk**: max drop is 36 units; the
zombies gametype's thresholds are engine defaults (the 256/512 figures one lane
cited are from the `level.oldschool` branch of `_globallogic.gsc:185-195` and do
not apply).

### #3 — GLASS FOOTSTEPS ("slippery", the audio half). Confidence: MEDIUM

**For:** confirmed — all 30 pack materials are `surfaceType "glass"` (§3.4).
100% of the player's proprioceptive audio for the entire game says *glass*.
Treyarch's use of surface-typed clip on stair ramps is evidence that the surface
type matters to them. Costs nothing to weigh; explains the word "slippery"
directly even if H1 turns out false.

**Against:** unverified that `surfaceType` drives footstep alias selection in
T7. `slick 0` means the material is not mechanically slippery, so this can only
ever be the *perceptual* half.

**Free discriminator:** if the author has heard "slippery" about **map 1**
(same pack, same glass), that is confirmation. If surfaces have never been
mentioned anywhere else, downgrade this.

### #4 — "STUCK GOING UP": NO GEOMETRIC CAUSE EXISTS. Confidence: HIGH that it is not geometry; LOW on which mechanism it is

Every up-transition is exactly +12 against an 18-unit step limit. Zero clip on
deck, zero low ceilings, zero non-axial faces, zero deltas over 12 on a 4-unit
grid. **"Stuck" is not a bad brush.** The residual candidates, none verified:

**4a — engine.** In Q3's `PM_SlideMove`, `planes[0]` is pre-seeded with the
ground normal and `planes[1]` with normalised velocity *before* any collision;
hitting the riser makes it three, and a third plane triggers
`// stop dead at a tripple plane interaction  VectorClear(velocity)`. A player
hugging the core wall (x=256) or the rail (x=416) while climbing presents ground
+ wall + riser — three mutually perpendicular planes — and on a spiral you hug
the inside. **Plausible, wholly unmeasured, and it is the mechanism most worth
testing.** Also: a step-up is refused while `velocity[2] > 0`, so a player who is
airborne (from a descent hop, a jump, or a Panzer/protector knockback) hits the
riser as a wall — which ties #4 and #2 to the same root.

**4b — bodies. This is the strongest non-geometric candidate and it is
under-weighted everywhere.** `_tod_corpse_cleanup.gsc:99-100` raises
`level.zombie_ai_limit` 24 → **45** and `level.zombie_actor_limit` 31 → **60**.
`_tod_zombie_speed.gsc` puts every zombie in the sprint gait from round 1. The
walkway is **160 wide**; a player and a zombie are each 32. `docs/24:31`
independently reports a *"permanent 8-robot traffic jam"* of Rogue Protectors on
these same stairs. And `phys_player_step_on_actors_zm` exists as a real dvar
(§3.1f) with a **ZM-specific variant** — if players can step onto AI capsules,
a packed flight is a field of moving 12-unit ledges. **This costs nothing to
discriminate: ask whether "stuck" ever happens with no zombies nearby.**

**4c — script-spawned collision on the breather decks.** 8 perk machines that
**reshuffle every 4 rounds** onto breather pads, 4 teleporter pads, ammo crates.
Invisible to AABB parsing *and* to the lint, sitting exactly where players stop
moving, and **different between runs** — which is the shape of a complaint that
reads as random. `_tod_perk_scatter.gsc:708-722` already ships an
`unstick_players()`, which is itself evidence that people get stuck there.

**4d — the 53 doorways.** The door slab straddles `y = -256`, half over the
landing and half embedded 12 units into tread 1. The doorway plane and the first
riser are effectively the same place, 53 times per climb.

### #5 — SPRINT-SLIDE AUTO-TRIGGER. Confidence: LOW-MEDIUM, but very cheap to test

Treyarch's own dvar description names slope-triggered auto-slide with a
downhill-friction term (§3.5), and `sin(20.556°) = 0.351` is a plausible value
to fall inside the band. Defaults unreadable. **One `IsSliding()` poll settles
it.**

### #6 — THE RAIL TOP STROBES ACROSS THE EYELINE. Confidence: MEDIUM (perception only)

`PARA_H 56` above the *local* tread, stepped every `PARA_EVERY 2` steps. Standing
on the first step of a pair the rail top is 68 above your feet; on the second it
is 56. With a player eye height near 60, **a hard horizontal line with a
19,000-unit void behind it crosses your eyeline every two steps** — a 12-unit
sawtooth at ~3-5 Hz, for 100 flights. That is exactly the kind of thing players
report as "not smooth" without being able to name it. Independent of every
physics hypothesis.

### #7 — 800 ANKLE GAPS UNDER THE STEPPED PARAPETS. Confidence: HIGH that it is real; LOW that it is this complaint

`:838-841`: parapet *j* spans two treads with its **bottom at `b + 24j`** = the
top of the *second* tread it covers. Verified in the `.map`: `lap3 E step 1` top
= **780**, `lap3 E para 1` bottom = **792**. **Every odd-numbered tread of every
flight has a 12-tall × 20-deep × 32-long slot of nothing under the rail** —
8/flight × 100 flights, ≈800.

It cannot catch a hull (a 72-tall player cannot enter a 12-tall slot) and it is
outside the deck at `x[416,436]`, so it is **not** a snag. It is a see-through
hole in the guard rail over the void, and a bullet/grenade gap.

Two things make it worth recording anyway: **the lint is structurally blind to
it** (the outermost sampled column at `snap(416) = 400` always contains the
parapet, so `solid` is truthy and the node is dropped before CHECK 2 runs — the
"a visible solid silently drops the node" caveat in CLAUDE.md, observed in the
wild), and **`PARA_EVERY` is documented as the bake-budget knob**, so anyone who
raises it 2 → 4 turns a 12-unit gap into a 36-unit gap on 3 of every 4 treads.

### #8 — MICRO-LIPS AND T-JUNCTIONS. Confidence: HIGH that they are irrelevant

1-unit inlay decals, the 8-unit extraction pad, 24-unit pylon plinths;
~1,600 coplanar face pairs from the 4-unit tread overlap. Lightmap/CSG only.
Listed so nobody re-investigates them.

---

## 5. THE OPTION SPACE

Ratings: **Fix-confidence** = how likely this addresses the *actual* complaint
(1-5). **Build** = `-GscOnly` or FULL (any `.map`, `.gdt` or material change is
FULL; CLAUDE.md — a `-GscOnly` after a GDT edit is *worse than nothing*).

### GEOMETRY

**G1 — Sloped `clip` ramp over every flight.** Fix-confidence **5/5**.
*What it fixes:* everything at once — no step-up events, no `EV_STEP` camera
sink, no riser planes to zero a diagonal move, and a continuous walkable plane
means `pml.walking` stays true so friction and full ground acceleration are
never lost. Zero visual change.
*Plane placement (measured from Treyarch's own, not guessed):* the ramp is the
plane through the **front-top nosing corner of every tread** — the unique lowest
plane of the right slope that never sinks below a tread top. Verified in
`stairs_curved.map` (flush at each nosing, +8 at each tread back) and
`zm_giant_zone_a_staircase_1` (+2 offset, exactly +2 at all 11 treads). For this
map, odd-lap E flight, base `b`: `z(y) = b + 12 + 0.375·(y + 256)`, spanning
`y[-288, +224]`, `z[b, b+192]` — **one wedge per flight, flush into the landing
at both ends**, riding the last 32 units of the lower landing as a 0→12 lip
(which is precisely Treyarch's arrangement). 100 wedges + 1 for the crown stair.
*Effort:* **this is not a one-line change.** `box()` (`:643`) emits a fixed
6-plane axis-aligned template and is the map's only brush writer; a new wedge
emitter is required, and for anything at the crown lap it must be mirrored
through `cbox` or it breaks the parity rule CLAUDE.md flags as a repeat offender.
Call it a day or two, not an hour.
*Blast radius:* +101 brushes (4,839 → ~4,940). **Lit area: zero if the material
is plain `clip`** — `measure_lit_area.js:38`'s `UNLIT` regex is
**start-anchored** (`/^(clip|sky|caulk|…)/`), so `clip` and `clip_player` are
excluded but **`metal_clip` and `concrete_clip` are NOT and would be counted as
lit.** Bake: no new lightmap charts. Navmesh: see G1a/G1b.
*Risk — the tooling, and it is real:*
  - `lint_tod_geometry.js:223` — `if (planes.length !== 6 || !mat) { continue; }`.
    A wedge has 4 axis-constant planes, so it is **silently dropped**. It cannot
    trip CHECK 1 and cannot regress the baseline (the treads remain as visible
    solids, so leave them solid — as Treyarch does) — **but the lint also proves
    nothing about it.** That is a genuine new blind spot.
  - `measure_lit_area.js:77-79` and `audit_hidden_faces.js` index-read the
    `box()` plane order `[z1,z2,y1,x2,y2,x1]`; a wedge is dropped from both
    totals, so `TOTAL` silently stops summing to the generator's brush count.
  - `roadEmit()` cannot express a slope **by design** (`:1230-1233`) — the road
    is cell-based and every coordinate asserts `% ROAD_G === 0`. A ramp on the
    causeway is a different project.
  - **Unverified: whether cod2map64 and the Radiant LED bake accept a non-axial
    brush at all, and how they texture the slanted face.** Standard Quake-family
    compilers do; nobody ran a build.
*Two material sub-options, and they are a real decision:*

  > **UPDATE 2026-09-02 (v16.61a): G1a ADOPTED.** The G1b `clip_player` wedges shipped 2026-08-27 and were walked for six days; the AI-side half turned out to be the root cause of the user's "Deadshot bounces tracking a zombie up stairs" (zombies were still climbing the 16 stepped treads — the only BO3 stair AI climbs on stepped collision). `MAT.rampClip` is plain `clip` now; the lounges' window voids kept `clip_player` under a new `MAT.winClip`. The horde walk G1a asks for is the v16.61a test. Record: CHANGELOG v16.61a, memory `stair-ramp-clip`.

  **G1a — `clip` (cuts navmesh; zombies walk the ramp too).** This is
  Treyarch's shipped configuration. 20.556° against `maxWalkableSlope 46`, and a
  planar surface is *strictly better-conditioned* navmesh input than 16 treads.
  Likely an AI improvement. But it is a whole-tower navmesh rebuild and must be
  walked with a horde before shipping.
  **G1b — `clip_player` (navmesh-excluded; zombie behaviour byte-identical).**
  Lowest AI risk and the cleanest *experiment*, because it isolates the
  player-side variable. But adding the material means editing the lint's
  `MATERIALS` map (an unknown material is a **hard abort**,
  `lint_tod_geometry.js:243-251` → `build_map.ps1` `Die`) and — subtly —
  CHECK 1 tests `b.mat === 'clip'` by literal equality, so a `clip_player`
  brush registers as *solid* and **silently disables the invisible-blocker check
  in every column it occupies.** Editing the lint requires re-running
  `tools/lint_tod_geometry_selftest.js`.

  There is no "player collision the navmesh ignores" that is also a *carver*;
  the `*_carver` family is the opposite (nav cut without player collision).

**G2 — Make the ramp VISIBLE: delete the tread brushes.** Fix-confidence 5/5 on
feel; needs author sign-off.
Same physics as G1 plus a **bake windfall** — the spiral falls from 2,709
brushes to a few hundred, riser faces disappear, tread-top area is unchanged so
lit area *falls*. That budget is exactly what the crown (85% of the map) has
been fighting for. **But:** the map is called a stair map, and a helical neon
ribbon is a visual identity change. Also the stepped parapets would look wrong
beside a smooth ramp (want continuous sloped rails: same emitter, 100 brushes
replacing ~800). **And a wedge cannot be *deck* to the lint even after a parser
fix** — `isDeck` requires `hi[2] - lo[2] <= MAX_SLAB (64)` and a flight wedge
spans 208 in Z. The blast-radius lane measured a 25-flight trial: **CHECK 2
`unguardedEdges 0 → 343`, CHECK 3 `unreachableTowerNodes 0 → 32453`,
`base -> terrace is NO LONGER walkable`** — red *before* anyone can walk it,
which is exactly the situation the lint's own header warns about with no walked
map to appeal to. **Rejected as a first move** for that reason; viable only
after the lint learns slopes.

**G3 — Ramp + 2-unit proud "tick" ribs.** Fix-confidence 5/5.
A 2-unit lip is silently stepped over (limit 18), so ribs are
**movement-invisible** while restoring the visual rhythm. Reads as a stair,
walks as a ramp. 8-16 thin brushes per flight (800-1,600 map-wide); lit area
~1M u² (+0.1%); **face count is the bake variable — bake it, and remember that a
single bake reading justifies nothing.** *Probably the best answer if the author
wants the stairs to still look like stairs.*

**G4 — AABB micro-slab "ramp" (avoid the wedge entirely).** Fix-confidence 2/5.
**Measured by the blast-radius lane**, so the numbers are real: a naive
one-box-per-flight clip goes **RED — 6,048 misplaced walls, 32,775 detached
nodes, climb severed.** A 4-unit-run stepped clip whose top stays ≤18 above each
tread passes the lint **CLEAN (0/0/0/0)** with **zero lit-area change** — but
costs **+12,800 brushes map-wide (4,839 → ~17,600, a 3.6× increase)**, and it is
mathematically just a finer staircase, which §5-G6 shows is *worse*. Rejected.

**G5 — Change the step ratio (`STEPS 32 / TREAD 16 / RISE 6`).**
Fix-confidence **1/5 — REJECTED, and the arithmetic goes the wrong way.**
Same 20.556° slope (it must, §2.2), but
`v_grounded_max = 16·sqrt(800/12) = **130.6 u/s**` — *lower* than today's 184.75,
so **every class including HEAVY goes airborne descending.** The jolt halves and
the airborne fraction rises. Measured cost: +50% brushes (4,839 → 7,255),
+0.9% map lit area, lint clean. Pure bake cost for a negative outcome. Only
viable *combined with* a ramp, where the tread subdivision becomes purely
cosmetic.
*Two silent hazards on this path, both demonstrated:* `STEPS × TREAD ≠ 512` is
**unguarded** and produces a silently broken map (an `if (STEPS*TREAD !== 2*CORE)
throw` is free insurance); and `PARA_EVERY` must **divide** `STEPS` or every
flight loses its top rail segment — with `PARA_EVERY 3` the lint reported
`unguarded edges 0` because the invisible `rail cap` clip satisfies `guarded()`
on its own. That is a second reproduced blind spot in the map's own gate.

**G6 — Shallower stair via a fatter core (`CORE 320`, `TREAD 40`, `PX 480+`).**
Fix-confidence 3/5. Run becomes 640, slope 16.7°,
`v_grounded_max = 40·sqrt(800/24) = **231 u/s`** — above sprint. Deeper treads
also give the 32-wide hull real dwell. And a fatter core is more imposing, a
direction the author has consistently wanted. **But** `CORE`/`PX` ripple into
doors (`y = ±256` hardcoded at `:3497`, `:3506`), breathers, rail caps, arena
walls, terrace, crown stair, `_tod_door_data.gsc`, the lint baseline and the
crown's pinned south face. Expensive-structural; G1/G3 buys more feel for less
risk.

**G7 — More flights per lap for a gentler slope.** **REJECTED.** Total run =
height/tan(slope): halving the slope doubles the walk (51,200 → 102,400). The
author rejected 4 flights/floor by name.

**G8 — Mid-flight landings.** Doesn't fit: 8 treads (256) + a 160 landing +
8 treads (256) = 672 ≠ 512. Requires G6 first.

**G9 — Widen the walkway `PX 416 → 496` (160 → 240).** Fix-confidence 3/5 for
the *body-blocking* half (#4b) only. Spiral lit area +~2.3% of the map total.
Touches parapets, rail caps, breathers, door trigger/clip x-extents, arena clip,
terrace, crown stair, lint baseline. Expensive-structural.

**G10 — Close the ankle gap (#7).** Fix-confidence 1/5 for *this* complaint;
5/5 as a bug fix. **One line:** change the parapet's `z1` from `top` to
`top - RISE*(PARA_EVERY-1)`. Top face unchanged, so `RAIL_CAP_H` and the
anti-vault design are untouched. **Zero new brushes**, +~1.5M u² lit (+0.13%).
Cheap, reversible, and it aligns the tower with what `roadStair()` already does.

**G11 — Move the risers off the landing centres.** `docs/24:31`: *"Risers sit
dead-centre on the landings … so zombies rise at your feet whenever you stop."*
A zombie spawning inside your hull at the exact moment you reach flat ground is
a very good candidate for "I got stuck". **Generator struct move: cheap, no new
geometry, no lit-area change, FULL build.** Fix-confidence 2/5 for the stated
complaint, higher for the felt one.

### SURFACE / MATERIAL

**S1 — Re-surface the treads and landings off `surfaceType "glass"`.**
Fix-confidence **4/5** *if* §3.4's unverified consequence holds.
*Two paths.* (a) Edit `emox_mwiii_vertigo_assets.gdt` in place — fast, but it
lives at the **shared tools root**, is un-versioned, and silently changes map 1
too (MEMORY: *shared-gdt-crosses-maps*). (b) **Clone the ~8 tread/landing
materials into a repo-owned `tod_surfaces.gdt` under new names, same images,
`surfaceType "metal"` or `"concrete"`** — owned, versioned, and then it is a
material-name swap in `stepMatOf`/`edgeMatOf` (`:435-441`). **Path (b) is right.**
*Blast radius:* **a `.gdt` edit is ALWAYS a full build** — `-GscOnly` copies the
GDT but runs no `gdtdb /update`, so it makes the tree *look* current while
shipping the old assets. New material names must be added to the lint's
`MATERIALS` map or the lint **hard-aborts**. Zero geometry change, zero brush
change, lit area unchanged (same face count, same materials class).
*Risk:* third-party pack licensing/credit if you edit theirs (path a).

**S2 — Scripted footstep layer in GSC.** **REJECTED.** Re-implementing
footsteps server-side at 20 Hz would desync from client-predicted animation and
sound worse than glass. Fix the material, not the symptom.

### SCRIPT (`-GscOnly`, no bake, no lint, no navmesh)

**S3 — `AllowSlide(false)` per player.** Fix-confidence 3/5 — **the cheapest
candidate fix in the whole document.**
API confirmed present. One call, server-authoritative, prediction-safe
(replicated player *state*, not a position correction). Nothing in the map uses
the slide for anything. *Cost:* players lose the slide everywhere, including the
base arena and the causeway. *Gate it on §7.1's `IsSliding()` probe first —
if nobody is sliding, this fixes nothing.*

**S4 — "Stay on ground": force early re-contact while descending.**
Fix-confidence 3/5. If H1 is real, a per-player watcher inside the spiral's x/y
band that fires only when `!IsOnGround()`, `GetVelocity()[2] < 0` and the player
did not jump, adding downward velocity — you only ever add speed in the
direction gravity already points, so **there is no rubber-banding**; it just
forces re-contact, restoring friction and turn authority.
*This is coherent precisely because it fires only when the player is AIRBORNE.*
`_tod_lunge.gsc:44-47` records that *"the player movement code overwrites a
grounded player's velocity every frame"* — impulses stick only while
airborne/sliding. So the one regime where `SetVelocity` works is exactly the one
this uses.
*Risk:* **20 Hz granularity is the ceiling.** A 0.173 s hop is ~3.5 server
frames; the corrector can sample it maybe once. Marginal by construction. Must
not fire during an intentional jump, a PhD dive, or on the causeway.
All four builtins are proven in this codebase (`_tod_lunge.gsc:272,293`;
`zm_weap_xmas_gun.gsc:256`; `_tod_runandgun.gsc:100-102`).

**S5 — Hard descent speed clamp inside `apply_move_speed()`.**
Fix-confidence 2/5. Mechanically it works — drop below 184.75 and you are glued
— and this map already funnels *every* speed source through one writer
(`_tod_upgrades.gsc:975`), so it is architecturally clean. **But** map 1's
hard-won rule applies: *"SetMoveSpeedScale IS NOT A MOMENTUM LEVER … a 'grace
window' or 'release ramp' does not read as momentum — it reads as ice /
unresponsiveness"* (`_acc_movement.gsc:25-45`). A **hard binary clamp** is a
different shape from the two lerps that were rejected there, so it is not
strictly dead — but it caps SKIRMISHER, SLASHER, all sprinting and the whole
SPRINT/MOBILITY line. **A design amputation dressed as a fix.** Also note the
existing re-assert is 1 Hz (`:1284`), far too slow; this needs its own faster
loop or must ride `_tod_uniques`' existing 20 Hz per-player poll.

**S6 — Engine dvars (`slide_*`, `bg_viewBob*`, `sprint_shake_*`,
`phys_player_step_on_actors_zm`).** Fix-confidence 2/5, **with a co-op trap.**
Setting engine movement dvars from GSC **is stock practice** —
`_zm.gsc:217-224` does it unconditionally with no cheat gate — and map 1 ships a
hardened helper (`_acc_movement.gsc::scale_engine_dvar`) that handles the two
traps: **(i)** `SetDvar` on an unregistered dvar silently creates a dead script
dvar, so failure looks like success — probe with `getdvarstring(name,"") == ""`
first; **(ii)** dvars persist across map loads within a Steam session, so a
naive `SetDvar(x, getdvarfloat(x)*k)` **compounds** on every restart — capture
the pristine default once into your own `tod_*_orig_*` dvar. Copy that helper
verbatim; do not re-derive it.
**The unresolved risk:** `_tod_upgrades.gsc:1672` records that *"host `SetDvar`
never replicates to co-op peers"*, and `bg_*` dvars are client-predicted. On a
guest the *client's* value governs its prediction, so a dvar fix may silently do
nothing for guests — or, worse, create a genuine prediction divergence on
stairs. **This must be verified in a real 2-player session before any dvar-based
fix ships.** It is the single biggest unknown on the script side.

**S7 — Fix the 1-second post-spawn speed race.** Fix-confidence 1/5 for this
complaint, but free. `_tod_upgrades.gsc:1280-1286` re-applies move speed once a
second because stock stomps it (`zm_usermap.gsc:336` `SetMoveSpeedScale(1)`).
So for **up to a full second after every spawn/revive** a HEAVY runs at 1.0
instead of 0.75 (+33%) and a SLASHER at 1.0 instead of 1.10 (−9%). A visible
speed change one second into a life reads as inconsistency. ~3 lines.

**S8 — Distance-gate the screen shake.** Fix-confidence 1/5, but cheap and
already proposed in `docs/24` §4. `_tod_bosses.gsc:497`
`Earthquake(0.55, 1.2, v_ground, 1200)` on Panzer landing, `landing_rumble()`
`:1549-1560` on a 0.1 s loop, `_tod_perk_phd.gsc:302`. Screen shake while
mid-hop down a stair reads as the stair being rough.

**REJECTED SCRIPT OPTIONS — do not carry these forward:**

| idea | why it dies |
|---|---|
| `SetVelocity` downward "glue" on a **grounded** player | The movement code overwrites a grounded player's velocity every frame — `_tod_lunge.gsc:44-47`, and the user's verdict on the one feature built on repeated `SetVelocity` steering was *"it doesnt work"* (CHAIN LUNGE, removed 2026-08-24). On an *airborne* player it only increases impact speed. |
| `SetOrigin`-based stair glue in a loop | 20 authoritative position corrections/second against a client that already predicted otherwise = textbook rubber-banding. Fine as a one-shot (teleporters, `unstick_players`), catastrophic as a corrector. |
| `PlayerSetGroundReferenceEnt` | **Wrong tool.** Its own doc: *"The ground entity's rotation will be added onto the player's view … the player's yaw to rotate around the entity's z-axis."* It is the rotating-platform *view* feature. It does not attach the player. |
| `AllowSprint(false)` on stairs | The whole tower is stairs, so "no sprint on stairs" is "no sprint". SPRINT, SPRINT FIRE, SPRINT ARMOR, SECOND WIND, DRAW CUT and RUN AND GUN all key off it. Reject on design grounds. |
| Turn off camera bob on stairs | `SetClientDvar` does not exist in T7 and there is no `.csc` camera hook. The only lever on step-bob is **removing the steps under the camera** — i.e. G1/G2/G3. |
| Clientfields to smooth movement | One-way data channel; cannot alter movement. |
| Make zombies non-solid to players | No T7 API found; `self.ignoreme` is a *targeting* refcount (MEMORY: *down-path-stock-contracts*), not collision. And it deletes the map's tension. |
| Ramp as a `script_brushmodel` (to dodge the lint) | Entity collision is navmesh-invisible by classname (`navmesh.json` excludes `script_brushmodel` by type) → zombies path into it and grind. A community thread reports exactly this: zombies "only walk up half way before becoming lost" with brushmodel ramps. **Worldspawn brush only.** |

### DESIGN — remove the exposure rather than fix the surface

These answer a *different*, already-documented complaint. `docs/23:88-90`:
*"A **fast descent route** is the single missing verb of this map"*;
`docs/24:77`: *"The tower is strictly one-way … There is no way down."*
**Confusing them with this one is how a stair fix becomes a three-week project.**

**D1 — Extend the teleporter network.** Fix-confidence 1/5 for the complaint,
3/5 for the underlying want. Today: 4 down-pads (breathers 10/20/30/40 at
z = 3648/7488/11328/15168, `_tod_teleport.gsc:147`) → one base arrival, and 4
base up-pads each gated on its own lap door (`:190`). **Coverage is 4 nodes on a
50-floor climb** — floors 41-50 have none, and every trip routes through z=0, so
"skip some stairs" means "restart the climb". Extending it uses proven code, no
geometry, no bake, no lint. **More teleporters reduce exposure to a bad surface;
they do not make the surface good.**

**D2 — Drop shaft through the core.** Fix-confidence 2/5 for the complaint.
The core is a solid 512×512×19,200 column doing nothing but holding up the
stairs — the largest dead volume in the map. Hollowing it is ~200 brushes.
*Breaks:* navmesh (zombies would path in and fall — needs `clip_ai` or a carver
at the mouths); fall damage (19,200 units is lethal, but `_tod_perk_phd.gsc:248-264`
already proves the `MOD_FALLING` override lane).

**D3 — Stock jump pads.** `<tools>\share\raw\scripts\zm\_zm_jump_pad.gsc` is a
722-line **shipped, zombies-native, struct-driven** launch system with per-pad
velocity/air-time overrides. Pads on landings that fling you up 2-4 floors make
ASCENT a verb instead of a chore. Cheapest "new mechanic" available because it
is already written.

**D4 — Powered elevator.** `<tools>\share\raw\scripts\mp\_elevator.gsc` exists
and is documented in-file, and `SetMovingPlatformEnabled` is a real API. **But**
it is MP-namespace and the platform is a `script_brushmodel` — an entity,
therefore navmesh-invisible — so zombies cannot ride it and will grind. Player-only
express elevator with `DisconnectPaths`, or don't. Unproven in ZM.

**D5 — Zipline.** **Downgraded.** No stock system exists (the only "zipline" hit
in the shipped script tree is a string case in `zm/gametypes/_weapons.gsc:1232`).
Build-from-scratch player-mover with all of the rejected `SetOrigin` problems.

**D6 — Emergent: the ramp becomes the slide.** If G2/G3 ships, BO3's sprint-slide
on a continuous 20.556° descent may chain — the tower becomes its own express
descent, closing `docs/23` §B2 for free and turning the complaint into a feature.
**Unverified** (needs a 5-minute in-game test) and it is the strongest reason to
prefer a *visible* ramp over an invisible one. It would also change economy
pacing, so test it before shipping.

### PERCEPTION (cheap, none of them fix physics)

**P1 — Alternate the tread material per step.** Fix-confidence 2/5 for
smoothness, 4/5 for legibility. Today a whole flight is one material
(`stepMatOf(lap)`, `:435`), so **there is no local depth cue anywhere within a
flight** — the only contrast is at the landings. Alternating two palette entries
per step gives descent depth cues for **zero new brushes, zero new faces, zero
lit-area change.** Cheapest item in this document; the only cost is a FULL build.

**P2 — Glowing nosing strips.** Fix-confidence 3/5. This is literally why
emergency stairs have nosing tape. `box()` textures all six faces identically,
so it needs a thin proud brush per step: 1,600 at 160×4 ≈ 1.1M u² (+0.1% lit)
but **+1,600 faces — bake it.** Consider every-other-step, or only the lower 20
floors. **Pairs perfectly with G3 — the ribs *are* the nosings**, and can be
`_tinted_edge`.

**P3 — Continuous sloped cap rail (fixes #6).** Fix-confidence 3/5 for the
strobe. Two routes: `PARA_EVERY 2 → 1` halves the sawtooth to 6 units but
**doubles parapet brushes (793 → ~1,590) and spends the exact currency
documented as the bake knob**; or **one continuous sloped rail per flight** —
100 brushes replacing ~800, a perfectly straight line, and *cheaper in brush
count*. The second needs the wedge emitter. **Another argument for paying that
cost once.**

**P4 — Floor-number read on each landing.** Orientation, not motion. Noted only
because "the stairs suck" often means "I don't know where I am"
(`docs/24:31`: floors 14-50 are visually identical except an 8-floor colour
cycle).

---

## 6. RECOMMENDED ORDER OF ATTACK — a proposal, not a plan of record

**Nothing here is decided. Every step below is reversible and each one is
designed to make the next one cheaper or unnecessary.**

**Step 0 — Ask one question. Cost: zero.**
*Which classes are complaining, and does "stuck" ever happen with no zombies
nearby?* That single answer discriminates #2 (physics — should skew
SLASHER/SKIRMISHER and sprinting) from #3 (audio — should be class-independent,
and should also show up on map 1) from #4b (bodies — should be
combat-correlated). **Three completely different fixes.**

**Step 1 — One dev probe. `-GscOnly`, no bake, no lint, no geometry.**
A `level.tod_dev`-gated 20 Hz per-player log of `IsOnGround()`, `GetVelocity()`
and `IsSliding()` while one player runs one flight down and one up. This
**settles §3.3 empirically** — the single unknown that everything expensive
hangs on — and simultaneously settles #5. Written to the harness doctrine in
CLAUDE.md and **removed before publish.**

**Step 2 — Ship the free wins regardless of the answer.** One FULL build:
G10 (close the ankle gap, one line), P1 (alternate tread material, zero
brushes), G11 (move risers off landing centres), S7 (the 1 s spawn speed race).
None of these depends on the diagnosis and all four are defects on their own.

**Step 3 — The cheap A/B, gated on Step 1's answer.**
If the probe shows *sliding*: `AllowSlide(false)` (S3) — one call, `-GscOnly`.
If the probe shows *airborne but not sliding*: S4 stay-on-ground, `-GscOnly`.
If the probe shows *grounded throughout*: **H1 is dead** — go straight to
Step 4 for the ascent/perception half and reweight #3 and #4b.

**Step 4 — S1, the surface swap** (repo-owned `tod_surfaces.gdt`, path (b)),
if Step 0 implicated audio. FULL build, zero geometry.

**Step 5 — The structural fix: build the wedge emitter, then G1 (or G3).**
Pay the emitter cost **once** — it unlocks the clip ramp, continuous rails (P3),
and G2 later if the author ever wants it. Start with **G1b (`clip_player`)** as
the *experiment* — it isolates the player-side variable and leaves zombie
pathing byte-identical — then move to **G1a (`clip`)** for shipping if the AI
side also wants it, which the navmesh evidence suggests it does.
My ranking within this step: **G3 (ramp + ribs) > G1 (invisible ramp) >
G2 (bare ramp)** — G3 keeps the stair *look*, gets the ramp *feel*, and hands
brush budget back to the crown.

**Separately, on its own timeline:** D1 (teleporter coverage, cheap) or D3
(stock jump pads). These answer `docs/23` §B2, not this complaint.

---

## 7. HOW TO PROVE IT

### 7.1 The 30-second walk the author can do today, before any build

**A/B by class, then by sprint.** Walk one flight down as **HEAVY** (142.5 u/s,
below the 184.75 threshold) and one as **SLASHER** (209 u/s, above it). Then
walk vs sprint as a single class.

* If HEAVY *walking* feels fine and SLASHER *walking* feels slippery → **H1
  confirmed**, the ballistic model holds, and G1/G3 is the fix.
* If both feel identical while walking and both degrade when sprinting → still
  consistent with H1 (sprint pushes everyone over), but weaker.
* If **all four cases feel the same** → H1 is dead, and the complaint is #3
  (audio), #4b (bodies) or #6 (the rail strobe). That saves the entire geometry
  branch.

Also: **backpedalling in ADS is ~130-180 u/s, i.e. *below* the threshold.** So
under H1 the retreating-and-firing player — the most common zombies action —
should feel *glued*, and only the sprinting player should feel slippery. **If
the reports are the other way round, H1 is wrong.**

### 7.2 The dev probe (Step 1)

Log at 20 Hz per player: `IsOnGround()`, `GetVelocity()`, `IsSliding()`, and the
player's z. Compute the **grounded fraction** over one descending flight and one
ascending flight, per class, walking and sprinting. Predictions to falsify:

| hypothesis | prediction |
|---|---|
| H1 (ballistic) | grounded fraction well under 30% descending at ≥190 u/s, ~100% at 142 u/s |
| BO3 snaps down | grounded fraction ~100% at every speed → **H1 dead** |
| H3 (slide) | `IsSliding()` true on descents |
| H4 (crease) | ascending, horizontal speed drops to ~0 for isolated frames while hugging the core or the rail |

Write it fresh, gate it on `level.tod_dev`, and **remove it before publish** —
CLAUDE.md records that the last throwaway harness had to be reverted.

### 7.3 In-game AI test, if a ramp ships in `clip` (G1a)

1. `/developer 1` then `/ai_shownavmesh 1` (the `/` prefix is required).
   **Look at the staircase BEFORE the change** — that observation costs one
   build and tells you whether the current navmesh over the treads is stepped or
   already a simplified surface.
2. **Prove the navmesh is not stale first.** `cod2map64` must run with
   `cwd = <tools>\bin` or navmesh generation aborts *while still writing a valid
   `.d3dbsp`* (`docs/BO3_MAPMAKING_KB.md:88`). `build_map.ps1` handles it — but a
   change that "did nothing to the zombies" may just be a stale `.hkt`. Use the
   CLAUDE.md `diff -rq` freshness check, never an mtime gate.
3. **A/B one flight.** Ramp a single lap and leave its parity mirror stepped.
   The generator's parity mirroring makes this a genuinely controlled
   comparison — a luxury most maps don't have.
4. **Test at round 15+, not round 1.** The failure mode scales with
   `ASMSetAnimationRate`; `_tod_zombie_speed.gsc:58` `TOD_ZSPEED_STEP 0.0028`
   and `:238` `1.0 + (round-15)*STEP` put the rate at 1.098 by round 50.
5. Watch for: bunching at flight *ends*, zombies pathing the ramp but animating
   into the treads (visual float — bisecting the treads keeps it to ±6, which is
   imperceptible at 72-unit actor height), and any zombie failing to leave a
   breather.

### 7.4 The repo's own tools

| tool | what it will and will not tell you |
|---|---|
| `node tools/lint_tod_geometry.js` | **Control is 0/0/0/0, both routes YES.** It will stay green for a wedge ramp — *because it silently drops the brush*, not because it proved anything. It **will** go red for an AABB clip stack (measured: 6,048 walls) and for any `STEPS × TREAD ≠ 512`. Never edit the baseline to make it green. |
| `node tools/lint_tod_geometry_selftest.js` | **Mandatory** if the lint is edited (adding `clip_player`, teaching it wedges). 9 cases. |
| `node tools/measure_lit_area.js` | **Control: spiral 2709 br / 51.6M u²; TOTAL 4188 br / 1117.5M.** Deterministic, instant. Plain `clip` is free. **`metal_clip`/`concrete_clip` are NOT excluded by its start-anchored regex and would be counted as lit.** A wedge vanishes from both totals — if `TOTAL` stops summing to the generator's brush count, that is the tell. |
| `tools/_bake_test.ps1` | **BAKED / CRASHED and nothing else.** Its timing is not a budget meter: this map has baked at 38.2, 126.2, 35.1, 31.9, 31.3 and 31.8 s on near-identical input. Bake twice before any number decides anything. |
| `node tools/audit_hidden_faces.js` | Advisory. AABB-only; blind to wedges. |
| `.\tools\build_map.ps1` | **FULL build for every option in §5 except S3-S8.** A `.gdt` edit is always FULL. Success = a FRESH `.ff`, not the linker exit code, and freshness is proven only by `diff -rq scripts` / `diff -rq zone_source` against the deployed usermaps tree. |

---

## 8. OPEN QUESTIONS / UNVERIFIED

Ranked by how much they matter.

1. **Does BO3's pmove snap a descending player down onto the next surface?**
   The single load-bearing unknown. Source does (`StayOnGround`, up to
   `StepSize` = 18); GoldSrc snaps 2; **idTech3 does neither**. If T7 snaps ≤18,
   root cause #2 evaporates and half of §5 becomes irrelevant. **Settled by
   §7.1 in 30 seconds or §7.2 in one build.**
2. **Does `surfaceType` alone select the footstep alias family in T7?** The
   *fact* is confirmed (all 30 pack materials are `glass`); the *consequence* is
   not. `material.awi:510`'s tooltip mentions only bullet particles.
3. **Do `clip` / `metal_clip` worldspawn brushes actually cut the BO3 navmesh?**
   Inferred purely from **absence in the `navmesh.json` exclusion list**, which
   agrees with `KB:89` and with The Giant (where the `metal_clip` ramp is the
   main zombie path). Never directly observed. Also unproven: that the `"type"`
   key in that file matches *materials* at all, as opposed to only entity
   classnames.
4. **Do `bg_*` movement dvars set by the host replicate to co-op guests?**
   `_tod_upgrades.gsc:1672` says host `SetDvar` does not replicate; stock relies
   on it working (`_zm.gsc:217-224` disables double-jump for everyone this way).
   Must be verified in a real 2-player session before any dvar-based fix ships.
5. **Do cod2map64 and the Radiant LED bake accept a non-axial brush**, and how
   do they texture the slanted face? Standard Quake-family compilers do; nobody
   ran a build. Related: whether ~17,600 brushes (G4) or ~9,700 (G5 at 64 steps)
   survive the bake.
6. **The defaults of `slide_angle1` / `slide_angle2`** — the string table has
   names and descriptions only. And whether the engine resolves a *slope* from
   axis-aligned treads at all.
7. **BO3's exact base run speed and sprint multiplier.** 190 u/s is the repo's
   own calibration (`_tod_runandgun.gsc:37`), not an engine reading; 1.5× sprint
   is a lineage assumption. **The `v_grounded_max` = 184.75 threshold is
   insensitive to both** (it depends only on `TREAD`, `RISE` and `g`), but every
   per-class row that compares against it inherits them. Also unverified:
   whether `SetMoveSpeedScale` scales *sprint* speed as well as run speed — the
   entire sprint column assumes it does.
8. **Stamin-Up's speed magnitude.** `specialty_staminup` is a pure engine
   specialty; `_zm_perk_staminup.gsc` registers machine/FX/clientfields and no
   number. Unquantifiable from script.
9. **Whether `PM_StepSlideMove`'s multi-plane clip can zero a diagonal move at a
   riser** (root cause #4a) — the leading engine hypothesis for "stuck going up",
   and entirely unmeasured.
10. **Whether bare `clip` produces any footstep sound underfoot.** Relevant only
    if a ramp becomes the walk surface; Treyarch's exclusive use of surface-typed
    clip on stairs is the evidence that it matters.
11. **Whether `metal_clip`/`concrete_clip` resolve correctly on a *published*
    usermap.** They are `t6_legacy` tool textures defined in
    `art_assets/t6_legacy/texture_assets/clip.gdt` (**not** `t10_materials.gdt`),
    used by shipped `zm_giant` prefabs, so they should be in the base asset set —
    but the repo's own KB carries a standing warning about DLC/specialty stock
    assets rendering wrong on published usermaps.
12. **What the `stairs` material flag does in T7.** `clip_stairs` is a real
    shipped material (`clip.gdt`, `"stairs" "1"`) but it is
    `noDraw 1, nonColliding 1, nonSolid 1, playerClip 0, aiClip 0` — a
    non-colliding *hint volume*, not a clip — and it appears in **0 of the 931**
    shipped `.map` files. **Treat it as unusable.**
13. **Whether the navmesh contributes to "stuck" at all.** `lint_tod_geometry.js`
    explicitly cannot see it (`:41-46`), and zombies crowding a 160-wide stair is
    a plausible independent cause that static geometry forensics cannot rule in
    or out.

### Two corrections to claims that circulated during this research

* **The tree is NOT in an armed dev state.** One lane reported
  `level.tod_dev = true; level.tod_god = true;` and a live `dev_crown_test()`.
  Re-checked for this report: `scripts/zm/zm_tower_of_doom.gsc:472-473` reads
  `level.tod_dev = false; level.tod_god = false;` and `dev_crown_test()` survives
  only as comments recording its removal (`_tod_main.gsc:63`,
  `zm_tower_of_doom.gsc:462-467`). **CLAUDE.md is correct; that lane was wrong.**
* **The `.map` was regenerated during this research** by one lane (`node
  tools/gen_tower_map.js`), bringing it into sync with a generator edit that was
  already committed — the teleport-bay back wall and pad rows. Verified
  MD5-identical to a fresh regen, `_tod_door_data.gsc` and `_tod_crown_data.gsc`
  byte-identical, no hand-edits. **Consequence the lane did not state: the
  deployed `.ff` is now stale against the tree and the next build must be FULL
  with an LED bake, never `-GscOnly`** — and builds must be serialised across
  sessions (MEMORY: *build-watchers-and-multi-session*).

---

## Sources

**Local primary (this machine, verified for this report):**
`<tools>\docs_modtools\Scale_Standards.pdf` ·
`<tools>\map_source\_prefabs\zm\zm_giant\geo\{zm_giant_zone_a_staircase_1, stairs_curved, zone_b\zoneb_garage_stair_set}.map` ·
`<tools>\bin\default_navmesh_settings.json` ·
`<tools>\radiant\configs\navmesh.json` ·
`<tools>\bin\cod2map64.exe` (dvar string table) ·
`<tools>\docs_modtools\bo3_scriptapifunctions.htm` ·
`<tools>\deffiles\material.awi` ·
`<tools>\source_data\_emox\emox_mwiii_vertigo_assets.gdt` ·
`<tools>\share\raw\scripts\zm\{_zm.gsc, _zm_jump_pad.gsc, zm_usermap.gsc}` ·
`<tools>\share\raw\scripts\mp\_elevator.gsc`

**Repo:** `tools/gen_tower_map.js` · `tools/lint_tod_geometry.js` ·
`tools/measure_lit_area.js` · `tools/audit_hidden_faces.js` ·
`map_source/zm/zm_tower_of_doom.map` ·
`scripts/zm/zm_tower_of_doom/{_tod_upgrades, _tod_doors, _tod_teleport, _tod_corpse_cleanup, _tod_zombie_speed, _tod_runandgun, _tod_lunge, _tod_perk_phd, _tod_bosses, _tod_perk_scatter}.gsc` ·
`docs/BO3_MAPMAKING_KB.md` · `docs/23_experience_review.md` ·
`docs/24_full_map_review.md` · `docs/33_upgrade_art_audit.md` ·
sister repo `abandoned_cyber_city_zombies/.../_acc_movement.gsc`

**Web:**
[id-Software/Quake-III-Arena — bg_slidemove.c](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/bg_slidemove.c) ·
[bg_pmove.c](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/bg_pmove.c) ·
[bg_local.h](https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/bg_local.h) ·
[cg_view.c](https://github.com/id-Software/Quake-III-Arena/blob/master/code/cgame/cg_view.c) ·
[Steam / BO3 Mod Tools — "My zombies wont walk up stairs properly"](https://steamcommunity.com/app/455130/discussions/0/340412122415898009/) ·
[CoD Modding Wiki — CoD4 Gameplay standards](https://wiki.zeroy.com/index.php?title=Call_of_Duty_4:_Gameplay_standards) ·
[CoD Modding Wiki — A Study on FPS](https://wiki.zeroy.com/index.php/Call_of_Duty_:_A_Study_on_FPS) ·
[Source vs GoldSrc Movement: Downward Slopes](https://www.ryanliptak.com/blog/source-vs-goldsrc-movement-slopes/) ·
[The Level Design Book — Quake metrics](https://book.leveldesignbook.com/process/blockout/metrics/quake) ·
[3dmappers — BO3 Scale Standards](https://www.3dmappers.com/forum/tutorials-and-helpful-information/1514-black-ops-3-scale-standards) ·
[TF2Maps — Stairs and your map](https://tf2maps.net/threads/article-stairs-and-your-map.8827/)
