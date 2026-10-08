# 103 — THE PACK-A-PUNCH BADGE PLATE (1 file → 1 image) — the half of docs/102 that did not come back

<!-- art-pack
name: pap_plate
refs:
  docs/103_pap_ref/plate_slot.png | THE BRIEF IN ONE PICTURE. The badge in place at true 1080p size over a dark AND a bright background with the FINISHED icon and number on the placeholder plate, the plate ringed in red, then magnified 6x — plus what is delivered. Attach to every prompt.
  docs/102_pap_ref/delivered_review.png | YOUR OWN REVIEW SHEET from the icon delivery: the three level icons on the placeholder plate beside the game's digit. The plate in it is the one being replaced. Attach to every prompt.
  docs/95_hud_ref/art_direction_board.png | THE ART DIRECTION on one page: the game, the palette sampled from the shipped files with hex values, three GOOD examples and three anti-examples, and the six rules. Attach to every prompt.
  i_tod_hud_offhand_tile.png | THE SIBLING PLATE, shipped and approved: the tile under the monkey and the grenade, two of them on the same row as the new plate. The new plate must look like the same hand made it on the same day. Attach to every prompt.
  i_tod_hud_pap_tile.png | THE PLACEHOLDER PLATE being replaced. Correct size and palette, deliberately plain. Attach to every prompt.
  i_tod_hud_pap_1.png | THE FINISHED LEVEL-1 ICON that sits on the plate's left half (128x128, drawn at 36x36). Shipping; do not redraw. Attach for context.
  i_tod_hud_pap_3.png | THE FINISHED LEVEL-3 ICON — the widest ink the plate must stay calm under. Shipping; do not redraw. Attach for context.
  docs/95_hud_ref/world_cover.png | the map's own cover art: the neon tower, the purple night city, the flat-vector-with-hard-outline look everything sits in. Attach to every prompt.
preview: 69x48
-->

> **STATUS: SHIPPED v17.68 (drop 2026-09-05 00:57, installed same name) —
> UNPLAYED.** `i_tod_hud_pap_tile.png` 276×192 RGBA: the offhand tile's
> chassis (chamfered top-left, cyan keyline, navy body) with ONE difference, a
> bold bright-cyan rule along the top edge. Review sheet kept at
> `docs/103_pap_ref/delivered_review.png`. `gen_pap_badge_placeholder.js` now
> writes nothing without `--tile` / `--numerals`. Every piece of the badge is
> commissioned art now.
>
> **(Original) STATUS: COMMISSIONED 2026-09-04 (v17.60 follow-up).** Pack built by
> `.\tools\make_art_pack.ps1 docs\103_pap_plate_art_prompt.md` →
> `~/Downloads/tod_pap_plate_art_pack.zip`. docs/102 ordered an icon AND a
> plate; the drop brought three level icons (installed v17.60, shipping) and no
> plate, so the badge still sits on `tools/gen_pap_badge_placeholder.js`'s flat
> navy placeholder. This is the plate alone. **Install = copy the one file over
> `source_data/tod_ui_images/_images/i_tod_hud_pap_tile.png` (same name, no
> wiring) + FULL build; proof = a fresh content-hash `.iwi` beside an untouched
> control.** Then flip this STATUS to SHIPPED and note it in docs/102.

## Why the plate matters now that the icons are in

The badge is read as one object: plate + icon + digit. The icons are house
style — flat, hard outline, palette — and the plate under them is a rectangle
with a cyan rule and two clipped corners. It is not wrong; it is the only part
of the corner that was drawn by a script, and beside the offhand tile (bevelled
corner cut, keyline weight, the same navy) it reads a shade flatter. One file
finishes the component.

## Geometry (1280×720 LUI canvas, ×1.5 = 1080p)

| slot | canvas box | @1080p | source | art |
|---|---|---|---|---|
| badge plate | 1012..1058 × 568..600 | 69 × 48 | 276×192 | `i_tod_hud_pap_tile` |
| icon (shipping) | 1017..1041 × 572..596 | 36 × 36 | 128×128 | `i_tod_hud_pap_1..3` |
| level digit (game-drawn) | right edge 1055, baseline 592, cap 12 | typeface | — | `todMakeGlyphRow` |

Zero stretch; box byte-identical to an offhand slot's. **y568 is a hard
ceiling** — the tower gauge's foot is at y566 in an overlay drawn on top.

<!-- PACK:BEGIN -->
# GAME HUD — THE PACK-A-PUNCH BADGE PLATE (1 file → 1 image)

## Start here

**Open `plate_slot.png` first.** It is the whole brief in one picture: the
badge in place at true size over a dark and a bright background, with the
FINISHED icon and number sitting on the plate you are replacing, ringed in red,
then magnified six times.

**Then open `delivered_review.png`** — your own review sheet from the icon
delivery. The three icons in it are installed and shipping exactly as drawn.
The plate under them is what this order replaces.

**Then open `art_direction_board.png` and read all of it.** Everything below
assumes you have.

