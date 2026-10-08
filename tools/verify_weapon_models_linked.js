// EVERY MODEL A GENERATED WEAPON FORM NAMES MUST BE IN THE LINKER'S LEDGER
// (2026-09-23, the sight audit: user watching v19.22 playthroughs, "the iron
// sights of a lot of our guns also got removed ... we need to find all the
// occasions of this").
//
// The pre-link gate (test_no_optics.js) proves the GDT is self-consistent: a
// packed form that hides its iron sights carries an optic MODEL, a form that
// raises to an optic's eye line has one attached. That is a statement about
// NAMES. This is the other half: the model those names point at was actually
// built into the fastfile. A first-person model, world model or attachment
// slot naming a model the linker never produced draws NOTHING in game - an
// invisible sight, a bare rail, a missing magazine - and the linker does not
// fail on it (it logs a default-substituted asset at most). The assetinfo
// ledger is the only record, so this runs after every link, like the
// missing-techsetdef gate beside it in build_map.ps1.
//
// Usage: node tools/verify_weapon_models_linked.js <path to zm_tower_of_doom.csv>
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const ledgerPath = process.argv[2];
if (!ledgerPath || !fs.existsSync(ledgerPath)) {
  console.error('usage: node tools/verify_weapon_models_linked.js <assetinfo csv> (missing: ' + ledgerPath + ')');
  process.exit(2);
}

const src = fs.readFileSync(path.join(root, 'source_data/tod_weapon_twins.gdt'), 'utf8');
const ledger = fs.readFileSync(ledgerPath, 'utf8');

// Ledger rows carry a leading index: "8076,xanim,tod_doubletap_fire,...".
const linked = new Set([...ledger.matchAll(/^(?:\d+,)?xmodel,([^,\r\n]+)/gm)].map(m => m[1]));
if (linked.size === 0) {
  console.error('no xmodel rows in ' + ledgerPath + ' - is this the assetinfo ledger?');
  process.exit(2);
}

const MODEL_KEYS = /^(viewModel|worldModel|dualWieldViewModel|attach(?:View|World)Model\d+)$/;
const owners = new Map();   // model -> Set(form names)
for (const m of src.matchAll(/"([^"\n]+)" \( "(?:bullet|projectile|dualwield)weapon.gdf" \)\s*\{([\s\S]*?)\n\t\}/g)) {
  for (const f of m[2].matchAll(/"([^"\n]+)" "([^"\n]*)"/g)) {
    if (!MODEL_KEYS.test(f[1]) || !f[2]) continue;
    if (!owners.has(f[2])) owners.set(f[2], new Set());
    owners.get(f[2]).add(m[1]);
  }
}

const missing = [...owners.keys()].filter(n => !linked.has(n)).sort();
for (const n of missing) {
  console.error(`MISSING xmodel ${n} <- ${[...owners.get(n)].slice(0, 5).join(', ')}${owners.get(n).size > 5 ? ' ...' : ''}`);
}
if (missing.length) {
  console.error(`${missing.length} of ${owners.size} models named by generated weapon forms are not in the ledger.`);
  process.exit(1);
}
console.log(`Weapon models linked: all ${owners.size} distinct models named by the generated weapon forms (view, world, every attachment slot) are xmodel rows in the ledger. PASS.`);
