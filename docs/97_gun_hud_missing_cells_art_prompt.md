# 93 — GUN HUD: the four cells that are still missing, plus one letter (5 files)

<!-- art-pack
name: gun_hud_missing
refs:
  docs/97_hud_ref/what_is_missing.png | THE WHOLE BRIEF IN ONE PICTURE: the twelve weapon cells that are DONE (at their true on-screen size), the two that are MISSING, and the equipment glyphs with the one to replace and the one to add. Attach to every prompt.
  docs/97_hud_ref/i_tod_hud_gun_sheet.png | THE SHIPPED WEAPON SHEET as it stands in the game right now. This is the STYLE you are matching, exactly. NOT a deliverable - do not redraw it, do not resize it, do not send it back. Attach to Prompts A and B.
  docs/97_hud_ref/i_tod_hud_offhand_sheet.png | THE SHIPPED EQUIPMENT GLYPHS. Cells 1 and 2 are done; cell 3 is the one being replaced. Same rule - NOT a deliverable. Attach to Prompts C and D.
  docs/97_hud_ref/i_tod_hud_letters.png | THE SHIPPED ALPHABET. Prompt E changes exactly one cell of it and sends the whole sheet back. Attach to Prompt E.
  docs/97_hud_ref/i_tod_hud_digits.png | THE SHIPPED NUMERALS. NOT a deliverable. Attached only so the corrected ampersand can be checked against the digit 8. Attach to Prompt E.
  docs/97_hud_ref/existing_gift_of_death_icon.png | the powerup icon this game ALREADY uses for the Gift of Death - a wrapped present with a bow and a skull. Prompt B must match its SHAPE, not its colour. Attach to Prompt B.
  docs/97_hud_ref/art_direction_board.png | the art direction: palette, the six rules, the good and bad examples. Unchanged, still governs. Attach to every prompt.
preview: 144x66 36x36
-->

> **STATUS: PACK BUILT 2026-09-04. The previous drop is INSTALLED and BUILT.**
> The twelve weapon silhouettes, the three equipment glyphs, the numerals, the
> alphabet, the panel and the tile are all in the game and looking good. This
> pack is only the pieces that did not arrive.

**Why:** the v2 brief (docs/96) asked for the two new weapons and the fourth
equipment glyph as **extra cells on the existing sheets** — the weapon sheet
growing from 6 columns to 7 (1728 → 2016 px), the equipment sheet from 3 cells to
4 (384 → 512 px). Both sheets came back **beautifully redrawn at their original
sizes**, so the new cells were never drawn at all. The detail pass landed; the
grid change did not.

**So this pack does not ask any sheet to grow.** Each missing piece is its own
single file at its own exact size. There is no arithmetic to miss.

## What actually came back last time, measured

| file | asked | got | verdict |
|---|---|---|---|
| `i_tod_hud_gun_sheet.png` | 2016 × 264 (14 cells) | 1728 × 264 (12 cells) | detail pass **landed on all 12** — installed. Two new cells absent |
| `i_tod_hud_offhand_sheet.png` | 512 × 128 (4 cells) | 384 × 128 (3 cells) | all three now have the missing dark outline — installed. Fourth cell absent |
| `i_tod_hud_letters.png` | ampersand (cell 28) fixed | **cell 12, the letter M**, changed instead | ampersand byte-identical to before. M change is fine and was kept |
| `i_tod_hud_digits.png` | do not change | the digit **4** changed | harmless refinement, kept |
| `i_tod_hud_weapon_panel.png` | do not change | corner accents + an inner bay rule added | harmless, kept |
| `i_tod_hud_offhand_tile.png` | do not change | corner notch added | harmless, kept |

Per-cell pixel diffs, not impressions — `tools/slice_hud_sheets.js --check` plus a
cell-by-cell comparison against the installed masters.

## Why these four cells exist at all

Each one is a weapon or state the HUD currently draws with the **wrong picture**,
not merely an absent nicety:

- **KATANA.** The SLASHER's ladder is Knife → **Wakizashi** → Stormbreaker, and
  the first two share the knife cell today. That class's entire tier-2
  promotion — the thing its whole upgrade path builds toward — is invisible on
  the HUD, while tier 3 is not. The wakizashi's own view model carries a sheath,
  a tsuka charm and a blade material: it is a short sword.
- **GIFT LAUNCHER.** `_tod_powerups.gsc:1051` redirects the Death Machine powerup
  to `xmas_gun`, whose model's bones are named for box-lid flaps as the magazine,
  ribbon bows, a gift tag and eight jingle bells. It fires exploding ornaments.
  Every player who grabs that powerup currently sees a minigun.
