"""Record reference-two back-machine delivery only after the full build passes."""
import hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'tmp/reference_two_back_machine_20260916'
raw=(OUT/'build.log').read_bytes()
log=raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8',errors='replace')
assert all(s in log for s in ('BUILD OK','CYBER_NATIVE_GEOMETRY_OK','CYBER_ROSTER_NATIVE_OK'))
build=json.loads((OUT/'deployment_verification.json').read_text())
assert not build['differences'] and not build['deployed_inputs_newer_than_ff'] and not build['missing_assets']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
before=json.loads((OUT/'before_hashes.json').read_text())
allowed=('tod_cyber_trooper_','tod_cyber_relay_','tod_cyber_bhead2_','tod_cyber_bhead3_','tod_cyber_hhead1_','i_tod_roster_trooper_','i_tod_roster_relay_')
changed=[name for name,digest in before.items() if sha(ROOT/name)!=digest]
assert all(Path(name).name.startswith(allowed) for name in changed),changed
preserved=[name for name in before if name not in changed]
(OUT/'asset_preservation.json').write_text(json.dumps({'changed':changed,'preserved':preserved,'references_one_and_three_unchanged':True},indent=2)+'\n')
folder=ROOT/'art/cyber_reference_two_mcp';report_path=folder/'validation.json'
report=json.loads(report_path.read_text());master=folder/'reference_two.blend'
assert sha(master)==report['master_sha256']
counts=json.loads((folder/'engine_kit/lod_counts.json').read_text())
totals=[sum(counts[str(i)].values()) for i in range(7)]
report.update(native_exported=True,native_playtested=False,equipment_lod_triangles=totals,game_integration=build,
 back_machine_revision='asymmetric paired supply / flank return / regulator / layered spine / supported upper cell')
report_path.write_text(json.dumps(report,indent=2)+'\n')
(folder/'README.md').write_text(f'''# Reference two: regular zombies

The rear machine was rebuilt through the visible Blender MCP session on port
9877. It now follows the reference's asymmetric pipe network, with paired supply
lines, a separate flank return, copper induction chamber, amber regulator,
layered lower spinal cassettes and a solid carrier for the tall neural cell.
The original body, head, skin weights and other master equipment are preserved.

- Master: `reference_two.blend`; {report['equipment_objects']:,} equipment objects.
- Gallery: `../cyber_zombie_roster/review.html?ref=2&mode=native&view=back_detail`.
- Five 4096-square baked maps; seven equipment LODs: {' / '.join(map(str,totals))}.
- Four pose checks passed. Reference-one and reference-three assets unchanged.
- Full build verified {build['ff_local_time']}; {build['ff_bytes']:,}-byte main fastfile.
- All {build['snapshot_inputs']} snapshot/source/deployed inputs match; compiled geometry passed.
- Built and stopped; game not launched. User playtest remains pending.

Authoring: `tools/cyber_references/two_back_machine.py`, followed by
`fix_modifier_order.py` and `review.py`. Evidence: `tmp/reference_two_back_machine_20260916`.
Gallery pictures are Blender renders of masters and exported source assets,
not in-game screenshots. Equipment adapts the reference to the original donor.
''',encoding='utf-8')
files=[master,report_path,folder/'README.md']+list(folder.glob('*.png'))+list(folder.glob('*.render.json'))+list((folder/'game_preview').glob('*'))
(folder/'delivery_manifest.json').write_text(json.dumps({'reference':2,'assignment':'Regular zombies','built_for_user_playtest':True,'native_playtested':False,'files':{str(p.relative_to(ROOT)):sha(p) for p in sorted(set(files))}},indent=2)+'\n')
doc=ROOT/'docs/149_reference_two_three_models.md';s=doc.read_text(encoding='utf-8')
s=re.sub(r'(reference_two\.blend`: )[\d,]+ separate equipment',lambda m:m[1]+f"{report['equipment_objects']:,} separate equipment",s)
s=re.sub(r'Ref2 totals: [\d, /]+\.',lambda m:'Ref2 totals: '+' / '.join(f'{v:,}' for v in totals)+'.',s)
s+=f'''

## Reference-two back machine enhancement — 2026-09-16

`two_back_machine.py` replaces only the `Back |` assembly through Blender MCP.
It verifies the other master equipment's signatures before saving. The new
layout puts paired descending purple supplies on the reference's rear-view left,
an amber regulator and independent return on the right, and a third route across
the lower flank. A copper induction chamber, actual hose saddles/compression
unions, deep louver pockets, layered spinal cassettes, hinge links, bus strips,
diagnostic sockets and an anchored lumbar plug replace the generic vent slab.
Open side rails expose the coat; the upper cell has a substantial nape carrier.
The authored model has {report['equipment_objects']:,} equipment objects; four pose checks pass.

Full build VERIFIED {build['ff_local_time']}: {build['ff_bytes']:,} bytes; all
{build['snapshot_inputs']} source/snapshot/deployed inputs match, no later sync or missing assets.
All 249 authored binaries pass source and compiled geometry checks. References
one and three remain byte-identical to the pre-pass asset snapshot. Dev/god/doors
OFF. Built and stopped, UNPLAYED. Evidence is in
`tmp/reference_two_back_machine_20260916/deployment_verification.json` and
`asset_preservation.json`. This is the current build; earlier build records
above are historical. No gameplay scripts or stats changed for this art pass.
'''
doc.write_text(s,encoding='utf-8')
claude=ROOT/'CLAUDE.md'
entry=f'''**2026-09-16 - REFERENCE TWO BACK MACHINE BUILT {build['ff_local_time']}.**
Full build {build['ff_bytes']:,} B; all {build['snapshot_inputs']} inputs match, no later sync/missing assets,
all 249 compiled model files retain geometry. Ref2's back was rebuilt in live
Blender MCP: paired descending purple pipes on rear-view left, separate lower
flank return, copper induction chamber, right amber regulator, layered spinal
cassettes, open side rails and a substantial upper-cell carrier. Source master
`art/cyber_reference_two_mcp/reference_two.blend`; script `two_back_machine.py`
supersedes the original mirrored-loop back from `two_torso.py`/`two_support.py`.
Other master equipment/donor meshes preserved; ref1/ref3 assets unchanged.
Dev/god/doors OFF. BUILT AND STOPPED, UNPLAYED; the user tests. Gallery has an
exported back close-up; evidence `tmp/reference_two_back_machine_20260916/`, docs/149.

'''
claude.write_text(entry+claude.read_text(encoding='utf-8'),encoding='utf-8')
print('REFERENCE_TWO_BACK_DELIVERY_RECORDED',build['ff_local_time'],'unchanged assets',len(preserved))
