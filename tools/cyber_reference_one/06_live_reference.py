"""Put the user's exact sheet beside the live 3D view, once per session."""
import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
scene=bpy.context.scene
assert scene.get('reference_one_mcp')
win=bpy.context.window;screen=win.screen
reference=bpy.data.images.get('CyberZombie1.png')
assert reference
editor=next((a for a in screen.areas if a.type=='IMAGE_EDITOR' and a.spaces.active.image==reference),None)
if editor is None:
    viewport=max((a for a in screen.areas if a.type=='VIEW_3D'),key=lambda a:a.width*a.height)
    with bpy.context.temp_override(window=win,area=viewport):bpy.ops.screen.area_split(direction='VERTICAL',factor=.68)
    editor=max((a for a in screen.areas if a.type=='VIEW_3D'),key=lambda a:a.x)
    editor.type='IMAGE_EDITOR';editor.spaces.active.image=reference
    region=next(r for r in editor.regions if r.type=='WINDOW')
    with bpy.context.temp_override(window=win,area=editor,region=region):bpy.ops.image.view_all(fit_view=True)
for area in screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_camera_zoom=3
        area.spaces.active.overlay.show_overlays=False
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/cyber_reference_one_mcp/reference_one.blend'))
print('LIVE_REFERENCE_PANEL_READY')
