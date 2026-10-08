"""The power terminal's POWER-ON animation (v19.69, user 2026-10-02: "the power has no animation from on to off so we
would need something for that as well. Like a knob turning or a switch or power visual going up on the screen. The
old switch would move the lever when turned on as an animation").

Nikolai's Grid Terminal V5 (`tod_power_terminal`, built by tools/fan_props/build_fan_props.py) is NOT touched. Two
new pieces hang on it, placed by _tod_power_terminal.gsc:

  tod_power_screen[_dark|_f1|_f2|_f3]  his five Clean_Display plates' FRONT faces, SCREEN_PROUD in front of the
        baked ones, on their ORIGINAL UVs into his 4K display sheet (cropped to the plates). One SKIN per frame of
        the boot (a skinOverride twin of one binary, the rocket-wreck recipe): dark (the screen drops out), f1..f3
        (the RESTART GRID steps light one by one while the progress bar fills and the sync arrows run), and the base
        model = ON (all four steps done, the bar full, 03:00 / 03:00, the header reads POWER RESTORED, the sync
        panel SYNC COMPLETE, every warning stripe mint). Every letter is HIS - copied from elsewhere on the sheet.
  tod_power_dial[_on]  the HOLD button's segmented bolt ring as its own disc. The button plate is flat and level
        with its rim (measured: 10.23 vs 10.3-10.8 deep), so it cannot press in without opening a see-through gap;
        instead the disc spins two turns at the press and stops upright, then swaps to the _on skin (the same images
        at DIAL_ON_SCALE emission). Its texture is sampled from the shipped atlas over the front view, the plate's
        hairline painted out inside the disc.

Run (system python - PyCoD is imported from the Blender add-on folder; Blender is only launched by --measure):
  python tools/fan_props/build_power_anim.py --measure   # needs tmp/fan_props_stage/power/low.npz (the
                                                          # build_fan_props bake) + the shipped atlas + the FBX
  python tools/fan_props/build_power_anim.py             # json + sheet -> frames, binaries, GDT, preview
  python tools/fan_props/build_power_anim.py --check     # build gate: re-derive in memory, FAIL on any drift
Outputs: art/fan_props/power_anim.json (the measurements), model_export/tod_fan_props/{tod_power_screen,
tod_power_dial}.xmodel_bin + _images/i_tod_pscr_*.png / i_tod_pdial_*.png, source_data/tod_power_anim.gdt,
art/fan_props/preview_power_boot.jpg. A change here is a FULL map build (new GDT/models).
"""
import argparse
import hashlib
import io
import json
import math
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path.home() / 'AppData/Roaming/Blender Foundation/Blender/4.2/scripts/addons/BetterBetterBlenderCOD'))
from PyCoD import xmodel  # noqa: E402

TOOLS = Path(r'C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130')
BLENDER = Path(r'C:\Program Files\Blender Foundation\Blender 4.2\blender.exe')
SRC = ROOT / 'art/fan_props/source/grid_v5'
FBX = (SRC / 'Grid_Terminal_V5_Final.fbx', 'b5178aef5359c8999d1bd34cce10f68b')       # = build_fan_props PROPS['power']
SHEET = (SRC / 'textures/Grid_Display_V4_4K.png', '10af6a2ad86f0d37b8216f7d0236dd80')
STAGE = ROOT / 'tmp/fan_props_stage/power'                 # build_fan_props' own bake stage (low.npz)
MY_STAGE = ROOT / 'tmp/fan_props_stage/power_anim'
OUT = ROOT / 'model_export/tod_fan_props'
IMG = OUT / '_images'
GDT = ROOT / 'source_data/tod_power_anim.gdt'
JSON = ROOT / 'art/fan_props/power_anim.json'
PREVIEW = ROOT / 'art/fan_props/preview_power_boot.jpg'
GSC = ROOT / 'scripts/zm/zm_tower_of_doom/_tod_power_terminal.gsc'
FOLDER = 'tod_fan_props'
REVISION = 'power_anim_1'

SCREEN_PROUD = 0.35        # the overlay's front faces this far in front of the baked plates (no z-fight, still inside the bezel)
CROP = (572, 300, 3572, 3372)   # the sheet region the five plates map into (+ an 8..17 px margin); 3000 x 3072
FRAME_SIZE = {'dark': 512, 'f1': 1024, 'f2': 1024, 'f3': 1024, 'on': 2048}   # ON lives forever: full detail
SCREEN_SCALE = '4'         # emission x the frame itself (the navy ground is ~0.003 linear: no wash)
DIAL_R = 3.55              # the disc: the ring is r 2.73..3.22 (measured), the bolt <= 1.9
DIAL_PROUD = 0.25          # the disc's face in front of the button plate
DIAL_SINK = 0.15           # its side wall runs this far back into the plate (no slit from an angle)
DIAL_SEGS = 48
DIAL_TEX = 512
DIAL_SCALE, DIAL_ON_SCALE = '5', '14'     # off = the body's own scaleRGB; on = lit
MINT = np.array([0.24, 1.0, 0.66])
CYAN = np.array([0.16, 0.84, 1.0])
NAVY = np.array([0.012, 0.024, 0.07])

