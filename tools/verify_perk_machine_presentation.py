"""Gate machine presentation on complete notes, source assets and banked audio."""
import csv
import hashlib
import json
from pathlib import Path
import re
import wave
from import_staff_animations import ROOT, blocks
from import_perk_machine_presentation import SHOTS
from bo6_extraction.install_ice_staff_bo3 import load_pycod

load_pycod()
from PyCoD import xanim as xa

manifest = json.loads((ROOT/'docs/perk_machine_presentation_manifest.json').read_text())
for name, expected in manifest['files'].items():
    path = ROOT/name
    assert path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == expected, ('asset drift', name)
assets = {name: fields for name, kind, fields in blocks(ROOT/'source_data/tod_perk_machines.gdt')}
assert set(assets) == {'tod_doubletap_intro', 'tod_doubletap_fire', 'tod_doubletap_outro', 'tod_wisp_activate'}


def notes(fields, prefix):
    result = []
    for key, action in fields.items():
        if re.fullmatch(prefix+r'\d+action', key) and action != 'None':
            base = key.removesuffix('action')
            result.append((int(fields.get(base+'frame', -1)), action,
                           fields.get(base+'actionparam1', ''), fields.get(base+'actionparam2', '')))
    return result


with (ROOT/'sound/aliases/tod_perk_machines.csv').open(newline='') as file:
    rows = list(csv.DictReader(file))
assert len(rows) == 14
aliases = {row['Name'] for row in rows}
assert len(aliases) == 5
assert sum(row['Name'] == 'evt_doubletap_purchase_shots' for row in rows) == 10
for row in rows:
    assert row['Storage'] == 'loaded' and row['PanType'] == '3d'
    with wave.open(str(ROOT/'sound_assets'/row['FileSpec'].replace('\\', '/'))) as wav:
        assert wav.getnframes() > 0 and wav.getsampwidth() == 2
szc = json.loads((ROOT/'sound/zoneconfig/zm_tower_of_doom.szc').read_text())
assert sum(s.get('Filename') == 'tod_perk_machines.csv' for s in szc['Sources']) == 1
for name, fields in assets.items():
    assert fields['looping'] == '0'
    clip = xa.Anim()
    clip.LoadFile_Bin(str(ROOT/'xanim_export'/fields['filename'].replace('\\', '/')))
    assert clip.framerate == 30
    assert (ROOT/'model_export'/fields['model'].replace('\\', '/')).is_file()
    for prefix, limit in [('customnote', 50), ('fx_customnote', 20), ('sound_customnote', 20),
                          ('fx_shutdownnote', 10), ('sound_shutdownnote', 10)]:
        entries = notes(fields, prefix)
        assert len(entries) <= limit
        for frame, action, param, bone in entries:
            assert frame == -1 or 0 <= frame < len(clip.frames), (name, frame, len(clip.frames))
            assert 'FxOnObject@' not in param, ('inert BO6 FX string', name, param)
            if action in ('Sound', 'Stop Sound'):
                assert param in aliases, ('unbanked sound', name, param)
            if action in ('Play Fx', 'Kill Fx', 'Stop Fx'):
                assert (ROOT/'share/raw/fx'/param.replace('\\', '/')).is_file(), ('missing FX', param)
    print(name, len(clip.frames), 'frames at', clip.framerate, 'fps')
