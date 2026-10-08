"""Replace both forearms and hands with complete elbow-to-tip spike swords."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from equipment import *
from cyber_arm_replacement import POLICY, arm_bone_names, replace_face
assert REFERENCE == 3
arm_bones = arm_bone_names({b.name: b.parent.name if b.parent else None for b in rig.data.bones})
for ob in list(scene.objects):
    if ob.name.startswith('Sword arm |') or ob.get('attachment_bone') in arm_bones or ob.get('arm_replacement_display'):
        bpy.data.objects.remove(ob, do_unlink=True)

# Retain immutable donors as hidden authoring references. The visible copies use
# the same arm-face mask as the native installer, with all other skin intact.
removed_display = {}
for donor in body:
    copy = donor.copy();copy.data = donor.data.copy()
    copy.name = 'Arm replacement | ' + donor.name.rsplit(' | ',1)[-1]
    copy['arm_replacement_display'] = POLICY
    copy['arm_replacement_donor'] = donor.name
    scene.collection.objects.link(copy)
    weights = [[(donor.vertex_groups[g.group].name, g.weight) for g in v.groups] for v in donor.data.vertices]
    removed = [p.index for p in donor.data.polygons
               if replace_face((weights[i] for i in p.vertices), arm_bones)]
    bm = bmesh.new();bm.from_mesh(copy.data);bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in removed], context='FACES_ONLY')
    bm.to_mesh(copy.data);bm.free();copy.data.update()
    copy.hide_render = False;copy.hide_set(False)
    donor.hide_render = True;donor.hide_set(True)
    removed_display[donor.name] = len(removed)
assert sum(removed_display.values()) > 1000, removed_display

blade = mat('scarred sword alloy', (.22,.25,.27), 'metal')
dark = mat('spike arm blackened forged roots', (.045,.055,.063), 'metal')

def blade_section(side, title, bone, start, end, sections, depth):
    axis = (end-start).normalized()
    normal = Vector((0,-1,0));normal = (normal-axis*normal.dot(axis)).normalized()
    across = axis.cross(normal).normalized()
    def v(d,w,z=0):return start+axis*d+across*w+normal*z
    verts=[]
    for d,w in sections:
        # The terminal ring tapers in depth as well as width: a sharp 3D spike.
        section_depth=min(depth,w*.55) if w<.10 else depth
        verts.extend((v(d,-w),v(d,0,section_depth),v(d,w),v(d,0,-section_depth*.62)))
    faces=[(3,2,1,0)]
    for j in range(len(sections)-1):
        for k in range(4):
            q=j*4+k;faces.append((q,j*4+(k+1)%4,(j+1)*4+(k+1)%4,(j+1)*4+k))
    q=(len(sections)-1)*4;faces.append((q,q+1,q+2,q+3))
    mesh('Sword arm | '+title+' '+side,verts,faces,blade,bone,.025)
    for sign in (-1,1):
        tube('Sword arm | uninterrupted honed edge '+title,
             [v(d,sign*w,.018) for d,w in sections],.075,edge,bone,False)
    tube('Sword arm | raised central spine '+title,
         [v(d,0,depth+.025) for d,w in sections[:-1]],.115,steel,bone,False)
    return axis,normal,across,v

for side in ('le','ri'):
    elbow='j_elbow_'+side;wrist='j_wrist_'+side
    b=rig.matrix_world@rig.data.bones[elbow].head_local
    c=rig.matrix_world@rig.data.bones[wrist].head_local
    length=(c-b).length
    reach=length+(19 if side=='le' else 21)
    axis,normal,across,v=blade_section(side,'full spike sword',elbow,b,c,
        [(-1.05,1.80),(length*.27,3.75),(length*.82,3.35),
         (length+7,2.55),(reach-5,1.1),(reach,.025)],1.22)
    # Keep the upper arm/sleeve. A sealed blade root closes its elbow cut, and
    # the complete lower limb follows that elbow instead of finger animation.
    cyl('Sword arm | sealed elbow blade socket',b+axis*.15,2.05,1.8,dark,elbow,axis,24)
    ring('Sword arm | elbow socket machined rim',b+axis*.90,axis,2.04,.14,edge,elbow)
    cyl('Sword arm | elbow front locking cap',b+normal*1.8,1.30,.22,steel,elbow,normal,20)
    bolt('Sword arm | elbow root axle fastener',b+normal*1.97,normal,elbow,.27)
    label('Sword arm | stamped root serial','SPK-'+('L' if side=='le' else 'R'),v(4.6,0,1.28),normal,.29,elbow,axis)
    # Broad root and continuous diamond-section blade replace forearm, wrist,
    # palm and fingers. No strap-on sword and no hand project from its surface.
    for sign in (-1,1):
        rod('Sword arm | recessed root fuller',v(1.7,sign*.95,.82),
            v(length+5,sign*.70,.82),.12,dark,elbow,8)
        for d in (2.0,length*.50,length*.90):
            bolt('Sword arm | lower blade retaining screw',v(d,sign*1.18,1.0),normal,elbow,.17)
    # Three forged back-edge teeth give the spike an aggressive saw silhouette.
    for d,w in ((length*.28,3.7),(length*.52,3.55),(length*.76,3.4)):
        tooth=[v(d-.7,-w,.10),v(d+.85,-w,.10),v(d-1.20,-w-1.20,.10)]
        mesh('Sword arm | forged root saw tooth '+side,tooth+[q-normal*.32 for q in tooth],
             [(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(2,5,3,0)],blade,elbow,.025)
    p=v(3,0,1.31)
    glow_slot('Sword arm | amber powered root',p,normal,.30,2.15,elbow,axis,color=amber)
scene['armored_sword_arms']=POLICY
scene['armored_arm_surface_replacement']=POLICY
scene['armored_display_removed_faces']=json.dumps(removed_display)
print('ARMORED_SPIKE_REPLACEMENT',json.dumps(removed_display),flush=True)
