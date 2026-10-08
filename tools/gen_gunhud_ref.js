// Build docs/95_hud_ref/current_gun_hud_onscreen.png — the "brief in one picture".
// Composites the REAL shipped kit images at their TRUE 1080p on-screen rects,
// over a dark and a bright background, then magnified. Rendered by headless Edge.
const fs = require('fs');
const path = require('path');

const REPO = 'C:/Users/jorda/Repositories/tower_of_doom_cybercity';
const REF  = path.join(REPO, 'docs/95_hud_ref');
const OUT  = process.argv[2];

// exact composite transform (TodScaleHud 1.15 about (1005,620), then 1080p = canvas*1.5)
const X = v => 1.725 * v - 226.125;
const Y = v => 1.725 * v - 139.5;

// crop window — deliberately extends PAST the screen edge (1920 x 1080) so the
// part of the plate the player never sees is visible in the brief.
const CX = 1190, CY = 726, CW = 860, CH = 382;
const SE_X = 1920 - CX;   // where the right screen edge falls inside the crop
const SE_Y = 1080 - CY;   // where the bottom screen edge falls inside the crop

const b64 = f => fs.readFileSync(path.join(REF, f)).toString('base64');
const img = f => `data:image/png;base64,${b64(f)}`;
const ttf = f => fs.readFileSync(path.join(REPO, 'fonts', f)).toString('base64');

// place an element by its PRE-scale canvas box, relative to the crop
function box(l, r, t, b) {
  return `left:${(X(l) - CX).toFixed(2)}px;top:${(Y(t) - CY).toFixed(2)}px;` +
         `width:${(X(r) - X(l)).toFixed(2)}px;height:${(Y(b) - Y(t)).toFixed(2)}px;`;
}

// The widget, composited. `state` picks which offhand art is shown.
function widget() {
  return `
  <img class="e" style="${box(885, 1312, 512, 720)}" src="${img('current_loadout_plate.png')}">

  <img class="e" style="${box(1057, 1124, 541, 600)}" src="${img('current_tactical_bg.png')}">
  <img class="e" style="${box(1065, 1099, 556, 585)}" src="${img('current_monkey_icon.png')}">
  <div class="t orb" style="${box(1099, 1124, 565, 577)};font-size:20.7px;text-align:left">+3</div>

  <img class="e" style="${box(1117, 1184, 541, 600)}" src="${img('current_lethal_bg_empty.png')}">
  <img class="e" style="${box(1126, 1153, 554, 577)}" src="${img('current_frag_icon.png')}">

  <div class="t orb" style="${box(847, 1106, 568, 585)};font-size:29.3px;text-align:center">DEATH &amp; TAXES</div>
  <div class="t ltr" style="${box(948, 1061, 605, 624)};font-size:32.8px;text-align:center">32</div>
  <div class="t ltr" style="${box(968, 1057, 629, 638)};font-size:15.5px;text-align:center">240</div>
  `;
}

// the off-screen shroud: dim + hatch everything the player never sees
function offscreen() {
  const hatch = 'repeating-linear-gradient(45deg,rgba(255,80,80,.20) 0 7px,rgba(0,0,0,0) 7px 14px)';
  const shroud = `background-color:rgba(3,5,11,.80);background-image:${hatch};`;
  return `
  <div style="position:absolute;left:${SE_X}px;top:0;right:0;bottom:0;${shroud}"></div>
  <div style="position:absolute;left:0;top:${SE_Y}px;width:${SE_X}px;bottom:0;${shroud}"></div>
  <div style="position:absolute;left:${SE_X}px;top:0;width:2px;height:${SE_Y}px;background:#ff5a5a"></div>
  <div style="position:absolute;left:0;top:${SE_Y}px;width:${SE_X + 2}px;height:2px;background:#ff5a5a"></div>
  <div class="edgelbl" style="left:${SE_X + 8}px;top:8px">never seen</div>
  `;
}

const DARK   = 'linear-gradient(150deg,#050810 0%,#0a1626 45%,#07101c 70%,#101a2e 100%)';
const BRIGHT = 'linear-gradient(150deg,#cfe6f7 0%,#a8cfe8 40%,#e8f2fb 75%,#bcd9ee 100%)';

