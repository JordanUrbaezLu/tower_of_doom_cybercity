"""Blender: bake the approved MVP additions and export seven geometric LODs.

blender -b art/cyber_zombie_mvp/cyber_zombie_mvp.blend --python tools/export_cyber_zombie_kit.py
Writes only repo model_export/tod_cyber_zombie and art/cyber_zombie_mvp.
"""
import bpy
import json
import sys
import hashlib
import runpy,shutil
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from cyber_material_bake import wire_channel, EMISSION_SCALE
from cyber_equipment_layout import GROUP_BONES
OUT = ROOT/'model_export/tod_cyber_zombie'
IMG = OUT/'_images'
STAGE = ROOT/'art/cyber_zombie_mvp/engine_kit'
REFERENCE_NUMBER=bpy.context.scene.get('cyber_reference_number',1)
PREFIX='i_tod_cyber_kit'
MATERIAL='mtl_tod_cyber_kit'
if REFERENCE_NUMBER in (2,3):
    # Isolated derivatives are reviewed before the roster installer consumes them.
    OUT=Path(bpy.context.scene['cyber_study_output'])/'engine_kit'
    STAGE=OUT;IMG=OUT/'_images'
    VARIANT={2:'trooper',3:'sprinter'}[REFERENCE_NUMBER]
    PREFIX='i_tod_roster_'+VARIANT;MATERIAL='mtl_tod_roster_'+VARIANT
for p in (OUT, IMG, STAGE): p.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(Path.home()/'AppData/Roaming/Blender Foundation/Blender/4.2/scripts/addons/BetterBetterBlenderCOD'))
from PyCoD import xmodel

scene=bpy.context.scene
SOURCE_MASTER=Path(bpy.data.filepath)
SOURCE_HASH=hashlib.sha256(SOURCE_MASTER.read_bytes()).hexdigest()
SOURCE_REVISION=scene.get('cyber_finish_revision')
SOURCE_FIT=scene.get('cyber_reference_pass')
SOURCE_STAGE=scene.get('cyber_authoring_stage') if REFERENCE_NUMBER in (2,3) else scene.get('reference_one_stage')
SOURCE_EMISSION_SCALE=float(scene.get('armored_emission_scale',EMISSION_SCALE)) if REFERENCE_NUMBER==3 else EMISSION_SCALE
SOURCE_HELMET=json.loads(scene['armored_helmet_spec']) if REFERENCE_NUMBER==3 and scene.get('armored_helmet') else None
SOURCE_BACKPACK_REMOVAL=json.loads(scene['armored_backpack_removal']) if REFERENCE_NUMBER==3 and scene.get('armored_backpack_removed') else None
SOURCE_ARMOR_FINISH=json.loads(scene['armored_finish_spec']) if REFERENCE_NUMBER==3 and scene.get('armored_finish') else None
LOD_AREA_FLOORS={'chest':(0,.025,.18,1.0,2.5,5.0,12.0)} if REFERENCE_NUMBER==2 and scene.get('reference_two_back_design') else {}
if REFERENCE_NUMBER==3 and scene.get('armored_sword_arms'):
    # Both long blade silhouettes survive; retire tiny backpack fittings at
    # the farthest distance to keep the established 2,000-triangle budget.
    LOD_AREA_FLOORS={'chest':(0,.025,.18,.60,1.5,3.5,12.0)}
    if SOURCE_HELMET:
        # Keep the thin eye cartridge readable at every authored head LOD.
        LOD_AREA_FLOORS['head']=(0,.01,.06,.12,.25,.50,.80)
scene.cycles.samples=16
scene.render.threads_mode='FIXED';scene.render.threads=8
scene.render.bake.margin=8
rig=bpy.data.objects['Cybercity_zombie_rig']
parts=[o for o in bpy.data.objects if 'attachment_bone' in o]
REFERENCE_ONE=bool(scene.get('reference_one_mcp')) or REFERENCE_NUMBER in (2,3)
ATLAS_SIZE=4096 if REFERENCE_ONE else 2048
scene.render.bake.margin=3 if REFERENCE_ONE else 8
assert len(parts)>35
if REFERENCE_ONE:
    if REFERENCE_NUMBER in (2,3):
        assert scene.get('cyber_finish_revision')==6
        assert SOURCE_STAGE=={2:'03_completed_reference_two',3:'03_completed_reference_three_armored_only'}[REFERENCE_NUMBER]
    else:assert scene.get('reference_one_stage')=='10_reference_refinement'
else:
    assert scene.get('cyber_finish_revision')==4 and scene.get('cyber_reference_pass')==3
GROUPS=sorted({{b:g for g,b in GROUP_BONES.items() if g!='helmet'}[o['attachment_bone']] for o in parts})
for o in list(bpy.data.objects):
    if o not in parts and o!=rig:
        bpy.data.objects.remove(o,do_unlink=True)
for o in parts:
    o.hide_render=False;o.hide_set(False)
    if REFERENCE_ONE:
        for mod in list(o.modifiers):
            if mod.type=='ARMATURE':o.modifiers.remove(mod)
