"""Snapshot before build; afterward prove matching, timely inputs and linked staff assets."""
import csv
import datetime
import hashlib
import json
from pathlib import Path
import sys
from import_staff_animations import ROOT, blocks
from verify_staff_animations import find_tools_root

TOOLS=find_tools_root()
DEPLOY=TOOLS/'usermaps/zm_tower_of_doom'
OUT=ROOT/'tmp/staff_pap_20260921'
SNAP=OUT/'build_input_snapshot.json'


def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def inputs():
    paths=set()
    for folder in ('scripts','ui','zone_source','gamedata','map_source'):
        paths.update(p for p in (ROOT/folder).rglob('*') if p.is_file()
                     and not any(x in ('all','english','loc','__pycache__') for x in p.relative_to(ROOT/folder).parts))
    for manifest in ('docs/staff_approved_manifest.json','docs/staff_presentation_manifest.json',
                     'docs/bo6_ports/manifests/ice_staff_bo3_install.json'):
        paths.update(ROOT/p for p in json.loads((ROOT/manifest).read_text())['files'])
    paths.update(ROOT/('source_data/'+p) for p in ('tod_staff.gdt','tod_staff_origins.gdt',
                'tod_staff_approved_anims.gdt','tod_weapon_twins.gdt'))
    return {p.relative_to(ROOT).as_posix():digest(p) for p in sorted(paths)}


def main():
    current=inputs()
    if '--snapshot' in sys.argv:
        SNAP.write_text(json.dumps(current,indent=2)+'\n')
        print('Staff build input snapshot:',len(current),'files');return
    snapshot=json.loads(SNAP.read_text());assert current==snapshot,'Inputs changed during build'
    ff=DEPLOY/'zone/zm_tower_of_doom.ff';stamp=ff.stat().st_mtime
    assert stamp>SNAP.stat().st_mtime,'No new fastfile'
    bad=[];newer=[]
    for name,sha in snapshot.items():
        path=Path(name)
        target=(TOOLS if path.parts[0] in ('source_data','model_export','xanim_export','map_source','sound_assets') else DEPLOY)/path
        if not target.is_file() or digest(target)!=sha:bad.append(name)
        if target.is_file() and target.stat().st_mtime>stamp:newer.append(name)
    names=set()
    for language in ('all','english'):
        path=DEPLOY/('zone_source/'+language+'/assetinfo/zm_tower_of_doom.csv')
        assert path.stat().st_mtime>SNAP.stat().st_mtime
        with path.open(encoding='utf-8-sig',newline='') as f:
            names.update((row['type'],row['name']) for row in csv.DictReader(f))
    wanted={(kind.removesuffix('.gdf'),name) for name,kind,fields in blocks(ROOT/'source_data/tod_staff_pap.gdt')}
    wanted.update(('weapon',name) for name,kind,fields in blocks(ROOT/'source_data/tod_weapon_twins.gdt') if name.startswith('tod_staff_'))
    wanted.add(('attachment','gmod6'))
    missing=sorted(wanted-names)
    banks=sorted((TOOLS/'sound/zone').rglob('zm_tower_of_doom*.all.sabs'))
    # Build pipeline may use the map's private sound directory instead.
    if not banks:banks=sorted((DEPLOY/'sound/zone').rglob('*.all.sabs'))
    report=dict(ff_bytes=ff.stat().st_size,ff_local_time=datetime.datetime.fromtimestamp(stamp).isoformat(),
                snapshot_inputs=len(snapshot),deployed_mismatches=bad,deployed_newer_than_ff=newer,
                missing_staff_assets=missing,linked_staff_assets=len(wanted)-len(missing),
                sound_banks=[dict(path=str(p),bytes=p.stat().st_size) for p in banks],
                game_launched=False,native_visual_verified=False)
    (OUT/'deployment_verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2));assert not bad and not newer and not missing
    assert banks and max(p.stat().st_size for p in banks)>50*1024*1024,'Missing/truncated sound bank'


if __name__=='__main__':main()
