"""Build map-owned zombie model/character assets from stock donors and baked kit.

Does not write shared Mod Tools files. tools/sync_to_modtools.ps1 deploys them.
Stock GDT DB opened read-only. Derived assets preserve stock AI and hitboxes.
"""
import copy
import hashlib
import json
import sqlite3
import sys
from pathlib import Path
from cyber_equipment_layout import body_groups, BODY_GROUPS, LEFT_HAND
from cyber_arm_replacement import POLICY as ARM_POLICY, replace_arm_surfaces
from cyber_back_spikes import POLICY as BACK_SPIKE_POLICY, enlarge_back_spikes

ROOT=Path(__file__).resolve().parents[1]
MT=Path(r'C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130')
OUT=ROOT/'model_export/tod_cyber_zombie'
STAGE_ROOT=ROOT/'art/cyber_zombie_roster/engine_kit'
STAGE=STAGE_ROOT/'trooper'
VARIANT='trooper'
sys.path.insert(0,str(Path.home()/'AppData/Roaming/Blender Foundation/Blender/4.2/scripts/addons/BetterBetterBlenderCOD'))
from PyCoD import xmodel

# Python SQLite cannot parse the unrelated 2000+-column scriptbundle schema.
# This flag skips malformed schema entries. mode=ro prohibits actual DB writes.
db=sqlite3.connect((MT/'gdtdb/gdt.db').as_uri()+'?mode=ro',uri=True)
db.execute('pragma writable_schema=ON');db.row_factory=sqlite3.Row
donors={};asset_copies={}
def asset(kind,name):
    d=dict(db.execute('select * from '+kind+' where _name=?',(name,)).fetchone())
    d={k:v for k,v in d.items() if not k.startswith('_') and k!='PK_id'}
    donors[kind+':'+name]=d
    return d

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def path_of(s):return MT/'model_export'/s.replace('\\\\','/').replace('\\','/')
def block(name,kind,fields,parent=None):
    # GDT inheritance resolves only within the SAME GDT, not across the DB.
    # Materialize the resolved stock fields, then apply cosmetic overrides.
    if parent:
        donor_fields=asset(kind,parent)
        # JAPANESE FASTFILE (2026-09-16, user's call). The linker DROPS a
        # japaneseUnsafe xmodel from the ja_ pass while the zone still names it,
        # so the v19.17 publish died on nine "xmodel is missing" errors: both
        # trooper and relay bodies (donor c_zom_der_zombie_body1) and the
        # sprinter (donor c_t8_zmb_mob_zombie_body3). The flag rides in from
        # those donors and is inconsistent in stock's OWN data - body1 carries
        # it, its sibling body2 behind crown/signal does not, and every
        # severed-limb gib we derive is unflagged while the intact bodies are.
        # These are our own derived cosmetic re-skins, so they ship unflagged
        # and a Japanese client gets the whole horde instead of two missing
        # bodies and a missing sprinter. Recorded as a real override so the
        # manifest shows it; verify_cyber_roster.py permits exactly this one
        # non-cosmetic xmodel field, only 1 -> 0, and nothing else.
        if kind=='xmodel' and donor_fields.get('japaneseUnsafe') not in (None,'',0,'0',0.0):
            fields={**fields,'japaneseUnsafe':0}
        asset_copies[name]={'kind':kind,'donor':parent,'overrides':dict(fields)}
        fields={**donor_fields,**fields}
    head=f'"{name}" ( "{kind}.gdf" )'
    def val(v):
        if isinstance(v,float) and v.is_integer():return str(int(v))
        return str(v).replace('"','\\"').replace('\r','\\r').replace('\n','\\n')
    return '\t'+head+'\n\t{\n'+''.join(f'\t\t"{k}" "{val(v)}"\n' for k,v in fields.items() if v is not None)+'\t}\n'

blocks=[];records=[]
lod_fields=('filename','mediumLod','lowLod','lowestLod','lod4File','lod5File','lod6File')
cloth='mtl_c_zom_der_zombie_body2'
skin=f'{cloth} mtl_tod_cyber_cloth\\r\\n'

