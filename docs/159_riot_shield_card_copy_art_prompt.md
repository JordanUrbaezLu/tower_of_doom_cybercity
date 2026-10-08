# 159 — RIOT SHIELD: say whose health it is, on four cards

<!-- art-pack
name: riot_shield_card_copy
refs:
  i_tod_card_riot_shield_regular.png | ORIGINAL to edit. RIOT SHIELD, REGULAR rarity. Body text reads "MORE HEALTH, / FASTER RECHARGE" over two lines, light grey-white.
  i_tod_card_riot_shield_super.png | ORIGINAL to edit. RIOT SHIELD, SUPER rarity. Same two-line body text, purple frame, lilac text.
  i_tod_card_riot_shield_ultimate.png | ORIGINAL to edit. RIOT SHIELD, ULTIMATE rarity. Same two-line body text, gold frame, yellow text.
  i_tod_card_riot_shield_dark.png | ORIGINAL to edit. RIOT SHIELD, DARK rarity. Same two-line body text, red frame, cream text.
preview: 234x351
-->

Status: SHIPPED 2026-09-23 (v19.46; FULL BUILD OK 18:24:49 Eastern, FF 147,403,456 B; four fresh content-hash .iwi at 18:24:40-41 beside an untouched DAMAGE control; deployed PNGs == repo; scripts/ui/zone_source diffs clean, nothing synced after; banks 68,465,920 / 207,523,840). UNPLAYED. Requested via
`~/Downloads/tod_riot_shield_card_copy_art_pack.zip`; returned as
`files - 2026-09-23T181852.284.zip` (all four). Proofread: "MORE RIOT HEALTH, /
FASTER RECHARGE" on every card, both lines same size, centred, clear of the box.
PIXEL-DIFFED against the shipped files: 2.2-2.9% of pixels changed per card, ALL
inside the body text box (x 170-598, y 861-967; zero changed pixels outside it) -
title, artwork, frame, ribbon, medallion and pips untouched. New md5s: regular
ef9be13d…, super aa1b903f…, ultimate d757aea7…, dark 146b9b9d…. Originals
(regular 1389fa5c…, super 0c9d6fc3…, ultimate 9c038acf…, dark fe31a8ff…) parked in
`docs/159_ref/_prev_shipped/` (not git-tracked; the only copy).

**Why:** players read the card's "MORE HEALTH, FASTER RECHARGE" as THEIR OWN
health going up. The upgrade raises the SHIELD's health (200 -> 500 HP) and
shortens its recharge; player health is untouched. User 2026-09-23: "people
think that it's their player health that goes up ... just adding Riot in the
description somewhere will make more sense". The wording is the user's:
`MORE RIOT HEALTH, FASTER RECHARGE`.

**Why the in-game text needs nothing:** the pause menu and scoreboard already
read "200 HP shield, back in 4:00" (DETAIL[45], `shieldHp`/`shieldRecharge`),
which names the shield. The baked card is the only ambiguous line.

**The one real layout change:** line 1 grows from `MORE HEALTH,` (12
characters) to `MORE RIOT HEALTH,` (17), which is wider than line 2
`FASTER RECHARGE` (15). Line 2 already nearly fills the panel, so both lines
may need to shrink slightly to fit. The brief tells the generator to shrink
BOTH lines together rather than let line 1 touch the panel edge.

<!-- PACK:BEGIN -->

# RIOT SHIELD — add one word on four cards

This is a small text-edit request: **four existing card images, one word added
to the body text on each.** Everything else on every card must come back
pixel-identical. The originals are all in `reference/`. Edit those; do not
redraw them.

## The change

The body text panel at the bottom of each card currently reads, on two lines:

`MORE HEALTH,`
`FASTER RECHARGE`

It must read, on two lines:

`MORE RIOT HEALTH,`
`FASTER RECHARGE`

The only change is the word `RIOT` inserted before `HEALTH` on the first line.
The second line stays exactly the same words.

| # | File (deliver with this exact name) | Size | Body text NOW | Body text WANTED |
|---|---|---|---|---|
| 1 | `i_tod_card_riot_shield_regular.png` | 768x1152 | `MORE HEALTH,` / `FASTER RECHARGE` | `MORE RIOT HEALTH,` / `FASTER RECHARGE` |
| 2 | `i_tod_card_riot_shield_super.png` | 768x1152 | `MORE HEALTH,` / `FASTER RECHARGE` | `MORE RIOT HEALTH,` / `FASTER RECHARGE` |
| 3 | `i_tod_card_riot_shield_ultimate.png` | 768x1152 | `MORE HEALTH,` / `FASTER RECHARGE` | `MORE RIOT HEALTH,` / `FASTER RECHARGE` |
| 4 | `i_tod_card_riot_shield_dark.png` | 768x1152 | `MORE HEALTH,` / `FASTER RECHARGE` | `MORE RIOT HEALTH,` / `FASTER RECHARGE` |

