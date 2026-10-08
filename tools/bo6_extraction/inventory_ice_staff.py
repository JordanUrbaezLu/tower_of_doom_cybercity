"""Inventory BO6 Ice Staff source banks and their recursive secondary aliases.

Adapted from Tower of Doom II's BO6 migration workflow. Hash matches establish
names; duration or ordering never establishes an event's meaning. This does not
export assets, alter Saluki, install sounds, or claim native playback.
"""
import argparse
import array
from collections import defaultdict
import hashlib
import itertools
import json
from pathlib import Path
import re
import wave

REPO = Path(__file__).resolve().parents[2]
BANKS = ('weapon_t10_zm_ice_staff_plr.all.json',
         'weapon_t10_zm_ice_staff_npc.all.json')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fnv1a(name):
    value = 0xcbf29ce484222325
    for char in name.lower().encode('ascii'):
        value = ((value ^ char) * 0x100000001b3) & 0xffffffffffffffff
    return f'{value:x}'


def inspect_wav(path):
    with wave.open(str(path),'rb') as wav:
        assert wav.getcomptype()=='NONE' and wav.getsampwidth()==2, path
        assert wav.getnchannels() in (1,2) and wav.getframerate()==48000, path
        raw=wav.readframes(wav.getnframes())
        assert len(raw)==wav.getnframes()*wav.getnchannels()*2, path
        samples=array.array('h',raw)
        peak=max(map(abs,samples),default=0)
        assert peak>0, path
        return dict(channels=wav.getnchannels(),sample_rate=wav.getframerate(),
                    frames=wav.getnframes(),seconds=wav.getnframes()/wav.getframerate(),
                    peak=peak/32768,listened_in_bo3=False)


def resolve_names(unknown):
    prefixes = ('wpn_ice_staff', 'wpn_staff_ice', 'fly_ice_staff',
                'prj_ice_staff', 'prj_staff_ice', 'wpn_zm_ice_staff',
                'wpn_zmb_staff_ice', 'wpn_staff', 'prj_staff',
                'wpn_zm_staff_ice', 'wpn_zmb_ice_staff', 'fly_staff_ice')
    events = ('fire', 'fire_loop', 'fire_start', 'fire_stop', 'fire_tail',
              'shot', 'charge', 'charge_in', 'charge_out', 'charge_loop',
              'charge_start', 'charge_stop', 'charge_end', 'charge_full',
              'charge_ready', 'charged', 'charged_fire', 'charged_loop',
              'idle', 'idle_loop', 'loop', 'flight', 'flight_loop', 'fly',
              'flyby', 'impact', 'imp', 'explode', 'explosion', 'tail',
              'storm', 'storm_loop', 'vortex', 'vortex_loop', 'freeze',
              'freeze_loop', 'shatter', 'melee', 'melee_hit', 'melee_miss',
              'reload', 'reload_start', 'reload_end', 'reload_in',
              'reload_out', 'pullout', 'pullout_quick', 'putaway',
              'putaway_quick', 'inspect', 'alt_inspect', 'alt_switch_in',
              'alt_switch_out', 'alt_fire', 'alt_impact', 'alt_explode',
              'empty', 'dryfire', 'revive', 'heal', 'raise', 'first_raise')
    forms = ('', 'base', 'alt', 'altmode', 'pap', 'upg', 'upgraded', 'charged')
    suffixes = ('', 'plr', 'npc', 'lfe', 'plr_lfe', 'npc_lfe', 'dist',
                'distant', 'close', 'plr_tail', 'npc_tail', 'plr_claw_close',
                'plr_claw_open', 'npc_claw_close', 'npc_claw_open', 'plr_loop',
                'npc_loop', 'plr_dist', 'npc_dist', 'left', 'right')
    found = {}
    for prefix, event, form, suffix in itertools.product(prefixes, events, forms, suffixes):
        for parts in ((prefix, form, event, suffix), (prefix, event, form, suffix)):
            name = '_'.join(p for p in parts if p)
            key = fnv1a(name)
            if key in unknown:
                assert key not in found or found[key] == name, (key, name)
                found[key] = name
    return found