def append_group(m,group,lod,force_bone=None,rotate_equipment=False):
    kit=json.loads((STAGE/f'{group}_lod{lod}.json').read_text())
    bi={b.name.lower():i for i,b in enumerate(m.bones)}
    bone=force_bone or kit['bone'];assert bone in bi,(group,lod,bone)
    mid=next((i for i,mat in enumerate(m.materials) if mat.name=='mtl_tod_roster_'+VARIANT),None)
    if mid is None:
        mid=len(m.materials);m.materials.append(xmodel.Material('mtl_tod_roster_'+VARIANT,'Phong',{}))
    mesh=xmodel.Mesh('cyber_'+group)
    rotate=lambda p:(-p[1],p[0],p[2]) if rotate_equipment else tuple(p)
    mesh.verts=[xmodel.Vertex(rotate(p),[(bi[bone],1.0)]) for p in kit['verts']]
    for corners in kit['faces']:
        assert all(sum(v*v for v in c['n'])>.9 for c in corners), (group,lod,'invalid normal')
        f=xmodel.Face(len(m.meshes),mid)
        f.indices=[xmodel.FaceVertex(c['v'],rotate(c['n']),(1,1,1,1),tuple(c['uv'])) for c in corners]
        mesh.faces.append(f)
    m.meshes.append(mesh)

def model(name,donor,groups=(),force_bone=None,extra=None):
    fields=asset('xmodel',donor)
    overrides={'skinOverride':'mtl_c_zom_der_zombie_body1 mtl_tod_roster_cloth1\\r\\n'} if 'body1' in donor else {}
    overrides.update(extra or {})
    for lod,lodfield in enumerate(lod_fields):
        src=fields[lodfield]
        if not src:continue
        p=path_of(src)
        assert p.exists(),p
        if not groups:continue  # same stock binary, only a cloth material override
        # Keep the donor object table. Flattened loading retains original face
        # object IDs; writing a smaller table then silently drops whole parts
        # in BO3 (the body's lower mesh is object 3, not object 0).
        m=xmodel.Model();m.LoadFile_Bin(str(p),split_meshes=True)
        source_meshes=len(m.meshes)
        source_verts=sum(len(mesh.verts) for mesh in m.meshes)
        source_faces=sum(len(mesh.faces) for mesh in m.meshes)
        removed_arm_faces=[];removed_arm_vertices=[]
        back_spikes=None
        if name=='tod_cyber_sprinter':
            assert donor=='c_t8_zmb_mob_zombie_body3' and VARIANT=='sprinter'
            back_spikes=enlarge_back_spikes(m,digest(p))
            assert back_spikes==json.loads((STAGE/'source_manifest.json').read_text())['back_spikes']
            removed_arm_faces,removed_arm_vertices=replace_arm_surfaces(m)
            assert sum(removed_arm_faces)>1000,removed_arm_faces
        rotate_equipment=donor=='c_t8_zmb_mob_zombie_body3'
        for group in groups:append_group(m,group,lod,force_bone,rotate_equipment)
        for index,mesh in enumerate(m.meshes):
            assert all(f.mesh_id==index for f in mesh.faces)
        dst=OUT/f'{name}_lod{lod}.xmodel_bin'
        # Preserve unchanged donors' timestamps so an armored-only iteration
        # does not ask the native converter to rebuild the regular roster.
        pending=dst.with_suffix('.pending.xmodel_bin')
        m.WriteFile_Bin(str(pending))
        if dst.exists() and digest(dst)==digest(pending):
            pending.unlink()
        else:
            pending.replace(dst)
        check=xmodel.Model();check.LoadFile_Bin(str(dst),split_meshes=True)
        assert len(check.meshes)==len(m.meshes)
        assert sum(len(x.faces) for x in check.meshes)==sum(len(x.faces) for x in m.meshes)
        assert [(b.name,b.parent) for b in check.bones]==[(b.name,b.parent) for b in m.bones]
        # All retained donor vertices and weights survive the round-trip.
        for old_mesh,new_mesh in zip(m.meshes[:source_meshes],check.meshes[:source_meshes]):
            assert old_mesh.name==new_mesh.name
            assert len(old_mesh.verts)==len(new_mesh.verts)
            assert len(old_mesh.faces)==len(new_mesh.faces)
            for old,new in zip(old_mesh.verts,new_mesh.verts):
                assert max(abs(a-b) for a,b in zip(old.offset,new.offset))<.0001
                assert len(old.weights)==len(new.weights)
                assert all(ai==bi and abs(av-bv)<.0001 for (ai,av),(bi,bv) in zip(old.weights,new.weights))
        overrides[lodfield]='tod_cyber_zombie\\\\'+dst.name
        records.append({'asset':name,'lod':lod,'source':str(p),'source_sha256':digest(p),
                        'file':str(dst.relative_to(ROOT)),'sha256':digest(dst),
                        'base_vertices':source_verts,'base_triangles':source_faces,
                        'triangles':sum(len(x.faces) for x in check.meshes),'bones':len(check.bones),
                        'base_meshes':source_meshes,'mesh_names':[x.name for x in check.meshes],
                        'arm_surface_replacement':ARM_POLICY if name=='tod_cyber_sprinter' else None,
                        'removed_arm_faces':removed_arm_faces,
                        'removed_arm_vertices':removed_arm_vertices,
                        'back_spikes':back_spikes,
                        'groups':list(groups),'force_bone':force_bone,'variant':VARIANT,'rotate_equipment':rotate_equipment,'material':'mtl_tod_roster_'+VARIANT,'source_asset':donor})
    blocks.append(block(name,'xmodel',overrides,parent=donor))

