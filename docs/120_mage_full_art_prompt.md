<!-- art-pack
name: mage_full
refs:
  i_tod_card_mage_fire_regular.png | THE CHASSIS at REGULAR, and the source for the FIRE re-copy. Every new card must match this frame exactly.
  i_tod_card_mage_fire_super.png | The same card at SUPER - the middle rung of the rarity ladder, and the SUPER re-copy source.
  i_tod_card_mage_fire_ultimate.png | The same card at ULTIMATE - gold dressing, warm outer glow, and the ULTIMATE re-copy source.
  i_tod_card_mage_ice_regular.png | The ICE card at REGULAR - re-copy source, and the second element in the set.
  i_tod_card_mage_ice_super.png | The ICE card at SUPER - re-copy source.
  i_tod_card_mage_ice_ultimate.png | The ICE card at ULTIMATE - re-copy source.
  i_tod_card_mage_heal_regular.png | The HEALING AURA card. The only mage card whose subject is an AREA rather than a projectile - closest neighbour for the new ARCHMAGE and BLINK subjects.
  i_tod_pause_r52.png | THE PAUSE-PLATE CHASSIS, 300x44. The three new plates must match this exactly; only the word changes.
  i_tod_pause_r49.png | A second plate, showing a two-word name set at the same size. Use it to judge type fitting.
  i_tod_hud_weapon_panel.png | THE PANEL TO MODIFY. The shipped weapon bay. The new mage panel is this file with one region replaced.
  i_tod_hud_health_frame.png | The shipped health/shield bar FRAME - the map's existing language for a recessed trough.
  i_tod_hud_health_fill.png | The shipped bar FILL - a flat strip that is cut left-to-right at runtime. The mana fills work the same way.
  i_tod_hud_offhand_tile.png | The tile the two new ability icons sit inside. Not a deliverable - it shows the box they must survive.
  i_tod_hud_off_frag.png | THE ICON STYLE for the two new ability icons, and the icon the mage's lethal slot replaces.
  i_tod_hud_off_monkey.png | The second shipped ability icon, for style breadth.
  i_tod_hud_gun_katana.png | HUD weapon-icon style: a clean side-on silhouette, not a render.
  i_tod_hud_gun_axe.png | A second HUD weapon icon, an ornate one - shows how much detail survives at this size.
  i_tod_hud_gun_staff1.png | The CURRENT staff-1 icon, being replaced. Keep its treatment, change its subject.
  i_tod_hud_gun_staff2.png | The CURRENT staff-2 icon, being replaced.
  i_tod_hud_gun_staff3.png | The CURRENT staff-3 icon, being replaced.
preview: 234x351 384x111 144x66 24x24
-->

# 120 — MAGE: the complete art request (everything but the class and tier cards)

**Status: SHIPPED v18.43, 2026-09-08.** The drop
(`files - 2026-09-08T111404.855.zip`) came back complete on the first pass — all
26 files, every one at the requested size and RGBA, the six re-bakes changed only
their description panel, and the mana panel's trough measured **x 416..1007,
y 152..263** against the x416..1008 / y152..264 the brief asked for. Nothing was
sent back for revision.

The user, 2026-09-08: *"Now we have the entire class done and finalized. …we need
new assets so I need you to first work towards getting me a full comprehensive zip
with full context and keep consistent. I need all the assets in one go. Everything
except the class and tier cards. We will do those later cause I want something
specific."*

