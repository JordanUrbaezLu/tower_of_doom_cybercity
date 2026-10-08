"""THE RISING-DIRT EFFECTS, THINNED (v19.76).

Lead tester Nikolai, Oct 2026: "the smoke/dust visual effects generated when zombies
emerge from the floor are too dense, severely reducing visibility. On Tower 1 and
Tower 2, fast-spawning zombies create a cumulative smoke effect that completely
obscures the screen ... Suggested Fix: Tone down the opacity and visual lifetime of
the spawn smoke/dust".

Stock plays THREE effects per rising zombie (_zm.csc init_riser_fx +
zombie_rise_fx; _zm.gsc init_fx + _zm_spawner zombie_rise_dust_fx):
  rise_burst  zombie/fx_spawn_dirt_hand_burst_zmb       once, as the hands break the floor
              (a smoke whisp 240 wide that lives 3 - 4 s, two 220-261 dust clouds)
  rise_billow zombie/fx_spawn_dirt_body_billowing_zmb   once, as the body comes up
              (a looping smoke puff 120 wide, 1.5 - 2.5 s; a one-shot puff 160, 2 - 2.5 s)
  rise_dust   zombie/fx_spawn_dirt_body_dustfalling_zmb EVERY 0.3 s FOR UP TO 5.5 s, and
              BOTH the client and the server run that loop - ~36 dust plays a zombie
At the spire's 0.12 s trial trickle that is a standing cloud.

This writes map-owned copies under share/raw/fx/tod/zombie/ - every donor element
kept, verbatim, except the smoke and dust ones, which keep a fraction of their
opacity and lifetime (the shared helpers of build_bo6_ice_fx.py: scale_alpha scales
the alpha CURVE's values, scale_life both lifeSpanMsec numbers). Rock gibs, debris
spikes and models are untouched, so a zombie still visibly tears out of the floor.
zm_tower_of_doom.csc / .gsc point level._effect["rise_*"] at these after
zm_usermap::main().

Run:  python tools/gen_tod_riser_fx.py           (writes the three .efx + manifest)
      python tools/gen_tod_riser_fx.py --check   (build gate: hashes of donors + outputs)
"""
import hashlib
import json
from pathlib import Path
import re
import sys

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'tools' / 'bo6_extraction'))
from build_bo6_ice_fx import blocks, block_name, child_refs, rescale, scale_alpha, scale_life  # noqa: E402

TOOLS_FX = Path(r'C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130\share\raw\fx')
OUT = REPO / 'share' / 'raw' / 'fx' / 'tod' / 'zombie'
MANIFEST = REPO / 'tools' / 'gen_tod_riser_fx.manifest.json'

SMOKE = {'alpha': 0.3, 'life': 0.5}            # smoke whisps / puffs: the cloud
DUST = {'alpha': 0.5, 'life': 0.6}             # dust falls / clumps / spikes: the haze

# (output name, donor, { element: edits }) - elements not listed are copied verbatim
RECIPES = [
    ('fx_tod_rise_burst', 'zombie/fx_spawn_dirt_hand_burst_zmb.efx', {
        'wraith_oneshot_def0': dict(SMOKE, scale=0.7),   # gfx_smk_whisp 240, 3 - 4 s
        'wraith_oneshot_def2': DUST,                     # gfx_dust_fall_lg 261
        'wraith_oneshot_def3': DUST,                     # gfx_dust_fall_lg 90
        'wraith_oneshot_def4': DUST,                     # gfx_dust_clump 220
        'wraith_oneshot_def7': DUST,                     # gfx_dust_clump 130
        'wraith_oneshot_def8': DUST,                     # gfx_dust_clump 90
        'wraith_oneshot_def9': DUST,                     # gfx_dust_clump 170
    }),
    ('fx_tod_rise_billow', 'zombie/fx_spawn_dirt_body_billowing_zmb.efx', {
        'wraith_looping_def0': SMOKE,                    # gfx_smk_puff_volume 120, looping
        'wraith_looping_def4': {'alpha': 0.6},           # gfx_dust_spike 40
        'wraith_looping_def6': {'alpha': 0.6},           # gfx_dust_spike 70
        'wraith_oneshot_def0': dict(SMOKE, scale=0.75),  # gfx_smk_puff_light 160, 2 - 2.5 s
    }),
    ('fx_tod_rise_dust', 'zombie/fx_spawn_dirt_body_dustfalling_zmb.efx', {
        'wraith_oneshot_def0': DUST,                     # gfx_dust_clump 60
        'wraith_oneshot_def2': {'alpha': 0.35, 'life': 0.6},   # gfx_smk_whisp 110
        'wraith_oneshot_def3': DUST,                     # gfx_dust_clump 60
        'wraith_oneshot_def4': {'alpha': 0.35, 'life': 0.6},   # gfx_smk_whisp 110
    }),
]


