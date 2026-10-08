<!-- art-pack
name: mage_class_tiers
refs:
  i_tod_card_class_slasher.png | THE CLASS-CARD CHASSIS to match. Note its central art is the WEAPON itself, and its bottom panel is primary name + rule + secondary name.
  i_tod_card_class_heavy.png | A second class card, for breadth - the accent colour changes and nothing else does.
  i_tod_card_class_mage.png | THE CURRENT mage class card, being REPLACED. Keep its frame and its mint accent; the central art and the bottom panel change.
  i_tod_card_tier_slasher_2.png | THE TIER-CARD CHASSIS. Note the UNPACKED banner across the foot of the art window and the 2-of-3 pips.
  i_tod_card_tier_slasher_3.png | The same class one rung higher - read it WITH the tier 2 above to see exactly what a ladder step changes.
  i_tod_card_tier_heavy_2.png | A second tier card, for breadth.
  i_tod_card_tier_mage_2.png | THE CURRENT mage tier 2, being REPLACED.
  i_tod_card_tier_mage_3.png | THE CURRENT mage tier 3, being REPLACED.
  i_tod_hud_gun_staff1.png | THE LIGHTNING STAFF as it is drawn in game. The cards must show THIS staff.
  i_tod_hud_gun_staff2.png | THE FIRE STAFF as it is drawn in game.
  i_tod_hud_gun_staff3.png | THE ICE STAFF as it is drawn in game.
preview: 186x279 234x351 144x66
-->

# 121 — MAGE class + tier cards: the revamp

**Status: SHIPPED v18.47, 2026-09-08.** The drop came back in two variants — a
pale-metal set and a wooden one — and the user chose the wood
(`files - 2026-09-08T142751.246.zip`): dark timber shafts with gold banding. All
three cards to brief on the first pass; nothing was sent back for revision. Held back from `docs/120` at the user's
request — *"Everything except the class and tier cards. We will do those later
cause I want something specific."* This is that specific thing.

## What the user asked for, 2026-09-08

> *"We now need to do a revamp of the class cards. We have tier one, tier two,
> tier three… The first one will need to say lightning staff. The class name
> will be the mage, and the image will be the lightning staff. There is no
> secondary, so we won't have anything there… Then the tier two… the weapon name
> needs to be Fire Staff, and the content needs to be the lightning staff and the
> fire staff crossing… it should say unpacked. It match the same design as the
> other cards. And then the third tier for the class will be all three. It'll be
> the lightning, the fire staff crossed with the ice staff down the middle. So to
> indicate that you're getting all three. That's what the content will be, and
> then the weapon name will be ice staff."*

## Why the shipped three are wrong

They were drawn on 2026-09-07, hours before the class was revamped, and they
describe a mage that no longer exists:

| Shipped card | Says | Reality since v18.30 |
|---|---|---|
| class | `ARCANE STAFF` + `AIR, FIRE, ICE AND HEALING` + `STAFF > TIPPED > EMPOWERED` | AIR is retired; the ladder is LIGHTNING → FIRE → ICE |
| tier 2 | `TIPPED` / `ARCANE STAFF`, one generic mint staff | tier 2 grants the **FIRE STAFF**, and you keep the lightning one |
| tier 3 | `EMPOWERED` | tier 3 grants the **ICE STAFF**, and you keep the other two |

The class is **ADDITIVE** — a promotion ADDS a staff rather than swapping it, so
a tier-3 mage is holding all three at once. That is exactly what the crossed
artwork is for, and it is the one thing these cards have never communicated.

## The secondary slot

Every other class card fills the bottom panel with `PRIMARY` / rule /
`SECONDARY` (slasher: `COMBAT KNIFE` / `AMP63`). **The mage has no sidearm** —
its three loadout slots are the three staffs — so that panel carries ONE line on
all three cards, with no rule and no second line.

## Install notes (repo-facing, not in the pack)

Same three filenames as the shipped cards, so the install is a straight file
swap: no GDT block, no zone line, no `CARD_SLUG`, no `MAGE_ART` flag change (it
is already true and all three names are already zoned). FULL build; proof is a
fresh content-hash `.iwi` for each beside an untouched control.

<!-- PACK:BEGIN -->

# TOWER OF DOOM — the MAGE's three class cards

**3 PNG files, 768 × 1152 each.** These replace three cards that already ship, at
the same filenames, in a deck the player sees beside four other classes' cards.
**Matching the reference chassis is the whole job.**

---

## 1. Deliverables

| # | File | Card | Draws on screen at |
|---|---|---|---|
| 1 | `i_tod_card_class_mage.png` | TIER 1 — the class draft card | 186 × 279 |
| 2 | `i_tod_card_tier_mage_2.png` | TIER 2 — a promotion card | 234 × 351 |
| 3 | `i_tod_card_tier_mage_3.png` | TIER 3 — a promotion card | 234 × 351 |

Exact filenames, exact size, PNG with alpha (the card body sits on transparency
and does not fill the canvas). No other files.

---

## 2. Who the MAGE is, in one paragraph

