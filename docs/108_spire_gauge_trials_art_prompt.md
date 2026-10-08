# 108 — THE SPIRE GAUGE LOST ITS TRIAL LANDMARKS: put the hub plates back (art pack)

<!-- art-pack
name: spire_gauge_trials
refs:
  docs/108_spire_gauge_ref/COMPARE_onscreen.png | THE BRIEF IN ONE PICTURE. Four columns at the REAL on-screen size (52x416), magnified 2x: the old gauge unlit + lit, then the shipped gauge unlit + lit. The trial plates used to be countable; now they are not. Attach to EVERY prompt.
  docs/108_spire_gauge_ref/ZOOM_cells_1to1.png | The same two lit masters cropped 1:1 around a trial plate. Shows the geometry that changed: slim rungs + a wide chamfered gold slab, versus fat rungs + a flat gold divider. Attach to EVERY prompt.
  docs/108_spire_gauge_ref/spire_lit_v1_liked.png | THE OLD LIT MASTER (180x1440, 50 cells at pitch 21). Retired for a grid reason only. Its LAMP-TO-PLATE PROPORTIONS are the target: slim red rungs, generous dark gaps, gold hub slabs with arrow wings that reach the rails. Attach to the lit prompt.
  docs/108_spire_gauge_ref/spire_dark_v1_liked.png | THE OLD UNLIT MASTER. Its unlit hub plates are readable before anything lights - that is the contrast to beat. Attach to the dark prompt.
  docs/108_spire_gauge_ref/spire_lit_shipped.png | THE SHIPPING LIT MASTER (180x1440, 35 cells at pitch 30). The grid, palette, summit, neck and base to KEEP exactly. Only the cell shapes are wrong. Attach to every prompt.
  docs/108_spire_gauge_ref/spire_dark_shipped.png | THE SHIPPING UNLIT MASTER. Same: keep everything but the cell shapes. Attach to the dark prompt.
  docs/108_spire_gauge_ref/spire_down_shipped.png | THE SHIPPING DOWN MASTER (every cell white with a red cross). Re-cut to the new cell shapes. Attach to the down prompt.
  docs/108_spire_gauge_ref/spire_won_shipped.png | THE SHIPPING WON MASTER (the lit master with a green beacon). Re-cut to the new cell shapes. Attach to the won prompt.
preview: 52x416
-->

> **STATUS: SHIPPED v17.89 (drop `files - 2026-09-05T172258.455.zip`, 2026-09-05 17:22 — the loose and nested copies are pixel-identical). Every slicer check green at the DEFAULT band tolerance (no `--band-tol`): registration 0 px, cut rows 0 px, neck 0 px, every hub cell distinct. Delivered trial slab 140 × 24 vs floor lamp 96 × 16 (1.46× / 1.50×), unlit trial plate 2.2× an unlit floor plate — the three asks met. Cut with `slice_gauge.js --spire --write`; FULL build; UNPLAYED.**
>
> **(Original) STATUS: COMMISSIONED 2026-09-05 (v17.82).** User: *"I feel like our endless
> spire progress indicator got degraded. In the old version the trials were
> clearly visible by the image so you know how close you were. I believe they
> had different widths as a huge indicator. Look at the old one and compare."*
> Pack built by `.\tools\make_art_pack.ps1 docs\108_spire_gauge_trials_art_prompt.md`
> → `~/Downloads/tod_spire_gauge_trials_art_pack.zip`.
>
> **Nothing in the game changes until the drop comes back.** No code, no zone,
> no GDT edit: the grid is already 35 cells at pitch 30 and the four masters
> are cut by `tools/slice_gauge.js --spire`, so this is an art swap only.

## A. WHAT ACTUALLY REGRESSED (measured, not guessed)

The v17.69 re-grid from 50 cells at pitch 21 to **35 cells at pitch 30** was
correct — 70 floors, two per cell. What went with it was the *proportion*
between a floor lamp and a trial plate. Measured off the two lit masters at
luminance > 140:

| | floor lamp | trial (hub) plate | ratio |
|---|---|---|---|
| **old (50 @ 21)** | 119 px wide, ~15 px of lit body in a 21-px band | 139 px wide, ~17 px body | 1.17 × wider |
| **shipped (35 @ 30)** | 109 px wide, but the body now fills ~22 of its 30-px band | 136 px wide, ~26 px body | 1.25 × wider |

On paper the shipped hub plate is *more* distinct. On screen it is less,
because the two changes cancelled: **the floor lamps grew into fat blocks**
while **the hub plate got flatter**. At the gauge's real on-screen size —
**52 × 416 px**, so one cell is **8.7 px tall at 720p** — the column reads as
a solid stack of red blocks with a thin yellow line between groups. The gold
stopped being *a different kind of thing* and became *a divider*.

The unlit master has the same problem for a different reason: an unlit hub
plate averages **43** luminance against **34** for an unlit floor plate — a
1.28× difference that survives being shrunk to 8.7 px only barely. You cannot
count the seven trials on a fresh spire, so you cannot see how far the next
one is, which is the whole job of the instrument.

