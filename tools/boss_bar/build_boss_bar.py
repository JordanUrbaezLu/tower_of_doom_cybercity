"""THE WARDEN KING'S BOSS BAR - the art (v19.76).

Lead tester Nikolai, Oct 2026: "introducing a dedicated Boss HP bar across the top
of the screen would immediately communicate that this is a true final boss fight".
The user, approving it: "I think you can make the assets yourself" - so this script
IS the art source: two PNGs drawn in the King banner's own language
(i_tod_king_banner.png: a red grid plate, a gold-to-red neon border, a neon crown,
the name in white condensed caps with a glow).

  i_tod_boss_bar.png       1024x128  the plate: crown + "THE WARDEN KING" + the
                                     empty trough, phase ticks at 2/3 and 1/3
                                     (his phases turn at 66% and 33% health)
  i_tod_boss_bar_fill.png   920x40   the fill, wiped left->right by uie_wipe_normal
                                     (the mana bar's material) over the trough

LOCKSTEP: tod_upgrade.lua's KING BAR block draws the plate at KB_X..KB_X+KB_W /
KB_Y..KB_Y+KB_H and the fill over the trough's inner rectangle, scaled by
KB_W / PLATE_W. `--check` re-derives those canvas numbers from the constants below
and fails if the Lua disagrees, or if either PNG drifted from what this script
draws (sha256 manifest beside the images).

Usage:  python tools/boss_bar/build_boss_bar.py            (writes both PNGs + manifest)
        python tools/boss_bar/build_boss_bar.py --check    (build gate: no writes)
"""
import hashlib
import io
import json
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..'))
IMG_DIR = os.path.join(ROOT, 'source_data', 'tod_ui_images', '_images')
MANIFEST = os.path.join(os.path.dirname(__file__), 'manifest.json')
LUA = os.path.join(ROOT, 'ui', 'uieditor', 'menus', 'hud', 'tod_upgrade.lua')
FONT = r'C:\Windows\Fonts\bahnschrift.ttf'

PLATE_W, PLATE_H = 1024, 128
FILL_W, FILL_H = 920, 40          # aspect 23.0 == the trough's inner rect (874 x 38)
# the plate's own rectangle inside the canvas (art px)
P_X1, P_Y1, P_X2, P_Y2 = 6, 10, 1018, 118
# the trough, art px: the outer edge, and the inner rect the fill covers
T_X1, T_Y1, T_X2, T_Y2 = 124, 62, 1004, 108
TI_X1, TI_Y1, TI_X2, TI_Y2 = 127, 66, 1001, 104   # inner (inside the 3 px stroke)
# the crown emblem's box
C_X1, C_Y1, C_X2, C_Y2 = 22, 18, 112, 110
# on-screen: the plate at KB_X..KB_X+KB_W, KB_Y..KB_Y+KB_H (1280x720 canvas)
KB_X, KB_Y, KB_W, KB_H = 384, 8, 512, 64
S = KB_W / PLATE_W                 # art px -> canvas units (0.5)

GOLD = (255, 212, 71)
RED = (255, 59, 59)
WHITE = (242, 244, 248)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def canvas_fill_rect():
    """The fill element's canvas rectangle (what the Lua must draw)."""
    return (KB_X + TI_X1 * S, KB_Y + TI_Y1 * S, KB_X + TI_X2 * S, KB_Y + TI_Y2 * S)


