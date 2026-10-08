# 98 — GUN HUD: one picture per gun (ONE sheet, 20 cells)

<!-- art-pack
name: gun_hud_per_gun
refs:
  docs/98_hud_ref/what_is_shared.png | THE WHOLE BRIEF IN ONE PICTURE: the six cells that today stand in for twenty different guns, the eight cells that are already one gun each (unchanged), and the target 5x4 sheet with every cell numbered and named. Attach to every prompt.
  docs/98_hud_ref/i_tod_hud_gun_sheet.png | THE SHIPPED WEAPON SHEET - the style you are matching, exactly. NOT a deliverable: do not redraw it, do not resize it, do not send it back. Attach to every prompt.
  docs/98_hud_ref/i_tod_hud_gun_katana.png | a shipped single cell (the wakizashi) - shows how one drawing sits in one 288x132 cell. NOT a deliverable. Attach to every prompt.
  docs/98_hud_ref/i_tod_hud_gun_gift.png | a shipped single cell (the Gift of Death) - the most detailed cell in the set, the ceiling for interior detail. NOT a deliverable. Attach to every prompt.
  docs/98_hud_ref/art_direction_board.png | the art direction: palette, the six rules, the good and bad examples. Unchanged, still governs. Attach to every prompt.
preview: 144x66
-->

> **STATUS: SHIPPED v17.40 (2026-09-04).** The drop came back the same evening
> (`files - 2026-09-04T172124.702.zip`) as ONE sheet at exactly 1440×528, all
> twenty cells in order. Installed per the "Install" section below; the six
> category cells are retired whole. UNPLAYED as of the build.

## Why (user, 2026-09-04)

*"One issue we see is that the HUD gun white icons are not matching with the
actual gun or we are missing some icons ... the RPK and the Stoner have the same
image. That should not be the case."*

There is no RPK in this map; the heavy's tier-2 gun is the **HK21**, and it
shares its picture with the tier-1 **Stoner 63** — which is exactly the report.
That is not a bug in the lookup. It is the DESIGN of the shipped set, and the
design is what the user is rejecting.

## The audit — what the icon lane actually does today

The resolver in `AetheriumLoadout.lua` (`todApplyWeapon`) turns the held weapon
into a CATEGORY and draws `i_tod_hud_gun_<category>`. Fourteen cells ship. The
map sells 26 silhouettes' worth of weapons. The arithmetic:

| cell | drawn for | how many guns look identical |
|---|---|---|
| `smg` | MAC-10, MP5, MP7 | 3 — the whole skirmisher ladder |
| `rifle` | Enfield, Krig 6, AK-47 | 3 — the whole assault ladder |
| `lmg` | Stoner 63, HK21 | 2 — the heavy's T1→T2 promotion is invisible |
| `shotgun` | Bulldog, SG12, SPAS-12, MOG 12 | 4 |
| `pistol` | MR6, Magnum, Executioner, AMP63, UDM 45, RK7 Garrison | 6 |
| `akimbo` | PaP Executioner pair, PaP AMP63 pair | 2 |
| `minigun` `launcher` `nailgun` `blade` `katana` `axe` `shield` `gift` | one weapon each | already right |

So **20 weapons share 6 pictures** and 8 are already one-to-one. Nothing is
*missing* in the sense of an unmapped weapon: every one of the 44 GDT display
names plus the four install-side ones (MR6 / Death & Taxes / AMP63 / Tokyo &
Rose) resolves to a cell, and every cell has a zone line and a converted `.iwi`.
The wrong-picture cases the previous packs fixed (gift drawn as a minigun,
wakizashi drawn as the knife) were the same disease at a smaller dose — the
category set was always going to be too coarse for a game whose whole upgrade
loop is "the gun in your hands changes".

**Why the pistol cell hurts most:** the cold-start default of the resolver is
also `pistol`, so a resolver failure and "you are holding one of six handguns"
draw the same thing. A per-gun set makes the default distinguishable for free.

The one thing this pack does NOT settle: whether the `viewmodelWeaponName` lane
or the `weaponName` lane is the one resolving in the running build (memory
`viewmodel-weapon-name-unproven`). The user's report — two LMGs drawing the LMG
cell — is the first evidence from play that the icon MOVES at all since v17.14,
which is consistent with v17.23's restored second feed. It is not proof of which
lane; `TOD_HUD_DEBUG` still is.

## Design decisions in this pack

- **ONE new sheet, not 20 files, not a grown sheet.** docs/96 asked the shipped
  sheet to GROW and the generator returned it at the old size; docs/97 asked for
  single files and got them. A FRESH sheet at a stated size is the v1 case,
  which came back correct. Twenty separately-generated silhouettes would come
  back with twenty stroke weights; one sheet cannot. The fallback is stated in
  the brief: if the canvas size cannot be hit, deliver 20 single 288×132 files
  with the listed names.
