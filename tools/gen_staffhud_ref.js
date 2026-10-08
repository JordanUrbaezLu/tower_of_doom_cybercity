// =============================================================================
// Build docs/124_hud_ref/staff_style_gap.html — the "brief in one picture" for
// the three MAGE STAFF weapon icons (docs/124).
//
// The three staff cells shipped v18.43 out of the docs/120 mage drop, drawn in
// the same pass as 25 CARDS rather than beside the 28 gun icons they sit with
// on the HUD. They came back off-house-style in three ways that are MEASURED,
// not felt — this board puts the numbers and the A/B side by side so the next
// pass has nothing to guess at.
//
// ⚠️ THE SHIPPED BOARD IS A **BEFORE** SNAPSHOT AND MUST NOT BE REGENERATED.
// This reads `_images/`, and docs/124's re-bake LANDED (v18.58, 2026-09-09):
// running it now measures the NEW cells and overwrites the picture that made
// the case for changing them. Kept because it is the recipe for the next such
// audit — point IMG at a drop folder to measure one before installing it.
//
//   node tools/gen_staffhud_ref.js
//   & "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --headless=new \
//       --screenshot=docs\124_hud_ref\staff_style_gap.png --window-size=1500,3560 \
//       --hide-scrollbars file:///<abs>/docs/124_hud_ref/staff_style_gap.html
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const REPO = path.resolve(__dirname, '..');
const IMG  = path.join(REPO, 'source_data', 'tod_ui_images', '_images');
const REF  = path.join(REPO, 'docs', '124_hud_ref');
const OUT  = path.join(REF, 'staff_style_gap.html');

// The gun icon draws into a 96 x 44 LUI box; the loadout panel is not under
// TodScaleHud, so at 1920x1080 that is 144 x 66 real pixels off a 288 x 132
// source. Same size the docs/98 and docs/99 boards previewed at.
const DW = 144, DH = 66;

const GUNS = ['mac10', 'mp5', 'mp7', 'bulldog', 'sg12', 'spas12', 'enfield',
              'krig6', 'ak47', 'magnum', 'mog12', 'executioner', 'stoner63', 'hk21',
              'minigun', 'mr6', 'launcher', 'nailgun', 'blade', 'katana', 'axe',
              'amp63', 'udm', 'rk7', 'executioner_akimbo', 'amp63_akimbo', 'gift', 'shield'];

const uri = slug => 'data:image/png;base64,' +
  fs.readFileSync(path.join(IMG, 'i_tod_hud_gun_' + slug + '.png')).toString('base64');

// ---------------------------------------------------------------------------
// minimal PNG decode (8-bit RGBA, non-interlaced) — same codec as the slicer
// ---------------------------------------------------------------------------
function decodePNG(file) {
  const b = fs.readFileSync(file);
  let o = 8, w, h, ct, depth, il;
  const idat = [];
  while (o < b.length) {
    const len = b.readUInt32BE(o), t = b.toString('ascii', o + 4, o + 8);
    const d = b.slice(o + 8, o + 8 + len);
    if (t === 'IHDR') { w = d.readUInt32BE(0); h = d.readUInt32BE(4); depth = d[8]; ct = d[9]; il = d[12]; }
    else if (t === 'IDAT') idat.push(d);
    else if (t === 'IEND') break;
    o += 12 + len;
  }
  if (depth !== 8 || ct !== 6 || il !== 0) throw new Error(file + ': unsupported PNG');
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const st = w * 4, out = Buffer.alloc(h * st);
  let p = 0;
  for (let y = 0; y < h; y++) {
    const ft = raw[p++], ln = raw.slice(p, p + st); p += st;
    for (let x = 0; x < st; x++) {
      const a = x >= 4 ? out[y * st + x - 4] : 0;
      const bb = y > 0 ? out[(y - 1) * st + x] : 0;
      const c = (x >= 4 && y > 0) ? out[(y - 1) * st + x - 4] : 0;
      let v = ln[x];
      if (ft === 1) v += a; else if (ft === 2) v += bb; else if (ft === 3) v += (a + bb) >> 1;
      else if (ft === 4) {
        const pp = a + bb - c, pa = Math.abs(pp - a), pb = Math.abs(pp - bb), pc = Math.abs(pp - c);
        v += (pa <= pb && pa <= pc) ? a : (pb <= pc ? bb : c);
      }
      out[y * st + x] = v & 255;
    }
  }
  return { w: w, h: h, d: out };
}

