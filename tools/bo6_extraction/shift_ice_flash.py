"""Move the ice staff's launch point: shift `tag_flash` forward in the fitted ice clips.

v18.93, user: "Can we just move it further from the player? ... Just move where
the shot starts." BO3 launches a projectile weapon's bolt and its 1p muzzle
effect from the VIEW MODEL's `tag_flash`, and a viewmodel clip pins that tag's
absolute transform every frame, so the model's own bone offset is irrelevant:
the only place the launch point lives is the clips. This shifts `tag_flash` by
SHIFT units along `tag_weapon`'s own X axis (the shaft direction) in every ice
clip that carries both parts, frame by frame, so the offset follows the staff
through raise / fire / sprint / reload. The other 193 parts are untouched.

Inputs are the vendored bins in xanim_export/tod_staff_approved/ (originals are
parked once under local_sync_cache/bo6_ice_staff/anims_before_flash_shift/);
outputs go back over the same names, are read back and checked, and
docs/staff_approved_manifest.json is re-hashed so verify_staff_animations.py
keeps gating them. Fire and lightning clips are not touched.

Run:  python tools/bo6_extraction/shift_ice_flash.py            (idempotent: measures first)
      python tools/bo6_extraction/shift_ice_flash.py --restore  (put the parked originals back)
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import types

REPO = Path(__file__).resolve().parents[2]
TOOLS = Path(r'C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130')
ANIMS = REPO/'xanim_export/tod_staff_approved'
PARK = REPO/'local_sync_cache/bo6_ice_staff/anims_before_flash_shift'
MANIFEST = REPO/'docs/staff_approved_manifest.json'
REPORT = REPO/'docs/bo6_ports/manifests/ice_staff_flash_shift.json'
WORK = REPO/'tmp/bo6_ice_staff/flash_shift'
PYCOD = Path(os.environ.get('TOD_PYCOD', r'C:\Users\jorda\Repositories\test+map\tmp\blender-cod\io_scene_cod'))
SHIFT = 48.0   # inches along the shaft; the tip tag_flash sat ~40 ahead of the camera in idle


def load_pycod():
    if 'PyCoD' not in sys.modules:
        sys.path.insert(0, str(PYCOD))
        pkg = types.ModuleType('PyCoD')
        pkg.__path__ = [str(PYCOD/'PyCoD')]
        sys.modules['PyCoD'] = pkg
    from PyCoD import xanim
    return xanim


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def flash_ahead(anim):
    """Distance of tag_flash ahead of tag_weapon along the shaft, frame 0."""
    names = [p.name for p in anim.parts]
    f, w = anim.frames[0].parts[names.index('tag_flash')], anim.frames[0].parts[names.index('tag_weapon')]
    ax = w.matrix[0]
    return sum((f.offset[k]-w.offset[k])*ax[k] for k in range(3))


def main():
    xanim = load_pycod()
    if '--restore' in sys.argv:
        for src in sorted(PARK.glob('*.XANIM_BIN')):
            shutil.copyfile(src, ANIMS/src.name)
        rehash()
        print('restored', len(list(PARK.glob('*.XANIM_BIN'))), 'clips from', PARK)
        return
    WORK.mkdir(parents=True, exist_ok=True)
    PARK.mkdir(parents=True, exist_ok=True)
    report = dict(shift_inches=SHIFT, clips=[])
    for path in sorted(ANIMS.glob('tod_vm_staff_ice_*.XANIM_BIN')):
        a = xanim.Anim()
        a.LoadFile_Bin(str(path))
        names = [p.name for p in a.parts]
        if 'tag_flash' not in names or 'tag_weapon' not in names:
            continue
        before = flash_ahead(a)
        if before > 39.8+SHIFT-1.0:
            print(f'{path.name}: already shifted ({before:.2f} ahead)')
            continue
        parked = PARK/path.name
        if not parked.exists():
            shutil.copyfile(path, parked)
        fi, wi = names.index('tag_flash'), names.index('tag_weapon')
        for frame in a.frames:
            fp, wp = frame.parts[fi], frame.parts[wi]
            ax = wp.matrix[0]
            fp.offset = tuple(fp.offset[k]+SHIFT*ax[k] for k in range(3))
        raw = WORK/(path.stem+'.XANIM_EXPORT')
        a.WriteFile_Raw(str(raw))
        r = subprocess.run([str(TOOLS/'bin/export2bin.exe'), raw.name], cwd=WORK, capture_output=True, text=True, timeout=300)
        out = next((p for p in WORK.iterdir() if p.name.lower() == path.name.lower()), None)
        assert r.returncode == 0 and out is not None, (path.name, r.stdout, r.stderr)
        back = xanim.Anim()
        back.LoadFile_Bin(str(out))
        assert [p.name for p in back.parts] == names and len(back.frames) == len(a.frames), path.name
        after = flash_ahead(back)
        assert abs(after-(before+SHIFT)) < 0.05, (path.name, before, after)
        assert [(n.frame, n.string) for n in back.notes] == [(n.frame, n.string) for n in a.notes], (path.name, 'notetracks changed')
        shutil.copyfile(out, path)
        report['clips'].append(dict(clip=path.name, frames=len(a.frames), flash_ahead_before=round(before, 3), flash_ahead_after=round(after, 3), sha256=digest(path)))
        print(f'{path.name}: tag_flash {before:.2f} -> {after:.2f} ahead of tag_weapon ({len(a.frames)} frames)')
    rehash()
    REPORT.write_text(json.dumps(report, indent=2)+'\n')
    print('SHIFTED', len(report['clips']), 'ice clips by', SHIFT, 'in; manifest re-hashed; FULL build next')


def rehash():
    m = json.loads(MANIFEST.read_text())
    changed = 0
    for rel in list(m['files']):
        p = REPO/rel
        if p.is_file() and 'tod_vm_staff_ice_' in rel:
            h = digest(p)
            changed += m['files'][rel] != h
            m['files'][rel] = h
    MANIFEST.write_text(json.dumps(m, indent=2)+'\n')
    print('manifest: re-hashed', changed, 'ice clip entries')


if __name__ == '__main__':
    main()
