#!/usr/bin/env node
// =============================================================================
// xpak_report.js - what is actually inside usermaps\zm_tower_of_doom\zone\
// zm_tower_of_doom.xpak, byte by byte, and how much of it is dead.
//
//   node tools/xpak_report.js                 full report on the deployed pack
//   node tools/xpak_report.js --brief         one line + exit 2 if dead > --warn-gb
//   node tools/xpak_report.js <file.xpak>     any pack (map 1, a language pack)
//   options: --top N (default 25)  --csv <file>  --warn-gb N (default 1)
//            --stale <regex> (names that should no longer ship; default =
//            the retired perk machines)
//
// WHY THIS EXISTS (2026-09-03): the Workshop item was 9.6 GB. The linker only
// ever APPENDS to the xpak - every full build adds a fresh sun-shadow tree,
// reflection-probe set and probe volumes and never removes the previous
// build's, and every replaced asset leaves its old slot as an un-indexed hole.
// 47 shadow trees under ONE name, 221 probe sets for 55 map probes, 1.37 GB of
// holes: ~5.3 GB of the 9.5 GB pack was history. The remedy is the official
// Workshop guide's own: delete the xpak and re-link (build_map.ps1 -CleanPak).
// This tool is how you PROVE it, before and after, instead of guessing.
//
// FORMAT (reverse-read from the packs on this box; header version 10):
//   0x00 'KAPI'  u16 unk  u16 version  u64 unk  u64 fileSize  u64 fileCount
//   0x20 u64 dataOffset  u64 dataSize  u64 hashCount  u64 hashOffset
//   0x40 u64 hashSize  u64 unk  u64 unkOffset  u64 unk
//   0x60 u64 indexCount  u64 indexOffset  u64 indexSize
//   hash table: hashCount x { u64 key, u64 offset (from dataOffset), u64 size
//                (low 56 bits) }
//   index: indexCount x { u64 key, u64 len, char[len] text } where text is
//          "name: <asset>\ntype: image|mesh|reflectionProbes|probeVolume|SST|
//          skybox\nwidth: ..\nheight: ..\nlevels: ..\nformat: BC7_SRGB..\n..."
//   A streamed image appears as 2-4 entries under the same name (its mip
//   chunks); bake products appear once PER BUILD under the same name.
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const MAP = 'zm_tower_of_doom';
const args = process.argv.slice(2);
function opt(name, dflt) { const i = args.indexOf(name); if (i < 0) return dflt; const v = args[i + 1]; args.splice(i, 2); return v; }
function flag(name) { const i = args.indexOf(name); if (i < 0) return false; args.splice(i, 1); return true; }
const brief = flag('--brief');
const topN = parseInt(opt('--top', '25'), 10);
const csvOut = opt('--csv', '');
const warnGb = parseFloat(opt('--warn-gb', '1'));
const staleRe = new RegExp(opt('--stale', 'deadshot|elemental_pop|mule_?kick'), 'i');
const rootOpt = opt('--root', '');

function toolsRoot() {
  if (rootOpt) return rootOpt;
  const libs = ['C:\\Program Files (x86)\\Steam\\steamapps\\common', 'D:\\Steam\\steamapps\\common', 'E:\\Steam\\steamapps\\common', 'C:\\Steam\\steamapps\\common'];
  for (const lib of libs) {
    if (!fs.existsSync(lib)) continue;
    for (const d of fs.readdirSync(lib)) {
      if (!d.startsWith('Call of Duty Black Ops III')) continue;
      const full = path.join(lib, d);
      if (fs.existsSync(path.join(full, 'bin', 'modlauncher.exe'))) return full;
    }
  }
  throw new Error('could not auto-detect the Mod Tools root (no folder with bin\\modlauncher.exe) - pass --root or a .xpak path');
}
const file = args.find(a => !a.startsWith('--')) || path.join(toolsRoot(), 'usermaps', MAP, 'zone', MAP + '.xpak');
if (!fs.existsSync(file)) { console.error('xpak not found: ' + file); process.exit(1); }

