"""The Healing Aura's ground effect: a green AREA with a crisp rim and a pulse.

User, 2026-10-01, after the v19.68 ring: "the mage healing visual effects ...
Should be a green pulse or area that looks nice for the radius of the effect ...
Might need to make the effect from scratch". The v19.68 ring was 12 tiny soul
glows (6-24 units) centred 4 units above the floor - half of each sank into it,
and nothing read as an area. This builds one effect per aura radius (the cast's
level picks it), drawn FLAT on the floor the way MP Domination draws its zone:

  * RIM   - stock gfx_ui_ring_thin (its texture is two bracket arcs; six copies
            turned 30 degrees apart overlap to an even circle: measured coverage
            1.24..1.28 of one copy), its line exactly ON the radius.
  * FILL  - stock gfx_light_bokeh_soft_em, a soft speckled disc to the rim.
  * PULSE - the same ring sweeping from the caster out to the rim every second.
  * MOTES - green sparks: a sparkle band on the rim + motes rising inside.

All four are native LOOPING emitters (a server-played one-shot renders nothing in
this map; the luck soul / inducer / staff glows prove the looping lane), so the
area lives exactly as long as its host: _tod_mage_elements::heal_area_start
plays it on a tag_origin host turned to face up (Domination passes the ground's
up vector as the effect's forward; dom.csc PlayFx(..., up, forward)), follows the
caster and deletes it when the aura ends. Lifespans are short (rim/fill 0.5 s,
pulse 0.9 s) so the area clears within half a second of the aura.

MEASURED, NOT GUESSED (texture_assets/black_ops_3/gfx, 256x256):
  i_gfx_ui_vtol_beam_ring_brackets (gfx_ui_ring_thin): alpha band peaks at
    0.93-0.96 of the half-width -> sprite width = RING_W x radius.
  fxt_light_bokeh_soft (gfx_light_bokeh_soft_em): flat to ~0.92 of the half-width,
    soft edge to 1.0 -> the same width puts the disc's edge on the rim.
  Sprite size in an .efx is the FULL width: Domination's r120 variant is 231 wide,
    and its ring line (0.945 of the half-width) lands at 109 - the zone's radius.
  gravity is a percentage of world gravity (stock sparks 30, stock smoke -5): the
    motes rise on negative gravity, which is world-space whatever the host's turn.

Templates are STOCK sources (oriented sprite: ui/fx_dom_cap_indicator_team.efx
element 0; mote: dlc5/zmb_weapon/fx_staff_charge_souls.efx element 1, the luck
soul's core the user has seen render). Both materials are in the tools'
black_ops_3_fx.gdt, so the linker builds them. --check is the build gate.
"""
import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_TOOLS = Path('C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130')
OUT_DIR = ROOT / 'share/raw/fx/tod/mage'
RADII = (256, 288, 320, 352, 384, 416)   # LOCKSTEP: _tod_mage_elements::heal_radius
NAME = 'fx_healing_aura_area_{}'

RING_W = 2.12        # sprite width per unit of radius (the ring line at 0.945 of the half-width)
DISC_W = 2.12        # the bokeh disc's soft edge reaches the rim at the same width
LIFT = 3.0           # units above the floor, along the effect's forward (= world up)
RIM_COPIES = 6       # bracket arcs turned 0, 30 .. 150 degrees -> an even circle
GREEN_RIM = (0.42, 1.00, 0.52)
GREEN_GLOW = (0.18, 0.85, 0.32)
GREEN_FILL = (0.12, 0.70, 0.26)
GREEN_PULSE = (0.62, 1.00, 0.68)


def blocks(path):
    parts = re.split(r'\n\{\n', path.read_text(encoding='utf-8'))
    return parts[1:]


def one(pattern, repl, text, flags=0):
    out, n = re.subn(pattern, repl, text, count=1, flags=flags)
    if n != 1:
        raise ValueError('template changed: no match for ' + pattern)
    return out


def field(text, name, value):
    return one(r'\t' + name + r' [^\n]*;', lambda m: '\t' + name + ' ' + value + ';', text)


def graph(text, name, scale, rows):
    body = ''.join('\t\t\t' + ' '.join('%.6f' % v for v in row) + '\n' for row in rows)
    block = '\t%s %s\n\t{\n\t\t{\n%s\t\t}\n\t\t{\n%s\t\t}\n\t};' % (name, scale, body, body)
    return one(r'\t' + name + r' [^\n]*\n\t\{.*?\n\t\};', lambda m: block, text, re.S)


