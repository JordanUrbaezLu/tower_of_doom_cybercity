"""Blender 4.2: convert the acquired BO6 staff body into an isolated BO3 source.

Based on Tower of Doom II's build_saug_bo3.py. This is a staging conversion:
the source has no water tip, and nothing here edits weapon fields or deploys a
model. All bones, source influences and source material identities are retained.
Animation retargeting, attachment alignment and runtime materials remain open.
"""
import addon_utils
import bpy
import hashlib
import json
from pathlib import Path
import subprocess
from BetterBetterBlenderCOD.PyCoD import xmodel

REPO = Path(__file__).resolve().parents[2]
SOURCE = Path.home()/'Downloads/BO6_Pilot_Export/bo6/models/wpn_t10_wm_ww_zmb_staffs_nocol/wpn_t10_wm_ww_zmb_staffs_nocol_LOD0.cast'
TOOLS = Path(r'C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130')
OUT = REPO/'local_sync_cache/bo6_ice_staff/staging/body'
SCALE = 1/2.54


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    assert SOURCE.is_file(), SOURCE
    assert (TOOLS/'bin/export2bin.exe').is_file(), TOOLS
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    addon_utils.enable('io_scene_cast', default_set=False)
    bpy.ops.import_scene.cast(filepath=str(SOURCE), import_skin=True)
    rigs = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    assert len(rigs) == 1 and len(meshes) == 8, (len(rigs), len(meshes))
    rig = rigs[0]
    bones = list(rig.data.bones)
    assert len(bones) == 61 and bones[0].name == 'j_gun'
    indices = {b.name:i for i,b in enumerate(bones)}
    model = xmodel.Model()
    model.version = 6
    for b in bones:
        parent = indices[b.parent.name] if b.parent else -1
        assert parent < indices[b.name], b.name
        world = rig.matrix_world @ b.matrix_local
        target = xmodel.Bone(b.name, parent)
        target.offset = tuple(world.translation*SCALE)
        target.matrix = [tuple(row) for row in world.to_3x3().transposed()]
        model.bones.append(target)
    materials = sorted({slot.material.name for o in meshes for slot in o.material_slots if slot.material})
    assert len(materials) == 4
    material_ids = {name:i for i,name in enumerate(materials)}
    for name in materials:
        model.materials.append(xmodel.Material('mtl_tod_bo6_ice_'+name.removeprefix('material_'), 'Phong', {}))
    points = []
    weights_report = dict(max_influences=0, vertices_over_four=0, discarded_weight=0)
    for number, obj in enumerate(meshes):
        data = obj.data
        data.calc_loop_triangles()
        assert len(data.uv_layers) == 1, obj.name
        groups = {g.index:indices[g.name] for g in obj.vertex_groups if g.name in indices}
        mesh = xmodel.Mesh('tod_bo6_ice_body_'+str(number))
        for vertex in data.vertices:
            weights = [(groups[g.group],g.weight) for g in vertex.groups
                       if g.group in groups and g.weight > 0]
            assert weights and all(g.group in groups for g in vertex.groups if g.weight > 0), vertex.index
            total = sum(w for _,w in weights)
            assert abs(total-1) < .002, (obj.name,vertex.index,total)
            weights_report['max_influences'] = max(weights_report['max_influences'],len(weights))
            weights_report['vertices_over_four'] += len(weights)>4
            position = (obj.matrix_world @ vertex.co)*SCALE
            points.append(position)
            mesh.verts.append(xmodel.Vertex(tuple(position),[(i,w/total) for i,w in weights]))
        uv = data.uv_layers[0]
        normal_matrix = obj.matrix_world.to_3x3().inverted().transposed()
        for tri in data.loop_triangles:
            material = obj.material_slots[tri.material_index].material.name
            face = xmodel.Face(len(model.meshes),material_ids[material])
            # Cast's Blender importer and BO3's raw export use opposite winding.
            for j, loop_index in enumerate((tri.loops[0],tri.loops[2],tri.loops[1])):
                u,v = uv.data[loop_index].uv
                normal = (normal_matrix @ data.corner_normals[loop_index].vector).normalized()
                face.indices[j] = xmodel.FaceVertex(data.loops[loop_index].vertex_index,
                                                   tuple(normal),(1,1,1,1),(u,1-v))
            mesh.faces.append(face)
        model.meshes.append(mesh)
    assert sum(len(m.verts) for m in model.meshes) == 37937
    assert sum(len(m.faces) for m in model.meshes) == 46266
    raw = OUT/'tod_bo6_ice_body.XMODEL_EXPORT'
    model.WriteFile_Raw(str(raw))
    run = subprocess.run([str(TOOLS/'bin/export2bin.exe'),raw.name],cwd=OUT,
                         capture_output=True,text=True,timeout=300)
    (OUT/'export2bin.log').write_text(run.stdout+'\n'+run.stderr)
    assert run.returncode == 0, (run.stdout,run.stderr)
    binary = raw.with_suffix('.XMODEL_BIN')
    check = xmodel.Model()
    check.LoadFile_Bin(str(binary))
    assert [(b.name,b.parent) for b in check.bones] == [(b.name,b.parent) for b in model.bones]
    matrix_error=0
    for a,b in zip(model.bones,check.bones):
        assert max(abs(x-y) for x,y in zip(a.offset,b.offset)) < .00001, a.name
        error=max(abs(x-y) for row_a,row_b in zip(a.matrix,b.matrix)
                  for x,y in zip(row_a,row_b))
        matrix_error=max(matrix_error,error)
        # XMODEL_BIN stores each rotation component as signed int16 / 32767
        # (PyCoD xbin.LoadShortVec3). Allow one quantization step plus the
        # preceding raw text writer's six-decimal rounding.
        assert error <= 1/32767 + .000001, (a.name,error)
    assert sum(len(m.verts) for m in check.meshes) == 37937
    assert sum(len(m.faces) for m in check.meshes) == 46266
    # The reader rebuilds vertex order from first face use. Compare matching
    # face corners, not the reordered flat vertex arrays.
    for original, converted in zip(model.meshes, check.meshes):
        assert len(original.faces) == len(converted.faces)
        for old_face, new_face in zip(original.faces, converted.faces):
            assert old_face.material_id == new_face.material_id
            for old_corner,new_corner in zip(old_face.indices,new_face.indices):
                a=original.verts[old_corner.vertex]
                b=converted.verts[new_corner.vertex]
                assert max(abs(x-y) for x,y in zip(a.offset,b.offset)) < .00001
                old_weights,new_weights=dict(a.weights),dict(b.weights)
                assert old_weights.keys() == new_weights.keys()
                assert all(abs(w-new_weights[i]) < .000002 for i,w in old_weights.items())
    report = dict(stage='body_geometry_only', source=str(SOURCE), source_sha256=digest(SOURCE),
        water_tip_present=False, deployed=False, native_verified=False, scale_cm_to_inches=SCALE,
        bounds_inches=[[min(p[a] for p in points) for a in range(3)],
                       [max(p[a] for p in points) for a in range(3)]],
        meshes=len(meshes),vertices=37937,triangles=46266,
        bones=[dict(name=b.name,parent=b.parent) for b in check.bones],
        material_mapping={name:check.materials[i].name for name,i in material_ids.items()},
        weights=weights_report,
        max_rotation_component_roundtrip_error=matrix_error,
        files=[dict(path=str(p),sha256=digest(p)) for p in (raw,binary)],
        open=['Acquire and assemble the water tip and first-person body',
              'Reconstruct remaining material layers and emission',
              'Retarget held motions and validate weighted vertices per frame',
              'Bind and verify sockets, audio, FX and native gameplay'])
    (OUT/'geometry.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ('bones','files','material_mapping')},indent=2))


if __name__ == '__main__':
    main()