const fd = fs.openSync(file, 'r');
const fileBytes = fs.fstatSync(fd).size;
function rd(off, len) { const b = Buffer.alloc(len); fs.readSync(fd, b, 0, len, off); return b; }
const h = rd(0, 0x78);
if (h.toString('ascii', 0, 4) !== 'KAPI') { console.error('not an xpak (bad magic): ' + file); process.exit(1); }
const H = {
  version: h.readUInt16LE(6), size: Number(h.readBigUInt64LE(16)),
  dataOffset: Number(h.readBigUInt64LE(32)), dataSize: Number(h.readBigUInt64LE(40)),
  hashCount: Number(h.readBigUInt64LE(48)), hashOffset: Number(h.readBigUInt64LE(56)),
  indexCount: Number(h.readBigUInt64LE(96)), indexOffset: Number(h.readBigUInt64LE(104)), indexSize: Number(h.readBigUInt64LE(112)),
};
const hb = rd(H.hashOffset, H.hashCount * 24);
const byKey = new Map();
for (let i = 0; i < H.hashCount; i++) {
  const key = hb.readBigUInt64LE(i * 24).toString(16);
  const off = Number(hb.readBigUInt64LE(i * 24 + 8));
  const size = Number(hb.readBigUInt64LE(i * 24 + 16) & 0xFFFFFFFFFFFFFFn);
  byKey.set(key, { off, size });
}
const ib = rd(H.indexOffset, H.indexSize);
fs.closeSync(fd);
const recs = [];
let pos = 0;
for (let i = 0; i < H.indexCount && pos + 16 <= ib.length; i++) {
  const key = ib.readBigUInt64LE(pos).toString(16);
  const len = Number(ib.readBigUInt64LE(pos + 8));
  const txt = ib.toString('latin1', pos + 16, pos + 16 + len);
  pos += 16 + len;
  const kv = {};
  for (const line of txt.split('\n')) { const m = line.match(/^([a-z0-9_]+):\s*(.*)$/); if (m && !(m[1] in kv)) kv[m[1]] = m[2]; }
  const hs = byKey.get(key) || { off: -1, size: 0 };
  recs.push({ key, name: kv.name || '?', type: kv.type || '?', w: +kv.width || 0, h: +kv.height || 0, levels: +kv.levels || 0, format: kv.format || '', off: hs.off, size: hs.size });
}

const MB = x => (x / 1048576).toFixed(1);
const GB = x => (x / 1073741824).toFixed(2);
const sum = a => a.reduce((s, r) => s + r.size, 0);
const total = sum(recs);

// --- holes: bytes of the data region no indexed entry covers -----------------
const byOff = recs.filter(r => r.off >= 0).slice().sort((a, b) => a.off - b.off);
let holes = 0, holeCount = 0, maxHole = 0;
for (let i = 0; i < byOff.length; i++) {
  const end = byOff[i].off + byOff[i].size;
  const next = i + 1 < byOff.length ? byOff[i + 1].off : H.dataSize;
  const gap = next - end;
  if (gap > 4096) { holes += gap; holeCount++; if (gap > maxHole) maxHole = gap; }
}

// --- bake products: one cluster per sun-shadow tree = one build ----------------
const isBake = r => /^(reflectionProbes|probeVolume|SST)$/.test(r.type);
const bake = recs.filter(isBake).sort((a, b) => a.off - b.off);
const builds = bake.filter(r => r.type === 'SST').length;
const clusters = [];
let cur = null;
for (const r of bake) {
  if (r.type === 'SST' || !cur) { cur = []; clusters.push(cur); }
  cur.push(r);
}
const liveBake = clusters.length ? sum(clusters[clusters.length - 1]) : 0;
const allBake = sum(bake);
const staleBake = allBake - liveBake;

