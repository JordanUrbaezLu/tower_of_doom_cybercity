# 125 — THE PACK-A-PUNCH ICON, ROUND 2: THREE DISTINCT CONCEPTS (3 files → pick one)

<!-- art-pack
name: pap_icon_concepts
refs:
  docs/102_pap_ref/icon_slot.png | WHERE IT LIVES. The badge in place at true 1080p size over a dark AND a bright background, the icon box ringed in red, then magnified 6x. Attach to every prompt.
  docs/102_pap_ref/delivered_review.png | THE CURRENT ICON ON ITS PLATE at all three levels, dark and bright. This is what is being replaced: it reads as a bullet or a gravestone, not as Pack-a-Punch. Attach to every prompt.
  docs/95_hud_ref/art_direction_board.png | THE ART DIRECTION on one page: the game, the palette with hex values, three good examples, three anti-examples, the six rules. Attach to every prompt.
  i_tod_hud_pap_1.png | THE CURRENT LEVEL-1 GLYPH, shipped. Correct SIZE, STYLE, OUTLINE WEIGHT and PALETTE — keep all of that. Wrong SUBJECT — replace that. Attach to every prompt.
  i_tod_hud_pap_3.png | THE CURRENT LEVEL-3 GLYPH, shipped. Same note. Attach to every prompt.
  i_tod_hud_pap_tile.png | THE PLATE the icon is drawn on. Not part of this order; shown so you can preview your icon on it. Attach to every prompt.
  i_tod_hud_off_monkey.png | SIBLING GLYPH 1, shipped and approved: the cymbal monkey on the same row. Same cell, same outline. Attach to every prompt.
  i_tod_hud_off_frag.png | SIBLING GLYPH 2, shipped and approved: the frag grenade. Flat, two tones, hard outline. Attach to every prompt.
  i_tod_hud_off_spider.png | SIBLING GLYPH 3, shipped and approved: the ceiling of allowed detail at 36x36. Attach to every prompt.
  i_tod_pu2_free_pap.png | THE MAP'S OWN POWER-UP ICON for Pack-a-Punch: a fist and a lightning bolt. Subject reference for CONCEPT A only. Its gradient and yellow are banned. Attach to Prompt A.
  docs/95_hud_ref/house_style_points_icon.png | THE HOUSE GLYPH STYLE at its clearest — flat, two tones, hard dark outline, zero gradient. Attach to every prompt.
  docs/95_hud_ref/world_cover.png | the map's own cover art: the neon tower, the purple night city, the flat-vector-with-hard-outline look. Attach to every prompt.
preview: 36x36
-->

> **⚠️ SUPERSEDED 2026-09-10 by `docs/131_pap_tier_icons_art_prompt.md` (round
> 4).** The user saw round 3 in game: *"Our pap icon looks like ass in game. But
> both blink and healing aura look great."* docs/131 measures why all three
> rounds here failed the same way — the icons average **9.0% saturated ink
> against the 29.3% of the two offhand icons on the same HUD row**, while ink
> coverage is effectively equal (43.3% vs 45.9%) and the PaP glyph box is
> already LARGER than theirs (26x26 canvas units against 24x24). So it was
> never a size problem, and re-picking the subject a fourth time would not have
> fixed it either. Read docs/131 before touching these three names.
>
> **2026-09-10 readability correction:** the live PNGs had reverted to the
> older round-2 bytes. Restored the exact round-3 delivery below and enlarged
> the HUD glyph box to 26x26 canvas units (39x39 physical pixels at 1080p).
> The plate and level digit stay in place. Full build verified 2026-09-10
> 20:03:42 Eastern. The reference dimensions farther down describe the original
> commission; native confirmation remains pending.
>
> **STATUS: ROUND 3 INSTALLED 2026-09-09 19:21 (files - 2026-09-09T191941.581.zip)
> — FULL BUILD, UNPLAYED.** The subject changed: this set is the FIST + LIGHTNING
> BOLT, which is concept A's direction and the same language as the map's own
> free-Pack-a-Punch power-up icon (`i_tod_pu2_free_pap`). Level is carried by
> chevrons above the fist — none / one / two — and the level DIGIT is still drawn
> by the game, so nothing is baked that the plate also prints. 128x128 RGBA,
> palette-only, house outline, no gradient. Installed over the round-2 pistol
> under the SAME NAMES `i_tod_hud_pap_1..3`, so no zone line, GDT block or Lua
> slug moved. Review sheet: `docs/125_pap_ref/delivered_review_round3.png`.
> The round-2 files it replaced are parked in the session scratchpad, not the
> repo — recover them from that sheet's own 128px panels if this is reverted.
>
> **(Round 2) STATUS: DROP INSTALLED 2026-09-09 (files - 2026-09-09T131305.081.zip)
> — SUPERSEDED THE SAME DAY by the set above.** The generator returned ONE
> direction, concept C (a blunt
> side-on pistol with 1 / 2 / 3 upward chevrons and a spark), already as the
> per-level set under the existing names `i_tod_hud_pap_1..3` (128x128 RGBA,
> palette-only, house outline) plus `docs/125_pap_ref/delivered_review.png`.
> Installed over the v17.60 capsule glyphs: same names = no zone/GDT/Lua
> wiring. The user asked for them wired up as delivered; concepts A/B were not
> returned.
>
> **(Original) STATUS: COMMISSIONED 2026-09-09 — NOT WIRED.** Pack built by
> `.\tools\make_art_pack.ps1 docs\125_pap_icon_concepts_art_prompt.md` →
> `~/Downloads/tod_pap_icon_concepts_art_pack.zip`. This is a CONCEPT round:
> three deliberately different directions, one icon each, so the user can pick
> a path and iterate on it. Nothing installs from this drop directly.

