"""Second reference-one art pass, executed in the user's live Blender MCP."""
import sys, importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import lib
importlib.reload(lib)
from lib import *

# Actual surface emission: this also illuminates nearby fittings in Cycles.
bs=magenta.node_tree.nodes['Principled BSDF']
nodes=magenta.node_tree.nodes;links=magenta.node_tree.links
for node in list(nodes):
    if node.name.startswith('Fluid glow |'):nodes.remove(node)
noise=nodes.new('ShaderNodeTexNoise');noise.name='Fluid glow | suspended particles'
noise.inputs['Scale'].default_value=12;noise.inputs['Detail'].default_value=4
links.new(nodes['Rest surface position'].outputs['Position'],noise.inputs['Vector'])
ramp=nodes.new('ShaderNodeValToRGB');ramp.name='Fluid glow | violet fluid density'
ramp.color_ramp.elements[0].position=.22;ramp.color_ramp.elements[0].color=(.055,.001,.047,1)
ramp.color_ramp.elements[1].position=.78;ramp.color_ramp.elements[1].color=(.48,.004,.33,1)
links.new(noise.outputs['Fac'],ramp.inputs[0]);links.new(ramp.outputs[0],bs.inputs['Emission Color'])
bs.inputs['Emission Strength'].default_value=2.6
magenta.diffuse_color=(.48,.004,.29,1)
ribmat=mat('pressure hose dark reinforcement',(.038,.004,.018),'rubber')
for ob in scene.objects:
    if ob.name.startswith('Hose | molded'):
        ob.data.materials[0]=ribmat

# Replace only the forearm assembly; preserve mechanical hand and upper-arm feeds.
for ob in list(scene.objects):
    bn=ob.get('attachment_bone')
    if (bn=='j_elbow_le' and ob.name.startswith(('Arm |','Hose | molded'))) or (bn=='j_knee_le' and ob.name.startswith(('Leg |','Knee |'))):
        bpy.data.objects.remove(ob,do_unlink=True)

bone='j_elbow_le'
a,b,axis,length,front,side,point,radii=limb(bone,'j_wrist_le')
for t in (.14,.84):
    strap('Arm | close fitted retaining cuff',point,t,.78,length,bone)
    for ang in (-.4,1.05,2.7,4.2):
        hp,hn=point(t,ang,.24)
        panel('Arm | riveted cuff saddle',hp,hn,.93,.68,bone,steel,-axis,depth=.13)

# The outboard normal faces away from the torso, between front and dorsal arm.
ang=1.05
start=point(.20,ang,.24)[0];end=point(.79,ang,.24)[0]
up=(start-end).normalized();normal=front*math.cos(ang)+side*math.sin(ang)
p,r,n,u,f=panel('Arm | lateral hydraulic cradle',(start+end)/2,normal,2.0,(end-start).length+.15,bone,steel,up,depth=.18)
cell=p+n*.50
cartridge('Arm | outboard cyan reservoir',cell,n,.57,4.55,bone,u)
# Narrow, offset armor cheeks expose the long cyan chamber, as in the reference.
for sx in (-1,1):
    q=p+r*sx*.91+n*.17
    panel('Arm | worn reservoir cheek',q,n,.43,4.05,bone,ivory,u,depth=.18,fasteners=False)
    for z in (-1.91,1.91):
        panel('Arm | end clamp bridge',q+u*z+n*.12,n,.79,.64,bone,ivory,u,depth=.20)
    piston('Arm | reservoir tie rod',q-u*1.61+n*.23,q+u*1.61+n*.23,.075,bone)
label('Arm | lateral cell service stencil','H-115',p+u*2.05+n*.87,n,.17,bone,u)

