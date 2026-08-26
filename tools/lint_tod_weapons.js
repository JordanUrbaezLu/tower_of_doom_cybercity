// tools/lint_tod_weapons.js — the PACK-A-PUNCH / twin-name gate.
//
// THE NAMING RULE (established 2026-08-23 from four independent shipped sources,
// after getting it BACKWARDS once and breaking the knife):
//
//   THE ENGINE STRIPS A TRAILING _zm FROM A WEAPON ASSET NAME.
//   Zone lines name the ASSET (t9_me_knife_american_k0_zm).
//   The weapons CSV and every GetWeapon() call use the BARE name.
//
// Evidence: map 1 zones only leviathan_zm/leviathan_up_zm with a CSV of
// leviathan,leviathan_up and ships working; same for freezegun_zm; this map's
// hand-authored row is 	9_amp63,t9_amp63_rdw_up against an asset
// t9_amp63_rdw_up_zm (note _rdw is KEPT — it is that one suffix, not a general
// rule); and _tod_classes.gsc register_guns has said so in a comment all along.
//
// Three places spell these names — the generator's forms[].name() (the asset),
// the generator's CSV row, and _tod_classes::variant_name() (the script). This
// checks all three agree, because when they do not NOTHING fails loudly: the
// map builds, links and boots, and PaP just silently refuses.
//
// Usage: node tools/lint_tod_weapons.js
'use strict';
const fs = require('fs'), path = require('path');
const REPO = path.join(__dirname, '..');

const zpkgPath = path.join(REPO, 'zone_source', 'tod_twins.zpkg');
const csvPath = path.join(REPO, 'gamedata', 'weapons', 'zm', 'zm_levelcommon_weapons.csv');
const classesPath = path.join(REPO, 'scripts', 'zm', 'zm_tower_of_doom', '_tod_classes.gsc');

const errors = [];

// ---- 1. what the map actually LINKS (the zone package = the asset truth) ----
const linkedRaw = new Set(
  fs.readFileSync(zpkgPath, 'utf8').split(/\r?\n/)
    .filter(l => l.startsWith('weapon,')).map(l => l.slice(7).trim()).filter(Boolean)
);
// The engine STRIPS a trailing "_zm" from an asset name, so the script name and
// the weapons-table name are the asset name without it (see the evidence block in
// _tod_classes.gsc register_guns). Match either spelling.
const linked = { has: n => linkedRaw.has(n) || linkedRaw.has(n + '_zm') };

// ---- 2. what the weapons table ADVERTISES -----------------------------------
const csvLines = fs.readFileSync(csvPath, 'utf8').split(/\r?\n/).slice(1).filter(Boolean);
for (const row of csvLines) {
  const c = row.split(',');
  const [base, up] = [c[0], c[1]];
  if (!base || !linked.has(base)) continue;   // stock weapons live outside our zpkg
  if (!up) { errors.push(`CSV row "${base}" has no upgrade_name — PaP will refuse it`); continue; }
  if (!linked.has(up))
    errors.push(`CSV "${base}" -> upgrade "${up}" is NOT a linked asset (PaP silently refuses)`);
}

// ---- 3. what the GSC will ASK GetWeapon() for -------------------------------
// Parsed from the source so this cannot drift from the real registration.
const gsc = fs.readFileSync(classesPath, 'utf8');
const guns = [];
const reGun = /register_gun\(\s*"([^"]+)"\s*,\s*(\d+)\s*,\s*"([^"]+)"\s*,\s*"([^"]*)"\s*,\s*(axes1\([^)]*\)|axes2\([^)]*\)|undefined)/g;
for (let m; (m = reGun.exec(gsc)); ) {
  const [, cls, tier, stem, upSuffix, axesRaw] = m;
  const letters = [...axesRaw.matchAll(/,\s*"([a-z])"/g)].map(x => x[1]);
  guns.push({ cls, tier: +tier, stem, upSuffix, letters, baseTail: '', upTail: '' });
}
if (!guns.length) errors.push('parsed ZERO register_gun lines — the regex has drifted from the source');

const reTail = /set_tails\(\s*"([^"]+)"\s*,\s*"([^"]*)"\s*,\s*"([^"]*)"\s*\)/g;
for (let m; (m = reTail.exec(gsc)); ) {
  const [, stem, bt, ut] = m;
  const hits = guns.filter(g => g.stem === stem);
  if (!hits.length) errors.push(`set_tails("${stem}") matches no registered gun`);
  hits.forEach(g => { g.baseTail = bt; g.upTail = ut; });
}

// Mirror _tod_classes::variant_name exactly.
const variantName = (g, isUp, suffix) =>
  g.stem + (isUp ? g.upSuffix : '') + suffix + (isUp ? g.upTail : g.baseTail);

