"""Record the v18.89 BINDING in docs/bo6_ports/ice_staff.json.

Run after install_ice_staff_bo3.py. It rewrites statuses/dispositions to what
the install actually did (implemented / adapted / unavailable / pending) and
pins the install manifest as `binding` evidence. It never marks anything
`verified`: that word is reserved for native evidence.
"""
import hashlib
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
LEDGER = REPO/'docs/bo6_ports/ice_staff.json'
INSTALL = 'docs/bo6_ports/manifests/ice_staff_bo3_install.json'
SOURCES = REPO/'docs/bo6_ports/manifests/ice_staff_sources.json'


def sha(rel):
    return hashlib.sha256((REPO/rel).read_bytes()).hexdigest()


def evidence(rel, kind):
    return dict(path=rel, sha256=sha(rel), kind=kind)


def main():
    d = json.loads(LEDGER.read_text())
    inst = json.loads((REPO/INSTALL).read_text())
    W = d['workstreams']

    def setws(key, status, findings, extra_evidence=True, replace_evidence=None):
        W[key]['status'] = status
        W[key]['findings'] = findings
        if replace_evidence is not None:
            W[key]['evidence'] = replace_evidence
        elif extra_evidence:
            W[key]['evidence'] = [e for e in W[key].get('evidence', []) if e.get('path') != INSTALL]+[evidence(INSTALL, 'binding')]

    setws('discovery', 'pending',
          'Sources acquired and the assembly BOUND (v18.89): both models, six materials and 14 sounds are Cybercity assets now. '
          'Still open: a neutral-light BO6 reference capture for comparison, the BO6 vfx (zero rows in the 408,004-asset index) '
          'and 37 unresolved hashed alias names.')
    for it in W['discovery']['items']:
        if it['id'] == 'audio_aliases':
            it.update(status='adapted', disposition='The 18 FNV-recovered names cover every handling/fire cue the BO3 weapon has a slot for; those are bound. 37 hashed aliases stay unbound: identity unknown, not guessed.')
        if it['id'] == 'world_body':
            it.update(status='implemented', disposition='Both assemblies converted to tod_bo6_ice_vm / tod_bo6_ice_wm (77 bones incl. tag_bo6_glow) and BOUND to tod_staff_ice + q0/q1; native look pending.')

    setws('geometry', 'implemented',
          'vm/wm assemblies bound as tod_bo6_ice_vm / tod_bo6_ice_wm: root j_gun -> tag_weapon, view aligned to the donor hands '
          '(residuals 0.29 in), world shifted +11.67 and rotated X->Z onto the donor world axis (muzzle 2.1 in from the donor). '
          'LOD1-4 source Casts are not bound: BO3 autogen LODs. Native check pending.')
    for it in W['geometry']['items']:
        if it['id'].endswith('_LOD0') and 'dreward' not in it['id']:
            it.update(status='implemented', disposition='LOD0 source of the bound assembly (install manifest pins the .xmodel_bin). Native look pending.')
        else:
            it.update(status='adapted', disposition='Not bound: the BO3 xmodel autogenerates LODs from LOD0; dreward variants are the same meshes.')

    setws('materials', 'implemented',
          'Six private materials bound (mtl_tod_bo6_ice_<hash>): original color, decoded NOG (normal/gloss/AO), the four emission-color '
          'maps on lit_emissive_plus at scaleRGB 6 (a first native tuning value, not a recovered constant). Layered masks, '
          'scroll/distortion, metal/specular and exact emission intensity remain unrecovered.')
    for it in W['materials']['items']:
        it.update(status='implemented', disposition='Bound to the vm AND wm meshes (world textures are byte-identical to view). Base streams only; native shading review pending.')

    setws('animations', 'adapted',
          'ALL 116 BO6 clips stay unbound by design: they carry local quaternions and no skeleton, so they can only be read against '
          'the BO6 arm rest pose, which was never exported (the Tower II Saug finding). The held motion is the fitted Origins set '
          'and the BO6 model is aligned to that donor grip.')
    for it in W['animations']['items']:
        it.update(status='adapted', disposition='Donor motion (fitted Origins clip) retained; BO6 clip unbound pending an exported BO6 arm rest pose.')

    bound = {}
    for s in inst['sounds']:
        stem = s['bo6_source'].replace('\\', '/').split('/')[-1].removesuffix('.wav')
        bound[stem] = s
    src = json.loads(SOURCES.read_text())['sounds']
    setws('audio', 'implemented',
          '14 payloads bound through 25 tod_ports.csv rows (5 base-fire variants + 5 tails, pullout, putaway, first raise, reload), '
          'trimmed/level-matched per the install manifest. Charged-attack payloads excluded by scope; inspect/alt-mode payloads have '
          'no BO3 slot; 37 hashed payloads unbound (identity unknown). Mix settings are BO3 rows cloned from the existing staff '
          'aliases, not BO6 settings. Listening pending.')
    for it in W['audio']['items']:
        stem = it['id'].split('/')[-1]
        aliases = src.get(it['id'], {}).get('resolved_aliases', [])
        hit = bound.get(stem) or next((v for k, v in bound.items() if k.startswith(stem) or stem.startswith(k)), None)
        if hit:
            it.update(status='implemented', disposition='Bound: %s (%s), trim %s s, gain %+.1f dB. Listening pending.' % (hit['output'], hit['bo6_alias'], hit['trim_s'], hit['gain_db']))
        elif any('charged' in a or 'claw' in a for a in aliases):
            it.update(status='not_applicable', disposition='Charged-attack cue; excluded by the user on 2026-09-13.')
        elif any(a.startswith('fly_ice_staff_') for a in aliases) or 'inspect' in stem or 'alt_' in stem:
            it.update(status='adapted', disposition='Inspect / alt-mode / quick cue: no BO3 weapon slot for it; not bound.')
        elif any(a.startswith('wpn_ice_staff_upg_') for a in aliases):
            it.update(status='adapted', disposition='BO6 upgraded-staff fire; Cybercity packs by tier and reuses the base-fire set. Not bound.')
        elif 'akilo' in stem:
            it.update(status='adapted', disposition='LFE layer; the BO3 rows here carry no LFE routing. Not bound.')
        else:
            it.update(status='pending', disposition='Exported and validated; alias identity still a hash, so unbound.')

    setws('fx', 'adapted',
          'BO3 effects retained on the BO6 model: muzzle tod/fx_tod_ice_muzzle_1p/3p at tag_flash (present on the assembly), '
          'trail/impact unchanged (projectile-side), glow dlc5 fx_staff_ice_persistent moved to the private tag_bo6_glow socket in '
          'the tip crystal (CSC per-element tag). BO6 vfx data was not in the export index; the cue-driven first-raise/reload/inspect '
          'effects are unavailable.')
    for it in W['fx']['items']:
        if it['status'] == 'not_applicable':
            continue
        if it['id'] in ('first_raise_top', 'reload_center', 'reload_bursts', 'inspect_top', 'inspect_mid'):
            it.update(status='unavailable', disposition='Cue discovered; BO6 particle data not exported.')
        else:
            it.update(status='adapted', disposition='Existing BO3 effect retained on the BO6 assembly; native look pending.')

    setws('integration', 'implemented',
          'tod_staff_ice + generated q0/q1 bound (gunModel/worldModel/sounds; attach tip and hideTags cleared), twins regenerated, '
          'verify_staff_animations runs the install --check on every build, sync copies model_export/tod_bo6_ice. Equip/switch, '
          'down/death and co-op checks await the native run.', replace_evidence=[evidence(INSTALL, 'binding')])
    for it in W['integration']['items']:
        if it['id'] in ('private_ice_assets', 'base_ice_weapon', 'q0', 'q1'):
            it.update(status='implemented', disposition='Bound via tools/bo6_extraction/install_ice_staff_bo3.py + gen_tod_twins.js; native pending.')
        elif it['id'] == 'hud_icons':
            it.update(status='adapted', disposition='Cybercity keeps its own drawn staff icons (docs/128); the BO6 weapon icon is not ported.')
        else:
            it.update(status='pending', disposition='Native run required.')

    setws('native', 'pending',
          'Full build started 2026-09-13 after the binding; deployment / map load / visual / listening / behavior / lifecycle '
          'evidence still to be captured.', extra_evidence=False)
    LEDGER.write_text(json.dumps(d, indent=2)+'\n')
    print('ledger: binding recorded')


if __name__ == '__main__':
    main()
