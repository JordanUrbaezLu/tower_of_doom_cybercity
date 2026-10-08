"""THE STAFF CRYSTAL (docs/164): Treyarch's fourth staff piece, back on the staff.

Treyarch built the Chronicles (zm_tomb HD) staff as a KIT: one shaft
(`wpn_t7_zmb_hd_staff_view/_world`) + an element head (`tip_<el>`) + a glowing
stone (`crystal_<el>`) + an upgraded head (`tip_<el>_upg_world`). The shaft,
heads and PaP heads have shipped since v18.33; the crystal was left out on
2026-09-07 because its material "looked like a camo shader" (docs/114 A.5).
Without it the fire and lightning heads are EMPTY CAGES (measured: the fire
head has no geometry within 3.4-6.1 in of its axis between local X 4 and 14),
which is the "missing piece in the middle" other players saw. First person
hid it: the staff glow is a PlayViewmodelFX for the local player only.

Treyarch's own material (T7 Assets V2.7, t7_weapons.gdt) is NOT a camo type:
`lit_emissive_scroll_advanced_fullspec`, a STOCK techset (share/raw
techsetdefs_stable + _toolsgfx) the stock elemental bow ships on. So:

  python tools/build_staff_crystal.py          # (re)generate from sources
  python tools/build_staff_crystal.py --check  # build gate (no sources needed)

Generation copies the two WORLD crystal binaries from the user's Greyhound
export into model_export/tod_staff_crystal/ (repo-owned; sync_to_modtools
copies that folder) and writes source_data/tod_staff_crystal.gdt:

  * xmodel blocks cloned field-for-field from tod_staff_tip_<el>_world (the
    proven head block) with only `filename` changed and the inherited
    `skinOverride` junk cleared;
  * material blocks NAMED EXACTLY AS THE BINARIES EMBED THEM - including
    Treyarch's own typo `..._crystal_lighting` - cloned from the stock bow's
    `mtl_wpn_t7_zmb_bow_wolf` (same materialType, a block that demonstrably
    renders) with Treyarch's crystal values laid over it.

Images it names: i_wpn_t7_camo_ice_e / i_wpn_t7_zmb_hd_staff_crystals_n / _o
(declared in tod_staff_origins.gdt since v18.33, unused until now),
i_generic_lookup (canonical texture_assets/genericfilters.gdt, revealMap - see
verify_staff_animations.check_flicker_lookup) and stock `$` images.

The crystals are ATTACHED by tools/staff_presentation_bindings.py (base:
attachWorldModel2 at tag_crystal + attachViewModel2 at tag_tip; PaP: gmod6
model1 in both perspectives). Pass 2 added the VIEW crystal (renamed root,
measured alignment) and the GLOW knob - see the constants below.
"""
import hashlib
import json
import shutil
import sys
from pathlib import Path

from import_staff_animations import ROOT, blocks, emit

ELEMENTS = ('fire', 'lightning')
GREYHOUND = Path(r'C:\Users\jorda\Documents\BO3_tools\Greyhound\exported_files\black_ops_3\xmodels')
TOOLS = Path(r'C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130')
OUT_DIR = ROOT/'model_export'/'tod_staff_crystal'
OUT_GDT = ROOT/'source_data'/'tod_staff_crystal.gdt'
MANIFEST = ROOT/'docs'/'staff_crystal_manifest.json'
BOW_GDT = TOOLS/'source_data'/'wpn_t7_zmb_bow.gdt'
BOW_MATERIAL = 'mtl_wpn_t7_zmb_bow_wolf'
MATERIAL_TYPE = 'lit_emissive_scroll_advanced_fullspec'

# Read off the binaries with PyCoD (root bone + embedded material name). The
# lightning name is Treyarch's typo and MUST be kept: the xmodel binds it.
CRYSTAL = {
    'fire':      {'source': 'wpn_t7_zmb_hd_staff_crystal_fire_world', 'bone': 'tag_clip_fire',
                  'material': 'mtl_wpn_t7_zmb_hd_staff_crystal_fire', 'triangles': 120},
    'lightning': {'source': 'wpn_t7_zmb_hd_staff_crystal_lightning_world', 'bone': 'tag_clip_lightning',
                  'material': 'mtl_wpn_t7_zmb_hd_staff_crystal_lighting', 'triangles': 36},
}

