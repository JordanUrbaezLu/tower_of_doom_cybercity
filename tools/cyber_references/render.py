"""Actual Blender renders of saved MCP-authored studies; never changes the master."""
import bpy,sys,json,hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
args=sys.argv[sys.argv.index('--')+1:];eevee='--eevee' in args;args=[a for a in args if a!='--eevee'];word=args[0];views=args[1:] or ['front','back','head','arm','leg','chest','back_detail']
OUT=ROOT/('art/cyber_reference_'+word+'_mcp');master=OUT/('reference_'+word+'.blend')
bpy.ops.wm.open_mainfile(filepath=str(master));scene=bpy.context.scene
sourcehash=hashlib.sha256(master.read_bytes()).hexdigest()
settings={
 'front':((30,-126,62),(0,-.5,36),83),'back':((38,116,66),(0,1,37),83),
 'head':((19,-62,68),(0,-.5,66),16),'arm':((43,-52,59),(17,-10,46),20),
 'leg':((30,-85,30),(5,1,15),30),'chest':((18,-100,65),(0,-1,53.5),25),
 'back_detail':((31,95,67),(0,2,56),30)}
if word=='three':settings['head']=((19,-62,70),(0,-.5,67),19)
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
if eevee:scene.render.engine='BLENDER_EEVEE_NEXT';scene.eevee.taa_render_samples=128
scene.render.threads_mode='FIXED';scene.render.threads=4
scene.render.resolution_x=1000;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
for view in views:
    loc,target,scale=settings[view];cam=scene.camera;cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=scale
    scene.render.filepath=str(OUT/(view+'.png'));bpy.ops.render.render(write_still=True)
    (OUT/(view+'.render.json')).write_text(json.dumps({'view':view,'master_sha256':sourcehash,'stage':scene.get('cyber_authoring_stage'),'image_sha256':hashlib.sha256((OUT/(view+'.png')).read_bytes()).hexdigest()},indent=2))
    print('REFERENCE_RENDER_OK',word,view,flush=True)