## B. WHAT TO ASK FOR

Restore the OLD relationship at the NEW pitch — do not go back to the old
grid. Three asks, all measurable:

1. **Slim the floor lamps back down** so the column is a ladder of rungs with
   real dark gaps, not a stack of blocks.
2. **Fatten and widen the trial plates** until they break the column's
   silhouette — wings touching both rails, the way the old master did.
3. **Make the unlit trial plates readable** so a player at floor 12 can see
   where floor 20 is.

## C. INSTALL WHEN THE DROP COMES BACK

1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'` — LOOK at all five
   files, then overlay each master on its shipped counterpart.
2. Put the four masters in one folder, `node tools/slice_gauge.js <folder>
   --spire` (dry run, every check green — including the band-line rule and
   the per-cell registration), then `--write`.
3. **If the band-line check fails, do not reach for `--band-tol`.** The v17.70
   delivery needed a 140 override because it drew plates edge-to-edge with no
   dark margin; this brief asks for a ≥ 7-px margin precisely so the default
   passes. A failure here means the plates are crossing cut lines and will
   show hard edges in game.
4. Re-run the on-screen comparison (crop each master to 52 × 416 and put the
   old, the shipped and the new side by side) before believing it is better.
5. FULL build; proof = fresh content-hash `.iwi` beside an untouched control.
6. Flip this STATUS to SHIPPED with the build version.

<!-- PACK:BEGIN -->
# TOWER OF DOOM: CYBERCITY — THE SPIRE GAUGE: PUT THE TRIAL LANDMARKS BACK (4 masters + 1 review sheet)

You are the art director and image generator for the HUD of **Tower of Doom:
Cybercity**, a Call of Duty: Black Ops III custom zombies map.

You have already delivered this instrument twice. It is the **ENDLESS SPIRE
GAUGE** — a tall thin bar pinned to the right edge of the screen that shows
how high the player has climbed a 70-floor tower. It is **35 cells**, two
floors each, and **every 5th cell is a TRIAL floor**: a boss hold-out the
player has to survive. There are **seven trials**, on cells 5, 10, 15, 20,
25, 30 and 35.

**The second delivery lost the trials.** They are still gold, but they no
longer read as landmarks. This job fixes exactly that and changes nothing
else.

**Open `reference/` first.** `COMPARE_onscreen.png` and `ZOOM_cells_1to1.png`
are the whole brief in two pictures — attach both to every generation.

### What to attach to what

| file | attach to |
|---|---|
| `COMPARE_onscreen.png` | every generation |
| `ZOOM_cells_1to1.png` | every generation |
| `spire_lit_shipped.png` | every generation — the frame, palette, summit, neck and base to keep |
| `spire_dark_shipped.png` | `spire_dark.png` and `spire_down.png` |
| `spire_lit_v1_liked.png` | `spire_lit.png` — the older version, for the lamp-to-plate proportions only |
| `spire_dark_v1_liked.png` | `spire_dark.png` — the unlit contrast to beat |
| `spire_down_shipped.png` | `spire_down.png` — the white-and-cross treatment to keep |
| `spire_won_shipped.png` | `spire_won.png` — the green beacon to keep |

---

## THE PROBLEM, IN NUMBERS

The gauge is drawn on screen at **52 × 416 pixels**. The masters are
180 × 1440, so everything you draw is seen at **29% of its size**. One cell is
**8.7 screen pixels tall**. At that size only two things survive: how WIDE a
shape is, and how BRIGHT it is.

Between the two deliveries:

| | floor lamp | trial plate |
|---|---|---|
| **older version (worked)** | 119 px wide, slim body, big dark gaps | 139 px wide, wings out to the rails |
| **current version (does not)** | 109 px wide, body fattened to fill its cell | 136 px wide, but flattened |

The floor lamps grew and the trial plates flattened, so at 52 px wide the gold
now looks like a thin divider line squeezed between fat red blocks — see
`COMPARE_onscreen.png`, columns 2 and 4. In the older version the gold was
obviously a **different kind of object**. That is what has to come back.

Same story unlit: an unlit trial plate is only **1.28× brighter** than an
unlit floor plate, so a player cannot count the seven trials ahead of them.

---

## WHAT STAYS PIXEL-IDENTICAL

Canvas **180 × 1440**, PNG-32, transparent outside the bar. Copy these
regions from `spire_lit_shipped.png` / `spire_dark_shipped.png` exactly:

- **SUMMIT, y 0 – 270** — the gold deck, the three-tier mast, the beacon.
- **NECK, y 270 – 290** — must be byte-identical in all four masters.
- **BASE CAP, y 1340 – 1440** — the crimson plaza plate and its red ring.
- The outer frame, the red keyline and glow, the gold circuit tracery, the
  side rails, and the palette: red `#FF4D4D`, gold `#FFD959`, crimson plate.

**The grid does not change:** 35 cells of exactly 30 px between y 290 and
y 1340. Cell *f* (counted from the bottom, f = 1..35) spans
**y = 290 + (35 − f) × 30** to that + 30.

## WHAT CHANGES — the three fixes