# ---- the sheet's own layout, measured 2026-10-02 on the 4096 px sheet (tools: tmp measure_sheet.py) ----------------
HDR_SUB = (1308, 588, 3347, 645)             # RESTART SEQUENCE REQUIRED (magenta; caps 591..633 = 43 px, Q's tail below)
HDR_CAP_TOP = 591
HDR_LINE = (1294, 546, 3391, 554)            # its magenta underline
# The sheet's ground is one flat navy (an empty region: median 0.114, max 0.118), so cleared text is filled flat - the
# patch under the subtitle holds the header's corner dashes and could not be copied.
STEP_TEXT = [(2339, 1264, 3281, 1307), (2337, 1361, 3283, 1404), (2331, 1458, 3280, 1501), (2342, 1555, 3282, 1598)]
STEP_CIRC = [(2183, 1258, 2285, 1320), (2183, 1355, 2285, 1417), (2183, 1453, 2285, 1514), (2183, 1550, 2285, 1611)]
BAR_INNER = (2172, 1689, 3386, 1743)         # inside the bar's outline (2165..3393 x 1682..1750)
TIME_L = (2492, 1792, 2804, 1841)            # 00:00
TIME_R = (3011, 1792, 3322, 1841)            # 03:00
REQ = (2938, 2500, 3373, 2543)               # REQUIRED (sync panel)
STEP4_INK = (1556, 1597)                     # step 4's ink rows: 41 px, scaled 43/41 into the header
GLYPH = {                                    # (x0, x1, y0, y1): letters of HIS side-panel font at REQUIRED's 43 px
    'C': (3134, 3184, 2409, 2454),           # from SYNC (45 px: scaled 43/45)
    'O': (767, 825, 2622, 2665),             # left panel POWER
    'M': (988, 1040, 2709, 2752),            # left panel SYSTEM
    'P': (701, 756, 2622, 2665),             # left panel POWER
    'E': (2996, 3038, 2500, 2543),           # REQUIRED
    'T': (869, 923, 2709, 2752),             # left panel SYSTEM
}
GLYPH_GAP = 8                                # REQUIRED's gaps run 8..15 px; COMPLETE's wide O and M need the tight end
PANEL_RIGHT = 3470                           # the sync panel's inner border
SYNC_STRIPES = (2915, 2648, 3434, 2700)
SYNC_ARROWS = (2918, 2756, 3301, 2808)
LEFT_STRIPES = (647, 2355, 1165, 2425)
LEFT_TRI = (743, 2910, 1015, 3059)
TOWER = (660, 820, 2080, 1980)
TEXT_THR = 0.45


def md5(p):
    return hashlib.md5(Path(p).read_bytes()).hexdigest()


def log(*a):
    print('[POWER_ANIM]', *a, flush=True)


# =============================================================================================================== measure
EXTRACT = r'''
import sys, bpy, numpy as np
fbx, out = sys.argv[sys.argv.index('--') + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
rows = []
for o in bpy.context.scene.objects:
    if o.type != 'MESH' or not o.name.startswith('Clean_Display_'):
        continue
    me = o.data
    me.calc_loop_triangles()
    uv = me.uv_layers.active.data
    mw = o.matrix_world
    nm = mw.to_3x3().inverted().transposed()
    for t in me.loop_triangles:
        P = [list(mw @ me.vertices[me.loops[li].vertex_index].co) for li in t.loops]
        U = [list(uv[li].uv) for li in t.loops]
        rows.append((o.name, P, U, list((nm @ t.normal).normalized())))
names = sorted({r[0] for r in rows})
np.savez(out, obj=np.array([names.index(r[0]) for r in rows]), names=np.array(names),
         P=np.array([r[1] for r in rows]), U=np.array([r[2] for r in rows]), N=np.array([r[3] for r in rows]))
print('[POWER_ANIM] plates', names, len(rows), 'tris')
'''


def frame_transform():
    """build_fan_props.place() for PROPS['power'] (front '+X', fit (2, 88), pivot 'back'), from its own low poly."""
    d = np.load(STAGE / 'low.npz')
    R = np.array([[0, -1, 0], [1, 0, 0], [0, 0, 1]], dtype=np.float64)
    p = d['V'] @ R.T
    s = 88.0 / float(p[:, 2].max() - p[:, 2].min())
    p = p * s
    lo, hi = p.min(0), p.max(0)
    t = np.array([-lo[0], -(lo[1] + hi[1]) / 2, -lo[2]])
    return R, s, t, d


def raster_front(P, tv, tuv, y0, y1, z0, z1, ppu):
    """Top-surface UV of the low poly over a front window (image x grows with +Y = the viewer's right)."""
    W, H = int(round((y1 - y0) * ppu)), int(round((z1 - z0) * ppu))
    depth = np.full((H, W), -1e9)
    UV = np.zeros((H, W, 2))
    cen = P[tv]
    keep = (cen[:, :, 1].max(1) >= y0) & (cen[:, :, 1].min(1) <= y1) & (cen[:, :, 2].max(1) >= z0) & (cen[:, :, 2].min(1) <= z1)
    for f in np.where(keep)[0]:
        P3 = P[tv[f]]
        xs = (P3[:, 1] - y0) * ppu
        ys = (z1 - P3[:, 2]) * ppu
        x0, x1 = int(max(0, math.floor(xs.min()))), int(min(W - 1, math.ceil(xs.max())))
        ya, yb = int(max(0, math.floor(ys.min()))), int(min(H - 1, math.ceil(ys.max())))
        if x1 < x0 or yb < ya:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(ya, yb + 1) + 0.5)
        (ax, bx, cx), (ay, by, cy) = xs, ys
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-12:
            continue
        l1 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / den
        l2 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / den
        l3 = 1 - l1 - l2
        m = (l1 >= -1e-6) & (l2 >= -1e-6) & (l3 >= -1e-6)
        dz = l1 * P3[0, 0] + l2 * P3[1, 0] + l3 * P3[2, 0]
        sub = depth[ya:yb + 1, x0:x1 + 1]
        upd = m & (dz > sub)
        sub[upd] = dz[upd]
        T = tuv[f]
        for k in range(2):
            v = l1 * T[0, k] + l2 * T[1, k] + l3 * T[2, k]
            UV[ya:yb + 1, x0:x1 + 1, k][upd] = v[upd]
    return depth, UV


