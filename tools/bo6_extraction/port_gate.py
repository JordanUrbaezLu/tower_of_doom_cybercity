"""BO6 migration ledger: complete means source coverage AND native evidence.

`init NAME --kind enemy|weapon` creates every mandatory workstream. `check`
fails incomplete ports; --development permits iteration but never prints COMPLETE.
Evidence pins bytes, including the tested build, so regeneration invalidates it.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

REPO = Path(__file__).resolve().parents[2]
LEDGERS = REPO / 'docs/bo6_ports'
COMMON = {
    'discovery': 'Source variant, dependencies, unresolved hashes and reference behavior inventoried; discovery reviewed beyond currently exported files.',
    'geometry': 'Every visible component, skin, attachment, UV/color layer, weights, skeleton, tags and LOD disposition accounted for.',
    'materials': 'Original color/alpha, normal orientation, gloss/roughness, metal/specular, AO, emissive, detail masks/layers, transparency and tint reproduced; neutral-light native comparison.',
    'animations': 'All applicable motion states, transitions, loops, speeds, root motion and notification timing wired; frame AND weighted-mesh validation.',
    'audio': 'All event families and variations including secondary aliases identified, converted, triggered and listened to; loops/spatialization and interruption cleanup checked.',
    'fx': 'Idle/charged/attack/impact/damage/death effects, lights, trails, sockets, color and lifecycle reproduced in first/third person as applicable.',
    'behavior': 'All source abilities and state transitions implemented, including timing, targeting, damage and recovery; BO3 balance changes explicitly recorded.',
    'integration': 'Spawn/equip, progression, HUD/inventory icons and names, keyboard/controller prompts, pause, switch, down/death, cleanup, collision and solo/co-op behavior checked without regressions.',
    'native': 'Fresh deployed build and banks match; actual map load, visual comparison, listening, actions and lifecycle evidence preserved for this exact implementation.',
}
DETAILS = {
    'weapon': {
        'animations': 'Equip/first raise/idle/move/sprint/tactical sprint/jump/fall/land/slide/mantle/crawl/putaway, every melee/combo/hit/miss, guard/parry and special/charge/recovery; first and third person.',
        'audio': 'Equip/putaway/swing/hit/miss/surface impact/guard/parry/charge ready/windup/release/projectile flight/impact/idle loop; player/NPC variants.',
        'behavior': 'Primary/combo, reach/hit window, block/parry arc/timing, special activation/resource/volley/burn, cancellation, upgrade and inventory restoration.',
    },
    'enemy': {
        'animations': 'Spawn/idle/walk/run/sprint/turn/juke, every attack/windup/recovery, hit/stagger/armor break/ability/death variant; locomotion restores after attacks.',
        'audio': 'Spawn/idle/aggro/voice/breath/footsteps/sprint/attack/windup/contact/hit/stagger/armor/ability/death; layers, distance, variations and loops.',
        'behavior': 'Detection/pursuit/speed/erratic paths, each melee/ranged/special, reach/LOS, grab/release, armor/regrowth/stagger/death behavior and replacement.',
    },
}
STATES = {'pending', 'implemented', 'verified', 'adapted', 'unavailable', 'not_applicable'}


def digest(path):
    with path.open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()


def create(name, kind):
    if not re.fullmatch(r'[a-z0-9_]+', name):
        raise ValueError('Use lowercase letters, digits and underscores for the port ID')
    return dict(schema=1, id=name, kind=kind, source_game='BO6',
        intent='Complete migration; never silently reduce to mesh-only scope',
        workstreams={key: dict(status='pending', requirement=value + ' ' + DETAILS[kind].get(key, ''),
            findings='', items=[], evidence=[]) for key, value in COMMON.items()})


def evidence_errors(evidence, prefix):
    errors = []
    if not evidence:
        return [prefix + ': no evidence']
    for item in evidence:
        path = REPO / item.get('path', '')
        if not path.is_file():
            errors.append(prefix + ': missing evidence ' + str(path))
        elif digest(path) != item.get('sha256'):
            errors.append(prefix + ': stale/unpinned evidence ' + str(path))
        elif item.get('kind') == 'implementation':
            snapshot = json.loads(path.read_text(encoding='utf-8'))
            files = snapshot.get('files', snapshot.get('files_checked', []))
            if not isinstance(files, list) or not files:
                errors.append(prefix + ': implementation evidence needs an explicit files array')
            else:
                for source in files:
                    target = REPO / source.get('path', source.get('source', ''))
                    if not target.is_file() or digest(target) != source.get('sha256'):
                        errors.append(prefix + ': implementation changed since test: ' + str(target))
    return errors


def inspect(data):
    errors, gaps = [], []
    if data.get('schema') != 1 or data.get('kind') not in DETAILS:
        return ['Invalid ledger schema/kind'], []
    streams = data.get('workstreams', {})
    if set(streams) != set(COMMON):
        errors.append('Missing or unknown workstreams: ' + str(set(streams) ^ set(COMMON)))
    for key in COMMON:
        row = streams.get(key, {})
        status = row.get('status')
        if status not in STATES:
            errors.append(key + ': invalid status')
            continue
        if status not in ('verified', 'not_applicable'):
            gaps.append(key + ': ' + status + ' - ' + row.get('findings', ''))
            continue
        # An umbrella checkbox cannot cover an empty, unreviewed inventory.
        if not row.get('findings') or not row.get('items'):
            errors.append(key + ': completed workstream needs findings and individual inventory items')
        errors += evidence_errors(row.get('evidence'), key)
        for item in row.get('items', []):
            label = key + '/' + item.get('id', '?')
            if item.get('status') not in ('verified', 'not_applicable'):
                gaps.append(label + ': unresolved, adapted or unverified')
            else:
                if not item.get('disposition'):
                    errors.append(label + ': missing source-to-runtime disposition')
                errors += evidence_errors(item.get('evidence'), label)
        if key == 'native' and status == 'verified':
            required = {'build', 'deployment', 'console', 'visual', 'listening', 'behavior', 'lifecycle', 'implementation'}
            kinds = {e.get('kind') for e in row.get('evidence', [])}
            if not required <= kinds:
                errors.append('native: missing evidence kinds ' + str(sorted(required-kinds)))
        if status == 'not_applicable' and key in ('discovery', 'geometry', 'materials', 'native'):
            errors.append(key + ': cannot be waived for a visible BO6 enemy/weapon')
    return errors, gaps


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest='command', required=True)
    init = sub.add_parser('init')
    init.add_argument('name')
    init.add_argument('--kind', choices=DETAILS, required=True)
    check = sub.add_parser('check')
    check.add_argument('--development', action='store_true')
    check.add_argument('--manifest', type=Path)
    check.add_argument('--output', type=Path)
    args = p.parse_args()
    if args.command == 'init':
        data = create(args.name, args.kind)
        LEDGERS.mkdir(parents=True, exist_ok=True)
        path = LEDGERS / (args.name + '.json')
        with path.open('x', encoding='utf-8') as handle:
            json.dump(data, handle, indent=2)
        print('Created ' + str(path) + '; all workstreams remain open.')
        return 0
    reports = []
    paths = [args.manifest] if args.manifest else sorted(LEDGERS.glob('*.json'))
    if not paths:
        print('FAIL: no registered BO6 ports')
        return 1
    for path in paths:
        if not args.manifest and (path.name.endswith('_manifest.json') or path.parent.name == 'manifests'):
            # Skipped BY NAME / BY FOLDER, never by a missing field. Other tools
            # write JSON beside the ledgers (build_mangler_variants.py wrote
            # mangler_variants_manifest.json here on 2026-09-12; it now writes
            # manifests/mangler_variants.json) and a manifest judged as a ledger
            # failed EVERY build on the machine as "None: 1 invalid". An absence
            # rule ("no 'id' -> skip") would also swallow a truncated or
            # hand-broken ledger with a reassuring line; a ledger that loses its
            # id must still fail loudly below. Today the glob is non-recursive,
            # so the manifests/ folder is never scanned; the folder test keeps
            # this skip correct if that ever changes. Every skip is printed.
            print(f"[BO6 PORT] skip {path.relative_to(LEDGERS)}: a manifest, not a port ledger")
            continue
        data = json.loads(path.read_text(encoding='utf-8'))
        errors, gaps = inspect(data)
        complete = not errors and not gaps
        reports.append(dict(port=data.get('id'), complete=complete, errors=errors, gaps=gaps))
        print(f"[BO6 PORT] {data.get('id')}: {'COMPLETE' if complete else 'INCOMPLETE'} ({len(gaps)} open, {len(errors)} invalid)")
        if not args.development:
            for message in errors+gaps:
                print('  ' + message)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(reports, indent=2), encoding='utf-8')
    return int(any(r['errors'] or (r['gaps'] and not args.development) for r in reports))


if __name__ == '__main__':
    raise SystemExit(main())
