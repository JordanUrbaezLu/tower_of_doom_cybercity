"""ARCHMAGE, ON THE WORLD: the Mage's ultimate form gets a body.

User, 2026-10-01: "Lets start with archmage. High quality viusals". Before this
the form was invisible to everyone but the Mage: the mana bar turns gold and a
local sound plays, so a teammate saw an ordinary Mage. The form already paints
every health bar of the Archmage in the health bar's RAINBOW (TodHealthTint.lua);
this carries that identity into the world as PRISMATIC LIGHT: a white-gold core,
a rainbow fringe.

THE PIECES (all played CLIENT-side by _tod_mage_elements.csc on the player's
`tod_arch_form` clientfield, so they follow the Mage with no server lag, and
KillFX takes every particle the instant the form ends - a server host's
long-lived particles would linger where the form ended):

  fx_archmage_circle   the ground circle, on a host turning slowly one way:
                       a crisp rainbow ring (six bracket arcs, one per health-bar
                       colour - a turning colour wheel), a breathing white-gold
                       glow band under it, eight gold KEEPER RUNES (Shadows of
                       Evil's own glyph atlas) that rewrite themselves one after
                       another, a soft floor glow, rainbow sparkles on the rim.
  fx_archmage_inner    a gold inner ring on its own host turning the OTHER way.
  fx_archmage_column   (teammates' view) rainbow motes spiralling up the body -
                       red at the feet to violet over the head, a vertical prism;
                       white-gold sparks, rising gold runes, a faint radiance.
  fx_archmage_column_1p  (own view) only low motes from the ring's edge, gone
                       below eye height: nothing rises across the crosshair.
  fx_archmage_light(_1p) a dynamic light cycling the health bar's rainbow on the
                       floor around the Mage (dimmer and lower in the own view).
  fx_archmage_rise(_1p)  ONE-SHOT at the feet when the form starts: a white
                       shockwave that disperses into concentric rainbow bands,
                       a rainbow fountain and scattered runes (own view: flat
                       rings and low runes only).
  fx_archmage_rise_light ONE-SHOT white-gold flash light (teammates' view only).
  fx_archmage_fade       ONE-SHOT when the form runs out: the rings implode,
                       gold sparks fall.

THE SPIN IS THE HOSTS', NOT THE PARTICLES'. Every sustained element runs relative
to its effect (runRelToEffect) on a client script_model that faces UP (pitch -90:
flat sprites lie on the floor - memory flat-ground-fx-rules) and whose yaw the CSC
turns every frame. So the particles carry NO rotation of their own (rotGraph 0):
a long-lived sprite that rotated by itself would jump back at each respawn, and
the column's motes spiral simply because their host turns under them.

NO SEAMS: a long-lived sprite is replaced on a fixed interval and lives XF ms
longer than it, fading out while its replacement fades in on the same spot - same
colour, same angle - so there is no one-frame blink at the handover (stock
Domination does interval == life; the light doc warns a gap goes black).

MEASURED, NOT GUESSED (texture_assets/black_ops_3/gfx, 256x256):
  i_gfx_ui_vtol_beam_ring_brackets (gfx_ui_ring_thin): two bracket arcs, line at
    0.945 of the half-width -> width 2.12 x radius; six copies 30 deg apart = an
    even circle (the Healing Aura's rim).
  fxt_distort_ring_hvy (gfx_ring_hvy_em): one full soft ring, alpha 255 from 0.53
    to 0.75 of the half-width, half alpha at 0.45 / 0.84 -> centre 0.64 -> width
    3.125 x radius.
  fxt_keeper_symbols_zod (gfx_keeper_symbols_zod_em): a 4x4 atlas of Keeper runes;
    stock plays it with startRandom over 16 entries (castle keeper ghost).
  Units (iwfx 2): sizes are the FULL width; velocity is units/second (stock smoke
    whisps 5, souls rays 0.25); gravity is % of world gravity, negative rises in
    world space; rotGraph is rad/ms (stock 0.001745 = 100 deg/s) - zeroed here.
  fadeOutRange (base, range) is the NEAR-camera fade (stock near-death 3p: 15 65):
    used on everything that rises, so no sprite ever sits on a close camera.

Templates are STOCK sources: oriented sprite = ui/fx_dom_cap_indicator_team.efx
element 0, billboard = dlc5/zmb_weapon/fx_staff_charge_souls.efx element 1 (the
luck soul / heal mote the user has seen render), light = the map's own perk-glow
donor share/raw/fx/acc/light/fx_perk_glow_amber.efx (iwfx 3 - lights exist only
in that format; the Rampage Inducer's approved light came from it). Every
material is in black_ops_3_fx.gdt or already linked in this map's .ff.

--check is the build gate: the effects regenerate byte-for-byte, and the
clientfield, precaches, effect registrations and zone lines are in lockstep.
"""
import argparse
import math
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_TOOLS = Path('C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130')
OUT_DIR = ROOT / 'share/raw/fx/tod/mage'
LIGHT_DONOR = ROOT / 'share/raw/fx/acc/light/fx_perk_glow_amber.efx'
GSC = ROOT / 'scripts/zm/zm_tower_of_doom/_tod_mage_elements.gsc'
CSC = ROOT / 'scripts/zm/zm_tower_of_doom/_tod_mage_elements.csc'
ZONE = ROOT / 'zone_source/zm_tower_of_doom.zone'
TINT_LUA = ROOT / 'ui/uieditor/widgets/HUD/AetheriumWidgets/TodHealthTint.lua'

