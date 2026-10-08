"""THE SPAWN SIGN, REBUILT AS A CLEAN RELIEF (v19.69, user 2026-10-02: "The sign looks a little janky and not enhanced
or smoothed. Can we enhance it so its more smooth. It almost looks meshed").

WHY (measured 2026-10-02): the shipped `tod_cybercity_sign` is Nikolai's 732K-triangle Meshy mesh decimated to 12K
triangles ON its own UVs (build_fan_props 'reuse': hundreds of tiny islands) with his crinkled-metal normal map on top.
The faceting is the decimation; the "meshed" sheen is that normal map on a mesh it was not baked for; the smeared
texels are the island seams. His GEOMETRY is clean: a flat area wobbles 0.011 units (p99 0.065). A wall sign is a
relief - every surface faces the front - so it is rebuilt from the front:
  1 render  (Blender, sign_relief_render.py) - his full-detail sign straight on, orthographic, 16 px per unit, in the
            sign's own BO3 frame (the transform build_fan_props gave tod_cybercity_sign): base colour, metallic,
            roughness, and EXACT depth (one centred ray per pixel).
  2 grid    the depth, median-cleaned, sampled every GRID units on the sign's exact extents.
  3 mesh    (Blender, sign_relief_mesh.py) a vertex per covered grid point at its depth (a depth step IS a letter's
            wall), the outer boundary closed back to the wall, a collapse decimate to TRIS, smooth shading with
            SHARP_DEG hard edges, UVs re-projected from the final positions.
  4 maps    ONE front-projected sheet: colour 4096 x 2048 (16 texels per unit across the whole sign, no island
            seams), glow cut with build_fan_props' own sign bands, spec / gloss from his metal / roughness, NO normal
            map ($identitynormalmap - the crinkle normals were the "meshed" look; the geometry carries the shape).
  5 export  `tod_cybercity_sign2` (a NEW name, so the old model stays defined and the rollback is one zone line + one
            #define in _tod_base_sign.gsc), source_data/tod_sign_relief.gdt, art/fan_props/sign_relief.json.
The placement does not move: same pivot (back plane, horizontal centre, bottom) and the same footprint, asserted
inside the manifest numbers gen_tower_map.js BASE_SIGN places the sign from.

THE SIDES (sign_relief_2): a letter's side cannot be front-projected (it would stretch one texel column down its
depth), and one texel per side triangle (sign_relief_1) left stripes wherever neighbouring triangles read different
texels. Every side now samples ONE FLAT SWATCH painted into the empty band above the sign in every map, chosen by the
face the side hangs from: cyan letter -> his steel-blue side, pink neon -> his muted purple, anything else -> his dark
metal. The three colours are the medians of HIS texture on the old model's side faces (measured 2026-10-02, SIDES).

THE POWER STATES (user 2026-10-02: "can we give the sign an on and off state and turning power on lights it up?"):
two skinOverride twins of the same binary (the power terminal's recipe): `tod_cybercity_sign2_off` - the neon dark (a
half-size colour sheet with every glowing texel dimmed and greyed toward unlit glass, a black glow map) - and
`tod_cybercity_sign2_dim` - the ON sheets at a third of the glow, the flicker's in-between. _tod_base_sign.gsc shows
OFF until power_on and then flickers through DIM into ON.

THE CYBERCITY LINE IS LEVEL (sign_relief_3, user: "The Y in the sign is sticking out and the B"): his last Y stood
3.6 proud and his first Y was bent back; every letter pixel of the line is set to the line's own face depth before
meshing (LEVEL, level_line), and line_level_bad() gates the binary in --check.

Run:  python tools/fan_props/build_sign_relief.py            (all stages; ~2 min)
      python tools/fan_props/build_sign_relief.py --check    (build gate: outputs == the json, bounds, wiring)
"""
import argparse
import hashlib
import io
import json
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path.home() / 'AppData/Roaming/Blender Foundation/Blender/4.2/scripts/addons/BetterBetterBlenderCOD'))
from PyCoD import xmodel  # noqa: E402

TOOLS = Path(r'C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130')
BLENDER = Path(r'C:\Program Files\Blender Foundation\Blender 4.2\blender.exe')
STAGE = ROOT / 'tmp/fan_props_stage/sign_relief'
OUT = ROOT / 'model_export/tod_fan_props'
IMG = OUT / '_images'
GDT = ROOT / 'source_data/tod_sign_relief.gdt'
JSON = ROOT / 'art/fan_props/sign_relief.json'
FAN_MANIFEST = ROOT / 'art/fan_props/manifest.json'
GSC = ROOT / 'scripts/zm/zm_tower_of_doom/_tod_base_sign.gsc'
ZONE = ROOT / 'zone_source/zm_tower_of_doom.zone'
FOLDER = 'tod_fan_props'
REVISION = 'sign_relief_3'