def sample(img, UV):
    """Bilinear sample of an atlas (H, W, C float) at Blender UVs (v up)."""
    h, w = img.shape[:2]
    x = UV[..., 0] * w - 0.5
    y = (1 - UV[..., 1]) * h - 0.5
    x0 = np.clip(np.floor(x).astype(int), 0, w - 1)
    y0 = np.clip(np.floor(y).astype(int), 0, h - 1)
    x1, y1 = np.clip(x0 + 1, 0, w - 1), np.clip(y0 + 1, 0, h - 1)
    fx, fy = (x - np.floor(x))[..., None], (y - np.floor(y))[..., None]
    return (img[y0, x0] * (1 - fx) * (1 - fy) + img[y0, x1] * fx * (1 - fy) + img[y1, x0] * (1 - fx) * fy + img[y1, x1] * fx * fy)


def measure():
    assert md5(FBX[0]) == FBX[1], 'the Grid Terminal FBX changed: re-measure only after build_fan_props rebuilt it'
    MY_STAGE.mkdir(parents=True, exist_ok=True)
    plates_npz = MY_STAGE / 'plates.npz'
    script = MY_STAGE / 'extract_plates.py'
    script.write_text(EXTRACT, encoding='utf-8')
    run = subprocess.run([str(BLENDER), '-b', '-noaudio', '--python', str(script), '--', str(FBX[0]), str(plates_npz)],
                         capture_output=True, text=True, timeout=900)
    assert plates_npz.exists(), run.stdout[-2000:] + run.stderr[-2000:]
    R, s, t, low = frame_transform()
    pl = np.load(plates_npz)
    L = (pl['P'] @ R.T) * s + t
    NL = pl['N'] @ R.T
    front = NL[:, 0] > 0.9
    tris = []
    for i in np.where(front)[0]:
        a, b, c = L[i]
        if np.cross(b - a, c - a)[0] < 0:          # keep Blender's CCW-about-+X order (the export flips it)
            order = (0, 2, 1)
        else:
            order = (0, 1, 2)
        pos = [[float(L[i, k, 0] + SCREEN_PROUD), float(L[i, k, 1]), float(L[i, k, 2])] for k in order]
        uv = []
        for k in order:
            u, v = pl['U'][i, k]
            px, py = u * 4096, (1 - v) * 4096
            uv.append([(px - CROP[0]) / (CROP[2] - CROP[0]), (py - CROP[1]) / (CROP[3] - CROP[1])])   # image (u, v-down)
        tris.append(dict(plate=str(pl['names'][pl['obj'][i]]), pos=pos, uv=uv))
    log('screen overlay', len(tris), 'front tris from', len(pl['names']), 'plates')

    # the dial: the bolt ring's centre + radius on the shipped atlas, in the terminal's local frame
    P = (low['V'] @ R.T) * s + t
    ppu = 64
    depth, UV = raster_front(P, low['tv'], low['tuv'], -8.0, 5.0, 21.0, 35.0, ppu)
    atlas_c = np.asarray(Image.open(IMG / 'i_tod_pterm_c.png').convert('RGB')).astype(np.float64) / 255
    col = sample(atlas_c, UV)
    H, W = depth.shape
    Y = -8.0 + (np.mgrid[0:H, 0:W][1] + 0.5) / ppu
    Z = 35.0 - (np.mgrid[0:H, 0:W][0] + 0.5) / ppu
    r_, g_, b_ = col[..., 0], col[..., 1], col[..., 2]
    cyan = (g_ > 0.55) & (b_ > 0.55) & (r_ < 0.75 * g_) & (depth > 0)
    ys, zs = Y[cyan], Z[cyan]
    cy, cz = float(ys.mean()), float(zs.mean())
    for _ in range(8):
        rr = np.hypot(ys - cy, zs - cz)
        ring = (rr > 2.2) & (rr < 4.0)
        A = np.c_[2 * ys[ring], 2 * zs[ring], np.ones(ring.sum())]
        c, *_ = np.linalg.lstsq(A, ys[ring] ** 2 + zs[ring] ** 2, rcond=None)
        cy, cz = float(c[0]), float(c[1])
    rr = np.hypot(ys - cy, zs - cz)
    ring_r = np.percentile(rr[(rr > 2.2) & (rr < 4.0)], [1, 50, 99])
    disc = np.hypot(Y - cy, Z - cz) < DIAL_R
    plate_x = float(np.median(depth[disc]))
    log('dial ring centre y', round(cy, 3), 'z', round(cz, 3), 'radius 1/50/99%', ring_r.round(3), 'plate x', round(plate_x, 3))
    assert DIAL_R > ring_r[2] + 0.2, 'the disc must cover the whole ring'
    assert float(np.percentile(depth[disc], 95)) - plate_x < 0.2, 'the plate under the disc is not flat'
    J = dict(revision=REVISION, fbx_md5=FBX[1], sheet_md5=SHEET[1], scale=s, t=[float(x) for x in t],
             screen_proud=SCREEN_PROUD, crop=CROP, screen_tris=tris,
             dial=dict(y=round(cy, 3), z=round(cz, 3), plate_x=round(plate_x, 3), ring_r=[round(float(x), 3) for x in ring_r],
                       r=DIAL_R, proud=DIAL_PROUD, x=round(plate_x + DIAL_PROUD, 3)))
    JSON.write_text(json.dumps(J, indent=1), encoding='utf-8')
    # the dial's texture: the shipped atlas over the disc, the plate ground evened out, the ring + bolt kept
    dial_texture(J, low, P)
    log('wrote', JSON.relative_to(ROOT))


