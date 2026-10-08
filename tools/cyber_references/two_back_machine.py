"""Reference-two spinal machine: layered chassis and asymmetric fluid routing.

Execute in the visible Blender MCP session after resume_two.py. Only the back
assembly is replaced; the original donor and all other equipment are preserved.
"""
import sys,importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import equipment;importlib.reload(equipment)
from equipment import *
assert REFERENCE==2
unchanged={o.name:signature(o) for o in scene.objects if o.type=='MESH' and 'attachment_bone' in o and not o.name.startswith('Back |')}
for ob in list(scene.objects):
    if 'attachment_bone' in ob and ob.name.startswith('Back |'):bpy.data.objects.remove(ob,do_unlink=True)
# Rear-view right is -X on this donor. Match the reference's paired tubes on
# rear-view left and regulator on rear-view right, not their mirror image.
n=Vector((0,1,0));u=Vector((0,0,1));r=Vector((-1,0,0));f=Matrix((r,n,u)).transposed()
p=skin(0,53.5,True,.24)
p.y=max(skin(x,z,True,.24).y for x in (-3.0,0,3.0) for z in (47,53.5,59.3))

def at(x=0,y=0,z=0):return p+r*x+n*y+u*z
def plate(name,shape,q,depth,material=steel):
    vs=[q+r*x+u*z+n*d for d in (0,depth) for x,z in shape];N=len(shape)
    return mesh('Back | '+name,vs,[tuple(range(N-1,-1,-1)),tuple(range(N,2*N))]+[(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)],material,bevel=.035)
def port(name,q,d,rad=.23):
    d=Vector(d).normalized()
    cyl('Back | '+name+' socket',q,rad*1.8,.28,steel,axis=d,sides=12)
    cyl('Back | '+name+' hex union',q+d*.22,rad*1.40,.31,edge,axis=d,sides=6)
    ring('Back | '+name+' elastomer seal',q+d*.41,d,rad*1.08,.05,rubber)
def pipe(name,coords,radius=.205):
    pts=[at(*v) for v in coords];ob=ribbed_hose('Back | '+name,pts,radius)
    ob['reference_two_route']=name
    for q,near in ((pts[0],pts[1]),(pts[-1],pts[-2])):port(name,q,(near-q).normalized(),radius)
    # Clamp actual sampled centerlines, never a second surface ray through clothing.
    centers=[sum((v.co for v in ob.data.vertices[i:i+10]),Vector())/10 for i in range(0,len(ob.data.vertices),10)]
    for t in (.28,.72):
        i=max(1,min(len(centers)-2,round((len(centers)-1)*t)));q=centers[i]
        direction=(centers[i+1]-centers[i-1]).normalized()
        rr,nn,uu,ff=basis(n,direction)
        box('Back | '+name+' hose saddle',q+n*(radius+.025),(.72,.13,.24),steel,frame=ff,bevel=.025)
        for sx in (-1,1):bolt('Back | '+name+' saddle bolt',q+rr*sx*.28+n*(radius+.11),n,r=.065)
    return ob

# Narrow spine with articulated lower sections; separate web pads nest into the
# old coat. Broad side shelves carry plumbing instead of two empty hose loops.
for sx in (-1,1):
    for z in (-7.4,-2.8,3.6,6.9):
        box('Back | padded harness standoff',at(sx*1.80,-.08,z),(.89,.27,1.12),web,frame=f)
        box('Back | isolation foot',at(sx*1.80,.16,z),(.63,.45,.61),steel,frame=f)
    box('Back | extruded chassis rail',at(sx*1.92,.45,-.45),(.36,.50,17.4),steel,frame=f)
    box('Back | rail exposed wear edge',at(sx*2.07,.70,-.40),(.065,.09,16.4),edge,frame=f,bevel=.018)
for z in (-8.2,-5.2,-2.2,1.1,4.9,7.3):
    box('Back | chassis crossmember',at(0,.37,z),(4.31,.61,.38),steel,frame=f)
