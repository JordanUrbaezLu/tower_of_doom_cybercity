"""Blender 4.2 (background): the OLD shipped sign (12K decimate, his UVs + crinkle normal map) beside the NEW relief
(tod_cybercity_sign2), both from their stage meshes with their SHIPPED textures, lit alike, from three views.
Run: blender -b -noaudio --python tools/fan_props/sign_relief_preview.py -- <out.jpg>
     blender -b -noaudio --python tools/fan_props/sign_relief_preview.py -- <out.jpg> states
        (the NEW sign only, in its three power looks: OFF | DIM | ON, from the spawn and head on)
"""
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
IMG = ROOT / 'model_export/tod_fan_props/_images'
argv = sys.argv[sys.argv.index('--') + 1:]
out = Path(argv[0])
STATES = len(argv) > 1 and argv[1] == 'states'
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def mesh_from(name, V, tv, tn, tuv):
    me = bpy.data.meshes.new(name)
    me.from_pydata(V.tolist(), [], tv.tolist())
    me.validate()
    uvl = me.uv_layers.new(name='uv')
    loops = np.array([l for p in me.polygons for l in p.loop_indices])
    uv = tuv.reshape(-1, 2)
    for i, l in enumerate(loops):
        uvl.data[l].uv = uv[i]
    me.normals_split_custom_set([tuple(n) for n in tn.reshape(-1, 3)])
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    return ob


