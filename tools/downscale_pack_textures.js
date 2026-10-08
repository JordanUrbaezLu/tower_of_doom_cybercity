#!/usr/bin/env node
// =============================================================================
// downscale_pack_textures.js - cap the resolution of third-party pack textures
// AT THEIR SOURCE (the PNG/TIF a GDT's baseImage points at), with the original
// moved to a backup tree so the change is one command to undo.
//
//   node tools/downscale_pack_textures.js --cap 1024 <gdt> [<gdt>...]   DRY RUN
//   node tools/downscale_pack_textures.js --cap 1024 <gdt>... --apply    do it
//   node tools/downscale_pack_textures.js --restore [<gdt>...]           undo
//                                          (no gdt = restore everything)
//   options: --root <modtools>  --backup <dir>  --filter <regex on image name>
//            --ffmpeg <exe>  --ffprobe <exe>
//   gdt paths are absolute or relative to the Mod Tools root.
//
// WHY (2026-09-03, docs/86): the live content of the shipped xpak is ~3.5 GB
// and a third of it is texture resolution nobody can see - the BO7 perk
// machines (WetEgg/SAT pack) carry 4096x4096 PBR sets on a world prop, the
// Leviathan axe / gift gun / Klauser ports carry 4K on first-person guns.
// The image GDT has no size cap, so the source pixels are the only lever.
//
// HOW IT WORKS: for every `"name" ( "image.gdf" )` block in the given GDTs,
// ffprobe the baseImage; if its longest side exceeds --cap, MOVE the original
// to <backup>/<same relative path> (same volume = instant, no copy) and write
// a resized file in its place with ffmpeg (area filter: no ringing on normal
// maps or alpha), keeping the file's own pixel format and extension so the
// GDT never changes. A manifest (<backup>/manifest.json) records every file;
// --restore moves the originals back. The next FULL build re-converts the
// changed sources (gdtdb hashes them) and the clean xpak shrinks accordingly.
// Never touches a GDT. Never touches a file whose backup already exists
// unless it still exceeds the cap (a tighter cap resizes the current file
// and keeps the earliest backup as the true original).
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const argv = process.argv.slice(2);
function opt(name, dflt) { const i = argv.indexOf(name); if (i < 0) return dflt; const v = argv[i + 1]; argv.splice(i, 2); return v; }
function flag(name) { const i = argv.indexOf(name); if (i < 0) return false; argv.splice(i, 1); return true; }
const apply = flag('--apply');
const restore = flag('--restore');
const cap = parseInt(opt('--cap', '0'), 10);
const rootOpt = opt('--root', '');
const backupOpt = opt('--backup', '');
const filterRe = new RegExp(opt('--filter', '.'), 'i');
const FFMPEG = opt('--ffmpeg', 'ffmpeg');
const FFPROBE = opt('--ffprobe', 'ffprobe');
const gdts = argv.filter(a => !a.startsWith('--'));

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
  throw new Error('could not auto-detect the Mod Tools root - pass --root');
}
const ROOT = toolsRoot();
const BACKUP = backupOpt || path.join(ROOT, '_tod_texture_originals');
const MANIFEST = path.join(BACKUP, 'manifest.json');
const MB = x => (x / 1048576).toFixed(1);

function loadManifest() { try { return JSON.parse(fs.readFileSync(MANIFEST, 'utf8')); } catch (e) { return { entries: [] }; } }
function saveManifest(m) { fs.mkdirSync(BACKUP, { recursive: true }); fs.writeFileSync(MANIFEST, JSON.stringify(m, null, 1)); }

function probe(file) {
  const r = spawnSync(FFPROBE, ['-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height,pix_fmt', '-of', 'csv=p=0', file], { encoding: 'utf8' });
  if (r.status !== 0) return null;
  const [w, h, pf] = r.stdout.trim().split(',');
  return { w: +w, h: +h, pix_fmt: (pf || '').trim() };
}
function encoderPixFmt(pf, ext) {
  if (!pf || pf === 'pal8' || pf === 'monob') return 'rgba';
  if (ext === '.tif' || ext === '.tiff') {
    if (pf.endsWith('be')) return pf.replace(/be$/, 'le'); // tiff encoder takes little-endian 16-bit
  }
  return pf;
}
function parseGdtImages(gdtPath) {
  const txt = fs.readFileSync(gdtPath, 'utf8');
  const re = /"([^"]+)"\s*\(\s*"image\.gdf"\s*\)\s*\{([\s\S]*?)\n\s*\}/g;
  const out = [];
  let m;
  while ((m = re.exec(txt))) {
    const bi = m[2].match(/"baseImage"\s+"([^"]*)"/);
    if (!bi || !bi[1]) continue;
    const rel = bi[1].replace(/\\\\/g, '\\').replace(/\\/g, '/');
    const abs = path.isAbsolute(rel) ? rel : path.join(ROOT, rel);
    out.push({ name: m[1], rel: path.relative(ROOT, abs).replace(/\\/g, '/'), abs, gdt: path.basename(gdtPath) });
  }
  return out;
}
function moveFile(from, to) {
  fs.mkdirSync(path.dirname(to), { recursive: true });
  try { fs.renameSync(from, to); } catch (e) { if (e.code !== 'EXDEV') throw e; fs.copyFileSync(from, to); fs.unlinkSync(from); }
}

const resolvedGdts = gdts.map(g => path.isAbsolute(g) ? g : path.join(ROOT, g));
for (const g of resolvedGdts) if (!fs.existsSync(g)) { console.error('GDT not found: ' + g); process.exit(1); }

