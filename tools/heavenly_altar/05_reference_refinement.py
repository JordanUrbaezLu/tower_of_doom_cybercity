"""Second comparison pass: depth, fitted armor facets, optical fields and light balance."""
import sys,importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import design_lib as D
importlib.reload(D)
from design_lib import *
D.group='12 Reference refinement armor'
for m in (ivory,ivory2):
    b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Coat Weight'].default_value=.32;b.inputs['Coat Roughness'].default_value=.24;b.inputs['Metallic'].default_value=.18
# A projected luminous scene should retain its own painted shadows, not receive key-light twice.
mat=bpy.data.materials[PREFIX+'reference heavenly portal artwork'];n,l=mat.node_tree.nodes,mat.node_tree.links
tex=next(n for n in n if n.type=='TEX_IMAGE');out=n.get('Material Output')
em=n.new('ShaderNodeEmission');l.new(tex.outputs['Color'],em.inputs[0]);em.inputs[1].default_value=.85;l.new(em.outputs[0],out.inputs[0])
ob=bpy.data.objects['Portal | recessed heavenly artwork']
pixels=[(470,488),(780,488),(885,681),(738,887),(724,1044),(491,1044),(480,871),(287,665)]
for p in ob.data.polygons:
    for li in p.loop_indices:
        u,v=pixels[ob.data.loops[li].vertex_index];ob.data.uv_layers.active.data[li].uv=(u/1122,1-v/1402)

def facet(name,pts,y,depth=1.2):
    # A real raised ridge and sloping side faces produce the reference's broad sharp highlights.
    N=len(pts);cx=sum(x for x,z in pts)/N;cz=sum(z for x,z in pts)/N
    inner=[(cx+(x-cx)*.91,cz+(z-cz)*.84) for x,z in pts]
    vs=[(x,y,z) for x,z in pts]+[(x,y-depth,z) for x,z in inner]
    fs=[tuple(range(N,2*N))]+[(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)]
    ob=mesh(name,vs,fs,ivory,.07);ob.data.materials.append(gold)
    for p in ob.data.polygons:
        if p.index%4==2:p.material_index=2 if len(ob.data.materials)>2 else 1
    outline(name+' gold perimeter',pts,y-.025,.085,goldlight)
    return ob

