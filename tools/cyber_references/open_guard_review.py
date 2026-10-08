"""Frame the armored head in the user's visible Blender window."""
import bpy
from mathutils import Vector
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        space = area.spaces.active
        space.shading.type = 'MATERIAL'
        space.overlay.show_overlays = False
        space.region_3d.view_perspective = 'ORTHO'
        space.region_3d.view_location = Vector((0,-1,66))
        space.region_3d.view_distance = 22
        space.region_3d.view_rotation = (Vector((19,-62,70))-Vector((0,-1,66))).to_track_quat('Z','Y')
bpy.ops.object.select_all(action='DESELECT')