So this doc is the ONE request for the finished mage. It supersedes the outstanding
half of docs/115 and docs/116 — both were written on 2026-09-07, before the class was
revamped that night, and both describe a class that no longer exists (a mint "arcane
staff" ladder with an AIR element and an ATTUNEMENT domain).

## Deliberately OUT of scope

- `i_tod_card_class_mage.png` — the draft card. The user is designing this.
- `i_tod_card_tier_mage_2.png` / `_3.png` — the promotion cards. Same.
- `i_tod_class_mage.png`, `i_tod_class_medallion_mage.png`, `i_tod_upg_class_mage.png` —
  the glyph, the HUD medallion and the upgrade-panel plate. **All three shipped
  2026-09-07 and all three still work**: they carry a generic mage mark in the class's
  mint, and nothing about the revamp made them wrong. They are held back on purpose —
  if the user's class card lands on a different identity colour, these three get
  re-requested to match it in one pass rather than being drawn twice.
- The staff MODELS and their FX. Those are in-engine assets, not UI art.

## What changed under the old docs, and why they cannot just be re-sent

| Old request | Now |
|---|---|
| AIR BURST card (`mage_air`, id 48) | domain RETIRED. The three regular/super/ultimate files sit unzoned on disk as dead weight. |
| ATTUNEMENT card (`mage_attune`, id 51) | domain RETIRED and its slug + three zone lines already removed (v18.41). |
| four elemental CASTS off one staff | THREE STAFFS, one per tier: lightning (T1), fire (T2), ice (T3). Each is a real held weapon. |
| a mint STAFF › TIPPED › EMPOWERED ladder | the three staff HUD icons must now show three DIFFERENT elemental staffs, not one staff at three polish levels. |
| healing aura on the aim button | on the LETHAL slot, with charges. The aim button is ARCHMAGE. |
| — | new domains CHAIN LIGHTNING (53), ARCHMAGE (54), BLINK (55). No art at all. |
| — | a MANA BAR replaces the ammo readout. No art at all. |

## The two re-copies, and why they are worth six files

Both shipped element cards bake a claim the code contradicts:

- **FIRE BLAST** reads `BURNS PANZERS AND ROBOTS`. In `staff_mult()` every staff takes
  `TOD_MAGE_VS_PANZER` 0.40 against a Panzer — fire included. Fire's ×2 is against the
  Rogue Protector (the robot) and the armored sprinter. The card teaches the exact
  opposite of the class's central trade, which the user specified in as many words:
  *"overall, the mage be pretty weak against the pansers."*
- **ICE SHATTER** reads `SHATTERS HOUNDS, FURY, AND ARMORED`. Ice's ×2 is hellhound +
  reaver. `AND ARMORED` is fire's line, not ice's.

Artwork on both is correct and stays pixel-identical; only the description panel changes.

## Install notes (repo-facing, not in the pack)

- Cards: drop into `source_data/tod_ui_images/_images/`, one `image,` line each, then
  `CARD_SLUG[53] = "mage_bolt"`, `[54] = "mage_arch"`, `[55] = "mage_blink"`.
  All six mage domains are `set_no_dark()`, so **no dark rung is drawn and none may be
  zoned**. Note `i_tod_card_mage_heal_dark.png` IS zoned today and `mage_heal` is
  `set_no_dark` — that is a dead 768x1152 `uncompressed` card, 3.4 MB of load RAM, and
  it should come out of the zone in the same build.
- Plates: `PAUSE_PLATE_MAX` is a CONTIGUOUS `<=` ceiling, currently 52. r53/r54/r55 land
  together or not at all. r48 (AIR) and r51 (ATTUNEMENT) are now dead plates inside that
  range; r48 was never zoned, r51 still is.
- `i_tod_hud_mage_panel` / `i_tod_hud_mana_fill` / `i_tod_hud_mana_arch`: new names, so
  GDT block + zone line + the `AetheriumLoadout.lua` wiring in the SAME build — GATE A
  is comment-stripped and flag-blind, and `RegisterImage` on an unzoned name draws a
  WHITE SQUARE rather than failing.
- The staff icons keep their existing names (`i_tod_hud_gun_staff1/2/3`), so they replace
  in place with no wiring at all.
- FULL build for every one of these. Proof is a fresh content-hash `.iwi` beside an
  untouched control.

<!-- PACK:BEGIN -->

# TOWER OF DOOM — the MAGE class: cards, HUD and staff icons

**26 PNG files.**

This is a fifth playable class being finished in a neon cyber-city zombies map that
already ships four. Every file here sits beside art that is already in the game, usually
in the same frame at the same moment. **Consistency with the reference images is the
whole job.** A piece that is beautiful but off-style is a failure.

Six of the 26 are **re-bakes of files you already have** — same artwork, one line of text
changed. Read section 3 before touching those.

---

## 0. Who the MAGE is — the 60-second brief

A fragile spellcaster who moves slower than everyone else and takes more damage than
everyone else. In exchange they carry **three elemental staffs** and swap between them:

| Staff | Element | Colour | Good against | Feel |
|---|---|---|---|---|
| 1 | **LIGHTNING** | electric blue / white | ordinary zombies, big crowds | fast, automatic, chattering |
| 2 | **FIRE** | orange / red | robots and armoured enemies | slow, heavy, charged shot |
| 3 | **ICE** | pale cyan / white | hounds and flying furies | mid-paced, freezes what it hits |

Every staff is weak against the map's heavy boss. The mage's counterweights are a
**healing aura** that protects the whole team, a **short-range teleport**, and a
**transformation** fuelled by a mana bar.

Their colour, where a piece is not element-specific, is a bright mint green **`#59FFCC`**.

---

## 1. Deliverables

### 1a. Three NEW upgrade cards — 768 × 1152 PNG, three rarities each (9 files)

| Upgrade | Regular | Super | Ultimate |
|---|---|---|---|
| CHAIN LIGHTNING | `i_tod_card_mage_bolt_regular.png` | `i_tod_card_mage_bolt_super.png` | `i_tod_card_mage_bolt_ultimate.png` |
| ARCHMAGE | `i_tod_card_mage_arch_regular.png` | `i_tod_card_mage_arch_super.png` | `i_tod_card_mage_arch_ultimate.png` |
| BLINK | `i_tod_card_mage_blink_regular.png` | `i_tod_card_mage_blink_super.png` | `i_tod_card_mage_blink_ultimate.png` |

**There is no DARK rarity for any mage card. Do not draw one.** Every mage upgrade is
excluded from the dark deck in code, so a fourth file could never be shown and would cost
memory for nothing.

### 1b. Two RE-BAKED cards — 768 × 1152 PNG (6 files)

Same filenames as the sources in `reference/`; these replace the shipped files in place.

| Upgrade | Files |
|---|---|
| FIRE BLAST | `i_tod_card_mage_fire_regular.png` / `_super.png` / `_ultimate.png` |
| ICE SHATTER | `i_tod_card_mage_ice_regular.png` / `_super.png` / `_ultimate.png` |

### 1c. Three pause-menu plates — 300 × 44 PNG (3 files)

| File | Word on it |
|---|---|
| `i_tod_pause_r53.png` | `CHAIN LIGHTNING` |
| `i_tod_pause_r54.png` | `ARCHMAGE` |
| `i_tod_pause_r55.png` | `BLINK` |

### 1d. The MANA BAR — 3 files

| File | Size | Draws at |
|---|---|---|
| `i_tod_hud_mage_panel.png` | 1024 × 296 | 384 × 111 |
| `i_tod_hud_mana_fill.png` | 576 × 96 | 216 × 36 |
| `i_tod_hud_mana_arch.png` | 576 × 96 | 216 × 36 |

### 1e. Two ability icons — 128 × 128 PNG (2 files)

| File | What it is |
|---|---|
| `i_tod_hud_off_heal.png` | HEALING AURA, in the grenade slot |
| `i_tod_hud_off_blink.png` | BLINK, in the tactical slot |

### 1f. Three staff HUD icons — 288 × 132 PNG (3 files)

Same filenames as the shipped ones in `reference/`; they replace in place.

| File | Which staff |
|---|---|
| `i_tod_hud_gun_staff1.png` | LIGHTNING |
| `i_tod_hud_gun_staff2.png` | FIRE |
| `i_tod_hud_gun_staff3.png` | ICE |

Exact filenames, exact pixel sizes, PNG with alpha. No other files. **26 total.**

---

## 2. The reference folder — open it first

`reference/` holds every file named above that already ships. `preview_onscreen_*/`
holds the same files downscaled to the size a player actually sees. **That is the real
test.** A detail that vanishes in the preview folder does not exist.

The four preview sizes and what each is for:

- `preview_onscreen_234x351/` — upgrade cards. Cards are drawn at under a third of the
  width you are painting at.
- `preview_onscreen_384x111/` — the weapon panel, at its true screen size.
- `preview_onscreen_144x66/` — the staff HUD icons.
- `preview_onscreen_24x24/` — the two ability icons. This is the hardest legibility test
  in the whole set: those icons are **24 pixels square** in play.

---

## 3. THE RE-BAKES — read this before drawing anything in 1b

**These are not new cards.** Six shipped cards need **one line of text** replaced and
**nothing else**. Reproduce each source in `reference/` exactly — same title plate, same
illustration, same colours, same frame, same side rails, same corner screws, same star
medal, same rarity ribbon, same dot row, same margins, same transparent background — and
change only the wording in the dark description panel at the bottom.

### FIRE BLAST — three files

The description panel currently reads, over two lines:

```
BURNS PANZERS
AND ROBOTS
```

It must read:

```
BURNS ROBOTS
AND ARMOR
```

*Why: fire is not the answer to the map's heavy boss — it is the answer to the robot
enemy and to armoured zombies. The shipped line tells the player the opposite.*

### ICE SHATTER — three files

The description panel currently reads, over three lines:

```
SHATTERS
HOUNDS, FURY,
AND ARMORED
```

It must read, over two lines:

```
SHATTERS HOUNDS
AND FURIES
```

*Why: armour is fire's job. Ice answers the hounds and the flying furies.*

Keep each card's own description colour — whatever that card uses today. Do not carry one
rarity's colour onto another. Keep the rarity ribbons (`REGULAR +1`, `SUPER +2`,
`ULTIMATE +3`) exactly as they are; those mark the card, not the upgrade.

