"""Show the corrected backpack in the open session without changing the master."""
import bpy
from mathutils import Vector
scene=bpy.context.scene
assert scene.get('cyber_reference_number')==3
scene.camera.location=(29,104,66)
scene.camera.rotation_euler=(Vector((0,3,55))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.camera.data.ortho_scale=32
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active;space.region_3d.view_perspective='CAMERA'
            space.region_3d.view_camera_zoom=25
            space.overlay.show_overlays=False;space.shading.type='MATERIAL'
print('LIVE_BACKPACK_VIEW_READY; master file untouched')
