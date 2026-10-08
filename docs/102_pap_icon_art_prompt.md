# 102 — THE PACK-A-PUNCH ICON (2 files → 2 images) — supersedes docs/96

<!-- art-pack
name: pap_icon
refs:
  docs/102_pap_ref/icon_slot.png | THE BRIEF IN ONE PICTURE. The badge in place at true 1080p size over a dark AND a bright background, the icon box ringed in red, the plate ringed dashed, then magnified 6x — plus what is delivered. Attach to every prompt.
  docs/95_hud_ref/art_direction_board.png | THE ART DIRECTION on one page: the game, the palette sampled from the shipped files with hex values, three GOOD examples and three anti-examples, and the six rules. Attach to every prompt.
  i_tod_hud_off_monkey.png | SIBLING GLYPH 1, shipped and approved: the cymbal monkey. Same 128x128 cell, same 36x36 on screen, same thick outline. Attach to Prompt A.
  i_tod_hud_off_frag.png | SIBLING GLYPH 2, shipped and approved: the frag grenade. Flat, two tones, hard outline. Attach to Prompt A.
  i_tod_hud_off_spider.png | SIBLING GLYPH 3, shipped and approved: the Widow's Wine spider. The most detailed glyph that still reads at 36x36 — the ceiling of allowed detail. Attach to Prompt A.
  i_tod_pu2_free_pap.png | THE SUBJECT, NOT THE STYLE. The map's own Pack-a-Punch power-up icon: a fist and a lightning bolt. This is what the emblem depicts. It is in the WRONG style — gradient, yellow — do not copy the rendering. Attach to Prompt A.
  docs/95_hud_ref/house_style_points_icon.png | THE HOUSE GLYPH STYLE at its clearest — flat, two tones, hard dark outline, zero gradient. Attach to Prompt A.
  i_tod_hud_offhand_tile.png | THE SIBLING PLATE, shipped and approved: the tile under the monkey and the grenade. The new plate must look like the same hand made it on the same day. Attach to Prompt B.
  i_tod_hud_pap_tile.png | THE PLACEHOLDER PLATE being replaced. Correct size and palette, deliberately plain. Attach to Prompt B.
  docs/95_hud_ref/world_cover.png | the map's own cover art: the neon tower, the purple night city, the flat-vector-with-hard-outline look everything sits in. Attach to every prompt.
preview: 36x36 69x48
-->

> **STATUS: DROP INSTALLED v17.60 (2026-09-04 22:19 drop) — BUILD PENDING,
> UNPLAYED.** The generator returned something better than the order: NOT one
> fist-and-bolt emblem plus a plate, but THREE level variants of a Pack-a-Punch
> MACHINE glyph with 1 / 2 / 3 bolts (`i_tod_hud_pap_icon_1..3`, 128×128 RGBA,
> flat, palette, hard outline — matches the monkey and the grenade) and a
> review sheet (`docs/102_pap_ref/delivered_review.png`) showing them on the
> placeholder plate beside a game-drawn digit. No plate was delivered; the
> placeholder plate stays. Installed under the EXISTING names
> `i_tod_hud_pap_1..3` (same names = no zone/GDT wiring; the "retire the
> numerals" step below is therefore moot — the cells are REPLACED, and the
> `i_tod_hud_pap_sheet` slicer entry stays valid for a future sheet drop).
> The Lua now draws the level as a DIGIT at the offhand count metrics beside
> the glyph (a single digit is all that lane holds; roman "III" does not fit).
> **The plate landed separately via docs/103 (v17.68, 2026-09-05).**
>
> **(Original) STATUS: COMMISSIONED 2026-09-04 — NOT WIRED.** Pack built by
> `.\tools\make_art_pack.ps1 docs\102_pap_icon_art_prompt.md` →
> `~/Downloads/tod_pap_icon_art_pack.zip`. This doc SUPERSEDES docs/96 (the
> plate + Roman-numeral sheet commission, which went out 2026-09-04 14:39 and
> had not come back when this was written): its plate spec is folded in here
> unchanged, its numeral sheet is DROPPED. If the docs/96 drop still arrives,
> use its plate and discard its sheet.