---

## 4. Card anatomy — for the three NEW cards

Open `reference/i_tod_card_mage_fire_regular.png` and copy this frame exactly:

1. **Outer chassis** — a rounded rectangle, thick outer border, a small screw head in each
   of the four corners, sitting on transparency.
2. **Title band** — a full-width rounded gold/amber plate near the top with a row of seven
   small dots along its upper edge. The upgrade name in heavy condensed uppercase, white
   with a thick dark outline.
3. **Art window** — a large inset rounded rectangle. Deep navy gradient, faint horizontal
   scanlines, scattered small squares and four-point sparkles. The subject sits centred,
   large, and reads instantly as a silhouette.
4. **Rarity medallion** — a circular badge with a five-point star, overlapping the
   bottom-right corner of the art window.
5. **Rarity plate** — a rounded capsule below the art window with small chevrons at each
   end.
6. **Description panel** — a recessed panel at the bottom holding an outlined box with one
   short line of chunky uppercase text (wrap to two lines if it does not fit).
7. **Dot row** — five small circles along the very bottom edge.
8. **Side rails** — two thin vertical light bars, one on each inner edge of the chassis.

### 4a. THE RULE THAT MATTERS MOST

**Draw the central artwork ONCE per upgrade and reuse it, pixel-identical, in all three
rarities.** Put the three shipped FIRE BLAST cards side by side: the fireball illustration
is the same image in every one. Only the frame dressing changes. Do not redraw, re-pose,
re-light or "improve" the artwork for a higher rarity.

