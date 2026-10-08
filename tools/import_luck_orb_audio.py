"""Import all eight Origins Soul Box WAVs; --check validates frozen build inputs.

Audio is copied unchanged. Tower-owned aliases control volume, spatialization
and voice limits without overwriting the installed pack's aliases.
"""
import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import wave
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = Path('C:/Users/jorda/Downloads/Origins-Soul-Box-OriginsSoulBox-v1.0.0.zip')
MANIFEST = ROOT / 'docs/luck_orb_audio_manifest.json'
ALIASES = ROOT / 'sound/aliases/tod_luck_orbs.csv'
# Source alias, our alias, volume, pan, looping, global voice limit.
SOUNDS = [
    ('snd_ori_soul_flush', 'tod_luck_soul_release', 72, '3d', False, 8),
    ('snd_ori_charge_soul_full_loop', 'tod_luck_soul_travel', 58, '3d', True, 4),
    ('snd_ori_soul_impact', 'tod_luck_soul_arrive', 76, '2d', False, 8),
    ('snd_ori_charge_soul_full', 'tod_luck_soul_full', 78, '2d', False, 4),
    ('snd_ori_soul_box_open', 'tod_luck_box_open', 76, '2d', False, 4),
    ('snd_ori_soul_box_close', 'tod_luck_box_close', 74, '2d', False, 4),
    ('snd_ori_soul_box_fire_lp', 'tod_luck_box_fire', 52, '3d', True, 4),
    ('snd_ori_soul_box_disappear', 'tod_luck_box_disappear', 74, '2d', False, 4),
]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def aliases(manifest):
    with (ROOT / 'sound/aliases/tod_ui.csv').open(newline='') as f:
        fields = next(csv.reader(f))
    out = io.StringIO(newline='')
    writer = csv.DictWriter(out, fieldnames=fields, lineterminator='\n')
    writer.writeheader()
    for source, name, volume, pan, loop, limit in SOUNDS:
        item = manifest['sounds'][name]
        row = dict(Name=name, Storage='loaded',
                   FileSpec=item['file'].removeprefix('sound_assets/').replace('/', '\\'),
                   VolMin=volume, VolMax=volume, PanType=pan,
                   Looping=('LOOPING' if loop else 'NONLOOPING'),
                   LimitCount=limit, LimitType='oldest',
                   EntityLimitCount=(1 if loop else 2), EntityLimitType='oldest',
                   Pauseable='yes', StopOnEntDeath='yes')
        if pan == '2d':
            row['Template'] = 'UIN_MOD'
        else:
            row.update(Bus='BUS_FX', VolumeGroup='grp_set_piece', DuckGroup='snp_set_piece',
                       ReverbSend=20, CenterSend=0, DistMin=40, DistMaxDry=500,
                       DistMaxWet=600, DryMinCurve='allon', DryMaxCurve='default',
                       WetMinCurve='allon', WetMaxCurve='default', Pan='default',
                       PriorityMin=50, PriorityMax=80,
                       PriorityThresholdMin=.25, PriorityThresholdMax=1,
                       AmplitudePriority='no', Probability=1)
        writer.writerow(row)
    return out.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, default=ARCHIVE)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.check:
        manifest = json.loads(MANIFEST.read_text())
        assert len(manifest['sounds']) == 8
        for item in manifest['sounds'].values():
            data = (ROOT / item['file']).read_bytes()
            assert sha(data) == item['sha256'], item['file'] + ' changed'
            with wave.open(io.BytesIO(data)) as wav:
                assert wav.getframerate() == 48000 and wav.getsampwidth() == 2
        assert ALIASES.read_text() == aliases(manifest), 'Luck sound aliases differ'
        config = json.loads((ROOT / 'sound/zoneconfig/zm_tower_of_doom.szc').read_text())
        assert sum(s.get('Filename') == 'tod_luck_orbs.csv' for s in config['Sources']) == 1
        assert not any(line.startswith('tod_headshot_ding,') for line in
                       (ROOT / 'sound/aliases/tod_ui.csv').read_text().splitlines())
        print('Luck audio verified: 8 unchanged pack WAVs, bounded aliases, sound-bank wiring, no Apex ding alias.')
        return
    manifest = dict(archive=args.archive.name, archive_sha256=sha(args.archive.read_bytes()),
                    credits=['Fanatic', 'Scobalula', 'HarryBo21', 'Treyarch'], sounds={})
    with ZipFile(args.archive) as archive:
        alias_name = next(n for n in archive.namelist() if n.endswith('sound/aliases/origins_soul_box.csv'))
        donor_rows = {r['Name']: r for r in csv.DictReader(io.StringIO(
            archive.read(alias_name).decode('utf-8-sig').replace('\r\r\n', '\n')))}
        for source, name, *_ in SOUNDS:
            relative = donor_rows[source]['FileSpec'].replace('\\', '/')
            member = next(n for n in archive.namelist() if n.endswith('sound_assets/' + relative))
            data = archive.read(member)
            target = ROOT / 'sound_assets/tod/luck' / Path(relative).name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            with wave.open(io.BytesIO(data)) as wav:
                seconds = wav.getnframes() / wav.getframerate()
            manifest['sounds'][name] = dict(source_alias=source, archive_member=member,
                file=target.relative_to(ROOT).as_posix(), sha256=sha(data), seconds=seconds)
    MANIFEST.write_text(json.dumps(manifest, indent=2) + '\n')
    ALIASES.write_text(aliases(manifest), newline='\n')
    print('Imported all 8 Origins Soul Box sounds unchanged.')


if __name__ == '__main__':
    main()