# LOCKSTEP: TodHealthTint.lua COLORS, same order (red, orange, yellow, green, blue, violet).
RAINBOW = [(1.0, 0.15, 0.2), (1.0, 0.65, 0.05), (0.9, 1.0, 0.15),
           (0.15, 1.0, 0.3), (0.15, 0.65, 1.0), (0.75, 0.2, 1.0)]
GOLD = (1.0, 0.784314, 0.274510)    # the Origins soul core's gold (the luck orbs')
WHITE_GOLD = (1.0, 0.90, 0.64)

RING_W = 2.12        # gfx_ui_ring_thin: width per unit of radius
BAND_W = 3.125       # gfx_ring_hvy_em: width per unit of radius (band centre)
DISC_W = 2.12        # gfx_light_bokeh_soft_em: soft edge at the radius
OUTER_R = 44.0       # the rainbow ring, a little wider than the body
GLOW_R = 46.0
RUNE_R = 34.0        # between the rings
INNER_R = 24.0
DISC_R = 40.0
RUNES = 8

XF = 120             # ms a long-lived sprite overlaps its replacement
L_RING = 2000        # replacement interval of the rings / disc / radiance
L_GLOW = 2400        # one breath of the glow band
L_RUNE = 2400        # each rune rewrites itself every 2.4 s, one after another
XF_RUNE = 320        # the glyph morph
L_LIGHT = 3240       # the light's rainbow: 3 x the health bar's 1.08 s cycle

LIGHT_3P = dict(intensity=900, radius=150, height=30)
LIGHT_1P = dict(intensity=400, radius=140, height=8)

FX = {   # file stem -> what it is; the CSC registers level._effect["tod_arch_<key>"]
    'circle': 'fx_archmage_circle',
    'inner': 'fx_archmage_inner',
    'column': 'fx_archmage_column',
    'column_1p': 'fx_archmage_column_1p',
    'light': 'fx_archmage_light',
    'light_1p': 'fx_archmage_light_1p',
    'rise': 'fx_archmage_rise',
    'rise_1p': 'fx_archmage_rise_1p',
    'rise_light': 'fx_archmage_rise_light',
    'fade': 'fx_archmage_fade',
}


# ---- the .efx text ---------------------------------------------------------

def blocks(path):
    return re.split(r'\n\{\n', path.read_text(encoding='utf-8'))[1:]


def one(pattern, repl, text, flags=0):
    out, n = re.subn(pattern, repl, text, count=1, flags=flags)
    if n != 1:
        raise ValueError('template changed: no match for ' + pattern)
    return out


def field(text, name, value):
    return one(r'\t' + name + r' [^\n]*;', lambda m: '\t' + name + ' ' + value + ';', text)


def num(v):
    return '%.6f' % v


def pair(a, b=0.0):
    return num(a) + ' ' + num(b)


def graph(text, name, scale, rows, hi_rows=None):
    def body(rs):
        return ''.join('\t\t\t' + ' '.join(num(v) for v in row) + '\n' for row in rs)
    lo = body(rows)
    hi = body(hi_rows if hi_rows is not None else rows)
    block = '\t%s %s\n\t{\n\t\t{\n%s\t\t}\n\t\t{\n%s\t\t}\n\t};' % (name, num(scale), lo, hi)
    return one(r'\t' + name + r' [^\n]*\n\t\{.*?\n\t\};', lambda m: block, text, re.S)


def flat(rgb):
    return [(0.0,) + tuple(rgb), (1.0,) + tuple(rgb)]


def crossfade(alpha, life, xf):
    """Alpha for a sprite replaced every (life - xf) ms: in over xf, out over xf."""
    a = xf / float(life)
    return [(0.0, 0.0), (a, alpha), (1.0 - a, alpha), (1.0, 0.0)]


def breathing(lo, hi, period, xf, step=100):
    """A slow breath that survives the handover: the value is a function of the
    particle's AGE with period `period`, weighted by the crossfade, so the old and
    the new sprite always sum to the same breath."""
    life = period + xf
    ages = sorted(set(list(range(0, life + 1, step)) + [xf, period, life]))
    rows = []
    for a in ages:
        w = min(1.0, a / float(xf), (life - a) / float(xf))
        v = lo + (hi - lo) * 0.5 * (1.0 - math.cos(2.0 * math.pi * a / period))
        rows.append((a / float(life), max(0.0, w) * v))
    return rows