### 4b. The three rarity treatments

Read the exact values off the three FIRE BLAST references — they are the ladder.

| | REGULAR | SUPER | ULTIMATE |
|---|---|---|---|
| Chassis | navy / indigo | see reference | black with a warm **gold** border and a soft outer glow |
| Title band | gold / amber | gold / amber | gold / amber |
| Rarity plate | silver, `REGULAR +1` | see reference, `SUPER +2` | orange-gold, `ULTIMATE +3` |
| Medallion | silver ring, silver star | see reference | gold ring, gold star |
| Description text | light grey in a teal-outlined box | see reference | **gold** in a gold-outlined box |
| Dots lit | 1 of 5 | 2 of 5 | 3 of 5, gold |
| Side rails | cyan | see reference | gold |
| Extra decoration | none | none | small gold chevrons and sparkles inside the art window and scattered in the outer margin |

---

## 5. The three new subjects

Each is ONE central object, drawn the way the fireball and the ice star are drawn: bold
flat vector-cartoon rendering, strong dark outlines, bright rim light, no photography, no
3D render, no painterly texture.

### 5.1 CHAIN LIGHTNING — electric blue / white

*What it does in game: the lightning bolt jumps from the zombie it hits to nearby zombies.*

Draw **one thick jagged bolt that forks into three branches**, each branch ending in a
small round burst of sparks. The forks should fan outward and downward so the shape reads
as *spreading*, not as a single strike. A faint ring of arcing filaments behind it.

Palette: deep electric blue through cyan to a white-hot core, with pale violet edge
sparks.

Description line: **`ARCS TO MORE ZOMBIES`**

### 5.2 ARCHMAGE — gold / white

*What it does in game: at a full mana bar the mage transforms — everything hits harder for
a short time. This upgrade makes the transformation stronger and longer.*

Draw **a blazing arcane crown**: a circlet of upright rune-carved gold points with a
white-hot core burning at its centre, wreathed in a corona of gold energy and rising
motes. It should read as *ascension* — the most powerful-looking card in the mage set,
because it is.

Palette: deep amber through gold to a white core; keep the darks dark so the glow carries.

Description line: **`ARCHMAGE HITS HARDER, FASTER AND LONGER`**
⚠️ CHANGED 2026-09-08: ARCHMAGE now also raises MOVE SPEED while the form runs
(user: "Archmage upgrade use will now enhance speed"). The shipped card still
bakes the old `ARCHMAGE HITS HARDER AND LASTS LONGER`, which is incomplete
rather than wrong. A RE-BAKE OF THE THREE ARCHMAGE CARDS IS OWED.

### 5.3 BLINK — violet / white

*What it does in game: the mage teleports a short distance forward, instantly.*

Draw **a horizontal teleport streak**: a bright violet-white comet of arcane light running
left to right, with a solid glowing rune-sigil at the leading end and a dissolving cloud
of motes and after-image fragments trailing behind it. Directional and unmistakable —
*was there, is here*.

Palette: deep violet through magenta to white, with cool blue-white sparks.

Description line: **`BLINK FURTHER AND MORE OFTEN`**

---

## 6. The pause plates (1c)

Three small name plates for a list in the pause menu. Match `reference/i_tod_pause_r52.png`
**exactly**: the same dark navy capsule, the same bright cyan tab at the left end, the same
heavy condensed white type with its dark outline, the same padding. Only the word changes.

`reference/i_tod_pause_r49.png` shows a two-word name set at this size — use it to judge
the fit for `CHAIN LIGHTNING`, which is the longest of the three. If it does not fit at the
reference's type size, condense the type slightly rather than shrinking the cap height or
moving the tab.

Text, exactly: `CHAIN LIGHTNING`, `ARCHMAGE`, `BLINK`.

---

## 7. The MANA BAR (1d) — the most technical piece here

The mage has no ammunition. Where every other class sees a bullet count in the corner of
the screen, the mage sees a **mana bar** that fills up as they play and empties when they
transform.

### 7.1 `i_tod_hud_mage_panel.png` — 1024 × 296