# Pressure lines run alongside, not through, the outer reservoir.
for angle in (-.35,.08):
    pts=[point(t,angle,.35)[0] for t in (.16,.31,.57,.82)]
    hose('Arm | luminous pressure feed',pts,.155,magenta,bone,False)
    for t in (.21,.74):
        hp,hn=point(t,angle,.39)
        panel('Arm | pressure line saddle',hp,hn,.57,.44,bone,steel,-axis,depth=.09,fasteners=False)
    # Sample the same spline as the tube so reinforcement hugs its bends.
    ext=[pts[0]]+pts+[pts[-1]];samples=[]
    for i in range(1,len(ext)-2):
        aa,bb,cc,dd=ext[i-1:i+3]
        for j in range(48):
            t=j/48
            samples.append(.5*((2*bb)+(-aa+cc)*t+(2*aa-5*bb+4*cc-dd)*t*t+(-aa+3*bb-3*cc+dd)*t*t*t))
    traveled=0
    for i in range(1,len(samples)-1):
        traveled+=(samples[i]-samples[i-1]).length
        if traveled<.32:continue
        traveled=0
        ring('Arm | dark feed reinforcement',samples[i],samples[i+1]-samples[i-1],.156,.018,ribmat,bone)
for angle in (2.55,3.7):
    aa=point(.18,angle,.25)[0];bb=point(.81,angle,.25)[0]
    piston('Arm | exposed rear actuator',aa,bb,.12,bone)
hp,hn=point(.49,math.pi,.20)
pp,rr,nn,uu,ff=panel('Arm | rear motor housing',hp,hn,1.15,3.65,bone,steel,-axis,depth=.20)
for z in (-.8,-.4,0,.4,.8):box('Arm | motor cooling recess',pp+uu*z+nn*.016,(.67,.04,.12),rubber,bone,ff,.018)

# Compound-profile metal shells: curved perimeter with a raised center ridge.
# Points are (horizontal, longitudinal), with depth controlled independently.
def shaped(name,p,n,up,outline,material,bone,depth=.20,crown=.12):
    r,n,u,f=basis(n,up);p=Vector(p);N=len(outline)
    vs=[p+r*x+u*z+n*d for d in (0,depth) for x,z in outline]
    vs.append(p+n*(depth+crown))
    fs=[tuple(range(N-1,-1,-1))]
    fs += [(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)]
    fs += [(N+i,N+(i+1)%N,2*N) for i in range(N)]
    ob=mesh(name,vs,fs,material,bone,.045)
    return p+n*(depth+crown),r,n,u,f

bone='j_knee_le'
a,b,axis,length,front,side,point,radii=limb(bone,'j_ankle_le')
for t in (.105,.49,.865):
    strap('Leg | fitted harness band',point,t,.72,length,bone)
    hp,hn=point(t,1.1,.25)
    panel('Leg | harness locking clasp',hp,hn,.96,.81,bone,steel,-axis,depth=.15)

# The backing follows the shin's changing width, rather than hovering as one slab.
outline=[(-1.40,4.9),(-1.76,3.9),(-1.49,1.5),(-1.18,-.2),(-.95,-4.55),(-.54,-5.0),(.74,-4.80),(1.03,-2.4),(1.53,.70),(1.62,3.6),(.98,4.85)]
start=point(.19,0,.20)[0];end=point(.84,0,.20)[0]
up=(start-end).normalized();p=(start+end)/2
p,r,n,u,f=shaped('Leg | tapered tibial foundation',p,front,up,outline,steel,bone,.20,.11)
# Two overlapping, asymmetrically cut enamel plates with a central folded ridge.
upper=[(-1.10,2.95),(-1.27,2.25),(-.94,.10),(-.28,-1.70),(.31,-1.78),(.72,-.88),(.94,1.90),(.48,2.94)]
shaped('Leg | sculpted upper tibial enamel',p+u*1.45+n*.13,n,u,upper,ivory,bone,.19,.29)
lower=[(-.51,1.30),(-.86,.68),(-.55,-1.89),(.03,-2.30),(.64,-1.92),(.77,.29),(.31,1.10)]
shaped('Leg | overlapping lower tibial enamel',p-u*2.11+n*.14,n,u,lower,ivory,bone,.18,.18)
for x,z in [(-.91,3.5),(.66,3.40),(-.60,.63),(.67,.50),(-.44,-3.51),(.51,-3.43)]:
    bolt('Leg | flush captive armor screw',p+r*x+u*z+n*.43,n,bone,.11)
label('Leg | upper service stencil','TIB / 01',p+u*2.8+n*.65,n,.18,bone,u)
for z in (-.25,-.55,-.85):
    box('Leg | central recessed vent',p+u*z+r*.05+n*.68,(.60,.055,.13),rubber,bone,f,.023)

