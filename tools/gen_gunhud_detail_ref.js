// Build docs/99_hud_ref/current_set_audit.html — the "brief in one picture" for
// the gun-HUD DETAIL pass (docs/99). Every one of the 28 shipped weapon icons at
// its true on-screen size AND at 2x, beside the gun it stands for, what a Black
// Ops veteran would expect to see, and what the current drawing is missing.
// Screenshot with headless Edge (command in docs/99).
'use strict';
const fs = require('fs');
const path = require('path');

const REPO = path.resolve(__dirname, '..');
const REF  = path.join(REPO, 'docs', '99_hud_ref');
const OUT  = path.join(REF, 'current_set_audit.html');

const K = 1.5 * 96 / 288;                              // 0.5 -> 144 x 66 on screen (loadout is not under TodScaleHud)
const DW = Math.round(288 * K), DH = Math.round(132 * K);

const S1 = { file: 'i_tod_hud_gun_sheet.png',  w: 2016, cols: 7 };
const S2 = { file: 'i_tod_hud_gun_sheet2.png', w: 1440, cols: 5 };
const IDX1 = { smg: 0, rifle: 1, lmg: 2, minigun: 3, shotgun: 4, pistol: 5, akimbo: 6,
               launcher: 7, nailgun: 8, gift: 9, blade: 10, katana: 11, axe: 12, shield: 13 };
const IDX2 = ['mac10', 'mp5', 'mp7', 'enfield', 'krig6', 'ak47', 'stoner63', 'hk21', 'bulldog', 'sg12',
              'spas12', 'magnum', 'mog12', 'executioner', 'mr6', 'amp63', 'udm', 'rk7',
              'executioner_akimbo', 'amp63_akimbo'].reduce((m, n, i) => (m[n] = i, m), {});

const b64 = f => fs.readFileSync(path.join(REF, f)).toString('base64');
const data = { [S1.file]: `data:image/png;base64,${b64(S1.file)}`, [S2.file]: `data:image/png;base64,${b64(S2.file)}` };

function cell(slug, scale) {
  const S = slug in IDX2 ? S2 : S1, i = slug in IDX2 ? IDX2[slug] : IDX1[slug];
  const c = i % S.cols, r = Math.floor(i / S.cols);
  const w = Math.round(DW * scale), h = Math.round(DH * scale);
  const rows = S === S1 ? 2 : 4;
  return `<div class="cell" style="width:${w}px;height:${h}px;background-image:url(${data[S.file]});` +
         `background-size:${Math.round(S.w * K * scale)}px ${Math.round(132 * rows * K * scale)}px;` +
         `background-position:${-c * w}px ${-r * h}px"></div>`;
}

