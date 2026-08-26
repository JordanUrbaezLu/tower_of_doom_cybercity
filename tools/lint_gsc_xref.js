#!/usr/bin/env node
// =============================================================================
// lint_gsc_xref.js - static cross-reference + dependency checker for our GSC.
//
// Catches, BEFORE the slow build, the linker error classes we hit on the first
// compile (each is a confirmed real failure mode, 2026-06-12):
//   1. acc_X::fn() with no #using of _acc_X            -> "Unresolved external"
//   2. acc_X::fn() where _acc_X has no function fn      -> "Unresolved external"
//   3. bare fn() that is actually another acc module's  -> missing namespace
//   4. stock ns::fn() with no #using of ns's file       -> "Unresolved external"
//   5. stock MACRO used with no #insert of its .gsh      -> undeclared identifier
//
// Deliberately does NOT verify stock FUNCTION existence (the mirror's
// multi-file namespaces make a per-ns function index unreliable -> false
// positives). The compiler is the oracle for that; this lint covers the
// dependency-wiring classes, which are reliably checkable from our source.
//
// Stock checks use a hardcoded namespace->required-#using-file map (verified
// against the dossiers in docs/research/) + the local mirror tmp/bo3_stock_ref
// for macro->gsh resolution (skipped if the mirror is absent).
//
// Usage:  node tools/lint_gsc_xref.js     (exit 1 on any problem)
// =============================================================================

'use strict';
const fs = require('fs');
const path = require('path');

const repo = path.join(__dirname, '..');
const ourDir = path.join(repo, 'scripts', 'zm', 'zm_tower_of_doom');
const entryGsc = path.join(repo, 'scripts', 'zm', 'zm_tower_of_doom.gsc');
const entryCsc = path.join(repo, 'scripts', 'zm', 'zm_tower_of_doom.csc');
const mirror = path.join(repo, 'tmp', 'bo3_stock_ref', 'scripts');

// stock namespace -> the #using basename it requires (verified).
const STOCK_NS = {
  util: 'util_shared', hud: 'hud_util_shared', struct: 'struct', array: 'array_shared',
  flag: 'flag_shared', callback: 'callbacks_shared', math: 'math_shared', scene: 'scene_shared',
  zm: '_zm', zm_utility: '_zm_utility', zm_perks: '_zm_perks', zm_weapons: '_zm_weapons',
  zm_score: '_zm_score', zm_spawner: '_zm_spawner', zm_powerups: '_zm_powerups',
  zm_zonemgr: '_zm_zonemgr', zm_audio: '_zm_audio', zm_magicbox: '_zm_magicbox',
  zombie_utility: 'zombie_utility', clientfield: 'clientfield_shared', system: 'system_shared',
  visionset_mgr: 'visionset_mgr_shared', laststand: 'laststand_shared', exploder: 'exploder_shared',
  compass: 'compass', lui: 'lui_shared', load: '_load',
};
const CONTROL = new Set(['if', 'while', 'for', 'foreach', 'switch', 'return', 'wait', 'waittill',
  'waittillmatch', 'waittillframeend', 'endon', 'notify', 'thread', 'self', 'assert', 'breakpoint']);

