"""Improve the user's live viewport framing without changing the saved export master."""
import bpy
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':area.spaces.active.region_3d.view_camera_zoom=25
print('LIVE_VIEW_FRAMED; master file unchanged')
