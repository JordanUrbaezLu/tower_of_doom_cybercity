"""Machine-migration helper (2026-10-08, docs/174). Stdlib only, Python 3.10+.

The BO3 Mod Tools root holds ~82 GB that exists nowhere else: every third-party pack this
map (and the user's other maps) was built against, the size-pass originals, and 30 STOCK
files that packs or our own passes modified (libtiff64r.dll, converter_gdt_dirs_0.txt,
wpn_t7_zmb_weapons.gdt, the shrunk zombie textures ...). A fresh Steam install restores
none of it. This tool separates those files from the stock install EXACTLY, using Steam's
own depot manifest (depotcache/455131_<id>.manifest, 187,611 stock entries with sha1s),
and moves only them.

  overlay-export  --dest <bundle>/tools_overlay [--dry-run] [--all-usermaps]
                  copy every added + modified file into the bundle, sha1 of each recorded
                  in overlay_manifest.json. Resumable: re-running skips finished files.
  overlay-import  --src <bundle>/tools_overlay
                  copy them into the new machine's tools root; every file is hashed on the
                  way in and a mismatch is refused (the existing file is left alone).
  overlay-verify  --manifest <overlay_manifest.json> [--quick]
                  re-check a tools root against the manifest (size, and sha1 unless --quick).
  copylist        --src <root> --dest <dir> --list <file>
                  copy a NUL/newline list of relative paths (git ls-files --others -z).
  du <path>...    sizes, for dry runs.

Left out on purpose (they regenerate): share/assetconvert (the converter cache, 24 GB /
942k files), gdtdb, bin/crash_reports, every map's usermaps build output except
zm_tower_of_doom's (kept as a playable fallback, minus the dead _xpak_prev backups) and
every map's zone/workshop* publish files (they are the Workshop link - always kept).
"""
import argparse
import collections
import datetime
import hashlib
import json
import os
import re
import shutil
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from steam_manifest import stock_files  # noqa: E402

MAP = 'zm_tower_of_doom'
DEFAULT_TOOLS = r'C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130'
STEAM_LIBS = [r'C:\Program Files (x86)\Steam', r'C:\Steam', r'D:\Steam', r'E:\Steam',
              r'D:\SteamLibrary', r'E:\SteamLibrary']
EXCLUDE_DIRS = ('share/assetconvert/', 'gdtdb/', 'bin/crash_reports/')
CHUNK = 1 << 20


def lp(p):
    """Long-path-safe absolute path (\\\\?\\ prefix on Windows): tool trees exceed 260 chars."""
    p = os.path.abspath(p)
    if os.name == 'nt' and not p.startswith('\\\\?\\'):
        if p.startswith('\\\\'):
            return '\\\\?\\UNC\\' + p[2:]
        return '\\\\?\\' + p
    return p


def gb(n):
    return '%.2f GB' % (n / 1e9)


def find_tools(arg):
    if arg:
        if not os.path.isdir(arg):
            sys.exit('tools root not found: %s' % arg)
        return arg
    if os.path.isfile(os.path.join(DEFAULT_TOOLS, 'bin', 'modlauncher.exe')):
        return DEFAULT_TOOLS
    for lib in STEAM_LIBS:
        common = os.path.join(lib, 'steamapps', 'common')
        if not os.path.isdir(common):
            continue
        for d in sorted(os.listdir(common)):
            if d.startswith('Call of Duty Black Ops III') and \
                    os.path.isfile(os.path.join(common, d, 'bin', 'modlauncher.exe')):
                return os.path.join(common, d)
    sys.exit('Mod Tools root not found (no Call of Duty Black Ops III* folder with bin\\modlauncher.exe); pass --tools')