- **The eight unique cells stay.** They are in the style already and redrawing
  them risks the drift this whole pack exists to avoid.
- **Muzzle LEFT, side profile, cell order = class ladders.** Same conventions as
  the shipped sheet, so a player who reads the HUD across a promotion sees a gun
  of the same family get bigger, not flip direction.
- **On-screen size is 144 × 66** (96 × 44 canvas units × 1.5 for 1080p).
  CORRECTED 2026-09-04 evening: this doc and docs/99 went out saying 166 × 76 on
  the belief that the loadout sat under `TodScaleHud` 1.15 — it does not any
  more (`AetheriumHud.lua`: "AetheriumLoadout dropped"), and docs/97's 144 × 66
  was right all along. The two packs were judged at a size 15% too large; the
  direction of every note still holds, the threshold is just slightly stricter.

## Install (when the drop lands)

1. `.\tools\make_art_pack.ps1 -Inspect 'files (N).zip'` — LOOK at every cell.
2. Copy the sheet to `source_data/tod_ui_images/_sheets/i_tod_hud_gun_sheet2.png`
   (the MASTERS folder — `_images/` holds only the cut cells; the slicer reads
   masters with `--src source_data/tod_ui_images/_sheets`).
3. Add a `SHEETS` row to `tools/slice_hud_sheets.js`:
   `file: 'i_tod_hud_gun_sheet2.png', w: 1440, h: 528, cw: 288, ch: 132, cols: 5, rows: 4`
   with `names` = `i_tod_hud_gun_` + `mac10 mp5 mp7 enfield krig6 / ak47 stoner63
   hk21 bulldog sg12 / spas12 magnum mog12 executioner mr6 / amp63 udm rk7
   executioner_akimbo amp63_akimbo`. Run `--check`, then slice, then `--wire`
   for the 20 GDT blocks + zone lines.
4. In `AetheriumLoadout.lua`, `TOD_NAME_CAT` and `TOD_GUN_CAT` change VALUE only:
   the six shared categories become per-gun slugs (`"STONER 63"`/`"PSYCHOTROPIC
   THUNDER"` → `stoner63`, `"HK21"`/`"H115 OSCILLATOR"` → `hk21`, the akimbo PaP
   names → `executioner_akimbo`/`amp63_akimbo`, `"MR6"`/`"DEATH & TAXES"` → `mr6`
   and the cold-start default → `mr6`). `TOD_NO_MAG` is keyed on the unchanged
   melee slugs and needs nothing. The six retired category images and their
   zone lines + GDT blocks go in the SAME change (retire a thing whole — GATE B).
5. FULL build; proof = 20 fresh content-hash `.iwi` beside an untouched control.
   Flip this STATUS to SHIPPED with the version.

<!-- PACK:BEGIN -->
# GUN HUD — one picture per gun (ONE sheet, 20 cells)

## Start here

**Open `what_is_shared.png` first.** It is the entire brief in one picture. It
shows, at the exact size the player sees them: the six weapon icons that today
have to stand in for twenty different guns, the eight icons that are already
correct and stay untouched, and the empty 5 × 4 sheet you are filling, with
every cell numbered and named.

**The style is already decided and it is attached.** `i_tod_hud_gun_sheet.png`,
`i_tod_hud_gun_katana.png` and `i_tod_hud_gun_gift.png` are what ships today.
The twenty new drawings must look like they were drawn in the same pass by the
same hand. Do not redraw, resize or re-send any of those three files.

## Deliver exactly ONE file

| file | size | contents |
|---|---|---|
| `i_tod_hud_gun_sheet2.png` | **1440 × 528** px, PNG, RGBA, transparent background | 5 columns × 4 rows of **288 × 132** cells, twenty weapon silhouettes, one per cell, in the order below |

The cell grid is arithmetic, not vision: the sheet is cut into cells by
position, so the canvas must be **exactly** 1440 × 528 and every drawing must
stay inside its own 288 × 132 cell with transparent margin all round — nothing
touching a cell edge, nothing crossing into a neighbour. Do not draw grid lines.

**If you cannot produce a canvas of exactly that size**, deliver twenty single
files instead, each exactly 288 × 132, named `i_tod_hud_gun_<slug>.png` with the
slugs from the table. Do not deliver a sheet of a different size.

## The twenty cells, in reading order (left to right, then the next row)

Every weapon: side profile, **muzzle pointing LEFT**, centred in its cell,
drawn to fill roughly the same height as the neighbouring cells on the shipped
sheet. The "tell" column is the one feature that makes that gun THAT gun; at
144 × 66 pixels on screen it is the only detail the player will see, so it must
be the biggest thing in the drawing.

