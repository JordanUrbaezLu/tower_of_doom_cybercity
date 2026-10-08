#!/usr/bin/env node
// tools/patch_notes.js — PUBLISH PREP = BUILD + PATCH NOTES (user 2026-09-02:
// "when I ask for a full build for publish prep we need to generate patch
// notes as well ... record the notes by day and time to be accurate").
//
// The ledger (docs/publish_ledger.json) holds one row per Steam Workshop
// upload: when it went up (machine clock, Eastern), which .ff, and the NEWEST
// CHANGELOG header it contained. Everything above that header in CHANGELOG.md
// is "unreleased", and that is exactly the window the next patch notes cover.
//
//   node tools/patch_notes.js window            -> docs/patch_notes_window.md: every CHANGELOG entry
//                                                  newer than the last upload (raw), plus the newest
//                                                  docs/68 section as the style reference. READ IT,
//                                                  then write the new section at the top of
//                                                  docs/68_patch_notes.md and the BBCode file.
//   node tools/patch_notes.js stage --version vX.Y
//                                               -> records a PENDING ledger row: cutoff = the current
//                                                  top CHANGELOG header, notes section = docs/68's top
//                                                  heading (must name vX.Y and carry today's date).
//   node tools/patch_notes.js check             -> the gate build_map.ps1 -Publish runs: a pending row
//                                                  exists, its cutoff is STILL the top CHANGELOG header,
//                                                  and docs/68 + the BBCode file lead with its section.
//   node tools/patch_notes.js built [--ff path] -> stamps the pending row with the .ff's write time
//                                                  (build_map.ps1 -Publish calls this after BUILD OK).
//   node tools/patch_notes.js uploaded [--at "YYYY-MM-DD HH:MM"]
//                                               -> after the user uploads: reads the newest time off the
//                                                  Steam change-log page (Pacific, +3 h), refuses if it
//                                                  predates the build, closes the row, and writes the
//                                                  upload time into the docs/68 section line.
//   node tools/patch_notes.js status            -> ledger tail + what is pending.
//
// Exit 0 = ok. Exit 1 = a gate failed and the message says what to do.

'use strict';
const fs = require('fs');
const path = require('path');
const https = require('https');

// PATCH_NOTES_REPO lets the selftest run every lane against a scratch copy.
const REPO = process.env.PATCH_NOTES_REPO ? path.resolve(process.env.PATCH_NOTES_REPO) : path.resolve(__dirname, '..');
const F = {
  ledger: path.join(REPO, 'docs', 'publish_ledger.json'),
  changelog: path.join(REPO, 'CHANGELOG.md'),
  notes: path.join(REPO, 'docs', '68_patch_notes.md'),
  bbcode: path.join(REPO, 'docs', '68_patch_notes_steam_bbcode.txt'),
  window: path.join(REPO, 'docs', 'patch_notes_window.md'),
};
const DEFAULT_FF = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/usermaps/zm_tower_of_doom/zone/zm_tower_of_doom.ff';
const STEAM_ITEM = '3788921059';
// 0 SINCE 2026-09-13, AND THE OLD 3 WAS WRONG ON EVERY ROW IT TOUCHED.
// The Workshop change-log page renders in the VIEWER'S OWN timezone, not
// Pacific, so the time the user reads off the page is already this machine's
// clock. PROVEN BY CONTRADICTION: the page showed 'Sep 13 @ 1:59pm' for an
// upload the user had already made, and 1:59pm Pacific is 4:59pm Eastern —
// a time that had not happened yet (it was 3:25pm). An upload cannot be in
// the future, so the +3 was the error. It had silently pushed rows 34, 35
// and 36 three hours late too, turning plausible 10-26 minute build->upload
// gaps into implausible 3-hour ones; all four rows are corrected in the
// ledger. If a reconstructed upload time ever lands in the future, or hours
// after its own .ff with nothing in between, suspect this constant first.
//
// 3 AGAIN SINCE 2026-09-16 — BUT ONLY FOR THE PAGE THIS TOOL FETCHES ITSELF,
// and the 2026-09-13 finding above still stands for the page the USER reads.
// The two are different pages: the browser renders the change log in the
// LOGGED-IN viewer's zone (Eastern here), which is why a pasted time needs 0
// and every `--at` row was right. This tool's own https.get is anonymous and
// gets Valve's default, PACIFIC. Proven the same way the 0 was: the fetch read
// 'Sep 16 @ 7:49am' for an upload of the 10:36:04 .ff the user confirmed they
// had made — 07:49 Eastern is three hours BEFORE its own build, impossible;
// 07:49 Pacific is 10:49 Eastern, thirteen minutes after it, the ordinary gap.
// This constant is applied at exactly one site, the fetch path below; `--at`
// takes the time as typed. Paste from the browser = 0, fetch = 3.
const STEAM_TO_LOCAL_HOURS = 3;
const MON = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

