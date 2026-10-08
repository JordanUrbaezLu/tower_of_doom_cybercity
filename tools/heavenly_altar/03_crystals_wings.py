import sys,importlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import design_lib as D
importlib.reload(D)
from design_lib import *
rng=random.Random(9462)
D.group='05 Crystals and induction pillars'
crystal=D.material('faceted energized crystal',(.08,.12,.38),.55,.16,.5)
bs=crystal.node_tree.nodes.get('Principled BSDF');bs.inputs['Coat Weight'].default_value=.7
def crystal_shard(name,x,y,z,r,h,seed=0):
    n=5;vs=[]
    for level,rr in [(0,r*.3),(h*.13,r),(h*.83,r*.9)]:
        for i in range(n):a=i*math.tau/n+.22;vs.append((x+rr*math.cos(a),y+rr*math.sin(a),z+level))
    vs.append((x+r*.12,y,z+h));fs=[tuple(range(n-1,-1,-1))]
    for j in range(2):
        for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    for i in range(n):fs.append((2*n+i,2*n+(i+1)%n,3*n))
    ob=mesh(name,vs,fs,crystal)
    ob.data.materials.append(violet);ob.data.materials.append(cyan)
    for p in ob.data.polygons:
        if p.index%7==seed%7:p.material_index=1 if seed%2 else 2
    for i in range(n):
        if i%2==0:
            tube(name+' luminous facet', [vs[n+i],vs[2*n+i],vs[-1]],.055,cyan if (i+seed)%2 else violet,6)
    tube(name+' internal axial filament',[(x,y-r*.75,z+h*.15),(x,y-r*.75,z+h*.8)],.09,cyan)
    return ob
for s in (-1,1):
    # Tall crystal columns in real machined cradles rather than floating strips.
    for z in (16,43,91,115):
        xx=29 if z<91 else 27
        basez=z if z!=43 else 48
        for j in range(3):
            crystal_shard('Crystal | prism cluster',s*(xx+(j-1)*1.8),-12+(j%2)*1.2,basez,.9 if j!=1 else 1.3,(12 if z<100 else 11)+(3 if j==1 else 0),j)
        panel('Crystal | gold saddle',[(s*(xx-4),basez-.5),(s*(xx+4),basez-.5),(s*(xx+3),basez+1),(s*(xx-3),basez+1)],-14,6,gold,.15)
    for j in range(4):
        xx=s*(27+j*.75);z=18+j*1.2
        line('Pillar | long rising violet beam',[(xx,z),(xx,44)],-11-j*.35,.08,violet if j%2 else cyan)
    # Larger lower crystals, nestled between shaped dark/gold fork blades.
    crystal_shard('Crystal | large lower conduit',s*29,-11,16,2.2,23,1 if s<0 else 2)
    for q in (-1,1):
        pp=[(s*(29+q*3),14),(s*(29+q*4),15),(s*(29+q*4),28),(s*(29+q*2),20)]
        panel('Crystal | protective fork',pp,-14,8,dark,.15)
        line('Crystal | gold fork edge',[(s*(29+q*3),15),(s*(29+q*3.5),26)],-14.25,.18,goldlight)
    # Tall, finely segmented spires behind top shoulder armor.
    for j in range(3):
        xx=s*(26+j*1.2);h=11+3*(j==1)
        line('Spire | needle conductor',[(xx,115),(xx,115+h)],-5,.075,warm)
        line('Spire | violet data blade',[(xx-.3*s,115),(xx-.3*s,121+j)],-5.2,.21,violet)