# Treyarch's crystal material, verbatim from T7 Assets V2.7
# (source_data/_midgetblaster/t7_weapons.gdt). The two elements differ only in
# the two tints. Every key exists in the stock bow block it overrides.
T7_COMMON = {
    'surfaceType': 'glass', 'materialCategory': 'Geometry Advanced', 'materialType': MATERIAL_TYPE,
    'textureAtlasRowCount': '1', 'textureAtlasColumnCount': '1',
    'occMap': 'i_wpn_t7_zmb_hd_staff_crystals_o', 'colorMap00': 'i_wpn_t7_camo_ice_e',
    'heatmap': '$gray_32_one_channel', 'flickerLookupMap': 'i_generic_lookup',
    'normalMap': 'i_wpn_t7_zmb_hd_staff_crystals_n', 'cosinePowerMap': '$gloss',
    'colorMap': '$black_color', 'specColorMap': '$specular',
    'normalHeightScale': '1', 'glossRangeMin': '3.29999995231628', 'glossRangeMax': '13.6000003814697',
    'rowCount': '1', 'columnCount': '1', 'imageTime': '1', 'uvScrollAngle': '1', 'uvRotationRate': '1',
    'gUVScroll02_Angle': '0.00999999977648258', 'gUVScroll03_Angle': '0.00999999977648258',
    'detailScaleX': '1', 'detailScaleY': '1', 'uScroll': '0', 'vScroll': '0',
    'zoomMin': '1', 'zoomMax': '1', 'zoomRate': '0', 'waterRoughness': '0.100000001490116',
    'clampU': '0', 'clampV': '0', 'flickerSeedU': '0', 'flickerSeedV': '0', 'flickerSpeed': '1',
    'flickerMin': '1', 'flickerMax': '1', 'flickerPower': '1', 'scaleRGB': '8', 'emissiveFalloff': '0',
    'emissiveIncompetence': '1', 'invertFalloff': '0', 'uvMotionToggle1': '0',
}
T7_TINT = {
    'fire':      {'colorTint': '0.466667 0.259144 0.186664 0.000000',
                  'colorTint1': '0.749020 0.333349 0.129244 1.000000'},
    'lightning': {'colorTint': '0.178332 0.092027 0.266667 0.000000',
                  'colorTint1': '0.189929 0.060349 0.427451 1.000000'},
}
# September 27: the user now explicitly wants retail BO3 presentation.
# Retire the pass-2 brightness/tint boost; use the exported crystal settings.
GLOW_SCALE = {element: T7_COMMON['scaleRGB'] for element in ELEMENTS}
GLOW_TINT = T7_TINT
GLOW_FLOOR = 8

# FIRST PERSON (pass 2, MEASURED - tmp/staff_crystal_20260927/
# view_crystal_alignment.json). The approved view clips key the crystal's own
# root `tag_clip_<el>` with the RAW Origins track (the docs/117 head-offset
# correction reached the head's bones, never tag_clip_*): a crystal driven by
# it lands 36-54 in from the head. The shaft's `tag_tip` in the same clips sits
# ON the head root (tag_tip_<el>) in every frame (0.000 in at the crystal's
# centroid; 0.574 in max, lightning first raise); tag_crystal is 3.243 off.
# A KEYED root ignores its attach tag (that is how an explicit tag lost the
# head in R5, docs/117), so the VIEW crystal is the same mesh with its one bone
# renamed to a name no clip keys; it then rests on VIEW_TAG like any optic.
VIEW_ROOT = 'tag_tod_staff_crystal'
VIEW_TAG = 'tag_tip'
EXPORT2BIN = TOOLS/'bin'/'export2bin.exe'

# Images these materials may name: ours (tod_staff_origins.gdt), the canonical
# flicker lookup, and engine built-ins.
OUR_IMAGES = ('i_wpn_t7_camo_ice_e', 'i_wpn_t7_zmb_hd_staff_crystals_n', 'i_wpn_t7_zmb_hd_staff_crystals_o')
IMAGE_FIELDS = ('colorMap', 'colorMap00', 'normalMap', 'occMap', 'cosinePowerMap', 'specColorMap',
                'heatmap', 'flickerLookupMap', 'camoMaskMap')


