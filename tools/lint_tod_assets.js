#!/usr/bin/env node
// =============================================================================
// lint_tod_assets.js — the two gates on UI ART: nothing missing, nothing dead.
//
// WHY THIS EXISTS (2026-09-03, docs/86 §9). Zoned art has two failure modes on
// this map and NEITHER is visible at build time. Both have shipped:
//
//   1. MISSING — the Lua asks for an image with no `image,` line. The linker
//      says nothing (Lua is an opaque rawfile to it) and the game draws a
//      WHITE SQUARE. Live 2026-08-23 (the Mule Kick shader; memory
//      `usermap-asset-traps`). Retiring a domain by deleting only its zone
//      lines, while its slug stays in CARD_SLUG, is exactly this bug.
//
//   2. DEAD — the zone line stays after the thing that drew it is gone. The
//      image is packed into the .ff and decompressed at load. Cards are
//      `uncompressed` 768x1152, so ONE dead card is 3.4 MB of load-time RAM.
//      Live until v16.86: FOUR retired domains (11 echo_rounds, 12 regen,
//      30 meat_grinder, 34 momentum) still shipped 12 cards no deal could
//      ever roll — 40.5 MB of RAM. v16.80 had already established the fix
//      (retire the slug AND the zone lines together) for a fifth domain;
//      nothing enforced it, so four were simply forgotten.
//
// THE RULE THIS ENFORCES: **a card slug and its zone lines are ONE unit.**
// Retire both or neither. Same for a domain and its pause plate.
//
// WHAT IT PROVES. Sources are PARSED, never copied here — the id map comes out
// of `_tod_upgrade_ui.gsc::domain_id`, the live domain set out of the
// `add_domain(` calls in `_tod_upgrades.gsc` (commented `// Was:` lines do NOT
// count), the slugs out of the Lua's own CARD_SLUG, the plate ceiling out of
// PAUSE_PLATE_MAX. Rename any of them and this lint follows.
//
//   GATE A — MISSING (HARD FAIL, always): an image a live path can name but
//   the zone does not carry. Three sources: literal "i_tod_*" strings in
//   ui/**/*.lua; every CARD_SLUG slug x {regular,super,ultimate}; every LIVE
//   domain id <= PAUSE_PLATE_MAX as i_tod_pause_rNN.
//
//   GATE B — DEAD (gated on REGRESSION against the baseline, like
//   lint_tod_geometry.js): a CARD_SLUG entry whose id has no live domain; a
//   zoned card whose slug nothing declares; a zoned pause plate for a dead id;
//   and zoned i_tod_* art no Lua literal names. The last bucket is ADVISORY —
//   art can be reached by a constructed name this lint does not model — so it
//   is counted, not itemised into a failure. Never edit the baseline to make
//   this green: fix the art, or record WHY in the entry you add.
//
// OUT OF SCOPE (documented so nobody reads more into a pass than is there):
// materials (`material,` lines and their colorMap images — a different lane,
// GSC SetShader names the MATERIAL), images referenced only from GSC, and
// anything a Lua builds from a table this file does not parse. A pass means
// the modelled lanes are consistent, not that every image is reachable.
//
//   node tools/lint_tod_assets.js            gate (build runs this)
//   node tools/lint_tod_assets.js --report   list every finding, exit 0
//   node tools/lint_tod_assets.js --update-baseline
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const REPO = path.resolve(__dirname, '..');
const ZONE = path.join(REPO, 'zone_source', 'zm_tower_of_doom.zone');
const UPGRADES = path.join(REPO, 'scripts', 'zm', 'zm_tower_of_doom', '_tod_upgrades.gsc');
const UPGRADE_UI = path.join(REPO, 'scripts', 'zm', 'zm_tower_of_doom', '_tod_upgrade_ui.gsc');
const LUA_DIR = path.join(REPO, 'ui');
const BASELINE = path.join(__dirname, 'lint_tod_assets.baseline.json');

