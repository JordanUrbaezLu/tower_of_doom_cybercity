'use strict';
// tools/test_party_shield.js - TEAMMATES' SHIELD BARS (2026-09-30).
//
// User: "add ... other players shield bar above their health bar ... I dont want the
// icon as well. Just the bar so other players know".
// Server: _zm_aetherium_hud::party_shield_watch packs every slot's shield percent into
// one int (TOD_SHIELD_BITS per slot) and LuiNotifyEvent's it to every player.
// Client: AetheriumPartyPlayers.lua decodes its row's slot (SHIELD_BASE) and paints a
// thin bar between the name and the health bar.
//
// Pins: the base lockstep and a full encode/decode round trip, the precached
// eventstring + its one-int payload, the watcher started from __main__ (post-func: its
// black-screen wait would crash a pre-func, see lint_tod_init_flags.js), the value
// source (stock's shield uimodel + hasRiotShield), the dev-only preview on unoccupied
// slots, the row's bar slot, NO icon on the rows, and both new elements closed.
// Every run also proves itself on in-memory mutations of the real files.
// Usage: node tools/test_party_shield.js
const fs = require('fs'), path = require('path');
const REPO = path.join(__dirname, '..');
const GSC = path.join(REPO, 'scripts/zm/_zm_aetherium_hud.gsc');
const LUA = path.join(REPO, 'ui/uieditor/widgets/HUD/AetheriumWidgets/AetheriumPartyPlayers.lua');

function stripGsc(s) { return s.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, ''); }
function stripLua(s) { return s.replace(/--\[\[[\s\S]*?\]\]/g, '').replace(/--[^\n]*/g, ''); }
function fnBody(src, re) {
  const m = re.exec(src); if (!m) return null;
  const open = src.indexOf('{', m.index); let d = 0;
  for (let i = open; i < src.length; i++) { if (src[i] === '{') d++; else if (src[i] === '}') { d--; if (d === 0) return src.slice(open + 1, i); } }
  return null;
}

