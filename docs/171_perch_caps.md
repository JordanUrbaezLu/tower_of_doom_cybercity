# 171 — Perch caps: no standing spot the horde cannot reach (v19.71, 2026-10-03)

## The report

A Workshop tester, playing the Slasher with the ATHLETE wall-run:

> Small visual glitch: as Slasher you can wall run through the Tower of Doom:Cyber city
> map sign might want to move it up just a little.
> Big glitch: ... I just tested the ammo box on first floor and first attempt am on top of
> the box and cant be hit. Might make it so it would push you to one of the sides of the box
> not be able to go on top of it. Same thing with quick revive can get behind it. I was
> able to replicate this with rampage also. I'm sure these could be found on each floor ...
> in the main area where the heavenly perk machine is, I know it's bumped out a little bit
> so you could run behind it ... You might consider doing that also with the ammo box.

The user: "Wall running seems to have not been thought through enough. Lets find a
solution to fix these. Even the slanted clips might help from abandoned cybercity map.
But go ahead and think and resolve any potential gaps."

## Why it happened

* **Every prop's collision was a flat-topped box.** The ammo crate's clip is 58 tall
  (the V6 crate itself is 29), the Rampage switch's 40, the power terminal's 88; the
  perk machines, altars, Pack-a-Punches and the uplink use stock `zm_collision_perks1`
  boxes spawned at runtime.
* **A zombie only swings inside 64 units, origin to origin, in 3D** (stock
  `zombie.gsc zombieShouldMeleeCondition`), and the navmesh only joins floors one
  18-unit step apart. A player on a box top is off the navmesh and out of reach. The
  tester proved it on the 40-tall switch too, so the arithmetic is not trusted: any
  top **30 or more** above the floor beside it counts as a perch (`perch_core
  HIT_DZ_MAX`).
* **The athlete jumps 2.25x higher (~88) and runs on walls** (v16.34), so every one of
  those tops has been reachable for a month. The V6 crate (v19.69) put the crate's
  clip top within reach of any class.
* **The vendors stood off their walls**: altars 64 off with their mesh reaching 19
  behind the origin (a 45-unit slot), Pack-a-Punches 56-60 off (37-41), the base crate
  27, the lounge crates 17, the summit crate 47 — slots a player (30 wide) fits into.
* **The spawn sign has no collision** (a script_model), so a wall-runner on the core
  face ran straight through its relief.

## What was built

### 1. The perch model — `tools/perch_core.js`

One model, two callers. A PERCH is an upward face a player can rest on (crouch
headroom 48) that is not a floor (a DECK, or a stair ramp), that no zombie on the floor
beside it can swing at (the 64 rule, and never at 30+ up), and that is within athlete
reach of a walkable floor — more than 18 and at most 200 up, at most 192 across, with
nothing on the straight run between them rising past both ends (a rail and its cap, a
wall, the core). Every number is a parameter in `DEFAULTS`.

On v19.70's map the model found **1,499 perch faces in 115 families**: every ammo crate
(68), the Rampage switch, the power terminal, the rocket wreck, the invisible rail caps
on every flight and landing (168 over the floor they guard — 68 on the spire hubs' W
flights), the trial halls' fences, lamps, pillars, lintels, panels, the throne, the
gallery caps, the lap-door lintels, the shelves, the hoop recess.

### 2. Perch caps — designed, for every prop (`gen_tower_map.js` PERCH CAPS)

A **steep player-only wedge** (`clip_player`: bullets, zombies, grenades and bodies pass)
over the prop: its low edge at the prop's front, its high edge **buried 16 into the wall
behind it**, so there is no ridge to balance on and no V-notch against the wall. Slope
3.5 (74 degrees): map 1 learned in play that 56 still let BO3 players stand and 72 did
not (`abandoned_cyber_city_zombies/tools/add_prop_clips.js gableBox`).

* **Crates (68), the Rampage switch**: the cap starts `PERCH_SLOT` (20) above the body
  clip. Their use-triggers sight-trace to an origin that sits in that slot, so the
  prompt still reaches the long sides; no player fits in 20.