D.group='06 Holographic wings'
# Each feather is a curved ribbon mesh with luminous leading edges and wire ribs.
wingmat=bpy.data.materials.get(PREFIX+'holographic cyan membrane') or bpy.data.materials.new(PREFIX+'holographic cyan membrane')
wingmat.use_nodes=True;n,l=wingmat.node_tree.nodes,wingmat.node_tree.links;n.clear()
out=n.new('ShaderNodeOutputMaterial');mix=n.new('ShaderNodeMixShader');tr=n.new('ShaderNodeBsdfTransparent');em=n.new('ShaderNodeEmission')
em.inputs[0].default_value=(.02,.24,1,1);em.inputs[1].default_value=2.2;mix.inputs[0].default_value=.28
l.new(tr.outputs[0],mix.inputs[1]);l.new(em.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs[0]);wingmat.surface_render_method='DITHERED'
for s in (-1,1):
    for j in range(7):
        root=Vector((s*30,-7,91-j*.18));tip=Vector((s*(48-j*.9),-6,107-j*3.2))
        top=[];bottom=[]
        for k in range(25):
            t=k/24;p=root.lerp(tip,t);p.z-=math.sin(math.pi*t)*(4-j*.25)
            top.append(tuple(p));q=p.copy();q.z-=math.sin(math.pi*t)*(1.2+j*.08);bottom.append(tuple(q))
        mesh('Wing | individually swept feather',top+bottom,[(k,k+1,25+k+1,25+k) for k in range(24)],wingmat)
        tube('Wing | cyan leading edge',top,.055,cyan,6);tube('Wing | violet feather trailing edge',bottom,.04,violet,6)
        for k in (5,10,15,20):tube('Wing | feather lattice rib',[top[k],bottom[k]],.021,cyan,5)
    # Radial mounting emitter follows the frame's shoulder join.
    disc('Wing | gold emitter pod',s*30,91,-8.5,2.6,2,gold)
    disc('Wing | cyan emitter lens',s*30,91,-9,1.8,.8,cyan)

D.group='07 Orbital ribbons and hanging sigils'
for z,rx,ry,tilt,mat in [(105,42,15,-.15,warm),(68,48,17,.12,white),(38,36,12,-.14,cyan)]:
    pts=[]
    for i in range(161):
        a=math.tau*i/160;pts.append((rx*math.cos(a),ry*math.sin(a),z+tilt*rx*math.cos(a)))
    tube('Halo | orbiting light ribbon',pts,.105,mat)
    if z==105:tube('Halo | fine parallel orbit',[(x,y,zz+.7) for x,y,zz in pts],.04,white,6)
for s in (-1,1):
    # Pennants are optical banners with a distinct tapered gold rim and glyph.
    x=s*44
    points=[(x-2.9,60),(x+2.9,60),(x+2.9,40),(x,36),(x-2.9,40)]
    panel('Sigil | dark violet banner',points,0,.25,optic,0)
    outline('Sigil | gold outline',points,-.25,.075,warm)
    outline('Sigil | inset purple outline',[(x-2.4,59),(x+2.4,59),(x+2.4,40.2),(x,37),(x-2.4,40.2)],-.35,.07,violet)
    ring('Sigil | celestial circle',x,50,-.5,1.55,.1,.12,warm,N=48)
    line('Sigil | center axis',[(x,37),(x,55)],-.6,.05,warm)
    line('Sigil | arrowhead',[(x-.4,54.1),(x,55),(x+.4,54.1)],-.6,.06,warm)
    for j in range(5):
        line('Sigil | tassel',[(x+(j-2)*.8,39),(x+(j-2)*.8,35-2*(j==2))],-.4,.06,pink if j%2 else warm)
    # Falling data: restrained thin trails, larger packets at irregular intervals.
    for j in range(20):
        xx=s*rng.uniform(27,44);zz=rng.uniform(20,94);yy=rng.uniform(-2,5);length=rng.uniform(3,11)
        tube('Data | falling optical trail',[(xx,yy,zz),(xx,yy,zz-length)],.018,cyan if j%3 else violet,5)
        box('Data | photon packet',(xx,yy,zz-length*.8),(.12,.09,rng.uniform(.35,1.15)),cyan if j%2 else pink,0)
save('03 crystal conduits holographic feathers orbital light and sigils')
