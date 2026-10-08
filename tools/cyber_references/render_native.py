"""Review actual installed source binaries and baked maps in Blender's studio."""
import bpy,sys,json,hashlib,re
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
word=sys.argv[sys.argv.index('--')+1]
FOLDER=ROOT/('art/cyber_reference_'+word+'_mcp');OUT=FOLDER/'game_preview';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(FOLDER/('reference_'+word+'.blend')))
if word=='two':
    with bpy.data.libraries.load(str(ROOT/'art/cyber_zombie_roster/02_signal_trooper/02_signal_trooper.blend'),link=False) as (src,dst):
        dst.materials=[n for n in src.materials if n.startswith('Roster | mtl_c_zom_der_zombie_head2')]
sys.path.insert(0,str(Path.home()/'AppData/Roaming/Blender Foundation/Blender/4.2/scripts/addons/BetterBetterBlenderCOD'))
from PyCoD import xmodel
EXPORT=ROOT/'model_export/tod_cyber_zombie';scene=bpy.context.scene
variant='relay' if word=='two' else 'sprinter';kitname='mtl_tod_roster_'+variant
for ob in list(scene.objects):
    if ob.type=='MESH' and ob.name!='Studio floor':bpy.data.objects.remove(ob,do_unlink=True)
mat=bpy.data.materials.new(kitname);mat.use_nodes=True
nodes,links=mat.node_tree.nodes,mat.node_tree.links;shader=nodes.get('Principled BSDF');hashes={}
def texture(suffix,noncolor=False):
    path=EXPORT/'_images'/('i_tod_roster_'+variant+'_'+suffix+'.png');hashes[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
    node=nodes.new('ShaderNodeTexImage');node.image=bpy.data.images.load(str(path))
    if noncolor:node.image.colorspace_settings.name='Non-Color'
    return node.outputs['Color']
links.new(texture('c'),shader.inputs['Base Color']);links.new(texture('e'),shader.inputs['Emission Color'])
gdt=(ROOT/'source_data/tod_cyber_roster.gdt').read_text()
material_fields=re.search(r'"'+kitname+r'"\s*\(\s*"material.gdf"\s*\)\s*\{([^}]+)\}',gdt).group(1)
emission_scale=float(re.search(r'"scaleRGB"\s*"([^"]+)"',material_fields).group(1))
shader.inputs['Emission Strength'].default_value=emission_scale;shader.inputs['Metallic'].default_value=.55
invert=nodes.new('ShaderNodeMath');invert.operation='SUBTRACT';invert.inputs[0].default_value=1
links.new(texture('g',True),invert.inputs[1]);links.new(invert.outputs[0],shader.inputs['Roughness'])
normal=nodes.new('ShaderNodeNormalMap');links.new(texture('n',True),normal.inputs['Color']);links.new(normal.outputs[0],shader.inputs['Normal'])
def load(name,lod=0,rotate=False):
    path=EXPORT/(name+'_lod'+str(lod)+'.xmodel_bin');hashes[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
    checked=xmodel.Model();checked.LoadFile_Bin(str(path),split_meshes=True)
    for i,mesh in enumerate(checked.meshes):assert all(f.mesh_id==i for f in mesh.faces)
    model=xmodel.Model();model.LoadFile_Bin(str(path),split_meshes=False);src=model.meshes[0]
    convert=lambda p:(p[1],-p[0],p[2]) if rotate else p
    mesh=bpy.data.meshes.new(name);mesh.from_pydata([convert(v.offset) for v in src.verts],[],[[f.indices[i].vertex for i in (0,2,1)] for f in src.faces]);mesh.update()
    ob=bpy.data.objects.new(name,mesh);scene.collection.objects.link(ob)
    for m in model.materials:
        material=mat if m.name==kitname else bpy.data.materials.get('Roster | '+m.name)
        assert material,m.name;mesh.materials.append(material)
    uv=mesh.uv_layers.new(name='Native UV');normals=[]
    for poly,face in zip(mesh.polygons,src.faces):
        poly.material_index=face.material_id;poly.use_smooth=True
        for li,fi in zip(poly.loop_indices,(0,2,1)):
            fv=face.indices[fi];uv.data[li].uv=(fv.uv[0],1-fv.uv[1]);normals.append(convert(fv.normal))
    mesh.normals_split_custom_set(normals);return ob
objects=[load('tod_cyber_relay_body' if word=='two' else 'tod_cyber_sprinter',rotate=word=='three'),load('tod_cyber_bhead2' if word=='two' else 'tod_cyber_sprinter_head2')]
native_scale=1.33 if word=='three' else 1.0
for ob in objects:ob.scale=(native_scale,)*3
high_quality='--high-quality' in sys.argv
scene.render.engine='CYCLES';scene.cycles.samples=128 if high_quality else 24;scene.cycles.use_denoising=True;scene.render.threads_mode='FIXED';scene.render.threads=4
if '--gpu' in sys.argv:
    prefs=bpy.context.preferences.addons['cycles'].preferences
    prefs.compute_device_type='OPTIX';prefs.get_devices()
    selected=[d for d in prefs.devices if d.type=='OPTIX']
    assert selected,'OptiX GPU requested but unavailable'
    for d in prefs.devices:d.use=d in selected
    scene.cycles.device='GPU'
    print('NATIVE_PREVIEW_GPU',[d.name for d in selected],flush=True)
if '--eevee' in sys.argv:
    scene.render.engine='BLENDER_EEVEE_NEXT';scene.eevee.taa_render_samples=128
scene.render.resolution_x=1600 if high_quality else 1000;scene.render.resolution_y=1760 if high_quality else 1100;scene.render.resolution_percentage=100
views=[('front',(30,-126,62),(0,-.5,37),86),('arm',(43,-52,59),(17,-10,46),20),('head',(19,-62,68),(0,-.5,67),18),('back',(38,116,66),(0,1,37),86)]
if word=='three':
    views.append(('back_detail',(31,95,67),(0,2,56),30))
    views.append(('head_lod6',(19,-62,68),(0,-.5,67),18))
    views.append(('front_dark',(30,-126,62),(0,-.5,37),86))
    order=['head','front','back_detail','arm','back','head_lod6','front_dark'];views.sort(key=lambda v:order.index(v[0]))
if word=='two':
    views.append(('back_detail',(31,95,67),(0,2,56),30))
    order=['back_detail','back','head','front','arm'];views.sort(key=lambda v:order.index(v[0]))
    views.append(('lod3',(30,-126,62),(0,-.5,37),86))
    views.append(('back_lod3',(38,116,66),(0,1,37),86))
    views.append(('back_lod6',(38,116,66),(0,1,37),86))
current_lod=0
studio_lights={o.name:o.data.energy for o in scene.objects if o.type=='LIGHT'}
world_background=next((n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND'),None) if scene.world and scene.world.use_nodes else None
world_strength=world_background.inputs['Strength'].default_value if world_background else None
for view,loc,target,scale in views:
    requested_lod=6 if view.endswith('lod6') else (3 if view.endswith('lod3') else 0)
    if requested_lod!=current_lod:
        for ob in objects:bpy.data.objects.remove(ob,do_unlink=True)
        if word=='two':
            objects=[load('tod_cyber_relay_body',requested_lod),load('tod_cyber_bhead2',requested_lod)]
        else:
            # The armored body has one authored source and native generated LODs.
            objects=[load('tod_cyber_sprinter',rotate=True),load('tod_cyber_sprinter_head2',requested_lod)]
            for ob in objects:ob.scale=(native_scale,)*3
        current_lod=requested_lod
    dark=view=='front_dark'
    for name,energy in studio_lights.items():scene.objects[name].data.energy=energy*(.06 if dark else 1)
    if world_background:world_background.inputs['Strength'].default_value=world_strength*(.05 if dark else 1)
    scene.camera.location=Vector(loc)*native_scale;scene.camera.rotation_euler=(Vector(target)*native_scale-scene.camera.location).to_track_quat('-Z','Y').to_euler();scene.camera.data.ortho_scale=scale*native_scale
    scene.render.filepath=str(OUT/('export_'+view+'.png'));bpy.ops.render.render(write_still=True)
    (OUT/('export_'+view+'.json')).write_text(json.dumps({'view':view,'configured_model_scale':native_scale,'native_material_emission_scale':emission_scale,
        'lighting_preset':'dim studio; visibility study, not native game lighting' if dark else 'reference studio',
        'head_source_lod':requested_lod,'source_binary_and_texture_hashes':hashes,
        'image_sha256':hashlib.sha256(Path(scene.render.filepath).read_bytes()).hexdigest(),'render_engine':scene.render.engine,
        'render_device':scene.cycles.device,
        'samples':scene.cycles.samples if scene.render.engine=='CYCLES' else scene.eevee.taa_render_samples,
        'resolution':[scene.render.resolution_x,scene.render.resolution_y],
        'type':'Blender render of native source binaries and baked maps; not an in-game screenshot'},indent=2))
    print('NATIVE_PREVIEW_OK',word,view,flush=True)
