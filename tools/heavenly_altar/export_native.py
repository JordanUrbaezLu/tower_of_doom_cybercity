"""Bake the approved master and export map-owned native source geometry.

Background Blender only. Never modifies the live art master or installed assets.
"""
import bpy,bmesh,sys,json,hashlib,runpy,shutil,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];ART=ROOT/'art/heavenly_altar';STAGE=ART/'engine_kit';OUT=ROOT/'model_export/tod_heavenly_altar';IMG=OUT/'_images'
for p in (STAGE,OUT,IMG):p.mkdir(parents=True,exist_ok=True)
MASTER=ART/'heavenly_altar_cyber.blend';source_hash=hashlib.sha256(MASTER.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(MASTER));scene=bpy.context.scene
sys.path.insert(0,str(ROOT/'tools'));import cyber_material_bake as BAKE
BAKE.EMISSION_SCALE=8
parts=[o for o in scene.objects if o.get('altar_design') and not o.hide_render]
portal=next(o for o in parts if o.name=='Portal | recessed heavenly artwork')
wings=[o for o in parts if o.name.startswith('Wing | individually swept feather')]
main=[o for o in parts if o not in wings and o!=portal]
for ob in list(scene.objects):
    if ob not in parts:bpy.data.objects.remove(ob,do_unlink=True)
for o in parts:o.hide_set(False);o.hide_render=False
scene.render.engine='CYCLES';scene.cycles.samples=8;scene.render.threads_mode='FIXED';scene.render.threads=8
scene.render.bake.margin=4;scene.render.bake.use_selected_to_active=False
scene.render.bake.normal_g='NEG_Y'  # Native BO3 tangent normals use DirectX green.
# Preserve each source object's generated-coordinate space across the join/bake.
deps=bpy.context.evaluated_depsgraph_get()
evaluated=[(o,bpy.data.meshes.new_from_object(o.evaluated_get(deps),preserve_all_data_layers=True,depsgraph=deps)) for o in parts]
for ob,geometry in evaluated:
    ob.data=geometry
    for mod in list(ob.modifiers):ob.modifiers.remove(mod)
    attr=geometry.attributes.new('altar_generated','FLOAT_VECTOR','POINT')
    lo=[min(v.co[i] for v in geometry.vertices) for i in range(3)];hi=[max(v.co[i] for v in geometry.vertices) for i in range(3)]
    attr.data.foreach_set('vector',[((v.co[i]-lo[i])/(hi[i]-lo[i])) if hi[i]-lo[i]>1e-8 else .5 for v in geometry.vertices for i in range(3)])
    bm=bmesh.new();bm.from_mesh(geometry);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(geometry);bm.free();geometry.update()
    if ob==portal and sum(p.normal.y for p in geometry.polygons)>0:
        bm=bmesh.new();bm.from_mesh(geometry);bmesh.ops.reverse_faces(bm,faces=list(bm.faces));bm.to_mesh(geometry);bm.free()
for mat in {m for o in main for m in o.data.materials if m}:
    n,l=mat.node_tree.nodes,mat.node_tree.links
    attr=n.new('ShaderNodeAttribute');attr.attribute_name='altar_generated'
    for node in list(n):
        if node.type in ('TEX_NOISE','TEX_VORONOI','TEX_WAVE') and not node.inputs['Vector'].is_linked:l.new(attr.outputs['Vector'],node.inputs['Vector'])

def select(ob):
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
def join(objects,name):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();ob=bpy.context.object;ob.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return ob
kit=join(main,'Altar native solid kit');kit.data.calc_loop_triangles();before=len(kit.data.loop_triangles)
mod=kit.modifiers.new('Native close silhouette reduction','DECIMATE');mod.ratio=min(1,85000/before);mod.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=mod.name)
print('ALTAR_SOLID_REDUCTION',before,len(kit.data.polygons),flush=True)
select(kit);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.12,island_margin=.0003,area_weight=.3,correct_aspect=True);bpy.ops.object.mode_set(mode='OBJECT')
materials=list(kit.data.materials)
def image_target(mats,prefix,suffix,size):
    im=bpy.data.images.new(prefix+'_'+suffix,width=size,height=size,alpha=False)
    im.colorspace_settings.name='Non-Color' if suffix in ('n','g') else 'sRGB'
    for mat in mats:
        node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=im;mat.node_tree.nodes.active=node
    return im
def save_image(im):
    im.filepath_raw=str(IMG/(im.name+'.png'));im.file_format='PNG';im.save()
im=image_target(materials,'i_tod_altar','n',4096);bpy.ops.object.bake(type='NORMAL',normal_space='TANGENT');save_image(im);print('ALTAR_BAKED n',flush=True)
for suffix in ('c','s','g','e'):
    im=image_target(materials,'i_tod_altar',suffix,4096)
    for mat in materials:BAKE.wire_channel(mat,suffix)
    bpy.ops.object.bake(type='EMIT');save_image(im);print('ALTAR_BAKED',suffix,flush=True)