// Every ladder combination the upgrade system can walk to. Level caps come from
// the generator's AXIS table, mirrored here; a mismatch shows up as a missing
// asset rather than passing silently.
const AXIS_LEVELS = { f: 3, h: 3, r: 2, m: 3, k: 5, p: 2 };
function combos(letters) {
  if (!letters.length) return ['_b'];
  let out = [''];
  for (const L of letters) {
    const max = AXIS_LEVELS[L];
    if (max === undefined) { errors.push(`unknown axis letter "${L}"`); return ['_b']; }
    const next = [];
    for (const pre of out) for (let i = 0; i <= max; i++) next.push(pre + L + i);
    out = next;
  }
  return out.map(s => '_' + s);
}

// ---- THE DIRECTION THIS LINT USED TO MISS ----------------------------------
// Everything above proves that names RESOLVE TO ASSETS. That is necessary and
// it is not sufficient, and the gap is exactly the shape of a PaP bug:
//
//   a variant can be a perfectly linked asset AND have no weapons-table row.
//
// The gun then works completely — it spawns, fires, reloads, takes upgrades —
// and only Pack-a-Punch refuses it, because stock builds level.zombie_weapons
// from the CSV (_zm_weapons::load_weapon_spec_from_table) and
// can_upgrade_weapon() returns IsDefined(level.zombie_weapons[root].upgrade).
// No row, no upgrade field, silent refusal. Nothing in the build says a word.
//
// AND IT PRESENTS AS RANDOMNESS, which is why it has been so hard to pin: the
// row that is missing belongs to ONE LADDER COMBINATION, so the same gun PaPs
// fine at one upgrade level and refuses at another. "Sometimes I can't PaP the
// MAC-10" is what a missing t9_mac10_f2h1 row looks like from the player's seat.
const rowFor = new Set();
for (const row of csvLines) { const c = row.split(',')[0]; if (c) rowFor.add(c); }

let checked = 0, rowsChecked = 0;
for (const g of guns) {
  for (const suffix of combos(g.letters)) {
    for (const isUp of [false, true]) {
      const name = variantName(g, isUp, suffix);
      checked++;
      if (!linked.has(name))
        errors.push(`${g.cls} T${g.tier} ${g.stem}: GSC would request "${name}" — not a linked asset`);
    }
    // the BASE form is the one PaP looks up; the _up form is the row's target
    const baseName = variantName(g, false, suffix);
    rowsChecked++;
    if (!rowFor.has(baseName))
      errors.push(`${g.cls} T${g.tier} ${g.stem}: "${baseName}" is linked but has NO weapons-table row — the gun works, PaP silently refuses it`);
  }
}

// ---- SECONDARIES — never covered by this lint until now ---------------------
// Sidearms sit in PRIMARY slots on this map and are Pack-a-Punchable, so every
// argument above applies to them identically. They were invisible here because
// they are not register_gun rows: they are the TOD_SEC_* defines.
// pistol_standard is the one legitimate exemption — the stock starter MR6,
// supplied by the base game's zone, so it is in neither our zpkg nor our CSV
// in the way the generated twins are.
const STOCK_SUPPLIED = new Set(['pistol_standard']);

// SECONDARIES ARE NOT ALL GENERATED, so `linked` (tod_twins.zpkg only) is the
// wrong truth set for them: the AMP63 is a raw port zoned in the MAIN zone, not
// a twin. Checking it against the twins package alone reports a working gun as
// missing — which it did on the first run of this check. Widen to every zone
// file the map links.
const linkedAllRaw = new Set();
{
  const zoneDir = path.join(REPO, 'zone_source');
  const main = path.join(zoneDir, 'zm_tower_of_doom.zone');
  const files = [main];
  for (const m of fs.readFileSync(main, 'utf8').matchAll(/^include,(\S+)\s*$/gm)) {
    const f = path.join(zoneDir, m[1] + '.zpkg');
    if (fs.existsSync(f)) files.push(f);
  }
  for (const f of files)
    for (const l of fs.readFileSync(f, 'utf8').split(/\r?\n/))
      if (l.startsWith('weapon,')) linkedAllRaw.add(l.slice(7).trim());
}
const linkedAll = { has: n => linkedAllRaw.has(n) || linkedAllRaw.has(n + '_zm') };

let secChecked = 0;
for (const m of gsc.matchAll(/#define\s+TOD_SEC_[A-Z_0-9]+\s+"([a-z0-9_]+)"/g)) {
  const n = m[1];
  if (STOCK_SUPPLIED.has(n)) continue;
  secChecked++;
  if (!linkedAll.has(n))
    errors.push(`secondary "${n}" is not a linked asset — the class draft would hand out a weapon that does not exist`);
  else if (!rowFor.has(n))
    errors.push(`secondary "${n}" is linked but has NO weapons-table row — PaP silently refuses it`);
}

if (errors.length) {
  console.error(`weapon-name lint FAILED (${errors.length}):`);
  for (const e of errors.slice(0, 40)) console.error('  ' + e);
  if (errors.length > 40) console.error(`  ... and ${errors.length - 40} more`);
  process.exit(1);
}
console.log(`weapon/PaP names OK — ${guns.length} guns, ${checked} GSC-requested names, ` +
            `${rowsChecked} base variants + ${secChecked} secondaries all have weapons-table rows, ` +
            `${csvLines.length} CSV rows, all resolve to linked assets`);
