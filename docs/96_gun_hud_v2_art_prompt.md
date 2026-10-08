# 92 — THE GUN HUD v2: more detail, two missing weapons, four offhand glyphs (3 files)

<!-- art-pack
name: gun_hud_v2
refs:
  docs/96_hud_ref/art_direction_board.png | READ THIS FIRST. The whole art direction on one page: the game, the opposite corner of the same HUD, the GOOD shipped examples, the anti-examples, the palette sampled from the shipped files, and the six rules. UNCHANGED from v1 - it still governs. Attach to every prompt.
  docs/96_hud_ref/v1_at_true_size.png | WHAT YOU DELIVERED, SHOWN AT ITS REAL ON-SCREEN SIZE, on dark and on light. This is the review of v1 and the reason for v2. Attach to every prompt.
  docs/96_hud_ref/v1_assembled_review.png | your own assembled review of v1, kept because it is a good one - it shows the readout working in four real states. Attach to every prompt.
  docs/96_hud_ref/i_tod_hud_gun_sheet.png | THE SHIPPED v1 GUN SHEET. Prompt A redraws this: same style, same grid pitch, MORE INTERIOR DETAIL, and two new cells. Attach to Prompt A.
  docs/96_hud_ref/i_tod_hud_offhand_sheet.png | THE SHIPPED v1 OFFHAND SHEET. Prompt B replaces it completely - this is the weakest art in the set. Attach to Prompt B.
  docs/96_hud_ref/i_tod_hud_letters.png | THE SHIPPED v1 LETTERS SHEET. Prompt C changes exactly ONE cell of it. Attach to Prompt C.
  docs/96_hud_ref/i_tod_hud_digits.png | THE SHIPPED v1 NUMERALS. NOT a deliverable - they are correct and they stay. Shown so the letters keep matching them. Attach to Prompt C.
  docs/96_hud_ref/i_tod_hud_weapon_panel.png | the shipped panel. NOT a deliverable, unchanged. Shown for palette and keyline weight. Attach to Prompt A.
  docs/96_hud_ref/existing_gift_of_death_icon.png | the powerup icon this map ALREADY ships for the Gift of Death - a wrapped present with a bow and a skull. The new weapon cell must echo its SHAPE so the two agree; it must NOT copy its colour, because every weapon on the gun sheet is monochrome steel-white. Attach to Prompt A.
  docs/96_hud_ref/world_cover.png | the map's own cover art: the neon tower, the purple night city, the flat-vector look everything sits in. Attach to every prompt.
preview: 36x36
-->

> **STATUS: v1 IS INSTALLED AND BUILT (v17.9, 2026-09-03).** All 59 v1 images are
> in the game — sliced, wired through the GDT and the `.zone`, GATE A covers the
> concatenated names, and every one converted with a fresh content-hash `.iwi`
> beside an untouched control. This pack is an ENHANCEMENT of three of those
> files, not a fresh start. The map is playable while it is out.

**Why (user, 2026-09-03, after seeing v1 in the tree):** *"I like the design we
go with but they need more detail on weapon shells and possible fonts and digits
where needed. Monkeys grenades and phd web grenades for sure need a different
look. We need a grenade icon for grenades, a spider icon for widow wines
grenades, and a purple spider for PHD widow win grenades."* and **"Like we should
have a katana i believe but i dont see one. Also what about the gift of death.
Lets think through every possibility... I need you to not miss any cases."*

## What v1 got right, and what it did not

v1 is good and most of it ships unchanged. Measured, on the delivered files:

| piece | verdict |
|---|---|
| the 12 gun silhouettes | consistent, readable at 144×66 on both grounds — but **flat and under-detailed**, and **two cases are wrong** |
| the 13 numerals | **correct.** One baseline (y1=152 on every digit), open counters, `1` has its base serif. Not touched by this pack |
| the 29 letters | correct **except the ampersand**, which reads as an `8` |
| the weapon panel | correct. Not touched |
| the offhand tile | correct. Not touched |
| **the 3 offhand glyphs** | **the weakest art in the set — replaced entirely** |

### The offhand glyphs, specifically

