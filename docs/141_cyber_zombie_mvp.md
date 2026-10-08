# Cybercity zombie MVP

**Superseded by the full roster:** all four regular slots and the armored
sprinter are now integrated and built. Current validation/build status is in
[docs/144](144_cyber_zombie_roster.md). The sections below retain MVP history.

Status: user approved enabling the existing cyber mix in ALL modes. Source
change and checks pass; build pending while BO3 runs. The missing-legs fix was
BUILT at 20:30:00 Eastern with source and compiled geometry checks passing.
The prior 19:42:50 Eastern build is the broken-legs version.
User approved continuing after the offline preview. One regular-horde appearance
slot uses the cyber variant; native testing remains with the user. Build and stop,
without relaunching, is still the latest operational instruction.

## Native integration

### Missing legs: export object table

The original installer loaded stock binaries with `split_meshes=False`.
PyCoD flattened the mesh list but retained the original face object IDs. The
intact body has four stock objects, with all 6,520 lower-body triangles on
object 3. The export declared only three objects (flat donor + chest + arm),
so BO3 silently discarded the legs. The left-arm-loss torso also lost its
224-triangle gear strap. A flat Blender render and the original flat checker
concealed the invalid object table even though all vertex data existed.

Installer now preserves the donor objects with `split_meshes=True`, appends
kit objects after them, and verifies the binary round-trip. All 36 exports
pass per-object names/counts, original vertices/faces/materials/UVs/colors/
normals/weights and original skeleton checks. The intact LOD0 body has six
valid objects, including the complete original lower-body mesh. The preserved
broken binary is rejected by the structured loader. The preview renderer also
validates object structure before flattening; source checks gate every build.

`tools/verify_cyber_zombie.py --compiled-ledger <fresh xmodel CSV>` additionally
checks native triangle coverage across all authored LODs, allowing only a few
converter-removed degenerate faces. It requires the intact body to retain all
6,520 leg triangles above the torso-only variant. Pre-fix native ledger proves
the intact body and upper torso both compiled to 18,661 triangles at LOD0.
Evidence: `tmp/cyber_leg_fix/before_xmodel.csv`, `broken_body_lod0.xmodel_bin`.

Replacement full build passed at 20:30:00.098 Eastern: 149,659,904-byte FF,
188 identical deployed inputs, no newer inputs or missing cyber assets. Fresh
native ledger has intact body 25,181 triangles vs upper torso 18,661: all 6,520
leg triangles survive conversion. All 36 authored LODs pass compiled coverage;
left-arm-loss LOD0 also recovers its 224 gear-strap triangles. The old native
ledger fails the same coverage check. Evidence: `tmp/cyber_leg_fix/build.log`,
`after_xmodel.csv`, `deploy_verification.json`, `old_ledger_negative_check.log`.
Both source and compiled coverage now gate future builds; the compiled gate
was added while this build was running and executed separately against its
fresh output. PowerShell parse check passed. No game launch or gameplay edits.

The user's playtest logs were preserved under
`tmp/cyber_leg_fix/logs/20260915_201859_996_1ddca90d/`. They confirm `[TOD_CYBER]`
spawn, damage-model state and death diagnostics, including intact, arm-loss
and upper-torso states. This proves the diagnostics run; it does not establish
visual correctness of animations, dismemberment or ragdolls. Native visual
retest of the corrected build remains with the user. Keep the dev-only gate
and normal native dismemberment; neither caused the missing legs.

### Appearance in all modes

User approved: "Okay we can enable now fully" after the missing-legs fix.
The entry script installs `ignore_spawner` before `zm_usermap::main()`;
stock `_zm_spawner::init` consumes it before registering spawn callbacks.
It now always retains the cyber factory and excludes the stock alternative,
regardless of whether `tod_dev` is false, unset or true. The existing BSP's
`tod_cyber_dev` marker is historical and no longer restricts appearance.
Keeping markers and entities avoids an unnecessary geometry rebuild.

The cyber appearance remains one of four regular-horde slots (roughly 25%),
now in normal matches too. Normal rounds and finale reinforcements use the
same filtered factory list. Models, AI, health, damage, animation, native gibs
and elite promotion are unchanged. Diagnostics alone stay dev-only; normal
matches do not register the tracking callback or its per-zombie loops.