def variant(name):
    global VARIANT,STAGE
    VARIANT=name;STAGE=STAGE_ROOT/name

def body_family(short,source,kit):
    variant(kit)
    for suffix,donor in [('body',''),('upper','_g_upclean'),
        ('rarmoff','_g_rarmoff'),('larmoff','_g_larmoff'),
        ('legs','_g_lowclean'),('rlegoff','_g_rlegoff'),
        ('llegoff','_g_llegoff'),('nolegs','_g_blegsoff')]:
        model('tod_cyber_'+short+'_'+suffix,source+donor,body_groups(kit,suffix))

body_family('trooper','c_zom_der_zombie_body1','trooper')
body_family('relay','c_zom_der_zombie_body1','relay')
for kit in ('trooper','relay'):
    # The newly outfit-colored brace must retain its finish after dismemberment.
    variant(kit)
    model('tod_cyber_'+kit+'_arm_gib','c_zom_zod_zombie_fem_body1_g_larmspawn',('arm',),'j_wrist_le')
    model('tod_cyber_'+kit+'_leftleg_gib','c_zom_zod_zombie_fem_body1_g_llegspawn',('shin_le',),'j_ankle_le')
    model('tod_cyber_'+kit+'_rightarm_gib','c_zom_zod_zombie_fem_body1_g_rarmspawn',('rightarm',),'j_wrist_ri')
    model('tod_cyber_'+kit+'_rightleg_gib','c_zom_zod_zombie_fem_body1_g_rlegspawn',('shin_ri',),'j_ankle_ri')
for index in (1,2,3):
    variant('trooper' if index==1 else 'signal')
    model('tod_cyber_hhead'+str(index),'c_zom_der_zombie_head'+str(index),('head',))
for index in (2,3):
    variant('relay')
    model('tod_cyber_bhead'+str(index),'c_zom_der_zombie_head'+str(index),('head',))
for kit in ('trooper','signal'):
    variant(kit)
    model('tod_cyber_helmet_'+kit,'c_zom_der_zombie_helmet1',('helmet',) if kit=='signal' else ())

variant('sprinter')
assert json.loads((STAGE/'source_manifest.json').read_text()).get('arm_surface_replacement')==ARM_POLICY
assert json.loads((STAGE/'source_manifest.json').read_text())['back_spikes']['policy']==BACK_SPIKE_POLICY
# The imported BO4 body has one authored LOD. Generate lower LODs natively,
# preserving its rig and source topology at LOD0; kit is rotated back +90 deg.
auto={'autogen'+field:1 for field in ('MediumLod','LowLod','LowestLod','Lod4','Lod5','Lod6','Lod7')}
# User 2026-10-06: 33% larger armored zombie. Compile-time model scaling;
# never SetScale on a live actor (known native crash). Head uses the same scale.
auto['scale']=1.33
armor_skin=[]
for index,part in enumerate(('torso','sleeves','leftleg','rightleg')):
    donor='mtl_c_t8_zmb_mob_zombie_body3_'+part
    target='mtl_tod_roster_armor_'+part
    blocks.append(block(target,'material',{'colorTint':'.48 .55 .60 1'},parent=donor))
    armor_skin.append(donor+' '+target)
auto['skinOverride']='\\r\\n'.join(armor_skin)+'\\r\\n'
model('tod_cyber_sprinter','c_t8_zmb_mob_zombie_body3',BODY_GROUPS['sprinter'],extra=auto)
for index in (1,2,3):
    # Existing head identity survives promotion; only its reference-three kit changes.
    # Stock Der Riese heads use the regular coordinate frame, not the BO4 body frame.
    model('tod_cyber_sprinter_head'+str(index),'c_zom_der_zombie_head'+str(index),('head',),extra={'scale':1.33})

