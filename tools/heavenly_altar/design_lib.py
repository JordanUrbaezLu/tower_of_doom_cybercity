"""Editable altar construction in the isolated live Blender MCP session (9878)."""
import bpy, math, random, json, hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/heavenly_altar'
scene=bpy.context.scene
PREFIX='Altar | '

def material(name,col,metal=0,rough=.4,emission=0):
    name=PREFIX+name
    if bpy.data.materials.get(name):return bpy.data.materials[name]
    m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*col,1)
    n,l=m.node_tree.nodes,m.node_tree.links;b=n.get('Principled BSDF')
    b.inputs['Base Color'].default_value=(*col,1);b.inputs['Metallic'].default_value=metal;b.inputs['Roughness'].default_value=rough
    if emission:
        b.inputs['Emission Color'].default_value=(*col,1);b.inputs['Emission Strength'].default_value=emission
    else:
        tex=n.new('ShaderNodeTexNoise');tex.label='Fine ceramic and metal grain';tex.inputs['Scale'].default_value=90;tex.inputs['Detail'].default_value=3
        bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.12;bump.inputs['Distance'].default_value=.018;l.new(tex.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],b.inputs['Normal'])
        tex2=n.new('ShaderNodeTexNoise');tex2.label='Subtle finish variation';tex2.inputs['Scale'].default_value=6;tex2.inputs['Detail'].default_value=4
        ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(*(c*.72 for c in col),1);ramp.color_ramp.elements[1].color=(*col,1)
        l.new(tex2.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],b.inputs['Base Color'])
        ramp2=n.new('ShaderNodeMapRange');ramp2.inputs['To Min'].default_value=rough*.8;ramp2.inputs['To Max'].default_value=min(.85,rough*1.3)
        l.new(tex2.outputs['Fac'],ramp2.inputs[0]);l.new(ramp2.outputs[0],b.inputs['Roughness'])
    return m
ivory=material('ivory ceramic titanium',(.62,.65,.7),.32,.31)
ivory2=material('warm pearl enamel',(.82,.79,.69),.25,.28)
gold=material('brushed champagne gold',(.62,.36,.12),.83,.25)
goldlight=material('polished gold bevel',(.91,.65,.28),.82,.19)
dark=material('recessed graphite chassis',(.025,.028,.041),.75,.34)
steel=material('machined titanium',(.16,.19,.25),.82,.27)
black=material('panel seam rubber',(.009,.011,.022),.2,.55)
cyan=material('cyan optical conductor',(.025,.62,1),.25,.23,5)
violet=material('violet optical conductor',(.36,.012,1),.15,.24,5)
pink=material('rose violet edge',(.7,.055,1),.2,.24,4)
warm=material('divine warm light', (1,.62,.19),.2,.24,5)
white=material('white gold light',(1,.91,.66),.15,.24,7)
optic=material('midnight blue optic',(.012,.035,.10),.7,.2,.15)
etch=material('fine wear and engravings',(.13,.13,.15),.45,.48)

def collection(name):
    name=PREFIX+name
    c=bpy.data.collections.get(name)
    if not c:c=bpy.data.collections.new(name);scene.collection.children.link(c)
    return c
group='Structure'
def mesh(name,verts,faces,mat,bevel=0):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    ob=bpy.data.objects.new(name,me);collection(group).objects.link(ob);me.materials.append(mat);ob['altar_design']=True
    if bevel:
        me.materials.append(goldlight if mat in (gold,goldlight) else steel)
        m=ob.modifiers.new('Manufactured edge bevel','BEVEL');m.width=bevel;m.segments=3;m.material=1
        m=ob.modifiers.new('Weighted surface normals','WEIGHTED_NORMAL');m.keep_sharp=True
    return ob

def panel(name,points,y,depth,mat=ivory,bevel=.13):
    ps=[(float(x),float(z)) for x,z in points];N=len(ps)
    v=[(x,Y,z) for Y in (y,y+depth) for x,z in ps]
    # Front points may be clockwise or counter-clockwise; mesh normals are repaired below.
    fs=[tuple(range(N-1,-1,-1)),tuple(range(N,2*N))]+[(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)]
    ob=mesh(name,v,fs,mat,bevel)
    import bmesh
    bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
    return ob

