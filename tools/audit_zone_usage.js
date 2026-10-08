#!/usr/bin/env node
// =============================================================================
// audit_zone_usage.js - which zone lines does nothing in the repo reference?
//
//   node tools/audit_zone_usage.js            report (all types)
//   node tools/audit_zone_usage.js --type xmodel,weapon,fx   restrict
//   node tools/audit_zone_usage.js --xpak <file.xpak>  attach pack bytes per name
//
// For every asset line in zone_source/zm_tower_of_doom.zone and the zpkgs it
// includes, search the AUTHORING tree (scripts, ui/*.lua, the .map, sound
// CSVs, zone_source, source_data GDTs) for the bare asset name and report
// the ones with NO reference outside their own zone line. A hit in a GDT
// counts (a material referenced by a zoned model's GDT is transitively used),
// so the report errs toward "used".
//
// READ THE OUTPUT AS CANDIDATES, NOT VERDICTS (2026-09-03, docs/86 §8). Two
// ways a zero-reference asset is still live: (1) Lua/GSC builds the name at
// runtime ("i_tod_card_" .. slug) - the audit also tries every prefix of the
// name at each '_' and reports the longest prefix that IS referenced, so a
// computed family shows up as "prefix i_tod_card_ referenced"; (2) a stock
// system asks for it by convention (perk bottle models, powerup materials).
// Dropping a zone line is a -GscOnly change and the linker prints
// "missing asset" for anything a script still asks for - so the safe order
// is: drop, build, grep the linker output for the name, play.
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const REPO = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
function opt(name, dflt) { const i = args.indexOf(name); if (i < 0) return dflt; const v = args[i + 1]; args.splice(i, 2); return v; }
const typeFilter = opt('--type', '').split(',').filter(Boolean);
const xpakFile = opt('--xpak', '');
const MB = x => (x / 1048576).toFixed(1);

// --- gather zone lines (main zone + included zpkgs) ---------------------------
const zoneDir = path.join(REPO, 'zone_source');
const mainZone = path.join(zoneDir, 'zm_tower_of_doom.zone');
const lines = []; // {type, name, file, lineNo}
function readZone(file) {
  const txt = fs.readFileSync(file, 'utf8').split(/\r?\n/);
  txt.forEach((raw, i) => {
    const l = raw.replace(/\/\/.*$/, '').trim();
    if (!l || l.startsWith('>') || l.startsWith('#')) return;
    const m = l.match(/^([a-z_]+),(.+)$/);
    if (!m) return;
    const [, type, name] = m;
    if (type === 'include') { const inc = path.join(zoneDir, name.trim() + '.zpkg'); if (fs.existsSync(inc)) readZone(inc); return; }
    lines.push({ type, name: name.trim(), file: path.basename(file), lineNo: i + 1 });
  });
}
readZone(mainZone);

// --- corpus: every authoring file we search ---------------------------------
const corpus = []; // {file, text}
function walk(dir, exts) {
  if (!fs.existsSync(dir)) return;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { if (!/node_modules|\.git|_images|_bake|spire_wip/.test(e.name)) walk(p, exts); }
    else if (exts.some(x => e.name.toLowerCase().endsWith(x))) corpus.push({ file: path.relative(REPO, p).replace(/\\/g, '/'), text: fs.readFileSync(p, 'utf8') });
  }
}
walk(path.join(REPO, 'scripts'), ['.gsc', '.csc', '.gsh']);
walk(path.join(REPO, 'ui'), ['.lua']);
walk(path.join(REPO, 'map_source'), ['.map']);
walk(path.join(REPO, 'sound'), ['.csv']);
walk(path.join(REPO, 'source_data'), ['.gdt', '.csv']);
walk(path.join(REPO, 'zone_source'), ['.zone', '.zpkg']);
walk(path.join(REPO, 'share'), ['.csv', '.gsc', '.csc']);
const zoneText = fs.readFileSync(mainZone, 'utf8');

