import bpy, json, pathlib, hashlib
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[2]
OUT=ROOT/'art/cyber_reference_one_mcp';OUT.mkdir(parents=True,exist_ok=True)
source=ROOT/'art/cyber_zombie_roster/04_crown_carrier/04_crown_carrier.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
scene=bpy.context.scene
scene['reference_one_mcp']=True
scene['authoring_transport']='upstream Blender MCP execute_blender_code; isolated localhost:9877'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'reference_one.blend'))
rig=bpy.data.objects['Cybercity_zombie_rig']
print(json.dumps({'bones':{b.name:[list(b.head_local),list(b.tail_local)] for b in rig.data.bones if any(v in b.name for v in ('wrist','index','mid','ring','pinky','thumb','head','shoulder','elbow','ankle','knee'))},'base_meshes':[{ 'name':o.name,'vertices':len(o.data.vertices),'materials':[m.name if m else None for m in o.data.materials]} for o in scene.objects if o.type=='MESH' and 'attachment_bone' not in o]},indent=2))
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active;space.region_3d.view_distance=95
            space.region_3d.view_location=Vector((0,0,38))
            space.region_3d.view_rotation=Vector((0,-1,.15)).to_track_quat('Z','Y')
            space.shading.type='MATERIAL'
