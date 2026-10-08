"""Rebuild cyber equipment from the user's three September 16 design sheets.

Blender --background --python-exit-code 1 --python this.py -- <roster-id|mvp>
Only the equipment changes. Revision-3 donor masters are kept as immutable inputs.
"""
import bpy, bmesh, sys, json, math, shutil, hashlib, random
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1]; ART=ROOT/'art/cyber_zombie_roster'
args=sys.argv[sys.argv.index('--')+1:]; key=args[0]
entry=next((e for e in json.loads((ART/'roster.json').read_text())['models'] if e['id']==key),None)
style=entry['style'] if entry else 'crown'
design=3 if style=='relay' else 2 if style in ('trooper','sprinter') else 1
master=ART/key/(key+'.blend') if entry else ROOT/'art/cyber_zombie_mvp/cyber_zombie_mvp.blend'
backup=ROOT/'tmp/cyber_finish_v3'/master.relative_to(ROOT); backup.parent.mkdir(parents=True,exist_ok=True)
if not backup.exists():shutil.copy2(master,backup)
bpy.ops.wm.open_mainfile(filepath=str(backup)); scene=bpy.context.scene
assert scene.get('cyber_finish_revision')==3
rig=bpy.data.objects['Cybercity_zombie_rig']
for pb in rig.pose.bones:pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0)
bpy.context.view_layer.update()
for ob in list(scene.objects):
    if 'attachment_bone' in ob:bpy.data.objects.remove(ob,do_unlink=True)
base=[o for o in scene.objects if o.type=='MESH' and o.name!='Studio floor']
body=[o for o in base if 'body' in o.name.lower() or o.get('source_asset','').startswith('c_t8')]
heads=[o for o in base if 'head' in o.name.lower()]
def signature(ob):
    return hashlib.sha256(repr(([tuple(v.co) for v in ob.data.vertices],
        [[(g.group,g.weight) for g in v.groups] for v in ob.data.vertices],
        [tuple(p.vertices) for p in ob.data.polygons])).encode()).hexdigest()
donors={o.name:signature(o) for o in base};parts=[];measurements=[]

