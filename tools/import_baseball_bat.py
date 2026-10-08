"""Vendor pmr360's BOCW Baseball Bat without overwriting shared common assets.

Run after extracting the user's archive to tmp/baseball_bat/pack.
The weapon generator owns balance; this import preserves the port presentation.
"""
from pathlib import Path
import csv
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / 'tmp/baseball_bat/pack/BOCW Baseball Bat'
TOOLS = Path('C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130')


def main():
    source = PACK / 'source_data/t9_weapons/melee/wpn_t9_me_baseballbat.gdt'
    text = source.read_text(encoding='utf8')
    # Private disk paths; asset names already belong uniquely to this pack.
    text = re.sub(r't9_wpn_ports\\+_melee\\+t9_baseballbat', 'tod_baseball_bat', text)
    for folder in ('model_export', 'xanim_export'):
        shutil.copytree(PACK / folder / 't9_wpn_ports/_melee/t9_baseballbat',
                        ROOT / folder / 'tod_baseball_bat', dirs_exist_ok=True)
    # Own the swish on the actual swing clips. This also covers an empty swing,
    # where the port's missing native sledgehammer whoosh aliases played nothing.
    text = text.replace('wpn_melee_t9_sledgehammer_swing_plr', '')
    text = text.replace('wpn_melee_t9_sledgehammer_swing_npc', '')
    for name in ('vm_t9_bat_melee_miss', 'vm_t9_bat_melee_miss_02', 'vm_t9_bat_melee_in'):
        match = re.search(r'\t"' + name + r'".*?\n\t}', text, re.S)
        block = match.group()
        # Slot zero is the pack's controller rumble; keep it intact.
        edits = {'customnote1action': '2D Sound',
                 'customnote1actionparam1': 'tod_bat_swing',
                 'customnote1actionparam2': '', 'customnote1frame': '4',
                 'customnote1useexistingnote': ''}
        for key, value in edits.items():
            block, count = re.subn(r'("' + key + r'" )"[^"]*"', lambda m: m[1] + '"' + value + '"', block)
            assert count <= 1, (name, key)
            if count == 0:
                block = block[:-3] + '\n\t\t"' + key + '" "' + value + '"\n\t}'
        text = text[:match.start()] + block + text[match.end():]
    text = text.replace('fly_melee_swipe_mace_shield', 'fly_melee_swipe_t9_bat')
    text = text.replace('fly_melee_swipe_player_mace_shield', 'fly_melee_swipe_player_t9_bat')
    text = text.replace('fly_melee_swipe_victim_mace_shield', 'fly_melee_swipe_victim_t9_bat')
    (ROOT / 'source_data/tod_baseball_bat.gdt').write_text(text, encoding='utf8')
    # Import only aliases referenced by the bat, recursively including layers.
    header = next(csv.reader((ROOT / 'sound/aliases/tod_combat_knife.csv').read_text(encoding='utf8').splitlines()))
    rows = list(csv.reader([line for line in (PACK / 'READ_ME.txt').read_text().splitlines()
                            if ',,loaded,' in line]))
    by_name = {}
    for row in rows:
        by_name.setdefault(row[0], []).append(row)
    names = {name for name in by_name if name in text}
    for clip in (ROOT / 'xanim_export/tod_baseball_bat').glob('*'):
        data = clip.read_bytes()
        names.update(name for name in by_name if name.encode() in data)
    while True:
        old = set(names)
        for name in old:
            for row in by_name[name]:
                names.update(v for v in row[8:11] if v in by_name)
        if names == old:
            break
    existing = set()
    for alias in (ROOT / 'sound/aliases').glob('*.csv'):
        if alias.name == 'tod_baseball_bat.csv':
            continue
        existing.update(row[0] for row in csv.reader(alias.read_text(encoding='utf8', errors='replace').splitlines()) if row)
    custom = ROOT / 'sound_assets/tod/baseball_bat/hit.wav'
    custom.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(Path.home() / 'Downloads/bathitball.wav', custom)
    whiffs = ('floraphonic-swing-whoosh-5-198498.wav',
              'floraphonic-swing-whoosh-weapon-1-189819.wav')
    for index, filename in enumerate(whiffs, 1):
        shutil.copy2(ROOT / 'tmp/baseball_bat/whiffs' / filename,
                     custom.with_name(f'swing_0{index}.wav'))
    out = []
    for name in sorted(names - existing):
        impact = name != 'fly_melee_t9_bat_crowd'
        for row in (by_name[name][:1] if impact else by_name[name]):
            if impact:
                row = list(row)
                row[3] = r'tod\baseball_bat\hit.wav'
                # One crack per contact, no inherited impact/crowd layers.
                row[8:11] = ['', '', '']
                row[30:32] = ['0', '0']
                out.append(row)
                continue
            wav = Path(row[3].replace('\\', '/'))
            src = PACK / 'sound_assets' / wav
            if not src.exists():
                src = TOOLS / 'sound_assets' / wav
            if not src.exists():
                raise FileNotFoundError(src)
            dest = ROOT / 'sound_assets' / wav
            dest.parent.mkdir(parents=True, exist_ok=True)
            if not dest.exists():
                shutil.copy2(src, dest)
            out.append(row)
    for index in (1, 2):
        swing = list(by_name['fly_melee_swipe_player_t9_bat'][0])
        swing[0] = 'tod_bat_swing'
        swing[3] = rf'tod\baseball_bat\swing_0{index}.wav'
        swing[8:11] = ['', '', '']
        swing[17:19] = ['88', '88']
        swing[30:32] = ['0', '0']
        # Multiple rows with one alias let the native sound system pick a sample.
        out.append(swing)
    with (ROOT / 'sound/aliases/tod_baseball_bat.csv').open('w', newline='') as file:
        writer = csv.writer(file, lineterminator='\n')
        writer.writerow(header)
        writer.writerows(out)
    print(f'Bat imported: {len(out)} sound rows; {len(names)} alias families (existing shared rows reused).')


if __name__ == '__main__':
    main()