def find_stock_manifest(tools, arg):
    if arg:
        return arg
    steamapps = os.path.dirname(os.path.dirname(os.path.abspath(tools)))
    acf = os.path.join(steamapps, 'appmanifest_455130.acf')
    if not os.path.isfile(acf):
        sys.exit('no %s - pass --stock-manifest' % acf)
    text = open(acf, encoding='utf-8', errors='replace').read()
    m = re.search(r'"455131"\s*\{[^}]*?"manifest"\s+"(\d+)"', text)
    if not m:
        sys.exit('depot 455131 not listed in %s' % acf)
    for cache in (os.path.join(os.path.dirname(steamapps), 'depotcache'),
                  r'C:\Program Files (x86)\Steam\depotcache'):
        p = os.path.join(cache, '455131_%s.manifest' % m.group(1))
        if os.path.isfile(p):
            return p
    sys.exit('Steam depot manifest 455131_%s.manifest not found - pass --stock-manifest' % m.group(1))


# ------------------------------------------------------------------ selection rules
def keep_dir(reldir, all_usermaps):
    """reldir: lowercase, '/'-separated, trailing '/', '' for the root."""
    if any(reldir.startswith(e) for e in EXCLUDE_DIRS):
        return False
    if '/_xpak_prev/' in reldir:
        return False
    if reldir.startswith('usermaps/') and not all_usermaps:
        parts = reldir.rstrip('/').split('/')
        if len(parts) >= 2 and parts[1] != MAP:
            return len(parts) == 2 or (len(parts) == 3 and parts[2] == 'zone')
    return True


def keep_file(rel_low, all_usermaps):
    parts = rel_low.split('/')
    if rel_low.startswith('usermaps/') and not all_usermaps and len(parts) >= 2 and parts[1] != MAP:
        return len(parts) == 4 and parts[2] == 'zone' and parts[3].startswith('workshop')
    return True


def sha1_file(path):
    h = hashlib.sha1()
    with open(lp(path), 'rb') as f:
        for chunk in iter(lambda: f.read(CHUNK), b''):
            h.update(chunk)
    return h.hexdigest()


def is_link(p):
    """Junction or symlink: never followed (os.walk follows junctions on Windows). Tower II's
    usermaps/zm_tod2_cybercity is a junction into another tools copy - not part of this root."""
    return os.path.islink(p) or (hasattr(os.path, 'isjunction') and os.path.isjunction(p))


def classify(tools, stock, all_usermaps, hash_all=True, log=print):
    """Return (sel, errors, links). sel = [(rel, size, mtime, kind)] for every added/modified
    file the rules keep; errors = paths that could not be read (the export FAILS on any - a
    silent skip is a missed file); links = junctions/symlinks met and deliberately not followed.
    hash_all: sha1 every same-size stock file (the real export); False = only the ones whose
    mtime is outside the install's busiest hours (dry runs - minutes faster, not exhaustive)."""
    t0 = time.time()
    root = lp(tools)
    added, size_mod, same, errors, links = [], [], [], [], []
    onerr = lambda e: errors.append('%s: %s' % (e.filename, e.strerror))
    for dp, dns, fns in os.walk(root, onerror=onerr):
        reldir = os.path.relpath(dp, root).replace(chr(92), '/')
        reldir = '' if reldir == '.' else reldir + '/'
        keep = []
        for d in dns:
            rd = reldir + d + '/'
            if not keep_dir(rd.lower(), all_usermaps):
                continue
            if is_link(os.path.join(dp, d)):
                links.append(rd)
                continue
            keep.append(d)
        dns[:] = keep
        if not keep_dir(reldir.lower(), all_usermaps):
            continue
        for fn in fns:
            rel = reldir + fn
            low = rel.lower()
            if not keep_file(low, all_usermaps):
                continue
            try:
                st = os.stat(os.path.join(dp, fn))
            except OSError as e:
                errors.append('%s: %s' % (rel, e.strerror))
                continue
            s = stock.get(low)
            if s is None:
                added.append((rel, st.st_size, st.st_mtime, 'added'))
            elif s[0] != st.st_size:
                size_mod.append((rel, st.st_size, st.st_mtime, 'modified'))
            else:
                same.append((rel, st.st_size, st.st_mtime))
    if hash_all:
        candidates = same
    else:
        hour = lambda t: datetime.datetime.fromtimestamp(t).strftime('%Y-%m-%d %H')
        top = {h for h, _ in collections.Counter(hour(m) for _, _, m in same).most_common(3)}
        candidates = [r for r in same if hour(r[2]) not in top]
    same_mod = []
    for rel, size, mt in candidates:
        try:
            if sha1_file(os.path.join(tools, rel)) != stock[rel.lower()][1].hex():
                same_mod.append((rel, size, mt, 'modified'))
        except OSError as e:
            errors.append('%s: %s' % (rel, e.strerror))
    log('scanned %s in %.0fs: %d added, %d modified (+%d same-size), %d stock files byte-identical%s'
        % (tools, time.time() - t0, len(added), len(size_mod), len(same_mod), len(same) - len(same_mod),
           '' if hash_all else ' (dry run: only date-suspect stock files hashed)'))
    for l in links:
        log('  not followed (junction/symlink): %s' % l)
    return sorted(added + size_mod + same_mod), errors, links


