#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# preview_views.py - render the GENERATED .map from real player eye positions,
# with the map's own wall/floor textures and the shipped sky behind it.
#
# WHY (2026-10-02, the surface refresh, docs/169): every surface on both towers
# is one of two vertigo textures (a black tile with a thin bright grid line, or
# a filled glowing tile) at three brightness rungs, and a design change to them
# could only be judged by a FULL build + bake + a climb. preview_crown.js draws
# flat-shaded silhouettes, which is right for the crown and useless for "does
# this floor read better". This draws what the material system draws:
#   * every face's own texture projection (the .map's "<mat> xs ys xo yo" axial
#     mapping), sampled with mip levels so far grid lines thin out as they do in
#     game instead of aliasing;
#   * the material's colorTint1 x scaleRGB read out of the real GDTs (vertigo
#     pack, source_data/tod_materials.gdt, the decal pack), tone-mapped;
#   * the map's light entities as a soft additive pool on the white albedo;
#   * patch-mesh decals (the chalk-mesh recipe) blended over what they sit on;
#   * the sky from docs/sky_preview/<theme>_sky_equirect.png behind everything;
#   * the spire's red volumetric fog on spire views.
# It is a PREVIEW, not the engine: no reflections (every vertigo material is a
# mirror in game), no bloom, no models (perk machines, crates, PaP are absent).
# Judge layout, texture rhythm and colour - never absolute brightness.
#
# USAGE
#   python tools/preview_views.py                         # every view, current map
#   python tools/preview_views.py --views base_spawn,climb_lap3
#   python tools/preview_views.py --map tmp/x.map --tag before --out tmp/prev
#   python tools/preview_views.py --list
# Output: <out>/<tag>_<view>.png (default out = tmp/preview_views, tag = now)
# -----------------------------------------------------------------------------
import argparse
import math
import os
import re
import sys
import time

import numpy as np
from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODTOOLS = os.environ.get('TOD_MODTOOLS', r'C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130')
GDTS = [
    os.path.join(MODTOOLS, 'source_data', '_emox', 'emox_mwiii_vertigo_assets.gdt'),
    os.path.join(REPO, 'source_data', 'tod_materials.gdt'),
    os.path.join(REPO, 'source_data', 'tod_refresh.gdt'),            # v19.69 the surface refresh (risers, floor numbers)
    os.path.join(MODTOOLS, 'model_export', 'codimages', 'arrow_coldwar_dogcanary', 'arrow_power_coldwar_dogcanary.gdt'),
]
TOOL_MAT = re.compile(r'^(clip|sky$|caulk|nodraw|portal|volume|sun_volume|umbra_volume|volume_fpstool|trigger|lightmap_gray)')

SP_X = 10240          # the spire axis (gen_tower_map.js SP_X) - fog applies east of SPIRE_FOG_X
SPIRE_FOG_X = 5600
LAP = 384             # LAP_RISE
FR = 192              # FLIGHT_RISE
EYE = 60              # standing eye height

# --- views: name -> (eye xyz, yaw deg (0 = +x, ccw), pitch deg (+ up), hfov deg) ----------
# Odd floors (1-based) climb the E then N flights and end on the NW landing; even floors
# climb W then S and end on the SE landing (gen_tower_map.js section 4).
def lap_b(lap1):
    return (lap1 - 1) * LAP

def tread_z(lap1, i):
    """top of tread i (1..16) of a flight that starts at height base"""
    return lap_b(lap1) + 12 * i


