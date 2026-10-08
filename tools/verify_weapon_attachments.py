"""Connect presentation AUs to weapons, including the native linker mapping gate.

Recipe: DTZxPorter / JerriGaming / The Black Death, Modme weapon attachments:
https://github.com/dtzxporter/ModmeWiki/blob/master/wiki/black_ops_3/guides/Setting-Up-Weapon-Attachments.md
The table is a build-machine input. Merge only this map's names; preserve stock
and peer rows byte-for-byte. No new weapon registrations or cosmetic variants.
"""
import argparse
from pathlib import Path
import re
from import_staff_animations import ROOT, blocks

TABLE = Path('share/raw/gamedata/weapons/common/attachmentmappingsTable.csv')
OWNED = re.compile(r'(?:leviathan(?:_up)?_k\d+|tod_staff_(?:ice|fire|lightning)_q\d+(?:d\d+)?)$')


def declarations():
    assets = {n: f for filename in ('tod_thunder_smash.gdt', 'tod_staff_pap.gdt')
              for n, k, f in blocks(ROOT/'source_data'/filename) if k == 'attachmentunique.gdf'}
    zone = set((ROOT/'zone_source/tod_twins.zpkg').read_text().splitlines())
    expected = {}
    for name, kind, fields in blocks(ROOT/'source_data/tod_weapon_twins.gdt'):
        runtime = name.removesuffix('_zm')
        if not OWNED.fullmatch(runtime):
            continue
        attachment = 'gmod7' if runtime.startswith('leviathan') else 'gmod6'
        assert 'weaponfull,'+name in zone, (name, 'must pack attachments with weaponfull')
        assert 'weapon,'+name not in zone, (name, 'duplicate bare registration')
        base = fields.get('attachmentUnique', '')
        for suffix in ('none', attachment):
            assert base+'_'+suffix in assets, (name, 'missing attachment unique', suffix)
        assert fields.get('ignoreAttachments', '0') == '0', (name, 'animation overrides disabled')
        expected[runtime] = attachment
    assert len(expected) == 21, ('presentation weapon coverage', len(expected))
    return expected


def merge_table(data, expected):
    # Retain unrelated rows exactly, including their existing newline style.
    lines = data.splitlines(keepends=True)
    kept = [line for line in lines if not OWNED.fullmatch(line.split(b',', 1)[0].decode('ascii', errors='replace'))]
    result = b''.join(kept)
    if result and not result.endswith(b'\n'):
        result += b'\r\n'
    return result + b''.join((name+','+attachment+'\r\n').encode('ascii')
                            for name, attachment in sorted(expected.items()))


def verify_table(data, expected):
    for name, attachment in expected.items():
        rows = [line for line in data.decode('ascii').splitlines() if line.split(',', 1)[0] == name]
        assert rows == [name+','+attachment], (name, 'missing/duplicate/wrong linker attachment mapping', rows)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--install', type=Path)
    parser.add_argument('--deployed', type=Path)
    args = parser.parse_args()
    expected = declarations()
    # Exercise preservation, stale row replacement and idempotence.
    sample = b'# stock header,\r\npeer,rf extclip\nleviathan_k999,gmod6\r\n'
    merged = merge_table(sample, expected)
    assert merged.startswith(b'# stock header,\r\npeer,rf extclip\n')
    assert b'k999' not in merged and merge_table(merged, expected) == merged
    verify_table(merged, expected)
    if args.install:
        target = args.install/TABLE
        original = target.read_bytes()  # Never replace a missing stock table with a fragment.
        result = merge_table(original, expected)
        verify_table(result, expected)
        if result != original:
            backup = target.with_suffix('.csv.tod-presentation-before')
            if not backup.exists():
                backup.write_bytes(original)
            temporary = target.with_suffix('.csv.tod-presentation-tmp')
            temporary.write_bytes(result)
            temporary.replace(target)
        verify_table(target.read_bytes(), expected)
    if args.deployed:
        verify_table((args.deployed/TABLE).read_bytes(), expected)
    print('Weapon attachments: 21 weaponfull roots, exact AU bindings, override flags and mapping merge checks pass.')


if __name__ == '__main__':
    main()
