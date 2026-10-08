# Full cyber zombie roster

## Current: fitted cuffs and expanded equipment, revision 3

User reported that the fixed-size wrist equipment looked wrong on skinny arms
and requested more cyber equipment across the roster. Revision 3 replaces the
old forearm assemblies and adds connected chest/back equipment to all five
studies. All 144 source binaries pass original body/skeleton/damage-variant
checks. Full build **PASSED 23:08:19 Eastern**; no game launch.

### Forearm fit

The original bands used the same fixed oval around both body donors. The new
script measures each actual donor forearm with radial surface intersections:
48 samples around each of three rows on each strap, with further samples for
the rigid plate. Both straps follow their own donor's sleeve/skin silhouette.

The smaller panel spans 45?77% of elbow-to-wrist distance and 60 degrees around
the outer arm. The straps center at 48% and 74%; the wrist joint stays clear by
about 2.16 game units. A smooth surface fitted above the sleeve folds supports
the hard plate; a shaped rubber liner fills the space beneath it. The hard
plate must not copy the donor's torn cloth folds?an initial close-up showed
that producing a crumpled-looking shell, corrected before export.

`forearm_fit` in each `equipment_v3.json` records the measurements and source
meshes. Body1 and body2 have different profiles; Signal/Crown share the same
body2 profile and native body assets. Sprinter keeps no wrist cuff.

### Added equipment

- All regular bodies: upper-chest receiver with twin capacitor cartridges,
  short protected feed, and a compact fitted forearm unit.
- Trooper/Signal/Crown: segmented three-cell spine power chassis and feeds.
- Relay: two cylindrical reserve cells and feeds around the existing back unit.
- Sprinter: collar capacitors, an auxiliary breast sensor, twin rear cooling
  assemblies and shoulder feeds. A shorter central power core replaces the
  tall rear box that intersected a donor armor spike.
- Both helmets: paired rear locator lamps (cyan/amber).

All use the existing head, torso or elbow export groups, material atlas sets,
and native damage/gib variants. No GSC/Lua changes, new AI behavior, gameplay
stats, or runtime attachment entities. Previous worn finishes and eye glow
remain. The source skeleton and body geometry are unchanged.

Authoring: `tools/expand_cyber_roster.py -- <study-id|mvp>` starts from preserved
revision-2 masters in `tmp/cyber_finish_v2`, checks donor geometry/weights and
four attachment poses, then writes the current packed master and previews.
The gallery adds **Wrist fit** and **Inside wrist** views for regular bodies;
sprinter displays its detail view for those tabs. Preview lighting is Blender
studio lighting. Final native appearance is for the user's playtest.

Aggressive LOD reduction exposed cancelled averaged corner normals where
thin cuff surfaces meet. Both exporters now fall back to the valid triangle's
geometric normal in that case, keeping the face and the existing strict native
normal checks. Full-detail sources are unaffected. Counts are recorded in
`tmp/roster_equipment_v3/distance_normal_fallbacks.json`.

### Revision 3 final build

Full build exit 0 at **2026-09-15 23:08:19 Eastern**. Main FF **150,027,008
bytes**; English companion **801,024 bytes**, 23:08:21. All **144 authored
LODs** pass the native geometry gate, including all original leg geometry
and eight generated LODs for the sprinter/arm gibs. All **318 snapshot, current
source and deployed inputs match**, with no later sync and no missing assets
across main/English asset ledgers.

Native LOD0 triangles: Crown/Signal 26,713; Trooper 25,219; Relay 28,195;
sprinter 12,674. The roster's five final master hashes and 23 preview hashes
also match their delivery manifest. Representative wrist/body/back previews
and the exported MVP model render were visually inspected. No native game
launched; the user handles the in-game test. Dev/god/doors/harness remain OFF.

Evidence: `tmp/roster_equipment_v3/build.log`, `input_snapshot.json`,
`deployment_verification.json`, `completion.json`, `compiled_xmodels.csv`,
source-check logs and `export_preview.log`. Gallery reopened with the new
**Wrist fit** / **Inside wrist** inspection views.


## Revision 2: equipment finish pass

User requested a more seamless outfit match, extra detail on each study, and
brighter eye pieces. All five roster studies plus the shared MVP master are
updated. Full geometry/lighting/native packaging completed at **22:32:44 Eastern**.
All source and compiled model checks pass. No game launched. Dev/god/open-door/harness flags remain OFF.

