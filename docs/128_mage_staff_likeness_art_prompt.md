<!-- art-pack
name: mage_staff_likeness
refs:
  docs/128_staff_ref/icon_vs_head_lightning.png | THE WHOLE BRIEF IN ONE PICTURE, part 1. The real lightning staff head from a first-person screenshot, beside the icon that is supposed to depict it, at native size on the HUD's own near-black. Read this before drawing anything.
  docs/128_staff_ref/icon_vs_head_fire.png | The same comparison for fire.
  docs/128_staff_ref/icon_vs_head_ice.png | The same comparison for ice. The worst of the three - the real head is a large mechanical assembly and the icon is a stick with a spike.
  docs/128_staff_ref/ingame_lightning_staff.png | FULL first-person screenshot, lightning staff held. The ground truth for the shape. Ignore the red and magenta cast - that is the room's lighting, not the staff.
  docs/128_staff_ref/ingame_fire_staff.png | FULL first-person screenshot, fire staff held.
  docs/128_staff_ref/ingame_ice_staff.png | FULL first-person screenshot, ice staff held.
  docs/128_staff_ref/head_lightning.png | Lightning head, cropped and doubled, no icon beside it. Use when you need the silhouette large.
  docs/128_staff_ref/head_fire.png | Fire head, cropped and doubled.
  docs/128_staff_ref/head_ice.png | Ice head, cropped and doubled.
  i_tod_hud_gun_staff1.png | DELIVERABLE 1, current version. The treatment is CORRECT and must be kept exactly; only the drawn object changes.
  i_tod_hud_gun_staff2.png | DELIVERABLE 2, current version.
  i_tod_hud_gun_staff3.png | DELIVERABLE 3, current version.
  i_tod_hud_gun_katana.png | The house style, nearest neighbour: one long object laid diagonally across the cell. This is the stroke weight and flatness to match.
  i_tod_hud_gun_axe.png | The house style, ornate. Shows how much internal detail survives at this size.
  i_tod_hud_gun_blade.png | The house style, third melee cell.
  i_tod_card_class_mage.png | DELIVERABLE 4, current version. Keep the whole chassis; replace the staff inside the art window.
  i_tod_card_tier_mage_2.png | DELIVERABLE 5, current version.
  i_tod_card_tier_mage_3.png | DELIVERABLE 6, current version.
  i_tod_card_class_slasher.png | The class-card chassis on another class, for breadth. Note the central art is the weapon itself.
  i_tod_card_tier_slasher_2.png | The tier-card chassis on another class - the UNPACKED banner and the pips.
preview: 144x66 186x279 234x351
-->

# 128 — MAGE STAFFS: make the six drawn assets look like the staffs actually held

> **STATUS: ALL SIX DELIVERED AND INSTALLED 2026-09-10.** GROUP B (the three
> cards) arrived 20:54 and GROUP A (the three HUD icons) at 21:01, in two
> drops. Every one was checked against the shipped file it replaces before
> installing, and all six went into `source_data/tod_ui_images/_images/` over
> their existing names, so there was no wiring to do. FULL build started
> 21:05 — native check pending; nobody has seen these in game.
>
> All six previously shipped images are parked at
> `docs/128_staff_ref/_prev_shipped_20260910/` — these images are NOT git
> tracked, so that folder is the only copy of the old art. The two delivery
> proof boards are kept beside them as
> `delivered_before_after_cards_20260910.png` and
> `delivered_before_after_icons_20260910.png`.

### GROUP B acceptance record (2026-09-10 20:54 drop)

Changed-pixel diff of each delivered card against the file it replaced
(per-channel tolerance 8, to absorb a compressor round trip):

| card | changed | bounding box | verdict |
|---|---|---|---|
| `i_tod_card_class_mage` | 6.86% | x 174..639, y 230..497 + 501..584, **plus y 845..976** | art window clean; the name plate ALSO changed |
| `i_tod_card_tier_mage_2` | 4.85% | x 128..639, y 230..436 + 480..529 | art window only — chassis untouched |
| `i_tod_card_tier_mage_3` | 6.52% | x 128..639, y 230..436 + 480..529 | art window only — chassis untouched |

