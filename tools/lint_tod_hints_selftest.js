#!/usr/bin/env node
// =============================================================================
// lint_tod_hints_selftest.js — proves lint_tod_hints.js actually catches things.
//
// A LINT NOBODY HAS SEEN GO RED IS NOT A GATE. This repo has the scar: the
// geometry lint went red twice on a map somebody had walked and both times the
// CHECK was wrong; and v14.3's triggerstring "fix" shipped with a dev print
// that proved its loop had RUN rather than that a slot had been SAVED. The
// pattern in both is a check that passes (or fails) honestly while measuring
// something other than the question. The only defence is to break the map on
// purpose and require a catch.
//
// It works on a COPY of the tree in the OS temp dir and passes --root to the
// lint, so the real files are never touched — a selftest that mutates the repo
// and restores it corrupts the tree the first time it throws mid-run.
//
// Usage:  node tools/lint_tod_hints_selftest.js
// Exit 0 = the lint caught every break AND passed the untouched control.
// =============================================================================

const fs = require( 'fs' );
const os = require( 'os' );
const path = require( 'path' );
const { execFileSync } = require( 'child_process' );

const REPO = path.join( __dirname, '..' );
const LINT = path.join( __dirname, 'lint_tod_hints.js' );
const REL_TOD = path.join( 'scripts', 'zm', 'zm_tower_of_doom' );
const REL_LUA = path.join( 'ui', 'uieditor', 'widgets', 'HUD', 'ZM_CursorHint',
	'ZMCursorHintNew.lua' );
// The lint's EXTRA_FILES (the de-singularized Pack-a-Punch, one directory up
// from REL_TOD). Mirrored here so the copied tree has it; the lint hard-fails
// on a missing extra file, so leaving it out would fail the control run.
const REL_EXTRA = path.join( 'scripts', 'zm', 'zm_cwpap.gsc' );

function mkTree()
{
	const dir = fs.mkdtempSync( path.join( os.tmpdir(), 'tod-hintlint-' ) );
	const tod = path.join( dir, REL_TOD );
	fs.mkdirSync( tod, { recursive: true } );
	for ( const f of fs.readdirSync( path.join( REPO, REL_TOD ) ) )
		if ( f.endsWith( '.gsc' ) )
			fs.copyFileSync( path.join( REPO, REL_TOD, f ), path.join( tod, f ) );
	fs.copyFileSync( path.join( REPO, REL_EXTRA ), path.join( dir, REL_EXTRA ) );
	fs.mkdirSync( path.join( dir, path.dirname( REL_LUA ) ), { recursive: true } );
	fs.copyFileSync( path.join( REPO, REL_LUA ), path.join( dir, REL_LUA ) );
	return dir;
}

function run( dir )
{
	try
	{
		const out = execFileSync( process.execPath, [ LINT, '--root', dir ],
			{ encoding: 'utf8', stdio: [ 'ignore', 'pipe', 'pipe' ] } );
		return { code: 0, out };
	}
	catch ( e )
	{
		return { code: e.status, out: ( e.stdout || '' ) + ( e.stderr || '' ) };
	}
}

function edit( dir, rel, from, to )
{
	const p = path.join( dir, rel );
	const src = fs.readFileSync( p, 'utf8' );
	if ( !src.includes( from ) )
		throw new Error( 'selftest anchor missing in ' + rel + ': ' + from );
	fs.writeFileSync( p, src.replace( from, to ) );
}