const argv = process.argv.slice(2);
const REPORT = argv.includes('--report');
const UPDATE = argv.includes('--update-baseline');
// --root lets the selftest point every path at a scratch copy of the tree.
const rootIdx = argv.indexOf('--root');
const ROOT = rootIdx >= 0 ? argv[rootIdx + 1] : REPO;
const P = rel => path.join(ROOT, rel);

// ---- source readers ---------------------------------------------------------
const read = f => { try { return fs.readFileSync(f, 'utf8'); } catch (e) { return ''; } };

// Lua comments would otherwise make every retired name look live: a retirement
// note ("-- the three i_tod_card_mobility_* lines are gone") names the very
// images it says are gone. Strip block comments then line comments.
function stripLua(txt) {
  return txt.replace(/--\[\[[\s\S]*?\]\]/g, '').replace(/--[^\n]*/g, '');
}
// GSC/C-style for the .gsc sources.
function stripGsc(txt) {
  return txt.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '');
}
function luaFiles(dir, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) luaFiles(p, out);
    else if (e.name.toLowerCase().endsWith('.lua')) out.push(p);
  }
  return out;
}

// ---- parse ------------------------------------------------------------------
const zoneTxt = read(P('zone_source/zm_tower_of_doom.zone'));
const zoned = new Set([...zoneTxt.matchAll(/^image,(\S+)/gm)].map(m => m[1]));

// live domains: add_domain( "key", ... ) with the call NOT commented out
const upgradesTxt = stripGsc(read(P('scripts/zm/zm_tower_of_doom/_tod_upgrades.gsc')));
const liveKeys = new Set([...upgradesTxt.matchAll(/\badd_domain\s*\(\s*"([a-z_0-9]+)"/g)].map(m => m[1]));

// id map: domain_id()'s switch cases
const uiTxt = stripGsc(read(P('scripts/zm/zm_tower_of_doom/_tod_upgrade_ui.gsc')));
const idBlock = (uiTxt.match(/function\s+domain_id[\s\S]*?\n\}/) || [''])[0];
const keyToId = new Map();
for (const m of idBlock.matchAll(/case\s+"([a-z_0-9]+)"\s*:\s*return\s+(\d+)/g)) keyToId.set(m[1], +m[2]);
const idToKey = new Map([...keyToId].map(([k, v]) => [v, k]));
const liveIds = new Set([...liveKeys].map(k => keyToId.get(k)).filter(v => v !== undefined));
// 24 = the TIER card: dealt by tier_card_roll, never registered via add_domain.
const TIER_ID = keyToId.get('tier');
if (TIER_ID !== undefined) liveIds.add(TIER_ID);

// Lua sources
const luaPaths = luaFiles(P('ui'));
const luaClean = new Map();      // path -> comment-stripped text
for (const f of luaPaths) luaClean.set(f, stripLua(read(f)));

// CARD_SLUG: [id] = "slug"
const cardLuaPath = luaPaths.find(f => f.toLowerCase().endsWith(path.join('hud', 'tod_upgrade.lua').toLowerCase()))
  || luaPaths.find(f => /tod_upgrade\.lua$/i.test(f));
const cardLua = cardLuaPath ? luaClean.get(cardLuaPath) : '';
const slugBlock = (cardLua.match(/CARD_SLUG\s*=\s*\{[\s\S]*?\n\s*\}/) || [''])[0];
const cardSlug = new Map();
for (const m of slugBlock.matchAll(/\[(\d+)\]\s*=\s*"([a-z_0-9]+)"/g)) cardSlug.set(+m[1], m[2]);