function fail(msg) { console.error('[patch_notes] FAIL: ' + msg); process.exit(1); }
function info(msg) { console.log('[patch_notes] ' + msg); }
function pad(n) { return String(n).padStart(2, '0'); }
function fmt(d, secs) { return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}${secs ? ':' + pad(d.getSeconds()) : ''}`; }
function fmtHuman(d) { let h = d.getHours(), ap = h >= 12 ? 'pm' : 'am'; h = h % 12 || 12; return `${MON[d.getMonth()]} ${d.getDate()}, ${h}:${pad(d.getMinutes())} ${ap}`; }
function parseLocal(s) { const m = String(s).match(/^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?/); if (!m) return null; return new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +(m[6] || 0)); }
function arg(name) { const i = process.argv.indexOf(name); return i > 0 ? process.argv[i + 1] : null; }

function readLedger() {
  if (!fs.existsSync(F.ledger)) fail('missing ' + F.ledger);
  const L = JSON.parse(fs.readFileSync(F.ledger, 'utf8'));
  if (!Array.isArray(L.uploads) || !L.uploads.length) fail('ledger has no uploads');
  return L;
}
function writeLedger(L) { fs.writeFileSync(F.ledger, JSON.stringify(L, null, 2) + '\n', 'utf8'); }
function pendingRow(L) { return L.uploads.find(u => u.status === 'pending') || null; }
function lastUploaded(L) { const rows = L.uploads.filter(u => u.status === 'uploaded'); return rows[rows.length - 1]; }

function changelogEntries() {
  const lines = fs.readFileSync(F.changelog, 'utf8').split('\n');
  const out = [];
  lines.forEach((l, i) => { if (l.startsWith('## ')) out.push({ header: l.trimEnd(), start: i }); });
  out.forEach((e, k) => { e.end = k + 1 < out.length ? out[k + 1].start : lines.length; e.body = lines.slice(e.start, e.end).join('\n'); });
  return out;
}
function topHeader() { const e = changelogEntries(); if (!e.length) fail('CHANGELOG has no entries'); return e[0].header; }

function notesTopSection() {
  // docs/68: first "## " heading after the title; section runs to the next "---" or "## "
  const lines = fs.readFileSync(F.notes, 'utf8').split('\n');
  let i = lines.findIndex(l => /^## /.test(l));
  if (i < 0) fail('docs/68_patch_notes.md has no "## " section');
  let j = i + 1; while (j < lines.length && !/^## /.test(lines[j]) && lines[j].trim() !== '---') j++;
  return { title: lines[i].slice(3).trim(), start: i, end: j, text: lines.slice(i, j).join('\n'), lines };
}
function bbcodeTopBlock() {
  const lines = fs.readFileSync(F.bbcode, 'utf8').split('\n');
  const i = lines.findIndex(l => /^=+$/.test(l));
  if (i < 0 || !lines[i + 1]) fail('BBCode file has no block header');
  return lines[i + 1].trim();
}
function parseSectionTitle(t) {
  // "Update — Sep 1 (v16.5)" | "Initial release — Aug 23 (v10.1)"
  const m = t.match(/^(Update|Initial release) — ([A-Z][a-z]{2}) (\d{1,2})(?:, [^(]+)? \((.+)\)$/);
  if (!m) return null;
  return { kind: m[1], mon: MON.indexOf(m[2]), day: +m[3], label: m[4] };
}

// ---------------------------------------------------------------- commands
function cmdWindow() {
  const L = readLedger();
  const last = lastUploaded(L);
  const entries = changelogEntries();
  const idx = entries.findIndex(e => e.header === last.changelog_cutoff);
  if (idx < 0) fail(`the last upload's cutoff header is not in CHANGELOG.md any more:\n  ${last.changelog_cutoff}\n  (renamed? fix the ledger row's changelog_cutoff to the exact header line)`);
  const win = entries.slice(0, idx);
  const pend = pendingRow(L);
  const clocks = e => [...new Set([...e.body.matchAll(/(?:@|linked at|\.ff)[^\n]{0,25}?\b(\d{1,2}:\d{2}(?::\d{2})?(?: ?[AP]M)?)/g)].map(m => m[1]))];
  let out = [];
  out.push(`# Patch-notes window — everything newer than Workshop upload #${last.n} (${last.version}, uploaded ${last.uploaded})`);
  out.push(`# Generated ${fmt(new Date(), true)} by tools/patch_notes.js window. ${win.length} CHANGELOG entries, newest first.`);
  if (pend) out.push(`# A PENDING row already exists (#${pend.n}, ${pend.version}, cutoff "${pend.changelog_cutoff}") — re-run "stage" if the CHANGELOG moved.`);
  out.push('#');
  out.push('# HOW TO USE: condense these into ONE new section at the top of docs/68_patch_notes.md, titled');
  out.push('#   ## Update — <Mon D> (<version>)      e.g.  ## Update — Sep 3 (v16.26)');
  out.push('# with the headings ### New / ### Balance / ### Improvements / ### Fixes (drop empty ones), then the');
  out.push('# same section as a [h2]/[list] block at the top of docs/68_patch_notes_steam_bbcode.txt.');
  out.push('# RULES (the style reference at the bottom is the standard): player-facing only — no builds, versions,');
  out.push('# harnesses, "unverified", engine/mechanism talk, docs, art prompts. Keep the numbers players feel.');
  out.push(`# SHORT AND PLAIN (user, 2026-09-10: "reduce any jargon ... we dont need a billion characters"):`);
  out.push(`# ONE LINE PER BULLET, ${MAX_BULLET} characters at most — stage() FAILS on a longer one. Say what changed,`);
  out.push('# not how or why. Group related knobs into one bullet instead of listing each. A second clause that');
  out.push('# only justifies the first is cut. Sections before Sep 10 2026 are the older, longer style.');
  out.push('# Net the window: a change made and undone inside it is dropped; a number changed twice states old -> final.');
  out.push('# Dev/test-only entries (armed flags, harnesses, lints, tooling) contribute nothing.');
  out.push('');
  out.push('## Index (date · version · recorded build clocks)');
  for (const e of win) { const c = clocks(e); out.push(`- ${e.header.slice(3)}${c.length ? '   [clocks: ' + c.join(', ') + ']' : ''}`); }
  out.push('');
  out.push('## Raw entries');
  out.push('');
  for (const e of win) { out.push(e.body.trimEnd()); out.push(''); }
  out.push('');
  out.push('## STYLE REFERENCE — the newest section already in docs/68_patch_notes.md');
  out.push('');
  out.push(notesTopSection().text);
  fs.writeFileSync(F.window, out.join('\n') + '\n', 'utf8');
  info(`window: ${win.length} entries since upload #${last.n} (${last.version}, ${last.uploaded}) -> ${path.relative(REPO, F.window)}`);
  for (const e of win) info('  ' + e.header.slice(3, 110));
  if (!win.length) info('nothing newer than the last upload — no patch notes needed (is the CHANGELOG entry for this build written yet?)');
}

