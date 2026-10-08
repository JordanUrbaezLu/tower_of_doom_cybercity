# 57 — ATHLETE card art prompt (domain 43: slide faster, jump higher)

> **STATUS: COMPLETE 2026-09-01.** Code shipped v16 and the art landed the same
> day (user drop `files (79).zip`). All four images installed and WIRED — 4 GDT
> blocks, 4 zone lines, `CARD_SLUG[43] = "athlete"`, `PAUSE_PLATE_MAX` 42 -> 43.
> Packing proven: 4 fresh content-hash `.iwi` with luck/cleave/vitality as
> untouched controls. FULL build, `.ff` 115.54 MB @ 03:39:20.
> **ATHLETE was the LAST text-only card — all 34 live domains now have art.**
> The prompts below are kept as the record of what was asked for.

## The domain

- **Key** `athlete`, id **43**, **SLASHER only**, band **A**, **max 5**,
  scope `class` (survives tier promotions).
- **Effect:** +10% slide speed and +25% jump height **per level**.
  Lv5 = +50% slide speed, 2.25× jump height.
- Fills the mobility slot the retired chain lunge (id 22) left in the kit.

## ⚠️ READ THIS BEFORE WRITING A PROMPT: the numbers are NOT on the card

The house rule from [`docs/33`](33_upgrade_art_audit.md) and the
`domain-retune-checklist` memory is that **card art carries baked-in numbers, so
a domain retune is not finished until the card is re-baked.** The escape from
that trap is to make the card **level-agnostic**, and ATHLETE has a specific
reason it must be:

**It carries TWO ladders (10%/Lv and 25%/Lv), and they are different numbers.**
Any card that prints one of them is wrong about the other, and a card that
prints both is doing the pause menu's job in a space that cannot hold it. So:

> **NO NUMBERS ANYWHERE ON THESE CARDS.** Not "+25%", not "+10%", not "Lv 3".
> The pause menu shows the live values (`DETAIL[43]` renders
> `+30% slide, +75% jump` and recomputes per level). The card shows the IDEA.

This also means a future retune of either number needs **no re-bake** — the same
protection FORCED MARCH got by going linear-and-generic.

## Pip count

**5 pips** (max = 5). Per the checklist: pips = MAX when max <= 6, else a flat 3.
- `_regular` → 1 lit · `_super` → 2 lit · `_ultimate` → 3 lit.
- Rarity pays +1/+2/+3 levels, so ULTIMATE lights 3 of 5. All five pips are drawn
  on all three cards; only the lit count changes.

## Accent colour

**SLASHER accent** — match the existing slasher cards (CLEAVE, LEECH, THOR'S
THUNDER, KNIFE SPEED, DRAW CUT). **Open one of those PNGs and sample it; do not
take a colour from this document.** The `perk-icon-set-is-circles` memory's rule
applies: the source of truth is the pixels in `source_data/tod_ui_images/`, and
prose about art in this repo has been stale before.

---

## PROMPT 1 — explore (run this first, pick a direction, then build out)

> Four thumbnail concepts on one sheet, 2×2 grid, for a **video-game ability
> card** called **ATHLETE**. Cyberpunk neon-noir, dark navy/black background,
> glowing edge light. The ability is **superhuman agility: sliding fast along
> the ground and jumping very high.** Vertical card format, 2:3.
>
> Vary the four by IDEA, not by palette:
> 1. a lone figure mid-**slide**, low to the ground, long motion streaks trailing
>    behind, sparks where the knee grazes the deck
> 2. the same figure at the **apex of a huge jump**, silhouetted against a
>    glowing city skyline far below, arms out
> 3. a **stylised motion diagram** — a single continuous neon line that slides
>    flat, then arcs up and over an obstacle, drawn like a route on a HUD
> 4. a **chevron/arrow motif** — stacked speed chevrons pointing forward and a
>    second set pointing up, forming an abstract "athlete" glyph, no figure
>
> No text, no numbers, no UI chrome, no border. Just the four illustration
> concepts.

## PROMPT 2 — build out (after a direction is chosen)

Replace `<CHOSEN CONCEPT>` with the winner from prompt 1, and
`<SLASHER ACCENT>` with the colour sampled from an existing slasher card.

