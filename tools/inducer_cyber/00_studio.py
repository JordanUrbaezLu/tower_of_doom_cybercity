"""Stage 00 - the review studio: the inducer's real corner of the base arena.

Re-runnable. Builds ONLY studio dressing (never exported): the blue-grid arena
floor, the south wall the device backs onto (its face 24 units behind the
origin), the flush cyan pilaster 140 units to the viewer's right and the cyan
cornice (gen_tower_map.js baseWallRun), the teleport-bay doorway gap from
y = -120 leftward, lights, two cameras, Rendered EEVEE with compositor bloom,
and the ON PREVIEW: a live collection instance of the master carrying
rampage_on = 1, so OFF (centre) and ON (left) update together as stages land.
"""
import sys, importlib, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import design_lib as D
importlib.reload(D)
import bpy
from mathutils import Vector

scene = bpy.context.scene
assert scene.get('mcp_port') == 9884, 'Use the cyber inducer Blender window only (port 9884)'

# Factory leftovers + any previous studio pass.
for ob in list(scene.objects):
    if ob.get('icyber_part') or ob.name.startswith('RI rig | '):
        continue                      # exported parts and their animation rig stay
    bpy.data.objects.remove(ob, do_unlink=True)
for c in list(bpy.data.collections):
    if c.name == 'Collection' and not c.objects:
        bpy.data.collections.remove(c)
master = D.master_collection()
studio = D.studio_collection()

scene.unit_settings.system = 'IMPERIAL'
scene.unit_settings.scale_length = 0.0254          # 1 Blender unit = 1 game unit = 1 inch
scene.unit_settings.length_unit = 'INCHES'
scene.frame_start, scene.frame_end = 0, 359      # one idle loop = four ON loops (anim_spec)
scene.render.fps = 30


def studio_obj(ob):
    for c in ob.users_collection:
        c.objects.unlink(ob)
    studio.objects.link(ob)
    ob['icyber_studio'] = True
    return ob


def grid_material(name, tile, line, line_strength, pitch=32.0, width=0.55):
    m = bpy.data.materials.get('RI studio | ' + name) or bpy.data.materials.new('RI studio | ' + name)
    m.use_nodes = True
    n, l = m.node_tree.nodes, m.node_tree.links
    for node in list(n):
        if node.type != 'OUTPUT_MATERIAL':
            n.remove(node)
    out = next(x for x in n if x.type == 'OUTPUT_MATERIAL')
    b = n.new('ShaderNodeBsdfPrincipled')
    b.inputs['Base Color'].default_value = (*tile, 1); b.inputs['Roughness'].default_value = 0.42
    b.inputs['Metallic'].default_value = 0.2
    tc = n.new('ShaderNodeTexCoord'); sep = n.new('ShaderNodeSeparateXYZ')
    l.new(tc.outputs['Object'], sep.inputs[0])
    lines = []
    for axis in ('X', 'Y', 'Z'):
        d = n.new('ShaderNodeMath'); d.operation = 'DIVIDE'; d.inputs[1].default_value = pitch
        l.new(sep.outputs[axis], d.inputs[0])
        f = n.new('ShaderNodeMath'); f.operation = 'PINGPONG'; f.inputs[1].default_value = 0.5
        l.new(d.outputs[0], f.inputs[0])
        r = n.new('ShaderNodeMapRange'); r.inputs['From Min'].default_value = 0.0
        r.inputs['From Max'].default_value = width / pitch; r.inputs['To Min'].default_value = 1.0
        r.inputs['To Max'].default_value = 0.0
        l.new(f.outputs[0], r.inputs['Value']); lines.append(r)
    mx = n.new('ShaderNodeMath'); mx.operation = 'MAXIMUM'
    l.new(lines[0].outputs[0], mx.inputs[0]); l.new(lines[1].outputs[0], mx.inputs[1])
    mx2 = n.new('ShaderNodeMath'); mx2.operation = 'MAXIMUM'
    l.new(mx.outputs[0], mx2.inputs[0]); l.new(lines[2].outputs[0], mx2.inputs[1])
    s = n.new('ShaderNodeMath'); s.operation = 'MULTIPLY'; s.inputs[1].default_value = line_strength
    l.new(mx2.outputs[0], s.inputs[0])
    b.inputs['Emission Color'].default_value = (*line, 1)
    l.new(s.outputs[0], b.inputs['Emission Strength'])
    l.new(b.outputs[0], out.inputs['Surface'])
    return m


