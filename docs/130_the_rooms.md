# 130 — THE ROOMS: room-scale trial halls (v18.80)

> **STATUS: FULL BUILD VERIFIED 2026-09-10 20:30:58 Eastern, FF 176,321,152 bytes; in-build hall bunker lint 0/7, geometry lint no regression, navmesh gate OK (both towers one walk); scripts/zone_source/ui diffs clean, nothing synced after the .ff, the compiled map md5-identical to the repo's. Harness #8 + dev flags still ARMED (test build). UNPLAYED.** User, after playing the first three v18.78 halls
> (2026-09-10): *"I can barely tell what unique changes you made that would
> improve players experiences and better uniquely design each trial?"* — and,
> asked how far to go: **all seven, room scale, with height.**

Plan views (from the EMITTED brushes): `docs/109_trial_halls/sheet.png`, one
`hall_<n>.png` per trial — `node tools/preview_trial_halls.js` after any edit.
Approach heatmaps: `node tools/lint_tod_hall_bunkers.js --png DIR`.

## A. Why the v18.78 halls read as one room

v17.86 gave each hall a set-piece and v18.78 gave each its own shell (vendor
walls, spawns, alcove) and closed every pocket. Both were real, and neither
was LAYOUT in the sense a player means: every hall was still the same
872-square drum with the same porch, the same galleries, the same floor, and
a cluster of furniture in the middle — four pillars, three pens, two arcades.
At eye level that is "some pillars in the same tinted room". Vendor walls and
riser positions are invisible as design.

What a player reads as a different room is the SHAPE OF THE SPACE: where the
floor is and is not, height, sight lines, and what the room makes you do —
climb, hold, run, navigate. So this pass gives every hall one room-scale idea,
with height wherever the drum allows it, and leaves the shell and the flow
(porch, seal, 70 s clock, recipes, mark, deal, door above) exactly as they were.

## B. Three new building blocks (generator, `SP_RM_LAYOUTS` vocabulary)