def rainbow_over(frac_end=1.0):
    """Red at birth -> violet at frac_end of the life (a vertical prism for a mote
    that rises)."""
    n = len(RAINBOW) - 1
    rows = [(frac_end * i / n,) + RAINBOW[i] for i in range(n + 1)]
    if frac_end < 1.0:
        rows.append((1.0,) + RAINBOW[-1])
    return rows


def rainbow_cycle(period, life):
    """The full rainbow every `period` ms of AGE, continued past the period for the
    crossfade, so old and new particle show the same colour at the handover."""
    n = len(RAINBOW)
    seg = period / float(n)

    def at(age):
        k = (age % period) / seg
        i = int(k) % n
        f = k - int(k)
        c0, c1 = RAINBOW[i], RAINBOW[(i + 1) % n]
        return tuple(c0[j] + (c1[j] - c0[j]) * f for j in range(3))
    ages = sorted(set([int(round(seg * i)) for i in range(n + 1)] + [life]))
    return [(a / float(life),) + at(a) for a in ages]


EASE_OUT = [(0.0, 0.08), (0.12, 0.45), (0.3, 0.72), (0.55, 0.9), (1.0, 1.0)]


def elem(templates, name, *, sprite, material, width, color, alpha,
         size_rows=((0.0, 1.0), (1.0, 1.0)), looping=True, life=(1000, 0),
         loop_ms=1000, oneshot=1, delay=0, org=(0.0, 0.0, 0.0), cyl=None,
         flags='spawnRelative spawnOffsetNone runRelToEffect',
         spawn_range=(0.0, 5000.0), fade_in=(4000.0, 1000.0), near=(0.0, 0.0),
         rot0=(0.0, 0.0), rot_rate=None, gravity=(0.0, 0.0), atlas=False,
         vel_x=None, vel_y=None, vel_z=None, zfeather=0.0, color_hi=None,
         org_range=(0.0, 0.0, 0.0), spin=None):
    t = templates[sprite]
    t = one(r'name "[^"]+";', 'name "%s";' % name, t)
    if not looping:
        t = one(r'(\teditorFlags )looping ', r'\1', t)
    t = field(t, 'flags', flags)
    t = one(r'\textraFlags[^\n]*;', lambda m: '\textraFlags;', t)   # no teamFriendly: ZM
    t = field(t, 'spawnRange', pair(*spawn_range))
    t = field(t, 'fadeInRange', pair(*fade_in))
    t = field(t, 'fadeOutRange', pair(*near))
    t = field(t, 'spawnLooping', '%d 0' % loop_ms)
    t = field(t, 'spawnLoopingSpawnCount', '1 0')
    t = field(t, 'spawnOneShot', '%d 0' % oneshot)
    t = field(t, 'spawnDelayMsec', '%d 0' % delay)
    t = field(t, 'lifeSpanMsec', '%d %d' % life)
    t = field(t, 'spawnOrgX', pair(org[0], org_range[0]))      # X = the host's forward = world UP
    t = field(t, 'spawnOrgY', pair(org[1], org_range[1]))      # (base, range): a random point in a box
    t = field(t, 'spawnOrgZ', pair(org[2], org_range[2]))
    if cyl:
        (r0, rr), (h0, hr) = cyl
        t = field(t, 'spawnOffsetRadius', pair(r0, rr))
        t = field(t, 'spawnOffsetHeight', pair(h0, hr))
    else:
        t = field(t, 'spawnOffsetRadius', pair(0.0))
        t = field(t, 'spawnOffsetHeight', pair(0.0))
    t = field(t, 'spawnOffsetCylindricalAxis', num(0.0))   # around the host's forward = up
    t = field(t, 'initialRot', pair(*rot0))
    t = field(t, 'gravity', pair(*gravity))
    if atlas:   # the Keeper runes, as stock plays them (castle keeper ghost)
        t = field(t, 'atlasBehavior', 'startRandom loopOnlyNTimes lerpFrames')
        t = field(t, 'atlasIndex', '0')
        t = field(t, 'atlasFps', '0')
        t = field(t, 'atlasLoopCount', '1')
        t = field(t, 'atlasColIndexBits', '2')
        t = field(t, 'atlasRowIndexBits', '2')
        t = field(t, 'atlasEntryCount', '16')
        t = field(t, 'atlasIndexRange', '0')
    zero = [(0.0, 0.0), (1.0, 0.0)]
    for key, v in (('velGraph0X', vel_x), ('velGraph0Y', vel_y), ('velGraph0Z', vel_z)):
        if v is None:
            t = graph(t, key, 0.0, zero)
        else:   # (scale, lo, hi): a constant velocity, random between lo and hi
            scale, lo, hi = v
            t = graph(t, key, scale, [(0.0, lo), (1.0, lo)], [(0.0, hi), (1.0, hi)])
    for key in ('velGraph1X', 'velGraph1Y', 'velGraph1Z'):
        t = graph(t, key, 0.0, zero)
    if spin is not None:   # deg/s, one fixed rate and direction (rad/ms in the file)
        s = abs(spin) * math.pi / 180.0 / 1000.0
        d = 1.0 if spin >= 0 else -1.0
        t = graph(t, 'rotGraph', s, [(0.0, d), (1.0, d)])
    elif rot_rate is None:
        t = graph(t, 'rotGraph', 0.0, zero)
    else:   # deg/s, random between -rot_rate and +rot_rate (rad/ms in the file)
        s = rot_rate * math.pi / 180.0 / 1000.0
        t = graph(t, 'rotGraph', s, [(0.0, -1.0), (1.0, -1.0)], [(0.0, 1.0), (1.0, 1.0)])
    t = graph(t, 'sizeGraph0', width, list(size_rows))
    t = graph(t, 'sizeGraph1', width, list(size_rows))
    t = graph(t, 'colorGraph', 1.0, color, color_hi)
    t = graph(t, 'alphaGraph', 1.0, alpha)
    t = field(t, 'zFeather', num(zfeather))
    t = one(r'(orientedSprite|billboardSprite)\n\t\{\n\t\t"[^"]+"\n\t\};',
            lambda m: '%s\n\t{\n\t\t"%s"\n\t};' % (m.group(1), material), t)
    return t