def flat_emit(name, rgb, strength, base=(0.02, 0.02, 0.02)):
    m = bpy.data.materials.get('RI studio | ' + name) or bpy.data.materials.new('RI studio | ' + name)
    m.use_nodes = True
    b = m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value = (*base, 1)
    b.inputs['Emission Color'].default_value = (*rgb, 1)
    b.inputs['Emission Strength'].default_value = strength
    b.inputs['Roughness'].default_value = 0.3
    return m


def slab(name, x0, x1, y0, y1, z0, z1, mat):
    D._stage['col'] = studio
    ob = D.box(name, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0), mat)
    for k in ('icyber_part', 'icyber_group', 'icyber_stage'):
        if k in ob:
            del ob[k]
    return studio_obj(ob)


floor = grid_material('arena floor', (0.004, 0.007, 0.018), (0.10, 0.36, 1.0), 0.9)
wall = grid_material('arena wall', (0.005, 0.008, 0.020), (0.10, 0.36, 1.0), 0.55)
cyan = flat_emit('cyan pilaster', (0.0, 0.85, 1.0), 0.7, base=(0.0, 0.18, 0.22))

slab('arena floor', -24, 520, -460, 420, -4, 0, floor)
slab('south wall run', -44, -24, -120, 260, 0, 128, wall)
slab('south wall cyan pilaster', -44, -23.9, 120, 160, 0, 128, cyan)
slab('south wall cornice', -44, -23.9, -120, 280, 128, 148, cyan)
slab('west wall corner', -44, 400, 260, 280, 0, 128, wall)
slab('west wall cornice', -44, 400, 260, 280.1, 128, 148, cyan)
slab('tp bay doorway lintel', -44, -24, -440, -120, 112, 148, wall)
D._stage['col'] = None

# World: the arena reads as a night sky above a dark room.
w = bpy.data.worlds.get('RI studio night') or bpy.data.worlds.new('RI studio night')
w.use_nodes = True
bg = w.node_tree.nodes.get('Background')
bg.inputs['Color'].default_value = (0.006, 0.009, 0.022, 1)
bg.inputs['Strength'].default_value = 1.0
scene.world = w


def light(name, kind, loc, rot, energy, color, size=None):
    data = bpy.data.lights.get('RI studio | ' + name)
    if data is None or data.type != kind:
        data = bpy.data.lights.new('RI studio | ' + name, kind)
    data.energy = energy; data.color = color
    if size is not None and kind == 'AREA':
        data.size = size
    if kind == 'SUN':
        data.angle = math.radians(4)
    ob = bpy.data.objects.new('RI studio | ' + name, data)
    studio.objects.link(ob); ob['icyber_studio'] = True
    ob.location = loc; ob.rotation_euler = [math.radians(a) for a in rot]
    return ob


light('key sun', 'SUN', (200, -120, 260), (52, 0, 62), 1.6, (0.86, 0.92, 1.0))
light('cool fill sun', 'SUN', (200, 200, 200), (66, 0, 128), 0.45, (0.55, 0.8, 1.0))
light('top area', 'AREA', (60, -40, 260), (0, 0, 0), 9.0e5, (0.8, 0.88, 1.0), size=200)
# The game's own lamp: tools/gen_tod_inducer_fx.py plays a looping orange point
# light inside the device - flat 120 when OFF, pulsing to 1500 when ON. These two
# stand in for it at the core's height (the in-game height follows this model).
light('OFF lamp (in-game fx light)', 'POINT', (0, 0, 35), (0, 0, 0), 2.2e4, (1.0, 0.45, 0.12))
light('ON lamp (in-game fx light)', 'POINT', (0, -85, 35), (0, 0, 0), 1.5e5, (1.0, 0.30, 0.06))
for ob in studio.objects:
    if ob.type == 'LIGHT' and ob.data.type == 'POINT':
        ob.data.shadow_soft_size = 4

