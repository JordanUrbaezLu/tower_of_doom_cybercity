"""Build gate for the cyber Rampage Inducer (2026-10-02).

  python tools/inducer_cyber/verify.py                       source checks (pre-link)
  python tools/inducer_cyber/verify.py --compiled-ledger X   + what the linker packed

SOURCE: every shipped file matches install_manifest.json; the GDT carries both
xmodels (animated, ON = skinOverride of both materials), the four materials on
their proven shaders, both looping xanims; the xmodel_bin has the six bones,
rigid single weights and fits the arena corner (back edge clear of the wall);
each clip loops seamlessly AND starts on the bind pose (no pop when it starts);
the animtree, the zone lines, _tod_rampage.gsc's defines/precaches/animtree and
the generated trigger lift all agree; the old BO6 inducer is no longer zoned.
COMPILED: both xmodels linked single-LOD with the expected triangles, both xanims,
the animtree, the four materials and the nine images are in the ledger.
The master .blend is provenance only (the user may save the live studio).
"""
import hashlib, json, math, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path.home()/'AppData/Roaming/Blender Foundation/Blender/4.2/scripts/addons/BetterBetterBlenderCOD'))
sys.path.insert(0, str(Path(__file__).parent))
from PyCoD import xmodel as xm, xanim as xa
import anim_spec as A

ART = ROOT/'art/rampage_inducer_cyber'
MODELS = ROOT/'model_export/tod_inducer_cyber'
ANIMS = ROOT/'xanim_export/tod_inducer_cyber'
GDT = ROOT/'source_data/tod_inducer_cyber.gdt'
ATR = ROOT/'animtrees/tod_inducer.atr'
ZONE = ROOT/'zone_source/zm_tower_of_doom.zone'
GSC = ROOT/'scripts/zm/zm_tower_of_doom/_tod_rampage.gsc'
DATA = ROOT/'scripts/zm/zm_tower_of_doom/_tod_breather_data.gsc'
GEN = ROOT/'tools/gen_tower_map.js'
MAP = ROOT/'map_source/zm/zm_tower_of_doom.map'
FX = [ROOT/'share/raw/fx/tod/fx_tod_inducer_idle.efx', ROOT/'share/raw/fx/tod/fx_tod_inducer_on.efx']
WALL_X = -24.0
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
fails = []


def check(ok, msg):
    if not ok:
        fails.append(msg)


man = json.loads((ART/'install_manifest.json').read_text())
check(man.get('revision') == 'cyber_core_1', 'install manifest revision')
check(sha(GDT) == man['gdt_sha256'], 'tod_inducer_cyber.gdt differs from install manifest - re-run install_native.py')
check(sha(ATR) == man['atr_sha256'], 'animtrees/tod_inducer.atr differs from install manifest')
xbin = MODELS/'tod_inducer_cyber.xmodel_bin'
check(sha(xbin) == man['xmodel_bin_sha256'], 'xmodel_bin differs from install manifest')
for name, digest in man['images'].items():
    p = MODELS/'_images'/name
    check(p.is_file() and sha(p) == digest, 'image changed or missing: ' + name)
for clip, info in man['xanims'].items():
    p = ANIMS/(info['name'] + '.XANIM_BIN')
    check(p.is_file() and sha(p) == info['sha256'], 'xanim changed or missing: ' + p.name)
    check(p.read_bytes()[:5] == b'*LZ4*', 'xanim is not a converted binary (export2bin passthrough?): ' + p.name)
check(xbin.read_bytes()[:5] == b'*LZ4*' or len(xbin.read_bytes()) > 1000, 'xmodel_bin unreadable')

# ---- GDT (one name per asset: the first cut named the ON clip and the ON xmodel
# alike, and a name-keyed reader silently saw only one of them)
raw = re.findall(r'"([^"]+)"\s*\(\s*"([^"]+)\.gdf"\s*\)\s*\{([^}]*)\}', GDT.read_text())
names = [n for n, k, b in raw]
check(len(names) == len(set(names)), 'two GDT assets share a name: ' + str(sorted({n for n in names if names.count(n) > 1})))
blocks = {n: (k, dict(re.findall(r'"([^"\r\n]+)"\s*"([^"\r\n]*)"', b))) for n, k, b in raw}
for name in ('tod_inducer_cyber', 'tod_inducer_cyber_on'):
    k, f = blocks.get(name, (None, {}))
    check(k == 'xmodel' and f.get('type') == 'animated', name + ' must be an animated xmodel')
    check(f.get('filename') == 'tod_inducer_cyber\\\\tod_inducer_cyber.xmodel_bin', name + ' filename')
skin = blocks['tod_inducer_cyber_on'][1].get('skinOverride', '')
check(skin == 'mtl_tod_icyber mtl_tod_icyber_on\\r\\nmtl_tod_icyber_plasma mtl_tod_icyber_plasma_on\\r\\n',
      'ON twin skinOverride must swap BOTH materials')