// ink coverage, bright-saturated share, and how many tones carry >=2% of the ink
function stat(slug) {
  const im = decodePNG(path.join(IMG, 'i_tod_hud_gun_' + slug + '.png'));
  const w = im.w, h = im.h, d = im.d;
  let ink = 0, satHi = 0;
  const cols = new Map();
  for (let i = 0; i < w * h; i++) {
    const o = i * 4;
    if (d[o + 3] < 128) continue;
    ink++;
    const r = d[o], g = d[o + 1], b = d[o + 2];
    const mx = Math.max(r, g, b), mn = Math.min(r, g, b);
    if (mx > 90 && (mx - mn) / mx > 0.40) satHi++;
    const k = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
    cols.set(k, (cols.get(k) || 0) + 1);
  }
  let tones = 0;
  cols.forEach(function (n) { if (n > ink * 0.02) tones++; });
  return { ink: 100 * ink / (w * h), sat: 100 * satHi / ink, tones: tones };
}

const S = {};
GUNS.concat(['staff1', 'staff2', 'staff3']).forEach(g => { S[g] = stat(g); });
const mean = k => GUNS.reduce((a, g) => a + S[g][k], 0) / GUNS.length;
const M = { ink: mean('ink'), sat: mean('sat'), tones: mean('tones') };
const num = (v, dp) => v.toFixed(dp === undefined ? 1 : dp);

const STAFF = [
  ['staff1', 'LIGHTNING', 'two upswept prongs like antlers, a jagged bolt between the tips'],
  ['staff2', 'FIRE',      'heavy inward-curling horns cradling a round stone'],
  ['staff3', 'ICE',       'a fan of angular crystal shards, a frozen arrowhead'],
];
const NEIGHBOURS = ['katana', 'axe', 'blade'];

const cell = (slug, s) =>
  '<img class="cel" src="' + uri(slug) + '" style="width:' + (DW * (s || 1)) +
  'px;height:' + (DH * (s || 1)) + 'px">';

const row = (slug, name, note) =>
  '<tr><td class="nm">' + name + '</td><td class="lit">' + cell(slug) +
  '</td><td class="lit">' + cell(slug, 2) + '</td><td class="no">' + note + '</td></tr>';

