"""RAMPAGE SHOWS ON THE TOWER: the column's four lit strips carry it.

User, 2026-10-01: "for the rampage visual lets make the tower show it instead of
the player. I know the tower has this strip going along the sides. Maybe we can
make that visual there or something" -> the signed plan ("Go"): the four CORE
SPINES (gen_tower_map.js v16.13 facelift section 7 - a CORE_SPINE_W-wide bar in
the district's plain hue down the middle of every face of the central column,
base to crown; every flight runs along it, so it is the surface a player looks
at most) carry red-orange energy while Rampage is on.

  fx_rampage_spine   per lap and face, LOOPING while Rampage is on: the strip
                     BURNS - a dense hot-orange core of flickering glows along
                     its whole length, a red halo, a wide red haze that blooms
                     the column from afar, and sparks spitting off it. NOTHING
                     TRAVELS: the glows hang where they are born (user, after
                     the first look, 2026-10-02: "remove the shooting lines and
                     make the visuals on the tower a bit stronger. I dont want
                     the shooting visual effects" - the v19.68j comets and the
                     climbing surge are gone).
  fx_rampage_flare   per lap and face, ONE-SHOT when Rampage is switched on:
                     the strips flare bright all at once, then settle into the
                     burn (the CSC fires every lap within a few frames - a
                     flash of the whole column, not a wave).
  fx_rampage_on(_light)  ONE-SHOT at the switch: an orange shockwave across the
                     arena floor, a red second wave, a floor flash, a spark
                     fountain off the device, rising embers, an orange flash.
  fx_rampage_off     ONE-SHOT at the switch: a puff of smoke (stock billow
                     smoke, 8x8 atlas played over its life), falling sparks and
                     a ring that collapses into the device.

The strip effects are played by _tod_rampage.csc, CLIENT-side, from each
player's own Rampage HUD value (the existing todRampage clientuimodel - no new
network field), only on the laps around that player, with PlayFx( origin,
forward = world up, up = the face's outward normal ): so X is height up the lap,
Z is the distance proud of the face, Y runs across the strip. The switch bursts
are played by _tod_rampage.gsc on a host facing up (two server frames after the
host exists - the same-frame rule).

Built with the Archmage generator's element builder (gen_archmage_fx.elem; every
unit measured there). --check is the build gate: effects byte-for-byte, the
tower geometry in the CSC == gen_tower_map.js, the HUD value's name, every
precache / effect key / zone line, the CSC is loaded, and the switch burst waits.
"""
import argparse
from pathlib import Path
import re

import gen_archmage_fx as fxlib

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / 'share/raw/fx/tod/rampage'
GEN_MAP = ROOT / 'tools/gen_tower_map.js'
GSC = ROOT / 'scripts/zm/zm_tower_of_doom/_tod_rampage.gsc'
CSC = ROOT / 'scripts/zm/zm_tower_of_doom/_tod_rampage.csc'
MAIN_CSC = ROOT / 'scripts/zm/zm_tower_of_doom.csc'
UI_GSC = ROOT / 'scripts/zm/zm_tower_of_doom/_tod_upgrade_ui.gsc'
ZONE = ROOT / 'zone_source/zm_tower_of_doom.zone'

RAMP_HOT = (1.0, 0.62, 0.28)
RAMP_WHITE = (1.0, 0.86, 0.62)
RAMP_CORE = (1.0, 0.38, 0.10)
RAMP_RED = (1.0, 0.14, 0.05)
RAMP_SPARK = (1.0, 0.5, 0.18)
SMOKE = (0.42, 0.38, 0.35)

LAP_H = 384.0                # LOCKSTEP: gen_tower_map.js LAP_RISE (checked)
SPINE_HALF = 16.0            # LOCKSTEP: CORE_SPINE_W / 2 (checked)
RAMP_BURN = (1.0, 0.32, 0.08)   # the strip's core
RAMP_DEEP = (0.8, 0.08, 0.03)   # the haze

WORLD = 'spawnRelative spawnOffsetNone runRelToWorld'
CYL = 'spawnRelative spawnOffsetCylinder runRelToWorld'
FLICKER = [(0.0, 0.0), (0.08, 0.9), (0.18, 0.45), (0.28, 1.0), (0.4, 0.55), (0.52, 0.95),
           (0.66, 0.5), (0.8, 0.8), (1.0, 0.0)]


def mix(c, d, f):
    return tuple(c[i] + (d[i] - c[i]) * f for i in range(3))