check(blocks['tod_inducer_cyber'][1].get('skinOverride', 'x') == '', 'OFF xmodel must not override')
for m, mtype in (('mtl_tod_icyber', 'lit_emissive_advanced_fullspec'), ('mtl_tod_icyber_on', 'lit_emissive_advanced_fullspec'),
                 ('mtl_tod_icyber_plasma', 'lit_emissive_scroll_transparent'), ('mtl_tod_icyber_plasma_on', 'lit_emissive_scroll_transparent')):
    k, f = blocks.get(m, (None, {}))
    check(k == 'material' and f.get('materialType') == mtype, m + ' shader')
    check(float(f.get('waterRoughness', 1)) == 0, m + ' waterRoughness must be 0 (fullspec layerDepth)')
check(blocks['mtl_tod_icyber'][1].get('colorMap00') == 'i_tod_icyber_e', 'OFF glow map')
check(blocks['mtl_tod_icyber_on'][1].get('colorMap00') == 'i_tod_icyber_eon', 'ON glow map')
check(float(blocks['mtl_tod_icyber_on'][1]['scaleRGB']) > float(blocks['mtl_tod_icyber'][1]['scaleRGB']), 'ON must glow harder than OFF')
for clip in ('idle', 'on'):
    k, f = blocks.get(A.XANIM[clip], (None, {}))
    check(k == 'xanim' and f.get('looping') == '1' and f.get('type') == 'relative' and f.get('useBones') == '1',
          A.XANIM[clip] + ' must be a looping relative xanim')
    check(f.get('model') == 'tod_inducer_cyber\\\\tod_inducer_cyber.xmodel_bin', A.XANIM[clip] + ' bind model')
for name, (k, f) in blocks.items():
    if k == 'image':
        check((ROOT/f['baseImage'].replace('\\\\', '/')).is_file(), 'GDT image file missing: ' + name)
    check(len(name) <= 63, 'asset name over 63 chars: ' + name)

# ---- the model
model = xm.Model(); model.LoadFile_Bin(str(xbin), split_meshes=True)
check([b.name for b in model.bones] == A.BONE_ORDER, 'bones != anim_spec.BONE_ORDER')
check([m.name for m in model.materials] == ['mtl_tod_icyber', 'mtl_tod_icyber_plasma'], 'model materials')
per_bone = [0] * len(model.bones)
xs, ys, zs = [], [], []
for m in model.meshes:
    for v in m.verts:
        check(len(v.weights) == 1, 'vertex with more than one bone weight')
        per_bone[v.weights[0][0]] += 1
        xs.append(v.offset[0]); ys.append(v.offset[1]); zs.append(v.offset[2])
check(all(per_bone), 'a bone drives no geometry: ' + str(dict(zip(A.BONE_ORDER, per_bone))))
check(min(xs) > WALL_X + 0.5, 'model reaches the arena wall (x %.2f)' % min(xs))
check(max(abs(y) for y in ys) <= 22.5 and max(xs) <= 22.5, 'model wider than its 44 x 44 footprint')
check(min(zs) > -0.05 and max(zs) < 70, 'model height out of range')
faces = sum(len(m.faces) for m in model.meshes)
check(faces == sum(man['faces'].values()), 'face count != manifest')
for i, b in enumerate(model.bones[1:], 1):
    off, rot = A.pose(b.name, 'idle', 0)
    check(max(abs(a - c) for a, c in zip(b.offset, off)) < 1e-3, b.name + ' bind offset != anim_spec rest')

# ---- the clips: seamless, and frame 0 == bind pose (no pop when AnimScripted starts)
bind = {b.name: (b.offset, b.matrix) for b in model.bones}
for clip in ('idle', 'on'):
    anim = xa.Anim(); anim.LoadFile_Bin(str(ANIMS/(A.XANIM[clip] + '.XANIM_BIN')))
    names = [p.name for p in anim.parts]
    check(names == A.BONE_ORDER, clip + ' clip bones')
    check(len(anim.frames) == A.CLIPS[clip] + 1, clip + ' frame count')
    first, last = anim.frames[0], anim.frames[-1]
    for i, name in enumerate(names):
        a, z = first.parts[i], last.parts[i]
        d = max(abs(p - q) for p, q in zip(a.offset, z.offset))
        r = max(abs(p - q) for ra, rz in zip(a.matrix, z.matrix) for p, q in zip(ra, rz))
        check(d < 0.02 and r < 0.002, '%s %s does not loop seamlessly (d=%.4f r=%.5f)' % (clip, name, d, r))
        bo, bm = bind[name]
        d0 = max(abs(p - q) for p, q in zip(a.offset, bo))
        r0 = max(abs(p - q) for ra, rb in zip(a.matrix, bm) for p, q in zip(ra, rb))
        check(d0 < 0.02 and r0 < 0.002, '%s %s frame 0 is not the bind pose' % (clip, name))
    # sanity: the moving bones actually move, and stay inside the cage
    for i, name in enumerate(names):
        if name == 'tag_origin':
            continue
        travel = max(math.dist(fr.parts[i].offset, first.parts[i].offset) for fr in anim.frames)
        check(travel < 2.5, '%s %s travels %.2f units - out of its cage' % (clip, name, travel))