const html = '<!doctype html><meta charset="utf-8"><style>' + [
  'body{margin:0;background:#0B1020;color:#C8D4EA;font:13px/1.45 "Consolas","DejaVu Sans Mono",monospace;padding:26px 30px}',
  'h1{color:#5BC8FF;font-size:21px;letter-spacing:.09em;margin:0 0 4px}',
  'h2{color:#5BC8FF;font-size:15px;letter-spacing:.09em;margin:30px 0 8px;border-bottom:1px solid #23304d;padding-bottom:5px}',
  'p{margin:5px 0 10px;max-width:1180px}',
  '.sub{color:#7d8db0}',
  '.box{background:#111a2e;border:1px solid #23304d;border-radius:5px;padding:14px 16px;margin:8px 0;display:inline-block}',
  'table{border-collapse:collapse}',
  'td,th{padding:6px 12px;vertical-align:middle;text-align:left}',
  'th{color:#7d8db0;font-weight:400;font-size:11px;letter-spacing:.08em;border-bottom:1px solid #23304d}',
  '.nm{color:#E8EEF6;font-weight:700;letter-spacing:.06em;white-space:nowrap}',
  '.no{color:#9fb0d0;max-width:520px;font-size:12px}',
  '.lit{background:#0A1020}',
  '.cel{display:block}',
  '.grid{display:flex;flex-wrap:wrap;gap:2px;background:#0A1020;padding:8px;border:1px solid #23304d;border-radius:5px;width:1180px}',
  '.g2{display:flex;flex-wrap:wrap;gap:2px;background:#E8EEF6;padding:8px;border:1px solid #23304d;border-radius:5px;width:1180px}',
  '.sw{display:inline-block;width:150px;margin:0 10px 10px 0;vertical-align:top}',
  '.chip{height:52px;border:1px solid #23304d;border-radius:3px}',
  '.hex{font-size:12px;color:#E8EEF6;margin-top:4px}',
  '.rl{font-size:11px;color:#7d8db0}',
  '.bad{color:#FF8A6B}.good{color:#7BE3A8}',
  '.num{text-align:right}',
  '.big{font-size:15px;color:#E8EEF6}',
].join('') + '</style>' + [

  '<h1>MAGE STAFF WEAPON ICONS &mdash; WHAT "CONSISTENT WITH THE GUN ICONS" MEANS, MEASURED</h1>',
  '<p class="sub">The three staff cells are in the game today. They were drawn in a pass of 25 upgrade CARDS, not beside the 28 weapon icons they actually sit with on the HUD, and it shows in three ways that can be counted rather than argued about. Every number below is measured off the shipped PNGs.</p>',

  '<h2>1 &mdash; THE SET YOU ARE JOINING &nbsp;<span class="sub">28 shipped weapon icons, true on-screen size (' + DW + ' &times; ' + DH + ')</span></h2>',
  '<p>One of these is on screen at all times, bottom-right, beside the health bar. Three flat tones, one heavy outline, no colour anywhere in the set.</p>',
  '<div class="grid">' + GUNS.map(g => cell(g)).join('') + '</div>',
  '<p class="sub">The same 28 on a light background &mdash; everything here has to survive both, because the HUD sits over black sky, over glowing neon treads and over a bright fog bank:</p>',
  '<div class="g2">' + GUNS.map(g => cell(g)).join('') + '</div>',

  '<h2>2 &mdash; THE THREE STAFFS TODAY, AND THEIR NEAREST NEIGHBOURS</h2>',
  '<p>Top three are the cells being replaced. Bottom three are the melee icons &mdash; the closest thing in the set to a staff: one long object laid diagonally across the cell.</p>',
  '<div class="box"><table>',
  '<tr><th>cell</th><th>true size</th><th>2&times;</th><th>what is off</th></tr>',
  STAFF.map(s => row(s[0], s[1] + ' (now)',
    '<span class="bad">saturated colour</span> in the head; <span class="bad">5 tones</span> where every gun uses 3; only <span class="bad">' +
    num(S[s[0]].ink) + '%</span> of the cell is inked (set mean ' + num(M.ink) +
    '%) &mdash; it reads thin and faint beside its neighbours.')).join(''),
  NEIGHBOURS.map(g => row(g, g.toUpperCase(),
    '<span class="good">3 tones, no colour, ' + num(S[g].ink) +
    '% ink.</span> This is the target treatment &mdash; a long object, drawn FAT, filling the cell.')).join(''),
  '</table></div>',

  '<h2>3 &mdash; THE NUMBERS</h2>',
  '<div class="box"><table>',
  '<tr><th>cell</th><th class="num">ink coverage</th><th class="num">bright saturated pixels</th><th class="num">tones &ge;2% of ink</th></tr>',
  ['staff1', 'staff2', 'staff3'].map(s =>
    '<tr><td class="nm">' + s + '</td><td class="num bad">' + num(S[s].ink) +
    '%</td><td class="num bad">' + num(S[s].sat) + '%</td><td class="num bad">' +
    S[s].tones + '</td></tr>').join(''),
  '<tr><td class="nm big">the 28 guns, mean</td><td class="num good big">' + num(M.ink) +
  '%</td><td class="num good big">' + num(M.sat) + '%</td><td class="num good big">' +
  num(M.tones) + '</td></tr>',
  '</table></div>',
  '<p><b>Read that middle column again.</b> Across all 28 shipped weapon icons, ' + num(M.sat) +
  '% of inked pixels are a saturated colour &mdash; i.e. none; what little there is comes from the blue-black outline itself. The three staffs are at ' +
  num(Math.min(S.staff1.sat, S.staff2.sat, S.staff3.sat)) + '&ndash;' +
  num(Math.max(S.staff1.sat, S.staff2.sat, S.staff3.sat)) +
  '% &mdash; roughly sixty times the set. <b>The coloured gems are the single biggest thing separating these three cells from the set.</b></p>',

  '<h2>4 &mdash; THE PALETTE IS THREE COLOURS. NOT FOUR, NOT SEVEN.</h2>',
  '<p>Sampled from the shipped sheet. Every one of the 28 icons is built from exactly these, plus antialiasing between them:</p>',
  '<div>',
  '<div class="sw"><div class="chip" style="background:#E8EEF6"></div><div class="hex">#E8EEF6</div><div class="rl">STEEL WHITE &mdash; the face of the object. About half of every icon.</div></div>',
  '<div class="sw"><div class="chip" style="background:#62779C"></div><div class="hex">#62779C</div><div class="rl">SLATE &mdash; the darker tone. Hard-edged shapes only: panels, grips, vents, wraps. Never a gradient.</div></div>',
  '<div class="sw"><div class="chip" style="background:#0A1020"></div><div class="hex">#0A1020</div><div class="rl">OUTLINE BLACK &mdash; the hard outline around the whole silhouette, and the internal separators.</div></div>',
  '<div class="sw"><div class="chip" style="background:#202A3F"></div><div class="hex">#202A3F</div><div class="rl">SHADOW &mdash; a soft dark shadow OUTSIDE the outline, down and right. Under 1% of pixels.</div></div>',
  '</div>',
  '<p>What the three staffs use instead &mdash; the first is a near-miss, the rest do not belong in this set at all:</p>',
  '<div>',
  '<div class="sw"><div class="chip" style="background:#5C7396"></div><div class="hex">#5C7396</div><div class="rl">the staffs\' slate. Close to #62779C but not it &mdash; these were not sampled from the set.</div></div>',
  '<div class="sw"><div class="chip" style="background:#46BEFF"></div><div class="hex">#46BEFF</div><div class="rl">lightning gem</div></div>',
  '<div class="sw"><div class="chip" style="background:#1E78DC"></div><div class="hex">#1E78DC</div><div class="rl">lightning gem, dark</div></div>',
  '<div class="sw"><div class="chip" style="background:#FF7828"></div><div class="hex">#FF7828</div><div class="rl">fire stone</div></div>',
  '<div class="sw"><div class="chip" style="background:#D73C1E"></div><div class="hex">#D73C1E</div><div class="rl">fire stone, dark</div></div>',
  '<div class="sw"><div class="chip" style="background:#AAF5FF"></div><div class="hex">#AAF5FF</div><div class="rl">ice crystal</div></div>',
  '<div class="sw"><div class="chip" style="background:#5ABEE1"></div><div class="hex">#5ABEE1</div><div class="rl">ice crystal, mid</div></div>',
  '</div>',

  '<h2>5 &mdash; SO HOW DOES A PLAYER TELL THEM APART? THE SAME WAY THEY TELL 28 GUNS APART.</h2>',
  '<p><b>By silhouette.</b> The set already separates a combat knife, a wakizashi and a Stormbreaker with no colour at all. The player only ever holds <i>one</i> staff at a time, so this is recognition, not a side-by-side discrimination test &mdash; but the three heads should still be unmistakable at ' + DW + ' &times; ' + DH + '. Same shaft, same grip, same diagonal, same proportions on all three. <b>Only the head changes, and it changes a lot.</b></p>',
  '<div class="box"><table>',
  '<tr><th>cell</th><th>the head</th><th>current drawing, 2&times;</th></tr>',
  STAFF.map(s => '<tr><td class="nm">' + s[1] + '</td><td class="no">' + s[2] +
    '</td><td class="lit">' + cell(s[0], 2) + '</td></tr>').join(''),
  '</table></div>',
  '<p>The head subjects above are the ones already shipped and they are good &mdash; keep them. This pass is about the <b>treatment</b>: kill the gem colours, drop to three flat tones, thicken every stroke, and fill the cell the way the axe and the wakizashi do.</p>',
].join('');

fs.mkdirSync(REF, { recursive: true });
fs.writeFileSync(OUT, html);
console.log('wrote ' + path.relative(REPO, OUT) + '  (' + (html.length / 1024).toFixed(0) + ' KB)');
console.log('staffs  ink ' + num(S.staff1.ink) + '/' + num(S.staff2.ink) + '/' + num(S.staff3.ink) +
            '%  sat ' + num(S.staff1.sat) + '/' + num(S.staff2.sat) + '/' + num(S.staff3.sat) +
            '%  tones ' + S.staff1.tones + '/' + S.staff2.tones + '/' + S.staff3.tones);
console.log('28 mean ink ' + num(M.ink) + '%  sat ' + num(M.sat) + '%  tones ' + num(M.tones));
