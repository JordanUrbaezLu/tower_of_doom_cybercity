# Reference-one Blender MCP model: game integration

Status: full build passed September 16 at 12:46:04 Eastern. Main fastfile
149,992,000 bytes. All 233 authored cyber binaries pass source and compiled
geometry coverage; 407 snapshot/source/deployed inputs match, no later synced
inputs and no missing assets. Built and stopped. Native playtest is the user's.

## Scope

The approved master is `art/cyber_reference_one_mcp/reference_one.blend`, stage
`10_reference_refinement`. It retains the stock Crown body and head with worn
cyber equipment, full mechanical left hand, outboard cyan forearm reservoir,
emissive purple plumbing, layered leg brace and both shoulder assemblies.

User authorized finishing this model and preparing it for their own in-game
test. No launch, test harness or gameplay changes are part of this pass.
Dev, god mode and open doors remain off. The previous native assets and bake
inputs are retained in `tmp/reference_one_integration_backup`.

The Crown body is also shared by the existing Signal character. Native head
randomness stays unchanged; the new reference-one head is one of the existing
bare-head choices. Other head designs, helmet kits, Trooper, Relay and armored
sprinter assets are preserved. This is one completed reference design, not an
art replacement for the full roster.

## Conversion

`tools/export_cyber_zombie_kit.py` supports the MCP master directly. It evaluates
its beveled geometry at bind pose, reduces the equipment silhouette, unwraps a
shared 4096-square atlas and bakes color, tangent normal, specular, gloss and
emission. Linked shader channels and relative emission strengths are retained;
the native fullspec material uses its existing emission scale of six. This
master uses tighter UV packing than the older kit: the first 2048 bake gave
small parts too few texels and visibly blurred the approved weathering. Other
roster atlases remain 2048. Native texture memory rises for this detailed kit;
the build's asset ledger is the source for actual converted sizes.

Seven equipment levels contain 44,610 / 27,464 / 12,050 / 7,705 / 4,350 / 2,702 /
1,776 triangles. These counts exclude the untouched stock zombie geometry.
Small disconnected fasteners and lettering retire at distance; each anatomical
region keeps its largest component. Reduction runs per connected part with a
24-triangle floor, preserving flat displays and solid housings. Reducing an
entire region at once had collapsed some of those silhouettes. The dense
editable master is preserved.

The first compiled coverage check rejected 54 silently discarded triangles in
the intact body, 44 of them on mechanical finger parts. These were microscopic
collapse remnants: the export now removes edges shorter than 0.001 units or
triangles with altitude below 0.0005 units. This cleans equipment only and leaves
the strict compiled-coverage tolerance and every stock face unchanged.

`cyber_equipment_layout.py` now distinguishes the full Crown hand from the old
Relay hand. All fifteen original finger joints and the right shoulder export.
Forearm and hand equipment leave with the native arm gib; knee/shin equipment
leaves with the leg gib; shoulders and thigh equipment remain at the stock cuts.
No extra runtime entities, animations, physics definitions or collision are added.

The stock object tables are preserved, including all 6,520 lower-body triangles.
All seven body LODs contain the original finger bones needed by this hand.
Source validation covers 65 Crown/shared binaries plus 168 other roster binaries.

## Reproduce and verify

1. Run Blender in background with the MCP master and
   `tools/export_cyber_zombie_kit.py` (leave the interactive MCP session open).
2. Run `python tools/install_cyber_zombie.py`.
3. Run `verify_cyber_reference_sources.py`, `test_cyber_equipment_layout.py`,
   `verify_cyber_zombie.py`, `verify_cyber_roster.py`, and the spawn test.
4. Render the actual binaries with `tools/cyber_reference_one/render_game_export.py`.
   Images go to `art/cyber_reference_one_mcp/game_preview/`.
5. With BO3 and other build tools stopped, snapshot inputs using
   `python tools/cyber_reference_one/verify_deployment.py --snapshot`.
6. Run `tools/build_map.ps1` for a full build. Both compiled triangle-coverage
   gates must pass. Then run `tools/cyber_reference_one/verify_deployment.py`.

Evidence lives in `tmp/reference_one_export.log`, `tmp/reference_one_install.log`,
`tmp/reference_one_game_render.log` and `tmp/reference_one_integration/`.

## Native playtest

Check the purple/cyan finish under map lighting, wrist and finger flexion,
head turns, limb removal/crawlers, bat ragdolls and horde frame rate. Studio
renders and static/compiled checks do not prove clip-free native motion or
measured runtime performance. The user handles this playtest.
