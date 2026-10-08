# Thunder Smash upgrade cards and ability icon

<!-- art-pack
name: thunder_smash
refs:
  i_tod_card_thors_thunder_regular.png | Primary Slasher lightning card: copy the regular frame, type, margins and electric palette.
  i_tod_card_thors_thunder_super.png | Super rarity treatment for the same deck.
  i_tod_card_thors_thunder_ultimate.png | Ultimate rarity treatment for the same deck.
  i_tod_card_cleave_regular.png | Three-level pip row; Thunder Smash has three levels, unlike Thor's Thunder.
  i_tod_hud_gun_axe.png | The existing Stormbreaker weapon identity and chunky HUD rendering style.
  i_tod_hud_off_blink.png | Primary Mage ability glyph reference: silhouette, dark outline, highlights and transparent canvas.
  i_tod_hud_off_heal.png | Second Mage ability glyph: match the same visual weight.
  i_tod_hud_offhand_tile.png | Existing ability tile that will contain the new glyph; reference only, do not replace it.
  i_tod_pause_r56.png | Existing pause nameplate chassis and long two-word title spacing.
preview: 234x351 24x24 46x32 300x44
-->

Status: REQUESTED 2026-09-21. User requested a Mage-style ability layout and
an asset request ZIP. Build with `tools/make_art_pack.ps1` after every edit.

Registered domain 58, key `thunder_smash`: Slasher tier 3, Stormbreaker only.
Drawing the card unlocks tactical/LB; three levels start from Hellbound's
45/35/25-second cooldown. No dark form in this initial implementation.
Movement reuses the gold sword's bounded hop; the weapon motion is the bat's
lunge with Stormbreaker held. Combat uses existing thunder/Gravity Spikes
effects and sounds; this handoff requests UI artwork only.

Install only after inspecting the returned PNGs. Add image GDT/zone entries
before CARD_SLUG[58] or the HUD image registration. Until then use live text
fallbacks. The HUD reuses the existing tactical tile and code-drawn cooldown
border, with the same binding-aware tutorial overlay as Mage abilities.
Do not bake LB, a cooldown, or damage figures into the artwork.

Pause plate ceiling is contiguous: r57 is still requested separately in
docs/151. Do not raise PAUSE_PLATE_MAX/TOD_UPG_PLATE_MAX to 58 until both r57
and r58 exist and are zoned; keep text fallback meanwhile. Full build after
art installation. Do not request a replacement weapon panel or new key art.

<!-- PACK:BEGIN -->
# THUNDER SMASH — five matching game UI assets

Create five finished PNGs for an existing neon arcade zombies game. Match
the supplied references closely. Three are upgrade-card rarity variants,
one is a small ability glyph, and one is a pause-menu nameplate.

THUNDER SMASH is an active ability for a warrior carrying Stormbreaker,
the heavy hammer/axe represented by the supplied weapon glyph. The player
jumps forward, swings the weapon down, and lands in a bright electric
shockwave. Lightning strikes and blue-white arcs spread from the impact.
The first upgrade unlocks the ability; later upgrades shorten its cooldown
and strengthen it. This is a ground slam with a weapon, not a staff attack.

## Deliverables

| Exact filename | Canvas | Exact baked text |
|---|---|---|
| `i_tod_card_thunder_smash_regular.png` | 768 x 1152 | Title `THUNDER SMASH`; ribbon `REGULAR +1`; effect `LEAP INTO A THUNDER SLAM`; three level pips |
| `i_tod_card_thunder_smash_super.png` | 768 x 1152 | Title `THUNDER SMASH`; ribbon `SUPER +2`; effect `LEAP INTO A THUNDER SLAM`; three level pips |
| `i_tod_card_thunder_smash_ultimate.png` | 768 x 1152 | Title `THUNDER SMASH`; ribbon `ULTIMATE +3`; effect `LEAP INTO A THUNDER SLAM`; three level pips |
| `i_tod_hud_off_thunder_smash.png` | 128 x 128 | No text |
| `i_tod_pause_r58.png` | 300 x 44 | `THUNDER SMASH` |

Deliver separate 8-bit RGBA PNGs with real transparency outside the artwork.
Return all five in one ZIP. No extra padding, white background, checkerboard,
watermark, mockup, contact sheet, ready/locked variations or dark-rarity card.

## Card prompt

Attach `reference/i_tod_card_thors_thunder_regular.png`,
`reference/i_tod_card_thors_thunder_super.png`,
`reference/i_tod_card_thors_thunder_ultimate.png`,
`reference/i_tod_card_cleave_regular.png`, and
`reference/i_tod_hud_gun_axe.png`.

Make three sibling cards titled THUNDER SMASH. Copy the Thor's Thunder
card chassis, outline, screws, inset illustration, title plate, medal,
effect panel and rarity ribbon positions. Use the matching reference for
each rarity's finish. Use the CLEAVE reference's THREE-pip layout.

The illustration shows a heavy Stormbreaker-like weapon striking downward
into a circular electric ground shockwave. Give it a bold hammer/axe head,
a short readable handle, cyan-white lightning forks and a violet electric
halo. A curved motion trail should suggest a jumping downward slam. Keep
the subject large and uncluttered, with the existing chunky outlines and
flat arcade shading. The impact and outward lightning should distinguish
this active slam from the Thor's Thunder card's cloud-and-bolt illustration.
No full character, hands, staff, gold sword, baseball bat, superhero logo,
photorealism or busy scenery.

Bake only: THUNDER SMASH, the matching rarity ribbon, and
LEAP INTO A THUNDER SLAM in the effect panel. Fit the effect on one or two
centered lines within the existing panel. Use the supplied type treatment.
Do not bake an input button, cooldown, damage number or level numeral.
The three cards share the same illustration and differ only in the normal
rarity treatment and pip emphasis. Judge readability at 234 x 351 pixels.

## Ability glyph prompt

Attach `reference/i_tod_hud_off_blink.png`,
`reference/i_tod_hud_off_heal.png`, `reference/i_tod_hud_gun_axe.png`, and
`reference/i_tod_hud_offhand_tile.png`.

Create a matching square ability glyph: a heavy hammer/axe head angled down
into one compact cyan lightning impact, with a small violet accent. It must
read as THUNDER SMASH at only 24 x 24 pixels. Match the Mage icons' very thick
navy outline, pale face, simple angular highlights and strong silhouette.
Use broad solid shapes and at most two lightning branches; avoid fine sparks.
Center the glyph on a 128 x 128 transparent canvas with similar clear margins.
The existing tile is context only: do not bake its background into the glyph.
No words, letters, LB symbol, keycap, number, cooldown ring or separate states.

## Nameplate prompt

Attach `reference/i_tod_pause_r56.png`.

Copy its 300 x 44 dark navy pill, cyan notch, bevel, outline and chunky white
lettering. Replace the words with THUNDER SMASH on one line, keeping the
baseline and margins. Transparent outside the pill. No icon, level, rarity,
subtitle or number.

## Delivery checklist

- Exactly five PNGs with the exact names, sizes and RGBA format above.
- All three cards say THUNDER SMASH and LEAP INTO A THUNDER SLAM identically.
- THREE pips on every card, with the supplied deck's rarity emphasis.
- Glyph remains clear at 24 x 24; nameplate remains clear at 300 x 44.
- Real alpha outside frames/glyph; no checkerboard baked into transparency.
- No button labels or balance numbers baked into any file.
- One ZIP containing the five individual files.
<!-- PACK:END -->
