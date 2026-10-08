<!-- art-pack
name: mage_cards
refs:
  i_tod_card_thors_thunder_regular.png | THE PRIMARY TARGET. Regular tier, and the closest existing card to an elemental power. Match this chassis exactly.
  i_tod_card_thors_thunder_super.png | The same card at SUPER. Shows the middle step of the rarity ladder.
  i_tod_card_thors_thunder_ultimate.png | The same card at ULTIMATE. Gold dressing, warm outer glow, confetti.
  i_tod_card_thors_thunder_dark.png | The same card at DARK. Red dressing, magenta-tinted art window, five red pips.
  i_tod_card_adrenaline_regular.png | A second domain at Regular, for style breadth - how a non-elemental subject is drawn.
  i_tod_card_vitality_regular.png | A third domain at Regular. Note how simple and readable the central object is.
  i_tod_pause_r47.png | THE PAUSE-PLATE CHASSIS. 300x44. The five new plates must match this exactly; only the word changes.
preview: 234x351
-->

# 115 — MAGE upgrade cards: art request

**Status: RE-REQUESTED 2026-09-07 evening. Still not shipped.**

⚠️ **THE FIRST DELIVERY CAME BACK AS A PROOF SHEET, NOT AS FILES.**
`~/Downloads/tod_mage_cards_titles_v3.png` is **1920 x 576** — five cards side by
side at ~384 x 576 each, which is EXACTLY HALF the shipped card size of
768 x 1152. The designs on it are approved and should be kept; they simply cannot
be installed. The drop that did contain files
(`files - 2026-09-07T150205.906.zip`) held only the HEALING AURA set and the
class/tier/glyph art — **no element cards at all**.

So in game, AIR BURST / FIRE BLAST / ICE SHATTER / ATTUNEMENT currently render as
the LUI **text fallback**, which is working as designed but looks unfinished.
The wiring for all five mage domains is COMPLETE and verified — `domain_id()`
maps them 48..52 and the Lua DOMAIN/DETAIL tables agree — so nothing but these
image files stands between the request and shipping them.

**RESEND AS INDIVIDUAL FULL-SIZE PNGs.** One file per name in the table below. A
contact sheet is a preview, never a deliverable.

## Why this doc exists

The user's instruction, 2026-09-07: *"the big thing I need from you are the assets ZIP … we
expect all of our images and upgrades to be consistent with each other. So throw in a couple
examples, give all the context to the LLM in the ZIP so that it knows how to make the asset."*

## What is being asked for, and what is NOT

**Four new domains × four rarities = 16 files.** ATTUNEMENT, FIRE, AIR, ICE.

The other domains the MAGE uses — BOUNTY, LUCK, DAMAGE, DAMAGE REDUCTION — are **existing
shared domains and already have their full card sets**. They need nothing. (Their per-class
caps for the mage — DR at 3, DAMAGE at 10 — are script values and do not touch art.)

## The finding that shapes the whole request

Reading the four shipped `thors_thunder` cards side by side: **the central illustration is
identical in all four.** Only the frame dressing changes — chassis colour, title band, rarity
plate, medallion, description text colour, pip count, and (dark only) a magenta tint over the
art window.

So the generator draws **ONE artwork per domain** and dresses it four ways. That is stated as
a hard rule in the pack, because getting it wrong is the one thing that would make these cards
look foreign next to the existing 44.

## Naming

Slugs are `attunement`, `mage_fire`, `mage_air`, `mage_ice`. The `mage_` prefix on the three
elements is deliberate: bare `fire` would sit confusingly beside the existing `fire_rate`,
`sprint_fire` and `suppressing_fire` slugs. Verified: no collision with any of the 44 existing
card domains.

## Install notes (repo-facing, not in the pack)

Same as every card set: drop into `source_data/tod_ui_images/_images/`, add an `image,` line
per file to the zone, add the `CARD_SLUG` entries, and rebuild FULL. `tools/lint_tod_assets.js`
GATE A hard-fails on a live path naming an image with no zone line, so the zone lines and the
slugs must land in the same build. Cards are `uncompressed` 768×1152 — **one dead card is
3.4 MB of load RAM**, so do not zone a card whose domain is not live.

<!-- PACK:BEGIN -->

# TOWER OF DOOM — MAGE upgrade cards

16 PNG files. Four new upgrade cards, each in four rarity treatments.

These join a shipped set of 44 existing cards that players see side by side in the same
picker. **Consistency with the reference images is the whole job.** A card that is beautiful
but off-style is a failure.

---

## 1. Deliverables

### 1a. The twelve cards — **768 × 1152 PNG** each

**THERE IS NO DARK CARD. Do not draw one.** All five mage domains are
`set_no_dark()` in script, so a dark card can never be dealt, cannot be zoned,
and would cost 3.4 MB of load RAM for nothing. The earlier version of this table
asked for four; that was wrong and is withdrawn.