| # | slug | gun | tell |
|---|---|---|---|
| 1 | `mac10` | MAC-10 | short boxy receiver, **magazine goes down through the pistol grip**, stubby barrel |
| 2 | `mp5` | MP5 | slim; **curved magazine ahead of the grip**; long slender fore-end; fixed stock |
| 3 | `mp7` | MP7 | tiny; **magazine in the grip** AND a **folding front grip** under a very short barrel; stock extended |
| 4 | `enfield` | Enfield (L85) | **BULLPUP** — the magazine is BEHIND the pistol grip; a carry-handle sight on top; short overall |
| 5 | `krig6` | Krig 6 | conventional assault rifle; curved magazine ahead of the grip; skeleton folding stock; long handguard |
| 6 | `ak47` | AK-47 | the **banana** magazine, deeply curved; a **gas tube above the barrel**; a solid wooden stock and handguard (draw the wood in the darker tone) |
| 7 | `stoner63` | Stoner 63 | **belt-fed light machine gun**: a squared ammo box under the receiver, a carry handle on top, a **bipod** folded under the barrel, tubular stock |
| 8 | `hk21` | HK21 | **long and slim** machine gun: a round drum feed under the receiver, slotted handguard, bipod, a rifle-style stock — must look LONGER and THINNER than cell 7 |
| 9 | `bulldog` | Bulldog | **BULLPUP auto shotgun**: fat barrel shroud, magazine BEHIND the grip, very short overall |
| 10 | `sg12` | SG12 | auto shotgun with a **box magazine** ahead of the grip and a wide muzzle — shaped like a rifle that fires shells |
| 11 | `spas12` | SPAS-12 | pump shotgun with a **tube magazine under the barrel** and the famous **hook stock folded over the top** of the receiver |
| 12 | `magnum` | Magnum | a **big revolver** with a **long barrel** and a large exposed cylinder; classic hunting-revolver silhouette |
| 13 | `mog12` | MOG 12 | pump shotgun: **tube magazine under a short barrel**, a pump fore-end, a traditional shoulder stock — must NOT have the hook stock of cell 11 |
| 14 | `executioner` | Executioner | a **snub revolver with an oversized cylinder** — the cylinder is almost as tall as the whole gun; barrel very short |
| 15 | `mr6` | MR6 | a plain **modern polymer service pistol**: slab-sided slide, squared trigger guard, no revolver cylinder |
| 16 | `amp63` | AMP63 | a **machine pistol**: pistol shape with a **long stick magazine** hanging well below the grip and a squared compensator at the muzzle |
| 17 | `udm` | UDM 45 | a **blocky, futuristic machine pistol**: thick angular slide, wide magazine, hard planes — looks like science-fiction next to cell 15 |
| 18 | `rk7` | RK7 Garrison | a **slim futuristic burst pistol**: long thin slide, angular, a small forward compensator — thinner than cell 17 |
| 19 | `executioner_akimbo` | two Executioners | **two of cell 14**, one slightly behind and to the right of the other, overlapping, both muzzles left — the same treatment as the AKIMBO cell on the shipped sheet |
| 20 | `amp63_akimbo` | two AMP63s | **two of cell 16**, same overlapping treatment as cell 19 |

Three groups must read as a LADDER on screen, because the player upgrades
along them: 1 → 2 → 3, 4 → 5 → 6, 7 → 8. Each step should look like a bigger,
more serious gun of the same family, and every step must be obviously a
different gun from the last at 144 × 66 pixels. Put cells 7 and 8 side by side
at that size before delivering: if a player cannot tell them apart in one
glance, cell 8 needs to be longer and thinner than it is.

## The style you are matching

From the art direction board and the attached sheet:

- Flat vector art. **No** 3D, bevel, gloss, gradient ramp, cast shadow or texture.
- Exactly **two flat tones**: a steel-white face `#E8EEF6` and one darker cool
  grey-blue (sample it from the attached sheet), the darker one used for the
  hard-edged offset and for interior structure — magazine, grip, stock, bipod.
- A crisp dark outline `#0A1020` around the whole silhouette, about **7 px** on
  the 288 × 132 cell.
- The **same offset direction** as every existing cell (down and to the right).
- Nothing narrower than 10 px on the 288 × 132 cell — it is shown at a bit over
  half size and thinner strokes vanish.
- No text, no numbers, no labels anywhere in the image.

The Gift of Death cell (`i_tod_hud_gun_gift.png`) is the most detailed cell in
the shipped set. That is the ceiling for interior detail — never more than that.

## The prompt (one pass, all twenty cells)

Attach `what_is_shared.png`, `i_tod_hud_gun_sheet.png`, `i_tod_hud_gun_katana.png`,
`i_tod_hud_gun_gift.png` and `art_direction_board.png`.

