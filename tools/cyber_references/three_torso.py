import sys,importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import equipment;importlib.reload(equipment)
from equipment import *
assert REFERENCE==3
for ob in list(scene.objects):
    if 'attachment_bone' in ob:bpy.data.objects.remove(ob,do_unlink=True)
src=(ROOT/'tools/cyber_reference_one/01_body.py').read_text()
exec(src[src.index('def harness_lane'):src.index('# Broad transverse')],globals())
# The sprinter keeps its original vest, plates and spikes. New rig rests outside that armor.
p,r,n,u,f=torso_panel('Back | twin reservoir load frame',0,53,6.7,11.5,True,steel)
for sx in (-1,1):
    box('Back | reservoir suspension rail',p+r*sx*2.75+n*.20,(.36,.48,10.3),edge,frame=f)
    for z in (-4.6,-2.3,0,2.3,4.6):bolt('Back | suspension fastener',p+r*sx*2.75+u*z+n*.46,n,r=.14)
    q=p+r*sx*1.70+n*1.25
    cartridge('Back | large cyan industrial tank',q,n,1.25,8.4)
    for dz in (-3.55,3.55):
        # Substantial segmented clamps and locks visibly hold the tanks to the frame.
        panel('Back | industrial tank clamp',q+u*dz+n*.94,n,2.60,1.13,mat=ivory,depth=.26)
        for x in (-.90,.90):bolt('Back | clamp bolt',q+r*x+u*dz+n*1.26,n,r=.14)
    qcap=q+u*4.65
    cyl('Back | regulator valve body',qcap,.60,1.1,steel)
    cyl('Back | regulator handwheel',qcap+u*.65,.68,.14,edge)
    for a in (0,math.pi/2,math.pi,math.pi*1.5):
        rod('Back | regulator wheel spoke',qcap+u*.76,qcap+u*.76+Vector((math.cos(a)*.62,math.sin(a)*.62,0)),.065,steel)
    # Outward loop crosses the shoulder while staying outside the original spiked vest.
    points=[qcap+u*.25,skin(sx*4.1,59.0,True,1.35),skin(sx*5.3,57.8,True,1.28),skin(sx*5.0,53.3,True,1.15),p+r*sx*2.50-u*4.10+n*.95]
    ribbed_hose('Back | luminous tank supply hose',points,.25)
    q=p+r*sx*1.70-u*4.42+n*1.13
    pp,rr,nn,uu,ff=panel('Back | tank warning shield',q,n,2.25,1.63,mat=steel,depth=.27)
    for x in (-.65,-.10,.45):
        # Real diagonal paint strips with small flakes added by shared worn yellow shader.
        vs=[pp+rr*(x+dx)+uu*z+nn*.018 for dx,z in ((-.16,-.56),(.06,-.56),(.67,.56),(.45,.56))]
        mesh('Back | diagonal hazard stencil',vs,[(0,1,2,3)],yellow)
panel('Back | central pressure distributor',p-u*3.68+n*.55,n,1.16,3.32,mat=steel,depth=.67)
for z in (-4.72,-3.88,-3.04):glow_slot('Back | distributor pilot',p+u*z+n*1.28,n,.21,.22,color=amber)
label('Back | serial plate','INDUSTRIAL / 03',p-u*5.18+n*.38,n,.19)

# Neck collar follows the vest opening. Head-mounted latches are added with the visor pass.
for sx in (-1,1):
    pts=[skin(sx*3.1,59.1,False,.42),skin(sx*2.4,60.4,False,.36),skin(sx*1.7,61.7,False,.36)]
    tube('Collar | padded armored upright',pts,.30,steel)
    for q in (pts[0],pts[-1]):bolt('Collar | swivel fastener',q+Vector((0,-.29,0)),(0,-1,0),r=.17)
q=skin(0,60.0,False,.70)
pp,r,n,u,f=panel('Collar | cyan throat module',q,(0,-1,0),2.15,1.73,mat=steel,depth=.38)
panel('Collar | throat enamel rim',pp+n*.03,n,1.28,1.31,mat=ivory,depth=.10,fasteners=False)
glow_slot('Collar | bright cyan status window',pp+n*.17,n,.44,.80)
for sx in (-1,1):
    q=skin(sx*4.4,57.2,False,.70)
    pp,r,n,u,f=panel('Harness | industrial amber connector',q,(0,-1,0),1.05,1.56,mat=steel,depth=.26)
    glow_slot('Harness | double amber locator',pp+n*.04,n,.30,.66,color=amber)

# Two small hanging waist cylinders like the concept. Fits outside original belt and pouches.
q=skin(3.65,45.3,False,.92)
pp,r,n,u,f=panel('Waist | paired reserve cell cradle',q,(0,-1,0),2.76,3.65,mat=steel,depth=.35)
for x in (-.67,.67):cartridge('Waist | cyan belt reservoir',pp+r*x+n*.64,n,.47,3.1)

# The reference's large hazard case sits on the opposite thigh, clear of the hip joint.
bone='j_hip_ri';a,b,axis,length,front,right,point,radii=limb(bone,'j_knee_ri')
for t in (.20,.43):strap('Thigh | fitted industrial case harness',point,t,.78,length,bone)
hp,hn=point(.32,.70,.32)
pp,r,n,u,f=panel('Thigh | shock-mounted hazard equipment case',hp,hn,3.7,6.0,bone,steel,-axis,depth=.65)
panel('Thigh | case inset cover',pp+n*.06,n,2.90,5.14,bone,steel,-axis,depth=.17)
for x in (-1.25,1.25):
    for z in (-2.10,2.10):bolt('Thigh | case corner bolt',pp+r*x+u*z+n*.27,n,bone,.15)
for x in (-1.1,-.25,.60):
    vs=[pp+r*(x+dx)+u*z+n*.26 for dx,z in ((-.16,-.58),(.15,-.58),(.97,1.0),(.66,1.0))]
    mesh('Thigh | chipped diagonal hazard stripe',vs,[(0,1,2,3)],yellow,bone)
label('Thigh | warning stamp','CAUTION  /  115',pp-u*1.60+n*.27,n,.20,bone,-axis)
for t in (.20,.43):
    hp,hn=point(t,-.10,.23);buckle('Thigh | cargo harness buckle',hp,hn,bone,-axis)
camera((30,-126,62),(0,-.5,37),85)
save('01_twin_tanks_industrial_harness')