| Domain | Regular | Super | Ultimate |
|---|---|---|---|
| ATTUNEMENT | `i_tod_card_attunement_regular.png` | `i_tod_card_attunement_super.png` | `i_tod_card_attunement_ultimate.png` |
| FIRE BLAST | `i_tod_card_mage_fire_regular.png` | `i_tod_card_mage_fire_super.png` | `i_tod_card_mage_fire_ultimate.png` |
| AIR BURST | `i_tod_card_mage_air_regular.png` | `i_tod_card_mage_air_super.png` | `i_tod_card_mage_air_ultimate.png` |
| ICE SHATTER | `i_tod_card_mage_ice_regular.png` | `i_tod_card_mage_ice_super.png` | `i_tod_card_mage_ice_ultimate.png` |

### 1b. The five pause-menu plates — **300 × 44 PNG** each

These are the name plates in the PAUSE menu's owned-upgrades list. Without them
all five mage rows show as plain text while every other class shows a plate.
Match `i_tod_pause_r47.png` exactly (same chassis, same type treatment); only the
word changes.

| Plate | Word on it |
|---|---|
| `i_tod_pause_r48.png` | AIR BURST |
| `i_tod_pause_r49.png` | FIRE BLAST |
| `i_tod_pause_r50.png` | ICE SHATTER |
| `i_tod_pause_r51.png` | ATTUNEMENT |
| `i_tod_pause_r52.png` | HEALING AURA |

Filenames must be exact, lowercase, and as written. **17 files total.**

### 1c. Do NOT redraw anything that already ships

The v3 proof sheet included a **THOR'S THUNDER** card. That is an EXISTING,
SHIPPED domain and it is not part of this request — it was only ever attached as
a style reference. Redrawing it would overwrite working art. Likewise HEALING
AURA already shipped: leave `i_tod_card_mage_heal_*` alone.

---

## 2. The reference images — open these first

In the `reference/` folder. Every one is a card currently shipping in the game; matching them
IS the task. `preview_onscreen_234x351/` holds the same six at the size a player actually
sees, which is the size your work has to survive.

| File | What to take from it |
|---|---|
| `i_tod_card_thors_thunder_regular.png` | **The primary target.** The closest existing card to an elemental power. Copy this chassis exactly — proportions, corner bolts, title dots, pips, side bars. |
| `i_tod_card_thors_thunder_super.png` | The SUPER dressing. Read its exact colours off this file; it is the middle step of the ladder. |
| `i_tod_card_thors_thunder_ultimate.png` | The ULTIMATE dressing — gold, warm outer glow, confetti. |
| `i_tod_card_thors_thunder_dark.png` | The DARK dressing — red, magenta-washed art window, five red pips, two-line description wrap. |
| `i_tod_card_adrenaline_regular.png` | Style breadth: how a non-elemental subject is drawn in the same frame. |
| `i_tod_card_vitality_regular.png` | Style breadth: how simple and readable the central object is allowed to be. Do not out-detail this. |

Attach all four `thors_thunder` files to every prompt — they are the rarity ladder. Attach
`adrenaline` and `vitality` as well when drawing ATTUNEMENT, whose subject is not an element.

## 3. THE RULE THAT MATTERS MOST

**Draw the central artwork ONCE per domain. Reuse it, pixel-identical, in all four rarities.**

Open `i_tod_card_thors_thunder_regular.png`, `_super`, `_ultimate` and `_dark` together and you
will see the cloud-and-lightning illustration is the same image in every one. Only the
surrounding frame changes.

Do not redraw, re-pose, re-light or "upgrade" the artwork for higher rarities. The rarity is
carried entirely by the frame.

The one exception: on **DARK**, the art window gets a magenta/purple colour wash over the
whole illustration. Same drawing, tinted.

---

## 4. Card anatomy

Every card, top to bottom:

1. **Outer chassis** — a rounded rectangle with a thick outer border and a small bolt/screw
   detail in each of the four corners.
2. **Title band** — a full-width rounded plate near the top with a row of seven small dots
   along its top edge. The domain name in heavy condensed uppercase, white with a thick dark
   outline.
3. **Art window** — a large inset rounded rectangle. Deep navy-blue gradient background with
   faint horizontal scanlines, scattered tiny squares and small four-point sparkle stars. The
   subject sits centred, large, and reads instantly as a silhouette.
4. **Rarity medallion** — a circular badge with a five-point star, overlapping the
   bottom-right corner of the art window.
5. **Rarity plate** — a rounded capsule below the art window with small chevrons at each end,
   carrying the rarity text.
6. **Description panel** — a recessed panel at the bottom containing an outlined box with one
   short line of chunky uppercase text.
7. **Pip row** — five small circles along the very bottom edge, some filled.
8. **Side bars** — two thin vertical light bars, one on each inner edge of the chassis.

---

## 5. The four rarity treatments

