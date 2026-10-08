# 164 - The staff crystal: Treyarch's fourth piece, back on the fire and lightning staffs

2026-09-27. Source change only: **not built and not played**. The coordinator
runs the build, and the user judges the look in game.

## Pass 2 (2026-09-27, after the user played pass 1): first person + glow

The user played pass 1. The third-person stones were now obvious, but **(1) they
did not glow**, and **(2) in first person the fire and lightning stones were
missing** (pass 1 was world only). Both are fixed here. Source change only:
**not built and not played**.

### First-person crystal: alignment MEASURED

`tmp/staff_crystal_20260927/measure_view_crystal.py` writes
`view_crystal_alignment.json` / `.log`. It reads every clip the fire/lightning
staffs play: the 24 approved fit clips per element plus the PaP first raise.
Frame parts are model-space poses.

For each frame it compares where the crystal's centroid would land under each
candidate attachment against Treyarch's design, which puts the crystal root ON
the head root, as on the world shaft where `tag_crystal == tag_tip`. The head
root is `tag_tip_<el>`, the bone the clips drive the head by.

**Maximum distance from the cage centre, all frames:**

| candidate | fire (25 clips, 876 frames) | lightning (25 clips, 864 frames) |
|---|---|---|
| blank tag, clip-driven root `tag_clip_<el>` | **36.0 - 53.0 in** | **36.2 - 54.4 in** |
| explicit `tag_crystal` | 3.243 in | 3.293 in |
| **explicit `tag_tip` (chosen)** | **0.000 in, 0.000 deg** | **0.574 in** (first raise only; 0.000 elsewhere) |

Per clip with `tag_tip`:
- **Fire:** 0.000 in / 0.000 deg in idle, fire, ADS fire, reload, first raise and
  the PaP first raise.
- **Lightning:** 0.000 in / 0.000 deg in idle, fire, ADS fire and reload. In the
  first raise (base and PaP) the head **spins** about its own long axis for
  frames 11-18 of 49, up to ~171 deg, with zero translation. The unspun crystal
  stays in the socket, and its centroid is 0.574 in from the spun one.

Six shared ice clips (`ads_up/down`, `fall`, `jump`, `jump_land`, `walk_f`) key
none of these bones: they are partial layers. The ADS pose itself is covered by
`ads_fire`.

**Why the crystal is missing in first person with the obvious wiring.** The
approved clips DO key the crystal's own bone `tag_clip_<el>`, but with the RAW,
uncorrected Origins track. The docs/117 head-offset correction reached the
head's bones and never `tag_clip_*`. A crystal driven by that bone, which is what
a blank tag does, lands 36-54 in off the head: off to the side of the screen.

The head's own trick, a blank tag with the clip-driven root, is exactly what
does NOT work for the crystal.

An explicit tag cannot be put on a model whose root the clips key: the key wins
over the tag. That is how an explicit tag "lost the head" in R5 (docs/117).
So:

- `tod_staff_crystal_<el>_view` is the SAME mesh with its one bone renamed from
  `tag_clip_<el>` to **`tag_tod_staff_crystal`**, a name no clip keys.
  - It goes through PyCoD's text writer and `export2bin`, and the output must
    start with `*LZ4*`.
  - The result is re-read: vertices, faces, UVs, normals, weights and the
    material must be identical to the source.
  - It rests on the explicit attach tag **`tag_tip`**, the ordinary optic lane
    (an unkeyed root on an explicit tag, like the ACOGs on `tag_acog_2`).
- The view HEAD keeps its blank tag. Only the crystal takes a tag.
- **Base:** `attachViewModel2 = tod_staff_crystal_<el>_view`,
  `attachViewModelTag2 = tag_tip`.
- **Packed:** gmod6 `attachment0_ViewModel_model1` / `ViewModelTag_model1`, same
  values.

### Glow