`node tools/test_cyber_zombie_spawns.js` exercises the shipping predicate with
off/unset/on, both factory orders and unrelated factories; exactly one factory
survives. It verifies bootstrap timing, map markers, dev-only diagnostics and
intact-head guards for elite promotion. A negative control reinstates the old
restriction and proves ordinary matches would fail. It gates every build.
Dev START diagnostics rev=3 report `dev_only=0`. All 36 exported models still
pass structure/rig/geometry checks. Build is pending while the native King
playtest runs; do not interrupt it. No new native match launched for this work.

### Assets

`source_data/tod_cyber_zombie.gdt` copies a map-owned character and AI spawner
from the resolved stock factory settings. Only appearance slot four changes (approximately
one quarter of ordinary spawns). Health, attacks, animation tables, sounds,
hitboxes, movement and ragdoll definitions are copied unchanged.

GDT bracket inheritance only resolves parents within the same file. The first
build rejected cross-file parents; the installer now serializes all resolved
donor settings before applying cosmetic overrides. The checker compares every
serialized field with the donor plus the explicit overrides, and all 14 copied
asset definitions were confirmed present in the updated Mod Tools database.

The BO3 converter also rejects collapsed bevel triangles that Blender renders
past. Export now omits zero-area triangles and validates nonzero unit normals;
994 invisible triangles were removed across all kit LODs. The kit uses
`Geometry Advanced / lit_emissive_advanced_fullspec`: the earlier
`lit_emissive_plus` shader ignores specColorMap even with specMapEnable set.
The installed fullspec techset explicitly consumes it as semantic specularMap.
A second build's link
step was stopped when a Tower II linker started during our lighting bake; only
our own build processes were stopped. Logs: `tmp/cyber_zombie_build.log`,
`tmp/cyber_zombie_build2.log`, `tmp/cyber_link_interrupted.log`.

Full build 3 passed at 19:24:05 Eastern, with a fresh 149,656,960-byte FF and
188 matching deployed inputs; no mismatches or newer deployed inputs. The
asset ledger included every model, character, gib definition and script, plus
four textures. That check caught the ignored specular map and prompted the
fullspec shader fix above. Build 4 stopped before syncing because BO3 started
again. The fullspec fix was still pending then; the final build below
supersedes that status. Evidence:
`tmp/cyber_zombie_build3.log`, `tmp/cyber_deploy_verification.json`,
`tmp/cyber_zombie_build4.log`.

Final full build: `tmp/cyber_zombie_dev_build2.log`, exit 0, fresh FF at
19:42:50.922 Eastern, 149,766,592 bytes. Navigation passes for both towers.
Dev-gate, weapon, bat and GSC checks pass. `tmp/verify_cyber_deploy.py` confirms
188 matching deployed inputs, no later input timestamps, and all expected
models, character/spawner/gib assets, script and five atlas textures present.
Result: `tmp/cyber_deploy_verification.json`. No native game was launched.

Shared-tools note: the first dev build stopped on optimization drift in
installed `xmas_gun_fx.gdt` and `chaos_pack_a_punch.gdt`. Their text matched
recorded originals; the only semantic differences from staged outputs were
the previously approved texture-deduplication aliases. Restored those outputs,
and the 260-file optimization check passed. A Tower II build subsequently
replaced those two installed files with original versions again during our
bake. Repository files and the final cyber deployment remain verified. This
shared-file drift can fail a future optimization preflight; review it against
the existing recovery manifest rather than overwrite unrelated authoring.
Audit helper: `tmp/audit_cyber_build_asset_drift.py`.

The optic/receiver, crown chest module and forearm brace are baked into native
model meshes, not separate runtime entities. Five 1024 texture atlases carry
color, normal, specular, gloss and emission. Cloth derives the stock shader,
retaining its damage/reveal behavior with a charcoal tint.

Body, head, clean upper torso and both arm-loss torsos have seven LODs. The
left-arm-loss torso excludes the brace; a derived detached left limb carries
it. Four leg damage variants share the stock meshes with the new cloth material.
The head is a separate native head model, so normal head removal also removes
the implant. The stock neck collar remains inherited. Promoting a cyber zombie
to an armored sprinter restores its intact stock head before the existing body
swap; a removed head is never recreated.

`_tod_cyber_zombies.gsc` adds bounded dev diagnostics under `[TOD_CYBER]` for
spawn, model/gib state changes, death and elite head restoration. These run only
with `tod_dev`; representative native output is preserved in the missing-legs
investigation above.

