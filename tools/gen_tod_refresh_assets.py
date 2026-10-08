#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# gen_tod_refresh_assets.py - the SURFACE REFRESH's own art and materials
# (2026-10-02, docs/169; user: "small visual enhancements ... to the walls,
# floors, ceilings ... on either tower ... a minor redesign").
#
# Writes (and with --check, re-derives in memory and FAILS if disk differs):
#   source_data/tod_refresh/_images/tod_rf_riser.png     the stair light-strip
#       profile: a greyscale band read UP the riser face, mapped at exactly one
#       repeat per visible riser (12 units), a soft body + a light line through
#       its middle - symmetric, so the engine's wall V direction cannot flip it.
#       The material's colorTint1 gives it the district colour.
#   source_data/tod_refresh/_images/tod_rf_floornum.png  the floor-number atlas:
#       the map's OWN HUD digits (source_data/tod_ui_images/_sheets/
#       i_tod_hud_digits.png, the typeface every number on the HUD is drawn in),
#       white fill only - outline and drop shadow stripped - 10 cells of 192 x
#       256 in a 2048 x 256 strip, RGBA (alpha = the glyph), plus a soft halo in
#       the alpha so the numeral reads at a glance on a dim floor.
#   source_data/tod_refresh.gdt  two image blocks + 12 materials:
#       tod_rf_riser_<hue>     blue/green/orange/yellow/red (the tower's five
#                              districts) - a CLONE of tod_door_blue (the matte
#                              vertigo clone: lit_emissive_advanced, specular and
#                              probe reflection zeroed) with this image + tint
#       tod_rf_riser_spire     the spire's red, a notch hotter (it is fogged)
#       tod_rf_floornum_<hue>  the five districts + _spire - CLONES of the
#                              DOGCANARY decal arrow_power_coldwar1 (the proven
#                              chalk-mesh decal: lit_emissive_scroll_transparent,
#                              usage decal) with the atlas + tint
# ONE NEW GDT FILE, so the whole refresh comes off with the generator switches
# (gen_tower_map.js RF_* / env TOD_REFRESH) and nothing here needs deleting: an
# unreferenced material is converted by gdtdb and never linked.
#
# Usage: python tools/gen_tod_refresh_assets.py           (write)
#        python tools/gen_tod_refresh_assets.py --check   (build gate)
# -----------------------------------------------------------------------------
import argparse
import io
import os
import re
import sys

import numpy as np
from PIL import Image, ImageFilter

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODTOOLS = os.environ.get('TOD_MODTOOLS', r'C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130')
IMG_DIR = os.path.join(REPO, 'source_data', 'tod_refresh', '_images')
GDT_OUT = os.path.join(REPO, 'source_data', 'tod_refresh.gdt')
DIGITS_SHEET = os.path.join(REPO, 'source_data', 'tod_ui_images', '_sheets', 'i_tod_hud_digits.png')
TEMPLATE_OPAQUE = (os.path.join(REPO, 'source_data', 'tod_materials.gdt'), 'tod_door_blue')
TEMPLATE_OPAQUE_IMG = (os.path.join(REPO, 'source_data', 'tod_materials.gdt'), 'tod_hall_crest_1_e')
DECAL_GDT = os.path.join(MODTOOLS, 'model_export', 'codimages', 'arrow_coldwar_dogcanary', 'arrow_power_coldwar_dogcanary.gdt')
TEMPLATE_DECAL = (DECAL_GDT, 'arrow_power_coldwar1')
TEMPLATE_DECAL_IMG = (DECAL_GDT, 'i_arrow_power_coldwar1_c1')

