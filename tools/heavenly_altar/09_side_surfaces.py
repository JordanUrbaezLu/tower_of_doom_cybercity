"""Finish the exposed depth surfaces found in the three-quarter inspection."""
import sys,importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import design_lib as D
importlib.reload(D)
from design_lib import *
D.group='16 Fitted side service armor'
def side_tile(name,origin,t,n,length,depth=11):
    origin,t,n=Vector(origin),Vector(t),Vector(n);v=Vector((0,1,0))
    points=[(-length*.5+1,-depth*.5), (length*.5-.7,-depth*.5),(length*.5,-depth*.5+.7),(length*.5,depth*.5-.7),(length*.5-.7,depth*.5),(-length*.5+.7,depth*.5),(-length*.5,depth*.5-.7),(-length*.5,-depth*.5+1)]
    def point(a,b,d):return origin+t*a+v*b+n*d
    N=len(points)
    verts=[point(a,b,d) for d in (0,.4) for a,b in points]
    fs=[tuple(range(N-1,-1,-1)),tuple(range(N,2*N))]+[(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)]
    mesh(name+' gold gasket',verts,fs,gold,.05)
    inset=[(a*.92,b*.9) for a,b in points]
    verts=[point(a,b,d) for d in (.45,.85) for a,b in inset]
    mesh(name+' ceramic cover',verts,fs,ivory,.08)
    tube(name+' service slit',[point(-length*.28,-depth*.22,.95),point(length*.22,-depth*.22,.95),point(length*.3,-depth*.08,.95)],.045,black,6)
    tube(name+' optical identification',[point(-length*.28,depth*.25,.96),point(length*.05,depth*.25,.96)],.06,cyan if length<8 else violet,6)
    for a in (-length*.32,length*.32):
        q=point(a,depth*.29,1)
        # Small hexagonal caps, aligned with the actual outward-facing side surface.
        ringpts=[q+t*(.14*math.cos(j*math.tau/6))+v*(.14*math.sin(j*math.tau/6)) for j in range(6)]
        mesh(name+' captive screw',ringpts,[tuple(range(6))],steel)
for s in (-1,1):
    # Each cover is fitted to the extrusion's own plane rather than a generic box.
    chain=[(25,16),(25,41),(50.5,65),(24,95)]
    for a,b in zip(chain,chain[1:]):
        A=Vector((s*a[0],0,a[1]));B=Vector((s*b[0],0,b[1]));t=(B-A).normalized();n=Vector((s*abs(t.z),0,-s*t.x)).normalized()
        count=max(2,int((B-A).length/8))
        for i in range(count):
            p=A.lerp(B,(i+.5)/count)+n*.2
            for yy in (-10,2):side_tile('Side frame | removable bay',p+Vector((0,yy,0)),t,n,(B-A).length/count-.7,10.5)
    A=Vector((s*39,0,106));B=Vector((s*36,0,114));t=(B-A).normalized();n=Vector((s*t.z,0,abs(t.x)))
    for yy in (-7,4):side_tile('Shoulder side | armored bay',(A+B)*.5+Vector((0,yy,0)),t,n,7.4,9.8)
    # Upper and lower flange planes carry transverse seams instead of broad blank surfaces.
    for yy in (-6,1,8):
        tube('Shoulder top | gold rail',[(s*19,yy,114.5),(s*35.5,yy,114.5)],.095,goldlight)
        tube('Shoulder top | narrow violet inset',[(s*25,yy+.25,114.6),(s*31,yy+.25,114.6)],.055,violet)
    A=Vector((s*46,0,2));B=Vector((s*40,0,10));t=(B-A).normalized();n=Vector((s*t.z,0,abs(t.x)))
    for yy in (-15,-3,9):side_tile('Foot side | removable cover',(A+B)*.5+Vector((0,yy,0)),t,n,8,10.5)
# The deep crest drum gets circumferential retention bands and radial service cassettes.
for i in range(20):
    a=(i+.5)*math.tau/20;n=Vector((math.cos(a),0,math.sin(a)));t=Vector((-math.sin(a),0,math.cos(a)))
    p=Vector((0,-12,104))+n*21.55
    side_tile('Crest drum | radial titanium cassette',p,t,n,5.5,8)
# Move the mid-height crystals onto the lower sloping jamb; no unsupported floating shelf.
for ob in list(D.collection('14 Inner crystal clusters').objects):
    if not ob.data.vertices:continue
    lo=min(v.co.z for v in ob.data.vertices);hi=max(v.co.z for v in ob.data.vertices)
    if lo>=65.4 and hi<80:
        for v in ob.data.vertices:v.co.z-=12
# A large studio floor avoids a hard background edge in oblique renders.
floor=bpy.data.objects['Altar review floor']
for v in floor.data.vertices:v.co.x*=15;v.co.y*=15
save('07 full-depth armor after three-quarter review')