const CASES = [
	{
		name: 'ammo crate loses its noun -> is claimed by the Pack-a-Punch card',
		// The EXACT shape of the bug this whole pass fixed: copy that mentions
		// Pack a Punch is safe ONLY while "ammo crate" claims it first.
		break: dir => edit( dir, path.join( REL_TOD, '_tod_ammo_crate.gsc' ),
			'^5AMMO CRATE^7 - Regular', '^5RESUPPLY^7 - Regular' ),
		expect: /routes to the PAP card/,
	},
	{
		name: 'the Pack-a-Punch packed line loses its noun and says "weapon" -> PAP card (proves zm_cwpap.gsc is read)',
		// The vendored PaP flow lives OUTSIDE scripts/zm/zm_tower_of_doom/ and
		// was the lint's blind spot until v16.27. This break is only caught if
		// EXTRA_FILES is actually scanned.
		break: dir => edit( dir, REL_EXTRA,
			'"^1ALREADY PACKED^7 - upgrade at the Heavenly Altar"',
			'"^1PACKED^7 - upgrade your weapon at the altar"' ),
		expect: /zm_cwpap\.gsc: hint routes to the PAP card/,
	},
	{
		name: 'the noun is dropped from the router Lua (GSC untouched)',
		// The anti-drift half: the lint reads TOD_NOUNS out of the Lua, so
		// breaking either side alone has to go red.
		break: dir => edit( dir, REL_LUA, '"ammo crate",', '' ),
		expect: /routes to the PAP card/,
	},
	{
		name: 'a teleporter hint accidentally says "Open Door"',
		break: dir => edit( dir, path.join( REL_TOD, '_tod_teleport.gsc' ),
			'^5TELEPORTER^7 - down to the BASE', 'Open Door to the BASE' ),
		expect: /routes to the Doors card/,
	},
	{
		name: 'a new variable hint arrives with no multiplicity row',
		break: dir => edit( dir, path.join( REL_TOD, '_tod_rampage.gsc' ),
			'"Hold ^3[{+activate}]^7 ^1RAMPAGE^7 - currently ^2ON^7"',
			'"Hold ^3[{+activate}]^7 ^1RAMPAGE^7 - round " + level.round_number' ),
		expect: /VARIABLE hint with no MULTIPLICITY row/,
	},
	{
		name: 'a module sets a hint but declares no expected route',
		break: dir => fs.writeFileSync(
			path.join( dir, REL_TOD, '_tod_selftest_new.gsc' ),
			'#namespace tod_selftest;\nfunction f() { t SetHintString( "Hold ^3[{+activate}]^7 ^5NEW THING^7 - hello" ); }\n' ),
		expect: /no row in EXPECTED_ROUTES/,
	},
	{
		name: 'the door count grows past the distinct-string budget',
		break: dir =>
		{
			const p = path.join( dir, REL_TOD, '_tod_door_data.gsc' );
			let extra = '';
			for ( let i = 0; i < 400; i++ ) extra += '// "the Extra Floor ' + i + '"\n';
			// Deliberately NOT in a comment -- the counter strips comments, so
			// the break has to be real code to prove the counter is real.
			fs.appendFileSync( p, extra.replace( /\/\/ /g, 'x = ' ) + '\n' );
		},
		expect: /DISTINCT STRING BUDGET/,
	},
	{
		name: 'a hyphen inside a title would split the default card in the wrong place',
		// PromptDefault splits on the FIRST "-" with optional spaces, so a
		// hyphenated noun silently truncates the title.
		break: dir => edit( dir, path.join( REL_TOD, '_tod_teleport.gsc' ),
			'^5TELEPORTER^7 - down to the BASE', '^5TELEPORTER^7 - down to the BASE-ARENA' ),
		expect: /not written as " - "/,
	},
	{
		name: 'TOD_NOUNS is deleted from the router entirely',
		// Must fail LOUDLY (exit 2), never go quietly green with an empty list.
		break: dir => edit( dir, REL_LUA, 'local TOD_NOUNS', 'local TOD_NOUNS_RENAMED' ),
		expect: /has no TOD_NOUNS table/,
		code: 2,
	},
];

let failures = 0;

// CONTROL FIRST. If the untouched copy does not pass, every "catch" below is
// meaningless -- it would just be the lint failing at everything.
{
	const dir = mkTree();
	const r = run( dir );
	if ( r.code !== 0 )
	{
		console.error( 'CONTROL FAILED: the untouched tree does not pass the lint.\n' + r.out );
		failures++;
	}
	else
	{
		console.log( 'ok  control: untouched tree passes' );
	}
	fs.rmSync( dir, { recursive: true, force: true } );
}

for ( const c of CASES )
{
	const dir = mkTree();
	let r;
	try
	{
		c.break( dir );
		r = run( dir );
	}
	finally
	{
		// keep the dir on failure so the break can be inspected
	}
	const wantCode = c.code || 1;
	const caught = r.code === wantCode && c.expect.test( r.out );
	if ( caught )
	{
		console.log( 'ok  caught: ' + c.name );
		fs.rmSync( dir, { recursive: true, force: true } );
	}
	else
	{
		failures++;
		console.error( 'MISSED: ' + c.name );
		console.error( '  wanted exit ' + wantCode + ' and /' + c.expect.source + '/' );
		console.error( '  got exit ' + r.code + ':\n' + r.out.split( '\n' ).map( l => '    ' + l ).join( '\n' ) );
		console.error( '  broken tree left at ' + dir );
	}
}

if ( failures )
{
	console.error( '\nlint_tod_hints_selftest: ' + failures + ' failure(s)' );
	process.exit( 1 );
}
console.log( '\nlint_tod_hints_selftest: ' + CASES.length + ' break(s) caught, control clean' );
