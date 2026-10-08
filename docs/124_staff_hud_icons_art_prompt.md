<!-- art-pack
name: staff_hud_icons
refs:
  docs/124_hud_ref/staff_style_gap.png | THE WHOLE BRIEF IN ONE PICTURE. The 28 shipped weapon icons at true on-screen size on both a dark and a light background, the three staff cells beside their nearest neighbours, the measured numbers, the exact palette. Attach to every prompt and read it top to bottom before drawing anything.
  docs/124_hud_ref/art_direction_board.png | The house art direction for this HUD - palette, the six rules, good and bad examples. Unchanged and still governs. Attach to every prompt.
  docs/124_hud_ref/i_tod_hud_gun_sheet3.png | THE SHIPPED SHEET, 28 weapon icons at 288x132 each. This is the set the three new cells must be indistinguishable from in treatment. The style you keep. NOT a deliverable.
  i_tod_hud_gun_katana.png | Nearest neighbour: one long object laid diagonally across the cell. The closest thing in the set to a staff, and the stroke weight to match.
  i_tod_hud_gun_axe.png | Nearest neighbour, ornate. Shows how much internal detail survives at this size, and how FAT a long object is drawn.
  i_tod_hud_gun_blade.png | The third melee cell, for breadth of the diagonal-object treatment.
  i_tod_hud_gun_staff1.png | The CURRENT lightning staff, being replaced. Keep its SUBJECT (the head), replace its treatment.
  i_tod_hud_gun_staff2.png | The CURRENT fire staff, being replaced.
  i_tod_hud_gun_staff3.png | The CURRENT ice staff, being replaced.
preview: 144x66
-->

# 124 — MAGE STAFFS: the three weapon HUD icons, re-drawn into the house style

> **STATUS: SHIPPED v18.58 (2026-09-09).** The drop came back within ten
> minutes (`files - 2026-09-09T030612.703.zip`) as ONE sheet at exactly
> 864 × 132 — plus the three cells already cut, byte-identical to the sheet's
> own slices (0 differing pixels), so there was no ambiguity about which to
> install. Every acceptance number below is met. Installed per "Install".
>
> **The acceptance test, measured on the shipped cells:**
>
> | | before | after | the 28 guns |
> |---|---|---|---|
> | bright saturated pixels | 14.4 / 11.9 / 12.5 % | **0.64 / 0.60 / 0.55 %** | 0.2 % mean (blade 0.6, katana 0.5) |
> | tones ≥2% of ink | 5 / 5 / 5 | **3 / 3 / 3** | 3, every cell |
> | ink coverage | 17.2 / 18.7 / 16.1 % | **32.3 / 33.6 / 29.8 %** | 36.1 % mean |
> | palette | 7 colours incl. gems | **`#E8EEF6` `#62779C` `#0A1020`** | the same three |
>
> The three staffs now sit inside the set's own range on all three axes rather
> than outside it on all three. Margins 16 px left, 10–27 right, 7–20 top,
> 9 bottom — nothing near a cell edge.
>
> ⚠️ `docs/124_hud_ref/staff_style_gap.png` is the **BEFORE** record and is
> deliberately not regenerated. `tools/gen_staffhud_ref.js` reads
> `_images/`, so re-running it now measures the NEW cells and overwrites the
> board that made the case for changing them.

## Why (user, 2026-09-09)

*"We need gun HUD icons for the three new staffs we just created. Can you create
a zip for me with examples and I'll get the assets. Make sure they are consistent
with existing gun icons."*

## The three cells already exist — this is a re-bake, not a new lane

`i_tod_hud_gun_staff1|2|3` shipped v18.43 (2026-09-08) as part of the docs/120
mage drop. They are wired: GDT blocks, `image,` lines in the zone, and the three
`TOD_GUN_CAT` rows in `AetheriumLoadout.lua` keyed on the element stems
(`tod_staff_lightning` → `staff1`, `_fire` → `staff2`, `_ice` → `staff3`).
**Same names back means zero wiring** — copy in, full build, done.

## What is actually wrong with them

They were drawn in a pass of 25 upgrade **cards**, not beside the 28 weapon
icons they share a HUD corner with, and the gap is measurable rather than a
matter of taste. Measured off the shipped PNGs by `tools/gen_staffhud_ref.js`:

| | staff1 / staff2 / staff3 | the 28 guns |
|---|---|---|
| bright saturated pixels, as a share of ink | **14.4 / 11.9 / 12.5 %** | **0.2 %** (mean; and that little comes from the blue-black outline itself) |
| tones carrying ≥2% of the ink | **5 / 5 / 5** | **3.0** — every single cell |
| ink coverage of the 288×132 cell | **17.2 / 18.7 / 16.1 %** | **36.1 %** mean |

Three separate breaks, in order of how much they matter:

1. **The coloured gems.** Nothing in the shipped set carries a saturated colour.
   Rule 4 of the art-direction board is explicit — *no orange, no red* — and the
   fire stone is `#FF7828`. This is the single biggest thing setting the three
   cells apart from their neighbours.
2. **Five tones instead of three.** The set is `#E8EEF6` / `#62779C` / `#0A1020`
   and nothing else. The staffs add gem colours and enough intermediate values
   (142–161 unique RGB values against the set's 49–59) that the shafts read as
   softly shaded rather than flat.
3. **They are thin.** At roughly half the set's ink coverage they read faint and
   spindly next to the wakizashi, which is the same idea — one long object laid
   diagonally — drawn twice as fat.

The staffs' slate is also `#5C7396` rather than the set's `#62779C`. Invisible on
its own; it is here as evidence the palette was not sampled from the set.

## What is NOT wrong with them

**The head subjects are good and they stay.** Antlers-with-a-bolt / horns-cradling-
a-stone / a shard fan are three genuinely different silhouettes, which is the
whole job once the colour is gone. This pass changes the *treatment* only.

## How the player tells three colourless staffs apart

By silhouette, the same way they tell 28 colourless guns apart — the set already
separates a combat knife, a wakizashi and a Stormbreaker with no colour at all.
And the mage holds one staff at a time, so this is recognition against a
remembered shape, not a side-by-side discrimination test.

## Install (when the drop lands)

1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'` — LOOK at all three at
   true size in the preview folder, on the dark AND the light strip from the
   style-gap board. Then measure the delivered cells:
   **saturated pixels under 1%, tones at 3, ink over 30%.** That is the
   acceptance test and it is mechanical. ✅ DONE — the table above.
2. Sheet to `source_data/tod_ui_images/_sheets/i_tod_hud_gun_staff_sheet.png`. ✅
3. New row in `tools/slice_hud_sheets.js`:
   `file: 'i_tod_hud_gun_staff_sheet.png', w: 864, h: 132, cw: 288, ch: 132, cols: 3, rows: 1`,
   `names` = `i_tod_hud_gun_staff1|2|3`. Run `--check --src source_data/tod_ui_images/_sheets`,
   then slice. The three GDT blocks and zone lines already exist; nothing to wire. ✅
   (The slicer's own `--check` reports the sheet's one pre-existing problem, the
   dormant `i_tod_hud_pap_sheet.png` row — present before this change and
   unrelated. The slice rewrote exactly three cells plus the generated glyph
   manifest; all 28 gun cells, the offhand set, the digits, the letters and
   `TodGlyphMetrics.lua` came out byte-identical.)
4. FULL build. Proof = three fresh content-hash `.iwi` beside an untouched
   control. Flip this STATUS to SHIPPED with the version. ✅

<!-- PACK:BEGIN -->
# MAGE STAFF WEAPON ICONS — three cells, re-drawn to match a shipped set of 28

## Start here

**Open `staff_style_gap.png` and read it top to bottom before drawing anything.**
It is this whole brief in one picture: the 28 icons you are joining at their real
on-screen size, the three cells you are replacing beside their nearest
neighbours, the exact palette, and the measurements behind every instruction
below. Then open `art_direction_board.png` for the house rules.

## What this is

A player in this game carries one weapon and its icon sits in the bottom-right
corner of the screen, next to the health bar, at all times. There are 28 of these
icons and they were all drawn in one pass, so they look like a set.

Three more have since been added for a wizard character who carries three
elemental staffs — lightning, fire and ice — and **they do not look like they
belong to the set.** They were drawn for a different job and dropped in. Your
task is to redraw those three so that a player cannot tell they arrived later.

**This is a treatment fix, not a redesign.** The three staff shapes are right.
Keep them.

## Deliverable

**ONE PNG file: `i_tod_hud_gun_staff_sheet.png`, exactly 864 × 132 pixels,
RGBA with a transparent background.**

Three cells side by side, each exactly 288 × 132, in this order:

| cell | x range | subject |
|---|---|---|
| 1 | 0–287 | **LIGHTNING** staff |
| 2 | 288–575 | **FIRE** staff |
| 3 | 576–863 | **ICE** staff |

One image rather than three files, because the three must share an identical
stroke weight, outline thickness and shadow direction, and separately-drawn
pieces never do. The cell boundaries are invisible in the delivered file — just
keep each drawing inside its own 288 × 132 box with a margin, nothing touching a
cell edge, nothing crossing into a neighbour.

**Each cell is shown to the player at 144 × 66 — half the size you are drawing
it.** Draw for that size.

## The palette. Three colours. This is the hard part of the brief.

Every one of the 28 shipped icons is built from exactly these, plus antialiasing
between them:

| | | |
|---|---|---|
| `#E8EEF6` | **STEEL WHITE** | the face of the object. About half of every icon. |
| `#62779C` | **SLATE** | the darker tone. Hard-edged flat shapes only — panels, grips, vents, wraps. Never a gradient, never a shading ramp. |
| `#0A1020` | **OUTLINE BLACK** | the hard outline around the whole silhouette, and the internal separators between parts. |
| `#202A3F` | **SHADOW** | a soft dark shadow OUTSIDE the outline, offset down and to the right. Under 1% of the pixels. |

**No other colour appears anywhere in any of the three cells.**

The current staffs each carry a coloured gem — an electric-blue crystal, an
orange molten stone, a pale-cyan ice shard. **Those go.** Draw the same gems in
`#E8EEF6` with `#62779C` facets and the same black outline, exactly as the
wakizashi's diamond wrap-pattern and the axe's head are drawn. Across all 28
shipped icons, saturated colour accounts for 0.2% of the inked pixels — in
practice, none. The three staffs are at 12–14%, and it is the first thing that
marks them out as foreign.

If this feels like it removes the only way to tell the three apart: it does not.
The set already distinguishes a combat knife, a wakizashi and a Stormbreaker
using nothing but silhouette. See the next section.

## Draw them FAT

Measured on the shipped files, each staff inks about 17% of its cell. The 28 guns
average 36%. The wakizashi — the same idea, one long object laid diagonally —
inks 26% and looks substantial; the staffs look like line art beside it.

- **Thicken the shaft** until it is comparable to the wakizashi's blade, not a
  pencil line. Nothing anywhere in the drawing narrower than about 6 px on the
  288-wide canvas.
- **Enlarge the heads** so they are a real mass, not a wire outline.
- **Fill the cell diagonally, corner to corner**, the way the wakizashi does.
- **Aim for 30–40% ink coverage.** Compare against the katana and axe references
  directly — if yours looks lighter than they do, it is.

## The three heads

All three staffs share **one identical shaft, one identical wrapped grip, the
same proportions and the same diagonal angle.** They are a matched set of weapons
made by the same hand. Only the head differs — and it differs a lot, because the
head is now the only thing carrying the element.

| cell | head |
|---|---|
| 1 — LIGHTNING | Two upswept prongs like antlers, with a jagged forked bolt shape arcing between their tips. The bolt is a solid `#E8EEF6` shape with a black outline, not a thin stroke. Tall and open. |
| 2 — FIRE | A pair of heavy inward-curling horns cradling a round stone. The stone is a solid white circle with two or three `#62779C` facets. Round and closed — the opposite read to the lightning head. |
| 3 — ICE | A fan of sharp angular crystal shards spreading from a collar, like a frozen arrowhead. Wide and spiky. Facet the shards in `#62779C` so they do not read as one blob. |

**Put all three side by side at 144 × 66 before you deliver, in greyscale-adjacent
tones only, and check you can still name each one.** Tall-and-forked /
round-and-closed / wide-and-spiky is the test. If two of them read the same,
push the head shapes further apart — do not reach for colour.

## Hard rules

1. **One file, exact name `i_tod_hud_gun_staff_sheet.png`, exactly 864 × 132.**
2. **PNG with a genuinely transparent background.** No JPEG, nothing flattened
   onto white or black, no background panel behind any cell.
3. **Four values only**, from the palette table. No fifth colour, no gem colour,
   no accent.
4. **Flat.** No bevel, no gloss, no gradient, no glow, no bloom, no drop shadow
   *inside* the art, no texture, no scan lines. Two flat tones per element: a
   face, and a darker tone used only as hard-edged shapes.
5. **One heavy black outline** around every silhouette, and a soft dark shadow
   outside it, down and to the right — same offset and same direction on all
   three cells.
6. **Nothing narrower than about 6 px** on the 288-wide canvas. If a detail would
   come out under 10 px, delete it rather than shrink it.
7. **Nothing touching a cell edge** and nothing crossing into a neighbouring
   cell.
8. **No text, no numbers, no letters** anywhere on any cell.
9. **Not a photograph or a render of a real object.** These are symbols. A player
   reads one in about a fifth of a second while being chased.

## Paste-ready prompt

*Attach all nine reference files: `staff_style_gap.png`,
`art_direction_board.png`, `i_tod_hud_gun_sheet3.png`, `i_tod_hud_gun_katana.png`,
`i_tod_hud_gun_axe.png`, `i_tod_hud_gun_blade.png`, `i_tod_hud_gun_staff1.png`,
`i_tod_hud_gun_staff2.png` and `i_tod_hud_gun_staff3.png`.*

> Draw one PNG, exactly 864 x 132 pixels, transparent background, containing three
> weapon icons side by side in cells of 288 x 132: a lightning staff, a fire staff
> and an ice staff. They must be indistinguishable in treatment from the 28 weapon
> icons in the attached sheet, which is the set they join on a game HUD.
>
> Use only four values: #E8EEF6 steel white for the face of the object, #62779C
> slate as hard-edged flat shapes for the darker tone, #0A1020 as one heavy
> outline around the whole silhouette and between parts, and #202A3F as a soft
> shadow outside the outline offset down-right. NO other colour anywhere — no
> blue crystal, no orange stone, no cyan ice. The three attached staff files are
> the versions being replaced: keep their shapes, discard their colours.
>
> Everything flat: no gradient, no bevel, no gloss, no glow, no texture. Nothing
> narrower than 6 px. Each staff laid diagonally corner to corner, filling its
> cell the way the attached wakizashi and axe fill theirs — draw them FAT, about
> a third of the cell inked; the current versions are half that and look thin.
>
> All three share one identical shaft, one identical wrapped grip, the same
> proportions and the same diagonal angle. Only the head differs: (1) two upswept
> prongs like antlers with a jagged solid forked bolt arcing between their tips,
> tall and open; (2) a pair of heavy inward-curling horns cradling a round faceted
> stone, round and closed; (3) a wide fan of sharp angular crystal shards from a
> collar like a frozen arrowhead, wide and spiky. The three heads must be
> unmistakable from each other at half size with no colour to help.
>
> Nothing touching a cell edge, nothing crossing between cells, no text or numbers
> anywhere.

## Delivery checklist

- [ ] One PNG, named `i_tod_hud_gun_staff_sheet.png`, exactly 864 × 132
- [ ] RGBA with a genuinely transparent background
- [ ] Three cells of 288 × 132 in order: lightning, fire, ice
- [ ] Zero saturated colour — no gem, no accent, in any cell
- [ ] Only `#E8EEF6`, `#62779C`, `#0A1020` and the `#202A3F` outer shadow
- [ ] All three noticeably fatter than the versions being replaced, roughly a
      third of each cell inked
- [ ] Identical stroke weight, outline thickness and shadow direction across all
      three cells
- [ ] Same shaft, same grip, same angle on all three; only the head differs
- [ ] The three heads still nameable side by side at 144 × 66
- [ ] Nothing touching a cell edge, nothing crossing into a neighbour
- [ ] No text or numbers anywhere
- [ ] Checked against the light-background strip in `staff_style_gap.png` as well
      as the dark one

## Do NOT

- Do **not** keep the coloured gems, in any strength, in any cell.
- Do **not** introduce a cyan or blue accent as a compromise — the set has none.
- Do **not** redesign the head shapes; they are right, only the treatment is wrong.
- Do **not** deliver three separate files.
- Do **not** add a glow, a spark, an energy trail or a magic effect of any kind.
- Do **not** put a background panel, a frame or a circle behind any staff.
- Do **not** change the shaft, grip or angle between the three cells.
<!-- PACK:END -->