**This is `reference/i_tod_hud_weapon_panel.png` with one region replaced.** Open that
file. It is the corner plate that holds the weapon readout: a dark navy body with a bright
cyan keyline, a thin horizontal rule near the top under the weapon name, a bright cyan
double-outlined box on the left (the weapon icon sits in it), a thick cyan rule along the
bottom edge, and a corner mark at each end.

**Keep every one of those, pixel-identical.** The two panels are shown to different players
in the same match and must be recognisably the same object.

Change exactly two things in the right-hand two thirds:

1. **Delete the short vertical cyan divider** that currently stands at roughly x = 760.
2. **Add a recessed MANA TROUGH** occupying **x = 416 → 1008, y = 152 → 264**
   (592 × 112 pixels in this file). Draw it as an empty well: 4-pixel rounded corners, a
   near-black interior a touch darker than the panel body, a 3-pixel mint-green `#59FFCC`
   keyline around it, and a soft inner shadow along its top edge so it reads as *sunk into*
   the plate rather than drawn on it.

Nothing else moves. The trough must be **empty** — the fill is a separate file that is
drawn on top of it in game.

### 7.2 `i_tod_hud_mana_fill.png` — 576 × 96

The mint fill that sits inside the trough. It is drawn edge to edge over
**x = 424 → 1000, y = 160 → 256** of the panel, so this file is the trough's interior with
an 8-pixel inset all round.

**It is revealed left to right as the bar fills, and it is cut off at an arbitrary vertical
line — any line.** So it must look correct at every width from a sliver to full.

- A horizontal energy bar in mint green `#59FFCC` with a cooler cyan at the bottom edge and
  a brighter, near-white highlight running along the upper third.
- A **uniform** treatment along its length. No left-to-right gradient in brightness, no
  single hotspot, no end cap, no arrow, no tapering — anything that only works at one width
  will look broken at every other width.
- A light regular texture along the bar is welcome — fine vertical energy striations, or a
  soft repeating scanline — as long as it is even end to end.
- Full-bleed: opaque edge to edge, no transparent margin, no rounded corners of its own
  (the trough supplies those).

### 7.3 `i_tod_hud_mana_arch.png` — 576 × 96

**The same bar in gold.** When the mage transforms, the mint fill is swapped for this one
and it drains back down over the next few seconds, so it is cut the same way and carries
the same rules: uniform along its length, full-bleed, no end caps.

Deep amber at the bottom edge through gold to a white-hot highlight along the upper third,
noticeably brighter overall than the mint bar — this is the "you are powerful right now"
state and it should be obvious in peripheral vision. Keep the same striation or scanline
treatment so the two read as the same bar in two states.

**Put the mint and gold bars side by side before delivering.** Same height of highlight,
same texture, same edges — only the hue and the brightness differ.

---

## 8. The two ability icons (1e) — 128 × 128 each

These sit in the two small ability tiles at the bottom right of the screen.
`reference/i_tod_hud_offhand_tile.png` is that tile — it is **not** a deliverable, it is
there so you can see the box these icons drop into and the dark plate they must stay
readable against. Open `reference/i_tod_hud_off_frag.png` (a grenade) and
`reference/i_tod_hud_off_monkey.png`. That is the style, exactly:

- A single object, centred, filling most of the frame with a little padding.
- **Very heavy dark navy outline** — thicker than looks right at full size. It is what
  keeps the icon alive when it shrinks.
- A pale near-white body with one cool blue-grey shade for the shadow side, and at most one
  accent colour.
- Flat cartoon rendering. No gradients beyond the single shade, no glow, no small parts.
- Transparent background.

**Check `preview_onscreen_24x24/` before you finish either one.** Twenty-four pixels is the
whole icon. If the shape is not readable there it is wrong, however good it looks large.

### 8.1 `i_tod_hud_off_heal.png` — HEALING AURA

A **wide, low ring of light on the ground with a bold cross rising from its centre**. The
ring is a flat ellipse — it must read as an *area*, not a beam, because that is exactly
what the ability does: it protects everyone standing in it. Accent colour: soft green.

Keep it to two shapes — ellipse and cross. Nothing else survives 24 pixels.

### 8.2 `i_tod_hud_off_blink.png` — BLINK

A **bold chevron or arrowhead pointing right, with two or three short streak lines trailing
behind it** and a small ghosted duplicate of the chevron at the tail. It must read as
*sudden movement forward*. Accent colour: violet.

Do not draw a figure, a portal or a rune ring — none of them survive 24 pixels. The
arrowhead does.

---

## 9. The three staff HUD icons (1f) — 288 × 132 each