Cropped from the delivered sheet at 3× and looked at (`v1_at_true_size.png` shows
them at their real 36 × 36):

- **None of the three has the dark outline the brief asked for.** The letters and
  the gun silhouettes all carry a proper `#0A1020` outline; the offhand sheet
  simply does not. That is why they wash out where the rest of the set holds.
- **The monkey does not read as a monkey with cymbals.** The two cymbals were
  drawn as overlapping round blobs sharing an edge with the body, so at size it
  is one gold lump with a face on top — no arms, no separation, no disc.
- **The frag reads as a snowman.** No collar, no spoon lever, no ring — just a
  large circle with a small one at the top right.
- **The web grenade reads as a pie chart.** The web became three wedges in a
  circle rather than arcs crossed by spokes.

### Two weapons that get the wrong picture today

Both found by reading `source_data/tod_weapon_twins.gdt` and
`source_data/xmas_gun.gdt` rather than by looking at names:

1. **THE WAKIZASHI IS DRAWN AS A COMBAT KNIFE.** The SLASHER's three tiers are
   Knife → **Wakizashi** → Stormbreaker, and v1 maps the first two to the same
   `blade` cell. So that class's *entire* tier-2 promotion — the thing the whole
   upgrade system builds toward — is invisible on the HUD. A wakizashi is a
   short SWORD (`displayName "Wakizashi"` / PaP `"Yamikirimaru"`), not a knife.
   **New cell.**

2. **THE GIFT OF DEATH IS DRAWN AS A MINIGUN.** `_tod_powerups.gsc:1051` sets
   `level.zombie_powerup_weapon["minigun"] = GetWeapon("xmas_gun")`, so the
   Death Machine powerup drops the **Gift of Death** instead — and that weapon is
   `weaponType "projectile"`, `weaponClass "rocketlauncher"`, Full Auto, 80/150
   clip. It is a festive present-launcher, not a rotary cannon. Every player who
   grabs that powerup sees the wrong picture. **New cell.**

### Everything else was checked and is right

Per-stem `weaponClass` out of the GDT, so this is evidence and not opinion:

| class in the GDT | stems | v1 cell | verdict |
|---|---|---|---|
| `smg` | mac10, mp5, mp7 | smg | ok |
| `rifle` | enfield, krig6, ak47 | rifle | ok |
| `mg` | stoner63, hk21, death_machine | lmg / minigun | ok — the Death Machine really is a minigun |
| `spread` | bulldog, sg12, spas12, mog12 | shotgun | ok |
| `spread` | **executioner** | pistol | ok *visually* — it is a revolver that fires shotgun shells, so the handgun silhouette is the honest one |
| `pistol` | magnum, udm, rk7, amp63, pistol_standard | pistol | ok |
| `rocketlauncher` | rpg | launcher | ok |
| `rifle` + projectile | nail_gun | nailgun | ok — its own cell already |
| `melee` | knife / **wakizashi** / leviathan | blade / **blade** / axe | **wakizashi is wrong** |

## The two spiders — and why the purple one is real

The user asked for a spider for Widow's Wine and a **purple** spider for
"PhD widow wine grenades". That second one needed proving before it was worth
drawing, because **art the code cannot select is art that can never appear.**

- **PhD does NOT change the held weapon.** `_tod_perk_phd.gsc` threads a watcher
  on the engine's `grenade_fire` notify and reacts at detonation; its own header
  says the split is *"gated on the thrown weapon BEING the Widow's grenade
  (stock swaps it in as the lethal)"*. So the offhand model reports the same
  weapon with or without PhD, and the two states are **not** distinguishable from
  the weapon alone.
- **But the HUD can read perks directly, and that settles it.**
  `AetheriumPerksContainer.lua` reads
  `Engine.GetModel( Engine.GetModelForController( controller ), "hudItems.perks" )`
  and then one model per perk by `clientFieldName`. From
  `Mappings/AetheriumPerks.lua`: Widow's Wine is **`widows_wine`** and PhD
  Flopper is **`electric_cherry`** (the specialty slot it is hung on — the perk
  is not the specialty, which is a documented trap in this map).

So the lethal glyph is selected from **perk state**, which is authoritative, not
from a stock image name that cannot be read from this tree:

