"""Stage 05 - the crown: the emitter dish that answers the coil from above, the
heat-sink collar with its STATUS band, radial fins, the titanium dome, four
claws rising off the ribs with emitter tips (the in-game sparks spawn at the two
front tips), and the beacon - a lamp inside a shutter that turns (bone
j_beacon), sweeping its light round the arena like an alarm when Rampage is ON.
"""
import sys, importlib, math, json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import design_lib as D
importlib.reload(D)
from design_lib import *
from mathutils import Vector

assert scene.get('mcp_port') == 9884
P = palette()
begin('05 crown')

# under-dish + lens pointing down at the crystal
lathe('crown under dish', [(0, 46.3), (3.6, 46.3), (5.6, 46.75), (9.0, 47.35), (10.2, 47.6), (10.2, 48.2), (0, 48.2)],
      P['graphite'], seg=64, smooth=30)
lathe('crown under lens', [(0, 45.45), (1.3, 45.5), (2.55, 45.72), (3.35, 46.02), (3.55, 46.4), (0, 46.4)],
      P['core'], seg=48, smooth=60)
torus('crown under lens rim', 3.72, 0.3, P['titanium'], seg=40, ring=8, center=(0, 0, 46.32))
# collar, its trims and the status band that rings the crown
bevel(lathe('crown collar', [(9.8, 47.6), (15.3, 47.6), (16.1, 48.4), (16.1, 50.8), (15.5, 51.5), (9.8, 51.5)],
            P['graphite'], seg=64, closed=True), 0.14, 2, 40)
lathe('crown status band', [(15.95, 49.05), (16.32, 49.05), (16.32, 50.15), (15.95, 50.15)], P['status'], seg=64, closed=True)
bevel(lathe('crown lower trim', [(14.4, 47.15), (15.7, 47.15), (15.7, 47.7), (14.4, 47.7)], P['titanium'], seg=64, closed=True),
      0.08, 1, 40)
# radial heat-sink fins
for i, a in enumerate(radial(24, 7.5)):
    pts = [(9.9, 51.45), (14.9, 51.45), (14.9, 52.35), (12.3, 55.1), (9.9, 55.1)]
    fin = loft('crown fin %d' % i, [(-0.27, [(x, z) for x, z in pts]), (0.27, [(x, z) for x, z in pts])], P['graphite'])
    # loft builds in XY; turn the (r, z) profile upright, then round to the azimuth
    me = fin.data
    for v in me.vertices:
        r, z, y = v.co.x, v.co.y, v.co.z
        v.co = Vector((r * math.cos(a) - y * math.sin(a), r * math.sin(a) + y * math.cos(a), z))
    me.update()
    recalc_normals(fin)          # the axis swap above is a mirror: re-wind outward
    bevel(fin, 0.07, 1, 40)
# dome, its heat ring and the beacon housing
bevel(lathe('crown dome', [(0, 51.3), (9.9, 51.3), (9.9, 52.1), (8.7, 54.3), (6.6, 56.4), (3.9, 57.8), (2.3, 58.25), (0, 58.25)],
            P['titanium'], seg=64, smooth=35), 0.1, 1, 50)
torus('crown dome heat ring', 7.7, 0.23, P['core'], seg=56, ring=8, center=(0, 0, 55.35), rot=(0, 0, 0))
bevel(lathe('beacon base', [(0, 58.1), (2.1, 58.1), (2.1, 59.0), (1.55, 59.45), (1.55, 59.75), (0, 59.75)],
            P['graphite'], seg=48, smooth=40), 0.06, 1, 40)
lathe('beacon lamp', [(0, 59.6), (1.42, 59.6), (1.38, 60.6), (1.2, 61.5), (0.8, 62.05), (0, 62.25)], P['core'], seg=40, smooth=60)
bevel(lathe('beacon cap', [(0, 62.1), (1.05, 62.1), (1.05, 62.6), (0, 62.6)], P['graphite'], seg=32, smooth=40), 0.05, 1, 40)
lathe('antenna mast', [(0, 62.5), (0.26, 62.5), (0.2, 66.4), (0, 66.4)], P['steel'], seg=16, smooth=60)
lathe('antenna tip light', [(0, 66.2), (0.44, 66.45), (0.44, 66.85), (0, 67.15)], P['status'], seg=16, smooth=60)

# the turning shutter: a 220-degree curved plate round the lamp, a status edge
z_mid = A.BONES['j_beacon']['pivot'][2]
path = [Vector((2.0 * math.cos(math.radians(70 + 220 * i / 36)), 2.0 * math.sin(math.radians(70 + 220 * i / 36)), z_mid))
        for i in range(37)]
shutter = sweep('beacon shutter', path, rounded_rect_section(0.3, 2.5, 0.1, 2), P['graphite'], smooth=40)
rig_bone(shutter, 'j_beacon')
for k, ang in enumerate((70, 290)):
    a = math.radians(ang)
    edge = box('beacon shutter edge light %d' % k, (0, 0, 0), (0.42, 0.26, 2.3), P['status'])
    edge.rotation_euler = (0, 0, a); edge.location = (2.0 * math.cos(a), 2.0 * math.sin(a), z_mid)
    rig_bone(apply_transform(edge), 'j_beacon')

# claws: continue each rib up through the collar, tapering to an emitter tip
CLAW_RZ = [(15.0, 48.6), (17.4, 51.8), (18.3, 55.8), (16.9, 59.6), (14.2, 62.1)]
tips = {}
for i, a in enumerate(radial(4, 45)):
    c, s = math.cos(a), math.sin(a)
    path = catmull([(r * c, r * s, z) for r, z in CLAW_RZ], steps=8)
    claw = sweep('crown claw %d' % i, path, rounded_rect_section(2.6, 2.2, 0.5, 2), P['graphite'], smooth=35,
                 scale_fn=lambda t: (1.0 - 0.62 * t, 1.0 - 0.6 * t))
    # status strip along the claw's outer face, tapering with it
    rad = Vector((c, s, 0))
    strip = []
    for j, p in enumerate(path[2:-3]):
        k = j + 2
        tng = (path[min(k + 1, len(path) - 1)] - path[k - 1])
        tr, tz = tng.dot(rad), tng.z
        n = Vector((tz, -tr)); n.normalize()
        t = k / (len(path) - 1)
        off = 1.1 * (1.0 - 0.6 * t) + 0.04
        strip.append(p + rad * (n.x * off) + Vector((0, 0, n.y * off)))
    sweep('crown claw status strip %d' % i, strip, rounded_rect_section(0.62, 0.2, 0.08, 1), P['status'], smooth=35,
          scale_fn=lambda t: (1.0 - 0.5 * t, 1.0))
    end = path[-1]; tng = (path[-1] - path[-2]).normalized()
    tip_center = end + tng * 0.95
    q = Vector((0, 0, 1)).rotation_difference(tng).to_euler()
    crystal('crown claw emitter %d' % i, 2.2, 0.62, P['crystal'], seed=101 + i, sides=6,
            center=tuple(tip_center), rot=tuple(q))
    tips['claw_%d_deg' % round(math.degrees(a))] = [round(v, 3) for v in (end + tng * 1.9)]

bones = sync_rig()
scene['inducer_claw_tips'] = json.dumps(tips)
save('05 crown')
print('CROWN_OK tips=' + json.dumps(tips))
