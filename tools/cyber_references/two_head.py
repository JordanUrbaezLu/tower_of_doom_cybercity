import sys,importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import equipment;importlib.reload(equipment)
from equipment import *
assert REFERENCE==2
for ob in list(scene.objects):
    if ob.get('attachment_bone')=='j_head':bpy.data.objects.remove(ob,do_unlink=True)
for ob in base:
    if 'helmet' in ob.name.lower():ob.hide_render=True;ob.hide_set(True);ob['preview_hidden_for_bare_head']=True
bone='j_head'
for sx in (-1,1):
    p,n=headpoint(sx*2,66.5,True,.17)
    cyl('Head | skull-mounted receiver cushion',p,.79,.24,rubber,bone,n,32)
    cyl('Head | skull-mounted receiver case',p+n*.17,.74,.30,steel,bone,n,32)
    ring('Head | exposed receiver bearing',p+n*.36,n,.58,.07,edge,bone)
    cyl('Head | inset receiver cover',p+n*.40,.43,.08,steel,bone,n,24)
    for ang in (.2,2.25,4.3):
        r,nn,u,f=basis(n);bolt('Head | receiver screw',p+n*.38+(r*math.sin(ang)+u*math.cos(ang))*.62,n,bone,.09)
    # Angular cheek implants are fitted to the sides of the head, leaving the face open.
    for z in (63.8,65.0,67.9):
        hp,hn=headpoint(sx*2,z,True,.18)
        pp,r,nn,u,f=panel('Head | riveted cranial plate',hp,hn,1.38,1.50,bone,steel,depth=.19,fasteners=False)
        for zz in (-.44,.44):bolt('Head | cranial plate anchor',pp+u*zz+nn*.04,nn,bone,.105)
        if z==67.9:
            panel('Head | distressed enamel temple inset',pp+nn*.05,nn,.67,.79,bone,ivory,depth=.08,fasteners=False)
    points=[]
    for z in (63.8,65,66.4,67.8,69.2):points.append(headpoint(sx*2,z,True,.22)[0])
    tube('Head | skull support rail',points,.12,steel,bone)
    # Receiver carries a short bright neural line that remains on the head joint.
    points=[p+n*.23+Vector((0,.25,-.45)),p+n*.08+Vector((0,1.15,-1.10)),p+Vector((-sx*.18,2.10,.1)),p+Vector((-sx*.3,1.90,1.25))]
    ribbed_hose('Head | purple neural loop',points,.17,bone)
    hp,hn=headpoint(sx*2,68.85,True,.23)
    pp,r,n,u,f=panel('Head | upper anchor',hp,hn,1.1,1.2,bone,steel,depth=.22)
    if sx==1:glow_slot('Head | cyan receiver indicator',pp+n*.04,n,.20,.65,bone)
    else:label('Head | implant serial','N-02',pp+n*.05,n,.19,bone)
for sx in (-1,1):
    jaw=[]
    for x,z in ((sx*2.22,64.6),(sx*2.02,63.6),(sx*1.5,62.8)):
        hp,hn=headpoint(x,z,False,.18);jaw.append(hp)
    tube('Head | cheek frame',jaw,.12,steel,bone)
    hp=jaw[1];pp,r,n,u,f=panel('Head | cheekbone armor plate',hp,(0,-1,0),.80,1.26,bone,steel,Vector((-.25*sx,0,1)),depth=.19,fasteners=False)
    bolt('Head | cheek adjustment screw',pp+u*.32+n*.04,n,bone,.10)
camera((30,-126,62),(0,-.5,36),81)
save('03_completed_reference_two')
