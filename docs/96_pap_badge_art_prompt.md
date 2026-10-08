# 96 — THE PACK-A-PUNCH TIER BADGE (2 files → 4 images)

<!-- art-pack
name: pap_badge
refs:
  docs/96_pap_ref/badge_slot.png | THE BRIEF IN ONE PICTURE. The badge slot outlined in red, in place, at true 1080p size, over a dark AND a bright background, then magnified 6x — plus what is delivered. Attach to every prompt.
  docs/95_hud_ref/art_direction_board.png | THE ART DIRECTION on one page: the game, the palette sampled from the shipped files with hex values, three GOOD examples and three anti-examples, and the six rules. Attach to every prompt.
  i_tod_hud_offhand_tile.png | THE SIBLING PLATE, shipped and approved. The two tiles to the right of the new badge are this file. The new plate must look like the same hand made it on the same day. Attach to Prompt A.
  i_tod_hud_off_frag.png | THE SIBLING GLYPH, shipped and approved: flat, two tones, thick hard outline, drawn for 36x36. Attach to Prompt B.
  docs/95_hud_ref/house_style_points_icon.png | THE HOUSE GLYPH STYLE at its clearest — flat, two tones, hard dark outline, zero gradient. Attach to Prompt B.
  i_tod_hud_pap_tile.png | THE PLACEHOLDER PLATE being replaced. Correct size and palette, deliberately plain. Attach to Prompt A.
  i_tod_hud_pap_1.png | THE PLACEHOLDER NUMERAL I being replaced. Attach to Prompt B.
  i_tod_hud_pap_2.png | THE PLACEHOLDER NUMERAL II being replaced. Attach to Prompt B.
  i_tod_hud_pap_3.png | THE PLACEHOLDER NUMERAL III being replaced. Attach to Prompt B.
  docs/95_hud_ref/world_cover.png | the map's own cover art: the neon tower, the purple night city, the flat-vector-with-hard-outline look everything sits in. Attach to every prompt.
preview: 69x48 36x36
-->

> **SUPERSEDED BY docs/102 (2026-09-04, later the same day).** The user's
> verdict on the numeral-only badge: *"we have cymbal monkeys, grenades,
> spiders in the HUD but no pap icon image."* docs/102 re-commissions the
> badge as EMBLEM + game-drawn numeral: its plate spec is this doc's, verbatim;
> the numeral sheet below is DROPPED. If this pack's drop still arrives, keep
> the plate and discard the sheet. Do not send this pack again.
>
> **(Original) STATUS: WIRED AND SHIPPING ON PLACEHOLDER ART (v17.33, 2026-09-04).** The
> badge is live, packed and testable right now — `TOD_PAP_ART` is `true` and the
> four images are zoned. What ships is
> `tools/gen_pap_badge_placeholder.js`'s output: flat navy plate, cyan keyline,
> numerals as thick steel bars. Correct in every measurable way and plain on
> purpose. **This drop replaces those four files under the same names, so
> installing it is a file copy plus `node tools/slice_hud_sheets.js` — no
> wiring, no flag, no Lua.**

**Why (user, 2026-09-04):** *"we need to update the HUD to add some section that
tells your pap level. So this include pap I. We would need new icons as well."*

## What the badge reports

The Endless Spire's Pack-a-Punch machines sell two re-packs beyond the ordinary
one: **PACK II at 25,000** and **PACK III at 50,000**, each worth +50% damage,
and each handing back **the same weapon** rather than a new one. That is the
whole problem this badge solves — a 50,000-point upgrade with no visible
difference on the gun, the model, the name or the ammo counter. The badge is the
only place a player ever sees what they bought.

So it is read *often* and it is read *at a glance*, and the three levels have to
be distinguishable from each other across a room. It is drawn at **69 × 48
physical pixels**.

## Geometry (all boxes on the 1280×720 LUI canvas, ×1.5 = 1080p)

| slot | canvas box | @1080p | source | art |
|---|---|---|---|---|
| badge plate | 1012..1058 × 568..600 | 69 × 48 | 276×192 | `i_tod_hud_pap_tile` |
| badge numeral | 1017..1041 × 572..596 | 36 × 36 | 128×128 | pap sheet, 3 cells |

Both aspects are exact — plate 46/32 = 276/192 = 1.4375, numeral 24/24 =
128/128 = 1.0. **Zero stretch on either**, which is the defect docs/89 and
docs/95 were both written to kill. The plate box is byte-identical to an offhand
tile's and the numeral box to an offhand glyph's, deliberately: the corner is one
component set.

**y568 is a hard ceiling.** The tower gauge's foot is at y566 in an overlay that
draws *on top of* this HUD, so nothing here may grow upward and no shadow may
bleed above the plate's own canvas.

## Runtime facts the art must survive

