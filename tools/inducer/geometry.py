"""Place the four separately exported BO6 crystals inside the real chamber.

The dump has local shard coordinates, not map placements. This is a reference-
guided assembly, not recovered retail transforms. Keep the canister unchanged.
"""
import math

CRYSTALS = (
    ((0, 0, 13.5), (1, 1, 1.8)),
    ((-1.25, -.5, 10.8), (1, 1, 1.2)),
    ((.7, .5, 15.5), (.85, 1, 1.2)),
    ((-1.4, .8, 16.8), (3, 3, 3)),
)

def arrange(model):
    shards = [mesh for mesh in model.meshes if all('crystal' in model.materials[f.material_id].name for f in mesh.faces)]
    assert len(shards) == 4
    for mesh, (target, scale) in zip(shards, CRYSTALS):
        center = [(min(v.offset[a] for v in mesh.verts)+max(v.offset[a] for v in mesh.verts))/2 for a in range(3)]
        for v in mesh.verts:
            v.offset = tuple((v.offset[a]-center[a])*scale[a]+target[a] for a in range(3))
            assert 7.1 < v.offset[2] < 19.5 and math.hypot(*v.offset[:2]) < 2.95
        for f in mesh.faces:
            for c in f.indices:
                normal = [c.normal[a]/scale[a] for a in range(3)]
                length = math.sqrt(sum(x*x for x in normal))
                c.normal = tuple(x/length for x in normal)
    # The old grounding used the misplaced shards as the lowest point, leaving
    # the actual feet 2.569 units above the floor. Ground the assembled canister.
    floor = min(v.offset[2] for mesh in model.meshes if mesh not in shards for v in mesh.verts)
    for mesh in model.meshes:
        for v in mesh.verts:
            v.offset = (v.offset[0], v.offset[1], v.offset[2]-floor)