if REFERENCE_ONE:
    # Evaluate once, then replace meshes in a separate pass. Mutating an object
    # between evaluations needlessly rebuilds the entire scene dependency graph.
    deps=bpy.context.evaluated_depsgraph_get()
    evaluated_meshes=[(o,bpy.data.meshes.new_from_object(o.evaluated_get(deps),
        preserve_all_data_layers=True,depsgraph=deps)) for o in parts]
    for o,geometry in evaluated_meshes:
        o.data=geometry
        # Tiny bevel corners can be generated without interpolated weights.
        # Equipment is rigid per original joint: bind every evaluated vertex.
        o.vertex_groups.clear();vg=o.vertex_groups.new(name=o['attachment_bone'])
        vg.add(list(range(len(geometry.vertices))),1,'REPLACE')
    print('REFERENCE_ONE_BEVELS_EVALUATED',len(parts),flush=True)
for o in parts:
    for mod in list(o.modifiers):o.modifiers.remove(mod)
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.object.join()
kit=bpy.context.object;kit.name='Cyber_kit_baked'
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
if REFERENCE_ONE:
    before=sum(len(p.vertices)-2 for p in kit.data.polygons)
    mod=kit.modifiers.new('Game silhouette reduction','DECIMATE')
    mod.ratio=min(1,48000/before);mod.use_collapse_triangulate=True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    print('REFERENCE_ONE_GAME_REDUCTION',before,sum(len(p.vertices)-2 for p in kit.data.polygons),flush=True)
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.00015 if REFERENCE_ONE else .012,area_weight=.3,correct_aspect=True)
bpy.ops.object.mode_set(mode='OBJECT')
original_mats=list(kit.data.materials)

def target_image(suffix, srgb=True):
    im=bpy.data.images.new(PREFIX+'_'+suffix,width=ATLAS_SIZE,height=ATLAS_SIZE,alpha=False)
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
        wire_channel(mat, suffix, emission_scale=SOURCE_EMISSION_SCALE)
    bpy.ops.object.bake(type='EMIT')
    save_image(im,suffix)

# Native material atlas is shared by all three body regions and every LOD.
mat=bpy.data.materials.new(MATERIAL)
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
    gid=obj.vertex_groups[keep].index
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
for lod,ratio in enumerate((1,) if REFERENCE_ONE else (1,.55,.28,.14,.075,.04,.022)):
    counts[lod]={g:export_group(kit,g,lod,ratio) for g in GROUPS}
(STAGE/'lod_counts.json').write_text(json.dumps(counts,indent=2)+'\n')
if REFERENCE_ONE:
    from cyber_reference_one.native_geometry import clean
    for group in GROUPS:
        path=STAGE/(group+'_lod0.json');data=clean(json.loads(path.read_text()))
        path.write_text(json.dumps(data,separators=(',',':')));counts[0][group]=len(data['faces'])
    (STAGE/'lod_counts.json').write_text(json.dumps(counts,indent=2)+'\n')
    reduced=ROOT/('tmp/reference_'+str(REFERENCE_NUMBER)+'_reduced_lods')
    runpy.run_path(str(ROOT/'tools/cyber_reference_one/reduce_game_lods.py'),run_name='__main__',init_globals={'CYBER_LOD_SOURCE':STAGE,'CYBER_LOD_OUTPUT':reduced,'CYBER_LOD_AREA_FLOORS':LOD_AREA_FLOORS,
        'CYBER_LOD_PRESERVE_LARGEST':['head'] if SOURCE_HELMET else []})
    for path in reduced.glob('*.json'):shutil.copy2(path,STAGE/path.name)
    counts=json.loads((STAGE/'lod_counts.json').read_text())
    if REFERENCE_NUMBER==2:
        # The fitted R2 shin shell produces near-collinear collapse slivers.
        # BO3 discarded one in the first compile. Clean sub-.002-unit
        # altitudes explicitly rather than loosening the native leg coverage gate.
        for lod in range(7):
            for group in GROUPS:
                path=STAGE/(group+'_lod'+str(lod)+'.json')
                data=clean(json.loads(path.read_text()),min_altitude=.002)
                path.write_text(json.dumps(data,separators=(',',':')))
                counts[str(lod)][group]=len(data['faces'])
        (STAGE/'lod_counts.json').write_text(json.dumps(counts,indent=2)+'\n')
(STAGE/'source_manifest.json').write_text(json.dumps({
    'master':str(SOURCE_MASTER.relative_to(ROOT)),
    'master_sha256':SOURCE_HASH,
    'revision':6 if REFERENCE_NUMBER in (2,3) else (5 if REFERENCE_ONE else SOURCE_REVISION),'fit_pass':REFERENCE_NUMBER if REFERENCE_NUMBER in (2,3) else (2 if REFERENCE_ONE else SOURCE_FIT),
    'authoring_stage':SOURCE_STAGE if REFERENCE_ONE else None,
    'emission_scale':SOURCE_EMISSION_SCALE,'armored_helmet':SOURCE_HELMET,'backpack_removal':SOURCE_BACKPACK_REMOVAL,
    'armor_finish':SOURCE_ARMOR_FINISH,
    'lod_preserve_largest':['head'] if SOURCE_HELMET else [],
    'lod_method':'component_floor_v1' if REFERENCE_ONE else 'legacy','lod_area_floors':LOD_AREA_FLOORS,
    'textures':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in IMG.glob(PREFIX+'_*.png')},
    'groups':GROUPS,'atlas_size':ATLAS_SIZE},indent=2)+'\n')
print('CYBER_KIT_EXPORT_OK',json.dumps(counts),flush=True)
