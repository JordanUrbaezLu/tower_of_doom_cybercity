"""Vendor WetEgg SAT machine cues; normal builds validate the frozen outputs.

Donor code/audio are extracted under tmp/perk_machine_fix_20260922. Shared
installed assets are read only. No extra weapon registrations are required.
"""
import csv
import hashlib
import json
from pathlib import Path
import re
import shutil
from import_staff_animations import ROOT, blocks, emit
from verify_staff_animations import find_tools_root

TOOLS = find_tools_root()
WORK = ROOT / 'tmp/perk_machine_fix_20260922'
VENDOR = WORK / 'vendor/SATPerksCode/share/raw'
SHOTS = [(1, 'le'), (8, 'ri'), (15, 'le'), (21, 'ri'), (24, 'le'),
         (27, 'ri'), (34, 'le'), (35, 'ri'), (42, 'le'), (43, 'ri'),
         (49, 'le'), (52, 'ri'), (59, 'le'), (61, 'ri'), (67, 'le'), (70, 'ri')]
EYE = r'_wetegg\\sat\\perks\\fx_double_tap_zombie_eye_glow_red.efx'
MUZZLE = r'tod\\perks\\doubletap_muzzle.efx'


def note(fields, prefix, index, action, param, frame=None, bone=''):
    key = prefix + str(index)
    fields.update({key+'action': action, key+'actionparam1': param,
                   key+'actionparam2': bone})
    if frame is not None:
        fields.update({key+'frame': str(frame), key+'useexistingnote': ''})


def main():
    files = set()
    sources = {}
    def copy(source, relative):
        target = ROOT / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        files.add(target)
        sources[str(source)] = hashlib.sha256(source.read_bytes()).hexdigest()
        return target
    assets = []
    for folder, wanted in [
        ('t10_zm_machine_d_mod', {
            't10_fxanim_zm_machine_d_mod_intro': 'tod_doubletap_intro',
            't10_fxanim_zm_machine_d_mod_loop': 'tod_doubletap_fire',
            't10_fxanim_zm_machine_d_mod_outro': 'tod_doubletap_outro'}),
        ('sat_zm_machine_w_mod', {'anim_2f28cb2f33eaab2f': 'tod_wisp_activate'}),
    ]:
        donor = TOOLS / ('_custom/_wetegg/models/sat/' + folder + '/' + folder + '.gdt')
        sources[str(donor)] = hashlib.sha256(donor.read_bytes()).hexdigest()
        for name, kind, original in blocks(donor):
            if name not in wanted:
                continue
            name = wanted[name]
            # Rebuild notes, removing unported BO6 FxOnObject strings incorrectly
            # labelled as Sound and the duplicate loop sound in the donor.
            fields = {k: v for k, v in original.items()
                      if not re.match(r'(?:(?:fx_|sound_)?(?:custom|startup|shutdown)note)\d+', k)}
            for field, tree in [('filename', 'xanim_export'), ('model', 'model_export')]:
                source = (TOOLS / tree / original[field].replace('\\', '/')).resolve()
                relative = Path(tree) / 'tod_perk_machines' / source.name
                copy(source, relative)
                fields[field] = str(relative.relative_to(tree)).replace('\\', '\\\\')
            fields['looping'] = '0'  # One finite purchase cycle, including fire.
            if name.startswith('tod_doubletap'):
                phase = {'tod_doubletap_intro': 'intro', 'tod_doubletap_fire': 'loop',
                         'tod_doubletap_outro': 'outro'}[name]
                note(fields, 'sound_customnote', 0, 'Sound', 'evt_doubletap_purchase_'+phase, 1)
                note(fields, 'sound_shutdownnote', 0, 'Stop Sound', 'evt_doubletap_purchase_'+phase)
                # Carry the eye glow through each clip, but also clean it up on
                # StopAnimScripted (movement, power loss, retirement).
                note(fields, 'fx_customnote', 0, 'Play Fx', EYE, 1, 'j_eyeball_le')
                note(fields, 'fx_shutdownnote', 0, 'Kill Fx', EYE, bone='j_eyeball_le')
                if name == 'tod_doubletap_fire':
                    for i, (frame, hand) in enumerate(SHOTS):
                        note(fields, 'customnote', i, 'Self Notify', 'tod_doubletap_shot', frame,
                             'j_pistol_'+hand+'_muzzle')
                        note(fields, 'fx_customnote', i+1, 'Play Fx', MUZZLE, frame, 'j_pistol_'+hand)
                        note(fields, 'sound_customnote', i+1, 'Sound', 'evt_doubletap_purchase_shots', frame)
                if name == 'tod_doubletap_outro':
                    note(fields, 'fx_customnote', 1, 'Kill Fx', EYE, 145, 'j_eyeball_le')
            else:
                note(fields, 'fx_customnote', 0, 'Play Fx', r'_wetegg\\sat\\perks\\fx_wisp_tea_activate.efx', 1)
                note(fields, 'sound_customnote', 0, 'Sound', 'ff13a722f5a3c511', 1)
                note(fields, 'sound_shutdownnote', 0, 'Stop Sound', 'ff13a722f5a3c511')
            assets.append((name, kind, fields))
    assert len(assets) == 4
    gdt = ROOT / 'source_data/tod_perk_machines.gdt'
    gdt.write_text('{\n' + ''.join(emit(*a) for a in assets) + '}\n')
    files.add(gdt)
    for fx in ('fx_double_tap_zombie_eye_glow_red', 'fx_wisp_tea_activate'):
        copy(VENDOR / ('fx/_wetegg/sat/perks/'+fx+'.efx'), 'share/raw/fx/_wetegg/sat/perks/'+fx+'.efx')
    # Muzzle tags have identity bind rotations, unlike the animated pistol
    # roots. Attach to the root with the measured muzzle offset so the flash
    # follows the barrel rather than pointing sideways out of the machine.
    source = VENDOR / 'fx/_wetegg/sat/perks/fx_mule_kick_bullet_fire_fx.efx'
    target = copy(source, 'share/raw/fx/tod/perks/doubletap_muzzle.efx')
    fx = target.read_text().replace('spawnOrgX 0.000000 0.000000;', 'spawnOrgX 4.330710 0.000000;')
    fx = fx.replace('spawnOrgZ 0.000000 0.000000;', 'spawnOrgZ 1.771652 0.000000;')
    target.write_text(fx)
    donor = VENDOR / 'sound/aliases/_wetegg/sat/sat_perk_machines.csv'
    with donor.open(encoding='utf-8-sig', newline='') as file:
        reader = csv.DictReader(file)
        columns = reader.fieldnames
        rows = [r for r in reader if r['Name'].startswith('evt_doubletap_purchase')
                or r['Name'] == 'ff13a722f5a3c511']
    assert len(rows) == 14
    aliases = ROOT / 'sound/aliases/tod_perk_machines.csv'
    with aliases.open('w', newline='') as file:
        writer = csv.DictWriter(file, fieldnames=columns)
        writer.writeheader(); writer.writerows(rows)
    files.add(aliases)
    for row in rows:
        relative = 'sound_assets/' + row['FileSpec'].replace('\\', '/')
        copy(WORK / 'assets/SATPerksAssets' / relative, relative)
    report = dict(sources=sources, shots=SHOTS,
                  files={p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                         for p in sorted(files)}, native_verified=False)
    (ROOT / 'docs/perk_machine_presentation_manifest.json').write_text(json.dumps(report, indent=2)+'\n')
    print('Vendored four machine clips, three FX, fourteen WAVs; no weapon registrations.')


if __name__ == '__main__':
    main()