* **Script-collided vendors** (9 perk pads read straight out of
  `_tod_perk_scatter.gsc`'s `make_pad` table, 6 altars, 12 PaPs): the cap starts 80 up,
  above a standing player and below any machine top, as wide as the three collision
  boxes need, trimmed to where the wall really runs.
* **The uplink** stands free on the terrace: a 400-tall column instead.
* **The power terminal**: from its 88 top.
* **The sign**: a clip box round the relief plus a cap on its top ledge; lifted
  100 -> 160 so the ordinary wall-run along the core passes under it.
* **The rocket clips** (script_brushmodels): the fin prism's flat ring ledge 100 up is
  now an octagonal frustum at the same 74 degrees.
* **The spire hall gates**: 128 tall with open hall above — a player could stand on one
  mid-trial or clear it. A player clip now rides inside each gate entity up to just
  under the core (the lap doors' anti-vault rule).

Caps are emitted LAST (`emitPerchCaps`), when every brush they could meet exists: each
proves it backs onto a wall, and stops under a floor above it (never through one) or
under a solid that covers all of it — any other solid it simply overlaps, because
cutting a wedge flat under a partial solid leaves a flat strip on top.

### 3. The perch seal — automatic, for everything else (`gen_tower_map.js` PERCH SEAL)

The generator runs the model over every brush it is about to write and closes each perch
with a player-only box over the ledge: up to `REACH_V + 8` above it (out of reach of every
floor below the old top), or to the underside of each floor above it — a ledge under a
staircase becomes a stair of seals in one pass. Re-run until the model finds nothing: two
passes, **1,498 seals**. The generator cannot write a map the gate fails.

### 4. Every vendor flush against its wall

| Vendor | Was | Now |
|---|---|---|
| Base altar | (0,-320), hand-typed in script, 45-unit slot | (0,-276), GENERATED (`base_station_org/_trig/_yaw`) |
| Lounge altars (4) | y -460, 25 slot | y -436 |
| Lounge PaPs (4) | x -744, 37 slot | x -780 |
| Crown altar / PaP | 64 off the wall, ~43 slot | 24 off (the gold shrine panel stands 4 proud) |
| Spire hub PaPs (7) | 60 off the drum, 41 slot | 20 (`SP_VENDOR_OFF`) |
| Base crate | x -320, 27 off the core | x -294, 1 off |
| Lounge crates (4) | 17 off the sill | 1 off |
| Crown crate | 11 off its panel | 1 off |
| Summit crate | 47 off the rail | 1 off |

Each moved straight back along its own axis; its trigger moved with it.

## Build

FULL BUILD OK 14:24 Eastern 2026-10-03, .ff 155,544,448 B (written 14:23:12); own compile
(d3dbsp 14:17:18) + bake (.led 45,145,470 B 14:20:30); navmesh 2 components (both towers one
walk); every gate in the build passed, the perch self-test and perch lint (0) among them;
scripts / zone_source / ui == deployed, nothing synced after the .ff. Against v19.70's map
(archived at tmp/perch_pass_20261003/map_before_v1970.map) the only changes are the 99 caps,
1,498 seals, the sign body, the moved crate bodies and lounge inlay spokes, the crown PaP
prefab, the lounge accent lights, the 7 hall gates and the 2 rocket clips. UNPLAYED.

## Gates

* `tools/lint_tod_perches.js` — every FULL build, after the hall bunker lint: zero
  perches, except families written into `lint_tod_perches.baseline.json` with a reason
  (there are none). ~20 s.
* `tools/lint_tod_perches_selftest.js` — runs first: the base crate without its cap,
  the switch without its cap, the hub-10 rail cap without its seal and a new capless
  column must all be caught; a 24-tall box must not be.
* The geometry lint, the hall bunker lint, the crate-contract test, the rocket ride test
  and the altar gate all pass on the new map (the altar gate now pins the generated base
  altar).

## What it cannot see

* **Drops** from a higher floor onto a ledge below it. Every such spot in this map is
  railed and capped.
* **The exact wall-run envelope.** `REACH_V` 200 / `REACH_H` 192 are generous guesses;
  if a tester finds a perch the gate calls clear, raise them and regenerate.
* **Stock collision sizes.** `zm_collision_perks1` is a packed stock asset; the vendor
  caps are sized to cover any plausible box (80 up, +-72 across).

## Diagnostics

Generator: `perch caps: N`, `perch seal: N seals in P passes`. `TOD_PERCH_DEBUG=<label
substring> node tools/gen_tower_map.js` prints every seal it emits for matching ledges.
`node tools/lint_tod_perches.js --near X,Y,Z[,R] --verbose` lists perches near a point
with the floor each is reached from.

## Rollback

`git` the generator; the caps are `PERCH_REQ` / `emitPerchCaps()` and the seal is
`perchSeal()` (comment the call and regenerate). The vendor moves are `VENDOR_STANDOFF`,
`CROWN_VENDOR_OFF`, `SP_VENDOR_OFF`, `BASE_CRATE`, `BR_FURN.crate`, `CRATE_ORG`,
`SP_SM_CRATE`, `BASE_STATION`. Geometry: FULL build.
