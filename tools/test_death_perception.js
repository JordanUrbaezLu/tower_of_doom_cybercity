// test_death_perception.js — v19.72: Death Perception outlines EVERY enemy.
//
// Runs the SHIPPING text of _tod_perk_electric_cherry.gsc (the server pulse)
// and _tod_perk_electric_cherry.csc (the client outline) over a simulated
// clock, with mocked natives, against every enemy this map spawns:
//   horde, armored sprinter, Panzer, Warden King, Rogue Protector, hellhound,
//   Reaver.
// It proves the four server rules (every elite is outlined; never on its spawn
// frame; never while drop_in holds it Ghosted; a hound never before its reveal,
// a Protector despite its lifelong ignoreme) and the three client rules (a dead
// enemy loses its outline; any local owner lights the shared per-entity outline
// in split-screen; a departed split-screen owner no longer does). Each rule has
// a NEGATIVE CONTROL: the same run against the shipping text with that one rule
// mutated out must fail the same assertion.
//
// Also pins: the prompt card copy (fits the 40-slot pool, only typeface glyphs,
// says ENEMY not HORDE), the shared perk-table copy, and the DP_REV / clientfield
// registration lockstep between the two VMs.
//
//   node tools/test_death_perception.js
'use strict';
const fs = require('fs'), vm = require('vm'), path = require('path');
const assert = require('assert/strict');

const ROOT = path.join(__dirname, '..');
const GSC = path.join(ROOT, 'scripts/zm/zm_tower_of_doom/_tod_perk_electric_cherry.gsc');
const CSC = path.join(ROOT, 'scripts/zm/zm_tower_of_doom/_tod_perk_electric_cherry.csc');
const PROMPT = path.join(ROOT, 'ui/uieditor/widgets/HUD/ZM_CursorHint/Prompts/PromptPerks.lua');
const TABLE = path.join(ROOT, 'ui/uieditor/widgets/HUD/Mappings/AetheriumPerks.lua');

// ---------------------------------------------------------------------------
// GSC -> JS for the subset these two files use.
// ---------------------------------------------------------------------------
function stripComments(src) { return src.replace(/\/\/[^\n]*/g, ''); }

