"""Blender 4.2: gallery sprite sheets for Nikolai's models, in the review gallery's own layout
(https://claude.ai/artifact/JfbPCEs4XXy3deaxA9t1RR - "Cybercity Fan Models").

Each model -> s/<tag>.jpg (a 6 x 2 sheet of views) + c/<tag>.jpg (the card) + stats in
<out>/stats.json (tris, verts, size, maps). Layouts copy the gallery's: PORTRAIT cells
450 x 600 with 12 views (incl. two close-ups), LANDSCAPE cells 600 x 450 with 10.
Backdrop #3d4047, the gallery's --tile, so letterboxing disappears. Plain studio light.
DirectX normal maps (tools/fan_props/normal_convention.py's test, run here per image)
get their green flipped for Blender's OpenGL node, so the bumps light the right way.

  blender -b -noaudio --python tools/fan_props/render_gallery.py -- <out_dir> <tag>=<file>[@portrait|@landscape] ...
"""
import bpy
import json
import math
import sys
from pathlib import Path

import numpy as np
from mathutils import Vector

BG = (0x3d / 255, 0x40 / 255, 0x47 / 255)
LIGHT_DIV = 14.0   # 4.0 blew the steel out (look_door_pair.jpg); the gallery's own renders read darker
CLAY_LIGHT = 0.13  # the 0.82 clay under the steel's lights clipped to a flat white silhouette
PORTRAIT = dict(cw=450, ch=600, cells=['Front', 'Front 3/4', 'Side', 'Back 3/4', 'Back', 'Other side', 'Low angle',
                                       'From above', 'Close-up', 'Close-up 3/4', 'Shape only', 'Shape only 3/4'])
LANDSCAPE = dict(cw=600, ch=450, cells=['Front', 'Front 3/4', 'Side', 'Back 3/4', 'Back', 'Other side', 'Low angle',
                                        'From above', 'Shape only', 'Shape only 3/4'])
# az: degrees around Z from the FRONT (Meshy front = -Y); el: degrees up; zoom: <1 = closer; top: aim at the top part
VIEW = {
    'Front': (0, 8, 1.0, False), 'Front 3/4': (35, 15, 1.0, False), 'Side': (90, 6, 1.0, False),
    'Back 3/4': (145, 15, 1.0, False), 'Back': (180, 8, 1.0, False), 'Other side': (270, 6, 1.0, False),
    'Low angle': (25, -14, 1.0, False), 'From above': (30, 58, 1.0, False),
    'Close-up': (0, 6, 0.48, True), 'Close-up 3/4': (35, 12, 0.48, True),
    'Shape only': (0, 8, 1.0, False), 'Shape only 3/4': (35, 15, 1.0, False),
}


def clear():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.lights, bpy.data.cameras):
        for item in list(coll):
            if item.users == 0:
                coll.remove(item)