def efx2(els):
    return 'iwfx 2\n\n' + '\n'.join('{\n' + e.rstrip() + '\n' for e in els)


# ---- the light (iwfx 3, the perk-glow donor's light_small) ----------------------

def light_graph(block, key, base, rows):
    start = block.find('\n\t' + key + ' ')
    if start < 0:
        raise ValueError('light donor lost ' + key)
    end = block.index(';', start)
    body = '\t\t{\n' + ''.join('\t\t\t' + ' '.join('%g' % round(v, 6) for v in r) + '\n' for r in rows) + '\t\t}\n'
    return block[:start] + '\n\t%s %g\n\t{\n' % (key, base) + body + body + '\t}' + block[end:]


def light_field(block, key, value):
    out, n = re.subn(r'\n\t' + key + r' [^;\n]*;', '\n\t%s %s;' % (key, value), block, count=1)
    if n != 1:
        raise ValueError('light donor lost ' + key)
    return out


def light_efx(name, *, looping, life, loop_ms, height, radius, intensity_base, intensity_rows, color_rows):
    text = LIGHT_DONOR.read_text(encoding='utf-8')
    head, *rest = re.split(r'\n\{\n\tname "', text)
    els = ['\n{\n\tname "' + r for r in rest]
    lights = [e for e in els if e.split('"')[1] == 'light_small']
    if len(lights) != 1 or 'dynamicLight2' not in lights[0] or 'PRIMARY_NOSHADOWMAP 1' not in lights[0] \
            or 'shadowUpdate Never' not in lights[0]:
        raise ValueError('light donor changed shape (light_small, dynamicLight2, no shadow map)')
    b = lights[0]
    b = b.replace('name "light_small"', 'name "%s"' % name, 1)
    flags = 'useRandSize0 useRandIntensity useRandVel0 absVel1'
    b = light_field(b, 'editorFlags', ('looping ' + flags) if looping else flags)
    b = light_field(b, 'flags', 'spawnRelative spawnOffsetNone runRelToEffect')   # never frustum-culled
    b = light_field(b, 'spawnLooping', '%d 0' % loop_ms)
    b = light_field(b, 'spawnLoopingSpawnCount', '1 0')
    b = light_field(b, 'spawnOneShot', '1 0')
    b = light_field(b, 'lifeSpanMsec', '%d 0' % life)
    b = light_field(b, 'spawnOrgX', '%d 0' % height)    # the host faces UP: X is height
    b = light_field(b, 'spawnOrgY', '0 0')
    b = light_field(b, 'spawnOrgZ', '0 0')
    b = light_field(b, 'spawnOffsetRadius', '0 0')
    b = light_graph(b, 'colorGraph', 1, color_rows)
    b = light_graph(b, 'alphaGraph', 1, [(0, 1), (1, 1)])
    b = light_graph(b, 'lightIntensityGraph', intensity_base, intensity_rows)
    b = light_graph(b, 'lightRadiusGraph', radius, [(0, 1), (1, 1)])
    reach = radius + 20
    head = one(r'efBoundingBoxMin [^;]*;', 'efBoundingBoxMin -40 -%d -%d;' % (reach, reach), head)
    head = one(r'efBoundingBoxMax [^;]*;', 'efBoundingBoxMax %d %d %d;' % (height + reach, reach, reach), head)
    return head.rstrip('\n') + b.rstrip('\n') + '\n'


# ---- the effects -------------------------------------------------------------

def templates_from(tools):
    ring = blocks(tools / 'share/raw/fx/ui/fx_dom_cap_indicator_team.efx')
    souls = blocks(tools / 'share/raw/fx/dlc5/zmb_weapon/fx_staff_charge_souls.efx')
    if len(ring) != 2 or len(souls) != 6:
        raise ValueError('stock template files changed shape')
    t = {'orientedSprite': ring[0], 'billboardSprite': souls[1]}
    for kind, need in (('orientedSprite', '"gfx_ui_ring_thin"'), ('billboardSprite', '"gfx_light_phosphorous_em"')):
        if need not in t[kind] or 'editorFlags looping' not in t[kind]:
            raise ValueError('template lost ' + need)
        for empty in ('fxOnImpact "";', 'fxOnDeath "";', 'emission "";'):
            if empty not in t[kind]:
                raise ValueError('a template spawns a child effect: ' + empty)
    return t


