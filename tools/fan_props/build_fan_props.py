"""Blender 4.2: three props from Nikolai's fan pack -> BO3 xmodels.

THE ASK (user 2026-10-02): "1. Add the Tower of Doom Cybercity sign part of tower
wall where players spawn at 2. Replace the ammo crates with the new model from
props (nikolai) 3. Replace the activation for run for the crown model to the Door
Terminal Idea prop. Make any tweaks necessary so that the models actually look like
they belong on the tower".

SOURCE: Nikolai's Meshy AI pack (Workshop name Nikolai; the 2026-09-30 Google Drive
split ~/Downloads/3D Models-20260930T132111Z-1-00{1,2}.zip). Copied with short
names to art/fan_props/source/ and md5-pinned in PROPS below:
  "3D Models/Cyber city sign.zip"                     -> sign     (Meshy "Ironclad Behemoth":
                                                         732K tris, 4K colour/normal + 2K metal/rough)
  "3D Models/Door terminal idea X2/Door terminal idea.zip" -> terminal (Meshy "Maintenance
                                                         Terminal": 656K tris, 2K colour ONLY)
  "3D Models/Cyber Ammo_Chest_texture_fbx.zip"        -> chest    (Meshy "Neon Arsenal Chest":
                                                         2.02M tris, 4K colour/normal + 2K metal/rough)
Every Meshy model is delivered at 1.9 m on its longest side, front facing -Y.

WHY A BAKE, NOT A DECIMATE-IN-PLACE (measured 2026-10-02, renders kept in
tmp/fanprops_20261002/decA_*): Meshy UVs are hundreds of tiny islands. Decimating
the mesh ON its own UVs held up on the sign's raised letters, but every FLAT panel
collapsed across island seams - the terminal's MAINTENANCE TERMINAL screen and the
chest's bullet icon came out as smeared triangles. So each prop is the classic game
asset: a decimated COPY, unwrapped fresh (hard edges == island splits, both
SHARP_DEG), with the full-detail original baked onto it in Cycles - colour, metal and
roughness through emission, tangent normals with DirectX green (the heavenly altar
and cyber inducer pipeline; the altar is played and accepted in game). The fan's
lossless PNGs replace the JPGs packed inside the FBXs as the bake source.

WHAT EACH ONE IS IN GAME (the scripts read the manifest numbers through the map
generator, never a copy):
  tod_cybercity_sign  - the spawn sign on the core's west face. Front = local +X,
                        pivot = the BACK plane, horizontal centre, bottom (the
                        generator puts that point on the wall). The back faces are
                        dropped: they are pressed to the core and only cost texels.
  tod_uplink_terminal - the terrace uplink that starts the run for the crown. Front
                        (screen + keyboard) = local +X, pivot = footprint centre on
                        the floor. 84 tall (the stock Stalingrad terminal it replaces
                        was 78; its screen faced -X, AWAY from the crown stair - this
                        one faces the player who walks up it).
  tod_ammo_chest      - every ammo crate. THE CRATE CONTRACT (gen_tower_map.js
                        crateBox / CRATE_LOCAL): front = local +Y (yaw + 90), depth
                        fitted to exactly 75 with the open lid's back edge at
                        F = -37, centred across, on the floor. The bottom faces are
                        dropped (never seen).
Each is ONE full-detail LOD (autogen off: the staff shaft / altar crest lesson,
memory autogen-lods-erase-thin-parts).

THE ROCKETS (2026-10-02, user: "use the rocket ships built in the props and place at each spot. Instead of the
teleporters after the crown fight is over. Then the colorful one goes to endless spire ... they view from the rocket
POV as it flies to the endless spire. Then it crashes into the ground"; "if you extract same thing but the extract
ship goes straight up"). From the pack's "Soul Box Ideas X3" folder (copied with short names to source/rocket_*):
  "Colorful rocket.zip"      -> rocket_spire   (Meshy "Ironclad Behemoth" 0927213722: 709K tris, black hull, cyan /
                                                 violet piping, glowing cyan-magenta-orange windows) - THE ASCEND ship
  "Cyber outline rocket.zip" -> rocket_extract (Meshy "Ironclad Behemoth" 0927213638: 496K tris, black hull, neon
                                                 cyan / violet outline trim) - THE EXTRACT ship
  ("Rocket Plain Texture" is a grey hull with no neon: not used.)
Both are the same retro shape: a bullet body, a nose cone, four swept fins that reach the ground at the cardinal
axes (the FEET), one engine bell in the middle of the underside ringed by small nozzle cups.
UNLIKE EVERY OTHER PROP HERE THEY ARE EXPORTED LYING DOWN: the nose is local +X, the windows (the Meshy front) are
local +Z, the pivot is on the axis at the fins' feet (pivot 'tail'). A rocket in flight is aimed with
angles = VectorToAngles( nose direction ), pitch -90 stands it up, and a dive never needs a pitch past 90 (the
standing-up Euler form would). The manifest carries the measured body profile and the engine bell for the
flight / camera code (tod_crown_data, generated from it). The SPIRE ship also gets a charred twin for the crash
site: model tod_rocket_wreck = the same mesh with a skinOverride onto a burnt material (its own colour + ember glow;
normal / spec / gloss shared).

THE POWER TERMINAL (2026-10-02, user: "We can add the grid terminal as well to replace the power switch"): his Oct 2
"Grid Terminal V5" (source/grid_v5, the FBX + the three PNGs it loads) - a GRID CONTROL wall panel that replaces
the stock lever at the end of the power hall. tod_power_terminal: front = local +X, pivot = the BACK plane (like the
sign: it hangs flush on the hall's east end wall), 88 tall. Unlike the other sources it is SIX objects: one 598K-tri
Meshy mesh with two materials (the body atlas; the screen sheet - a front-on picture of the panel's screens) and five
thin "Clean_Display_*" plates he laid over the screens for crisp lettering. They are joined (`join`), the plates on
a copy of the screen material so they form their own group that is never reduced and gets extra atlas (`groups`
uv 1.6). His screen material wires the sheet into Emission at STRENGTH 0, so `emit` turns it on for the bake and
`emit_floor` keeps the sheet's navy background dark.

GLOW: Meshy shipped no emission map; the neon is painted into the colour. Each glow
map is cut from the baked colour with hue/saturation/value bands (GLOW below) - the
teddy's recipe - so a painted light is a light in a dark room.

Run:  "C:\\Program Files\\Blender Foundation\\Blender 4.2\\blender.exe" -b -noaudio
      --python tools/fan_props/build_fan_props.py -- [--phase bake|build|all] [--only sign,terminal,chest]
  bake  : geometry + Cycles bakes -> tmp/fan_props_stage/<key>/ (minutes)
  build : maps, xmodel binaries, GDT, previews, manifest (seconds; re-run to tune GLOW)
"""
import bpy
import bmesh
import hashlib
import json
import math
import shutil
import subprocess
import sys
import time
from pathlib import Path

import numpy as np
from mathutils import Matrix, Vector
from BetterBetterBlenderCOD.PyCoD import xmodel

ROOT = Path(__file__).resolve().parents[2]
TOOLS = Path(r'C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130')
SRC = ROOT / 'art/fan_props/source'
ART = ROOT / 'art/fan_props'
FOLDER = 'tod_fan_props'
OUT = ROOT / 'model_export' / FOLDER
IMG = OUT / '_images'
STAGE = ROOT / 'tmp/fan_props_stage'
GDT = ROOT / 'source_data/tod_fan_props.gdt'
REVISION = 'fan_props_4'   # 3: the two rockets + the wreck twin (2026-10-02); 4: the power terminal (Grid Terminal V5)
SHARP_DEG = 60.0          # hard-edge angle == smart-project island angle: every hard edge is a seam
BAKE_SIZE = 2048
METAL_DIFFUSE_CUT = 0.35  # metals keep 65% of their colour as diffuse: this map's probes smear (CLAUDE.md), so a black-diffuse metal reads as a hole
CRATE_BACK = -37.0        # gen_tower_map.js CRATE_LOCAL.f1: the open lid's back edge, 3u off a backing wall

