import sys, importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import lib
importlib.reload(lib)
from lib import *

for ob in list(scene.objects):
    if 'attachment_bone' in ob:bpy.data.objects.remove(ob,do_unlink=True)
for pb in rig.pose.bones:pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0)
bpy.context.view_layer.update()
scene['donor_signatures']=json.dumps({o.name:signature(o) for o in base})

# Heavy double shoulder harness, wrapped over the top rather than ending at clavicles.
def harness_lane(sx,back=False):
    zs=[46.5+i*.42 for i in range(31)];w=1.02
    centers=[]
    for z in zs:
        x=sx*(3.5+(z-46.5)*.125)
        vals=[skin(x+dx,z,back,.17) for dx in (-w*.5,0,w*.5)]
        y=(max(v.y for v in vals) if back else min(v.y for v in vals));centers.append(Vector((x,y,z)))
    verts=[]
    sign=1 if back else -1
    for depth in (0,.12):
        for p in centers:
            for dx in (-w/2,w/2):verts.append(p+Vector((dx,sign*depth,0)))
    N=len(centers)*2;faces=[]
    for layer in (0,N):
        for j in range(len(centers)-1):k=layer+j*2;faces.append((k,k+1,k+3,k+2))
    for s in (0,1):
        for j in range(len(centers)-1):k=j*2+s;faces.append((k,k+2,k+2+N,k+N))
    mesh('Harness | broad fitted '+('rear' if back else 'front')+' webbing',verts,faces,web)
    n=Vector((0,sign,0))
    for i,p in enumerate(centers):
        if i%2:continue
        for dx in (-.40,.40):
            rod('Harness | frayed seam stitch',p+Vector((dx,sign*.15,-.08)),p+Vector((dx,sign*.15,.08)),.018,edge,sides=6)
    for z in (48.2,54.2,57.6):
        x=sx*(3.5+(z-46.5)*.125);p=skin(x,z,back,.42)
        pp,r,n,u,f=panel('Harness | riveted leather reinforcement',p,n,1.42,1.82,mat=web,depth=.13)
        # A genuinely open steel buckle, with webbing visible through its centre.
        for dx in (-.55,.55):box('Harness | buckle side',pp+r*dx+n*.10,(.15,.19,1.15),edge,frame=f)
        for dz in (-.52,.52):box('Harness | buckle crossbar',pp+u*dz+n*.10,(1.13,.19,.15),edge,frame=f)
        rod('Harness | buckle tongue',pp-u*.30+n*.18,pp+u*.38+n*.18,.07,steel)
        if not back and z==57.6:
            box('Harness | locator housing',pp+u*.93+n*.05,(.58,.21,.73),steel,frame=f)
            box('Harness | amber locator',pp+u*.93+n*.18,(.24,.08,.34),amber,frame=f,bevel=.035)
    return centers[-1]
for sx in (-1,1):
    a=harness_lane(sx);b=harness_lane(sx,True)
    mid=a.lerp(b,.5)+Vector((0,0,1.35))
    # Wide shoulder bridge is a flattened solid strap.
    pts=[a,a.lerp(mid,.6),mid,mid.lerp(b,.4),b]
    vs=[p+Vector((dx,0,offset)) for offset in (0,.14) for p in pts for dx in (-.51,.51)]
    fs=[]
    for layer in (0,10):
        for i in range(4):k=layer+i*2;fs.append((k,k+1,k+3,k+2))
    for j in (0,1):
        for i in range(4):k=i*2+j;fs.append((k,k+2,k+12,k+10))
    mesh('Harness | over-shoulder bridge',vs,fs,web)

# Broad transverse web belt ties the monitor into the shoulder harness.
for back in (False,True):
    n=Vector((0,1 if back else -1,0));verts=[]
    for z in (50.05,51.04):
        for i in range(31):verts.append(skin(-6.0+i*.4,z,back,.23))
    ob=mesh('Harness | chest crossbelt',verts,[(i,i+1,i+32,i+31) for i in range(30)],web)
    mod=ob.modifiers.new('Webbing thickness','SOLIDIFY');mod.thickness=.10;bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=mod.name)