// PAUSE_PLATE_MAX (declared in the start menu Lua)
let plateMax = 0;
for (const [, t] of luaClean) {
  const m = t.match(/PAUSE_PLATE_MAX\s*=\s*(\d+)/);
  if (m) plateMax = Math.max(plateMax, +m[1]);
}
// ...AND THE SCOREBOARD'S COPY (2026-09-10). AetheriumScoreboard.lua draws the
// same rows off its own TOD_UPG_PLATE_MAX, commented "LOCKSTEP" since v15 and
// never checked: it sat at 47 while the pause menu went to 56, so the eight
// Mage rows and MYSTICAL HANDS were text labels on the scoreboard with no red
// dark plate, for as long as those rows have existed. A lockstep pair nothing
// checks is a pair that drifts. GATE D below fails the build on a mismatch.
let sbPlateMax = null;
for (const [f, t] of luaClean) {
  if (!/AetheriumScoreboard\.lua$/i.test(f)) continue;
  const m = t.match(/TOD_UPG_PLATE_MAX\s*=\s*(\d+)/);
  if (m) sbPlateMax = +m[1];
}

// Every literal i_tod_* the Lua names — but a literal followed by `..` is a
// PREFIX for a constructed name ("i_tod_badge_luck_" .. i * 10), not an image,
// and demanding a zone line for it would fail on art that is perfectly fine.
// Those constructed families are covered by the card/plate lanes below and by
// the advisory bucket, never by GATE A.
const luaLiterals = new Map();   // image -> [files]
const luaPrefixes = new Set();
for (const [f, t] of luaClean) {
  for (const m of t.matchAll(/["'](i_tod_[a-z0-9_]+)["'](\s*\.\.)?/g)) {
    // `..` right after it, or a trailing underscore (no image is named that
    // way; `cellImg( "i_tod_gauge_", "c", f )` concatenates inside the callee).
    if (m[2] || m[1].endsWith('_')) { luaPrefixes.add(m[1]); continue; }
    if (!luaLiterals.has(m[1])) luaLiterals.set(m[1], []);
    const arr = luaLiterals.get(m[1]);
    const rel = path.relative(ROOT, f).replace(/\\/g, '/');
    if (!arr.includes(rel)) arr.push(rel);
  }
}

// ONE-IMAGE DOMAINS: a domain locked to a single rarity ships ONE card file and
// the Lua fills all three slots with it (CARD_ONE_IMAGE, v16.67 DEADSHOT).
// Demanding _regular/_super for those would be a false failure.
const oneImage = new Map();      // id -> rarity
const oneBlock = (cardLua.match(/CARD_ONE_IMAGE\s*=\s*\{[\s\S]*?\n\s*\}/) || [''])[0];
for (const m of oneBlock.matchAll(/\[(\d+)\]\s*=\s*"([a-z]+)"/g)) oneImage.set(+m[1], m[2]);

// THE 8 TIER CARDS are built from a table, so no literal names them:
//   art.tier[c][t] = RegisterImage( "i_tod_card_tier_" .. TCLS[c] .. "_" .. t )
// They are LIVE — a player sees one on every tier promotion. Without this the
// lint would leave them in the advisory bucket, uncovered: a deleted zone line
// would be a white square nothing caught (raised by a peer session 2026-09-03
// before the baseline set, and it was right). Parsed, not hardcoded, and only
// required when the flag that registers them is on.
const tierCards = [];
{
  const on = /USE_TIER_CARD_ART\s*=\s*true/.test(cardLua);
  const tblM = cardLua.match(/TCLS\s*=\s*\{([^}]*)\}/);
  const loopM = cardLua.match(/for\s+t\s*=\s*(\d+)\s*,\s*(\d+)\s*do[\s\S]{0,200}?i_tod_card_tier_/);
  if (on && tblM && loopM) {
    const classes = [...tblM[1].matchAll(/"([a-z_0-9]+)"/g)].map(m => m[1]);
    for (const c of classes)
      for (let t = +loopM[1]; t <= +loopM[2]; t++) tierCards.push(`i_tod_card_tier_${c}_${t}`);
  }
}

// THE GUN-HUD GLYPH SET (v17.9, docs/91) — the same blind spot as the tier
// cards, one size larger. AetheriumLoadout.lua builds every one of these names
// by concatenation: "i_tod_hud_d" .. c for a numeral, "i_tod_hud_l" .. lower(c)
// for a letter, "i_tod_hud_gun_" .. category for the weapon silhouette. A
// Lua-LITERAL scan cannot see any of them, so without this they sit in the
// advisory bucket and a deleted zone line is a WHITE SQUARE in the middle of the
// ammo counter that nothing catches.
//
// The list is READ FROM GENERATED DATA, not hardcoded here: tools/
// slice_hud_sheets.js writes tod_hud_glyphs.generated.json from the same SHEETS
// table it cuts the cells with, so adding a cell covers itself and a skipped
// cell (the ampersand) is absent from both at once.
//
// Read from __dirname, NOT from ROOT. The manifest is a toolchain artifact that
// lives beside this lint, not map content — and --root points the selftest at a
// scratch COPY of the map tree that has no tools/ directory at all. Resolving it
// against ROOT made three selftest shapes fail with a phantom unnamed 209 -> 257
// regression, which is the lint reporting on its own missing file rather than on
// anything the shape changed.
const hudGlyphs = [];
{
  const p = path.join(__dirname, 'tod_hud_glyphs.generated.json');
  if (fs.existsSync(p)) {
    try { hudGlyphs.push(...(JSON.parse(fs.readFileSync(p, 'utf8')).images || [])); } catch (e) {}
  }
}

const RARITIES = ['regular', 'super', 'ultimate'];
// DARK UPGRADES (v17.10): a FOURTH rarity, but only for the domains that can be
// dealt one. set_no_dark( "key" ) in _tod_upgrades.gsc is the exception list and
// is parsed here rather than copied, exactly like add_domain above -- a hand-kept
// mirror of it is the thing that goes stale and then passes while lying.
const noDarkKeys = new Set([...upgradesTxt.matchAll(/^\s*set_no_dark\s*\(\s*"([a-z_0-9]+)"/gm)].map(m => m[1]));
const noDarkIds = new Set([...noDarkKeys].map(k => keyToId.get(k)).filter(v => v !== undefined));
// Enabled text-only Dark cards neither register an image nor reuse Ultimate
// art. Honor this exception only while both routing guards are present.
const darkTextBlock = (cardLua.match(/DARK_TEXT_ONLY\s*=\s*\{([^}]*)\}/) || [,''])[1];
const darkTextIds = new Set([...darkTextBlock.matchAll(/\[\s*(\d+)\s*\]\s*=\s*true/g)].map(m => +m[1]));
const darkTextSafe = /not DARK_NONE\[ id \] and not DARK_TEXT_ONLY\[ id \]/.test(cardLua)
  && /if isDark and not darkImg then\s+set = nil/.test(cardLua);
// DARK_PLATE_NONE — ids whose red pause plate was deliberately not baked; they
// use the runtime tint instead. Parsed out of the Lua so the two can never
// disagree, exactly like set_no_dark above.
// MOVED 2026-09-04 from AetheriumStartMenu.lua to tod_upgrade.lua, with the
// rule itself (CoD.TodDarkPlate), when the SCOREBOARD turned out to draw the
// same list and know none of it. Searched across the Lua rather than read from
// one hardcoded path, so the next move does not silently empty this set — an
// EMPTY DARK_PLATE_NONE makes GATE A demand four plates that were never
// ordered, which is loud; but the same parse against a file that still had a
// stale copy would have been silent and wrong.
const darkPlateNone = new Set();
{
  let found = false;
  for (const [, t] of luaClean) {
    const m = t.match(/DARK_PLATE_NONE\s*=\s*\{([^}]*)\}/);
    if (!m) continue;
    found = true;
    for (const k of m[1].matchAll(/\[\s*(\d+)\s*\]/g)) darkPlateNone.add(Number(k[1]));
  }
  if (!found) console.error('lint_tod_assets: WARN — no DARK_PLATE_NONE table found in ui/; GATE A will demand every red plate.');
}
const pad2 = n => String(n).padStart(2, '0');