for sx in (-1,1):
    # Open shelf rails leave the coat visible through the pipe network.
    for x in (sx*2.23,sx*3.89):
        box('Back | open side shelf upright',at(x,.43,.45),(.22,.34,12.25),steel,frame=f)
    for z in (-5.46,-2.1,2.05,6.15):
        box('Back | open side shelf crossbar',at(sx*3.06,.43,z),(1.95,.35,.27),steel,frame=f)
    for z in (-4.7,3.9):bolt('Back | shelf harness anchor',at(sx*3.04,.76,z),n,r=.14)

# Upper machine housing is an open thick frame around four deep louver pockets.
# Ivory edge pieces cover the dark cast core; each vent has a separate gasket,
# cyan chamber, inclined metal hood and captive hardware.
plate('upper cast machine body',[(-2.1,-.4),(2.1,-.4),(2.24,5.5),(1.8,6.8),(-1.72,6.8),(-2.24,5.5)],at(0,.56,0),.90,steel)
for sx in (-1,1):
    shape=[(-.32,-.2),(.32,-.2),(.35,5.47),(.13,6.22),(-.30,6.05)]
    plate('chipped ceramic louver side rail',shape,at(sx*1.87,1.43,.08),.24,ivory)
    for z in (.38,2.2,4.2,5.8):bolt('Back | louver frame recessed fastener',at(sx*1.87,1.72,z),n,r=.10)
for z in (1.00,2.28,3.56,4.84):
    box('Back | recessed vent black cavity',at(0,1.46,z),(3.16,.07,.88),rubber,frame=f,bevel=.10)
    box('Back | inset cyan coolant channel',at(0,1.51,z-.08),(2.49,.05,.35),cyan,frame=f,bevel=.07)
    # Tapered, sloped blade gives real depth in side/overhead views.
    coords=[(-1.57,.39),(1.57,.39),(1.47,.12),(-1.47,.12)]
    vs=[at(x,y,z+zz) for y in (1.55,1.98) for x,zz in coords]
    mesh('Back | inclined louver blade',vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],steel,bevel=.025)
    box('Back | louver blade rubbed lip',at(0,2.01,z+.16),(2.99,.065,.045),edge,frame=f,bevel=.012)
    for sx in (-1,1):bolt('Back | louver end screw',at(sx*1.59,1.74,z-.11),n,r=.075)
for z in (-.08,6.3):
    panel('Back | upper ceramic frame end cap',at(0,1.45,z),n,3.91,.74,mat=ivory,depth=.23)
label('Back | machine service stencil','REANIMATOR  /  II',at(0,1.72,6.22),n,.145)

# Lower spine: overlapping mechanical cassettes, visible side links, pivot pins,
# latch, copper bus strips and a substantial base plug. No simple radiator slab.
for i,z in enumerate((-1.55,-4.12,-6.71)):
    width=3.50-i*.26
    plate('vertebral machine casting '+str(i),[(-width*.5,-.91),(-width*.36,-1.18),(width*.36,-1.18),(width*.5,-.91),(width*.5,.87),(width*.36,1.11),(-width*.36,1.11),(-width*.5,.87)],at(0,.77,z),.84,steel)
    panel('Back | floating spine service cover',at(0,1.63,z),n,width-.50,1.60,mat=steel,depth=.23)
    for sx in (-1,1):
        box('Back | spine cassette edge cleat',at(sx*(width*.5-.26),1.90,z),(.22,.20,1.38),edge,frame=f)
        bolt('Back | service cover screw',at(sx*.87,1.99,z+.49),n,r=.105)
        cyl('Back | transverse articulation pin',at(sx*width*.5,1.04,z-.66),.24,.39,edge,axis=r,sides=20)
    box('Back | recessed cassette slot',at(0,1.89,z+.12),(1.47,.035,.38),rubber,frame=f,bevel=.04)
    box('Back | lower cassette release tongue',at(0,1.96,z-.34),(.66,.23,.26),edge,frame=f,bevel=.04)
    if i<2:
        for sx in (-1,1):
            a=at(sx*1.18,1.23,z-.83);b=at(sx*1.05,1.23,z-1.66)
            piston('Back | articulated spine link',a,b,.10)
    if i==1:
        label('Back | cassette serial','115 / PUMP',at(0,1.91,z+.40),n,.14)
    if i==2:
        glow_slot('Back | lower amber state light',at(.62,1.92,z+.02),n,.17,.35,color=amber)