MODEL, MATERIAL, IMGP = 'tod_cybercity_sign2', 'mtl_tod_cybercity_sign2', 'i_tod_csign2'
MODEL_OFF, MAT_OFF = MODEL + '_off', MATERIAL + '_off'          # power off: the neon dark
MODEL_DIM, MAT_DIM = MODEL + '_dim', MATERIAL + '_dim'          # the power-on flicker's half step
PPU = 16                     # the render: px per unit (sign_relief_render.py)
FRAME_W, FRAME_H, Z_CENTRE = 256.0, 128.0, 59.49
GRID = 0.25                  # mesh grid, units
TRIS = 60000
SHARP_DEG = 40.0
WALL_NX = 0.5                # a face steeper than 60 degrees off the front is a wall (a flat swatch, see wall_uvs)
WALL_INSET = 0.6             # how far IN from a wall's front edge the face it hangs from is read (past the edge's AA)
SIZES = {'c': (4096, 2048), 'e': (2048, 1024), 's': (1024, 512), 'g': (1024, 512), 'coff': (2048, 1024), 'eoff': (64, 64)}
METAL_DIFFUSE_CUT = 0.35     # = build_fan_props: metals keep 65% of their colour as diffuse
# = build_fan_props GLOW['sign']: (hue in, full, full-to, out, sat lo, hi, val lo, hi, gain)
GLOW_SIGN = [(160, 172, 205, 222, 0.30, 0.55, 0.35, 0.70, 1.0),
             (255, 270, 335, 350, 0.30, 0.55, 0.30, 0.65, 1.0)]
SHADER = dict(scale_rgb='6', gloss=(0, 11), spec_amount='0.6', probe='0.3')   # = the old sign's
DIM_SCALE = '2'              # the flicker's half step: the ON sheets at a third of the glow
# THE SIDES: sRGB diffuse + sRGB glow per kind of face a side hangs from = the medians of HIS texture on the old model's
# side faces (tod_cybercity_sign, 6,489 side faces classed by the face they hang from; measured 2026-10-02). Spec 0.22
# (dielectric 0.04) and gloss 0.54 are his medians on all three kinds and the new plate's own.
SIDES = {'metal': ((0.184, 0.196, 0.286), (0.0, 0.0, 0.0)),
         'cyan': ((0.157, 0.329, 0.490), (0.043, 0.094, 0.137)),
         'pink': ((0.337, 0.216, 0.478), (0.0, 0.0, 0.0))}
SIDE_SPEC, SIDE_GLOSS = 0.22, 0.54
# the swatches sit in the EMPTY band above the sign (z above 118.99 = rows 0..70 of the 2048 colour rows); rows 0..60
# leave 10 rows of the nearest-colour fill between them and the sign's top, and stay solid down to mip 4
SWATCH_ROWS = (0, 61)
SWATCH_COLS = {'metal': (256, 1280), 'cyan': (1536, 2560), 'pink': (2816, 3840)}
OFF_DIM, OFF_DESAT = 0.28, 0.5   # power off: a glowing texel keeps 28% of its colour, half of it greyed (unlit glass)
# THE CYBERCITY LINE IS LEVEL (sign_relief_3; user 2026-10-02: "The Y in the sign is sticking out and the B ... make it
# level and fix"). Measured in his model: the line's LAST Y stands 3.6 proud of the other letters (face 20.10 against
# 16.53) and the FIRST Y is bent back (arms and foot 14.2-15.3, a 16.7 ridge in the middle); C B E R C I T all sit at
# 16.53 - beside the bent Y the B read as popping out. Every pixel in front of the mounting rods (~12) inside a letter's
# measured window (LINE_LETTERS, padded `pad`) and the line's band (`z`) is set to the line's own median face depth, so
# the word is one flat plane. A colour test missed the first Y's darker foot (brightness 0.24-0.29); the windows do not.
# The cable that loops under the first Y runs below the band, and the glitch streaks are paint on the plate (~10.4):
# both stay where they are.
LEVEL = dict(z=(35.0, 48.5), pad=0.5, above=13.5, face=(16.0, 17.0))
# the line's nine letters, y windows measured on his render (C Y B E R C I T Y)
LINE_LETTERS = (('C', -62.4, -50.4), ('Y', -47.1, -35.3), ('B', -29.3, -18.5), ('E', -12.9, -3.7), ('R', 3.2, 14.6),
                ('C', 19.3, 30.6), ('I', 37.7, 39.1), ('T', 44.6, 57.2), ('Y', 58.4, 72.4))