// ---- GATE A: missing (hard fail) --------------------------------------------
const missing = [];
for (const [img, files] of luaLiterals)
  if (!zoned.has(img)) missing.push(`${img} — named in ${files.join(', ')} but NO zone line (draws a WHITE SQUARE)`);
for (const [id, slug] of cardSlug) {
  const rars = oneImage.has(id) ? [oneImage.get(id)] : RARITIES;
  for (const r of rars) {
    const img = `i_tod_card_${slug}_${r}`;
    if (!zoned.has(img)) missing.push(`${img} — CARD_SLUG[${id}] = "${slug}"${oneImage.has(id) ? ' (one-image, ' + oneImage.get(id) + ')' : ''} but NO zone line (white square when that card is dealt)`);
  }
}
for (const [id, slug] of cardSlug) {
  if (!liveIds.has(id) || noDarkIds.has(id) || (darkTextSafe && darkTextIds.has(id))) continue;
  const img = `i_tod_card_${slug}_dark`;
  if (!zoned.has(img)) missing.push(`${img} — domain "${idToKey.get(id)}" (id ${id}) is live and has no set_no_dark(), so a DARK card can be dealt for it, but there is NO zone line (white square on that dark deal)`);
}
for (const img of tierCards)
  if (!zoned.has(img)) missing.push(`${img} — built by tod_upgrade.lua's TCLS loop under USE_TIER_CARD_ART, but NO zone line (white square on that tier promotion)`);