def model_name(element, view=False):
    return 'tod_staff_crystal_'+element+('_view' if view else '_world')


def bin_path(element, view=False):
    return OUT_DIR/(model_name(element, view)+'.XMODEL_BIN')


def convert_view(element, src):
    """Same mesh, single bone renamed to VIEW_ROOT, written out the long way:
    PyCoD's binary writer is broken (docs/114 A.5 trap 3), and export2bin
    passes a file through unconverted when handed an absolute path (trap 4)."""
    import subprocess
    m = pycod_model(src)
    assert len(m.bones) == 1 and m.bones[0].parent == -1
    m.bones[0].name = VIEW_ROOT
    raw = OUT_DIR/(model_name(element, True)+'.XMODEL_EXPORT')
    m.WriteFile_Raw(str(raw))
    subprocess.run([str(EXPORT2BIN), '/nt=8', '/o=.', raw.name], cwd=OUT_DIR, check=True, capture_output=True)
    out = bin_path(element, True)
    assert out.read_bytes()[:5] == b'*LZ4*', ('export2bin passed the file through', out)
    a, b = pycod_model(src), pycod_model(out)
    assert [x.name for x in b.bones] == [VIEW_ROOT], (element, [x.name for x in b.bones])
    assert [x.name for x in b.materials] == [x.name for x in a.materials], (element, 'material changed')
    for ma, mb in zip(a.meshes, b.meshes):
        va = [tuple(round(c, 4) for c in v.offset) for v in ma.verts]
        vb = [tuple(round(c, 4) for c in v.offset) for v in mb.verts]
        assert va == vb, (element, 'view crystal vertices moved in conversion')
        fa = [tuple((i.vertex, tuple(round(c, 4) for c in i.uv), tuple(round(c, 3) for c in i.normal)) for i in f.indices) for f in ma.faces]
        fb = [tuple((i.vertex, tuple(round(c, 4) for c in i.uv), tuple(round(c, 3) for c in i.normal)) for i in f.indices) for f in mb.faces]
        assert fa == fb, (element, 'view crystal faces changed in conversion')
    assert len(a.meshes) == len(b.meshes)
    return b


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def pycod_model(path):
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from bo6_extraction.install_ice_staff_bo3 import load_pycod
    xm = load_pycod()
    m = xm.Model(); m.LoadFile_Bin(str(path)); return m


def generate():
    origins = {n: f for n, k, f in blocks(ROOT/'source_data'/'tod_staff_origins.gdt')}
    bow = {n: f for n, k, f in blocks(BOW_GDT)}[BOW_MATERIAL]
    assert bow['materialType'] == MATERIAL_TYPE, 'stock bow donor changed materialType'
    assert all(k in bow for k in list(T7_COMMON)+['colorTint', 'colorTint1']), 'T7 key missing from the stock donor'
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    gdt, report = [], {'sources': {}, 'files': {}, 'geometry': {}}
    for el in ELEMENTS:
        c = CRYSTAL[el]
        src = GREYHOUND/c['source']/(c['source']+'_LOD0.XMODEL_BIN')
        report['sources'][str(src)] = sha(src)
        shutil.copyfile(src, bin_path(el))
        m = pycod_model(bin_path(el))
        bones = [b.name for b in m.bones]; mats = [x.name for x in m.materials]
        tris = sum(len(x.faces) for x in m.meshes)
        assert bones == [c['bone']] and mats == [c['material']] and tris == c['triangles'], (el, bones, mats, tris)
        report['geometry'][model_name(el)] = {'bones': bones, 'materials': mats, 'triangles': tris}
        vname = c['source'].replace('_world', '_view')
        vsrc = GREYHOUND/vname/(vname+'_LOD0.XMODEL_BIN')
        report['sources'][str(vsrc)] = sha(vsrc)
        vm = convert_view(el, vsrc)
        report['geometry'][model_name(el, True)] = {'bones': [b.name for b in vm.bones],
            'materials': [x.name for x in vm.materials], 'triangles': sum(len(x.faces) for x in vm.meshes)}
        for view in (False, True):
            xmodel = dict(origins['tod_staff_tip_'+el+('_view' if view else '_world')])
            xmodel['filename'] = 'tod_staff_crystal\\\\'+model_name(el, view)+'.XMODEL_BIN'
            xmodel['skinOverride'] = ''
            gdt.append((model_name(el, view), 'xmodel.gdf', xmodel))
        mat = dict(bow); mat.update(T7_COMMON); mat.update(T7_TINT[el])
        mat.update(GLOW_TINT[el]); mat['scaleRGB'] = GLOW_SCALE[el]
        gdt.append((c['material'], 'material.gdf', mat))
    OUT_GDT.write_text('{\n'+''.join(emit(*a) for a in gdt)+'}\n', encoding='latin1')
    for p in [bin_path(el, v) for el in ELEMENTS for v in (False, True)]+[OUT_GDT]:
        report['files'][p.relative_to(ROOT).as_posix()] = sha(p)
    MANIFEST.write_text(json.dumps(report, indent=2)+'\n')
    print('Staff crystals generated: 2 world + 2 view models, 2 glowing materials ('+MATERIAL_TYPE+').')