const html = `<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{font-family:orb;src:url(data:font/ttf;base64,${ttf('orbitron.ttf')}) format('truetype')}
@font-face{font-family:ltr;src:url(data:font/ttf;base64,${ttf('ltromatic.ttf')}) format('truetype')}
*{box-sizing:border-box}
body{margin:0;background:#0b1220;font-family:ui-monospace,Consolas,monospace;color:#cfe3f5;width:1820px}
h1{font:700 19px ui-monospace,monospace;color:#7fe3ff;margin:22px 0 4px 24px;letter-spacing:.4px}
p.n{font:13px ui-monospace,monospace;color:#8fa8c2;margin:0 0 10px 24px;line-height:1.5}
p.w{font:13px ui-monospace,monospace;color:#ffb36b;margin:0 0 10px 24px;line-height:1.5}
.row{display:flex;gap:20px;margin:0 0 6px 24px}
.cap{font:12px ui-monospace,monospace;color:#8fa8c2;margin:0 0 16px 24px}
.stage{position:relative;overflow:hidden;width:${CW}px;height:${CH}px;flex:none;
       border:1px solid #24344a}
.stage>.inner{position:absolute;left:0;top:0;width:${CW}px;height:${CH}px}
.e{position:absolute;display:block}
.t{position:absolute;color:#fff;line-height:1;display:flex;align-items:center;
   text-shadow:0 1px 2px rgba(0,0,0,.55)}
.orb{font-family:orb}.ltr{font-family:ltr}
.t[style*="text-align:center"]{justify-content:center}
.t[style*="text-align:left"]{justify-content:flex-start}
.zoomwrap{position:relative;overflow:hidden;border:1px solid #24344a;margin:0 0 16px 24px}
.zoomwrap>.z{position:absolute;transform-origin:0 0}
.edge{position:absolute;top:0;bottom:0;width:2px;background:#ff5a5a;opacity:.85}
.edgelbl{position:absolute;font:11px ui-monospace,monospace;color:#ff8a8a;background:#0b1220cc;padding:1px 4px}
</style></head><body>

<h1>THE GUN HUD AS IT SHIPS TODAY — TRUE SIZE ON A 1920 x 1080 SCREEN</h1>
<p class="n">The bottom-right corner of the screen, life size. Left: over a dark background (most of this game).
Right: over a bright one. Everything here is the REAL shipped artwork at its REAL on-screen rectangle.<br>
The RED LINES are the edges of the screen. Everything past them is drawn and never seen.</p>
<div class="row">
  <div class="stage"><div class="inner" style="background:${DARK}">${widget()}${offscreen()}</div></div>
  <div class="stage"><div class="inner" style="background:${BRIGHT}">${widget()}${offscreen()}</div></div>
</div>
<p class="cap">The blue orb plate runs 117 px past the right edge of the screen and 22 px below the bottom.
Roughly a fifth of the artwork is off-screen, and the fifth that is cut is the calm dark part —
what is left on screen is the bright core, exactly where the numbers sit.</p>

<h1>MAGNIFIED 2x — THE SAME PIXELS</h1>
<div class="zoomwrap" style="width:${(SE_X) * 2}px;height:${(SE_Y) * 2}px">
  <div class="z" style="transform:scale(2);width:${CW}px;height:${CH}px;background:${DARK}">${widget()}</div>
</div>
<p class="w">What is wrong, in the order it hurts:</p>
<p class="n">
1. THE TWO OFFHAND TILES ARE ORANGE. Everything else in this HUD is electric blue. They are also
   mirrored copies of one swoosh, so lethal and tactical are the same shape and nothing tells them apart.<br>
2. THE TWO OFFHAND ICONS ARE PALE GREY LINE ART, drawn 47x40 and 59x50 physical pixels. At that size the
   monkey is a grey smudge. Both are stretched +17% wider than their square source.<br>
3. THE RESERVE NUMBER IS 15 PIXELS TALL — half the height of the clip number above it, and the smaller of
   the two is the one you check before committing to a fight.<br>
4. THE WEAPON ICON IS BLANK. Nothing is drawn between the clip number and the bottom of the plate,
   because the icon table this HUD reads has no entry for any weapon in this map.<br>
5. THE WEAPON NAME RUNS UNDER THE TACTICAL TILE. Its text box is 447 px wide and centred, and its right
   85 px sit on top of the tactical plate.<br>
6. THE PLATE IS AN ELECTRIC ORB, brightest exactly where the numbers sit.
</p>

<h1>THE OFFHAND CLUSTER AT 4x — TACTICAL (left) AND LETHAL (right)</h1>
<div class="zoomwrap" style="width:${250 * 4}px;height:${118 * 4}px">
  <div class="z" style="transform:scale(4);width:250px;height:118px;background:${DARK};overflow:hidden;position:relative">
    <div style="position:absolute;left:${-(X(1053) - CX)}px;top:${-(Y(536) - CY)}px;width:${CW}px;height:${CH}px">
      ${widget()}
    </div>
  </div>
</div>
<p class="cap">The white sliver at the far left is the tail of the weapon NAME running underneath the tactical tile — defect 5.<br>Lethal is drawn in its EMPTY state here because that is the only state this map can produce —
nothing in the map ever hands a player a frag grenade. Tactical shows 3 cymbal monkeys, the map's real maximum.</p>

</body></html>`;

fs.writeFileSync(OUT, html, 'utf8');
console.log('wrote ' + OUT + '  (' + (html.length / 1024).toFixed(0) + ' KB)');
