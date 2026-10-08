"""Geometry review of the six actual complete native heads (studio lighting)."""
import sys,math
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from build_staff_assembly import model,OUT
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
metal=bpy.data.materials.new('Geometry review - neutral metal');metal.use_nodes=True
p=metal.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.19,.22,.25,1);p.inputs['Metallic'].default_value=.65;p.inputs['Roughness'].default_value=.35
for el,z in [('fire',31),('lightning',0)]:
    crystal=bpy.data.materials.new(el+' crystal');crystal.use_nodes=True;p=crystal.node_tree.nodes.get('Principled BSDF')
    color=(1,.18,.025,1) if el=='fire' else (.4,.025,1,1)
    p.inputs['Base Color'].default_value=color;p.inputs['Emission Color'].default_value=color;p.inputs['Emission Strength'].default_value=2
    for form,x in [('view',-27),('world',0),('pap',27)]:
        m=model(OUT/f'tod_staff_{el}_complete_{form}.XMODEL_BIN')
        for src in m.meshes:
            points=[(v.offset[1]+x,v.offset[2],v.offset[0]+z) for v in src.verts]
            faces=[tuple(f.indices[i].vertex for i in (0,2,1)) for f in src.faces]
            mesh=bpy.data.meshes.new(el+' '+form);mesh.from_pydata(points,[],faces);mesh.update()
            ob=bpy.data.objects.new(mesh.name,mesh);scene.collection.objects.link(ob)
            mat=crystal if 'crystal' in m.materials[src.faces[0].material_id].name else metal
            mesh.materials.append(mat)
            normals=[]
            for poly,f in zip(mesh.polygons,src.faces):
                poly.use_smooth=mat==metal
                for i in (0,2,1):n=f.indices[i].normal;normals.append((n[1],n[2],n[0]))
            mesh.normals_split_custom_set(normals)
        bpy.ops.object.text_add(location=(x,-5,z-4));ob=bpy.context.object;ob.data.body=el.upper()+' / '+{'view':'FIRST PERSON','world':'THIRD PERSON','pap':'UPGRADED'}[form];ob.data.align_x='CENTER';ob.data.size=1.05;ob.rotation_euler=(math.pi/2,0,0)
for pos,power,size in [((-30,-35,75),40000,35),((40,-20,45),30000,25),((0,25,65),40000,30)]:
    bpy.ops.object.light_add(type='AREA',location=pos);ob=bpy.context.object;ob.data.energy=power;ob.data.shape='DISK';ob.data.size=size;ob.rotation_euler=(Vector((0,0,25))-ob.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(22,-150,52));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,24))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=86;scene.camera=cam
scene.world.color=(.045,.045,.05);scene.render.engine='CYCLES';scene.cycles.samples=32
try:
    prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
    for device in prefs.devices:device.use=device.type=='OPTIX'
    scene.cycles.device='GPU'
except Exception:pass
scene.render.resolution_x=1500;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
dest=ROOT/'art/staff_assembly';dest.mkdir(exist_ok=True,parents=True)
scene.render.filepath=str(dest/'geometry_review.png');bpy.ops.wm.save_as_mainfile(filepath=str(dest/'geometry_review.blend'));bpy.ops.render.render(write_still=True)
print('STAFF_ASSEMBLY_PREVIEW',scene.render.filepath)