def dial_texture(J, low, P):
    D = J['dial']
    ppu = DIAL_TEX / (2 * DIAL_R)
    y0, y1 = D['y'] - DIAL_R, D['y'] + DIAL_R
    z0, z1 = D['z'] - DIAL_R, D['z'] + DIAL_R
    depth, UV = raster_front(P, low['tv'], low['tuv'], y0, y1, z0, z1, ppu)
    c = sample(np.asarray(Image.open(IMG / 'i_tod_pterm_c.png').convert('RGB')).astype(np.float64) / 255, UV)
    e = sample(np.asarray(Image.open(IMG / 'i_tod_pterm_e.png').convert('RGB')).astype(np.float64) / 255, UV)
    n = DIAL_TEX
    jj, ii = np.meshgrid(np.arange(n) + 0.5, np.arange(n) + 0.5)
    ry = (jj / n) * 2 * DIAL_R - DIAL_R
    rz = DIAL_R - (ii / n) * 2 * DIAL_R
    r = np.hypot(ry, rz)
    val = c.max(2)
    w = np.clip((val - 0.30) / 0.25, 0, 1)[..., None]       # the ring + bolt and their halo
    ground = np.median(c[(r < DIAL_R) & (w[..., 0] < 0.05)], axis=0)
    cc = ground * (1 - w) + c * w
    ee = e * w
    rim = ((r > DIAL_R - 0.14) & (r <= DIAL_R))[..., None]
    cc = np.where(rim, cc * 0.5, cc)                       # a machined edge: the disc reads as an insert
    cc[r > DIAL_R] = ground * 0.5
    ee[r > DIAL_R] = 0
    IMG.mkdir(parents=True, exist_ok=True)
    Image.fromarray((np.clip(cc, 0, 1) * 255 + 0.5).astype(np.uint8)).save(IMG / 'i_tod_pdial_c.png')
    Image.fromarray((np.clip(ee, 0, 1) * 255 + 0.5).astype(np.uint8)).save(IMG / 'i_tod_pdial_e.png')
    log('dial texture', DIAL_TEX, 'ground', ground.round(3))


# ================================================================================================================ frames
def load_sheet():
    assert md5(SHEET[0]) == SHEET[1], 'his display sheet changed'
    return np.asarray(Image.open(SHEET[0]).convert('RGB')).astype(np.float64) / 255


