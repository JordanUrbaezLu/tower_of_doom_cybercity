# 83 — TRAILBLAZER card art (domain 46: skirmisher burning sprint trail, 4 images)

<!-- art-pack
name: trailblazer
refs:
  i_tod_card_adrenaline_regular.png | a SKIRMISHER card from the same deck, max 5: the SKIRMISHER accent colour to match, and the FIVE-pip row (first lit). Attach to every prompt.
  i_tod_card_adrenaline_super.png | the SUPER rarity treatment (purple rails, ribbon, glow, gold medal, 2 lit pips). Attach to Prompt B.
  i_tod_card_adrenaline_ultimate.png | the ULTIMATE rarity treatment (gold rails, ribbon, glow, sparkles, 3 lit pips). Attach to Prompt C.
  i_tod_pause_r44.png | the CURRENT pause-menu nameplate style (GUNSLINGER): copy the pill, notch and lettering exactly with the new word. Attach to Prompt D.
preview: 213x320 300x44
-->

> **STATUS: SHIPPED v16.65, 2026-09-02 — UNPLAYED.** Drop `files - 2026-09-02T235756.963.zip` (nested `tod_trailblazer_riot_shield.zip`): 4 files installed + 4 GDT blocks + 4 zone lines, `CARD_SLUG[46] = "trailblazer"`. `PAUSE_PLATE_MAX` stays 44 until r45 lands (contiguous ceiling). Proof: fresh content-hash .iwi for each beside an untouched control.
> (Original request state below.) `CARD_SLUG[46]` unset, `PAUSE_PLATE_MAX` (AetheriumStartMenu.lua)
> and `TOD_UPG_PLATE_MAX` (AetheriumScoreboard.lua) stay **44** until all four
> PNGs are installed AND zoned. Pack built by
> `.\tools\make_art_pack.ps1 docs\83_trailblazer_card_art_prompt.md` →
> `~/Downloads/tod_trailblazer_art_pack.zip`. Install: copy the four files into
> `source_data/tod_ui_images/_images/`, add the GDT blocks + `image,` zone
> lines, set `CARD_SLUG[46] = "trailblazer"`, raise both PLATE_MAX to 46 only
> if r45 (RIOT SHIELD) has ALSO landed (the plate max is a contiguous ceiling),
> FULL build, prove with a fresh content-hash `.iwi` beside an untouched control.

## The domain

- **Key** `trailblazer`, id **46**, **SKIRMISHER only**, band **A**, **max 5**,
  scope `class` (survives tier promotions). Design record: docs/80.
