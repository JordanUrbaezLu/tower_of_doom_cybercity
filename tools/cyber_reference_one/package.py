"""Verify final gallery images came from this saved MCP master and record hashes."""
import hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'art/cyber_reference_one_mcp'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
master_hash=sha(OUT/'reference_one.blend')
report=json.loads((OUT/'validation.json').read_text())
assert report['donor_geometry_and_weights_unchanged']
assert len(report['attachment_pose_checks'])==3
assert max(p['max_attachment_error'] for p in report['attachment_pose_checks'])<.003
assert report['reference_refinement']
assert 0 < report['magenta_emission_strength'] < 5
views=('front','back','arm','head','chest','back_detail','leg')
files=['reference_one.blend','CyberZombie1.png','review.html','README.md','validation.json','textures/prompts.json','textures/worn_steel_v1.png','textures/chipped_enamel_v1.png']
for view in views:
    image=OUT/(view+'.png');meta=OUT/(view+'.render.json')
    data=json.loads(meta.read_text())
    assert data['master_sha256']==master_hash,(view,'stale master')
    assert data['stage']=='10_reference_refinement',(view,'stale art stage')
    assert data['equipment_objects']==report['equipment_objects']
    assert data['image_sha256']==sha(image),(view,'stale image')
    with Image.open(image) as im:
        im.verify()
    files.extend((view+'.png',view+'.render.json'))
for name,info in report['surface_textures'].items():
    assert sha(OUT/'textures'/name)==info['sha256']
    with Image.open(OUT/'textures'/name) as im:assert list(im.size)==info['pixels']
assert sha(OUT/'CyberZombie1.png')==sha(Path('C:/Users/jorda/Downloads/CyberZombie1.png'))
native=report.get('game_integration')
if native:
    for view in ('front','arm','leg','lod3'):
        name='game_preview/export_'+view+'.png'
        with Image.open(OUT/name) as im:im.verify()
        files.append(name)
manifest={'status':'built for user playtest' if native else 'editable reference-one art master; not game-integrated','authoring':'upstream Blender MCP','game_launched':False,'gallery_views':len(views)+(4 if native else 0),'equipment_triangles':report['evaluated_equipment_triangles'],'game_integration':native,'files':{name:{'sha256':sha(OUT/name),'bytes':(OUT/name).stat().st_size} for name in files}}
(OUT/'delivery_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('REFERENCE_ONE_DELIVERY_OK',len(views),'fresh renders;',len(files),'artifacts;',report['equipment_objects'],'equipment objects; original donor preserved')
