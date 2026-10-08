# 123 — Mystical Hands: ultimate card and pause nameplate

<!-- art-pack
name: mystical_hands
refs:
  i_tod_card_deadshot_ultimate.png | PRIMARY card chassis and one-time ultimate layout: ULTIMATE alone, no +3, no level pips. Preserve frame, margins and type treatment.
  i_tod_card_mage_arch_ultimate.png | Mage deck style and gold ultimate finish. Use its illustrated treatment, but do NOT copy +3 or its pip row.
  i_tod_card_mage_blink_ultimate.png | Mage movement-themed illustration reference. Match the deck; the new subject is magical hands exchanging staffs.
  i_tod_pause_r53.png | PRIMARY 300x44 pause plate and long two-word title fitting: CHAIN LIGHTNING. Replace only the title.
  i_tod_pause_r52.png | Second 300x44 pause plate reference: HEALING AURA. Match baseline, notch, border and margins.
preview: 234x351 300x44
-->

Status: INSTALLED 2026-09-08 from files - 2026-09-08T142203.896.zip.
User explicitly approved the delivered pips and HANDLE STAFFS FASTER text;
both assets installed unchanged. Card MD5 prefix 2cbf2599, plate ac9ce03f.
Built in the shared full build completed at 2026-09-08 14:34:56; source
freshness and both new image conversions verified. In-game check pending.
The brief below is the original request, not a claim about the approved art.
Domain 56, stable internal key
`mage_quickhands`, renamed from Quick Hands. One-level Mage-only ultimate,
rarity lock 3, no dark form. Both UI surfaces now use the delivered art.

Build this handoff with `tools/make_art_pack.ps1`. When the drop arrives,
inspect both images and dimensions, then add image GDT blocks and zone lines.
Set CARD_SLUG[56] to `mystical_hands`, CARD_ONE_IMAGE[56] to `ultimate`, and
raise PAUSE_PLATE_MAX from 55 to 56. Full build after installation. Do not
register missing art early. These two images add no weapon registrations.

<!-- PACK:BEGIN -->
# MYSTICAL HANDS — two matching game UI assets

Create exactly two finished PNG assets for a neon arcade zombies upgrade
deck. The attached artwork is the established style: match it closely.

The upgrade belongs to a wizard who carries Lightning, Fire and Ice staffs.
It makes putting away and raising every staff THREE TIMES FASTER. It is a
permanent, one-time unlock available only at ULTIMATE rarity. It does not
increase firing speed, reload speed or damage.

## Deliverables

| Exact filename | Canvas | Exact baked text |
|---|---|---|
| `i_tod_card_mystical_hands_ultimate.png` | 768 x 1152 px | Title: `MYSTICAL HANDS`; ribbon: `ULTIMATE`; effect panel: `SWAP AND RAISE` / `STAFFS 3X FASTER` |
| `i_tod_pause_r56.png` | 300 x 44 px | `MYSTICAL HANDS` |

Deliver separate 8-bit RGBA PNGs with real transparency outside the frame.
Keep transparent corners; no white or checkerboard background, watermark,
mockup, contact sheet or extra canvas padding. Preserve the reference frame
dimensions and positions. Return the two files together in one ZIP.

## Reference guide

All full-resolution references are in `reference/`.

- `i_tod_card_deadshot_ultimate.png`: PRIMARY card layout. It is a one-time
  ultimate like this upgrade: its ribbon reads ULTIMATE alone and it has no
  level pips. Copy its navy chassis, rounded thick outline, gold/orange glow,
  screws, title plate, inset illustration, medal and effect panel.
- `i_tod_card_mage_arch_ultimate.png` and
  `i_tod_card_mage_blink_ultimate.png`: Mage deck illustration style and gold
  finish. Their +3 and level pips do NOT apply to this one-time unlock.
- `i_tod_pause_r53.png`: PRIMARY long-title plate. Match its dark navy pill,
  cyan left notch, bevel and chunky white outlined lettering. Its two-word
  name is a useful spacing reference for MYSTICAL HANDS.
- `i_tod_pause_r52.png`: confirm the same plate baseline and margins.

Cards display around 234 x 351 pixels: judge card readability in the portrait
preview folder. Plates display at 300 x 44: judge plates in the landscape
preview folder or the native reference. Each preview preserves the matching
asset's aspect ratio.

## Card prompt

Attach the three full-resolution card references listed above.

Create a sibling card titled MYSTICAL HANDS. Match the Deadshot card's frame,
layout and one-time ULTIMATE structure exactly, with the Mage references'
clean, bold illustrated style. In the illustration panel, show two clearly
readable magical gloved hands rapidly exchanging a staff, with a small number
of mint/cyan motion trails. Include clear violet lightning, orange fire and
icy blue accents to suggest the three staffs. Keep the silhouette bold and
uncluttered; no photorealism, extra fingers, weapon inventory UI or busy scene.
The focus is dexterous magical hands, not a firing projectile or an explosion.

Title, one line: MYSTICAL HANDS. Ribbon: ULTIMATE, without +3. Effect panel,
two centered lines: SWAP AND RAISE / STAFFS 3X FASTER. Use the established
chunky outlined lettering, white title and gold effect text. Fit the title
inside its existing plate; do not widen the frame. No pips, level number,
button hints, cooldown, rarity variants or other text.

Export as i_tod_card_mystical_hands_ultimate.png, 768 x 1152, RGBA.

## Nameplate prompt

Attach reference/i_tod_pause_r53.png and reference/i_tod_pause_r52.png.

Make their matching sibling reading MYSTICAL HANDS. Copy the 300 x 44 pixel
navy rounded pill, cyan notch, dark outline, inner bevel and white outlined
lettering. Replace only the words. Use one line, left-aligned after the notch,
with the same baseline and clear right margin. No icon, rarity ribbon, level,
number or subtitle. Transparent outside the pill.

Export as i_tod_pause_r56.png, 300 x 44, RGBA.

## Final checks

- Exactly two PNGs, correct names and exact dimensions.
- Both say MYSTICAL HANDS, spelled identically.
- The card says ULTIMATE, with no +3 and no level pips.
- The effect is exactly SWAP AND RAISE / STAFFS 3X FASTER.
- Readable at the displayed sizes and visually consistent with the references.
- Real alpha transparency; no baked checkerboard or opaque corners.
<!-- PACK:END -->
