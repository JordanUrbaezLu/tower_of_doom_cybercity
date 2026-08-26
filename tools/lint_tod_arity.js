// Arity + resolution lint for tod GSC: every `ns::fn(...)` / bare `fn(...)` /
// `self fn(...)` call into OUR modules must match a definition with the same
// parameter count (T7 resolves by name+arity -> "Unresolved external" otherwise).
'use strict';
// tools/lint_tod_arity.js — call-site arity + resolution lint for THIS map's GSC/CSC.
// T7 resolves script calls by name+ARITY at map load, so a call with MORE args than
// the callee declares is a boot-time "Unresolved external" Com_Error (live 2026-08-21,
// _tod_upgrades.gsc:373). Fewer args is legal (padded undefined). The repo's older
// lint_gsc_xref.js is acc-prefix-only and silently passes tod code — run THIS one.
// Usage: node tools/lint_tod_arity.js
const fs = require('fs'), path = require('path');
const root = path.join(__dirname, '..', 'scripts', 'zm');
const files = []; const defFiles = [];
const stockRoot='C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/share/raw/scripts';(function walkS(d){for(const e of fs.readdirSync(d,{withFileTypes:true})){const p=path.join(d,e.name);if(e.isDirectory())walkS(p);else if(/.(gsc|csc)$/.test(e.name))defFiles.push(p);}})(stockRoot);(function walk(d) { for (const e of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, e.name); if (e.isDirectory()) walk(p); else if (/\.(gsc|csc)$/.test(e.name)) files.push(p); } })(root);

function strip(src) { // single-pass: blank comments + string bodies, keep newlines
  let out = '', i = 0, n = src.length;
  while (i < n) {
    const c = src[i], d = src[i + 1];
    if (c === '/' && d === '/') { while (i < n && src[i] !== '\n') { out += ' '; i++; } continue; }
    if (c === '/' && d === '*') { out += '  '; i += 2; while (i < n && !(src[i] === '*' && src[i + 1] === '/')) { out += (src[i] === '\n' ? '\n' : ' '); i++; } out += '  '; i += 2; continue; }
    if (c === '"') { out += '"'; i++; while (i < n && src[i] !== '"' && src[i] !== '\n') { if (src[i] === '\\') { out += '  '; i += 2; continue; } out += ' '; i++; } out += '"'; i++; continue; }
    out += c; i++;
  }
  return out;
}
function countArgs(s) { // s = text after '(' ; returns {n, end}
  let depth = 0, n = 0, sawTok = false, i = 0;
  for (; i < s.length; i++) {
    const c = s[i];
    if (c === '(' || c === '[') depth++;
    else if (c === ')' || c === ']') { if (depth === 0) break; depth--; }
    else if (c === ',' && depth === 0) { n++; sawTok = false; continue; }
    if (!/\s/.test(c)) sawTok = true;
  }
  return { n: (n === 0 && !sawTok) ? 0 : n + 1, end: i };
}
const defs = {}; // ns -> name -> Set(arity)
const fileNs = {}, fileSide = {};
const parsed = {};
for (const f of [...defFiles, ...files]) {
  const src = strip(fs.readFileSync(f, 'utf8'));
  parsed[f] = src;
  const nsm = src.match(/#namespace\s+([A-Za-z0-9_]+)/);
  const ns = nsm ? nsm[1] : path.basename(f).replace(/^_/, '').replace(/\.[gc]sc$/, '');
  fileNs[f] = ns; fileSide[f] = f.endsWith('.csc') ? 'csc' : 'gsc';
  const key = ns + '|' + fileSide[f];
  defs[key] = defs[key] || {};
  const re = /function\s+(?:autoexec\s+|private\s+)*([A-Za-z_][A-Za-z0-9_]*)\s*\(/g; let m;
  while ((m = re.exec(src))) { const { n } = countArgs(src.slice(m.index + m[0].length)); (defs[key][m[1].toLowerCase()] = defs[key][m[1].toLowerCase()] || new Set()).add(n); }
}
const ours = new Set(Object.keys(defs).map(k => k.split('|')[0]));
const KEYWORDS = new Set(['if','while','for','foreach','switch','return','wait','waittill','endon','notify','waittillmatch','isdefined','thread','function','self','level','undefined','case','else','waitrealtime','waittillframeend','true','false','in','sizeof','int','float','abs','min','max','new','class','constructor','destructor','RandomInt','RandomFloat','GetWeapon','Spawn','IsAlive','IsPlayer','array']);
let bad = 0;
for (const f of files) {
  const src = parsed[f], side = fileSide[f], ns = fileNs[f];
  const lines = src.split('\n');
  const lineOf = idx => src.slice(0, idx).split('\n').length;
  // namespaced calls
  let re = /([A-Za-z_][A-Za-z0-9_]*)::([A-Za-z_][A-Za-z0-9_]*)\s*\(/g, m;
  while ((m = re.exec(src))) {
    if (!ours.has(m[1])) continue;
    // skip function pointers &ns::fn (no call) — they have no '(' so fine; also skip definitions
    const { n } = countArgs(src.slice(m.index + m[0].length));
    const d = defs[m[1] + '|' + side] && defs[m[1] + '|' + side][m[2].toLowerCase()];
    if (!d) { console.log(`UNRESOLVED ${path.relative(root, f)}:${lineOf(m.index)} ${m[1]}::${m[2]}(${n}) — no such function in ${m[1]} (${side})`); bad++; }
    else if (n > Math.max(...d)) { console.log(`ARITY ${path.relative(root, f)}:${lineOf(m.index)} ${m[1]}::${m[2]} called with ${n}, defined with [${[...d]}]`); bad++; }
  }
  // bare calls (same file/namespace) : `name(` not preceded by `::`, `.`, `&`, or `function`
  re = /(?<![A-Za-z0-9_:.&#])([A-Za-z_][A-Za-z0-9_]*)\s*\(/g;
  const local = defs[ns + '|' + side] || {};
  while ((m = re.exec(src))) {
    const name = m[1].toLowerCase();
    if (KEYWORDS.has(name) || !local[name]) continue;
    const before = src.slice(Math.max(0, m.index - 12), m.index);
    if (/function\s+(?:autoexec\s+|private\s+)*$/.test(before)) continue;
    const { n } = countArgs(src.slice(m.index + m[0].length));
    if (n > Math.max(...local[name])) { console.log(`ARITY ${path.relative(root, f)}:${lineOf(m.index)} ${name} called with ${n}, defined with [${[...local[name]]}]`); bad++; }
  }
}
console.log(bad ? `${bad} problem(s)` : 'arity/resolution OK across ' + files.length + ' files');
