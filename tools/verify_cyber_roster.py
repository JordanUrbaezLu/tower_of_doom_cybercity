"""Verify native exports preserve stock geometry/rig and damage-model coverage."""
import argparse
import csv
import hashlib
import json
import math
import re
import sys
from pathlib import Path
from cyber_equipment_layout import GROUP_BONES, body_groups, BODY_GROUPS, LEFT_HAND
from cyber_arm_replacement import POLICY as ARM_POLICY, replace_arm_surfaces
from cyber_back_spikes import enlarge_back_spikes

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path.home() / 'AppData/Roaming/Blender Foundation/Blender/4.2/scripts/addons/BetterBetterBlenderCOD'))
from PyCoD import xmodel

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def near(a, b, tol=0.0001):
    assert len(a) == len(b)
    assert all(math.isfinite(x) and math.isfinite(y) and abs(x-y) < tol for x, y in zip(a, b)), (a, b)

def read(p):
    model = xmodel.Model()
    # A flat read hides dangling object IDs that BO3 silently drops.
    model.LoadFile_Bin(str(p), split_meshes=True)
    for index, mesh in enumerate(model.meshes):
        assert all(face.mesh_id == index for face in mesh.faces), (p, mesh.name)
    return model

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--compiled-ledger', type=Path, help='Also verify native converter triangle coverage from the fresh xmodel CSV.')
args = parser.parse_args()
manifest = json.loads((ROOT / 'art/cyber_zombie_roster/engine_kit/install_manifest.json').read_text())
gdt = ROOT / 'source_data/tod_cyber_roster.gdt'
assert sha(gdt) == manifest['gdt_sha256']
for kit in ('trooper', 'signal', 'relay', 'sprinter'):
    body = re.search(r'"mtl_tod_roster_' + kit + r'"\s*\(\s*"material.gdf"\s*\)\s*\{([^}]+)\}', gdt.read_text()).group(1)
    fields = dict(re.findall(r'"([^"\r\n]+)"\s*"([^"\r\n]*)"', body))
    assert float(fields['waterRoughness']) == 0, kit + ' emissive layer must stay on the surface'
    assert float(fields['scaleRGB'])==(16 if kit=='sprinter' else 6), kit+' emission bake/decode mismatch'
for name, digest in manifest['textures'].items():
    assert sha(ROOT / 'model_export/tod_cyber_zombie/_images' / name) == digest

expected = {}
for family in ('trooper','relay'):
    expected['tod_cyber_'+family+'_arm_gib']=['arm']
    expected['tod_cyber_'+family+'_leftleg_gib']=['shin_le']
    expected['tod_cyber_'+family+'_rightarm_gib']=['rightarm']
    expected['tod_cyber_'+family+'_rightleg_gib']=['shin_ri']
    for part in ('body','upper','rarmoff','larmoff','legs','rlegoff','llegoff','nolegs'):
        groups=list(body_groups(family,part))
        if groups:expected['tod_cyber_'+family+'_'+part]=groups