def triangle(peak):
    # Two copies alive at once (spawn every 250 ms, live 500 ms) -> the triangles
    # sum to a steady `peak`, and the last one is gone 0.5 s after the host.
    return [(0.0, 0.0), (0.5, peak), (1.0, 0.0)]


def color(rgb):
    return [(0.0,) + rgb, (1.0,) + rgb]


def oriented(template, name, material, width, alpha_rows, rgb, rot, loop_ms, life_ms, size_rows=None):
    t = one(r'name "[^"]+";', 'name "%s";' % name, template)
    t = field(t, 'extraFlags', '').replace('\textraFlags ;', '\textraFlags;')   # no teamFriendly: ZM
    t = field(t, 'spawnRange', '0.000000 6000.000000')
    t = field(t, 'fadeInRange', '0.000000 0.000000')
    t = field(t, 'fadeOutRange', '0.000000 0.000000')
    t = field(t, 'spawnLooping', '%d 0' % loop_ms)
    t = field(t, 'spawnLoopingSpawnCount', '1 0')
    t = field(t, 'lifeSpanMsec', '%d 0' % life_ms)
    t = field(t, 'spawnOrgX', '%.6f 0.000000' % LIFT)
    t = field(t, 'initialRot', '%.6f 0.000000' % rot)
    size_rows = size_rows or [(0.0, 1.0), (1.0, 1.0)]
    t = graph(t, 'sizeGraph0', '%.6f' % width, size_rows)
    t = graph(t, 'sizeGraph1', '%.6f' % width, size_rows)
    t = graph(t, 'colorGraph', '1', color(rgb))
    t = graph(t, 'alphaGraph', '1', alpha_rows)
    t = field(t, 'zFeather', '0.000000')   # flat 3 units over the floor: feathering would fade it out
    t = one(r'orientedSprite\n\t\{\n\t\t"[^"]+"\n\t\};', 'orientedSprite\n\t{\n\t\t"%s"\n\t};' % material, t)
    return t


def mote(template, name, radius_base, radius_range, height_base, height_range, loop_ms, life_ms, life_range, size, gravity, rgb):
    t = one(r'name "[^"]+";', 'name "%s";' % name, template)
    t = field(t, 'flags', 'spawnRelative spawnOffsetCylinder runRelToEffect')
    t = field(t, 'spawnRange', '0.000000 6000.000000')
    t = field(t, 'fadeOutRange', '0.000000 0.000000')
    t = field(t, 'spawnLooping', '%d 0' % loop_ms)
    t = field(t, 'lifeSpanMsec', '%d %d' % (life_ms, life_range))
    t = field(t, 'spawnOrgX', '0.000000 0.000000')
    t = field(t, 'spawnOffsetRadius', '%.6f %.6f' % (radius_base, radius_range))
    t = field(t, 'spawnOffsetHeight', '%.6f %.6f' % (height_base, height_range))
    t = field(t, 'spawnOffsetCylindricalAxis', '0.000000')
    t = field(t, 'gravity', '%.6f 0.000000' % gravity)
    rows = [(0.0, 0.35), (0.25, 1.0), (1.0, 0.0)]
    t = graph(t, 'sizeGraph0', '%.6f' % size, rows)
    t = graph(t, 'sizeGraph1', '%.6f' % size, rows)
    t = graph(t, 'colorGraph', '1', color(rgb))
    return t.replace(' dieOnTouch', '')