function check(gscRaw, luaRaw) {
  const fails = [];
  const gsc = stripGsc(gscRaw), lua = stripLua(luaRaw);
  const ok = (cond, msg) => { if (!cond) fails.push(msg); };

  // --- lockstep + round trip
  const gb = /#define\s+TOD_SHIELD_BITS\s+(\d+)/.exec(gsc);
  const lb = /local\s+SHIELD_BASE\s*=\s*(\d+)/.exec(lua);
  ok(gb && lb, 'TOD_SHIELD_BITS (gsc) and SHIELD_BASE (lua) both defined');
  const base = gb ? +gb[1] : 0;
  ok(gb && lb && +gb[1] === +lb[1], `lockstep: TOD_SHIELD_BITS ${gb && gb[1]} == SHIELD_BASE ${lb && lb[1]}`);
  ok(base > 100, 'a slot holds 0..100');
  ok(Math.pow(base, 4) <= 2147483647, 'four slots fit one signed int');
  const pack = fnBody(gsc, /function\s+shield_pack\s*\(/);
  ok(pack && /pct\s*\[\s*3\s*\]\s*\*\s*TOD_SHIELD_BITS\s*\*\s*TOD_SHIELD_BITS\s*\*\s*TOD_SHIELD_BITS/.test(pack)
     && /pct\s*\[\s*1\s*\]\s*\*\s*TOD_SHIELD_BITS/.test(pack), 'shield_pack: slot n at TOD_SHIELD_BITS^n');
  ok(/SHIELD_BASE\s*\^\s*id\s*\)\s*\)\s*%\s*SHIELD_BASE/.test(lua), 'lua decode: floor(packed / SHIELD_BASE^id) % SHIELD_BASE');
  if (base > 100) {
    let bad = 0;
    for (let n = 0; n < 2000; n++) {
      const p = [0, 1, 2, 3].map(() => Math.floor(Math.random() * 101));
      const packed = p[0] + p[1] * base + p[2] * base * base + p[3] * base * base * base;
      for (let id = 0; id < 4; id++) if (Math.floor(packed / Math.pow(base, id)) % base !== p[id]) bad++;
    }
    ok(bad === 0, `round trip: ${bad} slot mismatches over 2000 random parties`);
  }

  // --- the server lane
  ok(/#precache\s*\(\s*"eventstring"\s*,\s*"tod_party_shield"\s*\)/.test(gsc), 'eventstring tod_party_shield precached');
  ok(/LuiNotifyEvent\s*\(\s*&"tod_party_shield"\s*,\s*1\s*,\s*packed\s*\)/.test(gsc), 'LuiNotifyEvent( &"tod_party_shield", 1, packed )');
  const main = fnBody(gsc, /function\s+__main__\s*\(/), init = fnBody(gsc, /function\s+__init__\s*\(/);
  ok(main && /thread\s+party_shield_watch\s*\(/.test(main), 'started from __main__ (post-func)');
  ok(!(init && /party_shield_watch/.test(init)), 'NOT started from __init__ (its flag wait would crash the load)');
  const pct = fnBody(gsc, /function\s+shield_pct\s*\(/);
  ok(pct && /get_player_uimodel\s*\(\s*"zmInventory\.shield_health"\s*\)/.test(pct), 'value = the local bar\'s own uimodel');
  ok(pct && /hasRiotShield/.test(pct), 'shown only while stock says the player has a shield');
  const watch = fnBody(gsc, /function\s+party_shield_watch\s*\(/);
  ok(watch && /IS_TRUE\s*\(\s*level\.tod_dev\s*\)[\s\S]*?for\s*\(\s*i\s*=\s*players\.size/.test(watch), 'preview values: dev only, unoccupied slots only');
  ok(watch && /GetTime\s*\(\s*\)\s*>=\s*refresh/.test(watch) && /refresh\s*=\s*GetTime\s*\(\s*\)\s*\+\s*2000/.test(watch), 'change-gated with a 2 s hydrate');

  // --- the row
  ok(/"tod_party_shield"/.test(lua) && /scriptNotify/.test(lua), 'row subscribes to scriptNotify tod_party_shield');
  ok(!/riotshield_zm_icon|shield_icon/.test(lua), 'NO shield icon on the party rows (user)');
  const closeM = /OverrideFunction_CallOriginalSecond\s*\(\s*self\s*,\s*"close"[\s\S]*?end\s*\)/.exec(lua);
  ok(closeM && /shield_fill:close\(\)/.test(closeM[0]) && /shield_track:close\(\)/.test(closeM[0]), 'close() closes shield_fill and shield_track');
  const num = (re) => { const m = re.exec(lua); return m ? parseFloat(m[1]) : NaN; };
  const nameTop = num(/local\s+nameTop\s*=\s*bgTop\s*\+\s*([\d.]+)/);
  const nameH = num(/local\s+nameBottom\s*=\s*nameTop\s*\+\s*([\d.]+)/);
  const shieldTop = num(/local\s+shieldTop\s*=\s*bgTop\s*\+\s*([\d.]+)/);
  const trackH = num(/shield_track:setTopBottom\(\s*true\s*,\s*false\s*,\s*shieldTop\s*,\s*shieldTop\s*\+\s*([\d.]+)\s*\)/);
  const healthTop = num(/health_track:setTopBottom\(\s*true\s*,\s*false\s*,\s*bgTop\s*\+\s*([\d.]+)/);
  ok([nameTop, nameH, shieldTop, trackH, healthTop].every(Number.isFinite), 'row layout numbers readable');
  ok(nameTop + nameH < shieldTop, `name (ends ${nameTop + nameH}) above the shield trough (${shieldTop})`);
  ok(shieldTop + trackH < healthTop, `shield trough (ends ${shieldTop + trackH}) above the health trough (${healthTop})`);
  return fails;
}

const gscRaw = fs.readFileSync(GSC, 'utf8'), luaRaw = fs.readFileSync(LUA, 'utf8');
const fails = check(gscRaw, luaRaw);
if (fails.length) { fails.forEach(f => console.log('[party-shield] FAIL: ' + f)); process.exit(1); }

// Negative controls: one in-memory mutation each, every one must fail the check.
const controls = [
  ['base drift (lua 64)', gscRaw, luaRaw.replace(/local SHIELD_BASE = \d+/, 'local SHIELD_BASE = 64')],
  ['watcher moved into __init__', gscRaw.replace('callback::on_connect( &on_player_connect );', 'callback::on_connect( &on_player_connect );\n\tlevel thread party_shield_watch();'), luaRaw],
  ['icon added to the rows', gscRaw, luaRaw.replace('self:addElement( self.shield_fill )', 'self:addElement( self.shield_fill )\n\tself.shield_icon = LUI.UIImage.new()')],
  ['shield_fill not closed', gscRaw, luaRaw.replace('if element.shield_fill then element.shield_fill:close() end', '')],
  ['bar overlaps the health bar', gscRaw, luaRaw.replace('local shieldTop = bgTop + 18.5', 'local shieldTop = bgTop + 21')],
  ['eventstring not precached', gscRaw.replace(/#precache\( "eventstring", "tod_party_shield" \);[^\n]*/, ''), luaRaw],
];
let missed = 0;
for (const [why, g, l] of controls) {
  if (g === gscRaw && l === luaRaw) { console.log('[party-shield] CONTROL DID NOT MUTATE: ' + why); missed++; continue; }
  if (check(g, l).length === 0) { console.log('[party-shield] CONTROL MISSED: ' + why); missed++; }
}
if (missed) { console.log(`[party-shield] FAIL: ${missed} negative control(s) not caught`); process.exit(1); }
console.log(`[party-shield] OK: lockstep ${/#define\s+TOD_SHIELD_BITS\s+(\d+)/.exec(gscRaw)[1]}, round trip, server lane, row slot, no icon, cleanup; ${controls.length} negative controls caught.`);
