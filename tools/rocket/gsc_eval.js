'use strict';
// COPIED 2026-10-02 from Tower of Doom II (tower_of_doom_II_cybercity/tools/sky_ships/gsc_eval.js, session 9c's tool)
// for the rocket ride's gates (tools/rocket/test_rocket_ride.js): the gate RUNS the shipping _tod_rocket.gsc path and
// camera functions, never a copy. Added here: VectorNormalize / VectorDot / VectorCross / Distance / LengthSquared /
// AngleClamp180 / ACos / ATan / Min / Max / Floor / Pow / RotatePoint builtins (case-insensitive lookup).
// A small interpreter for the PURE GSC/CSC the sky fleet's director is written in (docs/192), so its gate runs the
// SHIPPING functions verbatim instead of a hand-written copy that could drift. Subset: functions, locals, if / else,
// for, while, foreach, return / break / continue, = += -= *= /= ++ --, || && == != < > <= >= + - * / %, unary - !,
// calls (incl. ns::name), member access, indexing, strings, numbers, vectors ( a, b, c ), true / false / undefined,
// and the engine builtins the director's math uses (trig in DEGREES, like the engine). No threads, waits or entity
// methods: those stay in the parts of the script the gate checks structurally.
//   const g = gscLoad([cscText, lanesText], defines); g.call('stand_in', [def, org, ang, cam]); g.level
const V = (x, y, z) => { const v = [x, y, z]; v.isVec = true; return v; };
const isVec = v => Array.isArray(v) && v.isVec === true;
const D2R = Math.PI / 180;

function tokenize(src) {
  const toks = [];
  const re = /\s+|\/\/[^\n]*|\/\*[\s\S]*?\*\/|([A-Za-z_][\w]*(?:::[A-Za-z_]\w*)?)|(\d+\.\d*|\.\d+|\d+)|("(?:[^"\\]|\\.)*")|(==|!=|<=|>=|&&|\|\||\+\+|--|\+=|-=|\*=|\/=|[-+*\/%<>=!(){}\[\],;.&])/y;
  let m;
  while (re.lastIndex < src.length) {
    const at = re.lastIndex;
    m = re.exec(src);
    if (!m) throw new Error('gsc_eval: cannot tokenize at ' + JSON.stringify(src.slice(at, at + 40)));
    if (m[1]) toks.push({ t: 'id', v: m[1] });
    else if (m[2]) toks.push({ t: 'num', v: parseFloat(m[2]) });
    else if (m[3]) toks.push({ t: 'str', v: JSON.parse(m[3]) });
    else if (m[4]) toks.push({ t: 'op', v: m[4] });
  }
  toks.push({ t: 'eof', v: '' });
  return toks;
}