- **The plate is ONE FILE for all three levels.** The numeral carries the level.
- **Neither is ever runtime-tinted.** Both draw at `setRGB(1,1,1)`, full alpha.
  Whatever colour is baked in is what appears.
- **There is no empty or dimmed state.** At pack level 0 both elements are
  hidden outright. Unlike the offhand tiles, this never draws at 40%.
- **Nothing is wipe-clipped**, so detail across the width is free.

## The one thing that could go wrong

**It must not read as a third equipment slot.** It sits on the same row as the
tactical and lethal tiles, at the same size, in the same palette — and those two
are *counters*. Three identical plates in a row reads as "3 of something". The
placeholder's answer is a cyan rule along the top edge and two bottom corner
notches: enough asymmetry to mark it as a status plate, not an inventory slot.
The commission can solve it differently but it must solve it.

The second constraint is the user's explicit call: **stay in the palette.** No
gold for tier III, no violet for tier II. The escalation is carried by the
numeral and by how much of the plate the ink occupies, not by hue.

<!-- PACK:BEGIN -->
# GAME HUD — A PACK LEVEL BADGE (2 files → 4 images)

## Start here

**Open `badge_slot.png` first.** It is the whole brief in one picture: the slot
outlined in red, in place, at true size, over a dark and a bright background,
then magnified six times, with a table of what to deliver.

**Then open `art_direction_board.png` and read all of it.** It is the art
direction for this HUD on one page — the game, the exact palette sampled out of
the shipped files, three good examples with what makes them good, three
anti-examples, and six rules. Everything below assumes you have read it.

## What this is

The bottom-right corner of the heads-up display of a custom Call of Duty:
Black Ops III zombies map. The map is a fifty-floor neon tower in a purple night
city; the player climbs an open staircase spiralling around the *outside* of it
while an endless horde chases them.

This one small plate reports **how many times the player has upgraded the
weapon they are holding** — level I, II or III. In the game, levels II and III
cost 25,000 and 50,000 points and give the player back *the same gun*, looking
exactly as it did before. This badge is the only thing on screen that shows what
that money bought. It has to feel worth it.

It sits immediately to the left of two existing equipment tiles, and directly
above the picture of the gun.

## The three rules that matter more than anything else

1. **DRAW FOR THE SIZE IT IS SHOWN, NOT THE SIZE OF YOUR CANVAS.** The plate is
   shown at **69 × 48 pixels** and the numeral inside it at **36 × 36**. You are
   drawing them at 276 × 192 and 128 × 128. Few shapes, thick strokes, huge
   contrast. Nothing narrower than about **6 px on your canvas**; if a detail
   would be under 10 px, delete it rather than shrink it.

2. **FLAT. ALWAYS.** No bevel, no extrusion, no gloss, no gradient ramps, no
   chrome, no photographic texture, no bloom, no glow. Two flat tones per
   element: a face, and one darker tone used only as a hard-edged offset.

3. **IT MUST READ ON A BRIGHT BACKGROUND.** Look at the right-hand half of
   `badge_slot.png`. Anything pale with no dark edge disappears against the fog.
   Every piece needs a hard near-black outline.

## The palette — do not invent colours

| hex | name | use |
|---|---|---|
| `#E8EEF6` | STEEL WHITE | the numeral face |
| `#5BC8FF` | ELECTRIC CYAN | keylines, edges, rules |
| `#33D9FF` | BRIGHT CYAN | the hottest accent, used sparingly |
| `#131B38` | DEEP NAVY | the plate body |
| `#0A1020` | OUTLINE BLACK | the hard outline around everything |

**No gold, no violet, no orange, no red, no green.** This was asked for
explicitly and then decided against: the three levels must escalate **within**
this palette. Red in particular is reserved — the game flashes the ammo numerals
red at low ammo, and a red badge one row up would read as that warning.

## Deliver exactly TWO files

| filename | canvas | what it is |
|---|---|---|
| `i_tod_hud_pap_tile.png` | **276 × 192** | the plate. ONE file, used behind all three numerals. |
| `i_tod_hud_pap_sheet.png` | **384 × 128** | ONE row of **three** 128 × 128 cells: the numerals **I**, **II**, **III**, in that order. |

PNG, RGBA, transparent where nothing is drawn. Exact pixel dimensions — the
sheet is cut into its three cells by arithmetic, so a canvas two pixels wide of
384 slices every cell wrong.

**The sheet must be drawn as one image in one pass.** That is the entire reason
it is a sheet and not three files: three numerals generated three times come back
with three stroke weights and three light directions, and the escalation
I → II → III only reads if they share one. Draw the row, then check it as a row.

---

## PROMPT A — the plate

