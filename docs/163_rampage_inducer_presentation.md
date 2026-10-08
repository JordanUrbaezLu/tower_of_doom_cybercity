# Rampage Inducer presentation repair — September 27, 2026

## Playtest follow-up: restore the glowing liquid

The user played the 13:46 build: the model looks better, but the liquid was
lost. Their archived console confirms `clear_chamber_1` and multiple ON/OFF
transitions. The first pass attenuated the broad liquid texture to 2.5/6% and
used only 8..32 alpha, making the fill too faint.

Revision `amber_liquid_2` restores the original BO6 yellow-gold energy sheet
at full strength inside and 55% on the outer layer, retaining the moving
strands. Neutral emission tints retain its authored color. Inner opacity now
ranges 84..138/255 and outer opacity 22..54/255, keeping the crystals visible.
Only four liquid PNGs change; native model, GDT, metal, normals, crystals,
gauge, original OFF/ON brightness multipliers and runtime FX are hash-identical.
The existing dev log identifies the new revision; source checks now require
visible golden emission and appropriate opacity, as well as asset hashes.

Evidence: `tmp/inducer_liquid_20260927/` (archived user log, changed-asset and
color receipts, backups, install/preview/build logs). The log also contains
separate bot-combat and Mage CSC errors; no inducer exception accompanies the
confirmed state changes. Those unrelated scripts were not changed here.

Source checks and Blender preview pass. Our initial build guard stopped
before sync because a new user session began. The other staff pass then
built the same liquid update at 14:31:10 Eastern (147,408,448-byte FF).
The next archived console confirms `amber_liquid_2`, and the user accepted
its appearance ("it looks great") before requesting the staff repair in
docs/165. Keep this liquid unchanged. The user tests; no agent game launch.

## First repair and original build evidence

User supplied a retail-reference screenshot and an in-game screenshot of the
opaque red cylinder and orange metal edges. The canister is the correct BO6
asset; its material conversion and assembly needed repair.

Reference: [official BO6 Zombies deep dive](https://www.callofduty.com/blog/2024/08/call-of-duty-black-ops-6-zombies-deep-dive-terminus-map-intel),
Rampage Inducer section. The official image shows a dark clear idle chamber
containing orange shards, with much brighter gold energy while active.
Saved reference and original native inputs: `tmp/inducer_20260927/`.

The original five exported CAST assets are retained. Their four crystals had
been joined in dump-local coordinates below the chamber. `tools/inducer/geometry.py`
assembles them inside the chamber and grounds the feet. These are reference-guided
placements, not recovered retail transforms. Canister topology and UVs are
retained: nine meshes, 32,847 triangles, one tag_origin bone, shared by both states.

`tools/bo6_extraction/install_inducer_bo3.py` now decodes packed surface normals
(X=alpha, Y=green; reconstruct Z) and extracts gloss from red. Fluid distortion
is already ordinary XYZ and is retained. Restrained specular/probe settings
replace the harsh reflections. The small named glass mesh is the instrument
face, not the chamber; it receives the source red indicator emission.

Both actual chamber meshes use native `lit_emissive_scroll_transparent` with
low alpha, the source gold palette, faint smoke and narrow moving energy
strands derived from the exported reactive lookup. This is an adaptation to
BO3's available shaders, not an exact recreation of the retail layered shader.
All twelve materials explicitly set zero emission depth. Idle emission stays
lower than active; existing native active sparks and pulsing lights remain.
Gameplay, interaction, placement logic and audio are unchanged.

The source manifest is `art/rampage_inducer/install_manifest.json`.
`tools/inducer/verify.py` checks hashes, materials, chamber alpha, decoded normals,
mesh counts, grounding and crystal containment. The full build runs this gate.
The existing dev logger records `MODEL revision=clear_chamber_1` and retains
its activation/state logs for the user's test.

Live Blender MCP imported the actual source casts, exported the installed native
binary, then reconstructed a review from that binary and its GDT/textures.
`art/rampage_inducer/native_review.blend` and `native_review.png` show OFF/ON.
Blender lighting is illustrative: native shader brightness, transparency sorting,
scrolling and runtime FX still require the user's playtest. Do not launch the game.

Full build passed: September 27, 2026, FF 13:46:32 Eastern, 147,402,624 bytes.
All 504 snapshotted inputs match source and deployed files, with nothing synced
after the FF. Native database confirms the four chamber state materials use
the transparent scroll shader and all twelve inducer materials have zero depth.
Both compiled models contain 32,839 triangles (99.97% of the 32,847 source
triangles; six source faces have exactly zero area). Both sound banks are
complete: 68,465,920 and 207,523,840 bytes. No missing shaders; 111/111 referenced
weapon models linked; only the ten established waived linker messages.
Evidence: `tmp/inducer_20260927/build_final.log` and `deployment_receipt.json`.
The first full link hit the known WAV checksum flake. A retry restored audio
but caught concurrently edited staff crystal definitions after the original
sync. The final full build includes that validated update. User playtest pending.

For the user's test, inspect OFF from front and side: dark metal, visible internal
crystals, a clear chamber and feet on the floor. Activate it and check moving gold
energy, sparks and a clear brightness increase. Move the camera around the altar
and equipped zombies to check that their colored light details stay on the mesh.
Afterward, archive `console_mp.log` using `tools/capture_ai_logs.ps1`; look for
the revision marker and the existing `[TOD_RAMPAGE]` state changes. Logs can
confirm state changes, but screenshots/player observation establish appearance.
