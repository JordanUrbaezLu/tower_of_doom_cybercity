"""Frame both complete sword arms in the visible Blender viewport."""
import bpy
from mathutils import Vector
for window in bpy.context.window_manager.windows:
    views=[a for a in window.screen.areas if a.type=='VIEW_3D']
    images=[a for a in window.screen.areas if a.type=='IMAGE_EDITOR']
    if views and images:
        view=max(views,key=lambda a:a.width*a.height)
        reference=max(images,key=lambda a:a.width*a.height)
        if reference.width>view.width:
            concept=reference.spaces.active.image
            reference.type='VIEW_3D'
            view.type='IMAGE_EDITOR';view.spaces.active.image=concept
            region=next(r for r in view.regions if r.type=='WINDOW')
            with bpy.context.temp_override(window=window,area=view,region=region):
                bpy.ops.image.view_all(fit_view=True)
for area in (area for window in bpy.context.window_manager.windows for area in window.screen.areas):
    if area.type=='VIEW_3D':
        space=area.spaces.active
        space.shading.type='MATERIAL';space.overlay.show_overlays=False
        space.region_3d.view_perspective='ORTHO'
        space.region_3d.view_location=Vector((0,-1,38))
        space.region_3d.view_distance=75
        space.region_3d.view_rotation=(Vector((22,-110,62))-Vector((0,-1,38))).to_track_quat('Z','Y')
for ob in bpy.context.scene.objects:ob.select_set(False)
