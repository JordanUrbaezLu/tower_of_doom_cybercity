#!/usr/bin/env node
// =============================================================================
// lint_tod_hints.js — the two gates on cursor-hint strings.
//
// WHY THIS EXISTS. Hint strings have two failure modes on this map and neither
// one is visible at build time. Both have shipped.
//
//   1. THE TRIGGERSTRING 250 CAP. SetHintString mints ONE PERMANENT engine slot
//      per DISTINCT string, capped at 250 per match, never freed, shared with
//      stock. Overflow fatals in BG_Cache_GetIndexInternal and BLAMES WHOEVER
//      REGISTERS NEXT, so the reported crash site is never the cause. The rule
//      CLAUDE.md draws from that history is "COUNT DISTINCT STRINGS to prove a
//      fix" — v14.3's flatten shipped with a dev print that proved the loop had
//      RUN rather than that a slot had been SAVED, and did nothing. Nothing in
//      the tree counted them until this file.
//
//   2. HINT-TEXT ROUTING. The Aetherium prompt kit picks which card to draw by
//      PATTERN-MATCHING THE HINT TEXT (ui/.../ZM_CursorHint/ZMCursorHintNew.lua)
//      — SetHintString is its only input channel. Get the wording wrong and the
//      prompt renders as something else entirely, silently, forever. Live for
//      months (found 2026-08-31): every priced NON-DOOR interactable in the map
//      — the ammo crates, the Heavenly Gift Altar, CALL EXTRACTION, every spire
//      buy — drew the WALL BUY card and its hardcoded description "Wall Weapon",
//      because that route's "…and the hint has no icon" guard never fired. Two
//      GSC files carried comments reasoning confidently from that dead guard.
//
// WHAT IT PROVES.
//   GATE A (routing): every hint authored under scripts/zm/zm_tower_of_doom/
//   lands on the card its module is declared to want. The router's own
//   TOD_NOUNS table is PARSED OUT OF THE LUA, not copied here, so the check
//   cannot drift from the thing it checks — rename a prompt in GSC without
//   updating TOD_NOUNS and this goes red.
//
//   GATE B (budget): the number of DISTINCT strings this map can register in
//   one match stays under budget. Constant literals count 1. A literal with an
//   interpolated value can produce many, so every one of those must have a row
//   in MULTIPLICITY below saying how many and why — an unannotated variable
//   hint is a hard failure, because "I did not think about it" is exactly how
//   v8's 25->50 lap doubling walked the map into the cap.
//
// WHAT IT DOES NOT PROVE. It reads scripts/zm/zm_tower_of_doom/ plus the
// EXTRA_FILES list (zm_cwpap, the de-singularized Pack-a-Punch — added v16.27
// when it grew authored copy; its stock &"ZOMBIE_*" references are counted and
// route-checked through LOCALIZED_REFS). The other VENDORED modules one
// directory up set hints too — _zm_perk_wisp_tea, zm_zod_robot (4 strings) and
// the fuse craftable (4) — and none are counted here. That is deliberate for
// the two robot/craftable families: both are vendored for their FX and VO only,
// their summon/craft flows need map entities this map does not place, so their
// hints never register; but it IS an assumption, and if one of those flows is
// ever wired up its strings are invisible to this count. It also cannot count STOCK's share
// of the 250 (that is
// engine-side), which is why BUDGET below reserves headroom rather than
// spending all 250. It does not parse GSC properly — it scans for
// SetHintString( and balances parens — so a hint built across statements into a
// variable is invisible to it. And a green run says nothing about whether the
// COPY is any good, only about where it routes and what it costs.
//
// Usage:  node tools/lint_tod_hints.js [--verbose]
// Exit 0 = clean, 1 = a finding. Wired into build_map.ps1, including -GscOnly:
// a hint change is exactly the kind of GSC-only edit that skips every other
// gate.
// =============================================================================

const fs = require( 'fs' );
const path = require( 'path' );

// --root <dir> points the lint at a COPY of the tree. Only the selftest uses
// it; it exists so the selftest can break the map six ways without ever
// touching the real files (a selftest that mutates the repo and restores it
// leaves a broken tree behind the first time it throws).
const rootArg = process.argv.indexOf( '--root' );
const ROOT = rootArg > 0 ? path.resolve( process.argv[ rootArg + 1 ] )
                         : path.join( __dirname, '..' );
