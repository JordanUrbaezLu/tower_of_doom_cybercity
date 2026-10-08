"""THE HALL BECOMES THE CLOCK: the Warden Trials' effects.

User, 2026-10-01 ("Lets build 1 first. Highest quality"), section 1 of the
effects plan they signed: "When the hall seals, sparks stream up its walls in
that hall's own colour. In the frenzy ... they turn red, rise faster and
thicker, and a red light pulses through the whole hall like a heartbeat. ...
On the win, the wall sparks stop and the last ones rise and fade. Gold sparks
rain onto the Max Ammo spot, with a gold ring and a flash on the floor. ... For
his 10-second countdown, a big red ring tightens on his landing spot ... and a
red heartbeat light quickens as he gets closer."

Before this a trial's only effect was the purple gate wall (which was never
drawn - same-frame host, fixed in _tod_spire.gsc beside this) and the clock
lived only on the HUD gauge. Now the room is the clock:

  fx_trial_walls_<hue>   the seal: motes, sparks, a low haze and slow Keeper
                         runes rise up all four drum walls in THAT HALL'S light
                         colour (SP_HUE in gen_tower_map.js, read here - so the
                         sparks always match the hall), and a rush of sparks
                         races up every wall the moment it seals.
  fx_trial_walls_frenzy  the last third (Trial VII: all of it): the same walls
                         red, faster, thicker, with flickering embers and a
                         surge up every wall as it starts.
  fx_trial_frenzy_light  a red light at the hall's heart beating lub-dub.
  fx_trial_win(_light)   on the Max Ammo spot: a gold shower falling from
                         above for over a second, a gold ring on the floor, a
                         warm floor glow, gold motes rising, a gold flash.
  fx_king_countdown(_light)  the summit: a red ring that tightens from 280 to
                         110 units over the King's 10 s countdown (it stays on
                         the deck), an inner ring turning the other way, a red
                         fill, a hot core on his spot and embers rising - all
                         beating on a heartbeat that quickens as he comes, the
                         light beating with it.

WHERE THE WALLS ARE (v19.68l - THE FIRST CUT WAS INVISIBLE). v19.68i put the
sparks 436 out from the hall's centre, reading the trial_box edge (456) as the
drum's inner face. It is the drum's OUTER face: the drum is 20 thick OUTSIDE
the parapet line (SP_RM_OUT 436 - its inner face), with an 8-thick LINER on
the W / N / E faces (SP_RM_LINER, 428). Every spark was born inside the wall,
and the user's first trial (log 20261002_001756: WALLS_ON / FX_PLAYED on time,
seal, frenzy and win) showed nothing: "I dont see any changes visually". Now
SIX SEGMENTS sit WALL_INSET in front of the liner on the hall's real floor
(gen_tower_map.js SP_RM_FLOOR): two on the N wall, two on the E wall, one on
the W wall over the NW region (the W flight climbs in below SP_RM_NOTCH_Y),
one along the S strip (the S flight runs behind it, outside the seal). The
geometry is READ from gen_tower_map.js and the gate fails if a segment leaves
the floor or touches a wall.

ONE EFFECT PER SEGMENT, its line running along the host's LEFT axis: pitch -90
puts X up (the proven flat-effect frame) and leaves the left vector to the
yaw - yaw 0 = world Y, yaw 90 = world X - so every line is symmetric about its
host and no sign of any axis matters. Wall effects run in WORLD space
(runRelToWorld): when the hosts go at the win the last sparks rise and fade.

Built with the Archmage generator's element builder (stock Domination ring /
Origins soul mote / Keeper rune templates, the perk-glow light donor) - every
unit there is measured (gen_archmage_fx.py). --check is the build gate: the
effects regenerate byte-for-byte and the hall colours, precaches, effect keys,
zone lines and the trial / King hooks are in lockstep.
"""
import argparse
import math
from pathlib import Path
import re

import gen_archmage_fx as fxlib

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / 'share/raw/fx/tod/spire'
GEN_MAP = ROOT / 'tools/gen_tower_map.js'
GSC = ROOT / 'scripts/zm/zm_tower_of_doom/_tod_spire.gsc'
DATA = ROOT / 'scripts/zm/zm_tower_of_doom/_tod_spire_data.gsc'
ZONE = ROOT / 'zone_source/zm_tower_of_doom.zone'

