# 91 — THE GUN HUD (bottom-right): a bespoke component set + a custom typeface (6 files → 60 images)

<!-- art-pack
name: gun_hud
refs:
  docs/95_hud_ref/art_direction_board.png | READ THIS FIRST. The whole art direction on one page: the game, the opposite corner of the same HUD, three GOOD shipped examples with what makes them good, three anti-examples, the palette sampled from the shipped files with hex values, and the six rules. Attach to every prompt.
  docs/95_hud_ref/current_gun_hud_onscreen.png | THE BRIEF IN ONE PICTURE: the gun HUD exactly as it ships, at true 1080p size, on a dark AND a bright background, then magnified, with all eight defects written under it. Attach to every prompt.
  docs/95_hud_ref/target_layout.png | THE TARGET: every slot drawn at its true on-screen size and dimensioned, plus an unannotated version showing the composition. Attach to every prompt.
  docs/95_hud_ref/sibling_bottom_left_onscreen.png | THE OPPOSITE CORNER, already shipped and already approved. The new set must look like it was made by the same hand on the same day. Attach to Prompt A.
  docs/95_hud_ref/house_style_points_icon.png | THE HOUSE GLYPH STYLE: flat, two tones, thick hard dark outline, zero gradient. Every glyph must be this one's sibling. Attach to Prompts B, D, E and F.
  docs/95_hud_ref/house_style_health_frame.png | steel-white furniture with a cool cyan edge, hard-edged, no glow. Attach to Prompts A and C.
  docs/95_hud_ref/class_medallion_skirmisher.png | a shipped class badge - the closest existing thing to the weapon silhouettes wanted in Prompt B. Attach to Prompt B.
  docs/95_hud_ref/world_cover.png | the map's own cover art: the neon tower, the purple night city, the flat-vector-with-hard-outline look everything sits in. Attach to every prompt.
  docs/95_hud_ref/current_loadout_plate.png | the plate being DELETED - a soft electric orb. The anti-example. Attach to Prompt A.
  docs/95_hud_ref/current_lethal_bg.png | the CURRENT offhand tile: an orange swoosh, used mirrored for both slots. Replaced by Prompt C.
  docs/95_hud_ref/current_monkey_icon.png | the CURRENT cymbal-monkey glyph: pale grey line art, unreadable at its real size. Replaced by Prompt D.
  docs/95_hud_ref/current_frag_icon.png | the CURRENT grenade glyph, same problem. Replaced by Prompt D.
preview: 36x36
-->

> **STATUS: PACK BUILT 2026-09-03 (v17.9), awaiting the drop.** The Lua rebuild
> ships alongside and is playable before any of this art lands — every glyph slot
> falls back to the existing TTF text and flat tinted plates until the images
> exist. This art is what makes it look designed.

**Why (user, 2026-09-03):** *"We have updated the left side player HUD but want
to move over to the Gun HUD at bottom right. We would need a component for clip,
reserve, gun, name, lethal and tacticals... It would be nice to have each piece
custom made so we can be consistent."* and then *"I wonder if we should get
creative with digits and letters as well so we can have custom text and numbers
as well. That would be sick."*

## The diagnosis — measured

Draw rects are `AetheriumLoadout.lua`'s boxes put through `AetheriumHud.lua`'s
`TodScaleHud( self.AetheriumLoadout, 1005, 620 )` at `TOD_HUD_SCALE = 1.15`,
then ×1.5 for 1080p — composite transform `X₁₀₈₀ = 1.725·x − 226.125`,
`Y₁₀₈₀ = 1.725·y − 139.5`. Source sizes are the PNG headers of the kit files in
`<modtools>/model_export/_OwensAssets/bo7/aetherium_hud/`.

| element | source | canvas box | 1080p px | aspect error |
|---|---|---|---|---|
| loadout plate | 1024×512 | 885..1312 × 512..720 | 736.6 × 358.8 | +2.6% |
| weapon icon | — | 1055..1165 × 599..664 | 189.8 × 112.1 | — (draws nothing) |
| weapon name | — | 847..1106 × 568..585 | 446.8 × 29.3 | — |
| ammo clip | — | 948..1061 × 605..624 | 194.9 × 32.8 | — |
| **ammo reserve** | — | 968..1057 × 629..638 | **153.5 × 15.5** | — |
| **lethal tile** | 416×320 | 1117..1184 × 541..600 | 115.6 × 101.8 | **−12.6%** |
| **lethal glyph** | 256×256 | 1126..1153 × 554..577 | 46.6 × 39.7 | **+17.4%** |
| **tactical tile** | 416×320 | 1057..1124 × 541..600 | 115.6 × 101.8 | **−12.6%** |
| **tactical glyph** | 256×256 | 1065..1099 × 556..585 | 58.7 × 50.0 | **+17.2%** |
| ammo mod (AAT) | — | 1037..1061 × 641..665 | 41.4 × 41.4 | — (never fires) |

**Eight defects**, in the order they hurt:

1. **THE WEAPON ICON IS BLANK FOR EVERY WEAPON IN THIS MAP.** Not dim, not
   wrong — *absent*. `AetheriumLoadout.lua`'s `GetWeaponIcon()` looks the weapon
   up in `CoD.AetheriumWeaponData` (`Mappings/AetheriumWeapons.lua`), and that
   table's gun entries are `sat_ar_hawk`, `sat_ar_condor`, `sat_ar_macaw` and
   their `_up` forms — **map 1's roster**. Not one of this map's **24** ladder
   weapons (12 primaries + 12 sidearms) is in it, so every one falls to
   `["default"] = { icon = "blacktransparent" }`. A 190 × 112 pixel hole in the
   middle of the panel, shipped since the kit was vendored. This is the defect
   that makes a bespoke set worth paying for.

2. **THE LETHAL GLYPH IS HARDCODED TO A FRAG, AND A PERK CHANGES THE WEAPON.**
   `AetheriumLoadout.lua:429/451/459` sets `i_mtl_sat_ui_icon_lethal_grenade_frag`
   literally, three times, and never reads what the player is holding. **Widow's
   Wine is in this map's nine-perk roster** and swaps the player's lethal for its
   own web grenade — after which this readout still draws a pineapple. The engine
   already publishes the right answer: the `CurrentPrimaryOffhand` /
   `primaryOffhand` global model carries a ready-to-register image name (this
   file's own dead branch tests one at `:502`,
   `"uie_t7_zm_hud_inv_icntactlilarnie"`), and map 1 ships the correct lane —
   `acc_hud.lua:1584-1592` does `RegisterImage(v)` on the engine's own value.
   > **CORRECTION, 2026-09-03.** An earlier draft of this doc claimed the lethal
   > slot *could never fill at all*, on the grounds that this map has no wall buys
   > and nothing in `scripts/zm/zm_tower_of_doom/` grants a frag. That was read
   > off the map's own scripts and it was **wrong**. Stock
   > `_zm.gsc:4564 award_grenades_for_survivors()` **gives** the lethal and sets
   > its clip to 2/3/4, and it is called from `round_think` at `_zm.gsc:4408` —
   > outside all three round pointers this map overrides
   > (`_tod_endless_rounds.gsc:172-174`), with `headshots_only` set nowhere.
   > **Every survivor gets 2–4 free frags at the start of every round.** Both
   > offhand slots are live and both must look right full and empty.

