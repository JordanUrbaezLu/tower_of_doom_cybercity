#!/usr/bin/env node
// =============================================================================
// lint_tod_assets_selftest.js — break the map, require a catch.
//
// A lint nobody has watched FAIL is not a gate (CLAUDE.md: "a guard nobody has
// watched fire is not a guard"; memory `check-passes-wrong-question`). This
// copies the four sources lint_tod_assets.js reads into a scratch tree, injures
// one thing per case, and requires the lint to catch exactly that — plus a
// clean control that must stay green, and two SHAPE cases that must NOT fire
// (the false positives the lint shipped with for ten minutes on 2026-09-03:
// a concatenation prefix, and a one-image card).
//
//   node tools/lint_tod_assets_selftest.js
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawnSync } = require('child_process');

const REPO = path.resolve(__dirname, '..');
const LINT = path.join(__dirname, 'lint_tod_assets.js');
const SRC = {
  zone: 'zone_source/zm_tower_of_doom.zone',
  upgrades: 'scripts/zm/zm_tower_of_doom/_tod_upgrades.gsc',
  ui: 'scripts/zm/zm_tower_of_doom/_tod_upgrade_ui.gsc',
  lua: 'ui/uieditor/menus/hud/tod_upgrade.lua',
  menu: 'ui/uieditor/menus/StartMenu/AetheriumStartMenu.lua',
  scoreboard: 'ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumScoreboard.lua',
};

// The whole ui/ tree is copied, not just the two Lua files the cases mutate:
// the lint's "unnamed" count is over EVERY Lua literal, so a partial copy makes
// images look unreferenced and every case regresses on that bucket alone.
function copyDir(src, dst) {
  fs.mkdirSync(dst, { recursive: true });
  for (const e of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, e.name), d = path.join(dst, e.name);
    if (e.isDirectory()) copyDir(s, d); else fs.copyFileSync(s, d);
  }
}
function freshTree() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'tod_assets_selftest_'));
  for (const rel of [SRC.zone, SRC.upgrades, SRC.ui]) {
    const dst = path.join(root, rel);
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    fs.copyFileSync(path.join(REPO, rel), dst);
  }
  copyDir(path.join(REPO, 'ui'), path.join(root, 'ui'));
  // 2026-09-09: the working-copy zone is CRLF (git normalises it to LF on
  // commit, so `git show HEAD:` hides that). Every zone mutation below deletes
  // "<line>\n", which never matched a CRLF line -- five "expected a catch"
  // failures that were the SELFTEST's, not the lint's. Normalise the scratch
  // copy; the lint's own ^image,(\S+) parse is line-ending agnostic.
  const zp = path.join(root, SRC.zone);
  fs.writeFileSync(zp, fs.readFileSync(zp, 'utf8').replace(/\r\n/g, '\n'));
  return root;
}
const rd = (root, key) => fs.readFileSync(path.join(root, SRC[key]), 'utf8');
const wr = (root, key, txt) => fs.writeFileSync(path.join(root, SRC[key]), txt);

// The lint gates GATE B on a baseline; the scratch tree has the same counts as
// the repo, so a case that ADDS a dead thing regresses and must fail.
function runLint(root) {
  const r = spawnSync(process.execPath, [LINT, '--root', root], { encoding: 'utf8' });
  return { code: r.status, out: (r.stdout || '') + (r.stderr || '') };
}

const cases = [];
const add = (name, mustCatch, mutate, expect) => cases.push({ name, mustCatch, mutate, expect });

// ---- control ----------------------------------------------------------------
add('CONTROL: untouched tree', false, () => {}, null);

// 2026-09-10: every shipped dark card has art now (DARK_TEXT_ONLY is empty), so
// these two cases first RE-CREATE a text-only card in the scratch tree — CHAIN
// LIGHTNING declared text-only and its dark zone line removed, which is a
// legal, clean state — and only then break the guard they exist to prove.
const makeTextOnly = root => {
  const lua = rd(root, 'lua');
  if (!/local DARK_TEXT_ONLY = \{\s*\}/.test(lua)) throw new Error('selftest: expected an EMPTY DARK_TEXT_ONLY to re-populate');
  wr(root, 'lua', lua.replace(/local DARK_TEXT_ONLY = \{\s*\}/, 'local DARK_TEXT_ONLY = { [53] = true }'));   // 53 = mage_bolt (CHAIN LIGHTNING)
  wr(root, 'zone', rd(root, 'zone').replace('image,i_tod_card_mage_bolt_dark\n', ''));
};
add('CONTROL: a text-only Dark card with its zone line gone is clean', false, root => { makeTextOnly(root); }, null);

