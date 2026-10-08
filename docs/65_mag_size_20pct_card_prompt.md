# 65 — MAG SIZE card re-bake: +20 / +40 / +60% (v16.14, 2026-09-01)

**STATUS: LANDED 2026-09-01 (v16.17).** The three cards below now read +20 / +40 / +60%. Kept as the record of the retune.

**Why:** the user nerfed MAG SIZE from +30%/Lv to +20%/Lv (`MAG_STEP` in
`tools/gen_tod_twins.js` is now `[1, 1.2, 1.4, 1.6]`). The three card PNGs
bake the OLD numbers as pixels — "+30% MAGAZINE" / "+60% MAGAZINE" /
"+90% MAGAZINE" — and the card is the only place a player ever reads the
value (docs/33). Until these three files are replaced the card overstates the
magazine by a third.

**Files to replace (same names, same pixel dimensions as the existing PNGs):**

```
source_data/tod_ui_images/_images/i_tod_card_mag_size_regular.png    "+30% MAGAZINE" -> "+20% MAGAZINE"
source_data/tod_ui_images/_images/i_tod_card_mag_size_super.png      "+60% MAGAZINE" -> "+40% MAGAZINE"
source_data/tod_ui_images/_images/i_tod_card_mag_size_ultimate.png   "+90% MAGAZINE" -> "+60% MAGAZINE"
```

Install = drop the three PNGs over the existing ones, then a **FULL build**
(image assets convert through the GDT; see CLAUDE.md "a .gdt edit is ALWAYS a
full build" — an image swap is the same lane). No GDT, zone or Lua change:
the asset names, the `CARD_SLUG[7] = "mag_size"` slug and the zone lines are
untouched.

**Nothing else on the card changes.** Keep the existing art exactly — the
orange title band "MAG SIZE", the navy magazine with three orange bullet tips
and the yellow ⊕ badge, the rarity ribbon (silver REGULAR +1 / SUPER +2 /
gold ULTIMATE +3 with its gold frame glow and sparkles), the three pips, the
lower plate. Only the plate text moves.

## Paste prompt (one card at a time; swap the bracketed line)

> Edit the attached trading-card image. Change ONLY the text on the dark
> lower plate: replace "**+30% MAGAZINE**" with "**+20% MAGAZINE**". Keep
> the exact same font, weight, size, letter-spacing, colour, outline and
> position — the new string is the same length, so it must sit exactly
> where the old one did. Do not touch the title band, the magazine
> illustration, the rarity ribbon, the pips, the frame, the glow or the
> background. Output at the original pixel dimensions with the same
> transparent margin.
>
> [super card: replace "+60% MAGAZINE" with "+40% MAGAZINE"]
> [ultimate card: replace "+90% MAGAZINE" with "+60% MAGAZINE"]

## Optional, if re-baking anyway

docs/63's enhancement list flagged this card as "navy on navy" — a navy
magazine on a navy plate — and asked for **a steel magazine in a light
metal**. If the bake is being redone from scratch rather than text-edited,
that is the one change worth folding in; it is cosmetic and nothing in the
game reads it.

## Lockstep record (all done in v16.14)

| Place | Was | Now |
|---|---|---|
| `tools/gen_tod_twins.js` `MAG_STEP` | `[1, 1.3, 1.6, 1.9]` | `[1, 1.2, 1.4, 1.6]` |
| `_tod_upgrades.gsc` `add_domain("magsize")` desc | `real mag +30/+60/+90%` | `real mag +20/+40/+60%` |
| `tod_upgrade.lua` `DOMAIN[7].desc` | `real mag +30/+60/+90%` | `real mag +20/+40/+60%` |
| `tod_upgrade.lua` `DETAIL[7].val` | `30 * l` | `20 * l` |
| `docs/armory.html` magsize row | 30/60/90 | 20/40/60 |
| card PNGs ×3 | +30/+60/+90% | **DONE 2026-09-01 — `files (89).zip`, redrawn (steel/gold magazine per docs/63), shipped v16.17** |