- **Effect:** sprinting leaves burning ground behind the skirmisher; zombies
  that run through it burn. Per level the trail lingers longer (2 → 4 s), is
  wider (one, two, then three fire patches across) and burns hotter (12 → 28%
  of a zombie's health per second).

**NO NUMBER ON THE CARD** (standing rule, user 2026-09-02): the value line is
`FIRE FOLLOWS YOUR SPRINT`, identical on all three rarities, so a retune owes
no re-bake. The pause menu (`DETAIL[46]`) carries the live numbers.
**5 pips** (max 5): 1 / 2 / 3 lit. **SKIRMISHER accent** — sample it from the
adrenaline reference, never from prose.

<!-- PACK:BEGIN -->
# TRAILBLAZER — a new upgrade card (3 rarities) + its pause-menu nameplate

## What this is

A Call of Duty: Black Ops 3 zombies map has a deck of upgrade cards (drawn at
**213 × 320 px on screen**, see `preview_onscreen_213x320/`) and a matching
row of slim pause-menu nameplates (**300 × 44**, see
`preview_onscreen_300x44/`). A new upgrade needs its four images. **The
attached cards ARE the style — match them exactly.** A new card has to sit in
a hand beside them and look like it came out of the same deck.

The upgrade: **TRAILBLAZER** — the fast, light-footed class leaves a trail of
fire on the ground behind it while sprinting; the undead that chase through
it burn. One card per rarity, then one nameplate.

**Deliver exactly FOUR files:**

| Deliver as | Size | Value line (exact) | Pips |
|---|---|---|---|
| `i_tod_card_trailblazer_regular.png` | 768 × 1152 | **`FIRE FOLLOWS YOUR SPRINT`** | 5 sockets, **1 lit** |
| `i_tod_card_trailblazer_super.png` | 768 × 1152 | **`FIRE FOLLOWS YOUR SPRINT`** | 5 sockets, **2 lit** |
| `i_tod_card_trailblazer_ultimate.png` | 768 × 1152 | **`FIRE FOLLOWS YOUR SPRINT`** | 5 sockets, **3 lit** |
| `i_tod_pause_r46.png` | 300 × 44 | **`TRAILBLAZER`** | — |

All four RGBA with a **fully transparent background** — the card body and the
plate sit on transparency, they do not fill the frame.

## References (in `reference/`)

- `i_tod_card_adrenaline_regular.png` — a card of the SAME CLASS. Two things
  come from it: the **accent colour** of its illustration (the class's colour —
  sample it from the image), and the **five-socket pip row** at the bottom
  (size, spacing, position; first lit). Its composition must NOT be copied.
- `i_tod_card_adrenaline_super.png`, `_ultimate.png` — the SUPER and ULTIMATE
  rarity treatments to apply to the finished regular card.
- `i_tod_pause_r44.png` — the current nameplate style; the new plate is this
  with a different word.

## The card template (identical on all three rarities)

**Canvas:** 768 × 1152 portrait, transparent outside the card edge, the same
small margin as the attached cards.

1. **Card body** — rounded-corner near-black navy card with a very thick black
   outline, faint horizontal scanlines, a small dark cross-head screw in each
   corner, a slim vertical accent rail inside the left and right edges
   (rarity-coloured).
2. **Title plate** — the rounded orange-to-amber gradient plate with a black
   outline and seven small studs along its top edge, holding **`TRAILBLAZER`**
   in chunky white bubble letters with a heavy dark outline. One line, all
   caps, identical on all three.
3. **Illustration panel** — the rounded darker-navy inset panel with a soft
   radial sheen at the top, faint scanlines, a thin inner border, the four
   tiny corner pixel squares and two or three small sparkle glyphs, exactly as
   on the attached cards. The illustration goes inside it.
4. **Rarity ribbon** — the gradient pill with a dark notched arrowhead each
   side, rarity text in the same bubble lettering; the round star medal
   overlapping the panel's bottom-right corner.
5. **Value plate** — the dark inset rectangle with a thin rounded inner frame
   and a rivet in each corner, holding **ONE centred line** of chunky all-caps
   outlined lettering: **`FIRE FOLLOWS YOUR SPRINT`** — identical text on all
   three cards, only the colour differs (see the rarity table). No second
   line, no number.
6. **Pip row** — **FIVE** round sockets, copied from the adrenaline card.

## The illustration (identical on all three rarities)

A chunky flat-cartoon **pair of running boots and lower legs**, seen from a
low three-quarter angle, mid-stride and moving toward the upper-right of the
panel, drawn in the **class accent colour sampled from the adrenaline card**
with dark outlines. Behind them, filling the lower-left two-thirds of the
panel, a **blazing trail of fire on the floor** — bold orange-to-yellow flame
shapes with a few flat ember dots rising, the trail widening as it recedes
toward the lower-left corner. The floor is a dark navy grid receding in
perspective (three or four thin lines are enough) so the fire clearly sits ON
the ground, not in the air. Two small, flat, dark zombie silhouettes are
caught in the trail behind the boots, arms up, outlined in the same orange.
Simple shapes, thick outlines, no gradients finer than the attached cards use,
nothing photoreal. No text inside the panel.

## Rarity table

| Rarity | Rails and ribbon | Ribbon text | Value-line colour | Pips lit | Extras |
|---|---|---|---|---|---|
| REGULAR | as `_regular` reference | `REGULAR` | as the regular reference | 1 | none |
| SUPER | as `_super` reference (purple) | `SUPER` | as the super reference | 2 | the super glow and gold medal |
| ULTIMATE | as `_ultimate` reference (gold) | `ULTIMATE` | as the ultimate reference | 3 | the ultimate glow, sparkles |

## Paste-ready prompts

**Prompt A — REGULAR card** (attach `i_tod_card_adrenaline_regular.png`):
"Match this card's template exactly (body, title plate, panel, ribbon, value
plate, five-pip row, first pip lit). Title text: TRAILBLAZER. Value-line text:
FIRE FOLLOWS YOUR SPRINT. Ribbon text: REGULAR. Illustration: running boots
mid-stride heading upper-right in this card's accent colour, a blazing orange
fire trail on a dark navy perspective-grid floor behind them widening toward
the lower-left, two flat dark zombie silhouettes caught in the flames.
Flat-cartoon, thick outlines. 768×1152, transparent background."

**Prompt B — SUPER card** (attach Prompt A's result + `i_tod_card_adrenaline_super.png`):
"Apply this SUPER rarity treatment to the attached regular card: purple rails
and ribbon, ribbon text SUPER, the glow and gold medal, second pip lit. Change
nothing else. 768×1152, transparent background."

**Prompt C — ULTIMATE card** (attach Prompt A's result + `i_tod_card_adrenaline_ultimate.png`):
"Apply this ULTIMATE rarity treatment to the attached regular card: gold rails
and ribbon, ribbon text ULTIMATE, the glow and sparkles, third pip lit. Change
nothing else. 768×1152, transparent background."

**Prompt D — nameplate** (attach `i_tod_pause_r44.png`):
"Recreate this nameplate exactly — same pill shape, notch, gradient, outline
and lettering — reading TRAILBLAZER. 300×44, transparent background."

## Delivery checklist

- [ ] Four files, exact names above, PNG, RGBA, transparent background
- [ ] Cards 768 × 1152; plate 300 × 44
- [ ] Title `TRAILBLAZER` and value line `FIRE FOLLOWS YOUR SPRINT` spelled exactly, on all three cards
- [ ] Five pip sockets; 1 / 2 / 3 lit by rarity
- [ ] The illustration is the SAME on all three; only the rarity dressing changes
- [ ] Nothing photoreal; nothing outside the card edge

## Do NOT

- Do not put a number, a percentage or a second line on the value plate
- Do not copy the adrenaline card's illustration — only its colour and pips
- Do not change the template proportions, fonts or plate positions
- Do not add a background behind the card
<!-- PACK:END -->
