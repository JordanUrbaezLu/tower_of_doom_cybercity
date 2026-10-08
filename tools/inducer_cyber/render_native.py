"""Render the SHIPPED binaries, not the art master: the xmodel_bin, both XANIM_BINs
and the baked/generated maps, posed by CPU skinning straight from the clip data.

  blender.exe -b art/rampage_inducer_cyber/rampage_inducer_cyber.blend --python \
      tools/inducer_cyber/render_native.py -- [view] [idle_frame] [on_frame]

What it proves offline: bones + weights + bind pose + clip frames agree (a wrong
matrix convention sends parts flying), every face survives BO3-style back-face
culling (back faces render transparent here), and the OFF/ON maps light the right
parts. It is NOT a game screenshot: BO3 shading, exposure and the scroll differ.
"""
import bpy, sys, json, hashlib, math
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path.home()/'AppData/Roaming/Blender Foundation/Blender/4.2/scripts/addons/BetterBetterBlenderCOD'))
sys.path.insert(0, str(Path(__file__).parent))
from PyCoD import xmodel as xm, xanim as xa
import anim_spec as A

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
view = args[0] if args else 'both'
idle_frame = int(args[1]) if len(args) > 1 else 100
on_frame = int(args[2]) if len(args) > 2 else 30
MODELS = ROOT/'model_export/tod_inducer_cyber'; IMG = MODELS/'_images'; ANIMS = ROOT/'xanim_export/tod_inducer_cyber'
OUT = ROOT/'art/rampage_inducer_cyber/game_preview'; OUT.mkdir(parents=True, exist_ok=True)
install = json.loads((ROOT/'art/rampage_inducer_cyber/install_manifest.json').read_text())
scene = bpy.context.scene
for ob in list(scene.objects):
    if ob.get('icyber_part') or ob.get('icyber_on_moving') or ob.name.startswith('RI rig | ') \
            or ob.name.startswith('RI studio | ON preview'):
        bpy.data.objects.remove(ob, do_unlink=True)
hashes = {}


