"""Adapt the installed bat lunge to Stormbreaker's existing grip; no new weapons.

Generation uses PyCoD/export2bin. Ordinary builds use the vendored outputs.
"""
import copy
import hashlib
import json
import math
from pathlib import Path
import subprocess
from build_staff_presentation import xm, xa, ROOT, TOOLS, pose, compose, relative, fp, basis
from import_staff_animations import blocks, emit

OUT = ROOT/'tmp/thunder_smash_20260921'
ANIMS = ROOT/'xanim_export/tod_thunder_smash'
MODELS = ROOT/'model_export/tod_thunder_smash'


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def blend(a, b, t):
    # These short entry/recovery blends keep the established hammer idle at
    # both endpoints. Orthonormalize blended rotation rows before conversion.
    if t <= 0: return copy.deepcopy(a)
    if t >= 1: return copy.deepcopy(b)
    matrix=tuple(tuple(x+(y-x)*t for x,y in zip(ar,br)) for ar,br in zip(a.matrix,b.matrix))
    return xa.FramePart(tuple(x+(y-x)*t for x,y in zip(a.offset,b.offset)),basis(matrix))


def main():
    for p in (OUT, ANIMS, MODELS): p.mkdir(parents=True,exist_ok=True)
    bat={n:f for n,k,f in blocks(ROOT/'source_data/tod_baseball_bat.gdt')}
    axe_gdt=TOOLS/'_custom/wetegg/leviathanaxe/leviathanaxe.gdt.acc-balance0709-orig'
    axe={n:f for n,k,f in blocks(axe_gdt)}
    sources={str(axe_gdt):sha(axe_gdt)}
    def read_anim(fields,base):
        path=base/'xanim_export'/fields['filename'].replace('\\','/')
        a=xa.Anim();a.LoadFile_Bin(str(path));sources[str(path.resolve())]=sha(path);return a
    idle=read_anim(axe['vm_leviathan_idle'],TOOLS)
    enter=read_anim(bat['vm_t9_bat_melee_in'],ROOT)
    leave=read_anim(bat['vm_t9_bat_melee_out'],ROOT)
    names=[p.name for p in enter.parts]
    assert names==[p.name for p in leave.parts]
    idx={n:i for i,n in enumerate(names)}
    old={p.name:idle.frames[0].parts[i] for i,p in enumerate(idle.parts)}
    grip=relative(pose(old['tag_weapon']),pose(old['j_wrist_ri']))
    def fitted(frame):
        frame=copy.deepcopy(frame)
        weapon=compose(pose(frame.parts[idx['j_wrist_ri']]),grip)
        original=pose(frame.parts[idx['tag_weapon']])
        for name in ('tag_weapon','tag_weapon_right','tag_charm'):
            if name in idx:
                frame.parts[idx[name]]=fp(compose(weapon,relative(pose(frame.parts[idx[name]]),original)))
        return frame
    enters=[fitted(f) for f in enter.frames]
    leaves=[fitted(f) for f in leave.frames]
    rest=copy.deepcopy(enters[0]);rest.parts=[copy.deepcopy(old.get(n,rest.parts[i])) for i,n in enumerate(names)]
    clip=copy.deepcopy(enter);clip.frames=[];clip.notes=[];clip.framerate=30
    for i in range(6):
        f=copy.deepcopy(rest);f.parts=[blend(a,b,i/5) for a,b in zip(rest.parts,enters[0].parts)];clip.frames.append(f)
    clip.frames.extend(enters)
    clip.frames.extend(copy.deepcopy(enters[-1]) for _ in range(5))
    clip.frames.extend(leaves)
    for i in range(1,8):
        f=copy.deepcopy(rest);f.parts=[blend(a,b,i/7) for a,b in zip(leaves[-1].parts,rest.parts)];clip.frames.append(f)
    assert len(clip.frames)==63
    # Refit the blended frames too: interpolating wrist and weapon separately
    # changes the grip offset even when both endpoints were correct.
    clip.frames=[fitted(f) for f in clip.frames]
    for i,f in enumerate(clip.frames):f.frame=i
    rig_path=ROOT/'model_export'/bat['vm_t9_bat_melee_in']['model'].replace('\\','/')
    sources[str(rig_path.resolve())]=sha(rig_path)
    rig=xm.Model();rig.LoadFile_Bin(str(rig_path))
    # Bind skeleton is identical to the accepted bat donor; no gameplay model
    # or original animation is edited. Runtime still draws Stormbreaker.
    (MODELS/'tod_thunder_smash_rig.XMODEL_BIN').write_bytes(rig_path.read_bytes())
    export=ANIMS/'tod_thunder_smash_cast.XANIM_EXPORT'
    clip.WriteFile_Raw(str(export))
    subprocess.run([str(TOOLS/'bin/export2bin.exe'),'/nt=8','/o=.',export.name],
                   cwd=ANIMS,check=True,capture_output=True)
    binary=export.with_suffix('.XANIM_BIN');assert binary.is_file()
    fields=dict(filename=r'tod_thunder_smash\\tod_thunder_smash_cast.XANIM_BIN',
                model=r'tod_thunder_smash\\tod_thunder_smash_rig.XMODEL_BIN',
                type='relative',useBones='0',looping='0',angleError='0.05',translationError='0.025',
                customnote0action='2D Sound',customnote0actionparam1='tod_bat_swing',customnote0frame='10')
    assets=[('tod_thunder_smash_cast','xanim.gdf',fields)]
    twins={n:f for n,k,f in blocks(ROOT/'source_data/tod_weapon_twins.gdt') if n.startswith('leviathan')}
    first=next(iter(twins.values()))
    loc={k:v for k,v in first.items() if k.startswith('loc') and k[3:4].isupper()}
    assert all(all(f.get(k)==v for k,v in loc.items()) for f in twins.values())
    for cast in (False,True):
        au=dict(configstringFileType='ATTACHMENTUNIQUEFILE',attachmenttype='gmod7' if cast else 'none',
                maxDamageRange='0',minDamageRange='0',**loc)
        if cast:au.update(firstRaiseAnim='tod_thunder_smash_cast',firstRaiseTime='2.1')
        assets.append(('au_tod_thunder_smash_'+('gmod7' if cast else 'none'),'attachmentunique.gdf',au))
    gdt=ROOT/'source_data/tod_thunder_smash.gdt'
    gdt.write_text('{\n'+''.join(emit(*asset) for asset in assets)+'}\n')
    files=[binary,MODELS/'tod_thunder_smash_rig.XMODEL_BIN',gdt]
    report=dict(sources=sources,files={p.relative_to(ROOT).as_posix():sha(p) for p in files},
                frames=63,fps=30,impact_frame=29,impact_ms=967,animation_ms=2100,
                donor_in_frames=len(enters),donor_out_frames=len(leaves),bones=len(rig.bones),
                weapon_registrations_added=0,native_verified=False)
    (ROOT/'docs/thunder_smash_manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Thunder Smash: bat lunge in/out, existing hammer grip, 967ms impact, 2100ms recovery; zero weapon registrations added.')


if __name__=='__main__':main()
