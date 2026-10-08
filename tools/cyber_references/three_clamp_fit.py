"""Mount saddles on the actual hose centerline, avoiding donor armor spikes."""
import sys,importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import equipment;importlib.reload(equipment)
from equipment import *
assert REFERENCE==3
for ob in list(scene.objects):
    if ob.name.startswith(('Arm | single feed steel saddle','Arm | saddle fastener','Arm | fitted hose saddle')):
        bpy.data.objects.remove(ob,do_unlink=True)
for bone,end,times in [('j_shoulder_le','j_elbow_le',(.39,.54,.72,.90)),('j_elbow_le','j_wrist_le',(.15,.31,.55,.79))]:
    a,b,axis,length,front,right,point,radii=limb(bone,end)
    hoses=[o for o in scene.objects if o.get('attachment_bone')==bone and o.name.split('.')[0]=='Arm | single industrial hydraulic feed']
    assert len(hoses)==1,(bone,[o.name for o in hoses])
    hose_ob=hoses[0];verts=hose_ob.data.vertices
    centers=[sum((hose_ob.matrix_world@v.co for v in verts[i:i+10]),Vector())/10 for i in range(0,len(verts),10)]
    for t in (.19,.81):
        i=max(1,min(len(centers)-2,round((len(centers)-1)*t)));hp=centers[i]
        tangent=(centers[i+1]-centers[i-1]).normalized()
        radial=(hp-a)-axis*(hp-a).dot(axis);hn=radial.normalized()
        # Saddle crosses the hose, and its feet hug the same route. No new
        # surface ray at a different t can accidentally land on a sharp spike.
        rr,nn,uu,ff=basis(hn,tangent)
        box('Arm | fitted hose saddle crossbar',hp+nn*.24,(.88,.12,.24),steel,bone,ff,.025)
        for sx in (-1,1):
            box('Arm | fitted hose saddle foot',hp+rr*sx*.34+nn*.08,(.19,.40,.29),steel,bone,ff,.025)
            bolt('Arm | fitted hose saddle anchor',hp+rr*sx*.34+nn*.29,nn,bone,.072)
save('03_completed_reference_three_armored_only')
