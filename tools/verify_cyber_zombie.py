"""Verify native exports preserve stock geometry/rig and damage-model coverage."""
import argparse
import csv
import hashlib
import json
import math
import re
import sys
from pathlib import Path
from cyber_equipment_layout import GROUP_BONES, body_groups, CROWN_HAND

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
manifest = json.loads((ROOT / 'art/cyber_zombie_mvp/engine_kit/install_manifest.json').read_text())
gdt = ROOT / 'source_data/tod_cyber_zombie.gdt'
assert sha(gdt) == manifest['gdt_sha256']
kit_body = re.search(r'"mtl_tod_cyber_kit"\s*\(\s*"material.gdf"\s*\)\s*\{([^}]+)\}', gdt.read_text()).group(1)
kit_fields = dict(re.findall(r'"([^"\r\n]+)"\s*"([^"\r\n]*)"', kit_body))
assert float(kit_fields['waterRoughness']) == 0, 'Cyber emissive layer must stay on the surface'
for name, digest in manifest['textures'].items():
    assert sha(ROOT / 'model_export/tod_cyber_zombie/_images' / name) == digest

expected = {'tod_cyber_head': ['head'], 'tod_cyber_arm_gib': ['arm']+list(CROWN_HAND),'tod_cyber_leftleg_gib':['shin_le']}
for part in ('body','upper','rarmoff','larmoff','legs','rlegoff','llegoff','nolegs'):
    groups=list(body_groups('crown',part))
    if groups:expected['tod_cyber_'+part]=groups
lods = {name: [] for name in expected}
for record in manifest['models']:
    source, target = Path(record['source']), ROOT / record['file']
    assert sha(source) == record['source_sha256']
    assert sha(target) == record['sha256']
    assert record['groups'] == expected[record['asset']]
    lods[record['asset']].append(record['lod'])
    old, new = read(source), read(target)
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
        kit=json.loads((ROOT/'art/cyber_zombie_mvp/engine_kit'/(group+'_lod'+str(record['lod'])+'.json')).read_text())
        assert len(mesh.faces)==len(kit['faces'])
        for actual,expected_face in zip(mesh.faces,kit['faces']):
            for corner,source_corner in zip(actual.indices,expected_face):
                near(mesh.verts[corner.vertex].offset,kit['verts'][source_corner['v']])
                near(corner.normal,source_corner['n'])
                near(corner.uv,source_corner['uv'])
        for v in mesh.verts:
            assert len(v.weights) == 1 and v.weights[0][1] == 1
            kit_bones.add(new.bones[v.weights[0][0]].name.lower())
        for face in mesh.faces:
            assert new.materials[face.material_id].name == 'mtl_tod_cyber_kit'
            for corner in face.indices:
                assert all(math.isfinite(v) for v in corner.normal + corner.uv)
                assert .99 < sum(v*v for v in corner.normal) < 1.01
                assert all(-0.001 <= v <= 1.001 for v in corner.uv)
    group_bones = GROUP_BONES
    assert kit_bones == ({record['force_bone']} if record['force_bone'] else
                         {group_bones[g] for g in record['groups']})
for name, found in lods.items():
    assert sorted(found) == ([0] if name.endswith('_gib') else list(range(7)))

blocks = {}
for name, kind, contents in re.findall(r'"([^"]+)"\s*\(\s*"([^"]+)\.gdf"\s*\)\s*\{([^}]+)\}', gdt.read_text()):
    blocks[name] = (kind, dict(re.findall(r'"([^"]+)"\s+"((?:\\.|[^"\\])*)"', contents)))
def serialized(v):
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    return str(v).replace('"', '\\"').replace('\r', '\\r').replace('\n', '\\n')
copies = manifest['asset_copies']
assert copies['spawner_zm_tod_cyber_horde']['overrides'] == {
    'character1':'c_tod_cyber_trooper','character2':'c_tod_cyber_signal',
    'character3':'c_tod_cyber_relay','character4':'c_tod_cyber_zombie'}
assert copies['c_tod_cyber_zombie']['overrides'] == manifest['character_overrides']
assert copies['tod_cyber_gib_def']['overrides'] == {'leftarm_gibmodel': 'tod_cyber_arm_gib','leftleg_gibmodel':'tod_cyber_leftleg_gib'}
for name, copy in copies.items():
    fields = {**manifest['donor_assets'][copy['kind']+':'+copy['donor']], **copy['overrides']}
    assert blocks[name] == (copy['kind'], {k: serialized(v) for k,v in fields.items() if v is not None}), name
assert 'torsoDmg5' not in manifest['character_overrides']  # retain stock neck collar
for name, copy in copies.items():
    if name.startswith('tod_cyber_') and name != 'tod_cyber_gib_def':
        assert set(copy['overrides']) <= {'skinOverride', 'filename', 'mediumLod', 'lowLod', 'lowestLod', 'lod4File', 'lod5File', 'lod6File'}
assert 'actor_spawner_zm_tod_cyber_horde' in (ROOT / 'tools/gen_tower_map.js').read_text(encoding='utf-8')
assert 'aitype,spawner_zm_tod_cyber_horde' in (ROOT / 'zone_source/zm_tower_of_doom.zone').read_text()
print('CYBER_VERIFY_OK:',len(manifest['models']),'binaries; valid object tables; every stock mesh, bone, bind matrix, vertex, face, UV, color, normal and weight preserved; 7 LODs; native head/limb variants; AI overrides cosmetic only.')
if args.compiled_ledger:
    with args.compiled_ledger.open(encoding='utf-8-sig', newline='') as handle:
        rows = {row['name']: row for row in csv.DictReader(handle)}
    for record in manifest['models']:
        row = rows[record['asset']]
        native_lods = int(row['lodCount'])
        if record['asset'].endswith('_gib'):
            assert native_lods == 8  # stock gib settings generate seven lower LODs
        else:
            assert native_lods == len(lods[record['asset']])
        # Native ledger lists coarse -> fine, opposite the source LOD order.
        column = native_lods - 1 - record['lod']
        count = int(row['tris' + str(column)])
        # The converter removes a few stock degenerate triangles; a missing
        # body part is hundreds/thousands. Check every LOD, not asset presence.
        assert 0 <= record['triangles'] - count <= 8, (record['asset'], record['lod'], record['triangles'], count)
    body, upper = rows['tod_cyber_body'], rows['tod_cyber_upper']
    extra=sum(len(json.loads((ROOT/'art/cyber_zombie_mvp/engine_kit'/(g+'_lod0.json')).read_text())['faces']) for g in body_groups('crown','legs'))
    assert int(body['tris6']) - int(upper['tris6']) == 6520+extra, 'Intact body lost lower-body geometry'
    print('CYBER_NATIVE_GEOMETRY_OK: all authored LODs retain expected triangle coverage; intact body includes all 6,520 stock leg triangles plus leg equipment.')
