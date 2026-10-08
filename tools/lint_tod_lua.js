#!/usr/bin/env node
// =============================================================================
// lint_tod_lua.js — a structural gate for the map's LUI Lua.
//
// WHY THIS EXISTS. ui/uieditor/menus/hud/tod_upgrade.lua is the single
// highest-blast-radius file in the tree: it draws the upgrade panel, the
// crosshair damage numbers, the tower gauge, the luck bar, the finale banner
// and the rampage seal. A syntax error in it does not degrade one feature — the
// menu fails to load and every one of those disappears at once, in game, with
// no build-time complaint. NOTHING in the pipeline reads Lua before the linker
// packs it as a rawfile: build_map.ps1 does not parse it, lint_tod_arity.js is
// GSC-only, and lint_gsc_xref.js is acc-only. Until this file, a dropped `end`
// shipped.
//
// WHAT IT PROVES (and, as importantly, what it does not). This is a TOKENIZER
// AND BLOCK BALANCER, not a Lua parser. It proves:
//   * every block keyword (function/if/for/while/do) has its `end`
//   * ( [ { all close, and close in the right order
//   * no unterminated string or long-bracket comment
// It does NOT prove the file is valid Lua — `x = = 1` sails straight through.
// That is the deliberate trade: the errors it CAN catch are the ones hand
// edits actually make, and it needs no toolchain (there is no Lua binary on
// this box, which is how the gap got here in the first place).
//
// Comments and strings are consumed properly, so `-- end` and "end" in a
// string cannot fool it. Long brackets ([[ ]], [==[ ]==]) are handled for both
// strings and comments.
//
// Usage:  node tools/lint_tod_lua.js [file ...]     (default: every ui/**/*.lua)
// Exit 0 = clean, 1 = a finding. Run it before every build that touches Lua.
// =============================================================================

const fs = require( 'fs' );
const path = require( 'path' );

// Keywords that OPEN a block and are closed by `end`.
//   `function`, `if` (via then), `for`/`while` (via do), and a bare `do`.
// `then` and `do` are NOT counted themselves — they are the tail of an `if` /
// `for` / `while` that was already counted, and counting both double-opens.
// A bare `do ... end` block is the one case where `do` opens on its own, so it
// is counted only when no for/while is pending.
const OPENERS = new Set( [ 'function', 'if', 'for', 'while', 'do' ] );

function tokenize( src )
{
	const out = [];
	let i = 0;
	const n = src.length;
	let line = 1;

	const longBracket = ( at ) =>
	{
		// [[ or [=*[ -> returns the level, or -1
		if ( src[ at ] !== '[' ) return -1;
		let j = at + 1, eq = 0;
		while ( src[ j ] === '=' ) { eq++; j++; }
		return src[ j ] === '[' ? eq : -1;
	};

	const skipLong = ( at, eq ) =>
	{
		const close = ']' + '='.repeat( eq ) + ']';
		const end = src.indexOf( close, at );
		if ( end === -1 ) return -1;
		return end + close.length;
	};

	while ( i < n )
	{
		const c = src[ i ];

		if ( c === '\n' ) { line++; i++; continue; }
		if ( c === ' ' || c === '\t' || c === '\r' ) { i++; continue; }

		// comment
		if ( c === '-' && src[ i + 1 ] === '-' )
		{
			const eq = longBracket( i + 2 );
			if ( eq >= 0 )
			{
				const next = skipLong( i + 2, eq );
				if ( next === -1 ) return { error: `unterminated long comment opened on line ${ line }` };
				for ( let k = i; k < next; k++ ) if ( src[ k ] === '\n' ) line++;
				i = next;
				continue;
			}
			while ( i < n && src[ i ] !== '\n' ) i++;
			continue;
		}

		// long string
		{
			const eq = longBracket( i );
			if ( eq >= 0 )
			{
				const next = skipLong( i, eq );
				if ( next === -1 ) return { error: `unterminated long string opened on line ${ line }` };
				for ( let k = i; k < next; k++ ) if ( src[ k ] === '\n' ) line++;
				i = next;
				continue;
			}
		}

		// quoted string
		if ( c === '"' || c === "'" )
		{
			const openLine = line;
			let j = i + 1;
			while ( j < n )
			{
				if ( src[ j ] === '\\' ) { j += 2; continue; }
				if ( src[ j ] === '\n' ) return { error: `unterminated string opened on line ${ openLine }` };
				if ( src[ j ] === c ) break;
				j++;
			}
			if ( j >= n ) return { error: `unterminated string opened on line ${ openLine }` };
			i = j + 1;
			continue;
		}

		// name / keyword
		if ( /[A-Za-z_]/.test( c ) )
		{
			let j = i;
			while ( j < n && /[A-Za-z0-9_]/.test( src[ j ] ) ) j++;
			out.push( { t: src.slice( i, j ), line } );
			i = j;
			continue;
		}

		// number (so 0x1f / 1e-3 cannot emit stray name tokens)
		if ( /[0-9]/.test( c ) )
		{
			let j = i;
			while ( j < n && /[0-9a-fA-FxX.\-+]/.test( src[ j ] ) )
			{
				// only let - / + continue the token straight after an exponent
				if ( ( src[ j ] === '-' || src[ j ] === '+' ) && !/[eEpP]/.test( src[ j - 1 ] ) ) break;
				j++;
			}
			i = j;
			continue;
		}

		out.push( { t: c, line } );
		i++;
	}
	return { tokens: out };
}

