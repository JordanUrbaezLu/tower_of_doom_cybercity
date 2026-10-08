# 157 — Spire victory banner: "100 FLOORS" -> "70 FLOORS"

<!-- art-pack
name: spire_win_banner_70
refs:
  i_tod_spire_win_banner.png | ORIGINAL to edit. The Endless Spire victory banner. Subtitle line reads "100 FLOORS - NOTHING LEFT TO CLIMB"; change only the number.
  i_tod_spire_over_banner.png | STYLE MATCH ONLY, do not edit. The Spire's loss banner, same frame family, for comparison of the subtitle lettering.
preview: 900x225
-->

Status: INSTALLED 2026-09-22 17:2x, FULL BUILD PENDING. Requested (v19.38) via
`~/Downloads/tod_spire_win_banner_70_art_pack.zip`; returned as a loose
`~/Downloads/i_tod_spire_win_banner.png` (md5 3c4b2b2a…). Proofread: "70 FLOORS -
NOTHING LEFT TO CLIMB", centred. 2048x512 RGBA. PIXEL-DIFFED against the shipped
file: 2.2% of pixels changed, ALL inside x620-1426 / y329-368 (the subtitle line);
title, frame, stars and rails untouched. Original parked in
`docs/157_ref/_prev_shipped/` (md5 589ae32f…, not git-tracked — the only copy).

**Why:** the Endless Spire has been 70 floors since v17.69 (`SP_LAPS = 70` in
`tools/gen_tower_map.js`, seven hubs). The victory banner shown on every summit
win (`_tod_spire.gsc::spire_game_over`, `SetShader( "tod_spire_win_banner", 900, 225 )`)
still bakes "100 FLOORS" from the original 100-lap spire. Found by the
2026-09-22 player-experience audit.

**Why it is cheap:** one number on one existing image. The frame, the title,
the stars and the glow all stay. The line gets one character shorter and is
re-centred on the same axis.

<!-- PACK:BEGIN -->

# Spire victory banner — change one number

This is the smallest kind of request: **one existing banner image, one number
changed.** Everything else must come back pixel-identical. The original is in
`reference/` — edit it, do not redraw it.

## The change

The small subtitle line under the big title currently reads:

`100 FLOORS - NOTHING LEFT TO CLIMB`

It must read:

`70 FLOORS - NOTHING LEFT TO CLIMB`

| # | File (deliver with this exact name) | Size | Subtitle NOW | Subtitle WANTED |
|---|---|---|---|---|
| 1 | `i_tod_spire_win_banner.png` | 2048x512 | `100 FLOORS - NOTHING LEFT TO CLIMB` | `70 FLOORS - NOTHING LEFT TO CLIMB` |

The title `YOU CONQUERED THE SPIRE` does not change.

## Hard rules

- **Edit the supplied original** (`reference/i_tod_spire_win_banner.png`). Do not regenerate the banner.
- **Only the subtitle line may change.** The title, the dark plate, the gold
  frame, the star field, the top flare, the red/gold rails and every glow must be untouched.
- **Match the existing subtitle lettering exactly**: same typeface, weight,
  size, pale mint-blue fill, dark outline, glow and baseline. The new `7` and
  `0` must look like they came from the same set as the letters around them;
  the `0` in `70` should match the shape of the `0`s in the old `100`.
- **Re-centre the shorter line** on the same horizontal centre the old line used
  (the centre of the banner). Do not leave it left-aligned with a gap on the right.
- **Keep the exact canvas size, 2048x512**, with the same transparent margins.
- **PNG with alpha (RGBA).** No JPEG, no flattening onto a solid background.
- **Keep the same filename.** It overwrites the live file by name.

## Prompt you can use

> Attached is a banner image from a game UI (`i_tod_spire_win_banner.png`).
> Under the big gold title "YOU CONQUERED THE SPIRE" there is a smaller
> subtitle line that reads "100 FLOORS - NOTHING LEFT TO CLIMB". Change it to
> "70 FLOORS - NOTHING LEFT TO CLIMB": replace "100" with "70", keeping the
> same font, weight, size, pale mint-blue colour, dark outline, glow and
> baseline, and re-centre the slightly shorter line on the banner's centre.
> Change nothing else — the title, frame, stars, flare and rails must stay
> pixel identical. Return a PNG with transparency at the original 2048x512
> size with the original filename. The second reference image
> (`i_tod_spire_over_banner.png`) is only a style comparison; do not edit or return it.

## Delivery checklist

- [ ] One PNG, named exactly `i_tod_spire_win_banner.png`.
- [ ] 2048x512, RGBA, transparency preserved.
- [ ] Subtitle reads `70 FLOORS - NOTHING LEFT TO CLIMB`, correctly spelled, centred.
- [ ] Every other pixel matches the supplied original.
- [ ] Check it against `preview_onscreen_900x225/` — that is the size it is shown
      at in game, and the subtitle must still be legible there.

## Do NOT

- Do not change the title text or its colours.
- Do not redraw, restyle or "improve" the banner.
- Do not resize, crop, or flatten the alpha channel.
- Do not rename the file or wrap it in extra folders.
- Do not return or edit the style-reference loss banner.

<!-- PACK:END -->

## On return

1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'` and LOOK at it.
2. Proofread the subtitle: `70 FLOORS - NOTHING LEFT TO CLIMB`, centred.
3. Overlay against the shipped file: only the subtitle band should differ.
   Park the original in `docs/157_ref/_prev_shipped/` first (these PNGs are
   not git-tracked).
4. Copy into `source_data/tod_ui_images/_images/`. **No wiring is needed** —
   same name, already zoned (`zm_tower_of_doom.zone:522` image, `:527`
   material). Straight overwrite.
5. FULL build (image change = GDT conversion), then prove with a fresh
   content-hash `.iwi` beside an untouched control.
6. Flip this doc to SHIPPED with the build version.