**Why (user, 2026-09-09):** *"I think we really need a nice pap icon and it
doesnt really indicate pap too well ... my llm can generate 3 different
versions so i can choose from. Distinct so i have a path to go down and
iterate."*

The shipped glyphs (`i_tod_hud_pap_1..3`, v17.60, docs/102) are a pale
pointed capsule with 1/2/3 bolts inside. On the plate at 36×36 the silhouette
reads as a bullet, a rocket or a gravestone — the bolts are the only
Pack-a-Punch cue and they are too thin to carry it. Size, style, palette and
outline weight are all right and are the things to keep.

## What is wired today (unchanged by this round)

`AetheriumLoadout.lua` (`TOD_PAP_ART`) draws `i_tod_hud_pap_<level>` in the
24×24 glyph box on `i_tod_hud_pap_tile`, and draws the level as a game-typeface
digit beside it. So the install of the WINNING concept is either:

- one icon for every level → copy it to all three names `i_tod_hud_pap_1..3`
  (same names = no zone/GDT wiring; the digit already says the level), or
- a per-level set (bolts / pips / fill growing 1→2→3) → three files under the
  same three names.

Either way it is a FULL build (image assets), proof = a fresh content-hash
`.iwi` beside an untouched control. The plate (docs/103) stays.

## Round plan

1. This pack → three concepts come back as `pap_concept_a/b/c.png`.
2. `-Inspect` the drop, LOOK at all three on `i_tod_hud_pap_tile` at 36×36
   over dark AND bright, put them in front of the user.
3. The chosen direction gets its own follow-up doc (126+) for the per-level set
   and any refinement — never iterate all three at once.

<!-- PACK:BEGIN -->
# GAME HUD — THE PACK-A-PUNCH ICON: THREE CONCEPTS (deliver 3 icons + 1 review sheet)

## Start here

**Open `delivered_review.png` first.** It shows the icon we have now, sitting on
its plate at the size the player sees it, at levels 1, 2 and 3, over a dark and a
bright background. **The problem: it does not say "Pack-a-Punch".** It reads as
a bullet, a rocket or a gravestone with some lightning in it. Its SIZE, STYLE,
OUTLINE and COLOURS are all correct and must be kept. Its SUBJECT is what this
order replaces.

**Then open `icon_slot.png`** (where it lives, magnified) and read
**`art_direction_board.png`** all the way through — the palette, the six rules,
the good and bad examples. Everything below assumes you have read it.

## What this is

The bottom-right corner of the heads-up display of a custom Call of Duty:
Black Ops III zombies map: a fifty-floor neon tower in a purple night city, an
endless horde on an open spiral staircase. The corner has equipment tiles — a
**cymbal monkey** and a **grenade**, each a picture plus a count
(`i_tod_hud_off_monkey.png`, `i_tod_hud_off_frag.png`). Beside them sits a
status badge that says **how many times the held gun has been upgraded at the
Pack-a-Punch machine** (level 1, 2 or 3). The game draws the level DIGIT itself
beside the icon, so the icon's one job is to say **"Pack-a-Punch"** at a glance.

Zombies players know Pack-a-Punch by three things: the **fist-and-lightning
mark** painted on the machine, the **machine itself** (a jukebox-sized cabinet
with a glowing hood and a roller that pulls the gun in and spits it back out),
and the **result** — the gun comes back stronger, with a shimmering camo.

## This is a CONCEPT round: three DIFFERENT answers

Deliver **three icons, one per concept below, as different from each other as
you can make them while all obeying the same style rules.** They will be judged
side by side and ONE direction chosen for a follow-up round. Do not blend them
into three variations of one idea — the value of this round is the spread.

