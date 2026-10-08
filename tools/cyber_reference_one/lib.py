"""Reference-one modeling primitives. Run only inside the isolated MCP scene."""
import bpy, bmesh, math, json, hashlib, random
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/cyber_reference_one_mcp'
scene=bpy.context.scene
assert scene.get('reference_one_mcp'), 'Use 00_open.py in this task session first'
rig=bpy.data.objects['Cybercity_zombie_rig']
base=[o for o in scene.objects if o.type=='MESH' and 'attachment_bone' not in o and o.name!='Studio floor']
body=[o for o in base if 'body' in o.name.lower()]
heads=[o for o in base if 'head' in o.name.lower()]
parts=[];key='reference_one';measurements=[]

def signature(ob):
    return hashlib.sha256(repr(([tuple(v.co) for v in ob.data.vertices],[[ (g.group,g.weight) for g in v.groups] for v in ob.data.vertices],[tuple(p.vertices) for p in ob.data.polygons])).encode()).hexdigest()

def mat(name,color,kind='paint',emit=0):
    full='R1 | '+name
    old=bpy.data.materials.get(full)
    if old:return old
    m=bpy.data.materials.new(full);m.use_nodes=True;m.diffuse_color=(*color,1);m['surface_kind']=kind
    ns=m.node_tree.nodes;ln=m.node_tree.links;ns.clear()
    def node(t,n):
        x=ns.new(t);x.name=n;x.label=n;return x
    def noise(n,scale,detail=4,vec=None):
        x=node('ShaderNodeTexNoise',n);x.inputs['Scale'].default_value=scale;x.inputs['Detail'].default_value=detail;x.inputs['Roughness'].default_value=.72;ln.new(vec or pos,x.inputs['Vector']);return x.outputs['Fac']
    def ramp(n,s,stops):
        x=node('ShaderNodeValToRGB',n)
        for i,(p,c) in enumerate(stops):
            e=x.color_ramp.elements[i] if i<2 else x.color_ramp.elements.new(p);e.position=p;e.color=(*c,1)
        ln.new(s,x.inputs[0]);return x.outputs['Color']
    def mix(n,f,a,b):
        x=node('ShaderNodeMixRGB',n)
        for sock,v in zip(x.inputs,(f,a,b)):
            if hasattr(v,'node'):ln.new(v,sock)
            else:sock.default_value=(*v,1) if isinstance(v,tuple) else v
        return x.outputs[0]
    pos=node('ShaderNodeNewGeometry','Rest surface position').outputs['Position']
    macro=noise('Broad oily staining',.9,5)
    grain=noise('Forged micro surface',49,2)
    chips=noise('Chipped paint irregularity',3.1,5)
    oxide=ramp('Dark iron with brown oxidation',macro,[(.23,(.012,.009,.006)),(.6,(.075,.047,.023)),(.8,(.17,.095,.037))])
    coating=ramp('Uneven worn base coating',macro,[(.18,tuple(c*.32 for c in color)),(.57,color),(.82,tuple(c*.86 for c in color))])
    chipmask=ramp('Paint-break sharp boundary',chips,[(.51,(0,0,0)),(.555,(1,1,1))])
    col=mix('Flaked enamel into iron',chipmask,coating,oxide) if kind=='paint' else coating
    if kind=='metal':col=mix('Oil in damaged steel',.3,coating,oxide)
    stretch=node('ShaderNodeVectorMath','Directional wear');stretch.operation='MULTIPLY';stretch.inputs[1].default_value=(45,12,1.3);ln.new(pos,stretch.inputs[0])
    scratches=ramp('Fine rubbed scratches',noise('Abrasion',3.1,2,stretch.outputs[0]),[(.69,(0,0,0)),(.76,(.6,.6,.6))])
    col=mix('Exposed hairline scratches',scratches,col,(.14,.12,.09)) if kind in ('metal','paint') else col
    bs=node('ShaderNodeBsdfPrincipled','Principled BSDF');out=node('ShaderNodeOutputMaterial','Surface');ln.new(bs.outputs[0],out.inputs['Surface']);ln.new(col,bs.inputs['Base Color'])
    bs.inputs['Metallic'].default_value=.72 if kind=='metal' else .05
    rough=ramp('Grease versus dry oxide',macro,[(.2,(.37,)*3),(.75,(.81,)*3)])
    ln.new(rough,bs.inputs['Roughness'])
    bump=node('ShaderNodeBump','Paint edge and forging relief');bump.inputs['Strength'].default_value=.33;bump.inputs['Distance'].default_value=.024
    ln.new(mix('Micro relief plus peeling',.38,grain,chipmask),bump.inputs['Height']);ln.new(bump.outputs[0],bs.inputs['Normal'])
    if kind=='cloth':
        wave=node('ShaderNodeTexWave','Warp and weft');wave.wave_type='BANDS';wave.bands_direction='DIAGONAL';wave.inputs['Scale'].default_value=80;ln.new(pos,wave.inputs[0]);ln.new(wave.outputs[0],bump.inputs['Height']);bump.inputs['Distance'].default_value=.014;bs.inputs['Sheen Weight'].default_value=.25
    if kind=='rubber':bs.inputs['Roughness'].default_value=.68
    if emit:
        ln.new(ramp('Uneven phosphor',noise('Cell fluid filament',8,3),[(.2,tuple(c*.3 for c in color)),(.7,color)]),bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=emit
    return m

ivory=mat('chipped porcelain enamel',(.48,.455,.37))
steel=mat('oil-black iron',(.031,.032,.028),'metal')
edge=mat('rubbed steel',(.18,.16,.12),'metal')
web=mat('stained canvas harness',(.031,.027,.020),'cloth')
rubber=mat('cracked elastomer',(.009,.007,.005),'rubber')
magenta=mat('aged magenta pressure line',(.28,.010,.064),'rubber')
cyan=mat('cyan plasma inside glass',(.003,.48,.64),'light',2.0)
glass=mat('smoky blue optical glass',(.005,.033,.040),'metal',.15)
crack=mat('fractured optic filaments',(.02,.52,.72),'light',3.2)
amber=mat('amber pilot lamps',(.8,.21,.009),'light',2.2)
yellow=mat('faded yellow markings',(.42,.25,.028))
letter=mat('worn stencil paint',(.47,.46,.36),'rubber')

def attach(ob,name,mat,bone='j_spine4',bevel=0):
    assert bone in rig.data.bones,bone
    ob.name=name;ob.data.materials.append(mat);bpy.context.view_layer.objects.active=ob
    for v in ob.data.vertices:
        v.co.x*=ob.scale.x;v.co.y*=ob.scale.y;v.co.z*=ob.scale.z
    ob.scale=(1,1,1)
    if bevel:
        ob.data.materials.append(edge if mat.get('surface_kind') in ('paint','metal') else mat)
        mod=ob.modifiers.new('Radiused worn edges','BEVEL');mod.width=bevel;mod.segments=3;mod.material=1
        mod=ob.modifiers.new('Machined surface normals','WEIGHTED_NORMAL');mod.keep_sharp=True
    vg=ob.vertex_groups.new(name=bone);vg.add(list(range(len(ob.data.vertices))),1,'REPLACE')
    mod=ob.modifiers.new('Original joint','ARMATURE');mod.object=rig;ob.parent=rig
    ob['attachment_bone']=bone;ob['equipment_revision']=5;parts.append(ob);return ob

# Frozen, local surface-fitting primitives; no execution of the roster generator.
exec(compile((Path(__file__).parent/'surface_helpers.py').read_text(),str(Path(__file__).parent/'surface_helpers.py'),'exec'),globals())
surface=bvh(body);headsurface=bvh(heads)

# Direct mesh construction keeps the interactive session responsive as detail grows.
def box(name,loc,dims,mat=steel,bone='j_spine4',frame=None,bevel=.045):
    p=Vector(loc);f=frame or Matrix.Identity(3)
    vs=[p+f@Vector((x*dims[0]/2,y*dims[1]/2,z*dims[2]/2)) for z in (-1,1) for y in (-1,1) for x in (-1,1)]
    return mesh(name,vs,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],mat,bone,bevel)