A spellcaster class in a neon cyber-city zombies map. It carries **three
elemental staffs** — lightning, fire and ice — and **keeps every one it earns**:
at tier 1 it holds the lightning staff, at tier 2 lightning *and* fire, at tier 3
all three. That accumulation is the whole point of these three cards, and it is
why tiers 2 and 3 show staffs *crossed* rather than one staff on its own.

Its accent colour is **mint green `#59FFCC`**, already used on the current cards
— keep it.

---

## 3. THE THREE STAFFS — draw these exact three

`reference/i_tod_hud_gun_staff1.png`, `staff2.png` and `staff3.png` are the three
staffs as the game draws them. **The cards must show the same three objects.**
They share one dark shaft with a wrapped grip and differ only in the head:

| Staff | Head | Colour |
|---|---|---|
| **LIGHTNING** (`staff1`) | two upswept prongs with a jagged bolt arcing between their tips | electric blue |
| **FIRE** (`staff2`) | heavy inward-curling horns cradling a round molten stone | orange-red |
| **ICE** (`staff3`) | a fan of sharp angular crystal shards spreading from a collar | pale cyan |

Draw them at card scale — larger, richer and more lit than the tiny HUD icons —
but keep each head's **silhouette** recognisably the same. A player who has seen
the icon must recognise the staff on the card.

---

## 4. Card 1 — `i_tod_card_class_mage.png` (TIER 1)

**Match `reference/i_tod_card_class_slasher.png` exactly** for frame, layout,
proportions and type. Then keep the mint accent from
`reference/i_tod_card_class_mage.png` (its frame is already right; the art window
and the bottom panel are what change).

Top to bottom:

| Element | What it must say / show |
|---|---|
| Title band | `TIER 1` |
| Role line, top of the art window | `SPELLCASTER` — keep it; every class card has one |
| Central art | **the LIGHTNING STAFF alone**, laid diagonally and filling the window, the way the slasher card shows its combat knife |
| Class plate | `MAGE` |
| Bottom panel | **`LIGHTNING STAFF`**, one centred line, mint |
| Pip row | 1 of 3 lit |

⚠️ **THE BOTTOM PANEL HAS ONE LINE AND NO RULE.** The slasher card shows
`COMBAT KNIFE`, a thin horizontal rule, then `AMP63` — that second line is the
class's sidearm. **The mage has no sidearm.** Draw the panel with a single
centred line and delete the rule and the second line entirely; do not stretch the
one line to fill, and do not invent a subtitle for the empty space.

**What comes OFF this card:** the hooded figure (the staff replaces it), and both
lines of the old bottom panel — `ARCANE STAFF`, `AIR, FIRE, ICE AND HEALING` and
`STAFF > TIPPED > EMPOWERED` are all gone.

---

## 5. Card 2 — `i_tod_card_tier_mage_2.png` (TIER 2)

**Match `reference/i_tod_card_tier_slasher_2.png` exactly** — the tier cards have
a different chassis from the class card: a coloured outer glow, corner brackets
in the art window, and the `UNPACKED` banner.

| Element | What it must say / show |
|---|---|
| Title band | `TIER 2` |
| Central art | **the LIGHTNING STAFF and the FIRE STAFF CROSSED** in an X, both fully visible |
| Banner across the foot of the art window | `UNPACKED` — same cream-on-dark-red plate as the reference, unchanged |
| Class plate | `MAGE` |
| Bottom panel | **`FIRE STAFF`**, one centred line, mint. No rule, no second line |
| Pip row | 2 of 3 lit |
| Outer glow | mint |

There is **no role line** on the tier cards — the art window is the artwork and
the banner only.

---

## 6. Card 3 — `i_tod_card_tier_mage_3.png` (TIER 3)

Identical to card 2 in every respect except the four below. Put the two side by
side before delivering: a player must read them as one ladder.

| Element | What it must say / show |
|---|---|
| Title band | `TIER 3` |
| Central art | **all three staffs**: lightning and fire CROSSED in an X behind, and the **ICE STAFF VERTICAL DOWN THE MIDDLE, in front of both** |
| Bottom panel | **`ICE STAFF`**, one centred line, mint |
| Pip row | 3 of 3 lit |

The ice staff sits in front and upright so the card reads instantly as *three*,
not as a busier version of card 2. Keep all three heads clear of each other and
clear of the `UNPACKED` banner.

---

## 7. The one thing that makes this set work

Cards 2 and 3 are a **story about accumulation**: one staff, then two crossed,
then three. Lay all three finished cards in a row and check that story reads at
the sizes in section 1 — at 234 × 351 a viewer should count the staffs without
effort. If the third card looks like a cluttered version of the second rather
than an obvious step up, the ice staff needs to be bigger and more separated, not
more detailed.

---

## 8. Hard rules

1. **Exact filenames, 768 × 1152, PNG with alpha**, transparent outside the card
   body, same margins as the references.
2. **Match the reference chassis** — frame, corner screws, side rails, title
   band, class plate shape, pip row, panel geometry. These sit beside four other
   classes' cards in the same frame.