p,r,n,u,f=torso_panel('Chest | shock-mounted monitor cradle',0,51.7,5.5,3.0,mat=steel)
panel('Chest | enamel console frame',p+n*.04,n,4.55,2.36,mat=ivory,depth=.13)
box('Chest | monitor rubber seal',p+n*.23,(3.55,.18,1.86),rubber,frame=f)
box('Chest | recessed smoked display',p+n*.34,(3.22,.05,1.56),glass,frame=f)
for z in (-.48,-.24,0,.24,.48):
    tube('Chest | faint screen grid',[p-r*1.48+n*.38+u*z,p+r*1.48+n*.38+u*z],.007,cyan,smooth=False)
for x in (-1.2,-.6,0,.6,1.2):tube('Chest | faint screen grid',[p+r*x+n*.38-u*.68,p+r*x+n*.38+u*.68],.006,cyan,smooth=False)
wave=[(-1.45,.05),(-.90,.05),(-.70,-.08),(-.55,.10),(-.41,.07),(-.31,.62),(-.19,-.48),(-.04,.02),(.55,.02),(.72,.14),(.85,.04),(1.4,.04)]
tube('Chest | primary ECG trace',[p+r*x+u*z+n*.395 for x,z in wave],.017,crack,smooth=False)
label('Chest | screen telemetry','SYS  038 / 115',p+n*.40-u*.56,n,.12)
for sx in (-1,1):
    panel('Chest | mounting latch',p+r*sx*2.68,n,.73,2.5,mat=steel,depth=.30)
    for z in (-.80,.80):cyl('Chest | rubber shock bushing',p+r*sx*2.66+u*z+n*.38,.20,.14,rubber,axis=n)
    label('Chest | serial stamp','R-01',p+r*sx*1.94+n*.22,n,.17)
    hose('Chest | coiled lower return',[p+r*sx*1.35-u*1.15,p+r*sx*1.25-u*2.6+n*.4,p+r*sx*.2-u*2.7+n*.5],.15,rubber,ribbed=False)

# Backpack: broad anchor rail, top distribution manifold, light in a metal cage.
p,r,n,u,f=torso_panel('Back | load-bearing spine cradle',0,53,3.45,10.4,True,steel)
for dx in (-1.44,1.44):
    box('Back | spine slide rail',p+r*dx+n*.08,(.29,.35,9.1),edge,frame=f)
    for z in (-4,-2,0,2,4):bolt('Back | structural screw',p+r*dx+u*z+n*.31,n,r=.13)
cartridge('Back | primary reactor',p+n*.97,n,1.05,7.8)
for dz in (-4.65,4.65):
    pp,rr,nn,uu,ff=panel('Back | manifold head',p+u*dz+n*.42,n,3.45,1.50,mat=ivory,depth=.48)
    for x in (-.75,0,.75):cyl('Back | manifold socket',pp+r*x+n*.12,.17,.20,steel,axis=n)
    label('Back | warning stencil','115  /  PRESSURE',pp+n*.03-u*.38,n,.19)
for sx in (-1,1):
    pts=[p+r*sx*.93+u*4.55+n*.7,skin(sx*3.1,58.4,True,.85),skin(sx*4.7,55.6,True,.75),skin(sx*4.0,52.1,True,.7),p+r*sx*1.5-u*2.8+n*.9]
    hose('Back | magenta reactor return',pts,.23,ribbed=False)
    for z in (52.1,55.6):
        hp=skin(sx*4.5,z,True,.72);panel('Back | hose saddle',hp,(0,1,0),.86,.55,mat=steel,depth=.10,fasteners=False)

