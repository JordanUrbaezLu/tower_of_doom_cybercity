import sys, importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import lib
importlib.reload(lib)
from lib import *
for ob in list(scene.objects):
    if 'attachment_bone' in ob and ob.name.startswith(('Arm |','Hand |','Finger |')):bpy.data.objects.remove(ob,do_unlink=True)

# A powered exoskeletal forearm surrounds the donor; no stock flesh or weights removed.
bone='j_elbow_le';a,b,axis,length,front,right,point,radii=limb(bone,'j_wrist_le')
for t in (.13,.83):
    strap('Arm | broad fitted leather retaining cuff',point,t,.90,length,bone)
    for ang in (0,1.55,3.10,4.65):
        hp,hn=point(t,ang,.24)
        panel('Arm | cuff armor tile',hp,hn,1.08,.73,bone,steel,-axis,depth=.14,fasteners=False)
        bolt('Arm | cuff clamp fastener',hp+hn*.18,hn,bone,.11)
start=point(.18,0,.38)[0];end=point(.80,0,.36)[0]
up=(start-end).normalized();n=(front-up*front.dot(up)).normalized()
p=(start+end)/2
p,r,n,u,f=panel('Arm | machined exoskeleton bed',p,n,2.6,(end-start).length,bone,steel,up,depth=.25)
# Twin-cell appearance in the reference's cyan window: one broad chamber split by a central rib.
cartridge('Arm | plasma hydraulic reservoir',p+n*.60,n,.63,4.15,bone,up)
for sx in (-1,1):
    rail=p+r*sx*1.28+n*.17
    panel('Arm | segmented outer armor',rail,n,.76,4.95,bone,ivory,up,depth=.28)
    for z in (-1.78,1.78):
        panel('Arm | riveted corner clamp',rail+u*z+n*.32,n,.89,.66,bone,steel,up,depth=.12,fasteners=False)
        bolt('Arm | captive corner bolt',rail+u*z+n*.48,n,bone,.13)
    label('Arm | service stencil','H-115',rail+n*.48,n,.17,bone,up)
    piston('Arm | telescopic actuator',rail-u*2.55+n*.13,rail+u*2.55+n*.13,.12,bone)
# Two side pressure lines from elbow manifold down to the wrist drive.
for ang in (1.05,1.70):
    pts=[point(t,ang,.47)[0] for t in (.14,.30,.55,.80)]
    hose('Arm | magenta hydraulic feed',pts,.18,magenta,bone,False)
    for t in (.20,.76):
        hp,hn=point(t,ang,.51);panel('Arm | pipe retaining saddle',hp,hn,.80,.50,bone,edge,-axis,depth=.12,fasteners=False)
# Back-of-arm structural rails and center service cover make all-around geometry.
for ang in (2.7,3.6):
    aa=point(.16,ang,.33)[0];bb=point(.80,ang,.33)[0]
    rod('Arm | rear structural tie',aa,bb,.14,steel,bone)
    for hp in (aa,bb):cyl('Arm | rear rail terminal',hp,.23,.31,edge,bone,axis)
hp,hn=point(.48,math.pi,.32)
pp,rr,nn,uu,ff=panel('Arm | back service hatch',hp,hn,1.35,3.7,bone,steel,-axis,depth=.22)
for z in (-.9,-.45,0,.45,.9):
    box('Arm | recessed cooling slot',pp+uu*z+nn*.015,(.87,.035,.12),rubber,bone,ff,.035)
label('Arm | service hatch number','EXO-01',pp+uu*1.48+nn*.04,nn,.17,bone,-axis)
# Upper-arm feeds are independently skinned so the elbow is free to flex.
upper='j_shoulder_le';aa,bb,ax,ll,fr,ri,pt,rad=limb(upper,bone)
for ang in (.65,1.20):
    points=[pt(t,ang,.43)[0] for t in (.43,.58,.77,.93)]
    hose('Arm | upper magenta drive line',points,.19,magenta,upper,False)
for t in (.61,.90):
    for ang in (.65,1.20):
        hp,hn=pt(t,ang,.47);panel('Arm | upper pipe clamp',hp,hn,.83,.55,upper,steel,-ax,depth=.13,fasteners=False)

# Mechanical hand: wrist coupling, sculpted palm chassis, knuckles, all finger segments.
bone='j_wrist_le';w=rig.data.bones[bone].head_local.copy()
mid=rig.data.bones['j_mid_le_1'].head_local.copy()
dorsal=Vector((0,0,1));direction=(mid-w).normalized()
def handskin(c,gap=.12):
    hit,normal,index,dist=surface.ray_cast(c+dorsal*6,-dorsal,12)
    assert hit is not None,('hand surface',list(c))
    return hit+dorsal*gap
