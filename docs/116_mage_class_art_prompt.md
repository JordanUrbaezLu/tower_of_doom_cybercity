<!-- art-pack
name: mage_class
refs:
  i_tod_card_class_slasher.png | THE DRAFT CARD to match. This is the exact chassis the MAGE draft card must join - same frame, same text stack, same accent treatment.
  i_tod_card_class_heavy.png | A second draft card, for breadth. Note how the accent colour changes but nothing else does.
  i_tod_class_slasher.png | The small class GLYPH (landscape line art). Sits at the top of the draft card and nowhere else.
  i_tod_class_medallion_slasher.png | The HUD medallion disc. Square, ringed, and it must survive being shrunk to a thumbnail.
  i_tod_upg_class_slasher.png | The class NAME PLATE on the upgrade panel. Wide strip, baked type.
  i_tod_card_tier_slasher_2.png | The TIER 2 promotion card - how a weapon upgrade is drawn.
  i_tod_card_tier_slasher_3.png | The TIER 3 promotion card. Same class, one rung higher: read these two together to see how a ladder step is expressed.
  i_tod_hud_gun_katana.png | The HUD weapon icon for a melee weapon - the closest existing shape to a staff. Note it is a clean side-on silhouette, not a render.
  i_tod_hud_gun_axe.png | A second HUD weapon icon, an ornate one. Shows how much detail survives at this size.
  i_tod_card_thors_thunder_regular.png | THE RARITY LADDER, step 1 of 4. Regular.
  i_tod_card_thors_thunder_super.png | Rarity step 2. Super.
  i_tod_card_thors_thunder_ultimate.png | Rarity step 3. Ultimate - gold dressing, warm outer glow.
  i_tod_card_thors_thunder_dark.png | Rarity step 4. Dark - red dressing, magenta-tinted art window, five red pips.
  i_tod_card_vitality_regular.png | The closest existing HEALTH-themed card. The nearest neighbour to HEALING AURA in subject.
preview: 186x279 234x351 144x66 56x56 64x56 280x60
-->

# 116 — MAGE class identity, staff tiers and HEALING AURA: art request

**Status: REQUESTED 2026-09-07. Not shipped.**

Companion to `docs/115_mage_card_art_prompt.md` (the four element/attunement upgrade
cards, requested the same day). 115 covers the mage's *upgrade cards*; this doc covers
everything else the class needs to appear on screen — its identity art, its staff tier
ladder, its weapon HUD icons, and the cards for a fifth domain added today.

## Why this doc exists

The user, 2026-09-07: *"we obviously need some kind of card, like, base… major class card
for when you're selecting a class, and then we need upgraded tiers. I would say for those
right now, let's just get those in, pretty generic. We don't really know what staff we
wanna use yet."* And then: *"There's a bunch of assets we're gonna need. So let's get
those. you'll have to dig into the code to make sure we don't miss anything."*

## The sweep behind the list

The deliverables were not guessed. Every image name in `ui/` and `zone_source/` that
carries a class key was enumerated, which found **four per-class families**, not the one
the request named:

| Family | Where it draws | Would have been missed? |
|---|---|---|
| `i_tod_card_class_*` | the draft card | no — this is what was asked for |
| `i_tod_card_tier_*_2/3` | the promotion cards | no — "upgraded tiers" |
| `i_tod_class_*` | the glyph on the draft card | **yes** |
| `i_tod_class_medallion_*` | the HUD portrait, all match | **yes** |
| `i_tod_upg_class_*` | the class plate on the upgrade panel | **yes** |

Plus one family keyed on the WEAPON rather than the class — `i_tod_hud_gun_*`, the icon
in the HUD gun bay. It is per-gun (28 of them), so three staffs need three icons. That
one is only reachable through a runtime-constructed name, so no lint would ever have
reported it missing.

## Two findings that shape the request

**1. The draft card shrinks when the fifth class lands.** `tod_class_select.lua` derives
its card geometry from the class count: `CARD_W` is 210 at four classes and **186 at
five**. So every draft card — the four shipped ones included — will draw at 186×279
instead of 210×315 the day the mage goes live. The preview folder uses the new number.

**2. Tier cards are keyed `[class][tier]` through a name built at runtime**, so
`lint_tod_assets.js` cannot see them. Nothing but a hand-kept flag stands between an
unzoned mage tier card and a white square. That flag (`MAGE_ART` in `tod_upgrade.lua`)
is in, defaulted false, and `build_map.ps1` now refuses a build that turns it on for a
class no player can draft.