SEG_HALF = 135.0             # each segment's half-length along its host's left axis
WALL_INSET = 24.0            # the sparks rise this far in front of the drum's liner
# ( x, y, yaw ) from the hall's centre, LOCKSTEP with _tod_spire.gsc trial_wall_segments();
# the gate re-derives every number from gen_tower_map.js (check_segments). Three
# segments tile the N and E walls end to end (-404..404); the W wall's floor is
# only the NW region (y 64..436), so one segment stands there (119..389); one
# runs the middle of the S strip.
WALL_SEGMENTS = [(-269, 404, 90), (0, 404, 90), (269, 404, 90),     # N wall
                 (404, -269, 0), (404, 0, 0), (404, 269, 0),        # E wall (the SE alcove included)
                 (-404, 254, 0),                                    # W wall, over the NW region
                 (0, -232, 90)]                                     # S strip (the S flight behind it)

FRENZY_RED = (1.0, 0.16, 0.10)
FRENZY_HOT = (1.0, 0.55, 0.30)
FRENZY_EMBER = (1.0, 0.35, 0.15)
GOLD = fxlib.GOLD
GOLD_HOT = (1.0, 0.92, 0.62)
KING_RED = (1.0, 0.14, 0.10)
KING_HOT = (1.0, 0.36, 0.22)
KING_FILL = (0.9, 0.08, 0.05)

KING_SECS = 10.0             # LOCKSTEP: _tod_spire.gsc TOD_KING_COUNTDOWN_SECS
KING_R0 = 280.0              # summit_king_org sits 304 from the deck's west edge: the ring stays on the deck
KING_R1 = 110.0
HEART_MS = 900               # the frenzy light's lub-dub

WALL_FLAGS = 'spawnRelative spawnOffsetNone runRelToWorld'
FALL_FLAGS = 'spawnRelative spawnOffsetCylinder runRelToWorld'


def hall_hues():
    """[(hall name, hue, rgb)] in hub order (hall 0 = floor 10), from the map generator."""
    js = GEN_MAP.read_text(encoding='utf-8')
    m = re.search(r'const SP_HUE = \{(.*?)\};', js, re.S)
    rgb = {k: tuple(float(x) for x in v.split()) for k, v in re.findall(r"(\w+):\s*'([\d. ]+)'", m.group(1))}
    lay = re.search(r'const SP_RM_LAYOUTS = \[(.*?)\n\];', js, re.S)
    order = re.findall(r"\{ name: '([^']+)',\s*hue: '(\w+)'", lay.group(1))
    if len(order) != 7 or any(h not in rgb for _, h in order):
        raise SystemExit('gen_tower_map.js SP_RM_LAYOUTS / SP_HUE changed shape: %s' % order)
    return [(name, hue, rgb[hue]) for name, hue in order]


def mix(c, d, f):
    return tuple(c[i] + (d[i] - c[i]) * f for i in range(3))


def line(h0, hr):
    """A random point on the segment's line (along Y), h0..h0+hr above the floor."""
    return (h0, -SEG_HALF, 0.0), (hr, 2.0 * SEG_HALF, 0.0)


FLICKER = [(0.0, 0.0), (0.08, 0.9), (0.18, 0.45), (0.28, 1.0), (0.4, 0.55), (0.52, 0.95),
           (0.66, 0.5), (0.8, 0.8), (1.0, 0.0)]