def cyl(name,loc,radius,depth,mat=edge,bone='j_spine4',axis=(0,0,1),sides=24):
    p=Vector(loc);f=Vector(axis).to_track_quat('Z','Y').to_matrix()
    vs=[p+f@Vector((radius*math.cos(i*math.tau/sides),radius*math.sin(i*math.tau/sides),z)) for z in (-depth/2,depth/2) for i in range(sides)]
    fs=[tuple(range(sides-1,-1,-1)),tuple(range(sides,2*sides))]+[(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
    ob=mesh(name,vs,fs,mat,bone,min(.035,depth*.12))
    for face in ob.data.polygons:face.use_smooth=len(face.vertices)==4
    return ob

def tube(name,points,radius=.12,mat=magenta,bone='j_spine4',smooth=True):
    points=[Vector(p) for p in points];ps=[]
    if smooth:
        ext=[points[0]]+points+[points[-1]]
        for i in range(1,len(ext)-2):
            a,b,c,d=ext[i-1:i+3]
            for j in range(6):
                t=j/6;ps.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
        ps.append(points[-1])
    else:ps=points
    N=10;vs=[]
    for i,p in enumerate(ps):
        tangent=ps[min(i+1,len(ps)-1)]-ps[max(i-1,0)];f=tangent.to_track_quat('Z','Y').to_matrix()
        vs.extend(p+f@Vector((math.cos(j*math.tau/N)*radius,math.sin(j*math.tau/N)*radius,0)) for j in range(N))
    fs=[tuple(range(N-1,-1,-1)),tuple((len(ps)-1)*N+j for j in range(N))]
    for i in range(len(ps)-1):
        for j in range(N):a=i*N+j;b=i*N+(j+1)%N;fs.append((a,b,b+N,a+N))
    ob=mesh(name,vs,fs,mat,bone)
    for face in ob.data.polygons:face.use_smooth=len(face.vertices)==4
    return ob

def rod(name,a,b,r,mat=steel,bone='j_spine4',sides=20):
    a,b=Vector(a),Vector(b);return cyl(name,(a+b)/2,r,(b-a).length,mat,bone,b-a,sides)

def ring(name,p,n,r,thickness,mat=steel,bone='j_spine4'):
    p=Vector(p);f=Vector(n).to_track_quat('Z','Y').to_matrix();N=32;K=8
    vs=[p+f@Vector(((r+thickness*math.cos(j*math.tau/K))*math.cos(i*math.tau/N),(r+thickness*math.cos(j*math.tau/K))*math.sin(i*math.tau/N),thickness*math.sin(j*math.tau/K))) for i in range(N) for j in range(K)]
    fs=[(i*K+j,((i+1)%N)*K+j,((i+1)%N)*K+(j+1)%K,i*K+(j+1)%K) for i in range(N) for j in range(K)]
    ob=mesh(name,vs,fs,mat,bone)
    for face in ob.data.polygons:face.use_smooth=True
    return ob

def label(name,text,p,n,size=.20,bone='j_spine4',up=(0,0,1),mat=letter):
    # Text is actual flush geometry and survives the editable scene, unlike a UI overlay.
    r,n,u,f=basis(n,Vector(up));cu=bpy.data.curves.new(name,'FONT');cu.body=text;cu.size=size;cu.align_x='CENTER';cu.extrude=.001;cu.resolution_u=2
    ob=bpy.data.objects.new(name,cu);scene.collection.objects.link(ob);ob.location=p
    ob.rotation_euler=Matrix((-r,u,n)).transposed().to_euler()
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob;bpy.ops.object.convert(target='MESH')
    result=attach(bpy.context.object,name,mat,bone);result['label_text']=text;result['label_basis_correct']=True
    return result

def hose(name,points,r=.18,mat=magenta,bone='j_spine4',ribbed=True):
    ob=tube(name,points,r,mat,bone,True)
    # Rings are hose reinforcement / molded ribs, not a flat pink curve.
    if ribbed:
        for a,b in zip(points[:-1],points[1:]):
            a,b=Vector(a),Vector(b);length=(b-a).length
            for k in range(max(1,int(length/.30))):
                t=(k+.5)/max(1,int(length/.30))
                # Only straight middle portions get ribs; curved corners stay flexible.
                if .20<t<.80:ring(name+' reinforcement',a.lerp(b,t),b-a,r*1.005,.027,steel,bone)
    for a,b in ((Vector(points[0]),Vector(points[1])),(Vector(points[-1]),Vector(points[-2]))):
        direction=(a-b).normalized();cyl(name+' compression coupling',a,r*1.6,.28,edge,bone,direction,12);ring(name+' gasket',a-direction*.16,direction,r*1.24,.038,rubber,bone)
    return ob

def piston(name,a,b,r=.17,bone='j_spine4'):
    a,b=Vector(a),Vector(b);mid=a.lerp(b,.54)
    rod(name+' outer housing',a,mid,r*1.5,steel,bone)
    rod(name+' polished actuator',mid,b,r*.70,edge,bone)
    ring(name+' wiper seal',mid,b-a,r*1.17,.045,rubber,bone)
    for p in (a,b):cyl(name+' pivot',p,r*1.7,r*2.2,steel,bone,(1,0,0),16)

def cartridge(name,p,n,r=.65,h=4,bone='j_spine4',up=Vector((0,0,1))):
    p=Vector(p);right,n,u,f=basis(n,up)
    cyl(name+' inner light',p,r*.77,h*.66,cyan,bone,u,28)
    # Split transparent chamber slats leave the light behind grime-dark vertical ribs.
    for dz in (-h*.46,h*.46):
        cyl(name+' locking cap',p+u*dz,r*1.08,h*.15,ivory,bone,u,24)
        ring(name+' seal',p+u*dz*.80,u,r*.99,.065,rubber,bone)
        ring(name+' chrome retaining ring',p+u*dz*.88,u,r*1.06,.045,edge,bone)
    for ang in (-1.05,1.05,2.1,4.2):
        d=right*math.sin(ang)+n*math.cos(ang)
        rod(name+' cage rod',p+d*r-u*h*.39,p+d*r+u*h*.39,.08,steel,bone)
    for z in (-.22,0,.22):
        box(name+' calibration mark',p+n*r*.79+right*r*.18+u*h*z,(r*.30,.023,.033),letter,bone,f,.004)
    for z in (-.46,.46):
        for s in (-1,1):bolt(name+' cap captive screw',p+u*h*z+right*r*s*.72+n*r*.88,n,bone,.09)
    label(name+' voltage stencil','115',p+u*h*.46+n*r*1.10,n,r*.27,bone,u)
    return p+u*h*.58

def save(stage):
    scene['reference_one_stage']=stage;bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'reference_one.blend'))
    print('REFERENCE_ONE_STAGE_OK',stage,'objects',sum('attachment_bone' in o for o in scene.objects))

def camera(loc,target,scale):
    c=scene.camera;c.location=loc;c.rotation_euler=(Vector(target)-c.location).to_track_quat('-Z','Y').to_euler();c.data.type='ORTHO';c.data.ortho_scale=scale
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                space=area.spaces.active;space.region_3d.view_perspective='CAMERA';space.overlay.show_overlays=False;space.shading.type='MATERIAL'