## Fitting the longer line

The new first line is a little longer than the second, and the second line
already almost fills the dark text box. So:

- Keep **both lines the same text size as each other.**
- If `MORE RIOT HEALTH,` fits inside the dark text box at the current size with
  a clear margin, keep the current size.
- If it does not, **shrink both lines together**, just enough that the longer
  line keeps roughly the same gap to the box edge that `FASTER RECHARGE` has
  now. Never let a letter touch or cross the box's border.
- Keep both lines **centred** horizontally on the box, and keep the pair
  vertically centred in the box as it is now.

## Hard rules

- **Edit the supplied originals.** Do not regenerate the cards from scratch.
- **Only the body text may change.** The frame, the title band (`RIOT SHIELD`),
  the artwork, the rarity ribbon (`REGULAR +1` / `SUPER +2` / `ULTIMATE +3` /
  `DARK UPGRADE`), the star medallion, the level pips, the background, the
  screws, the glow and the dark text box itself must be untouched.
- **Match the existing lettering exactly**: same typeface, weight, colour,
  outline and shadow as the current body text on THAT card. The four cards use
  four different text colours; each keeps its own.
- **Keep the exact canvas size, 768x1152**, with the same transparent margins.
- **Keep the same filenames.** These overwrite the live files by name.
- **PNG with alpha (RGBA).** No JPEG, no flattening onto a solid background.
- **No numbers.** These cards deliberately carry no values. Do not add any.

## Prompt you can use

> Attached are four card images from a game UI, all titled "RIOT SHIELD" in
> four rarity colourways. On each one, the dark text box near the bottom reads
> "MORE HEALTH," on the first line and "FASTER RECHARGE" on the second. Change
> the first line to "MORE RIOT HEALTH," (insert the word RIOT before HEALTH)
> and leave the second line as "FASTER RECHARGE". Use the same font, weight,
> colour, outline and shadow as the existing text on that card. Keep both lines
> the same size and centred in the box; if the longer first line would crowd
> the box edge, shrink both lines together slightly so it keeps the same margin
> the second line has now. Change nothing else: the border, title band,
> artwork, rarity ribbon, medallion, pips and background must stay pixel
> identical. Return each image as a PNG with transparency at its original
> 768x1152 size and its original filename.

## Delivery checklist

- [ ] Four PNGs, named exactly as the table above.
- [ ] Each is 768x1152, RGBA, with transparency preserved.
- [ ] Line 1 reads `MORE RIOT HEALTH,` (with the comma) on all four, correctly spelled.
- [ ] Line 2 still reads `FASTER RECHARGE` on all four.
- [ ] Both lines are the same size, centred, and clear of the box border.
- [ ] Every other pixel matches the supplied original.
- [ ] Compare each against `preview_onscreen_234x351/`. That is the real size
      these are seen at in game, and both lines must still be legible there.

## Do NOT

- Do not redraw, restyle or "improve" the cards.
- Do not change the title, the artwork, the frame, the ribbon or the pips.
- Do not change the words on the second line.
- Do not resize, crop, or flatten the alpha channel.
- Do not add a number, a percentage or any other figure.
- Do not rename the files or wrap them in extra folders.

<!-- PACK:END -->

## On return

1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'` and LOOK at all four.
2. Proofread both lines on every card, including the DARK one (different
   colourway, easy to skip).
3. Overlay each against the shipped file: only the body text band should differ.
   Park the originals in `docs/159_ref/_prev_shipped/` first (these PNGs are
   not git-tracked; that folder is the only copy).
4. Copy into `source_data/tod_ui_images/_images/`. **No wiring is needed**:
   same names, already zoned (`zm_tower_of_doom.zone:1306-1309`), `CARD_SLUG[45]`
   already `riot_shield`. Straight overwrite.
5. FULL build (image change = GDT conversion), then prove with fresh
   content-hash `.iwi` files beside an untouched control.
6. Flip this doc to SHIPPED with the build version.