- Coatings follow the outfit: olive on body 1, worn gray on body 2, dark
  oxidized metal on the sprinter, and pale chipped receivers on the helmets.
- All equipment materials now have baked color/roughness variation, small
  pits and chipped coating, tarnished brass, or fabric/rubber surface detail.
- Woven mounting pads, stitched anchor tabs, rivets and service screws add
  physical attachment detail. Receivers gain service ports; the relay and
  sprinter gain short service conduits attached to their existing torso bone.
- Optic rings use emission strength 5.4 and bright center lenses 6.0, while
  small body lamps use 1.8. Atlas values are divided by 6 and native scaleRGB
  reconstructs them at 6, avoiding saturation of every lamp to the same value.
- Trooper/Relay now have matching arm gibs: 108 roster binaries + 36 MVP =
  **144 authored model LOD binaries**. The five atlas sets still contain 25
  maps at 1024 square. No extra runtime attachment entities or gameplay edits.

### Authoring and bake correction

`tools/refine_cyber_roster.py -- <study-id|mvp>` updates the six saved masters
from one-time revision-1 backups in `tmp/cyber_finish_v1`. It refuses an already
refined source backup, checks donor geometry/weights, and evaluates four poses.
The five-study gallery and delivery manifest are refreshed under
`art/cyber_zombie_roster`; `finish_v2.json` records each art check.

The earlier exporters baked constant Principled defaults for color, specular,
gloss and glow. That discarded procedural links and emission intensity.
Both now use `tools/cyber_material_bake.py`: linked color is baked directly,
fullspec blends dielectric F0 .04 with color by metallic, gloss is one minus
linked roughness, and emission preserves relative strengths. This follows the
gold sword's use of real material-channel bakes and varied surface finishes.

`tools/test_cyber_material_bake.py` actually bakes a known gradient in Cycles
and checks color, metallic/specular, roughness/gloss and emissive values.
It passes; evidence is `tmp/cyber_material_bake_test.json`. Source checks pass
for all 144 native binaries, including every donor object/vertex/face, original
UVs/normals/weights and skeleton. The prior missing-leg object-table checks
remain active. Studio pose error is below 0.000023 game units.

Export/install order stays the same, but bake the shared MVP master with
`tools/export_cyber_zombie_kit.py` as well. Signal/Crown body equipment and
head 1 depend on it. All five native atlas sets must be refreshed together.
Build evidence for this revision belongs in `tmp/roster_finish_v2`.
Final map lighting, bloom and animation/dismemberment appearance still need
the user's native playtest. Blender renders do not establish those results.

### Revision 2 final artifact

Main FF **150,022,080 bytes**, 2026-09-15 22:32:44.145 Eastern; English FF
**800,960 bytes**, 22:32:46.241. All **318 snapshot/source/deployed inputs**
match, with no later deployed inputs or missing expected assets across both
main/English ledgers. All **144 authored model LODs** pass compiled coverage;
original 5,474/6,520 leg triangle differences remain intact.

The full build's post-link validator initially rejected the two new arm gibs
because it expected one native LOD. The inherited donor settings correctly
autogenerate eight, exactly like the existing MVP arm gib. Fixed that checker
expectation and reran the required compiled gate against the unchanged final
artifact: passed. No art/game input changed after packaging. Completed the
remaining local-build payload summary; no publication or game launch.

Evidence: `tmp/roster_finish_v2/build.log` retains the initial gate failure;
`compiled_roster_check.log`, `compiled_xmodels.csv`, `deployment_verification.json`
and `completion.json` record the successful corrected verification. The main
FF and English FF are ready for the user's playtest. All 15 gallery previews
were refreshed. Representative views of all five studies and the native-export
MVP LOD0/LOD3 studio renders were visually inspected.

## Revision 1 integration history

User approved integration after reviewing the offline roster. Scope: regular
zombies and armored sprinter; special enemies are unchanged. Full build PASSED
2026-09-15 21:58:51 Eastern. Dev/god/open-door flags and the King harness remain
OFF. Built and stopped; user handles native playtesting. No game launched.
Latest deployed artifact is the subsequent peer HUD script-only build at
22:05:14 Eastern; roster was reverified against it as described below.