| file | concept | subject in one line |
|---|---|---|
| `pap_concept_a.png` | **A — THE MARK** | The Pack-a-Punch emblem: a clenched fist punching upward with one lightning bolt struck through it. |
| `pap_concept_b.png` | **B — THE MACHINE** | The Pack-a-Punch machine itself, front-on: a squat cabinet with a bright hood/arch on top and a slot or roller across the front. |
| `pap_concept_c.png` | **C — THE UPGRADE** | A gun going up: a chunky side-on pistol or rifle silhouette with a bold upward chevron (or two) and one spark of lightning above it. |

Every icon: **128 × 128, PNG, RGBA, transparent outside the drawing**, shown to
the player at **36 × 36**.

Also deliver **`review_sheet.png`**: the three icons composited onto
`i_tod_hud_pap_tile.png` at their true on-screen size (36 px icon on the 69 × 48
plate) over a dark AND a bright background, labelled A / B / C — exactly like
`delivered_review.png`. This is how they will be judged.

## The three rules that matter more than anything else

1. **DRAW FOR 36 PIXELS, NOT FOR 128.** Few shapes, thick strokes, huge
   contrast. Nothing narrower than about **6 px on your 128 canvas**; if a detail
   would be under 10 px, delete it. `i_tod_hud_off_spider.png` is the MOST detail
   that still reads at 36 px — stay under it. **The silhouette must be the
   message**: cover the icon with your thumb at 36 px and the OUTLINE alone
   should still say fist / machine / gun.

2. **FLAT. ALWAYS.** No bevel, no extrusion, no gloss, no gradient, no chrome,
   no texture, no bloom, no glow. Two flat tones per element: a face, and one
   darker tone used only as a hard-edged offset.

3. **IT MUST READ ON A BRIGHT BACKGROUND.** Look at the bright half of
   `delivered_review.png`. Every piece needs the same hard near-black outline
   the monkey has, at the same weight.

## The palette — do not invent colours

| hex | name | use |
|---|---|---|
| `#E8EEF6` | STEEL WHITE | the main body (fist / cabinet / gun) |
| `#5BC8FF` | ELECTRIC CYAN | keylines, edges, the machine's hood |
| `#33D9FF` | BRIGHT CYAN | the lightning — the hottest accent, used small |
| `#131B38` | DEEP NAVY | interior dark tone, slots, shadows-as-shapes |
| `#0A1020` | OUTLINE BLACK | the hard outline around everything |

**No gold, no yellow, no violet, no orange, no red, no green.** The power-up
icon's yellow bolt is the one thing NOT to bring across: lightning is bright
cyan here. Red is reserved for the low-ammo flash one row down.

---

## PROMPT A — THE MARK

*Attach: `delivered_review.png`, `icon_slot.png`, `art_direction_board.png`,
`i_tod_hud_pap_1.png`, `i_tod_hud_off_monkey.png`, `i_tod_hud_off_frag.png`,
`i_tod_hud_off_spider.png`, `i_tod_pu2_free_pap.png`,
`house_style_points_icon.png`, `world_cover.png`*

> A single flat icon for a science-fiction video-game heads-up display, on a
> 128 × 128 transparent canvas, shown to the player at 36 × 36 pixels.
>
> Subject: the Pack-a-Punch mark — **a clenched fist punching straight up, with
> one big lightning bolt struck diagonally through it.** See
> `i_tod_pu2_free_pap.png` for the subject only; do not copy its gradient or its
> yellow. Two blunt shapes: the fist is one fat silhouette (four knuckles as a
> single stepped edge, thumb tucked, wrist cut flat at the bottom), the bolt is
> one thick zigzag with three points at most. The bolt must overlap the fist so
> the two read as ONE emblem, not a fist beside a bolt.
>
> Style: match `i_tod_hud_off_monkey.png`, `i_tod_hud_off_frag.png` and
> `i_tod_hud_pap_1.png` exactly — same cell, same outline weight (`#0A1020`),
> flat two-tone, no gradient, no glow. Fist in steel white (`#E8EEF6`) with a
> deep-navy (`#131B38`) hard-edged offset for the knuckle shadow; bolt in bright
> cyan (`#33D9FF`) with an electric-cyan (`#5BC8FF`) edge.
>
> Fill the cell like the siblings: silhouette in roughly the central 100 × 100,
> clear transparent margins, centred, upright, front-on, no perspective, no
> shadow outside the silhouette. It is a status mark, not a weapon and not a
> throwable.

## PROMPT B — THE MACHINE

