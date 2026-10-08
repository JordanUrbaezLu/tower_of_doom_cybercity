"""Author the Rampage Inducer's two glow effects from an existing donor.

USER, 2026-09-13, on seeing the ported BO6 inducer in game: *"it's not really
glowing ... it needs to glow a dim orange of some sort. And then when it's on,
it needs to pulse a deeper orange. And that's the indicator that it's on. But
when it's off, it just has, like, a dim kinda lamp, orange light lamp."*

TWO EFFECTS, one donor:
  fx_tod_inducer_idle  OFF - a dim, STEADY orange lamp. Always on, from spawn.
  fx_tod_inducer_on    ON  - a deeper, hotter orange that PULSES.

DONOR: share/raw/fx/acc/light/fx_perk_glow_amber.efx, one of map 1's
self-authored perk-machine auras. It is the right donor for three reasons: it
already carries a real dynamic light (`light_small`, intensity 512 / radius 60),
that light is already `editorFlags looping` with `spawnLooping 200` over a
1,000 ms life so it re-spawns forever, and its `lightIntensityGraph` is already
a two-hump curve - so a pulse is a matter of RESHAPING a curve that exists, not
inventing one. Reuse over authoring (memory reuse-over-authoring).

v18.99j: ONLY `light_small` survives - the model glows through its own emissive
materials now (install_inducer_bo3.py) and this effect is just the light it throws
on the floor. The sprite notes below describe the v18.99i shape and are kept for
the record; `sprite_scale` / `alpha_flat` are inert while the sprite is dropped.

WHAT IS CHANGED, and nothing else:
- Only the `glow` sprite and the `light_small` dynamic light are kept. The
  donor's `exp` and `glow_spikes` elements are DROPPED: they are burst shapes
  that read as an explosion on a prop that is supposed to sit there like a lamp.
- Every colorGraph key is retinted to the target orange, keeping its time.
- lightIntensityGraph's base and curve are replaced outright - flat for idle,
  a single clean 0.30 -> 1.00 -> 0.30 hump per second for the ON pulse.
- alphaGraph is flattened for idle so the sprite does not shimmer.

SERVER-SIDE PLAYFX IS VALID HERE because both effects LOOP; a non-looping FX
played from the server renders nothing (memory ambient-fx-server-loop-lane).

Both need a `fx,tod/fx_tod_inducer_*` line in the .zone or they silently never
play. Run: python tools/gen_tod_inducer_fx.py
"""
import io
from pathlib import Path
import re

REPO = Path(__file__).resolve().parents[1]
DONOR = REPO/'share/raw/fx/acc/light/fx_perk_glow_amber.efx'
OUT_DIR = REPO/'share/raw/fx/tod'

# v18.99j (user: "not like the perk glow ... I want just a model with a glow on
# it"): the sprite is GONE. The model glows through its own emissive materials
# now (install_inducer_bo3.py); this effect is only the dynamic LIGHT that puts
# orange on the floor and walls around the device, steady when off, pulsing on.
KEEP = ('light_small',)

# The donor spawns its light 40 units above the host, which was right for a
# perk machine. 18 sat inside the BO6 canister's glass cylinder; since
# 2026-10-02 the device is the 67-tall cyber inducer and 35 is its levitating
# crystal (tools/inducer_cyber/anim_spec.py j_crystal pivot 35.6), so the
# lamp throws the crystal's light on the floor and the wall behind it.
SPAWN_Z = 35

# Linear RGB, matched to the prop's own aether-orange interior.
IDLE_COLOR = (1.0, 0.42, 0.10)      # a warm lamp
ON_COLOR = (1.0, 0.26, 0.03)        # deeper, hotter

VARIANTS = {
    'fx_tod_inducer_idle': dict(
        color=IDLE_COLOR,
        light_base=120,             # v18.99k: dimmer still - OFF must read dark next to ON
        light_curve=[(0, 1.0), (1, 1.0)],          # dead steady
        alpha_flat=True,
        sprite_scale=0.55,
    ),
    'fx_tod_inducer_on': dict(
        color=ON_COLOR,
        light_base=1500,            # v18.99k: 900 -> 1500, the ON tell on the floor
        light_curve=[(0, 0.30), (0.5, 1.0), (1, 0.30)],   # one hump per second
        alpha_flat=False,
        sprite_scale=1.0,
    ),
}


def split_elements(text):
    head, *rest = re.split(r'\n\{\n\tname "', text)
    return head, ['\n{\n\tname "' + r for r in rest]


def element_name(block):
    return block.split('"')[1]


def replace_graph(block, key, base, curve):
    """Replace `key <base> { {curve} {curve} };` with our own, both curves."""
    start = block.find('\n\t' + key + ' ')
    assert start >= 0, key
    end = block.index(';', start)
    rows = '\n'.join(f'\t\t\t{t} {v}' for t, v in curve)
    body = '\t\t{\n' + rows + '\n\t\t}\n'
    return block[:start] + f'\n\t{key} {base}\n\t{{\n' + body + body + '\t}' + block[end:]


def retint(block, color):
    r, g, b = color

    def row(m):
        return f'{m.group(1)} {r} {g} {b}'
    # colorGraph rows are `<time> <r> <g> <b>` on their own line.
    out, inside = [], False
    for line in block.split('\n'):
        stripped = line.strip()
        if stripped.startswith('colorGraph'):
            inside = True
        elif inside and stripped.endswith(';'):
            inside = False
        if inside:
            line = re.sub(r'^(\s*[-\d.]+)\s+[-\d.]+\s+[-\d.]+\s+[-\d.]+$', row, line)
        out.append(line)
    return '\n'.join(out)


def flatten_alpha(block):
    start = block.find('\n\talphaGraph ')
    if start < 0:
        return block
    end = block.index(';', start)
    body = '\t\t{\n\t\t\t0 1\n\t\t\t1 1\n\t\t}\n'
    return block[:start] + '\n\talphaGraph 1\n\t{\n' + body + body + '\t}' + block[end:]


def scale_sprite(block, factor):
    start = block.find('\n\tscaleGraph ')
    if start < 0:
        return block
    m = re.match(r'\n\tscaleGraph ([\d.]+)', block[start:])
    assert m, 'scaleGraph base'
    return block[:start] + f'\n\tscaleGraph {round(float(m.group(1)) * factor, 3)}' \
        + block[start + m.end():]


def main():
    donor = io.open(DONOR, encoding='utf-8', errors='surrogateescape').read()
    head, blocks = split_elements(donor)
    kept = [b for b in blocks if element_name(b) in KEEP]
    assert len(kept) == len(KEEP), [element_name(b) for b in blocks]

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, spec in VARIANTS.items():
        out = [head.rstrip('\n')]
        for block in kept:
            block = retint(block, spec['color'])
            block = re.sub(r'\n\tspawnOrgZ [-\d.]+ ', f'\n\tspawnOrgZ {SPAWN_Z} ', block, count=1)
            if element_name(block) == 'light_small':
                block = replace_graph(block, 'lightIntensityGraph',
                                      spec['light_base'], spec['light_curve'])
            out.append(block.rstrip('\n'))
        path = OUT_DIR/f'{name}.efx'
        io.open(path, 'w', encoding='utf-8', errors='surrogateescape',
                newline='\n').write('\n'.join(out) + '\n')
        print(f'wrote {path}  elements={len(kept)} color={spec["color"]} '
              f'light={spec["light_base"]}')


main()