| player has | lethal glyph |
|---|---|
| neither | GRENADE |
| Widow's Wine | SPIDER |
| Widow's Wine **and** PhD Flopper | PURPLE SPIDER |

That is a better lane than v1's substring guess in every way, and all four
offhand glyphs are therefore selectable today with no new clientfield.

## A v1 BUG this pack also fixes: two of the three glyphs never drew

Worth recording because it is the reason the offhand sheet is being replaced
rather than patched, and because the art was fine-ish and the *selection* was
dead.

v1's `TOD_OFFHAND_CELL` picked a glyph by substring-matching the value the
engine publishes on the `CurrentPrimaryOffhand` / `CurrentSecondaryOffhand`
models, guessing at patterns `frag`, `grenade`, `cymbal`, `monkey`, `widow`,
`web`. **The engine's actual vocabulary is four names**, found in the base ZM
asset list (`<modtools>/zone_source/all/assetlist/zm_levelcommon.csv:6088-6091`):

    uie_t7_zm_hud_inv_icnlthl        the lethal
    uie_t7_zm_hud_inv_icntact        the tactical
    uie_t7_zm_hud_inv_icntactlilarnie
    uie_t7_zm_hud_inv_widowswine

Only `widow` can ever match. So the bespoke frag and monkey were set once at
construction and then **permanently overwritten** by the first model callback
with the stock icon — two commissioned images dead on arrival, and the glyph the
player actually saw was the kit's own.

The v2 lane does not guess at all: the tactical slot is always the monkey (this
map has exactly one tactical), and the lethal slot is chosen from **perk state**,
which is authoritative. The engine value is kept only as a last-resort fallback,
and that fallback is safe — those four names live in `zm_levelcommon`, the zone
every ZM map loads, not in the DLC `specialty_*` family that white-squares on a
published usermap.

## Two more weapons that fall through to the wrong cell

Found by an adversarial pass over the v1 mapping, both cheap to fix in the Lua
and neither needing art:

- **THE WIDOW'S WINE KNIFE.** Buying Widow's Wine replaces the player's melee
  with a widow variant. This map never calls `set_player_melee_weapon`, so the
  base melee stays `knife` and every buyer lands on stock's generic branch —
  `knife_widows_wine`. `TOD_GUN_CAT` has no key for it, so it falls through to
  the PISTOL cold-start default: a melee weapon drawing a handgun. Three keys
  (`knife_widows_wine`, `bowie_knife_widows_wine`, `sickle_knife_widows_wine`)
  → `blade` closes it.
- **BARE FISTS.** Two stock paths switch a player to `zombie_fists` — the riot
  shield being destroyed while held, and going down holding it with no other
  primary. Both are closed by inventory here (a player always carries a class
  primary plus a sidearm), so neither is reachable today — but the class-gun
  watchdog in `_tod_upgrades.gsc` exists because inventory *has* been emptied
  before. One key → `blade` is free insurance.

## Geometry — unchanged

Nothing moves. The gun bay is still 96 × 44 canvas = **144 × 66 physical px**,
exactly the 288 × 132 cell aspect (2.1818). The offhand glyphs are still
**36 × 36**. The letters are still 80 × 112 cells.

**The gun sheet grows from 12 cells to 14**, so its canvas goes 1728 × 264 →
**2016 × 264** (7 columns × 2 rows). The offhand sheet goes 3 cells to 4, so
384 × 128 → **512 × 128**.

**Cell pitch does NOT change, deliberately.** More canvas would not buy more
detail: the limit is the 144 × 66 the player actually sees, not the 288 × 132
you draw on. The extra detail asked for below has to survive that downscale, so
it must come from *bigger, fewer, higher-contrast* interior shapes — never from
finer ones.

<!-- PACK:BEGIN -->
# GUN HUD v2 — more detail, two new weapons, four offhand glyphs (3 files)

## Start here

**This is a revision, not a new job.** Twelve weapon silhouettes, a numeral set,
an alphabet, a panel and a tile from the last round are already in the game and
working. Three files change. Everything else stays exactly as it is.