**Why (user, 2026-09-04):** *"One area where we are weak are pap icons. We have
cymbal monkeys, grenades, spiders, in the HUD but no pap icon image."*

## What changes on the HUD

Today the badge is a plate with a bare Roman numeral in it (placeholder art
from `tools/gen_pap_badge_placeholder.js`). Every other tile in that corner is
a PICTURE of the thing plus a NUMBER — monkey + count, grenade + count. The
badge becomes the same component: the Pack-a-Punch EMBLEM in the 24×24 glyph
box, and the level (I / II / III) as a numeral at the offhand count position,
drawn by the game's own baked typeface — exactly the `pap_row` fallback lane
that already exists in `AetheriumLoadout.lua` behind `TOD_PAP_ART = false`.

So the order is ONE new image plus the plate; the three numeral cells retire.

## Geometry (1280×720 LUI canvas, ×1.5 = 1080p)

| slot | canvas box | @1080p | source | art |
|---|---|---|---|---|
| badge plate | 1012..1058 × 568..600 | 69 × 48 | 276×192 | `i_tod_hud_pap_tile` |
| badge icon | 1017..1041 × 572..596 | 36 × 36 | 128×128 | `i_tod_hud_pap_icon` (NEW) |
| level numeral | right edge 1055, baseline 592, cap 12 | typeface | — | `todMakeGlyphRow` (no art) |

Zero stretch on either image. The icon box and the plate box are byte-identical
to an offhand slot's (`makeOffhandSlot`), on purpose: the corner is one
component set. **y568 is a hard ceiling** — the tower gauge's foot is at y566.

## Install (when the drop comes back) — a Lua edit, then a FULL build

1. `-Inspect` the drop; LOOK at both files; check the icon leaves its right
   third clear enough for the numeral (the plate's right third is where the
   count lives).
2. Copy `i_tod_hud_pap_icon.png` + `i_tod_hud_pap_tile.png` into
   `source_data/tod_ui_images/_images/`. New name = GDT block + `image,` zone
   line for `i_tod_hud_pap_icon` (beside the four `i_tod_hud_pap_*` lines);
   `lint_tod_assets.js` GATE A catches a miss.
