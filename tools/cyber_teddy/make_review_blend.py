"""Blender 4.2: art/cyber_teddy/cyber_teddy_review.blend - the Cyber Teddy to look at in Blender.

Three bears on one floor, in BO3 units shown as inches (1 unit = 1 inch):
  left   the OLD stock bear p7_zm_teddybear (LOD0 from the tools, its own texture)
  middle the CYBER TEDDY AS THE GAME HAS IT - rebuilt from the WRITTEN
         model_export/tod_cyber_teddy/tod_cyber_teddy.xmodel_bin with its colour + glow
         maps, stood on the floor at TOD_SECRET_LIFT like the hunt places it
  right  the fan's ORIGINAL FBX at the same height, rig + walk (Space plays it; not used in game)
Opens in Material Preview. Run:
  "C:\\Program Files\\Blender Foundation\\Blender 4.2\\blender.exe" -b --factory-startup
      --python tools/cyber_teddy/make_review_blend.py
"""
import bpy
import math
import sys
from pathlib import Path
from mathutils import Euler, Vector

sys.path.append(r'C:\Users\jorda\AppData\Roaming\Blender Foundation\Blender\4.2\scripts\addons')
from BetterBetterBlenderCOD.PyCoD import xmodel

REPO = Path(r'C:\Users\jorda\Repositories\tower_of_doom_cybercity')
TOOLS = Path(r'C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130')
TEDDY_BIN = REPO/'model_export/tod_cyber_teddy/tod_cyber_teddy.xmodel_bin'
TEDDY_C = REPO/'model_export/tod_cyber_teddy/_images/i_tod_cyber_teddy_c.png'
TEDDY_E = REPO/'model_export/tod_cyber_teddy/_images/i_tod_cyber_teddy_e.png'
STOCK_BIN = TOOLS/'model_export/t7_props_zombie/p7_zm_teddybear/p7_zm_teddybear_lod0.xmodel_bin'
STOCK_C = TOOLS/'model_export/t7_props/p7_zm_teddybear/p7_zm_teddybear_c.tif'
SRC_FBX = REPO/'art/cyber_teddy/source/cyber_teddy_walking.fbx'
OUT = REPO/'art/cyber_teddy/cyber_teddy_review.blend'
TEDDY_LIFT = 14.0     # TOD_SECRET_LIFT (v19.64)
STOCK_LIFT = 14.2     # the stock bear's (v18.96f)
GAP = 36.0


