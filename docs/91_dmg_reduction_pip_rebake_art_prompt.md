# 91 — DMG REDUCTION card re-bake: the pip row goes 5 → 3 (v17.2)

<!-- art-pack
name: dmg_reduction_pips
refs:
  i_tod_card_dmg_reduction_regular.png | THE CARD TO CHANGE, regular rarity. Everything stays except the socket row at the bottom. Attach to every prompt.
  i_tod_card_dmg_reduction_super.png | the SUPER rarity form of the same card — same change. Attach to Prompt B.
  i_tod_card_dmg_reduction_ultimate.png | the ULTIMATE rarity form — same change. Attach to Prompt C.
  i_tod_card_damage_regular.png | THE TARGET SOCKET ROW. A max-10 domain in the same deck; copy its THREE-socket row exactly — count, size, spacing and position. Attach to every prompt.
preview: 213x320
-->

> **STATUS: REQUESTED 2026-09-03 (v17.2). Not yet baked — the shipped cards
> still carry the old five-socket row.**

## Why

v17.2 gave DMG REDUCTION a **per-class level cap** — 3 skirmisher / 5 slasher /
9 assault (7 until v19.52) / 10 heavy — where every class previously capped at 5. The domain's
ceiling is now **10**.

The deck's rule is **pips = the domain max when max ≤ 6, otherwise a flat 3**.
DAMAGE and BOUNTY are max 10 and both ship a three-socket row; the attached
`i_tod_card_damage_regular.png` is the reference. DMG REDUCTION was max 5 and
correctly carried five sockets. At max 10 it must carry three.

There is also a reason no other count can work: **one baked card is dealt to all
four classes**, and they no longer share a cap. Five sockets is now wrong for
three of the four. Three is right because it stops trying to encode the cap at
all, which is exactly what the >6 rule is for.

**The value line does not change.** It reads `TAKE LESS DAMAGE` with no figure,
which was deliberate (a diminishing ladder makes any printed number wrong at
every level but one) and is still true after this change. This is a pip-row
edit only.

<!-- PACK:BEGIN -->
# DMG REDUCTION — three cards, one small change each

## What this is

A Call of Duty: Black Ops 3 zombies map has a deck of upgrade cards, drawn at
**213 × 320 px on screen** (see `preview_onscreen_213x320/`). Three cards for
one upgrade already exist and are correct in every respect except one detail
that has to change.

**The change, on all three cards: the row of round sockets at the bottom goes
from FIVE to THREE.** Nothing else moves.

**Deliver exactly THREE files:**

| Deliver as | Size | Change |
|---|---|---|
| `i_tod_card_dmg_reduction_regular.png` | 768 × 1152 | 5 sockets → **3**, first one lit |
| `i_tod_card_dmg_reduction_super.png` | 768 × 1152 | 5 sockets → **3**, first **two** lit |
| `i_tod_card_dmg_reduction_ultimate.png` | 768 × 1152 | 5 sockets → **3**, all **three** lit |

All three RGBA with a **fully transparent background**, same canvas and same
margins as the attached originals.

## References (in `reference/`)

- `i_tod_card_dmg_reduction_regular.png`, `_super.png`, `_ultimate.png` — **the
  three cards to edit.** Treat each as the base and change only the socket row.
- `i_tod_card_damage_regular.png` — **the target.** Its three-socket row is
  exactly what the new row should look like: same socket diameter, same gap,
  same vertical position, same lit/unlit treatment, centred the same way.

## Rules

1. **Change the socket row and nothing else.** The title plate
   (`DMG REDUCTION`), the shield-and-cross illustration, the rarity ribbon, the
   star medal, the value plate reading `TAKE LESS DAMAGE`, the card body, rails,
   screws, scanlines and outer glow all stay pixel-identical.
2. **Three sockets, centred**, matching `i_tod_card_damage_regular.png`. Do not
   simply delete two of the five and leave the remaining three off-centre — the
   row is centred on the card, so removing two means re-centring the rest.
3. **Lit count follows rarity**: regular 1, super 2, ultimate 3. Lit and unlit
   styling copied from the originals, which already show both states.
4. **No number anywhere on the card.** The value plate must keep reading
   `TAKE LESS DAMAGE` exactly.
5. Same 768 × 1152 canvas, transparent outside the card edge.

## Prompt A — regular

Edit the attached `i_tod_card_dmg_reduction_regular.png`. Keep every element
exactly as it is, and change ONLY the row of round sockets near the bottom of
the card: replace the five sockets with **three**, centred, using the socket
size, spacing, vertical position and lit/unlit styling from the attached
`i_tod_card_damage_regular.png`. The **first** socket is lit; the other two are
unlit. Do not alter the title plate, illustration, rarity ribbon, medal, value
plate text, or any part of the card frame. Output 768 × 1152 RGBA with a
transparent background.

## Prompt B — super

As Prompt A, but edit `i_tod_card_dmg_reduction_super.png` and light the
**first two** of the three sockets.

## Prompt C — ultimate

As Prompt A, but edit `i_tod_card_dmg_reduction_ultimate.png` and light **all
three** sockets.

## Delivery checklist

- [ ] Three PNGs, named exactly as the table above.
- [ ] 768 × 1152, RGBA, transparent background.
- [ ] Exactly three sockets on each, centred, matching the DAMAGE card's row.
- [ ] Lit counts: 1 / 2 / 3.
- [ ] Value plate still reads `TAKE LESS DAMAGE`, no number added.
- [ ] Nothing else changed — overlay against the original and confirm only the
      socket row differs.

## Do NOT

- Do not add a number, percentage or level count anywhere.
- Do not redraw the illustration, retype the title, or restyle the frame.
- Do not change the canvas size, margins or transparency.
- Do not leave the three sockets where the first three used to sit — re-centre.
<!-- PACK:END -->

## Install (after the drop)

Same names as the shipped files, so **no wiring changes**: no GDT block, no zone
line, no Lua slug. Copy into `source_data/tod_ui_images/_images/`, FULL build,
and prove with a fresh content-hash `.iwi` for each of the three beside an
untouched control. Then flip the STATUS line above to SHIPPED with the version.