const TOD_DIR = path.join( ROOT, 'scripts', 'zm', 'zm_tower_of_doom' );
const ROUTER_LUA = path.join( ROOT, 'ui', 'uieditor', 'widgets', 'HUD',
	'ZM_CursorHint', 'ZMCursorHintNew.lua' );

// The engine's hard cap, and what we allow ourselves of it. Stock registers its
// own strings into the same 250 (perk machines, the power switch, the PaP,
// every stock prompt the kit shows), and we cannot enumerate those from here,
// so the reserve is the honest way to leave room for them.
const ENGINE_CAP = 250;
const STOCK_RESERVE = 60;
const BUDGET = ENGINE_CAP - STOCK_RESERVE;

// -----------------------------------------------------------------------------
// Which card each module's prompts are supposed to land on.
// -----------------------------------------------------------------------------
// A module may legitimately produce more than one route (the finale's uplink
// says "you must turn on the power first" in one state and names a price in
// another), so each entry is the SET of routes that module is allowed to hit.
// "" is the blanking call SetHintString( "" ) and never routes anywhere.
const EXPECTED_ROUTES = {
	'_tod_ammo_crate.gsc': [ 'DefaultHint' ],
	'_tod_doors.gsc': [ 'Doors', '' ],
	'_tod_finale.gsc': [ 'DefaultHint', 'PowerRequired', '' ],
	'_tod_rampage.gsc': [ 'DefaultHint' ],
	'_tod_rocket.gsc': [ 'DefaultHint', '' ],   // v19.68r THE ROCKETS: the ships' EXTRACT / ASCEND prompts reuse the finale's and the spire's strings (docs/170)
	'_tod_spire.gsc': [ 'DefaultHint', 'Doors', '' ],
	'_tod_teleport.gsc': [ 'DefaultHint' ],
	'_tod_upgrades.gsc': [ 'DefaultHint' ],
	'_tod_main.gsc': [ 'DefaultHint', '' ],   // HARNESS #8 ONLY (2026-09-02, the dev spire warp pad) — remove this row with the harness
	// Perk modules register their hint through zm_perks::register_perk_basic_info
	// rather than calling SetHintString, so they are picked up as assignments
	// below and must land on the perk card.
	'_tod_perk_phd.gsc': [ 'Perks' ],
	'_tod_perk_electric_cherry.gsc': [ 'Perks' ],
	// The de-singularized Pack-a-Punch flow (EXTRA_FILES below). This row covers
	// its AUTHORED literals only — the ALREADY PACKED status line (v16.27). Its
	// three stock &"ZOMBIE_*" references are checked against their OWN routes in
	// LOCALIZED_REFS, not against this row: if 'PAP' were allowed here, an
	// authored line that drifted onto the PaP card could never be caught.
	'zm_cwpap.gsc': [ 'DefaultHint', '' ],
};

// FILES OUTSIDE TOD_DIR THAT SET HINTS ON THIS MAP'S OWN VENDORS. zm_cwpap is
// the de-singularized Pack-a-Punch — five machines (the crown + four lounges)
// on one code path — and was this lint's declared blind spot until v16.27,
// when it grew the map's first authored copy. Paths are relative to ROOT. A
// missing file is a HARD failure, never a silent skip: a lint that quietly
// stops reading a file is the "passes the wrong question" shape again.
const EXTRA_FILES = [ path.join( 'scripts', 'zm', 'zm_cwpap.gsc' ) ];

// STOCK LOCALIZED REFERENCES — SetHintString( &"REF" [, parm] ). The engine
// resolves these from the game's own string table; the English is quoted from
// share/raw/english/localizedstrings/zombie.str (file prefix ZOMBIE_) so the
// ROUTING gate runs on what the player READS, not on the reference name. Each
// is one constant slot, and each carries the card it is SUPPOSED to draw — so
// a TOD_NOUNS entry that hijacked a stock prompt (say, a noun that matches
// "Pack-a-Punch") goes red here. An &"REF" not listed is a finding.
const LOCALIZED_REFS = {
	ZOMBIE_PERK_PACKAPUNCH:     { text: 'Hold ^3[{+activate}]^7 for Pack-a-Punch [Cost: &&1]',   route: 'PAP' },
	ZOMBIE_PERK_PACKAPUNCH_AAT: { text: 'Hold ^3[{+activate}]^7 to Re-Pack Weapon [Cost: &&1]', route: 'PAP' },
	ZOMBIE_NEED_POWER:          { text: 'You must turn on the Power first!',                     route: 'PowerRequired' },
};