- **SPIDER / PURPLE SPIDER.** Widow's Wine replaces the player's lethal grenade;
  PhD Flopper then makes that grenade split without changing the held weapon. The
  HUD selects between them from perk state, which it can read — so all three
  lethal states are distinguishable, and the third one has no art.

<!-- PACK:BEGIN -->
# GUN HUD — four missing cells and one letter (5 files)

## Start here

**Open `what_is_missing.png` first.** It is the entire brief in one picture: the
twelve weapon silhouettes that are already in the game shown at their true
on-screen size, the two that are missing shown as empty slots, and the equipment
glyphs with the one to replace and the one to add.

**Almost everything is already done and must not be touched.** The twelve weapon
silhouettes are finished and installed. The numerals, the panel and the tile are
finished. Two of the three equipment glyphs are finished. Please do not redraw,
resize or re-send any of them — the attached sheets are there as the STYLE you
are matching, not as work.

## Deliver exactly FIVE files

| Deliver as | Canvas | What it is |
|---|---|---|
| `i_tod_hud_gun_katana.png` | **288 × 132** | ONE weapon silhouette: a curved short sword |
| `i_tod_hud_gun_gift.png` | **288 × 132** | ONE weapon silhouette: a present that shoots |
| `i_tod_hud_off_spider.png` | **128 × 128** | ONE equipment glyph: a spider |
| `i_tod_hud_off_spider_phd.png` | **128 × 128** | the same spider, purple |
| `i_tod_hud_letters.png` | **1200 × 224** | the alphabet sheet with ONE cell corrected |

The first four are **single images, not sheets**. No grid, no cells, no
neighbours — one drawing, centred, on a transparent canvas of exactly that size.

## The style you are matching

Everything below is drawn in the style of the two attached sheets, and matching
them is most of the job. From the art direction board:

- Flat vector art. **No** 3D, bevel, gloss, gradient ramp, cast shadow or texture.
- Exactly **two flat tones**: a steel-white face `#E8EEF6` and one darker cool
  grey-blue, the darker used for the hard-edged offset and for interior structure.
- A crisp dark outline `#0A1020` around the whole silhouette — about **7 px** on
  the weapon cells, **8–10 px** on the equipment glyphs.
- The **same offset direction** as every existing cell (down and to the right).
- No text anywhere.

Match the attached sheets by eye: put your new cell beside them and it must look
like it was drawn in the same pass.

## Prompt A — `i_tod_hud_gun_katana.png` (288 × 132)

Attach `what_is_missing.png`, `i_tod_hud_gun_sheet.png` and
`art_direction_board.png`.

```text
Attached: a brief showing which HUD weapon icons exist and which are missing, the
sheet of twelve that already ship, and the art direction.

Draw ONE new weapon silhouette to join that set: a KATANA.

Canvas exactly 288 x 132 pixels, PNG, RGBA, fully transparent background. One
drawing, centred, with transparent margin all round - nothing touching an edge.
It is displayed at 144 x 66 pixels, half size.

The weapon: a single-edged curved Japanese short sword, blade pointing LEFT,
shown in side profile like every other weapon on the attached sheet.
- A long blade with a gentle, clearly visible curve - not a straight bar.
- A small round or oval guard where the blade meets the handle.
- A long handle behind the guard, with three or four diagonal wrap bands across
  it drawn in the darker tone.
- Draw it at a slight angle across the cell, the way the combat knife on the
  attached sheet is angled, so it reads as a blade rather than as a line.

IT MUST NOT LOOK LIKE THE COMBAT KNIFE already on the sheet (row 2, cell 4 - the
short straight blade with the ribbed handle). In the game these are two rungs of
the same weapon ladder and a player upgrades from one to the other, so the
difference has to be obvious at a glance:
- clearly LONGER in the blade
- clearly CURVED where the knife is straight
- a visible guard, which the knife does not have
- a longer handle with wrap bands
Put your katana next to that knife cell at 144 x 66 and check it reads as a
sword, not a big knife.

Two flat tones, hard dark outline about 7 pixels, same offset direction as the
attached sheet. Nothing narrower than 10 pixels on this canvas.

Deliver as i_tod_hud_gun_katana.png.
```

## Prompt B — `i_tod_hud_gun_gift.png` (288 × 132)

Attach `what_is_missing.png`, `i_tod_hud_gun_sheet.png` and
`existing_gift_of_death_icon.png`.

