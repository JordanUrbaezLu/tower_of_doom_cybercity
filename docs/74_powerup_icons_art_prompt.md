# 74 — POWER-UP HUD ICONS: the 8 live icons re-baked at 256, one recipe, Insta-Kill loses its "x3" (8 images)

<!-- art-pack
name: powerup_icons
refs:
  i_tod_pu2_insta.png | INSTA-KILL, current: white skull over a crescent with a gold "x3" coin. The "x3" coin must GO - the power-up is a one-hit kill now and the number is wrong.
  i_tod_pu2_double_points.png | DOUBLE POINTS, current: the polish benchmark of the set (gold coin, "x2"). Keep its "x2"; every other icon must match this finish.
  i_tod_pu2_gift_of_death.png | GIFT OF DEATH (the Death Machine drop), current: magenta gift box with a tiny skull tag that vanishes at HUD size.
  i_tod_pu2_max_ammo.png | MAX AMMO, current: navy crate with a few rounds - reads as a plain box at HUD size.
  i_tod_pu2_nuke.png | NUKE, current: flat orange mushroom cloud.
  i_tod_pu2_timewarp.png | TIME WARP, current: hourglass with thin arc arrows.
  i_tod_pu2_infinite_ammo.png | INFINITE AMMO, current: gold infinity sign with a bullet that clips the canvas edge.
  i_tod_pu2_zombie_blood.png | ZOMBIE BLOOD, current: red drop with an eye too small to read.
preview: 49x49
-->

> **STATUS: SHIPPED v16.49, 2026-09-02 — UNPLAYED.** Pack built by
> `.\tools\make_art_pack.ps1 docs\74_powerup_icons_art_prompt.md` →
> `~/Downloads/tod_powerup_icons_art_pack.zip`; the drop came back within the
> hour as `files - 2026-09-02T175849.836.zip` (a contact sheet + a loose nuke +
> a nested zip with all eight and the generator's `build_powerups.py` /
> `_v2.py`; the loose and nested nuke are pixel-identical). Verified via
> `-Inspect` + System.Drawing: all eight 256×256 RGBA; alpha bounding boxes
> give margins 14–26 px on every side and fills 80–89 % (infinite_ammo 69 %
> tall — an infinity sign is wide), so the set draws at one apparent size; a
> 49×49 tray strip of all eight reads at a glance; **Insta has no text**,
> double_points keeps `x2`. Installed under the same names (128 → 256, no
> wiring), FULL build 18:04:52; proof = eight NEW content-hash `.iwi` @
> 18:04:40 beside the untouched `i_tod_pu2_fire_sale` control, and the deps
> manifest lists exactly those eight. Record: CHANGELOG v16.49.

**Why (user, 2026-09-02):** *"I want to enhance the powerup icons that show on
the HUD ... also instakill does not do X3 anymore so lets make sure that gets
removed."*

**Where they draw.** `AetheriumPowerupsContainer.lua` renders the active
power-up tray as 49×49 `AetheriumPowerupItem` tiles on the 1280×720 virtual
canvas (×`TOD_HUD_SCALE`), and `AetheriumPowerupNotification.lua` shows the
pickup icon at 66×67 beside the name. At 1080p that is ~74 px, at 1440p ~98 px,
at 4K ~147 px — the shipped 128×128 sources are UPSCALED above 1080p
(docs/63 §7). **Deliver 256×256.** The GDT image blocks carry no dimensions,
so a same-name 256 replaces a 128 with no wiring.