# THE ON PREVIEW - the same master, instanced, with rampage_on = 1.
on = bpy.data.objects.new('RI studio | ON preview (rampage armed)', None)
on.instance_type = 'COLLECTION'; on.instance_collection = master
on.location = (0, -85, 0); on['rampage_on'] = 1.0
studio.objects.link(on); on['icyber_studio'] = True

# Floor labels.
label_mat = flat_emit('label', (0.75, 0.82, 0.95), 0.6)
for text, y in (('OFF', 0.0), ('ON', -85.0)):
    cu = bpy.data.curves.new('RI studio | label ' + text, 'FONT')
    cu.body = text; cu.size = 9; cu.align_x = 'CENTER'; cu.align_y = 'CENTER'; cu.extrude = 0.05
    ob = bpy.data.objects.new('RI studio | label ' + text, cu)
    ob.data.materials.append(label_mat)
    studio.objects.link(ob); ob['icyber_studio'] = True
    ob.location = (46, y, 0.06); ob.rotation_euler = (0, 0, math.radians(90))


def camera(name, loc, target, lens):
    data = bpy.data.cameras.get('RI studio | ' + name) or bpy.data.cameras.new('RI studio | ' + name)
    data.lens = lens; data.clip_start = 0.5; data.clip_end = 5000
    ob = bpy.data.objects.new('RI studio | ' + name, data)
    studio.objects.link(ob); ob['icyber_studio'] = True
    ob.location = loc
    ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    return ob


both = camera('camera OFF and ON', (176, -40, 74), (0, -42, 30), 35)
camera('camera hero', (96, 40, 66), (0, 0, 33), 45)
camera('camera player eye', (118, 0, 60), (0, 0, 30), 30)
scene.camera = both

# Render: EEVEE Next with ray tracing, bloom through the compositor.
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.eevee.taa_render_samples = 64
scene.eevee.taa_samples = 16
scene.eevee.use_raytracing = True
scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
scene.view_settings.view_transform = 'AgX'
try:
    scene.view_settings.look = 'AgX - Medium High Contrast'
except TypeError:
    pass
scene.use_nodes = True
tree = scene.node_tree
for node in list(tree.nodes):
    tree.nodes.remove(node)
rl = tree.nodes.new('CompositorNodeRLayers')
glare = tree.nodes.new('CompositorNodeGlare')
kinds = [i.identifier for i in glare.bl_rna.properties['glare_type'].enum_items]
glare.glare_type = 'BLOOM' if 'BLOOM' in kinds else 'FOG_GLOW'
glare.quality = 'HIGH'; glare.threshold = 0.85; glare.mix = -0.55
if hasattr(glare, 'size'):
    glare.size = 8
comp = tree.nodes.new('CompositorNodeComposite')
view = tree.nodes.new('CompositorNodeViewer')
tree.links.new(rl.outputs['Image'], glare.inputs['Image'])
tree.links.new(glare.outputs['Image'], comp.inputs['Image'])
tree.links.new(glare.outputs['Image'], view.inputs['Image'])

for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            sp = area.spaces.active
            sp.shading.type = 'RENDERED'
            sp.shading.use_scene_world_render = True
            sp.shading.use_scene_lights_render = True
            try:
                sp.shading.use_compositor = 'ALWAYS'
            except Exception:
                pass
            sp.overlay.show_overlays = False
            sp.clip_start = 0.5; sp.clip_end = 6000
            sp.region_3d.view_perspective = 'CAMERA'
            sp.region_3d.view_camera_zoom = 0
            sp.region_3d.view_camera_offset = (0, 0)
            for region in area.regions:
                if region.type in ('UI', 'TOOLS'):
                    pass
            sp.show_region_ui = False
            sp.show_region_toolbar = False

D.sync_rig()
D.save('00 studio')
print('STUDIO_OK glare=' + glare.glare_type)