## Appearance mapping

| Factory slot | Character | Body / equipment | Head selection |
| --- | --- | --- | --- |
| 1 | c_tod_cyber_trooper | Body 1, compact crown breast unit, brace, cyan helmet receiver | Three native heads with optic-only implants |
| 2 | c_tod_cyber_signal | Body 2, crown module, brace, amber helmet receiver and antenna | Same three helmet-compatible heads |
| 3 | c_tod_cyber_relay | Body 1, breast unit, brace, twin-cell rear module | Three bare heads with temple equipment |
| 4 | c_tod_cyber_zombie | Approved MVP body 2 equipment | Same three bare heads |

The original factory's four character slots and three-head randomness remain.
Both head aliases copy the original alias fields and replace only model names.
All normal matches select the cyber factory through the existing pre-init
filter; only diagnostics depend on `tod_dev`.

Signal and Crown reuse the proven MVP body/damage models and brace gib: their
body hardware is identical. New helmets carry their own receiver meshes.
The hat character's `head_gibmodel` points to that same enhanced helmet, so
its equipment goes with the flying helmet. Each character preserves its stock
gib definition apart from cosmetic model references. Arm-loss bodies omit the
brace from the missing side; the detached limb carries the existing brace.
Stock neck collars and leg damage source meshes remain inherited.

## Armored sprinter

`TOD_SPRINT_BODY_MODEL` now selects `tod_cyber_sprinter`, derived from the exact
BO4 mob body 3 previously used. Source geometry, bones and weights remain
unchanged. The new breast sensor and rear power rails are baked into the body.
The offline study rotated this donor -90 degrees for the studio; exporter
installation rotates hardware positions and normals back +90 degrees before
adding it to the original binary. The validator compares every kit corner
against this transformation.

The donor has only LOD0; native autogeneration supplies seven lower LODs.
Promotion retains its existing head/helmet and never reconstructs a removed
head. The MVP's old custom-to-stock head replacement is removed. Existing
health, armor, movement, `no_gib` and elite damage behavior are untouched.

## Assets and authoring

The MVP's 36 binaries and five atlases remain reusable dependencies. Roster
adds 106 binaries and four five-map atlases (color/normal/specular/gloss/glow).
Hardware is native skinned geometry, with no extra runtime entities or normal-
play polling. Every regular body, head and helmet has seven authored LODs.
Shader remains `lit_emissive_advanced_fullspec`, including the specular map.

