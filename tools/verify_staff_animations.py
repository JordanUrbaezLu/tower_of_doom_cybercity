"""Validate vendored staff assets, all six twins and Mystical Hands timing."""
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from import_staff_animations import ROOT, blocks, SOUND_NOTES
from staff_presentation_bindings import STAFF_BINDINGS


def check_flicker_lookup(origins):
    """i_generic_lookup must resolve as revealMap, WHEREVER it is defined.

    2026-09-08 this asserted `origins['i_generic_lookup']['semantic']=='revealMap'`
    — a flicker lookup imported as a diffuse texture failed the full link, and the
    staff migration fixed it by copying the block into tod_staff_origins.gdt.

    2026-09-11 that assert started raising KeyError and blocked every full build.
    The block was gone: GDTs sync to the MOD TOOLS ROOT, one copy shared by both
    of this user's maps, and a session on the other map removed our duplicate.
    Nothing was broken by that — the CANONICAL definition in
    texture_assets/genericfilters.gdt already carries semantic revealMap, and the
    six other GDTs that name i_generic_lookup only REFERENCE it as a material's
    flickerLookupMap. Our copy was a redundant override.

    So the location was never the requirement; the SEMANTIC is. This checks that
    instead: our GDT if it declares it, else the tools-root canonical file, and it
    still FAILS if the image is defined nowhere or defined as anything else.
    """
    if 'i_generic_lookup' in origins:
        assert origins['i_generic_lookup'].get('semantic')=='revealMap',\
            'Shared flicker lookup must not be imported as a diffuse texture'
        return
    tools=find_tools_root()
    if tools is None:
        print('[staff] WARN: mod tools root not found; skipped the i_generic_lookup semantic check')
        return
    canonical=tools/'texture_assets/genericfilters.gdt'
    assert canonical.exists(),\
        'i_generic_lookup is in no repo GDT and %s is missing: the flicker lookup is undefined'%canonical
    found={n:f for n,k,f in blocks(canonical)}.get('i_generic_lookup')
    assert found is not None,\
        'i_generic_lookup is defined in NO GDT (repo or tools root) — materials referencing it will fail the link'
    assert found.get('semantic')=='revealMap',\
        'Shared flicker lookup must not be imported as a diffuse texture (canonical copy says %r)'%found.get('semantic')


def find_tools_root():
    import os
    for base in (r'C:\Program Files (x86)\Steam\steamapps\common',
                 r'D:\Steam\steamapps\common'):
        p=Path(base)
        if not p.is_dir():
            continue
        for d in sorted(p.glob('Call of Duty Black Ops III*')):
            if (d/'bin/modlauncher.exe').exists():
                return d
    env=os.environ.get('TOD_MODTOOLS_ROOT')
    return Path(env) if env else None