def smoke_atlas(t):
    """Stock's billow smoke: an 8x8 atlas played once over the particle's life
    (zombie/fx_robot_helper_jet_leg_zod_zmb.efx, already in this map)."""
    t = fxlib.field(t, 'atlasBehavior', 'startFixed playOverLife loopOnlyNTimes')
    t = fxlib.field(t, 'atlasIndex', '0')
    t = fxlib.field(t, 'atlasFps', '0')
    t = fxlib.field(t, 'atlasLoopCount', '1')
    t = fxlib.field(t, 'atlasColIndexBits', '3')
    t = fxlib.field(t, 'atlasRowIndexBits', '3')
    t = fxlib.field(t, 'atlasEntryCount', '64')
    t = fxlib.field(t, 'atlasIndexRange', '0')
    return t


BURN = [(0.0, 0.0), (0.12, 0.55), (0.3, 0.38), (0.48, 0.55), (0.66, 0.42), (0.84, 0.5), (1.0, 0.0)]


def spine(T):
    """The burn: every element hangs where it is born (a drift of a few units a
    second at most) - glow and flicker, never a streak."""
    e = fxlib.elem
    near = dict(spawn_range=(0.0, 4000.0), fade_in=(3000.0, 1000.0))
    els = []
    els.append(e(T, 'spine_core', sprite='billboardSprite', material='gfx_light_phosphorous_em',
                 width=40.0, color=fxlib.flat(RAMP_BURN), alpha=BURN, size_rows=[(0.0, 0.85), (0.5, 1.0), (1.0, 0.9)],
                 life=(900, 200), loop_ms=100, org=(0.0, -4.0, 4.0), org_range=(LAP_H, 8.0, 0.0),
                 vel_x=(8.0, 0.5, 1.5), near=(16.0, 40.0), flags=WORLD, **near))
    els.append(e(T, 'spine_halo', sprite='billboardSprite', material='gfx_light_phosphorous_em',
                 width=130.0, color=fxlib.flat(RAMP_RED),
                 alpha=[(0.0, 0.0), (0.3, 0.17), (0.7, 0.13), (1.0, 0.0)], size_rows=[(0.0, 0.85), (1.0, 1.1)],
                 life=(1700, 300), loop_ms=300, org=(0.0, -SPINE_HALF / 2, 8.0), org_range=(LAP_H, SPINE_HALF, 0.0),
                 vel_x=(6.0, 0.5, 1.5), near=(40.0, 90.0), flags=WORLD, zfeather=20.0, **near))
    els.append(e(T, 'spine_haze', sprite='billboardSprite', material='gfx_light_bokeh_soft_em',
                 width=260.0, color=fxlib.flat(RAMP_DEEP),
                 alpha=[(0.0, 0.0), (0.35, 0.07), (0.7, 0.06), (1.0, 0.0)], size_rows=[(0.0, 0.9), (1.0, 1.1)],
                 life=(2400, 400), loop_ms=700, org=(0.0, -12.0, 14.0), org_range=(LAP_H, 24.0, 0.0),
                 near=(80.0, 160.0), flags=WORLD, zfeather=30.0, **near))
    els.append(e(T, 'spine_sparks', sprite='billboardSprite', material='gfx_light_phosphorous_em',
                 width=2.6, color=fxlib.flat(RAMP_SPARK), alpha=FLICKER, size_rows=[(0.0, 1.0), (1.0, 0.4)],
                 life=(700, 250), loop_ms=220, org=(0.0, -(SPINE_HALF - 2.0), 3.0),
                 org_range=(LAP_H, 2.0 * (SPINE_HALF - 2.0), 0.0),
                 vel_x=(40.0, -0.5, 1.0), vel_z=(100.0, 0.3, 1.0), gravity=(35.0, 0.0),
                 spawn_range=(0.0, 2500.0), fade_in=(2000.0, 500.0), near=(16.0, 36.0), flags=WORLD))
    return fxlib.efx2(els)


def flare(T):
    """The flip: the whole strip flashes bright where it stands and settles."""
    e = fxlib.elem
    far = dict(spawn_range=(0.0, 12000.0), fade_in=(11000.0, 1000.0))
    els = []
    els.append(e(T, 'flare_bloom', sprite='billboardSprite', material='gfx_light_bokeh_soft_em', looping=False,
                 oneshot=5, width=150.0, color=fxlib.flat(RAMP_CORE),
                 alpha=[(0.0, 0.0), (0.08, 0.55), (1.0, 0.0)], size_rows=[(0.0, 0.8), (1.0, 1.15)],
                 life=(800, 200), org=(0.0, -SPINE_HALF / 2, 8.0), org_range=(LAP_H, SPINE_HALF, 0.0),
                 near=(40.0, 90.0), flags=WORLD, zfeather=20.0, **far))
    els.append(e(T, 'flare_core', sprite='billboardSprite', material='gfx_light_phosphorous_em', looping=False,
                 oneshot=8, width=60.0, color=fxlib.flat(RAMP_WHITE),
                 alpha=[(0.0, 0.0), (0.06, 0.9), (1.0, 0.0)], size_rows=[(0.0, 1.0), (1.0, 0.8)],
                 life=(500, 120), org=(0.0, -4.0, 5.0), org_range=(LAP_H, 8.0, 0.0),
                 near=(20.0, 60.0), flags=WORLD, **far))
    return fxlib.efx2(els)