```text
Attached: the brief, the sheet of twelve weapon icons that already ship, and the
powerup icon this game ALREADY uses for the weapon you are about to draw.

Draw ONE new weapon silhouette: a GIFT LAUNCHER - a full-auto gun that fires
exploding Christmas presents. It is a joke weapon and it should look like one.

Canvas exactly 288 x 132 pixels, PNG, RGBA, fully transparent background. One
drawing, centred, transparent margin all round. Displayed at 144 x 66 pixels.

This is not a guess about the weapon - its 3D model is literally a wrapped
present, and its parts are named for a box lid with two FLAPS as the magazine,
ribbon BOWS at top and bottom, a GIFT TAG and eight JINGLE BELLS.

Draw it, side profile, pointing LEFT, as:
- a squared-off wrapped BOX forming the body of the gun
- a RIBBON running across the box, with a BOW on top of it
- a small rectangular TAG hanging off one corner on a short string
- a short wide CHUTE or muzzle out the front where the presents come out
- a pistol grip and a trigger group underneath, so it still reads as a weapon
- one or two small circles for bells

The attached powerup icon (a pink present with a bow and a skull) is the SAME
weapon. Match its SHAPE LANGUAGE - box, ribbon, bow - so the two read as the
same thing in the player's head.
DO NOT copy its colours. Every weapon on the attached sheet is the same
steel-white two-tone, and a pink one would break the set. Steel-white face,
darker cool grey-blue for the offset and the ribbon, dark outline.

IT MUST NOT LOOK LIKE THE MINIGUN already on the sheet (row 1, cell 4 - the wide
body with the barrel bank). No rotary barrel cluster, no ammo belt. It should
look absurd and heavy next to the real guns - that is correct.

Two flat tones, hard dark outline about 7 pixels, same offset direction as the
attached sheet. Nothing narrower than 10 pixels on this canvas.

Deliver as i_tod_hud_gun_gift.png.
```

## Prompt C — `i_tod_hud_off_spider.png` (128 × 128)

Attach `what_is_missing.png` and `i_tod_hud_offhand_sheet.png`.

```text
Attached: the brief, and the three equipment glyphs currently in the game.

Draw ONE new equipment glyph: a SPIDER. It replaces the third glyph on the
attached sheet, which is currently a grenade with a web pattern on it.

Canvas exactly 128 x 128 pixels, PNG, RGBA, fully transparent background. One
drawing, centred, filling about 80 percent of the canvas.

THIS IS DRAWN 36 x 36 PIXELS ON SCREEN. That is the whole difficulty - it gets
about three big shapes and nothing else.

A spider seen from directly above:
- a small round head at the front and a larger round abdomen behind it, joined
  so the dark outline reads around the pair as one body
- EIGHT legs, four a side, drawn as thick bars with ONE bend each, spread evenly
  and reaching well out toward the edges of the canvas
- every leg at least 14 pixels thick
- the GAPS between the legs matter as much as the legs - each leg must be clearly
  separated from its neighbours by background, or at 36 pixels they merge into a
  disc and it stops being a spider

No eyes, no fangs, no web, no markings on the abdomen, no grenade. The silhouette
is the entire glyph.

Style, matching the attached sheet exactly:
- flat vector art, no 3D, no bevel, no gloss, no gradient
- exactly two flat tones: a steel-white face #E8EEF6 and a mid slate-blue as a
  hard-edged offset down and to the right
- a crisp dark outline #0A1020, 8 to 10 pixels, around the entire silhouette -
  the glyphs on the attached sheet have this and it is what makes them hold up

Test: shrink to 36 x 36 and put it on a dark navy tile and on white. It must read
as a fat body with eight spiky legs, and the legs must still be countable.

Deliver as i_tod_hud_off_spider.png.
```

## Prompt D — `i_tod_hud_off_spider_phd.png` (128 × 128)

Attach the FINISHED `i_tod_hud_off_spider.png` from Prompt C.

```text
Attached: the spider you have just drawn.

Deliver the SAME spider in purple.

Canvas exactly 128 x 128 pixels, PNG, RGBA, transparent background.

Identical shape, identical pose, identical leg positions, identical outline,
identical everything - only the colour changes:
- face: a bright violet
- darker tone: a deeper purple, same hard-edged offset down and to the right
- outline: the same dark #0A1020

The game shows these two spiders in the same place on screen, and the same player
will see one become the other when they buy a perk. If the shapes differ at all
it will read as a mistake rather than as a change of state. Copy the drawing and
recolour it - do not redraw it.

Deliver as i_tod_hud_off_spider_phd.png.
```

## Prompt E — `i_tod_hud_letters.png` (1200 × 224) — ONE CELL

Attach `i_tod_hud_letters.png` and `i_tod_hud_digits.png`.

