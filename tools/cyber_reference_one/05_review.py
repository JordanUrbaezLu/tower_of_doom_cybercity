"""Organize the editable model and verify stock preservation via Blender MCP."""
import sys, importlib, collections
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import lib
importlib.reload(lib)
from lib import *
expected=json.loads(scene['donor_signatures'])
assert expected=={o.name:signature(o) for o in base},'Original donor geometry or weights changed'
equipment=[o for o in scene.objects if 'attachment_bone' in o]
assert all(o.get('equipment_revision')==5 for o in equipment)
for o in equipment:
    assert o['attachment_bone'] in rig.data.bones
    for v in o.data.vertices:
        assert all(math.isfinite(x) for x in v.co)
        assert len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-6,(o.name,v.index)
categories={'Head':'01 Head - optic, receiver, jaw','Shoulder':'02 Layered pauldrons','Harness':'03 Fitted harness','Chest':'04 Chest console','Back':'05 Spinal reactor','Arm':'06 Powered forearm','Hand':'07 Mechanical hand','Finger':'07 Mechanical hand','Leg':'08 Leg exoskeleton','Knee':'08 Leg exoskeleton','Thigh':'09 Reserve cell'}
for ob in equipment:
    title=categories.get(ob.name.split(' |')[0].split(' ')[0],'10 Equipment details')
    coll=bpy.data.collections.get(title)
    if coll is None:coll=bpy.data.collections.new(title);scene.collection.children.link(coll)
    for old in list(ob.users_collection):old.objects.unlink(ob)
    coll.objects.link(ob)
bone_counts=collections.Counter(o['attachment_bone'] for o in equipment)
assert all(f'j_{finger}_le_{segment}' in bone_counts for finger in ('index','mid','ring','pinky') for segment in (1,2,3))
assert all(f'j_thumb_le_{segment}' in bone_counts for segment in (1,2))
bpy.context.view_layer.update()
dg=bpy.context.evaluated_depsgraph_get();triangles=0;neutral={}
for ob in equipment:
    ev=ob.evaluated_get(dg);me=ev.to_mesh();triangles+=sum(len(p.vertices)-2 for p in me.polygons)
    step=max(1,len(me.vertices)//32)
    neutral[ob.name]=[(i,ev.matrix_world@me.vertices[i].co) for i in range(0,len(me.vertices),step)]
    ev.to_mesh_clear()
pose_checks=[]
for name,angles in [('head_turn',{'j_head':(0,0,25)}),('arm_flex',{'j_shoulder_le':(15,0,20),'j_elbow_le':(40,10,0),'j_wrist_le':(12,0,0),'j_index_le_1':(20,0,0),'j_mid_le_2':(20,0,0)}),('leg_flex',{'j_hip_le':(22,0,0),'j_knee_le':(45,0,0)})]:
    for pb in rig.pose.bones:pb.rotation_euler=(0,0,0)
    for bn,degrees in angles.items():rig.pose.bones[bn].rotation_euler=[math.radians(a) for a in degrees]
    bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();worst=0
    for ob in equipment:
        bn=ob['attachment_bone'];xf=rig.matrix_world@rig.pose.bones[bn].matrix@rig.data.bones[bn].matrix_local.inverted()@rig.matrix_world.inverted()
        ev=ob.evaluated_get(dg);me=ev.to_mesh()
        for idx,co in neutral[ob.name]:worst=max(worst,(ev.matrix_world@me.vertices[idx].co-xf@co).length)
        ev.to_mesh_clear()
    assert worst<.003,(name,worst);pose_checks.append({'name':name,'max_attachment_error':worst})
for pb in rig.pose.bones:pb.rotation_euler=(0,0,0)
bpy.context.view_layer.update()
report=json.loads((OUT/'validation.json').read_text()) if (OUT/'validation.json').exists() else {}
report.update({'authoring':'upstream Blender MCP execute_blender_code','port':9877,'scope':'Reference one / Crown original donor only; art master, not installed in game',
 'equipment_objects':len(equipment),'evaluated_equipment_triangles':triangles,'attachment_bones':dict(bone_counts),'donor_geometry_and_weights_unchanged':True,
 'reference':'CyberZombie1.png','attachment_pose_checks':pose_checks,'native_exported':False,'native_playtested':False,
 'limitations':['Adapted to original donor body proportions and clothing, not exact image-to-mesh recovery.','High-detail editable art; game LODs, texture bake, moving-joint clearance and performance must be checked before integration.']})
if scene.get('reference_one_pass2'):
    report['reference_refinement']=scene['reference_one_pass2']
    report['magenta_emission_strength']=magenta.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value
(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
if not scene.get('reference_one_pass2'):
    camera((30,-126,62),(0,-.5,36),81)
save(scene['reference_one_stage'] if scene.get('reference_one_pass2') else '05_reviewable_master')
print(json.dumps(report,indent=2))
