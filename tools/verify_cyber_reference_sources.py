"""Check that every atlas bake corresponds to the completed fitted master."""
import hashlib,json,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for folder in [ROOT/'art/cyber_zombie_mvp/engine_kit']+[ROOT/'art/cyber_zombie_roster/engine_kit'/v for v in ('trooper','signal','relay','sprinter')]:
    m=json.loads((folder/'source_manifest.json').read_text())
    if folder==ROOT/'art/cyber_zombie_mvp/engine_kit':
        assert m['revision']==5 and m['fit_pass']==2,folder
        assert Path(m['master'])==Path('art/cyber_reference_one_mcp/reference_one.blend')
        assert m['authoring_stage']=='10_reference_refinement'
        assert m['atlas_size']==4096
        assert m['lod_method']=='component_floor_v1'
        from cyber_equipment_layout import body_groups
        assert set(m['groups'])=={'head',*body_groups('crown','body')}
        counts=json.loads((folder/'lod_counts.json').read_text())
        totals=[sum(counts[str(i)].values()) for i in range(7)]
        assert totals[0]<=60000 and totals[3]<=9000 and totals[6]<=2000,totals
        assert all(a>=b>0 for a,b in zip(totals,totals[1:])),totals
        assert all(set(groups)==set(m['groups']) and min(groups.values())>0 for groups in counts.values())
    elif folder.name in ('trooper','relay','sprinter'):
        ref=3 if folder.name=='sprinter' else 2
        word='three' if ref==3 else 'two'
        assert m['revision']==6 and m['fit_pass']==ref,folder
        assert Path(m['master'])==Path('art/cyber_reference_'+word+'_mcp/reference_'+word+'.blend')
        assert m['authoring_stage']==('03_completed_reference_three_armored_only' if ref==3 else '03_completed_reference_two')
        assert m['atlas_size']==4096 and m['lod_method']=='component_floor_v1'
        assert m['reference_assignment']==('armored sprinter only' if ref==3 else 'regular zombies only')
        if ref==3:
            from cyber_arm_replacement import POLICY
            review=json.loads((ROOT/'art/cyber_reference_three_mcp/validation.json').read_text())
            assert m.get('arm_surface_replacement')==POLICY
            assert review.get('arm_surface_replacement')==POLICY
            assert review.get('forehead_shield_removed') is True
            from cyber_back_spikes import POLICY as BACK_SPIKE_POLICY
            assert m['back_spikes']==review['back_spikes']
            assert review['back_spikes']['policy']==BACK_SPIKE_POLICY
            assert review['back_spikes']['scale']==1.30 and review['back_spikes']['changed_vertices']==520
            assert len(review['back_spikes']['spikes'])==14 and review['visible_donor_deformations_verified']
            assert m['armored_helmet']==review['armored_helmet']
            assert m['armored_helmet']['policy']=='executioner_enclosed_v1'
            assert m['backpack_removal']==review['backpack_removal']
            assert m['armor_finish']==review['armor_finish']
            assert m['armor_finish']['policy']=='shared_worn_gunmetal_v1'
            assert m['backpack_removal']['tank_frame_plumbing_and_standoffs_removed']
            assert review['helmet_validation']['status']=='PASS'
            assert len(review['helmet_validation']['head_enclosure'])==3
            assert len(review['helmet_validation']['source_head_lod_enclosure'])==21
            assert review['helmet_validation']['eye_strength_vs_previous']==4
            assert m['emission_scale']==review['helmet_validation']['native_emission_scale']==16
            assert m['lod_preserve_largest']==['head']
            from cyber_references.verify_helmet_bake import verify as verify_helmet_bake
            verify_helmet_bake(folder)
        from cyber_equipment_layout import body_groups
        assert set(m['groups'])=={'head',*body_groups(folder.name,'body')}
        counts=json.loads((folder/'lod_counts.json').read_text())
        totals=[sum(counts[str(i)].values()) for i in range(7)]
        assert totals[0]<=60000 and totals[3]<=9000 and totals[6]<=2000,totals
        assert all(a>=b>0 for a,b in zip(totals,totals[1:])),totals
        assert all(set(groups)==set(m['groups']) and min(groups.values())>0 for groups in counts.values())
    else:
        assert m['revision']==4 and m['fit_pass']==3,folder
    assert sha(ROOT/m['master'])==m['master_sha256'],folder
    assert len(m['textures'])==5,folder
    for name,digest in m['textures'].items():
        p=ROOT/'model_export/tod_cyber_zombie/_images'/name
        assert sha(p)==digest,p
        assert struct.unpack('>II',p.read_bytes()[16:24])==(m['atlas_size'],m['atlas_size']),p
    assert set(m['groups'])==set(json.loads((folder/'lod_counts.json').read_text())['0']),folder
print('CYBER_REFERENCE_SOURCES_OK: 5 master/bake pairs; references 1/2 regular, reference 3 armored only; 20 detailed 4096 maps and 5 retained signal 2048 maps')
