"""Install the cyber Rampage Inducer as map-owned BO3 assets (system Python + PyCoD).

Reads art/rampage_inducer_cyber/engine_kit/ (export_native.py) and writes:
  model_export/tod_inducer_cyber/tod_inducer_cyber.xmodel_bin   one mesh, six bones
  model_export/tod_inducer_cyber/_images/i_tod_icyber_plasma_*.png (generated)
  xanim_export/tod_inducer_cyber/tod_inducer_cyber_{idle,on}.XANIM_BIN (export2bin)
  source_data/tod_inducer_cyber.gdt   images, OFF/ON materials, both xmodels, both xanims
  animtrees/tod_inducer.atr           the two loops _tod_rampage.gsc plays
  art/rampage_inducer_cyber/install_manifest.json (hashes the build gate pins)

Run: python tools/inducer_cyber/install_native.py
"""
import hashlib, json, math, subprocess, sys
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path.home()/'AppData/Roaming/Blender Foundation/Blender/4.2/scripts/addons/BetterBetterBlenderCOD'))
sys.path.insert(0, str(Path(__file__).parent))
from PyCoD import xmodel as xm, xanim as xa
import anim_spec as A

MT = Path('C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130')
ART = ROOT/'art/rampage_inducer_cyber'
STAGE = ART/'engine_kit'
MODELS = ROOT/'model_export/tod_inducer_cyber'
IMG = MODELS/'_images'
ANIMS = ROOT/'xanim_export/tod_inducer_cyber'
GDT = ROOT/'source_data/tod_inducer_cyber.gdt'
ATR = ROOT/'animtrees/tod_inducer.atr'
XMODEL, XMODEL_ON = 'tod_inducer_cyber', 'tod_inducer_cyber_on'
MAT_SOLID, MAT_PLASMA = 'mtl_tod_icyber', 'mtl_tod_icyber_plasma'
REVISION = 'cyber_core_1'
# Emission: the atlas maps were normalised by these (export_native.SCALE), so the
# GDT scaleRGB reproduces the Blender strengths. The plasma is its own pair.
SCALE_SOLID = {'idle': 4, 'on': 12}
SCALE_PLASMA = {'idle': 1.4, 'on': 5}
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()


def block(name, kind, fields):
    def val(v):
        if isinstance(v, float) and v.is_integer():
            return str(int(v))
        return str(v)
    return '\t"' + name + '" ( "' + kind + '.gdf" )\n\t{\n' + ''.join(
        '\t\t"' + k + '" "' + val(v) + '"\n' for k, v in fields.items()) + '\t}\n'