def tex(n, name, linear=False):
    path = IMG/(name + '.png'); hashes[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
    node = n.new('ShaderNodeTexImage'); node.image = bpy.data.images.load(str(path), check_existing=True)
    if linear:
        node.image.colorspace_settings.name = 'Non-Color'
    return node


def culled(mat, surface):
    n, l = mat.node_tree.nodes, mat.node_tree.links
    geo = n.new('ShaderNodeNewGeometry'); tr = n.new('ShaderNodeBsdfTransparent'); mix = n.new('ShaderNodeMixShader')
    l.new(geo.outputs['Backfacing'], mix.inputs[0]); l.new(surface, mix.inputs[1]); l.new(tr.outputs[0], mix.inputs[2])
    l.new(mix.outputs[0], n.get('Material Output').inputs[0])


def solid_material(state):
    m = bpy.data.materials.new('native solid ' + state); m.use_nodes = True
    n, l = m.node_tree.nodes, m.node_tree.links; b = n.get('Principled BSDF')
    l.new(tex(n, 'i_tod_icyber_c').outputs['Color'], b.inputs['Base Color'])
    e = tex(n, 'i_tod_icyber_e' if state == 'idle' else 'i_tod_icyber_eon')
    l.new(e.outputs['Color'], b.inputs['Emission Color'])
    b.inputs['Emission Strength'].default_value = install['scale_rgb']['solid'][state]
    g = tex(n, 'i_tod_icyber_g', True); inv = n.new('ShaderNodeMath'); inv.operation = 'SUBTRACT'
    inv.inputs[0].default_value = 1; l.new(g.outputs['Color'], inv.inputs[1]); l.new(inv.outputs[0], b.inputs['Roughness'])
    s = tex(n, 'i_tod_icyber_s'); bw = n.new('ShaderNodeRGBToBW'); l.new(s.outputs['Color'], bw.inputs[0])
    met = n.new('ShaderNodeMapRange'); met.inputs['From Min'].default_value = 0.08; met.inputs['From Max'].default_value = 0.5
    l.new(bw.outputs[0], met.inputs['Value']); l.new(met.outputs[0], b.inputs['Metallic'])
    nm_img = tex(n, 'i_tod_icyber_n', True); sep = n.new('ShaderNodeSeparateXYZ'); comb = n.new('ShaderNodeCombineXYZ')
    flip = n.new('ShaderNodeMath'); flip.operation = 'SUBTRACT'; flip.inputs[0].default_value = 1   # DirectX -> OpenGL green
    l.new(nm_img.outputs['Color'], sep.inputs[0]); l.new(sep.outputs[0], comb.inputs[0]); l.new(sep.outputs[2], comb.inputs[2])
    l.new(sep.outputs[1], flip.inputs[1]); l.new(flip.outputs[0], comb.inputs[1])
    nm = n.new('ShaderNodeNormalMap'); l.new(comb.outputs[0], nm.inputs['Color']); l.new(nm.outputs[0], b.inputs['Normal'])
    culled(m, b.outputs[0])
    return m


def plasma_material(state):
    m = bpy.data.materials.new('native plasma ' + state); m.use_nodes = True
    m.blend_method = 'BLEND'
    try:
        m.surface_render_method = 'BLENDED'
    except Exception:
        pass
    n, l = m.node_tree.nodes, m.node_tree.links
    for node in list(n):
        if node.type != 'OUTPUT_MATERIAL':
            n.remove(node)
    c = tex(n, 'i_tod_icyber_plasma_c'); e = tex(n, 'i_tod_icyber_plasma_e')
    em = n.new('ShaderNodeEmission'); l.new(e.outputs['Color'], em.inputs['Color'])
    em.inputs['Strength'].default_value = install['scale_rgb']['plasma'][state]
    tr = n.new('ShaderNodeBsdfTransparent'); mix = n.new('ShaderNodeMixShader')
    l.new(c.outputs['Alpha'], mix.inputs[0]); l.new(tr.outputs[0], mix.inputs[1]); l.new(em.outputs[0], mix.inputs[2])
    out = n.get('Material Output'); l.new(mix.outputs[0], out.inputs['Surface'])
    culled(m, mix.outputs[0])
    return m


path = MODELS/'tod_inducer_cyber.xmodel_bin'; hashes[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
model = xm.Model(); model.LoadFile_Bin(str(path), split_meshes=True)
bone_names = [b.name for b in model.bones]
assert bone_names == A.BONE_ORDER, bone_names


def bone_matrix(offset, rows):
    m = Matrix(((rows[0][0], rows[1][0], rows[2][0], offset[0]),
                (rows[0][1], rows[1][1], rows[2][1], offset[1]),
                (rows[0][2], rows[1][2], rows[2][2], offset[2]),
                (0, 0, 0, 1)))
    return m


rest = [bone_matrix(b.offset, b.matrix) for b in model.bones]


def clip_pose(clip, frame):
    p = ANIMS/(A.XANIM[clip] + '.XANIM_BIN'); hashes[p.name] = hashlib.sha256(p.read_bytes()).hexdigest()
    anim = xa.Anim(); anim.LoadFile_Bin(str(p))
    names = [q.name for q in anim.parts]
    fr = anim.frames[frame % len(anim.frames)]
    return [bone_matrix(fr.parts[names.index(nm)].offset, fr.parts[names.index(nm)].matrix) for nm in bone_names]


def build(state, clip, frame, offset):
    pose = clip_pose(clip, frame)
    skin = [pose[i] @ rest[i].inverted() for i in range(len(rest))]
    mats = [solid_material(state), plasma_material(state)]
    for index, src in enumerate(model.meshes):
        verts = []
        for v in src.verts:
            bi = v.weights[0][0]
            verts.append(tuple(skin[bi] @ Vector(v.offset) + Vector(offset)))
        me = bpy.data.meshes.new('native %s %s' % (state, src.name))
        me.from_pydata(verts, [], [[f.indices[i].vertex for i in (0, 2, 1)] for f in src.faces]); me.update()
        for m in mats:
            me.materials.append(m)
        uv = me.uv_layers.new(name='UV'); normals = []
        for poly, face in zip(me.polygons, src.faces):
            poly.material_index = face.material_id; poly.use_smooth = True
            bi = src.verts[face.indices[0].vertex].weights[0][0]
            rot = skin[bi].to_3x3()
            for li, fi in zip(poly.loop_indices, (0, 2, 1)):
                c = face.indices[fi]; uv.data[li].uv = (c.uv[0], 1 - c.uv[1])
                normals.append(tuple((rot @ Vector(c.normal)).normalized()))
        me.normals_split_custom_set(normals)
        ob = bpy.data.objects.new(me.name, me); scene.collection.objects.link(ob)


build('idle', 'idle', idle_frame, (0, 0, 0))
build('on', 'on', on_frame, (0, -85, 0))
VIEWS = {'both': ((128, -42, 64), (0, -42, 33), 32), 'off': ((74, 30, 56), (0, 0, 33), 40),
         'on': ((74, -55, 56), (0, -85, 33), 40), 'eye': ((96, 0, 60), (0, 0, 33), 30)}
loc, target, lens = VIEWS[view]
cam = bpy.data.objects.new('native cam', bpy.data.cameras.new('native cam')); scene.collection.objects.link(cam)
cam.data.lens = lens; cam.data.clip_start = 0.5; cam.location = loc
cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler(); scene.camera = cam
scene.render.engine = 'BLENDER_EEVEE_NEXT'; scene.eevee.taa_render_samples = 32
scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
tag = '%s_i%d_o%d' % (view, idle_frame, on_frame)
scene.render.filepath = str(OUT/('native_' + tag + '.png'))
bpy.ops.render.render(write_still=True)
(OUT/('native_' + tag + '.json')).write_text(json.dumps({
    'type': 'Blender render of the shipped xmodel_bin posed by the shipped XANIM_BINs (CPU skinning) with the '
            'shipped maps; back faces transparent. Not an in-game screenshot.',
    'idle_frame': idle_frame, 'on_frame': on_frame, 'hashes': hashes}, indent=2))
print('NATIVE_RENDER_OK', scene.render.filepath, flush=True)
