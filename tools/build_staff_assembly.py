"""Reassemble original Origins heads and crystals into one animated model.

The separate first-person crystal attachment was still missing in the user's
pass-2 playtest. Bind its vertices to the head root so the known-working head
attachment owns placement and motion in both perspectives and packed forms.
No remodelling, hand motion edits, or ice asset changes. See docs/165.
"""
import copy
import csv
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from import_staff_animations import ROOT, blocks, emit
from build_staff_crystal import GREYHOUND, TOOLS, CRYSTAL
from bo6_extraction.install_ice_staff_bo3 import load_pycod

xm=load_pycod()
OUT=ROOT/'model_export/tod_staff_assembly'
GDT=ROOT/'source_data/tod_staff_assembly.gdt'
MANIFEST=ROOT/'docs/staff_assembly_manifest.json'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def model(path):
    m=xm.Model();m.LoadFile_Bin(str(path),split_meshes=True);return m

def name(element,form):return 'tod_staff_'+element+'_complete_'+form

WORLD_GLOW_TINT = {
    'fire': {'colorTint': '0.90 0.45 0.18 0.000000', 'colorTint1': '1.00 0.50 0.14 1.000000'},
    'lightning': {'colorTint': '0.45 0.20 0.85 0.000000', 'colorTint1': '0.68 0.30 1.00 1.000000'},
}

def world_glow_assets(assets):
    """Restore pass-2 brightness only on world stones; reuse every mesh byte.

    PaP previously shared one xmodel between views, so its world instance needs
    a separate asset name. Only the crystal surface receives a skin override.
    """
    generated={name(el,'pap_world') for el in WORLD_GLOW_TINT}
    generated.update('mtl_tod_staff_crystal_'+el+'_world' for el in WORLD_GLOW_TINT)
    result=[(n,k,dict(f)) for n,k,f in assets if n not in generated]
    models={n:f for n,k,f in result}
    retail={n:f for n,k,f in blocks(ROOT/'source_data/tod_staff_crystal.gdt')}
    for el,tints in WORLD_GLOW_TINT.items():
        material='mtl_tod_staff_crystal_'+el+'_world'
        override=CRYSTAL[el]['material']+' '+material+r'\r\n'
        models[name(el,'world')]['skinOverride']=override
        packed=dict(models[name(el,'pap')]);packed['skinOverride']=override
        result.append((name(el,'pap_world'),'xmodel.gdf',packed))
        glow=dict(retail[CRYSTAL[el]['material']]);glow.update(tints,scaleRGB='16')
        result.append((material,'material.gdf',glow))
    return result

def refresh_world_glow():
    assets=world_glow_assets(blocks(GDT))
    GDT.write_text('{\n'+''.join(emit(*a) for a in assets)+'}\n',encoding='latin1')
    report=json.loads(MANIFEST.read_text())
    report['files'][GDT.relative_to(ROOT).as_posix()]=sha(GDT)
    MANIFEST.write_text(json.dumps(report,indent=2)+'\n')
    check()

def same_mesh(a,b):
    assert len(a.verts)==len(b.verts) and len(a.faces)==len(b.faces)
    for v,w in zip(a.verts,b.verts):assert max(abs(x-y) for x,y in zip(v.offset,w.offset))<1e-5
    for f,g in zip(a.faces,b.faces):
        for v,w in zip(f.indices,g.indices):
            assert v.vertex==w.vertex and v.color==w.color
            assert max(abs(x-y) for x,y in zip(v.uv,w.uv))<1e-5
            assert max(abs(x-y) for x,y in zip(v.normal,w.normal))<1e-4

