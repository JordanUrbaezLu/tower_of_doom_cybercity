#!/usr/bin/env node
// tools/lint_tod_hall_bunkers_selftest.js — breaks the map five ways and requires
// lint_tod_hall_bunkers.js to give the right verdict on each. Run it whenever the
// lint is edited (memory check-passes-wrong-question: a gate that passes while
// asking the wrong question is worse than no gate).
//
//   0. the real map                              -> OK
//   1. hall I's three porch risers removed       -> FAIL, "SW PORCH POCKET"
//   2. hall I's alcove seal removed              -> FAIL, "SE ALCOVE"
//   3. a U-shaped tall wall injected in hall I   -> FAIL, a BUNKER at the U
//   4. the same U with a riser inside it         -> OK   (the riser-inside rule)
//   5. a two-ended corridor injected in hall III -> OK   (the sector rule: two ways in is not a cubby)
//
// v18.80: the injected shapes moved to floor the ROOM-SCALE halls leave open —
// the U stood on THE RING's stage skirt and the corridor inside THE MAZE's rings.
//
// The broken copies are written to the OS temp dir and read back with --map;
// the anchors (spire origin, hub laps) always come from the repo's generated
// data, which the broken copies do not change.
'use strict';
const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawnSync } = require('child_process');

const REPO = path.resolve(__dirname, '..');
const MAP = path.join(REPO, 'map_source', 'zm', 'zm_tower_of_doom.map');
const LINT = path.join(__dirname, 'lint_tod_hall_bunkers.js');
const DATA = fs.readFileSync(path.join(REPO, 'scripts', 'zm', 'zm_tower_of_doom', '_tod_spire_data.gsc'), 'utf8');
const SP_X = +DATA.match(/function spire_x\(\)\s*\{\s*return\s+(-?\d+);/)[1];
const SP_Y = +DATA.match(/function spire_y\(\)\s*\{\s*return\s+(-?\d+);/)[1];
const HUBS = DATA.match(/function hub_laps\(\)\s*\{\s*return array\(([^)]*)\)/)[1].split(',').map(s => +s.trim());
const hubZ = lap => (lap - 1) * 384 + 192;
const src = fs.readFileSync(MAP, 'utf8');
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'tod_bunker_selftest_'));

function run(mapPath) {
  const r = spawnSync(process.execPath, [LINT, '--map', mapPath], { encoding: 'utf8' });
  return { code: r.status, out: (r.stdout || '') + (r.stderr || '') };
}
// a box brush in the map's plane format (three points per plane sharing the
// plane's coordinate — the lint's parser reads exactly that; winding is
// irrelevant here, these copies are never compiled)
let guidN = 0x9000;
function boxBrush(label, x1, x2, y1, y2, z1, z2, mat) {
  const g = () => `{7D0DB000-70D0-4E0A-8A3F-${(guidN++).toString(16).toUpperCase().padStart(12, '0')}}`;
  const tex = `${mat} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  return [
    `// brush 99999 — ${label}`, '{', ` guid "${g()}"`,
    ` ( ${x1 + 10} ${y1 + 10} ${z1} ) ( ${x1} ${y1 + 10} ${z1} ) ( ${x1} ${y1} ${z1} ) ${tex}`,
    ` ( ${x1} ${y1} ${z2} ) ( ${x1} ${y1 + 10} ${z2} ) ( ${x1 + 10} ${y1 + 10} ${z2} ) ${tex}`,
    ` ( ${x1} ${y1} ${z2} ) ( ${x1 + 10} ${y1} ${z2} ) ( ${x1 + 10} ${y1} ${z1} ) ${tex}`,
    ` ( ${x2} ${y1} ${z2} ) ( ${x2} ${y1 + 10} ${z2} ) ( ${x2} ${y1 + 10} ${z1} ) ${tex}`,
    ` ( ${x1 + 10} ${y2} ${z2} ) ( ${x1} ${y2} ${z2} ) ( ${x1} ${y2} ${z1} ) ${tex}`,
    ` ( ${x1} ${y1 + 10} ${z2} ) ( ${x1} ${y1} ${z2} ) ( ${x1} ${y1} ${z1} ) ${tex}`,
    '}',
  ].join('\n');
}
function riserEnt(x, y, z) {
  return ['// entity 99999 — selftest riser', '{', `guid "{7D0DB000-70D0-4E0A-8A3F-${(guidN++).toString(16).toUpperCase().padStart(12, '0')}}"`,
    '"classname" "script_struct"', '"angles" "0 270 0"', `"origin" "${x} ${y} ${z}"`, '"script_noteworthy" "riser_location"',
    '"script_string" "find_flesh"', '"targetname" "spire_c2_zone_spawners"', '"_color" "1 0 0"', '}'].join('\n');
}
// insert worldspawn brushes right before the worldspawn's closing brace
function addWorld(text, brushText) {
  const i = text.indexOf('\n// entity 1 ');
  if (i < 0) throw new Error('no entity 1');
  const close = text.lastIndexOf('\n}', i);
  return text.slice(0, close) + '\n' + brushText + text.slice(close);
}
function addEntity(text, entText) { return text.replace(/\n?$/, '\n' + entText + '\n'); }
// remove a labelled worldspawn brush block
function removeBrush(text, labelRe) {
  const lines = text.split('\n');
  for (let i = 0; i < lines.length; i++) {
    if (!labelRe.test(lines[i])) continue;
    let j = i + 1; while (lines[j] !== '}') j++;
    lines.splice(i, j - i + 1);
    return lines.join('\n');
  }
  throw new Error('brush not found: ' + labelRe);
}
// remove every script_struct entity whose origin matches one of the points
function removeStructs(text, pts) {
  return text.replace(/\/\/ entity \d+ — [^\n]*\n\{\nguid "[^"]*"\n((?:"[^"]+" "[^"]*"\n)+)\}\n/g, (m, kv) => {
    const o = kv.match(/"origin" "(-?\d+) (-?\d+) (-?\d+)"/);
    if (!o || !/"classname" "script_struct"/.test(kv)) return m;
    return pts.some(p => +o[1] === p[0] && +o[2] === p[1] && +o[3] === p[2]) ? '' : m;
  });
}