Treyarch's values (scaleRGB 8, emissive tint peak ~0.75) sit over an emission
map (`i_wpn_t7_camo_ice_e`) whose mean is **27%** (measured), so they read as a
dull stone under this map's lighting.

**One knob per element** in `tools/build_staff_crystal.py`:
- `GLOW_SCALE`: the scaleRGB multiplier.
- `GLOW_TINT`: colorTint / colorTint1. Keep the brightest tint1 channel at 1.
- `GLOW_FLOOR` 14 is asserted.

| | scaleRGB | colorTint1 (emissive) | colorTint |
|---|---|---|---|
| fire, was (Treyarch) | 8 | 0.749 0.333 0.129 | 0.467 0.259 0.187 |
| **fire, now** | **16** | **1.00 0.50 0.14** | 0.90 0.45 0.18 |
| lightning, was (Treyarch) | 8 | 0.190 0.060 0.427 | 0.178 0.092 0.267 |
| **lightning, now** | **16** | **0.68 0.30 1.00** | 0.45 0.20 0.85 |

For comparison in this map: the BO6 ice tip crystals ship at scaleRGB 14
(`install_ice_staff_bo3.EMISSIVE_SCALE`) and the inducer's ON emissives at 8-22.

The effective emission (map x tint x scale) rises 2.7x on fire and 4.7x on lightning: fire red goes from
~1.6 to ~4.3, and lightning violet from ~0.9 to ~4.3. The techset is still
`lit_emissive_scroll_advanced_fullspec`, and the world and view crystals share
the material.

### Pass-2 diff scope (`gdt_field_diff_pass2.log`, against `backup2/`)

| file | blocks | fields |
|---|---|---|
| `tod_staff.gdt` | `tod_staff_fire`, `tod_staff_lightning` | `attachViewModel2`, `attachViewModelTag2` |
| `tod_weapon_twins.gdt` | `tod_staff_{fire,lightning}_q{0,1}_zm` | the same two |
| `tod_staff_pap.gdt` | `au_tod_staff_{fire,lightning}_gmod6` | `attachment0_ViewModel_model1`, `attachment0_ViewModelTag_model1` |
| `tod_staff_crystal.gdt` | +2 xmodels `tod_staff_crystal_{fire,lightning}_view` (cloned from `tod_staff_tip_<el>_view`); both materials | `colorTint`, `colorTint1`, `scaleRGB` |

Nothing else moved:
- the world crystal binaries are byte-identical;
- ice is untouched;
- `tod_twins.zpkg` and the weapon CSV are byte-identical;
- the ledger stays **237**, and the cost table stays **234/240**.

The view `.XMODEL_BIN` is not byte-deterministic across regenerations: the text
writer stamps a header. The content is re-verified every run, and the manifest
pins the current bytes.

### Pass-2 evidence

- `backup2/`: every file as it was at pass 1, plus `backup2_sha256.txt`.
- `gates_pass2.log`, all rc=0:
  - `verify_staff_animations`, `verify_staff_3p`, `verify_staff_presentation`
  - `build_staff_crystal --check`
  - `test_staff_presentation`, `test_dev_mage`
  - `lint_tod_arity`, `lint_tod_assets`, `verify_weapon_costs`
  - `test_no_optics`, `lint_tod_weapons`, `verify_weapon_attachments`
- `negative_controls_pass2.log`: **11/11 caught**. That is pass 1's six plus five
  new ones:
  - a twin loses its view crystal;
  - the view crystal sits on the raw-keyed `tag_crystal`;
  - packed fire loses its view crystal;
  - the glow falls back to scaleRGB 8;
  - the view root is left as the clip-keyed `tag_clip_fire`.

  Every file was restored byte-identical.

### Pass-2 unproven

1. **The engine rule is inferred.** "A keyed root ignores its attach tag, an
   unkeyed one rests on it" is inferred from R5 (docs/117) and the working optic
   attachments. It has never been proven in this map for a model attached
   beside clip-driven heads.
   - If the first-person stone is still missing, the next try is the SAME renamed
     crystal on a blank tag. It would then sit at the view root, so that is
     only a diagnostic.