```text
Attached: a brief showing the HUD weapon icons that exist in this game, the
sheet of weapon icons that already ships (the style), two more shipped cells at
single-cell size, and the art direction.

Draw ONE sheet of TWENTY weapon silhouettes to join that set.

Canvas exactly 1440 x 528 pixels, PNG, RGBA, fully transparent background. It is
a grid of 5 columns x 4 rows of cells, each cell exactly 288 x 132 pixels. Draw
NO grid lines. One weapon per cell, centred in its cell, with transparent margin
all round - no drawing touches a cell edge or crosses into a neighbour. Each
cell is shown in the game at about 144 x 66 pixels, a bit over half size.

Every weapon: side profile, muzzle pointing LEFT, drawn to about the same height
as the weapons on the attached sheet.

Reading order, left to right then the next row:
 1 MAC-10       - boxy SMG, the magazine goes down THROUGH the pistol grip
 2 MP5          - slim SMG, CURVED magazine ahead of the grip, long thin fore-end
 3 MP7          - tiny PDW, magazine in the grip AND a folding front grip
 4 Enfield      - BULLPUP rifle: magazine BEHIND the grip, carry-handle sight on top
 5 Krig 6       - conventional assault rifle, curved magazine, skeleton stock
 6 AK-47        - deeply curved banana magazine, gas tube over the barrel, wood
                  stock and handguard in the darker tone
 7 Stoner 63    - belt-fed machine gun: squared ammo box under, carry handle on
                  top, bipod under the barrel, tubular stock
 8 HK21         - LONG, SLIM machine gun: round drum feed under, slotted
                  handguard, bipod, rifle stock. Must look longer and thinner
                  than cell 7.
 9 Bulldog      - BULLPUP auto shotgun, fat barrel shroud, magazine behind the grip
10 SG12         - auto shotgun with a BOX magazine ahead of the grip, wide muzzle
11 SPAS-12      - pump shotgun, tube magazine under the barrel, hook stock
                  FOLDED OVER THE TOP of the receiver
12 Magnum       - big revolver, LONG barrel, large exposed cylinder
13 MOG 12       - pump shotgun, tube under a SHORT barrel, traditional shoulder
                  stock (no hook stock)
14 Executioner  - snub revolver with an OVERSIZED cylinder, very short barrel
15 MR6          - plain modern polymer pistol, slab-sided slide
16 AMP63        - machine pistol: pistol with a LONG stick magazine hanging well
                  below the grip and a squared compensator
17 UDM 45       - blocky FUTURISTIC machine pistol, thick angular slide, wide mag
18 RK7 Garrison - slim FUTURISTIC burst pistol, long thin slide, small compensator
19 Executioner x2 - two of cell 14, overlapping, one slightly behind and to the
                  right of the other, both muzzles left - same treatment as the
                  dual-pistol cell on the attached sheet
20 AMP63 x2     - two of cell 16, same overlapping treatment

Cells 1-2-3, 4-5-6 and 7-8 are upgrade ladders: each step is a bigger, more
serious gun of the same family, and every step must be an OBVIOUSLY different
gun from the one before at 144 x 66 pixels.

Style, matching the attached sheet exactly: flat vector, no 3D, no gradient, no
gloss, no shadow. Two flat tones only - steel-white face #E8EEF6 and one darker
cool grey-blue for the offset and the interior parts (magazine, grip, stock,
bipod). Hard dark outline #0A1020 about 7 pixels wide around each silhouette.
Offset down and to the right like every existing cell. Nothing narrower than 10
pixels. No text anywhere.

The attached Gift of Death cell is the most detailed drawing in the set; do not
exceed that level of detail.

Deliver as i_tod_hud_gun_sheet2.png, exactly 1440 x 528.
```

## Delivery checklist

- [ ] ONE file, `i_tod_hud_gun_sheet2.png`, **exactly 1440 × 528**, RGBA, transparent
- [ ] twenty drawings, one per 288 × 132 cell, in the listed order, none touching a cell edge
- [ ] every muzzle points LEFT
- [ ] cells 7 and 8 tell apart at 144 × 66 (put them side by side and check)
- [ ] cells 4 and 9 read as bullpups (magazine BEHIND the grip)
- [ ] cells 19 and 20 are two overlapping copies of cells 14 and 16
- [ ] two flat tones + the dark outline, offset down-right, no gradient, no text

## Do NOT

- do not redraw, resize or re-send `i_tod_hud_gun_sheet.png`, the katana or the gift cell
- do not deliver the sheet at any size other than 1440 × 528 (single 288 × 132 files are the only alternative)
- do not add grid lines, cell borders, labels, numbers or names to the image
- do not add colour — every weapon is the same steel-white two-tone
- do not exceed the Gift of Death cell's level of detail
<!-- PACK:END -->