def geometry(ob,group,material):
    me=ob.data;me.calc_loop_triangles();data={'bone':'tag_origin','material':material,'verts':[list(ob.matrix_world@v.co) for v in me.vertices],'faces':[]}
    nm=ob.matrix_world.to_3x3().inverted().transposed()
    for tri in me.loop_triangles:
        if tri.area<1e-9:continue
        corners=[]
        for li in (tri.loops[0],tri.loops[2],tri.loops[1]):
            normal=(nm@me.corner_normals[li].vector).normalized()
            if normal.length_squared<.9:normal=(nm@tri.normal).normalized()
            assert normal.length_squared>.9
            uv=me.uv_layers.active.data[li].uv if me.uv_layers else (.5,.5)
            corners.append({'v':me.loops[li].vertex_index,'n':list(normal),'uv':[uv[0],1-uv[1]]})
        data['faces'].append(corners)
    from cyber_reference_one.native_geometry import clean
    clean(data,min_altitude=.001)
    (STAGE/(group+'_lod0.json')).write_text(json.dumps(data,separators=(',',':')))
    return len(data['faces'])
counts={'solid':geometry(kit,'solid','mtl_tod_altar')}
# Portal emission is baked separately; its figures remain sharp without competing for the solid atlas.
select(portal);material=portal.data.materials[0];n,l=material.node_tree.nodes,material.node_tree.links
old=next(node for node in n if node.type=='OUTPUT_MATERIAL').inputs['Surface'].links[0].from_node
assert old.type=='EMISSION'
emit=n.new('ShaderNodeEmission');emit.inputs[0].default_value=(0,0,0,1)
if old.inputs[0].is_linked:l.new(old.inputs[0].links[0].from_socket,emit.inputs[0])
else:emit.inputs[0].default_value=old.inputs[0].default_value
div=n.new('ShaderNodeMath');div.operation='DIVIDE';div.inputs[1].default_value=8
if old.inputs[1].is_linked:l.new(old.inputs[1].links[0].from_socket,div.inputs[0])
else:div.inputs[0].default_value=old.inputs[1].default_value
l.new(div.outputs[0],emit.inputs[1]);l.new(emit.outputs[0],next(node for node in n if node.type=='OUTPUT_MATERIAL').inputs['Surface'])
# Original texture lookup stays on the old UV layer while the target gets its own atlas UV.
old_uv=portal.data.uv_layers.active.name;uvnode=n.new('ShaderNodeUVMap');uvnode.uv_map=old_uv
for node in n:
    if node.type=='TEX_IMAGE':l.new(uvnode.outputs[0],node.inputs['Vector'])
portal.data.uv_layers.new(name='Native portal atlas');portal.data.uv_layers.active_index=len(portal.data.uv_layers)-1;portal.data.uv_layers.active.active_render=True
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.2,island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT')
im=image_target([material],'i_tod_altar_portal','e',1024);bpy.ops.object.bake(type='EMIT');save_image(im);counts['portal']=geometry(portal,'portal','mtl_tod_altar_portal');print('ALTAR_PORTAL_BAKED',flush=True)
wing=join(wings,'Altar native wing membranes')
counts['wings']=geometry(wing,'wings','mtl_tod_altar_wings')
# A small RGBA image supplies native wing opacity and emission; all facets share it.
for suffix,color in [('c',(.02,.35,1,.36)),('e',(.02,.35,1,1))]:
    encode=lambda v:12.92*v if v<=.0031308 else 1.055*v**(1/2.4)-.055
    im=bpy.data.images.new('i_tod_altar_wings_'+suffix,width=32,height=32,alpha=True);im.colorspace_settings.name='sRGB';im.generated_color=(*(encode(v) for v in color[:3]),color[3]);save_image(im)
(STAGE/'lod_counts.json').write_text(json.dumps({'0':counts},indent=2))
runpy.run_path(str(ROOT/'tools/cyber_reference_one/reduce_game_lods.py'),run_name='__main__',init_globals={'CYBER_LOD_SOURCE':STAGE,'CYBER_LOD_OUTPUT':STAGE,'CYBER_LOD_AREA_FLOORS':{'solid':(0,.015,.15,.65,1.7,4,9),'wings':(0,0,0,0,0,0,0),'portal':(0,0,0,0,0,0,0)}})
manifest={'master':str(MASTER.relative_to(ROOT)),'master_sha256':source_hash,'emission_scale':8,'normal_convention':'DirectX -Y','groups':{'solid':'mtl_tod_altar','portal':'mtl_tod_altar_portal','wings':'mtl_tod_altar_wings'},'textures':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in IMG.glob('*.png')},'lod_counts':json.loads((STAGE/'lod_counts.json').read_text()),'solid_atlas':4096,'portal_atlas':1024,'wing_atlas':32}
(STAGE/'source_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print('ALTAR_EXPORT_OK',json.dumps(manifest['lod_counts']),flush=True)
