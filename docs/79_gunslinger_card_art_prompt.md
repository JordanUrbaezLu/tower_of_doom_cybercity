# 79 — GUNSLINGER card art (domain 44: slasher sidearm vs bosses, 4 images)

<!-- art-pack
name: gunslinger
refs:
  i_tod_card_knife_speed_regular.png | a SLASHER card from the same deck, max 5: the SLASHER accent colour to match, and the FIVE-pip row (first lit) to copy exactly. Attach to every card prompt.
  i_tod_card_giant_slayer_regular.png | the assault's boss-damage card: the robot-boss motif to echo. Do NOT copy its amber accent or its numbered value line. Attach to Prompt A.
  i_tod_card_giant_slayer_super.png | the SUPER rarity treatment (purple rails, ribbon, glow, gold medal, 2 lit pips). Attach to Prompt B.
  i_tod_card_giant_slayer_ultimate.png | the ULTIMATE rarity treatment (gold rails, ribbon, glow, sparkles, 3 lit pips). Attach to Prompt C.
  i_tod_pause_r43.png | the CURRENT pause-menu nameplate style (ATHLETE): copy the pill, notch and lettering exactly with the new word. Attach to Prompt D.
preview: 213x320 300x44
-->

> **STATUS: SHIPPED v16.54, 2026-09-02 19:08 — UNPLAYED.** Drop `files - 2026-09-02T190025.581.zip`: 4 files installed, 4 GDT blocks, 4 zone lines, `CARD_SLUG[44]`, `PAUSE_PLATE_MAX` and `TOD_UPG_PLATE_MAX` 43 → 44; 4 fresh content-hash `.iwi` beside untouched `i_tod_pause_r43`. (Historical, pre-drop:) The domain
> ships on the TEXT fallbacks (VITALITY / RECOVERY / PERK SLOTS / DISTRACTION
> precedent): `CARD_SLUG[44]` unset, `PAUSE_PLATE_MAX` (AetheriumStartMenu.lua)
> and `TOD_UPG_PLATE_MAX` (AetheriumScoreboard.lua) stay **43** until all four
> PNGs are installed AND zoned. Pack built by
> `.\tools\make_art_pack.ps1 docs\79_gunslinger_card_art_prompt.md` →
> `~/Downloads/tod_gunslinger_art_pack.zip`.

## The domain

- **Key** `gunslinger`, id **44**, **SLASHER only**, band **B**, **max 5**,
  scope `class` (survives tier promotions).
- **Effect:** the slasher's class SIDEARM (AMP63 → UDM-45 → RK7) deals **+30%
  per level** against bosses and elites, on top of the class's 2.25× sidearm
  baseline. Lv5 = +150% (5.625× total). ONE line in
  `slasher_sidearm_boss_mult`, constant `TOD_UPG_GUNSLINGER_PER_LVL`.
- **Why:** the blade is ×0.33 against the triad; the sidearm is the slasher's
  boss answer and this is its ladder.