# --- the colours ---------------------------------------------------------------
# The vertigo pack's own colorTint1 for each district's PLAIN hue (the brightest,
# least saturated member of each family - read out of emox_mwiii_vertigo_assets.gdt
# 2026-10-02), so a riser is unmistakably the same colour as the rails beside it.
DISTRICT_TINT = {
    'blue':   (0.372549, 0.726848, 1.0),
    'green':  (0.372549, 1.0, 0.372549),
    'orange': (1.0, 0.472251, 0.184314),
    'yellow': (1.0, 0.918853, 0.372549),
    'red':    (1.0, 0.0431373, 0.0431373),
}
# RISER brightness. The tread beside it is `_tinted` (fill ~0.22 x 10) on odd
# floors and `_tinted_edge` (x 5) on even ones; the riser's body (0.42 of the
# image) x RISER_SCALE sits a little over the brighter tread and its hot line
# (1.0) is the brightest edge on the stair - a light strip, not a floodlight
# (the user's v17.82 / v18.97 calls on glare apply here too). ONE KNOB.
RISER_SCALE = 5.0
RISER_SCALE_SPIRE = 6.0          # the spire's red fog eats a third of it at arm's length
# FLOOR NUMBERS: a painted-light numeral on a dim floor. The DOGCANARY power
# signs run at 16 on a dark-aether texture; a solid glyph needs far less.
FLOORNUM_SCALE = 8.0
FLOORNUM_SCALE_SPIRE = 9.0
SPIRE_TINT = (1.0, 0.16, 0.10)    # a hotter red than the pack's (1, .04, .04): it has to read through red fog

# --- the riser profile -----------------------------------------------------------
RISER_W, RISER_H = 64, 64
def riser_image():
    # ONE REPEAT = THE VISIBLE RISER. The generator maps this image at 12 world
    # units per repeat with no offset (RF_RISER_V): every tread top on both towers
    # is a multiple of 12 (laps are 384 = 32 x 12, treads rise 12), so the visible
    # 12-unit riser holds exactly one copy whichever way the engine runs its wall
    # V axis (+z or -z - unverified on this map, docs/110 left it open for the
    # crests). The design is therefore SYMMETRIC top-to-bottom: a soft body and a
    # light LINE through the middle of the step face - an LED strip per step.
    t = (np.arange(RISER_H) + 0.5) / RISER_H                  # 0..1 across the riser
    d = np.abs(t - 0.5) / 0.5                                 # 0 at the centre line -> 1 at the edges
    line = np.exp(-(d / 0.16) ** 2)                           # the strip: ~2.4 world units, soft shoulders
    v = 0.30 + 0.70 * line - 0.06 * d                         # body 0.24..0.30, line 1.0
    a = np.repeat(v[:, None], RISER_W, axis=1)
    rgb = (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb, rgb, rgb]), 'RGB')