> ⚠️ **SUPERSEDED BY docs/124 (v18.58, 2026-09-09).** These three shipped from
> this pack and were **re-baked the next day**. The head SUBJECTS below are
> still correct and were kept; the *treatment* asked for here was not. Asking
> for them in a pass of 25 upgrade CARDS is what went wrong: the accent colours
> this section grants ("electric blue", "orange-red", "pale cyan") do not exist
> anywhere in the 28-icon weapon set they sit beside, and the cells came back
> with 5 tones instead of 3 and half the set's ink coverage. **A HUD icon is
> briefed against the HUD set it joins, never against the cards for the same
> feature.** docs/124 carries the measured version.

The icon in the corner showing which weapon the player is holding, drawn at 144 × 66.
Match `reference/i_tod_hud_gun_katana.png` and `reference/i_tod_hud_gun_axe.png`: a clean
side-on **silhouette-forward** treatment on transparency — a pale metal body, a heavy dark
outline, minimal internal detail, no scene, no background, no glow spill.

The cell is landscape (2.18 : 1) and a staff is long and thin, so **lay each staff
diagonally** and fill the cell the way the axe reference does.

The three shipped files in `reference/` show the correct *treatment* — copy the line
weight, the metal shading and the diagonal placement. **Their subject is wrong** and is
what you are replacing: they show one plain staff at three polish levels, and the mage now
carries three different elemental staffs.

**Shared between all three:** the same long dark shaft, the same simple wrapped grip, the
same proportions and the same diagonal angle. They are a matched set of weapons, not three
unrelated props.

**Different between all three:** the head, and only the head. That is where the element
lives, and it is the only thing a player can use to tell them apart at 144 × 66 — so push
the head **silhouettes** apart, not their surface detail.

| File | Head |
|---|---|
| `i_tod_hud_gun_staff1.png` | **LIGHTNING** — two upswept prongs like antlers, a jagged bolt shape arcing between their tips. Electric blue accent. |
| `i_tod_hud_gun_staff2.png` | **FIRE** — a pair of heavy inward-curling horns cradling a round molten stone. Orange-red accent. |
| `i_tod_hud_gun_staff3.png` | **ICE** — a fan of sharp angular crystal shards spreading from a collar, like a frozen arrowhead. Pale cyan accent. |

Keep the accent colour to the head and a hint on the grip binding. The shaft stays pale
metal like every other weapon icon, so the three sit correctly beside the other 25 icons in
the set.

**Put all three side by side at 144 × 66 before delivering.** Antlers / horns / shards must
be three obviously different silhouettes at that size.

---

## 10. Hard rules

1. **Exact filenames, exact pixel sizes** from section 1.
2. **PNG with alpha.** No JPEG, nothing flattened onto white.
3. **NO NUMBERS on any card** — not a percentage, not a level, not a damage figure —
   anywhere except the rarity plate's own `+1` / `+2` / `+3`. The game shows the values
   live elsewhere; baking one here is what makes a card go stale. This rule is broken often
   enough that it is worth checking your output against it before delivering.
4. **One artwork per upgrade, dressed three ways.**
5. **No DARK rarity for anything in this request.**
6. **The six re-bakes change one line of text and nothing else** (section 3).
7. **The three staff icons share one shaft and differ only in the head** (section 9).
8. **Both mana fills must survive being cut at any vertical line** (section 7).
9. **Check `preview_onscreen_*/`.** If it does not read there, it does not work.
10. No watermark, no signature, no border of your own outside the chassis.

---

## 11. Paste-ready prompts

Attach the named files from `reference/` with each prompt.

**A — CHAIN LIGHTNING, regular.** *Attach `i_tod_card_mage_fire_regular.png`,
`i_tod_card_mage_ice_regular.png`.*
> Match the attached game upgrade card's frame exactly — same chassis, title band, art
> window, star medallion, rarity plate, description panel, five-dot row, side rails, corner
> screws, margins and transparent background — for a new upgrade called CHAIN LIGHTNING.
> Title band text: `CHAIN LIGHTNING`. Description panel text: `ARCS TO MORE ZOMBIES`.
> Rarity plate: `REGULAR +1`, silver, with one of five dots lit. Central illustration: one
> thick jagged lightning bolt forking into three branches, each branch ending in a small
> round spark burst, fanning outward and downward, with a faint ring of arcing filaments
> behind. Deep electric blue through cyan to a white-hot core, pale violet edge sparks.
> Bold flat vector-cartoon rendering with heavy dark outlines, matching the attached cards.
> No numbers anywhere except the rarity plate. 768x1152 PNG, transparent background.

**B — CHAIN LIGHTNING, super and ultimate.** *Attach your finished regular card plus
`i_tod_card_mage_fire_super.png` and `i_tod_card_mage_fire_ultimate.png`.*
> Take the first attached card and re-dress it at the two higher rarities shown in the
> other two attachments. **The central lightning illustration must stay pixel-identical in
> all three** — copy only the frame dressing: chassis colour, rarity plate text and colour
> (`SUPER +2`, `ULTIMATE +3`), medallion, description text colour, dots lit (2 of 5, then
> 3 of 5), side-rail colour, and the ultimate's gold border, warm outer glow and scattered
> chevrons and sparkles. 768x1152 PNG each.