def material(name,base,kind='paint',emission=0):
    m=bpy.data.materials.new('REF4 | '+name);m.use_nodes=True
    ns=m.node_tree.nodes;ls=m.node_tree.links;ns.clear()
    def node(t,name):
        n=ns.new(t);n.name=name;n.label=name;return n
    def linkvalue(s,v):
        if hasattr(v,'node'):ls.new(v,s)
        else:s.default_value=(*v,1) if isinstance(v,tuple) else v
    def ramp(name,v,colors,positions):
        n=node('ShaderNodeValToRGB',name)
        for i,(c,p) in enumerate(zip(colors,positions)):
            e=n.color_ramp.elements[i] if i<2 else n.color_ramp.elements.new(p)
            e.position=p;e.color=(*c,1)
        ls.new(v,n.inputs[0]);return n.outputs['Color']
    def mix(name,f,a,b,mode='MIX'):
        n=node('ShaderNodeMixRGB',name);n.blend_type=mode
        for s,v in zip(n.inputs,(f,a,b)):linkvalue(s,v)
        return n.outputs[0]
    coord=node('ShaderNodeNewGeometry','World rest coordinates').outputs['Position']
    def noise(name,scale,detail=3,vector=coord):
        n=node('ShaderNodeTexNoise',name);ls.new(vector,n.inputs['Vector']);n.inputs['Scale'].default_value=scale
        n.inputs['Detail'].default_value=detail;n.inputs['Roughness'].default_value=.72;return n.outputs['Fac']
    macro=noise('Uneven dirt deposits',.68,4);pits=noise('Paint fractures',7,3);grain=noise('Pitted metal grain',36,2)
    mottled=ramp('Stained coating',macro,[tuple(x*.22 for x in base),base,tuple(min(.85,x*1.55) for x in base)],[.22,.52,.77])
    chips=ramp('Irregular worn-through islands',pits,[(0,)*3,(1,)*3],[.55,.68])
    rust=ramp('Dark oxide and exposed substrate',macro,[(.018,.013,.009),(.105,.048,.014),(.24,.20,.12)],[.30,.55,.76])
    color=mix('Peeling coating',chips,mottled,rust) if kind=='paint' else mottled
    if kind in ('paint','metal'):
        broad=ramp('Large accumulated oxide patches',noise('Corrosion under flaking paint',1.9,5),[(0,)*3,(.8,)*3],[.49,.68])
        color=mix('Patchy brown oxidation',broad,color,(.033,.020,.008))
    # Elongated scratches, distinct from broad paint damage and small pits.
    stretch=node('ShaderNodeVectorMath','Long abrasion direction');stretch.operation='MULTIPLY';ls.new(coord,stretch.inputs[0]);stretch.inputs[1].default_value=(22,22,1.1)
    scratches=ramp('Fine directional abrasions',noise('Scratched surface',2,2,stretch.outputs[0]),[(0,)*3,(1,)*3],[.66,.72])
    color=mix('Rubbed scratch edges',scratches,color,(.17,.15,.11))
    bs=node('ShaderNodeBsdfPrincipled','Principled BSDF');out=node('ShaderNodeOutputMaterial','Material Output');ls.new(bs.outputs[0],out.inputs[0]);ls.new(color,bs.inputs['Base Color'])
    rough=ramp('Dry grime and polished contact spots',macro,[(.48,)*3,(.89,)*3],[.2,.75]);ls.new(rough,bs.inputs['Roughness'])
    bs.inputs['Metallic'].default_value=.65 if kind=='metal' else .1 if kind=='paint' else 0
    if kind=='paint':ls.new(ramp('Exposed conductive substrate',chips,[(.05,)*3,(.7,)*3],[0,1]),bs.inputs['Metallic'])
    relief=mix('Flaking paint relief',.40,grain,pits,'MULTIPLY')
    if kind=='cloth':
        w=node('ShaderNodeTexWave','Woven strap fibers');w.wave_type='BANDS';w.bands_direction='DIAGONAL';w.inputs['Scale'].default_value=46;ls.new(coord,w.inputs[0]);relief=w.outputs['Fac'];bs.inputs['Sheen Weight'].default_value=.22
    bump=node('ShaderNodeBump','Surface erosion');bump.inputs['Strength'].default_value=.45;bump.inputs['Distance'].default_value=.032;ls.new(relief,bump.inputs['Height']);ls.new(bump.outputs[0],bs.inputs['Normal'])
    if emission:
        glow=ramp('Dirty phosphor with uneven brightness',pits,[tuple(v*.08 for v in base),base],[.28,.66]);ls.new(glow,bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=emission
        bs.inputs['Roughness'].default_value=.4
    m.diffuse_color=(*base,1);m['surface_kind']=kind;return m

ivory=material('chipped bone-white enamel',(.44,.41,.32))
steel=material('oiled blackened steel',(.044,.042,.032),'metal')
edge=material('abraded steel edge',(.17,.145,.10),'metal')
web=material('filthy woven harness',(.035,.030,.020),'cloth')
rubber=material('aged rubber seals',(.012,.010,.008),'rubber')
magenta=material('worn magenta hose jacket',(.26,.012,.075),'rubber')
cyan=material('scuffed cyan cell',(.005,.55,.70),'glass',3.2)
glass=material('dark cyan optical shield',(.006,.065,.072),'glass',.35)
crack=material('cyan fractured optic filament',(.03,.65,.80),'glass',5.5)
amber=material('amber pilot lights',(.8,.23,.008),'glass',3.2)
yellow=material('faded hazard ochre',(.38,.22,.024))

def attach(ob,name,mat,bone='j_spine4',bevel=0):
    assert bone in rig.data.bones,bone
    ob.name=name;ob.data.materials.append(mat);bpy.context.view_layer.objects.active=ob
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        ob.data.materials.append(edge if mat.get('surface_kind') in ('paint','metal') else mat)
        mod=ob.modifiers.new('Worn bevel exposing substrate','BEVEL');mod.width=bevel;mod.segments=1;mod.material=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=ob.modifiers.new('Hard-surface normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
    vg=ob.vertex_groups.new(name=bone);vg.add(list(range(len(ob.data.vertices))),1,'REPLACE')
    mod=ob.modifiers.new('Original joint','ARMATURE');mod.object=rig;ob.parent=rig
    ob['attachment_bone']=bone;ob['equipment_revision']=4;parts.append(ob);return ob
def mesh(name,verts,faces,mat,bone='j_spine4',bevel=0):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    ob=bpy.data.objects.new(name,me);scene.collection.objects.link(ob);return attach(ob,name,mat,bone,bevel)
def box(name,loc,dims,mat=steel,bone='j_spine4',frame=None,bevel=.045):
    bpy.ops.object.select_all(action='DESELECT');bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    ob=bpy.context.object;ob.dimensions=dims
    if frame is not None:ob.rotation_euler=frame.to_euler()
    return attach(ob,name,mat,bone,bevel)
def cyl(name,loc,radius,depth,mat=edge,bone='j_spine4',axis=(0,0,1),sides=12):
    bpy.ops.object.select_all(action='DESELECT');bpy.ops.mesh.primitive_cylinder_add(vertices=sides,radius=radius,depth=depth,location=loc)
    ob=bpy.context.object;ob.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    for p in ob.data.polygons:p.use_smooth=len(p.vertices)==4
    return attach(ob,name,mat,bone,min(.035,depth*.12))
def tube(name,points,radius=.12,mat=magenta,bone='j_spine4',smooth=True):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=5;cu.bevel_depth=radius;cu.bevel_resolution=1
    sp=cu.splines.new('BEZIER' if smooth else 'POLY')
    if smooth:
        sp.bezier_points.add(len(points)-1)
        for p,co in zip(sp.bezier_points,points):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    else:
        sp.points.add(len(points)-1)
        for p,co in zip(sp.points,points):p.co=(*co,1)
    ob=bpy.data.objects.new(name,cu);scene.collection.objects.link(ob)
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob;bpy.ops.object.convert(target='MESH')
    return attach(bpy.context.object,name,mat,bone)
def basis(n,up=Vector((0,0,1))):
    n=Vector(n).normalized();u=(Vector(up)-n*Vector(up).dot(n)).normalized();r=n.cross(u).normalized()
    return r,n,u,Matrix((r,n,u)).transposed()
def bolt(name,p,n,bone='j_spine4',r=.13):
    p=Vector(p);n=Vector(n);cyl(name+' washer',p,r*1.35,.045,rubber,bone,n)
    cyl(name+' hex head',p+n*.065,r,.10,edge,bone,n,6)
    right,_,up,frame=basis(n)
    box(name+' recessed slot',p+n*.122,(r*1.1,.012,.026),rubber,bone,frame,.003)
def panel(name,p,n,width,height,bone='j_spine4',mat=ivory,up=Vector((0,0,1)),depth=.22,fasteners=True):
    p=Vector(p);r,n,u,frame=basis(n,up)
    # Asymmetric manufactured outline: cut corners, slightly tapered lower edge.
    shape=[(-.48,-.34),(-.37,-.50),(.31,-.50),(.48,-.35),(.50,.36),(.34,.50),(-.36,.50),(-.5,.33)]
    vs=[p+r*x*width+u*z*height+n*d for d in (0,depth) for x,z in shape]
    fs=[tuple(range(7,-1,-1)),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
    mesh(name,vs,fs,mat,bone,.035)
    if fasteners:
        for x,z in [(-.33,-.32),(.33,-.32),(-.33,.32),(.33,.32)]:bolt(name,p+r*x*width+u*z*height+n*(depth+.02),n,bone,min(.13,width*.075))
    return p+n*depth,r,n,u,frame
def bvh(objects,accept=None):
    vs=[];fs=[]
    for ob in objects:
        offset=len(vs);coords=[ob.matrix_world@v.co for v in ob.data.vertices];vs.extend(coords)
        for poly in ob.data.polygons:
            center=sum((coords[i] for i in poly.vertices),Vector())/len(poly.vertices)
            if accept is None or accept(center):fs.append(tuple(offset+i for i in poly.vertices))
    assert fs;return BVHTree.FromPolygons(vs,fs)
surface=bvh(body);headsurface=bvh(heads)
def skin(x,z,back=False,gap=.12):
    p,n,idx,d=surface.ray_cast(Vector((x,24 if back else -24,z)),Vector((0,-1 if back else 1,0)),48)
    assert p is not None,('no torso surface',key,x,z,back)
    return p+Vector((0,gap if back else -gap,0))
def torso_panel(name,x,z,w,h,back=False,mat=ivory):
    n=Vector((0,1 if back else -1,0));p=skin(x,z,back,.16)
    # Rigid plate bridges the measured cloth relief instead of intersecting it.
    hits=[skin(x+dx*w,z+dz*h,back,.13) for dx in (-.42,0,.42) for dz in (-.4,0,.4)]
    p.y=(max(v.y for v in hits) if back else min(v.y for v in hits))
    box(name+' padded backing',p-n*.06,(w*.94,.18,h*.94),web)
    return panel(name,p,n,w,h,mat=mat)
def cell(name,p,n,r=.65,h=4,bone='j_spine4',up=Vector((0,0,1))):
    p=Vector(p);right,n,u,frame=basis(n,up)
    cyl(name+' recessed cylinder',p,r*.64,h,steel,bone,u)
    cyl(name+' cyan energy chamber',p+n*.04,r*.82,h*.66,cyan,bone,u)
    for dz in (-h*.48,h*.48):
        cyl(name+' heavy end cap',p+u*dz,r*1.12,h*.14,ivory,bone,u)
        cyl(name+' collar gasket',p+u*(dz*.77),r*1.06,.14,rubber,bone,u)
        cyl(name+' locking ring',p+u*(dz*.85),r*1.09,.10,edge,bone,u)
    for dx in (-r*.84,r*.84):
        box(name+' protective spine',p+right*dx+n*r*.49,(.13,.17,h*.86),steel,bone,frame,.025)
        for dz in (-h*.34,h*.34):bolt(name+' cage screw',p+right*dx+u*dz+n*r*.6,n,bone,.085)
    for dz in (-.23,0,.23):
        box(name+' calibration tick',p+n*r*.9+u*(h*dz)+right*r*.37,(.19,.045,.055),edge,bone,frame,.005)
    cyl(name+' hose socket',p+u*(h*.62),r*.48,h*.14,edge,bone,u)
    cyl(name+' hose socket dark insert',p+u*(h*.70),r*.34,.08,rubber,bone,u)
    return p+u*(h*.68)

# Harness straps conform to each body's measured clothes, including their torn folds.
for sx in (-1,1):
    zs=[47.0+i*.52 for i in range(23)];width=.82;verts=[]
    ys=[min(skin(sx*(3.5+(z-44.5)*.09)+dx,z,False,.14).y for dx in (-width/2,0,width/2)) for z in zs]
    # Sewn webbing bridges small cloth folds instead of copying every torn triangle.
    ys=[min(ys[max(0,i-1):min(len(ys),i+2)]) for i in range(len(ys))]
    for gap in (.14,.25):
        for row,z in enumerate(zs):
            x=sx*(3.5+(z-44.5)*.09)
            for dx in (-width/2,width/2):verts.append(Vector((x+dx,ys[row]-(gap-.14),z)))
    count=len(zs)*2;faces=[]
    for offset in (0,count):
        for j in range(len(zs)-1):a=offset+j*2;faces.append((a,a+1,a+3,a+2))
    for j in range(len(zs)-1):
        for side in (0,1):a=j*2+side;faces.append((a,a+2,a+2+count,a+count))
    mesh('Harness | fitted shoulder webbing',verts,faces,web)
    for z in (47.5,54.7,57.5):
        x=sx*(3.5+(z-44.5)*.09);p=skin(x,z,False,.36)
        panel('Harness | riveted buckle',p,(0,-1,0),1.15,1.30,mat=steel,depth=.15)
        tube('Harness | buckle tongue',[p+Vector((-.34,-.19,0)),p+Vector((.34,-.19,0))],.065,edge,smooth=False)

if design==1:
    p,r,n,u,f=torso_panel('Chest | ECG control console',0,52.0,5.0,2.5)
    box('Chest | recessed cyan monitor',p+n*.09,(3.25,.09,1.45),glass,frame=f)
    for i in range(4):
        pts=[p+n*.16+r*(-1.42+j*.16)+u*(.22*math.sin(j*1.3+i)+(-.35+i*.23)) for j in range(19)]
        tube('Chest | waveform etching',pts,.015,cyan,smooth=False)
    for sx in (-1,1):
        tube('Chest | protected return conduit',[p+r*sx*1.7,p+r*sx*1.5-u*1.8+n*.3,p+r*sx*.45-u*1.8+n*.4],.16,rubber)
    p,r,n,u,f=torso_panel('Back | spinal battery cradle',0,52.5,3.3,9,True,steel)
    cell('Back | spine reactor',p+n*.75,n,.79,6.8)
elif design==2:
    for sx in (-1,1):
        p,r,n,u,f=torso_panel('Chest | twin reactor frame',sx*3.5,53.0,2.5,6.8,mat=steel)
        inlet=cell('Chest | twin cyan reactor',p+n*.82,n,.72,5.7)
        shoulder=skin(sx*4.5,58.8,False,.50)
        tube('Chest | upper reactor supply',[inlet,inlet+u*.70+Vector((sx*.4,0,0)),shoulder,skin(sx*4.5,58.8,True,.50)],.19)
        tube('Chest | magenta pressure return',[p+n*.7-u*2.8,p+n*.5-u*3.9+r*sx,p+n*.2-u*3.5+r*sx*2],.19)
    p,r,n,u,f=torso_panel('Back | armored spinal unit',0,51.5,4.0,8.2,True)
    for dz in (-2,-.7,.6,1.9):
        box('Back | vent gasket',p+n*.12+u*dz,(2.65,.14,.60),rubber,frame=f)
        box('Back | cyan vent core',p+n*.21+u*dz,(2.05,.09,.27),cyan,frame=f)
    if style!='sprinter':cell('Back | upper spinal antenna cell',skin(0,60,True,.7),(0,1,0),.63,3.1)
else:
    p,r,n,u,f=torso_panel('Back | industrial twin tank frame',0,52.5,6.4,8.7,True,steel)
    for sx in (-1,1):
        cp=p+r*sx*1.55+n*1.1;cell('Back | industrial cyan reservoir',cp,n,1.05,7.5)
        face=cp-u*2.7+n*.99
        panel('Back | hazard service cover',face,n,1.65,1.8,mat=ivory,depth=.08,fasteners=False)
        for off in (-.44,.18):
            poly=[face+r*(off+dx)+u*dz+n*.10 for dx,dz in [(-.16,-.68),(.10,-.68),(.54,.65),(.28,.65)]]
            mesh('Back | worn diagonal hazard stripe',poly,[(0,1,2,3)],yellow)
    p,r,n,u,f=torso_panel('Chest | industrial status tag',3.9,55.7,1.35,1.9,mat=steel)
    box('Chest | amber status window',p+n*.07,(.65,.08,.85),amber,frame=f)

for sx in (-1,1):
    # This conduit stays entirely on the torso so neck turns cannot tear it.
    points=[skin(sx*x,z,True,.5) for x,z in [(1.6,55.2),(3.4,56.0),(4.4,58.0),(4.5,59.0)]]
    tube('Back | magenta shoulder umbilical',points,.23)
    for p in (points[0],points[-1]):cyl('Back | hose compression coupling',p,.31,.38,edge)

def limb(b0,b1,objects=body):
    a=rig.matrix_world@rig.data.bones[b0].head_local;b=rig.matrix_world@rig.data.bones[b1].head_local
    axis=(b-a).normalized();length=(b-a).length
    front=Vector((0,-1,.15));front=(front-axis*front.dot(axis)).normalized();side=front.cross(axis).normalized()
    if b0.endswith('_ri'):side=-side
    def accept(p):
        d=p-a;t=d.dot(axis)/length;return -.22<t<1.22 and (d-axis*d.dot(axis)).length<6.2
    tree=bvh(objects,accept);radii=[]
    def radius_at(t,angle):
        c=a.lerp(b,t);direction=front*math.cos(angle)+side*math.sin(angle)
        p,n,idx,dist=tree.ray_cast(c+direction*9,-direction,9)
        return (p-c).dot(direction) if p is not None else None
    def point(t,angle,gap=.1):
        c=a.lerp(b,t);direction=front*math.cos(angle)+side*math.sin(angle)
        radius=radius_at(t,angle)
        if radius is None or radius<.30:
            # Torn cloth has actual holes. Bridge only the missing angular span
            # from its measured rims; never ray through to the opposite wall.
            rims=[]
            for sign in (-1,1):
                for step in range(1,21):
                    r=radius_at(t,angle+sign*step*math.pi/40)
                    if r is not None and r>=.30:rims.append((r,step));break
            assert len(rims)==2,('no measured rims around donor tear',key,b0,t,angle)
            radius=(rims[0][0]*rims[1][1]+rims[1][0]*rims[0][1])/(rims[0][1]+rims[1][1])
        assert .29<radius<7,(b0,radius)
        radii.append(radius);return c+direction*(radius+gap),direction
    return a,b,axis,length,front,side,point,radii
def strap(name,point,t,width,length,bone):
    # Two closed bands; inner vertices follow the donor mesh independently.
    N=40;vs=[]
    for gap in (.08,.19):
        for row in (-.5,0,.5):
            for j in range(N):vs.append(point(t+row*width/length,j*math.tau/N,gap)[0])
    fs=[];count=3*N
    for layer in (0,count):
        for row in range(2):
            for j in range(N):a=layer+row*N+j;b=layer+row*N+(j+1)%N;fs.append((a,b,b+N,a+N))
    for row in (0,2):
        for j in range(N):a=row*N+j;b=row*N+(j+1)%N;fs.append((a,b,b+count,a+count))
    mesh(name,vs,fs,web,bone)
def limb_kit(side,leg=False):
    bone=('j_knee_' if leg else 'j_elbow_')+side
    target=('j_ankle_' if leg else 'j_wrist_')+side
    a,b,axis,length,front,right,point,radii=limb(bone,target)
    start,end=(.18,.83) if leg else (.21,.78)
    for t in (start,end):strap(('Shin' if leg else 'Forearm')+' | fitted retaining strap',point,t,.62,length,bone)
    # Tangent chassis remains above the complete sampled front surface.
    center=(start+end)*.5
    startp=point(start,0,.20)[0];endp=point(end,0,.20)[0]
    kit_axis=(endp-startp).normalized()
    normal=(front-kit_axis*front.dot(kit_axis)).normalized()
    p=(startp+endp)*.5
    lift=max((point(t,angle,.20)[0]-p).dot(normal) for t in (start,center,end) for angle in (-.35,0,.35))
    p+=normal*lift
    w=2.5 if leg else 2.05;h=(endp-startp).length
    p,r,n,u,f=panel(('Shin' if leg else 'Forearm')+' | articulated chassis',p,normal,w,h,bone,steel,kit_axis,depth=.24)
    for t in (start,end):
        hit,d=point(t,0,.20);seat=p-n*.24+u*((t-center)/(end-start)*h)
        depth=(seat-hit).dot(n)
        if depth>.08:
            box('Brace | fitted padded mounting pedestal',hit+n*(depth*.5),(.90,depth,.55),rubber,bone,f,.045)
            panel('Brace | strap-mounted anchor',hit,n,1.05,.65,bone,steel,u,depth=.1,fasteners=False)
    cell(('Shin' if leg else 'Forearm')+' | shielded cyan cartridge',p+n*.51,n,.39 if leg else .37,h*.73,bone,u)
    for sx in (-1,1):
        plate=p+r*sx*w*.40+n*.07
        panel(('Shin' if leg else 'Forearm')+' | chipped side armor',plate,n,w*.31,h*.89,bone,ivory,u,depth=.22,fasteners=False)
        for dz in (-h*.35,h*.35):bolt('Brace | cage pin',plate+u*dz+n*.25,n,bone,.1)
    pts=[p-r*w*.60-u*h*.31+n*.25,p-r*w*.69+n*.19,p-r*w*.60+u*h*.38+n*.25]
    tube('Brace | magenta pressure hose',pts,.135,magenta,bone)
    for t in (start,end):
        hit,d=point(t,.68,.27);bolt('Brace | strap rivet',hit,d,bone)
    if leg:
        hit,d=point(.07,0,.22)
        panel('Knee | segmented protective cup',hit,d,3.0,2.45,bone,ivory,axis,depth=.35)
        for sign in (-1,1):
            cp=hit+right*sign*1.7+axis*.4;cyl('Knee | hinge',cp,.44,.25,steel,bone,right*sign);cyl('Knee | hinge amber plug',cp+right*sign*.16,.17,.06,amber,bone,right*sign)
    measurements.append({'bone':bone,'surface_samples':len(radii),'radius_min':min(radii),'radius_max':max(radii),'joint_end_fraction':end})

limb_kit('le')
if design==2:limb_kit('ri')
limb_kit('le',True)
if design==2:limb_kit('ri',True)

# Upper arm pauldrons are independent of the spine and forearm.
if design!=3:
    for side in ('le','ri') if design==2 else ('le',):
        bone='j_shoulder_'+side;a,b,axis,length,front,right,point,radii=limb(bone,'j_elbow_'+side)
        for k in range(3 if design==1 else 2):
            shift=.13 if style=='sprinter' else 0
            ts=[.025+k*.15+shift,.115+k*.15+shift,.205+k*.15+shift]
            angles=[-.48+j*2.30/12 for j in range(13)];vs=[]
            # Bridge sleeve folds with a curved shell; preserve the open arm pit.
            rad=[]
            for ang in angles:
                direction=front*math.cos(ang)+right*math.sin(ang)
                rad.append(max((point(t,ang,.15)[0]-a.lerp(b,t)).dot(direction) for t in ts)+.08)
            for depth in (0,.18):
                for t in ts:
                    for ang,radius in zip(angles,rad):vs.append(a.lerp(b,t)+(front*math.cos(ang)+right*math.sin(ang))*(radius+depth))
            count=39;fs=[]
            for layer in (0,count):
                for row in range(2):
                    for j in range(12):i=layer+row*13+j;fs.append((i,i+1,i+14,i+13))
            for row in (0,2):
                for j in range(12):i=row*13+j;fs.append((i,i+1,i+1+count,i+count))
            for j in (0,12):
                for row in range(2):i=row*13+j;fs.append((i,i+13,i+13+count,i+count))
            mesh('Shoulder | curved overlapping armor lamella',vs,fs,ivory if k==0 else steel,bone,.025)
            for ang in (-.30,1.45):
                hp,hn=point(ts[1],ang,.44);bolt('Shoulder | lamella rivet',hp,hn,bone)
        # Donor sleeves are torn open behind the shoulder: use front suspension
        # tabs rather than forcing a closed band through that missing surface.
        for ang in (-.42,.42):
            hp,hn=point(.32,ang,.16)
            panel('Shoulder | suspension tab',hp,hn,.65,1.6,bone,web,-axis,depth=.10,fasteners=False)
        p,n=point(.22,.46,.8);cyl('Shoulder | amber inset marker',p,.23,.10,amber,bone,n)

# Side-mounted hip canister/tool case follows the upper leg, never the torso.
hipside='le' if design==1 else 'ri';bone='j_hip_'+hipside
a,b,axis,length,front,right,point,radii=limb(bone,'j_knee_'+hipside)
strap('Thigh | utility retaining strap',point,.35,.82,length,bone)
p,n=point(.30,.55,.2)
if design==1:cell('Thigh | emergency reactor',p+n*.68,n,.57,4.5,bone,-axis)
else:
    p,r,n,u,f=panel('Thigh | latched service case',p,n,3.6,5.0,bone,steel,-axis,depth=.65)
    panel('Thigh | chipped service cover',p+n*.04,n,3.10,4.3,bone,ivory,u,depth=.13)
    for dz in (-1.65,1.65):box('Thigh | toolcase latch',p+n*.32+u*dz,(1.1,.2,.35),steel,bone,f)
    if design==3:
        for off in (-.9,0,.9):
            verts=[p+n*.19+r*(off+x)+u*z for x,z in [(-.25,-1.25),(0,-1.25),(.72,1.25),(.47,1.25)]]
            mesh('Thigh | caution stripe',verts,[(0,1,2,3)],yellow,bone)

if design in (1,3):
    # Plates follow the existing wrist and finger joints; original hands remain.
    wrist=rig.matrix_world@rig.data.bones['j_wrist_le'].head_local
    knuckle=rig.matrix_world@rig.data.bones['j_mid_le_1'].head_local
    hp=wrist.lerp(knuckle,.6)
    hit,hn,idx,d=surface.ray_cast(hp+Vector((0,0,8)),Vector((0,0,-1)),14)
    assert hit is not None
    up=(knuckle-wrist).normalized();normal=Vector((0,0,1))
    pp,r,n,u,f=panel('Hand | dorsal mechanical glove',hit+normal*.10,normal,1.85,2.0,'j_wrist_le',steel,up,depth=.18)
    for dx in (-.50,0,.50):
        tube('Hand | tendon conduit',[pp+r*dx-u*.75+n*.08,pp+r*dx+u*.70+n*.08],.075,edge,'j_wrist_le',False)
    for finger in ('index','mid','ring'):
        bone='j_'+finger+'_le_1';nextbone='j_'+finger+'_le_2'
        a=rig.matrix_world@rig.data.bones[bone].head_local;b=rig.matrix_world@rig.data.bones[nextbone].head_local
        c=a.lerp(b,.4);hit,hn,idx,d=surface.ray_cast(c+normal*6,-normal,10)
        assert hit is not None
        panel('Hand | articulated '+finger+' plate',hit+normal*.08,normal,.44,(b-a).length*.64,bone,ivory,(b-a).normalized(),depth=.095,fasteners=False)
        cyl('Hand | '+finger+' knuckle hinge',hit+normal*.2,.18,.50,edge,bone,(1,0,0),8)

# Head pieces are fitted to this study's actual head silhouette.
def headpoint(x,z,side=False,gap=.08):
    if side:
        sign=1 if x>=0 else -1;origin=Vector((sign*12,x if abs(x)<1 else -.2,z));direction=Vector((-sign,0,0))
    else:origin=Vector((x,-16,z));direction=Vector((0,1,0))
    p,n,i,d=headsurface.ray_cast(origin,direction,30);assert p is not None,('head fit',key,x,z)
    return p-direction*gap,-direction
for sx in (-1,1):
    p,n=headpoint(sx*2,66.5,True,.14)
    cyl('Head | temporal receiver housing',p,.97,.34,steel,'j_head',n)
    cyl('Head | receiver worn bezel',p+n*.22,.72,.12,edge,'j_head',n)
    cyl('Head | cyan receiver ring',p+n*.30,.59,.08,cyan,'j_head',n)
    cyl('Head | receiver center',p+n*.36,.43,.10,steel,'j_head',n)
    for dz in (-1.1,1.1):bolt('Head | receiver mounting bolt',p+Vector((0,0,dz))+n*.08,n,'j_head',.105)
    points=[p+Vector((0,.30,-.65)),p+Vector((0,1.1,-1.1)),p+Vector((-sx*.25,1.8,-.2)),p+Vector((-sx*.2,1.2,1.9))]
    tube('Head | magenta neural lead',points,.17,magenta,'j_head')
    # Sculpted cheek support runs alongside the face, leaving the mouth readable.
    for j,(x,z) in enumerate([(sx*2.15,65.1),(sx*1.95,63.7)]):
        hp,hn=headpoint(x,z,False,.12)
        panel('Head | jaw support segment',hp,hn,.85,1.35,'j_head',steel,depth=.16,fasteners=False)
        bolt('Head | jaw brace rivet',hp+Vector((0,-.22,.32)),hn,'j_head',.095)
if design==1:
    # A cracked monocular shield; luminous fracture lines are real geometry.
    p,n=headpoint(1.1,66.3,False,.22)
    outline=[(-.9,.8),(.55,1.0),(1.35,.45),(1.05,-.75),(.1,-1.0),(-.80,-.3)]
    verts=[p+Vector((x,-.05-.08*x,z)) for x,z in outline]
    mesh('Head | fractured cyan monocular shield',verts,[tuple(range(6))],glass,'j_head',.015)
    for i in range(6):tube('Head | optic rim',[verts[i],verts[(i+1)%6]],.038,cyan,'j_head',False)
    c=p+Vector((.3,-.15,-.05))
    for i,v in enumerate(verts):
        mid=c.lerp(v,.55)+Vector((.10*(-1 if i%2 else 1),-.03,.05))
        tube('Head | branching lens fracture',[c,mid,v+Vector((0,-.04,0))],.018,crack,'j_head',False)
elif design==2:
    p,n=headpoint(0,62.9,False,.21)
    panel('Head | mandibular restraint',p,n,2.55,.65,'j_head',steel,depth=.20)
else:
    # Raised welding visor from reference 3: face remains fully visible.
    p=Vector((0,-3.0,70.8));normal=Vector((0,-.80,.60)).normalized()
    p,r,n,u,f=panel('Head | raised welding shield',p,normal,6.4,3.6,'j_head',ivory,depth=.35)
    box('Head | smoked welding window gasket',p+n*.05,(4.65,.16,2.35),rubber,'j_head',f)
    box('Head | scratched dark welding glass',p+n*.15,(4.16,.07,1.85),steel,'j_head',f,.06)
    for sx in (-1,1):
        hp,hn=headpoint(sx*2,68.1,True,.12)
        tube('Head | visor hinge arm',[hp,Vector((sx*3.0,-1.0,69.6)),p+r*sx*2.7],.17,edge,'j_head',False)
        cyl('Head | visor hinge bolt',hp,.38,.23,steel,'j_head',hn)

# Give the existing helmets matching receiver rails; those pieces leave with the hat gib.
if entry and entry['helmet']:
    helmets=[o for o in base if 'helmet' in o.name.lower()];hb=bvh(helmets)
    for sx in (-1,1):
        p,n,idx,d=hb.ray_cast(Vector((sx*10,0,70)),Vector((-sx,0,0)),15);assert p is not None
        panel('Helmet | battered mounting rail',p+Vector((sx*.1,0,0)),(sx,0,0),2.9,.75,'j_head',steel,depth=.18)

assert donors=={name:signature(bpy.data.objects[name]) for name in donors}
poses=[]
for pname,angles in [('rest',{}),('head_turn',{'j_head':(0,0,30)}),('arm_flex',{'j_shoulder_le':(15,0,20),'j_elbow_le':(45,12,0),'j_wrist_le':(15,0,0)}),('leg_flex',{'j_hip_le':(25,0,0),'j_knee_le':(50,0,0)})]:
    for pb in rig.pose.bones:pb.rotation_euler=(0,0,0)
    for bn,degrees in angles.items():rig.pose.bones[bn].rotation_euler=[math.radians(v) for v in degrees]
    bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();worst=0
    for ob in parts:
        bn=ob['attachment_bone'];xf=rig.pose.bones[bn].matrix@rig.data.bones[bn].matrix_local.inverted()
        ev=ob.evaluated_get(dg);me=ev.to_mesh()
        for raw,v in zip(ob.data.vertices,me.vertices):
            expected=rig.matrix_world@xf@rig.matrix_world.inverted()@ob.matrix_world@raw.co
            worst=max(worst,(ev.matrix_world@v.co-expected).length)
        ev.to_mesh_clear()
    assert worst<.002,(pname,worst);poses.append({'pose':pname,'max_attachment_error':worst})
for pb in rig.pose.bones:pb.rotation_euler=(0,0,0)
bpy.context.view_layer.update()
scene['cyber_finish_revision']=4;scene['reference_design']=design;scene['cyber_reference_pass']=3
scene.render.threads_mode='FIXED';scene.render.threads=6;scene.cycles.samples=24
scene.render.resolution_x=1100;scene.render.resolution_y=1300;scene.render.resolution_percentage=100
report={'id':key,'revision':4,'fit_pass':3,'authoring_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'reference':f'CyberZombie{design}.png','source_backup':str(backup.relative_to(ROOT)),
    'donor_geometry_weights_preserved':True,'limb_fits':measurements,'poses':poses,
    'attachment_objects':len(parts),'attachment_triangles':sum(len(p.vertices)-2 for o in parts for p in o.data.polygons),
    'attachment_bones':sorted(set(o['attachment_bone'] for o in parts)),
    'notes':'Equipment reconstruction adapted to original donor body; not an exact 3D recovery from reference images.'}
(master.parent/'equipment_v4.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(master))
if '--no-render' not in args:
    views=[('front',(34,-120,64),(0,-1,36),85),('detail',(28,-80,73),(0,-1,59),32),('back',(42,120,65),(0,0,39),80),
           ('wrist',(43,-40,63),(17,-6,46),20),('wrist_inside',(-7,-34,32),(17,-6,46),20),('equipment',(15,-65,64),(0,-1,51),24)]
    if '--front-only' in args:views=views[:1]
    for view,loc,target,scale in views:
        cam=scene.camera;cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
        scene.render.filepath=str(master.parent/((view if entry else 'reference_'+view)+'.png'));bpy.ops.render.render(write_still=True)
print('CYBER_REFERENCE_EQUIPMENT_OK',json.dumps(report),flush=True)
