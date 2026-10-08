# 128 — THE OPEN HALLS: one shell per trial, no cubby anywhere (v18.78)

> **v18.80 (2026-09-10): THE ROOMS.** The first play of these halls found them
> still reading as one room; the rooms were rebuilt at room scale with height
> (`docs/130_the_rooms.md`). The rule, the lint and the shell-per-hall contract
> below all still hold; the lint now scans every standable level, not just the
> hall floor.

> **STATUS: BUILT 2026-09-10, UNPLAYED.** User: *"One issue im seeing with the
> endless spire is that the layout of each trial is the same. Everyone just
> bunker up in the little cubby and withstands the trial. I dont want that to be
> allowed. So that means we need to really think about redesign each layer to be
> different not just in content but in layout too where thats possible. May
> require moving ammo and pap on each layer."* And, mid-work: *"we have freedom
> to layouts but lets not break the player flow, experience, or anything like
> that."*

Plan views (from the EMITTED brushes): `docs/109_trial_halls/sheet.png`, one
`hall_<n>.png` per trial — `node tools/preview_trial_halls.js` after any edit.
Approach-arc heatmaps: `node tools/lint_tod_hall_bunkers.js --png DIR`.

## A. What was actually the same

v17.86 gave every hall its own set-piece (docs/109), and the halls still
played as one room, because the SHELL around the set-piece was identical in
all seven and the shell had the only two spots that mattered:

| pocket | where (hall-local, N up, entrance SW) | why it was a bunker |
|---|---|---|
| **THE PORCH POCKET** | x[-256,-160] y[-236,-96], the sunken fan behind the gate | gate west (sealed for the trial), porch wall north, the S flight's inner wall south: one 140-wide mouth facing east, and the nearest riser ~300u away. Every party enters through it and the gate shuts behind them — so they simply stopped walking. |
| **THE SE ALCOVE** | x[256,436] y[-436,-256], under the SE landing (roof at 176) | three walls and one 180-wide mouth facing north — and it was OUTSIDE `trial_box` (the box's south edge was -256), so no riser was eligible in it, no elite could land in it, and a player standing in it did not even count as "in the hall". The safest 180×180 in the spire, by construction, in all seven halls. |

The v17.86 set-pieces then added their own: THE KENNEL's cages had one 64-wide
gate each, THE MAZE's inner room one 100-wide door, THE GAUNTLET's baffled lane
a walled finish. Seven halls, one answer: stand in the cubby, face the mouth.

## B. The rule, and the proof that it holds

**A bunker is a spot enemies can reach from ONE narrow direction where nothing
ever rises behind you.** `tools/lint_tod_hall_bunkers.js` proves there is none,
per hall, from the emitted `.map` — it runs on every full build beside the
geometry lint, and the number is zero (no baseline).

- Every 20u cell a body can stand on at hall level (steps ≤ 13 count as
  floor; anything solid between knee and head is a blocker, the SEALED gate
  included) casts 72 rays over standable floor. The **open arc** is the
  angular width from which a walker can reach the cell across 160u. A plain
  room corner reads ~90–95°; the porch pocket read 63°, a caged pen ~25°.
- Open rays are grouped into **approach sectors** (runs separated by ≥ 30° of
  closed rays). A corridor has two, a room with doors on several sides has
  several, a cubby has ONE. Only one-sector cells with arc < 80° count.
- Those cells cluster into **pockets**. A pocket is a BUNKER unless a riser
  sits INSIDE it (within 40u of one of its cells) — see D for why a riser
  inside is what makes a pocket untenable. A riser at the MOUTH does not
  count: it feeds the funnel.

Before this pass the first (arc-only) run found 6 / 7 / 11 / 5 / 6 / 7 / 9
pockets in halls I..VII; the porch pocket and the SE alcove were in every
list. After it: **0 bunkers in every hall**, geometry lint clean, navmesh gate
to come with the build.

`tools/lint_tod_hall_bunkers_selftest.js` breaks the map five ways (porch
risers removed, alcove seal removed, a U-shaped wall injected, the same U with
a riser inside — must PASS, a two-ended corridor injected — must PASS) and
requires the right verdict on each.

## C. One shell per hall

Every `SP_RM_LAYOUTS` row (generator) now owns its shell as well as its room:

| # | hall | PaP | crate | respawn | SE alcove | risers | the room (changes from v17.86) |
|---|---|---|---|---|---|---|---|
| I | THE RING (gold) | W wall | E wall | N gallery | **sealed** | 14 | the four pillars moved in off the walls (they had made a 120 slot against the N wall and a dead corner by the flight rail); the step between them |
| II | THE KENNEL (green) | E wall, south | W wall | NW region | **open — the kennel** (riser inside) | 14 | three pens rebuilt as ISLANDS in the yard, each with TWO gates and a riser inside: the horde comes OUT of the kennels |
| III | THE FIRING LINE (cyan) | E wall, south end | S flight's wall | N gallery | sealed | 12 | two arcades of TWO pillars each running EAST-WEST, so the lanes look straight down at the porch; the firing step at the east end; targets on the NW wall |
| IV | THE ALTAR (purple) | E wall | W wall | NW region | **open — the crypt** | 13 | the dais one step south, the altar screen 160 off the N wall, candles beside the dais |
| V | THE MAZE (orange) | S flight's wall | E wall | N gallery | sealed | 12 | four tall walls as a PINWHEEL round a 200-square heart: every corner of the room is a 100-wide opening (no door), and the heart has a riser — the labyrinth breathes |
| VI | THE GAUNTLET (white) | N wall | S flight's wall | NW region | **open — the pit** | 12 | four free-standing baffles as a slalom (the fifth had walled the finish into a cubby), four runway lamps, the finish step in the open |
| VII | THE THRONE (red) | N wall | S flight's wall | NW region | **open — the dungeon** | 12 | the nave 60 further east (its west column made a north-facing slot against the flight rail), braziers behind the throne |

Shell rules the generator now asserts for every layout: vendors on hall-level
floor with their triggers ≥ 200 apart and off the approach lane; the three
porch risers present (two on the fan's hall-level rows — back and mouth — and
one in THE DOORWAY'S CORNER, where the porch wall meets the flight rail: a
160-deep L that turned anything a layout put on the west side into a
north-facing slot in five of seven halls); an open alcove has a riser inside
it and a sealed one has none; every riser and respawn on hall-level floor,
clear of vendor bodies, risers ≥ 64 from respawns; no feature, sigil, mark or
warden inside a sealed alcove; no plaque behind a vendor on its wall; anything
under the SE landing stays under 176.

The generated `_tod_spire_data.gsc` carries the vendors PER HUB
(`hub_pap_org( hub, z )` etc., switch by layout index) and `trial_box` now
reaches the alcove: its south edge is the drum, with the S lane + SW landing
cut out as exclusion 3. `_tod_spire::spawn_hub_vendors` passes the hub.

> **First-play fix (2026-09-10, v18.79b).** Reaching the alcove also reached the
> SE LANDING 192 above it — lap n+1's start landing, OUTSIDE the seal (up the S
> flight, behind door n+1), with a riser at (336, -336). Zombies rose there
> stranded ("spawning outside the trial") and elites placed there by
> `pick_spawn_point` stood frozen with no route in. Exclusion 4 cuts x > 236,
> y < -246, z > +100 back out; the alcove floor stays in. Every box consumer
> inherits it through `in_box`.