for (const img of hudGlyphs)
  if (!zoned.has(img)) missing.push(`${img} — gun-HUD art (tools/tod_hud_glyphs.generated.json), named by concatenation in AetheriumLoadout.lua, but NO zone line (white square in the bottom-right readout)`);
for (const id of [...liveIds].sort((a, b) => a - b)) {
  if (!plateMax || id > plateMax) continue;
  const img = `i_tod_pause_r${pad2(id)}`;
  if (!zoned.has(img)) missing.push(`${img} — domain "${idToKey.get(id)}" (id ${id}) is LIVE and <= PAUSE_PLATE_MAX ${plateMax}, but NO zone line`);
  // DARK UPGRADES (v17.10): a dark-capable domain also owes its RED plate. The
  // name is built by concatenation in AetheriumStartMenu.lua under
  // USE_DARK_PLATE_ART, so no Lua literal exists for the literal lane to find.
  // DARK_PLATE_NONE in AetheriumStartMenu.lua lists the ids that deliberately
  // fall back to the runtime tint because no red plate was baked for them.
  // PARSED, not copied — same rule as every other fact in this file.
  if (noDarkIds.has(id) || id === TIER_ID || darkPlateNone.has(id)) continue;
  const dimg = `i_tod_pause_r${pad2(id)}_dark`;
  if (!zoned.has(dimg)) missing.push(`${dimg} — domain "${idToKey.get(id)}" (id ${id}) can hold a DARK upgrade, so the pause menu asks for its red plate, but there is NO zone line (white square in the pause list)`);
}

