<!-- art-pack
name: mage_dark
refs:
  i_tod_card_damage_ultimate.png | EXAMPLE PAIR 1, the ULTIMATE: DAMAGE as it ships.
  i_tod_card_damage_dark.png | EXAMPLE PAIR 1, the DARK: the SAME rocket, line for line, flat-recoloured to the warm dark palette, on the purple panel. No glow, no haze, no blur. This is the relationship every mage card must have to its ULTIMATE.
  i_tod_card_headshot_ultimate.png | EXAMPLE PAIR 2, the ULTIMATE: HEADSHOT as it ships.
  i_tod_card_headshot_dark.png | EXAMPLE PAIR 2, the DARK: identical drawing, dark palette, purple panel, ULTIMATE text kept.
  i_tod_card_mage_heal_ultimate.png | EXAMPLE PAIR 3, the ULTIMATE: a MAGE card as it ships.
  i_tod_card_mage_heal_dark.png | EXAMPLE PAIR 3, the DARK: the shipped mage dark card. Same aura drawing, same text, dark chassis. The five new cards sit beside this one.
  i_tod_card_mage_bolt_ultimate.png | CHAIN LIGHTNING at ULTIMATE: the drawing and text the dark card must keep.
  i_tod_card_mage_fire_ultimate.png | FIRE BLAST at ULTIMATE: the drawing and text to keep.
  i_tod_card_mage_ice_ultimate.png | ICE SHATTER at ULTIMATE: the drawing and text to keep.
  i_tod_card_mage_arch_ultimate.png | ARCHMAGE at ULTIMATE: the drawing and text to keep.
  i_tod_card_mage_blink_ultimate.png | BLINK at ULTIMATE: the drawing and text to keep.
  docs/126_dark_ref/i_tod_card_mage_bolt_dark.png | Your second delivery of CHAIN LIGHTNING: text now right, chassis right; the drawing was re-lit with a haze that no shipped dark card has.
  docs/126_dark_ref/i_tod_card_mage_fire_dark.png | Your second delivery of FIRE BLAST: same note.
  docs/126_dark_ref/i_tod_card_mage_ice_dark.png | Your second delivery of ICE SHATTER: same note.
  docs/126_dark_ref/i_tod_card_mage_arch_dark.png | Your second delivery of ARCHMAGE: the magenta haze around the crown is the clearest example of what to remove.
  docs/126_dark_ref/i_tod_card_mage_blink_dark.png | Your second delivery of BLINK: same note.
preview: 234x351
-->

# 126 — MAGE: the DARK cards (third request) and red plates (landed)

**Status: SHIPPED — plates v18.73, the five cards v18.76 (drop `files - 2026-09-10T135741.570.zip`, top-level set; the nested duplicate set differs only by a few bytes).**

Two drops so far, both wrong because of THIS BRIEF, not the generator — the
user's own requests do not come back wrong (*"I never have issues so how are
you causing problems"*):
1. `files - 2026-09-09T230555.322.zip`: the brief asked for "DARK: +50%"
   description lines. A dark card keeps its ULTIMATE description word for
   word. The six red plates in that drop were right and are installed.
2. `files - 2026-09-09T234343.399.zip`: text fixed, but the brief had also
   said "re-light the subject darker with a red-violet rim", so every drawing
   came back under a magenta haze. Look at any shipped pair: `damage_dark` is
   the SAME rocket as `damage_ultimate`, flat-recoloured, on the purple panel.
   No shipped dark card re-lights anything.

The third brief therefore says nothing the shipped pairs do not show: three
ULTIMATE/DARK pairs from the shipped set are attached as the whole
specification, and the ask is "do that to these five". The v2 cards are
attached only to name what to remove.

**Install, when the drop comes back** (`files (N).zip`):
1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'` — LOOK at all five
   beside `damage_dark`: identical drawing to the ULTIMATE, no haze, ULTIMATE
   text, dark chassis.
2. Copy the 5 PNGs into `source_data/tod_ui_images/_images/`.
3. GDT: clone the `i_tod_card_mage_heal_dark` block five times.
4. Zone: `image,i_tod_card_mage_bolt_dark` etc. beside the heal line.
5. Lua: delete 49/50/53/54/55 from `DARK_TEXT_ONLY` in `tod_upgrade.lua`;
   `lint_tod_assets.js` then demands the five zone lines.