# ------------------------------------------------------------------ the model
def build_model():
    manifest = json.loads((STAGE/'source_manifest.json').read_text())
    master = ROOT/manifest['master']
    assert sha(master) == manifest['master_sha256'], 'master changed since export_native ran'
    model = xm.Model(XMODEL)
    for i, name in enumerate(A.BONE_ORDER):
        b = xm.Bone(name, -1 if i == 0 else 0)
        if name == 'tag_origin':
            b.offset = (0.0, 0.0, 0.0); b.matrix = [(1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)]
        else:
            off, rot = A.pose(name, 'idle', 0)           # frame 0 IS the rest pose
            b.offset = tuple(off); b.matrix = A.rows(rot)
        model.bones.append(b)
    model.materials = [xm.Material(MAT_SOLID, 'Phong', {}), xm.Material(MAT_PLASMA, 'Phong', {})]
    counts = {}
    for mid, group in enumerate(('solid', 'plasma')):
        data = json.loads((STAGE/(group + '.json')).read_text())
        faces = list(zip(data['faces'], data['face_bone']))
        if group == 'plasma':
            # the energy column is seen from outside AND through its far wall
            faces += [([dict(c, n=[-x for x in c['n']]) for c in reversed(f)], b) for f, b in faces]
        counts[group] = len(faces)
        for start in range(0, len(faces), 18000):
            chunk = faces[start:start + 18000]
            used = sorted({c['v'] for f, _ in chunk for c in f})
            index = {v: i for i, v in enumerate(used)}
            mesh = xm.Mesh('%s_%d' % (group, start // 18000))
            mesh.verts = [xm.Vertex(tuple(data['verts'][v]), [(int(data['vert_bone'][str(v)]), 1.0)]) for v in used]
            assert len(mesh.verts) < 65535
            for f, _b in chunk:
                face = xm.Face(len(model.meshes), mid)
                face.indices = [xm.FaceVertex(index[c['v']], tuple(c['n']), (1.0, 1.0, 1.0, 1.0), tuple(c['uv'])) for c in f]
                mesh.faces.append(face)
            model.meshes.append(mesh)
    MODELS.mkdir(parents=True, exist_ok=True)
    path = MODELS/(XMODEL + '.xmodel_bin')
    model.WriteFile_Bin(str(path), version=7)
    check = xm.Model(); check.LoadFile_Bin(str(path), split_meshes=True)
    assert [m.name for m in check.materials] == [MAT_SOLID, MAT_PLASMA]
    assert [b.name for b in check.bones] == A.BONE_ORDER, [b.name for b in check.bones]
    assert sum(len(m.faces) for m in check.meshes) == sum(counts.values())
    weights = {}
    for m in check.meshes:
        for v in m.verts:
            assert len(v.weights) == 1 and abs(v.weights[0][1] - 1) < 1e-4
            weights[v.weights[0][0]] = weights.get(v.weights[0][0], 0) + 1
    zs = [v.offset[2] for m in check.meshes for v in m.verts]
    xs = [v.offset[0] for m in check.meshes for v in m.verts]
    ys = [v.offset[1] for m in check.meshes for v in m.verts]
    bounds = {'x': [min(xs), max(xs)], 'y': [min(ys), max(ys)], 'z': [min(zs), max(zs)]}
    return path, counts, {A.BONE_ORDER[k]: n for k, n in sorted(weights.items())}, bounds, manifest


# ------------------------------------------------------------------ the loops
def build_anims():
    ANIMS.mkdir(parents=True, exist_ok=True)
    out = {}
    for clip in ('idle', 'on'):
        anim = xa.Anim(); anim.version = 3; anim.framerate = A.FPS
        anim.parts = [xa.PartInfo(n) for n in A.BONE_ORDER]
        anim.notes = []
        n = A.CLIPS[clip]
        for f in range(n + 1):                       # last frame == first: a seamless loop
            fr = xa.Frame(f)
            for name in A.BONE_ORDER:
                if name == 'tag_origin':
                    fr.parts.append(xa.FramePart((0.0, 0.0, 0.0), [(1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)]))
                else:
                    off, rot = A.pose(name, clip, f)
                    fr.parts.append(xa.FramePart(tuple(off), A.rows(rot)))
            anim.frames.append(fr)
        export = ANIMS/(A.XANIM[clip] + '.XANIM_EXPORT')
        anim.WriteFile_Raw(str(export))
        # export2bin passes files through untouched when given absolute paths:
        # bare name, cwd = the folder (memory cod-asset-binary-pipeline).
        subprocess.run([str(MT/'bin/export2bin.exe'), '/nt=8', '/o=.', export.name], cwd=ANIMS, check=True,
                       capture_output=True)
        binary = export.with_suffix('.XANIM_BIN')
        assert binary.is_file() and binary.read_bytes()[:5] == b'*LZ4*', ('export2bin did not convert', binary)
        back = xa.Anim(); back.LoadFile_Bin(str(binary))
        assert len(back.frames) == n + 1 and [p.name for p in back.parts] == A.BONE_ORDER
        out[clip] = {'xanim': A.XANIM[clip], 'frames': n + 1, 'seconds': n / A.FPS, 'binary': binary}
    return out


# ------------------------------------------------------------------ plasma textures
def tile_noise(u, v, seed, terms):
    rnd = np.random.default_rng(seed)
    acc = np.zeros_like(u)
    for fu, fv, amp in terms:
        ph = rnd.uniform(0, math.tau)
        acc += amp * np.sin(math.tau * (fu * u + fv * v) + ph)
    return acc


def build_plasma(size=512):
    """Tileable in U and V (the scroll can run either way): vertical energy
    strands over a soft amber fill. Alpha keeps the crystal visible inside."""
    u, v = np.meshgrid(np.arange(size) / size, np.arange(size) / size)
    strands = np.zeros_like(u)
    rnd = np.random.default_rng(11)
    for k in range(22):
        centre = rnd.uniform(0, 1); width = rnd.uniform(0.004, 0.014); amp = rnd.uniform(0.45, 1.0)
        wob = 0.012 * np.sin(math.tau * (rnd.integers(1, 4) * v) + rnd.uniform(0, math.tau))
        d = np.abs(((u - centre - wob + 0.5) % 1.0) - 0.5)
        strands += amp * np.exp(-(d / width) ** 2) * (0.55 + 0.45 * np.sin(math.tau * (rnd.integers(1, 5) * v) + rnd.uniform(0, 6)))
    flow = tile_noise(u, v, 5, [(3, 2, .5), (7, 5, .3), (2, 9, .25), (11, 4, .15)])
    flow = (flow - flow.min()) / (flow.max() - flow.min())
    s = np.clip(strands, 0, 1.6) / 1.6
    energy = np.clip(0.22 + 0.55 * flow * 0.6 + 0.85 * s, 0, 1)
    gold = np.array([1.0, 0.62, 0.20])
    rgb = (energy[..., None] * gold[None, None, :] * 255).clip(0, 255).astype(np.uint8)
    alpha = (34 + 150 * np.clip(0.35 * flow + s, 0, 1)).clip(0, 255).astype(np.uint8)
    IMG.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.dstack([rgb, alpha])).save(IMG/'i_tod_icyber_plasma_c.png')
    em = (np.clip(0.12 + 0.35 * flow * 0.5 + 1.0 * s, 0, 1)[..., None] * gold[None, None, :] * 255).clip(0, 255).astype(np.uint8)
    Image.fromarray(em).save(IMG/'i_tod_icyber_plasma_e.png')
    Image.fromarray(np.full((64, 64, 3), (128, 128, 255), np.uint8)).save(IMG/'i_tod_icyber_plasma_n.png')


# ------------------------------------------------------------------ GDT
def image_fields(file, semantic, compression, srgb):
    f = {'baseImage': 'model_export\\\\tod_inducer_cyber\\\\_images\\\\' + file, 'imageType': 'Texture', 'type': 'image',
         'semantic': semantic, 'compressionMethod': compression, 'streamable': 1}
    if srgb:
        f['coreSemantic'] = 'sRGB3chAlpha'
    return f


def solid_fields(emission, scale):
    # The Heavenly Altar's proven lit_emissive_advanced_fullspec recipe; restrained
    # gloss/probe because the arena's probes smear (vertigo-materials-are-mirrors).
    return {'surfaceType': 'metal', 'template': 'material.template', 'materialCategory': 'Geometry Advanced',
            'materialType': 'lit_emissive_advanced_fullspec', 'colorMap': 'i_tod_icyber_c', 'normalMap': 'i_tod_icyber_n',
            'cosinePowerMap': 'i_tod_icyber_g', 'specColorMap': 'i_tod_icyber_s', 'specMapEnable': 1,
            'specColorTint': '.6 .6 .6 1', 'colorMap00': emission, 'colorTint': '1 1 1 1', 'colorTint1': '1 1 1 1',
            'scaleRGB': scale, 'emissiveIncompetence': 1, 'emissiveFalloff': 0, 'normalHeightScale': 1,
            'glossRangeMin': 0, 'glossRangeMax': 10, 'specAmount': .5, 'reflectionProbeAmount': .3,
            'textureAtlasRowCount': 1, 'textureAtlasColumnCount': 1, 'usage': '<not in editor>',
            'waterRoughness': 0}            # fullspec reads this as layerDepth: keep light ON the surface


def plasma_fields(scale):
    # The BO6 inducer's proven moving-energy recipe (install_inducer_bo3.py).
    return {'surfaceType': 'metal', 'template': 'material.template', 'materialCategory': 'Geometry',
            'materialType': 'lit_emissive_scroll_transparent', 'colorMap': 'i_tod_icyber_plasma_c',
            'normalMap': 'i_tod_icyber_plasma_n', 'colorTint': '1 1 1 1', 'textureAtlasRowCount': 1,
            'textureAtlasColumnCount': 1, 'usage': '<not in editor>', 'heatmap': '$gray_32_one_channel',
            'normalHeightScale': 1, 'glossRangeMin': 0, 'glossRangeMax': 8, 'specAmount': .1,
            'reflectionProbeAmount': .05, 'waterRoughness': 0, 'colorMap00': 'i_tod_icyber_plasma_e',
            'colorTint1': '1 1 1 1', 'scaleRGB': scale, 'emissiveIncompetence': 1, 'emissiveFalloff': 0,
            'gUVScroll02_Angle': .025, 'gUVScroll03_Angle': -.06, 'detailScaleX': 1, 'detailScaleY': 1}


def xmodel_fields(skin):
    # Minimal block = the BO6 inducer's (proven: one LOD, no autogen decimation of
    # thin strips - memory autogen-lods-erase-thin-parts). 'animated': it has bones.
    return {'filename': 'tod_inducer_cyber\\\\tod_inducer_cyber.xmodel_bin', 'type': 'animated', 'skinOverride': skin,
            'BulletCollisionLOD': 'High', 'physicsPreset': '', 'scale': 1, 'highLodDist': 0,
            'lodNormalPriority': 1, 'lodPositionPriority': 1}


def xanim_fields(clip):
    # The perk machines' proven looping fxanim settings (gdt.db p9_fxanim_zm_gp_speed_cola_loop).
    return {'filename': 'tod_inducer_cyber\\\\' + A.XANIM[clip] + '.XANIM_BIN',
            'model': 'tod_inducer_cyber\\\\tod_inducer_cyber.xmodel_bin', 'previewModel': XMODEL,
            'type': 'relative', 'useBones': 1, 'looping': 1, 'angleError': .01, 'translationError': .01}


def main():
    model_path, counts, weights, bounds, manifest = build_model()
    anims = build_anims()
    build_plasma()
    blocks = []
    images = [('i_tod_icyber_c', 'diffuseMap', 'compressed high color', True),
              ('i_tod_icyber_n', 'normalMap', 'compressed', False),
              ('i_tod_icyber_g', 'glossMap', 'compressed', False),
              ('i_tod_icyber_s', 'specularMap', 'compressed high color', True),
              ('i_tod_icyber_e', 'diffuseMap', 'compressed high color', True),
              ('i_tod_icyber_eon', 'diffuseMap', 'compressed high color', True),
              ('i_tod_icyber_plasma_c', 'diffuseMap', 'compressed high color', True),
              ('i_tod_icyber_plasma_e', 'diffuseMap', 'compressed high color', True),
              ('i_tod_icyber_plasma_n', 'normalMap', 'compressed', False)]
    for name, semantic, compression, srgb in images:
        assert (IMG/(name + '.png')).is_file(), name
        blocks.append(block(name, 'image', image_fields(name + '.png', semantic, compression, srgb)))
    blocks.append(block(MAT_SOLID, 'material', solid_fields('i_tod_icyber_e', SCALE_SOLID['idle'])))
    blocks.append(block(MAT_SOLID + '_on', 'material', solid_fields('i_tod_icyber_eon', SCALE_SOLID['on'])))
    blocks.append(block(MAT_PLASMA, 'material', plasma_fields(SCALE_PLASMA['idle'])))
    blocks.append(block(MAT_PLASMA + '_on', 'material', plasma_fields(SCALE_PLASMA['on'])))
    # skinOverride = "orig repl\r\n" pairs, the \r\n LITERAL in the GDT text
    skin = ''.join('%s %s_on\\r\\n' % (m, m) for m in (MAT_SOLID, MAT_PLASMA))
    blocks.append(block(XMODEL, 'xmodel', xmodel_fields('')))
    blocks.append(block(XMODEL_ON, 'xmodel', xmodel_fields(skin)))
    for clip in ('idle', 'on'):
        blocks.append(block(A.XANIM[clip], 'xanim', xanim_fields(clip)))
    GDT.write_text('{\n' + ''.join(blocks) + '}\n', encoding='utf-8')
    ATR.parent.mkdir(parents=True, exist_ok=True)
    ATR.write_text('inducer\n{\n' + ''.join('    %s\n' % A.XANIM[c] for c in ('idle', 'on')) + '}\n', encoding='utf-8')
    install = {
        'revision': REVISION, 'xmodel': XMODEL, 'xmodel_on': XMODEL_ON, 'materials': [MAT_SOLID, MAT_PLASMA],
        'master_sha256': manifest['master_sha256'], 'gdt_sha256': sha(GDT), 'atr_sha256': sha(ATR),
        'xmodel_bin_sha256': sha(model_path), 'faces': counts, 'bone_vertices': weights, 'bounds': bounds,
        'bones': A.BONE_ORDER, 'anim': A.summary(),
        'xanims': {c: {'name': a['xanim'], 'frames': a['frames'], 'sha256': sha(a['binary'])} for c, a in anims.items()},
        'scale_rgb': {'solid': SCALE_SOLID, 'plasma': SCALE_PLASMA},
        'images': {p.name: sha(p) for p in sorted(IMG.glob('*.png'))},
        'native_playtested': False,
    }
    (ART/'install_manifest.json').write_text(json.dumps(install, indent=2) + '\n')
    print('INDUCER_INSTALLED', json.dumps({'faces': counts, 'bones': weights, 'bounds': bounds}))


if __name__ == '__main__':
    main()
