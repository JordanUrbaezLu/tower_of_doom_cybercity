"""Blender 4.2: the fan's Cyber Teddy -> `tod_cyber_teddy`, the song-hunt bear.

SOURCE (2026-09-30): a fan's model pack, "Random Ideas/Cyber Teddy and animations/
Cyber Teddy_Bear_Walking.fbx" - made with Meshy AI: auto-rigged (24 bones), one
32-frame walk, ONE embedded 2048 base-colour texture, 9,919 triangles. The pack's
three copies are byte-identical. Kept at art/cyber_teddy/source/ (README there).

WHAT THIS MAKES - a STATIC prop that replaces the stock `p7_zm_teddybear` in
_tod_secret.gsc, and nothing else:
- the REST pose, baked (the walk frames are mid-step and sink below the floor).
  The rig and the walk are NOT used: the hunt's rise, spin and flight are scripted
  movers and need no bones.
- one bone `tag_origin` with the PIVOT AT THE BOUNDING-BOX CENTRE, like the stock
  bear, so _tod_secret's rule holds: LIFT = the mesh's -min z, HALF_DEPTH = its
  back (+Y) extent. Both are written to art/cyber_teddy/manifest.json and the GSC
  defines must equal them (test_v1896_secret_killconfirm_bottle.js checks).
- 28 units tall (the stock bear is 28.1); FRONT = local -Y (the convention the
  hunt's three yaws were set by). Winding reversed as in every repo exporter.
- the texture byte-for-byte, plus a GLOW MAP cut from its own blue-to-violet
  lights (eye, chest core, arm panels): Meshy shipped no emission map, and a
  painted light is dark in a dark room. Gold trim and copper wires are metal,
  not lights, so the cut is a hue band, not a brightness threshold.
- the GDT, the manifest and review renders REBUILT FROM THE WRITTEN BINARY, so
  what the preview shows is what the linker reads.

Run: "C:\\Program Files\\Blender Foundation\\Blender 4.2\\blender.exe" -b -noaudio
     --python tools/cyber_teddy/build_cyber_teddy.py
"""
import bpy
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import numpy as np
from mathutils import Vector
from BetterBetterBlenderCOD.PyCoD import xmodel

REPO = Path(r'C:\Users\jorda\Repositories\tower_of_doom_cybercity')
TOOLS = Path(r'C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130')
SRC = REPO/'art/cyber_teddy/source/cyber_teddy_walking.fbx'
SRC_MD5 = '0cdea9bee11f5360fe6cd63c51f4e619'
NAME = 'tod_cyber_teddy'
MATERIAL = 'mtl_tod_cyber_teddy'
IMG_C, IMG_E = 'i_tod_cyber_teddy_c', 'i_tod_cyber_teddy_e'
MODEL_DIR = REPO/'model_export'/NAME
IMAGE_DIR = MODEL_DIR/'_images'
GDT = REPO/'source_data/tod_cyber_teddy.gdt'
ART = REPO/'art/cyber_teddy'
STAGING = REPO/'tmp/cyber_teddy_20260930/staging'
REVISION = 'cyber_teddy_1'
TARGET_HEIGHT = 28.0          # BO3 units (inches); stock p7_zm_teddybear is 28.1
GLOW_SCALE = '4'              # scaleRGB. The ice staff's tips ship at 14; this is a toy's lights
# The glow cut (hue in degrees, value/saturation 0..1), soft-edged on every axis.
GLOW_HUE = (185, 205, 305, 325)   # ramp in 185->205, full to 305, out by 325: cyan, blue, violet, magenta
GLOW_VALUE = (0.60, 0.90)
GLOW_SAT = (0.35, 0.65)


def md5(path):
    return hashlib.md5(Path(path).read_bytes()).hexdigest()


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def ramp(x, a, b):
    return np.clip((x - a) / (b - a), 0.0, 1.0)


def clear():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)


def import_rest():
    assert md5(SRC) == SRC_MD5, f'source FBX changed: {SRC}'
    clear()
    bpy.ops.import_scene.fbx(filepath=str(SRC))
    arms = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    assert len(arms) == 1 and len(meshes) == 1, (arms, meshes)
    assert len(meshes[0].material_slots) == 1, 'one material expected'
    arms[0].data.pose_position = 'REST'
    bpy.context.view_layer.update()
    return meshes[0]


