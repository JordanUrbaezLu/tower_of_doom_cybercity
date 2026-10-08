"""Corrections from front/back renders: exposed optic cracks and reactor segmentation."""
import sys, importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import lib
importlib.reload(lib)
from lib import *
for ob in scene.objects:
    if ob.name.startswith('Head | thick optical'):
        for m in ob.modifiers:
            if m.type=='SOLIDIFY':
                # The face normal points into the head: thicken inward, away from the cracks.
                m.offset=1
for ob in list(scene.objects):
    if 'attachment_bone' in ob and ob.name.startswith(('Back | segmented','Back | pressure band','Hose | molded')):bpy.data.objects.remove(ob,do_unlink=True)
p,r,n,u,f=torso_panel('Back | segmented cell rear brace',0,53,1.3,7.6,True,steel)
# Get the actual stored chamber origin (the primitive can have local translation).
cell=next(o for o in scene.objects if o.name.startswith('Back | primary reactor inner light'))
world=[cell.matrix_world@v.co for v in cell.data.vertices]
c=sum(world,Vector())/len(world)
for z in (-1.75,0,1.75):
    cyl('Back | pressure band dark ferrule',c+Vector((0,0,z)),1.075,.24,steel,axis=(0,0,1),sides=32)
    for dz in (-.13,.13):ring('Back | pressure band worn lip',c+Vector((0,0,z+dz)),(0,0,1),1.04,.038,edge)

# Fine molded ribs follow the same smooth path as each magenta hose.
def ribbed(points,radius,bone):
    points=[Vector(p) for p in points];ext=[points[0]]+points+[points[-1]];ps=[]
    for i in range(1,len(ext)-2):
        a,b,c,d=ext[i-1:i+3]
        for j in range(24):
            t=j/24;ps.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
    ps.append(points[-1]);vs=[];fs=[];traveled=0
    for i in range(1,len(ps)-1):
        traveled+=(ps[i]-ps[i-1]).length
        if traveled<.16:continue
        traveled=0;p=ps[i];f=(ps[i+1]-ps[i-1]).to_track_quat('Z','Y').to_matrix();start=len(vs);N=14;K=4
        for a in range(N):
            for b in range(K):
                radial=radius+.012*math.cos(b*math.tau/K)
                vs.append(p+f@Vector((radial*math.cos(a*math.tau/N),radial*math.sin(a*math.tau/N),.012*math.sin(b*math.tau/K))))
        fs.extend((start+a*K+b,start+((a+1)%N)*K+b,start+((a+1)%N)*K+(b+1)%K,start+a*K+(b+1)%K) for a in range(N) for b in range(K))
    ob=mesh('Hose | molded corrugation',vs,fs,magenta,bone)
    for face in ob.data.polygons:face.use_smooth=True
bone='j_elbow_le';a,b,axis,length,front,right,point,radii=limb(bone,'j_wrist_le')
for ang in (1.05,1.70):ribbed([point(t,ang,.47)[0] for t in (.14,.30,.55,.80)],.18,bone)
bone='j_shoulder_le';a,b,axis,length,front,right,point,radii=limb(bone,'j_elbow_le')
for ang in (.65,1.20):ribbed([point(t,ang,.43)[0] for t in (.43,.58,.77,.93)],.19,bone)
for sx in (-1,1):
    p,n=headpoint(sx*2,66.5,True,.16)
    ribbed([p+Vector((0,.43,-.71))+n*.19,p+Vector((-sx*.12,1.60,-1.16)),p+Vector((-sx*.23,2.18,.10)),p+Vector((-sx*.08,1.45,1.82))],.22,'j_head')
camera((26,-86,63),(8,-5,51),35)
save('07_render_fit_corrections')