# --- the floor-number atlas --------------------------------------------------------
CELL_W, CELL_H, ATLAS_W, ATLAS_H = 192, 256, 2048, 256
def floornum_image():
    sheet = np.asarray(Image.open(DIGITS_SHEET).convert('RGBA')).astype(np.float32) / 255.0
    cw, ch = 128, 160                                         # slice_hud_sheets.js: digits cw 128 ch 160, 13 cols
    atlas = np.zeros((ATLAS_H, ATLAS_W, 4), np.float32)
    for d in range(10):
        cell = sheet[:, d * cw:(d + 1) * cw]
        r, g, b, a = cell[..., 0], cell[..., 1], cell[..., 2], cell[..., 3]
        lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        sat = cell[..., :3].max(axis=2) - cell[..., :3].min(axis=2)
        # the glyph's FILL is near-white (~0.90..0.97) and unsaturated; the drop
        # shadow is a saturated blue, the outline near-black - keep the fill only
        fill = np.clip((lum - 0.62) / 0.18, 0, 1) * np.clip((0.30 - sat) / 0.12, 0, 1) * a
        im = Image.fromarray((fill * 255).astype(np.uint8), 'L')
        sc = 1.18
        im = im.resize((int(cw * sc), int(ch * sc)), Image.LANCZOS)
        im = im.crop(im.getbbox())                            # tight to the ink ...
        PAD = 18                                              # ... then padded, so the halo blur is never cut at the ink's box
        padded = Image.new('L', (im.width + 2 * PAD, im.height + 2 * PAD), 0)
        padded.paste(im, (PAD, PAD))
        im = padded
        if im.width > CELL_W or im.height > CELL_H:
            sys.exit(f'digit {d}: {im.width}x{im.height} does not fit its {CELL_W}x{CELL_H} cell')
        halo = im.filter(ImageFilter.GaussianBlur(8))
        g_np = np.asarray(im).astype(np.float32) / 255.0
        h_np = np.asarray(halo).astype(np.float32) / 255.0
        x0 = d * CELL_W + (CELL_W - im.width) // 2
        y0 = (CELL_H - im.height) // 2
        alpha = np.maximum(g_np, h_np * 0.28)                 # the glyph + a faint glow skirt
        lum_out = np.clip(g_np * 1.0 + h_np * 0.55, 0, 1)
        atlas[y0:y0 + im.height, x0:x0 + im.width, 3] = alpha
        for c in range(3):
            atlas[y0:y0 + im.height, x0:x0 + im.width, c] = lum_out
    return Image.fromarray((np.clip(atlas, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA')

# --- GDT ----------------------------------------------------------------------------------
def block(path, name):
    text = open(path, encoding='utf-8', errors='replace').read()
    # the opening brace is tab-indented in most GDTs and at column 0 in the
    # generated door blocks; normalise it so every block written here is alike
    m = re.search(r'(\t"' + re.escape(name) + r'" \( "(?:material|image)\.gdf" \)\n)[ \t]*\{\n(.*?\n\t\})', text, re.S)
    if not m:
        sys.exit(f'template block {name} not found in {path}')
    return m.group(1) + '\t{\n' + m.group(2)

def setkv(blk, key, val):
    pat = re.compile(r'(\n\t\t"' + re.escape(key) + r'" )"[^"]*"')
    if not pat.search(blk):
        sys.exit(f'template has no "{key}"')
    return pat.sub(lambda m: m.group(1) + f'"{val}"', blk, count=1)

def rename(blk, old, new):
    return blk.replace(f'\t"{old}" (', f'\t"{new}" (', 1)

def fmt_tint(t):
    return ' '.join(f'{v:.6g}' for v in t) + ' 1'

def gdt_text():
    out = ['{']
    out.append('\t// ---- GENERATED by tools/gen_tod_refresh_assets.py - do not hand-edit (docs/169) ----')
    img_o = block(*TEMPLATE_OPAQUE_IMG)
    img_o = rename(img_o, TEMPLATE_OPAQUE_IMG[1], 'tod_rf_riser_e')
    img_o = setkv(img_o, 'baseImage', 'source_data/tod_refresh/_images/tod_rf_riser.png')
    out.append(img_o)
    img_d = block(*TEMPLATE_DECAL_IMG)
    img_d = rename(img_d, TEMPLATE_DECAL_IMG[1], 'tod_rf_floornum_c')
    img_d = setkv(img_d, 'baseImage', 'source_data/tod_refresh/_images/tod_rf_floornum.png')
    out.append(img_d)
    mat_o = block(*TEMPLATE_OPAQUE)
    mat_d = block(*TEMPLATE_DECAL)
    for hue, tint in list(DISTRICT_TINT.items()) + [('spire', SPIRE_TINT)]:
        m = rename(mat_o, TEMPLATE_OPAQUE[1], f'tod_rf_riser_{hue}')
        m = setkv(m, 'colorMap00', 'tod_rf_riser_e')
        m = setkv(m, 'colorTint1', fmt_tint(tint))
        m = setkv(m, 'scaleRGB', f'{RISER_SCALE_SPIRE if hue == "spire" else RISER_SCALE:.1f}')
        out.append(m)
    for hue, tint in list(DISTRICT_TINT.items()) + [('spire', SPIRE_TINT)]:
        # a numeral reads paler than a stripe: lift it 30% toward white
        nt = tuple(0.70 * c + 0.30 for c in tint)
        m = rename(mat_d, TEMPLATE_DECAL[1], f'tod_rf_floornum_{hue}')
        m = setkv(m, 'colorMap', 'tod_rf_floornum_c')
        m = setkv(m, 'colorMap00', 'tod_rf_floornum_c')
        m = setkv(m, 'colorTint1', fmt_tint(nt))
        m = setkv(m, 'scaleRGB', f'{FLOORNUM_SCALE_SPIRE if hue == "spire" else FLOORNUM_SCALE:.1f}')
        # The donor's technique compiles USE_EMISSIVE_FLICKER (lit_emissive_scroll_transparent
        # .techsetdef, technique "lit") and the arrow ships flickerMin 0 / flickerMax 1 - a neon
        # flicker on the POWER signs. A floor number should hold steady: a range of [1, 1] is
        # constant whatever the (unshipped) shader does with the lookup.
        m = setkv(m, 'flickerMin', '1')
        out.append(m)
    out.append('\t// ---- END GENERATED ----')
    out.append('}')
    return '\n'.join(out) + '\n'

def png_bytes(im):
    b = io.BytesIO()
    im.save(b, 'PNG', optimize=False, compress_level=9)
    return b.getvalue()

def check_generator_crops(atlas_png_bytes):
    # LOCKSTEP: gen_tower_map.js crops each digit out of its atlas cell with
    # FLOORNUM_INK / FLOORNUM_ROWS. A crop that cuts the ink would print a clipped
    # numeral on 120 landings with no other warning, so measure the ink here.
    g = open(os.path.join(REPO, 'tools', 'gen_tower_map.js'), encoding='utf-8').read()
    m = re.search(r'const FLOORNUM_INK = (\[\[.*?\]\]);', g)
    r = re.search(r'const FLOORNUM_ROWS = \[(\d+), (\d+)\];', g)
    c = re.search(r'const FLOORNUM_CELL = (\d+), FLOORNUM_ATLAS = (\d+), FLOORNUM_CELL_H = (\d+);', g)
    if not (m and r and c):
        return ['gen_tower_map.js FLOORNUM_INK / FLOORNUM_ROWS / FLOORNUM_CELL not found']
    import json
    ink = json.loads(m.group(1)); rows = (int(r.group(1)), int(r.group(2)))
    cell, atlas_w, cell_h = (int(v) for v in c.groups())
    if (cell, atlas_w, cell_h) != (CELL_W, ATLAS_W, CELL_H):
        return [f'atlas geometry {cell}/{atlas_w}/{cell_h} != {CELL_W}/{ATLAS_W}/{CELL_H}']
    a = np.asarray(Image.open(io.BytesIO(atlas_png_bytes)))[..., 3]
    errs = []
    for d in range(10):
        cellA = a[:, d * CELL_W:(d + 1) * CELL_W]
        cols = np.where(cellA.max(axis=0) > 40)[0]; rws = np.where(cellA.max(axis=1) > 40)[0]
        x0, x1 = ink[d]
        if cols.min() < x0 + 6 or cols.max() > x1 - 6:
            errs.append(f'digit {d}: ink x {cols.min()}..{cols.max()} not inside crop {x0}..{x1} with 6 px to spare')
        if rws.min() < rows[0] + 6 or rws.max() > rows[1] - 6:
            errs.append(f'digit {d}: ink rows {rws.min()}..{rws.max()} not inside crop {rows[0]}..{rows[1]} with 6 px to spare')
    return errs

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true')
    a = ap.parse_args()
    files = {
        os.path.join(IMG_DIR, 'tod_rf_riser.png'): png_bytes(riser_image()),
        os.path.join(IMG_DIR, 'tod_rf_floornum.png'): png_bytes(floornum_image()),
        GDT_OUT: gdt_text().encode('utf-8'),
    }
    bad = []
    crop_errs = check_generator_crops(files[os.path.join(IMG_DIR, 'tod_rf_floornum.png')])
    for e in crop_errs:
        print('  LOCKSTEP:', e)
    for p, data in files.items():
        if a.check:
            if not os.path.exists(p) or open(p, 'rb').read() != data:
                bad.append(os.path.relpath(p, REPO))
        else:
            os.makedirs(os.path.dirname(p), exist_ok=True)
            if not os.path.exists(p) or open(p, 'rb').read() != data:
                open(p, 'wb').write(data)
                print('wrote', os.path.relpath(p, REPO), len(data), 'B')
            else:
                print('unchanged', os.path.relpath(p, REPO))
    if crop_errs:
        print('gen_tod_refresh_assets FAILED - the digit crops in gen_tower_map.js do not hold the atlas ink')
        sys.exit(1)
    if a.check:
        if bad:
            print('gen_tod_refresh_assets --check FAILED - stale or missing: ' + ', '.join(bad))
            sys.exit(1)
        print(f'gen_tod_refresh_assets --check OK ({len(files)} files: riser profile, floor-number atlas, tod_refresh.gdt)')

if __name__ == '__main__':
    main()
