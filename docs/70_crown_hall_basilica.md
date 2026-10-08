# 70 — THE CROWN HALL AS A BASILICA (v16.35, 2026-09-02)

User: *"look into a redesign enhancement of the interior of the crown room. Its
quite open and the spots where ammo crate and pap and alter are odd and not
intuitive. Can we do a redesign that makes it less open and organizes things a
bit and enhances the room."* Approval: *"just dont change the overall size or
outside of functionality. Other than that you have the freedom to improve for
players experience and awesome design."*

Proposal page (before/after plans at 1 px = 4 u, a section, the options
rejected): artifact **"Crown Hall Basilica"**
<https://claude.ai/code/artifact/b2a5c700-6912-49c8-b59d-f5c6885e95f5>.
Renders after the build: `docs/crown_v16b_hall*.png` (`node
tools/preview_crown.js --filter "^(crown (hall|wall|gate|cornice)|uplink
dais|extraction pad)" --out docs/crown_v16b_hall`).

## 1. What the room was — measured from the .map

Inside 576-unit velvet walls, a 1456 × 1456 floor holding: four 176-tall
pillars at the quarter points, a 16-unit dais at the centre, the extraction pad
at the north end, and a 1u glowing ring at ±632. The three vendors sat on three
different walls with nothing framing them: the Pack-a-Punch on the SOUTH wall
beside the gate facing north (behind a player who has just run in), the altar
alone on the west wall, the crate alone on the east wall. The ring's west band
ran under the altar's trigger origin — the crown-altar bug fixed in v16.27.

## 2. What it is now — the plan in one line

**Gate → nave → crossing → sanctuary.** All coordinates in the generator's odd
frame (north = +y, HYC = 8608, TOP2 = 19392).

| element | where | size | material class |
|---|---|---|---|
| pier lines | x ±384; y 7976 / 8200 / 8424 · 8792 / 9016 / 9240 | base 112 sq × 24, shaft 80 sq to +176, capital 104 sq +176..+216 | gold / ruby / gold |
| beam | along each pier line, segments BETWEEN capitals | 48 wide, +176..+216 | plain gold |
| nave / aisles | nave 768 wide; aisles 304 clear (pier face 424 → wall 728) | gaps between bases 112 | — |
| west shrine | HEAVENLY GIFT ALTAR at (−664, 8608) yaw 90 | pilasters 32 sq at y 8464 / 8720 to +216, panel 4 proud +32..+216, canopy wall→424 at +216..+248 | gold / glow / gold |
| east shrine | PACK-A-PUNCH prefab at (664, 8608) yaw 270 (faces west) | same bay, mirrored | — |
| crate | (676, 8308) yaw 270 — unchanged | + low glow panel +24..+120 behind it | glow |
| sanctuary | tier 1 x ±320, y 8952..9336, +16; tier 2 x ±280, y 8992..9336, +32 | every step 16 | gold panel (walkable) |
| pad | (0, 9112), 160 sq, top **+40** | `exfil_org()` now returns z 19432 | green edge |
| reredos | north wall, x ±280, +32..+352; frame 8 proud; ruby stone ±64 × +112..+272, 16 proud; crest ±128 to +416; monde ±32 to +488 | under the cornice (+512) | brass / gold / ruby |
| carpet seams | nave seams at x ±300 (24 wide) from y 7984 to 8928; threshold bar 7960..7984; sanctuary-foot bar 8928..8952; dais rim 136..160; transept seams y 8608 from 160 to 600 (split at the nave seams); crate spoke y 8308 from 312 to 600 | all 1u walk-over | glow |

Unchanged on purpose: floor, walls, corner posts, gate, door, cornice, the
dais, `hall_center`, the 160 gather ring, the four corner risers, the hound
spawner, `in_hall` / `in_crown`, `gate_org`, `crown_door_org`.