**C — ARCHMAGE.** *Attach the three `i_tod_card_mage_fire_*` files and
`i_tod_card_mage_heal_regular.png`.*
> Make one upgrade card in three rarities matching the attached frames exactly. Title
> `ARCHMAGE`, description `ARCHMAGE HITS HARDER, FASTER AND LONGER`. Central illustration,
> identical in all three: a blazing arcane crown — a circlet of upright rune-carved gold
> points with a white-hot core burning at its centre, wreathed in a corona of gold energy
> and rising motes. Deep amber through gold to white, darks kept dark so the glow carries.
> This should be the most powerful-looking card in the set. Dress the three at
> `REGULAR +1` / `SUPER +2` / `ULTIMATE +3` exactly as the attachments do, with 1, 2 and 3
> of five dots lit. No numbers anywhere except the rarity plate. 768x1152 PNG each.

**D — BLINK.** *Attach the three `i_tod_card_mage_fire_*` files.*
> Make one upgrade card in three rarities matching the attached frames exactly. Title
> `BLINK`, description `BLINK FURTHER AND MORE OFTEN`. Central illustration, identical in
> all three: a horizontal teleport streak — a bright violet-white comet of arcane light
> running left to right, a solid glowing rune-sigil at the leading end, a dissolving cloud
> of motes and after-image fragments trailing behind. Deep violet through magenta to white
> with cool blue-white sparks. Directional and unmistakable. Dress the three at
> `REGULAR +1` / `SUPER +2` / `ULTIMATE +3` with 1, 2 and 3 of five dots lit. No numbers
> anywhere except the rarity plate. 768x1152 PNG each.

**E — the FIRE BLAST re-bake.** *Attach `i_tod_card_mage_fire_regular.png`,
`i_tod_card_mage_fire_super.png`, `i_tod_card_mage_fire_ultimate.png`.*
> Reproduce each attached card exactly at 768x1152 with a transparent background, changing
> ONE thing: in the dark description panel near the bottom, replace the two lines
> `BURNS PANZERS` / `AND ROBOTS` with `BURNS ROBOTS` / `AND ARMOR`. Same two-line
> arrangement, same centring, same type size, and keep each card's own text colour.
> Everything else must be identical to its source: the FIRE BLAST title plate, the fireball
> illustration, the background panel and scanlines, the floating sparks, the rarity ribbon,
> the star medal, the side rails, the corner screws, the dot row, the outer glow, the
> margins. Deliver three files under the same names as the sources.

**F — the ICE SHATTER re-bake.** *Attach `i_tod_card_mage_ice_regular.png`,
`i_tod_card_mage_ice_super.png`, `i_tod_card_mage_ice_ultimate.png`.*
> Reproduce each attached card exactly at 768x1152 with a transparent background, changing
> ONE thing: in the dark description panel near the bottom, replace the three lines
> `SHATTERS` / `HOUNDS, FURY,` / `AND ARMORED` with two lines reading `SHATTERS HOUNDS` /
> `AND FURIES`. Centre the two lines in the same panel and keep each card's own text
> colour; the type may grow slightly now that there are two lines instead of three, as long
> as it matches the size used on the other cards in the set. Everything else must be
> identical to its source: the ICE SHATTER title plate, the ice-star illustration, the
> background panel, the snowflakes and shards, the rarity ribbon, the star medal, the side
> rails, the corner screws, the dot row, the margins. Deliver three files under the same
> names as the sources.

**G — the pause plates.** *Attach `i_tod_pause_r52.png`, `i_tod_pause_r49.png`.*
> Match the attached name plates exactly — same dark navy capsule shape, same bright cyan
> tab at the left end, same heavy condensed white type with its dark outline, same padding
> and same margins. Make three, reading `CHAIN LIGHTNING`, `ARCHMAGE` and `BLINK`. If
> `CHAIN LIGHTNING` does not fit at the reference type size, condense the letterforms
> slightly rather than reducing the cap height or moving the tab. 300x44 PNG each,
> transparent background.

**H — the mage weapon panel.** *Attach `i_tod_hud_weapon_panel.png`,
`i_tod_hud_health_frame.png`.*
> Reproduce the first attached HUD panel exactly at 1024x296 with a transparent background
> — the dark navy body, the bright cyan keyline, the thin horizontal rule near the top, the
> bright cyan double-outlined box on the left, the thick cyan rule along the bottom edge and
> the corner marks all stay pixel-identical — and change only the right-hand two thirds:
> (1) delete the short vertical cyan divider standing at roughly x=760;
> (2) add an empty recessed bar trough occupying x=416 to x=1008, y=152 to y=264, with
> 4-pixel rounded corners, a near-black interior slightly darker than the panel body, a
> 3-pixel mint green #59FFCC keyline, and a soft inner shadow along its top edge so it reads
> as sunk into the plate. The second attachment shows how a recessed bar trough is drawn
> elsewhere in this interface — match that language. The trough must be EMPTY; its fill is a
> separate image drawn over it.

