"""Blender art revision 3: measured forearm cuffs and connected torso equipment.

Run -- <roster-id|mvp> [--no-render]. Rebuilds from saved revision-2 masters.
All additions use the existing head/spine/elbow groups and damage export path.
"""
import bpy, bmesh, sys, json, math, shutil, hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1];ART=ROOT/'art/cyber_zombie_roster'
args=sys.argv[sys.argv.index('--')+1:];key=args[0]
entry=next((e for e in json.loads((ART/'roster.json').read_text())['models'] if e['id']==key),None)
style=entry['style'] if entry else 'crown'
master=ART/key/(key+'.blend') if entry else ROOT/'art/cyber_zombie_mvp/cyber_zombie_mvp.blend'
backup=ROOT/'tmp/cyber_finish_v2'/master.relative_to(ROOT);backup.parent.mkdir(parents=True,exist_ok=True)
if not backup.exists():shutil.copy2(master,backup)
bpy.ops.wm.open_mainfile(filepath=str(backup));scene=bpy.context.scene
assert scene.get('cyber_finish_revision')==2,'Revision-2 master backup required'
rig=bpy.data.objects['Cybercity_zombie_rig']
for pb in rig.pose.bones:pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0)
bpy.context.view_layer.update()
parts=[o for o in scene.objects if 'attachment_bone' in o]
base=[o for o in scene.objects if o.type=='MESH' and o not in parts and o.name!='Studio floor']
def signature(ob):
    return hashlib.sha256(repr(([tuple(v.co) for v in ob.data.vertices],
        [[(g.group,g.weight) for g in v.groups] for v in ob.data.vertices],
        [tuple(p.vertices) for p in ob.data.polygons])).encode()).hexdigest()
donors={o.name:signature(o) for o in base}
body=[o for o in base if 'body' in o.name.lower() or o.get('source_asset','').startswith('c_t8')]
if not body:
    # MVP source object names predate source_asset metadata.
    body=[o for o in base if 'upperbody' in o.name.lower() or 'lowerbody' in o.name.lower()]
assert body,[o.name for o in base]
paint=bpy.data.materials['TOD | graphite ceramic steel'];edge=bpy.data.materials['TOD | worn titanium edges']
web=bpy.data.materials['TOD V2 | weathered uniform webbing'];rubber=bpy.data.materials['TOD | black cable insulation']
gold=bpy.data.materials['TOD | crown brass'];amber=bpy.data.materials['TOD | amber status lamp']
cyan=bpy.data.materials.get('TOD | cyan emissive inlay') or amber  # sprinter uses amber exclusively
# Signal and Crown share the same native body assets; only their heads/helmets differ.
lamp=amber if style in ('relay','sprinter') else cyan
def attach(ob,name,mat,bone='j_spine4',bevel=0):
    ob.name=name;ob.data.materials.append(mat);bpy.context.view_layer.objects.active=ob
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new('Machined bevel','BEVEL');mod.width=bevel;mod.segments=1;bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=ob.modifiers.new('Face normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
    vg=ob.vertex_groups.new(name=bone);vg.add(list(range(len(ob.data.vertices))),1,'REPLACE')
    mod=ob.modifiers.new('Existing skeleton','ARMATURE');mod.object=rig;ob.parent=rig
    ob['attachment_bone']=bone;ob['equipment_revision']=3;parts.append(ob);return ob
def mesh(name,verts,faces,mat,bone='j_spine4'):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    ob=bpy.data.objects.new(name,me);scene.collection.objects.link(ob);return attach(ob,name,mat,bone)
def box(name,loc,dims,mat,bone='j_spine4',frame=None,bevel=.055):
    bpy.ops.object.select_all(action='DESELECT');bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    ob=bpy.context.object;ob.dimensions=dims
    if frame is not None:ob.rotation_euler=frame.to_euler()
    return attach(ob,name,mat,bone,bevel)
def cylinder(name,loc,radius,depth,mat,bone='j_spine4',axis=(0,0,1)):
    bpy.ops.object.select_all(action='DESELECT');bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=radius,depth=depth,location=loc)
    ob=bpy.context.object;ob.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    for p in ob.data.polygons:p.use_smooth=len(p.vertices)==4
    return attach(ob,name,mat,bone,.035)