def summary(sel, depth=2, limit=40):
    g = collections.defaultdict(lambda: [0, 0])
    for rel, size, _, _ in sel:
        p = rel.split('/')
        k = '/'.join(p[:depth]) if len(p) > depth else '/'.join(p[:-1]) or '(root)'
        g[k][0] += 1
        g[k][1] += size
    for k, (n, s) in sorted(g.items(), key=lambda x: -x[1][1])[:limit]:
        print('  %10s %7d files  %s' % (gb(s), n, k))
    if len(g) > limit:
        rest = sorted(g.items(), key=lambda x: -x[1][1])[limit:]
        print('  %10s %7d files  (%d more folders)' % (gb(sum(v[1] for _, v in rest)),
                                                     sum(v[0] for _, v in rest), len(rest)))


def fold(path):
    """Windows file names are case-insensitive: compare paths case-folded there."""
    return path.lower() if os.name == 'nt' else path


def tree_sizes(root):
    """{'a/b/c.ext': (size, mtime)} for every file under root, from ONE directory listing per folder.
    On a network share a per-file isfile+getsize is two round trips each: the resume check
    of 16.5k finished files stalled ~25 min over Wi-Fi (2026-10-08). On Windows,
    DirEntry.stat() reuses the listing's data, so this costs no per-file request."""
    out = {}
    base = lp(root)
    stack = ['']
    while stack:
        rel = stack.pop()
        here = os.path.join(base, rel.replace('/', chr(92))) if rel else base
        try:
            with os.scandir(here) as it:
                for e in it:
                    r = rel + '/' + e.name if rel else e.name
                    if e.is_dir(follow_symlinks=False):
                        stack.append(r)
                    else:
                        st = e.stat(follow_symlinks=False)
                        out[fold(r)] = (st.st_size, st.st_mtime)
        except FileNotFoundError:
            pass
    return out


def copy_direct(src, dst):
    """Export-side copy: straight to the final name, hashing on the way, nothing else. Over SMB
    every extra step (a .part rename, a set-time) is more round trips per file, and the export
    needs neither: an interrupted file has no progress record (so the resume recopies it), the
    import re-hashes every file against the manifest, and the import sets the real mtime."""
    os.makedirs(lp(os.path.dirname(dst)), exist_ok=True)
    h = hashlib.sha1()
    with open(lp(src), 'rb') as fi, open(lp(dst), 'wb') as fo:
        for chunk in iter(lambda: fi.read(CHUNK), b''):
            h.update(chunk)
            fo.write(chunk)
    return h.hexdigest()


def copy_hash(src, dst, mtime, expect=None):
    """Copy src -> dst through a .part file, hashing on the way. With `expect`, a mismatch
    deletes the .part and leaves dst untouched. Returns the sha1 hex of what was read."""
    os.makedirs(lp(os.path.dirname(dst)), exist_ok=True)
    part = dst + '.part'
    h = hashlib.sha1()
    with open(lp(src), 'rb') as fi, open(lp(part), 'wb') as fo:
        for chunk in iter(lambda: fi.read(CHUNK), b''):
            h.update(chunk)
            fo.write(chunk)
    sha = h.hexdigest()
    if expect is not None and sha != expect:
        os.remove(lp(part))
        return sha
    os.replace(lp(part), lp(dst))
    os.utime(lp(dst), (mtime, mtime))
    return sha