Anchors that moved (all in generated `_tod_crown_data.gsc`): `station_org` /
`station_trig_org` y 8308 → 8608; `exfil_org` z +8 → +40 (`PAD_TOP`, one
constant with the pad brush); `siege_panzer_org` (280, 8850) → (192, 8860);
`hall_pillar_orgs` → the four crossing piers at +232; `sconce_orgs` re-pitched
to y 8048 / 8236 / 8420 / 8796 / 8980 / 9168 (twelve kept, ascending, so the
acceptance ignition still walks gate → pad). Lights: the four quarter lights
stay at +260; three added — two under the shrine canopies at +160 and a
reredos wash at (0, 9240, +300).

## 3. Why these numbers

* **Pier line at ±384, not ±448.** ±448 gives a 896 nave but 240-wide aisles
  — too mean to hold a 104-wide machine, its 64 standoff and a walkway. ±384
  gives 768 / 304, a classic ~2.5 : 1 nave-to-aisle, and the shrines still
  read from the door.
* **Pitch 224, six a side, the crossing gap 368 c-c.** 144 clear between
  shafts keeps the colonnade a loop, not a wall; the 288-clear crossing gap
  frames each shrine bay (224) with 32 to spare either side.
* **Nothing above +248 except the reredos.** The wall is 576 and the crown is
  the reason the room exists; the hall must stay open to the sky. The reredos
  stands against the far wall where it closes the axis instead of the sky.
* **Every level change is 16.** STEP_MAX is 18 for the geometry lint and for
  the engine's walk, so zombies climb the sanctuary and no edge needs a rail.
* **Sanctuary 640 / 560 wide, inside the 768 nave.** Tier 1 stops at x 320
  because the nearest pier bases start at 328 — no overlapping solids anywhere
  in the hall (the post-regen check counts 80 pieces, 0 overlapping pairs).
* **Overhead pieces are PLAIN gold.** The lint classes a ≤64-thick tinted
  brush as a DECK. The first regen's 40-tall ruby monde came back as a floor
  at +456 with six unguarded edges and four unreachable nodes; at 72 tall it
  is a solid again. Same rule for beams, capitals and canopies.
* **Vendor triggers float (v16.27),** so the seams can run under a machine's
  approach without killing its prompt — the exact failure the old ring caused.

## 4. Options rejected

* **A · frame only** — panels and canopies around the three machines where
  they stood. Fixes the look, not the plan: the PaP stays behind the door.
* **C · perimeter gallery** — a raised walkway round all four walls with the
  machines in alcoves. Most enclosed, but it hands the party high ground on
  every side of a hold-out that is meant to feel exposed, and it moves the
  risers.
* **D · entrance screen** — wing walls inside the gate for a staged reveal.
  The party arrives at a sprint with the horde behind them and the door seals
  behind the last one in; a choke there is a trap.

## 5. Contracts checked before the build

Post-regen script (scratch `hall_check.js`, the same axis-aligned parse as the
geometry lint): altar trigger origin (+32), altar and PaP model origins, the
crate trigger (+40, inside its own clip body as always), `exfil_org` (on the
pad), the four count-in hosts and every hall light — none inside a solid.
Standing room (nothing solid from +2 to +70 in a 32-square column) at all four
gather seats, the Panzer mark, both far risers, the hound spawner, the three
machine approaches, the pad, the sanctuary step, the gate axis, an aisle bay
and a nave-to-aisle gap — all open. Lit area: the hall went 34.1 → 37.7M u²
(+0.25 % of the map). Geometry lint: 0 misplaced walls, 0 unguarded edges,
0 detached nodes, base → terrace and terrace → citadel walkable, parity check
OK at both crown parities. Hint and arity lints unchanged.

## 6. What to test at the crown

1. The count-in on entry — the four CROSSING piers burn red per living player
   and turn green as each arrives.
2. The seal and gather — four seats round the dais, on open floor.
3. The Panzer drop on the new mark, north-east of the dais in the nave.
4. Both machines buy under their canopies: altar west, Pack-a-Punch east.
5. Extraction on the raised pad: prompt, purchase, the green pad light on top
   of the sanctuary.
6. ASCEND on the dais after the win (the teleporter stands where it always did).
7. Walk the aisles and the sanctuary steps: no invisible walls, no snags on the
   pier bases, zombies path through the colonnade gaps and up the steps.
