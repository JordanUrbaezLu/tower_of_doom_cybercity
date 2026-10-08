"""Render saved MCP-authored master without blocking the user's interactive session."""
import bpy, sys, json, hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'art/cyber_reference_one_mcp'
args=sys.argv[sys.argv.index('--')+1:];view=args[0]
source_hash=hashlib.sha256((OUT/'reference_one.blend').read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(OUT/'reference_one.blend'))
scene=bpy.context.scene
views={
 'front':((30,-126,62),(0,-.5,36),81),
 'back':((38,116,66),(0,1,37),81),
 'head':((19,-62,68),(0,-.5,66),13.5),
 'arm':((43,-52,59),(17,-10,46),19),
 'back_detail':((31,95,67),(0,2,54),23),
 'leg':((30,-85,30),(5,1,15),29),
 'chest':((18,-100,65),(0,-1,53.5),22)
}
loc,target,scale=views[view];cam=scene.camera;cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=scale
scene.render.filepath=str(OUT/(view+'.png'));bpy.ops.render.render(write_still=True)
(OUT/(view+'.render.json')).write_text(json.dumps({'view':view,'master_sha256':source_hash,'stage':scene.get('reference_one_stage'),'equipment_objects':sum('attachment_bone' in o for o in scene.objects),'image_sha256':hashlib.sha256((OUT/(view+'.png')).read_bytes()).hexdigest()},indent=2))
print('REFERENCE_ONE_RENDER_OK',view,flush=True)