Two of three obey the brief exactly. The class card carries one change the
brief did not ask for: `LIGHTNING STAFF` was re-set larger and wrapped to two
lines in its name plate (y 845..976). ACCEPTED — at the card's real on-screen
186x279 the old single line was the smallest text on the card, and the two-line
setting is legible where it was not. It is art-only; no wiring or slug reads it.

Likeness, judged against the three committed screenshots: all three heads now
centre on a metal assembly around a glass chamber, which is the real staffs'
shared signature. Lightning is a brass C-ring enclosing a lit chamber (was a
blue trident fork); fire is a broad banded head with oval bosses under a flame
plume (was a plain orange ring); ice is an arch bracket holding a horizontal
glass cylinder over flat gold cross plates (was a bare spiky crystal). The
subject gap this doc exists to close is closed on the cards.

### GROUP A acceptance record (2026-09-10 21:01 drop)

The icons' hard constraint was that the TREATMENT must not regress, since
docs/124 had already fixed it. Re-measured with the `stat()` body from
`tools/gen_staffhud_ref.js` verbatim, so these numbers are comparable to the
table above rather than a fresh definition:

| | staff1 | staff2 | staff3 | the 26 gun cells |
|---|---|---|---|---|
| tones ≥2% of ink | 3 (was 3) | 3 (was 3) | 3 (was 3) | 3.0 mean |
| bright saturated px | 0.32% (was 0.64) | 0.41% (was 0.60) | 0.35% (was 0.55) | 0.16% mean |
| ink coverage | 32.8% (was 32.3) | 32.6% (was 33.6) | 33.0% (was 29.8) | 35.4% mean |
| palette | `#0A1020` `#E8EEF6` `#62779C` | same | same | the same three |

No row regressed and two improved: the saturated share halved toward the gun
mean, and ice's ink coverage rose off 29.8% — it was the thinnest cell in the
set and is now in band with the other two.

**The delivered PNGs are ~2.6x the file size of the ones they replace (≈17.5 KB
against ≈6.5 KB) and that is NOT a style regression.** Distinct exact RGB
values rose 180 → 310 per cell, but every added value is under 0.4% of the
cell's ink: it is anti-aliasing fringe on a more intricate head outline, which
is why the 4-bit tone bucket still reports exactly three. The shipped cells
already carried 180 such values for the same reason. Changed pixels are
confined to the head in all three; the shaft, its banding and the outline are
untouched.

## Why (user, 2026-09-10)

> *"Okay we have gun HUD icons in bottom right of screen and class cards that
> include the staffs for the mage. Both the cards and icons depict staffs that
> don't really resemble the actually used staffs. Can you generate a zip so we
> can get better depicted assets for our mage class. Specifically these 6
> assets. 3 icons and 3 class cards. I've included the images of the actual
> usage of the staffs in game that you may include in the zips. Overall they are
> the bo3 origin staffs so thus should be obtainable online."*

Three screenshots came with it, one per staff, taken 2026-09-10 19:20 and
committed to `docs/128_staff_ref/` as the ground truth.

## This is a SUBJECT gap, not a style gap — and that distinction is the whole brief

`docs/124` re-baked these same three icons on 2026-09-09 and fixed a **style**
problem, with measured acceptance criteria. That work is good and must not
regress. Measured again today off the shipped PNGs:

| | staff1 | staff2 | staff3 | the 26 gun cells |
|---|---|---|---|---|
| tones ≥2% of ink | 3 | 3 | 3 | 3.0 mean |
| bright saturated pixels | 0.64% | 0.60% | 0.55% | 0.16% mean |
| ink coverage | 32.3% | 33.6% | 29.8% | 35.4% mean |
| palette | `#0A1020` `#E8EEF6` `#62779C` | same | same | the same three |