def switch_on(T):
    e = fxlib.elem
    els = []
    els.append(e(T, 'on_band', sprite='orientedSprite', material='gfx_ring_hvy_em', looping=False,
                 width=fxlib.BAND_W * 520.0, color=fxlib.flat(RAMP_CORE), size_rows=fxlib.EASE_OUT,
                 alpha=[(0.0, 0.0), (0.05, 0.8), (0.45, 0.45), (1.0, 0.0)], life=(800, 0), org=(2.0, 0.0, 0.0)))
    for k in range(6):
        els.append(e(T, 'on_ring_%d' % k, sprite='orientedSprite', material='gfx_ui_ring_thin', looping=False,
                     width=fxlib.RING_W * 540.0, color=fxlib.flat(RAMP_HOT), size_rows=fxlib.EASE_OUT,
                     alpha=[(0.0, 0.0), (0.04, 1.0), (0.5, 0.55), (1.0, 0.0)], life=(700, 0),
                     org=(2.4, 0.0, 0.0), rot0=(30.0 * k, 0.0)))
    els.append(e(T, 'on_band_2', sprite='orientedSprite', material='gfx_ring_hvy_em', looping=False,
                 width=fxlib.BAND_W * 360.0, color=fxlib.flat(RAMP_RED), size_rows=fxlib.EASE_OUT,
                 alpha=[(0.0, 0.0), (0.06, 0.55), (0.5, 0.3), (1.0, 0.0)], life=(700, 0), delay=140,
                 org=(1.8, 0.0, 0.0)))
    els.append(e(T, 'on_floor', sprite='orientedSprite', material='gfx_light_bokeh_soft_em', looping=False,
                 width=fxlib.DISC_W * 220.0, color=fxlib.flat(RAMP_CORE), size_rows=[(0.0, 0.5), (1.0, 1.1)],
                 alpha=[(0.0, 0.0), (0.06, 0.55), (1.0, 0.0)], life=(500, 0), org=(1.5, 0.0, 0.0)))
    els.append(e(T, 'on_fountain', sprite='billboardSprite', material='gfx_light_phosphorous_em', looping=False,
                 oneshot=40, width=3.4, color=fxlib.flat(RAMP_SPARK),
                 alpha=[(0.0, 0.0), (0.05, 1.0), (0.6, 0.85), (1.0, 0.0)], size_rows=[(0.0, 1.0), (1.0, 0.35)],
                 life=(1200, 400), cyl=((4.0, 14.0), (24.0, 12.0)),
                 vel_x=(380.0, 0.4, 1.0), vel_y=(150.0, -1.0, 1.0), vel_z=(150.0, -1.0, 1.0),
                 gravity=(50.0, 0.0), near=(20.0, 48.0), flags=CYL))
    els.append(e(T, 'on_embers', sprite='billboardSprite', material='gfx_light_phosphorous_em', looping=False,
                 oneshot=16, width=2.0, color=fxlib.flat(RAMP_CORE), alpha=FLICKER,
                 size_rows=[(0.0, 1.0), (1.0, 0.5)], life=(2000, 500), cyl=((6.0, 40.0), (10.0, 30.0)),
                 vel_x=(120.0, 0.5, 1.0), vel_y=(30.0, -1.0, 1.0), vel_z=(30.0, -1.0, 1.0),
                 gravity=(-2.0, 0.0), near=(20.0, 40.0), flags=CYL))
    return fxlib.efx2(els)


def switch_on_light():
    return fxlib.light_efx('rampage_on_light', looping=False, life=900, loop_ms=900, height=60, radius=600,
                           intensity_base=3000, intensity_rows=[(0, 0), (0.05, 1), (0.35, 0.5), (1, 0)],
                           color_rows=fxlib.flat(RAMP_CORE))