// SHORT AND PLAIN: the per-bullet ceiling the user set on 2026-09-10. Raising it
// is a style decision, not a convenience — the point is that a player reads the
// whole note in under a minute.
const MAX_BULLET = 200;

function validateNotes(version) {
  const top = notesTopSection();
  const t = parseSectionTitle(top.title);
  if (!t) fail(`docs/68 top heading is not in the expected shape:\n  "${top.title}"\n  expected  ## Update — <Mon D> (<version>)`);
  if (!top.title.includes(version)) fail(`docs/68 top section is "${top.title}" — it does not name ${version}. Write the new section first (node tools/patch_notes.js window).`);
  const lines = top.text.split('\n').filter(l => /^- /.test(l));
  const bullets = lines.length;
  if (bullets < 1) fail(`docs/68 top section "${top.title}" has no bullets`);
  // SHORT AND PLAIN (user, 2026-09-10). The Sep 10 2026 section is the standard;
  // everything above it in docs/68 is the older style and is never re-checked.
  const over = lines.map(l => ({ l, n: l.replace(/^- /, '').replace(/\*\*/g, '').length })).filter(x => x.n > MAX_BULLET);
  if (over.length) fail(`${over.length} bullet(s) over ${MAX_BULLET} characters — change notes are one short line each,\n`
    + `no jargon, no explaining how or why (user 2026-09-10). Longest first:\n`
    + over.sort((a, b) => b.n - a.n).slice(0, 5).map(x => `  ${x.n}: ${x.l.slice(0, 110)}...`).join('\n'));
  const bb = bbcodeTopBlock();
  if (!bb.includes(version)) fail(`the BBCode file's top block is "${bb}" — it does not name ${version}. Add the block at the top of ${path.relative(REPO, F.bbcode)}.`);
  // whole words only — the first draft matched "lintel" on `lint` (selftest 2026-09-02)
  const banned = /(\bv\d+\.\d+\b|-GscOnly|\.ff\b|\bunverified\b|\bharness\b|\bclientfield\b|\bnavmesh\b|\blints?\b|\bdev\b|\bgod mode\b|\bscriptparsetree\b)/i;
  const hit = top.text.split('\n').filter(l => /^- /.test(l)).find(l => banned.test(l));
  if (hit) fail(`docs/68 top section carries a dev-facing bullet (players never see these):\n  ${hit}`);
  return { top, t, bullets };
}