def build_model(mesh):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = mesh.evaluated_get(dg)
    me = ev.to_mesh()
    me.calc_loop_triangles()
    uv = me.uv_layers.active
    assert uv is not None, 'no UVs'
    M = np.array(mesh.matrix_world)
    co = np.zeros(len(me.vertices) * 3, dtype=np.float64)
    me.vertices.foreach_get('co', co)
    world = co.reshape(-1, 3) @ M[:3, :3].T + M[:3, 3]
    lo, hi = world.min(axis=0), world.max(axis=0)
    scale = TARGET_HEIGHT / float(hi[2] - lo[2])
    pos = (world - (lo + hi) / 2) * scale          # pivot = bounding-box centre, BO3 units
    normal_matrix = mesh.matrix_world.to_3x3().inverted().transposed()

    model = xmodel.Model(NAME)
    model.version = 6
    root = xmodel.Bone('tag_origin', -1)
    root.offset = (0.0, 0.0, 0.0)
    root.matrix = [(1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)]
    model.bones.append(root)
    model.materials.append(xmodel.Material(MATERIAL, 'Phong', {}))
    out = xmodel.Mesh(NAME)
    for p in pos:
        out.verts.append(xmodel.Vertex(tuple(float(x) for x in p), [(0, 1.0)]))
    for tri in me.loop_triangles:
        face = xmodel.Face(0, 0)
        # Blender and BO3's raw export use opposite winding (every repo exporter flips it).
        for j, li in enumerate((tri.loops[0], tri.loops[2], tri.loops[1])):
            n = (normal_matrix @ me.corner_normals[li].vector).normalized()
            u, v = uv.data[li].uv
            face.indices[j] = xmodel.FaceVertex(me.loops[li].vertex_index, tuple(n), (1, 1, 1, 1), (u, 1 - v))
        out.faces.append(face)
    model.meshes.append(out)
    ev.to_mesh_clear()
    return model, pos, scale


def write_binary(model):
    STAGING.mkdir(parents=True, exist_ok=True)
    raw = STAGING/(NAME + '.XMODEL_EXPORT')
    model.WriteFile_Raw(str(raw))
    # Bare name + cwd: given absolute paths export2bin SILENTLY copies the text
    # file through (memory cod-asset-binary-pipeline). The *LZ4* magic proves it did not.
    run = subprocess.run([str(TOOLS/'bin/export2bin.exe'), raw.name], cwd=STAGING,
                         capture_output=True, text=True, timeout=600)
    (STAGING/'export2bin.log').write_text(run.stdout + '\n' + run.stderr)
    assert run.returncode == 0, (run.stdout, run.stderr)
    binary = next(p for p in STAGING.iterdir() if p.name.lower() == NAME + '.xmodel_bin')
    assert binary.read_bytes()[:5] == b'*LZ4*', 'export2bin passed the text file through'
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    dst = MODEL_DIR/(NAME + '.xmodel_bin')
    shutil.copyfile(binary, dst)
    check = xmodel.Model()
    check.LoadFile_Bin(str(dst))
    assert [(b.name, b.parent) for b in check.bones] == [('tag_origin', -1)]
    assert sum(len(m.verts) for m in check.meshes) == sum(len(m.verts) for m in model.meshes)
    assert sum(len(m.faces) for m in check.meshes) == sum(len(m.faces) for m in model.meshes)
    assert [m.name for m in check.materials] == [MATERIAL], [m.name for m in check.materials]
    return dst, check