Every number is inside the set's range. **The icons are drawn correctly and
depict the wrong thing.** The head shapes came from the docs/120 card pass —
a fire spiral-shell, an ice crystal cluster, a lightning crescent-and-gem — which
are generic cartoon wizard staffs. The staffs in the game are the ported **BO3
Origins elemental staffs**: long dark timber shafts with brass banding, topped
by large *mechanical* heads of brass tubing, glass cylinders, bracket cages and
flat paddle plates.

So the ask is narrow and unusually well-defined: **keep every measured style
property, replace the drawn object.**

## What the staffs actually are

Shared across all three: a long shaft of dark timber and blackened metal with
brass collars, held near the middle. The head is roughly a third of the length
and is wide, asymmetric and machined — not a gem on a stick.

**All three share a family resemblance**, which is itself part of the problem:
each is a **horizontal glass chamber at the centre, surrounded by large curved or
flat metal assemblies**, on the same banded shaft. The shipped assets draw three
unrelated fantasy shapes instead, so they lose both the likeness *and* the
family.

| Element | In-game name | Canonical Origins name | Head, read off the screenshots |
|---|---|---|---|
| Lightning | LIGHTNING STAFF | Staff of Lightning / **Kimat's Bite** | Four thick ribbed brass tubes curving outward and **curling downward** around a central horizontal glass chamber; violet arcs inside the chamber; a small ornate fitting on top |
| Fire | FIRE STAFF | Staff of Fire / **Kagutsuchi's Blood** | Wide, flat and horizontal: two broad **paddle-shaped wing assemblies** projecting left and right, built from stacked flat plates with oval cutouts and gold banding; burning core at the crux |
| Ice | ICE STAFF | Staff of Ice / **Ull's Arrow** | The largest: twin tall curved brackets forming an arch, a segmented chain-like arc across it, a horizontal glass cylinder in metal rings, flat gold paddle plates projecting sideways, crystalline tip |

Those are the packed names the game itself uses, so they are the right search
terms — the user is correct that reference art is findable under them.

⚠️ Earlier drafts of this table said lightning's horns "sweep outward and up"
and described fire's plates as "gear teeth". Both were wrong against the
screenshots and are corrected above; the lightning tubes curl **down**, and
fire's wings are flat plates with oval holes. The fire screenshot is also the
least usable of the three — it was taken mid-shot, so the head is partly hidden
behind flame FX and motion blur. Lean on published art for fire in particular.

⚠️ **The screenshots are colour-unreliable.** All three were taken inside the
Endless Spire, whose lighting is a saturated red and magenta wash; it tints the
staffs, the hands and the walls alike. Read the screenshots for **shape**, and
take colour from the canonical art: brass and gold, dark timber, steel, with the
element colour confined to the glass and the effect.

## Install (when the drop returns)

Same six names, so there is no wiring to do. Inspect with the pack tool's
`-Inspect`, look at every image, overlay against the shipped file, then copy
into `source_data/tod_ui_images/_images/`. FULL build — these are `.gdt`-fed
images. Proof is a fresh content-hash `.iwi` beside an untouched control.

The three icon cells are keyed on the element stems in `AetheriumLoadout.lua`
(`tod_staff_lightning` → `staff1`, `_fire` → `staff2`, `_ice` → `staff3`); the
three cards are the mage rows of the class and tier card tables. Nothing in
either changes.

After installing the icons, re-run the measurement in the table above and
confirm all four rows still hold. `docs/124_hud_ref/staff_style_gap.png` is the
BEFORE record for that earlier pass and must not be regenerated.

<!-- PACK:BEGIN -->

# MAGE STAFFS — six assets, re-drawn to match the real staffs

Six PNGs, all replacing an existing file. **Same filenames back, same pixel
dimensions, transparent where the current file is transparent.**

There are two groups and they have different rules. Read both.

---

## The problem, in one sentence

The six assets draw generic cartoon wizard staffs — a spiral shell, a crystal
cluster, a crescent with a gem. The staffs in the game are large **mechanical**
staffs: dark timber shafts with brass banding, topped by machined heads of brass
tubing, glass chambers, bracket cages and flat paddle plates.