class Progress:
    def __init__(self, total_files, total_bytes, label):
        self.n = self.b = 0
        self.tf, self.tb, self.label = total_files, total_bytes, label
        self.t0 = self.last = time.time()

    def step(self, size):
        self.n += 1
        self.b += size
        now = time.time()
        if now - self.last > 15 or self.n == self.tf:
            self.last = now
            rate = self.b / max(now - self.t0, 0.001) / 1e6
            print('  %s: %d/%d files, %s/%s (%.0f MB/s)' % (self.label, self.n, self.tf, gb(self.b),
                                                          gb(self.tb), rate), flush=True)


# ------------------------------------------------------------------ subcommands
def overlay_export(a):
    tools = find_tools(a.tools)
    man_path = find_stock_manifest(tools, a.stock_manifest)
    meta, stock = stock_files(man_path)
    print('stock manifest %s: %d files' % (os.path.basename(man_path), len(stock)))
    sel, errors, links = classify(tools, stock, a.all_usermaps, hash_all=not a.dry_run)
    total = sum(r[1] for r in sel)
    print('overlay: %d files, %s' % (len(sel), gb(total)))
    summary(sel)
    print('BYTES=%d FILES=%d' % (total, len(sel)))
    if errors:
        print('OVERLAY EXPORT FAIL: %d path(s) could not be read - fix access (close the mod tools / BO3) and re-run:' % len(errors))
        for e in errors[:25]:
            print('   ', e)
        return 1
    if a.dry_run:
        return 0
    os.makedirs(lp(a.dest), exist_ok=True)
    # The progress record lives on THIS machine's disk (2026-10-08): written to the share, every
    # record was a network round trip, 32 copy workers outran the one recorder by ~27k files and a
    # Wi-Fi drop lost them all. Local appends are instant and survive any network drop; the file is
    # copied into the bundle at the end. A legacy record on the share (earlier runs) is merged in.
    legacy = os.path.join(a.dest, 'overlay_progress.jsonl')
    # the local record is keyed by an id stored IN the bundle: wipe the bundle and its id goes too,
    # so a stale local record can never skip files that are no longer there
    tok_path = os.path.join(a.dest, 'bundle_id.txt')
    if os.path.isfile(lp(tok_path)):
        key = open(lp(tok_path), encoding='utf-8').read().strip()
    else:
        import uuid
        key = uuid.uuid4().hex[:16]
        open(lp(tok_path), 'w', encoding='utf-8').write(key)
    local_dir = os.path.join(os.environ.get('LOCALAPPDATA', os.path.expanduser('~')), 'tod_migrate')
    os.makedirs(local_dir, exist_ok=True)
    prog_path = os.path.join(local_dir, key + '_overlay_progress.jsonl')
    done = {}
    for path in (legacy, prog_path):
        if os.path.isfile(lp(path)):
            for line in open(lp(path), encoding='utf-8'):
                try:
                    r = json.loads(line)
                    done[r['p']] = r
                except ValueError:
                    pass
    print('  progress record: %s (%d files recorded)' % (prog_path, len(done)))
    finished = {}
    todo = []
    # --verify-remote: also confirm each recorded file is still in the bundle (one listing per
    # folder; ~6 min over Wi-Fi). Off by default - the import re-hashes every file anyway.
    have = tree_sizes(os.path.join(a.dest, 'files')) if (done and a.verify_remote) else None
    pr = Progress(len(sel), total, 'export')
    for rel, size, mtime, kind in sel:
        r = done.get(rel)
        if r and r['size'] == size and abs(r['mtime'] - mtime) < 2 and \
                (have is None or (have.get(fold(rel)) or (None,))[0] == size):
            finished[rel] = r
            pr.step(size)
        else:
            todo.append((rel, size, mtime, kind))
    if finished:
        print('  resuming: %d files already in the bundle, %d to copy' % (len(finished), len(todo)))

    def work(item):
        rel, size, mtime, kind = item
        sha = copy_direct(os.path.join(tools, rel), os.path.join(a.dest, 'files', rel))
        return {'p': rel, 'size': size, 'mtime': mtime, 'sha1': sha, 'kind': kind}

    # Several files in flight at once: over SMB each file costs round trips (create, write, rename,
    # set time), so one-at-a-time ran at 2-4 MB/s on a link robocopy fills at 24 MB/s (2026-10-08).
    # Only this thread writes the progress file, so a crash leaves it consistent for the resume.
    with open(prog_path, 'a', encoding='utf-8') as prog:
        ex = ThreadPoolExecutor(max_workers=max(1, a.workers))
        try:
            for fut in as_completed([ex.submit(work, it) for it in todo]):
                r = fut.result()
                prog.write(json.dumps(r) + '\n')
                prog.flush()
                finished[r['p']] = r
                pr.step(r['size'])
        except BaseException:
            ex.shutdown(wait=True, cancel_futures=True)
            raise
        ex.shutdown(wait=True)
    records = [finished[rel] for rel, _, _, _ in sel]
    # Final safety net (2026-10-09): list the bundle once and re-copy any file whose size disagrees
    # with its record. A run stopped mid-copy truncates the file it was rewriting (copy_direct writes
    # in place); if that file's earlier record survives, a resume would trust it - 5 such files once
    # reached the new laptop (2 cut at 1 MiB, 3 empty). Up to 3 passes, then fail loudly.
    for attempt in range(3):
        on_disk = tree_sizes(os.path.join(a.dest, 'files'))
        short = [r for r in records if (on_disk.get(fold(r['p'])) or (None,))[0] != r['size']]
        if not short:
            print('  size check: all %d files in the bundle match their records' % len(records))
            break
        print('  size check: %d file(s) short or missing - re-copying (pass %d)' % (len(short), attempt + 1))
        for r in short:
            copy_hash(os.path.join(tools, r['p']), os.path.join(a.dest, 'files', r['p']), r['mtime'], expect=r['sha1'])
    else:
        print('OVERLAY EXPORT FAIL: files still short after 3 passes: %s' % ', '.join(r['p'] for r in short[:10]))
        return 1
    out = {'created': datetime.datetime.now().isoformat(timespec='seconds'),
           'source_tools_root': tools, 'stock_manifest': os.path.basename(man_path),
           'stock_depot_manifest_id': str(meta.get(2)), 'map': MAP, 'all_usermaps': a.all_usermaps,
           'excluded_dirs': list(EXCLUDE_DIRS) + ['**/_xpak_prev/', 'usermaps/<other maps>/ (zone/workshop* kept)'],
           'links_not_followed': links,
           'file_count': len(records), 'total_bytes': sum(r['size'] for r in records), 'files': records}
    with open(os.path.join(a.dest, 'overlay_manifest.json'), 'w', encoding='utf-8') as f:
        json.dump(out, f)
    # Write the COMPLETE record (every file in this bundle) to both places. Copying the local file
    # over the share's record (2026-10-08) erased the share-only entries from earlier runs, and the
    # next resume re-copied those files. Rewrite via .new + replace so a crash never leaves half.
    for path in (prog_path, legacy):
        tmp = path + '.new'
        with open(lp(tmp), 'w', encoding='utf-8') as f:
            for r in records:
                f.write(json.dumps(r) + '\n')
        os.replace(lp(tmp), lp(path))
    print('OVERLAY EXPORT OK: %d files, %s -> %s' % (len(records), gb(out['total_bytes']), a.dest))
    return 0