function cmdStage() {
  const version = arg('--version');
  if (!version) fail('stage needs --version vX.Y (the label players will see in the section heading)');
  const L = readLedger();
  const { top, t, bullets } = validateNotes(version);
  const now = new Date();
  if (t.mon !== now.getMonth() || t.day !== now.getDate()) {
    if (!process.argv.includes('--any-date')) fail(`docs/68 top section is dated "${MON[t.mon]} ${t.day}" but today is ${MON[now.getMonth()]} ${now.getDate()}. The heading date is the upload day — retitle it, or pass --any-date if the upload really is on another day.`);
  }
  const cutoff = topHeader();
  if (/\(docs\)|\(tooling\)/.test(cutoff)) info(`note: the top CHANGELOG entry is "${cutoff.slice(3, 80)}" — make sure the publish build's own entry is written and on top before you build`);
  let row = pendingRow(L);
  const n = row ? row.n : Math.max(...L.uploads.map(u => u.n)) + 1;
  const fresh = { n, status: 'pending', staged: fmt(now, true), uploaded: null, ff_time: null, version, confidence: 'exact', changelog_cutoff: cutoff, notes_section: top.title, notes_bullets: bullets };
  if (row) { Object.assign(row, fresh); info(`re-staged pending row #${n}`); } else { L.uploads.push(fresh); info(`staged pending row #${n}`); }
  writeLedger(L);
  info(`version ${version} · cutoff "${cutoff.slice(3, 90)}" · notes "${top.title}" (${bullets} bullets)`);
}

function cmdCheck() {
  const L = readLedger();
  const row = pendingRow(L);
  if (!row) fail('no PENDING ledger row. Publish prep is: (1) node tools/patch_notes.js window, (2) write the section in docs/68 + the BBCode file, (3) node tools/patch_notes.js stage --version vX.Y, (4) build with -Publish.');
  const cutoff = topHeader();
  if (cutoff !== row.changelog_cutoff) fail(`the CHANGELOG moved since staging.\n  staged cutoff: ${row.changelog_cutoff}\n  top now:       ${cutoff}\n  -> fold the new entries into the docs/68 section if they matter to players, then re-run: node tools/patch_notes.js stage --version ${row.version}`);
  const { top } = validateNotes(row.version);
  if (top.title !== row.notes_section) fail(`docs/68 top section "${top.title}" != staged "${row.notes_section}" — re-run stage`);
  info(`OK: pending #${row.n} ${row.version} · notes "${row.notes_section}" · cutoff is the top CHANGELOG header`);
}