def cable(name,points,radius=.09,bone='j_spine4',mat=None):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=3;cu.bevel_depth=radius;cu.bevel_resolution=0
    sp=cu.splines.new('POLY');sp.points.add(len(points)-1)
    for p,co in zip(sp.points,points):p.co=(*co,1)
    ob=bpy.data.objects.new(name,cu);scene.collection.objects.link(ob)
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob;bpy.ops.object.convert(target='MESH')
    return attach(bpy.context.object,name,mat or rubber,bone)
def bvh_for(objects,accept=None):
    verts=[];faces=[]
    for ob in objects:
        offset=len(verts);coords=[ob.matrix_world@v.co for v in ob.data.vertices];verts.extend(coords)
        for p in ob.data.polygons:
            center=sum((coords[i] for i in p.vertices),Vector())/len(p.vertices)
            if accept is None or accept(center):faces.append(tuple(offset+i for i in p.vertices))
    assert faces
    return BVHTree.FromPolygons(verts,faces)
surface=bvh_for(body)
fit_report={}
if style=='sprinter':
    # The donor's central back spike crosses the old tall power box. Replace
    # that box and its mounts with a shorter core below the spike.
    for ob in list(parts):
        rear=ob.name.startswith(('Armor | rear power','Armor | V2 rear conduit'))
        rear=rear or (ob.name.startswith('Armor | V2') and ob.location.y>0)
        if rear:parts.remove(ob);bpy.data.objects.remove(ob,do_unlink=True)