# (eye, yaw, pitch, hfov, doors) - doors 'open' hides every script_brushmodel (bought), 'closed'
# draws the lap doors shut (the trial / summit gates are hidden either way, as at load)
VIEWS = {
    'base_spawn':   ((-500, -60, EYE), 25, 14, 80, 'closed'),
    'base_arena':   ((-470, -470, EYE + 40), 45, 10, 80, 'closed'),
    'base_door':    ((80, -470, EYE), 25, 6, 80, 'closed'),
    'climb_lap3':   ((336, -140, tread_z(3, 4) + EYE), 90, 8, 80, 'open'),
    'climb_lap4':   ((-336, 140, tread_z(4, 4) + EYE), 270, 8, 80, 'open'),
    'landing_lap7': ((-336, 380, lap_b(7) + LAP + EYE), 270, 4, 80, 'closed'),
    'flight_lap12': ((-100, -336, lap_b(12) + FR + 60 + EYE), 0, 6, 80, 'open'),
    'up_lap15':     ((380, 380, lap_b(15) + FR + EYE), 225, 58, 80, 'open'),
    'down_lap30':   ((380, -380, lap_b(30) + LAP + EYE), 315, -50, 80, 'open'),
    'back_lap25':   ((336, 380, lap_b(25) + FR + EYE), 270, -12, 80, 'open'),
    'lounge20':     ((-480, -500, lap_b(20) + FR + EYE), 225, 2, 80, 'open'),
    'crown_lap45':  ((120, 336, tread_z(45, 16) + FR + EYE), 90, 34, 80, 'open'),
    'outside_mid':  ((-2600, -2400, 9200), 42, 6, 62, 'closed'),
    'door_lap8':    ((-336, 410, lap_b(8) + EYE), 270, -38, 80, 'closed'),
    'door_lap13':   ((336, -410, lap_b(13) + EYE), 90, -38, 80, 'closed'),
    'approach_13':  ((40, -336, lap_b(12) + FR + 12 * 12 + EYE), 0, -14, 80, 'closed'),
    'spire_door31': ((SP_X + 336, -410, lap_b(31) + EYE), 90, -38, 80, 'closed'),
    'spire_door2':  ((SP_X - 336, 410, lap_b(2) + EYE), 270, -38, 80, 'closed'),
    'spur_back20':  ((-704, -1500, lap_b(20) + FR + EYE), 64, 12, 80, 'open'),
    'spur_up30':    ((704, 1500, lap_b(30) + FR + EYE), 244, 34, 80, 'open'),
    'hub30_up':     ((SP_X - 200, 120, lap_b(30) + FR + EYE), 45, 55, 85, 'open'),
    'spire_arrive': ((SP_X - 400, -200, EYE), 20, 12, 80, 'closed'),
    'spire_lap15':  ((SP_X + 336, -140, tread_z(15, 4) + EYE), 90, 8, 80, 'open'),
    'spire_lap22':  ((SP_X - 336, 140, tread_z(22, 4) + EYE), 270, 6, 80, 'open'),
    'spire_hub30':  ((SP_X - 300, 300, lap_b(30) + FR + EYE), 315, 8, 85, 'open'),
    'spire_up40':   ((SP_X + 380, -380, lap_b(39) + LAP + EYE), 135, 55, 80, 'open'),
}


# --------------------------------------------------------------------------- GDT
def parse_gdts(paths):
    mats, imgs = {}, {}
    blk = re.compile(r'^\s*"([^"]+)"\s*\(\s*"([a-z_]+)\.gdf"\s*\)\s*\n\s*\{(.*?)\n\s*\}', re.S | re.M)
    for p in paths:
        if not os.path.exists(p):
            continue
        text = open(p, encoding='utf-8', errors='replace').read()
        for m in blk.finditer(text):
            kv = dict(re.findall(r'"([^"]+)"\s+"([^"]*)"', m.group(3)))
            (mats if m.group(2) == 'material' else imgs)[m.group(1)] = kv
    return mats, imgs


class Texture:
    def __init__(self, path):
        im = Image.open(path).convert('RGBA')
        self.levels = []
        a = np.asarray(im).astype(np.float32) / 255.0
        self.levels.append(a)
        while min(a.shape[0], a.shape[1]) > 4:
            h, w = a.shape[0] // 2, a.shape[1] // 2
            a = a[:h * 2, :w * 2].reshape(h, 2, w, 2, 4).mean(axis=(1, 3))
            self.levels.append(a)
        self.w = self.levels[0].shape[1]
        self.h = self.levels[0].shape[0]

    def sample(self, s, t, footprint_texels, wrap=True):
        # s, t in repeats (row 0 = image top at t = 1); nearest per mip, mip by footprint
        lvl = np.clip(np.floor(np.log2(np.maximum(footprint_texels, 1.0))), 0, len(self.levels) - 1).astype(np.int32)
        out = np.zeros((s.shape[0], 4), np.float32)
        for L in np.unique(lvl):
            m = lvl == L
            a = self.levels[L]
            hh, ww = a.shape[0], a.shape[1]
            ss = s[m] - np.floor(s[m]) if wrap else np.clip(s[m], 0, 0.9999)
            tt = t[m] - np.floor(t[m]) if wrap else np.clip(t[m], 0, 0.9999)
            x = np.clip((ss * ww).astype(np.int32), 0, ww - 1)
            y = np.clip(((1.0 - tt) * hh).astype(np.int32), 0, hh - 1)
            out[m] = a[y, x]
        return out