Open, in this order:
1. `art_direction_board.png` — the art direction. **Unchanged, still governs.**
2. `v1_at_true_size.png` — what you delivered last time, at its real on-screen
   size, on a dark background and a bright one. This is the review.
3. `v1_assembled_review.png` — your own assembly of the readout. It is a good
   review and it is why most of the set is staying.
4. `world_cover.png` — the game's own cover art, for the world all of this sits
   over: a neon tower in a purple night city, flat vector shapes with hard
   outlines. Attach it to every prompt alongside the direction board.

## What changes, in one table

| Deliver as | Canvas | Change |
|---|---|---|
| `i_tod_hud_gun_sheet.png` | **2016 × 264** (7 × 2 of 288 × 132) | REDRAW: same style, more interior detail, **12 cells → 14** |
| `i_tod_hud_offhand_sheet.png` | **512 × 128** (4 × 1 of 128 × 128) | REPLACE COMPLETELY: **3 cells → 4**, all four redrawn from scratch |
| `i_tod_hud_letters.png` | **1200 × 224** (15 × 2 of 80 × 112) | ONE CELL fixed. Everything else byte-for-byte as it was |

**NOT deliverables, do not change:** the numerals `i_tod_hud_digits.png`, the
weapon panel, the offhand tile. They are correct. They are attached only so the
new work matches them.

## The sheet rules — unchanged from last time, and they were followed perfectly

Exact canvas size. Uniform grid, **no gutters**, cells butt against each other
and the outermost cells touch the canvas edges. Nothing may touch or cross a cell
boundary — keep every drawing inside about 85–90% of its cell. No grid lines, no
frames, no backgrounds, no labels, no guide marks. Every cell filled, in the
listed order, left to right then top to bottom.

The last delivery hit all of this exactly and the cutter had zero complaints.

## Prompt A — `i_tod_hud_gun_sheet.png` (2016 × 264) — MORE DETAIL, 14 CELLS

Attach `art_direction_board.png`, `v1_at_true_size.png`,
`i_tod_hud_gun_sheet.png` (the shipped one) and `i_tod_hud_weapon_panel.png`.