def circle(T):
    els = []
    life = L_RING + XF
    for k, rgb in enumerate(RAINBOW):   # the colour wheel: each bracket pair one health-bar colour
        els.append(elem(T, 'arch_ring_%d' % k, sprite='orientedSprite', material='gfx_ui_ring_thin',
                        width=RING_W * OUTER_R, color=flat(rgb), alpha=crossfade(0.92, life, XF),
                        life=(life, 0), loop_ms=L_RING, delay=55 * k, org=(3.0, 0.0, 0.0),
                        rot0=(30.0 * k, 0.0)))
    glife = L_GLOW + XF
    els.append(elem(T, 'arch_glow', sprite='orientedSprite', material='gfx_ring_hvy_em',
                    width=BAND_W * GLOW_R, color=flat(WHITE_GOLD), alpha=breathing(0.13, 0.24, L_GLOW, XF),
                    life=(glife, 0), loop_ms=L_GLOW, org=(2.0, 0.0, 0.0)))
    rlife = L_RUNE + XF_RUNE
    for j in range(RUNES):              # eight Keeper runes, rewriting one after another
        a = 360.0 * j / RUNES
        y, z = RUNE_R * math.cos(math.radians(a)), RUNE_R * math.sin(math.radians(a))
        els.append(elem(T, 'arch_rune_%d' % j, sprite='orientedSprite', material='gfx_keeper_symbols_zod_em',
                        width=12.0, color=flat(GOLD), alpha=crossfade(0.95, rlife, XF_RUNE),
                        life=(rlife, 0), loop_ms=L_RUNE, delay=int(L_RUNE * j / RUNES),
                        org=(3.4, y, z), rot0=(a + 90.0, 0.0), atlas=True))
    els.append(elem(T, 'arch_floor', sprite='orientedSprite', material='gfx_light_bokeh_soft_em',
                    width=DISC_W * DISC_R, color=flat(WHITE_GOLD), alpha=crossfade(0.10, life, XF),
                    life=(life, 0), loop_ms=L_RING, org=(1.5, 0.0, 0.0)))
    for k, rgb in enumerate(RAINBOW):   # sparkles riding the rim
        els.append(elem(T, 'arch_sparkle_%d' % k, sprite='billboardSprite', material='gfx_light_phosphorous_em',
                        width=3.2, color=flat(rgb), alpha=[(0.0, 0.0), (0.2, 1.0), (1.0, 0.0)],
                        size_rows=[(0.0, 0.4), (0.25, 1.0), (1.0, 0.0)],
                        life=(520, 220), loop_ms=170, delay=28 * k, org=(2.0, 0.0, 0.0),
                        cyl=((OUTER_R, 0.0), (0.0, 3.0)), gravity=(-2.5, 0.0), near=(16.0, 40.0),
                        flags='spawnRelative spawnOffsetCylinder runRelToEffect spawnFrustumCull', zfeather=4.0))
    return efx2(els)


def inner(T):
    els = []
    life = L_RING + XF
    for k in range(6):
        els.append(elem(T, 'arch_inner_%d' % k, sprite='orientedSprite', material='gfx_ui_ring_thin',
                        width=RING_W * INNER_R, color=flat(GOLD), alpha=crossfade(0.80, life, XF),
                        life=(life, 0), loop_ms=L_RING, delay=55 * k, org=(3.2, 0.0, 0.0),
                        rot0=(30.0 * k + 15.0, 0.0)))
    els.append(elem(T, 'arch_inner_glow', sprite='orientedSprite', material='gfx_ring_hvy_em',
                    width=BAND_W * INNER_R, color=flat(GOLD), alpha=crossfade(0.12, life, XF),
                    life=(life, 0), loop_ms=L_RING, org=(2.4, 0.0, 0.0)))
    return efx2(els)


RISE_FLAGS = 'spawnRelative spawnOffsetCylinder runRelToEffect spawnFrustumCull'