class Materials:
    def __init__(self, extra_gdts):
        self.mats, self.imgs = parse_gdts(GDTS + list(extra_gdts))
        self.tex_cache = {}
        self.info_cache = {}
        self.missing = set()

    def _img_path(self, img_name):
        kv = self.imgs.get(img_name)
        if not kv:
            return None
        rel = kv.get('baseImage', '').replace('\\\\', '\\').replace('\\', os.sep).replace('/', os.sep)
        for root in (REPO, MODTOOLS):
            p = os.path.join(root, rel)
            if rel and os.path.exists(p):
                return p
        return None

    def tex(self, path):
        if path not in self.tex_cache:
            self.tex_cache[path] = Texture(path)
        return self.tex_cache[path]

    def info(self, name):
        if name in self.info_cache:
            return self.info_cache[name]
        r = None
        if TOOL_MAT.match(name):
            r = None
        else:
            kv = self.mats.get(name)
            if kv is None:
                self.missing.add(name)
                r = {'tex': None, 'tint': np.array([1.0, 0.0, 1.0], np.float32), 'scale': 4.0, 'trans': False}
            else:
                img = kv.get('colorMap00') or kv.get('colorMap')
                path = self._img_path(img) if img and not img.startswith('$') else None
                tint = np.array([float(v) for v in (kv.get('colorTint1') or '1 1 1 1').split()[:3]], np.float32)
                scale = float(kv.get('scaleRGB', '1') or 1)
                mt = kv.get('materialType', '')
                trans = ('transparent' in mt) or kv.get('alphaTexture', '0') == '1' or kv.get('usage', '') == 'decal'
                r = {'tex': self.tex(path) if path else None, 'tint': tint, 'scale': scale, 'trans': trans, 'type': mt}
        self.info_cache[name] = r
        return r


# --------------------------------------------------------------------------- .map
PLANE = re.compile(r'^\s*\(\s*([^)]*)\)\s*\(\s*([^)]*)\)\s*\(\s*([^)]*)\)\s+(\S+)\s+(.*)$')


def plane_of(p1, p2, p3):
    a, b, c = np.array(p1, float), np.array(p2, float), np.array(p3, float)
    n = np.cross(a - b, c - b)
    ln = np.linalg.norm(n)
    if ln < 1e-9:
        return None
    n /= ln
    return n, float(np.dot(n, a))


def hull_faces(planes):
    """planes: list of (n, d, mat, texparams). Returns list of (n, d, mat, tp, verts(k,3))."""
    P = len(planes)
    N = np.array([p[0] for p in planes])
    D = np.array([p[1] for p in planes])
    axial = np.all(np.isclose(np.abs(N).max(axis=1), 1.0))
    verts = []
    if axial and P == 6:
        lo = np.array([-1e18] * 3)
        hi = np.array([1e18] * 3)
        for n, d in zip(N, D):
            ax = int(np.argmax(np.abs(n)))
            if n[ax] > 0:
                hi[ax] = min(hi[ax], d / n[ax])
            else:
                lo[ax] = max(lo[ax], d / n[ax])
        if np.any(hi <= lo):
            return []
        for i in range(8):
            verts.append([hi[0] if i & 1 else lo[0], hi[1] if i & 2 else lo[1], hi[2] if i & 4 else lo[2]])
        V = np.array(verts)
    else:
        for i in range(P):
            for j in range(i + 1, P):
                for k in range(j + 1, P):
                    A = np.array([N[i], N[j], N[k]])
                    det = np.linalg.det(A)
                    if abs(det) < 1e-8:
                        continue
                    p = np.linalg.solve(A, np.array([D[i], D[j], D[k]]))
                    if np.any(N @ p > D + 0.02):
                        continue
                    if not any(np.linalg.norm(p - q) < 0.02 for q in verts):
                        verts.append(p)
        if len(verts) < 4:
            return []
        V = np.array(verts)
    faces = []
    for (n, d, mat, tp) in planes:
        on = np.abs(V @ n - d) < 0.03
        vs = V[on]
        if len(vs) < 3:
            continue
        c = vs.mean(axis=0)
        u = vs[0] - c
        u /= (np.linalg.norm(u) or 1)
        v = np.cross(n, u)
        ang = np.arctan2((vs - c) @ v, (vs - c) @ u)
        vs = vs[np.argsort(ang)]
        faces.append((n, d, mat, tp, vs))
    return faces