function Parser(toks) { this.k = toks; this.i = 0; }
Parser.prototype.peek = function (o = 0) { return this.k[this.i + o]; };
Parser.prototype.is = function (v) { const t = this.k[this.i]; return (t.t === 'op' || t.t === 'id') && t.v === v; };
Parser.prototype.eat = function (v) {
  const t = this.k[this.i];
  if (v !== undefined && !((t.t === 'op' || t.t === 'id') && t.v === v)) throw new Error('gsc_eval: expected ' + v + ' got ' + t.v + ' near token ' + this.i);
  this.i++;
  return t;
};
Parser.prototype.block = function () {
  this.eat('{');
  const body = [];
  while (!this.is('}')) body.push(this.stmt());
  this.eat('}');
  return { k: 'block', body };
};
Parser.prototype.stmt = function () {
  if (this.is('{')) return this.block();
  if (this.is(';')) { this.eat(';'); return { k: 'nop' }; }
  if (this.is('if')) {
    this.eat('if'); this.eat('(');
    const c = this.expr(); this.eat(')');
    const a = this.stmt();
    let b = null;
    if (this.is('else')) { this.eat('else'); b = this.stmt(); }
    return { k: 'if', c, a, b };
  }
  if (this.is('for')) {
    this.eat('for'); this.eat('(');
    const init = this.is(';') ? null : this.expr(); this.eat(';');
    const cond = this.is(';') ? null : this.expr(); this.eat(';');
    const step = this.is(')') ? null : this.expr(); this.eat(')');
    return { k: 'for', init, cond, step, body: this.stmt() };
  }
  if (this.is('while')) {
    this.eat('while'); this.eat('(');
    const c = this.expr(); this.eat(')');
    return { k: 'while', c, body: this.stmt() };
  }
  if (this.is('foreach')) {
    this.eat('foreach'); this.eat('(');
    let key = null, val = this.eat().v;
    if (this.is(',')) { this.eat(','); key = val; val = this.eat().v; }
    this.eat('in');
    const arr = this.expr(); this.eat(')');
    return { k: 'foreach', key, val, arr, body: this.stmt() };
  }
  if (this.is('return')) {
    this.eat('return');
    const e = this.is(';') ? null : this.expr();
    this.eat(';');
    return { k: 'return', e };
  }
  if (this.is('break')) { this.eat('break'); this.eat(';'); return { k: 'break' }; }
  if (this.is('continue')) { this.eat('continue'); this.eat(';'); return { k: 'continue' }; }
  const e = this.expr();
  this.eat(';');
  return { k: 'expr', e };
};
Parser.prototype.expr = function () { return this.assign(); };
Parser.prototype.assign = function () {
  const l = this.bin(0);
  for (const op of ['=', '+=', '-=', '*=', '/=']) if (this.is(op)) { this.eat(op); return { k: 'assign', op, l, r: this.assign() }; }
  return l;
};
const LEVELS = [['||'], ['&&'], ['==', '!='], ['<', '>', '<=', '>='], ['+', '-'], ['*', '/', '%']];
Parser.prototype.bin = function (lv) {
  if (lv >= LEVELS.length) return this.unary();
  let l = this.bin(lv + 1);
  for (;;) {
    const op = LEVELS[lv].find(o => this.is(o));
    if (!op) return l;
    this.eat(op);
    l = { k: 'bin', op, l, r: this.bin(lv + 1) };
  }
};
Parser.prototype.unary = function () {
  if (this.is('-')) { this.eat('-'); return { k: 'neg', e: this.unary() }; }
  if (this.is('!')) { this.eat('!'); return { k: 'not', e: this.unary() }; }
  return this.postfix();
};
Parser.prototype.postfix = function () {
  let e = this.primary();
  for (;;) {
    if (this.is('(') && (e.k === 'name')) { e = { k: 'call', f: e.v, args: this.args() }; continue; }
    if (this.is('[')) { this.eat('['); const ix = this.expr(); this.eat(']'); e = { k: 'index', o: e, ix }; continue; }
    if (this.is('.')) { this.eat('.'); e = { k: 'member', o: e, f: this.eat().v }; continue; }
    if (this.is('++') || this.is('--')) { const op = this.eat().v; e = { k: 'incdec', op, e }; continue; }
    return e;
  }
};
Parser.prototype.args = function () {
  this.eat('(');
  const a = [];
  while (!this.is(')')) { a.push(this.expr()); if (this.is(',')) this.eat(','); }
  this.eat(')');
  return a;
};
Parser.prototype.primary = function () {
  const t = this.peek();
  if (t.t === 'num') { this.i++; return { k: 'lit', v: t.v }; }
  if (t.t === 'str') { this.i++; return { k: 'lit', v: t.v }; }
  if (t.t === 'id') {
    this.i++;
    if (t.v === 'true') return { k: 'lit', v: true };
    if (t.v === 'false') return { k: 'lit', v: false };
    if (t.v === 'undefined') return { k: 'lit', v: undefined };
    return { k: 'name', v: t.v };
  }
  if (this.is('[')) { this.eat('['); this.eat(']'); return { k: 'newarr' }; }
  if (this.is('(')) {
    this.eat('(');
    const a = this.expr();
    if (this.is(',')) {                                          // a vector literal ( x, y, z )
      this.eat(','); const b = this.expr(); this.eat(','); const c = this.expr(); this.eat(')');
      return { k: 'vec', a, b, c };
    }
    this.eat(')');
    return a;
  }
  throw new Error('gsc_eval: unexpected ' + t.v + ' at token ' + this.i);
};

