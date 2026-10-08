"""Viewport-only framing; does not modify or save the validated art master."""
import bpy
assert bpy.context.scene.get('mcp_port')==9878
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active
            space.shading.type='RENDERED'
            space.shading.use_compositor='ALWAYS'
            space.region_3d.view_perspective='CAMERA'
            space.region_3d.view_camera_zoom=7
print('ALTAR_LIVE_VIEW_FRAMED')
