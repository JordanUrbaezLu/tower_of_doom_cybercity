"""Blender 4.2: convert BO6's Rampage Inducer into a BO3 static prop.

THE ASSET (found 2026-09-13, memory bo6-rampage-inducer-is-aether-canister):
BO6's Rampage Inducer is `t10_zm_essence_container_orange` — the orange
Aetherium essence container — plus four separate crystal shards
`t10_zm_essence_container_crystal_01..04` that float inside its glass cylinder.
Its asset name contains neither "rampage" nor "inducer"; those return 0 of
272,642 loaded BO6 assets. It was found by searching the FICTION (`kind:model
essence`), because the wikis call it "an Aetherium essence canister containing
fragments of a Fury Crystal".

WHAT THIS DOES, and what it deliberately does not:
- imports the container and the four shards, JOINS them into one static prop
  (BO6 places the shards as separate map entities; BO3 wants one SetModel), and
  writes a single-bone `tag_origin` BO3 model. The shards keep their own
  materials.
- GROUNDS it: the mesh is shifted so its lowest point sits at z = 0, so the
  script can place it on a floor or a pedestal top without a magic offset.
- keeps every source material identity; it renames them `mtl_tod_inducer_*`.
- does NOT edit weapon fields, gameplay, FX or audio, and does not deploy.

Run: "C:\\Program Files\\Blender Foundation\\Blender 4.2\\blender.exe" -b -noaudio
     --python tools/bo6_extraction/stage_rampage_inducer.py
"""
import addon_utils
import bpy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from BetterBetterBlenderCOD.PyCoD import xmodel

REPO = Path(r'C:\Users\jorda\Repositories\tower_of_doom_cybercity')
EXPORT = Path.home()/'Downloads/BO6_Pilot_Export/bo6/models'
TOOLS = Path(r'C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130')
OUT = REPO/'local_sync_cache/bo6_inducer/staging'
SCALE = 1/2.54          # BO6 authors in cm; BO3 works in inches
PARTS = ['t10_zm_essence_container_orange',
         't10_zm_essence_container_crystal_01',
         't10_zm_essence_container_crystal_02',
         't10_zm_essence_container_crystal_03',
         't10_zm_essence_container_crystal_04']


