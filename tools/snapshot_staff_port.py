"""Preserve the current staff sources and deployed Tower payload before porting.

Snapshots are immutable ZIPs plus SHA256 manifests outside build inputs. This
does not restore files automatically: shared GDT/scripts may receive unrelated
edits later, so restoration must select only the port's changed entries.
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def digest_file(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def archive(destination, entries):
    records = []
    with zipfile.ZipFile(destination, 'x', compression=zipfile.ZIP_STORED) as output:
        for name, path in sorted(entries.items()):
            before = digest_file(path)
            output.write(path, name)
            if digest_file(path) != before:
                raise RuntimeError(f'Source changed during snapshot: {path}')
            records.append({'entry': name, 'source': str(path),
                            'bytes': path.stat().st_size, 'sha256': before})
    with zipfile.ZipFile(destination) as saved:
        for row in records:
            with saved.open(row['entry']) as stream:
                actual = hashlib.file_digest(stream, 'sha256').hexdigest()
            if actual != row['sha256']:
                raise RuntimeError(f'Snapshot verification failed: {row["entry"]}')
    return records


def collect(entries, root, pattern, prefix):
    for path in root.glob(pattern):
        if path.is_file():
            entries[prefix + '/' + path.relative_to(root).as_posix()] = path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--modtools', type=Path, required=True)
    args = parser.parse_args()
    modtools = args.modtools.resolve()
    if not (modtools / 'bin/modlauncher.exe').is_file():
        raise RuntimeError('Not a verified Mod Tools root')
    stamp = datetime.datetime.now().astimezone().strftime('%Y%m%d_%H%M%S')
    destination = ROOT / 'local_sync_cache/bo6_ice_staff' / stamp
    destination.mkdir(parents=True, exist_ok=False)
    sources = {}
    for pattern in (
        'source_data/*.gdt', 'scripts/**/*', 'zone_source/**/*',
        'gamedata/weapons/**/*', 'sound/aliases/*.csv', 'sound/zoneconfig/*',
        'sound_assets/tod/mage/**/*', 'share/raw/fx/tod/**/*',
        'model_export/tod_staff_anim/**/*', 'xanim_export/tod_staff_approved/**/*',
        'docs/staff_approved_manifest.json', 'tools/*staff*',
        'tools/gen_tod_twins.js', 'tools/sync_to_modtools.ps1',
        'tools/build_map.ps1', 'ui/**/*.lua',
        'source_data/tod_ui_images/_images/*mage*',
        'source_data/tod_ui_images/_images/*staff*',
    ):
        collect(sources, ROOT, pattern, 'repo')
    for pattern in ('model_export/sla/tod_staff/**/*',
                    'share/raw/fx/dlc5/zmb_weapon/fx_staff*'):
        collect(sources, modtools, pattern, 'modtools')
    print(f'Preserving {len(sources)} source files in {destination}', flush=True)
    source_records = archive(destination / 'sources.zip', sources)
    payload_root = modtools / 'usermaps/zm_tower_of_doom/zone'
    payload = {}
    collect(payload, payload_root, '**/*', 'zone')
    print(f'Preserving {len(payload)} deployed payload files', flush=True)
    payload_records = archive(destination / 'payload.zip', payload)
    manifest = {
        'created': datetime.datetime.now().astimezone().isoformat(),
        'purpose': 'Current BO3 staffs and pre-port Tower build rollback reference',
        'repo': str(ROOT), 'modtools': str(modtools),
        'sources': source_records, 'payload': payload_records,
        'verified': True,
        'restore_note': 'Select port changes only; do not overwrite subsequent unrelated work.',
    }
    (destination / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (destination / 'git_status_before.txt').write_bytes(subprocess.check_output(
        ['git', 'status', '--short'], cwd=ROOT))
    latest = destination.parent / 'baseline.txt'
    if not latest.exists():
        latest.write_text(str(destination) + '\n')
    print(json.dumps({'snapshot': str(destination), 'sources': len(source_records),
                      'payload_files': len(payload_records),
                      'payload_bytes': sum(r['bytes'] for r in payload_records),
                      'every_archived_sha256_verified': True}), flush=True)


if __name__ == '__main__':
    main()