const BREAK = Symbol('break'), CONTINUE = Symbol('continue');
class Return { constructor(v) { this.v = v; } }

function num(x) { return typeof x === 'boolean' ? (x ? 1 : 0) : x; }
function arith(op, a, b) {
  a = num(a); b = num(b);
  if (isVec(a) || isVec(b)) {
    const A = isVec(a) ? a : null, B = isVec(b) ? b : null;
    if (op === '+' && A && B) return V(A[0] + B[0], A[1] + B[1], A[2] + B[2]);
    if (op === '-' && A && B) return V(A[0] - B[0], A[1] - B[1], A[2] - B[2]);
    if (op === '*' && A && !B) return V(A[0] * b, A[1] * b, A[2] * b);
    if (op === '*' && B && !A) return V(B[0] * a, B[1] * a, B[2] * a);
    if (op === '/' && A && !B) return V(A[0] / b, A[1] / b, A[2] / b);
    if (op === '==' && A && B) return A[0] === B[0] && A[1] === B[1] && A[2] === B[2];
    const error = new Error('gsc_eval: vector ' + op + ' not supported; operands ' + fmt(a) + ' and ' + fmt(b));
    error.operands = [a, b];
    throw error;
  }
  switch (op) {
    case '+': return (typeof a === 'string' || typeof b === 'string') ? String(fmt(a)) + String(fmt(b)) : a + b;
    case '-': return a - b;
    case '*': return a * b;
    case '/': return a / b;
    case '%': return a % b;
    case '<': return a < b; case '>': return a > b; case '<=': return a <= b; case '>=': return a >= b;
    case '==': return a === b; case '!=': return a !== b;
  }
  throw new Error('gsc_eval: op ' + op);
}
function fmt(v) { return isVec(v) ? '(' + v.join(', ') + ')' : v; }
function truthy(v) { return !!num(v); }

function angleVectors(ang) {
  const sp = Math.sin(ang[0] * D2R), cp = Math.cos(ang[0] * D2R), sy = Math.sin(ang[1] * D2R), cy = Math.cos(ang[1] * D2R);
  const sr = Math.sin(ang[2] * D2R), cr = Math.cos(ang[2] * D2R);
  return {                                                            // the engine's AngleVectors (id Tech convention)
    f: V(cp * cy, cp * sy, -sp),
    r: V(-sr * sp * cy + cr * sy, -sr * sp * sy - cr * cy, -sr * cp),
    u: V(cr * sp * cy + sr * sy, cr * sp * sy - sr * cy, cr * cp),
  };
}