2. **The lightning first-raise spin:** the stone does not spin with the head
   during frames 11-18.
3. **Glow strength is the user's call.** Tune `GLOW_SCALE` by +/-4, then run
   `python tools/build_staff_crystal.py` and do a FULL build.
4. **The packed forms** carry the same caveat as pass 1 (gmod6 runtime
   composition unproven).

## The report, and what it actually was

The user said the fire and lightning staffs "look like they're missing a piece
in the middle" in third person, while ice looks fine, and asked to "swap over to
the BO3 staffs".

**The staffs already are the BO3 staffs.** They are the Chronicles zm_tomb HD kit
`wpn_t7_zmb_hd_staff_*`, and the files are byte-identical to the user's
Greyhound export (md5):

| in game | Greyhound source |
|---|---|
| `tod_staff_view` / `_world` | `wpn_t7_zmb_hd_staff_view` / `_world` |
| `tod_staff_tip_fire_*`, `tod_staff_tip_lightning_*` | `..._tip_fire_*`, `..._tip_lightning_*` |
| `tod_staff_{fire,lightning}_pap_tip` | `..._tip_{fire,lightning}_upg_world` (T7 Assets V2.7) |

The 78 viewmodel clips are converted BO3 `vm_zom_staff_t7_*` clips. The
third-person clips are Treyarch's `pb_`/`pt_staff`, per docs/161.

**What was missing is the fourth piece of Treyarch's kit.** The kit is a shaft, an
element head, a **crystal** and an upgraded head. The crystal was left out on
2026-09-07 (docs/114 §A.5) because its material looked like a camo shader.

Measured from the XMODEL_EXPORTs:

- **The world shaft is continuous** from Z -24.3 to 47.65. `tag_tip` and
  `tag_crystal` sit at the same point (Z 47.86).
- **The fire head is a hollow cage.** Between local X 4 and 14 no vertex lies
  within 3.4-6.1 in of the axis.
- **The fire crystal fills that cage:** X 0-11.3, radius ≤ 3.5.
- **Lightning is the same:** the head is hollow at X 8-14 (2.5-5.5 in), and the
  crystal spans X 3-12 at radius ≤ 2.25.
- **Treyarch's own weapon defs** (`staff_fire_zm` / `staff_bolt_zm` in T7 Assets
  `t7_weapons.gdt`) put the crystal in attach slot 1 at `tag_crystal`, in both
  view and world.

First person hid the hole. The staff glow is a `PlayViewmodelFX` at `tag_upg`
for the local player only (`_tod_mage_elements.csc`), so it fills the cage on
your own screen. Other players get neither the glow nor a crystal.

Ice looks fine because it is the BO6 port, whose tip carries its own emissive
core.

The docs/161 armminigun / `tag_weapon_right` change did **not** cause this.
Attach slots hang off the weapon model's own tags. Before v19.49 the base world
head had a blank tag and sat at the grip, so the empty cage only became
visible recently.

## Why the old blocker is gone

Treyarch's crystal material is **`lit_emissive_scroll_advanced_fullspec`**, not a
camo type. That is a stock techset, installed in both `techsetdefs_stable`
folders and used by the stock bow (`wpn_t7_zmb_bow.gdt`, e.g.
`mtl_wpn_t7_zmb_bow_wolf`).

## What changed

- **`tools/build_staff_crystal.py`** (new) copies the two WORLD crystal binaries
  from the Greyhound export into **`model_export/tod_staff_crystal/`**.
  - The binaries are repo-owned. `sync_to_modtools.ps1` now copies that folder.
  - It writes **`source_data/tod_staff_crystal.gdt`** with 2 xmodels and 2
    materials.
  - It pins everything in `docs/staff_crystal_manifest.json`. `--check` is the
    gate half.
  - It reads the binaries back with PyCoD: `tag_clip_fire` /
    `mtl_wpn_t7_zmb_hd_staff_crystal_fire` / 120 tris, and `tag_clip_lightning`
    / `mtl_wpn_t7_zmb_hd_staff_crystal_lighting` / 36 tris.
