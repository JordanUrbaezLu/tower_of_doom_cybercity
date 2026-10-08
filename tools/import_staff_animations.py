"""Vendor the approved test-map staff clips; change only Tower animation slots.

Run after the test generator/audit. The resulting Tower build is self-contained.
No test weapons, ammo values, scripts, or registrations are imported.
"""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
from staff_presentation_bindings import STAFF_BINDINGS

ROOT = Path(__file__).resolve().parents[1]
TEST = ROOT.parent / 'test+map'


def blocks(path):
    return [(m[1],m[2],dict(re.findall(r'"([^"\n]+)"\s*"([^"\n]*)"',m[3])))
            for m in re.finditer(r'"([^"\n]+)"\s*\(\s*"([^"\n]+)"\s*\)\s*\{([^}]+)\}',path.read_text(encoding='latin1'))]


def emit(name,kind,fields):
    return '\t"'+name+'" ( "'+kind+'" )\n\t{\n'+''.join('\t\t"'+k+'" "'+v+'"\n' for k,v in fields.items())+'\t}\n'


# [tod 2026-09-09] SOUND NOTES -- THE FIX FOUR BUILDS MISSED. In BO3 a viewmodel
# clip's sounds are the "2D Sound" custom notes in its xanim GDT block (see
# night_t5_thundergun.gdt: action / actionparam1 = alias / frame). The note
# names baked inside the XANIM_BIN (wpn_staff_reload_1..4 at frames 14/29/43/59,
# wpn_*staff_1straise at frame 1) are INERT on their own: the linker packs them,
# the animation plays them, and nothing is heard. Every clip imported from the
# test map arrived with customnote0action=None, so the staffs reloaded in
# silence while the aliases, wavs, context columns and notetracks all checked
# out. Frames below are the baked note frames; verify_staff_animations.py
# gates every build on these notes being present and their aliases existing.
SOUND_NOTES={
    'tod_vm_staff_lightning_fit_t7_reload_elec':[(14,'wpn_staff_reload_1'),(29,'wpn_staff_reload_2'),(43,'wpn_staff_reload_3'),(59,'wpn_staff_reload_4')],
    'tod_vm_staff_fire_fit_t7_reload_fire':[(14,'wpn_staff_reload_1'),(29,'wpn_staff_reload_2'),(43,'wpn_staff_reload_3'),(59,'wpn_staff_reload_4')],
    # [tod 2026-09-13] BO6 ICE STAFF: its reload / first raise are single authored clips
    # (BO6 cues them once at frame 0), so the ice staff plays ONE note each instead of
    # the four Winter's Howl beats. See tools/bo6_extraction/install_ice_staff_bo3.py.
    'tod_vm_staff_ice_fit_t7_reload_ice':[(1,'wpn_tod_bo6_ice_reload')],
    'tod_vm_staff_lightning_fit_t7_lightning_first_raise':[(1,'wpn_lightningstaff_1straise')],
    'tod_vm_staff_fire_fit_t7_fire_first_raise':[(1,'wpn_firestaff_1straise')],
    'tod_vm_staff_ice_fit_t7_water_first_raise':[(1,'wpn_tod_bo6_ice_first_raise')],
}


def apply_sound_notes(name,fields):
    notes=SOUND_NOTES.get(name)
    if not notes:
        return fields
    out={k:v for k,v in fields.items() if not re.match(r'customnote\d+',k)}
    for i,(frame,alias) in enumerate(notes):
        out['customnote%daction'%i]='2D Sound'
        out['customnote%dactionparam1'%i]=alias
        out['customnote%dactionparam2'%i]=''
        out['customnote%dframe'%i]=str(frame)
        out['customnote%duseexistingnote'%i]=''
    return dict(sorted(out.items()))


def reapply_sound_notes():
    """Re-stamp the notes onto the vendored GDT without re-importing (python import_staff_animations.py --notes-only)."""
    path=ROOT/'source_data/tod_staff_approved_anims.gdt'
    out=[(n,k,apply_sound_notes(n,f)) for n,k,f in blocks(path)]
    path.write_text('{\n'+''.join(emit(*e) for e in out)+'}\n')
    print('sound notes re-applied to',sum(1 for n,_,_ in out if n in SOUND_NOTES),'clips')