*Attach: `badge_slot.png`, `art_direction_board.png`, `i_tod_hud_offhand_tile.png`,
`i_tod_hud_pap_tile.png`, `world_cover.png`*

> A single flat UI plate for a science-fiction video-game heads-up display,
> drawn on a 276 × 192 transparent canvas and shown to the player at 69 × 48
> pixels.
>
> It is a small status plate: a dark navy body (`#131B38`), a hard near-black
> outline (`#0A1020`) around the whole silhouette, and a crisp electric-cyan
> keyline (`#5BC8FF`). Slightly rounded or chamfered corners. Completely flat —
> two tones only, no bevel, no gloss, no gradient, no glow, no texture.
>
> Match `i_tod_hud_offhand_tile.png` exactly in weight, corner treatment, outline
> thickness and palette — it is the neighbouring plate in the same corner of the
> same HUD and the two are seen together constantly.
>
> **But it must not be mistaken for it.** The neighbouring plates are equipment
> counters; this one is a status badge. Give it one clear, deliberate difference
> that reads at 69 × 48 — a bright rule along one edge, a clipped corner, a
> notch, a bracket. One difference, not three.
>
> The middle of the plate must stay dark and calm: a bright white numeral is
> drawn on top of it and must stay legible.
>
> Flat vector, hard edges, high contrast, no perspective, no shadow inside the
> canvas.

## PROMPT B — the three numerals

*Attach: `badge_slot.png`, `art_direction_board.png`, `house_style_points_icon.png`,
`i_tod_hud_off_frag.png`, `i_tod_hud_pap_1.png`, `i_tod_hud_pap_2.png`,
`i_tod_hud_pap_3.png`*

> One image, 384 × 128 pixels, transparent background, divided into three equal
> cells of 128 × 128. Draw one Roman numeral in each cell, centred: **I** in the
> first, **II** in the second, **III** in the third. Each is shown to the player
> at 36 × 36 pixels.
>
> Style: flat, two tones, steel-white faces (`#E8EEF6`) with a hard near-black
> offset (`#0A1020`) and electric-cyan accents (`#5BC8FF`). Match
> `house_style_points_icon.png` and `i_tod_hud_off_frag.png` — same stroke
> weight, same outline thickness, same complete absence of gradient.
>
> These are numerals for a machine, not for a book. Draw them as **thick solid
> bars**, not as a typeface — heavy, blunt, and unmistakable at 36 pixels. Give
> the bars a small consistent cap and foot detail if it helps them read as
> deliberate marks rather than plain rectangles.
>
> **The three must feel like a ladder that goes UP.** The player pays 25,000
> points to go from I to II and 50,000 to reach III, so III has to look like the
> most expensive thing on the screen — more ink, more accent, more presence.
> Carry that entirely through weight, fill and detail. **Do not change the hue
> between levels**: no gold, no violet, no orange. All three live in the same
> steel-white and cyan palette.
>
> **All three must occupy the same optical area and sit on the same baseline.**
> The badge is redrawn in place when a player buys an upgrade, and a numeral that
> is taller or lower than the last one makes the whole plate visibly jump. Keep
> the ink inside a shared box in every cell — as a guide, roughly 84 × 76 pixels
> centred in the 128 × 128 cell — and let the bars get narrower as the count
> rises so the group keeps one mass rather than growing wider.
>
> Nothing may cross a cell boundary. Leave clear transparent margins.

---

## Delivery checklist

- [ ] `i_tod_hud_pap_tile.png` is **exactly 276 × 192**, RGBA, transparent
      outside the plate.
- [ ] `i_tod_hud_pap_sheet.png` is **exactly 384 × 128**, RGBA.
- [ ] The sheet is **three cells of 128 × 128**, in the order **I, II, III**.
- [ ] No drawing crosses a cell boundary.
- [ ] All three numerals share one baseline and one optical mass.
- [ ] Every element has a hard near-black outline and reads against the bright
      half of `badge_slot.png`.
- [ ] Palette only: `#E8EEF6`, `#5BC8FF`, `#33D9FF`, `#131B38`, `#0A1020`.
- [ ] The plate reads as a **status badge**, not as a third equipment slot.
- [ ] Nothing is a gradient, a bevel, a glow or a photograph.

## Do NOT

- Do not add gold, violet, orange, red or green anywhere, at any level.
- Do not put a fist, a hand, a gun or any pictorial symbol in the numeral cells —
  at 36 × 36 the numeral needs the whole cell.
- Do not deliver the three numerals as three separate files.
- Do not draw text, labels, borders, watermarks, drop shadows outside the
  silhouette, or a background behind the transparent areas.
- Do not resize, pad or crop the two canvases to "nicer" numbers.
- Do not make level I look broken or unfinished. It is what every player has for
  most of the game; it should look like an achievement too, just the smallest one.
<!-- PACK:END -->