if style!='sprinter':
    # Remove the fixed oval and oversized floating plate completely.
    for ob in list(parts):
        if ob.name.startswith('Forearm |'):
            parts.remove(ob);bpy.data.objects.remove(ob,do_unlink=True)
    elbow=rig.matrix_world@rig.data.bones['j_elbow_le'].head_local
    wrist=rig.matrix_world@rig.data.bones['j_wrist_le'].head_local
    axis=(wrist-elbow).normalized();length=(wrist-elbow).length
    front=Vector((0,-1,.6));front=(front-axis*front.dot(axis)).normalized();side=front.cross(axis).normalized()
    def arm_region(p):
        d=p-elbow;t=d.dot(axis)/length;rad=(d-axis*d.dot(axis)).length
        return -.05<t<1.1 and rad<5.2
    arm=bvh_for(body,arm_region)
    samples=[];misses=[]
    def skin(t,angle):
        center=elbow.lerp(wrist,t);direction=front*math.cos(angle)+side*math.sin(angle)
        hit,normal,index,dist=arm.ray_cast(center+direction*7,-direction,7.5)
        if hit is None:
            raise RuntimeError(('No arm surface at cuff sample',key,t,angle))
        radius=(hit-center).dot(direction)
        assert .3<radius<4.5,(key,t,angle,radius)
        samples.append(radius);return hit,direction
    def point(t,angle,gap):
        p,d=skin(t,angle);return p+d*gap
    # The cuff ends at 78% of elbow-to-wrist length, leaving the wrist free.
    # Each longitudinal/angular sample follows the *actual* sleeve or bare arm.
    def patch(name,ts,angles,gap,thickness,mat,closed=False):
        verts=[];rows=len(ts);cols=len(angles)
        for layer in (gap,gap+thickness):
            for t in ts:
                for a in angles:
                    if 'padded liner' in name and layer==gap:
                        p,d=raw_skin(t,a);verts.append(p+d*.055)
                    else:verts.append(point(t,a,layer))
        count=rows*cols;faces=[]
        limit=cols if closed else cols-1
        for layer in (0,count):
            for r in range(rows-1):
                for c in range(limit):
                    n=(c+1)%cols;a=layer+r*cols+c;b=layer+r*cols+n
                    f=(a,b,b+cols,a+cols);faces.append(f if layer else f[::-1])
        for r in (0,rows-1):
            for c in range(limit):
                n=(c+1)%cols;a=r*cols+c;b=r*cols+n;faces.append((a,b,b+count,a+count))
        if not closed:
            for c in (0,cols-1):
                for r in range(rows-1):
                    a=r*cols+c;b=a+cols;faces.append((a,b,b+count,a+count))
        ob=mesh(name,verts,faces,mat,'j_elbow_le')
        # Interpolate curved panel normals; retain hard perimeter edges.
        if not closed:
            for poly in list(ob.data.polygons)[:2*(rows-1)*(cols-1)]:poly.use_smooth=True
        return ob
    ring_angles=[i*math.tau/48 for i in range(48)]
    for t in (.48,.74):
        patch('Forearm | V3 fitted webbing strap',[t-.023,t,t+.023],ring_angles,.055,.075,web,True)
    # A rigid plate must bridge torn sleeve folds, not copy their wrinkles.
    # Fit a smooth quadratic radius to measured front-surface samples and lift
    # it by the largest positive residual, keeping it outside the donor skin.
    raw_skin=skin
    def terms(t,a):
        x=t-.5
        return [1,x,a,x*x,a*a,x*a,x*x*a,x*a*a]
    training=[];radii=[]
    for t in np.linspace(.44,.78,13):
        for a in np.linspace(math.radians(-30),math.radians(30),17):
            p,d=raw_skin(float(t),float(a));training.append(terms(t,a));radii.append((p-elbow.lerp(wrist,t)).dot(d))
    coef=np.linalg.lstsq(np.array(training),np.array(radii),rcond=None)[0]
    residual=(np.array(radii)-np.array(training)@coef).reshape(13,17).max(axis=1)
    fit_ts=np.linspace(.44,.78,13)
    lift_curve=np.polyfit(fit_ts,residual,2)
    lift_curve[-1]+=float(max(residual-np.polyval(lift_curve,fit_ts)))+.025
    lift=float(max(np.polyval(lift_curve,fit_ts)))
    def skin(t,angle):
        d=front*math.cos(angle)+side*math.sin(angle)
        radius=float(np.dot(terms(t,angle),coef))+float(np.polyval(lift_curve,t))
        return elbow.lerp(wrist,t)+d*radius,d
    ts=[.45+i*(.32/6) for i in range(7)]
    angles=[math.radians(-30+i*60/12) for i in range(13)]
    patch('Forearm | V3 tapered padded liner',ts,angles,.035,.085,rubber)
    patch('Forearm | V3 curved equipment shell',ts,angles,.12,.13,paint)
    # Long cyan rail sits on the measured shell; its direction follows taper.
    cable('Forearm | V3 embedded signal rail',[point(t,math.radians(-17),.285) for t in (.50,.55,.60,.65,.71)],.045,'j_elbow_le',cyan)
    for t in (.51,.57,.63,.70):
        a=math.radians(12);p,d=skin(t,a);frame=Matrix((side,d,axis)).transposed()
        box('Forearm | V3 recessed heat fin',p+d*.27,(.40,.065,.12),rubber,'j_elbow_le',frame,.018)
    for t in (.48,.74):
        for a in (-.37,.37):
            p,d=skin(t,a)
            cylinder('Forearm | V3 flush fastener',p+d*.27,.095,.06,gold,'j_elbow_le',d)
    fit_report={'fit':'48-ray body-specific closed straps; smooth tapered shell fitted over measured sleeve folds',
        'sample_radius_min':min(samples),'sample_radius_max':max(samples),'surface_samples':len(samples),
        'strap_gap':.055,'shell_gap_above_smooth_envelope':.12,'smooth_shell_fit_lift':lift,'wrist_clearance_units':length*(1-.78),
        'body_objects':[o.name for o in body]}