def column(T):
    els = []
    # the prism: red at the feet, violet over the head; they spiral because the host turns
    els.append(elem(T, 'arch_motes', sprite='billboardSprite', material='gfx_light_phosphorous_em',
                    width=5.0, color=rainbow_over(), alpha=[(0.0, 0.0), (0.12, 0.9), (0.65, 0.75), (1.0, 0.0)],
                    size_rows=[(0.0, 0.5), (0.15, 1.0), (1.0, 0.35)],
                    life=(1300, 300), loop_ms=22, cyl=((18.0, 12.0), (0.0, 18.0)),
                    vel_x=(32.0, 1.0, 1.0), gravity=(-5.0, 0.0), near=(20.0, 48.0), flags=RISE_FLAGS, zfeather=4.0))
    els.append(elem(T, 'arch_sparks', sprite='billboardSprite', material='gfx_light_phosphorous_em',
                    width=2.4, color=flat(WHITE_GOLD), alpha=[(0.0, 0.0), (0.1, 1.0), (0.6, 0.9), (1.0, 0.0)],
                    size_rows=[(0.0, 1.0), (1.0, 0.3)],
                    life=(850, 200), loop_ms=70, cyl=((14.0, 12.0), (0.0, 10.0)),
                    vel_x=(70.0, 1.0, 1.0), gravity=(-2.0, 0.0), near=(20.0, 48.0), flags=RISE_FLAGS, zfeather=4.0))
    els.append(elem(T, 'arch_glyphs', sprite='billboardSprite', material='gfx_keeper_symbols_zod_em',
                    width=7.5, color=flat(GOLD), alpha=[(0.0, 0.0), (0.2, 0.85), (0.7, 0.7), (1.0, 0.0)],
                    size_rows=[(0.0, 0.6), (0.2, 1.0), (1.0, 0.8)],
                    life=(1700, 300), loop_ms=420, cyl=((16.0, 10.0), (6.0, 24.0)), atlas=True,
                    vel_x=(24.0, 1.0, 1.0), gravity=(-1.5, 0.0), rot_rate=20.0, near=(20.0, 48.0), flags=RISE_FLAGS))
    life = L_RING + XF
    for m, (h, w) in enumerate(((20.0, 54.0), (42.0, 48.0), (62.0, 40.0))):   # a faint radiance
        els.append(elem(T, 'arch_radiance_%d' % m, sprite='billboardSprite', material='gfx_light_bokeh_soft_em',
                        width=w, color=flat(WHITE_GOLD), alpha=crossfade(0.05, life, XF),
                        life=(life, 0), loop_ms=L_RING, org=(h, 0.0, 0.0), near=(36.0, 64.0)))
    return efx2(els)


def column_1p(T):
    # Own view: motes leave the ring's edge and are gone below eye height.
    return efx2([elem(T, 'arch_motes_1p', sprite='billboardSprite', material='gfx_light_phosphorous_em',
                      width=3.6, color=rainbow_over(), alpha=[(0.0, 0.0), (0.15, 0.85), (0.6, 0.6), (1.0, 0.0)],
                      size_rows=[(0.0, 0.5), (0.2, 1.0), (1.0, 0.3)],
                      life=(900, 250), loop_ms=50, cyl=((46.0, 10.0), (0.0, 4.0)),
                      vel_x=(16.0, 1.0, 1.0), gravity=(-3.0, 0.0), near=(24.0, 40.0), flags=RISE_FLAGS, zfeather=4.0)])


def rise(T, own_view):
    els = []
    k_alpha = 0.8 if own_view else 1.0
    els.append(elem(T, 'rise_band', sprite='orientedSprite', material='gfx_ring_hvy_em', looping=False,
                    width=BAND_W * 190.0, color=flat(WHITE_GOLD), size_rows=EASE_OUT,
                    alpha=[(0.0, 0.0), (0.05, 0.85 * k_alpha), (0.45, 0.55 * k_alpha), (1.0, 0.0)],
                    life=(460, 0), org=(3.0, 0.0, 0.0)))
    for k in range(6):
        els.append(elem(T, 'rise_line_%d' % k, sprite='orientedSprite', material='gfx_ui_ring_thin', looping=False,
                        width=RING_W * 200.0, color=flat(WHITE_GOLD), size_rows=EASE_OUT,
                        alpha=[(0.0, 0.0), (0.04, 1.0 * k_alpha), (0.5, 0.6 * k_alpha), (1.0, 0.0)],
                        life=(400, 0), org=(3.2, 0.0, 0.0), rot0=(30.0 * k, 0.0)))
    for k, rgb in enumerate(RAINBOW):   # the white light disperses: concentric rainbow bands
        els.append(elem(T, 'rise_ripple_%d' % k, sprite='orientedSprite', material='gfx_ring_hvy_em', looping=False,
                        width=BAND_W * (168.0 - 12.0 * k), color=flat(rgb), size_rows=EASE_OUT,
                        alpha=[(0.0, 0.0), (0.08, 0.6), (0.5, 0.35), (1.0, 0.0)],
                        life=(560, 0), delay=45 + 38 * k, org=(2.6, 0.0, 0.0)))
    if own_view:   # runes skitter out low across the floor
        els.append(elem(T, 'rise_glyphs_1p', sprite='billboardSprite', material='gfx_keeper_symbols_zod_em',
                        looping=False, oneshot=8, width=9.0, color=flat(GOLD), atlas=True,
                        alpha=[(0.0, 0.0), (0.08, 1.0), (0.6, 0.8), (1.0, 0.0)],
                        size_rows=[(0.0, 0.6), (0.15, 1.1), (1.0, 0.7)],
                        life=(700, 200), cyl=((10.0, 10.0), (2.0, 6.0)),
                        vel_x=(60.0, 0.33, 1.0), vel_y=(340.0, -0.5, 0.5), vel_z=(340.0, -0.5, 0.5),
                        gravity=(22.0, 0.0), rot_rate=40.0, near=(24.0, 40.0), flags=RISE_FLAGS))
        return efx2(els)
    for k, rgb in enumerate(RAINBOW):   # a rainbow fountain
        els.append(elem(T, 'rise_fountain_%d' % k, sprite='billboardSprite', material='gfx_light_phosphorous_em',
                        looping=False, oneshot=7, width=4.2, color=flat(rgb),
                        alpha=[(0.0, 0.0), (0.06, 1.0), (0.55, 0.85), (1.0, 0.0)],
                        size_rows=[(0.0, 1.0), (1.0, 0.35)],
                        life=(900, 300), cyl=((6.0, 22.0), (0.0, 10.0)),
                        vel_x=(400.0, 0.55, 1.0), vel_y=(200.0, -0.5, 0.5), vel_z=(200.0, -0.5, 0.5),
                        gravity=(55.0, 0.0), near=(20.0, 48.0), flags=RISE_FLAGS))
    els.append(elem(T, 'rise_glyphs', sprite='billboardSprite', material='gfx_keeper_symbols_zod_em',
                    looping=False, oneshot=8, width=9.0, color=flat(GOLD), atlas=True,
                    alpha=[(0.0, 0.0), (0.08, 1.0), (0.6, 0.8), (1.0, 0.0)],
                    size_rows=[(0.0, 0.6), (0.15, 1.1), (1.0, 0.7)],
                    life=(750, 200), cyl=((4.0, 10.0), (6.0, 18.0)),
                    vel_x=(130.0, 0.31, 1.0), vel_y=(300.0, -0.5, 0.5), vel_z=(300.0, -0.5, 0.5),
                    gravity=(14.0, 0.0), rot_rate=40.0, near=(20.0, 48.0), flags=RISE_FLAGS))
    return efx2(els)