// [new cell #, slug, gun, the game it is from / what it is, what a veteran expects, what the drawing is missing]
const AUDIT = [
  [1,  'mac10',   'MAC-10',        'Cold War SMG',      'a stubby, wide, flat-topped box with the magazine straight down through the grip and almost no barrel',
        'reads as a generic SMG. Needs the flat rectangular receiver with the charging handle on top, a much shorter muzzle, and the magazine visibly exiting the GRIP, not ahead of it'],
  [2,  'mp5',     'MP5',           'Cold War SMG',      'the slim tubular barrel with the hooded front sight, a strongly CURVED magazine ahead of the grip, the slotted handguard, the solid stock',
        'curve on the magazine is too shallow and the fore-end is a block. Make the magazine a real banana, the barrel a thin tube with a front-sight hood, slots on the handguard'],
  [3,  'mp7',     'MP7',           'Black Ops II PDW',  'a tiny gun: magazine in the grip, a FOLDING FOREGRIP under the muzzle, a top rail, a thin extending stock',
        'foregrip and top rail are not readable at size. Make the foregrip a clear vertical post, the top rail a notched line, the stock two thin bars'],
  [4,  'bulldog', 'Bulldog',       'Advanced Warfare shotgun', 'a BULLPUP: the magazine sits BEHIND the pistol grip, fat barrel shroud, short overall, a carry-handle rail on top',
        'currently a plain rectangle. Needs the mag behind the grip to be obvious, the shroud fat and rounded at the muzzle, and the top rail'],
  [5,  'sg12',    'SG12',          'Black Ops 4 auto shotgun', 'a Saiga: rifle-shaped shotgun with a WIDE BOX magazine, a skeleton stock, a thick barrel with a big muzzle',
        'looks like a rifle. Make the box magazine visibly wide and short (shells, not bullets), the muzzle wide, the stock a skeleton frame'],
  [6,  'spas12',  'SPAS-12',       'Black Ops II shotgun', 'the hook stock FOLDED OVER THE TOP, a perforated heat shield over the barrel, a tube magazine under it, a pump',
        'hook stock is there and it works. Add the row of holes on the heat shield and a distinct pump grip under the barrel'],
  [7,  'enfield', 'Enfield (L85)', 'Black Ops rifle',   'a BULLPUP with the big SUSAT SCOPE / carry-handle hump on top, magazine behind the grip, short and chunky',
        'the top hump is a blob and the bullpup is not obvious. Draw the scope as a clear cylinder on a mount, put the magazine clearly BEHIND the grip'],
  [8,  'krig6',   'Krig 6',        'Cold War rifle',    'a long slender handguard with a top rail, a curved magazine ahead of the grip, a skeleton FOLDING stock',
        'generic assault rifle. Give it the long thin handguard, a full-length top rail, and a hollow skeleton stock so it is not the AK'],
  [9,  'ak47',    'AK-47',         'Cold War rifle',    'the deeply curved banana magazine, the GAS TUBE above the barrel, the slanted muzzle, wood stock and handguard',
        'the best of the rifles already. Add the gas tube as a second line above the barrel, the slanted muzzle cut, and keep the wood in the darker tone'],
  [10, 'magnum',  'Magnum',        'Cold War revolver', 'a big-frame REVOLVER: a large round cylinder, a LONG barrel with a vent rib, a curved wooden grip, an exposed hammer',
        'THE WEAKEST CELL: it reads as a small carbine, not a revolver. Draw the cylinder as a big round drum in the middle, a long barrel forward, a curved grip back, hammer spur'],
  [11, 'mog12',   'MOG 12',        'Black Ops 4 pump shotgun', 'a pump shotgun: short barrel with a tube magazine under it, a ribbed PUMP fore-end, a traditional shoulder stock',
        'currently a long thin tube. Shorten it, make the pump a ribbed block under the barrel, give it a proper stock in the darker tone'],
  [12, 'executioner', 'Executioner', 'Black Ops II revolver shotgun', 'a snub-nosed revolver with an ENORMOUS fluted cylinder and a very short barrel, hammer spur, rubber grip',
        'the big cylinder is there. Add the flutes (vertical bars) on the cylinder, the hammer spur at the back, and make the barrel even shorter'],
  [13, 'stoner63', 'Stoner 63',    'Cold War LMG',      'a belt-fed LMG with the ammo BOX hanging under the receiver, a carry handle on top, a bipod folded under the barrel, a tubular stock',
        'box and bipod read. Add the carry handle on top, a longer barrel with a front sight, and make the stock a thin tube'],
  [14, 'hk21',    'HK21',          'Black Ops LMG',     'a G3 stretched into an LMG: LONG and SLIM, a round DRUM feed under the receiver, a slotted handguard, bipod, a rifle-style stock',
        'must sit beside cell 13 and look like a different family. Make it longer and thinner, the drum a clear circle, the handguard slotted, and the stock a G3 shape'],
  [15, 'minigun', 'Death Machine', 'Black Ops II minigun', 'the rotary barrel cluster (SIX barrels, drawn as three stacked tubes with round ends), a rear grip and a top carry handle, an ammo box/belt',
        'reads as a box with lines. Draw the barrel cluster as separate stacked tubes ending in circles, a clear top handle, the rear grip, an ammo feed'],
  [16, 'mr6',     'MR6',           'Black Ops III pistol', 'a plain polymer service pistol: slab slide with rear serrations, squared trigger guard, short muzzle, no cylinder',
        'fine as a shape. Add the slide serrations (three short bars at the back) and a visible trigger guard'],
  [17, 'launcher', 'RPG',          'Black Ops II RPG-7', 'the long TUBE with a conical rear VENTURI (bell) at the back, the fat bulbous WARHEAD at the front, TWO pistol grips, a wooden heat guard',
        'the tube reads; the rocket does not. Draw the warhead as a distinct bulb at the muzzle, the rear bell wider than the tube, both grips, wood guard in the darker tone'],
  [18, 'nailgun', 'Nail Gun',      'Cold War nail gun', 'a construction TOOL: a boxy body, a NARROW angled nail strip magazine hanging down at an angle, a tool grip with a trigger, a thin nozzle',
        'looks like a compressor. Make the nail strip a long thin angled bar, the nozzle a thin tip, the body a tool not a gun'],
  [19, 'blade',   'Combat Knife',  'Black Ops knife',   'a straight fixed blade with a clipped point, SERRATIONS on the spine, a crossguard, a ribbed grip',
        'good. Add the crossguard and the serration notches on the spine near the tip'],
  [20, 'katana',  'Wakizashi',     'Cold War short sword', 'a curved single-edged blade, a round TSUBA guard, a long handle with diamond WRAP pattern, a sheath-length blade',
        'good. Make the round guard a clear disc and the handle wrap a row of diamonds, not stripes'],
  [21, 'axe',     'Stormbreaker',  'Leviathan axe',     'an AXE-HAMMER: an axe blade on ONE side of the head, a flat hammer face on the OTHER, a gnarled wood handle',
        'symmetrical blades now. Make one side an axe edge and the other a squared hammer face; handle in the darker tone with two or three knots'],
  [22, 'amp63',   'AMP63',         'Cold War machine pistol', 'a full-auto pistol with a LONG stick magazine below the grip, a boxy slide with VENT cuts at the front, a squared compensator',
        'magazine could be longer. Add the vent cuts at the front of the slide and a visible compensator block at the muzzle'],
  [23, 'udm',     'UDM 45',        'Infinite Warfare machine pistol', 'a BLOCKY science-fiction pistol: thick angular slide with diagonal cuts, a wide magazine, hard planes everywhere',
        'add the diagonal slide cuts and an angular muzzle so it looks like a future gun, not a fatter MR6'],
  [24, 'rk7',     'RK7 Garrison',  'Black Ops 4 burst pistol', 'a SLIM angular future pistol: long thin slide with a forward COMPENSATOR block, a skeletonised grip, a sharp muzzle',
        'add the compensator block at the front of the slide and thin the grip so it reads as futuristic and lighter than cell 23'],
  [25, 'executioner_akimbo', 'Executioner x2', 'dual-wield PaP form', 'two copies of cell 12, overlapping, one slightly behind and to the right',
        'follows cell 12: whatever changes there changes here'],
  [26, 'amp63_akimbo', 'AMP63 x2', 'dual-wield PaP form', 'two copies of cell 22, overlapping, one slightly behind and to the right',
        'follows cell 22'],
  [27, 'gift',    'Gift of Death', 'the Death Machine powerup gun', 'a wrapped present with a bow, a tag and bells, a chute at the front, a grip under',
        'the most detailed cell in the set and the ceiling for detail. Keep it; only match its new neighbours\' line weight'],
  [28, 'shield',  'Riot Shield',   'Black Ops III riot shield', 'a tall rectangular shield with a VIEWPORT window near the top, two horizontal reinforcing bars, a slight taper',
        'reads as a box with a window. Add the reinforcing bars across the face, taper the bottom corners, make the viewport a clear rectangle near the top'],
];