6. FULL build; proof = a fresh content-hash `.iwi` per image beside a control.
7. Flip this STATUS to SHIPPED with the build version.

<!-- PACK:BEGIN -->
# TOWER OF DOOM — five MAGE dark cards, made exactly like the shipped pairs

## The whole specification is three attached pairs

Look at these three ULTIMATE → DARK pairs from the shipped set:

| ULTIMATE | DARK |
|---|---|
| `i_tod_card_damage_ultimate.png` | `i_tod_card_damage_dark.png` |
| `i_tod_card_headshot_ultimate.png` | `i_tod_card_headshot_dark.png` |
| `i_tod_card_mage_heal_ultimate.png` | `i_tod_card_mage_heal_dark.png` |

In every pair the DARK card is the ULTIMATE card with exactly three changes:

1. The chassis: gold frame, name band, tag and pips become the red dark
   chassis with the DARK UPGRADE tag.
2. The picture panel background: navy becomes the dark purple.
3. The illustration's palette: the same drawing, line for line, at the same
   size and position, flat-recoloured toward the dark card's warm palette (the
   DAMAGE rocket goes from yellow to orange-red). Flat colour changes only —
   no added glow, haze, blur, smoke, rim light or gradient around the subject.

Everything else is identical, including the description text at the bottom,
which is the ULTIMATE card's text word for word.

## Deliverables — 5 files, 768 × 1152 PNG, RGBA

Do exactly what the pairs show, to these five:

| ULTIMATE (attached) | Deliver | Description text (as on the ULTIMATE) |
|---|---|---|
| `i_tod_card_mage_bolt_ultimate.png` | `i_tod_card_mage_bolt_dark.png` | `ARCS TO` / `MORE ZOMBIES` |
| `i_tod_card_mage_fire_ultimate.png` | `i_tod_card_mage_fire_dark.png` | `BURNS ROBOTS` / `AND ARMOR` |
| `i_tod_card_mage_ice_ultimate.png` | `i_tod_card_mage_ice_dark.png` | `SHATTERS HOUNDS` / `AND FURIES` |
| `i_tod_card_mage_arch_ultimate.png` | `i_tod_card_mage_arch_dark.png` | `ARCHMAGE HITS` / `HARDER AND` / `LASTS LONGER` |
| `i_tod_card_mage_blink_ultimate.png` | `i_tod_card_mage_blink_dark.png` | `BLINK FURTHER` / `AND MORE OFTEN` |

`/` marks a line break, exactly as the ULTIMATE card breaks it.

## What was wrong last time — remove it

Your second delivery is attached as `i_tod_card_mage_*_dark.png`. Its
chassis and text are right. Its drawings were
re-lit with a magenta haze and rim (clearest on ARCHMAGE, around the crown).
No shipped dark card has that. Start from the ULTIMATE drawing instead and
recolour it flat, as `damage_dark` does to `damage_ultimate`.

## Hard rules

1. 768 × 1152, RGBA PNG, the five file names above.
2. The chassis is the attached dark chassis, pixel for pixel; the pips are the
   ULTIMATE card's pip count, lit red as on the attached dark cards.
3. The illustration is the ULTIMATE card's illustration: same lines, same size,
   same position. Palette shift only. Nothing added around it.
4. The description text is the ULTIMATE card's, character for character.

## Prompt

Attach the three pairs plus the one ULTIMATE card being converted:

> The attached ULTIMATE/DARK pairs show how this set makes a dark card: the
> same illustration, line for line, flat-recoloured toward the warm dark
> palette, on the purple panel inside the red dark chassis, with the ULTIMATE
> description text kept word for word. Do exactly that to the attached
> ULTIMATE card. Do not add glow, haze, blur or rim light around the subject.
> 768 by 1152, RGBA PNG.

## Delivery checklist

- 5 files, named as above, 768 × 1152 RGBA.
- Each one, placed next to `i_tod_card_damage_dark.png`, reads as the same set.
- Each illustration overlays its ULTIMATE illustration exactly; only colours differ.
- The description strings match the table character for character.
- Zip them flat and send the zip.

## Do NOT

- Do not re-light, haze, blur or add a rim to the illustration.
- Do not change the description text or add numbers.
- Do not send the plates again — they are accepted.
<!-- PACK:END -->
