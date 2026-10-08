# 111 — ADRENALINE card re-copy (domain 25: the value line gains healing, 4 images)

<!-- art-pack
name: adrenaline_recopy
refs:
  i_tod_card_adrenaline_regular.png | THE SOURCE for the REGULAR card. Reproduce it exactly; only the two-line value plate changes. Attach to Prompt A.
  i_tod_card_adrenaline_super.png | THE SOURCE for the SUPER card. Same illustration, purple treatment, 2 lit pips. Attach to Prompt B.
  i_tod_card_adrenaline_ultimate.png | THE SOURCE for the ULTIMATE card. Same illustration, gold treatment, 3 lit pips. Attach to Prompt C.
  i_tod_card_adrenaline_dark.png | THE SOURCE for the DARK card. Same illustration, red/black treatment, 5 lit red pips. Attach to Prompt D.
preview: 213x320
-->

> **STATUS: SHIPPED into source 2026-09-05 (v17.85), NOT YET BUILT.** Drop `files - 2026-09-05T154021.035.zip` (nested `tod_adrenaline_recopy_unzipped/`): 4 files installed over the shipped names, no wiring needed. Verified per card against the source with ffmpeg PSNR — rows 0-820 and 1000-1152 identical (`inf`), only the 820-1000 text band differs.
> (Original request state below.) **REQUESTED 2026-09-05 (v17.85).** The behaviour shipped the same
> day; only the baked copy is stale. Four re-bakes, **same filenames**, so the
> install is a straight file swap — no GDT block, no zone line, no slug, no
> PLATE_MAX move. FULL build, prove with a fresh content-hash .iwi for each
> beside an untouched control.

## Why this exists

ADRENALINE (domain 25, SKIRMISHER, max 5) used to do two things, and the card
says so: `MULTI-KILLS GRANT / SPEED + DAMAGE`. As of v17.85 it does **three** —
the proc also HEALS the same percentage of max health it grants in speed and
damage (Lv1..Lv5 = 3/6/9/12/15%, DARK = 25%).

So the card is now **wrong on the art**, which is the one place a player reads
it that no code change can fix. User 2026-09-05: *"we need to update the asset.
Probably multi-kills gives buff or something. General copy."*

**The fix is deliberately GENERIC rather than a longer list.** `SPEED + DAMAGE`
was a list, and a list goes stale the moment the domain gains a fourth lane —
which is exactly what just happened. `A POWER SURGE` names the *shape* of the
effect and survives any future retune, matching the standing rule that a card
bakes no number and the pause menu carries every value.

**Line 1 does not change.** Only the second line of the value plate swaps, on
all four cards. That is the whole job.

## The pause plate is NOT in this pack

`i_tod_pause_r25.png` reads ADRENALINE and the domain name has not changed,
so it is untouched. Do not re-bake it.

<!-- PACK:BEGIN -->
# ADRENALINE — a one-line copy change on four existing cards

## What this is

A Call of Duty: Black Ops 3 zombies map has a deck of upgrade cards, drawn at
**213 x 320 px on screen** (see `preview_onscreen_213x320/` for what the player
actually sees). One upgrade in that deck — ADRENALINE — gained a third effect,
so the sentence printed at the bottom of its card is now out of date.

**This is not a new card. It is a re-bake of four cards you already have.**
The four attached images in `reference/` are the shipped originals. Reproduce
each one **exactly** — same title, same illustration, same colours, same
frame, same pips, same everything — and change **one line of text**.

## The change

The value plate at the bottom of each card holds two centred lines. Today:

```
MULTI-KILLS GRANT
SPEED + DAMAGE
```

It must become:

```
MULTI-KILLS GRANT
A POWER SURGE
```

**The first line is unchanged.** Only the second line is replaced, and it keeps
the identical typeface, weight, size, colour, outline, letter-spacing and
centring as the line it replaces. If `A POWER SURGE` sets narrower than
`SPEED + DAMAGE` (it will), keep the type at the SAME SIZE and let it be
narrower — do not stretch it to fill the plate, and do not re-size either line.

## Deliver exactly FOUR files

| Deliver as | Size | Source to match | Line 1 | Line 2 (the change) |
|---|---|---|---|---|
| `i_tod_card_adrenaline_regular.png` | 768 x 1152 | `reference/i_tod_card_adrenaline_regular.png` | `MULTI-KILLS GRANT` | `A POWER SURGE` |
| `i_tod_card_adrenaline_super.png` | 768 x 1152 | `reference/i_tod_card_adrenaline_super.png` | `MULTI-KILLS GRANT` | `A POWER SURGE` |
| `i_tod_card_adrenaline_ultimate.png` | 768 x 1152 | `reference/i_tod_card_adrenaline_ultimate.png` | `MULTI-KILLS GRANT` | `A POWER SURGE` |
| `i_tod_card_adrenaline_dark.png` | 768 x 1152 | `reference/i_tod_card_adrenaline_dark.png` | `MULTI-KILLS GRANT` | `A POWER SURGE` |