def parse_map(path, hide_targets):
    """Returns (faces, decals, lights). faces: dicts with n, d, mat, uvmap, verts, label."""
    text = open(path, encoding='utf-8', errors='replace').read().split('\n')
    faces, decals, lights = [], [], []
    depth = 0
    ent = None
    brush = None
    label = None
    in_mesh = False
    mesh = None
    i = 0
    nlines = len(text)
    while i < nlines:
        line = text[i]
        st = line.strip()
        if st.startswith('// brush') or st.startswith('// entity'):
            mm = re.match(r'//\s+(?:brush|entity)\s+\d+\s*(?:[—-]\s*(.*))?$', st)
            label = (mm.group(1) or '').strip() if mm else ''
            i += 1
            continue
        if st == '{':
            depth += 1
            if depth == 1:
                ent = {'kv': {}, 'label': label, 'brushes': [], 'meshes': []}
            elif depth == 2:
                brush = {'planes': [], 'label': label}
            i += 1
            continue
        if st == '}':
            if in_mesh:
                in_mesh = False
                depth -= 1
                i += 1
                continue
            if depth == 2 and brush is not None:
                if mesh is not None:
                    ent['meshes'].append(mesh)
                    mesh = None
                elif brush['planes']:
                    ent['brushes'].append(brush)
                brush = None
            elif depth == 1 and ent is not None:
                _flush_entity(ent, faces, decals, lights, hide_targets)
                ent = None
            depth -= 1
            i += 1
            continue
        if depth == 1 and st.startswith('"'):
            kv = re.findall(r'"([^"]*)"', st)
            if len(kv) >= 2:
                ent['kv'][kv[0]] = kv[1]
        elif depth == 2 and st == 'mesh':
            # chalk-mesh decal: material on the next non-keyword line, then (cols) blocks
            mesh = {'mat': None, 'verts': [], 'label': brush['label'] if brush else label}
            j = i + 1
            while j < nlines and text[j].strip() != '{':
                j += 1
            j += 1
            depth += 1
            in_mesh = True
            words = []
            while j < nlines:
                s = text[j].strip()
                if s.startswith('contents') or s.startswith('toolFlags') or s == '':
                    j += 1
                    continue
                if mesh['mat'] is None:
                    mesh['mat'] = s
                    j += 1
                    continue
                if s == 'lightmap_gray' or re.match(r'^\d+ \d+ \d+ \d+$', s) or s == '(' or s == ')':
                    j += 1
                    continue
                if s.startswith('v '):
                    nums = s.split()
                    mesh['verts'].append((float(nums[1]), float(nums[2]), float(nums[3]), float(nums[5]), float(nums[6])))
                    j += 1
                    continue
                break
            i = j
            continue
        elif depth == 2 and brush is not None:
            m = PLANE.match(line)
            if m:
                pts = [list(map(float, m.group(k).split())) for k in (1, 2, 3)]
                pl = plane_of(*pts)
                if pl:
                    rest = m.group(5).split()
                    try:
                        tp = [float(x) for x in rest[:4]]
                    except ValueError:
                        tp = [128.0, 128.0, 0.0, 0.0]
                    brush['planes'].append((pl[0], pl[1], m.group(4), tp))
        i += 1
    return faces, decals, lights


def _uvmap_axial(n, tp):
    xs, ys, xo, yo = tp
    xs = xs or 128.0
    ys = ys or 128.0
    ax = int(np.argmax(np.abs(n)))
    if ax == 2:
        U, V = np.array([1.0, 0, 0]), np.array([0, 1.0, 0])
    elif ax == 0:
        U, V = np.array([0, 1.0, 0]), np.array([0, 0, 1.0])
    else:
        U, V = np.array([1.0, 0, 0]), np.array([0, 0, 1.0])
    return (U / xs, xo / xs, V / ys, yo / ys, 1.0 / xs)