```text
Attached: the art direction board, a review of the weapon silhouettes at their
real on-screen size, the shipped sheet itself, and the panel they sit on.

Redraw this sheet. The style is RIGHT and must be kept - flat, two tones, hard
dark outline, one light direction, consistent stroke weight. Two things change:
the weapons need more interior detail, and there are two more of them.

Canvas exactly 2016 x 264 pixels, PNG, RGBA, fully transparent background.
A 7 column x 2 row grid, each cell exactly 288 x 132 pixels, butted directly
against each other with no gutters. Cell (column, row) starts at
(column x 288, row x 132) counting from zero.

THE FOURTEEN CELLS, left to right then top to bottom:

  row 1:  1 SUBMACHINE GUN   2 ASSAULT RIFLE   3 LIGHT MACHINE GUN
          4 MINIGUN          5 SHOTGUN         6 PISTOL             7 AKIMBO PISTOLS
  row 2:  8 ROCKET LAUNCHER  9 NAIL GUN       10 GIFT LAUNCHER
         11 COMBAT KNIFE    12 KATANA         13 BATTLE AXE        14 RIOT SHIELD

Cells 1-9, 11, 13 and 14 are the ones you already drew - keep each one
recognisably the same weapon in the same pose, just better. Cells 10 and 12 are
new.

WHAT "MORE DETAIL" MEANS HERE, precisely. These are shown 144 x 66 pixels, a bit
under half the cell, so detail only helps if it SURVIVES that. Do not add fine
lines. Add STRUCTURE, in the darker tone, as big confident shapes:
- Separate the major masses of each gun with a hard darker-tone line: receiver
  from barrel, barrel from handguard, body from stock, grip from body. Right now
  most of these read as one continuous blob with an outline round it.
- Give every gun a visible MAGAZINE or feed as its own shape, not merged into
  the body.
- Give every gun that has one a visible STOCK with a clear step where it meets
  the receiver, and a visible TRIGGER GROUP as a notch under the body.
- Two or three panel lines per weapon in the darker tone - vents, a rail, an
  ejection port. Two or three. Not ten.
- Every added shape and every gap between shapes at least 10 pixels on the
  288-wide cell. If a detail would be under 10 pixels, leave it out.
Test: at 144 x 66 every one of those additions must still be individually
visible. If it turns to mush, it was too fine - make it bigger and use fewer.

KEEP, and this is not negotiable:
- exactly two flat tones per weapon: a steel-white face (#E8EEF6) and one darker
  cool grey-blue, used for the offset AND now for the interior structure
- the same hard dark outline (#0A1020) about 7 pixels round each silhouette
- the same offset direction in all fourteen cells
- relative sizes: the pistol and the knife are small in their cells, the minigun
  and the launchers fill theirs. DO NOT scale every weapon up to fill its cell
- side profile, pointing LEFT, except the riot shield which stays face-on
- NO 3D, NO bevel, NO gloss, NO gradient, NO photographic detail, NO text

THE TWO NEW CELLS:

 10 GIFT LAUNCHER - a full-auto weapon that fires exploding Christmas ornaments.
    This is not a guess about the weapon: its 3D model is literally a wrapped
    present, and its parts are named for a box lid with two FLAPS as the
    magazine, a RIBBON BOW at top and bottom, a GIFT TAG, and eight JINGLE BELLS.
    Draw it as: a squared-off wrapped BOX forming the body, a ribbon running
    across it with a BOW on top, a small rectangular TAG hanging off one corner,
    a short wide CHUTE or muzzle out the front, and a pistol grip with a trigger
    group underneath. One or two small circles for bells. It should look absurd
    and heavy beside the real guns - that is correct, it is a joke weapon.
    It must NOT look like cell 4, the minigun - no rotary barrel cluster, no
    belt.
    A reference image is attached (existing_gift_of_death_icon.png): that is the
    powerup icon this game already uses for this weapon. MATCH ITS SHAPE
    LANGUAGE - box, ribbon, bow - so the two read as the same thing. DO NOT copy
    its pink and purple: every weapon on this sheet is the same steel-white
    two-tone, and a coloured one would break the set.

 12 KATANA - a single-edged curved SWORD, blade pointing left, clearly longer
    and more elegant than the combat knife in cell 11. A gentle curve to the
    blade, a small guard where blade meets handle, and a long wrapped handle
    shown with three or four darker-tone diagonal wrap bands. The silhouette must
    be unmistakably a sword and not a big knife: put them side by side at
    144 x 66 and the difference must be obvious at a glance. It sits between the
    knife and the axe as a player upgrades, so all three must be distinct.

Test before delivering: cut the sheet into its fourteen 288 x 132 cells, shrink
each to 144 x 66 pixels, and lay them in two rows on a dark background, then on a
white one. All fourteen must read as different weapons and as one set. Check
these three pairs specifically, because each pair is one upgrade step apart for
a player: 3 vs 4 (machine gun vs minigun), 8 vs 10 (rocket launcher vs gift
launcher), and 11 vs 12 vs 13 (knife vs katana vs axe).

Deliver as i_tod_hud_gun_sheet.png.
```

## Prompt B — `i_tod_hud_offhand_sheet.png` (512 × 128) — ALL FOUR, FROM SCRATCH

Attach `art_direction_board.png`, `v1_at_true_size.png` and the shipped
`i_tod_hud_offhand_sheet.png`.

