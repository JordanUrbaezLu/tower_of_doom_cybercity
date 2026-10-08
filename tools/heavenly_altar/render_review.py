"""Render the saved MCP-authored altar without blocking its live window."""
import bpy,sys,hashlib,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'art/heavenly_altar'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'heavenly_altar_cyber.blend'))
scene=bpy.context.scene
scene.render.engine='CYCLES'
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['front']
view=args[0]
if view=='detail':loc,target,scale=(17,-170,110),(0,-15,101),62
elif view=='side':loc,target,scale=(125,-190,92),(0,0,63),145
else:loc,target,scale=(25,-265,110),(0,0,65),146
cam=scene.camera;cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
scene.render.filepath=str(OUT/('cyber_'+view+'.png'))
bpy.ops.render.render(write_still=True)
(OUT/('cyber_'+view+'.json')).write_text(json.dumps({'view':view,'master_sha256':hashlib.sha256((OUT/'heavenly_altar_cyber.blend').read_bytes()).hexdigest(),'type':'Blender render; not an in-game screenshot'},indent=2))
print('ALTAR_RENDER_OK',view,flush=True)