# Glow bands: (hue in, hue full, hue full-to, hue out (degrees), sat lo, sat hi, val lo, val hi, gain).
# A pixel's weight is the max over its prop's bands; glow = colour * weight.
GLOW = {
    'sign': [
        (160, 172, 205, 222, 0.30, 0.55, 0.35, 0.70, 1.0),   # the cyan TOWER OF DOOM letters and tube
        (255, 270, 335, 350, 0.30, 0.55, 0.30, 0.65, 1.0),   # the pink / violet swoosh and CYBERCITY
    ],
    'terminal': [
        (165, 175, 200, 215, 0.40, 0.65, 0.35, 0.70, 1.0),   # cyan trim, screen text, key caps, back LEDs
        (280, 292, 330, 342, 0.40, 0.65, 0.35, 0.70, 1.0),   # magenta trim and key caps
    ],
    # THE POWER TERMINAL: the screens glow from the bake's own emission (PROPS 'power' emit / emit_floor); these bands
    # only catch the neon painted into the Meshy BODY atlas - its cyan light strips and magenta / violet trim.
    'power': [
        (165, 175, 200, 215, 0.40, 0.65, 0.35, 0.70, 1.0),   # cyan strips
        (275, 288, 330, 342, 0.40, 0.65, 0.35, 0.70, 1.0),   # magenta / violet trim
        # measured on the 4096 bake (2026-10-02): the HOLD button's lightning icon is a PALE cyan (hue 185, sat 0.34,
        # val 0.98) and the light bar on top a mid one (sat 0.41, val 0.73) - both under the strip band's saturation;
        # the ring round the button is a saturated BLUE (hue ~216, sat 0.75, val 0.56) in the gap between the bands.
        # The navy body (val <= 0.35) stays out of all three.
        (165, 175, 205, 220, 0.20, 0.32, 0.62, 0.80, 1.0),   # pale cyan: the button's bolt, the light bar
        (205, 215, 275, 290, 0.55, 0.70, 0.45, 0.60, 0.9),   # blue / violet: the ring round the button
    ],
    # V6 (measured on its bake, 2026-10-02): the neon strips and the lightning bolt are a
    # saturated cyan-blue (hue 190-210, sat ~0.85, the lit ones val 0.75+); the shell is a
    # dark navy (hue 210-220, val ~0.23); the brass rounds AND the bullet icon share one
    # orange (hue 30-40, val ~0.73), so the icon cannot glow without the rounds - it stays
    # lit only by the world, as in Nikolai's own render. His authored emission (the rounds'
    # energy bands, bake_e) is added on top in write_maps.
    'chest': [
        (184, 190, 205, 212, 0.55, 0.80, 0.55, 0.85, 1.0),   # the cyan-blue light strips and the lightning bolt
    ],
    # THE ROCKETS, measured on the 4K bakes (2026-10-02): every BRIGHT SATURATED texel is neon or a window -
    # value 0.48..0.90, saturation 0.34..0.71 - and the spire ship's hues run CONTINUOUSLY from cyan through
    # blue, violet, magenta and pink to orange (the windows are gradients), so its bands are contiguous: the
    # first cut's gaps (blue 220-250, red 350-8) left dark smudges in every window. The chrome (low saturation)
    # and the black hull (low value) stay unlit. The extract ship is cyan + violet trim only.
    'rocket_spire': [
        (165, 175, 352, 360, 0.28, 0.50, 0.40, 0.66, 1.0),   # cyan -> blue -> violet -> magenta -> pink
        (-1, 0, 38, 55, 0.35, 0.58, 0.48, 0.74, 0.95),       # red -> the windows' orange end
    ],
    'rocket_extract': [
        (165, 175, 318, 334, 0.28, 0.50, 0.40, 0.66, 1.0),   # cyan -> blue -> violet outline trim
    ],
}

# THE ROCKETS' SIZE (in game units, nose to the fins' feet). 440 tall puts the four feet 110 off the axis: the
# spire ship's feet land on the 224-wide uplink dais (half-width 112) and the extract ship's stand on sanctuary
# tier 2 with 66 to spare in front of the reredos stone (gen_tower_map.js asserts both from the manifest).
ROCKET_H = 440.0

PROPS = {
    'sign': dict(
        model='tod_cybercity_sign', material='mtl_tod_cybercity_sign', img='i_tod_csign',
        fbx=('sign/sign.fbx', 'a37cb3a7e26981c029a8040ad9e6e8f0'),
        tex={'color': ('sign/sign_color.png', '23f9454344b93087b0c38cf54df489ba'),
             'normal': ('sign/sign_normal.png', '4851043df75070237d603f1420fbe123'),
             'metallic': ('sign/sign_metallic.png', 'aa239dbe4491281b756e29be721888f7'),
             'roughness': ('sign/sign_roughness.png', '3a54e25157ac832222a97c0f6fd321d6')},
        method='reuse',   # the raised letters kept their shape on the fan's own UVs (decA test) and a fresh unwrap shattered them
        tris=12000, drop='back', front='+X', fit=(0, 256.0), pivot='back',
        sizes={'c': 2048, 'n': 2048, 's': 1024, 'g': 1024, 'e': 2048},
        shader='fullspec', scale_rgb='6', gloss=(0, 11), spec_amount='0.6', probe='0.3'),
    'terminal': dict(
        model='tod_uplink_terminal', material='mtl_tod_uplink_terminal', img='i_tod_uterm',
        fbx=('terminal/terminal.fbx', 'efa55bc652db51c6048fd84024f4b852'),
        tex={'color': ('terminal/terminal_color.png', '31e87845ac6ec94e63b32a27f63a35a9')},
        method='bake', pbr=False,   # colour only: no honest metal / roughness to bake
        tris=14000, drop=None, front='+X', fit=(2, 84.0), pivot='floor',
        sizes={'c': 2048, 'n': 2048, 'e': 1024},
        shader='plus', scale_rgb='5', gloss=(3, 7), spec_amount='0.4', probe='0.2'),
    # THE POWER TERMINAL (see the header). 88 tall: the power hall's walls are 128 and the POWER word above the switch
    # owns z 96..128 (gen_tower_map.js POWER_TERM asserts the gap); the screen's centre lands at eye height. Colour
    # only like the uplink (his body is a flat metallic 0.25 / roughness 0.7, nothing to bake). Baked at 4096 and
    # brought to 2048 so the lettering is supersampled.
    'power': dict(
        model='tod_power_terminal', material='mtl_tod_power_terminal', img='i_tod_pterm',
        fbx=('grid_v5/Grid_Terminal_V5_Final.fbx', 'b5178aef5359c8999d1bd34cce10f68b'),
        tex=None,
        deps={'grid_v5/textures/Grid_Body_V5_4K.png': '5ad17752ba7b61d096a99c0cae57620c',
              'grid_v5/textures/Grid_Display_V4_4K.png': '10af6a2ad86f0d37b8216f7d0236dd80',
              'grid_v5/textures/Grid_Normal_4K.png': 'd7f0b6529bb0088652c9881f50cab33d'},
        method='bake', pbr=False, bake_size=4096,
        join={'Clean_Display_': 'tod_clean_display'},
        emit={'Crisp_Reference_Lettering_4K': 1.0, 'tod_clean_display': 1.0}, emit_floor=(0.12, 0.26),
        groups=[dict(name='body', mats=['Material.001'], tris=14000, uv=1.0),
                dict(name='screen', mats=['Crisp_Reference_Lettering_4K'], tris=10000, uv=1.0),
                dict(name='lettering', mats=['tod_clean_display'], tris=None, uv=1.6)],
        drop='back', front='+X', fit=(2, 88.0), pivot='back',
        sizes={'c': 2048, 'n': 2048, 'e': 2048},
        shader='plus', scale_rgb='5', gloss=(3, 7), spec_amount='0.4', probe='0.2'),
    # v19.69b (2026-10-02, user: "the models may have been updated recently by Nikolai ...
    # I think ammo crate was updated to a new clean v6"): his "Ammo Box V6" replaces the
    # first chest (Meshy "Neon Arsenal Chest", which he dropped from the pack). A lidless
    # open case: the V5 Meshy exterior + a clean modelled interior - straight compartment
    # walls, 12 rounds per pistol / rifle compartment, 15 shotgun shells a side, gunmetal
    # panels, blue inlays and REAL emission on the rounds' energy bands. One mesh, 846K
    # tris, TEN materials (the FBX names its PNGs; no swap), 1.90 x 1.34 x 0.57 m.
    # Fitted to the crate box's 98 WIDTH (the trial halls' riser clearances cap it; the
    # first chest was fitted to depth): 98 x 69 x 29, the back still on f1 = -37.
    'chest': dict(
        model='tod_ammo_chest', material='mtl_tod_ammo_chest', img='i_tod_achest',
        fbx=('chest_v6/Ammo_Box_V6_Final.fbx', 'c7ee7c54e0ec0f96d4d84a8ab9ceac76'),
        tex=None,
        deps={'chest_v6/textures/CyberCrate_BaseColor_4K.png': '8e90f0d07722aceeab8403c0eddb2999',
              'chest_v6/textures/CyberCrate_Emissive_4K.png': 'b40d37e7829616c2b1ee72a067f33190',
              'chest_v6/textures/CyberCrate_Metallic_4K.png': 'bf83834fb969f834707bb2f22eeb9ed1',
              'chest_v6/textures/CyberCrate_Normal_4K.png': '9d44c259e4cc712a01c15d12b94d27ce',
              'chest_v6/textures/CyberCrate_Roughness_4K.png': '247c8a274a90f86b4cb23b6f66f4ee0e',
              'chest_v6/textures/Interior_Gunmetal_Panels.png': 'cc627d64064c338e66682168cd658e81',
              'chest_v6/textures/Meshy_AI_Neon_Ammunition_Cache_0930164345_texture.png': 'c7baf1ab23de4662fb23eb9aa1ccf1dd',
              'chest_v6/textures/Meshy_AI_Neon_Ammunition_Cache_0930164345_texture_metallic.png': '0434729afeabae84257b6744609227ec',
              'chest_v6/textures/Meshy_AI_Neon_Ammunition_Cache_0930164345_texture_normal.png': 'e1bd6e7dd48fea1326f9544acd7cacf0',
              'chest_v6/textures/Meshy_AI_Neon_Ammunition_Cache_0930164345_texture_roughness.png': '76ae721630a30c01ea39eb5f4f7aa353'},
        method='bake',
        # Per-group reduction (make_low_groups): the shell is one 610K-tri Meshy piece; the
        # tray / gunmetal / inlays are already light (4K); the ~950 rounds are 232K.
        groups=[dict(name='shell', mats=['Material.001'], tris=24000, uv=1.0),   # 16K tore holes (shell_test.py); 24K holds 1 cm
                dict(name='interior', mats=['Replacement_Tray', 'Interior_Brushed_Gunmetal', 'Interior_Blue_Inlays'], tris=None, uv=1.0),
                dict(name='rounds', mats=['Replacement_Brass', 'Replacement_Copper', 'Replacement_Silver', 'Replacement_Cyber_Metal',
                                          'Replacement_Neon_Blue', 'Replacement_Shell_Red'], tris=18000, uv=0.35)],
        # ONE full-detail LOD like the others (no `lods`): a generated LOD of this shell would
        # face the same non-manifold joins that tore the 16K reduction open.
        drop=None,   # dropping V6's bottom faces left a ragged open edge the shell's decimation tore into dark shards (strip_v6b)
        front='+Y', fit=(0, 98.0), pivot='crate',
        sizes={'c': 2048, 'n': 2048, 's': 1024, 'g': 1024, 'e': 2048},
        shader='fullspec', scale_rgb='4', gloss=(0, 11), spec_amount='0.6', probe='0.3'),
    # THE ROCKETS (see the header). 4096 colour + normal: the ride's camera sits a few dozen units off the hull, so
    # these are the two most closely seen surfaces in the map. One full-detail LOD (they are seen up close or not
    # at all: the choice window, the ride, the wreck).
    'rocket_spire': dict(
        model='tod_rocket_spire', material='mtl_tod_rocket_spire', img='i_tod_rkspire',
        fbx=('rocket_colorful/rocket.fbx', 'fd5d1a4051db8e05eedcc448a6af08eb'),
        tex={'color': ('rocket_colorful/rocket.png', 'c4c9602efca7eee8d5f336183837b55f'),
             'normal': ('rocket_colorful/rocket_normal.png', '8b9731d4612b46d3234fb58fb1f745fd'),
             'metallic': ('rocket_colorful/rocket_metallic.png', 'bd5b2698b1b3b72be9898728c16b6545'),
             'roughness': ('rocket_colorful/rocket_roughness.png', '9d7147611e922d814ebead52d08b4d7c')},
        method='bake', bake_size=4096, tris=32000, drop=None, front='nose+X', fit=(2, ROCKET_H), pivot='tail',
        sizes={'c': 4096, 'n': 4096, 's': 1024, 'g': 1024, 'e': 2048},
        shader='fullspec', scale_rgb='6', gloss=(0, 11), spec_amount='0.6', probe='0.3',
        # THE WRECK (the crash site at the Spire's base): the same mesh, burnt. Colour x WRECK_DARK, desaturated,
        # sooted toward the tail; the windows' glow becomes a dim ember orange.
        wreck=dict(model='tod_rocket_wreck', material='mtl_tod_rocket_wreck', img='i_tod_rkwreck', scale_rgb='5')),
    'rocket_extract': dict(
        model='tod_rocket_extract', material='mtl_tod_rocket_extract', img='i_tod_rkexit',
        fbx=('rocket_outline/rocket.fbx', '12bd6ee4a251cc2dc67a7e27e6d059c3'),
        tex={'color': ('rocket_outline/rocket.png', 'aa00a72e03be0775dda25aabc7e905c1'),
             'normal': ('rocket_outline/rocket_normal.png', '12de366cc1fb2f95edf40854c4c47094'),
             'metallic': ('rocket_outline/rocket_metallic.png', '095aba9def5700e5bde9193a6132314a'),
             'roughness': ('rocket_outline/rocket_roughness.png', 'bca55f87d51ec0847b5b196576ae2d2d')},
        method='bake', bake_size=4096, tris=32000, drop=None, front='nose+X', fit=(2, ROCKET_H), pivot='tail',
        sizes={'c': 4096, 'n': 4096, 's': 1024, 'g': 1024, 'e': 2048},
        shader='fullspec', scale_rgb='6', gloss=(0, 11), spec_amount='0.6', probe='0.3'),
}
WRECK_DARK = 0.30      # the burnt colour's brightness (x the lit colour); soot takes the tail down further
WRECK_DESAT = 0.65     # how much of the colour's saturation burns off
WRECK_EMBER = (1.0, 0.36, 0.08)   # the windows' glow, re-lit as embers (x the glow mask, x WRECK_EMBER_GAIN)
WRECK_EMBER_GAIN = 0.55


