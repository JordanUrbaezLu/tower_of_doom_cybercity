// Cross-check every constant the armory page STATES against the shipping code.
//
// TWO CLAIM SOURCES, and the second one was added 2026-09-08 because it was
// missing the exact drift it should have caught: the page said
// `LEDGER_GUARD 223` for a week while the generator held 235, and nothing here
// looked at it, because the guard is stated in the KNOBS table's constant
// column rather than in a domain's tune: string. A knob is a constant the page
// states; it gets checked like one now.
//
// TWO SOURCES OF TRUTH TOO: `#define NAME value` under scripts/zm, and
// `const NAME = value` in the twin generator, which is where every ledger /
// normalization / class-multiplier number actually lives.
const fs = require('fs');
const path = 'docs/armory.html';
const s = fs.readFileSync(path, 'utf8');
const page = s;   // the page text, for the gates appended below

const dir = 'scripts/zm/zm_tower_of_doom/';
const files = fs.readdirSync(dir).filter(f => f.endsWith('.gsc') || f.endsWith('.gsh'));
let src = '';
for (const f of files) src += fs.readFileSync(dir + f, 'utf8') + '\n';
// entry script + any shared gsh
try { src += fs.readFileSync('scripts/zm/zm_tower_of_doom.gsc', 'utf8'); } catch (e) {}
try { src += fs.readFileSync('scripts/zm/_zm_perk_wisp_tea.gsh', 'utf8'); } catch (e) {}
let gen = '';
try { gen = fs.readFileSync('tools/gen_tod_twins.js', 'utf8'); } catch (e) {}

const claims = [];
function harvest(text, where) {
  for (const part of text.split(/\s+\/\s+/)) {
    const g = part.trim().match(/^([A-Z][A-Z0-9_]{3,})\s+([0-9.]+)$/);
    if (g) claims.push([g[1], g[2], where]);
  }
}

// (a) every tune:"..." string on the page — one per upgrade domain
{
  const re = /tune:"([^"]+)"/g;
  let m;
  while ((m = re.exec(s))) harvest(m[1], 'tune');
}

// (b) the KNOBS table's constant column. Sliced and evaluated rather than
// regexed, because the descriptions are prose full of slashes and digits and
// a pattern loose enough to find the column would match half of them.
{
  const i = s.indexOf('const KNOBS = [');
  if (i < 0) {
    console.log('  WARN  no KNOBS array found — knob constants unchecked');
  } else {
    const open = s.indexOf('[', i);
    let depth = 0, end = -1;
    for (let j = open; j < s.length; j++) {
      if (s[j] === '[') depth++;
      else if (s[j] === ']') { depth--; if (!depth) { end = j + 1; break; } }
    }
    try {
      const rows = new Function('return ' + s.slice(open, end))();
      for (const r of rows) if (Array.isArray(r) && typeof r[2] === 'string') harvest(r[2], 'knob');
    } catch (e) {
      console.log('  WARN  KNOBS array did not evaluate: ' + e.message);
    }
  }
}

let ok = 0, bad = 0;
const missing = [];
for (const [name, val, where] of claims) {
  const d = src.match(new RegExp('#define[ \\t]+' + name + '[ \\t]+([0-9.]+)'))
         || gen.match(new RegExp('const[ \\t]+' + name + '[ \\t]*=[ \\t]*([0-9.]+)'));
  if (!d) { missing.push(name); continue; }
  if (Math.abs(parseFloat(d[1]) - parseFloat(val)) > 1e-9) {
    bad++;
    console.log('  MISMATCH  ' + name + ' (' + where + '): page ' + val + '  code ' + d[1]);
  } else {
    ok++;
  }
}

