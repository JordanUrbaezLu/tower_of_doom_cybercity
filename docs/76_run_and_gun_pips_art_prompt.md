# 76 — RUN AND GUN card re-bake (3 images): five pips

<!-- art-pack
name: run_and_gun_pips
refs:
  i_tod_card_run_and_gun_regular.png | the CURRENT REGULAR card: keep everything, change ONLY the pip row (3 sockets -> 5, first lit). Attach to Prompt A.
  i_tod_card_run_and_gun_super.png | the CURRENT SUPER card: same edit, 5 sockets, first TWO lit purple-white. Attach to Prompt B.
  i_tod_card_run_and_gun_ultimate.png | the CURRENT ULTIMATE card: same edit, 5 sockets, first THREE lit gold. Attach to Prompt C.
  i_tod_card_giant_slayer_regular.png | a card from the same deck whose upgrade has FIVE levels: its pip row (5 sockets, first lit) is the exact target. Attach to every prompt.
preview: 213x320
-->

> **STATUS: SHIPPED v16.54, 2026-09-02 19:08 — UNPLAYED.** Drop `files - 2026-09-02T190025.581.zip`; per-pixel diff vs shipped: 2.2–3.6k px, bbox y 1006–1049 (pip row only); 3 fresh content-hash `.iwi`. Pack was built
> by `.\tools\make_art_pack.ps1 docs\76_run_and_gun_pips_art_prompt.md` →
> `~/Downloads/tod_run_and_gun_pips_art_pack.zip`. Install = same three
> filenames over the shipped ones (no GDT / zone / Lua wiring), FULL build,
> proof = fresh content-hash `.iwi` for all three beside an untouched control.

**Why (user, 2026-09-02):** *"make run and gun 5 tiers. 16% 28% 38% 46% 52%"*.
The v16.50 code does that (domain max 3 → 5, stage table in both GSC files and
the Lua). The shipped cards carry a generic value line — `FREE SHOTS + BONUS
DAMAGE ON THE MOVE`, no number — so they stay TRUE; the only stale element is
the **pip row: three sockets on a five-level domain**. The deck's rule (memory:
domain-retune checklist, read off the PNGs): max ≤ 6 → pips = the domain's
max; lit count = the rarity's +1/+2/+3. GIANT SLAYER (max 5) is the model.

FORCED MARCH went 3 → 5 in v14.x and kept its three pips "by design"; this
brief follows the rule instead. If the user prefers the FORCED MARCH precedent,
skip the pack — nothing else depends on it.

<!-- PACK:BEGIN -->
# RUN AND GUN cards — pip row re-bake (3 images)

## What this is

Three upgrade cards from a Call of Duty: Black Ops 3 zombies map, one per
rarity, drawn at **213 × 320 px on screen** (see `preview_onscreen_213x320/`).
The upgrade they describe grew from three levels to five, so the row of small
round "pip" sockets at the very bottom of each card must grow from THREE to
FIVE. **Nothing else on the card changes.**

**Deliver exactly THREE files, same names as the attached originals:**

| Deliver as | Rarity | Pips |
|---|---|---|
| `i_tod_card_run_and_gun_regular.png` | REGULAR +1 | 5 sockets, **first 1 lit** white, 4 dark |
| `i_tod_card_run_and_gun_super.png` | SUPER +2 | 5 sockets, **first 2 lit** purple-white, 3 dark |
| `i_tod_card_run_and_gun_ultimate.png` | ULTIMATE +3 | 5 sockets, **first 3 lit** gold, 2 dark |

## References (in `reference/`)

- `i_tod_card_run_and_gun_regular.png`, `_super.png`, `_ultimate.png` — the
  CURRENT three cards. Everything on them is correct except the pip row.
- `i_tod_card_giant_slayer_regular.png` — a card from the same deck whose
  upgrade has five levels. **Its pip row is the target**: five round sockets,
  evenly spaced, centred at the bottom of the card, the first one lit white.
  Copy that row's socket size, spacing and vertical position exactly.
- `preview_onscreen_213x320/` — all four at their real on-screen size.

## The one change

Replace the three-socket pip row at the bottom of each card with a
five-socket row matching `i_tod_card_giant_slayer_regular.png`: same socket
size, same spacing, same vertical position, centred. Lit sockets fill from the
left. The lit and dark colours are the ones each attached card already uses
for its own pips (white on REGULAR, purple-white on SUPER, gold on ULTIMATE).

## Hard rules

- Canvas exactly **768 × 1152 px**, PNG, RGBA, fully transparent outside the
  card edge, identical margin to the attached files. Decode the corner pixel:
  it must be (0,0,0,0).