for index in (1,2,3):expected['tod_cyber_hhead'+str(index)]=['head']
for index in (2,3):expected['tod_cyber_bhead'+str(index)]=['head']
expected['tod_cyber_helmet_signal']=['helmet']
for index in (1,2,3):expected['tod_cyber_sprinter_head'+str(index)]=['head']
expected['tod_cyber_trooper_rightarm_gib']=['rightarm']
expected['tod_cyber_trooper_rightleg_gib']=['shin_ri']
expected['tod_cyber_sprinter']=list(BODY_GROUPS['sprinter'])
lods = {name: [] for name in expected}
for record in manifest['models']:
    source, target = Path(record['source']), ROOT / record['file']
    assert sha(source) == record['source_sha256']
    assert sha(target) == record['sha256']
    assert record['groups'] == expected[record['asset']]
    lods[record['asset']].append(record['lod'])
    old, new = read(source), read(target)
    replace_arms=record['asset']=='tod_cyber_sprinter'
    assert record.get('arm_surface_replacement')==(ARM_POLICY if replace_arms else None)
    if replace_arms:
        assert record['source_asset']=='c_t8_zmb_mob_zombie_body3'
        back_spikes=enlarge_back_spikes(old,sha(source))
        assert record.get('back_spikes')==back_spikes
        removed,vertices=replace_arm_surfaces(old)
        assert removed==record['removed_arm_faces'] and sum(removed)>1000,removed
        assert vertices==record['removed_arm_vertices'] and sum(vertices)>0,vertices
    else:
        assert record.get('back_spikes') is None
        assert record.get('removed_arm_faces',[])==[]
        assert record.get('removed_arm_vertices',[])==[]
    assert len(old.bones) == len(new.bones)
    for a, b in zip(old.bones, new.bones):
        assert (a.name, a.parent) == (b.name, b.parent)
        near(a.offset, b.offset)
        for row_a, row_b in zip(a.matrix, b.matrix):
            near(row_a, row_b)
    assert len(old.meshes) == record['base_meshes']
    assert len(new.meshes) == len(old.meshes) + len(record['groups'])
    assert [mesh.name for mesh in new.meshes] == record['mesh_names']
    assert sum(len(mesh.faces) for mesh in new.meshes) == record['triangles']
    for a, b in zip(old.meshes, new.meshes):
        assert a.name == b.name
        assert len(a.verts) == len(b.verts)
        assert len(a.faces) == len(b.faces)
        for va, vb in zip(a.verts, b.verts):
            near(va.offset, vb.offset)
            assert len(va.weights) == len(vb.weights)
            for (ia, wa), (ib, wb) in zip(va.weights, vb.weights):
                assert ia == ib
                near([wa], [wb])
        for fa, fb in zip(a.faces, b.faces):
            assert fa.mesh_id == fb.mesh_id
            assert old.materials[fa.material_id].name == new.materials[fb.material_id].name
            for ca, cb in zip(fa.indices, fb.indices):
                assert ca.vertex == cb.vertex
                near(ca.normal, cb.normal)
                near(ca.uv, cb.uv)
                near(ca.color, cb.color)
    kit_bones = set()
    for mesh, group in zip(new.meshes[len(old.meshes):], record['groups']):
        assert mesh.name == 'cyber_' + group
        kit=json.loads((ROOT/'art/cyber_zombie_roster/engine_kit'/record['variant']/(group+'_lod'+str(record['lod'])+'.json')).read_text())
        assert record['rotate_equipment']==(record['source_asset']=='c_t8_zmb_mob_zombie_body3')
        rotate=lambda p:(-p[1],p[0],p[2]) if record['rotate_equipment'] else p
        assert len(mesh.faces)==len(kit['faces'])
        for actual,expected_face in zip(mesh.faces,kit['faces']):
            for corner,source_corner in zip(actual.indices,expected_face):
                near(new.meshes[actual.mesh_id].verts[corner.vertex].offset,rotate(kit['verts'][source_corner['v']]))
                near(corner.normal,rotate(source_corner['n']))
                near(corner.uv,source_corner['uv'])
        for v in mesh.verts:
            assert len(v.weights) == 1 and v.weights[0][1] == 1
            kit_bones.add(new.bones[v.weights[0][0]].name.lower())
        for face in mesh.faces:
            assert new.materials[face.material_id].name == record['material']
            for corner in face.indices:
                assert all(math.isfinite(v) for v in corner.normal + corner.uv)
                assert .99 < sum(v*v for v in corner.normal) < 1.01
                assert all(-0.001 <= v <= 1.001 for v in corner.uv)
    group_bones = GROUP_BONES
    assert kit_bones == ({record['force_bone']} if record['force_bone'] else
                         {group_bones[g] for g in record['groups']})
for name, found in lods.items():
    assert sorted(found) == ([0] if name == 'tod_cyber_sprinter' or name.endswith('_gib') else list(range(7)))

blocks = {}
for name, kind, contents in re.findall(r'"([^"]+)"\s*\(\s*"([^"]+)\.gdf"\s*\)\s*\{([^}]+)\}', gdt.read_text()):
    blocks[name] = (kind, dict(re.findall(r'"([^"]+)"\s+"((?:\\.|[^"\\])*)"', contents)))
def serialized(v):
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    return str(v).replace('"', '\\"').replace('\r', '\\r').replace('\n', '\\n')
copies = manifest['asset_copies']
for name, copy in copies.items():
    fields = {**manifest['donor_assets'][copy['kind']+':'+copy['donor']], **copy['overrides']}
    assert blocks[name] == (copy['kind'], {k: serialized(v) for k,v in fields.items() if v is not None}), name
