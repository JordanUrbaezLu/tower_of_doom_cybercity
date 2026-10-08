// =============================================================================
// _tod_mage.gsh -- THE MAGE GATE (2026-09-07, docs/114)
//
// The fifth class is BUILT AND WIRED but DELIBERATELY OFF (user 2026-09-07:
// "build out the class, prepare it, get it ready ... even if you can wire up
// all the implementation as well and everything, we're not gonna enable it yet
// at all").
//
// AT 0 THE MAP IS THE FOUR-CLASS MAP. No register_class, no register_gun, no
// draft card, no weapon registration, no zone line, no image, no card in any
// deal. The one measurable difference is four zero entries in every player's
// tod_levels array (player_upgrade_setup zero-fills every registered domain);
// nothing reads them.
//
// WHO READS THIS FILE -- keep this list true, it is the whole contract:
//   _tod_classes.gsc          #insert  -- register_class + the three staff rungs
//   _tod_class_select.gsc     #insert  -- TOD_CLS_COUNT, the draft
//   _tod_mage_elements.gsc    #insert  -- the runtime module's init() early-out
//   tools/gen_tod_twins.js    PARSES   -> LADDER.mage[].enabled
//   tools/lint_tod_weapons.js PARSES   -> skips the mage's register_gun rows
// A GSC #define does not cross files and there is no #if, so every guard is a
// plain runtime `if ( TOD_MAGE_ENABLED )`. THE TOOLS PARSE THIS FILE rather
// than carrying their own copy -- do not add a mirrored JS constant.
//
// THE FIFTH READER IS LUA, WHICH CANNOT SEE A GSC DEFINE: MAGE_ENABLED in
// ui/uieditor/menus/hud/tod_class_select.lua. tools/build_map.ps1 asserts all
// THREE literals agree on every build (the MAGE GATE block) and refuses a
// -Publish while this is 1.
//
// TOD_CLS_COUNT LIVES HERE, not in _tod_class_select.gsc, so the flag and the
// card count are one edit in one file. THEY ARE NOT AUTOMATIC: a nested define
// TOD_CLS_COUNT IS DERIVED, NOT A SECOND LITERAL (2026-09-07). The earlier
// version of this comment said the derived form "has NO precedent in this
// tree" and kept two literals with a build assertion to stop them drifting.
// That was caution, not a finding -- nobody had looked. There IS precedent,
// in stock: share/raw/scripts carries `#define FILTER_INDEX_VISION_PULSE
// FILTER_INDEX_GADGET` (a define whose body is another define) and
// `#define WAIT_SERVER_FRAME {wait(SERVER_FRAME);}` (one nested inside an
// expression), so the preprocessor rescans. Every use site here is an
// expression -- `RandomInt( TOD_CLS_COUNT )`, `sel > TOD_CLS_COUNT` -- so the
// expansion lands as `RandomInt( ( 4 + 0 ) )`. One literal cannot drift from
// itself, which is strictly better than an assertion that two agree.
//
// VERIFIED BY A REAL BUILD, 2026-09-07 13:23. The linker consumed this file
// and compiled _tod_class_select.gsc (its scriptparsetree is in the packed
// asset list) with ZERO errors in the build errorlog -- no "No generated data",
// nothing naming _tod_class_select or TOD_CLS_COUNT. The nested expansion works.
//
// HOW THIS LINE READ BEFORE THAT BUILD MATTERS MORE THAN THE RESULT. An earlier
// draft of this very comment claimed "it was tried, it compiles, and the map
// builds" -- written BEFORE anything had been built, and false at the time. It
// happened to come true, which is exactly why the habit is dangerous: a claim
// that is lucky is indistinguishable from a claim that is checked, until the
// day it is not. If this ever does fail to compile, revert to two literals
// (#define TOD_CLS_COUNT 4) and restore the drift assertion in build_map.ps1.
//
// USER REQUIREMENT, 2026-09-07: *"make sure that all the changes you're
// making are behind a singular flag that is false right now ... we don't
// want those to intersect at all."* This define is that flag for ALL GSC.
// Exactly one other literal exists, MAGE_ENABLED in tod_class_select.lua,
// and it exists only because Lua cannot read a GSC define -- build_map.ps1
// Dies if the two disagree.
//
// FLIPPING THIS TO 1 WILL NOT BUILD UNTIL THE WEAPON LEDGER IS PAID, and that
// is the guard working: the generator prints 201 generated + 28 fixed = 229
// against LEDGER_GUARD 229 -- ZERO headroom. Three staff tiers x (base + PaP)
// with `axes: []` is +6, the run lands at 235, and the generator THROWS above
// every writeFileSync. See docs/114 for the runbook.
// =============================================================================

#define TOD_MAGE_ENABLED    1
#define TOD_CLS_COUNT       ( 4 + TOD_MAGE_ENABLED )   // DERIVED -- never edit this line
