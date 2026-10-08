#!/usr/bin/env node
/*
 * set_image_compression.js - flip `compressionMethod` on tod UI image GDT blocks.
 *
 * WHY THIS EXISTS (2026-09-14). The map holds 920.6 MiB RESIDENT and 731.0 MiB of that
 * (79.4%) is `i_tod_*` UI art, because every one of the 687 image blocks in
 * source_data/tod_ui_images.gdt ships `compressionMethod "uncompressed"` - raw RGBA8,
 * 3.38 MB per 768x1152 card, 176 cards = 594 MiB on their own. Block compression is 4x.
 *
 * READ THIS BEFORE WIDENING THE SELECTION:
 *  - BLOCK COMPRESSION WORKS ON 4x4 BLOCKS. An image whose width or height is not
 *    divisible by 4 is not a safe candidate; the converter's behaviour there (pad? resize?
 *    refuse?) is unproven in this repo. The div-4 gate below keeps those out. They are only
 *    7.2 MiB of the 731 anyway, so excluding them costs ~1% of the win.
 *  - BIGGER IS SAFER, NOT RISKIER. A 768x1152 card is drawn into a fraction of that on
 *    screen, so the GPU downsamples and averages block artifacts away. A 32x32 icon drawn
 *    at 32x32 has no such headroom. That is why this tool selects by SIZE DESCENDING and
 *    why --min-bytes exists.
 *  - THE ART CARRIES BAKED TEXT players read. Quality is the user's call, in game, not a
 *    number in this file. Ship, look, and --restore if it reads worse.
 *
 * USAGE
 *   node tools/set_image_compression.js --dry-run      # plan + projected saving
 *   node tools/set_image_compression.js --apply        # write the GDT + manifest
 *   node tools/set_image_compression.js --restore      # put every touched block back
 *   node tools/set_image_compression.js --verify       # manifest vs live GDT
 * Options: --method "<gdt value>"  --min-bytes N  --limit N  --gdt <path>
 *
 * A GDT EDIT IS ALWAYS A FULL BUILD (CLAUDE.md). -GscOnly will not reconvert these.
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const DEF_GDT = path.join(ROOT, 'source_data', 'tod_ui_images.gdt');
const MANIFEST = path.join(ROOT, 'tools', 'set_image_compression.manifest.json');
const MODTOOLS = process.env.TOD_MODTOOLS ||
  'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';

const argv = process.argv.slice(2);
const has = f => argv.includes(f);
const val = (f, d) => { const i = argv.indexOf(f); return i >= 0 && argv[i + 1] ? argv[i + 1] : d; };

const GDT = path.resolve(val('--gdt', DEF_GDT));
const METHOD = val('--method', 'compressed high color');
const MIN_BYTES = parseInt(val('--min-bytes', '0'), 10);
const LIMIT = parseInt(val('--limit', '0'), 10);

const FROM = 'uncompressed';

function pngSize(p) {
  try {
    const b = fs.readFileSync(p);
    if (b.length < 24 || b.readUInt32BE(0) !== 0x89504e47) return null;
    return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
  } catch (e) { return null; }
}

// Parse `"name" ( "image.gdf" ) { ...body... }` blocks, keeping byte offsets so we can do
// surgical replacements rather than re-serialising a 3 MB GDT we do not fully model.
function parseBlocks(text) {
  const out = [];
  const re = /"([^"\n]+)"\s*\(\s*"image\.gdf"\s*\)\s*\{/g;
  let m;
  while ((m = re.exec(text))) {
    const bodyStart = m.index + m[0].length;
    let depth = 1, i = bodyStart;
    while (i < text.length && depth > 0) {
      const c = text[i];
      if (c === '{') depth++;
      else if (c === '}') depth--;
      i++;
    }
    out.push({ name: m[1], bodyStart: bodyStart, bodyEnd: i - 1, body: text.slice(bodyStart, i - 1) });
  }
  return out;
}

function field(body, key) {
  const m = body.match(new RegExp('"' + key + '"\\s*"([^"]*)"'));
  return m ? m[1] : null;
}

function collect() {
  const text = fs.readFileSync(GDT, 'utf8');
  const blocks = parseBlocks(text);
  const rows = [];
  for (const b of blocks) {
    const cm = field(b.body, 'compressionMethod');
    const bi = field(b.body, 'baseImage');
    if (!cm || !bi) continue;
    const dim = pngSize(path.join(ROOT, bi));
    rows.push({
      name: b.name, cm: cm, baseImage: bi,
      w: dim && dim.w, h: dim && dim.h,
      bytes: dim ? dim.w * dim.h * 4 : 0,
      div4: !!(dim && dim.w % 4 === 0 && dim.h % 4 === 0),
      semantic: field(b.body, 'coreSemantic'),
      noMipMaps: field(b.body, 'noMipMaps'),
      bodyStart: b.bodyStart, bodyEnd: b.bodyEnd,
    });
  }
  return { text: text, rows: rows };
}

function eligible(rows) {
  const r = rows
    .filter(x => x.cm === FROM && x.div4 && x.w && x.bytes >= MIN_BYTES)
    .sort((a, b) => b.bytes - a.bytes);
  return LIMIT > 0 ? r.slice(0, LIMIT) : r;
}

const MB = n => (n / 1048576).toFixed(1);

// The linker's own ledger is the ONLY honest source for what an image actually COSTS.
// The GDT carries blocks the zone never takes (50 of 687 on 2026-09-14 - retired-domain
// card art), and those cost zero resident bytes. Projecting from the GDT alone overstates
// the saving by ~17%. Absent the ledger we fall back to w*h*4 and say so.
function loadLedger() {
  const csv = path.join(MODTOOLS, 'usermaps', 'zm_tower_of_doom', 'zone_source', 'all', 'assetinfo', 'zm_tower_of_doom.csv');
  try {
    const led = {};
    const lines = fs.readFileSync(csv, 'utf8').trim().split(/\r?\n/).slice(1);
    for (const l of lines) {
      const r = l.split(',');
      if (r[1] === 'image') led[r[2]] = Number(r[3]) || 0;
    }
    return Object.keys(led).length ? led : null;
  } catch (e) { return null; }
}

function report(rows, pick, led) {
  const unc = rows.filter(r => r.cm === FROM);
  const skipped = unc.filter(r => !r.div4);
  const cost = r => (led ? (led[r.name] || 0) : r.bytes);
  const zoned = led ? pick.filter(r => cost(r) > 0) : pick;
  const before = zoned.reduce((a, r) => a + cost(r), 0);
  const after = before / 4; // RGBA8 4 bpp -> block compressed 1 bpp
  console.log('GDT                : ' + path.relative(ROOT, GDT));
  console.log('image blocks       : ' + rows.length);
  console.log('currently uncompr. : ' + unc.length);
  console.log('skipped, not div-4 : ' + skipped.length + '  (left uncompressed on purpose)');
  console.log('SELECTED           : ' + pick.length + ' -> "' + METHOD + '"');
  if (led) {
    console.log('  of those ZONED   : ' + zoned.length + '   (' + (pick.length - zoned.length) + ' carry no resident cost - not in the zone)');
    console.log('resident (measured): ' + MB(before) + ' MiB -> ~' + MB(after) + ' MiB   (saves ~' + MB(before - after) + ' MiB)');
  } else {
    console.log('resident (ESTIMATE): ' + MB(before) + ' MiB -> ~' + MB(after) + ' MiB   (saves ~' + MB(before - after) + ' MiB)');
    console.log('  NOTE: linker ledger not found - this ESTIMATE counts unzoned blocks and overstates the saving.');
  }
  const g = {};
  for (const r of pick) { const k = r.w + 'x' + r.h; g[k] = g[k] || { n: 0, b: 0 }; g[k].n++; g[k].b += r.bytes; }
  console.log('');
  console.log('by dimension:');
  Object.entries(g).sort((a, b) => b[1].b - a[1].b).slice(0, 12)
    .forEach(function (e) { console.log('   ' + e[0].padEnd(12) + String(e[1].n).padStart(4) + '  ' + MB(e[1].b).padStart(7) + ' MiB'); });
}

function apply(text, rows, pick) {
  const picked = new Set(pick.map(r => r.name));
  const touched = [];
  // replace back-to-front so earlier offsets stay valid
  const ordered = rows.filter(r => picked.has(r.name)).sort((a, b) => b.bodyStart - a.bodyStart);
  let out = text;
  for (const r of ordered) {
    const body = out.slice(r.bodyStart, r.bodyEnd);
    const re = /("compressionMethod"\s*")([^"]*)(")/;
    const m = body.match(re);
    if (!m || m[2] !== FROM) continue;
    const nb = body.replace(re, '$1' + METHOD + '$3');
    out = out.slice(0, r.bodyStart) + nb + out.slice(r.bodyEnd);
    touched.push({ name: r.name, from: m[2], to: METHOD, w: r.w, h: r.h, bytes: r.bytes });
  }
  return { out: out, touched: touched };
}

(function main() {
  if (!fs.existsSync(GDT)) { console.error('GDT not found: ' + GDT); process.exit(2); }

  if (has('--restore')) {
    if (!fs.existsSync(MANIFEST)) { console.error('no manifest - nothing to restore'); process.exit(2); }
    const man = JSON.parse(fs.readFileSync(MANIFEST, 'utf8'));
    let text = fs.readFileSync(GDT, 'utf8');
    const blocks = parseBlocks(text);
    const want = new Map(man.touched.map(t => [t.name, t.from]));
    let n = 0;
    const ordered = blocks.filter(b => want.has(b.name)).sort((a, b) => b.bodyStart - a.bodyStart);
    for (const b of ordered) {
      const body = text.slice(b.bodyStart, b.bodyEnd);
      const nb = body.replace(/("compressionMethod"\s*")([^"]*)(")/, '$1' + want.get(b.name) + '$3');
      if (nb !== body) { text = text.slice(0, b.bodyStart) + nb + text.slice(b.bodyEnd); n++; }
    }
    fs.writeFileSync(GDT, text);
    fs.unlinkSync(MANIFEST);
    console.log('restored ' + n + ' image blocks to "' + FROM + '" and removed the manifest.');
    console.log('THIS IS A GDT CHANGE - run a FULL build.');
    return;
  }

  const c = collect();

  if (has('--verify')) {
    if (!fs.existsSync(MANIFEST)) { console.log('no manifest present - GDT is in its authored state'); return; }
    const man = JSON.parse(fs.readFileSync(MANIFEST, 'utf8'));
    const live = new Map(c.rows.map(r => [r.name, r.cm]));
    const bad = man.touched.filter(t => live.get(t.name) !== t.to);
    console.log('manifest: ' + man.touched.length + ' blocks -> "' + man.method + '"');
    if (bad.length) { console.error('MISMATCH on ' + bad.length + ': ' + bad.slice(0, 5).map(b => b.name).join(', ')); process.exit(1); }
    console.log('OK - every manifest entry matches the live GDT.');
    return;
  }

  const pick = eligible(c.rows);
  report(c.rows, pick, loadLedger());

  if (has('--apply')) {
    if (!pick.length) { console.log(''); console.log('nothing to do.'); return; }
    const a = apply(c.text, c.rows, pick);
    fs.writeFileSync(GDT, a.out);
    fs.writeFileSync(MANIFEST, JSON.stringify({
      gdt: path.relative(ROOT, GDT), method: METHOD, from: FROM, count: a.touched.length, touched: a.touched,
    }, null, 1));
    console.log('');
    console.log('APPLIED to ' + a.touched.length + ' blocks. Manifest: ' + path.relative(ROOT, MANIFEST));
    console.log('Undo with --restore. THIS IS A GDT CHANGE - run a FULL build.');
  } else if (!has('--dry-run')) {
    console.log('');
    console.log('(no action - pass --apply to write, --dry-run to silence this note)');
  }
})();