- **The xmodel blocks** are cloned field-for-field from `tod_staff_tip_<el>_world`.
  Only `filename` changed, and the inherited `skinOverride` junk was cleared.
- **The material blocks** are named **exactly as the binaries embed them**,
  including Treyarch's typo `..._crystal_lighting`.
  - They clone the stock bow's `mtl_wpn_t7_zmb_bow_wolf` field set (same
    materialType, a block that renders).
  - Treyarch's 48 crystal fields are laid over it: `colorMap00
    i_wpn_t7_camo_ice_e`, normal/occ `i_wpn_t7_zmb_hd_staff_crystals_n/_o`,
    `flickerLookupMap i_generic_lookup`, `$` stock maps, `scaleRGB 8`.
  - Tints:
    - fire: colorTint 0.467/0.259/0.187, colorTint1 0.749/0.333/0.129
    - lightning: colorTint 0.178/0.092/0.267, colorTint1 0.190/0.060/0.427
  - Every image they name either exists or is a built-in:
    - the three `i_wpn_t7_*` blocks have been declared in
      `tod_staff_origins.gdt` since v18.33, unused until now, with their PNGs
      present in the tools root;
    - `i_generic_lookup` is the canonical revealMap in
      `texture_assets/genericfilters.gdt`;
    - `$` images are engine built-ins.
- **`tools/staff_presentation_bindings.py`:**
  - `STAFF_CRYSTAL` and `STAFF_CRYSTAL_TAG` are new.
  - **Base:** fire and lightning get `attachWorldModel2 =
    tod_staff_crystal_<el>_world` and `attachWorldModelTag2 = tag_crystal`.
  - **PaP:** `attachment_fields()` adds `attachment0_WorldModel_model1` /
    `WorldModelTag_model1` to the gmod6 AU. `disableBaseWeaponAttachment 1`
    drops the base slots, so the packed form must re-attach the crystal.
    `attachmentunique.awi` offers model0..1.
  - Its refresh now also rewrites the six AU blocks in place from
    `attachment_fields()`. The round trip of the untouched blocks is lossless,
    so there is no need to re-run the export-dependent
    `build_staff_presentation.py`. It then re-stamps the PaP GDT pin in
    `docs/staff_presentation_manifest.json`.
- **`tools/verify_staff_presentation.py`:**
  - `check_world_assembly` requires the crystal on every fire/lightning form,
    base and packed, at `tag_crystal`.
  - It requires that ice has none. (Pass 1 also forbade a first-person
    crystal; pass 2 replaced that with the view-crystal requirement above.)
  - `main()` runs `build_staff_crystal.check()`.
  - `test_staff_presentation.js` was not touched: it tests GSC routing, not GDT
    fields.
- **No zone line.** The tips and PaP tips have no xmodel zone lines. They ride
  in through the weaponfull and the explicitly zoned attachmentunique, and the
  crystal takes the same lane. `scripts/` and `ui/` were not touched.

### Regenerated GDT scope (semantic field diff, `tmp/staff_crystal_20260927/gdt_field_diff.log`)

| file | blocks | fields |
|---|---|---|
| `tod_staff.gdt` | `tod_staff_fire`, `tod_staff_lightning` | `attachWorldModel2`, `attachWorldModelTag2` |
| `tod_weapon_twins.gdt` | `tod_staff_{fire,lightning}_q{0,1}_zm` (4) | the same two |
| `tod_staff_pap.gdt` | `au_tod_staff_{fire,lightning}_gmod6` | `attachment0_WorldModel_model1`, `attachment0_WorldModelTag_model1` |

Raw line counts: 8 / 16 / 4. The manifest changed one hash.

- Ice is untouched, and no other of the 249 twin blocks moved.
- `tod_twins.zpkg` and the weapon CSV are byte-identical.
- The ledger stays **209 + 28 = 237**, and the cost table stays **234/240**.

## Evidence (`tmp/staff_crystal_20260927/`)

- `backup/`: every changed file as it was before, plus `backup_sha256.txt`.
- `gates.log`, all rc=0:
  - `verify_staff_animations.py`
  - `verify_staff_3p.py`
  - `verify_staff_presentation.py`
  - `build_staff_crystal.py --check`
  - `test_staff_presentation.js`
  - `test_dev_mage.js`
  - `lint_tod_arity.js`
  - `lint_tod_assets.js`
  - `verify_weapon_costs.js`
  - `test_no_optics.js`
  - `verify_weapon_attachments.py`
- `negative_controls.py` / `.log`: **6/6 caught**, and every file was restored
  byte-identical. Each control mutates one named block:
  - fire q1 twin loses the crystal;
  - lightning source crystal on the wrong socket;
  - packed lightning loses it (with the pin re-stamped, so the crystal assert is
    what fires);
  - ice gains one;
  - the material moves off the stock techset;
  - the binary is edited without regenerating.

## Unproven: only the build and the game can answer

1. **Link.** A FULL build is required, because this is a GDT edit.
   - The post-link `verify_weapon_models_linked.js` now also demands the two
     crystal models, since it reads `attach*Model\d+`. Its count should rise
     from 111.
   - The `missing_techsetdef` gate must stay at zero.
   - The ledger should show both crystal materials on
     `lit_emissive_scroll_advanced_fullspec#…` with their images. `.deps`
     should show the fire/lightning weaponfulls and gmod6 AUs pulling the
     crystal.
