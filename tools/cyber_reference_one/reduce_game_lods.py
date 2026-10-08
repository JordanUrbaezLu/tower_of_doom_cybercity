"""Reduce native LOD0 per connected part, preserving flat faces and closed shells.

Run in background Blender. Output is isolated until the installer is rerun.
No rebake: all UVs and material samples originate in the verified LOD0.
"""
import bpy,bmesh,json,math,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/cyber_reference_one'))
from native_geometry import clean
SRC=Path(globals().get('CYBER_LOD_SOURCE',ROOT/'art/cyber_zombie_mvp/engine_kit'))
OUT=Path(globals().get('CYBER_LOD_OUTPUT',ROOT/'tmp/reference_one_reduced_lods'))
OUT.mkdir(parents=True,exist_ok=True)
AREA_FLOORS=globals().get('CYBER_LOD_AREA_FLOORS',{})
PRESERVE_LARGEST=set(globals().get('CYBER_LOD_PRESERVE_LARGEST',()))
bpy.ops.wm.read_factory_settings(use_empty=True)
counts={'0':json.loads((SRC/'lod_counts.json').read_text())['0']}
for lod in range(1,7):counts[str(lod)]={}
for group in counts['0']:
    data=json.loads((SRC/(group+'_lod0.json')).read_text())
    # Work from actual native corners, retaining the original UV and split normals.
    neighbors={};byvertex={}
    for i,face in enumerate(data['faces']):
        ids=[c['v'] for c in face]
        for v in ids:
            neighbors.setdefault(v,set()).update(ids)
            byvertex.setdefault(v,set()).add(i)
    pending=set(neighbors);islands=[]
    from mathutils import Vector
    while pending:
        seed=pending.pop();todo=[seed];verts={seed};faces=set()
        while todo:
            v=todo.pop();faces.update(byvertex[v])
            for other in neighbors[v]:
                if other in pending:pending.remove(other);verts.add(other);todo.append(other)
        area=0
        for i in faces:
            p,q,r=[Vector(data['verts'][c['v']]) for c in data['faces'][i]]
            area+=(q-p).cross(r-p).length*.5
        islands.append((area,verts,sorted(faces)))
    largest=max(islands,key=lambda item:item[0])
    for lod,ratio in enumerate((1,.55,.28,.14,.075,.04,.022)):
        if lod==0:continue
        result={'bone':data['bone'],'verts':[],'faces':[]}
        for island in islands:
            area,vertices,faces=island
            floor=AREA_FLOORS.get(group,(0,.025,.18,.60,1.5,3.5,7))[lod]
            if area<floor and island is not largest:continue
            # Flat plates and short closed shells stay intact. Decimating a whole
            # kit lets a two-triangle screen disappear to pay for an unseen bolt.
            if len(faces)<=24 or (group in PRESERVE_LARGEST and island is largest):
                remap={v:len(result['verts'])+i for i,v in enumerate(sorted(vertices))}
                result['verts'].extend(data['verts'][v] for v in sorted(vertices))
                result['faces'].extend([{**c,'v':remap[c['v']]} for c in data['faces'][i]] for i in faces)
                continue
            ordered=sorted(vertices);remap={v:i for i,v in enumerate(ordered)}
            me=bpy.data.meshes.new('reduce')
            me.from_pydata([data['verts'][v] for v in ordered],[],[[remap[data['faces'][i][j]['v']] for j in (0,2,1)] for i in faces])
            me.update();uv=me.uv_layers.new();normals=[]
            for poly,fi in zip(me.polygons,faces):
                poly.use_smooth=True
                for li,j in zip(poly.loop_indices,(0,2,1)):
                    corner=data['faces'][fi][j];uv.data[li].uv=(corner['uv'][0],1-corner['uv'][1]);normals.append(corner['n'])
            me.normals_split_custom_set(normals)
            ob=bpy.data.objects.new('reduce',me);bpy.context.scene.collection.objects.link(ob)
            bpy.context.view_layer.objects.active=ob;ob.select_set(True)
            mod=ob.modifiers.new('Keep component silhouette','DECIMATE')
            mod.ratio=max(ratio,24/len(faces));mod.use_collapse_triangulate=True
            bpy.ops.object.modifier_apply(modifier=mod.name)
            me=ob.data;me.calc_loop_triangles();offset=len(result['verts'])
            result['verts'].extend(list(v.co) for v in me.vertices)
            for tri in me.loop_triangles:
                if tri.area<1e-9:continue
                corners=[]
                for li in (tri.loops[0],tri.loops[2],tri.loops[1]):
                    n=me.corner_normals[li].vector.normalized()
                    if n.length_squared<.9:n=tri.normal.normalized()
                    assert n.length_squared>.9
                    u,v=me.uv_layers.active.data[li].uv
                    corners.append({'v':offset+me.loops[li].vertex_index,'n':list(n),'uv':[u,1-v]})
                result['faces'].append(corners)
            bpy.data.objects.remove(ob,do_unlink=True)
            bpy.data.meshes.remove(me)
        clean(result)
        (OUT/(group+'_lod'+str(lod)+'.json')).write_text(json.dumps(result,separators=(',',':')))
        counts[str(lod)][group]=len(result['faces'])
    print('REFERENCE_ONE_COMPONENT_LODS',group,flush=True)
(OUT/'lod_counts.json').write_text(json.dumps(counts,indent=2)+'\n')
print('REFERENCE_ONE_DISTANCE_TOTALS',{k:sum(v.values()) for k,v in counts.items()},flush=True)