def inventory(root):
    bank_dir = root / 'sndbanks/json'
    initial = {name: json.loads((bank_dir/name).read_text(encoding='utf-8-sig')) for name in BANKS}
    aliases = defaultdict(list)
    # Secondary aliases may be outside the two weapon banks.
    for path in sorted(bank_dir.glob('*.json')):
        rows = json.loads(path.read_text(encoding='utf-8-sig'))
        if not isinstance(rows, list):
            continue
        for row in rows:
            if isinstance(row, dict) and row.get('alias') and row.get('snd'):
                aliases[row['alias']].append((path.name, row))
    closure = [(bank, row) for bank, rows in initial.items() for row in rows]
    seen = {(bank, json.dumps(row, sort_keys=True)) for bank, row in closure}
    # Weapon banks do not cover every authored handling event. The first-raise
    # cues resolve in merged_global_stream_mp, discovered during the re-audit.
    # Pin the animation inventory to its actual Cast bytes before using cues.
    animation_audio_seeds = set()
    animations = json.loads((REPO/'docs/bo6_ports/manifests/ice_staff_animation_casts.json').read_text(encoding='utf-8'))
    for source in animations['files']:
        assert digest(Path(source['path'])) == source['sha256'], source['path']
        for clip in source['animations']:
            for note in clip['notifications']:
                if note['name'].startswith('Audio') and not note['name'].endswith('@End'):
                    alias = note['name'].split('@')[1]
                    animation_audio_seeds.add(alias)
                    if alias.endswith('_plr'): animation_audio_seeds.add(alias[:-4]+'_npc')
    missing_animation_audio_aliases = []
    for alias in sorted(animation_audio_seeds):
        matches = aliases.get(alias, []) + aliases.get(fnv1a(alias), [])
        if not matches: missing_animation_audio_aliases.append(alias)
        for bank, row in matches:
            key = (bank, json.dumps(row, sort_keys=True))
            if key not in seen:
                seen.add(key)
                closure.append((bank, row))
    missing_secondary = set()
    for bank, row in closure:
        secondary = row.get('alias2')
        if not secondary:
            continue
        if secondary not in aliases:
            missing_secondary.add(secondary)
        for other_bank, child in aliases.get(secondary, []):
            key = (other_bank, json.dumps(child, sort_keys=True))
            if key not in seen:
                seen.add(key)
                closure.append((other_bank, child))
    unknown = {row['alias'] for _, row in closure if re.fullmatch('[0-9a-f]+', row['alias'])}
    names = resolve_names(unknown)
    sounds = {}
    for bank, row in closure:
        name = row['snd']
        relative = Path(name + '.wav')
        assert not relative.is_absolute() and '..' not in relative.parts, name
        sound = sounds.setdefault(name, dict(source_banks=set(), aliases=set(), secondary_aliases=set()))
        sound['source_banks'].add(bank)
        sound['aliases'].add(row['alias'])
        if row.get('alias2'):
            sound['secondary_aliases'].add(row['alias2'])
    for name, entry in sounds.items():
        for key in ('source_banks', 'aliases', 'secondary_aliases'):
            entry[key] = sorted(entry[key])
        path = root/'sounds'/(name + '.wav')
        entry['payload'] = str(path)
        entry['payload_exists'] = path.is_file()
        entry['payload_sha256'] = digest(path) if path.is_file() else None
        entry['wav'] = inspect_wav(path) if path.is_file() else None
        entry['resolved_aliases'] = [names.get(a, a) for a in entry['aliases']]
    bank_names = sorted({bank for bank, _ in closure})
    return dict(source_root=str(root), bank_sha256={b:digest(bank_dir/b) for b in bank_names},
                direct_rows=sum(map(len, initial.values())), closure_rows=len(closure),
                recovered_names=names, unresolved_aliases=sorted(unknown-set(names)),
                missing_secondary_aliases=sorted(missing_secondary),
                animation_audio_seeds=sorted(animation_audio_seeds),
                missing_animation_audio_aliases=missing_animation_audio_aliases,
                sounds=dict(sorted(sounds.items())),
                source_casts=[dict(path=str(p), sha256=digest(p))
                              for folder in ('models', 'animations')
                              for p in sorted((root/folder).rglob('*staff*.cast'))
                              if p.name.startswith(('t10_vm_ww_staff','wpn_t10_vm_ww_zmb_staffs','wpn_t10_wm_ww_zmb_staffs',
                                                    'att_t10_vm_ww_zmb_staffs_water_tip','att_t10_wm_ww_zmb_staffs_water_tip'))],
                native_verified=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--export-root', type=Path,
                        default=Path.home()/'Downloads/BO6_Pilot_Export/bo6')
    parser.add_argument('--output', type=Path,
                        default=REPO/'docs/bo6_ports/manifests/ice_staff_sources.json')
    args = parser.parse_args()
    report = inventory(args.export_root)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(dict(report=str(args.output), direct_rows=report['direct_rows'],
                          closure_rows=report['closure_rows'], sounds=len(report['sounds']),
                          exported=sum(s['payload_exists'] for s in report['sounds'].values()),
                          recovered_names=report['recovered_names'],
                          unresolved_aliases=len(report['unresolved_aliases']),
                          missing_secondary_aliases=report['missing_secondary_aliases'],
                          casts=len(report['source_casts'])), indent=2))


if __name__ == '__main__':
    main()
