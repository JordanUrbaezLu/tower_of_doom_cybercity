import sys,importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import equipment;importlib.reload(equipment)
from equipment import *
assert REFERENCE==2
# Each brace derives its own width from the actual limb surface.
for side in ('le','ri'):
    bone='j_elbow_'+side;a,b,axis,length,front,right,point,radii=limb(bone,'j_wrist_'+side)
    for t in (.15,.82):
        strap('Arm | individually fitted retaining cuff',point,t,.68,length,bone)
        hp,hn=point(t,.76,.23);buckle('Arm | cuff buckle',hp,hn,bone,-axis)
    fitted_shell('Arm | curved forearm frame',point,.21,.75,.55,1.70,bone,steel,.24)
    for angle in (-.05,1.15):
        start=point(.24,angle,.47)[0];end=point(.73,angle,.47)[0]
        piston('Arm | parallel brace actuator',start,end,.12,bone)
    hp,hn=point(.49,.58,.56)
    pp,r,n,u,f=panel('Arm | chipped asymmetric service cover',hp,hn,1.45,4.55,bone,ivory,-axis,depth=.24)
    # Light sits in the brace's outside channel, leaving original wrist exposed.
    glow_slot('Arm | recessed cyan cell slot',pp+r*.31+n*.07,n,.20,3.05,bone,-axis)
    for z in (-1.75,1.75):panel('Arm | end keeper',pp+u*z+n*.04,n,1.75,.64,bone,steel,-axis,depth=.20)
    label('Arm | maintenance legend','A-02',pp-r*.39+n*.26,n,.17,bone,-axis)
    ribbed_hose('Arm | purple return feed',[point(t,1.72,.33)[0] for t in (.19,.35,.57,.79)],.145,bone)
    hp,hn=point(.47,math.pi,.23)
    pp,r,n,u,f=panel('Arm | rear fitted service hatch',hp,hn,1.10,3.3,bone,steel,-axis,depth=.20)
    for z in (-1,-.5,0,.5,1):box('Arm | cooling groove',pp+u*z+n*.02,(.71,.025,.10),rubber,bone,f,.018)

for side in ('le','ri'):
    bone='j_knee_'+side;a,b,axis,length,front,right,point,radii=limb(bone,'j_ankle_'+side)
    for t in (.12,.49,.88):
        strap('Leg | tailored retaining strap',point,t,.77,length,bone)
        hp,hn=point(t,.95,.23);buckle('Leg | locking buckle',hp,hn,bone,-axis)
    fitted_shell('Leg | tapered structural shin bed',point,.24,.83,.12,1.58,bone,steel,.24)
    # Raised longitudinal ridge and beveled, tapering ivory sides create a shaped shin guard.
    start=point(.28,.13,.51)[0];end=point(.81,.13,.51)[0];up=(start-end).normalized()
    p=(start+end)/2;n=point(.54,.13,.5)[1];r,n,u,f=basis(n,up);height=(end-start).length
    shape=[(-.98,.45),(.77,.50),(1.03,.32),(.63,-.46),(.18,-.53),(-.70,-.43),(-1.02,.20)]
    vs=[p+r*x+u*z*height+n*(d+.18*(1-abs(x))) for d in (0,.20) for x,z in shape]
    count=len(shape);fs=[tuple(range(count-1,-1,-1)),tuple(range(count,count*2))]+[(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    mesh('Leg | sculpted chipped shin shell',vs,fs,ivory,bone,.05)
    glow_slot('Leg | offset cyan power channel',p+r*.36+n*.42,n,.19,height*.63,bone,up)
    for z in (-.36,.36):
        for x in (-.60,.63):bolt('Leg | removable shell screw',p+r*x+u*z*height+n*.37,n,bone,.12)
    hp,hn=point(.055,0,.49)
    pp,rr,nn,uu,ff=panel('Knee | articulated patella armor',hp,hn,3.35,2.4,bone,steel,-axis,depth=.30)
    panel('Knee | worn ivory patella face',pp+nn*.08,nn,2.48,1.76,bone,ivory,-axis,depth=.22)
    for angle in (-1.2,1.35):
        kp,kn=point(.075,angle,.34)
        cyl('Knee | rotary actuator housing',kp,.61,.42,steel,bone,kn,28)
        ring('Knee | exposed bearing ring',kp+kn*.28,kn,.44,.09,edge,bone)
        cyl('Knee | amber axle hub',kp+kn*.39,.16,.06,amber,bone,kn,20)
        aa=point(.20,angle,.35)[0];bb=point(.79,angle,.35)[0]
        piston('Leg | outboard telescopic support',aa,bb,.17,bone)
        ap,an=point(.85,angle,.35)
        cyl('Leg | ankle-end floating pivot',ap,.47,.34,steel,bone,an,24)
        ring('Leg | ankle-end bearing',ap+an*.23,an,.32,.07,edge,bone)
    label('Leg | shin service stamp','EXO / II',p-r*.45+u*height*.10+n*.38,n,.17,bone,up)

# Thigh cargo/control rigs, mounted on measured trousers with open steel buckles.
for side in ('le','ri'):
    bone='j_hip_'+side;a,b,axis,length,front,right,point,radii=limb(bone,'j_knee_'+side)
    for t in (.24,.47):strap('Thigh | fitted equipment belt',point,t,.76,length,bone)
    hp,hn=point(.35,1.1,.23)
    pp,r,n,u,f=panel('Thigh | strapped utility carrier',hp,hn,2.75,4.1,bone,web,-axis,depth=.32)
    panel('Thigh | scuffed steel battery case',pp+n*.07,n,2.20,3.30,bone,steel,-axis,depth=.39)
    buckle('Thigh | case buckle',pp+u*1.29+n*.48,n,bone,-axis)
    glow_slot('Thigh | amber charge marker',pp-u*.90+n*.49,n,.30,.55,bone,-axis,amber)
    for t in (.24,.47):
        hp,hn=point(t,.15,.22);buckle('Thigh | front belt buckle',hp,hn,bone,-axis)
camera((30,-126,62),(0,-.5,36),81)
save('02_fitted_forearms_double_leg_exoskeleton')
