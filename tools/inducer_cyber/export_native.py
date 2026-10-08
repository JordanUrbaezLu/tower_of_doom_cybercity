"""Bake the cyber Rampage Inducer master and export its native source geometry.

BACKGROUND Blender only (never touches the live studio or saves the master):
  blender.exe -b --factory-startup --python tools/inducer_cyber/export_native.py

Writes:
  model_export/tod_inducer_cyber/_images/i_tod_icyber_{c,n,g,s,e,eon}.png  (2048 atlas)
  art/rampage_inducer_cyber/engine_kit/{solid,plasma}.json  (rest-pose geometry,
      corner normals/UVs, one animation bone per face) + source_manifest.json
install_native.py turns those into the xmodel, the two looping xanims and the GDT.

The rest pose is frame 0: every rig driver (anim_spec) is zero there. Emission is
baked TWICE from the same materials - kit['rampage_on'] = 0 then 1 (the materials'
INSTANCER attribute falls back to the object's own property) - into the OFF and ON
maps, each normalised by its own scale (written to the GDT as scaleRGB).
"""
import bpy, bmesh, sys, json, hashlib, math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools')); sys.path.insert(0, str(ROOT/'tools/inducer_cyber'))
import cyber_material_bake as BAKE
import anim_spec as A
from cyber_reference_one.native_geometry import clean

ART = ROOT/'art/rampage_inducer_cyber'
STAGE = ART/'engine_kit'
OUT = ROOT/'model_export/tod_inducer_cyber'
IMG = OUT/'_images'
MASTER = ART/'rampage_inducer_cyber.blend'
ATLAS = 2048
SCALE = {'e': 4.0, 'eon': 12.0}          # emission normalisation per state == GDT scaleRGB
for p in (STAGE, OUT, IMG):
    p.mkdir(parents=True, exist_ok=True)
master_sha = hashlib.sha256(MASTER.read_bytes()).hexdigest()

bpy.ops.wm.open_mainfile(filepath=str(MASTER))
scene = bpy.context.scene
scene.frame_set(0)
dg = bpy.context.evaluated_depsgraph_get()

# GPU when there is one; the bake is identical either way.
try:
    prefs = bpy.context.preferences.addons['cycles'].preferences
    for kind in ('OPTIX', 'CUDA', 'HIP'):
        try:
            prefs.compute_device_type = kind
            prefs.get_devices()
            if any(d.type == kind for d in prefs.devices):
                for d in prefs.devices:
                    d.use = d.type == kind
                scene.cycles.device = 'GPU'
                print('INDUCER_BAKE_DEVICE', kind, flush=True)
                break
        except TypeError:
            continue
except Exception as exc:  # CPU fallback
    print('INDUCER_BAKE_DEVICE CPU', exc, flush=True)

parts = [o for o in scene.objects if o.get('icyber_part') and o.type in ('MESH', 'CURVE', 'FONT')]
assert parts, 'no exported parts in the master'
bone_index = {b: i for i, b in enumerate(A.BONE_ORDER)}
work = bpy.data.collections.new('export kit'); scene.collection.children.link(work)
made = {'solid': [], 'plasma': []}
for o in parts:
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    me.transform(o.matrix_world)
    bone = o.get('icyber_bone', 'tag_origin')
    attr = me.attributes.new('bone_id', 'INT', 'FACE')
    attr.data.foreach_set('value', [bone_index[bone]] * len(me.polygons))
    ob = bpy.data.objects.new('kit ' + o.name, me)
    work.objects.link(ob)
    made[o.get('icyber_group', 'solid')].append(ob)
# Everything else leaves the scene: studio, rig, preview copies, the originals.
for ob in list(scene.objects):
    if ob.users_collection and ob.users_collection[0] is work:
        continue
    bpy.data.objects.remove(ob, do_unlink=True)


def join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    return ob


solid = join(made['solid'], 'Inducer native solid kit')
plasma = join(made['plasma'], 'Inducer native plasma column') if made['plasma'] else None
solid.data.calc_loop_triangles()
print('INDUCER_KIT tris', len(solid.data.loop_triangles), flush=True)

# Atlas UVs for the solid kit (the plasma keeps its own U-around / V-up UVs).
me = solid.data
while len(me.uv_layers) > 1:
    me.uv_layers.remove(me.uv_layers[-1])
if not me.uv_layers:
    me.uv_layers.new(name='UVMap')