| kind | what it emits | why it is shaped that way |
|---|---|---|
| `['stage', x, y, half, h]` | a `half`-square top at `h` with a stepped skirt on all four sides: one 12-high, 32-wide tier per 12 of height | the horde climbs it from every direction and no edge is a drop, so `lint_tod_geometry` sees no unguarded edge and `lint_tod_hall_bunkers` sees four approach sectors |
| `['deck', x1, x2, y1, y2, h, E]` | a platform at `h`; every edge in `E` is `'stair'` (h/12 treads, 12 × 32, running out from the edge, with stepped side rails), `'rail'` (a parapet in the column beside the edge, floor to h + 56, clip-capped) or `'flush'` (on the drum's liner, asserted) | the rail is the geometry lint's guard AND, from the floor side, a wall the horde cannot climb — the platform becomes a firing parapet; stairs are the only way up, so the platform is a corridor with two ends (or one, which needs a riser on top) |
| `['seat', x, y, lift]` | the throne's seat alone (tier 2 + seat + arms + back) on a deck top at `lift` | THE THRONE's platform IS tier 1 now |

Two rules the pass paid for:

- **A raised top must be a SLAB.** `lint_tod_geometry` reads a top as floor
  only when the brush is ≤ `MAX_SLAB` (64) thick. The first cut emitted a
  72-high deck as one block: the lint saw a wall, reported every tread beside
  it as an unguarded edge and 410 detached nodes. Every deck top and tread is
  now a 16-thick DECK slab over a wall-material body (`topped()` in the
  emitter) — the tower's own landing recipe.
- **A stair's foot must land on open floor.** THE FIRING LINE's first cut ran
  its stairs wall to wall, so both feet met the drum: the line was an island
  (the same 410 nodes), and the bunker lint read each stair as a one-way
  pocket. The line is now 344 wide with 128 of open floor beside each foot.

And two more from the lints:

- A lamp in a 145-wide gap closes it for the sampler (36 foot + 14 body radius
  each side leaves 38, under one cell). THE GAUNTLET's yard lamp did exactly
  that and turned the yard into an arc-0 room. Lamps stand in the open now,
  and a yard with three walls gets a riser.
- `lint_tod_hall_bunkers` now scans every standable level to +140
  (`STAND_HI`), judging each cell at its own floor top, and counts risers at
  any level in that band — so a platform top is proven like the floor, and a
  riser ON a platform is what makes a one-stair platform legal. Selftest
  shapes moved onto open floor of the new rooms; 6 / 6.

## C. The seven rooms

| # | hall | the room (one idea) | height | Warden | approach |
|---|---|---|---|---|---|
| I | THE RING (gold) | THE STAGE — a 200-square fighting stage in the middle of the room, stepped skirt all round, four lamps at its corners | 48 | on the stage | from every side, up the skirt |
| II | THE KENNEL (green) | THE CAGE BLOCK — six barred pens in two rows with a central spine and cross corridors; the whole floor is kennels and the corridors between them; a riser inside every pen, two gates each | fences 128 | south yard, in front of the door | out of the cages into your corridor |
| III | THE FIRING LINE (cyan) | THE LINE — a 344-wide firing platform across the north wall behind a chest-high parapet, a stair at each end; the field below with an arcade of three pillars and two lit lanes; a riser ON the line | 48 (parapet 104 from the floor) | in the field | the two stairs, and the line itself |
| IV | THE ALTAR (purple) | THE HIGH ALTAR — a railed chancel 160 wide and 416 long across the middle of the room, a stair at each end, four candles at its corners, the screen behind | 48 (rails 104) | on the altar | both stairs |
| V | THE MAZE (orange) | THE LABYRINTH — two square rings of tall walls, each a pinwheel with openings at alternating corners; door to heart is two half-circuits of blind corners; the heart holds the mark and a riser | walls 160 | NW region | every corridor has two ends |
| VI | THE GAUNTLET (white) | THE RUN — three tall walls comb the room (up from the S wall, down from the N wall, one free in the east) so the way to the raised finish step in the NE is a serpentine; four runway lamps at the turns | walls 160, finish 12 | on the finish | the run, from behind |
| VII | THE THRONE (red) | THE COURT — a nave of four pillars to a railed throne platform 72 up across the north end, one grand stair from the west, the seat on top, braziers beside it; a riser on the platform | 72 (rails 128) | on the platform | the stair, and the court rising on the platform |

Shell per hall (unchanged in kind from v18.78, moved where a room needed it):

| # | PaP | crate | respawn | alcove |
|---|---|---|---|---|
| I | W | E wall, south end | NW | sealed |
| II | E wall, south end | W | NW | open (the seventh kennel) |
| III | E wall, south end | S flight's wall | SE (the N gallery is the line) | sealed |
| IV | E | W | NW | open (the crypt) |
| V | S flight's wall | W | N | sealed |
| VI | N | S flight's wall | NW | open (the pit) |
| VII | W | S flight's wall | NW | open (the dungeon) |

## D. Constraints that shaped the coordinates

- The E gallery: anything east of x 236 fits under the next lap's E flight,
  which is 176 above the floor at the hall's south edge and rises 12 per 32
  northward — tall walls (160 + 112 cap) east of 236 only from y 0 north.
- Hub 70's centre is roofed by the summit capital at 192, so THE THRONE's
  platform and its rails stand north of y 256 and its pillars are the 192
  kind.
- The porch's approach lane (x[−256,−80] y[−256,−96]) stays clear; the
  notch rail (x[−256,−236] up to y 84) is why nothing west of x −236 south of
  the NW region is walkable.
- Every corridor a Warden must walk is ≥ 80 wide (THE KENNEL's spine 80,
  its cross corridors 96, THE MAZE's rings 90–120). If a Warden still jams,
  widen — do not remove the riser that lets the room rise behind you.

## E. Gates that prove it

- `SP_RM_LAYOUTS` asserts (generator): every feature on hall-level floor, out
  of the approach lane, clear of risers / spawns / vendors, under the
  galleries and the capital; decks' edges valid, flush edges on the liner,
  seats wholly on a deck top at that deck's height; a riser on a deck top
  rides on it; a mark / Warden inside a deck's footprint must be on its top.
- `tools/lint_tod_hall_bunkers.js`: 0 bunkers in all seven halls (multi-level).
- `tools/lint_tod_geometry.js`: 0 misplaced walls, 0 unguarded edges,
  0 detached spire nodes.
- The navmesh gate inside the full build.

## F. Open — playtest checklist

- **UNPLAYED.** Warp hub to hub with the dev pads (harness #8): does each room
  read as a different SPACE from the porch? Does the stage / line / altar /
  platform feel like height, not a step?
- Wardens on the stairs and through the corridors: any jam is a width
  problem — widen the corridor, keep the riser.
- The horde on the platforms: the on-platform risers (THE FIRING LINE at
  (0, 392), THE THRONE at (−8, 320)) should rise behind anyone holding them.
- Vendors: every PaP faces into the room, every crate prompt works from the
  front (the v17.38 contract); THE THRONE's PaP moved to the W wall and its
  crest to the N wall's east half.