## D. The horde rises where you stand

`_tod_endless_rounds::finale_spawn_selection`, inside a sealed hall: for
`TOD_TRIAL_NEAR_PCT` (70) of spawns a random UPRIGHT player is rolled and the
riser comes from the `TOD_TRIAL_NEAR_K` (3) nearest to THEM
(`trial_near_spots`); the rest stay uniform so the room keeps filling. Combined
with C — a riser inside every pocket — hiding is what draws the rise behind
you. Re-rolled per spawn, like the finale's focus; last stand is excluded (a
crawler must not draw the hall onto the teammate reviving them). 100 / 1 would
be pure spawn-on-the-player; 0 is the old uniform hall.

## E. What did NOT change (the flow)

The entrance (the porch, the W flight's top five treads), the gate and the
seal (everyone in → 2 s tell → sealed), the 70 s clock, the seven recipes
(which families, how many Wardens, when the frenzy), the ladder, the purse,
the Max Ammo on the mark, the card deal, the door above unsealing, the
banners, the gauge, the hall lights and the seven colour kits. The Warden
drop points moved where a layout moved (the drop adapts to clear air above,
`TOD_DROP_H_MAX`, so a drop under the E flight or the alcove roof is a
shorter fall, not a broken one).

## F. Open — playtest checklist

- **UNPLAYED.** Warp to hubs (HARNESS.md) and try to hold each of the old
  spots: the porch behind the gate, the SE alcove where it is open, a Kennel
  pen, the Maze's heart. The horde should rise ON you within seconds.
- Vendors: every PaP faces INTO the hall (W → east, N → south, E → west,
  S → north; the ALXS cabinet's front is yaw − 90) and every crate prompt
  works from the front (the v17.38 contract).
- Respawn in the NW region (Kennel, Altar, Gauntlet, Throne): a mid-trial
  death should come back inside the sealed hall, on the floor, facing the
  room.
- The lint models geometry, not feel: a 2-sector slot 100 wide is legal. If a
  spot still plays as a bunker, add a riser or open a side — never lower the
  threshold.
