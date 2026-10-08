"""Live Blender review of the shipped binary and GDT, not a replacement mesh."""
import bpy, sys, re, math
from pathlib import Path
from mathutils import Vector, Quaternion
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path.home()/'AppData/Roaming/Blender Foundation/Blender/4.2/scripts/addons/BetterBetterBlenderCOD'))
from PyCoD import xmodel
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
gdt=(ROOT/'source_data/tod_bo6_inducer.gdt').read_text()
fields={name:dict(re.findall(r'"([^"\r\n]+)"\s*"([^"\r\n]*)"',body)) for name,kind,body in re.findall(r'"([^"\n]+)"\s*\(\s*"([^"\n]+).gdf"\s*\)\s*\{([^}]+)\}',gdt)}
scene=bpy.context.scene
def texture(nodes,name,linear=False):
    t=nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(ROOT/'model_export/tod_bo6_inducer/_images'/(name+'.png')),check_existing=True)
    t.image.reload()
    if linear:t.image.colorspace_settings.name='Non-Color'
    return t
def material(name):
    f=fields[name];mat=bpy.data.materials.new(name);mat.use_nodes=True
    nodes=mat.node_tree.nodes;links=mat.node_tree.links;p=nodes.get('Principled BSDF')
    color=texture(nodes,f['colorMap']);links.new(color.outputs['Color'],p.inputs['Base Color'])
    normal=texture(nodes,f['normalMap'],True);n=nodes.new('ShaderNodeNormalMap');links.new(normal.outputs['Color'],n.inputs['Color']);links.new(n.outputs['Normal'],p.inputs['Normal'])
    # BO3's gloss exponent is not Blender roughness; this is a look preview.
    p.inputs['Roughness'].default_value=.5
    p.inputs['Metallic'].default_value=.45 if f['surfaceType']=='metal' else .05
    if 'transparent' in f['materialType']:
        links.new(color.outputs['Alpha'],p.inputs['Alpha']);mat.surface_render_method='DITHERED'
    if 'emissive' in f['materialType']:
        em=texture(nodes,f['colorMap00']);mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1
        mix.inputs[2].default_value=tuple(float(x) for x in f['colorTint1'].split())
        links.new(em.outputs['Color'],mix.inputs[1]);links.new(mix.outputs[0],p.inputs['Emission Color'])
        p.inputs['Emission Strength'].default_value=float(f['scaleRGB'])
    return mat
model=xmodel.Model();model.LoadFile_Bin(str(ROOT/'model_export/tod_bo6_inducer/tod_inducer.xmodel_bin'),split_meshes=True)
# Camera looks from +Y, so positive world X is the left of the image.
for state,offset in [('OFF',10),('ON',-10)]:
    mats=[material(m.name+('_on' if state=='ON' and m.name+'_on' in fields else '')) for m in model.materials]
    for src in model.meshes:
        me=bpy.data.meshes.new(src.name);me.from_pydata([v.offset for v in src.verts],[],[[f.indices[i].vertex for i in (0,2,1)] for f in src.faces]);me.update()
        for mat in mats:me.materials.append(mat)
        uv=me.uv_layers.new();normals=[]
        for poly,face in zip(me.polygons,src.faces):
            poly.material_index=face.material_id;poly.use_smooth=True
            for li,i in zip(poly.loop_indices,(0,2,1)):
                c=face.indices[i];uv.data[li].uv=(c.uv[0],1-c.uv[1]);normals.append(c.normal)
        me.normals_split_custom_set(normals)
        ob=bpy.data.objects.new(state+' | '+src.name,me);scene.collection.objects.link(ob);ob.location.x=offset
    bpy.ops.object.text_add(location=(offset,11,.3));label=bpy.context.object;label.data.body=state;label.data.align_x='CENTER';label.data.size=1.5;label.rotation_euler=(math.pi/2,0,math.pi)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.12));floor=bpy.context.object
mat=bpy.data.materials.new('Studio charcoal');mat.diffuse_color=(.025,.028,.035,1);floor.data.materials.append(mat)
for pos,power,size in [((0,-25,45),14000,30),((-30,10,25),9000,20),((25,8,35),10000,20)]:
    bpy.ops.object.light_add(type='AREA',location=pos);ob=bpy.context.object;ob.data.energy=power;ob.data.shape='DISK';ob.data.size=size;ob.rotation_euler=(Vector((0,0,14))-ob.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(-42,90,38));camera=bpy.context.object;camera.rotation_euler=(Vector((0,0,13))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=52;scene.camera=camera
scene.world.color=(.13,.13,.13);scene.render.engine='CYCLES';scene.cycles.samples=32
scene.cycles.transparent_max_bounces=16
try:
    prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
    for device in prefs.devices:device.use=device.type=='OPTIX'
    scene.cycles.device='GPU'
except Exception:pass
scene.render.resolution_x=1200;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(ROOT/'art/rampage_inducer/native_review.png')
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/rampage_inducer/native_review.blend'))
bpy.ops.render.render(write_still=True)
print('INDUCER_NATIVE_PREVIEW_SAVED',scene.render.filepath)