def log(*a):
    print('[SIGN_RELIEF]', *a, flush=True)


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def blender(script, *args):
    run = subprocess.run([str(BLENDER), '-b', '-noaudio', '--python', str(ROOT / 'tools/fan_props' / script), '--', *map(str, args)],
                         capture_output=True, text=True, timeout=3600)
    for line in run.stdout.splitlines():
        if '[SIGN_RELIEF]' in line:
            print(line, flush=True)
    assert run.returncode == 0 and 'Traceback' not in run.stdout + run.stderr, run.stdout[-3000:] + run.stderr[-3000:]


# ------------------------------------------------------------------------------------------------------------ helpers
def srgb_to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def ramp(x, a, b):
    return np.clip((x - a) / max(b - a, 1e-6), 0.0, 1.0)


def glow_weight(rgb, bands):                                              # = build_fan_props.glow_weight
    top, bottom = rgb.max(axis=-1), rgb.min(axis=-1)
    span = np.maximum(top - bottom, 1e-6)
    sat = np.where(top > 1e-6, (top - bottom) / np.maximum(top, 1e-6), 0.0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.where(top == r, ((g - b) / span) % 6, 0.0)
    hue = np.where(top == g, (b - r) / span + 2, hue)
    hue = np.where(top == b, (r - g) / span + 4, hue) * 60.0
    w = np.zeros(hue.shape, np.float32)
    for h1, h2, h3, h4, s1, s2, v1, v2, gain in bands:
        w = np.maximum(w, ramp(hue, h1, h2) * (1 - ramp(hue, h3, h4)) * ramp(sat, s1, s2) * ramp(top, v1, v2) * gain)
    return w


def png16(path):
    a = np.asarray(Image.open(path))                                      # 16-bit RGBA -> float
    return a.astype(np.float64) / (65535.0 if a.dtype == np.uint16 else 255.0)


def png_bytes(arr, size):
    im = Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8))
    if im.size != size:
        im = im.resize(size, Image.LANCZOS)
    b = io.BytesIO()
    im.save(b, 'PNG', optimize=False, compress_level=9)
    return b.getvalue()


# ------------------------------------------------------------------------------------------------------------- stages
def level_line(Dm, M):
    """THE CYBERCITY LINE -> one flat plane (see LEVEL). Returns the levelled depth and what moved."""
    H, W = Dm.shape
    ys = (np.arange(W) + 0.5) / PPU - FRAME_W / 2
    zs = Z_CENTRE + FRAME_H / 2 - (np.arange(H) + 0.5) / PPU
    cols = np.zeros(W, bool)
    for _, y0, y1 in LINE_LETTERS:
        cols |= (ys >= y0 - LEVEL['pad']) & (ys <= y1 + LEVEL['pad'])
    region = ((zs >= LEVEL['z'][0]) & (zs <= LEVEL['z'][1]))[:, None] & cols[None, :]
    letters = region & M & (Dm > LEVEL['above'])
    face = letters & (Dm >= LEVEL['face'][0]) & (Dm <= LEVEL['face'][1])
    target = float(np.median(Dm[face]))
    assert 16.3 < target < 16.8, f'the line face depth moved: {target}'
    before = Dm[letters]
    moved = np.abs(before - target) > 0.05
    out = Dm.copy()
    out[letters] = target
    rec = dict(target=round(target, 3), letter_px=int(letters.sum()), moved_px=int(moved.sum()),
               before_min=round(float(before.min()), 2), before_max=round(float(before.max()), 2))
    log('LEVEL CYBERCITY: %d letter px -> depth %.3f (%d moved; they ran %.2f .. %.2f)' % (
        rec['letter_px'], target, rec['moved_px'], rec['before_min'], rec['before_max']))
    return out, rec