// -----------------------------------------------------------------------------
// How many DISTINCT strings a hint template with an interpolated value can
// produce over one match. Keyed by "<file>::<template>", where the template is
// the literal with every interpolation replaced by <>. ADD A ROW WHEN YOU ADD A
// VARIABLE HINT — the lint fails on any it does not recognise, on purpose.
// -----------------------------------------------------------------------------
const MULTIPLICITY = [
	{
		file: '_tod_doors.gsc',
		match: 'Open Door to',
		count: () => countDoors(),
		why: 'one per buyable door: destination + price, both stamped ONCE at ' +
		     'spawn (v14.14 made the price a spawn-time constant precisely so ' +
		     'this stays bounded — never re-stamp a door hint)',
	},
	{
		file: '_tod_spire.gsc',
		match: 'Open Door to the Endless Spire',
		count: () => 1,
		why: 'ONE literal for all 70 spire doors (flat 6300 through ' +
		     'door_price), factored into spire_door_hint() so the seal re-stamp ' +
		     'cannot mint a second',
	},
	{
		file: '_tod_spire.gsc',
		match: 'CALL EXTRACTION',
		count: () => 1,
		why: 'the summit price is a single constant (7500)',
	},
	{
		file: '_tod_finale.gsc',
		match: 'CALL EXTRACTION',
		count: () => 1,
		why: 'finale_cost() is a single constant (12000); it is NOT scaled by ' +
		     'party size — if it ever is, this becomes one string per party size',
	},
	{
		file: '_tod_upgrades.gsc',
		match: 'HEAVENLY GIFT ALTAR',
		count: () => 1,
		why: 'station_cost() is a FLAT constant. The old 2000 +250/purchase ' +
		     'ladder was retired for this exact reason — every rung was a ' +
		     'permanent slot. If a ladder ever returns, this row is a lie',
	},
	{
		file: '_tod_ammo_crate.gsc',
		match: 'AMMO CRATE',
		count: () => 1,
		why: 'the two costs are #defines, so the built string is constant; and ' +
		     'crate_hint() is the ONE site, shared with the spire crates',
	},
	{
		file: '_tod_perk_phd.gsc',
		match: 'PhD FLOPPER',
		count: () => 1,
		why: 'the &&1 cost substitution is engine-side; the registered string ' +
		     'itself is constant',
	},
	{
		file: '_tod_perk_electric_cherry.gsc',
		match: 'Death Perception',
		count: () => 1,
		why: 'as above — &&1 is substituted at display time, not registration',
	},
];

// =============================================================================
// The router's TOD_NOUNS, read out of the Lua so it cannot drift.
// =============================================================================
function readTodNouns()
{
	const src = fs.readFileSync( ROUTER_LUA, 'utf8' );
	// ANCHORED, not indexOf (selftest case 7 found this): a bare
	// indexOf( 'local TOD_NOUNS' ) also matches 'local TOD_NOUNS_RENAMED', so
	// renaming the table away left the lint reading a table that no longer
	// feeds the router — passing green while measuring nothing. That is the
	// exact "a check that passes the wrong question" shape this repo keeps
	// hitting; the anchor is what makes the failure loud.
	const m = /\blocal\s+TOD_NOUNS\s*=/.exec( src );
	const at = m ? m.index : -1;
	if ( at < 0 )
		fail( 'ZMCursorHintNew.lua has no TOD_NOUNS table — the router was ' +
		      'restructured and this lint has not caught up. Fix the lint; do ' +
		      'not delete the check.' );
	const open = src.indexOf( '{', at );
	const close = src.indexOf( '}', open );
	if ( open < 0 || close < 0 )
		fail( 'could not read the TOD_NOUNS table body' );
	const body = src.slice( open + 1, close );
	const nouns = [];
	// Strip line comments first, or a noun mentioned in one would be counted.
	for ( const line of body.split( '\n' ) )
	{
		const code = line.replace( /--.*$/, '' );
		for ( const m of code.matchAll( /"([^"]*)"/g ) )
			nouns.push( m[ 1 ].toLowerCase() );
	}
	if ( !nouns.length )
		fail( 'TOD_NOUNS parsed as empty' );
	return nouns;
}

