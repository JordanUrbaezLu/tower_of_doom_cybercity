"""Blender 4.2 (background), phase 1 of tools/fan_props/build_sign_relief.py: Nikolai's FULL-DETAIL Cyber City sign
(732K tris, his lossless 4K/2K sheets) rendered straight on, orthographic, in the sign's BO3 frame (front +X, origin =
the back plane, horizontal centre, bottom; the same fit / pivot build_fan_props.py gave tod_cybercity_sign: 256 wide).

Writes to the stage folder given on the command line (16 px per unit, 4096 x 2048 = 256 x 128 units, image x = +Y =
the viewer's right, image row 0 = z 123.49):
  front_c.png / front_m.png / front_r.png   base colour (sRGB), metallic, roughness (emission-wired, 16 samples, RGBA)
  front_d.exr                               depth = local X (front distance off the back plane) in units, alpha =
                                            coverage; ONE centred ray per pixel (box filter 0.01): exact, never mixed
  frame.json                                the transform (R, scale, translation) and the measured bounds

The helpers marked (= build_fan_props.py) are copies: that tool runs its whole build when imported.
Run: blender -b -noaudio --python tools/fan_props/sign_relief_render.py -- <stage dir>
"""
import hashlib
import json
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'art/fan_props/source'
FBX = ('sign/sign.fbx', 'a37cb3a7e26981c029a8040ad9e6e8f0')                  # = build_fan_props PROPS['sign']
TEX = {'color': ('sign/sign_color.png', '23f9454344b93087b0c38cf54df489ba'),
       'metallic': ('sign/sign_metallic.png', 'aa239dbe4491281b756e29be721888f7'),
       'roughness': ('sign/sign_roughness.png', '3a54e25157ac832222a97c0f6fd321d6')}
WIDTH = 256.0                       # fit (0, 256): the sign's width (Meshy X) -> 256 units
PPU = 16                            # px per unit
FRAME_W, FRAME_H = 256.0, 128.0     # the rendered window: 4096 x 2048
Z_CENTRE = 59.49                    # the sign is 118.98 tall: centred in the 128 window


def md5(p):
    return hashlib.md5(Path(p).read_bytes()).hexdigest()


def log(*a):
    print('[SIGN_RELIEF]', *a, flush=True)


def channel_socket(nt, bsdf, name):                                         # (= build_fan_props.py)
    inp = bsdf.inputs[name]
    return inp.links[0].from_node if inp.is_linked else None


def socket_or_constant(nt, bsdf, name):                                     # (= build_fan_props.py)
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