# Layered shoulder silhouette: asymmetric pair, like the reference sheet.
for side,layers in (('le',4),('ri',2)):
    bone='j_shoulder_'+side;a,b,axis,length,front,right,point,radii=limb(bone,'j_elbow_'+side)
    for k in range(layers):
        ts=[.04+k*.13,.14+k*.13,.24+k*.13]
        angles=[-.48+j*2.30/20 for j in range(21)]
        rs=[max((point(t,ang,.22)[0]-a.lerp(b,t)).length for t in ts) for ang in angles]
        verts=[]
        for dep in (0,.20):
            for row,t in enumerate(ts):
                for j,(ang,rad) in enumerate(zip(angles,rs)):
                    # Tapered, stepped, chamfered lamella profile rather than a straight belt.
                    shape=.15*math.sin(math.pi*j/20)+( .13 if row==2 else 0)
                    verts.append(a.lerp(b,t)+(front*math.cos(ang)+right*math.sin(ang))*(rad+dep+shape))
        count=63;fs=[]
        for off in (0,count):
            for row in range(2):
                for j in range(20):i=off+row*21+j;fs.append((i,i+1,i+22,i+21))
        for row in (0,2):
            for j in range(20):i=row*21+j;fs.append((i,i+1,i+1+count,i+count))
        for j in (0,20):
            for row in range(2):i=row*21+j;fs.append((i,i+21,i+21+count,i+count))
        mesh('Shoulder '+side+' | armor lamella '+str(k+1),verts,fs,ivory if k==0 else steel,bone,.045)
        # Rivets and wear rims trace the actual curved shoulder surface.
        for ang in (-.65,1.65):
            hp,hn=point(ts[1],ang,.56);bolt('Shoulder | lamella pivot',hp,hn,bone,.16)
        rim=[a.lerp(b,ts[-1])+(front*math.cos(ang)+right*math.sin(ang))*(rad+.38) for ang,rad in zip(angles,rs)]
        tube('Shoulder | battered exposed lip',rim,.048,edge,bone)
    hp,hn=point(.29,.65,.66)
    pp,rr,nn,uu,ff=panel('Shoulder | amber locator mount',hp,hn,.86,.86,bone,steel,-axis,depth=.15)
    box('Shoulder | locator lens',pp+nn*.08,(.39,.09,.39),amber,bone,ff,.04)
    hp,hn=point(.05,.24,.56);label('Shoulder | identification','R1 / 09',hp,hn,.23,bone,-axis)

# Left articulated lower-leg exoskeleton, with actual side hinge and hydraulic rails.
bone='j_knee_le';a,b,axis,length,front,right,point,radii=limb(bone,'j_ankle_le')
for t in (.10,.48,.88):strap('Leg | fitted buckled retaining belt',point,t,.74,length,bone)
start=point(.19,0,.28)[0];end=point(.84,0,.28)[0];up=(start-end).normalized();normal=(front-up*front.dot(up)).normalized();p=(start+end)/2
p,r,n,u,f=panel('Leg | central shin chassis',p,normal,2.85,(end-start).length,bone,steel,up,depth=.24)
panel('Leg | chipped asymmetrical front armor',p+n*.14,n,1.65,6.4,bone,ivory,up,depth=.25)
label('Leg | etched service legend','EXO / 01',p+n*.41+u*.8,n,.21,bone,up)
for sx in (-1,1):
    pp=p+r*sx*1.22+n*.17
    box('Leg | inset energy rail gasket',pp,(.48,.32,5.5),rubber,bone,f)
    box('Leg | energy slit',pp+n*.19,(.17,.08,4.05),cyan,bone,f,.025)
    piston('Leg | side actuator',pp-u*4,pp+u*3.9,.17,bone)
    for z in (-3,3):panel('Leg | rail cross tie',pp+u*z+n*.2,n,.64,.78,bone,ivory,up,depth=.17)
hp,hn=point(.035,0,.40)
pp,rr,nn,uu,ff=panel('Knee | layered patella shell',hp,hn,3.45,2.75,bone,steel,-axis,depth=.35)
panel('Knee | chipped patella cap',pp+nn*.05,nn,2.55,2.15,bone,ivory,-axis,depth=.27)
for sx in (-1,1):
    cp=hp+right*sx*1.85+axis*.40
    cyl('Knee | rotary joint housing',cp,.64,.40,steel,bone,right*sx)
    ring('Knee | rotary bearing',cp+right*sx*.25,right,.43,.11,edge,bone)
    cyl('Knee | joint amber pilot',cp+right*sx*.36,.18,.04,amber,bone,right*sx)
for t in (.10,.48,.88):
    hp,hn=point(t,.65,.28);panel('Leg | retaining belt buckle',hp,hn,1.05,.90,bone,steel,-axis,depth=.14)

# Reference's rear-left thigh reserve, moved to the outside of the original trousers.
bone='j_hip_le';a,b,axis,length,front,right,point,radii=limb(bone,'j_knee_le')
for t in (.22,.49):strap('Thigh | reserve harness',point,t,.67,length,bone)
p,n=point(.34,1.42,.28)
pp,rr,nn,uu,ff=panel('Thigh | reserve cell cradle',p,n,2.15,5.75,bone,steel,-axis,depth=.28)
cartridge('Thigh | shielded reserve cell',pp+nn*.65,nn,.65,4.9,bone,-axis)
for z in (-2.7,2.7):label('Thigh | safety label','RESERVE',pp+uu*z+nn*.32,nn,.17,bone,-axis)

camera((33,-122,64),(0,0,36),85)
save('01_body_harness_shoulders_leg')