add('a text-only Dark card loses its registration guard', true, root => {
  makeTextOnly(root);
  wr(root, 'lua', rd(root, 'lua').replace(' and not DARK_TEXT_ONLY[ id ]', ''));
}, /i_tod_card_mage_bolt_dark/);

add('a text-only Dark card falls back to incorrect Ultimate art', true, root => {
  makeTextOnly(root);
  wr(root, 'lua', rd(root, 'lua').replace('if isDark and not darkImg then', 'if false then'));
}, /i_tod_card_mage_bolt_dark/);

// ---- GATE D: the two owned-upgrades screens disagree on the plate ceiling ---
// 2026-09-10: the scoreboard's TOD_UPG_PLATE_MAX sat at 47 against the pause
// menu's 56 for as long as the Mage rows existed, and nothing noticed until the
// user did. Both directions must fire — a LOWER scoreboard number is the drift
// that actually shipped.
add('the scoreboard plate ceiling falls behind the pause menu', true, root => {
  wr(root, 'scoreboard', rd(root, 'scoreboard').replace(/TOD_UPG_PLATE_MAX\s*=\s*\d+/, 'TOD_UPG_PLATE_MAX  = 47'));
}, /GATE D/);

add('the pause menu plate ceiling falls behind the scoreboard', true, root => {
  wr(root, 'menu', rd(root, 'menu').replace(/PAUSE_PLATE_MAX\s*=\s*\d+/, 'PAUSE_PLATE_MAX = 47'));
}, /GATE D/);

// ---- GATE A: missing art ----------------------------------------------------
add('a zoned card image is deleted while its slug stays (WHITE SQUARE)', true, root => {
  const slug = [...rd(root, 'lua').matchAll(/\[(\d+)\]\s*=\s*"([a-z_0-9]+)"/g)]
    .map(m => m[2]).find(s => rd(root, 'zone').includes(`image,i_tod_card_${s}_regular`));
  wr(root, 'zone', rd(root, 'zone').replace(`image,i_tod_card_${slug}_regular\n`, ''));
}, /GATE A/);