// --- optional: pack bytes per name stem --------------------------------------
let packBytes = null;
if (xpakFile && fs.existsSync(xpakFile)) {
  const fd = fs.openSync(xpakFile, 'r');
  const rd = (o, n) => { const b = Buffer.alloc(n); fs.readSync(fd, b, 0, n, o); return b; };
  const h = rd(0, 0x78);
  const hc = Number(h.readBigUInt64LE(48)), ho = Number(h.readBigUInt64LE(56)), ic = Number(h.readBigUInt64LE(96)), io = Number(h.readBigUInt64LE(104)), isz = Number(h.readBigUInt64LE(112));
  const hb = rd(ho, hc * 24); const sz = new Map();
  for (let i = 0; i < hc; i++) sz.set(hb.readBigUInt64LE(i * 24).toString(16), Number(hb.readBigUInt64LE(i * 24 + 16) & 0xFFFFFFFFFFFFFFn));
  const ib = rd(io, isz); fs.closeSync(fd);
  packBytes = []; let pos = 0;
  for (let i = 0; i < ic && pos + 16 <= ib.length; i++) {
    const key = ib.readBigUInt64LE(pos).toString(16); const len = Number(ib.readBigUInt64LE(pos + 8));
    const txt = ib.toString('latin1', pos + 16, pos + 16 + len); pos += 16 + len;
    const nm = (txt.match(/name: (\S+)/) || [])[1] || '';
    packBytes.push({ name: nm, size: sz.get(key) || 0 });
  }
}
function bytesFor(name) {
  if (!packBytes) return -1;
  const stem = name.replace(/^i_/, '');
  let b = 0;
  for (const e of packBytes) if (e.name === name || e.name.startsWith(name + '_') || e.name.startsWith('i_' + stem) || e.name.startsWith(stem + '_lod')) b += e.size;
  return b;
}

// --- reference search ----------------------------------------------------------
function refsFor(name, ownLine) {
  const hits = [];
  const re = new RegExp('(^|[^A-Za-z0-9_])' + name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '($|[^A-Za-z0-9_])');
  for (const c of corpus) {
    if (!re.test(c.text)) continue;
    if (c.file.startsWith('zone_source/')) {
      // ignore the asset's own zone line(s); other zone_source mentions still count
      const others = c.text.split(/\r?\n/).filter(l => re.test(l) && !new RegExp('^\\s*' + ownLine.type + ',\\s*' + name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '\\s*(//.*)?$').test(l));
      if (!others.length) continue;
    }
    hits.push(c.file);
  }
  return hits;
}
function longestReferencedPrefix(name) {
  const parts = name.split('_');
  for (let n = parts.length - 1; n >= 2; n--) {
    const pre = parts.slice(0, n).join('_') + '_';
    const re = new RegExp('["\']' + pre.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
    for (const c of corpus) if (!c.file.startsWith('zone_source/') && !c.file.endsWith('.gdt') && re.test(c.text)) return pre + '  (' + c.file + ')';
  }
  return '';
}

const wanted = typeFilter.length ? lines.filter(l => typeFilter.includes(l.type)) : lines;
const seen = new Set();
const unref = [], ref = [];
for (const l of wanted) {
  const k = l.type + ',' + l.name; if (seen.has(k)) continue; seen.add(k);
  const hits = refsFor(l.name, l);
  (hits.length ? ref : unref).push({ ...l, hits });
}
console.log(`zone lines: ${lines.length} (${wanted.length} audited, ${seen.size} distinct); referenced somewhere: ${ref.length}; NO reference outside the zone: ${unref.length}`);
const byType = {};
for (const u of unref) (byType[u.type] = byType[u.type] || []).push(u);
for (const t of Object.keys(byType).sort()) {
  console.log(`\n== ${t}: ${byType[t].length} unreferenced ==`);
  const rows = byType[t].map(u => ({ ...u, bytes: bytesFor(u.name), pre: longestReferencedPrefix(u.name) }));
  rows.sort((a, b) => b.bytes - a.bytes);
  for (const r of rows) console.log('  ' + (r.bytes >= 0 ? (MB(r.bytes) + ' MB').padStart(10) : ''.padStart(10)) + '  ' + r.name.padEnd(48) + (r.pre ? ' computed? prefix ' + r.pre : '') + `  [${r.file}:${r.lineNo}]`);
}
if (packBytes) {
  const tot = unref.reduce((s, u) => s + Math.max(0, bytesFor(u.name)), 0);
  console.log(`\npack bytes attributable to unreferenced names (upper bound, stems overlap): ${MB(tot)} MB`);
}
