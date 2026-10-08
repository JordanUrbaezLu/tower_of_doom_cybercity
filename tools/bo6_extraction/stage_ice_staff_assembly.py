"""Blender: assemble the original BO6 body and water tip by their shared socket.

Uses Tower II's bone-name attachment method and the earlier staff roundtrip
checks. Outputs only isolated staging. No hand alignment, bone loss, material
replacement or native presentation claim is made here.
"""
import addon_utils
import bpy
import hashlib
import json
from pathlib import Path
import subprocess
from mathutils import Matrix, Vector
from BetterBetterBlenderCOD.PyCoD import xmodel
from io_scene_cast import cast

REPO = Path(__file__).resolve().parents[2]
SOURCE = Path.home()/'Downloads/BO6_Pilot_Export/bo6/models'
TOOLS = Path(r'C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130')
OUT = REPO/'local_sync_cache/bo6_ice_staff/staging/assembly'
SCALE = 1/2.54


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build(perspective):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    addon_utils.enable('io_scene_cast',default_set=False)
    bones,indices,meshes,parts,slots = [],{},{},[],{}
    for name,join,want_vertices,want_faces in (
        (f'wpn_t10_{perspective}_ww_zmb_staffs',None,37937,46266),
        (f'att_t10_{perspective}_ww_zmb_staffs_water_tip','tag_barrel_attach',13123,13576),
    ):
        path = SOURCE/name/(name+'_LOD0.cast')
        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.cast(filepath=str(path),import_skin=True)
        added = set(bpy.context.scene.objects)-before
        rigs = [o for o in added if o.type == 'ARMATURE']
        objects = sorted((o for o in added if o.type == 'MESH'),key=lambda o:o.name)
        assert len(rigs)==1 and objects,path
        rig = rigs[0]
        assert rig.matrix_world == Matrix.Identity(4)
        roots = [b for b in rig.data.bones if not b.parent]
        assert len(roots)==1 and roots[0].name == (join or 'j_gun')
        shift = bones[indices[join]][2] if join else Matrix.Identity(4)
        local = {}
        for bone in rig.data.bones:
            if join and not bone.parent:
                local[bone.name] = indices[join]
                continue
            assert bone.name not in indices,bone.name
            parent = local[bone.parent.name] if bone.parent else -1
            local[bone.name] = len(bones)
            indices[bone.name] = len(bones)
            bones.append((bone.name,parent,shift@bone.matrix_local))
        rig.matrix_world = shift
        verts = faces = 0
        for obj in objects:
            # Imported meshes are parented to the source armature. The rig
            # shift already moves their evaluated world transform once.
            bpy.context.view_layer.update()
            groups = {g.index:local[g.name] for g in obj.vertex_groups}
            obj.data.calc_loop_triangles()
            verts += len(obj.data.vertices)
            faces += len(obj.data.loop_triangles)
            meshes[obj.name] = (obj,groups)
        assert (verts,faces)==(want_vertices,want_faces),(name,verts,faces)
        for root in cast.Cast.load(str(path)).Roots():
            for model in root.ChildrenOfType(cast.Model):
                for material in model.Materials():
                    value = {key:str(path.parent/value.Path()) for key,value in material.Slots().items() if isinstance(value,cast.File)}
                    if material.Name() in slots:
                        assert all(digest(Path(slots[material.Name()][k]))==digest(Path(v)) for k,v in value.items())
                    slots[material.Name()] = value
        parts.append(dict(source=str(path),sha256=digest(path),join=join,vertices=verts,triangles=faces,shift=[list(r) for r in shift]))
    assert len(bones)==76 and len(meshes)==11
    model = xmodel.Model()
    model.version = 6
    for name,parent,rest in bones:
        bone = xmodel.Bone(name,parent)
        bone.offset = tuple(rest.translation*SCALE)
        bone.matrix = [tuple(r) for r in rest.to_3x3().transposed()]
        model.bones.append(bone)
    material_ids = {name:i for i,name in enumerate(sorted(slots))}
    for name in material_ids:
        model.materials.append(xmodel.Material('mtl_tod_bo6_ice_'+name.removeprefix('material_'),'Phong',{}))
    positions=[]
    max_weights=0
    for obj,groups in meshes.values():
        data=obj.data
        assert len(data.uv_layers)==1 and len(data.color_attributes)==0,obj.name
        mesh=xmodel.Mesh(obj.name)
        for vertex in data.vertices:
            weights=[(groups[g.group],g.weight) for g in vertex.groups if g.weight>0]
            total=sum(w for _,w in weights)
            assert weights and abs(total-1)<.002,(obj.name,vertex.index,total)
            max_weights=max(max_weights,len(weights))
            assert len(weights)<=4,'Do not silently discard influences'
            point=(obj.matrix_world@vertex.co)*SCALE
            positions.append(point)
            mesh.verts.append(xmodel.Vertex(tuple(point),[(i,w/total) for i,w in weights]))
        normal_matrix=obj.matrix_world.to_3x3().inverted().transposed()
        for tri in data.loop_triangles:
            material=obj.material_slots[tri.material_index].material.name
            face=xmodel.Face(len(model.meshes),material_ids[material])
            for i,loop in enumerate((tri.loops[0],tri.loops[2],tri.loops[1])):
                u,v=data.uv_layers[0].data[loop].uv
                normal=(normal_matrix@data.corner_normals[loop].vector).normalized()
                face.indices[i]=xmodel.FaceVertex(data.loops[loop].vertex_index,tuple(normal),(1,1,1,1),(u,1-v))
            mesh.faces.append(face)
        model.meshes.append(mesh)
    raw=OUT/('tod_bo6_ice_'+perspective+'.XMODEL_EXPORT')
    model.WriteFile_Raw(str(raw))
    result=subprocess.run([str(TOOLS/'bin/export2bin.exe'),raw.name],cwd=OUT,capture_output=True,text=True,timeout=300)
    (OUT/(perspective+'_export2bin.log')).write_text(result.stdout+'\n'+result.stderr)
    assert result.returncode==0,(result.stdout,result.stderr)
    binary=raw.with_suffix('.XMODEL_BIN')
    check=xmodel.Model()
    check.LoadFile_Bin(str(binary))
    assert [(b.name,b.parent) for b in check.bones]==[(b.name,b.parent) for b in model.bones]
    assert sum(len(m.verts) for m in check.meshes)==51060
    assert sum(len(m.faces) for m in check.meshes)==59842
    assert [m.name for m in check.materials]==[m.name for m in model.materials]
    for a,b in zip(model.bones,check.bones):
        assert max(abs(x-y) for x,y in zip(a.offset,b.offset))<.00001
        assert max(abs(x-y) for ar,br in zip(a.matrix,b.matrix) for x,y in zip(ar,br))<=1/32767+.000001
    for a,b in zip(model.meshes,check.meshes):
        assert len(a.faces)==len(b.faces)
        for af,bf in zip(a.faces,b.faces):
            assert af.material_id==bf.material_id
            for ac,bc in zip(af.indices,bf.indices):
                av,bv=a.verts[ac.vertex],b.verts[bc.vertex]
                assert max(abs(x-y) for x,y in zip(av.offset,bv.offset))<.00001
                aw,bw=dict(av.weights),dict(bv.weights)
                assert aw.keys()==bw.keys() and all(abs(w-bw[i])<.000002 for i,w in aw.items())
    blend=OUT/('tod_bo6_ice_'+perspective+'.blend')
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    report=dict(perspective=perspective,stage='source_assembly',deployed=False,native_verified=False,parts=parts,vertices=51060,triangles=59842,bones=len(bones),meshes=len(meshes),max_influences=max_weights,discarded_weight=0,materials=slots,bounds_inches=[[min(p[i] for p in positions) for i in range(3)],[max(p[i] for p in positions) for i in range(3)]],files=[dict(path=str(p.relative_to(REPO)),sha256=digest(p)) for p in (raw,binary)],blend=str(blend))
    (OUT/(perspective+'_geometry.json')).write_text(json.dumps(report,indent=2)+'\n')
    print(f'ASSEMBLED {perspective}: 51060 vertices, 59842 triangles, 76 bones; roundtrip passed',flush=True)


OUT.mkdir(parents=True,exist_ok=True)
for perspective in ('vm','wm'):
    build(perspective)
