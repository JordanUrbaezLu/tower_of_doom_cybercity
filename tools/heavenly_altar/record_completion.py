"""Record the verified September 16 altar deployment without touching game inputs."""
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
evidence = ROOT / 'tmp/heavenly_altar_integration'
deployment = json.loads((evidence / 'deployment_verification.json').read_text())
assert not deployment['differences']
assert not deployment['missing_assets']
assert not deployment['deployed_inputs_newer_than_ff']
peer_log = Path(r'C:\Users\jorda\AppData\Local\Temp\claude\c--Users-jorda-Repositories-tower-of-doom-cybercity\9b957786-92f5-4471-905f-15b76e48d80b\scratchpad\hoop_v1921_build_3.log')
assert 'BUILD OK' in peer_log.read_text(encoding='utf-8', errors='replace')
shutil.copy2(peer_log, evidence / 'final_packaging_build.log')
provenance = {
    'full_build': 'build.log: geometry, navmesh, LED bake and native packaging completed; a concurrent peer sync deleted generated ledgers during post-link checks.',
    'final_packaging': 'final_packaging_build.log: peer GSC-only packaging completed BUILD OK using the fresh full-build geometry and unchanged snapshot inputs.',
    'independent_checks': ['compiled_altar_check.log', 'compiled_zombie_check.log', 'compiled_roster_check.log', 'deployment_verification.json'],
    'compiled_altar_lods': [83194, 51316, 35428, 26611, 21750, 18083, 15421],
    'compiled_altar_triangle_coverage': 'exact at every authored LOD',
    'existing_cyber_binaries_verified': 249,
    **deployment,
}
(evidence / 'build_provenance.json').write_text(json.dumps(provenance, indent=2) + '\n', encoding='utf-8')

guidance = ROOT / 'CLAUDE.md'
text = guidance.read_text(encoding='utf-8')
end = text.index('**2026-09-16 - REFERENCE TWO BACK MACHINE')
assert text.startswith(('**2026-09-16 - HEAVENLY ALTAR CYBER ART STUDY', '**2026-09-16 - ALL SIX HEAVENLY ALTARS'))
text = '''**2026-09-16 - ALL SIX HEAVENLY ALTARS REPLACED AND BUILT.**
Shared station model is now `tod_heavenly_altar`: spawn, four breather lounges,
and crown. Prices, triggers, original collision and aura sound are preserved.
Editable master: `art/heavenly_altar/heavenly_altar_cyber.blend`; original copy
and native donor remain preserved. Author through the isolated real Blender
MCP session **9878** (9876 is Tower II sword; 9877 is zombie work).
User requested visible textures: RENDERED Eevee, scene lighting and glow.
Native assets: `model_export/tod_heavenly_altar/`, map-owned GDT, eight baked
textures, three materials, seven LODs (83,194 down to 15,421 triangles).
Full geometry/LED/native build completed; a peer sync interrupted its ledger
checks. Final peer packaging passed BUILD OK at 18:50:18 Eastern, FF
146,512,640 B. Independently verified all 164 snapshot/source/deployed inputs,
no later sync/missing assets, exact compiled triangle coverage at all seven
altar LODs and all 249 existing cyber binaries. Evidence and race provenance:
`tmp/heavenly_altar_integration/build_provenance.json`. Dev/god/doors OFF.
BUILT AND STOPPED; user tests. No game launch or native visual verification.
Exterior is modeled; heavenly figures/stairs use recessed reference artwork.
Rear extrapolates the front reference. Blender renders do not establish exact
native glow/lighting. Scripts/docs: `tools/heavenly_altar/`,
`art/heavenly_altar/README.md`, `validation.json`, `review.html`.

''' + text[end:]
guidance.write_text(text, encoding='utf-8', newline='')

readme = ROOT / 'art/heavenly_altar/README.md'
text = readme.read_text(encoding='utf-8')
text = text.replace('still require baking for native deployment.', 'are baked into the native texture maps for deployment.')
text = text.replace('**Native export prepared; full build queued while BO3 is running. Not\nplaytested.**', '**All six altars built and independently verified. User playtest pending.**')
text = text.replace('Deployment evidence goes to\n`tmp/heavenly_altar_integration/deployment_verification.json` when complete.', '''Final package: **146,541,888 bytes, September 16 at 18:43:59 Eastern**.
All 164 source/deployed inputs match the full-build snapshot, no later sync or
missing altar assets, and every triangle survives conversion at all seven LODs.
The existing 249 cyber zombie binaries also pass source and compiled checks.
Our full geometry/lighting/native build completed; a concurrent peer sync
removed its reports during postchecks. The peer's subsequent packaging passed
BUILD OK using those unchanged inputs, and all checks were repeated independently.
Evidence: `tmp/heavenly_altar_integration/deployment_verification.json` and
`build_provenance.json`. The game was not launched; dev/god/open doors stay off.''')
text = text.replace('146,541,888 bytes, September 16 at 18:43:59 Eastern', '146,512,640 bytes, September 16 at 18:50:18 Eastern')
text = text.replace('Review the model from multiple angles before native integration.', 'Native integration is complete; the user will judge the game appearance.')
readme.write_text(text, encoding='utf-8')

validation = ROOT / 'art/heavenly_altar/validation.json'
data = json.loads(validation.read_text(encoding='utf-8'))
data.update(game_assets_changed=True, native_exported=True, native_build_verified=True,
            replaced_placements=6, deployment=deployment,
            build_provenance='../../tmp/heavenly_altar_integration/build_provenance.json')
data['limitations'][-1] = 'Native baked materials and all seven LODs are built and verified; game appearance, glow and transparency still await the user playtest.'
validation.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')

gallery = ROOT / 'art/heavenly_altar/review.html'
text = gallery.read_text(encoding='utf-8')
text = text.replace('This is a Blender art study; BO3 export and in-game lighting remain pending.', 'These are Blender previews. All six BO3 altars are replaced and built; in-game appearance awaits your playtest.')
gallery.write_text(text, encoding='utf-8')
print('ALTAR_COMPLETION_RECORDED')