blocks.append(block('mtl_tod_roster_cloth1','material',{'colorTint':'.23 .29 .34 1'},parent='mtl_c_zom_der_zombie_body1'))
for kit in ('trooper','signal','relay','sprinter'):
    prefix='i_tod_roster_'+kit
    for suffix,semantic in [('c','diffuseMap'),('n','normalMap'),('s','specularMap'),('g','glossMap'),('e','diffuseMap')]:
        fields={'baseImage':'model_export\\\\tod_cyber_zombie\\\\_images\\\\'+prefix+'_'+suffix+'.png',
                'imageType':'Texture','type':'image','semantic':semantic,'streamable':'1',
                'compressionMethod':'compressed' if suffix in ('n','g') else 'compressed high color'}
        if suffix in ('c','s','e'):fields['coreSemantic']='sRGB3chAlpha'
        blocks.append(block(prefix+'_'+suffix,'image',fields))
    blocks.append(block('mtl_tod_roster_'+kit,'material',{
        'surfaceType':'flesh','template':'material.template','materialCategory':'Geometry Advanced',
        'materialType':'lit_emissive_advanced_fullspec','colorMap':prefix+'_c','normalMap':prefix+'_n',
        'cosinePowerMap':prefix+'_g','specColorMap':prefix+'_s','specMapEnable':'1','specColorTint':'1 1 1 1',
        'colorMap00':prefix+'_e','colorTint':'1 1 1 1','colorTint1':'1 1 1 1',
        'scaleRGB':str(int(json.loads((ROOT/'art/cyber_zombie_roster/engine_kit'/kit/'source_manifest.json').read_text())['emission_scale'])) if kit=='sprinter' else '6',
        # Fullspec's emissive layerDepth must not inherit the native 0.1 offset.
        'waterRoughness':'0',
        'emissiveIncompetence':'1','emissiveFalloff':'0','normalHeightScale':'1',
        'glossRangeMin':'1','glossRangeMax':'17','specAmount':'1','reflectionProbeAmount':'1',
        'textureAtlasRowCount':'1','textureAtlasColumnCount':'1','usage':'<not in editor>'}))

blocks.append(block('tod_cyber_bare_heads','xmodelalias',{
    'model1':'tod_cyber_head','model2':'tod_cyber_bhead2','model3':'tod_cyber_bhead3'},parent='c_zom_der_zombie_headalias'))
blocks.append(block('tod_cyber_helmet_heads','xmodelalias',{
    'model'+str(i):'tod_cyber_hhead'+str(i) for i in (1,2,3)},parent='c_zom_der_zombie_headalias'))

characters={}
for short,donor in [('trooper','c_zom_der_zombie1'),('signal','c_zom_der_zombie2'),('relay','c_zom_der_zombie1_nohat')]:
    stock=asset('character',donor)
    gib='tod_cyber_'+short+'_gib'
    gib_overrides={'leftarm_gibmodel':'tod_cyber_arm_gib' if short=='signal' else 'tod_cyber_'+short+'_arm_gib'}
    gib_overrides['leftleg_gibmodel']='tod_cyber_leftleg_gib' if short=='signal' else 'tod_cyber_'+short+'_leftleg_gib'
    if short in ('trooper','relay'):
        gib_overrides.update(rightarm_gibmodel='tod_cyber_'+short+'_rightarm_gib',rightleg_gibmodel='tod_cyber_'+short+'_rightleg_gib')
    helmet=short!='relay'
    if helmet:gib_overrides['head_gibmodel']='tod_cyber_helmet_'+short
    blocks.append(block(gib,'gibcharacterdef',gib_overrides,parent=stock['gibDef']))
    prefix='tod_cyber_' if short=='signal' else 'tod_cyber_'+short+'_'
    overrides={'body':prefix+'body','head':'','headAlias':'tod_cyber_helmet_heads' if helmet else 'tod_cyber_bare_heads',
        'gibDef':gib,'torsoDmg1':prefix+'upper','torsoDmg2':prefix+'rarmoff',
        'torsoDmg3':prefix+'larmoff','torsoDmg4':prefix+'upper','legDmg1':prefix+'legs',
        'legDmg2':prefix+'rlegoff','legDmg3':prefix+'llegoff','legDmg4':prefix+'nolegs'}
    if helmet:overrides['hat']='tod_cyber_helmet_'+short
    name='c_tod_cyber_'+short
    blocks.append(block(name,'character',overrides,parent=donor));characters[name]=overrides

gdt=ROOT/'source_data/tod_cyber_roster.gdt';gdt.write_text('{\n'+''.join(blocks)+'}\n')
report={'native_verified':False,'models':records,'donor_assets':donors,'asset_copies':asset_copies,
    'gdt_sha256':digest(gdt),'characters':characters,
    'appearance_slots':{'1':'c_tod_cyber_trooper','2':'c_tod_cyber_signal','3':'c_tod_cyber_relay','4':'c_tod_cyber_zombie'},
    'textures':{p.name:digest(p) for p in (OUT/'_images').glob('i_tod_roster_*.png')}}
(STAGE_ROOT/'install_manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print('CYBER_ROSTER_ASSETS_OK',len(records),'model binaries;',len(blocks),'GDT entries')