2. **Packed forms.** The runtime composition of every gmod6 packed look in this
   map is still unproven (CLAUDE.md v19.41).
   - If `disableBaseWeaponAttachment` does NOT drop slot 2, a packed staff draws
     the crystal twice in the same place. That is harmless, but if it shimmers,
     delete the AU model1 lines.
3. **The look.** This is Treyarch's scroll/flicker shader with Treyarch's
   values, but nobody has seen it on this map's lighting.
4. **First person:** superseded by pass 2 (above). It was measured, and the
   view crystal is now attached at `tag_tip`.

## What to look at in game

Use the dev Mage dummy (docs/160, six forms every 12 s) or a co-op partner, and
look from the side and front:

- **Fire and lightning, base and packed, in third person AND first person:** a
  GLOWING orange stone (fire) or violet stone (lightning) sits inside the head
  cage, not at the hand and not floating off to the side.
- **First person:** check idle, fire, ADS, reload and the first raise. In the
  lightning first raise the head spins while the stone stays still.
- It moves with the staff through idle, walk and fire.
- **Ice is unchanged.**

## Fragility noted, not fixed

- The v18.33 shaft and heads (`tod_staff_view/_world`, `tod_staff_tip_*`) and
  the three crystal images still live **only in the tools root** under
  `model_export/sla/tod_staff/`. The repo does not vendor them, so a fresh tools
  install loses them.
- The new crystal binaries are repo-owned.

## Rollback

Pass 2 only: restore `tmp/staff_crystal_20260927/backup2/` (it includes the
pass-1 `model_export/tod_staff_crystal/`; delete the two `_view` files), then
FULL build. Everything: restore the files in
`tmp/staff_crystal_20260927/backup/` (matching the
recorded sha256). Then delete `source_data/tod_staff_crystal.gdt`,
`model_export/tod_staff_crystal/` and `docs/staff_crystal_manifest.json`, and
FULL build.

Or, to drop only the packed half, remove the `if element in STAFF_CRYSTAL` block
in `attachment_fields()`, then run `python tools/staff_presentation_bindings.py`
and `node tools/gen_tod_twins.js`.
