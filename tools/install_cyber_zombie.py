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
from cyber_equipment_layout import body_groups, CROWN_HAND

ROOT=Path(__file__).resolve().parents[1]
MT=Path(r'C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130')
OUT=ROOT/'model_export/tod_cyber_zombie'
STAGE=ROOT/'art/cyber_zombie_mvp/engine_kit'
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
        asset_copies[name]={'kind':kind,'donor':parent,'overrides':dict(fields)}
        fields={**asset(kind,parent),**fields}
    head=f'"{name}" ( "{kind}.gdf" )'
    def val(v):
        if isinstance(v,float) and v.is_integer():return str(int(v))
        return str(v).replace('"','\\"').replace('\r','\\r').replace('\n','\\n')
    return '\t'+head+'\n\t{\n'+''.join(f'\t\t"{k}" "{val(v)}"\n' for k,v in fields.items() if v is not None)+'\t}\n'

blocks=[];records=[]
lod_fields=('filename','mediumLod','lowLod','lowestLod','lod4File','lod5File','lod6File')
cloth='mtl_c_zom_der_zombie_body2'
skin=f'{cloth} mtl_tod_cyber_cloth\\r\\n'

def append_group(m,group,lod,force_bone=None):
    kit=json.loads((STAGE/f'{group}_lod{lod}.json').read_text())
    bi={b.name.lower():i for i,b in enumerate(m.bones)}
    bone=force_bone or kit['bone'];assert bone in bi,(group,lod,bone)
    mid=next((i for i,mat in enumerate(m.materials) if mat.name=='mtl_tod_cyber_kit'),None)
    if mid is None:
        mid=len(m.materials);m.materials.append(xmodel.Material('mtl_tod_cyber_kit','Phong',{}))
    mesh=xmodel.Mesh('cyber_'+group)
    mesh.verts=[xmodel.Vertex(tuple(p),[(bi[bone],1.0)]) for p in kit['verts']]
    for corners in kit['faces']:
        assert all(sum(v*v for v in c['n'])>.9 for c in corners), (group,lod,'invalid normal')
        f=xmodel.Face(len(m.meshes),mid)
        f.indices=[xmodel.FaceVertex(c['v'],tuple(c['n']),(1,1,1,1),tuple(c['uv'])) for c in corners]
        mesh.faces.append(f)
    m.meshes.append(mesh)

def model(name,donor,groups=(),force_bone=None):
    fields=asset('xmodel',donor)
    overrides={'skinOverride':skin} if 'body2' in donor else {}
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
        for group in groups:append_group(m,group,lod,force_bone)
        for index,mesh in enumerate(m.meshes):
            assert all(f.mesh_id==index for f in mesh.faces)
        dst=OUT/f'{name}_lod{lod}.xmodel_bin'
        m.WriteFile_Bin(str(dst))
        check=xmodel.Model();check.LoadFile_Bin(str(dst),split_meshes=True)
        assert len(check.meshes)==len(m.meshes)
        assert sum(len(x.faces) for x in check.meshes)==sum(len(x.faces) for x in m.meshes)
        assert [(b.name,b.parent) for b in check.bones]==[(b.name,b.parent) for b in m.bones]
        # All original vertices and weights survive the binary round-trip.
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
                        'groups':list(groups),'force_bone':force_bone})
    blocks.append(block(name,'xmodel',overrides,parent=donor))

model('tod_cyber_body','c_zom_der_zombie_body2',body_groups('crown','body'))
model('tod_cyber_upper','c_zom_der_zombie_body2_g_upclean',body_groups('crown','upper'))
model('tod_cyber_rarmoff','c_zom_der_zombie_body2_g_rarmoff',body_groups('crown','rarmoff'))
model('tod_cyber_larmoff','c_zom_der_zombie_body2_g_larmoff',body_groups('crown','larmoff'))
model('tod_cyber_head','c_zom_der_zombie_head1',('head',))
for short,suffix in [('legs','lowclean'),('rlegoff','rlegoff'),('llegoff','llegoff'),('nolegs','blegsoff')]:
    model('tod_cyber_'+short,'c_zom_der_zombie_body2_g_'+suffix,body_groups('crown',short))
# Stock's detached left limb has one wrist bone in the same world bind pose.
# Bake the brace into that flying piece; do not create a separate runtime entity.
model('tod_cyber_arm_gib','c_zom_zod_zombie_fem_body1_g_larmspawn',('arm',)+CROWN_HAND,'j_wrist_le')
model('tod_cyber_leftleg_gib','c_zom_zod_zombie_fem_body1_g_llegspawn',('shin_le',),'j_ankle_le')