def wall_elements(T, tag, hue, spark, frenzy):
    """Everything that rises from ONE segment, calm or frenzied (v19.68l: bigger,
    brighter motes and a stronger haze - the user asked for the tower's visuals
    to be stronger, and these now have to read across a hall)."""
    e = fxlib.elem
    els = []
    if frenzy:
        mote = dict(width=11.0, life=(2800, 900), loop=60, vel=(95.0, 0.8, 1.25), grav=-6.0, peak=0.9)
        sp = dict(width=3.8, life=(1800, 500), loop=120, vel=(220.0, 0.8, 1.25), grav=-3.0)
        haze = dict(width=170.0, life=(2200, 500), loop=240, alpha=0.12)
        rune = dict(life=(3200, 600), loop=750, vel=(50.0, 0.85, 1.15), grav=-1.5)
        rush = dict(count=20, width=4.6, life=(1500, 500), vel=(400.0, 0.8, 1.05))
    else:
        mote = dict(width=10.0, life=(3600, 1200), loop=100, vel=(55.0, 0.8, 1.2), grav=-3.0, peak=0.85)
        sp = dict(width=3.4, life=(2200, 600), loop=220, vel=(130.0, 0.8, 1.2), grav=-2.0)
        haze = dict(width=160.0, life=(2600, 600), loop=360, alpha=0.09)
        rune = dict(life=(4200, 800), loop=1200, vel=(34.0, 0.85, 1.15), grav=-1.0)
        rush = dict(count=14, width=4.2, life=(1600, 500), vel=(300.0, 0.7, 1.0))
    o, rng = line(2.0, 30.0)
    els.append(e(T, 'walls_%s_motes' % tag, sprite='billboardSprite', material='gfx_light_phosphorous_em',
                 width=mote['width'], color=fxlib.flat(hue),
                 alpha=[(0.0, 0.0), (0.12, mote['peak']), (0.6, mote['peak'] * 0.73), (1.0, 0.0)],
                 size_rows=[(0.0, 0.4), (0.15, 1.0), (0.7, 0.8), (1.0, 0.3)],
                 life=mote['life'], loop_ms=mote['loop'], org=o, org_range=rng,
                 vel_x=mote['vel'], gravity=(mote['grav'], 0.0), near=(24.0, 56.0), flags=WALL_FLAGS, zfeather=4.0))
    els.append(e(T, 'walls_%s_sparks' % tag, sprite='billboardSprite', material='gfx_light_phosphorous_em',
                 width=sp['width'], color=fxlib.flat(spark),
                 alpha=[(0.0, 0.0), (0.08, 1.0), (0.5, 0.9), (1.0, 0.0)], size_rows=[(0.0, 1.0), (1.0, 0.35)],
                 life=sp['life'], loop_ms=sp['loop'], org=o, org_range=rng,
                 vel_x=sp['vel'], gravity=(sp['grav'], 0.0), near=(20.0, 48.0), flags=WALL_FLAGS, zfeather=4.0))
    o, rng = line(2.0, 60.0)
    els.append(e(T, 'walls_%s_haze' % tag, sprite='billboardSprite', material='gfx_light_bokeh_soft_em',
                 width=haze['width'], color=fxlib.flat(hue),
                 alpha=[(0.0, 0.0), (0.3, haze['alpha']), (0.7, haze['alpha'] * 0.8), (1.0, 0.0)],
                 size_rows=[(0.0, 0.7), (1.0, 1.1)], life=haze['life'], loop_ms=haze['loop'],
                 org=o, org_range=rng, vel_x=(14.0, 0.8, 1.2),
                 near=(80.0, 140.0), flags=WALL_FLAGS, zfeather=20.0))
    o, rng = line(4.0, 80.0)
    els.append(e(T, 'walls_%s_runes' % tag, sprite='billboardSprite', material='gfx_keeper_symbols_zod_em',
                 width=13.0, color=fxlib.flat(spark if frenzy else hue), atlas=True,
                 alpha=[(0.0, 0.0), (0.2, 0.7), (0.75, 0.6), (1.0, 0.0)],
                 size_rows=[(0.0, 0.7), (0.2, 1.0), (1.0, 0.9)],
                 life=rune['life'], loop_ms=rune['loop'], org=o, org_range=rng,
                 vel_x=rune['vel'], gravity=(rune['grav'], 0.0), rot_rate=15.0, near=(24.0, 56.0), flags=WALL_FLAGS))
    o, rng = line(2.0, 10.0)
    els.append(e(T, 'walls_%s_rush' % tag, sprite='billboardSprite', material='gfx_light_phosphorous_em',
                 looping=False, oneshot=rush['count'], width=rush['width'], color=fxlib.flat(spark),
                 alpha=[(0.0, 0.0), (0.05, 1.0), (0.6, 0.8), (1.0, 0.0)], size_rows=[(0.0, 1.0), (1.0, 0.3)],
                 life=rush['life'], org=o, org_range=rng,
                 vel_x=rush['vel'], gravity=(-1.0, 0.0), near=(20.0, 48.0), flags=WALL_FLAGS, zfeather=4.0))
    if frenzy:
        o, rng = line(2.0, 120.0)
        els.append(e(T, 'walls_%s_embers' % tag, sprite='billboardSprite', material='gfx_light_phosphorous_em',
                     width=1.8, color=fxlib.flat(FRENZY_EMBER), alpha=FLICKER,
                     size_rows=[(0.0, 1.0), (1.0, 0.5)], life=(2400, 800), loop_ms=100,
                     org=o, org_range=rng,
                     vel_x=(60.0, 0.6, 1.4), vel_y=(25.0, -1.0, 1.0), vel_z=(25.0, -1.0, 1.0),
                     gravity=(-4.0, 0.0), near=(20.0, 40.0), flags=WALL_FLAGS, zfeather=4.0))
    return els