> A vertical **video-game upgrade card**, 768 × 1152 px, cyberpunk neon-noir.
>
> **ART:** <CHOSEN CONCEPT>. The subject reads instantly at thumbnail size —
> one clear silhouette, strong rim light, no fine detail that dissolves when the
> card is small. Dark navy-to-black background with a subtle glowing floor grid.
> Primary accent glow: <SLASHER ACCENT>. Secondary: cool white speed streaks.
>
> **TITLE:** the single word **`ATHLETE`** across the lower third, all caps, one
> line, chunky white bubble letters with a heavy dark outline, sized to fill the
> width with a comfortable margin. Correctly spelled. No other text of any kind.
>
> **PIPS:** a row of **5 small diamond pips** centred just below the title.
> <N> lit and glowing in <SLASHER ACCENT>; the rest dark, empty outlines.
>
> **NO NUMBERS, NO PERCENTAGES, NO LEVEL TEXT, NO SUBTITLE, NO DESCRIPTION
> LINE.** The card is title + art + pips only.
>
> Flat front-on view, no perspective, no drop shadow outside the card, no
> border frame, transparent-safe edges. Deliver as a clean PNG.

Run it three times, changing only `<N>`:

| file | size | pips |
|---|---|---|
| `i_tod_card_athlete_regular.png` | 768 × 1152 | 5 pips, **1 lit** |
| `i_tod_card_athlete_super.png` | 768 × 1152 | 5 pips, **2 lit** |
| `i_tod_card_athlete_ultimate.png` | 768 × 1152 | 5 pips, **3 lit** |

## PROMPT 3 — the pause plate

> A small horizontal **UI name plate**, 300 × 44 px, for a cyberpunk game pause
> menu. Dark translucent slab with a thin glowing <SLASHER ACCENT> left edge.
> The word **`ATHLETE`** in clean condensed white caps, vertically centred,
> left-aligned with a small margin. A tiny <CHOSEN MOTIF> glyph at the right
> edge. Nothing else — no numbers, no border, no shadow.

File: `i_tod_pause_r43.png`, **300 × 44**.

## Install order (do NOT reorder — steps 4 and 5 are the trap)

1. Drop the four PNGs into `source_data/tod_ui_images/_images/`.
2. Add a GDT block per image in `source_data/tod_ui_images.gdt` (copy an
   existing card block, change the name and path).
3. Add four `image,` lines to `zone_source/zm_tower_of_doom.zone`.
4. **Only now** `CARD_SLUG[43] = "athlete"` in `tod_upgrade.lua` —
   `RegisterImage` on an image that is not yet zoned is undefined behaviour here.
5. **Only now** bump `PAUSE_PLATE_MAX` 42 → **43**. It is a `<=` test over a
   **contiguous** range, so 43 may only be claimed once `i_tod_pause_r43` exists
   and is zoned. (The 9c session hit exactly this tonight claiming 42.)
6. **FULL build** — a `.gdt` edit is always a full build, never `-GscOnly`.
7. Verify packing by fresh content-hash `.iwi` **plus an untouched control**
   (memory: `verify-assets-in-artifacts`). A `.ff` raw grep is invalid.

## Proofread checklist

- [ ] title reads `ATHLETE`, spelled right, one line, identical on all three
- [ ] **zero** numbers or percentages anywhere on any of the three
- [ ] 5 pips drawn on all three; 1 / 2 / 3 lit respectively
- [ ] accent matches a real slasher card (sampled, not assumed)
- [ ] all three 768 × 1152; the plate 300 × 44
- [ ] silhouette still readable shrunk to ~120 px wide

---

## v16.23 addendum (2026-09-02) — AIR STEERING joined the domain; the card STAYS

The domain now does three things per level: +10% slide speed, +25% jump height
and 360 deg/s of air steering (turn your velocity toward the stick in mid-air,
speed unchanged). The card was deliberately baked **level-agnostic and
numberless** ("superhuman agility: sliding fast, jumping high"), so it is not
wrong — a mid-air direction change is the same idea — and it needs NO re-bake
for the numbers. The pause row carries the live values (`DETAIL[43]`: val =
slide/jump, act = "air steer N deg/s").

If the user wants the art to SHOW the new half of the ability, this is the
re-bake prompt (same install order as above, same three files, same pips):

> A vertical **video-game upgrade card**, 768 × 1152 px, cyberpunk neon-noir.
> **ART:** a lone figure at the apex of a huge jump, silhouetted against a
> glowing city skyline far below — and the motion trail behind them **bends
> sharply in mid-air**: a single continuous neon ribbon that slides flat along
> the deck, launches, then **hooks 90 degrees** at the top of the arc, drawn
> like a route on a HUD. The bend is the subject. One clear silhouette, strong
> rim light, no fine detail that dissolves at thumbnail size. Dark navy-to-black
> background with a subtle glowing floor grid. Primary accent glow: <SLASHER
> ACCENT>. Secondary: cool white speed streaks.
> **TITLE:** the single word **`ATHLETE`** across the lower third, all caps, one
> line, chunky white bubble letters with a heavy dark outline. Correctly
> spelled. No other text of any kind.
> **PIPS:** a row of **5 small diamond pips** centred just below the title,
> <N> lit and glowing in <SLASHER ACCENT>; the rest dark, empty outlines.
> **NO NUMBERS, NO PERCENTAGES, NO LEVEL TEXT, NO SUBTITLE.** Flat front-on
> view, no drop shadow outside the card, no border frame. Clean PNG.

