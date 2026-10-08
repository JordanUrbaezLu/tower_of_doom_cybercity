"""Reference-three industrial pressure pack, authored through live Blender MCP.

This deliberately does not use the shared cartridge silhouette. The reference
has a short sight chamber, heavy lower vessels, one fluid feed and a metal arch.
"""
import sys, importlib
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import equipment; importlib.reload(equipment)
from equipment import *
assert REFERENCE == 3
for ob in list(scene.objects):
    if 'attachment_bone' in ob and ob.name.startswith('Back |'):
        bpy.data.objects.remove(ob, do_unlink=True)

n=Vector((0,1,0));u=Vector((0,0,1));r=Vector((1,0,0))
frame=Matrix((r,n,u)).transposed()
p=skin(0,53.2,True,.3)
p.y=max(skin(x,z,True,.3).y for x in (-3.8,0,3.8) for z in (48.0,53.2,58.5))

def turned(name,center,profile,material):
    """Machined vessel profile, including shoulders and beveled transitions."""
    N=40;verts=[]
    for z,rad in profile:
        verts += [center+u*z+(r*math.sin(i*math.tau/N)+n*math.cos(i*math.tau/N))*rad for i in range(N)]
    faces=[tuple(range(N-1,-1,-1)),tuple((len(profile)-1)*N+i for i in range(N))]
    faces += [(j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i) for j in range(len(profile)-1) for i in range(N)]
    ob=mesh(name,verts,faces,material)
    for face in ob.data.polygons:face.use_smooth=len(face.vertices)==4
    return ob

def arc_plate(name,q,z0,z1,rad,a0,a1,material,depth=.12):
    N=16;verts=[]
    for rr in (rad,rad+depth):
        for z in (z0,z1):
            verts += [q+u*z+(r*math.sin(a0+(a1-a0)*i/N)+n*math.cos(a0+(a1-a0)*i/N))*rr for i in range(N+1)]
    S=N+1;faces=[]
    for off in (0,2*S):
        faces += [(off+i,off+i+1,off+S+i+1,off+S+i) for i in range(N)]
    for off in (0,S):faces += [(off+i,off+i+1,off+i+1+2*S,off+i+2*S) for i in range(N)]
    for j in (0,N):faces.append((j,j+S,j+3*S,j+2*S))
    return mesh(name,verts,faces,material,bevel=.018)

# Open load frame: two rails, crossmembers and separately padded contact feet.
# The original vest remains visible through it; no featureless backing slab.
for sx in (-1,1):
    for z in (-4.9,4.8):
        box('Back | harness cushion',p+r*sx*3.2+u*z-n*.17,(1.05,.30,1.9),web,frame=frame)
        box('Back | folded mounting foot',p+r*sx*3.2+u*z+n*.14,(1.12,.62,.62),steel,frame=frame)
    box('Back | extruded frame upright',p+r*sx*3.38+n*.27,(.43,.61,12.25),steel,frame=frame)
    box('Back | rail abraded edge',p+r*sx*3.56+n*.60,(.07,.09,11.3),edge,frame=frame,bevel=.018)
    for z in (-5.30,-3.55,3.8,5.40):bolt('Back | frame captive anchor',p+r*sx*3.38+u*z+n*.61,n,r=.15)
for z in (-5.65,-2.85,3.4,5.50):
    box('Back | structural cross member',p+u*z+n*.38,(7.32,.66,.45),steel,frame=frame)
box('Back | central distribution spine',p+n*.65-u*.35,(.65,.61,11.7),edge,frame=frame)
for z in (-4.5,-1.2,2.1,4.9):
    box('Back | spine isolation mount',p+u*z+n*.83,(1.12,.53,.72),rubber,frame=frame)

