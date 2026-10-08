"""Build gate: the Mage staffs' THIRD-PERSON player pose (docs/161).

The staffs use Treyarch's own Origins staff player animations: playerAnimType
"armminigun" selects them in the stock playeranim scripts (core_common.ff), and
all 77 clips (48 pb_staff_* full-body, 29 pt_staff_* torso) ship in
zm_common.ff, which every Zombies usermap loads before its own fastfile. This
map converts, zones and packs NONE of them, on purpose: a same-named copy in
our zone would at best duplicate Treyarch's asset and at worst shadow it.

Checks (all against files on disk, no game launch):
  1. every staff form (3 source blocks + every generated tod_staff_*_zm twin)
     carries the chosen pose AND its matching world mount, the two together;
  2. armminigun: the tools' zm_common assetlist names all 77 clips, core_common
     names the playeranim scripts, playeranimtypes.txt lists the type and the
     projectileweapon editor offers it;
  3. nothing in this repo defines or zones a pb_staff_*/pt_staff_* asset.
Run with --selftest to see each check fail on a broken input.
"""
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from import_staff_animations import ROOT, blocks
from staff_presentation_bindings import STAFF_BINDINGS, STAFF_PLAYER_ANIM_TYPE, STAFF_WORLD_MOUNT
from verify_staff_animations import find_tools_root

POSE_MOUNT = {'armminigun': 'tag_weapon_right', 'bow': 'tag_weapon_left'}

# Exactly the xanim names Treyarch's zm_common assetlist carries for the staff
# (verified 2026-09-27: 48 + 29 = 77, the same 77 Greyhound exported).
PB = ['crouch2prone', 'crouch_idle', 'crouch_run_b', 'crouch_run_f', 'crouch_run_l', 'crouch_run_r',
      'crouch_turn_l90', 'crouch_turn_r90', 'crouch_walk_b', 'crouch_walk_f', 'crouch_walk_l',
      'crouch_walk_r', 'prone2crouch', 'prone2crouchrun', 'prone2run', 'prone2sprint', 'prone2stand',
      'prone_crawl_b', 'prone_crawl_f', 'prone_crawl_l', 'prone_crawl_r', 'prone_idle', 'prone_turn_l',
      'prone_turn_r', 'runjump_land', 'runjump_takeoff', 'stand_idle', 'stand_run_b', 'stand_run_f',
      'stand_run_l', 'stand_run_r', 'stand_sprint', 'stand_turn_l', 'stand_turn_r', 'stand_walk_b',
      'stand_walk_f', 'stand_walk_l', 'stand_walk_r', 'standjump_land', 'standjump_takeoff',
      'stumble_back', 'stumble_forward', 'stumble_left', 'stumble_right', 'stumble_walk_back',
      'stumble_walk_forward', 'stumble_walk_left', 'stumble_walk_right']
PT = [s + '_' + a for s in ('crouch', 'prone', 'stand')
      for a in ('fire', 'flinch_back', 'flinch_forward', 'flinch_left', 'flinch_right', 'melee',
                'melee_charge', 'putaway', 'raise', 'shellshock')]
PT.remove('prone_melee_charge')   # Treyarch ships none; the ZM melee script reuses the crouch clip
CLIPS = ['pb_staff_' + n for n in PB] + ['pt_staff_' + n for n in PT]
assert len(CLIPS) == 77 and len(set(CLIPS)) == 77
PLAYERANIM_SCRIPTS = ['main', 'melee', 'loco_states', 'weapons', 'transitions']


def staff_forms():
    forms = [(n, f) for n, k, f in blocks(ROOT / 'source_data/tod_staff.gdt') if n.startswith('tod_staff_')]
    twins = [(n, f) for n, k, f in blocks(ROOT / 'source_data/tod_weapon_twins.gdt') if n.startswith('tod_staff_')]
    assert len(forms) == 3, ('expected 3 source staffs', [n for n, _ in forms])
    assert len(twins) >= 8, ('expected every generated staff twin', [n for n, _ in twins])
    return forms + twins


def check_forms(forms):
    for element, b in STAFF_BINDINGS.items():
        assert b['playerAnimType'] == STAFF_PLAYER_ANIM_TYPE and b['worldModelTagRight'] == STAFF_WORLD_MOUNT
    assert POSE_MOUNT.get(STAFF_PLAYER_ANIM_TYPE) == STAFF_WORLD_MOUNT, \
        ('pose/mount pair broken in staff_presentation_bindings.py', STAFF_PLAYER_ANIM_TYPE, STAFF_WORLD_MOUNT)
    for name, f in forms:
        pose = f.get('playerAnimType')
        assert pose == STAFF_PLAYER_ANIM_TYPE, (name, 'playerAnimType', pose, 'regenerate: gen_tod_twins.js')
        assert f.get('worldModelTagRight') == f.get('worldModelTagLeft') == POSE_MOUNT[pose], \
            (name, pose + ' needs the ' + POSE_MOUNT[pose] + ' mount', f.get('worldModelTagRight'), f.get('worldModelTagLeft'))
    return len(forms)


