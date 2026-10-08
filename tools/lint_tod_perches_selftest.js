// tools/lint_tod_perches_selftest.js — proves tools/perch_core.js (the perch lint's model,
// and the generator's PERCH SEAL) still catches what it exists to catch. Runs before the
// perch lint in every full build (build_map.ps1 step 1d).
//
// A lint that passes because it stopped looking is worse than no lint. Each case below
// mutates the EMITTED .map in memory and runs the model only around the mutation (--near
// semantics, so the whole test takes seconds):
//   MUST CATCH   the base ammo crate with its perch cap removed (the tester's report),
//                the Rampage switch without its cap, the spire hub-10 W rail cap without
//                its seal (the 68-up ledge on the trial-hall flight), and a brand-new
//                capless 70-tall clip column on the arena floor.
//   MUST PASS    a 24-tall box on the arena floor (a zombie still swings at a player 24 up;
//                the 40-tall Rampage body was NOT safe for the horde, the tester proved it -
//                perch_core HIT_DZ_MAX), and the shipped map around the crate, the switch
//                and the rail cap.
'use strict';
const fs = require('fs');
const path = require('path');
const PC = require('./perch_core');
const CB = require('./convex_brush');

const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_tower_of_doom.map');
const raw = PC.parseMapWorld(fs.readFileSync(MAP, 'utf8'));

function boxRaw(label, x1, x2, y1, y2, z1, z2, mat) {
  const c = [(x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2];
  const tris = [
    [[x1, y1, z1], [x2, y1, z1], [x2, y2, z1]], [[x1, y1, z2], [x2, y1, z2], [x2, y2, z2]],
    [[x1, y1, z1], [x1, y2, z1], [x1, y1, z2]], [[x2, y1, z1], [x2, y2, z1], [x2, y1, z2]],
    [[x1, y1, z1], [x2, y1, z1], [x1, y1, z2]], [[x1, y2, z1], [x2, y2, z1], [x1, y2, z2]],
  ];
  const planes = tris.map(v => { let q = CB.plane(v, mat); if (CB.dot(q.n, CB.sub(c, v[0])) > 0) { v = [v[2], v[1], v[0]]; q = CB.plane(v, mat); } return q; });
  return { label, planes };
}
function centreOf(label) {
  const r = raw.find(b => b.label === label);
  if (!r) throw new Error(`selftest: no brush "${label}" in the map — regenerate it, or update this test`);
  const h = CB.hull(r.planes);
  return [(h.lo[0] + h.hi[0]) / 2, (h.lo[1] + h.hi[1]) / 2, h.hi[2]];
}
const fails = [];
function check(name, brushes, near, want, r = 160) {
  const { perches } = PC.analyze(brushes, { near: { p: near, r } });
  const got = perches.length > 0;
  console.log(`  ${got === want ? 'ok  ' : 'FAIL'}  ${name}: ${got ? `${perches.length} perch face(s), e.g. "${perches[0].label}" ${Math.round(perches[0].dz)} up` : 'no perch'}`);
  if (got !== want) fails.push(name);
}
const without = (...labels) => raw.filter(b => !labels.includes(b.label));

const crate = centreOf('base ammo crate body');
const inducer = centreOf('base rampage inducer body');
const hubCap = raw.find(b => /^spire lap10 rail cap W perch seal$/.test(b.label));
console.log('perch lint self-test');
check('base crate WITHOUT its perch cap (the tester\'s report) is caught', without('base ammo crate perch cap'), crate, true);
check('base crate as shipped is clear', raw, crate, false);
check('rampage switch WITHOUT its perch cap is caught', without('base rampage inducer perch cap'), inducer, true);
check('rampage switch as shipped is clear', raw, inducer, false);
if (!hubCap) fails.push('the spire hub-10 W rail cap seal is missing from the map (the generator stopped sealing it?)');
else {
  // the whole 672-long cap (its open stretch is the part the hall floor does not roof)
  const capTop = centreOf('spire lap10 rail cap W');
  check('spire hub-10 W rail cap WITHOUT its seal is caught', raw.filter(b => !/^spire lap10 rail cap W perch seal/.test(b.label)), capTop, true, 400);
  check('spire hub-10 W rail cap as shipped is clear', raw, capTop, false, 400);
}
const fresh = boxRaw('selftest capless column', -120, -80, 300, 340, 0, 70, 'clip');
check('a new capless 70-tall prop clip on the arena floor is caught', raw.concat([fresh]), [-100, 320, 70], true);
const low = boxRaw('selftest low box', -120, -80, 300, 340, 0, 24, 'clip');
check('a 24-tall box (zombies still reach a player on it) is NOT a perch', raw.concat([low]), [-100, 320, 24], false);
const mid = boxRaw('selftest mid box', -120, -80, 300, 340, 0, 40, 'clip');
check('a 40-tall box (as tall as the Rampage body) IS a perch', raw.concat([mid]), [-100, 320, 40], true);
if (fails.length) {
  console.error(`perch lint self-test FAILED (${fails.length}):\n  ` + fails.join('\n  '));
  process.exit(1);
}
console.log('perch lint self-test OK');