centers=[]
for idx,sx in enumerate((-1,1)):
    q=p+r*sx*1.93+n*1.96;centers.append(q)
    prefix='Back | '+('left' if sx<0 else 'right')+' pressure vessel '
    # Full vessel is 12 units tall; illuminated sight chamber only 4.35 units.
    turned(prefix+'lower pressure housing',q,[(-5.65,1.03),(-5.5,1.36),(-5.27,1.48),(-2.50,1.48),(-2.27,1.34),(-2.08,1.34)],ivory)
    turned(prefix+'upper pressure housing',q,[(2.20,1.33),(2.35,1.49),(3.63,1.49),(3.88,1.34),(4.06,1.05)],ivory)
    turned(prefix+'stepped regulator crown',q,[(3.98,1.05),(4.16,1.19),(4.42,1.19),(4.56,.89),(5.15,.89),(5.34,.65),(5.51,.65)],steel)
    turned(prefix+'bottom sump and cap',q,[(-6.05,.69),(-5.98,.97),(-5.80,.97),(-5.63,1.21),(-5.49,1.21)],steel)
    # Dark outer glass edge surrounds the live fluid rather than solid white bars.
    cyl(prefix+'smoked chamber envelope',q,1.31,4.35,glass,sides=40)
    arc_plate(prefix+'cyan fluid sight chamber',q,-2.07,2.08,1.322,-1.22,1.22,cyan,.026)
    for z in (-2.22,2.27):
        cyl(prefix+'heavy split clamp',q+u*z,1.61,.38,steel,sides=40)
        ring(prefix+'clamp exposed rim',q+u*(z+.17),u,1.58,.055,edge)
        ring(prefix+'window black seal',q+u*(z-math.copysign(.24,z)),u,1.37,.08,rubber)
        # Rectangular clamp lugs + fasteners are distinct from cap geometry.
        for angle in (-1.05,1.05):
            d=r*math.sin(angle)+n*math.cos(angle)
            box(prefix+'clamp ear',q+u*z+d*1.49,(.47,.64,.55),steel,frame=basis(d)[3])
            bolt(prefix+'clamp lug screw',q+u*z+d*1.84,d,r=.15)
    # Four captive tie rods terminate in substantial lugs, not loose cage bars.
    for angle in (-1.14,1.14,2.2,4.08):
        d=r*math.sin(angle)+n*math.cos(angle)
        rod(prefix+'external tie rod',q+d*1.50-u*5.2,q+d*1.50+u*3.7,.083,edge)
        for z in (-5.20,-2.25,2.27,3.65):
            box(prefix+'rod captive lug',q+d*1.47+u*z,(.39,.39,.37),steel,frame=basis(d)[3])
            bolt(prefix+'lug retaining bolt',q+d*1.73+u*z,d,r=.10)
    for z in (-5.37,3.72):
        ring(prefix+'housing bolted flange',q+u*z,u,1.46,.10,steel)
        for angle in (-1.15,-.38,.38,1.15):
            d=r*math.sin(angle)+n*math.cos(angle)
            bolt(prefix+'housing perimeter screw',q+d*1.55+u*z,d,r=.115)
    # Curved access panel is part of the lower vessel, not a tiny dangling label.
    arc_plate(prefix+'lower access plate gasket',q,-5.07,-2.71,1.492,-.81,.81,rubber,.11)
    arc_plate(prefix+'ivory access plate',q,-4.98,-2.80,1.606,-.75,.75,ivory,.095)
    arc_plate(prefix+'hazard enamel field',q,-4.70,-3.02,1.708,-.55,.55,steel,.014)
    # Diagonal stripes follow cylinder curvature and terminate within the panel.
    for offset in (-1.42,-.49,.44,1.37):
        verts=[];faces=[];steps=24
        for j in range(steps+1):
            z=-4.66+1.60*j/steps
            for delta in (-.16,.16):
                x=max(-.83,min(.83,offset+(z+4.66)*.73+delta))
                angle=math.asin(x/1.728)
                verts.append(q+u*z+(r*math.sin(angle)+n*math.cos(angle))*1.731)
        for j in range(steps):
            if (verts[j*2]-verts[j*2+1]).length>.003 and (verts[j*2+2]-verts[j*2+3]).length>.003:faces.append((j*2,j*2+1,j*2+3,j*2+2))
        if faces:mesh(prefix+'curved chipped hazard paint',verts,faces,yellow)
    for ang in (-.69,.69):
        d=r*math.sin(ang)+n*math.cos(ang)
        for z in (-4.92,-2.88):bolt(prefix+'access panel screw',q+d*1.75+u*z,d,r=.095)
    label(prefix+'service stencil','PRESSURE / 115',q+n*1.71-u*2.72,n,.135)
    # Distinct caps: amber status window, bleed screw, hexagonal fill neck.
    pp,rr,nn,uu,ff=panel(prefix+'pilot housing',q+u*4.70+n*.87,n,.95,.79,mat=steel,depth=.22,fasteners=False)
    glow_slot(prefix+'amber pressure pilot',pp+n*.035,n,.31,.34,color=amber)
    cyl(prefix+'hexagonal fill connector',q+u*5.63,.48,.40,edge,sides=6)
    cyl(prefix+'capped fill port',q+u*5.92,.38,.18,steel,sides=16)
    for angle in (-.7,.7):
        d=r*math.sin(angle)+n*math.cos(angle)
        cyl(prefix+'bleed screw boss',q+u*3.1+d*1.49,.20,.24,steel,axis=d,sides=12)
        bolt(prefix+'bleed screw',q+u*3.1+d*1.66,d,r=.13)
    # A subdued dark scale and index marks reside on the glass itself.
    for z in (-1.55,-.94,-.33,.28,.89,1.50):
        a=.66;d=r*math.sin(a)+n*math.cos(a)
        box(prefix+'chamber calibration tick',q+d*1.365+u*z,(.25,.024,.040),edge,frame=basis(d)[3],bevel=.005)

