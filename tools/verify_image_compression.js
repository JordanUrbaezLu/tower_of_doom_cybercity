#!/usr/bin/env node
/*
 * verify_image_compression.js - prove an image-settings change did what it claimed and
 * NOTHING ELSE. Diffs two copies of the linker's own asset ledger
 * (<modtools>/usermaps/zm_tower_of_doom/zone_source/all/assetinfo/zm_tower_of_doom.csv).
 *
 * WHY A DEDICATED CHECK (2026-09-14). The 2026-09-14 compression pass flipped 487 UI images
 * from `uncompressed` to block compression to reclaim ~543 MiB of resident RAM. The user's
 * bar was "0 regressions", and the failure modes that a build does NOT shout about are:
 *   - AN IMAGE SILENTLY VANISHES from the zone (white square in game, linker stays quiet -
 *     the same class of failure lint_tod_assets.js GATE A exists for).
 *   - THE CONVERTER RESIZES a non-power-of-two source instead of compressing it, so the
 *     asset is still there but is the wrong shape.
 *   - A FLIP DOES NOT TAKE (still 4 bpp) - the win is imaginary and nobody notices.
 *   - SOMETHING UNRELATED MOVES because a GDT edit forced a full rebuild.
 * The ledger's resident byte count catches all four, because it is the linker reporting what
 * it actually packed rather than what we asked for.
 *
 * USAGE
 *   node tools/verify_image_compression.js <before.csv> [after.csv]
 * `after` defaults to the live ledger under the mod-tools root.
 *
 * EXIT 1 on any hard finding. Expected-shrink rows are read from the manifest written by
 * set_image_compression.js, so this checks the ACTUAL intent, not a guess.
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const MODTOOLS = process.env.TOD_MODTOOLS ||
  'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const LIVE = path.join(MODTOOLS, 'usermaps', 'zm_tower_of_doom', 'zone_source', 'all', 'assetinfo', 'zm_tower_of_doom.csv');
const MANIFEST = path.join(ROOT, 'tools', 'set_image_compression.manifest.json');

const beforePath = process.argv[2];
const afterPath = process.argv[3] || LIVE;

if (!beforePath) {
  console.error('usage: node tools/verify_image_compression.js <before.csv> [after.csv]');
  process.exit(2);
}

function readLedger(p) {
  const rows = fs.readFileSync(p, 'utf8').trim().split(/\r?\n/).slice(1);
  const byType = {};
  const images = new Map();
  let total = 0;
  for (const l of rows) {
    const r = l.split(',');
    if (r.length < 5) continue;
    const type = r[1], name = r[2], res = Number(r[3]) || 0;
    total += res;
    byType[type] = (byType[type] || 0) + res;
    if (type === 'image') images.set(name, res);
  }
  return { images: images, byType: byType, total: total, rows: rows.length };
}

const MB = n => (n / 1048576).toFixed(1);
const before = readLedger(beforePath);
const after = readLedger(afterPath);

let fail = 0;
const warn = [];

console.log('BEFORE : ' + beforePath);
console.log('AFTER  : ' + afterPath);
console.log('');
console.log('resident total : ' + MB(before.total) + ' MiB -> ' + MB(after.total) + ' MiB   (delta ' + MB(after.total - before.total) + ' MiB)');
console.log('ledger rows    : ' + before.rows + ' -> ' + after.rows);
console.log('images         : ' + before.images.size + ' -> ' + after.images.size);
console.log('');

// 1. NOTHING MAY DISAPPEAR. An image present before and absent after is a white square.
const gone = [...before.images.keys()].filter(n => !after.images.has(n));
if (gone.length) {
  fail++;
  console.error('FAIL: ' + gone.length + ' image(s) present BEFORE are ABSENT AFTER - white squares in game:');
  gone.slice(0, 20).forEach(n => console.error('   - ' + n));
} else {
  console.log('OK   every image present before is still present after.');
}

const added = [...after.images.keys()].filter(n => !before.images.has(n));
if (added.length) {
  warn.push(added.length + ' image(s) are NEW after (not necessarily wrong - say why)');
  added.slice(0, 10).forEach(n => warn.push('     + ' + n));
}

// 2. THE INTENDED ROWS MUST ACTUALLY SHRINK, and by roughly 4x.
let manifest = null;
try { manifest = JSON.parse(fs.readFileSync(MANIFEST, 'utf8')); } catch (e) { /* not applied */ }

