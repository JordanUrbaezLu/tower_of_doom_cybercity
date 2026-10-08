"""Inspect actual native source binaries and baked maps, including face culling."""
import bpy,sys,json,hashlib,re
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2];ART=ROOT/'art/heavenly_altar';OUT=ART/'game_preview';OUT.mkdir(exist_ok=True);EXPORT=ROOT/'model_export/tod_heavenly_altar';IMG=EXPORT/'_images'
sys.path.insert(0,str(Path.home()/'AppData/Roaming/Blender Foundation/Blender/4.2/scripts/addons/BetterBetterBlenderCOD'))
from PyCoD import xmodel
bpy.ops.wm.open_mainfile(filepath=str(ART/'heavenly_altar_cyber.blend'))
scene=bpy.context.scene
for ob in list(scene.objects):
    if ob.get('altar_design') or ob.get('preserved_original_reference'):bpy.data.objects.remove(ob,do_unlink=True)
hashes={'tod_heavenly_altar.gdt':hashlib.sha256((ROOT/'source_data/tod_heavenly_altar.gdt').read_bytes()).hexdigest()}
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['front']
def texture(n,name,linear=False):
    path=IMG/(name+'.png');hashes[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
    node=n.new('ShaderNodeTexImage');node.image=bpy.data.images.load(str(path),check_existing=True)
    if linear:node.image.colorspace_settings.name='Non-Color'
    return node
def cull(mat,surface):
    n,l=mat.node_tree.nodes,mat.node_tree.links;geo=n.new('ShaderNodeNewGeometry');tr=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader');l.new(geo.outputs['Backfacing'],mix.inputs[0]);l.new(surface,mix.inputs[1]);l.new(tr.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],n.get('Material Output').inputs[0])
mats=[]
for group in ('solid','portal','wings'):
    mat=bpy.data.materials.new('Native altar '+group);mat.use_nodes=True;n,l=mat.node_tree.nodes,mat.node_tree.links;bs=n.get('Principled BSDF')
    if group=='solid':
        l.new(texture(n,'i_tod_altar_c').outputs['Color'],bs.inputs['Base Color']);bs.inputs['Metallic'].default_value=.15;bs.inputs['Specular IOR Level'].default_value=.2
        e=texture(n,'i_tod_altar_e');l.new(e.outputs['Color'],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=8
        g=texture(n,'i_tod_altar_g',True);inv=n.new('ShaderNodeMath');inv.operation='SUBTRACT';inv.inputs[0].default_value=1;l.new(g.outputs[0],inv.inputs[1]);satin=n.new('ShaderNodeMapRange');satin.inputs['To Min'].default_value=.65;satin.inputs['To Max'].default_value=.9;l.new(inv.outputs[0],satin.inputs['Value']);l.new(satin.outputs[0],bs.inputs['Roughness'])
        normal=texture(n,'i_tod_altar_n',True);sep=n.new('ShaderNodeSeparateXYZ');comb=n.new('ShaderNodeCombineXYZ');inv=n.new('ShaderNodeMath');inv.operation='SUBTRACT';inv.inputs[0].default_value=1
        l.new(normal.outputs[0],sep.inputs[0]);l.new(sep.outputs[0],comb.inputs[0]);l.new(sep.outputs[2],comb.inputs[2]);l.new(sep.outputs[1],inv.inputs[1]);l.new(inv.outputs[0],comb.inputs[1]);nm=n.new('ShaderNodeNormalMap');l.new(comb.outputs[0],nm.inputs[1]);l.new(nm.outputs[0],bs.inputs['Normal']);surface=bs.outputs[0]
    elif group=='portal':
        # Static first-layer preview only. BO3 uses the original animated
        # three-layer shader and exact donor UVs/vertex colors in the binary.
        assert args[0]!='portal_unlit', 'Retired custom portal diagnostic; use front or side'
        gdt_path=ROOT/'source_data/chaos_pack_a_punch.gdt';gdt=gdt_path.read_text();hashes[gdt_path.name]=hashlib.sha256(gdt_path.read_bytes()).hexdigest()
        body=re.search(r'"i_chaos_pap_background_c"\s*\(\s*"image.gdf"\s*\)\s*\{([^}]+)\}',gdt).group(1);fields=dict(re.findall(r'"([^"\r\n]+)"\s*"([^"\r\n]*)"',body))
        path=Path('C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130')/fields['baseImage'].replace('\\\\','/')
        hashes[path.name]=hashlib.sha256(path.read_bytes()).hexdigest();tx=n.new('ShaderNodeTexImage');tx.image=bpy.data.images.load(str(path),check_existing=True)
        em=n.new('ShaderNodeEmission');l.new(tx.outputs[0],em.inputs[0]);em.inputs[1].default_value=1;surface=em.outputs[0]
    else:
        tx=texture(n,'i_tod_altar_wings_c');em=n.new('ShaderNodeEmission');l.new(texture(n,'i_tod_altar_wings_e').outputs[0],em.inputs[0]);em.inputs[1].default_value=3
        tr=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader');l.new(tx.outputs['Alpha'],mix.inputs[0]);l.new(tr.outputs[0],mix.inputs[1]);l.new(em.outputs[0],mix.inputs[2]);surface=mix.outputs[0]
    cull(mat,surface);mats.append(mat)
view=args[0];lod=6 if view=='lod6' else 0
if '--no-normal' in args:
    for mat in mats:
        bs=mat.node_tree.nodes.get('Principled BSDF')
        for link in list(bs.inputs['Normal'].links):mat.node_tree.links.remove(link)
    view='normal_control'
path=EXPORT/('tod_heavenly_altar_lod'+str(lod)+'.xmodel_bin');hashes[path.name]=hashlib.sha256(path.read_bytes()).hexdigest();model=xmodel.Model();model.LoadFile_Bin(str(path),split_meshes=True)
for index,src in enumerate(model.meshes):
    me=bpy.data.meshes.new(src.name);me.from_pydata([v.offset for v in src.verts],[],[[f.indices[i].vertex for i in (0,2,1)] for f in src.faces]);me.update();ob=bpy.data.objects.new(src.name,me);scene.collection.objects.link(ob)
    for mat in mats:me.materials.append(mat)
    uv=me.uv_layers.new(name='Native UV');normals=[]
    for poly,face in zip(me.polygons,src.faces):
        assert face.mesh_id==index;poly.material_index=face.material_id;poly.use_smooth=True
        for li,fi in zip(poly.loop_indices,(0,2,1)):
            c=face.indices[fi];uv.data[li].uv=(c.uv[0],1-c.uv[1]);normals.append(c.normal)
    me.normals_split_custom_set(normals)
if view=='side':loc,target,scale=(125,-190,92),(0,0,63),145
else:loc,target,scale=(25,-265,110),(0,0,65),146
cam=scene.camera;cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.threads_mode='FIXED';scene.render.threads=8;scene.render.filepath=str(OUT/('native_'+view+'.png'))
bpy.ops.render.render(write_still=True)
(OUT/('native_'+view+'.json')).write_text(json.dumps({'type':'Blender render of native source geometry; approximate satin shading and static original portal first layer; not an in-game screenshot','hashes':hashes,'lod':lod},indent=2))
print('ALTAR_NATIVE_RENDER_OK',view,flush=True)
