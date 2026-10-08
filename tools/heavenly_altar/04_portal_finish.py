import sys,importlib,shutil
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import design_lib as D
importlib.reload(D)
from design_lib import *
D.group='08 Recessed heavenly portal'
reference=Path('C:/Users/jorda/Downloads/ChatGPT Image Sep 16, 2026, 04_39_31 PM.png')
refcopy=OUT/'design_reference.png'
if not refcopy.exists():shutil.copy2(reference,refcopy)
image=bpy.data.images.load(str(refcopy),check_existing=True)
mat=bpy.data.materials.new(PREFIX+'reference heavenly portal artwork');mat.use_nodes=True
n,l=mat.node_tree.nodes,mat.node_tree.links;bs=n.get('Principled BSDF');tx=n.new('ShaderNodeTexImage');tx.image=image
l.new(tx.outputs['Color'],bs.inputs['Base Color']);l.new(tx.outputs['Color'],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=1.4;bs.inputs['Roughness'].default_value=.65
pts=[(-17,88),(17,88),(37,65),(14,43),(14,22),(-14,22),(-14,43),(-37,65)]
pixels=[(470,488),(780,488),(885,681),(738,887),(732,1085),(481,1085),(480,871),(287,665)]
ob=mesh('Portal | recessed heavenly artwork',[(x,-10,z) for x,z in pts],[tuple(range(8))],mat)
uv=ob.data.uv_layers.new(name='Reference interior projection')
for face in ob.data.polygons:
    for li in face.loop_indices:
        vi=ob.data.loops[li].vertex_index;u,v=pixels[vi];uv.data[li].uv=(u/1122,1-v/1402)
ob['construction']='Recessed image surface, as on original altar. Exterior armor and effects are separate 3D geometry.'
ob['source_reference']=str(refcopy)
# Real reveal surfaces surround the inset image to keep the portal recessed.
for i in range(8):
    a=pts[i];b=pts[(i+1)%8]
    mesh('Portal | champagne cavity wall',[(a[0],-19,a[1]),(b[0],-19,b[1]),(b[0],-9,b[1]),(a[0],-9,a[1])],[(0,1,2,3)],gold)
line('Portal | white gold threshold',[(-13.8,22.2),(13.8,22.2)],-20,.14,white)
# Physical columns, downlight bars and holographic rings in front of the recess.
for s in (-1,1):
    for j in range(2):
        x=s*(12+j*2)
        line('Portal | fluted inner jamb',[(x,26),(x,43)],-12-j*.3,.28,ivory2)
        line('Portal | warm jamb light',[(x-.4*s,27),(x-.4*s,43)],-12.5-j*.3,.07,white)
for i in range(16):
    a=math.pi+(i+.5)*math.pi/16
    x=21*math.cos(a);z=104+21*math.sin(a)
    panel('Portal | segmented crown downlight',[(x-.35,z),(x+.35,z),(x+.4,z-1.5),(x-.4,z-1.5)],-20.2,1,white,.04)
for z,rx,ry in [(80,11,3),(78.7,11.5,3.2),(71,3.5,1.1),(67,3.5,1.1)]:
    cx=0 if z>75 else (-16 if z==71 else 17)
    points=[(cx+rx*math.cos(i*math.tau/100),-15+ry*math.sin(i*math.tau/100),z) for i in range(101)]
    tube('Portal | floating warm halo',points,.07,white,6)
rng=random.Random(20260916)
for i in range(40):
    x=rng.uniform(-16,16);z=rng.uniform(45,84)
    tube('Portal | fine gold lightfall',[(x,-13,z),(x,-13,z-rng.uniform(.3,3))],.015,white,5)

D.group='09 Machined panel details'
# Tiny engraved branching wear lives on panel faces, clipped to their silhouettes.
def inside(p,poly):
    x,z=p;hit=False
    for a,b in zip(poly,poly[1:]+poly[:1]):
        if (a[1]>z)!=(b[1]>z) and x<(b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0]:hit=not hit
    return hit
faces=[o for o in scene.objects if o.get('altar_design') and o.type=='MESH' and o.data.materials[0]==ivory]
for ob in faces:
    coords=[v.co for v in ob.data.vertices];front=min(p.y for p in coords)
    poly=[(p.x,p.z) for p in coords if abs(p.y-front)<1e-4]
    if len(poly)<3:continue
    xmin,xmax=min(p[0] for p in poly),max(p[0] for p in poly);zmin,zmax=min(p[1] for p in poly),max(p[1] for p in poly)
    for j in range(8):
        p=(rng.uniform(xmin,xmax),rng.uniform(zmin,zmax))
        step=rng.uniform(.25,1.1);q=(p[0]+step,p[1]+step*rng.uniform(-.6,.6));r=(q[0]+step*.45,q[1]+step*.5)
        if all(inside(v,poly) for v in (p,q,r)):
            line('Finish | fine ceramic scratch',[p,q,r],front-.025,.012,etch)
            if j%3==0:line('Finish | exposed gold scratch edge',[(p[0],p[1]-.035),(q[0],q[1]-.035)],front-.03,.008,goldlight)
# Sharp engineered seams and gold corner catches distinguish panels from smooth blocks.
for s in (-1,1):
    def P(p):return [(s*x,z) for x,z in p]
    for z in (22,31,39):
        line('Upright | inset branching circuit',P([(20,z),(20,z+3),(21,z+4)]),-20.72,.035,black)
        box('Upright | gold locking tab',(s*22.5,-21,z+1),(.8,.5,2),gold,.08)
    line('Foot | engineered panel seam',P([(29,2.7),(30,5),(35,8.5),(36,10)]),-25.35,.035,black)
    line('Shoulder | angular service seam',P([(21,112),(25,111),(27,109),(31,109)]),-15.6,.038,black)
    for z in (50,59,74,83):
        x=abs(40-(abs(z-65))*.85)
        line('Frame | small exposed conductor',P([(x,z),(x+.8,z+.7),(x+2,z+.7)]),-21.7,.045,cyan)

D.group='10 Rear service housing'
# The image does not show the reverse; continue the same finish and construction there.
panel('Rear | central service spine',[(-9,14),(9,14),(12,96),(-12,96)],10,6,dark,.4)
panel('Rear | ivory back access panel',[(-7,22),(7,22),(8,84),(-8,84)],16,.8,ivory,.3)
for z in (27,47,67,84):
    box('Rear | service cover',(0,17,z),(12,1,9),steel,.25)
    for j in range(5):box('Rear | recessed cooling louver',(0,17.65,z-3+j*1.35),(9,.25,.4),black,.06)
    for x in (-5,5):
        # Back-facing bolts are sockets defined with negative depth-facing camera hidden.
        box('Rear | gold retaining lug',(x,18,z),(1.1,1,2),gold,.12)
for s in (-1,1):
    tube('Rear | purple shielded power conduit',[(s*10,17,24),(s*14,18,32),(s*14,18,82),(s*9,15,94)],.42,violet)
    for z in (36,54,72):box('Rear | conduit clamp',(s*14,18,z),(1.8,2,1.2),gold,.15)
ring('Rear | matching circular service bezel',0,104,0,18.5,1.5,2,gold)
disc('Rear | service drum face',0,104,1,17.5,1,steel)
ring('Rear | violet diagnostic ring',0,104,2.2,12,.25,.3,violet)

D.group='11 Review studio'
floor=box('Altar review floor',(0,0,-1.3),(1400,1400,2),D.material('dark reflective studio',(.013,.017,.028),.5,.24),0)
floor['altar_design']=False
scene.world.use_nodes=True;world=scene.world.node_tree.nodes.get('Background');world.inputs[0].default_value=(.035,.043,.068,1);world.inputs[1].default_value=.25
def area(name,loc,power,color,size,target=(0,0,65)):
    data=bpy.data.lights.new(name,'AREA');ob=bpy.data.objects.new(name,data);collection(D.group).objects.link(ob)
    ob.location=loc;ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler();data.energy=power;data.color=color;data.shape='DISK';data.size=size
area('Altar review key',(-70,-90,155),180000,(1,.86,.69),95)
area('Altar review cool fill',(85,-60,95),120000,(.53,.72,1),75)
area('Altar review rim',(-20,45,140),210000,(.71,.44,1),80)
area('Altar review portal bounce',(0,-14,60),1800,(1,.7,.28),22,(0,-50,55))
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True;scene.render.threads_mode='FIXED';scene.render.threads=8
scene.render.resolution_x=1120;scene.render.resolution_y=1400;scene.render.resolution_percentage=80
scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
scene.use_nodes=True;n=scene.node_tree.nodes;n.clear();l=scene.node_tree.links
rl=n.new('CompositorNodeRLayers');gl=n.new('CompositorNodeGlare');gl.glare_type='FOG_GLOW';gl.quality='HIGH';gl.threshold=1.8;gl.size=8;out=n.new('CompositorNodeComposite');l.new(rl.outputs['Image'],gl.inputs['Image']);l.new(gl.outputs['Image'],out.inputs[0])
camera((12,-265,87),(0,0,65),148)
scene.render.filepath=str(OUT/'cyber_front.png')
live_view()
save('04 complete reference-driven art master ready for visual review')