*Attach: `delivered_review.png`, `icon_slot.png`, `art_direction_board.png`,
`i_tod_hud_pap_1.png`, `i_tod_hud_pap_3.png`, `i_tod_hud_off_monkey.png`,
`i_tod_hud_off_frag.png`, `i_tod_hud_off_spider.png`,
`house_style_points_icon.png`, `world_cover.png`*

> A single flat icon for a science-fiction video-game heads-up display, on a
> 128 × 128 transparent canvas, shown to the player at 36 × 36 pixels.
>
> Subject: **the Pack-a-Punch machine, front-on, as a pictogram.** A squat,
> wide cabinet — wider than it is tall in the body — with a **bright arched or
> stepped hood on top** in electric cyan (`#5BC8FF`), a **dark horizontal slot
> or roller across the front** (`#131B38`) where the gun goes in, and a flat
> base. Optionally one small bright-cyan (`#33D9FF`) spark at the hood's peak.
> Think "jukebox meets vending machine", reduced to four or five big shapes.
> The arch-over-slot silhouette is the read; if the outline alone does not say
> "machine with a mouth", simplify further.
>
> Style: match `i_tod_hud_off_monkey.png`, `i_tod_hud_off_frag.png` and
> `i_tod_hud_pap_1.png` exactly — same cell, same outline weight (`#0A1020`),
> flat two-tone per element, no gradient, no glow, no bevel. Body in steel white
> (`#E8EEF6`) with a deep-navy offset for depth.
>
> Fill the cell like the siblings: silhouette in roughly the central 100 × 100,
> centred, upright, front-on, no perspective. Must NOT resemble the current
> icon's pointed capsule — the top is an arch or a step, not a point.

## PROMPT C — THE UPGRADE

*Attach: `delivered_review.png`, `icon_slot.png`, `art_direction_board.png`,
`i_tod_hud_pap_1.png`, `i_tod_hud_off_monkey.png`, `i_tod_hud_off_frag.png`,
`i_tod_hud_off_spider.png`, `house_style_points_icon.png`, `world_cover.png`*

> A single flat icon for a science-fiction video-game heads-up display, on a
> 128 × 128 transparent canvas, shown to the player at 36 × 36 pixels.
>
> Subject: **a gun being upgraded.** A chunky, generic, side-on firearm
> silhouette (a blocky pistol or a short rifle — no real-world model, no fine
> parts) in steel white (`#E8EEF6`) filling the lower two thirds of the cell,
> with **one bold upward chevron** in electric cyan (`#5BC8FF`) rising from it
> into the top third, and **one small bright-cyan (`#33D9FF`) lightning spark**
> at the chevron's tip. The read is "this gun went up". Three shapes total: gun,
> chevron, spark.
>
> Style: match `i_tod_hud_off_monkey.png`, `i_tod_hud_off_frag.png` and
> `i_tod_hud_pap_1.png` exactly — same cell, same outline weight (`#0A1020`),
> flat two-tone per element, no gradient, no glow. Deep navy (`#131B38`) for the
> gun's grip/slot as a hard-edged shape, nothing finer.
>
> Fill the cell like the siblings: silhouette in roughly the central 100 × 100,
> centred, no perspective. The gun must stay generic and blunt so it does not
> read as a fourth equipment slot — the chevron is the point of the picture, so
> make it big.

---

## Delivery checklist

- [ ] `pap_concept_a.png`, `pap_concept_b.png`, `pap_concept_c.png` — each
      **exactly 128 × 128**, RGBA, transparent outside the drawing.
- [ ] `review_sheet.png` — all three on the plate at 36 px, dark AND bright,
      labelled A / B / C.
- [ ] The three are visibly DIFFERENT subjects (mark / machine / gun-going-up),
      not one idea three ways.
- [ ] Each reads at 36 × 36 — shrink it and check the silhouette alone.
- [ ] Outline weight matches the monkey's and the current `i_tod_hud_pap_1.png`.
- [ ] Every element reads on the bright half of the review sheet.
- [ ] Palette only: `#E8EEF6`, `#5BC8FF`, `#33D9FF`, `#131B38`, `#0A1020`.
- [ ] No concept looks like the current pointed capsule.

## Do NOT

- Do not add gold, yellow, violet, orange, red or green anywhere.
- Do not bake a number, a numeral, "PaP", "I/II/III" or any text into an icon —
  the game draws the level beside it.
- Do not deliver per-level variants this round. One icon per concept.
- Do not draw the plate — `i_tod_hud_pap_tile.png` already exists; use it only
  in the review sheet.
- Do not draw text, labels, borders, watermarks, drop shadows outside the
  silhouette, or a background behind the transparent areas.
- Do not resize, pad or crop the 128 × 128 canvas to "nicer" numbers.
<!-- PACK:END -->