if (restore) {
  const man = loadManifest();
  const limit = resolvedGdts.length ? new Set(resolvedGdts.flatMap(parseGdtImages).map(i => i.rel)) : null;
  let n = 0, kept = [];
  for (const e of man.entries) {
    if (limit && !limit.has(e.rel)) { kept.push(e); continue; }
    const bak = path.join(BACKUP, e.rel);
    if (!fs.existsSync(bak)) { console.log('  no backup on disk, skipped: ' + e.rel); kept.push(e); continue; }
    const dst = path.join(ROOT, e.rel);
    if (fs.existsSync(dst)) fs.unlinkSync(dst);
    moveFile(bak, dst);
    console.log('  restored ' + e.rel + ' (' + e.before.w + 'x' + e.before.h + ')');
    n++;
  }
  man.entries = kept;
  saveManifest(man);
  console.log(`restored ${n} file(s); ${kept.length} manifest entr${kept.length === 1 ? 'y' : 'ies'} remain`);
  process.exit(0);
}

if (!cap || !resolvedGdts.length) {
  console.error('usage: node tools/downscale_pack_textures.js --cap <px> <gdt>... [--apply] | --restore [<gdt>...]');
  process.exit(1);
}
if (!spawnSync(FFPROBE, ['-version']).stdout) { console.error('ffprobe not runnable (' + FFPROBE + ')'); process.exit(1); }

console.log(`mod tools root: ${ROOT}\nbackup tree:    ${BACKUP}\ncap:            ${cap}px longest side\nmode:           ${apply ? 'APPLY' : 'dry run (add --apply)'}`);
const seen = new Set();
const candidates = [];
let probed = 0, missing = 0, under = 0;
for (const g of resolvedGdts) {
  for (const img of parseGdtImages(g)) {
    if (seen.has(img.rel) || !filterRe.test(img.name)) continue;
    seen.add(img.rel);
    if (!fs.existsSync(img.abs)) { missing++; continue; }
    const p = probe(img.abs);
    probed++;
    if (!p) { console.log('  ! ffprobe failed: ' + img.rel); continue; }
    if (Math.max(p.w, p.h) <= cap) { under++; continue; }
    const scale = cap / Math.max(p.w, p.h);
    const nw = Math.max(1, Math.round(p.w * scale)), nh = Math.max(1, Math.round(p.h * scale));
    candidates.push({ ...img, ...p, nw, nh, bytes: fs.statSync(img.abs).size });
  }
}
console.log(`\n${probed} source images probed (${missing} missing on disk, ${under} already within the cap); ${candidates.length} exceed ${cap}px:`);
candidates.sort((a, b) => b.bytes - a.bytes);
for (const c of candidates) console.log('  ' + MB(c.bytes).padStart(7) + ' MB  ' + (c.w + 'x' + c.h).padEnd(10) + '-> ' + (c.nw + 'x' + c.nh).padEnd(10) + c.pix_fmt.padEnd(9) + c.rel);
console.log('  total on disk: ' + MB(candidates.reduce((s, c) => s + c.bytes, 0)) + ' MB');
if (!apply || !candidates.length) process.exit(0);

const man = loadManifest();
let done = 0, failed = 0, afterBytes = 0;
for (const c of candidates) {
  const ext = path.extname(c.abs).toLowerCase();
  const bak = path.join(BACKUP, c.rel);
  const tmp = c.abs + '.downscale_tmp' + ext;
  let src = c.abs;
  if (!fs.existsSync(bak)) { moveFile(c.abs, bak); src = bak; }
  else { src = c.abs; }
  const pf = encoderPixFmt(c.pix_fmt, ext);
  const ffArgs = ['-v', 'error', '-y', '-i', src, '-vf', `scale=${c.nw}:${c.nh}:flags=area`, '-pix_fmt', pf];
  if (ext === '.tif' || ext === '.tiff') ffArgs.push('-compression_algo', 'lzw');
  ffArgs.push(tmp);
  const r = spawnSync(FFMPEG, ffArgs, { encoding: 'utf8' });
  const ok = r.status === 0 && fs.existsSync(tmp) && fs.statSync(tmp).size > 0;
  if (!ok) {
    failed++;
    console.log('  ! ffmpeg FAILED on ' + c.rel + ': ' + (r.stderr || '').trim().split('\n').pop());
    if (fs.existsSync(tmp)) fs.unlinkSync(tmp);
    if (src === bak && !fs.existsSync(c.abs)) moveFile(bak, c.abs); // put the original back, nothing changed
    continue;
  }
  if (fs.existsSync(c.abs)) fs.unlinkSync(c.abs);
  fs.renameSync(tmp, c.abs);
  const v = probe(c.abs);
  const nb = fs.statSync(c.abs).size;
  afterBytes += nb;
  man.entries = man.entries.filter(e => e.rel !== c.rel);
  man.entries.push({ rel: c.rel, name: c.name, gdt: c.gdt, before: { w: c.w, h: c.h, bytes: c.bytes, pix_fmt: c.pix_fmt }, after: { w: v ? v.w : nw, h: v ? v.h : nh, bytes: nb }, cap, when: new Date().toISOString() });
  saveManifest(man);
  done++;
  console.log('  ok ' + (c.w + 'x' + c.h).padEnd(10) + '-> ' + (v ? v.w + 'x' + v.h : '?').padEnd(10) + MB(c.bytes).padStart(7) + ' -> ' + MB(nb).padStart(6) + ' MB  ' + c.rel);
}
console.log(`\n${done} resized, ${failed} failed; on disk ${MB(candidates.reduce((s, c) => s + c.bytes, 0))} MB -> ${MB(afterBytes)} MB; originals in ${BACKUP}`);
console.log('next: a FULL build with -CleanPak (the converter re-reads changed sources; the clean pack drops the old chunks).');
process.exit(failed ? 1 : 0);