def generate():
    OUT.mkdir(parents=True,exist_ok=True)
    origins={n:f for n,k,f in blocks(ROOT/'source_data/tod_staff_origins.gdt')}
    pap={n:f for n,k,f in blocks(ROOT/'source_data/tod_staff_pap.gdt')}
    report={'revision':'integrated_crystals_1','models':{},'files':{},'sources':{}}
    assets=[]
    for el in ('fire','lightning'):
        for form in ('view','world','pap'):
            perspective='world' if form=='pap' else form
            source_name='wpn_t7_zmb_hd_staff_tip_'+el+'_'+perspective
            head_path=(ROOT/'model_export/tod_staff_pap'/('tod_staff_'+el+'_pap_tip.XMODEL_BIN') if form=='pap'
                       else GREYHOUND/source_name/(source_name+'_LOD0.XMODEL_BIN'))
            crystal_name='wpn_t7_zmb_hd_staff_crystal_'+el+'_'+perspective
            crystal_path=GREYHOUND/crystal_name/(crystal_name+'_LOD0.XMODEL_BIN')
            head,crystal=model(head_path),model(crystal_path)
            # Both original pieces share a zero, identity root in head-local space.
            for piece in (head,crystal):
                assert max(abs(x) for x in piece.bones[0].offset)<1e-5
                assert all(abs(piece.bones[0].matrix[i][j]-(i==j))<1e-5 for i in range(3) for j in range(3))
            assert head.bones[0].name=='tag_tip_'+el
            assert len(crystal.bones)==1
            merged=copy.deepcopy(head)
            materials={m.name:i for i,m in enumerate(merged.materials)}
            for material in crystal.materials:
                if material.name not in materials:
                    materials[material.name]=len(merged.materials);merged.materials.append(copy.deepcopy(material))
            first=len(merged.meshes)
            for mesh in copy.deepcopy(crystal.meshes):
                for vertex in mesh.verts:vertex.weights=[(0,1.0)]
                for face in mesh.faces:
                    face.material_id=materials[crystal.materials[face.material_id].name]
                    face.mesh_id=len(merged.meshes)
                merged.meshes.append(mesh)
            # attachmentunique treats this single-bone PaP head as a rigid
            # attachment. A blank socket falls back to the weapon root in
            # native play (docs/166). Use an unkeyed root + explicit tag_tip,
            # avoiding both root fallback and a second animation transform.
            if form=='pap':
                assert len(merged.bones)==1
                merged.bones[0].name='tag_tod_'+el+'_packed_head'
            asset=name(el,form);raw=OUT/(asset+'.XMODEL_EXPORT');binary=raw.with_suffix('.XMODEL_BIN')
            merged.WriteFile_Raw(str(raw))
            subprocess.run([str(TOOLS/'bin/export2bin.exe'),'/nt=8','/o=.',raw.name],cwd=OUT,check=True,capture_output=True)
            actual=model(binary)
            assert [b.name for b in actual.bones]==[b.name for b in merged.bones]
            assert len(actual.meshes)==len(head.meshes)+len(crystal.meshes)
            for old,new in zip(head.meshes+crystal.meshes,actual.meshes):same_mesh(old,new)
            for old,new in zip(head.meshes,actual.meshes):
                assert [v.weights for v in old.verts]==[v.weights for v in new.verts],(asset,'head weights changed')
            fields=dict(pap['tod_staff_'+el+'_pap_tip'] if form=='pap' else origins['tod_staff_tip_'+el+'_'+form])
            for key in list(fields):
                if key!='filename' and 'filename' in key.lower():fields[key]=''
                # The donor enabled generated 50/25/12/7/4-percent LODs.
                # Keep every small head/crystal part in one full-detail LOD.
                if key.startswith('autogen') and not key.endswith('Percent'):fields[key]='0'
            for key in ('mediumLod','lowLod','lowestLod','lod4File','lod5File','lod6File','lod7File'):
                fields[key]=''
            fields['filename']='tod_staff_assembly\\\\'+binary.name
            fields['skinOverride']=''  # old donor carries unrelated Russian icicle overrides
            assets.append((asset,'xmodel.gdf',fields))
            report['models'][asset]={'element':el,'form':form,'root':merged.bones[0].name,'crystal_mesh_start':first,
                'head_triangles':sum(len(m.faces) for m in head.meshes),'crystal_triangles':sum(len(m.faces) for m in crystal.meshes),
                'triangles':sum(len(m.faces) for m in actual.meshes)}
            report['files'][binary.relative_to(ROOT).as_posix()]=sha(binary)
            for p in (head_path,crystal_path):report['sources'][str(p)]=sha(p)
    assets=world_glow_assets(assets)
    GDT.write_text('{\n'+''.join(emit(*a) for a in assets)+'}\n',encoding='latin1')
    report['files'][GDT.relative_to(ROOT).as_posix()]=sha(GDT)
    MANIFEST.write_text(json.dumps(report,indent=2)+'\n')
    check()

