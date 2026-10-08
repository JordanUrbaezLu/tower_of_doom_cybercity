// Prove docs/armory.html actually RENDERS -- all twelve tabs, every one of them
// with real content in it.
//
// WHY THIS IS A REPO TOOL AND NOT A SCRATCHPAD SCRIPT (2026-09-09).
// The user's report was "I've asked multiple agents but they miss multiple tabs
// every time". The page has TWELVE tabs and only EIGHT builder functions -- one
// of them, buildClass, draws five of the tabs -- so "all builders ran" reads as
// full coverage while saying nothing about whether a given tab produced
// anything. The previous shim also handed out a FRESH fake node on every
// getElementById call, so a builder could write its panel into a throwaway
// object and the check still passed. Both holes are closed here: nodes are
// identity-stable by id, and every panel id must come out non-trivially filled.
//
// This is a page-integrity gate, not a numbers gate. verify_armory_constants.js
// checks stated constants, dead identifiers and ladder lengths;
// verify_armory_domains.js checks the domain table's structural fields.
const fs = require( 'fs' ), vm = require( 'vm' );
const path = 'docs/armory.html';
const html = fs.readFileSync( path, 'utf8' );

// The twelve panels declared in the markup. Derived, not hardcoded, so a new
// tab is covered the day it is added rather than the day somebody remembers.
const PANELS = [ ...html.matchAll( /<section class="panel" id="(p-[a-z0-9]+)"/g ) ].map( m => m[ 1 ] );
if ( PANELS.length < 2 ) { console.error( 'could not find the panel sections' ); process.exit( 1 ); }

const m = html.match( /<script>([\s\S]*?)<\/script>/ );
if ( !m ) { console.error( 'no <script> block' ); process.exit( 1 ); }
const src = m[ 1 ];

try { new vm.Script( src, { filename: 'armory-inline.js' } ); }
catch ( e ) { console.error( 'SYNTAX: ' + e.message ); process.exit( 1 ); }
console.log( 'syntax OK' );

const byId = new Map();

function mkNode( tag, id )
{
	const n = {
		tagName: ( tag || 'div' ).toUpperCase(), id: id || '', children: [], style: {}, dataset: {},
		classList: { add(){}, remove(){}, toggle(){}, contains(){ return false; } },
		_html: '', _text: '',
		get innerHTML(){ return this._html; },
		set innerHTML( v ){ this._html = String( v ); },
		get textContent(){ return this._text; },
		set textContent( v ){ this._text = String( v ); },
		appendChild( c ){ this.children.push( c ); this._html += ( c && c._html ) || ''; return c; },
		append( ...c ){ c.forEach( x => { this.children.push( x ); this._html += ( x && x._html ) || ''; } ); },
		insertBefore( c ){ this.children.push( c ); return c; },
		removeChild(){}, remove(){}, setAttribute(){}, getAttribute(){ return null; },
		removeAttribute(){}, addEventListener(){}, click(){}, focus(){}, scrollIntoView(){},
		closest(){ return null; }, contains(){ return false; },
		querySelector(){ return mkNode( 'div' ); },
		querySelectorAll(){ return []; },
		getBoundingClientRect(){ return { top: 0, left: 0, width: 0, height: 0 }; },
	};
	// `el(h)` builds every block on this page as
	//     t = createElement("template"); t.innerHTML = h; return t.content.firstElementChild
	// so a <template>'s content has to CARRY the html it was just given. The
	// old shim handed back a fresh empty node here, which silently threw away
	// the markup of every block on the page -- and since it also handed out a
	// new node per getElementById, nothing downstream could notice.
	Object.defineProperty( n, 'content', { get(){
		const inner = mkNode( 'div' );
		inner._html = n._html;
		return { firstElementChild: inner };
	} } );
	Object.defineProperty( n, 'firstElementChild', { get(){ return this.children[ 0 ] || mkNode( 'div' ); } } );
	return n;
}

// IDENTITY-STABLE. The whole point: the node a builder writes into is the node
// this script inspects afterwards.
function getById( id )
{
	if ( !byId.has( id ) ) byId.set( id, mkNode( 'div', id ) );
	return byId.get( id );
}

const doc = {
	createElement: t => mkNode( t ),
	createDocumentFragment: () => mkNode( 'fragment' ),
	getElementById: getById,
	querySelector: sel => {
		const g = /^#([A-Za-z0-9_-]+)$/.exec( sel || '' );
		return g ? getById( g[ 1 ] ) : mkNode( 'div' );
	},
	querySelectorAll: () => [],
	addEventListener(){}, body: mkNode( 'body' ), documentElement: mkNode( 'html' ),
};
const sandbox = {
	document: doc, console,
	window: { addEventListener(){}, matchMedia: () => ( { matches: false, addEventListener(){} } ),
	          location: { hash: '' }, localStorage: { getItem(){ return null; }, setItem(){} } },
	localStorage: { getItem(){ return null; }, setItem(){} },
	requestAnimationFrame: f => f(), setTimeout: f => f(), clearTimeout(){},
	Math, JSON, Date, Number, String, Array, Object, isNaN, parseInt, parseFloat,
};
sandbox.globalThis = sandbox;
try { vm.createContext( sandbox ); new vm.Script( src ).runInContext( sandbox, { timeout: 30000 } ); }
catch ( e ) {
	console.error( 'RUNTIME: ' + ( e && e.stack ? e.stack.split( '\n' ).slice( 0, 4 ).join( '\n' ) : e ) );
	process.exit( 1 );
}
console.log( 'boot OK' );

// Run every builder. A throw here is a dead tab.
const built = [];
for ( const k of Object.keys( sandbox ) )
{
	if ( /^build/.test( k ) && typeof sandbox[ k ] === 'function' )
	{
		const args = k === 'buildClass' ? [ 'skirmisher', 'assault', 'heavy', 'slasher', 'mage' ] : [ undefined ];
		try { args.forEach( a => sandbox[ k ]( a ) ); built.push( k ); }
		catch ( e ) { console.error( 'PANEL ' + k + ' THREW: ' + ( e && e.message ) ); process.exit( 1 ); }
	}
}
console.log( 'builders OK (' + built.length + '): ' + built.join( ', ' ) );

// THE CHECK THAT WAS MISSING: every declared panel must be non-trivially filled.
// 400 chars is far below the smallest real panel and far above an empty shell.
const MIN = 400;
let bad = 0;
for ( const id of PANELS )
{
	const n = byId.get( id );
	const len = n ? n.innerHTML.length : 0;
	if ( len < MIN )
	{
		bad++;
		console.log( '  EMPTY PANEL  ' + id + ' rendered ' + len + ' chars (expected at least ' + MIN + ')' );
	}
}
console.log( 'panels: ' + PANELS.length + ' declared, ' + ( PANELS.length - bad ) + ' rendered with content' );
if ( bad ) { console.error( '\nARMORY RENDER FAILED — ' + bad + ' tab(s) would show up blank' ); process.exit( 1 ); }
console.log( '\nARMORY RENDER OK — every tab draws' );
