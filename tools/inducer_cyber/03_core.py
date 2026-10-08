"""Stage 03 - the heart: a levitating Fury crystal in a plasma column, three
orbiting shards and two tilted, SEGMENTED containment halos (segments make
their spin readable - a smooth ring turning looks still).

Animated bones (anim_spec): j_crystal, j_shards, j_halo_lo, j_halo_hi. The
crystal is opaque emissive (baked into the atlas); the plasma column is the
one transparent part (its own scrolling material in BO3, double-sided at export).
"""
import sys, importlib, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import design_lib as D
importlib.reload(D)
from design_lib import *
from mathutils import Vector

assert scene.get('mcp_port') == 9884
P = palette()
begin('03 core')

# every part bakes its object transform into the mesh before rigging, so its
# vertices are already model-space rest positions (what the xmodel stores)
rig_bone(apply_transform(crystal('fury crystal', 18.6, 3.7, P['crystal'], seed=7, sides=9, center=(0, 0, 35.6),
                                 rot=(0, 0, math.radians(8)))), 'j_crystal')
# the cluster: five spurs growing off the main crystal's waist, on the same bone
for i, (az, el, length, radius, z, seed) in enumerate(((20, 38, 8.6, 1.55, 33.4, 51), (98, 52, 6.8, 1.25, 37.6, 52),
                                                        (167, 33, 7.9, 1.45, 34.2, 53), (236, 47, 6.2, 1.15, 38.4, 54),
                                                        (305, 30, 7.4, 1.35, 32.8, 55))):
    a, e = math.radians(az), math.radians(el)
    d = Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e) * (1 if i % 2 == 0 else -0.55)))
    d.normalize()
    root = Vector((0, 0, z)) + Vector((math.cos(a), math.sin(a), 0)) * 1.2
    center = root + d * (length * 0.5 - 0.4)
    q = Vector((0, 0, 1)).rotation_difference(d).to_euler()
    rig_bone(apply_transform(crystal('fury crystal spur %d' % i, length, radius, P['crystal'], seed=seed, sides=7,
                                     center=tuple(center), rot=tuple(q))), 'j_crystal')

# orbiting shards (one bone): tilted outward, spaced round the axis
for i, (az, z, tilt, seed) in enumerate(((35, 30.8, 18, 11), (155, 37.6, -22, 23), (275, 41.4, 15, 37))):
    a = math.radians(az)
    sh = crystal('orbiting shard %d' % i, 4.4, 1.05, P['crystal'], seed=seed, sides=6,
                 center=(8.1 * math.cos(a), 8.1 * math.sin(a), z),
                 rot=(math.radians(tilt) * -math.sin(a), math.radians(tilt) * math.cos(a), a))
    apply_transform(sh)
    rig_bone(sh, 'j_shards')


def halo(tag, bone, R, r, segs, gap_deg, start_deg):
    z = A.BONES[bone]['pivot'][2]
    span = 360.0 / segs
    parts = []
    for k in range(segs):
        a0 = math.radians(start_deg + k * span + gap_deg / 2)
        a1 = math.radians(start_deg + (k + 1) * span - gap_deg / 2)
        parts.append(arc_tube('halo %s arc %d' % (tag, k), R, r, a0, a1, P['core'], z=z))
        g = math.radians(start_deg + k * span)            # node sits in the gap
        node = box('halo %s node %d' % (tag, k), (0, 0, 0), (1.15, 1.5, 0.95), P['titanium'])
        node.rotation_euler = (0, 0, g); node.location = (R * math.cos(g), R * math.sin(g), z)
        apply_transform(node); bevel(node, 0.12, 1, 40); parts.append(node)
        led = box('halo %s node led %d' % (tag, k), (0, 0, 0), (0.22, 0.8, 0.45), P['status'])
        led.rotation_euler = (0, 0, g)
        led.location = ((R + 0.62) * math.cos(g), (R + 0.62) * math.sin(g), z)
        apply_transform(led); parts.append(led)
    for ob in parts:
        tilt_about_pivot(ob, bone)
        rig_bone(ob, bone)


halo('low', 'j_halo_lo', 7.3, 0.24, 3, 26, 10)
halo('high', 'j_halo_hi', 6.75, 0.21, 4, 22, 35)

# the plasma column stays still; its texture scrolls (in game: the scroll shader)
tube_uv('plasma column', 5.6, 23.9, 47.0, P['plasma'], seg=40, rows=10)

bones = sync_rig()
save('03 core')
print('CORE_OK bones=' + ','.join(bones))