def load_stock(tools, arg):
    """This machine's stock file list, or None (then a 'modified' stock file is always replaced)."""
    try:
        return stock_files(find_stock_manifest(tools, arg))[1]
    except (SystemExit, OSError, ValueError) as e:
        print('  (no Steam stock manifest here: %s - modified stock files are always replaced)' % e)
        return None


def overlay_import(a):
    tools = find_tools(a.tools)
    man = json.load(open(os.path.join(a.src, 'overlay_manifest.json'), encoding='utf-8'))
    stock = load_stock(tools, a.stock_manifest)
    files = man['files']
    present = copied = 0
    bad, missing, newer = [], [], []
    pr = Progress(len(files), man['total_bytes'], 'import')
    for r in files:
        src = os.path.join(a.src, 'files', r['p'])
        dst = os.path.join(tools, r['p'])
        if os.path.isfile(lp(dst)):
            st = os.stat(lp(dst))
            if st.st_size == r['size'] and abs(st.st_mtime - r['mtime']) < 2:
                present += 1
                pr.step(r['size'])
                continue
            if st.st_mtime > r['mtime'] + 2 and not a.force:
                if st.st_size == r['size'] and sha1_file(dst) == r['sha1']:
                    present += 1                    # same bytes, only the date differs
                    pr.step(r['size'])
                    continue
                # Steam stamps a fresh install with the INSTALL time, so an untouched stock file
                # always looks newer than the bundle's modified copy (the 30 modified stock files:
                # libtiff64r.dll, converter_gdt_dirs_0.txt, archetypes.gdt ...). Only a file that
                # is NOT byte-for-byte stock was really changed here - and only that is kept.
                s = stock.get(r['p'].lower()) if stock is not None else None
                still_stock = s is not None and st.st_size == s[0] and sha1_file(dst) == s[1].hex()
                if not still_stock and not (stock is None and r['kind'] == 'modified'):
                    newer.append(r['p'])            # changed on this machine (a build, a sync, an edit)
                    pr.step(r['size'])
                    continue
        if not os.path.isfile(lp(src)):
            missing.append(r['p'])
        elif copy_hash(src, dst, r['mtime'], expect=r['sha1']) != r['sha1']:
            bad.append(r['p'])
        else:
            copied += 1
        pr.step(r['size'])
    print('overlay import: %d copied, %d already present, %d kept (newer on this machine), %d missing from bundle, %d failed sha1'
          % (copied, present, len(newer), len(missing), len(bad)))
    if newer:
        print('   kept because the local copy is newer than the bundle (use --force to take the bundle copy):')
        for p in newer[:10]:
            print('     ', p)
    for p in (missing + bad)[:25]:
        print('   PROBLEM:', p)
    if missing or bad:
        print('OVERLAY IMPORT INCOMPLETE - re-copy the bundle from the old laptop and run again')
        return 1
    print('OVERLAY IMPORT OK -> %s' % tools)
    return 0