for s in (-1,1):
    def P(p):return [(s*x,z) for x,z in p]
    # White top cornices carry depth, seams, locking brackets and a recessed purple light blade.
    shoulder=P([(18.4,113.8),(35.5,113.8),(38.1,109.5),(34.8,108.3),(23.3,110.2),(21.3,111.7)])
    facet('Shoulder | sculpted raised cornice',shoulder,-15.9,1.25)
    box('Shoulder | purple light well',(s*29,-16.8,107.6),(11,1,1.8),black,.16)
    line('Shoulder | bright light blade',P([(24,108.3),(32.8,106.9),(34,107.8)]),-17.45,.27,violet)
    for j in (0,1):
        pp=P([(26+j*7,112.2-j),(29+j*7,111.7-j),(29.6+j*7,109.5-j),(28+j*7,109.9-j)])
        panel('Shoulder | gold retention fingers',pp,-17.45,.55,gold,.09)
    facet('Shoulder | lower layered cap',P([(28,102.5),(35,100.6),(34,96.2),(29,96.5),(26.8,99)]),-15.3,.85)
    # Gold jaw collars at the two diamond elbows and the lower change of direction.
    for x,z,rot in [(47,65,0),(21,44,0),(20,90,0)]:
        pp=P([(x-1,z-3),(x+1,z-3.4),(x+2,z-1),(x+1,z+2.5),(x-.5,z+2.6),(x+.2,z)])
        panel('Frame | angular gold joint clamp',pp,-22,1,gold,.1)
        bolt('Frame | elbow locking bolt',s*(x+.4),z-1,-22.4,.24)
    # Broad inset armor facets on each diagonal replace the flat-strip read.
    for a,b in [((24,47),(43,63)),((43,69),(25,89))]:
        A,B=Vector(a),Vector(b);t=(B-A).normalized();normal=Vector((-t.y,t.x))
        for j in range(2):
            aa=A+(B-A)*(j/2+.025);bb=A+(B-A)*((j+1)/2-.025)
            pp=[aa-normal*.15,bb-normal*.15,bb+normal*1.25,aa+normal*1.25]
            facet('Frame | folded diagonal armor',[ (s*v.x,v.y) for v in pp],-22,.6)
            mid=(aa+bb)*.5
            line('Frame | recessed purple segment',[(s*(aa.x-normal.x*1.15),aa.y-normal.y*1.15),(s*(bb.x-normal.x*1.15),bb.y-normal.y*1.15)],-21.4,.16,pink)
    # Lower columns have nested plates, circuit channels, catches and multi-face highlights.
    facet('Upright | inner pearl facet',P([(18.4,17),(21.3,19),(21.3,38),(19.3,41),(18.4,39)]),-21.3,.8)
    line('Upright | segmented violet light',P([(23.5,18),(23.5,25),(22.8,26),(22.8,34),(23.5,35),(23.5,41)]),-21.6,.19,violet)
    for z in (19,36):
        panel('Upright | angular gold latch',P([(21.4,z),(23.4,z+1),(23.4,z+2.2),(21.4,z+1.4)]),-22,.6,goldlight,.07)
    # Faceted ankles and overlapping front shields echo the stepped sci-fi plinth.
    facet('Base | inner front armor',P([(4,3.4),(11.8,3.4),(13,5.8),(11.5,10.4),(4,10.4)]),-26,1)
    facet('Base | outer front armor',P([(13,3.4),(23,3.4),(26,6.4),(24.8,10.4),(15.4,10.4),(13.5,8.6)]),-26,1)
    line('Base | bright violet cutout',P([(6,9.9),(10.5,9.9),(11.5,8.8)]),-27.1,.22,violet)
    line('Base | small violet cutout',P([(16,10),(20,10),(21,9)]),-27.1,.2,violet)
    panel('Base | heavy gold vertical brace',P([(1.9,3.2),(3.1,3.2),(3.1,12),(2.1,13.2),(1.9,11)]),-27.1,2,gold,.12)
    panel('Base | gold outside brace',P([(25,3),(26.5,3.8),(26.5,11.5),(25.2,11.5)]),-26.9,2,gold,.12)
    facet('Foot | sloping toe armor',P([(29,2.7),(42.7,2.7),(40,7.7),(36,10.2),(31,9.7)]),-25.9,.9)
    line('Foot | broad violet blade',P([(31,4),(38,4),(39.5,5.5)]),-26.9,.3,violet)
    line('Foot | white running light',P([(39.5,2.6),(44,2.6)]),-26.8,.2,white)
    facet('Wheel | shaped surround',P([(5,21),(11,19),(14,15),(10,14),(8,17),(4,18)]),-23,1.2)
    for j in range(3):
        box('Wheel | nested radiator',(s*(17+j*1.2),-23.2,17-j*.1),(.5,1.2,2.5),dark,.06)
        line('Wheel | cyan fan slit',P([(16.8+j*1.2,16),(17.6+j*1.2,17.2)]),-23.9,.18,cyan)

D.group='13 Fine crest mechanics'
# Replace clock-like ticks by irregular circuit lattices and recessed sector panels.
for ob in list(scene.objects):
    if ob.name.startswith('Crest | starfield circuit'):bpy.data.objects.remove(ob,do_unlink=True)