// A faithful mirror of classifyHint() in ZMCursorHintNew.lua. If you change one,
// change the other — that duplication is the price of checking a Lua predicate
// from node, and it is why the NOUN LIST (the part that actually moves) is
// parsed from the Lua instead of copied.
function classify( text, nouns )
{
	if ( !text ) return '';
	const h = text.toLowerCase();
	if ( h.includes( 'you must turn on the power first' ) ) return 'PowerRequired';
	if ( h.includes( 'turn on the power' ) || h.includes( 'activate power' ) ||
	     h.includes( 'activate the power' ) ) return 'PowerSwitch';
	if ( h.includes( 'open door' ) || h.includes( 'debris' ) ) return 'Doors';
	for ( const n of nouns )
		if ( h.includes( n ) ) return 'DefaultHint';
	if ( perkFromHint( h ) ) return 'Perks';
	if ( isPap( h ) ) return 'PAP';
	return 'DefaultHint';
}

// getPerkFromHint's rule: "hold" AND "for", then any perk-name word > 3 chars.
const PERK_NAMES = [ 'PhD FLOPPER', 'WISP TEA', 'DOUBLE TAP', 'JUGGER-NOG',
	'STAMIN-UP', 'QUICK REVIVE', 'SPEED COLA', "WIDOW'S WINE",
	'DEATH PERCEPTION' ];

function perkFromHint( h )
{
	if ( !h.includes( 'hold' ) || !h.includes( 'for' ) ) return null;
	for ( const name of PERK_NAMES )
	{
		const low = name.toLowerCase();
		if ( h.includes( low ) ) return name;
		for ( const word of low.split( /[\s-]+/ ) )
			if ( word.length > 3 && h.includes( word ) ) return name;
	}
	return null;
}

function isPap( h )
{
	const pack = h.includes( 'pack' ), punch = h.includes( 'punch' );
	const weapon = h.includes( 'weapon' ), upgrade = h.includes( 'upgrade' );
	return ( pack && punch ) || ( pack && weapon ) || ( upgrade && weapon );
}

// =============================================================================
// Extraction
// =============================================================================
function stripComments( src )
{
	let out = '', i = 0;
	while ( i < src.length )
	{
		const c = src[ i ];
		if ( c === '"' )
		{
			out += c; i++;
			while ( i < src.length && src[ i ] !== '"' )
			{
				if ( src[ i ] === '\\' ) { out += src[ i ]; i++; }
				out += src[ i ]; i++;
			}
			out += src[ i ]; i++;
			continue;
		}
		if ( c === '/' && src[ i + 1 ] === '/' )
		{
			while ( i < src.length && src[ i ] !== '\n' ) i++;
			continue;
		}
		if ( c === '/' && src[ i + 1 ] === '*' )
		{
			i += 2;
			while ( i < src.length && !( src[ i ] === '*' && src[ i + 1 ] === '/' ) ) i++;
			i += 2;
			continue;
		}
		out += c; i++;
	}
	return out;
}

// Split a GSC expression on its TOP-LEVEL '+' operators, skipping over string
// literals entirely. Skipping literals is not a nicety: "[Cost: " and "]" live
// in different literals of the door hint, so a naive bracket-depth counter goes
// negative mid-expression and swallows the separator (that bug ate the door
// template's whole price clause on the first run of this lint).
function splitConcat( expr )
{
	const parts = [];
	let cur = '', depth = 0, i = 0;
	while ( i < expr.length )
	{
		const c = expr[ i ];
		if ( c === '"' )
		{
			let j = i + 1;
			while ( j < expr.length && expr[ j ] !== '"' )
				j += ( expr[ j ] === '\\' ) ? 2 : 1;
			cur += expr.slice( i, j + 1 );
			i = j + 1;
			continue;
		}
		if ( c === '(' ) depth++;
		else if ( c === ')' ) depth--;
		if ( c === '+' && depth === 0 ) { parts.push( cur ); cur = ''; i++; continue; }
		cur += c; i++;
	}
	parts.push( cur );
	return parts;
}