def fade(T):
    els = []
    implode = [(0.0, 1.0), (0.4, 0.75), (0.75, 0.35), (1.0, 0.04)]
    els.append(elem(T, 'fade_band', sprite='orientedSprite', material='gfx_ring_hvy_em', looping=False,
                    width=BAND_W * GLOW_R, color=flat(GOLD), size_rows=implode,
                    alpha=[(0.0, 0.35), (0.5, 0.6), (0.85, 0.5), (1.0, 0.0)], life=(420, 0), org=(2.0, 0.0, 0.0)))
    for k, rgb in enumerate(RAINBOW):
        els.append(elem(T, 'fade_line_%d' % k, sprite='orientedSprite', material='gfx_ui_ring_thin', looping=False,
                        width=RING_W * OUTER_R, color=flat(rgb), size_rows=[(0.0, 1.0), (0.5, 0.62), (1.0, 0.05)],
                        alpha=[(0.0, 0.9), (0.6, 0.75), (1.0, 0.0)], life=(380, 0), org=(3.0, 0.0, 0.0),
                        rot0=(30.0 * k, 0.0)))
    els.append(elem(T, 'fade_flash', sprite='orientedSprite', material='gfx_light_bokeh_soft_em', looping=False,
                    width=DISC_W * 56.0, color=flat(WHITE_GOLD), size_rows=[(0.0, 0.6), (1.0, 1.1)],
                    alpha=[(0.0, 0.5), (1.0, 0.0)], life=(300, 0), org=(1.5, 0.0, 0.0)))
    els.append(elem(T, 'fade_sparks', sprite='billboardSprite', material='gfx_light_phosphorous_em',
                    looping=False, oneshot=22, width=3.0, color=flat(GOLD),
                    alpha=[(0.0, 0.0), (0.1, 1.0), (0.6, 0.8), (1.0, 0.0)], size_rows=[(0.0, 1.0), (1.0, 0.3)],
                    life=(650, 200), cyl=((12.0, 18.0), (26.0, 54.0)),
                    vel_x=(60.0, -1.0, 0.17), vel_y=(80.0, -0.5, 0.5), vel_z=(80.0, -0.5, 0.5),
                    gravity=(40.0, 0.0), near=(24.0, 48.0), flags=RISE_FLAGS))
    return efx2(els)


def fade_ramp(life, xf):
    a = xf / float(life)
    return [(0, 0), (a, 1), (1 - a, 1), (1, 0)]


def render(tools):
    T = templates_from(tools)
    llife = L_LIGHT + XF
    out = {
        'circle': circle(T),
        'inner': inner(T),
        'column': column(T),
        'column_1p': column_1p(T),
        'rise': rise(T, False),
        'rise_1p': rise(T, True),
        'fade': fade(T),
    }
    for key, spec in (('light', LIGHT_3P), ('light_1p', LIGHT_1P)):
        out[key] = light_efx('arch_' + key, looping=True, life=llife, loop_ms=L_LIGHT, height=spec['height'],
                             radius=spec['radius'], intensity_base=spec['intensity'],
                             intensity_rows=fade_ramp(llife, XF), color_rows=rainbow_cycle(L_LIGHT, llife))
    out['rise_light'] = light_efx('arch_rise_light', looping=False, life=520, loop_ms=520, height=42, radius=240,
                                  intensity_base=2400, intensity_rows=[(0, 0), (0.08, 1), (0.35, 0.55), (1, 0)],
                                  color_rows=flat(WHITE_GOLD))
    return out


