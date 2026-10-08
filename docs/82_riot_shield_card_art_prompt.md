# 82 — RIOT SHIELD card art (domain 45: the universal recharging shield, 4 images)

<!-- art-pack
name: riot_shield
refs:
  i_tod_card_perkslots_regular.png | a UNIVERSAL card from the same deck (every class rolls it), max 5: the SHARED accent colour to match, and the FIVE-pip row (first lit) to copy exactly. Attach to every card prompt.
  i_tod_card_perkslots_super.png | the SUPER rarity treatment (purple rails, ribbon, glow, gold medal, 2 lit pips). Attach to Prompt B.
  i_tod_card_perkslots_ultimate.png | the ULTIMATE rarity treatment (gold rails, ribbon, glow, sparkles, 3 lit pips). Attach to Prompt C.
  i_tod_card_dmg_reduction_regular.png | the deck's other defensive card: its composition is what NOT to repeat (no chest armour plate, no "shield around a body"). Attach to Prompt A as the thing to avoid.
  i_tod_pause_r44.png | the CURRENT pause-menu nameplate style (GUNSLINGER): copy the pill, notch and lettering exactly with the new words. Attach to Prompt D.
preview: 213x320 300x44
-->

> **STATUS: SHIPPED 2026-09-03 (the build after v16.63) — UNPLAYED.** Drop
> `files - 2026-09-02T235756.963.zip` (it also carried the TRAILBLAZER set for
> docs/80-81, left to that session): 4 files installed, 4 GDT blocks, 4 zone
> lines, `CARD_SLUG[45]`, `PAUSE_PLATE_MAX` and `TOD_UPG_PLATE_MAX` 44 → 45.
> The generator baked the value line as **`MORE HEALTH, FASTER RECHARGE`**
> (not the brief's TOUGHER SHIELD, FASTER RETURN) — still generic, no number,
> accepted as delivered. (Historical, pre-drop:) **STATUS: PENDING — v16.63 ships on the TEXT fallbacks** (VITALITY /
> RECOVERY / PERK SLOTS / DISTRACTION / GUNSLINGER precedent): `CARD_SLUG[45]`
> unset, `PAUSE_PLATE_MAX` (AetheriumStartMenu.lua) and `TOD_UPG_PLATE_MAX`
> (AetheriumScoreboard.lua) stay **44** until all four PNGs are installed AND
> zoned. Pack built by
> `.\tools\make_art_pack.ps1 docs\82_riot_shield_card_art_prompt.md` →
> `~/Downloads/tod_riot_shield_art_pack.zip`. Note id 46 (TRAILBLAZER, docs/80)
> is ALSO pending art — when both land, the two `_MAX` constants go to
> whichever is the highest CONTIGUOUS id with a plate (r45 first, then r46).

## The domain

- **Key** `riotshield`, id **45**, **EVERY CLASS**, band **A**, **max 5**,
  scope `class` (survives tier promotions).
- **Effect:** a riot shield rides in the equipment slot (d-pad down). Held, it
  blocks everything in front; on the back, everything behind. Each level adds
  shield health and shortens the recharge that hands it back after it breaks:
  200 / 300 / 370 / 450 / 500 HP, 4:00 / 3:30 / 3:00 / 2:30 / 2:00. Level 5
  also swaps in the second model (the clean white-and-orange cyber shield).
  Module: `_tod_riotshield.gsc`; constants `TOD_SHIELD_HP_L1..L5`,
  `TOD_SHIELD_RECHARGE_L1..L5`.
- **Why generic text:** the ladder is five numbers on two axes and has already
  been retuned once in the design conversation. The value line names the
  EFFECT, the pause menu (`DETAIL[45]`) carries the live numbers.

**NO NUMBER ON THE CARD** (user 2026-09-02: *"convert to generic text so this
can be prevented in future where possible"*): the value line is
`TOUGHER SHIELD, FASTER RETURN`, identical on all three rarities.
**5 pips** (max 5): 1 / 2 / 3 lit. **SHARED accent** — sample it from the
perk-slots reference (a universal card), never from a class card.

<!-- PACK:BEGIN -->
# RIOT SHIELD — a new upgrade card (3 rarities) + its pause-menu nameplate

## What this is

A Call of Duty: Black Ops 3 zombies map has a deck of upgrade cards (drawn at
**213 × 320 px on screen**, see `preview_onscreen_213x320/`) and a matching
row of slim pause-menu nameplates (**300 × 44**, see
`preview_onscreen_300x44/`). A new upgrade needs its four images. **The
attached cards ARE the style — match them exactly.** A new card has to sit in
a hand beside them and look like it came out of the same deck.

The upgrade: **RIOT SHIELD** — every player class can earn a riot shield they
carry on their back and raise to block the horde. Each level makes the shield
tougher, and when it breaks it comes back on its own sooner. One card per
rarity, then one nameplate.

**Deliver exactly FOUR files:**

| Deliver as | Size | Value line (exact) | Pips |
|---|---|---|---|
| `i_tod_card_riot_shield_regular.png` | 768 × 1152 | **`TOUGHER SHIELD, FASTER RETURN`** | 5 sockets, **1 lit** |
| `i_tod_card_riot_shield_super.png` | 768 × 1152 | **`TOUGHER SHIELD, FASTER RETURN`** | 5 sockets, **2 lit** |
| `i_tod_card_riot_shield_ultimate.png` | 768 × 1152 | **`TOUGHER SHIELD, FASTER RETURN`** | 5 sockets, **3 lit** |
| `i_tod_pause_r45.png` | 300 × 44 | **`RIOT SHIELD`** | — |

All four RGBA with a **fully transparent background** — the card body and the
plate sit on transparency, they do not fill the frame.

## References (in `reference/`)

- `i_tod_card_perkslots_regular.png` — a card that EVERY class can draw, like
  this one. Two things come from it: the **accent colour** of its illustration
  (the deck's shared, class-neutral accent — sample it from the image), and the
  **five-socket pip row** at the bottom (size, spacing, position; first lit).
- `i_tod_card_perkslots_super.png`, `_ultimate.png` — the SUPER and ULTIMATE
  rarity treatments to apply to the finished regular card.
- `i_tod_card_dmg_reduction_regular.png` — the deck's other defensive card.
  Attached so the new card does NOT repeat its composition: no chest plate, no
  glowing aura around a body, no crossed-out damage marks. This card is about
  a physical shield held in a hand.
- `i_tod_pause_r44.png` — the current nameplate style; the new plate is this
  with different words.

## The card template (identical on all three rarities)

**Canvas:** 768 × 1152 portrait, transparent outside the card edge, the same
small margin as the attached cards.

1. **Card body** — rounded-corner near-black navy card with a very thick black
   outline, faint horizontal scanlines, a small dark cross-head screw in each
   corner, a slim vertical accent rail inside the left and right edges
   (rarity-coloured).
2. **Title plate** — the rounded orange-to-amber gradient plate with a black
   outline and seven small studs along its top edge, holding **`RIOT SHIELD`**
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
   outlined lettering: **`TOUGHER SHIELD, FASTER RETURN`** — identical text on
   all three cards, only the colour differs (see the rarity table). No second
   line, no number.
6. **Pip row** — **FIVE** round sockets, copied from the perk-slots card.

## The illustration (identical on all three rarities)

A chunky flat-cartoon **tall riot shield held up by one gloved hand and
forearm**, seen from slightly to one side so the shield's face fills the
centre and left of the panel: a clean, smooth, slightly convex rectangular
shield with rounded corners, a **white body with a broad orange stripe**
across its upper third and a small transparent-looking vision slit near the
top (this is the shield's in-game look — white and orange, clean and
futuristic, no rivets, no wood, no police lettering). A thin **class-neutral
accent glow** (sampled from the perk-slots card) lines the shield's edge. Two
or three small cartoon impact stars burst against the face of the shield
from the upper right, with a pair of short green-grey zombie arms reaching in
from that corner, stopped by the shield. Below the shield's lower edge, a
small **circular-arrow "recharge" glyph** in the accent colour, drawn like a
loading ring three-quarters complete — the return-after-it-breaks idea, no
clock hands, no digits.

No human face or body beyond the gloved hand and forearm. No guns, no
blades on this card. No hearts, health bars, blood, text inside the panel, or
digits anywhere except the rarity ribbon.

## Rarity treatment — the ONLY differences between the three cards

| | REGULAR | SUPER | ULTIMATE |
|---|---|---|---|
| side rails, panel border, doodles | cyan | purple/violet (+ a teal touch) | gold and red (+ a teal touch) |
| rarity ribbon | silver/grey, text `REGULAR +1` | glowing purple, text `SUPER +2` | glowing orange-gold, text `ULTIMATE +3` |
| medal | silver | gold | gold |
| value-line lettering | pale grey-blue | purple/lavender | gold/amber |
| outer glow | none | soft lavender glow round the card edge | warm gold-and-pink glow plus scattered small gold sparkle crosses and tick marks outside the border |
| pips (5 sockets) | first lit white, 4 dark | first 2 lit purple-white, 3 dark | first 3 lit gold, 2 dark |

Take every one of these from the attached perk-slots super/ultimate cards —
they are the deck's rarity treatment, not a description to reinterpret.

## Hard rules

- Flat colours, thick black outlines, simple soft shading. No photorealism, no
  3D render look, no drop shadows on text.
- Text on the cards is exactly three strings: `RIOT SHIELD`, the rarity
  ribbon, and the value line. **No other text, no logos, no watermark, no
  lettering on the shield itself.**
- **No digits anywhere** except the `+1/+2/+3` in the ribbon. The value line
  carries NO number on purpose.
- **Exactly FIVE pip sockets** on every card. Generators normalise to three;
  count them.
- The three cards must stay registered with each other: same illustration,
  same plate positions, same pip row position; only the rarity treatment, the
  value-line colour, and the lit pips differ.
- Corner pixel of every file must be fully transparent — decode it.

## Prompt A — build `i_tod_card_riot_shield_regular.png`

Attach `reference/i_tod_card_perkslots_regular.png` AND
`reference/i_tod_card_dmg_reduction_regular.png`.

```text
Two upgrade cards from a Black Ops 3 zombies map are attached. The FIRST
(perk slots) IS the style: match it exactly and produce a NEW card of the
same deck. The SECOND (damage reduction) is attached only so you do NOT
repeat its composition. Deliver at exactly 768 x 1152 pixels, PNG, RGBA,
transparent outside the card, same margin as the attached cards. Flat
cartoon, thick black outlines, no photorealism.

Copy from the first card, unchanged: the navy rounded card body with the
thick black outline, corner screws and scanlines; the cyan side rails; the
orange-to-amber title plate with seven studs; the darker-navy illustration
panel with its sheen, inner border, corner pixel squares and sparkles; the
silver REGULAR +1 ribbon with notched arrowheads and the silver star medal
overlapping the panel's bottom-right corner; the dark riveted value plate; and
the FIVE-socket pip row, first socket lit white, four dark.

Title plate text: RIOT SHIELD (chunky white bubble letters, dark outline).

Illustration: a chunky flat-cartoon tall riot shield held up by one gloved
hand and forearm, seen slightly from one side so the shield face fills the
centre and left of the panel. The shield is clean, smooth and slightly
convex with rounded corners: a white body with a broad orange stripe across
its upper third and a small vision slit near the top - futuristic, no rivets,
no wood, no lettering on it. A thin glow along the shield's edge in the SAME
accent colour as the first card's illustration (sample it from the image).
Two or three small cartoon impact stars burst on the shield's face from the
upper right, where a pair of short green-grey zombie arms reach in and are
stopped by it. Under the shield's lower edge, a small circular-arrow recharge
glyph in that accent colour, like a loading ring three-quarters complete. No
faces, no guns, no blades, no blood, no text inside the panel.

Value plate: ONE centred line of chunky all-caps outlined lettering in pale
grey-blue: TOUGHER SHIELD, FASTER RETURN. No number in it, no second line.

No other text, no other digits, no watermark. Deliver as
i_tod_card_riot_shield_regular.png.
```

## Prompt B — build `i_tod_card_riot_shield_super.png`

Attach the FINISHED regular card from Prompt A AND
`reference/i_tod_card_perkslots_super.png`.

```text
Two cards are attached: the FINISHED regular RIOT SHIELD card, and a SUPER
card from the same deck showing the deck's purple rarity treatment. Produce
the SUPER version of the RIOT SHIELD card: keep its illustration, title
plate, value plate layout and five-socket pip row in exactly the same
positions, and apply the second card's rarity treatment - purple/violet side
rails, purple panel border and doodles (a teal touch is fine), the glowing
purple SUPER +2 ribbon, the gold star medal, the soft lavender glow outside
the card edge.

Value line stays exactly "TOUGHER SHIELD, FASTER RETURN", recoloured in the
second card's purple/lavender lettering colour, no number added. Pips: FIVE
sockets, the first TWO lit purple-white, three dark.

Canvas exactly 768 x 1152, PNG, RGBA, transparent outside the card. No other
changes, no other text. Deliver as i_tod_card_riot_shield_super.png.
```

## Prompt C — build `i_tod_card_riot_shield_ultimate.png`

Attach the FINISHED regular card from Prompt A AND
`reference/i_tod_card_perkslots_ultimate.png`.

```text
Two cards are attached: the FINISHED regular RIOT SHIELD card, and an
ULTIMATE card from the same deck showing the deck's gold rarity treatment.
Produce the ULTIMATE version of the RIOT SHIELD card: keep its illustration,
title plate, value plate layout and five-socket pip row in exactly the same
positions, and apply the second card's rarity treatment - gold side rails,
gold and red panel border and doodles (a teal touch is fine), the glowing
orange-gold ULTIMATE +3 ribbon, the gold star medal, the warm gold-and-pink
glow outside the card edge with its scattered small gold sparkle crosses and
tick marks.

Value line stays exactly "TOUGHER SHIELD, FASTER RETURN", recoloured in the
second card's gold/amber lettering colour, no number added. Pips: FIVE
sockets, the first THREE lit gold, two dark.

Canvas exactly 768 x 1152, PNG, RGBA, transparent outside the card. No other
changes, no other text. Deliver as i_tod_card_riot_shield_ultimate.png.
```

## Prompt D — build the pause-menu nameplate `i_tod_pause_r45.png`

Attach `reference/i_tod_pause_r44.png`.

```text
A slim game-menu nameplate is attached (reads GUNSLINGER). Produce its
sibling reading RIOT SHIELD. Exactly 300 x 44 pixels, PNG, RGBA, transparent
outside the plate. Copy the plate exactly: the fully rounded-end dark navy
pill with its thick dark outline and the subtle lighter bevel sheen along the
top inside edge, the short bright cyan vertical notch inset at the left end,
and the same chunky white bubble lettering with a dark outline, left-aligned
after the notch, sized to fill most of the plate's height. The only change is
the words: RIOT SHIELD (two words, one space). It is about the same length
as GUNSLINGER, so keep the same size and letterspacing and end before the
right edge with the same margin the attached plate keeps. No icon, no
numbers, no other text. Deliver as i_tod_pause_r45.png.
```

## Delivery checklist

- [ ] Four files, named exactly as the table above
- [ ] Cards 768 × 1152, plate 300 × 44, all RGBA, corner pixel fully
      transparent — decode it, do not eyeball it
- [ ] Title reads `RIOT SHIELD`, spelled right, identical on all three cards
      and on the plate
- [ ] Value line reads `TOUGHER SHIELD, FASTER RETURN` on all three, identical
      text, colour only differs; no digits in it; no second line
- [ ] **Exactly FIVE pip sockets** on every card, lit 1 / 2 / 3
- [ ] The shield is WHITE with an ORANGE stripe; the edge glow matches the
      perk-slots card's accent
- [ ] No lettering on the shield, no police/riot text, no digits
- [ ] Overlay the three cards: illustration, plates and pips do not move
      between rarities
- [ ] Downscale a card to 213 × 320 and the plate to 300 × 44: everything
      still reads at a glance

## Do NOT

- Do not repeat the damage-reduction card's chest-plate / body-aura idea —
  this is a physical shield in a hand.
- Do not draw a gun, a blade, a full figure or a face.
- Do not draw three pips, or a level indicator, or a "per level" subline.
- Do not add "200 HP", "4:00", "MAX" or ANY number to the value line — it is
  deliberately generic.
- Do not put a clock with hands or digits on the recharge glyph — a ring
  arrow only.
- Do not deliver an opaque background, a different canvas size, or a subset
  of the four files — they ship together or not at all.
<!-- PACK:END -->

## Install order — do NOT reorder

1. PNGs into `source_data/tod_ui_images/_images/`.
2. Four blocks into `source_data/tod_ui_images.gdt` (clone the
   `i_tod_card_gunslinger_regular` block; change only the asset name and
   `baseImage` path — the pause plate block clones `i_tod_pause_r44`).
3. Four `image,` lines into `zone_source/zm_tower_of_doom.zone`, after the
   `image,i_tod_pause_r44` line.
4. **Only now** `CARD_SLUG[45] = "riot_shield"` in `tod_upgrade.lua`.
5. `PAUSE_PLATE_MAX` 44 → 45 in `AetheriumStartMenu.lua` AND
   `TOD_UPG_PLATE_MAX` 44 → 45 in `AetheriumScoreboard.lua` — both, same
   commit, and only once `i_tod_pause_r45` has all three legs. (If r46
   TRAILBLAZER has ALSO landed by then, go straight to 46 — the test is
   `<=` over a contiguous range.)
6. `node tools/lint_tod_lua.js`, then a **FULL** build (a `.gdt` edit is always
   a full build). Proof: four fresh content-hash `.iwi` beside an untouched
   control. Flip this STATUS to SHIPPED.

Steps 4–5 before step 3 is a `RegisterImage` on a missing image; this Lua
file fails silently and takes the whole HUD with it.