def hall_walls(T, hue, frenzy):
    """ONE segment's effect; _tod_spire.gsc plays it on all six WALL_SEGMENTS."""
    spark = FRENZY_HOT if frenzy else mix(hue, (1.0, 1.0, 1.0), 0.45)
    colour = FRENZY_RED if frenzy else hue
    return fxlib.efx2(wall_elements(T, 'seg', colour, spark, frenzy))


def frenzy_light():
    # lub-dub: a strong beat, a softer echo, a rest - one light, replaced every beat
    rows = [(0, 0.15), (0.07, 1.0), (0.2, 0.32), (0.29, 0.72), (0.5, 0.18), (1, 0.15)]
    return fxlib.light_efx('trial_frenzy_light', looping=True, life=HEART_MS, loop_ms=HEART_MS, height=200,
                           radius=760, intensity_base=2200, intensity_rows=rows, color_rows=fxlib.flat(FRENZY_RED))


def win(T):
    e = fxlib.elem
    els = []
    # v19.68l (stronger): ten waves of sixteen, bigger flakes, and a pillar of
    # gold light standing on the mark while they fall.
    for k in range(10):   # the gold shower: ten waves 150 ms apart, falling from above
        rgb = GOLD_HOT if k % 2 else GOLD
        els.append(e(T, 'win_shower_%d' % k, sprite='billboardSprite', material='gfx_light_phosphorous_em',
                     looping=False, oneshot=16, delay=150 * k, width=3.8, color=fxlib.flat(rgb),
                     alpha=[(0.0, 0.0), (0.06, 1.0), (0.75, 0.9), (1.0, 0.0)], size_rows=[(0.0, 1.0), (1.0, 0.6)],
                     life=(1700, 300), cyl=((0.0, 150.0), (230.0, 80.0)),
                     vel_x=(60.0, -1.0, -0.4), vel_y=(30.0, -1.0, 1.0), vel_z=(30.0, -1.0, 1.0),
                     gravity=(18.0, 0.0), near=(20.0, 48.0), flags=FALL_FLAGS, zfeather=4.0))
    els.append(e(T, 'win_pillar', sprite='billboardSprite', material='gfx_light_bokeh_soft_em', looping=False,
                 oneshot=10, width=90.0, color=fxlib.flat(GOLD),
                 alpha=[(0.0, 0.0), (0.15, 0.28), (0.6, 0.2), (1.0, 0.0)], size_rows=[(0.0, 0.7), (1.0, 1.2)],
                 life=(1800, 400), cyl=((0.0, 30.0), (0.0, 320.0)), vel_x=(30.0, 0.7, 1.3),
                 near=(40.0, 90.0), flags=FALL_FLAGS, zfeather=20.0))
    for k in range(2):   # glitter: slow twinkling flakes
        els.append(e(T, 'win_glitter_%d' % k, sprite='billboardSprite', material='gfx_light_phosphorous_em',
                     looping=False, oneshot=10, delay=200 + 400 * k, width=1.6, color=fxlib.flat(GOLD_HOT),
                     alpha=FLICKER, size_rows=[(0.0, 1.0), (1.0, 0.7)], life=(2200, 400),
                     cyl=((0.0, 170.0), (200.0, 120.0)), vel_x=(20.0, -1.0, -0.3),
                     vel_y=(24.0, -1.0, 1.0), vel_z=(24.0, -1.0, 1.0), gravity=(8.0, 0.0),
                     near=(20.0, 40.0), flags=FALL_FLAGS))
    els.append(e(T, 'win_band', sprite='orientedSprite', material='gfx_ring_hvy_em', looping=False,
                 width=fxlib.BAND_W * 240.0, color=fxlib.flat(GOLD), size_rows=fxlib.EASE_OUT,
                 alpha=[(0.0, 0.0), (0.06, 0.7), (0.5, 0.4), (1.0, 0.0)], life=(700, 0), org=(2.0, 0.0, 0.0)))
    for k in range(6):
        els.append(e(T, 'win_ring_%d' % k, sprite='orientedSprite', material='gfx_ui_ring_thin', looping=False,
                     width=fxlib.RING_W * 260.0, color=fxlib.flat(GOLD_HOT), size_rows=fxlib.EASE_OUT,
                     alpha=[(0.0, 0.0), (0.05, 0.9), (0.5, 0.5), (1.0, 0.0)], life=(600, 0),
                     org=(2.4, 0.0, 0.0), rot0=(30.0 * k, 0.0)))
    els.append(e(T, 'win_floor', sprite='orientedSprite', material='gfx_light_bokeh_soft_em', looping=False,
                 width=fxlib.DISC_W * 120.0, color=fxlib.flat(GOLD), size_rows=[(0.0, 0.5), (0.3, 1.0), (1.0, 1.1)],
                 alpha=[(0.0, 0.0), (0.08, 0.35), (0.5, 0.22), (1.0, 0.0)], life=(1600, 0), org=(1.5, 0.0, 0.0)))
    els.append(e(T, 'win_rise', sprite='billboardSprite', material='gfx_light_phosphorous_em',
                 looping=False, oneshot=20, width=6.0, color=fxlib.flat(GOLD),
                 alpha=[(0.0, 0.0), (0.15, 0.8), (0.6, 0.6), (1.0, 0.0)], size_rows=[(0.0, 0.5), (0.2, 1.0), (1.0, 0.4)],
                 life=(2000, 500), cyl=((0.0, 80.0), (0.0, 20.0)), vel_x=(40.0, 0.7, 1.3),
                 gravity=(-2.0, 0.0), near=(24.0, 56.0), flags=FALL_FLAGS))
    return fxlib.efx2(els)


