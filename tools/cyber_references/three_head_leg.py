import sys,importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import equipment;importlib.reload(equipment)
from equipment import *
assert REFERENCE==3
bone='j_head'
# Raised welding visor with a shaped hood, opening, smoked filter and exposed hinges.
# Everything in this assembly follows j_head, including the rear helmet rails.
for sx in (-1,1):
    p,n=headpoint(sx*2,67.4,True,.27)
    cyl('Head | visor hinge padded socket',p,.86,.30,rubber,bone,n,32)
    cyl('Head | visor rotary hinge',p+n*.22,.72,.42,steel,bone,n,32)
    ring('Head | visor hinge retaining ring',p+n*.48,n,.50,.09,edge,bone)
    cyl('Head | visor hinge axle',p+n*.53,.24,.11,edge,bone,n,12)
    for angle in (.4,2.5,4.6):
        r,nn,u,f=basis(n);bolt('Head | hinge face screw',p+n*.47+(r*math.sin(angle)+u*math.cos(angle))*.55,n,bone,.09)
    hp,hn=headpoint(sx*2,65.3,True,.22)
    pp,r,nn,u,f=panel('Head | rectangular industrial receiver',hp,hn,1.52,2.05,bone,steel,depth=.43)
    panel('Head | receiver ivory bezel',pp+nn*.04,nn,1.14,1.68,bone,ivory,depth=.14)
    glow_slot('Head | cyan receiver glass',pp+nn*.22,nn,.38,.98,bone)
    hp,hn=headpoint(sx*2,68.7,True,.31)
    pp,r,nn,u,f=panel('Head | amber helmet locator',hp,hn,.94,1.06,bone,steel,depth=.25)
    glow_slot('Head | amber locator light',pp+nn*.04,nn,.22,.46,bone,color=amber)
    ribbed_hose('Head | purple welder neural feed',[p+Vector((0,.8,-1.4)),p+Vector((-sx*.15,2.0,-1.8)),p+Vector((-sx*.30,2.1,.3)),p+Vector((-sx*.18,.9,1.5))],.19,bone)
    # Swept helmet yoke wraps rearward and upward over the donor skull.
    rail=[headpoint(sx*2,z,True,.30)[0] for z in (66.8,68,69.0)]
    rail += [Vector((sx*1.65,1.10,70.6)),Vector((sx*.62,.80,71.0))]
    tube('Head | helmet crown rail',rail,.21,steel,bone)
    tube('Head | worn crown edge',[v+Vector((sx*.10,0,.10)) for v in rail],.060,edge,bone)
    for q in rail[1:3]:bolt('Head | yoke fastening screw',q+Vector((sx*.22,0,0)),(sx,0,0),bone,.13)

# Tilted shield: four thick frame rails around an actual recessed welding lens.
p=Vector((0,-3.0,71.9));n=Vector((0,-.83,.56)).normalized();r,n,u,f=basis(n)
W=6.65;H=4.32
box('Head | recessed smoked welding filter',p,(W-.72,.20,H-.77),glass,bone,f,.045)
for sx in (-1,1):
    box('Head | thick visor side armor',p+r*sx*W*.5+n*.06,(.49,.61,H+.38),ivory,bone,f,.08)
    box('Head | exposed filter retaining side',p+r*sx*(W*.5-.36)+n*.23,(.14,.15,H-.33),edge,bone,f,.025)
for z in (-H/2,H/2):
    box('Head | chamfered visor transverse armor',p+u*z+n*.07,(W+.33,.64,.48),ivory,bone,f,.075)
    box('Head | dark visor inner seal',p+u*(z-math.copysign(.30,z))+n*.17,(W-.35,.14,.12),rubber,bone,f,.015)
for sx in (-1,1):
    for z in (-H*.40,H*.40):bolt('Head | filter retention bolt',p+r*sx*W*.5+u*z+n*.41,n,bone,.13)
    hp,hn=headpoint(sx*2,67.4,True,.81)
    corner=p+Vector((sx*(W*.5-.10),0,0))-u*H*.37
    panel('Head | raised visor hinge cheek',(hp+corner)/2,(sx,0,0),2.1,4.1,bone,steel,Vector((0,.4,1)),depth=.22)
    rod('Head | visor lift linkage',hp,corner,.18,edge,bone)
# Thick roof and folded lateral wings give the lifted shield a real shell in profile.
for sx in (-1,1):
    corners=[p+r*sx*(W*.5)+u*z+n*d for z,d in ((-H*.5,-.2),(H*.5,-.2),(H*.42,-1.7),(-H*.42,-1.35))]
    verts=corners+[v+r*sx*.16 for v in corners]
    mesh('Head | folded visor sidewall',verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],steel,bone,.04)
label('Head | welder visor warning','WELD / 115',p+u*H*.52+n*.42,n,.21,bone,u)

# Sturdy collar latch beneath the chin. This moves with the head, above the fixed chest collar.
q,qn=headpoint(0,62.3,False,.34)
pp,rr,nn,uu,ff=panel('Head | industrial chin collar latch',q,qn,3.32,.79,bone,steel,depth=.30)
for sx in (-1,1):bolt('Head | collar latch screw',pp+rr*sx*1.18+nn*.03,nn,bone,.12)

# The industrial design has a single knee protector, over the armored donor's existing shin.
bone='j_knee_le';a,b,axis,length,front,right,point,radii=limb(bone,'j_ankle_le')
for t in (.13,.32,.86):
    strap('Leg | industrial fitted retaining belt',point,t,.82,length,bone)
    hp,hn=point(t,.9,.26);buckle('Leg | industrial belt buckle',hp,hn,bone,-axis)
fitted_shell('Knee | contoured industrial outer shell',point,.015,.23,0,1.90,bone,steel,.45)
hp,hn=point(.10,0,.90)
pp,rr,nn,uu,ff=panel('Knee | large worn ceramic kneecap',hp,hn,3.55,3.8,bone,ivory,-axis,depth=.26)
for x in (-1.3,1.3):
    box('Knee | inset side recess',pp+rr*x+nn*.04,(.16,.04,2.1),rubber,bone,ff,.015)
for angle in (-1.25,1.35):
    hp,hn=point(.14,angle,.39)
    cyl('Knee | brace swivel',hp,.56,.32,steel,bone,hn,28)
    ring('Knee | swivel wear ring',hp+hn*.22,hn,.39,.07,edge,bone)
    aa=point(.27,angle,.34)[0];bb=point(.76,angle,.34)[0]
    piston('Leg | industrial side support',aa,bb,.15,bone)
hp,hn=point(.52,1.02,.39)
pp,rr,nn,uu,ff=panel('Leg | small powered shin-side cover',hp,hn,1.03,4.70,bone,steel,-axis,depth=.22)
glow_slot('Leg | subtle cyan diagnostic slot',pp+nn*.035,nn,.16,3.25,bone,-axis)
label('Knee | industrial model stamp','MK / III',pp+uu*1.93+nn*.04,nn,.16,bone,-axis)
camera((30,-126,62),(0,-.5,37),86)
save('03_completed_reference_three_armored_only')
