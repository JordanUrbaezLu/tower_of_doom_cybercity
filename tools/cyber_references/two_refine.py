import sys,importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import equipment;importlib.reload(equipment)
from equipment import *
assert REFERENCE==2
for ob in list(scene.objects):
    if ob.name.startswith(('Back | tall','Back | triple vertical','Back | cell end')):
        # Tall rear cell now clears the skull like the reference, with offset mounting.
        for v in ob.data.vertices:v.co+=Vector((1.05,0,3.4))
bone='j_shoulder_ri';a,b,axis,length,front,right,point,radii=limb(bone,'j_elbow_ri')
fitted_shell('Shoulder | overlapping crown of pauldron',point,.05,.24,.58,2.10,bone,ivory,.57)
for angle in (-.3,1.4):
    hp,hn=point(.15,angle,.85);bolt('Shoulder | crown of pauldron anchor',hp,hn,bone,.17)
save('03_completed_reference_two')
