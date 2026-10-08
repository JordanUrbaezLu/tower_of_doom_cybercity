"""Compact raised welding hood: continuous formed shell and recessed filter."""
import sys,importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import equipment;importlib.reload(equipment)
from equipment import *
assert REFERENCE==3
remove=('Head | welder hood','Head | recessed smoked welding','Head | thick visor','Head | exposed filter','Head | chamfered visor','Head | dark visor','Head | filter retention','Head | raised visor','Head | visor lift','Head | folded visor','Head | welder visor warning')
for ob in list(scene.objects):
    if 'attachment_bone' in ob and ob.name.startswith(remove):bpy.data.objects.remove(ob,do_unlink=True)
bone='j_head';p=Vector((0,-2.75,71.10));n=Vector((0,-.78,.625)).normalized();r,n,u,f=basis(n)
# Front perimeter is clipped at corners, reducing the television-like rectangle.
outer=[(-2.70,-1.63),(2.70,-1.63),(2.92,-1.36),(2.92,1.30),(2.67,1.59),(-2.67,1.59),(-2.92,1.30),(-2.92,-1.36)]
inner=[(-2.30,-1.20),(2.30,-1.20),(2.43,-1.05),(2.43,1.03),(2.27,1.18),(-2.27,1.18),(-2.43,1.03),(-2.43,-1.05)]
verts=[p+r*x+u*z+n*d for d,shape in ((0,outer),(.13,inner),(-.28,outer),(-.13,inner)) for x,z in shape]
faces=[]
for i in range(8):
    j=(i+1)%8;faces += [(i,j,8+j,8+i),(16+i,24+i,24+j,16+j),(i,16+i,16+j,j),(8+i,8+j,24+j,24+i)]
mesh('Head | finished welder hood formed front rim',verts,faces,ivory,bone,.035)
box('Head | finished welder hood recessed filter',p-n*.20,(4.85,.09,2.37),glass,bone,f,.05)
for sx in (-1,1):
    box('Head | finished welder hood filter retention',p+r*sx*2.48+n*.16,(.10,.10,2.56),edge,bone,f,.025)
    for z in (-1.11,1.11):bolt('Head | finished welder hood captive screw',p+r*sx*2.70+u*z+n*.16,n,bone,.10)
for z in (-1.27,1.27):box('Head | finished welder hood soot seal',p+u*z+n*.05,(4.96,.11,.10),rubber,bone,f,.015)
# Deep hood folds from the filter to the rear crown, with open underside.
for sx in (-1,1):
    coords=[(sx*2.89,-1.39,-.14),(sx*2.89,1.30,-.14),(sx*2.51,1.57,-1.38),(sx*1.97,.66,-2.60),(sx*2.17,-1.23,-2.38)]
    vs=[p+r*x+u*z+n*d for x,z,d in coords];vs += [v+r*sx*.14 for v in vs]
    mesh('Head | finished welder hood tapered cheek',vs,[(0,4,3,2,1),(5,6,7,8,9)]+[(i,(i+1)%5,(i+1)%5+5,i+5) for i in range(5)],ivory,bone,.045)
    tube('Head | finished welder hood rolled upper seam',[p+r*sx*x+u*z+n*d for x,z,d in ((2.86,1.32,-.15),(2.49,1.55,-1.38),(1.96,.66,-2.55))],.06,edge,bone,False)
    hp,hn=headpoint(sx*2,67.4,True,.80)
    endpoint=p+r*sx*2.20-u*.81-n*1.89
    # Flattened cast bracket joins the original rotary hub to the shell.
    vv=[hp+Vector((0,y,z)) for y,z in ((-.30,-.23),(.32,-.23),(.32,.23),(-.30,.23))]
    vv += [endpoint+Vector((0,y,z)) for y,z in ((-.30,-.23),(.32,-.23),(.32,.23),(-.30,.23))]
    mesh('Head | finished welder hood hinge bracket',vv,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],steel,bone,.05)
    for q in (endpoint,endpoint.lerp(hp,.25)):bolt('Head | finished welder hood bracket bolt',q+r*sx*.20,r*sx,bone,.13)
vs=[p+r*x+u*z+n*d for x,z,d in ((-2.87,1.32,-.10),(2.87,1.32,-.10),(2.50,1.59,-1.38),(1.96,.69,-2.60),(-1.96,.69,-2.60),(-2.50,1.59,-1.38))]
vs += [v-u*.13 for v in vs]
mesh('Head | finished welder hood crown roof',vs,[(0,1,2,3,4,5),(11,10,9,8,7,6)]+[(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)],ivory,bone,.045)
label('Head | finished welder hood serial','WELD / III',p+u*1.45+n*.08,n,.16,bone,u)

for ob in scene.objects:
    if ob.name.startswith(('Head | industrial chin collar latch','Head | collar latch screw')) and not ob.get('lowered_to_neck'):
        ob.location.z-=1.25;ob['lowered_to_neck']=True
camera((19,-62,70),(0,-.5,67),19)
save('03_completed_reference_three_armored_only')