Optional. Nothing in the build waits on it.

---

## v16.34 addendum (2026-09-02) — the card goes GENERAL: four grants, one idea

User: *"This means we need to update the athlete assets I think ... our asset should be quite general now that this grants like 4 different things. Create a zip with instruction for my llm asset generator ... include the existing assets so they can use that as a template."*

Delivered as `~/Downloads/athlete_assets_v2.zip` (the brief below, the four current PNGs as the template, and `i_tod_card_cleave_regular.png` as the accent reference). The install order and the proofread checklist above still apply to the returned files; the only text on any asset stays the single word ATHLETE.

### The brief, verbatim

# ATHLETE — asset refresh brief (v2)

Four images to redraw for the video-game upgrade card **ATHLETE** in a cyberpunk
zombies map. The current four are in this folder as the TEMPLATE: keep their
layout, framing, title treatment, pip row and colour language; change the ART
CONTENT. One extra file, `REFERENCE_slasher_accent_cleave_regular.png`, is a
sibling card from the same class — sample the accent glow colour from it and
from the current athlete cards; do not invent a new palette.

## Why the redraw

The upgrade used to mean two things (slide faster, jump higher). It now grants
FOUR, and the card has to read as one general idea:

> **ATHLETE = superhuman agility.** Slide faster. Jump higher. Steer your
> momentum in mid-air. Run along walls.

The old art shows a figure sliding or leaping. The new art should show a body
that owns the air and the walls — parkour, not a single move. Think: a figure
mid wall-run on a neon-lit vertical surface with a motion trail that bends,
or a figure launching off a wall into a curved leap over a skyline. The bend
in the trail and the contact with a wall are the two new ideas; the slide and
the height can stay implied.

## Hard rules (these are enforced by the game's UI, not taste)

1. **NO NUMBERS, NO PERCENTAGES, NO LEVEL TEXT, NO SUBTITLE, NO DESCRIPTION
   LINE.** The game shows the live values elsewhere; a number baked into art
   goes stale. The card is title + art + pips only.
2. **The only text is the single word `ATHLETE`**, all caps, one line, chunky
   white bubble letters with a heavy dark outline, across the lower third,
   sized to fill the width with a comfortable margin, correctly spelled,
   identical on all three cards. (The pause plate carries the same word, once.)
3. **Pips:** a row of **5 small diamond pips** centred just below the title,
   drawn on all three cards. Lit count differs per file (below); unlit pips are
   dark empty outlines. Lit pips glow in the class accent.
4. **Sizes:** the three cards **768 × 1152** (vertical 2:3); the pause plate
   **300 × 44**. Flat front-on view, no perspective, no drop shadow outside the
   image, no border frame, transparent-safe edges. Clean PNG.
5. **Readability at thumbnail size:** one clear silhouette, strong rim light,
   no fine detail that dissolves when the card is ~120 px wide.
6. **Match the template:** same title band position and size, same pip row
   position, same dark navy-to-black background with the subtle glowing floor
   grid, same accent glow family. Someone flipping between the old and new
   card should see the same card with better art.

## Files to deliver (exact names)

| file | size | pips lit | note |
|---|---|---|---|
| `i_tod_card_athlete_regular.png` | 768 × 1152 | 1 of 5 | |
| `i_tod_card_athlete_super.png` | 768 × 1152 | 2 of 5 | same art, only the lit count changes |
| `i_tod_card_athlete_ultimate.png` | 768 × 1152 | 3 of 5 | same art, only the lit count changes |
| `i_tod_pause_r43.png` | 300 × 44 | — | the pause-menu name plate |

Deliver all four in one zip.

## Prompt 1 — explore (run first, pick a direction)

> Four thumbnail concepts on one sheet, 2×2 grid, for a video-game ability
> card called **ATHLETE**. Cyberpunk neon-noir, dark navy/black background,
> glowing edge light. The ability is **superhuman agility: sliding fast,
> leaping high, steering in mid-air, and running along walls.** Vertical card
> format, 2:3. Vary the four by IDEA, not by palette:
> 1. a lone figure mid **wall-run** on a tall neon-lit wall, body horizontal,
>    one hand brushing the surface, a long motion trail behind
> 2. a figure **launching off a wall** into a high arcing leap over a glowing
>    city skyline far below, arms out
> 3. a stylised **motion diagram**: one continuous neon ribbon that slides
>    flat, kicks up a wall, and bends sharply in the air, drawn like a HUD route
> 4. an abstract **glyph**: stacked speed chevrons forward, a vertical bar
>    for the wall, and a curved arrow over it — no figure
> No text, no numbers, no UI chrome, no border. Just the four illustration
> concepts.