// ---- GATE C: pause-menu row capacity (HARD FAIL, always) --------------------
//
// The pause menu's YOUR UPGRADES panel draws a fixed number of rows and
// SILENTLY DROPS the rest behind a "+N MORE" line. Rows render in ascending
// domain id, so overflow always eats the NEWEST domains — which is how RIOT
// SHIELD (id 45) was invisible for every class from 2026-09-02 to 2026-09-04,
// and FULL STEAM for the heavy on top of it. Nobody reads "+2 MORE".
//
// A ROW BUDGET IS NOT A COMMENT. It moves every time add_domain is called, and
// the comment that claimed "the true ceiling is 14 rows" had been stale for two
// days before a player noticed. Both halves are PARSED here: the reachable set
// per class off add_domain's own class_keys argument, and the panel's capacity
// off its ROWS_MAX declarations (the base preset and the compact one; the
// larger wins, since the panel picks it for exactly this case).
const CLASSES = ['skirmisher', 'assault', 'heavy', 'slasher', 'mage'];   // 2026-09-10: the MAGE was missing from the capacity check for as long as it has existed
const perClass = new Map(CLASSES.map(c => [c, []]));
// add_domain( key, display, desc, max, class_keys, ... ) — the 5th argument is
// either `undefined` (universal) or `array( "cls", ... )`.
for (const m of upgradesTxt.matchAll(
  /\badd_domain\s*\(\s*"([a-z_0-9]+)"\s*,\s*"([^"]*)"\s*,\s*"(?:[^"\\]|\\.)*"\s*,\s*\d+\s*,\s*(undefined|array\s*\([^)]*\))/g)) {
  const [, key, display, scope] = m;
  for (const c of CLASSES)
    if (scope === 'undefined' || scope.includes('"' + c + '"'))
      perClass.get(c).push({ id: keyToId.get(key), key, display });
}
// BOTH SCREENS, not just the pause menu. The scoreboard (AetheriumScoreboard)
// draws the same CoD.TodOwned on its own grid and DROPS ID 24, so its budget is
// one lower and its capacity is a different pair of numbers. Checking only the
// one that broke first is how the second one gets found by a player.
let rowsMax = 0;
for (const [, t] of luaClean)
  for (const m of t.matchAll(/ROWS_MAX\s*=\s*(\d+)/g)) rowsMax = Math.max(rowsMax, +m[1]);
const sbTxt = [...luaClean].find(([f]) => /AetheriumScoreboard\.lua$/i.test(f));
const sbNum = (re) => { const m = sbTxt && sbTxt[1].match(re); return m ? +m[1] : 0; };
const sbCap = sbNum(/TOD_UPG_ROWS_COL\s*=\s*(\d+)/) * sbNum(/TOD_UPG_COLS\s*=\s*(\d+)/);
const PANELS = [
  { name: 'pause menu', cap: rowsMax * 2, tier: true,
    how: `2 columns x ROWS_MAX ${rowsMax}`, where: 'ui/uieditor/menus/StartMenu/AetheriumStartMenu.lua' },
  { name: 'scoreboard', cap: sbCap, tier: false,
    how: 'TOD_UPG_COLS x TOD_UPG_ROWS_COL', where: 'ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumScoreboard.lua' },
];
const overCap = [];
const classRowCounts = [];
for (const panel of PANELS) {
  if (!panel.cap) continue;
  for (const c of CLASSES) {
    // +1 for the CLASS TIER row (id 24), which refresh_upgrade_list sends for
    // every drafted player and which add_domain therefore never declares. The
    // scoreboard skips that row, so it is added only where it is drawn.
    const rows = (panel.tier
      ? perClass.get(c).concat([{ id: TIER_ID, key: 'tier', display: 'CLASS TIER' }])
      : perClass.get(c).slice())
      .sort((a, b) => (a.id || 0) - (b.id || 0));
    if (panel.tier) classRowCounts.push(`${c} ${rows.length}`);
    if (rows.length > panel.cap)
      overCap.push(`${panel.name.toUpperCase()} / ${c.toUpperCase()}: ${rows.length} rows but the panel draws ${panel.cap} ` +
        `(${panel.how}) — DROPPED: ` +
        rows.slice(panel.cap).map(r => `${r.id}:${r.display}`).join(', ') + ` [${panel.where}]`);
  }
}