def overlay_verify(a):
    tools = find_tools(a.tools)
    man = json.load(open(a.manifest, encoding='utf-8'))
    # this map's own usermaps tree is build output + synced copies: every build rewrites it, so only
    # its Workshop publish files are checked (they are the link to the published item)
    own = 'usermaps/%s/' % MAP
    files = [r for r in man['files'] if not r['p'].lower().startswith(own) or
             r['p'].lower().startswith(own + 'zone/workshop')]
    stock = load_stock(tools, a.stock_manifest)
    probs = collections.defaultdict(list)
    changed = []
    pr = Progress(len(files), sum(r['size'] for r in files), 'verify')
    for r in files:
        dst = os.path.join(tools, r['p'])
        pr.step(r['size'])
        if not os.path.isfile(lp(dst)):
            probs['missing'].append(r['p'])
            continue
        st = os.stat(lp(dst))
        # a 'modified' stock file is always hashed, even with --quick: the stock copy can share its size
        full = not a.quick or r['kind'] == 'modified'
        differs = st.st_size != r['size'] or (full and sha1_file(dst) != r['sha1'])
        if not differs:
            continue
        s = stock.get(r['p'].lower()) if stock is not None else None
        if s is not None and st.st_size == s[0] and sha1_file(dst) == s[1].hex():
            probs['still_stock'].append(r['p'])  # the import never replaced the fresh Steam copy
        elif st.st_mtime > r['mtime'] + 2:
            changed.append(r['p'])          # edited / rebuilt here after the import: fine
        else:
            probs['size' if st.st_size != r['size'] else 'sha1'].append(r['p'])
    note = ''
    if changed:
        note = ' (%d changed on this machine since the import - normal after builds or edits)' % len(changed)
    if not probs:
        print('OVERLAY VERIFY OK: %d files present%s in %s%s'
              % (len(files), '' if a.quick else ' and sha1-identical', tools, note))
        return 0
    label = {'missing': 'missing', 'still_stock': 'still the STOCK Steam copy (the modified version was never applied)'}
    for k, v in probs.items():
        print('OVERLAY VERIFY FAIL: %d %s' % (len(v), label.get(k, 'differ from the bundle (' + k + ')')))
        for p in v[:15]:
            print('   ', p)
    if note:
        print('   ' + note.strip())
    return 1