blocks.append(block('mtl_tod_cyber_cloth','material',{'colorTint':'.19 .25 .30 1'},parent=cloth))
asset('material',cloth)
for suffix,semantic in [('c','diffuseMap'),('n','normalMap'),('s','specularMap'),('g','glossMap'),('e','diffuseMap')]:
    f={'baseImage':'model_export\\\\tod_cyber_zombie\\\\_images\\\\i_tod_cyber_kit_'+suffix+'.png',
       'imageType':'Texture','type':'image','semantic':semantic,'streamable':'1',
       'compressionMethod':'compressed' if suffix in ('n','g') else 'compressed high color'}
    if suffix in ('c','s','e'):f['coreSemantic']='sRGB3chAlpha'
    blocks.append(block('i_tod_cyber_kit_'+suffix,'image',f))
blocks.append(block('mtl_tod_cyber_kit','material',{
    'surfaceType':'flesh','template':'material.template','materialCategory':'Geometry Advanced',
    'materialType':'lit_emissive_advanced_fullspec','colorMap':'i_tod_cyber_kit_c',
    'normalMap':'i_tod_cyber_kit_n','cosinePowerMap':'i_tod_cyber_kit_g',
    'specColorMap':'i_tod_cyber_kit_s','specMapEnable':'1','specColorTint':'1 1 1 1',
    'colorMap00':'i_tod_cyber_kit_e',
    # Fullspec maps waterRoughness to emissive layerDepth; atlas lights sit on the surface.
    'waterRoughness':'0',
    'colorTint':'1 1 1 1','colorTint1':'1 1 1 1','scaleRGB':'6',
    'emissiveIncompetence':'1','emissiveFalloff':'0','normalHeightScale':'1',
    'glossRangeMin':'1','glossRangeMax':'17','specAmount':'1','reflectionProbeAmount':'1',
    'textureAtlasRowCount':'1','textureAtlasColumnCount':'1','usage':'<not in editor>'}))

character=asset('character','c_zom_der_zombie2_nohat')
overrides={'body':'tod_cyber_body','head':'','headAlias':'tod_cyber_bare_heads',
           'gibDef':'tod_cyber_gib_def','torsoDmg1':'tod_cyber_upper',
           'torsoDmg2':'tod_cyber_rarmoff','torsoDmg3':'tod_cyber_larmoff',
           'torsoDmg4':'tod_cyber_upper','legDmg1':'tod_cyber_legs',
           'legDmg2':'tod_cyber_rlegoff','legDmg3':'tod_cyber_llegoff','legDmg4':'tod_cyber_nolegs'}
blocks.append(block('c_tod_cyber_zombie','character',overrides,parent='c_zom_der_zombie2_nohat'))
asset('gibcharacterdef','c_zom_der_zombie_gib_def')
blocks.append(block('tod_cyber_gib_def','gibcharacterdef',{'leftarm_gibmodel':'tod_cyber_arm_gib','leftleg_gibmodel':'tod_cyber_leftleg_gib'},parent='c_zom_der_zombie_gib_def'))
asset('aitype','spawner_zm_factory_zombie')
blocks.append(block('spawner_zm_tod_cyber_horde','aitype',{
    'character1':'c_tod_cyber_trooper','character2':'c_tod_cyber_signal',
    'character3':'c_tod_cyber_relay','character4':'c_tod_cyber_zombie'},parent='spawner_zm_factory_zombie'))
gdt=ROOT/'source_data/tod_cyber_zombie.gdt';gdt.write_text('{\n'+''.join(blocks)+'}\n')
report={'native_verified':False,'models':records,'donor_assets':donors,'asset_copies':asset_copies,
        'kit_lods':json.loads((STAGE/'lod_counts.json').read_text()),
        'gdt_sha256':digest(gdt),'character_overrides':overrides,
        'appearance_slots':{'unchanged':[],'cyber':[1,2,3,4]},
        'textures':{p.name:digest(p) for p in (OUT/'_images').glob('i_tod_cyber_kit_*.png')}}
(STAGE/'install_manifest.json').write_text(json.dumps(report,indent=2)+'\n')
print('CYBER_ASSETS_OK',len(records),'model binaries;',len(blocks),'GDT entries;',
      sum(p.stat().st_size for p in OUT.rglob('*') if p.is_file()),'source bytes')