function cmdBuilt() {
  const L = readLedger();
  const row = pendingRow(L);
  if (!row) fail('no pending row to stamp (run stage first)');
  const ff = arg('--ff') || DEFAULT_FF;
  if (!fs.existsSync(ff)) fail('no .ff at ' + ff);
  const st = fs.statSync(ff);
  row.ff_time = fmt(st.mtime, true);
  row.ff_bytes = st.size;
  writeLedger(L);
  info(`pending #${row.n} ${row.version}: .ff ${fmt(st.mtime, true)} (${st.size.toLocaleString()} bytes) — upload it, then run: node tools/patch_notes.js uploaded`);
}

function fetchSteamLatest() {
  return new Promise((resolve, reject) => {
    const url = `https://steamcommunity.com/sharedfiles/filedetails/changelog/${STEAM_ITEM}`;
    https.get(url, { headers: { 'User-Agent': 'Mozilla/5.0' } }, res => {
      let data = ''; res.on('data', c => data += c); res.on('end', () => {
        const m = data.match(/Update:\s*([A-Z][a-z]{2}) (\d{1,2})(?:, (\d{4}))? @ (\d{1,2}):(\d{2})(am|pm)/);
        if (!m) return reject(new Error('could not find an "Update: Mon D @ H:MMam" line on the Steam page (status ' + res.statusCode + ')'));
        const year = m[3] ? +m[3] : new Date().getFullYear();
        let h = +m[4] % 12; if (m[6] === 'pm') h += 12;
        const steamLocal = new Date(year, MON.indexOf(m[1]), +m[2], h, +m[5]);
        resolve(new Date(steamLocal.getTime() + STEAM_TO_LOCAL_HOURS * 3600 * 1000));
      });
    }).on('error', reject);
  });
}

async function cmdUploaded() {
  const L = readLedger();
  const row = pendingRow(L);
  if (!row) fail('no pending row (nothing was staged/built)');
  let when;
  const at = arg('--at');
  if (at) { when = parseLocal(at); if (!when) fail('--at needs "YYYY-MM-DD HH:MM"'); }
  else { try { when = await fetchSteamLatest(); } catch (e) { fail(e.message + ' — pass --at "YYYY-MM-DD HH:MM" (Eastern) from the Steam page by hand'); } }
  if (row.ff_time) {
    const ff = parseLocal(row.ff_time);
    if (when < ff) fail(`the newest upload on Steam is ${fmt(when)} but the pending .ff was written ${row.ff_time} — the upload has not happened yet (or Steam has not refreshed). Upload first, then re-run.`);
  }
  row.uploaded = fmt(when);
  row.status = 'uploaded';
  writeLedger(L);
  // stamp the docs/68 section line
  const top = notesTopSection();
  if (top.title === row.notes_section) {
    const k = top.lines.findIndex((l, i) => i > top.start && i < top.end && /^\*Workshop upload:/.test(l));
    const line = `*Workshop upload: ${row.version} — ${fmtHuman(when)}*`;
    if (k >= 0) top.lines[k] = line; else top.lines.splice(top.start + 1, 0, line);
    fs.writeFileSync(F.notes, top.lines.join('\n'), 'utf8');
  }
  info(`upload #${row.n} ${row.version} recorded at ${fmt(when)} (Eastern). Remember: paste the BBCode block into the Workshop change note if you have not.`);
}

function cmdStatus() {
  const L = readLedger();
  const tail = L.uploads.slice(-4);
  for (const u of tail) info(`#${u.n} ${u.status.padEnd(8)} ${u.version.padEnd(18)} uploaded ${u.uploaded || '-'}  ff ${u.ff_time || '-'}  notes "${u.notes_section}"`);
  const p = pendingRow(L);
  const last = lastUploaded(L);
  const entries = changelogEntries();
  const idx = entries.findIndex(e => e.header === last.changelog_cutoff);
  info(p ? `PENDING: #${p.n} ${p.version}` : 'no pending publish');
  info(`${idx < 0 ? '?' : idx} CHANGELOG entries newer than the last upload (#${last.n} ${last.version})`);
}

const cmd = process.argv[2];
({ window: cmdWindow, stage: cmdStage, check: cmdCheck, built: cmdBuilt, uploaded: cmdUploaded, status: cmdStatus }[cmd] ||
  (() => { console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(1, 30).join('\n')); process.exit(2); }))();
