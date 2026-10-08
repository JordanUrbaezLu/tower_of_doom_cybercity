"""Which way does a tangent-space normal map's GREEN point? (OpenGL +Y up vs DirectX -Y down)

A normal map baked from a height field h(col, row) is a gradient field, and a
gradient field has no curl. With gx = R and gy = G (both decoded to slopes):
  OpenGL  (green = up in the image):   d(gx)/d(row) == -d(gy)/d(col)  -> corr < 0
  DirectX (green = down in the image): d(gx)/d(row) == +d(gy)/d(col)  -> corr > 0
so the sign of the correlation between those two mixed derivatives names the
convention. Seams and flat texels are masked out; nothing about the mesh is needed.

GROUND TRUTH (2026-10-02, tmp/fanprops_20261002/normal_control.py): a bumpy plane
baked by Blender with normal_g POS_Y scores -0.87 and with NEG_Y +0.86.
Nikolai's Meshy maps score +0.38 (sign) and +0.35 (chest): DIRECTX - the same
convention BO3 uses (the heavenly altar / cyber inducer bakes are NEG_Y), so they
ship unflipped, and only Blender (which reads OpenGL) needs the flip.

  python tools/fan_props/normal_convention.py <normal.png> [...]
"""
import sys

import numpy as np
from PIL import Image

Image.MAX_IMAGE_PIXELS = None


def convention(path, size=2048):
    im = Image.open(path).convert('RGB')
    if im.size[0] > size:
        im = im.resize((size, size), Image.BOX)
    n = np.asarray(im).astype(np.float64) / 255 * 2 - 1
    nz = np.maximum(n[..., 2], 0.2)
    gx, gy = n[..., 0] / nz, n[..., 1] / nz
    a = gx[1:, 1:] - gx[:-1, 1:]      # d gx / d row  (row 0 = the image's top)
    b = gy[1:, 1:] - gy[1:, :-1]      # d gy / d col
    m = (np.abs(a) < 0.3) & (np.abs(b) < 0.3) & ((np.abs(a) + np.abs(b)) > 0.01)
    c = float(np.corrcoef(a[m], b[m])[0, 1])
    name = 'OpenGL (+Y)' if c < -0.1 else ('DirectX (-Y)' if c > 0.1 else 'unclear')
    return c, int(m.sum()), name


if __name__ == '__main__':
    for p in sys.argv[1:]:
        c, n, name = convention(p)
        print(f'{p}: corr {c:+.3f} over {n} texels -> {name}')