def _flush_entity(ent, faces, decals, lights, hide_targets):
    cls = ent['kv'].get('classname', '')
    tn = ent['kv'].get('targetname', '')
    if cls == 'light':
        try:
            org = [float(v) for v in ent['kv']['origin'].split()]
            col = [float(v) for v in ent['kv'].get('_color', '1 1 1').split()[:3]]
            rad = float(ent['kv'].get('radius', '300'))
            bake = float(ent['kv'].get('bake_intensity_scale', '1'))
            lights.append((np.array(org), np.array(col), rad, bake))
        except (KeyError, ValueError):
            pass
        return
    if cls not in ('worldspawn', 'script_brushmodel', 'func_group', ''):
        return
    if cls == 'script_brushmodel' and any(re.search(h, tn) for h in hide_targets):
        return
    for b in ent['brushes']:
        if all(TOOL_MAT.match(p[2]) for p in b['planes']):
            continue
        for (n, d, mat, tp, vs) in hull_faces(b['planes']):
            if TOOL_MAT.match(mat):
                continue
            faces.append({'n': n, 'd': d, 'mat': mat, 'uv': _uvmap_axial(n, tp), 'verts': vs, 'label': b['label'],
                          'door': cls == 'script_brushmodel'})
    for m in ent['meshes']:
        if not m['mat'] or len(m['verts']) != 4:
            continue
        # patch order: col0 (bottom, top), col1 (bottom, top) -> quad c0b, c1b, c1t, c0t
        c0b, c0t, c1b, c1t = m['verts']
        P = np.array([c0b[:3], c1b[:3], c1t[:3], c0t[:3]])
        UVt = np.array([[c0b[3], c0b[4]], [c1b[3], c1b[4]], [c1t[3], c1t[4]], [c0t[3], c0t[4]]])
        # A DECAL FACES u_dir x v_dir (gen_tower_map.js's chalk-mesh winding rule: u runs
        # column 0 -> column 1, v bottom -> top). The brush-plane formula plane_of uses is
        # the OPPOSITE orientation for this vertex order, and culled every decal.
        nrm = np.cross(P[1] - P[0], P[3] - P[0])
        ln = np.linalg.norm(nrm)
        if ln < 1e-9:
            continue
        n = nrm / ln
        d = float(n @ P[0])
        # affine (u,v) = M @ p + o from three corners, in the plane
        e1, e2 = P[1] - P[0], P[3] - P[0]
        G = np.array([[e1 @ e1, e1 @ e2], [e1 @ e2, e2 @ e2]])
        du = np.linalg.solve(G, np.array([UVt[1, 0] - UVt[0, 0], UVt[3, 0] - UVt[0, 0]]))
        dv = np.linalg.solve(G, np.array([UVt[1, 1] - UVt[0, 1], UVt[3, 1] - UVt[0, 1]]))
        gu = du[0] * e1 + du[1] * e2
        gv = dv[0] * e1 + dv[1] * e2
        decals.append({'n': n, 'd': d, 'mat': m['mat'], 'verts': P, 'gu': gu / 1024.0, 'ou': (UVt[0, 0] - gu @ P[0]) / 1024.0,
                       'gv': gv / 1024.0, 'ov': (UVt[0, 1] - gv @ P[0]) / 1024.0, 'label': m['label']})


# --------------------------------------------------------------------------- render
def camera(eye, yaw, pitch):
    y, p = math.radians(yaw), math.radians(pitch)
    fwd = np.array([math.cos(p) * math.cos(y), math.cos(p) * math.sin(y), math.sin(p)])
    right = np.cross(fwd, [0, 0, 1.0])
    right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    return np.array(eye, float), fwd, right, up


def tonemap(E):
    return 1.0 - np.exp(-np.maximum(E, 0))