def check():
    report=json.loads(MANIFEST.read_text())
    assert report['revision']=='integrated_crystals_1' and len(report['models'])==6
    for rel,digest in report['files'].items():assert sha(ROOT/rel)==digest,rel
    fields_by_asset={n:f for n,k,f in blocks(GDT)}
    assert blocks(GDT)==world_glow_assets(blocks(GDT)), 'World glow materials/bindings drifted'
    for el in WORLD_GLOW_TINT:
        for form in ('view','pap'):
            assert fields_by_asset[name(el,form)]['skinOverride']=='', (el,form,'first-person material changed')
    for asset,info in report['models'].items():
        fields=fields_by_asset[asset]
        assert all(v=='0' for k,v in fields.items() if k.startswith('autogen') and not k.endswith('Percent'))
        m=model(OUT/(asset+'.XMODEL_BIN'))
        assert m.bones[0].name==info['root']
        if info['form']=='pap':
            assert len(m.bones)==1 and m.bones[0].name=='tag_tod_'+info['element']+'_packed_head'
        assert not any('tag_clip_' in b.name or 'tag_tod_staff_crystal' in b.name for b in m.bones)
        assert sum(len(mesh.faces) for mesh in m.meshes)==info['triangles']
        for i,mesh in enumerate(m.meshes):
            assert all(f.mesh_id==i for f in mesh.faces),(asset,'object table')
            if i>=info['crystal_mesh_start']:
                assert all(v.weights==[(0,1.0)] for v in mesh.verts),(asset,'crystal must follow head root')
                assert all(m.materials[f.material_id].name==CRYSTAL[info['element']]['material'] for f in mesh.faces)
        assert info['crystal_triangles']==CRYSTAL[info['element']]['triangles']
    print('STAFF_ASSEMBLY_OK: six original heads + complete crystals, preserved head geometry/weights; crystals follow the head root in base/packed and both views.')

def check_compiled(path):
    report=json.loads(MANIFEST.read_text())
    with Path(path).open(newline='') as stream:rows={r['name']:r for r in csv.DictReader(stream)}
    for asset,info in report['models'].items():
        assert asset in rows,(asset,'missing compiled complete head')
        assert int(rows[asset]['lodCount'])==1,(asset,'unexpected reduced LODs')
        count=int(rows[asset]['tris0'])
        # Native welding may remove tiny/degenerate triangles. This tolerance
        # is smaller than the entire crystal, even for the 36-triangle stone.
        assert info['triangles']*.995<=count<=info['triangles'],(asset,count,info['triangles'])
    for el in WORLD_GLOW_TINT:
        a,b=rows[name(el,'pap')],rows[name(el,'pap_world')]
        assert a['tris0']==b['tris0'] and b['lodCount']=='1',(el,'world PaP geometry changed')
    print('STAFF_ASSEMBLY_COMPILED_OK: all six complete heads retain their geometry.')

if __name__=='__main__':
    if '--compiled-ledger' in sys.argv:
        check();check_compiled(sys.argv[sys.argv.index('--compiled-ledger')+1])
    elif '--world-glow' in sys.argv:refresh_world_glow()
    elif '--check' in sys.argv:check()
    else:generate()
