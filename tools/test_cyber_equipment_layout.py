"""Protect the stock elbow/knee cut contract when adding equipment regions."""
from cyber_equipment_layout import body_groups, LEFT_HAND, CROWN_HAND, GROUP_BONES

for style in ('crown','trooper','relay'):
    upper=set(body_groups(style,'upper'))
    lower=set(body_groups(style,'legs'))
    full=set(body_groups(style,'body'))
    assert upper.isdisjoint(lower) and upper | lower == full, style
    left=set(body_groups(style,'larmoff'))
    right=set(body_groups(style,'rarmoff'))
    hand=CROWN_HAND if style=='crown' else LEFT_HAND
    assert 'arm' not in left and left == upper-{'arm',*hand}, style
    assert 'rightarm' not in right and right == upper-{'rightarm'}, style
    assert {g for g in upper if g.startswith('shoulder_')} <= left & right, style
    assert set(body_groups(style,'nolegs')) == {g for g in lower if g.startswith('hip_')}, style
    assert set(body_groups(style,'rlegoff')) == lower-{'shin_ri'}, style
    assert set(body_groups(style,'llegoff')) == lower-{'shin_le'}, style
assert 'shoulder_ri' in body_groups('crown','body')
for finger in ('thumb','index','mid','ring','pinky'):
    for segment in (1,2,3):
        assert 'j_'+finger+'_le_'+str(segment) in {GROUP_BONES[g] for g in CROWN_HAND}
print('CYBER_ANATOMY_OK: intact and split bodies; elbow/knee cuts; shoulders and hips retained; all reference-one finger joints covered')
