'use strict';
// tools/lint_tod_init_flags.js - NO FLAG IS READ BEFORE IT EXISTS ON A SYSTEM __init__'S PATH.
//
// THE CRASH THIS GATES (paid twice, both times in _tod_powerups.gsc):
//     server script error / cannot cast undefined to bool /
//     Terminal script error / scripts/shared/flag_shared.gsc:0
//   2026-08-25  pap_power_hint   read "power_on" with no exists check (its comment)
//   2026-09-30  dev_blood_shelf  `level flag::wait_till( "initial_blackscreen_passed" )`
//               as its first statement, threaded from __init__ - the dev Zombie Blood
//               shelf. Every load died, dev on or off: the read came before the dev check.
//               Console stack: flag_shared.gsc <- _tod_powerups.gsc:946 <- :153 (__init__)
//               <- system_shared.gsc <- callbacks_shared.gsc.
//
// WHY IT IS NOT A RACE: stock runs every REGISTER_SYSTEM pre-func (__init__) from
// CodeCallback_PreInitialization, "Called by code before level main but after
// autoexecs" (callbacks_shared.gsc). Stock creates its own flags in main
// (_zm.gsc init() -> init_flags(): initial_blackscreen_passed, power_on, ...).
// flag::get returns self.flag[ name ] - undefined for a flag nobody created - and every
// flag read negates or branches on it (wait_till is `while ( !get( name ) )`), so the
// cast fatals the server. A thread started from __init__ runs synchronously up to its
// first wait, so a flag read on that stretch kills EVERY load.
//
// THE RULE: on the synchronous path of a system pre-func - its own body, plus every
// function in the same file it calls or threads, each up to that function's first
// yield, followed recursively - a flag may be read (get / get_any / toggle / every
// wait_till*) only after one of these appears earlier on that path:
//     flag::exists( <same name> )     the idiom: while ( !( level flag::exists( X ) ) ) wait 0.05;
//     flag::init( <same name> )       created on that same path
//     isdefined( level.flag[ <same name> ] )
//
// LIMITS - a pass means exactly this and no more:
//   - a path ends at the first yield TOKEN whatever the control flow, so a wait inside
//     an `if` ends it; a direct (not threaded) call into a function that can yield ends
//     the caller's path at that call
//   - only calls into THIS file (bare or own-namespace) are followed
//   - a flag named by a non-literal expression must match an exists() of the same text
//   - post-funcs (__main__) and the init() chains main calls are out of scope: by then
//     main has created stock's flags
//
// Every run proves the analyzer on synthetic cases first (both real crash shapes must
// fire, every guarded idiom must pass), then reads the tree. Exit 1 on either failure.
// Usage: node tools/lint_tod_init_flags.js
const fs = require('fs'), path = require('path');

const REPO = path.join(__dirname, '..');
const SCRIPTS = path.join(REPO, 'scripts');

// Every flag_shared function that reads self.flag[ name ] (stock flag_shared.gsc).
const READS = new Set([
  'get', 'get_any', 'toggle',
  'wait_till', 'wait_till_timeout', 'wait_till_all', 'wait_till_all_timeout',
  'wait_till_any', 'wait_till_any_timeout', 'wait_till_clear', 'wait_till_clear_timeout',
  'wait_till_clear_all', 'wait_till_clear_all_timeout', 'wait_till_clear_any', 'wait_till_clear_any_timeout',
]);
// A token that suspends the thread. `wait_till` is NOT one: it reads before it waits.
const YIELD_RE = /\b(?:wait|waittillframeend|WAIT_SERVER_FRAME|wait_network_frame|waittill\w*)\b/;

// Blank comments (keep newlines) -> src. Also blank string BODIES -> code. Same length,
// so an index into one is an index into the other: structure from code, names from src.
function views(text) {
  let src = '', code = '', i = 0;
  const n = text.length;
  while (i < n) {
    const c = text[i], d = text[i + 1];
    if (c === '/' && d === '/') { while (i < n && text[i] !== '\n') { src += ' '; code += ' '; i++; } continue; }
    if (c === '/' && d === '*') {
      src += '  '; code += '  '; i += 2;
      while (i < n && !(text[i] === '*' && text[i + 1] === '/')) { const k = text[i] === '\n' ? '\n' : ' '; src += k; code += k; i++; }
      if (i < n) { src += '  '; code += '  '; i += 2; }
      continue;
    }
    if (c === '"') {
      src += '"'; code += '"'; i++;
      while (i < n && text[i] !== '"' && text[i] !== '\n') {
        if (text[i] === '\\' && i + 1 < n) { src += text[i] + text[i + 1]; code += '  '; i += 2; continue; }
        src += text[i]; code += ' '; i++;
      }
      if (i < n && text[i] === '"') { src += '"'; code += '"'; i++; }
      continue;
    }
    src += c; code += c; i++;
  }
  return { src, code };
}