Same filenames as the sources — these replace the shipped files in place.
RGBA, **fully transparent background** (the card body sits on transparency and
does not fill the frame), same canvas size and same margins as the source.

## Hard rules

- **Nothing else may change.** Title plate, illustration (the three chevrons,
  the burst, the three skulls, the speed lines, the sparkles), rarity ribbon,
  star medal, rails, screws, scanlines, inner panel, pip row, glow, canvas
  size, margins — all identical to the source card.
- **Pips are per-rarity and must not move:** regular 1 lit of 5, super 2 of 5,
  ultimate 3 of 5, dark all 5 lit in red.
- **The colour treatment is per-rarity and must not move:** regular navy/blue,
  super purple, ultimate gold, dark red-on-black.
- **No number anywhere on the card.** Not in the new line, not in the panel.
- **Spell it exactly:** `MULTI-KILLS GRANT` / `A POWER SURGE`, all caps, the
  hyphen in MULTI-KILLS, no full stop.
- Do not add a third line. Do not re-flow the two lines into one.

## Paste-ready prompts

**Prompt A — regular.** *Attach `reference/i_tod_card_adrenaline_regular.png`.*

> Reproduce the attached game upgrade card exactly, at 768 x 1152 with a fully
> transparent background, changing ONE thing: in the dark value plate at the
> bottom, the second line of text currently reads SPEED + DAMAGE and must
> instead read A POWER SURGE. The first line, MULTI-KILLS GRANT, stays exactly
> as it is. Keep the new line in the identical typeface, weight, size, colour,
> outline and centring as the line it replaces — do not stretch it to fill the
> width. Everything else on the card must be faithful to the attachment: the
> ADRENALINE title plate, the illustration of three cyan chevrons with a burst
> and three white skulls, the REGULAR ribbon and star medal, the blue accent
> rails, the corner screws, the scanlines and the row of five pips with the
> first one lit. No numbers anywhere. Flat cartoon style, thick dark outlines,
> no photorealism.

**Prompt B — super.** *Attach `reference/i_tod_card_adrenaline_super.png`.*

> Same instruction as before, applied to this SUPER version of the card:
> reproduce the attachment exactly at 768 x 1152 with a transparent background,
> changing only the second line of the bottom value plate from SPEED + DAMAGE
> to A POWER SURGE, with MULTI-KILLS GRANT unchanged above it. Preserve the
> purple rails and ribbon, the SUPER ribbon text, the gold star medal, the
> super glow, and the pip row with TWO of five lit.

**Prompt C — ultimate.** *Attach `reference/i_tod_card_adrenaline_ultimate.png`.*

> Same instruction, applied to this ULTIMATE version: reproduce the attachment
> exactly at 768 x 1152 with a transparent background, changing only the second
> line of the bottom value plate from SPEED + DAMAGE to A POWER SURGE, with
> MULTI-KILLS GRANT unchanged above it. Preserve the gold rails and ribbon, the
> ULTIMATE ribbon text, the gold star medal, the sparkle glyphs, the ultimate
> glow, and the pip row with THREE of five lit.

**Prompt D — dark.** *Attach `reference/i_tod_card_adrenaline_dark.png`.*

> Same instruction, applied to this DARK version: reproduce the attachment
> exactly at 768 x 1152 with a transparent background, changing only the second
> line of the bottom value plate from SPEED + DAMAGE to A POWER SURGE, with
> MULTI-KILLS GRANT unchanged above it. Preserve the black card body, the red
> rails and outer glow, the red DARK UPGRADE ribbon, the red star medal, the
> purple-to-magenta illustration panel, and the row of FIVE red pips all lit.

## Delivery checklist

- [ ] Four PNGs, 768 x 1152, RGBA, transparent background
- [ ] Filenames exactly as the table above (same as the sources)
- [ ] Line 2 reads A POWER SURGE on all four; line 1 still MULTI-KILLS GRANT
- [ ] No number anywhere on any card
- [ ] Pips: 1 lit / 2 lit / 3 lit / 5 lit red
- [ ] Rarity colours unchanged: navy, purple, gold, red-on-black
- [ ] Overlay each output on its source — only the second text line differs

## Do NOT

- Do NOT redraw or restyle the illustration, the title plate or the frame
- Do NOT change the card size, margins or transparency
- Do NOT add a number, a percentage, a third line or a full stop
- Do NOT resize or re-weight either line of the value plate
- Do NOT deliver a pause-menu nameplate — the name has not changed
<!-- PACK:END -->
