# 156 — LEECH + KNIFE SPEED: one word on eight cards

<!-- art-pack
name: slasher_melee_copy
refs:
  i_tod_card_leech_regular.png | ORIGINAL to edit. LEECH, REGULAR rarity. Body line reads "BLADE KILLS / HEAL YOU" over two lines.
  i_tod_card_leech_super.png | ORIGINAL to edit. LEECH, SUPER rarity. Same two-line body copy, purple frame.
  i_tod_card_leech_ultimate.png | ORIGINAL to edit. LEECH, ULTIMATE rarity. Same two-line body copy, gold frame.
  i_tod_card_leech_dark.png | ORIGINAL to edit. LEECH, DARK rarity. Same two-line body copy, red frame, cream text.
  i_tod_card_knife_speed_regular.png | ORIGINAL to edit. KNIFE SPEED, REGULAR rarity. Body line reads "FASTER BLADE SWING" on ONE line.
  i_tod_card_knife_speed_super.png | ORIGINAL to edit. KNIFE SPEED, SUPER rarity. Same one-line body copy, purple frame.
  i_tod_card_knife_speed_ultimate.png | ORIGINAL to edit. KNIFE SPEED, ULTIMATE rarity. Same one-line body copy, gold frame.
  i_tod_card_knife_speed_dark.png | ORIGINAL to edit. KNIFE SPEED, DARK rarity. Same one-line body copy, red frame, cream text.
preview: 234x351
-->

Status: SHIPPED 2026-09-22 (full build 15:39:00 Eastern, FF 147,080,064 B; fresh content-hash .iwi for both sets at 15:28 beside an untouched DAMAGE control). Installed from `files - 2026-09-22T152105.980.zip`. All
eight returned; each proofread (MELEE, correct spelling, original line breaks
kept) and PIXEL-DIFFED against the shipped file: 0.19-0.21% of pixels changed
per card, all inside one word-sized box in the body band (y 874-961) - title,
artwork, frame, ribbon and pips are untouched. Originals parked in
`docs/156_ref/_prev_shipped/` (these PNGs are not git-tracked; that folder is
the only copy). Same names, already zoned: straight overwrite, full build.
⚠️ This brief had the one-line / two-line split wrong per rarity (regular LEECH
is ONE line, dark KNIFE SPEED is TWO). Harmless, because it told the generator
to keep each original's layout - which is the instruction to reuse.

**Why:** the Slasher's weapon roster changed. Tier 1 is a BASEBALL BAT and
tier 3 is the STORMBREAKER (a Leviathan axe); only tier 2 is a blade. Both
domains apply to all three, so "BLADE" is wrong on two thirds of the class.
The GSC and the in-game menu text were corrected on 2026-09-22; these eight
baked images are the only place the old word survives.

**Why it is cheap:** `MELEE` and `BLADE` are both five characters, so the line
length, the line breaks and the centring are all unchanged. This is a text
swap on an existing image, not a re-draw.

<!-- PACK:BEGIN -->

# LEECH + KNIFE SPEED — change one word on eight cards

This is the smallest kind of request: **eight existing card images, one word
changed on each.** Everything else on every card must come back pixel-identical.
The originals are all in `reference/` — edit those, do not redraw them.

## The change

One word in the body text panel at the bottom of each card. `BLADE` becomes
`MELEE`. Nothing else changes anywhere on any card.

| # | File (deliver with this exact name) | Size | Body line NOW | Body line WANTED |
|---|---|---|---|---|
| 1 | `i_tod_card_leech_regular.png` | 768x1152 | `BLADE KILLS` / `HEAL YOU` | `MELEE KILLS` / `HEAL YOU` |
| 2 | `i_tod_card_leech_super.png` | 768x1152 | `BLADE KILLS` / `HEAL YOU` | `MELEE KILLS` / `HEAL YOU` |
| 3 | `i_tod_card_leech_ultimate.png` | 768x1152 | `BLADE KILLS` / `HEAL YOU` | `MELEE KILLS` / `HEAL YOU` |
| 4 | `i_tod_card_leech_dark.png` | 768x1152 | `BLADE KILLS` / `HEAL YOU` | `MELEE KILLS` / `HEAL YOU` |
| 5 | `i_tod_card_knife_speed_regular.png` | 768x1152 | `FASTER BLADE SWING` | `FASTER MELEE SWING` |
| 6 | `i_tod_card_knife_speed_super.png` | 768x1152 | `FASTER BLADE SWING` | `FASTER MELEE SWING` |
| 7 | `i_tod_card_knife_speed_ultimate.png` | 768x1152 | `FASTER BLADE SWING` | `FASTER MELEE SWING` |
| 8 | `i_tod_card_knife_speed_dark.png` | 768x1152 | `FASTER BLADE SWING` | `FASTER MELEE SWING` |