| | REGULAR | SUPER | ULTIMATE | DARK |
|---|---|---|---|---|
| Chassis | navy / indigo | see reference | black with a warm **gold** border and a soft outer glow | black with a **red** border and a soft red outer glow |
| Title band | gold / amber | gold / amber | gold / amber | **red** |
| Rarity plate | silver, reads `REGULAR +1` | reads `SUPER +2` | orange-gold, reads `ULTIMATE +3` | red, reads `DARK UPGRADE` (no number) |
| Medallion | silver ring, silver star | see reference | gold ring, gold star | red disc, white star |
| Description text | light grey, teal-outlined box | see reference | **gold**, gold-outlined box | **cream**, red-outlined box |
| Pips filled | 1 of 5, white | 2 of 5 | 3 of 5, gold | 5 of 5, red |
| Side bars | cyan | see reference | gold | dark red |
| Extra decoration | none | none | small gold/red chevrons and sparkles inside the art window and scattered in the outer margin | same confetti in red/orange, plus the magenta wash on the art window |

Take SUPER's exact values from its reference image — it is the middle step between Regular
and Ultimate.

---

## 6. The four subjects

The three elements must read as **a matched set**: same drawing language, same framing, same
weight, differing by colour and motif. ATTUNEMENT is the odd one out and should read as the
"meta" card.

### ATTUNEMENT — violet / purple
The mage's focus and recharge. Draw a floating arcane sigil or rune-ring with an inner glow,
energy spiralling inward toward a bright core — a sense of *refilling*, not of blasting. A
subtle clock or hourglass motif worked into the ring is welcome but must not dominate.
Palette: violet and magenta with white-hot centre, cool lilac rim light.
Description line: **`SPELLS RECHARGE FASTER`**

### FIRE — orange / red
An anti-armour strike. Draw a compact fireball or flame burst with a dense, molten core and
sharp flame tongues, over a faint cracked or scorched shape. It should look *heavy* — this is
the card that kills the big armoured things.
Palette: deep red through orange to a white-yellow core, dark smoke edges.
Description line: **`BURNS PANZERS AND ROBOTS`**

### AIR — green / pale teal
A horde-clearing blast. Draw a spiralling vortex or a cone of swirling wind with visible
curved motion lines sweeping outward, small debris caught in the current. It should read as
*wide* and sweeping, the opposite of Fire's concentrated punch.
Palette: pale green through emerald, white motion streaks.
Description line: **`CLEARS THE WHOLE HORDE`**

### ICE — cyan / white
Freeze and shatter. Draw a cluster of angular ice crystals or a frost burst with sharp
faceted shards radiating outward, a pale frozen mist behind.
Palette: cyan through pale blue to white, with deep blue shadow inside the facets.
Description line: **`SHATTERS HOUNDS AND ARMOR`**

---

## 7. Text to bake — exact

Title band, exactly as written:

```
ATTUNEMENT
FIRE
AIR
ICE
```

Description panel, exactly as written (wrap to two lines only if it does not fit on one — the
DARK reference shows the two-line wrap):

```
SPELLS RECHARGE FASTER
BURNS PANZERS AND ROBOTS
CLEARS THE WHOLE HORDE
SHATTERS HOUNDS AND ARMOR
```

Rarity plate text: `REGULAR +1` / `SUPER +2` / `ULTIMATE +3` / `DARK UPGRADE`.

---

## 8. Hard rules

- **768 × 1152, PNG.** No other size, no other format.
- **NO NUMBERS anywhere except the rarity plate.** No percentages, no "+15%", no level
  values, no damage figures. The card never states what the upgrade is worth — that lives
  elsewhere in the game. This is a standing rule for this project and it is broken often, so
  check your output against it before delivering.
- **One artwork per domain, reused across all four rarities.** See section 2.
- Match the reference chassis exactly — same proportions, same corner bolts, same seven title
  dots, same five pips, same side bars.
- Heavy condensed uppercase type with a thick dark outline, matching the references.
- Bold flat vector/cartoon rendering with strong dark outlines and bright rim light. Not
  photoreal, not painterly, not 3D-rendered.
- The subject must read clearly at **234 × 351**. That is not a guess and it is not half
  size — it is the exact box the game draws these in, measured from the live menu. Your art
  is shown at under a third of the width you are drawing at, so anything fine is lost.
  Check yours against the preview folder before delivering.
- Transparent background outside the chassis, as in the references.

---

## 9. Do NOT

- Do not invent a different card layout or "improve" the frame.
- Do not put numbers or percentages in the artwork or description.
- Do not redraw the art per rarity.
- Do not add a border, watermark, signature or logo.
- Do not change the filenames.
- Do not use photographic or 3D-rendered elements.
- Do not put the domain name anywhere except the title band.

---

## 10. Delivery checklist

Before sending back, confirm:

- [ ] 16 files, exact filenames from section 1
- [ ] Every file 768 × 1152 PNG
- [ ] Each domain's artwork identical across its four rarities
- [ ] No numbers outside the rarity plate
- [ ] Title and description text exactly as section 6
- [ ] Rarity dressing matches the table in section 4
- [ ] Each card still readable at half size
- [ ] The three elements read as a set beside each other

<!-- PACK:END -->