**The Insta-Kill "x3" (the fact, from the code).** `_tod_powerups.gsc` still
carries the v6 `instakill_3x_override`, but v14.x made Insta-Kill a TRUE
ONE-HIT on regular zombies (docs/67 "Insta-Kill is now a true one-hit on
regular zombies (Armored Sprinters included); bosses and elites keep the 3x
damage instead"). The icon's "x3" coin describes a rule regular zombies no
longer follow, and no other HUD lane says "x3" (the pickup notification's
name is stock's localized string; the 3X announce was removed 2026-08-20).
The icon is the only carrier, so this pack removes it. docs/63 batch 8's
"Insta keeps its baked x3" is superseded here. **No gameplay change.**

**Scope: the 8 LIVE icons only.** `fire_sale` (needs a mystery box),
`carpenter` (needs barricades) and `free_pap` (instant, never in the timed
tray) cannot show — docs/63: "keep the rows, spend no art".

<!-- PACK:BEGIN -->
# POWER-UP HUD ICONS — 8 icons, one recipe, at 256 × 256

## What this is

Eight Black Ops 3 zombies HUD power-up icons. They appear in a row of small
tiles while a power-up is active (about **49 × 49 on a 1280 × 720 layout**,
so ~74 px at 1080p and ~98 px at 1440p) and, larger, in the pickup banner.
Look at `preview_onscreen_49x49/` — that is the size the player reads them at.

The current set is 128 × 128 and inconsistent: four icons touch the canvas
edge, they fill anywhere from 69% to 95% of the canvas so they draw at
different apparent sizes, several are flat single fills while one
(`double_points`) is fully rendered, and small details (a skull tag, an eye,
thin arrows) vanish at HUD size. **Re-bake all eight at 256 × 256 with ONE
recipe, at the finish of the current `double_points` icon.**

**Deliver exactly EIGHT files:**

| Deliver as | Depicts | Text on the icon |
|---|---|---|
| `i_tod_pu2_insta.png` | INSTA-KILL: white skull (crescent behind it, as now) | **NONE — remove the "x3" coin** |
| `i_tod_pu2_double_points.png` | DOUBLE POINTS: gold coin | `x2` only, as now |
| `i_tod_pu2_gift_of_death.png` | GIFT OF DEATH: gift box with a LARGE menacing skull on it | none |
| `i_tod_pu2_max_ammo.png` | MAX AMMO: olive/steel ammo crate with fewer, bolder rounds standing in it | none |
| `i_tod_pu2_nuke.png` | NUKE: mushroom cloud with layered lobes and a hot core | none |
| `i_tod_pu2_timewarp.png` | TIME WARP: hourglass with a glass highlight, a sand stream, thick arc arrows | none |
| `i_tod_pu2_infinite_ammo.png` | INFINITE AMMO: infinity sign with the bullet fully inside the canvas | none |
| `i_tod_pu2_zombie_blood.png` | ZOMBIE BLOOD: blood drop with a LARGE eye, white sclera, red iris | none |

Keep each icon's colour identity so a player who knows the old set still
recognises it at a glance: skull white / coin gold / gift magenta-red with a
violet ribbon / crate olive-steel with brass rounds / nuke orange / hourglass
cyan glass with orange arrows / infinity gold / blood red.

## References (in `reference/`)

The eight CURRENT icons at 128 × 128. `i_tod_pu2_double_points.png` is the
**finish benchmark**: rendered coin, top-left highlight, bottom-right shade,
thin inner rim light, heavy dark outline. Match every icon to that finish.
Attach the benchmark to every prompt, and the icon being redrawn to its own
build-out prompt.

## Hard rules (the ONE recipe)

- Canvas exactly **256 × 256**, PNG, RGBA, fully transparent background.
  Flat vector-clean game-UI art: crisp edges, no photographic texture, no
  noise, no grain.
- **Same size on screen for all eight:** the silhouette is centred in a
  uniform safe box of about **80% of the canvas (≈205 px)** with a minimum
  **16 px margin** on every side. Nothing touches the edge.
- **Identical outline weight:** a heavy near-black outline about **10 px** at
  256 around the whole silhouette, plus a thin **4–6 px dark halo** outside it
  so the icon stays legible over bright gameplay. The `double_points`
  reference shows the weight.
- **Identical lighting:** soft top-left highlight, bottom-right shade, a thin
  inner rim light along the top edges. No purple bloom, no outer glow, no drop
  shadow beyond the halo.
- **One bold silhouette per icon** that still reads at 49 × 49. No detail
  thinner than ~8 px at 256. Test each icon by downscaling it to 49 × 49 and
  asking whether it is still obviously that power-up.
- **Text:** only `double_points` carries text (`x2`, as now, in the same coin
  style). Every other icon, **Insta-Kill included**, carries NO letters or
  numbers.

## Per-icon notes

- **insta** — keep the skull-and-crescent idea; delete the gold `x3` coin and
  let the skull grow into the space it occupied. Bigger eye sockets, a clean
  jaw with four teeth, no smaller.
- **double_points** — the benchmark; rebuild at 256 with the same look.
- **gift_of_death** — the skull tag on top is unreadable; put a LARGE skull on
  the front face of the box instead, ribbon behind it.
- **max_ammo** — an olive/steel crate (not navy) with 3 bold brass rounds
  standing in it; the crate must read as ammunition, not a suitcase.
- **nuke** — two or three layered cloud lobes with a hot yellow-white core in
  the cap and a thick stem; keep the orange.
- **timewarp** — thicker arc arrows (at least 14 px at 256), a glass highlight
  on the upper bulb, a visible sand stream between the bulbs.
- **infinite_ammo** — recentre; the bullet sits fully inside the margin.
- **zombie_blood** — enlarge the eye to roughly half the drop's width, white
  sclera, red iris, dark pupil; the two side droplets can go if they crowd it.

## Prompt 1 — EXPLORE (one contact sheet)

Attach ALL EIGHT current icons.

```text
Attached are eight Black Ops 3 zombies HUD power-up icons at 128 x 128. They are
inconsistent: different sizes, different finishes, small details that vanish at
HUD size. Redraw all eight as ONE consistent set and show them on a single
2 x 4 contact sheet, each icon drawn at 256 x 256 on a mid-grey background so
the outline and halo can be judged.

The finish benchmark is the gold "x2" coin icon (double_points): rendered
surfaces, soft top-left highlight, bottom-right shade, thin inner rim light,
heavy near-black outline. Match every icon to that finish. Flat vector-clean
game-UI art, crisp edges, no photographic texture, no noise.

ONE recipe for all eight:
- silhouette centred in a uniform safe box about 80% of the canvas, at least
  16 px margin on every side, nothing touching the edge
- heavy near-black outline about 10 px, plus a thin 4 to 6 px dark halo outside
  it for contrast over gameplay
- one bold silhouette per icon, no detail thinner than about 8 px, so each
  still reads when shrunk to 49 x 49
- no outer glow, no purple bloom, no drop shadow beyond the halo

The eight, keeping each one's colour identity:
1. INSTA-KILL: white skull over a crescent. NO "x3" coin, NO text of any kind -
   the skull grows into that space. Bigger eye sockets, clean four-tooth jaw.
2. DOUBLE POINTS: the gold coin with "x2" - keep it, this is the benchmark.
3. GIFT OF DEATH: magenta-red gift box, violet ribbon, a LARGE menacing skull on
   the front face of the box.
4. MAX AMMO: olive/steel ammo crate with three bold brass rounds standing in it.
5. NUKE: orange mushroom cloud, two or three layered lobes, a hot yellow-white
   core in the cap, thick stem.
6. TIME WARP: hourglass with cyan glass, a glass highlight on the upper bulb, a
   visible sand stream, thick orange arc arrows around it.
7. INFINITE AMMO: gold infinity sign with a bullet, everything fully inside the
   margin.
8. ZOMBIE BLOOD: red blood drop with a LARGE eye - white sclera, red iris, dark
   pupil - about half the drop's width.

Only DOUBLE POINTS carries text. Label each tile on the sheet with its name
underneath, outside the icon.
```

## Prompt 2 — BUILD-OUT (run once per icon, eight times)

Attach the approved contact sheet AND the current icon being replaced. Fill in
the name and the description line from the table above.

```text
Attached: a contact sheet showing an approved set of eight Black Ops 3 zombies
HUD power-up icons, and the old version of one of them. Produce the final
<NAME> icon from the sheet as a standalone file.

Canvas exactly 256 x 256 pixels, PNG, fully transparent background (RGBA).
Flat vector-clean game-UI art, crisp edges, no photographic texture, no noise.

Reproduce the <NAME> tile from the sheet exactly - same silhouette, colours,
finish, outline weight and halo - centred in a safe box of about 80% of the
canvas with at least 16 px of transparent margin on every side. Nothing touches
the edge. Heavy near-black outline about 10 px plus a 4 to 6 px dark halo. Soft
top-left highlight, bottom-right shade, thin inner rim light. No outer glow, no
drop shadow beyond the halo. <TEXT RULE: "No letters or numbers anywhere on the
icon." / for double_points: "The only text is x2, in the coin style shown.">

It must still read as <NAME> when shrunk to 49 x 49. Deliver as <FILE>.
```

## Delivery checklist

- [ ] Eight files with exactly the names in the table, 256 × 256, RGBA,
      transparent background
- [ ] `i_tod_pu2_insta.png` has NO "x3" and no text; `i_tod_pu2_double_points.png`
      keeps `x2`; no other icon has text
- [ ] Every icon fills about the same 80% box with ≥ 16 px margin; none touches
      the edge
- [ ] Same outline weight and halo on all eight
- [ ] Each one downscaled to 49 × 49 is still obviously that power-up

## Do NOT

- Do not put "x3" (or any number or word) on Insta-Kill.
- Do not add text to any icon other than the `x2` on Double Points.
- Do not change an icon's colour identity or swap its subject.
- Do not let any icon touch or clip the canvas edge, or draw the set at
  different sizes.
- Do not add glows, blooms, or drop shadows beyond the thin dark halo.
- Do not deliver 128 × 128; the set is 256 × 256.
<!-- PACK:END -->

## Install (when the drop lands)

1. `.\tools\make_art_pack.ps1 -Inspect '<drop zip>'` — headers (256×256, RGBA),
   md5 vs the repo copies. LOOK at all eight; confirm Insta has no `x3`; check
   the 49×49 read; check margins by eye on a contact sheet.
2. Copy the eight over `source_data/tod_ui_images/_images/` (same names; the
   GDT blocks carry no dimensions, so 128→256 needs no wiring).
3. FULL build. Proof: eight fresh content-hash `.iwi` with fresh mtimes beside
   an untouched control (`i_tod_pu2_fire_sale`).
4. Flip this STATUS to SHIPPED with the build version; CHANGELOG entry; note in
   docs/63 batch 8 that "Insta keeps its baked x3" was reversed here.