def render(tools, radius):
    ring = blocks(tools / 'share/raw/fx/ui/fx_dom_cap_indicator_team.efx')
    souls = blocks(tools / 'share/raw/fx/dlc5/zmb_weapon/fx_staff_charge_souls.efx')
    if len(ring) != 2 or len(souls) != 6:
        raise ValueError('stock template files changed shape')
    base, core = ring[0], souls[1]
    for need in ('orientedSprite', '"gfx_ui_ring_thin"', 'runRelToEffect', 'editorFlags looping'):
        if need not in base:
            raise ValueError('ring template lost ' + need)
    for need in ('billboardSprite', 'runRelToEffect', 'editorFlags looping'):
        if need not in core:
            raise ValueError('mote template lost ' + need)
    for t in (base, core):
        for empty in ('fxOnImpact "";', 'fxOnDeath "";', 'emission "";'):
            if empty not in t:
                raise ValueError('a template spawns a child effect: ' + empty)
    w = RING_W * radius
    els = []
    for k in range(RIM_COPIES):   # the crisp line, ON the radius
        els.append(oriented(base, 'aura_rim_%d' % k, 'gfx_ui_ring_thin', w,
                            triangle(0.50), GREEN_RIM, 30.0 * k, 250, 500))
    for k in range(RIM_COPIES):   # its soft glow, 4% wider
        els.append(oriented(base, 'aura_rim_glow_%d' % k, 'gfx_ui_ring_thin', w * 1.04,
                            triangle(0.20), GREEN_GLOW, 30.0 * k + 15.0, 250, 500))
    els.append(oriented(base, 'aura_fill', 'gfx_light_bokeh_soft_em', DISC_W * radius,
                        triangle(0.16), GREEN_FILL, 0.0, 250, 500))
    pulse_size = [(0.0, 0.06), (0.25, 0.55), (0.5, 0.82), (0.75, 0.95), (1.0, 1.0)]
    pulse_alpha = [(0.0, 0.0), (0.08, 0.45), (0.55, 0.40), (1.0, 0.0)]
    for k in range(RIM_COPIES):   # the heal pulse, caster -> rim each second
        els.append(oriented(base, 'aura_pulse_%d' % k, 'gfx_ui_ring_thin', w,
                            pulse_alpha, GREEN_PULSE, 30.0 * k, 1000, 900, pulse_size))
    els.append(mote(core, 'aura_rim_sparks', radius, 0.0, 2.0, 8.0, 12, 520, 200, 9.0, -3.0, GREEN_RIM))
    els.append(mote(core, 'aura_motes', 0.0, radius * 0.92, 2.0, 6.0, 28, 1100, 400, 7.0, -5.0, GREEN_PULSE))
    return 'iwfx 2\n\n' + '\n'.join('{\n' + e.rstrip() + '\n' for e in els)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--tools', type=Path, default=DEFAULT_TOOLS)
    args = parser.parse_args()
    bad = []
    for r in RADII:
        target = OUT_DIR / (NAME.format(r) + '.efx')
        expected = render(args.tools, r)
        if args.check:
            if not target.exists() or target.read_text(encoding='utf-8') != expected:
                bad.append(target.name)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(expected, encoding='utf-8', newline='\n')
            print(f'Wrote {target.relative_to(ROOT)} ({len(expected)} bytes, {expected.count(chr(10) + "{" + chr(10))} elements)')
    if args.check:
        if bad:
            raise SystemExit('Healing Aura area FX differ (' + ', '.join(bad) + '); run tools/gen_heal_area_fx.py')
        # LOCKSTEP with the script and the zone: every radius the aura can cast at
        # has its effect precached, registered and zoned - a missing one would draw
        # nothing for that level, silently.
        gsc = (ROOT / 'scripts/zm/zm_tower_of_doom/_tod_mage_elements.gsc').read_text(encoding='utf-8')
        zone = (ROOT / 'zone_source/zm_tower_of_doom.zone').read_text(encoding='utf-8')
        m = re.search(r'function heal_radius\( lv \)\s*\{.*?array\(([^)]*)\)', gsc, re.S)
        radii = tuple(int(v) for v in m.group(1).split(',')) if m else ()
        if radii != RADII:
            raise SystemExit('heal_radius() radii %s != the area FX radii %s' % (radii, RADII))
        m = re.search(r'foreach \( r in array\(([^)]*)\) \)\s*// LOCKSTEP: heal_radius\(\)', gsc)
        if not m or tuple(int(v) for v in m.group(1).split(',')) != RADII:
            raise SystemExit('_tod_mage_elements init() must register level._effect for every area radius')
        for r in RADII:
            fx = 'tod/mage/' + NAME.format(r)
            if ('#precache( "fx", "%s" );' % fx) not in gsc:
                raise SystemExit('missing #precache for ' + fx)
            if ('\nfx,%s' % fx) not in zone.replace('\r\n', '\n'):
                raise SystemExit('missing zone line fx,' + fx)
        if 'healing_aura_ring' in gsc or 'healing_aura_ring' in zone:
            raise SystemExit('the retired v19.68 ring effect is still referenced')
        print('Healing Aura area FX verified: %d radii (%s), each rim x%d + glow x%d + fill + pulse x%d + 2 mote loops, all looping, no light/child.'
              % (len(RADII), '/'.join(map(str, RADII)), RIM_COPIES, RIM_COPIES, RIM_COPIES))


if __name__ == '__main__':
    main()
