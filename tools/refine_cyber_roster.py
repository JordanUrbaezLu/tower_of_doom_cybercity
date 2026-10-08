"""Blender: second art pass on the six existing editable zombie studies.

Uses a one-time source backup so reruns never stack detail. Original donor
geometry, weights and materials are untouched. Run -- <id|mvp> [--no-render].
"""
import bpy, sys, math, json, hashlib, shutil
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'art/cyber_zombie_roster'
args=sys.argv[sys.argv.index('--')+1:]
key=args[0]
entry=next((e for e in json.loads((ART/'roster.json').read_text())['models'] if e['id']==key),None)
style=entry['style'] if entry else 'crown'
master=ART/key/(key+'.blend') if entry else ROOT/'art/cyber_zombie_mvp/cyber_zombie_mvp.blend'
backup=ROOT/'tmp/cyber_finish_v1'/master.relative_to(ROOT)
backup.parent.mkdir(parents=True,exist_ok=True)
if not backup.exists():shutil.copy2(master,backup)
bpy.ops.wm.open_mainfile(filepath=str(backup))
scene=bpy.context.scene;rig=bpy.data.objects['Cybercity_zombie_rig']
assert scene.get('cyber_finish_revision',1)==1,'Restore the revision-1 source backup before authoring again'
parts=[o for o in scene.objects if 'attachment_bone' in o]
original_parts=len(parts)
def signature(ob):
    return hashlib.sha256(repr(([tuple(v.co) for v in ob.data.vertices],
        [[(g.group,g.weight) for g in v.groups] for v in ob.data.vertices],
        [tuple(p.vertices) for p in ob.data.polygons])).encode()).hexdigest()
donors={o.name:signature(o) for o in scene.objects if o.type=='MESH' and o not in parts and o.name!='Studio floor'}

def finish_material(name,base,kind='paint'):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name);m.use_nodes=True
    ns=m.node_tree.nodes;links=m.node_tree.links;ns.clear()
    def node(t,n):
        o=ns.new(t);o.name=n;o.label=n;return o
    def noise(n,scale,vec):
        o=node('ShaderNodeTexNoise',n);o.inputs['Scale'].default_value=scale;o.inputs['Detail'].default_value=3
        links.new(vec,o.inputs['Vector']);return o.outputs['Fac']
    def ramp(n,fac,a,b,p0=.25,p1=.75):
        o=node('ShaderNodeValToRGB',n);o.color_ramp.elements[0].position=p0;o.color_ramp.elements[0].color=(*a,1)
        o.color_ramp.elements[1].position=p1;o.color_ramp.elements[1].color=(*b,1);links.new(fac,o.inputs[0]);return o.outputs[0]
    def mix(n,fac,a,b):
        o=node('ShaderNodeMixRGB',n);links.new(fac,o.inputs[0])
        for s,v in ((o.inputs[1],a),(o.inputs[2],b)):
            if isinstance(v,tuple):s.default_value=(*v,1)
            else:links.new(v,s)
        return o.outputs[0]
    bs=node('ShaderNodeBsdfPrincipled','Principled BSDF');out=node('ShaderNodeOutputMaterial','Material Output')
    links.new(bs.outputs[0],out.inputs['Surface']);bs.inputs['Base Color'].default_value=(*base,1)
    # World/rest coordinates survive the atlas join, unlike each part's Generated bounds.
    coord=node('ShaderNodeNewGeometry','Stable surface position').outputs['Position']
    macro=noise('Uneven age and grime',1.15,coord)
    color=ramp('Aged finish',macro,tuple(x*.38 for x in base),tuple(x*1.4 for x in base))
    grain=noise('Small surface pits',22,coord)
    rough=ramp('Dry and rubbed areas',macro,(.48,)*3,(.85,)*3)
    if kind in ('paint','helmet'):
        chips=ramp('Chipped coating',noise('Broken chip edges',7.5,coord),(0,)*3,(1,)*3,.59,.70)
        substrate=ramp('Oxidized steel beneath paint',grain,(.034,.028,.019),(.19,.19,.15))
        color=mix('Coating and exposed steel',chips,color,substrate)
        links.new(ramp('Conductive chipped edges',chips,(.12,)*3,(.78,)*3,0,1),bs.inputs['Metallic'])
    elif kind=='metal':
        bs.inputs['Metallic'].default_value=.8;rough=ramp('Tarnish polish',macro,(.3,)*3,(.66,)*3)
    elif kind=='cloth':
        bs.inputs['Metallic'].default_value=0;bs.inputs['Sheen Weight'].default_value=.18
        wave=node('ShaderNodeTexWave','Woven webbing');wave.wave_type='BANDS';wave.bands_direction='DIAGONAL';wave.inputs['Scale'].default_value=35
        links.new(coord,wave.inputs['Vector']);grain=wave.outputs['Fac']
        rough=ramp('Worn fabric',macro,(.78,)*3,(.96,)*3)
    else:bs.inputs['Metallic'].default_value=.03
    links.new(color,bs.inputs['Base Color']);links.new(rough,bs.inputs['Roughness'])
    bump=node('ShaderNodeBump','Fine relief');bump.inputs['Strength'].default_value=.28;bump.inputs['Distance'].default_value=.018
    links.new(grain,bump.inputs['Height']);links.new(bump.outputs['Normal'],bs.inputs['Normal'])
    m.diffuse_color=(*base,1)
    return m

