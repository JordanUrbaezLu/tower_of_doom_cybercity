# 64 — The Tower Facelift (v16.11, 2026-09-01)

User: "Look into overall design enhancement we can make to the tower physical
appearance overall to improve design and player pleasability" → ranked review
(artifact "Cybercity Tower Facelift", https://claude.ai/code/artifact/b58fdc99-f613-47bd-8850-d16eac455183)
→ "Lets do the first 4". This file is the repo-side record of the review's
findings and of batch one. The lounges (docs/42) and the crown (docs/34) were
out of scope by design.

## What the review measured

From the generator and the shipped map, `measure_lit_area.js`, the August
full-map review (docs/24), the stair note (docs/39), the live Workshop page and
its 96 comments, and the six screenshots on the item (none of which shows the
ordinary climb):

- The crown is 71% of all lit surface; the spiral, where the run happens, 4.7%;
  the base arena, the first minute of every run, 0.4%.
- Per lap: five brush kinds (treads, landings, parapets, invisible rail caps,
  ramp clips), two lights, nothing decorative on any of the 100 flights.
- Colour: treads/parapets/core cycled an 8-hue `PALETTE` per lap, landings a
  5-hue `EDGE_COLORS` list — a 40-floor beat; the same colour never meant the
  same height.
- The core: a plain 512-square column for 19,200 units, one band per lap.
- Doors: bare 160×20×128 slabs in one green material, instant `Hide()`; the
  authored `script_vector`/`script_transition_time` keys were read by nothing.
- Never done from docs/24: district palette (A7/L5), door slide + sound (A9),
  core windows (L12), pockets (L9), fog retune (A12 — the fog only started
  rendering in v14.37/41, so its heights were tuned blind).
- Player words on record about looks: "STAIRS SUCKS" (unspecified), "no pics
  no clicks", "difficult time finding the power", the spawn teleporters "not
  aligned perfectly and feel quite confusing to know which is which", and the
  user's own: "in awe", "look up and see the tower", shell walls "ugly".

## The ranked list (the artifact has costs and verdicts)

1. District palette — **batch one**
2. Door gates that open — **batch one**
3. Base plaza and wayfinding — **batch one**
4. Teleport bay colour code — **batch one**
5. Fog retune (`TOD_FOG_HALFWAY_HEIGHT` 1200 → ~3600; one constant, -GscOnly)
6. Lower the rails (`PARA_H` 56 → 40; the eyeline sawtooth of docs/39 #6)
7. Core spines (flush split of the core band into a cross, +400 brushes, +0 area)
8. Wireframe city ring (60–120 brushes, +100–200M u²; MUST bake-test as a
   `TOD_MAP_OUT` variant first)
9. Mid-district pockets on floors 5/15/25/35/45 (play change)
10. Core windows at landing height (play change)
11. Workshop screenshots (no build)

## Batch one, as built

One switch, `FACELIFT` in `tools/gen_tower_map.js`, gates the four geometry
halves; `TOD_DOOR_SLIDE` in `_tod_doors.gsc` gates the slide. Switch-off regen
was proven equal to the v16.7 map by md5 (76dd78ab…) when the switch landed.

### 1. Districts

| floors | key | light | why |
|--------|-----|-------|-----|
| 1–10 | blue | `0.35 0.55 1` | the base arena's blue; lounge 10 |
| 11–20 | green | `0.35 1 0.6` | lounge 20 |
| 21–30 | orange | `1 0.6 0.25` | lounge 30 |
| 31–40 | yellow | `1 0.85 0.35` | lounge 40, the crown's gold foreshadowed |
| 41–50 | red | `1 0.3 0.3` | danger; the last ten under the crown, no lounge |

`districtOf(lap)` feeds `lapPal` (lights), `stepMatOf` (treads + core band;
`_tinted` on odd floors, `_tinted_edge` on even — parapets stay plain hue
because a `_tinted` parapet is a ≤64-thick `_tinted` slab = DECK to
`lint_tod_geometry` and would flag ~hundreds of unguarded edges),
`paraMatOf` (parapets) and `edgeMatOf` (landings, breather floors). The end
landing of lap L wears lap L+1's colour (`edgeMatOf(lap + 1)`, unchanged), so
the landing where you buy the next door is the first thing in the new colour.
Lap 50's end landing clamps to red. The lounge themes (`BREATHER_THEME`) were
already these four colours, so each lounge is its district's culmination.
Zero brushes, zero lit area.

### 2. Door gates that open

Per lap door (odd frame; even mirrored by negation): post
`x[PX+PARA, PX+PARA+20] y[-266,-246] z[b, b+152]` OUTSIDE the rail band (a
post IN the band would coplanar-fight the parapet; a post in the path would
narrow it); lintel `x[CORE, PX+PARA+20] z[b+128, b+152]` sitting on the slab's
top; sill `x[CORE, PX] z[b, b+1]` in the slab's material, hidden until the
door opens. Frame = plain hue of the district the door opens INTO, slab = its
`_tinted_edge`. 3 brushes × 50 doors. The roof, power and bay doors keep their
old slab and get no gate.

The slide: `open_slab( d, slab )` — `MoveX` toward x=0 by 168 over 1.2 s (the
160-wide slab ends fully inside the solid 512-square core), de-rez burst at
the doorway (`tod_perk_scatter::derez_burst`; the import is cycle-free per
docs/61) and stock's `zmb_heavy_door_open` via `zm_utility::play_sound_at_pos`,
then the unchanged Hide / NotSolid / ConnectPaths. Slab solid and paths cut
until the slide ends. Threaded from all three open paths (buy, v13.9
force-open, dev open-all). The authored rise (`script_vector 0 0 130`) was
dropped on purpose: a rising slab passes through any lintel low enough to read
as a frame.

### 3. Base plaza and wayfinding

- `base trace spawn` x[-440,-420] y[-420,-40]; `base trace east` x[-440,580]
  y[-440,-420] — rides the north edge of the power hallway's opening
  (y[-540,-420]), 16u clear of the inlay ring's inner edge (-456), and runs
  20u into the hall floor; `base trace door` x[326,346] y[-420,-310], 4u
  short of the lap-1 door trigger (y1 = -306). All 1u, `MAT.baseInlay`.
- Core foot ring, 40 wide, 1u: N/S/W full; E starts at y=-240 so it never
  shares a plane with the lap-1 sill (both would be blue_tinted_edge at z=1).
- `baseWallRun(label, x1, x2, y1, y2)`: the five arena walls split along their
  length into blue runs with a 40-wide `MAT.pilaster` (cyan) every 280 units
  (centres ±140, ±420; skipped where a doorway or wall end is within 20u) and
  a 20-tall cyan cornice on top. Flush; the annexes keep plain walls.

### 4. Teleport bay colour code

Pad i (generator order `[-X,YN] [X,YN] [-X,YS] [X,YS]`) lands on breather lap
(i+1)×10 — LOCKSTEP with `up_orgs` in `_tod_teleport.gsc` (front-left 10,
front-right 20, back-left 30, back-right 40). Each pad's 176-square wears
`BREATHER_THEME[(i+1)*10].key + '_tinted_edge'` and gets a light (radius 200,
z 120) in that theme's light colour. The arrival mark stays green.

## Numbers

12,375 → 12,563 world brushes (+188 = 150 gate + 7 base inlays + 31 wall
segments/cornices), 1,225 → 1,229 entities (+4 lights). Lit area 1,332.7 →
1,335.3M u² (+0.2%). Geometry lint 0 misplaced walls / 0 unguarded edges, no
baseline motion.

## Revert

`FACELIFT = false` (generator; regen + FULL build) and `TOD_DOOR_SLIDE 0`
(`_tod_doors.gsc`; -GscOnly). Both are one-line flips; the geometry one was
proven by hash against the v16.7 map.

## v16.13 — core spines (item 7) + the door-clip fix

**Core spines.** `CORE_SPINE_W = 32`. Each core band (512×512×384 per lap)
is seven boxes: `spine NS` (x[-16,16], full y), `spine W` (x[-256,-16],
y[-16,16]), `spine E` (x[16,256], y[-16,16]) in `paraMatOf(lap)` (the plain
district hue), and four corner blocks in `stepMatOf(lap)`. Same volume, same
exterior; the lit-area tool over-reports the core (it counts the internal
faces cod2map culls). +300 brushes.

**The invisible wall above every door** (player reports, 2026-09-01). The
anti-vault clip over each slab (z from the slab's top to +600) was a
WORLDSPAWN brush, so it survived the purchase and stopped anyone jumping down
the flight through the open doorway (head ~135-150 above the door's floor at
the door line vs a clip bottom at 128). It is now the second brush of the
door's `script_brushmodel` on all 153 doors (50 lap + roof + power + bay +
100 spire): guard intact while shut, gone with the slab when bought, no script
change on either tower. Regen proof: 0 worldspawn door clips, 153 door
entities with one clip brush each.

## Left on the list

Items 5–11 above, untouched. Decisions the review asked for and still open:
red vs white-cyan for district five (shipped RED — flip `DISTRICTS[4]` to
`{ key: 'yellow' ... }` or any `_tinted_edge` hue to change it), go/no-go on
the city ring bake test, pockets and core windows (play changes), and whether
the rail experiment goes in before or after a play test of this batch.