Open `reference/icon_vs_head_ice.png` first. Left is the real staff head from the
game. Right is the icon that is supposed to depict it, at native size. That gap
is the entire job.

---

## What the three staffs are

All three share one shaft: long, dark timber and blackened metal, brass collars
at intervals, gripped near the middle. The head is about a third of the total
length and is wide, asymmetric and built out of parts.

**They also share a family resemblance, and keeping it matters.** Each head is a
**horizontal glass chamber at the centre, surrounded by large curved or flat
metal assemblies**. The current assets draw three unrelated fantasy shapes, so
they lose both the likeness and the family. The three new ones should look like
three weapons from one workshop.

**LIGHTNING** — *Staff of Lightning*, also called **Kimat's Bite**.
Four thick ribbed brass tubes curving outward from the shaft and **curling
downward** around a central horizontal glass chamber, with a small ornate fitting
on top. Violet-white arcs inside the chamber. The curling ribbed tubes are the
recognisable part.

**FIRE** — *Staff of Fire*, also called **Kagutsuchi's Blood**.
Wide, flat and horizontal. Two broad **paddle-shaped wing assemblies** project
left and right, each built from stacked flat plates with oval cutouts and gold
banding. A burning orange core at the crux with a small ornate fitting above it.

**ICE** — *Staff of Ice*, also called **Ull's Arrow**.
The biggest and busiest. Twin tall curved brackets forming an arch, a segmented
chain-like arc across it, a horizontal glass cylinder held in metal rings, flat
gold paddle plates projecting sideways, and a crystalline tip.

These are well-known weapons and reference art is easy to find under those
names. **Use it.** The screenshots in `reference/` confirm which is which and how
each is proportioned, but published art will be cleaner to read — and the fire
screenshot in particular was taken mid-shot, so its head is partly hidden behind
flame effects and motion blur.

⚠️ **Do not take colour from the screenshots.** All three were shot in a room lit
saturated red and magenta, which tints the staffs, the hands and the walls
equally. Read the screenshots for **shape only**. Colour is brass and gold, dark
timber and steel, with the element colour confined to the glass and the effect.

---

## GROUP A — the three weapon HUD icons

| Deliverable | Size | Subject |
|---|---|---|
| `i_tod_hud_gun_staff1.png` | 288 x 132 | Lightning staff |
| `i_tod_hud_gun_staff2.png` | 288 x 132 | Fire staff |
| `i_tod_hud_gun_staff3.png` | 288 x 132 | Ice staff |

These sit in a strip with 26 other weapon icons in the corner of the screen at
**144 x 66** — half the delivered size. See `preview_onscreen_144x66/` for what
the player actually sees.

### The treatment is already correct. Keep it exactly.

This is the unusual part of this job: the current three icons were re-drawn last
week and their *style* is right. **Do not restyle them. Change only the object
drawn.** These properties are measured and checked on delivery:

- **Three flat colours and no others**: `#E8EEF6` (light), `#62779C` (mid),
  `#0A1020` (dark). No gradients, no glows, no gem colours, no element colour.
  At most one extra intermediate tone, holding under 2% of the pixels.
- **Flat vector look.** Hard edges, no soft shading, no outline glow.
- **Ink coverage 29–36%** of the cell — how much of the 288 x 132 box the drawn
  object fills. Match `reference/i_tod_hud_gun_katana.png` and
  `reference/i_tod_hud_gun_axe.png`.
- **One long object laid diagonally** across the cell, head toward the upper
  right, butt toward the lower left. Same diagonal as the katana and axe cells.
- **Transparent background.** PNG with alpha, 8-bit RGBA.
- **Margins**: keep 10–16 px clear on the left and right, 7–20 top, ~9 bottom.
  Nothing may touch a cell edge.

### What to change

Only the head. Keep the shaft as the existing cells draw it — a banded diagonal
pole. Redraw each head as the real staff's head, simplified to read at 144 x 66:

- **Lightning**: the two outward-sweeping ribbed horns and the chamber between
  them. The horns are the recognisable part — make them read as *ribbed metal
  horns*, not as antlers or a bolt.
