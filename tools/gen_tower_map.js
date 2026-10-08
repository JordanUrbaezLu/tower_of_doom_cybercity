#!/usr/bin/env node
// =============================================================================
// gen_tower_map.js — generator for map_source/zm/zm_tower_of_doom.map
//
// THE .map IS GENERATED: this file's layout tables are the source of truth.
// Run `node tools/gen_tower_map.js` to (re)write BOTH:
//   map_source/zm/zm_tower_of_doom.map
//   scripts/zm/zm_tower_of_doom/_tod_door_data.gsc   (door buy-trigger coords)
// Hand-edits to those two files WILL be clobbered — change the tables here.
//
// v3 — THE FULL TOWER (user 2026-08-18, overnight mandate): 25 laps of
// open-air spiral around the solid core (was 3), rooftop arena on top at
// z=19200. Neon palette CYCLES through 8 colors lap by lap (all names
// verified against the installed eMoX GDT). Perks / wallbuys ladder up the
// climb; door costs escalate 750 -> 4000 (roof 5000). Reflection probes every
// 3rd lap. Miami night skybox all around; scripted fog rides
// _tod_atmosphere.gsc (not this file).
//
//   base arena  z=0        base_zone     power switch, Quick Revive, SMG wall,
//                                        mystery box, 3 class-select stations
//   lap N       (N-1)*768  lapN_zone     door enter_lapN
//   THE CROWN   z=19392    roof_zone     door enter_roof — the finale plaza
//
// Spiral (per lap, CCW): E flight north -> NE landing -> N flight west ->
// NW landing -> W flight south -> SW landing -> S flight east -> SE landing
// (= next lap start). 16 steps x 12u rise / 32u tread per flight; steps are
// 16u slabs (the lap above spirals 752u overhead).
//
// v9 — THE CROWN (user 2026-08-21: "at the top of the map there is nothing...
// design the top of the map and design the ending. Also the last platform
// isn't even connected to the stairs"). Two things changed:
//   1. THE BUG. The roof arrival was an ODD-lap-only special case inside the
//      flight loop. v8 doubled LAPS to 50 — an EVEN final lap — so that branch
//      never ran: no arrival landing was ever emitted, and the roof door slab
//      hung in open air on a side floor 50 does not build. The roof was
//      literally unreachable. The crown is now built from the SAME parity math
//      as the flights (CROWN_LAP = LAPS+1, mirror factor CM), so it welds to
//      the stairs for ANY value of LAPS. Change LAPS freely; the top follows.
//   2. THE TOP. One more flight (the CROWN STAIR) climbs off the final landing
//      to the CROWN DECK at z=TOP2 — a 1152x1152 plaza capping the core, WIDER
//      THAN THE BASE ARENA, with a glowing cornice visible from the street.
//      Plaza furniture: the UPLINK dais dead centre, 4 corner PYLONS, PaP west,
//      Mule Kick east, an upgrade terminal south, and the EXTRACTION PAD north.
//      The finale logic that drives them lives in _tod_finale.gsc and reads its
//      anchor points from the GENERATED _tod_crown_data.gsc (this file emits
//      it, same no-drift contract as _tod_door_data.gsc).
//
// LED-BAKE BUDGET: ~2400 brushes at 25 laps. The bake is THE gate
// (docs/BO3_MAPMAKING_KB.md §1) — tools/_bake_test.ps1 -TimeoutSec 420 after
// any regen. If it CRASHES (brush.cpp:1860): first bump PARA_EVERY 2 -> 4
// (halves parapet brushes), then reduce LAPS.
// =============================================================================

'use strict';

const fs = require('fs');
const path = require('path');

const REPO = path.join(__dirname, '..');
// TOD_MAP_OUT lets a run write the .map somewhere else, so a variant can be
// generated and BAKED (`_bake_test.ps1 -TestMap <path>`) without touching the
// shipped one. Added 2026-08-25 to A/B a bake time that would not reproduce —
// which is the only honest way to answer "what actually made the bake slow".
const MAP_OUT = process.env.TOD_MAP_OUT || path.join(REPO, 'map_source', 'zm', 'zm_tower_of_doom.map');
const DOOR_GSC_OUT = path.join(REPO, 'scripts', 'zm', 'zm_tower_of_doom', '_tod_door_data.gsc');
const CROWN_GSC_OUT = path.join(REPO, 'scripts', 'zm', 'zm_tower_of_doom', '_tod_crown_data.gsc');
const BREATHER_GSC_OUT = path.join(REPO, 'scripts', 'zm', 'zm_tower_of_doom', '_tod_breather_data.gsc');
// v19.69 — NIKOLAI'S FAN PROPS (the ammo chest and the spawn sign). Their sizes are
// MEASURED from the shipped binaries by tools/fan_props/build_fan_props.py and read
// here, so the crate box and the sign's clearances are asserted against the real
// models instead of a re-typed number.
const FAN_PROPS = JSON.parse(fs.readFileSync(path.join(REPO, 'art', 'fan_props', 'manifest.json'), 'utf8')).props;

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------
const CORE = 256;          // core half-extent (solid column, roof on top)
const PX = 416;            // path outer edge (path width 160)
const PARA = 20;           // parapet thickness
const PARA_H = 56;         // parapet height above the local step/landing
// the lap-door gate post lives IN the rail band (see the DOORS block, section 5)
const DOOR_POST_NOTCH = 10;   // the post reaches this far past the door line's centre each way (y +-256 -> +-266 / +-246)
const doorPostAt = (lapNo) => FACELIFT && lapNo >= 1 && lapNo <= LAPS;   // every lap door carries a gate; the crown door (LAPS+1) does not
const ARENA = 540;         // base arena half-extent (104u ring around the tower)
const WALL = 20;
const BASE_WALL_H = 128;
const SLAB = 16;

// ---------------------------------------------------------------------------
// THE TELEPORT BAY (v10.24, user 2026-08-24: "Someone placed the telepoerter
// under the stairs. Thats a horrible spot. Just add a new area at spawn where
// these teleporters live. Its no probelm to add another room somewhere on the
// first floor").
//
// THEY WERE LITERALLY UNDER THE STAIRCASE. v10.22 lined the four up-pads down
// the arena's east strip at x=360 — but lap 1's east flight occupies x[256,416]
// climbing the east face, so three of the four pads sat directly beneath the
// treads. The east strip looked like "the only clear straight run in the arena"
// on a plan view because the plan view has no z.
//
// So the bay moves OUT of the arena entirely, into its own room punched through
// the SOUTH wall — directly behind the spawn band (spawns are x[-192,192],
// y[-462,-498], facing north), which is what "a new area at spawn" asks for.
// This is the same move the POWER HALL makes through the east wall, and it is
// built to the same recipe: own floor, own 128-tall walls, own clips to 800,
// own lights, and an added base_zone volume brush so drops and spawn logic
// cover it.
//
// Nothing here is under anything: the room is south of y=-560 and the tower's
// lowest geometry stops at the arena wall.
// v10.25 (user 2026-08-24: "That room needs to be a lot smaller almost only big
// enough to fit the teleporters. Also it shoudl cost money to open that room.
// And you need to add a couple spawns in there").
//
// SHRUNK BY BUILDING IN A 2x2 INSTEAD OF A ROW. Four pads in a line cannot be
// compact: the assembly is ~167 across and TOD_TP_TRIG_RADIUS 110 forces 220
// between centres, so a row is 828 wide before any margin. Stacked 2x2 the same
// four pads occupy 388 x 388, and the room lands at 480 x 560 interior against
// the v10.24 row's 960 x 640 — 44% of the floor area, and only ~1.8x the pad
// block itself. That is as tight as the trigger geometry allows: the 220
// spacing is what makes the four use-triggers exactly TANGENT, and overlapping
// use-triggers turn the prompt into a coin flip (the v10.4 rule).
//
// GATED (TPBAY_DOOR_COST) and it is its OWN ZONE, not part of base_zone. Both
// follow from the user asking for spawns in here: risers belong to a zone, and
// base_zone is live from round 1, so risers in a sealed room would spawn
// zombies nobody can reach — actor slots burned on a room with no door open.
// That is exactly why the POWER ROOM, the map's other gated annex, has none.
// With its own zone the risers only wake when the door is bought.
const TPB_DOOR  = 160;    // half-width of the opening in the south wall
const TPB_X     = 240;    // bay interior half-width
// ROOM DEEPENED 2026-08-27 (user: "the teleporter room lets expand it by pushing
// the back wall a bit further back, This is because the landing pad overlaps with
// the teleporter pads and that doesnt look good").
//
// THE OVERLAP WAS REAL AND PURELY VISUAL — the trigger clearances were always
// fine, which is why it never showed up as a bug. Measured on the old numbers:
//   arrival decal   x[-88,88]    y[-708,-532]
//   front-row decal x[-198,-22]  y[-848,-672]   (and its mirror)
// -> they intersected over 66 x 36 units. The pad CENTRES were 178u apart,
// comfortably past the 120u gather, so nothing malfunctioned; two 176u floor
// squares simply drew through each other.
//
// Fix: push the south wall back 160 and slide BOTH rows 80 further south. The
// row-to-row spacing stays exactly 220 so the "tangent triggers either way"
// property is untouched; only the gap to the arrival grows.
// -1120 -> -1280 buys the room for it, and every clearance improves:
//   arrival-to-nearest-pad   178u -> 246u
//   decal gap                -66u (overlapping) -> +44u
//   back row to south wall   56u  -> 132u
//   riser to nearest pad     186u -> 258u
// KEEP _tod_teleport.gsc's up_orgs IN STEP — that file HARDCODES these four pad
// coordinates and there is no generated bridge for them, so a change here alone
// separates the visible pad from the trigger that uses it.
const TPB_Y1    = -1280;  // bay interior south edge
const TPB_Y2    = -(ARENA + WALL);  // -560, flush with the arena wall's south face
// The 2x2: centres 220 apart on BOTH axes (tangent triggers either way), the
// pair of rows 52u apart at the pad edges so you can still walk between them.
const TPB_PAD_X = 110;
const TPB_PAD_YN = -840;  // front row  (floors 10 / 20)
const TPB_PAD_YS = -1060; // back row   (floors 30 / 40)
const TPB_ARR_Y = -620;   // arrival, in the entry apron north of the front row
const TPB_RISER_Y = -600; // the two risers flank the doorway (see the zone below)
const TPB_RISER_X = 205;

const LAPS = 50;                              // v8: DOUBLED (user 2026-08-21) — top z=19200
const STEPS = 16, TREAD = 32, RISE = 12;      // per flight: 512 run, 192 rise
// A flight spans exactly one core face, so STEPS*TREAD must equal 2*CORE. That
// was an unguarded hand-maintained coincidence until 2026-08-27 — docs/39's
// blast-radius trial set TREAD 48 and got a 50-storey map with the climb
// SILENTLY severed (no throw; only the geometry lint caught it). Free insurance:
if (STEPS * TREAD !== 2 * CORE) throw new Error(`STEPS*TREAD (${STEPS * TREAD}) must equal 2*CORE (${2 * CORE}) — the flight no longer spans its core face`);
const FLIGHT_RISE = STEPS * RISE;             // 192
const LAP_RISE = 2 * FLIGHT_RISE;             // 384 — v6: TWO flights per floor (user 2026-08-20)
const TOP = LAPS * LAP_RISE;                  // 19200 — rooftop level
const PARA_EVERY = 2;                         // parapet box per N steps (bake knob)
// Invisible cap over every rail run so a rail top is not a launch pad (v9,
// user 2026-08-21). 112 is well over a BO3 jump from a rail top; the rails
// themselves stay 56 so the city stays visible while you climb.
const RAIL_CAP_H = 112;

// ---------------------------------------------------------------------------
// STAIR RAMP CLIP (2026-08-27) — the stair-feel fix. Full research: docs/39.
//
// Players complained the stairs are "slippery going down / sticky going up".
// The geometry is NOT defective (docs/39 §2: every transition on the climb is
// exactly 0 or +12, zero anomalies on a 1-unit walk) — the problem is that this
// was the only staircase in shipped-or-custom BO3 content that players WALK ON
// STEPPED COLLISION. Every stock Treyarch stair carries a sloped clip wedge
// over its treads (verified in the shipped prefab source: zm_giant staircases
// use metal_clip at atan(8/12); stairs_curved clips a HELICAL stair with a
// 16-brush fan). The wedge removes all ~1,616 discrete step events per climb:
// no riser planes to catch a diagonal move going up, no per-step camera
// correction, continuous ground contact (friction + full steering) going down.
//
// MATERIAL = plain `clip` since v16.61a (2026-09-02) — Treyarch's own shipped
// configuration (zm_giant uses metal_clip, the same flags + a surface type).
// From 2026-08-27 to v16.60 it was `clip_player`, chosen to isolate the
// player-side variable for the feel experiment (docs/39 G1b):
//   * clip.gdt (art_assets/t6_legacy/texture_assets/clip.gdt, re-read
//     2026-09-02): clip_player = playerClip 1, aiClip 0, bulletClip 0,
//     canShootClip 0 — blocks PLAYERS ONLY; plain clip = the SAME flags with
//     aiClip 1. So bullets and grenades still pass through either wedge and
//     hit the treads; the only thing `clip` adds is ZOMBIE collision.
//   * radiant/configs/navmesh.json lists clip_player in "exclusions" and NOT
//     plain clip. Under clip_player the navmesh — and every zombie path — was
//     byte-identical with the ramps in or out, and zombies climbed the 16
//     stepped treads: ~9 discrete 12-unit hops per second at sprint speed,
//     the only BO3 staircase anywhere that AI climbs on stepped collision.
//     THAT is what a head lock-on (Deadshot, and the stock torso assist to a
//     lesser degree) was tracking — the user's "bounces up and down when a
//     zombie runs up stairs". Under plain clip the navmesh cuts on the wedge
//     (20.556° against maxWalkableSlope 46), so zombies glide the slope the
//     way they do on every Treyarch stair and the target head moves smoothly.
//     Docs/39 G1a called this "likely an AI improvement ... must be walked
//     with a horde before shipping" — that walk is the v16.61a test.
//   * measure_lit_area.js's UNLIT regex is start-anchored (^clip): `clip` and
//     `clip_player` both stay out of the lit-area budget; metal_clip would be
//     mis-counted as ~30M u² of phantom lit area, which is why not metal_clip.
//   * The breather lounges' WINDOW VOIDS used to share this key. They must
//     stay clip_player (players stay in, bullets AND zombies pass — a zombie
//     must never path onto a window sill), so they ride MAT.winClip now.
// REVERT TO THE OLD FEEL EXPERIMENT: MAT.rampClip = 'clip_player', regen,
// FULL build (the navmesh is what changes either way).
//
// PLANE PLACEMENT (Treyarch's, measured from their prefabs, not guessed): the
// wedge top is the plane through the FRONT-TOP NOSING CORNER of every tread —
// the unique lowest plane at the stair's slope that never dips below a tread
// top. It touches each tread at its front edge and stands at most +RISE above
// it at the back. Both ends land flush: the top end welds into the landing at
// exactly landing height, and the bottom end knife-edges into the approach
// floor over the last TREAD units before the first riser (a 0->12 feather,
// exactly the stock arrangement). Underside = the same plane RAMP_T lower,
// which stays inside the tread slabs the whole way (tread slab bottom is
// top-16 and consecutive treads overlap 4 in z), so NO invisible face is ever
// exposed under the open-air stairs — the lap-1 arena strip under the east
// flight stays walkable.
//
// TOOLING CONTRACT (all verified before this shipped):
//   * lint_tod_geometry.js parses axis-constant planes only and drops a wedge
//     at `planes.length !== 6` BEFORE the material table lookup — so the lint
//     neither aborts on the material nor sees the ramps at all. Its proofs
//     still hold for the treads underneath, which stay exactly as they were;
//     the ramps themselves are proven by the generator's own construction
//     (slope asserted = RISE/TREAD, ends asserted flush by arithmetic here).
//   * measure_lit_area.js counts them in its skipped/unlit bucket (^clip).
//   * The wedges do NOT go through addBox(), so the crown self-measure
//     (crownBB) never sees the crown-stair ramp — irrelevant, it is inside the
//     crown stair's existing envelope.
//
// REVERT: set STAIR_RAMP_CLIP = false, node tools/gen_tower_map.js, FULL
// rebuild. Nothing else references it — no GSC, no zone, no data file.
// ---------------------------------------------------------------------------
const STAIR_RAMP_CLIP = true;
const RAMP_T = 16;             // vertical thickness = SLAB: underside stays buried in the tread slabs
// RAMP_LIFT (2026-09-04, navmesh seams — user: "random spots on the map zombies
// won't attack you ... around floor 42-44"). The wedge top used to pass EXACTLY
// through every tread's front-top nosing edge, so each flight handed cod2map a
// walkable plane with fifteen coplanar contact LINES on it. Havok's overlapping-
// triangle fixup turns that into slivers, and on specific laps — the same laps on
// BOTH towers, because the plane arithmetic depends only on y and z — the ramp's
// faces come out unstitched: tools/lint_tod_navmesh.js read the shipped .hkt as
// 18 connected components, every seam inside the E flight of laps 17/19/33/39/43
// (floor 43 = the user's 42-44 report; lap 17 = the v17.7 "no mesh above floor
// 17" ceiling, which was this seam plus pruning). Lifting the whole wedge by
// RAMP_LIFT puts every nosing strictly UNDER the plane — no contact, no sliver —
// while the walking surface, the slope and the seeds are otherwise unchanged
// (the underside stays inside the tread slabs for any LIFT <= SLAB - 4; the two
// ends become 2-unit steps onto/off the landings, under Havok maxStepHeight 18).
// Players never touched the treads except at the nosings, so this moves the
// visible feet by 2 units and nothing else. The gate that proves it every full
// build is lint_tod_navmesh.js (build_map.ps1, right after cod2map).
const RAMP_LIFT = 2;

// ---------------------------------------------------------------------------
// THE CROWN (v9) — the top of the map.
//
// PARITY IS THE WHOLE POINT. The spiral alternates sides per lap: an ODD lap
// climbs E then N and finishes on the NW landing; an EVEN lap climbs W then S
// and finishes on the SE landing. So the final landing's CORNER depends on
// LAPS' parity. v8's roof arrival was hardcoded to the odd case and silently
// vanished when LAPS became even. Here the crown is treated as ONE MORE LAP
// (CROWN_LAP = LAPS + 1) and every crown coordinate is written in the ODD
// frame, then point-mirrored through the tower axis by CM when the crown lap
// is even. Odd-frame crown = E flight up the east face, arriving on the NORTH
// apron; even-frame = the exact mirror (W flight, SOUTH apron). Both weld to
// whatever landing the spiral actually ended on.
// ---------------------------------------------------------------------------
const CROWN_LAP    = LAPS + 1;                  // the crown stair is "lap LAPS+1"
const CROWN_ODD    = ( CROWN_LAP % 2 === 1 );   // odd -> E flight, N arrival
const CM           = ( CROWN_ODD ? 1 : -1 );    // point-mirror factor for crown coords
const TOP2         = TOP + FLIGHT_RISE;         // 19392 — the crown level (terrace / causeway / hall floor)
// The route, in order (odd frame — all y's flip under CM):
//   CROWN STAIR  final landing -> TOP2, gold treads, up the east face
//   TERRACE      a 960x224 forecourt along the capital's north face; you arrive
//                at its east end and turn toward the causeway
//   CAUSEWAY     "the pathway" (user): 224 wide, 640 long, on-axis, three cyan
//                portal frames, glowing underside — over 19,000 units of air
//   CROWN HALL   "the crown house" (user): 1536 x 1536 open-top citadel,
//                576-tall walls, 4 corner towers + 3 pilaster spikes + a
//                twin-spired gate, cyan cornice, inverted-ziggurat underbelly
//                ending in a glowing gravity core. It FLOATS beside the tower.
//   MAST         on the core top: a 5-tier spire to TOP2+1920 with a red beacon
const TER_W        = 480;                       // terrace half-width (x)
const TER_Y1       = CORE, TER_Y2 = 480;        // terrace band (y): 224 deep off the capital face
// THE LAST MILE (v10, user 2026-08-23: "the road to the pyramid needs to be
// long ... they get ambushed in all directions"). The causeway is now the
// finale ARENA, not a connector, so it grew on BOTH axes:
//   LENGTH 640 -> 6400. The finale clock is the length of the closing song
//   (197s). Unopposed sprint is roughly 250 u/s, so 6400 is about 26s of pure
//   running — the rest of the song is the fight. Tune here, and re-run the LED
//   bake gate: this is the single biggest lit surface on the map now.
//   WIDTH 224 -> 576. A 224-wide bridge can only be attacked from ahead and
//   behind, which is the opposite of "ambushed in all directions". At 576 the
//   risers below can sit off-centre on alternating sides and there is room to
//   be flanked, to dodge, and to fight backwards.
// v10.9 (user 2026-08-23: "make the path to the castle very thin"). 576 -> 160
// wide, which is EXACTLY the tower's own stair width (PX 416 - CORE 256), so
// the road reads as one last flight rather than a plaza. This reverses the v10
// widening: that was mine, to make "ambushed in all directions" survivable on
// a bridge. The user has since asked for the opposite feel AND for spawns to
// come from AHEAD instead of the flanks (see the causeway risers below and
// _tod_endless_rounds::finale_spawn_selection), so the flanking room the width
// existed to provide is no longer what the encounter is built on. Rails stay:
// at 160 wide over 19,000 units of air, they are the difference between a
// gauntlet and a coin flip.
const CW_HALF      = 80;                        // causeway half-width (160 wide)
const CW_LEN       = 7360;                      // walked length exceeds this: the lanes climb, dive and jog
// THE ROAD WINDS AND FORKS — and since v12 every lane is a DIFFERENT shape
// (v10.11 user: "can twist and turn and go up and down ... split into
// multiple paths that converge. Lets be creative"; v12 user: "scary and
// anxious"). ONE shape description lives in this file and it is the one in
// SECTION 5c (ridge / broken stair -> THE NARROWS -> undercroft / plank /
// weave) — this header deliberately does not carry a second copy, because a
// second copy is how the v10.10 comment ended up describing a serpentine
// that no longer existed.
// FIRST AND LAST RUN ARE ON THE AXIS AT TOP2, and that is load-bearing: the
// entrance must line up with the terrace mouth where the gate stands, and the
// exit with the hall gate opening (x +/-GATE_HALF). A run ending off-axis or
// off-height would put players against the citadel south WALL, not its door.
// The full layout, the y-budget and the brush recipe live in section 5c.
// The road's own geometry constants (CW_LAT, CW_SWING, tread/rise, the grid)
// live in SECTION 5c with the code that uses them — they were up here when the
// road was a straight strip described by two numbers, and having half the shape
// 500 lines from the other half is how the v10.10 comment ended up describing a
// serpentine that no longer existed.
const HS           = TER_Y2 + CW_LEN;           // hall south outer face
const HW           = 768;                       // hall half-width           (1536 wide)
const HD           = 1536;                      // hall depth
const HN           = HS + HD;                   // hall north outer face     (2656)
const HYC          = ( HS + HN ) / 2;           // hall centre y             (1888)
const HWALL        = 40, HWALL_H = 576;         // wall thickness / height (unjumpable)
// v19.71 (the perch pass): the crown altar's and Pack-a-Punch's origin this far off the hall's
// inner wall face (was 64). The gold shrine panel behind each stands 4 proud of the wall and
// both meshes reach ~19 behind their origin, so each back now sits ~1 off its panel.
const CROWN_VENDOR_OFF = 24;
const CTOWER       = 192;                       // corner tower footprint (square)
const GATE_HALF    = 128, GATE_H = 256;         // gate opening (256 wide x 256 tall)
const POST_W       = 40;                        // gate post width
const RAIL_H       = PARA_H;                    // 56: chest-high rails everywhere up here + caps
const DAIS         = 112, DAIS_H = 16;          // uplink dais (16 = one step; 32 would need a jump)
const EXFIL_Y      = HN - HWALL - 224;          // extraction pad centre, north end of the hall
const EXFIL_HALF   = 80;                        // 160 sq pad (the 129-wide pad light sits on it)
const MAST_TIERS   = [ [ 512, 320 ], [ 384, 320 ], [ 256, 320 ], [ 128, 384 ], [ 48, 576 ] ];  // [width, height]
const MAST_TOP     = TOP2 + MAST_TIERS.reduce( ( a, t ) => a + t[ 1 ], 0 );   // TOP2 + 1920

// ---------------------------------------------------------------------------
// THE CIRCLET (v11, user 2026-08-25: "make the crown larger and more gold and
// look more like a crown ... It just looks like a castle with spikes. We can do
// so so so much better").
//
// WHAT WAS WRONG, MEASURED RATHER THAN FELT. Render the old citadel from the
// base arena (`node tools/preview_crown.js`, the `street`/`under` views) and it
// is a 1536-wide blue box with nine narrowing spires on it, standing on a navy
// underside. At the base-arena slant distance of 22,079 units, 1 degree of arc
// is 29.5 px and the legibility floor is about half a degree:
//
//     0.5 deg = 193 units.  1.0 deg = 385 units.  NOTHING NARROWER THAN ~384
//     UNITS CAN CARRY ANY PART OF THE READ FROM THE TOWER.
//
// The old gate spire tip was 20 units (0.05 deg, 1.5 px). The pilaster tip 24.
// The corner-tower tip 40. Six of the nine spires were at or under the vanishing
// threshold — the crown was one 4-degree box with hair on it, which is exactly
// what the user described.
//
// AND THE UNDERSIDE IS 60% OF THE PIXELS. Every sight line from the tower comes
// from the SOUTH and from BELOW, so the near (south) rim occludes the interior,
// the far rim and everything behind them for the whole climb. What a player on
// the street can actually see is three things: the UNDERSIDE, the SOUTH BAND's
// outer face, and the SOUTH RIM's points silhouetted against pure night sky.
// The old underside was MAT.ground (dark_blue_tinted) — almost exactly the
// atmosphere fog colour (_tod_atmosphere.gsc, 0.16 0.14 0.30) — so it rendered
// as a black square. That is why the crown had no pull.
//
// AND YOU CANNOT LIGHT IT. Every crown light is radius 460-900 (see the CL block
// down in the lights section); a 900-unit light does nothing for a 4096-unit
// object. THE EXTERIOR READ IS CARRIED BY MATERIAL, NOT BY LIGHT ENTITIES.
// Light entities up here exist only to make the RED points of the vertical
// axis bloom: the apex beacon, the great ruby, and (v12) the girandole.
//
// THE SHAPE. A rectangular gold circlet CENTRED ON THE HALL, so the play floor
// sits inside it the way a head sits inside a crown — 544 units of clear air on
// the y sides, 960 on the x sides, the band's bottom 832 BELOW the floor and its
// top 640 ABOVE the hall wall tops. The floor, the walls and everything the
// finale stands on DO NOT MOVE (user: "We dont need to edit the floor of the
// room or space"): every constant below is additive, outboard of |x|=HW and of
// y=[HS,HN], and the ring's inner faces clear the hall on all four sides.
//
// WHY A RECTANGLE AND NOT A SQUARE. Width is what you see; depth is invisible.
// A 4096-square ring would put its south rim 2048 in front of centre and bury
// its own monde behind that rim until floor ~35. At CR_HY 1632 the monde clears
// at floor 7 and the finial clears from the ground.
//
// WHY H/width = 1.61 AND NOT THE HERALDIC 1.4. From the base the elevation angle
// is 67 degrees, so vertical extent is foreshortened by cos(67) = 0.39. Building
// the true 1.4 would read as 0.55:1 — a squashed plate — from the street.
// Do not push past 1.7 or it becomes a papal tiara.
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// CR_SCALE — THE ONE KNOB (v11.1, user 2026-08-25: "I want the scale to be even
// more. I want players to be in awe when they see the crown.")
//
// 1.0 was the v11 crown: 4096 wide over the band, and from the base arena that
// is 10.6 deg of arc — big, correct, and not yet awe. At 1.4 the band is 5728
// and the real bounding box is 6128 (the east/west point HEADS stand proud of
// it), 13,888 tall overall: 14.8 deg, and 3.9x the width of the citadel this all
// started from. The generator PRINTS the measured box on every run — read it
// there rather than trusting this comment.
//
// AND 1.4 IS WHERE IT STOPS — FOR DESIGN REASONS, NOT BAKE ONES.
//
// ⚠️ THIS PARAGRAPH USED TO SAY THE OPPOSITE AND IT WAS WRONG. It read: "1.4 is
// where it stops, because the bake said so — the SAME 4,700 brushes bake in
// 38.2 s at 1.0 and 126.2 s at 1.4, 3.3x the time for ~2x the lit area… a step
// to 1.6 would plausibly be 250-300 s or trip brush.cpp:1860." **THE 126.2 s
// READING WAS TAKEN ONCE AND NEVER REPRODUCED.** The same map at 1.4 has since
// baked at 35.1, 31.9 and 31.8 s, and an A/B on byte-identical geometry
// differing only in material distribution came in at 31.3 s. Bake timing on this
// map is dominated by HOST STATE, not by map content, across everything
// measured. Read `_bake_test.ps1` as BAKED/CRASHED and nothing else; for the
// budget question run `node tools/measure_lit_area.js`, which is deterministic.
// Full series in docs/34 §8. (This correction is here because THIS is the file
// the next session reads before changing the crown — leaving the retracted
// number in the docs but not in the generator is how folklore survives.)
//
// The real reason 1.4 is the number: the crown reads correctly at 1.4 and the
// user signed the look off. What DOES constrain further growth is the ROAD —
// the pinned south face is 6912 against cwY[8] = 6880, a 32-unit margin, so any
// further scale-up throws the 5f.1 assert until the causeway is re-cut.
// If area ever does need buying back: `caulk` (noDraw and still solid, stock,
// used in Treyarch's own zm_giant.map source) on buried faces is the untouched
// lever, and it needs a per-face boxFaces() plus a deliberate
// lint_tod_geometry.js material entry.
//
// SCALE UNIFORMLY. Every proportion in the design was derived against the
// heraldic canon and against the 384-unit legibility floor, and the user has
// already signed off on how it LOOKS — so the correct way to make it bigger is
// to multiply, not to re-litigate ratios one at a time. `CS()` is the multiplier;
// it snaps to the 16-grid so nothing lands on a half unit.
//
// TWO THINGS DELIBERATELY DO NOT SCALE:
//   * BAND_T. Band thickness is the DEPTH OF THE TUNNEL the causeway walks
//     through. 320 is already the deepest passage in the map (the hall gate is
//     40); scaling it to 448 would deepen it for no visual gain, since you only
//     ever see the band's face, never its thickness.
//   * The south outer face, CR_S_FACE. It is pinned (see below).
// ---------------------------------------------------------------------------
const CR_SCALE     = 1.4;
const CS = ( v ) => Math.round( v * CR_SCALE / 16 ) * 16;   // scale, then snap to the 16-grid
// THE SOUTH FACE IS PINNED AND THE CROWN GROWS NORTH AROUND IT. The south band
// has to land inside the causeway's F APPROACH — the one stretch that is flat,
// on-axis, 160 wide and at TOP2 — and that stretch is only 800 deep, so there
// was no room to grow southward at all: at CR_HY 1632 the old ring was already
// within 32 units of the J4 merge. So the crown is no longer centred on the
// hall. It is anchored to the ROAD, and CR_CY floats north as it grows. Nobody
// can ever see that: every sight line is from the south, depth is invisible,
// and the hall's own walls occlude the ring's inner faces from inside.
const CR_S_FACE    = 6912;                      // south outer face (ermine) — PINNED to the road
const CR_HX        = CS(2048);                  // half-width  x  (2864 -> 5728 across the band at 1.4)
const CR_HY        = CS(1632);                  // half-depth  y  — see the road assert in 5f.1
const BAND_T       = 320;                       // ring wall thickness — NOT scaled, see above
const CR_CHAM      = CS(512);                  // true diagonal corner depth
const CR_ERM       = CS(64);                    // how far the ermine rim stands proud of the band
const CR_CY        = CR_S_FACE + CR_ERM + CR_HY;   // derived: the south face cannot move
// The vertical schedule, all relative to TOP2. The ratios these land on are the
// St Edward's canon to within 2% (band top 0.20 H, fleurs 0.44, crosses 0.55,
// arch springing 0.55, arch crown 0.72, monde centre 0.80, finial 1.00) — that
// is the point of the numbers, not something to tune away.
const CR_SKIRT_BOT = CS(-3136);                 // glowing core, the bottom of the velvet cap
const CR_ERM_Z1    = CS(-832), CR_ERM_Z2 = CS(-576);  // the ermine rim: the widest line in the silhouette
const CR_C1_Z      = CS(-40);                   // C1 spans CR_ERM_Z2 -> here (all of it below the road)
const CR_C2_Z      = CS(160), CR_C3_Z = CS(384), CR_C4_Z = CS(640);
const CR_RIM_Z     = CS(704);                   // top of the rim strip — above this there is ONLY sky and points
const CR_SHORT_TOP = CS(2112);                  // fleur-de-lis heads
const CR_TALL_TOP  = CS(2880);                  // crosses pattee — also the arch springing
const CR_FRONT_TOP = CS(3456);                  // the FRONT CROSS: taller than its neighbours
const CR_ARCH_CROWN= CS(3840);                  // where the two dipped arches meet the monde
const CR_MONDE_Z2  = CS(4864);
const CR_FINIAL_Z2 = CS(5760);
const CR_BEACON_Z2 = CS(6784);                  // the red star over the crown, visible from the base arena
const CROWN_TOP    = TOP2 + CR_BEACON_Z2;
const CROWN_BOT    = TOP2 + CR_SKIRT_BOT;
// The mouth: the causeway walks THROUGH the rim before it reaches the hall gate.
// Z IS DERIVED FROM THE BAND, NOT WRITTEN DOWN: the mouth is exactly courses C2
// and C3, so it can never drift out of the band as the schedule scales. The
// scale-up is a straight win here — the opening grows from 640x424 to 896x592.
const CR_MOUTH_HALF = CS(320);
const CR_MOUTH_Z1  = CR_C1_Z, CR_MOUTH_Z2 = CR_C3_Z;   // C1 and C4 stay continuous
// Outer envelope, INCLUDING the proud ermine — everything downstream derives
// from these two rather than from a literal.
const CR_OUT_X     = CR_HX + CR_ERM;            // 2112
const CR_OUT_Y     = CR_CY + CR_HY + CR_ERM;    // 10304 (north face, odd frame)

// ---------------------------------------------------------------------------
// THE ENDLESS SPIRE (docs/44, user 2026-08-29) — the post-victory endless
// tower: 100 laps of the SAME spiral grammar, far east in the void, reached
// only by the one-way ascension teleporter on the crown hall dais. Visible
// from the whole climb (user: "players should be able to see and wonder what
// that tower is") — it sits INSIDE the existing sky seal, ~9,500 units off
// the tower's east face, and its monochrome red glow lines are the mystery.
//
// SPIRE_ENABLED is the emission gate, agreed with the publish lane
// 2026-08-29: while false this file's output is BYTE-IDENTICAL to the
// pre-spire generator — no brush, no entity, no guid consumed, no
// _tod_spire_data.gsc written — so an accidental regen by any session can
// never leak half-finished spire geometry into a shipping build. The proof
// is mechanical (scratch-copy byte-diff), not a promise. Flip to true only
// when the spire lane wires up (docs/44 build-order).
const SPIRE_ENABLED = true;
const SP_X = 10240, SP_Y = 0;   // spire axis — due EAST: every odd lap's E flight faces it
// v17.69 (user 2026-09-05: "make the endless spire tower go to floor 70
// instead of 100 ... now its only 7 boss fights"): 100 -> 70. Seven hub
// halls (10..70), seven trials, the summit one gold flight above hub 70's
// hall — THE TOP, the future boss floor (extraction only for now, docs/105).
// SP_LAPS must stay EVEN (asserted below): a 71st regular floor between the
// last trial and the top would mean mirroring the whole summit block (6d)
// into the odd frame.
const SP_LAPS = 70;             // was 100 (v14.0 "a tower that goes up 100 floors") until v17.69
const SP_TOP = SP_LAPS * LAP_RISE;      // 26880
const SP_TOP2 = SP_TOP + FLIGHT_RISE;   // 27072 — summit deck (the crown-stair pattern)
const SP_DOOR_COST = 4725;      // v18.0 (user 2026-09-06: "lower the price of the doors by 25%"): 6300 x 0.75. LADDER: 3000 originally, 4500 v16.30, 9000 v17.10 ("double the price"), 6300 v17.70 ("cut by 30%"), 4725 here. Emitted into _tod_spire_data::door_cost() — a price change is a -GscOnly build
const SP_SUMMIT_COST = 7500;    // summit extraction (the roof door's price) — the chosen WIN
const SP_HUB_EVERY = 10;        // vendor hub balcony every 10th floor
const SP_ZONE_CHUNK = 5;        // floors per spawn zone (riser gating rides a script filter)
const SP_BEACON_H = 512;        // summit beacon mast above the deck
// THE SUMMIT ARENA (v17.70, user 2026-09-05: "the boss fight will be one
// panzer that has 2x flame size and range ... 50M health ... He will spawn in
// many elites and zombies"). The top is no longer a 512 plaza + apron: ONE
// deck SP_SM_HALF square (1408 wide) at the plaza's level (SP_TOP2, 16 thick,
// top SP_TOP2+SLAB — one step up from the stair's arrival, as before), with
// the summit stair's WELL cut out of its east side (x[CORE, PX+PARA] x
// y[-CORE, CORE] — the treads climb inside it), a full perimeter rail, a rail
// down the well's east side (the deck stands up to 208 above the low treads),
// four cover pillars, eight risers, the mast and the exfil pad where they
// were. It ROOFS the last hub's hall (the drum is 456 half, the deck 704):
// THE THRONE fights under the king's floor, 384 of headroom, a 152-tall open
// band above the drum wall — accepted, the arena needs the room more than the
// hall needs the sky. THE SUMMIT GATE (tod_spire_summit_gate) seals the
// stair's mouth on the hall-gate contract for the fight; the box, gate,
// king-drop and mark anchors are emitted to _tod_spire_data.gsc.
const SP_SM_HALF = 704;         // arena half-width (in_spire's 1500 bound asserted below)
const SP_SM_PILLARS = [[-520, -520], [-520, 520], [520, 520], [520, -520]];   // cover, clear of the stair well and the risers
const SP_SM_RISERS = [[-600, -200], [-600, 200], [-200, -600], [200, -600], [-200, 600], [200, 600], [600, -200], [600, 420]];
const SP_SM_KING_ORG = [-400, 0];   // the Warden King's drop (the west half, facing the stair)
const SP_SM_MARK = [-300, -300];    // the win's Max Ammo
// v19.71 (the perch pass): FLUSH against the arena's west rail, -620 -> -666 — the body's
// back edge sat 47 off the rail, a player-wide slot behind the crate on the King's deck.
const SP_SM_CRATE = { org: [-666, -320], yaw: 270 };   // 270 = CRATE_YAW_E (defined further down; asserted equal at the emission site)   // the 1000-point crate (user: "Ammo will be cost 1k at the top"), on the west edge facing east
const SP_SM_GATE_Y = 262;           // the gate's centre line, just north of the stair's top tread (y 224..256)
if (SP_SM_HALF + 100 > 1500) throw new Error('summit arena leaves the in_spire bound');
for (const [px, py] of SP_SM_PILLARS) {
  if (Math.abs(px) + 56 > SP_SM_HALF - PARA || Math.abs(py) + 56 > SP_SM_HALF - PARA) throw new Error('summit pillar off the deck');
  if (px + 56 > CORE && px - 56 < PX + PARA && py + 56 > -CORE && py - 56 < CORE) throw new Error('summit pillar in the stair well');
  for (const [rx, ry] of SP_SM_RISERS) if (Math.abs(rx - px) < 88 && Math.abs(ry - py) < 88) throw new Error(`summit riser ${rx},${ry} inside pillar ${px},${py}`);
}
for (const [rx, ry] of SP_SM_RISERS) {
  if (Math.abs(rx) > SP_SM_HALF - 64 || Math.abs(ry) > SP_SM_HALF - 64) throw new Error('summit riser off the deck');
  if (rx > CORE - 40 && rx < PX + PARA + 40 && ry > -CORE - 40 && ry < CORE + 40) throw new Error('summit riser in the stair well');
  if (Math.abs(rx) < 80 && Math.abs(ry) < 80) throw new Error('summit riser in the mast');
}
// Crate shelf (every non-hub floor): the mid landing is 160 sq with a riser in
// its centre and both other landings are door territory (a 96-radius door
// trigger owns each one), so "an ammo crate at every floor" needs its own
// ground: a 128x120 railed bump-out through a gap cut in the mid landing's
// outer parapet. Crate trigger at the shelf's far edge = 190u from the landing
// riser — the power-hall precedent (189u) for "no two things in one trigger".
const SP_SHELF_Y1 = 276, SP_SHELF_Y2 = 396;   // the parapet gap (odd frame)
const SP_SHELF_X1 = PX + PARA, SP_SHELF_X2 = PX + PARA + 128;   // 436..564
const SP_CRATE_LX = 526, SP_CRATE_LY = 336;   // crate org on the shelf (local, odd frame)
// ---------------------------------------------------------------------------
// THE WARDEN TRIALS — THE HUB HALL (v16.19, user 2026-09-02: "instead of a
// breather the hub battle should actually be inside the tower. so every 10
// floors the center of the tower open up for the battle"). Supersedes the
// v16.15 outside arena (a 928-square balcony off the SW landing) outright.
//
// At every hub lap the tower's centre OPENS: the core column stops at the
// hub's mid landing and resumes SP_RM_VOID_H higher, and a DRUM of walls
// (SP_RM_WALL_H tall, SP_RM_WALL outside the parapet line) encloses the whole
// cross-section. Inside: a hall floor at the hub landing level over the core
// footprint, the E and N galleries and the NW region (which roofs the W
// flight's lower half), the hub's own S flight climbing INSIDE the drum to
// the SE landing and door n+1 behind a full-length inner wall, and the NEXT
// lap's E and N flights running around the inside of the drum as galleries
// 192 and 384 up — you fight on the floor and watch the spiral continue
// overhead. Vendors on the walls, seven risers.
//
// v16.21 (user 2026-09-02, after the first run: "the entrance to get into the
// arena is tiny. And once players go in it should lock up. I was able to
// easily walk in and out"):
//   THE PORCH — the hall's SW corner steps DOWN alongside the W flight's top
//   five treads (one slab per tread, 12 apart), so treads 12..16 all open
//   east into the hall: a 160-wide stepped entrance instead of two treads'
//   worth (64). Its east and north sides are walled up to hall level + rail.
//   THE HALL GATE — a script_brushmodel across the porch's mouth (the x=-256
//   line, y[-236,-96]) on the crown door's Show+Solid+DisconnectPaths
//   contract, hidden until the trial seals it. v16.19 sealed door n one
//   flight BELOW the hall, which locked the floor but not the room — the
//   party walked out of the hall onto the stairs and read it as "no lock".
//   THE S FLIGHT'S INNER WALL now runs from the corner (x=-256): tread 1 was
//   left open as a second way in, which was also a second way OUT of a
//   sealed hall. The S flight is the SW landing's lane, outside the seal.
//   SEVEN LAYOUTS (ten until v17.69) — SP_RM_LAYOUTS below: every hub hall
//   has its own structure, colour and floor sigil (user: "I think its
//   horrible for players when things get stale"; 2026-09-05: "now its only 7
//   boss fights we can give the rooms more personality").
//
// Frame: the hall is authored around the TOWER AXIS (0,0) in the EVEN frame
// (every hub lap is even, asserted above). Materials: floor/inlays
// `_tinted_edge` (DECK); every wall, rail and pillar PLAIN (BLOCK) — a
// `_tinted` wall top is a floating deck to lint_tod_geometry. Dais tiers are
// DECK on purpose: 12-high steps the flood walks.
const SP_RM_OUT = PX + PARA;                  // 436 — the hall floor reaches the parapet line
const SP_RM_NOTCH_Y = 64;                     // the NW piece starts here: W-flight treads under it are i <= 6 (b + 72), 104 of headroom
const SP_RM_WALL = 20;                        // drum wall thickness, outside the parapet line
const SP_RM_VOID_H = LAP_RISE + FLIGHT_RISE;  // 576 — the core resumes at the next lap's NW landing (three flights up)
const SP_RM_WALL_H = SP_RM_VOID_H + PARA_H;   // 632 — flush with that landing's parapet tops
const SP_RM_BAND = [280, 320];                // gold band on the drum's outer face, above the hall floor
// THE PORCH: slabs for treads 16-k, k = 1..SP_RM_PORCH_N-1 (tread 16 is at hall
// level already), each at the tread's own height, x[-CORE, -CORE + PORCH_D]
const SP_RM_PORCH_N = 5;                      // treads 12..16 open into the hall (160 wide)
const SP_RM_PORCH_D = TREAD * (SP_RM_PORCH_N - 2);   // 96: how far the fan reaches into the hall (its deepest row has PORCH_N-2 slabs)
const SP_RM_PORCH_Y2 = -CORE + TREAD * SP_RM_PORCH_N;   // -96: the porch's north end (tread 12's north edge)
const SP_RM_GATE_H = 128;                     // the hall gate's height above hall level (the door slab's own)
const SP_RM_GATE_Y1 = -CORE + PARA;           // -236: the gate starts past the inner wall's corner run
// ---------------------------------------------------------------------------
// THE AMMO CRATE — ONE CONTRACT FOR EVERY CRATE IN THE MAP
// (v17.37 facing, v17.38 the rest; user 2026-09-04: "Lets do this one run and
// master ammo crates so we dont ever have to touch them again")
// ---------------------------------------------------------------------------
// A crate is FOUR things and every one of them is derived from ONE origin and
// ONE yaw, here: the facing, the occupancy box (its collision), the use
// trigger, and the model. Base, the four breathers, the crown, the spire arena,
// every spire shelf and every spire hub read this block — there is no other
// crate recipe, and _tod_ammo_crate.gsc reads the trigger numbers back out of
// GENERATED _tod_breather_data.gsc (crate_trig_out / crate_trig_r), so the
// script cannot drift from the table that asserts it.
//
// v19.69 (user 2026-10-02: "Replace the ammo crates with the new model from props
// (nikolai)"): every crate is `tod_ammo_chest`, Nikolai's case - since v19.69b his
// lidless Ammo Box V6 - built by tools/fan_props/build_fan_props.py TO THIS CONTRACT:
// front = local +Y (yaw + 90, the convention below, unchanged), the back edge on
// f1 = -37, 98 across (fitted to the trial halls' riser clearances), centred across.
// The chest is a wide case where the West crate was a deep one (64, 13u off-axis).
// FACING. west_ammo_crate_model's FRONT is the mesh's local -right, i.e.
// yaw + 90 — not the yaw - 90 every tower crate was authored against. v14.23
// already ran this experiment on the spire: the user's answer to "which crates
// face wrong" was "All of them", so all four spire yaws were flipped 180 and
// that entry closed with "verify by eye next run and record the winning
// convention at BR_FURN". The 2026-09-04 report ("Pap and ammo crate are not
// facing the center of the crown room" — the crown crate being a
// tower-convention crate on an EAST wall at yaw 270) was that verification.
const CRATE_YAW_N = 0;      // front = world +y — a crate whose wall is SOUTH of it
const CRATE_YAW_W = 90;     // front = world -x — wall EAST of it
const CRATE_YAW_S = 180;    // front = world -y — wall NORTH of it
const CRATE_YAW_E = 270;    // front = world +x — wall WEST of it
function crateFront(yaw) {
  const y = ((yaw % 360) + 360) % 360;
  if (y === CRATE_YAW_N) return [0, 1];
  if (y === CRATE_YAW_W) return [-1, 0];
  if (y === CRATE_YAW_S) return [0, -1];
  if (y === CRATE_YAW_E) return [1, 0];
  throw new Error(`crateFront: crate yaw ${yaw} is not one of the four cardinal CRATE_YAW_* values`);
}
// OCCUPANCY. The mesh is NOT centred on its origin: at CRATE_YAW_E it occupies
// x[-37,+38] y[-19,+45] (measured, zeroy_s4_ammo_crate at SetScale 2.5) — 13u
// off-axis along its wide side. The other three yaws are that box rotated about
// the origin, so every "ammo crate body" clip in the map is the mesh's real
// footprint at its real yaw. THEY DISAGREED BEFORE: the v14.23 flip turned four
// spire yaws and left every box at the yaw-270 occupancy (26u off the mesh),
// and the spire arena crate carried a script-clip row that ran FRONT-TO-BACK
// through the crate (AnglesToRight is the front at these yaws), planting an
// invisible lip in front of the face that held the player out of the trigger.
// v19.69: the box is tod_ammo_chest's — x[-37,33] (the case's back edge to its front)
// y[-49,49] (centred; the West crate's was y[-19,45]). Asserted against the chest's
// measured bounds right below, so a re-export cannot leave a part outside. v19.69b:
// Nikolai's Ammo Box V6 (lidless, 98 x 69 x 29) - the front came in 38 -> 33.
function crateBox(cx, cy, yaw) {
  const y = ((yaw % 360) + 360) % 360;
  const E = { x1: -37, x2: 33, y1: -49, y2: 49 };   // tod_ammo_chest (V6) at CRATE_YAW_E
  let b;
  if (y === CRATE_YAW_E)      b = E;
  else if (y === CRATE_YAW_W) b = { x1: -E.x2, x2: -E.x1, y1: -E.y2, y2: -E.y1 };   // 180: (x,y) -> (-x,-y)
  else if (y === CRATE_YAW_N) b = { x1: -E.y2, x2: -E.y1, y1: E.x1,  y2: E.x2  };   // +90 CCW: (x,y) -> (-y,x)
  else if (y === CRATE_YAW_S) b = { x1: E.y1,  x2: E.y2,  y1: -E.x2, y2: -E.x1 };   // -90:     (x,y) -> (y,-x)
  else throw new Error(`crateBox: crate yaw ${yaw} is not one of the four cardinal CRATE_YAW_* values`);
  return { x1: cx + b.x1, x2: cx + b.x2, y1: cy + b.y1, y2: cy + b.y2 };
}
const CRATE_BOX_H = 58;     // occupancy height above the crate's floor
// THE TRIGGER (v17.38, user: "check the trigger on all ammo crates. Some of them
// are off and you cant get ammo unless at a certain angle"). Every crate used
// to spawn its trigger_radius_use ON the model origin with radius 72 — and the
// occupancy box holds a player's origin >= 38 + ~16 (capsule) = 54u from that
// origin, so the usable band in front of the face was 54..72: EIGHTEEN UNITS,
// and only along the face's centre line. Stand naturally, or a little off-axis,
// and there was no prompt; the spire arena crate's invisible lip made it worse.
// The trigger now sits CRATE_TRIG_OUT in front of the origin — the stations'
// and PaP machines' own grammar (BR_FURN.pap/station trig = org + 56) — so the
// band runs from the face to ~128u out and ±72 across it. Radius unchanged.
//
// RE-CENTRED, RAISED AND WIDENED (2026-09-24, lead tester: "on the middle to far
// left side in front of the ammo box you cannot get a prompt to purchase ammo
// despite being right on it ... Almost like prompt ends half way through").
// v17.38 fixed the FRONT and left the two LONG SIDES — the faces players
// actually walk up to — half dead, for two reasons at once:
//   1. REACH. The circle was centred 56 out on the ORIGIN's line, and the box
//      is 13u off that line (crateBox). From the far end of a long side a
//      player's origin is ~99-108u from that centre: outside 72.
//   2. SIGHT. trigger_radius_use runs a sight trace to its origin (the API doc,
//      SetIgnoreEntForTrigger: "trigger sight traces"), and a clip brush blocks
//      it (the crown hall crate's dead trigger inside its clip column,
//      memory trigger-origin-under-decal). An origin 40 up in FRONT of the crate
//      is seen from the long sides THROUGH the 58-tall clip, so most of each
//      side failed even inside the radius.
// Now: centred on the box's own line (CRATE_TRIG_LAT), pulled in to 6u off the
// clip's front face, lifted to 60 (stock's own perk-machine trigger recipe,
// _zm_perks.gsc:1513, origin + 60 / height 80) so a standing player's sight line
// passes OVER the 58u clip top, radius 100 so both long sides are covered end to
// end. The back face is not covered on purpose: every crate backs onto a wall.
// The block below PROVES all of it at all four yaws, or the generator throws.
// v19.69: OUT 44 -> 38 and LAT 13 -> 0 for the wide chest. The long sides are now
// 65 from the centre line (49 + the 16 capsule), and from OUT 44 their back ends sat
// 104 away — outside the 100 radius the block below proves. On the front face line
// (38) the farthest standing spot is 99.2: covered, with the radius unchanged, so no
// vendor-spacing assert anywhere had to move. Still never inside its own clip (the
// check is strict) and still lifted over it.
// v19.69b: 38 -> 33 with V6's shallower case (the far long-side spot is then 95.5).
const CRATE_TRIG_OUT = 33;    // along the front: ON the clip's front face line (+33), lifted 60 above it
const CRATE_TRIG_LAT = 0;     // along the front turned +90: the box's centre line (the chest is centred)
const CRATE_TRIG_LIFT = 60;   // stock perk-trigger height; must clear CRATE_BOX_H
const CRATE_TRIG_R = 100;
// crateBox's yaw-270 occupancy in the crate's OWN frame (F = front, L = front
// turned +90 CCW). The block below checks this frame reproduces crateBox exactly.
const CRATE_LOCAL = { f1: -37, f2: 33, l1: -49, l2: 49 };
// THE MODEL MUST FILL THIS BOX AND NOT LEAVE IT (v19.69). tod_ammo_chest's local frame
// IS the crate frame: F = model +Y, L = model -X (front turned +90 CCW), floor at z 0.
// A part outside the box is a part players walk into; a box much bigger than the
// model is an invisible wall. Both are checked against the shipped binary's bounds.
{
  const ch = FAN_PROPS.chest;
  if (!ch || ch.model !== 'tod_ammo_chest') throw new Error('art/fan_props/manifest.json has no tod_ammo_chest — run tools/fan_props/build_fan_props.py');
  const [[x1, y1, z1], [x2, y2, z2]] = ch.bounds;
  const F = [y1, y2], L = [-x2, -x1];
  const tol = 0.05;
  if (F[0] < CRATE_LOCAL.f1 - tol || F[1] > CRATE_LOCAL.f2 + tol || L[0] < CRATE_LOCAL.l1 - tol || L[1] > CRATE_LOCAL.l2 + tol || z1 < -tol || z2 > CRATE_BOX_H)
    throw new Error(`tod_ammo_chest bounds F[${F}] L[${L}] z[${z1},${z2}] leave the crate box F[${CRATE_LOCAL.f1},${CRATE_LOCAL.f2}] L[${CRATE_LOCAL.l1},${CRATE_LOCAL.l2}] z[0,${CRATE_BOX_H}]`);
  if (F[0] - CRATE_LOCAL.f1 > 1.5 || CRATE_LOCAL.f2 - F[1] > 1.5 || L[0] - CRATE_LOCAL.l1 > 1.5 || CRATE_LOCAL.l2 - L[1] > 1.5)
    throw new Error(`crate box F[${CRATE_LOCAL.f1},${CRATE_LOCAL.f2}] L[${CRATE_LOCAL.l1},${CRATE_LOCAL.l2}] is more than 1.5u bigger than tod_ammo_chest F[${F}] L[${L}] — an invisible lip`);
}
function crateLat(yaw) {
  const f = crateFront(yaw);
  return [-f[1], f[0]];
}
function crateTrig(org, yaw) {
  const f = crateFront(yaw), l = crateLat(yaw);
  return [org[0] + f[0] * CRATE_TRIG_OUT + l[0] * CRATE_TRIG_LAT,
          org[1] + f[1] * CRATE_TRIG_OUT + l[1] * CRATE_TRIG_LAT];
}
// THE BUY SPOT is a separate thing from the trigger now. Floor-clearance asserts
// (hall features and sigils, the summit's risers and pillars) keep the v17.38
// "stand here to buy" footprint — 56 in front, 72 across — which every layout
// was built around. The TRIGGER (crateTrig / CRATE_TRIG_R) is what the engine
// spawns, and it is what the trigger-vs-trigger spacing asserts still measure:
// two vendor prompts overlapping is a real wrong-buy bug; scenery standing
// inside a wider prompt circle beside a crate is not.
const CRATE_BUY_OUT = 56;
const CRATE_BUY_CLEAR = 72;
function crateBuySpot(org, yaw) {
  const f = crateFront(yaw);
  return [org[0] + f[0] * CRATE_BUY_OUT, org[1] + f[1] * CRATE_BUY_OUT];
}
{
  const C = 16;   // the player's capsule, the v17.38 note's figure
  if (CRATE_TRIG_LIFT <= CRATE_BOX_H) throw new Error(`crate trigger lift ${CRATE_TRIG_LIFT} must clear the clip top ${CRATE_BOX_H}: an origin inside a brush never prompts`);
  for (const yaw of [CRATE_YAW_N, CRATE_YAW_W, CRATE_YAW_S, CRATE_YAW_E]) {
    const f = crateFront(yaw), l = crateLat(yaw), t = crateTrig([0, 0], yaw), b = crateBox(0, 0, yaw);
    const w = (F, L) => [f[0] * F + l[0] * L, f[1] * F + l[1] * L];
    const cs = [w(CRATE_LOCAL.f1, CRATE_LOCAL.l1), w(CRATE_LOCAL.f2, CRATE_LOCAL.l2)];
    const xs = cs.map(c => c[0]).sort((p, q) => p - q), ys = cs.map(c => c[1]).sort((p, q) => p - q);
    if (xs[0] !== b.x1 || xs[1] !== b.x2 || ys[0] !== b.y1 || ys[1] !== b.y2)
      throw new Error(`crate local frame disagrees with crateBox at yaw ${yaw}: every trigger number would be about the wrong crate`);
    if (t[0] > b.x1 && t[0] < b.x2 && t[1] > b.y1 && t[1] < b.y2)
      throw new Error(`crate trigger origin is inside its own clip at yaw ${yaw}`);
    const spots = [];
    for (let L = CRATE_LOCAL.l1 - C; L <= CRATE_LOCAL.l2 + C; L += 2) spots.push([CRATE_LOCAL.f2 + C, L]);   // the front face
    for (let F = CRATE_LOCAL.f1; F <= CRATE_LOCAL.f2 + C; F += 2) {                                         // both long sides, back to front
      spots.push([F, CRATE_LOCAL.l1 - C]);
      spots.push([F, CRATE_LOCAL.l2 + C]);
    }
    for (const [F, L] of spots) {
      const p = w(F, L);
      if (Math.hypot(p[0] - t[0], p[1] - t[1]) > CRATE_TRIG_R)
        throw new Error(`crate at yaw ${yaw}: a player at local (${F},${L}) stands outside the ${CRATE_TRIG_R}u trigger`);
    }
  }
}

// ---------------------------------------------------------------------------
// THE SHELL IS PER HALL TOO (v18.78, user 2026-09-10: "the layout of each trial
// is the same. Everyone just bunker up in the little cubby and withstands the
// trial. I dont want that to be allowed ... redesign each layer to be different
// not just in content but in layout too ... May require moving ammo and pap on
// each layer").
//
// Until this pass every hall shared ONE shell around its set-piece: the porch,
// the PaP on the W wall, the crate on the E wall, the same seven risers, the
// same respawn corner. And that shell had TWO three-walled pockets nothing ever
// spawned in — THE PORCH POCKET behind the sealed gate (x[-256,-160] y[-236,-96]:
// gate west, porch wall north, the S flight's inner wall south, one 140-wide
// mouth east, nearest riser ~300u) and THE SE ALCOVE under the SE landing
// (x[256,436] y[-436,-256], roofed at 176, one 180-wide mouth north — and
// OUTSIDE trial_box, so no riser, no elite landing and no player was ever
// counted there). v17.86's set-pieces then added their own: a caged pen with
// one 64-wide gate, a walled room with one door, a baffled lane. Seven halls,
// one answer: stand in the cubby, face the mouth.
//
// Now every layout owns its whole shell, and the shell is PROVEN open:
//   furn    { pap, crate } — which wall each vendor stands on (SP_PAP_AT /
//           SP_CRATE_AT presets W / N / E / S; facing derived per mesh)
//   risers  the hall's own riser set. EVERY pocket a layout leaves gets a
//           riser INSIDE it — the porch always gets two — so with
//           _tod_endless_rounds' follow-the-party pick (a trial's horde rises
//           at the risers nearest a random living player) whoever hides in a
//           pocket has the horde rising among them. A riser at a pocket's
//           MOUTH does not count: it feeds the funnel.
//   spawns  its respawn points (default SP_RM_SPAWN_XY, the N gallery; a hall
//           with a vendor on the N wall uses SP_RM_SPAWN_NW)
//   alcove  'seal' fills the SE alcove solid (a K.wall block to the landing's
//           underside); 'open' keeps it as a spawn closet with a riser inside —
//           the kennel, the crypt, the pit — and trial_box now includes it
//   f/sig   the set-piece, redrawn so no piece makes a bay: cover is an
//           ISLAND you circle (pillar, lamp, pinwheel wall, slalom baffle,
//           two-gate pen), never a room you enter
// tools/lint_tod_hall_bunkers.js proves the result on the EMITTED map: no
// three-walled spot (open arc under 80 degrees at 160u) without a riser inside
// it, in any hall. It runs on every full build beside the geometry lint, and
// its --png heatmaps are the design tool for the next pass.
// ---------------------------------------------------------------------------
// A machine's origin this far off the wall it backs. v16.19-v19.70: 60, which left a 41-unit
// slot behind every hub PaP (the ALXS cabinet reaches only 18.4 behind its origin) — a player
// fits in 30, and the hall bunker lint cannot see script collision, so nothing flagged it.
// v19.71 (the perch pass): 20 — the cabinet's back touches the drum, and its perch cap buries
// into it. LOCKSTEP with VENDOR_STANDOFF (the breather/crown figure, defined with BR_FURN).
const SP_VENDOR_OFF = 20;
// The ALXS PaP cabinet's FRONT is yaw - 90 (memory crate-and-pap-facing; the
// breather machines prove W/90, the breather station N/359.999). trig = org +
// 56 toward the front — the stations' grammar. r = the use radius.
const SP_PAP_AT = {
  W: y => ({ kind: 'pap', side: 'W', org: [-SP_RM_OUT + SP_VENDOR_OFF, y], trig: [-SP_RM_OUT + SP_VENDOR_OFF + 56, y], yaw: 90, r: 64 }),           // faces east
  N: x => ({ kind: 'pap', side: 'N', org: [x, SP_RM_OUT - SP_VENDOR_OFF], trig: [x, SP_RM_OUT - SP_VENDOR_OFF - 56], yaw: 359.999, r: 64 }),       // faces south
  E: y => ({ kind: 'pap', side: 'E', org: [SP_RM_OUT - SP_VENDOR_OFF, y], trig: [SP_RM_OUT - SP_VENDOR_OFF - 56, y], yaw: 270, r: 64 }),           // faces west
  S: x => ({ kind: 'pap', side: 'S', org: [x, -(CORE - PARA) + SP_VENDOR_OFF], trig: [x, -(CORE - PARA) + SP_VENDOR_OFF + 56], yaw: 180, r: 64 }),   // backs the S flight's inner wall, faces north
};
// The crate: THE ONE CONTRACT above (crateFront / crateBox / crateTrig); the
// body sits 3u off the wall it backs, exactly as the v17.38 hub crate did.
const crateAt = (side, org, yaw) => ({ kind: 'crate', side, org, trig: crateTrig(org, yaw), yaw, r: CRATE_TRIG_R,
  buy: crateBuySpot(org, yaw), clear: CRATE_BUY_CLEAR });   // buy/clear: the floor-clearance footprint (see crateBuySpot)
const SP_CRATE_AT = {
  W: y => crateAt('W', [-SP_RM_OUT + 40, y], CRATE_YAW_E),          // body x[-433,-358], faces east
  N: x => crateAt('N', [x, SP_RM_OUT - 40], CRATE_YAW_S),           // body y[358,433], faces south
  E: y => crateAt('E', [SP_RM_OUT - 40, y], CRATE_YAW_W),           // body x[358,433], faces west (the v17.38 hub crate)
  S: x => crateAt('S', [x, -(CORE - PARA) + 40], CRATE_YAW_N),      // body y[-233,-158], faces north
};
// a vendor's footprint for the asserts: the crate's measured body; the cabinet
// as its three colliders (+-32 along the wall axis, pap_place_clips) = +-56
// along the wall, +-28 across it
// v19.71: the cabinet's BACK is its mesh (the ALXS xmodel reaches 18.4 behind its origin, and
// the machine is flush to its wall since the perch pass); its FRONT keeps the colliders' 28.
const PAP_VEND_BACK = 19, PAP_VEND_FRONT = 28;
function vendBox(v) {
  if (v.kind === 'crate') { const b = crateBox(v.org[0], v.org[1], v.yaw); return [b.x1, b.x2, b.y1, b.y2]; }
  const [x, y] = v.org;
  if (v.side === 'W') return [x - PAP_VEND_BACK, x + PAP_VEND_FRONT, y - 56, y + 56];
  if (v.side === 'E') return [x - PAP_VEND_FRONT, x + PAP_VEND_BACK, y - 56, y + 56];
  if (v.side === 'N') return [x - 56, x + 56, y - PAP_VEND_FRONT, y + PAP_VEND_BACK];
  return [x - 56, x + 56, y - PAP_VEND_BACK, y + PAP_VEND_FRONT];   // S: backs the S flight's inner wall
}
const SP_FURN_DEFAULT = { pap: SP_PAP_AT.W(200), crate: SP_CRATE_AT.E(120) };   // the v16.19 shell: PaP W wall, crate E wall
// Respawn points: the N gallery by default; the NW region for a hall whose
// N wall carries a vendor.
const SP_RM_SPAWN_XY = [[60, 360], [140, 360], [60, 396], [140, 396]];
const SP_RM_SPAWN_NW = [[-380, 320], [-300, 320], [-380, 390], [-300, 390]];   // the NW region's north half (40 inside every edge)
// The three porch risers every layout carries — two on the fan's hall-level
// rows, at the back of the pocket and at its mouth (the fan's diagonal is why
// the back one sits at x -192 and not deeper: onHallFloor at 32 is the proof),
// and one in THE DOORWAY'S CORNER just north of the porch wall, where that wall
// meets the W flight's rail: a 160-deep L that turns anything a layout puts on
// the hall's west side into a north-facing slot (the lint found it in five of
// seven halls). A shell corner gets a shell riser.
const SP_RM_PORCH_RISERS = [[-192, -216], [-128, -136], [-210, -10]];
const SP_RM_ALCOVE_RISER = [340, -340];   // an OPEN alcove's riser, inside it
// THE APPROACH: the porch's mouth into the hall (east of the porch, south of
// the notch rail) stays clear of every feature so the doorway never opens
// onto a wall — x[-CORE, -80] x y[-CORE, PORCH_Y2].
const SP_RM_APPROACH = { x1: -CORE, x2: -80, y1: -CORE, y2: SP_RM_PORCH_Y2 };
// The hall-level floor as boxes (mirrors the emitter's slabs). The fan's lower
// steps are NOT hall level: no riser or respawn may stand on one.
const SP_RM_FLOOR = [
  [-SP_RM_OUT, -CORE, SP_RM_NOTCH_Y, SP_RM_OUT],       // NW region
  [-CORE, CORE, -CORE, -CORE + TREAD],                 // S strip (tread 16's level)
  [-CORE, CORE, SP_RM_PORCH_Y2, SP_RM_OUT],            // core + N
  [CORE, SP_RM_OUT, -SP_RM_OUT, SP_RM_OUT],            // E gallery + the SE alcove
  ...Array.from({ length: SP_RM_PORCH_N - 1 }, (_, i) => [-CORE + TREAD * i, CORE, -CORE + TREAD * (i + 1), -CORE + TREAD * (i + 2)]),   // the porch rows at hall level
];
// every point of the m-square round (x,y) lies on hall-level floor (and not in
// a sealed alcove)
const onHallFloor = ([x, y], m, L) => {
  if (L && L.alcove === 'seal' && x > CORE - m && y < -CORE + m) return false;
  const pts = [[x - m, y - m], [x + m, y - m], [x - m, y + m], [x + m, y + m], [x, y]];
  return pts.every(([px, py]) => SP_RM_FLOOR.some(b => px >= b[0] && px <= b[1] && py >= b[2] && py <= b[3]));
};
// ---------------------------------------------------------------------------
// SEVEN LAYOUTS (v17.86: one STORY per hall — user 2026-09-05: "I want each
// one to have its own personality ... should be a story for each"; v18.78:
// one SHELL per hall and no pocket anywhere — see the block above). One per
// hub, in hub order. Feature vocabulary:
//   ['pillar', x, y]            96 sq x 192 cover pillar (gold plinth, HUE shaft, gold cap)
//   ['post',   x, y]            48 sq x 240 pylon (thin cover, sight-line breaker)
//   ['wall',   x1, y1, x2, y2]  a LOW wall, PARA thick, PARA_H tall + a clip cap (unhoppable, shoot over it)
//   ['twall',  x1, y1, x2, y2]  a TALL wall, PARA thick, SP_RM_TWALL_H tall + clip cap (you cannot see over it)
//   ['fence',  x1, y1, x2, y2]  a line of BARS: 16-sq posts at 32 pitch (16 gaps — nothing fits
//                               through, bullets do) on a gold sill, SP_RM_FENCE_H tall + clip cap
//   ['lamp',   x, y]            a glowing PYLON in the hall's colour, 24 sq x 200 on a gold foot
//   ['plat',   x1, x2, y1, y2]  a raised STEP, 12 high, DECK in the hall's step material
//   ['dais',   x, y, tiers]     a stepped platform: tier k (1..tiers) is a 12-high step,
//                               half-size shrinking 44 per tier; DECK tops, all steps
//   ['throne', x, y]            two 12-high tiers (half 88 / 44) with a SEAT on top: gold arms,
//                               a back to 184 in the hall's wall colour. The boss lands on it.
//   ['big',    x, y, half]      a square pillar of any half-size, 240 tall
//   ['lintel', x1, y1, x2, y2]  an OVERHEAD gold beam, cap to cap between two PILLARS of this
//                               layout (endpoints must be pillar centres) at z 168..192 — no
//                               footprint, nothing stands under it but air
//   ['panel',  side, a1, a2, z1, z2 [, 'crest']]  a glowing plaque on the drum's inner face
//                               ('N' spans x, 'W' spans y), 8 proud, in the hall's panel
//                               material — or, with 'crest', the hall's CREST image (docs/110)
//                               mapped once onto it. The wall liner is split around it.
// Per-layout `mark` (where the win's Max Ammo lands; the inlay) and `warden`
// (the boss's forced drop point; asserted clear of every SOLID feature by 80,
// but it MAY land on a dais / plat / throne — that is the point of those).
//
// PERSONALITY, THE WHOLE KIT (v17.86):
//   hue     the hall's light colour — the central pool AND the four corner
//           pools take it (6g).
//   kit     SP_HALL_KIT[hue]: the hall FLOOR (every slab incl. the porch fan),
//           the inner WALLS (porch wall, notch rails, the S flight's inner
//           wall, the galleries' rails, every pillar shaft, every wall
//           feature) and a LINER band on the drum's W / N / E inner faces, the
//           LAMP pylons, the PANEL plaques, the STEP material and the SIGIL
//           inlay — all in the hall's colour family. The drum's OUTER faces
//           and the gold band stay as they were, so the tower still reads
//           "gold ring every 10th" from outside.
//   sig     the floor SIGIL: 1u-proud inlay boxes [x1,x2,y1,y2] in kit.sig,
//           asserted clear of every feature, the mark, the approach lane and
//           the vendor triggers; risers/spawns may sit on an inlay (floor).
// THE PACK IS TWO TEXTURES AND A BRIGHTNESS LADDER (memory
// vertigo-pack-is-two-textures): plain = black tiles + a bright grid line
// (15), _tinted = filled glow (10), _tinted_edge = the same at half (5).
// Contrast between two surfaces is TEXTURE + BRIGHTNESS, never hue alone —
// so every kit pairs a filled floor with a plain-grid wall, and its sigil
// is a step up the ladder from its floor. Only these 30 names exist
// (cyan/purple/pink have no _tinted_edge; white has no tinted form at all);
// the linker substitutes an invented name SILENTLY, and lint_tod_geometry
// classes floor-vs-wall by the NAME, so every entry below is one it knows.
// The trial banners (docs/105) carry the same seven colours; the fight for
// each hall is _tod_spire.gsc's trial_recipe, matched by index. Stories and
// plan views: docs/109_trial_halls_personality.md (rooms), docs/128 (shells).
// ---------------------------------------------------------------------------
const SP_HUE = {   // light colour strings (the `light()` grammar)
  gold:   '1 0.85 0.35',
  green:  '0.4 1 0.5',
  cyan:   '0.35 0.85 1',
  purple: '0.7 0.4 1',
  orange: '1 0.55 0.2',
  white:  '0.95 0.95 1',
  red:    '1 0.3 0.3',
};
const VM = 'mwiii_vertigo_retro_synth_';
const SP_HALL_KIT = {
  //         floor (DECK, every slab)   wall (plain grid)   lamp (filled)          panel (filled)         step (DECK)             sig (1u inlay)
  gold:   { floor: VM + 'yellow_tinted_edge', wall: VM + 'yellow', lamp: VM + 'yellow_tinted', panel: VM + 'yellow_tinted', step: VM + 'yellow_tinted', sig: VM + 'yellow_tinted' },
  green:  { floor: VM + 'green_tinted_edge',  wall: VM + 'green',  lamp: VM + 'green_tinted',  panel: VM + 'green_tinted',  step: VM + 'green_tinted',  sig: VM + 'green_tinted' },
  cyan:   { floor: VM + 'cyan_tinted',        wall: VM + 'cyan',   lamp: VM + 'cyan_tinted',   panel: VM + 'cyan_tinted',   step: VM + 'yellow_tinted', sig: VM + 'cyan' },
  purple: { floor: VM + 'purple_tinted',      wall: VM + 'purple', lamp: VM + 'purple_tinted', panel: VM + 'purple_tinted', step: VM + 'yellow_tinted', sig: VM + 'purple' },
  orange: { floor: VM + 'orange_tinted_edge', wall: VM + 'orange', lamp: VM + 'orange_tinted', panel: VM + 'orange_tinted', step: VM + 'orange_tinted', sig: VM + 'orange_tinted' },
  // white has no filled form: a cold navy floor under white light, white grid walls, white bars for lamps
  white:  { floor: VM + 'dark_blue_tinted',   wall: VM + 'white',  lamp: VM + 'white',         panel: VM + 'white',         step: VM + 'blue_tinted',   sig: VM + 'white' },
  red:    { floor: VM + 'red_tinted_edge',    wall: VM + 'red',    lamp: VM + 'red_tinted',    panel: VM + 'red_tinted',    step: VM + 'red_tinted',    sig: VM + 'red_tinted' },
};
const SP_RM_TWALL_H = 160;   // a tall wall: over a standing player's eyes (view height ~60), under the gallery flights
const SP_RM_FENCE_H = 128;   // bars: chest-and-a-half; you see and shoot through, nothing climbs
const SP_RM_LAMP_H = 200;
const SP_RM_LINER = { z1: 24, z2: 248, ez2: 152, t: 8 };   // the drum liner band; E stops under the E gallery's first parapet (bottom at mid+204)
// ---------------------------------------------------------------------------
// v18.80 THE ROOMS — ROOM-SCALE VOCABULARY (user 2026-09-10, after playing the
// first three: "I can barely tell what unique changes you made that would
// improve players experiences and better uniquely design each trial"). The
// v17.86 / v18.78 pieces were furniture in the middle of an 872-square room:
// four pillars, three pens, two arcades — the same room seven times with
// different ornaments. These kinds change the SHAPE OF THE SPACE you fight in,
// and add HEIGHT where the drum allows it.
//   ['stage', x, y, half, h]          a raised fighting STAGE: a `half`-square top at h (a multiple of
//                                     12) with a stepped SKIRT all round — one 12-high, 32-wide tier per
//                                     12 of height — so the horde climbs it from every side and no edge
//                                     is a drop the geometry lint would call unguarded.
//   ['deck', x1, x2, y1, y2, h, E]    a raised PLATFORM, top at h (a multiple of 12); E names every
//                                     edge: { S: 'stair'|'rail'|'flush', N, W, E }. 'stair' = h/12 treads,
//                                     12 high and 32 deep, running OUT from that edge (their own sides
//                                     get stepped rails unless they lie on the liner); 'rail' = a parapet
//                                     in the column beside the edge, floor to h + PARA_H, clip-capped —
//                                     the geometry lint's guard, and the reason the platform is a firing
//                                     PARAPET from the floor side; 'flush' = the edge lies ON the drum's
//                                     liner (x = +-428 or y = 428, asserted). Nothing else: an unrailed
//                                     drop is the geometry lint's unguarded edge.
//   ['seat', x, y, lift]              THE THRONE's seat alone (tier 2 + seat + arms + back) standing on a
//                                     deck top at `lift` (asserted = that deck's h).
// A `risers` entry that lies on a deck / stage TOP (32 inside it) is emitted ON
// it: the horde rises up there too, which is what keeps a platform from being
// the cubby the v18.78 pass exists to forbid (tools/lint_tod_hall_bunkers.js
// now scans every standable level to +140, not just the hall floor).
const RM_DECK_EDGES = ['S', 'N', 'W', 'E'];
const RM_LINER_X = SP_RM_OUT - SP_RM_LINER.t;   // 428: the drum's inner face, liner included
function deckParts(ft) {
  const [, x1, x2, y1, y2, h, E] = ft;
  const n = h / 12, run = 32 * n;
  const parts = { top: [x1, x2, y1, y2], stairs: [], rails: [], flush: [] };
  for (const side of RM_DECK_EDGES) {
    const e = (E || {})[side];
    if (e === 'stair') {
      // the run's box, the direction of CLIMB, and its two long sides (rails unless on the liner)
      if (side === 'S') parts.stairs.push({ box: [x1, x2, y1 - run, y1], dir: 'N', sides: [['W', [x1 - PARA, x1, y1 - run, y1]], ['E', [x2, x2 + PARA, y1 - run, y1]]] });
      if (side === 'N') parts.stairs.push({ box: [x1, x2, y2, y2 + run], dir: 'S', sides: [['W', [x1 - PARA, x1, y2, y2 + run]], ['E', [x2, x2 + PARA, y2, y2 + run]]] });
      if (side === 'W') parts.stairs.push({ box: [x1 - run, x1, y1, y2], dir: 'E', sides: [['S', [x1 - run, x1, y1 - PARA, y1]], ['N', [x1 - run, x1, y2, y2 + PARA]]] });
      if (side === 'E') parts.stairs.push({ box: [x2, x2 + run, y1, y2], dir: 'W', sides: [['S', [x2, x2 + run, y1 - PARA, y1]], ['N', [x2, x2 + run, y2, y2 + PARA]]] });
    } else if (e === 'rail') {
      if (side === 'S') parts.rails.push([x1, x2, y1 - PARA, y1]);
      if (side === 'N') parts.rails.push([x1, x2, y2, y2 + PARA]);
      if (side === 'W') parts.rails.push([x1 - PARA, x1, y1, y2]);
      if (side === 'E') parts.rails.push([x2, x2 + PARA, y1, y2]);
    } else if (e === 'flush') parts.flush.push(side);
    else throw new Error(`deck ${ft.slice(1, 6)}: edge ${side} must be 'stair', 'rail' or 'flush' (it is ${e})`);
  }
  // a stair's long side is a rail unless it lies on the liner
  for (const st of parts.stairs) {
    st.sideRails = [];
    for (const [sside, sb] of st.sides) {
      const onLiner = (sside === 'N' && sb[2] >= RM_LINER_X) || (sside === 'S' && sb[3] <= -RM_LINER_X) || (sside === 'W' && sb[1] <= -RM_LINER_X) || (sside === 'E' && sb[0] >= RM_LINER_X);
      if (!onLiner) { parts.rails.push(sb); st.sideRails.push(sb); }
    }
  }
  return parts;
}
// a deck stair's treads: tread t (1..n) is 12t high; the highest stands against the deck
function deckTreads(st, n) {
  const [bx1, bx2, by1, by2] = st.box, out = [];
  for (let t = 1; t <= n; t++) {
    let b;
    if (st.dir === 'N') b = [bx1, bx2, by1 + 32 * (t - 1), by1 + 32 * t];
    if (st.dir === 'S') b = [bx1, bx2, by2 - 32 * t, by2 - 32 * (t - 1)];
    if (st.dir === 'E') b = [bx1 + 32 * (t - 1), bx1 + 32 * t, by1, by2];
    if (st.dir === 'W') b = [bx2 - 32 * t, bx2 - 32 * (t - 1), by1, by2];
    out.push({ box: b, h: 12 * t });
  }
  return out;
}
// a stage's tiers, bottom-up: tier t (1..n) has half `half + 32 (n - t)` and spans z 12(t-1)..12t
function stageTiers(ft) {
  const [, x, y, half, h] = ft, n = h / 12, tiers = [];
  for (let t = 1; t <= n; t++) { const hh = half + 32 * (n - t); tiers.push({ box: [x - hh, x + hh, y - hh, y + hh], z1: 12 * (t - 1), z2: 12 * t }); }
  return tiers;
}
// the TOP of a deck / stage (the standable, spawnable, landable part)
const rmTopBox = ft => (ft[0] === 'deck') ? deckParts(ft).top : (ft[0] === 'stage') ? [ft[1] - ft[3], ft[1] + ft[3], ft[2] - ft[3], ft[2] + ft[3]] : null;
function rmDeckTopOf(L, pt, m) {
  return L.f.find(ft => { const t = rmTopBox(ft); return t && pt[0] >= t[0] + m && pt[0] <= t[1] - m && pt[1] >= t[2] + m && pt[1] <= t[3] - m; });
}
// THE KENNEL's pens: a barred box with `gates` = { side: [a1, a2] } openings along that side.
// Every segment comes out a multiple of 32 (the fence rule) when the box and the
// gates are — the assert below says so if not.
function kennelPen(x1, x2, y1, y2, gates) {
  const out = [];
  const seg = (side, a1, a2) => {
    if (a2 <= a1) return;
    if (side === 'S') out.push(['fence', a1, y1, a2, y1]);
    if (side === 'N') out.push(['fence', a1, y2, a2, y2]);
    if (side === 'W') out.push(['fence', x1, a1, x1, a2]);
    if (side === 'E') out.push(['fence', x2, a1, x2, a2]);
  };
  for (const side of RM_DECK_EDGES) {
    const [lo, hi] = (side === 'S' || side === 'N') ? [x1, x2] : [y1, y2];
    const g = (gates || {})[side];
    if (!g) seg(side, lo, hi); else { seg(side, lo, g[0]); seg(side, g[1], hi); }
  }
  return out;
}
const SP_RM_LAYOUTS = [
  // I — THE RING (gold, floor 10): THE STAGE. A raised fighting stage — a 200-
  // square top 48 up with a stepped skirt on all four sides — fills the middle
  // of the room; four gold-footed lamps mark its corners. You fight ON it and
  // the horde climbs it from every side at once: there is no wall to put your
  // back to, only the edge. The Warden lands on the stage with you.
  // SHELL: PaP west, crate on the E wall's south end, respawn NW, alcove sealed.
  { name: 'THE RING',        hue: 'gold',
    mark: [90, 140],  warden: [90, 140],
    furn: { pap: SP_PAP_AT.W(200), crate: SP_CRATE_AT.E(-180) }, alcove: 'seal', spawns: SP_RM_SPAWN_NW,
    risers: [...SP_RM_PORCH_RISERS, [-300, 200], [-290, 100], [-200, 60], [-100, 400], [90, 402], [250, 400], [404, 404], [380, 250], [400, -10], [200, -200], [0, -200]],
    f: [['stage', 90, 140, 100, 48],
        ['lamp', -170, -70], ['lamp', 350, -70], ['lamp', -170, 350], ['lamp', 350, 350],
        ['panel', 'N', -128, 128, 120, 248, 'crest']],
    sig: [] },
  // II — THE KENNEL (green, floor 20): THE CAGE BLOCK. Six barred pens in two
  // rows of three, with a central spine and cross corridors between them — the
  // whole floor is kennels and the corridors that serve them. Every pen has a
  // riser inside and two gates: the horde comes OUT of the cages into the
  // corridors you are standing in. The alcove is the seventh kennel. The
  // Warden drops in the south yard, right in front of the door.
  // SHELL: PaP on the E wall's south end, crate west, respawn NW, alcove open.
  { name: 'THE KENNEL',      hue: 'green',
    mark: [-20, -160], warden: [140, -190],
    furn: { pap: SP_PAP_AT.E(-200), crate: SP_CRATE_AT.W(160) }, alcove: 'open', spawns: SP_RM_SPAWN_NW,
    // v19.69: the W wall riser (-400,100) -> (-310,100). Nikolai's chest is 98 across
    // (the West crate was 64) and could not fit between it and (-370,250) with the
    // 32u riser clearance on both sides; moved off the crate's wall line instead of
    // moving the crate, which has nowhere else to go in a hall of pens.
    risers: [...SP_RM_PORCH_RISERS, SP_RM_ALCOVE_RISER, [-96, -8], [-96, 248], [112, -8], [112, 248], [336, -8], [336, 248], [-370, 250], [-310, 100], [0, 404], [-40, -200]],
    f: [...kennelPen(-144, -48, -88, 72,  { E: [8, 72],    W: [-88, -24] }),
        ...kennelPen(-144, -48, 168, 328, { E: [264, 328], W: [168, 232] }),
        ...kennelPen(48, 176, -88, 72,    { W: [8, 72],    E: [-88, -24] }),
        ...kennelPen(48, 176, 168, 328,   { W: [264, 328], E: [168, 232] }),
        ...kennelPen(272, 400, -88, 72,   { W: [8, 72],    S: [272, 336] }),
        ...kennelPen(272, 400, 168, 328,  { W: [168, 232], N: [336, 400] }),
        ['lamp', 40, -220], ['lamp', -300, 260],
        ['panel', 'N', -128, 128, 120, 248, 'crest']],
    sig: [[-132, -60, -76, 60], [-132, -60, 180, 316], [60, 164, -76, 60], [60, 164, 180, 316], [284, 388, -76, 60], [284, 388, 180, 316]] },
  // III — THE FIRING LINE (cyan, floor 30): THE LINE. A raised firing platform
  // runs the WHOLE width of the north wall, 48 up behind a chest-high parapet,
  // with a stair at each end — wall to wall, so the only ways up are the two
  // stairs. Below it the FIELD: an arcade of three pillars under beams, two lit
  // lanes on the floor, the target plaques on the wall above the line. Hold the
  // line and the horde runs the field to the stairs; a riser on the line itself
  // means it never holds for long. The Warden lands in the field.
  // SHELL: PaP on the E wall's south end, crate on the S flight's wall, respawn
  // in the SE (the N gallery is the platform now), alcove sealed.
  { name: 'THE FIRING LINE', hue: 'cyan',
    mark: [0, 344],   warden: [60, -72],
    furn: { pap: SP_PAP_AT.E(-200), crate: SP_CRATE_AT.S(60) }, alcove: 'seal', spawns: [[330, -60], [390, -60], [330, 20], [390, 20]],
    risers: [...SP_RM_PORCH_RISERS, [0, 392], [-370, 400], [370, 400], [-200, -60], [-60, -200], [180, -200], [60, 200], [-300, 180], [-380, 120], [300, 180], [400, 120]],
    f: [['deck', -172, 172, 260, 428, 48, { W: 'stair', E: 'stair', S: 'rail', N: 'flush' }],
        ['pillar', -120, 70], ['pillar', 60, 70], ['pillar', 240, 70],
        ['lintel', -120, 70, 60, 70], ['lintel', 60, 70, 240, 70],
        ['lamp', -360, 200], ['lamp', 400, 200],
        ['panel', 'N', -128, 128, 120, 248, 'crest'], ['panel', 'N', -368, -272, 72, 232], ['panel', 'N', -240, -144, 72, 232]],
    sig: [[-60, -44, -60, 200], [160, 176, -60, 200]] },
  // IV — THE ALTAR (purple, floor 40): THE HIGH ALTAR. A railed altar platform
  // 48 up stands across the middle of the room with a stair at each end — a
  // raised chancel 160 wide and 416 long that splits the hall in two — with
  // four candle pylons at its corners and the altar screen (two pillars, a
  // beam, the crest) behind it. The Wardens land on the altar; the only high
  // ground there is, and the horde takes both stairs to reach it.
  // SHELL: PaP east, crate west, respawn NW, alcove open — THE CRYPT.
  { name: 'THE ALTAR',       hue: 'purple',
    mark: [60, 40],   warden: [60, 40],
    furn: { pap: SP_PAP_AT.E(-160), crate: SP_CRATE_AT.W(116) }, alcove: 'open', spawns: SP_RM_SPAWN_NW,   // v19.69: 120 -> 116, the 98-wide chest clears riser (-340,200)
    risers: [...SP_RM_PORCH_RISERS, SP_RM_ALCOVE_RISER, [-340, 200], [-300, 100], [-190, 40], [-120, 180], [260, 180], [-60, 392], [60, 300], [340, 300], [380, 390], [340, 200], [400, -40], [60, -160]],
    f: [['deck', -20, 140, -40, 120, 48, { W: 'stair', E: 'stair', S: 'rail', N: 'rail' }],
        ['lamp', -60, -100], ['lamp', 200, -100], ['lamp', -60, 180], ['lamp', 200, 180],
        ['pillar', -60, 280], ['pillar', 180, 280], ['lintel', -60, 280, 180, 280],
        ['panel', 'N', -128, 128, 120, 248, 'crest']],
    sig: [] },
  // V — THE MAZE (orange, floor 50): THE LABYRINTH. Two square rings of tall
  // walls you cannot see over, one inside the other, each a pinwheel with its
  // four openings at alternating corners — so getting from the door to the
  // heart is two half-circuits through blind corners, and every corridor has
  // two ends. The heart holds the mark and a riser. An orange thread on the
  // floor points at the first opening. The Warden drops in the NW region.
  // SHELL: PaP on the S flight's wall, crate west, respawn N, alcove sealed.
  { name: 'THE MAZE',        hue: 'orange',
    mark: [90, 110],  warden: [-340, 160],
    furn: { pap: SP_PAP_AT.S(200), crate: SP_CRATE_AT.W(300) }, alcove: 'seal',
    risers: [...SP_RM_PORCH_RISERS, [90, 110], [-400, 400], [-180, 380], [-20, 392], [240, 392], [380, 300], [400, -100], [320, -220], [-80, 260], [250, -60], [-300, 180], [-400, 200], [300, -140]],
    f: [['twall', -10, 10, 90, 10], ['twall', 190, 10, 190, 110], ['twall', 90, 210, 190, 210], ['twall', -10, 110, -10, 210],
        ['twall', -60, -120, 120, -120], ['twall', 320, 0, 320, 220], ['twall', 60, 310, 320, 310], ['twall', -140, -20, -140, 190],
        ['lamp', -200, 300], ['lamp', 380, -20],
        ['panel', 'N', -128, 128, 120, 248, 'crest']],
    sig: [[-72, -56, -236, -160], [-56, 110, -168, -152]] },
  // VI — THE GAUNTLET (white, floor 60): THE RUN. Three tall walls comb the
  // room — one up from the south wall, one down from the north wall, one free
  // in the east — so the way from the door to the finish is a serpentine: west
  // lane north, over the first wall's end, under the second, up the east lane
  // to the raised FINISH step in the NE corner where the three Wardens come
  // down. Four white runway lamps mark the turns. The alcove, THE PIT, rises.
  // SHELL: PaP north, crate on the S flight's wall, respawn NW, alcove open.
  { name: 'THE GAUNTLET',    hue: 'white',
    mark: [-60, -190], warden: [370, 370],
    furn: { pap: SP_PAP_AT.N(-120), crate: SP_CRATE_AT.S(186) }, alcove: 'open', spawns: SP_RM_SPAWN_NW,   // v19.69: 200 -> 186, the 98-wide chest clears riser (270,-200)
    risers: [...SP_RM_PORCH_RISERS, SP_RM_ALCOVE_RISER, [-340, 200], [-400, 100], [60, 392], [270, -200], [240, 120], [400, 120], [-100, -40], [80, 200], [80, -190]],
    f: [['twall', 0, -236, 0, 100], ['twall', 160, 60, 160, 428], ['twall', 320, 0, 320, 280],
        ['lamp', -100, 200], ['lamp', 80, -60], ['lamp', 240, 240], ['lamp', 80, 300],
        ['plat', 340, 428, 320, 428],
        ['panel', 'N', 180, 420, 120, 248, 'crest']],
    sig: [[-60, -44, -120, 60]] },
  // VII — THE THRONE (red, floor 70): THE COURT. A NAVE of four pillars under
  // two beams leads from the door to a raised THRONE PLATFORM 72 up across the
  // north end — railed, climbed by one grand stair from the west, the seat on
  // top — with two brazier pylons beside it. The first Warden lands on the
  // platform; the court rises there too. The summit capital roofs the centre
  // at 192, which is why the platform and its rails stand north of the core.
  // SHELL: PaP west, crate on the S flight's wall, respawn NW, alcove open —
  // THE DUNGEON. The top is one flight up.
  { name: 'THE THRONE',      hue: 'red',
    mark: [70, 20],   warden: [70, 300],
    furn: { pap: SP_PAP_AT.W(200), crate: SP_CRATE_AT.S(200) }, alcove: 'open', spawns: SP_RM_SPAWN_NW,
    risers: [...SP_RM_PORCH_RISERS, SP_RM_ALCOVE_RISER, [-8, 320], [-300, 100], [-400, 100], [340, 260], [380, 400], [380, -60], [320, -220], [70, -100]],
    f: [['deck', -40, 180, 276, 428, 72, { W: 'stair', S: 'rail', E: 'rail', N: 'flush' }],
        ['seat', 70, 380, 72],
        ['pillar', -120, 0], ['pillar', -120, 160], ['pillar', 260, 0], ['pillar', 260, 160],
        ['lintel', -120, 0, -120, 160], ['lintel', 260, 0, 260, 160],
        ['lamp', 320, 340], ['lamp', 400, 340],
        ['panel', 'N', 172, 428, 120, 248, 'crest']],
    sig: [[54, 86, -110, -40]] },
];
// v17.88 THE HALL ART (docs/110, drop 2026-09-05 16:38): per hall a CREST plaque
// (1024x512, the far wall), a floor SEAL (1024 sq, the trial mark) and a
// seamless WALL TILE (the liner band) — custom lit_emissive world materials
// in source_data/tod_materials.gdt (tod_hall_<kind>_<n>, image <name>_e).
// A NEW LANE for this map: nothing custom has rendered as a world material
// here before. HALL_ART = false puts every hall back on the plain kit.
const HALL_ART = true;
for (const L of SP_RM_LAYOUTS) { if (!SP_HUE[L.hue] || !SP_HALL_KIT[L.hue]) throw new Error(`layout ${L.name}: unknown hue ${L.hue}`); L.kit = SP_HALL_KIT[L.hue]; }
SP_RM_LAYOUTS.forEach((L, i) => { L.art = HALL_ART ? { crest: `tod_hall_crest_${i + 1}`, seal: `tod_hall_floor_${i + 1}`, liner: `tod_hall_wall_${i + 1}` } : null; });
if (SP_RM_LAYOUTS.length !== SP_LAPS / SP_HUB_EVERY) throw new Error(`SP_RM_LAYOUTS has ${SP_RM_LAYOUTS.length} entries for ${SP_LAPS / SP_HUB_EVERY} hubs`);
// footprint of a feature as [x1,x2,y1,y2] (walls get their thickness here);
// null for the two kinds that have no footprint (overhead beams, wall plaques)
function rmFeatBox(ft) {
  const [k] = ft;
  if (k === 'pillar') return [ft[1] - 56, ft[1] + 56, ft[2] - 56, ft[2] + 56];   // plinth incl. its 8 proud
  if (k === 'post')   return [ft[1] - 30, ft[1] + 30, ft[2] - 30, ft[2] + 30];
  if (k === 'lamp')   return [ft[1] - 18, ft[1] + 18, ft[2] - 18, ft[2] + 18];   // the gold foot
  if (k === 'big')    return [ft[1] - ft[3] - 8, ft[1] + ft[3] + 8, ft[2] - ft[3] - 8, ft[2] + ft[3] + 8];
  if (k === 'dais')   { const h = 44 * ft[3]; return [ft[1] - h, ft[1] + h, ft[2] - h, ft[2] + h]; }
  if (k === 'throne') return [ft[1] - 88, ft[1] + 88, ft[2] - 88, ft[2] + 88];
  if (k === 'plat')   return [ft[1], ft[2], ft[3], ft[4]];
  if (k === 'wall' || k === 'twall' || k === 'fence') {
    const [, x1, y1, x2, y2] = ft;
    const t = (k === 'fence') ? 8 : PARA / 2;
    if (x1 === x2) return [x1 - t, x1 + t, Math.min(y1, y2), Math.max(y1, y2)];
    if (y1 === y2) return [Math.min(x1, x2), Math.max(x1, x2), y1 - t, y1 + t];
    throw new Error(`${k} must be axis-aligned: ` + JSON.stringify(ft));
  }
  if (k === 'stage') { const hh = ft[3] + 32 * (ft[4] / 12 - 1); return [ft[1] - hh, ft[1] + hh, ft[2] - hh, ft[2] + hh]; }   // the skirt's foot
  if (k === 'deck') {   // top + every stair run + every rail
    const p = deckParts(ft), all = [p.top, ...p.stairs.map(st => st.box), ...p.rails];
    return [Math.min(...all.map(b => b[0])), Math.max(...all.map(b => b[1])), Math.min(...all.map(b => b[2])), Math.max(...all.map(b => b[3]))];
  }
  if (k === 'seat') return [ft[1] - 44, ft[1] + 44, ft[2] - 44, ft[2] + 48];   // tier 2 + the back's cap
  if (k === 'lintel' || k === 'panel') return null;
  throw new Error('unknown feature ' + k);
}
// height of a feature's top above the hall floor (the gallery-clearance assert)
function rmFeatTop(ft) {
  const [k] = ft;
  if (k === 'pillar') return 192;
  if (k === 'post' || k === 'big') return 264;
  if (k === 'lamp') return SP_RM_LAMP_H + 36;
  if (k === 'dais') return RISE * ft[3];
  if (k === 'throne') return 184;
  if (k === 'plat') return 12;
  if (k === 'wall') return PARA_H + RAIL_CAP_H;
  if (k === 'twall') return SP_RM_TWALL_H + RAIL_CAP_H;
  if (k === 'fence') return SP_RM_FENCE_H + RAIL_CAP_H;
  if (k === 'stage') return ft[4];
  if (k === 'deck') return ft[5] + (deckParts(ft).rails.length ? PARA_H + RAIL_CAP_H : 0);   // a rail's clip cap is the tallest thing on it
  if (k === 'seat') return ft[3] + 172;
  if (k === 'lintel') return 192;
  if (k === 'panel') return ft[5];
  throw new Error('unknown feature ' + k);
}
const rmIsDeckFeat = k => (k === 'dais' || k === 'plat' || k === 'throne' || k === 'stage' || k === 'deck' || k === 'seat');   // the mark / the Warden may sit on (or beside, for the seat) these
// the deck feature (dais / plat / throne) a point sits on, if any — the mark
// and the Warden ride on its TOP (a Max Ammo drop is not ground-traced)
function rmFeatUnder(L, pt) {
  return L.f.find(ft => {
    if (ft[0] === 'dais')   return Math.abs(pt[0] - ft[1]) < 44 * ft[3] && Math.abs(pt[1] - ft[2]) < 44 * ft[3];
    if (ft[0] === 'throne') return Math.abs(pt[0] - ft[1]) < 44 && Math.abs(pt[1] - ft[2]) < 44;
    if (ft[0] === 'plat')   return pt[0] > ft[1] && pt[0] < ft[2] && pt[1] > ft[3] && pt[1] < ft[4];
    if (ft[0] === 'deck' || ft[0] === 'stage') { const t = rmTopBox(ft); return pt[0] > t[0] && pt[0] < t[1] && pt[1] > t[2] && pt[1] < t[3]; }   // the TOP only
    return false;
  });
}
function rmLift(L, pt) {
  const d = rmFeatUnder(L, pt);
  if (!d) return 0;
  if (d[0] === 'dais') return RISE * d[3];
  if (d[0] === 'throne') return 24;
  if (d[0] === 'deck') return d[5];
  if (d[0] === 'stage') return d[4];
  return 12;
}
{
  // On the hall floor = inside the parapet line, NOT in the W notch (the W
  // flight climbs there), NOT in the S lane (the S flight) and NOT in the porch.
  const inHall = ([x, y], m) => {
    if (x < -SP_RM_OUT + m || x > SP_RM_OUT - m || y < -SP_RM_OUT + m || y > SP_RM_OUT - m) return false;
    if (x < -CORE + m && y > -CORE - m && y < SP_RM_NOTCH_Y + m) return false;                 // the notch
    if (x > -CORE - m && x < CORE + m && y > -PX - m && y < -CORE + m) return false;           // the S lane
    if (x < -CORE + SP_RM_PORCH_D + m && y > -CORE - m && y < SP_RM_PORCH_Y2 + m) return false; // the porch
    return true;
  };
  const boxClear = (bx, [x, y], m) => x < bx[0] - m || x > bx[1] + m || y < bx[2] - m || y > bx[3] + m;
  const boxesOverlap = (a, b, m) => !(a[1] + m <= b[0] || b[1] + m <= a[0] || a[3] + m <= b[2] || b[3] + m <= a[2]);
  const inAlcove = ([x, y]) => x > CORE && y < -CORE;
  const approach = [SP_RM_APPROACH.x1, SP_RM_APPROACH.x2, SP_RM_APPROACH.y1, SP_RM_APPROACH.y2];
  const alcoveBox = [CORE, SP_RM_OUT, -SP_RM_OUT, -CORE];
  const MIN_TRIG_GAP_HALL = 64;   // MIN_TRIG_GAP (defined with BR_FURN further down)
  SP_RM_LAYOUTS.forEach((L, li) => {
    const tag = `layout ${li + 1} ${L.name}`;
    // --- v18.78 THE SHELL: defaults, then every shell rule --------------------
    L.furn = L.furn || SP_FURN_DEFAULT;
    L.spawns = L.spawns || SP_RM_SPAWN_XY;
    if (L.alcove !== 'seal' && L.alcove !== 'open') throw new Error(`${tag}: alcove must be 'seal' or 'open' (it is ${L.alcove})`);
    if (!Array.isArray(L.risers) || L.risers.length < 7) throw new Error(`${tag}: a hall lists its own risers (7 or more; the porch pair included)`);
    // --- v18.80 THE ROOMS: decks, stages, seats ---------------------------------
    for (const ft of L.f) {
      if (ft[0] === 'stage' || ft[0] === 'deck') {
        const h = (ft[0] === 'stage') ? ft[4] : ft[5];
        if (h % 12 !== 0 || h < 24) throw new Error(`${tag}: ${ft[0]} at ${ft.slice(1)} is ${h} high — a multiple of 12, 24 or more (every tier / tread is one 12 step)`);
      }
      if (ft[0] === 'deck') {
        const [, x1, x2, y1, y2] = ft;
        if (x1 >= x2 || y1 >= y2) throw new Error(`${tag}: deck ${ft.slice(1, 6)} is not a proper box`);
        const p = deckParts(ft);   // throws on a bad edge word
        for (const side of p.flush) {
          const ok = (side === 'N' && y2 === RM_LINER_X) || (side === 'E' && x2 === RM_LINER_X) || (side === 'W' && x1 === -RM_LINER_X);
          if (!ok) throw new Error(`${tag}: deck ${ft.slice(1, 6)} edge ${side} is 'flush' but does not lie on the drum's liner (${RM_LINER_X})`);
        }
      }
      if (ft[0] === 'seat') {
        const [, sx, sy, lift] = ft;
        const dk = L.f.find(d => d[0] === 'deck' && (() => { const t = deckParts(d).top; return sx - 44 >= t[0] && sx + 44 <= t[1] && sy - 44 >= t[2] && sy + 48 <= t[3]; })());
        if (!dk) throw new Error(`${tag}: seat at ${sx},${sy} does not stand wholly on a deck top`);
        if (dk[5] !== lift) throw new Error(`${tag}: seat at ${sx},${sy} lifts ${lift} but its deck is ${dk[5]} high`);
      }
    }
    for (const pt of [L.mark, L.warden]) {
      const dk = L.f.find(ft => (ft[0] === 'deck' || ft[0] === 'stage') && !boxClear(rmFeatBox(ft), pt, 0));
      if (dk && rmFeatUnder(L, pt) !== dk) throw new Error(`${tag}: point ${pt} is on the ${dk[0]}'s stair / skirt / rail, not its top`);
    }
    const vend = [L.furn.pap, L.furn.crate];
    if (L.furn.pap.kind !== 'pap' || L.furn.crate.kind !== 'crate') throw new Error(`${tag}: furn.pap must be an SP_PAP_AT preset and furn.crate an SP_CRATE_AT preset`);
    {
      const [a, b] = vend;
      const d = Math.hypot(a.trig[0] - b.trig[0], a.trig[1] - b.trig[1]);
      const need = a.r + b.r + MIN_TRIG_GAP_HALL;
      if (d < need) throw new Error(`${tag}: pap<->crate triggers ${Math.round(d)}u apart, rims need ${need}`);
    }
    for (const v of vend) {
      if (!inHall(v.trig, 8)) throw new Error(`${tag}: the ${v.kind} trigger is off the hall floor`);
      const vb = vendBox(v);
      for (const c of [[vb[0], vb[2]], [vb[1], vb[2]], [vb[0], vb[3]], [vb[1], vb[3]]])
        if (!onHallFloor(c, 0, L)) throw new Error(`${tag}: the ${v.kind} body leaves the hall-level floor (corner ${c})`);
      if (boxesOverlap(vb, approach, 0)) throw new Error(`${tag}: the ${v.kind} stands in the doorway's approach lane`);
      if (!boxClear(vb, L.mark, 40)) throw new Error(`${tag}: the mark is within 40 of the ${v.kind}`);
      if (!boxClear(vb, L.warden, 80)) throw new Error(`${tag}: the warden drop is within 80 of the ${v.kind}`);
    }
    const has = pt => L.risers.some(r => r[0] === pt[0] && r[1] === pt[1]);
    for (const p of SP_RM_PORCH_RISERS) if (!has(p)) throw new Error(`${tag}: the porch risers ${JSON.stringify(SP_RM_PORCH_RISERS)} are not optional — the porch is the pocket this pass exists for`);
    if (L.alcove === 'open' && !L.risers.some(inAlcove)) throw new Error(`${tag}: an OPEN alcove needs a riser inside it (x > ${CORE}, y < ${-CORE})`);
    if (L.alcove === 'seal' && L.risers.some(inAlcove)) throw new Error(`${tag}: a riser inside a SEALED alcove`);
    L.risers.forEach((r, ri) => {
      if (!onHallFloor(r, 32, L)) throw new Error(`${tag}: riser ${r} is not on hall-level floor with 32 to spare (fan step / void / sealed alcove)`);
      for (const v of vend) if (!boxClear(vendBox(v), r, 32)) throw new Error(`${tag}: riser ${r} is within 32 of the ${v.kind}`);
      for (const s of L.spawns) if (Math.hypot(r[0] - s[0], r[1] - s[1]) < 64) throw new Error(`${tag}: riser ${r} within 64 of respawn ${s}`);
      for (let j = 0; j < ri; j++) if (Math.hypot(r[0] - L.risers[j][0], r[1] - L.risers[j][1]) < 48) throw new Error(`${tag}: risers ${L.risers[j]} and ${r} within 48`);
    });
    for (const sp of L.spawns) {
      if (!onHallFloor(sp, 40, L)) throw new Error(`${tag}: respawn ${sp} is not on hall-level floor with 40 to spare`);
      for (const v of vend) if (!boxClear(vendBox(v), sp, 40)) throw new Error(`${tag}: respawn ${sp} is within 40 of the ${v.kind}`);
    }
    // --- the set-piece ------------------------------------------------------------
    if (!inHall(L.mark, 8)) throw new Error(`${tag}: mark is off the hall floor`);
    if (!inHall(L.warden, 64)) throw new Error(`${tag}: warden drop is within 64 of a wall/notch/lane/porch`);
    if (L.alcove === 'seal' && (inAlcove(L.mark) || inAlcove(L.warden))) throw new Error(`${tag}: mark / warden inside the sealed alcove`);
    const pillarAt = (x, y) => L.f.some(ft => ft[0] === 'pillar' && ft[1] === x && ft[2] === y);
    for (const ft of L.f) {
      // v17.86: the two footprint-less kinds have their own contracts
      if (ft[0] === 'lintel') {
        const [, x1, y1, x2, y2] = ft;
        if (x1 !== x2 && y1 !== y2) throw new Error(`${tag}: lintel ${ft.slice(1)} is not axis-aligned`);
        if (!pillarAt(x1, y1) || !pillarAt(x2, y2)) throw new Error(`${tag}: lintel ${ft.slice(1)} does not run pillar-centre to pillar-centre`);
        if (Math.abs(x2 - x1) + Math.abs(y2 - y1) <= 112) throw new Error(`${tag}: lintel ${ft.slice(1)} has no span between its caps`);
        continue;
      }
      if (ft[0] === 'panel') {
        const [, side, a1, a2, z1, z2] = ft;
        if (side !== 'N' && side !== 'W') throw new Error(`${tag}: panel side ${side} must be N or W`);
        if (a1 >= a2 || z1 >= z2 || z1 < 0) throw new Error(`${tag}: panel ${ft.slice(1)} is not a proper plaque`);
        const lo = (side === 'W') ? SP_RM_NOTCH_Y + PARA : -SP_RM_OUT + SP_RM_LINER.t;
        if (a1 < lo || a2 > SP_RM_OUT - SP_RM_LINER.t) throw new Error(`${tag}: panel ${ft.slice(1)} runs off the ${side} wall's hall span [${lo},${SP_RM_OUT - SP_RM_LINER.t}]`);
        // v18.78: never behind a vendor on that wall (the v17.86 rule was "the PaP on W"; the vendors move now)
        for (const v of vend) {
          if (v.side !== side) continue;
          const a = (side === 'N') ? v.org[0] : v.org[1];
          if (a2 > a - 80 && a1 < a + 80) throw new Error(`${tag}: panel ${ft.slice(1)} sits behind the ${v.kind} on the ${side} wall`);
        }
        continue;
      }
      if (ft[0] === 'fence') {
        const len = Math.abs(ft[3] - ft[1]) + Math.abs(ft[4] - ft[2]);
        if (len % 32 !== 0 || len < 64) throw new Error(`${tag}: fence ${ft.slice(1)} is ${len} long — bars sit at 32 pitch, so a fence is a multiple of 32 (min 64)`);
      }
      const bx = rmFeatBox(ft);
      // every feature wholly on the floor, out of the approach lane, out of a sealed alcove
      for (const c of [[bx[0], bx[2]], [bx[1], bx[2]], [bx[0], bx[3]], [bx[1], bx[3]]])
        if (!inHall(c, 0)) throw new Error(`${tag}: ${ft[0]} at ${ft.slice(1)} leaves the hall floor (corner ${c})`);
      if (boxesOverlap(bx, approach, 0)) throw new Error(`${tag}: ${ft[0]} at ${ft.slice(1)} blocks the doorway's approach lane`);
      if (L.alcove === 'seal' && boxesOverlap(bx, alcoveBox, 0)) throw new Error(`${tag}: ${ft[0]} at ${ft.slice(1)} is inside the sealed alcove`);
      for (const r of L.risers) {
        if (rmDeckTopOf(L, r, 32) === ft) continue;   // v18.80: a riser ON this deck's top (32 inside it) rides on it
        if (!boxClear(bx, r, 32)) throw new Error(`${tag}: ${ft[0]} at ${ft.slice(1)} is within 32 of riser ${r}`);
      }
      for (const s of L.spawns) if (!boxClear(bx, s, 32)) throw new Error(`${tag}: ${ft[0]} at ${ft.slice(1)} is within 32 of spawn ${s}`);
      for (const v of vend) {
        // the BUY footprint where a vendor has one (the crate, 2026-09-24): see crateBuySpot
        if (!boxClear(bx, v.buy || v.trig, ( v.clear || v.r ) + 8)) throw new Error(`${tag}: ${ft[0]} at ${ft.slice(1)} overlaps the ${v.kind} trigger`);
        if (boxesOverlap(bx, vendBox(v), 8)) throw new Error(`${tag}: ${ft[0]} at ${ft.slice(1)} touches the ${v.kind} body`);
      }
      if (!rmIsDeckFeat(ft[0])) {
        if (!boxClear(bx, L.warden, 80)) throw new Error(`${tag}: warden drop within 80 of ${ft[0]} at ${ft.slice(1)}`);
        if (!boxClear(bx, L.mark, 40)) throw new Error(`${tag}: mark within 40 of ${ft[0]} at ${ft.slice(1)}`);
      }
      // v17.86 GALLERY CLEARANCE. The next lap's E flight climbs over the E
      // gallery (x > CORE, treads 12 per 32 from FLIGHT_RISE at y = -CORE) with
      // its inner rail on x[CORE-PARA, CORE]; the NE landing (y > CORE) sits at
      // 2*FLIGHT_RISE. Anything tall east of the core has to fit UNDER whichever
      // tread / rail group is over its SOUTH edge (the lowest point above it).
      // Before this a 240-tall fence at x 240 would have run into the flight's
      // first treads — and nothing here would have said so.
      const top = rmFeatTop(ft);
      if (bx[1] > CORE - PARA) {
        const i = Math.max(0, Math.min(STEPS, Math.floor((bx[2] + CORE) / TREAD) + 1));
        const treadUnder = FLIGHT_RISE + RISE * i - SLAB;
        const j = Math.max(1, Math.min(STEPS / PARA_EVERY, Math.floor((bx[2] + CORE) / (TREAD * PARA_EVERY)) + 1));
        const railUnder = FLIGHT_RISE + RISE * PARA_EVERY * j - RISE * (PARA_EVERY - 1);
        const under = Math.min(treadUnder, (bx[2] >= CORE) ? Infinity : railUnder) - 4;
        if (top > under) throw new Error(`${tag}: ${ft[0]} at ${ft.slice(1)} (top ${top}) reaches the E gallery flight over it (underside ${under} at y ${bx[2]})`);
        // v18.78: and under the SE landing (the alcove's roof) when the alcove is open
        if (bx[2] < -CORE && top > FLIGHT_RISE - SLAB - 4) throw new Error(`${tag}: ${ft[0]} at ${ft.slice(1)} (top ${top}) reaches the SE landing that roofs the alcove at ${FLIGHT_RISE - SLAB}`);
      }
      if (top > SP_RM_VOID_H - 16) throw new Error(`${tag}: ${ft[0]} at ${ft.slice(1)} (top ${top}) reaches the core column that resumes at ${SP_RM_VOID_H}`);
      // THE LAST HALL'S CEILING IS THE SUMMIT CAPITAL (6d: 'core capital', the core
      // footprint from SP_TOP = its mid + FLIGHT_RISE). Everything inside |x|,|y| < CORE
      // there stops at 192 — the preview tool showed the throne's back buried in it.
      if (li === SP_RM_LAYOUTS.length - 1 && boxesOverlap(bx, [-CORE, CORE, -CORE, CORE], 0) && top > FLIGHT_RISE)
        throw new Error(`${tag}: ${ft[0]} at ${ft.slice(1)} (top ${top}) reaches the summit capital that roofs the last hall's centre at ${FLIGHT_RISE}`);
    }
    // pairwise: walls of any kind may meet (an L, a T, a cage corner); nothing else may overlap
    const solids = L.f.filter(ft => rmFeatBox(ft));
    const wallish = k => (k === 'wall' || k === 'twall' || k === 'fence');
    // v18.80: a seat stands on its deck (asserted above) — that pair may overlap
    const seatOn = (a, b) => (a[0] === 'seat' && b[0] === 'deck') || (a[0] === 'deck' && b[0] === 'seat');
    for (let i = 0; i < solids.length; i++) for (let j = i + 1; j < solids.length; j++)
      if (boxesOverlap(rmFeatBox(solids[i]), rmFeatBox(solids[j]), 0) && !(wallish(solids[i][0]) && wallish(solids[j][0])) && !seatOn(solids[i], solids[j]))
        throw new Error(`${tag}: ${solids[i][0]} at ${solids[i].slice(1)} and ${solids[j][0]} at ${solids[j].slice(1)} overlap`);
    // v17.69 THE SIGIL: every inlay box on the floor, out of the approach
    // lane, clear of every feature (a buried inlay is the hidden-face audit's
    // exact finding), clear of the mark inlay (two 1u brushes would z-fight)
    // and of the vendor triggers' rims and bodies.
    const markBox = [L.mark[0] - 48, L.mark[0] + 48, L.mark[1] - 48, L.mark[1] + 48];
    (L.sig || []).forEach((bx, si) => {
      if (bx[0] >= bx[1] || bx[2] >= bx[3]) throw new Error(`${tag}: sigil ${si} is not a proper box`);
      for (const c of [[bx[0], bx[2]], [bx[1], bx[2]], [bx[0], bx[3]], [bx[1], bx[3]]])
        if (!inHall(c, 0)) throw new Error(`${tag}: sigil ${si} leaves the hall floor (corner ${c})`);
      if (boxesOverlap(bx, approach, 0)) throw new Error(`${tag}: sigil ${si} lies in the doorway's approach lane`);
      if (boxesOverlap(bx, markBox, 0)) throw new Error(`${tag}: sigil ${si} overlaps the trial mark`);
      if (L.alcove === 'seal' && boxesOverlap(bx, alcoveBox, 0)) throw new Error(`${tag}: sigil ${si} is inside the sealed alcove`);
      for (const ft of solids) if (boxesOverlap(bx, rmFeatBox(ft), 0)) throw new Error(`${tag}: sigil ${si} overlaps ${ft[0]} at ${ft.slice(1)}`);
      for (const v of vend) {
        // buy footprint for the crate (its trigger origin now floats 60 up, far above any inlay)
        if (!boxClear(bx, v.buy || v.trig, ( v.clear || v.r ) + 8)) throw new Error(`${tag}: sigil ${si} overlaps the ${v.kind} trigger`);
        if (boxesOverlap(bx, vendBox(v), 0)) throw new Error(`${tag}: sigil ${si} runs under the ${v.kind}`);
      }
      for (let j = 0; j < si; j++) if (boxesOverlap(bx, L.sig[j], 0)) throw new Error(`${tag}: sigils ${j} and ${si} overlap`);
    });
  });
}
// Monochrome menace: on this map red means danger, and the spire IS the
// danger. Steps stay navy silhouette; every glow line is red; the hubs go
// GOLD — the crown's colour marks the reward rhythm every 10th floor.
const SP_MAT_STEP = 'mwiii_vertigo_retro_synth_dark_blue_tinted';
const SP_MAT_LAND = 'mwiii_vertigo_retro_synth_red_tinted_edge';
const SP_MAT_PARA = 'mwiii_vertigo_retro_synth_red';
const SP_MAT_CORE = 'mwiii_vertigo_retro_synth_red_tinted';
const SP_MAT_HUBF = 'mwiii_vertigo_retro_synth_yellow_tinted_edge';
const SP_MAT_HUBP = 'mwiii_vertigo_retro_synth_yellow';
const SP_LIGHT_RED = '1 0.3 0.3';
const SP_LIGHT_GOLD = '1 0.85 0.35';
if (SP_LAPS % 2 !== 0) throw new Error('SP_LAPS must be EVEN — the summit flight and hub furniture are authored for the frame that parity produces (the tower paid for silent parity drift once; the spire refuses to build instead of drifting)');
if (SP_HUB_EVERY % 2 !== 0) throw new Error('SP_HUB_EVERY must be even — hubs reuse the breathers\' mirrored-frame furniture table (BR_FURN)');

// Sky enclosure (the SEAL)
// v9: widened 1900 -> 2900 for the crown hall (outer face at y=2656 in either
// frame) and raised to clear the mast tip + corner needles.
// v10: the long causeway pushes the hall's outer face to y=HN (8416 at
// CW_LEN 6400), so the seal has to clear it. DERIVED, not a literal — a future
// CW_LEN change must never be able to leave the hall outside the skybox, which
// would be a hole in the world rather than a cosmetic bug. Symmetric on both
// axes because CM mirrors the whole crown to -y on an even crown lap.
// v11: it now has to clear THE CIRCLET too, and that was a real trap rather
// than a hypothetical one. SKY_IN tracked HN in Y ONLY and SKY_TOP tracked the
// MAST ONLY, and the two asserts further down test the CAUSEWAY, never the
// crown — so the old seal had 620 units of headroom above the corner-tower tips
// and nothing whatsoever would have fired when the beacon needle went 4564
// units through the roof of the world. Both are max()'d over the crown now, and
// section 5f asserts the crown against them.
const SKY_IN = Math.max(2900, HN + 384, CR_OUT_Y + 512, CR_OUT_X + 512), SKY_TH = 32;
const SKY_BOT = -96, SKY_FLOOR = -64;
// v14: max()'d over the SPIRE's beacon when it is enabled — same rule as the
// crown (the seal must be derived from everything under it, never a literal).
// ⚠️ THE SKY SEAL / SUN VOLUME MUST NEVER SHRINK BELOW THIS (v17.80, 2026-09-05, docs/107).
// SKY_TOP sizes BOTH the sky enclosure and the `volume_sun` brush (the map-wide sun / light-grid
// volume, grid_density 32). It used to be governed by whatever was tallest, and when v17.69 cut the
// spire from 100 to 70 laps the spire term fell from 39,168 to 27,648, CROWN_TOP (28,896) took
// over, and SKY_TOP dropped from 39,468 to 29,196 — 10,272 units. From that build on THE WHOLE
// TOWER READ YELLOW-OLIVE: every surface, the viewmodel and the zombies lit by a warm light that
// honoured the base lights' POSITIONS but not their colour or their lighting state (authored OFF
// before power), i.e. the engine on default light parameters. Six builds of sky / sun / light /
// fog / vision / dev-flag reverts changed nothing because none of those had changed. Proof:
//   - v17.79: this floor at 39,168 + a from-nothing .led  -> DARK at the crate (published look);
//     .led 45,041,494 B.
//   - v17.80 bisect: floor 0 + a from-nothing .led        -> the crash-era .led size again,
//     44,592,078 B, byte-identical to every yellow bake; deletion of the .led was NOT the fix.
//   - the control map (Repositories/test+map) bakes clean on this host, so it is not the tools.
// The published v17.58 build had the 100-lap spire and therefore this height by accident. The
// mechanism inside Radiant is not known (a light-grid partition of the volume is the likely lane);
// the RULE is empirical and cheap: hold the floor. If the geometry ever grows past it, max() wins.
const SUN_VOLUME_TOP_MIN = 39168;
const SKY_TOP = Math.max(MAST_TOP, CROWN_TOP, SPIRE_ENABLED ? SP_TOP2 + SP_BEACON_H + 64 : 0, SUN_VOLUME_TOP_MIN) + 300;

// Neon palette, cycled per lap (ALL names verified in the installed
// emox_mwiii_vertigo_assets.gdt 2026-08-17/18).
const PALETTE = [
  { key: 'cyan',   light: '0.35 0.9 1' },
  { key: 'purple', light: '0.66 0.35 1' },
  { key: 'pink',   light: '1 0.35 0.8' },
  { key: 'green',  light: '0.35 1 0.6' },
  { key: 'orange', light: '1 0.6 0.25' },
  { key: 'yellow', light: '1 0.95 0.35' },
  { key: 'red',    light: '1 0.3 0.3' },
  { key: 'blue',   light: '0.35 0.55 1' },
];
// ---------------------------------------------------------------------------
// v16.11 — THE TOWER FACELIFT (user 2026-09-01: "Look into overall design
// enhancement we can make to the tower physical appearance ... Lets do the
// first 4" of the ranked review, artifact "Cybercity Tower Facelift"):
//   1. DISTRICT PALETTE (here)     colour means height
//   2. DOOR GATES THAT OPEN         post + lintel + sill per lap door, the slab
//                                   in the district it opens into; the slab
//                                   SLIDES into the core on purchase
//                                   (_tod_doors.gsc TOD_DOOR_SLIDE)
//   3. BASE PLAZA + WAYFINDING      floor traces spawn -> first door / power
//                                   hall, a foot ring under the core, cyan
//                                   pilasters + cornice on the arena walls
//   4. TELEPORT BAY COLOUR CODE     each up pad wears its destination lounge's
//                                   colour (pad square + light)
// ONE SWITCH, FACELIFT, gates all four geometry halves (same construction as
// BR_POLISH): false regenerates the v16.7 map byte-for-byte (proven by md5
// when the switch was added). Flipping it is a regen + FULL build. The script
// half (the slide) has its own TOD_DOOR_SLIDE define.
//
// 1. DISTRICTS. The old scheme cycled treads/parapets/core through the 8-entry
// PALETTE per lap and landings through 5 edge hues, so the same colour never
// meant the same height and the two cycles only realigned every 40 floors.
// Now five districts of DISTRICT_LAPS floors, each ONE hue family, in the
// order the breather lounges ALREADY wear (BREATHER_THEME: 10 blue, 20 green,
// 30 orange, 40 gold) — the lounge is the district's culmination — and RED
// for 41-50, the map's danger colour, for the ten hardest floors under the
// gold crown (no lounge up there; the spire is red too but on black with
// different bones). These five are exactly the five hues the pack ships as
// `_tinted_edge` landing tiles, so nothing new is needed. The core band per
// lap takes the district colour too: from the base the tower reads as five
// stacked bands, and the lap lights follow lapPal for free.
// RHYTHM inside a district — laps must still differ from their neighbours:
// treads (and the core band) alternate `_tinted` on odd floors and
// `_tinted_edge` on even floors. NOT the parapets: a `_tinted` parapet is a
// 56-tall `_tinted` slab, which lint_tod_geometry classes as a walkable DECK
// (<= MAX_SLAB) and would flag hundreds of false unguarded edges; parapets
// stay plain hue (BLOCK). The end landing of lap L already wears lap L+1's
// colour (edgeMatOf(lap + 1) below), so at a district boundary the landing
// where you buy the next door is the FIRST thing in the new colour — the
// "one more floor" tell for free.
// ---------------------------------------------------------------------------
const FACELIFT = true;
const DISTRICT_LAPS = 10;
const DISTRICTS = [
  { key: 'blue',   light: '0.35 0.55 1' },   // floors  1-10 — the base arena's blue; lounge 10
  { key: 'green',  light: '0.35 1 0.6'  },   // floors 11-20 — lounge 20
  { key: 'orange', light: '1 0.6 0.25'  },   // floors 21-30 — lounge 30
  { key: 'yellow', light: '1 0.85 0.35' },   // floors 31-40 — lounge 40, the crown's gold foreshadowed
  { key: 'red',    light: '1 0.3 0.3'   },   // floors 41-50 — danger; the last ten under the crown
];
// lap is 0-based; lap 50 (edgeMatOf(lap + 1) on the last lap, the crown's
// own lap index) clamps to the last district.
function districtOf(lap) { return DISTRICTS[Math.min(DISTRICTS.length - 1, Math.max(0, Math.floor(lap / DISTRICT_LAPS)))]; }
function lapPal(lap) { return FACELIFT ? districtOf(lap) : PALETTE[lap % PALETTE.length]; }
function stepMatOf(lap) {
  if (!FACELIFT) return `mwiii_vertigo_retro_synth_${lapPal(lap).key}_tinted`;
  return `mwiii_vertigo_retro_synth_${districtOf(lap).key}_${lap % 2 === 0 ? 'tinted' : 'tinted_edge'}`;
}
function paraMatOf(lap) { return `mwiii_vertigo_retro_synth_${lapPal(lap).key}`; }
// TRON GRID floors (user 2026-08-20 design pick): dark tiles with GLOWING
// SEAMS — the pack's `_tinted_edge` family (only blue/green/orange/red/
// yellow exist). Pre-facelift: cycled per lap on landings + breather balconies;
// facelift: the district hue.
const EDGE_COLORS = ['blue', 'green', 'orange', 'red', 'yellow'];
function edgeMatOf(lap) {
  if (!FACELIFT) return `mwiii_vertigo_retro_synth_${EDGE_COLORS[lap % EDGE_COLORS.length]}_tinted_edge`;
  return `mwiii_vertigo_retro_synth_${districtOf(lap).key}_tinted_edge`;
}

// DOOR SLABS ONLY (v18.99g). Same hue ladder as edgeMatOf, but the matte clones
// — see MAT.door's note and tools/gen_tod_door_materials.js. This exists as its
// own function precisely so the swap CANNOT leak onto the landings, breather
// floors, terrace, causeway deck or extraction pad, which are edgeMatOf's other
// callers and are supposed to keep their wet-neon reflection.
// LOCKSTEP: the five names here are generated from DISTRICTS, are declared in
// source_data/tod_materials.gdt, and are classified BLOCK in
// tools/lint_tod_geometry.js — a name missing from any of those three is a
// silent linker substitution, i.e. a white square nobody warns you about.
function doorMatOf(lap) {
  if (!FACELIFT) return MAT.door;
  return `tod_door_${districtOf(lap).key}`;
}

// ---------------------------------------------------------------------------
// v19.69 THE SURFACE REFRESH (user 2026-10-02: "Are there any small visual
// enhancements or updates we can make to the walls floors ceilings etc on
// either tower to keep the content improving and fresh. Like a minor redesign"
// + "be prepared to revert cleanly if i dont like some of the changes").
// Design record + previews: docs/169_surface_refresh.md.
//
// THE IDEA: LIT EDGES ON A DARKER UNDERSIDE. Every stair on both towers was one
// glowing slab per tread - top, front, back and underside all the same filled
// glow - so a flight read as a ramp of light and the view UP the spiral was one
// wash of district colour. The pass gives each face its own job, PER FACE, on
// the brushes that already exist: ZERO new brushes, ZERO new lightmap area, no
// collision, trigger, navmesh or gameplay change (the AI walks the ramp clip,
// which is untouched; the geometry lint takes a brush's class from its TOP face,
// which stays the tread's own material).
//   RF_RISERS     the riser (the face toward the low end of the flight) of every
//                 tread wears tod_rf_riser_<district> - a soft glow with a light
//                 LINE through its middle: an LED strip per step, so climbing,
//                 the stair ahead is a ladder of light in the district's colour.
//                 The spire's are its own hotter red (tod_rf_riser_spire).
//   RF_SOFFITS    the UNDERSIDES - tread bottoms + the strip of each tread's back
//                 face left exposed under the next tread, every landing's bottom
//                 - wear the district's PLAIN material (black tiles + a thin grid
//                 line, the rails' own look): the ceiling you see looking up the
//                 spiral is a dark gridded soffit and the lit edges read against
//                 it. The spire's undersides are plain dark_blue (its navy steps'
//                 own family, neutral inside every coloured trial hall).
//   RF_STRINGERS  the OUTER side faces of treads and landings (the 16-tall slab
//                 edge under each rail, seen from outside the spiral) - plain hue
//                 too, so the ribbon reads as one dark stringer under its rail.
//   RF_FLOORNUMS  a glowing floor NUMBER on every door landing (the landing where
//                 floor n's door is bought), in the map's own HUD digits
//                 (tools/gen_tod_refresh_assets.py), the district's colour, as a
//                 non-colliding chalk-mesh decal 1.5 above the floor - tower
//                 floors 1-50, spire floors 1-70.
// The art and the 12 materials live in their own source_data/tod_refresh.gdt.
// TRIED AND DROPPED: a light ring round the core at every floor line - the column
// already carries a grid line every 64 units, so the ring read as one more grid
// line in every preview (docs/169).
//
// REVERT, PER ITEM: set its switch below to false, `node tools/gen_tower_map.js`,
// FULL build. All four false regenerates the pre-refresh map BYTE-FOR-BYTE (proven
// by md5 against tmp/visual_refresh_20261002/baseline when the pass landed - the
// switch-off path calls plain addBox and consumes no guid). TOD_REFRESH=all|none|
// risers,soffits,... in the environment overrides the literals for an A/B regen.
// ---------------------------------------------------------------------------
const REFRESH_ENV = process.env.TOD_REFRESH;
function refreshOn(key, def) {
  if (REFRESH_ENV === undefined || REFRESH_ENV === '') return def;
  if (REFRESH_ENV === 'all') return true;
  if (REFRESH_ENV === 'none') return false;
  return REFRESH_ENV.split(',').map(s => s.trim()).includes(key);
}
const RF_RISERS     = refreshOn('risers', true);
const RF_SOFFITS    = refreshOn('soffits', true);
const RF_STRINGERS  = refreshOn('stringers', false);   // OFF: a 16-tall edge under a lit rail - no visible difference in any preview
const RF_FLOORNUMS  = refreshOn('floornums', true);
// THE RISER TEXTURE MAPS AT EXACTLY ONE REPEAT PER VISIBLE RISER: every tread top
// on both towers is a multiple of 12 (a lap is 384 = 32 x 12; treads rise 12), so
// with V = 12 world units per repeat and no offset, the 12-unit band between one
// tread top and the next holds one whole copy of the image whichever way the
// engine runs a wall's V axis (+z or -z - unverified on this map; docs/110 left
// it open for the crests). The image is symmetric top-to-bottom for the same
// reason. U is uniform, any size.
const RF_RISER_U = 64, RF_RISER_V = 12;
if (LAP_RISE % RF_RISER_V !== 0 || RISE % RF_RISER_V !== 0) throw new Error('the riser texture repeat must divide every tread top (LAP_RISE and RISE multiples of RF_RISER_V)');
const RF_SPIRE_RISER = 'tod_rf_riser_spire';
const RF_SPIRE_SOFFIT = 'mwiii_vertigo_retro_synth_dark_blue';
function riserMatOf(lap) { return `tod_rf_riser_${districtOf(lap).key}`; }
// the soffit / stringer material: the district's PLAIN hue (what paraMatOf returns)
function soffitMatOf(lap) { return paraMatOf(lap); }
// per-face spec for a stair tread. riser / back / outer are box face keys
// ('s' = y1, 'e' = x2, 'n' = y2, 'w' = x1); the riser faces the LOW end of its
// flight, the back faces the high end, the outer side faces away from the core.
function treadFaces(riser, back, outer, riserMat, soffitMat) {
  const f = {};
  if (RF_RISERS) f[riser] = [riserMat, RF_RISER_U, RF_RISER_V, 0, 0];
  if (RF_SOFFITS) { f.bottom = soffitMat; f[back] = soffitMat; }
  if (RF_STRINGERS) f[outer] = soffitMat;
  return f;
}
// per-face spec for a landing slab: the underside + its outer (void-side) edges
function landingFaces(outers, soffitMat) {
  const f = {};
  if (RF_SOFFITS) f.bottom = soffitMat;
  if (RF_STRINGERS) for (const k of outers) f[k] = soffitMat;
  return f;
}

// ---------------------------------------------------------------------------
// v17.28 — FLOOR 1 GOES BLACK (Workshop, Nikolai 2026-09-04): "the walls all
// have the black and blue grid ... remove the blue only on the first floor and
// just make it consistently that black and blue grid checker (only leave the
// green buyable doors and blue buyable door) ... right now the blue wrapping
// around it makes it a little more difficult to see which blue is the buyable
// door ... add that black and blue checker to the bottom part of the column of
// the tower outside where the blue purchasable door is."
//
// HE IS DESCRIBING A MEASURABLE FACT, not a taste. The whole vertigo pack is
// TWO textures and one brightness number (read out of
// emox_mwiii_vertigo_assets.gdt, 2026-09-04):
//
//   <colour>              i_..._e         BLACK tiles + a thin bright grid line, scaleRGB 15
//   <colour>_tinted       i_..._tinted_e  FILLED tiles glowing at the seams,   scaleRGB 10
//   <colour>_tinted_edge  i_..._tinted_e  the SAME texture and the SAME tint,  scaleRGB 5
//
// So `_tinted_edge` is not an "edge" variant of anything — it is `_tinted` at
// HALF BRIGHTNESS. (The old comment on edgeMatOf calling it "dark tiles with
// GLOWING SEAMS" described the texture both share.) That single fact explains
// the report: at ground level the arena FLOOR was `dark_blue_tinted` (filled,
// 10) and the core's lap-1 band `blue_tinted` (filled, 10), while the buyable
// door slab is `blue_tinted_edge` (filled, 5) — the door is the SAME TEXTURE
// and roughly the same hue as everything around it, at HALF the brightness of
// the wall it is cut beside. It is the dimmest blue in a room full of brighter
// blue, which is exactly backwards.
//
// The fix is his: ground level drops to the PLAIN family (black tiles + a blue
// grid line), so the only FILLED blue left down there is the lap-1 door slab
// and the 1-10 teleport pad it is colour-matched to. Green keeps the power and
// teleport-bay doors. Nothing above floor 1 changes.
//
// ONE SWITCH, BASE_GRID, so the whole look A/Bs in one edit; false regenerates
// the pre-v17.28 base exactly.
//
// ⚠️ THE FLOOR MATERIAL IS LOAD-BEARING FOR lint_tod_geometry.js, which classes
// DECK vs BLOCK by MATERIAL NAME and HARD-FAILS on a name it does not know.
// Every plain `<colour>` in its table is BLOCK (parapets, rails, base walls),
// so handing the arena floor a plain material the lint already knew would have
// deleted the floor from its walkability model and reported the whole map as
// unreachable. `dark_blue` is used NOWHERE ELSE in this map, so it can be added
// there as DECK with a one-to-one meaning — which is the lint's own rule that
// a material's class is derived from the labels that use it. Pick a plain
// colour that is already in service for something else and that rule breaks.
const BASE_GRID = true;
// How many core bands from the ground wear the floor's grid material. Band 0 is
// z 0..384 and carries the floor-1 door; band 1 is z 384..768 and carries the
// floor-2 door. Two puts the change-over above the arena walls (128) and out of
// the eyeline from the spawn, and leaves the column visibly standing ON the
// black grid it is lit against. The four plain-hue SPINES are untouched, so the
// column keeps its four vertical lines all the way up.
const BASE_GRID_LAPS = 2;

const MAT = {
  // NOT the base floor — `ground` is also the tower shell, the crown hall floor
  // and the spire's base slab (see every MAT.ground call site). Floor 1 has its
  // own entry below precisely so those three do not follow it.
  ground: 'mwiii_vertigo_retro_synth_dark_blue_tinted',   // TRON GRID: navy tiles (was grey asphalt)
  // GROUND LEVEL ONLY: the arena slab, the power-hall floor and the teleport-bay
  // floor. `dark_blue` is the exact plain twin of `dark_blue_tinted` — same
  // tint (0.067 0.198 1), grid texture instead of filled — so this is literally
  // "keep the colour, drop the fill".
  // v17.32: `blue` (0.373 0.727 1), not `dark_blue` (0.067 0.198 1) — user asked
  // for the lighter tint. ⚠️ BE CLEAR WHAT THIS DOES: both are the SAME plain
  // texture at the SAME scaleRGB 15, and that texture is ~96% black, so the tint
  // only recolours the thin GRID LINE. It lifts the lines from deep blue to pale
  // sky blue; it does NOT make the tiles less black. The room's brightness comes
  // from BASE_LIGHT_BAKE below, not from here — an earlier note in this session
  // listed the two as alternative brightness knobs and that was wrong.
  baseFloor: BASE_GRID ? 'mwiii_vertigo_retro_synth_blue' : 'mwiii_vertigo_retro_synth_dark_blue_tinted',
  // THE COLUMN'S PLINTH STAYS THE DARKER TINT and no longer shares the floor's
  // material. It has to: the core's four SPINES are paraMatOf(lap) = plain
  // `blue` for district 1, so a plinth in plain `blue` would be the same material
  // as the spines standing in it and the four vertical lines would vanish for the
  // first two bands. `dark_blue` keeps the plinth reading behind them.
  baseColumn: BASE_GRID ? 'mwiii_vertigo_retro_synth_dark_blue' : 'mwiii_vertigo_retro_synth_blue_tinted',
  // THE WAYFINDING GLOW MOVES OFF BLUE. The inlay ring, the three power/door
  // traces and the core foot ring were `blue_tinted_edge` — byte-identical to
  // the lap-1 door slab, so the one thing on the floor that is supposed to say
  // "the way through" was drawn in the door's own material. Cyan is already the
  // arena's accent (pilasters + cornice) and it is a hue the spiral never uses
  // for a district, so at ground level cyan now means "this room" and blue means
  // "the way up". `cyan_tinted` is deliberate: the pack ships NO
  // `cyan_tinted_edge` (30 materials, verified) and the linker substitutes an
  // invented name silently. It is also brightness 10 against the old 5, so the
  // traces read BETTER on the darker floor, not worse.
  baseInlay: BASE_GRID ? 'mwiii_vertigo_retro_synth_blue_tinted' : 'mwiii_vertigo_retro_synth_blue_tinted_edge',
  baseWall: 'mwiii_vertigo_retro_synth_blue',
  pilaster: 'mwiii_vertigo_retro_synth_cyan',              // v16.11 facelift: arena wall pilasters + cornice (the crown fascia's cyan)
  landing: 'mwiii_vertigo_retro_synth_dark_white',        // fallback only — landings now use edgeMatOf(lap)
  roofFloor: 'mwiii_vertigo_retro_synth_pap',             // the payoff floor under PaP
  roofPara: 'mwiii_vertigo_retro_synth_yellow',
  // BUYABLE DOORS — GLOWING GREEN SEAM (user 2026-08-27: "making the doors more
  // obvious to buy. They look quite similar to the walls ... see if we have a
  // wall in that same pack that can be used").
  //
  // WHY THE OLD FLAT RED FAILED, measured rather than guessed:
  //   * the wall a door is set into is the CORE BAND, stepMatOf(lap) =
  //     `<PALETTE>_tinted`, and PALETTE cycles EIGHT colours — one of which is
  //     RED. On lap % 8 == 6 the door was red-on-red against its own wall, i.e.
  //     6 of the 50 floors.
  //   * every landing and balcony is `_tinted_edge` (glowing seams), so a flat
  //     door was the ONLY major surface in the map with no glow at all. It did
  //     not read as a door; it read as wall.
  //
  // A FIXED HUE CANNOT SOLVE THIS — with eight wall colours cycling, whatever
  // colour the door takes, one lap in eight matches it. So the door has to
  // differ in KIND, not in hue: `_tinted_edge` makes it the only VERTICAL
  // glowing-grid surface in the map, on every lap, against flat `_tinted` walls.
  //
  // GREEN because this map already speaks it: exfilPad below is
  // green_tinted_edge, so green already means "the way through". Green is also
  // the universal buyable convention. Residual: the wall is green_tinted on
  // lap % 8 == 3, so on 6 floors the HUE matches — but the door still carries a
  // seam grid the wall does not, which is the read that was missing before.
  //
  // Same pack (emox_mwiii_vertigo_assets), so the theme is untouched. NOTE the
  // `_tinted_edge` family exists ONLY for blue/green/orange/red/yellow — the
  // geometry lint will not catch an invented name, the linker just substitutes.
  // v18.99g THE DOOR IS MATTE NOW (user 2026-09-13: "fix this door. It has a
  // reflection bug"). tod_door_green is a byte-for-byte clone of
  // green_tinted_edge — same texture, same tint, same scaleRGB 5 — with its
  // specular and reflection-probe response zeroed, because every material in
  // the vertigo pack is configured as a polished flat mirror (white albedo,
  // 97%-white gloss map, no normal map, reflectionProbeAmount 1) and a door
  // slab is the largest, dimmest, flattest surface in the room, so the
  // reflection won. Generated by tools/gen_tod_door_materials.js — READ ITS
  // HEADER before touching door materials; it also records the separate,
  // still-open probe-box bug. doorMatOf() below is the one selector.
  door: 'tod_door_green',
  clip: 'clip',
  // the stair ramp wedges (tower, crown, causeway, spire) — plain clip since
  // v16.61a so ZOMBIES climb the slope too; see the STAIR RAMP CLIP block up in
  // the constants (and why not metal_clip: the lit-area tool).
  rampClip: 'clip',
  // player-only clip for the breather lounges' window voids: bullets and
  // zombies pass, players stay in. Was MAT.rampClip until v16.61a split them.
  winClip: 'clip_player',
  sky: 'sky',
  // --- the crown (v9) ---
  crownStep: 'mwiii_vertigo_retro_synth_yellow_tinted',        // the last flight is GOLD — you can see the prize
  crownBand: 'mwiii_vertigo_retro_synth_pap',                  // the core's capital block
  crownRing: 'mwiii_vertigo_retro_synth_yellow_tinted_edge',   // glowing inlay ring on the deck
  crownFascia: 'mwiii_vertigo_retro_synth_cyan',               // cornice: the crown glows from 19000 units down
  exfilPad: 'mwiii_vertigo_retro_synth_green_tinted_edge',     // the way out
  // --- THE CIRCLET (v11) — a GOLD VALUE LADDER, not one flat yellow ---------
  // "More gold" is not "everything gold": gold only reads as gold against a
  // dark foil. Target proportions on the exterior are roughly 60% gold, 25%
  // velvet/brass, 10% white, 5% jewel. The old citadel was ~70% blue.
  // Every name below was checked against the installed
  // emox_mwiii_vertigo_assets.gdt on 2026-08-25 — that pack has 30 materials
  // and NO metal, so the ladder is built out of value, not out of a shader.
  // Beware: `_tinted_edge` exists ONLY for blue/green/orange/red/yellow (there
  // is no purple_tinted_edge and no cyan_tinted_edge), and the geometry lint's
  // colour loop would happily pass a name the linker then substitutes.
  crownGold: 'mwiii_vertigo_retro_synth_yellow',               // BRIGHT gold: points, arches, finial, rim strip
  crownGoldPanel: 'mwiii_vertigo_retro_synth_yellow_tinted',   // gold panel (#e3cd3b): the band courses
  crownBrass: 'mwiii_vertigo_retro_synth_orange_tinted',       // old brass (#ed871a): the dark foil the gold reads against
  crownGoldSeam: 'mwiii_vertigo_retro_synth_yellow_tinted_edge', // glowing gold seam: inlays only
  crownVelvet: 'mwiii_vertigo_retro_synth_purple_tinted',      // the cap under the floor, and the hall walls
  // ERMINE — the white fur roll at the bottom of the band, and the single
  // strongest read from the base arena (a bright annulus at the widest point of
  // the silhouette). NOTE: `white` is NOT in lint_tod_geometry.js's material
  // table by default; it was added there deliberately as BLOCK in this same
  // change, because an unclassified material is a HARD ABORT of the build gate.
  crownErmine: 'mwiii_vertigo_retro_synth_white',
  // the ermine's dark tails. `dark_white` is a neutral 0.188 grey (measured
  // value 2.8 against the ermine's 13.1) — the pack's only real dark short of
  // `off`, which is scaleRGB 0 and would read as a hole punched in the crown
  // against a night skybox rather than as fur. Added to lint_tod_geometry.js's
  // material table as BLOCK in the same change.
  crownErmineSpot: 'mwiii_vertigo_retro_synth_dark_white',
  jewelRuby: 'mwiii_vertigo_retro_synth_red_tinted_edge',
  jewelSapphire: 'mwiii_vertigo_retro_synth_blue_tinted_edge',
  jewelEmerald: 'mwiii_vertigo_retro_synth_green_tinted_edge',
};
// THE ONE MATERIAL RULE ON THE CROWN, and it is a build gate, not taste:
// lint_tod_geometry.js classifies `_tinted` / `_tinted_edge` as DECK and calls
// any DECK brush <= MAX_SLAB (64) thick IN Z a walkable floor. A 48-thick gold
// moulding 19,000 units in the air would become a floor node with no guard on
// any edge, and the baseline is `unguardedEdges: 0`. So:
//   ANY HORIZONTAL ELEMENT 64 UNITS THICK OR THINNER MUST USE A PLAIN COLOUR.
// That is why the rim strip and every fillet below are MAT.crownGold (plain)
// and the band courses — all hundreds thick — are MAT.crownGoldPanel.
// A vertical plaque (a jewel boss, the ruby) is safe at any thickness, because
// the test is on its Z extent, which is its height.
const BASE_LIGHT = '0.4 0.6 1';
const ROOF_LIGHT = '1 0.6 0.25';

// Sky / sun (Nastian T9 pack, installed)
//
// v14.37 — DARKER SKY (user 2026-08-30: "make the map darker or change the sky
// box to something dark"). Swapped miami_night -> dark_night, the pack's own
// darker pairing. THE SKYBOX AND SSI ARE WORLDSPAWN KEYS: they are baked into
// the .d3dbsp at compile, so this is a FULL-BUILD change and can never be a
// runtime swap (the spire's dynamic sky is done with fog instead — see
// _tod_atmosphere::spire_set_fog and its block comment).
//
// The two ssi entries are IDENTICAL except for the skybox they carry (diffed in
// acc_nastian_t9_skyboxes.gdt: same colorSRGB 0.7913/1/1/1, ev 6, evcmp 2.5,
// evmax 3.5, evmin 3, stops -2.2, pitch 130, bounceCount 4, dynamicShadow 1).
// So this swaps the SKY IMAGE and nothing about the sun rig — the lighting
// solve is unchanged and the LED bake has no new work to do.
//   acc_ssi_miami_night -> skybox_t9_mp_miami        (city glow, the old look)
//   acc_ssi_dark_night  -> skybox_t9_zm_silver_dark  (dark zm sky, this one)
// If a darker-still sky is ever wanted, the pack also ships
// skybox_t9_mp_black_sea and skybox_t9_mp_moscow; changing SKYBOX_MODEL alone
// is NOT enough — the ssi carries its own skyboxmodel key and would fight it,
// so always move the PAIR together, and update the zone's xmodel line.
// v14.40 — REVERTED TO MIAMI, and the reason is the whole design (user
// 2026-08-31: "But its only in the spire correct? Thats the whole point").
// THE SPIRE'S SKY IS THE CONTRAST, so darkening the TOWER works against it —
// arriving somewhere black is a smaller moment if you already were somewhere
// black. And the revert costs the spire NOTHING: at TOD_SPIRE_FOG_OPACITY 0.90
// with halfDist 1400, anything at sky distance is fully fogged, so the skybox
// is INVISIBLE from the spire no matter which one is baked. The baked sky
// therefore only ever decides how the TOWER looks — pick it for the tower.
// (v14.37 briefly shipped dark_night/silver_dark map-wide. Kept in history
// because the pairing is proven-good if a darker tower is ever wanted: the two
// ssi entries are identical apart from their skybox, so swapping the PAIR is a
// safe one-line change that does not touch the sun rig or the bake.)
// v17.78 (2026-09-05, user: "Still yellow, lets do this. Just revert back to the miami view.
// Revert all the code we touched to try to make this work and ill get a screenshot"): the
// MIAMI PAIR is back — the exact v17.70 sky — so the user can A/B screenshot Miami against the
// cybercity builds. The cybercity sky (v17.71-v17.77: tools/gen_tod_sky.js +
// source_data/tod_skybox.gdt, `skybox_tod_cybercity` / `tod_ssi_cybercity`) is DORMANT, not
// deleted: the files stay, nothing references them, and the pair below is the only switch.
// The same revert put the fsi back to zm_factory_volumetric, the spawn light back to
// `1 0.9 0.78`, LIGHT_TINT to null and the zone's xmodel line back to skybox_t9_mp_miami.
// v17.81 (2026-09-05, user "Looks good. Lets implement" on the v17.80 sun-volume fix): THE
// CYBERCITY NIGHT SKY IS BACK — the pair below and the zone's xmodel line, NOTHING ELSE. The
// fsi, the spawn light and LIGHT_TINT stay at their published (Miami-era) values, so the only
// difference from v17.80 is the sky image + its ssi clone. The yellow was never the sky
// (docs/107: the sun volume), so this is the first build where the sky is judged on a
// correctly lit base. Back to Miami = skybox_t9_mp_miami / acc_ssi_miami_night here + the
// zone's xmodel line (always the pair, never one of them).
const SKYBOX_MODEL = 'skybox_tod_cybercity';   // THE CYBERCITY SKY (docs/104) — self-authored, tools/gen_tod_sky.js
const SSI = 'tod_ssi_cybercity';               // its ssi: a clone of acc_ssi_miami_night carrying skyboxmodel skybox_tod_cybercity (LOCKSTEP with the line above)
// v17.77 THE RED-LIGHT TEST — the colour gel over EVERY point light the map emits (tower,
// lounges, crown, spire; applied inside light(), the single emitter). [r,g,b] multiplier in
// 0..1, luma held per light; `null` = off. The sun's gel is colorSRGB on the SSI above
// (source_data/tod_skybox.gdt) and the sky light's is `gen_tod_sky.js --tint` — the three
// together are "the light on the entire map". Full story at the light() block, §lights.
const LIGHT_TINT = null;   // v17.78: OFF (the v17.77 red test was [1, 0.2, 0.2]; the map came back "still yellow")

// PERKS (v5, user 2026-08-20): NO fixed perk ladder — the 6 machines PARK
// along the base-arena N wall and _tod_perk_scatter.gsc relocates them to
// random pads at load (+ reshuffles after each Panzer). Parking = graceful
// fallback: if capture ever fails they stay buyable here. 4 park via the
// stock prefabs; Widow's Wine + Electric Cherry have NO prefab — raw
// zm_perk_machine structs (map 1's exact recipe). DoubleTap retired from
// the roster (the 6: jugg, sleight, revive, staminup, widows, cherry).
// NINE machines now (user 2026-08-25: "I dont want a perk on the crown" +
// "2 on each breather"). PhD Flopper moved off the crown into the scatter pool,
// which makes the pad math land exactly: _tod_perk_scatter has 9 pads — the base
// arena (Quick Revive pinned) plus TWO on each of the four breathers — so 9
// machines fill every one. At 8 machines one breather pad was always empty.
//
// X SPACING RE-CUT 150 -> 130 to fit the ninth: ARENA is a 540 half-extent and
// the old row already reached 525, so a slot at 675 would have parked a machine
// OUTSIDE the arena wall. Parking is only the fallback position (the scatter
// relocates these at load) but it has to stay reachable if capture ever fails.
// v13.3 (user 2026-08-28: "I have downloaded the Bo7 perk machines. Can we
// miggrate to those machines?") — THE WHOLE ROSTER WEARS THE BO7/BO6 MESHES
// (wetegg/sat port, install-side at <root>\_custom\_wetegg\models\sat\ +
// per-machine GDTs in the shared source_data — root-only, our sync COPIES and
// never mirrors, so they survive builds; credits owed before publish, the
// pack ships no readme). Every machine is now the INLINE-STRUCT lane the
// widow's/cherry/nuke entries proved across v6-v13: stock
// perk_machine_spawn_init builds the machine script_model AND the
// zombie_vending trigger from the struct's model/noteworthy/script_string
// (_tod_perk_scatter.gsc:253's verified chain), so a model swap is JUST a
// model name. The retired stock prefabs carried only two extras: 6 clientside
// spot lights and 3 attack_spot structs — both pinned to the PARK ROW, which
// players never see lit (machines scatter at load), so nothing player-facing
// is lost. Noteworthies are copied VERBATIM from the stock prefabs (read
// 2026-08-28, map_source\_prefabs\zm\zm_core — doubletap is
// specialty_doubletap2, not "doubletap"). Every t10/sat machine has an _on
// twin with lit emissive maps; _tod_perk_lights swaps models at power-on.
// In-game verify list (first armed run): yaw convention (ports usually keep
// the stock -Y front — if all nine face backwards, flip the one yaw below),
// footprint vs the 130u park pitch and pad clearances, base seam at z=0.
const PERK_PARK = [
  { struct: 't10_zm_machine_juggernog',                  noteworthy: 'specialty_armorvest',         x: -520 },
  { struct: 't10_zm_machine_speed_cola_lava_all_fxanim', noteworthy: 'specialty_fastreload',        x: -390 },
  { struct: 't10_zm_machine_quick_revive',               noteworthy: 'specialty_quickrevive',       x: -260 },
  { struct: 't10_zm_machine_staminup',                   noteworthy: 'specialty_staminup',          x: -130 },
  // sat's custom Widow's Wine build — identified by the literal "WIDOW'S
  // WINE" on its emissive text plate (the pack's codenames say nothing).
  { struct: 'sat_zm_machine_y_mod',                      noteworthy: 'specialty_widowswine',        x: 0 },
  // v14.16: struct model caught up with the v13.19 Death Perception swap —
  // this row still said elemental_pop, which v13.19 deliberately UN-ZONED, so
  // the .map's pre-registration window pointed at an unpacked xmodel (the
  // runtime machine_assets stamp hid it within a frame; cosmetic, but wrong).
  { struct: 't10_zm_machine_death_perception',           noteworthy: 'specialty_combat_efficiency', x: 130 },
  { struct: 't10_zm_machine_d_mod_cowboy_fxanim',        noteworthy: 'specialty_doubletap2',        x: 260 },
  // v14.16: WISP TEA (BO7, SAT custom mesh) replaces Deadshot — same slot,
  // same everything. Deadshot's yaw-359.999 override died with its off-mesh
  // rotation exception; the wisp pair is one mesh + a skin override, so it
  // takes the uniform yaw. Module: scripts/zm/_zm_perk_wisp_tea.gsc (sets
  // its own machine_assets off/on pair — _tod_perk_lights leaves it alone).
  { struct: 'sat_zm_machine_w_mod_fxanim',               noteworthy: 'specialty_nomotionsensor',    x: 390 },
  // PhD FLOPPER — registered OVER the stock cherry specialty (_tod_perk_phd.gsc).
  // v13.3: a REAL PhD machine at last — the nuke vending model was only ever a
  // stand-in ("reads as ordnance") from the era when no PhD mesh existed.
  { struct: 't10_zm_machine_phd_flopper',                noteworthy: 'specialty_electriccherry',    x: 520 },
];
const PERK_PARK_Y = 511;   // base N wall interior, machines face south (500 -> 511 v13.5: the BO7 meshes are shallower than the p7 stock ones — user: "QR has a bit of space between its back and the wall"; the scatter pads moved 11u wallward in lockstep)
// (WALLBUYS REMOVED — user 2026-08-20: never asked for; the box + class guns carry weapons)
// x1.5 2026-08-20 (user): was 750 +250/lap cap 4000 -> 1125 +375/lap cap 6000.
// v9.41 2026-08-23 (user: "Doors cost too much. Lets make it so they
// increase by 200 every level"): the STEP drops 375 -> 200; lap-1 door and the
// 6000 cap unchanged. The cap now binds at lap 26 (was lap 14): laps 1-25 cost
// 1125..5925, laps 26-50 cost 6000. Climb total to the roof door: 238,125 (was
// 265,875) + the 7500 roof door. The cost rides in BOTH the .map entity
// (zombie_cost, for the BSP) and the generated _tod_door_data.gsc — the GSC
// prefers the data-file value, so a price change is a -GscOnly build.
// v10.4 2026-08-23 — THE LADDER WAS THE MAP'S REAL LENGTH, and it was too long.
// Summed rather than estimated: the 52 generated rows totalled 186,975, and the
// flat 25,000 extraction on top made the minimum win path 211,975. The fastest
// solo class does not cross that until round 27-28 (round ~29 once a realistic
// perk + PaP kit is bought), i.e. 90-120 minutes with no between-round pause —
// and it lands on top of the ammo curve going negative, on a map with no box and
// no wallbuys. The finale is the best content in the map and essentially nobody
// was reaching it.
//
// The perverse part that made it worse than it looked: BO3 pays 10 per damaging
// HIT, so building damage REDUCES income. A PaP'd, DAMAGE-Lv5 MAC-10 cuts points
// per zombie ~42% — the player who builds correctly arrives LATER.
//
// One lever, pulled hard, per the audit: the ladder itself. base/step/cap only —
// ROOF_DOOR_COST and POWER_DOOR_COST are deliberately untouched to keep the
// change surface small.
//   ladder    178,725 -> 106,680  (57%)
//   win path  211,975 -> 139,930  (66%)
//   floor 10   15,750 ->  10,200      floor 20  41,500 -> 26,400
//   floor 30   77,250 ->  48,600      floor 40 123,000 -> 76,680
//   cap now binds at lap 39 (was lap 50, i.e. never in practice)
// Floor 10 still costs a real climb, so the first non-QuickRevive perk is still
// earned rather than handed over. TUNE HERE FIRST if the beta says the run is
// still long — this is the one knob that moves the map's length, and the number
// to playtest is THE ROUND EXTRACTION BECOMES BUYABLE, not the door price.
const DOOR_COST_BASE = 750;    // the lap-1 door (was 1125)
const DOOR_COST_STEP = 60;     // per lap (was 100, was 200, was 375)
const DOOR_COST_CAP  = 3000;   // was 6000 — bound at lap 50, so it never really applied
function doorCost(lap) { return Math.min(DOOR_COST_BASE + DOOR_COST_STEP * (lap - 1), DOOR_COST_CAP); }
const ROOF_DOOR_COST = 7500;   // x1.5 2026-08-20 (was 5000)
const POWER_DOOR_COST = 750;   // x1.5 2026-08-20 (was 500) — the power-room gate
// THE TELEPORT BAY GATE (user 2026-08-24: "it shoud cost money to open that
// room"). 1500 = the price of admission to the teleport network in BOTH
// directions (the down-pads are gated on this same flag, so the bay is the
// network's terminus and buying it once turns the whole thing on). It is
// deliberately not a lap-door price: the first up-pad it can actually serve is
// FLOOR 10, which already sits behind 15,750 points of lap doors, so this is
// never the thing standing between a player and the climb.
const TPBAY_DOOR_COST = 1500;

// BREATHER LANDMARKS (user 2026-08-19: "every 5 or so levels you have a
// breather landmark"): the NE landing grows a big flat balcony extending
// north + east — same laps as the wallbuys, so each breather is a restock
// stop. The rooftop is the FINAL lap's breather (see LAPS). Each balcony: 1 floor + 3 parapets
// (lap neon color), the NE-landing parapet opens into it, an extra zone
// brush + light. Net +3 brushes/lap = trivial vs the bake budget.
const BREATHER_LAPS = new Set([10, 20, 30, 40]);   // respaced for 50 laps (still 4, still 2 perks each)
// v9.37 (user 2026-08-23: "the breather platforms are too small and need to
// be expanded") — balcony 384x400 -> 544x576 (~2x the floor). Everything
// that hangs off these two numbers (parapets, rail caps, zone volumes, the
// balcony light at BR_DEPTH/2, VOL_R) follows automatically. The SCRIPTED
// furniture does NOT — it backs the walls by hand: _tod_perk_scatter pads
// (S wall), _tod_upgrades breather station (W wall), _tod_teleport pad
// (SE quarter), _tod_powerups PaP (N edge). Keep those four in lockstep.
const BR_DEPTH = 576;   // extension beyond PX (was 400)
const BR_EAST = 384;    // widening beyond PX (was 224)

// ---------------------------------------------------------------------------
// v13 — THE BREATHER LOUNGES (user 2026-08-28: "redesign the breather areas so
// they are nicer and more atmospheric ... space things out a bit better ...
// pap and ammo box are so close to each other that it can trigger the wrong
// thing ... Maybe each one can have its own color theme ... Teleporter can be
// off in its own pathway that stems from the breather room ... maybe the idea
// of putting a roof and walls in these breathers. I dont really want to add
// furniture.") Three moves, ZERO new models — brushwork plus the furniture
// that already exists:
//
// 1. ROOF + WALLS. The open deck becomes an enclosed room: each old parapet
//    band grows into a full wall — 56 SILL (the old rail line), a 136-tall
//    WINDOW BAND (glowing mullions; the voids carry clip_player so nobody
//    climbs out but BULLETS PASS — zombies on the gantry and on the stairs
//    above are shootable through the windows), a 96 LINTEL band, and a dark
//    roof with a glowing theme trim ring. The climb stays open-air; the
//    breather now reads as shelter. THE ROOF IS 72 THICK ON PURPOSE:
//    lint_tod_geometry calls any _tinted/_tinted_edge slab <= 64 thick a
//    walkable DECK and would demand guards on a surface nobody can reach
//    (every approach above it is already railed + rail-capped).
//
// 2. ONE COLOR PER BREATHER (BREATHER_THEME): floor grid, sill, mullions,
//    roof trim, gate and the room lights all speak a single hue — 10 BLUE
//    (the base arena's color: the city follows you up), 20 GREEN, 30 ORANGE,
//    40 GOLD (the crown's color — the last stop foreshadows the prize). All
//    four keys come from the `_tinted_edge` five (blue/green/orange/red/
//    yellow) so the floor can carry the theme; RED is deliberately unused —
//    on this map red means danger (beacon, ruby, boss), never rest. What
//    this replaces: laps 10/20/30/40 all hit EDGE_COLORS[4], so all four
//    floors were the SAME yellow with rails in four unrelated palette colors.
//
// 3. THE TELEPORTER SPUR: the porter moves off the room floor entirely —
//    through a doorway in the outer wall, down an open-air 160-wide gantry,
//    onto a 288x288 pad platform floating in the void. Room = shelter,
//    gantry = exposure, and the pad's idle beam marks the departure lounge
//    from the whole tower. The doorway is a double frame: the wall's own
//    192-tall opening, then a 240-tall gate (posts + lintel) at the gantry's
//    head. The spur has NO risers and no roof; pressure walks in through the
//    gate — the deck riser 42u inside the mouth keeps the annex from ever
//    being a quiet camp pocket.
//
// THE SPACING FIX RIDES ON THIS — each interactable now owns a wall:
//    N wall (entrance side)  UPGRADE STATION   (was W wall)
//    W wall                  PACK-A-PUNCH      (was parked IN the entrance
//                            path at (-320,-470), its trigger 174u from the
//                            crate's with both costing 5000 — the reported
//                            wrong-buy)
//    E wall                  AMMO CRATE        (unchanged)
//    S wall                  the two PERK PADS (unchanged) + the spur doorway
// BR_FURN below is the single source of truth: asserted for pairwise trigger
// clearance at generation time and emitted as GENERATED
// scripts/zm/zm_tower_of_doom/_tod_breather_data.gsc (the door-data no-drift
// contract), which _tod_powerups / _tod_upgrades / _tod_ammo_crate /
// _tod_teleport read. _tod_perk_scatter keeps its own pad table (machines
// relocate at runtime); its two S-wall pads are mirrored into BR_FURN for the
// assert with a lockstep note there.
// ---------------------------------------------------------------------------
const BR_WALL_H  = 288;      // room wall: 56 sill + 136 window + 96 lintel
const BR_SILL_H  = PARA_H;   // 56 — the old parapet height IS the sill
const BR_WIN_TOP = 192;      // window band spans z mid+56 .. mid+192
// BR_ROOF_TH: RETIRED v13.6 (user 2026-08-29: open-top lounges — "You cant
// look up and see the tower so it kinda makes it worse"). Kept as a comment,
// not a live define, so nobody reads a roof-thickness constant and concludes
// the lounges have roofs. If a lid ever returns, it must be >64 thick or the
// geometry lint's DECK rule classifies it walkable and demands edge guards —
// that was the whole reason the retired value was 72.
const BR_MULL_W  = 28;       // window mullion width (thin bright strut)
const BR_TRIM_W  = 24;       // glowing trim ring on the roof, 8 proud
// ---------------------------------------------------------------------------
// v16.7 — THE LOUNGE POLISH PASS (user 2026-09-01: "continue enhance however
// we can"). Brushwork only, in the lounge's own three materials: ZERO models,
// ZERO footprint change, no trigger moves beyond two centring nudges recorded
// in BR_FURN. The room stops reading as an empty box with machines pushed
// against the walls and reads as a furnished pavilion:
//   FIXTURE PANELS  the window bay BEHIND each machine goes solid in the
//                   theme's edge-lit grid (the floor material stood up) — a
//                   lit backboard per amenity, so every machine has a halo
//                   and from the stairs the four lit bays are four signs. The
//                   whole perk wall is one panel (the bar back); the other
//                   three take the middle bay between their wall's mullions.
//   FINIALS         a glow post on each room corner above the cap band, so the
//                   open-top room (roof gone since v13.6) keeps a silhouette
//                   from the flights above and from below.
//   FLOOR INLAY     a 1-proud glowing ring at the room centre with a spoke to
//                   each amenity — the base arena's inlay construct, the pad
//                   ring's height: the floor points at the four things.
//   PAD PYLONS      four glow posts straddling the platform's rail corners:
//                   the floating pad gets verticals and reads as a dock.
//   GANTRY HOOPS    two door-height frames over the walkway (the gate's own
//                   post+lintel language repeated): a lit jetway, not a plank.
//   UNDERSIDE       a slab-thick glow band under the four wall bands (the
//                   sills used to float over nothing — from the flights below
//                   and from the base, 3,600u down, that outline IS the
//                   lounge), stepped pendants under three wall midpoints and a
//                   thruster cube under the pad. docs/34's lesson applied: the
//                   underside is most of the pixels anyone ever sees.
//   ACCENT LIGHTS   one theme-coloured pool per fixture (lights section).
// Script side (same version): ambient FX per lounge in _tod_atmosphere.gsc
// (motes, haze, pad fog, a vent) and a per-player first-arrival chime.
// Design record: docs/42 §v16.7.
//
// ONE SWITCH REVERTS THE WHOLE PASS (user 2026-09-01: "Keep your changes
// noted. I may want to revert."): BR_POLISH=false drops every v16.7 brush and
// light AND restores the pre-v16.7 BR_FURN coordinates (the two nudges), so a
// regen reproduces the v16.6 .map byte-for-byte (proven by md5 against the
// saved pre-pass map when the switch was added). The script half has its own
// switch, TOD_LOUNGE_AMBIENCE in _tod_atmosphere.gsc. Flipping this is
// geometry -> regen + FULL build.
// ---------------------------------------------------------------------------
const BR_POLISH   = true;
// v16.57 (user 2026-09-02: "remove the windows blocking views in the breather
// rooms of the first tower"): the v16.7 FIXTURE PANELS — the solid boards that
// filled the window bay behind every machine (the whole perk wall was one) —
// are OFF. Every bay is an open window again (mullions + clip_player void, the
// v13 look); the finials, inlay, pylons, hoops, under-glow and lights stay.
// Geometry -> regen + FULL build. true restores the panels.
const BR_WIN_PANELS = false;
const BR_FIN_W    = 36;      // finial footprint — 8 proud of the 20 wall band each side
const BR_FIN_H    = 128;     // finial height above the cap band
const BR_RING_R   = 120;     // floor inlay ring, outer half-size (240 square)
const BR_INLAY_W  = 20;      // ring / spoke width (the pad ring's)
const BR_PYLON_W  = 36;      // pad pylon footprint, centred on the rail corner
const BR_PYLON_H  = 240;     // pad pylon top above the platform (the gate post's height)
const BR_HOOP_N   = 2;       // gantry hoops (posts + lintel) over the neck
const BR_PEND     = [[64, 48], [32, 48], [16, 48]];   // pendant tiers: [half-width, height], top tier first
// The spur, authored in the ODD frame like the rest of the breather block
// (brBox mirrors it; every shipped breather lap is EVEN — asserted below).
const SPUR_CX    = 704;                      // gantry centreline
const SPUR_W     = 80;                       // walkway half-width (160 clear)
const SPUR_Y0    = PX + BR_DEPTH;            // 992  — leaves the room here
const SPUR_Y1    = SPUR_Y0 + 320;            // 1312 — gantry ends, platform starts
const SPUR_Y2    = SPUR_Y1 + 288;            // 1600 — platform far edge
const SPUR_PAD_Y = (SPUR_Y1 + SPUR_Y2) / 2;  // 1456 — porter centre
const BREATHER_THEME = {
  10: { key: 'blue',   light: '0.35 0.55 1' },
  20: { key: 'green',  light: '0.35 1 0.6'  },
  30: { key: 'orange', light: '1 0.6 0.25'  },
  40: { key: 'yellow', light: '1 0.85 0.35' },
};
for (const l of BREATHER_LAPS) {
  // The furniture data file and the crate's collision clip are emitted in the
  // EVEN (mirrored) frame because every breather lap is even. If one ever
  // lands on an odd lap the geometry mirrors itself (brBox), but the data
  // emission needs a parity pass — refuse to build a half-mirrored map.
  if (l % 2 !== 0) throw new Error(`breather lap ${l} is ODD — _tod_breather_data emission assumes the mirrored frame`);
  if (!BREATHER_THEME[l]) throw new Error(`breather lap ${l} has no BREATHER_THEME entry`);
}
// Furniture, EVEN-frame absolutes (the frame all four breathers sit in).
// trig = where the use-trigger stands, r = its radius (r mirrored from each
// owner script: PaP/station 64, crate 72, perk vending ~48, teleporter 110).
// MIN_TRIG_GAP makes the v10.4 rule mechanical: rims must clear by a stride,
// not merely avoid touching — the shipped PaP/crate pair had a 38u rim gap
// and produced the wrong-buy report this redesign exists to fix.
// v16.7: two CENTRING NUDGES so each machine sits on the axis of the window
// bay that now carries its lit panel — PaP y -680 -> -704 (the long walls'
// middle bay, between the mullions, is y[-786,-622]) and station x -500 ->
// -520 (the entrance wall's west bay is x[-604,-436]). Every clearance was
// re-measured: the assert below, the risers (-750,-460)/(-750,-950), the
// respawn spots (BREATHER_SPAWN_XY, >=130u station / >=230u PaP kept) and the
// doorway. The spire hubs read the same table, so their PaP moved with it.
// v19.71 (2026-10-03, the perch pass — Workshop tester: "the heavenly perk machine ... is
// bumped out a little bit so you could run behind it. I wonder if you just bumped that up
// against the wall"): EVERY VENDOR STANDS FLUSH. The PaP stood 56 off its wall and the
// altar 44 (both meshes reach only ~19 behind their origin — measured: tod_heavenly_altar
// y[-27.85,19.0], the ALXS PaP xmodel y[-22.2,18.4]), so the PaP left a 37-unit slot behind
// it, wider than a player (30); the crate stood 17 off the window sill. All three now sit
// VENDOR_STANDOFF / 1 unit off their walls, so the perch caps bury into the wall behind
// them. Each moves straight back along its own axis; its trigger moves with it.
//   pap     W wall x = -(PX + BR_EAST) = -800:  org -744 -> -780, trig -688 -> -724
//   station N wall y = -PX = -416:              org -460 -> -436, trig -516 -> -492
//   crate   E wall x = -CORE = -256:            org -310 -> -294 (its body's back edge 1 off the sill)
const VENDOR_STANDOFF = 20;   // a PaP's / an altar's origin this far off its wall: the mesh's back (~19) touches it
const BR_FURN = {
  pap:     { org: [-(PX + BR_EAST) + VENDOR_STANDOFF, BR_POLISH ? -704 : -680], trig: [-(PX + BR_EAST) + VENDOR_STANDOFF + 56, BR_POLISH ? -704 : -680], yaw: 90,      r: 64 },  // W wall, faces east (v16.7: y -680 -> -704; v19.71 flush)
  station: { org: [BR_POLISH ? -520 : -500, -PX - VENDOR_STANDOFF], trig: [BR_POLISH ? -520 : -500, -PX - VENDOR_STANDOFF - 56], yaw: 359.999, r: 64 },  // N wall, faces south (v16.7: x -500 -> -520; v19.71 flush)
  crate:   { org: [-CORE - 1 - 37, -700], trig: crateTrig([-CORE - 1 - 37, -700], CRATE_YAW_W), yaw: CRATE_YAW_W, r: CRATE_TRIG_R },  // E wall, faces west (v17.37: 270 -> the one crate convention; v17.38: trig 56 in front, the PaP/station grammar; 2026-09-24: re-centred + r 100, see crateTrig; v19.71 flush: -310 -> -294)
  perk_e:  { trig: [-360, -970], r: 48 },   // _tod_perk_scatter pads — HAND-SYNCED there (v13.5: -959 -> -970, wallward with the BO7 meshes)
  perk_w:  { trig: [-536, -970], r: 48 },   //   (v13.5 lockstep; listed for the assert only)
  tp:      { trig: [-SPUR_CX, -SPUR_PAD_Y], r: 110 },   // the spur pad (TOD_TP_TRIG_RADIUS)
};
const MIN_TRIG_GAP = 64;
const TP_ARRIVE_OFF = 160;   // up-riders land this far up the gantry, toward the room
const TP_GATHER = 120;       // mirrored from _tod_teleport.gsc TOD_TP_GATHER (assert only)
{
  const ks = Object.keys(BR_FURN);
  for (let i = 0; i < ks.length; i++) for (let j = i + 1; j < ks.length; j++) {
    const a = BR_FURN[ks[i]], b = BR_FURN[ks[j]];
    const d = Math.hypot(a.trig[0] - b.trig[0], a.trig[1] - b.trig[1]);
    const need = a.r + b.r + MIN_TRIG_GAP;
    if (d < need) throw new Error(`breather furniture ${ks[i]}<->${ks[j]}: triggers ${Math.round(d)}u apart, rims need ${need}`);
  }
  // A landing rider inside the pad's own gather is swept along by the next
  // departure (v10.4); and the pad trigger must not reach the platform rails.
  if (TP_ARRIVE_OFF <= TP_GATHER) throw new Error('tp arrival lands inside the pad gather');
  if ((SPUR_Y2 - SPUR_Y1) / 2 - BR_FURN.tp.r < 24) throw new Error('tp pad trigger reaches the platform rails');
}

// ---------------------------------------------------------------------------
// Emitters (proven plane family — do not touch the placeholder numbers)
// ---------------------------------------------------------------------------
let guidCounter = 0x100;
function guid() {
  guidCounter++;
  const c = guidCounter.toString(16).toUpperCase().padStart(12, '0');
  return `{7D0DB000-70D0-4E0A-8A3F-${c}}`;
}

function box(x1, x2, y1, y2, z1, z2, tex) {
  if (x1 >= x2 || y1 >= y2 || z1 >= z2) {
    throw new Error(`degenerate box ${tex}: x[${x1},${x2}] y[${y1},${y2}] z[${z1},${z2}]`);
  }
  const t = `${tex} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  return [
    '{',
    ` guid "${guid()}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,
    ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`,
    '}',
  ].join('\n');
}

// v17.88 (docs/110): a box whose faces carry an EXPLICIT texture size and
// offset — the face string is "<mat> xSize ySize xOff yOff rot 0", so a 256 x
// 128 plaque maps its whole image once when xs/ys are the face's own extent
// and the offsets cancel the world position (the projection is axial from the
// world origin, U = the face's horizontal world axis, V = world z).
function boxTex(x1, x2, y1, y2, z1, z2, tex, xs, ys, xo, yo) {
  const plain = box(x1, x2, y1, y2, z1, z2, tex);
  return plain.split(`${tex} 128 128 0 0 0 0`).join(`${tex} ${xs} ${ys} ${xo} ${yo} 0 0`);
}
function addBoxTex(label, x1, x2, y1, y2, z1, z2, tex, xs, ys, xo, yo) {
  addBox(label, x1, x2, y1, y2, z1, z2, tex);
  const b = worldBrushes[worldBrushes.length - 1];
  b.text = boxTex(x1, x2, y1, y2, z1, z2, tex, xs, ys, xo, yo);
}
// v19.69 THE SURFACE REFRESH: a box whose faces may each carry their OWN material
// (and texture size/offset). `faces` maps 'bottom' | 'top' | 's' (y1) | 'e' (x2) |
// 'n' (y2) | 'w' (x1) to a material name or [mat, xs, ys, xo, yo]; an absent key
// keeps `tex` with the default 128 mapping. NO KEY SET = plain addBox, byte for
// byte (the refresh switches' revert proof rests on this). The brush keeps the
// guid addBox gave it, so a per-face brush consumes exactly one guid like any box.
// The face ORDER is box()'s, which every parser of this map reads.
function addBoxFaces(label, x1, x2, y1, y2, z1, z2, tex, faces) {
  addBox(label, x1, x2, y1, y2, z1, z2, tex);
  if (!faces || !Object.keys(faces).length) return;
  for (const k of Object.keys(faces)) if (!['bottom', 'top', 's', 'e', 'n', 'w'].includes(k)) throw new Error(`addBoxFaces ${label}: unknown face key ${k}`);
  const b = worldBrushes[worldBrushes.length - 1];
  const g = /guid "([^"]+)"/.exec(b.text)[1];
  const spec = (k) => {
    const f = faces[k] === undefined ? tex : faces[k];
    return Array.isArray(f) ? `${f[0]} ${f[1]} ${f[2]} ${f[3]} ${f[4]} 0 0` : `${f} 128 128 0 0 0 0`;
  };
  const t = (k) => `${spec(k)} lightmap_gray 16384 16384 0 0 0 0`;
  b.text = [
    '{',
    ` guid "${g}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t('bottom')}`,
    ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${t('top')}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t('s')}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t('e')}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t('n')}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t('w')}`,
    '}',
  ].join('\n');
}
const worldBrushes = [];

// ---------------------------------------------------------------------------
// NAVMESH SEEDS ON SURFACES NO RISER STANDS ON (2026-09-04)
// ---------------------------------------------------------------------------
// Seeds are emitted one per RISER (tower §5, spire §6f) and risers live ONLY on
// LANDINGS by construction — §6f says so in its own words ("a riser on a stair
// hangs in mid-air or buries itself under a crest"). So every STAIR FLIGHT, and
// on the spire every crate shelf, hub porch fan and the summit apron, has
// carried no seed at all.
//
// THAT IS NOT THE SAME AS "covered by the landing's seed". cod2map64 is Havok AI
// region pruning, not a flood: it meshes the world, splits it into CONNECTED
// REGIONS, and keeps a region only if its AREA clears a threshold OR a seed sits
// on it (within pruning.minDistanceToSeedPoints = 14). A region CONNECTED to a
// seeded one can still be dropped, and this map has already paid for that lesson
// twice (the detached spire v14.19, the tower above ~floor 17 v17.7). The
// evidence that it is still paying: v17.14 took the spire from 22 seeds to 278
// with BYTE-IDENTICAL GEOMETRY and the .hkt went 110,468 -> 114,624. Entities
// that add no surface cannot grow a mesh unless previously-PRUNED regions are
// now KEPT — so regions were being pruned, and per-landing seeding recovered
// only some of them.
//
// THE RULE, third time of writing and the first time stated about SURFACES:
// seed every walkable SURFACE, not every walkable zone and not every riser.
// Risers are a SPAWN table; they were never a COVERAGE table. Because the ramp
// seeds are taken inside rampWedgeY/rampWedgeX themselves, from the very
// arguments the wedge is built from, a new flight anywhere in this map is
// seeded by construction and cannot be forgotten again.
//
// node_pathnode is free: it is on radiant/configs/navmesh.json's EXCLUSION list
// (carves nothing), is invisible, and spawns NO runtime gentity, so the ~1024
// gentity budget is untouched. Buffered rather than emitted inline because
// `entities` / ent() do not exist yet at this point in the file (the tower's
// ramps are written ~2,500 lines before them); flushed after section 6.
const navSeeds = [];
function navSeed(label, x, y, z) {
  navSeeds.push({ label, org: [Math.round(x), Math.round(y), Math.round(z)] });
}
// ONE KNOB. 3 puts a seed roughly every 128 units of run / 48 of rise on a
// standard flight. Drop to 1 if the entity count ever matters; raise if a .hkt
// delta says the mesh still fragments finer than this.
const RAMP_SEEDS = 3;
// THE CROWN MEASURES ITSELF. The sky seal used to be asserted against DERIVED
// constants (CR_OUT_X / CR_OUT_Y), and those understate the truth: the east and
// west point HEADS stand 200 units proud of the band they sit on, so the derived
// figure was 104 short before anyone scaled anything. An element that sticks out
// further than its own constant suggests is exactly the bug the seal assert
// exists to catch, so the assert reads THIS instead — the real bounding box of
// every brush actually emitted with a crown or mast label.
const crownBB = { x1: Infinity, x2: -Infinity, y1: Infinity, y2: -Infinity, z1: Infinity, z2: -Infinity };
const crownBoxes = [];
// v19.68t: EVERY box, for the end-of-file sightline checks (the floor-number signs
// and the rocket prompt rings read it; nothing is emitted from it)
const ALL_BOXES = [];
function addBox(label, x1, x2, y1, y2, z1, z2, tex) {
  ALL_BOXES.push({ label, x1, x2, y1, y2, z1, z2, tex });
  if (/^(crown|mast)\b/.test(label)) {
    crownBB.x1 = Math.min(crownBB.x1, x1); crownBB.x2 = Math.max(crownBB.x2, x2);
    crownBB.y1 = Math.min(crownBB.y1, y1); crownBB.y2 = Math.max(crownBB.y2, y2);
    crownBB.z1 = Math.min(crownBB.z1, z1); crownBB.z2 = Math.max(crownBB.z2, z2);
    // kept for the road-intrusion assert in 5f.9 — see the comment there
    crownBoxes.push({ label, x1, x2, y1, y2, z1, z2 });
  }
  worldBrushes.push({ label, text: box(x1, x2, y1, y2, z1, z2, tex) });
}

// --- crown mirror helpers ---------------------------------------------------
// Every crown box/point/yaw below is authored in the ODD frame (E flight up the
// east face, arriving on the NORTH apron). When the crown lap is EVEN the whole
// assembly is point-mirrored through the tower axis (x,y -> -x,-y), which maps
// the E flight onto the W flight and the N arrival onto the S arrival — exactly
// the mirror the spiral itself uses. Mirroring an interval flips its ends, so
// cbox re-orders them to keep x1<x2 / y1<y2 (the degenerate-box rule).
// Crown architecture uses true convex solids. Bounding boxes still feed the
// sky/causeway clearance assertions; emitted planes feed the independent tools.
const CB = require('./convex_brush');
const PERCH = require('./perch_core');   // v19.71: the perch model shared with tools/lint_tod_perches.js
function crownPoly(label, vertices, faces, tex) {
  const vs=vertices.map(p=>cpt(...p));
  const center=[0,1,2].map(i=>vs.reduce((s,p)=>s+p[i],0)/vs.length);
  const planes=faces.map(face=>{
    let v=face.slice(0,3).map(i=>vs[i]);
    let q=CB.plane(v,tex);
    if(CB.dot(q.n,CB.sub(center,v[0]))>0){v=[v[2],v[1],v[0]];q=CB.plane(v,tex);}
    if(face.some(i=>Math.abs(CB.dot(q.n,vs[i])-q.d)>0.01))
      throw new Error(`non-planar crown face: ${label}`);
    if(vs.some(p=>CB.dot(q.n,p)>q.d+0.01))
      throw new Error(`non-convex crown profile: ${label}`);
    return q;
  });
  crownPlanes(label,planes,tex);
}
function crownPlanes(label,planes,tex) {
  const h=CB.hull(planes);
  // Use the existing accounting path, then replace just its brush definition.
  addBox(label,h.x1,h.x2,h.y1,h.y2,h.z1,h.z2,tex);
  const lines=planes.map(q=>rampPlane(...q.v,q.mat));
  worldBrushes[worldBrushes.length-1].text=['{',` guid "${guid()}"`,...lines,'}'].join('\n');
}
function crownBevel(label,x1,x2,y1,y2,z1,z2,tex,amount) {
  const lo=[CM===1?x1:-x2,CM===1?y1:-y2,z1];
  const hi=[CM===1?x2:-x1,CM===1?y2:-y1,z2];
  const mid=lo.map((v,i)=>(v+hi[i])/2), half=lo.map((v,i)=>(hi[i]-v)/2);
  const b=Math.min(amount,...half.map(v=>v*0.42));
  const ps=[];
  function cut(n,d,mat) {
    n=CB.norm(n);const point=mid.map((v,i)=>v+n[i]*d);
    const u=CB.norm(CB.cross(n,Math.abs(n[2])<0.9?[0,0,1]:[0,1,0]));
    const v=CB.cross(n,u);
    ps.push(CB.plane([point.map((x,i)=>x+u[i]*128),point,point.map((x,i)=>x+v[i]*128)],mat));
  }
  for(let a=0;a<3;a++)for(const sign of [-1,1]){const n=[0,0,0];n[a]=sign;cut(n,half[a],tex);}
  for(let a=0;a<3;a++)for(let c=a+1;c<3;c++)for(const sa of [-1,1])for(const sc of [-1,1]){
    const n=[0,0,0];n[a]=sa;n[c]=sc;
    cut(n,(half[a]+half[c]-b)/Math.SQRT2,tex===MAT.crownBrass?MAT.crownGoldPanel:tex);
  }
  crownPlanes(label,ps,tex);
}
function cbox(label, x1, x2, y1, y2, z1, z2, tex) {
  // Only decorative solid architecture: walking slabs, structural wall seals,
  // vendor clips and floor inlays retain their exact collision contracts.
  if(/^crown (point|rib |front cross|finial|jewel|cullinan|pendilia|girandole|monde|beacon|mouth jamb|mouth corbel|hall pier|hall shrine.*(pilaster|canopy)|hall reredos|gate post|cornice)/.test(label)
      && !/^(clip|sky)/.test(tex)) {
    crownBevel(label,x1,x2,y1,y2,z1,z2,tex,Math.min(48,Math.min(x2-x1,y2-y1,z2-z1)*0.18));return;
  }
  if (CM === 1) addBox(label, x1, x2, y1, y2, z1, z2, tex);
  else addBox(label, -x2, -x1, -y2, -y1, z1, z2, tex);
}
// Loft matching convex profiles; shared boundaries are identical, avoiding
// stair-step silhouettes and cracks between adjacent ribbon sections.
function crownLoft(label,lower,upper,tex) {
  const n=lower.length,faces=[Array.from({length:n},(_,i)=>i),Array.from({length:n},(_,i)=>i+n)];
  for(let i=0;i<n;i++)faces.push([i,(i+1)%n,(i+1)%n+n,i+n]);
  crownPoly(label,[...lower,...upper],faces,tex);
}
function crownOct(hx,hy,z,c=Math.min(CR_CHAM,Math.min(hx,hy)*0.32)) {
  return [[-hx+c,-hy],[hx-c,-hy],[hx,-hy+c],[hx,hy-c],[hx-c,hy],[-hx+c,hy],[-hx,hy-c],[-hx,-hy+c]].map(([x,y])=>[x,CR_CY+y,z]);
}
function crownOrb(tag,x,y,z,rx,ry,rz,tex) {
  const n=12,stacks=8;
  for(let j=0;j<stacks;j++) {
    const ring=t=>{const r=Math.max(0.015,Math.cos(t));return Array.from({length:n},(_,i)=>{
      const a=i*2*Math.PI/n;return [x+rx*r*Math.cos(a),y+ry*r*Math.sin(a),z+rz*Math.sin(t)];});};
    crownLoft(`${tag} facet ${j+1}`,ring(-Math.PI/2+Math.PI*j/stacks),ring(-Math.PI/2+Math.PI*(j+1)/stacks),tex);
  }
}
function cpt(x, y, z) { return [CM * x, CM * y, z]; }
function cyaw(y) { return CM === 1 ? y : ((y + 180) % 360); }

// ---------------------------------------------------------------------------
// v19.71 PERCH CAPS (2026-10-03, docs/171). A Workshop tester, as the Slasher with
// the ATHLETE wall-run: "first attempt am on top of the [ammo] box and cant be hit
// ... Same thing with quick revive ... I was able to replicate this with rampage
// also ... I'm sure these could be found on each floor." User: "Wall running seems
// to have not been thought through enough ... Even the slanted clips might help from
// abandoned cybercity map ... think and resolve any potential gaps."
//
// Every prop in this map stood in for its missing collision with a FLAT-TOPPED box
// (the crate's 58-tall clip, the inducer's 40, the power terminal's 88, the stock
// zm_collision_perks1 boxes under every perk machine, altar, PaP and the uplink).
// A zombie swings only when the player is within 64 of it in 3D (stock
// zombieShouldMeleeCondition), so a player on any of those tops is untouchable, and
// the athlete jumps 2.25x higher (~88) and runs on walls. A flat top is a perch.
//
// THE CAP: a steep player-only (clip_player — bullets, zombies, grenades and bodies
// pass) WEDGE over the prop, its low edge at the prop's front and its high edge
// BURIED in the wall behind it, so there is no ridge to balance on (a capsule can
// rest on an exposed apex) and no V-notch against the wall to wedge into. A player
// who lands on it slides off the front. The angle is map 1's, paid for in play:
// abandoned_cyber_city_zombies add_prop_clips.js gableBox — 56 degrees "was NOT
// steep enough - BO3 still let players stand", 72 was. PERCH_SLOPE 3.5 = 74.
//
// THE SLOT: over a prop whose use-trigger sight-traces across its top (the crates
// from the long sides, the inducer from every side — trigger_radius_use traces to
// its origin and a clip brush stops that trace, memory trigger-origin-under-decal),
// the cap starts PERCH_SLOT above the body clip. The trigger origin and a standing
// player's eye line sit in that slot, and no player fits in it (crouch is 48).
//
// DEFERRED: a cap is a REQUEST here and is emitted after every other brush in the
// map (emitPerchCaps, just before the PERCH SEAL pass), because its height is
// limited by whatever stands above it — a flight, a gallery, a lintel — and most of
// those are emitted later in this file. The emitter also PROVES each cap backs onto
// a solid (the wall it buries into) and that no trigger origin ends up inside one.
//
// THE PERCH SEAL (end of file) runs tools/perch_core.js — the same model the build
// gate tools/lint_tod_perches.js runs on the finished .map — and raises every OTHER
// perch it finds (rail caps, trial-hall props, lintels, the hoop recess) out of reach
// or seals it to the brush above. The generator cannot write a map the gate fails.
// ---------------------------------------------------------------------------
const PERCH_SLOPE = 3.5;     // rise per unit run: 74 degrees (map 1: 56 still standable, 72 not)
const PERCH_LIP = 4;         // a short vertical face at the cap's low edge (no knife edge)
const PERCH_BURY = 16;       // the high edge runs this far INTO the backing wall
const PERCH_WALL_SLACK = 4;  // a prop may stand up to this far off its wall (the bury starts from the wall)
const PERCH_SLOT = 20;       // trigger slot between a body clip and its cap (no player fits; crouch is 48)
const PERCH_VENDOR_Z = 80;   // over a script-collided vendor (perk / altar / PaP / uplink): above a standing player
const PERCH_COLUMN_H = 400;  // a free-standing prop (no wall to bury into) gets a column this tall instead
const PERCH_MAT = 'clip_player';
const PERCH_REQ = [];        // deferred requests, emitted by emitPerchCaps()
// back = the unit axis pointing from the prop INTO its wall ([1,0] / [-1,0] / [0,1] / [0,-1]).
// fp = the prop's footprint { x1, x2, y1, y2 } in world units; the cap runs from the
// footprint's FRONT edge to the wall (found by ray, PERCH_WALL_SLACK at most past the
// footprint's back edge unless opts.wallSearch says otherwise) + PERCH_BURY.
//   opts.across  widen the cap this much each side across the prop
//   opts.column  free-standing: a box from zBot to zBot + PERCH_COLUMN_H (no wall)
//   opts.trig    [x, y, z] trigger origins that must stay OUTSIDE the cap
//   opts.wallSearch  how far past the footprint's back edge to look for the wall
function perchCap(label, fp, zBot, back, opts = {}) {
  if (!opts.column && Math.abs(back[0]) + Math.abs(back[1]) !== 1) throw new Error(`perchCap ${label}: back must be a unit axis`);
  if (fp.x1 >= fp.x2 || fp.y1 >= fp.y2) throw new Error(`perchCap ${label}: empty footprint`);
  PERCH_REQ.push({ label, fp: { ...fp }, zBot, back, opts });
}
// EVERY AMMO CRATE: the cap over its body clip, leaning into the wall it backs (the
// crate contract already says every crate backs a wall), PERCH_SLOT above the 58-tall
// body so the trigger (CRATE_TRIG_LIFT 60, on the front face line) keeps its sight
// line from both long sides. cb = the body box in WORLD units; yaw = its world yaw.
function crateCap(label, cb, zFloor, yaw) {
  const f = crateFront(yaw);
  perchCap(`${label} perch cap`, cb, zFloor + CRATE_BOX_H + PERCH_SLOT, [-f[0], -f[1]]);
}
// A SCRIPT-COLLIDED VENDOR (stock zm_collision_perks1 boxes, spawned at runtime, whose
// size this repo cannot measure — a packed stock asset): the cap starts PERCH_VENDOR_Z up,
// above a standing player and below any vending-machine top, and covers the vendor from
// its FRONT line to its wall, `across` either side — wide enough for the three collision
// boxes the altar / PaP rows put +-32 along the wall. Their triggers are 40-56 in front of
// the origin, outside the cap; the perk machine's stock trigger (origin + 60) sits under it.
//   VENDOR_PERK  the BO6/BO7 machines: face 38 in front of the origin (BR_FURN note)
//   VENDOR_PAP   the ALXS cabinet: front 22.2 (its xmodel), 3 clips +-32
//   VENDOR_ALTAR tod_heavenly_altar: front 27.85 (art/heavenly_altar/validation.json), 3 clips +-32
const VENDOR_PERK = { front: 40, across: 40, minHalf: 32 };
const VENDOR_PAP = { front: 26, across: 72, minHalf: 38 };
const VENDOR_ALTAR = { front: 32, across: 72, minHalf: 55 };
const SIDE_BACK = { W: [-1, 0], E: [1, 0], N: [0, 1], S: [0, -1] };
function vendorCap(label, org, zFloor, back, kind) {
  const [bx, by] = back, f = kind.front, a = kind.across;
  // the footprint runs from the front line back to the ORIGIN; the wall is found by ray
  // (perchCap) up to 64 past it — the vendors stand 20-33 off their walls
  const fp = bx !== 0
    ? { x1: Math.min(org[0], org[0] - bx * f), x2: Math.max(org[0], org[0] - bx * f), y1: org[1] - a, y2: org[1] + a }
    : { x1: org[0] - a, x2: org[0] + a, y1: Math.min(org[1], org[1] - by * f), y2: Math.max(org[1], org[1] - by * f) };
  perchCap(`${label} perch cap`, fp, zFloor + PERCH_VENDOR_Z, back, { wallSearch: 64, minHalf: kind.minHalf });
}

// --- STAIR RAMP CLIP emitters (see the constants block for the full note) ---
// These are the map's ONLY non-axis-aligned brushes, and that is deliberate:
// box() stays the sole general-purpose writer, and every tool that parses the
// .map (geometry lint, parity lint, measure_lit_area, audit_hidden_faces,
// preview_crown) either skips or buckets a brush whose planes are not all
// axis-constant — verified per-tool on 2026-08-27, docs/39 §5-G1.
// Plane convention (matches box()): three points per plane, outward normal
// = (P1-P2)x(P3-P2). The slope is ASSERTED equal to RISE/TREAD, which is what
// welds the wedge to the nosing line and both landings by arithmetic.
function rampPlane(p1, p2, p3, tex) {
  const t = `${tex} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  return ` ( ${p1.join(' ')} ) ( ${p2.join(' ')} ) ( ${p3.join(' ')} ) ${t}`;
}
function rampWedge(label, planes, tex) {
  worldBrushes.push({
    label,
    text: ['{', ` guid "${guid()}"`, ...planes.map((p) => rampPlane(p[0], p[1], p[2], tex)), '}'].join('\n'),
  });
}
// A wedge whose top slopes along Y: z = zAtY1 at y1, zAtY2 at y2 (either end
// may be the high one). x1<x2, y1<y2 always — these are bounds, not direction.
// rise/tread default to the tower's stair scale; roadStair passes its own
// (CW_RISE/CW_TREAD) — the assert is what welds the plane to the nosings.
function rampWedgeY(label, x1, x2, y1, y2, zAtY1, zAtY2, tex, rise = RISE, tread = TREAD) {
  if (x1 >= x2 || y1 >= y2) throw new Error(`ramp wedge ${label}: degenerate bounds`);
  if (Math.abs(zAtY2 - zAtY1) * tread !== (y2 - y1) * rise)
    throw new Error(`ramp wedge ${label}: slope must be rise/tread or it misses the nosings`);
  // Navmesh seeds ride the SAME arguments the wedge is built from, so they can
  // never drift from the surface they vouch for. +2z matches the riser-seed
  // convention; the wedge top IS the AI-walkable surface since v16.61a.
  for (let s = 1; s <= RAMP_SEEDS; s++) {
    const t = s / (RAMP_SEEDS + 1);
    navSeed(`${label} ${s}`, (x1 + x2) / 2, y1 + (y2 - y1) * t, zAtY1 + (zAtY2 - zAtY1) * t + 2);
  }
  // RAMP_LIFT: the emitted wedge sits LIFT above the nosing plane the caller
  // described (see the constant). Seeds above were placed off the caller's plane
  // + 2, i.e. exactly on the lifted surface — still inside minDistanceToSeedPoints.
  zAtY1 += RAMP_LIFT; zAtY2 += RAMP_LIFT;
  rampWedge(label, [
    [[x2, y1, zAtY1], [x1, y1, zAtY1], [x1, y2, zAtY2]],                               // top (sloped, up)
    [[x1, y1, zAtY1 - RAMP_T], [x2, y1, zAtY1 - RAMP_T], [x2, y2, zAtY2 - RAMP_T]],    // bottom (sloped, down)
    [[x1, y1, zAtY1], [x2, y1, zAtY1], [x2, y1, zAtY1 - 64]],                          // end -y
    [[x2, y2, zAtY2], [x1, y2, zAtY2], [x1, y2, zAtY2 - 64]],                          // end +y
    [[x1, y1 + 64, zAtY1], [x1, y1, zAtY1], [x1, y1, zAtY1 - 64]],                     // side -x
    [[x2, y1, zAtY1], [x2, y1 + 64, zAtY1], [x2, y1 + 64, zAtY1 - 64]],                // side +x
  ], tex);
}
// The X-sloping mirror: z = zAtX1 at x1, zAtX2 at x2.
function rampWedgeX(label, y1, y2, x1, x2, zAtX1, zAtX2, tex, rise = RISE, tread = TREAD) {
  if (y1 >= y2 || x1 >= x2) throw new Error(`ramp wedge ${label}: degenerate bounds`);
  if (Math.abs(zAtX2 - zAtX1) * tread !== (x2 - x1) * rise)
    throw new Error(`ramp wedge ${label}: slope must be rise/tread or it misses the nosings`);
  // Same as rampWedgeY, with the run on x (note this function is bounded
  // y1,y2 FIRST — the seed must not copy the other one blind).
  for (let s = 1; s <= RAMP_SEEDS; s++) {
    const t = s / (RAMP_SEEDS + 1);
    navSeed(`${label} ${s}`, x1 + (x2 - x1) * t, (y1 + y2) / 2, zAtX1 + (zAtX2 - zAtX1) * t + 2);
  }
  zAtX1 += RAMP_LIFT; zAtX2 += RAMP_LIFT;   // see rampWedgeY
  rampWedge(label, [
    [[x1, y1, zAtX1], [x1, y2, zAtX1], [x2, y2, zAtX2]],                               // top (sloped, up)
    [[x1, y2, zAtX1 - RAMP_T], [x1, y1, zAtX1 - RAMP_T], [x2, y1, zAtX2 - RAMP_T]],    // bottom (sloped, down)
    [[x1, y2, zAtX1], [x1, y1, zAtX1], [x1, y1, zAtX1 - 64]],                          // end -x
    [[x2, y1, zAtX2], [x2, y2, zAtX2], [x2, y2, zAtX2 - 64]],                          // end +x
    [[x1, y1, zAtX1], [x1 + 64, y1, zAtX1], [x1 + 64, y1, zAtX1 - 64]],                // side -y
    [[x1 + 64, y2, zAtX1], [x1, y2, zAtX1], [x1, y2, zAtX1 - 64]],                     // side +y
  ], tex);
}

// ---------------------------------------------------------------------------
// 1. Sky enclosure
// ---------------------------------------------------------------------------
addBox('sky floor', -(SKY_IN + SKY_TH), SKY_IN + SKY_TH, -(SKY_IN + SKY_TH), SKY_IN + SKY_TH, SKY_BOT, SKY_FLOOR, MAT.sky);
addBox('sky top', -(SKY_IN + SKY_TH), SKY_IN + SKY_TH, -(SKY_IN + SKY_TH), SKY_IN + SKY_TH, SKY_TOP, SKY_TOP + SKY_TH, MAT.sky);
addBox('sky wall S', -(SKY_IN + SKY_TH), SKY_IN + SKY_TH, -(SKY_IN + SKY_TH), -SKY_IN, SKY_FLOOR, SKY_TOP, MAT.sky);
addBox('sky wall N', -(SKY_IN + SKY_TH), SKY_IN + SKY_TH, SKY_IN, SKY_IN + SKY_TH, SKY_FLOOR, SKY_TOP, MAT.sky);
addBox('sky wall W', -(SKY_IN + SKY_TH), -SKY_IN, -SKY_IN, SKY_IN, SKY_FLOOR, SKY_TOP, MAT.sky);
addBox('sky wall E', SKY_IN, SKY_IN + SKY_TH, -SKY_IN, SKY_IN, SKY_FLOOR, SKY_TOP, MAT.sky);

// ---------------------------------------------------------------------------
// 2. Base arena: ground + wall + full-height clip
// ---------------------------------------------------------------------------
addBox('ground slab', -(ARENA + WALL), ARENA + WALL, -(ARENA + WALL), ARENA + WALL, -SLAB, 0, MAT.baseFloor);
// ---------------------------------------------------------------------------
// v17.32 — ONE WIDTH, ONE COLOUR, AND THE POWER LANE ACTUALLY REACHES THE POWER
// (user 2026-09-04: "the floor has these strip designs. Can we make that blue
// instead of teal. Its alos not complleted I dont think. Lets redesign this
// strip so it looks cleaner and consistent").
//
// WHAT WAS ACTUALLY INCONSISTENT — measured, not guessed. The base carried
// THREE different line weights for one visual language:
//     perimeter ring    64 wide   (ARENA-84 .. ARENA-20)
//     core foot ring    40 wide
//     wayfinding lane   20 wide
// and the lane ran 16u INSIDE the ring's inner edge for its whole length,
// parallel to it and never touching it. Two lines doing the same job, at
// different weights, that never meet — which is exactly what reads as
// unfinished.
//
// AND IT GENUINELY WAS INCOMPLETE. The power lane — the whole reason these
// exist (Workshop 2026-08-26: "having a difficult time finding the power.
// Where is it?") — stopped at x=580. That is TWENTY UNITS past the doorway,
// into a hallway that runs to x=1640. It pointed at the power room and quit
// before the switch.
//
// NOW: every line in the arena is TRACE_W wide, every line is the same blue,
// and one continuous lane runs spawn -> south -> through the power door ->
// down the hall to the switch.
//
// TWO RULES THAT DECIDED THE COORDINATES, both learned by nearly breaking them:
//
//  1. COPLANAR DECALS MUST ABUT, NEVER OVERLAP. Everything here is 1u at
//     z[0,1]; two of them sharing floor is a z-fight, not a brighter line. The
//     lane therefore STOPS at the perimeter ring's inner edge and RESUMES at its
//     outer edge (the ring carries the crossing), and the door spur stops at
//     y=-266, which is where the lap-1 door gate's own SILL starts — that sill
//     is also a 1u z[0,1] strip in this exact spot.
//  2. NOTHING MAY RUN UNDER A WALL. The power room's north wall is
//     x[280,540] y[-420,-400]; the lane rides y[-460,-420] so its north edge is
//     that wall's south face. The old 20-wide lane at y[-440,-420] cleared it by
//     luck, not by construction.
//
// The TELEPORT BAY's own ring is deliberately NOT widened to TRACE_W: its E/W
// runs sit at x 204..220 and the up-pad squares reach x=198, so 40 wide would
// collide with them. It takes the new blue and keeps its 16u width. That is a
// constraint, not an oversight.
// ---------------------------------------------------------------------------
const TRACE_W = 40;
const RG_O = ARENA - 20, RG_I = RG_O - TRACE_W;   // perimeter ring 480..520

// TRON GRID inlay: a glowing ring 1u proud around the arena perimeter. N and S
// span the full width; W and E fill between them, so the corners mitre and no
// two boxes overlap.
addBox('base inlay N', -RG_O, RG_O, RG_I, RG_O, 0, 1, MAT.baseInlay);
addBox('base inlay S', -RG_O, RG_O, -RG_O, -RG_I, 0, 1, MAT.baseInlay);
addBox('base inlay W', -RG_O, -RG_I, -RG_I, RG_I, 0, 1, MAT.baseInlay);
addBox('base inlay E', RG_I, RG_O, -RG_I, RG_I, 0, 1, MAT.baseInlay);
// v16.11 FACELIFT §3 — BASE PLAZA + WAYFINDING. Players have reported not
// finding the power ("having a difficult time finding the power. Where is
// it?", Workshop 2026-08-26). Three 1u glow traces in the inlay material, the
// same decal trick as the ring: from the spawn band south to the south lane,
// east along the lane straight into the power hallway's mouth (the opening is
// y[-540,-420]; the trace rides its north edge at y[-440,-420], 16u clear of
// the inlay ring's inner edge at -456), and a spur north to the first door
// (its trigger starts at y=-306; the spur stops at -310). Plus a FOOT RING
// 40 wide around the core so the column visibly lands on the floor. NO EAST
// BOX since v16.80: the lap-1 under-stair fill (section 4) is solid from the
// floor across x[256,416], y[-224,256], so the ring's east run would be buried
// inside it; the fill IS the column landing on that side.
// Nothing here is taller than 1u: a step to the lint, a decal to the eye.
if (FACELIFT) {
  const LN_S = -460, LN_N = LN_S + TRACE_W;        // the east lane, y[-460,-420]
  const LN_W = -450, LN_E = LN_W + TRACE_W;        // the spawn lane, x[-450,-410]

  // THE LANE, one continuous path in four pieces: it leaves the perimeter ring
  // beside the spawn, runs south, turns east, crosses under the ring, passes
  // through the power door and ends 20u short of the hall's east wall — at the
  // switch. The two east pieces exist only because rule 1 forbids drawing over
  // the ring; walked, it is one unbroken line.
  addBox('base trace ring spur', -RG_I, LN_W, -TRACE_W / 2, TRACE_W / 2, 0, 1, MAT.baseInlay);
  addBox('base trace spawn', LN_W, LN_E, LN_N, TRACE_W / 2, 0, 1, MAT.baseInlay);
  addBox('base trace east', LN_W, RG_I, LN_S, LN_N, 0, 1, MAT.baseInlay);
  // ...under the ring at x[480,520]...
  addBox('base trace power hall', RG_O, 1600, LN_S, LN_N, 0, 1, MAT.baseInlay);

  // THE DOOR SPUR runs off the foot ring's south-east stub, east to the path
  // edge, stopping at the lap-1 door gate's SILL (y=-266). It CANNOT come off
  // the lane instead: the lane is inside the power room for all x in [280,540],
  // and the only clear channel north out of it is x[256,280] — 24 wide, against
  // the core's east face — so a spur there would be off-width and half-buried.
  addBox('base trace door', CORE + TRACE_W, PX, -306, -266, 0, 1, MAT.baseInlay);

  // THE FOOT RING. Three runs, and the EAST side is open BY CONSTRUCTION, not by
  // omission: the lap-1 under-stair fill is solid from the floor across
  // x[256,416] y[-224,256] (section 4), so an east run would be buried inside it
  // — the staircase IS what lands on that side. The N and S runs deliberately
  // over-run to CORE+TRACE_W so the ring turns its corners and terminates against
  // the stair rather than just stopping in open floor.
  addBox('core foot N', -(CORE + TRACE_W), CORE + TRACE_W, CORE, CORE + TRACE_W, 0, 1, MAT.baseInlay);
  addBox('core foot S', -(CORE + TRACE_W), CORE + TRACE_W, -(CORE + TRACE_W), -CORE, 0, 1, MAT.baseInlay);
  addBox('core foot W', -(CORE + TRACE_W), -CORE, -CORE, CORE, 0, 1, MAT.baseInlay);
}
// SPLIT — the TELEPORT BAY doorway passes through at x[-TPB_DOOR,TPB_DOOR].
// The clip above (base clip S) is deliberately NOT split: it spans z[128,1600]
// and becomes the lintel over the opening, so the doorway is walk-through at
// player height and still un-jumpable.
//
// v16.11 FACELIFT §3 — the five arena walls are emitted by baseWallRun: the
// same blue volume split along its length into runs with a 40-wide CYAN
// PILASTER every 280 units (centres at ±140 and ±420, skipped where a doorway
// or a wall end is within 20u), and a 20-tall cyan CORNICE on top. Flush,
// so nothing intrudes into the arena; the pilasters are the wall's own
// material swapped, not new surface, and the cornice is the only new area.
// The annexes (teleport bay, power hall) keep plain walls.
function baseWallRun(label, x1, x2, y1, y2) {
  if (!FACELIFT) { addBox(label, x1, x2, y1, y2, 0, BASE_WALL_H, MAT.baseWall); return; }
  const alongX = (x2 - x1) > (y2 - y1);
  const a1 = alongX ? x1 : y1, a2 = alongX ? x2 : y2;
  const emit = (l, s1, s2, mat) => (alongX
    ? addBox(l, s1, s2, y1, y2, 0, BASE_WALL_H, mat)
    : addBox(l, x1, x2, s1, s2, 0, BASE_WALL_H, mat));
  const cuts = [];
  for (let c = -420; c <= 420; c += 280) if (c - 20 > a1 && c + 20 < a2) cuts.push(c);
  let cur = a1, k = 0;
  for (const c of cuts) {
    if (c - 20 > cur) emit(`${label} run ${++k}`, cur, c - 20, MAT.baseWall);
    emit(`${label} pilaster ${k}`, c - 20, c + 20, MAT.pilaster);
    cur = c + 20;
  }
  if (a2 > cur) emit(`${label} run ${++k}`, cur, a2, MAT.baseWall);
  addBox(`${label} cornice`, x1, x2, y1, y2, BASE_WALL_H, BASE_WALL_H + 20, MAT.pilaster);
}
baseWallRun('base wall S w', -(ARENA + WALL), -TPB_DOOR, -(ARENA + WALL), -ARENA);
baseWallRun('base wall S e', TPB_DOOR, ARENA + WALL, -(ARENA + WALL), -ARENA);
baseWallRun('base wall N', -(ARENA + WALL), ARENA + WALL, ARENA, ARENA + WALL);
baseWallRun('base wall W', -(ARENA + WALL), -ARENA, -ARENA, ARENA);
// base wall E: SPLIT — the power hallway passes through at y[-540,-420]
// (user 2026-08-20: "hallway needs to be like 5x longer" — it now runs
// outside the arena to x=1640; see the POWER ROOM section).
baseWallRun('base wall E', ARENA, ARENA + WALL, -420, ARENA);
// v18.99g — THE DOORWAY LINTELS. The cornice is emitted per WALL RUN, and the
// south and east walls are SPLIT around their doorways, so the 20-tall cyan band
// that caps every other inch of the arena simply stopped at each opening. That
// left a genuinely open slot above each door — 320 x 20 over the teleport bay,
// 120 x 20 over the power hallway — and because the annex beyond is itself only
// BASE_WALL_H tall and open-topped, what you saw through that slot was SKY. On
// the screenshot that reported the door "reflection bug" it reads as the city
// showing through the top of the door, which is a separate defect from the
// mirror finish fixed in MAT.door, and it is a real hole, not a material.
// Only the visible band is added: the anti-vault clip above these openings
// already runs BASE_WALL_H..BASE_CLIP_TOP, so nothing about collision or the
// 128-unit walk-through clearance changes.
// v19.18c (user 2026-09-16: "remove the top part of the bay door ... because
// it's blocking zombies from launching into the hole"): the SOUTH doorway
// lintel is GONE again, and so is the invisible wall-hop clip over that
// opening — `base clip S` is split around x[-TPB_DOOR, TPB_DOOR] below. From
// the teleport bay the band and the clip together were the bar every bat
// fling hit on its way to the hoop. The 320-wide notch above the bay door is
// open sky by design now; the doorway's own anti-vault clip rides in the door
// slab and still seals it until the door is bought.
addBox('base doorway lintel E', ARENA, ARENA + WALL, -ARENA, -420,
       BASE_WALL_H, BASE_WALL_H + 20, MAT.pilaster);
// BASE_CLIP_TOP (user 2026-08-20 "invisible walls on the platforms"): the
// enlarged breather balconies extend to y/x ±816 — PAST the arena clip planes
// at ±540..560 — so full-height clips cut invisible walls straight across
// every breather. Cap them below the first breather floor (floor 5 mid slab
// bottom = 1712); the clips only need to stop base-arena wall-hops anyway.
const BASE_CLIP_TOP = 1600;
addBox('base clip S w', -(ARENA + WALL), -TPB_DOOR, -(ARENA + WALL), -ARENA, BASE_WALL_H, BASE_CLIP_TOP, MAT.clip);
addBox('base clip S e', TPB_DOOR, ARENA + WALL, -(ARENA + WALL), -ARENA, BASE_WALL_H, BASE_CLIP_TOP, MAT.clip);
addBox('base clip N', -(ARENA + WALL), ARENA + WALL, ARENA, ARENA + WALL, BASE_WALL_H, BASE_CLIP_TOP, MAT.clip);
addBox('base clip W', -(ARENA + WALL), -ARENA, -ARENA, ARENA, BASE_WALL_H, BASE_CLIP_TOP, MAT.clip);
addBox('base clip E', ARENA, ARENA + WALL, -420, ARENA, BASE_WALL_H, BASE_CLIP_TOP, MAT.clip);
// clip ABOVE the hallway pass-through (the wall line stays sealed over z=128)
addBox('power hall doorway clip', ARENA, ARENA + WALL, -ARENA, -420, BASE_WALL_H, BASE_CLIP_TOP, MAT.clip);

// THE BASE AMMO CRATE (v14.3) — core WEST face. This is the single source of
// truth for its position: the collision clip is cut HERE (exactly like the
// five breather/crown crates — the model ships NO collision data) and the
// origin/yaw are emitted into GENERATED _tod_breather_data.gsc
// (base_crate_org/base_crate_yaw), which _tod_ammo_crate.gsc reads — the
// door-data no-drift contract. HISTORY THAT MUST NOT REPEAT: v13.23 placed
// this crate script-side at (320,0,0) — "the emptiest base wall" — which is
// the strip UNDER LAP 1'S EAST FLIGHT (x[256,416], the very strip the
// teleport bay was moved out of, see the TPB note near the top), and its
// three script-clip DisconnectPaths carves severed the stair navmesh both
// ways (Workshop report Pinkbrotha4310 2026-08-30). A wall strip is "empty"
// precisely when a flight runs over it. The asserts below make that mistake
// mechanical: the geometry lint CANNOT see script collision, and now there
// is none — the clip is a real brush the lint and the navmesh compiler both
// understand. FACING AND COLLISION both come from the one crate convention
// above (CRATE_YAW_W / crateBox) — never re-type an occupancy box here.
// v19.71 (2026-10-03, the perch pass): FLUSH against the core, -320 -> -294. The
// box's back edge sat 27 off the core face — a slot a wall-runner dropped into and
// the tester's "push it up against the wall like you have it with quick revive".
// Its back edge is now 1 off the face, and its perch cap buries into the core.
const BASE_CRATE = { org: [-294, 0], yaw: CRATE_YAW_W };
{
  const [bcx, bcy] = BASE_CRATE.org;
  const box = crateBox(bcx, bcy, BASE_CRATE.yaw);   // z 0..CRATE_BOX_H
  // 1. NEVER inside a ground-level flight footprint (+24u margin). The only
  //    flight at base z is lap 1's E flight (odd laps climb E+N): x[CORE,PX],
  //    y[-CORE,CORE], z 0..192 — the Pinkbrotha strip.
  if (box.x2 > CORE - 24 && box.x1 < PX + 24 && box.y2 > -CORE - 24 && box.y1 < CORE + 24)
    throw new Error('base ammo crate box overlaps the lap-1 E flight footprint (the v13.23 navmesh break) — move BASE_CRATE');
  // 2. It must BACK the core's west face (a crate floating mid-arena is a
  //    different design and would need its own review): back edge within 64u
  //    of x=-CORE and not inside the core.
  if (box.x2 > -CORE || box.x2 < -CORE - 64)
    throw new Error('base ammo crate no longer backs the core west face — re-review the placement');
  // 3. The walkway past its front must stay at least a doorway wide (128u)
  //    to the arena W wall inner face, so the clip can never become a choke.
  if (box.x1 - (-ARENA) < 128)
    throw new Error(`base ammo crate leaves only ${box.x1 + ARENA}u of west walkway — needs >= 128`);
  addBox('base ammo crate body', box.x1, box.x2, box.y1, box.y2, 0, CRATE_BOX_H, MAT.clip);
  crateCap('base ammo crate', box, 0, BASE_CRATE.yaw);
}

// THE CYBERCITY SIGN (v19.69, user 2026-10-02: "Add the Tower of Doom Cybercity sign
// part of tower wall where players spawn at"). Nikolai's neon TOWER OF DOOM /
// CYBERCITY sign (`tod_cybercity_sign`, tools/fan_props) hangs on the core's WEST
// face: the tower wall beside the spawn band (SPAWNS above, x -462..-498), lit by
// the spawn's own warm light (SPAWN_BAND_X - 10, 0, 200), centred on the W spine's
// lit line, above the base ammo chest. It is a script_model (_tod_base_sign.gsc), so
// nothing here is geometry: the generator emits its ANCHOR — the sign's back plane,
// horizontal centre, bottom edge — into _tod_breather_data.gsc and asserts where it
// may not go, from the model's measured size (FAN_PROPS.sign).
// v19.71 (2026-10-03, Workshop tester: "as Slasher you can wall run through the Tower of
// Doom:Cyber city map sign might want to move it up just a little"): z1 100 -> 160, and the
// sign gets a body. The model has no collision (a script_model), so a wall-runner on the core
// face ran straight through its 256-wide relief. Now: a player-only clip box over the sign
// (wall-runners stop against it, bullets pass), a perch cap on its top ledge, and the sign
// lifted 60 so the usual wall-run along this face passes under it - and so it reads above
// the base crate's cap instead of sitting on it. Still under lap 2's W flight (assert 2).
const BASE_SIGN = { y: 0, z1: 160, proud: 0.5, yaw: 180 };   // yaw 180: the sign's front (model +X) faces west, at the spawn
{
  const sg = FAN_PROPS.sign;
  if (!sg || sg.model !== 'tod_cybercity_sign') throw new Error('art/fan_props/manifest.json has no tod_cybercity_sign — run tools/fan_props/build_fan_props.py');
  const [d, w, h] = sg.size;                       // x = off the wall, y = across, z = up
  const y1 = BASE_SIGN.y - w / 2, y2 = BASE_SIGN.y + w / 2, z2 = BASE_SIGN.z1 + h;
  // 1. ON the face, 32 clear of both corners (the corners are where the flights turn).
  if (y1 < -CORE + 32 || y2 > CORE - 32) throw new Error(`base sign y[${y1},${y2}] runs off the core west face`);
  // 2. UNDER lap 2's W flight, which climbs over this face from z 384: 64 below the
  //    lowest tread underside anywhere over the sign's span.
  let under = Infinity;
  for (let i = 1; i <= STEPS; i++) {
    const ty1 = CORE - TREAD * i, ty2 = CORE - TREAD * (i - 1);
    if (ty2 > y1 && ty1 < y2) under = Math.min(under, LAP_RISE + RISE * i - SLAB);
  }
  if (z2 > under - 64) throw new Error(`base sign top ${z2} is within 64 of the lap-2 W flight underside (${under})`);
  // 3. ABOVE the base ammo chest standing under it: 32 clear of its box top.
  const cb = crateBox(BASE_CRATE.org[0], BASE_CRATE.org[1], BASE_CRATE.yaw);
  if (cb.y2 > y1 && cb.y1 < y2 && BASE_SIGN.z1 < CRATE_BOX_H + 32) throw new Error(`base sign bottom ${BASE_SIGN.z1} sits within 32 of the base ammo chest (${CRATE_BOX_H})`);
  // 4. Its face stands no further out than the chest's, so nothing at head height
  //    juts past the furniture line of the west walkway.
  if (-CORE - BASE_SIGN.proud - d < cb.x1) throw new Error('base sign stands further off the core than the base ammo chest');
  // 5. (v19.71) THE SIGN'S BODY: a player-only clip box round the relief (1 unit of air
  //    each side, so a wall-runner meets the clip before the mesh), and a perch cap on its
  //    top ledge, leaning into the core.
  const sx1 = Math.floor(-CORE - BASE_SIGN.proud - d - 1);
  addBox('base sign body', sx1, -CORE, Math.floor(y1 - 1), Math.ceil(y2 + 1), BASE_SIGN.z1 - 1, Math.ceil(z2 + 1), PERCH_MAT);
  perchCap('base sign perch cap', { x1: sx1, x2: -CORE, y1: Math.floor(y1 - 1), y2: Math.ceil(y2 + 1) }, Math.ceil(z2 + 1), [1, 0]);
}

// ---------------------------------------------------------------------------
// 3. The core (one palette band per lap; its top IS the rooftop)
// ---------------------------------------------------------------------------
// v16.13 FACELIFT §7 — CORE SPINES. The core was one 512-square box per lap
// with nothing on any face for 19,200 units. Each band is now SPLIT INTO A
// CROSS: a CORE_SPINE_W-wide bar across the middle of each face, full height,
// in the district's PLAIN hue (the parapets' bright material — it reads
// against both the `_tinted` and the `_tinted_edge` bands the treads
// alternate through), and four corner blocks in the band material as before.
// Seven boxes tile the same volume exactly (no overlap, no coplanar overlap —
// adjacent faces on the same plane are side by side), so the surface area
// and the lit area are unchanged, nothing protrudes into a tread, and the
// lint sees the same solid column. Four unbroken lit lines run from the
// base to the crown and change colour at every district. Every flight runs
// along the core, so this is the surface a player looks at most.
const CORE_SPINE_W = 32;

// THE BASE UPGRADE STATION — the HEAVENLY GIFT ALTAR on the core's SOUTH face, facing the
// spawn (v19.71: GENERATED here and emitted as base_station_org/_trig/_yaw into
// _tod_breather_data.gsc; _tod_upgrades.gsc station_spawn read a hand-typed (0,-320) until
// now). Workshop tester, 2026-10-03: "in the main area where the heavenly perk machine is,
// I know it's bumped out a little bit so you could run behind it. I wonder if you just bumped
// that up against the wall ... it would just look a little more clean". It stood 64 off the
// core with its mesh reaching 19 behind its origin: a 45-unit slot behind it, wider than a
// player. Now VENDOR_STANDOFF, its back 1 off the face; the trigger keeps its 40 in front.
const BASE_STATION = { org: [0, -CORE - VENDOR_STANDOFF], trig: [0, -CORE - VENDOR_STANDOFF - 40], yaw: 359.999 };

// THE HOOP (v19.18, user 2026-09-16: "a hole inside the tower where you can
// attempt to launch zombies into the hole for like an extra 20 dollars ...
// above the heavenly altar ... in between the heavenly altar and the top part
// of that staircase"). A RECESS cut into the core's SOUTH face directly above
// the base upgrade station (the HEAVENLY GIFT ALTAR, model (0,-320), 127 tall,
// trigger cylinder topping out at 132) and under the floor-2 south flight
// (lap 2 climbs W+S; its lowest tread over the opening bottoms out at ~644).
// A cyan rim proud of the face frames it and a cyan backboard lights the back,
// so it reads as a target from the arena floor. _tod_corpse_cleanup.gsc scores
// a bat-flung body whose spine passes through the box (TOD_HOOP_PTS).
//
// THE BOX IS EMITTED, NOT COPIED: base_hoop_lo/_hi ride into
// _tod_breather_data.gsc from these constants, the same no-drift contract the
// crate, inducer and station anchors use — the target the player sees IS the
// volume the script tests. The recess stays INSIDE lap 1's band (asserted), so
// only lap 1's three south-face boxes are cut; everything else is untouched.
//
// LINT: the recess floor is the top of a MAT.baseColumn block (plain
// `dark_blue`, BLOCK to lint_tod_geometry at any height) and the rim/backboard
// are MAT.pilaster (plain `cyan`, also BLOCK) — nothing here is a `_tinted`
// DECK, so no detached ledge is invented 240 units up the column.
//
// HEIGHT IS THE ONE UNMEASURED NUMBER. LaunchRagdoll's impulse-to-arc mapping
// is not documented anywhere in this repo, so HOOP_Z1 is a first placement,
// and the script logs every fling's apex and landing ([TOD_HOOP] FLIGHT) so a
// single dev playtest says where the bodies actually go. Move HOOP_Z1 from
// that log, never from a guess; it is a full build either way (geometry).
const HOOP_HALF_W  = 48;    // opening half-width: 96 across — a body fits, a miss is a miss
const HOOP_Z1      = 200;   // opening floor (v19.20, user 2026-09-16 after the first real run: "move the hole a little bit down" - 240 -> 200; 68 above the trigger top, the assert's floor is 196)
const HOOP_H       = 96;    // opening height
const HOOP_DEPTH   = 64;    // recess depth into the core (y -256 -> -192)
const HOOP_RIM     = 12;    // rim bar thickness
const HOOP_RIM_OUT = 16;    // rim proud of the face (y -272 -> -256)
const HOOP_BOARD   = 4;     // lit backboard plate at the back of the recess
const HOOP = { x1: -HOOP_HALF_W, x2: HOOP_HALF_W, y1: -CORE, y2: -CORE + HOOP_DEPTH, z1: HOOP_Z1, z2: HOOP_Z1 + HOOP_H };
{
  const STATION_TOP = 132;                                   // trigger cylinder [32, 132]; mesh 127 (station_place)
  if (HOOP.z1 <= STATION_TOP + 64) throw new Error(`hoop floor ${HOOP.z1} is within 64 of the base station's top (${STATION_TOP})`);
  if (HOOP.z2 + HOOP_RIM > LAP_RISE) throw new Error(`hoop (top ${HOOP.z2 + HOOP_RIM}) leaves lap 1's core band (${LAP_RISE}) — the cut only knows how to split lap 1`);
  // Lowest lap-2 S tread whose x-range overlaps the rim: slab bottom must clear the rim top.
  const mid2 = LAP_RISE + FLIGHT_RISE;
  let under = Infinity;
  for (let i = 1; i <= STEPS; i++) {
    const sx1 = -CORE + TREAD * (i - 1), sx2 = -CORE + TREAD * i;
    if (sx2 > HOOP.x1 - HOOP_RIM && sx1 < HOOP.x2 + HOOP_RIM) under = Math.min(under, mid2 + RISE * i - SLAB);
  }
  if (HOOP.z2 + HOOP_RIM >= under - 64) throw new Error(`hoop rim top ${HOOP.z2 + HOOP_RIM} is within 64 of the floor-2 S flight underside (${under})`);
  if (HOOP_HALF_W + HOOP_RIM > CORE) throw new Error('hoop rim wider than the core face');
}
// Emit `box` minus the axis-aligned `hole` as up to six NON-OVERLAPPING boxes
// (x slabs either side, then y slabs front/back of the remaining column, then
// z slabs below/above). A box the hole misses is emitted whole, same label.
function addBoxMinus(label, x1, x2, y1, y2, z1, z2, mat, h) {
  if (!h || h.x1 >= x2 || h.x2 <= x1 || h.y1 >= y2 || h.y2 <= y1 || h.z1 >= z2 || h.z2 <= z1) { addBox(label, x1, x2, y1, y2, z1, z2, mat); return; }
  const cx1 = Math.max(x1, h.x1), cx2 = Math.min(x2, h.x2);
  const cy1 = Math.max(y1, h.y1), cy2 = Math.min(y2, h.y2);
  const cz1 = Math.max(z1, h.z1), cz2 = Math.min(z2, h.z2);
  if (x1 < cx1) addBox(`${label} W of hoop`, x1, cx1, y1, y2, z1, z2, mat);
  if (cx2 < x2) addBox(`${label} E of hoop`, cx2, x2, y1, y2, z1, z2, mat);
  if (y1 < cy1) addBox(`${label} S of hoop`, cx1, cx2, y1, cy1, z1, z2, mat);
  if (cy2 < y2) addBox(`${label} N of hoop`, cx1, cx2, cy2, y2, z1, z2, mat);
  if (z1 < cz1) addBox(`${label} below hoop`, cx1, cx2, cy1, cy2, z1, cz1, mat);
  if (cz2 < z2) addBox(`${label} above hoop`, cx1, cx2, cy1, cy2, cz2, z2, mat);
}
for (let lap = 0; lap < LAPS; lap++) {
  const z1 = lap * LAP_RISE, z2 = (lap + 1) * LAP_RISE;
  const hole = (lap === 0) ? HOOP : null;   // the hoop recess lives in lap 1's band only (asserted above)
  if (!FACELIFT) { addBoxMinus(`core band lap${lap + 1}`, -CORE, CORE, -CORE, CORE, z1, z2, stepMatOf(lap), hole); continue; }
  // v17.28 — THE COLUMN'S FOOT WEARS THE FLOOR'S GRID (Workshop, Nikolai: "add
  // that black and blue checker to the bottom part of the column of the tower
  // outside where the blue purchasable door is"). The lap-1 and lap-2 door
  // slabs are cut in beside these quadrants, and a FILLED band at brightness 10
  // beside a FILLED door slab at brightness 5 is why the door does not read.
  // Plain here means the wall behind the door is black tiles + a grid line and
  // the door is the only lit fill in the frame. See the BASE_GRID block.
  const h = CORE_SPINE_W / 2, sm = paraMatOf(lap);
  const bm = (BASE_GRID && lap < BASE_GRID_LAPS) ? MAT.baseColumn : stepMatOf(lap);
  // The three boxes that own the SOUTH face take the hoop recess on lap 1 (a
  // no-op `hole` everywhere else — addBoxMinus emits the box whole).
  addBoxMinus(`core band lap${lap + 1} spine NS`, -h, h, -CORE, CORE, z1, z2, sm, hole);   // the N and S face bars
  addBox(`core band lap${lap + 1} spine W`, -CORE, -h, -h, h, z1, z2, sm);      // the W face bar
  addBox(`core band lap${lap + 1} spine E`, h, CORE, -h, h, z1, z2, sm);        // the E face bar
  addBox(`core band lap${lap + 1} NW`, -CORE, -h, h, CORE, z1, z2, bm);
  addBox(`core band lap${lap + 1} NE`, h, CORE, h, CORE, z1, z2, bm);
  addBoxMinus(`core band lap${lap + 1} SW`, -CORE, -h, -CORE, -h, z1, z2, bm, hole);
  addBoxMinus(`core band lap${lap + 1} SE`, h, CORE, -CORE, -h, z1, z2, bm, hole);
}
// THE HOOP'S RIM AND BACKBOARD (see the HOOP block above the loop): four cyan
// bars proud of the south face framing the opening, and a cyan plate at the
// back of the recess (its rear face is buried against the recess back wall, so
// nothing z-fights). Labels start with `core` so measure_lit_area groups them
// with the column. Plain-hue material = BLOCK to the lint at any height.
{
  const rx1 = HOOP.x1 - HOOP_RIM, rx2 = HOOP.x2 + HOOP_RIM, ry1 = -CORE - HOOP_RIM_OUT, ry2 = -CORE;
  addBox('core hoop rim bottom', rx1, rx2, ry1, ry2, HOOP.z1 - HOOP_RIM, HOOP.z1, MAT.pilaster);
  addBox('core hoop rim top',    rx1, rx2, ry1, ry2, HOOP.z2, HOOP.z2 + HOOP_RIM, MAT.pilaster);
  addBox('core hoop rim W',      rx1, HOOP.x1, ry1, ry2, HOOP.z1, HOOP.z2, MAT.pilaster);
  addBox('core hoop rim E',      HOOP.x2, rx2, ry1, ry2, HOOP.z1, HOOP.z2, MAT.pilaster);
  addBox('core hoop backboard',  HOOP.x1, HOOP.x2, HOOP.y2 - HOOP_BOARD, HOOP.y2, HOOP.z1, HOOP.z2, MAT.pilaster);
}
// THE CAPITAL: one more core band carrying the column from the spiral's top
// (TOP) up to the crown deck (TOP2). Its top face IS the middle of the plaza,
// and its east face is the crown stair's inner wall. In the PaP material, so
// the last 192 units of the tower read as the prize from the street.
// (The old z=TOP roof overlay + 4 parapets are GONE — they would now be buried
// inside this band, and the crown deck replaces them wholesale.)
addBox('core capital band', -CORE, CORE, -CORE, CORE, TOP, TOP2, MAT.crownBand);

// ---------------------------------------------------------------------------
// 4. The spiral: flights + landings + parapets, per lap (CCW: E N W S)
// ---------------------------------------------------------------------------
function slabZ(top) { return [top - SLAB, top]; }

// v6 (user 2026-08-20): TWO flights per floor (was four) — each lap = HALF a
// revolution (LAP_RISE 384), floors come twice as fast. Odd floors (1-based)
// climb the EAST+NORTH sides, even floors WEST+SOUTH; the spiral stays
// continuous CCW: E->NE->N->NW | W->SW->S->SE. Breathers ride each floor's
// MID landing (odd: NE balcony N+E; even: SW balcony S+W, mirrored).
for (let lap = 0; lap < LAPS; lap++) {
  const b = lap * LAP_RISE;
  const stepMat = stepMatOf(lap), paraMat = paraMatOf(lap);
  const odd = (lap % 2 === 0);   // 1-based odd floor
  const mid = b + FLIGHT_RISE, end = b + LAP_RISE;

  if (odd) {
    // E flight (x[CORE,PX], y -CORE -> +CORE)
    for (let i = 1; i <= STEPS; i++) {
      const [z1, z2] = slabZ(b + RISE * i);
      addBoxFaces(`lap${lap + 1} E step ${i}`, CORE, PX, -CORE + TREAD * (i - 1), -CORE + TREAD * i, z1, z2, stepMat, treadFaces('s', 'n', 'e', riserMatOf(lap), soffitMatOf(lap)));   // v19.69 refresh: climbs +y
    }
    // v16.80 (Workshop: Nikolai 2026-09-03, Pinkbrotha4310 08-30) — THE VOID
    // UNDER THE FIRST FLIGHT WAS A SAFE ROOM. Lap 1's E flight is the only
    // flight whose underside meets a walkable floor (the arena): the pocket
    // opens under the NE landing with 176 of clearance and loses RISE per
    // tread toward the door (~8 at tread 2). The zombie navmesh stops part-way
    // in, a crouched or prone player fits further, and stock find-flesh just
    // SetGoals the player origin — no reachable mesh point, so every zombie
    // and every boss stood still. Filled with VISIBLE stepped solids, one per
    // tread (top = that tread's slab bottom; tread 1's is below the floor),
    // in the arena wall material so it reads as the stair's own underside on
    // sight. Every internal face is buried by construction (fill i's north
    // face by fill i+1 and tread i's slab; west by the core, east by the
    // anti-bypass wall, bottom by the ground slab), so the only lit face is
    // the 160x176 wall closing the mouth under the NE landing. NOT a clip:
    // an invisible fill repeats the v10.3 "invisible barrier under the
    // stairs" report and trips the lint's misplaced-wall rule. The spire's
    // lap 1 (section 6c) carries the identical fill.
    if (lap === 0) {
      for (let i = 2; i <= STEPS; i++)
        addBox(`lap1 E under-stair fill ${i}`, CORE, PX, -CORE + TREAD * (i - 1), -CORE + TREAD * i, b, b + RISE * i - SLAB, MAT.baseWall);
    }
    addBoxFaces(`lap${lap + 1} NE landing`, CORE, PX, CORE, PX, ...slabZ(mid), edgeMatOf(lap), landingFaces(['e', 'n'], soffitMatOf(lap)));
    // N flight (y[CORE,PX], x CORE -> -CORE)
    for (let i = 1; i <= STEPS; i++) {
      const [z1, z2] = slabZ(mid + RISE * i);
      addBoxFaces(`lap${lap + 1} N step ${i}`, CORE - TREAD * i, CORE - TREAD * (i - 1), CORE, PX, z1, z2, stepMat, treadFaces('e', 'w', 'n', riserMatOf(lap), soffitMatOf(lap)));   // v19.69 refresh: climbs -x
    }
    // v9: the old odd-only "final NW landing (roof arrival)" special case is
    // GONE. It only fired when LAPS was odd, so v8's LAPS=50 built no arrival
    // at all — the roof was unreachable. EVERY lap now ends on its normal
    // landing, and the CROWN section below grows the final flight off whichever
    // landing the parity actually produced.
    addBoxFaces(`lap${lap + 1} NW landing`, -PX, -CORE, CORE, PX, ...slabZ(end), edgeMatOf(lap + 1), landingFaces(['w', 'n'], soffitMatOf(lap + 1)));
    if (STAIR_RAMP_CLIP) {
      // E flight: nosing line from (y=-CORE-TREAD, z=b) to (y=CORE-TREAD, z=b+192).
      // The low TREAD units feather over the approach floor (SE landing / the
      // arena at lap 1, slab z[b-16,b] — the underside stays buried); the high
      // end face sits exactly in step 16's slab z[b+176,b+192].
      rampWedgeY(`lap${lap + 1} E stair ramp`, CORE, PX, -CORE - TREAD, CORE - TREAD, b, b + FLIGHT_RISE, MAT.rampClip);
      // N flight: mirrored form, sloping down toward +x into the NE landing.
      rampWedgeX(`lap${lap + 1} N stair ramp`, CORE, PX, -CORE + TREAD, CORE + TREAD, mid + FLIGHT_RISE, mid, MAT.rampClip);
    }
  } else {
    // W flight (x[-PX,-CORE], y CORE -> -CORE)
    for (let i = 1; i <= STEPS; i++) {
      const [z1, z2] = slabZ(b + RISE * i);
      addBoxFaces(`lap${lap + 1} W step ${i}`, -PX, -CORE, CORE - TREAD * i, CORE - TREAD * (i - 1), z1, z2, stepMat, treadFaces('n', 's', 'w', riserMatOf(lap), soffitMatOf(lap)));   // v19.69 refresh: climbs -y
    }
    addBoxFaces(`lap${lap + 1} SW landing`, -PX, -CORE, -PX, -CORE, ...slabZ(mid), edgeMatOf(lap), landingFaces(['w', 's'], soffitMatOf(lap)));
    // S flight (y[-PX,-CORE], x -CORE -> +CORE)
    for (let i = 1; i <= STEPS; i++) {
      const [z1, z2] = slabZ(mid + RISE * i);
      addBoxFaces(`lap${lap + 1} S step ${i}`, -CORE + TREAD * (i - 1), -CORE + TREAD * i, -PX, -CORE, z1, z2, stepMat, treadFaces('w', 'e', 's', riserMatOf(lap), soffitMatOf(lap)));   // v19.69 refresh: climbs +x
    }
    addBoxFaces(`lap${lap + 1} SE landing`, CORE, PX, -PX, -CORE, ...slabZ(end), edgeMatOf(lap + 1), landingFaces(['e', 's'], soffitMatOf(lap + 1)));
    if (STAIR_RAMP_CLIP) {
      // Point mirrors of the odd lap's pair (x,y -> -x,-y), same welds.
      rampWedgeY(`lap${lap + 1} W stair ramp`, -PX, -CORE, -CORE + TREAD, CORE + TREAD, b + FLIGHT_RISE, b, MAT.rampClip);
      rampWedgeX(`lap${lap + 1} S stair ramp`, -PX, -CORE, -CORE - TREAD, CORE - TREAD, mid, mid + FLIGHT_RISE, MAT.rampClip);
    }
  }

  // BREATHER LOUNGE (v13) on the floor's MID landing — an enclosed themed room
  // (roof + walls + windows) with the teleporter on an open-air spur. Authored
  // ONCE in the ODD frame (balcony extends N+E off the NE landing); bb()
  // mirrors every box for the even/SW parity all four shipped breathers use.
  // The old deck's parapet bands ARE the new wall bands, so the room footprint
  // is unchanged; only the spur extends it. Design record: the v13 block at
  // BREATHER_THEME. Wall anatomy (z above mid): 0-56 sill (the old rail),
  // 56-192 window band (mullions + clip_player voids — players stay in,
  // bullets pass), 192-288 lintel, 288-360 roof, 360-368 glowing trim ring.
  if (BREATHER_LAPS.has(lap + 1)) {
    const T = BREATHER_THEME[lap + 1];
    const mFloor = `mwiii_vertigo_retro_synth_${T.key}_tinted_edge`;
    const mGlow  = `mwiii_vertigo_retro_synth_${T.key}`;               // sill / mullions / gate / trim
    const mPanel = `mwiii_vertigo_retro_synth_${T.key}_tinted`;        // lintel band + pier (softer)
    const mBoard = mFloor;   // v16.7 fixture panels: the floor's edge-lit grid stood up behind each machine
    const bb = (label, x1, x2, y1, y2, z1, z2, mat) => odd
      ? addBox(`lap${lap + 1} breather ${label}`, x1, x2, y1, y2, z1, z2, mat)
      : addBox(`lap${lap + 1} breather ${label}`, -x2, -x1, -y2, -y1, z1, z2, mat);
    // Wall band lines (odd frame): outer N y[992,1012], E x[800,820],
    // W x[236,256], inner S y[396,416] with the 160 entrance at x[256,416].
    const NB1 = PX + BR_DEPTH, NB2 = NB1 + PARA;          // 992,1012
    const EB1 = PX + BR_EAST,  EB2 = EB1 + PARA;          // 800,820
    const WB1 = CORE - PARA,   WB2 = CORE;                // 236,256
    const SB1 = PX - PARA,     SB2 = PX;                  // 396,416
    const zSill = [mid, mid + BR_SILL_H];
    const zWin  = [mid + BR_SILL_H, mid + BR_WIN_TOP];
    const zLin  = [mid + BR_WIN_TOP, mid + BR_WALL_H];


    bb('floor', CORE, EB1, PX, NB1, ...slabZ(mid), mFloor);

    // OUTER WALL (N) — carries the spur doorway at x[624,784]. East of it the
    // wall is a full-height solid pier (36 wide: too narrow for a window, and
    // the gate's east post lands against it).
    bb('wall N sill', WB1, SPUR_CX - SPUR_W, NB1, NB2, ...zSill, mGlow);
    // v16.7: the PERK WALL's whole window band is one solid panel of the theme
    // grid (mBoard), W corner to spur doorway — the bar back behind the two
    // machines. It REPLACES the v13 mullion + clip_player void on this wall (a
    // solid needs no player-clip); the other three walls keep their windows
    // and each gives up one bay, below.
    if (BR_POLISH && BR_WIN_PANELS) {
      bb('wall N perk panel', WB1, SPUR_CX - SPUR_W, NB1, NB2, ...zWin, mBoard);
    } else {   // pre-v16.7 (and v16.57 with BR_WIN_PANELS off): a mullion + the clip_player window void
      bb('wall N mull', 416, 444, NB1, NB2, ...zWin, mGlow);
      bb('wall N win', WB1, SPUR_CX - SPUR_W, NB1, NB2, ...zWin, MAT.winClip);
    }
    bb('wall N lintel', WB1, SPUR_CX + SPUR_W, NB1, NB2, ...zLin, mPanel);
    bb('wall N pier', SPUR_CX + SPUR_W, EB2, NB1, NB2, mid, mid + BR_WALL_H, mPanel);
    // SIDE WALLS (E long / W long) — the city-view walls: sill, two mullions
    // at the third points, the window clip, the lintel. The E wall starts at
    // y=396 and owns the SE corner cube; the W wall starts at y=436 because
    // y[416,436] in its band belongs to the lap's own N-flight parapet
    // (emitting both would coplanar-fight two materials on the x=256 plane).
    for (const [tag, x1, x2, y1] of [['E', EB1, EB2, SB1], ['W', WB1, WB2, SB2 + PARA]]) {
      bb(`wall ${tag} sill`, x1, x2, y1, NB1, ...zSill, mGlow);
      bb(`wall ${tag} mull a`, x1, x2, 594, 622, ...zWin, mGlow);
      bb(`wall ${tag} mull b`, x1, x2, 786, 814, ...zWin, mGlow);
      bb(`wall ${tag} win`, x1, x2, y1, NB1, ...zWin, MAT.winClip);
      bb(`wall ${tag} lintel`, x1, x2, y1, NB1, ...zLin, mPanel);
    }
    // v16.7 FIXTURE PANELS on the long walls: the middle bay between the two
    // mullions goes solid behind the machine that owns that wall — the PaP on
    // the E wall (odd frame; even -744,-704) and the ammo crate on the W wall
    // (even -310,-700). Both machines sit within 4u of the bay's axis (the PaP
    // was nudged 24u for exactly this — BR_FURN). A solid inside the window
    // clip is the same overlap the mullions already live in.
    const BAY1 = 594 + BR_MULL_W, BAY2 = 786;   // y[622,786], the middle bay
    if (BR_POLISH && BR_WIN_PANELS) {
      bb('wall E pap panel', EB1, EB2, BAY1, BAY2, ...zWin, mBoard);
      bb('wall W crate panel', WB1, WB2, BAY1, BAY2, ...zWin, mBoard);
    }
    // INNER WALL (S) — the entrance side. The wall proper runs x[436,800]
    // (x[416,436] is the NE landing's own parapet, breather variant); the old
    // landing gap x[256,416] is now a real 192-tall doorway — the lintel
    // reaches west over it and becomes the door header.
    bb('wall S sill', SB2 + PARA, EB1, SB1, SB2, ...zSill, mGlow);
    bb('wall S mull', 604, 632, SB1, SB2, ...zWin, mGlow);
    bb('wall S win', SB2 + PARA, EB1, SB1, SB2, ...zWin, MAT.winClip);
    // v16.7: the STATION's panel — the bay west of the mullion, x[436,604],
    // butting the mullion; its axis is x=520 (even -520), where BR_FURN now
    // parks the station. The east bay stays a window onto the flight.
    if (BR_POLISH && BR_WIN_PANELS) bb('wall S station panel', SB2 + PARA, 604, SB1, SB2, ...zWin, mBoard);
    bb('wall S lintel', WB2, EB1, SB1, SB2, ...zLin, mPanel);
    // THE DOORWAY CORNER PIER (v13.1, user live report 2026-08-28: "the roof
    // panels dont connect on one corner for all breather zones"). The W wall
    // starts at y=436 (the y[416,436] band belongs to the lap's own N-flight
    // parapet) and the S lintel starts at x=256 — which left the corner column
    // x[236,256] y[396,436] EMPTY from rail height to the roof at +288: the
    // roof corner floated over an L-shaped hole beside the entrance (the
    // flight's rail cap made it collision-tight, so it was purely visible).
    // Two flush brushes, no overlaps: the base stands on the N-flight's
    // FIRST TREAD (top mid+12; it narrows that one tread by 20u at its far
    // corner — cosmetically a doorjamb, the flight is 160 wide); the upper
    // pier sits exactly on the base AND the flight para (both top out at
    // mid+80) and carries the roof corner. It doubles as the doorway's east
    // jamb in the even frame, matching the spur gate's post language.
    bb('corner pier base', WB1, WB2, SB1, SB2, mid + RISE, mid + 80, mGlow);
    bb('corner pier', WB1, WB2, SB1, SB2 + PARA, mid + 80, mid + BR_WALL_H, mGlow);
    // ROOF: REMOVED v13.6 (user 2026-08-29: "The roof on the breathers I think
    // look better when open. You cant look up and see the tower so it kinda
    // makes it worse. Lets remove that"). The lounges are OPEN-TOP rooms now —
    // walls, sills, windows and lintels stand as before; standing inside you
    // look straight up the tower's flank. Gone with the slab: the trim ring
    // (it sat ON the roof) and the v13.1 ceiling halo (it hung UNDER it). The
    // v13.1 corner pier STAYS — it is the doorway's east jamb first and a roof
    // carrier second, and as a free-standing glow post it still frames the
    // entrance. A glowing TOP-EDGE band on the wall heads replaces the trim
    // ring's night-read silhouette (same mGlow, 8 tall, sits on the lintels —
    // the open room still draws its theme-colour outline against the tower).
    const zCap = [mid + BR_WALL_H, mid + BR_WALL_H + 8];
    bb('wall cap N', WB1, EB2, NB1, NB2, ...zCap, mGlow);
    bb('wall cap S', WB1, EB2, SB1, SB2, ...zCap, mGlow);
    bb('wall cap W', WB1, WB2, SB2, NB1, ...zCap, mGlow);
    bb('wall cap E', EB1, EB2, SB2, NB1, ...zCap, mGlow);
    // v16.7 FINIALS — one glow post per room corner standing on the cap band,
    // 8 proud of the 20 wall band on every side (a capital, not a spike: 36u
    // clears the 384u legibility floor from the flight above). The SW one
    // crowns the v13.1 doorway pier. Overhangs float over void or cap only.
    const fp = BR_FIN_W / 2, zFin = [zCap[1], zCap[1] + BR_FIN_H];
    if (BR_POLISH) for (const [tag, cx, cy] of [['NW', WB1 + PARA / 2, NB1 + PARA / 2], ['NE', EB1 + PARA / 2, NB1 + PARA / 2],
                                 ['SE', EB1 + PARA / 2, SB1 + PARA / 2], ['SW', WB1 + PARA / 2, SB1 + PARA / 2]])
      bb(`finial ${tag}`, cx - fp, cx + fp, cy - fp, cy + fp, ...zFin, mGlow);

     // existing rooms on floors 20/30/40

    // THE SPUR — gantry + pad platform, open-air. Rails ride the 20-unit band
    // OUTSIDE the walk surface exactly like every other rail on this map, and
    // every rail top is capped (RAIL_CAP_H). The gate: two 240-tall posts
    // where the neck rails meet the wall, lintel spanning the walkway between
    // them at door height.
    bb('spur neck floor', SPUR_CX - SPUR_W, SPUR_CX + SPUR_W, NB1, SPUR_Y1, ...slabZ(mid), mFloor);
    bb('spur gate post w', SPUR_CX - SPUR_W - PARA, SPUR_CX - SPUR_W, NB2, NB2 + 48, mid, mid + 240, mGlow);
    bb('spur gate post e', SPUR_CX + SPUR_W, SPUR_CX + SPUR_W + PARA, NB2, NB2 + 48, mid, mid + 240, mGlow);
    bb('spur gate lintel', SPUR_CX - SPUR_W, SPUR_CX + SPUR_W, NB2, NB2 + 48, mid + BR_WIN_TOP, mid + 240, mGlow);
    for (const [tag, rx1, rx2] of [['w', SPUR_CX - SPUR_W - PARA, SPUR_CX - SPUR_W], ['e', SPUR_CX + SPUR_W, SPUR_CX + SPUR_W + PARA]]) {
      bb(`spur neck rail ${tag}`, rx1, rx2, NB2 + 48, SPUR_Y1 - PARA, mid, mid + PARA_H, mGlow);
      bb(`spur neck cap ${tag}`, rx1, rx2, NB2 + 48, SPUR_Y1 - PARA, mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
    }
    const PL1 = SPUR_CX - 144, PL2 = SPUR_CX + 144;   // platform x[560,848]
    bb('spur platform', PL1, PL2, SPUR_Y1, SPUR_Y2, ...slabZ(mid), mFloor);
    const PRAILS = [
      ['w', PL1 - PARA, PL1, SPUR_Y1 - PARA, SPUR_Y2 + PARA],
      ['e', PL2, PL2 + PARA, SPUR_Y1 - PARA, SPUR_Y2 + PARA],
      ['n', PL1, PL2, SPUR_Y2, SPUR_Y2 + PARA],
      ['s w', PL1, SPUR_CX - SPUR_W, SPUR_Y1 - PARA, SPUR_Y1],
      ['s e', SPUR_CX + SPUR_W, PL2, SPUR_Y1 - PARA, SPUR_Y1],
    ];
    for (const [tag, rx1, rx2, ry1, ry2] of PRAILS) {
      bb(`spur plat rail ${tag}`, rx1, rx2, ry1, ry2, mid, mid + PARA_H, mGlow);
      bb(`spur plat cap ${tag}`, rx1, rx2, ry1, ry2, mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
    }
    // PAD RING (v13.1 polish): a 1-proud glowing theme ring inlaid in the
    // platform around the porter — the base arena's inlay construct, so the
    // pad reads as a landing pad from the whole tower. Inner edge 100u from
    // the pad centre: clear of the ~83u-half assembly, walk-over (1 unit).
    const PR1 = PL1 + 24, PR2 = PL2 - 24, PRY1 = SPUR_Y1 + 24, PRY2 = SPUR_Y2 - 24, PRW = 20;
    bb('spur pad ring s', PR1, PR2, PRY1, PRY1 + PRW, mid, mid + 1, mGlow);
    bb('spur pad ring n', PR1, PR2, PRY2 - PRW, PRY2, mid, mid + 1, mGlow);
    bb('spur pad ring w', PR1, PR1 + PRW, PRY1 + PRW, PRY2 - PRW, mid, mid + 1, mGlow);
    bb('spur pad ring e', PR2 - PRW, PR2, PRY1 + PRW, PRY2 - PRW, mid, mid + 1, mGlow);

    if (BR_POLISH) {   // ---- room polish on all breather floors ----
    // v16.7 FLOOR INLAY — the base arena's inlay construct on the room floor:
    // a 1-proud glow ring at the room centre and a spoke to each amenity (S to
    // the station, E to the PaP, W to the crate, N to the perk wall with a
    // crossbar spanning both pads). 1u is walk-over (the pad ring precedent)
    // and a 1u step to the geometry lint, never a wall. Spoke ends are the
    // machines' FEET, taken from BR_FURN (odd frame = -even): the station's
    // base reaches ~40u out from its origin, the PaP's ~44u, the crate's clip
    // face is org+38, the perk pads are at y=970 with the bar 20u short.
    const RCX = (CORE + EB1) / 2, RCY = (PX + NB1) / 2;      // 528, 704
    const R1 = BR_RING_R - BR_INLAY_W, R2 = BR_RING_R;        // 100 .. 120
    const hw = BR_INLAY_W / 2, zIn = [mid, mid + 1];
    const oPap = [-BR_FURN.pap.org[0], -BR_FURN.pap.org[1]];
    const oSta = [-BR_FURN.station.org[0], -BR_FURN.station.org[1]];
    const oCra = [-BR_FURN.crate.org[0], -BR_FURN.crate.org[1]];
    const oPkE = -BR_FURN.perk_e.trig[0], oPkW = -BR_FURN.perk_w.trig[0], oPkY = -BR_FURN.perk_e.trig[1];
    bb('inlay ring s', RCX - R2, RCX + R2, RCY - R2, RCY - R1, ...zIn, mGlow);
    bb('inlay ring n', RCX - R2, RCX + R2, RCY + R1, RCY + R2, ...zIn, mGlow);
    bb('inlay ring w', RCX - R2, RCX - R1, RCY - R1, RCY + R1, ...zIn, mGlow);
    bb('inlay ring e', RCX + R1, RCX + R2, RCY - R1, RCY + R1, ...zIn, mGlow);
    bb('inlay spoke s', oSta[0] - hw, oSta[0] + hw, oSta[1] + 40, RCY - R2, ...zIn, mGlow);
    bb('inlay spoke e', RCX + R2, oPap[0] - 44, oPap[1] - hw, oPap[1] + hw, ...zIn, mGlow);
    bb('inlay spoke w', oCra[0] + 38, RCX - R2, oCra[1] - hw, oCra[1] + hw, ...zIn, mGlow);
    bb('inlay spoke n', RCX - hw, RCX + hw, RCY + R2, oPkY - 40, ...zIn, mGlow);
    bb('inlay perk bar', oPkE - 10, oPkW + 10, oPkY - 40, oPkY - 40 + BR_INLAY_W, ...zIn, mGlow);

    // v16.7 PAD PYLONS — four glow posts CENTRED ON the platform's rail-band
    // corners (half over the band's corner, half hanging off it: an attached
    // post, not a floating one). They never reach the floor (x/y stop at the
    // band's inner face), so no walkable column changes and no cap is needed:
    // the 168u rail+cap stands between a player and every post.
    const zPy = [mid - SLAB, mid + BR_PYLON_H], pp = BR_PYLON_W / 2;
    for (const [tag, cx, cy] of [['sw', PL1 - PARA, SPUR_Y1 - PARA], ['se', PL2 + PARA, SPUR_Y1 - PARA],
                                 ['nw', PL1 - PARA, SPUR_Y2 + PARA], ['ne', PL2 + PARA, SPUR_Y2 + PARA]])
      bb(`spur pylon ${tag}`, cx - pp, cx + pp, cy - pp, cy + pp, ...zPy, mGlow);

    // v16.7 GANTRY HOOPS — door-height frames over the walkway along the neck:
    // posts hanging OUTSIDE the rail bands (slab bottom up to door height), a
    // lintel spanning post-to-post in the gate's own BR_WIN_TOP..240 band and
    // sitting ON the posts (no coplanar tops). Nothing enters the walkway, the
    // rail bands or the cap band; the lintel is 192 over the deck, and the
    // second hoop stops 64u short of the up-teleport arrival (y=1296).
    const neckY0 = NB2 + 48;
    for (let k = 1; k <= BR_HOOP_N; k++) {
      const hy = neckY0 + 72 + (k - 1) * 80;   // 1132, 1212 — the neck's third points, on the grid
      const hx1 = SPUR_CX - SPUR_W - 2 * PARA, hx2 = SPUR_CX + SPUR_W + 2 * PARA;   // 584 .. 824
      bb(`spur hoop ${k} post w`, hx1, hx1 + PARA, hy, hy + PARA, mid - SLAB, mid + BR_WIN_TOP, mGlow);
      bb(`spur hoop ${k} post e`, hx2 - PARA, hx2, hy, hy + PARA, mid - SLAB, mid + BR_WIN_TOP, mGlow);
      bb(`spur hoop ${k} lintel`, hx1, hx2, hy, hy + PARA, mid + BR_WIN_TOP, mid + 240, mGlow);
    }

    // v16.7 UNDERSIDE — the walls start at z=mid and the floor slab stops at
    // the wall line, so every sill floated over a slab-thick void: from the
    // flights below and from the base the lounge's outline was a gap. Fill it
    // with glow under all four bands (the S band only where it overhangs the
    // void — x<436 is the landing and the flight's own parapet), hang a
    // stepped pendant under the E, W and N midpoints, and a thruster cube
    // under the pad platform. All plain glow = BLOCK to the lint, nothing
    // standable, nothing in any walkable column.
    const zUn = [mid - SLAB, mid];
    bb('under band N', WB1, EB2, NB1, NB2, ...zUn, mGlow);
    bb('under band E', EB1, EB2, SB1, NB1, ...zUn, mGlow);
    bb('under band W', WB1, WB2, SB2 + PARA, NB1, ...zUn, mGlow);
    bb('under band S', SB2 + PARA, EB1, SB1, SB2, ...zUn, mGlow);
    let pz = mid - SLAB;
    BR_PEND.forEach(([ph, pt], i) => {
      bb(`pendant E ${i + 1}`, EB1, EB2, RCY - ph, RCY + ph, pz - pt, pz, mGlow);
      bb(`pendant W ${i + 1}`, WB1, WB2, RCY - ph, RCY + ph, pz - pt, pz, mGlow);
      bb(`pendant N ${i + 1}`, RCX - ph, RCX + ph, NB1, NB2, pz - pt, pz, mGlow);
      pz -= pt;
    });
    bb('spur pad thruster', SPUR_CX - 24, SPUR_CX + 24, SPUR_PAD_Y - 24, SPUR_PAD_Y + 24, mid - SLAB - 64, mid - SLAB, mGlow);
    }   // ---- end BR_POLISH ----

    // AMMO CRATE COLLISION — the crate model ships NO collision (CollisionMap
    // "" / BulletCollisionFile ""), so the .map carries a clip brush inside
    // the mesh; lint_tod_geometry knows it via MODEL_CLIP_COLUMNS (the label
    // MUST end "ammo crate body"). Bounds are the measured yaw-270 occupancy
    // of zeroy_s4_ammo_crate at SetScale 2.5 around the crate origin — which
    // now COMES FROM BR_FURN, the same table _tod_ammo_crate.gsc reads via
    // generated _tod_breather_data.gsc, so clip and model can never drift.
    // Even/mirrored frame only, which is every breather (asserted at
    // BREATHER_THEME). Full history: git log this label.
    if (!odd) {
      const [ccx, ccy] = BR_FURN.crate.org;
      const cb = crateBox(ccx, ccy, BR_FURN.crate.yaw);
      addBox(`lap${lap + 1} ammo crate body`, cb.x1, cb.x2, cb.y1, cb.y2, mid, mid + CRATE_BOX_H, MAT.clip);
      crateCap(`lap${lap + 1} ammo crate`, cb, mid, BR_FURN.crate.yaw);
    }
  }

  // PARAPETS (outer edges + landing corners, per parity)
  if (odd) {
    if (lap === 0) {
      // THE FIRST FLIGHT'S OUTER WALL — a 288-tall slab (not a 56 parapet) so
      // nobody hops onto the stairs from the east gutter past the first door.
      // MATERIAL = the arena WALL material (v9.34, user 2026-08-23: "an
      // invisible wall attached to the stairs near that tight hallway"): the
      // lap-palette neon-edge material it used to wear reads as a faint glow
      // at night, so players walked into an unlit 288-unit barrier they could
      // not see. Same blue as the base walls = reads as a wall on sight.
      addBox('lap1 E parapet (anti-bypass wall)', PX, PX + PARA, -CORE + (doorPostAt(1) ? DOOR_POST_NOTCH : 0), CORE, 0, 288, MAT.baseWall);   // the lap-1 gate post takes the first 10
    } else {
      for (let j = 1; j <= STEPS / PARA_EVERY; j++) {
        const top = b + RISE * PARA_EVERY * j;
        // z1 is top - RISE*(PARA_EVERY-1), NOT top (fixed 2026-08-27, docs/39 §4#7):
        // a parapet box spans PARA_EVERY treads but used to start at the HIGHER
        // tread's top, leaving a 12-tall see-through slot to the void under the
        // rail over every lower tread — ~800 map-wide. The box now drops to the
        // lowest tread it guards. Top face unchanged, so RAIL_CAP_H still holds.
        const y1 = -CORE + TREAD * PARA_EVERY * (j - 1) + ((j === 1 && doorPostAt(lap + 1)) ? DOOR_POST_NOTCH : 0);   // the gate post takes the first 10
        addBox(`lap${lap + 1} E para ${j}`, PX, PX + PARA, y1, -CORE + TREAD * PARA_EVERY * j, top - RISE * (PARA_EVERY - 1), top + PARA_H, paraMat);
      }
    }
    for (let j = 1; j <= STEPS / PARA_EVERY; j++) {
      const top = mid + RISE * PARA_EVERY * j;
      addBox(`lap${lap + 1} N para ${j}`, CORE - TREAD * PARA_EVERY * j, CORE - TREAD * PARA_EVERY * (j - 1), PX, PX + PARA, top - RISE * (PARA_EVERY - 1), top + PARA_H, paraMat); // ankle gap: see E para
    }
    if (BREATHER_LAPS.has(lap + 1)) {
      addBox(`lap${lap + 1} NE landing para a`, PX, PX + PARA, CORE, PX, mid, mid + PARA_H, paraMat);
    } else {
      addBox(`lap${lap + 1} NE landing para a`, PX, PX + PARA, CORE, PX + PARA, mid, mid + PARA_H, paraMat);
      addBox(`lap${lap + 1} NE landing para b`, CORE, PX, PX, PX + PARA, mid, mid + PARA_H, paraMat);
    }
    // v9: the odd-only "final NW landing para" special case is gone with the
    // landing it railed (see above).
    addBox(`lap${lap + 1} NW landing para a`, -PX - PARA, -PX, CORE + (doorPostAt(lap + 2) ? DOOR_POST_NOTCH : 0), PX + PARA, end, end + PARA_H, paraMatOf(lap + 1));   // the next lap's gate post takes the first 10
    addBox(`lap${lap + 1} NW landing para b`, -PX, -CORE, PX, PX + PARA, end, end + PARA_H, paraMatOf(lap + 1));
  } else {
    for (let j = 1; j <= STEPS / PARA_EVERY; j++) {
      const top = b + RISE * PARA_EVERY * j;
      const y2 = CORE - TREAD * PARA_EVERY * (j - 1) - ((j === 1 && doorPostAt(lap + 1)) ? DOOR_POST_NOTCH : 0);   // the gate post takes the last 10
      addBox(`lap${lap + 1} W para ${j}`, -PX - PARA, -PX, CORE - TREAD * PARA_EVERY * j, y2, top - RISE * (PARA_EVERY - 1), top + PARA_H, paraMat); // ankle gap: see E para
    }
    for (let j = 1; j <= STEPS / PARA_EVERY; j++) {
      const top = mid + RISE * PARA_EVERY * j;
      addBox(`lap${lap + 1} S para ${j}`, -CORE + TREAD * PARA_EVERY * (j - 1), -CORE + TREAD * PARA_EVERY * j, -PX - PARA, -PX, top - RISE * (PARA_EVERY - 1), top + PARA_H, paraMat); // ankle gap: see E para
    }
    if (BREATHER_LAPS.has(lap + 1)) {
      addBox(`lap${lap + 1} SW landing para a`, -PX - PARA, -PX, -PX, -CORE, mid, mid + PARA_H, paraMat);
    } else {
      addBox(`lap${lap + 1} SW landing para a`, -PX - PARA, -PX, -PX - PARA, -CORE, mid, mid + PARA_H, paraMat);
      addBox(`lap${lap + 1} SW landing para b`, -PX, -CORE, -PX - PARA, -PX, mid, mid + PARA_H, paraMat);
    }
    addBox(`lap${lap + 1} SE landing para a`, PX, PX + PARA, -PX - PARA, -CORE - (doorPostAt(lap + 2) ? DOOR_POST_NOTCH : 0), end, end + PARA_H, paraMatOf(lap + 1));   // the next lap's gate post takes the last 10
    addBox(`lap${lap + 1} SE landing para b`, CORE, PX, -PX - PARA, -PX, end, end + PARA_H, paraMatOf(lap + 1));
  }

  // -------------------------------------------------------------------------
  // RAIL CAPS (v9, user 2026-08-21: "you can just jump on top of the guard
  // rails on the stairs and jump off the map").
  //
  // PARA_H is 56 and a BO3 jump tops out around that — so every rail is a
  // mountable ledge, and from a rail top the drop outside is 19,000 units of
  // nothing. The obvious fix (raise PARA_H) is the WRONG one: the rail would
  // then sit above eye height and the whole point of an open-air spiral over a
  // neon city is that you can SEE the city while you climb.
  //
  // So the rails stay 56 tall and get an invisible CLIP CAP instead: a `clip`
  // volume filling the airspace directly above each rail run. You can still
  // hop onto a rail; you simply cannot get any higher or move outward. And
  // because a clip does not have to follow the stairs, ONE box spans a whole
  // flight's worth of stepped parapet — 4 brushes per lap instead of one per
  // rail segment (~200 total, not ~900, which matters: the LED bake is the
  // gate and it is already at 44.5s).
  //
  // Each cap's bottom sits at the run's LOWEST rail top and its top clears the
  // HIGHEST rail top by RAIL_CAP_H, so no segment is standable. Caps live in
  // the parapet's own x/y band (outside the walkway), so they never pinch the
  // stairs, and they top out far below the next same-side lap (+768).
  // A breather lap OPENS its mid landing into the balcony (the corner rail is
  // omitted there) — so the caps must stop short of that doorway or they wall
  // the balcony off / leave an invisible pillar standing on its floor.
  const br = BREATHER_LAPS.has(lap + 1);
  if (odd) {
    // E flight rail + the NE landing's east rail, one cap
    if (lap === 0) {
      // v10.3 — THE BASE-FLOOR INVISIBLE BARRIER (playtest 2026-08-23: "the
      // invisible barrier is still there. Its under the stairs... on the base
      // floor"). The generic E cap starts at b+PARA_H = z56 — KNEE height —
      // and at lap 1 'b' is the ARENA FLOOR, so the cap stood as an invisible
      // 20-thin wall at x=416 across the whole east band, including under the
      // NE landing where nothing visible suggests a wall (the v9.34 fix made
      // the 288 anti-bypass SLAB visible, but this clip hovered on top of and
      // beyond it, y all the way to 436). At ground level the cap protects
      // nothing — hopping the first flight's rail lands you on the arena
      // floor. So at lap 1 the cap keeps only the spans that matter:
      //   * over the anti-bypass wall (y[-CORE,CORE]) from the WALL'S TOP
      //     (288) up — the wall itself already blocks below;
      //   * beside the NE landing (y[CORE,PX+PARA]) from the LANDING RAIL top
      //     (mid+PARA_H = 248) up — head-high off the base floor, so nothing
      //     at ground level can touch it.
      addBox('lap1 rail cap E over wall', PX, PX + PARA, -CORE, CORE, 288, b + FLIGHT_RISE + PARA_H + RAIL_CAP_H, MAT.clip);
      addBox('lap1 rail cap E landing', PX, PX + PARA, CORE, PX + PARA, mid + PARA_H, b + FLIGHT_RISE + PARA_H + RAIL_CAP_H, MAT.clip);
    } else {
      addBox(`lap${lap + 1} rail cap E`, PX, PX + PARA, -CORE, (br ? PX : PX + PARA), b + PARA_H, b + FLIGHT_RISE + PARA_H + RAIL_CAP_H, MAT.clip);
    }
    // N flight rail + (non-breather) the NE landing's north rail
    addBox(`lap${lap + 1} rail cap N`, -CORE, (br ? CORE : PX + PARA), PX, PX + PARA, mid + PARA_H, mid + FLIGHT_RISE + PARA_H + RAIL_CAP_H, MAT.clip);
    // NW landing corner rails (a different z tier — their own caps)
    addBox(`lap${lap + 1} rail cap NW a`, -PX - PARA, -PX, CORE, PX + PARA, end + PARA_H, end + PARA_H + RAIL_CAP_H, MAT.clip);
    addBox(`lap${lap + 1} rail cap NW b`, -PX, -CORE, PX, PX + PARA, end + PARA_H, end + PARA_H + RAIL_CAP_H, MAT.clip);
  } else {
    addBox(`lap${lap + 1} rail cap W`, -PX - PARA, -PX, (br ? -PX : -PX - PARA), CORE, b + PARA_H, b + FLIGHT_RISE + PARA_H + RAIL_CAP_H, MAT.clip);
    addBox(`lap${lap + 1} rail cap S`, (br ? -CORE : -PX - PARA), CORE, -PX - PARA, -PX, mid + PARA_H, mid + FLIGHT_RISE + PARA_H + RAIL_CAP_H, MAT.clip);
    addBox(`lap${lap + 1} rail cap SE a`, PX, PX + PARA, -PX - PARA, -CORE, end + PARA_H, end + PARA_H + RAIL_CAP_H, MAT.clip);
    addBox(`lap${lap + 1} rail cap SE b`, CORE, PX, -PX - PARA, -PX, end + PARA_H, end + PARA_H + RAIL_CAP_H, MAT.clip);
  }

  // (v13: the breather rail caps, the window guards and the ammo-crate
  // collision clip are all emitted by the BREATHER LOUNGE block above — the
  // room's window band carries clip_player, the spur rails carry MAT.clip
  // caps, and the crate clip derives from BR_FURN so it tracks the data file.)
}

// ---------------------------------------------------------------------------
// 5. THE CROWN (v9) — everything above the spiral. Odd frame; cbox mirrors.
// ---------------------------------------------------------------------------
// a rail run + its invisible cap, in one call (z = the floor the rail stands on)
function crail(label, x1, x2, y1, y2, z, mat) {
  cbox(label, x1, x2, y1, y2, z, z + RAIL_H, mat || MAT.roofPara);
  cbox(`${label} cap`, x1, x2, y1, y2, z + RAIL_H, z + RAIL_H + RAIL_CAP_H, MAT.clip);
}
// `cspike()` AND `SKY_MAT_PINK` LIVED HERE AND ARE DELETED (v11, 2026-08-25).
// cspike stacked tiers that could only get NARROWER, and every caller it ever
// had was a crown spire: the 4 corner towers (192->144->96->40), the 3 mid
// pilasters (128->96->56->24) and the 2 gate spires (32->20), all of them
// tipped in SKY_MAT_PINK. Measured from the base arena those tips were 0.10,
// 0.06 and 0.05 degrees — 3 px, 1.8 px and 1.5 px — so none of them was ever
// visible from anywhere in the map, and the shape they made is the thing the
// user was describing when he said "it just looks like a castle with spikes".
// A form that narrows to a point is a SPIRE. The crown's replacement helper is
// `cfleuron()` in section 5f, whose whole reason for existing is that a tier
// may be WIDER than the one below it. If a narrowing stack is ever wanted
// again, write it there and say what it is for — do not resurrect this one.

// --- 5a. CROWN STAIR: the last flight, gold, welded to the final landing ----
// In the odd frame this is an E flight from the SE landing (y=-CORE) up to
// the terrace (y=+CORE). With LAPS even the crown lap is odd and CM=+1, so it
// really is the east face; with LAPS odd it mirrors to the west face off the
// NW landing. Either way the first tread sits on the landing the spiral
// actually finished on — that is the whole fix for "the last platform isn't
// connected to the stairs".
for (let i = 1; i <= STEPS; i++) {
  const [z1, z2] = slabZ(TOP + RISE * i);
  cbox(`crown step ${i}`, CORE, PX, -CORE + TREAD * (i - 1), -CORE + TREAD * i, z1, z2, MAT.crownStep);
}
if (STAIR_RAMP_CLIP) {
  // The crown stair's ramp, mirrored by hand because the wedge emitters do not
  // go through cbox (they are not AABBs). CM point-mirror maps the odd-frame E
  // form onto the W form — the same mapping the spiral's own even laps use.
  // (Does not register in crownBB — it sits inside the crown stair's envelope.)
  if (CM === 1) rampWedgeY('crown stair ramp', CORE, PX, -CORE - TREAD, CORE - TREAD, TOP, TOP + FLIGHT_RISE, MAT.rampClip);
  else rampWedgeY('crown stair ramp', -PX, -CORE, -CORE + TREAD, CORE + TREAD, TOP + FLIGHT_RISE, TOP, MAT.rampClip);
}
for (let j = 1; j <= STEPS / PARA_EVERY; j++) {
  const top = TOP + RISE * PARA_EVERY * j;
  cbox(`crown stair rail ${j}`, PX, PX + PARA, -CORE + TREAD * PARA_EVERY * (j - 1), -CORE + TREAD * PARA_EVERY * j, top - RISE * (PARA_EVERY - 1), top + RAIL_H, MAT.roofPara); // ankle gap: see E para
}
cbox('crown stair rail cap', PX, PX + PARA, -CORE, CORE, TOP + RAIL_H, TOP2 + RAIL_H + RAIL_CAP_H, MAT.clip);

// --- 5a2. THE TOWER SHELL (v13.5, user 2026-08-28: "Im considering add walls
// to the toer so you cant see outside except for the side that can see the
// crown" / "Except for the side facing the crown. It gives visuals for
// players") ------------------------------------------------------------------
// Three walls enclose the spiral — EAST, SOUTH, WEST — and the NORTH stays
// fully open: the crown floats north of the tower, so the open side IS the
// crown view, revealed more with every lap climbed. What this changes: the
// climb becomes a shaft — Tron floors and door glow against dark walls, the
// Miami sky and the crown visible only through the north opening (and through
// each lounge's own windows, which poke out past the shell).
//
// GEOMETRY RULES, each load-bearing:
//  * Inner faces at +/-SHELL_IN = PX+PARA+24 — a 24u air gap outside the
//    parapets, so nothing is coplanar with a parapet face (z-fight rule) and
//    the lint's edge logic is untouched (walls stand in the void, never on
//    deck; boss/zombie navmesh never knew the void existed).
//  * STARTS at z = LAP_RISE (384): the base arena (half-extent 540) is WIDER
//    than the shell, so the shell begins above lap 1 and the arena keeps its
//    open-air street feel; from the arena you look UP into the shaft mouth.
//  * ENDS at z = TOP (19200): the roof deck, terrace, crown stair and
//    causeway stay open to the sky.
//  * BREATHER GAPS: the four lounges (all even laps -> all on the SW side)
//    span x[-800,-256] y[-992,-416] — they CROSS both the S and W shell
//    planes, so those two walls open for each breather's full z band
//    [mid-16, mid+400] (floor slab underside to just past the roof trim).
//    The lounges are their own walls there; the teleporter spurs stay
//    floating outside the shell, exactly the v13 exposure design. The E wall
//    has no breathers and runs unbroken.
//  * Corners: E and W own the S corners (their y spans run to -SHELL_OUT);
//    the S wall spans between their inner faces. Zero overlap, zero gap.
//  * MAT.ground (dark navy) on all faces — the decade-banding decoration
//    pass (docs/24 / Fifty Floors review) has a canvas now, not a decision.
const TOWER_SHELL = false;  // OFF (user 2026-08-29: "Remove the walls. They are
                            // ugly and you didnt vene implement them correctly.")
                            // The v13.5 shell lasted one build. Kept as a flag,
                            // not deleted: the geometry was lint/bake-proven, so
                            // if a future enclosed-shaft look is wanted, start
                            // here — but sell the LOOK to the user first with a
                            // preview render, which is the step this skipped.
if (TOWER_SHELL) {
  const SHELL_IN  = PX + PARA + 24;   // 460
  const SHELL_TH  = 32;
  const SHELL_OUT = SHELL_IN + SHELL_TH;   // 492
  const SHELL_Z0  = LAP_RISE;         // 384
  const SHELL_Z1  = TOP;              // 19200
  // Breather z bands (ascending), derived — never hand-copied.
  const shellGaps = [...BREATHER_LAPS].sort((a, b) => a - b)
    .map(lap => { const mid = (lap - 1) * LAP_RISE + FLIGHT_RISE; return [mid - 16, mid + 400]; });
  // EAST — one unbroken slab, S corner owned, stops at the N opening.
  addBox('tower shell E', SHELL_IN, SHELL_OUT, -SHELL_OUT, SHELL_IN, SHELL_Z0, SHELL_Z1, MAT.ground);
  // SOUTH + WEST — five segments each, gapped at the four breather bands.
  let zlo = SHELL_Z0;
  const bands = [...shellGaps, [SHELL_Z1, SHELL_Z1]];
  for (let i = 0; i < bands.length; i++) {
    const [glo, ghi] = bands[i];
    if (glo > zlo) {
      addBox(`tower shell S ${i + 1}`, -SHELL_IN, SHELL_IN, -SHELL_OUT, -SHELL_IN, zlo, glo, MAT.ground);
      addBox(`tower shell W ${i + 1}`, -SHELL_OUT, -SHELL_IN, -SHELL_OUT, SHELL_IN, zlo, glo, MAT.ground);
    }
    zlo = ghi;
  }
}

// --- 5b. TERRACE: the forecourt along the capital's arrival face -----------
// Glow-edge tiles; the stair's last tread (top = TOP2, y up to +CORE) meets its
// south edge flush. Its south side for x[-CORE,CORE] is the mast's base tier
// (solid), so the core top is never a walkable surface.
cbox('terrace', -TER_W, TER_W, TER_Y1, TER_Y2, TOP2 - SLAB, TOP2, MAT.crownRing);
cbox('terrace under-glow', -TER_W, TER_W, TER_Y1, TER_Y2, TOP2 - SLAB - 24, TOP2 - SLAB, MAT.crownFascia);
crail('terrace rail N west', -TER_W - PARA, -CW_HALF - PARA, TER_Y2, TER_Y2 + PARA, TOP2);
crail('terrace rail N east', CW_HALF + PARA, TER_W + PARA, TER_Y2, TER_Y2 + PARA, TOP2);
crail('terrace rail W', -TER_W - PARA, -TER_W, TER_Y1 - PARA, TER_Y2, TOP2);
crail('terrace rail E', TER_W, TER_W + PARA, TER_Y1 - PARA, TER_Y2, TOP2);
// south edge: west of the core (void below), and east of the stair rail (void below)
crail('terrace rail S west', -TER_W - PARA, -CORE, TER_Y1 - PARA, TER_Y1, TOP2);
crail('terrace rail S east', PX + PARA, TER_W + PARA, TER_Y1 - PARA, TER_Y1, TOP2);

// --- 5c. THE LAST MILE: the causeway ----------------------------------------
// v10.12 (user 2026-08-23: "Keep adding geometry, one thing to be carefull of
// are holes and miss placed walls").
//
// HOW THIS SECTION IS BUILT, AND WHY IT IS BUILT THAT WAY
// ------------------------------------------------------
// The v10.11 road hand-cut its own rails: each piece knew which of its own
// faces to guard, and each junction hand-computed the gaps where a branch
// opened off it (`face()` walking a sorted list of mouth x-centres). That works
// for a road made of parallel strips and starts producing slivers and holes the
// moment the road TURNS — which is exactly what the user then asked for. Every
// dogleg would be a new hand-reasoned rail case, and the failure mode is not a
// crash: it is a 20-unit gap over 19,000 units of open sky that nobody sees
// until a player walks through it. This map has already shipped that bug once,
// in the other direction (the lap-1 "rail cap E" starting at knee height ON the
// arena floor, reported three times as an invisible barrier before it was found).
//
// So the road is no longer drawn. It is DECLARED as a set of flat, grid-aligned
// DECK CELLS, and the rails are DERIVED from the union of those cells:
//
//   roadFlat()  / roadStair()   declare deck. They never emit a rail.
//   roadPortal()                declares "geometry I do not own continues here"
//                               (the terrace mouth, the citadel gate opening).
//   roadEmit()                  rasterises every cell onto a 20-unit grid and
//                               guards EVERY exposed edge it finds.
//
// Three properties then hold BY CONSTRUCTION rather than by inspection:
//
//   1. NO UNGUARDED EDGE. A rail goes on every grid column face whose neighbour
//      is not deck. There is no way to forget one, because nothing is written
//      by hand — a hole would have to be a hole in the cell list, and (3)
//      catches that.
//   2. NO MISPLACED WALL. ROAD_G === PARA === 20, so a rail occupies EXACTLY the
//      one unoccupied grid column outside the edge it guards. A rail can never
//      land on deck, because the column it sits in is by definition not deck.
//      This is the whole reason the grid is 20 and not 16 or 32; if you change
//      PARA you must change ROAD_G with it or that guarantee silently dies.
//   3. NO UNWALKABLE JOIN. Adjacent occupied columns are asserted to be within
//      ROAD_STEP_MAX of each other. A dogleg that misses its neighbour by a
//      cell, or a flight that lands 40 units proud of its landing, throws AT
//      GENERATION TIME instead of shipping.
//
// tools/lint_tod_geometry.js re-proves all three by parsing the FINISHED .map,
// independently of this code, so a bug in the builder above cannot hide behind
// the builder's own assertions.
//
// THE SHAPE, south to north (v12, user 2026-08-26: "the paths to get to the
// crown building are pretty simple and straight forward. Lets be more creative
// ... the run over to it should be scary and anxious driving"). The v10.12
// road was two MIRRORED doglegs and a plank — learn one fork and you knew the
// other, and mirrored shapes cannot be scary twice. Every lane is now a
// DIFFERENT KIND of fear, and the two forks teach opposite lessons:
//
//   A   GATE RUN     on-axis, flat. The GATE seals its mouth until EXTRACTION.
//   J1  FORK
//   W*  THE RIDGE   (west)  climbs +256 and ZIGZAGS along the crest — outer
//                           run, cut back in, inner run, descend. Longest walk,
//                           longest sightlines, and the best view of the crown
//                           on the whole road: height = vision = exposure.
//   E*  THE BROKEN STAIR (east)  steps DOWN into sunken pockets — drop, pocket,
//                           drop, a 640-long hollow at -256 you cannot see out
//                           of, then ONE long blind climb to the merge. The
//                           short straight lane, bought with blindness.
//   J2  MERGE
//   N   THE NARROWS  on-axis, flat — and the deck PINCHES to 120 for the middle
//                    stretch. Everybody crosses this, single file, under the
//                    second portal frame. The one guaranteed choke on the road.
//   J3  THREE-WAY FORK — three flavours of fear, pick one:
//   W*  THE UNDERCROFT (west)  plunges -384 (the deepest the road goes), a wide
//                           ambush CISTERN at the bottom, then a 960-unit blind
//                           ascent straight into the merge. Feels safe, is
//                           lonely — stairs draw no risers, so the pressure all
//                           waits in the basin. From the bottom the crown's
//                           whole underside hangs overhead.
//   P*  THE PLANK   (centre) 120 wide, dead straight, lifted +256 clear of
//                           everything — no cover at all, and it splits into
//                           four pieces so it is the riser-DENSEST lane per
//                           unit length. The exposed fast line.
//   E*  THE WEAVE   (east)  flat at deck height the whole way but SERPENTINES
//                           through four jogs — nine pieces, nine risers, the
//                           most infested ground on the road. Flat does not
//                           mean safe.
//   J4  MERGE
//   F   APPROACH     on-axis, flat, into the citadel gate.
//
// (An emergent bonus the boss code already provides: anchor_player keys the
// Panzer to the HIGHEST living player and protectors to the LOWEST — so the
// plank draws the Panzer plug and the undercroft draws the swarm. Recorded in
// docs/32 as the altitude-sorting oddity; here it is the design.)
//
// LOAD-BEARING: A and F are on-axis at TOP2 because they must meet the terrace
// mouth and the hall's gate opening (x +/-GATE_HALF). Every branch returns to
// TOP2 before a merge, so junctions are always flat. The span budget cwSpan is
// UNCHANGED from v10.12 — every fork/landing boundary keeps its y — so the
// 5f.1/5f.9 crown-vs-road asserts and the pinned CR_S_FACE stay valid without
// re-derivation. Verticality note: the undercroft's -384 slightly exceeds the
// +-256 envelope the finale's yaw-only "ahead" tests were tuned against
// (_tod_endless_rounds.gsc:172-178) — same mechanism, deeper trough; the
// fallback paths there degrade gracefully (spawn lands beside instead of
// ahead). Do not go deeper than 384 without re-reading that comment.

const ROAD_G        = 20;    // rasterisation grid. MUST equal PARA — see (2) above.
const ROAD_STEP_MAX = 18;    // BO3 walks up to this without a jump (stock stepSize)
const CW_TREAD      = 40;    // stair tread depth (multiple of ROAD_G)
const CW_RISE       = 16;    // stair rise per tread (<= ROAD_STEP_MAX)
const CW_HUMP       = 256;   // how far a raised/sunken branch leaves TOP2
const CW_PLANK_HUMP = 256;   // plank lift. v12: 192 -> 256 — with the second
                             // fork's west lane now DIVING CW_DEEP the plank
                             // reads taller by matching the ridge, and 256 is
                             // exactly the envelope the finale's yaw-only
                             // "ahead" spawn test was already tuned against.
const CW_DEEP       = 384;   // the undercroft's plunge — the deepest the road
                             // goes. 384 = 24 treads = 960 of run each way.
                             // HARD CEILING: see the verticality note in the
                             // shape comment above before deepening this.
const CW_LAT        = 400;   // branch centreline offset from the axis
const CW_SWING      = 720;   // outer-lane centreline: the ridge crest and the weave's far runs
// THE PLANK IS NARROW — 120, against 160 everywhere else.
//
// This went 120 -> 160 -> 120 in one session and the round trip is worth
// recording. The widening was caution: nothing in this map or map 1 has had a
// zombie path a walkway under 160, so 120 was an unproven width on the piece of
// road that is supposed to be the DANGEROUS one, and if the navmesh came out
// thin there and zombies avoided it, the exposed shortcut would quietly become
// the safe route.
//
// Review killed that reasoning: at 160 the plank is STRICTLY DOMINANT. It is
// the shortest line through the second fork by ~1200 units, it is no narrower
// than the alternatives, and being raised costs a player nothing on a bridge in
// open sky where there was never any cover to lose. A choice with no downside
// is not a choice. And the failure the widening was insuring against — zombies
// avoiding the plank — produces the SAME safe-shortcut outcome that 160
// guarantees outright. So 120 is weakly dominant: better if pathing works, no
// worse if it does not. 120 still fits three zombies abreast (~40-45 each).
// It is on the playtest list either way.
const CW_PLANK_HALF = 60;

// Narrowest walkable lane the road is allowed to declare, cross-axis. Nothing
// in this map or map 1 has ever had a zombie path along a walkway under 160
// (the spiral itself is PX-CORE = 160), so anything below that is unproven
// rather than wrong. 120 is set as the tripwire, not as a physical limit: a
// zombie is ~40-45 units wide, so 60 would be the true floor. If a future
// design genuinely wants a narrower catwalk, RAISE this deliberately and
// accept that zombie pathing on it is untested — the failure mode is that they
// avoid it, which silently turns whatever you built as the dangerous route
// into the safe one.
const CW_MIN_LANE   = 120;

// How wide the road opens out to where it meets the citadel gate. The gate
// opening is GATE_HALF*2 = 256 and the road is 160, and the difference used to
// be open hall floor guarded by nothing — walk in a little wide and you drop
// 19,000 units. Asserted rather than commented: both of these were prose in the
// first cut and the second one was violated within the hour.
const CW_FLARE      = 120;
if (CW_FLARE > GATE_HALF) throw new Error(`CW_FLARE ${CW_FLARE} would foul the gate posts at ${GATE_HALF}`);
if (CW_FLARE % ROAD_G)    throw new Error(`CW_FLARE ${CW_FLARE} is not a multiple of ROAD_G ${ROAD_G}`);
if (CW_FLARE < CW_HALF)   throw new Error(`CW_FLARE ${CW_FLARE} is narrower than the road it flares from`);

if (ROAD_G !== PARA) throw new Error('ROAD_G must equal PARA or derived rails can land on deck');
if (CW_RISE > ROAD_STEP_MAX) throw new Error('CW_RISE exceeds the walkable step');

// ---- the deck-cell model ---------------------------------------------------
// A CELL is a flat, grid-aligned rectangle of deck at one height. Stairs are
// just many cells. Nothing here is ever a slope: a ramp cannot be rasterised
// onto a grid without picking a height per column anyway, and pretending
// otherwise is how the ankle-gap under a stepped parapet got shipped in v10.11.
const roadCells = [];    // { tag, x1, x2, y1, y2, z, deck }
// Set by roadEmit(). Rails are DERIVED from the finished occupancy map, so a
// cell declared after the derivation would get no rails at all and could be
// overlapped by one — the silent version of exactly the defect this design
// exists to prevent.
let roadSealed = false;
const roadPieces = [];   // { tag, cx, cy, cz, kind } — one per NAMED piece, for risers/lights

function roadAssertGrid(tag, ...vals) {
  for (const v of vals)
    if (v % ROAD_G !== 0)
      throw new Error(`road "${tag}": ${v} is not a multiple of ROAD_G (${ROAD_G})`);
}

// deck:false = "something else owns the floor here, but it IS floor" — used for
// the terrace mouth and the citadel gate opening so the rail pass does not wall
// the road off from the two things it has to connect to.
function roadCell(tag, x1, x2, y1, y2, z, deck) {
  if (roadSealed) throw new Error(`road "${tag}": declared AFTER roadEmit() — it would get no rails`);
  roadAssertGrid(tag, x1, x2, y1, y2);
  if (x1 >= x2 || y1 >= y2) throw new Error(`road "${tag}": degenerate footprint`);
  roadCells.push({ tag, x1, x2, y1, y2, z, deck });
}

function roadPiece(tag, kind, cx, cy, cz) { roadPieces.push({ tag, kind, cx, cy, cz }); }

// A flat piece: one cell, one deck brush, one under-glow.
function roadFlat(tag, x1, x2, y1, y2, z) {
  if (Math.min(x2 - x1, y2 - y1) < CW_MIN_LANE)
    throw new Error(`road "${tag}": ${Math.min(x2 - x1, y2 - y1)}u lane is under CW_MIN_LANE ${CW_MIN_LANE}`);
  roadCell(tag, x1, x2, y1, y2, z, true);
  cbox(tag, x1, x2, y1, y2, z - SLAB, z, MAT.crownRing);
  cbox(`${tag} under-glow`, x1, x2, y1, y2, z - SLAB - 24, z - SLAB, MAT.crownFascia);
  roadPiece(tag, 'flat', (x1 + x2) / 2, (y1 + y2) / 2, z);
}

// A stepped piece along +y: one cell and one brush PER TREAD, so the rail pass
// guards every tread at its own height and no tread can end up with a parapet
// floating above its ankles.
function roadStair(tag, x1, x2, yA, yB, zA, zB) {
  // cross-axis only: a tread is deliberately shallow along the direction of travel
  if (x2 - x1 < CW_MIN_LANE)
    throw new Error(`road "${tag}": ${x2 - x1}u lane is under CW_MIN_LANE ${CW_MIN_LANE}`);
  const n = Math.round(Math.abs(zB - zA) / CW_RISE);
  if (n < 1) throw new Error(`road "${tag}": not a stair`);
  if (Math.abs(zB - zA) !== n * CW_RISE)
    throw new Error(`road "${tag}": rise ${zB - zA} is not a whole number of ${CW_RISE}u treads`);
  if (yB - yA !== n * CW_TREAD)
    throw new Error(`road "${tag}": ${n} treads need ${n * CW_TREAD}u of run, got ${yB - yA}`);
  const dz = (zB - zA) / n;
  for (let i = 0; i < n; i++) {
    const y0 = yA + CW_TREAD * i, y1 = y0 + CW_TREAD;
    const zt = zA + dz * (i + 1);   // the tread you step ONTO
    roadCell(`${tag} ${i + 1}`, x1, x2, y0, y1, zt, true);
    cbox(`${tag} step ${i + 1}`, x1, x2, y0, y1, zt - SLAB, zt, MAT.crownRing);
    cbox(`${tag} step ${i + 1} under-glow`, x1, x2, y0, y1, zt - SLAB - 24, zt - SLAB, MAT.crownFascia);
  }
  // STAIR RAMP CLIP (2026-08-27, docs/39) — the road's stairs get the same
  // invisible MAT.rampClip wedge as the tower's flights, emitted here so every
  // current AND future roadStair is ramped by construction. The nosing plane:
  //   * FALLING along +y: (yA,zA)->(yB,zB) touches every tread's downhill edge
  //     and welds flush at both ends — no feather needed.
  //   * RISING along +y: the same line shifted one tread back,
  //     (yA-CW_TREAD, zA)->(yB-CW_TREAD, zB) — it passes through every riser
  //     top, feathers 0->CW_RISE over the last CW_TREAD of the approach flat
  //     (every rising stair's approach is a wider flat at zA, checked per call
  //     site 2026-08-27: J1 fork / hollow 2 / cistern / J3 fork), and leaves
  //     the last tread's own top to carry the deck to yB.
  // The wedge is not a cell: rails, risers, reachability and every roadEmit
  // assert see exactly the geometry they saw before. Underside = plane - RAMP_T,
  // which stays inside the tread slabs (RISE == SLAB == 16 exactly here).
  if (STAIR_RAMP_CLIP) {
    if (zB < zA) rampWedgeY(`${tag} ramp`, x1, x2, yA, yB, zA, zB, MAT.rampClip, CW_RISE, CW_TREAD);
    else rampWedgeY(`${tag} ramp`, x1, x2, yA - CW_TREAD, yB - CW_TREAD, zA, zB, MAT.rampClip, CW_RISE, CW_TREAD);
  }
  roadPiece(tag, 'stair', (x1 + x2) / 2, (yA + yB) / 2, (zA + zB) / 2);
}

// "The floor continues here and I do not own it." Emits nothing.
function roadPortal(tag, x1, x2, y1, y2, z) { roadCell(tag, x1, x2, y1, y2, z, false); }

// ---- the rail pass ---------------------------------------------------------
// Rasterise, check every adjacency, guard every exposed face. This is the only
// code in the section that emits a rail.
function roadEmit() {
  roadSealed = true;
  const key = (gx, gy) => `${gx},${gy}`;
  const occ = new Map();

  for (const c of roadCells) {
    for (let x = c.x1; x < c.x2; x += ROAD_G) {
      for (let y = c.y1; y < c.y2; y += ROAD_G) {
        const k = key(x, y);
        const prev = occ.get(k);
        // OVERLAP IS ALWAYS A BUG HERE. This road never crosses over itself, so
        // two cells claiming one column means a copy-paste or an arithmetic
        // slip — and the rail pass would silently guard the wrong height.
        if (prev)
          throw new Error(`road overlap at (${x},${y}): "${prev.tag}" and "${c.tag}"`);
        occ.set(k, { z: c.z, tag: c.tag, deck: c.deck });
      }
    }
  }

  // Every 4-neighbour pair must be walkable. A dogleg that misses its partner by
  // one cell shows up here as an unguarded edge instead (correct, if ugly); a
  // flight that lands proud of its landing shows up as this throw.
  const DIRS = [[-ROAD_G, 0, 'W'], [ROAD_G, 0, 'E'], [0, -ROAD_G, 'S'], [0, ROAD_G, 'N']];
  const edges = [];   // { dir, gx, gy, z }
  for (const [k, cell] of occ) {
    const [gx, gy] = k.split(',').map(Number);
    for (const [dx, dy, dir] of DIRS) {
      const n = occ.get(key(gx + dx, gy + dy));
      if (!n) { if (cell.deck) edges.push({ dir, gx, gy, z: cell.z }); continue; }
      if (Math.abs(n.z - cell.z) > ROAD_STEP_MAX)
        throw new Error(
          `road step ${Math.abs(n.z - cell.z)}u > ${ROAD_STEP_MAX}u between "${cell.tag}" and "${n.tag}" at (${gx},${gy})`);
    }
  }

  // REACHABILITY, proven on the cell list before a single brush is written.
  // Flood from the terrace mouth; the citadel mouth must be in the flood, and
  // nothing may be outside it.
  const start = roadCells.find(c => c.tag === 'causeway terrace mouth');
  const goal = roadCells.find(c => c.tag === 'causeway citadel mouth');
  if (!start || !goal) throw new Error('road: both mouths must be declared');
  // BREADTH-first, so the distance it records is the SHORTEST walk. That number
  // matters: the finale clock is the length of one song (TOD_FINALE_SONG_SECS,
  // 191s) and the road is what the clock is for. If the quickest line through
  // here ever stops being comfortably runnable inside the song while fighting,
  // the ending becomes unwinnable and nothing else in the map will say so.
  const seen = new Map([[key(start.x1, start.y1), 0]]);
  let frontier = [[start.x1, start.y1]];
  let depth = 0;
  while (frontier.length) {
    const next = [];
    depth++;
    for (const [gx, gy] of frontier) {
      const here = occ.get(key(gx, gy));
      for (const [dx, dy] of DIRS) {
        const nk = key(gx + dx, gy + dy);
        if (seen.has(nk)) continue;
        const n = occ.get(nk);
        if (!n || Math.abs(n.z - here.z) > ROAD_STEP_MAX) continue;
        seen.set(nk, depth);
        next.push([gx + dx, gy + dy]);
      }
    }
    frontier = next;
  }
  const goalDepth = seen.get(key(goal.x1, goal.y1));
  if (goalDepth === undefined)
    throw new Error('road: the citadel mouth is NOT reachable from the terrace mouth');
  if (seen.size !== occ.size) {
    const orphan = [...occ].find(([k]) => !seen.has(k));
    throw new Error(`road: ${occ.size - seen.size} column(s) unreachable, first in "${orphan[1].tag}"`);
  }

  // Merge each exposed face into the longest runs of equal height, then guard
  // them. Merging is cosmetic (fewer, cleaner brushes); the guarantee comes from
  // the edge list, not from the merge.
  const groups = new Map();
  for (const e of edges) {
    // W/E faces run along y; N/S faces run along x.
    const along = (e.dir === 'W' || e.dir === 'E') ? e.gy : e.gx;
    const fixed = (e.dir === 'W' || e.dir === 'E') ? e.gx : e.gy;
    const gk = `${e.dir}|${fixed}|${e.z}`;
    if (!groups.has(gk)) groups.set(gk, { dir: e.dir, fixed, z: e.z, along: [] });
    groups.get(gk).along.push(along);
  }
  // PORTAL COVERAGE. A portal says "other geometry owns the floor here"; if the
  // rail pass wants to guard an edge that points INTO a portal's band, the
  // portal is too narrow for the road that meets it, and the rail is about to
  // be planted on somebody else's floor. That is not a hole and not an
  // invisible wall, so nothing downstream catches it — it has to throw here.
  const portals = roadCells.filter(c => !c.deck);
  for (const e of edges) {
    const [nx, ny] = { W: [e.gx - ROAD_G, e.gy], E: [e.gx + ROAD_G, e.gy],
                       S: [e.gx, e.gy - ROAD_G], N: [e.gx, e.gy + ROAD_G] }[e.dir];
    const lateral = (e.dir === "W" || e.dir === "E");
    for (const q of portals) {
      // Compare the rail against the portal ACROSS THE PORTAL'S THIN AXIS only.
      // A portal is a one-cell-deep strip: a mouth wide in x is thin in y, and
      // only a north/south rail can land in its row. Testing the wide axis too
      // fires on every side rail the road has, anywhere along its length, purely
      // because their x happens to fall inside the mouth's width.
      const thinInY = (q.x2 - q.x1) > (q.y2 - q.y1);
      if (thinInY === lateral) continue;   // this edge cannot reach that band
      const inBand = thinInY ? (ny >= q.y1 && ny < q.y2) : (nx >= q.x1 && nx < q.x2);
      if (!inBand) continue;
      throw new Error(
        `road: a rail would stand inside portal "${q.tag}" at (${nx},${ny}) — the portal is ` +
        `narrower than the road face that meets it, so this rail lands on geometry the road does not own`);
    }
  }

  let railN = 0;
  for (const g of groups.values()) {
    g.along.sort((a, b) => a - b);
    let run = [g.along[0], g.along[0] + ROAD_G];
    const runs = [run];
    for (let i = 1; i < g.along.length; i++) {
      if (g.along[i] === run[1]) run[1] += ROAD_G;
      else { run = [g.along[i], g.along[i] + ROAD_G]; runs.push(run); }
    }
    for (const [a1, a2] of runs) {
      railN++;
      const lbl = `causeway rail ${g.dir}${railN}`;
      // The guard sits in the neighbour column, which the edge list has already
      // established is not deck.
      const o = { W: [g.fixed - ROAD_G, g.fixed], E: [g.fixed + ROAD_G, g.fixed + 2 * ROAD_G],
                  S: [g.fixed - ROAD_G, g.fixed], N: [g.fixed + ROAD_G, g.fixed + 2 * ROAD_G] }[g.dir];
      if (g.dir === 'W' || g.dir === 'E') crail(lbl, o[0], o[1], a1, a2, g.z);
      else                                crail(lbl, a1, a2, o[0], o[1], g.z);
    }
  }
  return { columns: occ.size, edges: edges.length, rails: railN, walk: goalDepth * ROAD_G };
}

// ---- the layout ------------------------------------------------------------
// y-budget, south to north. These must sum to CW_LEN or run F misses the hall.
//   A 640 | J1 160 | branches 2240 | J2 160 | C 640 | J3 160 | branches 2240
//   | J4 160 | F 960   =  7360
const ZB      = TOP2;
const CW_LAND = 480;                       // junction landings span x +/-CW_LAND
const cwSpan  = [640, 160, 2240, 160, 640, 160, 2240, 160, 960];
const cwY     = [TER_Y2];
cwSpan.forEach(L => cwY.push(cwY[cwY.length - 1] + L));
if (cwY[cwY.length - 1] - TER_Y2 !== CW_LEN)
  throw new Error(`causeway spans sum to ${cwY[cwY.length - 1] - TER_Y2}, CW_LEN is ${CW_LEN}`);

const LX = [-CW_LAT - CW_HALF, -CW_LAT + CW_HALF];   // west branch lane
const EX = [CW_LAT - CW_HALF, CW_LAT + CW_HALF];     // east branch lane
const LW = [-CW_SWING - CW_HALF, -CW_SWING + CW_HALF];  // west outer lane (ridge crest / cistern west edge)
const EW = [CW_SWING - CW_HALF, CW_SWING + CW_HALF];    // east outer lane (the weave's far runs)
const PX_ = [-CW_PLANK_HALF, CW_PLANK_HALF];         // the centre plank

// THE TWO MOUTHS. Declared, never drawn — the terrace and the citadel own those
// floors. Without them the rail pass would wall the road off at both ends.
roadPortal('causeway terrace mouth', -CW_HALF, CW_HALF, TER_Y2 - ROAD_G, TER_Y2, ZB);
// THE CITADEL MOUTH IS CW_FLARE WIDE, NOT CW_HALF. This was 160 while the road
// that meets it flares to 240, and the 40 units either side promptly became
// what the rail pass thought was an exposed edge — so it dutifully guarded them,
// putting two rail bollards and their clip caps ON THE CROWN HALL FLOOR, inside
// the gate opening, at the finish line. Three independent reviewers found it and
// none of the automated checks did: the road builder cannot see the hall, and
// the geometry lint only reports INVISIBLE misplaced walls, so a visible rail
// standing on somebody else's floor passes clean. roadEmit now throws on it —
// see the portal-coverage assert there.
roadPortal('causeway citadel mouth', -CW_FLARE, CW_FLARE, cwY[9], cwY[9] + ROAD_G, ZB);

// A — the gate run. The GATE (an entity, emitted further down) stands across it.
roadFlat('causeway A gate-run', -CW_HALF, CW_HALF, cwY[0], cwY[1], ZB);
roadFlat('causeway J1 fork', -CW_LAND, CW_LAND, cwY[1], cwY[2], ZB);

// (roadDogleg is GONE — v12. It built both halves of a fork as one mirrored
// helper, which is exactly why the road felt "simple and straightforward":
// mirrored shapes cannot surprise twice. The lanes below are written out one
// by one ON PURPOSE — each is a different shape — and every block's y-run is
// pinned to the cwY[] boundaries, so roadStair's own tread arithmetic plus the
// roadEmit adjacency sweep replace the old end-y asserts.)

// FIRST FORK — THE RIDGE (west) vs THE BROKEN STAIR (east).
// The ridge is the long open lane: climb, run the OUTER crest, cut back in,
// run the INNER shelf, descend. Two direction changes at height, so the crest
// never shows you all of itself — and from +256 it is the best view of the
// crown anywhere on the road. The awe lane, paid for in exposure and distance.
{
  const zTop = ZB + CW_HUMP, climb = CW_TREAD * (CW_HUMP / CW_RISE);   // 640
  const yA = cwY[2];
  roadStair('causeway W ridge climb', LX[0], LX[1], yA, yA + 640, ZB, zTop);
  roadFlat('causeway W ridge elbow out', LW[0], LX[1], yA + 640, yA + 800, zTop);
  roadFlat('causeway W ridge crest', LW[0], LW[1], yA + 800, yA + 1200, zTop);
  roadFlat('causeway W ridge jog', LW[0], LX[1], yA + 1200, yA + 1360, zTop);
  roadFlat('causeway W ridge shelf', LX[0], LX[1], yA + 1360, yA + 1600, zTop);
  roadStair('causeway W ridge descent', LX[0], LX[1], yA + 1600, cwY[3], zTop, ZB);
  if (yA + 1600 + climb !== cwY[3]) throw new Error('ridge y-budget does not close on J2');
}
// The broken stair is the short blind lane: two half-drops with a pocket
// between them, a 640-long HOLLOW at -256 whose walls hide everything, then
// one unbroken 16-tread ascent — the merge above is invisible until the last
// step. Straight in plan, terrifying in section. The hollow is split in two
// so the deepest ground on this fork is also its riser-densest.
{
  const zMid = ZB - CW_HUMP / 2, zLow = ZB - CW_HUMP;
  const yA = cwY[2];
  roadStair('causeway E steps drop 1', EX[0], EX[1], yA, yA + 320, ZB, zMid);
  roadFlat('causeway E steps pocket', EX[0], EX[1], yA + 320, yA + 640, zMid);
  roadStair('causeway E steps drop 2', EX[0], EX[1], yA + 640, yA + 960, zMid, zLow);
  roadFlat('causeway E hollow 1', EX[0], EX[1], yA + 960, yA + 1280, zLow);
  roadFlat('causeway E hollow 2', EX[0], EX[1], yA + 1280, yA + 1600, zLow);
  roadStair('causeway E hollow climb', EX[0], EX[1], yA + 1600, cwY[3], zLow, ZB);
}

roadFlat('causeway J2 merge', -CW_LAND, CW_LAND, cwY[3], cwY[4], ZB);

// THE NARROWS — the old flat spine, with its middle PINCHED to the plank's
// width. Every route crosses this, so the pinch is the road's one guaranteed
// choke: 320 units of single file directly under the second portal frame,
// with the shoulder bollards the rail pass derives marking the squeeze. Two
// pieces, two risers — the choke feeds itself.
roadFlat('causeway N throat south', -CW_HALF, CW_HALF, cwY[4], cwY[4] + 160, ZB);
roadFlat('causeway N narrows 1', -CW_PLANK_HALF, CW_PLANK_HALF, cwY[4] + 160, cwY[4] + 320, ZB);
roadFlat('causeway N narrows 2', -CW_PLANK_HALF, CW_PLANK_HALF, cwY[4] + 320, cwY[4] + 480, ZB);
roadFlat('causeway N throat north', -CW_HALF, CW_HALF, cwY[4] + 480, cwY[5], ZB);

roadFlat('causeway J3 fork', -CW_LAND, CW_LAND, cwY[5], cwY[6], ZB);

// SECOND FORK — three ways, three flavours of fear.
// THE UNDERCROFT (west): a pure V — 24 treads down, a wide CISTERN at -384,
// 24 treads back up. Stairs draw no risers, so the descent is eerily quiet and
// the cistern is where the ambush lives; the ascent is 960 units of stairs
// with the merge hidden past the crest the whole way. From the cistern floor
// the crown's entire underside hangs overhead — the deep lane is also the
// map's best look UP at the thing you are running toward.
{
  const zLow = ZB - CW_DEEP, run = CW_TREAD * (CW_DEEP / CW_RISE);   // 960
  const yA = cwY[6];
  roadStair('causeway W undercroft descent', LX[0], LX[1], yA, yA + run, ZB, zLow);
  roadFlat('causeway W undercroft cistern', LW[0], LX[1], yA + run, yA + run + 320, zLow);
  roadStair('causeway W undercroft ascent', LX[0], LX[1], yA + run + 320, cwY[7], zLow, ZB);
  if (yA + 2 * run + 320 !== cwY[7]) throw new Error('undercroft y-budget does not close on J4');
}
// THE PLANK (centre) — unchanged in spirit from v10.11, raised to +256 so it
// clears the fork by the full hump. Dead straight, 120 wide, no cover at all.
// Same walked length as the undercroft's straight V — the choice between them
// is not distance, it is WHICH fear: constant fire in the open, or the quiet
// deep and one blind climb. See CW_PLANK_HALF for the 120-not-160 record.
{
  const climb = CW_TREAD * (CW_PLANK_HUMP / CW_RISE);   // 640
  const zTop = ZB + CW_PLANK_HUMP;
  const yA = cwY[6], yB = yA + climb, yC = cwY[7] - climb;
  roadStair('causeway P plank climb', PX_[0], PX_[1], yA, yB, ZB, zTop);
  // FOUR pieces, not one. Risers are placed one per flat piece, so a single
  // long plank drew ONE riser while other lanes drew three — the lane meant
  // to be the hot one was the quietest on the road. Split, it is dense: four
  // risers over the short straight middle, with nothing to hide behind.
  const seg = (yC - yB) / 4;
  for (let i = 0; i < 4; i++)
    roadFlat(`causeway P plank ${i + 1}`, PX_[0], PX_[1], yB + seg * i, yB + seg * (i + 1), zTop);
  roadStair('causeway P plank drop', PX_[0], PX_[1], yC, cwY[7], zTop, ZB);
}
// THE WEAVE (east): never leaves deck height, never runs straight for more
// than 480 units. Four jogs = eight blind corners; nine flat pieces = nine
// risers, the most infested ground on the road. Flat does not mean safe —
// this is the lane for players who fear stairs more than zombies.
{
  const yA = cwY[6];
  const W = [
    ['run 1', EX[0], EX[1], 0, 240], ['jog 1', EX[0], EW[1], 240, 400],
    ['run 2', EW[0], EW[1], 400, 880], ['jog 2', EX[0], EW[1], 880, 1040],
    ['run 3', EX[0], EX[1], 1040, 1280], ['jog 3', EX[0], EW[1], 1280, 1440],
    ['run 4', EW[0], EW[1], 1440, 1760], ['jog 4', EX[0], EW[1], 1760, 1920],
    ['run 5', EX[0], EX[1], 1920, 2240],
  ];
  for (const [nm, x1, x2, y1, y2] of W)
    roadFlat(`causeway E weave ${nm}`, x1, x2, yA + y1, yA + y2, ZB);
  if (yA + 2240 !== cwY[7]) throw new Error('weave y-budget does not close on J4');
}

roadFlat('causeway J4 merge', -CW_LAND, CW_LAND, cwY[7], cwY[8], ZB);
// F — the approach, and then a FLARE into the citadel gate.
//
// THE FLARE IS A BUG FIX, not decoration (lint_tod_causeway, 2026-08-23). The
// gate opening is GATE_HALF*2 = 256 wide; the road is 160 wide with rails out to
// +/-100. That left ~28 units of open hall floor on EACH side of the doorway,
// inside the opening, guarded by nothing — walk into the citadel a little wide
// and you drop 19,000 units. Nothing in the .map said so and the road's own rail
// pass could not see it, because the hole was not on the road: it was on the
// hall's floor, one column past where the road stopped.
//
// So the mouth widens to meet the opening. The rail pass then guards the flare's
// own flanks and the two gap columns become deck. The side rails overlap the
// gate posts by ~12 units, which is fine — the CSG merges them and a rail dying
// into a gate post is what it should look like anyway.

roadFlat('causeway F approach', -CW_HALF, CW_HALF, cwY[8], cwY[9] - 160, ZB);
roadFlat('causeway F gate flare', -CW_FLARE, CW_FLARE, cwY[9] - 160, cwY[9], ZB);

const CW_STATS = roadEmit();
const CW_WALK = CW_STATS.walk;   // shortest walk, terrace mouth -> citadel mouth

// PORTAL FRAMES on the three on-axis stretches — the milestones you run through,
// and the only three places where the whole party is guaranteed to be in one lane.
// v12: each portal carries its own x-offset now — portal 2 stands at the
// NARROWS' pinched width (posts riding the shoulder-rail line at +-80), so the
// frame itself announces the squeeze; 1 and 3 keep the full road width.
const CW_PORTALS = [
  { y: (cwY[0] + cwY[1]) / 2, xo: CW_HALF + PARA, m: MAT.crownFascia },       // mid gate-run
  { y: (cwY[4] + cwY[5]) / 2, xo: CW_PLANK_HALF + PARA, m: MAT.crownFascia }, // over the narrows pinch
  // THE LAST PORTAL IS GOLD, NOT CYAN, because it is not on the road any more.
  // Measured 2026-08-25: portal 3 stands at y 7344-7376, and the crown's band
  // inner face is at 7328 — so the third portal is INSIDE THE CROWN'S THROAT,
  // 16 units past the wall, in the courtyard between the rim and the hall gate.
  // In cyan it was the brightest object in the arrival shot and the only foreign
  // hue in the composition, sitting exactly on the map's most important framing
  // moment. The road's language is cyan and the crown's is gold; the colour
  // change IS the arrival, so the portal that stands inside the crown wears the
  // crown's colour. The first two keep the road's.
  { y: (cwY[8] + cwY[9]) / 2, xo: CW_HALF + PARA, m: MAT.crownGold },
];
CW_PORTALS.forEach(({ y: yp, xo, m }, k) => {
  cbox(`causeway portal ${k + 1} post W`, -xo - 24, -xo, yp - 16, yp + 16, ZB, ZB + 224, m);
  cbox(`causeway portal ${k + 1} post E`, xo, xo + 24, yp - 16, yp + 16, ZB, ZB + 224, m);
  cbox(`causeway portal ${k + 1} lintel`, -xo - 24, xo + 24, yp - 16, yp + 16, ZB + 224, ZB + 256, m);
});

// THE AVENUE (v12) — four PAIRS of jewelled gold pylons floating in the void
// beside the road: two flanking the gate-run (visible from the terrace all
// game, through the sealed gate — the road advertises itself), two flanking
// the narrows' throats. A ceremonial avenue is the oldest scale-rhythm trick
// there is: passing identical markers is what makes 7,000 units FEEL like
// 7,000 units. They hang bottomless over the drop — bead below, head above,
// both WIDER than the shaft (the pendilia rule: nothing narrows to its tip).
// PLACEMENT RULES — ASSERTED below, not just written down (the CW_FLARE block
// records what happens to prose rules in this section: "violated within the
// hour"):
//   * x +-360: the nearest pylon FACE (head/collar at |x| 288) is 188 units
//     from the widest rail cap face (x 100) — but distance is NOT what makes
//     them unreachable: every derived rail carries a 168-tall clip cap
//     (RAIL_H 56 + RAIL_CAP_H 112, crail()), so no jump can even be STARTED
//     toward a pylon from any deck. The gap is hygiene, not the guarantee.
//   * y clear of every junction landing AND of the landing-edge rail columns
//     (a pylon overlapping a derived rail would CSG-weld into it). Tightest
//     today: 20 units to the J2-north / J3-south rail columns.
//   * every _tinted/_tinted_edge box is >64 tall in z, so the lint can never
//     class a pylon slab as an unguarded floor node hanging over the void.
//   * labels start with neither crown/mast (crownBB stays the circlet's) nor
//     causeway/terrace (the lint's road bucket stays pure road) — which also
//     means NO EXISTING GATE SEES A PYLON: not 5f.9, not the sky-seal bb, not
//     the lint (non-floor solids). Hence the assert below is the only guard.
// Sapphire jewels, not ruby: blue is the ROAD's language (cyan portals, cyan
// deck glow) — the colour change at the mouth stays the arrival cue.
const PYLON_HALF = 72;   // the widest tier (the head)
function avenuePylon(tag, px, py) {
  // THE ONE PYLON GATE: no pylon may come within one grid column (ROAD_G) of
  // any declared road cell — the rails and their caps live in exactly that
  // one column outside each deck edge, so "clear of cell+ROAD_G" IS "clear of
  // every rail the pass can ever derive". Fires on any future nudge of
  // CW_LAND, the span budget, pylon y's, or PYLON_HALF.
  for (const c of roadCells)
    if (px + PYLON_HALF > c.x1 - ROAD_G && px - PYLON_HALF < c.x2 + ROAD_G &&
        py + PYLON_HALF > c.y1 - ROAD_G && py - PYLON_HALF < c.y2 + ROAD_G)
      throw new Error(`avenue pylon at (${px},${py}) fouls road cell "${c.tag}" or its rail column`);
  cbox(`${tag} bead`, px - 64, px + 64, py - 64, py + 64, TOP2 - 384, TOP2 - 288, MAT.jewelSapphire);
  cbox(`${tag} shaft`, px - 40, px + 40, py - 40, py + 40, TOP2 - 288, TOP2 + 416, MAT.crownGold);
  cbox(`${tag} collar`, px - 64, px + 64, py - 64, py + 64, TOP2 - 16, TOP2 + 64, MAT.crownBrass);
  cbox(`${tag} head`, px - 72, px + 72, py - 72, py + 72, TOP2 + 416, TOP2 + 496, MAT.crownGold);
  cbox(`${tag} pip`, px - 48, px + 48, py - 48, py + 48, TOP2 + 496, TOP2 + 576, MAT.jewelSapphire);
}
for (const py of [640, 960, 3792, 4208])
  for (const sx of [-1, 1])
    avenuePylon(`avenue pylon y${py}${sx > 0 ? 'E' : 'W'}`, sx * 360, py);

// The road's own extremes, for the zone volume. DERIVED — a volume that misses
// a piece of road leaves it outside roof_zone, i.e. no spawns and no zone logic
// on that piece, which is invisible until somebody plays it.
const CW_XMIN = Math.min(...roadCells.map(c => c.x1)) - PARA - 64;
const CW_XMAX = Math.max(...roadCells.map(c => c.x2)) + PARA + 64;
const CW_ZMIN = Math.min(...roadCells.map(c => c.z)) - SLAB - 64;
const CW_ZMAX = Math.max(...roadCells.map(c => c.z)) + 400;
// Y from the DECK cells only — the two portals are the terrace and the hall
// floor, which belong to their own volumes. This used to be the literals
// TER_Y2..HS while x and z were derived, so a switchback that left that band
// would have landed in NO ZONE AT ALL: no risers, get_zone_from_position
// undefined so every boss spawn candidate there rejected, and no zone logic
// ever seeing a player standing on it. Nothing would have said so.
const CW_YMIN = Math.min(...roadCells.filter(c => c.deck).map(c => c.y1));
const CW_YMAX = Math.max(...roadCells.filter(c => c.deck).map(c => c.y2));

// THE SKY ENCLOSURE IS DERIVED FROM THE HALL, NOT FROM THE ROAD. SKY_IN is
// max(2900, HN + 384), so it follows CW_LEN through HS -> HN — but only in y.
// A road that swung far enough sideways, or a crest tall enough, would poke
// through the enclosure and leave a hole in the world that no geometry check
// here would notice. Cheap to assert, so assert it.
if (Math.max(-CW_XMIN, CW_XMAX) + 256 > SKY_IN)
  throw new Error(`causeway reaches x ${CW_XMAX} but the sky wall is at ${SKY_IN}`);
if (CW_ZMAX + 256 > SKY_TOP)
  throw new Error(`causeway reaches z ${CW_ZMAX} but the sky ceiling is at ${SKY_TOP}`);

// PUBLIC to the zone code below. Every point is on a piece of road, at that
// piece's own height — placed BY SHAPE, never by fraction of length. Half this
// road is no longer at x=0 and no longer at TOP2, and a fractional point would
// hang in mid-air or bury itself under a crest. Flats only: a riser on a stair
// tread surfaces a zombie mid-flight.
function causewayRunPoints() {
  return roadPieces.filter(p => p.kind === 'flat').map(p => cpt(p.cx, p.cy, p.cz));
}
// ...and the same points in the CROWN FRAME, unmirrored. The only caller is the
// light pass, which wraps every point in CL() and applies cpt() itself, so a
// mirrored value here would be double-mirrored. The name says "crownFrame"
// because the two functions above and below differ ONLY in whether cpt() has
// been applied, and at CM=+1 — the only parity anyone has generated — they
// return identical numbers. Anyone adding a second consumer (FX emitters,
// ambient sound origins, debug markers) would reach for whichever name looked
// convenient and be right half the time, in the frame nobody tests.
function causewayLightPointsCrownFrame() {
  return roadPieces.filter(p => p.kind === 'flat').map(p => [p.cx, p.cy, p.cz]);
}
function causewayPortalPoints() { return CW_PORTALS.map(p => cpt(0, p.y, TOP2)); }

// --- 5d. CROWN HALL: the citadel ---------------------------------------------
// THIS IS NOW THE INNER CHAMBER OF THE CIRCLET, not the building. Section 5f
// wraps a 4096 x 3264 x 6592 gold crown around everything below. The hall's
// floor, walls, gate, dais, sconces and extraction pad are UNCHANGED in
// position (user 2026-08-25: "We dont need to edit the floor of the room or
// space") — only their materials moved, from blue to velvet-and-gold, because
// the inside of a crown is what this room is now.
cbox('crown hall floor', -HW, HW, HS, HN, TOP2 - SLAB, TOP2, MAT.ground);

// THE UNDERBELLY IS THE MAP'S MOST-SEEN SURFACE AND IT USED TO BE INVISIBLE.
// The old three ziggurat tiers + gravity core were MAT.ground (dark_blue_tinted)
// — within a few percent of the atmosphere's fog colour — so from the base arena
// they rendered as a black square (see docs/crown_now_under.png). They are gone.
// The velvet cap here and the ten-tier gold/brass skirt in 5f replace them: from
// below you now look up the inside of a banded cone, which is the "radiate
// crown" read and the thing that actually carries the silhouette.
cbox('crown cap velvet', -832, 832, HYC - 832, HYC + 832, TOP2 + CR_ERM_Z1, TOP2 - 112, MAT.crownVelvet);
cbox('crown cap fillet', -856, 856, HYC - 856, HYC + 856, TOP2 - 112, TOP2 - SLAB, MAT.crownGold);

// walls — run BETWEEN the gate posts (no overlapping solids). VELVET now: they
// are invisible from outside once the band exists, but they are the whole
// interior of the hold-out arena, and purple-and-gold is what the inside of a
// crown looks like.
const WZ1 = TOP2, WZ2 = TOP2 + HWALL_H;
cbox('crown wall S west', -(HW - CTOWER), -GATE_HALF - POST_W, HS, HS + HWALL, WZ1, WZ2, MAT.crownVelvet);
cbox('crown wall S east', GATE_HALF + POST_W, HW - CTOWER, HS, HS + HWALL, WZ1, WZ2, MAT.crownVelvet);
cbox('crown gate lintel', -GATE_HALF, GATE_HALF, HS, HS + HWALL, TOP2 + GATE_H, WZ2, MAT.crownVelvet);
cbox('crown wall N', -(HW - CTOWER), HW - CTOWER, HN - HWALL, HN, WZ1, WZ2, MAT.crownVelvet);
cbox('crown wall W', -HW, -HW + HWALL, HS + CTOWER, HN - CTOWER, WZ1, WZ2, MAT.crownVelvet);
cbox('crown wall E', HW - HWALL, HW, HS + CTOWER, HN - CTOWER, WZ1, WZ2, MAT.crownVelvet);
// the wall corners the old corner towers used to fill. They were 192-square
// stacks that narrowed 192->144->96->40; a shape that narrows to a point is a
// SPIRE, and spires are the castle token this redesign exists to kill. The
// corner posts stay (the wall needs closing) but they are plain velvet mass now
// and the crown's actual points live out on the ring, 1888 units further out.
for (const [sx, sy, tag] of [[-1, HS, 'SW'], [1, HS, 'SE'], [-1, HN - CTOWER, 'NW'], [1, HN - CTOWER, 'NE']])
  cbox(`crown wall corner ${tag}`, sx > 0 ? HW - CTOWER : -HW, sx > 0 ? HW : -(HW - CTOWER), sy, sy + CTOWER, WZ1, WZ2, MAT.crownVelvet);
// gold cornice band, 16 proud of the outer faces, top 64 of the wall. It only
// reads from INSIDE now (the band hides the hall completely from outside), so
// it went from cyan to a glowing gold seam.
cbox('crown cornice S', -HW - 16, HW + 16, HS - 16, HS, WZ2 - 64, WZ2, MAT.crownGold);
cbox('crown cornice N', -HW - 16, HW + 16, HN, HN + 16, WZ2 - 64, WZ2, MAT.crownGold);
cbox('crown cornice W', -HW - 16, -HW, HS, HN, WZ2 - 64, WZ2, MAT.crownGold);
cbox('crown cornice E', HW, HW + 16, HS, HN, WZ2 - 64, WZ2, MAT.crownGold);

// the GATE: gold posts flanking the opening. The two 32->20 spires that used to
// stand on them subtended 0.05 and 0.6 degrees from the base arena — 1.5 px and
// half a pixel — i.e. they were never visible from anywhere in the map. Deleted.
cbox('crown gate post W', -GATE_HALF - POST_W, -GATE_HALF, HS - 24, HS + HWALL + 24, TOP2, WZ2 + 64, MAT.crownGold);
cbox('crown gate post E', GATE_HALF, GATE_HALF + POST_W, HS - 24, HS + HWALL + 24, TOP2, WZ2 + 64, MAT.crownGold);

// interior: the uplink dais (unchanged since v10 — the spire's ASCEND
// teleporter stands on it, tod_spire_data::ascension_pad_org)...
cbox('uplink dais', -DAIS, DAIS, HYC - DAIS, HYC + DAIS, TOP2, TOP2 + DAIS_H, MAT.crownRing);

// ...and THE BASILICA (v16.35, 2026-09-02). User: the hall was "quite open
// and the spots where ammo crate and pap and alter are odd and not intuitive
// ... less open ... organizes things ... enhances the room", with one rule:
// "dont change the overall size or outside of functionality". So the floor,
// the walls, the gate, the dais and every zone box are byte-identical to v12;
// this block only FURNISHES the inside. Plan, before/after drawings and the
// options rejected: docs/70_crown_hall_basilica.md.
//
// THE PLAN IN ONE LINE: gate -> nave -> crossing -> sanctuary. Two pier lines
// at x +-NAVE_X make a 768-wide nave and two 304-clear aisles; the two upgrade
// shrines (HEAVENLY GIFT ALTAR west, PACK-A-PUNCH east) face each other across
// the dais at the crossing under gold canopies; the ammo crate stays in the
// east aisle one bay inside the gate; the extraction pad rises on a two-step
// sanctuary in front of a reredos on the north wall. NOTHING IS ROOFED — the
// crown overhead is why this room exists — every piece stops at +248 under a
// 576 wall, and the one tall object (the reredos, +456 with its monde) stands
// against the far wall where it closes the axis instead of the sky.
//
// THE OLD FURNITURE IS GONE ON PURPOSE: the four +-448 pylon plinths (v12) are
// replaced by the colonnade, and the 1u glowing ring at +-632 — whose WEST
// band sat under the altar's trigger origin for three months and killed its
// prompt (v16.27, memory trigger-origin-under-decal) — by the carpet seams.
//
// CONTRACTS KEPT (read _tod_finale / _tod_spire before moving anything here):
//   * hall_center + the 160 gather ring (gather_spot): all four seats land on
//     open nave floor; the two on the transept seams stand on 1u walk-over.
//   * the dais: untouched (ASCEND teleporter + trigger, the hound spawner).
//   * hall risers (+-560, HS+280 / HN-280): open aisle bays; the nearest pier
//     base ends at x 440, the sanctuary at x 320, the canopies are overhead.
//   * siege_panzer_org moves 100u toward the axis (crown-data emission) to
//     keep clear floor round the drop — TOD_BOSS_CLEARANCE is boss-to-boss,
//     nothing in the director checks boss-to-geometry for us.
//   * hall_pillar_orgs (the count-in glow hosts) ride the FOUR CROSSING PIERS,
//     above the beam (+232) and below every light.
//   * exfil_org's z is PAD_TOP, emitted from the same constant as the pad.
//   * lint_tod_geometry: every level change is 16 (STEP_MAX 18, no rails
//     needed) and every OVERHEAD piece — beams, capitals, canopies — is PLAIN
//     gold, never a tinted material: the lint classes a <=64-thick tinted slab
//     as a DECK and would flood a "floor" at +216. The sanctuary tiers are
//     tinted ON PURPOSE (walkable). Pier bases are plain gold: a 24-tall
//     BLOCK, not a step.
//   * every vendor trigger origin floats (v16.27), so a 1u seam under a
//     machine's approach can no longer kill its prompt.
//   * no two solids overlap: beam segments run BETWEEN capitals, seams stop at
//     each other's edges, the canopy rests ON the pilasters and panel.
const NAVE_X   = 384;                                   // pier line: nave 768, aisles 304 clear (424 -> 728)
const PIER_Y   = [-632, -408, -184, 184, 408, 632].map(d => HYC + d);   // 7976 8200 8424 | 8792 9016 9240
const PIER_H   = 176, PIER_CAP = 40;                    // ruby shaft to +176; gold capital = the beam depth
const BEAM_Z1  = TOP2 + PIER_H, BEAM_Z2 = BEAM_Z1 + PIER_CAP;   // +176 .. +216
const SHR_Y1   = HYC - 112, SHR_Y2 = HYC + 112;         // the shrine bay (224) inside the 288-clear crossing gap
const PIL_W    = 32;                                    // wall pilasters framing each shrine bay
const CAN_Z1   = BEAM_Z2, CAN_Z2 = BEAM_Z2 + 32;        // canopy +216 .. +248, resting on the pilasters
const SANC_Y1  = HN - HWALL - 384;                      // sanctuary tier 1 starts here (8952)
const SANC_X1  = 320, SANC_X2 = 280;                    // tier 1 / tier 2 half-widths (clear of the pier bases at 328)
const PAD_TOP  = 40;                                    // the pad's top over TOP2 — exfil_org() below reads THIS
const SEAM_W   = 24, SEAM_X = 300;                      // the nave carpet seams, 24 wide at x +-300
const WALL_IN  = HW - HWALL;                            // 728, the long walls' inner face
const ZS1 = TOP2, ZS2 = TOP2 + 1;                       // every seam: 1u, walk-over (the lounge pad-ring precedent)

// the colonnade: 12 piers (gold base / ruby shaft / gold capital) and the beam
for (const sx of [-1, 1]) {
  const cx = sx * NAVE_X, tag = sx < 0 ? 'W' : 'E';
  PIER_Y.forEach((py, i) => {
    cbox(`crown hall pier ${tag}${i + 1} base`, cx - 56, cx + 56, py - 56, py + 56, TOP2, TOP2 + 24, MAT.crownGold);
    cbox(`crown hall pier ${tag}${i + 1} shaft`, cx - 40, cx + 40, py - 40, py + 40, TOP2 + 24, BEAM_Z1, MAT.jewelRuby);
    cbox(`crown hall pier ${tag}${i + 1} capital`, cx - 52, cx + 52, py - 52, py + 52, BEAM_Z1, BEAM_Z2, MAT.crownGold);
    if (i < PIER_Y.length - 1) {
      const a=py+52,b=PIER_Y[i+1]-52;
      for(let k=0;k<8;k++) {
        const ring=t=>{const y=a+(b-a)*t,z=BEAM_Z1+48*Math.sin(Math.PI*t);
          return [[cx-24,y,z],[cx+24,y,z],[cx+24,y,z+PIER_CAP],[cx-24,y,z+PIER_CAP]];};
        crownLoft(`crown hall arcade ${tag}${i+1}-${k+1}`,ring(k/8),ring((k+1)/8),MAT.crownGold);
      }
    }
  });
  // the shrine bay: two wall pilasters, a glowing panel between them behind
  // the machine, and a canopy spanning wall -> pier line over it. The machine
  // anchors (station_org west, the PaP prefab east) sit at HYC, 64 off the
  // wall face — the same standoff both have used since 2026-08-28.
  const wx1 = sx < 0 ? -WALL_IN : WALL_IN - PIL_W, wx2 = wx1 + PIL_W;
  cbox(`crown hall shrine ${tag} pilaster S`, wx1, wx2, SHR_Y1 - PIL_W, SHR_Y1, TOP2, BEAM_Z2, MAT.crownGold);
  cbox(`crown hall shrine ${tag} pilaster N`, wx1, wx2, SHR_Y2, SHR_Y2 + PIL_W, TOP2, BEAM_Z2, MAT.crownGold);
  const px1 = sx < 0 ? -WALL_IN : WALL_IN - 4, px2 = px1 + 4;
  cbox(`crown hall shrine ${tag} panel`, px1, px2, SHR_Y1, SHR_Y2, TOP2 + 32, BEAM_Z2, MAT.crownGoldSeam);
  const cx1 = sx < 0 ? -WALL_IN : NAVE_X + 40, cx2 = sx < 0 ? -(NAVE_X + 40) : WALL_IN;
  cbox(`crown hall shrine ${tag} canopy`, cx1, cx2, SHR_Y1 - PIL_W, SHR_Y2 + PIL_W, CAN_Z1, CAN_Z2, MAT.crownGold);
}

// the sanctuary: two 16-unit tiers (walkable, tinted on purpose), the pad on
// top, and the reredos closing the axis on the north wall — brass field (the
// dark foil the gold reads against), gold frame 8 proud, ruby stone 16 proud,
// gold crest and a ruby monde. Everything stays under the cornice (+512).
cbox('crown hall sanctuary tier 1', -SANC_X1, SANC_X1, SANC_Y1, HN - HWALL, TOP2, TOP2 + 16, MAT.crownGoldPanel);
cbox('crown hall sanctuary tier 2', -SANC_X2, SANC_X2, SANC_Y1 + 40, HN - HWALL, TOP2 + 16, TOP2 + 32, MAT.crownGoldPanel);
cbox('extraction pad', -EXFIL_HALF, EXFIL_HALF, EXFIL_Y - EXFIL_HALF, EXFIL_Y + EXFIL_HALF, TOP2 + 32, TOP2 + PAD_TOP, MAT.exfilPad);
const RER_Y2 = HN - HWALL, RER_Y1 = RER_Y2 - 32;
cbox('crown hall reredos field', -SANC_X2, SANC_X2, RER_Y1, RER_Y2, TOP2 + 32, TOP2 + 352, MAT.crownBrass);
cbox('crown hall reredos jamb W', -SANC_X2, -SANC_X2 + 24, RER_Y1 - 8, RER_Y1, TOP2 + 32, TOP2 + 352, MAT.crownGold);
cbox('crown hall reredos jamb E', SANC_X2 - 24, SANC_X2, RER_Y1 - 8, RER_Y1, TOP2 + 32, TOP2 + 352, MAT.crownGold);
cbox('crown hall reredos sill', -SANC_X2 + 24, SANC_X2 - 24, RER_Y1 - 8, RER_Y1, TOP2 + 32, TOP2 + 56, MAT.crownGold);
cbox('crown hall reredos head', -SANC_X2 + 24, SANC_X2 - 24, RER_Y1 - 8, RER_Y1, TOP2 + 328, TOP2 + 352, MAT.crownGold);
cbox('crown hall reredos stone', -64, 64, RER_Y1 - 16, RER_Y1, TOP2 + 112, TOP2 + 272, MAT.jewelRuby);
cbox('crown hall reredos crest', -128, 128, RER_Y1, RER_Y2, TOP2 + 352, TOP2 + 416, MAT.crownGold);
// 72 tall, NOT 40: jewelRuby is a tinted_edge material, and the geometry lint
// classes any tinted brush <= 64 thick as a DECK — a 40-tall monde read as a
// walkable floor at +456 with six unguarded edges. Taller than MAX_SLAB it is
// a solid again. Top +488, still under the cornice (+512).
cbox('crown hall reredos monde', -32, 32, RER_Y1 + 8, RER_Y2, TOP2 + 416, TOP2 + 488, MAT.jewelRuby);

// Upper wall arcades carry the interior's architectural scale. Recessed dark
// bays framed by gold ribs; all begin above +288, clear of vendors and players.
for(const sx of [-1,1]) {
  const x=sx*(WALL_IN-5);
  for(const py of [HYC-480,HYC+480]) {
    cbox(`crown hall upper panel ${sx} ${py}`,Math.min(x,x+sx*4),Math.max(x,x+sx*4),py-144,py+144,TOP2+288,TOP2+480,MAT.crownBrass);
    for(const sy of [-1,1]) {
      const y=py+sy*144;
      // The end bays meet solid corner piers. Trim inside those piers is
      // completely buried; keep only the exposed inner jamb of each bay.
      if(y-10<HS+CTOWER || y+10>HN-CTOWER)continue;
      cbox(`crown hall shrine frame pilaster ${sx} ${py} ${sy}`,
        sx<0?-WALL_IN:WALL_IN-12,sx<0?-WALL_IN+12:WALL_IN,
        y-10,y+10,TOP2+288,TOP2+480,MAT.crownGold);
    }
  }
}

// the floor: a processional carpet in the map's own wayfinding language (the
// lounges' spokes, the plaza's traces) — two nave seams, a threshold bar at
// the gate end, a bar at the sanctuary foot, a rim round the dais, a transept
// seam to each shrine (split where it crosses a nave seam) and a spoke to the
// crate (after CRATE_ORG below).
cbox('crown hall seam nave W', -SEAM_X - SEAM_W / 2, -SEAM_X + SEAM_W / 2, HS + HWALL + 104, SANC_Y1 - 24, ZS1, ZS2, MAT.crownRing);
cbox('crown hall seam nave E', SEAM_X - SEAM_W / 2, SEAM_X + SEAM_W / 2, HS + HWALL + 104, SANC_Y1 - 24, ZS1, ZS2, MAT.crownRing);
cbox('crown hall seam threshold', -SEAM_X - SEAM_W / 2, SEAM_X + SEAM_W / 2, HS + HWALL + 80, HS + HWALL + 104, ZS1, ZS2, MAT.crownRing);
cbox('crown hall seam sanctuary foot', -SEAM_X - SEAM_W / 2, SEAM_X + SEAM_W / 2, SANC_Y1 - 24, SANC_Y1, ZS1, ZS2, MAT.crownRing);
cbox('crown hall dais rim S', -160, 160, HYC - 160, HYC - 136, ZS1, ZS2, MAT.crownRing);
cbox('crown hall dais rim N', -160, 160, HYC + 136, HYC + 160, ZS1, ZS2, MAT.crownRing);
cbox('crown hall dais rim W', -160, -136, HYC - 136, HYC + 136, ZS1, ZS2, MAT.crownRing);
cbox('crown hall dais rim E', 136, 160, HYC - 136, HYC + 136, ZS1, ZS2, MAT.crownRing);
cbox('crown hall seam transept W1', -(SEAM_X - SEAM_W / 2), -160, HYC - SEAM_W / 2, HYC + SEAM_W / 2, ZS1, ZS2, MAT.crownRing);
cbox('crown hall seam transept W2', -600, -(SEAM_X + SEAM_W / 2), HYC - SEAM_W / 2, HYC + SEAM_W / 2, ZS1, ZS2, MAT.crownRing);
cbox('crown hall seam transept E1', 160, SEAM_X - SEAM_W / 2, HYC - SEAM_W / 2, HYC + SEAM_W / 2, ZS1, ZS2, MAT.crownRing);
cbox('crown hall seam transept E2', SEAM_X + SEAM_W / 2, 600, HYC - SEAM_W / 2, HYC + SEAM_W / 2, ZS1, ZS2, MAT.crownRing);

// THE HALL AMMO CRATE (v12, user 2026-08-26: "we need an ammo crate in that
// room"). Same two-sided contract as the four breather crates: the MODEL and
// its use-trigger are script-spawned by _tod_ammo_crate.gsc (which reads the
// origin from GENERATED _tod_crown_data.gsc — see crown_crate_org() at the
// bottom of this file, the door-data no-drift pattern), and the generator
// contributes ONLY this invisible collision clip, because the xmodel ships
// with no collision at all (the whole story: the breather crate block in
// section 4). Position: EAST wall, mirroring the upgrade station on the west
// wall — measured clear of the wall inner face (728: model bbox reaches
// ~717.8, 10u standoff), the sconce column above (z-gap ~137), the exfil
// trigger, the gather ring, the hall risers AND the east glowing ring inlay
// (inlay E ends at x=632; the model bbox starts at ~634.5 — the review caught
// the first cut at 672 nicking the glow strip by 1.5u). CRATE_YAW_W = facing
// west, into the hall (the mirrored box runs y 8263..8327 — still clear of the
// wall panel and the seam spoke, both of which are decoration on the wall).
// Bounds are the breather crate's measured yaw-270 occupancy translated to
// (672, 8308) with the same 4u inset; under CM=-1 the point-mirror of this box
// equals the 180-degree-rotated crate exactly, so clip and model stay welded at
// either parity. v17.37: box AND yaw now come from crateBox()/CRATE_YAW_W, so
// the 26u mesh offset can no longer be left behind by a facing change. THE LABEL MUST END "ammo crate body" —
// lint_tod_geometry's MODEL_CLIP_COLUMNS whitelist matches on it.
// v19.71 (the perch pass): FLUSH against the crate panel, 676 -> 686 — the body's back
// edge sat 11 off the panel (WALL_IN - 4 = 724); now 1. Its perch cap buries through the
// panel into the wall.
const CRATE_ORG = [686, 8308];
const CRATE_YAW = CRATE_YAW_W;   // v17.37: was 270 — see the crate convention
{
  const cb = crateBox(CRATE_ORG[0], CRATE_ORG[1], CRATE_YAW);
  cbox('crown hall ammo crate body', cb.x1, cb.x2, cb.y1, cb.y2, TOP2, TOP2 + CRATE_BOX_H, MAT.clip);
  const wb = ALL_BOXES[ALL_BOXES.length - 1];   // the body as emitted (world frame, either parity)
  crateCap('crown hall ammo crate', { x1: wb.x1, x2: wb.x2, y1: wb.y1, y2: wb.y2 }, TOP2, cyaw(CRATE_YAW));
}
// v16.35: the crate's bay in the basilica — a low glow panel on the wall
// behind it (below the sconce row at +200) and the carpet spoke from the east
// nave seam to its approach. Both clear the clip body above (panel x 724..728
// vs body to 714; spoke ends at x 600 vs body from 639).
cbox('crown hall crate panel', WALL_IN - 4, WALL_IN, CRATE_ORG[1] - 32, CRATE_ORG[1] + 32, TOP2 + 24, TOP2 + 120, MAT.crownGoldSeam);
cbox('crown hall seam crate spoke', SEAM_X + SEAM_W / 2, 600, CRATE_ORG[1] - SEAM_W / 2, CRATE_ORG[1] + SEAM_W / 2, ZS1, ZS2, MAT.crownRing);

// --- 5e. THE MAST: the tower's own spire on the core top (axis-symmetric) ----
{
  let z = TOP2;
  const MAST_MATS = [MAT.crownBand, MAT.crownBand, MAT.roofPara, MAT.crownFascia, MAT.crownFascia];
  MAST_TIERS.forEach(([w, h], i) => {
    addBox(`mast tier ${i + 1}`, -w / 2, w / 2, -w / 2, w / 2, z, z + h, MAST_MATS[i]);
    z += h;
  });
  // THE TOWER WEARS A SMALL CROWN (v11). Eight points around the mast's
  // shoulder, standing on tier 1's rim at TOP2+320 — which is 320 above the
  // core top, so nothing can be walked on or blocked. This is the one piece of
  // the composition that sits directly over the base-arena player's head, and
  // it is what makes the whole thing legible in a sentence: the tower wears a
  // small crown, and the citadel IS the crown. The red beacon at mast_tip_org()
  // is untouched — MAST_TOP must not move, _tod_finale.gsc puts a prop there.
  const MP = [[192, 0], [-192, 0], [0, 192], [0, -192], [136, 136], [-136, 136], [136, -136], [-136, -136]];
  MP.forEach(([px, py], i) => {
    addBox(`mast crown point ${i + 1} shaft`, px - 48, px + 48, py - 48, py + 48, TOP2 + 320, TOP2 + 704, MAT.crownGold);
    addBox(`mast crown point ${i + 1} head`, px - 88, px + 88, py - 88, py + 88, TOP2 + 704, TOP2 + 832, MAT.crownGold);
    addBox(`mast crown point ${i + 1} pip`, px - 32, px + 32, py - 32, py + 32, TOP2 + 832, TOP2 + 928, MAT.jewelRuby);
  });
}

// ---------------------------------------------------------------------------
// 5f. THE CIRCLET (v11) — the crown itself
// ---------------------------------------------------------------------------
// See the CIRCLET block up in the constants for WHY every number is what it is
// (the 384-unit legibility floor, the south-only occlusion, the underside being
// 60% of the pixels, and why light entities cannot help up here).
//
// True convex crown surfaces are decoded from their emitted planes by the
// preview, geometry lint, area meter and hidden-face audit (2026-09-15).
// Keep the gameplay floor and the causeway joins on their original grid.
// Decorative bevels carve inward; the road/sky asserts retain full envelopes.
//
// LINT CONTRACT for everything below (lint_tod_geometry.js):
//   * label everything `crown ...` — labels starting with `causeway`/`terrace`
//     land in the ROAD detachment bucket, which is gated at zero.
//   * plain colours are BLOCK and can never become floor at any size;
//     `_tinted`/`_tinted_edge` are DECK and become FLOOR at <= 64 thick in Z.
//   * the 20x20 column at (x in [0,20), y in [7840,7860)) is the lint's ONLY
//     working citadel reachability anchor (its fallback at y=9360 is already
//     blocked by `crown wall N`). Nothing may be put there above TOP2+18.
// ---------------------------------------------------------------------------

// One octagonal ring course, split into eight convex wall sectors. Band
// courses flare continuously from the previous course's top width. The south
// sector splits around the existing approach opening at its original height.
function crownCourse(tag, hx, hy, t, z1, z2, mat, mouthHalf) {
  const taper=/^crown band C/.test(tag)?CS(64):0;
  function sections(z,shrink) {
    const outer=crownOct(hx-shrink,hy-shrink,z,CR_CHAM);
    const inner=crownOct(hx-shrink-t,hy-shrink-t,z,CR_CHAM-t*(2-Math.SQRT2));
    return {outer,inner};
  }
  const lo=sections(z1,taper),hi=sections(z2,0);
  for(let i=0;i<8;i++) {
    const j=(i+1)%8;
    const face=r=>[r.outer[i],r.outer[j],r.inner[j],r.inner[i]];
    if(i===0 && mouthHalf) {
      for(const sign of [-1,1]) {
        const half=r=>{
          const f=face(r);
          if(sign<0){f[1]=[-mouthHalf,f[1][1],f[1][2]];f[2]=[-mouthHalf,f[2][1],f[2][2]];}
          else {f[0]=[mouthHalf,f[0][1],f[0][2]];f[3]=[mouthHalf,f[3][1],f[3][2]];}
          return f;
        };
        crownLoft(`${tag} face S ${sign<0?'west':'east'}`,half(lo),half(hi),mat);
      }
    } else crownLoft(`${tag} face ${i}`,face(lo),face(hi),mat);
  }
}

// cfleuron — cspike's opposite number. cspike can only make a NARROWING stack,
// and a shape that narrows to a point is a spire; spires are the single most
// castle-shaped thing in architecture and they are why the old crown read the
// way it did. A crown point is the other way round: a thin shaft carrying a
// head that is WIDER than the shaft. A cross pattee is literally named for its
// widening arms. Tier = [widthAlongFan, widthAcross, height, material].
function cfleuron(label, cx, cy, z0, tiers, fan) {
  let z = z0;
  let previous=null;
  tiers.forEach(([wf, wc, h, mat], i) => {
    const hx = (fan === 'x' ? wf : wc) / 2, hy = (fan === 'x' ? wc : wf) / 2;
    // Broad crown heads flare out from their shafts, then close through an
    // angled shoulder. No square shelf at the head/cap transition.
    const lower=(i===3 || i===4)?previous:[hx,hy];
    const ring=(a,b,z)=>{
      const bevel=Math.min(a,b)*0.24;
      return [[-a+bevel,-b],[a-bevel,-b],[a,-b+bevel],[a,b-bevel],[a-bevel,b],[-a+bevel,b],[-a,b-bevel],[-a,-b+bevel]].map(([x,y])=>[cx+x,cy+y,z]);
    };
    crownLoft(`${label} ${i+1}`,ring(...lower,z),ring(hx,hy,z+h),mat);
    previous=[hx,hy];
    z += h;
  });
  return z;
}

// --- 5f.1 the assertions that keep the circlet inside the world -------------
{
  // THE ROAD MUST SURVIVE. CR_HY is 1632 and not 1728 or 2048 for exactly one
  // reason: the south band has to land inside the causeway's F APPROACH, the
  // one stretch that is flat, on-axis, 160 wide and at TOP2. Anywhere else and
  // the ring would have to be pierced by three separate mouths through a fork
  // that is on stairs at three different heights.
  const y0 = CR_CY - CR_HY - CR_ERM, y1 = CR_CY - CR_HY + BAND_T;
  if (y0 <= cwY[8] || y1 >= cwY[9] - 160)
    throw new Error(`crown ring south band [${y0},${y1}] must lie inside the causeway F approach ` +
      `[${cwY[8]},${cwY[9] - 160}] — CR_HY ${CR_HY} puts it over a fork`);
  if (CR_MOUTH_HALF < CW_HALF + PARA + 40)
    throw new Error(`crown mouth half ${CR_MOUTH_HALF} would foul the road rails at ${CW_HALF + PARA}`);
  if (CR_MOUTH_Z2 - CR_MOUTH_Z1 < GATE_H)
    throw new Error('crown mouth is lower than the hall gate it leads to');
  // The ring must never touch the hall it surrounds — the user's constraint was
  // "We dont need to edit the floor of the room or space", and this is what
  // enforces it rather than hoping.
  if (CR_HX - BAND_T <= HW + 64)
    throw new Error(`crown ring inner face x ${CR_HX - BAND_T} does not clear the hall wall at ${HW}`);
  if (CR_CY - CR_HY + BAND_T >= HS - 64 || CR_CY + CR_HY - BAND_T <= HN + 64)
    throw new Error('crown ring inner face does not clear the hall in y');
  // The arches are scenery, not a ceiling.
  if (CR_TALL_TOP < HWALL_H + 1024)
    throw new Error('crown arches must clear the hall wall tops by 1024');
  // (The SEAL asserts live at the END of 5f — they measure the crown's real
  // bounding box, which does not exist yet at this point in the file.)
}

// --- 5f.2 the skirt: the surface the whole map actually looks at ------------
// The former stacked skirt is retired. The bell below uses continuous
// octagonal lofts and follows the existing crown envelope and pendant axis.
// SIGN-SYMMETRIC 16-SNAP for ornament-row u positions (the bell, and the
// ermine underside row in 5f.10). Math.round() rounds -53.5 to -53 but +53.5
// to +54, so a mirror-symmetric formula produced mirror-ASYMMETRIC positions —
// and the jewel pick keys on |u|/16, so the v12 first cut drew emerald west
// against ruby east on the one crown in the world that must be symmetric
// (adversarial review 2026-08-26).
const snapU = (x) => Math.sign(x) * Math.round(Math.abs(x) / 16) * 16;
// THE PENDILIA OWN THE STRAND LINES. The south cords (5f.8) hang at
// u = 0, +-3PT_X/8, +-3PT_X/4 (0 / 1014 / 2028 at CR_SCALE 1.4) and drop as
// far as z -1824 rel TOP2 — straight through the z-band of the tier-0 teeth,
// the tier-1 studs and the ermine underside row. The v12 first cut centred
// all three rows on u=0 and the centre cord passed clean through the centre
// ornament of each (review, same day). So every rim-height ornament row on
// the south face sits at the MIDPOINTS BETWEEN the strands instead:
// 3PT_X/16 and 9PT_X/16, which CS(368)/CS(1088) approximate within 8 units
// at any scale. Deeper tiers (2+) are below the longest cord and keep their
// own pitch. Four positions, symmetric by construction.
const SAFE_U = [-CS(1088), -CS(368), CS(368), CS(1088)];

{
  // THE RIBBED BELL — broad panels and eight structural ribs carry the
  // silhouette from below; brass reveals separate the panels at three levels.
  // An octagonal bell with continuous sloping faces. Three broad brass
  // reveals articulate its height without repeating a staircase silhouette.
  const profiles=[
    [1.00,CR_ERM_Z1],[0.94,CS(-960)],[0.80,CS(-1510)],
    [0.58,CS(-2080)],[0.34,CS(-2530)],[0.19,CR_SKIRT_BOT]
  ];
  const hx=CR_HX-CR_ERM,hy=CR_HY-CR_ERM;
  for(let i=0;i<profiles.length-1;i++) {
    const [fa,za]=profiles[i],[fb,zb]=profiles[i+1];
    crownLoft(`crown skirt swept shell ${i+1}`,
      crownOct(hx*fb,hy*fb,TOP2+zb,Math.min(hx,hy)*0.30*fb),
      crownOct(hx*fa,hy*fa,TOP2+za,Math.min(hx,hy)*0.30*fa),MAT.crownGoldPanel);
    // Eight substantial ribs follow the actual sloping surface and stay
    // attached at every joint. Bright edges remain legible against gold panels.
    const ra=crownOct(hx*fa,hy*fa,TOP2+za,Math.min(hx,hy)*0.30*fa);
    const rb=crownOct(hx*fb,hy*fb,TOP2+zb,Math.min(hx,hy)*0.30*fb);
    for(let k=0;k<8;k++) {
      const w=CS(44);
      const ring=p=>[[-w,-w],[w,-w],[w,w],[-w,w]].map(([x,y])=>[p[0]+x,p[1]+y,p[2]]);
      crownLoft(`crown skirt rib ${i+1}-${k}`,ring(rb[k]),ring(ra[k]),MAT.crownGold);
    }
    if(i>0 && i<4) crownLoft(`crown skirt reveal ${i}`,
      crownOct(hx*fa+CS(24),hy*fa+CS(24),TOP2+za-CS(32),Math.min(hx,hy)*0.30*fa),
      crownOct(hx*fa+CS(24),hy*fa+CS(24),TOP2+za+CS(32),Math.min(hx,hy)*0.30*fa),MAT.crownBrass);
  }

  // --- THE GIRANDOLE — the drop pendant --------------------------------------
  // The v11 core was a 544-square ruby cube: the natural focal point of the
  // entire climb, delivered at 1.4 degrees. It is now a proper chandelier
  // drop — collar, chain, a stepped ruby ORB (the monde trick, inverted),
  // a flaring gold coronet and a ruby drop-stone — hanging BELOW the bell's
  // throat, and it completes the crown's red vertical axis: beacon above,
  // great ruby front, girandole below. Every stage is WIDER than the stage
  // above where it matters (orb over chain, coronet over orb-foot, stone over
  // pip) — the pendilia rule, at architectural size. One light entity makes
  // the orb bloom the way the great ruby does; it is the third and LAST red
  // light the crown gets (the CL block counts all three) — the girandole
  // exists to be the climb's magnet, and the axis is complete at three.
  {
    const G = [
      // [half, height, material]  top -> tip
      [CS(184), CS(72), MAT.crownGold],     // collar, tucked under tier 10's floor
      [CS(104), CS(128), MAT.crownGold],    // the chain
      [CS(208), CS(112), MAT.jewelRuby],    // orb shoulder
      [CS(264), CS(240), MAT.jewelRuby],    // orb equator — the widest stage
      [CS(208), CS(112), MAT.jewelRuby],    // orb foot
      [CS(256), CS(64), MAT.crownGold],     // coronet — flares back OUT under the orb
      [CS(96), CS(88), MAT.crownGold],      // pip
      [CS(136), CS(112), MAT.jewelRuby],    // the drop stone — wider than its pip
    ];
    let z = TOP2 + CR_SKIRT_BOT;
    G.forEach(([h, hh, mat], i) => {
      cbox(`crown girandole ${i + 1}`, -h, h, CR_CY - h, CR_CY + h, z - hh, z, mat);
      z -= hh;
    });
  }
}

// --- 5f.3 the band: ermine rim, four flaring courses, the pearl rim ---------
// The FLARE is the move that stops this being a curtain wall. Band courses step
// OUTWARD going up — 1856 -> 1920 -> 1984 -> 2048, which is 192 of batter over
// 1216 of height, about 9 degrees — and the ermine below them is proud of even
// the topmost course. That gives the correct crown profile: a fur roll at the
// very bottom that is the widest line in the whole silhouette, a nipped waist
// above it, then a splay to the band's top edge. Plumb walls make castles.
crownCourse('crown ermine', CR_HX + CR_ERM, CR_HY + CR_ERM, BAND_T + CR_ERM,
  TOP2 + CR_ERM_Z1, TOP2 + CR_ERM_Z2, MAT.crownErmine);
// THE FOUR COURSES CLIMB THE VALUE LADDER, they do not just step outward.
// All four used to be crownGoldPanel, which meant the flare — the move the whole
// silhouette rests on — was invisible on any face: one material, one value, one
// plate. Every material in this pack is lit_emissive (self-lit), so a step in
// geometry produces NO shading difference on its own. Value has to be authored.
// Brass at the bottom against the white ermine, gold panel through the middle,
// bright plain gold at the top under the rim, so the band reads dark-to-light as
// it splays. The measured ladder is orange_tinted 5.8 / yellow_tinted 7.8 /
// yellow 13.5, which is a 2.3:1 spread across the band.
crownCourse('crown band C1', CR_HX - CS(192), CR_HY - CS(192), BAND_T,
  TOP2 + CR_ERM_Z2, TOP2 + CR_C1_Z, MAT.crownBrass);
crownCourse('crown band C2', CR_HX - CS(128), CR_HY - CS(128), BAND_T,
  TOP2 + CR_C1_Z, TOP2 + CR_C2_Z, MAT.crownGoldPanel, CR_MOUTH_HALF);
crownCourse('crown band C3', CR_HX - CS(64), CR_HY - CS(64), BAND_T,
  TOP2 + CR_C2_Z, TOP2 + CR_C3_Z, MAT.crownGoldPanel, CR_MOUTH_HALF);
crownCourse('crown band C4', CR_HX, CR_HY, BAND_T,
  TOP2 + CR_C3_Z, TOP2 + CR_C4_Z, MAT.crownGold);
// the pearl rim: thin, so it MUST be a plain colour (see the material rule)
crownCourse('crown rim', CR_HX + CS(48), CR_HY + CS(48), BAND_T + CS(48),
  TOP2 + CR_C4_Z, TOP2 + CR_RIM_Z, MAT.crownGold);
// TWO PROUD ASTRAGALS. A band this tall with nothing but jewels on it is a wall
// with jewels on it. These are the horizontal divisions every real circlet has,
// and they are the reason the flare reads as three distinct courses instead of
// one leaning surface. Under MAX_SLAB thick, so both MUST be a plain colour.
crownCourse('crown astragal lower', CR_HX - CS(96), CR_HY - CS(96), BAND_T + CS(48),
  TOP2 + CR_C1_Z - CS(32), TOP2 + CR_C1_Z + CS(48), MAT.crownGold, CR_MOUTH_HALF);
crownCourse('crown astragal upper', CR_HX + CS(16), CR_HY + CS(16), BAND_T + CS(48),
  TOP2 + CR_C3_Z - CS(32), TOP2 + CR_C3_Z + CS(32), MAT.crownGold);
// THE MOUTH'S JAMBS — and they were completely buried until 2026-08-25.
// Measured: the jamb (x 448..576, y 6912..7216) sat entirely INSIDE the
// frontispiece side panel (x 448..944, y 6912..7136), with their south faces on
// the SAME PLANE. So the element the design record credits with "turning a hole
// in the rim into a gate" was invisible, and where it was not invisible it was
// coplanar with a different material — a z-fight waiting for a driver to break
// the tie. The gate's edge had literally zero geometric relief; it was a change
// of material on a flat wall.
// They now stand CS(240) proud of the band and are wide enough to read, so the
// opening has a genuine 336-unit reveal. The frontispiece is pushed back behind
// them (see 5f.7) so no two faces share a plane.
// MP1 vs MP_DEEP — AND THIS DISTINCTION IS A ROAD SAFETY RULE, NOT A STYLE ONE.
// The first cut of the proud jamb used a single MP1 = CR_CY-CR_HY-CS(240) =
// 6672 for the whole family. The causeway's J4 LANDING is 960 wide (x +-480)
// and runs y 6720..6880 at TOP2 — so that put four 176-tall solid gold blocks
// ON WALKABLE DECK, straight through the landing's north guard rail.
// `lint_tod_geometry` CANNOT SEE THAT: its misplaced-wall check only fires on a
// `clip` brush with no visible solid beside it, and a visible solid just drops
// the node from `stand` silently — while the flood still walks the middle of a
// 960-wide landing, so reachability stays green too.
//   MP1     = 6912, flush with the ermine line. Anything reaching DOWN to the
//             road deck uses this: it is north of the landing (6880) and north
//             of the rail that caps it (6900).
//   MP_DEEP = 6672, the full 336 reveal. ONLY for elements whose bottom is well
//             clear of head height over that landing — the cap and the corbels,
//             both of which live above TOP2+368. That is what corbelling IS:
//             the gate's head oversails the threshold, the threshold stays clear.
// Section 5f.9 now asserts this rather than trusting it.
const MJ = CS(160), MP1 = CR_CY - CR_HY - CS(64), MP_DEEP = CR_CY - CR_HY - CS(240);
const MP2 = CR_CY - CR_HY + CS(144);
for (const sx of [-1, 1]) {
  cbox(`crown mouth jamb ${sx > 0 ? 'E' : 'W'}`,
    sx > 0 ? CR_MOUTH_HALF : -CR_MOUTH_HALF - MJ, sx > 0 ? CR_MOUTH_HALF + MJ : -CR_MOUTH_HALF,
    MP1, MP2, TOP2, TOP2 + CR_C4_Z, MAT.crownGold);
  // corbels in the mouth's top corners. They narrow the OPENING at the head
  // only — the centre headroom the road needs is untouched, and they sit well
  // above the deck so they can never read as a blocker in a road column.
  cbox(`crown mouth corbel ${sx > 0 ? 'E' : 'W'}`,
    sx > 0 ? CR_MOUTH_HALF - MJ : -CR_MOUTH_HALF, sx > 0 ? CR_MOUTH_HALF : -CR_MOUTH_HALF + MJ,
    MP_DEEP, MP2, TOP2 + CR_MOUTH_Z2 - CS(128), TOP2 + CR_MOUTH_Z2, MAT.crownGold);
}
// THE KEYSTONE IS DELETED (v11.2). It sat at x +-176, y from 6896, z 19936-20182
// — entirely behind `crown cullinan bezel` (x +-536, y from 6832, z 19952-20400),
// which is 64 units IN FRONT of it and covers it in x and z but for a 16-unit
// sliver. It was ~93% buried: bake cost for nothing. The Cullinan and its bezel
// already are the centrepiece over the mouth, which is what a keystone is for.
// A STEPPED PEDIMENT over the mouth. Three courses corbelling inward above the
// lintel, so the gate has a head instead of stopping dead at a flat soffit.
// It sits between the Cullinan and the front cross and ties the three into one
// vertical event on the centreline — which is the whole composition's axis.
for (let k = 0; k < 3; k++)
  cbox(`crown mouth pediment ${k + 1}`, -(CS(512) - k * CS(128)), CS(512) - k * CS(128),
    CR_CY - CR_HY - CS(32) - k * 16, CR_CY - CR_HY + CS(96),
    TOP2 + CR_C4_Z + k * CS(96), TOP2 + CR_C4_Z + (k + 1) * CS(96), MAT.crownGoldPanel);
// THE MOUTH'S LINING. The road runs the full band thickness through solid gold
// here, and without this the tunnel is the same flat gold as everything else.
// The glowing seam material turns it into a lit threshold you walk through —
// the one piece of the crown every player is guaranteed to see from arm's length.
{
  const y1 = CR_CY - CR_HY - CS(32), y2 = CR_CY - CR_HY + BAND_T + CS(96), LT = CS(24);
  for (const sx of [-1, 1])
    cbox(`crown mouth lining ${sx > 0 ? 'E' : 'W'}`,
      sx > 0 ? CR_MOUTH_HALF - LT : -CR_MOUTH_HALF, sx > 0 ? CR_MOUTH_HALF : -CR_MOUTH_HALF + LT,
      y1, y2, TOP2 + CR_MOUTH_Z1, TOP2 + CR_MOUTH_Z2, MAT.crownGoldSeam);
  // THICKER THAN MAX_SLAB, NOT 24, and that is a lint constraint rather than a
  // look: the glowing-seam family is DECK, and a DECK brush 64 thick or less
  // becomes a walkable floor surface — this one would be a floor node hanging
  // over the causeway with no guard on any edge. Over MAX_SLAB it is a wall.
  cbox('crown mouth soffit', -CR_MOUTH_HALF, CR_MOUTH_HALF, y1, y2,
    TOP2 + CR_MOUTH_Z2 - CS(80), TOP2 + CR_MOUTH_Z2, MAT.crownGoldSeam);
}

// --- 5f.4 the sixteen points ------------------------------------------------
// 8 tall crosses pattee alternating with 8 short fleurs-de-lis, sitting on the
// ring's wall centreline. Across the SOUTH FACE — the only face anybody ever
// sees from the tower — that reads, left to right:
//     TALL corner   short   FRONT CROSS   short   TALL corner
// Five teeth, alternating, with a dominant centre. That is a crown and nothing
// else. Above the rim strip there is NOTHING but points and sky: if the mass
// carried on up between the teeth they would read as buttresses.
const PT_X = CR_HX - BAND_T / 2, PT_Y = CR_HY - BAND_T / 2;
const PT_CX = CR_HX - CR_CHAM / 2 - CS(112), PT_CY = CR_HY - CR_CHAM / 2 - CS(112);  // on the chamfer's centreline
const PZ = TOP2 + CR_RIM_Z;
// [widthAlongFan, widthAcross, height, material] — note every head is WIDER
// than the shaft that carries it.
// The hierarchy is deliberate and survives any CR_SCALE: a tall head must beat
// a fleur head must beat the sky gap between them, or the rhythm across the
// face stops reading as alternating. At CR_SCALE 1.4 those are 896 / 784 /
// ~560 units — 2.3, 2.0 and 1.45 degrees from the base arena.
// THE PIP WAS A SPIRE AND IT SHIPPED THAT WAY. Measured on the generated .map,
// a tall point ran 400 -> 896 -> 496 -> 208 -> 320: a 4.3:1 collapse over 624
// units of height, which is exactly the cspike() silhouette this whole redesign
// was written to delete, rebuilt out of cfleuron(). Worse, 208 units subtends
// 0.54 degrees from the base arena — sitting right on the shimmer floor.
// The pip is now 400 (the width of the shaft it stands over) and the stone above
// it FLARES to 448, so the profile reads cap -> neck -> flaring stone. Nothing
// on this crown may narrow toward its own tip.
// The cap is BRASS, not gold panel: self-lit materials mean the head only reads
// as three parts if those parts are three different values.
// THE SHAFT IS BANDED, NOT ONE POST. A tall point's shaft is 1,888 units of
// dead rectangle, and from the terrace these are the dominant verticals in the
// frame. Because every material here is self-lit, a plain moulding ring on it
// would produce no value change at all — so the articulation IS a material
// change: gold / brass / gold, with the brass course slightly proud so it also
// breaks the outline. That replaces the old separate `collar` box, which was
// 40 units of relief in the same colour as the shaft and therefore invisible.
// The three heights must sum to TALL_SHAFT_H.
const TALL_SHAFT_H = CS(1344), TALL_HEAD_H = CS(384), TALL_CAP_H = CS(256), TALL_PIP_H = CS(192);
const SH_A = Math.round(TALL_SHAFT_H * 0.42 / 16) * 16;
const SH_B = TALL_SHAFT_H - 2 * SH_A;
const TALL_TIERS = [
  [CS(288), CS(352), SH_A, MAT.crownGold],
  [CS(320), CS(384), SH_B, MAT.crownBrass],
  [CS(288), CS(352), SH_A, MAT.crownGold],
  [CS(640), CS(512), TALL_HEAD_H, MAT.crownGold],
  [CS(352), CS(352), TALL_CAP_H, MAT.crownBrass],
  [CS(288), CS(288), TALL_PIP_H, MAT.crownGold]];
const CORNER_TIERS = [
  [CS(352), CS(352), SH_A, MAT.crownGold],
  [CS(384), CS(384), SH_B, MAT.crownBrass],
  [CS(352), CS(352), SH_A, MAT.crownGold],
  [CS(640), CS(640), TALL_HEAD_H, MAT.crownGold],
  [CS(352), CS(352), TALL_CAP_H, MAT.crownBrass],
  [CS(288), CS(288), TALL_PIP_H, MAT.crownGold]];
// Point positions are DERIVED from the ring, never written down: three per side
// at quarter-points of the wall centreline, plus one on each chamfer. A literal
// pitch would put the teeth in the wrong place the moment CR_SCALE moved, and
// the jewels and pendilia below take their bays from the same halves.
const PT_BX = PT_X / 2, PT_BY = PT_Y / 2;
const CR_POINTS = [
  [-PT_BX, CR_CY - PT_Y, 'short', 'x'], [0, CR_CY - PT_Y, 'front', 'x'], [PT_BX, CR_CY - PT_Y, 'short', 'x'],
  [-PT_BX, CR_CY + PT_Y, 'short', 'x'], [0, CR_CY + PT_Y, 'tall', 'x'], [PT_BX, CR_CY + PT_Y, 'short', 'x'],
  [-PT_X, CR_CY - PT_BY, 'short', 'y'], [-PT_X, CR_CY, 'tall', 'y'], [-PT_X, CR_CY + PT_BY, 'short', 'y'],
  [PT_X, CR_CY - PT_BY, 'short', 'y'], [PT_X, CR_CY, 'tall', 'y'], [PT_X, CR_CY + PT_BY, 'short', 'y'],
  [-PT_CX, CR_CY - PT_CY, 'corner', 'x'], [PT_CX, CR_CY - PT_CY, 'corner', 'x'],
  [-PT_CX, CR_CY + PT_CY, 'corner', 'x'], [PT_CX, CR_CY + PT_CY, 'corner', 'x'],
];
// The four corner point heads — where the finale's quarter-progress beacons
// live now that the hall's pylon plinths are gone. See pylon_orgs() at the
// bottom of this file. Standing on the cap under the pip, so it is derived from
// the tier heights and cannot drift when CR_SCALE moves.
const CROWN_BEACON_XY = CR_POINTS.filter(p => p[2] === 'corner').map(p => [p[0], p[1]]);
// ON TOP OF THE STONE, not on top of the cap. This used to stop at
// shaft+head+cap, which is the pip's BOTTOM face — so all four finale
// quarter-progress beacons were spawned inside the 400-wide pip brush and
// entombed, model and aura both. The point of moving them out of the hall was
// to be seen, so the whole tier stack has to be counted: shaft, head, cap, pip,
// AND the jewel stone that caps it, plus a little clearance so the prop's own
// bounds are clear of the stone's top face.
const CROWN_BEACON_Z = CR_RIM_Z + TALL_SHAFT_H + TALL_HEAD_H + TALL_CAP_H + TALL_PIP_H + CS(224) + 24;

// THE RIBS. One vertical buttress under each point, running the whole band from
// the ermine to the rim strip and standing proud of the topmost course. Without
// them the sixteen points are stuck onto a smooth wall like candles on a cake;
// with them the band reads as SUPPORTING the points, which is what the eye
// wants from any load-bearing arcade and what turns a hoop into a circlet.
// They also give the flare something to be measured against on the walk in.
// NOTE the two exclusions, both deliberate:
//   * the SOUTH MID rib is skipped — that is where the mouth is, and a rib
//     there would wall up the road. The Cullinan does that job on the lintel.
//   * corner ribs are square posts on the chamfer rather than face ribs; an
//     axis-aligned box cannot stand proud of a 45-degree face.
// THREE THINGS WERE WRONG WITH THE RIBS AND ALL THREE COST NOTHING TO FIX
// (measured off the generated .map, 2026-08-25):
//
// 1. THEY WERE NARROWER THAN THE POINTS THEY CARRY. A rib was 256 wide under a
//    384 fleur shaft and 416 under a 496 corner shaft, so every one of the
//    sixteen points overhung its own buttress by 40-64 a side. That does not
//    read as support, it reads as a mistake. A buttress must be at least as wide
//    as its load.
// 2. THEY BARELY PROTRUDED. Every articulating element on the band lived inside
//    a 96-unit slot on a 6128-wide elevation: ribs 80 proud, rim 64, upper
//    astragal 16. That is 1.6% of the width, which is why the band read as one
//    flat plate in every walk-up render.
//    THE FIX IS TO SPLIT `out` BY AXIS. Silhouette rule H — sky between and
//    behind the points — is about the X profile. A south or north rib protruding
//    in Y changes the silhouette not at all, because you are looking down that
//    axis. So S/N ribs now stand 320 proud and E/W ribs stay inside the ermine.
// 3. THEY WERE THE SAME GOLD AS EVERYTHING ELSE. Every material in this pack is
//    lit_emissive (self-lit) — geometry does NOT self-shadow here, so relief
//    only reads if it carries a MATERIAL CHANGE. Brass ribs are the dark foil
//    the design doc asks for and never delivered on the band. Legal despite
//    `orange_tinted` being DECK: the rib's Z extent is 1696, far over MAX_SLAB.
CR_POINTS.forEach(([px, py, kind, fan], i) => {
  const z1 = TOP2 + CR_ERM_Z2, z2 = TOP2 + CR_C4_Z, tag = `crown rib ${i + 1}`;
  if (kind === 'front') return;
  if (kind === 'corner') {
    // matches the 496-wide corner shaft above it
    cbox(tag, px - CS(176), px + CS(176), py - CS(176), py + CS(176), z1, z2, MAT.crownBrass);
    return;
  }
  const inset = CS(192);   // keys into C1. NOT +CS(32): that put the rib back face exactly on C4 inner (7328), brass against gold, coplanar - a z-fight on a surface the hold-out looks straight at.
  const out = (fan === 'x') ? CS(224) : CS(56);   // S/N stand proud; E/W stay in the ermine
  const w = CS(144);                         // 400 wide — wider than the 384 shaft it carries
  if (fan === 'x') {
    const s = py < CR_CY ? -1 : 1;      // south face or north face
    const f = CR_CY + s * (CR_HY + out), b = CR_CY + s * (CR_HY - inset);
    cbox(tag, px - w, px + w, Math.min(f, b), Math.max(f, b), z1, z2, MAT.crownBrass);
  } else {
    const s = px < 0 ? -1 : 1;          // west face or east face
    const f = s * (CR_HX + out), b = s * (CR_HX - inset);
    cbox(tag, Math.min(f, b), Math.max(f, b), py - w, py + w, z1, z2, MAT.crownBrass);
  }
});
CR_POINTS.forEach(([px, py, kind, fan], i) => {
  const tag = `crown point ${i + 1} ${kind}`;
  // (The separate `collar` box that used to sit here is gone. It was 40 units
  // proud in the SAME material as the shaft, and on self-lit geometry that is
  // no value change and no outline change — i.e. invisible from everywhere,
  // paid for in bake. The shaft's brass middle band in TALL_TIERS does the job
  // properly, because it changes material as well as width.)
  // Every tall point is finialled with a STONE, cycling the three jewel
  // colours. 224 is 0.58 deg from the base arena — over the shimmer threshold,
  // so the rim reads as gold teeth tipped with colour rather than gold teeth.
  // KEYED ON POSITION, NOT ON ARRAY INDEX. `i % 3` looked fine until you notice
  // CR_POINTS lists the four corners last, so indices 12 and 13 are the SW and
  // SE corners and got ruby and emerald — a visible asymmetry on the one face
  // anybody ever looks at. A key built from |x| and |y - CR_CY| is symmetric in
  // both axes by construction, so mirrored points always match.
  const JT = [MAT.jewelRuby, MAT.jewelEmerald, MAT.jewelSapphire][
    Math.round((Math.abs(px) + Math.abs(py - CR_CY)) / 16) % 3];
  if (kind === 'tall' || kind === 'corner') {
    const top = cfleuron(tag, px, py, PZ, kind === 'tall' ? TALL_TIERS : CORNER_TIERS, fan);
    cbox(`${tag} stone`, px - CS(160), px + CS(160), py - CS(160), py + CS(160), top, top + CS(224), JT);
  }
  else if (kind === 'short') {
    // FLEUR-DE-LIS. The transverse bar is the token that NAMES the shape — it
    // is what separates a fleur from three lumps on a stick — so it is the
    // widest thing here (448 = 1.16 deg = 34 px from the base arena).
    // `off` slides along the fan axis, `w` is the width across it: one helper
    // and the whole shape works on a north/south wall or an east/west one.
    const P = (t, off, w, across, z1, z2, mat) => {
      const dx = fan === 'x' ? off : 0, dy = fan === 'x' ? 0 : off;
      const hx = (fan === 'x' ? w : across) / 2, hy = (fan === 'x' ? across : w) / 2;
      cbox(`${tag} ${t}`, px + dx - hx, px + dx + hx, py + dy - hy, py + dy + hy, z1, z2, mat);
    };
    // THE CENTRE LOBE WAS NARROWER THAN ITS OWN SHAFT (336 against 384), which
    // breaks the one rule every point on this crown has to obey, and the tip was
    // 176 = 0.46 deg, under the legibility floor. Centre lobe now 448, tip 288.
    // Side lobes are GOLD PANEL rather than plain so the centre petal dominates:
    // with self-lit materials, three plain-gold lumps at the same value are
    // three lumps on a stick, which is precisely what a fleur must not be.
    P('shaft', 0, CS(272), CS(320), PZ, PZ + CS(832), MAT.crownGold);
    P('bar', 0, CS(512), CS(320), PZ + CS(736), PZ + CS(864), MAT.crownGold);
    P('lobe C', 0, CS(320), CS(240), PZ + CS(832), PZ + CS(1408), MAT.crownGold);
    P('lobe L', -CS(208), CS(176), CS(192), PZ + CS(832), PZ + CS(1184), MAT.crownGoldPanel);
    P('lobe R', CS(208), CS(176), CS(192), PZ + CS(832), PZ + CS(1184), MAT.crownGoldPanel);
    P('tip', 0, CS(208), CS(208), PZ + CS(1408), PZ + CS(1552), MAT.jewelSapphire);
  }
});

// --- 5f.5 THE FRONT CROSS ---------------------------------------------------
// Real crowns have a FRONT; forts are omnidirectional, and four identical faces
// is one of the reasons the old citadel read as a keep. This is the south mid
// point, 576 taller than its neighbours, standing on the NEAR rim — which means
// it is the one tall element in the whole composition that can never be
// occluded by the crown's own south band, from any height on the tower. It
// carries the great ruby, and it is what magnetises the base arena.
{
  const fy = CR_CY - PT_Y, S = 'crown front cross';
  cbox(`${S} shaft`, -CS(192), CS(192), fy - CS(208), fy + CS(208), PZ, PZ + CS(1600), MAT.crownGold);
  cbox(`${S} upper`, -CS(176), CS(176), fy - CS(176), fy + CS(176), PZ + CS(1600), PZ + CS(2496), MAT.crownGold);
  cbox(`${S} pip`, -CS(112), CS(112), fy - CS(112), fy + CS(112), PZ + CS(2496), PZ + CS(2752), MAT.jewelRuby);
  // the transverse arm — its TOP is also the south foot of the N-S arch, which
  // is heraldically right: the arches spring from the crosses pattee, and the
  // front cross carries on above the springing.
  cbox(`${S} arm`, -CS(512), CS(512), fy - CS(176), fy + CS(176), PZ + CS(1856), PZ + CS(2176), MAT.crownGold);
  for (const s of [-1, 1])
    cbox(`${S} arm flare ${s > 0 ? 'E' : 'W'}`, s > 0 ? CS(288) : -CS(512), s > 0 ? CS(512) : -CS(288),
      fy - CS(208), fy + CS(208), PZ + CS(1760), PZ + CS(2272), MAT.crownGold);
  // THE GREAT RUBY — 716 square at CR_SCALE 1.4, which is 1.86 deg and 55 px
  // from the floor of the base arena. One of only two crown elements that gets
  // a real light entity, because it is the thing that magnetises the street.
  // THE RUBY TAKES THE ARM'S OWN HEIGHT, not the flares'. It used to be 720 tall
  // like the arm-end flares while the arm between them is 448, so the south
  // elevation read [720][a 45-wide notch][720] and the FLARE — the entire reason
  // this element is called a cross pattee — never appeared. Now the profile is
  // centre 448, ends 720: arms visibly wider at their tips, which is the shape.
  cbox(`${S} ruby`, -CS(256), CS(256), fy - CS(288), fy - CS(208), PZ + CS(1856), PZ + CS(2176), MAT.jewelRuby);
  cbox(`${S} ruby bezel`, -CS(288), CS(288), fy - CS(272), fy - CS(208), PZ + CS(1824), PZ + CS(2208), MAT.crownGoldPanel);
}

// --- 5f.6 the arches, the monde, the finial, the beacon ---------------------
// A crown CONVERGES; a castle TERMINATES in a wall-walk. The closure is also a
// reveal staged across the whole climb: from the base the arches and monde are
// occluded by the near rim and contribute nothing, the monde clears at floor 7,
// the arch crowns at floor 18, and from the terrace they are the entire
// silhouette. From inside the hall during the hold-out they are a golden vault
// overhead, which is the single best thing the crown can give the ending.
const ARCH_SPRING = TOP2 + CR_TALL_TOP, ARCH_RISE = CR_ARCH_CROWN - CR_TALL_TOP;
const ARCH_N = 8, ARCH_HW = CS(176), ARCH_TH = CS(320);
// `skip` drops the first N segments. The N-S arch's SOUTH half springs off the
// front cross's arm, and the front cross's upper member is 480 deep and 1248
// tall right there — so segment 1 came out 90% inside it, paying full bake for a
// brush you cannot see. Only that half needs it: the north foot is a 400-wide
// pip and does not swallow anything.
function archHalf(tag, axis, from, to, skip = 0) {
  const count=24;
  for(let k=skip?1:0;k<count;k++) {
    const u=k/count,v=(k+1)/count;
    const a=from+(to-from)*u,b=from+(to-from)*v;
    const za=ARCH_SPRING+ARCH_RISE*Math.sin(Math.PI/2*u);
    const zb=ARCH_SPRING+ARCH_RISE*Math.sin(Math.PI/2*v);
    const ring=(p,z)=>axis==='y'
      ?[[-ARCH_HW,p,z-ARCH_TH],[ARCH_HW,p,z-ARCH_TH],[ARCH_HW,p,z],[-ARCH_HW,p,z]]
      :[[p,CR_CY-ARCH_HW,z-ARCH_TH],[p,CR_CY+ARCH_HW,z-ARCH_TH],[p,CR_CY+ARCH_HW,z],[p,CR_CY-ARCH_HW,z]];
    crownLoft(`${tag} swept ${k+1}`,ring(a,za),ring(b,zb),MAT.crownGold);
  }
}
// The arch ribbon must be thicker than its own worst step or it breaks into a
// dotted line. sin(90/8 deg) = 0.195 of the rise is the first and biggest step.
if (ARCH_RISE * Math.sin(Math.PI / 16) > ARCH_TH)
  throw new Error(`crown arch step ${Math.round(ARCH_RISE * Math.sin(Math.PI / 16))} exceeds the ${ARCH_TH} ribbon — the arch would gap`);
archHalf('crown arch NS south', 'y', CR_CY - PT_Y, CR_CY, 1);
archHalf('crown arch NS north', 'y', CR_CY + PT_Y, CR_CY);
archHalf('crown arch EW west', 'x', -PT_X, 0);
archHalf('crown arch EW east', 'x', PT_X, 0);
// PEARLS ON THE ARCHES (v12). Real crown arches carry a row of pearls — it is
// the single most recognisable piece of crown jewellery grammar after the
// ermine, and the arches were bare gold ribbons. Three ermine-white beads per
// half-arch, on segments 2/4/6: white (13.1) on gold (13.5) is nearly no VALUE
// step, so what these buy is the serrated OUTLINE against the sky — the one
// currency that always spends on self-lit materials. Segment 7 is skipped
// deliberately: the two arches CROSS at the crown, and beads from both would
// collide there. 176-square = 1.1 deg from the terrace, where the arches ARE
// the silhouette; from the base they are group texture on a line that already
// reads. Plain-colour white, so the lint can never call one a floor.
{
  const PB = CS(88), PH = CS(96);
  const pearls = (tag, axis, from, to, skip = 0) => {
    for (const k of [2, 4, 6]) {
      if (k < skip) continue;
      const u = Math.round(from + (to - from) * (k + 0.5) / ARCH_N);
      const top = Math.round(ARCH_SPRING + ARCH_RISE * Math.sin(Math.PI / 2 * (k + 1) / ARCH_N));
      crownOrb(`${tag} pearl ${k}`,axis==='y'?0:u,axis==='y'?u:CR_CY,top+PH/2,PB,PB,PH/2,MAT.crownErmine);
    }
  };
  pearls('crown arch NS south', 'y', CR_CY - PT_Y, CR_CY, 1);
  pearls('crown arch NS north', 'y', CR_CY + PT_Y, CR_CY);
  pearls('crown arch EW west', 'x', -PT_X, 0);
  pearls('crown arch EW east', 'x', PT_X, 0);
}
{
  // THE MONDE — eight stepped slabs on a circle, plus an equator fillet in
  // bright gold. Real mondes have exactly that band and it is what stops a
  // stepped sphere reading as a stack of boxes.
  // Slab height is DERIVED so the eight courses land exactly on CR_MONDE_Z2 at
  // any CR_SCALE — a literal 128 leaves a 32-unit step in the sphere at 1.4.
  crownOrb('crown monde',0,CR_CY,TOP2+(CR_ARCH_CROWN+CR_MONDE_Z2)/2,
    CS(504),CS(504),(CR_MONDE_Z2-CR_ARCH_CROWN)/2,MAT.crownGoldPanel);
  const ME = TOP2 + (CR_ARCH_CROWN + CR_MONDE_Z2) / 2, MEH = CS(544);
  cbox('crown monde equator', -MEH, MEH, CR_CY - MEH, CR_CY + MEH, ME - CS(48), ME + CS(48), MAT.crownGold);
  // THE FINIAL — a cross pattee, arms wider at the ends than at the crossing.
  // Its arms run on BOTH axes: from the terrace you read the E-W pair, from
  // directly below you read whichever presents area, and a cross that only
  // exists on one axis disappears from half the map.
  const F = 'crown finial';
  cbox(`${F} shaft`, -CS(128), CS(128), CR_CY - CS(128), CR_CY + CS(128), TOP2 + CR_MONDE_Z2, TOP2 + CS(5568), MAT.crownGold);
  cbox(`${F} arm EW`, -CS(384), CS(384), CR_CY - CS(112), CR_CY + CS(112), TOP2 + CS(5184), TOP2 + CS(5376), MAT.crownGold);
  cbox(`${F} arm NS`, -CS(112), CS(112), CR_CY - CS(384), CR_CY + CS(384), TOP2 + CS(5184), TOP2 + CS(5376), MAT.crownGold);
  for (const s of [-1, 1]) {
    cbox(`${F} arm flare ${s > 0 ? 'E' : 'W'}`, s > 0 ? CS(288) : -CS(384), s > 0 ? CS(384) : -CS(288),
      CR_CY - CS(128), CR_CY + CS(128), TOP2 + CS(5136), TOP2 + CS(5424), MAT.crownGold);
    cbox(`${F} arm flare ${s > 0 ? 'N' : 'S'}`, -CS(128), CS(128),
      CR_CY + Math.min(s * CS(288), s * CS(384)), CR_CY + Math.max(s * CS(288), s * CS(384)),
      TOP2 + CS(5136), TOP2 + CS(5424), MAT.crownGold);
  }
  cbox(`${F} crossing stone`, -CS(160), CS(160), CR_CY - CS(160), CR_CY + CS(160), TOP2 + CS(5216), TOP2 + CS(5344), MAT.jewelEmerald);
  cbox(`${F} top flare`, -CS(176), CS(176), CR_CY - CS(176), CR_CY + CS(176), TOP2 + CS(5568), TOP2 + CS(5664), MAT.crownGold);
  cbox(`${F} pip`, -CS(80), CS(80), CR_CY - CS(80), CR_CY + CS(80), TOP2 + CS(5664), TOP2 + CR_FINIAL_Z2, MAT.crownGold);
  // THE BEACON. Its job is to clear the south rim's occlusion line — which it
  // does by 1,392 units — and be SEEN from the floor of the base arena,
  // vertically aligned with the great ruby below it.
  //
  // THE FIRST CUT WAS A 160-WIDE NEEDLE AND THAT WAS THE OLD MISTAKE AGAIN.
  // Clearing the occlusion line is not the same as resolving: 160 units at
  // 22,079 is 0.41 deg = 12 px, under the half-degree floor, so it would have
  // shimmered away exactly like the gate spires it replaced. And from directly
  // below, a vertical member presents almost NO area at all — the preview's
  // `street` view shows the whole upper crown as a hairline. So the apex is a
  // STAR, not a spike: a cross of horizontal plates, because horizontal is the
  // only orientation that has any area when you are looking straight up at it.
  cbox('crown beacon needle', -CS(80), CS(80), CR_CY - CS(80), CR_CY + CS(80), TOP2 + CR_FINIAL_Z2, TOP2 + CS(6272), MAT.crownGold);
  cbox('crown beacon core', -CS(224), CS(224), CR_CY - CS(224), CR_CY + CS(224), TOP2 + CS(6272), TOP2 + CS(6720), MAT.jewelRuby);
  cbox('crown beacon arm EW', -CS(384), CS(384), CR_CY - CS(80), CR_CY + CS(80), TOP2 + CS(6432), TOP2 + CS(6592), MAT.jewelRuby);
  cbox('crown beacon arm NS', -CS(80), CS(80), CR_CY - CS(384), CR_CY + CS(384), TOP2 + CS(6432), TOP2 + CS(6592), MAT.jewelRuby);
  cbox('crown beacon pip', -CS(80), CS(80), CR_CY - CS(80), CR_CY + CS(80), TOP2 + CS(6720), TOP2 + CR_BEACON_Z2, MAT.crownGold);
}

// --- 5f.7 the jewels --------------------------------------------------------
// One boss per bay between adjacent points, keyed into C2 and C3 and standing
// 48 proud of C3's face. 320 square = 0.86 deg = 25 px from the base arena, so
// they are the smallest thing on the crown that still resolves.
// A vertical plaque is safe in a `_tinted_edge` material at any thickness — the
// lint's floor test is on the Z extent, which here is the boss's height.
{
  const JH = CS(160), JZ1 = TOP2, JZ2 = TOP2 + CS(320), JP = CS(48), JK = CS(128);
  const JM = [MAT.jewelRuby, MAT.jewelSapphire, MAT.jewelEmerald];
  const oS = CR_CY - CR_HY - JP, iS = CR_CY - CR_HY + JK;    // south face band
  const oN = CR_CY + CR_HY + JP, iN = CR_CY + CR_HY - JK;
  // A BAY IS THE GAP BETWEEN TWO ADJACENT POINTS, so its centre is computed from
  // where the points ACTUALLY are, never from a fraction of the wall. The old
  // fraction form put the outer bosses at 3/4 of PT_X = 2028 while the corner
  // point sits on the chamfer centreline at PT_CX = 2344 — so the moment the
  // corner ribs were widened to match their shafts, the boss ran into the post
  // and was partly buried. Midpoints cannot drift: widen a rib, move a point or
  // change CR_SCALE and the boss stays centred in its bay by construction.
  const BAYX = [-(PT_CX + PT_BX) / 2, -PT_BX / 2, PT_BX / 2, (PT_CX + PT_BX) / 2];
  const BAYY = [-(PT_CY + PT_BY) / 2, -PT_BY / 2, PT_BY / 2, (PT_CY + PT_BY) / 2];
  // THE TWO INNER SOUTH BOSSES WERE ENTIRELY BURIED. The frontispiece occupies
  // the two bays either side of the centreline by design (|x| up to CS(672)),
  // and the bosses for those bays sat inside it — 448-wide coloured slabs
  // completely enclosed in solid gold, costing bake and rendering nothing.
  // They are skipped rather than moved: the centreline already carries the
  // frontispiece, the Cullinan and the front cross, which is the busiest event
  // on the crown. It does not need two more stones behind a wall.
  // The NORTH face keeps all four — nothing is in front of them there.
  let n = 0;
  for (const jx of BAYX) {
    n++;
    if (Math.abs(jx) > CS(672) + JH)
      cbox(`crown jewel S${n}`, jx - JH, jx + JH, oS, iS, JZ1, JZ2, JM[n % 3]);
    cbox(`crown jewel N${n}`, jx - JH, jx + JH, iN, oN, JZ1, JZ2, JM[(n + 1) % 3]);
  }
  for (const jy of BAYY.map(d => CR_CY + d)) {
    cbox(`crown jewel W${++n}`, -CR_HX - JP, -CR_HX + JK, jy - JH, jy + JH, JZ1, JZ2, JM[n % 3]);
    cbox(`crown jewel E${n}`, CR_HX - JK, CR_HX + JP, jy - JH, jy + JH, JZ1, JZ2, JM[(n + 1) % 3]);
  }
  // THE FRONTISPIECE. A raised panel on the south band, spanning the two bays
  // either side of the centreline, that the Cullinan is set into. Without it
  // the front stone floats on a flat wall; with it the crown has a facade, and
  // the centreline reads as one vertical event from the mouth through the
  // stone to the front cross. It is 800 tall, so it is a wall, not a floor.
  // SPLIT AROUND THE MOUTH, and this is not a detail — the first cut spanned the
  // full +-672 for the whole band height and walled the causeway up inside the
  // rim. `lint_tod_geometry` caught it instantly: `terrace -> citadel walkable:
  // NO`, 336 detached road nodes. Anything that crosses x=0 on the south band
  // between CR_MOUTH_Z1 and CR_MOUTH_Z2 is a wall across the road.
  // fy1 is CS(16) proud, not CS(64): the frontispiece now sits BEHIND the mouth
  // jambs (which stand CS(240) proud) instead of sharing a plane with them.
  // Two different materials on one plane is a z-fight, and it also flattened the
  // gate's edge to nothing. Depth order out from the band is now:
  // jamb (240) > rib (224) > ermine (96) > rim (64) > frontispiece (16) > C4 (0).
  const fy1 = CR_CY - CR_HY - CS(16), fy2 = CR_CY - CR_HY + CS(96);
  const FW = CS(672), FP = CS(576);
  cbox('crown frontispiece head', -FW, FW, fy1, fy2,
    TOP2 + CR_MOUTH_Z2, TOP2 + CR_RIM_Z, MAT.crownGoldPanel);
  for (const s of [-1, 1])
    cbox(`crown frontispiece ${s > 0 ? 'E' : 'W'}`, s > 0 ? CR_MOUTH_HALF : -FW, s > 0 ? FW : -CR_MOUTH_HALF,
      fy1, fy2, TOP2 + CR_C1_Z, TOP2 + CR_MOUTH_Z2, MAT.crownGoldPanel);
  for (const s of [-1, 1])
    cbox(`crown frontispiece pier ${s > 0 ? 'E' : 'W'}`, s > 0 ? FP : -FW, s > 0 ? FW : -FP,
      CR_CY - CR_HY - CS(112), fy2, TOP2 + CR_C1_Z, TOP2 + CR_RIM_Z, MAT.crownGold);
  // THE CULLINAN — the band's front stone, on the lintel DIRECTLY ABOVE the
  // mouth the player walks through and DIRECTLY BELOW the front cross. It is
  // the brightest single point on the south elevation and it sits on the
  // centreline of the entire composition. Its z is derived from the courses it
  // straddles (C4 and the rim strip) so it cannot slide off the lintel.
  const CUZ1 = TOP2 + CR_C4_Z - CS(240), CUZ2 = TOP2 + CR_RIM_Z + CS(16);
  cbox('crown cullinan', -CS(320), CS(320), CR_CY - CR_HY - CS(144), fy2,
    CUZ1 + CS(32), CUZ2 - CS(32), MAT.jewelSapphire);
  cbox('crown cullinan bezel', -CS(384), CS(384), CR_CY - CR_HY - CS(128), fy2,
    CUZ1, CUZ2, MAT.crownGold);
}

// --- 5f.8 the pendilia ------------------------------------------------------
// Byzantine hanging strands off the ermine rim (the kamelaukion's pendilia).
// They hang at the OUTER edge of the rim rather than into the cone, so they
// read as a fringe on the silhouette's widest line instead of cluttering the
// concentric underside — which is the surface doing most of the work. They are
// under the legibility floor individually from the base, but they are a group
// read there and they are the detail that pays off on the walk in.
{
  const drops = [512, 704, 512].map(CS), PW = CS(80), PB = CS(112), PIN = CS(128);
  const strand = (tag, cx, cy, i) => {
    const d = drops[i % drops.length], z0 = TOP2 + CR_ERM_Z1;
    cbox(`${tag} cord`, cx - PW, cx + PW, cy - PW, cy + PW, z0 - d, z0, MAT.crownGold);
    cbox(`${tag} bead`, cx - PB, cx + PB, cy - PB, cy + PB, z0 - d - CS(224), z0 - d, MAT.jewelSapphire);
  };
  const yS = CR_CY - CR_HY - CR_ERM + PIN, yN = CR_CY + CR_HY + CR_ERM - PIN;
  [-3 * PT_X / 4, -3 * PT_X / 8, 0, 3 * PT_X / 8, 3 * PT_X / 4].forEach((jx, i) => {
    strand(`crown pendilia S${i + 1}`, jx, yS, i);
    strand(`crown pendilia N${i + 1}`, jx, yN, i + 1);
  });
  [-3 * PT_Y / 4, 0, 3 * PT_Y / 4].map(d => CR_CY + d).forEach((jy, i) => {
    strand(`crown pendilia W${i + 1}`, -CR_HX - CR_ERM + PIN, jy, i);
    strand(`crown pendilia E${i + 1}`, CR_HX + CR_ERM - PIN, jy, i + 1);
  });
}

// ---------------------------------------------------------------------------
// 5f.10 THE SECOND DETAIL SCALE (v11.2, user 2026-08-25: "Its scale is perfect.
// It looks fantastic. Now I want to review the design and add some details to
// it. To make it look nicer and more pleasing and impressive.")
//
// TWO MEASUREMENTS DECIDED EVERYTHING IN THIS SECTION.
//
// 1. THE MATERIALS ARE SELF-LIT. All 30 in the emox vertigo pack are
//    `lit_emissive_*` (verified in the GDT). A face pointing down and a face
//    pointing at the sky emit the same. So GEOMETRY DOES NOT SELF-SHADOW HERE:
//    a corbel, a ledge or a moulding produces NO value change on its own.
//    Relief only pays when it (a) breaks the silhouette against sky or a darker
//    neighbour, or (b) CARRIES A DIFFERENT MATERIAL. Everything below either
//    changes material or changes the outline. Nothing below is there to catch
//    light, because nothing here can.
//
// 2. THE CROWN IS ALREADY 84% OF THE MAP'S LIT AREA (run
//    `node tools/measure_lit_area.js`). The bake costs AREA — the same 4,700
//    brushes went 38.2 s to 126.2 s purely by scaling. So detail here must be
//    SMALL: a 200-unit cube is 0.24M against the crown's 807M. Small relief is
//    nearly free; a new LARGE SURFACE is what would cost. That is why this
//    section adds ~90 small brushes and not one new panel.
//
// AND WHERE IT GOES IS DECIDED BY WHERE A PLAYER CAN STAND. They can be: in the
// base arena, on the spiral, on the breathers, on the terrace, anywhere on the
// causeway, in the mouth, and on the hall floor. NOWHERE ELSE — they cannot fly
// and cannot reach the band. The reachable close views are all from the SOUTH:
// the terrace (~6,500 out), the plank (the raised centre route, 700-2,000 out —
// the real money view, see preview_crown.js), the mouth itself, and the hall
// floor looking up. So detail goes on the SOUTH face, the mouth and the ermine.
// The E/W/N band faces get nothing: they are only ever seen from 22,000 units,
// where the 384-unit legibility floor says sub-degree detail shimmers, so a
// brush spent there is pure bake cost for a surface nobody resolves.
// ---------------------------------------------------------------------------

// Apply a detail box to one of the ring's four flat faces. `u` is the position
// ALONG the face (x on the S/N faces, y offset from CR_CY on the W/E faces),
// `w` its width along that face, `out` how far it stands proud, `keyed` how far
// it sinks back into the wall so it never floats.
function crownFaceBox(tag, face, hx, hy, u, w, z1, z2, out, keyed, mat) {
  if (face === 'S') cbox(tag, u - w / 2, u + w / 2, CR_CY - hy - out, CR_CY - hy + keyed, z1, z2, mat);
  else if (face === 'N') cbox(tag, u - w / 2, u + w / 2, CR_CY + hy - keyed, CR_CY + hy + out, z1, z2, mat);
  else if (face === 'W') cbox(tag, -hx - out, -hx + keyed, CR_CY + u - w / 2, CR_CY + u + w / 2, z1, z2, mat);
  else cbox(tag, hx - keyed, hx + out, CR_CY + u - w / 2, CR_CY + u + w / 2, z1, z2, mat);
}

// --- ERMINE SPOTS -----------------------------------------------------------
// The ermine rim is the widest line in the whole silhouette and the strongest
// single read from the base arena — and it was a blank white bar. Heraldic
// ermine is white WITH DARK TAILS; that pattern is the entire reason a white
// band on a crown reads as fur rather than as paint. Two staggered rows, which
// is how ermine is actually diapered.
// 224 wide = 0.58 deg from the base arena, over the shimmer floor, so they
// resolve as spots instead of greying the ring down to a flat mid tone.
{
  const EW = CS(160), EH = CS(176), EO = CS(24);
  const z1 = TOP2 + CR_ERM_Z1, z2 = TOP2 + CR_ERM_Z2, mid = (z1 + z2) / 2;
  const hx = CR_HX + CR_ERM, hy = CR_HY + CR_ERM;
  let n = 0;
  for (const face of ['S', 'N']) {
    const span = (CR_HX - CR_CHAM) * 2;
    const cols = Math.max(3, Math.round(span / CS(760)) | 1);
    for (let i = 0; i < cols; i++) {
      // snapped to the 16-grid — span/cols never divides evenly here
      const u = Math.round((-span / 2 + span * (i + 0.5) / cols) / 16) * 16;
      // upper row on the odd columns, lower row on the even ones — a diaper
      const hi = (i % 2 === 0);
      crownFaceBox(`crown ermine spot ${++n}`, face, hx, hy, u, EW,
        hi ? mid + CS(8) : mid - EH - CS(8), hi ? mid + EH + CS(8) : mid - CS(8),
        EO, CS(32), MAT.crownErmineSpot);
    }
  }
  // v12: THE UNDERSIDE ROW. From the upper half of the spiral the sight line
  // has climbed past the ermine's face and what you see is its BOTTOM — the
  // widest, whitest annulus on the crown, and it was blank. One row of tails
  // hanging just under the south rim (south only: the rest of the annulus is
  // never seen — the tower is due south of the crown). They are keyed CS(32)
  // up into the ermine body so nothing floats, and their south face stands
  // CS(24) PROUD of the ermine's — the first cut put both on the same y plane,
  // dark_white against white, five z-fights on the strongest read from the
  // base (the mouth-jamb defect, again; caught by the same-day review). The
  // row rides SAFE_U: the pendilia cords fall straight past this z-band.
  {
    const yS = CR_CY - hy;
    for (const u of SAFE_U)
      cbox(`crown ermine spot ${++n}`, u - EW, u + EW, yS - CS(24), yS + CS(128),
        TOP2 + CR_ERM_Z1 - CS(24), TOP2 + CR_ERM_Z1 + CS(32), MAT.crownErmineSpot);
  }
}

// --- DENTILS UNDER THE RIM --------------------------------------------------
// A dentil course is the oldest "this is finished architecture, not a wall" cue
// there is, and it is one of the few kinds of relief that still works on
// self-lit materials: it reads as a broken OUTLINE against the dark recess
// behind it, not as a shaded moulding. South face only — see the header.
// Z extent CS(64) = 96, over MAX_SLAB, but plain `yellow` anyway so it can never
// be classed as floor at any scale.
{
  // A DENTIL COURSE IS INTERRUPTED BY ITS BUTTRESSES — that is how the real thing
  // behaves, and here it is not optional. At the rim's height the south face is
  // already occupied: the ribs stand 320 proud, the mouth jamb caps 384, the
  // Cullinan bezel 176, all of them in FRONT of a 56-proud dentil. An evenly
  // spaced course across the whole face buried more than half of itself and the
  // survivors read as scattered blocks, not as a course.
  // So: compute the RUNS between the obstructions and fill each one at its own
  // pitch. Every dentil emitted is one a player can actually see.
  // Each range is the obstruction's REAL extent plus half a dentil, so the
  // course stops exactly where something stands in front of it and no further.
  const DW = CS(72), DP = CS(88), DO = CS(40), HALF = CR_HX - CR_CHAM, P = DW / 2;
  const BLOCK = [
    [0, CS(384) + P],                                        // the Cullinan bezel
    [CR_MOUTH_HALF - CS(24) - P, CR_MOUTH_HALF + MJ + CS(48) + P], // the mouth jamb cap
    [CS(576) - P, CS(672) + P],                              // the frontispiece piers
    [PT_BX - CS(144) - P, PT_BX + CS(144) + P],              // the south ribs
    [PT_CX - CS(176) - P, Infinity],                         // the corner posts
  ].sort((a, b) => a[0] - b[0]);
  const runs = [];
  let cur = 0;
  for (const [a, b] of BLOCK) { if (a > cur) runs.push([cur, Math.min(a, HALF)]); cur = Math.max(cur, b); }
  if (cur < HALF) runs.push([cur, HALF]);
  let d = 0;
  for (const [a, b] of runs) {
    const n = Math.floor((b - a) / DP);
    for (let i = 0; i < n; i++) {
      const u = Math.round((a + (b - a) * (i + 0.5) / n) / 16) * 16;   // 16-grid
      for (const s of [-1, 1])
        crownFaceBox(`crown dentil ${++d}`, 'S', CR_HX + CS(48), CR_HY + CS(48), s * u, DW,
          TOP2 + CR_C4_Z - CS(96), TOP2 + CR_C4_Z, DO, CS(48), MAT.crownGold);
    }
  }
}

// --- THE CULLINAN BECOMES A CUT STONE ---------------------------------------
// It is the focal point of the entire south elevation and it was a single flat
// slab 896 wide — from the plank it reads as a blue rectangle painted on gold.
// A real stone of that size in a crown is a CABOCHON in a clawed collet: a
// stepped dome held by four claws. Three stacked plates give the dome, four
// small gold blocks give the claws, and the outline stops being a rectangle.
{
  const cy1 = CR_CY - CR_HY, S = 'crown cullinan';
  const zc = (TOP2 + CR_C4_Z - CS(240) + TOP2 + CR_RIM_Z + CS(16)) / 2;
  const steps = [[CS(224), CS(112), CS(72)], [CS(144), CS(72), CS(112)]];
  steps.forEach(([hw, hh, out], k) => {
    cbox(`${S} facet ${k + 1}`, -hw, hw, cy1 - CS(144) - out, cy1 - CS(144),
      zc - hh, zc + hh, MAT.jewelSapphire);
  });
  for (const sx of [-1, 1]) for (const sz of [-1, 1])
    cbox(`${S} claw ${sx > 0 ? 'E' : 'W'}${sz > 0 ? 'U' : 'D'}`,
      sx > 0 ? CS(288) : -CS(352), sx > 0 ? CS(352) : -CS(288),
      cy1 - CS(176), cy1 - CS(48),
      sz > 0 ? zc + CS(112) : zc - CS(208), sz > 0 ? zc + CS(208) : zc - CS(112),
      MAT.crownGold);
}

// --- BOSS COLLETS -----------------------------------------------------------
// The Cullinan and the great ruby both sit in a gold surround; the remaining
// face bosses were coloured slabs stuck flat to a wall with nothing holding
// them, which reads as a decal rather than a stone. One plate behind each, a
// little larger than the stone, is the cheapest possible collet.
// South and north only — the E/W faces are never seen close (header).
{
  const CH = CS(200), CZ = CS(400), OB = (PT_CX + PT_BX) / 2;   // the outer bay centre
  for (const jx of [-OB, OB]) {
    crownFaceBox(`crown collet S${jx < 0 ? 'W' : 'E'}`, 'S', CR_HX, CR_HY, jx, CH * 2,
      TOP2 - CS(40), TOP2 + CZ, CS(24), CS(160), MAT.crownGold);
  }
}

// --- SUNKEN PANELS IN THE SOUTH BAYS ----------------------------------------
// THE NUMBER-ONE COMPLAINT IN EVERY CRITIQUE. Between the ribs, each outer south
// bay is an unbroken field roughly 660 wide by 1,800 tall carrying one boss and
// nothing else — the single largest flat surface a player ever walks past, and
// it reads as an untextured wall in every close render.
// You cannot RECESS anything with additive boxes, so the panel is implied the
// way real masonry implies it: a raised FRAME around a quiet centre. Four thin
// bars per bay, plain gold standing proud of the gold-panel field, which is a
// 13.5-against-7.8 value step and therefore reads without any light at all.
// The horizontals are under MAX_SLAB in Z, so plain colour is MANDATORY here.
// THE PANEL FITS THE BAY IT IS IN, and the bay is measured, not assumed. The
// first cut centred a CS(300) half-width panel on the bay midpoint, which put
// BOTH its stiles behind the very buttresses that define the bay — the ribs
// stand 320 proud at |x| 1152-1552 and the corner posts at 2104+, and the panel
// spanned 1428-2268. `tools/audit_hidden_faces.js` caught both stiles at 100%
// buried on all six faces: a frame with no sides is not a frame.
// The clear span is rib-outer to post-inner, so that is what it is derived from.
{
  const RIB_OUT = PT_BX + CS(144), POST_IN = PT_CX - CS(176);
  const BW = CS(40), BO = CS(64), BK = CS(96), PAD = CS(48);
  const a = RIB_OUT + PAD, b = POST_IN - PAD;
  const cx = (a + b) / 2, half = (b - a) / 2;
  const z1 = TOP2 + CR_C1_Z + CS(80), z2 = TOP2 + CR_C3_Z - CS(48);
  if (half > BW * 2) for (const sx of [-1, 1]) {
    const tag = sx > 0 ? 'SE' : 'SW';
    for (const s of [-1, 1])
      crownFaceBox(`crown panel ${tag} stile ${s > 0 ? 'E' : 'W'}`, 'S', CR_HX, CR_HY,
        sx * (cx + s * half), BW, z1, z2, BO, BK, MAT.crownGold);
    for (const [nm, za, zb] of [['head', z2 - BW, z2], ['sill', z1, z1 + BW]])
      crownFaceBox(`crown panel ${tag} ${nm}`, 'S', CR_HX, CR_HY, sx * cx, half * 2 + BW,
        za, zb, BO, BK, MAT.crownGold);
  }
}

// --- THE MOUTH: bases, capitals and a ribbed vault ---------------------------
// The mouth is the ONE piece of the crown every player is guaranteed to see from
// arm's length, and it is the only place on the whole fabric with a light
// entity (`tod light crown mouth`), so it is the only place where relief behaves
// the way relief is supposed to. It gets the densest detail on the crown.
{
  const JX = CR_MOUTH_HALF, MJ2 = CS(160), y2 = CR_CY - CR_HY + CS(144);
  for (const sx of [-1, 1]) {
    // A BASE AND A CAPITAL, so the jamb stands ON something and stops AT
    // something. The BASE takes MP1 because it reaches down to the road deck and
    // must stay north of the J4 landing; the CAP takes MP_DEEP and oversails,
    // which is exactly the corbel a real gate head does over its own threshold.
    // The BASE takes its projection entirely in X (it is already wider than the
    // jamb) and NONE in Y: it sits exactly on MP1, because any southward
    // oversail at deck height lands on the J4 landing. The CAP is high enough to
    // oversail freely. The 5f.9 road assert enforces this — it caught a 64-unit
    // `- CS(48)` on the base that was left over from when both shared a line.
    for (const [nm, za, zb, yy] of [
      ['base', TOP2, TOP2 + CS(128), MP1],
      ['cap', TOP2 + CR_C4_Z - CS(160), TOP2 + CR_C4_Z, MP_DEEP - CS(48)]])
      cbox(`crown mouth jamb ${nm} ${sx > 0 ? 'E' : 'W'}`,
        sx > 0 ? JX - CS(24) : -JX - MJ2 - CS(48), sx > 0 ? JX + MJ2 + CS(48) : -JX + CS(24),
        yy, y2, za, zb, MAT.crownGold);
  }
  // two longitudinal vault ribs under the soffit. They run N-S so they can never
  // cross x=0 on the south band (constraint C), and they sit CS(80) below the
  // soffit, leaving well over GATE_H of clearance over the road.
  for (const sx of [-1, 1])
    cbox(`crown mouth vault rib ${sx > 0 ? 'E' : 'W'}`,
      sx > 0 ? CS(200) : -CS(272), sx > 0 ? CS(272) : -CS(200),
      CR_CY - CR_HY - CS(32), CR_CY - CR_HY + BAND_T + CS(96),
      TOP2 + CR_MOUTH_Z2 - CS(160), TOP2 + CR_MOUTH_Z2 - CS(80), MAT.crownGold);
}

// --- POINT PLINTHS ----------------------------------------------------------
// Every shaft on the rim just started in mid-air where it met the rim strip.
// A plinth is the cheapest way to make sixteen posts read as STANDING on the
// crown rather than being stuck to it, and it is a silhouette break so it works
// on self-lit materials. South row and the four corners only: the north and
// side points are never seen from close enough for a 128-tall block to resolve.
CR_POINTS.forEach(([px, py, kind], i) => {
  if (kind === 'front') return;
  if (!(py < CR_CY || kind === 'corner')) return;      // south row + corners
  const w = (kind === 'corner') ? CS(232) : (kind === 'tall' ? CS(216) : CS(200));
  cbox(`crown point ${i + 1} plinth`, px - w, px + w, py - w, py + w,
    PZ - CS(24), PZ + CS(112), MAT.crownGoldPanel);
});

// --- 5f.9 THE SEAL, asserted against the crown's REAL bounding box ----------
// This runs last on purpose: it reads crownBB, which is accumulated by addBox as
// the crown is emitted, so it sees what was actually cut rather than what the
// constants imply. Before v11 the seal was `SKY_IN = max(2900, HN + 384)` and
// `SKY_TOP = MAST_TOP + 300`, and the only asserts in the file tested the
// CAUSEWAY — so nothing whatsoever would have fired when the beacon went
// thousands of units through the roof of the world. A hole in the sky is a hole
// in the world, not a cosmetic bug.
// THE CROWN MUST NOT STAND ON THE ROAD, and this is asserted against the brushes
// rather than against the constants — because the constants version passed while
// four gold blocks were sitting on the causeway's J4 landing.
//
// 5f.1 checks `CR_CY - CR_HY - CR_ERM > cwY[8]`, which is true (6912 > 6880) and
// says nothing at all about a jamb, a base or a corbel that reaches 336 units
// further south than the band it hangs off. That is exactly what happened in the
// v11.2 detail pass, and NO EXISTING GATE CAUGHT IT: lint_tod_geometry's
// misplaced-wall check only fires on a `clip` brush with no visible solid, and a
// VISIBLE solid silently drops the node from `stand` — while the reachability
// flood still walks the middle of a 960-wide landing, so it stayed green too.
//
// The invariant nobody had written down: south of cwY[8] the road is 960 wide to
// +-CW_LAND, so any crown brush there must be either outside that width or high
// enough over it that a player walks under (STAND_HI is 70; use 96 for margin).
{
  const RY = cwY[8], RX = CW_LAND + PARA + 20, RZ = TOP2 + 96;
  const onRoad = crownBoxes.filter(b =>
    b.y1 < RY && b.y2 > cwY[7] && b.x1 < RX && b.x2 > -RX && b.z1 < RZ && b.z2 > TOP2 + 2);
  if (onRoad.length) {
    const l = onRoad.slice(0, 6).map(b =>
      `\n    ${b.label}  x[${b.x1},${b.x2}] y[${b.y1},${b.y2}] z[${b.z1},${b.z2}]`).join('');
    throw new Error(`${onRoad.length} crown brush(es) stand on the causeway landing ` +
      `(south of y=${RY}, within x +-${RX}, below z=${RZ}) — they would be an obstruction ` +
      `on the road that the geometry lint cannot see:${l}`);
  }
}
{
  const bb = crownBB;
  const R = Math.max(-bb.x1, bb.x2, -bb.y1, bb.y2);
  if (bb.z2 + 256 > SKY_TOP)
    throw new Error(`crown reaches z ${bb.z2} but the sky ceiling is at ${SKY_TOP}`);
  if (bb.z2 > SKY_TOP - 200)
    throw new Error(`crown reaches z ${bb.z2} but the umbra/fpstool lid is at ${SKY_TOP - 200}`);
  if (bb.z1 - 256 < SKY_FLOOR)
    throw new Error(`crown descends to z ${bb.z1} but the sky floor is at ${SKY_FLOOR}`);
  if (R + 256 > SKY_IN)
    throw new Error(`crown reaches ${R} from the axis but the sky wall is at ${SKY_IN}`);
  // (the umbra/fpstool volume is asserted where VOL_R is defined — it is
  // declared further down the file, in the entities section)
  console.log(`  crown: x[${bb.x1},${bb.x2}] y[${bb.y1},${bb.y2}] z[${bb.z1},${bb.z2}] ` +
    `(${bb.x2 - bb.x1} wide, ${bb.z2 - bb.z1} tall, CR_SCALE ${CR_SCALE}); ` +
    `sky wall ${SKY_IN}, ceiling ${SKY_TOP}`);
}

// ===========================================================================
// THE ROCKETS (2026-10-02, docs/170; user: "use the rocket ships built in the props and place at each spot.
// Instead of the teleporters after the crown fight is over. Then the colorful one goes to endless spire ... they
// view from the rocket pov as it flies to the endless spire. Then it crashes into the ground and they spawn in" +
// "if you extract same thing but the extract ship goes striaght up and the game ends few seconds later").
// Two of Nikolai's ships (tools/fan_props/build_fan_props.py; measured in art/fan_props/manifest.json: nose =
// model +X, pivot on the axis at the fins' feet) come DOWN into the crown hall when THE CHOICE opens: the
// colourful one onto the uplink dais (ASCEND), the cyber-outline one onto sanctuary tier 2 over the extraction
// pad (EXTRACT). _tod_rocket.gsc flies every flight as a cubic Hermite through the KEYS below (points + unit
// tangents, in ship-PIVOT positions) on a speed profile scaled to the path's length; tools/rocket/
// test_rocket_ride.js RUNS that GSC over these keys and proves the hull and the ride camera clear every visible
// brush, stay inside the sky seal and never snap. RE-AUTHOR A FLIGHT THERE (tools/rocket/ride_check.js), not here.
//   THE ASCEND: straight up off the dais to 21000, the pitch-over out between the crown's NS arch and its
//     front points (the arch underside is 24070+ over the hall; the open sky is |x| > 240 south of the EW arch),
//     over the apex and a steepening dive onto a STRAIGHT 70-degree line into the Endless Spire's NORTH-WEST
//     CORNER (the arena's open rim: the stair spiral roofs everything inside it), where the ship stays as the
//     burnt wreck, nose buried, leaning 20 deg out over the void - visible from the arrival ring.
//   THE EXTRACT: straight up off the sanctuary, a 13-degree drift out from under the arch crossing (the pad is
//     under both arches) while the end screen comes up, then straight up to 36000.
// AUTHORED FOR CM +1 (the crown north of the tower): a LAPS parity change mirrors the crown and these keys with it
// would fly into it - re-author them (the gate fails first).
// THE SWITCH: TOD_ROCKETS=0 (or off / false / no / none) builds the map WITHOUT them - rocket_enabled() answers
// false (the old extraction pad + dais teleporter choice runs) and no clip entities are emitted (the .map is the
// pre-rocket map byte for byte). Everything else below still computes, so the asserts keep guarding the data.
// ===========================================================================
const ROCKETS = !/^(0|off|false|no|none)$/i.test(String(process.env.TOD_ROCKETS || '').trim());
const RK_SHIP = FAN_PROPS.rocket_spire, RK_EXIT = FAN_PROPS.rocket_extract;
if (!RK_SHIP || !RK_SHIP.rocket || !RK_EXIT || !RK_EXIT.rocket) throw new Error('art/fan_props/manifest.json has no rocket_spire / rocket_extract measurements - run tools/fan_props/build_fan_props.py -- --only rocket_spire,rocket_extract');
if (CM !== 1) throw new Error('THE ROCKETS: the flights are authored for the crown at CM +1 - re-author them (tools/rocket/ride_check.js)');
const RK_LEN = RK_SHIP.rocket.len;
if (Math.abs(RK_EXIT.rocket.len - RK_LEN) > 0.5) throw new Error('the two rockets must share one length (ROCKET_H in build_fan_props.py)');
const RK_FEET_R = Math.max(RK_SHIP.rocket.feet_r, RK_EXIT.rocket.feet_r);
const RK_MAX_R = Math.max(RK_SHIP.rocket.max_r, RK_EXIT.rocket.max_r);
const RK_BELL_X = Math.max(RK_SHIP.rocket.bell[0], RK_EXIT.rocket.bell[0]);
const RK_BODY_R = RK_SHIP.rocket.profile.map((q, i) => Math.max(q[1], RK_EXIT.rocket.profile[i][1]));   // 41 stations
const RK_MAXR_AT = RK_SHIP.rocket.profile.map((q, i) => Math.max(q[2], RK_EXIT.rocket.profile[i][2]));
const rkR = (prof, x) => { const f = Math.max(0, Math.min(40, x * 40 / RK_LEN)), i = Math.min(39, Math.floor(f)); return prof[i] + (prof[i + 1] - prof[i]) * (f - i); };
const rkN = (x, y, z) => { const l = Math.hypot(x, y, z); return [x / l, y / l, z / l]; };
const rkR2 = v => v.map(x => Math.round(x * 100) / 100);
// WHERE THEY STAND (the pivot: the fins' feet, on the axis)
const RK_SHIP_FEET = [0, HYC, TOP2 + DAIS_H];           // on the uplink dais
const RK_EXIT_FEET = [0, EXFIL_Y, TOP2 + 32];           // on sanctuary tier 2; the pad (8 tall) sits under its belly
if (RK_FEET_R > DAIS - 2) throw new Error(`rocket feet ${RK_FEET_R} overhang the uplink dais (${DAIS})`);
if (EXFIL_Y - RK_FEET_R < SANC_Y1 + 40 + 4) throw new Error('extract rocket feet off the south edge of sanctuary tier 2');
if (RK_FEET_R > SANC_X2 - 8) throw new Error('extract rocket feet off sanctuary tier 2 sideways');
if (EXFIL_Y + RK_MAX_R > RER_Y1 - 16 - 24) throw new Error('extract rocket within 24 of the reredos stone');
// the boarding prompts: in open air RK_FEET_R + 56 out from each ship's axis - the same ring a landing pushes
// anyone under a ship onto.
// v19.68t A RING OF THEM (user 2026-10-02: "The trigger for the ascend or extract space ships should be all around
// the spaceship. Not just one side"). v19.68r had ONE prompt, on the NAVE side. Now RK_RING_N spots every
// 360 / RK_RING_N degrees on that circle, each a trigger_radius_use of RK_TRIG_R x RK_TRIG_H (neighbours overlap:
// the chord 2 R sin(180 / N) is asserted under 2 RK_TRIG_R, so the ring has no gap). A spot is DROPPED where its
// origin would sit in, or within RK_RING_CLEAR of, any solid at the trigger's height - the reredos, a pier, the
// hall wall, a clip (the dead-trigger trap: a use-trigger sight-traces to its origin and never prompts from inside
// a solid; memory trigger-origin-under-decal). Spot 0 IS the old nave-side prompt and must survive (asserted).
// _tod_rocket.gsc::board_trigger spawns one trigger per spot from the generated rocket_trigs( kind ); all of a
// ship's spots share its one hint string and its one choice (the first committed hold wins).
const RK_TRIG_OUT = RK_FEET_R + 56;
const RK_TRIG_R = 84, RK_TRIG_H = 96, RK_TRIG_LIFT = 40;
const RK_RING_N = 8, RK_RING_CLEAR = 16;
if (2 * RK_TRIG_OUT * Math.sin(Math.PI / RK_RING_N) >= 2 * RK_TRIG_R) throw new Error('the rocket prompt ring has gaps between its spots - raise RK_RING_N');
const RK_SHIP_TRIG = [0, HYC - RK_TRIG_OUT, TOP2 + RK_TRIG_LIFT];      // ring spot 0, the nave side (v19.68r's one prompt)
const RK_EXIT_TRIG = [0, EXFIL_Y - RK_TRIG_OUT, TOP2 + RK_TRIG_LIFT];
if (Math.abs(RK_SHIP_TRIG[1] - HYC) < DAIS + 16) throw new Error('spire rocket prompt over the dais');
if (RK_EXIT_TRIG[1] > SANC_Y1) throw new Error('extract rocket prompt origin over the sanctuary tiers (keep it on the floor in front of them)');
function rkRing(kind, feet) {
  const kept = [], dropped = [];
  for (let k = 0; k < RK_RING_N; k++) {
    const a = -Math.PI / 2 + k * 2 * Math.PI / RK_RING_N;          // k = 0: due south, the nave side
    const p = [feet[0] + Math.cos(a) * RK_TRIG_OUT, feet[1] + Math.sin(a) * RK_TRIG_OUT, TOP2 + RK_TRIG_LIFT].map(v => Math.round(v * 100) / 100);
    const hit = ALL_BOXES.find(b => !/^(trigger|volume|sky)/.test(b.tex)
      && p[2] >= b.z1 - 1 && p[2] <= b.z2 + 1
      && p[0] > b.x1 - RK_RING_CLEAR && p[0] < b.x2 + RK_RING_CLEAR && p[1] > b.y1 - RK_RING_CLEAR && p[1] < b.y2 + RK_RING_CLEAR);
    (hit ? dropped : kept).push(hit ? { k, p, by: hit.label } : { k, p });
  }
  if (!kept.length || kept[0].k !== 0) throw new Error(`the ${kind} rocket's nave-side prompt (ring spot 0) is in a solid`);
  if (kept.length < 4) throw new Error(`only ${kept.length} of the ${kind} rocket's ${RK_RING_N} prompt spots are open: ${dropped.map(d => d.k + ' (' + d.by + ')').join(', ')}`);
  return { kept, dropped };
}
const RK_RING = ROCKETS ? { spire: rkRing('spire', RK_SHIP_FEET), extract: rkRing('extract', RK_EXIT_FEET) } : { spire: { kept: [{ k: 0, p: RK_SHIP_TRIG }], dropped: [] }, extract: { kept: [{ k: 0, p: RK_EXIT_TRIG }], dropped: [] } };
for (const kind of ['spire', 'extract'])
  console.log(`rocket prompts ${kind}: ${RK_RING[kind].kept.length} of ${RK_RING_N} spots round the ship${RK_RING[kind].dropped.length ? ' (dropped ' + RK_RING[kind].dropped.map(d => (d.k * 360 / RK_RING_N) + ' deg: ' + d.by).join('; ') + ')' : ''}`);
// THE CRASH (spire frame) - v19.68s (user, after the first ride: "it should land in the corner area not the wall"):
// the nose drives into the FLOOR of the arena's north-west corner - the 104-square where the W and N walkways meet,
// in full view of the arrival - and the ship stays there, leaning RK_WRECK_LEAN degrees out (north-west) along its
// own dive. The hull is 126 across and the corner 104, so THE CRASH BREAKS THE CORNER: wall N and wall W stop where
// the hull leans out over them, a broken stub (RK_STUB_H) runs under it with stepped rubble at each break, and the
// invisible boundary clip comes down to the stub so the arena stays closed (RK_CORNER, read by section 6a). The lower
// hull wears its own clip (`rocket wreck body`, a model-backed clip column: lint_tod_geometry MODEL_CLIP_COLUMNS) so
// nobody walks into it; the corner's zombie riser moves out along the north walkway (6f) and the corner light steps
// in off the hull (6e). TOD_ROCKETS=0 keeps the whole old corner. (v19.68r buried the nose in the corner PILLAR: the
// wreck stood behind the wall - the user's first ride.)
const RK_WRECK_LEAN = 20, RK_WRECK_BURY = 20, RK_WRECK_ROLL = 17;
const RK_TIP = [SP_X - 460, SP_Y + 470, 6];                                              // the nose at impact: on the corner floor
const rkL = RK_WRECK_LEAN * Math.PI / 180;
// THE SPIRE FLIGHT'S PLANE: the whole ascend ride lies in the vertical plane from the dais to the crash, heading
// RK_SH - so the chase camera's "up" (tod_rocket::rk_cam, the ship's right hand x the flight) never leaves it - and
// the wreck leans back along it, toward where the ship came from
const RK_SH = rkN(RK_TIP[0] - 0, RK_TIP[1] - HYC, 0);
const RK_NC = [Math.sin(rkL) * RK_SH[0], Math.sin(rkL) * RK_SH[1], -Math.cos(rkL)];   // the nose: down, along the flight
const RK_CRASH_PIV = RK_TIP.map((v, i) => v - RK_NC[i] * RK_LEN);                        // the pivot as the nose arrives
const RK_WRECK_PIV = RK_TIP.map((v, i) => v + RK_NC[i] * RK_WRECK_BURY - RK_NC[i] * RK_LEN);
const RK_WRECK_ANG = [Math.round(-Math.atan2(RK_NC[2], Math.hypot(RK_NC[0], RK_NC[1])) * 180 / Math.PI * 100) / 100,
                      Math.round(Math.atan2(RK_NC[1], RK_NC[0]) * 180 / Math.PI * 100) / 100, RK_WRECK_ROLL];
const RK_STUB_H = 40;                         // the broken corner walls under the hull
const RK_WRECK_CLIP_TOP = 160;                // the wreck's clip column: higher than any jump
const RK_NW_LIGHT = ROCKETS ? [-440, 440] : [-470, 470];   // spire light base 3 (6e), off the hull
// the wreck's hull, spire-local: every 10 units its centre, max radius (fins included) and body radius
const RK_WRECK_HULL = [];
for (let x = 0; x <= RK_LEN - RK_WRECK_BURY; x += 10) {
  const c = RK_WRECK_PIV.map((v, i) => v + RK_NC[i] * x);
  RK_WRECK_HULL.push({ x, c: [c[0] - SP_X, c[1] - SP_Y, c[2]], r: rkR(RK_MAXR_AT, x), rb: rkR(RK_BODY_R, x) });
}
// a point's distance to a spire-local box [x1, x2, y1, y2, z1, z2]; the hull's clearance from a box (< 0 = inside)
const rkBoxDist = (p, b) => Math.hypot(Math.max(0, b[0] - p[0], p[0] - b[1]), Math.max(0, b[2] - p[1], p[1] - b[3]), Math.max(0, b[4] - p[2], p[2] - b[5]));
const rkHullClear = b => Math.min(...RK_WRECK_HULL.map(h => rkBoxDist(h.c, b) - h.r));
const RK_CORNER = (() => {
  if (!ROCKETS) return null;
  const M = 8, G = 20;
  // THE BREAK: every y of wall W (x -560..-540) and every x of wall N (y 540..560) a hull sphere (max radius + M)
  // reaches between the stub top and the wall top, rounded out to the 20-unit grid
  let wy = Infinity, nx = -Infinity;
  for (const h of RK_WRECK_HULL) {
    const R = h.r + M;
    const dz = Math.max(0, RK_STUB_H - h.c[2], h.c[2] - BASE_WALL_H);
    const dW = Math.max(0, -(ARENA + WALL) - h.c[0], h.c[0] + ARENA);
    if (dW * dW + dz * dz < R * R) wy = Math.min(wy, h.c[1] - Math.sqrt(R * R - dW * dW - dz * dz));
    const dN = Math.max(0, ARENA - h.c[1], h.c[1] - (ARENA + WALL));
    if (dN * dN + dz * dz < R * R) nx = Math.max(nx, h.c[0] + Math.sqrt(R * R - dN * dN - dz * dz));
  }
  if (!isFinite(wy) || !isFinite(nx)) throw new Error('the rocket wreck never reaches the corner walls - re-check RK_TIP (the break would be empty)');
  wy = Math.floor(wy / G) * G;
  nx = Math.ceil(nx / G) * G;
  if (wy < 200 || nx > -200) throw new Error(`the rocket crash break runs too far (wall W from y ${wy}, wall N to x ${nx})`);
  const out = { wy, nx, rubble: [], clip: null };
  // the stubs under the hull clear it
  for (const [label, b] of [['W', [-(ARENA + WALL), -ARENA, wy, ARENA, 0, RK_STUB_H]], ['N', [-(ARENA + WALL), nx, ARENA, ARENA + WALL, 0, RK_STUB_H]]]) {
    const cl = rkHullClear(b);
    if (cl < M) throw new Error(`the rocket crash stub ${label} is ${cl.toFixed(1)} from the hull (want ${M})`);
  }
  // the broken ends: each wall CRUMBLES down to the break over its last 40 units (two 20-unit steps, 100 then 72
  // tall - outside the hull's path, asserted), so the break reads as smashed rather than cut
  for (const [d, top] of [[40, 100], [20, 72]]) {
    const w = [-(ARENA + WALL), -ARENA, wy - d, wy - d + 20, 0, top];
    const n = [nx + d - 20, nx + d, ARENA, ARENA + WALL, 0, top];
    for (const [label, b] of [[`rocket crash crumble W ${top}`, w], [`rocket crash crumble N ${top}`, n]]) {
      const cl = rkHullClear(b);
      if (cl < M) throw new Error(`${label} is ${cl.toFixed(1)} from the hull (want ${M})`);
      out.rubble.push({ label, b });
    }
  }
  // THE WRECK'S CLIP: a square column round every hull station below its top, inside the arena (outside it the
  // stub and the boundary clip close the corner)
  let x1 = Infinity, x2 = -Infinity, y1 = Infinity, y2 = -Infinity;
  for (const h of RK_WRECK_HULL) {
    if (h.c[2] - h.rb > RK_WRECK_CLIP_TOP || h.c[2] + h.rb < 0) continue;
    x1 = Math.min(x1, h.c[0] - h.rb); x2 = Math.max(x2, h.c[0] + h.rb);
    y1 = Math.min(y1, h.c[1] - h.rb); y2 = Math.max(y2, h.c[1] + h.rb);
  }
  const snap = v => Math.round(v / 4) * 4;
  out.clip = [snap(Math.max(x1 - 4, -ARENA)), snap(x2 + 4), snap(y1 - 4), snap(Math.min(y2 + 4, ARENA)), 0, RK_WRECK_CLIP_TOP];
  if (out.clip[1] > -(PX + PARA) + 80 || out.clip[2] < PX + PARA - 80) throw new Error(`the rocket wreck clip ${out.clip} reaches too far under the NW landing`);
  return out;
})();
{
  // the buried nose is IN the corner floor; every hull station stands clear of the stair footprint (|x|,|y| <=
  // PX + PARA round the spire axis) and of the corner light; nothing of it sinks under the slab
  const tipB = RK_TIP.map((v, i) => v + RK_NC[i] * RK_WRECK_BURY);
  const bx = tipB[0] - SP_X, by = tipB[1] - SP_Y;
  if (!(bx >= -ARENA && bx <= -(PX + PARA) && by >= PX + PARA && by <= ARENA && tipB[2] > -SLAB && tipB[2] < 0))
    throw new Error(`rocket wreck nose ${rkR2(tipB)} is not buried in the arena's NW corner floor`);
  const stair = PX + PARA;
  for (const h of RK_WRECK_HULL) {
    const dStair = Math.hypot(Math.max(0, Math.abs(h.c[0]) - stair), Math.max(0, Math.abs(h.c[1]) - stair));
    if (dStair < h.r + 8) throw new Error(`rocket wreck ${h.x} up its hull within ${(dStair - h.r).toFixed(1)} of the spire stair footprint`);
    if (h.c[2] - h.rb < -SLAB - 40) throw new Error('rocket wreck sinks under the spire slab');
    // the light moves off the hull only when the wreck is there (TOD_ROCKETS=0 keeps the old light AND no wreck)
    const lt = Math.hypot(h.c[0] - RK_NW_LIGHT[0], h.c[1] - RK_NW_LIGHT[1], h.c[2] - 240);
    if (ROCKETS && lt < h.rb + 30) throw new Error(`rocket wreck hull within ${(lt - h.rb).toFixed(1)} of the spire base light at the NW corner (want 30)`);
  }
}
// the arrival faces the wreck (the white burns away onto it): from the arrival mark to the wreck's middle
const RK_WRECK_MID = RK_WRECK_PIV.map((v, i) => v + RK_NC[i] * RK_LEN * 0.5);
const RK_ARRIVAL_YAW = Math.round(Math.atan2(RK_WRECK_MID[1] - SP_Y, RK_WRECK_MID[0] - (SP_X - 400)) * 180 / Math.PI * 10) / 10;
// THE FLIGHTS (ship-pivot keys + unit tangents), checked by tools/rocket/test_rocket_ride.js (every hull sphere >= 12
// clear, the camera >= 28 clear, <= 7.5 deg a frame). v19.68s: THE ASCEND IS ONE CIRCLE IN RK_SH'S PLANE - straight
// up off the dais to RK_ARC_Z, then a single circle from straight up over the top into the dive direction, its radius
// SOLVED so it ends on the dive line, then the straight RK_WRECK_LEAN dive into the corner. A circle turns at a
// constant v / R the chase camera can follow. (v19.68r's keys bunched the turn at the apex and dropped the ship
// near-vertically for two seconds before its dive: harmless for a camera on the hull, a whipping view above it.)
const rkDive = d => RK_CRASH_PIV.map((v, i) => v - RK_NC[i] * d);    // a point d back up the final dive line
const rkPlane = (s, z) => [RK_SH[0] * s, HYC + RK_SH[1] * s, z];    // s along the heading from the dais, at height z
const rkPlaneT = a => { const r = a * Math.PI / 180; return rkN(RK_SH[0] * Math.sin(r), RK_SH[1] * Math.sin(r), Math.cos(r)); };   // a = degrees from straight up
const RK_ARC_Z = 21000;
const rkPivS = RK_CRASH_PIV[0] * RK_SH[0] + (RK_CRASH_PIV[1] - HYC) * RK_SH[1];   // the crash pivot along the heading
// a circle starting straight up at (0, RK_ARC_Z) ends heading RK_WRECK_LEAN off straight down at
// (R (1 + cos L), RK_ARC_Z + R sin L): on the dive line through the pivot when R is
const RK_ARC_R = (rkPivS - (RK_ARC_Z - RK_CRASH_PIV[2]) * Math.tan(rkL)) / (1 + 1 / Math.cos(rkL));
const rkArc = deg => { const f = deg * Math.PI / 180; return rkPlane(RK_ARC_R * (1 - Math.cos(f)), RK_ARC_Z + RK_ARC_R * Math.sin(f)); };
const RK_ARC_END = 180 - RK_WRECK_LEAN;
const RK_FLIGHT = {
  spire: {
    keys: [RK_SHIP_FEET, rkArc(0), rkArc(RK_ARC_END * 0.25), rkArc(RK_ARC_END * 0.5), rkArc(RK_ARC_END * 0.75), rkArc(RK_ARC_END), RK_CRASH_PIV],
    tans: [[0, 0, 1], [0, 0, 1], rkPlaneT(RK_ARC_END * 0.25), rkPlaneT(RK_ARC_END * 0.5), rkPlaneT(RK_ARC_END * 0.75), RK_NC, RK_NC],
  },
  extract: {
    keys: [RK_EXIT_FEET, [0, EXFIL_Y, 20600], [420, 8700, 22700], [700, 8400, 24200], [800, 8300, 26000], [820, 8280, 36000]],
    tans: [[0, 0, 1], [0, 0, 1], rkN(0.20, -0.20, 0.96), rkN(0.12, -0.12, 0.985), [0, 0, 1], [0, 0, 1]],
  },
  land_spire: {
    keys: [[2600, 6300, 28000], [900, 7800, 23800], [0, HYC, 21900], RK_SHIP_FEET],
    tans: [rkN(-0.5, 0.45, -0.74), rkN(-0.35, 0.32, -0.88), [0, 0, -1], [0, 0, -1]],
  },
  land_extract: {
    keys: [[-2400, 6600, 28000], [-860, 8240, 24200], [-500, 8620, 23000], [0, EXFIL_Y, 22200], RK_EXIT_FEET],
    tans: [rkN(0.5, 0.4, -0.77), rkN(0.25, 0.3, -0.92), rkN(0.45, 0.45, -0.77), [0, 0, -1], [0, 0, -1]],
  },
};
if (RK_FLIGHT.extract.keys[RK_FLIGHT.extract.keys.length - 1][2] + RK_LEN + 600 > SKY_TOP) throw new Error('the extract climb ends within 600 of the sky ceiling');
{
  // the circle's end IS on the dive line (the solve), and it is a real arc (radius) above the crown hall
  const e = rkArc(RK_ARC_END), t = Math.tan(rkL);
  const eS = e[0] * RK_SH[0] + (e[1] - HYC) * RK_SH[1];
  const onLine = rkPivS - (e[2] - RK_CRASH_PIV[2]) * t;
  if (Math.abs(eS - onLine) > 0.5) throw new Error(`the ascend's arc ends ${(eS - onLine).toFixed(1)} off its dive line`);
  if (!(RK_ARC_R > 1500)) throw new Error(`the ascend's arc radius ${RK_ARC_R.toFixed(0)} is too tight for the chase camera`);
}
// each ship stands with its yaw on its flight's first lean (so straight up never spins it), and its ride camera
// hangs off its RIGHT hand: horizontal, square to that heading (tod_rocket::rk_cam)
const rkYaw = k => { const a = RK_FLIGHT[k].keys[0], b = RK_FLIGHT[k].keys[2]; return Math.round(Math.atan2(b[1] - a[1], b[0] - a[0]) * 180 / Math.PI * 10) / 10; };
const RK_YAW = { spire: rkYaw('spire'), extract: rkYaw('extract') };
const rkRight = k => { const a = RK_YAW[k] * Math.PI / 180; return [Math.sin(a), -Math.cos(a), 0].map(x => Math.round(x * 10000) / 10000); };
// THE RIDE CAMERA (v19.68s, the chase camera - tod_rocket::rk_cam): it turns about the ship's RIGHT hand R = z x S,
// S = the side the camera starts on, beside the ship on its pad (horizontal; it must point BEHIND the flight's
// heading, or "up" turns over in the cruise). The spire ship's is straight behind its heading (the pitch-over then
// swings the camera up over the ship, where it stays); the extract ship's is south-west of its pad, between the
// sanctuary's west piers and the dais (it never cruises, so "behind" only has to hold while it climbs).
const RK_CAM_SIDE = { spire: null, extract: [-0.8, -0.6] };
const rkCamRight = k => {
  if (!RK_CAM_SIDE[k]) return rkRight(k);
  const s = RK_CAM_SIDE[k], l = Math.hypot(s[0], s[1]);
  return [-s[1] / l, s[0] / l, 0].map(x => Math.round(x * 10000) / 10000);
};
// the clips: an octagon prism round the fins (to +100) and one round the body (to the nose) - script_brushmodels,
// open at load, made solid by _tod_rocket only while a ship stands (the wreck's own clip is RK_CORNER.clip, 6a)
const RK_CLIP_FIN_APO = 100, RK_CLIP_BODY_APO = 66, RK_CLIP_FIN_TOP = 100;
// (the stations under the fin prism's top belong to the fin prism: the base slice's percentile is the fin feet)
if (RK_CLIP_BODY_APO < Math.max(...RK_BODY_R.slice(Math.ceil(RK_CLIP_FIN_TOP * 40 / RK_LEN)))) throw new Error('the rocket body clip is thinner than the hull');
if (RK_CLIP_FIN_APO < RK_FEET_R - 10) throw new Error('the rocket fin clip leaves the feet sticking out more than 10');

// ---------------------------------------------------------------------------
// Entities
// ---------------------------------------------------------------------------
const entities = [];
function ent(label, lines) { entities.push({ label, text: lines.join('\n') }); }
function kv(k, v) { return `"${k}" "${v}"`; }

function volumeBrush(x1, x2, y1, y2, z1, z2) {
  const t = 'volume 64 64 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0';
  return [
    '{',
    ` guid "${guid()}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,
    ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`,
    '}',
  ].join('\n');
}
function matBrush(x1, x2, y1, y2, z1, z2, mat) {
  return box(x1, x2, y1, y2, z1, z2, mat);
}

// mirrored volume brush (crown zones) — same re-ordering rule as cbox
function cvolume(x1, x2, y1, y2, z1, z2) {
  return CM === 1 ? volumeBrush(x1, x2, y1, y2, z1, z2) : volumeBrush(-x2, -x1, -y2, -y1, z1, z2);
}
// mirrored {x1,x2,y1,y2,z1,z2} spec (door slab/trig/clip boxes)
function cspec(s) {
  return CM === 1 ? s : { x1: -s.x2, x2: -s.x1, y1: -s.y2, y2: -s.y1, z1: s.z1, z2: s.z2 };
}

// --- zones + spawners -------------------------------------------------------
// v9: the FINAL lap's volumes stop just above its last landing (TOP+100) —
// stock-height ring volumes (b+LAP_RISE+200) would swallow the crown stair
// and the terrace, and level.zones iteration order would then report every
// player up there as "lap50_zone" forever. The crown stair past the door
// belongs to roof_zone (its volumes start at TOP-SLAB).
function lapVolumeBrushes(lapBase, isLast) {
  const z1 = lapBase - SLAB, z2 = isLast ? TOP + 100 : lapBase + LAP_RISE + 200;
  return [
    volumeBrush(CORE, PX + PARA, -CORE, CORE, z1, z2),
    volumeBrush(-PX - PARA, -CORE, -CORE, CORE, z1, z2),
    volumeBrush(-PX - PARA, PX + PARA, CORE, PX + PARA, z1, z2),
    volumeBrush(-PX - PARA, PX + PARA, -PX - PARA, -CORE, z1, z2),
  ];
}

// Riser points down the causeway. Section 5c owns WHERE they go, because only
// the code that lays the road knows where the road actually is (see roof_zone
// below for why that matters now).
function causewayRisers() { return causewayRunPoints(); }

const ZONES = [
  {
    name: 'base_zone',
    brushes: [
      volumeBrush(-(ARENA + WALL), ARENA + WALL, -(ARENA + WALL), ARENA + WALL, -SLAB, 368),
      // THE POWER HALLWAY'S EXTERIOR LEG MOVED OUT OF base_zone (v13.1) into
      // power_zone below, for the reason the teleport bay is its own zone: it
      // is a SEALED room until enter_power is bought, and base_zone is live
      // from round 1, so the riser this change adds would have spawned zombies
      // behind a DisconnectPaths'd door with no way out — actor slots burnt on
      // enemies nobody can reach or kill. Coverage is not lost, only deferred:
      // power_zone carries the same volume and goes live on the same flag, and
      // nothing can drop in there before the door opens because nothing can
      // die in there. The 20u threshold strip x[540,560] (the gap cut through
      // the arena's east wall) stays base_zone — it holds no riser, and
      // carving it out of the arena box would cost a brush to buy nothing.
    ],
    // SE riser: the (470,-470) corner is now the POWER ROOM, and the y=-360
    // relocation (user 2026-08-20) still landed it in a dead pocket — the east
    // gutter (x[416,540]) is sealed from the walkway by the lap1 anti-bypass
    // wall (x416..436, y[-256,256], z0..288) and capped on the south by the
    // power-room north wall (y=-400), so a zombie there could only mill at the
    // first-door corner (user 2026-08-21: "stuck at a wall near the first stair
    // door"). Moved ONTO the open walkway ring, south of the E-flight base and
    // the door slab (y=-256), where it paths freely to the arena and up.
    risers: [[-470, -470, 0], [336, -336, 0], [-470, 470, 0], [470, 470, 0]],
    dog: [0, -470, 0],
  },
];
for (let lap = 1; lap <= LAPS; lap++) {
  const b = (lap - 1) * LAP_RISE;
  const oddz = (lap % 2 === 1);
  const brushes = lapVolumeBrushes(b, lap === LAPS);
  if (BREATHER_LAPS.has(lap)) {
    // the lounge footprint sits outside the ring volumes — cover it (mirrored
    // by parity), plus the v13 teleporter spur (gantry + pad platform, with
    // margin past the rails). A point outside every zone volume gets no spawn
    // logic and no drop logic, and nothing says so until someone plays it.
    brushes.push(oddz
      ? volumeBrush(CORE - PARA, PX + BR_EAST + PARA, PX, PX + BR_DEPTH + PARA, b - SLAB, b + LAP_RISE + 200)
      : volumeBrush(-(PX + BR_EAST + PARA), -(CORE - PARA), -(PX + BR_DEPTH + PARA), -PX, b - SLAB, b + LAP_RISE + 200));
    brushes.push(oddz
      ? volumeBrush(SPUR_CX - 184, SPUR_CX + 184, PX + BR_DEPTH, SPUR_Y2 + 40, b - SLAB, b + LAP_RISE + 200)
      : volumeBrush(-(SPUR_CX + 184), -(SPUR_CX - 184), -(SPUR_Y2 + 40), -(PX + BR_DEPTH), b - SLAB, b + LAP_RISE + 200));

  }
  // BREATHERS NOW SPAWN (v10.12, user 2026-08-23 after the full playthrough:
  // "The safe breather zones need to be a lot less safe. Its to easy to camp
  // there so maybe we need to add a some zombie spawns there").
  //
  // THIS REVERSES THE 2026-08-20 DECISION ON PURPOSE, so the old reasoning is
  // kept here rather than deleted: breathers were given ZERO risers so the
  // horde had to climb to you and the balcony became a real holdout stop. In
  // play that landed too far the other way — a zero-riser balcony with a
  // teleporter, a PaP and two perk machines is not a rest stop, it is a camp
  // with amenities, and the only pressure was whatever walked up the stairs.
  //
  // The balconies get TWO risers, the same count as an ordinary floor — the
  // pacing beat now comes from the balcony being LARGE and open rather than
  // from it being empty. All four breather laps are EVEN, so every lounge is
  // the mirrored SW one: floor x[-800,-256] y[-992,-416].
  // PLACED AT THE TWO WEST CORNERS, still the clearest ground after the v13
  // relayout (clearances re-measured against BR_FURN): the north riser
  // (-750,-460) sits 220u from the W-wall PaP model and 250u from the N-wall
  // station; the south riser (-750,-950) stands 42u inside the spur doorway
  // (x[-784,-624] in the S wall) ON PURPOSE — zombies boil up right at the
  // gate, so the teleporter annex is never a quiet camp pocket. Both stay
  // clear of the perk wall (y=-959, x -360/-536) and the v10.4 respawn spawns
  // (x -340/-460, y -640/-780). Zombies emerge IN the lounge instead of only
  // arriving up the stairs.
  //
  // v13.2 (user 2026-08-28: "add one zombie spawn in the path from breather
  // and teleporter for each zone") — THE SPUR GETS ITS OWN RISER, mid-gantry.
  // This retires v13's "the spur emits NO risers, pressure walks in through
  // the gate" stance (and the docs/42 watch item that predicted this exact
  // retune): with only door-side pressure the gantry+pad annex was still a
  // one-entrance pocket. The y is DERIVED from the up-teleport arrival point
  // (SPUR_PAD_Y - TP_ARRIVE_OFF, even-frame y=-1296) minus 176, so the v10.22
  // rule (riser >= ~165u from any point players materialize on) holds by
  // construction and survives any spur re-proportioning. Clearances at the
  // emitted spot (-704,-1120): arrival 176u; pad centre 336u (gather ring 120
  // -> 216u past its edge); gate posts (y ends -1060) 60u behind the riser, so
  // zombies surface OUTSIDE the gate on the open gantry, cutting the walkway
  // between a player on the pad and the room; lounge deck riser (-750,-950)
  // ~176u away — no stacked spawn events on one strip (the power-hall rule);
  // centred between the gantry rails, 80u each side.
  // NOTE FOR THE BAKE: this adds NO brushes — risers are spawn structs, so the
  // LED atlas is untouched by this change.
  const brz = b + FLIGHT_RISE;   // the balcony sits on the floor's MID landing
  const spurRiserY = -(SPUR_PAD_Y - TP_ARRIVE_OFF - 176);   // -1120
  ZONES.push({
    name: `lap${lap}_zone`,
    brushes: brushes,
    risers: BREATHER_LAPS.has(lap)
      ? [[-750, -460, brz], [-750, -950, brz], [-SPUR_CX, spurRiserY, brz]]
      : (oddz
      ? [[336, 336, b + FLIGHT_RISE], [-336, 336, b + LAP_RISE]]
      : [[-336, -336, b + FLIGHT_RISE], [336, -336, b + LAP_RISE]]),
    dog: oddz ? [336, 336, b + FLIGHT_RISE] : [-336, -336, b + FLIGHT_RISE],
  });
  // THE BREATHER LAPS HAVE NO LANDING SEED (found 2026-09-04). The navmesh
  // seeds below §5 are emitted one per entry of `zn.risers`, and the seed
  // block's own comment justifies that by asserting "the tower's two risers
  // per lap sit on the mid and end landings". That is true for 46 laps and
  // FALSE for laps 10/20/30/40: v10.12/v13.2 moved their risers into the
  // lounge and onto the teleporter spur, so the spiral's own two landings on
  // those floors were left unseeded — a 384-unit z band of staircase with no
  // seed on it, four times up the tower, and nothing said so because the
  // riser table is a GAMEPLAY table that no longer matched the sentence
  // written about it. Parsed out of the emitted .map to confirm before fixing:
  // the tower's 149 seeds have z gaps of exactly 384 at 3650, 7490, 11330 and
  // 15170, and nowhere else.
  //
  // Seeded from the GEOMETRY here rather than from the riser table, which is
  // the whole point — a spawn table must never be a coverage table again.
  if (BREATHER_LAPS.has(lap)) {
    const mz = b + FLIGHT_RISE, ez = b + LAP_RISE;
    if (oddz) {
      navSeed(`lap${lap} mid landing`, 336, 336, mz + 2);
      navSeed(`lap${lap} end landing`, -336, 336, ez + 2);
    } else {
      navSeed(`lap${lap} mid landing`, -336, -336, mz + 2);
      navSeed(`lap${lap} end landing`, 336, -336, ez + 2);
    }
  }
}
// roof_zone (v9) = the crown: stair + terrace, causeway, hall. Risers in the
// hall's four quarters (they dig up through the citadel floor) and two on the
// terrace ends; the dog/fallback struct at the hall centre.
ZONES.push({
  name: 'roof_zone',
  brushes: [
    cvolume(-TER_W - PARA, TER_W + PARA, -CORE, TER_Y2 + PARA, TOP - SLAB, TOP2 + 400),          // crown stair + terrace
    // BOUNDING BOX OF THE WHOLE ROAD, MEASURED FROM THE ROAD (v10.12). The
    // doglegs swing to x +/-800 and the branches leave TOP2 in both directions,
    // so this is computed from the declared deck cells rather than written down:
    // anything the volume misses is outside roof_zone, which means no spawns and
    // no zone logic on that piece of road, and nothing says so until someone
    // plays it. A hand-maintained literal here has been wrong twice.
    cvolume(CW_XMIN, CW_XMAX, CW_YMIN, CW_YMAX, CW_ZMIN, CW_ZMAX),                                    // causeway
    cvolume(-HW - 16, HW + 16, HS - 16, HN + 16, TOP2 - SLAB, TOP2 + 700),                       // hall
  ],
  // v10 — THE LAST MILE. The road used to have NO risers, so everything on it
  // had to walk in from the terrace or the hall: a queue, not an ambush.
  // causewayRunPoints() now puts one on EVERY piece of the road — the three
  // on-axis stretches and all four branches — each on its own centreline at its
  // own height (v10.11; the old evenly-spaced x=+/-180 points assumed a straight
  // strip at TOP2 and half of them would now be hanging in mid-air). A party
  // that splits at a fork gets clawed at on both branches at once.
  // Concurrency is NOT set here — level.zombie_ai_limit / zombie_actor_limit
  // still bind (see _tod_finale::finale_director). More risers buys VARIETY OF
  // DIRECTION, never more simultaneous AI, which is exactly the distinction
  // that keeps this from blowing the actor cap. While the gate is shut none of
  // them are eligible at all — _tod_endless_rounds::finale_spawn_selection.
  risers: [
    cpt(-560, HS + 280, TOP2), cpt(560, HS + 280, TOP2),
    cpt(-560, HN - 280, TOP2), cpt(560, HN - 280, TOP2),
    cpt(-400, 368, TOP2), cpt(400, 368, TOP2),
    ...causewayRisers(),
  ],
  dog: cpt(0, HYC, TOP2),
});

// THE TELEPORT BAY ZONE (v10.25). Its own zone rather than part of base_zone so
// that its risers are asleep until `enter_tpbay` is bought — see the TPB_ block.
// The volume meets base_zone exactly at y=-560 (base_zone's own brush stops
// there, and the south wall's footprint belongs to it), so there is neither a
// gap a player can stand in nor an overlap two zones would both claim.
//
// TWO RISERS, and where they go is set by the pads, not by looks. A riser
// closer than ~165u to a pad means a zombie climbs out ON TOP of somebody mid
// teleport (the rule the v10.22 arena bay was spaced by). In a room this small
// the only spots that satisfy it are the two corners flanking the doorway:
//   riser (+-205,-600) -> nearest pad (+-110,-760) = 186u   ok
//                      -> the arrival (0,-620)     = 206u   ok
// which also means they rise BETWEEN the player and the exit — the right
// pressure for a small paid room you are meant to be caught in.
ZONES.push({
  name: 'tpbay_zone',
  brushes: [
    volumeBrush(-(TPB_X + WALL + 20), TPB_X + WALL + 20, TPB_Y1 - WALL - 20, -(ARENA + WALL), -SLAB, 368),
  ],
  risers: [[-TPB_RISER_X, TPB_RISER_Y, 0], [TPB_RISER_X, TPB_RISER_Y, 0]],
  dog: [0, TPB_RISER_Y + 10, 0],
});

// POWER HALL (v13.1, user 2026-08-28: "add one zombie spawn in the power switch
// hallway towards the switch in the back. The issue is players will camp in
// here so adding a spawn might help that").
//
// WHY IT IS ITS OWN ZONE and not two more lines in base_zone: identical to the
// teleport bay's reasoning above. The hall is sealed by the enter_power door
// (slab Solid + DisconnectPaths at x=280) until it is bought, and base_zone is
// live from round 1 — a riser in there on the base's ticket would spawn
// zombies into a corridor with a severed navmesh from the very first round.
// They would path nowhere, die to nothing, and hold actor slots against the
// 45-zombie cap for the whole run. The zone gate is what makes the riser safe.
//
// THE CAMP THIS BREAKS: the hall is a 1,060-long dead end with ONE mouth, so a
// player standing at the east cap covers the only approach and never has to
// turn around. The riser goes BEHIND that firing line, not in front of it —
// west of it and the camp is untouched.
//
// PLACEMENT x=1400, measured rather than eyeballed:
//   corridor walkable  x[560,1620], y[-540,-420] -> centreline y=-480
//   power switch       the v19.69 power terminal (POWER_TERM): face x~1608.6,
//                      USE TRIGGER x[1582,1606] (the lever's was x[1589,1608])
//   riser -> trigger   182u clear (189 with the lever; POWER_TERM asserts >= 165),
//                      so a zombie can never rise standing inside
//                      the switch's trigger and block the buy (the same
//                      no-two-things-in-one-trigger rule the tp-bay pads and
//                      the lounge furniture are spaced by)
//   riser -> east cap  220u — inside the last fifth of the hall, which is the
//                      half a camper actually occupies
//   hall lights (x 800/1200/1560) are z=100 point lights, no collision
// The dog point sits mid-corridor: a hound needs run-up, and dropping one on
// top of the riser would stack two spawn events on one 120-wide strip.
ZONES.push({
  name: 'power_zone',
  brushes: [
    volumeBrush(560, 1660, -580, -380, -SLAB, 368),
  ],
  risers: [[1400, -480, 0]],
  dog: [1100, -480, 0],
});

for (const zn of ZONES) {
  ent(`${zn.name} info_volume`, [
    '{',
    `guid "${guid()}"`,
    kv('classname', 'info_volume'),
    kv('script_noteworthy', 'player_volume'),
    kv('target', `${zn.name}_spawners`),
    kv('targetname', zn.name),
    ...zn.brushes,
    '}',
  ]);
  zn.risers.forEach(([sx, sy, sz], i) => {
    ent(`${zn.name} riser ${i + 1}`, [
      '{',
      `guid "${guid()}"`,
      kv('classname', 'script_struct'),
      kv('angles', '0 270 0'),
      kv('origin', `${sx} ${sy} ${sz}`),
      kv('script_noteworthy', 'riser_location'),
      kv('script_string', 'find_flesh'),
      kv('targetname', `${zn.name}_spawners`),
      kv('_color', '1 0 0'),
      '}',
    ]);
  });
  // NAVMESH SEEDS — THE TOWER (2026-09-03). THE SAME BUG THE SPIRE SHIPPED IN
  // v14.0-v14.18, IN THE OTHER TOWER, AND IT WENT UNSEEDED FOR LONGER.
  //
  // User: "zombies are spawning in and not moving ... only if you get close
  // they move", "if I throw a monkey it disappears instantly and I hear
  // samantha", "around floor 18 ... anything above they wont target". One
  // cause explains all three: NO NAVMESH above ~floor 17. An off-mesh zombie
  // has no path and no find_flesh, so it stands until stock's direct
  // proximity aggro fires; a Cymbal Monkey needs mesh under it to become a
  // zombie_poi and is discarded instantly when there is none; and the Sam
  // laugh is this map's own documented tell for the out-of-playable monitor
  // (zm_tower_of_doom.gsc:532 and :845 — god mode MASKS it, which is why the
  // v17.6 disarm is when it became audible rather than when it broke).
  //
  // WHY IT ONLY BIT NOW. cod2map64 FLOOD-GROWS navmesh from seed entities
  // only (radiant/configs/navmesh.json "seeds": node_*, mp_*spawn*,
  // cp_*spawn*, info_player_start, actor_*). Grep the emitted .map for those
  // classes and the whole 50-floor tower had exactly TWO, both standing on
  // the base arena floor: the factory spawner and info_player_start. Every
  // other thing this file places is on the EXCLUSION list (script_struct,
  // info_volume, script_brushmodel, light, node_*), so nothing seeded a
  // single floor by accident. Fifty floors of spiral were meshed by one flood
  // climbing from z=0, and a flood has a finite reach: it used to clear the
  // tower, and after the floors changed it stopped somewhere around lap 17.
  // The §6f comment below already spelled this mechanism out and named the
  // two base seeds — it fixed the SPIRE and left the tower riding the flood.
  //
  // A SEED PER ZONE IS THE RULE, NOT A PATCH FOR ONE BAD FLOOR. Seeding only
  // where it broke would re-break the moment the geometry moves again, and
  // "which lap does the flood die on" is not a number anything checks. One
  // node_pathnode per RISER (not per zone as §6f does — the tower's two
  // risers per lap sit on the mid and end landings, i.e. one on each flight's
  // top, which is exactly the coverage a flight-by-flight flood wants) makes
  // every landing its own origin, so no lap can be orphaned by the one below
  // it failing to hand the flood upward. node_pathnode is itself on the
  // exclusion list (it carves nothing), is invisible, spawns no runtime
  // gentity and is untargeted by script — zm_giant ships six the same way.
  // Risers stand on proven-open landing floor by construction, so a seed can
  // never land inside a brush.
  //
  // A NEW DETACHED REGION NEEDS ITS OWN SEED — and so does a region the flood
  // merely HAPPENS to reach today. FULL build: the navmesh is what changes.
  zn.risers.forEach(([sx, sy, sz], i) => {
    ent(`${zn.name} navmesh seed ${i + 1}`, [
      '{',
      `guid "${guid()}"`,
      kv('classname', 'node_pathnode'),
      kv('origin', `${sx} ${sy} ${sz + 2}`),
      kv('_color', '1 0 1'),
      '}',
    ]);
  });
  ent(`${zn.name} dog location`, [
    '{',
    `guid "${guid()}"`,
    kv('classname', 'script_struct'),
    kv('origin', `${zn.dog[0]} ${zn.dog[1]} ${zn.dog[2]}`),
    kv('script_noteworthy', 'dog_location'),
    kv('targetname', `${zn.name}_spawners`),
    kv('_color', '1 0 0'),
    '}',
  ]);
}

// --- player start / initial spawns / respawn / intermission -----------------
//
// SPAWN MOVED SOUTH BAND -> WEST BAND (user 2026-08-27: "I do want to make sure
// players dont spawn in at a door buyable in their radius. Currently the spawn
// for the map is outside doors where you can see the trigger as you are
// selecting your class. There is one side of the first floor that has no doors
// or perks. Thats where I want to move the spawn").
//
// THE BUG, MEASURED: _tod_doors spawns a trigger_radius_use of RADIUS 96 at each
// door's org AND at org+off (both sides of the slab). Against the old south-band
// spawns that put SIX OF THE EIGHT start points inside a live buy trigger:
//   (-64,-462) (64,-462)   -> enter_tpbay (0,-530)  93.4u   INSIDE
//   (-64,-498) (64,-498)   -> enter_tpbay (0,-530)  71.6u   INSIDE
//   (192,-462) (192,-498)  -> enter_power (270,-480) 80.0u  INSIDE
// so most of the party stared at a "Hold F to buy" prompt through the whole
// 30-second class draft. The old row also sat 64u from the base dog spawn
// (0,-470).
//
// WHY WEST. Enumerating the base ring by side (ARENA 540 outer, CORE 256 inner,
// so each band is 284 wide):
//   NORTH  9 perk parking pads along y=500 (x -520..520)
//   SOUTH  all three base doors' triggers (enter_tpbay 0,-550 / enter_power
//          270,-480 / and enter_lap1's south reach), the base upgrade station on
//          the core south face (0,-320, trigger 0,-360), intermission, tp-bay
//   EAST   enter_lap1 (336,-256) + the lap1 anti-bypass wall
//   WEST   NOTHING. No door, no perk pad, no station, no wallbuy (this map has
//          none), no box (none either). The class-select stations that used to
//          live at the base were removed 2026-08-20.
// So the west band is the only side with no interactable at all — exactly the
// side the user identified.
//
// PLACEMENT is the old 4x2 grid TRANSPOSED onto the band: 4 points along y at
// the same 128 spacing, 2 rows across x at the same 36 spacing, same z=28. That
// keeps quad/trio/duo/solo behaviour identical — stock fills from the same
// eight-struct list, it just reads different coordinates. Clearances:
//   nearest door trigger .......... 572u (enter_tpbay)   vs the 96u radius
//   base upgrade station trigger .. 491u
//   nearest perk pad (-520,500) ... 313u
//   nearest zombie riser .......... 278u  (-470,-470 and -470,470, tied)
//   base dog spawn (0,-470) ....... 511u
//   west wall face (x=-540) ....... 42u   (identical to the old row's clearance
//                                          from the south wall — same margin)
// All eight sit inside base_zone's volume (it spans the full arena + walls), so
// the start-room group stays selectable exactly as before.
//
// WHAT MOVES WITH THEM: info_player_start, the player_respawn_point GROUP origin
// (its children are these structs — leaving the parent behind would scatter the
// group's distance maths across the arena), and 'tod light base spawn', the
// dedicated warm light that exists to light the spawn. What does NOT move, and
// why: 'probe base' has radius 2048 and covers the whole 1080-wide arena from
// anywhere in it; the intermission camera is a spectator view, not a spawn; and
// _tod_atmosphere's music emitter at (0,-490,100) only needs to be in OPEN AIR
// (its aliases are 2D), which that point still is.
//
// EVERY OTHER KEY ON THESE STRUCTS IS UNCHANGED — in particular
// script_noteworthy "start_room" and the script_string gametype list. A
// player_respawn_point is LOCKED at init and unlocks only by noteworthy match
// (_zm_zonemgr.gsc:827); this map has already shipped an inert respawn group
// once by dropping that key. Only `origin` moves here.
const SPAWN_BAND_X = -480;   // centre of the west band (core face -256, wall -540)
ent('info_player_start', [
  '{', `guid "${guid()}"`, kv('classname', 'info_player_start'),
  kv('angles', '0 90 0'), kv('origin', `${SPAWN_BAND_X - 10} 0 40`), '}',
]);
ent('player_respawn_point', [
  '{', `guid "${guid()}"`, kv('classname', 'script_struct'),
  kv('angles', '0 90 0'), kv('origin', `${SPAWN_BAND_X} 0 28`),
  kv('radius', '2000'), kv('script_int', '2000'),
  kv('script_noteworthy', 'start_room'),
  kv('script_string', 'zclassic_start_room zcleansed_start_room zgrief_start_room'),
  kv('target', 'initial_spawn_points'), kv('targetname', 'player_respawn_point'),
  kv('_color', '1 0 0'), '}',
]);
const SPAWNS = [[-462, -192], [-462, -64], [-462, 64], [-462, 192], [-498, -192], [-498, -64], [-498, 64], [-498, 192]];
SPAWNS.forEach(([sx, sy], i) => {
  ent(`initial spawn ${i + 1}`, [
    '{', `guid "${guid()}"`, kv('classname', 'script_struct'),
    kv('_color', i % 2 ? '1 0 1' : '1 1 0'),
    kv('angles', '0 90 0'), kv('origin', `${sx} ${sy} 28`),
    kv('radius', '32'), kv('script_int', `${(i % 2) + 1}`),
    kv('script_noteworthy', 'initial_spawn'),
    kv('script_string', 'zcleansed_start_room'),
    kv('targetname', 'initial_spawn_points'), '}',
  ]);
});
// --- BREATHER RESPAWN GROUPS (co-op audit 2026-08-23) ------------------------
// The map used to emit exactly ONE player_respawn_point — the base-arena group
// above — and no spawn-override callback anywhere in scripts/. Stock's selector
// therefore had a one-element candidate list, so EVERY bled-out co-op player
// came back at z=28 regardless of how high the party had climbed. A floor-40
// death was a 53,088-unit re-ascent past every door, unperked (nothing sets
// _retain_perks), and because breather balconies deliberately emit no risers the
// lone returning player pulled most of the spawn budget onto himself the whole
// way up. In practice he did not climb — he looped the arrival pad.
//
// Stock picks the group CLOSEST to a living teammate, but only if the group's
// origin sits inside an ENABLED zone (_zm.gsc:3399 check_point_in_enabled_zone).
// So a breather group is automatically ineligible until that lap's door is
// bought, and a party can never respawn past a door it has not paid for. That
// gating is a property of WHERE the struct is; it needs no script support.
//
// script_string is DELIBERATELY OMITTED. get_player_spawns_for_gametype
// (_zm_gametype.gsc:589) filters a struct to matching locations when it carries
// a gametype string and adds it to ALL locations when it does not. The base
// group carries "zclassic_start_room ..." because it IS the start room; these
// are not, and must stay eligible in every mode the map runs in.
//
// `locked` is omitted too, matching the base group — stock never initialises it,
// and only maps that want a spawn disabled ever set it true (zm_giant.gsc:413).
//
// PLACEMENT: all four breather laps are EVEN, so every lounge is the mirrored
// SW one (floor x[-800,-256] y[-992,-416]; zone volume x[-820,-236]
// y[-1012,-416], so all five points below are inside it). Centre-east of the
// room, re-measured against the v13 BR_FURN layout: >=130u from the N-wall
// station trigger (-500,-516), >=230u from the W-wall PaP trigger (-688,-680),
// north of the perk wall (y=-959), and the teleporter is out on the spur now.
// Mid-landing top is (lap-1)*LAP_RISE + FLIGHT_RISE; the +28 matches the base
// spawns' height above their own floor.
// 2026-10-02: spawn 1 moved -640 -> -620 (20 north): the v19.68n crate clip reaches y -651,
// and at -640 a player hull overlapped it by 4 - checkBreatherSpawns() now fails any repeat.
const BREATHER_SPAWN_XY = [[-340, -620], [-340, -780], [-460, -640], [-460, -780]];
[...BREATHER_LAPS].sort((a, b) => a - b).forEach((lap) => {
  const brz = (lap - 1) * LAP_RISE + FLIGHT_RISE + 28;
  const brTn = `tod_respawn_lap${lap}`;
  ent(`lap${lap} breather respawn group`, [
    '{', `guid "${guid()}"`, kv('classname', 'script_struct'),
    kv('angles', '0 90 0'), kv('origin', `-400 -710 ${brz}`),
    kv('radius', '2000'), kv('script_int', '2000'),
    // script_noteworthy IS REQUIRED, and its absence made this whole feature
    // INERT (verification pass 2026-08-23). manage_zones() LOCKS every
    // player_respawn_point at zone-manager init (_zm_zonemgr.gsc:810-828), and
    // the ONLY unlock anywhere in the stock zm tree is enable_zone's
    // `spawn_points[i].script_noteworthy == zone_name` (:505-510) — all three
    // selection sites then skip anything still locked. So these four groups
    // could never unlock, and bled-out co-op players kept falling back to
    // spectator_respawn (the base arena): exactly the exile the v10.4 entry
    // claims to have fixed. The balcony brush belongs to lap{N}_zone, so that
    // is the correct gate — and it delivers the door-gating the original
    // comment wanted, since the zone only enables once that lap's door is
    // bought. (The base group's 'start_room' matches no zone on this map
    // either, but that one is harmless: stock's fallback lands in the same
    // arena it names, which is why nobody noticed.)
    kv('script_noteworthy', `lap${lap}_zone`),
    kv('target', brTn), kv('targetname', 'player_respawn_point'),
    kv('_color', '1 0 0'), '}',
  ]);
  BREATHER_SPAWN_XY.forEach(([sx, sy], i) => {
    ent(`lap${lap} breather spawn ${i + 1}`, [
      '{', `guid "${guid()}"`, kv('classname', 'script_struct'),
      kv('_color', i % 2 ? '1 0 1' : '1 1 0'),
      kv('angles', '0 90 0'), kv('origin', `${sx} ${sy} ${brz}`),
      kv('radius', '32'), kv('targetname', brTn), '}',
    ]);
  });
});

// --- CROWN RESPAWN GROUP (review 2026-08-23) --------------------------------
// The four breather groups above stop a co-op death being a 50-floor re-climb,
// but they stop at floor 40 — there was NOTHING on the crown. A player who bled
// out on the terrace, on the causeway or inside the citadel fell all the way
// back to the base arena, and during THE LAST MILE that is not a setback, it is
// removal from the game: the run is a 191-second song, the gate is behind them,
// and 8,600 units of road plus a 50-floor climb do not fit in what is left of
// it. One player dying ended that player's finale outright.
//
// ON THE TERRACE, not in the citadel, and that is the whole design of it: you
// come back at the START of the road and have to run it again. Respawning past
// the gate would hand the ending to anyone willing to trade a down for a
// teleport, which is the opposite of what the road is for.
//
// Gated for free by roof_zone, exactly like the breather groups are gated by
// their lap zones: script_noteworthy must equal the zone name or manage_zones()
// leaves the group LOCKED forever (the trap that made all four breather groups
// inert until 2026-08-23), and stock also refuses any group whose origin is not
// inside an ENABLED zone. So this cannot be used before the roof door is bought.
//
// PLACEMENT: the terrace is x[-TER_W,TER_W] y[TER_Y1,TER_Y2] at TOP2. The four
// points sit EAST of centre, clear of the causeway mouth (x +/-100, where the
// gate stands) and clear of the uplink terminal at x -(CW_HALF+96). Mirrored by
// cpt() like every other crown coordinate — the terrace itself is emitted
// through cbox, so raw coordinates here would put the whole group on the wrong
// side of the tower at the other parity.
const CROWN_SPAWN_XY = [[240, 320], [360, 320], [240, 420], [360, 420]];
{
  const gz = TOP2 + 28;   // +28 above the deck, matching the base group
  const org = cpt(0, (TER_Y1 + TER_Y2) / 2, gz);
  ent('crown respawn group', [
    '{', `guid "${guid()}"`, kv('classname', 'script_struct'),
    kv('angles', `0 ${cyaw(90)} 0`), kv('origin', `${org[0]} ${org[1]} ${org[2]}`),
    kv('radius', '2000'), kv('script_int', '2000'),
    kv('script_noteworthy', 'roof_zone'),
    kv('target', 'tod_respawn_crown'), kv('targetname', 'player_respawn_point'),
    kv('_color', '1 0 0'), '}',
  ]);
  CROWN_SPAWN_XY.forEach(([sx, sy], i) => {
    const o = cpt(sx, sy, gz);
    ent(`crown spawn ${i + 1}`, [
      '{', `guid "${guid()}"`, kv('classname', 'script_struct'),
      kv('_color', i % 2 ? '1 0 1' : '1 1 0'),
      kv('angles', `0 ${cyaw(90)} 0`), kv('origin', `${o[0]} ${o[1]} ${o[2]}`),
      kv('radius', '32'), kv('targetname', 'tod_respawn_crown'), '}',
    ]);
  });
}

ent('intermission', [
  '{', `guid "${guid()}"`, kv('classname', 'script_struct'),
  kv('angles', '0 90 0'), kv('origin', '0 -500 104'),
  kv('target', 'intermission_b'), kv('targetname', 'intermission'),
  kv('_color', '1 0 0'), '}',
]);
ent('intermission_b', [
  '{', `guid "${guid()}"`, kv('classname', 'script_struct'),
  kv('angles', '0 30 0'), kv('origin', '-460 -460 104'),
  kv('targetname', 'intermission_b'), kv('_color', '1 0 0'), '}',
]);

// --- AI factory alternatives: stock runtime filter keeps exactly one --------
// Both use the same spawn location/settings. All modes select the native cyber
// mix before spawn initialization. Keep historical markers compatible with BSPs.
for (const [factory, marker] of [
  ['actor_spawner_zm_factory_zombie', 'tod_cyber_stock'],
  ['actor_spawner_zm_tod_cyber_horde', 'tod_cyber_dev'],
]) {
ent('zombie factory spawner ' + marker, [
  '{', `guid "${guid()}"`,
  kv('classname', factory), kv('script_string', marker),
  kv('ALERTONSPAWN', '0'), kv('MAKEROOM', '1'), kv('SCRIPT_FORCESPAWN', '1'),
  kv('angles', '0 270 0'), kv('count', '9999'), kv('export', '1'),
  kv('origin', '470 470 208'),
  kv('script_disable_bleeder', '1'), kv('script_forcespawn', '1'),
  kv('script_noteworthy', 'zombie_spawner'), kv('SPAWNER', '1'),
  kv('_color', '1 0.25 0'), kv('engageMaxDist', '700'), kv('engageMinDist', '250'),
  kv('model', 'c_zom_test_body1'), kv('script_dropammo', '1'),
  kv('sm_active_count_max', '3'), kv('sm_active_count_min', '3'),
  kv('spawnflags', '19'), '}',
]);
}

// --- buyable doors (25 lap doors + the rooftop flight) -----------------------
// v6 doors: odd floors enter the E flight at the SE corner (S walkway),
// even floors enter the W flight at the NW corner (N walkway).
// A door's anti-bypass clip rises 600 above the doorway so nobody vaults the
// slab — but it must never poke up THROUGH the floor above it. lap50's did:
// 18816+600 = 19416, and the terrace deck is at 19392, so 24 units of invisible
// clip stood on the terrace floor. 24 > the 18-unit step, so it was a wall you
// could not walk over and could not see — the same defect class as the lap-1
// rail cap that took three bug reports to find, caught this time by
// tools/lint_tod_geometry.js before anyone played it.
//
// Clamped to the UNDERSIDE of the crown floor. A no-op for laps 1-49 (600 never
// reaches it) and exactly right for lap 50. The ROOF door is deliberately not
// clamped: it sits on the opposite face, the lint proves it intrudes on nothing,
// and shortening it there would trade a real anti-bypass guard for no gain.
function doorClipTop(b) { return Math.min(b + 600, TOP2 - SLAB); }

const DOORS = [];
// v16.11 FACELIFT §2 — DOOR GATES THAT OPEN. Every lap door was a bare
// 160x20x128 slab in one green material that blinked away on purchase. Now:
//   slabMat   the `_tinted_edge` of the district the door opens INTO, so at a
//             district boundary the door is the first thing in the new colour
//   post      a 20-square glow post in that district's plain hue standing IN
//             THE RAIL BAND (x PX..PX+PARA) on the door line, floor to lintel
//             top, so the closed slab meets it edge to edge with no slot. The
//             two rail runs that meet at the door line are NOTCHED back
//             DOOR_POST_NOTCH each side (the parapet emission reads
//             doorPostAt), so the post overlaps nothing and nothing is
//             coplanar with it. v16.11-v19.56 stood it OUTSIDE the band and the
//             band's own 20 units of open air above the rail beside every
//             closed door was the user's "small empty slit" (2026-09-24,
//             screenshots on floors 1 and 2: "Its the door frame that needs to
//             be moved").
//   lintel    a 24-tall bar over the path from the core face to the post's
//             outer face, sitting ON the slab's top (z1 = slab z2), so the
//             doorway reads as a framed gate from both sides
//   sill      a 1u strip of the slab material in the floor under the slab —
//             hidden while the door is shut, revealed when it SLIDES INTO THE
//             CORE (_tod_doors.gsc: MoveX toward x=0 by the slab's own width
//             plus 8, then Hide/NotSolid/ConnectPaths as before). The rise the
//             map's dead `script_vector 0 0 130` keys were authored for was
//             dropped for the slide: a rising slab would pass through any
//             lintel low enough to read as a frame.
// The roof, power and bay doors keep their old slab and get no gate (different
// walls, different frames); only enter_lapN doors carry `gate`.
// THE SLAB STOPS AT THE RAILING AND NOTHING SITS ON IT (v19.51 / v19.54 / v19.56,
// 2026-09-23, user after playing v19.50: "the door goes into the railing where
// it should just go up right against the railing").
// v19.45 (same day, user: "the door should just fill up the entire path") had
// run the slab 20u across the rail band to the post's inner face (DOOR_REACH),
// because the slab stopping at the path edge (PX) left a railing-wide slot of
// sky between it and the gate post above the knee-high parapet - a door left
// ajar, on the player's right on every floor. That closed the slot by putting
// 128 tall of door THROUGH the parapet's own column, so the slab read as sunk
// into the railing. Now:
//   slab   x CORE..PX again - flush against the railing's inner face, the
//          parapet runs past it untouched;
//   NOTHING in the rail band (x PX..PX+PARA). The slot above the railing
//          between the slab and the post stays OPEN - 20 wide, too narrow for
//          a player, and the anti-vault clip above the slab still spans it.
// DO NOT FILL THAT SLOT AGAIN. It was filled twice and the user rejected both:
// v19.51 stood permanent world "jambs" on the rail tops (a block left on the
// railing beside every OPEN door), v19.54 made them door brushes ("caps") that
// slid away with the slab - but a CLOSED door then still sat on and past the
// railing (user 2026-09-24, after playing it: "The door should not be
// overlapping with the railing ... It looks like it goes beyond the railing").
// The door's outer edge IS the railing's inner face, x = PX.
// The spire's doors never took the reach and never had a frame: their slabs
// stop at PX already (section 6e), so this changes nothing there.
// LOCKSTEP: _tod_doors.gsc TOD_DOOR_SLIDE_DIST = the slab's width + 8 = 168.
for (let lap = 1; lap <= LAPS; lap++) {
  const b = (lap - 1) * LAP_RISE;
  const dMat = doorMatOf(lap - 1);     // the district you are buying into (MATTE — v18.99g)
  const gMat = paraMatOf(lap - 1);                             // its plain hue (post + lintel)
  if (lap % 2 === 1) {
    DOORS.push({
      flag: `enter_lap${lap}`, cost: doorCost(lap), target: `tod_door_lap${lap}`,
      dest: `the Spiral - Floor ${lap}`,
      slab: { x1: CORE, x2: PX, y1: -266, y2: -246, z1: b, z2: b + 128 },
      trig: { x1: CORE, x2: PX, y1: -306, y2: -206, z1: b, z2: b + 128 },
      clip: { x1: CORE, x2: PX + PARA, y1: -266, y2: -246, z1: b + 128, z2: doorClipTop(b) },
      org: [336, -256, b + 40], off: [0, 60, 0],
      slabMat: dMat,
      gate: FACELIFT ? {
        mat: gMat,
        post:   { x1: PX, x2: PX + PARA, y1: -266, y2: -246, z1: b, z2: (lap === 1 ? 288 : b + 152) },   // lap 1: up the 288 anti-bypass wall it now ends
        lintel: { x1: CORE, x2: PX + PARA, y1: -266, y2: -246, z1: b + 128, z2: b + 152 },
        sill:   { x1: CORE, x2: PX, y1: -266, y2: -246, z1: b, z2: b + 1 },
      } : undefined,
    });
  } else {
    DOORS.push({
      flag: `enter_lap${lap}`, cost: doorCost(lap), target: `tod_door_lap${lap}`,
      dest: `the Spiral - Floor ${lap}`,
      slab: { x1: -PX, x2: -CORE, y1: 246, y2: 266, z1: b, z2: b + 128 },
      trig: { x1: -PX, x2: -CORE, y1: 206, y2: 306, z1: b, z2: b + 128 },
      clip: { x1: -PX - PARA, x2: -CORE, y1: 246, y2: 266, z1: b + 128, z2: doorClipTop(b) },
      org: [-336, 256, b + 40], off: [0, 60, 0],
      slabMat: dMat,
      gate: FACELIFT ? {
        mat: gMat,
        post:   { x1: -(PX + PARA), x2: -PX, y1: 246, y2: 266, z1: b, z2: b + 152 },
        lintel: { x1: -(PX + PARA), x2: -CORE, y1: 246, y2: 266, z1: b + 128, z2: b + 152 },
        sill:   { x1: -PX, x2: -CORE, y1: 246, y2: 266, z1: b, z2: b + 1 },
      } : undefined,
    });
  }
}
// CROWN DOOR (v9): gates the FIRST TREAD of the crown stair, on whichever
// landing the spiral ended on. This is exactly the odd-lap door formula with
// b=TOP, point-mirrored by CM for an even crown lap — the old version was
// hardcoded to "lap 25 ends via the N flight" and with LAPS=50 it hung a slab
// in open air on the wrong side of the tower.
DOORS.push({
  flag: 'enter_roof', cost: ROOF_DOOR_COST, target: 'tod_door_roof',
  dest: 'the Crown',
  slab: cspec({ x1: CORE, x2: PX, y1: -266, y2: -246, z1: TOP, z2: TOP + 128 }),
  trig: cspec({ x1: CORE, x2: PX, y1: -306, y2: -206, z1: TOP, z2: TOP + 128 }),
  clip: cspec({ x1: CORE, x2: PX + PARA, y1: -266, y2: -246, z1: TOP + 128, z2: TOP + 600 }),
  org: cpt(336, -256, TOP + 40), off: [0, 60, 0],
});
// v17.29 — EVERY GROUND-LEVEL DOOR IS THE TOWER DOOR'S BLUE (user 2026-09-04:
// "We can make all the doors on first floor blue like the tower door").
//
// The power-room and teleport-bay doors had no `slabMat` at all, so they fell
// through to MAT.door (green) while the lap-1 door beside them took the district
// hue. DERIVED from the same expression the lap doors use — `edgeMatOf(0)` is
// literally what floor 1's door resolves to — rather than a literal
// `blue_tinted_edge`, so if district 1 is ever re-hued these follow it instead
// of quietly becoming the odd ones out. Under FACELIFT=false the tower door is
// green, and "like the tower door" then correctly means green, so the ternary is
// the whole rule.
//
// NOTE this drops the green/blue split Nikolai proposed alongside the black
// floor ("only leave the green buyable doors and blue buyable door"). Deliberate,
// on the user's call: the three ground doors are in three different walls in
// three different rooms, so they were never told apart by hue, and against the
// v17.28 black floor a single saturated blue is the strongest "buy me" the pack
// can draw. MAT.door still owns the ROOF door, the causeway gate and the crown
// door — none of them are on floor 1, and none of them change here.
const GROUND_DOOR_MAT = doorMatOf(0);   // matte blue — v18.99g
// POWER ROOM (user 2026-08-20): a longish hallway in the base SE corner —
// buyable door at the west end, power switch behind it at the east end.
// Interior x[280,540] y[-540,-420]; south/east sides are the arena walls,
// north side is a new wall, the west face IS the door slab.
DOORS.push({
  flag: 'enter_power', cost: POWER_DOOR_COST, target: 'tod_door_power',
  dest: 'the Power Room', slabMat: GROUND_DOOR_MAT,
  slab: { x1: 260, x2: 280, y1: -540, y2: -420, z1: 0, z2: 128 },
  trig: { x1: 220, x2: 320, y1: -540, y2: -420, z1: 0, z2: 128 },
  clip: { x1: 260, x2: 280, y1: -540, y2: -420, z1: 128, z2: 600 },
  org: [270, -480, 40], off: [60, 0, 0],
});
// TELEPORT BAY (v10.25): the slab fills the opening cut in the arena's south
// wall. `base clip S` was never split, so it still spans z[128,1600] across the
// whole wall and is the lintel over this doorway whether the door is open or
// shut — which is why the clip here only has to cover the slab's own height.
DOORS.push({
  flag: 'enter_tpbay', cost: TPBAY_DOOR_COST, target: 'tod_door_tpbay',
  dest: 'the Teleport Bay', slabMat: GROUND_DOOR_MAT,
  slab: { x1: -TPB_DOOR, x2: TPB_DOOR, y1: -(ARENA + WALL), y2: -ARENA, z1: 0, z2: 128 },
  trig: { x1: -TPB_DOOR, x2: TPB_DOOR, y1: -600, y2: -500, z1: 0, z2: 128 },
  clip: { x1: -TPB_DOOR, x2: TPB_DOOR, y1: -(ARENA + WALL), y2: -ARENA, z1: 128, z2: 600 },
  // OFFSET 60 -> 20 (live report 2026-08-25: "there is a trigger near it where
  // it says hevenly something but you cant even buy it ... Seems like a multiple
  // trigger issue"). The buy triggers are radius 96 and sit at org +- off, so at
  // 60 the OUTER one stood at y=-490 and reached y=-394 — straight through the
  // HEAVENLY GIFT ALTAR's trigger at (0,-360) r64, which reaches y=-424. A 30u
  // band on the main walk from spawn to the core had BOTH prompts live, so the
  // altar's hint drew while this door owned the press. That is the exact
  // "no two use-triggers overlap" rule the teleport pads are spaced by.
  // At 20 the outer trigger sits at y=-530 and reaches y=-434, clearing the
  // altar by 10u, and it still covers a player walking down from the spawn band
  // at y=-462..-498.
  org: [0, -550, 40], off: [0, 20, 0],
});
for (const d of DOORS) {
  ent(`door trigger ${d.flag}`, [
    '{', `guid "${guid()}"`,
    kv('classname', 'trigger_use'),
    kv('targetname', 'zombie_door'),
    kv('target', d.target),
    // CONSTANT, NOT d.cost — the 250-triggerstring cap (2026-08-30).
    // Stock _zm_blockers::door_init runs as a system PRELOAD (REGISTER_SYSTEM_EX
    // -> shared.gsh's __func_init_preload -> system::run_pre_systems, called from
    // CodeCallback_PreInitialization, i.e. BEFORE the map's main() executes a
    // single line) and ends in set_hint_string(self,"default_buy_door",cost) ->
    // SetHintString(&"ZOMBIE_BUTTON_BUY_OPEN_DOOR_COST", cost). That mints ONE
    // PERMANENT BG-cache 'triggerstring' slot per DISTINCT cost, and the cache
    // caps at 250 for the whole match. Per-lap pricing put 41 distinct values in
    // here, so stock burned 41 slots on prompts nobody ever sees — _tod_doors.gsc
    // TriggerEnable(false)s all 53 of those triggers a second later.
    //
    // SAFE BECAUSE THIS VALUE IS DEAD DATA: _tod_doors.gsc seeds cost=1000 from
    // this key and then overrides it from the GENERATED _tod_door_data.gsc
    // (info.cost WINS, v9.41 — that is what keeps a price change -GscOnly), and
    // all 53 rows define info.cost. A door with no data row returns before it
    // ever gets a trigger. 1000 matches the GSC's own fallback exactly.
    //
    // The REAL per-door price is emitted further down as `info.cost = ${d.cost}`
    // in _tod_door_data.gsc. Do not "fix" this line to match it.
    kv('zombie_cost', '1000'),
    kv('script_flag', d.flag),
    matBrush(d.trig.x1, d.trig.x2, d.trig.y1, d.trig.y2, d.trig.z1, d.trig.z2, 'trigger'),
    '}',
  ]);
  ent(`door slab ${d.flag}`, [
    '{', `guid "${guid()}"`,
    kv('classname', 'script_brushmodel'),
    kv('targetname', d.target),
    kv('script_vector', '0 0 130'),
    kv('script_transition_time', '1.5'),
    matBrush(d.slab.x1, d.slab.x2, d.slab.y1, d.slab.y2, d.slab.z1, d.slab.z2, d.slabMat || MAT.door),
    // v16.13 — THE ANTI-VAULT CLIP RIDES IN THE SLAB ENTITY (user 2026-09-01:
    // "above doors there are invisible walls so if they jump down stairs
    // sometimes they hit an invisible wall above where the door would be").
    // It used to be a WORLDSPAWN brush from the slab's top (b+128) to b+600,
    // which is permanent: it kept stopping players for the rest of the match
    // after the door was bought. A jump down the flight toward the doorway
    // puts the head at ~135-150 above the door's floor as it crosses the
    // door line (12u treads, 39u jump, 72u eye) — straight into a brush whose
    // bottom is 128 up. As a second brush of the script_brushmodel it is
    // Solid + DisconnectPaths while the door is shut (the vault guard is
    // intact — a shut door still needs it, a 128 slab is jumpable with a
    // slide-jump under the ATHLETE dvar), slides into the core with the slab
    // (all solid core above every doorway), and goes NotSolid with it. No
    // script change: every open path already Hide/NotSolid/ConnectPaths the
    // entity. The rail-band column it also covered (x to PX+PARA) is under the
    // parapets' own rail caps, so nothing is lost there. Same fix on the
    // spire's 100 doors (section 6e), the roof, power and bay doors.
    matBrush(d.clip.x1, d.clip.x2, d.clip.y1, d.clip.y2, d.clip.z1, d.clip.z2, MAT.clip),
    '}',
  ]);
  if (d.gate) {   // v16.11 facelift §2 — see the DOORS block
    const g = d.gate;
    addBox(`door gate post ${d.flag}`, g.post.x1, g.post.x2, g.post.y1, g.post.y2, g.post.z1, g.post.z2, g.mat);
    addBox(`door gate lintel ${d.flag}`, g.lintel.x1, g.lintel.x2, g.lintel.y1, g.lintel.y2, g.lintel.z1, g.lintel.z2, g.mat);
    addBox(`door gate sill ${d.flag}`, g.sill.x1, g.sill.x2, g.sill.y1, g.sill.y2, g.sill.z1, g.sill.z2, d.slabMat);
  }
}

// THE CAUSEWAY GATE (v10.11) — the road is CUT until EXTRACTION is bought.
// Same slab contract as every buyable door here: _tod_finale makes it
// Solid + DisconnectPaths at init and Hide + NotSolid + ConnectPaths on the
// buy, so the navmesh is genuinely severed and the horde cannot path the road
// early either. Emitted HERE, not in section 5c, because entities[] does not
// exist yet up there.
// DOOR_PROUD (v19.53, 2026-09-24, user: "the green doors at the bridge ... flash
// in and out inside of the wall ... they're both trying to compete"): the
// causeway gate and the five lane seals were cut EXACTLY to the road - gate
// x = the rails' outer faces and y1 = where rails W1/E5 begin; each seal x =
// the lane's edges and y = where the lane's first tread begins - so their
// faces lay ON the tread / under-glow / rail faces, facing the same way, and
// the two surfaces z-fought (tmp/bridge_gift_20260924/door_zfight.js found
// 33 such overlaps, all on these six doors). Every door now stands DOOR_PROUD
// proud of those faces on every side but the top: a face 2 units outside a
// world face never ties with it, and what it covers is inside the door.
const DOOR_PROUD = 2;
{
  const g = cspec({
    x1: -CW_HALF - PARA - DOOR_PROUD, x2: CW_HALF + PARA + DOOR_PROUD,
    y1: TER_Y2 - DOOR_PROUD, y2: TER_Y2 + 24 + DOOR_PROUD, z1: TOP2 - DOOR_PROUD, z2: TOP2 + 256,
  });
  ent('causeway gate', [
    '{', `guid "${guid()}"`,
    kv('classname', 'script_brushmodel'),
    kv('targetname', 'tod_causeway_gate'),
    matBrush(g.x1, g.x2, g.y1, g.y2, g.z1, g.z2, MAT.door),
    '}',
  ]);
}
// THE CROWN DOOR (v10.26) — the citadel's own gate, and the OPPOSITE contract to
// the causeway gate above. That one starts SEALED and opens when you pay; this
// one starts OPEN (you have to be able to walk in) and SLAMS SHUT when the
// hold-out begins, sealing the party inside for the final fight.
//
// It fills the gate opening EXACTLY: x +-GATE_HALF is the hole the south wall
// leaves between its two gate posts, and GATE_H is the lintel height above it
// ('crown gate lintel' fills WZ2 down to TOP2+GATE_H). So this brush is the
// missing 256x256 rectangle and nothing else — it cannot foul a post or a rail.
//
// _tod_finale::crown_door_init makes it Hide + NotSolid + ConnectPaths at map
// start (open), and crown_door_close() does Show + Solid + DisconnectPaths.
// THE CLOSE IS DEFERRED UNTIL AFTER THE PARTY IS TELEPORTED TO THE HALL CENTRE
// — a brush that solidifies on top of a player is the crush case the door slabs
// have always been careful about, and here it would land on somebody standing
// in the doorway by definition.
{
  const cd = cspec({
    x1: -GATE_HALF, x2: GATE_HALF,
    y1: HS, y2: HS + HWALL, z1: TOP2, z2: TOP2 + GATE_H,
  });
  ent('crown door', [
    '{', `guid "${guid()}"`,
    kv('classname', 'script_brushmodel'),
    kv('targetname', 'tod_crown_door'),
    matBrush(cd.x1, cd.x2, cd.y1, cd.y2, cd.z1, cd.z2, MAT.door),
    '}',
  ]);
}
// THE LANE LOTTERY SEALS (v12.13, docs/41 §B1) — five slabs, one across each
// branch lane's SOUTH mouth just past its fork landing. ALL start OPEN
// (_tod_finale::lane_seals_init does Hide+NotSolid+ConnectPaths at init); at
// the extraction buy the finale rolls ONE lane per fork and seals it
// (Show+Solid+DisconnectPaths) BEFORE the causeway gate opens, so no player
// can be standing in a slab when it solidifies (they are all behind the
// still-solid causeway gate; the dev harness opens that gate early, so the
// script also occupancy-checks before sealing). Same contract, same material,
// same visual grammar as the causeway gate above. SOUTH mouth only: every lane
// stays path-connected via its merge, so nothing — player or zombie — can be
// stranded inside a sealed lane; it is a dead end you walk back out of.
// Indices are load-bearing (_tod_finale rolls 0-1 for fork 1, 2-4 for fork 2):
//   0 f1 W ridge | 1 f1 E broken stair | 2 f2 W undercroft | 3 f2 C plank | 4 f2 E weave
{
  const seals = [
    ['f1 ridge',      LX[0],  LX[1],  cwY[2]],
    ['f1 bstair',     EX[0],  EX[1],  cwY[2]],
    ['f2 undercroft', LX[0],  LX[1],  cwY[6]],
    ['f2 plank',      PX_[0], PX_[1], cwY[6]],
    ['f2 weave',      EX[0],  EX[1],  cwY[6]],
  ];
  seals.forEach(([tag, x1, x2, y], i) => {
    // z1 is TOP2-32, not TOP2: the two DESCENDING lanes (broken stair, under-
    // croft) drop 16 within their first tread, so a slab based at TOP2 would
    // hover with a 16u see-through slot beneath it. 32 buries the base inside
    // the tread/under-glow brushes on every lane (deck slab is 16, glow 24).
    // v19.53: DOOR_PROUD on every side but the top (see the causeway gate)
    const s = cspec({ x1: x1 - DOOR_PROUD, x2: x2 + DOOR_PROUD, y1: y - DOOR_PROUD, y2: y + 24 + DOOR_PROUD, z1: TOP2 - 32 - DOOR_PROUD, z2: TOP2 + 256 });
    ent(`lane seal ${tag}`, [
      '{', `guid "${guid()}"`,
      kv('classname', 'script_brushmodel'),
      kv('targetname', `tod_lane_seal_${i}`),
      matBrush(s.x1, s.x2, s.y1, s.y2, s.z1, s.z2, MAT.door),
      '}',
    ]);
  });
}
// --- prefabs: base kit + the ladder up the tower -----------------------------
function prefab(label, model, x, y, z, yaw, scriptString) {
  // v13.6: a model containing '/' is a path under _prefabs/ (e.g.
  // 'ALXS/alxs_cwpap_prefab.map'); a bare name keeps the legacy zm_core home.
  const prefabPath = model.includes('/') ? '_prefabs/' + model : '_prefabs/zm/zm_core/' + model;
  const lines = [
    '{', `guid "${guid()}"`, kv('classname', 'misc_prefab'),
    kv('angles', `0 ${yaw} 0`), kv('model', prefabPath), kv('origin', `${x} ${y} ${z}`),
  ];
  if (scriptString) lines.push(kv('script_string', scriptString));
  lines.push('}');
  ent(label, lines);
}
const PERK_LOC = 'zclassic_perks_start_room';
// Base arena (z=0)
// POWER ROOM hallway v2 (user 2026-08-20: "5x longer"): the SE-corner
// corridor now punches THROUGH the arena's east wall and runs outside to
// x=1620 — door at x=280, switch at x~1596, corridor ~1340u (~5.2x the v1).
// Interior leg: arena S wall + the north wall below; exterior leg: own
// floor/walls/clips under the (widened) skybox.
addBox('power room north wall', 280, 540, -420, -400, 0, BASE_WALL_H, MAT.baseWall);
addBox('power hall floor', 560, 1640, -560, -400, -SLAB, 0, MAT.baseFloor);
addBox('power hall wall N', 560, 1620, -420, -400, 0, BASE_WALL_H, MAT.baseWall);
addBox('power hall wall S', 560, 1620, -560, -540, 0, BASE_WALL_H, MAT.baseWall);
addBox('power hall wall E', 1620, 1640, -560, -400, 0, BASE_WALL_H, MAT.baseWall);
addBox('power hall clip N', 560, 1640, -420, -400, BASE_WALL_H, 800, MAT.clip);
addBox('power hall clip S', 560, 1640, -560, -540, BASE_WALL_H, 800, MAT.clip);
addBox('power hall clip E', 1620, 1640, -560, -400, BASE_WALL_H, 800, MAT.clip);
// THE POWER TERMINAL (v19.69, 2026-10-02, user: "We can add the grid terminal as
// well to replace the power switch"). Nikolai's Grid Terminal V5 (`tod_power_terminal`,
// tools/fan_props: GRID CONTROL / RESTART SEQUENCE REQUIRED / HOLD TO INITIATE)
// replaces the stock lever prefab (power_switch.map, 2026-08-21..10-02) on the
// east end wall, FACING WEST down the hall.
// STOCK STILL RUNS THE SWITCH (_zm_power::electric_switch), so this block emits
// exactly the pieces that function reads from the prefab, and nothing else:
//   * the trigger_use `use_elec_switch` (HINT_ACTIVATE) targeting 'tod_power_switch'
//     - same class and hint as the lever's, so the prompt card does not change;
//   * the HANDLE: script_noteworthy 'elec_switch' on that targetname. Stock rolls it
//     90 degrees and plays zmb_switch_flip / zmb_turn_on FROM it. Here it is an
//     invisible tag_origin script_model at the panel's HOLD button, so the roll shows
//     nothing and both sounds come from the button, as they came from the lever;
//   * the script_struct 'elec_switch_fx', where stock bursts switch_sparks on
//     power-on: the button, again (stock reads its .origin with no isdefined guard
//     once a handle exists, so it must exist).
// The panel itself is a script_model (_tod_power_terminal.gsc - the carved-GDT rule:
// script_model + SetModel + a zone `xmodel,` line) at the GENERATED
// base_power_terminal_org/yaw below, and `base power terminal body` is the clip that
// stands in for its collision (the model has none; lint_tod_geometry
// MODEL_CLIP_COLUMNS). The lever's prefab clip and misc_model body went with it.
// THE SPOT: back plane 0.5 proud of the east cap's inner face (x=1620), yaw 180
// (the model's front is local +X). Centred at y=-464, NOT on the hall's centreline:
// the song-hunt bear (_tod_secret.gsc spots[0]) stands against the same wall at
// y=-520, so the 60-wide panel takes the wall space north of it (~14 clear either
// side). 88 tall: the hall walls are 128 and the POWER word owns z 96..128.
const POWER_WORD_Z = [96, 128];
const POWER_TERM = { wall: 1620, y: -464, proud: 0.5, yaw: 180 };
const SONG_BEAR_0 = {   // LOCKSTEP: _tod_secret.gsc spots[0] y; half width from the teddy's own manifest
  y: -520, half: JSON.parse(fs.readFileSync(path.join(REPO, 'art', 'cyber_teddy', 'manifest.json'), 'utf8')).size[0] / 2,
};
{
  const pt = FAN_PROPS.power;
  if (!pt || pt.model !== 'tod_power_terminal') throw new Error('art/fan_props/manifest.json has no tod_power_terminal — run tools/fan_props/build_fan_props.py --only power');
  const [d, w, h] = pt.size;                        // x = off the wall, y = across, z = up
  const back = POWER_TERM.wall - POWER_TERM.proud;
  const front = back - d;
  const y1 = POWER_TERM.y - w / 2, y2 = POWER_TERM.y + w / 2;
  // 1. inside the hall (walkable y[-540,-420]) with 8 to spare each side
  if (y1 < -540 + 8 || y2 > -420 - 8) throw new Error(`power terminal y[${y1},${y2}] crowds the power hall's side walls`);
  // 2. clear of the song-hunt bear beside it
  if (y1 < SONG_BEAR_0.y + SONG_BEAR_0.half + 8) throw new Error(`power terminal y1 ${y1} is within 8 of the song-hunt bear (${SONG_BEAR_0.y + SONG_BEAR_0.half})`);
  // 3. under the POWER word above the switch
  if (h > POWER_WORD_Z[0] - 8) throw new Error(`power terminal top ${h} is within 8 of the POWER word (z ${POWER_WORD_Z[0]})`);
  const cx1 = Math.floor(front), cy1 = Math.floor(y1), cy2 = Math.ceil(y2);
  addBox('base power terminal body', cx1, POWER_TERM.wall, cy1, cy2, 0, Math.ceil(h), MAT.clip);
  // v19.71 the perch cap: the 88-tall body top was a ledge in the athlete's reach
  perchCap('base power terminal perch cap', { x1: cx1, x2: POWER_TERM.wall, y1: cy1, y2: cy2 }, Math.ceil(h), [1, 0]);
  // The use trigger: open air in front of the face (never inside the clip), the
  // button-to-screen band, as the lever's (local y[-24,-5], z 38..60) was.
  const trig = { x1: cx1 - 26, x2: cx1 - 2, y1: POWER_TERM.y - 22, y2: POWER_TERM.y + 22, z1: 24, z2: 64 };
  if (trig.x2 >= cx1) throw new Error('power switch trigger reaches into the terminal clip');
  // 4. the hall riser (x 1400) must not rise inside it (the ~165u materialize clearance)
  if (trig.x1 - 1400 < 165) throw new Error(`power switch trigger is ${trig.x1 - 1400} from the hall riser`);
  const button = `${cx1 - 2} ${POWER_TERM.y} 29`;   // the HOLD button's centre, measured on the preview (29 of 88)
  ent('base power switch trigger', [
    '{', `guid "${guid()}"`,
    kv('classname', 'trigger_use'),
    kv('targetname', 'use_elec_switch'),
    kv('target', 'tod_power_switch'),
    kv('cursorhint', 'HINT_ACTIVATE'),
    matBrush(trig.x1, trig.x2, trig.y1, trig.y2, trig.z1, trig.z2, 'trigger'),
    '}',
  ]);
  ent('base power switch handle', [
    '{', `guid "${guid()}"`,
    kv('classname', 'script_model'),
    kv('model', 'tag_origin'),
    kv('origin', button),
    kv('angles', '0 180 0'),
    kv('targetname', 'tod_power_switch'),
    kv('script_noteworthy', 'elec_switch'),
    kv('client_server', 'ServerSide'),
    '}',
  ]);
  ent('base power switch fx', [
    '{', `guid "${guid()}"`,
    kv('classname', 'script_struct'),
    kv('origin', button),
    kv('angles', '0 180 0'),
    kv('targetname', 'tod_power_switch'),
    kv('script_noteworthy', 'elec_switch_fx'),
    '}',
  ]);
}
// hallway lights (the exterior leg is outside every arena light's radius)
light('power hall light 1', 800, -480, 100, '0.3 0.9 1', 380, 6, 1);
light('power hall light 2', 1200, -480, 100, '0.3 0.9 1', 380, 6, 1);
light('power hall light 3', 1560, -480, 100, '0.3 0.9 1', 380, 6, 1);

// ---------------------------------------------------------------------------
// POWER / STAIRS WAYFINDING (2026-09-23 review: too many identical arrows).
// Name the entrance, indicate its actual turn, reassure once inside the long
// straight hall, then identify the switch head-on. STAIRS + the rising arrow
// belong beside the actual tower gate, so its blue door differs from POWER.
//
// THE PACK IS MAP 1'S AND IT IS ALREADY INSTALLED IN THE SHARED TOOLS ROOT
// (`model_export/codimages/arrow_coldwar_dogcanary/*.gdt` + the
// `_modelos_dogcanary` pngs, there since 2026-07-12), so this map pays nothing
// to use it. Materials, READ OUT OF THAT GDT rather than guessed from the
// numbering — the material order and the image order do NOT line up:
//     arrow_power_coldwar  = curved RIGHT arrow    arrow_power_coldwar1 = POWER
//     arrow_power_coldwar2 = rising RIGHT arrow    arrow_power_coldwar7 = STAIRS
// The remaining art says ENGINE, VENT, Assemble, PASSWORD, Family, STOLEN,
// plus a straight left arrow. Those words do not name anything on this route.
// Keep the original pack art/materials. They are `usage decal` /
// `lit_emissive_scroll_transparent` at scaleRGB 16 — they GLOW, which is the
// point in a hallway lit by three cyan point lights.
// NO ZONE LINE IS NEEDED: world-geometry materials ride in through the
// compiled BSP, which is why map 1 ships these with no `material,` row either.
// It is still a FULL build — the .map changes.
//
// THE RECIPE IS MAP 1'S PROVEN CHALK-MESH, NOT A BRUSH: a flat quad
// DECAL_PROUD off the wall face with `contents nonColliding`, texture mapped
// once (u 0 -> 1024 across the columns, v 0 -> -1024 up the rows). A brush
// would give a picture collision, a navmesh cut and six textured faces.
//
// WINDING DECIDES WHICH WAY THE ART FACES, and map 1 paid for the rule:
// normal = u_dir x v_dir with v_dir = +z, so
//     -y normal -> columns Xmin->Xmax        +y normal -> columns Xmax->Xmin
//     -x normal -> columns Ymax->Ymin        +x normal -> columns Ymin->Ymax
// with u0 always the VIEWER'S LEFT and the texture unmirrored. On the arena's
// +y face, RIGHT points WEST, around the end of the wall to the power door.
// On the core's -y face, the rising RIGHT arrow points EAST toward the stairs.
const DECAL_PROUD = 2;
const DECAL_TAB = String.fromCharCode(9);   // map 1's vertex rows are tab-indented
function decalMesh(label, mat, cols, z1, z2, word = false) {
  // cols = [[ax, ay], [bx, by]] in draw order; each column is bottom then top.
  // POWER/STAIRS ink occupies the middle half of the 512-square image. Crop
  // only its empty top/bottom quarters via UVs: a 2:1 word quad now retains
  // the source aspect ratio, with no stretched text or texture edits.
  const [c0, c1] = cols;
  const bottomV = word ? -256 : 0, topV = word ? -768 : -1024;
  const v = (x, y, z, u, w) => `${DECAL_TAB}v ${x} ${y} ${z} t ${u} ${w}`;
  worldBrushes.push({ label, text: [
    '{',
    ` guid "${guid()}"`,
    ' mesh',
    ' {',
    ' contents nonColliding;',
    ' toolFlags;',
    `  ${mat}`,
    '  lightmap_gray',
    '  2 2 0 8',
    '  (',
    v(c0[0], c0[1], z1, 0, `${bottomV} -1.0001428 -6.7082205`),
    v(c0[0], c0[1], z2, 0, `${topV} -0.99985725 -9.0415535`),
    '  )',
    '  (',
    v(c1[0], c1[1], z1, 1024, `${bottomV} 0.87485725 -6.7084455`),
    v(c1[0], c1[1], z2, 1024, `${topV} 0.87514287 -9.0417786`),
    '  )',
    ' }',
    '}',
  ].join('\n') });
}
// A decal on a wall face at constant y whose normal points +y (the viewer is
// north of it, facing south). Columns run Xmax -> Xmin per the rule above.
function decalSouthWall(label, mat, faceY, xCentre, width, zCentre, word = false) {
  const x1 = xCentre - width / 2, x2 = xCentre + width / 2, y = faceY + DECAL_PROUD;
  const height = word ? width / 2 : width;
  decalMesh(label, mat, [[x2, y], [x1, y]], zCentre - height / 2, zCentre + height / 2, word);
}
const DECAL_POWER = 'arrow_power_coldwar1';
// One composed sign on the SAME wall: POWER, then a curved arrow at the west
// corner. The arrow points toward x=280 and the actual doorway around it;
// the old straight-arrow trail pointed east from the arena-facing wall.
decalSouthWall('power decal entrance POWER', DECAL_POWER, -400, 416, 128, 64, true);
decalSouthWall('power decal entrance turn', 'arrow_power_coldwar', -400, 316, 64, 64);
// One word halfway along the straight hall. No repeated arrows, no sign near
// the teddy bear at x=1614, and the existing floor trace still reaches power.
decalSouthWall('power decal hall POWER', DECAL_POWER, -540, 960, 112, 64, true);
// Face WEST, directly above the switch: the power terminal tops out at z=88
// (POWER_TERM asserts 8 of air) and this 64x32 word occupies z=96..128 on the
// end wall, centred over the terminal (y=-464 since v19.69, beside the bear),
// readable head-on when approaching rather than sideways.
decalMesh('power decal switch POWER', DECAL_POWER, [[1618, POWER_TERM.y + 32], [1618, POWER_TERM.y - 32]], POWER_WORD_Z[0], POWER_WORD_Z[1], true);
// The core south face beside the first stair gate (x=256..416, y=-266).
// Both meshes face SOUTH and stay on solid core wall; they are not attached
// to the moving door, so opening it cannot leave floating text in the passage.
decalMesh('stairs decal entrance STAIRS', 'arrow_power_coldwar7', [[100, -258], [212, -258]], 52, 108, true);
decalMesh('stairs decal entrance rise', 'arrow_power_coldwar2', [[216, -258], [252, -258]], 62, 98);

// v19.68t FLOOR NUMBERS ON THE WALL (user 2026-10-02: "The Floor number should be to the
// left of the door and not on the ground"). Each number now stands UPRIGHT on the wall at a
// player's LEFT as they face the door. Every lap door spans the core's corner to the railing
// (slab x CORE..PX on the door line), so that wall is the CORE FACE in the door's own plane:
// odd floors the core's SOUTH face (y = -CORE; the text's right = +x, facing -y), even floors
// its NORTH face (y = +CORE; right = -x, facing +y) - the spiral's parity mirror. The digits'
// right edge sits FLOORNUM_WALL_GAP from the corner (so every number hugs its door), the centre
// FLOORNUM_WALL_Z over the door landing (above eye height, under the door's 128 top), 1.5 proud.
// TWO PLACES ARE DIFFERENT - measured here, asserted by checkFloorSigns() at the end of the file:
//   tower floor 1   the base's STAIRS sign (decalMesh 'stairs decal entrance', z 52..108)
//                   already holds that stretch of the core face, so floor 1 rides above it;
//   spire floors 11, 21 ... 61 (the floor after each hub)   the core is OPEN there - the hub
//                   hall's void (6b: it stops at the hall floor and resumes SP_RM_VOID_H up) -
//                   and the wall left of the door is the hub S flight's INNER WALL, rail-high
//                   (its last segment, x 192..256, tops out at the landing + PARA_H), so the
//                   number is smaller and low on that wall.
// The v19.69 flat-on-the-landing layout (floorNumber / floorNumberSpot) is retired whole.
const FLOORNUM_WALL_H = 44, FLOORNUM_WALL_GAP = 12, FLOORNUM_WALL_Z = 92;
const FLOORNUM_WALL_Z1 = 138;                                   // tower floor 1: over the STAIRS sign (top 108)
const FLOORNUM_HUBEXIT_H = 32, FLOORNUM_HUBEXIT_GAP = 8, FLOORNUM_HUBEXIT_Z = 30;
const FLOORNUM_SIGNS = [];                                      // every placed number, for checkFloorSigns()
// v19.69 THE SURFACE REFRESH - FLOOR NUMBERS (RF_FLOORNUMS; see the REFRESH block
// near doorMatOf). One flat chalk-mesh quad per DIGIT, lying on the door landing
// - the landing where floor n's door is bought, i.e. floor n's own first metres
// (the HUD's real_floor_of(z) = 1 + int(z / LAP_RISE) says floor n there too) -
// cut from the 10-cell atlas tod_rf_floornum.png: cell k is u [96k, 96k + 96] in
// the decal UV convention above (0..1024 across the image), v 0 at the cell's
// bottom row to -1024 at its top (image row = 1 + v / 1024).
// THE QUAD FACES UP BY THE WINDING RULE ABOVE (normal = u_dir x v_dir): u runs
// along the text's RIGHT and v along its UP, and right = up turned -90 degrees, so
// right x up = +z for every reading direction. The numeral reads for a player
// FACING THE DOOR: odd floors' doors are on the E flight's foot (y = -256, you
// face +y), even floors' on the W flight's head (y = +256, you face -y).
// Footprint 48 x 64 per digit, centred 89 back from the door line (clear of the
// gate sill y +-246..266 and the buy trigger's 40-unit apron); 1.5 proud.
const FLOORNUM_H = 64, FLOORNUM_PROUD = 1.5, FLOORNUM_BACK = 345;
// PROPORTIONAL DIGITS: each digit's crop of its 192 x 256 atlas cell - its ink plus
// a 14 px margin for the glow skirt - so a narrow "1" does not leave a gap in "13".
// LOCKSTEP with the atlas: tools/gen_tod_refresh_assets.py --check measures the
// ink in tod_rf_floornum.png and FAILS if these crops do not hold it. Pixels in the
// cell: FLOORNUM_INK[d] = [x0, x1]; rows FLOORNUM_ROWS = [top, bottom].
const FLOORNUM_CELL = 192, FLOORNUM_ATLAS = 2048, FLOORNUM_CELL_H = 256;
const FLOORNUM_INK = [[30, 161], [49, 141], [30, 161], [30, 161], [30, 161], [30, 161], [30, 161], [30, 161], [30, 161], [30, 161]];
const FLOORNUM_ROWS = [48, 207];
const FLOORNUM_PX = FLOORNUM_H / (FLOORNUM_ROWS[1] - FLOORNUM_ROWS[0]);   // world units per atlas pixel
function decalQuad(label, mat, cols) {
  // cols = [[bottom, top], [bottom, top]], each vertex [x, y, z, u, v]; map 1's donor lightmap floats
  const v = (p, lm) => `${DECAL_TAB}v ${p[0]} ${p[1]} ${p[2]} t ${p[3]} ${p[4]} ${lm}`;
  worldBrushes.push({ label, text: [
    '{',
    ` guid "${guid()}"`,
    ' mesh',
    ' {',
    ' contents nonColliding;',
    ' toolFlags;',
    `  ${mat}`,
    '  lightmap_gray',
    '  2 2 0 8',
    '  (',
    v(cols[0][0], '-1.0001428 -6.7082205'),
    v(cols[0][1], '-0.99985725 -9.0415535'),
    '  )',
    '  (',
    v(cols[1][0], '0.87485725 -6.7084455'),
    v(cols[1][1], '0.87514287 -9.0417786'),
    '  )',
    ' }',
    '}',
  ].join('\n') });
}
// THE WALL SIGN: digits laid along `rt` (the text's right, horizontal) and +z, on the
// plane `out` (the wall's outward normal) through (ox, oy). decalQuad's winding makes the
// face's normal u x v = rt x z = out for both parities (asserted). The RIGHT edge of the
// number is fixed (at `edge` along rt from the plane's origin) so numbers hug their door.
function floorNumberWall(label, n, ox, oy, rt, out, edge, zc, h, mat, eye) {
  const digits = String(n).split('').map(Number);
  const px = h / (FLOORNUM_ROWS[1] - FLOORNUM_ROWS[0]);
  const widths = digits.map(dg => (FLOORNUM_INK[dg][1] - FLOORNUM_INK[dg][0]) * px);
  const total = widths.reduce((p, w) => p + w, 0), hh = h / 2;
  const nrm = [rt[1], -rt[0]];                                  // rt x (0,0,1), horizontal part
  if (Math.abs(nrm[0] - out[0]) > 1e-9 || Math.abs(nrm[1] - out[1]) > 1e-9) throw new Error(`${label}: the digits would face into the wall`);
  const uOf = (dg, p) => +((dg * FLOORNUM_CELL + p) / FLOORNUM_ATLAS * 1024).toFixed(3);
  const vOf = (row) => +((row / FLOORNUM_CELL_H - 1) * 1024).toFixed(3);
  const at = (s, tz) => [+(ox + rt[0] * s + out[0] * FLOORNUM_PROUD).toFixed(3), +(oy + rt[1] * s + out[1] * FLOORNUM_PROUD).toFixed(3), +(zc + tz).toFixed(3)];
  let a = edge - total;
  digits.forEach((dg, k) => {
    const b = a + widths[k];
    const u0 = uOf(dg, FLOORNUM_INK[dg][0]), u1 = uOf(dg, FLOORNUM_INK[dg][1]);
    const vb = vOf(FLOORNUM_ROWS[1]), vt = vOf(FLOORNUM_ROWS[0]);
    decalQuad(`${label} digit ${k + 1}`, mat, [
      [[...at(a, -hh), u0, vb], [...at(a, hh), u0, vt]],
      [[...at(b, -hh), u1, vb], [...at(b, hh), u1, vt]],
    ]);
    a = b;
  });
  FLOORNUM_SIGNS.push({ label, n, ox, oy, rt, out, s1: edge - total, s2: edge, z1: zc - hh, z2: zc + hh, eye });
}
// Floor n's sign, in a tower's own frame (+offX/offY for the spire). The door landing is SE
// (odd) or NW (even); the viewer the check uses stands on it, 100 out from the door line, eye
// 60 up. The plane's origin is the face's middle (x = 0), so the right edge is CORE - gap.
function floorNumberWallAt(label, n, offX, offY, mat, kind) {
  const b = (n - 1) * LAP_RISE, odd = n % 2 === 1;
  const rt = odd ? [1, 0] : [-1, 0], out = odd ? [0, -1] : [0, 1];
  let h = FLOORNUM_WALL_H, gap = FLOORNUM_WALL_GAP, zc = b + FLOORNUM_WALL_Z;
  if (kind === 'tower1') zc = FLOORNUM_WALL_Z1;
  if (kind === 'hubexit') { h = FLOORNUM_HUBEXIT_H; gap = FLOORNUM_HUBEXIT_GAP; zc = b + FLOORNUM_HUBEXIT_Z; }
  const eye = [offX + (odd ? (CORE + PX) / 2 : -(CORE + PX) / 2), offY + (odd ? -(CORE + 100) : CORE + 100), b + 60];
  floorNumberWall(label, n, offX, offY + (odd ? -CORE : CORE), rt, out, CORE - gap, zc, h, mat, eye);
}
if (RF_FLOORNUMS) {
  for (let n = 1; n <= LAPS; n++)
    floorNumberWallAt(`floor number ${n}`, n, 0, 0, `tod_rf_floornum_${districtOf(n - 1).key}`, n === 1 ? 'tower1' : 'tower');
}

// ---------------------------------------------------------------------------
// THE TELEPORT BAY — the map's second annex (see the TPB_* block up top).
// ---------------------------------------------------------------------------
addBox('tp bay floor',   -(TPB_X + WALL), TPB_X + WALL, TPB_Y1 - WALL, TPB_Y2, -SLAB, 0, MAT.baseFloor);
addBox('tp bay wall W',  -(TPB_X + WALL), -TPB_X, TPB_Y1 - WALL, TPB_Y2, 0, BASE_WALL_H, MAT.baseWall);
addBox('tp bay wall E',  TPB_X, TPB_X + WALL, TPB_Y1 - WALL, TPB_Y2, 0, BASE_WALL_H, MAT.baseWall);
addBox('tp bay wall S',  -(TPB_X + WALL), TPB_X + WALL, TPB_Y1 - WALL, TPB_Y1, 0, BASE_WALL_H, MAT.baseWall);
// clips to 800, exactly as the power hall does — the room is open to the sky
addBox('tp bay clip W',  -(TPB_X + WALL), -TPB_X, TPB_Y1 - WALL, TPB_Y2, BASE_WALL_H, 800, MAT.clip);
addBox('tp bay clip E',  TPB_X, TPB_X + WALL, TPB_Y1 - WALL, TPB_Y2, BASE_WALL_H, 800, MAT.clip);
addBox('tp bay clip S',  -(TPB_X + WALL), TPB_X + WALL, TPB_Y1 - WALL, TPB_Y1, BASE_WALL_H, 800, MAT.clip);
// Tron inlay: a glowing seam around the room, one lit square under each of the
// four up-pads (the assembly is ~167 across, so 176 reads as its footprint) and
// a GREEN square on the arrival spot so the landing point is legible from the
// door. These are 1u decals on the floor, the same trick as the base inlay ring.
addBox('tp bay inlay N', -(TPB_X - 20), TPB_X - 20, TPB_Y2 - 20, TPB_Y2 - 4, 0, 1, MAT.baseInlay);
addBox('tp bay inlay S', -(TPB_X - 20), TPB_X - 20, TPB_Y1 + 4, TPB_Y1 + 20, 0, 1, MAT.baseInlay);
// v18.99e/f/g THE RAMPAGE INDUCER STAND (user 2026-09-13: players "don't know
// what it's for" — the wall breaker read as a power switch; then "move it into
// the main room ... on the wall across from QR in spawn"; then, on seeing it,
// "the inducer is way too high to even trigger"). The switch is the BO6 aether
// canister (t10_zm_aether_canister, 12 x 12 x 29 — decoded from the
// xmodel_bin), knee-high on the floor, so it stands on this plinth against the
// BASE ARENA's SOUTH wall — the wall across from the pinned Quick Revive pad
// (-75, 511). Straight across from QR is the teleport-bay doorway (x +-160), so
// the plinth sits on the free wall run just WEST of it, between the -420 and
// -140 pilaster slots (the -140 one is skipped at the door end).
//
// ⚠️ THREE THINGS WENT WRONG IN v18.99e/f AND ALL THREE ARE FIXED HERE:
//   1. HEIGHT — the plinth was 72 tall, which puts a 29-tall device's BASE
//      above a 60-unit eye line. INDUCER_PLINTH_H is 32 now: waist-high pedestal,
//      device top at 61, dead on the eye line.
//   2. THE DEAD TRIGGER — the v18.99f trigger origin sat at the device's own
//      x/y, i.e. INSIDE this brush, and a use-trigger whose ORIGIN is inside any
//      solid never prompts (memory trigger-origin-under-decal; paid for by the
//      extraction obelisk, the hall crate and the crown altar before this). The
//      trigger now sits INDUCER_TRIG_OUT in FRONT of the plinth's north face on
//      open floor — the ammo crate / station grammar (CRATE_TRIG_OUT 56).
//   3. IT READ AS FLOATING — MAT.baseColumn is plain `dark_blue`, a black tile
//      with a dim grid, so the plinth vanished against a black floor and the
//      device looked stuck to the wall in mid-air. MAT.pilaster (plain `cyan`)
//      is the arena's own accent for "this is a fixture", and plain colours are
//      BLOCK to the geometry lint at ANY height, so a short plinth is safe.
//      (Both earlier lint failures were the 1u `baseInlay` CAP — a `_tinted`
//      DECK raised off the floor — never the plinth itself.)
//
// Clearances on the south band: enter_tpbay trigger box x[-160,160] y[-600,-500]
// (48u from this trigger's rim in x), base station trigger (0,-360) r64 290u
// away, dog spawn (0,-470) 280u, SW riser (-470,-470) 193u, spawn structs 370u+.
// EVERY NUMBER BELOW IS EMITTED into _tod_breather_data.gsc as base_inducer_org
// / _trig / _yaw and READ BACK by _tod_rampage.gsc, so the brush and the script
// cannot drift — the same no-drift contract the base ammo crate rides.
const INDUCER_X       = -280;
const INDUCER_PLINTH_H = 0;     // v18.99i: FLOOR-MOUNTED, no pedestal
const INDUCER_PLINTH_D = 48;    // depth out from the wall (y -540 .. -492)
// v18.99k (user: "it should be kind of in a radius all around it"): the trigger
// is centred ON the device and reaches every side. INDUCER_TRIG_OUT is gone.
const INDUCER_TRIG_R   = 96;
const INDUCER_YAW      = 90;    // local +X points north, into the arena
const INDUCER_FACE_Y  = -ARENA + INDUCER_PLINTH_D;              // -492
const INDUCER_ORG     = [INDUCER_X, -ARENA + INDUCER_PLINTH_D / 2];   // on the plinth's centre
const INDUCER_TRIG    = [INDUCER_X, INDUCER_ORG[1]];   // ON the device; script lifts it 40 above the prop
// v18.99i (user: "I don't really want it on a... an object, so we can just put
// it on the floor") - NO PEDESTAL. The device stands on the arena floor, which
// is also how BO6 places it. INDUCER_PLINTH_H is 0 now and nothing is cut here;
// INDUCER_PLINTH_D survives only as the depth the device stands off the wall.
// THE ASSERT THAT CLOSES note 2 FOR GOOD: the trigger origin must be clear of
// the plinth in plan. Nothing else stands on this wall run, and the trigger is
// lifted 40u off the floor in script, so plan clearance is the whole test.
// The pedestal is gone, so the only solid that can swallow this trigger origin
// is the arena's south WALL. Keep the check: the dead-trigger trap is why this
// whole block is generator-owned, and a future nudge of INDUCER_X/_TRIG_OUT is
// exactly how it would come back.
if (INDUCER_TRIG[1] <= -ARENA)
  throw new Error('rampage inducer trigger origin is inside the arena south wall — the dead-trigger trap');
// 2026-10-02 THE CYBER INDUCER HAS A BODY (user: "It looks large enough where it
// may need a clip as well"). The device is now tools/inducer_cyber's model: a
// 44 x 44 chamfered footprint, 67 tall, front on local +X, back 24 off the wall
// (INDUCER_PLINTH_D / 2 - its conduits stop 0.9 short of the wall face). The
// script_model has no collision of its own (same as the ammo crates), so a CLIP
// stands in for it - labelled `rampage inducer body`, the geometry lint's
// MODEL_CLIP_COLUMNS exception, which demands a visible model in the column.
// Square, a hair inside the footprint (a player brushes the plate, never an
// invisible lip in front of it); INDUCER_CLIP_H 40 is above a jump (39), so
// nobody stands on it, and well below the crystal.
// THE TRIGGER STAYS CENTRED ("a radius all around it") but rides ABOVE the clip:
// trigger_radius_use sight-traces to its origin and a clip blocks that trace
// (memory trigger-origin-under-decal; the v19.55 crate fix). INDUCER_TRIG_LIFT is
// emitted as base_inducer_trig_lift() - _tod_rampage.gsc reads it - so the clip
// height and the trigger height cannot drift apart.
const INDUCER_CLIP_HALF = 21;
const INDUCER_CLIP_H    = 40;
const INDUCER_TRIG_LIFT = 44;
if (INDUCER_TRIG_LIFT < INDUCER_CLIP_H + 2)
  throw new Error('rampage inducer trigger origin must sit above its body clip — the dead-trigger trap');
if (INDUCER_ORG[1] - INDUCER_CLIP_HALF <= -ARENA)
  throw new Error('rampage inducer body clip reaches into the arena south wall');
addBox('base rampage inducer body', INDUCER_ORG[0] - INDUCER_CLIP_HALF, INDUCER_ORG[0] + INDUCER_CLIP_HALF,
       INDUCER_ORG[1] - INDUCER_CLIP_HALF, INDUCER_ORG[1] + INDUCER_CLIP_HALF, 0, INDUCER_CLIP_H, MAT.clip);
// v19.71 THE PERCH CAP (Workshop tester: "I was able to replicate this with rampage also" -
// standing on the 40-tall body clip, out of every zombie's reach; the comment above called 40
// "above a jump (39), so nobody stands on it" - true for a stock jump, not for the athlete's
// 88). The cap leans into the arena's south wall, PERCH_SLOT above the body so the centred
// trigger (lift 44) keeps its sight line from every side.
if (INDUCER_TRIG_LIFT >= INDUCER_CLIP_H + PERCH_SLOT)
  throw new Error('rampage inducer trigger origin would sit inside its perch cap - keep it in the slot');
perchCap('base rampage inducer perch cap', { x1: INDUCER_ORG[0] - INDUCER_CLIP_HALF, x2: INDUCER_ORG[0] + INDUCER_CLIP_HALF,
  y1: INDUCER_ORG[1] - INDUCER_CLIP_HALF, y2: INDUCER_ORG[1] + INDUCER_CLIP_HALF }, INDUCER_CLIP_H + PERCH_SLOT, [0, -1]);
if (Math.abs(INDUCER_TRIG[0]) - INDUCER_TRIG_R < -TPB_DOOR - 0
    && INDUCER_TRIG[1] - INDUCER_TRIG_R < -500 && INDUCER_TRIG[0] + INDUCER_TRIG_R > -TPB_DOOR)
  throw new Error('rampage inducer trigger overlaps the enter_tpbay door trigger');
addBox('tp bay inlay W', -(TPB_X - 20), -(TPB_X - 36), TPB_Y1 + 4, TPB_Y2 - 4, 0, 1, MAT.baseInlay);
addBox('tp bay inlay E', TPB_X - 36, TPB_X - 20, TPB_Y1 + 4, TPB_Y2 - 4, 0, 1, MAT.baseInlay);
// v16.11 FACELIFT §4 — TELEPORT BAY COLOUR CODE (Workshop 2026-08-23: the
// spawn teleporters "are not aligned perfectly and feel quite confusing to
// know which is which"). Pad i lands on breather lap (i+1)*10, in THIS order —
// LOCKSTEP with `up_orgs` in _tod_teleport.gsc (front-left 10, front-right
// 20, back-left 30, back-right 40) — so each pad's square wears its
// destination lounge's `_tinted_edge` (= that lounge's district colour) and
// gets a pool light in the lounge's own light colour. The pad you stand on is
// the colour of the floor you arrive at.
[[-TPB_PAD_X, TPB_PAD_YN], [TPB_PAD_X, TPB_PAD_YN],
 [-TPB_PAD_X, TPB_PAD_YS], [TPB_PAD_X, TPB_PAD_YS]].forEach(([px, py], i) => {
  const th = BREATHER_THEME[(i + 1) * 10];
  const padMat = (FACELIFT && th) ? `mwiii_vertigo_retro_synth_${th.key}_tinted_edge` : MAT.baseInlay;
  addBox(`tp bay pad ${i + 1}`, px - 88, px + 88, py - 88, py + 88, 0, 1, padMat);
  if (FACELIFT && th) light(`tp bay pad ${i + 1} light`, px, py, 120, th.light, 200, 6, 1);
});
// THE ARRIVAL MARK IS GONE (v17.29, user 2026-09-04: "the teleporter bay has a
// landing area. I dont mind where it is but I do want to remove the green square
// we made to indicate it. There will be no landing zone but they will still land
// in that zone. Just no visual zone").
//
// IT WAS ONLY EVER A DECAL. The landing point is TPB_ARR_Y, read by
// _tod_teleport.gsc; this brush was a 1u green square painted on the floor over
// it, so deleting it removes the marker and moves nothing. Players still arrive
// on exactly the same spot. The arrival LIGHT below stays — it is one of the
// bay's three lights and pulling it would leave the north apron dark, which is a
// different change from the one asked for.
//
// The 176-unit squares under the four UP pads stay too: those are the
// destination colour code (FACELIFT §4), they mark a thing you stand on and
// press, not a thing that happens to you, and they answered a different Workshop
// report ("not aligned perfectly and feel quite confusing to know which is
// which").
// addBox('tp bay arrival mark', -88, 88, TPB_ARR_Y - 88, TPB_ARR_Y + 88, 0, 1, MAT.exfilPad);
light('tp bay light 1', 0, TPB_PAD_YS - 60, 110, '0.3 0.9 1', 380, 6, 1);
light('tp bay light 2', 0, TPB_ARR_Y, 110, '0.3 0.9 1', 340, 6, 1);
light('tp bay doorway', 0, -520, 100, BASE_LIGHT, 300, 6, 1);

// MYSTERY BOX REMOVED (user 2026-08-22: "I also never asked you to include it
// in the map"). It also fought the class design: stock weapon_give at the
// 2-primary limit takes the weapon you are HOLDING, so a box pull with the
// class gun out deleted it — and the class gun carries every upgrade, the tier
// ladder and the PaP state. Do not re-add without the user asking.
// prefab('base mystery box start', 'buyable_magic_box_start.map', -526, -200, -0.5, 0);
// PERK PARKING ROW (see PERK_PARK — the scatter relocates these at load).
// yaw 269.999 SINCE v13.3c: these back a NORTH wall and must face south, and
// the BO7/BO6 port meshes front on model-local +X where the old stock
// p7_zm_vending_* models fronted on -Y (measured — see the long note on the
// yaw in _tod_perk_scatter::build_pads, which carries the matching -90 for
// every scatter pad). This row is only the pre-scatter fallback parking spot,
// but it is visible at spawn, and it is what a machine keeps if capture ever
// fails — so it has to be right too. The old value was 359.999.
for (const pk of PERK_PARK) {
  if (pk.prefab) {
    prefab(`perk park ${pk.prefab}`, pk.prefab, pk.x, PERK_PARK_Y, 0, 269.999, PERK_LOC);
  } else {
    ent(`perk park ${pk.noteworthy}`, [
      '{', `guid "${guid()}"`,
      kv('classname', 'script_struct'),
      kv('angles', `0 ${pk.yaw !== undefined ? pk.yaw : 269.999} 0`),
      kv('model', pk.struct),
      kv('origin', `${pk.x} ${PERK_PARK_Y} 0`),
      kv('script_noteworthy', pk.noteworthy),
      kv('script_string', PERK_LOC),
      kv('targetname', 'zm_perk_machine'),
      kv('_color', '1 0 0'), '}',
    ]);
  }
}
// (wallbuy emission removed with WALLBUY_AT — user 2026-08-20)
// THE CROWN — the payoff (v9): PaP + Mule Kick inside the hall, backed on the
// gate wall either side of the entrance (33u standoff, facing into the hall —
// yaw 180 = back to a south wall in the odd frame; cyaw flips it). The
// finale props (uplink, pylons, pad light, sconces, beacon) are SCRIPT-spawned
// by _tod_finale.gsc from _tod_crown_data.gsc — carved-GDT models are safest
// as script_model+SetModel (zone `xmodel,` line), never as baked misc_models.
{
  // STANDOFF 33 -> 64 (user live report 2026-08-28: "final boss room. Pap is
  // inside the wall"). THE HALL HAS TWO MACHINES AND BOTH WERE AUTHORED AT 33:
  // this real Pack-a-Punch, 33u off the SOUTH wall's inner face (HS+HWALL=7880,
  // so origin y=7913), and the upgrade station 33u off the WEST wall. 33 is a
  // copied constant in this section, not a measured clearance, and it is the
  // tightest standoff any vending machine has in the map — the base station
  // sits 64u off the core face and the breather lounges 44u off theirs.
  //
  // I FIXED THE STATION FIRST AND ON A WRONG PREMISE, so the reasoning is
  // recorded rather than quietly overwritten: I had concluded the hall held no
  // real PaP at all, because I grepped the emitted .map for "pack_a_punch" and
  // "packapunch" and the stock prefab is named vending_weapon_upgrade_spawnable
  // — a name containing neither. VERIFY ASSET EXISTENCE BY WHAT THE GENERATOR
  // EMITS, NEVER BY STRING-MATCHING ITS OUTPUT; a prefab's filename is not its
  // subject. Both machines now use the base station's proven 64.
  //
  // v16.35 THE BASILICA (user 2026-09-02: the old spot was "odd and not
  // intuitive" — on the SOUTH wall beside the gate, facing north, i.e. behind
  // a player who has just run in). The machine now takes the EAST SHRINE at
  // the crossing: on the east wall at HYC, 64 off the inner face (the same
  // proven standoff), facing WEST across the dais at the upgrade altar in the
  // west shrine — the two upgrade machines flank the choice point. Its bay is
  // cut in section 5d (pilasters, glow panel, canopy at +216); its clips are
  // script (_tod_powerups::crown_pap_clips) and follow the model.
  //
  // YAW — v17.37 (user 2026-09-04: "Pap and ammo crate are not facing the
  // center of the crown room"). THE OLD DERIVATION WAS BUILT ON A CLAIM NOBODY
  // CHECKED: it read "at the old S-wall placement cyaw(180) faced the machine
  // NORTH into the room (user-verified for a month)" and rotated from there to
  // cyaw(270) for west. Both were wrong, and the prefab says so in its own
  // file. _prefabs/ALXS/alxs_cwpap_prefab.map holds the machine model at an
  // INTERNAL yaw of 270 and its pap_trigger_struct at (-25,0,0) — the side a
  // player stands on is prefab-local -x. A misc_prefab's angles COMPOSE with
  // that, so the machine's world facing is 180 + the instance yaw:
  //     cyaw(0) -> WEST (into the hall, across the dais at the altar)
  //     cyaw(180) -> east      cyaw(270) -> north (what shipped: along the wall)
  // Cross-check that needs no prefab file: _tod_powerups::pap_place_clips
  // spreads the machine's colliders along AnglesToForward — "the mesh's local
  // +X, its WIDE axis" — so the cabinet's face is perpendicular to its entity
  // yaw, and the four breather machines (BR_FURN.pap, W wall, yaw 90, facing
  // east, played for weeks) fix that perpendicular as yaw - 90. The prefab's
  // internal 270 lands the model at 180 when the instance is 270 = facing
  // north. VERIFY BY EYE and correct here, one number — same rule as v13.6.
  //
  // CLEARANCES at (664, HYC): the shrine pilasters sit at y HYC+-112..+-144,
  // the machine is ~128 wide along y; the nearest pier base (E4, y HYC+184)
  // starts at x 328 — 250u clear of the machine's front; the crate's clip body
  // (y 8289..8353) is 200u south along the same wall.
  // v19.71 (the perch pass): FLUSH, 64 -> CROWN_VENDOR_OFF off the wall (the prefab, its own
  // clip and its trigger struct move together) - see CROWN_VENDOR_OFF.
  const [px, py, pz] = cpt(HW - HWALL - CROWN_VENDOR_OFF, HYC, TOP2);
  // v13.6 (user 2026-08-29: "I just downloaded bo6 pap. Lets replace all pap
  // machines with this new version. Lets keep the FX and animations from this
  // pack if possible."): the stock vending_weapon_upgrade prefab is REPLACED
  // by the ALXS CW/BO6 PaP — an animated machine with its own FX, sounds and
  // buy script (zm_cwpap, de-singularized in v13.12 so the four breather
  // vendors run the same flow wearing this pack's mesh).
  prefab('crown pack-a-punch', 'ALXS/alxs_cwpap_prefab.map', px, py, pz, cyaw(0), PERK_LOC);
  // NO PERK ON THE CROWN (user 2026-08-25: "I dont want a perk on the crown").
  // The crown carries Pack-a-Punch and nothing else. Mule Kick used to sit here;
  // its replacement, PhD Flopper, went into the PERK_PARK scatter pool instead
  // so that every one of the scatter pads gets a machine — see PERK_PARK.
  // (The "mirrored companion slot" this block used to compute is now literally
  // where the upgrade altar stands — station_org(), the west shrine.)
}

// NOTE (2026-08-22, HARD-WON — do NOT re-add stock PaP prefabs here):
// A second stock `zm_pack_a_punch` zbarrier FATALS THE MAP LOAD. Stock
// _zm_pack_a_punch::spawn_init renames EVERY such zbarrier to the shared
// "vending_packapunch", then vending_weapon_upgrade() does a SINGULAR
// GetEnt("vending_packapunch") which errors with two or more. Map 1 paid for
// this exact lesson (its CHANGELOG "Working 2nd Pack-a-Punch in Paradise").
// v9.16 briefly shipped 4 breather PaP prefabs here and the map would not
// load. The breather Pack-a-Punches are SCRIPT-SPAWNED standalone vendors
// instead (script_model + trigger_radius_use, never the zm_pack_a_punch
// targetname) — see _tod_powerups.gsc::breather_pap_spawn.

// --- lights: 3 per lap (landing pools, palette-cycled) + base + roof ---------
// v17.77 — THE RED-LIGHT TEST (user 2026-09-05: "if i asked for a red tint of light on the
// entire map how would you do it and can you implement"). The map's light comes from three
// sources and each has ONE colour knob:
//   1. the SKY IMAGE (the ambient; bakes through skyStops) — `gen_tod_sky.js --tint r,g,b`;
//   2. the SUN — `colorSRGB` on tod_ssi_cybercity in source_data/tod_skybox.gdt;
//   3. every POINT LIGHT — `_color` on the entity, and ALL of them (36 call sites, ~310
//      lights, tower + crown + spire) are emitted by light() below, so LIGHT_TINT here is
//      the whole lane.
// Everything else that can colour the screen is NOT light: the vision file (a post-grade,
// must stay neutral — it is force-restored per client on every revive), the LUT material,
// and the fog (the tower has none; fog_off()). All three light knobs are BAKED: FULL build.
// The rule: colour x LIGHT_TINT, then rescaled so the light's LUMA is unchanged (a tint is a
// cast, not a dimming); if a channel passes 1 the colour is renormalised to max 1 and the
// overflow goes into `stops` (one stop = 2x) — a light that was already red gets brighter-red
// instead of clipping. `null` = off, byte-identical .map. The knob itself, LIGHT_TINT, sits
// with SKYBOX_MODEL / SSI near the top of the file (the first light() call runs before this
// block is reached, and a `const` here would be in its temporal dead zone).
function tintLight(color, stops) {
  if (!LIGHT_TINT) return [color, stops];
  const luma = v => 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2];
  const c = color.trim().split(/\s+/).map(Number);
  let t = c.map((v, i) => v * LIGHT_TINT[i]);
  const k = luma(c) / Math.max(luma(t), 1e-9);
  t = t.map(v => v * k);
  const mx = Math.max(...t);
  let s = stops;
  if (mx > 1) { t = t.map(v => v / mx); s = +(stops + Math.log2(mx)).toFixed(3); }
  return [t.map(v => +v.toFixed(4)).join(' '), s];
}
function light(label, x, y, z, color, radius, stops, bake) {
  [color, stops] = tintLight(color, stops);
  ent(label, [
    '{', `guid "${guid()}"`, kv('classname', 'light'),
    kv('targetname', label.replace(/\W+/g, '_')),
    kv('origin', `${x} ${y} ${z}`),
    kv('PRIMARY_TYPE', 'PRIMARY_OMNI'), kv('PRIMARY_NOSHADOWMAP', '1'),
    kv('ENABLE_FALLOFF', '1'), kv('_color', color),
    kv('radius', `${radius}`), kv('stops', `${stops}`),
    kv('falloffdistance', '12'), kv('bake_intensity_scale', `${bake}`),
    kv('client_server', 'ClientSide'), kv('def_tile', '1 1'),
    kv('excludeDedicated', 'Off'), kv('far_edge', '0.949999988079071'),
    kv('fov_outer', '90'),
    kv('lightingstate1', '0'), kv('lightingstate2', '1'),
    kv('lightingstate3', '1'), kv('lightingstate4', '1'),
    kv('penumbraRadius', '1.5'), kv('roundness', '0.5'),
    kv('shadowUpdate', 'Never'), kv('shadowmapScale', '1'),
    kv('superellipse', '0.75 1 0.75 1'), kv('volumetricSampleCount', '8'),
    kv('name', 'light'), kv('spawnflags', '82'), '}',
  ]);
}
// BASE_LIGHT_BAKE (v17.32, user 2026-09-04: "Tiny bit brighter"). v17.28 took
// the arena floor from a FILLED emissive (dark_blue_tinted, scaleRGB 10) to the
// plain grid texture, which is ~96% black — so the floor stopped lighting the
// room and the four corner lights are now most of what is down here.
//
// THIS IS THE ONLY REAL BRIGHTNESS KNOB IN THE BASE. The floor TINT is not one:
// `blue` and `dark_blue` are the same texture at the same scaleRGB, so the tint
// moves the grid LINE colour and nothing else (see MAT.baseFloor). Raising the
// light instead of the material keeps the black floor black, which is the look
// that was asked for, and lifts the walls and the players standing on it.
//
// bake_intensity_scale, not radius: radius would change WHERE the pools fall and
// re-shape the room. 1.35 is deliberately small — "tiny bit" — and it is one
// number to move again after a look.
const BASE_LIGHT_BAKE = 1.35;
light('tod light base 1', -470, -470, 240, BASE_LIGHT, 520, 6, BASE_LIGHT_BAKE);
light('tod light base 2', 470, -470, 240, BASE_LIGHT, 520, 6, BASE_LIGHT_BAKE);
light('tod light base 3', -470, 470, 240, BASE_LIGHT, 520, 6, BASE_LIGHT_BAKE);
light('tod light base 4', 470, 470, 240, BASE_LIGHT, 520, 6, BASE_LIGHT_BAKE);
// Follows the spawn to the WEST band (2026-08-27) — it exists to light the
// start point, and leaving it in the south would have left the new spawn lit
// only by the two blue corner lights while the empty south stayed warm. Same
// colour, same radius, same height; only x/y move.
// v17.76 (2026-09-05): '1 0.9 0.78' was THE OLIVE POOL. The floor's colourMap is $white_diffuse, so this
// one warm omni painted the spawn, the core's face, hands, guns and zombies olive-yellow; Miami's warm
// sky-light tinted everything the same way and hid it (the Workshop screenshots show the base gold-olive
// under Miami too) — the blue sky exposed it. Cool white now, same radius/stops. Read docs/104 §4d.
// v17.78: back to the warm '1 0.9 0.78' — the v17.76 cool-white swap was part of the yellow hunt
// the user asked to revert whole ("revert all the code we touched") for the Miami A/B screenshot.
light('tod light base spawn', SPAWN_BAND_X - 10, 0, 200, '1 0.9 0.78', 420, 6, BASE_LIGHT_BAKE);
for (let lap = 0; lap < LAPS; lap++) {
  const b = lap * LAP_RISE, c = lapPal(lap).light;
  const oddl = (lap % 2 === 0);
  if (oddl) {
    light(`tod light lap${lap + 1} mid`, 336, 336, b + FLIGHT_RISE + 160, c, 420, 6, 1);
    light(`tod light lap${lap + 1} end`, -336, 336, b + LAP_RISE + 160, c, 420, 6, 1);
  } else {
    light(`tod light lap${lap + 1} mid`, -336, -336, b + FLIGHT_RISE + 160, c, 420, 6, 1);
    light(`tod light lap${lap + 1} end`, 336, -336, b + LAP_RISE + 160, c, 420, 6, 1);
  }
  // v13 LOUNGE LIGHTS — the room has a roof now, so it must light itself: two
  // interior pools plus one over the spur pad, all in the lounge's THEME color
  // (BREATHER_THEME) rather than the lap-cycle color the deck used to borrow.
  if (BREATHER_LAPS.has(lap + 1)) {
    const s = oddl ? 1 : -1, mz = b + FLIGHT_RISE;
    const tl = BREATHER_THEME[lap + 1].light;

    light(`tod light lap${lap + 1} breather`, s * 448, s * (PX + BR_DEPTH / 2), mz + 220, tl, 460, 6, 1);
    light(`tod light lap${lap + 1} breather w`, s * 640, s * 540, mz + 220, tl, 380, 6, 1);
    light(`tod light lap${lap + 1} breather pad`, s * SPUR_CX, s * SPUR_PAD_Y, mz + 190, tl, 380, 6, 1);
    // v16.7 ACCENT POOLS — one per fixture panel, 40u into the room from the
    // machine's origin (odd frame = -BR_FURN, mirrored by s like the three
    // above), radius 240: each amenity sits in its own theme-coloured pool
    // against its lit panel. +4 lights per lounge, 16 map-wide.
    if (BR_POLISH) {
      const aP = [-BR_FURN.pap.org[0] - 44, -BR_FURN.pap.org[1]];
      const aS = [-BR_FURN.station.org[0], -BR_FURN.station.org[1] + 40];
      const aC = [-BR_FURN.crate.org[0] + 40, -BR_FURN.crate.org[1]];
      const aK = [(-BR_FURN.perk_e.trig[0] - BR_FURN.perk_w.trig[0]) / 2, -BR_FURN.perk_e.trig[1] - 40];
      light(`tod light lap${lap + 1} breather pap`, s * aP[0], s * aP[1], mz + 120, tl, 240, 6, 1);
      light(`tod light lap${lap + 1} breather station`, s * aS[0], s * aS[1], mz + 120, tl, 240, 6, 1);
      light(`tod light lap${lap + 1} breather crate`, s * aC[0], s * aC[1], mz + 120, tl, 240, 6, 1);
      light(`tod light lap${lap + 1} breather perks`, s * aK[0], s * aK[1], mz + 120, tl, 240, 6, 1);
    }
    
  }
}
// THE CROWN (v9) — gold on the approach, cyan at the gate, gold in the hall,
// green over the extraction pad, a red beacon on the mast tip.
{
  const CL = (label, x, y, z, color, radius) => { const [a, b, c] = cpt(x, y, z); light(label, a, b, c, color, radius, 6, 1); };
  CL('tod light crown stair', 336, 0, TOP + 96 + 160, '1 0.85 0.35', 460);
  CL('tod light terrace W', -300, 368, TOP2 + 170, '1 0.85 0.35', 460);
  CL('tod light terrace E', 300, 368, TOP2 + 170, '1 0.85 0.35', 460);
  // one per on-axis stretch and one down the middle of every branch (7). A
  // fraction-of-length point would now hang in the air over a fork.
  causewayLightPointsCrownFrame().forEach((o, k) => CL(`tod light causeway ${k + 1}`, o[0], o[1], o[2] + 180, '0.35 0.9 1', 420));
  CL('tod light crown gate', 0, HS + 60, TOP2 + 200, '0.35 0.9 1', 520);
  // The four hall lights hang on the quarter points at +260 — since v16.35
  // that is 24u outside the pier line (bases end at x 440) and 44u above the
  // beam top (+216), so each one lights an aisle bay and the nave beside it.
  // Nothing in the basilica reaches +260: pier caps +216, canopies +248.
  const HQ = 448;
  CL('tod light hall SW', -HQ, HYC - HQ, TOP2 + 260, '1 0.85 0.35', 620);
  CL('tod light hall SE', HQ, HYC - HQ, TOP2 + 260, '1 0.85 0.35', 620);
  CL('tod light hall NW', -HQ, HYC + HQ, TOP2 + 260, '1 0.85 0.35', 620);
  CL('tod light hall NE', HQ, HYC + HQ, TOP2 + 260, '1 0.85 0.35', 620);
  CL('tod light hall dais', 0, HYC, TOP2 + 240, '1 0.95 0.5', 520);
  CL('tod light extraction', 0, EXFIL_Y, TOP2 + 200, '0.35 1 0.6', 460);
  // v16.35 THE BASILICA: one warm light under each shrine canopy (canopy
  // underside +216, the machines top out ~+127, so +160 sits in the clear
  // between them), and a wash on the reredos from 64u in front of its face.
  CL('tod light shrine W', -600, HYC, TOP2 + 160, '1 0.85 0.35', 360);
  CL('tod light shrine E', 600, HYC, TOP2 + 160, '1 0.85 0.35', 360);
  CL('tod light reredos', 0, HN - HWALL - 96, TOP2 + 300, '1 0.85 0.35', 420);
  light('tod light mast beacon', 0, 0, MAST_TOP + 24, '1 0.25 0.2', 900, 6, 1);
  // THE CIRCLET'S ONLY THREE LIGHTS (v11, +1 in v12). A 900-unit light does
  // nothing for a 4096-unit object, so the crown's exterior read is carried by
  // MATERIAL and these exist only to make the RED points of the vertical axis
  // bloom: the beacon at the apex, the great ruby on the front cross, and —
  // v12 — the GIRANDOLE hanging under the bell, which is the one object every
  // climbing player faces for fifty floors. Adding more would cost bake time
  // and change nothing anyone can see from the tower.
  CL('tod light crown ruby', 0, CR_CY - PT_Y - 300, TOP2 + CR_RIM_Z + 2016, '1 0.25 0.2', 900);
  CL('tod light crown beacon', 0, CR_CY, CROWN_TOP + 24, '1 0.25 0.2', 900);
  // SOUTH of the orb, not centred on it: at (0, CR_CY, orb-height) the origin
  // sits INSIDE the CS(264)-half ruby equator brush and a light inside solid
  // illuminates nothing (caught by arithmetic 2026-08-26, the same trap as the
  // entombed quarter-beacons). CS(480) south clears the orb by ~300 and biases
  // the bloom onto the pendant's SOUTH face — the only side anybody sees.
  CL('tod light crown girandole', 0, CR_CY - CS(480), TOP2 + CR_SKIRT_BOT - CS(480), '1 0.25 0.2', 900);
  // and one warm wash inside the circlet's mouth, where the party walks through
  CL('tod light crown mouth', 0, CR_CY - CR_HY + 160, TOP2 + 300, '1 0.85 0.35', 560);
}

// --- reflection probes: base + every 3rd lap + roof --------------------------
function probe(label, x, y, z) {
  ent(label, [
    '{', `guid "${guid()}"`, kv('classname', 'reflection_probe'),
    kv('origin', `${x} ${y} ${z}`), kv('radius', '2048'),
    kv('ao_power', '2'), kv('ao_range', '16'), kv('ao_strength', '1'),
    kv('blend_maxs', '3 3 3'), kv('blend_mins', '3 3 3'), kv('box', '1'),
    kv('client_server', 'ClientSide'), kv('debugColor', '1 1 1'),
    kv('debug_render_index_x', '64'), kv('exploderFade', '1'),
    kv('grid_density', '16'), kv('high_detail', '1'), kv('in_play_space', '1'),
    kv('name', 'probe'), kv('placement_offset', '72'),
    kv('size_max', '72 72 72'), kv('size_min', '72 72 72'), '}',
  ]);
}
probe('probe base', 0, -490, 150);
for (let lap = 1; lap <= LAPS; lap += 3) {
  const pxp = (lap % 2 === 1) ? 336 : -336;
  probe(`probe lap${lap}`, pxp, pxp, (lap - 1) * LAP_RISE + FLIGHT_RISE + 150);
}
{
  const [tx, ty, tz] = cpt(0, 368, TOP2 + 150);
  probe('probe crown terrace', tx, ty, tz);
  const [hx, hy, hz] = cpt(0, HYC, TOP2 + 200);
  probe('probe crown hall', hx, hy, hz);
  // v11: `probe crown hall` has radius 2048 and the circlet now reaches +-2048
  // in x and 1696 in y off centre, so the band, the points and the arches were
  // all outside every probe in the map. Three more cover the ring's south face
  // (the one everybody looks at), its north face, and the upper crown.
  const RP = (label, x, y, z) => { const [a, b, c2] = cpt(x, y, z); probe(label, a, b, c2); };
  RP('probe crown ring S', 0, CR_CY - CR_HY - 256, TOP2 + CR_C2_Z);
  RP('probe crown ring N', 0, CR_CY + CR_HY + 256, TOP2 + CR_C2_Z);
  RP('probe crown upper', 0, CR_CY, TOP2 + CR_ARCH_CROWN);
}

// --- volume_sun / umbra / fpstool -------------------------------------------
ent('volume_sun', [
  '{', `guid "${guid()}"`, kv('classname', 'volume_sun'),
  kv('ssi', SSI), kv('grid_density', '32'), kv('shadowBiasScale', '1'),
  kv('shadowSplitDistance', '2000'), kv('ssi1', SSI), kv('streamLighting', '1'),
  matBrush(-(SKY_IN + SKY_TH), SKY_IN + SKY_TH, -(SKY_IN + SKY_TH), SKY_IN + SKY_TH, SKY_BOT, SKY_TOP + SKY_TH, 'sun_volume'),
  '}',
]);
// bounds cover the breather balconies (out to y=708), the power hallway (x to
// 1640), the crown hall (outer face at |y|=HN plus its cornice) and — v11 —
// THE CIRCLET, which reaches 10304 in y and 2112 in x. Geometry outside the
// umbra/fpstool volume is not a crash, but it drops out of occlusion culling
// and out of the fps tool's accounting, and the crown is now the largest single
// object in the map.
const VOL_R = Math.max(ARENA + WALL, PX + BR_DEPTH + PARA + 12, SPUR_Y2 + 60, 1700, HN + 64,
  Math.max(-crownBB.x1, crownBB.x2, -crownBB.y1, crownBB.y2) + 128,
  // v14: the spire drops out of occlusion culling + fps accounting if the
  // umbra/fpstool volumes stop short of it (the crown's own lesson)
  SPIRE_ENABLED ? SP_X + ARENA + WALL + 128 : 0);
if (Math.max(-crownBB.x1, crownBB.x2, -crownBB.y1, crownBB.y2) + 64 > VOL_R)
  throw new Error(`crown reaches ${Math.max(-crownBB.x1, crownBB.x2, -crownBB.y1, crownBB.y2)} but the umbra/fpstool volume stops at ${VOL_R}`);
ent('umbra_volume', [
  '{', `guid "${guid()}"`, kv('classname', 'umbra_volume'),
  matBrush(-VOL_R, VOL_R, -VOL_R, VOL_R, -SLAB, SKY_TOP - 200, 'umbra_volume'),
  '}',
]);
ent('volume_fpstool', [
  '{', `guid "${guid()}"`, kv('classname', 'volume_fpstool'),
  matBrush(-VOL_R, VOL_R, -VOL_R, VOL_R, -SLAB, SKY_TOP - 200, 'volume_fpstool'),
  '}',
]);

// ---------------------------------------------------------------------------
// 6. THE ENDLESS SPIRE (v14, docs/44) — everything inside this ONE gated block.
// Emission order is load-bearing for the freeze envelope: the block sits LAST,
// after every existing brush and entity, so enabling it APPENDS — no existing
// guid shifts, and with SPIRE_ENABLED=false the output is byte-identical to
// the pre-spire generator (proven by scratch diff, not assumed).
// ---------------------------------------------------------------------------
if (SPIRE_ENABLED) {
  const SPIRE_GSC_OUT = path.join(REPO, 'scripts', 'zm', 'zm_tower_of_doom', '_tod_spire_data.gsc');
  const sb0 = worldBrushes.length, se0 = entities.length;

  // local-frame emitters: everything below is authored around (0,0) and offset
  const sbox = (label, x1, x2, y1, y2, z1, z2, mat) =>
    addBox(`spire ${label}`, SP_X + x1, SP_X + x2, SP_Y + y1, SP_Y + y2, z1, z2, mat);
  // v19.69 THE SURFACE REFRESH: sbox with per-face materials (see addBoxFaces)
  const sboxF = (label, x1, x2, y1, y2, z1, z2, mat, faces) =>
    addBoxFaces(`spire ${label}`, SP_X + x1, SP_X + x2, SP_Y + y1, SP_Y + y2, z1, z2, mat, faces);
  const svol = (x1, x2, y1, y2, z1, z2) =>
    volumeBrush(SP_X + x1, SP_X + x2, SP_Y + y1, SP_Y + y2, z1, z2);
  // A shelf crate's body box in the spire's local frame (see the crate contract
  // near SP_FURN): asserted INSIDE the shelf floor it stands on, at either parity.
  const shelfCrateBox = (lap, cx, cy, yaw, mid) => {
    const cb = crateBox(cx, cy, yaw);
    const sx1 = Math.min(SP_SHELF_X1, -SP_SHELF_X2) , sx2 = Math.max(SP_SHELF_X2, -SP_SHELF_X1);
    const sy1 = Math.min(SP_SHELF_Y1, -SP_SHELF_Y2) , sy2 = Math.max(SP_SHELF_Y2, -SP_SHELF_Y1);
    const onOdd  = cb.x1 >= SP_SHELF_X1 && cb.x2 <= SP_SHELF_X2 && cb.y1 >= SP_SHELF_Y1 && cb.y2 <= SP_SHELF_Y2;
    const onEven = cb.x1 >= -SP_SHELF_X2 && cb.x2 <= -SP_SHELF_X1 && cb.y1 >= -SP_SHELF_Y2 && cb.y2 <= -SP_SHELF_Y1;
    if (!onOdd && !onEven) throw new Error(`lap${lap + 1} shelf crate box x[${cb.x1},${cb.x2}] y[${cb.y1},${cb.y2}] is not inside its shelf floor (x[${sx1},${sx2}] y[${sy1},${sy2}])`);
    sbox(`lap${lap + 1} shelf ammo crate body`, cb.x1, cb.x2, cb.y1, cb.y2, mid, mid + CRATE_BOX_H, MAT.clip);
    crateCap(`spire lap${lap + 1} shelf ammo crate`, { x1: SP_X + cb.x1, x2: SP_X + cb.x2, y1: SP_Y + cb.y1, y2: SP_Y + cb.y2 }, mid, yaw);
  };
  // Navmesh seed in the same local frame as sbox (see navSeed by worldBrushes).
  const snav = (label, x, y, z) => navSeed(`spire ${label}`, SP_X + x, SP_Y + y, z);

  // --- seal fit + clearances, asserted (the crown's own doctrine) -----------
  // v16.19: the hub drums (SP_RM_OUT + wall + band) are inside the base arena's
  // footprint; the crate shelves are the spiral's widest reach.
  const spExtX = Math.max(ARENA + WALL, SP_RM_OUT + SP_RM_WALL + 8, SP_SHELF_X2 + PARA);
  const spExtY = Math.max(ARENA + WALL, SP_RM_OUT + SP_RM_WALL + 8);
  if (SP_X + spExtX + 256 > SKY_IN) throw new Error(`spire east face ${SP_X + spExtX} inside the sky seal margin (SKY_IN ${SKY_IN})`);
  if (SP_X - spExtX < Math.max(crownBB.x2, CW_XMAX) + 512) throw new Error('spire west face crowds the crown/causeway envelope');
  if (Math.abs(SP_Y) + spExtY + 256 > SKY_IN) throw new Error('spire y extent inside the sky seal margin');
  if (SP_TOP2 + SP_BEACON_H + 300 > SKY_TOP) throw new Error('spire beacon through the sky ceiling — SKY_TOP max() is broken');

  // --- 6a. arrival arena (the base arena's proven shape, no annexes) --------
  sbox('ground slab', -(ARENA + WALL), ARENA + WALL, -(ARENA + WALL), ARENA + WALL, -SLAB, 0, MAT.ground);
  sbox('base inlay N', -(ARENA - 20), ARENA - 20, ARENA - 84, ARENA - 20, 0, 1, MAT.jewelRuby);
  sbox('base inlay S', -(ARENA - 20), ARENA - 20, -(ARENA - 20), -(ARENA - 84), 0, 1, MAT.jewelRuby);
  sbox('base inlay W', -(ARENA - 20), -(ARENA - 84), -(ARENA - 84), ARENA - 84, 0, 1, MAT.jewelRuby);
  sbox('base inlay E', ARENA - 84, ARENA - 20, -(ARENA - 84), ARENA - 84, 0, 1, MAT.jewelRuby);
  // where the ascension drops you — green, the same "landing point" grammar as
  // the teleport bay's arrival mark. CENTRED ON THE WEST BAND at x=-400 (live
  // test 2026-08-29: the first cut sat at x=-200 — INSIDE THE CORE COLUMN's
  // footprint (|x|<256), so the engine shoved arrivals out under the stairs).
  // The open band is x[-540,-256]; -400 is its centre, players land facing
  // the tower they are about to climb.
  sbox('arrival mark', -488, -312, -88, 88, 0, 1, MAT.exfilPad);
  // v19.68s THE CRASHED CORNER (docs/170): with the rockets on, wall N and wall W stop where the wreck's hull leans
  // out over the NW corner (RK_CORNER, the ROCKETS block) - the off switch emits the whole walls in the same order.
  if (RK_CORNER) sbox('wall N', RK_CORNER.nx + 40, ARENA + WALL, ARENA, ARENA + WALL, 0, BASE_WALL_H, SP_MAT_CORE);
  else sbox('wall N', -(ARENA + WALL), ARENA + WALL, ARENA, ARENA + WALL, 0, BASE_WALL_H, SP_MAT_CORE);
  sbox('wall S', -(ARENA + WALL), ARENA + WALL, -(ARENA + WALL), -ARENA, 0, BASE_WALL_H, SP_MAT_CORE);
  if (RK_CORNER) sbox('wall W', -(ARENA + WALL), -ARENA, -ARENA, RK_CORNER.wy - 40, 0, BASE_WALL_H, SP_MAT_CORE);
  else sbox('wall W', -(ARENA + WALL), -ARENA, -ARENA, ARENA, 0, BASE_WALL_H, SP_MAT_CORE);
  sbox('wall E', ARENA, ARENA + WALL, -ARENA, ARENA, 0, BASE_WALL_H, SP_MAT_CORE);
  if (RK_CORNER) sbox('clip N', RK_CORNER.nx + 40, ARENA + WALL, ARENA, ARENA + WALL, BASE_WALL_H, 1600, MAT.clip);
  else sbox('clip N', -(ARENA + WALL), ARENA + WALL, ARENA, ARENA + WALL, BASE_WALL_H, 1600, MAT.clip);
  sbox('clip S', -(ARENA + WALL), ARENA + WALL, -(ARENA + WALL), -ARENA, BASE_WALL_H, 1600, MAT.clip);
  if (RK_CORNER) sbox('clip W', -(ARENA + WALL), -ARENA, -ARENA, RK_CORNER.wy - 40, BASE_WALL_H, 1600, MAT.clip);
  else sbox('clip W', -(ARENA + WALL), -ARENA, -ARENA, ARENA, BASE_WALL_H, 1600, MAT.clip);
  sbox('clip E', ARENA, ARENA + WALL, -ARENA, ARENA, BASE_WALL_H, 1600, MAT.clip);
  if (RK_CORNER) {
    // the break: a stub under the hull, each wall crumbling down to it over its last 40 units, the boundary clip
    // down to the stub (the arena stays closed), and the wreck's own clip column (a script_model has no collision).
    // The stub's TOP wears the plain parapet red, the honest class for a wall top under a clip cap (a rail's, the
    // geometry lint classes a brush by its top face): in the wall's own red_tinted a 40-tall stub is a DECK slab
    // with an invisible wall standing on it
    sboxF('rocket crash stub N', -(ARENA + WALL), RK_CORNER.nx, ARENA, ARENA + WALL, 0, RK_STUB_H, SP_MAT_CORE, { top: SP_MAT_PARA });
    sboxF('rocket crash stub W', -(ARENA + WALL), -ARENA, RK_CORNER.wy, ARENA, 0, RK_STUB_H, SP_MAT_CORE, { top: SP_MAT_PARA });
    for (const r of RK_CORNER.rubble) sbox(r.label, ...r.b, SP_MAT_CORE);
    sbox('rocket crash clip N', -(ARENA + WALL), RK_CORNER.nx + 40, ARENA, ARENA + WALL, RK_STUB_H, 1600, MAT.clip);
    sbox('rocket crash clip W', -(ARENA + WALL), -ARENA, RK_CORNER.wy - 40, ARENA, RK_STUB_H, 1600, MAT.clip);
    sbox('rocket wreck body', ...RK_CORNER.clip, MAT.clip);
  }
  // the arena's own ammo crate (floors 1-4 have no shelf — the arena E clip
  // spans z128..1600 and a shelf below floor 5 would bury itself in it).
  // S wall, facing NORTH (CRATE_YAW_N), clear of the arrival (272u to the
  // nearest riser, 96-door far away).
  // v17.38: A REAL .map BOX AGAIN. The 2026-08-29 live report ("the trigger
  // crate and clip are not all aligned") was the yaw-270 occupancy emitted
  // under a crate at another yaw; the answer then was script clips — a 3-row
  // of perk-machine colliders that ran FRONT-TO-BACK through the crate and
  // planted an invisible lip in front of its face. crateBox() now rotates the
  // measured occupancy to the crate's own yaw, so the box IS the mesh and the
  // lint can see it. y moved -505 -> -500 so the box clears the S wall's inner
  // face (-ARENA) by 3u instead of cutting 2u into it.
  const SP_ARENA_CRATE = [-200, -500];
  {
    const cb = crateBox(SP_ARENA_CRATE[0], SP_ARENA_CRATE[1], CRATE_YAW_N);
    if (cb.y1 < -ARENA) throw new Error(`spire arena crate box cuts into wall S by ${-ARENA - cb.y1}u`);
    sbox('arena ammo crate body', cb.x1, cb.x2, cb.y1, cb.y2, 0, CRATE_BOX_H, MAT.clip);
    crateCap('spire arena ammo crate', { x1: SP_X + cb.x1, x2: SP_X + cb.x2, y1: SP_Y + cb.y1, y2: SP_Y + cb.y2 }, 0, CRATE_YAW_N);
  }

  // --- 6b. the core (monochrome, no palette cycle) ---------------------------
  // v16.19 — THE CENTRE OPENS at every hub: the column stops at the hub's mid
  // landing (the hall floor) and resumes SP_RM_VOID_H higher, so the hall's
  // void is the tower's own interior; the last hub's void ends at the capital.
  {
    let z0 = 0;
    for (let f = SP_HUB_EVERY; f <= SP_LAPS; f += SP_HUB_EVERY) {
      const hmid = (f - 1) * LAP_RISE + FLIGHT_RISE;
      sbox(`core column below hub ${f}`, -CORE, CORE, -CORE, CORE, z0, hmid - SLAB, SP_MAT_CORE);   // ends UNDER the hall floor slab: a core top at mid would z-fight the slab top
      z0 = (f === SP_LAPS) ? SP_TOP : hmid + SP_RM_VOID_H;
    }
    if (z0 < SP_TOP) sbox('core column top', -CORE, CORE, -CORE, CORE, z0, SP_TOP, SP_MAT_CORE);
  }
  sbox('core capital', -CORE, CORE, -CORE, CORE, SP_TOP, SP_TOP2, MAT.crownBand);

  // --- 6c. the spiral: the tower's own lap grammar, red, with hubs + shelves -
  const SP_HUBS = [];
  for (let lap = 0; lap < SP_LAPS; lap++) {
    const b = lap * LAP_RISE;
    const odd = (lap % 2 === 0);
    const mid = b + FLIGHT_RISE, end = b + LAP_RISE;
    const hub = ((lap + 1) % SP_HUB_EVERY === 0);
    // v16.19: no shelf on the floor right after a hub either — that floor's E
    // flight runs INSIDE the hub drum and a shelf there would jut through the
    // drum wall (the lint found the nine of them detached). The hall's own
    // crate is one flight below.
    const postHub = (lap > 0 && lap % SP_HUB_EVERY === 0);
    const sh = !hub && !postHub && (lap + 1) >= 5;   // crate shelf (floors 5+, hub + post-hub floors excluded)
    if (hub) SP_HUBS.push(lap + 1);

    if (odd) {
      for (let i = 1; i <= STEPS; i++)
        sboxF(`lap${lap + 1} E step ${i}`, CORE, PX, -CORE + TREAD * (i - 1), -CORE + TREAD * i, ...slabZ(b + RISE * i), SP_MAT_STEP, treadFaces('s', 'n', 'e', RF_SPIRE_RISER, RF_SPIRE_SOFFIT));
      // v16.80: the tower's lap-1 under-stair fill, same shape (see section 4).
      if (lap === 0) {
        for (let i = 2; i <= STEPS; i++)
          sbox(`lap1 E under-stair fill ${i}`, CORE, PX, -CORE + TREAD * (i - 1), -CORE + TREAD * i, b, b + RISE * i - SLAB, SP_MAT_CORE);
      }
      sboxF(`lap${lap + 1} NE landing`, CORE, PX, CORE, PX, ...slabZ(mid), SP_MAT_LAND, landingFaces(['e', 'n'], RF_SPIRE_SOFFIT));
      for (let i = 1; i <= STEPS; i++)
        sboxF(`lap${lap + 1} N step ${i}`, CORE - TREAD * i, CORE - TREAD * (i - 1), CORE, PX, ...slabZ(mid + RISE * i), SP_MAT_STEP, treadFaces('e', 'w', 'n', RF_SPIRE_RISER, RF_SPIRE_SOFFIT));
      sboxF(`lap${lap + 1} NW landing`, -PX, -CORE, CORE, PX, ...slabZ(end), SP_MAT_LAND, landingFaces(['w', 'n'], RF_SPIRE_SOFFIT));
      if (STAIR_RAMP_CLIP) {
        rampWedgeY(`spire lap${lap + 1} E stair ramp`, SP_X + CORE, SP_X + PX, SP_Y - CORE - TREAD, SP_Y + CORE - TREAD, b, b + FLIGHT_RISE, MAT.rampClip);
        rampWedgeX(`spire lap${lap + 1} N stair ramp`, SP_Y + CORE, SP_Y + PX, SP_X - CORE + TREAD, SP_X + CORE + TREAD, mid + FLIGHT_RISE, mid, MAT.rampClip);
      }
      // parapets (the tower's exact stepped grammar, incl. the lap-1 wall)
      if (lap === 0) {
        sbox('lap1 E parapet (anti-bypass wall)', PX, PX + PARA, -CORE, CORE, 0, 288, SP_MAT_CORE);
      } else {
        for (let j = 1; j <= STEPS / PARA_EVERY; j++) {
          const top = b + RISE * PARA_EVERY * j;
          sbox(`lap${lap + 1} E para ${j}`, PX, PX + PARA, -CORE + TREAD * PARA_EVERY * (j - 1), -CORE + TREAD * PARA_EVERY * j, top - RISE * (PARA_EVERY - 1), top + PARA_H, SP_MAT_PARA);
        }
      }
      for (let j = 1; j <= STEPS / PARA_EVERY; j++) {
        const top = mid + RISE * PARA_EVERY * j;
        sbox(`lap${lap + 1} N para ${j}`, CORE - TREAD * PARA_EVERY * j, CORE - TREAD * PARA_EVERY * (j - 1), PX, PX + PARA, top - RISE * (PARA_EVERY - 1), top + PARA_H, SP_MAT_PARA);
      }
      // mid-landing rails: full / shelf-split / hub-mouth
      if (sh) {
        sbox(`lap${lap + 1} NE landing para a1`, PX, PX + PARA, CORE, SP_SHELF_Y1, mid, mid + PARA_H, SP_MAT_PARA);
        sbox(`lap${lap + 1} NE landing para a2`, PX, PX + PARA, SP_SHELF_Y2, PX + PARA, mid, mid + PARA_H, SP_MAT_PARA);
      } else if (!hub) {
        sbox(`lap${lap + 1} NE landing para a`, PX, PX + PARA, CORE, PX + PARA, mid, mid + PARA_H, SP_MAT_PARA);
      } else {
        sbox(`lap${lap + 1} NE landing para a`, PX, PX + PARA, CORE, PX, mid, mid + PARA_H, SP_MAT_PARA);
      }
      if (!hub) sbox(`lap${lap + 1} NE landing para b`, CORE, PX, PX, PX + PARA, mid, mid + PARA_H, SP_MAT_PARA);
      sbox(`lap${lap + 1} NW landing para a`, -PX - PARA, -PX, CORE, PX + PARA, end, end + PARA_H, SP_MAT_PARA);
      sbox(`lap${lap + 1} NW landing para b`, -PX, -CORE, PX, PX + PARA, end, end + PARA_H, SP_MAT_PARA);
      // rail caps
      if (lap === 0) {
        sbox('lap1 rail cap E over wall', PX, PX + PARA, -CORE, CORE, 288, b + FLIGHT_RISE + PARA_H + RAIL_CAP_H, MAT.clip);
        sbox('lap1 rail cap E landing', PX, PX + PARA, CORE, PX + PARA, mid + PARA_H, b + FLIGHT_RISE + PARA_H + RAIL_CAP_H, MAT.clip);
      } else if (sh) {
        sbox(`lap${lap + 1} rail cap E a`, PX, PX + PARA, -CORE, SP_SHELF_Y1, b + PARA_H, b + FLIGHT_RISE + PARA_H + RAIL_CAP_H, MAT.clip);
        sbox(`lap${lap + 1} rail cap E b`, PX, PX + PARA, SP_SHELF_Y2, PX + PARA, b + PARA_H, b + FLIGHT_RISE + PARA_H + RAIL_CAP_H, MAT.clip);
      } else {
        sbox(`lap${lap + 1} rail cap E`, PX, PX + PARA, -CORE, (hub ? PX : PX + PARA), b + PARA_H, b + FLIGHT_RISE + PARA_H + RAIL_CAP_H, MAT.clip);
      }
      sbox(`lap${lap + 1} rail cap N`, -CORE, (hub ? CORE : PX + PARA), PX, PX + PARA, mid + PARA_H, mid + FLIGHT_RISE + PARA_H + RAIL_CAP_H, MAT.clip);
      sbox(`lap${lap + 1} rail cap NW a`, -PX - PARA, -PX, CORE, PX + PARA, end + PARA_H, end + PARA_H + RAIL_CAP_H, MAT.clip);
      sbox(`lap${lap + 1} rail cap NW b`, -PX, -CORE, PX, PX + PARA, end + PARA_H, end + PARA_H + RAIL_CAP_H, MAT.clip);
      if (sh) {
        // THE THRESHOLD (v14.23, live report: "there is a whole and no floor
        // to get to them"): the landing ends at PX and the shelf starts at
        // SP_SHELF_X1 = PX+PARA — the 20u parapet-gap band between them was a
        // bottomless slot the lint's 20u sampling stepped exactly over. This
        // strip closes it, flanked by para a1/a2 so every edge is guarded.
        sbox(`lap${lap + 1} shelf threshold`, PX, SP_SHELF_X1, SP_SHELF_Y1, SP_SHELF_Y2, mid - SLAB, mid, SP_MAT_LAND);
        sbox(`lap${lap + 1} shelf floor`, SP_SHELF_X1, SP_SHELF_X2, SP_SHELF_Y1, SP_SHELF_Y2, mid - SLAB, mid, SP_MAT_LAND);
        sbox(`lap${lap + 1} shelf rail E`, SP_SHELF_X2, SP_SHELF_X2 + PARA, SP_SHELF_Y1, SP_SHELF_Y2, mid, mid + PARA_H, SP_MAT_PARA);
        sbox(`lap${lap + 1} shelf rail N`, SP_SHELF_X1, SP_SHELF_X2 + PARA, SP_SHELF_Y2, SP_SHELF_Y2 + PARA, mid, mid + PARA_H, SP_MAT_PARA);
        sbox(`lap${lap + 1} shelf rail S`, SP_SHELF_X1, SP_SHELF_X2 + PARA, SP_SHELF_Y1 - PARA, SP_SHELF_Y1, mid, mid + PARA_H, SP_MAT_PARA);
        sbox(`lap${lap + 1} shelf cap E`, SP_SHELF_X2, SP_SHELF_X2 + PARA, SP_SHELF_Y1 - PARA, SP_SHELF_Y2 + PARA, mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
        sbox(`lap${lap + 1} shelf cap N`, SP_SHELF_X1, SP_SHELF_X2 + PARA, SP_SHELF_Y2, SP_SHELF_Y2 + PARA, mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
        sbox(`lap${lap + 1} shelf cap S`, SP_SHELF_X1, SP_SHELF_X2 + PARA, SP_SHELF_Y1 - PARA, SP_SHELF_Y1, mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
        // The shelf is a 128x120 dead-end bump-out off the mid landing with
        // no riser on it, so no seed ever reached it. Dead centre of the
        // floor, clear of the threshold and of the flight footprint.
        snav(`lap${lap + 1} shelf`, (SP_SHELF_X1 + SP_SHELF_X2) / 2, (SP_SHELF_Y1 + SP_SHELF_Y2) / 2, mid + 2);
        // THE SHELF CRATE'S BODY (v17.38) — a real .map box from the one crate
        // contract, replacing the v14.23 "single collider at the origin" (a
        // perk-machine box that matched neither the mesh nor its yaw). The
        // crate MODEL still materializes/de-rezzes with the ±3-floor window
        // (_tod_spire::crate_window); the box is resident, which is safe
        // because a player standing on this shelf is inside that window by
        // definition. Asserted inside the shelf floor so it can never hang over
        // a rail, and the lint's MODEL_CLIP_COLUMNS matches the label.
        shelfCrateBox(lap, SP_CRATE_LX, SP_CRATE_LY, CRATE_YAW_W, mid);
      }
    } else {
      for (let i = 1; i <= STEPS; i++)
        sboxF(`lap${lap + 1} W step ${i}`, -PX, -CORE, CORE - TREAD * i, CORE - TREAD * (i - 1), ...slabZ(b + RISE * i), SP_MAT_STEP, treadFaces('n', 's', 'w', RF_SPIRE_RISER, RF_SPIRE_SOFFIT));
      sboxF(`lap${lap + 1} SW landing`, -PX, -CORE, -PX, -CORE, ...slabZ(mid), SP_MAT_LAND, landingFaces(['w', 's'], RF_SPIRE_SOFFIT));
      for (let i = 1; i <= STEPS; i++)
        sboxF(`lap${lap + 1} S step ${i}`, -CORE + TREAD * (i - 1), -CORE + TREAD * i, -PX, -CORE, ...slabZ(mid + RISE * i), SP_MAT_STEP, treadFaces('w', 'e', 's', RF_SPIRE_RISER, RF_SPIRE_SOFFIT));
      sboxF(`lap${lap + 1} SE landing`, CORE, PX, -PX, -CORE, ...slabZ(end), SP_MAT_LAND, landingFaces(['e', 's'], RF_SPIRE_SOFFIT));
      if (STAIR_RAMP_CLIP) {
        rampWedgeY(`spire lap${lap + 1} W stair ramp`, SP_X - PX, SP_X - CORE, SP_Y - CORE + TREAD, SP_Y + CORE + TREAD, b + FLIGHT_RISE, b, MAT.rampClip);
        rampWedgeX(`spire lap${lap + 1} S stair ramp`, SP_Y - PX, SP_Y - CORE, SP_X - CORE - TREAD, SP_X + CORE - TREAD, mid, mid + FLIGHT_RISE, MAT.rampClip);
      }
      for (let j = 1; j <= STEPS / PARA_EVERY; j++) {
        const top = b + RISE * PARA_EVERY * j;
        sbox(`lap${lap + 1} W para ${j}`, -PX - PARA, -PX, CORE - TREAD * PARA_EVERY * j, CORE - TREAD * PARA_EVERY * (j - 1), top - RISE * (PARA_EVERY - 1), top + PARA_H, SP_MAT_PARA);
      }
      for (let j = 1; j <= STEPS / PARA_EVERY; j++) {
        const top = mid + RISE * PARA_EVERY * j;
        sbox(`lap${lap + 1} S para ${j}`, -CORE + TREAD * PARA_EVERY * (j - 1), -CORE + TREAD * PARA_EVERY * j, -PX - PARA, -PX, top - RISE * (PARA_EVERY - 1), top + PARA_H, SP_MAT_PARA);
      }
      if (sh) {
        sbox(`lap${lap + 1} SW landing para a1`, -PX - PARA, -PX, -SP_SHELF_Y1, -CORE, mid, mid + PARA_H, SP_MAT_PARA);
        sbox(`lap${lap + 1} SW landing para a2`, -PX - PARA, -PX, -PX - PARA, -SP_SHELF_Y2, mid, mid + PARA_H, SP_MAT_PARA);
      } else if (!hub) {
        sbox(`lap${lap + 1} SW landing para a`, -PX - PARA, -PX, -PX - PARA, -CORE, mid, mid + PARA_H, SP_MAT_PARA);
      } else {
        sbox(`lap${lap + 1} SW landing para a`, -PX - PARA, -PX, -PX, -CORE, mid, mid + PARA_H, SP_MAT_PARA);
      }
      if (!hub) sbox(`lap${lap + 1} SW landing para b`, -PX, -CORE, -PX - PARA, -PX, mid, mid + PARA_H, SP_MAT_PARA);
      sbox(`lap${lap + 1} SE landing para a`, PX, PX + PARA, -PX - PARA, -CORE, end, end + PARA_H, SP_MAT_PARA);
      sbox(`lap${lap + 1} SE landing para b`, CORE, PX, -PX - PARA, -PX, end, end + PARA_H, SP_MAT_PARA);
      if (sh) {
        sbox(`lap${lap + 1} rail cap W a`, -PX - PARA, -PX, -SP_SHELF_Y1, CORE, b + PARA_H, b + FLIGHT_RISE + PARA_H + RAIL_CAP_H, MAT.clip);
        sbox(`lap${lap + 1} rail cap W b`, -PX - PARA, -PX, -PX - PARA, -SP_SHELF_Y2, b + PARA_H, b + FLIGHT_RISE + PARA_H + RAIL_CAP_H, MAT.clip);
      } else {
        // v16.19: at a hub the cap stops under the hall floor (the NW piece
        // roofs this flight's lower half; above the floor the drum wall stands
        // beside the parapet, so nothing needs a cap there)
        sbox(`lap${lap + 1} rail cap W`, -PX - PARA, -PX, (hub ? -PX : -PX - PARA), CORE, b + PARA_H, (hub ? mid - SLAB : b + FLIGHT_RISE + PARA_H + RAIL_CAP_H), MAT.clip);
      }
      sbox(`lap${lap + 1} rail cap S`, (hub ? -CORE : -PX - PARA), CORE, -PX - PARA, -PX, mid + PARA_H, mid + FLIGHT_RISE + PARA_H + RAIL_CAP_H, MAT.clip);
      sbox(`lap${lap + 1} rail cap SE a`, PX, PX + PARA, -PX - PARA, -CORE, end + PARA_H, end + PARA_H + RAIL_CAP_H, MAT.clip);
      sbox(`lap${lap + 1} rail cap SE b`, CORE, PX, -PX - PARA, -PX, end + PARA_H, end + PARA_H + RAIL_CAP_H, MAT.clip);
      if (sh) {
        // THE THRESHOLD — even-frame mirror of the odd block's slot bridge.
        sbox(`lap${lap + 1} shelf threshold`, -SP_SHELF_X1, -PX, -SP_SHELF_Y2, -SP_SHELF_Y1, mid - SLAB, mid, SP_MAT_LAND);
        sbox(`lap${lap + 1} shelf floor`, -SP_SHELF_X2, -SP_SHELF_X1, -SP_SHELF_Y2, -SP_SHELF_Y1, mid - SLAB, mid, SP_MAT_LAND);
        sbox(`lap${lap + 1} shelf rail E`, -SP_SHELF_X2 - PARA, -SP_SHELF_X2, -SP_SHELF_Y2, -SP_SHELF_Y1, mid, mid + PARA_H, SP_MAT_PARA);
        sbox(`lap${lap + 1} shelf rail N`, -SP_SHELF_X2 - PARA, -SP_SHELF_X1, -SP_SHELF_Y2 - PARA, -SP_SHELF_Y2, mid, mid + PARA_H, SP_MAT_PARA);
        sbox(`lap${lap + 1} shelf rail S`, -SP_SHELF_X2 - PARA, -SP_SHELF_X1, -SP_SHELF_Y1, -SP_SHELF_Y1 + PARA, mid, mid + PARA_H, SP_MAT_PARA);
        sbox(`lap${lap + 1} shelf cap E`, -SP_SHELF_X2 - PARA, -SP_SHELF_X2, -SP_SHELF_Y2 - PARA, -SP_SHELF_Y1 + PARA, mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
        sbox(`lap${lap + 1} shelf cap N`, -SP_SHELF_X2 - PARA, -SP_SHELF_X1, -SP_SHELF_Y2 - PARA, -SP_SHELF_Y2, mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
        sbox(`lap${lap + 1} shelf cap S`, -SP_SHELF_X2 - PARA, -SP_SHELF_X1, -SP_SHELF_Y1, -SP_SHELF_Y1 + PARA, mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
        // ...and its mirror. Same reasoning as the odd frame above.
        snav(`lap${lap + 1} shelf`, -(SP_SHELF_X1 + SP_SHELF_X2) / 2, -(SP_SHELF_Y1 + SP_SHELF_Y2) / 2, mid + 2);
        shelfCrateBox(lap, -SP_CRATE_LX, -SP_CRATE_LY, CRATE_YAW_E, mid);   // the mirror: faces east toward the SW landing
      }
    }

    // THE HUB HALL (v16.19 / v16.21) — the tower's centre opens for one lap;
    // constants + rationale at SP_RM_*. Replaces the v16.15 outside arena.
    if (hub) {
      const H = `hub lap${lap + 1}`;
      const OUT = SP_RM_OUT, WL = OUT + SP_RM_WALL;              // 436 / 456
      const last = (lap + 1 === SP_LAPS);                         // the last hub (70): the summit caps the void
      const TOP = end + FLIGHT_RISE;                              // the next lap's NE landing level (mid + 384)
      const wallTop = last ? SP_TOP + PARA_H : mid + SP_RM_WALL_H;
      const L = SP_RM_LAYOUTS[SP_HUBS.length - 1];                // this hub's layout (SP_HUBS already holds this lap)
      const K = L.kit;                                            // v17.86: its material kit (floor / wall / lamp / panel / step / sig)
      const PY2 = SP_RM_PORCH_Y2, PD = SP_RM_PORCH_D;
      // --- the hall floor: pieces around the NOTCH (the W flight's upper half
      // climbs into the hall there), the S LANE (the hub's own S flight) and
      // THE PORCH (the stepped entrance). The SW landing is the lap's own brush.
      sbox(`${H} hall floor NW`, -OUT, -CORE, SP_RM_NOTCH_Y, OUT, ...slabZ(mid), K.floor);
      sbox(`${H} hall floor S strip`, -CORE, CORE, -CORE, -CORE + TREAD, ...slabZ(mid), K.floor);     // y[-256,-224]: tread 16's level
      sbox(`${H} hall floor core+N`, -CORE, CORE, PY2, OUT, ...slabZ(mid), K.floor);
      sbox(`${H} hall floor E`, CORE, OUT, -OUT, OUT, ...slabZ(mid), K.floor);
      sbox(`${H} hall floor SW strip`, -OUT, -CORE, -OUT, -PX, ...slabZ(mid), K.floor);
      // --- THE PORCH: a stepped FAN. Tread k (15..12) sits 12*(16-k) below
      // the hall; its row gets (16-k-1) slabs stepping up 12 each EASTWARD
      // until the hall floor takes over, so every adjacency in the fan —
      // east, west, north, south — is exactly one 12-high step: the flood
      // walks it in every direction, nothing inside it needs a guard, and the
      // hall meets the flight along all five treads (160 wide). Only the fan's
      // NORTH edge (over tread 11 and below) needs a wall, up from the lowest
      // slab. (The first cut walled the fan's EAST side; with the S flight's
      // inner wall now closing the corner too, the hall sealed itself off from
      // its own entrance — the lint found every hall detached.)
      for (let k = 1; k < SP_RM_PORCH_N; k++) {        // k = 1..4 <-> treads 15..12
        const y1 = -CORE + TREAD * k, y2 = -CORE + TREAD * (k + 1);
        for (let s = 1; s < k; s++)                     // this row's slabs below hall level
          sbox(`${H} porch row ${k} step ${s}`, -CORE + TREAD * (s - 1), -CORE + TREAD * s, y1, y2, ...slabZ(mid - RISE * (k - s)), K.floor);
        sbox(`${H} hall floor row ${k}`, -CORE + TREAD * (k - 1), CORE, y1, y2, ...slabZ(mid), K.floor);
        // THE FAN STEPS are the smallest walkable pieces on either tower —
        // 32-wide slabs 12 units apart, bridging the W flight up into the
        // hall floor. If anything here fragments into micro-regions it is
        // these, and a break at this joint severs the climb AT A HUB, which
        // is exactly where the user reports enemies standing still. Seed the
        // lowest slab of each row (s = 1); the rows above sit on the hall
        // floor, which the hall risers already vouch for.
        // CLAMPED TO THE LOWEST EXPOSED SURFACE. The row's westmost slabs are
        // emitted BELOW the core column's top (mid - SLAB) and inside its
        // x[-CORE,CORE] footprint, so they are buried solid: for k=3 and k=4 the
        // un-clamped seed landed INSIDE the core and cod2map would have dropped
        // it ("Could not drop node"). What is actually exposed at x=-240 in
        // those rows is the CORE TOP itself, which is the smallest walkable
        // fragment in the fan and the one most worth anchoring. Verified by
        // testing every emitted seed for containment in the axis-aligned world
        // brushes: 20 of 30 were solid before this clamp, 0 after.
        if (k >= 2) snav(`${H} porch row ${k}`, -CORE + TREAD * 0.5, (y1 + y2) / 2,
                         Math.max(mid - RISE * (k - 1), mid - SLAB) + 2);
      }
      const porchLow = mid - RISE * (SP_RM_PORCH_N - 2);   // the lowest slab (row 4, step 1): hall - 36
      sbox(`${H} porch wall N`, -CORE, -CORE + PD, PY2, PY2 + PARA, porchLow, mid + PARA_H, K.wall);
      sbox(`${H} porch cap N`, -CORE, -CORE + PD, PY2, PY2 + PARA, mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
      // the hall floor's edges over the W flight's slot north of the porch
      sbox(`${H} notch rail N`, -OUT, -CORE, SP_RM_NOTCH_Y, SP_RM_NOTCH_Y + PARA, mid, mid + PARA_H, K.wall);
      sbox(`${H} notch cap N`, -OUT, -CORE, SP_RM_NOTCH_Y, SP_RM_NOTCH_Y + PARA, mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
      sbox(`${H} notch rail E`, -CORE, -(CORE - PARA), PY2 + PARA, SP_RM_NOTCH_Y + PARA, mid, mid + PARA_H, K.wall);
      sbox(`${H} notch cap E`, -CORE, -(CORE - PARA), PY2 + PARA, SP_RM_NOTCH_Y + PARA, mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
      // --- THE HALL GATE: a slab across the porch's mouth (the x=-256 line),
      // from under the lowest porch step to SP_RM_GATE_H above hall level.
      // Hidden + NotSolid + ConnectPaths at init (crown_door_init), Shown +
      // Solid + DisconnectPaths for the trial (crown_door_close — the one
      // Show-after-Hide this map has proven live), hidden again on the win.
      ent(`spire hall gate ${lap + 1}`, [
        '{', `guid "${guid()}"`,
        kv('classname', 'script_brushmodel'),
        kv('targetname', `tod_spire_hall_gate${lap + 1}`),
        matBrush(SP_X - CORE - 10, SP_X - CORE + 10, SP_Y + SP_RM_GATE_Y1, SP_Y + PY2, porchLow - SLAB, mid + SP_RM_GATE_H, SP_MAT_LAND),
        // v19.71 (the perch pass): the gate was 128 tall with open hall above it - a wall-running
        // athlete could stand on it mid-trial or clear it and leave the sealed hall. A player-only
        // clip rides IN the gate entity (the lap doors' anti-vault rule: a barrier that must vanish
        // with the gate is a second brush of the gate, never a worldspawn brush), up to just under
        // the core's resumption over the hall. Bullets, zombies and grenades pass it.
        matBrush(SP_X - CORE - 10, SP_X - CORE + 10, SP_Y + SP_RM_GATE_Y1, SP_Y + PY2, mid + SP_RM_GATE_H, mid + SP_RM_VOID_H - 8, PERCH_MAT),
        '}',
      ]);
      // --- the drum: four walls outside the parapet line, PLAIN red like the
      // parapets they stand beside, floor slab to wallTop, a gold band outside
      sbox(`${H} drum W`, -WL, -OUT, -WL, WL, mid - SLAB, wallTop, SP_MAT_PARA);
      sbox(`${H} drum E`, OUT, WL, -WL, WL, mid - SLAB, wallTop, SP_MAT_PARA);
      sbox(`${H} drum S`, -OUT, OUT, -WL, -OUT, mid - SLAB, wallTop, SP_MAT_PARA);
      sbox(`${H} drum N`, -OUT, OUT, OUT, WL, mid - SLAB, wallTop, SP_MAT_PARA);
      const [bz1, bz2] = SP_RM_BAND;
      sbox(`${H} band W`, -WL - 8, -WL, -WL - 8, WL + 8, mid + bz1, mid + bz2, MAT.crownGold);
      sbox(`${H} band E`, WL, WL + 8, -WL - 8, WL + 8, mid + bz1, mid + bz2, MAT.crownGold);
      sbox(`${H} band S`, -WL, WL, -WL - 8, -WL, mid + bz1, mid + bz2, MAT.crownGold);
      sbox(`${H} band N`, -WL, WL, WL, WL + 8, mid + bz1, mid + bz2, MAT.crownGold);
      // --- the wall under the S flight's inner edge (the lane beneath a stair
      // is void): hall floor up to each tread's rail top, stepped with the
      // flight, FROM THE CORNER (v16.21: tread 1 was a second way in — and a
      // second way out of a sealed hall); the lane's east end closed under
      // the SE landing, its top flush under tread 16.
      for (let j = 1; j <= STEPS / PARA_EVERY; j++) {
        const top = mid + RISE * PARA_EVERY * j;
        const x1 = -CORE + TREAD * PARA_EVERY * (j - 1), x2 = -CORE + TREAD * PARA_EVERY * j;
        sbox(`${H} S flight inner wall ${j}`, x1, x2, -CORE, -(CORE - PARA), mid, top + PARA_H, K.wall);
        sbox(`${H} S flight inner cap ${j}`, x1, x2, -CORE, -(CORE - PARA), top + PARA_H, top + PARA_H + RAIL_CAP_H, MAT.clip);
      }
      sbox(`${H} S lane end wall`, CORE - PARA, CORE, -OUT, -CORE, mid, end - SLAB, K.wall);
      // v18.78 THE SE ALCOVE — x[CORE,OUT] y[-OUT,-CORE], roofed by this lap's SE
      // landing at end-SLAB: a three-walled room with one 180-wide mouth that was
      // also OUTSIDE trial_box (nothing rose, nothing landed, nobody counted).
      // 'seal' fills it solid to the landing's underside; 'open' keeps it as a
      // spawn closet with a riser inside (SP_RM_LAYOUTS asserts both).
      if (L.alcove === 'seal') sbox(`${H} alcove seal`, CORE, OUT, -OUT, -CORE, mid, end - SLAB, K.wall);
      // --- the next lap's galleries: inner rails on the E flight and the N
      // flight (the core used to be beside them). NO rail on the NE landing:
      // both of its inner sides are flight mouths (tread 1 of the N flight
      // spans x[224,256]) — a rail there stood ON that tread and severed the
      // climb. The last hub has the summit stair (the capital beside it) and
      // no N flight — nothing to rail.
      if (!last) {
        for (let j = 1; j <= STEPS / PARA_EVERY; j++) {
          const top = end + RISE * PARA_EVERY * j;
          const y1 = -CORE + TREAD * PARA_EVERY * (j - 1), y2 = -CORE + TREAD * PARA_EVERY * j;
          sbox(`${H} E gallery rail ${j}`, CORE - PARA, CORE, y1, y2, top - RISE * (PARA_EVERY - 1), top + PARA_H, K.wall);
          sbox(`${H} E gallery cap ${j}`, CORE - PARA, CORE, y1, y2, top + PARA_H, top + PARA_H + RAIL_CAP_H, MAT.clip);
        }
        for (let j = 1; j <= STEPS / PARA_EVERY; j++) {
          const top = TOP + RISE * PARA_EVERY * j;
          const x1 = CORE - TREAD * PARA_EVERY * j, x2 = CORE - TREAD * PARA_EVERY * (j - 1);
          sbox(`${H} N gallery rail ${j}`, x1, x2, CORE - PARA, CORE, top - RISE * (PARA_EVERY - 1), top + PARA_H, K.wall);
          sbox(`${H} N gallery cap ${j}`, x1, x2, CORE - PARA, CORE, top + PARA_H, top + PARA_H + RAIL_CAP_H, MAT.clip);
        }
      }
      // --- THIS HUB'S LAYOUT (SP_RM_LAYOUTS; v17.86 THE KIT): every shaft and
      // wall in the hall's colour (plain grid), plinths / caps / sills / beams
      // gold, lamps and panels the hall's filled glow, steps DECK.
      const capClip = (lab, bx, z1) => sbox(`${lab} cap`, bx[0], bx[1], bx[2], bx[3], mid + z1, mid + z1 + RAIL_CAP_H, MAT.clip);
      L.f.forEach((ft, fi) => {
        const F = `${H} ${L.name.toLowerCase()} ${ft[0]} ${fi + 1}`;
        if (ft[0] === 'pillar') {
          const [, px, py] = ft, P = 48;
          sbox(`${F} plinth`, px - P - 8, px + P + 8, py - P - 8, py + P + 8, mid, mid + 16, MAT.crownGold);
          sbox(`${F} shaft`, px - P, px + P, py - P, py + P, mid + 16, mid + 192 - 24, K.wall);
          sbox(`${F} cap`, px - P - 8, px + P + 8, py - P - 8, py + P + 8, mid + 192 - 24, mid + 192, MAT.crownGold);
        } else if (ft[0] === 'post') {
          const [, px, py] = ft, P = 24;
          sbox(`${F} base`, px - P - 6, px + P + 6, py - P - 6, py + P + 6, mid, mid + 12, MAT.crownGold);
          sbox(`${F} shaft`, px - P, px + P, py - P, py + P, mid + 12, mid + 240, K.wall);
          sbox(`${F} head`, px - P - 6, px + P + 6, py - P - 6, py + P + 6, mid + 240, mid + 264, MAT.crownGold);
        } else if (ft[0] === 'big') {
          const [, px, py, hs] = ft;
          sbox(`${F} plinth`, px - hs - 8, px + hs + 8, py - hs - 8, py + hs + 8, mid, mid + 16, MAT.crownGold);
          sbox(`${F} shaft`, px - hs, px + hs, py - hs, py + hs, mid + 16, mid + 240 - 24, K.wall);
          sbox(`${F} cap`, px - hs - 8, px + hs + 8, py - hs - 8, py + hs + 8, mid + 240 - 24, mid + 240, MAT.crownGold);
        } else if (ft[0] === 'wall') {
          const bx = rmFeatBox(ft);
          sbox(`${F}`, bx[0], bx[1], bx[2], bx[3], mid, mid + PARA_H, K.wall);
          capClip(F, bx, PARA_H);
        } else if (ft[0] === 'twall') {
          const bx = rmFeatBox(ft);
          sbox(`${F}`, bx[0], bx[1], bx[2], bx[3], mid, mid + SP_RM_TWALL_H, K.wall);
          capClip(F, bx, SP_RM_TWALL_H);
        } else if (ft[0] === 'fence') {
          // a gold sill the length of the line, 16-sq bars at 32 pitch (16
          // gaps: no body fits, bullets do), one clip cap over bars and gaps
          const bx = rmFeatBox(ft), [, x1, y1, x2, y2] = ft;
          sbox(`${F} sill`, bx[0], bx[1], bx[2], bx[3], mid, mid + 8, MAT.crownGold);
          const alongY = (x1 === x2), a1 = alongY ? Math.min(y1, y2) : Math.min(x1, x2), a2 = alongY ? Math.max(y1, y2) : Math.max(x1, x2);
          let n = 0;
          for (let a = a1; a <= a2; a += 32) {
            n++;
            if (alongY) sbox(`${F} bar ${n}`, x1 - 8, x1 + 8, a - 8, a + 8, mid + 8, mid + SP_RM_FENCE_H, K.wall);
            else        sbox(`${F} bar ${n}`, a - 8, a + 8, y1 - 8, y1 + 8, mid + 8, mid + SP_RM_FENCE_H, K.wall);
          }
          capClip(F, bx, SP_RM_FENCE_H);
        } else if (ft[0] === 'lamp') {
          const [, px, py] = ft, P = 12;
          sbox(`${F} foot`, px - P - 6, px + P + 6, py - P - 6, py + P + 6, mid, mid + 12, MAT.crownGold);
          sbox(`${F} shaft`, px - P, px + P, py - P, py + P, mid + 12, mid + 12 + SP_RM_LAMP_H, K.lamp);
          sbox(`${F} head`, px - P - 6, px + P + 6, py - P - 6, py + P + 6, mid + 12 + SP_RM_LAMP_H, mid + 36 + SP_RM_LAMP_H, MAT.crownGold);
        } else if (ft[0] === 'plat') {
          const [, x1, x2, y1, y2] = ft;
          sbox(`${F}`, x1, x2, y1, y2, mid, mid + 12, K.step);
        } else if (ft[0] === 'dais') {
          const [, px, py, tiers] = ft;
          for (let t = 1; t <= tiers; t++) {
            const h = 44 * (tiers - t + 1);
            sbox(`${F} tier ${t}`, px - h, px + h, py - h, py + h, mid + RISE * (t - 1), mid + RISE * t, (t % 2) ? K.step : K.floor);
          }
        } else if (ft[0] === 'throne') {
          // two tiers, then the seat: gold arms, a plain gold seat (BLOCK on
          // purpose — a DECK top 24 above the tier would be an unguarded edge
          // to the lint), a tall back in the wall colour with a gold cap
          const [, px, py] = ft;
          sbox(`${F} tier 1`, px - 88, px + 88, py - 88, py + 88, mid, mid + 12, K.sig);
          sbox(`${F} tier 2`, px - 44, px + 44, py - 44, py + 44, mid + 12, mid + 24, K.floor);
          sbox(`${F} seat`, px - 24, px + 24, py - 20, py + 20, mid + 24, mid + 48, MAT.crownGold);
          sbox(`${F} arm W`, px - 40, px - 24, py - 20, py + 20, mid + 24, mid + 72, MAT.crownGold);
          sbox(`${F} arm E`, px + 24, px + 40, py - 20, py + 20, mid + 24, mid + 72, MAT.crownGold);
          sbox(`${F} back`, px - 40, px + 40, py + 20, py + 44, mid + 24, mid + 168, K.wall);
          sbox(`${F} back cap`, px - 44, px + 44, py + 16, py + 48, mid + 168, mid + 184, MAT.crownGold);
        } else if (ft[0] === 'stage') {
          // v18.80: the skirt's tiers bottom-up, DECK tops alternating like the dais
          stageTiers(ft).forEach((t, ti) => sbox(`${F} tier ${ti + 1}`, t.box[0], t.box[1], t.box[2], t.box[3], mid + t.z1, mid + t.z2, ((ti + 1) % 2) ? K.step : K.floor));
        } else if (ft[0] === 'deck') {
          // v18.80: the top as one block, each stair as solid treads (12t high, the
          // highest against the deck), stepped side rails over every tread, and a
          // floor-to-(h + PARA_H) parapet on every 'rail' edge — all clip-capped
          const p = deckParts(ft), h = ft[5], n = h / 12;
          // a SLAB-thick DECK top over a wall-material body: lint_tod_geometry only reads a
          // top as floor when its brush is <= MAX_SLAB (64) thick — a 72 block is a wall to it
          const topped = (lab, b, hh, matTop) => {
            if (hh > SLAB) sbox(`${lab} body`, b[0], b[1], b[2], b[3], mid, mid + hh - SLAB, K.wall);
            sbox(lab, b[0], b[1], b[2], b[3], mid + Math.max(0, hh - SLAB), mid + hh, matTop);
          };
          topped(`${F} top`, p.top, h, K.step);
          p.stairs.forEach((st, si) => {
            deckTreads(st, n).forEach((tr, ti) => {
              topped(`${F} stair ${si + 1} tread ${ti + 1}`, tr.box, tr.h, ((ti + 1) % 2) ? K.step : K.floor);
              st.sideRails.forEach((sb, ri) => {
                // the rail piece beside this tread: the tread's span along the run, the side's thickness across it
                const along = (st.dir === 'N' || st.dir === 'S');
                const rb = along ? [sb[0], sb[1], tr.box[2], tr.box[3]] : [tr.box[0], tr.box[1], sb[2], sb[3]];
                sbox(`${F} stair ${si + 1} rail ${ri + 1} tread ${ti + 1}`, rb[0], rb[1], rb[2], rb[3], mid, mid + tr.h + PARA_H, K.wall);
                sbox(`${F} stair ${si + 1} rail ${ri + 1} tread ${ti + 1} cap`, rb[0], rb[1], rb[2], rb[3], mid + tr.h + PARA_H, mid + tr.h + PARA_H + RAIL_CAP_H, MAT.clip);
              });
            });
          });
          const edgeRails = p.rails.filter(r => !p.stairs.some(st => st.sideRails.includes(r)));
          edgeRails.forEach((r, ri) => {
            sbox(`${F} rail ${ri + 1}`, r[0], r[1], r[2], r[3], mid, mid + h + PARA_H, K.wall);
            sbox(`${F} rail ${ri + 1} cap`, r[0], r[1], r[2], r[3], mid + h + PARA_H, mid + h + PARA_H + RAIL_CAP_H, MAT.clip);
          });
        } else if (ft[0] === 'seat') {
          // v18.80: the throne's tier 2 + seat + arms + back, standing on a deck top
          const [, px, py, lift] = ft, z = mid + lift;
          sbox(`${F} tier`, px - 44, px + 44, py - 44, py + 44, z, z + 12, K.floor);
          sbox(`${F} seat`, px - 24, px + 24, py - 20, py + 20, z + 12, z + 36, MAT.crownGold);
          sbox(`${F} arm W`, px - 40, px - 24, py - 20, py + 20, z + 12, z + 60, MAT.crownGold);
          sbox(`${F} arm E`, px + 24, px + 40, py - 20, py + 20, z + 12, z + 60, MAT.crownGold);
          sbox(`${F} back`, px - 40, px + 40, py + 20, py + 44, z + 12, z + 156, K.wall);
          sbox(`${F} back cap`, px - 44, px + 44, py + 16, py + 48, z + 156, z + 172, MAT.crownGold);
        } else if (ft[0] === 'lintel') {
          // cap to cap (the pillar cap is 56 half): touching, never inside a cap
          const [, x1, y1, x2, y2] = ft;
          if (x1 === x2) sbox(`${F}`, x1 - 12, x1 + 12, Math.min(y1, y2) + 56, Math.max(y1, y2) - 56, mid + 168, mid + 192, MAT.crownGold);
          else           sbox(`${F}`, Math.min(x1, x2) + 56, Math.max(x1, x2) - 56, y1 - 12, y1 + 12, mid + 168, mid + 192, MAT.crownGold);
        } else if (ft[0] === 'panel') {
          const [, side, a1, a2, z1, z2, kind] = ft;
          if (kind === 'crest' && L.art) {
            // the crest image maps ONCE onto the plaque: texture size = the
            // face's extent, offsets cancel the world position (mod the size)
            const xs = a2 - a1, ys = z2 - z1;
            const wa = (side === 'N') ? SP_X + a1 : SP_Y + a1;
            const xo = ((-wa % xs) + xs) % xs, yo = ((-(mid + z1) % ys) + ys) % ys;
            if (side === 'N') addBoxTex(`spire ${F}`, SP_X + a1, SP_X + a2, SP_Y + OUT - SP_RM_LINER.t, SP_Y + OUT, mid + z1, mid + z2, L.art.crest, xs, ys, xo, yo);
            else              addBoxTex(`spire ${F}`, SP_X - OUT, SP_X - OUT + SP_RM_LINER.t, SP_Y + a1, SP_Y + a2, mid + z1, mid + z2, L.art.crest, xs, ys, xo, yo);
          } else if (side === 'N') sbox(`${F}`, a1, a2, OUT - SP_RM_LINER.t, OUT, mid + z1, mid + z2, K.panel);
          else                     sbox(`${F}`, -OUT, -OUT + SP_RM_LINER.t, a1, a2, mid + z1, mid + z2, K.panel);
        }
      });
      // --- THE LINER (v17.86): the drum's W / N / E inner faces wear a band of
      // the hall's colour, 8 proud, split round the PaP (W), the panels (N/W)
      // and the crate (E); the E band stops under the E gallery's first
      // parapet. Corners: the N band is inset by the liner thickness so the
      // three never share a cell. The S side is the S flight's stepped inner
      // wall and is left alone.
      {
        const LN = SP_RM_LINER;
        const cut = (a1, a2, holes) => {
          let spans = [[a1, a2]];
          for (const [h1, h2] of holes)
            spans = spans.flatMap(([s1, s2]) => (h2 <= s1 || h1 >= s2) ? [[s1, s2]] : [[s1, Math.min(s2, h1)], [Math.max(s1, h2), s2]].filter(([p, q]) => q > p));
          return spans.filter(([p, q]) => q - p >= 16);
        };
        const panels = side => L.f.filter(ft => ft[0] === 'panel' && ft[1] === side).map(ft => [ft[2], ft[3]]);
        // v18.78: the vendors are per layout (L.furn) — a hole of +-80 round each on its own wall
        const vend = side => [L.furn.pap, L.furn.crate].filter(v => v.side === side).map(v => { const a = (side === 'N' || side === 'S') ? v.org[0] : v.org[1]; return [a - 80, a + 80]; });
        const LM = (L.art && L.art.liner) || K.wall;   // v17.88: the hall's seamless wall tile
        cut(SP_RM_NOTCH_Y + PARA, OUT - LN.t, [...vend('W'), ...panels('W')]).forEach(([a1, a2], i) =>
          sbox(`${H} liner W ${i + 1}`, -OUT, -OUT + LN.t, a1, a2, mid + LN.z1, mid + LN.z2, LM));
        cut(-OUT + LN.t, OUT - LN.t, [...vend('N'), ...panels('N')]).forEach(([a1, a2], i) =>
          sbox(`${H} liner N ${i + 1}`, a1, a2, OUT - LN.t, OUT, mid + LN.z1, mid + LN.z2, LM));
        // under a plaque that starts above the band's foot, the band continues below it
        L.f.filter(ft => ft[0] === 'panel' && ft[1] === 'N' && ft[4] > LN.z1 + 16).forEach((ft, i) =>
          sbox(`${H} liner N under plaque ${i + 1}`, ft[2], ft[3], OUT - LN.t, OUT, mid + LN.z1, mid + ft[4], LM));
        cut(-OUT, OUT - LN.t, vend('E')).forEach(([a1, a2], i) =>
          sbox(`${H} liner E ${i + 1}`, OUT - LN.t, OUT, a1, a2, mid + LN.z1, mid + LN.ez2, LM));
      }
      // the trial mark (the win's Max Ammo lands here) — a 1u-proud red seam
      // on the floor, or on a plat's top; skipped when the layout puts the
      // mark on a dais / throne (the inlay would be buried inside tier 1 —
      // the hidden-face audit found exactly that)
      {
        const on = rmFeatUnder(L, L.mark);
        const mz = (!on) ? mid : (on[0] === 'plat') ? mid + 12 : (on[0] === 'deck' || on[0] === 'stage') ? mid + rmLift(L, L.mark) : null;   // v18.80: on a deck / stage top
        if (mz !== null) {
          if (L.art) {
            const x1 = SP_X + L.mark[0] - 48, y1 = SP_Y + L.mark[1] - 48;
            addBoxTex(`spire ${H} trial mark`, x1, x1 + 96, y1, y1 + 96, mz, mz + 1, L.art.seal, 96, 96, ((-x1 % 96) + 96) % 96, ((-y1 % 96) + 96) % 96);
          } else sbox(`${H} trial mark`, L.mark[0] - 48, L.mark[0] + 48, L.mark[1] - 48, L.mark[1] + 48, mz, mz + 1, SP_MAT_LAND);
        }
      }
      // v17.69 THE SIGIL — the hall's emblem, 1u proud in the hall's colour
      // (asserted clear of everything at SP_RM_LAYOUTS)
      (L.sig || []).forEach((bx, si) =>
        sbox(`${H} ${L.name.toLowerCase()} sigil ${si + 1}`, bx[0], bx[1], bx[2], bx[3], mid, mid + 1, K.sig));
      // --- the hub crate's body clip (the label the lint's MODEL_CLIP_COLUMNS matches)
      const [ccx, ccy] = L.furn.crate.org;   // v18.78: per layout
      const cb = crateBox(SP_X + ccx, SP_Y + ccy, L.furn.crate.yaw);
      addBox(`spire hub lap${lap + 1} ammo crate body`, cb.x1, cb.x2, cb.y1, cb.y2, mid, mid + CRATE_BOX_H, MAT.clip);
      crateCap(`spire hub lap${lap + 1} ammo crate`, cb, mid, L.furn.crate.yaw);
      // v19.71: the hub PaP's cap (its collision is script-spawned at ascension)
      vendorCap(`spire hub lap${lap + 1} pap`, [SP_X + L.furn.pap.org[0], SP_Y + L.furn.pap.org[1]], mid, SIDE_BACK[L.furn.pap.side], VENDOR_PAP);
    }
  }

  // --- 6d. the summit (crown-stair pattern: gold flight -> apron + plaza) ---
  for (let i = 1; i <= STEPS; i++)
    sbox(`summit step ${i}`, CORE, PX, -CORE + TREAD * (i - 1), -CORE + TREAD * i, ...slabZ(SP_TOP + RISE * i), MAT.crownStep);
  if (STAIR_RAMP_CLIP)
    rampWedgeY('spire summit stair ramp', SP_X + CORE, SP_X + PX, SP_Y - CORE - TREAD, SP_Y + CORE - TREAD, SP_TOP, SP_TOP + FLIGHT_RISE, MAT.rampClip);
  for (let j = 1; j <= STEPS / PARA_EVERY; j++) {
    const top = SP_TOP + RISE * PARA_EVERY * j;
    sbox(`summit stair rail ${j}`, PX, PX + PARA, -CORE + TREAD * PARA_EVERY * (j - 1), -CORE + TREAD * PARA_EVERY * j, top - RISE * (PARA_EVERY - 1), top + PARA_H, MAT.crownGold);
  }
  sbox('summit stair cap', PX, PX + PARA, -CORE, CORE, SP_TOP + PARA_H, SP_TOP + FLIGHT_RISE + PARA_H + RAIL_CAP_H, MAT.clip);
  // THE PLAZA DECK — a real floor slab over the capital. The capital is `pap`,
  // which the lint (and the design language) classes as BLOCK: nothing stands
  // on bare capital anywhere else in the map, so the summit lays a gold-grid
  // deck on top. It tops out 16 above the apron/stair arrival — one step.
  // v17.70 THE ARENA DECK — one level (SP_TOP2..+SLAB) in four pieces around
  // the stair well; the piece north of the well keeps the 'summit apron' label
  // the geometry lint's spire proof reads (spireReachesSummit).
  const SMH = SP_SM_HALF;
  // THE DECK IS CUT ROUND EVERY PILLAR FOOTPRINT (build 4). A deck slab that
  // runs under a pillar leaves its top face there, and cod2map surfaces it as
  // a walkable navmesh face with the shaft standing on it — four single-face
  // ISLANDS (one per pillar) that failed the gate three builds running (a
  // proud plinth, a flush plinth and no plinth all produced them). The hall
  // pillars do not show this only because the hall floor is already several
  // brushes whose seams happen to miss the footprints. So: the deck pieces
  // are split round each pillar's 96-square hole and the shaft fills the hole
  // from the deck's UNDERSIDE (SP_TOP2), flush with the deck's cut edges.
  const holes = SP_SM_PILLARS.map(([px, py]) => [px - 48, px + 48, py - 48, py + 48]);
  const deckPiece = (label, x1, x2, y1, y2) => {
    let rects = [[x1, x2, y1, y2]];
    for (const [hx1, hx2, hy1, hy2] of holes) {
      const next = [];
      for (const [a1, a2, b1, b2] of rects) {
        if (hx1 >= a2 || hx2 <= a1 || hy1 >= b2 || hy2 <= b1) { next.push([a1, a2, b1, b2]); continue; }   // no overlap
        // up to four rects round the hole; a side the hole already reaches is skipped
        const mx1 = Math.max(a1, hx1), mx2 = Math.min(a2, hx2);
        if (hx1 > a1) next.push([a1, hx1, b1, b2]);
        if (hx2 < a2) next.push([hx2, a2, b1, b2]);
        if (hy1 > b1) next.push([mx1, mx2, b1, hy1]);
        if (hy2 < b2) next.push([mx1, mx2, hy2, b2]);
      }
      rects = next;
    }
    // the FIRST rect keeps the bare label: the geometry lint's spire proof reads
    // the node 'spire summit apron' by exact name (spireReachesSummit)
    rects.forEach(([a1, a2, b1, b2], i) => sbox(i === 0 ? label : `${label} ${i + 1}`, a1, a2, b1, b2, SP_TOP2, SP_TOP2 + SLAB, SP_MAT_HUBF));
  };
  deckPiece('summit plaza deck', -SMH, CORE, -SMH, SMH);              // west of the well (incl. the core plaza)
  deckPiece('summit apron', CORE, SMH, CORE, SMH);                    // north of the well — the stair's arrival
  deckPiece('summit deck SE', CORE, SMH, -SMH, -CORE);                // south of the well (roofs the SE landing, 208 headroom)
  sbox('summit deck E strip', PX + PARA, SMH, -CORE, CORE, SP_TOP2, SP_TOP2 + SLAB, SP_MAT_HUBF);       // east of the stair's own rail (no pillar there)
  // the well's east side: the deck stands up to 208 above the low treads
  sbox('summit well rail E', PX + PARA, PX + PARA * 2, -CORE, CORE, SP_TOP2 + SLAB, SP_TOP2 + SLAB + PARA_H, MAT.crownGold);
  sbox('summit well cap E', PX + PARA, PX + PARA * 2, -CORE, CORE, SP_TOP2 + SLAB + PARA_H, SP_TOP2 + SLAB + PARA_H + RAIL_CAP_H, MAT.clip);
  // the well's south side: over tread 1 (a 196 drop onto walkable stair)
  // v19.76 — ONE PARA LONGER AT EACH END (lead tester Nikolai, Oct 2026: "You can
  // also jump up these two corner wall spots since the walls don't extend to
  // complete ... you can wedge yourself on both edge surfaces"). This rail ran
  // x[CORE, PX+PARA] and stopped short of BOTH rails it meets: the rim rail stands
  // at x[CORE-PARA, CORE] and the well's east rail at x[PX+PARA, PX+2*PARA], each
  // ending at y = -CORE, so each corner was a 20x20 column with no rail and no cap
  // between two capped rails - an inside corner a player wedges into and climbs
  // (onto the caps, then the gate). It now spans x[CORE-PARA, PX+2*PARA] and both
  // corners are solid; the perch seal pass caps the new length with the rest.
  sbox('summit well rail S', CORE - PARA, PX + PARA * 2, -CORE - PARA, -CORE, SP_TOP2 + SLAB, SP_TOP2 + SLAB + PARA_H, MAT.crownGold);
  sbox('summit well cap S', CORE - PARA, PX + PARA * 2, -CORE - PARA, -CORE, SP_TOP2 + SLAB + PARA_H, SP_TOP2 + SLAB + PARA_H + RAIL_CAP_H, MAT.clip);
  // perimeter rails, every run capped
  for (const [lbl, x1, x2, y1, y2] of [
    ['N', -SMH - PARA, SMH + PARA, SMH, SMH + PARA],
    ['S', -SMH - PARA, SMH + PARA, -SMH - PARA, -SMH],
    ['W', -SMH - PARA, -SMH, -SMH, SMH],
    ['E', SMH, SMH + PARA, -SMH, SMH],
  ]) {
    sbox(`summit arena rail ${lbl}`, x1, x2, y1, y2, SP_TOP2 + SLAB, SP_TOP2 + SLAB + PARA_H, MAT.crownGold);
    sbox(`summit arena cap ${lbl}`, x1, x2, y1, y2, SP_TOP2 + SLAB + PARA_H, SP_TOP2 + SLAB + PARA_H + RAIL_CAP_H, MAT.clip);
  }
  // under-glow band on the deck's edge (the summit is seen from the whole climb)
  for (const [lbl, x1, x2, y1, y2] of [
    ['N', -SMH, SMH, SMH - 8, SMH], ['S', -SMH, SMH, -SMH, -SMH + 8], ['W', -SMH, -SMH + 8, -SMH, SMH], ['E', SMH - 8, SMH, -SMH, SMH],
  ]) sbox(`summit deck edge ${lbl}`, x1, x2, y1, y2, SP_TOP2 - 24, SP_TOP2, MAT.crownGold);
  // four cover pillars (the hall's pillar recipe)
  SP_SM_PILLARS.forEach(([px, py], i) => {
    const P = 48, z = SP_TOP2 + SLAB;
    // FLUSH plinth (v17.70 build 2): the hall recipe's 8u-proud plinth left a
    // 16-high, 8-wide walkable ring round each shaft — four single-face navmesh
    // ISLANDS at (+-520,+-520) z+16 that failed the gate. No rim, no ring.
    // (build 3: NO plinth brush at all — a flush plinth's top face, coincident
    // with the shaft's bottom, still surfaced as a walkable navmesh face at z+16
    // under the shaft, the same four islands. One shaft brush from the deck.)
    sbox(`summit pillar ${i + 1} shaft`, px - P, px + P, py - P, py + P, SP_TOP2, z + 192 - 24, SP_MAT_PARA);   // from the deck's UNDERSIDE: it fills the hole cut for it
    sbox(`summit pillar ${i + 1} cap`, px - P - 8, px + P + 8, py - P - 8, py + P + 8, z + 192 - 24, z + 192, MAT.crownGold);
  });
  // the 1000-point crate's body (the ONE crate contract: crateBox at its real yaw)
  {
    if (SP_SM_CRATE.yaw !== CRATE_YAW_E) throw new Error("summit crate yaw is not CRATE_YAW_E");
    const cb = crateBox(SP_X + SP_SM_CRATE.org[0], SP_Y + SP_SM_CRATE.org[1], SP_SM_CRATE.yaw);
    addBox('spire summit ammo crate body', cb.x1, cb.x2, cb.y1, cb.y2, SP_TOP2 + SLAB, SP_TOP2 + SLAB + CRATE_BOX_H, MAT.clip);
    crateCap('spire summit ammo crate', cb, SP_TOP2 + SLAB, SP_SM_CRATE.yaw);
    // the BUY footprint (2026-09-24, crateBuySpot): a buyer must not stand on a
    // riser or inside a pillar; the wider prompt circle may reach past either.
    const ct = crateBuySpot(SP_SM_CRATE.org, SP_SM_CRATE.yaw);
    for (const [rx, ry] of SP_SM_RISERS) if (Math.hypot(rx - ct[0], ry - ct[1]) < CRATE_BUY_CLEAR + 40) throw new Error('summit crate trigger on a riser');
    for (const [px, py] of SP_SM_PILLARS) if (Math.abs(px - ct[0]) < 56 + CRATE_BUY_CLEAR && Math.abs(py - ct[1]) < 56 + CRATE_BUY_CLEAR) throw new Error('summit crate trigger inside a pillar');
  }
  // the king's mark (the win's Max Ammo lands here) — 1u proud, red
  sbox('summit king mark', SP_SM_MARK[0] - 48, SP_SM_MARK[0] + 48, SP_SM_MARK[1] - 48, SP_SM_MARK[1] + 48, SP_TOP2 + SLAB, SP_TOP2 + SLAB + 1, SP_MAT_LAND);
  // THE SUMMIT GATE — across the stair's mouth (the y = SP_SM_GATE_Y line,
  // x over the treads and their rail), from under the arrival to 256 above
  // the deck (no vault). The hall-gate contract: hidden at init, Show + Solid +
  // DisconnectPaths for the fight - and since v19.76 it STAYS shut after the
  // King (_tod_spire::king_win; the summit is the end of the road).
  // v19.76: the gate's player-clip top = the rail caps' perch-seal top beside it
  // (perchSeal raises each cap REACH_V + 8 above itself; the caps top out at
  // SP_TOP2 + SLAB + PARA_H + RAIL_CAP_H).
  const SP_SM_GATE_CLIP_TOP = SP_TOP2 + SLAB + PARA_H + RAIL_CAP_H + PERCH.DEFAULTS.REACH_V + 8;
  if (SP_SM_GATE_CLIP_TOP <= SP_TOP2 + SLAB + 256) throw new Error('summit gate clip would sit below the gate top');
  ent('spire summit gate', [
    '{', `guid "${guid()}"`,
    kv('classname', 'script_brushmodel'),
    kv('targetname', 'tod_spire_summit_gate'),
    matBrush(SP_X + CORE, SP_X + PX + PARA, SP_Y + SP_SM_GATE_Y - 10, SP_Y + SP_SM_GATE_Y + 10, SP_TOP2 - SLAB, SP_TOP2 + SLAB + 256, SP_MAT_LAND),
    // v19.76 (lead tester Nikolai, Oct 2026, a screenshot from ON TOP of it: "You
    // also can glitch jump onto it"). The perch model reads worldspawn only, so the
    // 256-tall gate's 20-wide top was never in it - and the rail caps beside it are
    // sealed to SP_SM_GATE_CLIP_TOP, so a player who wedged up a corner dropped onto
    // it. A player-only clip rides IN the gate entity (the hall gates' v19.71 rule:
    // a barrier that must vanish with the gate is a second brush of the gate), from
    // its top to the seals' own height: nothing level with or above the gate is left
    // to stand on. Bullets, zombies and grenades pass it.
    matBrush(SP_X + CORE, SP_X + PX + PARA, SP_Y + SP_SM_GATE_Y - 10, SP_Y + SP_SM_GATE_Y + 10, SP_TOP2 + SLAB + 256, SP_SM_GATE_CLIP_TOP, PERCH_MAT),
    '}',
  ]);
  // CAPITAL RIM RAIL — between the plaza deck and the summit stair's top
  // treads (the stair rises flush along the plaza's east edge; without this,
  // treads 13-16 sit above the capital's guard reach — first lint run). The
  // rail base is sunk 32 into the capital so it guards the top treads too.
  // It stopped at y=224 "so the arrival strip (y 224..256) stays open" - and that
  // opening was the SLOT beside the gate: from y 224 to the gate's south face at
  // SP_SM_GATE_Y - 10 the plaza deck met the top tread with nothing between, so with
  // the gate shut the stair still showed through a 28-wide gap on its west side
  // (lead tester Nikolai, Oct 2026: "there is a large hole to the right of door as
  // if you can run through ... Might want to extend that wall a little bit").
  // v19.76: the rail runs on to the gate's NORTH face, so the shut gate and this rail
  // close the stair's whole mouth. The arrival strip still opens NORTH (through the
  // gate's footprint while it is hidden) onto the apron, which joins the plaza.
  sbox('summit rim rail', CORE - PARA, CORE, -CORE, SP_SM_GATE_Y + 10, SP_TOP2 - 32, SP_TOP2 + SLAB + PARA_H, MAT.crownGold);
  sbox('summit rim cap', CORE - PARA, CORE, -CORE, SP_SM_GATE_Y + 10, SP_TOP2 + SLAB + PARA_H, SP_TOP2 + SLAB + PARA_H + RAIL_CAP_H, MAT.clip);
  // THE STAIR MOUTH IS CLOSED BY CONSTRUCTION (v19.76) - asserted, so a later edit to
  // any of these four numbers cannot quietly reopen either hole.
  if (SP_SM_GATE_Y + 10 > 256 + 20 || SP_SM_GATE_Y - 10 < 224)
    throw new Error('summit gate no longer sits across the stair top (y 224..256): the rim rail extension was sized to it');
  // Seeds across the deck so every piece is its own seeded origin (the old
  // apron's three seeds, widened to the arena).
  for (const [ax, ay] of [[-500, 500], [0, 500], [500, 500], [-500, 0], [-500, -500], [0, -500], [500, -500], [600, 0]]) snav(`summit deck ${ax} ${ay}`, ax, ay, SP_TOP2 + SLAB + 2);
  // (v17.70: the old apron and its rails, and the plaza's W/S rails, are gone —
  // the arena deck above replaced them; the summit rim rail stays: it guards
  // the west piece's edge over the top treads, where the stair rises flush.)
  // beacon mast + the ruby head — the red star the whole map wonders about
  sbox('summit mast t1', -48, 48, -48, 48, SP_TOP2 + SLAB, SP_TOP2 + 192, MAT.crownGold);
  sbox('summit mast t2', -32, 32, -32, 32, SP_TOP2 + 192, SP_TOP2 + 352, MAT.crownGold);
  sbox('summit mast t3', -16, 16, -16, 16, SP_TOP2 + 352, SP_TOP2 + SP_BEACON_H - 48, MAT.crownGold);
  // PLAIN red, not jewelRuby: a 48-thick _tinted_edge box is a walkable DECK
  // slab to the lint — a floating unguarded "floor" 500 over the deck (the
  // crown-moulding rule). The beacon's glow is the light + aura, not the box.
  sbox('summit mast head', -24, 24, -24, 24, SP_TOP2 + SP_BEACON_H - 48, SP_TOP2 + SP_BEACON_H, SP_MAT_PARA);
  sbox('summit exfil mark', -80, 80, -230, -70, SP_TOP2 + SLAB, SP_TOP2 + SLAB + 1, MAT.exfilPad);

  // --- 6e. doors: slab + anti-bypass clip, NO map trigger -------------------
  // _tod_doors replaces every map trigger with its own script-spawned
  // trigger_radius_use anyway, so the spire emits none: its door triggers are
  // spawned LAZILY by _tod_spire.gsc in the climb window (the ~1024-slot
  // gentity table is the budget everything here answers to — docs/44 §4).
  // v14.23 — 50 DOORS, ONE PER LAP-PAIR, ALL RESIDENT (user 2026-08-30:
  // "What about changing the spire to 50 doors?" after the live test proved
  // the v14.1 parity MOVER never re-seated — doors 3+ never existed, the
  // party climbed free, the un-set door flags left every zone past c1
  // DISABLED and stock's out-of-playable monitor instakilled the climbers.
  // The mover used two mechanisms this map had never proven live (.origin
  // assignment on a brushmodel + Show() after Hide()); 50 resident slabs
  // need NEITHER — they use the tower's 53-door contract verbatim: Solid
  // from load, Hide+NotSolid+ConnectPaths ONCE on buy, never moved, never
  // re-shown. Door d sits at ODD floor 2d-1 (every door on the E face — all
  // odd flights start E) and opens floors 2d-1 and 2d; even floors have no
  // doorway barrier at all, by design.
  // ENTITY BUDGET: +48 residents vs v14.1's 2. The v14.0 crash config was
  // +100 and only the LAST few init spawns failed (the crown altar trigger),
  // so the overshoot was small; _tod_spire's tod_dev headroom probe MEASURES
  // the live margin at boot — read it on the next dev run, and the crown
  // altar's trigger is the canary if it ever regresses.
  // v14.36 — ONE DOOR PER FLOOR, TOWER-MATCHED (user 2026-08-30: "each door is
  // 4 set of stairs between each where the normal tower is 2... I want the
  // endless spire to match that 2 set of stairs per door"). This restores the
  // ORIGINAL v14.0 shape: 100 doors, alternating faces by parity exactly like
  // the tower's own DOORS table (odd floor -> E face at y=-256, even floor ->
  // W face at y=+256), because odd flights climb E+N and even flights W+S.
  // v14.23's 50 doors were all on the E face precisely BECAUSE they only ever
  // sealed odd floors; per-floor doors must alternate or every even door hangs
  // on the wrong side of the core.
  //
  // ENTITY BUDGET — the fear here is v14.0's untriggerable crown altar, and it
  // is worth writing down that the diagnosis was NEVER ISOLATED: v14.1 shipped
  // the slab cut (100->2) AND the station_place reordering (trigger manager
  // launches first instead of behind four unguarded Spawns) in ONE release for
  // ONE symptom. Either could have been the fix. Measured 2026-08-30: the .map
  // contributes 166 runtime-gentity entities at 50 doors, 216 at 100, against
  // a ~1024 table — a small delta that makes the pressure story look weak.
  // The dev headroom probe in _tod_spire::init and the crown altar's own buy
  // trigger are the empirical check; if the altar ever loses its prompt again,
  // THIS is the first thing to halve.
  const SPIRE_DOORS = [];
  for (let n = 1; n <= SP_LAPS; n++) {
    const b = (n - 1) * LAP_RISE;
    // v16.19: a HUB door's anti-vault clip stops at the hall floor slab — the
    // hall's NW region is directly above it, and the old 600-tall clip would
    // be an invisible wall across that floor (the lint's misplaced-wall class).
    const clipTop = (n % SP_HUB_EVERY === 0) ? b + FLIGHT_RISE - SLAB : Math.min(b + 600, SP_TOP2 - SLAB);
    if (n % 2 === 1) {
      SPIRE_DOORS.push({ n, floor: n, slab: { x1: CORE, x2: PX, y1: -266, y2: -246, z1: b, z2: b + 128 }, clip: { x1: CORE, x2: PX + PARA, y1: -266, y2: -246, z1: b + 128, z2: clipTop } });
    } else {
      SPIRE_DOORS.push({ n, floor: n, slab: { x1: -PX, x2: -CORE, y1: 246, y2: 266, z1: b, z2: b + 128 }, clip: { x1: -PX - PARA, x2: -CORE, y1: 246, y2: 266, z1: b + 128, z2: clipTop } });
    }
  }
  // ALL 50 SLABS RESIDENT — the tower's own door contract, no movers, no
  // lintels. (The v14.20 lintel experiment is REMOVED: the user's live
  // verdict was "weird headboards above all the spots where there should be
  // doors" — with a real slab in every doorway there is nothing left for a
  // header band to explain. Do not re-add decorative frames without doors.)
  // script_vector/script_transition_time are NOT emitted — the v14.1 movers
  // carried them and nothing ever read them; a slab that never moves needs
  // neither.
  for (const d of SPIRE_DOORS) {
    ent(`spire door slab ${d.n} (floor ${d.floor})`, [
      '{', `guid "${guid()}"`,
      kv('classname', 'script_brushmodel'),
      kv('targetname', `tod_spire_door${d.n}`),
      matBrush(SP_X + d.slab.x1, SP_X + d.slab.x2, SP_Y + d.slab.y1, SP_Y + d.slab.y2, d.slab.z1, d.slab.z2, MAT.door),
      // v16.13: the anti-vault clip rides IN the slab entity, exactly as on the
      // tower's doors (see that block) — a worldspawn clip outlived the door
      // and was the "invisible wall above the door" players hit jumping down
      // the flight. _tod_spire opens with Hide/NotSolid/ConnectPaths on the
      // entity, so the clip leaves with the slab. No script change.
      matBrush(SP_X + d.clip.x1, SP_X + d.clip.x2, SP_Y + d.clip.y1, SP_Y + d.clip.y2, d.clip.z1, d.clip.z2, MAT.clip),
      '}',
    ]);
  }

  // v19.69 THE SURFACE REFRESH - the spire's floor numbers, 1..SP_LAPS, on its
  // door landings (the tower's spots: its doors alternate faces exactly like the
  // tower's DOORS table), in the spire's own hotter red. The hub halls' door
  // landings (floors 11, 21 ...) are the SE landings inside each drum.
  if (RF_FLOORNUMS) {
    // v19.68t: on the wall left of each door (see floorNumberWall); the floor after each hub
    // (11, 21 ... 61) has no core at that height - its sign rides the hub S flight's inner wall
    for (let n = 1; n <= SP_LAPS; n++)
      floorNumberWallAt(`spire floor number ${n}`, n, SP_X, SP_Y, 'tod_rf_floornum_spire',
                        (n > 1 && (n - 1) % SP_HUB_EVERY === 0) ? 'hubexit' : 'spire');
  }

  // --- 6f. zones + risers + respawn groups ----------------------------------
  // One square volume per 5-floor chunk (it may cover the solid core — no
  // walkable point is lost, and 1 brush beats 4 rings). Risers live ONLY on
  // landings — the road's rule: a riser on a stair hangs in mid-air or buries
  // itself under a crest. Riser gating above the highest bought door is a
  // SCRIPT filter (_tod_spire, the finale gate-filter pattern), because a
  // 5-floor zone wakes all its risers at its first door.
  const SP_ZONES = [];
  SP_ZONES.push({
    name: 'spire_base_zone',
    brushes: [svol(-(ARENA + WALL), ARENA + WALL, -(ARENA + WALL), ARENA + WALL, -SLAB, 368)],
    // v19.68s: the NW corner holds the rocket wreck (RK_CORNER) - its riser moves out along the north walkway
    risers: [[-470, -470, 0], [336, -336, 0], (RK_CORNER ? [-200, 488, 0] : [-470, 470, 0]), [470, 470, 0]],
    dog: [0, -470, 0],
  });
  for (let k = 1; k <= SP_LAPS / SP_ZONE_CHUNK; k++) {
    const f1 = (k - 1) * SP_ZONE_CHUNK + 1, f2 = k * SP_ZONE_CHUNK;
    const brushes = [svol(-600, 600, -600, 600, (f1 - 1) * LAP_RISE - SLAB, f2 * LAP_RISE + 200)];
    const risers = [];
    let dog;
    for (let f = f1; f <= f2; f++) {
      const b = (f - 1) * LAP_RISE, mid = b + FLIGHT_RISE, end = b + LAP_RISE;
      const fodd = (f % 2 === 1);
      risers.push(fodd ? [336, 336, mid] : [-336, -336, mid]);
      risers.push(fodd ? [-336, 336, end] : [336, -336, end]);
      if (!dog) dog = fodd ? [336, 336, mid] : [-336, -336, mid];
      if (f % SP_HUB_EVERY === 0) {
        // v16.19: the hub hall's risers — the only risers a trial keeps live.
        // The hall sits inside the chunk's own 600-square volume (the drum
        // reaches 456), so no extra volume brush. v18.78: PER LAYOUT — every
        // pocket a hall has gets a riser inside it (SP_RM_LAYOUTS).
        // v18.80: a riser on a deck / stage TOP rides on it (rmLift) — the horde rises up there too
        { const HL = SP_RM_LAYOUTS[SP_HUBS.indexOf(f)]; for (const [rx, ry] of HL.risers) risers.push([rx, ry, mid + rmLift(HL, [rx, ry])]); }
      }
    }
    SP_ZONES.push({ name: `spire_c${k}_zone`, brushes, risers, dog });
  }
  SP_ZONES.push({
    name: 'spire_summit_zone',
    brushes: [svol(-SP_SM_HALF - 60, SP_SM_HALF + 60, -SP_SM_HALF - 60, SP_SM_HALF + 60, SP_TOP2 - SLAB - 8, SP_TOP2 + 400)],   // v17.70: the arena (starts at the deck — the hub's chunk owns the drum below)
    risers: SP_SM_RISERS.map(([rx, ry]) => [rx, ry, SP_TOP2 + SLAB]),
    dog: [0, 500, SP_TOP2 + SLAB],
  });
  for (const zn of SP_ZONES) {
    ent(`${zn.name} info_volume`, [
      '{', `guid "${guid()}"`,
      kv('classname', 'info_volume'),
      kv('script_noteworthy', 'player_volume'),
      kv('target', `${zn.name}_spawners`),
      kv('targetname', zn.name),
      ...zn.brushes,
      '}',
    ]);
    zn.risers.forEach(([sx, sy, sz], i) => {
      ent(`${zn.name} riser ${i + 1}`, [
        '{', `guid "${guid()}"`,
        kv('classname', 'script_struct'),
        kv('angles', '0 270 0'),
        kv('origin', `${SP_X + sx} ${SP_Y + sy} ${sz}`),
        kv('script_noteworthy', 'riser_location'),
        kv('script_string', 'find_flesh'),
        kv('targetname', `${zn.name}_spawners`),
        kv('_color', '1 0 0'), '}',
      ]);
    });
    ent(`${zn.name} dog location`, [
      '{', `guid "${guid()}"`,
      kv('classname', 'script_struct'),
      kv('origin', `${SP_X + zn.dog[0]} ${SP_Y + zn.dog[1]} ${zn.dog[2]}`),
      kv('script_noteworthy', 'dog_location'),
      kv('targetname', `${zn.name}_spawners`),
      kv('_color', '1 0 0'), '}',
    ]);
    // NAVMESH SEED (2026-08-30, "spire zombies never target anyone" — the
    // symptom recorded at _tod_spire.gsc's dev_target_probe since the first
    // live test). This map's only two seed-class entities — the factory
    // spawner and info_player_start — stand at the OLD tower's base, and the
    // spire is a detached island by design, so it compiled with ZERO navmesh:
    // every zombie risen here was off-mesh — no pathing, no find_flesh, no
    // melee. Everything the spire places is on the exclusion list
    // (script_struct, info_volume, script_brushmodel, light), so nothing
    // seeded it by accident.
    //
    // ⚠️ THE v14.19 MODEL WAS WRONG AND THIS BLOCK IS WHERE IT WAS WRITTEN
    // DOWN. It said "the navmesh FLOOD-GROWS from seeds, so a detached island
    // needs one seed" and therefore took `zn.risers[0]` — ONE node per 5-floor
    // chunk, 22 for 100 floors. cod2map64 is HAVOK AI
    // (NavMesh\hkaiNavMeshPruningUtils.cpp), and it does not flood: it meshes
    // the world, splits it into CONNECTED REGIONS, and keeps each region only
    // if its AREA clears a threshold **OR** a seed point sits on it. The
    // compiler's own fallback line is the proof, and the conjunction is the
    // whole story: "All regions are below the area threshold AND too far from
    // a seed point. Keeping the largest region."
    // (bin\default_navmesh_settings.json: pruning.minDistanceToSeedPoints 14 —
    // that is the tolerance for a seed counting as sitting ON a region, NOT a
    // coverage radius. One seed vouches for its whole connected component.)
    //
    // So a region CONNECTED to a seeded one can still be pruned, and "one seed
    // floods the island" was never true. Proven twice on this map:
    //   * 2026-09-03, the TOWER — one continuous staircase from the base, two
    //     base seeds, and everything above ~floor 18 had no mesh. Fixed by
    //     seeding EVERY riser (the block at the tower's ZONES loop).
    //   * 2026-09-03, hours later, the SPIRE — the tower fix shipped and the
    //     user hit the identical symptom on the spire, because THIS site was
    //     left on per-zone seeding: 22 seeds at 1,920-unit intervals over
    //     38,400 units of climb, ~15x sparser than the tower now is.
    // Seed every riser here too. Risers live ONLY on landings by construction
    // (see the §6f rule above), so a seed can never land inside a brush, and
    // `Could not drop node at (x,y,z)` in tools/cod2map_last.log names any that
    // does. node_pathnode is on the EXCLUSION list (carves nothing), is
    // invisible, spawns NO runtime gentity (so the ~1024 gentity budget is
    // untouched) and is untargeted by script — zm_giant ships six the same way.
    //
    // THE RULE: SEED EVERY WALKABLE REGION, not just detached ones, and not
    // just the floor that broke. FULL build — the navmesh is what changes.
    zn.risers.forEach(([sx, sy, sz], i) => {
      ent(`${zn.name} navmesh seed ${i + 1}`, [
        '{', `guid "${guid()}"`,
        kv('classname', 'node_pathnode'),
        kv('origin', `${SP_X + sx} ${SP_Y + sy} ${sz + 2}`),
        kv('_color', '1 0 1'), '}',
      ]);
    });
  }
  // respawn groups: arena + every hub + the summit. script_noteworthy MUST be
  // the owning zone's name or manage_zones leaves the group locked forever —
  // the trap that shipped four inert breather groups once.
  const spGroup = (label, tn, zone, org, spawns) => {
    ent(`${label} respawn group`, [
      '{', `guid "${guid()}"`, kv('classname', 'script_struct'),
      kv('angles', '0 90 0'), kv('origin', `${org[0]} ${org[1]} ${org[2]}`),
      kv('radius', '2000'), kv('script_int', '2000'),
      kv('script_noteworthy', zone),
      kv('target', tn), kv('targetname', 'player_respawn_point'),
      kv('_color', '1 0 0'), '}',
    ]);
    spawns.forEach(([sx, sy, sz], i) => {
      ent(`${label} spawn ${i + 1}`, [
        '{', `guid "${guid()}"`, kv('classname', 'script_struct'),
        kv('_color', i % 2 ? '1 0 1' : '1 1 0'),
        kv('angles', '0 90 0'), kv('origin', `${sx} ${sy} ${sz}`),
        kv('radius', '32'), kv('targetname', tn), '}',
      ]);
    });
  };
  spGroup('spire base', 'tod_respawn_spire_base', 'spire_base_zone',
    [SP_X - 400, SP_Y, 28],
    [[SP_X - 430, SP_Y - 140, 28], [SP_X - 430, SP_Y - 20, 28], [SP_X - 430, SP_Y + 100, 28], [SP_X - 360, SP_Y - 20, 28]]);
  for (const hl of SP_HUBS) {
    const mz = (hl - 1) * LAP_RISE + FLIGHT_RISE + 28;
    // v16.19: inside the hub hall (the N gallery by default) — a mid-trial
    // death must come back INTO the sealed fight. v18.78: per layout
    // (L.spawns) — a hall with a vendor on the N wall respawns in the NW region.
    const HL = SP_RM_LAYOUTS[SP_HUBS.indexOf(hl)];
    spGroup(`spire hub lap${hl}`, `tod_respawn_spire${hl}`, `spire_c${Math.ceil(hl / SP_ZONE_CHUNK)}_zone`,
      [SP_X + HL.spawns[0][0] + 40, SP_Y + HL.spawns[0][1] + 20, mz],
      HL.spawns.map(([sx, sy]) => [SP_X + sx, SP_Y + sy, mz]));
  }
  spGroup('spire summit', 'tod_respawn_spire_summit', 'spire_summit_zone',
    [SP_X, SP_Y + 368, SP_TOP2 + 28],
    [[SP_X - 240, SP_Y + 368, SP_TOP2 + 28], [SP_X + 240, SP_Y + 368, SP_TOP2 + 28], [SP_X - 360, SP_Y + 420, SP_TOP2 + 28], [SP_X + 360, SP_Y + 420, SP_TOP2 + 28]]);

  // --- 6g. lights + probes (sparse: 1 red pool per lap, gold at the hubs) ---
  light('spire light base 1', SP_X - 470, SP_Y - 470, 240, SP_LIGHT_RED, 520, 6, 1);
  light('spire light base 2', SP_X + 470, SP_Y - 470, 240, SP_LIGHT_RED, 520, 6, 1);
  light('spire light base 3', SP_X + RK_NW_LIGHT[0], SP_Y + RK_NW_LIGHT[1], 240, SP_LIGHT_RED, 520, 6, 1);   // v19.68s: off the wreck's hull (RK_NW_LIGHT)
  light('spire light base 4', SP_X + 470, SP_Y + 470, 240, SP_LIGHT_RED, 520, 6, 1);
  light('spire light arrival', SP_X - 200, SP_Y, 200, '1 0.9 0.78', 420, 6, 1);
  for (let lap = 0; lap < SP_LAPS; lap++) {
    const mid = lap * LAP_RISE + FLIGHT_RISE;
    const s = (lap % 2 === 0) ? 1 : -1;
    light(`spire light lap${lap + 1}`, SP_X + s * 336, SP_Y + s * 336, mid + 160, SP_LIGHT_RED, 420, 6, 1);
    if ((lap + 1) % SP_HUB_EVERY === 0) {
      // v16.19: the hall — one pool high in the open core, one in each
      // gallery corner. v17.69: all five take the HALL'S HUE (SP_RM_LAYOUTS)
      // — gold / green / cyan / purple / orange / white / red up the tower —
      // so each hall is lit in its own colour (was gold heart + red corners).
      const hue = SP_HUE[SP_RM_LAYOUTS[SP_HUBS.indexOf(lap + 1)].hue];
      light(`spire light hub${lap + 1}`, SP_X, SP_Y, mid + 420, hue, 760, 6, 1);
      [[300, 300], [-300, 300], [300, -300], [-300, -300]].forEach(([px, py], i) =>
        light(`spire light hub${lap + 1} corner ${i + 1}`, SP_X + px, SP_Y + py, mid + 160, hue, 460, 6, 1));
    }
  }
  light('spire light summit 1', SP_X - 180, SP_Y, SP_TOP2 + 200, SP_LIGHT_GOLD, 520, 6, 1);
  light('spire light summit 2', SP_X + 180, SP_Y, SP_TOP2 + 200, SP_LIGHT_GOLD, 520, 6, 1);
  SP_SM_PILLARS.forEach(([px, py], i) => light(`spire light summit corner ${i + 1}`, SP_X + px * 0.8, SP_Y + py * 0.8, SP_TOP2 + 220, SP_LIGHT_RED, 560, 6, 1));   // v17.70: the arena's red corners
  light('spire light beacon', SP_X, SP_Y, SP_TOP2 + SP_BEACON_H + 24, '1 0.25 0.2', 900, 6, 1);
  probe('probe spire base', SP_X, SP_Y, 150);
  for (let lap = 1; lap <= SP_LAPS; lap += 5) {
    const s = (lap % 2 === 1) ? 336 : -336;
    probe(`probe spire lap${lap}`, SP_X + s, SP_Y + s, (lap - 1) * LAP_RISE + FLIGHT_RISE + 150);
  }
  for (const hl of SP_HUBS)   // v16.19: one probe per hub hall, in the open core
    probe(`probe spire hub${hl}`, SP_X, SP_Y, (hl - 1) * LAP_RISE + FLIGHT_RISE + 150);
  probe('probe spire summit', SP_X, SP_Y, SP_TOP2 + 150);

  // --- 6h. _tod_spire_data.gsc ----------------------------------------------
  const s = [];
  s.push('// GENERATED by tools/gen_tower_map.js — DO NOT HAND-EDIT (regen instead).');
  s.push('// THE ENDLESS SPIRE anchors (docs/44): door positions ride the same');
  s.push('// arithmetic that cut the slabs, so script and geometry cannot drift.');
  s.push('// Doors have NO map triggers — _tod_spire spawns them lazily in the climb');
  s.push('// window (the gentity-table budget, docs/44 §4).');
  s.push('');
  s.push('#namespace tod_spire_data;');
  s.push('');
  s.push(`function spire_x()        { return ${SP_X}; }`);
  s.push(`function spire_y()        { return ${SP_Y}; }`);
  s.push(`function spire_laps()     { return ${SP_LAPS}; }`);
  s.push(`function spire_top()      { return ${SP_TOP}; }`);
  s.push(`function spire_summit_z() { return ${SP_TOP2}; }`);
  s.push(`function door_cost()      { return ${SP_DOOR_COST}; }`);
  s.push(`function summit_cost()    { return ${SP_SUMMIT_COST}; }`);
  s.push('');
  s.push('// Is this point anywhere on the spire (arena, spiral, hubs, summit)?');
  s.push('function in_spire( org )');
  s.push('{');
  // v16.15: 1400 -> 1500 (the outside arena needed it; the v16.19 hall does
  // not, but a wider bound costs nothing and the assert keeps it honest).
  if (SP_RM_OUT + SP_RM_WALL + 100 > 1500 || SP_SHELF_X2 + PARA + 100 > 1500) throw new Error('in_spire bound no longer encloses the spire with 100u to spare');
  s.push(`\treturn ( org[ 0 ] > ${SP_X - 1500} && org[ 0 ] < ${SP_X + 1500} && org[ 1 ] > ${SP_Y - 1500} && org[ 1 ] < ${SP_Y + 1500} );`);
  s.push('}');
  s.push('');
  s.push('// v14.36 — ONE DOOR PER FLOOR, TOWER-MATCHED (2 flights per door).');
  s.push('// Door n seals floor n. ODD floors sit on the E face (y=-256), EVEN on');
  s.push('// the W face (y=+256) — the tower DOORS table\'s own parity, because odd');
  s.push('// flights climb E+N and even flights W+S. (v14.23\'s 50 doors were all');
  s.push('// on the E face precisely BECAUSE they only sealed odd floors; a');
  s.push('// per-floor door that ignored parity would hang on the wrong side of');
  s.push('// the core every other floor.) Slabs are .map residents on the tower');
  s.push('// door contract; NO movers — the v14.1 parity mover never re-seated');
  s.push('// live and its un-set flags instakilled climbers (CHANGELOG v14.23).');
  s.push(`function spire_door_count() { return ${SP_LAPS}; }`);
  s.push('function get_spire_door_info( n )');
  s.push('{');
  s.push(`\tif ( n < 1 || n > ${SP_LAPS} )`);
  s.push('\t\treturn undefined;');
  s.push(`\tb = ( n - 1 ) * ${LAP_RISE};`);
  s.push('\tinfo = SpawnStruct();');
  s.push('\tif ( ( n % 2 ) == 1 )');
  s.push(`\t\tinfo.org = ( ${SP_X + 336}, ${SP_Y - 256}, b + 40 );`);
  s.push('\telse');
  s.push(`\t\tinfo.org = ( ${SP_X - 336}, ${SP_Y + 256}, b + 40 );`);
  s.push('\tinfo.off = ( 0, 60, 0 );');
  s.push(`\tinfo.cost = ${SP_DOOR_COST};`);
  s.push('\tinfo.flag = "enter_spire" + n;');
  s.push('\tinfo.target = "tod_spire_door" + n;');
  s.push('\tinfo.floor = n;');
  s.push('\tinfo.dest = "the Spire - Floor " + n;');
  s.push('\treturn info;');
  s.push('}');
  s.push(`function spire_door_z( n ) { return ( n - 1 ) * ${LAP_RISE}; }`);
  s.push('');
  s.push('// v14.31 — THE HONOUR GUARD anchor: the MID landing of the floor door n');
  s.push('// just opened — the same landing that floor\'s own risers use, hence');
  s.push('// proven-open ground. v14.36: parity-aware, because per-floor doors');
  s.push('// alternate faces (odd -> NE at +336,+336; even -> SW at -336,-336,');
  s.push('// mirroring the riser table in section 6f).');
  s.push('// _tod_spire hands this to spawn_panzer as tod_boss_force_org; that');
  s.push('// path still runs pick_spawn_point + ground_snap, so this is a HINT,');
  s.push('// not a teleport — a blocked anchor scatters rather than stacking.');
  s.push('function guard_spawn_org( n )');
  s.push('{');
  s.push(`\tmid = ( n - 1 ) * ${LAP_RISE} + ${FLIGHT_RISE};`);
  s.push('\tif ( ( n % 2 ) == 1 )');
  s.push(`\t\treturn ( ${SP_X + 336}, ${SP_Y + 336}, mid );`);
  s.push(`\treturn ( ${SP_X - 336}, ${SP_Y - 336}, mid );`);
  s.push('}');
  s.push('');
  s.push('// Crate shelf per floor (floors 5+; hub floors use the hub crate; the');
  s.push('// arena crate covers 1-4). undefined = no shelf on that floor.');
  s.push('//');
  s.push('// ⚠️ THE UPPER BOUND IS LOAD-BEARING (v17.83, user 2026-09-05: "lingering');
  s.push('// ammo crates about the spire on floor 70 ... looking up during boss fight');
  s.push('// and I swear i saw some leftover crate models"). This is a FORMULA, not a');
  s.push('// table, and it had no ceiling: _tod_spire::crate_window materialises every');
  s.push('// floor within TOD_SPIRE_CRATE_WINDOW of a player and trusts an `isdefined`');
  s.push('// on this return. On the summit deck the player reads as floor');
  s.push(`// ${SP_LAPS + 1}, so the window asked for ${SP_LAPS + 2}..${SP_LAPS + 4} — and this function`);
  s.push('// happily returned coordinates for floors that have no shelf, no landing and');
  s.push('// no tower: three crate models hanging in the sky over the boss fight.');
  s.push('//');
  s.push(`// It was invisible until v17.69 cut the spire from 100 laps to ${SP_LAPS}: at 100`);
  s.push('// laps those floors had real shelves. Same class as the sun volume (docs/107)');
  s.push('// — a DERIVED value that did not follow the lap-count cut. When SP_LAPS moves,');
  s.push('// grep for every unbounded per-floor formula in this emitter, not just this one.');
  s.push('function shelf_crate_org( n )');
  s.push('{');
  s.push(`\tif ( n < 5 || n > ${SP_LAPS} || ( n % ${SP_HUB_EVERY} ) == 0 || ( n % ${SP_HUB_EVERY} ) == 1 )   // v16.19: no shelf on a hub floor or the floor after it (inside the drum); v17.83: none above the top floor`);
  s.push('\t\treturn undefined;');
  s.push(`\tmid = ( n - 1 ) * ${LAP_RISE} + ${FLIGHT_RISE};`);
  s.push('\tif ( ( n % 2 ) == 1 )');
  s.push(`\t\treturn ( ${SP_X + SP_CRATE_LX}, ${SP_Y + SP_CRATE_LY}, mid );`);
  s.push(`\treturn ( ${SP_X - SP_CRATE_LX}, ${SP_Y - SP_CRATE_LY}, mid );`);
  s.push('}');
  s.push('// Yaws from the generator\'s one crate contract (CRATE_YAW_*: front = yaw + 90).');
  s.push('// Odd shelves hang EAST of the NE landing and face WEST back onto it; even');
  s.push('// shelves are the mirror. The arena crate backs the S wall and faces NORTH.');
  s.push('// The v14.23 "flip all four" was the right call and this is its record.');
  s.push(`function shelf_crate_yaw( n ) { return ( ( ( n % 2 ) == 1 ) ? ${CRATE_YAW_W} : ${CRATE_YAW_E} ); }`);
  s.push(`function arena_crate_org() { return ( ${SP_X + SP_ARENA_CRATE[0]}, ${SP_Y + SP_ARENA_CRATE[1]}, 0 ); }`);
  s.push(`function arena_crate_yaw() { return ${CRATE_YAW_N}; }`);
  s.push('');
  s.push('// THE WARDEN TRIALS — THE HUB HALL (v16.19 / v16.21): anchors around the tower');
  s.push('// axis, even frame (every hub lap is even, asserted in the generator).');
  s.push('// trial_box is the HALL ONLY (v16.21): the drum footprint north of the S');
  s.push('// lane, MINUS the W flight\'s slot (the notch) and MINUS the next lap\'s E');
  s.push('// flight beyond door n+1 — in_box applies both exclusions. The gate is the');
  s.push('// HALL GATE across the porch\'s mouth (hidden until the trial). Every hub');
  s.push('// has its own layout: the mark (where the Max Ammo lands) and the Warden');
  s.push('// drop point come from it.');
  s.push(`function hub_every() { return ${SP_HUB_EVERY}; }`);
  s.push(`function is_hub( n ) { return ( n >= ${SP_HUB_EVERY} && n <= ${SP_LAPS} && ( n % ${SP_HUB_EVERY} ) == 0 ); }`);
  s.push('// The hub whose trial guards door n (door n opens the floor ABOVE hub n-1),');
  s.push('// or 0 when door n is not a trial door.');
  s.push('function trial_hub_of_door( n )');
  s.push('{');
  s.push('\tif ( n > 1 && is_hub( n - 1 ) )');
  s.push('\t\treturn ( n - 1 );');
  s.push('\treturn 0;');
  s.push('}');
  s.push('function trial_gate_target( hub ) { return "tod_spire_hall_gate" + hub; }');
  s.push('// z = hub_z (the hall floor = the mid landing).');
  s.push('function trial_box( z )');
  s.push('{');
  s.push('\tb = SpawnStruct();');
  s.push(`\tb.x1 = ${SP_X - SP_RM_OUT - SP_RM_WALL};`);
  s.push(`\tb.x2 = ${SP_X + SP_RM_OUT + SP_RM_WALL};`);
  s.push(`\tb.y1 = ${SP_Y - SP_RM_OUT - SP_RM_WALL};   // v18.78: the SE alcove (east of the S lane's end wall, south of -CORE) is IN; the S lane + SW landing are exclusion 3`);
  s.push(`\tb.y2 = ${SP_Y + SP_RM_OUT + SP_RM_WALL};`);
  s.push(`\tb.z1 = z - ${RISE * (SP_RM_PORCH_N - 1) + 40};   // under the porch's lowest step`);
  s.push(`\tb.z2 = z + ${FLIGHT_RISE + 100};`);
  s.push('\t// exclusion 1: the E lane past door n+1 (the next lap\'s E flight)');
  s.push(`\tb.ex1 = ${SP_X + CORE - PARA};`);
  s.push(`\tb.ex2 = ${SP_X + SP_RM_OUT + SP_RM_WALL};`);
  s.push(`\tb.ey1 = ${SP_Y - CORE + 10};`);
  s.push(`\tb.ey2 = ${SP_Y + SP_RM_OUT + SP_RM_WALL};`);
  s.push(`\tb.ez1 = z + ${FLIGHT_RISE - 10};`);
  s.push(`\tb.ez2 = z + ${FLIGHT_RISE + 300};`);
  s.push('\t// exclusion 2: the W flight\'s slot (the notch) — outside the hall gate —');
  s.push('\t// PLUS the gate\'s own thickness and a player\'s radius (40 past the x=-256');
  s.push('\t// line): nobody standing in the slab\'s volume may count as "in", or the');
  s.push('\t// seal closes on them (v16.26 review find)');
  s.push(`\tb.nx1 = ${SP_X - SP_RM_OUT - SP_RM_WALL};`);
  s.push(`\tb.nx2 = ${SP_X - CORE + 40};`);
  s.push(`\tb.ny1 = ${SP_Y - CORE - 10};`);
  s.push(`\tb.ny2 = ${SP_Y + SP_RM_NOTCH_Y};`);
  s.push('\t// exclusion 3 (v18.78): the S lane + the SW landing, outside the seal. y1 used');
  s.push('\t// to stop at -CORE, which ALSO cut out the SE ALCOVE under the SE landing: no');
  s.push('\t// riser, no elite landing and no player ever counted there, which made it');
  s.push('\t// the safest spot in every hall (tools/lint_tod_hall_bunkers.js).');
  s.push(`\tb.sx1 = ${SP_X - SP_RM_OUT - SP_RM_WALL};`);
  s.push(`\tb.sx2 = ${SP_X + CORE - PARA};`);
  s.push(`\tb.sy1 = ${SP_Y - SP_RM_OUT - SP_RM_WALL};`);
  s.push(`\tb.sy2 = ${SP_Y - CORE};`);
  s.push('\t// exclusion 4 (2026-09-10, first play of the open halls: "zombies spawning outside"');
  s.push('\t// + "elites and panzers freezing"): everything ABOVE the alcove roof in the SE corner.');
  s.push('\t// The SE LANDING (lap n+1\'s start, 192 up) is outside the seal — reached only up the');
  s.push('\t// S flight from the SW landing, behind door n+1 — and it carries a riser at (336,-336).');
  s.push('\t// v18.78 let it in with the alcove: a zombie rising there was stranded outside the');
  s.push('\t// gate, and pick_spawn_point could stand an elite there with no route to anyone.');
  s.push('\t// The alcove floor is at z; its roof (the landing slab) at z + 176 — so the cut starts');
  s.push('\t// at z + 100 and covers the S flight\'s top treads east of the lane wall too.');
  s.push(`\tb.tx1 = ${SP_X + CORE - PARA};`);
  s.push(`\tb.tx2 = ${SP_X + SP_RM_OUT + SP_RM_WALL};`);
  s.push(`\tb.ty1 = ${SP_Y - SP_RM_OUT - SP_RM_WALL};`);
  s.push(`\tb.ty2 = ${SP_Y - CORE + 10};`);
  s.push('\tb.tz1 = z + 100;');
  s.push(`\tb.tz2 = z + ${FLIGHT_RISE + 300};`);
  s.push('\treturn b;');
  s.push('}');
  s.push('function in_box( org, b )');
  s.push('{');
  s.push('\tif ( !( org[ 0 ] > b.x1 && org[ 0 ] < b.x2 && org[ 1 ] > b.y1 && org[ 1 ] < b.y2 && org[ 2 ] > b.z1 && org[ 2 ] < b.z2 ) )');
  s.push('\t\treturn false;');
  s.push('\tif ( isdefined( b.ex1 ) && org[ 0 ] > b.ex1 && org[ 0 ] < b.ex2 && org[ 1 ] > b.ey1 && org[ 1 ] < b.ey2 && org[ 2 ] > b.ez1 && org[ 2 ] < b.ez2 )');
  s.push('\t\treturn false;');
  s.push('\tif ( isdefined( b.nx1 ) && org[ 0 ] > b.nx1 && org[ 0 ] < b.nx2 && org[ 1 ] > b.ny1 && org[ 1 ] < b.ny2 )');
  s.push('\t\treturn false;');
  s.push('\tif ( isdefined( b.sx1 ) && org[ 0 ] > b.sx1 && org[ 0 ] < b.sx2 && org[ 1 ] > b.sy1 && org[ 1 ] < b.sy2 )');
  s.push('\t\treturn false;');
  s.push('\tif ( isdefined( b.tx1 ) && org[ 0 ] > b.tx1 && org[ 0 ] < b.tx2 && org[ 1 ] > b.ty1 && org[ 1 ] < b.ty2 && org[ 2 ] > b.tz1 && org[ 2 ] < b.tz2 )');
  s.push('\t\treturn false;');
  s.push('\treturn true;');
  s.push('}');
  s.push('// per-hub layout anchors (SP_RM_LAYOUTS): index = hub / hub_every - 1');
  s.push('function trial_layout_index( hub ) { return ( int( hub / hub_every() ) - 1 ); }');
  s.push('function trial_mark_org( hub, z )');
  s.push('{');
  s.push('\tswitch ( trial_layout_index( hub ) )');
  s.push('\t{');
  // a mark or Warden point on a dais rides on the dais's TOP (the Max Ammo
  // drop is not ground-traced; a point inside the tiers would bury it)
  const lift = rmLift;   // v17.86: dais / throne / plat (the shared helper beside rmFeatBox)
  SP_RM_LAYOUTS.forEach((L, i) => s.push(`\t\tcase ${i}: return ( ${SP_X + L.mark[0]}, ${SP_Y + L.mark[1]}, z + ${lift(L, L.mark)} );   // ${L.name}`));
  s.push('\t}');
  s.push(`\treturn ( ${SP_X}, ${SP_Y}, z );`);
  s.push('}');
  s.push('function trial_warden_org( hub, z )');
  s.push('{');
  s.push('\tswitch ( trial_layout_index( hub ) )');
  s.push('\t{');
  SP_RM_LAYOUTS.forEach((L, i) => s.push(`\t\tcase ${i}: return ( ${SP_X + L.warden[0]}, ${SP_Y + L.warden[1]}, z + ${lift(L, L.warden)} );   // ${L.name}`));
  s.push('\t}');
  s.push(`\treturn ( ${SP_X}, ${SP_Y + 100}, z );`);
  s.push('}');
  s.push('// the hall gate\'s centre at hall-floor level (the FX hosts stand along it);');
  s.push('// it runs along y, so hosts spread on y and face +x (into the hall).');
  s.push(`function trial_gate_org( z )   { return ( ${SP_X - CORE}, ${SP_Y + (SP_RM_GATE_Y1 + SP_RM_PORCH_Y2) / 2}, z ); }`);
  s.push(`function trial_gate_len()      { return ${SP_RM_PORCH_Y2 - SP_RM_GATE_Y1}; }`);
  s.push('function trial_gate_axis()     { return ( 0, 1, 0 ); }');
  s.push('function trial_gate_yaw()      { return 0; }');
  s.push('');
  s.push('// vendor hubs (every 10th floor, even frame) — on the hub hall\'s walls since v16.19;');
  s.push('// v18.78: PER HUB (SP_RM_LAYOUTS[i].furn — which wall each vendor stands on). index = hub / hub_every - 1');
  s.push(`function hub_laps() { return array( ${SP_HUBS.join(', ')} ); }`);
  s.push(`function hub_z( lap ) { return ( lap - 1 ) * ${LAP_RISE} + ${FLIGHT_RISE}; }`);
  const perHub = (name, args, pick, fallback) => {
    s.push(`function ${name}( ${args} )`); s.push('{'); s.push('\tswitch ( trial_layout_index( hub ) )'); s.push('\t{');
    SP_RM_LAYOUTS.forEach((L, i) => s.push(`\t\tcase ${i}: return ${pick(L)};   // ${L.name} (${L.furn.pap.side} wall PaP, ${L.furn.crate.side} wall crate)`));
    s.push('\t}'); s.push(`\treturn ${fallback};`); s.push('}');
  };
  const D = SP_FURN_DEFAULT;
  perHub('hub_pap_org', 'hub, z', L => `( ${SP_X + L.furn.pap.org[0]}, ${SP_Y + L.furn.pap.org[1]}, z )`, `( ${SP_X + D.pap.org[0]}, ${SP_Y + D.pap.org[1]}, z )`);
  perHub('hub_pap_trig', 'hub, z', L => `( ${SP_X + L.furn.pap.trig[0]}, ${SP_Y + L.furn.pap.trig[1]}, z )`, `( ${SP_X + D.pap.trig[0]}, ${SP_Y + D.pap.trig[1]}, z )`);
  perHub('hub_pap_yaw', 'hub', L => `${L.furn.pap.yaw}`, `${D.pap.yaw}`);
  perHub('hub_crate_org', 'hub, z', L => `( ${SP_X + L.furn.crate.org[0]}, ${SP_Y + L.furn.crate.org[1]}, z )`, `( ${SP_X + D.crate.org[0]}, ${SP_Y + D.crate.org[1]}, z )`);
  perHub('hub_crate_yaw', 'hub', L => `${L.furn.crate.yaw}`, `${D.crate.yaw}`);
  s.push('// (hub_perk_pads / hub_perk_yaw / hub_perk_front / arena_perk_pads — RETIRED');
  s.push('// v17.56: the spire sells no perks, every perk is perma-granted on ascension.)');
  s.push('');
  s.push('// arrival + summit');
  s.push(`function arrival_org()     { return ( ${SP_X - 400}, ${SP_Y}, 0 ); }   // west-band centre — NEVER inside |x|<256 (the core column)`);
  s.push(`function summit_exfil_org(){ return ( ${SP_X}, ${SP_Y - 150}, ${SP_TOP2 + SLAB + 8} ); }`);

  // THE ROCKET'S CRASH (docs/170): the ASCEND ride ends with the nose in the arena's NW corner pillar; the burnt
  // wreck stays there (pivot + angles of the lying-down model), and the riders stand up at the arrival facing it.
  s.push('// THE ROCKET (docs/170, _tod_rocket.gsc): the crash, the wreck, the arrival facing it');
  s.push(`function rocket_crash_tip()          { return ( ${rkR2(RK_TIP).join(', ')} ); }`);
  s.push(`function rocket_wreck_org()          { return ( ${rkR2(RK_WRECK_PIV).join(', ')} ); }`);
  s.push(`function rocket_wreck_angles()       { return ( ${RK_WRECK_ANG.join(', ')} ); }`);
  s.push(`function rocket_arrival_yaw()        { return ${RK_ARRIVAL_YAW}; }`);
  // v17.70 THE SUMMIT ARENA (the Warden King) — the box every spawn is kept
  // inside and every player must stand inside for the fight to begin (the
  // stair well is excluded: nobody standing in the gate's volume may count as
  // in), the gate across the stair's mouth, the king's drop and the mark.
  s.push('function summit_box()');
  s.push('{');
  s.push('\tb = SpawnStruct();');
  s.push(`\tb.x1 = ${SP_X - SP_SM_HALF};`);
  s.push(`\tb.x2 = ${SP_X + SP_SM_HALF};`);
  s.push(`\tb.y1 = ${SP_Y - SP_SM_HALF};`);
  s.push(`\tb.y2 = ${SP_Y + SP_SM_HALF};`);
  s.push(`\tb.z1 = ${SP_TOP2 - 40};`);
  s.push(`\tb.z2 = ${SP_TOP2 + 400};`);
  s.push('\t// exclusion: the stair well + the gate\'s volume + a player radius north of it');
  s.push(`\tb.ex1 = ${SP_X + CORE - 40};`);
  s.push(`\tb.ex2 = ${SP_X + PX + PARA + 40};`);
  s.push(`\tb.ey1 = ${SP_Y - CORE - 40};`);
  s.push(`\tb.ey2 = ${SP_Y + SP_SM_GATE_Y + 48};`);
  s.push(`\tb.ez1 = ${SP_TOP - 8};`);
  s.push(`\tb.ez2 = ${SP_TOP2 + 300};`);
  s.push('\treturn b;');
  s.push('}');
  s.push(`function summit_gate_target() { return "tod_spire_summit_gate"; }`);
  s.push(`function summit_gate_org()    { return ( ${SP_X + (CORE + PX + PARA) / 2}, ${SP_Y + SP_SM_GATE_Y}, ${SP_TOP2} ); }`);
  s.push(`function summit_gate_len()    { return ${PX + PARA - CORE}; }`);
  s.push('function summit_gate_axis()   { return ( 1, 0, 0 ); }');
  s.push('function summit_gate_yaw()    { return 90; }');
  s.push(`function summit_king_org()    { return ( ${SP_X + SP_SM_KING_ORG[0]}, ${SP_Y + SP_SM_KING_ORG[1]}, ${SP_TOP2 + SLAB} ); }`);
  s.push(`function summit_mark_org()    { return ( ${SP_X + SP_SM_MARK[0]}, ${SP_Y + SP_SM_MARK[1]}, ${SP_TOP2 + SLAB} ); }`);
  s.push(`function summit_crate_org()   { return ( ${SP_X + SP_SM_CRATE.org[0]}, ${SP_Y + SP_SM_CRATE.org[1]}, ${SP_TOP2 + SLAB} ); }`);
  s.push(`function summit_crate_yaw()   { return ${SP_SM_CRATE.yaw}; }`);
  s.push(`function beacon_org()      { return ( ${SP_X}, ${SP_Y}, ${SP_TOP2 + SP_BEACON_H + 24} ); }`);
  s.push('');
  s.push('// THE ASCENSION PAD — on the crown hall DAIS (the focal point the uplink');
  s.push('// left behind in v10). Crown-frame coordinates, pre-mirrored like every');
  s.push('// _tod_crown_data anchor.');
  s.push(`function ascension_pad_org() { return ${(() => { const p = cpt(0, HYC, TOP2 + DAIS_H); return `( ${p[0]}, ${p[1]}, ${p[2]} )`; })()}; }`);
  s.push(`function ascension_pad_yaw() { return ${cyaw(180)}; }`);
  s.push('');
  s.push('// zone bookkeeping for the wiring (zonemgr adjacency, spawn filter)');
  s.push(`function zone_chunk() { return ${SP_ZONE_CHUNK}; }`);
  s.push('function spire_zone_of( n ) { return "spire_c" + ( int( ( n - 1 ) / ' + SP_ZONE_CHUNK + ' ) + 1 ) + "_zone"; }');
  s.push('function spire_zone_names()');
  s.push('{');
  s.push('\ta = [];');
  s.push('\ta[ 0 ] = "spire_base_zone";');
  for (let k = 1; k <= SP_LAPS / SP_ZONE_CHUNK; k++) s.push(`\ta[ ${k} ] = "spire_c${k}_zone";`);
  s.push(`\ta[ ${SP_LAPS / SP_ZONE_CHUNK + 1} ] = "spire_summit_zone";`);
  s.push('\treturn a;');
  s.push('}');
  s.push('');
  fs.mkdirSync(path.dirname(SPIRE_GSC_OUT), { recursive: true });   // the parity harness runs this file from a temp dir (door-data convention)
  fs.writeFileSync(SPIRE_GSC_OUT, s.join('\n'), 'utf8');
  console.log(`wrote ${SPIRE_GSC_OUT}`);
  console.log(`  spire: ${worldBrushes.length - sb0} brushes, ${entities.length - se0} entities, ${SP_LAPS} laps at x=${SP_X}, ` +
    `${SPIRE_DOORS.length} doors @${SP_DOOR_COST}, hubs ${SP_HUBS.join('/')}, top z=${SP_TOP2}, beacon ${SP_TOP2 + SP_BEACON_H}`);
}

// ---------------------------------------------------------------------------
// NAVMESH SEEDS — flush (see navSeed's block beside `worldBrushes`)
// ---------------------------------------------------------------------------
// OUTSIDE the SPIRE_ENABLED gate on purpose: the TOWER's flights need seeding
// too, and this is also where the "SPIRE_ENABLED = false produces a byte-
// identical tower" property stops holding. That flag is a dormant experiment
// and the coverage rule is not negotiable, so it is recorded here rather than
// worked around.
navSeeds.forEach((s) => {
  ent(`navmesh seed ${s.label}`, [
    '{',
    `guid "${guid()}"`,
    kv('classname', 'node_pathnode'),
    kv('origin', `${s.org[0]} ${s.org[1]} ${s.org[2]}`),
    kv('_color', '1 0 1'),
    '}',
  ]);
});
console.log(`  navmesh seeds: ${navSeeds.length} on ramps/shelves/porches/aprons (RAMP_SEEDS=${RAMP_SEEDS}), plus one per riser`);

// THE ROCKET CLIPS (docs/170): octagon prisms (convex brushes, the box() plane convention: outward normal =
// (P1-P2)x(P3-P2)), one script_brushmodel per ship. _tod_rocket.gsc opens both at init (NotSolid + ConnectPaths)
// and makes a ship's solid only while it stands on its pad - a world clip would have stood on the dais through the
// whole crown siege.
function octPrismBrush(cx, cy, apo, z1, z2, mat) {
  const t = `${mat} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  const f = v => v.map(x => Math.round(x * 1000) / 1000).join(' ');
  const L = [];
  for (let k = 0; k < 8; k++) {
    const a = (k * 45 + 22.5) * Math.PI / 180, n = [Math.cos(a), Math.sin(a)];
    const p2 = [cx + n[0] * apo, cy + n[1] * apo, z1];
    const p1 = [p2[0] - n[1] * 64, p2[1] + n[0] * 64, z1];      // along the face, so (p1-p2) x (p3-p2) = n
    const p3 = [p2[0], p2[1], z1 + 64];
    L.push(` ( ${f(p1)} ) ( ${f(p2)} ) ( ${f(p3)} ) ${t}`);
  }
  L.push(` ( ${f([cx + 64, cy, z2])} ) ( ${f([cx, cy, z2])} ) ( ${f([cx, cy + 64, z2])} ) ${t}`);   // top: +z
  L.push(` ( ${f([cx, cy + 64, z1])} ) ( ${f([cx, cy, z1])} ) ( ${f([cx + 64, cy, z1])} ) ${t}`);   // bottom: -z
  return ['{', ` guid "${guid()}"`, ...L, '}'].join('\n');
}
// v19.71 THE FIN SKIRT IS A SLOPE (the perch pass): the fin prism (apothem 100, to +100) under the
// body prism (apothem 66) left a flat 34-wide ring ledge 100 up round every landed ship - a perch
// the moment the clip goes solid. The fins' clip is now an octagonal FRUSTUM from apothem 100 at
// the feet to the body's 66 at PERCH_SLOPE (74 degrees), its top inside the body prism.
function octFrustumBrush(cx, cy, apoBot, apoTop, z1, z2, mat) {
  const t = `${mat} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  const f = v => v.map(x => Math.round(x * 1000) / 1000).join(' ');
  const L = [];
  for (let k = 0; k < 8; k++) {
    const a = (k * 45 + 22.5) * Math.PI / 180, n = [Math.cos(a), Math.sin(a)];
    const p2 = [cx + n[0] * apoBot, cy + n[1] * apoBot, z1];
    const p1 = [p2[0] - n[1] * 64, p2[1] + n[0] * 64, z1];      // along the face at the foot
    const p3 = [cx + n[0] * apoTop, cy + n[1] * apoTop, z2];      // up the face to the top ring
    L.push(` ( ${f(p1)} ) ( ${f(p2)} ) ( ${f(p3)} ) ${t}`);
  }
  L.push(` ( ${f([cx + 64, cy, z2])} ) ( ${f([cx, cy, z2])} ) ( ${f([cx, cy + 64, z2])} ) ${t}`);   // top: +z
  L.push(` ( ${f([cx, cy + 64, z1])} ) ( ${f([cx, cy, z1])} ) ( ${f([cx + 64, cy, z1])} ) ${t}`);   // bottom: -z
  return ['{', ` guid "${guid()}"`, ...L, '}'].join('\n');
}
const RK_CLIP_FIN_TAPER = Math.ceil((RK_CLIP_FIN_APO - RK_CLIP_BODY_APO) * PERCH_SLOPE);   // 119: the frustum's height
if (RK_CLIP_FIN_TAPER < RK_CLIP_FIN_TOP) throw new Error('the fin frustum must reach past the fin prism top it replaces');
for (const [kind, feet] of (ROCKETS ? [['spire', RK_SHIP_FEET], ['extract', RK_EXIT_FEET]] : [])) {
  const c = cpt(feet[0], feet[1], feet[2]);
  ent(`rocket clip ${kind}`, [
    '{', `guid "${guid()}"`,
    kv('classname', 'script_brushmodel'),
    kv('targetname', `tod_rocket_clip_${kind}`),
    octFrustumBrush(c[0], c[1], RK_CLIP_FIN_APO, RK_CLIP_BODY_APO, feet[2], feet[2] + RK_CLIP_FIN_TAPER, MAT.clip),
    octPrismBrush(c[0], c[1], RK_CLIP_BODY_APO, feet[2] + RK_CLIP_FIN_TOP, feet[2] + RK_LEN, MAT.clip),
    '}',
  ]);
}
console.log(`rockets: ${ROCKETS ? 'ON (2 ship clips; spire ' + RK_SHIP_FEET.join(',') + ' extract ' + RK_EXIT_FEET.join(',') + ', crash tip ' + rkR2(RK_TIP).join(',') + '; the NW corner broken: wall W to y ' + RK_CORNER.wy + ', wall N from x ' + RK_CORNER.nx + ', ' + RK_CORNER.rubble.length + ' crumbled ends, wreck clip ' + RK_CORNER.clip.join(',') + ')' : 'OFF (TOD_ROCKETS) - the old pad + teleporter choice'}`);

// v19.68t THE FLOOR-NUMBER SIGNS, CHECKED AGAINST EVERY BOX (ALL_BOXES): each sign must have a
// solid, VISIBLE wall right behind it everywhere (no number hanging in the air or on a clip), nothing
// in front of it (no number buried in a rail, a band or a cap), and a clear view from its door
// landing (the eye floorNumberWallAt stood on it). Sampled on a 5 x 3 grid per sign. Door slabs are
// script_brushmodels, not in ALL_BOXES: they sit right of each sign by construction (x >= CORE).
function checkFloorSigns() {
  const SEE_THROUGH = /^(clip|trigger|volume|sky|caulk|nodraw|hint|portal)/;
  const inside = (b, q) => q[0] > b.x1 && q[0] < b.x2 && q[1] > b.y1 && q[1] < b.y2 && q[2] > b.z1 && q[2] < b.z2;
  const segHits = (b, p0, p1) => {           // slab test: does the open segment p0 -> p1 pass through b?
    let t0 = 0, t1 = 1;
    for (const [i, lo, hi] of [[0, b.x1, b.x2], [1, b.y1, b.y2], [2, b.z1, b.z2]]) {
      const d = p1[i] - p0[i];
      if (Math.abs(d) < 1e-9) { if (p0[i] <= lo || p0[i] >= hi) return false; continue; }
      let a = (lo - p0[i]) / d, c = (hi - p0[i]) / d;
      if (a > c) [a, c] = [c, a];
      t0 = Math.max(t0, a); t1 = Math.min(t1, c);
      if (t0 >= t1) return false;
    }
    return true;
  };
  const bad = [];
  for (const s of FLOORNUM_SIGNS) {
    const zMin = s.z1 - 64, zMax = s.z2 + 64;
    const near = ALL_BOXES.filter(b => b.z2 > zMin && b.z1 < zMax);
    for (let i = 0; i <= 4; i++) for (let j = 0; j <= 2; j++) {
      const sa = s.s1 + (s.s2 - s.s1) * (0.04 + 0.92 * i / 4), z = s.z1 + (s.z2 - s.z1) * (0.06 + 0.88 * j / 2);
      const on = [s.ox + s.rt[0] * sa, s.oy + s.rt[1] * sa, z];
      const behind = [on[0] - s.out[0] * 3, on[1] - s.out[1] * 3, z];
      const front = [on[0] + s.out[0] * (FLOORNUM_PROUD + 1), on[1] + s.out[1] * (FLOORNUM_PROUD + 1), z];
      if (!near.some(b => !SEE_THROUGH.test(b.tex) && inside(b, behind))) { bad.push(`${s.label}: no visible wall behind (${on.map(v => Math.round(v)).join(',')})`); continue; }
      const cover = near.find(b => inside(b, front));
      if (cover) { bad.push(`${s.label}: covered by ${cover.label}`); continue; }
      const block = near.find(b => !SEE_THROUGH.test(b.tex) && segHits(b, s.eye, front));
      if (block) bad.push(`${s.label}: hidden from its door landing by ${block.label}`);
    }
  }
  if (bad.length) throw new Error(`floor-number signs (${bad.length} sample(s) failed):\n  ` + [...new Set(bad)].slice(0, 30).join('\n  '));
  console.log(`floor numbers: ${FLOORNUM_SIGNS.length} signs on the wall left of their doors - a visible wall behind every sample, nothing in front, a clear view from each door landing`);
}
if (RF_FLOORNUMS) checkFloorSigns();

// 2026-10-02 (pre-publish review): EVERY BREATHER RESPAWN POINT STANDS CLEAR OF EVERY SOLID BOX.
// v19.68n widened the ammo crate's clip sideways (crateBox y[-49,49]) and breather spawn 1, then
// (-340,-640), ended up 4 units inside the lounge crate's clip in all four lounges: stock's respawn
// pick (_zm.gsc get_valid_spawn_location) checks only PositionWouldTelefrag, never solids, so a
// co-op respawn there started stuck. A player hull (+-15, 72 tall) plus 8 of air must touch no box
// that is not a trigger / volume / sky (clip counts: it blocks players).
function checkBreatherSpawns() {
  const NOT_SOLID = /^(trigger|volume|sky)/;
  const R = 15 + 8, H = 72;
  const bad = [];
  for (const lap of [...BREATHER_LAPS].sort((a, b) => a - b)) {
    const floor = (lap - 1) * LAP_RISE + FLIGHT_RISE;   // the lounge floor (the spawn's z is this + 28)
    for (const [sx, sy] of BREATHER_SPAWN_XY) {
      const hit = ALL_BOXES.find(b => !NOT_SOLID.test(b.tex)
        && sx + R > b.x1 && sx - R < b.x2 && sy + R > b.y1 && sy - R < b.y2
        && floor + H > b.z1 && floor + 2 < b.z2);
      if (hit) bad.push(`lap ${lap} spawn (${sx},${sy}) touches ${hit.label} [${hit.x1},${hit.x2}] x [${hit.y1},${hit.y2}]`);
    }
  }
  if (bad.length) throw new Error(`breather respawn points in or against a solid (${bad.length}):\n  ` + bad.join('\n  '));
  console.log(`breather respawns: ${BREATHER_LAPS.size * BREATHER_SPAWN_XY.length} points, each player hull + 8 clear of every solid box`);
}
checkBreatherSpawns();

// ---------------------------------------------------------------------------
// v19.71 THE VENDOR PERCH CAPS — every script-collided vendor at its FIXED anchor
// (see PERCH CAPS at the emitters for why). Their collision is stock zm_collision_perks1
// boxes spawned at runtime, invisible to every tool that reads this .map, so the anchors
// are listed here and nowhere else.
// ---------------------------------------------------------------------------
{
  // THE PERK PADS: read straight out of _tod_perk_scatter.gsc's make_pad table, so a pad
  // moved there can never leave its cap behind (the machines shuffle between these pads;
  // every pad always holds one). The table is the only place the pads live.
  const scatter = fs.readFileSync(path.join(REPO, 'scripts', 'zm', 'zm_tower_of_doom', '_tod_perk_scatter.gsc'), 'utf8');
  const padRe = /make_pad\(\s*"([^"]+)",\s*\(\s*(-?[\d.]+),\s*(-?[\d.]+),\s*(-?[\d.]+)\s*\),\s*[\d.]+,\s*\(\s*(-?[\d.]+),\s*(-?[\d.]+),\s*-?[\d.]+\s*\)/g;
  let m, pads = 0;
  while ((m = padRe.exec(scatter))) {
    const [, disp, x, y, z, fx, fy] = m;
    vendorCap(`perk pad ${disp}`, [+x, +y], +z, [-(+fx), -(+fy)], VENDOR_PERK);
    pads++;
  }
  if (pads !== 9) throw new Error(`_tod_perk_scatter.gsc make_pad table: found ${pads} pads, the roster is 9 — the perk caps would miss a machine`);
  // THE ALTARS: base + four breathers + crown (station_spawn's six)
  vendorCap('base altar', BASE_STATION.org, 0, [0, 1], VENDOR_ALTAR);
  for (const lap of [...BREATHER_LAPS].sort((a, b) => a - b)) {
    const z = (lap - 1) * LAP_RISE + FLIGHT_RISE;
    vendorCap(`lap${lap} altar`, BR_FURN.station.org, z, [0, 1], VENDOR_ALTAR);
    vendorCap(`lap${lap} pap`, BR_FURN.pap.org, z, [-1, 0], VENDOR_PAP);
  }
  {
    const a = cpt(-HW + HWALL + CROWN_VENDOR_OFF, HYC, TOP2), p = cpt(HW - HWALL - CROWN_VENDOR_OFF, HYC, TOP2);
    vendorCap('crown hall altar', [a[0], a[1]], TOP2, [-CM, 0], VENDOR_ALTAR);
    vendorCap('crown hall pap', [p[0], p[1]], TOP2, [CM, 0], VENDOR_PAP);
  }
  // THE UPLINK stands free on the terrace (no wall to bury into): a column, out of reach
  {
    const u = cpt(-(CW_HALF + 96), (TER_Y1 + TER_Y2) / 2, TOP2);
    perchCap('crown uplink perch cap', { x1: u[0] - 48, x2: u[0] + 48, y1: u[1] - 48, y2: u[1] + 48 }, TOP2 + PERCH_VENDOR_Z, null, { column: true });
  }
  // (the spire hub PaPs are capped where the hubs are built — vendorCap in section 6)
}

// ---------------------------------------------------------------------------
// v19.71 EMIT THE PERCH CAPS — every request, now that every brush they could meet exists.
// ---------------------------------------------------------------------------
function emitPerchCaps() {
  if (CRATE_TRIG_LIFT >= CRATE_BOX_H + PERCH_SLOT) throw new Error(`crate trigger lift ${CRATE_TRIG_LIFT} must sit in the slot under the crate's perch cap (${CRATE_BOX_H + PERCH_SLOT})`);
  const solids = PERCH.prepare(worldBrushes.map(b => ({ label: b.label, planes: CB.readPlanes(b.text) })));
  const CELL = 128, grid = new Map();
  solids.forEach((b, i) => {
    for (let gx = Math.floor(b.lo[0] / CELL); gx <= Math.floor(b.hi[0] / CELL); gx++)
      for (let gy = Math.floor(b.lo[1] / CELL); gy <= Math.floor(b.hi[1] / CELL); gy++) {
        const k = gx + ',' + gy;
        if (!grid.has(k)) grid.set(k, []);
        grid.get(k).push(i);
      }
  });
  const inSolid = (p) => (grid.get(Math.floor(p[0] / CELL) + ',' + Math.floor(p[1] / CELL)) || []).some(i => {
    const b = solids[i];
    if (p[0] < b.lo[0] || p[0] > b.hi[0] || p[1] < b.lo[1] || p[1] > b.hi[1] || p[2] < b.lo[2] || p[2] > b.hi[2]) return false;
    return b.planes.every(q => CB.dot(q.n, p) <= q.d + 0.01);
  });
  const over = (x1, x2, y1, y2) => {
    const seen = new Set();
    for (let gx = Math.floor(x1 / CELL); gx <= Math.floor(x2 / CELL); gx++)
      for (let gy = Math.floor(y1 / CELL); gy <= Math.floor(y2 / CELL); gy++)
        for (const i of grid.get(gx + ',' + gy) || []) seen.add(i);
    return [...seen].map(i => solids[i]).filter(b => b.hi[0] > x1 + 0.5 && b.lo[0] < x2 - 0.5 && b.hi[1] > y1 + 0.5 && b.lo[1] < y2 - 0.5);
  };
  const q16 = v => Math.floor(v * 16) / 16;
  let n = 0;
  for (const r of PERCH_REQ) {
    const { fp, zBot, back, opts } = r;
    if (opts.column) {
      const above = over(fp.x1, fp.x2, fp.y1, fp.y2).filter(b => {
        const covers = b.lo[0] <= fp.x1 + 0.01 && b.hi[0] >= fp.x2 - 0.01 && b.lo[1] <= fp.y1 + 0.01 && b.hi[1] >= fp.y2 - 0.01;
        return (b.isDeck || b.isRamp || covers) && bottomOver(b, fp) >= zBot + 8;
      });
      const top = Math.min(zBot + PERCH_COLUMN_H, ...above.map(b => q16(bottomOver(b, fp) - 0.5)));
      addBox(r.label, fp.x1, fp.x2, fp.y1, fp.y2, zBot, top, PERCH_MAT);
      n++;
      continue;
    }
    const a = back[0] !== 0 ? 0 : 1, sgn = back[a];
    const lo = a === 0 ? fp.x1 : fp.y1, hi = a === 0 ? fp.x2 : fp.y2;
    let v1 = (a === 0 ? fp.y1 : fp.x1) - (opts.across || 0), v2 = (a === 0 ? fp.y2 : fp.x2) + (opts.across || 0);
    const vm = (v1 + v2) / 2;
    const u0 = sgn > 0 ? lo : hi, backEdge = sgn > 0 ? hi : lo;
    const P = (u, v, z) => (a === 0 ? [u, v, z] : [v, u, z]);
    // THE WALL: march back from the footprint's back edge; the prop must back onto a solid
    const search = opts.wallSearch === undefined ? PERCH_WALL_SLACK : opts.wallSearch;
    let wall = null;
    for (let t = 0; t <= search && wall === null; t++) {
      const c = backEdge + sgn * (t + 0.5);
      if (inSolid(P(c, vm, zBot + 8)) && inSolid(P(c, vm, zBot + 40))) wall = backEdge + sgn * t;
    }
    if (wall === null) throw new Error(`${r.label}: no wall within ${search} behind it - a perch cap must bury into a wall (move the prop flush, or give it a column)`);
    // ...and the wall (or what stands proud of it - the crown crate's gold panel is narrower
    // than the crate) must be met somewhere inside the bury depth across the whole prop
    const walled = v => {
      for (let t = 1; t < PERCH_BURY; t++) if (inSolid(P(wall + sgn * t, v, zBot + 20))) return true;
      return false;
    };
    if (opts.minHalf !== undefined) {
      // a VENDOR's cap is wider than its mesh (it covers the stock collision boxes, whose
      // size this repo cannot read): trim it to where its wall really runs, never under
      // minHalf either side of the vendor's centre line
      let a1 = vm, a2 = vm;
      while (a1 - 2 >= v1 && walled(a1 - 2)) a1 -= 2;
      while (a2 + 2 <= v2 && walled(a2 + 2)) a2 += 2;
      if (a1 > vm - opts.minHalf || a2 < vm + opts.minHalf)
        throw new Error(`${r.label}: its wall runs only [${a1 - vm}, ${a2 - vm}] either side of it - the vendor needs +-${opts.minHalf}`);
      v1 = Math.max(v1, a1); v2 = Math.min(v2, a2);
    } else {
      const across = [v1 + 4, vm, v2 - 4].filter(walled).length;
      if (across < 3) throw new Error(`${r.label}: the wall behind it does not span the prop (${across}/3 samples meet a solid within ${PERCH_BURY})`);
    }
    const uEnd = wall + sgn * PERCH_BURY;
    const run = Math.abs(uEnd - u0);
    const zLip = zBot + PERCH_LIP, zEnd = zLip + PERCH_SLOPE * run;
    // THE CEILING: whatever stands above the cap's footprint (a flight, a gallery, a canopy)
    const ux1 = Math.min(u0, uEnd), ux2 = Math.max(u0, uEnd);
    const fx1 = a === 0 ? ux1 : v1, fx2 = a === 0 ? ux2 : v2, fy1 = a === 0 ? v1 : ux1, fy2 = a === 0 ? v2 : ux2;
    // A cap stops under a FLOOR (never through one) or under a solid that covers all of it.
    // Any other solid over part of it (the sign's clip over the base crate, a wall top's
    // clip over the bury) it simply overlaps - cutting the whole wedge flat under a partial
    // solid would leave a flat strip on top, the very thing the cap exists to remove.
    const foot = { x1: fx1, x2: fx2, y1: fy1, y2: fy2 };
    const above = over(fx1, fx2, fy1, fy2).filter(b => {
      const covers = b.lo[0] <= fx1 + 0.01 && b.hi[0] >= fx2 - 0.01 && b.lo[1] <= fy1 + 0.01 && b.hi[1] >= fy2 - 0.01;
      return (b.isDeck || b.isRamp || covers) && bottomOver(b, foot) >= zLip + 0.5;
    });
    let zCeil = Math.min(Infinity, ...above.map(b => q16(bottomOver(b, foot) - 0.5)));
    if (zCeil < zLip + 8) throw new Error(`${r.label}: only ${zCeil - zLip} of room above its lip - something sits on the prop`);
    const tris = [
      [P(u0, v1, zBot), P(uEnd, v1, zBot), P(uEnd, v2, zBot)],              // bottom
      [P(u0, v1, zBot), P(u0, v2, zBot), P(u0, v1, zLip)],                  // the low edge's lip
      [P(uEnd, v1, zBot), P(uEnd, v2, zBot), P(uEnd, v1, zBot + 64)],       // the buried back
      [P(u0, v1, zBot), P(uEnd, v1, zBot), P(u0, v1, zLip)],                // side
      [P(u0, v2, zBot), P(uEnd, v2, zBot), P(u0, v2, zLip)],                // side
      [P(u0, v1, zLip), P(u0, v2, zLip), P(uEnd, v1, zEnd)],                // THE SLOPE
    ];
    if (zCeil < zEnd) tris.push([P(u0, v1, zCeil), P(uEnd, v1, zCeil), P(uEnd, v2, zCeil)]);   // cut under the ceiling
    const uq = u0 + (uEnd - u0) * 0.25;
    const topQ = Math.min(zLip + PERCH_SLOPE * Math.abs(uq - u0), zCeil);
    perchBrush(r.label, tris, P(uq, vm, (zBot + topQ) / 2), PERCH_MAT);
    n++;
  }
  console.log(`perch caps: ${n} (${PERCH_REQ.filter(r => r.opts.column).length} free-standing columns), every wedge ${Math.round(Math.atan(PERCH_SLOPE) * 180 / Math.PI)} deg and buried ${PERCH_BURY} into the wall it backs`);
}
// a convex brush from point triples in any winding, oriented by an interior point (the
// crownPoly rule). Accounted in ALL_BOXES by its hull; never a crown/mast label.
function perchBrush(label, tris, inside, tex) {
  const planes = tris.map(v => {
    let q = CB.plane(v, tex);
    if (CB.dot(q.n, CB.sub(inside, v[0])) > 0) { v = [v[2], v[1], v[0]]; q = CB.plane(v, tex); }
    return q;
  });
  if (planes.some(q => CB.dot(q.n, inside) > q.d - 0.01)) throw new Error(`${label}: interior point is not inside its own brush`);
  const h = CB.hull(planes);
  addBox(label, h.x1, h.x2, h.y1, h.y2, h.z1, h.z2, tex);
  worldBrushes[worldBrushes.length - 1].text = ['{', ` guid "${guid()}"`, ...planes.map(q => rampPlane(q.v[0].map(r4), q.v[1].map(r4), q.v[2].map(r4), tex)), '}'].join('\n');
  return h;
}
function r4(v) { return Math.round(v * 10000) / 10000; }
emitPerchCaps();

// ---------------------------------------------------------------------------
// v19.71 THE PERCH SEAL — the generator runs the build gate's own perch model
// (tools/perch_core.js, the same code tools/lint_tod_perches.js runs on the finished .map)
// over every brush it is about to write, and closes each perch it finds with a
// player-only box: raised PERCH_SEAL_RISE out of reach (more than the model's REACH_V above
// the old top, so out of reach of every floor below it), or sealed to the brush above it,
// whichever comes first. Re-run until the model finds nothing (a seal's own top is checked
// like any other brush). What it closes, measured on v19.70's map: the invisible rail caps
// (168 over the landing they guard, 68 on the spire hubs' W flights), the trial halls' fence
// / lamp / pillar / lintel tops, the lap-door lintels, the gallery caps, the hoop recess, the
// rocket wreck's body clip - 1,491 perch faces in 113 families.
// A seal only ever rises over a non-floor brush's own top; it stops under any floor above it.
// ---------------------------------------------------------------------------
function perchSeal() {
  const RISE = PERCH.DEFAULTS.REACH_V + 8;
  let total = 0;
  for (let pass = 1; ; pass++) {
    const { brushes, perches } = PERCH.analyze(worldBrushes.map(b => ({ label: b.label, planes: CB.readPlanes(b.text) })));
    if (!perches.length) {
      console.log(`perch seal: ${total} seal${total === 1 ? '' : 's'} in ${pass - 1} pass${pass === 2 ? '' : 'es'}; the perch model finds nothing left`);
      return;
    }
    if (pass > 4) throw new Error(`perch seal: ${perches.length} perch(es) left after 4 passes:\n  ` +
      perches.slice(0, 30).map(p => `${p.label} (${Math.round(p.x)},${Math.round(p.y)},${Math.round(p.z)}) ${Math.round(p.dz)} up`).join('\n  '));
    for (const p of perches) {
      const f = p.face, self = brushes[p.idx];
      const z1 = Math.floor(f.z1 * 16) / 16, zTop = Math.ceil(f.z2);
      const face = { x1: Math.floor(f.x1), x2: Math.ceil(f.x2), y1: Math.floor(f.y1), y2: Math.ceil(f.y2) };
      const overlaps = (b, r) => !(b.hi[0] <= r.x1 + 0.5 || b.lo[0] >= r.x2 - 0.5 || b.hi[1] <= r.y1 + 0.5 || b.lo[1] >= r.y2 - 0.5);
      const seal = (r, top) => {
        if (process.env.TOD_PERCH_DEBUG && p.label.includes(process.env.TOD_PERCH_DEBUG))
          console.log(`  [perch debug] pass ${pass} ${p.label} (${p.x},${p.y},${p.z}) ${p.dz} up -> x[${r.x1},${r.x2}] y[${r.y1},${r.y2}] z ${z1}..${top}`);
        if (top <= z1 + 0.5) return;   // a floor sits right on it: no headroom, no perch here
        addBox(`${p.label} perch seal`, r.x1, r.x2, r.y1, r.y2, z1, top, PERCH_MAT);
        total++;
      };
      // EVERY FLOOR ABOVE THE LEDGE, lowest first: the part of the ledge under each floor is
      // filled to that floor's underside (never through it), and only what no floor covers
      // rises out of reach. A ledge under a staircase becomes a stair of seals in ONE pass
      // instead of one tread a pass.
      const floorsAbove = brushes
        .filter(b => b !== self && (b.isDeck || b.isRamp) && b.hi[2] >= f.z2 && overlaps(b, face))
        .map(b => ({ b, bot: bottomOver(b, face) }))
        .filter(o => o.bot >= f.z2 - 0.01 && o.bot < zTop + RISE)
        .sort((a, b) => a.bot - b.bot);
      let rest = [face];
      for (const { b } of floorsAbove) {
        const hb = { x1: b.lo[0], x2: b.hi[0], y1: b.lo[1], y2: b.hi[1] };
        const next = [];
        for (const r of rest) {
          if (!overlaps(b, r)) { next.push(r); continue; }
          const i = { x1: Math.max(r.x1, Math.ceil(hb.x1)), x2: Math.min(r.x2, Math.floor(hb.x2)), y1: Math.max(r.y1, Math.ceil(hb.y1)), y2: Math.min(r.y2, Math.floor(hb.y2)) };
          if (i.x2 - i.x1 >= 1 && i.y2 - i.y1 >= 1) seal(i, Math.floor(bottomOver(b, i) * 16) / 16);
          next.push(...rectMinus(r, hb));
        }
        rest = next;
      }
      // what no floor covers: out of reach, or up to a solid that covers all of it
      for (const r of rest) {
        let top = zTop + RISE;
        for (const b of brushes) {
          if (b === self || !overlaps(b, r)) continue;
          const covers = b.lo[0] <= r.x1 + 0.01 && b.hi[0] >= r.x2 - 0.01 && b.lo[1] <= r.y1 + 0.01 && b.hi[1] >= r.y2 - 0.01;
          if (!covers) continue;
          const bot = bottomOver(b, r);
          if (bot >= f.z2 - 0.01) top = Math.min(top, Math.floor(bot * 16) / 16);
        }
        seal(r, top);
      }
    }
  }
}
// the lowest point of brush b's underside over rectangle r (its hull's for a box; sampled at
// the overlap's corners and centre for a sloped one - a stair ramp's hull bottom is the foot
// of the whole flight, 100+ below its underside over any one ledge)
function bottomOver(b, r) {
  if (b.axial) return b.lo[2];
  const x1 = Math.max(r.x1, b.lo[0]), x2 = Math.min(r.x2, b.hi[0]), y1 = Math.max(r.y1, b.lo[1]), y2 = Math.min(r.y2, b.hi[1]);
  let lo = Infinity;
  for (const x of [x1 + 0.01, (x1 + x2) / 2, x2 - 0.01]) for (const y of [y1 + 0.01, (y1 + y2) / 2, y2 - 0.01]) {
    const sp = CB.verticalSpan(b.planes, x, y);
    if (sp) lo = Math.min(lo, sp[0]);
  }
  return lo === Infinity ? b.lo[2] : lo;
}
// r minus h, both { x1, x2, y1, y2 }: up to four rectangles (none thinner than 1)
function rectMinus(r, h) {
  if (h.x2 <= r.x1 || h.x1 >= r.x2 || h.y2 <= r.y1 || h.y1 >= r.y2) return [r];
  const out = [];
  if (h.x1 > r.x1) out.push({ x1: r.x1, x2: Math.floor(h.x1), y1: r.y1, y2: r.y2 });
  if (h.x2 < r.x2) out.push({ x1: Math.ceil(h.x2), x2: r.x2, y1: r.y1, y2: r.y2 });
  const ix1 = Math.max(r.x1, Math.floor(h.x1)), ix2 = Math.min(r.x2, Math.ceil(h.x2));
  if (h.y1 > r.y1) out.push({ x1: ix1, x2: ix2, y1: r.y1, y2: Math.floor(h.y1) });
  if (h.y2 < r.y2) out.push({ x1: ix1, x2: ix2, y1: Math.ceil(h.y2), y2: r.y2 });
  return out.filter(q => q.x2 - q.x1 >= 1 && q.y2 - q.y1 >= 1);
}
perchSeal();
// the caps and seals are new solids: the breather respawns must still stand clear of every one
checkBreatherSpawns();

// ---------------------------------------------------------------------------
// Output: the .map
// ---------------------------------------------------------------------------
const out = [];
out.push('iwmap 4');
out.push('"script_startingnumber" 0');
out.push('"000_Global" flags expanded  active');
out.push('"000_Global/No Comp" flags hidden ignore ');
out.push('"The Map" flags expanded ');
out.push('// entity 0');
out.push('{');
out.push(`guid "${guid()}"`);
out.push(kv('classname', 'worldspawn'));
out.push(kv('lightingquality', '1024'));
out.push(kv('samplescale', '1'));
out.push(kv('skyboxmodel', SKYBOX_MODEL));
out.push(kv('ssi', SSI));
out.push(kv('wsi', 'default_night'));
// ⚠️ THIS LINE IS WHY THE MAP NEVER RENDERED FOG (v14.41, root cause).
// `fsi` is the FOG SETTINGS asset, baked into the BSP from worldspawn like the
// ssi. We shipped `default`, and <modtools>/source_data/fog.gdt's "default"
// entry carries **"fogopacity" "0"** — the fog system was CLAMPED OFF at the
// asset level, so every SetVolFog call in _tod_atmosphere set colour and
// distances on a fog that could never draw. User confirmed live: "Yes this map
// has never rendered fog."
// `zm_factory_volumetric` is stock zm_factory's own volumetric entry —
// "fogopacity" "1", i.e. the full range available — and is therefore a
// SHIPPED, PROVEN-IN-A-REAL-ZM-MAP fog asset rather than something authored
// here. Everything else in it is ordinary (fogintensity 1, sane
// maxlit*fogdistance); script owns colour/distance/height at runtime.
// NO ZONE LINE IS NEEDED: fog settings ride in via the worldspawn/BSP, exactly
// like the ssi (verified — there is no `fog,` asset type in any stock .zone).
// If fog ever reads too heavy at range, `zm_factory_afog` (fogopacity 0.5) is
// the gentler proven alternative; change it HERE, it is a full build.
// `fsi` STAYS `default` — v14.41 changed it to zm_factory_volumetric on the
// theory that "default" carrying fogopacity 0 was why this map never rendered
// fog. THAT THEORY IS DEAD: map 1 (abandoned_cyber_city) renders fog fine with
// `fsi "default"`, and so does stock zm_giant. The fsi was never the problem;
// the problem was that _tod_atmosphere called SetVolFog twice and stopped,
// while map 1 runs a PERSISTENT re-assert loop it calls "the single fog
// authority" — its own comments record a one-shot call as the original "no
// haze" bug. Reverted rather than left changed, so this map matches the two
// working references instead of deviating from both.
// v14.43 — `zm_factory_volumetric` as a DELIBERATE HEDGE, not a theory.
// Two explanations for SetVolFog's 8th arg are still live and I cannot settle
// them from here: the API doc says <transition time>, but MAP 1 passes an
// opacity there and its fog renders. This asset covers BOTH:
//   - if arg 8 IS opacity, an fsi with fogopacity 1 is simply a permissive
//     ceiling and changes nothing about our 0.90;
//   - if arg 8 is a TRANSITION TIME, then opacity can only come from the fsi,
//     and `default` (fogopacity 0) would clamp the fog off no matter what.
// zm_factory_volumetric is stock zm_factory's own entry (fogopacity 1), so it
// is shipped-and-proven rather than authored here. Costs nothing under either
// theory. NOTE map 1 and zm_giant both render fog on `default`, so this is NOT
// claimed as the root cause — it is insurance while the real one is confirmed.
// v17.75 (2026-09-05, user: "Still yellow ... maybe its fog"): zm_factory_volumetric carries litfog 1 +
// sunintensityscale 2 + an orange haze — SUN-LIT FOG, which the 8-arg SetVolFog in fog_off() cannot
// switch off (it only moves distances/colour). That was the olive wash, the light shafts and the
// yellow strip on the core; Miami'"'"'s warm horizon hid it, the purple sky exposed it. tod_fsi_cybercity
// (source_data/tod_skybox.gdt) is that asset with the sun-lit lane OFF and fogopacity 1 kept for the
// spire'"'"'s red fog. Rides in via worldspawn like the ssi — no zone line.
// v17.78: zm_factory_volumetric again — the v17.70 value — for the Miami A/B screenshot (the user
// asked for every yellow-hunt change reverted). tod_fsi_cybercity stays in the GDT, unreferenced.
out.push(kv('fsi', 'zm_factory_volumetric'));
out.push(kv('gravity', '800'));
out.push(kv('lodbias', 'default'));
out.push(kv('lutmaterial', 'luts_t7_default'));
out.push(kv('numOmniShadowSlices', '24'));
out.push(kv('numSpotShadowSlices', '64'));
out.push(kv('sky_intensity_factor0', '1'));
out.push(kv('sky_intensity_factor1', '1'));
out.push(kv('state_alias_1', 'State 1'));
out.push(kv('state_alias_2', 'State 2'));
out.push(kv('state_alias_3', 'State 3'));
out.push(kv('state_alias_4', 'State 4'));
worldBrushes.forEach((b, i) => {
  out.push(`// brush ${i} — ${b.label}`);
  out.push(b.text);
});
out.push('}');
entities.forEach((e, i) => {
  out.push(`// entity ${i + 1} — ${e.label}`);
  out.push(e.text);
});
out.push('');

fs.mkdirSync(path.dirname(MAP_OUT), { recursive: true });
fs.writeFileSync(MAP_OUT, out.join('\n'), 'utf8');
console.log(`wrote ${MAP_OUT}  (${worldBrushes.length} world brushes, ${entities.length} entities, ${LAPS} laps, top z=${TOP})`);
// The causeway reports itself because it is the one structure whose shape is
// DERIVED rather than written down — read these numbers here rather than
// trusting any figure copied into a doc or a session brief.
console.log(`  causeway: ${CW_STATS.columns} deck columns, ${CW_STATS.edges} exposed edges guarded by ` +
            `${CW_STATS.rails} rails, ${roadPieces.length} pieces, ` +
            `x[${CW_XMIN},${CW_XMAX}] z[${CW_ZMIN},${CW_ZMAX}], walked length ~${CW_WALK} units`);

// ---------------------------------------------------------------------------
// Output: _tod_door_data.gsc
// ---------------------------------------------------------------------------
const g = [];
g.push('// GENERATED by tools/gen_tower_map.js — DO NOT HAND-EDIT (regen instead).');
g.push('// Door buy-trigger positions for _tod_doors.gsc. A map brush entity has no');
g.push('// usable .origin (reports 0,0,0), so the generator hardcodes each doorway');
g.push("// center + its thin-axis offset here from the same tables that cut the .map.");
g.push('');
g.push('#namespace tod_door_data;');
g.push('');
g.push('function get_door_info( flag )');
g.push('{');
g.push('\tinfo = SpawnStruct();');
g.push('\tswitch ( flag )');
g.push('\t{');
for (const d of DOORS) {
  g.push(`\tcase "${d.flag}":`);
  g.push(`\t\tinfo.org = ( ${d.org.join(', ')} );`);
  g.push(`\t\tinfo.off = ( ${d.off.join(', ')} );`);
  g.push(`\t\tinfo.dest = "${d.dest}";`);
  g.push(`\t\tinfo.cost = ${d.cost};`);   // v9.41: the price lives here too (wins over the BSP's zombie_cost)
  g.push('\t\treturn info;');
}
g.push('\t}');
g.push('\treturn undefined;');
g.push('}');
g.push('');

fs.mkdirSync(path.dirname(DOOR_GSC_OUT), { recursive: true });
fs.writeFileSync(DOOR_GSC_OUT, g.join('\n'), 'utf8');
console.log(`wrote ${DOOR_GSC_OUT}  (${DOORS.length} doors)`);

// ---------------------------------------------------------------------------
// Output: _tod_crown_data.gsc — the finale's anchor points (v9)
// ---------------------------------------------------------------------------
// Everything _tod_finale.gsc and the crown upgrade terminal need to place
// themselves, in the SAME mirrored frame the brushes were cut in. Vectors are
// emitted pre-mirrored, so the GSC never has to know about parity.
const vec = ([x, y, z]) => `( ${x}, ${y}, ${z} )`;
const SCONCES = [];
{
  // v16.35 THE BASILICA: the same twelve sconces (six a side, +200, the
  // acceptance sequence still walks them gate -> pad), re-spaced to clear the
  // shrine bays — pilasters at HYC+-112..+-144 and a canopy at +216..+248 sit
  // exactly where the old 208-pitch put rows 3 and 4. Symmetric about HYC,
  // ascending y so the ignition order is unchanged.
  for (const d of [-560, -372, -188, 188, 372, 560]) {
    const y = HYC + d;
    SCONCES.push({ org: cpt(-HW + HWALL + 2, y, TOP2 + 200), yaw: cyaw(0) });
    SCONCES.push({ org: cpt(HW - HWALL - 2, y, TOP2 + 200), yaw: cyaw(180) });
  }
}
const c = [];
c.push('// GENERATED by tools/gen_tower_map.js — DO NOT HAND-EDIT (regen instead).');
c.push('// Anchor points for the CROWN finale (_tod_finale.gsc) and the crown');
c.push('// upgrade terminal (_tod_upgrades.gsc). Emitted from the same tables that');
c.push('// cut the crown brushes, already point-mirrored for the crown lap parity');
c.push(`// (LAPS=${LAPS}, crown lap ${CROWN_LAP} is ${CROWN_ODD ? 'ODD: east stair, north hall' : 'EVEN: west stair, south hall'}).`);
c.push('');
c.push('#namespace tod_crown_data;');
c.push('');
c.push(`function crown_z()         { return ${TOP2}; }`);
// THE UPLINK MOVED TO THE TERRACE (v10, 2026-08-23). The finale clock is the
// length of the closing song and the run is the road, so the console that
// starts it has to sit where the players ARRIVE, not at the far end of the
// thing they are about to run. Placed WEST of the causeway mouth (mouth is
// x +/-CW_HALF) so it never blocks the road, and facing the road.
c.push(`function uplink_org()      { return ${vec(cpt(-(CW_HALF + 96), (TER_Y1 + TER_Y2) / 2, TOP2))}; }`);
c.push(`function uplink_yaw()      { return ${cyaw(0)}; }`);
// the old hall-dais spot — kept as an anchor so the dais brush still has a
// named centre and a future boss fight has the hall's focal point.
c.push(`function dais_org()        { return ${vec(cpt(0, HYC, TOP2 + DAIS_H))}; }`);
// causeway portal frame centres, south -> north: the road's milestones.
c.push('function portal_orgs()');
c.push('{');
c.push('	a = [];');
(() => { causewayPortalPoints().forEach((o, k) => c.push('	a[ ' + k + ' ] = ' + vec(o) + ';')); })();
c.push('	return a;');
c.push('}');
// THE CAUSEWAY GATE: where it stands, and what counts as being past it.
// beyond_gate() is the spawn filter's test — while the gate is shut, the road
// and the citadel behind it are pathing-severed from the terrace, so a zombie
// risen out there can never reach anybody. It would just stand on the bridge
// holding a slot under the actor cap for the rest of the game. Un-mirrors y by
// CM so the test reads in the crown's own frame whichever parity the crown got.
c.push(`function causeway_gate_org() { return ${vec(cpt(0, TER_Y2 + 12, TOP2 + 128))}; }`);
c.push('function beyond_gate( org )');
c.push('{');
c.push(`	y = org[ 1 ] * ${CM};`);
c.push(`	return ( y > ${TER_Y2} && org[ 2 ] > ${CW_ZMIN} );`);
c.push('}');
// THE CROWN DOOR and the two containment tests the finale runs on.
//
// in_crown() IS THE WIN TEST and it is a BOX, not a radius. The old
// TOD_FINALE_ARRIVE_RAD 1536 sphere from the exfil pad reached ~284 units
// OUTSIDE the gate, so a player standing on the approach counted as "in the
// Crown" — fine when arriving was the whole win, wrong now that arriving is
// what SEALS THE DOOR ON YOU. This is the hall's actual interior: inside the
// four walls, above the floor, with a small inset so someone hugging a wall
// still reads as in.
//
// in_hall() is the same box widened to the gate line — used by the spawn filter
// during the hold-out so risers on the causeway are dropped once the party is
// sealed in (a zombie out there could never reach them and would hold an actor
// slot for the rest of the fight, the same trap beyond_gate() exists to stop).
c.push(`function crown_door_org()  { return ${vec(cpt(0, HS + HWALL / 2, TOP2 + GATE_H / 2))}; }`);
c.push('function in_crown( org )');
c.push('{');
c.push(`	y = org[ 1 ] * ${CM};`);
c.push(`	x = org[ 0 ] * ${CM};`);
c.push(`	if ( x < ${-(HW - HWALL - 8)} || x > ${HW - HWALL - 8} ) return false;`);
c.push(`	if ( y < ${HS + HWALL} || y > ${HN - HWALL} ) return false;`);
c.push(`	return ( org[ 2 ] > ${TOP2 - 64} && org[ 2 ] < ${TOP2 + 400} );`);
c.push('}');
c.push('function in_hall( org )');
c.push('{');
c.push(`	y = org[ 1 ] * ${CM};`);
c.push(`	x = org[ 0 ] * ${CM};`);
c.push(`	if ( x < ${-HW} || x > ${HW} ) return false;`);
c.push(`	if ( y < ${HS} || y > ${HN} ) return false;`);
c.push(`	return ( org[ 2 ] > ${TOP2 - 64} );`);
c.push('}');
// v16.35: the pad sits on the sanctuary — its top is TOP2 + PAD_TOP (section
// 5d), and the prop, the derez bursts and the +30 trigger all hang off this.
c.push(`function exfil_org()       { return ${vec(cpt(0, EXFIL_Y, TOP2 + PAD_TOP))}; }`);
c.push(`function exfil_radius()    { return ${EXFIL_HALF + 16}; }`);
c.push(`function hall_center()     { return ${vec(cpt(0, HYC, TOP2))}; }`);
// THE ROCKETS (docs/170, _tod_rocket.gsc): where each ship stands, its prompt, the hull it measured, and every
// flight's keys (ship-pivot points + unit tangents). kind = "spire" | "extract".
{
  const g2 = v => `( ${rkR2(v).join(', ')} )`;
  const pick = (name, sig, f) => {
    c.push(`function ${name}( ${sig} )`);
    c.push('{');
    c.push(`\tif ( kind == "spire" ) return ${f('spire')};`);
    c.push(`\treturn ${f('extract')};`);
    c.push('}');
  };
  const arr = (name, key, field) => {
    c.push(`function ${name}( kind )`);
    c.push('{');
    c.push('\ta = [];');
    for (const k of ['spire', 'extract']) {
      c.push(`\tif ( kind == "${k}" )`);
      c.push('\t{');
      RK_FLIGHT[key(k)][field].forEach((v, i) => c.push(`\t\ta[ ${i} ] = ${g2(cpt(v[0], v[1], v[2]).map((x, j) => (field === 'tans' && j < 2) ? x * CM * CM : x))};`));
      c.push('\t\treturn a;');
      c.push('\t}');
    }
    c.push('\treturn a;');
    c.push('}');
  };
  c.push(`function rocket_enabled()   { return ${ROCKETS}; }`);
  c.push(`function rocket_len()       { return ${RK_LEN}; }`);
  c.push(`function rocket_feet_r()    { return ${RK_FEET_R}; }`);
  c.push(`function rocket_bell_x()    { return ${RK_BELL_X}; }`);
  c.push('function rocket_body_r()');
  c.push('{');
  c.push('\ta = [];');
  RK_BODY_R.forEach((r, i) => c.push(`\ta[ ${i} ] = ${r};`));
  c.push('\treturn a;');
  c.push('}');
  pick('rocket_org', 'kind', k => g2(cpt(...(k === 'spire' ? RK_SHIP_FEET : RK_EXIT_FEET))));
  pick('rocket_yaw', 'kind', k => `${cyaw(RK_YAW[k])}`);
  // v19.68t: the prompt RING (rkRing) - every open spot round the ship, spot 0 the nave side
  c.push('function rocket_trigs( kind )');
  c.push('{');
  c.push('\ta = [];');
  for (const k of ['spire', 'extract']) {
    c.push(`\tif ( kind == "${k}" )`);
    c.push('\t{');
    RK_RING[k].kept.forEach((s, i) => c.push(`\t\ta[ ${i} ] = ${g2(cpt(...s.p))};`));
    c.push('\t\treturn a;');
    c.push('\t}');
  }
  c.push('\treturn a;');
  c.push('}');
  c.push(`function rocket_trig_r()    { return ${RK_TRIG_R}; }`);
  c.push(`function rocket_trig_h()    { return ${RK_TRIG_H}; }`);
  pick('rocket_cam_right', 'kind', k => g2(rkCamRight(k)));
  c.push('function rocket_clip_target( kind ) { return "tod_rocket_clip_" + kind; }');
  arr('rocket_keys', k => k, 'keys');
  arr('rocket_tans', k => k, 'tans');
  arr('rocket_land_keys', k => 'land_' + k, 'keys');
  arr('rocket_land_tans', k => 'land_' + k, 'tans');
}
c.push(`function gate_org()        { return ${vec(cpt(0, HS + HWALL / 2, TOP2))}; }`);
c.push(`function mast_tip_org()    { return ( 0, 0, ${MAST_TOP} ); }`);
// THE CROWN UPGRADE STATION — STANDOFF 33 -> 64 (user live report 2026-08-28:
// "final boss room. Pap is inside the wall"). The machine is the
// `chaos_pack_a_punch` mesh (it is the UPGRADE STATION, not a Pack-a-Punch —
// the map has no PaP prefab at all), and it was the tightest-placed of the
// six stations by a wide margin:
//     base station      64u off the core's south face   (model 0,-320 vs CORE 256)
//     breather lounges  44u off the lounge's N wall     (BR_FURN, v13)
//     crown hall        33u off the hall's W wall       <<< the reported one
// The hall's west wall inner face is x = -HW + HWALL = -728, so 33 put the
// origin at -695. 64 matches the BASE station, which is the longest-shipped
// placement of this exact model and has never been reported.
//
// WHY 64 AND NOT A MEASURED NUMBER, STATED HONESTLY: the width profile of this
// mesh is measured (see the long note in _tod_upgrades::station_place — 957,902
// vertex records binned by height, +-52 at the chest-height flare), but that
// pass recorded DEPTH only as a single "53" and never established whether the
// origin sits at the mesh's centre or its front face. If it is centred, 33
// should have cleared by ~6u and something else is wrong; if the body hangs
// backward from the origin, 33 buries it and 64 fixes it. The report says it is
// buried, and 64 is the standoff already proven on the same asset, so this
// takes the proven number rather than a derived one. If it is STILL in the wall
// after this, the origin is not the issue and the next step is to actually
// measure the depth axis off chaos_pack_a_punch.xmodel_bin (LZ4-wrapped; the
// width pass is the recipe) rather than nudging it again.
//
// v16.35 THE BASILICA: the altar moves 300u north to the WEST SHRINE at the
// crossing (y = HYC), facing the Pack-a-Punch in the east shrine across the
// dais. Standoff 64 unchanged. Its bay (pilasters at HYC+-112..+-144, glow
// panel, canopy +216) is cut in section 5d.
// CLEARANCES at the new spot (the trigger keeps its 40u face offset and floats
// +32 since v16.27):
//   trigger (-624, HYC) r64 -> pilaster faces at y HYC+-112: 48u clear;
//     nearest pier base (W3/W4 at y HYC-+184) starts at x -440: 184u clear
//   3 collision clips spread +-32 along AnglesToForward (= +-y at yaw 90),
//     so they move with the model and stay between the pilasters
//   the transept seam under its approach is 1u walk-over
// v19.71 (the perch pass): FLUSH, 64 -> CROWN_VENDOR_OFF (24) off the wall: the altar stood
// 45 off the shrine panel - a player-wide slot behind it. The trigger keeps its 40 in front.
c.push(`function station_org()     { return ${vec(cpt(-HW + HWALL + CROWN_VENDOR_OFF, HYC, TOP2))}; }`);
c.push(`function station_trig_org(){ return ${vec(cpt(-HW + HWALL + CROWN_VENDOR_OFF + 40, HYC, TOP2))}; }`);
c.push(`function station_yaw()     { return ${cyaw(90)}; }`);
c.push('');
c.push('// THE HALL AMMO CRATE (v12) — spawned by _tod_ammo_crate.gsc, which reads');
c.push('// these instead of hardcoding, so the crate and its generator-emitted');
c.push('// collision clip (label "crown hall ammo crate body") can never drift.');
c.push(`function crown_crate_org() { return ${vec(cpt(CRATE_ORG[0], CRATE_ORG[1], TOP2))}; }`);
c.push(`function crown_crate_yaw() { return ${cyaw(CRATE_YAW)}; }`);
c.push('');
c.push('// The finale\'s four QUARTER-PROGRESS beacons — one ignites per quarter of');
c.push('// the closing song (_tod_finale::ignite_pylon). These are the CIRCLET\'s');
c.push('// four corner point caps, NOT anything in the hall: v11 moved the read up');
c.push('// there when the user rejected the old in-room coil models ("weird looking');
c.push('// pipe level model on top"). NOTE v12: the four bare PILLARS returned to');
c.push('// the hall at their old +-448 spots — as pure scenery/cover with NO script');
c.push('// contract. Do not point these beacons back at them; the progress read is');
c.push('// the crown lighting up around you — legible from inside the hall, from');
c.push('// the causeway, and from the tower. The function name is unchanged on');
c.push('// purpose: _tod_finale.gsc needed a model swap, not a rewrite.');
c.push('function pylon_orgs()');
c.push('{');
c.push('\ta = [];');
CROWN_BEACON_XY.forEach(([bx, by], i) => {
  c.push(`\ta[ ${i} ] = ${vec(cpt(bx, by, TOP2 + CROWN_BEACON_Z))};`);
});
c.push('\treturn a;');
c.push('}');
c.push('');
c.push('// wall sconces (light panels) on the two long walls — parallel arrays');
c.push('function sconce_orgs()');
c.push('{');
c.push('\ta = [];');
SCONCES.forEach((s, i) => c.push(`\ta[ ${i} ] = ${vec(s.org)};`));
c.push('\treturn a;');
c.push('}');
c.push('function sconce_yaws()');
c.push('{');
c.push('\ta = [];');
SCONCES.forEach((s, i) => c.push(`\ta[ ${i} ] = ${s.yaw};`));
c.push('\treturn a;');
c.push('}');
c.push('');
// ---------------------------------------------------------------------------
// THE FINALE BEAT SYSTEM (v12.13, docs/41: A1 tide + A2 boss beats + A4
// arrival + riders + B1 lane lottery). Every anchor below is derived from the
// same cwY/lane tables that cut the road, so script and geometry cannot drift.
// ---------------------------------------------------------------------------
c.push('// --- THE FINALE BEAT SYSTEM (v12.13, docs/41) — road-derived anchors -----');
c.push('// road_y: the mirrored y — compare against tide/beat y thresholds with THIS,');
c.push('// never with raw org[1] (the crown lap parity flips the whole road).');
c.push(`function road_y( org )     { return org[ 1 ] * ${CM}; }`);
c.push('// (tide_start_y/tide_end_y/road_north_yaw/tide_curtain_orgs were emitted');
c.push('// here for exactly one day — THE DEREZ TIDE, added and removed 2026-08-27;');
c.push('// post-mortem at the top of _tod_finale.gsc\'s beat table.)');
c.push('// BOSS BEATS (A2): the Panzer lands at the NARROWS north lip (80 past the');
c.push('// pinch exit, on full-width throat deck — fightable from the 320 throat);');
c.push('// two protectors land on the gate APPROACH as the leader crosses J4.');
c.push(`function beat_narrows_org()        { return ${vec(cpt(0, cwY[4] + 560, TOP2))}; }`);
c.push(`function beat_narrows_trigger_y()  { return ${cwY[4]}; }   // leader entering the throat`);
c.push('function beat_flare_orgs()');
c.push('{');
c.push('\ta = [];');
// ±60 on the 160-wide approach and 140 short of the mouth (review FIX 3,
// 2026-08-27): the first cut sat at ±100/y7600 — INSIDE the derived rail
// column over the void, where SpawnActor eats half the boss roof for nothing.
c.push(`\ta[ 0 ] = ${vec(cpt(-60, cwY[9] - 140, TOP2))};`);
c.push(`\ta[ 1 ] = ${vec(cpt(60, cwY[9] - 140, TOP2))};`);
c.push('\treturn a;');
c.push('}');
c.push(`function beat_flare_trigger_y()    { return ${cwY[7]}; }   // leader crossing J4`);
c.push('// A4: the hold-out opener Panzer crashes into the hall here — on open nave');
c.push('// floor: 317u from hall_center (gather ring 160), 92u short of the');
c.push('// sanctuary foot, 136u inside the east pier line (v16.35 basilica).');
c.push(`function siege_panzer_org()        { return ${vec(cpt(192, HYC + 252, TOP2))}; }`);
c.push('// THE CROWN\'S HEARTBEAT rider: the girandole — same coordinate as its');
c.push('// baked light (the ruby drop-pendant under the vortex bell).');
c.push(`function girandole_org()           { return ${vec(cpt(0, CR_CY - CS(480), TOP2 + CR_SKIRT_BOT - CS(480)))}; }`);
c.push('// THE COUNTDOWN AVENUE (A1): glow hosts on the 8 avenue pylon PIPS (pip');
c.push('// body spans +496..+576 over the deck; host at its centre) — ignited blue');
c.push('// at the buy, strobed green on the win (the tide-era red flip is gone).');
c.push('function avenue_pylon_orgs()');
c.push('{');
c.push('\ta = [];');
(() => {
  let k = 0;
  for (const py of [640, 960, 3792, 4208])
    for (const sx of [-1, 1])
      c.push(`\ta[ ${k++} ] = ${vec(cpt(sx * 360, py, TOP2 + 536))};`);
})();
c.push('\treturn a;');
c.push('}');
c.push('// A4 pillar count-in hosts: the FOUR CROSSING PIERS of the basilica');
c.push('// (v16.35), 16u above the beam top (+216) and well under the +260 lights.');
c.push('function hall_pillar_orgs()');
c.push('{');
c.push('\ta = [];');
(() => {
  [[-1, -1], [1, -1], [-1, 1], [1, 1]].forEach(([sx, sy], i) => {
    c.push(`\ta[ ${i} ] = ${vec(cpt(sx * NAVE_X, HYC + sy * 184, BEAM_Z2 + 16))};`);
  });
})();
c.push('\treturn a;');
c.push('}');
c.push('// THE LANE LOTTERY (B1). Parallel arrays, index = tod_lane_seal_<i>:');
c.push('//   0 f1 W ridge | 1 f1 E broken stair | 2 f2 W undercroft | 3 f2 C plank | 4 f2 E weave');
c.push('// seal_orgs: slab centres (FX anchors). slab/band mins+maxs: WORLD-space');
c.push('// AABBs (pre-mirrored — test raw org x/y against them, no road_y). The');
c.push('// BAND is the whole lane footprint fork->merge, for the riser filter.');
(() => {
  const mb = (x1, x2, y1, y2) => (CM === 1 ? [x1, x2, y1, y2] : [-x2, -x1, -y2, -y1]);
  const seals = [
    [LX[0], LX[1], cwY[2]], [EX[0], EX[1], cwY[2]],
    [LX[0], LX[1], cwY[6]], [PX_[0], PX_[1], cwY[6]], [EX[0], EX[1], cwY[6]],
  ];
  const bands = [
    // bstair is EX-only (review FIX 6 — the EW copy-paste came from the weave
    // row; the ridge legitimately spans LW..LX and the weave EX..EW)
    [LW[0], LX[1], cwY[2], cwY[3]], [EX[0], EX[1], cwY[2], cwY[3]],
    [LW[0], LX[1], cwY[6], cwY[7]], [PX_[0], PX_[1], cwY[6], cwY[7]], [EX[0], EW[1], cwY[6], cwY[7]],
  ];
  c.push('function lane_seal_orgs()');
  c.push('{');
  c.push('\ta = [];');
  seals.forEach(([x1, x2, y], i) =>
    c.push(`\ta[ ${i} ] = ${vec(cpt((x1 + x2) / 2, y + 12, TOP2 + 128))};`));
  c.push('\treturn a;');
  c.push('}');
  const emitMM = (name, rows, lo) => {
    c.push(`function ${name}()`);
    c.push('{');
    c.push('\ta = [];');
    rows.forEach((r, i) => {
      const m = mb(r[0], r[1], r[2], r[3]);
      c.push(`\ta[ ${i} ] = ( ${lo ? m[0] : m[1]}, ${lo ? m[2] : m[3]}, 0 );`);
    });
    c.push('\treturn a;');
    c.push('}');
  };
  const slabs = seals.map(([x1, x2, y]) => [x1, x2, y, y + 24]);
  emitMM('lane_seal_slab_mins', slabs, true);
  emitMM('lane_seal_slab_maxs', slabs, false);
  emitMM('lane_band_mins', bands, true);
  emitMM('lane_band_maxs', bands, false);
})();
c.push('');
fs.writeFileSync(CROWN_GSC_OUT, c.join('\n'), 'utf8');
console.log(`wrote ${CROWN_GSC_OUT}  (crown lap ${CROWN_LAP}, CM=${CM}, TOP2=${TOP2}, mast top=${MAST_TOP})`);

// ---------------------------------------------------------------------------
// Output: _tod_breather_data.gsc — the lounge furniture anchors (v13)
// ---------------------------------------------------------------------------
// _tod_powerups (PaP), _tod_upgrades (station), _tod_ammo_crate (crate) and
// _tod_teleport (spur pad + up-ride arrival) read these instead of hardcoding,
// so the room, the crate's generator-emitted collision clip and the four
// scripts can never drift — the same contract as _tod_door_data /
// _tod_crown_data. All values are in the EVEN (mirrored) frame every breather
// sits in (asserted at BREATHER_THEME). _tod_perk_scatter deliberately keeps
// its own pad table (its machines relocate at runtime); the S-wall pads are
// mirrored into BR_FURN for the spacing assert only.
{
  const bd = [];
  bd.push('// GENERATED by tools/gen_tower_map.js — DO NOT HAND-EDIT (regen instead).');
  bd.push('// v13 breather-lounge furniture anchors. Source of truth: the BR_FURN table');
  bd.push('// in the generator, which asserts every pair of use-triggers clears by');
  bd.push(`// radius_a + radius_b + ${MIN_TRIG_GAP} at generation time — the mechanical form of the`);
  bd.push('// v10.4 rule, added after the shipped PaP/crate pair sat 174u apart with a');
  bd.push('// 38u rim gap and players bought the wrong 5000-point thing.');
  bd.push('// Frame: EVEN/mirrored (all four breathers). z = the lounge mid-slab top.');
  bd.push('');
  bd.push('#namespace tod_breather_data;');
  bd.push('');
  bd.push('// mid-slab z of each breather lounge, ascending (laps 10/20/30/40)');
  const BRZS = [...BREATHER_LAPS].sort((a, b2) => a - b2).map(l => (l - 1) * LAP_RISE + FLIGHT_RISE);
  bd.push(`function breather_zs() { return array( ${BRZS.join(', ')} ); }`);
  bd.push('');
  bd.push('// Shared room detection for the arrival chime and spawn-pressure relief.');
  bd.push('function lounge_index_at( o )');
  bd.push('{');
  bd.push('    zs = breather_zs();');
  bd.push('    for ( j = 0; j < zs.size; j++ )');
  bd.push('    {');
  bd.push('        if ( o[ 2 ] < zs[ j ] - 64 || o[ 2 ] > zs[ j ] + 256 ) continue;');
  bd.push('        if ( o[ 0 ] >= -900 && o[ 0 ] <= -200 && o[ 1 ] >= -1550 && o[ 1 ] <= -400 ) return j;');
  bd.push('    }');
  bd.push('    return -1;');
  bd.push('}');
  const bfun = (name, [x, y]) => bd.push(`function ${name}( z ) { return ( ${x}, ${y}, z ); }`);
  bd.push('');
  bd.push('// PACK-A-PUNCH — W wall, facing east into the room');
  bfun('pap_org', BR_FURN.pap.org);
  bfun('pap_trig', BR_FURN.pap.trig);
  bd.push(`function pap_yaw() { return ${BR_FURN.pap.yaw}; }`);
  bd.push('');
  bd.push('// UPGRADE STATION — N wall (entrance side), facing south into the room');
  bfun('station_org', BR_FURN.station.org);
  bfun('station_trig', BR_FURN.station.trig);
  bd.push(`function station_yaw() { return ${BR_FURN.station.yaw}; }`);
  bd.push('');
  bd.push('// AMMO CRATE — E wall, facing west (its collision clip in the .map is cut');
  bd.push('// from this same origin: label "ammo crate body", lint MODEL_CLIP_COLUMNS)');
  bfun('crate_org', BR_FURN.crate.org);
  bd.push(`function crate_yaw() { return ${BR_FURN.crate.yaw}; }`);
  bd.push('');
  bd.push('// THE CRATE TRIGGER RECIPE (v17.38; re-centred 2026-09-24) — read by');
  bd.push('// _tod_ammo_crate::spawn_trigger for EVERY crate in the map (tower and spire):');
  bd.push('// the trigger_radius_use sits crate_trig_out() in FRONT of the crate origin');
  bd.push('// (front = yaw + 90) and crate_trig_lat() along the front turned +90 (the clip');
  bd.push('// box\'s own centre line), crate_trig_lift() up (above the clip top, so a standing');
  bd.push('// player\'s sight line clears the crate from its long sides), with this radius.');
  bd.push('// The generator asserts the same numbers against every other vendor trigger in');
  bd.push('// the lounges and the hub halls, so they live here, once.');
  bd.push(`function crate_trig_out()  { return ${CRATE_TRIG_OUT}; }`);
  bd.push(`function crate_trig_lat()  { return ${CRATE_TRIG_LAT}; }`);
  bd.push(`function crate_trig_lift() { return ${CRATE_TRIG_LIFT}; }`);
  bd.push(`function crate_trig_r()    { return ${CRATE_TRIG_R}; }`);
  bd.push('');
  bd.push('// BASE AMMO CRATE — core WEST face at the base arena, ABSOLUTE coords (no');
  bd.push('// mirror frame; the base is authored absolute). v14.3: origin lives in the');
  bd.push('// generator (BASE_CRATE), which also cuts its "base ammo crate body" clip');
  bd.push('// brush and asserts it clear of the lap-1 E flight — the Workshop navmesh');
  bd.push('// report (Pinkbrotha4310 2026-08-30) is the reason this rides the no-drift');
  bd.push('// contract instead of a hand-typed GSC literal.');
  bd.push(`function base_crate_org() { return ( ${BASE_CRATE.org[0]}, ${BASE_CRATE.org[1]}, 0 ); }`);
  bd.push(`function base_crate_yaw() { return ${BASE_CRATE.yaw}; }`);
  bd.push('');
  bd.push('// THE BASE UPGRADE STATION (v19.71) — the Heavenly Gift Altar, flush against the');
  bd.push('// core\'s south face (BASE_STATION in the generator, which also emits its perch cap).');
  bd.push('// _tod_upgrades.gsc station_spawn reads these; it hand-typed (0,-320) until v19.71.');
  bd.push(`function base_station_org() { return ( ${BASE_STATION.org[0]}, ${BASE_STATION.org[1]}, 0 ); }`);
  bd.push(`function base_station_trig() { return ( ${BASE_STATION.trig[0]}, ${BASE_STATION.trig[1]}, 0 ); }`);
  bd.push(`function base_station_yaw() { return ${BASE_STATION.yaw}; }`);
  bd.push('');
  bd.push('// THE CYBERCITY SIGN (v19.69) — Nikolai\'s neon sign on the core WEST face, over');
  bd.push('// the spawn band. The anchor is the model\'s back plane / horizontal centre /');
  bd.push('// bottom edge, 0.5 proud of the face; the generator (BASE_SIGN) asserts it clear');
  bd.push('// of the lap-2 W flight, the base ammo chest and the face\'s corners from the');
  bd.push('// model\'s measured size. _tod_base_sign.gsc reads both.');
  bd.push(`function base_sign_org() { return ( ${-(CORE + BASE_SIGN.proud)}, ${BASE_SIGN.y}, ${BASE_SIGN.z1} ); }`);
  bd.push(`function base_sign_yaw() { return ${BASE_SIGN.yaw}; }`);
  bd.push('');
  bd.push('// THE POWER TERMINAL (v19.69) — Nikolai\'s Grid Terminal V5 on the power hall\'s');
  bd.push('// east end wall, replacing the stock lever. The anchor is the model\'s back plane /');
  bd.push('// horizontal centre / floor, 0.5 proud of the wall; the generator (POWER_TERM)');
  bd.push('// emits its clip, the stock switch trigger / handle / fx struct and asserts it');
  bd.push('// clear of the hall walls, the song-hunt bear and the POWER word. Read by');
  bd.push('// _tod_power_terminal.gsc.');
  bd.push(`function base_power_terminal_org() { return ( ${POWER_TERM.wall - POWER_TERM.proud}, ${POWER_TERM.y}, 0 ); }`);
  bd.push(`function base_power_terminal_yaw() { return ${POWER_TERM.yaw}; }`);
  bd.push('');
  bd.push('// THE RAMPAGE INDUCER (v18.99g) — the BO6 aether canister on its cyan');
  bd.push('// pedestal against the base arena south wall, across from Quick Revive.');
  bd.push('// _tod_rampage.gsc reads all three; the generator cuts the pedestal brush');
  bd.push('// ("base inducer plinth") from the same constants and ASSERTS the trigger');
  bd.push('// origin is outside it, because a use-trigger whose origin is inside a');
  bd.push('// solid never prompts — which is exactly how v18.99f shipped dead.');
  bd.push(`function base_inducer_org()  { return ( ${INDUCER_ORG[0]}, ${INDUCER_ORG[1]}, ${INDUCER_PLINTH_H} ); }`);
  bd.push(`function base_inducer_trig() { return ( ${INDUCER_TRIG[0]}, ${INDUCER_TRIG[1]}, 0 ); }`);
  bd.push(`function base_inducer_yaw()  { return ${INDUCER_YAW}; }`);
  bd.push(`function base_inducer_trig_r() { return ${INDUCER_TRIG_R}; }`);
  bd.push('// 2026-10-02: the trigger rides above the body clip (INDUCER_CLIP_H) - read this,');
  bd.push('// never a script literal, so the two heights cannot drift.');
  bd.push(`function base_inducer_trig_lift() { return ${INDUCER_TRIG_LIFT}; }`);
  bd.push('');
  bd.push('// THE HOOP (v19.18) — the bat target cut into the core south face above the');
  bd.push('// base upgrade station. _tod_corpse_cleanup::hoop_watch scores a flung body');
  bd.push('// whose spine enters this box; the generator cut the recess and rim from the');
  bd.push('// same numbers, so the target the player sees IS the volume the script tests.');
  bd.push('// lo.y includes the rim standoff so a body entering the mouth counts.');
  bd.push(`function base_hoop_lo() { return ( ${HOOP.x1}, ${HOOP.y1 - HOOP_RIM_OUT}, ${HOOP.z1} ); }`);
  bd.push(`function base_hoop_hi() { return ( ${HOOP.x2}, ${HOOP.y2}, ${HOOP.z2} ); }`);
  bd.push('');
  bd.push('// TELEPORTER — the pad out on the spur platform, and where up-riders land');
  bd.push(`// (${TP_ARRIVE_OFF}u up the gantry toward the room: outside the pad's ${TP_GATHER}u gather,`);
  bd.push('// so an arrival is never swept along by the next departure — v10.4 rule)');
  bfun('tp_pad_org', BR_FURN.tp.trig);
  bfun('tp_arrival_org', [BR_FURN.tp.trig[0], BR_FURN.tp.trig[1] + TP_ARRIVE_OFF]);
  bd.push('');
  fs.writeFileSync(BREATHER_GSC_OUT, bd.join('\n'), 'utf8');
  console.log(`wrote ${BREATHER_GSC_OUT}  (${BRZS.length} lounges, themes ${[...BREATHER_LAPS].sort((a, b2) => a - b2).map(l => `${l}:${BREATHER_THEME[l].key}`).join(' ')})`);
}