**NO NUMBER ON THE CARD** (user 2026-09-02: *"convert to generic text so this
can be prevented in future where possible"*): the value line is
`SIDEARM SHREDS BOSSES`, identical on all three rarities, so a retune of the
30%/Lv owes no re-bake. The pause menu (`DETAIL[44]`) carries the live number.
**5 pips** (max 5): 1 / 2 / 3 lit. **SLASHER accent** — sample it from the
knife-speed reference, never from prose.

<!-- PACK:BEGIN -->
# GUNSLINGER — a new upgrade card (3 rarities) + its pause-menu nameplate

## What this is

A Call of Duty: Black Ops 3 zombies map has a deck of upgrade cards (drawn at
**213 × 320 px on screen**, see `preview_onscreen_213x320/`) and a matching
row of slim pause-menu nameplates (**300 × 44**, see
`preview_onscreen_300x44/`). A new upgrade needs its four images. **The
attached cards ARE the style — match them exactly.** A new card has to sit in
a hand beside them and look like it came out of the same deck.

The upgrade: **GUNSLINGER** — the knife-fighter class's backup pistol hits
bosses and giant elite enemies harder. One card per rarity, then one nameplate.

**Deliver exactly FOUR files:**

| Deliver as | Size | Value line (exact) | Pips |
|---|---|---|---|
| `i_tod_card_gunslinger_regular.png` | 768 × 1152 | **`SIDEARM SHREDS BOSSES`** | 5 sockets, **1 lit** |
| `i_tod_card_gunslinger_super.png` | 768 × 1152 | **`SIDEARM SHREDS BOSSES`** | 5 sockets, **2 lit** |
| `i_tod_card_gunslinger_ultimate.png` | 768 × 1152 | **`SIDEARM SHREDS BOSSES`** | 5 sockets, **3 lit** |
| `i_tod_pause_r44.png` | 300 × 44 | **`GUNSLINGER`** | — |

All four RGBA with a **fully transparent background** — the card body and the
plate sit on transparency, they do not fill the frame.

## References (in `reference/`)

- `i_tod_card_knife_speed_regular.png` — a card of the SAME CLASS. Two things
  come from it: the **accent colour** of its illustration (the class's colour —
  sample it from the image; it is not the amber the boss card uses), and the
  **five-socket pip row** at the bottom (size, spacing, position; first lit).
- `i_tod_card_giant_slayer_regular.png` — the other class's boss-damage card.
  Its robot-boss motif is the enemy this card is also about, so echo it, but
  the composition must be new (below). Do NOT copy its numbered value line —
  this card's value line has no number.
- `i_tod_card_giant_slayer_super.png`, `_ultimate.png` — the SUPER and ULTIMATE
  rarity treatments to apply to the finished regular card.
- `i_tod_pause_r43.png` — the current nameplate style; the new plate is this
  with a different word.

## The card template (identical on all three rarities)

**Canvas:** 768 × 1152 portrait, transparent outside the card edge, the same
small margin as the attached cards.

1. **Card body** — rounded-corner near-black navy card with a very thick black
   outline, faint horizontal scanlines, a small dark cross-head screw in each
   corner, a slim vertical accent rail inside the left and right edges
   (rarity-coloured).
2. **Title plate** — the rounded orange-to-amber gradient plate with a black
   outline and seven small studs along its top edge, holding **`GUNSLINGER`** in
   chunky white bubble letters with a heavy dark outline. One line, all caps,
   identical on all three.
3. **Illustration panel** — the rounded darker-navy inset panel with a soft
   radial sheen at the top, faint scanlines, a thin inner border, the four
   tiny corner pixel squares and two or three small sparkle glyphs, exactly as
   on the attached cards. The illustration goes inside it.
4. **Rarity ribbon** — the gradient pill with a dark notched arrowhead each
   side, rarity text in the same bubble lettering; the round star medal
   overlapping the panel's bottom-right corner.
5. **Value plate** — the dark inset rectangle with a thin rounded inner frame
   and a rivet in each corner, holding **ONE centred line** of chunky all-caps
   outlined lettering: **`SIDEARM SHREDS BOSSES`** — identical text on all
   three cards, only the colour differs (see the rarity table). No second line,
   no number.
6. **Pip row** — **FIVE** round sockets, copied from the knife-speed card.

## The illustration (identical on all three rarities)

A chunky flat-cartoon **compact machine pistol held in one gloved hand**,
seen three-quarters from the side, filling the lower-left two-thirds of the
panel, its muzzle pointed up-right with a bright white-and-class-colour muzzle
flash. The gun's accent stripes and the hand's cuff are in the **class accent
colour sampled from the knife-speed card**. Behind and above it, larger but
receding into the panel's navy, the **boxy robot-boss silhouette** the
giant-slayer card uses (round head with a single glowing orange visor slit,
square shoulders), drawn darker and flatter than the pistol so it reads as the
target, with a small orange impact starburst where the shot lands on its
chest. Two or three short cartoon tracer lines between muzzle and impact.

No human face or body beyond the gloved hand and forearm. No blades or knives
on this card (the pistol is the point). No hearts, health bars, blood, text
inside the panel, or digits anywhere except the rarity ribbon.

## Rarity treatment — the ONLY differences between the three cards

| | REGULAR | SUPER | ULTIMATE |
|---|---|---|---|
| side rails, panel border, doodles | cyan | purple/violet (+ a teal touch) | gold and red (+ a teal touch) |
| rarity ribbon | silver/grey, text `REGULAR +1` | glowing purple, text `SUPER +2` | glowing orange-gold, text `ULTIMATE +3` |
| medal | silver | gold | gold |
| value-line lettering | pale grey-blue | purple/lavender | gold/amber |
| outer glow | none | soft lavender glow round the card edge | warm gold-and-pink glow plus scattered small gold sparkle crosses and tick marks outside the border |
| pips (5 sockets) | first lit white, 4 dark | first 2 lit purple-white, 3 dark | first 3 lit gold, 2 dark |

Take every one of these from the attached giant-slayer super/ultimate cards —
they are the deck's rarity treatment, not a description to reinterpret.

## Hard rules

- Flat colours, thick black outlines, simple soft shading. No photorealism, no
  3D render look, no drop shadows on text.
- Text on the cards is exactly three strings: `GUNSLINGER`, the rarity
  ribbon, and the value line. **No other text, no logos, no watermark.**
- **No digits anywhere** except the `+1/+2/+3` in the ribbon. The value line
  carries NO number on purpose.
- **Exactly FIVE pip sockets** on every card. Generators normalise to three;
  count them.
- The three cards must stay registered with each other: same illustration,
  same plate positions, same pip row position; only the rarity treatment, the
  value-line colour, and the lit pips differ.
- Corner pixel of every file must be fully transparent — decode it.

## Prompt A — build `i_tod_card_gunslinger_regular.png`

Attach `reference/i_tod_card_knife_speed_regular.png` AND
`reference/i_tod_card_giant_slayer_regular.png`.

```text
Two upgrade cards from a Black Ops 3 zombies map are attached. They ARE the
style: match them exactly and produce a NEW card of the same deck. Deliver at
exactly 768 x 1152 pixels, PNG, RGBA, transparent outside the card, same
margin as the attached cards. Flat cartoon, thick black outlines, no
photorealism.

Copy from the attached cards, unchanged: the navy rounded card body with the
thick black outline, corner screws and scanlines; the cyan side rails; the
orange-to-amber title plate with seven studs; the darker-navy illustration
panel with its sheen, inner border, corner pixel squares and sparkles; the
silver REGULAR +1 ribbon with notched arrowheads and the silver star medal
overlapping the panel's bottom-right corner; the dark riveted value plate; and
the FIVE-socket pip row from the FIRST card (knife speed), first socket lit
white, four dark.

Title plate text: GUNSLINGER (chunky white bubble letters, dark outline).

Illustration: a chunky flat-cartoon compact machine pistol held in one gloved
hand, seen three-quarters from the side, filling the lower-left two thirds of
the panel, muzzle pointed up-right with a bright muzzle flash. The gun's
accent stripes and the glove cuff use the SAME accent colour as the first
card's illustration (sample it from the image). Behind and above, larger but
receding into the panel's navy, the boxy robot boss from the SECOND card
(round head, single orange visor slit, square shoulders), darker and flatter
than the pistol, with a small orange impact starburst on its chest where the
shot lands and two or three short tracer lines from muzzle to impact. No
blades, no faces, no blood, no text inside the panel.

Value plate: ONE centred line of chunky all-caps outlined lettering in pale
grey-blue: SIDEARM SHREDS BOSSES. No number in it, no second line.

No other text, no other digits, no watermark. Deliver as
i_tod_card_gunslinger_regular.png.
```

## Prompt B — build `i_tod_card_gunslinger_super.png`

Attach the FINISHED regular card from Prompt A AND
`reference/i_tod_card_giant_slayer_super.png`.

```text
Two cards are attached: the FINISHED regular GUNSLINGER card, and a SUPER card
from the same deck showing the deck's purple rarity treatment. Produce the
SUPER version of the GUNSLINGER card: keep its illustration, title plate,
value plate layout and five-socket pip row in exactly the same positions, and
apply the second card's rarity treatment - purple/violet side rails, purple
panel border and doodles (a teal touch is fine), the glowing purple SUPER +2
ribbon, the gold star medal, the soft lavender glow outside the card edge.

Value line stays exactly "SIDEARM SHREDS BOSSES", recoloured in the second
card's purple/lavender lettering colour, no number added. Pips: FIVE sockets,
the first TWO lit purple-white, three dark.

Canvas exactly 768 x 1152, PNG, RGBA, transparent outside the card. No other
changes, no other text. Deliver as i_tod_card_gunslinger_super.png.
```

## Prompt C — build `i_tod_card_gunslinger_ultimate.png`

Attach the FINISHED regular card from Prompt A AND
`reference/i_tod_card_giant_slayer_ultimate.png`.

```text
Two cards are attached: the FINISHED regular GUNSLINGER card, and an ULTIMATE
card from the same deck showing the deck's gold rarity treatment. Produce the
ULTIMATE version of the GUNSLINGER card: keep its illustration, title plate,
value plate layout and five-socket pip row in exactly the same positions, and
apply the second card's rarity treatment - gold side rails, gold and red panel
border and doodles (a teal touch is fine), the glowing orange-gold ULTIMATE +3
ribbon, the gold star medal, the warm gold-and-pink glow outside the card edge
with its scattered small gold sparkle crosses and tick marks.

Value line stays exactly "SIDEARM SHREDS BOSSES", recoloured in the second
card's gold/amber lettering colour, no number added. Pips: FIVE sockets, the
first THREE lit gold, two dark.

Canvas exactly 768 x 1152, PNG, RGBA, transparent outside the card. No other
changes, no other text. Deliver as i_tod_card_gunslinger_ultimate.png.
```

## Prompt D — build the pause-menu nameplate `i_tod_pause_r44.png`

Attach `reference/i_tod_pause_r43.png`.

```text
A slim game-menu nameplate is attached (reads ATHLETE). Produce its sibling
reading GUNSLINGER. Exactly 300 x 44 pixels, PNG, RGBA, transparent outside
the plate. Copy the plate exactly: the fully rounded-end dark navy pill with
its thick dark outline and the subtle lighter bevel sheen along the top inside
edge, the short bright cyan vertical notch inset at the left end, and the
same chunky white bubble lettering with a dark outline, left-aligned after the
notch, sized to fill most of the plate's height. The only change is the word:
GUNSLINGER. It is longer than ATHLETE, so tighten the letterspacing slightly
or reduce the size a little so it still ends before the right edge with the
same margin the attached plate keeps. No icon, no numbers, no other text.
Deliver as i_tod_pause_r44.png.
```

## Delivery checklist

- [ ] Four files, named exactly as the table above
- [ ] Cards 768 × 1152, plate 300 × 44, all RGBA, corner pixel fully
      transparent — decode it, do not eyeball it
- [ ] Title reads `GUNSLINGER`, spelled right, identical on all three cards
      and on the plate
- [ ] Value line reads `SIDEARM SHREDS BOSSES` on all three, identical text,
      colour only differs; no digits in it; no second line
- [ ] **Exactly FIVE pip sockets** on every card, lit 1 / 2 / 3
- [ ] The accent colour matches the knife-speed card, not the amber boss card
- [ ] Overlay the three cards: illustration, plates and pips do not move
      between rarities
- [ ] Downscale a card to 213 × 320 and the plate to 300 × 44: everything
      still reads at a glance

## Do NOT

- Do not put a knife, sword or blade on the card — the pistol is the point.
- Do not use the boss card's amber as the class accent.
- Do not draw three pips, or a level indicator, or a "per level" subline.
- Do not add "MAX", "x2.25", "+30%" or ANY number to the value line — it is
  deliberately generic.
- Do not deliver an opaque background, a different canvas size, or a subset
  of the four files — they ship together or not at all.
<!-- PACK:END -->

## Install order — do NOT reorder

1. PNGs into `source_data/tod_ui_images/_images/`.
2. Four blocks into `source_data/tod_ui_images.gdt` (clone the
   `i_tod_card_athlete_regular` block; change only the asset name and
   `baseImage` path — the pause plate block clones `i_tod_pause_r43`).
3. Four `image,` lines into `zone_source/zm_tower_of_doom.zone`, after the
   `image,i_tod_pause_r43` line.
4. **Only now** `CARD_SLUG[44] = "gunslinger"` in `tod_upgrade.lua`.
5. `PAUSE_PLATE_MAX` 43 → 44 in `AetheriumStartMenu.lua` AND
   `TOD_UPG_PLATE_MAX` 43 → 44 in `AetheriumScoreboard.lua` — both, same
   commit, and only once `i_tod_pause_r44` has all three legs.
6. `node tools/lint_tod_lua.js`, then a **FULL** build (a `.gdt` edit is always
   a full build). Proof: four fresh content-hash `.iwi` beside an untouched
   control. Flip this STATUS to SHIPPED.

Steps 4–5 before step 3 is a `RegisterImage` on a missing image; this Lua
file fails silently and takes the whole HUD with it.
