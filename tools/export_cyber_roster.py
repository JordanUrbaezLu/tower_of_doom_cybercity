"""Bake a roster study and export head/helmet/chest/arm groups at seven LODs.
Blender -b <study.blend> --python tools/export_cyber_roster.py -- <variant>
Writes repository assets only; the editable study is never saved over.
"""
import bpy
import json
import sys
import hashlib
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from cyber_material_bake import wire_channel
from cyber_equipment_layout import GROUP_BONES
OUT = ROOT/'model_export/tod_cyber_zombie'
IMG = OUT/'_images'
VARIANT=sys.argv[sys.argv.index('--')+1]
STAGE=ROOT/'art/cyber_zombie_roster/engine_kit'/VARIANT
PREFIX='i_tod_roster_'+VARIANT
for p in (OUT, IMG, STAGE): p.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path.home()/'AppData/Roaming/Blender Foundation/Blender/4.2/scripts/addons/BetterBetterBlenderCOD'))
from PyCoD import xmodel

scene=bpy.context.scene
assert scene.get('cyber_finish_revision')==4 and scene.get('cyber_reference_pass')==3,'Export the completed reference-fit master'
scene.cycles.samples=16
scene.render.threads_mode='FIXED';scene.render.threads=4
scene.render.bake.margin=8
rig=bpy.data.objects['Cybercity_zombie_rig']
parts=[o for o in bpy.data.objects if 'attachment_bone' in o]
assert parts
GROUPS=set()
for ob in parts:
    group='helmet' if ob.name.startswith('Helmet |') else {b:g for g,b in GROUP_BONES.items() if g!='helmet'}[ob['attachment_bone']]
    marker=ob.vertex_groups.new(name='_kit_'+group)
    marker.add(list(range(len(ob.data.vertices))),1,'REPLACE')
    GROUPS.add(group)
GROUPS=sorted(GROUPS)
for o in list(bpy.data.objects):
    if o not in parts and o!=rig:
        bpy.data.objects.remove(o,do_unlink=True)
for o in parts:
    o.hide_render=False;o.hide_set(False)
    for mod in list(o.modifiers):o.modifiers.remove(mod)
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.object.join()
kit=bpy.context.object;kit.name='Cyber_kit_baked'
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.012,area_weight=.3,correct_aspect=True)
bpy.ops.object.mode_set(mode='OBJECT')
original_mats=list(kit.data.materials)

def target_image(suffix, srgb=True):
    im=bpy.data.images.new(PREFIX+'_'+suffix,width=2048,height=2048,alpha=False)
    im.colorspace_settings.name='sRGB' if srgb else 'Non-Color'
    for mat in original_mats:
        node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=im
        mat.node_tree.nodes.active=node
    return im

def save_image(im,suffix):
    im.filepath_raw=str(IMG/(PREFIX+'_'+suffix+'.png'))
    im.file_format='PNG';im.save()

# Bake the original procedural bump into a tangent-space normal texture.
im=target_image('n',False)
bpy.ops.object.bake(type='NORMAL',normal_space='TANGENT')
save_image(im,'n')
for suffix in ('c','s','g','e'):
    im=target_image(suffix,suffix in ('c','s','e'))
    for mat in original_mats:
        wire_channel(mat, suffix)
    bpy.ops.object.bake(type='EMIT')
    save_image(im,suffix)

# Native material atlas is shared by all three body regions and every LOD.
mat=bpy.data.materials.new('mtl_tod_roster_'+VARIANT)
kit.data.materials.clear();kit.data.materials.append(mat)
for face in kit.data.polygons:face.material_index=0
bone_names=[b.name for b in rig.data.bones]

def export_group(source, group, lod, ratio):
    obj=source.copy();obj.data=source.data.copy();scene.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    # A vertex belongs to exactly one rigid region. The join preserved weights.
    keep=GROUP_BONES[group]
    import bmesh
    bm=bmesh.new();bm.from_mesh(obj.data);deform=bm.verts.layers.deform.active
    gid=obj.vertex_groups['_kit_'+group].index
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if v[deform].get(gid,0)<.99],context='VERTS')
    bm.to_mesh(obj.data);bm.free();obj.data.update()
    if ratio<1:
        mod=obj.modifiers.new('Distance simplification','DECIMATE');mod.ratio=ratio
        mod.use_collapse_triangulate=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    me=obj.data;me.calc_loop_triangles()
    data={'bone':keep,'verts':[list(obj.matrix_world@v.co) for v in me.vertices], 'faces':[]}
    normal_matrix=obj.matrix_world.to_3x3().inverted().transposed()
    for tri in me.loop_triangles:
        # Fully collapsed bevel faces have no visible area and zero normals.
        # Blender renders past them; the BO3 converter rejects them.
        if tri.area < 1e-9:
            continue
        corners=[]
        for li in (tri.loops[0],tri.loops[2],tri.loops[1]):
            u,v=me.uv_layers.active.data[li].uv
            normal=(normal_matrix@me.corner_normals[li].vector).normalized()
            # Aggressive distance reduction can cancel averaged corner normals
            # where a thin cuff's inner/outer surfaces meet. Retain the valid
            # triangle and use its geometric normal, never export a zero vector.
            if normal.length_squared < .9:
                normal=(normal_matrix@tri.normal).normalized()
                data['geometric_normal_fallbacks']=data.get('geometric_normal_fallbacks',0)+1
            assert normal.length_squared > .9,(group,lod,'invalid geometric normal')
            corners.append({'v':me.loops[li].vertex_index,'n':list(normal),'uv':[u,1-v]})
        data['faces'].append(corners)
    (STAGE/f'{group}_lod{lod}.json').write_text(json.dumps(data,separators=(',',':')))
    bpy.data.objects.remove(obj,do_unlink=True)
    return len(data['faces'])

counts={}
for lod,ratio in enumerate((1,.55,.28,.14,.075,.04,.022)):
    counts[lod]={g:export_group(kit,g,lod,ratio) for g in GROUPS}
(STAGE/'lod_counts.json').write_text(json.dumps(counts,indent=2)+'\n')
(STAGE/'source_manifest.json').write_text(json.dumps({
    'master':str(Path(bpy.data.filepath).relative_to(ROOT)),
    'master_sha256':hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest(),
    'revision':scene.get('cyber_finish_revision'),'fit_pass':scene.get('cyber_reference_pass'),
    'textures':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in IMG.glob(PREFIX+'_*.png')},
    'groups':GROUPS,'atlas_size':2048},indent=2)+'\n')
print('CYBER_ROSTER_KIT_EXPORT_OK',json.dumps(counts),flush=True)