# Torso units use the clothing surface itself as their mounting reference.
# Their fronts share the donor's +Z up direction and outward surface normal.
def surface_point(x,z,back=False,extra=.12):
    direction=Vector((0,-1 if back else 1,0));origin=Vector((x,24 if back else -24,z))
    p,n,index,dist=surface.ray_cast(origin,direction,48)
    assert p is not None,('missing torso mount',key,x,z,back)
    outward=Vector((0,1 if back else -1,0))
    if n.dot(outward)<0:n=-n
    # Keep sockets almost parallel to clothing, without extreme torn-flap tilt.
    n=(n*.45+outward*.55).normalized()
    return p+n*extra,n
def module(name,x,z,width,height,back=False,light=True):
    p,n=surface_point(x,z,back)
    up=Vector((0,0,1));up=(up-n*up.dot(n)).normalized();right=n.cross(up).normalized()
    frame=Matrix((right,n,up)).transposed()
    box(name+' | cloth mount',p,(width+.28,.14,height+.25),web,frame=frame)
    box(name+' | chassis',p+n*.20,(width,.35,height),edge,frame=frame,bevel=.08)
    box(name+' | inset ceramic',p+n*.41,(width-.24,.12,height-.26),paint,frame=frame,bevel=.06)
    if light:
        box(name+' | status strip',p+n*.50+right*(width*.27),(width*.10,.06,height*.57),lamp,frame=frame,bevel=.025)
    for dz in (-height*.32,height*.32):
        box(name+' | retaining lug',p+n*.52+up*dz-right*width*.25,(width*.24,.09,.15),rubber,frame=frame,bevel=.025)
    return p,n,right,up
def routed(name,xzs,back=False):
    points=[surface_point(x,z,back,.22)[0] for x,z in xzs]
    cable(name,points,.085)
    return points

# A clearly readable clavicle sensor and twin capacitor cartridges sit above
# the existing chest module, away from the waist pouches and torn elbow skin.
cx=4.0 if style in ('trooper','relay','sprinter') else -4.0
p,n,right,up=module('Collar | V3 command receiver',cx,57.6,2.25,1.40,light=True)
for dx in (-.5,.35):
    loc=p+n*.60+right*dx-up*.1
    cylinder('Collar | V3 capacitor',loc,.25,1.65,edge,axis=up)
    cylinder('Collar | V3 capacitor light ring',loc+up*.38,.265,.10,lamp,axis=up)
    cylinder('Collar | V3 armored cap',loc+up*.83,.275,.16,paint,axis=up)
routed('Collar | V3 protected feed',[(cx,56.8),(cx*.90,55.8),(cx*.80,54.7)])

# Rear silhouette differs across families: signal spine cartridges, relay
# flanking cells, or sprinter's heavier cooling rails. All are torso-weighted.
if style in ('trooper','signal','crown'):
    p,n,right,up=module('Back | V3 spinal power chassis',0,53.2,3.1,5.9,True,False)
    for zoff in (-1.72,0,1.72):
        box('Back | V3 segmented power cell',p+n*.56+up*zoff,(2.25,.34,1.35),paint,frame=Matrix((right,n,up)).transposed(),bevel=.13)
        box('Back | V3 cell indicator',p+n*.76+up*zoff,(1.2,.07,.14),lamp,frame=Matrix((right,n,up)).transposed(),bevel=.025)
    for sx in (-1,1):
        routed('Back | V3 shoulder feed',[(sx*1.15,55.8),(sx*2.6,57.1),(sx*4.3,57.6)],True)