- **Everything above the pip row is pixel-for-pixel the attached card**: the
  running soldier illustration, the title plate reading `RUN AND GUN`, the
  rarity ribbon (`REGULAR +1` / `SUPER +2` / `ULTIMATE +3`), the medal, the
  value plate reading `FREE SHOTS + BONUS DAMAGE` / `ON THE MOVE`, the rails,
  the outer glow, the ULTIMATE's scattered gold sparkles.
- No new text, no digits, no level indicator.
- The three files must stay registered with each other: the pip row sits in
  the same place on all three.

## Prompt A — `i_tod_card_run_and_gun_regular.png`

Attach `reference/i_tod_card_run_and_gun_regular.png` AND
`reference/i_tod_card_giant_slayer_regular.png`.

```text
Two upgrade cards from a Black Ops 3 zombies map are attached. Edit the FIRST
one (RUN AND GUN) and deliver it at exactly 768 x 1152 pixels, PNG, RGBA,
transparent outside the card, same margin as the original.

Make exactly ONE change: the row of small round pip sockets at the very bottom
of the card currently has THREE sockets. Make it FIVE, matching the SECOND
attached card (GIANT SLAYER) exactly: five round sockets, evenly spaced,
centred, same socket size and same vertical position as on GIANT SLAYER. The
FIRST socket is lit white; the other four are dark.

Everything else — the running soldier, the title plate, the silver REGULAR +1
ribbon, the medal, the value plate text, the cyan rails, the card body — stays
pixel-for-pixel as in the original. No new text, no digits. Deliver as
i_tod_card_run_and_gun_regular.png.
```

## Prompt B — `i_tod_card_run_and_gun_super.png`

Attach `reference/i_tod_card_run_and_gun_super.png` AND
`reference/i_tod_card_giant_slayer_regular.png`.

```text
Two upgrade cards are attached. Edit the FIRST one (RUN AND GUN, the purple
SUPER +2 card) and deliver it at exactly 768 x 1152 pixels, PNG, RGBA,
transparent outside the card.

Make exactly ONE change: the pip row at the very bottom currently has THREE
sockets. Make it FIVE, matching the SECOND attached card's row exactly (size,
spacing, vertical position, centred). The first TWO sockets are lit in the
same purple-white the card's current lit pips use; the other three are dark.

Everything else stays pixel-for-pixel as in the original. Deliver as
i_tod_card_run_and_gun_super.png.
```

## Prompt C — `i_tod_card_run_and_gun_ultimate.png`

Attach `reference/i_tod_card_run_and_gun_ultimate.png` AND
`reference/i_tod_card_giant_slayer_regular.png`.

```text
Two upgrade cards are attached. Edit the FIRST one (RUN AND GUN, the gold
ULTIMATE +3 card) and deliver it at exactly 768 x 1152 pixels, PNG, RGBA,
transparent outside the card, keeping its outer glow and scattered gold
sparkles.

Make exactly ONE change: the pip row at the very bottom currently has THREE
sockets, all lit gold. Make it FIVE, matching the SECOND attached card's row
exactly (size, spacing, vertical position, centred). The first THREE sockets
are lit gold; the last two are dark.

Everything else stays pixel-for-pixel as in the original. Deliver as
i_tod_card_run_and_gun_ultimate.png.
```

## Delivery checklist

- [ ] Three files, named exactly as the table above
- [ ] 768 × 1152, RGBA, corner pixel fully transparent — decode it
- [ ] **Exactly FIVE pip sockets** on every card, lit 1 / 2 / 3 from the left
- [ ] Overlay each file on its original: nothing outside the pip row changes
- [ ] Overlay the three against each other: the pip row is in the same place

## Do NOT

- Do not redraw or move the illustration, title, ribbon, medal or value plate.
- Do not change the value plate text or add a number to it.
- Do not light more pips than the rarity's +1 / +2 / +3.
- Do not hand back a different canvas size, a cropped card or an opaque
  background.
- Do not deliver one or two of the set — the three ship together or not at all.
<!-- PACK:END -->

## Install (when the drop lands)

1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'`; LOOK at all three;
   count the pips (5); per-pixel diff against the shipped files — zero changed
   pixels outside the pip row.
2. Copy over the three files in `source_data/tod_ui_images/_images/` (same
   names; no GDT / zone / Lua edits).
3. FULL build. Proof: NEW content-hash `.iwi` for all three
   `i_tod_card_run_and_gun_*` with fresh mtimes, beside an untouched control.
4. Flip this STATUS to SHIPPED with the build version; CHANGELOG entry.
