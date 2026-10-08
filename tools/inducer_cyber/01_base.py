"""Stage 01 - the base: armoured plinth, floor light ring, sloped skirt with the
front RAMPAGE display, glowing side vents, corner anchor clamps.

Footprint: a 44 x 44 square with 7-unit chamfers (the clip brush in the map is
a box just inside it). Back face at x = -22, two units off the arena wall.
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
begin('01 base')

# ---- plinth: graphite plate split by the floor light ring, titanium deck band
sq = poly_chamfer_square
bevel(prism('plinth plate lower', sq(22, 22, 7), 0.0, 0.8, P['graphite']), 0.18, 1, 40)
bevel(prism('plinth floor light ring', sq(21.7, 21.7, 6.88), 0.8, 1.65, P['status']), 0.05, 1, 40)
bevel(prism('plinth plate upper', sq(22, 22, 7), 1.65, 2.7, P['graphite']), 0.32, 2, 40)
bevel(prism('plinth titanium deck band', sq(20.6, 20.6, 6.6), 2.7, 4.0, P['titanium']), 0.28, 2, 40)

# ---- the sloped skirt (loft) and its top lip
Z0, H0, C0 = 4.0, 19.2, 6.2
Z1, H1, C1 = 12.4, 14.2, 4.6
skirt = loft('skirt armour', [(Z0, sq(H0, H0, C0)), (Z1, sq(H1, H1, C1))], P['graphite'])
bevel(skirt, 0.32, 2, 30)
bevel(prism('skirt top lip', sq(14.7, 14.7, 4.85), 12.4, 13.3, P['titanium']), 0.22, 2, 40)
bevel(prism('skirt top deck', sq(13.9, 13.9, 4.5), 13.3, 13.7, P['carbon']), 0.12, 1, 40)


def face(side):
    """Bottom-centre, right, up-slope and outward normal of one skirt face."""
    dx, dz = H1 - H0, Z1 - Z0
    L = math.hypot(dx, dz)
    out = {'+X': Vector((1, 0, 0)), '-X': Vector((-1, 0, 0)), '+Y': Vector((0, 1, 0)), '-Y': Vector((0, -1, 0))}[side]
    right = Vector((0, 0, 1)).cross(out)               # viewer facing the face: right hand
    B = out * H0 + Vector((0, 0, Z0))
    U = (out * dx + Vector((0, 0, dz))) / L
    N = (out * dz - Vector((0, 0, dx))) / L
    N.normalize()
    return B, right, U, N, L


def on_face(side, ob, u, s, lift=0.0):
    B, R, U, N, L = face(side)
    origin = B + R * u + U * s + N * lift
    return apply_transform(place_on(ob, origin, R, N))


# ---- front display: bezel, dark glass, RAMPAGE in light, the five-step meter
B, R, U, N, L = face('+X')
bez = box('display bezel', (0, 0, 0.22), (15.6, 6.6, 0.44), P['titanium'])
on_face('+X', bez, 0, 4.75); bevel(bez, 0.14, 2, 40)
scr = box('display glass', (0, 0, 0.42), (14.0, 5.2, 0.08), P['glass'])
on_face('+X', scr, 0, 4.75)
word = text_mesh('display RAMPAGE', 'RAMPAGE', 1.62, P['letters'], (0, 0, 0.5), (0, 0, 0), extrude=0.035, spacing=1.18)
on_face('+X', word, 0, 5.55)
for i in range(5):
    bar = box('display meter bar %d' % (i + 1), (-5.2 + i * 2.6, 0, 0.49), (2.1, 0.62, 0.06),
              P['meter_lo'] if i < 2 else P['meter_hi'])
    on_face('+X', bar, 0, 3.15)
for sgn in (-1, 1):
    tick = box('display corner tick', (sgn * 6.35, 0, 0.49), (0.5, 3.9, 0.06), P['status'])
    on_face('+X', tick, 0, 4.75)
# hazard band under the display
hz = box('front hazard band', (0, 0, 0.18), (20.0, 1.25, 0.36), P['hazard'])
on_face('+X', hz, 0, 0.8); bevel(hz, 0.08, 1, 40)

# ---- side vents: four slots a side that breathe the core's light
for side in ('+Y', '-Y'):
    for k in range(4):
        s = 1.6 + k * 1.75
        slot = box('side vent slot %s %d' % (side, k), (0, 0, 0.12), (13.0 - k * 1.3, 0.95, 0.24), P['carbon'])
        on_face(side, slot, 0, s); bevel(slot, 0.08, 1, 40)
        glow = box('side vent glow %s %d' % (side, k), (0, 0, 0.255), (12.2 - k * 1.3, 0.34, 0.04), P['core'])
        on_face(side, glow, 0, s)
    plate = box('side service plate %s' % side, (0, 0, 0.16), (5.0, 1.6, 0.32), P['titanium'])
    on_face(side, plate, 0, 8.6); bevel(plate, 0.1, 1, 40)

# ---- back: junction housing the conduits drop into (cables arrive in stage 06)
jb = loft('rear junction housing', [(4.0, [(-21.6, -7.5), (-16.0, -7.5), (-16.0, 7.5), (-21.6, 7.5)]),
                                     (11.0, [(-21.0, -6.8), (-16.5, -6.8), (-16.5, 6.8), (-21.0, 6.8)])], P['graphite'])
bevel(jb, 0.3, 2, 30)
bevel(box('rear junction face plate', (-21.75, 0, 7.4), (0.5, 11.0, 4.6), P['titanium']), 0.1, 1, 40)

# ---- corner anchor clamps on the four chamfers
for i, a in enumerate(radial(4, 45)):
    c, s_ = math.cos(a), math.sin(a)
    rad = Vector((c, s_, 0)); tan = Vector((-s_, c, 0))

    def pt(r, t):
        p = rad * r + tan * t
        return (p.x, p.y)
    clamp = loft('anchor clamp %d' % i, [(0.0, [pt(16.8, -5.2), pt(25.4, -5.2), pt(25.4, 5.2), pt(16.8, 5.2)]),
                                         (3.2, [pt(16.8, -5.2), pt(25.4, -5.2), pt(25.4, 5.2), pt(16.8, 5.2)]),
                                         (6.6, [pt(16.8, -4.2), pt(20.6, -4.2), pt(20.6, 4.2), pt(16.8, 4.2)])], P['titanium'])
    bevel(clamp, 0.3, 2, 30)
    # bolts on the sloped outer face (normal tilts out and up)
    nrm = (rad * 3.4 + Vector((0, 0, 4.8))).normalized()
    for t in (-2.6, 2.6):
        p = rad * 23.15 + tan * t + Vector((0, 0, 4.85))
        hex_bolt('anchor clamp bolt %d' % i, p + nrm * 0.05, nrm, P['steel'], r=0.62, h=0.34)
    pip = box('anchor clamp status pip %d' % i, (0, 0, 0.1), (0.7, 1.9, 0.2), P['status'])
    apply_transform(place_on(pip, rad * 23.15 + Vector((0, 0, 4.79)), tan, nrm))

save('01 base')
print('BASE_OK')