def copylist(a):
    if a.git_untracked:
        # every path git does not track (ignored or not); --directory folds a wholly-untracked folder
        # (tmp/, local_sync_cache/) into one entry. Read as bytes: -z paths are raw UTF-8, unquoted.
        import subprocess
        raw = subprocess.run(['git', '-C', a.src, 'ls-files', '--others', '--directory', '-z'],
                             check=True, capture_output=True).stdout.decode('utf-8')
        if a.save_list:
            os.makedirs(lp(os.path.dirname(os.path.abspath(a.save_list))), exist_ok=True)
            open(a.save_list, 'w', encoding='utf-8').write(raw.replace('\0', '\n'))
    else:
        raw = open(a.list, 'rb').read().decode('utf-8')
    items = [x.rstrip('\r') for x in re.split('[\0\n]', raw) if x.strip()]
    n = b = skipped = kept = 0
    errors, links, absent, jobs = [], [], [], []
    onerr = lambda e: errors.append('%s: %s' % (e.filename, e.strerror))
    # what is already at the destination: ONE listing per folder, not a stat per file (over a
    # network share each stat is a round trip - 26k of them is ~25 min on Wi-Fi)
    existing = {} if a.dry_run else tree_sizes(a.dest)
    for rel in items:
        src = os.path.join(a.src, rel)
        srcs = []
        if os.path.isdir(lp(src)):
            for dp, dns, fns in os.walk(lp(src), onerror=onerr):
                for d in list(dns):
                    if is_link(os.path.join(dp, d)):
                        links.append(os.path.relpath(os.path.join(dp, d), lp(a.src)))
                        dns.remove(d)
                for fn in fns:
                    full = os.path.join(dp, fn)
                    srcs.append(os.path.relpath(full, lp(a.src)))
        elif os.path.isfile(lp(src)):
            srcs.append(rel.rstrip('/'))
        else:
            absent.append(rel)
        for r in srcs:
            s, d = os.path.join(a.src, r), os.path.join(a.dest, r)
            try:
                st = os.stat(lp(s))
            except OSError as e:
                errors.append('%s: %s' % (r, e.strerror))
                continue
            if a.dry_run:
                n += 1
                b += st.st_size
                continue
            cur = existing.get(fold(r.replace(chr(92), '/')))
            if cur is not None:
                if a.no_overwrite:
                    kept += 1          # import: a file the clone (or the user) already has wins
                    continue
                if cur[0] == st.st_size and abs(cur[1] - st.st_mtime) < 2:
                    skipped += 1
                    continue
            jobs.append((r, s, d, st.st_size))
    # copy in parallel (same reason as overlay-export: per-file round trips over SMB)
    lock = threading.Lock()

    def one(job):
        r, s, d, size = job
        try:
            os.makedirs(lp(os.path.dirname(d)), exist_ok=True)
            shutil.copy2(lp(s), lp(d))
            return size
        except OSError as e:
            with lock:
                errors.append('%s: %s' % (r, e.strerror))
            return None
    if jobs:
        with ThreadPoolExecutor(max_workers=max(1, a.workers)) as ex:
            for size in ex.map(one, jobs):
                if size is not None:
                    n += 1
                    b += size
    for l in links:
        print('  not followed (junction/symlink): %s' % l)
    if absent:
        print('  %d list entr%s no longer exist at the source (skipped): %s'
              % (len(absent), 'y' if len(absent) == 1 else 'ies', ', '.join(absent[:5])))
    if a.dry_run:
        print('copylist (dry run): %d files, %s from %d list entries' % (n, gb(b), len(items)))
    else:
        print('copylist: %d copied (%s), %d already current, %d kept (already at the destination), from %d list entries'
              % (n, gb(b), skipped, kept, len(items)))
    print('BYTES=%d FILES=%d' % (b, n))
    if errors:
        print('COPYLIST FAIL: %d file(s) could not be read/written:' % len(errors))
        for e in errors[:25]:
            print('   ', e)
        return 1
    if not a.dry_run:
        print('COPYLIST OK')
    return 0


