"""The cyber Rampage Inducer's motion - ONE source for the live Blender preview
(drivers, design_lib.sync_rig) and the in-game xanims (install_native.py).

Pure Python (no bpy / mathutils) so the installer can import it under system
Python. Units: game units, degrees in the tables, radians in the maths.

Five animated bones under the static `tag_origin`:
  j_crystal  the Fury crystal          - turns slowly about the axis and bobs
  j_shards   the three orbiting shards - orbit the other way
  j_halo_lo  the low containment halo  - tilted 11 deg, precesses + spins in plane
  j_halo_hi  the high containment halo - tilted 9 deg, the opposite way round
  j_beacon   the beacon's shutter      - sweeps the beacon light like a lighthouse

Two looping clips at 30 fps, both seamless (the last frame equals the first):
  idle  12.0 s: the calm standby the device sits in all match
  on     3.0 s: Rampage armed - everything four times faster, the crystal bobs
                harder and shivers, the beacon sweeps like an alarm
The integer turns/cycles below are what make each clip loop without a seam.
"""
import math

FPS = 30
CLIPS = {'idle': 360, 'on': 90}          # frames per loop (12 s / 3 s)
# NOT 'tod_inducer_cyber_on': that is the lit xmodel twin's name - keep clips and models apart.
XANIM = {'idle': 'tod_inducer_cyber_loop_idle', 'on': 'tod_inducer_cyber_loop_on'}

# Rest pose: pivot (model space) and the bone's fixed tilt (degrees about X, Y).
BONES = {
    'j_crystal': dict(pivot=(0.0, 0.0, 35.6), tilt=(0.0, 0.0)),
    'j_shards':  dict(pivot=(0.0, 0.0, 36.5), tilt=(0.0, 0.0)),
    'j_halo_lo': dict(pivot=(0.0, 0.0, 31.2), tilt=(11.0, 0.0)),
    'j_halo_hi': dict(pivot=(0.0, 0.0, 40.4), tilt=(0.0, -9.0)),
    'j_beacon':  dict(pivot=(0.0, 0.0, 60.9), tilt=(0.0, 0.0)),
}
BONE_ORDER = ['tag_origin'] + list(BONES)

# Per clip and bone: whole turns of PRECESSION about the world axis (yaw), whole
# turns of SPIN about the bone's own (tilted) axis, bob amplitude + whole bob
# cycles, and an optional shiver (small fast wobble, whole cycles, degrees).
MOTION = {
    'idle': {
        'j_crystal': dict(yaw=1, spin=0, bob=0.55, bob_cycles=2, shiver=0.0, shiver_cycles=0),
        'j_shards':  dict(yaw=-2, spin=0, bob=0.35, bob_cycles=3, shiver=0.0, shiver_cycles=0),
        'j_halo_lo': dict(yaw=1, spin=2, bob=0.0, bob_cycles=0, shiver=0.0, shiver_cycles=0),
        'j_halo_hi': dict(yaw=-1, spin=-3, bob=0.0, bob_cycles=0, shiver=0.0, shiver_cycles=0),
        'j_beacon':  dict(yaw=2, spin=0, bob=0.0, bob_cycles=0, shiver=0.0, shiver_cycles=0),
    },
    'on': {
        'j_crystal': dict(yaw=1, spin=0, bob=1.05, bob_cycles=2, shiver=1.6, shiver_cycles=9),
        'j_shards':  dict(yaw=-2, spin=0, bob=0.6, bob_cycles=3, shiver=0.0, shiver_cycles=0),
        'j_halo_lo': dict(yaw=1, spin=2, bob=0.0, bob_cycles=0, shiver=0.0, shiver_cycles=0),
        'j_halo_hi': dict(yaw=-1, spin=-3, bob=0.0, bob_cycles=0, shiver=0.0, shiver_cycles=0),
        'j_beacon':  dict(yaw=4, spin=0, bob=0.0, bob_cycles=0, shiver=0.0, shiver_cycles=0),
    },
}


def _rx(a):
    c, s = math.cos(a), math.sin(a)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def _ry(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def _rz(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def tilt_matrix(bone):
    tx, ty = BONES[bone]['tilt']
    return mul(_rx(math.radians(tx)), _ry(math.radians(ty)))


def angles(bone, clip, frame):
    """(yaw, spin, bob, shiver) at a frame; every term is periodic over the clip."""
    n = CLIPS[clip]
    m = MOTION[clip][bone]
    t = (frame % n) / n
    yaw = math.tau * m['yaw'] * t
    spin = math.tau * m['spin'] * t
    bob = m['bob'] * math.sin(math.tau * m['bob_cycles'] * t) if m['bob_cycles'] else 0.0
    shiver = math.radians(m['shiver']) * math.sin(math.tau * m['shiver_cycles'] * t) if m['shiver_cycles'] else 0.0
    return yaw, spin, bob, shiver


def pose(bone, clip, frame):
    """Model-space (offset, 3x3 rotation) of a bone - columns are its axes.

    rotation = Rz(yaw) . Tilt . Rx(shiver) . Rz(spin): spin about the bone's own
    axis, then the fixed tilt, then precession about the world vertical."""
    yaw, spin, bob, shiver = angles(bone, clip, frame)
    rot = mul(_rz(yaw), mul(tilt_matrix(bone), mul(_rx(shiver), _rz(spin))))
    px, py, pz = BONES[bone]['pivot']
    return (px, py, pz + bob), rot


def rows(rot):
    """XANIM/XMODEL_EXPORT write each bone axis as a row (the exporter's
    `matrix.transposed()`): row i = column i of the rotation."""
    return [tuple(rot[r][c] for r in range(3)) for c in range(3)]


def summary():
    out = {}
    for clip, n in CLIPS.items():
        out[clip] = {'frames': n, 'seconds': n / FPS, 'xanim': XANIM[clip],
                     'bones': {b: dict(MOTION[clip][b]) for b in BONES}}
    return out
