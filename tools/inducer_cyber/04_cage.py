"""Stage 04 - the cage: four bowed armoured ribs on the diagonals carry the crown
over the crystal. Each rib wears a STATUS strip outside (cyan idle, red ON) and
a CORE strip inside, facing the crystal; titanium sleeves and clamps at the ends.
The diagonals keep the front (+X) open so the crystal is the first thing seen."""
import sys, importlib, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import design_lib as D
importlib.reload(D)
from design_lib import *
from mathutils import Vector

assert scene.get('mcp_port') == 9884
P = palette()
begin('04 cage')

RIB_RZ = [(12.4, 21.9), (13.7, 26.8), (15.3, 33.6), (15.5, 40.0), (14.5, 46.0), (13.8, 49.6)]
W, DEPTH = 3.0, 2.4


def rib_path(a):
    c, s = math.cos(a), math.sin(a)
    return catmull([(r * c, r * s, z) for r, z in RIB_RZ], steps=7)


def offset_path(path, a, dist):
    """Offset a path lying in the radial plane at azimuth a along its in-plane normal
    (positive = outward, away from the axis)."""
    rad = Vector((math.cos(a), math.sin(a), 0))
    out = []
    for i, p in enumerate(path):
        t = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)])
        tr, tz = t.dot(rad), t.z
        n = Vector((tz, -tr)); n.normalize()
        out.append(p + rad * (n.x * dist) + Vector((0, 0, n.y * dist)))
    return out


def window(path, t0, t1):
    L = [0.0]
    for i in range(1, len(path)):
        L.append(L[-1] + (path[i] - path[i - 1]).length)
    tot = L[-1]
    return [p for p, l in zip(path, L) if t0 * tot <= l <= t1 * tot]


for i, a in enumerate(radial(4, 45)):
    path = rib_path(a)
    rib = sweep('cage rib %d' % i, path, rounded_rect_section(W, DEPTH, 0.55, 2), P['graphite'], smooth=35)
    sweep('cage rib status strip %d' % i, offset_path(path, a, DEPTH / 2 + 0.06)[3:-3],
          rounded_rect_section(0.8, 0.26, 0.1, 1), P['status'], smooth=35)
    sweep('cage rib core strip %d' % i, offset_path(path, a, -(DEPTH / 2 + 0.05))[4:-4],
          rounded_rect_section(0.55, 0.2, 0.08, 1), P['core'], smooth=35)
    for t0, t1 in ((0.24, 0.31), (0.69, 0.76)):
        seg = window(path, t0, t1)
        if len(seg) >= 2:
            bevel(sweep('cage rib sleeve %d' % i, seg, rounded_rect_section(W * 1.16, DEPTH * 1.2, 0.6, 2), P['titanium'], smooth=35),
                  0.08, 1, 40)
    # end clamps: where the rib bites into the coil collar and the crown collar
    c, s = math.cos(a), math.sin(a)
    for (r, z, h) in ((12.9, 23.2, 2.4), (13.9, 47.6, 2.2)):
        cl = box('cage rib clamp %d' % i, (0, 0, 0), (3.3, 4.0, h), P['titanium'])
        cl.location = (r * c, s * r, z); cl.rotation_euler = (0, 0, a)
        apply_transform(cl); bevel(cl, 0.2, 2, 40)
        for t in (-1.2, 1.2):
            tan = Vector((-s, c, 0))
            p = Vector((c * (r + 1.65), s * (r + 1.65), z)) + tan * t
            hex_bolt('cage clamp bolt %d' % i, p, Vector((c, s, 0)), P['steel'], r=0.32, h=0.2)

save('04 cage')
print('CAGE_OK')
