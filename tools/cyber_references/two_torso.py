import sys,importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import equipment;importlib.reload(equipment)
from equipment import *
assert REFERENCE==2
for ob in list(scene.objects):
    if 'attachment_bone' in ob:bpy.data.objects.remove(ob,do_unlink=True)
# The reference's harness follows the original clothing rather than floating above it.
src=(ROOT/'tools/cyber_reference_one/01_body.py').read_text()
exec(src[src.index('def harness_lane'):src.index('# Broad transverse')],globals())
for sx in (-1,1):
    p,r,n,u,f=torso_panel('Chest | twin cell suspension rail',sx*3.05,53.5,2.5,8.9,mat=steel)
    for dx in (-1.0,1.0):
        box('Chest | cage mounting rail',p+r*dx+n*.07,(.20,.25,7.5),edge,frame=f)
    top=cartridge('Chest | paired cyan power cylinder',p+n*.88,n,.83,6.7)
    for z in (-4.0,4.0):
        pp,rr,nn,uu,ff=panel('Chest | ivory manifold block',p+u*z+n*.35,n,2.2,1.15,mat=ivory,depth=.38)
        cyl('Chest | pressure port',pp+nn*.13,.25,.27,steel,axis=n,sides=12)
        label('Chest | cell stencil','C-02 / 115',pp+uu*.26+nn*.02,n,.17)
    q=p-u*3.9+n*.66
    pts=[q,q+Vector((sx*.35,0,-1.1)),skin(sx*4.7,48.6,False,1.0),skin(sx*6.3,50.5,False,.80)]
    ribbed_hose('Chest | purple lower return',pts,.21)
    # Front/rear shoulder mount includes a locking clevis and amber electrical connector.
    q=skin(sx*4.2,58.2,False,.40)
    panel('Collar | shoulder locking clevis',q,(0,-1,0),1.65,1.65,mat=steel,depth=.27)
    glow_slot('Collar | amber latch',q+Vector((0,-.36,.24)),(0,-1,0),.20,.53,color=amber)

# Open U-shaped powered neck cage; central throat and jaw remain visible.
for sx in (-1,1):
    pts=[skin(sx*4.0,58.0,False,.32),skin(sx*3.1,59.5,False,.36),skin(sx*2.4,61.0,False,.34)]
    tube('Collar | contoured armored upright',pts,.29,steel)
    tube('Collar | exposed seam rail',[v+Vector((sx*.22,-.05,0)) for v in pts],.065,edge)
    for q in (pts[0],pts[-1]):bolt('Collar | articulating anchor',q+Vector((0,-.31,0)),(0,-1,0),r=.19)
    glow_slot('Collar | status aperture',pts[1]+Vector((0,-.27,0)),(0,-1,0),.13,.48,color=amber)
q=skin(0,58.3,False,.62)
panel('Collar | lower throat bridge',q,(0,-1,0),4.8,.77,mat=steel,depth=.26)
for sx in (-1,1):bolt('Collar | bridge captive bolt',q+Vector((sx*1.84,-.31,0)),(0,-1,0),r=.13)

# Distinctive stacked back unit and the tall cell behind the head.
p,r,n,u,f=torso_panel('Back | spinal harness backplate',0,54.2,4.7,12.0,True,steel)
for sx in (-1,1):
    box('Back | structural outer spine',p+r*sx*2.0+n*.22,(.34,.55,10.8),edge,frame=f)
    for z in (-4.9,-2.5,0,2.5,4.9):bolt('Back | chassis fastener',p+r*sx*1.98+u*z+n*.57,n,r=.15)
panel('Back | distressed ceramic vent surround',p+n*.35+u*2.0,n,4.0,6.7,mat=ivory,depth=.48)
for z in (0,1.2,2.4,3.6):
    q=p+u*z+n*.90
    panel('Back | recessed louver well',q,n,3.0,.91,mat=steel,depth=.16,fasteners=False)
    glow_slot('Back | horizontal cyan cooling vent',q+n*.20,n,2.15,.29)
    box('Back | angled louver hood',q+u*.40+n*.27,(3.10,.46,.16),steel,frame=f)