def sha(b):
    return hashlib.sha256(b).hexdigest()


def compose(out_name, donor_rel, edits):
    src = TOOLS_FX / donor_rel
    raw = src.read_bytes()
    text = raw.decode('latin1').replace('\r', '')
    assert text.startswith(('iwfx 2', 'iwfx 3')), src
    header = text[:text.index('{')].rstrip() + '\n\n'
    parts, seen = [], set()
    for b in blocks(text):
        n = block_name(b)
        # A child reference is kept only if its source exists in the tools, so the
        # linker can pull it in with the parent (the hand burst's gib model lands with
        # player/fx_plyr_footstep_dust - stock's own, loaded by every ZM map).
        for ref in child_refs(b):
            assert (TOOLS_FX / (ref.strip() + '.efx')).is_file(), (donor_rel, n, 'child effect missing from the tools', ref)
        e = edits.get(n)
        if e:
            seen.add(n)
            if e.get('scale', 1.0) != 1.0:
                b = rescale(b, e['scale'])
            if 'alpha' in e:
                b = scale_alpha(b, e['alpha'])
            if 'life' in e:
                b = scale_life(b, e['life'])
        parts.append(b)
    missing = set(edits) - seen
    assert not missing, (donor_rel, 'donor elements not found', sorted(missing))
    # CRLF, like every stock .efx (the donors are read with the \r stripped)
    body = (header + '\n\n'.join(parts) + '\n').replace('\n', '\r\n').encode('latin1')
    return body, sha(raw), len(parts)


def main():
    check = '--check' in sys.argv
    result = {}
    for out_name, donor, edits in RECIPES:
        body, donor_sha, n = compose(out_name, donor, edits)
        result[out_name] = dict(donor=donor, donor_sha256=donor_sha, sha256=sha(body), elements=n,
                                edited=sorted(edits))
        if not check:
            OUT.mkdir(parents=True, exist_ok=True)
            (OUT / (out_name + '.efx')).write_bytes(body)
    if check:
        man = json.loads(MANIFEST.read_text(encoding='utf-8'))
        bad = []
        for k, v in result.items():
            p = OUT / (k + '.efx')
            if not p.is_file():
                bad.append('missing ' + str(p))
            elif sha(p.read_bytes()) != man[k]['sha256'] or v['sha256'] != man[k]['sha256']:
                bad.append(k + ': output drifted from the recipe or the manifest (re-run without --check)')
            if v['donor_sha256'] != man[k]['donor_sha256']:
                bad.append(k + ': the stock donor changed under us: ' + v['donor'])
        if bad:
            for b in bad:
                print('RISER FX CHECK FAIL: ' + b)
            sys.exit(1)
        print('riser fx: %d thinned copies match their recipes and pinned donors' % len(result))
        return
    MANIFEST.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    for k, v in result.items():
        print('FX %s: %d elements, %d thinned' % (k, v['elements'], len(v['edited'])))


if __name__ == '__main__':
    main()