def normal_is_directx(img):
    """The integrability test (tools/fan_props/normal_convention.py) on a Blender image."""
    if not img.has_data:
        img.reload()                                      # FBX images load lazily: size reads 0 x 0 until then
    w, h = img.size
    if w < 64 or h < 64:
        return False
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    a = px.reshape(h, w, 4)[::-1, :, :3]                 # Blender rows run bottom-up; the test wants image rows
    step = max(1, w // 2048)
    if step > 1:                                          # AVERAGE down (as the standalone tool's BOX resize); sampling every Nth texel aliases the slopes
        hh, ww = (h // step) * step, (w // step) * step
        a = a[:hh, :ww].reshape(hh // step, step, ww // step, step, 3).mean(axis=(1, 3))
    a = a.astype(np.float64)
    n = a * 2 - 1
    nz = np.maximum(n[..., 2], 0.2)
    gx, gy = n[..., 0] / nz, n[..., 1] / nz
    da = gx[1:, 1:] - gx[:-1, 1:]
    db = gy[1:, 1:] - gy[1:, :-1]
    m = (np.abs(da) < 0.3) & (np.abs(db) < 0.3) & ((np.abs(da) + np.abs(db)) > 0.01)
    if m.sum() < 5000:
        print('NORMAL_TEST', img.name, w, 'flat', int(m.sum()), flush=True)
        return False                                      # flat map: nothing to flip
    c = float(np.corrcoef(da[m], db[m])[0, 1])
    print('NORMAL_TEST', img.name, w, 'corr', round(c, 3), flush=True)
    return c > 0.1


def fix_normals(materials):
    flipped = []
    for mat in materials:
        if not mat or not mat.use_nodes:
            continue
        nt = mat.node_tree
        for nm in [n for n in nt.nodes if n.type == 'NORMAL_MAP']:
            if not nm.inputs['Color'].is_linked:
                continue
            src = nm.inputs['Color'].links[0].from_node
            if src.type != 'TEX_IMAGE' or src.image is None or not normal_is_directx(src.image):
                continue
            sep = nt.nodes.new('ShaderNodeSeparateColor'); comb = nt.nodes.new('ShaderNodeCombineColor')
            inv = nt.nodes.new('ShaderNodeMath'); inv.operation = 'SUBTRACT'; inv.inputs[0].default_value = 1.0
            nt.links.new(src.outputs['Color'], sep.inputs['Color'])
            nt.links.new(sep.outputs['Red'], comb.inputs['Red'])
            nt.links.new(sep.outputs['Green'], inv.inputs[1]); nt.links.new(inv.outputs[0], comb.inputs['Green'])
            nt.links.new(sep.outputs['Blue'], comb.inputs['Blue'])
            nt.links.new(comb.outputs['Color'], nm.inputs['Color'])
            flipped.append(src.image.name)
    return flipped


def maps_of(materials):
    kinds, size = set(), 0
    for mat in materials:
        if not mat or not mat.use_nodes:
            continue
        for n in mat.node_tree.nodes:
            if n.type != 'TEX_IMAGE' or n.image is None:
                continue
            size = max(size, n.image.size[0])
            for l in n.outputs[0].links:
                to = l.to_socket.name.lower()
                kinds.add('normal' if 'color' == to and l.to_node.type == 'NORMAL_MAP' else
                          {'base color': 'color', 'metallic': 'metallic', 'roughness': 'roughness',
                           'emission color': 'emission', 'alpha': 'alpha'}.get(to, to))
    return sorted(kinds), size


def drop_bad_edges(fbx_obj):
    # Upgrade Terminal Fix 6 ships its second mesh (Reference_Wireframe_Tower) with the FIRST
    # mesh's Edges array (3,063,108 entries against 375,060 loops), and Blender's importer then
    # dies indexing it. An Edges array that points outside its own loop list is not this mesh's:
    # drop it and mesh.validate() rebuilds the edges from the faces. The file's normals still
    # drive the shading, so nothing visible is lost.
    loops = edges = None
    for e in fbx_obj.elems:
        if e.id == b'PolygonVertexIndex':
            loops = e
        elif e.id == b'Edges':
            edges = e
    if loops is None or edges is None or not edges.props:
        return
    n = len(loops.props[0])
    arr = np.frombuffer(edges.props[0], dtype=edges.props[0].typecode)
    if len(arr) and (int(arr.min()) < 0 or int(arr.max()) >= n):
        fbx_obj.elems.remove(edges)
        print('DROP_BAD_EDGES', fbx_obj.props[1][:40] if len(fbx_obj.props) > 1 else '?', len(arr), 'loops', n)


def import_fbx(p):
    from io_scene_fbx import import_fbx as imp
    orig = imp.blen_read_geom

    def read_geom(fbx_tmpl, fbx_obj, settings):
        drop_bad_edges(fbx_obj)
        return orig(fbx_tmpl, fbx_obj, settings)

    imp.blen_read_geom = read_geom
    try:
        bpy.ops.import_scene.fbx(filepath=str(p))
    finally:
        imp.blen_read_geom = orig


def render_model(tag, path, layout, out):
    clear()
    p = Path(path)
    if p.suffix.lower() == '.fbx':
        import_fbx(p)
    else:
        raise SystemExit('unsupported ' + str(p))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    dg = bpy.context.evaluated_depsgraph_get()
    pts, tris, verts, mats = [], 0, 0, []
    for ob in meshes:
        me = ob.evaluated_get(dg).to_mesh()
        me.calc_loop_triangles()
        tris += len(me.loop_triangles)
        verts += len(me.vertices)
        M = np.array(ob.matrix_world)
        co = np.zeros(len(me.vertices) * 3)
        me.vertices.foreach_get('co', co)
        pts.append(co.reshape(-1, 3) @ M[:3, :3].T + M[:3, 3])
        mats += [s.material for s in ob.material_slots if s.material and s.material not in mats]
        ob.evaluated_get(dg).to_mesh_clear()
    a = np.concatenate(pts)
    lo, hi = a.min(axis=0), a.max(axis=0)
    centre = Vector(((lo + hi) / 2).tolist())
    dims = hi - lo
    kinds, texsize = maps_of(mats)                       # before the flip: its nodes sit between image and normal map
    flipped = fix_normals(mats)

    clay = bpy.data.materials.new('clay')
    clay.use_nodes = True
    clay.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.82, 0.82, 0.82, 1)
    clay.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.6

    scene = bpy.context.scene
    r = scene.render
    try:
        r.engine = 'BLENDER_EEVEE_NEXT'                    # Blender 4.2
    except TypeError:
        r.engine = 'BLENDER_EEVEE'                         # 4.3+ / 5.x renamed it back
    scene.eevee.taa_render_samples = 32
    r.resolution_x, r.resolution_y = layout['cw'], layout['ch']
    r.image_settings.file_format = 'PNG'
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'None'
    # The camera sees exactly the gallery tile (#3d4047 as LINEAR, so Standard shows the sRGB
    # value); the light the models receive from the world stays a separate soft grey.
    world = bpy.data.worlds.new('w'); scene.world = world; world.use_nodes = True
    wn, wl = world.node_tree.nodes, world.node_tree.links
    seen = wn['Background']
    seen.inputs['Color'].default_value = (*[((c + 0.055) / 1.055) ** 2.4 for c in BG], 1)
    lit = wn.new('ShaderNodeBackground'); lit.inputs['Color'].default_value = (0.16, 0.165, 0.18, 1)
    path = wn.new('ShaderNodeLightPath'); mix = wn.new('ShaderNodeMixShader')
    wl.new(path.outputs['Is Camera Ray'], mix.inputs['Fac'])
    wl.new(lit.outputs['Background'], mix.inputs[1]); wl.new(seen.outputs['Background'], mix.inputs[2])
    wl.new(mix.outputs['Shader'], wn['World Output'].inputs['Surface'])
    r.film_transparent = False
    cam_data = bpy.data.cameras.new('cam'); cam = bpy.data.objects.new('cam', cam_data)
    scene.collection.objects.link(cam); scene.camera = cam
    cam_data.lens = 70
    span = float(np.linalg.norm(dims))
    cam_data.clip_start, cam_data.clip_end = span * 0.01, span * 50
    lights = []
    for name, d, e in (('key', (-0.7, -1.0, 0.9), 900), ('fill', (1.0, -0.6, 0.3), 380), ('rim', (0.2, 1.0, 0.8), 520), ('under', (0, -0.3, -1), 90)):
        ld = bpy.data.lights.new(name, 'AREA'); ld.size = span * 1.2
        lo_ = bpy.data.objects.new(name, ld); scene.collection.objects.link(lo_)
        lo_.location = centre + Vector(d).normalized() * span * 2.2
        lo_.rotation_euler = (centre - lo_.location).to_track_quat('-Z', 'Y').to_euler()
        ld.energy = e * (span * 2.2) ** 2 / LIGHT_DIV
        lights.append((ld, ld.energy))
    cells_dir = out / 'cells' / tag
    cells_dir.mkdir(parents=True, exist_ok=True)
    originals = {ob.name: [s.material for s in ob.material_slots] for ob in meshes}
    sensor = cam_data.sensor_width
    files = []
    for i, label in enumerate(layout['cells']):
        az, el, zoom, top = VIEW[label]
        shape = label.startswith('Shape only')
        for ob in meshes:
            for k, s in enumerate(ob.material_slots):
                s.material = clay if shape else originals[ob.name][k]
        for ld, e in lights:
            ld.energy = e * (CLAY_LIGHT if shape else 1.0)
        aim = centre.copy()
        if top:
            aim.z = lo[2] + dims[2] * 0.72                  # close-ups: the upper part (screens, heads, crowns)
        th, ph = math.radians(az), math.radians(el)
        d = Vector((math.sin(th) * math.cos(ph), -math.cos(th) * math.cos(ph), math.sin(ph)))   # az 0 = in front (-Y)
        # distance that fits the bounding sphere in the NARROWER field of view (sensor_fit
        # AUTO spreads the sensor over the image's longer side)
        fov = 2 * math.atan(sensor / 2 / cam_data.lens)
        ratio = min(layout['cw'], layout['ch']) / max(layout['cw'], layout['ch'])
        fov_min = 2 * math.atan(math.tan(fov / 2) * ratio)
        dist = (span / 2) / math.sin(fov_min / 2) * 0.92 * zoom
        cam.location = aim + d * dist
        cam.rotation_euler = (aim - cam.location).to_track_quat('-Z', 'Y').to_euler()
        f = cells_dir / f'{i:02d}.png'
        r.filepath = str(f)
        bpy.ops.render.render(write_still=True)
        files.append(f)
    # compose the sheet (6 columns x 2 rows, row-major) and the card (Front 3/4)
    cols, rows = 6, 2
    W, H = layout['cw'], layout['ch']
    sheet = np.zeros((rows * H, cols * W, 4), dtype=np.float32)
    sheet[..., :3] = BG
    sheet[..., 3] = 1
    imgs = []
    for i, f in enumerate(files):
        im = bpy.data.images.load(str(f))
        px = np.empty(W * H * 4, dtype=np.float32); im.pixels.foreach_get(px)
        px = px.reshape(H, W, 4)
        imgs.append(px)
        rr, cc = divmod(i, cols)
        y0 = (rows - 1 - rr) * H                             # Blender rows bottom-up: row 0 at the top of the sheet
        sheet[y0:y0 + H, cc * W:(cc + 1) * W] = px
        bpy.data.images.remove(im)

    def save(arr, path):
        h, w = arr.shape[:2]
        im = bpy.data.images.new(Path(path).stem, w, h, alpha=False)
        im.pixels.foreach_set(arr.ravel())
        im.filepath_raw = str(path)
        im.file_format = 'JPEG'
        scene.render.image_settings.quality = 88
        im.save()
        bpy.data.images.remove(im)
    (out / 's').mkdir(parents=True, exist_ok=True)
    (out / 'c').mkdir(parents=True, exist_ok=True)
    save(sheet, out / 's' / f'{tag}.jpg')
    save(imgs[1], out / 'c' / f'{tag}.jpg')
    return dict(tag=tag, tris=tris, verts=verts, dims_m=[round(float(x), 4) for x in dims], maps=kinds,
                tex=[texsize, texsize], normals_flipped=flipped, layout='portrait' if layout is PORTRAIT else 'landscape',
                cols=6, rows=2, cw=W, ch=H, cells=layout['cells'])


def main():
    argv = sys.argv[sys.argv.index('--') + 1:]
    out = Path(argv[0]).resolve()   # Blender resolves a relative save path against the DRIVE ROOT (C:\tmp\...)
    out.mkdir(parents=True, exist_ok=True)
    stats_path = out / 'stats.json'
    stats = json.loads(stats_path.read_text()) if stats_path.exists() else {}
    for spec in argv[1:]:
        tag, rest = spec.split('=', 1)
        path, _, kind = rest.partition('@')
        rec = render_model(tag, path, LANDSCAPE if kind == 'landscape' else PORTRAIT, out)
        stats[tag] = rec
        stats_path.write_text(json.dumps(stats, indent=1))
        print('GALLERY_OK', tag, rec['tris'], rec['dims_m'], rec['maps'], 'flipped', rec['normals_flipped'], flush=True)


main()
