"""Stage 06 - conduits and service detail: three corrugated power conduits from
the crown's back drop into the rear junction (they hang behind the rear claws,
never past x = -23, so the device still clears the arena wall), ferrules and
cable glands at both ends, and a pair of thin data lines from the coil."""
import sys, importlib, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import design_lib as D
importlib.reload(D)
from design_lib import *
from mathutils import Vector

assert scene.get('mcp_port') == 9884
P = palette()
begin('06 conduits')

CABLE_RZ = [(13.4, 51.6), (16.8, 53.8), (20.4, 51.4), (21.9, 43.0), (21.8, 31.0), (20.9, 20.0), (19.6, 13.6), (19.2, 11.1)]
for k, deg in enumerate((166.5, 180.0, 193.5)):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    pts = [Vector((r * c, r * s, z)) for r, z in CABLE_RZ]
    # the last point lands on the junction housing's top at its actual x/y
    jy = (-4.6, 0.0, 4.6)[k]
    pts[-1] = Vector((-18.75, jy, 11.0)); pts[-2] = Vector((-19.0, jy * 0.95, 13.4))
    cable('power conduit %d' % k, pts, 1.05, P['rubber'], rib_every=1.25, rib=0.1, sides=10, steps=8)
    # ferrules: titanium sleeves at both ends, aligned to the cable
    for end, nxt in ((pts[0], pts[1]), (pts[-1], pts[-2])):
        d = (nxt - end).normalized()
        f = lathe('conduit ferrule %d' % k, [(0, 0.0), (1.45, 0.0), (1.45, 1.6), (1.25, 1.85), (0, 1.85)], P['titanium'],
                  seg=24, smooth=40)
        f.rotation_mode = 'QUATERNION'; f.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
        f.location = end - d * 0.35
        apply_transform(f)
    gland = lathe('junction gland %d' % k, [(0, 10.9), (1.7, 10.9), (1.7, 11.5), (1.4, 11.75), (0, 11.75)], P['steel'],
                  seg=24, smooth=40)
    gland.location = (-18.75, jy, 0); apply_transform(gland)

# thin data lines from the coil collar to the junction face
for k, deg in enumerate((150.0, 210.0)):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    y = (-6.0, 6.0)[k]
    pts = [Vector((13.2 * c, 13.2 * s, 22.4)), Vector((15.6 * c, 15.6 * s, 21.2)),
           Vector((-17.3, y * 0.9, 16.0)), Vector((-21.0, y * 0.75, 10.4)), Vector((-21.95, y * 0.7, 8.6))]
    cable('data line %d' % k, pts, 0.32, P['rubber'], sides=8, steps=10)

save('06 conduits')
print('CONDUITS_OK')