def write_textures():
    img = next(i for i in bpy.data.images if i.size[0] >= 1024)
    assert img.packed_file is not None, 'expected the texture embedded in the FBX'
    IMAGE_DIR.mkdir(parents=True, exist_ok=True)
    data = img.packed_file.data
    assert data[:4] == b'\x89PNG', 'embedded texture is not a PNG'
    color = IMAGE_DIR/(IMG_C + '.png')
    color.write_bytes(data)                          # the fan's texture, byte for byte

    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    rgb = px.reshape(h, w, 4)[..., :3]
    top, bottom = rgb.max(axis=-1), rgb.min(axis=-1)
    span = np.maximum(top - bottom, 1e-6)
    sat = np.where(top > 1e-6, (top - bottom) / np.maximum(top, 1e-6), 0.0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.where(top == r, ((g - b) / span) % 6, 0.0)
    hue = np.where(top == g, (b - r) / span + 2, hue)
    hue = np.where(top == b, (r - g) / span + 4, hue) * 60.0
    a1, a2, b1, b2 = GLOW_HUE
    weight = (ramp(hue, a1, a2) * (1 - ramp(hue, b1, b2))
              * ramp(top, *GLOW_VALUE) * ramp(sat, *GLOW_SAT))
    glow = np.concatenate([rgb * weight[..., None], np.ones((h, w, 1), np.float32)], axis=-1)
    em = bpy.data.images.new(IMG_E, w, h, alpha=False)
    em.pixels.foreach_set(glow.ravel())
    emission = IMAGE_DIR/(IMG_E + '.png')
    em.filepath_raw = str(emission)
    em.file_format = 'PNG'
    em.save()
    return color, emission, (w, h), float((weight > 0.5).mean())


IMAGE_BLOCK = """\t"{name}" ( "image.gdf" )
\t{{
\t\t"baseImage" "model_export\\\\{folder}\\\\_images\\\\{name}.png"
\t\t"imageType" "Texture"
\t\t"type" "image"
\t\t"compressionMethod" "compressed high color"
\t\t"semantic" "diffuseMap"
\t\t"coreSemantic" "sRGB3chAlpha"
\t\t"streamable" "1"
\t}}"""

XMODEL_BLOCK = """\t"{name}" ( "xmodel.gdf" )
\t{{
\t\t"filename" "{folder}\\\\{name}.xmodel_bin"
\t\t"type" "rigid"
\t\t"skinOverride" ""
\t\t"BulletCollisionLOD" "None"
\t\t"physicsPreset" ""
\t\t"scale" "1"
\t\t"highLodDist" "0"
\t\t"lodNormalPriority" "1"
\t\t"lodPositionPriority" "1"
\t}}"""


def write_gdt():
    # lit_emissive_plus = the ice staff / inducer recipe proven in this map. No
    # normal or gloss map shipped: $identitynormalmap, and the gloss RANGE is
    # pinned low so the toy reads satin whatever the default gloss map is.
    # BulletCollisionLOD None like the stock bear: bullets pass through; the hunt
    # detects hits with its own view ray and melee lanes.
    fields = {'surfaceType': 'plastic', 'template': 'material.template',
              'materialCategory': 'Geometry Plus', 'materialType': 'lit_emissive_plus',
              'colorMap': IMG_C, 'normalMap': '$identitynormalmap', 'colorTint': '1 1 1 1',
              'textureAtlasRowCount': '1', 'textureAtlasColumnCount': '1',
              'usage': '<not in editor>', 'heatmap': '$gray_32_one_channel',
              'normalHeightScale': '1', 'glossRangeMin': '4', 'glossRangeMax': '5',
              'specAmount': '0.2', 'reflectionProbeAmount': '0.15', 'waterRoughness': '0',
              'colorMap00': IMG_E, 'colorTint1': '1 1 1 1', 'scaleRGB': GLOW_SCALE,
              'emissiveIncompetence': '1', 'emissiveFalloff': '0'}
    material = f'\t"{MATERIAL}" ( "material.gdf" )\n\t{{\n' + '\n'.join(
        f'\t\t"{k}" "{v}"' for k, v in fields.items()) + '\n\t}'
    blocks = [IMAGE_BLOCK.format(name=n, folder=NAME) for n in (IMG_C, IMG_E)]
    blocks += [material, XMODEL_BLOCK.format(name=NAME, folder=NAME)]
    GDT.write_text('{\n' + '\n'.join(blocks) + '\n}\n', encoding='utf-8')
    for name in (NAME, MATERIAL, IMG_C, IMG_E):
        assert len(name) <= 63, name                   # BO3 truncates at 63 and default-substitutes


def preview(check, color, emission):
    """Rebuild the WRITTEN binary as a Blender mesh and render it (lit, and dim to show the glow)."""
    clear()
    src = check.meshes[0]
    faces, uvs = [], []
    for f in src.faces:
        corners = (f.indices[0], f.indices[2], f.indices[1])   # undo the export winding
        faces.append([c.vertex for c in corners])
        uvs.append([(c.uv[0], 1 - c.uv[1]) for c in corners])
    me = bpy.data.meshes.new('from_bin')
    me.from_pydata([tuple(v.offset) for v in src.verts], [], faces)
    layer = me.uv_layers.new(name='uv')
    for poly, fuv in zip(me.polygons, uvs):
        for li, uv in zip(poly.loop_indices, fuv):
            layer.data[li].uv = uv
    for poly in me.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new('teddy', me)
    bpy.context.scene.collection.objects.link(obj)

    mat = bpy.data.materials.new('preview')
    mat.use_nodes = True
    mat.use_backface_culling = True                    # a flipped face would show as a hole
    nt = mat.node_tree
    bsdf = nt.nodes['Principled BSDF']
    tc = nt.nodes.new('ShaderNodeTexImage'); tc.image = bpy.data.images.load(str(color))
    te = nt.nodes.new('ShaderNodeTexImage'); te.image = bpy.data.images.load(str(emission))
    nt.links.new(tc.outputs['Color'], bsdf.inputs['Base Color'])
    nt.links.new(te.outputs['Color'], bsdf.inputs['Emission Color'])
    bsdf.inputs['Roughness'].default_value = 0.55
    me.materials.append(mat)

    scene = bpy.context.scene
    r = scene.render
    r.engine = 'BLENDER_EEVEE_NEXT'
    scene.eevee.taa_render_samples = 48
    r.resolution_x, r.resolution_y = 600, 800
    r.image_settings.file_format = 'JPEG'
    r.image_settings.quality = 88
    scene.view_settings.view_transform = 'Standard'
    world = bpy.data.worlds.new('w'); scene.world = world; world.use_nodes = True
    bg = world.node_tree.nodes['Background']
    cam_data = bpy.data.cameras.new('cam'); cam = bpy.data.objects.new('cam', cam_data)
    scene.collection.objects.link(cam); scene.camera = cam
    cam_data.type = 'ORTHO'; cam_data.ortho_scale = TARGET_HEIGHT * 1.25
    lights = []
    # The gallery's studio rig, moved ~15x further out for a 28-unit subject: power scales with distance squared.
    for name, off, energy in (('key', (-40, -55, 35), 2.3e5), ('fill', (50, -40, 5), 7e4), ('rim', (0, 55, 30), 1e5)):
        ld = bpy.data.lights.new(name, 'AREA'); ld.size = 30
        lo = bpy.data.objects.new(name, ld); scene.collection.objects.link(lo)
        lo.location = off
        lo.rotation_euler = (Vector((0, 0, 0)) - Vector(off)).to_track_quat('-Z', 'Y').to_euler()
        lights.append((ld, energy))
    shots = []
    for tag, az, lit, strength in (('front', 0, 1.0, 1.0), ('three_quarter', 35, 1.0, 1.0),
                                   ('side', 90, 1.0, 1.0), ('dim_glow', 35, 0.06, 4.0)):
        for ld, energy in lights:
            ld.energy = energy * lit
        bg.inputs['Color'].default_value = (0.045, 0.05, 0.062, 1) if lit == 1.0 else (0.004, 0.005, 0.008, 1)
        bsdf.inputs['Emission Strength'].default_value = strength
        th = math.radians(az)
        fwd = Vector((-math.sin(th), math.cos(th), 0))    # 0 = camera at -Y, looking at the front
        cam.location = -fwd * 100
        cam.rotation_euler = fwd.to_track_quat('-Z', 'Y').to_euler()
        out = ART/f'preview_{tag}.jpg'
        r.filepath = str(out)
        bpy.ops.render.render(write_still=True)
        shots.append(out)
    return shots


def main():
    mesh = import_rest()
    model, pos, scale = build_model(mesh)
    binary, check = write_binary(model)
    color, emission, size, glow_fraction = write_textures()
    write_gdt()
    pts = np.array([v.offset for m in check.meshes for v in m.verts])
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    ART.mkdir(parents=True, exist_ok=True)
    shots = preview(check, color, emission)
    manifest = dict(
        revision=REVISION, source=str(SRC.relative_to(REPO)).replace('\\', '/'), source_md5=SRC_MD5,
        pose='rest', target_height=TARGET_HEIGHT, scale_from_fbx_world=scale,
        bounds=[[round(float(x), 3) for x in lo], [round(float(x), 3) for x in hi]],
        size=[round(float(hi[a] - lo[a]), 3) for a in range(3)],
        # _tod_secret.gsc: TOD_SECRET_LIFT = -min z (feet on the surface), TOD_SECRET_HALF_DEPTH
        # = the BACK extent (+Y; the front is -Y) so "back to a wall" touches it.
        lift=round(float(-lo[2]), 1), half_depth=round(math.ceil(float(hi[1]) * 10) / 10, 1),
        verts=len(check.meshes[0].verts), tris=len(check.meshes[0].faces),
        texture=list(size), glow_fraction=round(glow_fraction, 4), glow_scale=GLOW_SCALE,
        files={str(p.relative_to(REPO)).replace('\\', '/'): sha(p) for p in (binary, color, emission, GDT)},
        previews=[str(p.relative_to(REPO)).replace('\\', '/') for p in shots])
    (ART/'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('CYBER_TEDDY_OK', json.dumps({k: manifest[k] for k in ('size', 'lift', 'half_depth', 'verts', 'tris', 'glow_fraction')}))


main()