add('a Lua literal names an image with no zone line', true, root => {
  wr(root, 'lua', rd(root, 'lua').replace(
    /(local CARD_SLUG\s*=\s*\{)/,
    'local NOPE = RegisterImage( "i_tod_totally_invented_image" )\n        $1'));
}, /i_tod_totally_invented_image/);

add('a LIVE domain loses its pause plate', true, root => {
  wr(root, 'zone', rd(root, 'zone').replace(/image,i_tod_pause_r01\n/, ''));
}, /GATE A/);

// The 8 TIER cards are built from TCLS, so NO literal names them. Before
// 2026-09-03 they were invisible to this lint entirely — not even in the
// advisory bucket — so deleting one was a white square nothing caught.
add('a TIER card loses its zone line (no literal names it)', true, root => {
  wr(root, 'zone', rd(root, 'zone').replace(/image,i_tod_card_tier_heavy_3\n/, ''));
}, /i_tod_card_tier_heavy_3/);

// THE GUN-HUD GLYPH SET, same blind spot one size larger (v17.9, docs/91).
// AetheriumLoadout.lua builds these names by concatenation — "i_tod_hud_d" .. c —
// so no Lua literal names them and a literal scan leaves them uncovered. The
// coverage reads tools/tod_hud_glyphs.generated.json, and the only honest way to
// know that coverage works is to DELETE one and require the lint to notice
// (memory: constructed-names-evade-inventory). Two shapes, because the set has
// two different constructions behind it: a typeface cell and a category cell.
add('a DIGIT glyph loses its zone line (built by concatenation)', true, root => {
  wr(root, 'zone', rd(root, 'zone').replace(/image,i_tod_hud_d7\n/, ''));
}, /i_tod_hud_d7/);

add('a GUN silhouette loses its zone line (built by concatenation)', true, root => {
  wr(root, 'zone', rd(root, 'zone').replace(/image,i_tod_hud_gun_minigun\n/, ''));
}, /i_tod_hud_gun_minigun/);

// ---- GATE B: dead weight (the v16.86 bug class) ------------------------------
add('a domain is retired but its CARD_SLUG slug stays (the v16.86 bug)', true, root => {
  // retire "leech" (id 13) by commenting out its add_domain, leaving the slug
  wr(root, 'upgrades', rd(root, 'upgrades').replace(/^(\s*)(add_domain\(\s*"leech")/m, '$1// Was: $2'));
}, /deadSlugs 0 -> 1|GATE B REGRESSION/);

add('a card is zoned that no slug declares', true, root => {
  wr(root, 'zone', rd(root, 'zone').replace(/^image,i_tod_card_damage_regular$/m,
    'image,i_tod_card_damage_regular\nimage,i_tod_card_ghostdomain_regular'));
}, /deadCards 0 -> 1|GATE B REGRESSION/);

// ---- GATE C: pause/scoreboard row capacity + the one-owner dark rule --------
// The bug this gate exists for (2026-09-04): the pause panel drew 2 x 7 = 14
// rows while every class could hold 15 or 16, so RIOT SHIELD was invisible on
// all four and the only complaint on screen was a "+N MORE" nobody reads. Both
// halves of the comparison are parsed, so the way to prove the gate works is to
// move either half — here the panel's own ROWS_MAX, back to what shipped.
const MENU = 'ui/uieditor/menus/StartMenu/AetheriumStartMenu.lua';
const SCORE = 'ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumScoreboard.lua';
const rdf = (root, rel) => fs.readFileSync(path.join(root, rel), 'utf8');
const wrf = (root, rel, t) => fs.writeFileSync(path.join(root, rel), t);

add('the pause panel loses a row of capacity (the v17.10 riot-shield bug)', true, root => {
  wrf(root, MENU, rdf(root, MENU).replace(/ROWS_MAX = 9/, 'ROWS_MAX = 7'));
}, /GATE C/);

add('the SCOREBOARD loses a column of capacity', true, root => {
  wrf(root, SCORE, rdf(root, SCORE).replace(/TOD_UPG_COLS\s*=\s*3/, 'TOD_UPG_COLS       = 2'));
}, /GATE C.*|SCOREBOARD/);

// A NEW DOMAIN IS THE OTHER HALF OF THE SAME COMPARISON, and the more likely
// one: nobody edits ROWS_MAX by accident, but add_domain gets called every few
// days. This is the case that will actually fire in anger one day.
add('a new universal domain pushes a class past the panel capacity', true, root => {
  let u = rd(root, 'upgrades');
  // Two extra universal domains take the 16-row classes to 18, one past the 18
  // the compact preset draws... so add three, and keep them off the art lanes
  // by reusing ids the lint already knows are dead (no CARD_SLUG is added).
  const extra = ['zz_one', 'zz_two', 'zz_three'].map(k =>
    `\tadd_domain( "${k}", "TEST ${k}", "test", 5, undefined, TOD_TIER_A );`).join('\n');
  u = u.replace(/^(\s*add_domain\(\s*"luck".*)$/m, `$1\n${extra}`);
  wr(root, 'upgrades', u);
}, /GATE C/);

add('a second Lua file builds an i_tod_pause_rNN_dark name itself', true, root => {
  wrf(root, SCORE, rdf(root, SCORE).replace(
    /(local TOD_UPG_COLS)/,
    'local BAD = string.format( "i_tod_pause_r%02d_dark", 1 )\n$1'));
}, /TodDarkPlate|GATE C/);

// ---- SHAPE: things that must NOT fire ---------------------------------------
add('SHAPE: a concatenation prefix is not an image name', false, root => {
  wr(root, 'lua', rd(root, 'lua').replace(
    /(local CARD_SLUG\s*=\s*\{)/,
    'local PFX = RegisterImage( "i_tod_made_up_prefix_" .. 7 )\n        $1'));
}, null);

add('SHAPE: a one-image card needs only its one rarity', false, root => {
  // add a one-image domain whose _regular/_super deliberately do not exist
  let lua = rd(root, 'lua');
  lua = lua.replace(/(local CARD_ONE_IMAGE\s*=\s*\{)/, '$1\n            [13] = "ultimate",');
  wr(root, 'lua', lua);
  let zone = rd(root, 'zone');
  zone = zone.replace(/^image,i_tod_card_leech_regular$/m, '')
             .replace(/^image,i_tod_card_leech_super$/m, '');
  wr(root, 'zone', zone);
}, null);

// ---- run --------------------------------------------------------------------
let pass = 0, fail = 0;
for (const c of cases) {
  const root = freshTree();
  c.mutate(root);
  const { code, out } = runLint(root);
  const caught = code !== 0;
  let ok = caught === c.mustCatch;
  if (ok && c.mustCatch && c.expect) ok = c.expect.test(out);
  if (ok) { pass++; console.log('  ok   ' + c.name); }
  else {
    fail++;
    console.log('  FAIL ' + c.name + `  (expected ${c.mustCatch ? 'a catch' : 'clean'}, exit ${code})`);
    console.log(out.split('\n').filter(l => l.trim()).slice(-6).map(l => '         ' + l).join('\n'));
  }
  fs.rmSync(root, { recursive: true, force: true });
}
console.log(`\nlint_tod_assets_selftest: ${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
