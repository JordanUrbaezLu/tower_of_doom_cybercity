import sys,importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import equipment;importlib.reload(equipment)
from equipment import *
assert REFERENCE==2
# Extend the rear chassis physically into the raised cell. The cell remains a
# backpack component and does not follow head turns or rely on the skull as support.
for ob in list(scene.objects):
    if ob.name.startswith('Back | elevated cell support'):bpy.data.objects.remove(ob,do_unlink=True)
lower=skin(0,58.5,True,.90)
# Compute the endpoint from the actual authored case, not a camera-specific guess.
case=bpy.data.objects['Back | tall rear head cell mount']
coords=[case.matrix_world@v.co for v in case.data.vertices]
upper=Vector(((min(v.x for v in coords)+max(v.x for v in coords))/2,max(v.y for v in coords)-.21,min(v.z for v in coords)+.45))
for sx in (-1,1):
    a=lower+Vector((sx*.73,0,0));b=upper+Vector((sx*.73,0,0))
    normal=Vector((0,1,0));up=(b-a).normalized();r,n,u,f=basis(normal,up)
    p=(a+b)/2
    box('Back | elevated cell support steel rail',p,(.30,.34,(b-a).length+.45),steel,frame=f,bevel=.065)
    box('Back | elevated cell support exposed edge',p+n*.19,(.10,.07,(b-a).length+.15),edge,frame=f,bevel=.023)
    for q in (a,b):
        pp,rr,nn,uu,ff=panel('Back | elevated cell support bolted foot',q,normal,.92,.96,mat=steel,depth=.25)
        bolt('Back | elevated cell support anchor',pp+nn*.035,nn,r=.13)
ribbed_hose('Back | elevated cell support power jumper',[lower+Vector((-.9,.45,-.10)),lower+Vector((-.4,.65,1.25)),upper+Vector((-.45,.45,-.85)),upper+Vector((-.45,.40,0))],.16)
save('03_completed_reference_two')