```text
Attached: the alphabet sheet currently in the game, and the numeral sheet used
alongside it.

The alphabet is correct and is staying. EXACTLY ONE cell is wrong. Send the whole
sheet back with only that cell changed.

Canvas exactly 1200 x 224 pixels, PNG, RGBA, transparent background, same
15 column x 2 row grid of 80 x 112 cells, same order:

  row 1:  A B C D E F G H I J K L M N O
  row 2:  P Q R S T U V W X Y Z - ' & .

THE CELL TO CHANGE IS THE AMPERSAND. It is the 29th cell: row 2, the 14th
column - pixel region x 1040 to 1120, y 112 to 224. Please count to it on the
attached sheet before drawing, because the last revision changed the letter M
instead and the ampersand came back untouched.

WHAT IS WRONG WITH IT: it was drawn as a squared-off form with a small
rectangular hole near the top and a diagonal tail, and it reads as the digit 8 or
the letter B at every size it is shown. The two weapon names in the game that use
it currently read "DEATH 8 TAXES" and "VOICE OF JUSTICE 8 RAGING JUDGE".

Redraw ONLY that cell as an unmistakable ampersand:
- the classic looping form: a closed loop at the TOP LEFT, a diagonal stroke
  running down and right out of it, and a tail kicking out to the lower right
  past the body
- the top loop must be clearly SMALLER than the bottom of the glyph. That
  top-to-bottom asymmetry is what stops it reading as an 8
- the hole in the top loop must be open and at least 12 pixels across
- DO NOT give it a second closed hole at the bottom. An ampersand with two
  stacked holes IS an 8. The lower half must be open on the right
- same cap height (74 px), same baseline (y 94 within the row), same stroke
  weight (about 16 px), same two flat tones, same 5 px offset down and right,
  same 5 px dark outline as every other letter on the sheet
- roughly 58 px wide, centred in its cell, touching no boundary

EVERY OTHER CELL ON THIS SHEET MUST COME BACK UNCHANGED.

Test: cut the sheet, shrink to 27 x 36, and set "DEATH & TAXES" using the
attached numerals for any digits. Compare your ampersand directly against the 8
on the numeral sheet - they must not be confusable.

Deliver as i_tod_hud_letters.png.
```

## Delivery checklist

- [ ] Five files, named exactly as in the table
- [ ] `i_tod_hud_gun_katana.png` and `i_tod_hud_gun_gift.png` are **288 × 132**,
      one drawing each, transparent, nothing touching an edge
- [ ] `i_tod_hud_off_spider.png` and `i_tod_hud_off_spider_phd.png` are
      **128 × 128**, identical in shape, differing only in colour
- [ ] `i_tod_hud_letters.png` is **1200 × 224** and differs from the attached one
      in **exactly one cell — the ampersand, row 2 column 14**
- [ ] The katana does not read as the combat knife at 144 × 66
- [ ] The gift launcher does not read as the minigun at 144 × 66
- [ ] The spider's eight legs are countable at 36 × 36 on white and on dark
- [ ] Every new piece has the hard dark outline and the same offset direction as
      the attached sheets

## Do NOT

- **Do not send back the weapon sheet or the equipment sheet.** They are
  attached as style reference only. They are finished and installed.
- Do not send back the numerals, the panel or the tile.
- Do not resize anything. Nothing on this list grows or shrinks.
- Do not draw the katana as a straight knife, or the gift launcher as a
  conventional gun.
- Do not put a web, a grenade or a pattern on the spider — it is a spider.
- Do not change any cell of the alphabet except the ampersand.
- Do not use orange, red or green. The only warm colour in the whole set is the
  cymbal monkey; the only violet is the purple spider.
<!-- PACK:END -->

## Install (when the drop lands)

1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'` and LOOK at all five.
2. The four single-cell files are **composited into the master sheets** rather
   than shipped loose, so the repo keeps one master per family and
   `slice_hud_sheets.js` stays the single cutter:
   - `i_tod_hud_gun_sheet.png` 1728 × 264 → **2016 × 264**, katana into cell 12
     and gift into cell 13 (the grid becomes 7 × 2; `SHEETS` in the slicer needs
     `cols: 7` and the two names appended in reading order).
   - `i_tod_hud_offhand_sheet.png` 384 × 128 → **512 × 128**, spider replacing
     cell 2 (`i_tod_hud_off_web` retires) and the purple spider as cell 3.
3. `node tools/slice_hud_sheets.js --check` must pass before slicing — it proves
   canvas size, no cell-boundary crossings, and one baseline per typeface row.
4. New names: `i_tod_hud_gun_katana`, `i_tod_hud_gun_gift`,
   `i_tod_hud_off_spider`, `i_tod_hud_off_spider_phd`. Each needs a GDT block and
   an `image,` line; `i_tod_hud_off_web` is retired whole (image, block and zone
   line together).
5. `AetheriumLoadout.lua`: add `t9_me_wakizashi -> "katana"` and
   `xmas_gun -> "gift"` to `TOD_GUN_CAT`, and point `TOD_OFF_WIDOW` /
   `TOD_OFF_WIDOW_PHD` at the two spiders.
6. **FULL build.** Proof = a fresh content-hash `.iwi` for each new name beside
   an untouched control.