function strip(t) {
  return t.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/#[\s\S]*?#\//g, '')
    .replace(/\/\/.*$/gm, '').replace(/"(?:[^"\\]|\\.)*"/g, '""');
}
function usingsOf(code) {
  const set = new Set(); let m; const re = /^#using\s+([^\s;]+)/gm;
  while ((m = re.exec(code))) { const s = m[1].replace(/\\/g, '/').split('/'); set.add(s[s.length - 1]); }
  return set;
}
function insertsOf(code) {
  const set = new Set(); let m; const re = /#insert\s+([^\s;]+)/g;
  while ((m = re.exec(code))) { const s = m[1].replace(/\\/g, '/').split('/'); set.add(path.basename(s[s.length - 1], '.gsh')); }
  return set;
}
function fnsOf(code) {
  const set = new Set(); let m; const re = /^\s*function\s+(?:autoexec\s+|private\s+)*([A-Za-z0-9_]+)\s*\(/gm;
  while ((m = re.exec(code))) set.add(m[1]);
  return set;
}

// --- build our-module index ----------------------------------------------------
// .csc twins are linted too (2026-07-15 audit): they are compiled via the same zone manifest as the
// .gsc modules, so an unresolved xref in one is just as fatal - but this glob used to take '.gsc' only,
// leaving every authored client twin (_acc_lui.csc, _acc_perk_lights.csc, _acc_boss_nameplate.csc,
// _acc_boss_phantom.csc, _zm_ai_avogadro.csc) silently unlinted.
const ourFiles = fs.readdirSync(ourDir).filter(f => f.endsWith('.gsc') || f.endsWith('.csc')).map(f => path.join(ourDir, f));
const allFiles = [...ourFiles, entryGsc, entryCsc];
const mods = allFiles.map(f => {
  const code = strip(fs.readFileSync(f, 'utf8'));
  return { f, base: path.basename(f), code, ns: (code.match(/^#namespace\s+(\w+)/m) || [])[1],
    usings: usingsOf(code), inserts: insertsOf(code), fns: fnsOf(code) };
});
const nsToMod = {};            // acc namespace -> module
const fnToFiles = {};          // function name -> set of acc files defining it
for (const m of mods) {
  if (m.ns) nsToMod[m.ns] = m;
  for (const fn of m.fns) (fnToFiles[fn] = fnToFiles[fn] || new Set()).add(m.base);
}
function accUsingStem(ns) { const m = nsToMod[ns]; return m ? path.basename(m.f, path.extname(m.f)) : null; }

// --- build macro -> gsh (transitive) from the mirror ---------------------------
const macroToGsh = {}; const gshInserts = {};
function indexGsh(dir) {
  if (!fs.existsSync(dir)) return;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { indexGsh(p); continue; }
    if (!e.name.endsWith('.gsh')) continue;
    const base = path.basename(e.name, '.gsh');
    const code = strip(fs.readFileSync(p, 'utf8'));
    let m; const dr = /^\s*#define\s+([A-Z][A-Z0-9_]+)/gm;
    while ((m = dr.exec(code))) if (!macroToGsh[m[1]]) macroToGsh[m[1]] = base;
    gshInserts[base] = insertsOf(code);
  }
}
indexGsh(mirror);
const haveMacros = Object.keys(macroToGsh).length > 0;
function transitive(set) { const out = new Set(set), q = [...set]; while (q.length) { const b = q.pop(); for (const n of (gshInserts[b] || [])) if (!out.has(n)) { out.add(n); q.push(n); } } return out; }

// --- run checks ----------------------------------------------------------------
const problems = [];
for (const m of mods) {
  const lines = m.code.split('\n');
  const availMacros = transitive(m.inserts);
  lines.forEach((line, i) => {
    let c;
    // ns::fn( calls
    const nr = /(\w+)::(\w+)\s*\(/g;
    while ((c = nr.exec(line))) {
      const [ns, fn] = [c[1], c[2]];
      if (ns === m.ns) continue;
      if (nsToMod[ns]) {                                   // OUR module
        if (!m.usings.has(accUsingStem(ns))) problems.push(`${m.base}:${i + 1}  missing #using for ${ns}::${fn}`);
        else if (!nsToMod[ns].fns.has(fn)) problems.push(`${m.base}:${i + 1}  UNDEFINED ${ns}::${fn} (not in ${nsToMod[ns].base})`);
      } else if (STOCK_NS[ns]) {                           // stock module
        if (!m.usings.has(STOCK_NS[ns])) problems.push(`${m.base}:${i + 1}  missing #using ${STOCK_NS[ns]} for ${ns}::${fn}`);
      }
    }
    // function pointers: &ns::fn (same rules as a call) and bare &fn (must be
    // defined in this file). Used heavily in register_* callbacks; a typo here
    // is an unresolved external just like a call.
    const pr = /&([A-Za-z0-9_]+)(::([A-Za-z0-9_]+))?/g;
    while ((c = pr.exec(line))) {
      if (c[3]) {                                          // &ns::fn
        const ns = c[1], fn = c[3];
        if (ns === m.ns) { if (!m.fns.has(fn)) problems.push(`${m.base}:${i + 1}  &${ns}::${fn} undefined in self`); continue; }
        if (nsToMod[ns]) {
          if (!m.usings.has(accUsingStem(ns))) problems.push(`${m.base}:${i + 1}  missing #using for &${ns}::${fn}`);
          else if (!nsToMod[ns].fns.has(fn)) problems.push(`${m.base}:${i + 1}  &${ns}::${fn} UNDEFINED in ${nsToMod[ns].base}`);
        } else if (STOCK_NS[ns] && !m.usings.has(STOCK_NS[ns])) {
          problems.push(`${m.base}:${i + 1}  missing #using ${STOCK_NS[ns]} for &${ns}::${fn}`);
        }
      } else {                                             // bare &fn
        const fn = c[1];
        if (!m.fns.has(fn) && fnToFiles[fn]) {
          const other = [...fnToFiles[fn]].filter(x => x !== m.base);
          if (other.length) problems.push(`${m.base}:${i + 1}  &${fn} points to other module ${other.join(',')} (use &ns::${fn})`);
        }
      }
    }
    // bare fn() that belongs to another acc module
    const br = /(^|[^A-Za-z0-9_:.&])([a-z_][A-Za-z0-9_]*)\s*\(/g;
    while ((c = br.exec(line))) {
      const fn = c[2];
      if (CONTROL.has(fn) || m.fns.has(fn) || !fnToFiles[fn]) continue;
      const other = [...fnToFiles[fn]].filter(x => x !== m.base);
      if (other.length) problems.push(`${m.base}:${i + 1}  bare ${fn}() defined in ${other.join(',')} (missing namespace?)`);
    }
    // field access on a parenthesized expression: '( expr ).field' is illegal
    // ("Primitive expression field object must be...") though 'call().field'
    // is fine. Find ).<field>, match the '(' back, flag if it's a GROUPING
    // paren (preceded by =/return/operator/comma/( - not a function name).
    {
      const s = line;
      for (let k = 0; k < s.length - 1; k++) {
        if (s[k] !== ')') continue;
        // must be )<ws>.<letter>
        let t = k + 1; while (t < s.length && (s[t] === ' ' || s[t] === '\t')) t++;
        if (!(s[t] === '.' && /[A-Za-z_]/.test(s[t + 1] || ''))) continue;
        // walk back to matching (
        let depth = 1, j = k - 1;
        for (; j >= 0; j--) { if (s[j] === ')') depth++; else if (s[j] === '(') { depth--; if (depth === 0) break; } }
        if (j < 0) continue;
        // token before the '('
        let b = j - 1; while (b >= 0 && (s[b] === ' ' || s[b] === '\t')) b--;
        let word = ''; while (b >= 0 && /[A-Za-z0-9_]/.test(s[b])) { word = s[b] + word; b--; }
        const isCall = word && !['return', 'if', 'while', 'for', 'foreach', 'switch', 'case'].includes(word);
        if (!isCall) problems.push(`${m.base}:${i + 1}  field access on parenthesized expr '( ... ).${(s.slice(t + 1).match(/^[A-Za-z0-9_]+/) || [''])[0]}' - use a temp variable`);
      }
    }
    // stock macro without #insert
    if (haveMacros) {
      const mr = /\b([A-Z][A-Z0-9_]{1,})\b/g;
      while ((c = mr.exec(line))) {
        const tok = c[1];
        if (!macroToGsh[tok]) continue;
        if (m.inserts.size && availMacros.has(macroToGsh[tok])) continue;
        // local #define?
        if (m.code.match(new RegExp('^\\s*#define\\s+' + tok + '\\b', 'm'))) continue;
        if (!availMacros.has(macroToGsh[tok])) problems.push(`${m.base}:${i + 1}  macro ${tok} needs #insert ${macroToGsh[tok]}.gsh`);
      }
    }
  });
}
// de-dup
const uniq = [...new Set(problems)];
if (uniq.length === 0) {
  console.log('xref OK: acc cross-refs, stock #usings, macros, and bare-calls all resolve');
  process.exit(0);
} else {
  console.log(`xref FAIL: ${uniq.length} problems:\n`);
  uniq.forEach(p => console.log('  ' + p));
  process.exit(1);
}