# Bottom manifold joins both vessels, with a visible removable central cassette.
for q in centers:
    tube('Back | rigid sump elbow',[q-u*5.88,q-u*6.25+n*.12,p+n*2.05-u*6.25],.18,steel,smooth=False)
q=p+n*3.07-u*4.7
pp,rr,nn,uu,ff=panel('Back | central manifold casting',q,n,1.48,3.50,mat=steel,depth=.48)
panel('Back | manifold bolted cover',pp+n*.04,n,1.13,2.91,mat=edge,depth=.12)
panel('Back | warning plaque',pp+n*.20+u*.69,n,.91,.91,mat=steel,depth=.04,fasteners=False)
tri=[pp+n*.254+u*.69+r*x+u*z for x,z in ((-.32,-.25),(.32,-.25),(0,.32))]
mesh('Back | embossed yellow warning triangle',tri,[(0,1,2)],yellow)
label('Back | pressure warning exclamation','!',pp+n*.26+u*.58,n,.33,mat=steel)
box('Back | recessed latch pocket',pp+n*.23-u*.63,(.55,.12,.94),rubber,frame=frame)
box('Back | latch lever',pp+n*.35-u*.60,(.27,.21,.57),edge,frame=frame)
cyl('Back | latch hinge pin',pp+n*.37-u*.28,.11,.68,steel,axis=r,sides=16)
label('Back | manifold service identification','MK III',pp+n*.22-u*1.25,n,.17)

# Reference asymmetry: ONE purple loop at the powered-arm side. Opposite side
# is an ivory/metal lifting arch with exposed hinge, no mirrored fluid hose.
q=centers[1]
path=[q+u*5.57,p+r*2.15+n*2.10+u*7.65,p+r*3.65+n*1.8+u*7.84,p+r*4.64+n*1.3+u*6.02,p+r*4.95+n*1.40+u*2.1,p+r*4.85+n*1.18-u*1.40,p+r*4.45+n*.90-u*3.65]
h=ribbed_hose('Back | SINGLE purple pressure feed',path,.275)
h['reference_role']='single main purple backpack hose'
for z in (2.1,-1.40):
    panel('Back | feed guide clamp',p+r*4.93+n*1.53+u*z,n,.98,.62,mat=steel,depth=.15,fasteners=False)
q=centers[0]
arch=[q-u*.05+u*4.40,p-r*2.25+n*1.6+u*6.60,p-r*3.05+n*1.0+u*7.75,p-r*4.00+n*.64+u*7.20,p-r*4.26+n*.4+u*5.25]
for a,b in zip(arch[:-1],arch[1:]):
    d=(b-a).normalized();ff=Matrix((r,d.cross(r).normalized(),d)).transposed()
    box('Back | segmented metal lifting arch',(a+b)/2,(.53,.57,(b-a).length+.12),ivory,frame=ff,bevel=.065)
for q in (arch[1],arch[3],arch[-1]):
    cyl('Back | lifting arch hinge',q,.36,.61,steel,axis=n,sides=24)
    bolt('Back | lifting arch axle',q+n*.35,n,r=.17)
box('Back | lifting arch rubber grip',(arch[1]+arch[2])/2,(.64,.69,1.05),rubber,frame=Matrix((r,(arch[2]-arch[1]).normalized().cross(r).normalized(),(arch[2]-arch[1]).normalized())).transposed())

scene['reference_three_backpack_design']='short sight chambers / heavy hazard vessels / single purple feed / mechanical lifting arch'
assert sum(o.get('reference_role')=='single main purple backpack hose' for o in scene.objects)==1
camera((29,104,66),(0,3,55),32)
save('03_completed_reference_three_armored_only')
