"""Render the actual exported binaries/atlas using the prototype studio."""
import sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path.home() / 'AppData/Roaming/Blender Foundation/Blender/4.2/scripts/addons/BetterBetterBlenderCOD'))
from PyCoD import xmodel
OUT = ROOT / 'art/cyber_zombie_mvp'
EXPORT = ROOT / 'model_export/tod_cyber_zombie'
scene = bpy.context.scene
for obj in list(scene.objects):
    if obj.type == 'MESH' and obj.name != 'Studio floor':
        bpy.data.objects.remove(obj, do_unlink=True)
mat = bpy.data.materials.new('mtl_tod_cyber_kit')
mat.use_nodes = True
nodes, links = mat.node_tree.nodes, mat.node_tree.links
shader = nodes.get('Principled BSDF')
def texture(suffix, noncolor=False):
    node = nodes.new('ShaderNodeTexImage')
    node.image = bpy.data.images.load(str(EXPORT / '_images' / ('i_tod_cyber_kit_' + suffix + '.png')))
    if noncolor:
        node.image.colorspace_settings.name = 'Non-Color'
    return node.outputs['Color']
links.new(texture('c'), shader.inputs['Base Color'])
links.new(texture('e'), shader.inputs['Emission Color'])
shader.inputs['Emission Strength'].default_value = 6
shader.inputs['Metallic'].default_value = .55
invert = nodes.new('ShaderNodeMath'); invert.operation = 'SUBTRACT'; invert.inputs[0].default_value = 1
links.new(texture('g', True), invert.inputs[1]); links.new(invert.outputs[0], shader.inputs['Roughness'])
normal = nodes.new('ShaderNodeNormalMap')
links.new(texture('n', True), normal.inputs['Color']); links.new(normal.outputs['Normal'], shader.inputs['Normal'])

def load(name, lod):
    # Validate native object references before flattening for the studio render.
    # Otherwise Blender can display faces that BO3 will silently discard.
    checked = xmodel.Model(); checked.LoadFile_Bin(str(EXPORT / (name + '_lod' + str(lod) + '.xmodel_bin')), split_meshes=True)
    model = xmodel.Model(); model.LoadFile_Bin(str(EXPORT / (name + '_lod' + str(lod) + '.xmodel_bin')), split_meshes=False)
    src = model.meshes[0]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([v.offset for v in src.verts], [], [[f.indices[i].vertex for i in (0, 2, 1)] for f in src.faces])
    mesh.update()
    obj = bpy.data.objects.new(name, mesh); scene.collection.objects.link(obj)
    for material in model.materials:
        key = 'TOD | charcoal distressed uniform' if material.name == 'mtl_c_zom_der_zombie_body2' else material.name
        mesh.materials.append(bpy.data.materials[key])
    uv = mesh.uv_layers.new(name='Exported UV')
    normals = []
    for poly, face in zip(mesh.polygons, src.faces):
        poly.material_index = face.material_id; poly.use_smooth = True
        for li, fi in zip(poly.loop_indices, (0, 2, 1)):
            fv = face.indices[fi]
            uv.data[li].uv = (fv.uv[0], 1-fv.uv[1]); normals.append(fv.normal)
    mesh.normals_split_custom_set(normals)
    return obj

objects = [load('tod_cyber_body', 0), load('tod_cyber_head', 0)]
scene.cycles.samples = 24
scene.render.resolution_x = 1050; scene.render.resolution_y = 1100
scene.camera.location = (36, -100, 70)
scene.camera.rotation_euler = (Vector((0, -1, 39))-scene.camera.location).to_track_quat('-Z', 'Y').to_euler()
scene.camera.data.ortho_scale = 80
scene.render.filepath = str(OUT / 'export_front.png')
bpy.ops.render.render(write_still=True)
for obj in objects:
    bpy.data.objects.remove(obj, do_unlink=True)
load('tod_cyber_body', 3); load('tod_cyber_head', 3)
scene.render.filepath = str(OUT / 'export_lod3.png')
bpy.ops.render.render(write_still=True)
print('CYBER_EXPORT_RENDER_OK', flush=True)
