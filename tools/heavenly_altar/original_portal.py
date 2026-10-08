"""Read the original, user-tested altar inset without remapping its artwork."""
import hashlib
from pathlib import Path
from PyCoD import xmodel

SOURCE = Path('C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/model_export/chaos_models/pack_a_punch/chaos_pack_a_punch.xmodel_bin')
SOURCE_SHA = 'c738e6cb1ce082f4b9a7d64a50af9f2519522650ce1da2e7646434e12ed22c8f'
MATERIAL = 'chaos_pap_background'

def geometry():
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == SOURCE_SHA
    model = xmodel.Model()
    model.LoadFile_Bin(str(SOURCE), split_meshes=True)
    assert len(model.bones) == 1 and model.bones[0].offset == (0, 0, 0)
    result = {'verts': [], 'faces': []}
    for mesh in model.meshes:
        faces = [f for f in mesh.faces if model.materials[f.material_id].name == 'xmaterial_3ca8db9c2b0c764']
        if not faces:
            continue
        used = sorted({c.vertex for f in faces for c in f.indices})
        indices = {v: len(result['verts']) + i for i, v in enumerate(used)}
        for index in used:
            vertex = mesh.verts[index]
            assert vertex.weights == [(0, 1.0)]
            result['verts'].append(vertex.offset)
        for face in faces:
            result['faces'].append([{'v': indices[c.vertex], 'n': c.normal, 'uv': c.uv, 'color': c.color} for c in face.indices])
    assert len(result['faces']) == 32
    return result

def face_signatures(data):
    return sorted(tuple((tuple(data['verts'][c['v']]), tuple(c['n']), tuple(c['uv']), tuple(c['color'])) for c in f) for f in data['faces'])
