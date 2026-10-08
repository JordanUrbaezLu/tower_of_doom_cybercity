"""Install the staged BO6 Ice Staff assembly into Cybercity as private BO3 assets.

This is the BINDING step the ledger had open: everything before it (extraction,
assembly, material decode, sound export) stayed in local_sync_cache/ and tmp/.
After this script the ice staff's PRESENTATION fields point at BO6 assets:

  * models    tod_bo6_ice_vm / tod_bo6_ice_wm  (model_export/tod_bo6_ice/)
  * materials mtl_tod_bo6_ice_<hash> x6 with decoded NOG + original emission
  * sounds    wpn_tod_bo6_ice_* (sound_assets/tod/mage/bo6/, tod_ports.csv)
  * glow      a private socket, tag_bo6_glow, inside the tip crystal

What is deliberately NOT BO6 (recorded in the ledger as `adapted`):

  * MOTION. The held animations stay the fitted Origins set. BO6's 116 clips
    carry local quaternions and NO skeleton, so they can only be interpreted
    against BO6's own arm rest pose, which was never exported - the exact
    finding Tower II recorded for its Saug port. The BO6 model is therefore
    aligned to the donor's grip so the donor set places it correctly.
  * EFFECTS. The BO6 vfx names returned zero rows in the 408,004-asset index;
    the muzzle / trail / impact / glow effects stay the existing BO3 ones.

ALIGNMENT IS MEASURED, NOT GUESSED. BO3 attaches a gun model by its root
(`tag_weapon`) at the hand rig's `tag_weapon_right`, and the fitted clips
store absolute transforms, so the BO6 root has to sit where the donor root
sits relative to the hands:

  view   donor j_wrist_ri is 11.38 in behind tag_weapon, j_wrist_le 0.61 ahead
         (fitted idle, frame 0); BO6 authored tag_ik_loc_ri at -11.67 and
         tag_ik_loc_le at +0.90 from j_gun.  Residuals 0.29 / 0.29 in: the
         root maps 1:1, no shift.
  world  the donor world staff runs along +Z (tag_tip's frame is X->+Z), its
         root is the 3p right hand.  BO6 runs along +X with the right hand at
         x = -11.67, so the world model is shifted +11.67 along the staff and
         rotated X->Z.  That lands the muzzle at z 49.98 (donor 47.86) and
         the butt at z -26.0 (donor -24.3): both ends within 2.2 in.

The world assembly's six materials are byte-identical textures to the view
assembly's (every image md5 matches pairwise), so the world mesh is bound to
the same six materials rather than staging a duplicate set.

Run (game closed, then a FULL build):
    python tools/bo6_extraction/install_ice_staff_bo3.py
    python tools/bo6_extraction/install_ice_staff_bo3.py --check   # hashes only
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import types

REPO = Path(__file__).resolve().parents[2]
TOOLS = Path(r'C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130')
STAGING = REPO/'local_sync_cache/bo6_ice_staff/staging/assembly'
OUT = REPO/'model_export/tod_bo6_ice'
IMAGES = OUT/'_images'
GDT = REPO/'source_data/tod_bo6_ice_staff.gdt'
STAFF_GDT = REPO/'source_data/tod_staff.gdt'
ORIGINS_GDT = REPO/'source_data/tod_staff_origins.gdt'
SND_DIR = REPO/'sound_assets/tod/mage/bo6'
ALIASES = REPO/'sound/aliases/tod_ports.csv'
MANIFEST = REPO/'docs/bo6_ports/manifests/ice_staff_bo3_install.json'
BO6_SOUNDS = Path.home()/'Downloads/BO6_Pilot_Export/bo6/sounds'
FFMPEG = Path(os.environ.get('LOCALAPPDATA', ''))/'Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-8.1.2-full_build/bin/ffmpeg.exe'
PYCOD = Path(os.environ.get('TOD_PYCOD', r'C:\Users\jorda\Repositories\test+map\tmp\blender-cod\io_scene_cod'))

VM_MATERIALS = ['185cf03e0a997c76', '18911d6f7aeac1d9', '265e6ebadb703c9',
                '368354ed1784cc03', '5ef8c6c509565385', '7816470a495eb7d0']
# world-assembly material hash -> view-assembly hash (byte-identical textures)
WM_TO_VM = {'50bca4d3e8a8ebd': '185cf03e0a997c76', '47a5334bc348f05e': '18911d6f7aeac1d9',
            '227d9a19c4a22c0e': '265e6ebadb703c9', '354775f8164f7530': '368354ed1784cc03',
            '2a376a86a6aa0a3e': '5ef8c6c509565385', '652a30a6ea81b223': '7816470a495eb7d0'}
EMISSION = {'185cf03e0a997c76', '265e6ebadb703c9', '5ef8c6c509565385', '7816470a495eb7d0'}
# v18.92 (user: "any way to make the crystal glow more? The tip of the staff has a crystal"):
# the two water-tip materials (185cf.., 5ef8c..) glow at 14, the shaft runes stay at 6.
EMISSIVE_SCALE = {'185cf03e0a997c76': '14', '5ef8c6c509565385': '14', '265e6ebadb703c9': '6', '7816470a495eb7d0': '6'}
GLOW_BONE = ('tag_bo6_glow', 'j_water', (8.5, 0.0, 0.0))  # centre of the tip crystal (obj 8: x 24.8..41.9)
WM_SHIFT = 11.667      # BO6 tag_ik_loc_ri.x, negated: the 3p right hand becomes the root
EXPECT = dict(bones=76, vertices=51060, triangles=59842, meshes=11)

# Donor anchors (fitted ice idle, frame 0, relative to tag_weapon) and the BO6 tags they answer.
VIEW_ALIGN = {'tag_ik_loc_ri': (-11.382, 0.0, 0.0), 'tag_ik_loc_le': (0.607, 0.0, 0.0)}
VIEW_TOL = 0.5      # inches, along the shaft only: the IK locators sit off-axis by design
WORLD_ALIGN = {'tag_flash': 47.861, 'tag_ik_loc_ri': 0.0}   # z along the donor world staff
WORLD_TOL = 2.5


def load_pycod():
    if 'PyCoD' not in sys.modules:
        sys.path.insert(0, str(PYCOD))
        pkg = types.ModuleType('PyCoD')
        pkg.__path__ = [str(PYCOD/'PyCoD')]
        sys.modules['PyCoD'] = pkg
    from PyCoD import xmodel
    return xmodel


def digest(path):
    with Path(path).open('rb') as h:
        return hashlib.file_digest(h, 'sha256').hexdigest()


def blocks(path):
    """Same parser the staff importer uses; the GDTs it wrote round-trip through it."""
    text = path.read_text(encoding='latin1')
    return [(m[1], m[2], dict(re.findall(r'"([^"\n]+)"\s*"([^"\n]*)"', m[3])))
            for m in re.finditer(r'"([^"\n]+)"\s*\(\s*"([^"\n]+)"\s*\)\s*\{([^}]+)\}', text)]


def emit(name, kind, fields):
    return '\t"'+name+'" ( "'+kind+'" )\n\t{\n'+''.join('\t\t"'+k+'" "'+v+'"\n' for k, v in fields.items())+'\t}\n'


def rot_world(v):
    """BO6 staff axis +X -> donor world axis +Z (the donor's tag_tip frame: X=(0,0,1), Z=(-1,0,0))."""
    return (-v[2], v[1], v[0])


# ------------------------------------------------------------------ models
def convert_model(xmodel, perspective, report):
    src = STAGING/f'tod_bo6_ice_{perspective}.XMODEL_EXPORT'
    m = xmodel.Model()
    m.LoadFile_Raw(str(src))
    verts = sum(len(x.verts) for x in m.meshes)
    tris = sum(len(x.faces) for x in m.meshes)
    assert (len(m.bones), verts, tris, len(m.meshes)) == (EXPECT['bones'], EXPECT['vertices'], EXPECT['triangles'], EXPECT['meshes']), \
        (perspective, len(m.bones), verts, tris, len(m.meshes))
    assert m.bones[0].name == 'j_gun' and m.bones[0].parent == -1
    m.bones[0].name = 'tag_weapon'
    names = {b.name: i for i, b in enumerate(m.bones)}

    if perspective == 'wm':
        for mat in m.materials:
            h = mat.name.removeprefix('mtl_tod_bo6_ice_')
            assert h in WM_TO_VM, mat.name
            mat.name = 'mtl_tod_bo6_ice_'+WM_TO_VM[h]
        for i, b in enumerate(m.bones):
            if i == 0:
                continue   # the root stays identity at the hand; the model turns around it
            b.offset = rot_world((b.offset[0]+WM_SHIFT, b.offset[1], b.offset[2]))
            b.matrix = [rot_world(tuple(r)) for r in b.matrix]
        for mesh in m.meshes:
            for v in mesh.verts:
                v.offset = rot_world((v.offset[0]+WM_SHIFT, v.offset[1], v.offset[2]))
            for f in mesh.faces:
                for fv in f.indices:
                    fv.normal = rot_world(tuple(fv.normal))
    assert {mat.name.removeprefix('mtl_tod_bo6_ice_') for mat in m.materials} == set(VM_MATERIALS)

    # Private glow socket inside the tip crystal. Appended, so no weight index moves;
    # its name is in no fitted clip, so it rides its parent instead of being driven
    # to the donor's crystal position the way a `tag_upg` would be.
    name, parent, local = GLOW_BONE
    assert name not in names
    p = m.bones[names[parent]]
    g = xmodel.Bone(name, names[parent])
    off = tuple(local) if perspective == 'vm' else rot_world(local)
    g.offset = tuple(p.offset[k]+off[k] for k in range(3))
    g.matrix = [tuple(r) for r in p.matrix]
    m.bones.append(g)
    names[name] = len(m.bones)-1

    # Alignment proof before anything is written.
    align = {}
    if perspective == 'vm':
        for tag, donor in VIEW_ALIGN.items():
            d = abs(m.bones[names[tag]].offset[0]-donor[0])
            align[tag] = round(d, 3)
            assert d < VIEW_TOL, (tag, d)
    else:
        for tag, donor_z in WORLD_ALIGN.items():
            d = abs(m.bones[names[tag]].offset[2]-donor_z)
            align[tag] = round(d, 3)
            assert d < WORLD_TOL, (tag, d)
        assert m.bones[names['tag_weapon']].offset == (0.0, 0.0, 0.0) or tuple(m.bones[0].offset) == (0.0, 0.0, 0.0)

    OUT.mkdir(parents=True, exist_ok=True)
    raw = OUT/f'tod_bo6_ice_{perspective}.XMODEL_EXPORT'
    m.WriteFile_Raw(str(raw))
    result = subprocess.run([str(TOOLS/'bin/export2bin.exe'), raw.name], cwd=OUT, capture_output=True, text=True, timeout=600)
    binary = next((p for p in OUT.iterdir() if p.name.lower() == f'tod_bo6_ice_{perspective}.xmodel_bin'), None)
    assert result.returncode == 0 and binary is not None and binary.read_bytes()[:5] == b'*LZ4*', (result.stdout, result.stderr)
    (OUT/f'{perspective}_export2bin.log').write_text(result.stdout+'\n'+result.stderr)
    back = xmodel.Model()
    back.LoadFile_Bin(str(binary))
    assert [b.name for b in back.bones] == [b.name for b in m.bones], 'bone order changed in conversion'
    assert sum(len(x.verts) for x in back.meshes) == verts
    assert sum(len(x.faces) for x in back.meshes) == tris
    lo = [min(v.offset[k] for x in m.meshes for v in x.verts) for k in range(3)]
    hi = [max(v.offset[k] for x in m.meshes for v in x.verts) for k in range(3)]
    report['models'][perspective] = dict(
        source=str(src.relative_to(REPO)), source_sha256=digest(src),
        xmodel_export=str(raw.relative_to(REPO)), xmodel_bin=str(binary.relative_to(REPO)),
        xmodel_bin_sha256=digest(binary), bones=len(m.bones), vertices=verts, triangles=tris,
        bounds_inches=[[round(x, 3) for x in lo], [round(x, 3) for x in hi]],
        alignment_residuals_inches=align, glow_bone=dict(name=name, parent=parent, offset=[round(x, 3) for x in g.offset]),
        world_transform=(None if perspective == 'vm' else dict(shift_along_staff=WM_SHIFT, rotation='X->Z (donor tag_tip frame)')))
    print(f'MODEL {perspective}: {len(m.bones)} bones, {verts} verts, {tris} tris, align {align}', flush=True)
    return binary


# ------------------------------------------------------------------ materials
def image_block(name, png, semantic, core, compression):
    return emit(name, 'image.gdf', {
        'baseImage': 'model_export\\\\tod_bo6_ice\\\\_images\\\\'+png, 'imageType': 'Texture', 'type': 'image',
        'compressionMethod': compression, 'semantic': semantic, 'coreSemantic': core, 'streamable': '1'})


def material_gdt(report):
    IMAGES.mkdir(parents=True, exist_ok=True)
    staged = json.loads((STAGING/'materials.json').read_text())
    by_name = {row['material'].removeprefix('material_'): row for row in staged['materials']}
    assert set(by_name) == set(VM_MATERIALS)
    out, files = [], {}
    for h in VM_MATERIALS:
        row = by_name[h]
        prefix = 'i_tod_bo6_ice_'+h
        for field, spec in row['outputs'].items():
            src = REPO/spec['path']
            assert digest(src) == spec['sha256'], ('staged texture changed', src)
            dst = IMAGES/src.name
            shutil.copyfile(src, dst)
            files[str(dst.relative_to(REPO)).replace('\\', '/')] = digest(dst)
        out.append(image_block(prefix+'_c', prefix+'_c.png', 'diffuseMap', 'sRGB3chAlpha', 'compressed high color'))
        out.append(image_block(prefix+'_n', prefix+'_n.png', 'normalMap', 'Normal', 'compressed'))
        out.append(image_block(prefix+'_g', prefix+'_g.png', 'glossMap', 'Linear1ch', 'compressed'))
        out.append(image_block(prefix+'_o', prefix+'_o.png', 'occlusionMap', 'Linear1ch', 'compressed'))
        fields = {
            'surfaceType': 'metal', 'template': 'material.template', 'materialCategory': 'Geometry Plus',
            'materialType': 'lit_plus', 'colorMap': prefix+'_c', 'normalMap': prefix+'_n',
            'cosinePowerMap': prefix+'_g', 'occMap': prefix+'_o', 'colorTint': '1 1 1 1',
            'textureAtlasRowCount': '1', 'textureAtlasColumnCount': '1', 'usage': '<not in editor>',
            'heatmap': '$gray_32_one_channel', 'normalHeightScale': '1', 'glossRangeMin': '0', 'glossRangeMax': '13'}
        if h in EMISSION:
            out.append(image_block(prefix+'_e', prefix+'_e.png', 'diffuseMap', 'sRGB3chAlpha', 'compressed high color'))
            fields.update({'materialType': 'lit_emissive_plus', 'colorMap00': prefix+'_e', 'colorTint1': '1 1 1 1',
                           'scaleRGB': EMISSIVE_SCALE[h], 'emissiveIncompetence': '1', 'emissiveFalloff': '0'})
        out.append(emit('mtl_tod_bo6_ice_'+h, 'material.gdf', fields))
        report['materials'].append(dict(material='mtl_tod_bo6_ice_'+h, emissive=h in EMISSION, fields=fields))
    return out, files


def xmodel_blocks():
    donor = {n: f for n, k, f in blocks(ORIGINS_GDT) if k == 'xmodel.gdf'}['tod_staff_view']
    out = []
    for persp, usage_view in (('vm', '1'), ('wm', '0')):
        f = dict(donor)
        f.update({'filename': 'tod_bo6_ice\\\\tod_bo6_ice_'+persp+'.xmodel_bin', 'type': 'animated',
                  'usage_view': usage_view, 'usage_weapon': '1', 'usage_attachment': '0', 'usage_hero': '0',
                  'skinOverride': '', 'BulletCollisionLOD': 'None', 'collisionLOD': 'None', 'hitBoxModel': '',
                  'mediumLod': '', 'lowLod': '', 'lowestLod': '', 'lod4': '', 'lod5': '', 'lod6': '', 'lod7': ''})
        out.append(emit('tod_bo6_ice_'+persp, 'xmodel.gdf', f))
    return out


# ------------------------------------------------------------------ sounds
SOUNDS = [
    # (output name, BO6 source relative to BO6_SOUNDS, trim seconds, fade-out seconds, target RMS dBFS or None)
    ('ice_fire_1', 'sound_3a0d39942f663533.wav', 1.25, 0.25, -17.4),
    ('ice_fire_2', 'sound_46f987281a8d8407.wav', 1.25, 0.25, -17.4),
    ('ice_fire_3', 'sound_579c222960c7879e.wav', 1.25, 0.25, -17.4),
    ('ice_fire_4', 'sound_678327412b1e8e25.wav', 1.25, 0.25, -17.4),
    ('ice_fire_5', 'sound_787f1ce0760fe728.wav', 1.25, 0.25, -17.4),
    ('ice_fire_tail_1', 'sound_2228dcacb0967df3.wav', 2.0, 0.4, None),
    ('ice_fire_tail_2', 'sound_29466eb1d86be41.wav', 2.0, 0.4, None),
    ('ice_fire_tail_3', 'sound_3321cd077ae5355e.wav', 2.0, 0.4, None),
    ('ice_fire_tail_4', 'sound_44849a325d37a5e5.wav', 2.0, 0.4, None),
    ('ice_fire_tail_5', 'sound_6284f7e5e227eee8.wav', 2.0, 0.4, None),
    ('ice_first_raise', 'sound_5fd20fdab747836b.wav', 2.75, 0.5, -19.0),
    ('ice_raise', 't10/wpn/zmb/staff_ice/fly_ice_staff_pullout.tnn.75.48000.all.wav', None, None, None),
    ('ice_putaway', 't10/wpn/zmb/staff_ice/fly_ice_staff_putaway.tnn.75.48000.all.wav', 1.2, 0.25, None),
    ('ice_reload', 't10/wpn/zmb/staff_ice/fly_ice_staff_reload.tnn.75.48000.all.wav', 2.0, 0.35, -18.0),
]
BO6_ALIAS = {'ice_fire': 'wpn_ice_staff_base_fire_plr/npc', 'ice_fire_tail': 'wpn_ice_staff_base_fire_plr/npc_tail',
             'ice_first_raise': 'fly_ice_staff_first_raise_plr', 'ice_raise': 'fly_ice_staff_pullout_plr',
             'ice_putaway': 'fly_ice_staff_putaway_plr', 'ice_reload': 'fly_ice_staff_reload_plr'}


def measure(path):
    r = subprocess.run([str(FFMPEG), '-hide_banner', '-i', str(path), '-af',
                        'astats=measure_overall=Peak_level+RMS_level:measure_perchannel=none', '-f', 'null', '-'],
                       capture_output=True, text=True)
    peak = float(re.search(r'Peak level dB: ([-\d.]+|-inf)', r.stderr)[1].replace('-inf', '-120'))
    rms = float(re.search(r'RMS level dB: ([-\d.]+|-inf)', r.stderr)[1].replace('-inf', '-120'))
    return peak, rms


def convert_sounds(report):
    SND_DIR.mkdir(parents=True, exist_ok=True)
    files = {}
    for name, rel, trim, fade, target in SOUNDS:
        src = BO6_SOUNDS/rel
        assert src.is_file(), src
        peak, rms = measure(src)
        filters = []
        if trim:
            filters.append(f'atrim=0:{trim}')
            filters.append(f'afade=t=out:st={trim-fade}:d={fade}')
        gain = 0.0
        if target is not None:
            gain = round(target-rms, 2)
            # never push the peak over -1 dBFS: these masters already sit at 0 dBFS
            gain = min(gain, -1.0-peak)
            filters.append(f'volume={gain}dB')
        dst = SND_DIR/(name+'.wav')
        cmd = [str(FFMPEG), '-hide_banner', '-y', '-i', str(src)]
        if filters:
            cmd += ['-af', ','.join(filters)]
        cmd += ['-ar', '48000', '-ac', '2', '-c:a', 'pcm_s16le', str(dst)]
        r = subprocess.run(cmd, capture_output=True, text=True)
        assert r.returncode == 0 and dst.is_file(), r.stderr
        out_peak, out_rms = measure(dst)
        files[str(dst.relative_to(REPO)).replace('\\', '/')] = digest(dst)
        report['sounds'].append(dict(output=str(dst.relative_to(REPO)), bo6_source=str(src), bo6_alias=BO6_ALIAS[re.sub(r'_\d+$', '', name)],
                                     source_sha256=digest(src), source_peak_db=peak, source_rms_db=rms,
                                     trim_s=trim, fade_out_s=fade, gain_db=gain, output_peak_db=out_peak, output_rms_db=out_rms))
        print(f'SOUND {name}: {rms:.1f} -> {out_rms:.1f} dBFS RMS (gain {gain:+.1f})', flush=True)
    return files


BEGIN, END = '#BO6 ICE STAFF BEGIN (tools/bo6_extraction/install_ice_staff_bo3.py; do not hand-edit between the markers)', '#BO6 ICE STAFF END'


def alias_rows():
    lines = ALIASES.read_text(encoding='utf-8', errors='replace').splitlines()
    rows = {l.split(',')[0]: l for l in lines if l and not l.startswith('#')}
    header = lines[0].split(',')
    col = {c: i for i, c in enumerate(header)}

    def derive(template, name, wav, secondary=''):
        f = rows[template].split(',')
        f[col['Name']] = name
        f[col['FileSpec']] = 'tod\\mage\\bo6\\'+wav
        f[col['Secondary']] = secondary
        return ','.join(f)

    out = [BEGIN,
           '# BO6 Ice Staff (t10 wpn_ww_zmb_staffs): base-fire variants + tails, pullout/putaway, first raise, reload.',
           '# Player rows clone the 2D shot / foley rows above; NPC rows clone the 3d shot row. Levels: see the install manifest.']
    for i in range(1, 6):
        out.append(derive('wpn_tod_staff_ice_plr', 'wpn_tod_bo6_ice_fire_plr', f'ice_fire_{i}.wav', 'wpn_tod_bo6_ice_fire_tail_plr'))
    for i in range(1, 6):
        out.append(derive('wpn_tod_staff_ice_plr', 'wpn_tod_bo6_ice_fire_tail_plr', f'ice_fire_tail_{i}.wav'))
    for i in range(1, 6):
        out.append(derive('wpn_tod_staff_ice_npc', 'wpn_tod_bo6_ice_fire_npc', f'ice_fire_{i}.wav', 'wpn_tod_bo6_ice_fire_tail_npc'))
    for i in range(1, 6):
        out.append(derive('wpn_tod_staff_ice_npc', 'wpn_tod_bo6_ice_fire_tail_npc', f'ice_fire_tail_{i}.wav'))
    out.append(derive('wpn_waterstaff_1straise', 'wpn_tod_bo6_ice_first_raise', 'ice_first_raise.wav'))
    out.append(derive('wpn_tod_staff_raise_plr', 'wpn_tod_bo6_ice_raise_plr', 'ice_raise.wav'))
    out.append(derive('wpn_tod_staff_pickup_plr', 'wpn_tod_bo6_ice_pickup_plr', 'ice_raise.wav'))
    out.append(derive('wpn_tod_staff_putaway_plr', 'wpn_tod_bo6_ice_putaway_plr', 'ice_putaway.wav'))
    out.append(derive('wpn_staff_reload_1', 'wpn_tod_bo6_ice_reload', 'ice_reload.wav'))
    out.append(END)
    if BEGIN in lines:
        a, b = lines.index(BEGIN), lines.index(END)
        lines[a:b+1] = out
    else:
        lines.extend(out)
    ALIASES.write_text('\n'.join(lines)+'\n', encoding='utf-8')
    return [l.split(',')[0] for l in out if l and not l.startswith('#')]


# ------------------------------------------------------------------ weapon binding
ICE_BINDINGS = {
    'gunModel': 'tod_bo6_ice_vm', 'worldModel': 'tod_bo6_ice_wm',
    'attachViewModel1': '', 'attachWorldModel1': '',     # the BO6 assembly carries its own tip
    'hideTags': '',                                     # the Origins storm/rune tags do not exist on it
    'fireSound': 'wpn_tod_bo6_ice_fire_npc', 'fireSoundPlayer': 'wpn_tod_bo6_ice_fire_plr',
    'raiseSoundPlayer': 'wpn_tod_bo6_ice_raise_plr', 'putawaySoundPlayer': 'wpn_tod_bo6_ice_putaway_plr',
    'pickupSoundPlayer': 'wpn_tod_bo6_ice_pickup_plr',
    # v18.90: BO6-INSPIRED shot effects composed from BO3 emitters (build_bo6_ice_fx.py).
    # GDT values are C-escaped on disk: two backslash CHARACTERS per separator.
    'viewFlashEffect': 'tod\\\\bo6\\\\fx_bo6_ice_muzzle_1p.efx', 'worldFlashEffect': 'tod\\\\bo6\\\\fx_bo6_ice_muzzle_3p.efx',
    'projTrailEffect': 'tod\\\\bo6\\\\fx_bo6_ice_trail.efx', 'projExplosionEffect': 'tod\\\\bo6\\\\fx_bo6_ice_impact.efx',
}


def bind_weapon(report):
    # The PaP presentation layer splits this original assembly at its measured
    # socket. Reinstalling BO6 textures/sounds must not silently undo that layer.
    sys.path.insert(0, str(REPO/'tools'))
    from staff_presentation_bindings import STAFF_BINDINGS
    entries = blocks(STAFF_GDT)
    before = {n: dict(f) for n, k, f in entries}
    out = []
    for name, kind, fields in entries:
        if name == 'tod_staff_ice':
            fields = dict(fields)
            for k, v in ICE_BINDINGS.items():
                assert k in fields, k
                fields[k] = v
            fields.update(STAFF_BINDINGS['ice'])
        out.append((name, kind, fields))
    STAFF_GDT.write_text('{\n'+''.join(emit(*e) for e in out)+'}\n', encoding='latin1')
    after = {n: f for n, k, f in blocks(STAFF_GDT)}
    for n in before:
        changed = {k for k in before[n] if before[n][k] != after[n].get(k)}
        assert changed <= (set(ICE_BINDINGS) | set(STAFF_BINDINGS['ice']) if n == 'tod_staff_ice' else set()), (n, changed)
    report['weapon'] = dict(block='tod_staff_ice', previous={k: before['tod_staff_ice'][k] for k in ICE_BINDINGS}, bound=ICE_BINDINGS)


# ------------------------------------------------------------------ main
def check():
    sys.path.insert(0, str(REPO/'tools'))
    from staff_presentation_bindings import STAFF_BINDINGS
    r = json.loads(MANIFEST.read_text())
    for path, sha in r['files'].items():
        assert (REPO/path).is_file() and digest(REPO/path) == sha, ('BO6 ice staff install file missing/changed', path)
    staff = {n: f for n, k, f in blocks(STAFF_GDT)}['tod_staff_ice']
    expected = dict(r['weapon']['bound'])
    expected.update(STAFF_BINDINGS['ice'])
    for k, v in expected.items():
        assert staff.get(k) == v, ('ice weapon binding drifted', k, staff.get(k), v)
    aliases = {l.split(',')[0] for l in ALIASES.read_text(encoding='utf-8', errors='replace').splitlines()}
    assert set(r['aliases']) <= aliases, sorted(set(r['aliases'])-aliases)
    print(f"BO6 ICE STAFF INSTALL OK: {len(r['files'])} files, {len(r['aliases'])} aliases; native acceptance is a separate claim")


def main():
    if '--check' in sys.argv:
        check()
        return
    xmodel = load_pycod()
    assert FFMPEG.is_file(), FFMPEG
    report = dict(models={}, materials=[], sounds=[], files={}, held_motion='donor: the fitted Origins staff set (BO6 clips lack an exported arm rest pose)',
                  effects='BO3 muzzle/trail/impact/glow retained (BO6 vfx absent from the export index)', native_verified=False)
    for persp in ('vm', 'wm'):
        binary = convert_model(xmodel, persp, report)
        report['files'][str(binary.relative_to(REPO)).replace('\\', '/')] = digest(binary)
    gdt, files = material_gdt(report)
    report['files'].update(files)
    gdt += xmodel_blocks()
    GDT.write_text('{\n'+''.join(gdt)+'}\n', encoding='utf-8')
    report['files'][str(GDT.relative_to(REPO)).replace('\\', '/')] = digest(GDT)
    report['files'].update(convert_sounds(report))
    report['aliases'] = alias_rows()
    bind_weapon(report)
    MANIFEST.write_text(json.dumps(report, indent=2)+'\n')
    print('INSTALLED: BO6 ice staff models, 6 materials, %d sounds, %d alias rows; ice weapon rebound. Next: SOUND_NOTES, twins, verify, FULL build.'
          % (len(report['sounds']), len(report['aliases'])), flush=True)


if __name__ == '__main__':
    main()