```text
Attached: the art direction board, a review at real on-screen size, and the three
equipment glyphs currently in the game.

These are the weakest art in the set and they are being replaced completely. Draw
four new ones. Please read this whole prompt before starting - the diagnosis
matters more than the description.

WHAT IS WRONG WITH THE THREE YOU SEE:
- NONE of them has the hard dark outline. Every other piece in this set - the
  letters, the numerals, all twelve weapons - carries a thick #0A1020 outline,
  and these three do not. That is the single biggest reason they fall apart on a
  light background while everything else holds.
- The monkey does not read as a monkey holding cymbals. The two cymbals were
  drawn as round blobs touching the body, so at its real size it is one gold lump
  with a face. There are no arms and no separation.
- The grenade reads as a snowman: one big circle with a small circle at the top
  right. It has no collar, no spoon lever and no ring.
- The web grenade reads as a pie chart: a circle cut into three wedges.

Canvas exactly 512 x 128 pixels, PNG, RGBA, fully transparent background.
A 4 column x 1 row grid, each cell exactly 128 x 128 pixels, butted directly
together with no gutters. Cell 1 at x 0, cell 2 at x 128, cell 3 at x 256,
cell 4 at x 384.

  cell 1: CYMBAL MONKEY
  cell 2: GRENADE
  cell 3: SPIDER
  cell 4: PURPLE SPIDER

THESE ARE DRAWN 36 x 36 PIXELS. That is the whole difficulty. Each glyph gets
about three big shapes and nothing else. Rules for all four:
- Flat vector art. Exactly TWO flat tones: a bright face and one darker tone of
  the same hue used only as a hard-edged offset down and to the right.
- A crisp dark outline (#0A1020) 8 to 10 pixels wide around the ENTIRE
  silhouette. This is the thing that was missing. It is not optional.
- Fill about 80 percent of the 128 cell, centred, nothing crossing a boundary.
- NOTHING narrower than 14 pixels anywhere, outline included.
- No 3D, no bevel, no gloss, no gradient, no cast shadow.

 CELL 1 - CYMBAL MONKEY. The one that must improve most.
   Front view. Build it from FOUR separate shapes with visible dark outline
   between them, so it cannot merge into a lump:
     - a round head with a small flat fez hat on top
     - a smaller round body below it
     - two ARMS as short straight bars going out sideways from the body, angled
       slightly up - these must be visible as arms, with the dark outline
       separating them from the body
     - one CYMBAL at the end of each arm, drawn as a full circle seen face-on,
       each about 34 pixels across, clearly separated from the arm and from the
       body by outline
   Face: two dots for eyes and one short horizontal line for a mouth. Nothing
   else. No fur, no muzzle, no teeth, no drum, no wind-up key.
   The read at 36 x 36 must be: a small round creature with two circles held out
   to its sides. If the circles touch the body, it fails.
   Colour: warm brass gold face with a deeper bronze as the darker tone. This is
   the only warm colour in the whole set - it is what separates the tactical slot
   from the lethal one at a glance.

 CELL 2 - GRENADE. A classic fragmentation grenade, side profile, and it must
   read as a grenade and not as a ball:
     - an oval body, slightly taller than wide
     - a flat COLLAR across the top, clearly narrower than the body, separated
       from it by the dark outline
     - a straight SPOON LEVER running down the right side from the collar to
       about two thirds of the body height, drawn as a bar with dark outline on
       both sides so it is unmistakably a separate part
     - a PULL RING as a small open circle at the top left of the collar
   That collar plus spoon plus ring is what makes it a grenade. Do not omit
   them. Nothing else - no segmentation grid, no lettering.
   Colour: steel-white face (#E8EEF6) with a mid slate-blue darker tone.

 CELL 3 - SPIDER. Not a grenade with a web on it. An actual spider, top-down:
     - a small round head at the front and a larger round abdomen behind it,
       joined, with the dark outline reading round the pair as one body
     - EIGHT legs, four a side, as thick bars with one bend each, spread evenly
       and reaching well out toward the cell edges
     - each leg at least 14 pixels thick, and clearly separated from its
       neighbours by background - the gaps between the legs are as important as
       the legs
   No eyes, no fangs, no web, no markings on the abdomen. The silhouette is the
   whole glyph.
   At 36 x 36 the read must be: a fat body with eight spiky legs.
   Colour: steel-white face with a mid slate-blue darker tone - the same pair as
   the grenade, because these two are alternatives to each other.

 CELL 4 - PURPLE SPIDER. The SAME spider as cell 3, identical shape, identical
   pose, identical everything - only the colour changes. A bright violet face
   with a deeper purple as the darker tone. Keep the same dark outline.
   The two spiders will sometimes be seen one after the other by the same player,
   so if the shapes differ at all it will look like a mistake. Draw cell 3 and
   copy it.

Test before delivering: cut the sheet into its four 128 x 128 cells, shrink each
to 36 x 36 pixels, and place them on a dark navy tile AND on a white background.
The monkey must read as a creature holding two circles out to its sides. The
grenade must read as a grenade with a lever. Both spiders must read as spiders
with countable legs. If any of them becomes a blob, use fewer and thicker shapes
and try again - and check the outline is really there.

Deliver as i_tod_hud_offhand_sheet.png.
```

