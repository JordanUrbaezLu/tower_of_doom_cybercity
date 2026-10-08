"""Visual correction after inspecting MCP viewport images of the first assemblies."""
import sys, importlib, shutil
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import lib
importlib.reload(lib)
from lib import *

# Jaw bridge was across the bottom teeth in the first viewport check.
# Lower it to the chin, and make anatomical, tapered cheek links.
for ob in list(scene.objects):
    if 'attachment_bone' in ob and ob.name.startswith(('Head | articulated cheek','Head | cheek','Head | mandibular','Head | worn chin','Head | jaw-to-chin','Head | lower jaw')):bpy.data.objects.remove(ob,do_unlink=True)
bone='j_head'
for sx in (-1,1):
    ps=[]
    for x,z in ((sx*2.25,65.47),(sx*2.13,64.12),(sx*1.76,62.95)):
        hp,hn=headpoint(x,z,False,.12);ps.append(hp)
        r,n,u,f=basis(hn,Vector((sx*.28,0,1)))
        shape=[(-.42,-.48),(.12,-.64),(.40,-.34),(.49,.28),(.17,.55),(-.37,.34)]
        vs=[hp+r*x+u*z+n*d for d in (0,.18) for x,z in shape]
        fs=[tuple(range(5,-1,-1)),tuple(range(6,12))]+[(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
        mesh('Head | shaped cheek armor',vs,fs,steel,bone,.047)
        bolt('Head | cheek segment rivet',hp+u*.19+n*.22,n,bone,.085)
    tube('Head | jaw structural link',ps,.09,edge,bone)
p,n=headpoint(0,62.02,False,.17)
pp,r,n,u,f=panel('Head | chin restraint',p,n,2.6,.64,bone,steel,depth=.22)
panel('Head | chin latch',pp+n*.04,n,.62,.58,bone,edge,depth=.12,fasteners=False)
for sx in (-1,1):
    hp,hn=headpoint(sx*1.76,62.95,False,.16)
    tube('Head | mandibular arch',[hp,hp+Vector((-sx*.15,-.18,-.48)),pp+r*sx*1.05+u*.12],.13,steel,bone)
    bolt('Head | chin anchor rivet',pp+r*sx*.91+n*.03,n,bone,.10)
glass.node_tree.nodes.get('Principled BSDF').inputs['Transmission Weight'].default_value=.22
glass.node_tree.nodes.get('Principled BSDF').inputs['IOR'].default_value=1.46
for ob in scene.objects:
    if ob.name.startswith('Head | thick optical'):
        m=ob.modifiers.new('Actual glass thickness','SOLIDIFY');m.thickness=.045

# Broad shoulders need surface construction detail, rather than uninterrupted dark strips.
for side,count in (('le',4),('ri',2)):
    bone='j_shoulder_'+side;a,b,axis,length,front,right,point,radii=limb(bone,'j_elbow_'+side)
    for k in range(count):
        t=.14+k*.13
        for ang in (.15,.85,1.5):
            hp,hn=point(t,ang,.55)
            # Narrow recessed seams, two subplates and scratched stamped numerals.
            pp,r,n,u,f=panel('Shoulder | inset reinforcing scale',hp,hn,.62,.57,bone,steel,-axis,depth=.065,fasteners=False)
            bolt('Shoulder | scale rivet',pp+n*.01,n,bone,.065)
    hp,hn=point(.17,.48,.64);label('Shoulder | worn warning','CAUTION',hp,hn,.17,bone,-axis,letter)

# Explicit paint wear in the bevels is already modeled; add fastener-local grease halos
# without global dirt blobs or changes to the original zombie skin texture.
for ob in list(scene.objects):
    if ob.type!='MESH' or 'attachment_bone' not in ob:continue
    if any(k in ob.name for k in ('hex head','cap captive screw')):
        ob['wear_location']='fastener / exposed contact'

# Neutral warm-gray studio: inspect weathering without a blue cast.
scene.world.use_nodes=True
bg=scene.world.node_tree.nodes.get('Background')
if bg:bg.inputs[0].default_value=(.16,.17,.19,1);bg.inputs[1].default_value=.35
lights=[o for o in scene.objects if o.type=='LIGHT']
for ob in lights:
    ob.data.color=(1,.92,.83) if ob.location.x<0 else (.83,.90,1)
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=48;scene.cycles.use_denoising=True
scene.render.threads_mode='FIXED';scene.render.threads=6
scene.render.resolution_x=1400;scene.render.resolution_y=1700;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
reference=bpy.data.images.load('C:/Users/jorda/Downloads/CyberZombie1.png',check_existing=True);reference.pack()
scene['source_reference_image']=reference.name
shutil.copy2('C:/Users/jorda/Downloads/CyberZombie1.png',OUT/'CyberZombie1.png')
camera((30,-126,62),(0,-.5,36),81)
save('04_refined_fit_and_materials')
