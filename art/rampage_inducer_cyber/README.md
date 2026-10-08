# Cyber Rampage Inducer — live Blender studio

The editable master is `rampage_inducer_cyber.blend`. It opens in **Rendered**
EEVEE with the studio's lights, bloom and the animation playing; full record and
pipeline: [docs/168](../../docs/168_cyber_rampage_inducer.md).

## Looking at it

* **Centre = OFF**, **left = ON** (a live instance carrying `rampage_on = 1`,
  with its own four-times-faster moving parts). Labels on the floor.
* Press **Space** to play/pause the motion; the timeline (0–359, 30 fps) is one
  idle loop = four ON loops, so it loops without a seam.
* Cameras (Ctrl+Numpad 0 on a selected camera): `camera OFF and ON` (default),
  `camera hero` (close three-quarter), `camera player eye` (what a player
  standing in front sees). Middle mouse orbits; Numpad 0 returns to the camera.
* The floor, the wall behind it, the cyan pilaster to the right and the
  teleport-bay doorway gap to the left are the real arena corner it stands in
  (gen_tower_map.js), not exported.

## Editing it

Re-run any stage through the MCP session (port **9884**):

```
..\tower_of_doom_II_hellbound\tmp\gold_sword_env\Scripts\python.exe tools\inducer_cyber\mcp_call.py tools\inducer_cyber\03_core.py
```

Stages: `00_studio`, `01_base`, `02_coil`, `03_core`, `04_cage`, `05_crown`,
`06_conduits`, `07_play`. Each empties its own collection first. Motion lives
in `tools/inducer_cyber/anim_spec.py` (drives the Blender drivers AND the game
clips). After any change: `export_native.py` (background Blender) →
`install_native.py` → `verify.py` → a FULL build.

`review/` holds studio renders of the master; `game_preview/` holds renders of
the SHIPPED binaries posed by the shipped clips (`render_native.py`). Neither is
a game screenshot.
