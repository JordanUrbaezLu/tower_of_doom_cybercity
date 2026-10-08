"""Background review renders of the saved master (never saves over it).

blender.exe -b art/rampage_inducer_cyber/rampage_inducer_cyber.blend --python \
    tools/inducer_cyber/render_review.py -- <view> [frame] [samples]
Views: both, off, on, back, side, eye, top. Writes art/rampage_inducer_cyber/review/<view>.png
"""
import bpy, sys, math, json
from pathlib import Path
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
view = args[0] if args else 'both'
frame = int(args[1]) if len(args) > 1 else 40
samples = int(args[2]) if len(args) > 2 else 48
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'art/rampage_inducer_cyber/review'
OUT.mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene
VIEWS = {
    #        location              target            lens
    'both': ((128, -42, 64), (0, -42, 33), 32),
    'off':  ((74, 30, 56), (0, 0, 33), 40),
    'on':   ((74, -55, 56), (0, -85, 33), 40),
    'side': ((8, 92, 44), (0, 0, 33), 38),
    'back': ((-23.5, 0, 140), (0, 0, 30), 30),
    'eye':  ((96, 0, 60), (0, 0, 33), 30),
    'top':  ((40, 10, 110), (0, 0, 40), 38),
}
loc, target, lens = VIEWS[view]
cam_data = bpy.data.cameras.new('review cam'); cam_data.lens = lens; cam_data.clip_start = 0.5; cam_data.clip_end = 5000
cam = bpy.data.objects.new('review cam', cam_data); scene.collection.objects.link(cam)
cam.location = loc
cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
scene.camera = cam
if view == 'back':
    # hide the wall so the rear (conduits, junction) can be inspected
    for ob in scene.objects:
        if ob.name.startswith('RI studio | ') and ('wall' in ob.name or 'pilaster' in ob.name or 'cornice' in ob.name or 'lintel' in ob.name):
            ob.hide_render = True
scene.frame_set(frame)
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.eevee.taa_render_samples = samples
scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
scene.render.resolution_percentage = 100
scene.render.filepath = str(OUT/(view + '.png'))
bpy.ops.render.render(write_still=True)
(OUT/(view + '.json')).write_text(json.dumps({'view': view, 'frame': frame, 'samples': samples, 'camera': [loc, target, lens]}, indent=2))
print('REVIEW_RENDERED', scene.render.filepath)
