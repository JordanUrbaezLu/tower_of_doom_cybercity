// =============================================================================
// gen_pap_badge_ref.js — build docs/96_pap_ref/badge_slot.html, the ONE picture
// the PaP-badge commission needs: where the badge sits, at true 1080p size, on
// a dark and a bright ground, then magnified.
//
// Same idea and the same transform discipline as tools/gen_gunhud_ref.js, but
// against the POST-REBUILD geometry: TodScaleHud is gone from AetheriumLoadout,
// so the canvas maps to 1080p by a flat x1.5 and nothing else. Every rect below
// is read straight off the Lua.
//
//   node tools/gen_pap_badge_ref.js docs/96_pap_ref/badge_slot.html
//   then render it to PNG with headless Edge (see docs/96 for the command)
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const OUT = process.argv[2];
if (!OUT) { console.error('usage: node tools/gen_pap_badge_ref.js <out.html>'); process.exit(1); }

const IMG = path.join(__dirname, '..', 'source_data', 'tod_ui_images', '_images');
const b64 = n => 'data:image/png;base64,' + fs.readFileSync(path.join(IMG, n + '.png')).toString('base64');

// canvas -> 1080p is a flat x1.5 since the v17.9 rebuild dropped TodScaleHud.
const S = 1.5;
const HUD_DX = 12;                       // AetheriumLoadout.lua
// crop window in 1080p px — the whole readout plus a margin
const CX = 1470, CY = 830, CW = 450, CH = 210;

const P = (x, y, w, h) => `left:${x * S - CX}px;top:${y * S - CY}px;width:${w * S}px;height:${h * S}px`;

const DARK = '#0b0f1a';
const BRIGHT = 'linear-gradient(135deg,#c9d6e8,#9fb6d4 60%,#e8eef6)';

// Every box is (canvas x, canvas y, w, h) exactly as the Lua sets it.
function widget() {
  return `
  <img class="e" style="${P(1000 + HUD_DX, 604, 256, 74)}" src="${b64('i_tod_hud_weapon_panel')}">
  <img class="e" style="${P(1004 + HUD_DX, 632, 96, 44)}" src="${b64('i_tod_hud_gun_smg')}">
  <img class="e" style="${P(1160 + HUD_DX, 568, 46, 32)}" src="${b64('i_tod_hud_offhand_tile')}">
  <img class="e" style="${P(1165 + HUD_DX, 572, 24, 24)}" src="${b64('i_tod_hud_off_monkey')}">
  <img class="e" style="${P(1210 + HUD_DX, 568, 46, 32)}" src="${b64('i_tod_hud_offhand_tile')}">
  <img class="e" style="${P(1215 + HUD_DX, 572, 24, 24)}" src="${b64('i_tod_hud_off_frag')}">
  <img class="e" style="${P(1000 + HUD_DX, 568, 46, 32)}" src="${b64('i_tod_hud_pap_tile')}">
  <img class="e" style="${P(1005 + HUD_DX, 572, 24, 24)}" src="${b64('i_tod_hud_pap_3')}">`;
}

function stage(bg, label) {
  return `
  <div class="stagewrap">
    <div class="stage" style="background:${bg}">
      ${widget()}
      <div class="ring" style="${P(1000 + HUD_DX, 568, 46, 32)}"></div>
    </div>
    <div class="lbl">${label}</div>
  </div>`;
}

const html = `<!doctype html><meta charset="utf-8"><style>
body{margin:0;background:#11151f;color:#dbe6f5;font:14px/1.5 ui-sans-serif,system-ui,sans-serif;padding:24px 28px}
h1{font:600 15px ui-monospace,monospace;color:#7fd4ff;letter-spacing:.06em;margin:26px 0 10px;text-transform:uppercase}
.row{display:flex;gap:22px;flex-wrap:wrap}
.stagewrap{}
.stage{position:relative;width:${CW}px;height:${CH}px;overflow:hidden;border:1px solid #2b3550}
.e{position:absolute;image-rendering:auto}
.ring{position:absolute;outline:2px solid #ff5a5a;outline-offset:3px;pointer-events:none}
.lbl{font:11px ui-monospace,monospace;color:#8fa3c0;margin-top:6px}
.cap{max-width:920px;color:#9fb0c9;font-size:13px}
b{color:#e8eef6}
.zoomwrap{overflow:hidden;border:1px solid #2b3550;display:inline-block;background:${DARK}}
.z{transform-origin:0 0}
table{border-collapse:collapse;margin:10px 0;font:12px ui-monospace,monospace}
td,th{border:1px solid #2b3550;padding:5px 9px;text-align:left}
th{color:#7fd4ff;font-weight:600}
</style>

<h1>The badge, in place, at true 1080p size</h1>
<p class="cap">The red ring is the slot being commissioned: <b>69 x 48 physical pixels</b>, at the left end
of the equipment row, directly above the gun picture. What is inside it now is <b>placeholder art</b> —
correct sizes and palette, deliberately plain. The two tiles on the right are the shipped equipment slots;
the new badge must look like it came from the same hand, without reading as a third equipment slot.</p>

<div class="row">
  ${stage(DARK, 'over black sky — the common case')}
  ${stage(BRIGHT, 'over a bright fog bank — the hard case')}
</div>

<h1>The slot at 6x</h1>
<div class="zoomwrap" style="width:${100 * 6}px;height:${44 * 6}px">
  <div class="z" style="transform:scale(6);width:100px;height:44px;background:${DARK};overflow:hidden;position:relative">
    <div style="position:absolute;left:${-(( 998 + HUD_DX) * S - CX)}px;top:${-(564 * S - CY)}px;width:${CW}px;height:${CH}px">
      ${widget()}
    </div>
  </div>
</div>
<p class="cap">The plate and the numeral, magnified. The numeral shown is <b>III</b>, the widest of the three.</p>

<h1>What is delivered</h1>
<table>
<tr><th>file</th><th>canvas</th><th>drawn at</th><th>what it is</th></tr>
<tr><td>i_tod_hud_pap_tile.png</td><td>276 x 192</td><td>69 x 48</td><td>the plate, one file, used for all three levels</td></tr>
<tr><td>i_tod_hud_pap_sheet.png</td><td>384 x 128</td><td>36 x 36 per cell</td><td>3 cells of 128 x 128: the numerals I, II, III</td></tr>
</table>
<p class="cap">The plate is drawn <b>behind</b> the numeral, and the numeral is drawn at
<b>setRGB(1,1,1)</b> — no runtime tint on either. Both are hidden entirely when the weapon is unpacked,
so neither needs an empty state.</p>
`;

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, html, 'utf8');
console.log('wrote ' + OUT + '  (' + (html.length / 1024).toFixed(0) + ' KB)');