def grid():
    d = np.load(STAGE / 'front_d.npy')
    D, A = d[..., 0].astype(np.float64), d[..., 1]
    M = A > 0.5
    # one-pixel render noise at the silhouettes: a 3x3 median inside the coverage (outside stays 0)
    Dm = ndimage.median_filter(np.where(M, D, 0.0), size=3)
    Dm = np.where(M, Dm, 0.0)
    Dm, level = level_line(Dm, M)
    (STAGE / 'level.json').write_text(json.dumps(level, indent=1))
    H, W = D.shape
    ys = -FRAME_W / 2 + np.arange(int(FRAME_W / GRID) + 1) * GRID
    top = Z_CENTRE + FRAME_H / 2
    zs = top - np.arange(int(FRAME_H / GRID) + 1) * GRID
    cols = np.clip(np.round((ys + FRAME_W / 2) * PPU - 0.5).astype(int), 0, W - 1)
    rows = np.clip(np.round((top - zs) * PPU - 0.5).astype(int), 0, H - 1)
    Dg = Dm[np.ix_(rows, cols)]
    Mg = M[np.ix_(rows, cols)] & (Dg > 0.05)
    np.savez(STAGE / 'grid.npz', D=Dg, M=Mg, y0=ys[0], z1=zs[0], step=GRID)
    log('grid', Dg.shape[1], 'x', Dg.shape[0], 'covered', int(Mg.sum()))


KINDS = ('metal', 'cyan', 'pink')


