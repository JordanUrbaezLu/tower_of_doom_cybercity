"""Check actual baked eye radiance and the strip's survival in every head LOD."""
import json, hashlib
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
def verify(folder):
    folder=Path(folder)
    manifest=json.loads((folder/'source_manifest.json').read_text())
    assert manifest['armored_helmet']['policy']=='executioner_enclosed_v1'
    scale=manifest['emission_scale']
    assert scale==16
    assert manifest['lod_preserve_largest']==['head']
    # Isolated bake uses _images; promoted inputs use the shared export folder.
    image_name='i_tod_roster_sprinter_e.png'
    image_path=folder/'_images'/image_name
    if not image_path.exists():
        image_path=ROOT/'model_export/tod_cyber_zombie/_images'/image_name
    assert hashlib.sha256(image_path.read_bytes()).hexdigest()==manifest['textures'][image_name]
    image=Image.open(image_path).convert('RGB');width,height=image.size
    def radiance(uv):
        rgb=image.getpixel((max(0,min(width-1,int(uv[0]*width))),max(0,min(height-1,int(uv[1]*height)))))
        def linear(byte):
            value=byte/255
            return value/12.92 if value<=.04045 else ((value+.055)/1.055)**2.4
        return tuple(linear(c)*scale for c in rgb)
    report=[]
    source=json.loads((folder/'head_lod0.json').read_text())
    neighbors={};by_vertex={}
    for index,face in enumerate(source['faces']):
        ids=[corner['v'] for corner in face]
        for vertex in ids:
            neighbors.setdefault(vertex,set()).update(ids)
            by_vertex.setdefault(vertex,set()).add(index)
    pending=set(neighbors);islands=[]
    while pending:
        todo=[pending.pop()];used=set(todo);face_ids=set()
        while todo:
            vertex=todo.pop();face_ids.update(by_vertex[vertex])
            for other in neighbors[vertex]:
                if other in pending:
                    pending.remove(other);used.add(other);todo.append(other)
        def area(face):
            a,b,c=[source['verts'][corner['v']] for corner in face]
            u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)]
            cross=(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])
            return sum(x*x for x in cross)**.5*.5
        islands.append((sum(area(source['faces'][i]) for i in face_ids),face_ids))
    shell=max(islands,key=lambda item:item[0])[1]
    def signature(data,face):
        return tuple((tuple(data['verts'][corner['v']]),tuple(corner['n']),tuple(corner['uv'])) for corner in face)
    shell_faces={signature(source,source['faces'][i]) for i in shell}
    for lod in range(7):
        data=json.loads((folder/('head_lod'+str(lod)+'.json')).read_text())
        assert shell_faces<={signature(data,face) for face in data['faces']},('enclosing helmet shell changed',lod)
        spans={key:[] for key in ('left_outer','left_inner','right_inner','right_outer')}
        for face in data['faces']:
            points=[data['verts'][corner['v']] for corner in face]
            center=[sum(p[i] for p in points)/3 for i in range(3)]
            if not (-3.95<center[0]<3.95 and center[1]<-3.0 and 65.48<center[2]<66.13):
                continue
            uv=[sum(corner['uv'][i] for corner in face)/3 for i in range(2)]
            rgb=radiance(uv)
            if rgb[0]<10 or max(rgb[1:])>1:
                continue
            x=center[0]
            key='left_outer' if x<-2.17 else ('left_inner' if x<0 else ('right_inner' if x<2.17 else 'right_outer'))
            spans[key].append(rgb[0])
        assert all(spans.values()),('eye strip lost or dimmed',lod,{k:len(v) for k,v in spans.items()})
        report.append({'lod':lod,'preserved_helmet_shell_triangles':len(shell_faces),'bright_eye_triangles':{k:len(v) for k,v in spans.items()},
                       'minimum_sampled_red_radiance':min(min(v) for v in spans.values())})
    return {'status':'PASS','native_material_emission_scale':scale,'emission_map_sha256':manifest['textures'][image_name],
            'head_lods':report,'type':'Actual source atlas/UV samples; native lighting and bloom require a playtest'}

if __name__=='__main__':
    import sys
    folder=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'art/cyber_reference_three_mcp/engine_kit'
    result=verify(folder)
    print('ARMORED_HELMET_BAKE_OK',json.dumps(result))
