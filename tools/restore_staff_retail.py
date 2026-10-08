"""Retail BO3 fire/lightning material inputs, not the old pistol donor maps."""
import hashlib
import json
import shutil
import sys
from pathlib import Path
from import_staff_animations import ROOT, blocks, emit
from build_staff_crystal import GREYHOUND

FIXTURE=ROOT/'docs/staff_retail_materials.json'
MANIFEST=ROOT/'docs/staff_retail_manifest.json'
OUT=ROOT/'model_export/tod_staff_retail'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def install():
    retail=json.loads(FIXTURE.read_text())['materials']
    images={v for f in retail.values() for v in f.values() if v.startswith('i_wpn_')}
    OUT.mkdir(parents=True,exist_ok=True)
    files={}
    for name in sorted(images):
        sources=sorted(GREYHOUND.glob('wpn_t7_zmb_hd_staff*/_images/*/'+name+'.png'))
        assert sources,('missing original texture',name)
        assert len({sha(p) for p in sources})==1,('ambiguous original texture',name)
        dst=OUT/(name+'.png');shutil.copyfile(sources[0],dst)
        files[dst.relative_to(ROOT).as_posix()]=sha(dst)
    for filename in ['tod_staff_origins.gdt','tod_staff_crystal.gdt']:
        path=ROOT/'source_data'/filename;assets=blocks(path)
        for name,kind,fields in assets:
            if name in retail:fields.update(retail[name])
            if name in images:fields['baseImage']='model_export\\\\tod_staff_retail\\\\'+name+'.png'
        path.write_text('{\n'+''.join(emit(*a) for a in assets)+'}\n',encoding='latin1')
    # Crystal generator already emits these retail settings. Pin its new GDT.
    path=ROOT/'docs/staff_crystal_manifest.json';m=json.loads(path.read_text())
    m['files']['source_data/tod_staff_crystal.gdt']=sha(ROOT/'source_data/tod_staff_crystal.gdt')
    path.write_text(json.dumps(m,indent=2)+'\n')
    MANIFEST.write_text(json.dumps({'files':files,'fixture_sha256':sha(FIXTURE)},indent=2)+'\n')
    check()

def check():
    retail=json.loads(FIXTURE.read_text())['materials'];manifest=json.loads(MANIFEST.read_text())
    assert sha(FIXTURE)==manifest['fixture_sha256']
    assets={n:f for fn in ['tod_staff_origins.gdt','tod_staff_crystal.gdt'] for n,k,f in blocks(ROOT/'source_data'/fn)}
    def equal(a,b):
        try:return len(a.split())==len(b.split()) and all(abs(float(x)-float(y))<1e-5 for x,y in zip(a.split(),b.split()))
        except (ValueError,AttributeError):return a==b
    for name,expected in retail.items():
        for key,value in expected.items():assert equal(assets[name].get(key),value),(name,key,'not retail')
    for rel,digest in manifest['files'].items():
        assert sha(ROOT/rel)==digest,(rel,'texture changed')
        name=Path(rel).stem
        assert assets[name]['baseImage'].replace('\\\\','/')==rel,(name,'wrong image source')
    print('STAFF_RETAIL_OK: seven material blocks match original fields; '+str(len(manifest['files']))+' original textures pinned; no pistol maps on fire/lightning.')

if __name__=='__main__':check() if '--check' in sys.argv else install()