me.uv_layers.active_index = 0
bpy.ops.object.select_all(action='DESELECT'); solid.select_set(True); bpy.context.view_layer.objects.active = solid
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(62), island_margin=0.0035, area_weight=0.0, correct_aspect=True,
                         scale_to_bounds=False)
bpy.ops.object.mode_set(mode='OBJECT')

scene.render.engine = 'CYCLES'; scene.cycles.samples = 12
scene.render.bake.margin = 6; scene.render.bake.use_selected_to_active = False
scene.render.bake.normal_g = 'NEG_Y'          # native BO3 tangent normals use DirectX green
materials = [m for m in me.materials if m]


def target(suffix, alpha=False):
    im = bpy.data.images.new('i_tod_icyber_' + suffix, width=ATLAS, height=ATLAS, alpha=alpha)
    im.colorspace_settings.name = 'Non-Color' if suffix in ('n', 'g') else 'sRGB'
    for m in materials:
        node = m.node_tree.nodes.new('ShaderNodeTexImage'); node.image = im
        m.node_tree.nodes.active = node
    return im


def save(im):
    im.filepath_raw = str(IMG/(im.name + '.png')); im.file_format = 'PNG'; im.save()


im = target('n'); bpy.ops.object.bake(type='NORMAL', normal_space='TANGENT'); save(im)
print('INDUCER_BAKED n', flush=True)
for suffix, channel in (('c', 'c'), ('s', 's'), ('g', 'g'), ('e', 'e'), ('eon', 'e')):
    if channel == 'e':
        BAKE.EMISSION_SCALE = SCALE[suffix]
        solid['rampage_on'] = 1.0 if suffix == 'eon' else 0.0
        solid.data.update()
    im = target(suffix)
    for m in materials:
        BAKE.wire_channel(m, channel)
    bpy.ops.object.bake(type='EMIT'); save(im)
    print('INDUCER_BAKED', suffix, 'scale', SCALE.get(suffix, '-'), flush=True)


def geometry(ob, group, uv_name=None):
    me = ob.data
    me.calc_loop_triangles()
    uvl = me.uv_layers[uv_name] if uv_name else me.uv_layers.active
    bone_of_face = [0] * len(me.polygons)
    me.attributes['bone_id'].data.foreach_get('value', bone_of_face)
    data = {'group': group, 'verts': [list(v.co) for v in me.vertices], 'faces': [], 'face_bone': [], 'vert_bone': {}}
    for tri in me.loop_triangles:
        if tri.area < 1e-9:
            continue
        corners = []
        for li in (tri.loops[0], tri.loops[2], tri.loops[1]):     # BO3 winding
            n = me.corner_normals[li].vector.normalized()
            if n.length_squared < 0.9:
                n = tri.normal.normalized()
            uv = uvl.data[li].uv
            corners.append({'v': me.loops[li].vertex_index, 'n': list(n), 'uv': [uv[0], 1 - uv[1]]})
        data['faces'].append(corners)
        b = bone_of_face[tri.polygon_index]
        data['face_bone'].append(b)
        for c in corners:
            prev = data['vert_bone'].setdefault(c['v'], b)
            assert prev == b, ('a vertex shared by two bones', c['v'], prev, b)
    # carry the bone through the sliver clean-up (it filters faces only)
    keyed = list(zip(data['faces'], data['face_bone']))
    data['faces'] = [f for f, _ in keyed]
    clean(data, min_altitude=.0008)
    kept = {id(f) for f in data['faces']}
    data['face_bone'] = [b for f, b in keyed if id(f) in kept]
    data['vert_bone'] = {str(k): v for k, v in data['vert_bone'].items()}
    (STAGE/(group + '.json')).write_text(json.dumps(data, separators=(',', ':')))
    return len(data['faces']), data['native_slivers_removed']


counts = {'solid': geometry(solid, 'solid')}
if plasma is not None:
    counts['plasma'] = geometry(plasma, 'plasma', 'UVMap')
manifest = {
    'master': str(MASTER.relative_to(ROOT)), 'master_sha256': master_sha,
    'atlas': ATLAS, 'emission_scale': SCALE, 'normal_convention': 'DirectX -Y',
    'bones': A.BONE_ORDER, 'anim': A.summary(), 'counts': counts,
    'textures': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(IMG.glob('i_tod_icyber_*.png'))
                 if not p.name.startswith('i_tod_icyber_plasma')},
}
(STAGE/'source_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('INDUCER_EXPORT_OK', json.dumps(counts), flush=True)