def win_light():
    return fxlib.light_efx('trial_win_light', looping=False, life=1100, loop_ms=1100, height=70, radius=420,
                           intensity_base=2600, intensity_rows=[(0, 0), (0.06, 1), (0.3, 0.6), (1, 0)],
                           color_rows=fxlib.flat(GOLD_HOT))


# ---- the King's countdown: a heartbeat that quickens --------------------------

def heartbeats(total=KING_SECS, first=0.35, start_iv=1.25, end_iv=0.38):
    beats, t = [], first
    while t < total - 0.2:
        beats.append(t)
        t += start_iv - (start_iv - end_iv) * (t / total)
    return beats


def beat_track(base0, base1, peak0, peak1, total=KING_SECS):
    """Alpha (or light) over the countdown: a rising floor, a sharp beat on every
    heartbeat, quicker and stronger as he comes; in at the start, out at the end."""
    beats = heartbeats(total)

    def lerp(a, b, t):
        return a + (b - a) * (t / total)
    rows = [(0.0, 0.0), (0.25, lerp(base0, base1, 0.25))]
    for i, b in enumerate(beats):
        nxt = beats[i + 1] if i + 1 < len(beats) else total - 0.05
        rise = 0.06
        fall = min(0.32, 0.5 * (nxt - b))
        if b <= rows[-1][0]:
            continue
        rows.append((b, lerp(base0, base1, b)))
        rows.append((b + rise, lerp(peak0, peak1, b)))
        rows.append((b + rise + fall, lerp(base0, base1, b + rise + fall)))
    rows.append((total - 0.15, lerp(base0, base1, total - 0.15)))
    rows.append((total, 0.0))
    out, last = [], -1.0
    for t, v in rows:
        if t > last + 1e-6:
            out.append((round(t / total, 6), v))
            last = t
    return out


def tighten(step=0.5):
    """The ring's radius over the countdown, normalised to the start: slow, then closing."""
    rows = []
    n = int(KING_SECS / step)
    for i in range(n + 1):
        t = i * step
        r = KING_R0 - (KING_R0 - KING_R1) * (t / KING_SECS) ** 1.6
        rows.append((t / KING_SECS, r / KING_R0))
    return rows


