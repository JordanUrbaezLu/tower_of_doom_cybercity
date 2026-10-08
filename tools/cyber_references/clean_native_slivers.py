"""Apply the final R2 exporter cleanup to an existing bake without rebaking pixels."""
import json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools'))
from cyber_reference_one.native_geometry import clean
stage=ROOT/'art/cyber_reference_two_mcp/engine_kit'
counts=json.loads((stage/'lod_counts.json').read_text());removed={}
for lod,groups in counts.items():
    removed[lod]={}
    for group in groups:
        path=stage/(group+'_lod'+lod+'.json');data=json.loads(path.read_text());before=len(data['faces'])
        data=clean(data,min_altitude=.002);groups[group]=len(data['faces']);removed[lod][group]=before-groups[group]
        assert groups[group]>0
        path.write_text(json.dumps(data,separators=(',',':')))
(stage/'lod_counts.json').write_text(json.dumps(counts,indent=2)+'\n')
(ROOT/'tmp/reference_23_integration/sliver_cleanup.json').write_text(json.dumps(removed,indent=2)+'\n')
print('REFERENCE_TWO_MICRO_SLIVERS_CLEANED',json.dumps({lod:sum(v.values()) for lod,v in removed.items()}))
