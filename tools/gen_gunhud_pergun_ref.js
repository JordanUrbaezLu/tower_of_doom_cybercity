// Build docs/98_hud_ref/what_is_shared.html — the "brief in one picture" for the
// per-gun weapon-icon pack (docs/98). Shows the SIX shipped cells that today stand
// in for TWENTY different guns, at their true on-screen size, with the guns that
// share each one listed under it; the eight cells that are already one-gun-each
// (unchanged); and the target 5x4 sheet with every cell numbered and named.
// Screenshot it with headless Edge (see docs/98 for the exact command).
'use strict';
const fs = require('fs');
const path = require('path');

const REPO = path.resolve(__dirname, '..');
const REF  = path.join(REPO, 'docs', '98_hud_ref');
const OUT  = path.join(REF, 'what_is_shared.html');

// gun_icon box in AetheriumLoadout.lua is 96 x 44 canvas units;
// x1.5 for 1080p (the loadout is NOT under TodScaleHud any more), so the cell is drawn 144 x 66 physical pixels.
const CW = 288, CH = 132, K = 1.5 * 96 / 288;        // 0.5
const DW = Math.round(CW * K), DH = Math.round(CH * K); // 144 x 66

// the SHIPPED 6x2 sheet (1728x264): cell index -> (col,row)
const SHEET = 'i_tod_hud_gun_sheet.png';
const CELLS = { smg: 0, rifle: 1, lmg: 2, minigun: 3, shotgun: 4, pistol: 5,
                akimbo: 6, launcher: 7, nailgun: 8, blade: 9, axe: 10, shield: 11 };

const b64 = f => fs.readFileSync(path.join(REF, f)).toString('base64');
const img = f => `data:image/png;base64,${b64(f)}`;
const sheetData = img(SHEET);

function cell(name) {
  const i = CELLS[name], c = i % 6, r = Math.floor(i / 6);
  return `<div class="cell" style="background-image:url(${sheetData});` +
         `background-size:${Math.round(1728 * K)}px ${Math.round(264 * K)}px;` +
         `background-position:${-c * DW}px ${-r * DH}px"></div>`;
}
function single(file) {
  return `<div class="cell" style="background-image:url(${img(file)});background-size:${DW}px ${DH}px"></div>`;
}

const SHARED = [
  ['smg',     'SMG cell',     ['MAC-10', 'MP5', 'MP7'], 'the whole SKIRMISHER ladder draws this one picture'],
  ['rifle',   'RIFLE cell',   ['Enfield', 'Krig 6', 'AK-47'], 'the whole ASSAULT ladder'],
  ['lmg',     'LMG cell',     ['Stoner 63', 'HK21'], 'HEAVY tier 1 and tier 2 - the promotion is invisible'],
  ['shotgun', 'SHOTGUN cell', ['Bulldog', 'SG12', 'SPAS-12', 'MOG 12'], 'four different shotguns'],
  ['pistol',  'PISTOL cell',  ['MR6', 'Magnum', 'Executioner', 'AMP63', 'UDM 45', 'RK7 Garrison'], 'six different handguns'],
  ['akimbo',  'AKIMBO cell',  ['dual Executioners', 'dual AMP63s'], 'two different dual-wield pairs'],
];
const KEEP = [
  ['minigun', 'Death Machine'], ['launcher', 'RPG'], ['nailgun', 'Nail Gun'], ['blade', 'Combat Knife'],
  ['KATANA', 'Wakizashi'], ['axe', 'Stormbreaker'], ['shield', 'Riot Shield'], ['GIFT', 'Gift of Death'],
];
const TARGET = [
  ['mac10', 'MAC-10', 'compact SMG, magazine in the grip'],
  ['mp5', 'MP5', 'curved magazine ahead of the grip'],
  ['mp7', 'MP7', 'tiny PDW, magazine in the grip, front grip'],
  ['enfield', 'Enfield', 'BULLPUP - magazine behind the grip'],
  ['krig6', 'Krig 6', 'conventional rifle, folding stock'],
  ['ak47', 'AK-47', 'banana magazine, wood stock'],
  ['stoner63', 'Stoner 63', 'belt-fed, ammo box under, bipod'],
  ['hk21', 'HK21', 'long slim belt-fed, drum feed, bipod'],
  ['bulldog', 'Bulldog', 'BULLPUP auto shotgun'],
  ['sg12', 'SG12', 'auto shotgun with a box magazine'],
  ['spas12', 'SPAS-12', 'pump, top-folding hook stock'],
  ['magnum', 'Magnum', 'big long-barrel revolver'],
  ['mog12', 'MOG 12', 'pump shotgun, tube under barrel'],
  ['executioner', 'Executioner', 'snub revolver with a HUGE cylinder'],
  ['mr6', 'MR6', 'plain modern polymer pistol'],
  ['amp63', 'AMP63', 'machine pistol, long stick magazine'],
  ['udm', 'UDM 45', 'blocky futuristic machine pistol'],
  ['rk7', 'RK7 Garrison', 'slim futuristic burst pistol'],
  ['executioner_akimbo', 'Executioner x2', 'two of cell 14, overlapping'],
  ['amp63_akimbo', 'AMP63 x2', 'two of cell 16, overlapping'],
];