def gradient_stroke_mask(size, box, radius, width):
    m = Image.new('L', size, 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle(box, radius=radius, outline=255, width=width)
    return m


def h_gradient(size, stops):
    """A horizontal colour ramp across the canvas width (RGB)."""
    w, h = size
    row = Image.new('RGB', (w, 1))
    px = row.load()
    for x in range(w):
        t = x / (w - 1)
        for i in range(len(stops) - 1):
            t0, c0 = stops[i]
            t1, c1 = stops[i + 1]
            if t0 <= t <= t1:
                px[x, 0] = lerp(c0, c1, (t - t0) / (t1 - t0) if t1 > t0 else 0)
                break
    return row.resize((w, h))


def neon(layer_mask, color, glow_radius, glow_gain, size):
    """Colour a mask and add a soft glow under it. Returns an RGBA image."""
    out = Image.new('RGBA', size, (0, 0, 0, 0))
    glow = layer_mask.filter(ImageFilter.GaussianBlur(glow_radius))
    glow = glow.point(lambda v: min(255, int(v * glow_gain)))
    if isinstance(color, Image.Image):
        col = color
    else:
        col = Image.new('RGB', size, color)
    g = col.copy()
    g.putalpha(glow)
    out = Image.alpha_composite(out, g)
    c = col.copy()
    c.putalpha(layer_mask)
    return Image.alpha_composite(out, c)


def draw_plate():
    size = (PLATE_W, PLATE_H)
    img = Image.new('RGBA', size, (0, 0, 0, 0))

    # 1. the body: a dark red-black gradient, top to bottom, like the banner
    body = Image.new('RGBA', size, (0, 0, 0, 0))
    grad = Image.new('RGB', (1, PLATE_H))
    for y in range(PLATE_H):
        grad.putpixel((0, y), lerp((22, 3, 6), (58, 9, 13), y / (PLATE_H - 1)))
    grad = grad.resize(size)
    mask = Image.new('L', size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((P_X1, P_Y1, P_X2, P_Y2), radius=16, fill=236)
    grad_rgba = grad.convert('RGBA')
    grad_rgba.putalpha(mask)
    body = Image.alpha_composite(body, grad_rgba)

    # 2. the red grid (the banner's floor grid, flat here), clipped to the body
    grid = Image.new('L', size, 0)
    gd = ImageDraw.Draw(grid)
    for x in range(P_X1 + 12, P_X2, 24):
        gd.line((x, P_Y1, x, P_Y2), fill=46, width=1)
    for y in range(P_Y1 + 10, P_Y2, 24):
        gd.line((P_X1, y, P_X2, y), fill=46, width=1)
    grid = Image.composite(grid, Image.new('L', size, 0), mask)
    red_layer = Image.new('RGBA', size, RED + (0,))
    red_layer.putalpha(grid)
    body = Image.alpha_composite(body, red_layer)
    img = Image.alpha_composite(img, body)

    # 3. the neon border: gold at the crown end to red at the far end
    ramp = h_gradient(size, [(0.0, GOLD), (0.45, (255, 150, 60)), (1.0, RED)])
    stroke = gradient_stroke_mask(size, (P_X1, P_Y1, P_X2, P_Y2), 16, 3)
    img = Image.alpha_composite(img, neon(stroke, ramp, 5, 2.2, size))

    # 4. the crown (the banner's neon crown, redrawn as lines): five points with
    #    dots at the tips, a band beneath, gold over red
    cm = Image.new('L', size, 0)
    cd = ImageDraw.Draw(cm)
    cx1, cy1, cx2, cy2 = C_X1, C_Y1, C_X2, C_Y2
    w = cx2 - cx1
    band_top = cy1 + int((cy2 - cy1) * 0.70)
    pts = [
        (cx1 + 6, band_top),
        (cx1 + 2, cy1 + 26),
        (cx1 + int(w * 0.30), cy1 + 52),
        (cx1 + int(w * 0.50), cy1 + 8),
        (cx1 + int(w * 0.70), cy1 + 52),
        (cx2 - 2, cy1 + 26),
        (cx2 - 6, band_top),
    ]
    cd.line(pts, fill=255, width=4, joint='curve')
    cd.rectangle((cx1 + 6, band_top + 4, cx2 - 6, cy2 - 4), outline=255, width=4)
    for (px, py) in (pts[1], pts[3], pts[5]):
        cd.ellipse((px - 6, py - 6, px + 6, py + 6), fill=255)
    for (px, py) in (pts[2], pts[4]):
        cd.ellipse((px - 4, py - 4, px + 4, py + 4), fill=255)
    crown_ramp = Image.new('RGB', size, GOLD)
    img = Image.alpha_composite(img, neon(cm, crown_ramp, 6, 2.6, size))

    # 5. the name, white condensed caps with a soft white glow (the banner's title)
    font = ImageFont.truetype(FONT, 42)
    font.set_variation_by_axes([700, 75])   # Bahnschrift Bold Condensed (Weight 700, Width 75)
    tm = Image.new('L', size, 0)
    td = ImageDraw.Draw(tm)
    text = 'THE WARDEN KING'
    # letter-spaced by hand: draw glyph by glyph. The CAP top is seated at y 20,
    # clear of the border's stroke + glow (10..16) and the phase ticks (56..62).
    cap_top = font.getbbox('T')[1]
    x, base_top = T_X1 + 2, 20 - cap_top
    for ch in text:
        td.text((x, base_top), ch, font=font, fill=255)
        x += font.getlength(ch) + 3
    img = Image.alpha_composite(img, neon(tm, WHITE, 4, 1.6, size))

    # 6. the trough: near-black, a red inner stroke, gold phase ticks at 2/3 and 1/3
    tr = Image.new('RGBA', size, (0, 0, 0, 0))
    trd = ImageDraw.Draw(tr)
    trd.rounded_rectangle((T_X1, T_Y1, T_X2, T_Y2), radius=6, fill=(9, 2, 4, 246), outline=(122, 16, 22, 255), width=3)
    img = Image.alpha_composite(img, tr)
    ticks = Image.new('L', size, 0)
    tkd = ImageDraw.Draw(ticks)
    for frac in (1.0 / 3.0, 2.0 / 3.0):
        tx = int(round(TI_X1 + (TI_X2 - TI_X1) * frac))
        tkd.line((tx, T_Y1 - 6, tx, T_Y1 + 4), fill=255, width=3)
        tkd.line((tx, T_Y2 - 4, tx, T_Y2 + 6), fill=255, width=3)
    img = Image.alpha_composite(img, neon(ticks, GOLD, 3, 2.0, size))
    return img


def draw_fill():
    size = (FILL_W, FILL_H)
    # left (low health) deep red -> right (full) orange-gold; the wipe reveals it
    # from the left, so a dying King reads red
    ramp = h_gradient(size, [(0.0, (196, 18, 26)), (0.55, (240, 70, 36)), (1.0, (255, 176, 58))])
    img = ramp.convert('RGBA')
    px = img.load()
    for y in range(FILL_H):
        # vertical light: a hot top band, a darker foot
        k = 1.0
        if y < 3:
            k = 1.55
        elif y < 9:
            k = 1.22
        elif y > FILL_H - 8:
            k = 0.72
        for x in range(FILL_W):
            r, g, b, a = px[x, y]
            # thin diagonal hatch, the HUD's cyber texture
            if ((x + y) // 6) % 4 == 0:
                r, g, b = int(r * 0.86), int(g * 0.86), int(b * 0.86)
            px[x, y] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), 255)
    return img


def png_bytes(img):
    buf = io.BytesIO()
    img.save(buf, format='PNG', optimize=True)
    return buf.getvalue()


def lua_numbers():
    src = open(LUA, encoding='utf-8').read()
    m = re.search(r'local KB_X, KB_Y, KB_W, KB_H = (\d+), (\d+), (\d+), (\d+)', src)
    f = re.search(r'local KB_FX1, KB_FY1, KB_FX2, KB_FY2 = ([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+)', src)
    return m, f


def main():
    check = '--check' in sys.argv
    outs = {'i_tod_boss_bar.png': png_bytes(draw_plate()), 'i_tod_boss_bar_fill.png': png_bytes(draw_fill())}
    fx = canvas_fill_rect()
    errors = []
    m, f = lua_numbers()
    if not m or tuple(int(v) for v in m.groups()) != (KB_X, KB_Y, KB_W, KB_H):
        errors.append('tod_upgrade.lua KB_X/KB_Y/KB_W/KB_H != %s' % ((KB_X, KB_Y, KB_W, KB_H),))
    if not f or any(abs(float(a) - b) > 0.01 for a, b in zip(f.groups(), fx)):
        errors.append('tod_upgrade.lua KB_FX1..KB_FY2 != %s (the trough inner rect at scale %.3f)' % (tuple(round(v, 2) for v in fx), S))
    if abs((TI_X2 - TI_X1) / (TI_Y2 - TI_Y1) - FILL_W / FILL_H) > 0.05:
        errors.append('the fill art aspect drifted from the trough inner rect')
    for n in ('i_tod_boss_bar.png', 'i_tod_boss_bar_fill.png'):
        im = Image.open(io.BytesIO(outs[n]))
        if im.size[0] % 4 or im.size[1] % 4:
            errors.append('%s is not divisible by 4 (compressed high color needs 4x4 blocks)' % n)
    if check:
        try:
            man = json.load(open(MANIFEST, encoding='utf-8'))
        except Exception:
            man = {}
        for n in outs:
            p = os.path.join(IMG_DIR, n)
            if not os.path.exists(p):
                errors.append('missing ' + p)
                continue
            have = hashlib.sha256(open(p, 'rb').read()).hexdigest()
            if man.get(n) != have:
                errors.append('%s sha256 != manifest (hand-edited or not re-run)' % n)
        if errors:
            for e in errors:
                print('BOSS BAR CHECK FAIL: ' + e)
            sys.exit(1)
        print('boss bar: both PNGs match the manifest, the Lua layout matches the art (fill at %s)' % (tuple(round(v, 2) for v in fx),))
        return
    if errors and any('tod_upgrade.lua' not in e for e in errors):
        for e in errors:
            print('BOSS BAR FAIL: ' + e)
        sys.exit(1)
    man = {}
    for n, b in outs.items():
        open(os.path.join(IMG_DIR, n), 'wb').write(b)
        man[n] = hashlib.sha256(b).hexdigest()
    with open(MANIFEST, 'w', encoding='utf-8', newline='\n') as fh:
        json.dump(man, fh, indent=2)
        fh.write('\n')
    print('wrote', ', '.join(outs))
    print('Lua layout: local KB_X, KB_Y, KB_W, KB_H = %d, %d, %d, %d' % (KB_X, KB_Y, KB_W, KB_H))
    print('Lua layout: local KB_FX1, KB_FY1, KB_FX2, KB_FY2 = %s, %s, %s, %s' % tuple(('%.2f' % v).rstrip('0').rstrip('.') for v in fx))
    for e in errors:
        print('note (expected until the Lua is written): ' + e)


if __name__ == '__main__':
    main()