def box(name,loc,dims,mat=dark,bevel=.1):
    x,y,z=loc;a,b,c=[d*.5 for d in dims]
    return panel(name,[(x-a,z-c),(x+a,z-c),(x+a,z+c),(x-a,z+c)],y-b,2*b,mat,bevel)

def tube(name,points,radius,mat,sides=8):
    pts=[Vector(p) for p in points];v=[]
    for i,p in enumerate(pts):
        t=pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]
        f=t.to_track_quat('Z','Y').to_matrix()
        v.extend(p+f@Vector((radius*math.cos(j*math.tau/sides),radius*math.sin(j*math.tau/sides),0)) for j in range(sides))
    fs=[tuple(range(sides-1,-1,-1)),tuple((len(pts)-1)*sides+j for j in range(sides))]
    for i in range(len(pts)-1):
        for j in range(sides):a=i*sides+j;b=i*sides+(j+1)%sides;fs.append((a,b,b+sides,a+sides))
    ob=mesh(name,v,fs,mat)
    for p in ob.data.polygons:p.use_smooth=len(p.vertices)==4
    return ob

def line(name,points,y,radius,mat):return tube(name,[(x,y,z) for x,z in points],radius,mat)
def outline(name,pts,y,radius,mat):return line(name,pts+[pts[0]],y,radius,mat)

def ring(name,x,z,y,radius,width,depth,mat=gold,start=0,end=math.tau,N=128):
    ps=[start+(end-start)*i/N for i in range(N+1)];v=[]
    for yy in (y,y+depth):
        for rr in (radius-width*.5,radius+width*.5):
            v.extend((x+rr*math.cos(a),yy,z+rr*math.sin(a)) for a in ps)
    k=N+1;fs=[]
    for i in range(N):fs.extend([(i,i+1,k+i+1,k+i),(2*k+i,3*k+i,3*k+i+1,2*k+i+1),(i,2*k+i,2*k+i+1,i+1),(k+i,k+i+1,3*k+i+1,3*k+i)])
    fs.extend([(0,k,3*k,2*k),(N,2*k+N,3*k+N,k+N)])
    return mesh(name,v,fs,mat,min(.07,width*.2) if width>.25 else 0)

def disc(name,x,z,y,r,depth,mat,N=64):
    return panel(name,[(x+r*math.cos(i*math.tau/N),z+r*math.sin(i*math.tau/N)) for i in range(N)],y,depth,mat,.07)

def bolt(name,x,z,y,r=.24):
    disc(name+' sunk socket',x,z,y,r*1.5,.1,black,12)
    disc(name+' hex head',x,z,y-.12,r,.17,steel,6)
    line(name+' slot',[(x-r*.45,z),(x+r*.45,z)],y-.14,.025,black)

def bevel_panel(name,pts,y,depth=1):
    panel(name+' gold backing',pts,y,depth,gold,.18)
    cx=sum(p[0] for p in pts)/len(pts);cz=sum(p[1] for p in pts)/len(pts)
    inner=[(cx+(x-cx)*.92,cz+(z-cz)*.89) for x,z in pts]
    panel(name+' ceramic face',inner,y-.22,.55,ivory,.14)
    return inner

def save(stage):
    scene['altar_stage']=stage;scene['altar_authoring']='Blender MCP execute_blender_code on isolated port 9878'
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'heavenly_altar_cyber.blend'))
    print('ALTAR_STAGE_SAVED',stage,'objects',sum(bool(o.get('altar_design')) for o in scene.objects),flush=True)

def camera(loc=(15,-255,83),target=(0,0,64),scale=146):
    ob=bpy.data.objects.get('Altar review camera')
    if not ob:
        data=bpy.data.cameras.new('Altar review camera');ob=bpy.data.objects.new('Altar review camera',data);scene.collection.objects.link(ob)
    scene.camera=ob;ob.location=loc;ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler();ob.data.type='ORTHO';ob.data.ortho_scale=scale;ob.data.clip_end=2000
    return ob

def live_view():
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                s=area.spaces.active;s.shading.type='MATERIAL';s.overlay.show_overlays=False;s.region_3d.view_perspective='CAMERA'