const hub1 = HUBS[0], z1 = hubZ(hub1);
const cases = [];
cases.push({ name: 'real map', text: src, expectFail: false });
cases.push({ name: 'porch risers removed (hall I)', expectFail: true, must: /SW PORCH POCKET/,
  text: removeStructs(src, [[-192, -216], [-128, -136], [-210, -10]].map(([x, y]) => [SP_X + x, SP_Y + y, z1])) });
cases.push({ name: 'alcove seal removed (hall I)', expectFail: true, must: /SE ALCOVE/,
  text: removeBrush(src, new RegExp(`^// brush \\d+ — spire hub lap${hub1} alcove seal$`)) });
// a U open to the WEST on hall I's east floor (between the stage and the E wall): walls S / N / E of an interior x[320,400] y[100,180]
const U = (t) => addWorld(t, [
  boxBrush('selftest U south', SP_X + 300, SP_X + 420, SP_Y + 80, SP_Y + 100, z1, z1 + 160, 'mwiii_vertigo_retro_synth_yellow'),
  boxBrush('selftest U north', SP_X + 300, SP_X + 420, SP_Y + 180, SP_Y + 200, z1, z1 + 160, 'mwiii_vertigo_retro_synth_yellow'),
  boxBrush('selftest U east', SP_X + 400, SP_X + 420, SP_Y + 80, SP_Y + 200, z1, z1 + 160, 'mwiii_vertigo_retro_synth_yellow'),
].join('\n'));
cases.push({ name: 'U-shaped wall injected (hall I)', expectFail: true, must: /BUNKER\s+\d+ cells .* at \(3[3-8]\d, 1[2-5]\d\)/, text: U(src) });
cases.push({ name: 'the same U with a riser inside', expectFail: false, text: addEntity(U(src), riserEnt(SP_X + 360, SP_Y + 140, z1)) });
// a two-ended corridor across hall III's field, south of the arcade: interior x[-40,240] y[-120,-60], open west (the doorway) and east (the E strip)
const hub3 = HUBS[2], z3 = hubZ(hub3);
cases.push({ name: 'two-ended corridor injected (hall III)', expectFail: false,
  text: addWorld(src, [
    boxBrush('selftest corridor S', SP_X - 40, SP_X + 240, SP_Y - 140, SP_Y - 120, z3, z3 + 160, 'mwiii_vertigo_retro_synth_cyan'),
    boxBrush('selftest corridor N', SP_X - 40, SP_X + 240, SP_Y - 60, SP_Y - 40, z3, z3 + 160, 'mwiii_vertigo_retro_synth_cyan'),
  ].join('\n')) });

let bad = 0;
cases.forEach((c, i) => {
  const p = path.join(tmp, `case${i}.map`);
  fs.writeFileSync(p, c.text, 'utf8');
  const r = run(p);
  const failed = r.code !== 0;
  let ok = failed === c.expectFail;
  if (ok && c.must && !c.must.test(r.out)) ok = false;
  if (!ok) bad++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  case ${i}: ${c.name}  -> lint ${failed ? 'FAILED' : 'passed'}${c.must ? (c.must.test(r.out) ? ', named it' : ', DID NOT name it') : ''}`);
  if (!ok) console.log(r.out.split('\n').filter(l => /BUNKER|HALL BUNKERS|Error/.test(l)).join('\n'));
});
fs.rmSync(tmp, { recursive: true, force: true });
console.log(bad ? `\nSELFTEST: ${bad} case(s) wrong` : '\nSELFTEST: all cases gave the right verdict');
process.exit(bad ? 1 : 0);