for sx in (-1,1):
    rod('Back | exposed copper power bus',at(sx*.47,.83,-7.30),at(sx*.47,.83,.05),.075,edge)
    for z in (-6.1,-3.5,-.95):box('Back | bus insulating keeper',at(sx*.47,.91,z),(.25,.22,.24),rubber,frame=f)
panel('Back | lumbar anchoring shoe',at(0,.53,-8.42),n,3.1,1.0,mat=ivory,depth=.36)
panel('Back | base plug casting',at(0,1.28,-8.18),n,1.42,1.18,mat=steel,depth=.48)
for sx in (-1,1):bolt('Back | base plug captive screw',at(sx*.46,1.82,-8.18),n,r=.095)

# Offset upper cell is integral to a heavy nape carrier. No thin exposed poles.
plate('nape carrier tapered casting',[(-1.35,-1.5),(1.47,-1.5),(1.47,2.8),(.87,3.5),(-.99,3.1)],at(.40,.63,8.35),.76,steel)
for z in (7.48,8.24,9.0,9.76):
    box('Back | nape carrier cooling fin',at(.38,1.44,z),(2.31,.37,.15),edge,frame=f,bevel=.025)
q=at(.85,1.16,13.45)
panel('Back | upper cell cast cage',q,n,2.80,7.25,mat=steel,depth=.64)
for sx in (-1,1):
    box('Back | upper cell ivory side wall',q+r*sx*1.15+n*.69,(.30,.38,6.35),ivory,frame=f)
for x in (-.64,0,.64):
    box('Back | upper cell deep slot',q+r*x+n*.69,(.43,.13,5.57),rubber,frame=f,bevel=.04)
    box('Back | upper cell cyan plasma rod',q+r*x+n*.80,(.17,.09,5.12),cyan,frame=f,bevel=.05)
for z in (-3.22,3.22):
    panel('Back | upper cell bolted end cap',q+u*z+n*.55,n,2.87,.82,mat=ivory,depth=.34)
    for sx in (-1,1):bolt('Back | upper cell perimeter screw',q+r*sx*1.05+u*z+n*.93,n,r=.095)
for sx in (-1,1):
    a=at(sx*2.14,.65,5.6);b=q+r*sx*.85-u*3.15
    d=(b-a).normalized();rr,nn,uu,ff=basis(n,d)
    box('Back | continuous upper cell support beam',(a+b)/2,(.33,.42,(b-a).length+.15),steel,frame=ff)
    for v in (a,b):bolt('Back | upper carrier anchor',v+n*.30,n,r=.12)
label('Back | upper cell identification','NEURAL / 02',q+n*.96-u*3.25,n,.12)

# Small left-side induction chamber, with ribbed copper coils and twin outlets.
# The right-side unit is an amber regulator: intentionally different machinery.
copper=mat('reference two copper coil',(.22,.063,.030),'metal')
red=mat('reference two hot induction core',(.42,.026,.012),'light',1.1)
q=at(-3.15,1.06,4.36)
panel('Back | left induction chamber cradle',q-n*.2,n,1.82,3.62,mat=steel,depth=.32)
cyl('Back | left induction chamber core',q+n*.45,.52,2.22,steel)
for x in (-.32,0,.32):box('Back | induction red coil slit',q+r*x+n*.92,(.10,.06,1.58),red,frame=f,bevel=.02)
for z in (-.95,-.66,-.37,-.08,.21,.5,.79,.98):ring('Back | copper induction winding',q+n*.45+u*z,u,.56,.043,copper)
for z in (-1.21,1.21):
    cyl('Back | induction chamber flanged cap',q+n*.45+u*z,.66,.29,steel)
    ring('Back | induction cap rubbed seam',q+n*.45+u*z,u,.66,.055,edge)
