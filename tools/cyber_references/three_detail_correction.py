"""Remove mirrored plumbing and finish the reference-three welder shell."""
import sys,importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import equipment;importlib.reload(equipment)
from equipment import *
assert REFERENCE==3
for ob in list(scene.objects):
    if 'attachment_bone' not in ob:continue
    if ob.name.startswith(('Arm | glowing purple hydraulic feed','Arm | purple upper hydraulic supply','Arm | hose clamp','Arm | upper supply clamp','Head | welder hood')):
        bpy.data.objects.remove(ob,do_unlink=True)
    elif ob.name.startswith('Head | purple welder neural feed'):
        center=sum((ob.matrix_world@v.co for v in ob.data.vertices),Vector())/len(ob.data.vertices)
        if center.x<0:bpy.data.objects.remove(ob,do_unlink=True)

# One supply run down the powered arm; articulated sections remain bound to
# their own bones. Short slack bends clear the elbow and cuff joints.
for bone,end,times in [('j_shoulder_le','j_elbow_le',(.39,.54,.72,.90)),('j_elbow_le','j_wrist_le',(.15,.31,.55,.79))]:
    a,b,axis,length,front,right,point,radii=limb(bone,end)
    angle=1.20
    ribbed_hose('Arm | single industrial hydraulic feed',[point(t,angle,.59)[0] for t in times],.205,bone)
    for t in (times[0]+.04,times[-1]-.04):
        hp,hn=point(t,angle,.66)
        pp,rr,nn,uu,ff=panel('Arm | single feed steel saddle',hp,hn,.91,.53,bone,steel,-axis,depth=.15,fasteners=False)
        for sx in (-1,1):bolt('Arm | saddle fastener',pp+rr*sx*.34+nn*.02,hn,bone,.075)

# Raised shield gets a continuous folded top and tapered cheeks, not a flat
# rectangular display. The original filter/frame and rotation pivots stay.
bone='j_head';p=Vector((0,-3.0,71.9));n=Vector((0,-.83,.56)).normalized();r,n,u,f=basis(n)
W=6.65;H=4.32
def shell(name,coords,material,thickness=.13):
    vertices=[p+r*x+u*z+n*d for x,z,d in coords]
    back=[v-u*thickness for v in vertices];N=len(vertices)
    fs=[tuple(range(N-1,-1,-1)),tuple(range(N,2*N))]+[(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)]
    mesh('Head | welder hood '+name,vertices+back,fs,material,bone,.045)
shell('folded roof',[(-3.32,2.20,.09),(3.32,2.20,.09),(3.05,2.47,-.89),(2.28,2.03,-2.16),(-2.28,2.03,-2.16),(-3.05,2.47,-.89)],ivory)
for sx in (-1,1):
    # Smaller inset reinforcing cheek over the existing broad folded sidewall.
    coords=[(sx*3.39,-1.53,-.44),(sx*3.39,1.72,-.45),(sx*3.20,1.90,-1.35),(sx*2.45,.88,-2.04),(sx*2.52,-1.25,-1.67)]
    vertices=[p+r*x+u*z+n*d for x,z,d in coords]
    vertices+= [v+r*sx*.12 for v in vertices]
    mesh('Head | welder hood shaped enamel cheek',vertices,[(0,4,3,2,1),(5,6,7,8,9)]+[(i,(i+1)%5,(i+1)%5+5,i+5) for i in range(5)],ivory,bone,.045)
    for z,d in ((1.50,-.78),(-1.15,-.81),(.75,-1.50)):
        bolt('Head | welder hood side rivet',p+r*sx*3.47+u*z+n*d,r*sx,bone,.11)
    # Raised rolled seam protects the upper fold from impact.
    tube('Head | welder hood rolled roof seam',[p+r*sx*x+u*z+n*d for x,z,d in ((3.22,2.21,.05),(2.97,2.43,-.91),(2.27,2.06,-2.08))],.065,edge,bone,False)

scene['reference_three_plumbing']='one backpack feed, one powered-arm supply route, one head neural loop'
camera((29,104,66),(0,3,55),32)
save('03_completed_reference_three_armored_only')
