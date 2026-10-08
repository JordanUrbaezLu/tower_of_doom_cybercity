"""An enclosed executioner helmet: folded jaw, fitted crown, brilliant red slit.

Run on the accepted reference-three master. This supersedes the raised welder
and mouth-only guard; no separate forehead ornament returns.
"""
import sys, runpy
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from equipment import *
assert REFERENCE == 3
bone = 'j_head'
retired = []
for ob in list(scene.objects):
    if ob.get('attachment_bone') == bone:
        retired.append(ob.name)
        bpy.data.objects.remove(ob, do_unlink=True)
runpy.run_path(str(HERE / 'three_remove_backpack.py'))

armor = mat('executioner helmet forged graphite', (.105, .135, .145), 'metal')
rim = mat('executioner helmet cold worn edges', (.30, .33, .34), 'metal')
patch = mat('executioner helmet repaired plate', (.155, .19, .20), 'metal')
dark = mat('executioner helmet optical recess', (.003, .002, .003), 'rubber')
# Constant radiance keeps a readable single line; procedural scratches belong
# on the housing, not as dark breaks in the aperture.
def optic(name, color, strength):
    material = mat(name, color, 'light')
    bs = material.node_tree.nodes['Principled BSDF']
    for key in ('Emission Color', 'Base Color', 'Roughness', 'Normal'):
        for link in list(bs.inputs[key].links):
            material.node_tree.links.remove(link)
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Emission Color'].default_value = (*color, 1)
    bs.inputs['Emission Strength'].default_value = strength
    bs.inputs['Roughness'].default_value = .24
    return material

red = optic('executioner continuous red aperture', (.95, .006, .003), 14.0)
core = optic('executioner red hot optical core', (1.0, .026, .012), 16.0)

# Twelve fitted facets, with a forward ridge continuous from brow to jaw.
# Coordinates enclose the skull; the lower neck and donor shoulder bib remain.
N = 12
def perimeter(z, width, front, rear):
    result = []
    for i in range(N):
        angle = math.tau * i / N
        x = width * math.sin(angle)
        y = -1.2 - (front if math.cos(angle) >= 0 else rear) * math.cos(angle)
        result.append(Vector((x, y, z)))
    return result

rows = [
    perimeter(61.35, 3.25, 5.30, 4.20),
    perimeter(63.30, 4.15, 5.55, 4.92),
    perimeter(65.54, 4.35, 5.55, 5.37),
    perimeter(66.13, 4.35, 5.55, 5.37),
    perimeter(68.35, 4.25, 5.05, 5.17),
    perimeter(69.75, 3.65, 4.55, 4.10),
    perimeter(70.65, 2.55, 3.50, 3.20),
    perimeter(71.15, .80, 1.15, 1.05),
]
# A strong central fold continues through the jaw and optic. It gives the
# front a cutting prow rather than a round bucket, with a slightly angry slit.
for row in (0,1,2,3):
    rows[row][0].y-=.95 if row==0 else 1.0
rows[4][0].y-=.40
for row in (2,3):
    rows[row][0].z-=.11
    for index in (2,10):
        rows[row][index].z+=.06
front_segments = (0, 1, 10, 11)
outside=[p for row in rows for p in row]
inside=[p+Vector((-p.x,-1.2-p.y,0)).normalized()*.20 for p in outside]
for p in inside[-N:]:
    p.z-=.20
offset=len(outside);shell_faces=[]
for band in range(len(rows)-1):
    for i in range(N):
        j = (i+1) % N
        # The eye opening is backed by a recessed optical cartridge below.
        if band == 2 and i in front_segments:
            continue
        face=(band*N+i,band*N+j,(band+1)*N+j,(band+1)*N+i)
        shell_faces.extend((face,tuple(v+offset for v in reversed(face))))
