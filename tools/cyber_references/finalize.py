"""Record completed build evidence without touching deployed game inputs."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
raw_log=(ROOT/'tmp/reference_23_integration/build_final.log').read_bytes()
log=raw_log.decode('utf-16' if raw_log.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8',errors='replace')
assert 'BUILD OK' in log and 'CYBER_ROSTER_NATIVE_OK' in log and 'CYBER_NATIVE_GEOMETRY_OK' in log,'Full compiled build must pass before delivery is recorded'
build=json.loads((ROOT/'tmp/reference_23_integration/deployment_verification.json').read_text())
assert not build['differences'] and not build['deployed_inputs_newer_than_ff'] and not build['missing_assets']
details=[]
for word,number in [('two',2),('three',3)]:
    folder=ROOT/('art/cyber_reference_'+word+'_mcp');reportpath=folder/'validation.json'
    report=json.loads(reportpath.read_text());master=folder/('reference_'+word+'.blend')
    assert hashlib.sha256(master.read_bytes()).hexdigest()==report['master_sha256']
    counts=json.loads((folder/'engine_kit/lod_counts.json').read_text())
    totals=[sum(counts[str(i)].values()) for i in range(7)]
    report.update(native_exported=True,native_playtested=False,equipment_lod_triangles=totals,game_integration=build)
    reportpath.write_text(json.dumps(report,indent=2)+'\n')
    title='Regular zombies' if number==2 else 'Armored sprinter only'
    readme=f'''# Reference {number}: {title}

Created through the upstream Blender MCP in the visible localhost:9877 session.
The original body, head geometry and skin weights are preserved. The exact user
concept sheet is packed into the master and included beside the gallery.

- Master: `reference_{word}.blend` ({report['equipment_objects']:,} equipment objects).
- Gallery: `../cyber_zombie_roster/review.html`, with actual master and native
  source binary/atlas renders. Gallery pictures are not in-game screenshots.
- Native equipment LOD totals: {' / '.join(str(t) for t in totals)}.
- Five 4096-square baked maps preserve the worn-metal, chipped-enamel and
  luminous fluid finishes. Dense editable geometry is not shipped directly.
- Four attachment pose checks pass; original donor hashes match.
- Full local build verified {build['ff_local_time']}; {build['ff_bytes']:,}-byte
  main fastfile. Game not launched; user playtest pending. Dev/god/doors OFF.

Authoring and delivery scripts: `tools/cyber_references/`. Full integration
record: `docs/149_reference_two_three_models.md`. Backup of previous game inputs:
`tmp/reference_23_backup/`. The unrelated gold sword Blender session is untouched.

The equipment is reconstructed from the image and fitted to the original donor;
it is not exact recovery of an unseen 3D source. In-game lighting, animation
clearance and performance still require playtesting.
'''
    (folder/'README.md').write_text(readme,encoding='utf-8')
    files=[master,reportpath,folder/'README.md',folder/('CyberZombie'+str(number)+'.png')]
    files+=list(folder.glob('*.png'))+list(folder.glob('*.render.json'))+list((folder/'game_preview').glob('*'))
    manifest={'reference':number,'assignment':title,'built_for_user_playtest':True,'native_playtested':False,
      'files':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(set(files))}}
    (folder/'delivery_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    details.append((report,totals))
doc=ROOT/'docs/149_reference_two_three_models.md';text=doc.read_text()
text=text.replace('1,502 separate equipment',f"{details[0][0]['equipment_objects']:,} separate equipment")
text=text.replace('46,930 / 29,616 / 16,071 / 7,137 / 4,975 / 3,039 / 1,781',' / '.join(f'{x:,}' for x in details[0][1]))
text=text.replace('Ref3 totals are in its engine_kit/lod_counts.json.', 'Ref3 totals: '+' / '.join(f'{x:,}' for x in details[1][1])+'.')
text=text.replace('Build status will be recorded below after verification.',f"Full local build VERIFIED {build['ff_local_time']}: main fastfile {build['ff_bytes']:,} bytes. All {build['snapshot_inputs']} snapshot/source/deployed inputs match; no later deployed inputs and no missing assets. All 249 authored source binaries pass native compiled triangle coverage.")
text+='''

### Build repair notes

Attempt one stopped at the reference-one manifest: its installer used to hash
every PNG in the shared directory, including the independently installed roster
atlases. The manifest now owns exactly its five `i_tod_cyber_kit_*` maps; the
roster manifest owns its twenty maps. Regenerating the manifest left all 65
reference-one binaries byte-for-byte unchanged. A final close-up also prompted
physical rails and a power jumper between reference two's raised rear cell and
its backpack. The final master and all derivatives include these supports.
'''
doc.write_text(text,encoding='utf-8')
claude=ROOT/'CLAUDE.md'
entry=f'''**2026-09-16 - REFERENCES TWO/THREE BUILT {build['ff_local_time']}.**
User mapping: refs 1/2 REGULAR, ref 3 ARMORED ONLY. Both new models authored
through live Blender MCP 9877, original donors/weights preserved; gallery at
`art/cyber_zombie_roster/review.html`, masters `art/cyber_reference_two_mcp/`
and `art/cyber_reference_three_mcp/`. Trooper/Relay now use ref2; sprinter uses
ref3 twin tanks, welder visor, powered arm/hand. Promotion replaces only known
intact heads with the SAME head identity wearing ref3; native gib flags, unknown
heads and repeated calls are guarded. Original head/hat attachments are removed
and both gib-data layouts updated. No gameplay stats changed. Full build passed:
FF {build['ff_bytes']:,} B; {build['snapshot_inputs']} inputs match, no later sync/missing assets, all 249
authored binaries pass source and compiled geometry coverage. Dev/god/doors OFF.
BUILT AND STOPPED, UNPLAYED; user tests. See docs/149 and
tmp/reference_23_integration/deployment_verification.json. Reference one's 65
binaries are unchanged. Older notes assigning ref3 to Relay/ref2 to sprinter
are superseded. Signal's existing ref1 head/helmet accents remain.

'''
claude.write_text(entry+claude.read_text(encoding='utf-8'),encoding='utf-8')
print('REFERENCE_23_DELIVERY_RECORDED')
