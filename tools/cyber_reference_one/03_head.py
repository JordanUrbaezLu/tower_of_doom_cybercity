import sys, importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import lib
importlib.reload(lib)
from lib import *
for ob in list(scene.objects):
    if 'attachment_bone' in ob and ob.name.startswith('Head |'):bpy.data.objects.remove(ob,do_unlink=True)
bone='j_head'
for sx in (-1,1):
    p,n=headpoint(sx*2,66.5,True,.16)
    # Cast receiver: off-centre mounting lugs, stepped steel annuli, ceramic cover.
    cyl('Head | receiver cushion',p,1.05,.28,rubber,bone,n,32)
    cyl('Head | machined receiver housing',p+n*.18,.98,.46,steel,bone,n,32)
    ring('Head | receiver exposed bearing',p+n*.46,n,.76,.10,edge,bone)
    ring('Head | receiver luminous annulus',p+n*.52,n,.64,.073,cyan,bone)
    cyl('Head | recessed receiver cap',p+n*.53,.51,.18,steel,bone,n,28)
    cyl('Head | receiver central fastener',p+n*.64,.18,.065,edge,bone,n,8)
    for ang in (.15,1.7,3.3,4.85):
        rr,nn,uu,ff=basis(n);d=rr*math.sin(ang)+uu*math.cos(ang)
        bolt('Head | receiver face screw',p+d*.88+n*.46,n,bone,.090)
    # The vertical skull frame sits on measured head surfaces, not detached earcups.
    rail=[]
    for z in (64.8,66.0,67.3,68.45,69.4):
        hp,hn=headpoint(sx*2,z,True,.20);rail.append(hp)
        pp,rr,nn,uu,ff=panel('Head | skull rail armor tile',hp,hn,1.36,1.0,bone,steel,depth=.20,fasteners=False)
        if z in (64.8,67.3,69.4):bolt('Head | skull anchoring screw',pp+nn*.04,nn,bone,.13)
    tube('Head | continuous skull support',rail,.16,steel,bone)
    hp,hn=headpoint(sx*2,69.3,True,.24)
    label('Head | receiver number','N / 09',hp+hn*.25,hn,.17,bone)
    # Flexible magenta neural loop behind each ear, hardware at both ends.
    points=[p+Vector((0,.43,-.71))+n*.19,p+Vector((-sx*.12,1.60,-1.16)),p+Vector((-sx*.23,2.18,.10)),p+Vector((-sx*.08,1.45,1.82))]
    hose('Head | neural pressure loop',points,.22,magenta,bone,False)
    # Cheek plates follow actual head front and meet the lower jaw restraint.
    jaw=[]
    for x,z in ((sx*2.17,65.55),(sx*2.04,64.35),(sx*1.53,63.18)):
        hp,hn=headpoint(x,z,False,.18);jaw.append(hp)
        pp,rr,nn,uu,ff=panel('Head | articulated cheek plate',hp,hn,.94,1.28,bone,steel,Vector((-.2*sx,0,1)),depth=.23,fasteners=False)
        bolt('Head | cheek swivel',pp+uu*.30+nn*.025,nn,bone,.12)
        box('Head | cheek slit',pp+nn*.02-uu*.20,(.47,.025,.08),rubber,bone,ff,.008)
    tube('Head | cheek chassis',jaw,.14,edge,bone)
    # Diagonal temple-to-eye retaining links make the optic an attached device.
    if sx==1:
        hp,hn=headpoint(2.1,67.25,False,.24)
        rod('Head | optic hinge arm',p+n*.40+Vector((0,-.45,.60)),hp,.12,steel,bone)
        cyl('Head | optic adjustment wheel',hp,.24,.17,edge,bone,(0,-1,0),16)

p,n=headpoint(0,62.65,False,.19)
pp,r,n,u,f=panel('Head | mandibular chin bridge',p,n,2.9,.86,bone,steel,depth=.26)
panel('Head | worn chin latch',pp+n*.08,n,.75,.64,bone,edge,depth=.12,fasteners=False)
for sx in (-1,1):
    hp,hn=headpoint(sx*1.53,63.18,False,.25)
    rod('Head | jaw-to-chin strut',hp,pp+r*sx*1.26+u*.22,.14,steel,bone)
    bolt('Head | lower jaw rivet',pp+r*sx*1.1+n*.035,n,bone,.12)

# Fractured shield with an irregular silhouette, inset dark glass and varied cracks.
p,n=headpoint(1.12,66.30,False,.34)
outline=[(-.94,.91),(-.13,1.11),(.74,.93),(1.36,.29),(1.08,-.55),(.38,-1.01),(-.52,-.71),(-1.02,-.04)]
verts=[p+Vector((x,-.03-.15*x,z)) for x,z in outline]
mesh('Head | thick optical glass shield',verts,[tuple(range(len(verts)))],glass,bone)
for i in range(len(verts)):
    # Two broken rim spans remain absent at the bottom like a damaged sheet of glass.
    if i in (4,5):continue
    tube('Head | glass exposed luminous edge',[verts[i],verts[(i+1)%len(verts)]],.025,cyan,bone,False)
for i in (0,2,3,6):
    v=verts[i];panel('Head | optic perimeter retaining clip',v+Vector((0,-.09,0)),(0,-1,0),.25,.38,bone,steel,depth=.08,fasteners=False)
# Hand-authored crack paths from the sheet's star fracture; secondary branches vary in width.
paths=[
 [(-.83,.74),(-.44,.57),(-.18,.31),(.18,.16),(.35,-.08),(.77,-.39),(1.02,-.48)],
 [(-.06,1.03),(-.22,.67),(-.18,.31),(-.38,-.13),(-.12,-.44),(-.02,-.82)],
 [(.70,.88),(.61,.51),(.18,.16),(.07,-.08),(.35,-.08),(.47,-.52),(.38,-.94)],
 [(1.26,.27),(.84,.34),(.61,.51)],
 [(-.93,-.02),(-.60,.09),(-.38,-.13),(-.68,-.41),(-.49,-.66)],
 [(-.44,.57),(-.59,.82)],[(.84,.34),(.99,.02),(.77,-.39)],
 [(-.12,-.44),(.47,-.52)],[(.61,.51),(.91,.69)],
 [(-.60,.09),(-.65,.34),(-.44,.57)],[(.07,-.08),(-.12,-.44)],
 [(.18,.16),(.45,.22),(.84,.34)],[(.35,-.08),(.68,-.06),(.99,.02)]
]
for i,path in enumerate(paths):
    coords=[p+Vector((x,-.062-.15*x,z)) for x,z in path]
    tube('Head | fracture network '+str(i),coords,.013 if i<5 else .0065,crack,bone,False)
camera((21,-65,68),(0,-.5,66.3),13)
save('03_head_optic_jaw_neural_hardware')