elif style=='relay':
    for sx in (-1,1):
        p,n,right,up=module('Back | V3 reserve cell cradle',sx*3.7,52.4,1.4,4.6,True,False)
        cylinder('Back | V3 cylindrical reserve cell',p+n*.60,.47,3.6,paint,axis=up)
        for dz in (-1.3,1.3):cylinder('Back | V3 cell collar',p+n*.6+up*dz,.51,.23,edge,axis=up)
        cylinder('Back | V3 charged ring',p+n*.6+up*.65,.49,.13,amber,axis=up)
        routed('Back | V3 reserve feed',[(sx*3.7,54.7),(sx*2.8,55.4),(sx*1.5,54)],True)
else:
    module('Armor | V3 compact spinal core',0,49.9,3.2,2.7,True,True)
    for sx in (-1,1):
        p,n,right,up=module('Armor | V3 spinal heat exchanger',sx*3.7,53.0,1.6,5.2,True,False)
        frame=Matrix((right,n,up)).transposed()
        for dz in (-1.7,-.85,0,.85,1.7):box('Armor | V3 cooling fin',p+n*.6+up*dz,(1.7,.4,.16),edge,frame=frame)
        box('Armor | V3 cooling status',p+n*.86,(.20,.07,3.3),amber,frame=frame,bevel=.03)
        routed('Armor | V3 shoulder feed',[(sx*3.7,55.7),(sx*4.4,57.4),(sx*5.1,58)],True)
    module('Armor | V3 auxiliary chest sensor',4.4,53.4,1.7,2.9,False,True)

if entry and entry['helmet']:
    helmet=[o for o in base if o.get('source_asset')=='c_zom_der_zombie_helmet1']
    hb=bvh_for(helmet)
    for sx in (-1,1):
        p,n,idx,dist=hb.ray_cast(Vector((sx*1.4,20,69)),Vector((0,-1,0)),25)
        assert p is not None
        box('Helmet | V3 rear locator mount',p+Vector((0,.08,0)),(1.0,.3,.68),paint,'j_head')
        box('Helmet | V3 rear locator light',p+Vector((0,.26,0)),(.64,.07,.14),amber if style=='signal' else cyan,'j_head',bevel=.018)

assert donors=={name:signature(bpy.data.objects[name]) for name in donors}
poses=[]
for pname,angles in [('rest',{}),('head_turn',{'j_head':(0,0,25)}),('arm_flex',{'j_elbow_le':(35,12,0),'j_wrist_le':(15,0,0)}),('torso_leg',{'j_spine4':(8,0,10),'j_knee_ri':(25,0,0)})]:
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
for ob in parts:ob.hide_render=False
scene['cyber_finish_revision']=3
scene.render.threads_mode='FIXED';scene.render.threads=4;scene.cycles.samples=24
scene.render.resolution_x=900;scene.render.resolution_y=1080;scene.render.resolution_percentage=100
report={'id':key,'revision':3,'source_backup':str(backup.relative_to(ROOT)),
    'donor_geometry_weights_preserved':True,'forearm_fit':fit_report,'poses':poses,
    'attachment_objects':len(parts),'attachment_triangles':sum(len(p.vertices)-2 for o in parts for p in o.data.polygons),
    'notes':'Actual donor-surface measurements; studio previews. Native animation/lighting remains user tested.'}
(master.parent/'equipment_v3.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(master))
if '--no-render' not in args:
    views=[('front',(34,-120,64),(0,-1,36),84),('detail',(36,-80,76),(0,-1,57),37),('back',(42,120,65),(0,0,44),68)]
    if style!='sprinter':views += [('wrist',(43,-40,63),(17,-6,46),19),('wrist_inside',(-7,-34,32),(17,-6,46),19)]
    if '--fit-only' in args:views=[v for v in views if v[0].startswith('wrist')]
    if '--body-views-only' in args:views=[v for v in views if not v[0].startswith('wrist')]
    for view,loc,target,scale in views:
        cam=scene.camera;cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
        scene.render.filepath=str(master.parent/((view if entry else 'prototype_'+view)+'.png'));bpy.ops.render.render(write_still=True)
print('CYBER_EQUIPMENT_V3_OK',json.dumps(report),flush=True)