## What this is

The bottom-right corner of the heads-up display of a custom Call of Duty:
Black Ops III zombies map: a fifty-floor neon tower in a purple night city.

The corner has two equipment tiles — a cymbal monkey with a count and a grenade
with a count — each on the plate `i_tod_hud_offhand_tile.png`. To their left,
above the gun picture, sits the Pack-a-Punch badge: a picture of the upgrade
machine with one, two or three bolts, and the level number beside it. **The
icon and the number are done.** The plate they sit on is a placeholder. This
order is that ONE plate.

## The three rules that matter more than anything else

1. **DRAW FOR THE SIZE IT IS SHOWN.** The plate is shown at **69 × 48 pixels**.
   You draw it at 276 × 192. Nothing narrower than about **6 px on your
   canvas**; if a detail would be under 10 px, delete it.

2. **FLAT. ALWAYS.** No bevel, no extrusion, no gloss, no gradient, no chrome,
   no texture, no bloom, no glow. A dark body, a hard outline, one keyline.

3. **THE MIDDLE STAYS DARK AND CALM.** A white icon is drawn on the left half
   and a white digit on the right third. Anything bright inside the body
   competes with them. Look at `plate_slot.png` at 6x: the ink of the level-3
   icon is the most the plate ever has to sit under.

## The palette — do not invent colours

| hex | name | use |
|---|---|---|
| `#131B38` | DEEP NAVY | the plate body |
| `#0A1020` | OUTLINE BLACK | the hard outline around the whole silhouette |
| `#5BC8FF` | ELECTRIC CYAN | the keyline |
| `#33D9FF` | BRIGHT CYAN | the one accent, if any, used sparingly |

**No gold, no yellow, no violet, no orange, no red, no green.** Red is
reserved — the game flashes the ammo numerals red at low ammo one row down.

## Deliver exactly ONE file

| filename | canvas | what it is |
|---|---|---|
| `i_tod_hud_pap_tile.png` | **276 × 192** | THE PLATE. ONE file, drawn behind the icon and the number at every level. |

PNG, RGBA, transparent outside the plate. Exact pixel dimensions.

---

## PROMPT — the plate

*Attach: `plate_slot.png`, `delivered_review.png`, `art_direction_board.png`,
`i_tod_hud_offhand_tile.png`, `i_tod_hud_pap_tile.png`, `i_tod_hud_pap_1.png`,
`i_tod_hud_pap_3.png`, `world_cover.png`*

> A single flat UI plate for a science-fiction video-game heads-up display,
> drawn on a 276 × 192 transparent canvas and shown to the player at 69 × 48
> pixels.
>
> It is a small status plate: a dark navy body (`#131B38`), a hard near-black
> outline (`#0A1020`) around the whole silhouette, and a crisp electric-cyan
> keyline (`#5BC8FF`). Slightly rounded or chamfered corners. Completely flat —
> two tones only, no bevel, no gloss, no gradient, no glow, no texture.
>
> Match `i_tod_hud_offhand_tile.png` exactly in weight, corner treatment,
> outline thickness and palette — it is the neighbouring plate in the same
> corner of the same HUD, and the two are seen together constantly.
>
> **But it must not be mistaken for it.** The neighbouring plates are equipment
> counters; this one is a status badge. Give it one clear, deliberate
> difference that reads at 69 × 48 — a bright rule along one edge, a clipped
> corner, a notch, a bracket. One difference, not three. The placeholder used a
> rule along the top edge and two clipped bottom corners; you may keep that
> idea or replace it, but keep exactly one.
>
> The body must stay dark and calm across its whole width: the icon in
> `i_tod_hud_pap_3.png` is drawn on its left half and a white digit on its
> right third (see `delivered_review.png`), and both must stay legible.
>
> Flat vector, hard edges, high contrast, no perspective, no shadow inside the
> canvas.

---

## Delivery checklist

- [ ] `i_tod_hud_pap_tile.png` is **exactly 276 × 192**, RGBA, transparent
      outside the plate.
- [ ] Palette only: `#131B38`, `#0A1020`, `#5BC8FF`, `#33D9FF`.
- [ ] The outline weight and corner treatment match `i_tod_hud_offhand_tile.png`.
- [ ] Exactly ONE deliberate difference from the equipment tile.
- [ ] The body is dark and calm where the icon and the digit sit — check by
      placing `i_tod_hud_pap_3.png` on the left half at 36 × 36 scale.
- [ ] Reads against the bright half of `plate_slot.png`.
- [ ] Nothing is a gradient, a bevel, a glow or a photograph.

## Do NOT

- Do not redraw or include the icons or the number — they are finished and
  drawn by the game on top of this plate.
- Do not add gold, yellow, violet, orange, red or green anywhere.
- Do not draw text, labels, watermarks, drop shadows outside the silhouette,
  or a background behind the transparent areas.
- Do not resize, pad or crop the canvas to a "nicer" number.
- Do not deliver level variants. One plate, all levels.
<!-- PACK:END -->