palette={'trooper':(.10,.125,.061),'relay':(.10,.125,.061),'signal':(.15,.18,.17),'crown':(.15,.18,.17),'sprinter':(.07,.084,.083)}
paint=finish_material('TOD | graphite ceramic steel',palette[style])
edge=finish_material('TOD | worn titanium edges',(.12,.14,.125),'metal')
rubber=finish_material('TOD | black cable insulation',(.012,.017,.014),'rubber')
gold=finish_material('TOD | crown brass',(.32,.18,.047),'metal')
web=finish_material('TOD V2 | weathered uniform webbing',(.073,.072,.047),'cloth')
helmet_mat=finish_material('TOD V2 | chipped helmet coating',(.24,.26,.235),'helmet')
stitch=finish_material('TOD V2 | dirty seam thread',(.20,.19,.135),'cloth')
def glow(name,color,strength):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Metallic'].default_value=.2;bs.inputs['Roughness'].default_value=.27
    bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=strength
    return m
cyan=glow('TOD | cyan emissive inlay',(.008,.55,.8),1.8)
amber=glow('TOD | amber status lamp',(.9,.15,.012),1.8)
eye=glow('TOD V2 | luminous optic',(.008,.68,1) if style in ('crown','trooper') else (1,.24,.016),5.4)
core=glow('TOD V2 | bright optic core',(.42,.88,1) if style in ('crown','trooper') else (1,.65,.24),6)
for ob in parts:
    if ob.name.startswith('Helmet |') and any(s in ob.name for s in ('backing','housing','foot')):ob.data.materials[0]=helmet_mat
    if ob.name.startswith('Optic | cyan lens'):ob.data.materials[0]=eye
    if ob.name.startswith('Optic | center lens'):ob.data.materials[0]=core
    if 'retaining band' in ob.name:ob.data.materials[0]=web

