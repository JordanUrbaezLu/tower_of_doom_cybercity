# 104 — ADRENALINE cards: "SPEED + DAMAGE" re-bake (4 images)

<!-- art-pack
name: adrenaline_damage
refs:
  i_tod_card_adrenaline_regular.png | the CURRENT regular card being replaced: keep everything, change the value line and add the damage motif. Attach to Prompt A.
  i_tod_card_adrenaline_super.png | the CURRENT super card being replaced (violet rarity treatment). Attach to Prompt B.
  i_tod_card_adrenaline_ultimate.png | the CURRENT ultimate card being replaced (orange-gold rarity treatment, gold value lettering). Attach to Prompt C.
  i_tod_card_adrenaline_dark.png | the CURRENT dark card being replaced (red DARK UPGRADE treatment, cream value lettering, all five pips lit red). Attach to Prompt D.
  i_tod_card_run_and_gun_regular.png | a card whose value line is TWO lines of words: the lettering size and line spacing to copy for a two-line value plate. Attach to every prompt.
preview: 213x320
-->

> **STATUS: SHIPPED v17.68, 2026-09-05 — UNPLAYED.** Drop `files - 2026-09-05T010402.623.zip` (four 768x1152 RGBA cards + two REVIEW sheets not installed): every card opened and proofread — two-line MULTI-KILLS GRANT / SPEED + DAMAGE in each rarity's own lettering colour, impact burst at the rightmost chevron tip, ribbons and pips 1/2/3/5 correct. Installed under the same names, FULL build; proof = four fresh content-hash `.iwi` beside an untouched control. (Historical:) **REQUESTED 2026-09-05 (v17.67).** The mechanic shipped the same
> day: while the 3s burst is live the player now ALSO hits +3%/tier harder
> (dark +25%) — `adren_bonus()` feeds both the move-speed sum and
> `unique_damage_mult`. The shipped cards read **MULTI-KILLS GRANT SPEED**
> (opened, not assumed: regular, ultimate and dark all carry that line; super
> shipped in the same docs/58 drop), which now under-sells the card, so all
> four are re-baked at IDENTICAL filenames — no wiring, no GDT rows, no zone
> lines, `CARD_SLUG[25]` already exists. Pack built by
> `.\tools\make_art_pack.ps1 docs\104_adrenaline_damage_art_prompt.md` →
> `~/Downloads/tod_adrenaline_damage_art_pack.zip`. The pause plate
> `i_tod_pause_r25` is a bare nameplate (reads ADRENALINE only) and needs
> nothing. Install = copy the four PNGs over the originals, FULL build, prove
> with four fresh content-hash `.iwi` beside an untouched control, then flip
> this STATUS to SHIPPED.

**Generic card text rule still holds:** the value line carries NO number.
The pause menu's DETAIL row (`+N% move speed and damage for 3s`) carries the
value, so a percent retune still owes no re-bake.

<!-- PACK:BEGIN -->
# ADRENALINE — re-bake four existing upgrade cards (new value line + damage motif)

## What this is

A Call of Duty: Black Ops 3 zombies map has a deck of upgrade cards (drawn at
**213 × 320 px on screen**, see `preview_onscreen_213x320/`). The ADRENALINE
card already exists at four rarities. Its effect changed: a multi-kill used to
grant a short burst of **speed**; it now grants a burst of **speed AND
damage**. The four cards must be re-made so the value line says so and the
picture hints at hitting harder. **The attached cards ARE the style — every
plate, colour and margin stays exactly where it is.** Only two things change.

**Deliver exactly FOUR files, same names as the attached originals:**

| Deliver as | Size | Title plate | Value line (exact, two lines) | Ribbon | Pips lit |
|---|---|---|---|---|---|
| `i_tod_card_adrenaline_regular.png` | 768 × 1152 | `ADRENALINE` | `MULTI-KILLS GRANT` / `SPEED + DAMAGE` | `REGULAR +1` (silver medal, grey ribbon, no glow) | 1 of 5 |
| `i_tod_card_adrenaline_super.png` | 768 × 1152 | `ADRENALINE` | `MULTI-KILLS GRANT` / `SPEED + DAMAGE` | `SUPER +2` (gold medal, violet ribbon, violet glow) | 2 of 5 |
| `i_tod_card_adrenaline_ultimate.png` | 768 × 1152 | `ADRENALINE` | `MULTI-KILLS GRANT` / `SPEED + DAMAGE` | `ULTIMATE +3` (gold medal, orange-gold ribbon, warm glow) | 3 of 5 |
| `i_tod_card_adrenaline_dark.png` | 768 × 1152 | `ADRENALINE` | `MULTI-KILLS GRANT` / `SPEED + DAMAGE` | `DARK UPGRADE` (red treatment, red star medal, red outer glow) | 5 of 5, red |