def render_view(name, cfg, faces, decals, lights, mats, sky, W, H, ss, show_lights=True):
    eye, yaw, pitch, hfov, doors = cfg
    eye, fwd, right, up = camera(eye, yaw, pitch)
    open_doors = (doors == 'open')
    Ws, Hs = W * ss, H * ss
    fx = (Ws / 2) / math.tan(math.radians(hfov) / 2)
    xs = (np.arange(Ws) + 0.5 - Ws / 2) / fx
    ys = -(np.arange(Hs) + 0.5 - Hs / 2) / fx
    X, Y = np.meshgrid(xs, ys)
    dirs = fwd[None, None, :] + X[..., None] * right[None, None, :] + Y[..., None] * up[None, None, :]
    dirs /= np.linalg.norm(dirs, axis=2, keepdims=True)
    zbuf = np.full((Hs, Ws), np.inf, np.float32)
    fid = np.full((Hs, Ws), -1, np.int32)
    near = 2.0

    def project_poly(V):
        rel = V - eye
        cz = rel @ fwd
        cx = rel @ right
        cy = rel @ up
        poly = []
        k = len(V)
        for a in range(k):
            b = (a + 1) % k
            za, zb = cz[a], cz[b]
            if za >= near:
                poly.append((cx[a], cy[a], za))
            if (za >= near) != (zb >= near):
                t = (near - za) / (zb - za)
                poly.append((cx[a] + (cx[b] - cx[a]) * t, cy[a] + (cy[b] - cy[a]) * t, near))
        if len(poly) < 3:
            return None
        return np.array([[Ws / 2 + px * fx / pz, Hs / 2 - py * fx / pz] for (px, py, pz) in poly])

    def raster(poly2, n, d, idx, depth_ok=None):
        x0 = max(0, int(math.floor(poly2[:, 0].min())))
        x1 = min(Ws - 1, int(math.ceil(poly2[:, 0].max())))
        y0 = max(0, int(math.floor(poly2[:, 1].min())))
        y1 = min(Hs - 1, int(math.ceil(poly2[:, 1].max())))
        if x1 < x0 or y1 < y0:
            return None
        px = np.arange(x0, x1 + 1) + 0.5
        py = np.arange(y0, y1 + 1) + 0.5
        PX, PY = np.meshgrid(px, py)
        inside = np.ones(PX.shape, bool)
        k = len(poly2)
        area = 0.0
        for a in range(k):
            b = (a + 1) % k
            area += poly2[a, 0] * poly2[b, 1] - poly2[b, 0] * poly2[a, 1]
        sgn = 1.0 if area > 0 else -1.0
        for a in range(k):
            b = (a + 1) % k
            ex, ey = poly2[b, 0] - poly2[a, 0], poly2[b, 1] - poly2[a, 1]
            inside &= ((PX - poly2[a, 0]) * ey - (PY - poly2[a, 1]) * ex) * sgn <= 1e-6
        if not inside.any():
            return None
        dsub = dirs[y0:y1 + 1, x0:x1 + 1]
        den = dsub @ n
        with np.errstate(divide='ignore', invalid='ignore'):
            t = (d - eye @ n) / den
        ok = inside & (t > 0) & np.isfinite(t)
        return (y0, y1, x0, x1, t, ok)

    for idx, f in enumerate(faces):
        if open_doors and f['door']:
            continue
        n = f['n']
        c = f['verts'].mean(axis=0)
        if (c - eye) @ n >= -1e-3:
            continue                                   # back face
        rel = f['verts'] - eye
        cz = rel @ fwd
        if cz.max() < near:
            continue
        cx = rel @ right
        cy = rel @ up
        lim = math.tan(math.radians(hfov) / 2) * 1.05
        czc = np.maximum(cz, near)
        if (cx / czc).min() > lim or (cx / czc).max() < -lim:
            if cz.min() > near:
                continue
        vlim = lim * Hs / Ws * 1.05
        if (cy / czc).min() > vlim or (cy / czc).max() < -vlim:
            if cz.min() > near:
                continue
        poly2 = project_poly(f['verts'])
        if poly2 is None:
            continue
        r = raster(poly2, n, f['d'], idx)
        if r is None:
            continue
        y0, y1, x0, x1, t, ok = r
        zsub = zbuf[y0:y1 + 1, x0:x1 + 1]
        win = ok & (t < zsub)
        if win.any():
            zsub[win] = t[win]
            fid[y0:y1 + 1, x0:x1 + 1][win] = idx

    img = np.zeros((Hs, Ws, 3), np.float32)
    # sky
    skym = fid < 0
    if sky is not None and skym.any():
        d = dirs[skym]
        az = np.arctan2(d[:, 1], d[:, 0])
        el = np.arcsin(np.clip(d[:, 2], -1, 1))
        u = (az / (2 * math.pi)) % 1.0
        v = 0.5 - el / math.pi
        sh, sw = sky.shape[0], sky.shape[1]
        img[skym] = sky[np.clip((v * sh).astype(int), 0, sh - 1), np.clip((u * sw).astype(int), 0, sw - 1)]
    # surfaces, grouped by material
    hit = ~skym
    if hit.any():
        hy, hx = np.nonzero(hit)
        f_ids = fid[hy, hx]
        tt = zbuf[hy, hx]
        dd = dirs[hy, hx]
        P = eye[None, :] + dd * tt[:, None]
        Nn = np.array([f['n'] for f in faces])[f_ids]
        cosi = np.abs(np.sum(Nn * dd, axis=1))
        pix_ang = 1.0 / fx
        foot_world = tt * pix_ang / np.maximum(cosi, 0.08)
        col = np.zeros((len(hy), 3), np.float32)
        mat_of = np.array([f['mat'] for f in faces], dtype=object)[f_ids]
        uvs = [f['uv'] for f in faces]
        for mname in np.unique(mat_of):
            m = mat_of == mname
            info = mats.info(mname)
            if info is None:
                continue
            ids = f_ids[m]
            Pm = P[m]
            Ua = np.array([uvs[i][0] for i in ids])
            Uo = np.array([uvs[i][1] for i in ids])
            Va = np.array([uvs[i][2] for i in ids])
            Vo = np.array([uvs[i][3] for i in ids])
            inv_xs = np.array([uvs[i][4] for i in ids])
            s = np.sum(Pm * Ua, axis=1) + Uo
            t2 = np.sum(Pm * Va, axis=1) + Vo
            if info['tex'] is not None:
                fp = foot_world[m] * inv_xs * info['tex'].w
                tex = info['tex'].sample(s, t2, fp)[:, :3]
            else:
                tex = np.ones((m.sum(), 3), np.float32)
            E = tex * info['tint'][None, :] * info['scale'] * 0.12
            col[m] = E
        # point lights on the white albedo - computed on a coarse grid (light pools are smooth) and
        # spread back to every pixel of the cell; the pool colour is what matters, not its edge
        if show_lights and lights:
            st = 4
            cyi = np.arange(st // 2, Hs, st)
            cxi = np.arange(st // 2, Ws, st)
            CY, CX = np.meshgrid(cyi, cxi, indexing='ij')
            cf = fid[CY, CX]
            cval = cf >= 0
            Lg = np.zeros(CY.shape + (3,), np.float32)
            if cval.any():
                Pc = eye[None, :] + dirs[CY[cval], CX[cval]] * zbuf[CY[cval], CX[cval]][:, None]
                Nc = np.array([f['n'] for f in faces])[cf[cval]]
                lsum = np.zeros((len(Pc), 3), np.float32)
                pmin, pmax = Pc.min(axis=0), Pc.max(axis=0)
                for (org, lcol, rad, bake) in lights:
                    if np.any(org + rad < pmin) or np.any(org - rad > pmax):
                        continue
                    dv = org[None, :] - Pc
                    dist = np.linalg.norm(dv, axis=1)
                    nm = dist < rad
                    if not nm.any():
                        continue
                    ndl = np.clip(np.sum(Nc[nm] * dv[nm], axis=1) / np.maximum(dist[nm], 1e-3), 0, 1)
                    fall = (1 - dist[nm] / rad) ** 2
                    lsum[nm] += (lcol[None, :] * (fall * ndl * 0.45 * bake)[:, None]).astype(np.float32)
                Lg[cval] = lsum
            Lfull = np.repeat(np.repeat(Lg, st, axis=0), st, axis=1)[:Hs, :Ws]
            col += Lfull[hy, hx]
        col += np.array([0.010, 0.010, 0.022], np.float32)        # sky ambient
        out = tonemap(col)
        # spire fog (gen: TOD_SPIRE_FOG_* in _tod_atmosphere.gsc)
        spm = P[:, 0] > SPIRE_FOG_X
        if spm.any():
            fogk = 0.90 * (1 - np.power(0.5, tt[spm] / 260.0))
            fc = np.array([0.46, 0.03, 0.05], np.float32)
            out[spm] = out[spm] * (1 - fogk[:, None]) + fc[None, :] * fogk[:, None] * 0.55
        img[hy, hx] = out
    if eye[0] > SPIRE_FOG_X and sky is not None:
        img[skym] = img[skym] * 0.1 + np.array([0.46, 0.03, 0.05], np.float32) * 0.55 * 0.9
    # decals: transparent overlays, depth-tested against what they sit on
    for dc in decals:
        info = mats.info(dc['mat'])
        if info is None:
            continue
        n = dc['n']
        if (dc['verts'].mean(axis=0) - eye) @ n >= 0:
            continue
        poly2 = project_poly(dc['verts'])
        if poly2 is None:
            continue
        r = raster(poly2, n, dc['d'], -1)
        if r is None:
            continue
        y0, y1, x0, x1, t, ok = r
        zsub = zbuf[y0:y1 + 1, x0:x1 + 1]
        vis = ok & (t < zsub + 3.0)
        if not vis.any():
            continue
        dsub = dirs[y0:y1 + 1, x0:x1 + 1][vis]
        Pd = eye[None, :] + dsub * t[vis][:, None]
        s = Pd @ dc['gu'] + dc['ou']
        tt2 = Pd @ dc['gv'] + dc['ov']
        if info['tex'] is None:
            continue
        foot = t[vis] / fx * np.linalg.norm(dc['gu']) * info['tex'].w
        smp = info['tex'].sample(s, -tt2, foot, wrap=True)   # image row = 1 + v/1024 (the chalk-mesh UV rule)
        rgb = tonemap(smp[:, :3] * info['tint'][None, :] * info['scale'] * 0.12)
        a = smp[:, 3:4] if info.get('trans') else np.ones((len(s), 1), np.float32)
        sub = img[y0:y1 + 1, x0:x1 + 1]
        sub[vis] = sub[vis] * (1 - a) + rgb * a
    # downsample
    img = img.reshape(H, ss, W, ss, 3).mean(axis=(1, 3))
    return np.clip(img, 0, 1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--map', default=os.path.join(REPO, 'map_source', 'zm', 'zm_tower_of_doom.map'))
    ap.add_argument('--out', default=os.path.join(REPO, 'tmp', 'preview_views'))
    ap.add_argument('--tag', default=time.strftime('%H%M%S'))
    ap.add_argument('--views', default='')
    ap.add_argument('--w', type=int, default=1280)
    ap.add_argument('--h', type=int, default=720)
    ap.add_argument('--ss', type=int, default=2)
    ap.add_argument('--sky', default=os.path.join(REPO, 'docs', 'sky_preview', 'night_sky_equirect.png'))
    ap.add_argument('--gdt', action='append', default=[])
    ap.add_argument('--no-lights', action='store_true')
    ap.add_argument('--list', action='store_true')
    a = ap.parse_args()
    if a.list:
        for k, v in VIEWS.items():
            print(f'{k:14s} eye={v[0]} yaw={v[1]} pitch={v[2]} fov={v[3]} doors={v[4]}')
        return
    names = [v for v in a.views.split(',') if v] or list(VIEWS)
    for nme in names:
        if nme not in VIEWS:
            sys.exit(f'unknown view {nme} (--list)')
    t0 = time.time()
    hide = [r'^tod_spire_hall_gate', r'^tod_spire_summit_gate']
    faces, decals, lights = parse_map(a.map, hide)
    mats = Materials(a.gdt)
    sky = np.asarray(Image.open(a.sky).convert('RGB')).astype(np.float32) / 255.0 if os.path.exists(a.sky) else None
    print(f'parsed {len(faces)} faces, {len(decals)} decals, {len(lights)} lights in {time.time() - t0:.1f}s')
    os.makedirs(a.out, exist_ok=True)
    for nme in names:
        t1 = time.time()
        img = render_view(nme, VIEWS[nme], faces, decals, lights, mats, sky, a.w, a.h, a.ss, not a.no_lights)
        p = os.path.join(a.out, f'{a.tag}_{nme}.png')
        Image.fromarray((img * 255 + 0.5).astype(np.uint8)).save(p)
        print(f'  {nme:14s} {time.time() - t1:5.1f}s -> {os.path.relpath(p, REPO)}')
    if mats.missing:
        print('  materials not found in the GDTs (drawn magenta): ' + ', '.join(sorted(mats.missing)))


if __name__ == '__main__':
    main()