for sx in (-1,1):rod('Back | induction chamber tie bolt',q+r*sx*.71+n*.58-u*1.35,q+r*sx*.71+n*.58+u*1.35,.075,edge)
q=at(3.15,1.04,4.0)
panel('Back | regulator service body',q-n*.13,n,1.95,3.3,mat=steel,depth=.53)
cyl('Back | regulator round gauge socket',q+n*.54,.65,.35,steel,axis=n,sides=32)
ring('Back | regulator bronze gauge bezel',q+n*.79,n,.50,.095,copper)
cyl('Back | regulator amber glass dial',q+n*.82,.41,.045,amber,axis=n,sides=32)
rod('Back | regulator dial needle',q+n*.86,q+n*.86+r*.16+u*.24,.033,steel,sides=10)
for angle in (-1.0,-.4,.2,.8):
    d=r*math.sin(angle)+u*math.cos(angle)
    rod('Back | regulator dial index',q+n*.86+d*.32,q+n*.86+d*.37,.019,steel,sides=8)
panel('Back | regulator lower union block',q-u*1.09+n*.20,n,1.23,.87,mat=ivory,depth=.49)

# Route the actual reference's paired descending supply lines separately from
# its lower cross-body return and opposite regulator hose. Endpoints join ports.
pipe('paired supply OUT',[(-3.43,1.64,3.03),(-3.59,1.69,1.47),(-3.60,1.71,-.40),(-3.34,1.76,-1.97),(-2.67,1.78,-2.92),(-1.60,1.38,-3.28)],.218)
pipe('paired supply IN',[(-2.78,1.67,3.03),(-2.89,1.79,1.43),(-2.91,1.80,-.34),(-2.67,1.91,-1.56),(-2.05,1.90,-2.18),(-1.63,1.61,-2.22)],.218)
pipe('lower flank return',[(-1.58,1.48,-5.51),(-2.94,1.27,-5.76),(-4.41,.97,-5.97),(-5.44,.37,-5.57),(-6.03,-.16,-4.50)],.235)
pipe('right regulator return',[(3.13,1.56,2.83),(3.22,1.51,1.22),(3.18,1.39,-.73),(2.87,1.33,-2.62),(2.92,1.30,-4.30),(2.42,1.40,-5.65),(1.41,1.40,-6.01)],.214)
pipe('upper neural jumper',[(-.18,1.71,10.09),(-1.0,1.81,10.16),(-1.94,1.73,9.04),(-2.56,1.57,7.71),(-2.65,1.41,6.05)],.19)
# Solid service manifolds physically terminate the lower plumbing.
for x,z in ((-1.68,-3.22),(-1.67,-2.23),(-1.54,-5.51),(1.48,-6.0)):
    panel('Back | hydraulic termination block',at(x,1.05,z),n,.72,.65,mat=edge,depth=.40,fasteners=False)
panel('Back | flank return belt anchor',at(-5.82,-.33,-4.73),n,1.38,1.36,mat=steel,depth=.32)
# Plain black sensor looms and rigid elbow tubes bring the back to life without
# turning every piece into an emissive line.
for x in (-.19,.17):
    tube('Back | ribbed black sensor loom',[at(x,.64,8.00),at(x-.33,.40,6.6),at(-1.13+x,.65,5.4)],.09,rubber)
for sx in (-1,1):
    tube('Back | rigid regulator bypass',[at(sx*2.08,.78,-.25),at(sx*2.4,.89,-.52),at(sx*2.42,.90,-1.22)],.09,edge,smooth=False)
    port('auxiliary diagnostic jack',at(sx*2.11,1.24,-7.24),n,.12)

assert unchanged=={o.name:signature(o) for o in scene.objects if o.type=='MESH' and 'attachment_bone' in o and not o.name.startswith('Back |')},'Unrelated equipment changed'
scene['reference_two_back_design']='layered spinal cassettes / paired descending lines / flank return / right regulator / supported neural cell'
scene['reference_two_nonback_signatures']=json.dumps(unchanged)
camera((31,95,67),(0,2,55.5),33)
save('03_completed_reference_two')
