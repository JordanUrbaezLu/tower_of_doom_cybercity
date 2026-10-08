// Build docs/100_hud_ref/current_medallions_onscreen.html — the "brief in one
// picture" for the class-medallion pack (docs/100). The four shipped medallions
// exactly as the player sees them: 84 px beside the name on the local panel,
// 52 px on the teammate rows, then at their 256 px source size, with the
// measurements and the verdict. Screenshot with headless Edge (see docs/100).
'use strict';
const fs = require('fs');
const path = require('path');

const REPO = path.resolve(__dirname, '..');
const IMG  = path.join(REPO, 'source_data', 'tod_ui_images', '_images');
const REF  = path.join(REPO, 'docs', '100_hud_ref');
const OUT  = path.join(REF, 'current_medallions_onscreen.html');

// AetheriumPlayerInfo.lua: 56x56 canvas (x 24..80, y 620..676), no TodScaleHud
// -> x1.5 = 84 px at 1080p. AetheriumPartyPlayers.lua: 35x35 -> 52.5 px.
const LOCAL = 84, ROW = 52;
const CLASSES = [
  ['skirmisher', 'SKIRMISHER', '#33D9FF', 'cyan',   'running figure + SMG'],
  ['assault',    'ASSAULT',    '#FFBF40', 'gold',   'rifle + chevron'],
  ['heavy',      'HEAVY',      '#FF594D', 'red',    'LMG + ammo belt'],
  ['slasher',    'SLASHER',    '#BF73FF', 'violet', 'katana'],
];
const img = c => `data:image/png;base64,${fs.readFileSync(path.join(IMG, `i_tod_class_medallion_${c}.png`)).toString('base64')}`;

const panel = (c, name, size, hp) => `
<div class="panel" style="height:${size + 30}px">
  <img src="${img(c)}" style="width:${size}px;height:${size}px">
  <div class="col"><div class="nm" style="font-size:${Math.round(size * 0.22)}px">${name}</div>
  <div class="bar" style="width:${size * 2.6}px;height:${Math.max(6, Math.round(size * 0.12))}px"><div style="width:${hp}%"></div></div></div>
</div>`;

const html = `<!doctype html><html><head><meta charset="utf-8"><style>
body{margin:0;background:#0b1020;color:#e8eef6;font:15px/1.35 Segoe UI,Arial,sans-serif;width:1500px;padding:24px 30px;box-sizing:border-box}
h1{font-size:26px;margin:0 0 6px;color:#fff}
h2{font-size:19px;margin:24px 0 8px;color:#7fd3ff;border-bottom:1px solid #26365a;padding-bottom:4px}
p{margin:4px 0 10px;color:#c9d3e6;max-width:1400px}
.row{display:flex;flex-wrap:wrap;gap:18px 24px;align-items:flex-start}
.panel{display:flex;align-items:center;gap:12px;background:#0e1628;border:1px solid #223055;border-radius:6px;padding:12px 16px;box-sizing:border-box}
.col{display:flex;flex-direction:column;gap:6px}
.nm{font-weight:700;color:#fff;letter-spacing:.5px}
.bar{background:#1b2540;border:1px solid #3a4a75}.bar div{height:100%;background:#e8eef6}
.card{background:#141c33;border:1px solid #2a3a63;border-radius:6px;padding:10px 12px;width:300px}
.lbl{font-weight:700;color:#fff;margin-top:6px}.sub{color:#9fb0d4;font-size:12.5px}
.sw{display:inline-block;width:16px;height:16px;vertical-align:middle;border:1px solid #666;margin-right:6px}
table{border-collapse:collapse;margin:6px 0 10px}td,th{border:1px solid #2a3a63;padding:4px 10px;text-align:left;font-size:14px}th{color:#7fd3ff}
.bad{color:#ff8c8c;font-weight:700}
</style></head><body>
<h1>CLASS MEDALLIONS — the icon beside your name, as it ships today</h1>
<p>The medallion is the player's class badge. It draws in exactly two places and both show it SMALL:</p>
<table><tr><th>where</th><th>on screen at 1080p</th><th>at 1440p</th><th>at 4K</th></tr>
<tr><td>the local player's panel, bottom-left, beside the name</td><td><b>${LOCAL} × ${LOCAL} px</b></td><td>126 px</td><td>168 px</td></tr>
<tr><td>each teammate's row above it</td><td><b>${ROW} × ${ROW} px</b></td><td>79 px</td><td>105 px</td></tr>
</table>
<p>The source file is 256 × 256. At 1080p only a THIRD of its pixels are ever shown; at 4K, two thirds.
<span class="bad">Resolution is not the problem.</span> The problem is what is drawn: a flat two-tone glyph with thin strokes inside a thin ring,
which at ${LOCAL} px turns into a coloured circle with a smudge in it.</p>

<h2>1. LIFE SIZE — the local panel (${LOCAL} px) and a teammate row (${ROW} px)</h2>
<div class="row">${CLASSES.map(([c, n]) => panel(c, n, LOCAL, 100)).join('')}</div>
<div class="row" style="margin-top:14px">${CLASSES.map(([c, n]) => panel(c, n, ROW, 70)).join('')}</div>

<h2>2. THE SOURCE FILES at 256 px — what the drawing actually is</h2>
<div class="row">${CLASSES.map(([c, n, hex, cn, sym]) => `
<div class="card"><img src="${img(c)}" style="width:256px;height:256px;display:block;margin:0 auto">
<div class="lbl">${n} <span class="sw" style="background:${hex}"></span><span class="sub">${cn} ${hex}</span></div>
<div class="sub">symbol today: ${sym}. Flat fill, one outline, thin ring, soft outer glow, no lighting.</div></div>`).join('')}
</div>

<h2>3. WHAT THE NEW ONES MUST DO</h2>
<p>Read as a <b>3D-rendered medal</b> — a solid metal object with light on it — at ${LOCAL} px, and still read at ${ROW} px.
Keep the four colours above exactly: they are the class identity everywhere else on screen (cards, class select, teammate rows).
Fill the whole disc with the symbol; big shapes, strong light-to-dark contrast, a hard silhouette edge. No text.</p>
</body></html>`;

fs.mkdirSync(REF, { recursive: true });
fs.writeFileSync(OUT, html, 'utf8');
console.log('wrote ' + path.relative(REPO, OUT) + '  (' + (html.length / 1024).toFixed(0) + ' KB)');