// ONE OWNER FOR THE DARK PLATE RULE. The name i_tod_pause_rNN_dark may only be
// built inside CoD.TodDarkPlate (tod_upgrade.lua). The scoreboard printed dark
// VALUES under an ordinary blue plate for a whole version because the pause
// menu's copy of the rule was a local — a rule written down twice is a rule one
// screen will be a version behind on, and nothing failed to say so.
for (const [f, t] of luaClean) {
  if (/tod_upgrade\.lua$/i.test(f)) continue;
  if (/_dark"/.test(t) || /_dark'/.test(t))
    overCap.push(`${path.relative(P('.'), f)} builds an i_tod_pause_rNN_dark name itself — ` +
      `call CoD.TodDarkPlate( id, plateMax ) instead; it owns the art flag AND the not-yet-baked list`);
}

// ---- GATE B: dead (baseline-gated) ------------------------------------------
const deadSlugs = [];
for (const [id, slug] of cardSlug)
  if (!liveIds.has(id))
    deadSlugs.push(`CARD_SLUG[${id}] = "${slug}" — no live add_domain for id ${id} (key "${idToKey.get(id) || '?'}"), so no deal can roll it; its 3 cards are dead weight in the .ff`);

// zoned cards whose slug nothing declares. tier_/class_ are built from their own
// tables (art.tier, tod_class_select) and are covered by the literal lane.
const declaredSlugs = new Set(cardSlug.values());
const deadCards = [];
for (const img of zoned) {
  const m = img.match(/^i_tod_card_(.+)_(regular|super|ultimate|dark)$/);
  if (!m) continue;
  const slug = m[1];
  if (declaredSlugs.has(slug)) continue;
  if (/^(tier|class)(_|$)/.test(slug)) continue;
  if (luaLiterals.has(img)) continue;
  deadCards.push(`${img} — no CARD_SLUG entry declares slug "${slug}"`);
}
const deadPlates = [];
for (const img of zoned) {
  const m = img.match(/^i_tod_pause_r(\d+)$/);
  if (!m) continue;
  const id = +m[1];
  if (liveIds.has(id) || luaLiterals.has(img)) continue;
  deadPlates.push(`${img} — no live domain has id ${id} (key "${idToKey.get(id) || 'unmapped'}")`);
}
// advisory bucket: zoned art no Lua literal names and no family above explains
const unnamed = [];
const tierSet = new Set(tierCards);
const hudSet = new Set(hudGlyphs);
for (const img of zoned) {
  if (luaLiterals.has(img)) continue;
  if (tierSet.has(img)) continue;          // covered by GATE A above, not advisory
  if (hudSet.has(img)) continue;           // ditto — the gun-HUD glyph set
  if (/^i_tod_card_/.test(img) || /^i_tod_pause_r\d+(_dark)?$/.test(img)) continue;
  unnamed.push(img);
}

// ---- report / gate ----------------------------------------------------------
const counts = { deadSlugs: deadSlugs.length, deadCards: deadCards.length, deadPlates: deadPlates.length, unnamed: unnamed.length };
let baseFile = {};
if (fs.existsSync(BASELINE)) { try { baseFile = JSON.parse(fs.readFileSync(BASELINE, 'utf8')); } catch (e) {} }
const base = baseFile.counts || { deadSlugs: 0, deadCards: 0, deadPlates: 0, unnamed: 0 };

if (UPDATE) {
  // The `why` block is the whole discipline of this baseline — it says which
  // numbers are ACCEPTED and on what grounds. An update that silently wiped it
  // would turn the next reader's "just re-baseline" into exactly the unrecorded
  // bump this file exists to prevent, so it is CARRIED FORWARD. Numbers that
  // went UP are called out for you to justify.
  const raised = Object.keys(counts).filter(k => counts[k] > (base[k] ?? 0));
  fs.writeFileSync(BASELINE, JSON.stringify({
    note: baseFile.note || 'Regression baseline for lint_tod_assets.js GATE B. Lower is better. NEVER raise a number to make the lint green - fix the art, or replace this note with the reason the new number is correct. GATE A (missing art) has no baseline: it is always a hard fail.',
    updated: new Date().toISOString().slice(0, 10),
    why: baseFile.why || undefined,
    counts,
  }, null, 2) + '\n');
  console.log('baseline updated: ' + JSON.stringify(counts));
  if (baseFile.why) console.log('  (the "why" block was carried forward — update the entries for any number that moved)');
  if (raised.length) console.log('  RAISED: ' + raised.map(k => `${k} ${base[k]} -> ${counts[k]}`).join(', ') + ' — record WHY in the baseline, or this is dead weight nobody will question again.');
  process.exit(0);
}

const show = (label, arr) => { if (!arr.length) return; console.log(`\n${label} (${arr.length}):`); for (const f of arr) console.log('  * ' + f); };

if (missing.length) {
  console.error('\nlint_tod_assets: GATE A — MISSING ART (' + missing.length + ')');
  for (const f of missing) console.error('  * ' + f);
}
const plateDrift = [];
if (sbPlateMax !== null && plateMax && sbPlateMax !== plateMax)
  plateDrift.push(`AetheriumScoreboard.lua TOD_UPG_PLATE_MAX ${sbPlateMax} != AetheriumStartMenu.lua PAUSE_PLATE_MAX ${plateMax} — rows ${Math.min(sbPlateMax, plateMax) + 1}..${Math.max(sbPlateMax, plateMax)} draw a plate on one screen and a text label on the other`);
if (plateDrift.length) {
  console.error('\nlint_tod_assets: GATE D — PLATE CEILING DRIFT BETWEEN THE TWO OWNED-UPGRADES SCREENS');
  for (const f of plateDrift) console.error('  * ' + f);
  console.error('  The pause menu and the scoreboard read one CoD.TodOwned and must agree on which ids have baked plates.');
}
if (overCap.length) {
  console.error('\nlint_tod_assets: GATE C — PAUSE ROWS OVER CAPACITY (' + overCap.length + ')');
  for (const f of overCap) console.error('  * ' + f);
  console.error('  Raise ROWS_MAX (and the row metrics that make the rows fit) in');
  console.error('  ui/uieditor/menus/StartMenu/AetheriumStartMenu.lua. Do NOT let it ride on "+N MORE".');
}
if (REPORT) {
  show('GATE B — dead CARD_SLUG entries', deadSlugs);
  show('GATE B — dead zoned cards', deadCards);
  show('GATE B — dead zoned pause plates', deadPlates);
  console.log(`\nadvisory — zoned i_tod_* no Lua literal names (${unnamed.length}); a constructed name may still reach these:`);
  for (const i of unnamed.sort()) console.log('    ' + i);
}

const regressed = Object.keys(counts).filter(k => counts[k] > base[k]);
if (regressed.length && !REPORT) {
  console.error('\nlint_tod_assets: GATE B REGRESSION — ' +
    regressed.map(k => `${k} ${base[k]} -> ${counts[k]}`).join(', '));
  console.error('  Retiring a domain? Remove its CARD_SLUG slug AND its zone lines together (the v16.80/v16.86 pattern).');
  console.error('  Run with --report to see them. Fix the art; do not raise the baseline to hide it.');
}

console.log(`\nassets: ${zoned.size} zoned image(s), ${cardSlug.size} card slug(s), ` +
  `${liveIds.size} live domain id(s), plate ceiling ${plateMax}; ` +
  `dead slugs ${counts.deadSlugs}/${base.deadSlugs}, dead cards ${counts.deadCards}/${base.deadCards}, ` +
  `dead plates ${counts.deadPlates}/${base.deadPlates}, unnamed ${counts.unnamed}/${base.unnamed} (now/baseline); ` +
  `pause rows ${classRowCounts.join(' / ')} vs capacity ${rowsMax * 2} (scoreboard ${sbCap}, tier row excluded)`);

process.exit((missing.length || overCap.length || plateDrift.length || (regressed.length && !REPORT)) ? 1 : 0);
