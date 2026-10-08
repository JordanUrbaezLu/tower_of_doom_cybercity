# 101 — DARK PAUSE PLATES: the four that were never made (MAG SIZE, HANDLING, RECOIL, KNIFE SPEED)

<!-- art-pack
name: dark_pause_plates_missing
refs:
  i_tod_pause_r23.png | RUN AND GUN, the ordinary blue plate. THE WORKED EXAMPLE: this is a source plate...
  i_tod_pause_r23_dark.png | ...and this is its finished DARK variant from the previous batch. The exact recipe to repeat: same shape, same word, bar goes crimson, word stays light.
  i_tod_pause_r07.png | MAG SIZE - source plate 1 of 4. Deliver i_tod_pause_r07_dark.png.
  i_tod_pause_r16.png | HANDLING - source plate 2 of 4. Deliver i_tod_pause_r16_dark.png.
  i_tod_pause_r17.png | RECOIL - source plate 3 of 4. Deliver i_tod_pause_r17_dark.png.
  i_tod_pause_r18.png | KNIFE SPEED - source plate 4 of 4. Deliver i_tod_pause_r18_dark.png.
preview: 210x31
-->

> **STATUS: SHIPPED v17.49 (2026-09-04).** The drop
> (`files - 2026-09-04T193429.273.zip`) came back to spec: alpha byte-identical
> to the sources, crimson within 3 units of r23_dark, text untouched. Wired
> (GDT + zone), `DARK_PLATE_NONE` is now empty. UNPLAYED as of the build.

## Why (user, 2026-09-04)

*"Is the Handling Dark upgrade pause menu implemented correctly? Let's check
those. I think it's different from what's in pause menu for dark Run and Gun."*

Audited end to end:

| lane | HANDLING dark | RUN AND GUN dark | verdict |
|---|---|---|---|
| effect in game | `twin_suffix` bumps the packed MP7's `h` axis to the dark rung h4 (-55%) when the dark bit is set; `gen_tod_twins.js` `axisMaxUp: { h: 4 }` | `TOD_DARK_RNG_ADD` on the stage table (52% -> 77%) | both paid |
| pause-menu text | `DARK[16]`: "-55% reload, swap and ADS time" / "MP7, Pack-a-Punched" | `DARK[23]`: "77% of shots free, +77% damage" / "per bullet while running or sprinting" | same format, both LOCKSTEP with the GSC numbers |
| pause-menu PLATE | **no baked `i_tod_pause_r16_dark`** -> `DARK_PLATE_NONE` -> the blue plate with `setRGB(1.0, 0.34, 0.36)` — a multiplicative tint that turns the cyan/white WORD red too | baked `i_tod_pause_r23_dark`: crimson bar, word kept light | **this is the difference** |

The four weapon-variant domains (MAG SIZE 7, HANDLING 16, RECOIL 17, KNIFE
SPEED 18) became dark-capable in v17.10, AFTER docs/94 scoped the dark plate
batch to the 24 domains that could go dark at the time — so their plates were
never commissioned and the code parked them in `DARK_PLATE_NONE` with a tint
fallback. The tint is a placeholder that reads as a different design.

## Install (when the drop lands)

1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'` — overlay each on its
   source at 100 % (nothing moves), proofread the four words, check 210×31.
2. Copy the four into `source_data/tod_ui_images/_images/`.
3. Wire like `i_tod_pause_r23_dark`: a GDT block each in `tod_ui_images.gdt`
   (clone the r23_dark block) and an `image,` line each in the zone beside its
   base plate.
4. `tod_upgrade.lua`: delete 7, 16, 17, 18 from `DARK_PLATE_NONE` (the comment
   above it says to do exactly this the commit the plates are zoned).
   `lint_tod_assets.js` parses that table, so GATE A covers the four names.
5. FULL build; proof = 4 fresh content-hash `.iwi` beside a control. Flip this
   STATUS to SHIPPED.

<!-- PACK:BEGIN -->
# DARK PAUSE PLATES — four more, same recipe as before (4 files)

## What this is