- **Fire**: the wide flat stack of toothed discs and the paddle wings. Read as a
  flat mechanical fan, not a shell or a sunburst.
- **Ice**: the tall arch of twin brackets over the cylinder, with the side
  paddles. Read as a machined cage, not a crystal cluster.

At this size, three or four shapes per head is the budget. Choose the silhouette
that makes the three staffs distinguishable from each other at a glance, in a
strip where they sit next to a katana and an axe.

---

## GROUP B — the three class and tier cards

| Deliverable | Size | Title | Weapon name | Art content |
|---|---|---|---|---|
| `i_tod_card_class_mage.png` | 768 x 1152 | class card (no tier banner) | LIGHTNING STAFF | the lightning staff alone |
| `i_tod_card_tier_mage_2.png` | 768 x 1152 | TIER 2 | FIRE STAFF | lightning and fire staffs crossed |
| `i_tod_card_tier_mage_3.png` | 768 x 1152 | TIER 3 | ICE STAFF | all three: lightning and fire crossed, ice down the middle |

Shown to the player at **186 x 279** (class) and **234 x 351** (tier). See the
`preview_onscreen_*` folders — at that size only the silhouette survives, so the
staffs must be distinguishable by outline alone.

### Keep the entire chassis, pixel for pixel where you can

Open `reference/i_tod_card_tier_mage_3.png`. Everything on it stays:

- the rounded frame, the dark navy body, the mint outer glow
- the gold title banner and its rivets, and its text (`TIER 2` / `TIER 3`)
- the art window: dark blue panel, corner brackets, star sparkles
- the dark red **UNPACKED** banner across the foot of the art window
- the mint **MAGE** nameplate pill
- the bottom plate with the weapon name in mint
- the three pips at the foot, filled to the tier
- the corner screws

**The only thing that changes is the staff artwork inside the art window.**

### What to change

Replace the drawn staffs with the real ones, in the card set's existing painted
style — this is *not* the flat three-colour HUD style, it is the illustrated look
the other class cards use, with the dark timber shafts and gold banding the
current mage cards already have. Keep that. The shafts are close to right
already; it is the heads that are wrong.

Keep the existing composition and crossing angles so the three cards still read
as a ladder when seen side by side. Keep each staff's element colour in the
glass and the effect only — violet-white for lightning, orange for fire, pale
blue for ice — as the current cards do.

On the tier 3 card the ice staff runs vertically up the middle and must be the
most legible of the three, because that card's weapon name is ICE STAFF.

---

---

## Paste-ready prompts

Three passes. Each lists exactly which files from `reference/` to attach.

### Prompt 1 — the three HUD icons

> Attach: `icon_vs_head_lightning.png`, `icon_vs_head_fire.png`,
> `icon_vs_head_ice.png`, `head_lightning.png`, `head_fire.png`,
> `head_ice.png`, `i_tod_hud_gun_staff1.png`, `i_tod_hud_gun_staff2.png`,
> `i_tod_hud_gun_staff3.png`, `i_tod_hud_gun_katana.png`,
> `i_tod_hud_gun_axe.png`, `i_tod_hud_gun_blade.png`.
>
> Redraw three weapon HUD icons at 288 x 132, transparent PNG, filenames
> `i_tod_hud_gun_staff1.png` (lightning), `i_tod_hud_gun_staff2.png` (fire),
> `i_tod_hud_gun_staff3.png` (ice).
>
> The three `icon_vs_head_*` images each show a real staff head on the left and
> the icon meant to depict it on the right. The icons' *style* is correct and
> must be preserved exactly; the *object* is wrong and must be replaced. Keep:
> only the three flat colours `#E8EEF6`, `#62779C`, `#0A1020`; no gradients,
> glows or element colour; hard vector edges; ink filling 29-36% of the cell;
> one long object laid diagonally with the head to the upper right; transparent
> background; nothing touching a cell edge.
>
> Match the katana, axe and blade cells so closely in treatment that covering
> the heads makes it impossible to tell which pass drew them.
>
> Redraw each head as the real staff, simplified to three or four shapes:
> lightning = ribbed brass tubes curling outward and down around a chamber;
> fire = two wide flat paddle wings of stacked plates around a burning core;
> ice = a tall arch of twin brackets over a cylinder with side paddles.
> All three centre on a horizontal glass chamber — keep that family
> resemblance, so they read as three weapons from one workshop. They must still
> be tellable apart by silhouette alone at half this size.