def material(name, c, e, s, g, n=None, emit=6.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes['Principled BSDF']

    def tex(path, color=True):
        node = nt.nodes.new('ShaderNodeTexImage')
        node.image = bpy.data.images.load(str(path))
        node.image.colorspace_settings.name = 'sRGB' if color else 'Non-Color'
        return node
    nt.links.new(tex(c).outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(tex(e).outputs['Color'], bsdf.inputs['Emission Color'])
    bsdf.inputs['Emission Strength'].default_value = emit * 0.35
    gl = tex(g, False)
    inv = nt.nodes.new('ShaderNodeMath')
    inv.operation = 'SUBTRACT'
    inv.inputs[0].default_value = 1.0
    nt.links.new(gl.outputs['Color'], inv.inputs[1])
    nt.links.new(inv.outputs[0], bsdf.inputs['Roughness'])
    bsdf.inputs['Metallic'].default_value = 0.0
    if n is not None:
        nm = tex(n, False)
        sep = nt.nodes.new('ShaderNodeSeparateColor')
        comb = nt.nodes.new('ShaderNodeCombineColor')
        flip = nt.nodes.new('ShaderNodeMath')
        flip.operation = 'SUBTRACT'
        flip.inputs[0].default_value = 1.0
        nt.links.new(nm.outputs['Color'], sep.inputs['Color'])
        nt.links.new(sep.outputs['Red'], comb.inputs['Red'])
        nt.links.new(sep.outputs['Green'], flip.inputs[1])                 # his maps are DirectX green
        nt.links.new(flip.outputs[0], comb.inputs['Green'])
        nt.links.new(sep.outputs['Blue'], comb.inputs['Blue'])
        nmap = nt.nodes.new('ShaderNodeNormalMap')
        nmap.uv_map = 'uv'
        nt.links.new(comb.outputs['Color'], nmap.inputs['Color'])
        nt.links.new(nmap.outputs['Normal'], bsdf.inputs['Normal'])
    return mat


# NEW: the relief's stage mesh is already in the sign's BO3 frame
d = np.load(ROOT / 'tmp/fan_props_stage/sign_relief/low.npz')
new = mesh_from('new', d['V'], d['tv'], np.load(ROOT / 'tmp/fan_props_stage/sign_relief/tn_walls.npy'),
               np.load(ROOT / 'tmp/fan_props_stage/sign_relief/tuv_walls.npy'))   # the SHIPPED normals + UVs
new.data.materials.append(material('new', IMG / 'i_tod_csign2_c.png', IMG / 'i_tod_csign2_e.png', IMG / 'i_tod_csign2_s.png', IMG / 'i_tod_csign2_g.png'))
# OLD: build_fan_props' stage mesh in the Meshy frame -> place() (front +X, fit (0, 256), pivot back)
o = np.load(ROOT / 'tmp/fan_props_stage/sign/low.npz')
V = o['V']
R = np.array([[0, -1, 0], [1, 0, 0], [0, 0, 1]], dtype=np.float64)
s = 256.0 / float(V[:, 0].max() - V[:, 0].min())
p = (V @ R.T) * s
lo, hi = p.min(0), p.max(0)
p = p + np.array([-lo[0], -(lo[1] + hi[1]) / 2, -lo[2]])
old = mesh_from('old', p, o['tv'], o['tn'] @ R.T, o['tuv'])
old.data.materials.append(material('old', IMG / 'i_tod_csign_c.png', IMG / 'i_tod_csign_e.png', IMG / 'i_tod_csign_s.png',
                                   IMG / 'i_tod_csign_g.png', IMG / 'i_tod_csign_n.png'))

# the spawn's light: a warm key from the spawn band + a cool fill + a dim world
scene.world = bpy.data.worlds.new('w')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.02, 0.025, 0.05, 1)
for name, loc, energy, col in (('key', (420, -160, 120), 9e6, (1.0, 0.82, 0.62)), ('fill', (300, 260, 320), 3e6, (0.55, 0.65, 1.0))):
    ld = bpy.data.lights.new(name, 'POINT')
    ld.energy = energy
    ld.color = col
    ld.shadow_soft_size = 30
    lo_ = bpy.data.objects.new(name, ld)
    lo_.location = loc
    scene.collection.objects.link(lo_)
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1000, 700
scene.view_settings.view_transform = 'AgX'
cam_d = bpy.data.cameras.new('cam')
cam_d.lens = 50
cam = bpy.data.objects.new('cam', cam_d)
scene.collection.objects.link(cam)
scene.camera = cam
shots = []
# PLAYER EYES: the sign hangs 100 up the core's west face; the spawn band stands ~240 out at eye height 64, so in the
# sign's own frame the eye is ~36 BELOW its bottom edge. Each model rendered alone from the same three cameras.
views = (('head_on', (300, 0, -36), (0, 0, 60)),
         ('spawn_left', (230, -190, -36), (0, -10, 60)),
         ('close_up', (120, -120, 10), (0, -50, 70)))
if STATES:
    # the NEW sign alone in its three power looks (= the GDT: OFF = the dimmed sheet + a black glow, DIM = the ON
    # sheets at scaleRGB 2, ON = scaleRGB 6), two rows: the spawn view, then head on
    old.hide_render = True
    looks = (('off', material('off', IMG / 'i_tod_csign2_coff.png', IMG / 'i_tod_csign2_eoff.png', IMG / 'i_tod_csign2_s.png',
                              IMG / 'i_tod_csign2_g.png')),
             ('dim', material('dim', IMG / 'i_tod_csign2_c.png', IMG / 'i_tod_csign2_e.png', IMG / 'i_tod_csign2_s.png',
                              IMG / 'i_tod_csign2_g.png', emit=2.0)),
             ('on', new.data.materials[0]))
    for tag, eye, look in (views[1], views[0]):
        for name, mat in looks:
            new.data.materials[0] = mat
            cam.location = Vector(eye)
            cam.rotation_euler = (Vector(look) - Vector(eye)).to_track_quat('-Z', 'Y').to_euler()
            f = out.parent / f'_state_{name}_{tag}.png'
            scene.render.filepath = str(f)
            bpy.ops.render.render(write_still=True)
            shots.append(f)
            print('[SIGN_RELIEF] preview state', name, tag, flush=True)
for ob_on, ob_off in (((old, new), (new, old)) if not STATES else ()):
    ob_on.hide_render, ob_off.hide_render = False, True
    for tag, eye, look in views:
        cam.location = Vector(eye)
        cam.rotation_euler = (Vector(look) - Vector(eye)).to_track_quat('-Z', 'Y').to_euler()
        f = out.parent / f'_{ob_on.name}_{tag}.png'
        scene.render.filepath = str(f)
        bpy.ops.render.render(write_still=True)
        shots.append(f)
        print('[SIGN_RELIEF] preview', ob_on.name, tag, flush=True)
# stitch side by side (Blender has no PIL): load + paste via numpy
arrs = []
for f in shots:
    im = bpy.data.images.load(str(f))
    w, h = im.size
    px = np.empty(w * h * 4, np.float32)
    im.pixels.foreach_get(px)
    arrs.append(px.reshape(h, w, 4))
rows_ = [np.concatenate(arrs[i * 3:(i + 1) * 3], axis=1) for i in range(2)]
sheet = np.concatenate(rows_[::-1], axis=0)   # Blender rows run bottom-up: the OLD row ends on top
im = bpy.data.images.new('sheet', sheet.shape[1], sheet.shape[0])
im.pixels.foreach_set(sheet.ravel())
im.filepath_raw = str(out)
im.file_format = 'JPEG'
im.save()
for f in shots:
    f.unlink()
print('[SIGN_RELIEF] wrote', out, flush=True)
