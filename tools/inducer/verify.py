"""Check the actual native inducer assembly and transparency before a build."""
import hashlib,json,re,sys,math
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path.home()/'AppData/Roaming/Blender Foundation/Blender/4.2/scripts/addons/BetterBetterBlenderCOD'))
from PyCoD import xmodel
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((ROOT/'art/rampage_inducer/install_manifest.json').read_text())
gdt=ROOT/'source_data/tod_bo6_inducer.gdt';folder=ROOT/'model_export/tod_bo6_inducer'
assert manifest['revision']=='amber_liquid_2'
assert sha(gdt)==manifest['gdt_sha256']
assert sha(folder/'tod_inducer.xmodel_bin')==manifest['xmodel_bin_sha256']
for name,digest in manifest['images'].items():assert sha(folder/'_images'/name)==digest,name
fields={name:dict(re.findall(r'"([^"\r\n]+)"\s*"([^"\r\n]*)"',body)) for name,body in re.findall(r'"([^"\n]+)"\s*\(\s*"material.gdf"\s*\)\s*\{([^}]+)\}',gdt.read_text())}
for key in ('36ade0417853ec32','503f0f822297b23b'):
    for suffix in ('','_on'):
        f=fields['mtl_tod_inducer_'+key+suffix]
        assert f['materialType']=='lit_emissive_scroll_transparent'
        assert float(f['waterRoughness'])==0
        assert f['colorTint1']=='1 1 1 1'  # source amber, no red-shifting tint
    im=Image.open(folder/'_images'/('i_tod_inducer_'+key+'_c.png'))
    lo,hi=im.getextrema()[3]
    assert im.mode=='RGBA'
    assert (80<=lo<=hi<=200) if key=='36ade0417853ec32' else (20<=lo<=hi<=90)
    # A nonzero alpha alone missed the nearly black fill in the first repair.
    # Check broad energy coverage and golden (R/G-rich, low-blue) output too.
    from PIL import ImageStat
    energy=Image.open(folder/'_images'/('i_tod_inducer_'+key+'_e.png')).convert('RGB')
    red,green,blue=ImageStat.Stat(energy).mean
    assert red>green>blue and green/red>.65 and blue/red<.65
    assert green>25, ('liquid emission too faint',key,red,green,blue)
for f in fields.values():assert float(f['waterRoughness'])==0
for info in manifest['materials'].values():
    if info['role']!='fluid':
        im=Image.open(folder/'_images'/(info['material'].replace('mtl_tod_','i_tod_')+'_n.png'))
        assert im.mode=='RGB'  # decoded XYZ, never unconverted RGBA NOG
model=xmodel.Model();model.LoadFile_Bin(str(folder/'tod_inducer.xmodel_bin'),split_meshes=True)
assert len(model.meshes)==9 and sum(len(m.faces) for m in model.meshes)==32847
assert len(model.bones)==1 and model.bones[0].name=='tag_origin'
shards=[];body=[]
for i,mesh in enumerate(model.meshes):
    assert all(f.mesh_id==i for f in mesh.faces)
    points=[v.offset for v in mesh.verts]
    if all('crystal' in model.materials[f.material_id].name for f in mesh.faces):
        shards.append(mesh)
        assert all(4.5<p[2]<17.0 and math.hypot(*p[:2])<2.95 for p in points)
    else:body+=points
assert len(shards)==4
assert abs(min(v[2] for v in body))<.001 and 28<max(v[2] for v in body)<28.1
print('INDUCER_SOURCE_OK: grounded original canister; all four crystals inside chamber; 32847 triangles; translucent moving energy; decoded surface maps; paired off/on models.')