def king(T):
    e = fxlib.elem
    life = (int(KING_SECS * 1000), 0)
    size = tighten()
    els = []
    for k in range(6):
        els.append(e(T, 'king_ring_%d' % k, sprite='orientedSprite', material='gfx_ui_ring_thin', looping=False,
                     width=fxlib.RING_W * KING_R0, color=fxlib.flat(KING_RED), size_rows=size,
                     alpha=beat_track(0.40, 0.65, 0.80, 0.98), life=life, org=(3.0, 0.0, 0.0),
                     rot0=(30.0 * k, 0.0), spin=18.0))
    els.append(e(T, 'king_band', sprite='orientedSprite', material='gfx_ring_hvy_em', looping=False,
                 width=fxlib.BAND_W * KING_R0, color=fxlib.flat(KING_RED), size_rows=size,
                 alpha=beat_track(0.08, 0.16, 0.24, 0.34), life=life, org=(2.0, 0.0, 0.0)))
    for k in range(6):
        els.append(e(T, 'king_inner_%d' % k, sprite='orientedSprite', material='gfx_ui_ring_thin', looping=False,
                     width=fxlib.RING_W * KING_R0 * 0.62, color=fxlib.flat(KING_HOT), size_rows=size,
                     alpha=beat_track(0.30, 0.50, 0.60, 0.85), life=life, org=(3.2, 0.0, 0.0),
                     rot0=(30.0 * k + 15.0, 0.0), spin=-26.0))
    els.append(e(T, 'king_fill', sprite='orientedSprite', material='gfx_light_bokeh_soft_em', looping=False,
                 width=fxlib.DISC_W * KING_R0, color=fxlib.flat(KING_FILL), size_rows=size,
                 alpha=beat_track(0.03, 0.16, 0.10, 0.26), life=life, org=(1.5, 0.0, 0.0)))
    els.append(e(T, 'king_core', sprite='billboardSprite', material='gfx_light_bokeh_soft_em', looping=False,
                 width=120.0, color=fxlib.flat(KING_HOT), size_rows=[(0.0, 0.6), (1.0, 1.0)],
                 alpha=beat_track(0.12, 0.35, 0.30, 0.60), life=life, org=(34.0, 0.0, 0.0), near=(40.0, 80.0)))
    els.append(e(T, 'king_embers', sprite='billboardSprite', material='gfx_light_phosphorous_em',
                 width=3.0, color=[(0.0,) + KING_RED, (1.0,) + KING_HOT],
                 alpha=[(0.0, 0.0), (0.12, 0.9), (0.6, 0.7), (1.0, 0.0)], size_rows=[(0.0, 1.0), (1.0, 0.4)],
                 life=(1300, 400), loop_ms=45, cyl=((0.0, 140.0), (0.0, 8.0)), vel_x=(70.0, 0.7, 1.3),
                 gravity=(-5.0, 0.0), near=(20.0, 48.0), flags=FALL_FLAGS, zfeather=4.0))
    return fxlib.efx2(els)


def king_light():
    return fxlib.light_efx('king_countdown_light', looping=False, life=int(KING_SECS * 1000),
                           loop_ms=int(KING_SECS * 1000), height=40, radius=420, intensity_base=2000,
                           intensity_rows=beat_track(0.10, 0.45, 0.55, 1.0), color_rows=fxlib.flat(KING_RED))


def render(tools):
    T = fxlib.templates_from(tools)
    out = {}
    for _, hue, rgb in hall_hues():
        out['fx_trial_walls_' + hue] = hall_walls(T, rgb, False)
    out['fx_trial_walls_frenzy'] = hall_walls(T, None, True)
    out['fx_trial_frenzy_light'] = frenzy_light()
    out['fx_trial_win'] = win(T)
    out['fx_trial_win_light'] = win_light()
    out['fx_king_countdown'] = king(T)
    out['fx_king_countdown_light'] = king_light()
    return out


# ---- the gate ------------------------------------------------------------------

def js_num(js, name):
    m = re.search(r'^const (?:[^;\n]*?,\s*)?' + name + r'\s*=\s*([^,;\n]+)', js, re.M)
    if not m:
        raise SystemExit('gen_tower_map.js lost const ' + name)
    return m.group(1).split('//')[0].strip()


