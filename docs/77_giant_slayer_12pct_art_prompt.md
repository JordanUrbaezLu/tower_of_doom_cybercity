# 77 — GIANT SLAYER card re-bake (3 images): generic value line, no baked number

<!-- art-pack
name: giant_slayer_12pct
refs:
  i_tod_card_giant_slayer_regular.png | the CURRENT REGULAR card, value line "+15%  BOSS DAMAGE": replace the whole value line with the generic text. Attach to Prompt A.
  i_tod_card_giant_slayer_super.png | the CURRENT SUPER card, value line "+30%  BOSS DAMAGE": same edit, purple lettering. Attach to Prompt B.
  i_tod_card_giant_slayer_ultimate.png | the CURRENT ULTIMATE card, value line "+45%  BOSS DAMAGE": same edit, gold lettering. Attach to Prompt C.
  i_tod_card_run_and_gun_regular.png | a card from the same deck whose value line is GENERIC (no number): the lettering size, weight and colour to match. Attach to every prompt.
preview: 213x320
-->

> **STATUS: SHIPPED v16.54, 2026-09-02 19:08 — UNPLAYED.** Drop `files - 2026-09-02T190025.581.zip`; per-pixel diff vs shipped: ~12k px, bbox x 170–598 y 898–940 (value line only); 3 fresh content-hash `.iwi`. GIANT SLAYER is GENERIC now. Pack was built
> by `.\tools\make_art_pack.ps1 docs\77_giant_slayer_12pct_art_prompt.md` →
> `~/Downloads/tod_giant_slayer_12pct_art_pack.zip` (also inside the combined
> `tod_card_retunes_2026-09-02_art_pack.zip`). Install = same three filenames
> over the shipped ones (no GDT / zone / Lua wiring), FULL build, proof =
> fresh content-hash `.iwi` for all three beside an untouched control.

**Why (user, 2026-09-02):** *"nerf giant slayer to 12% each tier"* — and then,
on the cards: *"convert to generic text so this can be prevented in future
where possible."* The code is `TOD_UPG_BOSSDMG_PER_LVL` 0.15 → 0.12
(`_tod_upgrades.gsc`), the Lua rows and the armory all moved in v16.50. The
shipped cards bake +15 / +30 / +45, so they advertise a number the game no
longer pays — and every future retune would do it again. The fix is to take
the number OFF the card: the value line becomes **`HIT BOSSES HARDER`** on all
three rarities, and the pause menu (`DETAIL[35]`, live text) carries the
actual percentage. House precedent: `FREE SHOTS + BONUS DAMAGE ON THE MOVE`,
`PIERCE HEAVIER COVER`, `AMMO BACK ON KILLS`, and every ATHLETE card.

<!-- PACK:BEGIN -->
# GIANT SLAYER cards — value line re-bake (3 images)

## What this is

Three upgrade cards from a Call of Duty: Black Ops 3 zombies map, one per
rarity, drawn at **213 × 320 px on screen** (see `preview_onscreen_213x320/`).
Each card's value plate currently prints a percentage. The game no longer
wants a number on this card at all: the line becomes a short generic phrase.
**Nothing else on any card changes.**

**Deliver exactly THREE files, same names as the attached originals:**

| Deliver as | Rarity | Value line currently | Value line must read |
|---|---|---|---|
| `i_tod_card_giant_slayer_regular.png` | REGULAR +1 | `+15%  BOSS DAMAGE` | **`HIT BOSSES HARDER`** |
| `i_tod_card_giant_slayer_super.png` | SUPER +2 | `+30%  BOSS DAMAGE` | **`HIT BOSSES HARDER`** |
| `i_tod_card_giant_slayer_ultimate.png` | ULTIMATE +3 | `+45%  BOSS DAMAGE` | **`HIT BOSSES HARDER`** |

The text is IDENTICAL on all three; only its colour differs per rarity.

## References (in `reference/`)

- `i_tod_card_giant_slayer_regular.png`, `_super.png`, `_ultimate.png` — the
  CURRENT three cards. Everything on them is correct except the value line.
- `i_tod_card_run_and_gun_regular.png` — a card from the same deck whose value
  line is a generic phrase with no number (`FREE SHOTS + BONUS DAMAGE / ON THE
  MOVE`). Its lettering — chunky all-caps, dark outline, one weight, one
  size — is what the new line must look like. This one happens to use two
  lines because its phrase is long; ours is short and stays on ONE line.
- `preview_onscreen_213x320/` — all four at their real on-screen size.

## The one change