RGBA with a **fully transparent background** outside the card edge, same
margin as the originals.

## The two changes (and nothing else)

1. **Value plate text.** Replace `MULTI-KILLS / GRANT SPEED` with two centred
   lines: **`MULTI-KILLS GRANT`** on the first line and **`SPEED + DAMAGE`** on
   the second. Same chunky all-caps outlined lettering, in the SAME colour the
   original of that rarity uses (white on the regular card, gold on the
   ultimate card, cream on the dark card, whatever the super card uses). The
   lines are longer than before, so use the lettering size of
   `i_tod_card_run_and_gun_regular.png` (attached: a two-line value plate) so
   both lines fit inside the plate's inner frame with the same inset. The `+`
   is a plus sign, not the word "AND" and not an ampersand.
2. **A damage motif in the illustration.** Keep the three cyan speed chevrons
   with their motion dashes and the three cross-eyed skulls exactly where they
   are. Add ONE clear "hits harder" element: a cartoon **impact burst** — a
   white-and-gold jagged starburst with a short red-orange outer spike ring —
   at the tip of the leading (rightmost) chevron, as if the chevrons are
   slamming into something. Small enough not to cover the chevrons or the
   skulls, bright enough to read at 213 × 320. Same flat style, thick black
   outline. On the dark card the burst keeps its white-gold core; its spikes
   may pick up the card's red.

Everything else — card body, screws, scanlines, side rails, title plate and
its studs, illustration panel and sheen, corner pixel squares, sparkles,
ribbon, medal, rivets, pip row and lit counts, outer glow — is copied from the
attached original of that rarity, unchanged. Overlay to check.

## Hard rules

- Flat colours, thick black outlines, simple soft shading. No photorealism,
  no 3D render look.
- Text on each card is exactly: the title `ADRENALINE`, the ribbon text of
  that rarity, and the two value lines `MULTI-KILLS GRANT` / `SPEED + DAMAGE`.
  **No other text, no numbers, no percent signs, no watermark.**
- Five pip sockets on every card; lit 1 / 2 / 3 / 5 as the table says. The
  dark card's lit pips are red, as on its original.
- Filenames identical to the originals — these overwrite them.
- Corner pixel of every file must be fully transparent — decode it.

## Prompt A — `i_tod_card_adrenaline_regular.png`

Attach `reference/i_tod_card_adrenaline_regular.png` and
`reference/i_tod_card_run_and_gun_regular.png`.

```text
An upgrade card from a Black Ops 3 zombies map is attached, plus a second
card from the same deck whose value plate holds two lines of words. Re-make
the FIRST card at exactly 768 x 1152 pixels, PNG, RGBA, transparent outside
the card, same margin. Copy the attached card exactly - card body, screws,
scanlines, cyan side rails, orange title plate with studs reading
ADRENALINE, navy illustration panel with its sheen, corner pixel squares and
sparkles, the grey REGULAR +1 ribbon with the silver star medal, the dark
riveted value plate, and the five pip sockets with only the first lit.

Change exactly two things.

One: the value plate now reads two centred lines of the same chunky white
outlined all-caps lettering: MULTI-KILLS GRANT on the first line and
SPEED + DAMAGE on the second, with a plus sign. Use the lettering size and
line spacing of the second attached card so both lines fit inside the
plate's inner frame.

Two: in the illustration, keep the three cyan chevrons with their motion
dashes and the three cross-eyed skulls exactly as they are, and add one
cartoon impact burst at the tip of the rightmost chevron: a white-and-gold
jagged starburst with a short ring of red-orange spikes, thick black
outline, as if the chevrons are slamming into something. Keep it small
enough not to cover the chevrons or skulls.

Flat cartoon style, thick black outlines, no photorealism. No other text,
no digits, no percent signs, no watermark. Deliver as
i_tod_card_adrenaline_regular.png.
```