def hsv(a):
    mx, mn = a.max(-1), a.min(-1)
    d = mx - mn + 1e-9
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    h = np.where(mx == r, (g - b) / d % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    return h, d / (mx + 1e-9), mx


def region(img, box):
    x0, y0, x1, y1 = box
    return img[y0:y1, x0:x1]


GROUND_V = 0.13   # the sheet's navy ground peaks at 0.118: anything recoloured is measured ABOVE it, or the ground tints too


def ink(v):
    """0 on the navy ground, 1 at full stroke: the weight a recolour or a paste uses (keeps antialias + halo)."""
    return np.clip((v - GROUND_V) / (0.85 - GROUND_V), 0, 1)


def tint_bright(img, box, color, gain=1.05):
    """Text / strokes in the box take `color`, at their own strength (halo and antialias kept, the ground untouched)."""
    sub = region(img, box)
    w = ink(sub.max(-1, keepdims=True))
    sub[:] = sub * (1 - w) + np.clip(color * gain, 0, 1) * w


def recolor_hue(img, box, h0, h1, color):
    sub = region(img, box)
    h, s, v = hsv(sub)
    w = (((h >= h0) & (h <= h1)) * np.clip((s - 0.25) / 0.2, 0, 1))[..., None]
    sub[:] = sub * (1 - w) + np.clip(color * v[..., None] * 1.05, 0, 1) * w


def clear_flat(img, box, pad=6):
    """Erase text: the box (+pad for the glow halo) takes the median of its own dark ground."""
    x0, y0, x1, y1 = box
    sub = img[y0 - pad:y1 + pad, x0 - pad:x1 + pad]
    ground = np.median(sub[sub.max(-1) < 0.2], axis=0)
    sub[:] = ground


def paste_max(img, src, x, y):
    h, w = src.shape[:2]
    dst = img[y:y + h, x:x + w]
    dst[:] = np.maximum(dst, src)


def badge(img, k, state, sheet):
    """The circled step number: 'active' = filled cyan, 'done' = filled mint; the digit stays as a dark cut-out."""
    x0, y0, x1, y1 = STEP_CIRC[k]
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    ax, ay = (x1 - x0) / 2 - 4.5, (y1 - y0) / 2 - 4.5
    yy, xx = np.mgrid[y0:y1, x0:x1]
    inside = ((xx + 0.5 - cx) / ax) ** 2 + ((yy + 0.5 - cy) / ay) ** 2 < 1
    orig = sheet[y0:y1, x0:x1]
    digit = (orig.max(-1) > 0.35) & inside
    col = MINT if state == 'done' else CYAN
    sub = img[y0:y1, x0:x1]
    sub[inside] = col * 0.92
    sub[digit] = NAVY
    ring = ~inside & (orig.max(-1) > 0.2)
    sub[ring] = np.clip(col * orig.max(-1)[ring][:, None] * 1.1, 0, 1)


def bar(img, frac):
    """The progress bar fills with lit segments, cyan at the start to mint at the end."""
    x0, y0, x1, y1 = BAR_INNER
    clear_flat(img, (x0 + 2, y0 + 2, x1 - 2, y1 - 2), pad=0)  # the empty bar's three ticks go
    seg, gap, pad = 36, 8, 7
    x = x0 + pad
    end = x0 + pad + frac * (x1 - x0 - 2 * pad)
    prof = 0.72 + 0.28 * np.sin(np.linspace(0, math.pi, (y1 - pad) - (y0 + pad)))[:, None, None]
    while x + seg <= end + 0.5 and x + seg <= x1 - pad:
        t = (x - x0) / (x1 - x0)
        col = CYAN * (1 - t) + MINT * t
        img[y0 + pad:y1 - pad, int(x):int(x + seg)] = np.clip(col * prof, 0, 1)
        x += seg + gap


def arrows(img, lit, color):
    x0, y0, x1, y1 = SYNC_ARROWS
    sub = img[y0:y1, x0:x1]
    on = sub.max(-1) > 0.3
    cols = on.any(0)
    runs, start = [], None
    for i, c in enumerate(cols):
        if c and start is None:
            start = i
        if not c and start is not None:
            runs.append((start, i)); start = None
    if start is not None:
        runs.append((start, len(cols)))
    assert len(runs) == 4, runs
    ground = np.median(sub[~on], axis=0)
    for k, (a, b) in enumerate(runs):
        part = sub[:, a:b]
        w = ink(part.max(-1, keepdims=True))
        if k < lit:
            part[:] = part * (1 - w) + np.clip(color * 1.05, 0, 1) * w
        else:
            part[:] = ground + (part - ground) * 0.22       # not yet: a dim ghost of the arrow


def ink_rows(sheet, box, thr=0.4):
    x0, y0, x1, y1 = box
    rows = np.where((sheet[y0:y1, x0:x1].max(-1) > thr).any(1))[0]
    return y0 + int(rows.min()), y0 + int(rows.max()) + 1


def compose_word(img, sheet, letters, box, color):
    """Clear `box` and set `letters` in HIS side-panel glyphs, left-aligned, every glyph scaled from its own INK
    height to the replaced word's cap height (REQUIRED: 36 px caps in a 43 px box - its Q has a tail; the left
    panel's POWER / SYSTEM letters are 43 px caps, SYNC's 45), GLYPH_GAP between glyphs (REQUIRED's tightest)."""
    cap0, cap1 = ink_rows(sheet, box)
    cap = cap1 - cap0
    clear_flat(img, box)
    x0, y0, x1, y1 = box
    x = x0
    pad = 3
    for ch in letters:
        gx0, gx1, gy0, gy1 = GLYPH['E' if ch == 'L' else ch]
        i0, i1 = ink_rows(sheet, (gx0, gy0, gx1, gy1))
        g = sheet[i0 - pad:i1 + pad, gx0 - pad:gx1 + pad].copy()
        if ch == 'L':                                        # an E with its top and middle arms cut: the font's own L
            v = g[pad:-pad, pad:-pad].max(-1) > 0.4
            cover = v.mean(0)
            stem = int(np.argmax(cover < 0.6))               # the first column past the stem
            rows = v.mean(1)
            lit = np.where(rows > 0.8)[0]
            bottom = int(lit[-1])
            while bottom > 0 and rows[bottom - 1] > 0.8:
                bottom -= 1                                  # the first row of the bottom bar
            assert 3 <= stem <= v.shape[1] // 2 and bottom > v.shape[0] // 2, f'E stem {stem} bottom bar {bottom}'
            g[: pad + bottom, pad + stem:] = 0               # keep the stem and the bottom bar (the column past the
                                                             # stem is the top arm's antialiased root: it goes too)
        k = cap / (i1 - i0)
        if abs(k - 1) > 1e-6:
            g = np.asarray(Image.fromarray((np.clip(g, 0, 1) * 255).astype(np.uint8)).resize(
                (max(1, round(g.shape[1] * k)), max(1, round(g.shape[0] * k))), Image.LANCZOS)).astype(np.float64) / 255
        paste_max(img, np.clip(color * 1.05, 0, 1) * ink(g.max(-1, keepdims=True)), x - round(pad * k), cap0 - round(pad * k))
        x += g.shape[1] - 2 * round(pad * k) + GLYPH_GAP
    assert x - GLYPH_GAP <= PANEL_RIGHT - 24, f'{letters} runs into the panel border ({x - GLYPH_GAP} > {PANEL_RIGHT - 24})'


def frames(sheet):
    out = {}
    base = sheet.copy()
    for name, (k_active, frac, lit) in {'f1': (0, 0.25, 1), 'f2': (1, 0.5, 2), 'f3': (2, 0.75, 3)}.items():
        img = base.copy()
        for k in range(k_active):
            badge(img, k, 'done', sheet)
            tint_bright(img, STEP_TEXT[k], MINT)
        badge(img, k_active, 'active', sheet)
        tint_bright(img, STEP_TEXT[k_active], np.array([0.92, 1.0, 1.0]), gain=1.15)
        bar(img, frac)
        arrows(img, lit, CYAN)
        out[name] = img
    img = base.copy()
    for k in range(4):
        badge(img, k, 'done', sheet)
        tint_bright(img, STEP_TEXT[k], MINT)
    bar(img, 1.0)
    arrows(img, 4, MINT)
    # the header: RESTART SEQUENCE REQUIRED -> POWER RESTORED (step 4's own letters, scaled to the subtitle's caps)
    clear_flat(img, HDR_SUB)
    x0, _, x1, _ = STEP_TEXT[3]
    pad = 4
    ink0, ink1 = STEP4_INK
    word = sheet[ink0 - pad:ink1 + pad, x0 - pad:x1 + pad]
    k = 43.0 / (ink1 - ink0)                                   # the subtitle's caps are 43 px, step 4's 41
    word = np.asarray(Image.fromarray((word * 255).astype(np.uint8)).resize(
        (round(word.shape[1] * k), round(word.shape[0] * k)), Image.LANCZOS)).astype(np.float64) / 255
    paste_max(img, np.clip(MINT * 1.05, 0, 1) * ink(word.max(-1, keepdims=True)), HDR_SUB[0] - round(pad * k), HDR_CAP_TOP - round(pad * k))
    recolor_hue(img, HDR_LINE, 275, 330, MINT)
    # the clock: 03:00 / 03:00
    clear_flat(img, TIME_L)
    x0, y0, x1, y1 = TIME_R
    paste_max(img, sheet[y0 - 4:y1 + 4, x0 - 4:x1 + 4], TIME_L[0] - 4, TIME_L[1] - 4)
    # the sync panel: SYNC COMPLETE; every warning stripe and the left panel's bolt go mint
    compose_word(img, sheet, 'COMPLETE', REQ, MINT)
    recolor_hue(img, SYNC_STRIPES, 275, 330, MINT)
    recolor_hue(img, LEFT_STRIPES, 275, 330, MINT)
    recolor_hue(img, LEFT_TRI, 275, 330, MINT)
    t = region(img, TOWER)
    t[:] = np.clip(t * 1.15, 0, 1)                           # the tower picture powers up
    out['on'] = img
    out['dark'] = base * 0.06
    return out


def frame_png(img, size):
    x0, y0, x1, y1 = CROP
    im = Image.fromarray((np.clip(img[y0:y1, x0:x1], 0, 1) * 255 + 0.5).astype(np.uint8))
    im = im.resize((size, size), Image.LANCZOS)
    b = io.BytesIO()
    im.save(b, 'PNG', optimize=False, compress_level=9)
    return b.getvalue()


# ============================================================================================================== binaries
def export_text(name, material, tris):
    """tris: [(pos x3, normal, uv x3 (image u, v-down))] in BO3 local order (already flipped for the export)."""
    model = xmodel.Model(name)
    model.version = 6
    root = xmodel.Bone('tag_origin', -1)
    root.offset = (0.0, 0.0, 0.0)
    root.matrix = [(1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)]
    model.bones.append(root)
    model.materials.append(xmodel.Material(material, 'Phong', {}))
    mesh = xmodel.Mesh(name)
    for pos, nrm, uvs in tris:
        base = len(mesh.verts)
        for p in pos:
            mesh.verts.append(xmodel.Vertex(tuple(float(x) for x in p), [(0, 1.0)]))
        face = xmodel.Face(0, 0)
        for j, c in enumerate((0, 2, 1)):                    # BO3's raw export winds opposite to CCW-about-the-normal
            face.indices[j] = xmodel.FaceVertex(base + c, tuple(float(x) for x in nrm[c]), (1, 1, 1, 1),
                                                (float(uvs[c][0]), float(uvs[c][1])))
        mesh.faces.append(face)
    model.meshes.append(mesh)
    return model


def screen_tris(J):
    out = []
    for t in J['screen_tris']:
        out.append((t['pos'], [(1.0, 0.0, 0.0)] * 3, t['uv']))
    return out


def dial_tris(J):
    """The disc in its own frame: origin = the disc's centre ON ITS FACE, front = +X (the terminal's front)."""
    out = []
    n = DIAL_SEGS
    uvc = lambda y, z: ((y + DIAL_R) / (2 * DIAL_R), (DIAL_R - z) / (2 * DIAL_R))
    ring = [(math.cos(2 * math.pi * k / n) * DIAL_R, math.sin(2 * math.pi * k / n) * DIAL_R) for k in range(n)]
    for k in range(n):
        (ya, za), (yb, zb) = ring[k], ring[(k + 1) % n]
        # front: CCW about +X seen from +X. Looking along -X, +Y is the viewer's right: (centre, a, b) with the
        # angle increasing from +Y to +Z is counter-clockwise for that viewer.
        pos = [(0.0, 0.0, 0.0), (0.0, ya, za), (0.0, yb, zb)]
        out.append((pos, [(1.0, 0.0, 0.0)] * 3, [uvc(0, 0), uvc(ya, za), uvc(yb, zb)]))
        # the side wall, back to DIAL_PROUD + DIAL_SINK behind the face; outward normals, the rim's dark texels
        back = -(DIAL_PROUD + DIAL_SINK)
        na, nb = (0.0, ya / DIAL_R, za / DIAL_R), (0.0, yb / DIAL_R, zb / DIAL_R)
        rim = uvc(ya * 0.985, za * 0.985)
        rimb = uvc(yb * 0.985, zb * 0.985)
        out.append(([(0.0, ya, za), (back, ya, za), (back, yb, zb)], [na, na, nb], [rim, rim, rimb]))
        out.append(([(0.0, ya, za), (back, yb, zb), (0.0, yb, zb)], [na, nb, nb], [rim, rimb, rimb]))
    # every triangle must wind CCW about its own normal (the export flips it)
    for pos, nrm, _ in out:
        a, b, c = (np.array(p) for p in pos)
        assert np.dot(np.cross(b - a, c - a), np.array(nrm[0]) + np.array(nrm[1]) + np.array(nrm[2])) > 0, pos
    return out


def write_binary(name, material, tris, check):
    model = export_text(name, material, tris)
    stage = MY_STAGE
    stage.mkdir(parents=True, exist_ok=True)
    raw = stage / (name + '.XMODEL_EXPORT')
    model.WriteFile_Raw(str(raw))
    if check:
        dst = OUT / (name + '.xmodel_bin')
        m = xmodel.Model()
        m.LoadFile_Bin(str(dst))
        got = sum(len(x.faces) for x in m.meshes)
        assert got == len(tris), f'{name}: shipped binary has {got} faces, the json makes {len(tris)}'
        assert [x.name for x in m.materials] == [material], (name, [x.name for x in m.materials])
        return None
    run = subprocess.run([str(TOOLS / 'bin/export2bin.exe'), raw.name], cwd=stage, capture_output=True, text=True, timeout=600)
    assert run.returncode == 0, (run.stdout, run.stderr)
    binary = next(p for p in stage.iterdir() if p.name.lower() == name + '.xmodel_bin')
    assert binary.read_bytes()[:5] == b'*LZ4*', 'export2bin passed the text file through'
    OUT.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(binary, OUT / (name + '.xmodel_bin'))
    return OUT / (name + '.xmodel_bin')


# =================================================================================================================== GDT
def gdt_text():
    def image(name):
        return (f'\t"{name}" ( "image.gdf" )\n\t{{\n\t\t"baseImage" "model_export\\\\{FOLDER}\\\\_images\\\\{name}.png"\n'
                f'\t\t"imageType" "Texture"\n\t\t"type" "image"\n\t\t"semantic" "diffuseMap"\n'
                f'\t\t"compressionMethod" "compressed high color"\n\t\t"streamable" "1"\n\t\t"coreSemantic" "sRGB3chAlpha"\n\t}}')

    def material(name, color, emit, scale):
        fields = {'surfaceType': 'metal', 'template': 'material.template', 'materialCategory': 'Geometry Plus',
                  'materialType': 'lit_emissive_plus', 'colorMap': color, 'normalMap': '$identitynormalmap',
                  'colorTint': '1 1 1 1', 'textureAtlasRowCount': '1', 'textureAtlasColumnCount': '1',
                  'usage': '<not in editor>', 'heatmap': '$gray_32_one_channel', 'normalHeightScale': '1',
                  'glossRangeMin': '3', 'glossRangeMax': '7', 'specAmount': '0.4', 'reflectionProbeAmount': '0.2',
                  'waterRoughness': '0', 'colorMap00': emit, 'colorTint1': '1 1 1 1', 'scaleRGB': scale,
                  'emissiveIncompetence': '1', 'emissiveFalloff': '0'}
        return f'\t"{name}" ( "material.gdf" )\n\t{{\n' + '\n'.join(f'\t\t"{k}" "{v}"' for k, v in fields.items()) + '\n\t}'

    def model(name, binary, skin=''):
        fields = [('filename', f'{FOLDER}\\\\{binary}.xmodel_bin'), ('type', 'rigid'), ('skinOverride', skin),
                  ('BulletCollisionLOD', 'None'), ('physicsPreset', ''), ('scale', '1'), ('highLodDist', '0'),
                  ('autogenMediumLod', '0'), ('autogenLowLod', '0'), ('autogenLowestLod', '0')]
        fields += [(f'autogenLod{i}', '0') for i in range(4, 8)]
        fields += [('lodNormalPriority', '1'), ('lodPositionPriority', '1')]
        return f'\t"{name}" ( "xmodel.gdf" )\n\t{{\n' + '\n'.join(f'\t\t"{k}" "{v}"' for k, v in fields) + '\n\t}'

    b = ['\t// ---- GENERATED by tools/fan_props/build_power_anim.py - do not hand-edit ----']
    for f in ('on', 'dark', 'f1', 'f2', 'f3'):
        b.append(image(f'i_tod_pscr_{f}'))
        b.append(material(f'mtl_tod_pscr_{f}', f'i_tod_pscr_{f}', f'i_tod_pscr_{f}', SCREEN_SCALE))
    b.append(image('i_tod_pdial_c'))
    b.append(image('i_tod_pdial_e'))
    b.append(material('mtl_tod_pdial', 'i_tod_pdial_c', 'i_tod_pdial_e', DIAL_SCALE))
    b.append(material('mtl_tod_pdial_on', 'i_tod_pdial_c', 'i_tod_pdial_e', DIAL_ON_SCALE))
    b.append(model('tod_power_screen', 'tod_power_screen'))
    for f in ('dark', 'f1', 'f2', 'f3'):
        b.append(model(f'tod_power_screen_{f}', 'tod_power_screen', f'mtl_tod_pscr_on mtl_tod_pscr_{f}\\r\\n'))
    b.append(model('tod_power_dial', 'tod_power_dial'))
    b.append(model('tod_power_dial_on', 'tod_power_dial', 'mtl_tod_pdial mtl_tod_pdial_on\\r\\n'))
    b.append('\t// ---- END GENERATED ----')
    for line in b:
        for tok in line.split('"'):
            if tok.startswith(('i_tod_', 'mtl_tod_', 'tod_power_')) and ' ' not in tok:
                assert len(tok) <= 32, tok
    return '{\n' + '\n'.join(b) + '\n}\n'


# =========================================================================================================== GSC lockstep
def gsc_constants():
    """_tod_power_terminal.gsc places the dial from #defines; they must be this json's numbers."""
    text = GSC.read_text(encoding='utf-8')
    got = {}
    for key in ('TOD_PDIAL_X', 'TOD_PDIAL_Y', 'TOD_PDIAL_Z'):
        import re
        m = re.search(r'#define\s+' + key + r'\s+(-?[0-9.]+)', text)
        got[key] = float(m.group(1)) if m else None
    return got


# =============================================================================================================== preview
def preview(J, imgs):
    """The terminal's front (shipped atlas over the low poly) with each frame laid over the plates and the dial."""
    R, s, t, low = frame_transform()
    P = (low['V'] @ R.T) * s + t
    ppu = 9
    depth, UV = raster_front(P, low['tv'], low['tuv'], -30.5, 30.5, -0.5, 88.5, ppu)
    atlas = np.asarray(Image.open(IMG / 'i_tod_pterm_c.png').convert('RGB')).astype(np.float64) / 255
    glow = np.asarray(Image.open(IMG / 'i_tod_pterm_e.png').convert('RGB')).astype(np.float64) / 255
    body = np.clip(sample(atlas, UV) * 0.75 + sample(glow, UV) * 0.6, 0, 1)
    body[depth < -1e8] = (0.16, 0.16, 0.19)
    H, W = depth.shape
    Y = -30.5 + (np.mgrid[0:H, 0:W][1] + 0.5) / ppu
    Z = 88.5 - (np.mgrid[0:H, 0:W][0] + 0.5) / ppu
    tiles = []
    dial_c = np.asarray(Image.open(IMG / 'i_tod_pdial_c.png').convert('RGB')).astype(np.float64) / 255
    dial_e = np.asarray(Image.open(IMG / 'i_tod_pdial_e.png').convert('RGB')).astype(np.float64) / 255
    D = J['dial']
    for name in ('dark', 'f1', 'f2', 'f3', 'on'):
        fr = np.asarray(Image.open(io.BytesIO(imgs[name])).convert('RGB')).astype(np.float64) / 255
        canvas = body.copy()
        for tr in J['screen_tris']:
            p = np.array(tr['pos'])
            uv = np.array(tr['uv'])
            (ay, az), (by, bz), (cy, cz) = p[:, 1:3]
            den = (bz - cz) * (ay - cy) + (cy - by) * (az - cz)
            if abs(den) < 1e-12:
                continue
            l1 = ((bz - cz) * (Y - cy) + (cy - by) * (Z - cz)) / den
            l2 = ((cz - az) * (Y - cy) + (ay - cy) * (Z - cz)) / den
            l3 = 1 - l1 - l2
            m = (l1 >= 0) & (l2 >= 0) & (l3 >= 0)
            u = l1 * uv[0, 0] + l2 * uv[1, 0] + l3 * uv[2, 0]
            v = l1 * uv[0, 1] + l2 * uv[1, 1] + l3 * uv[2, 1]
            fh, fw = fr.shape[:2]
            canvas[m] = fr[np.clip((v[m] * fh).astype(int), 0, fh - 1), np.clip((u[m] * fw).astype(int), 0, fw - 1)]
        rr = np.hypot(Y - D['y'], Z - D['z'])
        dm = rr < DIAL_R
        # the dial, turned to where it is in this frame (the spin runs dark..f3; ON is upright)
        ang = {'dark': 0.0, 'f1': 140.0, 'f2': 400.0, 'f3': 610.0, 'on': 720.0}[name]
        a = math.radians(ang)
        yl, zl = Y - D['y'], Z - D['z']
        ys, zs = yl * math.cos(a) + zl * math.sin(a), -yl * math.sin(a) + zl * math.cos(a)
        n = dial_c.shape[0]
        ix = np.clip(((ys + DIAL_R) / (2 * DIAL_R) * n).astype(int), 0, n - 1)
        iz = np.clip(((DIAL_R - zs) / (2 * DIAL_R) * n).astype(int), 0, n - 1)
        k = 2.6 if name == 'on' else 1.0
        canvas[dm] = np.clip(dial_c[iz, ix][dm] * 0.75 + dial_e[iz, ix][dm] * 0.6 * k, 0, 1)
        tiles.append((np.clip(canvas, 0, 1) * 255).astype(np.uint8))
    sheet = np.concatenate([np.pad(tl, ((0, 0), (6, 6), (0, 0)), constant_values=40) for tl in tiles], axis=1)
    im = Image.fromarray(sheet)
    b = io.BytesIO()
    im.save(b, 'JPEG', quality=90)
    return b.getvalue()


# ================================================================================================================== main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--measure', action='store_true')
    ap.add_argument('--check', action='store_true')
    a = ap.parse_args()
    if a.measure:
        measure()
    J = json.loads(JSON.read_text(encoding='utf-8'))
    assert J['revision'] == REVISION and J['fbx_md5'] == FBX[1] and J['sheet_md5'] == SHEET[1], 'json from another source'
    sheet = load_sheet()
    fr = frames(sheet)
    files = {IMG / f'i_tod_pscr_{k}.png': frame_png(v, FRAME_SIZE[k]) for k, v in fr.items()}
    files[GDT] = gdt_text().encode('utf-8')
    bad = []
    for p, data in files.items():
        if a.check:
            if not p.exists() or p.read_bytes() != data:
                bad.append(str(p.relative_to(ROOT)))
        else:
            p.parent.mkdir(parents=True, exist_ok=True)
            if not p.exists() or p.read_bytes() != data:
                p.write_bytes(data)
                log('wrote', p.relative_to(ROOT), len(data), 'B')
    for name, material, tris in (('tod_power_screen', 'mtl_tod_pscr_on', screen_tris(J)),
                                 ('tod_power_dial', 'mtl_tod_pdial', dial_tris(J))):
        if a.check:
            try:
                write_binary(name, material, tris, True)
            except AssertionError as e:
                bad.append(f'{name}.xmodel_bin ({e})')
        else:
            write_binary(name, material, tris, False)
            log('wrote', name, len(tris), 'tris')
    for img in ('i_tod_pdial_c.png', 'i_tod_pdial_e.png'):
        if not (IMG / img).exists():
            bad.append(f'{img} missing (run --measure)')
    want = {'TOD_PDIAL_X': J['dial']['x'], 'TOD_PDIAL_Y': J['dial']['y'], 'TOD_PDIAL_Z': J['dial']['z']}
    got = gsc_constants()
    for k, v in want.items():
        if got.get(k) is None or abs(got[k] - v) > 1e-3:
            bad.append(f'LOCKSTEP {GSC.name} {k} = {got.get(k)}, the json says {v}')
    if a.check:
        if bad:
            print('build_power_anim --check FAILED:\n  ' + '\n  '.join(bad))
            sys.exit(1)
        print(f'build_power_anim --check OK ({len(files)} files, 2 binaries, dial at x {J["dial"]["x"]} y {J["dial"]["y"]} z {J["dial"]["z"]})')
        return
    PREVIEW.write_bytes(preview(J, {k: files[IMG / f'i_tod_pscr_{k}.png'] for k in fr}))
    log('wrote', PREVIEW.relative_to(ROOT))
    if bad:
        log('NOTE:', *bad)


if __name__ == '__main__':
    main()