def lines(path):
    return {l.strip().lower() for l in path.read_text(encoding='latin1').splitlines()}


def check_stock(tools):
    assetlists = tools / 'zone_source/all/assetlist'
    zm_common, core_common = lines(assetlists / 'zm_common.csv'), lines(assetlists / 'core_common.csv')
    missing = [c for c in CLIPS if 'xanim,' + c not in zm_common]
    assert not missing, ('zm_common no longer carries these staff player clips', missing)
    scripts = [s for s in PLAYERANIM_SCRIPTS if 'rawfile,gamedata/playeranim/playeranim_%s.script' % s not in core_common]
    assert not scripts, ('core_common is missing playeranim scripts', scripts)
    types = [l.strip() for l in (tools / 'share/raw/gamedata/playeranim/playeranimtypes.txt').read_text().splitlines()]
    assert STAFF_PLAYER_ANIM_TYPE in types, (STAFF_PLAYER_ANIM_TYPE, 'not a native player anim type')
    awi = (tools / 'deffiles/projectileweapon.awi').read_text(encoding='latin1')
    combo = re.search(r'"playerAnimType",\s*"([^"]+)"', awi)
    assert combo and STAFF_PLAYER_ANIM_TYPE in [x.strip() for x in combo[1].split('|')], \
        (STAFF_PLAYER_ANIM_TYPE, 'not offered by projectileweapon.awi')
    return len(CLIPS)


def check_no_shadow(texts):
    """texts: {label: content} of every repo GDT and zone/zpkg file."""
    pat = re.compile(r'(?i)(?:"|xanim,)(p[bt]_staff_[a-z0-9_]+)')
    hits = sorted({(label, m[1]) for label, t in texts.items() for m in pat.finditer(t)})
    assert not hits, ('a repo asset shadows a stock staff player clip; zm_common already has it', hits[:5])


def repo_texts():
    paths = list((ROOT / 'source_data').glob('*.gdt')) + list((ROOT / 'zone_source').glob('*.zone')) \
        + list((ROOT / 'zone_source').glob('*.zpkg'))
    return {str(p.relative_to(ROOT)): p.read_text(encoding='latin1') for p in paths}


def main():
    tools = find_tools_root()
    assert tools and (tools / 'zone_source/all/assetlist/zm_common.csv').is_file(), 'Mod Tools root not found'
    n = check_forms(staff_forms())
    c = check_stock(tools)
    check_no_shadow(repo_texts())
    print('staff 3p OK: %d staff forms on %s + %s; %d stock clips resident in zm_common; no repo shadow'
          % (n, STAFF_PLAYER_ANIM_TYPE, STAFF_WORLD_MOUNT, c))


def selftest():
    import copy
    forms = staff_forms()
    tools = find_tools_root()
    cases = []
    bad = copy.deepcopy(forms); bad[4][1]['playerAnimType'] = 'bow'
    cases.append(('one twin left on bow', lambda: check_forms(bad)))
    bad2 = copy.deepcopy(forms); bad2[0][1]['worldModelTagRight'] = 'tag_weapon_left'
    cases.append(('armminigun with the left mount', lambda: check_forms(bad2)))
    bad3 = copy.deepcopy(forms)
    for _, f in bad3: f.update(playerAnimType='bow')
    cases.append(('bow pose on the right mount', lambda: check_forms(bad3)))
    cases.append(('zone shadows a clip', lambda: check_no_shadow({'z': 'xanim,pb_staff_stand_idle\n'})))
    cases.append(('gdt defines a clip', lambda: check_no_shadow({'g': '\t"pt_staff_stand_fire" ( "xanim.gdf" )'})))
    real = lines

    def fake_lines(path):
        out = real(path)
        return out - {'xanim,pt_staff_stand_raise'} if path.name == 'zm_common.csv' else out
    def run_missing():
        globals()['lines'] = fake_lines
        try: check_stock(tools)
        finally: globals()['lines'] = real
    cases.append(('clip missing from zm_common', run_missing))
    failed = 0
    for label, fn in cases:
        try:
            fn(); print('SELFTEST MISSED:', label); failed += 1
        except AssertionError as e:
            print('selftest caught:', label, '->', str(e)[:110])
    check_forms(forms); check_no_shadow(repo_texts()); check_stock(tools)
    print('selftest: %d/%d negative controls caught; real tree passes' % (len(cases) - failed, len(cases)))
    return failed


if __name__ == '__main__':
    if '--selftest' in sys.argv:
        sys.exit(1 if selftest() else 0)
    main()