These are name plates from the pause menu of a Black Ops 3 zombies map: small
horizontal bars carrying one ability's name, stacked in a list. A plate has a
RED variant that is shown when the player holds the DARK version of that
ability. Twenty-four of those red variants already exist and are in the game.
**Four abilities were added to the dark set after that batch and never got
theirs.** This job is those four.

Every file is **300 × 44 px** and is drawn at **210 × 31 px** on a 1080p screen
— see `preview_onscreen_210x31/`. Judge everything at that size.

## The recipe is already decided — copy it

Open `i_tod_pause_r23.png` and `i_tod_pause_r23_dark.png` side by side. That
pair IS the specification: same canvas, same bar shape, same word in the same
place, and the bar has gone from blue to a deep, slightly desaturated crimson
while the word stayed light and just as readable. The little cyan pip at the
left became red. Nothing else changed.

Do exactly that to the four source plates below.

## Deliverables — 4 files, exact names

| Deliver as | Built from | Word on the plate |
|---|---|---|
| `i_tod_pause_r07_dark.png` | `i_tod_pause_r07.png` | MAG SIZE |
| `i_tod_pause_r16_dark.png` | `i_tod_pause_r16.png` | HANDLING |
| `i_tod_pause_r17_dark.png` | `i_tod_pause_r17.png` | RECOIL |
| `i_tod_pause_r18_dark.png` | `i_tod_pause_r18.png` | KNIFE SPEED |

The word column is for PROOFREADING what is already baked in, not for
re-setting it. If a source disagrees with the column, say so rather than
changing it.

## Hard rules

1. **300 × 44 px, PNG-32, alpha preserved and matching the source exactly.**
   Overlay your result on the source at 100 %: nothing moves by a pixel.
2. **The word does not change.** Same text, font, size, position, spacing.
   Do not tint the TEXT red — the bar goes red, the name stays light.
3. **Match `i_tod_pause_r23_dark.png`.** Same crimson, same treatment of the
   edge light and the left pip. These four will sit in the same list as the
   twenty-four already done and must be indistinguishable in recipe.
4. **No new elements.** No icons, no glow, no border, no "DARK" label.

## The prompt

Attach `i_tod_pause_r23.png`, `i_tod_pause_r23_dark.png` and the four source
plates.

```text
Attached: a blue menu name plate (i_tod_pause_r23.png) and its finished dark-red
variant (i_tod_pause_r23_dark.png) - that pair is the exact recipe. Also
attached: four more blue plates that need the same treatment.

For each of the four source plates, produce its dark variant exactly the way
r23 was done: same 300 x 44 canvas, same bar shape, same transparent margin,
same word in the same place at the same size; the bar goes from blue to the
same deep, slightly desaturated crimson as r23_dark; the small cyan pip at the
left goes red the same way; the WORD stays light and stays exactly as readable.
Do not tint the text. Do not add anything. Do not move anything - overlay each
result on its source at 100 percent and nothing should shift by a pixel.

Deliver four PNG-32 files with alpha, exactly 300 x 44 each:
  i_tod_pause_r07_dark.png  from i_tod_pause_r07.png  (MAG SIZE)
  i_tod_pause_r16_dark.png  from i_tod_pause_r16.png  (HANDLING)
  i_tod_pause_r17_dark.png  from i_tod_pause_r17.png  (RECOIL)
  i_tod_pause_r18_dark.png  from i_tod_pause_r18.png  (KNIFE SPEED)

Check each at 210 x 31 pixels - that is the size it is read at.
```

## Delivery checklist

- [ ] 4 files, exact names
- [ ] every file 300 × 44, PNG-32, alpha matching the source
- [ ] overlaid on the source at 100 %: nothing moved
- [ ] the four words proofread, unchanged, still light
- [ ] the crimson matches `i_tod_pause_r23_dark.png`
- [ ] each readable at 210 × 31

## Do NOT

- Do **not** change the canvas, the bar shape or the transparent margin.
- Do **not** re-typeset, re-position or re-kern any word.
- Do **not** tint the TEXT red.
- Do **not** re-send `i_tod_pause_r23_dark.png` — it is the example, not a deliverable.
<!-- PACK:END -->
