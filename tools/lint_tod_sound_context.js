// SOUND-CONTEXT LINT (2026-09-09). Runs on every build, -GscOnly included.
//
// A sound alias row with a ContextType/ContextValue pair plays ONLY while that
// sound context is set on the listener/entity. Stock maps set "water" = over /
// under from their own scripts; THIS MAP NEVER SETS ANY SOUND CONTEXT (no
// SetContext anywhere in scripts/, and none in the stock shared scripts either).
// So a context-gated row here is a row that never plays, and it fails silently:
// the wav converts, the bank packs, the notetrack fires, and nothing is heard.
//
// This was ONE of the two reasons the mage's staff reload and first-raise
// foley shipped silent across four builds (the other, found the same day: the
// xanim GDT blocks carried no "2D Sound" custom notes -- see SOUND_NOTES in
// tools/import_staff_animations.py). The seven rows were copied from stock
// freezegun_sounds.csv with its water/over context intact, and they were the
// only rows among ~1,800 in this map's alias tables with any context at all.
// Every agent that looked checked the wavs, the notetracks and the GDT fields,
// and the row LOOKED like every other row unless you counted to column 55.
//
// Rule: no row in sound/aliases/*.csv may carry a ContextType or ContextValue.
// If a context is ever wired for real, add the alias to ALLOW with the script
// site that sets it, so the exception is documented next to the check.
const fs = require('fs');
const path = require('path');

const ALLOW = new Set([
  // alias name -> reason. Example of a real exception:
  // 'wpn_x_underwater', // set by _tod_x::water_watch SetContext("water","under")
]);
// Whole vendored files whose rows are third-party authoring, not ours. The
// Civil Protector VO (zm_ai_zod_companion.csv, 20 vox_crbt_* rows) carries
// ContextType=mature with an EMPTY value, straight from the pack. Whether the
// robot's voice lines play in this map is UNVERIFIED; they are listed here so
// the gate stays about rows this repo authored. Remove the entry to audit them.
const ALLOW_FILES = new Set(['zm_ai_zod_companion.csv']);

const dir = path.join(__dirname, '..', 'sound', 'aliases');
let rows = 0, bad = [];
for (const f of fs.readdirSync(dir).filter(n => n.toLowerCase().endsWith('.csv'))) {
  const text = fs.readFileSync(path.join(dir, f), 'utf8');
  const lines = text.split(/\r?\n/);
  const hdr = lines[0].split(',');
  const ct = hdr.indexOf('ContextType'), cv = hdr.indexOf('ContextValue');
  if (ct < 0 || cv < 0) { console.log(`sound-context: ${f}: no Context columns in header - skipped`); continue; }
  for (let i = 1; i < lines.length; i++) {
    const l = lines[i];
    if (!l.trim() || l.startsWith('#')) continue;
    const c = l.split(',');
    if (c.length <= Math.max(ct, cv)) continue;
    rows++;
    if ((c[ct] && c[ct].trim()) || (c[cv] && c[cv].trim())) {
      if (ALLOW.has(c[0]) || ALLOW_FILES.has(f)) continue;
      bad.push(`${f}:${i + 1} ${c[0]} ContextType=${c[ct]} ContextValue=${c[cv]}`);
    }
  }
}
if (bad.length) {
  console.log('sound-context: FAIL - alias rows gated on a sound context this map never sets (they will be SILENT):');
  for (const b of bad) console.log('  ' + b);
  console.log('  Clear both columns (or document the SetContext site in ALLOW in tools/lint_tod_sound_context.js).');
  process.exit(1);
}
console.log(`sound-context: OK - ${rows} alias rows, none context-gated`);