## Prompt C — `i_tod_hud_letters.png` (1200 × 224) — ONE CELL

Attach the shipped `i_tod_hud_letters.png` and `i_tod_hud_digits.png`.

```text
Attached: the alphabet sheet currently in the game, and the numeral sheet it is
used alongside.

The alphabet is correct and is staying. Exactly ONE cell is wrong and needs
redrawing. Change nothing else on the sheet.

Canvas exactly 1200 x 224 pixels, PNG, RGBA, transparent background, the same
15 column x 2 row grid of 80 x 112 cells, same order:

  row 1:  A B C D E F G H I J K L M N O
  row 2:  P Q R S T U V W X Y Z - ' & .

THE PROBLEM: the AMPERSAND, at row 2 column 14 (x 1040 to 1120, y 112 to 224).
It was drawn as a squared-off form with a small rectangular counter near the top
and a diagonal tail, and the result reads as the digit 8 or the letter B at every
size it is displayed. The two weapon names in the game that use it come out as
"DEATH 8 TAXES" and "VOICE OF JUSTICE 8 RAGING JUDGE".

Redraw ONLY that cell as an unmistakable ampersand:
- Use the classic looping ampersand form: a closed loop at the TOP LEFT, a
  diagonal stroke running down to the right from it, and a tail kicking out to
  the lower right past the body. The top loop must be clearly SMALLER than the
  bottom of the glyph - the asymmetry between top and bottom is what stops it
  reading as an 8.
- The counter in the top loop must be an obvious open hole at least 12 pixels
  across at its narrowest.
- Do NOT give it a second closed counter at the bottom. An ampersand with two
  stacked holes IS an 8. The lower half must be open on the right.
- Same cap height (74 pixels), same baseline (y 94 within the row), same stroke
  weight (about 16 pixels), same two flat tones, same 5 pixel darker offset down
  and right, same 5 pixel dark outline as every other letter on the sheet.
- Roughly 58 pixels wide, centred in its cell, touching no boundary.

Everything else on this sheet must come back UNCHANGED - same letters, same
positions, same weights. Only that one cell differs.

Test before delivering: cut the sheet, shrink to 27 x 36 pixels, and set
"DEATH & TAXES" mixing in numerals from the attached digit sheet. It must read as
an ampersand and must not be confusable with the 8 on that digit sheet - compare
them side by side.

Deliver as i_tod_hud_letters.png.
```

## Delivery checklist

- [ ] Three files: `i_tod_hud_gun_sheet.png` (2016 × 264),
      `i_tod_hud_offhand_sheet.png` (512 × 128), `i_tod_hud_letters.png`
      (1200 × 224) — all RGBA, transparent
- [ ] The gun sheet is 7 × 2 of 288 × 132 with all fourteen cells filled in order
- [ ] Every gun has visible interior structure — receiver/barrel/stock separated,
      a magazine as its own shape — and all of it still visible at 144 × 66
- [ ] The GIFT LAUNCHER does not look like the minigun
- [ ] The KATANA, the KNIFE and the AXE are obviously three different weapons at
      144 × 66
- [ ] The offhand sheet is 4 × 1 of 128 × 128, and **all four glyphs have the
      hard dark outline** the previous set was missing
- [ ] The monkey's two cymbals are separated from its body by outline
- [ ] The grenade has a collar, a spoon lever and a ring
- [ ] The two spiders are identical in shape and differ only in colour
- [ ] The letters sheet differs from the attached one in exactly one cell
- [ ] Everything downscaled to its real size (144 × 66, 36 × 36, 27 × 36) and
      **looked at on white as well as black**

## Do NOT

- Do not change the numerals, the weapon panel or the offhand tile. They ship
  as they are.
- Do not change the letters sheet other than the ampersand cell.
- Do not change the grid pitch of the gun sheet. 288 × 132 cells, more cells.
- Do not add detail so fine it disappears at 144 × 66 — that is worse than the
  flatness it replaces, because it turns to noise.