function gscLoad(texts, defines, opts = {}) {
  const funcs = {};
  for (const [ns, text] of texts) {
    let src = text.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '');
    src = src.replace(/^\s*#[^\n]*$/gm, '');                                     // #using / #insert / #precache / #define
    for (const [k, v] of Object.entries(defines)) src = src.replace(new RegExp('\\b' + k + '\\b', 'g'), '(' + v + ')');
    const re = /\bfunction\s+(\w+)\s*\(([^)]*)\)\s*\{/g;
    let m;
    while ((m = re.exec(src))) {
      let depth = 1, j = re.lastIndex;
      while (depth) { if (src[j] === '{') depth++; else if (src[j] === '}') depth--; j++; }
      const body = src.slice(re.lastIndex - 1, j);
      re.lastIndex = j;
      const params = m[2].split(',').map(s => s.trim()).filter(Boolean);
      funcs[ns + '::' + m[1]] = { params, src: body, ns };
      if (!funcs[m[1]] || ns === texts[0][0]) funcs[m[1]] = funcs[ns + '::' + m[1]];
    }
  }
  const rnd = opts.random || Math.random;
  const level = {};
  const B = {
    Sqrt: x => Math.sqrt(x), Sin: x => Math.sin(x * D2R), Cos: x => Math.cos(x * D2R), abs: x => Math.abs(x), Abs: x => Math.abs(x),
    int: x => Math.trunc(x), Length: v => Math.hypot(v[0], v[1], v[2]),
    AnglesToForward: a => angleVectors(a).f, AnglesToRight: a => angleVectors(a).r, AnglesToUp: a => angleVectors(a).u,
    VectorToAngles: v => { let y = Math.atan2(v[1], v[0]) / D2R; if (y < 0) y += 360; return V(-Math.atan2(v[2], Math.hypot(v[0], v[1])) / D2R, y, 0); },
    RandomFloatRange: (a, b) => a + (b - a) * rnd(), RandomInt: n => Math.floor(rnd() * n), RandomIntRange: (a, b) => a + Math.floor(rnd() * (b - a)),
    SpawnStruct: () => ({}), array: (...a) => a, isdefined: x => x !== undefined, IsArray: x => Array.isArray(x),
  };
  const nrm = v => { const l = Math.hypot(v[0], v[1], v[2]); return l > 1e-9 ? V(v[0] / l, v[1] / l, v[2] / l) : V(0, 0, 0); };
  Object.assign(B, {
    VectorNormalize: nrm,
    VectorDot: (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2],
    VectorCross: (a, b) => V(a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]),
    Distance: (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]),
    DistanceSquared: (a, b) => (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2,
    LengthSquared: v => v[0] * v[0] + v[1] * v[1] + v[2] * v[2],
    AngleClamp180: a => { let x = ((a % 360) + 360) % 360; if (x > 180) x -= 360; return x; },
    ACos: x => Math.acos(Math.max(-1, Math.min(1, x))) / D2R, ATan: x => Math.atan(x) / D2R,
    Min: (a, b) => Math.min(a, b), Max: (a, b) => Math.max(a, b), Floor: x => Math.floor(x), Pow: (a, b) => Math.pow(a, b),
    // the engine's RotatePoint: the vector expressed in the frame `ang` (x along forward, y along left, z along up)
    RotatePoint: (p, a) => { const f = angleVectors(a); return V(p[0] * f.f[0] - p[1] * f.r[0] + p[2] * f.u[0],
                                                              p[0] * f.f[1] - p[1] * f.r[1] + p[2] * f.u[1],
                                                              p[0] * f.f[2] - p[1] * f.r[2] + p[2] * f.u[2]); },
  });
  Object.assign(B, opts.builtins || {});
  const BL = {};
  for (const k of Object.keys(B)) BL[k.toLowerCase()] = B[k];                    // GSC builtins are case-insensitive
  function call(name, args) {
    const bl = BL[name.toLowerCase()];
    if (bl && !funcs[name]) return bl(...args);
    const f = funcs[name];
    if (!f) throw new Error('gsc_eval: unknown function ' + name);
    if (!f.ast) f.ast = new Parser(tokenize(f.src)).block();
    const env = Object.create(null);
    f.params.forEach((p, i) => { env[p.toLowerCase()] = args[i]; });
    try { exec(f.ast, env, f.ns); } catch (e) { if (e instanceof Return) return e.v; throw e; }
    return undefined;
  }
  // Native CSC local names are case-insensitive. In particular d and D share
  // one slot: treating them as JS names concealed the 2026-09-29 rock failure.
  // Preserve string keys and builtin/member spellings; only local bindings
  // are canonicalized here, including parameters and foreach destinations.
  function lookup(env, n) { n = n.toLowerCase(); if (n === 'level') return level; return env[n]; }
  function exec(s, env, ns) {
    switch (s.k) {
      case 'block': for (const x of s.body) { const r = exec(x, env, ns); if (r === BREAK || r === CONTINUE) return r; } return;
      case 'nop': return;
      case 'expr': ev(s.e, env, ns); return;
      case 'if': if (truthy(ev(s.c, env, ns))) return exec(s.a, env, ns); if (s.b) return exec(s.b, env, ns); return;
      case 'for':
        if (s.init) ev(s.init, env, ns);
        for (let n = 0; !s.cond || truthy(ev(s.cond, env, ns)); n++) {
          if (n > 1e7) throw new Error('gsc_eval: runaway loop');
          const r = exec(s.body, env, ns);
          if (r === BREAK) break;
          if (s.step) ev(s.step, env, ns);
        }
        return;
      case 'while':
        for (let n = 0; truthy(ev(s.c, env, ns)); n++) {
          if (n > 1e7) throw new Error('gsc_eval: runaway loop');
          if (exec(s.body, env, ns) === BREAK) break;
        }
        return;
      case 'foreach': {
        const a = ev(s.arr, env, ns);
        for (const key of Object.keys(a)) {
          if (s.key) env[s.key.toLowerCase()] = /^\d+$/.test(key) ? +key : key;
          env[s.val.toLowerCase()] = a[key];
          if (exec(s.body, env, ns) === BREAK) break;
        }
        return;
      }
      case 'return': throw new Return(s.e ? ev(s.e, env, ns) : undefined);
      case 'break': return BREAK;
      case 'continue': return CONTINUE;
    }
    throw new Error('gsc_eval: statement ' + s.k);
  }
  function store(target, val, env, ns) {
    if (target.k === 'name') { env[target.v.toLowerCase()] = val; return; }
    if (target.k === 'member') { ev(target.o, env, ns)[target.f] = val; return; }
    if (target.k === 'index') { const o = ev(target.o, env, ns); o[ev(target.ix, env, ns)] = val; return; }
    throw new Error('gsc_eval: cannot assign to ' + target.k);
  }
  function ev(e, env, ns) {
    switch (e.k) {
      case 'lit': return e.v;
      case 'name': return lookup(env, e.v);
      case 'vec': return V(num(ev(e.a, env, ns)), num(ev(e.b, env, ns)), num(ev(e.c, env, ns)));
      case 'newarr': return [];
      case 'neg': { const v = ev(e.e, env, ns); return isVec(v) ? V(-v[0], -v[1], -v[2]) : -num(v); }
      case 'not': return !truthy(ev(e.e, env, ns));
      case 'bin':
        if (e.op === '&&') return truthy(ev(e.l, env, ns)) && truthy(ev(e.r, env, ns));
        if (e.op === '||') return truthy(ev(e.l, env, ns)) || truthy(ev(e.r, env, ns));
        return arith(e.op, ev(e.l, env, ns), ev(e.r, env, ns));
      case 'call': {
        const name = e.f.includes('::') ? e.f : (funcs[ns + '::' + e.f] ? ns + '::' + e.f : e.f);
        return call(name, e.args.map(a => ev(a, env, ns)));
      }
      case 'member': {
        const o = ev(e.o, env, ns);
        if (e.f === 'size' && (Array.isArray(o) || typeof o === 'string')) return Array.isArray(o) ? Object.keys(o).length : o.length;
        if (o === undefined || o === null) throw new Error('gsc_eval: .' + e.f + ' of undefined');
        return o[e.f];
      }
      case 'index': { const o = ev(e.o, env, ns); if (o === undefined) throw new Error('gsc_eval: index of undefined'); return o[ev(e.ix, env, ns)]; }
      case 'assign': {
        let val = ev(e.r, env, ns);
        if (e.op !== '=') val = arith(e.op[0], ev(e.l, env, ns), val);
        store(e.l, val, env, ns);
        return val;
      }
      case 'incdec': { const v = num(ev(e.e, env, ns)); store(e.e, e.op === '++' ? v + 1 : v - 1, env, ns); return v; }
    }
    throw new Error('gsc_eval: expression ' + e.k);
  }
  return { call, level, funcs, V, angleVectors };
}

module.exports = { gscLoad, V, isVec, angleVectors };