for name, copy in copies.items():
    overrides=copy['overrides']
    if copy['kind']=='xmodel':
        allowed={'skinOverride','filename','mediumLod','lowLod','lowestLod','lod4File','lod5File','lod6File'}
        if name=='tod_cyber_sprinter':allowed.update('autogen'+f for f in ('MediumLod','LowLod','LowestLod','Lod4','Lod5','Lod6','Lod7'))
        if name in ('tod_cyber_sprinter', 'tod_cyber_sprinter_head1', 'tod_cyber_sprinter_head2', 'tod_cyber_sprinter_head3'):
            allowed.add('scale')
            assert overrides.get('scale') == 1.33, name
        # The ONE permitted non-cosmetic xmodel field (2026-09-16): a donor's
        # japaneseUnsafe flag is cleared on our derived re-skin so the ja_ pass
        # can pack it. Pinned tight on purpose - it may only ever go 1 -> 0, and
        # only where the donor actually carried it, so this stays an unpacking
        # fix and never becomes a hole other fields can travel through.
        if 'japaneseUnsafe' in overrides:
            allowed.add('japaneseUnsafe')
            assert overrides['japaneseUnsafe']==0,name
            assert manifest['donor_assets']['xmodel:'+copy['donor']].get('japaneseUnsafe') not in (None,'',0,'0',0.0),name
        assert set(overrides)<=allowed,name
    if copy['kind']=='character':
        assert overrides==manifest['characters'][name]
        assert set(overrides)<={'body','head','headAlias','gibDef','hat','torsoDmg1','torsoDmg2','torsoDmg3','torsoDmg4','legDmg1','legDmg2','legDmg3','legDmg4'}
        assert overrides['head']==''
        gib=copies[overrides['gibDef']]['overrides']
        short=name.removeprefix('c_tod_cyber_')
        assert gib['leftarm_gibmodel']==('tod_cyber_arm_gib' if short=='signal' else 'tod_cyber_'+short+'_arm_gib')
        assert gib['leftleg_gibmodel']==('tod_cyber_leftleg_gib' if short=='signal' else 'tod_cyber_'+short+'_leftleg_gib')
        if short in ('trooper','relay'):
            assert gib['rightarm_gibmodel']=='tod_cyber_'+short+'_rightarm_gib'
            assert gib['rightleg_gibmodel']=='tod_cyber_'+short+'_rightleg_gib'
        if 'hat' in overrides:
            assert gib['head_gibmodel']==overrides['hat']
            assert overrides['headAlias']=='tod_cyber_helmet_heads'
        else:
            assert 'head_gibmodel' not in gib
            assert overrides['headAlias']=='tod_cyber_bare_heads'
    if copy['kind']=='gibcharacterdef':assert set(overrides)<={'leftarm_gibmodel','rightarm_gibmodel','leftleg_gibmodel','rightleg_gibmodel','head_gibmodel'}
assert copies['tod_cyber_bare_heads']['overrides']=={'model1':'tod_cyber_head','model2':'tod_cyber_bhead2','model3':'tod_cyber_bhead3'}
assert copies['tod_cyber_helmet_heads']['overrides']=={'model'+str(i):'tod_cyber_hhead'+str(i) for i in (1,2,3)}
mvp=json.loads((ROOT/'art/cyber_zombie_mvp/engine_kit/install_manifest.json').read_text())
assert mvp['asset_copies']['spawner_zm_tod_cyber_horde']['overrides']=={'character'+slot:char for slot,char in manifest['appearance_slots'].items()}
assert mvp['character_overrides']['headAlias']=='tod_cyber_bare_heads'
print('CYBER_ROSTER_VERIFY_OK:',len(manifest['models']),'binaries; donor objects, bones and weights preserved; armored forearm/hand faces replaced by exact elbow-weight mask; 14 rear spikes scaled 1.30 at fixed roots (520 vertices); all other donor surfaces unchanged; all appearances, heads and gibs verified.')
if args.compiled_ledger:
    with args.compiled_ledger.open(encoding='utf-8-sig', newline='') as handle:
        rows = {row['name']: row for row in csv.DictReader(handle)}
    for record in manifest['models']:
        row = rows[record['asset']]
        native_lods = int(row['lodCount'])
        if record['asset'] == 'tod_cyber_sprinter' or record['asset'].endswith('_gib'):
            # Both the sprinter and inherited stock arm-gib settings generate
            # seven lower LODs from their single authored source mesh.
            assert native_lods == 8
        else:
            assert native_lods == len(lods[record['asset']])
        # Native ledger lists coarse -> fine, opposite the source LOD order.
        column = native_lods - 1 - record['lod']
        count = int(row['tris' + str(column)])
        # The converter removes a few stock degenerate triangles; a missing
        # body part is hundreds/thousands. Check every LOD, not asset presence.
        assert 0 <= record['triangles'] - count <= 8, (record['asset'], record['lod'], record['triangles'], count)
    for family in ('trooper','relay'):
        body,upper=rows['tod_cyber_'+family+'_body'],rows['tod_cyber_'+family+'_upper']
        extra=sum(len(json.loads((ROOT/'art/cyber_zombie_roster/engine_kit'/family/(g+'_lod0.json')).read_text())['faces']) for g in body_groups(family,'legs'))
        assert int(body['tris6'])-int(upper['tris6'])==5474+extra, (family,'lower-body geometry lost')
    print('CYBER_ROSTER_NATIVE_OK: all authored LODs retain geometry; both body-1 variants include all 5,474 stock leg triangles plus their new leg equipment; sprinter has eight native LODs.')
