import bpy
from pathlib import Path
scene=bpy.context.scene
assert scene.get('mcp_port')==9878
scene.render.engine='BLENDER_EEVEE_NEXT'
scene.eevee.taa_render_samples=64
scene.eevee.taa_samples=24
scene.eevee.use_raytracing=True
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active
            space.shading.type='RENDERED'
            space.shading.use_scene_world_render=True
            space.shading.use_scene_lights_render=True
            space.shading.use_compositor='ALWAYS'
            space.overlay.show_overlays=False
            space.region_3d.view_perspective='CAMERA'
            space.region_3d.view_camera_zoom=12
scene['live_preview']='Rendered Eevee with scene lights, materials, ray-traced reflections, shadows and compositor bloom'
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).resolve().parents[2]/'art/heavenly_altar/heavenly_altar_cyber.blend'))
print('ALTAR_RENDERED_VIEW_ENABLED')
