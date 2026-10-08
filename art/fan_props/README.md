# Nikolai's fan props (v19.69, 2026-10-02)

Three props from the Meshy AI model pack a fan of the map, **Nikolai**, shared on
2026-09-30 (`~/Downloads/3D Models-20260930T132111Z-1-00{1,2,3}.zip`; review gallery
https://claude.ai/artifact/JfbPCEs4XXy3deaxA9t1RR). His note: "feel free to alter or
change any model as needed". The user's ask (2026-10-02):

> 1. Add the Tower of Doom Cybercity sign part of tower wall where players spawn at
> 2. Replace the ammo crates with the new model from props (nikolai)
> 3. Replace the activation for run for the crown model to the Door Terminal Idea prop
> Make any tweaks necessary so that the models actually look like they belong on the tower

| In game | Model | From the pack | Size (units) | Tris |
|---|---|---|---|---|
| Spawn sign on the core's west face | `tod_cybercity_sign` | `Cyber city sign.zip` (Meshy "Ironclad Behemoth") | 256 wide x 119 tall x 24 deep | 12,000 |
| The crown uplink (starts the run for the crown) | `tod_uplink_terminal` | `Door terminal idea X2/Door terminal idea.zip` (Meshy "Maintenance Terminal") | 84 tall, 46 x 48 footprint | 14,000 |
| Every ammo crate | `tod_ammo_chest` | his Oct 2 **Ammo Box V6** (`~/Downloads/3D Models-20261002T134705Z-1-00{1,2}.zip`, `source/chest_v6/`) | 98 wide x 69 deep x 29 tall (no lid) | 45,535 exported, 26,492 in the game |

| The power switch at the end of the power hall | `tod_power_terminal` | his Oct 2 **Grid Terminal V5** (`source/grid_v5/`) | 60 wide x 11 deep x 88 tall | 24,136 |

The first chest (Sep 30 `Cyber Ammo_Chest_texture_fbx.zip`, 97 x 75 x 53 with an open lid,
24,000 tris) shipped in one build (v19.68n) and was replaced by V6 the same day (v19.68p).

`source/` holds the fan's files with short names, md5-pinned in the tool.

## Rebuild

```
"C:\Program Files\Blender Foundation\Blender 4.2\blender.exe" -b -noaudio --python tools/fan_props/build_fan_props.py -- [--phase bake|build|all] [--only sign,terminal,chest]
node tools/gen_tower_map.js     # the crate box and the sign anchor read manifest.json
```

`bake` (minutes) writes the low-poly meshes and the Cycles bakes to `tmp/fan_props_stage/`;
`build` (seconds) writes the maps, the binaries, `source_data/tod_fan_props.gdt`, the
previews here and `manifest.json`. A change to the models is a FULL map build.

## Decisions worth keeping

- **Meshy meshes are 0.65-2 million triangles with hundreds of tiny UV islands.**
  Decimating ON those UVs kept the sign (its letters are raised geometry) but smeared
  every flat panel across island seams - the terminal's MAINTENANCE TERMINAL screen and
  the chest's bullet icon came out as triangles (`tmp/fanprops_20261002/decA_*`). So the
  sign keeps the fan's UVs and sheets; the terminal and chest are decimated, unwrapped
  fresh and BAKED from the full-detail original (colour, metal, roughness, tangent
  normals) in Cycles.
- **The fresh unwrap is weighted by visibility.** The chest's first bake gave its
  thousands of interior shell/cell islands most of the sheet and the front icon plate
  ~90 px. Each island is now scaled by how exposed its faces are (24 rays per face) with
  a boost for front- and up-facing faces: the icon plate got ~4x the area, and the empty
  sheet space fell from 50% to 34%.
- **The fan's normal maps are DirectX green** (what BO3 uses) - measured by
  `tools/fan_props/normal_convention.py` (+0.38 sign, +0.35 chest, against a Blender
  control bake at -0.87 OpenGL / +0.86 DirectX). They ship unflipped; only Blender's own
  Normal Map node (OpenGL) gets a flipped copy for the bake.
- **Glow is cut from the paint** (Meshy ships no emission map): hue / saturation / value
  bands per prop, measured from the baked colour - the chest's seams are a PALE cyan
  (saturation ~0.44) and its brass shells must not glow, so its bullet icon band takes
  only bright gold. Emission strength (GDT scaleRGB): sign 6, terminal 5, chest 4.
- **Metals keep 65% of their colour as diffuse** (`METAL_DIFFUSE_CUT` 0.35): this map's
  reflection probes smear, so a black-diffuse metal reads as a hole.
- **One full-detail LOD each** (autogen off) - generated LODs erased the staff shaft and
  the altar crest (memory `autogen-lods-erase-thin-parts`).
- **The terminal faces the crown stair.** The Stalingrad data terminal it replaced
  showed its screen at model -X; at `uplink_yaw()` 0 that pointed at the terrace's empty
  west end. This one's screen is model +X: east, at the players walking up.
- **The crate contract grew sideways only.** Depth stays 75 (lid's back edge at -37),
  the chest is 98 across where the West crate was 64, so the generator's crate box is
  `x[-37,38] y[-49,49]` (asserted against `manifest.json`), the trigger moved to the
  front face line on the centre line (38 / 0), and three trial halls were nudged: the
  Altar crate 4 south, the Gauntlet crate 14 west, the Kennel's (-400,100) riser to
  (-310,100). Hall bunker lint: 0 in all seven halls. **V6 (v19.68p): the box is
  `x[-37,33] y[-49,49]`, the trigger 33 / 0**; the hall nudges stay (more clearance).
- **V6 is reduced per material group** (`groups=` in the tool): one decimate over the
  whole box bridged separate parts into black triangles. Weld, split non-manifold edges,
  separate by material, then reduce each: the shell to 24,000 (16,000 tore holes; 24,000
  holds 1 cm at p99), the interior trays not at all, the rounds to 18,000 at a 0.35 UV
  weight. Dropping the bottom faces tore shards, so V6 keeps them. V6 ships its own glow
  map; the glow is the max of his map and the cyan-blue strip band. The reduction leaves
  18,936 zero-area slivers that the linker drops: the ledger count is the real one.

## The power terminal (v19.68q)

- **The switch logic stays stock.** `_zm_power::electric_switch` reads a trigger_use
  `use_elec_switch`, an `elec_switch` handle it rolls and plays its two sounds from, and an
  `elec_switch_fx` spark point. The generator (`POWER_TERM` in gen_tower_map.js) emits those
  three in place of the old `power_switch.map` prefab - the handle is an invisible
  `tag_origin` at the panel's HOLD button - and `_tod_power_terminal.gsc` only hangs the panel
  (script_model, generated anchor). `base power terminal body` is its clip.
- **88 tall, centred at y -464, not on the hall's centreline:** the hall walls are 128 and the
  POWER word owns z 96..128; the song-hunt bear stands against the same wall at y -520. The
  generator asserts both gaps (and the hall walls, and the riser at x 1400).
- **Six source objects:** the Meshy mesh (body atlas + the screen sheet) and five thin
  `Clean_Display_*` lettering plates. `join` merges them with the plates on their own material,
  so they are never reduced and get 1.6x atlas (`groups`).
- **The screens glow from his own sheet:** it is wired into Emission at strength 0 in the FBX;
  `emit` turns it on for the bake and `emit_floor` keeps the sheet's navy background dark. The
  bands catch the body's neon, plus two measured on the bake: the HOLD button's pale-cyan bolt
  and the blue ring round it.
- **Baked at 4096, shipped at 2048:** the lettering is supersampled. The back faces are
  dropped (flush to the wall); the side view shows no tear.

### The power-on animation (v19.68u)

User: "the power has no animation from on to off ... Like a knob turning or a switch or power
visual going up on the screen. The old switch would move the lever". Stock's handle is the
invisible tag_origin above, so nothing visible moved. `tools/fan_props/build_power_anim.py`
(`--check` gates every full build) adds two pieces over the untouched panel, both in the
panel's own frame (`power_anim.json`):

- **The dial** - the HOLD button's segmented bolt ring cut out as its own 48-segment disc,
  0.25 proud. On the press it spins two turns in 1.4 s (eased) and stops upright, then swaps
  to `tod_power_dial_on` (the same mesh, scaleRGB 5 -> 14). A press-in would open a gap: the
  button plate is level with its rim. Its centre is a LOCKSTEP trio of #defines in
  `_tod_power_terminal.gsc` that the gate compares with the json.
- **The screen** - his five display plates again, 0.35 in front of the baked ones, one
  skinOverride frame each: `_dark` (0.15 s), `_f1.._f3` (each RESTART GRID step lights cyan then
  mint while the bar fills and the arrows run, 0.35 s each), then the base model = ON: POWER
  RESTORED, the bar full, 03:00 / 03:00, SYNC COMPLETE, mint stripes. Every new word is
  composed from his own glyphs on the sheet (the GLYPH table: C O M P E T, and an L cut from his E), recoloured by
  INK weight so no navy box shows behind a pasted letter. Hidden until the press.
- It starts on the SAME press stock takes (both wait on the trigger's notify); a power_on from
  anywhere else shows ON directly. `preview_power_boot.jpg` = the five frames.

## The spawn sign, rebuilt as a relief (v19.68u)

User: "The sign looks a litlle janky and not enhancedf or smmothed ... It alsmot looks meshed".
`tools/fan_props/build_sign_relief.py` (`--check` gates every full build) replaces
`tod_cybercity_sign` with `tod_cybercity_sign2` (the old model stays defined - rollback is one
zone line + one #define):

- **Why it looked meshed:** his 732K-tri mesh decimated to 12K ON his own UV islands, plus his
  crinkled-metal normal map on a mesh it was not baked for. His geometry is clean.
- **The relief:** his full-detail sign rendered straight on (orthographic, 16 px per unit, exact
  depth per pixel) -> a mesh off a 0.25 grid (a depth step is a letter's side; the outline
  closed back to the wall) -> collapse decimate to 60K -> ONE front-projected 4096 x 2048 colour
  sheet, no normal map. Footprint asserted inside the generator's placed size.
- **The sides:** a side cannot be front-projected (one texel column smeared down its depth)
  and one texel per triangle striped. Each side samples a FLAT SWATCH (painted in the empty
  band above the sign) by the face it hangs from - his steel blue on the cyan letters, his
  muted purple on the pink neon, his dark metal elsewhere (medians of his texture on the old
  model's side faces) - and side corners share area-averaged normals, so a side shades as one
  smooth return while the face/side edge stays sharp.
- **Power states** (user: "can we give the sign and on and off state and turning power on
  lights it up?"): skinOverride twins `_off` (a half-size colour sheet with every glowing texel
  dimmed to 28% and half greyed, a black glow sheet) and `_dim` (scaleRGB 2). The script hangs
  it OFF and flickers it on 0.4 s after power_on. `preview_sign_relief.jpg` (old vs new) and
  `preview_sign_states.jpg` (OFF | DIM | ON).

- **The CYBERCITY word is level** (v19.68w, user: "The Y in the sign is sticking out and the B ... make it
  level"): his model has the last Y 3.6 units proud of the line (20.10 against 16.53) and the first Y bent back
  (14.2-15.3 with a 16.7 ridge); the B was level all along and only read as popping out beside the bent Y. Every
  pixel in front of the mounting rods inside each letter's measured window (`LINE_LETTERS`) goes to the line's own
  face depth before meshing; `--check` reads the shipped binary and fails on any letter proud of or sunk behind
  that plane. **Measure every letter's face depth on an AI-made sign before trusting it.**

## Gallery renders

`tools/fan_props/render_gallery.py` renders any of his FBXs as the review gallery's own
6 x 2 sheet (12 portrait or 10 landscape views, incl. two clay "shape only" views):

```
"C:\Program Files\Blender Foundation\Blender 4.2\blender.exe" -b -noaudio --python tools/fan_props/render_gallery.py -- <out_dir> tag=<file.fbx>[@portrait|@landscape] ...
```

It writes `s/<tag>.jpg`, `c/<tag>.jpg` and `stats.json`. The clay views use their own
dimmer lights (`CLAY_LIGHT`); a light clay under lights set for dark metal clips to a white
silhouette. **Upgrade Terminal Fix 6's FBX crashes Blender's FBX importer** (4.2 and 5.2):
its `Reference_Wireframe_Tower` mesh carries the main mesh's Edges array (3,063,108
entries for 375,060 loops). The renderer drops any Edges array that points past its own
loops, and Blender rebuilds the edges from the faces. The Oct 2 before/after page builder
is `tmp/fanprops_20261002/gallery_page/build_page.py`.

## Not done (offered)

- The terminal's screen still says MAINTENANCE TERMINAL with the AI's "> 8EAJY" under
  it. It could be repainted to read CROWN UPLINK / > READY (the screen is one clean
  island in the bake).
- The sign's neon does not light the wall around it (an emissive surface lights
  nothing in BO3). A small looping light effect could add the spill.
- Credit: the fan is Nikolai; which Meshy plan made the models (free plan = CC BY 4.0,
  must also credit Meshy) is still unconfirmed - CREDITS.md.
