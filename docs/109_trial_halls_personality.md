# 109 — THE SEVEN TRIAL HALLS: one story each (v17.86)

> **v18.80 (2026-09-10): THE ROOMS.** The set-pieces below were replaced by
> room-scale rooms with height (a stage, a cage block, a parapet platform, a
> chancel, two rings, a comb, a throne platform) — `docs/130_the_rooms.md` is
> the current record; the stories and colours here still hold. Plan views in
> `docs/109_trial_halls/` are re-rendered for v18.80.

> **v18.78 (2026-09-10): the SHELL is per hall too, and no hall has a cubby.**
> The rooms below were redrawn so no piece makes a one-way bay, every hall
> puts its PaP / crate / respawn on its own walls, and the two pockets every
> hall shared (the porch behind the gate, the alcove under the SE landing) are
> either sealed or rising. The record of that pass — the diagnosis, the rule,
> the lint that proves it and the per-hall table — is `docs/128_open_halls.md`.
> The plan views in `docs/109_trial_halls/` are current (re-rendered v18.78).

> **STATUS: BUILT v17.86 (2026-09-05), UNPLAYED.** User: *"They still look the
> same in design and dont really look better and uniquer per trial. I want each
> one to have its own personality. You can keep the textures but just better
> design and personality for each. Should be a story for each trial."*
>
> v17.69 gave each hall a light colour and a floor inlay and left the room
> itself — the same gold floor, the same red drum, the same gold rails, the
> same pillar vocabulary — untouched, so seven halls still read as one hall.
> This pass rebuilds the ROOM per trial: its floor, its walls, its set-piece,
> its lamps, its plaques, all from the same 30-material vertigo pack.

Plan views (drawn from the EMITTED brushes by `tools/preview_trial_halls.js`,
north up, entrance at the south-west): `docs/109_trial_halls/sheet.png`, one
`hall_<n>.png` per trial. Re-run the tool after any layout edit.

## A. What every hall now owns (the kit)

Everything below comes from ONE row in `SP_RM_LAYOUTS` (generator) plus its
hue's entry in `SP_HALL_KIT`. The fight for each hall is unchanged
(`_tod_spire.gsc::trial_recipe`, matched by index); the banners (docs/105)
already carry the same seven colours.

| part | before (v17.69) | now (v17.86) |
|---|---|---|
| hall floor (every slab incl. the porch fan) | gold `yellow_tinted_edge` in all seven | the hall's own colour (`kit.floor`) |
| inner walls: porch wall, notch rails, the S flight's inner wall, the galleries' rails | gold plain in all seven | the hall's colour, plain grid (`kit.wall`) |
| the drum's inner faces | bare red | a LINER band (8 proud, z 24..248; E stops at 152 under the gallery flight) in the hall's colour, split round the PaP, the crate and the plaques |
| pillar / post shafts | red | the hall's colour |
| set-piece | pillar / post / low wall / dais / big plinth | + TALL wall (160, unseeable-over), FENCE (bars at 32 pitch, 16 gaps), LAMP pylon (24 sq × 200, filled glow), PLAT step (12, DECK), THRONE, LINTEL beam (pillar cap to cap at 168..192), PANEL plaque on the N/W drum face |
| floor sigil | 1u inlay in the hue | kept; now a step up the brightness ladder from that hall's floor |
| lights | 5 in the hue | unchanged |

The vertigo pack is two textures and a brightness ladder (memory
`vertigo-pack-is-two-textures`): plain = black tiles + a bright grid line,
`_tinted` = filled glow, `_tinted_edge` = the same at half. So each kit pairs
a FILLED floor with PLAIN-grid walls and a filled lamp — contrast by texture,
not by hue. Only 30 names exist; cyan / purple have no `_tinted_edge`, white
has no tinted form at all (the white hall stands on a cold navy floor under
white light, with white grid walls and white bars for lamps).

## B. The seven stories