fire = assets['tod_doubletap_fire']
assert notes(fire, 'customnote') == [(frame, 'Self Notify', 'tod_doubletap_shot', 'j_pistol_'+hand+'_muzzle') for frame, hand in SHOTS]
shots = [entry for entry in notes(fire, 'sound_customnote') if entry[2] == 'evt_doubletap_purchase_shots']
flashes = [entry for entry in notes(fire, 'fx_customnote') if 'doubletap_muzzle' in entry[2]]
assert [entry[0] for entry in shots] == [frame for frame, hand in SHOTS]
assert [(entry[0], entry[3]) for entry in flashes] == [(frame, 'j_pistol_'+hand) for frame, hand in SHOTS]
assert sum(entry[2] == 'evt_doubletap_purchase_loop' for entry in notes(fire, 'sound_customnote')) == 1
# 2026-09-23 (v19.44): the volley is SCHEDULED in script from the clip's start on
# these same frames (the clip's script notes wake the AnimScripted done-notify
# instead of reaching a listener), so the GSC frame table is pinned to SHOTS.
gsc = (ROOT/'scripts/zm/zm_tower_of_doom/_tod_perk_anims.gsc').read_text()
table = re.search(r'function volley_frames\(\)\s*\{\s*return array\(([^)]*)\);', gsc)
assert table, 'volley_frames() table missing from _tod_perk_anims.gsc'
assert [int(v) for v in table.group(1).split(',')] == [frame for frame, hand in SHOTS], 'GSC shot frames drifted from SHOTS'
assert [hand for frame, hand in SHOTS] == ['le' if i % 2 == 0 else 'ri' for i in range(len(SHOTS))], \
    'SHOTS no longer alternate left/right from the left pistol; volley_muzzle() assumes that'
assert 'waittill( done, note )' in gsc and 'if ( note == "end" ) break;' in gsc, 'a clip must finish only on the "end" note'
assert notes(assets['tod_wisp_activate'], 'sound_customnote')[0][2] == 'ff13a722f5a3c511'
zone = (ROOT/'zone_source/zm_tower_of_doom.zone').read_text()
tree = (ROOT/'animtrees/tod_perk_machines.atr').read_text()
for name in assets:
    assert 'xanim,'+name in zone and name in tree
assert 't10_zm_machine_d_mod_bullet' not in zone, 'No new weapon registration is needed'

# 2026-09-23: THE WIDOW'S WINE POWERED PANEL NEEDS A SHADER THE TOOLS DO NOT SHIP.
# sat_zm_machine_y_mod_01_on (pack GDT) is authored on
# lit_emissive_scroll_3layer_advanced_fullspec: a techsetdef the SAT code archive
# ships and this install never had. The linker does not fail on it - it builds the
# material on missing_techsetdef_geometry, writes nothing to the errorlog, and the
# whole front panel (sign, spider crest, red WIDOW'S WINE glow) renders as the
# engine's grey stand-in once powered. The repo carries the def under both
# techsetdef trees and the sync copies them; this pins the content and proves both
# installed copies BEFORE the link (build_map.ps1 reads the ledger after it).
from bo6_extraction.install_ice_staff_bo3 import TOOLS
TECHSETDEF = 'geometry_advanced/lit_emissive_scroll_3layer_advanced_fullspec.techsetdef'
TECHSETDEF_SHA = '1ceee61a64126105a38a3d31bfa1e507dd1faa4c47505a20ffffb1a77d946af9'
for tree in ('techsetdefs_stable', 'techsetdefs_stable_toolsgfx'):
    for root in (ROOT, TOOLS):
        path = root/'share/raw'/tree/TECHSETDEF
        assert path.is_file(), ('3-layer emissive techsetdef missing (grey Widow\'s Wine panel)', str(path))
        assert hashlib.sha256(path.read_bytes()).hexdigest() == TECHSETDEF_SHA, ('techsetdef drift', str(path))
pack_gdt = TOOLS/'_custom/_wetegg/models/sat/sat_zm_machine_y_mod/sat_zm_machine_y_mod.gdt'
assert '"materialType" "lit_emissive_scroll_3layer_advanced_fullspec"' in pack_gdt.read_text(errors='replace'), \
    'Widow\'s Wine pack GDT no longer uses the 3-layer emissive type; retire this pin'
print('Perk machine assets pass: 16 paired shots/FX/sounds, interruption cleanup, finite clips, 14 WAVs, loaded alias source, 3-layer emissive techsetdef installed x2.')
