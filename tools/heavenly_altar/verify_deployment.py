"""Prove that the completed full build consumed these exact sources/assets."""
import sys,json,hashlib,datetime,csv,os,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];MT=Path('C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130');DEPLOY=MT/'usermaps/zm_tower_of_doom'
OUT=Path(os.environ.get('ALTAR_VERIFY_OUT',str(ROOT/'tmp/heavenly_altar_integration')));OUT.mkdir(parents=True,exist_ok=True);SNAP=OUT/'input_snapshot.json'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def portal_definitions(path):
    # The shared pack also defines retired exterior materials that another map
    # optimizes differently. Our only dependencies are this material and its
    # three images: require their complete definitions, not unused pack entries.
    needed={'chaos_pap_background','i_chaos_pap_background_c','i_chaos_pap_background_2_c','i_chaos_pap_background_3_c'}
    entries={name:(kind,dict(re.findall(r'"([^"\r\n]+)"\s*"([^"\r\n]*)"',body))) for name,kind,body in re.findall(r'"([^"\r\n]+)"\s*\(\s*"([^"\r\n]+)"\s*\)\s*\{([^}]+)\}',path.read_text()) if name in needed}
    assert set(entries)==needed
    return entries
def inputs():
    for directory in ('scripts','ui','zone_source','model_export/tod_heavenly_altar'):
        for p in (ROOT/directory).rglob('*'):
            if p.is_file() and not any(x in ('all','english','loc','__pycache__') for x in p.relative_to(ROOT/directory).parts):yield p
    yield ROOT/'source_data/tod_heavenly_altar.gdt'
    yield ROOT/'source_data/chaos_pack_a_punch.gdt'
if '--snapshot' in sys.argv:
    SNAP.write_text(json.dumps({str(p.relative_to(ROOT)):sha(p) for p in inputs()},indent=2));print('ALTAR_INPUT_SNAPSHOT',SNAP);raise SystemExit
snapshot=json.loads(SNAP.read_text());assert set(snapshot)=={str(p.relative_to(ROOT)) for p in inputs()}
ff=DEPLOY/'zone/zm_tower_of_doom.ff';stamp=ff.stat().st_mtime;assert stamp>SNAP.stat().st_mtime
bad=[];newer=[];shared_portal_match=False
for name,digest in snapshot.items():
    relative=Path(name);target=(MT if relative.parts[0] in ('source_data','model_export') else DEPLOY)/relative
    if sha(ROOT/relative)!=digest:bad.append('source_changed:'+name)
    if relative.as_posix()=='source_data/chaos_pack_a_punch.gdt':
        shared_portal_match=target.exists() and portal_definitions(ROOT/relative)==portal_definitions(target)
        if not shared_portal_match:bad.append('deployed_portal_definition_mismatch:'+name)
    elif not target.exists() or sha(target)!=digest:bad.append('deployed_mismatch:'+name)
    if target.exists() and target.stat().st_mtime>stamp:newer.append(name)
names=set()
for language in ('all','english'):
    path=DEPLOY/'zone_source'/language/'assetinfo/zm_tower_of_doom.csv';assert path.stat().st_mtime>SNAP.stat().st_mtime
    with path.open(encoding='utf-8-sig',newline='') as f:
        # Native model-surface materials are compiled in the mc/ namespace.
        for row in csv.DictReader(f):names.add(row['name'].removeprefix('mc/') if row['type']=='material' else row['name'])
manifest=json.loads((ROOT/'art/heavenly_altar/engine_kit/install_manifest.json').read_text())
expected={manifest['asset'],*manifest['materials'],*(Path(n).stem for n in manifest['textures'])}
expected.update(manifest.get('external_images',[]))
missing=sorted(expected-names)
entry=(ROOT/'scripts/zm/zm_tower_of_doom.gsc').read_text(encoding='utf-8-sig')
result={'ff_bytes':ff.stat().st_size,'ff_local_time':datetime.datetime.fromtimestamp(stamp).isoformat(),'snapshot_inputs':len(snapshot),'differences':bad,'deployed_inputs_newer_than_ff':newer,'missing_assets':missing,'shared_portal_complete_definitions_match':shared_portal_match,'replaced_placements':6,'game_launched':False,'native_visual_verified':False}
(OUT/'deployment_verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2));assert not bad and not newer and not missing