| # | floor | name | colour | the room | the story |
|---|---|---|---|---|---|
| I | 10 | **THE RING** | gold | a raised, brighter gold step at the centre; a gold pillar on each of its four corners with beams between their caps — a cage of light over the ring | THE PROVING GROUND. The Warden lands IN the ring; its protectors circle outside. Nothing to hide behind but four posts: fight in the open, keep moving. |
| II | 20 | **THE KENNEL** | green | three CAGES of green bars along the walls (NW, NE, SE), each with one gate onto the yard, each cell floor lit; two yard lamps | THE POUND. Hound packs. The cages are dead ends for you and doorways for them — hold the yard, never a cell. |
| III | 30 | **THE FIRING LINE** | cyan | two arcades of three pillars under beams make three long lanes; a gold FIRING STEP across the south end; a lamp at either end of the centre lane; a lit line down every lane; three cyan TARGET plaques on the far wall | THE RANGE. Protectors take the step and fire down the lanes. You are the targets — cross the lanes, never stand in one. |
| IV | 40 | **THE ALTAR** | purple | the three-tier dais; four purple CANDLE pylons at its corners; an ALTAR SCREEN behind it (two pillars, a beam, a lit reredos on the far wall); the frame inlay round it all | THE SACRIFICE. Two Wardens. The reavers take the high ground with you, and the dais is the only high ground there is. |
| V | 50 | **THE MAZE** | orange | five TALL walls you cannot see over make one loop round a walled inner room with a single door on its west; an orange thread on the floor leads from the entrance to that door; two lamps | THE LABYRINTH. The Warden drops in the far south-east corner, sprinters and hounds come round every blind corner, the frenzy at the halfway mark. Corners are the enemy. |
| VI | 60 | **THE GAUNTLET** | white | one lane between two TALL white walls with a baffle jutting in from each side (a slalom); a watchtower pillar off its east flank; six white runway lamps down the outsides; the start mark at its mouth; a raised FINISH step at the far end | THE RUN. Three Wardens come down at the finish. Run it. |
| VII | 70 | **THE THRONE** | red | a NAVE of four pillars under two beams up a red carpet to THE THRONE: two red tiers, a gold-armed seat, a tall back, a lit red banner on the wall behind, a brazier pylon either side; the summit capital roofs the centre at 192 | THE COURT. Four Wardens (the cap), every family, the whole trial a frenzy — and the first Warden lands ON the throne. The top is one flight up. |

## C. Contracts the generator now proves (all in the `SP_RM_LAYOUTS` assert)

- every solid feature wholly on the hall floor, out of the doorway's approach
  lane, ≥ 32 from every riser and respawn point, clear of both vendor
  triggers' rims (r + 8);
- the Warden drop ≥ 80 and the mark ≥ 40 from every solid feature that is not
  a dais / plat / throne (those are where they are MEANT to land; the emitted
  anchors lift onto the deck's top — `rmLift`, shared with the data emitter);
- walls of any kind (low / tall / fence) may meet; nothing else may overlap;
- **GALLERY CLEARANCE (new):** anything east of the core (x > CORE − PARA)
  must fit under the next lap's E flight and its inner rail at its own south
  edge (the lowest point above it) — a 240-tall fence at x 240 would have run
  into the first treads and nothing said so before;
- **THE LAST HALL'S CEILING (new):** hub 70's centre is roofed by the summit
  capital at 192 (`core capital`, generator 6d). Everything inside |x|,|y| <
  CORE there stops at 192; the throne's back was 240 until the preview tool
  showed it buried;
- fences are multiples of 32 (bars at 32 pitch, ≥ 64); lintels run pillar
  centre to pillar centre and never enter a cap; panels sit on the N or W
  face, never behind the PaP.

`tools/lint_tod_geometry.js` then walks the whole thing: the first cut left a
**6-node dead pocket** in the Gauntlet (18 units between the east wall, two
lamps and the pillar), fixed by moving the lamps to a 32 slot and the pillar
off the lamp column. The lint is the proof; the assert is the fence.

## D. What is NOT changed

- the fight per hall (`trial_recipe`), the ladder, the clock, the purse;
- the banners, the gauge, the hall lights (5 per hall, the hue);
- the drum's outer faces and the gold band (the tower still reads "gold ring
  every 10th" from outside);
- the porch, the hall gate, the risers, the respawn points, both vendors.

## E. Open

- **UNPLAYED.** Walk every hall in the harness (HARNESS.md, warp to a hub):
  the fence gaps must stop a player and a hound; the tall walls must not
  read as rails; the Warden must land on the ring / dais / throne tops.
- The navmesh lint runs inside the full build (one component per tower). If
  a tall-walled hall fragments the mesh, it will say so there.
- The kit has no per-hall LIGHT count. Five lights per hall was enough for a
  gold room; the navy Gauntlet floor may want a sixth. Look first.