# BO3 TRUNCATES AN ASSET NAME AT 63 CHARACTERS AND THEN CANNOT FIND IT IN THE
# gdtDB - it reports "Material <truncated> was not found" and silently
# default-substitutes, which on a glass cylinder is a white face. The first cut
# built the name straight from BO6's, giving
# mtl_tod_inducer_m_mtl_t10_zm_essence_container_large_orange_glass (65) and
# exactly that failure. This is the ONE naming rule, duplicated verbatim in
# stage_rampage_inducer.py and install_inducer_bo3.py; they MUST agree, because
# stage writes the name into the mesh and install writes the GDT block it binds
# to. Longest name it can now produce is 32 characters.
def short_key(name):
    key = name
    for prefix in ('material_', 'm_', 'mtl_t10_zm_', 't10_zm_'):
        key = key.removeprefix(prefix)
    key = key.replace('essence_container_large_orange_', '').replace('essence_container_', '')
    key = key.replace('crystal_medium_', 'crystal')
    return key[:24]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    addon_utils.enable('io_scene_cast', default_set=False)

    part_meshes = {}
    for part in PARTS:
        src = EXPORT/part/f'{part}_LOD0.cast'
        assert src.is_file(), src
        before = {o.name for o in bpy.context.scene.objects}
        bpy.ops.import_scene.cast(filepath=str(src), import_skin=False)
        fresh = [o for o in bpy.context.scene.objects
                 if o.name not in before and o.type == 'MESH']
        assert fresh, part
        part_meshes[part] = fresh

    meshes = [o for parts in part_meshes.values() for o in parts]
    assert meshes, 'no meshes imported'

    # --- one bone, at the prop's own origin -------------------------------
    model = xmodel.Model()
    model.version = 6
    root = xmodel.Bone('tag_origin', -1)
    root.offset = (0.0, 0.0, 0.0)
    root.matrix = [(1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)]
    model.bones.append(root)

    materials = sorted({slot.material.name for o in meshes
                        for slot in o.material_slots if slot.material})
    material_ids = {name: i for i, name in enumerate(materials)}
    for name in materials:
        model.materials.append(xmodel.Material('mtl_tod_inducer_' + short_key(name), 'Phong', {}))

    # --- first pass: measure, so we can ground the prop --------------------
    lowest = None
    for obj in meshes:
        for vertex in obj.data.vertices:
            z = ((obj.matrix_world @ vertex.co) * SCALE).z
            lowest = z if lowest is None else min(lowest, z)
    lift = -lowest

    points = []
    for number, obj in enumerate(meshes):
        data = obj.data
        data.calc_loop_triangles()
        assert len(data.uv_layers) >= 1, obj.name
        uv = data.uv_layers[0]
        mesh = xmodel.Mesh('tod_inducer_' + str(number))
        for vertex in data.vertices:
            position = (obj.matrix_world @ vertex.co) * SCALE
            position.z += lift
            points.append(tuple(position))
            mesh.verts.append(xmodel.Vertex(tuple(position), [(0, 1.0)]))
        normal_matrix = obj.matrix_world.to_3x3().inverted().transposed()
        for tri in data.loop_triangles:
            slot = obj.material_slots[tri.material_index].material
            face = xmodel.Face(len(model.meshes), material_ids[slot.name])
            # Cast's Blender importer and BO3's raw export use opposite winding.
            for j, loop_index in enumerate((tri.loops[0], tri.loops[2], tri.loops[1])):
                u, v = uv.data[loop_index].uv
                normal = (normal_matrix @ data.corner_normals[loop_index].vector).normalized()
                face.indices[j] = xmodel.FaceVertex(data.loops[loop_index].vertex_index,
                                                    tuple(normal), (1, 1, 1, 1), (u, 1 - v))
            mesh.faces.append(face)
        model.meshes.append(mesh)

    sys.path.insert(0, str(REPO/'tools/inducer'))
    import geometry, importlib
    importlib.reload(geometry).arrange(model)
    points = [v.offset for mesh in model.meshes for v in mesh.verts]
    verts = sum(len(m.verts) for m in model.meshes)
    tris = sum(len(m.faces) for m in model.meshes)

    raw = OUT/'tod_inducer.XMODEL_EXPORT'
    model.WriteFile_Raw(str(raw))
    run = subprocess.run([str(TOOLS/'bin/export2bin.exe'), raw.name], cwd=OUT,
                         capture_output=True, text=True, timeout=600)
    (OUT/'export2bin.log').write_text(run.stdout + '\n' + run.stderr)
    assert run.returncode == 0, (run.stdout, run.stderr)
    binary = next(p for p in OUT.iterdir() if p.name.lower() == 'tod_inducer.xmodel_bin')

    check = xmodel.Model()
    check.LoadFile_Bin(str(binary))
    assert [(b.name, b.parent) for b in check.bones] == [('tag_origin', -1)]
    assert sum(len(m.verts) for m in check.meshes) == verts
    assert sum(len(m.faces) for m in check.meshes) == tris

    bounds = [[min(p[a] for p in points) for a in range(3)],
              [max(p[a] for p in points) for a in range(3)]]
    report = dict(
        stage='inducer_geometry_only', deployed=False, native_verified=False,
        parts={p: len(m) for p, m in part_meshes.items()},
        sources=[dict(path=str(EXPORT/p/f'{p}_LOD0.cast'),
                      sha256=digest(EXPORT/p/f'{p}_LOD0.cast')) for p in PARTS],
        scale_cm_to_inches=SCALE, grounded_lift_inches=lift,
        bounds_inches=bounds,
        size_inches=[bounds[1][a] - bounds[0][a] for a in range(3)],
        meshes=len(meshes), vertices=verts, triangles=tris,
        material_mapping={name: check.materials[i].name for name, i in material_ids.items()},
        files=[dict(path=str(p), sha256=digest(p)) for p in (raw, binary)])
    (OUT/'geometry.json').write_text(json.dumps(report, indent=2) + '\n')
    print('INDUCER_OK', json.dumps(dict(size=report['size_inches'], verts=verts,
                                        tris=tris, materials=len(materials),
                                        lift=lift)))


main()