## What is NOT in this request

- **The element cards** (ATTUNEMENT / FIRE / AIR / ICE) — those are docs/115, already sent.
- **Pause-menu plates** for any mage domain. Plates are `i_tod_pause_rNN` over a
  *contiguous* id range capped at `PAUSE_PLATE_MAX` 47; the mage domains are 48–52, so
  claiming plates would mean baking all five. They ship on the LUI text fallback, which
  is a deliberate, working path.
- **The staff models themselves.** This is 2D UI art only.

## HEALING AURA — the new domain

Added today (user: *"a new move called healing aura. And this one is to support you and
the team, whoever's near you"*). Domain id 52, slug `mage_heal`, six levels, band A,
mage-only, and **not** gated behind a staff tier — the mage moves at 0.85 speed with
DAMAGE REDUCTION capped at 3, so its counterweight has to be draftable from the first card.

It is the fourth combat-stance cast, on the tactical button. Ten pulses over five seconds
from an aura linked to the caster, healing every living teammate standing in it; **level 6
also raises one downed teammate per cast**, which is the "revive staff" the user asked for
the same day, folded into an existing domain rather than minting a new id.

Its cards are requested at all four rarities to match 115. The dark rung is parked in
script (`set_no_dark`) exactly as the other four are — the art lands first, the rung is
designed after.

## Install notes (repo-facing, not in the pack)

Drop into `source_data/tod_ui_images/_images/`, add an `image,` line per file, then:

- `i_tod_upg_class_mage` — add the `classPlate[ 5 ]` line to `tod_upgrade.lua` **in the
  same build as its zone line**. GATE A is comment-stripped and flag-blind: wrapping the
  literal in `if MAGE_ART` still fails the build. Proven 2026-09-07.
- `i_tod_card_tier_mage_2/3` — flip `MAGE_ART = true` in `tod_upgrade.lua`.
- `i_tod_hud_gun_staff1/2/3` — flip `TOD_MAGE_ART = true` in `AetheriumLoadout.lua`.
- `i_tod_card_class_mage` / `i_tod_class_mage` — add to `tod_class_select.lua`'s `art.cards[5]`
  and `art.icons[5]`, same-build rule as above.
- `i_tod_class_medallion_mage` — **needs a wiring decision first**, not just art. The
  medallion is keyed on the stock CHARACTER id, not the class, and the four SoE bodies
  (5–8) are already spoken for. A fifth class needs a fifth body from the Primis four, and
  its `char` id can only be OBSERVED in game (three of the four current mappings were
  corrected from playtests). See the table in `AetheriumCharacters.lua`.
- `i_tod_card_mage_heal_*` — add `CARD_SLUG[52]`, and delete the `set_no_dark( "mage_heal" )`
  line only when a dark rung is actually designed.

FULL build. Cards are `uncompressed` 768×1152 — **one dead card is 3.4 MB of load RAM**,
so do not zone a card whose domain is not live.

<!-- PACK:BEGIN -->

# TOWER OF DOOM — the MAGE class: identity, staff tiers, and one new upgrade

**13 PNG files.** A fifth playable class is being added to a zombies map that already
ships four. Everything here has to sit beside existing art that players see in the same
frame, often side by side. **Consistency with the reference images is the whole job.** A
piece that is beautiful but off-style is a failure.

---

## 1. Deliverables

| # | File | Size | Draws on screen at |
|---|---|---|---|
| 1 | `i_tod_card_class_mage.png` | 768 × 1152 | 186 × 279 |
| 2 | `i_tod_class_mage.png` | 224 × 196 | 64 × 56 |
| 3 | `i_tod_class_medallion_mage.png` | 512 × 512 | 56 × 56 |
| 4 | `i_tod_upg_class_mage.png` | 420 × 90 | 280 × 60 |
| 5 | `i_tod_card_tier_mage_2.png` | 768 × 1152 | 234 × 351 |
| 6 | `i_tod_card_tier_mage_3.png` | 768 × 1152 | 234 × 351 |
| 7 | `i_tod_hud_gun_staff1.png` | 288 × 132 | 144 × 66 |
| 8 | `i_tod_hud_gun_staff2.png` | 288 × 132 | 144 × 66 |
| 9 | `i_tod_hud_gun_staff3.png` | 288 × 132 | 144 × 66 |
| 10 | `i_tod_card_mage_heal_regular.png` | 768 × 1152 | 234 × 351 |
| 11 | `i_tod_card_mage_heal_super.png` | 768 × 1152 | 234 × 351 |
| 12 | `i_tod_card_mage_heal_ultimate.png` | 768 × 1152 | 234 × 351 |
| 13 | `i_tod_card_mage_heal_dark.png` | 768 × 1152 | 234 × 351 |

Exact filenames, exact pixel sizes, PNG with alpha. No other files.

**Look at `preview_onscreen_*/` before you finish anything.** Those folders hold the
reference images downscaled to the sizes above. That is what a player actually sees. A
detail that vanishes there does not exist.

---

## 2. Who the MAGE is

The fifth class in a neon cyber-city tower. The other four are SKIRMISHER (speed),
ASSAULT (precision), HEAVY (sustained fire) and SLASHER (melee). The MAGE is the
**SPELLCASTER**: a fragile support caster who moves slower than everyone, takes more
damage than everyone, and answers with elemental spells and a healing aura.

- **Accent colour: `#59FFCC`** — a bright mint/aqua green. This is the mage's identity
  colour and it appears in every one of the 13 files. The other four classes use cyan,
  amber, red and violet, so the mint must stay clearly distinct from the cyan.
- **Weapon: an arcane staff**, in three tiers named **STAFF › TIPPED › EMPOWERED**.
- **Powers: air, fire, ice and healing.**

---

## 3. THE STAFF — read this before drawing any of it

Six of the 13 files show a staff. **They must all show the SAME staff.**

The final staff model has not been chosen yet, so **keep it archetypal and generic**. Do
not draw a staff copied from any existing game. Draw the idea of a wizard's staff:

- **Tier 1 — "STAFF".** A plain straight shaft, gently tapered, a wrapped leather grip
  around the middle, and a small rough crystal seated in a simple two-prong fork at the
  head. Almost no glow. It should read as *scavenged*, not enchanted.
- **Tier 2 — "TIPPED".** The same shaft, now with metal banding at the collar and foot,
  and a properly formed head: a cast ring holding a larger faceted crystal. A steady
  inner light. It should read as *made*.
- **Tier 3 — "EMPOWERED".** The same shaft again, with a full ornamental head — spread
  vanes or wings framing a bright core stone — plus two or three smaller gems set down
  the shaft. A strong corona. It should read as *awake*.

**The ladder is the head getting richer.** Shaft length, thickness, taper and grip
position stay identical across all three. Put the three side by side before delivering:
a player must see one object at three stages, not three different props.

**The staff's own energy is the mage's mint `#59FFCC` at every tier.** Do **not** colour
tier 1 blue for air, tier 2 red for fire, tier 3 white for ice. The elements are separate
upgrades a player buys in any order; they have nothing to do with which staff is held.

---

## 4. File-by-file

### 4.1 The draft card — `i_tod_card_class_mage.png` (768 × 1152)

Shown once per match, in a row of five, while every player picks a class under a timer.
**Match `i_tod_card_class_slasher.png` exactly**: same frame, same internal layout, same
proportions, same type treatment. Only the accent colour and the content change.

Bake this text, in the same positions the reference uses:

| Slot | Text |
|---|---|
| Class name | `MAGE` |
| Weapon | `ARCANE STAFF` |
| Role | `SPELLCASTER` |
| Line 1 | `air, fire, ice and healing` |
| Line 2 | `STAFF > TIPPED > EMPOWERED` |

Central art: a hooded caster holding the **tier 1** staff, mint energy gathering at the
head. Same framing and crop as the reference cards.

⚠️ At 186 × 279 the two description lines are very small. Check them in the preview
folder. If they are not readable there, the type is wrong, however good it looks at
full size.

### 4.2 The class glyph — `i_tod_class_mage.png` (224 × 196)

Landscape line art on transparency, drawn at 64 × 56 at the top of the draft card. Match
`i_tod_class_slasher.png` — same stroke weight, same flat single-colour treatment, same
optical weight in frame.

Subject: **a staff head with a crystal, three-quarter view**, or a staff crossed over an
open palm. Simple enough to survive 64 px wide. Mint on transparency.

### 4.3 The HUD medallion — `i_tod_class_medallion_mage.png` (512 × 512)

A round badge in the corner of the HUD for the whole match, drawn at **56 × 56** — and
every teammate wears theirs too, so up to four are on screen at once. Match
`i_tod_class_medallion_slasher.png`: same disc, same ring, same depth treatment.

**It must be square and it must be a circle**, because the box that draws it is square
and the art gets stretched to fill it.

Subject: the simplest possible mage mark — a crystal, or a staff head — inside the ring.
This is the single hardest legibility test in the set. Solve it at 56 px first and scale
the idea up. Thin strokes disappear here; the ring's hard outer edge is what keeps it
readable, so keep the ring.

### 4.4 The class plate — `i_tod_upg_class_mage.png` (420 × 90)

A wide name plate on the upgrade panel, drawn at 280 × 60. Match
`i_tod_upg_class_slasher.png` exactly — same chassis, same bake, same type size and
placement. Baked text: **`MAGE`**. Accent mint.

### 4.5 The tier cards — `i_tod_card_tier_mage_2.png` / `_3.png` (768 × 1152 each)

These are the promotion cards a player is offered to upgrade their staff. Study
`i_tod_card_tier_slasher_2.png` and `_3.png` **together** — they show how one ladder step
is expressed, and the mage pair must express its step the same way.

- **Tier 2** shows the **TIPPED** staff. Baked text `TIER 2` and `TIPPED` in the slots
  the reference uses for the same purpose.
- **Tier 3** shows the **EMPOWERED** staff. Baked text `TIER 3` and `EMPOWERED`.

Same crop, same lighting, same background treatment on both, so the only thing that
changes between them is the staff and the label. Both draw at 234 × 351.

### 4.6 The HUD weapon icons — `i_tod_hud_gun_staff1/2/3.png` (288 × 132 each)

The icon in the HUD gun bay showing what the player is holding, drawn at **144 × 66**.
Match `i_tod_hud_gun_katana.png` and `i_tod_hud_gun_axe.png`: a clean side-on
**silhouette-forward** treatment on transparency, not a render, not a scene.

- `staff1` = the plain STAFF, `staff2` = TIPPED, `staff3` = EMPOWERED.
- The cell is landscape (2.18 : 1) and a staff is long and thin, so **lay it diagonally**
  and fill the cell the way the axe reference does.
- The three must be **distinguishable from each other at 144 × 66**. That is the whole
  point of having three. If the difference is only visible at full size, push the head
  silhouettes further apart — a bigger head, added vanes, a wider collar — rather than
  adding fine detail.

### 4.7 HEALING AURA — the four upgrade cards (768 × 1152 each)

An upgrade card offered mid-match, drawn at 234 × 351, seen beside 44 existing cards.

**THE ONE HARD RULE, and getting it wrong is what would make these look foreign:** look
at `i_tod_card_thors_thunder_regular.png`, `i_tod_card_thors_thunder_super.png`,
`i_tod_card_thors_thunder_ultimate.png` and `i_tod_card_thors_thunder_dark.png` side by side. **The central illustration is
identical in all four.** Only the frame dressing changes — chassis colour, title band,
rarity plate, medallion, description text colour, pip count, and (dark only) a magenta
tint over the art window.

So: draw **ONE artwork** and dress it four ways, copying the dressing from those four
`thors_thunder` references exactly.

- **Title:** `HEALING AURA`
- **Description line:** `an aura that heals you and every teammate standing in it`
- **Bake no numbers.** Card art in this game is level-agnostic — values live in the menu,
  not on the card. `i_tod_card_vitality_regular.png` is the nearest existing card in
  subject; note it names no figure.

Artwork: a staff head planted low, with a **soft ring of green-gold light spreading
outward across the ground** and motes rising through it. The healing should read as an
*area* — the whole point is that it covers your teammates too — so favour a wide,
low, spreading shape over a vertical beam. Keep it warmer and softer than the mage's
sharp mint elemental spells; this is the one mage power that is kind.

---

## 5. Hard rules

1. **Exact filenames and exact pixel sizes** from the table in section 1.
2. **PNG with alpha.** No JPEG, no flattened white background.
3. **One staff, three stages** (section 3). Same shaft in all six files that show it.
4. **The staff is mint `#59FFCC` at every tier** — never element-coloured.
5. **One artwork per upgrade card, dressed four ways** (section 4.7).
6. **No numbers baked into any upgrade card.**
7. **Match the reference chassis.** These sit beside shipped art in the same frame.
8. **Check `preview_onscreen_*/`.** If it does not read there, it does not work.
9. No watermarks, no signatures, no borders of your own outside the chassis.

---

## 6. Prompts you can paste

Attach the named reference files with each.

**Draft card** — attach `i_tod_card_class_slasher.png`, `i_tod_card_class_heavy.png`:
> Match the attached class card chassis exactly — same frame, layout, proportions and
> type treatment — for a fifth class. Accent colour mint green #59FFCC. Central art: a
> hooded spellcaster holding a plain wooden staff with a small raw mint-glowing crystal
> at its head. Baked text: title MAGE, weapon ARCANE STAFF, role SPELLCASTER, line 1
> "air, fire, ice and healing", line 2 "STAFF > TIPPED > EMPOWERED". 768x1152 PNG.

**Class glyph** — attach `i_tod_class_slasher.png`:
> Match the attached glyph's stroke weight, flat single-colour treatment and optical
> weight. Subject: a staff head with a crystal, three-quarter view. Mint green #59FFCC
> on transparency. Must stay readable at 64 pixels wide. 224x196 PNG.

**Medallion** — attach `i_tod_class_medallion_slasher.png`:
> Match the attached medallion exactly — same disc, ring and depth treatment — for a
> mage class. Simple crystal or staff-head mark inside the ring, mint green #59FFCC.
> Perfectly square and circular. Must read at 56 pixels. 512x512 PNG.

**Class plate** — attach `i_tod_upg_class_slasher.png`:
> Match the attached name plate exactly — same chassis, bake, type size and placement.
> Baked text: MAGE. Accent mint green #59FFCC. 420x90 PNG.

**Tier cards** — attach `i_tod_card_tier_slasher_2.png`, `i_tod_card_tier_slasher_3.png`:
> Match the attached tier-card pair exactly. Make two cards for a mage's staff ladder.
> Card A: baked text TIER 2 / TIPPED, showing a staff with metal banding and a cast ring
> holding a faceted mint crystal. Card B: baked text TIER 3 / EMPOWERED, showing the same
> staff with an ornamental winged head around a bright core stone and smaller gems down
> the shaft. Identical shaft, crop, lighting and background in both — only the head and
> the label differ. Mint green #59FFCC energy. 768x1152 PNG each.

**HUD weapon icons** — attach `i_tod_hud_gun_katana.png`, `i_tod_hud_gun_axe.png`:
> Match the attached HUD weapon icons — clean side-on silhouette-forward treatment on
> transparency, filling the landscape cell diagonally. Three icons of the same staff at
> three stages: (1) plain shaft, small raw crystal; (2) metal banding, cast ring, faceted
> crystal; (3) ornamental winged head, bright core, gems down the shaft. They must be
> clearly distinguishable at 144x66. Mint green #59FFCC. 288x132 PNG each.

**HEALING AURA cards** — attach `i_tod_card_thors_thunder_regular.png`, `i_tod_card_thors_thunder_super.png`, `i_tod_card_thors_thunder_ultimate.png`, `i_tod_card_thors_thunder_dark.png` and `i_tod_card_vitality_regular.png`:
> Draw ONE central illustration and dress it in the four attached rarity treatments,
> copying the chassis colour, title band, rarity plate, medallion, text colour, pip count
> and dark magenta art-window tint exactly from the references. Title HEALING AURA,
> description "an aura that heals you and every teammate standing in it", no numbers
> anywhere. Illustration: a staff head planted low with a soft wide ring of green-gold
> light spreading across the ground and motes rising through it — a warm, kind, area
> effect. 768x1152 PNG each.

---

## 7. Delivery checklist

- [ ] All 13 files present, exact names, exact sizes
- [ ] PNG with alpha; nothing flattened
- [ ] The three staffs are recognisably **one** staff at three stages
- [ ] The three HUD icons are distinguishable **in the 144x66 preview**
- [ ] The medallion is square, circular, and readable **in the 56 px preview**
- [ ] The four HEALING AURA cards share one identical central illustration
- [ ] No numbers on any card
- [ ] Baked text proofread letter by letter (`STAFF > TIPPED > EMPOWERED`, `SPELLCASTER`)
- [ ] Every piece checked against `preview_onscreen_*/`

## 8. Do NOT

- Do not draw a staff copied from another game — keep it generic.
- Do not colour the staff tiers by element.
- Do not change the central illustration between the four rarity treatments.
- Do not bake numbers, levels or percentages onto a card.
- Do not invent a new frame, border or chassis for anything here.
- Do not deliver at a different resolution "for quality" — the sizes are exact.
- Do not add a signature, watermark or logo.

<!-- PACK:END -->