- Do not put grid lines, frames, gutters, labels or backgrounds on any sheet.
- Do not use orange, red or green. The only warm colour in the set is the cymbal
  monkey; the only violet is the purple spider.
- Do not add glow, bloom, bevel, chrome or scan lines.
<!-- PACK:END -->

## The v2 cell map — every case, and what it lands on

Fourteen gun cells covering every weapon a player can hold, and four offhand
glyphs covering every state the two slots can show.

| cell | covers | evidence |
|---|---|---|
| 1 SMG | MAC-10, MP5, MP7 | `weaponClass "smg"` ×3 |
| 2 RIFLE | Enfield, Krig 6, AK-47 | `weaponClass "rifle"` |
| 3 LMG | Stoner 63, HK21 | `weaponClass "mg"` |
| 4 MINIGUN | Death Machine (heavy T3) | `weaponClass "mg"`, and it really is one |
| 5 SHOTGUN | Bulldog, SG12, SPAS-12, MOG 12 | `weaponClass "spread"` ×4 |
| 6 PISTOL | MR6 `pistol_standard` (start weapon, heavy T1 sidearm, last-stand pistol), Magnum, UDM, RK 7, AMP63, Executioner | `weaponClass "pistol"`; the Executioner is `spread` but is visually a revolver |
| 7 AKIMBO | `t9_amp63_rdw_up` "Tokyo & Rose", `t6_executioner_rdw_up` | both carry `"dualWield" "1"` |
| 8 LAUNCHER | RPG | `weaponClass "rocketlauncher"` |
| 9 NAIL GUN | `t9_nail_gun` | `rifle` + `projectile`; looks like neither |
| **10 GIFT LAUNCHER** | **`xmas_gun` — the Death Machine powerup drop** | `_tod_powerups.gsc:1051`; `rocketlauncher`/`projectile`, Full Auto |
| 11 KNIFE | `t9_me_knife_american` (slasher T1) | `weaponClass "melee"` |
| **12 KATANA** | **`t9_me_wakizashi` (slasher T2)** | `melee`, displayName "Wakizashi" |
| 13 AXE | `leviathan` — Stormbreaker (slasher T3) | `melee` |
| 14 SHIELD | `zod_riotshield` / `log_riotshield_zm` | RIOT SHIELD domain, v16.63 |

| offhand cell | shown when | selected by |
|---|---|---|
| MONKEY | tactical slot, always | the slot itself (DISTRACTION is the only tactical) |
| GRENADE | lethal slot, no Widow's Wine | perk model `widows_wine` == 0 |
| SPIDER | lethal slot, Widow's Wine | `widows_wine` > 0 |
| PURPLE SPIDER | lethal slot, Widow's Wine **and** PhD | `widows_wine` > 0 and `electric_cherry` > 0 |

## Install (when the drop lands)

1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'`, then
   `node tools/slice_hud_sheets.js --check --src <dir>`. The SHEETS table in that
   tool needs its gun grid changed to 7 × 2 / 14 names and its offhand grid to
   4 × 1 / 4 names **before** the check will pass — that edit is the definition
   of the new layout and the check enforces it.
2. Slice. `--check` proves canvas size, no boundary crossings, one baseline per
   typeface row, and re-emits `TodGlyphMetrics.lua` plus
   `tod_hud_glyphs.generated.json` (which is what gives GATE A its coverage).
3. New names this round: `i_tod_hud_gun_gift`, `i_tod_hud_gun_katana`,
   `i_tod_hud_off_spider`, `i_tod_hud_off_spider_phd`. Each needs its GDT block
   and its `image,` line. `i_tod_hud_off_web` is RETIRED — remove its image, its
   GDT block and its zone line together.
4. `AetheriumLoadout.lua`: add `t9_me_wakizashi -> "katana"` and
   `xmas_gun -> "gift"` to `TOD_GUN_CAT`, and replace the offhand substring guess
   with the perk read described above.
5. **FULL build** (a GDT edit always is). Proof = a fresh content-hash `.iwi` for
   each new name beside an untouched control.
