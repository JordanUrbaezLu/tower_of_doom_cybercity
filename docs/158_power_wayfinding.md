# Power route decal review

2026-09-23. User reported too many arrows and requested a review of the full
downloaded pack and a more meaningful layout.

## Pack audit

Both the installed DOGCANARY GDT and the downloaded
`Images arrow coldwar dogcanary (1).rar` provide eleven decals. The pack's
`arrows.png` contact sheet was inspected along with the original POWER,
STAIRS and two arrow PNGs. Material suffixes do **not** match texture suffixes.

| Material | Texture suffix | Actual artwork | Use |
| --- | --- | --- | --- |
| `arrow_power_coldwar` | `01` | Curved right arrow | Turn around the power entrance wall |
| `arrow_power_coldwar1` | `05` | POWER | Entrance, hall reassurance, switch |
| `arrow_power_coldwar2` | `03` | Rising right arrow | Beside the real stair entrance |
| `arrow_power_coldwar3` | `11` | Family | Not a destination here |
| `arrow_power_coldwar4` | `02` | Straight left arrow | Removed from this route |
| `arrow_power_coldwar5` | `06` | ENGINE | No engine room here |
| `arrow_power_coldwar6` | `07` | VENT | No accessible vent here |
| `arrow_power_coldwar7` | `08` | STAIRS | Beside the real stair entrance |
| `arrow_power_coldwar8` | `09` | Assemble | No assembly objective here |
| `arrow_power_coldwar9` | `10` | PASSWORD | No password objective here |
| `arrow_power_coldwar10` | `12` | STOLEN | Not a destination here |

Shared source: `model_export/codimages/arrow_coldwar_dogcanary/` under Mod Tools;
unchanged PNGs: `model_export/_modelos_dogcanary/arrow_coldwar_power/`.
No new material or texture assets, shader edits, added lights or zone rows.
World mesh materials are linked through the freshly compiled BSP.

## Revised placement

Authored in the POWER / STAIRS WAYFINDING block of `tools/gen_tower_map.js`.
The six old meshes (two POWER words, four identical left arrows) become six
meshes using four artworks, with only two arrows serving two separate entrances.

| Location | Artwork | Centre / bounds | Reading direction |
| --- | --- | --- | --- |
| Arena side of power room wall | POWER, 128 x 64 | Centre `(416,-398,64)` | Facing south |
| Same wall, near doorway corner | Curved right arrow, 64 x 64 | Centre `(316,-398,64)` | Points west to the doorway around the wall's end |
| Straight hall midpoint | POWER, 112 x 56 | Centre `(960,-538,64)` | Facing south; one reassurance word |
| Directly above switch | POWER, 64 x 32 | `x=1618`, `y=-512..-448`, `z=96..128` | Facing east, head-on at the destination |
| Core beside first stair gate | STAIRS, 112 x 56 | Centre `(156,-258,80)` | Facing north |
| Same core wall, next to word | Rising right arrow, 36 x 36 | Centre `(234,-258,80)` | Points east/up toward the stair entrance |

The switch prefab's clip ends at z=94; its new sign starts at z=96. Both
stairs signs remain on the solid core wall, not the sliding door. The hall
teddy, door triggers, player collision, lights and continuous floor route
are unchanged. No signs point beyond the switch or repeat arrows down the
straight hallway.

The word art's top/bottom quarters are fully transparent (alpha max 0, checked
for POWER and STAIRS). Word quads crop those empty quarters using V=-256..-768
instead of 0..-1024 and use a 2:1 shape, preserving the lettering's original
aspect. Arrows retain their full square texture. The original material's glow
is unchanged; the native visual result is for the user to test.

## Verification and evidence

`tmp/power_decals_20260923/review_layout.py` reads the generated map, checks
quad normals, supporting wall bounds, word aspect, switch clearance and
non-collision. At the initial decal regen, removing only the six decal blocks
yielded a byte-identical map to the backup; all four generated gameplay GSC
files also matched. That report is preserved as `layout_verification_initial.json`.
An independent door-width update subsequently regenerated the shared map;
`--layout-only` rechecked the six decals on that version without claiming its
other map changes belong to this task. The final build snapshot covers both.

The same script generates `tmp/power_decals_20260923/layout_preview.html` with
embedded original art at the emitted sizes. Its captured PNG is a flat wall
layout reference, **not** an in-game lighting/rendering claim.

The first full build was rejected for unexpected linker errors while producing
the language files, including a missing `zone_source/loc` input. Its source
snapshot also became stale as door/HUD work landed in the shared workspace.
A fresh full retry passed at 17:51:33 Eastern with a 147,342,720-byte fastfile.
All 384 snapshotted inputs match deployment; complete scripts/UI/zone trees
match and no source was synced after the FF. All four decal materials and
their images appear in assetinfo, the old straight-arrow material is absent,
and the missing-shader gate passes. Loaded/streamed sound banks are
68,465,920 / 207,523,840 bytes. Ten existing waived linker errors only;
the unexpected language errors did not recur. Complete stage output is saved
as `stage_*.log`, and `deployment_verification.json` records the final checks.
Native appearance unplayed; no agent game launch. Opened the preview image on
the user's computer at their request.
Backups, pack contact sheet, layout audit, build input snapshot and build log
are under `tmp/power_decals_20260923/`.