function defines(src) {
  const out = {};
  for (const m of src.matchAll(/^#define\s+(\w+)\s+([^\n]+?)\s*$/gm)) {
    const v = m[2].replace(/\/\/.*$/, '').trim();
    out[m[1]] = v;
  }
  return out;
}

function fn(src, name) {
  const at = src.indexOf('function ' + name + '(');
  assert.ok(at >= 0, 'function ' + name + ' not found');
  const params = src.slice(src.indexOf('(', at) + 1, src.indexOf(')', at)).split(',').map(s => s.trim()).filter(Boolean);
  const start = src.indexOf('{', at);
  let end = start + 1, depth = 1;
  while (depth) { if (src[end] === '{') depth++; if (src[end] === '}') depth--; end++; }
  return { params, body: src.slice(start + 1, end - 1) };
}

function translate(body) {
  return body
    .replace(/\/#|#\//g, '')                                            // devblock markers
    .replace(/(?:self|level)\s+endon\([^;]*;/g, '')                     // endons: the harness owns lifetimes
    .replace(/\bwait\s+([^;]+);/g, 'yield ($1);')
    .replace(/foreach\s*\(\s*(\w+)\s*,\s*(\w+)\s+in\s+([^)]+?)\s*\)/g, 'for (const [$1, $2] of __pairs($3))')
    .replace(/\bself\s+thread\s+(\w+)\(\s*/g, '__thread(self, $1(self, ')
    .replace(/\b(\w+)\s+(\w+)::(\w+)\(/g, '$1.$2__$3(')                 // ent ns::fn( -> ent.ns__fn(
    .replace(/\b(\w+)\s+(GetEntityNumber)\(/g, '$1.$2(')
    .replace(/\.size\b/g, '.length')
    // GSC locals are function-scoped: declare them, or two interleaved watcher
    // generators would share one global (`var` re-declaration is legal JS).
    .replace(/(^|[;{}\n])(\s*)([A-Za-z_]\w*)\s*=(?!=)/g, '$1$2var $3 =');
}

// Functions that read `self` get it as an explicit first parameter; the rest
// are plain (GSC passes self implicitly, and none of those use it).
function build(src, names, defs) {
  let code = '';
  for (const [k, v] of Object.entries(defs)) code += `const ${k} = ${v};\n`;
  for (const name of names) {
    const { params, body } = fn(src, name);
    let js = translate(body);
    // __thread(self, f(self, x)); -- close the extra paren the rewrite opened
    js = js.replace(/__thread\(self, (\w+)\(self, ([^;]*?)\);/g, '__thread(self, $1(self, $2));');
    const usesSelf = /\bself\b/.test(js);
    const gen = /\byield\b/.test(js);
    const ps = (usesSelf ? ['self'] : []).concat(params);
    code += `function${gen ? '*' : ''} ${name}(${ps.join(', ')}) {${js}}\n`;
  }
  return code;
}

const gscSrc = fs.readFileSync(GSC, 'utf8');
const cscSrc = fs.readFileSync(CSC, 'utf8');
const gscDefs = defines(gscSrc), cscDefs = defines(cscSrc);
const gscText = stripComments(gscSrc), cscText = stripComments(cscSrc);

// ---------------------------------------------------------------------------
// SERVER: the pulse over a scripted match.
// ---------------------------------------------------------------------------
const SERVER_FNS = ['dp_pulse_loop', 'dp_is_elite', 'dp_elite_hold', 'dp_kind', 'dp_str', 'dp_log'];
const SERVER_DEFS = { DP_PULSE_SECS: gscDefs.DP_PULSE_SECS, DP_REV: gscDefs.DP_REV };

function runServer(mutate, script, untilMs) {
  let text = gscText;
  if (mutate) text = mutate(text);
  const pings = [], logs = [], violations = [];
  const ais = [];
  const env = {
    level: { tod_dev: true, zombie_team: 'axis' },
    nowMs: 0,
    GetTime: () => env.nowMs,
    GetAITeamArray: team => { assert.equal(team, 'axis'); return ais.slice(); },
    isdefined: v => v !== undefined && v !== null,
    IsAlive: e => !!(e && e.alive),
    IS_TRUE: v => v !== undefined && v !== null && v !== false && v !== 0,
    PrintLn: s => logs.push(s),
  };
  vm.createContext(env);
  vm.runInContext(build(text, SERVER_FNS, SERVER_DEFS), env);
  const spawnAI = (fields) => {
    const e = Object.assign({ alive: true, spawnMs: env.nowMs, ent: 100 + ais.length }, fields);
    e.GetEntityNumber = () => e.ent;
    e.clientfield__increment = (name) => {
      assert.equal(name, 'tod_dp_ping');
      if (env.nowMs === e.spawnMs) violations.push(`${e.label} pinged on its spawn frame (${env.nowMs})`);
      pings.push({ t: env.nowMs, label: e.label });
    };
    ais.push(e);
    return e;
  };
  ais.push(undefined);   // GetAITeamArray can hand back a freed slot; the loop must skip it
  // Script events (by time), then the pulse, at each 100 ms step - so an event
  // scheduled AT a pulse time lands in the same frame, BEFORE the pulse thread
  // runs: the spawn-frame case.
  const loop = env.dp_pulse_loop();
  let nextWake = 0;
  const first = loop.next();
  nextWake = env.nowMs + first.value * 1000;
  for (env.nowMs = 0; env.nowMs <= untilMs; env.nowMs += 50) {
    for (const ev of script) if (ev.t === env.nowMs) ev.run({ spawnAI, ais, env });
    if (env.nowMs >= nextWake) {
      const r = loop.next();
      nextWake = env.nowMs + r.value * 1000;
    }
  }
  const pingTimes = label => pings.filter(p => p.label === label).map(p => p.t);
  return { pings, pingTimes, logs, violations, env, ais };
}

// The match. Pulses run at 2000, 4000, 6000, ...
const ent = {};
const SCRIPT = [
  // The horde: one emerged zombie, one still rising, one armored sprinter.
  { t: 1000, run: ({ spawnAI }) => { ent.z = spawnAI({ label: 'zombie', completed_emerging_into_playable_area: true }); } },
  { t: 1000, run: ({ spawnAI }) => { ent.riser = spawnAI({ label: 'riser' }); } },
  { t: 1000, run: ({ spawnAI }) => { ent.spr = spawnAI({ label: 'sprinter', completed_emerging_into_playable_area: true, tod_is_sprinter: true }); } },
  // Panzer spawned ON a pulse frame (4000): Ghost + triad on the spawn frame,
  // drop_in from +100 for the tell (2.0 s) -> revealed at 6450.
  { t: 4000, run: ({ spawnAI }) => { ent.panzer = spawnAI({ label: 'panzer', is_boss: true, acc_is_boss: true, acc_is_mini_boss: true }); } },
  { t: 4100, run: () => { ent.panzer.tod_dropping = true; ent.panzer.tod_boss_kind = 'panzer'; } },
  { t: 6450, run: () => { ent.panzer.tod_dropping = undefined; } },
  // Rogue Protector: ignoreme FOR LIFE (archetype_zod_companion), drop_in the
  // same frame as the spawn, revealed 2.35 s later.
  { t: 9950, run: ({ spawnAI }) => { ent.prot = spawnAI({ label: 'protector', is_boss: true, acc_is_boss: true, acc_is_mini_boss: true, tod_boss_kind: 'protector', ignoreme: 1, tod_dropping: true }); } },
  { t: 12300, run: () => { ent.prot.tod_dropping = undefined; } },
  // Hellhound: Hidden + ignoreme until its reveal. (Real hounds reveal at
  // +1.2 s; this one is held 3.4 s so a pulse lands on the hidden state.)
  { t: 13000, run: ({ spawnAI }) => { ent.hound = spawnAI({ label: 'hound', is_boss: true, acc_is_boss: true, acc_is_mini_boss: true, tod_boss_kind: 'hellhound', ignoreme: true }); } },
  { t: 16400, run: () => { ent.hound.ignoreme = false; } },
  // Reaver: the pack stamps completed_emerging_into_playable_area on its spawn
  // frame, and here that frame IS a pulse frame (18000).
  { t: 18000, run: ({ spawnAI }) => { ent.reaver = spawnAI({ label: 'reaver', completed_emerging_into_playable_area: 1, is_boss: true, acc_is_boss: true, acc_is_mini_boss: true, tod_boss_kind: 'reaver' }); } },
  // The Warden King: a Panzer + tod_king.
  { t: 20500, run: ({ spawnAI }) => { ent.king = spawnAI({ label: 'king', is_boss: true, acc_is_boss: true, acc_is_mini_boss: true, tod_boss_kind: 'panzer', tod_king: true, tod_dropping: true }); } },
  { t: 22850, run: () => { ent.king.tod_dropping = undefined; } },
  // The Protector dies; the stuck-watch relocates the Panzer (a second drop).
  { t: 25000, run: () => { ent.prot.alive = false; } },
  { t: 27000, run: () => { ent.panzer.tod_dropping = true; } },
  { t: 29350, run: () => { ent.panzer.tod_dropping = undefined; } },
];
const END = 34000;

function serverRules(r, tag) {
  const pt = r.pingTimes;
  // The horde lane is unchanged.
  assert.deepEqual(pt('zombie'), [2000, 4000, 6000, 8000, 10000, 12000, 14000, 16000, 18000, 20000, 22000, 24000, 26000, 28000, 30000, 32000, 34000], tag + ': emerged zombie every pulse');
  assert.deepEqual(pt('riser'), [], tag + ': a zombie still rising is never pinged');
  assert.equal(pt('sprinter').length, 17, tag + ': armored sprinter rides the horde lane');
  // Every elite is outlined, at the first pulse its rules allow.
  assert.equal(pt('panzer')[0], 8000, tag + ': Panzer first outlined at the first pulse after its reveal');
  assert.equal(pt('protector')[0], 14000, tag + ': Protector outlined despite its lifelong ignoreme');
  assert.equal(pt('hound')[0], 18000, tag + ': hound first outlined after its reveal');
  assert.equal(pt('reaver')[0], 20000, tag + ': Reaver first outlined one pulse after its spawn frame');
  assert.equal(pt('king')[0], 24000, tag + ': Warden King outlined after his landing');
}

// 1. The shipping text.
let r = runServer(null, SCRIPT, END);
serverRules(r, 'shipping');
assert.deepEqual(r.violations, [], 'no counter increment on any spawn frame');
assert.ok(!r.pingTimes('panzer').some(t => t > 27000 && t < 29350), 'no ping while the Panzer is in a relocation drop');
assert.ok(!r.pingTimes('protector').some(t => t > 25000), 'the dead are never pinged');
assert.ok(!r.pingTimes('hound').some(t => t < 16400), 'no hound ping while Hidden');
// Dev evidence: one LOOP_START with the revision, one ELITE_ON per elite with
// its kind, change-gated PULSE lines.
const L = r.logs;
assert.equal(L.filter(s => s.includes('LOOP_START rev=' + JSON.parse(gscDefs.DP_REV))).length, 1, 'LOOP_START carries DP_REV');
for (const k of ['panzer', 'protector', 'hellhound', 'reaver', 'king'])
  assert.equal(L.filter(s => s.includes('ELITE_ON kind=' + k + ' ')).length, 1, 'one ELITE_ON for ' + k);
assert.ok(L.every(s => s.startsWith('[TOD_DP] ms=')), 'every server line is tagged');
assert.ok(L.some(s => /PULSE elites=0 held_new=1 /.test(s)), 'PULSE reports a held new elite');
assert.ok(L.some(s => /held_dropping=1/.test(s)), 'PULSE reports a held dropping elite');
assert.ok(L.some(s => /held_hidden=1/.test(s)), 'PULSE reports a held hidden hound');
const pulses = L.filter(s => s.includes(' PULSE '));
assert.ok(pulses.length < 17, 'PULSE is change-gated, not one per pulse (' + pulses.length + ')');
// tod_dev OFF (the ship state): the pulse runs and prints nothing.
{
  const logs = [];
  const env = { level: { tod_dev: false }, nowMs: 0, GetTime: () => 0, GetAITeamArray: () => [], isdefined: v => v !== undefined, IsAlive: () => true, IS_TRUE: v => !!v, PrintLn: s => logs.push(s) };
  vm.createContext(env);
  vm.runInContext(build(gscText, SERVER_FNS, SERVER_DEFS), env);
  const g = env.dp_pulse_loop(); g.next(); g.next(); g.next();
  assert.deepEqual(logs, [], 'tod_dev OFF prints nothing');
}

// 2. NEGATIVE CONTROLS - each mutation must break the rule it removes.
function mustFail(label, mutate, check) {
  const m = runServer(mutate, SCRIPT, END);   // outside the try, same reason as clientMustFail
  let failed = false;
  try { check(m); } catch (e) { if (!(e instanceof assert.AssertionError)) throw e; failed = true; }
  assert.ok(failed, 'NEGATIVE CONTROL did not fail: ' + label);
}
const mutated = (from, to) => t => { assert.ok(t.includes(from), 'mutation anchor missing: ' + from); return t.replace(from, to); };
// (a) the pre-v19.72 loop: the elite lane was a skip.
mustFail('pre-v19.72 elite skip', mutated('if ( dp_is_elite( z ) )\n            {', 'if ( dp_is_elite( z ) )\n            { continue;'),
  m => serverRules(m, 'old'));
// (b) no first-sighting hold: the Panzer and the Reaver get pinged on their spawn frames.
mustFail('no "new" hold', mutated('if ( !isdefined( z.tod_dp_seen_ms ) )', 'z.tod_dp_seen_ms = GetTime(); if ( false )'),
  m => assert.deepEqual(m.violations, []));
// (c) a general ignoreme gate: the Protector is never outlined.
mustFail('general ignoreme gate', mutated('isdefined( z.tod_boss_kind ) && z.tod_boss_kind == "hellhound" && IS_TRUE( z.ignoreme )', 'IS_TRUE( z.ignoreme )'),
  m => assert.equal(m.pingTimes('protector')[0], 14000));
// (d) no drop-in hold: pinged while Ghosted mid-entrance.
mustFail('no dropping hold', mutated('if ( IS_TRUE( z.tod_dropping ) )', 'if ( false )'),
  m => assert.equal(m.pingTimes('panzer')[0], 8000));

// ---------------------------------------------------------------------------
// CLIENT: the outline per entity.
// ---------------------------------------------------------------------------
const CLIENT_FNS = ['dp_owner_cb', 'dp_any_local_owner', 'dp_ping_cb', 'dp_death_watch', 'dp_note', 'dp_log'];
const CLIENT_DEFS = { DP_REV: cscDefs.DP_REV, DP_DEATH_POLL: cscDefs.DP_DEATH_POLL, DP_LOG_FIRST: cscDefs.DP_LOG_FIRST, DP_LOG_EVERY: cscDefs.DP_LOG_EVERY };

function client(mutate) {
  let text = cscText;
  if (mutate) text = mutate(text);
  const logs = [], threads = [];
  const env = {
    level: {}, nowMs: 0, locals: { 0: { name: 'p1' } },
    GetRealTime: () => env.nowMs,
    GetLocalPlayer: lcn => env.locals[Number(lcn)],
    isdefined: v => v !== undefined && v !== null,
    IsAlive: e => !!(e && e.alive),
    IS_TRUE: v => v !== undefined && v !== null && v !== false && v !== 0,
    PrintLn: s => logs.push(s),
    __pairs: o => Object.entries(o || {}),
    __thread: (self, gen) => { threads.push({ self, gen, wake: env.nowMs }); },
  };
  vm.createContext(env);
  vm.runInContext(build(text, CLIENT_FNS, CLIENT_DEFS), env);
  const actor = (fields) => {
    const a = Object.assign({ alive: true, archetype: 'zombie', ent: 300 + Math.floor(Math.random() * 1000), flag: false, shutdown: false }, fields);
    a.GetEntityNumber = () => a.ent;
    a.duplicate_render__set_dr_flag = (name, on) => { assert.equal(name, 'keyline_active'); a.flag = !!on; };
    a.duplicate_render__update_dr_filters = () => { a.updates = (a.updates || 0) + 1; };
    return a;
  };
  const step = (ms) => {   // advance the client clock, running due threads
    const until = env.nowMs + ms;
    for (; env.nowMs <= until; env.nowMs += 50) {
      for (const th of threads) {
        if (th.done || th.wake > env.nowMs) continue;
        if (th.self.shutdown) { th.done = true; continue; }   // endon( "entityshutdown" )
        const r = th.gen.next();
        if (r.done) th.done = true; else th.wake = env.nowMs + r.value * 1000;
      }
    }
    env.nowMs = until;
  };
  const own = (lcn, on, self) => env.dp_owner_cb(self || env.locals[lcn], lcn, 0, on ? 1 : 0, false, false, 'tod_dp_owner', false);
  const ping = (a, lcn = 0) => env.dp_ping_cb(a, lcn, 0, 1, false, false, 'tod_dp_ping', false);
  return { env, logs, threads, actor, step, own, ping, live: () => threads.filter(t => !t.done).length };
}

// 3. One local player.
let c = client();
let zed = c.actor({});
c.ping(zed);
assert.equal(zed.flag, false, 'no owner -> no outline');
c.own(0, true);
c.ping(zed);
assert.equal(zed.flag, true, 'owner -> outline');
c.ping(zed); c.ping(zed);
assert.equal(c.live(), 1, 'one death watcher per entity, however many pings');
c.step(1000);
assert.equal(zed.flag, true, 'still outlined while alive');
zed.alive = false;
c.step(300);
assert.equal(zed.flag, false, 'outline cleared within a poll of the death');
assert.equal(c.live(), 0, 'the watcher ends at the death');
c.ping(zed);
assert.equal(zed.flag, false, 'a late ping never lights the dead');
// Perk loss: the next ping clears a living enemy.
let hound = c.actor({ archetype: 'zombie_dog' });
c.ping(hound);
assert.equal(hound.flag, true);
c.own(0, false);
c.ping(hound);
assert.equal(hound.flag, false, 'perk loss clears on the next ping');
// Entity removed (the Panzer deletes itself): the watcher ends without touching it.
c.own(0, true);
let panzer = c.actor({ archetype: 'mechz' });
c.ping(panzer);
const updatesBefore = panzer.updates;
panzer.shutdown = true;
c.step(500);
assert.equal(c.live(), 1, 'only the hound watcher is left (the Panzer\'s ended with its entity)');
assert.equal(panzer.updates, updatesBefore, 'nothing is written to a shut-down entity');
// Elite log lines always; the horde's are bounded.
assert.ok(c.logs.some(s => s.includes('ON lc=0 arch=zombie_dog')), 'elite ON logged with its archetype');
assert.ok(c.logs.some(s => /CLEAR_DEATH lc=0 arch=zombie ent=\d+ n=1 watched_ms=\d+/.test(s)), 'horde CLEAR_DEATH carries its count and watch time');
assert.ok(c.logs.every(s => s.startsWith('[TOD_DP_C] rt=')), 'every client line is tagged');
c = client();
c.own(0, true);
for (let i = 0; i < 250; i++) { const a = c.actor({}); c.ping(a); a.alive = false; c.step(250); }
const clears = c.logs.filter(s => s.includes('CLEAR_DEATH'));
assert.equal(clears.length, 3 + 2, 'horde CLEAR_DEATH: the first 3, then every 100th (250 deaths -> 5 lines)');
assert.equal(c.live(), 0, 'no watcher outlives its enemy');
// The local-guard (2026-08-30 lobby leak) still holds: a remote player's field
// on the host's client VM never sets local ownership.
c = client();
c.own(0, true, { name: 'remote' });
zed = c.actor({});
c.ping(zed);
assert.equal(zed.flag, false, 'a remote player\'s ownership never lights this machine');

// 4. Split-screen: the outline is per ENTITY, and both local clients' callbacks
// run on it in the same frame - the last write wins.
c = client();
c.env.locals[1] = { name: 'p2' };
c.own(0, true);              // player 1 owns, player 2 does not
zed = c.actor({});
c.ping(zed, 0); c.ping(zed, 1);
assert.equal(zed.flag, true, 'split-screen: player 1 owning still lights the (shared) outline');
// Player 1's guest seat leaves while it owned the perk: stale entry ignored.
c = client();
c.env.locals[1] = { name: 'p2' };
c.own(1, true);
zed = c.actor({});
c.ping(zed, 0);
assert.equal(zed.flag, true);
delete c.env.locals[1];
c.ping(zed, 0);
assert.equal(zed.flag, false, 'a departed split-screen owner no longer lights anything');

// 5. CLIENT NEGATIVE CONTROLS.
function clientMustFail(label, mutate, check) {
  const k = client(mutate);   // OUTSIDE the try: a mutation that breaks the build must crash the test, not "pass" it
  let failed = false;
  try { check(k); } catch (e) { if (!(e instanceof assert.AssertionError)) throw e; failed = true; }
  assert.ok(failed, 'NEGATIVE CONTROL did not fail: ' + label);
}
const cmut = (from, to) => t => { assert.ok(t.includes(from), 'mutation anchor missing: ' + from); return t.replace(from, to); };
clientMustFail('no death watcher', cmut('self thread dp_death_watch( localClientNum );', ';'), k => {
  k.own(0, true); const a = k.actor({}); k.ping(a); a.alive = false; k.step(500);
  assert.equal(a.flag, false);
});
clientMustFail('per-screen decision (the pre-v19.72 rule)', cmut('on = ( dp_any_local_owner() && IsAlive( self ) );',
  'on = ( isdefined( level.tod_dp_local ) && IS_TRUE( level.tod_dp_local[ localClientNum ] ) && IsAlive( self ) );'), k => {
  k.env.locals[1] = { name: 'p2' }; k.own(0, true); const a = k.actor({}); k.ping(a, 0); k.ping(a, 1);
  assert.equal(a.flag, true);
});
clientMustFail('no departed-seat check', cmut('IS_TRUE( owned ) && isdefined( GetLocalPlayer( lcn ) )', 'IS_TRUE( owned )'), k => {
  k.env.locals[1] = { name: 'p2' }; k.own(1, true); const a = k.actor({}); delete k.env.locals[1]; k.ping(a, 0);
  assert.equal(a.flag, false);
});

// ---------------------------------------------------------------------------
// 6. LOCKSTEP + COPY.
// ---------------------------------------------------------------------------
assert.equal(gscDefs.DP_REV, cscDefs.DP_REV, 'DP_REV must match in both VMs');
const reg = (src, name) => {
  const m = src.match(new RegExp('clientfield::register\\(\\s*"(\\w+)",\\s*"' + name + '",\\s*VERSION_SHIP,\\s*(\\d+),\\s*"(\\w+)"'));
  assert.ok(m, name + ' registration');
  return m.slice(1, 4).join('/');
};
for (const f of ['tod_dp_owner', 'tod_dp_ping'])
  assert.equal(reg(gscSrc, f), reg(cscSrc, f), f + ' registered identically in both VMs');

const promptSrc = fs.readFileSync(PROMPT, 'utf8');
const row = promptSrc.match(/\[\s*"specialty_combat_efficiency"\s*\]\s*=\s*\{\s*"([^"]*)",\s*"([^"]*)"\s*\}/);
assert.ok(row, 'Death Perception PERK_COPY row');
for (const line of [row[1], row[2]]) {
  assert.ok(line.length <= 40, 'card line fits the 40-slot description pool: ' + line);
  assert.ok(/^[A-Z0-9 $-]*$/.test(line), 'card line uses only typeface glyphs: ' + line);
}
assert.ok(/ENEMY/.test(row[1]) && !/HORDE/.test(row[1] + row[2]), 'the card says every enemy, not the horde');
const tableSrc = fs.readFileSync(TABLE, 'utf8');
const desc = tableSrc.match(/name = "DEATH PERCEPTION",[\s\S]*?description = "([^"]*)"/);
assert.ok(desc && /enemy/i.test(desc[1]) && !/horde/i.test(desc[1]), 'the perk table says every enemy');

console.log('PASS: Death Perception outlines every enemy - horde/sprinter unchanged; Panzer, King, Protector, hound, Reaver outlined after their reveal and never on a spawn frame; dead enemies cleared; split-screen any-owner + departed seat; 7 negative controls; lockstep + card copy.');
