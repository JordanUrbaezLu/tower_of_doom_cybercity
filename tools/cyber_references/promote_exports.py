"""Promote reviewed reference-two/three derivatives into native roster inputs."""
import argparse,hashlib,json,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
parser=argparse.ArgumentParser();parser.add_argument('--reference',choices=('two','three'))
args=parser.parse_args()
for word,variants in [('two',('trooper','relay')),('three',('sprinter',))]:
    if args.reference and word!=args.reference:continue
    folder=ROOT/('art/cyber_reference_'+word+'_mcp');src=folder/'engine_kit'
    manifest=json.loads((src/'source_manifest.json').read_text())
    review=json.loads((folder/'validation.json').read_text())
    assert sha(ROOT/manifest['master'])==manifest['master_sha256']==review['master_sha256']
    assert review['stock_geometry_and_weights_unchanged'] and max(p['maximum_attachment_error'] for p in review['pose_checks'])<.003
    if word=='three':
        import sys
        sys.path.insert(0,str(ROOT/'tools'))
        from cyber_arm_replacement import POLICY
        assert review.get('arm_surface_replacement')==POLICY
        assert review.get('forehead_shield_removed') is True
        assert sum(review['visible_donor_arm_faces_removed'].values())>1000
        from cyber_back_spikes import POLICY as BACK_SPIKE_POLICY
        assert review['back_spikes']['policy']==BACK_SPIKE_POLICY
        assert review['back_spikes']['scale']==1.30 and review['back_spikes']['changed_vertices']==520
        assert len(review['back_spikes']['spikes'])==14 and review['visible_donor_deformations_verified']
        assert review['armored_helmet']['policy']=='executioner_enclosed_v1'
        assert review['helmet_validation']['status']=='PASS'
        assert len(review['helmet_validation']['head_enclosure'])==3
        assert len(review['helmet_validation']['source_head_lod_enclosure'])==21
        assert review['helmet_validation']['eye_strength_vs_previous']==4
        assert manifest['armored_helmet']==review['armored_helmet']
        assert manifest['backpack_removal']==review['backpack_removal']
        assert manifest['armor_finish']==review['armor_finish']
        assert manifest['armor_finish']['policy']=='shared_worn_gunmetal_v1'
        assert review['backpack_removal']['tank_frame_plumbing_and_standoffs_removed']
        assert manifest['emission_scale']==16
        assert manifest['lod_preserve_largest']==['head']
    primary=variants[0]
    for variant in variants:
        dst=ROOT/'art/cyber_zombie_roster/engine_kit'/variant;dst.mkdir(exist_ok=True,parents=True)
        for p in src.glob('*.json'):
            if p.name!='source_manifest.json':shutil.copy2(p,dst/p.name)
        m=dict(manifest);m['textures']={};m['reference_assignment']='armored sprinter only' if word=='three' else 'regular zombies only'
        if word=='three':
            m['arm_surface_replacement']=review['arm_surface_replacement']
            m['back_spikes']=review['back_spikes']
        for name,digest in manifest['textures'].items():
            p=src/'_images'/name;assert sha(p)==digest
            filename=name.replace('i_tod_roster_'+primary+'_','i_tod_roster_'+variant+'_')
            target=ROOT/'model_export/tod_cyber_zombie/_images'/filename;shutil.copy2(p,target)
            m['textures'][filename]=digest
        (dst/'source_manifest.json').write_text(json.dumps(m,indent=2)+'\n')
    review['native_exported']=True;review['native_playtested']=False
    review['equipment_lod_triangles']=[sum(v.values()) for v in json.loads((src/'lod_counts.json').read_text()).values()]
    (folder/'validation.json').write_text(json.dumps(review,indent=2)+'\n')
print('REFERENCE_EXPORTS_PROMOTED:',args.reference or 'two and three','; regular=two; armored=three')
