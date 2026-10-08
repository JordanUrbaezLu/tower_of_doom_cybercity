# 78 — RECOIL card re-bake (3 images): generic value line, no baked number

<!-- art-pack
name: recoil_15pct
refs:
  i_tod_card_recoil_regular.png | the CURRENT REGULAR card, value line "-10% RECOIL": replace the whole value line with the generic text. Attach to Prompt A.
  i_tod_card_recoil_super.png | the CURRENT SUPER card, value line "-20% RECOIL": same edit, purple lettering. Attach to Prompt B.
  i_tod_card_recoil_ultimate.png | the CURRENT ULTIMATE card, value line "-20% RECOIL": same edit, gold lettering. Attach to Prompt C.
  i_tod_card_run_and_gun_regular.png | a card from the same deck whose value line is GENERIC (no number): the lettering size, weight and colour to match. Attach to every prompt.
preview: 213x320
-->

> **STATUS: SHIPPED v16.54, 2026-09-02 19:08 — UNPLAYED.** Drop `files - 2026-09-02T190025.581.zip`; per-pixel diff vs shipped: 7.1–7.8k px, bbox x 232–535 y 898–939 (value line only); 3 fresh content-hash `.iwi`. RECOIL is GENERIC now. Pack was built
> by `.\tools\make_art_pack.ps1 docs\78_recoil_15pct_art_prompt.md` →
> `~/Downloads/tod_recoil_15pct_art_pack.zip` (also inside the combined
> `tod_card_retunes_2026-09-02_art_pack.zip`). Install = same three filenames
> over the shipped ones (no GDT / zone / Lua wiring), FULL build, proof =
> fresh content-hash `.iwi` for all three beside an untouched control.

**Why (user, 2026-09-02):** *"Buff recoil to 15%"* — and then, on the cards:
*"convert to generic text so this can be prevented in future where
possible."* RECOIL is a TWIN domain: the number is `RECOIL_STEP` in
`tools/gen_tod_twins.js` ([1, 0.90, 0.80] → [1, 0.85, 0.70]), regenerated into
the weapon GDT (v16.50: 752 kick-key lines moved in exactly two ratio buckets,
×0.9444 and ×0.875, the zpkg byte-identical — same asset names, same
registration count). The shipped cards bake −10 / −20 / −20, so they now
advertise the wrong number — and every future retune would do it again. The
fix is to take the number OFF the card: the value line becomes **`LESS KICK`**
on all three rarities, and the pause menu (`DETAIL[17]`, live text) carries
the actual percentages. Pips stay at TWO (max 2).

<!-- PACK:BEGIN -->
# RECOIL cards — value line re-bake (3 images)

## What this is

Three upgrade cards from a Call of Duty: Black Ops 3 zombies map, one per
rarity, drawn at **213 × 320 px on screen** (see `preview_onscreen_213x320/`).
Each card's value plate currently prints a percentage. The game no longer
wants a number on this card at all: the line becomes a short generic phrase.
**Nothing else on any card changes.**

**Deliver exactly THREE files, same names as the attached originals:**

| Deliver as | Rarity | Value line currently | Value line must read |
|---|---|---|---|
| `i_tod_card_recoil_regular.png` | REGULAR +1 | `-10% RECOIL` | **`LESS KICK`** |
| `i_tod_card_recoil_super.png` | SUPER +2 | `-20% RECOIL` | **`LESS KICK`** |
| `i_tod_card_recoil_ultimate.png` | ULTIMATE +3 | `-20% RECOIL` | **`LESS KICK`** |

The text is IDENTICAL on all three; only its colour differs per rarity.

## References (in `reference/`)

- `i_tod_card_recoil_regular.png`, `_super.png`, `_ultimate.png` — the CURRENT
  three cards. Everything on them is correct except the value line.
- `i_tod_card_run_and_gun_regular.png` — a card from the same deck whose value
  line is a generic phrase with no number. Its lettering — chunky all-caps,
  dark outline, one weight, one size — is what the new line must look like.
  (It uses two lines because its phrase is long; ours is short, ONE line.)
- `preview_onscreen_213x320/` — all four at their real on-screen size.

## The one change