def switch_off(T):
    e = fxlib.elem
    els = []
    smoke = e(T, 'off_smoke', sprite='billboardSprite', material='gfx_smk_billow_sm_anim_em', looping=False,
              oneshot=6, width=46.0, color=fxlib.flat(SMOKE), size_rows=[(0.0, 0.6), (1.0, 1.6)],
              alpha=[(0.0, 0.0), (0.15, 0.5), (1.0, 0.0)], life=(1600, 400), cyl=((0.0, 10.0), (20.0, 14.0)),
              vel_x=(40.0, 0.6, 1.2), vel_y=(12.0, -1.0, 1.0), vel_z=(12.0, -1.0, 1.0),
              rot_rate=40.0, near=(30.0, 60.0), flags=CYL, zfeather=10.0)
    els.append(smoke_atlas(smoke))
    els.append(e(T, 'off_sparks', sprite='billboardSprite', material='gfx_light_phosphorous_em', looping=False,
                 oneshot=18, width=2.6, color=fxlib.flat(mix(RAMP_SPARK, SMOKE, 0.3)),
                 alpha=[(0.0, 0.0), (0.05, 0.9), (0.5, 0.7), (1.0, 0.0)], size_rows=[(0.0, 1.0), (1.0, 0.4)],
                 life=(600, 200), cyl=((2.0, 10.0), (26.0, 8.0)),
                 vel_x=(120.0, -0.2, 1.0), vel_y=(80.0, -1.0, 1.0), vel_z=(80.0, -1.0, 1.0),
                 gravity=(45.0, 0.0), near=(20.0, 40.0), flags=CYL))
    for k in range(6):
        els.append(e(T, 'off_ring_%d' % k, sprite='orientedSprite', material='gfx_ui_ring_thin', looping=False,
                     width=fxlib.RING_W * 90.0, color=fxlib.flat(RAMP_CORE),
                     size_rows=[(0.0, 1.0), (0.5, 0.6), (1.0, 0.1)], alpha=[(0.0, 0.8), (0.6, 0.6), (1.0, 0.0)],
                     life=(350, 0), org=(2.0, 0.0, 0.0), rot0=(30.0 * k, 0.0)))
    return fxlib.efx2(els)


def render(tools):
    T = fxlib.templates_from(tools)
    return {
        'fx_rampage_spine': spine(T),
        'fx_rampage_flare': flare(T),
        'fx_rampage_on': switch_on(T),
        'fx_rampage_on_light': switch_on_light(),
        'fx_rampage_off': switch_off(T),
    }


# ---- the gate ------------------------------------------------------------------

def js_const(js, name):
    # `const A = 1;` or one of several on a line: `const STEPS = 16, TREAD = 32, RISE = 12;`
    m = re.search(r'^const (?:[^;\n]*?,\s*)?' + name + r'\s*=\s*([^,;\n]+)', js, re.M)
    if not m:
        raise SystemExit('gen_tower_map.js lost const ' + name)
    return m.group(1).split('//')[0].strip()


def tower_numbers():
    js = GEN_MAP.read_text(encoding='utf-8')
    steps = int(js_const(js, 'STEPS'))
    rise = int(js_const(js, 'RISE'))
    if js_const(js, 'FLIGHT_RISE') != 'STEPS * RISE' or js_const(js, 'LAP_RISE') != '2 * FLIGHT_RISE':
        raise SystemExit('gen_tower_map.js LAP_RISE is no longer 2 * STEPS * RISE - re-read it')
    return {'CORE': int(js_const(js, 'CORE')), 'LAP_RISE': 2 * steps * rise, 'LAPS': int(js_const(js, 'LAPS')),
            'SPINE_W': int(js_const(js, 'CORE_SPINE_W'))}


def body(src, name):
    m = re.search(r'\nfunction ' + name + r'\([^)]*\)[^\n]*\n\{(.*?)\n\}', src, re.S)
    if not m:
        raise SystemExit('lost function ' + name)
    return m.group(1)