3. **A MELEE CLASS READS `0` AND `0` FOREVER.** Parsed across all 191 blocks of
   `source_data/tod_weapon_twins.gdt`: the 36 `t9_me_knife_american_*`,
   `t9_me_wakizashi_*` and `leviathan_*` variants all carry `clipSize 0` and
   `maxAmmo 0`. The SLASHER carries a blade at **all three tiers**, so that is a
   quarter of the roster, whole run. In Lua `0` is truthy, so
   `AetheriumLoadout.lua:316` `if ammoInClip then` passes and `:346` prints a
   literal zero — and the clip is the biggest element on the panel. The riot
   shield (`weaponType "riotshield"`) lands in the same case. **Map 1 hit this
   and fixed it** (`acc_hud.lua:1484-1494`: show `-` rather than a meaningless
   `0 / 0`), which is why the digit sheet here carries a dedicated dash.

4. **THE PLATE RUNS OFF THE SCREEN.** Right edge at x=2037 on a 1920-wide
   screen, bottom at y=1102 on a 1080-tall one — 117 px and 22 px past. The
   fifth that gets cut is the calm dark tail; what stays is the bright electric
   core, and the ammo numbers are drawn on top of exactly that.

5. **THE RESERVE NUMBER IS 15 PIXELS TALL** — under half the clip number above
   it, and it is the number you check before committing to a fight. Measured
   maximums across the generated roster: **clip 188**, **reserve 752**
   (`t6_death_machine_up_p*`) — both three digits, so three is the proven floor
   and the boxes below are sized for four.

6. **THE TWO OFFHAND TILES ARE ORANGE, MIRRORED COPIES OF ONE SWOOSH.**
   Everything else in this HUD is electric blue, and the two slots are the same
   shape, so nothing but the glyph tells them apart. Both are squashed 12.6%
   from their source aspect; both glyphs are stretched 17% the other way.

7. **THE WEAPON NAME RUNS UNDER THE TACTICAL TILE.** Its box is 1235..1682 at
   1080p and centre-aligned; the tactical plate starts at 1597, so the right
   85 px of the name box sits on top of it.

8. **THE PLATE IS AN ELECTRIC ORB**, brightest exactly where the numbers sit.