def main():
    # Current source audit must include the fire-tip stabilization gate.
    subprocess.run(['python',str(TEST/'tools/audit_staff_elements.py')],check=True,cwd=TEST)
    entries={n:(k,f) for file in ['sla_staff_animtest.gdt','sla_staff_element_tests.gdt']
             for n,k,f in blocks(TEST/'source_data'/file)}
    slots=json.loads((TEST/'docs/staff_element_tests_report.json').read_text())['elements']['fire']['slots'].keys()
    selected={'ice':'sla_staff_animb_zm','fire':'sla_staff_animd_zm','lightning':'sla_staff_animf_zm'}
    # Freeze the A controls before Tower itself adopts the new animations.
    # Otherwise regenerating the test later would turn both A and B into B.
    controls={e:entries[n][1] for e,n in {'ice':'sla_staff_anima_zm','fire':'sla_staff_animc_zm','lightning':'sla_staff_anime_zm'}.items()}
    (TEST/'docs/staff_tower_original_reference.json').write_text(json.dumps(controls,indent=2)+'\n')
    mapping={};anim_names=set()
    for element,weapon in selected.items():
        mapping[element]={slot:entries[weapon][1][slot] for slot in slots}
        anim_names.update(mapping[element].values())
    assert len(slots)==45 and len(anim_names)==78
    output=[];files={};rename={name:'tod_vm_staff_'+name.removeprefix('sla_') for name in anim_names}
    for name in sorted(anim_names):
        kind,fields=entries[name];assert kind=='xanim.gdf'
        fields=dict(fields)
        # A sprint loop must replay for the entire sprint, not hold its last
        # frame after its first cycle. Preserve this on future re-imports.
        if name in {values['sprintLoopAnim'] for values in mapping.values()}:
            fields['looping']='1'
        for field,folder,target_folder in [('filename','xanim_export','tod_staff_approved'),('model','model_export','tod_staff_anim')]:
            relative=Path(fields[field].replace('\\','/'))
            src=TEST/folder/relative
            filename=rename[name]+'.XANIM_BIN' if field=='filename' else 'tod_vm_'+relative.name.removeprefix('sla_')
            dst=ROOT/folder/target_folder/filename
            dst.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(src,dst)
            files[str(dst.relative_to(ROOT)).replace('\\','/')]=hashlib.sha256(dst.read_bytes()).hexdigest()
            fields[field]=target_folder+'\\\\'+filename
        fields=apply_sound_notes(rename[name],fields)
        output.append((rename[name],kind,fields))
    (ROOT/'source_data/tod_staff_approved_anims.gdt').write_text('{\n'+''.join(emit(*e) for e in output)+'}\n')
    original=blocks(ROOT/'source_data/tod_staff.gdt')
    before_twins={n:f for n,k,f in blocks(ROOT/'source_data/tod_weapon_twins.gdt')}
    changed=[]
    for name,kind,fields in original:
        element=name.removeprefix('tod_staff_')
        assert element in mapping,name
        replacement=dict(fields)
        replacement.update({slot:rename[asset] for slot,asset in mapping[element].items()})
        replacement.update(STAFF_BINDINGS[element])
        assert {k:v for k,v in fields.items() if k not in slots}=={k:v for k,v in replacement.items() if k not in slots}
        changed.append((name,kind,replacement))
    (ROOT/'source_data/tod_staff.gdt').write_text('{\n'+''.join(emit(*e) for e in changed)+'}\n',encoding='latin1')
    subprocess.run(['node','tools/gen_tod_twins.js'],cwd=ROOT,check=True)
    after_twins={n:f for n,k,f in blocks(ROOT/'source_data/tod_weapon_twins.gdt')}
    assert before_twins.keys()==after_twins.keys(),'weapon registrations changed'
    for name,old in before_twins.items():
        new=after_twins[name]
        omit=set(slots) if name.startswith('tod_staff_') else set()
        assert {k:v for k,v in old.items() if k not in omit}=={k:v for k,v in new.items() if k not in omit},('non-animation change',name)
    manifest={'files':files,'animation_assets':sorted(rename.values()),
              'slots':{element:{s:rename[a] for s,a in values.items()} for element,values in mapping.items()},
              'generated_asset_blocks':len(after_twins),'only_animation_fields_changed':True}
    (ROOT/'docs/staff_approved_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('Imported 78 animations / 45 slots per staff. All weapon names and non-animation fields preserved.')


if __name__=='__main__':(reapply_sound_notes if '--notes-only' in sys.argv else main)()
