"""Build an OFFLINE, rigged Cybercity zombie art prototype in Blender 4.2.

Run: blender.exe -b --python tools/cyber_zombie_mvp.py
Uses installed BO3 source meshes read-only. No Mod Tools/game writes.
Outputs: art/cyber_zombie_mvp/{cyber_zombie_mvp.blend,*.png,manifest.json}
"""
import sys
import math
import json
import hashlib
from pathlib import Path

import bpy
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'art/cyber_zombie_mvp'
OUT.mkdir(parents=True, exist_ok=True)
MT = Path(r'C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130')
SRC = MT / 'model_export/t7_characters/zombies/zombies'
ADDON = Path.home() / 'AppData/Roaming/Blender Foundation/Blender/4.2/scripts/addons/BetterBetterBlenderCOD'
sys.path.insert(0, str(ADDON))
from PyCoD import xmodel

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = 'NONE'
scene.render.engine = 'CYCLES'
scene.cycles.samples = 40
scene.cycles.use_denoising = True
scene.render.threads_mode = 'FIXED'
scene.render.threads = 8
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'AgX'
scene.world.color = (0.12, 0.12, 0.12)
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.08, 0.115, 0.18, 1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.35

sources = []
def read_model(fn):
    path = SRC / fn
    m = xmodel.Model()
    m.LoadFile_Bin(str(path), split_meshes=False)
    sources.append({'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    return m

body = read_model('c_zom_der_zombie_body2_lod0.xmodel_bin')
head = read_model('c_zom_der_head_1_lod0.xmodel_bin')
tex_index = {p.name.lower(): p for p in SRC.rglob('*') if p.is_file() and p.suffix.lower() in ('.tif', '.tiff', '.png')}

arm = bpy.data.armatures.new('Original_BO3_skeleton')
rig = bpy.data.objects.new('Cybercity_zombie_rig', arm)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for model in (body, head):
    for b in model.bones:
        if b.name.lower() in arm.edit_bones:
            continue
        eb = arm.edit_bones.new(b.name.lower())
        eb.head = b.offset
        eb.tail = Vector(b.offset) + Vector(b.matrix[1])
        eb.align_roll(Vector(b.matrix[2]))
        if b.parent >= 0:
            eb.parent = arm.edit_bones[model.bones[b.parent].name.lower()]
bpy.ops.object.mode_set(mode='OBJECT')
rig.show_in_front = True
rig.display_type = 'WIRE'

def stock_material(mat):
    found = bpy.data.materials.get(mat.name)
    if found:
        return found
    out = bpy.data.materials.new(mat.name)
    out.use_nodes = True
    ns, links = out.node_tree.nodes, out.node_tree.links
    bs = ns.get('Principled BSDF')
    bs.inputs['Roughness'].default_value = 0.73
    bs.inputs['Specular IOR Level'].default_value = 0.28
    source = tex_index.get(mat.images['color'].lower())
    assert source, mat.images
    img = bpy.data.images.load(str(source), check_existing=True)
    tx = ns.new('ShaderNodeTexImage')
    tx.image = img
    links.new(tx.outputs['Color'], bs.inputs['Base Color'])
    normal = tex_index.get(source.stem[:-2].lower() + '_n' + source.suffix.lower())
    if normal:
        im = bpy.data.images.load(str(normal), check_existing=True)
        im.colorspace_settings.name = 'Non-Color'
        nt = ns.new('ShaderNodeTexImage'); nt.image = im
        nm = ns.new('ShaderNodeNormalMap'); nm.inputs['Strength'].default_value = 0.65
        links.new(nt.outputs['Color'], nm.inputs['Color'])
        links.new(nm.outputs['Normal'], bs.inputs['Normal'])
    return out

base_objects = []
for label, model in [('Original_body', body), ('Original_head', head)]:
    sm = model.meshes[0]
    mesh = bpy.data.meshes.new(label)
    faces = [[f.indices[i].vertex for i in (0, 2, 1)] for f in sm.faces]
    mesh.from_pydata([v.offset for v in sm.verts], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(label, mesh); scene.collection.objects.link(obj)
    for mat in model.materials:
        mesh.materials.append(stock_material(mat))
    uv = mesh.uv_layers.new(name='Original_UV')
    normals = []
    for poly, face in zip(mesh.polygons, sm.faces):
        poly.material_index = face.material_id
        poly.use_smooth = True
        for li, fi in zip(poly.loop_indices, (0, 2, 1)):
            fv = face.indices[fi]
            uv.data[li].uv = (fv.uv[0], 1 - fv.uv[1])
            normals.append(fv.normal)
    mesh.normals_split_custom_set(normals)
    for b in model.bones:
        assert b.name.lower() in arm.bones, b.name
        obj.vertex_groups.new(name=b.name.lower())
    for i, v in enumerate(sm.verts):
        for bi, weight in v.weights:
            obj.vertex_groups[bi].add([i], weight, 'REPLACE')
    mod = obj.modifiers.new('Original bone weights', 'ARMATURE'); mod.object = rig
    obj.parent = rig
    base_objects.append(obj)

# Prototype-only cloth finish. Keep the original material for honest A/B renders.
cloth_original = bpy.data.materials['mtl_c_zom_der_zombie_body2']
cloth_cyber = cloth_original.copy(); cloth_cyber.name = 'TOD | charcoal distressed uniform'
ns, links = cloth_cyber.node_tree.nodes, cloth_cyber.node_tree.links
bs = ns.get('Principled BSDF')
color_link = bs.inputs['Base Color'].links[0]
source_socket = color_link.from_socket; links.remove(color_link)
tint = ns.new('ShaderNodeMixRGB'); tint.blend_type='MULTIPLY'
tint.inputs[0].default_value=1; tint.inputs[2].default_value=(.19,.25,.30,1)
links.new(source_socket,tint.inputs[1]);links.new(tint.outputs[0],bs.inputs['Base Color'])
bs.inputs['Roughness'].default_value=.80

def material(name, color, metallic=0, roughness=0.5, emission=0):
    mat = bpy.data.materials.new(name); mat.use_nodes = True
    ns, links = mat.node_tree.nodes, mat.node_tree.links
    bs = ns.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Metallic'].default_value = metallic
    bs.inputs['Roughness'].default_value = roughness
    if emission:
        bs.inputs['Emission Color'].default_value = (*color, 1)
        bs.inputs['Emission Strength'].default_value = emission
    else:
        # Fine microtexture for the offline look; bake before engine integration.
        noise = ns.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value = 95
        noise.inputs['Detail'].default_value = 2
        bump = ns.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = 0.16
        bump.inputs['Distance'].default_value = 0.035
        links.new(noise.outputs['Fac'], bump.inputs['Height'])
        links.new(bump.outputs['Normal'], bs.inputs['Normal'])
    return mat

steel = material('TOD | graphite ceramic steel', (.035, .051, .067), .7, .38)
edge = material('TOD | worn titanium edges', (.23, .29, .31), .8, .35)
rubber = material('TOD | black cable insulation', (.015, .02, .022), .1, .78)
gold = material('TOD | crown brass', (.55, .30, .07), .8, .37)
cyan = material('TOD | cyan emissive inlay', (.015, .72, 1), .2, .3, 3.2)
amber = material('TOD | amber status lamp', (1, .21, .025), .2, .32, 2.8)
parts = []

def finish(obj, name, mat, bone, bevel=0):
    obj.name = name
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        be = obj.modifiers.new('Machined edges', 'BEVEL'); be.width = bevel; be.segments = 2
        bpy.ops.object.modifier_apply(modifier=be.name)
        wn = obj.modifiers.new('Weighted face normals', 'WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=wn.name)
    assert bone in arm.bones
    vg = obj.vertex_groups.new(name=bone)
    vg.add(list(range(len(obj.data.vertices))), 1, 'REPLACE')
    ar = obj.modifiers.new('Follow original skeleton', 'ARMATURE'); ar.object = rig
    obj.parent = rig
    obj['attachment_bone'] = bone
    parts.append(obj)
    obj.select_set(False)
    return obj

def box(name, loc, dims, mat=steel, bone='j_spine4', bevel=.1, rot=None):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object; obj.dimensions = dims
    if rot:
        obj.rotation_euler = rot
    return finish(obj, name, mat, bone, bevel)

def tube(name, pts, radius, mat=rubber, bone='j_head'):
    cr = bpy.data.curves.new(name, 'CURVE'); cr.dimensions = '3D'
    cr.resolution_u = 8; cr.bevel_depth = radius; cr.bevel_resolution = 1
    sp = cr.splines.new('BEZIER'); sp.bezier_points.add(len(pts)-1)
    for p, co in zip(sp.bezier_points, pts):
        p.co = co; p.handle_left_type = 'AUTO'; p.handle_right_type = 'AUTO'
    ob = bpy.data.objects.new(name, cr); scene.collection.objects.link(ob)
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.convert(target='MESH')
    return finish(bpy.context.object, name, mat, bone)

def cylinder(name, loc, radius, depth, mat=edge, bone='j_head', axis=(0,-1,0), vertices=12):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    obj = bpy.context.object
    obj.rotation_euler = Vector(axis).to_track_quat('Z','Y').to_euler()
    return finish(obj, name, mat, bone, min(.07, radius*.12))

# Skull: asymmetrical receiver, optic and a protected cable following the temple.
box('Temple receiver | backing', (3.35,-.55,66.8), (.7,2.3,1.9), edge, 'j_head', .17)
box('Temple receiver | shell', (3.73,-.55,66.9), (.3,1.9,1.5), steel, 'j_head', .12)
box('Temple receiver | cyan slit', (3.9,-.62,66.9), (.04,1.2,.10), cyan, 'j_head', .018)
for z in (66.4,67.4):
    cylinder('Temple receiver | fastener', (3.91,.1,z), .1,.05, edge,'j_head',(1,0,0),8)
box('Orbital plate | brow', (1.6,-4.23,66.95), (2.25,.35,.33), steel,'j_head',.08, (0,.08,.17))
cylinder('Optic | titanium socket', (1.20,-4.7,66.19), .69,.28, edge)
cylinder('Optic | dark recess', (1.20,-4.88,66.19), .55,.11, rubber)
cylinder('Optic | cyan lens', (1.20,-4.96,66.19), .34,.06, cyan,vertices=16)
cylinder('Optic | center lens', (1.20,-5.00,66.19), .13,.025, edge,vertices=12)
tube('Optic | temple cable', [(1.8,-4.7,66.3),(2.9,-3.55,66.0),(3.8,-2.1,66.1),(3.8,-.9,66.4)], .11)
tube('Temple | rear cable', [(3.4,.2,67.4),(3.5,1.65,67.9),(2.8,2.4,67.1),(2.1,2.6,65.2)], .13)
box('Rear neural connector', (2.1,2.5,65.0), (1.0,.55,1.4), steel,'j_head',.1)

# Chest module fitted to the intact left breast, away from torn flesh.
box('Chest | backing plate', (4.3,-4.75,53.0), (3.7,.75,5.5), edge,'j_spine4',.24, (0,.04,-.08))
box('Chest | graphite face', (4.3,-5.18,53.0), (3.15,.35,4.85), steel,'j_spine4',.2, (0,.04,-.08))
box('Chest | recessed light', (5.3,-5.43,52.2), (.22,.08,2.1), cyan,'j_spine4',.045)
for z in (51.5,52.05,52.6):
    box('Chest | ventilation slot', (3.7,-5.41,z), (1.0,.07,.13), rubber,'j_spine4',.02)
cylinder('Chest | amber status', (3.7,-5.5,54.25), .13,.05, amber,'j_spine4',vertices=8)
# A true mesh crown emblem, not a text label or a texture stand-in.
outline = [(-.85,-.55),(.85,-.55),(1,.55),(.43,.12),(0,.88),(-.43,.12),(-1,.55)]
verts = [(4.4+x,-5.5+y,54.5+z) for y in (-.07,.07) for x,z in outline]
n = len(outline)
faces = [tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
me = bpy.data.meshes.new('Crown emblem'); me.from_pydata(verts,[],faces); me.update()
ob = bpy.data.objects.new('Crown emblem',me); scene.collection.objects.link(ob)
finish(ob,'Chest | raised crown seal',gold,'j_spine4',.04)
tube('Chest | short power cable', [(5.1,-4.9,55.4),(6.2,-4.25,56.9),(7,-2.9,57.1),(6.3,-1.5,57.4)], .14,rubber,'j_spine4')

# Forearm plate: local z follows elbow -> wrist, local y faces outward/front.
elbow = Vector((15.18,-1.96,48.36)); wrist = Vector((18.24,-10.58,44.81))
axis = (wrist-elbow).normalized()
front = Vector((0,-1,.6)); front = (front-axis*front.dot(axis)).normalized()
side = front.cross(axis).normalized()
frame = Matrix((side,front,axis)).transposed()
center = elbow.lerp(wrist,.54)
def forebox(name, offset, dims, mat=steel, bevel=.1):
    offset=Vector(offset);offset.y+=1.15
    return box(name, center+frame@offset, dims, mat,'j_elbow_le',bevel,frame.to_euler())
forebox('Forearm | titanium base', (0,1.55,0), (3.5,.5,6.0),edge,.22)
forebox('Forearm | armored shell', (0,1.9,0), (3.05,.55,5.55),steel,.2)
forebox('Forearm | inlaid cyan rail', (-.73,2.205,0), (.25,.08,3.7),cyan,.035)
forebox('Forearm | rail end brass', (-.73,2.21,2.0), (.4,.09,.25),gold,.03)
for z in (-1.65,-.95,-.25,.45,1.15):
    forebox('Forearm | inset vent', (.5,2.21,z), (.85,.08,.18),rubber,.025)
for z in (-2.25,2.25):
    # Closed sleeve straps, with the visible clasp seated against the plate.
    points=[tuple(center+frame@Vector((2.35*math.cos(t),2.75*math.sin(t),z))) for t in [i*math.tau/12 for i in range(13)]]
    tube('Forearm | retaining band', points,.20,rubber,'j_elbow_le')
    forebox('Forearm | retaining clasp', (1.12,2.2,z), (.44,.22,.52),edge,.05)

# Checks are on the deliverable geometry and rig, not a game compatibility claim.
for ob in parts:
    assert len(ob.vertex_groups)==1 and ob.vertex_groups[0].name in arm.bones
    assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-6 for v in ob.data.vertices)

def point_at(obj, target):
    obj.rotation_euler = (Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()

def area(name,loc,energy,color,size,target):
    data=bpy.data.lights.new(name,'AREA'); data.energy=energy; data.color=color; data.shape='DISK'; data.size=size
    obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj);obj.location=loc;point_at(obj,target)
    return obj

# Scene coordinates are inches, so wattage scales with the 70-unit model.
area('Studio key', (35,-65,105), 65000,(.77,.88,1),65,(0,0,42))
area('Studio soft fill',(-55,-20,48),35000,(.65,.77,1),55,(0,0,40))
area('Cyan rim', (36,22,80),50000,(.08,.68,1),40,(0,0,42))
area('Warm edge',(-40,20,55),35000,(1,.46,.18),35,(0,0,40))

floor_mat=material('Studio | slate',(.025,.034,.047),.15,.62)
bpy.ops.mesh.primitive_plane_add(size=2000,location=(0,0,-.08)); floor=bpy.context.object
floor.name='Studio floor';floor.data.materials.append(floor_mat)
cam_data=bpy.data.cameras.new('Review camera');cam=bpy.data.objects.new('Review camera',cam_data)
scene.collection.objects.link(cam);scene.camera=cam;cam_data.type='ORTHO';cam_data.lens=65

# A light compositor bloom is presentation-only; tiny emitters remain inspectable.
scene.use_nodes=True
tree=scene.node_tree; tree.nodes.clear()
rl=tree.nodes.new('CompositorNodeRLayers')
gl=tree.nodes.new('CompositorNodeGlare');gl.glare_type='FOG_GLOW';gl.quality='HIGH';gl.threshold=2;gl.size=6;gl.mix=-.94
co=tree.nodes.new('CompositorNodeComposite');tree.links.new(rl.outputs['Image'],gl.inputs['Image']);tree.links.new(gl.outputs['Image'],co.inputs['Image'])

def render(name, loc, target, scale, width=1100,height=1300, modified=True):
    for ob in parts:ob.hide_render=not modified
    base_objects[0].data.materials[0] = cloth_cyber if modified else cloth_original
    cam.location=loc;point_at(cam,target);cam_data.ortho_scale=scale
    scene.render.resolution_x=width;scene.render.resolution_y=height
    scene.render.filepath=str(OUT/(name+'.png'))
    bpy.ops.render.render(write_still=True)

manifest={'status':'OFFLINE ART MVP; not installed, exported to BO3, or game-tested',
          'sources':sources,'base_triangles':sum(len(o.data.polygons) for o in base_objects),
          'attachment_triangles':sum(len(p.vertices)-2 for o in parts for p in o.data.polygons),
          'attachment_objects':len(parts),'original_bones':len(arm.bones),
          'design':'Asymmetric cyan optic/temple receiver, crown breast module, forearm brace, charcoal uniform',
          'limitations':['Procedural metal microtexture needs baking for BO3.',
                         'No LOD/gib variants or native ragdoll validation yet.',
                         'Renders use studio lighting, not map lighting.']}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2),flush=True)

render('prototype_front',(34,-120,64),(0,-1,36),82)
render('original_front',(34,-120,64),(0,-1,36),82,modified=False)
render('prototype_detail',(36,-75,76),(1,-1,59.4),31,1400,1100)
render('prototype_side',(110,-40,59),(0,0,36),82)
render('prototype_back',(48,115,62),(0,0,36),82)
for ob in parts:ob.hide_render=False
# Save with front camera, embedded source textures, and original rest pose.
cam.location=(34,-120,64);point_at(cam,(0,-1,36));cam_data.ortho_scale=82
scene.render.resolution_x=1100;scene.render.resolution_y=1300
bpy.ops.file.pack_all()
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cyber_zombie_mvp.blend'))
print('CYBER ZOMBIE MVP COMPLETE',flush=True)