const html = `<!doctype html><html><head><meta charset="utf-8"><style>
body{margin:0;background:#0b1020;color:#e8eef6;font:15px/1.35 Segoe UI,Arial,sans-serif;width:1500px;padding:24px 30px;box-sizing:border-box}
h1{font-size:26px;margin:0 0 6px;color:#fff;letter-spacing:.5px}
h2{font-size:19px;margin:26px 0 8px;color:#7fd3ff;border-bottom:1px solid #26365a;padding-bottom:4px}
p{margin:4px 0 10px;color:#c9d3e6;max-width:1400px}
.row{display:flex;flex-wrap:wrap;gap:18px 22px}
.card{background:#141c33;border:1px solid #2a3a63;border-radius:6px;padding:10px 12px;width:206px}
.card.wide{width:440px}
.cell{width:${DW}px;height:${DH}px;background-repeat:no-repeat;background-color:#0e1a34;border:1px solid #33456f;margin:0 auto 8px}
.cell.empty{border:2px dashed #4b5f95;background:#0b1430;display:flex;align-items:center;justify-content:center;color:#4b5f95;font-size:22px;font-weight:700}
.lbl{font-weight:700;color:#fff;font-size:14px}
.sub{color:#9fb0d4;font-size:12.5px}
.guns{color:#ffd166;font-size:13px;margin-top:4px}
.grid{display:grid;grid-template-columns:repeat(5,1fr);gap:12px 14px;width:1100px}
.slot{background:#141c33;border:1px solid #2a3a63;border-radius:6px;padding:8px 8px 6px;text-align:center}
.num{position:relative;top:-2px;font-size:11px;color:#7fd3ff}
.sw{display:inline-block;width:22px;height:22px;vertical-align:middle;border:1px solid #666;margin:0 6px 0 14px}
.warn{color:#ff8c8c;font-weight:700}
</style></head><body>
<h1>GUN HUD — ONE PICTURE PER GUN (20 new cells on one sheet)</h1>
<p>Every weapon icon here is shown at its TRUE on-screen size, ${DW} × ${DH} px, on the HUD's dark panel colour.
Judge every drawing at that size.</p>

<h2>1. WHAT SHIPS TODAY — six cells doing the work of twenty guns</h2>
<p>The current set draws one silhouette per <i>kind</i> of gun. So when a player upgrades from a Stoner 63 to an HK21,
or swaps a MAC-10 for an MP5, <span class="warn">the picture does not change</span>. These six cells are being RETIRED
in favour of one picture per gun. They are attached only as the STYLE to match.</p>
<div class="row">${SHARED.map(([k, t, guns, why]) => `
  <div class="card ${guns.length > 3 ? 'wide' : ''}">${cell(k)}<div class="lbl">${t}</div><div class="sub">${why}</div>
  <div class="guns">stands in for: ${guns.join(' · ')}</div></div>`).join('')}
</div>

<h2>2. ALREADY ONE GUN EACH — finished, keep, do NOT redraw</h2>
<p>These eight are unique to one weapon already and stay exactly as they are. The new twenty must sit beside them and look drawn in the same pass.</p>
<div class="row">${KEEP.map(([k, n]) => `
  <div class="card">${k === 'KATANA' ? single('i_tod_hud_gun_katana.png') : k === 'GIFT' ? single('i_tod_hud_gun_gift.png') : cell(k)}<div class="lbl">${n}</div></div>`).join('')}
</div>

<h2>3. THE DELIVERABLE — one sheet, 1440 × 528 px, 5 columns × 4 rows of 288 × 132 cells, in THIS order</h2>
<p>Reading order: left to right, then the next row. Each cell holds ONE gun, side profile, muzzle pointing LEFT, centred, with transparent margin —
exactly as every cell in section 1 and 2 is laid out. The number is the cell's position; the name is the gun; the note is the one feature that makes it that gun.</p>
<div class="grid">${TARGET.map(([slug, n, d], i) => `
  <div class="slot"><div class="cell empty">${i + 1}</div><div class="lbl">${n}</div><div class="sub">${d}</div></div>`).join('')}
</div>

<h2>4. THE THREE COLOURS — and nothing else</h2>
<p><span class="sw" style="background:#E8EEF6"></span>steel-white face #E8EEF6
   <span class="sw" style="background:#6B7FA6"></span>cool grey-blue offset + interior detail (sample it from the attached sheet)
   <span class="sw" style="background:#0A1020"></span>dark outline #0A1020, about 7 px on the 288 × 132 cell. Flat. No gradient, no glow, no text.</p>
</body></html>`;

fs.writeFileSync(OUT, html, 'utf8');
console.log('wrote ' + path.relative(REPO, OUT) + '  (' + (html.length / 1024).toFixed(0) + ' KB)');