def check():
    manifest = json.loads(MANIFEST.read_text())
    for rel, digest in manifest['files'].items():
        assert (ROOT/rel).is_file(), ('staff crystal file missing', rel)
        assert sha(ROOT/rel) == digest, ('staff crystal file changed; re-run build_staff_crystal.py', rel)
    assets = {n: (k, f) for n, k, f in blocks(OUT_GDT)}
    origins = {n: f for n, k, f in blocks(ROOT/'source_data'/'tod_staff_origins.gdt')}
    for el in ELEMENTS:
        c = CRYSTAL[el]
        for view in (False, True):
            kind, xmodel = assets[model_name(el, view)]
            assert kind == 'xmodel.gdf'
            assert xmodel['filename'].replace('\\\\', '/') == 'tod_staff_crystal/'+model_name(el, view)+'.XMODEL_BIN'
            assert (ROOT/'model_export'/'tod_staff_crystal'/(model_name(el, view)+'.XMODEL_BIN')).is_file()
        assert manifest['geometry'][model_name(el, True)]['bones'] == [VIEW_ROOT], \
            (el, 'view crystal root must be the unkeyed VIEW_ROOT (a keyed root ignores its attach tag)')
        kind, mat = assets[c['material']]
        assert kind == 'material.gdf' and mat['materialType'] == MATERIAL_TYPE, (c['material'], 'material type')
        for k, v in T7_COMMON.items():
            if k != 'scaleRGB':
                assert mat[k] == v, (c['material'], k, mat[k], v)
        for k, v in GLOW_TINT[el].items():
            assert mat[k] == v, (c['material'], k, mat[k], v)
        assert mat['scaleRGB'] == GLOW_SCALE[el], (c['material'], 'scaleRGB', mat['scaleRGB'])
        assert float(mat['scaleRGB']) >= GLOW_FLOOR, (c['material'], 'glow floor: scaleRGB', mat['scaleRGB'], GLOW_FLOOR)
        assert mat['colorTint1'] == T7_TINT[el]['colorTint1'], (c['material'], 'retail emissive tint')
        for field in IMAGE_FIELDS:
            img = mat.get(field, '')
            assert img == '' or img.startswith('$') or img == 'i_generic_lookup' or img in OUR_IMAGES, \
                (c['material'], field, img, 'names an image this map does not declare')
    for img in OUR_IMAGES:
        assert img in origins, (img, 'image block missing from tod_staff_origins.gdt')
        base = origins[img]['baseImage'].replace('\\\\', '/')
        if TOOLS.is_dir():
            # Source gates run before sync; retail textures are now owned here.
            assert (ROOT/base).is_file() or (TOOLS/base).is_file(), (img, 'source PNG missing', base)
    techset = TOOLS/'share/raw/techsetdefs_stable/geometry_advanced'/(MATERIAL_TYPE+'.techsetdef')
    if TOOLS.is_dir():
        assert techset.is_file(), ('stock techsetdef missing', techset)
    print('Staff crystal OK: fire + lightning crystals (world + view, view root '+VIEW_ROOT+') on '+MATERIAL_TYPE
          +', glow scaleRGB '+'/'.join(GLOW_SCALE[e] for e in ELEMENTS)+' (floor '+str(GLOW_FLOOR)+'), hashes pinned.')


if __name__ == '__main__':
    check() if '--check' in sys.argv else generate()
