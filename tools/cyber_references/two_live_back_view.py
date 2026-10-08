"""Focus the live reference-two back assembly without changing the saved master."""
import bpy
from mathutils import Vector
scene=bpy.context.scene
assert scene.get('cyber_reference_number')==2
scene.camera.location=(31,95,67)
scene.camera.rotation_euler=(Vector((0,2,55.5))-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.camera.data.ortho_scale=33
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            s=area.spaces.active;s.region_3d.view_perspective='CAMERA'
            s.region_3d.view_camera_zoom=25;s.overlay.show_overlays=False;s.shading.type='MATERIAL'
print('LIVE_REFERENCE_TWO_BACK_READY; saved master untouched')
