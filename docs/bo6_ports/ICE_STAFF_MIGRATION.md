# BO6 Ice Staff migration into Cybercity

Status, September 13, 2026 (v18.89): **BOUND — the ice staff's presentation is
the BO6 assembly in the built map; native acceptance pending.** The user
authorized an iterative BO6 presentation replacement and a return to the
current BO3 staff if needed. They specifically pointed to Tower of Doom II's
conversion process, and that is the process this follows: BO6 mesh + materials
+ sounds on the DONOR's held motion, aligned by measured anchors.

## The binding (v18.89, `tools/bo6_extraction/install_ice_staff_bo3.py`)

What is BO6 now:

- **Models.** `tod_bo6_ice_vm` / `tod_bo6_ice_wm` (`model_export/tod_bo6_ice/`,
  `source_data/tod_bo6_ice_staff.gdt`) — the staged 51,060-vertex assemblies
  with the root `j_gun` renamed `tag_weapon` (the one tag BO3's weapon code
  attaches by), plus one appended socket `tag_bo6_glow` (child of `j_water`,
  +8.5 in, the centre of the tip crystal). 77 bones, binary readback checked.
  - *View alignment is 1:1, measured.* The fitted idle's right wrist sits
    11.38 in behind `tag_weapon`, the left 0.61 ahead; BO6 authored its IK
    locators at −11.67 / +0.90 from `j_gun`. Residuals 0.29 in. No shift.
  - *World alignment.* The donor world staff runs along **+Z** (its `tag_tip`
    frame maps X→Z) with the root at the 3p right hand; the BO6 world mesh is
    shifted +11.67 along the shaft (so its right-hand locator becomes the
    root) and rotated X→Z. Muzzle lands at z 49.98 vs the donor's 47.86, butt
    at −26.0 vs −24.3.
  - The world assembly's six materials are byte-identical textures to the
    view assembly's (every image md5 matches pairwise), so the world mesh is
    bound to the same six materials rather than a duplicate set.
  - The BO6 staff is 79.5 in long (the Origins view mesh was truncated to
    53.5); the extra length is a tail behind the hands, off-camera as in BO6.
