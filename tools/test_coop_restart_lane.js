#!/usr/bin/env node
// THE RESTART LANE GATE (v19.63, 2026-09-30; re-scoped 2026-10-01).
//
// WHY THIS EXISTS. The restart button has broken in a different place each time
// it was "fixed", because nothing checked HOW the menu restarts:
//   kit     Restart Level = GoBack + Engine.Exec(controller, "map_restart"), a
//           CONSOLE command on the pressing machine. Solo: fine for months.
//           Online co-op host: the host reloads alone, the teammate drops
//           (Tixy, Sep 7: "it kicks the other player out in coop!").
//   v19.16  HID the button in co-op -> Biffbrooks11 (Sep 29) "the restart button
//           doesn't work", and split-screen lost it too.
//   v19.63  moved EVERY restart onto a server request closed with plain GoBack,
//           which does not unpause: a SOLO game froze on one frame until
//           something else unpaused (lead tester, Oct 1).
// THE CONTRACT NOW (2026-10-01, user: "the stock aetherium HUD had this
// perfectly set up ... once we started tweaking i think we got lost"):
//   1. Every human at this machine (solo / split-screen) -> the kit's own
//      restart and leave, verbatim (TodKitRestart / TodKitLeave). The console
//      command runs on THIS machine, which here is the whole game.
//   2. A host with a teammate on ANOTHER machine -> TodGoServer: the request FIRST
//      on two lanes (the host-machine dvar tod_go_request, read by
//      _tod_gameover::go_request_watch - the lane that works at GAME OVER, where
//      a menu response never reached the server in the 2026-10-01 co-op test -
//      and the menu response), then TodGoClose (unpause +
//      StartMenuGoBack) then the server request; _tod_gameover restarts with
//      stock's map_restart( true ) (every client stays connected) or ends with
//      ExitLevel( false ) (the party to the lobby together).
//   3. The deciding fact comes from the server: party_push's host value
//      0 = not the host machine, 1 = host + remote teammate, 2 = host + all
//      local (IsLocalToHost per human); the HUD files it per controller
//      (split-screen shares ONE Lua VM); the host-machine dvar tod_party_remote
//      is the instant fallback (written at level start, before any HUD); with
//      neither, this is a teammate's machine -> the server lane, which the
//      server ignores for a non-host.
//   4. The cached "game-over menu is up" flag is cleared at HUD build and on
//      restart, or the next game's pause menu opens as the game-over list.
// Negative controls mutate copies of the sources and require a catch on each,
// including the exact kit / v19.16-style / v19.63 shapes.
'use strict';
const fs = require('fs');
const path = require('path');
const assert = require('assert');

const REPO = path.resolve(__dirname, '..');
const crlf = s => s.replace(/\r\n/g, '\n');   // the sources are CRLF
const rd = f => crlf(fs.readFileSync(path.join(REPO, f), 'utf8'));
const MENU = 'ui/uieditor/menus/StartMenu/AetheriumStartMenu.lua';
const HUD = 'ui/uieditor/menus/hud/AetheriumHud.lua';
const GO = 'scripts/zm/zm_tower_of_doom/_tod_gameover.gsc';
const MAIN = 'scripts/zm/zm_tower_of_doom/_tod_main.gsc';

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (e.name.endsWith('.lua')) out.push(p);
  }
  return out;
}

// Strip comments so a historical note about an old lane is not a hit.
const stripLua = s => s.replace(/--\[\[[\s\S]*?\]\]/g, '').replace(/--[^\n]*/g, '');
const stripGsc = s => s.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '');
const body = (src, re) => (src.match(re) || ['', ''])[1];