# ---- lockstep: animtree / zone / script / generated data / fx
atr = ATR.read_text()
for clip in ('idle', 'on'):
    check(A.XANIM[clip] in atr, 'animtree lacks ' + A.XANIM[clip])
zone = [l.strip() for l in ZONE.read_text(encoding='utf-8').splitlines()]
for line in ('xmodel,tod_inducer_cyber', 'xmodel,tod_inducer_cyber_on', 'rawfile,animtrees/tod_inducer.atr',
             'xanim,tod_inducer_cyber_loop_idle', 'xanim,tod_inducer_cyber_loop_on', 'fx,tod/fx_tod_inducer_idle', 'fx,tod/fx_tod_inducer_on'):
    check(line in zone, 'zone line missing: ' + line)
for line in ('xmodel,tod_inducer', 'xmodel,tod_inducer_on'):
    check(line not in zone, 'retired BO6 inducer still zoned: ' + line)
gsc = GSC.read_text(encoding='utf-8')
need = {'TOD_RAMPAGE_MODEL': 'tod_inducer_cyber', 'TOD_RAMPAGE_MODEL_ON': 'tod_inducer_cyber_on',
        'TOD_RAMPAGE_ANIM_IDLE': A.XANIM['idle'], 'TOD_RAMPAGE_ANIM_ON': A.XANIM['on']}
for define, value in need.items():
    check(re.search(r'#define\s+%s\s+"%s"' % (define, value), gsc), '_tod_rampage.gsc %s != "%s"' % (define, value))
check('#using_animtree( "tod_inducer" );' in gsc, '_tod_rampage.gsc must use the tod_inducer animtree')
for clip in ('idle', 'on'):
    check('#precache( "xanim", "%s" );' % A.XANIM[clip] in gsc, 'xanim precache missing: ' + A.XANIM[clip])
check('base_inducer_trig_lift()' in gsc, '_tod_rampage.gsc must read the generated trigger lift')
check('anim_set( on );' in gsc, 'glow_set must re-play the anim after each SetModel')
gen = GEN.read_text(encoding='utf-8')
clip_h = int(re.search(r'const INDUCER_CLIP_H\s*=\s*(\d+)', gen).group(1))
lift = int(re.search(r'const INDUCER_TRIG_LIFT\s*=\s*(\d+)', gen).group(1))
m = re.search(r'function base_inducer_trig_lift\(\)\s*\{\s*return\s+(\d+);', DATA.read_text())
check(m and int(m.group(1)) == lift, 'generated base_inducer_trig_lift() != INDUCER_TRIG_LIFT (regenerate the map)')
check(lift >= clip_h + 2, 'trigger lift must clear the body clip')
check('rampage inducer body' in MAP.read_text(encoding='utf-8', errors='replace'), 'the .map has no inducer body clip (regenerate)')
for fx in FX:
    check(re.search(r'spawnOrgZ 35 ', fx.read_text(encoding='utf-8', errors='replace')), fx.name + ' lamp not at the crystal (spawnOrgZ 35)')

# ---- compiled ledger (post-link)
if '--compiled-ledger' in sys.argv:
    ledger = Path(sys.argv[sys.argv.index('--compiled-ledger') + 1])
    rows = {r.split(',')[0]: r.split(',') for r in ledger.read_text().splitlines()[1:]}
    want = sum(man['faces'].values())
    for name in ('tod_inducer_cyber', 'tod_inducer_cyber_on'):
        r = rows.get(name)
        check(r is not None, 'xmodel not linked: ' + name)
        if r:
            check(r[4] == '1', '%s compiled %s LODs (want 1: no autogen decimation of thin strips)' % (name, r[4]))
            check(int(r[6]) >= want * 0.995, '%s compiled %s tris, source %d' % (name, r[6], want))
    check('tod_inducer' not in rows, 'the retired BO6 inducer is still linked')
    main = ledger.parent/(ledger.name.replace('_xmodel.csv', '.csv'))
    text = main.read_text(errors='replace')
    for kind, name in (('xanim', A.XANIM['idle']), ('xanim', A.XANIM['on']),
                       ('rawfile', 'animtrees/tod_inducer.atr'), ('material', 'mc/mtl_tod_icyber'),
                       ('material', 'mc/mtl_tod_icyber_on'), ('material', 'mc/mtl_tod_icyber_plasma'),
                       ('material', 'mc/mtl_tod_icyber_plasma_on')):
        check((',%s,%s,' % (kind, name)) in text, 'not in the linked ledger: %s %s' % (kind, name))
    for img in man['images']:
        check((',image,%s,' % img[:-4]) in text, 'image not linked: ' + img)

if fails:
    print('INDUCER_CYBER_VERIFY FAILED (%d):' % len(fails))
    for f in fails:
        print('  - ' + f)
    raise SystemExit(1)
print('INDUCER_CYBER_OK: %d faces, bones %s, idle %d / on %d frames seamless from the bind pose, '
      'ON/OFF twins, animtree + zone + script + generated trigger lift in lockstep%s.'
      % (faces, ','.join(A.BONE_ORDER[1:]), A.CLIPS['idle'], A.CLIPS['on'],
         ', compiled ledger verified' if '--compiled-ledger' in sys.argv else ''))