## Prompt 2 — build out (after a direction is chosen)

Replace `<CHOSEN CONCEPT>` with the winner and `<ACCENT>` with the colour
sampled from the attached cards.

> A vertical **video-game upgrade card**, 768 × 1152 px, cyberpunk neon-noir,
> laid out exactly like the attached template card.
> **ART:** <CHOSEN CONCEPT>. The subject reads instantly at thumbnail size —
> one clear silhouette, strong rim light, no fine detail that dissolves when
> the card is small. Dark navy-to-black background with a subtle glowing
> floor grid. Primary accent glow: <ACCENT>. Secondary: cool white speed
> streaks. The wall the figure touches is a clean vertical neon surface.
> **TITLE:** the single word **`ATHLETE`** across the lower third, all caps,
> one line, chunky white bubble letters with a heavy dark outline, sized to
> fill the width with a comfortable margin. Correctly spelled. No other text
> of any kind.
> **PIPS:** a row of **5 small diamond pips** centred just below the title,
> <N> lit and glowing in <ACCENT>; the rest dark, empty outlines.
> **NO NUMBERS, NO PERCENTAGES, NO LEVEL TEXT, NO SUBTITLE, NO DESCRIPTION
> LINE.** The card is title + art + pips only.
> Flat front-on view, no perspective, no drop shadow outside the card, no
> border frame, transparent-safe edges. Deliver as a clean PNG.

Run it three times changing only `<N>` = 1, 2, 3 for regular / super /
ultimate. Keep the art identical across the three (same seed / same base
image, only the lit pips change).

## Prompt 3 — the pause plate

> A small horizontal **UI name plate**, 300 × 44 px, for a cyberpunk game
> pause menu, laid out exactly like the attached `i_tod_pause_r43.png`. Dark
> translucent slab with a thin glowing <ACCENT> left edge. The word
> **`ATHLETE`** in clean condensed white caps, vertically centred,
> left-aligned with a small margin. A tiny glyph of a figure mid wall-run (or
> the chosen motif) at the right edge. Nothing else — no numbers, no border,
> no shadow.

## Proofread before sending

- [ ] title reads `ATHLETE`, spelled right, one line, identical on all three
- [ ] zero numbers or percentages anywhere on any of the four
- [ ] 5 pips drawn on all three cards; 1 / 2 / 3 lit respectively
- [ ] accent sampled from the attached cards, not invented
- [ ] all three cards 768 × 1152; the plate 300 × 44
- [ ] silhouette still readable shrunk to ~120 px wide
- [ ] the art says "agile body, walls and air", not "one specific move"

### Card text decided (v16.36, user: "im asking for description text on the card")

The brief above was updated in the zip before it was handed over. Exact copy, identical on all three cards, numberless so no ladder change can stale it:

- Title: `ATHLETE`
- Tagline (small wide-spaced caps in the accent, under the title): `SUPERHUMAN AGILITY`
- Description (bottom plate under the pips, one or two short lines): `Slide faster. Jump higher. Steer mid-air. Run the walls.`
- Footer (optional, tiny, pale): `Grows with every level.`
- Pause plate: `ATHLETE` only.

This is a deliberate exception to docs/40 (which stripped sublines because they carried NUMBERS): a numberless description line cannot go stale.

### Card text, final (user: "make this super generic. Its too much on the card")

Two lines only, identical on all three cards, no tagline, no footer:

- Title: `ATHLETE`
- Description (one line on the bottom plate under the pips): `Unmatched mobility.`
- Pause plate: `ATHLETE` only.

The four-beat line above is withdrawn. The zip in Downloads was re-packed with this copy.

> **v2 ART LANDED 2026-09-02 (user drop `files (97).zip`, nested `tod_athlete_v2.zip`).** All four installed over the v1 files (same names, so the GDT blocks and zone lines are unchanged): the wall-run figure with a bending trail, title ATHLETE, the rarity plates, description UNMATCHED MOBILITY, five round pips lit 1/2/3, 768 × 1152; the plate ATHLETE + a running-figure glyph, 300 × 44. Proofread against the brief: pass. FULL build v16.36; packing proof = fresh content-hash `.iwi` in `<tools>/share/assetconvert/image/v29/` for the four, with `i_tod_card_cleave_regular` as the untouched control (see the CHANGELOG entry).