panel('Back | lower regulator cover',p-u*3.8+n*.37,n,3.75,3.3,mat=steel,depth=.48)
for x in (-1.2,-.6,0,.6,1.2):box('Back | regulator cooling fin',p+r*x-u*3.8+n*.92,(.19,.45,2.50),edge,frame=f)
label('Back | serialized backplate','REANIMATOR / II',p-u*5.57+n*.58,n,.20)
# Cell stands proud of upper shoulder, with separate cage rather than a plain emissive block.
q=p+u*10.15+n*.45
panel('Back | tall rear head cell mount',q,n,2.65,6.7,mat=steel,depth=.45)
for sx in (-1,1):
    panel('Back | tall cell enamel flank',q+r*sx*1.13+n*.51,n,.42,5.9,mat=ivory,depth=.16,fasteners=False)
for x in (-.64,0,.64):glow_slot('Back | triple vertical cell',q+r*x+n*.54,n,.18,4.8)
for z in (-3.0,3.0):panel('Back | cell end manifold',q+u*z+n*.40,n,2.75,.90,mat=ivory,depth=.40)
for sx in (-1,1):
    q0=p+r*sx*2.3+u*3.7+n*.65
    ribbed_hose('Back | rib return plumbing',[q0,skin(sx*4.2,55.7,True,1.05),skin(sx*5.1,51.7,True,.9),skin(sx*3.2,49.0,True,1.15),p+r*sx*1.45-u*4.2+n*.95],.23)
    q=skin(sx*3.7,56.6,True,.72)
    cyl('Back | accumulator gauge case',q,.66,.45,steel,axis=n)
    ring('Back | gauge rim',q+n*.29,n,.46,.065,edge)
    cyl('Back | amber dial',q+n*.34,.37,.045,amber,axis=n)
    rod('Back | gauge needle',q+n*.38,q+Vector((sx*.14,.38,.23)),.035,steel,sides=8)

# Broad ivory pauldron on one side, sparse dark harness on the other.
for side in ('ri','le'):
    bone='j_shoulder_'+side;a,b,axis,length,front,right,point,radii=limb(bone,'j_elbow_'+side)
    if side=='ri':
        fitted_shell('Shoulder | large curved ivory housing',point,.16,.56,.55,2.35,bone,ivory,.40)
        fitted_shell('Shoulder | underlapping dark skirt',point,.48,.70,.60,2.0,bone,steel,.32)
        for t in (.19,.51):
            for ang in (-.52,1.56):
                hp,hn=point(t,ang,.70);bolt('Shoulder | housing capture bolt',hp,hn,bone,.18)
        hp,hn=point(.28,.53,.77)
        pp,rr,nn,uu,ff=panel('Shoulder | recessed light surround',hp,hn,1.10,3.75,bone,steel,-axis,depth=.18)
        glow_slot('Shoulder | long cyan status light',pp+nn*.05,nn,.23,2.8,bone,-axis)
        hp,hn=point(.22,-.25,.72);label('Shoulder | worn warning code','II / 115',hp,hn,.24,bone,-axis)
    else:
        strap('Shoulder | narrow device restraint',point,.34,.78,length,bone)
        hp,hn=point(.38,.65,.29)
        panel('Shoulder | small feed control',hp,hn,1.7,2.45,bone,steel,-axis,depth=.28)
        glow_slot('Shoulder | orange indicator',hp+hn*.33,hn,.20,1.10,bone,-axis,amber)
        ribbed_hose('Shoulder | exposed hydraulic feed',[point(t,1.20,.44)[0] for t in (.43,.56,.70,.90)],.16,bone)

camera((30,-126,62),(0,-.5,36),81)
save('01_twin_cells_spine_collar_shoulders')