function matchClose(code, open, oc, cc) {
  let depth = 0;
  for (let i = open; i < code.length; i++) {
    if (code[i] === oc) depth++;
    else if (code[i] === cc) { depth--; if (depth === 0) return i; }
  }
  return -1;
}

// Top-level argument spans of a call whose '(' is at `open`.
function argSpans(code, open) {
  const close = matchClose(code, open, '(', ')');
  if (close < 0) return [];
  const spans = []; let depth = 0, start = open + 1;
  for (let i = open + 1; i < close; i++) {
    const c = code[i];
    if (c === '(' || c === '[' || c === '{') depth++;
    else if (c === ')' || c === ']' || c === '}') depth--;
    else if (c === ',' && depth === 0) { spans.push([start, i]); start = i + 1; }
  }
  spans.push([start, close]);
  return spans;
}

function parseDefines(src, into) {
  const re = /^[ \t]*#define[ \t]+(\w+)[ \t]+"((?:[^"\\\n]|\\.)*)"/gm; let m;
  while ((m = re.exec(src))) into.set(m[1], m[2]);
}

function parseFile(text, name, readInsert) {
  const { src, code } = views(text);
  const defines = new Map();
  parseDefines(src, defines);
  if (readInsert) {
    const ins = /^[ \t]*#insert[ \t]+([\w\\\/.]+\.gsh)/gm; let m;
    while ((m = ins.exec(src))) {
      const t = readInsert(m[1]);
      if (t) parseDefines(views(t).src, defines);
    }
  }
  const nsm = /#namespace\s+(\w+)\s*;/.exec(code);
  const ns = nsm ? nsm[1] : null;
  const fns = new Map();
  const fre = /\bfunction\s+(?:(?:autoexec|private)\s+)*(\w+)\s*\(/g; let m;
  while ((m = fre.exec(code))) {
    const pOpen = m.index + m[0].length - 1;
    const pClose = matchClose(code, pOpen, '(', ')');
    if (pClose < 0) continue;
    const bOpen = code.indexOf('{', pClose);
    if (bOpen < 0) continue;
    const between = code.slice(pClose + 1, bOpen);
    if (/[^\s]/.test(between)) continue;   // a prototype or something else, not a body
    const bClose = matchClose(code, bOpen, '{', '}');
    if (bClose < 0) continue;
    if (!fns.has(m[1])) fns.set(m[1], { name: m[1], start: bOpen + 1, end: bClose });
    fre.lastIndex = bClose;
  }
  const pre = [];
  const sre = /\bREGISTER_SYSTEM(?:_EX)?\s*\(\s*"[^"]*"\s*,\s*&\s*(?:\w+\s*::\s*)?(\w+)/g;
  while ((m = sre.exec(code))) pre.push(m[1]);
  const rre = /\bsystem\s*::\s*register\s*\(\s*"[^"]*"\s*,\s*&\s*(?:\w+\s*::\s*)?(\w+)/g;
  while ((m = rre.exec(code))) pre.push(m[1]);
  return { name, text, src, code, defines, ns, fns, pre };
}

function lineOf(text, idx) { let l = 1; for (let i = 0; i < idx && i < text.length; i++) if (text[i] === '\n') l++; return l; }
function norm(s) { return s.replace(/\s+/g, ' ').trim(); }

// Flag names in an argument: every string literal; else a define; else the expression text.
function namesIn(f, a, b) {
  const s = f.src.slice(a, b);
  const lits = [...s.matchAll(/"((?:[^"\\]|\\.)*)"/g)].map(x => x[1]);
  if (lits.length) return lits;
  const t = norm(s);
  if (/^\w+$/.test(t) && f.defines.has(t)) return [f.defines.get(t)];
  return t ? ['<expr> ' + t] : [];
}

function hasYield(f, fn) { return YIELD_RE.test(f.code.slice(fn.start, fn.end)); }

