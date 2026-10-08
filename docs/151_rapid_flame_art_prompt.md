# 151 — RAPID FLAME: three mage cards and a pause nameplate

<!-- art-pack
name: rapid_flame
refs:
  i_tod_card_mage_fire_regular.png | PRIMARY sibling, REGULAR rarity. Same staff, same class deck, same fire palette. The new card is its rate counterpart: copy frame, margins, pip row and type treatment exactly.
  i_tod_card_mage_fire_super.png | PRIMARY sibling, SUPER rarity. The ribbon and frame finish to match on the super card.
  i_tod_card_mage_fire_ultimate.png | PRIMARY sibling, ULTIMATE rarity. The ribbon and gold finish to match on the ultimate card.
  i_tod_card_mage_ice_regular.png | Second mage-deck card at the same rarity: confirms the shared chassis is not fire-specific and shows how a second element is coloured.
  i_tod_card_headshot_regular.png | The pip-row reference: a five-level upgrade drawn with exactly five pips, leftmost lit. RAPID FLAME is also five levels.
  i_tod_pause_r55.png | PRIMARY 300x44 pause plate: baseline, notch, bevel and margins.
  i_tod_pause_r56.png | Second 300x44 plate with a long two-word title (MYSTICAL HANDS): spacing reference for RAPID FLAME.
preview: 234x351 300x44
-->

Status: SHIPPED 2026-09-21 (v19.27). All four deliverables returned in
`files - 2026-09-21T115409.834.zip`, proofread, installed and wired: the three
`i_tod_card_mage_rate_*` cards and `i_tod_pause_r57` are in
`source_data/tod_ui_images/_images/`, each has a GDT block and a zone `image,`
line, `CARD_SLUG[57] = "mage_rate"` is set, and the contiguous plate ceiling
moved 56 -> 57 in BOTH `AetheriumStartMenu.lua` and `AetheriumScoreboard.lua`.
The LUI text fallback is retired for this domain.

The drop carried each deliverable TWICE - loose at the zip root and again under
`tod_rapid_flame_deliverables_unzipped/` - with different byte sizes and md5s.
Decoded to raw RGBA both copies are pixel-identical, so the difference is PNG
encoding only and either copy installs the same art; the loose set is installed.

Domain 57, internal key `mage_rate`, display name RAPID FLAME. Mage only,
tier 2+, band A, max 5, no dark form (`set_no_dark`). The effect lives in
`_tod_mage_elements::fire_recovery_ms`.

**Build this handoff with `tools/make_art_pack.ps1`.** When the drop arrives:
inspect all four images and their dimensions, add their image GDT blocks and
zone lines, set `CARD_SLUG[57] = "mage_rate"` in `tod_upgrade.lua`, and raise
`PAUSE_PLATE_MAX` from 56 to 57 in **both** `AetheriumStartMenu.lua` and
`AetheriumScoreboard.lua` (`TOD_UPG_PLATE_MAX`) — `lint_tod_assets` GATE D
fails the build if those two ever differ. Full build after installation.

⚠️ **Do not add `CARD_SLUG[57]` before the images are zoned.** `lint_tod_assets`
GATE A fails on a named-but-unzoned image and it is right to: the alternative
is a white square where the card should be. There is no `_dark` file in this
request and there must not be one — `DARK_NONE[57]` is already set.