**I — the two mana fills.** *Attach `i_tod_hud_health_fill.png` and your finished
`i_tod_hud_mage_panel.png`.*
> Make two horizontal bar fills, 576x96 PNG each, opaque edge to edge with no transparent
> margin and no rounded corners. They are revealed left to right and can be cut off at any
> vertical line, so each must look correct at every width — completely UNIFORM along its
> length, with no gradient in brightness, no hotspot, no end cap, no arrow and no taper.
> (1) `i_tod_hud_mana_fill.png`: mint green #59FFCC, cooler cyan along the bottom edge, a
> brighter near-white highlight running along the upper third, and a fine even vertical
> striation across the whole length.
> (2) `i_tod_hud_mana_arch.png`: the same bar in gold — deep amber at the bottom edge
> through gold to a white-hot upper highlight, noticeably brighter overall, same highlight
> height and same striation so the two read as one bar in two states.

**J — the two ability icons.** *Attach `i_tod_hud_off_frag.png`, `i_tod_hud_off_monkey.png`
and `i_tod_hud_offhand_tile.png` (the tile they sit in — not a deliverable, it shows the box
and the dark plate they must read against).*
> Match the first two attached icons exactly — single centred object, very heavy dark navy outline,
> pale near-white body with one cool blue-grey shadow shade, one accent colour, flat cartoon
> rendering with no gradients or glow, transparent background. Make two, 128x128 PNG each,
> both readable at 24x24 pixels:
> (1) `i_tod_hud_off_heal.png`: a wide low ellipse of light lying on the ground with a bold
> cross rising from its centre — an area, not a beam. Soft green accent. Two shapes only.
> (2) `i_tod_hud_off_blink.png`: a bold chevron pointing right with two or three short
> streak lines trailing behind it and a small ghosted duplicate of the chevron at the tail —
> sudden movement forward. Violet accent. No figure, no portal, no rune ring.

**K — the three staff icons.** *Attach `i_tod_hud_gun_katana.png`, `i_tod_hud_gun_axe.png`,
`i_tod_hud_gun_staff1.png`.*
> Match the attached weapon icons' treatment — a clean side-on silhouette-forward drawing on
> transparency, pale metal body, heavy dark outline, minimal internal detail, no background
> and no glow — and make three staff icons, 288x132 PNG each, each staff laid diagonally to
> fill the landscape cell the way the axe does. All three share one identical long dark
> shaft, one identical wrapped grip, the same proportions and the same diagonal angle; only
> the head differs:
> (1) LIGHTNING — two upswept prongs like antlers with a jagged bolt arcing between their
> tips, electric blue accent;
> (2) FIRE — a pair of heavy inward-curling horns cradling a round molten stone, orange-red
> accent;
> (3) ICE — a fan of sharp angular crystal shards spreading from a collar like a frozen
> arrowhead, pale cyan accent.
> Keep the accent colour to the head and a hint on the grip binding; the shaft stays pale
> metal. The three silhouettes must be obviously different at 144x66. The third attachment
> is the current version being replaced — copy its line weight and placement, not its
> subject.

---

## 12. Delivery checklist

- [ ] 26 PNG files, exact names and sizes from section 1
- [ ] Every file RGBA with a genuinely transparent background where the reference has one
- [ ] No number, percentage or level count anywhere on any card except the rarity plate
- [ ] No DARK card delivered for anything
- [ ] Each new upgrade's central artwork identical across its three rarities
- [ ] The six re-bakes differ from their sources **only** in the description panel
- [ ] `CHAIN LIGHTNING` fits its plate without moving the cyan tab
- [ ] The mage panel differs from the shipped panel only in the right-hand two thirds
- [ ] Both mana fills look correct when covered from the right at 10%, 50% and 90%
- [ ] Both ability icons readable in `preview_onscreen_24x24/`
- [ ] The three staff heads clearly different in `preview_onscreen_144x66/`
- [ ] All baked text proofread letter by letter
- [ ] Every piece checked against `preview_onscreen_*/`

## 13. Do NOT

- Do not draw a dark/red rarity of anything.
- Do not bake numbers, levels or percentages onto a card.
- Do not redraw the illustration between rarities.
- Do not change anything on the six re-bakes except the description panel.
- Do not restyle the weapon panel, move its keylines, or resize its canvas.
- Do not give either mana fill an end cap, a taper or a brightness gradient along its
  length.
- Do not put fine detail in the 128x128 ability icons.
- Do not give the three staffs three different shafts.
- Do not add a watermark, signature, logo or border of your own.
- Do not rename any file.
<!-- PACK:END -->
