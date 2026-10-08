#!/usr/bin/env python3
"""Apply the reviewed size manifest, with staged conversion and guarded rollback.

python tools/optimize_tod_assets.py --prepare  # hashes, duplicates, stage all files
python tools/optimize_tod_assets.py --apply    # preflight every input, then install
python tools/optimize_tod_assets.py --verify   # confirm exact installed/repo output
python tools/optimize_tod_assets.py --restore # refuse to overwrite later edits
python tools/optimize_tod_assets.py --retire sky  # drop one CATEGORY from the pass: its sources are authored again
                                                  # (2026-09-13: the sky ships at its native 8192x4096 since v18.87)

Requires ffmpeg/ffprobe, Pillow, numpy. Optional local dependencies:
python -m pip install --target tmp/size_audit_deps Pillow numpy
Backups and staging live OUTSIDE all build/upload inputs; GDT backups use .before.
The manifest only targets measured assets; this is not a whole-installation cap.
Installed third-party sources can also be shared by other local maps.
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / 'tmp/size_audit_deps'))
BLOCK = re.compile(r'"([^"\r\n]+)"\s*\(\s*"([^"\r\n]+)\.gdf"\s*\)\s*\{(.*?)\n\s*\}', re.S)


def digest(p):
    with p.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def child(root, relative):
    p = (root / relative).resolve()
    if not p.is_relative_to(root.resolve()) or p == root.resolve():
        raise ValueError(f'Path escapes root: {relative}')
    return p


def run(args):
    return subprocess.run(args, check=True, capture_output=True).stdout


def probe(p):
    return json.loads(run(['ffprobe', '-v', 'error', '-select_streams', 'v:0',
                          '-show_entries', 'stream=width,height,pix_fmt', '-of', 'json', str(p)]))['streams'][0]


def save(p, data):
    p.parent.mkdir(parents=True, exist_ok=True)
    temp = p.with_suffix('.writing')
    temp.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    temp.replace(p)


def edit_gdt(raw, edits):
    text = raw.decode('utf-8')  # preserves a BOM, CRLF, and all untouched bytes
    seen = set()

    def block(m):
        body = m[0]
        for i, e in enumerate(edits):
            if (m[1], m[2]) != (e['asset'], e['kind']):
                continue
            pattern = re.compile(r'("' + re.escape(e['field']) + r'"\s+")([^"\r\n]*)(")')
            matches = list(pattern.finditer(body))
            if len(matches) != 1 or matches[0][2] not in (e['before'], e['after']):
                raise ValueError(f'GDT field changed/ambiguous: {e}')
            body = pattern.sub(lambda v: v[1] + e['after'] + v[3], body)
            if i in seen:
                raise ValueError(f'Duplicate GDT asset block: {e}')
            seen.add(i)
        return body

    text = BLOCK.sub(block, text)
    if len(seen) != len(edits):
        raise ValueError(f'Missing GDT edits: {[e for i,e in enumerate(edits) if i not in seen]}')
    return text.encode('utf-8')


def resize(source, output, row):
    from PIL import Image
    before = probe(source)
    scale = row['cap'] / max(before['width'], before['height'])
    if scale >= 1:
        raise ValueError(f'Expected a reduction: {row["source"]}')
    w, h = [max(1, round(before[k] * scale)) for k in ('width', 'height')]
    details = {'before': before, 'width': w, 'height': h}
    if row['category'] == 'sky':
        # Work in float planes, not swscale's integer intermediate. Never tone map.
        import numpy as np
        if before['width'] != w * 2 or before['height'] != h * 2:
            raise ValueError('Reviewed sky operation must be exactly 2:1')
        if before['pix_fmt'] != 'gbrapf16le':
            raise ValueError('Reviewed sky source must be RGBA half-float EXR')
        # Decode at the native half format: asking swscale for float32 first
        # quantizes faint lines through an integer intermediate on this ffmpeg.
        original = np.frombuffer(run(['ffmpeg', '-v', 'error', '-gamma', '1', '-i', str(source),
            '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'gbrapf16le', '-']), dtype='<f2').astype(np.float32)
        original = original.reshape(4, before['height'], before['width'])
        if not np.isfinite(original).all():
            raise ValueError('Non-finite HDR source')
        reduced = original.reshape(4, h, 2, w, 2).mean(axis=(2,4), dtype=np.float32)
        original_means = original.mean(axis=(1,2), dtype=np.float64)
        details['linear_mean_before_GBRA'] = original_means.tolist()
        details['linear_range_before'] = [float(original.min()), float(original.max())]
        del original
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pixel_format', 'gbrapf32le',
            '-video_size', f'{w}x{h}', '-i', '-', '-frames:v', '1', '-c:v', 'exr', '-pix_fmt', 'gbrapf32le',
            '-format', 'half', '-compression', 'zip16', '-gamma', '1', str(output)],
            input=reduced.tobytes(), check=True, capture_output=True)
        actual = np.frombuffer(run(['ffmpeg', '-v', 'error', '-gamma', '1', '-i', str(output),
            '-frames:v', '1', '-f', 'rawvideo', '-pix_fmt', 'gbrapf16le', '-']), dtype='<f2').astype(np.float32).reshape(4,h,w)
        # Half-float rounding is the only allowed change from the linear 2x2 mean.
        if not np.isfinite(actual).all() or not np.allclose(actual, reduced, rtol=0.001, atol=6e-8):
            raise ValueError('EXR lost linear HDR values')
        means = actual.mean(axis=(1,2), dtype=np.float64)
        if not np.allclose(means, original_means, rtol=0.001, atol=6e-8):
            raise ValueError('EXR changed average light energy')
        details['linear_mean_after_GBRA'] = means.tolist()
        details['linear_range_after'] = [float(actual.min()), float(actual.max())]
    else:
        pf = before['pix_fmt']
        if pf in ('pal8', 'monob', 'monow'):
            pf = 'rgba'
        if output.suffix.lower() in ('.tif', '.tiff') and pf.endswith('be'):
            pf = pf[:-2] + 'le'
        args = ['ffmpeg', '-v', 'error', '-y', '-i', str(source), '-vf', f'scale={w}:{h}:flags=area',
                '-frames:v', '1', '-pix_fmt', pf]
        if output.suffix.lower() in ('.tif', '.tiff'):
            args += ['-compression_algo', 'lzw']
        run(args + [str(output)])
        if row['category'] == 'constant':
            with Image.open(source) as a, Image.open(output) as b:
                old, new = a.convert('RGBA').getextrema(), b.convert('RGBA').getextrema()
                if old != new or any(lo != hi for lo, hi in old):
                    raise ValueError(f'Constant image changed: {row["source"]}')
            details['constant_RGBA'] = [lo for lo, hi in old]
    after = probe(output)
    if (after['width'], after['height']) != (w, h):
        raise ValueError(f'Unexpected output dimensions: {output}')
    details['after'] = after
    return details


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(r'C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130'))
    parser.add_argument('--manifest', type=Path, default=REPO / 'docs/size_optimization_manifest.json')
    parser.add_argument('--backup', type=Path)
    modes = parser.add_mutually_exclusive_group(required=True)
    for mode in ('prepare', 'apply', 'verify', 'restore'):
        modes.add_argument('--' + mode, action='store_true')
    modes.add_argument('--retire', metavar='CATEGORY', help='remove every entry of this category from the pass (its sources are authored again; recovery copies are kept)')
    args = parser.parse_args()
    root = args.root.resolve()
    backup = (args.backup or root / '_tod_size_originals/20260910').resolve()
    if backup == root or not backup.is_relative_to(root) or backup.parts[len(root.parts)] != '_tod_size_originals':
        raise ValueError('Backup must be under modtools/_tod_size_originals, outside build inputs')
    plan = json.loads(args.manifest.read_text(encoding='utf-8'))
    state_path = backup / 'state.json'
    state = json.loads(state_path.read_text()) if state_path.exists() else {'manifest_sha256': digest(args.manifest), 'entries': []}
    if state['manifest_sha256'] != digest(args.manifest):
        raise ValueError('Manifest changed: use a new backup directory')
    entries = {e['target']: e for e in state['entries']}

    def stage(target, stage_file, category, details=None):
        target = target.resolve()
        key = str(target)
        if key in entries:
            e = entries[key]
            if digest(target) not in (e['before_sha256'], e['after_sha256']):
                raise ValueError(f'Later edit detected: {target}')
            return
        scope, base = ('repo', REPO) if target.is_relative_to(REPO) else ('installed', root)
        file_id = hashlib.sha256(key.encode()).hexdigest()[:24]
        old = child(backup, Path('original') / scope / (file_id + '.before'))
        old.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(target, old)
        e = dict(target=key, original=str(old.relative_to(backup)), staged=str(stage_file.relative_to(backup)),
                 before_sha256=digest(old), after_sha256=digest(stage_file), category=category, details=details)
        state['entries'].append(e)
        entries[key] = e
        save(state_path, state)

    if args.prepare:
        from PIL import Image
        # Check every input before expensive conversion. A completed prepare is resumable.
        for row in plan['resizes']:
            p = child(root, row['source'])
            expected = entries.get(str(p), {}).get('after_sha256')
            if digest(p) not in (row['before_sha256'], expected):
                raise ValueError(f'Input changed since audit: {p}')
        for group in plan['duplicate_groups']:
            pixels = None
            for src in group['sources']:
                p = child(root, src['source'])
                if str(p) in entries:
                    p = child(backup, entries[str(p)]['original'])
                if digest(p) != src['before_sha256']:
                    raise ValueError(f'Duplicate source changed: {p}')
                with Image.open(p) as im:
                    current = (im.size, im.mode, im.tobytes())
                if pixels is not None and current != pixels:
                    raise ValueError(f'Duplicate pixels differ: {group["canonical"]}')
                pixels = current
                # Validate the asset settings again, not just the earlier audit.
                definitions = [(n,k,b) for n,k,b in BLOCK.findall(child(root, src['gdt']).read_text(encoding='utf-8')) if n == src['name'] and k == 'image']
                if len(definitions) != 1:
                    raise ValueError(f'Duplicate definition missing: {src["name"]}')
                fields = dict(re.findall(r'"([^"\r\n]+)"\s+"([^"\r\n]*)"', definitions[0][2]))
                fields = {k:v for k,v in fields.items() if k not in ('baseImage','type')}
                if fields != src['fields']:
                    raise ValueError(f'Duplicate settings changed: {src["name"]}')
        for i, row in enumerate(plan['resizes']):
            p = child(root, row['source'])
            file_id = hashlib.sha256(row['source'].encode()).hexdigest()[:24]
            out = child(backup, entries[str(p)]['staged'] if str(p) in entries else Path('staged') / (file_id + p.suffix))
            out.parent.mkdir(parents=True, exist_ok=True)
            if str(p) not in entries:
                details = resize(p, out, row)
                stage(p, out, row['category'], details)
            else:
                details = entries[str(p)]['details']
            mirror = child(REPO, row['source'])
            if mirror.exists():
                if digest(mirror) not in (row['before_sha256'], digest(out)):
                    raise ValueError(f'Repo mirror differs; preserve and review: {mirror}')
                stage(mirror, out, row['category'], details)
            print(f'Staged {i+1}/{len(plan["resizes"])} {row["category"]}: {row["source"]}', flush=True)
        files = {}
        for e in plan['gdt_edits']:
            files.setdefault(e['file'], []).append(e)
        for relative, edits in files.items():
            for scope, base in (('installed',root), ('repo',REPO)):
                p = child(base, relative)
                if not p.exists() and scope == 'repo':
                    continue
                if str(p) in entries:
                    continue
                file_id = hashlib.sha256(relative.encode()).hexdigest()[:24]
                out = child(backup, Path('staged_gdt') / scope / (file_id + '.after'))
                out.parent.mkdir(parents=True, exist_ok=True)
                out.write_bytes(edit_gdt(p.read_bytes(), edits))
                stage(p, out, 'gdt')
        state['prepared'] = True
        save(state_path, state)
        print(f'PREPARED {len(entries)} installed/repo files. No build inputs changed. {state_path}')
        return
    if args.retire:
        # A category whose sources are AUTHORED again leaves the pass whole: the build gate
        # (--verify) must stop comparing them to the staged reduction, and --restore must never
        # put the reduction's "original" back over the new authoring. The recovery copies stay
        # on disk for the record; only the ledger rows go, and the revision says why.
        # 2026-09-13: the sky. v18.87 re-renders it at 8192x4096 (docs/104 4g) — the 2:1
        # average the pass shipped on 2026-09-10 (docs/129 item 9) is superseded by the source.
        gone = [e for e in state['entries'] if e.get('category') == args.retire]
        if not gone:
            raise ValueError(f'No entries of category {args.retire!r} in {state_path}')
        state['entries'] = [e for e in state['entries'] if e.get('category') != args.retire]
        state.setdefault('revisions', []).append(
            f'{args.retire}: retired {len(gone)} entr{"y" if len(gone) == 1 else "ies"} on {datetime.date.today().isoformat()}; '
            'the sources are authored at ship size again and are no longer compared by --verify or touched by --restore: '
            + ', '.join(Path(e['target']).name for e in gone))
        save(state_path, state)
        print(f'RETIRED {len(gone)} {args.retire} entr{"y" if len(gone) == 1 else "ies"}; {len(state["entries"])} remain. {state_path}')
        for e in gone:
            print(f'  {e["target"]}')
        return
    if not state.get('prepared'):
        raise ValueError('Run --prepare to completion first')
    # Entire set is preflighted before any mutation; restore never overwrites later work.
    #
    # A target that no longer EXISTS is not the same failure as one that changed,
    # and until 2026-09-11 this loop could not tell them apart: digest() raised
    # FileNotFoundError and killed every full build. What actually happened is that
    # GDTs live in the MOD TOOLS ROOT, which is SHARED BY BOTH OF THIS USER'S MAPS,
    # and this pass optimized sources belonging to map 1 (acc_*) as well as ours.
    # Map 1's own work then deleted one of them. Nothing about our map regressed.
    #
    # So: a missing target OUTSIDE our repo is another map's file to delete — warn,
    # skip it, and say so, because --restore can no longer cover it. A missing
    # target INSIDE our repo is our own regression and still fails hard.
    gone = []
    entries_live = []
    for e in state['entries']:
        p = Path(e['target'])
        if not p.exists():
            if p.is_relative_to(REPO):
                raise ValueError(f'Optimized source missing from THIS repo: {p}')
            gone.append(p)
            continue
        entries_live.append(e)
    if gone:
        print(f'WARNING: {len(gone)} optimized source(s) no longer exist in the shared mod tools root.')
        print('         These belong to another map using the same tools root; --restore cannot cover them.')
        for p in gone:
            print(f'         gone: {p.name}')
    for e in entries_live:
        p = Path(e['target'])
        child(REPO if p.is_relative_to(REPO) else root, p)
        if digest(p) not in (e['before_sha256'], e['after_sha256']):
            raise ValueError(f'Later edit detected; refusing overwrite: {p}')
        for field, expected in (('original','before_sha256'), ('staged','after_sha256')):
            if digest(child(backup,e[field])) != e[expected]:
                raise ValueError(f'Damaged recovery/staging file: {e[field]}')
        if args.verify and digest(p) != e['after_sha256']:
            raise ValueError(f'Optimization not installed: {p}')
    if args.verify:
        tail = f' ({len(gone)} skipped: gone from the shared tools root)' if gone else ''
        print(f'VERIFIED {len(entries_live)} exact installed/repo outputs and all recovery hashes.{tail}')
        return
    source_field = 'original' if args.restore else 'staged'
    hash_field = 'before_sha256' if args.restore else 'after_sha256'
    # entries_live, NOT state['entries']: a target another map deleted must not be
    # resurrected here. Restoring it would put a file back that its owner removed.
    for e in entries_live:
        p = Path(e['target'])
        if digest(p) != e[hash_field]:
            shutil.copyfile(child(backup,e[source_field]), p)
        if digest(p) != e[hash_field]:
            raise ValueError(f'Copy verification failed: {p}')
    state['applied'] = not args.restore
    save(state_path, state)
    print(f'{"RESTORED" if args.restore else "APPLIED"} {len(entries)} files. Full -CleanPak build required.')


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(error.stderr.decode(errors='replace'), file=sys.stderr)
        raise