const html = `<!doctype html><html><head><meta charset="utf-8"><style>
body{margin:0;background:#0b1020;color:#e8eef6;font:15px/1.35 Segoe UI,Arial,sans-serif;width:1500px;padding:24px 30px;box-sizing:border-box}
h1{font-size:26px;margin:0 0 6px;color:#fff}
h2{font-size:19px;margin:22px 0 8px;color:#7fd3ff;border-bottom:1px solid #26365a;padding-bottom:4px}
p{margin:4px 0 10px;color:#c9d3e6;max-width:1400px}
.card{display:flex;gap:14px;align-items:flex-start;background:#141c33;border:1px solid #2a3a63;border-radius:6px;padding:10px 12px;margin:0 0 10px}
.art{flex:0 0 auto;display:flex;gap:10px;align-items:center}
.cell{background-repeat:no-repeat;background-color:#0e1a34;border:1px solid #33456f}
.txt{flex:1 1 auto}
.num{display:inline-block;background:#7fd3ff;color:#0b1020;font-weight:700;padding:0 7px;border-radius:3px;margin-right:8px}
.lbl{font-weight:700;color:#fff;font-size:16px}
.src{color:#9fb0d4;font-size:12.5px;margin-left:8px}
.exp{color:#c9d3e6;margin:4px 0 2px}
.exp b{color:#ffd166}
.fix{color:#ff9d8c;margin:2px 0 0}
.fix b{color:#ff8c8c}
.sw{display:inline-block;width:22px;height:22px;vertical-align:middle;border:1px solid #666;margin:0 6px 0 14px}
</style></head><body>
<h1>GUN HUD — THE DETAIL PASS: every shipped weapon icon, audited (28 cells)</h1>
<p>Each row: the icon as it ships, at its TRUE on-screen size (${DW} × ${DH} px) and at 2×. Then the gun it stands for,
<b style="color:#ffd166">what a player who knows the Black Ops games expects to see</b>, and <b style="color:#ff8c8c">what the current drawing is missing</b>.
The number is the cell's position on the ONE sheet you deliver (7 columns × 4 rows, reading order).</p>
${AUDIT.map(([n, slug, gun, src, exp, fix]) => `
<div class="card"><div class="art">${cell(slug, 1)}${cell(slug, 2)}</div>
<div class="txt"><span class="num">${n}</span><span class="lbl">${gun}</span><span class="src">${src} · file cell <code>${slug}</code></span>
<div class="exp"><b>Expected:</b> ${exp}</div><div class="fix"><b>Missing:</b> ${fix}</div></div></div>`).join('')}
<h2>The rules that do not change</h2>
<p>Two flat tones + one outline, and nothing else:
<span class="sw" style="background:#E8EEF6"></span>steel-white face #E8EEF6
<span class="sw" style="background:#6B7FA6"></span>cool grey-blue offset + interior detail (sample it from the sheets)
<span class="sw" style="background:#0A1020"></span>dark outline #0A1020, ~7 px on the 288 × 132 cell. Offset down-right. Muzzle LEFT. No gradient, no glow, no text.
<b>More detail means more of the gun's SHAPE, never thinner lines</b>: nothing narrower than 10 px on the 288 × 132 cell survives being shown at ${DW} × ${DH}.</p>
</body></html>`;

fs.writeFileSync(OUT, html, 'utf8');
console.log('wrote ' + path.relative(REPO, OUT) + '  (' + (html.length / 1024).toFixed(0) + ' KB)');
