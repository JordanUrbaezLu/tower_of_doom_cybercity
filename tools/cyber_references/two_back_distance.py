"""Regenerate distance meshes from the finished bake; preserve LOD0 and pixels."""
import json,runpy,sys,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from cyber_reference_one.native_geometry import clean
stage=ROOT/'art/cyber_reference_two_mcp/engine_kit'
out=ROOT/'tmp/reference_two_back_machine_20260916/distance_lods'
floors={'chest':(0,.025,.18,1.0,2.5,5.0,12.0)}
runpy.run_path(str(ROOT/'tools/cyber_reference_one/reduce_game_lods.py'),run_name='__main__',init_globals={'CYBER_LOD_SOURCE':stage,'CYBER_LOD_OUTPUT':out,'CYBER_LOD_AREA_FLOORS':floors})
for p in out.glob('*.json'):shutil.copy2(p,stage/p.name)
counts=json.loads((stage/'lod_counts.json').read_text())
for lod,groups in counts.items():
    for group in groups:
        p=stage/(group+'_lod'+lod+'.json');data=clean(json.loads(p.read_text()),min_altitude=.002)
        p.write_text(json.dumps(data,separators=(',',':')));groups[group]=len(data['faces'])
(stage/'lod_counts.json').write_text(json.dumps(counts,indent=2)+'\n')
m=json.loads((stage/'source_manifest.json').read_text());m['lod_area_floors']=floors
(stage/'source_manifest.json').write_text(json.dumps(m,indent=2)+'\n')
totals=[sum(counts[str(i)].values()) for i in range(7)]
print('REFERENCE_TWO_BACK_DISTANCE_TOTALS',totals,flush=True)
assert totals[0]<=60000 and totals[3]<=9000 and totals[6]<=2000,totals
