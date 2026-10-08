"""Measure skull enclosure, actual emitters and complete pressure-pack retirement."""
import bpy, json, sys, hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[2]
scene=bpy.context.scene
assert scene.get('armored_helmet')=='executioner_enclosed_v1'
assert scene.get('armored_backpack_removed') is True
assert not any(o.get('attachment_bone') and o.name.startswith(('Back |','Back standoff |','Mouth guard |','Head |')) for o in scene.objects)
assert scene.get('armored_forehead_shield_removed') is True
spec=json.loads(scene['armored_helmet_spec'])
assert spec['closed_crown'] and spec['full_skull_shell'] and not spec['separate_forehead_shield']
assert spec['emission_bake_range']==scene['armored_emission_scale']==16
assert scene.get('armored_finish')=='shared_worn_gunmetal_v1'
finish=json.loads(scene['armored_finish_spec'])
for name,required in (
    ('R1 | armored shared worn gunmetal',{'j_head','j_elbow_le','j_elbow_ri','j_spine4'}),
    ('R1 | armored shared abraded steel edges',{'j_head','j_elbow_le','j_elbow_ri'}),
):
    actual={o['attachment_bone'] for o in scene.objects if o.get('attachment_bone')
            and any(m and m.name==name for m in o.data.materials)}
    assert required<=actual and sorted(actual)==finish['material_bone_usage'][name]
eyes=[o for o in scene.objects if o.name.startswith('Eye strip |')]
assert len(eyes)==2 and all(o.get('attachment_bone')=='j_head' for o in eyes)
emitters={}
for prefix,strength in (('continuous executioner red',14),('continuous hot red core',16)):
    objects=[o for o in eyes if prefix in o.name]
    assert len(objects)==1
    for ob in objects:
        bs=ob.data.materials[0].node_tree.nodes['Principled BSDF']
        assert not bs.inputs['Emission Color'].is_linked
        assert bs.inputs['Emission Strength'].default_value==strength
        assert bs.inputs['Emission Color'].default_value[0]>=.94
    emitters[prefix]={'objects':len(objects),'emission_strength':strength}

# Every supported intact head is retained. Cast out from its actual skull
# vertices to require a helmet surface outside it, not just a larger bbox.
sys.path.insert(0,str(Path.home()/'AppData/Roaming/Blender Foundation/Blender/4.2/scripts/addons/BetterBetterBlenderCOD'))
from PyCoD import xmodel
manifest=json.loads((ROOT/'art/cyber_zombie_roster/engine_kit/install_manifest.json').read_text())
sources=[r for r in manifest['models'] if r['asset'] in ('tod_cyber_sprinter_head1','tod_cyber_sprinter_head2','tod_cyber_sprinter_head3')]
assert len(sources)==21
parts=[o for o in scene.objects if o.get('attachment_bone')=='j_head']
verts=[];faces=[]
for ob in parts:
    offset=len(verts);verts.extend(ob.matrix_world@v.co for v in ob.data.vertices)
    faces.extend(tuple(offset+i for i in p.vertices) for p in ob.data.polygons)
tree=BVHTree.FromPolygons(verts,faces)
center=Vector((0,-1.2,66.5));coverage=[]
for source in sources:
    path=Path(source['source'])
    assert hashlib.sha256(path.read_bytes()).hexdigest()==source['source_sha256']
    model=xmodel.Model();model.LoadFile_Bin(str(path),split_meshes=True)
    checked=0;minimum=100;failures=[]
    for mesh in model.meshes:
        for vertex in mesh.verts:
            p=Vector(vertex.offset)
            if p.z<61.9:
                continue # exposed lower neck / shoulder bib are not the skull
            direction=p-center
            if p.z<69.0:
                # The bottom is deliberately open around the neck. A diagonal
                # jaw ray through that opening measures the neck, not the shell.
                direction.z=0
            direction.normalize()
            hit,normal,index,distance=tree.ray_cast(p+direction*40,-direction,80)
            assert hit is not None,(source['asset'],'uncovered skull',tuple(p))
            clearance=(hit-p).dot(direction)
            if clearance<=-.015:
                failures.append((clearance,tuple(p)))
            minimum=min(minimum,clearance);checked+=1
    assert checked>(1500 if source['lod']==0 else 25)
    assert not failures,(source['asset'],'skull clips helmet',len(failures),sorted(failures)[:8])
    coverage.append({'head':source['asset'],'lod':source['lod'],'source_sha256':source['source_sha256'],
                     'skull_vertices_checked':checked,'minimum_radial_outer_clearance':minimum})
result={'status':'PASS','head_enclosure':[c for c in coverage if c['lod']==0],
        'source_head_lod_enclosure':coverage,'eye_emitters':emitters,
        'backpack_removal':json.loads(scene['armored_backpack_removal']),
        'eye_strength_vs_previous':14/3.5,'native_emission_scale':16}
scene['armored_helmet_validation']=json.dumps(result)
print('ARMORED_HELMET_VALIDATED',json.dumps(result),flush=True)
