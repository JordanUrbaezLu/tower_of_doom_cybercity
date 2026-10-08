"""Compact golden luck soul from the installed Origins staff soul effect.

Two native looping emitters: wispy trail + attached core. The first release
was too small/subtle to spot in the user's live match despite 189 deliveries;
this version makes the core and trail larger/denser while keeping finite
particle lives and native mover limits. --check is the build gate.
"""
import argparse
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_TOOLS = Path('C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130')


def render(tools):
    donor = tools / 'share/raw/fx/dlc5/zmb_weapon/fx_staff_charge_souls.efx'
    blocks = re.split(r'\n\{\n', donor.read_text(encoding='utf-8'))[1:]
    if len(blocks) != 6:
        raise ValueError('Origins soul donor changed: expected six emitters')
    output = 'iwfx 2\n'
    for i, (interval, lifetime, size) in enumerate([(25, 500, 20), (60, 320, 44)]):
        block = blocks[i]
        if 'editorFlags looping' not in block:
            raise ValueError('Soul host requires native looping FX')
        block = re.sub(r'name "[^"]+";', f'name "luck_{["trail", "core"][i]}";', block, count=1)
        block = re.sub(r'spawnLooping \d+ \d+;', f'spawnLooping {interval} 0;', block, count=1)
        block = re.sub(r'lifeSpanMsec \d+ \d+;', f'lifeSpanMsec {lifetime} 0;', block, count=1)
        block = re.sub(r'sizeGraph([01]) [\d.]+', rf'sizeGraph\1 {size:.6f}', block)
        block = re.sub(r'fadeOutRange [\d.]+ [\d.]+;', 'fadeOutRange 0.000000 6.000000;', block, count=1)
        block = block.replace(' dieOnTouch', '')
        output += '\n{\n' + block.rstrip() + '\n'
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--tools', type=Path, default=DEFAULT_TOOLS)
    args = parser.parse_args()
    target = ROOT / 'share/raw/fx/tod/fx_luck_soul.efx'
    expected = render(args.tools)
    if args.check:
        if not target.exists() or target.read_text(encoding='utf-8') != expected:
            raise SystemExit('Luck soul FX differs; run tools/gen_luck_orb_fx.py')
        print('Luck soul FX verified: 2 native golden loops, bounded emission, no flash/light/cloud.')
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(expected, encoding='utf-8', newline='\n')
        print(f'Wrote {target.relative_to(ROOT)} ({len(expected)} bytes)')


if __name__ == '__main__':
    main()