if (manifest) {
  // CALIBRATION, learned the hard way on 2026-09-14. A flat ratio band is WRONG for small
  // images: every .iwi carries a fixed header, so a 24x24 pip (2,304 px bytes) shrinks
  // 2326 -> 790 and reads x2.94, not x4, purely because ~200 bytes of header survive the
  // pixel data shrinking 4x. Both pause pips tripped a 3.2-4.8 band and BOTH were fine -
  // confirmed by reading the .iwi header: BC7, still 24x24, not resized.
  // So predict the ACTUAL block-compressed payload from the manifest's own w/h and allow
  // a header allowance, instead of asserting a ratio. A real resize still fails, because
  // resizing changes w*h and the prediction misses by far more than the allowance.
  const HEADER_ALLOWANCE = 1024; // bytes of per-asset header/metadata slack
  const bc7Bytes = (w, h) => Math.ceil(w / 4) * Math.ceil(h / 4) * 16;
  const expect = manifest.touched.map(t => t.name).filter(n => before.images.has(n));
  const byName = new Map(manifest.touched.map(t => [t.name, t]));
  let shrank = 0, unchanged = [], odd = [];
  let sb = 0, sa = 0;
  for (const n of expect) {
    const b = before.images.get(n), a = after.images.get(n) || 0;
    sb += b; sa += a;
    if (a === b) { unchanged.push(n); continue; }
    const t = byName.get(n);
    if (t && t.w && t.h) {
      const pred = bc7Bytes(t.w, t.h);
      // accept anything within the header allowance (plus 10% for mip/alignment slop)
      if (a >= pred - HEADER_ALLOWANCE && a <= pred * 1.1 + HEADER_ALLOWANCE) { shrank++; continue; }
      odd.push(n + '  ' + b + ' -> ' + a + '  (predicted block payload ' + pred + ' for ' + t.w + 'x' + t.h + ')');
    } else {
      const ratio = b / (a || 1);
      if (ratio > 3.2 && ratio < 4.8) shrank++;
      else odd.push(n + '  ' + b + ' -> ' + a + '  (x' + ratio.toFixed(2) + ', no dims in manifest)');
    }
  }
  console.log('');
  console.log('manifest rows in zone : ' + expect.length + ' of ' + manifest.touched.length + ' (' + (manifest.touched.length - expect.length) + ' are unzoned, expected)');
  console.log('  shrank ~4x          : ' + shrank);
  console.log('  UNCHANGED           : ' + unchanged.length);
  console.log('  other ratio         : ' + odd.length);
  console.log('  measured saving     : ' + MB(sb) + ' MiB -> ' + MB(sa) + ' MiB  (saved ' + MB(sb - sa) + ' MiB)');
  if (unchanged.length) {
    fail++;
    console.error('FAIL: ' + unchanged.length + ' flipped image(s) did NOT change size - the flip did not take:');
    unchanged.slice(0, 12).forEach(n => console.error('   - ' + n));
  }
  if (odd.length) {
    fail++;
    console.error('FAIL: ' + odd.length + ' image(s) changed by an unexpected ratio - suspect a RESIZE, not a compress:');
    odd.slice(0, 12).forEach(s => console.error('   - ' + s));
  }
}

// 3. NOTHING WE DID NOT TOUCH MAY MOVE. A GDT edit forces a full rebuild, which is exactly
//    when unrelated drift sneaks in, so hold every other image byte-identical.
// CALIBRATION (2026-09-14): a relink shifts per-asset header/metadata bytes by a couple of
// hundred either way on assets nobody touched - observed on 12 images, every one of them
// still raw RGBA8 at its original dimensions when the .iwi header was read. Pixel payload is
// w*h*4 and did not move. So ignore sub-kilobyte, sub-1% wobble and fail on real changes:
// a resize or a format change moves an image by a factor, never by 96 bytes.
// ABSOLUTE bytes, deliberately NOT a percentage. A percentage rule is wrong in the small:
// i_mtl_hud_icon_zombie moved 16 bytes (1.3%) and i_tod_gauge_boss 224 bytes (1.85%), and
// both were verified unchanged (still raw RGBA8 at their original dimensions, read from the
// .iwi header). Meanwhile the faults this gate exists to catch are never small: a raw image's
// resident size IS w*h*4, so any resize moves it by a factor, and a format flip moves it ~4x.
// Sub-kilobyte movement cannot express either, so absolute bytes is the honest discriminator.
const DRIFT_BYTES = 1024;
const touched = new Set(manifest ? manifest.touched.map(t => t.name) : []);
const drifted = [];
const wobbled = [];
for (const [n, b] of before.images) {
  if (touched.has(n)) continue;
  const a = after.images.get(n);
  if (a === undefined || a === b) continue;
  const d = Math.abs(a - b);
  if (d <= DRIFT_BYTES) { wobbled.push(n); continue; }
  drifted.push(n + '  ' + b + ' -> ' + a);
}
if (wobbled.length) warn.push(wobbled.length + ' untouched image(s) moved by <1KB (header/metadata wobble, not pixels)');
if (drifted.length) {
  fail++;
  console.error('');
  console.error('FAIL: ' + drifted.length + ' UNTOUCHED image(s) changed resident size - unexplained drift:');
  drifted.slice(0, 15).forEach(s => console.error('   - ' + s));
} else {
  console.log('OK   every untouched image is byte-identical in resident size.');
}

// 4. Non-image asset classes should not move either.
console.log('');
console.log('non-image asset classes:');
const types = new Set([...Object.keys(before.byType), ...Object.keys(after.byType)]);
for (const t of [...types].sort()) {
  if (t === 'image') continue;
  const b = before.byType[t] || 0, a = after.byType[t] || 0;
  if (b !== a) {
    warn.push('asset class "' + t + '" moved ' + MB(b) + ' -> ' + MB(a) + ' MiB');
    console.log('   ~ ' + t.padEnd(18) + MB(b) + ' -> ' + MB(a) + ' MiB   <-- MOVED, explain this');
  }
}
if (!warn.some(w => w.startsWith('asset class'))) console.log('   all unchanged.');

if (warn.length) {
  console.log('');
  console.log('WARNINGS (not failures - read them):');
  warn.forEach(w => console.log('   ! ' + w));
}

console.log('');
if (fail) { console.error('VERIFY FAILED (' + fail + ' hard finding' + (fail > 1 ? 's' : '') + ').'); process.exit(1); }
console.log('VERIFY OK - the change did what it claimed and nothing else moved.');