function scanPath(f, fnName, known, stack, out, depth) {
  const fn = f.fns.get(fnName);
  if (!fn || depth > 12 || stack.includes(fnName)) return;
  const here = stack.concat(fnName);
  const body = f.code.slice(fn.start, fn.end);
  const y = YIELD_RE.exec(body);
  const stop = fn.start + (y ? y.index : body.length);
  const ev = /\b(?:(\w+)\s*::\s*)?(\w+)\s*\(/g;
  ev.lastIndex = fn.start;
  let m;
  while ((m = ev.exec(f.code)) && m.index < stop) {
    const ns = m[1], name = m[2];
    const open = m.index + m[0].length - 1;
    if (ns === 'flag') {
      const spans = argSpans(f.code, open);
      if ((name === 'exists' || name === 'init') && spans[0]) {
        for (const nm of namesIn(f, spans[0][0], spans[0][1])) known.add(nm);
      } else if (READS.has(name)) {
        const sp = spans[name.endsWith('_timeout') ? 1 : 0];
        if (sp) for (const nm of namesIn(f, sp[0], sp[1]))
          if (!known.has(nm)) out.push({ file: f.name, line: lineOf(f.text, m.index), path: here.join(' > '), op: 'flag::' + name, flag: nm });
      }
      continue;
    }
    if (!ns && /^isdefined$/i.test(name)) {
      const spans = argSpans(f.code, open);
      if (spans[0] && /\.flag\s*\[/.test(f.code.slice(spans[0][0], spans[0][1])))
        for (const nm of namesIn(f, spans[0][0], spans[0][1])) known.add(nm);
      continue;
    }
    if ((!ns || ns === f.ns) && f.fns.has(name) && name !== fnName) {
      const threaded = /\bthread\s+$/.test(f.code.slice(Math.max(0, m.index - 16), m.index));
      scanPath(f, name, new Set(known), here, out, depth + 1);
      if (!threaded && hasYield(f, f.fns.get(name))) break;   // the call may suspend this thread
    }
  }
}

function lintFile(f) {
  const out = [];
  for (const p of f.pre) if (f.fns.has(p)) scanPath(f, p, new Set(), [], out, 0);
  return out;
}

// ---------------------------------------------------------------- self-test
const HEAD = '#namespace t;\nREGISTER_SYSTEM( "t", &__init__, undefined )\n';
const CASES = [
  { why: 'the 2026-09-30 crash: threaded from __init__, bare wait_till', want: ['initial_blackscreen_passed'], src: HEAD +
    'function __init__() { level thread shelf(); }\n' +
    'function shelf() { level endon( "end_game" ); level flag::wait_till( "initial_blackscreen_passed" ); if ( !IS_TRUE( level.tod_dev ) ) return; }' },
  { why: 'the exists-poll idiom passes', want: [], src: HEAD +
    'function __init__() { level thread shelf(); }\n' +
    'function shelf() { level endon( "end_game" ); while ( !( level flag::exists( "initial_blackscreen_passed" ) ) ) wait 0.05; level flag::wait_till( "initial_blackscreen_passed" ); }' },
  { why: 'the 2026-08-25 lane: a bare get of "power_on"', want: ['power_on'], src: HEAD +
    'function __init__() { level thread hint(); }\nfunction hint() { if ( level flag::get( "power_on" ) ) return; }' },
  { why: 'exists() && get() passes', want: [], src: HEAD +
    'function __init__() { level thread hint(); }\nfunction hint() { if ( level flag::exists( "power_on" ) && level flag::get( "power_on" ) ) return; }' },
  { why: 'a flag created earlier on the path passes', want: [], src: HEAD +
    'function __init__() { level flag::init( "tod_x" ); level thread w(); }\nfunction w() { level flag::wait_till( "tod_x" ); }' },
  { why: 'isdefined( level.flag[ X ] ) counts as exists', want: [], src: HEAD +
    'function __init__() { level thread w(); }\nfunction w() { if ( isdefined( level.flag[ "power_on" ] ) && level flag::get( "power_on" ) ) return; }' },
  { why: 'a read after the first wait is out of scope', want: [], src: HEAD +
    'function __init__() { level thread w(); }\nfunction w() { wait 0.05; level flag::wait_till( "initial_blackscreen_passed" ); }' },
  { why: 'a helper on the path is followed', want: ['power_on'], src: HEAD +
    'function __init__() { level thread w(); }\nfunction w() { helper(); }\nfunction helper() { level flag::get( "power_on" ); }' },
  { why: 'an own-namespace call is followed', want: ['power_on'], src: HEAD +
    'function __init__() { level thread t::w(); }\nfunction w() { level flag::wait_till( "power_on" ); }' },
  { why: 'a define names the flag', want: ['power_on'], src: '#define TOD_F "power_on"\n' + HEAD +
    'function __init__() { level thread w(); }\nfunction w() { level flag::wait_till( TOD_F ); }' },
  { why: 'a _timeout form reads its second argument', want: ['power_on'], src: HEAD +
    'function __init__() { level thread w(); }\nfunction w() { level flag::wait_till_timeout( 5, "power_on" ); }' },
  { why: 'an array form reads every name', want: ['a_flag', 'b_flag'], src: HEAD +
    'function __init__() { level thread w(); }\nfunction w() { level flag::wait_till_any( array( "a_flag", "b_flag" ) ); }' },
  { why: '"wait" inside a string or a comment does not end the path', want: ['power_on'], src: HEAD +
    'function __init__() { level thread w(); }\nfunction w() { log( "please wait" ); // wait here\n level flag::get( "power_on" ); }' },
  { why: 'a direct call into a yielding helper ends the caller\'s path', want: [], src: HEAD +
    'function __init__() { level thread w(); }\nfunction w() { wait_exists(); level flag::wait_till( "power_on" ); }\n' +
    'function wait_exists() { while ( !( level flag::exists( "power_on" ) ) ) wait 0.05; }' },
  { why: 'a threaded yielding helper does NOT end the caller\'s path', want: ['power_on'], src: HEAD +
    'function __init__() { level thread w(); }\nfunction w() { level thread other(); level flag::get( "power_on" ); }\nfunction other() { wait 1; }' },
  { why: 'a post-func (__main__) path is out of scope', want: [], src: '#namespace t;\nREGISTER_SYSTEM_EX( "t", &__init__, &__main__, undefined )\n' +
    'function __init__() {}\nfunction __main__() { level thread w(); }\nfunction w() { level flag::wait_till( "power_on" ); }' },
];

function selftest() {
  let bad = 0;
  for (const c of CASES) {
    const got = lintFile(parseFile(c.src, 'case')).map(v => v.flag).sort();
    const want = c.want.slice().sort();
    if (JSON.stringify(got) !== JSON.stringify(want)) {
      bad++;
      console.log('[init-flags] SELFTEST FAIL: ' + c.why + '\n    want ' + JSON.stringify(want) + '  got ' + JSON.stringify(got));
    }
  }
  return bad;
}

// ---------------------------------------------------------------- the tree
function walk(d, acc) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p, acc);
    else if (/\.(gsc|csc)$/i.test(e.name)) acc.push(p);
  }
  return acc;
}

