"""Rigid equipment regions and their anatomical damage variants (no gameplay)."""
GROUP_BONES={'head':'j_head','helmet':'j_head','chest':'j_spine4',
    'arm':'j_elbow_le','rightarm':'j_elbow_ri',
    'shoulder_le':'j_shoulder_le','shoulder_ri':'j_shoulder_ri',
    'shin_le':'j_knee_le','shin_ri':'j_knee_ri','hip_le':'j_hip_le','hip_ri':'j_hip_ri',
    'hand_le':'j_wrist_le','finger_index_le':'j_index_le_1','finger_mid_le':'j_mid_le_1','finger_ring_le':'j_ring_le_1'}
LEFT_HAND=('hand_le','finger_index_le','finger_mid_le','finger_ring_le')
# Reference-one keeps each mechanical phalanx on its original finger joint.
# Reference three uses the same complete mechanical hand on the armored sprinter.
CROWN_HAND=LEFT_HAND+tuple('finger_'+finger+'_le'+('' if segment==1 else '_'+str(segment))
    for finger in ('thumb','index','mid','ring','pinky') for segment in (1,2,3)
    if not (finger in ('index','mid','ring') and segment==1))
for finger in ('thumb','index','mid','ring','pinky'):
    for segment in (1,2,3):
        GROUP_BONES['finger_'+finger+'_le'+('' if segment==1 else '_'+str(segment))]='j_'+finger+'_le_'+str(segment)
BODY_GROUPS={
    'crown':('chest','arm','shoulder_le','shoulder_ri','shin_le','hip_le')+CROWN_HAND,
    'trooper':('chest','arm','rightarm','shoulder_le','shoulder_ri','shin_le','shin_ri','hip_le','hip_ri'),
    'relay':('chest','arm','rightarm','shoulder_le','shoulder_ri','shin_le','shin_ri','hip_le','hip_ri'),
    'sprinter':('chest','arm','rightarm','shoulder_le','shin_le','hip_ri')}
def body_groups(style,part):
    groups=BODY_GROUPS[style]
    if part=='body':return groups
    if part in ('upper','rarmoff','larmoff'):
        groups=tuple(g for g in groups if not g.startswith(('shin_','hip_')))
        # Stock cuts at the elbow; the shoulder remains on the upper body.
        if part=='rarmoff':groups=tuple(g for g in groups if g!='rightarm')
        if part=='larmoff':groups=tuple(g for g in groups if g not in ('arm',)+CROWN_HAND)
        return groups
    groups=tuple(g for g in groups if g.startswith(('shin_','hip_')))
    # Knee cuts retain thigh/hip gear, including the two-leg-loss variant.
    if part=='rlegoff':groups=tuple(g for g in groups if g!='shin_ri')
    if part=='llegoff':groups=tuple(g for g in groups if g!='shin_le')
    if part=='nolegs':groups=tuple(g for g in groups if g.startswith('hip_'))
    return groups