hp=handskin(w.lerp(mid,.5))
pp,r,n,u,f=panel('Hand | armored dorsal palm chassis',hp,dorsal,2.10,2.55,bone,steel,direction,depth=.19)
panel('Hand | segmented worn metacarpal cover',pp+n*.06,n,1.65,1.70,bone,ivory,direction,depth=.16,fasteners=False)
for sx in (-1,1):
    piston('Hand | palm servo',pp+r*sx*.81-u*.95+n*.28,pp+r*sx*.81+u*.73+n*.28,.095,bone)
label('Hand | machine serial','H / 01',pp+n*.245,n,.20,bone,direction)
# Wrist coupler follows wrist, forearm end cap follows elbow; flexible hoses bridge visually.
for sx in (-1,1):
    center=handskin(w.lerp(mid,.08))+r*sx*.86
    cyl('Hand | wrist rotary coupling',center,.30,.35,steel,bone,r)
    ring('Hand | wrist bearing ring',center+r*sx*.18,r,.22,.054,edge,bone)
for dx in (-.49,0,.49):
    hose('Hand | dorsal flexible tendon',[pp+r*dx-u*1.30+n*.21,pp+r*dx-u*.78+n*.34,pp+r*dx+u*.9+n*.35],.069,rubber,bone,False)

for finger in ('thumb','index','mid','ring','pinky'):
    for j in (1,2,3):
        bn=f'j_{finger}_le_{j}'
        if bn not in rig.data.bones:continue
        start=rig.data.bones[bn].head_local.copy()
        nextbn=f'j_{finger}_le_{j+1}'
        end=rig.data.bones[nextbn].head_local.copy() if nextbn in rig.data.bones else rig.data.bones[bn].tail_local.copy()
        vec=end-start;lng=vec.length
        tangent=vec.normalized();normal=(dorsal-tangent*dorsal.dot(tangent)).normalized();side=tangent.cross(normal).normalized()
        center=start.lerp(end,.49)
        hit,hn,idx,d=surface.ray_cast(center+normal*3,-normal,6)
        radius=max(.19,min(.51,(hit-center).dot(normal)+.10)) if hit is not None else .28
        # C-section armor wraps 260 degrees around each original phalanx.
        # An actual gap remains on the palm side for flexion and to preserve the donor hand.
        N=16;vs=[]
        for dep in (0,.10):
            for t in (.11,.85):
                for k in range(N+1):
                    ang=-2.26+k*4.52/N;vs.append(start.lerp(end,t)+(normal*math.cos(ang)+side*math.sin(ang))*(radius+dep))
        count=2*(N+1);fs=[]
        for layer in (0,count):
            for k in range(N):fs.append((layer+k,layer+k+1,layer+k+N+2,layer+k+N+1))
        for row in (0,N+1):
            for k in range(N):q=row+k;fs.append((q,q+1,q+1+count,q+count))
        for k in (0,N):fs.append((k,k+N+1,k+N+1+count,k+count))
        mesh(f'Finger | {finger} segment {j} machined sleeve',vs,fs,steel if j!=2 else ivory,bn,.022)
        # Distinct hinge end caps; central rods make the mechanical tendon visible.
        for sx in (-1,1):
            joint=start+side*sx*(radius+.10)
            cyl('Finger | '+finger+' knuckle hinge',joint,radius*.64,.12,edge,bn,side,16)
            cyl('Finger | '+finger+' recessed hinge screw',joint+side*sx*.075,radius*.23,.035,steel,bn,side,8)
            rod('Finger | '+finger+' tendon piston',start.lerp(end,.21)+side*sx*(radius+.15),start.lerp(end,.76)+side*sx*(radius+.15),.045,edge,bn,12)
        panel('Finger | '+finger+' dorsal shield',center+normal*(radius+.105),normal,radius*1.35,lng*.48,bn,ivory,tangent,depth=.06,fasteners=False)
        if j==1:
            # Feed terminates at the knuckle so it does not hold a finger rigid to the hand.
            hose('Finger | '+finger+' short knuckle feed',[start+normal*(radius+.15)-tangent*.18,start+normal*(radius+.23)+tangent*.17,start.lerp(end,.35)+normal*(radius+.16)],.043,rubber,bn,False)

camera((43,-52,58),(17,-9,46),21)
save('02_mechanical_arm_and_all_finger_segments')