- **Materials.** Six `mtl_tod_bo6_ice_<hash>`: original colour, decoded
  normal/gloss/AO (Tower II's NOG convention), gloss range 0–13, and the four
  emission-colour maps on `lit_emissive_plus` (`colorMap00`, `scaleRGB 6`,
  `emissiveIncompetence 1`). **`scaleRGB 6` is the first native tuning value,
  not a recovered constant** (Tower II's sword needed 12).
- **Sounds.** 14 payloads → `sound_assets/tod/mage/bo6/`, 25 rows between the
  `#BO6 ICE STAFF` markers in `tod_ports.csv`: five base-fire variants (each
  with a tail on the Secondary column), player and NPC; pullout (raise +
  pickup), putaway, first raise, reload. Trims/fades/gains are in the install
  manifest; fire is capped at −1 dBFS peak so it lands ~2 dB hotter (RMS
  −15.5) than the old shot (−17.4). The ice reload and first raise are now
  ONE `2D Sound` note each at frame 1 (`SOUND_NOTES`), because BO6 authored
  them as single clips; lightning and fire keep their four Winter's Howl
  beats. Mix settings are BO3 rows cloned from the existing staff aliases.
- **Weapon.** `tod_staff_ice` (+ regenerated `_q0`/`_q1`): `gunModel`,
  `worldModel`, the five sound fields; `attachViewModel1`/`attachWorldModel1`
  cleared (the assembly carries its tip); `hideTags` cleared (the Origins
  storm/rune tags do not exist on it). Nothing else in the block moved —
  the installer asserts that.
- **Glow.** `_tod_mage_elements.csc` picks the socket per element:
  `tag_upg` for lightning/fire, `tag_bo6_glow` for ice.
- **Gates.** `verify_staff_animations.py` runs the installer's `--check`
  (45 pinned files, 25 aliases, the weapon bindings) on every build;
  `sync_to_modtools.ps1` copies `model_export/tod_bo6_ice`.

What is deliberately NOT BO6 (ledger status `adapted`):

- **Motion.** All 116 BO6 clips stay unbound. They carry local quaternions
  and no skeleton, so they can only be read against BO6's own arm rest pose,
  which was never exported — the same finding Tower II recorded for its
  Saug. The held set is the fitted Origins clips; the model is aligned to
  that donor's grip so those clips place it correctly.
- **Effects (v18.90: BO6-INSPIRED rebuild, not a port).** BO6 vfx cannot be
  exported here: Saluki has no particle/vfx asset type (its settings list is
  Models / Animations / Images / Materials / Sounds / Camos / Sound Banks /
  Animation Packages / Additional), all 35 name dictionaries hold zero
  `vfx_*staff_ice*` entries and the loaded index returned zero rows. So the
  BO6 look is rebuilt from BO3 emitters by
  `tools/bo6_extraction/build_bo6_ice_fx.py` → `share/raw/fx/tod/bo6/
  fx_bo6_ice_{muzzle_1p,muzzle_3p,trail,impact}.efx` (manifest
  `manifests/ice_staff_bo6_fx.json` lists every donor block, scale and tint):
  our trimmed muzzle/trail + Winter's Howl flash-upg crystals/frost/core flash
  + the stock Origins impact under a freezegun light/glow/snow-burst/sparks/
  tendrils/ring nova, tinted cyan-white. The 1p core flash is held at 18 with
  no light and no lens flare (the v18.75 glare rule). Bound on the ice weapon
  and its twins, zoned explicitly, pinned by `--check` in the staff gate. The
  persistent tip glow stays the BO3 effect on `tag_bo6_glow`.
- **Charged attack** (user-excluded), inspect / alt-mode / LFE payloads (no
  BO3 slot), the 37 hashed alias payloads (identity unknown).

Rollback of the binding alone: `git checkout` is not available for the
untracked GDTs — restore `source_data/tod_staff.gdt`'s ten fields from
`manifests/ice_staff_bo3_install.json` (`weapon.previous`), revert
`SOUND_NOTES` in `tools/import_staff_animations.py` and run `--notes-only`,
delete the rows between the CSV markers, `node tools/gen_tod_twins.js`,
revert the CSC tag, FULL build. The staff-asset snapshot below still covers
the whole pre-port tree.

## Process and scope

The locally available sibling repository is
`C:\Users\jorda\Repositories\tower_of_doom_II_hellbound`. Its current extraction,
agent-operations, complete-migration, material-stream and Saug conversion files
were read. The [migration contract](reference/BO6_COMPLETE_MIGRATION.md) is an
unchanged reference copy from that repository, not a claim that its other ports
are complete. `tools/bo6_extraction/port_gate.py` and `inspect_cast.py` are also
unchanged copies. The new staff staging scripts adapt the model writer and
packed-texture decoder. No sibling source files were edited or reset.

The [ledger](ice_staff.json) tracks geometry, materials, animation, sound, FX,
behavior, integration, discovery and native evidence separately. Source-only
preparation does not close any of the nine workstreams. Run:

```powershell
python tools/bo6_extraction/port_gate.py check
```

It currently returns INCOMPLETE. `--development` permits a preparation check and
does not claim completion. This gate is not yet added to Cybercity's normal build:
no BO6 assets are referenced by its playable weapons or zones.

Preserve Cybercity's current ice damage, mana, upgrades, Mystical Hands timing
and three-missile attack (center and +/-8 degrees). On September 13 the user
explicitly excluded the charged attack. Its exclusive sounds, animation and
effects do not need migration; shared or unresolved assets still require review.
All normal-shot sounds, effects and staff glows remain required. The current
ice weapon and its twins use `Single Shot`; no charge mechanic was removed.

## Initial acquisition checkpoint (superseded by the audit below)

- `wpn_t10_wm_ww_zmb_staffs_nocol_LOD0.cast`: actual detailed body, 8 meshes,
  37,937 vertices, 46,266 triangles, 61 bones, four materials. Its source skeleton
  and maximum two actual influences per vertex are preserved. The water tip is
  **absent**, as confirmed by the Blender preview. Both exported `*_base` model
  entries are empty assembly roots (356-byte Casts), not usable meshes.
- 116 `t10_vm_ww_staff*` animation Casts: idle, fire, reload, equip, movement,
  upgraded and alternate forms. Frame/curve/bone/notetrack data were checked.
  None are retargeted or bound in BO3 yet. Shared names do not establish
  compatible parent transforms or view-hand alignment.
- The player/NPC banks contain 258 rows referring to 108 distinct payloads.
  Recursive secondary-alias discovery found no missing external references.
  Eighteen previously hashed alias names were recovered by exact FNV1a matches;
  37 remain unresolved. Ten payloads are exported and validated as nonempty
  48 kHz PCM16 WAVs: nine handling clips and one base-fire variant. The other
  98 payloads still require export; no new sound is installed or heard in BO3.
- The isolated body conversion passed `export2bin` and a binary readback that
  compares mesh counts, bone hierarchy/transforms, matching face positions,
  material assignments and skin weights. The binary reader reorders vertices;
  comparisons therefore use corresponding face corners.
- Four original color PNGs are copied byte-for-byte. Twelve normal/gloss/AO
  PNGs are decoded at source resolution using Tower II's reviewed NOG convention
  (normal XY=A/G, gloss=R, AO=B). Three main maps are 2048x2048. The hose's actual
  constant `(179,128,255,128)` source is repeated from 1x1 to 4x4 for BO3 block
  alignment. No global tint or brightness change is applied. Alpha/metallic,
  specular, extra layers, emission and native shading remain unresolved.

Exact source paths and hashes live under [manifests](manifests/ice_staff_sources.json).
Staged binary and texture outputs live outside build inputs at
`local_sync_cache/bo6_ice_staff/staging/body/`. The source preview and extraction
receipts are under `tmp/bo6_ice_staff/`. This work has not changed staff GDTs,
weapon twins, aliases, glow effects or animation bindings. The September 13
follow-up changes the dev/Mage test setup only, as recorded below.

## Acquisition session

The saved BO6 executable dump and installed game/tool hashes passed Tower II's
preflight. The existing offline Cordycep/Saluki session was reused. The authorized
Saluki controller started successfully, and the assets above exported through it.

The first two UAC attempts were canceled. The user then requested another prompt
and accepted it at 01:52. Successful load receipts now exist for these packages:

```text
mp_av_wpn_t10_vm_ww_zmb_staffs_tr
mp_av_att_t10_vm_ww_zmb_staffs_water_tip_tr
mp_aw_wpn_t10_vm_ww_zmb_staffs_tr
mp_aw_att_t10_vm_ww_zmb_staffs_water_tip_tr
```

The new controller session is recorded in `tmp/bo6_ice_staff/session.txt`.
`tools/bo6_extraction/resume_ice_staff.ps1` wraps the existing Tower II selective
loader and a guarded local Saluki controller in one ordinary administrator
prompt. With games closed, check the shared extractor lease before resuming.
Do not restart or close shared Cordycep/Saluki when a controller expires.
The earlier 25-minute controller is gone; its late stop request has no receipt
and must not be replayed into a new session.

The refreshed model search found eleven staff assets, including the missing
first-person/world bodies and water tips plus their `dreward` variants. All 31
available LOD Casts are inventoried in `manifests/ice_staff_assembly_casts.json`;
re-exporting all LODs left the assembly's LOD0 source hashes unchanged. The tip's
root `tag_barrel_attach` matches the body socket; no hand positioning was used.
`stage_ice_staff_assembly.py` stages both complete assemblies with 51,060
vertices, 59,842 triangles, eleven meshes and 76 bones each. Binary readback
checks face positions, material assignments, hierarchy/rest transforms and all
weights. No influences are discarded. The Blender assembly preview is
`tmp/bo6_ice_staff/source_assembly_preview.png`; it is not a native shader review.

`stage_ice_staff_assembly_materials.py` preserves all six source colors, decodes
eighteen base normal/gloss/AO maps, and preserves four source emission-color
maps byte-for-byte. The 28 outputs and every original texture slot are hashed in
`local_sync_cache/bo6_ice_staff/staging/assembly/materials.json`. Retail shader
constants, layered masks, scrolling/distortion, transparency/metal/specular and
emission intensity remain unverified. The source contact sheet is preserved at
`tmp/bo6_ice_staff/assembly_materials_contact.png`.

`export_ice_staff_audio.py` continues exact bank-referenced sounds through the
guarded controller. Windows OCR must show one matching sound row before each
export. It corrects only impossible-in-hex OCR glyphs (I/l to 1, O to 0), checks
the entire identifier, and stops before export when unverified. Source files
and WAV validation are persisted after every sound. One memory failure during
concurrent large-image conversion stopped the requester after a Clear action;
the successful controller receipt was inspected before resuming. No unverified
export was replayed. Export is not event binding or matching playback.

Nineteen authored sound/FX cue names and their exact clip frames are recorded in
`manifests/ice_staff_presentation_cues.json`, including first-raise, reload and
inspect effects. The sound-bank export supplies only snd/alias/alias2/speaker/
content fields; volume, pitch, falloff, mix and concurrency settings are absent
and must not be invented as "identical" settings.

The authored first-raise player/NPC cues resolve in
`merged_global_stream_mp.all.json`, outside the original two weapon banks.
The inventory now follows those cues and their secondary aliases: **260 rows,
110 distinct payloads, all 110 exported and validated**, with no missing cue or
secondary alias in that closure. Eighteen hashed names were recovered; 37 remain
unresolved. This is the known bank/animation inventory, not a claim that every
retail event or mix setting has been discovered or installed. The shared normal-
fire LFE clip was also exported by its exact observed asset name.

The expanded Saluki index contained 408,004 assets after enabling images,
materials and additional asset types. The observed search for
`vfx_t10_gameplay_zm_weapons_ww_staff_ice` returned zero rows (session screenshot
`request_648.png`); this describes the loaded index, not every BO6 package. A
representative crystal material exported a techset hash and texture-semantic
list only (`bo6/materials/material_185cf03e0a997c76/*.txt`), without shader
constants. Do not infer exact retail material behavior from those texture slots.
All five changed extractor preferences were restored (screenshots 666/668).
The controller acknowledged stop (request/result 670); its PID exited and its
matching lease was expired. Shared Saluki and Cordycep remain open.

## September 13 pre-test audit and setup

The active staff remains the BO3 staff. `source_data/tod_staff.gdt` still uses
`tod_staff_view/world`, `tod_staff_tip_water_view/world`, the existing fitted
Origins animations, `wpn_tod_staff_ice_plr/npc`, and shared bow handling/impact
aliases. Its muzzle effects are `tod/fx_tod_ice_muzzle_1p/3p`, trail is
`tod/mage/fx_staff_ice_trail_clean`, and impact is
`dlc5/zmb_weapon/fx_staff_ice_impact`. The client glow is still
`dlc5/zmb_weapon/fx_staff_ice_persistent` attached to `tag_upg` and replaced on
weapon changes. These are baseline bindings, not substitutes proven identical
to BO6. The tip is now acquired and assembled; motion integration, material
layers/emission, sound-event settings and BO6 FX still prevent a parity claim.

At the user's request, `tod_resolve_dev_flags()` now hardcodes `tod_dev`,
`tod_god`, `tod_dev_maxed` and `tod_dev_mage_test` true. The class draft assigns
Mage automatically before pausing the world. The existing max-grant routine
promotes to tier three, fills every available upgrade domain, and the test
wrapper equips ice. It logs `[TOD_STAFF_TEST]` class assignment, actual caps,
missing domains, ice presence and fired staff weapons in dev mode. The logger
explicitly labels the presentation `bo3_pending_bo6`. God mode uses the existing
unkillable-player implementation. The spire warp remains parked. The build's
publish gate recognizes the new `tod_dev_mage_test` flag automatically.

The three pre-edit gameplay files are backed up separately under the directory
in `tmp/bo6_ice_staff/test_setup_baseline.txt`. Disable the four armed flags and
rebuild to restore ordinary class selection/progression; no staff-asset rollback
is needed.

**Build verified, native test blocked:** the final full build completed at
02:23:39 Eastern with the corrected 8192 sky, a 176,396,544-byte fastfile and
all required build checks passing. `manifests/ice_staff_dev_deployment.json`
pins the fastfile and 142 matching scripts/zone/UI files, with no sync later
than the fastfile. The earlier failed build involving the concurrent unsupported
sky is preserved in `tmp/bo6_ice_staff/dev_build_sky_failed.log`; it is not the
test artifact. The final transcript is `tmp/bo6_ice_staff/dev_build.log`.

`tools/run_game.ps1` requested the Steam launch at 02:28. Regular guarded focus
could not raise Steam or send input. A normal administrator prompt for the
existing guarded focus helper was canceled by Windows. No Continue/game input
was sent and no BlackOps3 process started. The spawn/grant/god diagnostics are
therefore **compiled but not natively verified**. See
`manifests/ice_staff_native_attempt.json`. The prelaunch archive contains the
previous game session, not evidence for this build. All four test flags remain
armed for the user's test; no publish was attempted.

Once loaded, refresh Saluki's Load Game list, inspect the exact staff filter,
then export the newly available body and tip components. In this session Ctrl+F
left a stray character once. Clear, click the search box, then submit acknowledged
12-character text chunks worked. Inspect the complete query and result count
before Export All. Export All operates on the current filtered list.

## Continue conversion

Steps 2–4 of the original plan are DONE by the v18.89 binding above (with
motion and effects adapted, not retargeted — see the reasons there). What is
left, in order:

1. **Native acceptance.** Launch per `docs/132_native_game_verification.md`
   with the four test flags armed (`tod_dev_mage_test` equips ice at spawn),
   look at the held staff in idle / fire / reload / sprint / first raise, the
   glow at `tag_bo6_glow`, the muzzle at `tag_flash`, the 3p/stowed/dropped
   world model, and listen to fire / raise / putaway / reload / first raise.
   The user judges look and feel; the likely first knobs are `scaleRGB` (glow
   strength), the fire alias VolMin/VolMax, and the first-raise trim.
2. **Motion, only if the BO6 arm rest pose is ever exported.** Then the 116
   clips can be retargeted honestly; until then do not "fit" them by eye.
3. **Effects, only if BO6 vfx data is found** (it was absent from the loaded
   index). The cue frames for first raise / reload / inspect are recorded in
   `manifests/ice_staff_presentation_cues.json`.
4. Resolve the 37 hashed aliases if their identities ever surface; bind by
   name, never by listening-and-guessing.

Re-run the binding from the staged assembly at any time (idempotent):

```powershell
python tools/bo6_extraction/install_ice_staff_bo3.py
python tools/import_staff_animations.py --notes-only
node tools/gen_tod_twins.js
python tools/verify_staff_animations.py
python tools/bo6_extraction/ledger_ice_staff_bound.py
```

Reproduce the current isolated stages:

```powershell
python tools/bo6_extraction/inventory_ice_staff.py
& 'C:/Program Files/Blender Foundation/Blender 4.2/blender.exe' --background --python-exit-code 1 --python tools/bo6_extraction/stage_ice_staff_body.py
python tools/bo6_extraction/stage_ice_staff_materials.py --python-packages C:/Users/jorda/Repositories/tower_of_doom_II_hellbound/tmp/bo6_materials/python_packages
```

The materials tool uses Pillow/numpy versions recorded in
`tools/bo6_extraction/requirements_materials.txt`. No package install was needed
for this attempt. The tools do not request elevation or drive the extractor.

## Rollback baseline

`local_sync_cache/bo6_ice_staff/baseline.txt` points to snapshot
`20260913_005833`. It contains 435 source files and all 48 deployed payload files
(2,119,398,484 payload bytes). Every archived entry was SHA256-verified against
its source. `sources.zip`, `payload.zip` and `manifest.json` are preserved.

The final checkpoint rechecked 141 existing staff sources against the baseline,
119 source Cast hashes and all 18 staged geometry/texture output hashes.
`verify_staff_animations.py` also passed the existing 78-clip/six-twin checks.
The strict migration gate reports nine open workstreams and zero invalid claims.

At this checkpoint no gameplay rollback is necessary: the existing staff is
still selected. After integration, restore only the port's recorded changes;
shared files may contain later unrelated edits, including concurrent work on
Cybercity. Never reset the whole repository or blindly unpack the old sources
over newer work. A selected source rollback requires regenerating twins and a
fresh full build. The payload archive is also available for an explicitly chosen
return to that exact pre-port build, with the game closed.
