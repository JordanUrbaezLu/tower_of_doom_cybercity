"""Check source integrity, all-six shared placement and native conversion coverage."""
import sys,json,hashlib,re,csv,math,argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];ART=ROOT/'art/heavenly_altar';STAGE=ART/'engine_kit'
sys.path.insert(0,str(Path.home()/'AppData/Roaming/Blender Foundation/Blender/4.2/scripts/addons/BetterBetterBlenderCOD'))
from PyCoD import xmodel
from original_portal import geometry as original_portal_geometry, face_signatures, MATERIAL as ORIGINAL_PORTAL_MATERIAL
parser=argparse.ArgumentParser();parser.add_argument('--compiled-ledger',type=Path);args=parser.parse_args()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
m=json.loads((STAGE/'install_manifest.json').read_text());assert sha(ART/'heavenly_altar_cyber.blend')==m['master_sha256']
assert sha(ROOT/'source_data/tod_heavenly_altar.gdt')==m['gdt_sha256']
gdt=(ROOT/'source_data/tod_heavenly_altar.gdt').read_text()
original_faces=face_signatures(original_portal_geometry())
assert m['materials'][1]==ORIGINAL_PORTAL_MATERIAL
assert '"mtl_tod_altar_portal"' not in gdt
solid_body=re.search(r'"mtl_tod_altar"\s*\(\s*"material.gdf"\s*\)\s*\{([^}]+)\}',gdt).group(1)
solid_fields=dict(re.findall(r'"([^"\r\n]+)"\s*"([^"\r\n]*)"',solid_body))
assert {k:float(solid_fields[k]) for k in ('glossRangeMin','glossRangeMax','specAmount','reflectionProbeAmount','specMapEnable')}=={'glossRangeMin':0,'glossRangeMax':6,'specAmount':.2,'reflectionProbeAmount':.15,'specMapEnable':1}
assert solid_fields['specColorMap']=='i_tod_altar_s' and solid_fields['specColorTint']=='.25 .25 .25 1'
assert 'i_tod_altar_s.png' in m['textures']
assert solid_fields['colorMap00']=='i_tod_altar_e' and float(solid_fields['scaleRGB'])==8
assert float(solid_fields['waterRoughness'])==0, 'Altar emissive layer must stay on the surface'
# 2026-10-01 (docs/167 item 16): the crest's emblem breaks from LOD2 on, so the
# first switch must stay past the arena + teleport bay (the base altar at
# (0,-276) is at most ~960 units from anywhere a player stands there), and the
# switches must stay in order.
xm_body=re.search(r'"tod_heavenly_altar"\s*\(\s*"xmodel.gdf"\s*\)\s*\{([^}]+)\}',gdt).group(1)
xm=dict(re.findall(r'"([^"\r\n]+)"\s*"([^"\r\n]*)"',xm_body))
lod_dists=[float(xm[k]) for k in ('mediumLodDist','lowLodDist','lowestLodDist','lod4Dist','lod5Dist','lod6Dist')]
assert lod_dists[0]>=1000, ('Altar LOD1 switches inside the base arena/bay - the crest emblem breaks there', lod_dists[0])
assert all(a<b for a,b in zip(lod_dists,lod_dists[1:])), ('Altar LOD distances out of order', lod_dists)
for f,d in m['textures'].items():assert sha(ROOT/'model_export/tod_heavenly_altar/_images'/f)==d,f
for record in m['models']:
    file=ROOT/record['file'];assert sha(file)==record['sha256'];model=xmodel.Model();model.LoadFile_Bin(str(file),split_meshes=True)
    assert len(model.bones)==1 and model.bones[0].name=='tag_origin'
    assert [mat.name for mat in model.materials]==m['materials']
    assert sum(len(mesh.faces) for mesh in model.meshes)==record['triangles']
    groups={g:0 for g in record['groups']}
    for idx,mesh in enumerate(model.meshes):
        groups[mesh.name.rsplit('_',1)[0]]+=len(mesh.faces)
        assert all(f.mesh_id==idx for f in mesh.faces)
        assert all(len(v.weights)==1 and v.weights[0]==(0,1.) and all(math.isfinite(p) for p in v.offset) for v in mesh.verts)
        assert all(.99<sum(v*v for v in c.normal)<1.01 for f in mesh.faces for c in f.indices)
    assert groups==record['groups']
    portals=[mesh for mesh in model.meshes if mesh.name.startswith('portal_')]
    assert len(portals)==1
    mesh=portals[0]
    actual={'verts':[v.offset for v in mesh.verts],'faces':[[{'v':c.vertex,'n':c.normal,'uv':c.uv,'color':c.color} for c in f.indices] for f in mesh.faces]}
    assert face_signatures(actual)==original_faces, 'Original portal positions, UVs, colors, normals and winding must remain exact'
    assert all(model.materials[f.material_id].name==ORIGINAL_PORTAL_MATERIAL for f in mesh.faces)
    coords=[v.offset for mesh in model.meshes for v in mesh.verts]
    assert max(p[2] for p in coords)>122 and min(p[2] for p in coords)<2
    assert max(p[0] for p in coords)>46 and min(p[0] for p in coords)<-46
script=(ROOT/'scripts/zm/zm_tower_of_doom/_tod_upgrades.gsc').read_text(encoding='utf-8-sig')
station=script.split('function station_place(',1)[1].split('function ',1)[0]
assert 'm SetModel( "tod_heavenly_altar" );' in station
assert '#precache( "model", "tod_heavenly_altar" );' in script
assert 'xmodel,tod_heavenly_altar' in (ROOT/'zone_source/zm_tower_of_doom.zone').read_text(encoding='utf-8-sig')
# v19.71: the base altar is GENERATED (gen_tower_map.js BASE_STATION), flush against the core
assert 'station_place( tod_breather_data::base_station_org(), tod_breather_data::base_station_trig(), tod_breather_data::base_station_yaw() );' in script
assert 'station_place( tod_breather_data::station_org( z ), tod_breather_data::station_trig( z ), tod_breather_data::station_yaw() );' in script
assert 'station_place( tod_crown_data::station_org(), tod_crown_data::station_trig_org(), tod_crown_data::station_yaw() );' in script
breathers=(ROOT/'scripts/zm/zm_tower_of_doom/_tod_breather_data.gsc').read_text(encoding='utf-8-sig')
assert re.search(r'function base_station_org\(\) \{ return \( 0, -276, 0 \); \}', breathers), 'the base altar must stand flush against the core south face (origin 20 off it)'
zs=re.search(r'function breather_zs\(\)\s*\{ return array\(([^)]+)\)',breathers).group(1).split(',');assert len(zs)==4
assert 'm PlayLoopSound( "tod_altar_aura" );' in station
assert 'clip_offs = array( -32, 0, 32 );' in station
assert 'c SetModel( "zm_collision_perks1" );' in station
print('ALTAR_SOURCE_OK: six shared placements; valid native mesh tables; seven LODs; matching materials/textures; original trigger, sound and clips retained.')
if args.compiled_ledger:
    with args.compiled_ledger.open(encoding='utf-8-sig',newline='') as f:rows={r['name']:r for r in csv.DictReader(f)}
    row=rows[m['asset']];assert int(row['lodCount'])==7
    for record in m['models']:
        count=int(row['tris'+str(6-record['lod'])]);assert count==record['triangles'],(record['lod'],record['triangles'],count)
    print('ALTAR_COMPILED_OK: every triangle survives native conversion at every authored LOD.')