# Single outer cyan rail, segmented casing, visible side hydraulic drive.
hp,hn=point(.53,1.00,.31)
pp,rr,nn,uu,ff=panel('Leg | outboard energy channel',hp,hn,.68,6.15,bone,steel,-axis,depth=.21)
box('Leg | side cyan light guide',pp+nn*.065,(.23,.10,4.86),cyan,bone,ff,.035)
for z in (-2.75,0,2.75):
    panel('Leg | rail retaining collar',pp+uu*z+nn*.07,nn,.83,.46,bone,ivory,uu,depth=.15,fasteners=False)
    bolt('Leg | rail collar fastener',pp+uu*z+rr*.27+nn*.25,nn,bone,.075)
aa=point(.17,1.65,.43)[0];bb=point(.83,1.65,.43)[0]
piston('Leg | exposed lateral hydraulic strut',aa,bb,.24,bone)
for t in (.22,.79):
    hp,hn=point(t,1.65,.47)
    panel('Leg | hydraulic anchor bracket',hp,hn,1.10,.86,bone,steel,-axis,depth=.16)

# Knee cup sits around the original knee, and overlaps the shin's upper flange.
hp,hn=point(.025,0,.28)
knee=[(-1.34,1.56),(-1.88,.69),(-1.62,-.92),(-.93,-1.72),(.51,-1.90),(1.46,-.90),(1.59,.83),(.82,1.58)]
kp,kr,kn,ku,kf=shaped('Knee | compound patella surround',hp,hn,-axis,knee,steel,bone,.26,.16)
inset=[(x*.79,z*.83) for x,z in knee]
shaped('Knee | folded ivory patella',kp+kn*.03,kn,ku,inset,ivory,bone,.20,.30)
for x,z in [(-.9,.85),(.80,.80),(-.57,-.91),(.61,-.85)]:
    bolt('Knee | recessed patella screw',kp+kr*x+ku*z+kn*.43,kn,bone,.12)
# Outboard ring bearing is recessed into its own side cheek, not attached to the front cap.
cp,cn=point(.085,1.50,.31)
cyl('Knee | outboard rotary chassis',cp,.90,.45,steel,bone,cn,40)
ring('Knee | concentric rubbed bearing',cp+cn*.26,cn,.65,.095,edge,bone)
cyl('Knee | central hub cover',cp+cn*.28,.49,.15,steel,bone,cn,32)
cyl('Knee | small cyan hub pilot',cp+cn*.37,.14,.035,cyan,bone,cn,24)
br,bn,bu,bf=basis(cn,-axis)
for k in range(6):
    ang=k*math.tau/6
    bolt('Knee | bearing ring screw',cp+cn*.29+(br*math.cos(ang)+bu*math.sin(ang))*.72,cn,bone,.075)
# Curved steel yoke links the patella to its outboard bearing around the cloth.
for t in (.015,.15):
    pts=[point(t,angle,.35)[0] for angle in (.12,.4,.75,1.10,1.47)]
    tube('Knee | wraparound patella yoke',pts,.15,steel,bone)
    for q in (pts[0],pts[-1]):bolt('Knee | yoke anchor',q,front,bone,.09)
for angle in (-.30,.30):
    aa=point(.13,angle,.50)[0];bb=point(.30,angle,.50)[0]
    piston('Knee | patella to tibia link',aa,bb,.12,bone)
# Offset knee-to-shin linkage and a compact inner hinge.
for angle,rad in ((1.50,.22),(-1.10,.13)):
    aa=point(.10,angle,.45)[0];bb=point(.33,angle,.40)[0]
    piston('Knee | articulated short linkage',aa,bb,rad,bone)
hp,hn=point(.875,0,.22)
panel('Leg | ankle cross clamp',hp,hn,2.36,.80,bone,steel,-axis,depth=.20)
for sx in (-1,1):
    pp=hp+side*sx*.79+hn*.30
    bolt('Leg | ankle clamp bolt',pp,hn,bone,.13)

assert json.loads(scene['donor_signatures'])=={o.name:signature(o) for o in base}
scene['reference_one_pass2']='Emissive purple plumbing, lateral forearm reservoir, sculpted knee and layered tibial armor'
save('10_reference_refinement')
print('PASS2_FITTING',json.dumps({'forearm_cell_angle_degrees':math.degrees(1.05),'magenta_emission_strength':2.6}))
