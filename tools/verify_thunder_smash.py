"""Offline animation, grip and asset closure checks; does not claim native playback."""
import hashlib
import json
import math
from pathlib import Path
from build_thunder_smash import ROOT, xa, pose, relative
from import_staff_animations import blocks
from verify_weapon_attachments import declarations

declarations()

report=json.loads((ROOT/'docs/thunder_smash_manifest.json').read_text())
for name,want in report['files'].items():
    assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==want,name
for name,want in report['sources'].items():
    p=Path(name)
    if p.is_file(): assert hashlib.sha256(p.read_bytes()).hexdigest()==want,name
anim=xa.Anim();anim.LoadFile_Bin(str(ROOT/'xanim_export/tod_thunder_smash/tod_thunder_smash_cast.XANIM_BIN'))
assert len(anim.frames)==63 and anim.framerate==30
names=[p.name for p in anim.parts];wi=names.index('j_wrist_ri');ti=names.index('tag_weapon')
def flat(p): return [*p[0],*(x for row in p[1] for x in row)]
grip=flat(relative(pose(anim.frames[0].parts[ti]),pose(anim.frames[0].parts[wi])))
worst=0
for frame in anim.frames:
    g=flat(relative(pose(frame.parts[ti]),pose(frame.parts[wi])))
    worst=max(worst,max(abs(a-b) for a,b in zip(grip,g)))
    for part in frame.parts:
        assert all(math.isfinite(v) for v in [*part.offset,*(x for row in part.matrix for x in row)])
assert worst<0.002,('hammer drifted from wrist',worst)
assets={n:(k,f) for n,k,f in blocks(ROOT/'source_data/tod_thunder_smash.gdt')}
twins={n:f for n,k,f in blocks(ROOT/'source_data/tod_weapon_twins.gdt') if n.startswith('leviathan_') and k=='bulletweapon.gdf'}
assert len(twins)==13
for n,f in twins.items():
    # Native appends _<attachment> to the FULL base; it does not prepend au_.
    # Existence in the zone alone missed this live failure on the first build.
    assert f['attachmentUnique']+'_none' in assets,(n,'unresolved neutral attachment base')
    assert f['attachmentUnique']+'_gmod7' in assets,(n,'unresolved cast attachment base')
    for au in ('none','gmod7'):
        fields=assets['au_tod_thunder_smash_'+au][1]
        for key,value in f.items():
            if key.startswith('loc') and key[3:4].isupper():assert fields[key]==value,(n,key)
        assert fields['maxDamageRange']==fields['minDamageRange']=='0'
assert 'firstRaiseAnim' not in assets['au_tod_thunder_smash_none'][1]
assert assets['au_tod_thunder_smash_gmod7'][1]['firstRaiseAnim']=='tod_thunder_smash_cast'
assert float(assets['au_tod_thunder_smash_gmod7'][1]['firstRaiseTime'])*1000==report['animation_ms']
zone=(ROOT/'zone_source/zm_tower_of_doom.zone').read_text()
for line in ('attachment,gmod7','attachmentunique,au_tod_thunder_smash_none','attachmentunique,au_tod_thunder_smash_gmod7','xanim,tod_thunder_smash_cast','fx,dlc1/zmb_weapon/fx_wpn_spike_grnd_hit','fx,electric/fx_elec_burst_lg_z270_os'):
    assert sum(s.strip()==line for s in zone.splitlines())==1,line
gsc=(ROOT/'scripts/zm/zm_tower_of_doom/_tod_thunder_smash.gsc').read_text()
assert '#define TOD_SMASH_IMPACT_MS '+str(report['impact_ms']) in gsc
assert '#define TOD_SMASH_ANIMATION_MS '+str(report['animation_ms']) in gsc
print(f'Thunder Smash assets: 63 finite frames, wrist grip error {worst:.6f}, 13 existing hammer forms, neutral damage fields, complete zone. Native playback pending.')