function check( file )
{
	const src = fs.readFileSync( file, 'utf8' );
	const r = tokenize( src );
	if ( r.error ) return [ r.error ];

	const findings = [];
	const blocks = [];    // { kw, line }
	const brackets = [];  // { ch, line }
	const PAIR = { ')': '(', ']': '[', '}': '{' };
	let pendingLoop = 0;  // for/while seen, its `do` not yet consumed

	for ( let k = 0; k < r.tokens.length; k++ )
	{
		const { t, line } = r.tokens[ k ];

		if ( t === '(' || t === '[' || t === '{' ) { brackets.push( { ch: t, line } ); continue; }
		if ( t === ')' || t === ']' || t === '}' )
		{
			const top = brackets.pop();
			if ( !top ) findings.push( `line ${ line }: stray '${ t }' — nothing open` );
			else if ( top.ch !== PAIR[ t ] ) findings.push( `line ${ line }: '${ t }' closes '${ top.ch }' opened on line ${ top.line }` );
			continue;
		}

		if ( t === 'for' || t === 'while' ) { blocks.push( { kw: t, line } ); pendingLoop++; continue; }
		if ( t === 'do' )
		{
			// the `do` of a for/while already counted, or a bare do-block
			if ( pendingLoop > 0 ) pendingLoop--;
			else blocks.push( { kw: 'do', line } );
			continue;
		}
		if ( t === 'function' || t === 'if' ) { blocks.push( { kw: t, line } ); continue; }
		if ( t === 'repeat' ) { blocks.push( { kw: 'repeat', line } ); continue; }
		if ( t === 'until' )
		{
			const top = blocks.pop();
			if ( !top || top.kw !== 'repeat' ) findings.push( `line ${ line }: 'until' without a matching 'repeat'` );
			continue;
		}
		if ( t === 'elseif' )
		{
			// `elseif cond then` — the `then` belongs to the SAME if, nothing opens
			const top = blocks[ blocks.length - 1 ];
			if ( !top || top.kw !== 'if' ) findings.push( `line ${ line }: 'elseif' outside an 'if'` );
			continue;
		}
		if ( t === 'end' )
		{
			const top = blocks.pop();
			if ( !top ) findings.push( `line ${ line }: 'end' with no open block` );
			else if ( top.kw === 'repeat' ) findings.push( `line ${ line }: 'end' closing a 'repeat' from line ${ top.line } (wants 'until')` );
			continue;
		}
	}

	for ( const b of blocks ) findings.push( `line ${ b.line }: '${ b.kw }' is never closed` );
	for ( const b of brackets ) findings.push( `line ${ b.line }: '${ b.ch }' is never closed` );
	return findings;
}


// =============================================================================
// PAUSE-ROW WIDTH GATE (added 2026-09-03).
//
// WHY. User, with a screenshot: "Looks how horrible it is. We need to remember
// that this has to be short and concise. This has happened multiple times where
// our description is super long and overlaps". It had happened repeatedly —
// every new domain wrote its DETAIL row without ever seeing the panel full, and
// the pause panel does NOT wrap, it OVERLAPS the row below.
//
// THE BUDGET, measured off AetheriumStartMenu's real rows: column COL_W 369,
// eff drawn at scale 0.90 and act at 0.79 => about 40 and 46 characters.
// STILL THE TIGHTER OF THE TWO PRESETS (2026-09-04): a 15+ row list switches
// that panel to a compact preset at scale 0.76/0.67 in the SAME COL_W, which
// fits MORE characters, not fewer. So this budget covers both. If a future
// preset ever grows the text or narrows the column, re-measure — do not assume
// the number below is the binding one just because it is the one written down.
//
// THE TRAP THIS EXISTS TO CATCH. A row whose eff is literally "{V}" hides its
// real length inside the val FUNCTION, so reading the table finds nothing:
// TRAILBLAZER measured 4 characters in the table and rendered 76 on screen.
// So val bodies are measured too — every string literal in the row is summed
// and each concatenated expression counted as a number's worth of characters.
// That is an approximation, deliberately generous, and it still catches the
// class of bug that shipped four times.
// =============================================================================
const PAUSE_EFF_MAX = 40;
const PAUSE_ACT_MAX = 46;