The LEECH line stays on **two** lines and the KNIFE SPEED line stays on **one**.
`MELEE` and `BLADE` are both five characters, so no re-flow is needed or wanted.

## Hard rules

- **Edit the supplied originals.** Do not regenerate the card from scratch.
- **Only the pixels of that one word may change.** The frame, the title band,
  the artwork, the rarity ribbon, the star medallion, the level pips, the
  background, the screws and the glow must all be untouched.
- **Match the existing lettering exactly**: same typeface, same weight, same
  size, same colour, same outline/shadow, same baseline, same letter spacing.
  The replacement word sits where the old one sat.
- **Keep the exact canvas size, 768x1152**, with the same transparent margins.
- **Keep the same filename.** These overwrite the live files by name.
- **PNG with alpha (RGBA).** No JPEG, no flattening onto a solid background.
- **No numbers, ever.** These cards deliberately carry no percentages so the
  values can be tuned without new art. Do not add any.
- Do not change the card TITLE. `KNIFE SPEED` stays `KNIFE SPEED` even though
  the body line changes; the name is used elsewhere in the game and is not part
  of this request.
- Do not change the knife artwork. A future request may revisit it; this one is
  copy only.

## Prompt you can use

> Attached are eight card images from a game UI. On each one, the body text
> panel near the bottom contains the word **BLADE**. Replace only that word with
> **MELEE**, keeping the same font, weight, size, colour, outline, letter
> spacing, baseline and position. Both words are five letters, so the line
> should not re-flow or re-centre. Change nothing else: the border, title band,
> artwork, rarity ribbon, medallion, pips and background must stay pixel
> identical. Return each image as a PNG with transparency at its original
> 768x1152 size and its original filename.
>
> - `i_tod_card_leech_*.png`: "BLADE KILLS / HEAL YOU" becomes
>   "MELEE KILLS / HEAL YOU", staying on two lines.
> - `i_tod_card_knife_speed_*.png`: "FASTER BLADE SWING" becomes
>   "FASTER MELEE SWING", staying on one line.

## Delivery checklist

- [ ] Eight PNGs, named exactly as the table above.
- [ ] Each is 768x1152, RGBA, with transparency preserved.
- [ ] The word reads `MELEE` on all eight, correctly spelled.
- [ ] Every other pixel matches the supplied original.
- [ ] No numbers anywhere on any card.
- [ ] Compare each against `preview_onscreen_234x351/` — that is the real size
      these are seen at in game, and the body line must still be legible there.

## Do NOT

- Do not redraw, restyle or "improve" the cards.
- Do not change the title, the artwork, the frame or the pips.
- Do not resize, crop, or flatten the alpha channel.
- Do not add a percentage, a level number or any other figure.
- Do not rename the files or wrap them in extra folders.

<!-- PACK:END -->

## On return

1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'` and LOOK at all eight.
2. Proofread the word on every one, including the four DARK cards — those are
   easy to forget because they are a different colourway.
3. Overlay each against the shipped file: only the one word should differ.
4. Copy into `source_data/tod_ui_images/_images/`. **No wiring is needed** —
   same names, already zoned (`zm_tower_of_doom.zone:648-655`), `CARD_SLUG`
   already set for both domains. It is a straight overwrite.
5. FULL build (image change = GDT conversion), then prove with fresh
   content-hash `.iwi` files beside an untouched control.
6. Flip this doc to SHIPPED with the build version.