# A connected double-wall shell avoids pinholes between independently beveled
# plates. Only the optical opening and neck opening remain, with real returns.
top=(len(rows)-1)*N
shell_faces.extend((tuple(top+i for i in range(N)),tuple(top+offset+i for i in range(N-1,-1,-1))))
for i in range(N):
    j=(i+1)%N
    shell_faces.append((i,i+offset,j+offset,j))
for i in front_segments:
    j=(i+1)%N
    for row in (2,3):
        a,b=row*N+i,row*N+j
        shell_faces.append((a,b,b+offset,a+offset))
for i in (2,10):
    a,b=2*N+i,3*N+i
    shell_faces.append((a,b,b+offset,a+offset))
mesh('Executioner | enclosed skull and folded jaw shell',outside+inside,shell_faces,armor,bone)
# Subtle manufactured crown seams follow the fitted hull, without a crest.
for i in (3,6,9):
    for band in range(4,7):
        a,b=rows[band][i],rows[band+1][i]
        n=Vector((a.x,a.y+1.2,.20)).normalized()
        rod('Executioner | fitted crown weld seam',a+n*.015,b+n*.015,.023,rim,bone,8)
for i in range(N):
    j = (i+1) % N
    rod('Executioner | rolled nape and jaw edge', rows[0][i], rows[0][j], .065, rim, bone, 8)