// --- stale-named assets (retired content that should no longer ship) -----------
const staleNamed = recs.filter(r => staleRe.test(r.name));
const staleNamedBytes = sum(staleNamed);

const dead = holes + staleBake + staleNamedBytes;
const projected = fileBytes - dead;

if (brief) {
  console.log(`xpak ${GB(fileBytes)} GB: dead ~${GB(dead)} GB (holes ${GB(holes)} + stale bake ${GB(staleBake)} from ${builds} recorded builds + retired assets ${MB(staleNamedBytes)} MB); projected clean ~${GB(projected)} GB`);
  process.exit(dead > warnGb * 1073741824 ? 2 : 0);
}

console.log('xpak: ' + file);
console.log(`file ${GB(fileBytes)} GB (${fileBytes.toLocaleString()} bytes)  version ${H.version}  entries ${recs.length}  data region ${MB(H.dataSize)} MB  indexed ${MB(total)} MB`);
console.log(`holes (un-indexed bytes between entries): ${MB(holes)} MB in ${holeCount} gaps, largest ${MB(maxHole)} MB`);
console.log(`bake products: ${builds} sun-shadow trees = ${builds} builds recorded; all bake entries ${MB(allBake)} MB, last build's set ~${MB(liveBake)} MB => stale bake ~${MB(staleBake)} MB`);
console.log(`retired-name assets (/${staleRe.source}/): ${staleNamed.length} entries, ${MB(staleNamedBytes)} MB`);
console.log(`DEAD ~${GB(dead)} GB  ->  projected clean pack ~${GB(projected)} GB   (delete the xpak before a full build: build_map.ps1 -CleanPak)`);

function group(label, fn, top) {
  const g = {};
  for (const r of recs) { const k = fn(r); (g[k] = g[k] || { n: 0, b: 0 }); g[k].n++; g[k].b += r.size; }
  console.log('\n== ' + label + ' ==');
  Object.entries(g).sort((a, b) => b[1].b - a[1].b).slice(0, top).forEach(([k, v]) =>
    console.log('  ' + String(k).padEnd(46) + String(v.n).padStart(6) + MB(v.b).padStart(10) + ' MB' + (100 * v.b / total).toFixed(1).padStart(6) + '%'));
}
group('by type', r => r.type, 10);
group('by format', r => r.format || '(none)', 12);
group('images by resolution (max side)', r => r.type === 'image' ? Math.max(r.w, r.h) + 'px' : '(not an image)', 12);
group('by name prefix (3 tokens)', r => r.name.split('_').slice(0, 3).join('_'), 30);
console.log(`\n== top ${topN} entries ==`);
recs.slice().sort((a, b) => b.size - a.size).slice(0, topN).forEach(r =>
  console.log('  ' + MB(r.size).padStart(8) + ' MB  ' + r.type.padEnd(17) + (r.w ? (r.w + 'x' + r.h) : '').padEnd(10) + ' ' + r.format.padEnd(9) + ' ' + r.name));
if (staleNamed.length) {
  console.log('\n== retired-name assets still packed ==');
  const g = {};
  for (const r of staleNamed) { const k = r.name.replace(/_[a-z]$/, ''); (g[k] = g[k] || 0); g[k] += r.size; }
  Object.entries(g).sort((a, b) => b[1] - a[1]).slice(0, 15).forEach(([k, b]) => console.log('  ' + MB(b).padStart(8) + ' MB  ' + k));
}
if (csvOut) {
  const rows = ['name,type,format,width,height,levels,offset,bytes'];
  for (const r of recs.slice().sort((a, b) => b.size - a.size)) rows.push([r.name, r.type, r.format, r.w, r.h, r.levels, r.off, r.size].join(','));
  fs.writeFileSync(csvOut, rows.join('\n'));
  console.log('\ncsv: ' + csvOut);
}