Authoring/export commands, run in order after an art edit:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.2\blender.exe' -b art/cyber_zombie_mvp/cyber_zombie_mvp.blend --python tools/export_cyber_zombie_kit.py
python tools/install_cyber_zombie.py
python tools/verify_cyber_zombie.py
& 'C:\Program Files\Blender Foundation\Blender 4.2\blender.exe' -b art/cyber_zombie_mvp/cyber_zombie_mvp.blend --python tools/render_cyber_zombie_export.py
```

Exporter writes repo assets only. The normal sync copies the new model folder
and GDT into Mod Tools; the map generator selects the derived actor spawner.
The export manifest records stock donors and SHA-256 hashes for all 36 new
binaries and five atlases. Validation reads binaries back and compares original
bone names/parents/bind matrices, positions, weights, normals and UVs. It also
checks LOD and damage-model coverage and cosmetic-only AI overrides.

Export validation and GSC arity checks pass. Existing bat balance/fling checks
pass. `export_front.png` and `export_lod3.png` were rendered from exported
binaries and baked maps, then visually inspected; they still use Blender studio
lighting and are not in-game captures. Native checks still needed: actual map
lighting, animation, head/limb removal, crawlers, detached brace placement,
ragdolls/bat fling and the logged state transitions.

## Deliverables

- `art/cyber_zombie_mvp/review.html`: original/prototype comparison and views.
- `art/cyber_zombie_mvp/cyber_zombie_mvp.blend`: editable model, original rig,
  packed source textures, separate named additions, lights and camera.
- `prototype_front.png`, `prototype_detail.png`, `prototype_side.png`,
  `prototype_back.png`, `original_front.png`: actual Blender renders.
- `manifest.json`: original asset hashes, geometry counts and limitations.
- `rig_check.json`: evaluated-mesh checks, generated by the checker below.

## Design and sources

The user's supplied reference guides the small illuminated implants and worn
metal. Prototype: asymmetric cyan optic with a temple receiver/cable, graphite
forearm brace, breast module with a raised brass crown and an amber status light,
and a charcoal tint on the existing uniform material.

Installed stock BO3 sources, read-only:
`model_export/t7_characters/zombies/zombies/c_zom_der_zombie_body2_lod0.xmodel_bin`
and `c_zom_der_head_1_lod0.xmodel_bin`. Original textures remain packed in the
Blender file. The skeleton is the union of the original body and head bones;
the latter includes the eye/facial bones absent from the body. Original base
mesh coordinates, UVs and weights are retained. New pieces have explicit
single-bone weights on the existing head, chest and elbow bones.

The offline prototype uses the factory spawner's Der Riese model family as its
art donor. The native integration above now derives that spawner for this map.

## Reproduce

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.2\blender.exe' -b --python tools/cyber_zombie_mvp.py
& 'C:\Program Files\Blender Foundation\Blender 4.2\blender.exe' -b art/cyber_zombie_mvp/cyber_zombie_mvp.blend --python tools/check_cyber_zombie_mvp.py
```

The installed BetterBetterBlenderCOD PyCoD reader decodes the original meshes.
The generator builds Blender meshes and materials directly and writes only to
the repository's art directory. It caps CPU rendering to eight threads.

## Offline prototype validation

Final offline validation: 35 attachment objects, 7,132 attachment triangles,
26,907 base triangles, 118 original body/head bones and 12 packed textures.
Rest, head-turn, arm-flex and torso/leg poses pass the evaluated-mesh check;
maximum attachment error is below 0.000016 source units. The saved Blender
file and manifest agree. Final render log: `tmp/cyber_zombie_mvp_final.log`;
checker exits 0 in `tmp/cyber_zombie_mvp_check_final.log`. The five final views
were rendered from the same prototype; the original comparison disables the
additions and restores the original cloth material under matching lighting.

The original previews use studio lighting and procedural Blender materials.
The integrated export above bakes those materials and merges geometry by
material while retaining bone assignments. The original authoring manifest
describes the offline source, not the subsequent native integration.

Offline bone checks do not prove BO3 animation compatibility, head loss,
limb loss, crawlers, ragdolls or bat fling. All remain native checks. Do not
solve dismemberment by disabling it on ordinary
zombies. Preserve elite identities when selecting the regular-horde variant.

No game launch: the user's latest operational direction is build and stop,
with the user handling native testing. Native integration requires a full build.
