"""Create portable map-owned xmodel/material/image assets from baked geometry."""
import sys,json,hashlib,sqlite3,copy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];ART=ROOT/'art/heavenly_altar';STAGE=ART/'engine_kit';OUT=ROOT/'model_export/tod_heavenly_altar'
MT=Path('C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130')
sys.path.insert(0,str(Path.home()/'AppData/Roaming/Blender Foundation/Blender/4.2/scripts/addons/BetterBetterBlenderCOD'))
from PyCoD import xmodel
from original_portal import geometry as original_portal_geometry, MATERIAL as ORIGINAL_PORTAL_MATERIAL, SOURCE_SHA as ORIGINAL_PORTAL_SHA
manifest=json.loads((STAGE/'source_manifest.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(ART/'heavenly_altar_cyber.blend')==manifest['master_sha256']
db=sqlite3.connect((MT/'gdtdb/gdt.db').as_uri()+'?mode=ro',uri=True);db.execute('pragma writable_schema=ON');db.row_factory=sqlite3.Row
def donor(kind,name):return {k:v for k,v in dict(db.execute('select * from '+kind+' where _name=?',(name,)).fetchone()).items() if not k.startswith('_') and k!='PK_id' and v is not None}
def block(name,kind,fields):
    def val(v):
        if isinstance(v,float) and v.is_integer():return str(int(v))
        return str(v).replace('"','\\"').replace('\r','\\r').replace('\n','\\n')
    return '\t"'+name+'" ( "'+kind+'.gdf" )\n\t{\n'+''.join('\t\t"'+k+'" "'+val(v)+'"\n' for k,v in fields.items())+'\t}\n'
blocks=[];records=[];groups=list(manifest['groups'])
materials={**manifest['groups'],'portal':ORIGINAL_PORTAL_MATERIAL}
original_portal=original_portal_geometry()
for lod in range(7):
    model=xmodel.Model('tod_heavenly_altar');root=xmodel.Bone('tag_origin');root.offset=(0,0,0);root.matrix=[(1,0,0),(0,1,0),(0,0,1)];model.bones=[root]
    model.materials=[xmodel.Material(materials[g],'Phong',{}) for g in groups]
    group_counts={}
    for mid,group in enumerate(groups):
        data=original_portal if group=='portal' else json.loads((STAGE/(group+'_lod'+str(lod)+'.json')).read_text());faces=list(data['faces'])
        # Wing membranes are genuinely two-sided. Opposite normals/winding,
        # same positions, so native backface culling exposes just one side.
        if group=='wings':faces+=[[{**c,'n':[-v for v in c['n']]} for c in reversed(f)] for f in list(faces)]
        group_counts[group]=len(faces)
        for start in range(0,len(faces),18000):
            chunk=faces[start:start+18000];used=sorted({c['v'] for f in chunk for c in f});index={v:i for i,v in enumerate(used)}
            mesh=xmodel.Mesh(group+'_'+str(start//18000));mesh.verts=[xmodel.Vertex(data['verts'][i],[(0,1.)]) for i in used]
            assert len(mesh.verts)<65535
            for corners in chunk:
                f=xmodel.Face(len(model.meshes),mid);f.indices=[xmodel.FaceVertex(index[c['v']],tuple(c['n']),tuple(c.get('color',(1,1,1,1))),tuple(c['uv'])) for c in corners];mesh.faces.append(f)
            model.meshes.append(mesh)
    path=OUT/('tod_heavenly_altar_lod'+str(lod)+'.xmodel_bin');model.WriteFile_Bin(str(path),version=7)
    check=xmodel.Model();check.LoadFile_Bin(str(path),split_meshes=True)
    assert [m.name for m in check.materials]==list(materials.values())
    assert len(check.meshes)==len(model.meshes)
    assert sum(len(m.faces) for m in check.meshes)==sum(group_counts.values())
    for idx,m in enumerate(check.meshes):assert all(f.mesh_id==idx for f in m.faces)
    records.append({'lod':lod,'file':str(path.relative_to(ROOT)),'sha256':sha(path),'triangles':sum(group_counts.values()),'groups':group_counts,'meshes':len(check.meshes),'vertices':sum(len(m.verts) for m in check.meshes)})
fields=donor('xmodel','chaos_pack_a_punch')
# LOD DISTANCES (2026-10-01, docs/167 item 16; lead tester: "Walking backwards into
# the teleporter room while looking at the top circle causes the model to break /
# disappear in the logo at top"). The crest's raised emblem and fine rings are
# what the solid group's decimation removes first: measured on the shipped
# binaries, the crest changes visibly from LOD2 and its triangle emblem is mostly
# gone by LOD3 - and the old 500 / 850 switches sat exactly where a player backs
# from the base altar (0,-320) into the teleport bay (380..960 units). LOD1 now
# starts at 1000, past every spot in the arena and the bay, and the rest keep
# their spacing behind it.
for i,key in enumerate(('filename','mediumLod','lowLod','lowestLod','lod4File','lod5File','lod6File')):fields[key]='tod_heavenly_altar\\\\tod_heavenly_altar_lod'+str(i)+'.xmodel_bin'
fields.update({'skinOverride':'','scale':1,'arabicUnsafe':0,'germanUnsafe':0,'japaneseUnsafe':0,'CollisionMap':'','BulletCollisionFile':'','physicsPreset':'','highLodDist':0,'mediumLodDist':1000,'lowLodDist':1500,'lowestLodDist':2100,'lod4Dist':2800,'lod5Dist':3600,'lod6Dist':4500,'lod7File':'','lod7Dist':0})
for key in list(fields):
    if key.startswith('autogen') and not key.endswith('Percent'):fields[key]=0
blocks.append(block('tod_heavenly_altar','xmodel',fields))
active_textures={file:digest for file,digest in manifest['textures'].items() if file!='i_tod_altar_portal_e.png'}
for file,digest in active_textures.items():
    assert sha(OUT/'_images'/file)==digest
    name=Path(file).stem;suffix=name.rsplit('_',1)[-1];alpha=name=='i_tod_altar_wings_c'
    fields={'baseImage':'model_export\\\\tod_heavenly_altar\\\\_images\\\\'+file,'imageType':'Texture','type':'image','semantic':{'c':'diffuseMap','e':'diffuseMap','n':'normalMap','s':'specularMap','g':'glossMap'}[suffix],'streamable':1,'compressionMethod':'compressed' if suffix in ('n','g') else 'compressed high color'}
    if suffix in ('c','s','e'):fields['coreSemantic']='sRGB3chAlpha'
    blocks.append(block(name,'image',fields))
solid={'surfaceType':'metal','template':'material.template','materialCategory':'Geometry Advanced','materialType':'lit_emissive_advanced_fullspec','colorMap':'i_tod_altar_c','normalMap':'i_tod_altar_n','cosinePowerMap':'i_tod_altar_g','specColorMap':'i_tod_altar_s','specMapEnable':1,'specColorTint':'1 1 1 1','colorMap00':'i_tod_altar_e','colorTint':'1 1 1 1','colorTint1':'1 1 1 1','scaleRGB':8,'emissiveIncompetence':1,'emissiveFalloff':0,'normalHeightScale':1,'glossRangeMin':1,'glossRangeMax':17,'specAmount':1,'reflectionProbeAmount':1,'textureAtlasRowCount':1,'textureAtlasColumnCount':1,'usage':'<not in editor>'}
# Restore the 19:54 material which the user accepted except for excess shine.
# Change ONLY glossRangeMax from that setup (8 -> 6). Keep the fullspec map,
# enabled shader path, nonzero specular tint/amount and probe contribution.
solid.update({'glossRangeMin':0,'glossRangeMax':6,'specAmount':.2,'specColorTint':'.25 .25 .25 1','reflectionProbeAmount':.15})
# Fullspec maps this field to layerDepth: keep atlas lights on their actual surface.
solid['waterRoughness']=0
blocks.append(block('mtl_tod_altar','material',solid))
# Reuse the complete original three-layer animated material, without cloning
# or altering its shared definition in chaos_pack_a_punch.gdt.
wing=donor('material','mtl_attach_t9_optic_acog_reticle')
wing.update({'colorMap':'i_tod_altar_wings_c','colorMap00':'i_tod_altar_wings_e','colorTint':'1 1 1 1','colorTint1':'1 1 1 1','scaleRGB':3,'specMapEnable':0,'noCastShadow':1,'noReceiveDynamicShadow':1,'emissiveFalloff':0,'emissiveIncompetence':1})
blocks.append(block('mtl_tod_altar_wings','material',wing))
gdt=ROOT/'source_data/tod_heavenly_altar.gdt';gdt.write_text('{\n'+''.join(blocks)+'}\n')
install={'asset':'tod_heavenly_altar','master_sha256':manifest['master_sha256'],'gdt_sha256':sha(gdt),'models':records,'textures':active_textures,'materials':list(materials.values()),'source_geometry_unchanged':True,'placements':6,'native_playtested':False,'original_portal_source_sha256':ORIGINAL_PORTAL_SHA,'external_images':['i_chaos_pap_background_c','i_chaos_pap_background_2_c','i_chaos_pap_background_3_c']}
(STAGE/'install_manifest.json').write_text(json.dumps(install,indent=2)+'\n')
print('ALTAR_NATIVE_INSTALLED',json.dumps({r['lod']:r['triangles'] for r in records}))