def log(*a):
    print('[FAN_PROPS]', *a, flush=True)


def md5(path):
    return hashlib.md5(Path(path).read_bytes()).hexdigest()


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def ramp(x, a, b):
    return np.clip((x - a) / max(b - a, 1e-6), 0.0, 1.0)


def srgb_to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def clear_scene():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.lights, bpy.data.cameras):
        for item in list(coll):
            if item.users == 0:
                coll.remove(item)


def select_only(active, *others):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in others:
        ob.select_set(True)
    active.select_set(True)
    bpy.context.view_layer.objects.active = active


# ---------------------------------------------------------------------------
# images <-> numpy (Blender rows run bottom-up; every array here keeps that order)
# ---------------------------------------------------------------------------
def read_image(path):
    im = bpy.data.images.load(str(path), check_existing=False)
    w, h = im.size
    px = np.empty(w * h * 4, dtype=np.float32)
    im.pixels.foreach_get(px)
    bpy.data.images.remove(im)
    return px.reshape(h, w, 4)[..., :3].copy()


def write_image(arr, path, colorspace):
    h, w = arr.shape[:2]
    im = bpy.data.images.new(Path(path).stem, w, h, alpha=False)
    im.colorspace_settings.name = colorspace
    rgba = np.concatenate([np.clip(arr, 0, 1), np.ones((h, w, 1), np.float32)], axis=-1).astype(np.float32)
    im.pixels.foreach_set(rgba.ravel())
    im.filepath_raw = str(path)
    im.file_format = 'PNG'
    im.save()
    bpy.data.images.remove(im)


