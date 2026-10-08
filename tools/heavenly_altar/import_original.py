"""Read-only native altar import for an unchanged Blender reference preview."""
import bpy, sys, re, json, hashlib
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/heavenly_altar'
OUT.mkdir(parents=True, exist_ok=True)
MT = Path('C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130')
SOURCE = MT / 'model_export/chaos_models/pack_a_punch/chaos_pack_a_punch.xmodel_bin'
GDT = MT / 'source_data/chaos_pack_a_punch.gdt'
sys.path.insert(0, str(Path.home() / 'AppData/Roaming/Blender Foundation/Blender/4.2/scripts/addons/BetterBetterBlenderCOD'))
from PyCoD import xmodel

entries = {}
for name, kind, body in re.findall(r'"([^"\r\n]+)"\s*\(\s*"([^"\r\n]+)"\s*\)\s*\{([^}]+)\}', GDT.read_text()):
    entries[name] = dict(re.findall(r'"([^"\r\n]+)"\s*"([^"\r\n]*)"', body))
model = xmodel.Model()
model.LoadFile_Bin(str(SOURCE), split_meshes=False)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
materials = []
loaded = []
for original in model.materials:
    name = 'chaos_pap_background' if original.name == 'xmaterial_3ca8db9c2b0c764' else original.name
    props = entries[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    ns, links = mat.node_tree.nodes, mat.node_tree.links
    bs = ns.get('Principled BSDF')
    bs.inputs['Roughness'].default_value = .6
    def texture(key, noncolor=False):
        asset = props.get(key, '')
        relative = entries.get(asset, {}).get('baseImage')
        if not relative:
            return None
        path = MT / relative.replace('\\\\', '/')
        assert path.is_file(), str(path)
        node = ns.new('ShaderNodeTexImage')
        node.image = bpy.data.images.load(str(path), check_existing=True)
        if noncolor:
            node.image.colorspace_settings.name = 'Non-Color'
        loaded.append(str(path))
        return node
    color = texture('colorMap')
    if color:
        links.new(color.outputs['Color'], bs.inputs['Base Color'])
        if 'transparent' in props.get('materialType', ''):
            links.new(color.outputs['Alpha'], bs.inputs['Alpha'])
            mat.surface_render_method = 'DITHERED'
    else:
        bs.inputs['Base Color'].default_value = (.025, .025, .025, 1)
    normal = texture('normalMap', True)
    if normal:
        nm = ns.new('ShaderNodeNormalMap')
        links.new(normal.outputs['Color'], nm.inputs['Color'])
        links.new(nm.outputs['Normal'], bs.inputs['Normal'])
    gloss = texture('cosinePowerMap', True)
    if gloss:
        inv = ns.new('ShaderNodeMath'); inv.operation = 'SUBTRACT'; inv.inputs[0].default_value = 1
        links.new(gloss.outputs['Color'], inv.inputs[1]); links.new(inv.outputs[0], bs.inputs['Roughness'])
    if 'scroll_3layer' in props.get('materialType', ''):
        layer = texture('colorMap00')
        if layer:
            links.new(layer.outputs['Color'], bs.inputs['Base Color'])
            links.new(layer.outputs['Color'], bs.inputs['Emission Color'])
            bs.inputs['Emission Strength'].default_value = 1
        mat['preview_limitation'] = 'Static first layer of BO3 animated three-layer shader; original game material unchanged.'
    mat['source_material'] = original.name
    materials.append(mat)

src = model.meshes[0]
mesh = bpy.data.meshes.new('Original altar geometry and UVs')
mesh.from_pydata([v.offset for v in src.verts], [], [[f.indices[i].vertex for i in (0,2,1)] for f in src.faces])
mesh.update()
ob = bpy.data.objects.new('Heavenly Gift Altar | ORIGINAL', mesh)
scene.collection.objects.link(ob)
for mat in materials: mesh.materials.append(mat)
uv = mesh.uv_layers.new(name='Original UV')
normals = []
for poly, face in zip(mesh.polygons, src.faces):
    poly.material_index = face.material_id
    poly.use_smooth = True
    for li, fi in zip(poly.loop_indices, (0,2,1)):
        fv = face.indices[fi]
        uv.data[li].uv = (fv.uv[0], 1-fv.uv[1])
        normals.append(fv.normal)
mesh.normals_split_custom_set(normals)
ob['source_file'] = str(SOURCE)
ob['source_sha256'] = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
ob['unchanged_source_geometry'] = True
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
lo = Vector(tuple(min(v.offset[i] for v in src.verts) for i in range(3)))
hi = Vector(tuple(max(v.offset[i] for v in src.verts) for i in range(3)))
center = (lo+hi)*.5
size = max(hi-lo)
orientation = Vector((.45,-1,.22)).to_track_quat('Z','Y')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.shading.type = 'MATERIAL'
            space.shading.studiolight_rotate_z = .5
            space.overlay.show_overlays = False
            space.clip_end = 10000
            space.region_3d.view_location = center
            space.region_3d.view_distance = size*1.7
            space.region_3d.view_rotation = orientation
            space.region_3d.view_perspective = 'PERSP'
scene.view_settings.view_transform = 'AgX'
scene['preview'] = 'Original Heavenly Gift Altar; geometry and source textures unchanged. BO3 scrolling shader represented by a static layer.'
scene['mcp_port'] = 9878
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'heavenly_altar_original.blend'))
report = {'source':str(SOURCE),'sha256':ob['source_sha256'],'vertices':len(src.verts),'triangles':len(src.faces),'materials':len(materials),'textures':len(set(loaded)),'bounds':[list(lo),list(hi)],'game_assets_modified':False,'shader_limitation':'BO3 animated three-layer background shown as a static first layer'}
(OUT/'original_import.json').write_text(json.dumps(report,indent=2))
print('ALTAR_ORIGINAL_IMPORTED',json.dumps(report))