def attach(ob,name,mat,bone,bevel=0):
    ob.name=name;ob.data.materials.append(mat)
    bpy.context.view_layer.objects.active=ob
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new('Soft worn edge','BEVEL');mod.width=bevel;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=ob.modifiers.new('Face normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
    vg=ob.vertex_groups.new(name=bone);vg.add(list(range(len(ob.data.vertices))),1,'REPLACE')
    mod=ob.modifiers.new('Original skeleton attachment','ARMATURE');mod.object=rig;ob.parent=rig
    ob['attachment_bone']=bone;ob['finish_revision']=2;parts.append(ob);return ob
def box(name,loc,dims,mat,bone,rotation=None,bevel=.045):
    bpy.ops.object.select_all(action='DESELECT');bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    ob=bpy.context.object;ob.dimensions=dims
    if rotation is not None:ob.rotation_euler=rotation
    return attach(ob,name,mat,bone,bevel)
def local_box(ref,name,offset,dims,mat,bevel=.035):
    return box(name,ref.matrix_world@Vector(offset),dims,mat,ref['attachment_bone'],ref.rotation_euler,bevel)
def cable(name,points,bone):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=4;cu.bevel_depth=.085;cu.bevel_resolution=0
    sp=cu.splines.new('BEZIER');sp.bezier_points.add(len(points)-1)
    for p,co in zip(sp.bezier_points,points):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    ob=bpy.data.objects.new(name,cu);scene.collection.objects.link(ob)
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob;bpy.ops.object.convert(target='MESH')
    return attach(bpy.context.object,name,rubber,bone)

# Equipment sewn/riveted into a small fabric mount. Work in each fitted plate's
# frame so the body1 and body2 mounts follow their actual breast and arm angles.
for ref in list(parts):
    if not any(s in ref.name for s in ('Chest | backing plate','Forearm | titanium base','Armor | breast sensor backing','Back | cell chassis','Armor | rear power housing')):continue
    x,y,z=ref.dimensions
    prefix=ref.name.split(' |')[0]+' | V2 '
    outward=1 if 'rear' in ref.name or prefix.startswith('Back') else -1
    # Forearm local +Y points outwards; chest local -Y points forwards.
    if prefix.startswith('Forearm'):outward=1
    rear=-outward
    local_box(ref,prefix+'woven mounting pad',(0,rear*(y/2+.025),0),(x+.32,.15,z+.40),web,.07)
    for sign in (-1,1):
        zz=sign*(z/2+.28)
        local_box(ref,prefix+'sewn anchor tab',(0,rear*y*.35,zz),(x*.55,.12,.68),web)
        for xx in (-x*.21,x*.21):
            local_box(ref,prefix+'seam stitch',(xx,rear*y*.35+outward*.07,zz),(.055,.035,.38),stitch,.012)
        local_box(ref,prefix+'anchor rivet',(0,rear*y*.35+outward*.105,zz),(.17,.08,.17),gold,.045)
    # Raised corner screws and small score lines break up the flat rectangle.
    for xx in (-x*.37,x*.37):
        for zz in (-z*.39,z*.39):
            local_box(ref,prefix+'service screw',(xx,outward*(y/2+.39),zz),(.13,.08,.13),edge,.025)

# Short service conduits attached to the same bone as their connector modules.
if style=='sprinter':
    cable('Armor | V2 breast conduit',[(-3.1,-7.2,55.6),(-2.7,-7.15,57),(-3.6,-6.0,58.1)],'j_spine4')
    cable('Armor | V2 rear conduit',[(1.7,7.4,53.4),(3.15,6.9,54.4),(3.7,5.8,56)],'j_spine4')
elif style=='relay':
    cable('Back | V2 cell feed',[(2.4,6.2,52.5),(3.8,5.5,53.4),(4.4,4.6,55.5)],'j_spine4')
for ref in list(parts):
    if ref.name.startswith(('Helmet | receiver housing','Temple receiver | shell')):
        # Side receiver lives on X, so its service port is on the exposed side.
        x,y,z=ref.dimensions;prefix='Helmet |' if ref.name.startswith('Helmet') else 'Temple |'
        local_box(ref,prefix+' V2 service socket',(x/2+.045,.48,-.27),(.1,.34,.28),rubber)
        local_box(ref,prefix+' V2 socket collar',(x/2+.09,.48,-.27),(.06,.19,.13),gold,.02)

assert donors=={name:signature(bpy.data.objects[name]) for name in donors},'Donor geometry changed'
poses=[]
for pname,angles in [('rest',{}),('head_turn',{'j_head':(0,0,25)}),('arm_flex',{'j_elbow_le':(30,10,0)}),('torso_leg',{'j_spine4':(8,0,10),'j_knee_ri':(25,0,0)})]:
    for pb in rig.pose.bones:pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0)
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
for ob in parts:ob.hide_render=False
bpy.context.view_layer.update()
scene['cyber_finish_revision']=2
scene.render.threads_mode='FIXED';scene.render.threads=4;scene.cycles.samples=24
scene.render.resolution_x=900;scene.render.resolution_y=1080;scene.render.resolution_percentage=100
# Modest bloom in this studio preview only; native glow uses the emissive atlas.
for n in scene.node_tree.nodes:
    if n.type=='GLARE':n.mix=-.80;n.threshold=2
folder=master.parent
report={'id':key,'revision':2,'donor_geometry_weights_preserved':True,'source_backup':str(backup.relative_to(ROOT)),
    'previous_attachment_objects':original_parts,'attachment_objects':len(parts),
    'attachment_triangles':sum(len(p.vertices)-2 for o in parts for p in o.data.polygons),
    'poses':poses,'emission_scale':6,'notes':'Studio previews; native map appearance still requires user playtest.'}
(folder/'finish_v2.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(master))
if '--no-render' not in args:
    for view,loc,target,scale in [('front',(34,-120,64),(0,-1,36),84),('detail',(36,-80,76),(0,-1,57),37),('back',(42,120,65),(0,0,36),84)]:
        cam=scene.camera;cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
        scene.render.filepath=str(folder/((view if entry else 'prototype_'+view)+'.png'));bpy.ops.render.render(write_still=True)
print('CYBER_FINISH_V2_OK',json.dumps(report),flush=True)