3. `AetheriumLoadout.lua` badge block: `pap_glyph` takes `i_tod_hud_pap_icon`
   once at construction; `setPapTier` always draws the level through `pap_row`
   at the OFFHAND count metrics (`PAP_X + 43`, cap 12, baseline 592 — the
   `makeOffhandSlot` values, not the 40/14 the fallback used, so the badge's
   number sits exactly where the monkey's does). `PAP_IMG` and the three
   `RegisterImage( "i_tod_hud_pap_N" )` go.
4. **Retire the numerals WHOLE**: the three `image,i_tod_hud_pap_1..3` zone
   lines, their GDT blocks, the `i_tod_hud_pap_sheet` entry in
   `tools/slice_hud_sheets.js` (and `_sheets/` file if one exists), and the
   numeral half of `gen_pap_badge_placeholder.js`. Half a retirement is dead
   weight — see the KEEP THE BUILD SMALL rule.
5. Full build (a GDT edit is always a full build); proof = a fresh
   content-hash `.iwi` for `i_tod_hud_pap_icon` beside an untouched control.
   Flip this STATUS to SHIPPED with the version.

## The two things that could go wrong

**It must not read as a third equipment slot.** The badge sits on the same row
as the monkey and the grenade at the same size in the same palette, and those
two are inventory counters. The plate carries the difference (a rule along one
edge, a clipped corner — one deliberate asymmetry), and the icon carries the
meaning: a fist and a bolt is not a thing you throw.

**Stay in the palette.** The user's explicit call for this badge: no gold, no
violet. The map's own free-PaP power-up icon has a yellow bolt and a gradient
fist; the HUD glyph set has neither. The bolt goes bright cyan.

<!-- PACK:BEGIN -->
# GAME HUD — THE PACK-A-PUNCH ICON (2 files → 2 images)

## Start here

**Open `icon_slot.png` first.** It is the whole brief in one picture: the badge
in place at true size over a dark and a bright background, the icon box ringed
in solid red, the plate ringed in dashed orange, then magnified six times, with
a table of what to deliver.

**Then open `art_direction_board.png` and read all of it.** It is the art
direction for this HUD on one page — the game, the exact palette sampled out of
the shipped files, three good examples with what makes them good, three
anti-examples, and six rules. Everything below assumes you have read it.

## What this is

The bottom-right corner of the heads-up display of a custom Call of Duty:
Black Ops III zombies map. The map is a fifty-floor neon tower in a purple night
city; the player climbs an open staircase spiralling around the *outside* of it
while an endless horde chases them.

The corner already has two equipment tiles: a **cymbal monkey** with a count and
a **grenade** with a count (`i_tod_hud_off_monkey.png`, `i_tod_hud_off_frag.png`
— open them). To their left, above the picture of the gun, sits a third plate
that reports **how many times the player has upgraded the gun they are
holding** at the Pack-a-Punch machine: level I, II or III. Levels II and III
cost 25,000 and 50,000 points and hand back *the same gun*, looking exactly as
before, so this badge is the only thing on screen that shows what the money
bought.

Right now that badge is a plate with a bare Roman numeral. It is the one tile in
the corner with **no picture**. This order fixes that: the badge becomes
**a Pack-a-Punch emblem on the left and the level number on the right**, built
exactly like the monkey and the grenade tiles.

The **number is drawn by the game** in its own typeface and is NOT part of this
order. You are drawing the **emblem** and the **plate** behind it.

## The subject

The Pack-a-Punch machine's mark is **a clenched fist and a lightning bolt** —
open `i_tod_pu2_free_pap.png`, the map's own power-up icon, to see the subject.
**Copy the subject, not the rendering**: that file has a gradient fist and a
yellow bolt, and both are banned here. Draw the same idea in the flat two-tone
style of the three sibling glyphs.

Read it as: *power went into this gun.* A fist punching upward, wrapped or
struck through by one bolt. Two shapes, big and blunt.

## The three rules that matter more than anything else

1. **DRAW FOR THE SIZE IT IS SHOWN, NOT THE SIZE OF YOUR CANVAS.** The icon is
   shown at **36 × 36 pixels** and the plate at **69 × 48**. You are drawing them
   at 128 × 128 and 276 × 192. Few shapes, thick strokes, huge contrast. Nothing
   narrower than about **6 px on your canvas**; if a detail would be under 10 px,
   delete it rather than shrink it. `i_tod_hud_off_spider.png` is the MOST detail
   that still reads at 36 px — do not exceed it.

2. **FLAT. ALWAYS.** No bevel, no extrusion, no gloss, no gradient ramps, no
   chrome, no photographic texture, no bloom, no glow. Two flat tones per
   element: a face, and one darker tone used only as a hard-edged offset.

3. **IT MUST READ ON A BRIGHT BACKGROUND.** Look at the right-hand half of
   `icon_slot.png`. Anything pale with no dark edge disappears against the fog.
   Every piece needs a hard near-black outline, the same weight as the monkey's.

## The palette — do not invent colours

| hex | name | use |
|---|---|---|
| `#E8EEF6` | STEEL WHITE | the fist |
| `#5BC8FF` | ELECTRIC CYAN | keylines, edges, rules |
| `#33D9FF` | BRIGHT CYAN | the bolt — the hottest accent |
| `#131B38` | DEEP NAVY | the plate body |
| `#0A1020` | OUTLINE BLACK | the hard outline around everything |

**No gold, no yellow, no violet, no orange, no red, no green.** The power-up
icon's yellow bolt is the one thing NOT to bring across: the bolt here is bright
cyan. Red in particular is reserved — the game flashes the ammo numerals red at
low ammo one row down.

## Deliver exactly TWO files

| filename | canvas | what it is |
|---|---|---|
| `i_tod_hud_pap_icon.png` | **128 × 128** | THE ICON. The Pack-a-Punch emblem. ONE file, used at every level. |
| `i_tod_hud_pap_tile.png` | **276 × 192** | THE PLATE. ONE file, drawn behind the icon and the number at every level. |

PNG, RGBA, transparent where nothing is drawn. Exact pixel dimensions.

---

## PROMPT A — the icon

*Attach: `icon_slot.png`, `art_direction_board.png`, `i_tod_hud_off_monkey.png`,
`i_tod_hud_off_frag.png`, `i_tod_hud_off_spider.png`, `i_tod_pu2_free_pap.png`,
`house_style_points_icon.png`, `world_cover.png`*

> A single flat icon for a science-fiction video-game heads-up display, drawn
> on a 128 × 128 transparent canvas and shown to the player at 36 × 36 pixels.
>
> Subject: the Pack-a-Punch emblem — **a clenched fist punching upward with a
> single lightning bolt** striking through or wrapping it. See
> `i_tod_pu2_free_pap.png` for the subject only; do not copy its gradient or its
> yellow. Two big blunt shapes that read as "fist" and "bolt" at 36 pixels.
>
> Style: match `i_tod_hud_off_monkey.png`, `i_tod_hud_off_frag.png` and
> `i_tod_hud_off_spider.png` exactly — they are the three icons this one sits
> beside on the same row of the same HUD. Flat, two tones per element, a hard
> near-black outline (`#0A1020`) of the same thickness as theirs, no gradient,
> no glow, no bevel, no texture. The fist in steel white (`#E8EEF6`) with a
> darker hard-edged offset tone for the knuckle shadow; the bolt in bright cyan
> (`#33D9FF`) with an electric-cyan (`#5BC8FF`) edge.
>
> Fill the cell the way the siblings do: the silhouette occupies roughly the
> central 100 × 100 of the 128 canvas, with clear transparent margins. Centred,
> upright, front-on, no perspective, no shadow outside the silhouette.
>
> It must not look like a weapon or a throwable — it is a status mark, not a
> piece of equipment.

## PROMPT B — the plate

*Attach: `icon_slot.png`, `art_direction_board.png`, `i_tod_hud_offhand_tile.png`,
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
> The body must stay dark and calm across its whole width: a white icon is drawn
> on its left half and a white number on its right third, and both must stay
> legible.
>
> Flat vector, hard edges, high contrast, no perspective, no shadow inside the
> canvas.

---

## Delivery checklist

- [ ] `i_tod_hud_pap_icon.png` is **exactly 128 × 128**, RGBA, transparent
      outside the emblem.
- [ ] `i_tod_hud_pap_tile.png` is **exactly 276 × 192**, RGBA, transparent
      outside the plate.
- [ ] The icon reads as a **fist and a bolt** at 36 × 36 — shrink it and check.
- [ ] The icon's outline weight matches the monkey's and the grenade's.
- [ ] Every element has a hard near-black outline and reads against the bright
      half of `icon_slot.png`.
- [ ] Palette only: `#E8EEF6`, `#5BC8FF`, `#33D9FF`, `#131B38`, `#0A1020`.
- [ ] The plate reads as a **status badge**, not as a third equipment slot.
- [ ] Nothing is a gradient, a bevel, a glow or a photograph.

## Do NOT

- Do not add gold, yellow, violet, orange, red or green anywhere.
- Do not bake a number, a numeral, or the letters "PaP" into the icon — the
  game draws the level itself, beside the icon.
- Do not draw the Pack-a-Punch MACHINE; draw its mark.
- Do not deliver three level variants of the icon. One icon, all levels.
- Do not draw text, labels, borders, watermarks, drop shadows outside the
  silhouette, or a background behind the transparent areas.
- Do not resize, pad or crop the two canvases to "nicer" numbers.
<!-- PACK:END -->
