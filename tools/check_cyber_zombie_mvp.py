"""Validate the saved Blender MVP's packed textures and actual evaluated skinning.

Run with Blender -b art/cyber_zombie_mvp/cyber_zombie_mvp.blend --python <this>.
Does not save over the source .blend or write any game files.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parents[1] / 'art/cyber_zombie_mvp'
scene = bpy.context.scene
rig = bpy.data.objects['Cybercity_zombie_rig']
parts = [o for o in bpy.data.objects if 'attachment_bone' in o]
assert len(parts) >= 30
textures = [im for im in bpy.data.images if im.source == 'FILE' and im.type == 'IMAGE']
assert textures and all(im.packed_file for im in textures)
for ob in parts:
    assert len(ob.vertex_groups) == 1
    assert ob.vertex_groups[0].name == ob['attachment_bone']
    assert all(len(v.groups) == 1 and abs(v.groups[0].weight-1) < 1e-6 for v in ob.data.vertices)

report = {'kind':'Offline Blender evaluated-mesh check; not BO3 validation',
          'packed_textures':len(textures),'attachment_objects':len(parts),'poses':[]}
for name, angles in [
    ('rest', {}),
    ('head_turn', {'j_head':(0,0,28),'j_neck':(8,0,0)}),
    ('arm_flex', {'j_elbow_le':(30,12,0),'j_shoulder_le':(8,0,12)}),
    ('torso_leg', {'j_spine4':(10,0,8),'j_knee_ri':(22,0,0)}),
]:
    for pb in rig.pose.bones:
        pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0)
    for bone, degrees in angles.items():
        rig.pose.bones[bone].rotation_euler=[math.radians(a) for a in degrees]
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    worst = 0
    for ob in parts:
        bone = ob['attachment_bone']
        transform = rig.pose.bones[bone].matrix @ rig.data.bones[bone].matrix_local.inverted()
        ev=ob.evaluated_get(dg);mesh=ev.to_mesh()
        assert len(mesh.vertices)==len(ob.data.vertices)
        for raw, posed in zip(ob.data.vertices,mesh.vertices):
            expected=rig.matrix_world @ transform @ rig.matrix_world.inverted() @ ob.matrix_world @ raw.co
            actual=ev.matrix_world @ posed.co
            worst=max(worst,(actual-expected).length)
        ev.to_mesh_clear()
    assert worst < .002, (name,worst)
    report['poses'].append({'name':name,'max_attachment_error_units':worst})

for pb in rig.pose.bones:pb.rotation_euler=(0,0,0)
bpy.context.view_layer.update()
(OUT/'rig_check.json').write_text(json.dumps(report,indent=2)+'\n')
print('MVP RIG CHECK PASS',json.dumps(report),flush=True)