def image_material(name, color, emission=None, strength=2.0, roughness=0.55, specular=0.5):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes['Principled BSDF']
    tc = nt.nodes.new('ShaderNodeTexImage')
    tc.image = bpy.data.images.load(str(color))
    nt.links.new(tc.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Specular IOR Level'].default_value = specular
    if emission is not None:
        te = nt.nodes.new('ShaderNodeTexImage')
        te.image = bpy.data.images.load(str(emission))
        nt.links.new(te.outputs['Color'], bsdf.inputs['Emission Color'])
        bsdf.inputs['Emission Strength'].default_value = strength
    return mat


def object_from_bin(path, name, material, file_normals=True):
    """Every mesh of an xmodel_bin as one object; the export winding and V flip undone.
    file_normals=False: Blender's own smooth normals (the stock bear's fur cards carry
    card-plane normals that read as white streaks under the preview light)."""
    model = xmodel.Model()
    model.LoadFile_Bin(str(path))
    verts, faces, uvs, normals = [], [], [], []
    for mesh in model.meshes:
        base = len(verts)
        verts += [tuple(v.offset) for v in mesh.verts]
        for f in mesh.faces:
            corners = (f.indices[0], f.indices[2], f.indices[1])
            faces.append([base + c.vertex for c in corners])
            uvs.append([(c.uv[0], 1 - c.uv[1]) for c in corners])
            normals.append([tuple(c.normal) for c in corners])
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    layer = me.uv_layers.new(name='uv')
    loop_normals = []
    for poly, fuv, fn in zip(me.polygons, uvs, normals):
        poly.use_smooth = True
        for li, uv in zip(poly.loop_indices, fuv):
            layer.data[li].uv = uv
        loop_normals += fn
    if file_normals:
        me.normals_split_custom_set(loop_normals)     # the game's own normals
    me.materials.append(material)
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj, len(verts), len(faces)


def label(text, x, z):
    cu = bpy.data.curves.new(text, 'FONT')
    cu.body = text
    cu.size = 2.4
    cu.align_x = 'CENTER'
    obj = bpy.data.objects.new('label ' + text, cu)
    obj.location = (x, 0, z)
    obj.rotation_euler = (math.radians(90), 0, 0)          # stand up, read from the front (-Y)
    mat = bpy.data.materials.new('label')
    mat.use_nodes = True
    mat.node_tree.nodes['Principled BSDF'].inputs['Emission Color'].default_value = (0.8, 0.9, 1, 1)
    mat.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value = 1.5
    cu.materials.append(mat)
    bpy.context.scene.collection.objects.link(obj)


def main():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    scene = bpy.context.scene
    us = scene.unit_settings
    us.system, us.length_unit, us.scale_length = 'IMPERIAL', 'INCHES', 0.0254   # 1 Blender unit = 1 BO3 unit

    # left: the stock bear it replaced
    stock, sv, sf = object_from_bin(STOCK_BIN, 'OLD stock bear (p7_zm_teddybear)',
                                    image_material('stock bear', STOCK_C, roughness=1.0, specular=0.1),
                                    file_normals=False)
    stock.location = (-GAP, 0, STOCK_LIFT)
    # middle: the Cyber Teddy exactly as the game builds it
    teddy, tv, tf = object_from_bin(TEDDY_BIN, 'CYBER TEDDY - in game',
                                    image_material('cyber teddy', TEDDY_C, TEDDY_E))
    teddy.location = (0, 0, TEDDY_LIFT)
    # right: the fan's original, rigged, walking, scaled to the same 28-unit height.
    # Its walk KEYS the armature object's own location/scale, so it is moved and sized
    # through a parent Empty the animation never touches.
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(SRC_FBX))
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == 'ARMATURE')
    body = next(o for o in new if o.type == 'MESH')
    action = arm.animation_data.action if arm.animation_data else None
    if action:
        scene.frame_start, scene.frame_end = int(action.frame_range[0]), int(action.frame_range[1])
    scene.frame_set(scene.frame_start)
    arm.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg); me = ev.to_mesh()
    zs = [(body.matrix_world @ v.co).z for v in me.vertices]
    ev.to_mesh_clear()
    arm.data.pose_position = 'POSE'
    holder = bpy.data.objects.new('ORIGINAL fan FBX (rig + walk)', None)
    scene.collection.objects.link(holder)
    holder.empty_display_size = 4
    arm.parent = holder
    arm.name = 'walk rig'
    holder.scale = (28.0 / (max(zs) - min(zs)),) * 3
    holder.location = (GAP, 0, -min(zs) * holder.scale[0])
    scene.frame_set(scene.frame_start)

    label('OLD stock bear', -GAP, 33)
    label('CYBER TEDDY (in game)', 0, 33)
    label('ORIGINAL + walk (Space)', GAP, 33)

    # open in Material Preview, framed on the three bears from a little above the front
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type != 'VIEW_3D':
                continue
            space = area.spaces.active
            space.shading.type = 'MATERIAL'
            space.overlay.show_relationship_lines = False
            space.clip_start, space.clip_end = 0.1, 5000
            r3d = space.region_3d
            r3d.view_perspective = 'PERSP'
            r3d.view_location = Vector((0, 0, 16))
            r3d.view_rotation = Euler((math.radians(80), 0, math.radians(-12))).to_quaternion()
            r3d.view_distance = 130
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT), relative_remap=True, compress=True)
    print('REVIEW_BLEND_OK', OUT, 'stock', sv, sf, 'teddy', tv, tf, 'walk frames',
          scene.frame_start, scene.frame_end)


main()