In the dark value plate near the bottom of each card, replace the whole line
`+NN%  BOSS DAMAGE` with **`HIT BOSSES HARDER`**: ONE centred line, the same
chunky all-caps outlined face the deck uses, ONE size and weight throughout
(no larger "number" glyphs any more, since there is no number), coloured per
rarity — pale grey-blue on REGULAR, purple/lavender on SUPER, gold/amber on
ULTIMATE (sample the colour from each attached card's current number). No
second line.

## Hard rules

- Canvas exactly **768 × 1152 px**, PNG, RGBA, fully transparent outside the
  card edge, identical margin to the attached files. Decode the corner pixel:
  it must be (0,0,0,0).
- **Everything except the value-line text is pixel-for-pixel the attached
  card**: the robot illustration, the title plate `GIANT SLAYER`, the rarity
  ribbon, the medal, the rails, the outer glow, the five-socket pip row and its
  lit count (1 / 2 / 3), the ULTIMATE's scattered gold sparkles.
- **No digits anywhere** except the `+1 / +2 / +3` in the rarity ribbon. The
  value line carries NO number on purpose.
- No other text, no subtitle, no "per level".

## Prompt A — `i_tod_card_giant_slayer_regular.png`

Attach `reference/i_tod_card_giant_slayer_regular.png` AND
`reference/i_tod_card_run_and_gun_regular.png`.

```text
Two upgrade cards from a Black Ops 3 zombies map are attached. Edit the FIRST
one (GIANT SLAYER) and deliver it at exactly 768 x 1152 pixels, PNG, RGBA,
transparent outside the card, same margin as the original.

Make exactly ONE change: in the dark value plate near the bottom, the text
"+15%  BOSS DAMAGE" is replaced by "HIT BOSSES HARDER" - one centred line, all
caps, in the same chunky outlined lettering the SECOND attached card uses for
its value line, one size and one weight throughout, in the pale grey-blue the
first card's number currently uses, with the same dark outline. No number in
it, nothing beneath it.

Everything else stays pixel-for-pixel as in the original: the robot
illustration, the GIANT SLAYER title plate, the silver REGULAR +1 ribbon, the
medal, the cyan rails, the five pip sockets with the first one lit. No other
text, no digits except the +1 in the ribbon. Deliver as
i_tod_card_giant_slayer_regular.png.
```

## Prompt B — `i_tod_card_giant_slayer_super.png`

Attach `reference/i_tod_card_giant_slayer_super.png` AND
`reference/i_tod_card_run_and_gun_regular.png`.

```text
Two upgrade cards are attached. Edit the FIRST one (GIANT SLAYER, purple
SUPER +2) and deliver it at exactly 768 x 1152 pixels, PNG, RGBA, transparent
outside the card, keeping its purple outer glow.

Make exactly ONE change: in the dark value plate near the bottom, the text
"+30%  BOSS DAMAGE" is replaced by "HIT BOSSES HARDER" - one centred line, all
caps, the second card's chunky outlined lettering, one size and weight, in the
purple/lavender the first card's number currently uses. No number in it,
nothing beneath it.

Everything else stays pixel-for-pixel as in the original, including the five
pip sockets with the first two lit. Deliver as
i_tod_card_giant_slayer_super.png.
```

## Prompt C — `i_tod_card_giant_slayer_ultimate.png`

Attach `reference/i_tod_card_giant_slayer_ultimate.png` AND
`reference/i_tod_card_run_and_gun_regular.png`.

```text
Two upgrade cards are attached. Edit the FIRST one (GIANT SLAYER, gold
ULTIMATE +3) and deliver it at exactly 768 x 1152 pixels, PNG, RGBA,
transparent outside the card, keeping its gold outer glow and scattered
sparkles.

Make exactly ONE change: in the dark value plate near the bottom, the text
"+45%  BOSS DAMAGE" is replaced by "HIT BOSSES HARDER" - one centred line, all
caps, the second card's chunky outlined lettering, one size and weight, in the
gold/amber the first card's number currently uses. No number in it, nothing
beneath it.

Everything else stays pixel-for-pixel as in the original, including the five
pip sockets with the first three lit. Deliver as
i_tod_card_giant_slayer_ultimate.png.
```

## Delivery checklist

- [ ] Three files, named exactly as the table above
- [ ] 768 × 1152, RGBA, corner pixel fully transparent — decode it
- [ ] Value line reads `HIT BOSSES HARDER` on all three — identical text,
      colour only differs, NO digits in it, one line
- [ ] Overlay each file on its original: nothing outside the value plate's
      text changes
- [ ] Pip rows untouched: five sockets, lit 1 / 2 / 3

## Do NOT

- Do not redraw or move the illustration, title, ribbon, medal or plate.
- Do not keep, shrink or restyle the percentage — the number is gone.
- Do not add a second line, "per level", "MAX", or any digit to the plate.
- Do not touch the pip row.
- Do not hand back a different canvas size, a cropped card or an opaque
  background.
- Do not deliver one or two of the set — the three ship together or not at all.
<!-- PACK:END -->

## Install (when the drop lands)

1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'`; LOOK at all three;
   proofread `HIT BOSSES HARDER`; per-pixel diff against the shipped files —
   changed pixels only inside the value plate.
2. Copy over the three files in `source_data/tod_ui_images/_images/` (same
   names; no GDT / zone / Lua edits).
3. FULL build. Proof: NEW content-hash `.iwi` for all three
   `i_tod_card_giant_slayer_*` with fresh mtimes, beside an untouched control.
4. Flip this STATUS to SHIPPED with the build version; CHANGELOG entry;
   docs/33 art audit row (GIANT SLAYER joins the generic set — future retunes
   owe no re-bake).