3. **One line in the bottom panel on all three cards.** No rule, no second line.
4. **Keep the `UNPACKED` banner** on cards 2 and 3, exactly as the reference
   draws it.
5. **The three staffs must match the attached HUD icons** (section 3).
6. **Mint `#59FFCC`** is the accent on all three.
7. **No numbers anywhere** except the `TIER 1` / `TIER 2` / `TIER 3` titles and
   the pip row.
8. **Check `preview_onscreen_*/`.** The class card draws at 186 px wide — barely
   a quarter of what you are painting. If it does not read there, it does not
   work.
9. No watermark, no signature, no border of your own.

---

## 9. Paste-ready prompts

**A — the class card.** *Attach `i_tod_card_class_slasher.png`,
`i_tod_card_class_mage.png`, `i_tod_hud_gun_staff1.png`. Open
`i_tod_card_class_heavy.png` too — a second class card, to confirm that the ONLY
thing that changes between classes is the accent colour and the content.*
> Match the first attached class card's frame, layout, proportions and type
> exactly, and keep the mint green accent of the second attached card (the
> current version of the card you are replacing). Title band `TIER 1`. Role line
> at the top of the art window: `SPELLCASTER`. Central art: a single arcane
> staff laid diagonally and filling the window, drawn at card scale but matching
> the staff in the third attachment — a dark shaft with a wrapped grip and a head
> of two upswept prongs with a jagged electric-blue bolt arcing between their
> tips. Class plate reads `MAGE`. The bottom panel contains ONE centred line in
> mint reading `LIGHTNING STAFF` — delete the thin horizontal rule and the second
> line that the first attachment uses for a sidearm, because this class has none;
> do not replace them with anything. Pip row: 1 of 3 lit. 768x1152 PNG,
> transparent background.

**B — tier 2.** *Attach `i_tod_card_tier_slasher_2.png`,
`i_tod_hud_gun_staff1.png`, `i_tod_hud_gun_staff2.png`. Open
`i_tod_card_tier_heavy_2.png` too — a second tier card at the same rung, so you
can see which parts of the chassis are fixed and which take the class colour.*
> Match the first attached tier card exactly — same frame, coloured outer glow,
> corner brackets in the art window, class plate, bottom panel, pip row and the
> cream-on-dark-red `UNPACKED` banner across the foot of the art window. Make the
> glow and the accent mint green #59FFCC. Title band `TIER 2`. Central art: TWO
> staffs crossed in an X, both fully visible above the banner — the second
> attachment's staff (dark shaft, two upswept prongs, electric-blue bolt between
> the tips) and the third attachment's staff (same shaft, heavy inward-curling
> horns cradling a round molten orange-red stone). Class plate `MAGE`. Bottom
> panel: ONE centred mint line reading `FIRE STAFF`, with no rule and no second
> line. Pip row: 2 of 3 lit. 768x1152 PNG, transparent background.

**C — tier 3.** *Attach your finished tier 2, `i_tod_card_tier_slasher_3.png`,
`i_tod_hud_gun_staff3.png`.*
> Reproduce the first attached card (your tier 2) exactly, changing only four
> things, so the two read as one ladder. (1) Title band becomes `TIER 3`.
> (2) Add a THIRD staff to the central art: the third attachment's staff — same
> dark shaft, head a fan of sharp angular pale-cyan crystal shards spreading from
> a collar — standing VERTICAL down the middle and IN FRONT of the two crossed
> staffs, so the card reads instantly as three. Keep all three heads clear of
> each other and clear of the UNPACKED banner. (3) The bottom panel's single line
> becomes `ICE STAFF`. (4) The pip row becomes 3 of 3 lit. The second attachment
> shows how the same class's tier 3 differs from its tier 2 — copy that
> relationship. Everything else identical to your tier 2. 768x1152 PNG.

---

## 10. Delivery checklist

- [ ] Three PNGs, exact names, 768 × 1152, RGBA, transparent background
- [ ] All three bottom panels have ONE line, no rule, no second line
- [ ] `LIGHTNING STAFF` / `FIRE STAFF` / `ICE STAFF`, spelled and in that order
- [ ] `TIER 1` / `TIER 2` / `TIER 3` titles; pips 1 / 2 / 3 lit
- [ ] `UNPACKED` on cards 2 and 3, not on card 1
- [ ] `SPELLCASTER` on card 1 only
- [ ] Card 2 shows two staffs, card 3 shows three, and you can count them at
      234 × 351
- [ ] The three staffs match the attached HUD icons
- [ ] Every card checked in `preview_onscreen_*/`

## 11. Do NOT

- Do not keep the hooded figure on the class card.
- Do not keep `ARCANE STAFF`, `TIPPED`, `EMPOWERED`, or any mention of AIR.
- Do not put a second line or a rule in any bottom panel.
- Do not put the `UNPACKED` banner on the class card.
- Do not invent a fourth staff or restyle the three.
- Do not change the frame, the pip row position, or the canvas size.
- Do not rename the files.
<!-- PACK:END -->
