# 168 — The cyber Rampage Inducer (2026-10-02)

User: *"Can we do a redesign on the rampage inducer so it fits the map more. We
ported it over from bo6 but I believe we have the capabilities to create one
that's even better and more cyber like that is nicer for our map. Use the
blender mcp to do this and open up an instance so i can see the changes."*
Then, mid-build: *"Make sure to add animations"* and *"It looks large enough
where it may need a clip as well."*

## What it is

A map-owned device, authored live in Blender over MCP (the window stays open
for the user), replacing BO6's essence canister (`tod_inducer`, v18.99h–v19.68k):

| Part | Look | Moves? |
| --- | --- | --- |
| Plinth (44 × 44, 7-unit chamfers) | graphite armour, titanium deck band, floor light ring, corner anchor clamps | — |
| Skirt | front **RAMPAGE** display with a 5-step meter, hazard band, glowing side vents | — |
| Power coil | four copper windings over a glowing core, retaining bars, emitter lens | — |
| Core | a levitating **Fury crystal cluster** (main crystal + five spurs) in a scrolling plasma column, three orbiting shards, two segmented containment halos | crystal, shards, both halos |
| Cage | four bowed ribs on the diagonals, outer status strip + inner core strip each | — |
| Crown | emitter dish, finned collar with a status band, titanium dome, four claws with crystal emitter tips, beacon lamp + antenna | the beacon shutter |
| Rear | three corrugated conduits into a junction, two data lines | — |

67 tall, front on local +X (the generator's `INDUCER_YAW` 90 turns it to face
the arena). Its back stops 0.9 units short of the south wall.

### The two states (one atlas, two glow maps)