// ===========================================================================
// GATE C -- AN IDENTIFIER THE PAGE NAMES MUST STILL EXIST.
//
// The checks above only see the tune:/knob CONSTANT columns. A define named in
// PROSE was invisible to them, and a DELETED define was invisible twice over:
// an unresolved name landed in `missing`, which printed a friendly "check by
// hand" line and let the run exit 0. Four dead names had accumulated that way
// (TOD_MAGE_ARCH_MULT_LV, TOD_MAGE_ON_LIGHTNING, TOD_TRAIL_NODE_MS,
// TOD_ATH_EDGE_TOL) while every gate on this page reported green.
//
// Naming a dead define ON PURPOSE is legitimate -- a note saying "X was deleted
// in v18.xx" is exactly the history this page exists to carry -- so those live
// in DEAD_OK with a reason, the same shape as the lint baselines.
// ===========================================================================
const DEAD_OK = {
  TOD_MAGE_ARCH_MULT_LV:
    "deleted 2026-09-08 when ARCHMAGE was rebased; the ARCHMAGE note names it to say so",
};

{
  let all = "";
  for ( const d of [ "scripts/zm/zm_tower_of_doom/", "scripts/zm/" ] ) {
    let names = [];
    try { names = fs.readdirSync( d ); } catch ( e ) {}
    for ( const f of names ) {
      if ( !/[.](gsc|gsh|csc)$/.test( f ) ) continue;
      try { all += fs.readFileSync( d + f, "utf8" ) + "\n"; } catch ( e ) {}
    }
  }
  for ( const f of fs.readdirSync( "tools" ) ) {
    if ( /[.]js$/.test( f ) && f !== "verify_armory_constants.js" ) {
      try { all += fs.readFileSync( "tools/" + f, "utf8" ) + "\n"; } catch ( e ) {}
    }
  }
  try { all += fs.readFileSync( "ui/uieditor/menus/hud/tod_upgrade.lua", "utf8" ); } catch ( e ) {}

  const named = [ ...new Set( page.match( /TOD_[A-Z0-9_]{2,}/g ) || [] ) ];
  const dead = named.filter( n => !all.includes( n ) && !DEAD_OK[ n ] );
  for ( const n of dead ) {
    bad++;
    console.log( "  DEAD NAME  " + n + " is named on the page but exists nowhere in scripts/, tools/ or the upgrade Lua" );
  }
  console.log( "identifiers named on the page: " + named.length + " checked, " + dead.length +
               " dead, " + Object.keys( DEAD_OK ).length + " waived" );
}

// ===========================================================================
// GATE D -- a domain ladder must have one rung per level it can reach.
// Cheap, and it catches a retune that moved a cap without touching the ladder
// beside it. bonusMax is a real higher cap for one class (SCAVENGER reaches 6
// for the assault), so the expected length is the larger of the two.
// ===========================================================================
{
  const i = page.indexOf( "const lin =" );
  const j = page.indexOf( "const DOMAINS = [" );
  if ( i < 0 || j < 0 ) {
    console.log( "  WARN  DOMAINS array not found -- ladder lengths unchecked" );
  } else {
    const open = page.indexOf( "[", j );
    let depth = 0, end = -1;
    for ( let k = open; k < page.length; k++ ) {
      if ( page[ k ] === "[" ) depth++;
      else if ( page[ k ] === "]" ) { depth--; if ( !depth ) { end = k + 1; break; } }
    }
    try {
      const doms = new Function( page.slice( i, j ) + "\nreturn " + page.slice( open, end ) )();
      let n = 0;
      for ( const d of doms ) {
        const want = Math.max( d.max || 0, d.bonusMax || 0 );
        if ( !Array.isArray( d.lad ) ) {
          bad++; n++;
          console.log( "  NO LADDER  " + d.name + " (id " + d.id + ") has no lad array" );
        } else if ( d.lad.length !== want ) {
          bad++; n++;
          console.log( "  LADDER LEN  " + d.name + " (id " + d.id + "): " + d.lad.length +
                       " rungs, but it reaches level " + want );
        }
      }
      console.log( "domain ladders: " + doms.length + " checked, " + n + " wrong length" );
    } catch ( e ) {
      console.log( "  WARN  DOMAINS array did not evaluate: " + e.message );
    }
  }
}

console.log('\nCONSTANTS STATED ON THE PAGE: ' + ok + ' match code, ' + bad + ' mismatch');
if (missing.length) console.log('not a #define or generator const (check by hand): ' + [...new Set(missing)].join(', '));
if (bad) process.exit(1);
