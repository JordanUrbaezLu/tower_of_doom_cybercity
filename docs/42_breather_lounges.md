# 42 — The Breather Lounges (v13, 2026-08-28)

User brief: "How can we redesign the breather areas so they are nicer and more
atmospheric ... space things out a bit better. One thing is pap and ammo box
are so close to each other that it can trigger the wrong thing occasionally ...
Maybe each one can have its own color theme ... Teleporter can be off in its
own pathway that stems from the breather room ... I dont really want to add
furniture. Maybe 1 or 2 models. ... maybe the idea of putting a roof and walls
in these breathers."

Delivered: roof + walls + per-floor color theme + the teleporter on its own
spur + a mechanical fix for the trigger crowding. **Zero new models** — all
brushwork; the furniture is the same set that already existed.

## The reported bug, measured

The old layout parked the Pack-a-Punch at (-320,-470) — in the entrance path —
with its trigger at (-320,-526) r64, and the ammo crate trigger at (-310,-700)
r72. Centre distance 174u, rim gap **38u**, and both cost 5000. Holding USE at
the boundary bought the wrong 5000-point thing. The v10.4 rule ("every
use-trigger 220u+ from its triggered neighbour") existed only as a comment;
now it is an assert (below).

## Move 1 — roof + walls (the lounge)

Every old 56-tall parapet band grows into a full wall in the same 20-unit
band; the room footprint is untouched. Wall anatomy, z above the mid-slab:

| band        | z          | material                              |
|-------------|------------|---------------------------------------|
| sill        | 0–56       | plain theme colour (the old rail line) |
| window band | 56–192     | OPEN + `clip_player` guard; 28-wide plain-theme mullions |
| lintel      | 192–288    | `<theme>_tinted` (softer panel)        |
| roof        | 288–360    | `MAT.ground` dark navy, **72 thick**   |
| trim ring   | 360–368    | plain theme, 24 wide                   |

* `clip_player`, not `clip`, in the windows: players stay in, **bullets pass**
  — you can shoot zombies on the spur gantry and on the stairs above through
  the windows. lint_tod_geometry now classifies `clip_player` as BLOCK (first
  axial use; the stair ramps are wedges the lint never parses).
* The roof is 72 thick **on purpose**: the lint calls any `_tinted*` slab
  ≤64 thick a walkable DECK and would demand guards on it. It is unreachable
  anyway — every approach above it is railed + rail-capped (verified: lap N+1's
  landing rail cap tops out 160u above the trim ring).
* Doorways: the old landing gap (x[-416,-256] at y=-416, even frame) is now a
  real 160×192 doorway under the lintel; the spur doorway (S wall) is a second
  160×192 opening with a 240-tall gate frame (posts + lintel) outside it.

## Move 2 — one colour per breather

`BREATHER_THEME` in gen_tower_map.js — floor grid, sill, mullions, trim, gate
and all three room lights speak one hue per floor:

| floor | key    | light           | why                                   |
|-------|--------|-----------------|---------------------------------------|
| 10    | blue   | `0.35 0.55 1`   | the base arena's colour — the city follows you up |
| 20    | green  | `0.35 1 0.6`    |                                        |
| 30    | orange | `1 0.6 0.25`    |                                        |
| 40    | yellow | `1 0.85 0.35`   | the crown's gold — the last stop foreshadows the prize |

All four keys are from the `_tinted_edge` five (blue/green/orange/red/yellow)
so the floor can carry the theme grid. RED is deliberately unused: on this map
red means danger (beacon, ruby, boss). What this replaced: laps 10/20/30/40
all hit `EDGE_COLORS[4]`, so all four floors were the SAME yellow with rails
in four unrelated palette colours.

## Move 3 — the teleporter spur

Authored odd-frame in the generator (`SPUR_*`), mirrored like everything else.
Even-frame (actual) numbers: doorway in the S wall at x[-784,-624] → 320-long,
160-wide open-air gantry (rails + caps) → 288×288 pad platform, porter at
(-704,-1456). Up-riders land on the gantry at (-704,-1296) — 160u toward the
room, outside the pad's 120u gather (v10.4 rule, now asserted). The spur has
no roof; the deck riser at (-750,-950) stands 42u inside the gate so the
annex is never a quiet camp pocket.

**v13.2 (2026-08-28, same day): the WATCH ITEM fired.** User: "add one zombie
spawn in the path from breather and telepoter for each zone" — exactly the
mid-neck riser this section predicted. Each lounge now has a THIRD riser at
even-frame (-704,-1120) on the gantry centreline, y derived in the generator
as `SPUR_PAD_Y - TP_ARRIVE_OFF - 176` so the v10.22 materialize-clearance
rule (~165u) holds by construction: 176u from the up-arrival, 336u from the
pad (216u past the gather ring), 60u outside the gate posts — zombies surface
on the open gantry, cutting the walkway between pad and room — and ~176u from
the deck riser so spawn events never stack. v13's "the spur emits NO risers"
stance is retired.

## The spacing fix — now mechanical

Each interactable owns a wall (even frame):

| wall | fixture            | model         | trigger        | r   |
|------|--------------------|---------------|----------------|-----|
| N    | upgrade station    | (-500,-460)   | (-500,-516)    | 64  |
| W    | Pack-a-Punch       | (-744,-680)   | (-688,-680)    | 64  |
| E    | ammo crate         | (-310,-700)   | (-310,-700)    | 72  |
| S    | perk pads ×2       | —             | (-360/-536,-959) | ~48 |
| spur | teleporter         | —             | (-704,-1456)   | 110 |

Worst pair is now station↔PaP at 249u (needs 192); the old PaP↔crate pair is
379u (was 174). **`BR_FURN` in gen_tower_map.js is the single source of
truth**: the generator asserts every pair ≥ r_a + r_b + 64 at generation time
and emits `_tod_breather_data.gsc` (same no-drift contract as door/crown
data), which `_tod_powerups`, `_tod_upgrades`, `_tod_ammo_crate` and
`_tod_teleport` all read. The crate's collision clip is cut from the same
table. `_tod_perk_scatter` keeps its own pad table (machines relocate at
runtime); its two S-wall pads are mirrored into `BR_FURN` for the assert with
a lockstep note.

Unchanged: perk pads, both risers, all four respawn spots, zone gating,
respawn groups, teleport-bay side of the network, hints, costs, cooldowns.

## Iterating

* `node tools/preview_crown.js --filter "^lap10 breather" --out <prefix>` —
  renders the lounge without a build (plan/elevation/under auto-fit the
  selection). The tool now hides `clip_player` like `clip`.
* Retunes: theme = `BREATHER_THEME` (one entry per floor); lintel/mullion
  materials = `mPanel`/`mGlow` in the lounge block; furniture = `BR_FURN`
  (then regen — scripts follow automatically). Any of these is geometry → a
  regen + FULL build + bake test.

## v13.1 — the doorway corner fix + two polish pieces (2026-08-28, same day)

User live report after the first walk-through: "the roof panels dont connect
on one corner for all breather zones." Root cause, from the geometry: the W
wall starts at y=436 odd-frame (y[416,436] belongs to the lap's own N-flight
parapet — extending into it would coplanar-fight two materials on the x=256
plane) and the S lintel starts at x=256, which left the DOORWAY corner column
x[236,256] y[396,436] empty from rail height to the roof at +288. The roof
corner floated over an L-shaped hole beside the entrance on all four lounges
(one authored corner, mirrored); the flight's rail cap made it
collision-tight, so it was purely visible.

Fix + polish, all theme-plain material, zero models, +10 brushes per lounge:

* **corner pier** (2 brushes): `corner pier base` stands on the flight's
  first tread (top mid+12, narrowing that one tread by 20u at its far
  corner); `corner pier` sits flush on the base AND the parapet top (both
  mid+80) and carries the roof. Doubles as the doorway's east jamb — the
  same post language as the spur gate.
* **ceiling halo** (4): a 256-square glowing ring hanging 8 proud under the
  roof over the room centre — the interior echo of the trim ring, visible
  through the windows from the stairs. Top face buried flush against the
  roof slab, so nothing is standable.
* **pad ring** (4): a 1-proud glow ring inlaid in the teleporter platform
  (the base-arena inlay construct), inner edge 100u off the pad centre —
  clear of the ~83u-half porter assembly, walk-over height.

Shipped in the combined v13.1 build together with the parallel session's
power-hall zone + riser and Death Machine retune (see CHANGELOG).

## Also in the v13 build (peer-triage fix)

`_tod_powerups.gsc` non-class PaP lane: `get_upgrade_weapon` can return the
same weapon, and the lane charged 5000 before verifying — the "PaP took my
cash and changed nothing" live report. Now verifies `up != w` BEFORE charging,
and the give-failure fallback refunds the 5000 alongside re-giving the
original weapon.

## v13.6 — the roof came off (2026-08-29)

User, after walking v13: "The roof on the breathers I think look better when
open. You cant look up and see the tower so it kinda makes it worse. Lets
remove that." The lounges are OPEN-TOP rooms: roof slab, trim ring and the
v13.1 ceiling halo are gone; walls, sills, windows, lintels and the corner
pier stay; a glowing 8-tall cap band on the wall heads keeps the theme-colour
outline at night. **Move 1 above describes a roof that no longer exists** —
read the wall table with the last two rows deleted and a cap band in their
place. (Same build: teleporter rules, ALXS PaP — see CHANGELOG v13.6.)

## v16.7 — the polish pass (2026-09-01)

User: "Can you look into enhancing the breather zones again? ... I want to
continue enhance however we can." Brief re-read from source (the v13.6 roof
removal above had not reached CLAUDE.md), the 96 Workshop comments pulled
first (none names the lounges' look). The room was structurally complete and
read as an empty box with machines pushed to the walls, floating over a void
from below. Seven brushwork moves + two script moves, zero models, footprint
untouched. Every geometry knob is a `BR_*` constant in the generator's v16.7
block; the room block emits everything in the odd frame and `bb()` mirrors.

| move | what | brushes/lounge |
|------|------|----------------|
| fixture panels | the window bay behind each machine becomes a solid `<theme>_tinted_edge` panel (the floor's grid stood up). Perk wall = one panel x[236,624] odd (replaces the N mullion + clip void); PaP (E wall) and crate (W wall) = the middle bay y[622,786] between the mullions; station (S wall) = the west bay x[436,604]. | +4 −2 |
| finials | 36-sq glow posts on the four corners, 128 tall above the cap band | 4 |
| floor inlay | 1-proud ring (outer half 120, 20 wide) at the room centre (528,704 odd) + spokes to the station/PaP/crate feet + a spoke to the perk wall ending in a bar over both pads | 9 |
| pad pylons | 36-sq glow posts centred on the platform's rail-band corners, slab bottom to +240 | 4 |
| gantry hoops | two post+lintel frames at y 1132/1212 odd (posts outside the rail bands, lintel in the 192..240 band ON the posts) | 6 |
| underside | glow band (slab-thick) under all four wall bands; 3-tier pendants (half-widths 64/32/16, 48 each) under the E/W/N midpoints; a 48-sq thruster cube 64 under the pad | 14 |

Plus four accent lights per lounge (PaP/station/crate/perks, radius 240, 40u
into the room from each machine) — 288 → 304 map-wide.

**Two furniture nudges** so each machine sits on its panel's axis: PaP y −680 →
−704 (even frame), station x −500 → −520. Re-measured: the generator's
pairwise assert (worst pair now station↔PaP 252u, needs 192), the two deck
risers (PaP model 244u from the N riser), the respawn spots (≥130u from the
station trigger, ≥230u from the PaP trigger — both still hold: 138u / 240u),
the doorway (station model edge 54u clear of the jamb). The spire hubs read
`BR_FURN` too, so the hub PaP moved with it.

**Script (`_tod_atmosphere.gsc`)**: `lounge_fx()` places four stock LOOPING
effects per lounge with server `PlayFX` under the blackscreen — motes from the
open top, interior haze, ground fog on the pad, a soft vent at the gate's east
post. The render lane is map 1's `fx_at` (loops render; one-shots need a
tag_origin host). `lounge_arrival_watch()` plays `tod_lounge_arrive` (2D, once
per player per lounge, alive + playing only) the first time a player's origin
enters the lounge box — the same box `_tod_endless_rounds::tod_player_in_breather`
uses for the spawn relief (LOCKSTEP). The wav is an ffmpeg-synthesised
rising arpeggio (E5–G#5–B5–E6 over an E3 pad, 2.0 s, peak −1 dBFS).

Lint: 0 misplaced walls, 0 unguarded edges, no baseline motion (the inlay is a
1u step, the panels are 136 tall so never DECK, everything else is plain glow
= BLOCK). Lit area: the spiral 59.1 → 63.2M u² (+0.3% of the map). Preview:
`node tools/preview_crown.js --filter "^lap10 (breather|ammo)" --out <prefix>`.

Left for the user (play changes, not looks): a station that pauses or slows
the world (Workshop ask; the no-pause is a recorded design call), a guaranteed
Max Ammo per breather door (docs/24 PK-09), perk info plaques (LUI lane only —
hints are the 250-slot budget).

**To revert the whole pass:** `BR_POLISH = false` (generator, geometry + lights
+ the two furniture nudges; regen + FULL build) and `TOD_LOUNGE_AMBIENCE 0`
(`_tod_atmosphere.gsc`, FX + chime; `-GscOnly`). Both proven by hash: the
switch-off regen equals the pre-pass map byte-for-byte (see CHANGELOG v16.7).

## v16.57 — the window panels are OFF (2026-09-02)

User: *"remove the windows blocking views in the breather rooms of the first
tower"*. The v16.7 FIXTURE PANELS — the solid `mBoard` boards that filled the
window bay behind every machine (the whole perk wall was one) — are gated by a
new switch, `BR_WIN_PANELS` in `gen_tower_map.js`, now **false**. Every bay is
the v13 open window again: mullions + the `clip_player` void, so bullets pass
and players stay in. Everything else in the v16.7 pass (finials, inlay ring,
pylons, hoops, under-glow, pendants, lights, the two BR_FURN nudges) stays
under `BR_POLISH`. `BR_WIN_PANELS = true` restores the boards. Geometry ->
regen + FULL build.