| | OFF | ON |
| --- | --- | --- |
| Trims, floor ring, collar band, claw strips | **cyan** standby (the arena's own accent) | **rampage red** |
| Core, vents, crystal | dim amber lamp (the user's v18.99i ask) | hot orange burn |
| Meter | 2 amber bars | all 5 lit red |
| Plasma column | soft amber | bright |
| Motion | `tod_inducer_cyber_loop_idle` (12 s) | `tod_inducer_cyber_loop_on` (3 s): 4× faster, the crystal bobs harder and shivers, the beacon sweeps like an alarm |

`tod_inducer_cyber_on` is the same mesh with `skinOverride` swapping both
materials (`mtl_tod_icyber` → `_on`, `mtl_tod_icyber_plasma` → `_on`).

### The motion (five bones)

`tools/inducer_cyber/anim_spec.py` is the one source for the Blender preview
drivers AND the in-game clips. Bones under a static `tag_origin`:
`j_crystal` (turns + bobs), `j_shards` (orbit the other way), `j_halo_lo` /
`j_halo_hi` (tilted 11° / 9°, precess and spin in opposite directions),
`j_beacon` (the shutter sweeps the beacon lamp). Every term is a whole number
of turns/cycles per clip, so both clips loop without a seam; frame 0 is the
bind pose, so `AnimScripted` never pops when it starts. In game,
`_tod_rampage.gsc::anim_set` plays the state's loop after every `SetModel`
(a swap restarts scripted anims — the perk machines' `rest_pose` handles
model changes the same way); the flip's own flash hides the restart.

### Collision

`gen_tower_map.js` emits **`base rampage inducer body`**: a `clip` box 42 × 42 ×
40 from the same constants that place the device (players and zombies walk
round it; 40 is above a jump). The geometry lint's `MODEL_CLIP_COLUMNS` accepts
it (a visible model with no collision of its own stands in that column — the
ammo crates' rule). The use trigger stays centred ("a radius all around it")
but its origin rides ABOVE the clip at `base_inducer_trig_lift()` = 44,
generated beside the clip: a clip under the origin would block the trigger's
sight trace (memory `trigger-origin-under-decal`). The sparks moved to the two
front claw tips (`TOD_RAMPAGE_FX_FWD` 9 / `_SPREAD` 9 / `_FX_Z` 63.4); the
looping lamp light rose from 18 to 35, the crystal (`gen_tod_inducer_fx.py`).

## The pipeline

1. **Live studio** — `blender.exe --factory-startup --python tools/inducer_cyber/mcp_bootstrap.py`
   (port **9884**, the inducer's own; 9876 sword, 9877 zombies, 9878 altar).
   Stage scripts run through `mcp_call.py` with the Tower II MCP env
   (`../tower_of_doom_II_hellbound/tmp/gold_sword_env/Scripts/python.exe`):
   `00_studio` (the arena corner mock: blue-grid floor, the south wall, the cyan
   pilaster and cornice, lights, three cameras, EEVEE + bloom, the ON preview)
   → `01_base` → `02_coil` → `03_core` → `04_cage` → `05_crown` →
   `06_conduits` → `07_play` (drives the rig, starts real-time playback).
   Every stage is re-runnable (it empties its own collection first).
   Master: `art/rampage_inducer_cyber/rampage_inducer_cyber.blend`.
2. **State in one material** — emissive materials read `rampage_on` through an
   Attribute node of type INSTANCER (probed: a non-instanced object reads its
   own property, an instanced one the empty's). The ON preview is a collection
   instance with `rampage_on = 1` plus ON-speed copies of the moving parts
   (they live in `Inducer | moving parts`, outside the instanced master).
3. **Export** (background Blender) — `export_native.py`: rest pose at frame 0,
   every part evaluated into model space with its bone stamped per face,
   smart-UV atlas, Cycles bake (OptiX, ~15 s) of `i_tod_icyber_{n,c,s,g}` and the
   two glow maps `_e` (normalised by 4) and `_eon` (by 12), geometry JSON.
4. **Install** (system Python + PyCoD) — `install_native.py`: the six-bone
   `tod_inducer_cyber.xmodel_bin` (rigid single weights; the plasma doubled
   back-to-back), both `XANIM_EXPORT`s → `export2bin` (bare name, cwd = folder),
   the tileable plasma textures, `source_data/tod_inducer_cyber.gdt`,
   `animtrees/tod_inducer.atr`, `art/rampage_inducer_cyber/install_manifest.json`.
5. **Proof offline** — `render_native.py` rebuilds the SHIPPED binaries in
   Blender, poses them by CPU skinning straight from the shipped clips, back
   faces transparent: `art/rampage_inducer_cyber/game_preview/`.
6. **Gate** — `tools/inducer_cyber/verify.py`, every build (replaces
   `tools/inducer/verify.py`): shipped files == manifest, GDT shape (no shared
   names — the first cut named the ON clip and the ON model alike), bones,
   bounds (wall clearance), clips seamless and starting on the bind pose,
   animtree/zone/script/generated-lift lockstep, the BO6 inducer unzoned; after
   the link `--compiled-ledger` proves both xmodels single-LOD with every
   triangle, both clips, the animtree, the four materials and nine images.
   Negative controls: re-zoning `xmodel,tod_inducer` and drifting the GSC clip
   name both fail it.

## Numbers

54,370 triangles (solid 52,770 + plasma 800 × 2 sides), one LOD (thin strips
survive at range — memory `autogen-lods-erase-thin-parts`). Atlas 2048².
GDT `scaleRGB`: solid 4 OFF / 12 ON (the maps' own normalisation, so the game
reproduces the Blender strengths), plasma 1.4 / 5. Those four numbers are the
brightness knobs; re-run `install_native.py` after changing them.

## Logs (dev runs)

`[TOD_RAMPAGE] MODEL revision=cyber_core_1 model=tod_inducer_cyber ... anims=... trig_lift=44`
at spawn; `[TOD_RAMPAGE] ANIM clip=tod_inducer_cyber_loop_idle|_on model=... rampage=0|1`
on spawn and every flip.

## Build

FULL BUILD OK 01:04:58 Eastern (2026-10-02), FF 148,582,528 B. The gate ran
before the link and after it (both xmodels single-LOD at 54,370 tris, both
clips, the animtree and the four materials in the ledger). scripts / zone_source
/ ui diffs clean, nothing synced after the .ff, the tools-root .map == repo,
navmesh gate OK, geometry lint OK, bank 197.9 MB, the 10 waived linker messages
only. Log `tmp/inducer_cyber/build_full1.log`.

## Not verified / open

* Native appearance, the motion in game, the scroll direction of the plasma
  and the trigger feel are the user's to judge — nothing here was launched.
* PRE-EXISTING, NOT CHANGED: `glow_set` still plays the lamp FX on a host it
  created in the same frame (one of the same-frame hosts listed in CHANGELOG
  v19.68i — the user's call). If the floor lamp never shows, that is why.

## Rollback

The BO6 port is untouched on disk (`source_data/tod_bo6_inducer.gdt`,
`model_export/tod_bo6_inducer/`, still synced, unzoned). Restore = zone
`xmodel,tod_inducer` + `_on`, point `TOD_RAMPAGE_MODEL*` back at them, drop
`anim_set( on );` from `glow_set`, and swap the build gate back.