### 1. Slim the floor lamps
A floor lamp (the 28 non-trial cells) is a rounded neon bar:

- **width 104 px**, centred (it was 109 and looked fatter because of its
  height)
- **body height 16 px** inside its 30-px cell — leaving **7 px of dark plate
  above and 7 px below**
- the column should read as a **ladder of separate rungs**, the way the older
  version did. Look at `ZOOM_cells_1to1.png`, left half.

### 2. Make the trial plates unmistakable
A trial plate (cells 5, 10, 15, 20, 25, 30, 35) is a wide chamfered slab:

- **width 152 px** — its pointed **wings must touch both side rails**, so the
  bar's silhouette visibly notches outward at every trial
- **body height 24 px** of its 30-px cell (3 px clear above and below)
- the flattened hexagon / arrow-wing shape from the older master, with the
  small **tick marks on the rails** either side
- result: a trial plate is **≥ 1.45× the width and ≥ 1.5× the height** of a
  floor lamp. Both, not one.

### 3. Make the UNLIT trial plates countable
In the dark master the seven trial plates must be the brightest thing in the
column — aim for **at least twice** the mean brightness of an unlit floor
plate (it is 1.28× today). A dim gold slab against near-black floor plates.
A player on floor 12 should be able to glance at the bar and see that the
next trial is four rungs up.

Do NOT put numerals, glyphs or text in any cell. At 8.7 screen pixels they
turn to mush. Shape, width and brightness are the whole vocabulary.

---

## DELIVERABLES (exact filenames, all 180 × 1440 PNG-32)

| # | file | what it is |
|---|---|---|
| 1 | `spire_dark.png` | UNLIT master: 35 empty plates — 28 slim floor plates, 7 wide trial plates, the trial plates clearly readable. Summit dim, beacon dark, base dim. |
| 2 | `spire_lit.png` | FULLY LIT master: 28 red floor lamps `#FF4D4D`, 7 gold trial slabs `#FFD959`, summit lit, beacon burning red, base ring lit. |
| 3 | `spire_down.png` | DOWN master: all 35 cells white with the red cross, on the same new plate shapes. Summit and base as in the dark master. |
| 4 | `spire_won.png` | the LIT master with **only** the beacon and its halo changed to green `#4DFF88`. Nothing else differs from `spire_lit.png`. |
| 5 | `spire_kit_preview.png` | review sheet, any size (see below). |

### The four masters must be PIXEL-REGISTERED
Identical alpha silhouette, identical frame, identical everything except the
lamp states. Overlay them — nothing may shift by one pixel. The game stamps
strips cut from one master on top of another, so a shift shows as a seam.

### THE CUT-LINE RULE — the one that breaks the build
The game slices these masters on the rows **y = 290 + 30 × k** for k = 0..35.
Those 36 rows must be **identical in all four masters** and must fall on
plain plate — **no lamp, plate, glow or bloom may cross one**. That is why the
floor lamp gets 7 px of margin and the trial plate 3 px: keep every glow
inside its own 30-px band, including the soft bloom.

The neck (y 270–290) and the rows either side of it are also cut lines. Keep
them identical.

---

## REVIEW SHEET — `spire_kit_preview.png`

One image showing, side by side and clearly labelled:

1. the new `spire_dark.png` and `spire_lit.png` at **full size**;
2. the same two **downscaled to 52 × 416** — the real on-screen size — beside
   the attached `spire_lit_shipped.png` downscaled the same way, so the
   improvement is visible at the size that matters;
3. a 1:1 crop of five cells around a trial plate, so the proportions can be
   checked against `ZOOM_cells_1to1.png`.

**Judge your own work on the 52 × 416 version.** If you cannot count seven
trial plates in the small unlit strip at a glance, it is not done.

---

## DELIVERY CHECKLIST

- [ ] 4 masters, each exactly 180 × 1440, PNG-32, transparent background
- [ ] summit (0–270), neck (270–290) and base (1340–1440) pixel-identical to
      the attached shipped masters
- [ ] 35 cells at exactly 30 px pitch — count them
- [ ] trial plates on cells 5, 10, 15, 20, 25, 30, 35 counted **from the
      bottom** — seven of them
- [ ] floor lamp ≈ 104 × 16 px; trial plate ≈ 152 × 24 px; wings touch the
      rails
- [ ] no lamp, plate or glow crosses y = 290 + 30k
- [ ] unlit trial plates at least twice as bright as unlit floor plates
- [ ] all four masters overlay with no shift
- [ ] `spire_won.png` differs from `spire_lit.png` only at the beacon
- [ ] review sheet includes the 52 × 416 comparison

## DO NOT

- Do not change the grid — it is 35 cells at pitch 30, not 50 at 21.
- Do not redraw the summit, the mast, the beacon, the neck or the base.
- Do not change the palette or add new colours.
- Do not add numerals, letters, icons or glyphs to any cell.
- Do not add outer glow that spills past the bar's silhouette.
- Do not deliver JPEG, or PNG without an alpha channel.
- Do not rename the files.
<!-- PACK:END -->
