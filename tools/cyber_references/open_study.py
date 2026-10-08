import hashlib, shutil
from mathutils import Vector
word={2:'two',3:'three'}[reference]
OUT=ROOT/('art/cyber_reference_'+word+'_mcp');OUT.mkdir(parents=True,exist_ok=True)
master=OUT/('reference_'+word+'.blend')
assert not master.exists(), 'Existing master: open it explicitly instead of resetting progress'
donor={2:'01_line_trooper',3:'05_armored_sprinter'}[reference]
source=ROOT/'art/cyber_zombie_roster'/donor/(donor+'.blend')
bpy.ops.wm.open_mainfile(filepath=str(source))
scene=bpy.context.scene
for ob in list(scene.objects):
    if 'attachment_bone' in ob:bpy.data.objects.remove(ob,do_unlink=True)
# Reuse the approved reference-one surface materials, including packed bitmap wear.
with bpy.data.libraries.load(str(ROOT/'art/cyber_reference_one_mcp/reference_one.blend'),link=False) as (src,dst):
    dst.materials=[n for n in src.materials if n.startswith('R1 |')]
scene['cyber_reference_number']=reference
scene['cyber_study_output']=str(OUT)
scene['authoring_transport']='upstream Blender MCP execute_blender_code; localhost:9877'
scene['cyber_finish_revision']=6;scene['cyber_reference_pass']=reference
base=[o for o in scene.objects if o.type=='MESH' and 'attachment_bone' not in o and o.name!='Studio floor']
def signature(ob):
    return hashlib.sha256(repr(([tuple(v.co) for v in ob.data.vertices],[[(g.group,g.weight) for g in v.groups] for v in ob.data.vertices],[tuple(p.vertices) for p in ob.data.polygons])).encode()).hexdigest()
scene['donor_signatures']=json.dumps({o.name:signature(o) for o in base})
rig=bpy.data.objects['Cybercity_zombie_rig']
for pb in rig.pose.bones:pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0)
ref=Path.home()/'Downloads'/('CyberZombie'+str(reference)+'.png');shutil.copy2(ref,OUT/ref.name)
image=bpy.data.images.load(str(OUT/ref.name),check_existing=True);image.pack()
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='IMAGE_EDITOR':area.spaces.active.image=image
        elif area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL';area.spaces.active.overlay.show_overlays=False
bpy.ops.wm.save_as_mainfile(filepath=str(master))
print(json.dumps({'base':[{'name':o.name,'bounds':[[min((o.matrix_world@v.co)[i] for v in o.data.vertices),max((o.matrix_world@v.co)[i] for v in o.data.vertices)] for i in range(3)]} for o in base], 'bones':{b.name:list(b.head_local) for b in rig.data.bones if any(x in b.name for x in ('head','spine','wrist','elbow','shoulder','knee','ankle','hip'))}},indent=2))