## Prompt B — `i_tod_card_adrenaline_super.png`

Attach `reference/i_tod_card_adrenaline_super.png` and the FINISHED new
regular card from Prompt A.

```text
Attached: the current SUPER card of an upgrade, and the finished new REGULAR
card of the same upgrade. Re-make the SUPER card at exactly 768 x 1152
pixels, PNG, RGBA, transparent outside the card. Keep every part of the
attached SUPER card - its violet SUPER +2 ribbon, gold star medal, violet
outer glow, its value-plate lettering colour, and the five pip sockets with
the first TWO lit - and take only two things from the new regular card: the
two-line value plate text MULTI-KILLS GRANT / SPEED + DAMAGE at the same
lettering size, and the white-and-gold impact burst at the tip of the
rightmost chevron, placed in exactly the same spot. No other changes, no
other text, no digits. Deliver as i_tod_card_adrenaline_super.png.
```

## Prompt C — `i_tod_card_adrenaline_ultimate.png`

Attach `reference/i_tod_card_adrenaline_ultimate.png` and the FINISHED new
regular card from Prompt A.

```text
Attached: the current ULTIMATE card of an upgrade, and the finished new
REGULAR card of the same upgrade. Re-make the ULTIMATE card at exactly
768 x 1152 pixels, PNG, RGBA, transparent outside the card. Keep every part
of the attached ULTIMATE card - its orange-gold ULTIMATE +3 ribbon, gold star
medal, warm outer glow with gold sparkles, its GOLD value-plate lettering,
and the five pip sockets with the first THREE lit - and take only two things
from the new regular card: the two-line value plate text MULTI-KILLS GRANT /
SPEED + DAMAGE (in this card's gold, same lettering size), and the
white-and-gold impact burst at the tip of the rightmost chevron, placed in
exactly the same spot. No other changes, no other text, no digits. Deliver
as i_tod_card_adrenaline_ultimate.png.
```

## Prompt D — `i_tod_card_adrenaline_dark.png`

Attach `reference/i_tod_card_adrenaline_dark.png` and the FINISHED new
regular card from Prompt A.

```text
Attached: the current DARK card of an upgrade (red frame, red DARK UPGRADE
ribbon, red star medal, purple illustration panel, all five pips lit red,
red outer glow with sparkle crosses), and the finished new REGULAR card of
the same upgrade. Re-make the DARK card at exactly 768 x 1152 pixels, PNG,
RGBA, transparent outside the card. Keep every part of the attached DARK
card unchanged, including its cream-coloured value-plate lettering, and take
only two things from the new regular card: the two-line value plate text
MULTI-KILLS GRANT / SPEED + DAMAGE (in the dark card's cream colour, same
lettering size as the new regular card), and the impact burst at the tip of
the rightmost chevron in the same spot - white-and-gold core, and its spike
ring may take the card's red. No other changes, no other text, no digits.
Deliver as i_tod_card_adrenaline_dark.png.
```

## Delivery checklist

- [ ] Four files, exact original names, 768 × 1152, RGBA, transparent corner
      pixel.
- [ ] Value plate on all four reads `MULTI-KILLS GRANT` / `SPEED + DAMAGE`,
      two lines, plus sign. Proofread every card.
- [ ] Impact burst present at the rightmost chevron tip on all four, same
      spot.
- [ ] Ribbons read `REGULAR +1` / `SUPER +2` / `ULTIMATE +3` /
      `DARK UPGRADE`; pips lit 1 / 2 / 3 / 5.
- [ ] No digits or percent signs anywhere except the ribbon's `+1/+2/+3`.
- [ ] Overlaid on its original, every plate lines up.

## Do NOT

- Do not move, resize or restyle any plate, rail, ribbon, medal or pip row.
- Do not bake a percentage, a number or a duration into the value plate.
- Do not remove or redraw the chevrons or skulls — the burst is ADDED.
- Do not write "AND" or "&" — the second line is `SPEED + DAMAGE`.
- Do not change the dark card's colours to match the normal cards.
- Do not deliver JPEG, a filled background, or a different size.
<!-- PACK:END -->