for i in range(16):
    a=i*math.tau/16+.04
    ring('Crest | radial recessed sector',0,104,-25,15.1,1,.6,steel,start=a+.07,end=a+.27,N=6)
    ring('Crest | tiny violet sector marker',0,104,-25.6,14.8,.075,.15,violet,start=a+.09,end=a+.19,N=5)
    line('Crest | outer index gold saddle',[(18*math.cos(a),104+18*math.sin(a)),(20.8*math.cos(a),104+20.8*math.sin(a))],-25,.13,goldlight)
    bolt('Crest | inner dial anchor',15.5*math.cos(a),104+15.5*math.sin(a),-25.3,.13)
rng=random.Random(11236)
for i in range(70):
    a=rng.uniform(0,math.tau);r=rng.uniform(3.8,9.3);x,z=r*math.cos(a),104+r*math.sin(a)
    disc('Crest | faint celestial particle',x,z,-25.9,rng.uniform(.025,.06),.05,cyan if i%4 else white,6)
    if i%8==0:
        line('Crest | fine optical data path',[(x,z),(x+.5,z),(x+.8,z+.5),(x+1.3,z+.5)],-25.95,.02,cyan)
# Warm index insert illumination with real gold shadow separators.
for ob in scene.objects:
    if ob.name.startswith('Crest | segmented ceramic index'):
        ob.data.materials[0]=ivory2
    if ob.name.startswith('Crest | luminous radial tick'):
        ob.data.materials[0]=white
ring('Crest | warm luminous index bed',0,104,-24.3,19.3,1.2,.12,warm)
# Separate field material: tiny bright particles on a deep blue, faintly noisy lens.
field=bpy.data.materials.new(PREFIX+'celestial blue optical field');field.use_nodes=True
n,l=field.node_tree.nodes,field.node_tree.links;b=n.get('Principled BSDF');b.inputs['Metallic'].default_value=.55;b.inputs['Roughness'].default_value=.19
noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=19;noise.inputs['Detail'].default_value=5
ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.2;ramp.color_ramp.elements[0].color=(.002,.009,.029,1);ramp.color_ramp.elements[1].position=.8;ramp.color_ramp.elements[1].color=(.015,.11,.24,1)
l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],b.inputs['Base Color']);l.new(ramp.outputs[0],b.inputs['Emission Color']);b.inputs['Emission Strength'].default_value=.65
bpy.data.objects['Crest | central blue lens'].data.materials[0]=field

# Wider translucent feather membranes and more luminous facet shading.
wing=bpy.data.materials[PREFIX+'holographic cyan membrane'];mix=next(n for n in wing.node_tree.nodes if n.type=='MIX_SHADER');mix.inputs[0].default_value=.48
em=next(n for n in wing.node_tree.nodes if n.type=='EMISSION');em.inputs[0].default_value=(.02,.35,1,1);em.inputs[1].default_value=3
for ob in scene.objects:
    if ob.name.startswith('Wing | individually swept feather'):
        for i in range(25):
            delta=ob.data.vertices[i].co.z-ob.data.vertices[i+25].co.z
            ob.data.vertices[i+25].co.z-=delta*.9
    if ob.name.startswith('Wing | violet feather trailing edge'):
        ob.hide_render=True;ob.hide_set(True)
# Broader orbit ribbons match the drawn energy hoops; segment front crossings to avoid a wire across the portal.
for ob in list(scene.objects):
    if ob.name.startswith('Halo | orbiting light ribbon'):
        ob.hide_render=True;ob.hide_set(True)
for z,rx,ry,tilt,mat in [(105,42,15,-.15,warm),(68,48,17,.12,white),(38,36,12,-.14,cyan)]:
    for start,end in [(0,math.pi*.85),(math.pi*1.08,math.pi*1.33),(math.pi*1.72,math.tau)]:
        points=[]
        for j in range(65):
            a=start+(end-start)*j/64;points.append((rx*math.cos(a),ry*math.sin(a),z+tilt*rx*math.cos(a)))
        tube('Halo | segmented energy ribbon',points,.19 if z!=105 else .105,mat)
camera((25,-265,87),(0,0,65),146);live_view();save('05 reference comparison: sculpted armor and corrected optical lighting')