def face_kind(rgb, weight):
    """0 metal / 1 cyan / 2 pink per texel: a glowing texel is cyan or pink by hue, everything else is metal."""
    top, bottom = rgb.max(axis=-1), rgb.min(axis=-1)
    span = np.maximum(top - bottom, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.where(top == r, ((g - b) / span) % 6, 0.0)
    hue = np.where(top == g, (b - r) / span + 2, hue)
    hue = np.where(top == b, (r - g) / span + 4, hue) * 60.0
    return np.where(weight > 0.5, np.where((hue > 150) & (hue < 230), 1, 2), 0).astype(np.int8)


def swatch_uv(kind):
    (c0, c1), (r0, r1) = SWATCH_COLS[kind], SWATCH_ROWS
    W, H = SIZES['c']
    return ((c0 + c1) / 2 / W, 1 - (r0 + r1) / 2 / H)                    # v up, like every tuv here


def maps():
    c = png16(STAGE / 'front_c.png')
    m = png16(STAGE / 'front_m.png')[..., 0]
    r = png16(STAGE / 'front_r.png')[..., 0]
    alpha = c[..., 3]
    rgb = c[..., :3]
    # straight alpha from the render; fill the uncovered texels with their NEAREST covered neighbour, so bilinear
    # sampling at a silhouette never pulls the black background in
    inside = alpha > 0.5
    assert inside.shape == (SIZES['c'][1], SIZES['c'][0]), inside.shape
    band = inside[:SWATCH_ROWS[1] + 8]
    assert not band.any(), f'the render covers the swatch band (row {int(np.nonzero(band.any(1))[0].min())}): move SWATCH_ROWS'
    _, (iy, ix) = ndimage.distance_transform_edt(~inside, return_indices=True)
    rgb = rgb[iy, ix]
    m, r = m[iy, ix], r[iy, ix]
    lin = srgb_to_lin(rgb)
    weight = glow_weight(rgb, GLOW_SIGN)
    kind = np.where(inside, face_kind(rgb, weight), -1).astype(np.int8)  # read by wall_uvs, before the swatches land
    diffuse = lin * (1 - METAL_DIFFUSE_CUT * m[..., None])
    spec = 0.04 * (1 - m[..., None]) + lin * m[..., None]
    gloss = np.repeat((1 - r)[..., None], 3, axis=-1)
    glow = rgb * weight[..., None]
    # THE SIDE SWATCHES, painted into every map (glow in the same sRGB space the e map is written in)
    (r0, r1) = SWATCH_ROWS
    for k in KINDS:
        c0, c1 = SWATCH_COLS[k]
        col, emit = SIDES[k]
        diffuse[r0:r1, c0:c1] = srgb_to_lin(np.array(col))
        spec[r0:r1, c0:c1] = srgb_to_lin(np.array([SIDE_SPEC] * 3))
        gloss[r0:r1, c0:c1] = SIDE_GLOSS
        glow[r0:r1, c0:c1] = np.array(emit)
        weight[r0:r1, c0:c1] = 0.0                                        # the OFF sheet leaves the sides alone
    files = {'c': png_bytes(lin_to_srgb(diffuse), SIZES['c']), 's': png_bytes(lin_to_srgb(spec), SIZES['s']),
             'g': png_bytes(gloss, SIZES['g']), 'e': png_bytes(glow, SIZES['e'])}
    # POWER OFF: every glowing texel dimmed and half greyed (unlit glass); the metal and the sides untouched
    luma = (diffuse @ np.array([0.2126, 0.7152, 0.0722]))[..., None]
    unlit = OFF_DIM * ((1 - OFF_DESAT) * diffuse + OFF_DESAT * luma)
    files['coff'] = png_bytes(lin_to_srgb(diffuse + (unlit - diffuse) * weight[..., None]), SIZES['coff'])
    files['eoff'] = png_bytes(np.zeros((SIZES['eoff'][1], SIZES['eoff'][0], 3)), SIZES['eoff'])
    stats = dict(glow_fraction=round(float((weight[inside] > 0.5).mean()), 4), metal_mean=round(float(m[inside].mean()), 3),
                 rough_mean=round(float(r[inside].mean()), 3))
    return {IMG / f'{IMGP}_{k}.png': v for k, v in files.items()}, stats, kind


def wall_uvs(V, tv, tuv, kind):
    """A front projection streaks every steep face (a letter's side samples one texel column down its whole depth: the
    first preview's 'motion blur' extrusions), and one texel per side triangle (sign_relief_1) striped wherever two
    neighbouring triangles read different texels. Each wall - |normal.x| under WALL_NX - now samples a FLAT SWATCH, the
    kind of the face it hangs from: its FRONT-most corner moved WALL_INSET back along the wall's own normal, i.e. onto
    the top of the step. A cyan letter's sides are his steel blue, the pink neon's his muted purple, the rest metal."""
    P = V[tv]
    n = np.cross(P[:, 1] - P[:, 0], P[:, 2] - P[:, 0])
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
    wall = np.abs(n[:, 0]) < WALL_NX
    front = P[np.arange(len(P)), P[:, :, 0].argmax(1)]
    lat = n[:, 1:3] / np.maximum(np.linalg.norm(n[:, 1:3], axis=1, keepdims=True), 1e-12)
    yz = front[:, 1:3] - WALL_INSET * lat
    H, W = kind.shape
    col = np.clip(((yz[:, 0] + FRAME_W / 2) * PPU).astype(int), 0, W - 1)
    row = np.clip(((Z_CENTRE + FRAME_H / 2 - yz[:, 1]) * PPU).astype(int), 0, H - 1)
    k = np.maximum(kind[row, col], 0)                                     # off the sign (a handful) -> metal
    out = tuv.copy()
    counts = {}
    for i, name in enumerate(KINDS):
        sel = wall & (k == i)
        out[sel] = np.array(swatch_uv(name))[None, None, :]
        counts[name] = int(sel.sum())
    return out, int(wall.sum()), counts


def wall_normals(V, tv, tn):
    """The letters' outlines come off a 0.25 grid, so a side is a run of small facets at odd angles to each other, and
    SHARP_DEG split most of them: every facet shaded flat = fine stripes down every side (the sign_relief_2 preview).
    Each wall corner now takes the area-weighted average of the WALLS meeting at its vertex, so a side shades as one
    smooth return; the front faces keep their own normals, so the crisp edge where a face meets its side stays. Where
    walls facing opposite ways meet at one vertex (a stroke's tip) the sum cancels and that corner stays faceted."""
    P = V[tv]
    fn = np.cross(P[:, 1] - P[:, 0], P[:, 2] - P[:, 0])                  # length = 2 x area: area-weighted
    area = np.linalg.norm(fn, axis=1)
    unit = fn / np.maximum(area[:, None], 1e-12)
    wall = np.abs(unit[:, 0]) < WALL_NX
    acc = np.zeros((len(V), 3))
    mag = np.zeros(len(V))
    np.add.at(acc, tv[wall].ravel(), np.repeat(fn[wall], 3, axis=0))
    np.add.at(mag, tv[wall].ravel(), np.repeat(area[wall], 3))
    vn = acc / np.maximum(np.linalg.norm(acc, axis=1, keepdims=True), 1e-12)
    keep = np.linalg.norm(acc, axis=1) > 0.35 * mag                       # opposed walls cancelling: stay faceted
    out = tn.copy()
    idx = np.nonzero(wall)[0]
    smoothed = 0
    for j in range(3):
        v = tv[idx, j]
        good = keep[v]
        out[idx[good], j] = vn[v[good]]
        out[idx[~good], j] = unit[idx[~good]]
        smoothed += int(good.sum())
    return out, smoothed


def export(kind):
    d = np.load(STAGE / 'low.npz')
    V, tv, tn, tuv = d['V'], d['tv'], d['tn'], d['tuv']
    tuv, walls, counts = wall_uvs(V, tv, tuv, kind)
    log('walls', walls, 'of', len(tv), 'faces take a flat side swatch', counts)
    tn, smoothed = wall_normals(V, tv, tn)
    log('wall corners smoothed', smoothed, 'of', walls * 3)
    np.save(STAGE / 'tuv_walls.npy', tuv)                                 # the preview renders the same UVs
    np.save(STAGE / 'tn_walls.npy', tn)                                   # ... and the same normals
    used = np.unique(tv)
    remap = np.full(len(V), -1, dtype=np.int64)
    remap[used] = np.arange(len(used))
    V, tv = V[used], remap[tv]
    model = xmodel.Model(MODEL)
    model.version = 6
    root = xmodel.Bone('tag_origin', -1)
    root.offset = (0.0, 0.0, 0.0)
    root.matrix = [(1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)]
    model.bones.append(root)
    model.materials.append(xmodel.Material(MATERIAL, 'Phong', {}))
    mesh = xmodel.Mesh(MODEL)
    for p in V:
        mesh.verts.append(xmodel.Vertex(tuple(float(x) for x in p), [(0, 1.0)]))
    for f in range(len(tv)):
        face = xmodel.Face(0, 0)
        for j, c in enumerate((0, 2, 1)):                                 # Blender CCW -> BO3's raw winding
            n = tn[f, c] / max(np.linalg.norm(tn[f, c]), 1e-9)
            u, v = tuv[f, c]
            face.indices[j] = xmodel.FaceVertex(int(tv[f, c]), tuple(float(x) for x in n), (1, 1, 1, 1), (float(u), float(1 - v)))
        mesh.faces.append(face)
    model.meshes.append(mesh)
    raw = STAGE / (MODEL + '.XMODEL_EXPORT')
    model.WriteFile_Raw(str(raw))
    run = subprocess.run([str(TOOLS / 'bin/export2bin.exe'), raw.name], cwd=STAGE, capture_output=True, text=True, timeout=600)
    assert run.returncode == 0, (run.stdout, run.stderr)
    binary = next(p for p in STAGE.iterdir() if p.name.lower() == MODEL + '.xmodel_bin')
    assert binary.read_bytes()[:5] == b'*LZ4*', 'export2bin passed the text file through'
    dst = OUT / (MODEL + '.xmodel_bin')
    shutil.copyfile(binary, dst)
    lo, hi = V.min(0), V.max(0)
    return dst, len(tv), len(V), lo, hi


def gdt_text():
    def image(name, semantic, compression, srgb):
        core = '\n\t\t"coreSemantic" "sRGB3chAlpha"' if srgb else ''
        return (f'\t"{name}" ( "image.gdf" )\n\t{{\n\t\t"baseImage" "model_export\\\\{FOLDER}\\\\_images\\\\{name}.png"\n'
                f'\t\t"imageType" "Texture"\n\t\t"type" "image"\n\t\t"semantic" "{semantic}"\n'
                f'\t\t"compressionMethod" "{compression}"\n\t\t"streamable" "1"{core}\n\t}}')
    def material(name, color, emit, scale):
        fields = {'surfaceType': 'metal', 'template': 'material.template', 'materialCategory': 'Geometry Advanced',
                  'materialType': 'lit_emissive_advanced_fullspec', 'colorMap': color, 'normalMap': '$identitynormalmap',
                  'cosinePowerMap': IMGP + '_g', 'specColorMap': IMGP + '_s', 'specMapEnable': '1', 'specColorTint': '1 1 1 1',
                  'colorMap00': emit, 'colorTint': '1 1 1 1', 'colorTint1': '1 1 1 1', 'scaleRGB': scale,
                  'emissiveIncompetence': '1', 'emissiveFalloff': '0', 'normalHeightScale': '1',
                  'glossRangeMin': str(SHADER['gloss'][0]), 'glossRangeMax': str(SHADER['gloss'][1]),
                  'specAmount': SHADER['spec_amount'], 'reflectionProbeAmount': SHADER['probe'],
                  'textureAtlasRowCount': '1', 'textureAtlasColumnCount': '1', 'usage': '<not in editor>', 'waterRoughness': '0'}
        return f'\t"{name}" ( "material.gdf" )\n\t{{\n' + '\n'.join(f'\t\t"{k}" "{v}"' for k, v in fields.items()) + '\n\t}'

    def model(name, skin=''):
        mfields = [('filename', f'{FOLDER}\\\\{MODEL}.xmodel_bin'), ('type', 'rigid'), ('skinOverride', skin),
                   ('BulletCollisionLOD', 'None'), ('physicsPreset', ''), ('scale', '1'), ('highLodDist', '0'),
                   ('autogenMediumLod', '0'), ('autogenLowLod', '0'), ('autogenLowestLod', '0')]
        mfields += [(f'autogenLod{i}', '0') for i in range(4, 8)] + [('lodNormalPriority', '1'), ('lodPositionPriority', '1')]
        return f'\t"{name}" ( "xmodel.gdf" )\n\t{{\n' + '\n'.join(f'\t\t"{k}" "{v}"' for k, v in mfields) + '\n\t}'

    b = ['\t// ---- GENERATED by tools/fan_props/build_sign_relief.py - do not hand-edit ----',
         image(IMGP + '_c', 'diffuseMap', 'compressed high color', True),
         image(IMGP + '_e', 'diffuseMap', 'compressed high color', True),
         image(IMGP + '_s', 'specularMap', 'compressed high color', True),
         image(IMGP + '_g', 'glossMap', 'compressed', False),
         image(IMGP + '_coff', 'diffuseMap', 'compressed high color', True),
         image(IMGP + '_eoff', 'diffuseMap', 'compressed high color', True),
         material(MATERIAL, IMGP + '_c', IMGP + '_e', SHADER['scale_rgb']),
         material(MAT_DIM, IMGP + '_c', IMGP + '_e', DIM_SCALE),
         material(MAT_OFF, IMGP + '_coff', IMGP + '_eoff', '1'),   # a black glow sheet: nothing glows at any scale
         model(MODEL),
         model(MODEL_DIM, f'{MATERIAL} {MAT_DIM}\\r\\n'),
         model(MODEL_OFF, f'{MATERIAL} {MAT_OFF}\\r\\n'),
         '\t// ---- END GENERATED ----']
    for n in (MODEL, MODEL_OFF, MODEL_DIM, MATERIAL, MAT_OFF, MAT_DIM, IMGP + '_coff', IMGP + '_eoff'):
        assert len(n) <= 32, n
    return '{\n' + '\n'.join(b) + '\n}\n'


def footprint_ok(lo, hi):
    """The generator places the sign from art/fan_props/manifest.json's tod_cybercity_sign size: the new one must not
    be bigger in any direction (0.15 of slack for the height - the full-detail mesh is 119.07 where the decimated one
    measured 118.98, and the clearance above it is 209 units)."""
    sg = json.loads(FAN_MANIFEST.read_text())['props']['sign']
    (olo, ohi) = sg['bounds']
    bad = []
    if lo[0] < -0.01 or hi[0] > ohi[0] + 0.01:
        bad.append(f'depth {lo[0]:.2f}..{hi[0]:.2f} outside 0..{ohi[0]}')
    if lo[1] < olo[1] - 0.01 or hi[1] > ohi[1] + 0.01:
        bad.append(f'width {lo[1]:.2f}..{hi[1]:.2f} outside {olo[1]}..{ohi[1]}')
    if lo[2] < -0.01 or hi[2] > ohi[2] + 0.15:
        bad.append(f'height {lo[2]:.2f}..{hi[2]:.2f} outside 0..{ohi[2]} (+0.15)')
    return bad


def binary_verts(path):
    m = xmodel.Model()
    m.LoadFile_Bin(str(path))
    return np.array([v.offset for mesh in m.meshes for v in mesh.verts], dtype=np.float64)


def line_level_bad(V, target):
    """THE CYBERCITY LINE IS LEVEL: nothing in the line stands proud of its face plane, and every letter's face sits
    ON it. (sign_relief_2 fails both: the last Y at 20.10, the first Y's face median 15.17.)"""
    bad = []
    z0, z1 = LEVEL['z']
    band = (V[:, 2] >= z0) & (V[:, 2] <= z1)
    for name, y0, y1 in LINE_LETTERS:
        m = band & (V[:, 1] >= y0) & (V[:, 1] <= y1)
        x = V[m, 0]
        face = x[x > LEVEL['above']]
        if not len(face):
            bad.append(f'CYBERCITY {name} at y {y0}..{y1}: no face vertices')
            continue
        if x.max() > target + 0.15:
            bad.append(f'CYBERCITY {name} at y {y0}..{y1} stands proud: {x.max():.2f} > {target:.2f}')
        if np.median(face) < target - 0.3:
            bad.append(f'CYBERCITY {name} at y {y0}..{y1} is set back: face median {np.median(face):.2f} < {target:.2f}')
    return bad


def wiring():
    bad = []
    g = GSC.read_text(encoding='utf-8')
    z = ZONE.read_text(encoding='utf-8')
    for define, name in (('TOD_SIGN_MODEL    ', MODEL), ('TOD_SIGN_MODEL_OFF', MODEL_OFF), ('TOD_SIGN_MODEL_DIM', MODEL_DIM)):
        if f'#define {define} "{name}"' not in g:
            bad.append(f'{GSC.name} does not #define {define.strip()} "{name}"')
        if f'#precache( "model", "{name}" );' not in g:
            bad.append(f'{GSC.name} does not precache {name}')
        if f'xmodel,{name}\n' not in z:
            bad.append(f'the zone does not carry xmodel,{name}')
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--skip-render', action='store_true', help='reuse the stage renders')
    a = ap.parse_args()
    if a.check:
        J = json.loads(JSON.read_text(encoding='utf-8'))
        bad = []
        for rel, want in J['files'].items():
            p = ROOT / rel
            if not p.exists() or sha(p) != want:
                bad.append(f'{rel} differs from sign_relief.json')
        m = xmodel.Model()
        m.LoadFile_Bin(str(OUT / (MODEL + '.xmodel_bin')))
        if sum(len(x.faces) for x in m.meshes) != J['tris']:
            bad.append('the binary face count drifted')
        if [x.name for x in m.materials] != [MATERIAL]:
            bad.append('the binary names another material')
        if GDT.read_text(encoding='utf-8') != gdt_text():
            bad.append(f'{GDT.name} is not what the tool writes')
        bad += footprint_ok(np.array(J['bounds'][0]), np.array(J['bounds'][1]))
        if 'level' not in J:
            bad.append('sign_relief.json has no CYBERCITY level record (pre-sign_relief_3 build)')
        else:
            bad += line_level_bad(binary_verts(OUT / (MODEL + '.xmodel_bin')), J['level']['target'])
        bad += wiring()
        if bad:
            print('build_sign_relief --check FAILED:\n  ' + '\n  '.join(bad))
            sys.exit(1)
        print(f'build_sign_relief --check OK ({MODEL} + _dim + _off: {J["tris"]} tris, {len(J["files"])} files, footprint inside the placed sign, '
              f'CYBERCITY level at {J["level"]["target"]})')
        return
    STAGE.mkdir(parents=True, exist_ok=True)
    if not a.skip_render:
        blender('sign_relief_render.py', STAGE)
    grid()
    blender('sign_relief_mesh.py', STAGE, TRIS, SHARP_DEG, FRAME_W, FRAME_H, Z_CENTRE)
    files, stats, kind = maps()
    IMG.mkdir(parents=True, exist_ok=True)
    for p, data in files.items():
        p.write_bytes(data)
        log('wrote', p.relative_to(ROOT), len(data), 'B')
    GDT.write_text(gdt_text(), encoding='utf-8')
    binary, tris, verts, lo, hi = export(kind)
    bad = footprint_ok(lo, hi)
    assert not bad, bad
    level = json.loads((STAGE / 'level.json').read_text())
    bad = line_level_bad(binary_verts(binary), level['target'])
    assert not bad, bad
    rec = dict(revision=REVISION, model=MODEL, material=MATERIAL, tris=tris, verts=verts, level=level,
               bounds=[[round(float(x), 3) for x in lo], [round(float(x), 3) for x in hi]], grid=GRID, sharp_deg=SHARP_DEG,
               sizes={k: list(v) for k, v in SIZES.items()}, **stats,
               states=dict(on=MODEL, dim=MODEL_DIM, off=MODEL_OFF, dim_scale=DIM_SCALE, off_dim=OFF_DIM, off_desat=OFF_DESAT),
               sides={k: dict(colour=v[0], glow=v[1]) for k, v in SIDES.items()},
               files={str(p.relative_to(ROOT)).replace('\\', '/'): sha(p) for p in [binary, GDT] + list(files)})
    JSON.write_text(json.dumps(rec, indent=1) + '\n', encoding='utf-8')
    log('BUILD_OK', tris, 'tris', verts, 'verts, bounds', rec['bounds'], stats)
    w = wiring()
    if w:
        log('NOTE (wire it):', *w)


if __name__ == '__main__':
    main()
