# Reference one — Blender MCP study

This is the detailed **art master** for the reference-one game conversion.
The user requested concentrating on
`CyberZombie1.png`, using the same upstream Blender MCP workflow as Tower II's
gold sword, and keeping Blender visible for live direction.

- Master: `reference_one.blend` (original Crown donor body, head and skeleton).
- Gallery: `review.html`, seven rendered views plus the supplied reference.
- Report: `validation.json`; original geometry/weights preserved, equipment
  follows head/arm/finger/leg joints in three sampled poses.
- MCP authoring scripts: `tools/cyber_reference_one/`.
- Logs: `tmp/cyber_reference_one_mcp/` contains actual MCP responses.

## Scope and visual design

The second reference pass adds actual purple hose emission with dark reinforcing
ribs, relocates the cyan forearm chamber about 60 degrees around the limb toward
its outer side, and replaces the generic leg plates with a compound knee cup,
outboard concentric bearing, overlapping ridged shin plates, one lateral cyan
rail, exposed hydraulic strut and ankle clamp. The hand and original donor are
preserved. `tmp/cyber_reference_one_pass1_checkpoint` retains the first master.

Powered left forearm, reservoir, side pistons, dual magenta feeds, a mechanical
palm and sleeves/hinges for every finger segment. Asymmetric layered shoulder
armor, over-shoulder webbing, open buckles, transverse chest belt, shock-mounted
ECG console, spinal cell and manifold, thigh reserve and left-leg exoskeleton.
The head has machined receiver housings, skull mounting rails, corrugated neural
loops, shaped cheek plates, a chin bridge and a fractured optical shield.

Equipment materials combine dedicated raster albedo sheets with procedural
roughness and normal relief: chipped enamel, oxidation, oil-dark steel,
directional scratches, woven webbing, rubber and uneven phosphor. The built-in
image_gen tool produced `textures/worn_steel_v1.png` and
`textures/chipped_enamel_v1.png`; exact prompts are in `textures/prompts.json`.
The returned sheets are 1254-square (the prompt requested 2048); they are used
at a fixed physical scale, embedded in the master, and copied into the project.
These are authored surface maps, not calibrated scanned PBR measurements or
already-baked game atlases. Beveled wear rims, captive fasteners, serial marks
and small mechanical fittings are actual geometry. Source zombie textures and
geometry remain intact, so its clothing, hands and proportions differ from the
concept sheet. This is not an exact recovery of an unseen 3D asset.

## MCP reproduction

The existing Tower II installation provides the upstream addon and isolated
Python environment. No external asset-generation service is used. Do not
connect to or replace the gold sword's session on port 9876.

1. Start Blender 4.2 with `--factory-startup --python
   tools/cyber_reference_one/mcp_bootstrap.py` (interactive, own port **9877**).
2. Use `tower_of_doom_II_hellbound/tmp/gold_sword_env/Scripts/python.exe`
   to run `tools/cyber_reference_one/mcp_call.py <script path>`.
3. Stages: `00_open.py`, `01_body.py`, `02_arm.py`, `03_head.py`,
   `04_refine.py`, `07_surface_finish.py`, `05_review.py`, `06_live_reference.py`,
   `08_textures.py`, `09_labels_and_webbing.py`, `10_reference_refinement.py`,
   then `05_review.py` again to refresh preservation and attachment checks.
   `01b_complete_body.py` only resumes the shoulder/leg section after the original
   first-pass shoulder ray reached above the torn sleeve; the full stage is fixed.
4. `mcp_call.py screenshot` captures the actual Blender viewport. Review these
   between modeling stages, alongside the saved studio renders.
5. `render.py -- <view>` under a separate background Blender reads the saved
   master without blocking the user's live session. Views: front, back, head,
   arm, chest, back_detail, leg.

Blender is deliberately left open. Do not reset the user's live scene or
control the other Blender session. No game files or game launch flags change.

## Game conversion

User approved native preparation on September 16. The exporter now handles
every original finger joint and both shoulders, preserves the stock mesh
objects and damaged variants, and produces seven equipment detail levels
(44,610 down to 1,776 triangles) with five 4096-square baked material maps.
The high-detail master stays editable. `game_preview/` contains studio renders
of the actual exported game binaries and maps, including the distance model.
Build and playtest status: [integration record](../../docs/148_reference_one_game_model.md).

## Integration history and remaining verification

This master is deliberately dense (see the current evaluated count in the
report). The master itself is **not the game mesh**. The conversion described
above supplies reduced meshes, baked maps, both shoulders, every finger region
and native damaged-limb exports. Source/compiled geometry checks gate the build.
Three pose checks verify attachment transforms, not absence of intersections.
Full moving-joint clearance, native shading and horde performance are untested.
