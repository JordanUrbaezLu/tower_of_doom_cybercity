# Model surface glow correction - September 27, 2026

The user requested the same correction as Cybercity II's teleporter, then
explicitly selected: remove the displaced glow and keep the colored lights.

Six native `lit_emissive_advanced_fullspec` materials now explicitly set
`waterRoughness` to zero: `mtl_tod_cyber_kit`, the four `mtl_tod_roster_*`
equipment materials (trooper, signal, relay, sprinter), and `mtl_tod_altar`.
The installed techset maps this surprisingly named field to `layerDepth`,
shown as **Emissive / Depth** in the material editor. Omitting it inherited
the native 0.1 depth, unsuitable for these surface-aligned atlas lights.
Cybercity II's reference is `tools/teleporter/repair_surface.py` and its
`tools/art_cohesion/profiles.py` teleporter profile.

Only that field changes in the three generated GDTs; the corresponding
installers emit it and existing build validators require it. Installation
manifest hashes were refreshed without regenerating the meshes. All 296
model/texture inputs are hash-identical. Emission maps, colors, brightness,
gloss, reflection settings, rigging, damage variants and gameplay are retained.
The altar's original animated interior and transparent wings are untouched;
the wings already specify zero for this field and use a different shader.
Do not reinstate the rejected all-matte altar finish.

Evidence: `tmp/surface_glow_20260927/source_receipt.json`, source validation
logs and `build.log`. This is a static material correction; server logs cannot
observe native shader displacement, so no gameplay logger is added.

Validation: all source and compiled checks pass (65 MVP binaries, 184 roster
binaries, and seven altar LODs). Read-only native database inspection confirms
all six materials changed from depth 0.1 to zero, preserving scaleRGB 6 for
equipment and 8 for the altar. Database evidence: `native_db_before.json`
and `native_db_after.json` under `tmp/surface_glow_20260927/`.

Full build passed: September 27, 2026, FF 13:46:32 Eastern, 147,402,624 bytes.
The final build includes the inducer repair and concurrent validated staff
crystal update. All 504 snapshotted source files equal their deployed copies;
no inputs synced after the FF; both sound banks complete (68,465,920 and
207,523,840 bytes), only the ten established waived linker messages.
Evidence: `tmp/inducer_20260927/build_final.log` and `deployment_receipt.json`.
The initial guard rejected a build during the user's match; later attempts
encountered a recovered WAV checksum flake and concurrent staff source changes.
No game launch or input from the agent.
The user's next playtest should check the equipment and altar while moving
the camera: colored lights should remain attached to their actual surfaces.
Native appearance is not verified by source/build checks.