# Four coplanar optical panels meet across the ridge without a nose divider.
# Black returns shelter the emitter; the inner red core is one thinner line.
for i in front_segments:
    j = (i+1) % N
    a, b = rows[2][i], rows[2][j]
    normal = Vector(((a+b).x, (a+b).y+2.4, 0)).normalized()
    # Actual face normal, oriented outward, is more precise at the two wings.
    normal = (b-a).cross(Vector((0,0,1))).normalized()
    if normal.y > 0:
        normal = -normal
    def strip(name, bottom, top, recess, material, thickness):
        aa, bb = a+normal*recess, b+normal*recess
        za=a.z-65.54;zb=b.z-65.54
        points = [Vector((aa.x,aa.y,bottom+za)), Vector((bb.x,bb.y,bottom+zb)),
                  Vector((bb.x,bb.y,top+zb)), Vector((aa.x,aa.y,top+za))]
        back = [p-normal*thickness for p in points]
        mesh(name, points+back,
             [(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],
             material, bone)
    strip('Executioner | sealed optical cartridge', 65.51,66.16,-.07,dark,.20)
    # The steel brow is a fitted lip of the helmet, no elevated shield.
    rod('Executioner | worn brow aperture lip',rows[3][i],rows[3][j],.055,rim,bone,8)

def optic_band(name,bottom,top,recess,material,thickness):
    # Shared vertices at the prow keep the emitter unbroken around every fold.
    indices=(10,11,0,1,2);centers=[rows[2][i] for i in indices];normals=[]
    for index,p in enumerate(centers):
        tangents=[]
        if index:tangents.append(p-centers[index-1])
        if index+1<len(centers):tangents.append(centers[index+1]-p)
        normal=sum((t.cross(Vector((0,0,1))).normalized() for t in tangents),Vector()).normalized()
        normals.append(normal)
    verts=[]
    for depth in (recess,recess-thickness):
        for height in (bottom,top):
            for p,n in zip(centers,normals):
                q=p+n*depth
                verts.append(Vector((q.x,q.y,height+p.z-65.54)))
    count=len(centers);faces=[]
    for i in range(count-1):
        j=i+1
        faces.extend(((i,j,j+count,i+count),
                      (i+2*count,i+3*count,j+3*count,j+2*count),
                      (i,i+2*count,j+2*count,j),
                      (i+count,j+count,j+3*count,i+3*count)))
    faces.extend(((0,count,3*count,2*count),
                  (count-1,3*count-1,4*count-1,2*count-1)))
    mesh(name,verts,faces,material,bone)
optic_band('Eye strip | continuous executioner red',65.64,66.02,.024,red,.04)
optic_band('Eye strip | continuous hot red core',65.775,65.885,.041,core,.02)

# Flush temple cassettes and deep horizontal vents create an industrial profile.
# Quiet metal/amber details keep the red eye aperture dominant.
for side in (-1,1):
    q = Vector((side*4.31,-1.12,66.45));normal=Vector((side,0,0))
    panel('Executioner | inset temple armor',q,normal,3.10,3.70,bone,patch,depth=.14,fasteners=False)
    for z in (65.45,66.12,66.79):
        panel('Executioner | temple cooling recess',q+Vector((side*.16,.15,z-q.z)),normal,
              1.55,.20,bone,dark,depth=.026,fasteners=False)
        rod('Executioner | cooling slot metal lip',
            (side*4.52,-1.86,z-.11),(side*4.52,-.39,z-.11),.025,rim,bone,8)
    for y,z in ((-2.25,67.7),(.03,64.95)):
        bolt('Executioner | recessed temple captive screw',(side*4.55,y,z),normal,bone,.13)
    # A low-profile jaw hinge and doubled seam have functional-looking roots.
    cyl('Executioner | jaw hinge bearing',(side*3.75,-.35,63.2),.47,.18,armor,bone,normal,24)
    cyl('Executioner | jaw hinge hex lock',(side*3.88,-.35,63.2),.20,.08,rim,bone,normal,6)
    for z in (62.65,63.05):
        p=Vector((side*2.75,-4.95,z));n=Vector((side*.58,-.82,0))
        panel('Executioner | recessed jaw breather',p,n,.90,.15,bone,dark,depth=.018,fasteners=False)

# A small asymmetric riveted repair plate and workshop stamp, away from the slit.
a,b=rows[1][11],rows[1][0]
n=(b-a).cross(Vector((0,0,1))).normalized()
p=a.lerp(b,.48)+n*.035-Vector((0,0,.20))
panel('Executioner | sacrificial cheek repair',p,n,1.40,.85,bone,patch,depth=.06,fasteners=False)
for dx in (-.43,.43):
    bolt('Executioner | cheek repair rivet',p+Vector((dx,.02,-.20))+n*.08,n,bone,.085)
label('Executioner | MK33 cheek stamp','MK / 33',p+n*.075+Vector((0,0,.13)),n,.15,bone,mat=letter)

# Rear access cassette stays tight to the nape, clear of the dorsal spikes.
p=Vector((0,3.86,66.7));n=Vector((0,1,0))
panel('Executioner | rear service cassette',p,n,3.20,2.6,bone,armor,depth=.18,fasteners=False)
for z in (65.95,66.40,66.85,67.30):
    panel('Executioner | rear deep exhaust slot',(0,4.08,z),n,2.25,.16,bone,dark,depth=.02,fasteners=False)
for side in (-1,1):
    bolt('Executioner | rear service captive screw',(side*1.22,4.10,67.7),n,bone,.105)
label('Executioner | rear asset stencil','EXEC / 115',(0,4.09,65.6),n,.17,bone,mat=letter)

scene['armored_helmet'] = 'executioner_enclosed_v1'
scene['armored_eye_strip'] = 'executioner_red_14_v1'
scene['armored_mouth_guard'] = 'integrated_folded_jaw_v2'
scene['armored_forehead_shield_removed'] = True
scene['armored_emission_scale'] = 16.0
scene['armored_native_scale'] = 1.33
scene['armored_helmet_spec'] = json.dumps({
    'policy':'executioner_enclosed_v1','closed_crown':True,'full_skull_shell':True,
    'separate_forehead_shield':False,'eye_aperture_height':.38,'eye_core_height':.11,
    'eye_emission_strength':14.0,'eye_core_emission_strength':16.0,
    'previous_eye_emission_strength':3.5,'emission_bake_range':16.0,
    'dim_body_lamps_preserve_radiance':True,'head_bone':bone,
})
scene['authoring_transport'] = 'Original Blender MCP master; enclosed helmet refined in Blender Python, 2026-10-07'
print('ARMORED_HELMET_AUTHORED',scene['armored_helmet_spec'],flush=True)