def main():
    stage = Path(sys.argv[sys.argv.index('--') + 1])
    stage.mkdir(parents=True, exist_ok=True)
    fbx = SRC / FBX[0]
    assert md5(fbx) == FBX[1], 'source FBX changed'
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(fbx))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    assert len(meshes) == 1, meshes
    hp = meshes[0]
    hp.data.transform(hp.matrix_world)
    hp.matrix_world = Matrix.Identity(4)
    # the fan's lossless sheets replace the JPEG copies packed in the FBX (= build_fan_props source_materials)
    mat = hp.material_slots[0].material
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    out = next(n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL')
    for chan, (rel, want) in TEX.items():
        assert md5(SRC / rel) == want, rel
        node = channel_socket(nt, bsdf, {'color': 'Base Color', 'metallic': 'Metallic', 'roughness': 'Roughness'}[chan])
        assert node is not None and node.type == 'TEX_IMAGE', (chan, node)
        im = bpy.data.images.load(str(SRC / rel), check_existing=False)
        im.colorspace_settings.name = 'sRGB' if chan == 'color' else 'Non-Color'
        node.image = im
        node.interpolation = 'Linear'

    # THE TRANSFORM (= build_fan_props.place for front '+X', fit (0, 256), pivot 'back') - from the full-detail mesh
    n = len(hp.data.vertices)
    V = np.empty(n * 3)
    hp.data.vertices.foreach_get('co', V)
    V = V.reshape(n, 3)
    R = np.array([[0, -1, 0], [1, 0, 0], [0, 0, 1]], dtype=np.float64)       # Meshy -Y (front) -> +X
    s = WIDTH / float(V[:, 0].max() - V[:, 0].min())
    p = (V @ R.T) * s
    lo, hi = p.min(0), p.max(0)
    t = np.array([-lo[0], -(lo[1] + hi[1]) / 2, -lo[2]])
    M = Matrix(((R[0, 0] * s, R[0, 1] * s, R[0, 2] * s, t[0]),
                (R[1, 0] * s, R[1, 1] * s, R[1, 2] * s, t[1]),
                (R[2, 0] * s, R[2, 1] * s, R[2, 2] * s, t[2]),
                (0, 0, 0, 1)))
    hp.data.transform(M)
    q = p + t
    log('scale', round(s, 4), 'bounds', q.min(0).round(3).tolist(), q.max(0).round(3).tolist(), 'tris', len(hp.data.polygons))

    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.render.resolution_x = int(FRAME_W * PPU)
    scene.render.resolution_y = int(FRAME_H * PPU)
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'None'
    scene.world = bpy.data.worlds.new('none')
    scene.world.color = (0, 0, 0)
    cam_data = bpy.data.cameras.new('front')
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = FRAME_W
    cam_data.clip_start, cam_data.clip_end = 1.0, 400.0
    cam = bpy.data.objects.new('front', cam_data)
    scene.collection.objects.link(cam)
    # at +X looking -X, up +Z: Blender cameras look down their local -Z, so rotate Z->-X ... x=90deg, z=90deg
    cam.location = (200.0, 0.0, Z_CENTRE)
    cam.rotation_euler = (np.pi / 2, 0.0, np.pi / 2)
    scene.camera = cam

    restore = out.inputs['Surface'].links[0].from_socket
    emit = nt.nodes.new('ShaderNodeEmission')
    emit.inputs['Strength'].default_value = 1.0
    nt.links.new(emit.outputs['Emission'], out.inputs['Surface'])

    def render(name, fmt, depth16=True, samples=16, box=False):
        scene.cycles.samples = samples
        scene.cycles.use_denoising = False
        scene.cycles.pixel_filter_type = 'BOX' if box else 'BLACKMAN_HARRIS'
        scene.cycles.filter_width = 0.01 if box else 1.5
        scene.render.image_settings.file_format = fmt
        scene.render.image_settings.color_mode = 'RGBA'
        if fmt == 'PNG':
            scene.render.image_settings.color_depth = '16' if depth16 else '8'
        else:
            scene.render.image_settings.color_depth = '32'
            scene.render.image_settings.exr_codec = 'ZIP'
        scene.render.filepath = str(stage / name)
        bpy.ops.render.render(write_still=True)
        log('rendered', name)

    for chan, name in (('Base Color', 'front_c.png'), ('Metallic', 'front_m.png'), ('Roughness', 'front_r.png')):
        nt.links.new(socket_or_constant(nt, bsdf, chan), emit.inputs['Color'])
        scene.display_settings.display_device = 'sRGB'
        # colour: the sRGB sheet -> linear in the shader -> Standard encodes it back: the PNG holds his sRGB texels.
        # metallic / roughness are DATA: Raw writes the shader's linear value untouched.
        scene.view_settings.view_transform = 'Standard' if chan == 'Base Color' else 'Raw'
        render(name, 'PNG')
    # depth: the emission colour IS the local X (units); an EXR keeps it exact (Raw view)
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    nt.links.new(geo.outputs['Position'], sep.inputs['Vector'])
    comb = nt.nodes.new('ShaderNodeCombineColor')
    for k in ('Red', 'Green', 'Blue'):
        nt.links.new(sep.outputs['X'], comb.inputs[k])
    nt.links.new(comb.outputs['Color'], emit.inputs['Color'])
    scene.view_settings.view_transform = 'Raw' if 'Raw' in [v.identifier for v in scene.view_settings.bl_rna.properties['view_transform'].enum_items] else 'Standard'
    render('front_d.exr', 'OPEN_EXR', samples=1, box=True)
    # the system-python side has no EXR reader: hand it the float depth + coverage as .npy (rows top-down)
    im = bpy.data.images.load(str(stage / 'front_d.exr'), check_existing=False)
    w, h = im.size
    px = np.empty(w * h * 4, dtype=np.float32)
    im.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)[::-1]
    np.save(stage / 'front_d.npy', np.stack([px[..., 0], px[..., 3]], axis=-1))
    log('depth range', float(px[..., 0][px[..., 3] > 0.5].min()), float(px[..., 0][px[..., 3] > 0.5].max()))
    nt.links.new(restore, out.inputs['Surface'])
    (stage / 'frame.json').write_text(json.dumps(dict(
        fbx_md5=FBX[1], scale=s, R=R.tolist(), t=t.tolist(), bounds=[q.min(0).tolist(), q.max(0).tolist()],
        ppu=PPU, frame=[FRAME_W, FRAME_H], z_centre=Z_CENTRE, view=scene.view_settings.view_transform), indent=1))
    log('done')


main()