### Prompt 2 — the three class and tier cards

> Attach: `i_tod_card_class_mage.png`, `i_tod_card_tier_mage_2.png`,
> `i_tod_card_tier_mage_3.png`, `i_tod_card_class_slasher.png`,
> `i_tod_card_tier_slasher_2.png`, `ingame_lightning_staff.png`,
> `ingame_fire_staff.png`, `ingame_ice_staff.png`, `head_lightning.png`,
> `head_fire.png`, `head_ice.png`.
>
> Re-bake three cards at 768 x 1152, transparent PNG, filenames
> `i_tod_card_class_mage.png`, `i_tod_card_tier_mage_2.png`,
> `i_tod_card_tier_mage_3.png`.
>
> Keep the entire chassis from the current versions: frame, dark navy body, mint
> outer glow, gold title banner and its rivets and text, the art window with its
> corner brackets and sparkles, the dark red UNPACKED banner, the mint MAGE
> nameplate, the bottom weapon-name plate, the pips and the corner screws. The
> slasher cards show the same chassis on another class, for reference.
>
> Change only the staff artwork inside the art window. Keep the painted card
> style and the dark timber shafts with gold banding the current cards already
> use — the shafts are close to right; the heads are wrong. Replace the heads
> with the real staffs' heads, using the screenshots and head crops for shape.
> Keep each card's composition and crossing angles so the three still read as a
> ladder: class card = lightning alone; tier 2 = lightning and fire crossed;
> tier 3 = lightning and fire crossed with ice vertical up the middle and most
> legible of the three. Element colour stays confined to the glass and the
> effect. Do not take colour from the screenshots.

### Prompt 3 — self-check before sending

> Attach your six deliverables plus `i_tod_hud_gun_katana.png`,
> `i_tod_hud_gun_axe.png` and `i_tod_card_tier_mage_3.png`.
>
> Check each of the seven checklist items below and report any that fail.
> Downscale each icon to 144 x 66 and each card to 234 x 351 and confirm the
> three staffs are still tellable apart at that size.

---

## Delivery

- Six PNGs at the exact sizes and filenames in the tables above.
- PNG with alpha. Do not flatten onto a background colour.
- Do not rename, do not add a suffix, do not deliver a sheet in place of the
  cells. If you also want to send a contact sheet, send it *as well*, clearly
  named, not instead.
- Two variants per asset is welcome if you are unsure of a head shape. Put each
  variant set in its own folder.

## Checklist before you send

1. Each of the six is the exact pixel size listed.
2. The three icons use only the three named colours, are flat, have a
   transparent background, and nothing touches a cell edge.
3. The three icons sit indistinguishably beside the katana and axe cells in
   treatment — cover the heads and you cannot tell which pass drew them.
4. The three staffs are tellable apart at 144 x 66 by silhouette alone.
5. The three cards are unchanged outside the art window.
6. Each card's staffs match the real staffs and the card's weapon name.
7. Nothing carries the red or magenta cast from the screenshots.

## Do NOT

- Do not restyle the icons. Palette, flatness, coverage and diagonal all stay.
- Do not put element colour into the icons. They are three greys.
- Do not redesign the cards' frame, banner, nameplate, pips or UNPACKED plate.
- Do not draw fantasy wizard staffs: no crystal clusters, no spiral shells, no
  crescent-and-gem, no orbs on sticks, no glowing runes.
- Do not copy the screenshots' lighting.
- Do not add a fourth staff. There are three; the wind staff is not in this game.

<!-- PACK:END -->
