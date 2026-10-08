"""Snapshot and verify the exact source/assets consumed by this playtest build."""
import datetime, hashlib, json, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
MT=Path('C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130')
DEPLOY=MT/'usermaps/zm_tower_of_doom'
OUT=Path(sys.argv[sys.argv.index('--output')+1]) if '--output' in sys.argv else ROOT/'tmp/reference_one_integration'
OUT.mkdir(parents=True,exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
snapshot_path=OUT/'input_snapshot.json'
def inputs():
    for directory in ('scripts','ui','zone_source','model_export/tod_cyber_zombie'):
        for p in (ROOT/directory).rglob('*'):
            if p.is_file() and not any(x in ('all','english','loc','__pycache__') for x in p.relative_to(ROOT/directory).parts):yield p
    for name in ('tod_cyber_zombie.gdt','tod_cyber_roster.gdt'):yield ROOT/'source_data'/name
if '--snapshot' in sys.argv:
    snapshot_path.write_text(json.dumps({str(p.relative_to(ROOT)):sha(p) for p in inputs()},indent=2)+'\n')
    print('REFERENCE_ONE_INPUT_SNAPSHOT',snapshot_path)
    raise SystemExit(0)
snapshot=json.loads(snapshot_path.read_text())
assert set(snapshot)=={str(p.relative_to(ROOT)) for p in inputs()},'Source file set changed during build'
ff=DEPLOY/'zone/zm_tower_of_doom.ff';stamp=ff.stat().st_mtime
assert stamp>=snapshot_path.stat().st_mtime
bad=[];newer=[]
for name,digest in snapshot.items():
    relative=Path(name);source=ROOT/relative
    target=(MT if relative.parts[0] in ('source_data','model_export') else DEPLOY)/relative
    if sha(source)!=digest:bad.append('source_changed:'+name)
    if not target.exists() or sha(target)!=digest:bad.append('deployed_mismatch:'+name)
    if target.exists() and target.stat().st_mtime>stamp:newer.append(name)
ledgers=[DEPLOY/'zone_source'/lang/'assetinfo/zm_tower_of_doom.csv' for lang in ('all','english')]
for ledger in ledgers:assert ledger.stat().st_mtime>=snapshot_path.stat().st_mtime
text='\n'.join(p.read_text(encoding='utf-8-sig') for p in ledgers)
expected=set()
for name in ('art/cyber_zombie_mvp/engine_kit/install_manifest.json','art/cyber_zombie_roster/engine_kit/install_manifest.json'):
    manifest=json.loads((ROOT/name).read_text())
    expected.update(manifest['asset_copies'])
    expected.update(Path(t).stem for t in manifest['textures'])
expected.update(['mtl_tod_cyber_kit','_tod_cyber_zombies.gsc'])
missing=sorted(n for n in expected if n not in text)
result={'ff_bytes':ff.stat().st_size,'ff_local_time':datetime.datetime.fromtimestamp(stamp).isoformat(),
    'snapshot_inputs':len(snapshot),'differences':bad,'deployed_inputs_newer_than_ff':newer,
    'missing_assets':missing,'native_visual_verified':False,'game_launched':False}
(OUT/'deployment_verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
assert not bad and not newer and not missing