// Balanced argument text for the FIRST call of `name` starting at `from`.
function callArgs( src, name, from )
{
	const at = src.indexOf( name, from );
	if ( at < 0 ) return null;
	const open = src.indexOf( '(', at + name.length - 1 );
	if ( open < 0 ) return null;
	let depth = 0, j = open;
	for ( ; j < src.length; j++ )
	{
		if ( src[ j ] === '"' ) { j++; while ( j < src.length && src[ j ] !== '"' ) j += ( src[ j ] === '\\' ) ? 2 : 1; continue; }
		if ( src[ j ] === '(' ) depth++;
		else if ( src[ j ] === ')' ) { depth--; if ( !depth ) break; }
	}
	return { text: src.slice( open + 1, j ), end: j };
}

// Every hint-setting site. THREE lanes, because the map genuinely uses three:
//   (1) a direct SetHintString( <expr> ) call,
//   (2) SetHintString( helper() ) where the literal lives in the helper's
//       `return` — crate_hint(), spire_door_hint(), hint_for_state(). Factoring
//       a hint into a function is the RECOMMENDED shape (it is what keeps every
//       ammo crate on one slot), so the lint has to follow it or it would
//       penalise the correct pattern,
//   (3) the perk modules, which hand their string to stock via
//       register_perk_basic_info / .hint_string and never call SetHintString.
// Plus a catch-all: any literal carrying the [{+activate}] button token IS a
// cursor hint (nothing else in this tree uses that token), which is how the
// teleporters' per-destination strings get counted even though they reach the
// trigger through an entity field this scanner cannot follow.
function extract( file, src, defines )
{
	const clean = stripComments( src );
	const sites = [];
	const seenTemplates = new Set();

	const resolve = ( expr ) =>
	{
		const parts = [];
		let variable = false;
		for ( const raw of splitConcat( expr ) )
		{
			const t = raw.trim();
			if ( !t ) continue;
			const lit = t.match( /^"((?:[^"\\]|\\.)*)"$/ );
			if ( lit ) { parts.push( lit[ 1 ] ); continue; }
			if ( Object.prototype.hasOwnProperty.call( defines, t ) )
			{
				parts.push( String( defines[ t ] ) );
				continue;
			}
			variable = true;
			parts.push( '<>' );
		}
		return { template: parts.join( '' ), variable };
	};

	const add = ( template, variable, kind, argText ) =>
	{
		const key = kind + ' ' + template;
		if ( seenTemplates.has( key ) ) return;
		seenTemplates.add( key );
		sites.push( { file, kind, template, variable, argText } );
	};

	// --- lane 2 first: index this file's functions so lane 1 can follow them.
	const fns = new Map();
	for ( const m of clean.matchAll( /^function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(/gm ) )
	{
		// Body = from the match to the next top-level `function` (GSC has no
		// nested function definitions, so this is exact enough).
		const start = m.index;
		const next = clean.indexOf( '\nfunction ', start + 1 );
		fns.set( m[ 1 ], clean.slice( start, next < 0 ? clean.length : next ) );
	}

	// --- lane 1
	let from = 0;
	for ( ;; )
	{
		const args = callArgs( clean, 'SetHintString', from );
		if ( !args ) break;
		from = args.end;
		const expr = args.text.trim();

		// SetHintString( &"REF" [, parm] ) — a stock localized string. One
		// constant slot of its own; routed on its English text (LOCALIZED_REFS).
		const ref = expr.match( /^&"([A-Za-z0-9_]+)"(?:\s*,[\s\S]*)?$/ );
		if ( ref )
		{
			add( '&' + ref[ 1 ], false, 'SetHintString(&ref)', expr );
			continue;
		}

		// SetHintString( helper() ) -> resolve the helper's return expressions.
		const direct = expr.match( /^([A-Za-z_][A-Za-z0-9_]*)\s*\(\s*\)$/ );
		if ( direct && fns.has( direct[ 1 ] ) )
		{
			const body = fns.get( direct[ 1 ] );
			let found = false;
			for ( const r of body.matchAll( /\breturn\s*\(?\s*("[\s\S]*?)\s*\)?\s*;/g ) )
			{
				const res = resolve( r[ 1 ] );
				if ( res.template ) { add( res.template, res.variable, 'SetHintString->' + direct[ 1 ], r[ 1 ] ); found = true; }
			}
			if ( found ) continue;
		}

		const res = resolve( expr );
		add( res.template, res.variable, 'SetHintString', expr );
	}

	// --- lane 3
	for ( const m of clean.matchAll( /register_perk_basic_info\s*\(([\s\S]*?)\);/g ) )
	{
		const lit = m[ 1 ].match( /"((?:[^"\\]|\\.)*)"\s*,\s*GetWeapon/ );
		if ( lit ) add( lit[ 1 ], false, 'register_perk_basic_info', lit[ 0 ] );
	}
	for ( const m of clean.matchAll( /\.hint_string\s*=\s*"((?:[^"\\]|\\.)*)"/g ) )
		add( m[ 1 ], false, 'hint_string=', m[ 0 ] );

	// --- catch-all: a literal carrying the button token is a cursor hint --
	// BUT ONLY IN A FILE THAT ACTUALLY SETS ONE (2026-09-07).
	//
	// The catch-all exists so a hint ASSEMBLED INTO A VARIABLE cannot hide from
	// the scanner. That reasoning needs a SetHintString call somewhere in the
	// file; with none there is no hint to assemble. The old rule said "any
	// literal carrying the button token is a cursor hint", and that premise
	// stopped being true when _tod_mage_elements grew a HUDELEM whose button
	// labels are live bind tokens. A hudelem expands bind tokens (stock proof:
	// mp/killstreaks/_remotemortar.gsc:414 sets "[{+attack}]" on one) and mints
	// NO triggerstring slot -- the 250 cap belongs to SetHintString alone.
	// Counting those four labels moved the reported budget 95 -> 99 and hard-
	// failed the build over a hint that does not exist.
	//
	// THE BLIND SPOT THIS ADDS, stated now rather than discovered later: a file
	// that builds a hint string but calls SetHintString nowhere in its own text
	// -- handing it to another module -- now escapes this catch-all. The known
	// cross-file cases are modelled explicitly already (EXTRA_FILES, and the
	// register_perk_basic_info / .hint_string= lanes above); all of those run
	// before this block and are untouched by the guard.
	if ( /SetHintString\s*\(/.test( clean ) )
		for ( const m of clean.matchAll( /"((?:[^"\\]|\\.)*\[\{\+[\w_]+\}\](?:[^"\\]|\\.)*)"/g ) )
			add( m[ 1 ], false, 'token-literal', m[ 0 ] );

	return sites;
}

// #define constants, so TOD_CRATE_COST_BASE resolves to 2500 and the ammo
// crate's built string is recognised as CONSTANT rather than variable.
function readDefines( src )
{
	const out = {};
	for ( const m of src.matchAll( /^\s*#define\s+([A-Za-z_][A-Za-z0-9_]*)\s+(-?[0-9.]+)\s*(?:\/\/.*)?$/gm ) )
		out[ m[ 1 ] ] = m[ 2 ];
	return out;
}

let doorCache = null;
function countDoors()
{
	if ( doorCache !== null ) return doorCache;
	const p = path.join( TOD_DIR, '_tod_door_data.gsc' );
	const src = stripComments( fs.readFileSync( p, 'utf8' ) );
	// Each door row names its zone flag exactly once as "enter_lapN" / a named
	// zone; counting the destination strings is the stable signal.
	const dests = new Set();
	for ( const m of src.matchAll( /"((?:the |The )[^"]*)"/g ) ) dests.add( m[ 1 ] );
	doorCache = dests.size;
	return doorCache;
}

// Colour codes and the button token are engine formatting, not part of what the
// router sees as words — but they ARE part of the distinct string the engine
// caches, so strip them only for routing, never for counting.
function forRouting( t )
{
	return t.replace( /\^\d/g, '' ).replace( /\[\{\+[\w_]+\}\]/g, '' );
}

// =============================================================================
const findings = [];
let hardFail = false;
function fail( msg ) { console.error( 'lint_tod_hints: ' + msg ); process.exit( 2 ); }

function main()
{
	const verbose = process.argv.includes( '--verbose' );
	const nouns = readTodNouns();

	const files = fs.readdirSync( TOD_DIR ).filter( f => f.endsWith( '.gsc' ) ).sort();
	let sites = [];
	for ( const f of files )
	{
		const src = fs.readFileSync( path.join( TOD_DIR, f ), 'utf8' );
		sites = sites.concat( extract( f, src, readDefines( src ) ) );
	}
	for ( const rel of EXTRA_FILES )
	{
		const p = path.join( ROOT, rel );
		if ( !fs.existsSync( p ) )
			fail( `${rel} is missing — it is a declared hint-setting file ` +
			      `(EXTRA_FILES). If it moved, move the row; never drop it.` );
		const src = fs.readFileSync( p, 'utf8' );
		sites = sites.concat( extract( path.basename( rel ), src, readDefines( src ) ) );
	}

	// The token-literal catch-all also sees the FRAGMENTS of a concatenated
	// hint ("… ^2[Cost: " is its own literal in the source). Those are not
	// separate engine slots — only the assembled string is — so drop any
	// catch-all entry that is a strict prefix of a real site's template.
	const assembled = sites.filter( s => s.kind !== 'token-literal' ).map( s => s.template );
	sites = sites.filter( s => !( s.kind === 'token-literal' &&
		assembled.some( a => a !== s.template && a.startsWith( s.template ) ) ) );

	// OPAQUE SITES: SetHintString( <something this scanner cannot follow> ) —
	// today that is _tod_teleport's per-pad t.tod_tp_hint_ready field. The
	// literals themselves are still counted, by the [{+activate}] catch-all, so
	// this is a note rather than a failure. It IS the lint's blind spot though:
	// a hint assembled into a variable with no button token would be invisible.
	const opaque = sites.filter( s => /^(<>)*$/.test( s.template ) && s.template !== '' );
	sites = sites.filter( s => !opaque.includes( s ) );
	for ( const s of opaque )
		console.log( `  note: ${s.file} sets a hint from "${s.argText.trim()}" — ` +
			`not followable here; its literals are counted via the button token` );

	// ---- GATE A: routing ----------------------------------------------------
	for ( const s of sites )
	{
		if ( s.template === '' ) continue;             // the blanking call
		if ( s.template[ 0 ] === '&' )                 // a stock localized reference
		{
			const ref = LOCALIZED_REFS[ s.template.slice( 1 ) ];
			if ( !ref )
			{
				findings.push( `${s.file}: SetHintString( ${s.argText.trim()} ) uses a ` +
					`stock localized reference this lint has no English text for.\n` +
					`      Add it to LOCALIZED_REFS (zombie.str, prefix ZOMBIE_) with ` +
					`the card it draws, so its route can be checked.` );
				hardFail = true;
				continue;
			}
			s.route = classify( forRouting( ref.text ), nouns );
			if ( s.route !== ref.route )
			{
				findings.push( `${s.file}: the stock string ${s.template} ("${ref.text}") ` +
					`now routes to the ${s.route} card instead of ${ref.route}.\n` +
					`      A TOD_NOUNS entry or a router change has hijacked a stock ` +
					`prompt — fix the router, not this table.` );
				hardFail = true;
			}
			continue;
		}
		const route = classify( forRouting( s.template ), nouns );
		s.route = route;
		const allowed = EXPECTED_ROUTES[ s.file ];
		if ( !allowed )
		{
			findings.push( `${s.file}: sets a hint but has no row in ` +
				`EXPECTED_ROUTES. Declare which prompt card it is supposed to ` +
				`draw.\n      hint: "${s.template}"` );
			hardFail = true;
			continue;
		}
		if ( !allowed.includes( route ) )
		{
			findings.push( `${s.file}: hint routes to the ${route} card, but ` +
				`this module is declared as ${allowed.filter( Boolean ).join( '/' )}.\n` +
				`      hint: "${s.template}"\n` +
				`      FIX: give the prompt a noun in TOD_NOUNS ` +
				`(ZMCursorHintNew.lua), or reword it so no other card claims it.` );
			hardFail = true;
		}
	}

	// ---- GATE C: the default card's grammar ---------------------------------
	// PromptDefault.lua splits "<TITLE> - <detail> / <detail 2>" on the first
	// "-" and the first "/", with the surrounding spaces OPTIONAL — deliberately,
	// so the card degrades gracefully if whitespace is ever lost upstream (the
	// "HoldXAMMOCRATE" report). The cost of that tolerance is that a hyphen or
	// slash INSIDE a title or a detail would be read as the separator and split
	// the copy in the wrong place: "JUGGER-NOG - buy it" would render the title
	// "JUGGER" over the detail "NOG - buy it".
	//
	// So the SOURCE must always write a real separator as " - " / " / " with
	// spaces, and must never use either character for anything else. That is
	// decidable from the literal, unlike "is this title a whole noun".
	for ( const s of sites )
	{
		if ( s.route !== 'DefaultHint' ) continue;      // other cards parse themselves
		const body = forRouting( s.template ).replace( /\[[Cc]ost:[^\]]*\]/g, '' );
		for ( const ch of [ '-', '/' ] )
		{
			for ( let i = 0; i < body.length; i++ )
			{
				if ( body[ i ] !== ch ) continue;
				const before = body[ i - 1 ], after = body[ i + 1 ];
				if ( before === ' ' && after === ' ' ) continue;
				findings.push( `${s.file}: a "${ch}" that is not written as ` +
					`" ${ch} " in a hint that draws the DEFAULT card. That card ` +
					`splits on the first "${ch}" with optional spaces, so this ` +
					`would break the copy at the wrong place.\n` +
					`      hint: "${s.template}"\n` +
					`      FIX: reword so "${ch}" appears only as the separator, ` +
					`surrounded by spaces.` );
				hardFail = true;
				break;
			}
		}
	}

	// ---- GATE B: distinct-string budget ------------------------------------
	const seen = new Map();     // template -> {count, why, files:Set}
	for ( const s of sites )
	{
		if ( s.template === '' ) continue;
		let count = 1, why = 'constant literal';
		if ( s.variable )
		{
			const row = MULTIPLICITY.find( r => r.file === s.file &&
				s.template.includes( r.match ) );
			if ( !row )
			{
				findings.push( `${s.file}: VARIABLE hint with no MULTIPLICITY ` +
					`row — how many DISTINCT strings can it register in one ` +
					`match?\n      hint: "${s.template}"\n` +
					`      Add a row to MULTIPLICITY in tools/lint_tod_hints.js ` +
					`with the number and the reason it is bounded.` );
				hardFail = true;
				continue;
			}
			count = row.count();
			why = row.why;
		}
		const prev = seen.get( s.template );
		if ( prev ) { prev.files.add( s.file ); continue; }   // same string = same slot
		seen.set( s.template, { count, why, files: new Set( [ s.file ] ) } );
	}

	let total = 0;
	for ( const [ , v ] of seen ) total += v.count;

	// ---- report -------------------------------------------------------------
	if ( verbose )
	{
		const rows = [ ...seen.entries() ].sort( ( a, b ) => b[ 1 ].count - a[ 1 ].count );
		console.log( 'DISTINCT HINT STRINGS (tod-authored):' );
		for ( const [ t, v ] of rows )
			console.log( `  ${String( v.count ).padStart( 3 )}  [${[ ...v.files ].join( ',' )}]  ${JSON.stringify( t )}` );
		console.log( '' );
	}

	// A string set by two different modules is ONE slot, and that is worth
	// saying out loud — it is the shape the ammo-crate duplication had.
	const shared = [ ...seen.entries() ].filter( ( [ , v ] ) => v.files.size > 1 );
	for ( const [ t, v ] of shared )
		console.log( `  note: one slot shared by ${[ ...v.files ].join( ' + ' )}: ${JSON.stringify( t )}` );

	if ( total > BUDGET )
	{
		findings.push( `DISTINCT STRING BUDGET: ${total} tod-authored strings ` +
			`against a budget of ${BUDGET} (engine cap ${ENGINE_CAP} minus ` +
			`${STOCK_RESERVE} reserved for stock). Overflow does not fail here — ` +
			`it fatals IN GAME in BG_Cache_GetIndexInternal, blaming whichever ` +
			`system registers next.` );
		hardFail = true;
	}

	if ( findings.length )
	{
		console.error( '\nlint_tod_hints: ' + findings.length + ' finding(s)\n' );
		for ( const f of findings ) console.error( '  * ' + f + '\n' );
	}
	console.log( `hint strings: ${seen.size} template(s) -> ${total} distinct ` +
		`string(s) of ${BUDGET} budgeted (engine cap ${ENGINE_CAP}, ` +
		`${STOCK_RESERVE} reserved for stock)` );

	process.exit( hardFail ? 1 : 0 );
}

main();