# ---- the gate ------------------------------------------------------------------

def check_lockstep():
    gsc = GSC.read_text(encoding='utf-8').replace('\r\n', '\n')
    csc = CSC.read_text(encoding='utf-8').replace('\r\n', '\n')
    zone = ZONE.read_text(encoding='utf-8').replace('\r\n', '\n')
    lua = TINT_LUA.read_text(encoding='utf-8')
    # The rainbow IS the health bar's: same six colours, same order.
    m = re.search(r'local COLORS = \{(.*?)\n\}', lua, re.S)
    lua_cols = [tuple(float(x) for x in c.split(',')) for c in re.findall(r'\{\s*([\d.]+\s*,\s*[\d.]+\s*,\s*[\d.]+)\s*\}', m.group(1))] if m else []
    if lua_cols != RAINBOW:
        raise SystemExit('RAINBOW %s != TodHealthTint.lua COLORS %s' % (RAINBOW, lua_cols))
    # ONE clientfield, the same in both VMs (a mismatch fails the map load), from
    # the REGISTER_SYSTEM __init__ (memory clientfield-registration-window).
    g = re.findall(r'clientfield::register\(\s*"allplayers"\s*,\s*TOD_ARCH_FX_FIELD\s*,\s*VERSION_SHIP\s*,\s*(\d+)\s*,\s*"int"\s*\)', gsc)
    c = re.findall(r'clientfield::register\(\s*"allplayers"\s*,\s*TOD_ARCH_FX_FIELD\s*,\s*VERSION_SHIP\s*,\s*(\d+)\s*,\s*"int"\s*,\s*&arch_form_cb', csc)
    if g != ['2'] or c != ['2']:
        raise SystemExit('tod_arch_form must be registered once per VM, "allplayers", 2 bits, int (gsc %s, csc %s)' % (g, c))
    for src, label in ((gsc, 'gsc'), (csc, 'csc')):
        if not re.search(r'#define TOD_ARCH_FX_FIELD\s+"tod_arch_form"', src):
            raise SystemExit('TOD_ARCH_FX_FIELD must be "tod_arch_form" in the ' + label)
        init = re.search(r'function __init__\(\)\s*\{(.*?)\n\}', src, re.S)
        if not init or 'TOD_ARCH_FX_FIELD' not in init.group(1):
            raise SystemExit('the %s must register tod_arch_form inside __init__ (the registration window)' % label)
    # The form drives it: on at the start, the fade on the timer's end, off when cut.
    run = re.search(r'function demigod_run\(\)(.*?)\n\}', gsc, re.S)
    end = re.search(r'function demigod_end\( sound \)(.*?)\n\}', gsc, re.S)
    if not run or 'arch_fx_set( TOD_ARCH_FX_ON' not in run.group(1):
        raise SystemExit('demigod_run must turn the form effect on')
    if not end or 'TOD_ARCH_FX_FADE' not in end.group(1) or 'TOD_ARCH_FX_OFF' not in end.group(1):
        raise SystemExit('demigod_end must fade (timer) or cut (death / class change) the form effect')
    # The client side: every effect precached + registered, killed with KillFX.
    for key, stem in FX.items():
        fx = 'tod/mage/' + stem
        if ('#precache( "client_fx", "%s" );' % fx) not in csc:
            raise SystemExit('missing client_fx #precache for ' + fx)
        if ('level._effect[ "tod_arch_%s" ] = "%s";' % (key, fx)) not in csc:
            raise SystemExit('the csc must register level._effect["tod_arch_%s"]' % key)
        if ('\nfx,%s\n' % fx) not in zone:
            raise SystemExit('missing zone line fx,' + fx)
    if 'KillFX( localClientNum' not in re.search(r'function arch_fx_teardown\(.*?\n\}', csc, re.S).group(0):
        raise SystemExit('arch_fx_teardown must KillFX (StopFX leaves the particles behind)')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--tools', type=Path, default=DEFAULT_TOOLS)
    args = parser.parse_args()
    expected = render(args.tools)
    bad = []
    for key, stem in FX.items():
        target = OUT_DIR / (stem + '.efx')
        text = expected[key]
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
            raise SystemExit('Archmage FX differ (' + ', '.join(bad) + '); run tools/gen_archmage_fx.py')
        check_lockstep()
        print('Archmage FX verified: %d effects (circle, inner ring, column 3p/1p, light 3p/1p, rise 3p/1p + light, fade), '
              'rainbow == TodHealthTint, tod_arch_form registered in both VMs, every effect precached/registered/zoned.' % len(FX))


if __name__ == '__main__':
    main()