function pauseRowWidths( file, src )
{
	const out = [];
	if ( !file.replace( /\\/g, '/' ).endsWith( 'tod_upgrade.lua' ) ) return out;
	const start = src.indexOf( 'local DETAIL' );
	if ( start < 0 ) return out;
	// rows are "\n    [<id>] = {" separated; take to the table's closing line
	const body = src.slice( start );
	const rows = body.split( /\n    \[/ ).slice( 1 );
	for ( const r of rows )
	{
		const idm = r.match( /^(\d+)\]/ );
		if ( !idm ) continue;
		const id = idm[ 1 ];
		// bound the row: next row, or the line that closes the table
		let row = r.split( /\n    \[/ )[ 0 ];
		const closeAt = row.search( /\n\}/ );
		if ( closeAt >= 0 ) row = row.slice( 0, closeAt );
		if ( /eff\s*=\s*"REMOVED"/.test( row ) ) continue;   // retired stubs

		const wid = t => t.replace( /\{V\}/g, '99.9' ).length;

		const effLit = ( row.match( /eff\s*=\s*"([^"]*)"/ ) || [] )[ 1 ];
		const actLit = ( row.match( /act\s*=\s*"([^"]*)"/ ) || [] )[ 1 ];

		if ( effLit !== undefined && effLit !== '{V}' && wid( effLit ) > PAUSE_EFF_MAX )
			out.push( `DETAIL[${ id }] eff is ${ wid( effLit ) } chars (max ${ PAUSE_EFF_MAX }): "${ effLit }"` );
		// An ABILITY line ("Press ^3[{+bind}]^7 to cast - ...", v19.60) is NOT
		// counted here: its key is the engine's live key name or button picture,
		// whose width no character count can know, and the pause menu lays it out
		// piece by piece (AetheriumStartMenu TodActLine). tools/test_pause_text_all.lua
		// runs that real layout for every level on keyboard + controller and gates
		// the build; that measurement is the authority for these lines.
		if ( actLit !== undefined && !actLit.includes( '[{' ) && wid( actLit ) > PAUSE_ACT_MAX )
			out.push( `DETAIL[${ id }] act is ${ wid( actLit ) } chars (max ${ PAUSE_ACT_MAX }): "${ actLit }"` );

		// the val builder — only meaningful when eff defers to it
		// THE val BUILDER — only meaningful when eff defers to it with "{V}".
		//
		// Measured from the RETURN EXPRESSIONS ONLY, and with -- comments
		// stripped first. The first cut of this check summed every literal in
		// the row and reported DETAIL[8] at 213 chars and DETAIL[47] at 5594:
		// it was counting comment prose and, for the last row in the table,
		// everything to end of file. A lint that cries wolf gets switched off,
		// so it is bounded to what actually reaches the screen.
		if ( effLit === '{V}' )
		{
			const vm = row.match( /val\s*=\s*function[\s\S]*/ );
			if ( vm )
			{
				const src = vm[ 0 ].replace( /--[^\n]*/g, '' );      // drop comments
				let worst = 0;
				const rets = src.match( /return[^\n]*/g ) || [];
				for ( const ret of rets )
				{
					const lits = ( ret.match( /"([^"]*)"/g ) || [] )
						.map( x => x.slice( 1, -1 ) )
						.filter( x => !/^%\.?\d*f$/.test( x ) );
					const joins = ( ret.match( /\.\./g ) || [] ).length;
					const est = lits.reduce( ( a, b ) => a + b.length, 0 ) + Math.ceil( joins / 2 ) * 3;   // ~3 chars per substituted value (2-digit is the norm)
					if ( est > worst ) worst = est;
				}
				if ( worst > PAUSE_EFF_MAX )
					out.push( `DETAIL[${ id }] eff BUILDER renders about ${ worst } chars (max ${ PAUSE_EFF_MAX }) — the "{V}" hides it; shorten the val strings` );
			}
		}
	}
	return out;
}

function walk( dir, acc )
{
	for ( const e of fs.readdirSync( dir, { withFileTypes: true } ) )
	{
		const p = path.join( dir, e.name );
		if ( e.isDirectory() ) walk( p, acc );
		else if ( e.name.endsWith( '.lua' ) ) acc.push( p );
	}
	return acc;
}

const args = process.argv.slice( 2 );
const files = args.length ? args : walk( path.join( __dirname, '..', 'ui' ), [] );

let bad = 0;
for ( const f of files )
{
	const findings = check( f );
	findings.push( ...pauseRowWidths( f, fs.readFileSync( f, 'utf8' ) ) );
	if ( findings.length )
	{
		bad++;
		console.log( `FAIL ${ path.relative( path.join( __dirname, '..' ), f ).replace( /\\/g, '/' ) }` );
		for ( const m of findings.slice( 0, 12 ) ) console.log( `       ${ m }` );
		if ( findings.length > 12 ) console.log( `       ... and ${ findings.length - 12 } more` );
	}
}

console.log( `\nlua structure + pause-row widths: ${ files.length } file(s), ${ bad } with findings` );
process.exit( bad ? 1 : 0 );