def down(arr, size):
    f = arr.shape[0] // size
    if f <= 1:
        return arr
    h, w, c = arr.shape
    return arr.reshape(h // f, f, w // f, f, c).mean(axis=(1, 3))


def down_normal(arr, size):
    n = down(arr * 2 - 1, size)
    n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
    return n * 0.5 + 0.5


def hsv(rgb):
    top, bottom = rgb.max(axis=-1), rgb.min(axis=-1)
    span = np.maximum(top - bottom, 1e-6)
    sat = np.where(top > 1e-6, (top - bottom) / np.maximum(top, 1e-6), 0.0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.where(top == r, ((g - b) / span) % 6, 0.0)
    hue = np.where(top == g, (b - r) / span + 2, hue)
    hue = np.where(top == b, (r - g) / span + 4, hue) * 60.0
    return hue, sat, top


def glow_weight(rgb, bands):
    hue, sat, val = hsv(rgb)
    w = np.zeros(hue.shape, np.float32)
    for h1, h2, h3, h4, s1, s2, v1, v2, gain in bands:
        band = ramp(hue, h1, h2) * (1 - ramp(hue, h3, h4)) * ramp(sat, s1, s2) * ramp(val, v1, v2) * gain
        w = np.maximum(w, band)
    return w


# ---------------------------------------------------------------------------
# PHASE 1 - geometry + bakes
# ---------------------------------------------------------------------------
def channel_socket(nt, bsdf, name):
    inp = bsdf.inputs[name]
    if not inp.is_linked:
        return None
    return inp.links[0].from_node


def source_materials(hp, P):
    """Every material on the full-detail source -> [(material, tree, principled, output)].
    Single-material Meshy FBXs pack JPEG copies of their colour/normal maps: those are
    swapped for the fan's lossless PNGs (P['tex']). V6's FBX names its PNGs directly."""
    mats = []
    for slot in hp.material_slots:
        mat = slot.material
        if mat is None or not mat.use_nodes:
            continue
        nt = mat.node_tree
        bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
        out = next((n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL' and n.is_active_output),
                   next(n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'))
        mats.append((mat, nt, bsdf, out))
    assert mats, 'the source has no node materials'
    if P.get('tex'):
        assert len(mats) == 1, 'a texture swap expects the single Meshy material'
        mat, nt, bsdf, _ = mats[0]
        for chan, (rel, want) in P['tex'].items():
            path = SRC / rel
            assert md5(path) == want, f'source texture changed: {path}'
            if chan == 'color':
                node = channel_socket(nt, bsdf, 'Base Color')
            elif chan == 'metallic':
                node = channel_socket(nt, bsdf, 'Metallic')
            elif chan == 'roughness':
                node = channel_socket(nt, bsdf, 'Roughness')
            else:
                nm = channel_socket(nt, bsdf, 'Normal')
                assert nm is not None and nm.type == 'NORMAL_MAP', 'expected a Normal Map node on the source'
                node = nm.inputs['Color'].links[0].from_node
            assert node is not None and node.type == 'TEX_IMAGE', (chan, node)
            im = bpy.data.images.load(str(path), check_existing=False)
            im.colorspace_settings.name = 'sRGB' if chan == 'color' else 'Non-Color'
            node.image = im
            node.interpolation = 'Linear'
    for mat, nt, bsdf, _ in mats:
        nm = channel_socket(nt, bsdf, 'Normal') if bsdf else None
        if nm is None or nm.type != 'NORMAL_MAP' or not nm.inputs['Color'].is_linked:
            continue
        # THE FAN'S NORMAL MAPS ARE DIRECTX GREEN (measured 2026-10-02: the
        # integrability test in tools/fan_props/normal_convention.py scores the sign
        # +0.38, the first chest +0.35 and V6's Meshy exterior +0.34, against a Blender
        # control bake at -0.87 OpenGL / +0.86 DirectX; V6's CyberCrate normal is flat).
        # Blender's Normal Map node reads OpenGL, so flip green here or every baked
        # bump comes out inverted on one axis.
        src = nm.inputs['Color'].links[0].from_socket
        sep = nt.nodes.new('ShaderNodeSeparateColor')
        comb = nt.nodes.new('ShaderNodeCombineColor')
        inv = nt.nodes.new('ShaderNodeMath')
        inv.operation = 'SUBTRACT'
        inv.inputs[0].default_value = 1.0
        nt.links.new(src, sep.inputs['Color'])
        nt.links.new(sep.outputs['Red'], comb.inputs['Red'])
        nt.links.new(sep.outputs['Green'], inv.inputs[1])
        nt.links.new(inv.outputs[0], comb.inputs['Green'])
        nt.links.new(sep.outputs['Blue'], comb.inputs['Blue'])
        nt.links.new(comb.outputs['Color'], nm.inputs['Color'])
    return mats


def socket_or_constant(nt, bsdf, name):
    """The socket feeding a Principled input, or a constant node holding its value."""
    inp = bsdf.inputs[name]
    if inp.is_linked:
        return inp.links[0].from_socket
    val = inp.default_value
    if hasattr(val, '__len__'):
        node = nt.nodes.new('ShaderNodeRGB')
        node.outputs[0].default_value = tuple(val)
    else:
        node = nt.nodes.new('ShaderNodeValue')
        node.outputs[0].default_value = float(val)
    return node.outputs[0]


def wire_channel(mats, chan):
    """Point every source material's output at an Emission shader carrying one channel:
    'c' base colour, 'm' metallic, 'r' roughness, 'e' the AUTHORED glow (colour x strength).
    Returns the restore list."""
    restore = []
    for mat, nt, bsdf, out in mats:
        surface = out.inputs['Surface'].links[0].from_socket if out.inputs['Surface'].is_linked else None
        restore.append((nt, out, surface))
        emit = nt.nodes.new('ShaderNodeEmission')
        emit.inputs['Strength'].default_value = 1.0
        if bsdf is None:
            emit.inputs['Color'].default_value = (0, 0, 0, 1)
        elif chan == 'e':
            nt.links.new(socket_or_constant(nt, bsdf, 'Emission Color'), emit.inputs['Color'])
            strength = bsdf.inputs['Emission Strength']
            if strength.is_linked:
                nt.links.new(strength.links[0].from_socket, emit.inputs['Strength'])
            else:
                emit.inputs['Strength'].default_value = float(strength.default_value)
        else:
            nt.links.new(socket_or_constant(nt, bsdf, {'c': 'Base Color', 'm': 'Metallic', 'r': 'Roughness'}[chan]),
                         emit.inputs['Color'])
        nt.links.new(emit.outputs['Emission'], out.inputs['Surface'])
    return restore


def unwire(restore):
    for nt, out, surface in restore:
        if surface is not None:
            nt.links.new(surface, out.inputs['Surface'])


def has_glow(mats):
    for _, _, bsdf, _ in mats:
        if bsdf is None:
            continue
        s = bsdf.inputs['Emission Strength']
        if s.is_linked or s.default_value > 0:
            return True
    return False


def make_low_groups(hp, P):
    """V6 (2026-10-02): a Meshy shell around ~950 separate modelled parts. ONE decimate
    over all of it bridged parts and laid a huge black triangle across the open top
    (tmp/fan_props_stage/strip_v6a.jpg), so each material GROUP is reduced on its own,
    with no vertex welding across parts, then joined. The face attribute tod_group
    carries the group to weight_islands (the rounds are flat colours: little atlas)."""
    lp = hp.copy()
    lp.data = hp.data.copy()
    lp.name = P['model'] + '_low'
    bpy.context.scene.collection.objects.link(lp)
    me = lp.data
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    names = [s.material.name if s.material else '' for s in lp.material_slots]
    group_of = {}
    for gi, g in enumerate(P['groups']):
        for m in g['mats']:
            group_of[m] = gi
    missing = [n for n in names if n not in group_of]
    assert not missing, f'materials with no group: {missing}'
    bm = bmesh.new()
    bm.from_mesh(me)
    lo_z = min(v.co.z for v in bm.verts)
    hi_y = max(v.co.y for v in bm.verts)
    bm.normal_update()
    kill = [f for f in bm.faces
            if (P['drop'] == 'bottom' and f.normal.z < -0.95 and f.calc_center_median().z < lo_z + 0.006)
            or (P['drop'] == 'back' and f.normal.y > 0.95 and f.calc_center_median().y > hi_y - 0.006)]   # the power terminal: flush to its wall
    dropped = len(kill)
    bmesh.ops.delete(bm, geom=kill, context='FACES')
    gl = bm.faces.layers.int.new('tod_group')
    for f in bm.faces:
        f[gl] = group_of[names[f.material_index]]
    bm.to_mesh(me)
    bm.free()
    select_only(lp)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.separate(type='MATERIAL')
    bpy.ops.object.mode_set(mode='OBJECT')
    pieces = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o is not hp]
    by_group = {}
    for o in pieces:
        o.data.calc_loop_triangles()
        used = {p.material_index for p in o.data.polygons}
        gi = group_of[o.material_slots[used.pop()].material.name] if used else 0
        by_group.setdefault(gi, []).append(o)
    report = {}
    for gi, objs in by_group.items():
        g = P['groups'][gi]
        total = sum(len(o.data.loop_triangles) for o in objs)
        ratio = 1.0 if not g.get('tris') else min(1.0, g['tris'] / total)
        for o in objs:
            # Weld, then split every edge shared by 3+ faces into boundaries: V6's shell
            # has 336 such edges where its parts were joined, and the collapse decimator
            # tore holes through them (shell_test.py: unwelded 16K = 39 cm off the
            # original; welded + split 24K = 1.0 cm at the 99th percentile).
            b = bmesh.new()
            b.from_mesh(o.data)
            bmesh.ops.remove_doubles(b, verts=b.verts, dist=1e-5)
            bmesh.ops.split_edges(b, edges=[e for e in b.edges if len(e.link_faces) > 2])
            b.to_mesh(o.data)
            b.free()
            if ratio < 1.0:
                mod = o.modifiers.new('reduce', 'DECIMATE')
                mod.decimate_type = 'COLLAPSE'
                mod.ratio = ratio
                mod.use_collapse_triangulate = True
                select_only(o)
                bpy.ops.object.modifier_apply(modifier=mod.name)
            o.data.calc_loop_triangles()
        report[g['name']] = (total, sum(len(o.data.loop_triangles) for o in objs))
    bpy.ops.object.select_all(action='DESELECT')
    for o in pieces:
        o.select_set(True)
    bpy.context.view_layer.objects.active = pieces[0]
    bpy.ops.object.join()
    lp = bpy.context.view_layer.objects.active
    lp.name = P['model'] + '_low'
    me = lp.data
    for p in me.polygons:
        p.material_index = 0
    me.materials.clear()
    me.set_sharp_from_angle(angle=math.radians(SHARP_DEG))
    me.shade_smooth()
    select_only(lp)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.ops.uv.smart_project(angle_limit=math.radians(SHARP_DEG), island_margin=0.003, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    weight_islands(lp, [g.get('uv', 1.0) for g in P['groups']])
    select_only(lp)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.select_all(action='SELECT')
    bpy.ops.uv.pack_islands(rotate=True, margin=0.002, shape_method='CONCAVE')
    bpy.ops.object.mode_set(mode='OBJECT')
    me.calc_loop_triangles()
    log(P['model'], 'low poly by group', {k: f'{a} -> {b}' for k, (a, b) in report.items()},
        '=', len(me.loop_triangles), 'tris, dropped', dropped, 'faces')
    return lp


def make_low(hp, P):
    if P.get('groups'):
        return make_low_groups(hp, P)
    reuse = P['method'] == 'reuse'
    lp = hp.copy()
    lp.data = hp.data.copy()
    lp.name = P['model'] + '_low'
    bpy.context.scene.collection.objects.link(lp)
    me = lp.data
    if not reuse:
        while me.uv_layers:
            me.uv_layers.remove(me.uv_layers[0])
    me.materials.clear()
    bm = bmesh.new()
    bm.from_mesh(me)
    if not reuse:
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    lo = Vector([min(v.co[i] for v in bm.verts) for i in range(3)])
    hi = Vector([max(v.co[i] for v in bm.verts) for i in range(3)])
    dropped = 0
    if P['drop']:
        bm.normal_update()
        kill = []
        for f in bm.faces:
            c = f.calc_center_median()
            if P['drop'] == 'back' and f.normal.y > 0.95 and c.y > hi.y - 0.006:
                kill.append(f)
            if P['drop'] == 'bottom' and f.normal.z < -0.95 and c.z < lo.z + 0.006:
                kill.append(f)
        dropped = len(kill)
        bmesh.ops.delete(bm, geom=kill, context='FACES')
    bm.to_mesh(me)
    bm.free()
    me.calc_loop_triangles()
    n0 = len(me.loop_triangles)
    mod = lp.modifiers.new('reduce', 'DECIMATE')
    mod.decimate_type = 'COLLAPSE'
    mod.ratio = min(1.0, P['tris'] / n0)
    mod.use_collapse_triangulate = True
    select_only(lp)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    me = lp.data
    me.set_sharp_from_angle(angle=math.radians(SHARP_DEG))
    me.shade_smooth()
    select_only(lp)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.quads_convert_to_tris()
    if not reuse:
        bpy.ops.uv.smart_project(angle_limit=math.radians(SHARP_DEG), island_margin=0.003, area_weight=0.0,
                                 correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    if not reuse:
        weight_islands(lp)
        select_only(lp)
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.select_all(action='SELECT')
        bpy.ops.uv.pack_islands(rotate=True, margin=0.002, shape_method='CONCAVE')
        bpy.ops.object.mode_set(mode='OBJECT')
    me.calc_loop_triangles()
    log(P['model'], 'low poly', n0, '->', len(me.loop_triangles), 'tris, dropped', dropped, 'faces')
    return lp


def weight_islands(lp, group_uv=None):
    """Spend the atlas where players look (the chest's first bake, 2026-10-02: thousands of
    decimated shell/cell islands inside the case took most of the sheet and left the
    front icon plate ~90 px wide). Each UV island is scaled about its centre by how
    EXPOSED its faces are - rays from each face into its hemisphere that leave the model -
    with a boost for faces turned to the front (-Y, the Meshy front) or up (into the
    open case); pack_islands then keeps those relative sizes."""
    from mathutils.bvhtree import BVHTree
    me = lp.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bm.normal_update()
    uvl = bm.loops.layers.uv.active
    gl = bm.faces.layers.int.get('tod_group') if group_uv else None
    parent = list(range(len(bm.faces)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    def uv_at(f, v):
        for l in f.loops:
            if l.vert == v:
                return l[uvl].uv
        return None

    for e in bm.edges:
        if len(e.link_faces) != 2:
            continue
        f0, f1 = e.link_faces
        a, b = e.verts
        if (uv_at(f0, a) - uv_at(f1, a)).length < 1e-6 and (uv_at(f0, b) - uv_at(f1, b)).length < 1e-6:
            ra, rb_ = find(f0.index), find(f1.index)
            if ra != rb_:
                parent[ra] = rb_
    bvh = BVHTree.FromBMesh(bm)
    size = max(max(v.co[i] for v in bm.verts) - min(v.co[i] for v in bm.verts) for i in range(3))
    golden = math.pi * (3 - math.sqrt(5))
    dirs = []
    for k in range(24):                                   # Fibonacci sphere: 24 even directions
        z = 1 - 2 * (k + 0.5) / 24
        r = math.sqrt(1 - z * z)
        dirs.append(Vector((math.cos(golden * k) * r, math.sin(golden * k) * r, z)))
    front, up = Vector((0, -1, 0)), Vector((0, 0, 1))
    score = {}
    for f in bm.faces:
        n = f.normal
        c = f.calc_center_median() + n * (0.002 * size)
        tried = escaped = 0
        for d in dirs:
            if d.dot(n) < 0.15:
                continue
            tried += 1
            if bvh.ray_cast(c, d, size * 3)[0] is None:
                escaped += 1
        vis = escaped / max(tried, 1)
        imp = (0.3 + 1.7 * vis) * (1 + 0.6 * max(0.0, n.dot(front)) + 0.35 * max(0.0, n.dot(up)))
        if gl is not None:
            imp *= group_uv[f[gl]]                       # e.g. V6's rounds: flat colours need little atlas
        root = find(f.index)
        a = f.calc_area()
        s = score.setdefault(root, [0.0, 0.0])
        s[0] += imp * a
        s[1] += a
    islands = {}
    for f in bm.faces:
        islands.setdefault(find(f.index), []).append(f)
    scales = []
    for root, faces in islands.items():
        k = score[root][0] / max(score[root][1], 1e-12)
        loops = [l for f in faces for l in f.loops]
        cu = sum(l[uvl].uv.x for l in loops) / len(loops)
        cv = sum(l[uvl].uv.y for l in loops) / len(loops)
        for l in loops:
            uv = l[uvl].uv
            uv.x, uv.y = cu + (uv.x - cu) * k, cv + (uv.y - cv) * k
        scales.append(k)
    bm.to_mesh(me)
    bm.free()
    log(lp.name, 'uv islands', len(islands), 'scale min/median/max',
        round(min(scales), 2), round(float(np.median(scales)), 2), round(max(scales), 2))


def bake_target(lp, name, colorspace, size=BAKE_SIZE):
    im = bpy.data.images.new(name, size, size, alpha=False)
    im.colorspace_settings.name = colorspace
    mat = lp.data.materials[0]
    node = mat.node_tree.nodes['bake_target']
    node.image = im
    mat.node_tree.nodes.active = node
    return im


def join_source(meshes, rename):
    """A source delivered as several objects (the power terminal: one Meshy mesh + five thin lettering plates) ->
    one object. An object whose name starts with a key of `rename` first gets a COPY of its material under the
    mapped name, so its faces form their own reduction group (make_low_groups keys groups by material name)."""
    for o in meshes:
        for prefix, name in rename.items():
            if not o.name.startswith(prefix):
                continue
            for slot in o.material_slots:
                if slot.material is None:
                    continue
                copy = bpy.data.materials.get(name)
                if copy is None:
                    copy = slot.material.copy()
                    copy.name = name
                slot.material = copy
    main = max(meshes, key=lambda o: len(o.data.polygons))
    select_only(main, *[o for o in meshes if o is not main])
    bpy.ops.object.join()
    hp = bpy.context.view_layer.objects.active
    log(hp.name, 'joined', len(meshes), 'source objects, materials', [s.material.name for s in hp.material_slots if s.material])
    return hp


def bake_prop(key, P):
    stage = STAGE / key
    stage.mkdir(parents=True, exist_ok=True)
    clear_scene()
    fbx = SRC / P['fbx'][0]
    assert md5(fbx) == P['fbx'][1], f'source FBX changed: {fbx}'
    for rel, want in (P.get('deps') or {}).items():
        assert md5(SRC / rel) == want, f'source texture changed: {rel}'   # textures the FBX loads by path
    t0 = time.time()
    bpy.ops.import_scene.fbx(filepath=str(fbx))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    if P.get('join'):
        hp = join_source(meshes, P['join'])
    else:
        assert len(meshes) == 1, meshes
        hp = meshes[0]
    hp.data.transform(hp.matrix_world)
    hp.matrix_world = Matrix.Identity(4)
    mats = source_materials(hp, P)
    for mat, nt, bsdf, _ in mats:
        if bsdf is not None and mat.name in (P.get('emit') or {}):
            # the power terminal's screen sheet is wired into Emission at strength 0: turn it on for the 'e' bake
            bsdf.inputs['Emission Strength'].default_value = float(P['emit'][mat.name])
    size = max(hp.dimensions)
    lp = make_low(hp, P)
    if P['method'] == 'reuse':
        save_low(lp, stage)
        lp.data.calc_loop_triangles()
        (stage / 'bake.json').write_text(json.dumps(dict(
            fbx_md5=P['fbx'][1], method='reuse', tris=len(lp.data.loop_triangles), verts=len(lp.data.vertices),
            source_size_m=size, total_seconds=round(time.time() - t0, 1)), indent=1))
        log(key, 'low poly kept the source UVs (no bake) in', round(time.time() - t0, 1), 's')
        return

    bm_mat = bpy.data.materials.new(P['model'] + '_bake')
    bm_mat.use_nodes = True
    tn = bm_mat.node_tree.nodes.new('ShaderNodeTexImage')
    tn.name = 'bake_target'
    lp.data.materials.append(bm_mat)

    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 8
    rb = scene.render.bake
    rb.use_selected_to_active = True
    rb.cage_extrusion = 0.012 * size
    rb.max_ray_distance = 0.03 * size
    rb.margin = 8
    rb.margin_type = 'EXTEND'
    rb.use_clear = True
    rb.normal_space = 'TANGENT'
    rb.normal_r, rb.normal_g, rb.normal_b = 'POS_X', 'NEG_Y', 'POS_Z'   # DirectX green: native BO3 tangent normals
    select_only(lp, hp)

    # Colour always; metal + roughness when the prop has PBR to carry (the terminal shipped
    # colour only); the AUTHORED glow when a material emits (V6's energy bands).
    chans = ['c'] + (['m', 'r'] if P.get('pbr', True) else []) + (['e'] if has_glow(mats) else [])
    for stale in stage.glob('bake_*.png'):
        stale.unlink()                                  # a channel this run skips must not leak in from an old run
    baked = {}
    for chan in chans:
        restore = wire_channel(mats, chan)
        im = bake_target(lp, f'{key}_bake_{chan}', 'sRGB' if chan in ('c', 'e') else 'Non-Color', P.get('bake_size', BAKE_SIZE))
        tb = time.time()
        bpy.ops.object.bake(type='EMIT')
        im.filepath_raw = str(stage / f'bake_{chan}.png')
        im.file_format = 'PNG'
        im.save()
        baked[chan] = round(time.time() - tb, 1)
        unwire(restore)
    im = bake_target(lp, f'{key}_bake_n', 'Non-Color', P.get('bake_size', BAKE_SIZE))
    tb = time.time()
    bpy.ops.object.bake(type='NORMAL')
    im.filepath_raw = str(stage / 'bake_n.png')
    im.file_format = 'PNG'
    im.save()
    baked['n'] = round(time.time() - tb, 1)

    tris, verts = save_low(lp, stage)
    (stage / 'bake.json').write_text(json.dumps(dict(
        fbx_md5=P['fbx'][1], method='bake', tris=tris, verts=verts, source_size_m=size, seconds=baked,
        total_seconds=round(time.time() - t0, 1), cage=rb.cage_extrusion, ray=rb.max_ray_distance), indent=1))
    log(key, 'baked', baked, 'in', round(time.time() - t0, 1), 's')


def save_low(lp, stage):
    me = lp.data
    me.calc_loop_triangles()
    uv = me.uv_layers.active.data
    V = np.array([v.co[:] for v in me.vertices], dtype=np.float64)
    tv = np.array([[me.loops[li].vertex_index for li in t.loops] for t in me.loop_triangles], dtype=np.int32)
    tn_ = np.array([[me.corner_normals[li].vector[:] for li in t.loops] for t in me.loop_triangles], dtype=np.float64)
    tuv = np.array([[uv[li].uv[:] for li in t.loops] for t in me.loop_triangles], dtype=np.float64)
    np.savez(stage / 'low.npz', V=V, tv=tv, tn=tn_, tuv=tuv)
    return len(tv), len(V)


# ---------------------------------------------------------------------------
# PHASE 2 - maps, binaries, GDT, previews, manifest
# ---------------------------------------------------------------------------
def place(V, P):
    """Source frame (Meshy: front -Y, Z up) -> the prop's BO3 local frame, scaled and pivoted."""
    if P['front'] == '+X':
        R = np.array([[0, -1, 0], [1, 0, 0], [0, 0, 1]], dtype=np.float64)    # Rz(+90): -Y -> +X
    elif P['front'] == '+Y':
        R = np.array([[-1, 0, 0], [0, -1, 0], [0, 0, 1]], dtype=np.float64)   # Rz(180): -Y -> +Y
    elif P['front'] == 'nose+X':
        # THE ROCKETS lie down: Meshy +Z (the nose) -> local +X, Meshy -Y (the window side) -> local +Z, so
        # local +Y = -Meshy X (a proper rotation, det +1). Standing at angles ( -90, yaw, 0 ) the windows face
        # yaw + 180 (AnglesToUp of a pitch -90 frame points back along the yaw).
        R = np.array([[0, 0, 1], [-1, 0, 0], [0, -1, 0]], dtype=np.float64)
    else:
        raise ValueError(P['front'])
    axis, length = P['fit']
    s = length / float(V[:, axis].max() - V[:, axis].min())
    p = (V @ R.T) * s
    lo, hi = p.min(axis=0), p.max(axis=0)
    if P['pivot'] == 'back':
        t = np.array([-lo[0], -(lo[1] + hi[1]) / 2, -lo[2]])
    elif P['pivot'] == 'floor':
        t = np.array([-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]])
    elif P['pivot'] == 'crate':
        t = np.array([-(lo[0] + hi[0]) / 2, CRATE_BACK - lo[1], -lo[2]])
    elif P['pivot'] == 'tail':
        # the rockets: on the axis (the four fins are symmetric, so the box centre IS the axis), at the feet
        t = np.array([-lo[0], -(lo[1] + hi[1]) / 2, -(lo[2] + hi[2]) / 2])
    else:
        raise ValueError(P['pivot'])
    return p + t, R, s


def write_binary(key, P, pos, R, tv, tn, tuv):
    name = P['model']
    model = xmodel.Model(name)
    model.version = 6
    root = xmodel.Bone('tag_origin', -1)
    root.offset = (0.0, 0.0, 0.0)
    root.matrix = [(1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)]
    model.bones.append(root)
    model.materials.append(xmodel.Material(P['material'], 'Phong', {}))
    mesh = xmodel.Mesh(name)
    for p in pos:
        mesh.verts.append(xmodel.Vertex(tuple(float(x) for x in p), [(0, 1.0)]))
    nrm = tn @ R.T
    for f in range(len(tv)):
        face = xmodel.Face(0, 0)
        # Blender and BO3's raw export use opposite winding (every repo exporter flips it).
        for j, c in enumerate((0, 2, 1)):
            n = nrm[f, c] / max(np.linalg.norm(nrm[f, c]), 1e-9)
            u, v = tuv[f, c]
            face.indices[j] = xmodel.FaceVertex(int(tv[f, c]), tuple(float(x) for x in n), (1, 1, 1, 1), (float(u), float(1 - v)))
        mesh.faces.append(face)
    model.meshes.append(mesh)
    stage = STAGE / key
    raw = stage / (name + '.XMODEL_EXPORT')
    model.WriteFile_Raw(str(raw))
    # Bare name + cwd: given absolute paths export2bin SILENTLY copies the text file
    # through (memory cod-asset-binary-pipeline). The *LZ4* magic proves it did not.
    run = subprocess.run([str(TOOLS / 'bin/export2bin.exe'), raw.name], cwd=stage, capture_output=True, text=True, timeout=600)
    (stage / 'export2bin.log').write_text(run.stdout + '\n' + run.stderr)
    assert run.returncode == 0, (run.stdout, run.stderr)
    binary = next(p for p in stage.iterdir() if p.name.lower() == name + '.xmodel_bin')
    assert binary.read_bytes()[:5] == b'*LZ4*', 'export2bin passed the text file through'
    OUT.mkdir(parents=True, exist_ok=True)
    dst = OUT / (name + '.xmodel_bin')
    shutil.copyfile(binary, dst)
    check = xmodel.Model()
    check.LoadFile_Bin(str(dst))
    got_v, got_f = sum(len(m.verts) for m in check.meshes), sum(len(m.faces) for m in check.meshes)
    assert [(b.name, b.parent) for b in check.bones] == [('tag_origin', -1)]
    assert got_v == len(pos), f'{name}: wrote {len(pos)} verts, binary has {got_v}'
    assert got_f == len(tv), f'{name}: wrote {len(tv)} faces, binary has {got_f}'
    assert [m.name for m in check.materials] == [P['material']]
    return dst, check, pos


def write_maps(key, P):
    stage = STAGE / key
    sz = P['sizes']
    if P['method'] == 'reuse':
        # The fan's own sheets on the fan's own UVs, brought to the shipped sizes.
        # Their normal map is already DirectX green (see source_material), so it ships as-is.
        def src(chan):
            rel, want = P['tex'][chan]
            assert md5(SRC / rel) == want, rel
            return read_image(SRC / rel)
        colour = down(src('color'), BAKE_SIZE)
        normal = down_normal(src('normal'), BAKE_SIZE)
        metal = down(src('metallic'), BAKE_SIZE)[..., :1]
        rough = down(src('roughness'), BAKE_SIZE)[..., :1]
    else:
        colour = read_image(stage / 'bake_c.png')                 # sRGB-encoded albedo
        metal = read_image(stage / 'bake_m.png')[..., :1] if (stage / 'bake_m.png').exists() else None
        rough = read_image(stage / 'bake_r.png')[..., :1] if (stage / 'bake_r.png').exists() else None
        normal = read_image(stage / 'bake_n.png')
    lin = srgb_to_lin(colour)
    files = {}
    pre = IMG / P['img']
    IMG.mkdir(parents=True, exist_ok=True)

    diffuse = lin if metal is None else lin * (1 - METAL_DIFFUSE_CUT * metal)
    files['c'] = pre.with_name(P['img'] + '_c.png')
    write_image(down(lin_to_srgb(diffuse), sz['c']), files['c'], 'sRGB')
    files['n'] = pre.with_name(P['img'] + '_n.png')
    write_image(down_normal(normal, sz['n']), files['n'], 'Non-Color')
    if 's' in sz:
        spec = 0.04 * (1 - metal) + lin * metal
        files['s'] = pre.with_name(P['img'] + '_s.png')
        write_image(down(lin_to_srgb(spec), sz['s']), files['s'], 'sRGB')
        files['g'] = pre.with_name(P['img'] + '_g.png')
        write_image(np.repeat(down(1 - rough, sz['g']), 3, axis=-1), files['g'], 'Non-Color')
    weight = glow_weight(colour, GLOW[key])
    glow = colour * weight[..., None]
    if P['method'] == 'bake' and (stage / 'bake_e.png').exists():
        # V6 ships real emission (the rounds' energy bands); the painted neon on the
        # Meshy exterior still needs the cut. The brighter of the two wins per texel.
        authored = read_image(stage / 'bake_e.png')
        if P.get('emit_floor'):
            # the power terminal: its whole screen sheet emits, so its navy background would glow too; ramp the
            # emission in by the texel's own brightness (sRGB-encoded max channel) - the art lights, the navy stays
            authored = authored * ramp(authored.max(axis=-1), *P['emit_floor'])[..., None]
        glow = np.maximum(glow, authored)
    files['e'] = pre.with_name(P['img'] + '_e.png')
    write_image(down(glow, sz['e']), files['e'], 'sRGB')
    if P.get('wreck'):
        # THE WRECK (the spire ship after the crash): the same UVs, burnt. Desaturate, darken, and break it up with
        # low-frequency soot (UV-space blotches, seeded: the same every run); the windows' glow mask re-lit as dim
        # orange embers, some of them out. Normal / spec / gloss stay the ship's own (shared images).
        W = P['wreck']
        h, w = lin.shape[:2]
        rng = np.random.default_rng(1977)
        coarse = rng.random((h // 128 + 2, w // 128 + 2)).astype(np.float32)
        ys = np.linspace(0, coarse.shape[0] - 1.001, h)
        xs = np.linspace(0, coarse.shape[1] - 1.001, w)
        y0, x0 = ys.astype(int), xs.astype(int)
        fy, fx = (ys - y0)[:, None], (xs - x0)[None, :]
        c00, c01 = coarse[y0][:, x0], coarse[y0][:, x0 + 1]
        c10, c11 = coarse[y0 + 1][:, x0], coarse[y0 + 1][:, x0 + 1]
        soot = (c00 * (1 - fx) + c01 * fx) * (1 - fy) + (c10 * (1 - fx) + c11 * fx) * fy   # 0..1, smooth blotches
        luma = (lin * np.array([0.2126, 0.7152, 0.0722], np.float32)).sum(axis=-1, keepdims=True)
        burnt = (lin * (1 - WRECK_DESAT) + luma * WRECK_DESAT) * WRECK_DARK * (0.45 + 0.55 * soot[..., None])
        files['wc'] = IMG / (W['img'] + '_c.png')
        write_image(down(lin_to_srgb(burnt), sz['c']), files['wc'], 'sRGB')
        embers = weight[..., None] * np.array(WRECK_EMBER, np.float32) * WRECK_EMBER_GAIN * np.clip(soot[..., None] * 1.6 - 0.25, 0, 1)
        files['we'] = IMG / (W['img'] + '_e.png')
        write_image(down(embers, sz['e']), files['we'], 'sRGB')
    # review aid: the mask over a dimmed copy of the colour (tmp only, never shipped)
    review = colour * 0.25 + np.stack([weight, weight * 0.8, weight * 0.2], axis=-1) * 0.75
    write_image(down(review, 1024), stage / 'review_glow_mask.png', 'sRGB')
    stats = dict(glow_fraction=round(float((weight > 0.5).mean()), 4),
                 metal_mean=None if metal is None else round(float(metal.mean()), 3),
                 rough_mean=None if rough is None else round(float(rough.mean()), 3))
    return files, stats


IMAGE_BLOCK = """\t"{name}" ( "image.gdf" )
\t{{
\t\t"baseImage" "model_export\\\\{folder}\\\\_images\\\\{name}.png"
\t\t"imageType" "Texture"
\t\t"type" "image"
\t\t"semantic" "{semantic}"
\t\t"compressionMethod" "{compression}"
\t\t"streamable" "1"{core}
\t}}"""

def xmodel_block(P):
    """One full-detail LOD by default (autogen off: the staff shaft / altar crest lesson). A
    prop that names `lods` gets the linker's own reduced LODs at those distances instead."""
    lods = {name: (pct, dist) for name, pct, dist in P.get('lods', [])}
    fields = [('filename', f'{FOLDER}\\\\{P["model"]}.xmodel_bin'), ('type', 'rigid'), ('skinOverride', ''),
              ('BulletCollisionLOD', 'High'), ('physicsPreset', ''), ('scale', '1'), ('highLodDist', '0')]
    for name in ('Medium', 'Low', 'Lowest'):
        if name in lods:
            pct, dist = lods[name]
            fields += [(f'autogen{name}Lod', '1'), (f'autogen{name}LodPercent', str(pct)), (f'{name.lower()}LodDist', str(dist))]
        else:
            fields.append((f'autogen{name}Lod', '0'))
    fields += [(f'autogenLod{i}', '0') for i in range(4, 8)]
    fields += [('lodNormalPriority', '1'), ('lodPositionPriority', '1')]
    return f'\t"{P["model"]}" ( "xmodel.gdf" )\n\t{{\n' + '\n'.join(f'\t\t"{k}" "{v}"' for k, v in fields) + '\n\t}'

IMAGE_KINDS = {   # suffix -> (semantic, compression, sRGB core semantic?)
    'c': ('diffuseMap', 'compressed high color', True),
    'e': ('diffuseMap', 'compressed high color', True),
    's': ('specularMap', 'compressed high color', True),
    'n': ('normalMap', 'compressed', False),
    'g': ('glossMap', 'compressed', False),
}


def material_block(P):
    i = P['img']
    if P['shader'] == 'fullspec':
        fields = {'surfaceType': 'metal', 'template': 'material.template',
                  'materialCategory': 'Geometry Advanced', 'materialType': 'lit_emissive_advanced_fullspec',
                  'colorMap': i + '_c', 'normalMap': i + '_n', 'cosinePowerMap': i + '_g', 'specColorMap': i + '_s',
                  'specMapEnable': '1', 'specColorTint': '1 1 1 1', 'colorMap00': i + '_e',
                  'colorTint': '1 1 1 1', 'colorTint1': '1 1 1 1', 'scaleRGB': P['scale_rgb'],
                  'emissiveIncompetence': '1', 'emissiveFalloff': '0', 'normalHeightScale': '1',
                  'glossRangeMin': str(P['gloss'][0]), 'glossRangeMax': str(P['gloss'][1]),
                  'specAmount': P['spec_amount'], 'reflectionProbeAmount': P['probe'],
                  'textureAtlasRowCount': '1', 'textureAtlasColumnCount': '1',
                  'usage': '<not in editor>', 'waterRoughness': '0'}
    else:
        # lit_emissive_plus = the teddy / BO6 inducer recipe. The terminal shipped
        # colour only, so there is no honest metal/roughness to bake; the gloss RANGE
        # holds it at satin whatever the default gloss map is.
        fields = {'surfaceType': 'metal', 'template': 'material.template',
                  'materialCategory': 'Geometry Plus', 'materialType': 'lit_emissive_plus',
                  'colorMap': i + '_c', 'normalMap': i + '_n', 'colorTint': '1 1 1 1',
                  'textureAtlasRowCount': '1', 'textureAtlasColumnCount': '1',
                  'usage': '<not in editor>', 'heatmap': '$gray_32_one_channel',
                  'normalHeightScale': '1', 'glossRangeMin': str(P['gloss'][0]), 'glossRangeMax': str(P['gloss'][1]),
                  'specAmount': P['spec_amount'], 'reflectionProbeAmount': P['probe'], 'waterRoughness': '0',
                  'colorMap00': i + '_e', 'colorTint1': '1 1 1 1', 'scaleRGB': P['scale_rgb'],
                  'emissiveIncompetence': '1', 'emissiveFalloff': '0'}
    return f'\t"{P["material"]}" ( "material.gdf" )\n\t{{\n' + '\n'.join(
        f'\t\t"{k}" "{v}"' for k, v in fields.items()) + '\n\t}'


def write_gdt(built):
    blocks = []
    for key, P in PROPS.items():
        if key not in built:
            continue
        for suffix in P['sizes']:
            sem, comp, srgb = IMAGE_KINDS[suffix]
            core = '\n\t\t"coreSemantic" "sRGB3chAlpha"' if srgb else ''
            blocks.append(IMAGE_BLOCK.format(name=P['img'] + '_' + suffix, folder=FOLDER, semantic=sem, compression=comp, core=core))
        blocks.append(material_block(P))
        blocks.append(xmodel_block(P))
        for n in (P['model'], P['material']) + tuple(P['img'] + '_' + s for s in P['sizes']):
            assert len(n) <= 32, n   # BO3 truncates long names and default-substitutes (the inducer glass, v18.99h)
        if P.get('wreck'):
            # the burnt twin: its own colour + ember images, the ship's normal / spec / gloss, the SAME binary with a
            # skinOverride onto the burnt material (the 'orig replacement' + literal backslash-r backslash-n pair form
            # stock GDTs use, e.g. chaos_pack_a_punch.gdt)
            W = P['wreck']
            for suffix in ('c', 'e'):
                sem, comp, srgb = IMAGE_KINDS[suffix]
                blocks.append(IMAGE_BLOCK.format(name=W['img'] + '_' + suffix, folder=FOLDER, semantic=sem, compression=comp,
                                                 core='\n\t\t"coreSemantic" "sRGB3chAlpha"'))
            WP = dict(P, material=W['material'], scale_rgb=W['scale_rgb'])
            mb = material_block(WP).replace(f'"colorMap" "{P["img"]}_c"', f'"colorMap" "{W["img"]}_c"')
            mb = mb.replace(f'"colorMap00" "{P["img"]}_e"', f'"colorMap00" "{W["img"]}_e"')
            assert f'{W["img"]}_c' in mb and f'{W["img"]}_e' in mb and f'"normalMap" "{P["img"]}_n"' in mb
            blocks.append(mb)
            xb = xmodel_block(P).replace(f'	"{P["model"]}" ( "xmodel.gdf" )', f'	"{W["model"]}" ( "xmodel.gdf" )', 1)
            xb = xb.replace('"skinOverride" ""', '"skinOverride" "' + P['material'] + ' ' + W['material'] + '\\r\\n"', 1)
            assert W['model'] in xb and W['material'] in xb and P['model'] + '.xmodel_bin' in xb
            blocks.append(xb)
            for n in (W['model'], W['material'], W['img'] + '_c', W['img'] + '_e'):
                assert len(n) <= 32, n
    GDT.write_text('{\n' + '\n'.join(blocks) + '\n}\n', encoding='utf-8')


def preview(key, P, check, files):
    """Rebuild the WRITTEN binary in Blender and render it lit and in the dark (the glow read)."""
    clear_scene()
    src = check.meshes[0]
    faces, uvs, nrms = [], [], []
    for f in src.faces:
        corners = (f.indices[0], f.indices[2], f.indices[1])   # undo the export winding
        faces.append([c.vertex for c in corners])
        uvs.append([(c.uv[0], 1 - c.uv[1]) for c in corners])
        nrms.append([tuple(c.normal) for c in corners])
    stand = np.array([[0, 0, 1], [0, -1, 0], [1, 0, 0]], dtype=np.float64) if P['front'] == 'nose+X' else np.eye(3)
    me = bpy.data.meshes.new('from_bin')
    me.from_pydata([tuple(stand @ np.array(v.offset)) for v in src.verts], [], faces)
    layer = me.uv_layers.new(name='uv')
    loop_normals = [None] * len(me.loops)
    for poly, fuv, fn in zip(me.polygons, uvs, nrms):
        for li, uv, n in zip(poly.loop_indices, fuv, fn):
            layer.data[li].uv = uv
            loop_normals[li] = tuple(stand @ np.array(n))
    me.shade_smooth()
    me.normals_split_custom_set(loop_normals)          # the binary's own hard edges, not Blender's guess
    obj = bpy.data.objects.new(P['model'], me)
    bpy.context.scene.collection.objects.link(obj)
    mat = bpy.data.materials.new('preview')
    mat.use_nodes = True
    mat.use_backface_culling = True                     # a flipped face shows as a hole
    nt = mat.node_tree
    bsdf = nt.nodes['Principled BSDF']

    def tex(path, cs):
        n = nt.nodes.new('ShaderNodeTexImage')
        n.image = bpy.data.images.load(str(path), check_existing=False)
        n.image.colorspace_settings.name = cs
        return n
    nt.links.new(tex(files['c'], 'sRGB').outputs['Color'], bsdf.inputs['Base Color'])
    # the shipped normal is DirectX green; flip it back for Blender's OpenGL node
    nn = tex(files['n'], 'Non-Color')
    sep = nt.nodes.new('ShaderNodeSeparateColor'); comb = nt.nodes.new('ShaderNodeCombineColor')
    inv = nt.nodes.new('ShaderNodeMath'); inv.operation = 'SUBTRACT'; inv.inputs[0].default_value = 1.0
    nt.links.new(nn.outputs['Color'], sep.inputs['Color'])
    nt.links.new(sep.outputs['Red'], comb.inputs['Red'])
    nt.links.new(sep.outputs['Green'], inv.inputs[1]); nt.links.new(inv.outputs[0], comb.inputs['Green'])
    nt.links.new(sep.outputs['Blue'], comb.inputs['Blue'])
    nmap = nt.nodes.new('ShaderNodeNormalMap')
    nt.links.new(comb.outputs['Color'], nmap.inputs['Color'])
    nt.links.new(nmap.outputs['Normal'], bsdf.inputs['Normal'])
    if 'g' in files:
        g = tex(files['g'], 'Non-Color')
        r = nt.nodes.new('ShaderNodeMath'); r.operation = 'SUBTRACT'; r.inputs[0].default_value = 1.0
        nt.links.new(g.outputs['Color'], r.inputs[1]); nt.links.new(r.outputs[0], bsdf.inputs['Roughness'])
    else:
        bsdf.inputs['Roughness'].default_value = 0.45
    nt.links.new(tex(files['e'], 'sRGB').outputs['Color'], bsdf.inputs['Emission Color'])
    me.materials.append(mat)

    scene = bpy.context.scene
    r = scene.render
    r.engine = 'BLENDER_EEVEE_NEXT'
    scene.eevee.taa_render_samples = 48
    r.resolution_x, r.resolution_y = 900, 700
    r.image_settings.file_format = 'JPEG'
    r.image_settings.quality = 90
    scene.view_settings.view_transform = 'Standard'
    world = bpy.data.worlds.new('w'); scene.world = world; world.use_nodes = True
    bg = world.node_tree.nodes['Background']
    cam_data = bpy.data.cameras.new('cam'); cam = bpy.data.objects.new('cam', cam_data)
    scene.collection.objects.link(cam); scene.camera = cam
    cam_data.type = 'ORTHO'
    pts = np.array([stand @ np.array(v.offset) for v in src.verts])
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    centre = Vector(((lo + hi) / 2).tolist())
    span = float((hi - lo).max())
    aspect = r.resolution_x / r.resolution_y
    wide = float(max(hi[0] - lo[0], hi[1] - lo[1]))
    cam_data.ortho_scale = max(wide, float(hi[2] - lo[2]) * aspect) * 1.15   # fit both the width and the height
    cam_data.clip_start, cam_data.clip_end = span * 0.05, span * 40   # the scene is in game units: a 256-unit sign
    front = Vector((1, 0, 0)) if P['front'] in ('+X', 'nose+X') else Vector((0, 1, 0))
    lights = []
    for name, off, energy in (('key', (-0.6, 0.9, 0.6), 2.0), ('fill', (0.7, 0.6, 0.1), 0.7), ('rim', (0.0, -1.0, 0.8), 1.0)):
        side = front.cross(Vector((0, 0, 1)))
        d = (front * off[1] + side * off[0] + Vector((0, 0, off[2]))).normalized()
        ld = bpy.data.lights.new(name, 'AREA'); ld.size = span
        lo_ = bpy.data.objects.new(name, ld); scene.collection.objects.link(lo_)
        lo_.location = centre + d * span * 3
        lo_.rotation_euler = (centre - lo_.location).to_track_quat('-Z', 'Y').to_euler()
        lights.append((ld, energy * (span * 3) ** 2 * 18))
    shots = []
    ART.mkdir(parents=True, exist_ok=True)
    for tag, az, lit, strength, lift in (('front', 0, 1.0, 1.0, 0.12), ('three_quarter', 35, 1.0, 1.0, 0.12),
                                         ('side', 80, 1.0, 1.0, 0.12), ('above', 25, 1.0, 1.0, 2.2),
                                         ('dark_glow', 25, 0.05, float(P['scale_rgb']) / 2.5, 0.12)):
        for ld, energy in lights:
            ld.energy = energy * lit
        bg.inputs['Color'].default_value = (0.04, 0.045, 0.055, 1) if lit == 1.0 else (0.004, 0.005, 0.008, 1)
        bsdf.inputs['Emission Strength'].default_value = strength
        th = math.radians(az)
        side = front.cross(Vector((0, 0, 1)))
        look = -(front * math.cos(th) + side * math.sin(th))     # camera looks back at the front
        cam.location = centre - look * span * 4 + Vector((0, 0, span * lift))   # 'above' = a standing player looking down into it
        cam.rotation_euler = (centre - cam.location).to_track_quat('-Z', 'Y').to_euler()
        out = ART / f'preview_{key}_{tag}.jpg'
        r.filepath = str(out)
        bpy.ops.render.render(write_still=True)
        shots.append(out)
    return shots


def rocket_measure(pos):
    """THE ROCKET CONTRACT, measured on the shipped mesh (local frame: nose +X, pivot on the axis at the feet):
    len = nose tip x; profile = every 1/40 of the length: [x, body radius (60th percentile of the slice: the four
    thin fins are a few verts), max radius (fins included)]; bell = the engine bell's exit plane and radius (the
    lowest vertices within 0.09 len of the axis); feet = the radius the four fin tips touch down at. The ride's
    camera keeps its distance from the BODY radius, the clips and the path clearance use the MAX."""
    x = pos[:, 0]
    r = np.hypot(pos[:, 1], pos[:, 2])
    L = float(x.max())
    prof = []
    for k in range(41):
        a, b = L * (k - 0.5) / 40, L * (k + 0.5) / 40
        m = (x >= a) & (x < b)
        if m.sum() < 3:
            prof.append([round(L * k / 40, 2), 0.0, 0.0])
            continue
        prof.append([round(L * k / 40, 2), round(float(np.percentile(r[m], 60)), 2), round(float(r[m].max()), 2)])
    near = r < 0.09 * L
    bx = float(x[near].min())
    bell_r = float(r[near & (x < bx + 0.02 * L)].max())
    foot = x < 0.004 * L
    return dict(len=round(L, 2), profile=prof, bell=[round(bx, 2), round(bell_r, 2)],
                feet_r=round(float(r[foot].max()), 2) if foot.any() else None,
                max_r=round(float(r.max()), 2))


def build_prop(key, P):
    stage = STAGE / key
    data = np.load(stage / 'low.npz')
    V, tv, tn, tuv = data['V'], data['tv'], data['tn'], data['tuv']
    # Compact FIRST: dropping the hidden faces (and the decimator) can leave loose
    # vertices, which export2bin discards and which would skew the measured size.
    used = np.unique(tv)
    remap = np.full(len(V), -1, dtype=np.int64)
    remap[used] = np.arange(len(used))
    V, tv = V[used], remap[tv]
    pos, R, s = place(V, P)
    binary, check, pos = write_binary(key, P, pos, R, tv, tn, tuv)
    files, stats = write_maps(key, P)
    lo, hi = pos.min(axis=0), pos.max(axis=0)
    rec = dict(model=P['model'], material=P['material'], front=P['front'], pivot=P['pivot'],
               scale_from_meshy_m=round(s, 4), tris=int(len(tv)), verts=int(len(V)),
               bounds=[[round(float(x), 2) for x in lo], [round(float(x), 2) for x in hi]],
               size=[round(float(hi[a] - lo[a]), 2) for a in range(3)],
               shader=P['shader'], scale_rgb=P['scale_rgb'], glow=GLOW[key], **stats,
               files={str(p.relative_to(ROOT)).replace('\\', '/'): sha(p) for p in [binary] + list(files.values())})
    if P['front'] == 'nose+X':
        rec['rocket'] = rocket_measure(pos)
    rec['previews'] = [str(p.relative_to(ROOT)).replace('\\', '/') for p in preview(key, P, check, files)]
    log(key, json.dumps({k: rec[k] for k in ('size', 'bounds', 'tris', 'glow_fraction')}))
    return rec


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    phase = argv[argv.index('--phase') + 1] if '--phase' in argv else 'all'
    only = argv[argv.index('--only') + 1].split(',') if '--only' in argv else list(PROPS)
    if phase in ('bake', 'all'):
        for key in only:
            bake_prop(key, PROPS[key])
    if phase in ('build', 'all'):
        manifest_path = ART / 'manifest.json'
        manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
        manifest.update(revision=REVISION, source='art/fan_props/source (Nikolai, Meshy AI, 2026-09-30 pack)',
                        sharp_deg=SHARP_DEG, metal_diffuse_cut=METAL_DIFFUSE_CUT)
        props = manifest.setdefault('props', {})
        for key in only:
            props[key] = build_prop(key, PROPS[key])
        write_gdt(set(props))
        manifest['gdt'] = {str(GDT.relative_to(ROOT)).replace('\\', '/'): sha(GDT)}
        manifest_path.write_text(json.dumps(manifest, indent=1) + '\n')
        log('BUILD_OK', ', '.join(f'{k}: {v["size"]}' for k, v in props.items()))


main()