⚠️ **THE EFFECT PANEL CARRIES NO NUMBER, BY STANDING RULE** (user 2026-09-02,
after four same-day retunes each owing a card re-bake: *"we need to convert to
generic text so this can be prevented in future where possible"*). The first cut
of this brief asked for `10% FASTER PER LEVEL` and that was wrong: the rate is a
tuning knob (`TOD_MAGE_FIRE_RATE_PER_LV`), so the next retune would falsify the
pixels. The live number lives in `DETAIL[57].val` and the armory. The pip COUNT
and the rarity ribbon are the only numbers that legitimately bake, because they
are structural rather than tuned.

⚠️ **The pause plate is why `r57` is in this request at all.** `PAUSE_PLATE_MAX`
is a CONTIGUOUS ceiling: without `i_tod_pause_r57.png` the ceiling stays at 56
and this domain's pause and scoreboard rows draw as plain text next to every
other row's nameplate.

<!-- PACK:BEGIN -->
# RAPID FLAME — four matching game UI assets

Create exactly four finished PNG assets for a neon arcade zombies upgrade
deck. The attached artwork is the established style: match it closely. Three
are rarity variants of one card; the fourth is a small nameplate.

The upgrade belongs to a wizard who carries Lightning, Fire and Ice staffs.
RAPID FLAME makes the FIRE staff SHOOT FASTER — 10% less time between shots
per level, so at level 5 it fires twice as often. It does not add damage,
does not change the other two staffs, and is not an explosion.

The three attached `i_tod_card_mage_fire_regular.png`,
`i_tod_card_mage_fire_super.png` and `i_tod_card_mage_fire_ultimate.png` cards
are the same wizard's FIRE STAFF DAMAGE card. This new card is its sibling: same staff, same palette, but the
subject is SPEED rather than force.

## Deliverables

| Exact filename | Canvas | Exact baked text |
|---|---|---|
| `i_tod_card_mage_rate_regular.png` | 768 x 1152 px | Title: `RAPID FLAME`; ribbon: `REGULAR +1`; effect panel: `FIRE STAFF` / `SHOOTS FASTER`; five level pips |
| `i_tod_card_mage_rate_super.png` | 768 x 1152 px | Title: `RAPID FLAME`; ribbon: `SUPER +2`; effect panel: `FIRE STAFF` / `SHOOTS FASTER`; five level pips |
| `i_tod_card_mage_rate_ultimate.png` | 768 x 1152 px | Title: `RAPID FLAME`; ribbon: `ULTIMATE +3`; effect panel: `FIRE STAFF` / `SHOOTS FASTER`; five level pips |
| `i_tod_pause_r57.png` | 300 x 44 px | `RAPID FLAME` |

Deliver separate 8-bit RGBA PNGs with real transparency outside the frame.
Keep transparent corners; no white or checkerboard background, watermark,
mockup, contact sheet or extra canvas padding. Preserve the reference frame
dimensions and positions. Return the four files together in one ZIP.

## Reference guide

All full-resolution references are in `reference/`.

- `i_tod_card_mage_fire_regular.png`, `i_tod_card_mage_fire_super.png` and
  `i_tod_card_mage_fire_ultimate.png`: the PRIMARY references and the direct
  sibling of this card, one per rarity. Copy the navy
  chassis, rounded thick outline, screws, title plate, inset illustration,
  medal, effect panel and the exact ribbon treatment of each rarity. Their
  orange-and-gold fire palette is this card's palette too.
- `i_tod_card_mage_ice_regular.png`: the same chassis on a different element,
  to confirm what belongs to the frame and what belongs to the subject.
- `i_tod_card_headshot_regular.png`: **the pip reference.** One pip per level of
  the upgrade, leftmost lit. It is a five-level upgrade and so is this one, so
  copy its pip row exactly: FIVE pips.
- `i_tod_pause_r55.png`: PRIMARY nameplate. Match its dark navy pill, cyan
  left notch, bevel and chunky white outlined lettering.
- `i_tod_pause_r56.png`: a long two-word title on the same plate; useful
  spacing reference for RAPID FLAME.

Cards display around 234 x 351 pixels: judge card readability in the portrait
preview folder. Plates display at 300 x 44: judge plates in the landscape
preview folder. Each preview preserves the matching asset's aspect ratio.

## Card prompt

Attach reference/i_tod_card_mage_fire_regular.png,
reference/i_tod_card_mage_fire_super.png,
reference/i_tod_card_mage_fire_ultimate.png and
reference/i_tod_card_headshot_regular.png.

Create a sibling card titled RAPID FLAME, in three rarity variants that differ
ONLY in the ribbon and the frame finish, exactly as the three attached fire
cards differ from each other.

In the illustration panel, show the wizard's fire staff loosing a rapid BURST
of small flame bolts — three or four compact bolts in a row receding into the
panel, each with a short mint/cyan speed streak behind it. The idea to read
instantly is CADENCE: many quick shots, not one big blast. Keep the flame
orange and gold like the attached fire cards. Keep the silhouette bold and
uncluttered; no photorealism, no explosion or fireball, no muzzle bloom filling
the panel, no clock, stopwatch, speedometer, gauge, numeral or arrow icon, no
hands, no busy scene.

Title, one line: RAPID FLAME. Effect panel, two centered lines:
FIRE STAFF / SHOOTS FASTER. **No percentage, no number and no use of the word
"level" in the effect panel** - it reads identically on all three rarities,
exactly like the attached fire cards' BURNS ROBOTS AND ARMOR. Five level pips in
the established pip row. Ribbon: REGULAR +1, SUPER +2 or ULTIMATE +3 to match the attached
card of that rarity. Use the established chunky outlined lettering, white
title and gold effect text. Fit the title inside its existing plate; do not
widen the frame. No button hints, cooldown, damage number or other text.

Export as i_tod_card_mage_rate_regular.png, i_tod_card_mage_rate_super.png and
i_tod_card_mage_rate_ultimate.png, each 768 x 1152, RGBA.

## Nameplate prompt

Attach reference/i_tod_pause_r55.png and reference/i_tod_pause_r56.png.

Make their matching sibling reading RAPID FLAME. Copy the 300 x 44 pixel navy
rounded pill, cyan notch, dark outline, inner bevel and white outlined
lettering. Replace only the words. Use one line, left-aligned after the notch,
with the same baseline and clear right margin. No icon, rarity ribbon, level,
number or subtitle. Transparent outside the pill.

Export as i_tod_pause_r57.png, 300 x 44, RGBA.

## Final checks

- Exactly four PNGs, correct names and exact dimensions.
- All four say RAPID FLAME, spelled identically.
- The effect panel carries NO percentage and NO level count, on all three cards.
- FIVE pips on every card, not six.
- The three cards differ ONLY in ribbon text and frame finish.
- No `_dark` variant — it is not wanted and will not be used.
- Transparent outside the card frame and outside the plate pill.
<!-- PACK:END -->