def check_segments():
    """Every segment stands on the hall's floor, WALL_INSET in front of the wall it
    lights - the numbers re-derived from gen_tower_map.js, not trusted."""
    js = GEN_MAP.read_text(encoding='utf-8')
    core = int(js_num(js, 'CORE'))
    px, para = int(js_num(js, 'PX')), int(js_num(js, 'PARA'))
    if js_num(js, 'SP_RM_OUT') != 'PX + PARA':
        raise SystemExit('SP_RM_OUT is no longer PX + PARA - re-read the drum')
    out = px + para                                   # 436: the drum's inner face
    m = re.search(r'const SP_RM_LINER = \{[^}]*\bt:\s*(\d+)', js)
    liner = out - int(m.group(1))                     # 428: the W / N / E faces, liner included
    notch = int(js_num(js, 'SP_RM_NOTCH_Y'))         # 64: the NW region starts here
    tread = int(js_num(js, 'TREAD'))
    face = liner - WALL_INSET                         # where the N / E / W lines stand
    for x, y, yaw in WALL_SEGMENTS:
        if yaw == 0:     # a line along y at x
            lo, hi = y - SEG_HALF, y + SEG_HALF
            if abs(abs(x) - face) > 0.5:
                raise SystemExit('segment %s: x must be +-%s (WALL_INSET in front of the liner %s)' % ((x, y, yaw), face, liner))
            if lo < -face - 0.5 or hi > face + 0.5:
                raise SystemExit('segment %s runs into a corner wall' % ((x, y, yaw),))
            if x < 0 and lo < notch - 24:
                raise SystemExit('segment %s hangs over the W flight (the NW region starts at y %s)' % ((x, y, yaw), notch))
        elif yaw == 90:  # a line along x at y
            lo, hi = x - SEG_HALF, x + SEG_HALF
            if y > 0:
                if abs(y - face) > 0.5:
                    raise SystemExit('segment %s: y must be %s (WALL_INSET in front of the N liner)' % ((x, y, yaw), face))
            elif not (-core <= y <= -core + tread):
                raise SystemExit('segment %s is off the S strip (y %s..%s)' % ((x, y, yaw), -core, -core + tread))
            elif lo < -core or hi > core:
                raise SystemExit('segment %s leaves the S strip (x +-%s)' % ((x, y, yaw), core))
            if lo < -face - 0.5 or hi > face + 0.5:
                raise SystemExit('segment %s runs into a corner wall' % ((x, y, yaw),))
        else:
            raise SystemExit('segment %s: yaw must be 0 or 90' % ((x, y, yaw),))


def body(src, name):
    m = re.search(r'\nfunction ' + name + r'\([^)]*\)[^\n]*\n\{(.*?)\n\}', src, re.S)
    if not m:
        raise SystemExit('_tod_spire.gsc lost function ' + name)
    return m.group(1)