function check(src) {
  const problems = [];
  const menu = stripLua(src.lua[MENU]);
  const go = stripGsc(src.gsc[GO]);
  const main = stripGsc(src.gsc[MAIN]);
  const hud = stripLua(src.lua[HUD]);

  // ---- 1. the console restart lives in ONE place: the kit's own helper ------
  for (const [file, text] of Object.entries(src.lua)) {
    let t = stripLua(text);
    if (file === MENU) t = t.replace(/local TodKitRestart = function\(menu, controller\)[\s\S]*?\nend/, '');
    if (/Engine\.Exec\s*\(\s*[^)]*map_restart/.test(t))
      problems.push(`${file}: Engine.Exec map_restart outside TodKitRestart - the console restart reloads only THIS machine and drops an online teammate`);
  }
  const kit = body(menu, /local TodKitRestart = function\(menu, controller\)([\s\S]*?)\nend/);
  if (!kit) problems.push('AetheriumStartMenu: TodKitRestart (the kit\'s own restart) is missing');
  else {
    if (!/(^|\n)\s*GoBack\(menu, controller\)\s*\n\s*Engine\.Exec\(controller, "map_restart"\)/.test(kit))
      problems.push('AetheriumStartMenu: TodKitRestart must be the kit verbatim - GoBack(menu, controller) then Engine.Exec(controller, "map_restart")');
    if (!/TodClearGoFlag\(\)/.test(kit)) problems.push('AetheriumStartMenu: TodKitRestart must clear the cached game-over flag (the Lua VM outlives the restart)');
  }
  const leave = body(menu, /local TodKitLeave = function\(menu, controller\)([\s\S]*?)\nend/);
  if (!/close_all_ingame_menus/.test(leave) || !/Engine\.Exec\(controller, "disconnect"\)/.test(leave) || !/"cl_paused", 0/.test(leave))
    problems.push('AetheriumStartMenu: TodKitLeave must be the kit\'s Leave Game lane (close_all_ingame_menus, cl_paused 0, disconnect)');

  // ---- 2. every Restart: kit lane ONLY behind TodLocalParty, else the server --
  const restarts = [...menu.matchAll(/displayText = "(Restart (?:Level|Map))",\s*action = function\(self, element, controller, actionParam, menu\)([\s\S]*?)\n\t*end\n\t*\}/g)];
  if (restarts.length < 2) problems.push(`AetheriumStartMenu: expected the pause Restart Level AND the game-over Restart Map (found ${restarts.length})`);
  for (const [, name, act] of restarts) {
    if (!/^\s*if TodLocalParty\(controller\) then\s*\n\s*TodKitRestart\(menu, controller\)\s*\n\s*return\s*\n\s*end/.test(act))
      problems.push(`AetheriumStartMenu: ${name} must open with "if TodLocalParty(controller) then TodKitRestart(menu, controller) return end" - the kit lane only when every human is at this machine`);
    const tail = act.replace(/^[\s\S]*?\n\s*end\n/, '');
    if (!/^\s*TodGoServer\(menu, controller, "restart"\)\s*$/.test(tail))
      problems.push(`AetheriumStartMenu: ${name} must otherwise take the server lane: TodGoServer(menu, controller, "restart")`);
    if (/(^|\n)\s*GoBack\(menu, controller\)/.test(tail))
      problems.push(`AetheriumStartMenu: ${name} closes the server lane with plain GoBack - that leaves a paused game paused (the v19.63 freeze)`);
  }
  const endAct = body(menu, /displayText = "End Game",\s*action = function\(self, element, controller, actionParam, menu\)([\s\S]*?)\n\t*end\n\t*\}/);
  if (!/if TodIsHost\(controller\) and not TodLocalParty\(controller\) then\s*\n\s*TodGoServer\(menu, controller, "end"\)/.test(endAct))
    problems.push('AetheriumStartMenu: End Game must ask the server ONLY for a host with a remote teammate (TodIsHost and not TodLocalParty -> TodGoServer "end")');
  // THE SERVER LANE (2026-10-01): request FIRST on both lanes, then close + unpause.
  // The game-over menu's response never reached the server in the user's co-op
  // test (stock's end_game marks the match ended); the host-machine dvar does.
  const srv = body(menu, /local TodGoServer = function\(menu, controller, what\)([\s\S]*?)\nend/);
  if (!srv) problems.push('AetheriumStartMenu: TodGoServer(menu, controller, what) is missing');
  else {
    if (!/TodGoRequest\(controller, what\)[\s\S]*pcall\(TodGoClose, menu, controller\)/.test(srv))
      problems.push('AetheriumStartMenu: TodGoServer must send the request FIRST, then close + unpause through TodGoClose (pcall)');
    if (!/TodClearGoFlag\(\)/.test(srv)) problems.push('AetheriumStartMenu: TodGoServer must clear the cached game-over flag on a restart');
  }
  const order = ['local TodGoRequest', 'local TodGoClose', 'local TodClearGoFlag', 'local TodGoServer'].map(k => menu.indexOf(k));
  if (order.some(i => i < 0) || !(order[3] > order[0] && order[3] > order[1] && order[3] > order[2]))
    problems.push('AetheriumStartMenu: TodGoServer must be declared BELOW TodGoRequest / TodGoClose / TodClearGoFlag (a Lua closure above a local binds a nil global)');
  const req = body(menu, /local TodGoRequest = function\(controller, what\)([\s\S]*?)\nend/);
  if (!/Engine\.SetDvar\("tod_go_request", what\)/.test(req))
    problems.push('AetheriumStartMenu: TodGoRequest must write the host-machine dvar tod_go_request (the lane that works at game over)');
  const watch = body(go, /function go_request_watch\s*\(\s*\)\s*\{([\s\S]*?)\n\}/);
  if (!watch) problems.push('_tod_gameover: go_request_watch is missing');
  else {
    if (!/^\s*SetDvar\( "tod_go_request", "" \);/.test(watch)) problems.push('_tod_gameover: go_request_watch must scrub tod_go_request before its loop (a stale request would restart the next level)');
    if (!/GetDvarString\( "tod_go_request" \)/.test(watch) || !/level thread host_restart\(\);/.test(watch) || !/level thread host_end\(\);/.test(watch))
      problems.push('_tod_gameover: go_request_watch must read tod_go_request and run host_restart / host_end');
    if (/endon\(\s*"end_game"\s*\)/.test(watch)) problems.push('_tod_gameover: go_request_watch must NOT end at end_game - game over is when it matters');
  }
  if (!/level thread go_request_watch\(\);/.test(go)) problems.push('_tod_gameover: init must start go_request_watch');
  if (!/TodKitLeave\(menu, controller\)/.test(endAct)) problems.push('AetheriumStartMenu: every other End Game must be the kit\'s leave (TodKitLeave)');
  const goClose = body(menu, /local TodGoClose = function\(menu, controller\)([\s\S]*?)\nend/);
  if (!goClose) problems.push('AetheriumStartMenu: TodGoClose(menu, controller) is missing');
  else {
    if (!/Engine\.SetDvar\("cl_paused", 0\)/.test(goClose)) problems.push('AetheriumStartMenu: TodGoClose must clear cl_paused (stock popups unpause FIRST)');
    if (!/StartMenuGoBack\(menu, controller\)/.test(goClose)) problems.push('AetheriumStartMenu: TodGoClose must close through StartMenuGoBack (unpause + SetActiveMenu NONE), not plain GoBack');
  }

  // ---- 3. who is local: server fact, host dvar, default local ---------------
  const lp = body(menu, /local TodLocalParty = function\(controller\)([\s\S]*?)\nend/);
  if (!lp) problems.push('AetheriumStartMenu: TodLocalParty(controller) is missing');
  else {
    if (!/local _, _, _, localOnly = TodParty\(controller\)/.test(lp) || !/return localOnly == true/.test(lp))
      problems.push('AetheriumStartMenu: TodLocalParty must read the server\'s per-controller answer first (TodParty -> localOnly)');
    if (!/TodDvarNumber\(controller, "tod_party_remote"\)/.test(lp) || !/return remote <= 0/.test(lp))
      problems.push('AetheriumStartMenu: TodLocalParty must fall back to the host-machine dvar tod_party_remote');
    if (!/\n\treturn false\s*$/.test(lp)) problems.push('AetheriumStartMenu: with no server answer AND no host dvar TodLocalParty must answer false - that is a teammate\'s machine (the host machine has the dvar from level start), and the server lane is the one a non-host cannot act on');
  }
  if (!/return p\.n, \(p\.host == true\), \(p\.go == true\), p\.localOnly/.test(menu)) problems.push('AetheriumStartMenu: TodParty must return localOnly as its 4th value');
  if (!/CoD\.TodPartyBy\[controller\]/.test(menu)) problems.push('AetheriumStartMenu: must read the party facts for ITS controller (CoD.TodPartyBy[controller]) before the shared fallback');

  // ---- 4. LOCKSTEP menu name + key ------------------------------------------
  const luaSend = menu.match(/SendMenuResponse\s*\(\s*controller\s*,\s*"([^"]+)"\s*,\s*"([a-z_]+)\|"\s*\.\.\s*what\s*\)/);
  if (!luaSend) problems.push('AetheriumStartMenu: TodGoRequest must send SendMenuResponse(controller, "<menu>", "<key>|" .. what)');
  const gscMenu = go.match(/#define\s+TOD_GO_MENU\s+"([^"]+)"/);
  const gscKey = go.match(/#define\s+TOD_GO_KEY\s+"([^"]+)"/);
  if (!gscMenu || !gscKey) problems.push('_tod_gameover: TOD_GO_MENU / TOD_GO_KEY defines missing');
  if (luaSend && gscMenu && luaSend[1] !== gscMenu[1]) problems.push(`menu name drift: Lua "${luaSend[1]}" vs GSC "${gscMenu[1]}"`);
  if (luaSend && gscKey && luaSend[2] !== gscKey[1]) problems.push(`response key drift: Lua "${luaSend[2]}" vs GSC "${gscKey[1]}"`);

  // ---- 5. the GSC contract ----------------------------------------------------
  if (!/function go_menu_watch\s*\(\s*\)[\s\S]*?waittill\s*\(\s*"menuresponse"/.test(go)) problems.push('_tod_gameover: go_menu_watch must wait on "menuresponse"');
  if (!/host = self go_is_host\(\);[\s\S]*?if \( !host \)\s*continue;/.test(go)) problems.push('_tod_gameover: go_menu_watch must act only when self go_is_host()');
  const isHost = body(go, /function go_is_host\s*\(\s*\)\s*\{([\s\S]*?)\n\}/);
  if (!/IsHost\(\)/.test(isHost) || !/IsLocalToHost\(\)/.test(isHost)) problems.push('_tod_gameover: go_is_host must be IsHost() OR IsLocalToHost() (the split-screen guest sits at the host machine)');
  const push = body(go, /function party_push\s*\(\s*go\s*\)\s*\{([\s\S]*?)\n\}/);
  if (!/remote = party_remote_humans\(\);/.test(push) || !/if \( p go_is_host\(\) \)\s*\n\s*host = \( \( remote > 0 \) \? 1 : 2 \);/.test(push))
    problems.push('_tod_gameover: party_push must send host 0 / 1 (remote teammate) / 2 (all local) through go_is_host() and party_remote_humans()');
  // the dev co-op stand-in (2026-10-01) can never count a bot as a teammate in a
  // shipping build: both dev flags AND the preview bot's own mark are required
  const mock = body(go, /function coop_mock_teammate\s*\(\s*p\s*\)\s*\{([\s\S]*?)\n\}/);
  if (!/IS_TRUE\( level\.tod_dev \)/.test(mock) || !/IS_TRUE\( level\.tod_dev_coop_mock \)/.test(mock) || !/IS_TRUE\( p\.tod_dev_mage_dummy \)/.test(mock))
    problems.push('_tod_gameover: coop_mock_teammate must require level.tod_dev AND level.tod_dev_coop_mock AND the preview bot\'s tod_dev_mage_dummy mark (a bot must never count as a teammate in a shipping build)');
  // dropping a leftover dev bot runs stock's disconnect check (checkForAllDead), which
  // ended the freshly restarted game before the host spawned ("restart the map twice
  // in coop", 2026-10-01): the drop must hold stock's end-game guard first
  const sweep = body(go, /function leftover_bot_sweep\s*\(\s*\)\s*\{([\s\S]*?)\n\}/);
  if (!/level thread hold_end_game_check_for_drop\( p \);\s*\n\s*p BotDropClient\(\);/.test(sweep))
    problems.push('_tod_gameover: leftover_bot_sweep must start hold_end_game_check_for_drop BEFORE BotDropClient (a drop with nobody up yet ends the restarted game)');
  const hold = body(go, /function hold_end_game_check_for_drop\s*\(\s*bot\s*\)\s*\{([\s\S]*?)\n\}/);
  if (!/^\s*zm_utility::increment_no_end_game_check\(\);/.test(hold) || !/restart_human_up\(\)[\s\S]*zm_utility::decrement_no_end_game_check\(\);/.test(hold))
    problems.push('_tod_gameover: hold_end_game_check_for_drop must increment stock\'s guard first and decrement it only once a human is up');
  // both lanes leave the restart mark the new level logs (RESTART_BACK / RESTART_UP)
  if (!/SetDvar\( "tod_go_restart_mark", "server" \);[\s\S]{0,300}map_restart\(\s*true\s*\)/.test(go)) problems.push('_tod_gameover: host_restart must set tod_go_restart_mark "server" before map_restart (the restart-came-back log)');
  if (!/Engine\.SetDvar\("tod_go_restart_mark", "kit"\)/.test(kit)) problems.push('AetheriumStartMenu: TodKitRestart must set tod_go_restart_mark "kit" (the restart-came-back log)');
  if (!/GetDvarString\( "tod_go_restart_mark" \)/.test(go) || !/RESTART_UP/.test(go)) problems.push('_tod_gameover: restart_back_log must read tod_go_restart_mark and log RESTART_UP');
  const rem = body(go, /function party_remote_humans\s*\(\s*\)\s*\{([\s\S]*?)\n\}/);
  if (!/IsTestClient\(\)/.test(rem) || !/!\s*\(\s*p IsLocalToHost\(\)\s*\)/.test(rem))
    problems.push('_tod_gameover: party_remote_humans must count humans that are NOT IsLocalToHost() (test clients excluded)');
  if (!/game\[\s*"state"\s*\]\s*=\s*"playing";\s*\n\s*map_restart\(\s*true\s*\);/.test(go)) problems.push('_tod_gameover: host_restart must write game["state"] = "playing" immediately before map_restart( true ) (stock round-switch recipe)');
  if (!/LUINotifyEvent\(\s*&"force_scoreboard"\s*,\s*1\s*,\s*0\s*\);[\s\S]{0,200}map_restart\(\s*true\s*\)/.test(go)) problems.push('_tod_gameover: host_restart must release the forced scoreboard before map_restart');
  const hostEnd = body(go, /function host_end\s*\(\s*\)\s*\{([\s\S]*?)\n\}/);
  if (!/ExitLevel\(\s*false\s*\);/.test(hostEnd)) problems.push('_tod_gameover: host_end must call ExitLevel( false )');
  if (!/#precache\(\s*"eventstring"\s*,\s*"tod_party"\s*\)/.test(src.gsc[GO])) problems.push('_tod_gameover: #precache( "eventstring", "tod_party" ) missing');
  if (!/LuiNotifyEvent\(\s*&"tod_party"\s*,\s*3\s*,/.test(go)) problems.push('_tod_gameover: party_push must send LuiNotifyEvent( &"tod_party", 3, ... )');
  if (!/callback::on_connect\(\s*&on_player_connect\s*\)/.test(go)) problems.push('_tod_gameover: the per-player watcher must be installed on connect');

  // ---- 6. published + read ----------------------------------------------------
  if (!/tod_gameover::party_push\(\s*0\s*\)/.test(main)) problems.push('_tod_main: party_dvar_watch must heartbeat tod_gameover::party_push( 0 )');
  if (!/SetDvar\(\s*"tod_party_remote"\s*,\s*""\s*\+\s*remote\s*\)/.test(main) || !/remote = tod_gameover::party_remote_humans\(\);/.test(main))
    problems.push('_tod_main: party_dvar_watch must publish tod_party_remote (the host machine\'s instant answer)');
  if (!/~=\s*"tod_party"/.test(hud) || !/CoD\.TodParty\s*=\s*\{/.test(hud)) problems.push('AetheriumHud: must subscribe scriptNotify "tod_party" and write CoD.TodParty');
  const facts = body(hud, /CoD\.TodParty\s*=\s*\{([\s\S]*?)\}/);
  for (const f of ['n', 'host', 'localOnly', 'go']) if (!new RegExp(`\\b${f}\\s*=`).test(facts)) problems.push(`AetheriumHud: CoD.TodParty must carry field "${f}"`);
  if (!/host = \( hv >= 1 \)/.test(facts) || !/localOnly = \( hv == 2 \)/.test(facts)) problems.push('AetheriumHud: host value decode must be host = hv >= 1, localOnly = hv == 2 (LOCKSTEP party_push)');
  if (!/CoD\.TodPartyBy\[\s*controller\s*\]\s*=/.test(hud)) problems.push('AetheriumHud: must also file the party facts per controller (CoD.TodPartyBy[ controller ]) - split-screen shares one Lua VM');
  if (!/CoD\.TodPartyBy\[ controller \]\.go = false/.test(hud)) problems.push('AetheriumHud: a newly built HUD must clear the cached game-over flag (stale go=true turns the next pause menu into the game-over list)');
  return problems;
}

function load() {
  const lua = {};
  for (const p of walk(path.join(REPO, 'ui'))) lua[path.relative(REPO, p).replace(/\\/g, '/')] = crlf(fs.readFileSync(p, 'utf8'));
  return { lua, gsc: { [GO]: rd(GO), [MAIN]: rd(MAIN) } };
}

const src = load();
const problems = check(src);
if (problems.length) {
  console.error('RESTART LANE: FAIL');
  for (const p of problems) console.error('  - ' + p);
  process.exit(1);
}

// ---- negative controls: each mutation must be caught ------------------------
const clone = () => ({ lua: { ...src.lua }, gsc: { ...src.gsc } });
const sub = (s, f, a, b) => { const t = s.lua[f] !== undefined ? 'lua' : 'gsc'; const before = s[t][f]; s[t][f] = before.replace(a, b); assert(s[t][f] !== before, `control did not apply: ${a}`); };
const controls = [
  // the three shipped shapes
  ['kit shape: unconditional console restart (kicks an online teammate)', s => sub(s, MENU, /if TodLocalParty\(controller\) then\s*\n(\s*)TodKitRestart\(menu, controller\)\s*\n\s*return\s*\n\s*end/g, 'TodKitRestart(menu, controller)\n$1do return end')],
  ['v19.63 shape: the server lane closes with plain GoBack', s => sub(s, MENU, 'pcall(TodGoClose, menu, controller)', 'GoBack(menu, controller)')],
  ['menu-response-only request (the game-over bug)', s => sub(s, MENU, /\n\s*pcall\(function\(\)\s*\n\s*Engine\.SetDvar\("tod_go_request", what\)\s*\n\s*end\)/, '')],
  ['server stops watching the host dvar', s => sub(s, GO, 'level thread go_request_watch();', '')],
  ['host dvar watcher dies at game over', s => sub(s, GO, /(function go_request_watch\(\)\s*\n\{\s*\n)/, '$1\tlevel endon( "end_game" );\n')],
  ['stale request not scrubbed at level start', s => sub(s, GO, /(function go_request_watch\(\)\s*\n\{\s*\n)\s*SetDvar\( "tod_go_request", "" \);[^\n]*\n/, '$1')],
  ['close before the request (nothing guards the press)', s => sub(s, MENU, /(local TodGoServer = function\(menu, controller, what\)\s*\n)\s*TodGoRequest\(controller, what\)\s*\n([\s\S]*?)pcall\(TodGoClose, menu, controller\)/, '$1\tpcall(TodGoClose, menu, controller)\n$2TodGoRequest(controller, what)')],
  ['v19.63 shape: every restart on the server (no kit lane)', s => sub(s, MENU, /if TodLocalParty\(controller\) then\s*\n\s*TodKitRestart\(menu, controller\)\s*\n\s*return\s*\n\s*end\s*\n/g, '')],
  // the kit helper itself
  ['kit restart drifts from the kit (no GoBack)', s => sub(s, MENU, /(local TodKitRestart = function\(menu, controller\)[\s\S]*?)GoBack\(menu, controller\)/, '$1StartMenuGoBack(menu, controller)')],
  ['kit restart leaves the game-over flag set', s => sub(s, MENU, /(local TodKitRestart = function\(menu, controller\)\s*\n)\s*TodClearGoFlag\(\)\s*\n/, '$1')],
  ['console map_restart in another Lua file', s => { s.lua[HUD] += '\nEngine.Exec( controller, "map_restart" )\n'; }],
  ['console map_restart inline in an action', s => sub(s, MENU, /(\n\s*)TodGoServer\(menu, controller, "restart"\)/, '$1Engine.Exec(controller, "map_restart")')],
  // End Game
  ['End Game: online host no longer asks the server', s => sub(s, MENU, 'if TodIsHost(controller) and not TodLocalParty(controller) then', 'if false then')],
  ['End Game: solo host asks the server (v19.63 shape)', s => sub(s, MENU, 'if TodIsHost(controller) and not TodLocalParty(controller) then', 'if TodIsHost(controller) then')],
  // who is local
  ['TodLocalParty defaults to the kit lane (a teammate\'s machine would run map_restart)', s => sub(s, MENU, /(local TodLocalParty = function\(controller\)[\s\S]*?\n\t)return false(\s*\nend)/, '$1return true$2')],
  ['TodLocalParty ignores the server answer', s => sub(s, MENU, 'return localOnly == true', 'return true')],
  ['TodLocalParty ignores the host dvar', s => sub(s, MENU, 'TodDvarNumber(controller, "tod_party_remote")', 'nil')],
  ['GSC always says "all local"', s => sub(s, GO, 'host = ( ( remote > 0 ) ? 1 : 2 );', 'host = 2;')],
  ['GSC counts the split-screen guest as remote', s => sub(s, GO, /!\s*\(\s*p IsLocalToHost\(\)\s*\)/, '!( p IsHost() )')],
  ['HUD drops the localOnly decode', s => sub(s, HUD, 'localOnly = ( hv == 2 ),', '')],
  ['co-op stand-in not dev-gated', s => sub(s, GO, /return IS_TRUE\( level\.tod_dev \) && IS_TRUE\( level\.tod_dev_coop_mock \)/, 'return true')],
  ['leftover bot dropped without holding the end-game check (the double restart)', s => sub(s, GO, /\n\s*level thread hold_end_game_check_for_drop\( p \);/, '')],
  ['end-game hold released before a human is up', s => sub(s, GO, /restart_human_up\(\)/, 'true')],
  ['server restart leaves no mark', s => sub(s, GO, 'SetDvar( "tod_go_restart_mark", "server" );', '')],
  ['kit restart leaves no mark', s => sub(s, MENU, 'Engine.SetDvar("tod_go_restart_mark", "kit")', '')],
  ['HUD keeps a stale game-over flag', s => sub(s, HUD, 'CoD.TodPartyBy[ controller ].go = false', 'local _ = 0')],
  ['host dvar fallback not published', s => sub(s, MAIN, /SetDvar\( "tod_party_remote", "" \+ remote \);/, '')],
  // the server side, unchanged from v19.63
  ['TodGoClose stops unpausing', s => sub(s, MENU, /(local TodGoClose = function\(menu, controller\)\s*\n)\s*Engine\.SetDvar\("cl_paused", 0\)\s*\n/, '$1')],
  ['TodGoClose closes with plain GoBack', s => sub(s, MENU, /(local TodGoClose = function\(menu, controller\)[\s\S]*?)StartMenuGoBack\(menu, controller\)/, '$1GoBack(menu, controller)')],
  ['game state not reset before map_restart', s => sub(s, GO, 'game[ "state" ] = "playing";\n', '')],
  ['host check removed', s => sub(s, GO, 'if ( !host )\n\t\t\tcontinue;', '')],
  ['split-screen guest not trusted', s => sub(s, GO, 'return ( self IsHost() || self IsLocalToHost() );', 'return self IsHost();')],
  ['response key drift', s => sub(s, GO, '#define TOD_GO_KEY   "tod_go"', '#define TOD_GO_KEY   "tod_go2"')],
  ['menu name drift', s => sub(s, MENU, 'Engine.SendMenuResponse(controller, "StartMenu_Main", "tod_go|" .. what)', 'Engine.SendMenuResponse(controller, "StartMenu_Other", "tod_go|" .. what)')],
  ['ExitLevel dropped', s => sub(s, GO, /(function host_end\(\)[\s\S]*?)ExitLevel\( false \);/, '$1wait 1;')],
  ['heartbeat removed', s => sub(s, MAIN, 'tod_gameover::party_push( 0 );', '')],
  ['per-controller party facts not written', s => sub(s, HUD, 'CoD.TodPartyBy[ controller ] = CoD.TodParty', 'CoD.TodPartyBy = CoD.TodParty')],
  ['per-controller party facts not read', s => sub(s, MENU, 'p = CoD.TodPartyBy[controller]', 'p = CoD.TodParty')],
];
let caught = 0;
for (const [name, mutate] of controls) {
  const s = clone();
  mutate(s);
  const p = check(s);
  assert(p.length > 0, `negative control NOT caught: ${name}`);
  caught++;
}
console.log(`Restart lane OK: solo / split-screen use the kit's own map_restart + disconnect (TodKitRestart / TodKitLeave behind TodLocalParty); a host with a remote teammate asks the server FIRST (host dvar tod_go_request + tod_go|restart / tod_go|end on ${src.gsc[GO].match(/#define\s+TOD_GO_MENU\s+"([^"]+)"/)[1]}), then closes + unpauses (TodGoServer -> TodGoClose) -> map_restart( true ) / ExitLevel( false ); party host value 0/1/2 published (event + tod_party_remote) and read per controller; stale game-over flag cleared. ${caught}/${controls.length} negative controls caught.`);
