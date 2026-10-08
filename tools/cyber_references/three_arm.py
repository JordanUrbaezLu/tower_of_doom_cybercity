import sys,importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import equipment;importlib.reload(equipment)
from equipment import *
assert REFERENCE==3
bone='j_elbow_le';a,b,axis,length,front,right,point,radii=limb(bone,'j_wrist_le')
for t in (.14,.82):
    strap('Arm | fitted industrial retaining cuff',point,t,.84,length,bone)
    hp,hn=point(t,.45,.25);buckle('Arm | retaining cuff buckle',hp,hn,bone,-axis)
fitted_shell('Arm | curved hydraulic cradle',point,.20,.77,.88,1.52,bone,steel,.28)
hp,hn=point(.49,.88,.64)
pp,r,n,u,f=panel('Arm | twin cell mounting frame',hp,hn,2.38,5.85,bone,steel,-axis,depth=.24)
for x in (-.60,.60):cartridge('Arm | twin exposed cyan reservoir',pp+r*x+n*.54,n,.44,4.63,bone,-axis)
for x in (-1.14,1.14):
    panel('Arm | chipped ceramic edge shield',pp+r*x+n*.28,n,.47,4.79,bone,ivory,-axis,depth=.24,fasteners=False)
    piston('Arm | reservoir locking rod',pp+r*x-u*2.10+n*.60,pp+r*x+u*2.10+n*.60,.073,bone)
for z in (-2.55,2.55):
    panel('Arm | heavy cell end clamp',pp+u*z+n*.62,n,2.65,.78,bone,ivory,-axis,depth=.23)
for angle in (-.23,.08):
    ribbed_hose('Arm | glowing purple hydraulic feed',[point(t,angle,.46)[0] for t in (.18,.35,.56,.78)],.17,bone)
    for t in (.21,.75):
        hp,hn=point(t,angle,.51);panel('Arm | hose clamp',hp,hn,.63,.53,bone,steel,-axis,depth=.13,fasteners=False)
for angle in (2.7,3.65):piston('Arm | rear exposed actuator',point(.21,angle,.29)[0],point(.77,angle,.29)[0],.13,bone)
hp,hn=point(.49,math.pi,.27)
pp,r,n,u,f=panel('Arm | rear motor case',hp,hn,1.34,3.80,bone,steel,-axis,depth=.22)
for z in (-1,-.5,0,.5,1):box('Arm | rear motor cooling fin',pp+u*z+n*.025,(.85,.10,.10),edge,bone,f,.015)

# Carry the reference's full mechanical hand over the donor fingers, with independent joints.
src=(ROOT/'tools/cyber_reference_one/02_arm.py').read_text()
exec(src[src.index('# Mechanical hand:'):src.index('camera((43')],globals())
bone='j_shoulder_le';a,b,axis,length,front,right,point,radii=limb(bone,'j_elbow_le')
for angle in (.75,1.18):
    ribbed_hose('Arm | purple upper hydraulic supply',[point(t,angle,.40)[0] for t in (.43,.60,.76,.91)],.20,bone)
for t in (.48,.86):
    hp,hn=point(t,.96,.57);panel('Arm | upper supply clamp',hp,hn,1.6,.66,bone,steel,-axis,depth=.17)
camera((43,-52,59),(17,-10,46),21)
save('02_industrial_powered_arm_and_hand')