def check_lockstep(stems):
    gsc = GSC.read_text(encoding='utf-8').replace('\r\n', '\n')
    data = DATA.read_text(encoding='utf-8').replace('\r\n', '\n')
    zone = ZONE.read_text(encoding='utf-8').replace('\r\n', '\n')
    # The hall colour the script picks is the hall's own (hub order = SP_RM_LAYOUTS order).
    m = re.search(r'function trial_fx_hues\(\)\s*\{\s*return array\(([^)]*)\);', gsc)
    script = [s.strip().strip('"') for s in m.group(1).split(',')] if m else []
    gen = [h for _, h, _ in hall_hues()]
    if script != gen:
        raise SystemExit('trial_fx_hues() %s != gen_tower_map.js SP_RM_LAYOUTS hues %s' % (script, gen))
    # WHERE THE SPARKS STAND (v19.68l): the script's segments are these, and these
    # are on the hall's floor, in front of its walls - read from the generator.
    m = re.search(r'function trial_wall_segments\(\)\s*\{\s*return array\((.*?)\);', gsc, re.S)
    script = [tuple(int(v) for v in t.split(',')) for t in re.findall(r'\(\s*(-?\d+\s*,\s*-?\d+\s*,\s*-?\d+)\s*\)', m.group(1))] if m else []
    if script != [tuple(s) for s in WALL_SEGMENTS]:
        raise SystemExit('trial_wall_segments() %s != gen_trial_fx.py WALL_SEGMENTS %s' % (script, WALL_SEGMENTS))
    check_segments()
    m = re.search(r'#define TOD_KING_COUNTDOWN_SECS\s+(\d+)', gsc)
    if not m or float(m.group(1)) != KING_SECS:
        raise SystemExit('TOD_KING_COUNTDOWN_SECS != the countdown effect (%s s)' % KING_SECS)
    for stem in stems:
        fx = 'tod/spire/' + stem
        key = 'tod_' + stem[3:]
        if ('#precache( "fx", "%s" );' % fx) not in gsc:
            raise SystemExit('missing #precache for ' + fx)
        if ('\nfx,%s\n' % fx) not in zone:
            raise SystemExit('missing zone line fx,' + fx)
        if not stem.startswith('fx_trial_walls_') or stem == 'fx_trial_walls_frenzy':
            if ('level._effect[ "%s" ] = "%s";' % (key, fx)) not in gsc:
                raise SystemExit('_tod_spire.gsc must register level._effect["%s"]' % key)
    if 'level._effect[ "tod_trial_walls_" + hue ] = "tod/spire/fx_trial_walls_" + hue;' not in gsc:
        raise SystemExit('_tod_spire.gsc must register every hall colour from trial_fx_hues()')
    # The hooks: the seal starts the walls, the frenzy swaps them, the win stops them
    # and showers the mark, the King's countdown draws his ring.
    run = body(gsc, 'trial_run')
    for need in ('trial_fx_start( hub, z,', 'trial_fx_frenzy( hub, z );'):
        if need not in run:
            raise SystemExit('trial_run must call ' + need)
    won = body(gsc, 'trial_win')
    for need in ('trial_fx_stop( "win" );', 'level thread trial_fx_win( mark );'):
        if need not in won:
            raise SystemExit('trial_win must call ' + need)
    if 'level thread king_countdown_fx( TOD_KING_COUNTDOWN_SECS );' not in body(gsc, 'king_run'):
        raise SystemExit('king_run must thread king_countdown_fx for the countdown')
    # THE SAME-FRAME RULE: no effect is played on a host in the frame it was made.
    for fn in ('trial_barrier_up', 'king_barrier_up', 'trial_fx_start', 'trial_fx_win', 'king_countdown_fx', 'fx_host_up'):
        if re.search(r'PlayF[Xx]OnTag\(', body(gsc, fn)):
            raise SystemExit(fn + ' plays an effect on a host it just made - hand it to fx_play_on_new_host')
    late = body(gsc, 'fx_play_on_new_host')
    if late.count('WAIT_SERVER_FRAME;') < 2 or late.index('WAIT_SERVER_FRAME;') > late.index('PlayFXOnTag('):
        raise SystemExit('fx_play_on_new_host must wait two server frames before PlayFXOnTag')
    barrier = body(gsc, 'barrier_fx_late')
    if barrier.count('WAIT_SERVER_FRAME;') < 2 or barrier.index('WAIT_SERVER_FRAME;') > barrier.index('PlayFxOnTag('):
        raise SystemExit('barrier_fx_late must wait two server frames before PlayFxOnTag')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--tools', type=Path, default=fxlib.DEFAULT_TOOLS)
    args = parser.parse_args()
    expected = render(args.tools)
    bad = []
    for stem, text in expected.items():
        target = OUT_DIR / (stem + '.efx')
        if args.check:
            if not target.exists() or target.read_text(encoding='utf-8') != text:
                bad.append(target.name)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text, encoding='utf-8', newline='\n')
            n = text.count('\n{\n') + (1 if text.startswith('{') else 0)
            print(f'Wrote {target.relative_to(ROOT)} ({len(text)} bytes, {n} elements)')
    if args.check:
        if bad:
            raise SystemExit('Trial FX differ (' + ', '.join(bad) + '); run tools/gen_trial_fx.py')
        check_lockstep(list(expected))
        print('Trial FX verified: %d effects (7 hall colours from SP_HUE, frenzy + heartbeat light, win shower + light, '
              'King countdown + light); hues, the 8 wall segments on the hall floor, countdown, precache/effect keys/zone and the seal/frenzy/win/King '
              'hooks in lockstep; no effect on a same-frame host.' % len(expected))


if __name__ == '__main__':
    main()
