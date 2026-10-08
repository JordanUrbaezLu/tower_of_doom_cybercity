# Fire/lightning head assembly and dev class caps — September 27, 2026

The user reports fire/lightning parts and crystals still looking wrong after
the other AI's first-person attempt, and asks for complete models if needed.
Ice is explicitly accepted in both views. They also want whichever class they
pick in dev mode fully maxed for testing.

## Actual starting point

The notes in docs/164 still said pass 2 was unbuilt. The actual
`tmp/staff_crystal_20260927/build_pass2.log` says BUILD OK, FF September 27
14:31:10, 147,408,448 bytes, 113 referenced models linked. The first-person
separate crystal was already in that build. Do not diagnose this as merely
an unbuilt first-person fix. Latest user log archived with capture_ai_logs.ps1
under `tmp/staff_repair_20260927/user_logs/`.

The head and shaft meshes are the actual BO3 Chronicles exports. This repair
uses those original parts; it does not invent replacement shapes. Online
in-game comparison images were inspected from the
[lightning guide](https://guiascodzombies.com/black-ops-iii/origins-bo3/baston-electrico-mejora-bo3/)
and [fire guide](https://steamcommunity.com/sharedfiles/filedetails/?id=950070059).
Local source geometry remains the authority for the model parts.

## Complete head models

`tools/build_staff_assembly.py` generates six native binaries and
`source_data/tod_staff_assembly.gdt`: fire/lightning × view/world/packed.
Each contains the original complete head plus its original crystal mesh.
The crystal vertices bind directly to the head root (`tag_tip_<element>`).
Both source roots share a zero/identity pose, so no vertex repositioning is
needed. Original head bones, vertices, triangles, UVs, normals and weights are
preserved; the raw export round trip introduces at most sub-0.00001-unit
float differences. Object/material indices are rebuilt for the appended mesh.

The existing, rendered head attachment now owns the crystal too. This avoids
relying on a second attachment with an unkeyed root, the unproven part of
pass 2. It also makes the crystal follow the lightning first-raise spin exactly.
The cause of the native pass-2 disappearance remains an inference; this repair
removes that separate attachment path structurally.

`staff_presentation_bindings.py` routes the base slot 1 and packed gmod6 model0
to these complete heads. Base slot 2 and packed model1 are empty. Shafts,
first-person clips, hand placement, third-person pose/mount, gameplay fields,
element colors and the pass-2 crystal materials are retained. Ice's complete
GDT blocks are identical before/after, and its asset manifest check passes.
No weapon registrations are added.

The first package exposed inherited automatic LOD reduction settings: six
levels, down to 4% geometry (152/235 triangles for the fire/lightning view
heads, versus 3,828/5,884 at full detail). Automatic LOD generation is disabled
on the six complete heads. Each must compile as one full-detail LOD; the
compiled gate rejects reductions or incomplete geometry. This protects the
small crystal and cage details without changing accepted ice assets.

`docs/staff_assembly_manifest.json` pins source/output hashes and component
counts. The existing staff build gate calls `build_staff_assembly.check()`;
sync includes `model_export/tod_staff_assembly`. Idle animation audit: original
fire local shape error <0.000001 units; lightning <0.00274 units. The source
crystals remain part of the head under every root transform, including spins.
`art/staff_assembly/geometry_review.blend` and `.png` review the actual binaries
with neutral studio materials; they are not game-rendered texture/FX previews.

## Dev mode: selected class at maximum

The user supersedes the September 15 preference that removed maxing from the
dev bundle. `_tod_main.gsc` now starts the existing maxed grant when `tod_dev`
or its independent `tod_dev_maxed` flag is set. The normal class draft remains.
The grant waits for the initial card pause to finish, skips the Mage preview
dummy, and uses the real tier/PaP/domain primitives. It does not force Mage,
grant perks, warp the player or alter normal non-dev progression.

`[TOD_DEV_MAX] BEGIN`, `CAP_MISSING`, and `READY`/`INCOMPLETE` record player,
chosen class, actual tier, eligible domain count and missed caps. The result
wrapper cancels on death/disconnect/end-game. The existing staff-only test
branch remains available but is not armed. `test_dev_maxed.js` executes the
shipping grant/wrapper with native services mocked for all five classes,
Mage tier unlock ordering, ship/dummy exclusion and incomplete-tier reporting.

## Verification and native test

Source gates pass: staff model/animation/attachment validation, existing dev
preview lifecycle, new five-class maxing tests, script arity, and inducer
liquid verification. `tmp/staff_repair_20260927/field_diff.json` proves only
fire/lightning attachment fields changed in existing GDTs.

Full build passed September 27, 2026, 15:21:26 Eastern: FF 147,492,608 bytes.
All 1,373 snapshotted inputs match source and deployment, nothing synced after
the FF. All six complete heads have one LOD and exactly their source triangle
counts: fire 3,828 / 2,712 / 2,712; lightning 5,884 / 4,038 / 4,038
(view/world/packed). All 109 referenced weapon models linked; zero missing
shaders; only the ten established waived asset messages. Complete sound banks
are 68,465,920 and 207,523,840 bytes. Evidence:
`tmp/staff_repair_20260927/build_final.log`, `deployment_receipt.json`, and
`deployment_verify.log`. The first build's inherited generated LODs and failed
gate are preserved in `build.log` and `initial_xmodel.csv`.

User tests; no game launch. Check fire/lightning base and
packed in first person (idle, firing, reload, switching, equip spin) and on the
dev preview player. Check the selected class reaches tier 3 and the pause menu
shows its upgrade caps; archive the console and look for `[TOD_DEV_MAX] READY`.
The accepted golden inducer liquid is retained in this build.

## User follow-up: protruding side pieces (15:30 screenshots)

The fire screenshot shows the perforated side blades; lightning shows four
thin outward spikes. These are present in the imported T7 upgraded head
sources, not newly generated geometry. The base heads lack the extended
silhouette. The geometry review's upgraded column shows the same parts.
A retail Origins screenshot independently confirms the fire side blades:
https://images.steamusercontent.com/ugc/12105797795301879396/BB2382A459FACEB80860CA6B76FD6FC584BAE111/
Saved at `tmp/staff_edges_20260927/fire_retail.jpg`.

The archived user console under `tmp/staff_edges_20260927/logs/` confirms
`integrated_crystals_1` and `TOD_DEV_MAX READY player=0 class=mage tier=3
domains=14 missing=0`. Dev maxing gives the upgraded appearance immediately.
No asset change/build made for this question: side extensions themselves are
intentional. This does not certify all first-person framing, materials or FX
as retail-identical. Earlier coverage checks prove preservation, not visual
accuracy; report those limits explicitly.