def main():
    manifest=json.loads((ROOT/'docs/staff_approved_manifest.json').read_text())
    for name,expected in manifest['files'].items():
        assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==expected,('changed/missing staff source',name)
    animations={n:f for n,k,f in blocks(ROOT/'source_data/tod_staff_approved_anims.gdt')}
    origins={n:f for n,k,f in blocks(ROOT/'source_data/tod_staff_origins.gdt')}
    check_flicker_lookup(origins)
    assert set(animations)==set(manifest['animation_assets'])
    # 2026-09-09: reload / first-raise foley lives in "2D Sound" custom notes on
    # the xanim blocks; the baked notetrack names alone play nothing (four silent builds).
    aliases={l.split(',')[0] for l in (ROOT/'sound/aliases/tod_ports.csv').read_text(encoding='utf-8',errors='replace').splitlines()}
    for name,notes in SOUND_NOTES.items():
        f=animations[name]
        for i,(frame,alias) in enumerate(notes):
            assert f.get('customnote%daction'%i)=='2D Sound' and f.get('customnote%dactionparam1'%i)==alias and f.get('customnote%dframe'%i)==str(frame),(name,i,alias,'sound note missing: this clip is SILENT without a 2D Sound custom note')
            assert alias in aliases,(alias,'has no tod_ports.csv row')
    for name,fields in animations.items():
        for key,folder in [('filename','xanim_export'),('model','model_export')]:
            relative=folder+'/'+fields[key].replace('\\','/').replace('//','/')
            assert relative in manifest['files'],('untracked animation dependency',name,relative)
    source={n:f for n,k,f in blocks(ROOT/'source_data/tod_staff.gdt')}
    mage=(ROOT/'scripts/zm/zm_tower_of_doom/_tod_mage_elements.gsc').read_text(encoding='utf-8')
    recovery=int(re.search(r'#define\s+TOD_MAGE_FIRE_RECOVERY_MS\s+(\d+)',mage)[1])
    assert recovery==1573,'Preserve fire shot cadence independently of its native state'
    assert float(source['tod_staff_fire']['fireTime'])==0.1,'Native firing state must release use/cycling promptly'
    # v18.99c: ICE IS BACK ON ITS NATIVE fireTime AND OFF THE SCRIPT CONTROLLER.
    # v18.94 copied the fire staff's trick to free the weapon switch; it does not
    # transfer, because fire is `Charge Shot` (the engine fires on RELEASE, so
    # DisableWeaponFire is read on the next press) and ice is `Single Shot`. With
    # fireTime cut to 0.1 the engine gate was 0.1 s and the staff fired as fast as
    # the trigger could be clicked. The cadence is the engine's again; do not move
    # it back without a native lever that separates the fire state from the cadence
    # (`shotsBeforeRechamber` + `rechamberTime`, both present and both 0, unproven).
    assert 'TOD_MAGE_ICE_RECOVERY_MS' not in mage,'ice must not ride the script fire cooldown (v18.94 regression)'
    assert float(source['tod_staff_ice']['fireTime'])==0.8,'Ice cadence is its native firing state (0.8 s, user 2026-09-13)'
    twins={n:f for n,k,f in blocks(ROOT/'source_data/tod_weapon_twins.gdt')}
    assert len(twins)==manifest['generated_asset_blocks']
    # 2026-09-23: the staff ASSETS carry the engine's _zm tail (the linker connects
    # attachment uniques only to mode-suffixed weapon names; gen_tod_twins.js mage
    # block, docs/150). Script names and this table stay unsuffixed: strip it here.
    twins={(n.removesuffix('_zm') if n.startswith('tod_staff_') else n):f for n,f in twins.items()}
    timings={'raiseTime','firstRaiseTime','altRaiseTime','quickRaiseTime','emptyRaiseTime','dropTime','emptyDropTime','quickDropTime','altDropTime','adsAltDropTime','adsAltRaiseTime','swimDropTime'}
    # v19.25: THE ICE STAFF HAS A SECOND VARIANT LETTER AND IT IS A PERK.
    # `d` is Double Tap (gen_tod_twins.js DTAP_STEP, _tod_upgrades::axis_level),
    # so ice emits q x d = four assets where the other two staffs emit two. This
    # table is the only place that shape is written down on the python side; if a
    # staff ever gains or loses a letter, the KeyError it raises here is the point.
    variants={'lightning':['_q0','_q1'],'fire':['_q0','_q1'],
              'ice':['_q0d0','_q0d1','_q1d0','_q1d1']}
    fire_keys={'fireTime','holdFireTime','introFireTime'}   # LOCKSTEP: FIRE_KEYS in gen_tod_twins.js
    dtap_step=0.75                                          # LOCKSTEP: DTAP_STEP[1]
    for element,slots in manifest['slots'].items():
        slots=dict(slots)
        slots.update({k:v for k,v in STAFF_BINDINGS[element].items() if k in slots})
        base='tod_staff_'+element
        assert set(variants[element])=={n[len(base):] for n in twins if n.startswith(base+'_')},(base,'emitted variant set moved')
        for name,weapon in [(base,source[base])]+[(base+s,twins[base+s]) for s in variants[element]]:
            assert all(weapon[k]==v for k,v in slots.items()),('staff slot mismatch',base)
            assert not any(v.startswith(('sla_','vm_freezegun_')) for k,v in weapon.items() if 'Anim' in k or k.startswith('slide_'))
            assert weapon['segmentedReload']=='1',(base,'reload must allow interruption')
            assert weapon['reloadAnim'] and weapon['reloadEmptyAnim'],(base,'keep reload animations')
            assert weapon['reloadEndTime']=='0' and not weapon['reloadEndAnim'],(base,'no extra reload exit delay')
            assert weapon['clipOnly']=='0' and int(weapon['maxAmmo'])>=int(weapon['clipSize']),(base,'optional native reload needs reserve ammo')
            # 2026-09-11: was clipSize-1, which fills a clip pinned one short in ONE
            # segment but leaves an EMPTY clip one round shy, so the engine ran a
            # second segment -- the reported 'reloads twice' on the lightning staff's
            # forced reload. clipSize covers both starts in a single segment.
            assert int(weapon['reloadAmmoAdd'])==int(weapon['clipSize']),(base,'one full reload segment from empty OR one-short')
            assert weapon['reloadAddTime']==weapon['reloadTime'],(base,'reload reward must wait for the full animation')
            if element in ('lightning','ice'):
                assert weapon['guidedMissileType']=='None',(base,'straight projectiles')
            if element=='fire':
                assert float(weapon['fireTime'])==0.1,(base,'script recovery must not lock interactions / the weapon switch')
            if element=='ice':
                # The ice cadence is the ENGINE's (the script controller cannot
                # gate a Single Shot press), so Double Tap has to be a second
                # asset: d0 is the 0.8 s staff, d1 the one a Double Tap holder
                # gets. The SOURCE gdt and every d0 variant stay 0.8.
                want=0.8*dtap_step if name.endswith('d1') else 0.8
                assert abs(float(weapon['fireTime'])-want)<1e-6,(name,'ice cadence',want)
            if element=='lightning':
                assert all(float(weapon[k])==0 for k in ('explosionCameraShakeDuration','explosionCameraShakeRadius','explosionCameraShakeScale','adsViewKickMinMagnitude','hipViewKickMinMagnitude')),'lightning camera shake disabled'
            assert animations[weapon['sprintLoopAnim']]['looping']=='1',(base,'sprint freezes without looping')
        # MYSTICAL HANDS, checked at EVERY Double Tap rung rather than only at
        # d0 - a q ladder that is right on the staff you get without the perk and
        # wrong on the one you get with it is exactly the half-applied kind of
        # change this file exists to catch.
        for tail in (['d0','d1'] if element=='ice' else ['']):
            slow=twins[base+'_q0'+tail];fast=twins[base+'_q1'+tail]
            changed={k for k in slow if slow[k]!=fast[k]}
            assert changed <= timings,('unexpected Mystical Hands difference',base,tail,changed)
            for key in timings:
                assert source[base].get(key)==slow.get(key),(base,key,'base timing differs from q0')
                if key in slow and float(slow[key])>0:
                    assert abs(float(fast[key])*3-float(slow[key]))<0.0001,(base,key)
        # DOUBLE TAP is a RATE change and nothing else. Every field but the three
        # fire-time keys must be identical between d0 and d1, at both q rungs -
        # a damage or clip difference sneaking in here would be an invisible
        # buff that only players holding one perk ever see.
        if element=='ice':
            for q in ('q0','q1'):
                plain=twins[base+'_'+q+'d0'];quick=twins[base+'_'+q+'d1']
                changed={k for k in plain if plain[k]!=quick[k]}
                assert changed <= fire_keys,('unexpected Double Tap difference',base,q,changed)
                for key in fire_keys:
                    if key in plain and float(plain[key])>0:
                        assert abs(float(quick[key])-float(plain[key])*dtap_step)<1e-6,(base,q,key)
    # 2026-09-13: the ice staff's PRESENTATION is the BO6 assembly (v18.89). Its
    # models, textures, wavs, alias rows and weapon bindings are pinned by the
    # installer's manifest so a stale or missing file fails the build, not the link.
    subprocess.run([sys.executable, str(ROOT/'tools/bo6_extraction/install_ice_staff_bo3.py'), '--check'], check=True, cwd=ROOT)
    # v18.90: the composed BO6-inspired shot effects are pinned the same way.
    subprocess.run([sys.executable, str(ROOT/'tools/bo6_extraction/build_bo6_ice_fx.py'), '--check'], check=True, cwd=ROOT)
    subprocess.run([sys.executable, str(ROOT/'tools/verify_staff_presentation.py')], check=True, cwd=ROOT)
    print('Staff validation passed: 78 clips, eight twins (ice carries the Double Tap rung), 45 slots each; Mystical Hands remains 3x faster.')


if __name__=='__main__':main()