def check_lockstep(stems):
    nums = tower_numbers()
    if nums['LAP_RISE'] != LAP_H or nums['SPINE_W'] / 2.0 != SPINE_HALF:
        raise SystemExit('the strip effects assume LAP_RISE %s / spine %s, the tower has %s / %s'
                         % (LAP_H, SPINE_HALF * 2, nums['LAP_RISE'], nums['SPINE_W']))
    csc = CSC.read_text(encoding='utf-8').replace('\r\n', '\n')
    gsc = GSC.read_text(encoding='utf-8').replace('\r\n', '\n')
    main_csc = MAIN_CSC.read_text(encoding='utf-8').replace('\r\n', '\n')
    ui = UI_GSC.read_text(encoding='utf-8').replace('\r\n', '\n')
    zone = ZONE.read_text(encoding='utf-8').replace('\r\n', '\n')
    for name, key in (('TOD_RAMPAGE_CORE', 'CORE'), ('TOD_RAMPAGE_LAP_RISE', 'LAP_RISE'), ('TOD_RAMPAGE_LAPS', 'LAPS')):
        m = re.search(r'#define ' + name + r'\s+(\d+)', csc)
        if not m or int(m.group(1)) != nums[key]:
            raise SystemExit('_tod_rampage.csc %s != gen_tower_map.js %s (%s)' % (name, key, nums[key]))
    # The client reads the server's own Rampage HUD value - same name, still registered.
    if 'clientfield::register( "clientuimodel", "todRampage"' not in ui or '"todRampage"' not in body(csc, 'rampage_on'):
        raise SystemExit('_tod_rampage.csc must read the todRampage clientuimodel _tod_upgrade_ui.gsc registers')
    client = {'fx_rampage_spine', 'fx_rampage_flare'}
    if 'fx_rampage_surge' in csc or 'fx_rampage_surge' in zone:
        raise SystemExit('the retired climbing surge (fx_rampage_surge) is still referenced')
    for stem in stems:
        fx = 'tod/rampage/' + stem
        key = 'tod_' + stem[3:]
        if ('\nfx,%s\n' % fx) not in zone:
            raise SystemExit('missing zone line fx,' + fx)
        if stem in client:
            if ('#precache( "client_fx", "%s" );' % fx) not in csc or ('level._effect[ "%s" ] = "%s";' % (key, fx)) not in csc:
                raise SystemExit('_tod_rampage.csc must precache and register ' + fx)
        else:
            if ('#precache( "fx", "%s" );' % fx) not in gsc or ('level._effect[ "%s" ] = "%s";' % (key, fx)) not in gsc:
                raise SystemExit('_tod_rampage.gsc must precache and register ' + fx)
    if '\nscriptparsetree,scripts/zm/zm_tower_of_doom/_tod_rampage.csc\n' not in zone:
        raise SystemExit('missing zone line scriptparsetree,scripts/zm/zm_tower_of_doom/_tod_rampage.csc')
    if '#using scripts\\zm\\zm_tower_of_doom\\_tod_rampage;' not in main_csc:
        raise SystemExit('zm_tower_of_doom.csc must #using _tod_rampage or the strips never light')
    # The switch: a burst on every flip, never on a host made in the same frame.
    if 'level thread switch_burst( IS_TRUE( level.tod_rampage_on ) );' not in body(gsc, 'station_setup'):
        raise SystemExit('the Rampage use loop must thread switch_burst on every flip')
    if re.search(r'PlayFXOnTag\(', body(gsc, 'switch_burst'), re.I):
        raise SystemExit('switch_burst plays on the host it just made - leave it to switch_burst_play')
    late = body(gsc, 'switch_burst_play')
    if late.count('WAIT_SERVER_FRAME;') < 2 or late.index('WAIT_SERVER_FRAME;') > late.index('PlayFXOnTag('):
        raise SystemExit('switch_burst_play must wait two server frames before PlayFXOnTag')
    # The client: stopped with StopFX (the strips fade), the flare only on a real flip.
    watch = body(csc, 'tower_watch')
    if 'StopFX( localClientNum' not in csc or 'first' not in watch or 'flare(' not in watch:
        raise SystemExit('tower_watch must StopFX the laps it leaves and flare only on a real flip')
    # NOTHING SHOOTS (user 2026-10-02): no strip element moves faster than a drift.
    for stem in client:
        text = (OUT_DIR / (stem + '.efx')).read_text(encoding='utf-8')
        for m in re.finditer(r'\n\tname "([^"]+)";.*?\n\tvelGraph0X ([-\d.]+)\n\t\{\n\t\t\{\n([^}]*)\}\n\t\t\{\n([^}]*)\}', text, re.S):
            name, scale = m.group(1), float(m.group(2))
            top = max(abs(float(v)) for rows in (m.group(3), m.group(4)) for v in rows.split()[1::2])
            if 'sparks' not in name and scale * top > 20.0:
                raise SystemExit('%s: %s climbs at %.0f u/s - the strips must burn, not shoot' % (stem, name, scale * top))


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
            raise SystemExit('Rampage FX differ (' + ', '.join(bad) + '); run tools/gen_rampage_fx.py')
        check_lockstep(list(expected))
        print('Rampage FX verified: %d effects (the strip burn + flare - nothing shoots, switch on + light, switch off); '
              'tower geometry == gen_tower_map.js, todRampage read, precache/effect keys/zone/CSC load, the switch waits.'
              % len(expected))


if __name__ == '__main__':
    main()
