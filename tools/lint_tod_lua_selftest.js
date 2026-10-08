#!/usr/bin/env node
// =============================================================================
// lint_tod_lua_selftest.js — proves lint_tod_lua.js can actually go RED.
//
// Same doctrine as lint_tod_geometry_selftest.js: a lint that has only ever
// been seen passing has proven nothing. A green result over a broken file is
// this repo's most expensive bug shape (see the "check that passes the wrong
// question" note in CLAUDE.md's neighbourhood) — the geometry lint shipped
// green over a spire with zero navmesh for eighteen versions.
//
// Breaks the real tod_upgrade.lua six ways in a scratch copy, requires the lint
// to catch every one, and requires it to pass the UNMODIFIED file. Run it
// whenever lint_tod_lua.js is edited.
//
// Usage:  node tools/lint_tod_lua_selftest.js      (exit 0 = the lint works)
// =============================================================================

const fs = require( 'fs' );
const os = require( 'os' );
const path = require( 'path' );
const { spawnSync } = require( 'child_process' );

const ROOT = path.join( __dirname, '..' );
const LINT = path.join( __dirname, 'lint_tod_lua.js' );
const SUBJECT = path.join( ROOT, 'ui', 'uieditor', 'menus', 'hud', 'tod_upgrade.lua' );

const tmp = fs.mkdtempSync( path.join( os.tmpdir(), 'todlua-' ) );
const scratch = path.join( tmp, 'subject.lua' );
// 2026-09-10: the subject can be CRLF in the working copy (it was, that day); every
// mutation below anchors on LF, so normalise here or the cases match nothing.
const original = fs.readFileSync( SUBJECT, 'utf8' ).replace( /\r\n/g, '\n' );

function runLint()
{
	const r = spawnSync( process.execPath, [ LINT, scratch ], { encoding: 'utf8' } );
	return r.status;
}

function write( text )
{
	fs.writeFileSync( scratch, text );
}

// Each case returns a mutated copy of the file that must be REJECTED.
// ⚠️ ANCHOR ON STRUCTURE, NEVER ON A VALUE. Three of these originally matched
// literal constants (`REVEAL_FLIP_MS   = 120`, `REVEAL_GLOW_PAD   = 14`,
// `MAX_LEVEL_TIME_DANGER = 5`). The first ROTTED the moment v14.53 retuned the
// flip to 60: the mutation matched nothing and the case tested NOTHING. The
// SETUP FAIL guard below is the only reason it did not quietly become a
// passing no-op — which would have left a lint whose selftest "passed" while
// exercising five of six behaviours.
//
// That is this repo's "second source of truth that nothing regenerates" trap
// wearing a test-file disguise. A subject's tuning constants WILL move, so
// match the DECLARATION and reuse whatever value it currently holds.
const CASES = [
	[ 'a dropped `end`', s => s.replace( /\n    end\n/, '\n' ) ],
	[ 'an extra `end`', s => s + '\nend\n' ],
	[ 'an unclosed paren',
		s => s.replace( /(local REVEAL_FLIP_MS\s*=\s*)(\d+)/, '$1( $2' ) ],
	[ 'a mismatched closer',
		s => s.replace( /(local REVEAL_GLOW_PAD\s*=\s*)(\d+)/, '$1( $2 ]' ) ],
	[ 'an unterminated string',
		s => s.replace( /(local MAX_LEVEL_TIME_DANGER\s*=\s*\d+)/, 'local BROKEN = "oops\n$1' ) ],
	[ 'a stray `until`', s => s + '\nuntil true\n' ],
];

let failures = 0;

for ( const [ label, mutate ] of CASES )
{
	const broken = mutate( original );
	if ( broken === original )
	{
		console.log( `SETUP FAIL  ${ label } — the mutation matched nothing; this case is testing NOTHING` );
		failures++;
		continue;
	}
	write( broken );
	const code = runLint();
	if ( code === 1 )
	{
		console.log( `caught      ${ label }` );
	}
	else
	{
		console.log( `MISSED      ${ label } (lint exited ${ code })` );
		failures++;
	}
}

// THE CONTROL. Without this the suite would still pass if the lint simply
// rejected everything, which is the same lie in the other direction.
write( original );
if ( runLint() === 0 )
{
	console.log( 'clean       the unmodified file (control)' );
}
else
{
	console.log( 'FALSE POSITIVE on the unmodified file (control)' );
	failures++;
}

fs.rmSync( tmp, { recursive: true, force: true } );

console.log( `\nlua lint selftest: ${ CASES.length + 1 } checks, ${ failures } failed` );
process.exit( failures ? 1 : 0 );
