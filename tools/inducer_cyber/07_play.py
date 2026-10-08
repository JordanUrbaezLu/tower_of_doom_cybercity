"""Stage 07 - viewing: drive the rig, frame the cameras, start the live playback.

The timeline is one idle loop (360 frames at 30 fps = four ON loops), so the
playback loops seamlessly for both states. FRAME_DROP keeps real-time speed
even while the viewport renders.
"""
import sys, importlib, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import design_lib as D
importlib.reload(D)
import bpy
from mathutils import Vector

scene = bpy.context.scene
assert scene.get('mcp_port') == 9884
D.sync_rig()
scene.frame_start, scene.frame_end = 0, 359
scene.render.fps = 30
scene.sync_mode = 'FRAME_DROP'


def aim(name, loc, target, lens=None):
    ob = bpy.data.objects.get('RI studio | ' + name)
    if ob is None:
        return None
    ob.location = loc
    ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    if lens:
        ob.data.lens = lens
    return ob


cam = aim('camera OFF and ON', (128, -42, 64), (0, -42, 33), 32)
aim('camera hero', (82, 36, 60), (0, 0, 34), 40)
aim('camera player eye', (100, 0, 60), (0, 0, 33), 30)
scene.camera = cam
D.view_camera(0)

playing = False
for win in bpy.context.window_manager.windows:
    for area in win.screen.areas:
        if area.type == 'VIEW_3D':
            region = next(r for r in area.regions if r.type == 'WINDOW')
            with bpy.context.temp_override(window=win, area=area, region=region):
                if not bpy.context.screen.is_animation_playing:
                    bpy.ops.screen.animation_play()
                playing = bpy.context.screen.is_animation_playing
            break
D.save('07 play')
print('PLAY_OK playing=%s' % playing)