function main() {
  const bad = selftest();
  if (bad) { console.log('[init-flags] FAIL: the analyzer missed ' + bad + ' of ' + CASES.length + ' known shapes - fix the lint before trusting it.'); process.exit(1); }
  const readInsert = (rel) => {
    const p = path.join(REPO, rel.replace(/\\/g, '/'));
    try { return fs.readFileSync(p, 'utf8'); } catch (e) { return null; }
  };
  const files = walk(SCRIPTS, []);
  let systems = 0; const all = [];
  for (const p of files) {
    const f = parseFile(fs.readFileSync(p, 'utf8'), path.relative(REPO, p).replace(/\\/g, '/'), readInsert);
    systems += f.pre.filter(x => f.fns.has(x)).length;
    all.push(...lintFile(f));
  }
  console.log('[init-flags] selftest ' + CASES.length + '/' + CASES.length + ' shapes; scanned ' + files.length + ' scripts, ' + systems + ' system pre-funcs.');
  if (all.length) {
    for (const v of all) console.log('[init-flags] ' + v.file + ':' + v.line + '  ' + v.op + '( "' + v.flag + '" ) on the __init__ path ' + v.path + ' with no flag::exists first');
    console.log('[init-flags] FAIL: ' + all.length + ' flag read(s) can run before the flag exists. A system __init__ runs BEFORE main creates stock\'s flags - poll first:');
    console.log('[init-flags]     while ( !( level flag::exists( "<name>" ) ) ) wait 0.05;');
    process.exit(1);
  }
  console.log('[init-flags] OK: no flag is read before it can exist on any system __init__ path.');
}

if (require.main === module) main();
else module.exports = { parseFile, lintFile };