In the dark value plate near the bottom of each card, replace the whole line
`-NN% RECOIL` with **`LESS KICK`**: ONE centred line, the same chunky all-caps
outlined face the deck uses, one size and weight, coloured per rarity — pale
grey-blue on REGULAR, purple/lavender on SUPER, gold/amber on ULTIMATE (sample
the colour from each attached card's current line). The phrase is short, so
it may be set a little larger than the current line, but no wider than the
current line's extent. No second line.

## Hard rules

- Canvas exactly **768 × 1152 px**, PNG, RGBA, fully transparent outside the
  card edge, identical margin to the attached files. Decode the corner pixel:
  it must be (0,0,0,0).
- **Everything except the value-line text is pixel-for-pixel the attached
  card**: the rifle illustration with its amber recoil arcs, the title plate
  `RECOIL`, the rarity ribbon, the medal, the rails, the outer glow, the
  TWO-socket pip row and its lit count (1 on REGULAR, 2 on SUPER and
  ULTIMATE), the ULTIMATE's scattered gold sparkles.
- **No digits anywhere** except the `+1 / +2 / +3` in the rarity ribbon. The
  value line carries NO number on purpose.
- No other text, no subtitle, no "MAX", no "per level".

## Prompt A — `i_tod_card_recoil_regular.png`

Attach `reference/i_tod_card_recoil_regular.png` AND
`reference/i_tod_card_run_and_gun_regular.png`.

```text
Two upgrade cards from a Black Ops 3 zombies map are attached. Edit the FIRST
one (RECOIL) and deliver it at exactly 768 x 1152 pixels, PNG, RGBA,
transparent outside the card, same margin as the original.

Make exactly ONE change: in the dark value plate near the bottom, the text
"-10% RECOIL" is replaced by "LESS KICK" - one centred line, all caps, in the
same chunky outlined lettering the SECOND attached card uses for its value
line, one size and one weight, in the pale grey-blue the first card's line
currently uses, with the same dark outline. No number in it, nothing beneath
it.

Everything else stays pixel-for-pixel as in the original: the rifle, the
RECOIL title plate, the silver REGULAR +1 ribbon, the medal, the cyan rails,
the two pip sockets with the first one lit. No other text, no digits except
the +1 in the ribbon. Deliver as i_tod_card_recoil_regular.png.
```

## Prompt B — `i_tod_card_recoil_super.png`

Attach `reference/i_tod_card_recoil_super.png` AND
`reference/i_tod_card_run_and_gun_regular.png`.

```text
Two upgrade cards are attached. Edit the FIRST one (RECOIL, purple SUPER +2)
and deliver it at exactly 768 x 1152 pixels, PNG, RGBA, transparent outside
the card, keeping its purple outer glow.

Make exactly ONE change: in the dark value plate near the bottom, the text
"-20% RECOIL" is replaced by "LESS KICK" - one centred line, all caps, the
second card's chunky outlined lettering, one size and weight, in the
purple/lavender the first card's line currently uses. No number in it, nothing
beneath it.

Everything else stays pixel-for-pixel as in the original, including the two
pip sockets, both lit. Deliver as i_tod_card_recoil_super.png.
```

## Prompt C — `i_tod_card_recoil_ultimate.png`

Attach `reference/i_tod_card_recoil_ultimate.png` AND
`reference/i_tod_card_run_and_gun_regular.png`.

```text
Two upgrade cards are attached. Edit the FIRST one (RECOIL, gold ULTIMATE +3)
and deliver it at exactly 768 x 1152 pixels, PNG, RGBA, transparent outside
the card, keeping its gold outer glow and scattered sparkles.

Make exactly ONE change: in the dark value plate near the bottom, the text
"-20% RECOIL" is replaced by "LESS KICK" - one centred line, all caps, the
second card's chunky outlined lettering, one size and weight, in the
gold/amber the first card's line currently uses. No number in it, nothing
beneath it.

Everything else stays pixel-for-pixel as in the original, including the two
pip sockets, both lit. Deliver as i_tod_card_recoil_ultimate.png.
```

## Delivery checklist

- [ ] Three files, named exactly as the table above
- [ ] 768 × 1152, RGBA, corner pixel fully transparent — decode it
- [ ] Value line reads `LESS KICK` on all three — identical text, colour only
      differs, NO digits in it, one line
- [ ] Overlay each file on its original: nothing outside the value plate's
      text changes
- [ ] Pip rows untouched: two sockets, lit 1 / 2 / 2

## Do NOT

- Do not redraw or move the illustration, title, ribbon, medal or plate.
- Do not keep, shrink or restyle the percentage — the number is gone.
- Do not add a second line, "MAX", "per level", or any digit to the plate.
- Do not add a third pip — the upgrade has two levels.
- Do not hand back a different canvas size, a cropped card or an opaque
  background.
- Do not deliver one or two of the set — the three ship together or not at all.
<!-- PACK:END -->

## Install (when the drop lands)

1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'`; LOOK at all three;
   proofread `LESS KICK`; per-pixel diff against the shipped files — changed
   pixels only inside the value plate.
2. Copy over the three files in `source_data/tod_ui_images/_images/` (same
   names; no GDT / zone / Lua edits).
3. FULL build. Proof: NEW content-hash `.iwi` for all three
   `i_tod_card_recoil_*` with fresh mtimes, beside an untouched control.
4. Flip this STATUS to SHIPPED with the build version; CHANGELOG entry;
   docs/33 art audit row (RECOIL joins the generic set — a future
   `RECOIL_STEP` retune owes no re-bake).