def du(a):
    out = []
    for p in a.paths:
        n = s = 0
        if os.path.isfile(lp(p)):
            n, s = 1, os.path.getsize(lp(p))
        elif os.path.isdir(lp(p)):
            # one listing per folder: a stat per file over a network share took over an hour for
            # the ~150k-file bundle (2026-10-08); DirEntry sizes come free with the listing
            sizes = tree_sizes(p)
            n, s = len(sizes), sum(v[0] for v in sizes.values())
        out.append({'path': p, 'files': n, 'bytes': s, 'exists': os.path.exists(lp(p))})
    if a.json:
        print(json.dumps(out))
    else:
        for o in out:
            print('%10s %8d files  %s' % (gb(o['bytes']), o['files'], o['path']))
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)
    e = sub.add_parser('overlay-export')
    e.add_argument('--dest', required=True)
    e.add_argument('--tools')
    e.add_argument('--stock-manifest')
    e.add_argument('--dry-run', action='store_true')
    e.add_argument('--all-usermaps', action='store_true', help="also keep the other maps' build output")
    e.add_argument('--workers', type=int, default=32, help='files copied at once (default 32: Wi-Fi SMB is latency-bound)')
    e.add_argument('--verify-remote', action='store_true', help='on resume, also list the bundle to confirm recorded files are still there')
    i = sub.add_parser('overlay-import')
    i.add_argument('--src', required=True)
    i.add_argument('--tools')
    i.add_argument('--force', action='store_true', help='also replace files that are newer on this machine')
    i.add_argument('--stock-manifest', help="this machine's Steam depot manifest (auto-found)")
    v = sub.add_parser('overlay-verify')
    v.add_argument('--manifest', required=True)
    v.add_argument('--tools')
    v.add_argument('--stock-manifest', help="this machine's Steam depot manifest (auto-found)")
    v.add_argument('--quick', action='store_true', help='sizes only, no sha1')
    c = sub.add_parser('copylist')
    c.add_argument('--src', required=True)
    c.add_argument('--dest', required=True)
    g = c.add_mutually_exclusive_group(required=True)
    g.add_argument('--list', help='NUL- or newline-separated relative paths')
    g.add_argument('--git-untracked', action='store_true', help='copy every path git does not track in --src')
    c.add_argument('--save-list', help='with --git-untracked: also write the list here')
    c.add_argument('--no-overwrite', action='store_true', help='never replace a file already at the destination')
    c.add_argument('--workers', type=int, default=32, help='files copied at once (default 32)')
    c.add_argument('--dry-run', action='store_true')
    d = sub.add_parser('du')
    d.add_argument('paths', nargs='+')
    d.add_argument('--json', action='store_true')
    a = ap.parse_args()
    fn = {'overlay-export': overlay_export, 'overlay-import': overlay_import,
          'overlay-verify': overlay_verify, 'copylist': copylist, 'du': du}[a.cmd]
    return fn(a)


if __name__ == '__main__':
    sys.exit(main())