Also dead, and deleted rather than re-skinned: the **AAT / ammo-mod icon**
(subscribes to `currentWeapon.aatIcon`; this map ships no alternate ammo types),
the **octobomb** lane (Li'l Arnie was retired from DISTRACTION in v16.49), and
the `isEquipment` substring branch at `:192-198`, which routes `knife_` to a
56×56 box and therefore catches all 12 `t9_me_knife_american_*` forms — the
slasher's T1 **primary**.

### Why this is a bespoke set and not a re-tint

Every kit image here is DXT5 (`compressionMethod "compressed"` in
`bo7_aetherium_hud.gdt`, which lives in the mod-tools root, is **not** in this
repo and is **shared with map 1**). Our own `i_tod_*` images are `uncompressed`.
Re-authoring as `i_tod_hud_*` fixes the compression, the aspect errors, the
palette and the missing icon in one pass, version-controlled, with no reach into
a shared file — the argument docs/89 made for the player panel, which shipped
well.

## THE THING THAT MAKES THIS SET CONSISTENT: SHEETS, NOT FILES

The user's actual requirement is *"each piece custom made so we can be
consistent."* Consistency across N separately-generated images is exactly where
art packs fail — sixty glyphs asked for sixty times come back with sixty stroke
weights and sixty light directions.

So the small pieces are **not** requested as separate files. They are requested
as **four sheets**, each drawn in one pass as one image, and this repo slices
them locally (`tools/slice_hud_sheets.js`, the same trick `tools/slice_gauge.js`
already uses to cut 54 gauge tiles from registered masters). One generation =
one hand, one light, one stroke weight, by construction.

**The two typeface sheets are SINGLE ROWS on purpose.** A row makes the shared
baseline visible to whoever is drawing it, which is the one property that
decides whether a bitmap font looks like a font or like thirteen drawings.

**Six delivered files become 60 shipped images.**

## THE CUSTOM TYPEFACE — what it can and cannot carry

The user asked for custom digits *and* letters. Both are in, but they are not the
same proposition and the doc should say so.

**DIGITS are an unambiguous win.** The clip counter is the single most-looked-at
glyph in the HUD, it is drawn ~40 px tall, and it is never more than four
characters. Custom numerals there are pure upside.

**LETTERS carry a real risk, mitigated in code.** The 44 display names in
`source_data/tod_weapon_twins.gdt` (plus `AMP63`, `Tokyo & Rose`,
`Gift of Death`, `X-Mass Murder`, `Riot Shield`) run from `MP5` (3 characters) to
`VOICE OF JUSTICE & RAGING JUDGE` and `UNIVERSAL DEMOLISHING MECHANISM` (31).
Thirty-one glyphs in a 372-pixel band is a 12 px advance — a size where a scaled
bitmap letterform loses to a hinted TTF. So the renderer **auto-fits**: it
measures the string against the derived width table, picks a scale in
`[0.50, 1.00]`, and only if the string still will not fit at 0.50 does it fall
back to the TTF for that one name. Short names — most of them, and every
base-tier one — get the full-size custom face.

**The character set is verified, not guessed.** Every one of those names was read
out of the GDT. They contain `A-Z`, `a-z`, `0-9`, space, `-`, `'`, `&`, and the
engine colour escapes `^3` / `^7` (in `^3Face Hammer^7`). The renderer
**uppercases** the string, so only capitals are needed, and **strips `^n` colour
codes** before layout, or they render as literal glyphs.

So the alphabet needs **A–Z (26) + `-` + `'` + `&` + `.` = 30 cells.** Digits come
off the digit sheet, which the name renderer shares — `AK-47`, `MP5`, `SPAS-12`
and `BLITZKRIG 99` all mix numerals into a name.

**Metrics are DERIVED, never hand-authored.** `slice_hud_sheets.js` measures each
cell's alpha bounding box and emits the advance-width table into
`ui/uieditor/widgets/HUD/AetheriumWidgets/TodGlyphMetrics.lua`. The art and its
metrics therefore cannot drift — the same doctrine as the generated
`_tod_door_data.gsc`. Redraw a glyph narrower and the spacing follows on the next
slice.

## Geometry the art must hit

**`TodScaleHud` is REMOVED from this widget.** The 1.15 scale about (1005, 620)
existed to make the kit's small text readable; the rebuild authors bigger boxes
directly instead, which makes canvas × 1.5 = 1080p exactly, kills the whole
"post-scale" arithmetic class, and makes it impossible for a box to walk off the
screen.

> **The perks container stays a CHILD of this widget** (`AetheriumLoadout.lua:412`)
> rather than being split out, which is the opposite of what the file's own
> `ONE-ANCHOR LIMIT` comment suggests — and it is the better call. Dropping the
> scale puts `PerkList`'s ±180 box back on centre 640, matching the powerup row,
> **with zero visibility-lane work**, because a child keeps inheriting both alpha
> subscriptions. Splitting it out means hand-adding both lanes, and
> `AetheriumHud.lua:520-556` and `:563-599` are two independent absolute writers
> that already disagree. The cost is that `AetheriumPerkItem`'s 28×28 goes from
> 32.2 to 28 canvas px; that is bought back by bumping the item size, not by
> keeping the scale.

All boxes on the 1280×720 LUI canvas. Whole readout: **x 1000..1256, y 568..678**
= 256 × 110 canvas = **384 × 165 physical pixels**, bottom edge at y=1017, level
with the minimal player readout in the opposite corner.

> **The tower gauge is the one neighbour with no clearance to spare.**
> `tod_upgrade.lua:2942-2943` puts it at canvas x1216..1268, y150..566, unscaled,
> in an always-open additive overlay that draws **on top of** AetheriumHud. The
> offhand row starts at y568 — a 2 canvas-pixel gap. Nothing in this pack may
> grow upward, and the tile's shadow must not bleed above its own canvas.

| slot | canvas box | @1080p | art |
|---|---|---|---|
| tactical tile | 1160..1206 × 568..600 | 69 × 48 | `i_tod_hud_offhand_tile` |
| tactical glyph | 1166..1190 × 572..596 | 36 × 36 | offhand sheet |
| tactical count | 1191..1204 × 577..594 | 20 × 26 | digit sheet |
| lethal tile | 1210..1256 × 568..600 | 69 × 48 | same tile file |
| lethal glyph | 1216..1240 × 572..596 | 36 × 36 | offhand sheet |
| lethal count | 1241..1254 × 577..594 | 20 × 26 | digit sheet |
| **weapon panel** | 1000..1256 × 604..678 | **384 × 111** | `i_tod_hud_weapon_panel` |
| weapon name | 1004..1252 × 606..630 | 372 × 36 | letter + digit sheets |
| gun bay | 1004..1100 × 632..676 | 144 × 66 | gun sheet |
| ammo clip | 1104..1188 × 634..674 | 126 × 60 | digit sheet |
| ammo reserve | 1192..1252 × 648..672 | 90 × 36 | digit sheet |

Every art box's aspect matches its source exactly: panel 256/74 = 1024/296 =
3.4595; gun bay 96/44 = 288/132 = 2.1818; tile 46/32 = 276/192 = 1.4375. **Zero
aspect error anywhere** — that is the defect docs/89 was written to kill.

**Positions inside the 1024 × 296 panel art** (scale = 1024/256 = 296/74 = 4.0):

| what sits there | panel-art px |
|---|---|
| weapon name band (custom letters, right-aligned) | x 16..1008, y 8..104 |
| gun bay (a silhouette is drawn into this) | x 16..400, y 112..288 |
| clip numerals (large, right-aligned) | x 416..752, y 120..280 |
| reserve numerals (smaller, right-aligned) | x 768..1008, y 176..272 |

## Runtime tints the art MUST survive

- **The offhand tile is ONE FILE used for BOTH slots.** Never colour-tinted — the
  glyph distinguishes lethal from tactical — but the whole slot is drawn at
  **`setAlpha( 0.40 )`** when the count is zero. It must still read as a tile at
  40% opacity over a bright background: a real dark body, not a whisper.
- **Clip digits are tinted RED and pulsed** at low ammo (`setRGB(1,0,0)` ↔ white,
  200 ms). The numerals must therefore be authored **steel-white / near-neutral**
  — any baked-in hue multiplies with the red and goes muddy — and the panel
  behind them must not be red or the warning stops reading.
- **Gun silhouettes and letters are drawn at `setRGB(1,1,1)`** on transparent
  backgrounds. Author them light; the bays behind them are dark.
- **The weapon panel is never tinted.** Free colour — but the four bays must stay
  dark and calm, because live white glyphs are drawn on them.
- **Nothing here is wipe-clipped.** There is no draining bar in this widget, so
  unlike the health fill in docs/89 there is no column-uniformity rule. Detail
  along the width is allowed and wanted.

<!-- PACK:BEGIN -->
# GAME HUD — GUN READOUT + A CUSTOM TYPEFACE (6 files, 60 images)

## Start here

**Open `art_direction_board.png` first and read all of it.** It is the whole art
direction on one page: the game this belongs to, the opposite corner of the same
HUD (already shipped, already approved), three GOOD examples with what makes them
good, three anti-examples, the exact palette sampled out of the shipped files,
and six rules. Everything below assumes you have read it.

Then open `current_gun_hud_onscreen.png` — what ships today, at true size on a
dark and a bright background, with everything wrong with it written underneath.
Then `target_layout.png` — what is being built, every slot at its true on-screen
size and dimensioned, with an unannotated version showing the composition.

## What this is

The bottom-right corner of the heads-up display of a custom Call of Duty:
Black Ops III zombies map. It is the weapon readout: it shows the gun you are
holding, its name, the rounds in your magazine, your reserve ammo, and two small
tiles counting your thrown equipment.

The map is a fifty-floor neon tower in a purple night city. The player climbs an
open staircase spiralling around the *outside* of it while an endless horde
chases them. This readout sits over that — over black sky, over glowing treads,
over a bright fog bank, over a gold citadel. It has to stay readable over all of
it, and there is **no background panel behind most of it**.

## The three rules that matter more than anything else

1. **DRAW FOR THE SIZE IT IS SHOWN, NOT THE SIZE OF YOUR CANVAS.** Every file
   here is displayed at a third to a fifth of the canvas you draw it on. The
   smallest pieces are shown **36 × 36 pixels**. Few shapes, thick strokes, huge
   contrast. Nothing narrower than about **6 px on your canvas**; if a detail
   would be under 10 px, delete it rather than shrink it.

2. **FLAT. ALWAYS.** No bevel, no extrusion, no gloss, no gradient ramps, no
   chrome, no photographic texture, no bloom, no glow. Two flat tones per
   element: a face, and one darker tone used only as a hard-edged offset.

3. **IT MUST READ ON A BRIGHT BACKGROUND.** Look at the right-hand half of every
   reference image. Anything pale with no dark edge disappears. Every piece needs
   a hard near-black outline and, where it floats free, a soft dark shadow
   outside it.

## The palette (sampled from the shipped files — do not invent colours)

| hex | name | use |
|---|---|---|
| `#E8EEF6` | STEEL WHITE | every furniture face — frames, silhouettes, numerals, letters |
| `#5BC8FF` | ELECTRIC CYAN | keylines, edges, rules |
| `#33D9FF` | BRIGHT CYAN | the hottest accent, used sparingly |
| `#131B38` | DEEP NAVY | panel and tile bodies |
| `#0A1020` | OUTLINE BLACK | the hard outline around every silhouette |

**No orange, no red, no purple, no green, no gold anywhere** — with exactly one
exception, the cymbal monkey in Prompt D, which is warm brass on purpose so the
two equipment slots differ at a glance. Red is otherwise reserved: the game
flashes the ammo numerals red at low ammo. Gold is reserved for the currency
glyph in the opposite corner.

## Deliver exactly SIX files

| Deliver as | Canvas | Shown on screen at | What it is |
|---|---|---|---|
| `i_tod_hud_weapon_panel.png` | **1024 × 296** | 384 × 111 px | the chassis: a name band, a bay for a gun silhouette, and a bracket around two numbers |
| `i_tod_hud_gun_sheet.png` | **1728 × 264** | each cell 144 × 66 px | SHEET — 6 × 2 grid of 288 × 132 cells: twelve weapon-category silhouettes |
| `i_tod_hud_offhand_tile.png` | **276 × 192** | 69 × 48 px | one small tile, used for both equipment slots |
| `i_tod_hud_offhand_sheet.png` | **384 × 128** | each cell 36 × 36 px | SHEET — 3 × 1 row of 128 × 128 cells: a cymbal monkey, a frag grenade, a web grenade |
| `i_tod_hud_digits.png` | **1664 × 160** | each cell up to 42 × 60 px | SHEET — 13 × 1 row of 128 × 160 cells: `0`–`9`, `/`, `+`, `-` |
| `i_tod_hud_letters.png` | **1200 × 224** | each cell up to 27 × 36 px | SHEET — 15 × 2 grid of 80 × 112 cells: `A`–`Z`, `-`, `'`, `&`, `.` |

All six: PNG, RGBA, transparent background, flat vector-clean game-UI art.

**Do not deliver 4K or "upscaled" versions.** These sizes are already 2–4× what
the game displays. Bigger files are thrown away and the extra detail is lost.

## THE SHEET RULES — read these before drawing any sheet

Four of the six files are sheets. The reason is consistency: twelve weapon
silhouettes drawn as twelve separate requests come back as twelve different
styles. Drawn as one image in one pass they cannot.

For **every** sheet:

- The grid is **exact and uniform**, and the sizes are given per prompt. Cell
  `(column, row)` starts at `(column × cellWidth, row × cellHeight)`, counting
  from zero.
- **No gutters, no margins, no padding.** Cells butt directly against each other
  and the outermost cells touch the canvas edges.
- **Nothing may touch or cross a cell boundary.** Keep every drawing inside a
  safe area of about 85–90% of its cell, with transparent margin all round.
- **No grid lines, no cell frames, no boxes, no backgrounds, no labels, no
  reference text, no guide marks of any kind.** The sheet is only a delivery
  format; it gets cut up and the cells are used separately.
- **Every cell filled, in the exact order listed.** Reading order is
  left-to-right, then top-to-bottom.
- **The canvas must be EXACTLY the stated size.** The cutting is arithmetic, not
  vision — a sheet 1730 px wide instead of 1728 slices wrong on every cell.

## Prompt A — `i_tod_hud_weapon_panel.png` (1024 × 296)

Attach `art_direction_board.png`, `target_layout.png`, `world_cover.png`,
`current_loadout_plate.png`, `house_style_health_frame.png` and
`sibling_bottom_left_onscreen.png`.

```text
Attached: an art direction board for a game HUD, a dimensioned target layout, the
game's cover art, the soft glowing orb this replaces, a shipped bar frame in the
correct house style, and the opposite corner of the same HUD.

Draw the chassis the weapon readout sits on: a single wide horizontal panel,
anchored to the bottom-right corner of the screen.

Canvas exactly 1024 x 296 pixels, PNG, RGBA, transparent background. It is
displayed at 384 x 111 pixels - a 2.67x reduction. Flat, hard-edged, neon-cyber
game UI. NO glow, NO bevel, NO 3D, NO soft blur, NO photographic texture.

Four regions sit on this panel. The game draws live glyph art into them, so they
must be dark, calm and completely empty. Their exact rectangles on your
1024 x 296 canvas:

  NAME BAND      x 16 to 1008, y 8 to 104     (white letters, right-aligned)
  GUN BAY        x 16 to 400,  y 112 to 288   (a light weapon silhouette)
  CLIP NUMBER    x 416 to 752, y 120 to 280   (large white numerals)
  RESERVE NUMBER x 768 to 1008, y 176 to 272  (smaller white numerals)

What to draw:

- A DARK, NEARLY OPAQUE BODY under all four of those rectangles: a deep navy
  near-black around #131B38, at roughly 85 percent opacity. This is what makes
  white glyphs readable over a bright game world, so do not make it a whisper.
  Keep it visibly DARKER and CALMER than anything around it. No filaments, no
  highlights, no texture, no pattern inside those four rectangles.
- A GUN BAY that reads as a recessed well: outline the x 16-400, y 112-288
  rectangle with a bright cyan keyline (#5BC8FF) about 6 pixels thick, and make
  its interior slightly darker than the rest of the panel. A light silhouette is
  dropped inside it at runtime, so leave the interior empty.
- A DIVIDER between the clip number and the reserve number: one clean vertical
  cyan rule about 5 pixels wide at roughly x 760, running from y 130 to y 275.
  It reads as the slash in "32 / 240".
- A HAIRLINE separating the name band from the row below it: one horizontal cyan
  rule about 3 pixels tall, from x 16 to x 1008, at about y 108. Keep it subtle -
  it is a divider, not a feature.
- A THIN BRIGHT CYAN RULE along the panel's whole bottom edge, about 6 pixels
  tall, full width. This is the readout's baseline and it is what ties this
  corner to the opposite one in the attached screenshot.
- A SINGLE ANGLED CUT at the panel's top-left corner - shave the corner off at
  about 45 degrees over roughly 44 pixels - so the panel has a direction and does
  not read as a plain rectangle. Every other corner stays square.
- A HARD NEAR-BLACK OUTLINE (#0A1020) about 5 pixels thick around the panel's
  whole silhouette, and outside that a soft dark shadow about 12 pixels deep
  fading to transparent, so the panel separates from a light background.

Palette: deep navy-black body, electric cyan keylines and rules, steel white only
at the very hottest points. NO orange, NO red, NO purple, NO green, NO gold.

Leave a transparent margin of a few pixels inside the canvas edges for the
shadow, and keep the shadow OFF the top edge entirely - another element sits two
pixels above this panel.

Test before delivering: shrink your result to 384 x 111 pixels and put it on a
white background, then on a black one. The gun bay must still read as a crisp
rectangle on both, and all four regions must be visibly darker than the
background on both.

Deliver as i_tod_hud_weapon_panel.png.
```

## Prompt B — `i_tod_hud_gun_sheet.png` (1728 × 264)

Attach `art_direction_board.png`, `house_style_points_icon.png`,
`class_medallion_skirmisher.png` and `target_layout.png`.

```text
Attached: an art direction board, a flat game HUD glyph showing the house drawing
style, a shipped class badge whose weapon silhouette is very close to what is
wanted here, and a dimensioned layout.

Draw TWELVE weapon silhouettes as ONE sheet, so that they are unmistakably one
set drawn by one hand.

Canvas exactly 1728 x 264 pixels, PNG, RGBA, fully transparent background.
A 6 column x 2 row grid of cells, each cell exactly 288 x 132 pixels, butted
directly against each other with no gutters and no margins. Cell (column, row)
starts at (column x 288, row x 132) counting from zero.

THE TWELVE CELLS, in reading order left-to-right then top-to-bottom:

  row 1:  1 SUBMACHINE GUN   2 ASSAULT RIFLE   3 LIGHT MACHINE GUN
          4 MINIGUN          5 SHOTGUN         6 PISTOL
  row 2:  7 AKIMBO PISTOLS   8 ROCKET LAUNCHER 9 NAIL GUN
         10 COMBAT KNIFE    11 BATTLE AXE     12 RIOT SHIELD

Each cell holds ONE weapon in SIDE PROFILE, pointing LEFT, drawn as a flat
silhouette, centred in its cell. Never let any drawing touch or cross a cell
boundary.

The style:
- Completely flat vector art. NO 3D, NO bevel, NO extrusion, NO cast shadow, NO
  gloss, NO gradient ramp of any kind, NO photographic detail.
- Exactly TWO flat tones for the body: a bright face in steel white (#E8EEF6),
  and one darker cool grey-blue used only as a hard-edged offset along the bottom
  edge of every form. Same offset direction in all twelve cells.
- A crisp dark outline about 7 pixels wide around each complete silhouette, in a
  very dark cool blue-black (#0A1020).
- Enormously simplified. These are shown 144 x 66 pixels. Each weapon should read
  as about four to seven big shapes - body, barrel, magazine, stock, grip - and
  nothing else. No sights, no rails, no screws, no serial numbers, no muzzle
  detail, no trigger-guard detail, no texture, no text.
- Every stroke and every gap at least 10 pixels on your canvas.

CONSISTENCY IS THE WHOLE POINT and it will be judged on these four things:
- identical stroke weight and identical outline thickness in all twelve cells
- identical offset direction and identical offset thickness in all twelve cells
- the same level of abstraction everywhere - do not draw one gun carefully and
  another loosely
- weapons scaled RELATIVE TO EACH OTHER as they are in life: the pistol and the
  knife are small in their cells, the minigun and the launcher fill theirs.
  DO NOT scale every weapon up to fill its cell.

Cell notes:
   1 SUBMACHINE GUN - compact, short barrel, box magazine, folding stock.
   2 ASSAULT RIFLE - longer barrel, curved magazine, full stock.
   3 LIGHT MACHINE GUN - heavy, thick barrel, a carry handle on top, a belt box
     underneath.
   4 MINIGUN - an unmistakable rotary barrel cluster at the front, a squat body,
     a spade grip at the back. The heaviest silhouette on the sheet, and it must
     read as different from cell 3 at a glance.
   5 SHOTGUN - pump action, a tube under the barrel, wide muzzle.
   6 PISTOL - a single handgun. The smallest firearm on the sheet, about half the
     width of the others in its cell.
   7 AKIMBO PISTOLS - TWO of that same handgun, one behind the other and offset
     up and to the right, so the pair reads instantly as "two guns" and not as
     one. Same pistol drawing as cell 6, duplicated.
   8 ROCKET LAUNCHER - a shoulder tube with a conical warhead at the front and a
     pistol grip under it.
   9 NAIL GUN - a boxy industrial nailer: a chunky rectangular body, a short
     stubby barrel, a magazine sticking down and forward at an angle, a fat
     handle. It should read as a TOOL, not as a firearm.
  10 COMBAT KNIFE - a straight blade and a wrapped handle, blade pointing left.
     Draw it at a slight angle so it reads as a blade and not as a line.
  11 BATTLE AXE - a heavy double-bitted axe head on a haft, head at the left.
     Chunky and unmistakable next to the knife.
  12 RIOT SHIELD - a tall rounded rectangular shield seen FACE-ON, not in
     profile, with one horizontal viewport slot across its upper third. The only
     face-on item on the sheet; that is correct and intended.

NO grid lines, NO cell frames, NO backgrounds, NO labels, NO text anywhere.

Test before delivering: cut the sheet into its twelve 288 x 132 cells, shrink
each to 144 x 66 pixels, and lay them in a row on a dark background. All twelve
must read instantly as different weapons, and the row must look like one set.
Check cells 3 and 4 side by side - if the machine gun and the minigun look alike
at that size, exaggerate the minigun's barrel cluster. If any cell turns into a
grey smear, simplify it further and thicken its strokes.

Deliver as i_tod_hud_gun_sheet.png.
```

## Prompt C — `i_tod_hud_offhand_tile.png` (276 × 192)

Attach `art_direction_board.png`, `current_lethal_bg.png`,
`house_style_health_frame.png` and the FINISHED `i_tod_hud_weapon_panel.png`
from Prompt A.

```text
Attached: an art direction board, the orange swoosh this replaces, a shipped bar
frame in the correct house style, and the finished panel from the previous step.

Draw ONE small tile. Two of them sit side by side above the weapon panel, each
holding a small equipment glyph and a count. The SAME file is used for both, so
it must be neutral - it carries no meaning of its own.

Canvas exactly 276 x 192 pixels, PNG, RGBA, transparent background. Displayed at
69 x 48 pixels, a 4x reduction. Flat, hard-edged, no glow, no bevel, no gradient.

The design:
- A rounded-corner rectangle filling most of the canvas, corner radius about 10
  pixels, with a transparent margin of about 10 pixels all round for its shadow.
- Body: deep navy near-black (#131B38) at about 85 percent opacity. Dark enough
  that a light glyph and white numerals read strongly on top.
- A bright cyan keyline (#5BC8FF) about 5 pixels thick around the whole rounded
  rectangle.
- A slightly brighter cyan accent along the BOTTOM edge only, about 9 pixels
  tall, running the full inner width - so the tile has a floor and matches the
  bright cyan baseline rule on the attached panel.
- A hard near-black outline (#0A1020) about 4 pixels outside the cyan keyline,
  and outside that a soft dark shadow about 10 pixels deep fading to transparent.
- The interior must be plain and even. A glyph is drawn into the LEFT half and a
  numeral into the RIGHT half at runtime, so put NOTHING inside: no divider, no
  pattern, no inner highlight, no vignette, no icon.

It must match the attached panel exactly in palette, keyline thickness and corner
treatment - they sit 4 pixels apart on screen and must read as one system.

IMPORTANT - this tile is also drawn at 40 percent opacity when the slot is empty,
which happens several times a match for both slots. So it must still read as a
tile when everything about it is 40 percent as strong. That means a genuinely
dark body and a genuinely bright keyline, not subtle ones.

Test before delivering: shrink to 69 x 48 pixels and place it on a white
background at full opacity, and again at 40 percent opacity. It must read as a
crisp rounded tile in both.

Deliver as i_tod_hud_offhand_tile.png.
```

## Prompt D — `i_tod_hud_offhand_sheet.png` (384 × 128)

Attach `art_direction_board.png`, `house_style_points_icon.png`,
`current_monkey_icon.png`, `current_frag_icon.png` and the FINISHED
`i_tod_hud_offhand_tile.png` from Prompt C.

```text
Attached: an art direction board, a flat game HUD glyph showing the house drawing
style, the two pale grey equipment icons being replaced, and the tile these sit
on.

Draw THREE equipment glyphs as ONE sheet so they are obviously a matched set.

Canvas exactly 384 x 128 pixels, PNG, RGBA, fully transparent background.
A 3 column x 1 row grid, each cell exactly 128 x 128 pixels, butted directly
against each other with no gutters. Cell 1 starts at x 0, cell 2 at x 128,
cell 3 at x 256.

  cell 1: CYMBAL MONKEY
  cell 2: FRAG GRENADE
  cell 3: WEB GRENADE

These are displayed 36 x 36 PIXELS. That is very small. The attached grey icons
are what happens when detailed line art is shrunk that far - the monkey becomes a
smudge. Yours must survive it.

The style:
- Completely flat vector art. NO 3D, NO bevel, NO extrusion, NO cast shadow, NO
  gloss, NO gradient of any kind.
- Exactly TWO flat tones per glyph: a bright face and one darker tone of the same
  hue, the darker used only as a hard-edged offset toward the bottom-right.
- A crisp dark outline about 8 pixels wide around the entire silhouette, in a
  very dark cool blue-black (#0A1020).
- Each glyph fills about 80 percent of its 128 pixel cell and is centred in it.
  Nothing may touch or cross a cell boundary.
- Nothing narrower than 12 pixels anywhere, outline included.

CELL 1 - CYMBAL MONKEY. A toy monkey seen from the front, sitting, holding one
cymbal in each hand out to its sides. Reduce it to its silhouette: a round head,
a round body, two arms out sideways, and one flat circular cymbal at the end of
each arm. Give it a small flat hat. Two dots for eyes, one line for a mouth, and
NOTHING else on the face. No fur, no teeth, no drum, no wind-up key, no strap, no
explosive charges. The two cymbals sticking out sideways ARE the silhouette -
make them big and unmistakable.
Colour: a warm brass gold face with a deeper bronze as the darker tone. This is
the ONE warm colour allowed in the whole pack - it is what separates the two
equipment slots at a glance.

CELL 2 - FRAG GRENADE. A hand grenade in side profile: a rounded body, a flat
collar on top, and one straight spoon lever down the right side with a ring at
the top. Nothing else. No segmentation grid, no pin detail, no lettering.
Colour: a steel-white face (#E8EEF6) with a mid slate-blue as the darker tone.

CELL 3 - WEB GRENADE. The same grenade silhouette as cell 2 - identical body,
collar, spoon and ring, so the pair reads as two versions of one object - but
with a simple spider-web motif across the body: two or three concentric arcs
crossed by three or four straight radial spokes, all in the darker tone, thick
and widely spaced. No spider, no strands trailing off, no more than about seven
lines total.
Colour: a pale lilac-white face with a deeper violet as the darker tone. This is
the only violet in the pack and it is correct here - it is the colour of the
in-game effect it represents.

All three must read as a matched set - identical outline thickness, identical
offset direction, identical weight - differing only in shape and hue.

NO grid lines, NO cell frames, NO backgrounds, NO labels, NO text.

Test before delivering: cut the sheet into its three 128 x 128 cells, shrink each
to 36 x 36 pixels, and place them on a dark navy tile. The monkey must still read
as a monkey with two cymbals; the two grenades must read as grenades and must be
distinguishable from each other. If any becomes a blob, use fewer and thicker
shapes and try again.

Deliver as i_tod_hud_offhand_sheet.png.
```

## Prompt E — `i_tod_hud_digits.png` (1664 × 160) — THE NUMERALS

Attach `art_direction_board.png`, `house_style_points_icon.png` and the FINISHED
`i_tod_hud_weapon_panel.png` from Prompt A.

```text
Attached: an art direction board, a flat game HUD glyph showing the house drawing
style, and the panel these numerals are drawn on top of.

Draw a set of THIRTEEN numerals and marks as ONE sheet, in ONE ROW. This is a
custom typeface for a game HUD ammunition counter. It replaces a system font
entirely, so the thirteen must work as a family, not as thirteen drawings.
The single row is deliberate: it makes the shared baseline obvious.

Canvas exactly 1664 x 160 pixels, PNG, RGBA, fully transparent background.
A 13 column x 1 row grid, each cell exactly 128 x 160 pixels, butted directly
against each other with no gutters. Cell n starts at x = n x 128, counting from
zero.

THE THIRTEEN CELLS, left to right:

  0   1   2   3   4   5   6   7   8   9   /   +   -

THE DESIGN - a wide, bold, geometric technical numeral:
- Squarish and mechanical, built from straight lines and hard corners with only
  slight corner cuts - the look of a machine readout, not a handwriting face.
  Think of numerals on industrial equipment: confident, blocky, legible across a
  room.
- Stroke weight about 26 pixels, IDENTICAL in every glyph. This is the single
  most important consistency rule for a typeface.
- Cap height exactly 112 pixels in every cell, sitting on a common baseline at
  y = 136 within the canvas. Every digit the same height on the same line - if
  one digit is 4 pixels taller than another, the counter visibly wobbles as the
  number changes.
- Exactly TWO flat tones: a steel-white face (#E8EEF6) and one darker cool
  grey-blue used only as a hard-edged offset down and to the right, about 8
  pixels. Same offset direction and thickness in all thirteen.
- A crisp dark outline (#0A1020) about 8 pixels wide around each glyph.
- Counters - the enclosed holes in 0, 4, 6, 8, 9 - at least 20 pixels across at
  their narrowest. At the size this is shown, a thin counter fills in and an 8
  becomes a blob.
- Make 0, 6, 8 and 9 clearly distinguishable from each other, and 1 clearly
  distinguishable from 7. Give the 1 a full base serif so it is not a bare stem,
  and put a crossbar on the 7.
- NO slant, NO italic. Upright only.

WIDTH - this is a PROPORTIONAL face, not a monospace one. Draw each glyph at its
natural width and centre it horizontally in its cell:
- 1 is narrow, roughly 55 pixels wide
- 0 2 3 4 5 6 7 8 9 are wide, roughly 85 to 95 pixels
- / is narrow and steeply angled, roughly 55 pixels, and spans the full cap
  height
- + is a plain cross, roughly 70 pixels, and sits HIGHER than the digits -
  centred on the digits' upper half rather than on the baseline, because it is
  used as a prefix in small counts like "+3"
- - is a single horizontal bar, roughly 70 pixels wide, at the digits' mid
  height. It is NOT a hyphen in a word - it is the character shown in place of a
  number when the weapon has no magazine at all, so it must be as visually
  substantial as a digit and must not read as a stray line.
The game measures each glyph's actual ink width from your artwork and spaces them
accordingly, so natural widths are correct and welcome. What must NOT vary is the
cap height, the baseline, the stroke weight and the outline.

These are displayed up to 42 x 60 pixels - about a third of the cell.

NO grid lines, NO cell frames, NO backgrounds, NO labels, NO guide marks, NO
baseline rule drawn on the artwork.

Test before delivering: cut the sheet into its thirteen cells, shrink each to
42 x 60 pixels, and write out "1234567890", "32 / 240" and "- / -" with them on a
dark navy background. Every row must sit dead level with no glyph riding high or
low, every digit must be individually identifiable, and the counters in 0/6/8/9
must still be open holes.

Deliver as i_tod_hud_digits.png.
```

## Prompt F — `i_tod_hud_letters.png` (1200 × 224) — THE ALPHABET

Attach `art_direction_board.png`, `house_style_points_icon.png` and the FINISHED
`i_tod_hud_digits.png` from Prompt E.

```text
Attached: an art direction board, a flat game HUD glyph showing the house drawing
style, and the FINISHED numeral sheet from the previous step.

Draw a set of THIRTY letters and marks as ONE sheet: the uppercase alphabet for
the same custom HUD typeface. These letters and the numerals you just drew are
used TOGETHER in the same line of text - weapon names like "AK-47", "MP5" and
"SPAS-12" mix them - so they must be the SAME TYPEFACE. Match the attached
numeral sheet in construction logic, offset direction and relative stroke weight.

Canvas exactly 1200 x 224 pixels, PNG, RGBA, fully transparent background.
A 15 column x 2 row grid, each cell exactly 80 x 112 pixels, butted directly
against each other with no gutters. Cell (column, row) starts at
(column x 80, row x 112) counting from zero.

THE THIRTY CELLS, in reading order left-to-right then top-to-bottom:

  row 1:  A B C D E F G H I J K L M N O
  row 2:  P Q R S T U V W X Y Z - ' & .

THE DESIGN - the same wide, bold, geometric technical face as the numerals:
- Squarish and mechanical, straight lines and hard corners with only slight
  corner cuts. UPPERCASE ONLY - there are no lowercase letters in this set and
  none are needed; the game uppercases every string before drawing it.
- Stroke weight about 16 pixels, IDENTICAL in every glyph, and proportionally the
  same as the numerals' 26 pixels on their larger cell.
- Cap height exactly 74 pixels in every cell, sitting on a common baseline at
  y = 94 within each row. Every letter the same height on the same line.
- Exactly TWO flat tones: a steel-white face (#E8EEF6) and one darker cool
  grey-blue as a hard-edged offset down and right, about 5 pixels. Same direction
  as the numerals.
- A crisp dark outline (#0A1020) about 5 pixels wide around each glyph.
- Counters - the holes in A B D O P Q R - at least 12 pixels across at their
  narrowest.
- NO slant, NO italic. Upright only. No serifs except where noted below.

WIDTH - proportional, not monospace. Draw each letter at its natural width and
centre it horizontally in its cell:
- I is narrow, roughly 20 pixels. Give it top and bottom serifs so it is not a
  bare stem and cannot be confused with the numeral 1.
- M and W are wide, roughly 66 pixels
- most letters land between 42 and 56 pixels
- - (hyphen) is a short horizontal bar at mid height, roughly 34 pixels wide.
  Draw it NARROWER than the dash on the numeral sheet - that one is a standalone
  symbol, this one sits between letters in a word like "AK-47"
- ' (apostrophe) is a single short vertical mark at cap height, roughly 14 pixels
- & (ampersand) is roughly 58 pixels
- . (period) is a small square block on the baseline, roughly 18 pixels
The game measures each glyph's actual ink width from your artwork and spaces them
accordingly. What must NOT vary is the cap height, the baseline, the stroke
weight and the outline.

LEGIBILITY PAIRS - these must be clearly distinguishable at small size, so give
each a definite distinguishing feature: O and Q (Q needs a bold tail that breaks
the outline), C and G (G needs a strong horizontal crossbar), E and F, P and R,
U and V, M and N, and S against the numeral 5.

These are displayed up to 27 x 36 pixels and, for the longest weapon names, as
small as 14 x 18 pixels. That is the real test.

NO grid lines, NO cell frames, NO backgrounds, NO labels, NO guide marks, NO
baseline rule drawn on the artwork.

Test before delivering: cut the sheet into its thirty cells, shrink each to
27 x 36 pixels, and set these five REAL weapon names on a dark navy background,
mixing in the numerals from the previous sheet:

  AK-47
  STORMBREAKER EX
  RASPUTIN'S RETRIBUTION
  VOICE OF JUSTICE & RAGING JUDGE
  MP117 REDACTOR

Every line must sit dead level, every letter must be identifiable, and the
letters must look like they belong to the same family as the numerals inside
"AK-47" and "MP117". Then shrink the longest line to half that size and check it
still reads - the game does exactly that to make long names fit.

Deliver as i_tod_hud_letters.png.
```

## Delivery checklist

- [ ] Six files, named exactly `i_tod_hud_weapon_panel.png`,
      `i_tod_hud_gun_sheet.png`, `i_tod_hud_offhand_tile.png`,
      `i_tod_hud_offhand_sheet.png`, `i_tod_hud_digits.png`,
      `i_tod_hud_letters.png`
- [ ] Exact canvases: 1024×296, 1728×264, 276×192, 384×128, 1664×160, 1200×224 —
      all RGBA with a transparent background
- [ ] Every sheet is exactly its stated grid with **no gutters**, nothing
      crossing a cell boundary, and every cell filled in the listed order
- [ ] Digits: identical stroke weight, identical cap height, one common baseline,
      open counters. `+` sits high; `-` is substantial, not a stray line
- [ ] Letters: same typeface as the digits — same construction, same offset
      direction, proportionally the same stroke weight and outline
- [ ] Every piece downscaled to its on-screen size (384×111, 144×66, 69×48,
      36×36, 42×60, 27×36) and **looked at on a white background as well as a
      black one** — that is the only test that matters
- [ ] The twelve gun silhouettes laid in a row at 144 × 66 read as twelve
      different weapons AND as one set; cells 3 and 4 are distinguishable
- [ ] The five test strings in Prompt F set correctly and sit level
- [ ] The panel's four regions are visibly darker and calmer than everything
      around them, and its shadow does not extend past the top edge
- [ ] The tile still reads as a tile at 40% opacity on white

## Do NOT

- Do not deliver sheet cells as separate files. The sheet is the point — it is
  what makes the set consistent.
- Do not put grid lines, frames, gutters, labels, guide marks or backgrounds on
  any sheet.
- Do not bake any word, name, number or count into the panel or the tile. Every
  number and the weapon name are assembled at runtime from the glyph sheets.
- Do not draw lowercase letters. The game uppercases every string.
- Do not make the typeface monospace. Natural widths are measured from your
  artwork; forcing every glyph to one width wastes the band and looks wrong on
  short names.
- Do not use orange, red or green anywhere. Red is reserved for the game's own
  low-ammo warning flash on the numerals. The only warm colour in the pack is the
  cymbal monkey; the only violet is the web grenade.
- Do not add glow, bloom, lens flare, bevel, chrome, metal photo texture or scan
  lines.
- Do not draw a specific real-world weapon model. These are generic category
  silhouettes standing in for several guns each.
- Do not scale every weapon up to fill its cell — their relative sizes carry
  meaning.
- Do not add a compass, minimap, health bar, perk icons, crosshair, or any
  element that is not in the layout reference.
<!-- PACK:END -->

## The twelve categories, and which of this map's weapons each covers

The gun sheet is a CATEGORY set, not a per-gun set, and that is a deliberate
call. The roster is **24 ladder weapons** — 12 primaries and 12 sidearms, and
every sidearm is `inventoryType "primary"`, so the HUD's one `currentWeapon` lane
sees them identically. With the Death Machine powerup gift and the riot shield
that is ~26 silhouettes. Twenty-six bespoke icons is not a pack; it is a project,
and consistency across twenty-six generations is far worse than across twelve.
The weapon NAME immediately above the bay already says exactly which gun it is —
the silhouette only has to say what KIND.

| cell | category | covers |
|---|---|---|
| 1 | SMG | MAC-10, MP5, MP7 |
| 2 | ASSAULT RIFLE | Enfield, Krig 6, AK-47 |
| 3 | LMG | Stoner 63, HK21 |
| 4 | MINIGUN | Death Machine (heavy T3) + the Gift of Death powerup weapon |
| 5 | SHOTGUN | Bulldog, SG12, SPAS-12, MOG 12 |
| 6 | PISTOL | MR6 `pistol_standard` (start weapon, heavy T1 sidearm, last-stand pistol), Magnum, Executioner, UDM, RK 7, AMP63 |
| 7 | AKIMBO PISTOLS | `t9_amp63_rdw_up` "Tokyo & Rose", `t6_executioner_rdw_up` |
| 8 | LAUNCHER | RPG |
| 9 | NAIL GUN | `t9_nail_gun` (heavy T3 sidearm) |
| 10 | BLADE | Combat Knife, Wakizashi |
| 11 | AXE | Stormbreaker (the Leviathan port) |
| 12 | SHIELD | `zod_riotshield` / `log_riotshield_zm` (RIOT SHIELD domain, v16.63) |

**Cell 7 exists because four PaP forms are not the same silhouette as their
base.** `s1_bulldog_up` and `iw7_udm_up` use a different `gunModel` entirely, and
`t6_executioner_rdw_up_b_zm` and `t9_amp63_rdw_up_zm` carry `"dualWield" "1"` —
the PaP AMP63 is an akimbo pair. Without cell 7 those two would draw a single
pistol for a weapon the player is visibly holding two of.

Mapping lives in ONE place — `TOD_GUN_CAT` in `AetheriumLoadout.lua`, keyed on
the weapon stem and matched against `viewmodelWeaponName` after the axis suffix
is stripped, with the `_rdw`/`_ldw` test taking priority so an akimbo form cannot
fall through to its base category. A new gun is one row.

> **`riotshield_zm_icon` is already zoned** (`zone_source/zm_tower_of_doom.zone:970`)
> and already drawn on the left panel, so cell 12 is technically optional. It is
> in the set anyway: a stock icon next to eleven bespoke ones is exactly the
> inconsistency this pack exists to remove.

## The 60 shipped images

| from | cells | names |
|---|---|---|
| `i_tod_hud_weapon_panel` | — | itself |
| `i_tod_hud_offhand_tile` | — | itself |
| `i_tod_hud_gun_sheet` | 12 | `i_tod_hud_gun_smg` … `i_tod_hud_gun_shield` |
| `i_tod_hud_offhand_sheet` | 3 | `i_tod_hud_off_monkey`, `i_tod_hud_off_frag`, `i_tod_hud_off_web` |
| `i_tod_hud_digits` | 13 | `i_tod_hud_d0` … `i_tod_hud_d9`, `_dslash`, `_dplus`, `_ddash` |
| `i_tod_hud_letters` | 30 | `i_tod_hud_la` … `i_tod_hud_lz`, `_lhyphen`, `_lapos`, `_lamp`, `_ldot` |

Load RAM, uncompressed RGBA8 at `W×H×4`: panel 1.16 MB + tile 0.20 + guns 1.74 +
offhands 0.19 + digits 1.02 + letters 1.03 = **≈ 5.34 MB**, against ≈1.60 MB of
kit art retired — **net ≈ +3.7 MB**, about one upgrade card. Worth re-checking
against the `docs/86_xpak_size.md` posture at publish.

## Install (when the drop lands)

1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'`, then **LOOK at all
   six**. For the sheets run `node tools/slice_hud_sheets.js --check` first — it
   verifies each canvas size and reports every cell's alpha bounding box, so a
   drawing that crosses a cell boundary, a glyph off its baseline, or a wrong
   canvas size is caught before anything is installed.
2. `node tools/slice_hud_sheets.js` cuts the four sheets into the 58 cell images,
   writes them into `source_data/tod_ui_images/_images/`, and **emits the derived
   advance-width table** to
   `ui/uieditor/widgets/HUD/AetheriumWidgets/TodGlyphMetrics.lua`.
3. All 60 names are NEW, so all three wiring lanes are needed for each:
   - a GDT block per image in `source_data/tod_ui_images.gdt` — clone an existing
     `i_tod_hud_*` block verbatim (`compressionMethod "uncompressed"`,
     `colorSRGB 1`, `coreSemantic sRGB3chAlpha`, `noPicMip 1`)
   - an `image,` line each in `zone_source/zm_tower_of_doom.zone` — without it the
     linker is silent and the game draws a WHITE SQUARE
     (`tools/lint_tod_assets.js` GATE A catches this)
   - the `RegisterImage` names in `AetheriumLoadout.lua` (already written — they
     resolve to `blacktransparent` until the images exist)

   `slice_hud_sheets.js --wire` writes the GDT blocks and zone lines for all 60.
4. **FULL build** (a GDT edit is always a full build). Proof = a fresh
   content-hash `.iwi` for each of the 60 beside an untouched control, per the
   verify-assets-in-artifacts rule.

## States the rebuild must render, and what each shows

Enumerated because an unhandled state is how a HUD ships a permanent zero.

| state | gun bay | clip | reserve | offhands |
|---|---|---|---|---|
| normal firearm | its category | number | number | live |
| **melee (SLASHER, all 3 tiers)** | blade / axe | **`-`** | **`-`** | live |
| **riot shield equipped** | shield | **`-`** | **`-`** | live |
| dual-wield PaP (`_rdw`/`_ldw`) | akimbo | clip × 2 | number | live |
| Death Machine powerup | minigun | number | up to 4 digits | live |
| offhand count 0 | — | — | — | tile at α 0.40 |
| last stand | pistol | number | number | live |
| class-select draft (first 30 s) | cold-start: pistol | `-` | `-` | hidden |
| card deal / solo station freeze | unchanged, live | unchanged | unchanged | unchanged |

**Reloading has no data channel** — the only weapon models any Lua in `ui/` reads
are `aatIcon`, `ammoInClip`, `ammoStock`, `maxAmmoInClip`, `viewmodelWeaponName`
and `weaponName`. There is no reload or weapon-state model, and the
clientuimodel pool is at its proven 61-bit ceiling, so a reload indicator would
cost a new clientfield. Not promised, and not in this pack.

## Open decisions this pack does NOT make

1. **A TIER CHIP.** The map's progression is 4 classes × 3 tiers and the HUD
   never says which tier you are on. The data path exists and works
   (`CoD.TodOwned` survives the per-life menu rebuild; `refresh_upgrade_list`
   pushes the tier row every spawn). Deliberately cut — it was not asked for, it
   is the one element that could render a *wrong* value rather than a blank one,
   and with the typeface in scope the pack is already at six files. Worth a
   follow-on with its own doc.
2. **The party-member plate**, still carried over from docs/89's open list.
3. **`MagChip` must be deleted, not ignored.** `tod_upgrade.lua:3294-3295` puts it
   at canvas x950..1100, y668..690 — overlapping the new panel's reserve row — in
   the menu that draws on top. It is dead (`set_mag_bonus` has zero call sites)
   but it is still drawn.