`tools/export_cyber_roster.py` bakes a saved study into repository assets:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.2\blender.exe' -b art/cyber_zombie_roster/01_line_trooper/01_line_trooper.blend --python tools/export_cyber_roster.py -- trooper
# Repeat for 02_signal_trooper / signal, 03_relay_carrier / relay,
# and 05_armored_sprinter / sprinter. Crown reuses the approved MVP atlas.
python tools/install_cyber_roster.py
python tools/install_cyber_zombie.py
python tools/verify_cyber_roster.py
python tools/verify_cyber_zombie.py
```

Both installers read the stock database/source binaries without modifying them.
GDT definitions materialize resolved donor settings (cross-file inheritance
does not work). The full build syncs both GDTs and the existing owned model
folder. It must not run during BO3 or another build.

## Validation and diagnostics

Source checks pass for all 142 binaries: valid object tables, every original
mesh/vertex/face/material/normal/UV/color/weight and bone bind matrix preserved.
The roster check additionally compares each hardware corner to its baked kit,
including the sprinter's coordinate conversion. Character and gib overrides
are limited to appearance. Head aliases, hats and all four slots are checked.

Both checks gate builds before compilation, and again with the fresh native
xmodel ledger afterward. Compiled geometry must retain the expected triangle
counts at every authored LOD. Intact body 1 must contain all 5,474 leg triangles
beyond its upper torso, and body 2 all 6,520. Sprinter must have eight native
LODs. Asset presence alone is not adequate verification.

`tools/test_cyber_zombie_spawns.js` checks all dev flag states, both factory
orders, init timing, dev-only tracking and sprinter promotion retaining heads.
GSC arity, existing bat behavior and current HUD lifetime tests pass. The latter
were rerun because the earlier concurrent UI review flagged a failure; the
current tests and their negative controls pass (`tmp/roster_ui_lifetimes.log`).

`[TOD_CYBER] START rev=4 appearance_slots=4_of_4` tracks all body families in
dev mode, with bounded spawn/damage/death logs and `ELITE_PROMOTE` recording
body/head/head-removed state. Normal matches register no tracking callback.
The expanded native appearance, gib behavior and new diagnostic revision still
need a playtest; offline pose checks and compilation cannot establish those.

Full build: `tmp/roster_integration/build.log`, exit 0. Main FF 149,784,704 bytes
at 21:58:51.007 Eastern; English companion FF 800,832 bytes at 21:58:53.085.
All 142 authored LOD binaries pass compiled geometry coverage. Trooper LOD0
has 23,687 triangles, Relay 24,503, Crown/Signal 25,181 and sprinter 9,298.
All original leg triangles remain; sprinter has eight native LODs.

The final snapshot/source/deployed comparison passes for all 316 inputs, with
no differences or deployed inputs newer than the FF. All expected models,
characters, aliases, gibs, materials and 25 atlas maps are present across the
main and English asset ledgers. Sprinter material dependencies are in the
English companion: checking only the `all` ledger gives a false missing-assets
result. The dependency report also confirms the model references its new
materials/maps. Before a Workshop publication, use the existing required
`-Publish`/`-AllLanguages` workflow to refresh every language companion.

Evidence: `tmp/roster_integration/input_snapshot.json`,
`deployment_verification.json`, `compiled_xmodels.csv`,
`verify_deployment.py`. Asset ledgers are linker outputs written after the
FF; their freshness is checked against the build window. Source inputs use
the stricter snapshot/hash and no-later-sync checks. Native visual and gameplay
verification remain pending with the user; no automatic launch was performed.

### Final shared-workspace build

After the full build passed, a peer changed `AetheriumLoadout.lua` and ran a
GSC-only build. The original snapshot correctly detected that source change;
the peer sync then retired the earlier generated ledgers. We did not overwrite
their edit or start a competing build. Captured a new source/deployed snapshot
during that link: all 316 files matched, with only that HUD file different
from the full-build snapshot. Every cyber input was unchanged.

Final artifact: main FF 149,784,384 bytes at 22:05:14.209 Eastern; English FF
800,768 bytes at 22:05:16.241. Both compiled-geometry checks pass again. All
316 snapshot/current-source/deployed inputs match, no later deployed inputs,
and no missing assets across both ledgers. Evidence:
`tmp/roster_integration/peer_input_snapshot.json`, `final_verification.json`.
This final report supersedes `deployment_verification.json`, which records
the intermediate detected HUD drift. No game launch; native retest pending.

## The Japanese fastfile (2026-09-16)

The v19.17 publish failed its `japanese` language pass on nine
`xmodel ... is missing` errors: `tod_cyber_trooper_body/_upper/_rarmoff/_larmoff`,
the four matching `tod_cyber_relay_*` and `tod_cyber_sprinter`. The linker drops
a `japaneseUnsafe` xmodel from that pass while the zone still names it.

The flag was inherited from the donors, not authored here:
`c_zom_der_zombie_body1` (trooper, relay) and `c_t8_zmb_mob_zombie_body3`
(sprinter). It is inconsistent in stock's own data - the sibling
`c_zom_der_zombie_body2` behind crown and signal is unflagged, and every
severed-limb gib derived here is unflagged while the intact bodies were not.
Accepting the exclusion would have left a Japanese client without two of the
four regular appearance slots and without the sprinter.

On the user's call the derived models ship unflagged.
`install_cyber_roster.py::block()` emits `japaneseUnsafe 0` as a recorded
override, only where the donor actually carried the flag and only for `xmodel`.
`verify_cyber_roster.py` allows that single non-cosmetic field, asserting both
the value and that the donor's flag was set, so the cosmetic-only guarantee
still covers every other field.

Re-running the installer was proven side-effect free: all 258 files under
`model_export/tod_cyber_zombie` were hashed before and after and **zero binaries
changed** - only the GDT and its manifest. Do not hand-edit
`source_data/tod_cyber_roster.gdt`; the verifier pins its sha256 against the
manifest, so a flag change means an installer change and a re-run.
