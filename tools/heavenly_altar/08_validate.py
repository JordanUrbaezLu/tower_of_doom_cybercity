"""Check the actual saved art, its source preservation and visible geometry."""
import bpy,math,json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'art/heavenly_altar';scene=bpy.context.scene
assert scene.get('mcp_port')==9878
original=json.loads((OUT/'original_import.json').read_text())
assert hashlib.sha256(Path(original['source']).read_bytes()).hexdigest()==original['sha256']
reference=[o for o in scene.objects if o.get('preserved_original_reference')]
assert len(reference)==1 and reference[0].hide_render
assert len(reference[0].data.vertices)==original['vertices']
assert len(reference[0].data.polygons)==original['triangles']
visible=[o for o in scene.objects if o.get('altar_design') and not o.hide_render]
assert visible and all(o.type=='MESH' for o in visible)
assert all(math.isfinite(v) for o in visible for vert in o.data.vertices for v in vert.co)
assert all(len(o.data.materials)>0 and all(m for m in o.data.materials) for o in visible)
missing=[]
for im in bpy.data.images:
    if im.source=='FILE' and im.filepath and not im.packed_file and not Path(bpy.path.abspath(im.filepath)).is_file():missing.append(im.filepath)
assert not missing,missing
dg=bpy.context.evaluated_depsgraph_get();tris=0
for ob in visible:
    ev=ob.evaluated_get(dg);mesh=ev.to_mesh();tris+=sum(len(p.vertices)-2 for p in mesh.polygons);ev.to_mesh_clear()
coords=[o.matrix_world@v.co for o in visible for v in o.data.vertices]
bounds=[[min(p[i] for p in coords) for i in range(3)],[max(p[i] for p in coords) for i in range(3)]]
report={'authoring':'Live Blender MCP localhost:9878','stage':scene['altar_stage'],'visible_mesh_objects':len(visible),'evaluated_triangles':tris,'bounds':bounds,'original_source_sha256':original['sha256'],'original_source_unchanged':True,'original_mesh_preserved':True,'missing_textures':missing,'live_preview':scene.get('live_preview'),'reference_image':'design_reference.png','game_assets_changed':False,'native_exported':False,'native_playtested':False,'limitations':['Single-image design reconstruction, not an exact image-to-mesh recovery.','Heavenly figures and stairs use a recessed reference-art surface; exterior equipment and effect ribbons are modeled geometry.','Rear and hidden surfaces extrapolate the supplied front view.','Procedural material baking, distance LODs and BO3 glow/transparency adaptation remain necessary before game deployment.']}
# Pack the source textures for a self-contained editable master.
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'heavenly_altar_cyber.blend'))
report['master_sha256']=hashlib.sha256((OUT/'heavenly_altar_cyber.blend').read_bytes()).hexdigest()
(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
print('ALTAR_VALIDATED',json.dumps(report),flush=True)
