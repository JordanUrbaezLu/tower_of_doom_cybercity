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

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------
const CORE = 256;          // core half-extent (solid column, roof on top)
const PX = 416;            // path outer edge (path width 160)
const PARA = 20;           // parapet thickness
const PARA_H = 56;         // parapet height above the local step/landing
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
// MATERIAL = clip_player, chosen over Treyarch's own metal_clip/plain clip
// after reading the local tools (2026-08-27):
//   * clip.gdt: clip_player = playerClip 1, aiClip 0, bulletClip 0,
//     canShootClip 0, missileClip 0 — blocks PLAYERS ONLY. Bullets, grenades
//     and zombies pass through and keep using the visible treads.
//   * radiant/configs/navmesh.json lists clip_player in "exclusions", so the
//     navmesh — and therefore every zombie path — is BYTE-IDENTICAL with the
//     ramps in or out. Plain `clip`/metal_clip are NOT excluded and would
//     re-cut the whole tower's navmesh (Treyarch's config; fine, but a much
//     bigger change than a feel experiment needs).
//   * measure_lit_area.js's UNLIT regex is start-anchored: `clip_player`
//     matches ^clip and stays out of the lit-area budget; metal_clip would be
//     mis-counted as ~30M u² of phantom lit area.
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
// ⚠️ THIS PARAGRAPH USED TO SAY THE OPPOSITE AND IT WAS WRONG. It read: "1.4 is
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
const CR_CHAM      = CS(512), CR_CHAM_N = 4;    // corner chamfer depth / steps: the plan reads OCTAGONAL
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
const SP_LAPS = 100;            // the ask: "a tower that goes up 100 floors"
const SP_TOP = SP_LAPS * LAP_RISE;      // 38400
const SP_TOP2 = SP_TOP + FLIGHT_RISE;   // 38592 — summit deck (the crown-stair pattern)
const SP_DOOR_COST = 3000;      // user: every door = the original ladder's cap
const SP_SUMMIT_COST = 7500;    // summit extraction (the roof door's price) — the chosen WIN
const SP_HUB_EVERY = 10;        // vendor hub balcony every 10th floor
const SP_ZONE_CHUNK = 5;        // floors per spawn zone (riser gating rides a script filter)
const SP_BEACON_H = 512;        // summit beacon mast above the deck
// Crate shelf (every non-hub floor): the mid landing is 160 sq with a riser in
// its centre and both other landings are door territory (a 96-radius door
// trigger owns each one), so "an ammo crate at every floor" needs its own
// ground: a 128x120 railed bump-out through a gap cut in the mid landing's
// outer parapet. Crate trigger at the shelf's far edge = 190u from the landing
// riser — the power-hall precedent (189u) for "no two things in one trigger".
const SP_SHELF_Y1 = 276, SP_SHELF_Y2 = 396;   // the parapet gap (odd frame)
const SP_SHELF_X1 = PX + PARA, SP_SHELF_X2 = PX + PARA + 128;   // 436..564
const SP_CRATE_LX = 526, SP_CRATE_LY = 336;   // crate org on the shelf (local, odd frame)
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
const SKY_TOP = Math.max(MAST_TOP, CROWN_TOP, SPIRE_ENABLED ? SP_TOP2 + SP_BEACON_H + 64 : 0) + 300;

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
function lapPal(lap) { return PALETTE[lap % PALETTE.length]; }
function stepMatOf(lap) { return `mwiii_vertigo_retro_synth_${lapPal(lap).key}_tinted`; }
function paraMatOf(lap) { return `mwiii_vertigo_retro_synth_${lapPal(lap).key}`; }
// TRON GRID floors (user 2026-08-20 design pick): dark tiles with GLOWING
// SEAMS — the pack's `_tinted_edge` family (only blue/green/orange/red/
// yellow exist) cycles per lap on landings + breather balconies.
const EDGE_COLORS = ['blue', 'green', 'orange', 'red', 'yellow'];
function edgeMatOf(lap) { return `mwiii_vertigo_retro_synth_${EDGE_COLORS[lap % EDGE_COLORS.length]}_tinted_edge`; }

const MAT = {
  ground: 'mwiii_vertigo_retro_synth_dark_blue_tinted',   // TRON GRID: navy tiles (was grey asphalt)
  baseInlay: 'mwiii_vertigo_retro_synth_blue_tinted_edge', // glowing-seam perimeter ring
  baseWall: 'mwiii_vertigo_retro_synth_blue',
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
  door: 'mwiii_vertigo_retro_synth_green_tinted_edge',
  clip: 'clip',
  // player-only clip for the stair ramps — see the STAIR RAMP CLIP block up in
  // the constants for why it is NOT plain `clip` (navmesh + AI + lit-area).
  rampClip: 'clip_player',
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
const SKYBOX_MODEL = 'skybox_t9_mp_miami';
const SSI = 'acc_ssi_miami_night';

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
const BR_FURN = {
  pap:     { org: [-744, -680], trig: [-688, -680], yaw: 90,      r: 64 },  // W wall, faces east
  station: { org: [-500, -460], trig: [-500, -516], yaw: 359.999, r: 64 },  // N wall, faces south
  crate:   { org: [-310, -700], trig: [-310, -700], yaw: 270,     r: 72 },  // E wall, faces west (unchanged)
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

const worldBrushes = [];
// THE CROWN MEASURES ITSELF. The sky seal used to be asserted against DERIVED
// constants (CR_OUT_X / CR_OUT_Y), and those understate the truth: the east and
// west point HEADS stand 200 units proud of the band they sit on, so the derived
// figure was 104 short before anyone scaled anything. An element that sticks out
// further than its own constant suggests is exactly the bug the seal assert
// exists to catch, so the assert reads THIS instead — the real bounding box of
// every brush actually emitted with a crown or mast label.
const crownBB = { x1: Infinity, x2: -Infinity, y1: Infinity, y2: -Infinity, z1: Infinity, z2: -Infinity };
const crownBoxes = [];
function addBox(label, x1, x2, y1, y2, z1, z2, tex) {
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
function cbox(label, x1, x2, y1, y2, z1, z2, tex) {
  if (CM === 1) addBox(label, x1, x2, y1, y2, z1, z2, tex);
  else addBox(label, -x2, -x1, -y2, -y1, z1, z2, tex);
}
function cpt(x, y, z) { return [CM * x, CM * y, z]; }
function cyaw(y) { return CM === 1 ? y : ((y + 180) % 360); }

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
addBox('ground slab', -(ARENA + WALL), ARENA + WALL, -(ARENA + WALL), ARENA + WALL, -SLAB, 0, MAT.ground);
// TRON GRID inlay: a glowing-seam ring 1u proud around the arena perimeter
addBox('base inlay N', -(ARENA - 20), ARENA - 20, ARENA - 84, ARENA - 20, 0, 1, MAT.baseInlay);
addBox('base inlay S', -(ARENA - 20), ARENA - 20, -(ARENA - 20), -(ARENA - 84), 0, 1, MAT.baseInlay);
addBox('base inlay W', -(ARENA - 20), -(ARENA - 84), -(ARENA - 84), ARENA - 84, 0, 1, MAT.baseInlay);
addBox('base inlay E', ARENA - 84, ARENA - 20, -(ARENA - 84), ARENA - 84, 0, 1, MAT.baseInlay);
// SPLIT — the TELEPORT BAY doorway passes through at x[-TPB_DOOR,TPB_DOOR].
// The clip above (base clip S) is deliberately NOT split: it spans z[128,1600]
// and becomes the lintel over the opening, so the doorway is walk-through at
// player height and still un-jumpable.
addBox('base wall S w', -(ARENA + WALL), -TPB_DOOR, -(ARENA + WALL), -ARENA, 0, BASE_WALL_H, MAT.baseWall);
addBox('base wall S e', TPB_DOOR, ARENA + WALL, -(ARENA + WALL), -ARENA, 0, BASE_WALL_H, MAT.baseWall);
addBox('base wall N', -(ARENA + WALL), ARENA + WALL, ARENA, ARENA + WALL, 0, BASE_WALL_H, MAT.baseWall);
addBox('base wall W', -(ARENA + WALL), -ARENA, -ARENA, ARENA, 0, BASE_WALL_H, MAT.baseWall);
// base wall E: SPLIT — the power hallway passes through at y[-540,-420]
// (user 2026-08-20: "hallway needs to be like 5x longer" — it now runs
// outside the arena to x=1640; see the POWER ROOM section).
addBox('base wall E', ARENA, ARENA + WALL, -420, ARENA, 0, BASE_WALL_H, MAT.baseWall);
// BASE_CLIP_TOP (user 2026-08-20 "invisible walls on the platforms"): the
// enlarged breather balconies extend to y/x ±816 — PAST the arena clip planes
// at ±540..560 — so full-height clips cut invisible walls straight across
// every breather. Cap them below the first breather floor (floor 5 mid slab
// bottom = 1712); the clips only need to stop base-arena wall-hops anyway.
const BASE_CLIP_TOP = 1600;
addBox('base clip S', -(ARENA + WALL), ARENA + WALL, -(ARENA + WALL), -ARENA, BASE_WALL_H, BASE_CLIP_TOP, MAT.clip);
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
// understand. Yaw 270 = front toward -x, out into the arena; box literals =
// the measured yaw-270 occupancy shared by every "ammo crate body" cut.
const BASE_CRATE = { org: [-320, 0], yaw: 270 };
{
  const [bcx, bcy] = BASE_CRATE.org;
  const box = { x1: bcx - 37, x2: bcx + 38, y1: bcy - 19, y2: bcy + 45 };  // z 0..58
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
  addBox('base ammo crate body', box.x1, box.x2, box.y1, box.y2, 0, 58, MAT.clip);
}

// ---------------------------------------------------------------------------
// 3. The core (one palette band per lap; its top IS the rooftop)
// ---------------------------------------------------------------------------
for (let lap = 0; lap < LAPS; lap++) {
  addBox(`core band lap${lap + 1}`, -CORE, CORE, -CORE, CORE, lap * LAP_RISE, (lap + 1) * LAP_RISE, stepMatOf(lap));
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
      addBox(`lap${lap + 1} E step ${i}`, CORE, PX, -CORE + TREAD * (i - 1), -CORE + TREAD * i, z1, z2, stepMat);
    }
    addBox(`lap${lap + 1} NE landing`, CORE, PX, CORE, PX, ...slabZ(mid), edgeMatOf(lap));
    // N flight (y[CORE,PX], x CORE -> -CORE)
    for (let i = 1; i <= STEPS; i++) {
      const [z1, z2] = slabZ(mid + RISE * i);
      addBox(`lap${lap + 1} N step ${i}`, CORE - TREAD * i, CORE - TREAD * (i - 1), CORE, PX, z1, z2, stepMat);
    }
    // v9: the old odd-only "final NW landing (roof arrival)" special case is
    // GONE. It only fired when LAPS was odd, so v8's LAPS=50 built no arrival
    // at all — the roof was unreachable. EVERY lap now ends on its normal
    // landing, and the CROWN section below grows the final flight off whichever
    // landing the parity actually produced.
    addBox(`lap${lap + 1} NW landing`, -PX, -CORE, CORE, PX, ...slabZ(end), edgeMatOf(lap + 1));
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
      addBox(`lap${lap + 1} W step ${i}`, -PX, -CORE, CORE - TREAD * i, CORE - TREAD * (i - 1), z1, z2, stepMat);
    }
    addBox(`lap${lap + 1} SW landing`, -PX, -CORE, -PX, -CORE, ...slabZ(mid), edgeMatOf(lap));
    // S flight (y[-PX,-CORE], x -CORE -> +CORE)
    for (let i = 1; i <= STEPS; i++) {
      const [z1, z2] = slabZ(mid + RISE * i);
      addBox(`lap${lap + 1} S step ${i}`, -CORE + TREAD * (i - 1), -CORE + TREAD * i, -PX, -CORE, z1, z2, stepMat);
    }
    addBox(`lap${lap + 1} SE landing`, CORE, PX, -PX, -CORE, ...slabZ(end), edgeMatOf(lap + 1));
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
    const mFloor = `mwiii_vertigo_retro_synth_${T.key}_tinted_edge`;   // theme grid floor
    const mGlow  = `mwiii_vertigo_retro_synth_${T.key}`;               // sill / mullions / gate / trim
    const mPanel = `mwiii_vertigo_retro_synth_${T.key}_tinted`;        // lintel band + pier (softer)
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
    bb('wall N mull', 416, 444, NB1, NB2, ...zWin, mGlow);
    bb('wall N win', WB1, SPUR_CX - SPUR_W, NB1, NB2, ...zWin, MAT.rampClip);
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
      bb(`wall ${tag} win`, x1, x2, y1, NB1, ...zWin, MAT.rampClip);
      bb(`wall ${tag} lintel`, x1, x2, y1, NB1, ...zLin, mPanel);
    }
    // INNER WALL (S) — the entrance side. The wall proper runs x[436,800]
    // (x[416,436] is the NE landing's own parapet, breather variant); the old
    // landing gap x[256,416] is now a real 192-tall doorway — the lintel
    // reaches west over it and becomes the door header.
    bb('wall S sill', SB2 + PARA, EB1, SB1, SB2, ...zSill, mGlow);
    bb('wall S mull', 604, 632, SB1, SB2, ...zWin, mGlow);
    bb('wall S win', SB2 + PARA, EB1, SB1, SB2, ...zWin, MAT.rampClip);
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
      addBox(`lap${lap + 1} ammo crate body`, ccx - 37, ccx + 38, ccy - 19, ccy + 45, mid, mid + 58, MAT.clip);
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
      addBox('lap1 E parapet (anti-bypass wall)', PX, PX + PARA, -CORE, CORE, 0, 288, MAT.baseWall);
    } else {
      for (let j = 1; j <= STEPS / PARA_EVERY; j++) {
        const top = b + RISE * PARA_EVERY * j;
        // z1 is top - RISE*(PARA_EVERY-1), NOT top (fixed 2026-08-27, docs/39 §4#7):
        // a parapet box spans PARA_EVERY treads but used to start at the HIGHER
        // tread's top, leaving a 12-tall see-through slot to the void under the
        // rail over every lower tread — ~800 map-wide. The box now drops to the
        // lowest tread it guards. Top face unchanged, so RAIL_CAP_H still holds.
        addBox(`lap${lap + 1} E para ${j}`, PX, PX + PARA, -CORE + TREAD * PARA_EVERY * (j - 1), -CORE + TREAD * PARA_EVERY * j, top - RISE * (PARA_EVERY - 1), top + PARA_H, paraMat);
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
    addBox(`lap${lap + 1} NW landing para a`, -PX - PARA, -PX, CORE, PX + PARA, end, end + PARA_H, paraMatOf(lap + 1));
    addBox(`lap${lap + 1} NW landing para b`, -PX, -CORE, PX, PX + PARA, end, end + PARA_H, paraMatOf(lap + 1));
  } else {
    for (let j = 1; j <= STEPS / PARA_EVERY; j++) {
      const top = b + RISE * PARA_EVERY * j;
      addBox(`lap${lap + 1} W para ${j}`, -PX - PARA, -PX, CORE - TREAD * PARA_EVERY * j, CORE - TREAD * PARA_EVERY * (j - 1), top - RISE * (PARA_EVERY - 1), top + PARA_H, paraMat); // ankle gap: see E para
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
    addBox(`lap${lap + 1} SE landing para a`, PX, PX + PARA, -PX - PARA, -CORE, end, end + PARA_H, paraMatOf(lap + 1));
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
  // invisible clip_player wedge as the tower's flights, emitted here so every
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

// interior: the glowing ring inlay, the uplink dais, 4 pylon plinths, the pad
const RI = HW - HWALL - 96, RY1 = HS + HWALL + 96, RY2 = HN - HWALL - 96, RW = 48;
cbox('crown ring inlay S', -RI, RI, RY1, RY1 + RW, TOP2, TOP2 + 1, MAT.crownRing);
cbox('crown ring inlay N', -RI, RI, RY2 - RW, RY2, TOP2, TOP2 + 1, MAT.crownRing);
cbox('crown ring inlay W', -RI, -RI + RW, RY1 + RW, RY2 - RW, TOP2, TOP2 + 1, MAT.crownRing);
cbox('crown ring inlay E', RI - RW, RI, RY1 + RW, RY2 - RW, TOP2, TOP2 + 1, MAT.crownRing);
cbox('uplink dais', -DAIS, DAIS, HYC - DAIS, HYC + DAIS, TOP2, TOP2 + DAIS_H, MAT.crownRing);

// THE FOUR HALL PILLARS ARE BACK — as PURE ARCHITECTURE (v12, user
// 2026-08-26: "We had pillars inside the boss room. Lets add those back. We
// had some models on top of those pillars i didnt want. I think the last
// agent thought I wanted the entire pillars removed"). The v11 deletion
// (user: "4 pillars with this weird looking pipe level model on top ... So
// weird") was aimed at the p7_zm_ctl_deathray_sphere_coil MODELS; the posts
// themselves were the hold-out's only cover and the room has been an empty
// box since. Same footprint and positions as the originals (PYL_OFF 448,
// 176 tall, 80-sq shaft in the original ruby glass), finished now as the
// velvet-and-gold room demands: gold base, ruby shaft, gold cap.
//
// THE SCRIPT CONTRACT IS UNCHANGED AND MUST STAY THAT WAY: the finale's
// quarter-progress read LIVES ON THE CIRCLET's corner points (CROWN_BEACON_XY
// below; `pylon_orgs()` still exports those, NOT these) — these four posts are
// scenery and cover, nothing references them. Verified clearances (finale
// runtime map, 2026-08-26): gather ring 160 about hall_center — clear by
// ~290; hall risers at (+-560, HS+280 / HN-280) — nearest solid face 56 away
// in x (the 24-tall base corner only); hall quarter LIGHTS at (+-448,
// HYC+-448, TOP2+260) sit 84 ABOVE the caps — pillar tops must stay under
// +260 or the light origins end up inside solid. Total height 176 =
// unjumpable, matching the originals.
{
  const PYL_OFF = 448, PYL_H = 176;
  for (const [sx, sy, tag] of [[-1, -1, 'SW'], [1, -1, 'SE'], [-1, 1, 'NW'], [1, 1, 'NE']]) {
    const px = sx * PYL_OFF, py = HYC + sy * PYL_OFF;
    cbox(`pylon plinth ${tag} base`, px - 56, px + 56, py - 56, py + 56, TOP2, TOP2 + 24, MAT.crownGold);
    cbox(`pylon plinth ${tag} shaft`, px - 40, px + 40, py - 40, py + 40, TOP2 + 24, TOP2 + PYL_H - 32, MAT.jewelRuby);
    cbox(`pylon plinth ${tag} cap`, px - 52, px + 52, py - 52, py + 52, TOP2 + PYL_H - 32, TOP2 + PYL_H, MAT.crownGold);
  }
}
cbox('extraction pad', -EXFIL_HALF, EXFIL_HALF, EXFIL_Y - EXFIL_HALF, EXFIL_Y + EXFIL_HALF, TOP2, TOP2 + 8, MAT.exfilPad);

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
// the first cut at 672 nicking the glow strip by 1.5u). Yaw 270 = facing
// west, into the hall.
// Bounds are the breather crate's measured yaw-270 occupancy translated to
// (672, 8308) with the same 4u inset; under CM=-1 the point-mirror of this box
// equals the 180-degree-rotated crate exactly (yaw 90 = 270+180), so clip and
// model stay welded at either parity. THE LABEL MUST END "ammo crate body" —
// lint_tod_geometry's MODEL_CLIP_COLUMNS whitelist matches on it.
const CRATE_ORG = [676, 8308];
cbox('crown hall ammo crate body', CRATE_ORG[0] - 37, CRATE_ORG[0] + 38,
  CRATE_ORG[1] - 19, CRATE_ORG[1] + 45, TOP2, TOP2 + 58, MAT.clip);

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
// EVERYTHING HERE IS AXIS-ALIGNED BOXES, ON PURPOSE. True convex brushes ARE
// supported by this .map format and by cod2map — 51% of the mod tools' shipped
// content is non-axis-aligned, and map 1's own .map has 160 such brushes on
// visible materials — but lint_tod_geometry.js's parser counts axis-constant
// planes and SILENTLY DROPS anything that is not the 6-plane template, as does
// tools/preview_crown.js. Using them here would blind the map's only whole-map
// hole/edge/walkability proof and the 2-second preview loop at exactly the spot
// where the most new geometry is going in. A 4-step chamfer subtends 0.33 deg
// (10 px) at the base-arena distance, i.e. below the shimmer threshold, so the
// plan reads octagonal anyway. Convex brushes are the right tool for the arch
// ribbons LATER, once the previewer projects hulls and the lint tags them.
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

// ONE COURSE OF THE RING: four wall segments plus four 4-step chamfered
// corners. The chamfer is what stops the plan reading as a box — each step
// marches 128 outward in x while the y limit steps 128 inward, so the corner
// walks the 45-degree line. Consecutive steps overlap by design (cod2map merges
// interior faces; this map already has 1,146 overlapping solid pairs).
function crownCourse(tag, hx, hy, t, z1, z2, mat, mouthHalf) {
  const yS = CR_CY - hy, yN = CR_CY + hy;
  const xIn = hx - CR_CHAM, yIn = hy - CR_CHAM;
  cbox(`${tag} band N`, -xIn, xIn, yN - t, yN, z1, z2, mat);
  if (mouthHalf) {
    // THE MOUTH. The causeway walks THROUGH the rim before it ever reaches the
    // hall gate, so the south band is cut here and only here. C1 stays whole
    // (it is entirely below the road) so the ermine ring is unbroken from
    // below, and C4 stays whole and becomes the lintel.
    cbox(`${tag} band S west`, -xIn, -mouthHalf, yS, yS + t, z1, z2, mat);
    cbox(`${tag} band S east`, mouthHalf, xIn, yS, yS + t, z1, z2, mat);
  } else {
    cbox(`${tag} band S`, -xIn, xIn, yS, yS + t, z1, z2, mat);
  }
  cbox(`${tag} band W`, -hx, -hx + t, CR_CY - yIn, CR_CY + yIn, z1, z2, mat);
  cbox(`${tag} band E`, hx - t, hx, CR_CY - yIn, CR_CY + yIn, z1, z2, mat);
  const s = CR_CHAM / CR_CHAM_N;
  for (const sx of [-1, 1]) for (const sy of [-1, 1]) for (let k = 0; k < CR_CHAM_N; k++) {
    const xa = hx - CR_CHAM + s * k, xb = xa + s, yb = hy - s * k;
    cbox(`${tag} corner ${sx > 0 ? 'E' : 'W'}${sy > 0 ? 'N' : 'S'} ${k + 1}`,
      sx > 0 ? xa : -xb, sx > 0 ? xb : -xa,
      CR_CY + (sy > 0 ? yb - t : -yb), CR_CY + (sy > 0 ? yb : -yb + t),
      z1, z2, mat);
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
  tiers.forEach(([wf, wc, h, mat], i) => {
    const hx = (fan === 'x' ? wf : wc) / 2, hy = (fan === 'x' ? wc : wf) / 2;
    cbox(`${label} ${i + 1}`, cx - hx, cx + hx, cy - hy, cy + hy, z, z + h, mat);
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
// Ten tiers, each 0.80 of the one above on BOTH axes, so the taper is
// PROPORTIONAL and reads as a cone. A linear step-in runs the short axis out
// first and produces a keel. Alternate gold and brass every tier: from below
// you look almost straight up the cone and what you see is a set of concentric
// rings whose visible width is the step-in — 400 units at the top (1.04 deg,
// 31 px) and shrinking inward. That is the radiate-crown underside delivered
// with ten boxes and no radial ribs. Radial ribs at 128 wide would be 0.33 deg
// and would shimmer; concentric banding beats radial geometry at this distance.
// A SOLID tier with CHAMFERED CORNERS out of axis-aligned boxes. Two
// overlapping boxes make the cross; one more box per corner cuts the notch on
// the 45-degree line, giving a two-step staircase across it. Six brushes buys
// an octagonal outline — and the outline is the entire point here, because from
// directly below the skirt IS the crown, and a stack of rectangles reads as a
// stack of rectangles no matter what colour it is.
function crownSolidTier(tag, hx, hy, z1, z2, mat) {
  const c = Math.min(CR_CHAM, Math.round(Math.min(hx, hy) * 0.32 / 16) * 16);
  cbox(`${tag} A`, -hx, hx, CR_CY - (hy - c), CR_CY + (hy - c), z1, z2, mat);
  cbox(`${tag} B`, -(hx - c), hx - c, CR_CY - hy, CR_CY + hy, z1, z2, mat);
  for (const sx of [-1, 1]) for (const sy of [-1, 1]) {
    const x1 = hx - c, x2 = hx - c / 2, y1 = hy - c, y2 = hy - c / 2;
    cbox(`${tag} corner ${sx > 0 ? 'E' : 'W'}${sy > 0 ? 'N' : 'S'}`,
      sx > 0 ? x1 : -x2, sx > 0 ? x2 : -x1,
      CR_CY + (sy > 0 ? y1 : -y2), CR_CY + (sy > 0 ? y2 : -y1), z1, z2, mat);
  }
}
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
  // --- THE VORTEX BELL (v12, user 2026-08-26: "players climb the tower and
  // ... can see the bottom of the crown building as they get higher. Maybe a
  // cool design on bottom is something worth thinking about. They look up and
  // see this MASSIVE building") -----------------------------------------------
  //
  // The underside is 60% of the pixels for the whole climb (docs/34 §2), and
  // the v11 cone — eight tiers at a uniform 0.8 taper — read correctly but
  // read SMOOTH: concentric rings with no second rhythm, no scale reference,
  // and a 544-unit core. A smooth object has no size. Three changes, all
  // measured against the CLIMB's shrinking sight line (0.5 deg is 384 units
  // from the base arena but ~100 units from floor 40 — the underside is the
  // one crown surface whose audience keeps getting CLOSER):
  //
  //   1. TEN TIERS ON AN OGEE, NOT EIGHT ON A LINE. Per-tier scale factors run
  //      slow-fast-slow, so the side silhouette is a BELL and, from below, the
  //      visible ring widths accelerate toward the centre — thin rings at the
  //      rim, broad mid-rings, a tight whorl at the throat. The eye reads
  //      accelerating rings as DEPTH (it is how a dome coffer fakes height),
  //      which is exactly the "massive building overhead" the user asked for.
  //      Heights are weight-derived from the same span, taller at the rim and
  //      shorter at the throat, so the vertical rhythm accelerates too.
  //   2. CORONA TEETH on the gold tiers — brass blocks hanging below the tier
  //      lip at 320 wide (0.83 deg from the BASE, so they resolve everywhere).
  //      This is the dentil trick from the south face turned downward: a
  //      broken outline against a different value, the one kind of relief
  //      that works on self-lit materials. It is NOT the rejected radial-rib
  //      idea (docs/34: 128-wide ribs shimmer) — teeth are 2.5x that size and
  //      they serrate the EDGE rather than lining the field.
  //   3. JEWEL COLLARS on two brass tiers — stud rings echoing the band's
  //      jewel program, sized for the mid-climb read.
  //
  // SOUTH HALF ONLY for teeth and studs: every sight line to the underside
  // comes from the tower, which is due south — the cone's north faces are
  // self-occluded from everywhere a player can stand (the courtyard behind
  // the rim is open air, and the hall is walled). Same argument as 5f.10's
  // south-face rule, applied downward.
  const SK_W = [25, 24, 23, 22, 21, 20, 19, 18, 15, 14];    // height weights, rim -> throat
  const SK_F = [0.94, 0.90, 0.86, 0.80, 0.74, 0.70, 0.70, 0.74, 0.80, 0.86];  // ogee taper
  const SK_SPAN = CR_ERM_Z1 - CR_SKIRT_BOT;
  const SK_WSUM = SK_W.reduce((a, b) => a + b, 0);
  let hx = CR_HX - CR_ERM, hy = CR_HY - CR_ERM;
  let acc = 0, tooth = 0, stud = 0;
  const JM = [MAT.jewelRuby, MAT.jewelSapphire, MAT.jewelEmerald];
  for (let i = 0; i < 10; i++) {
    // z bounds from the CUMULATIVE weight fraction, so tier 10's floor lands
    // exactly on CR_SKIRT_BOT at any CR_SCALE — no drift, no seam.
    const z2 = TOP2 + CR_ERM_Z1 - SK_SPAN * acc / SK_WSUM;
    acc += SK_W[i];
    const z1 = TOP2 + CR_ERM_Z1 - SK_SPAN * acc / SK_WSUM;
    const gold = (i % 2 === 0);
    crownSolidTier(`crown skirt tier ${i}`, hx, hy, z1, z2, gold ? MAT.crownGold : MAT.crownBrass);
    // the chamfer crownSolidTier used, recomputed so teeth/studs know the
    // straight span of the south face they sit on
    const cham = Math.min(CR_CHAM, Math.round(Math.min(hx, hy) * 0.32 / 16) * 16);
    const span = hx - cham, yS = CR_CY - hy;
    if (gold && i <= 6 && span > CS(480)) {
      // CORONA TEETH — hang CS(80) below the lip, keyed CS(24) up into the
      // tier and CS(48) north into it so nothing floats. Brass against gold.
      // Tier 0 shares its z-band with the pendilia cords, so it takes the
      // strand-safe positions; the deeper gold tiers are below every cord.
      const us = (i === 0) ? SAFE_U
        : (() => {
          const n = Math.max(2, Math.floor((2 * span) / CS(560)));
          return Array.from({ length: n }, (_, t) => snapU(-span + 2 * span * (t + 0.5) / n));
        })();
      for (const u of us)
        cbox(`crown skirt tooth ${++tooth}`, u - CS(112), u + CS(112),
          yS - CS(32), yS + CS(48), z1 - CS(80), z1 + CS(24), MAT.crownBrass);
    }
    if (!gold && (i === 1 || i === 5) && span > CS(400)) {
      // JEWEL COLLAR — stones keyed on |u| (the points' symmetric-key rule) so
      // mirrored studs always match; height fitted to the tier's own course.
      // Tier 1 is in the cords' z-band -> strand-safe positions; tier 5 is
      // far below them and keeps its own spread, clamped to the straight face
      // (past `span` the tier steps back through the chamfer and a keyed stud
      // would float — the sunken-panel lesson).
      const sh = Math.min(CS(200), Math.round((z2 - z1 - CS(48)) / 2));
      const umax = span - CS(176);
      const us = (i === 1) ? SAFE_U
        : Array.from({ length: 3 }, (_, t) => snapU(-umax + umax * t));
      for (const u of us) {
        const zm = (z1 + z2) / 2;
        cbox(`crown skirt stud ${++stud}`, u - CS(160), u + CS(160),
          yS - CS(40), yS + CS(64), zm - sh, zm + sh, JM[Math.round(Math.abs(u) / 16) % 3]);
      }
    }
    hx = Math.round(hx * SK_F[i] / 16) * 16; hy = Math.round(hy * SK_F[i] / 16) * 16;
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
  // quarter-sine, so the ribbon rises fast at the shoulder and flattens into
  // the crown. The largest step delta is sin(11.25 deg) of the rise = 19.5% of
  // it, against a ribbon ARCH_TH thick; both scale together with CR_SCALE, so
  // consecutive boxes always overlap and the arch can never gain a gap. There
  // is an assert on exactly that below the loop.
  for (let k = skip; k < ARCH_N; k++) {
    const a = from + (to - from) * k / ARCH_N, b = from + (to - from) * (k + 1) / ARCH_N;
    const top = Math.round(ARCH_SPRING + ARCH_RISE * Math.sin(Math.PI / 2 * (k + 1) / ARCH_N));
    const p1 = Math.round(Math.min(a, b)), p2 = Math.round(Math.max(a, b));
    if (axis === 'y') cbox(`${tag} ${k + 1}`, -ARCH_HW, ARCH_HW, p1, p2, top - ARCH_TH, top, MAT.crownGold);
    else cbox(`${tag} ${k + 1}`, p1, p2, CR_CY - ARCH_HW, CR_CY + ARCH_HW, top - ARCH_TH, top, MAT.crownGold);
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
      if (axis === 'y') cbox(`${tag} pearl ${k}`, -PB, PB, u - PB, u + PB, top, top + PH, MAT.crownErmine);
      else cbox(`${tag} pearl ${k}`, u - PB, u + PB, CR_CY - PB, CR_CY + PB, top, top + PH, MAT.crownErmine);
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
  const MSH = (CR_MONDE_Z2 - CR_ARCH_CROWN) / 8;
  const MW = [240, 400, 472, 504, 504, 472, 400, 240].map(CS);
  let z = TOP2 + CR_ARCH_CROWN;
  MW.forEach((h, i) => {
    cbox(`crown monde ${i + 1}`, -h, h, CR_CY - h, CR_CY + h, z, z + MSH,
      i % 2 ? MAT.crownGoldPanel : MAT.crownGold);
    z += MSH;
  });
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
//   power switch       origin x=1613, USE TRIGGER x[1589,1608]
//   riser -> trigger   189u clear, so a zombie can never rise standing inside
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
const BREATHER_SPAWN_XY = [[-340, -640], [-340, -780], [-460, -640], [-460, -780]];
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

// --- the one AI factory spawner ---------------------------------------------
ent('zombie factory spawner', [
  '{', `guid "${guid()}"`,
  kv('classname', 'actor_spawner_zm_factory_zombie'),
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
for (let lap = 1; lap <= LAPS; lap++) {
  const b = (lap - 1) * LAP_RISE;
  if (lap % 2 === 1) {
    DOORS.push({
      flag: `enter_lap${lap}`, cost: doorCost(lap), target: `tod_door_lap${lap}`,
      dest: `the Spiral - Floor ${lap}`,
      slab: { x1: CORE, x2: PX, y1: -266, y2: -246, z1: b, z2: b + 128 },
      trig: { x1: CORE, x2: PX, y1: -306, y2: -206, z1: b, z2: b + 128 },
      clip: { x1: CORE, x2: PX + PARA, y1: -266, y2: -246, z1: b + 128, z2: doorClipTop(b) },
      org: [336, -256, b + 40], off: [0, 60, 0],
    });
  } else {
    DOORS.push({
      flag: `enter_lap${lap}`, cost: doorCost(lap), target: `tod_door_lap${lap}`,
      dest: `the Spiral - Floor ${lap}`,
      slab: { x1: -PX, x2: -CORE, y1: 246, y2: 266, z1: b, z2: b + 128 },
      trig: { x1: -PX, x2: -CORE, y1: 206, y2: 306, z1: b, z2: b + 128 },
      clip: { x1: -PX - PARA, x2: -CORE, y1: 246, y2: 266, z1: b + 128, z2: doorClipTop(b) },
      org: [-336, 256, b + 40], off: [0, 60, 0],
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
// POWER ROOM (user 2026-08-20): a longish hallway in the base SE corner —
// buyable door at the west end, power switch behind it at the east end.
// Interior x[280,540] y[-540,-420]; south/east sides are the arena walls,
// north side is a new wall, the west face IS the door slab.
DOORS.push({
  flag: 'enter_power', cost: POWER_DOOR_COST, target: 'tod_door_power',
  dest: 'the Power Room',
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
  dest: 'the Teleport Bay',
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
    matBrush(d.slab.x1, d.slab.x2, d.slab.y1, d.slab.y2, d.slab.z1, d.slab.z2, MAT.door),
    '}',
  ]);
  addBox(`door clip ${d.flag}`, d.clip.x1, d.clip.x2, d.clip.y1, d.clip.y2, d.clip.z1, d.clip.z2, MAT.clip);
}

// THE CAUSEWAY GATE (v10.11) — the road is CUT until EXTRACTION is bought.
// Same slab contract as every buyable door here: _tod_finale makes it
// Solid + DisconnectPaths at init and Hide + NotSolid + ConnectPaths on the
// buy, so the navmesh is genuinely severed and the horde cannot path the road
// early either. Emitted HERE, not in section 5c, because entities[] does not
// exist yet up there.
{
  const g = cspec({
    x1: -CW_HALF - PARA, x2: CW_HALF + PARA,
    y1: TER_Y2, y2: TER_Y2 + 24, z1: TOP2, z2: TOP2 + 256,
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
    const s = cspec({ x1, x2, y1: y, y2: y + 24, z1: TOP2 - 32, z2: TOP2 + 256 });
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
addBox('power hall floor', 560, 1640, -560, -400, -SLAB, 0, MAT.ground);
addBox('power hall wall N', 560, 1620, -420, -400, 0, BASE_WALL_H, MAT.baseWall);
addBox('power hall wall S', 560, 1620, -560, -540, 0, BASE_WALL_H, MAT.baseWall);
addBox('power hall wall E', 1620, 1640, -560, -400, 0, BASE_WALL_H, MAT.baseWall);
addBox('power hall clip N', 560, 1640, -420, -400, BASE_WALL_H, 800, MAT.clip);
addBox('power hall clip S', 560, 1640, -560, -540, BASE_WALL_H, 800, MAT.clip);
addBox('power hall clip E', 1620, 1640, -560, -400, BASE_WALL_H, 800, MAT.clip);
// Power switch at the FAR east end, BACK to the east cap, FACING WEST down
// the corridor (yaw 270 — model front is local -Y, the live-verified vending
// convention; the old yaw-180 at the core's south face pointed it INTO the
// wall, untriggerable).
// FLUSH TO THE WALL (user 2026-08-21 "not up against the wall, some space in
// between"): the prefab's body clip spans local y[-8,+7] (back = +7) and yaw
// 270 maps local +Y onto world +X, so the back lands at origin.x+7. The east
// cap's inner face is x=1620 -> origin 1613 (the old 1596 left a 17u gap).
// The use trigger (local y[-24,-5]) ends up at x[1589,1608], still in the hall.
prefab('base power switch', 'power_switch.map', 1613, -480, 0, 270);
// hallway lights (the exterior leg is outside every arena light's radius)
light('power hall light 1', 800, -480, 100, '0.3 0.9 1', 380, 6, 1);
light('power hall light 2', 1200, -480, 100, '0.3 0.9 1', 380, 6, 1);
light('power hall light 3', 1560, -480, 100, '0.3 0.9 1', 380, 6, 1);
// ---------------------------------------------------------------------------
// THE TELEPORT BAY — the map's second annex (see the TPB_* block up top).
// ---------------------------------------------------------------------------
addBox('tp bay floor',   -(TPB_X + WALL), TPB_X + WALL, TPB_Y1 - WALL, TPB_Y2, -SLAB, 0, MAT.ground);
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
addBox('tp bay inlay W', -(TPB_X - 20), -(TPB_X - 36), TPB_Y1 + 4, TPB_Y2 - 4, 0, 1, MAT.baseInlay);
addBox('tp bay inlay E', TPB_X - 36, TPB_X - 20, TPB_Y1 + 4, TPB_Y2 - 4, 0, 1, MAT.baseInlay);
[[-TPB_PAD_X, TPB_PAD_YN], [TPB_PAD_X, TPB_PAD_YN],
 [-TPB_PAD_X, TPB_PAD_YS], [TPB_PAD_X, TPB_PAD_YS]].forEach(([px, py], i) => {
  addBox(`tp bay pad ${i + 1}`, px - 88, px + 88, py - 88, py + 88, 0, 1, MAT.baseInlay);
});
addBox('tp bay arrival mark', -88, 88, TPB_ARR_Y - 88, TPB_ARR_Y + 88, 0, 1, MAT.exfilPad);
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
  // CLEARANCES at y=7944: nearest hall pillar solid (-448,8160) is 218u away;
  // the gate opening is x[-128,128] so a machine at x=-480 never approaches it;
  // the CTOWER 192 corner blocks sit at the wall ENDS, far from x=-480.
  const [px, py, pz] = cpt(-480, HS + HWALL + 64, TOP2);
  // v13.6 (user 2026-08-29: "I just downloaded bo6 pap. Lets replace all pap
  // machines with this new version. Lets keep the FX and animations from this
  // pack if possible."): the stock vending_weapon_upgrade prefab is REPLACED
  // by the ALXS CW/BO6 PaP — an animated machine with its own FX, sounds and
  // buy script (zm_cwpap, singular by design: ONE GetEnt'd machine, so the
  // crown is the one place it can live; the four breather vendors keep our
  // tod_pap_owned lane wearing this pack's mesh instead). Same spot, same
  // 64u standoff; yaw kept — if the port fronts differently the user's eyes
  // decide the correction, one number.
  prefab('crown pack-a-punch', 'ALXS/alxs_cwpap_prefab.map', px, py, pz, cyaw(180), PERK_LOC);
  const [mx, my, mz] = cpt(480, HS + HWALL + 33, TOP2);
  // NO PERK ON THE CROWN (user 2026-08-25: "I dont want a perk on the crown").
  // The crown carries Pack-a-Punch and nothing else. Mule Kick used to sit here;
  // its replacement, PhD Flopper, went into the PERK_PARK scatter pool instead
  // so that every one of the scatter pads gets a machine — see PERK_PARK.
  //
  // mx/my/mz are still computed above and are now UNUSED on purpose: they are the
  // mirrored companion slot to the PaP position, and leaving them documented is
  // cheaper than re-deriving cpt(480, ...) if anything is ever placed here again.
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
function light(label, x, y, z, color, radius, stops, bake) {
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
light('tod light base 1', -470, -470, 240, BASE_LIGHT, 520, 6, 1);
light('tod light base 2', 470, -470, 240, BASE_LIGHT, 520, 6, 1);
light('tod light base 3', -470, 470, 240, BASE_LIGHT, 520, 6, 1);
light('tod light base 4', 470, 470, 240, BASE_LIGHT, 520, 6, 1);
// Follows the spawn to the WEST band (2026-08-27) — it exists to light the
// start point, and leaving it in the south would have left the new spawn lit
// only by the two blue corner lights while the empty south stayed warm. Same
// colour, same radius, same height; only x/y move.
light('tod light base spawn', SPAWN_BAND_X - 10, 0, 200, '1 0.9 0.78', 420, 6, 1);
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
  // The four hall lights used to hang over the pylon plinths at +-448. The
  // plinths are gone (user 2026-08-25), so they sit on the quarter points of
  // the floor instead — the room still needs lighting, the furniture does not.
  const HQ = 448;
  CL('tod light hall SW', -HQ, HYC - HQ, TOP2 + 260, '1 0.85 0.35', 620);
  CL('tod light hall SE', HQ, HYC - HQ, TOP2 + 260, '1 0.85 0.35', 620);
  CL('tod light hall NW', -HQ, HYC + HQ, TOP2 + 260, '1 0.85 0.35', 620);
  CL('tod light hall NE', HQ, HYC + HQ, TOP2 + 260, '1 0.85 0.35', 620);
  CL('tod light hall dais', 0, HYC, TOP2 + 240, '1 0.95 0.5', 520);
  CL('tod light extraction', 0, EXFIL_Y, TOP2 + 200, '0.35 1 0.6', 460);
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
  const svol = (x1, x2, y1, y2, z1, z2) =>
    volumeBrush(SP_X + x1, SP_X + x2, SP_Y + y1, SP_Y + y2, z1, z2);

  // --- seal fit + clearances, asserted (the crown's own doctrine) -----------
  const spExtX = Math.max(ARENA + WALL, PX + BR_EAST + PARA, SP_SHELF_X2 + PARA);
  const spExtY = Math.max(ARENA + WALL, PX + BR_DEPTH + PARA);
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
  sbox('wall N', -(ARENA + WALL), ARENA + WALL, ARENA, ARENA + WALL, 0, BASE_WALL_H, SP_MAT_CORE);
  sbox('wall S', -(ARENA + WALL), ARENA + WALL, -(ARENA + WALL), -ARENA, 0, BASE_WALL_H, SP_MAT_CORE);
  sbox('wall W', -(ARENA + WALL), -ARENA, -ARENA, ARENA, 0, BASE_WALL_H, SP_MAT_CORE);
  sbox('wall E', ARENA, ARENA + WALL, -ARENA, ARENA, 0, BASE_WALL_H, SP_MAT_CORE);
  sbox('clip N', -(ARENA + WALL), ARENA + WALL, ARENA, ARENA + WALL, BASE_WALL_H, 1600, MAT.clip);
  sbox('clip S', -(ARENA + WALL), ARENA + WALL, -(ARENA + WALL), -ARENA, BASE_WALL_H, 1600, MAT.clip);
  sbox('clip W', -(ARENA + WALL), -ARENA, -ARENA, ARENA, BASE_WALL_H, 1600, MAT.clip);
  sbox('clip E', ARENA, ARENA + WALL, -ARENA, ARENA, BASE_WALL_H, 1600, MAT.clip);
  // the arena's own ammo crate (floors 1-4 have no shelf — the arena E clip
  // spans z128..1600 and a shelf below floor 5 would bury itself in it).
  // S wall, clear of the arrival (272u to the nearest riser, 96-door far away).
  // NO map-cut clip here, DELIBERATELY (live test 2026-08-29, "the trigger
  // crate and clip are not all aligned"): the first cut emitted the breather
  // crates' measured YAW-270 occupancy under a crate spawned at another yaw —
  // three disagreeing collision sources. This crate is script-clipped by
  // _tod_spire::spawn_crate (the tower base crate's own recipe, where model,
  // clips and trigger all derive from one org+yaw and cannot disagree).
  const SP_ARENA_CRATE = [-200, -505];

  // --- 6b. the core (ONE brush — monochrome, no palette cycle) --------------
  sbox('core column', -CORE, CORE, -CORE, CORE, 0, SP_TOP, SP_MAT_CORE);
  sbox('core capital', -CORE, CORE, -CORE, CORE, SP_TOP, SP_TOP2, MAT.crownBand);

  // --- 6c. the spiral: the tower's own lap grammar, red, with hubs + shelves -
  const SP_HUBS = [];
  for (let lap = 0; lap < SP_LAPS; lap++) {
    const b = lap * LAP_RISE;
    const odd = (lap % 2 === 0);
    const mid = b + FLIGHT_RISE, end = b + LAP_RISE;
    const hub = ((lap + 1) % SP_HUB_EVERY === 0);
    const sh = !hub && (lap + 1) >= 5;   // crate shelf (floors 5+, hub floors excluded)
    if (hub) SP_HUBS.push(lap + 1);

    if (odd) {
      for (let i = 1; i <= STEPS; i++)
        sbox(`lap${lap + 1} E step ${i}`, CORE, PX, -CORE + TREAD * (i - 1), -CORE + TREAD * i, ...slabZ(b + RISE * i), SP_MAT_STEP);
      sbox(`lap${lap + 1} NE landing`, CORE, PX, CORE, PX, ...slabZ(mid), SP_MAT_LAND);
      for (let i = 1; i <= STEPS; i++)
        sbox(`lap${lap + 1} N step ${i}`, CORE - TREAD * i, CORE - TREAD * (i - 1), CORE, PX, ...slabZ(mid + RISE * i), SP_MAT_STEP);
      sbox(`lap${lap + 1} NW landing`, -PX, -CORE, CORE, PX, ...slabZ(end), SP_MAT_LAND);
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
        sbox(`lap${lap + 1} shelf floor`, SP_SHELF_X1, SP_SHELF_X2, SP_SHELF_Y1, SP_SHELF_Y2, mid - SLAB, mid, SP_MAT_LAND);
        sbox(`lap${lap + 1} shelf rail E`, SP_SHELF_X2, SP_SHELF_X2 + PARA, SP_SHELF_Y1, SP_SHELF_Y2, mid, mid + PARA_H, SP_MAT_PARA);
        sbox(`lap${lap + 1} shelf rail N`, SP_SHELF_X1, SP_SHELF_X2 + PARA, SP_SHELF_Y2, SP_SHELF_Y2 + PARA, mid, mid + PARA_H, SP_MAT_PARA);
        sbox(`lap${lap + 1} shelf rail S`, SP_SHELF_X1, SP_SHELF_X2 + PARA, SP_SHELF_Y1 - PARA, SP_SHELF_Y1, mid, mid + PARA_H, SP_MAT_PARA);
        sbox(`lap${lap + 1} shelf cap E`, SP_SHELF_X2, SP_SHELF_X2 + PARA, SP_SHELF_Y1 - PARA, SP_SHELF_Y2 + PARA, mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
        sbox(`lap${lap + 1} shelf cap N`, SP_SHELF_X1, SP_SHELF_X2 + PARA, SP_SHELF_Y2, SP_SHELF_Y2 + PARA, mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
        sbox(`lap${lap + 1} shelf cap S`, SP_SHELF_X1, SP_SHELF_X2 + PARA, SP_SHELF_Y1 - PARA, SP_SHELF_Y1, mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
      }
    } else {
      for (let i = 1; i <= STEPS; i++)
        sbox(`lap${lap + 1} W step ${i}`, -PX, -CORE, CORE - TREAD * i, CORE - TREAD * (i - 1), ...slabZ(b + RISE * i), SP_MAT_STEP);
      sbox(`lap${lap + 1} SW landing`, -PX, -CORE, -PX, -CORE, ...slabZ(mid), SP_MAT_LAND);
      for (let i = 1; i <= STEPS; i++)
        sbox(`lap${lap + 1} S step ${i}`, -CORE + TREAD * (i - 1), -CORE + TREAD * i, -PX, -CORE, ...slabZ(mid + RISE * i), SP_MAT_STEP);
      sbox(`lap${lap + 1} SE landing`, CORE, PX, -PX, -CORE, ...slabZ(end), SP_MAT_LAND);
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
        sbox(`lap${lap + 1} rail cap W`, -PX - PARA, -PX, (hub ? -PX : -PX - PARA), CORE, b + PARA_H, b + FLIGHT_RISE + PARA_H + RAIL_CAP_H, MAT.clip);
      }
      sbox(`lap${lap + 1} rail cap S`, (hub ? -CORE : -PX - PARA), CORE, -PX - PARA, -PX, mid + PARA_H, mid + FLIGHT_RISE + PARA_H + RAIL_CAP_H, MAT.clip);
      sbox(`lap${lap + 1} rail cap SE a`, PX, PX + PARA, -PX - PARA, -CORE, end + PARA_H, end + PARA_H + RAIL_CAP_H, MAT.clip);
      sbox(`lap${lap + 1} rail cap SE b`, CORE, PX, -PX - PARA, -PX, end + PARA_H, end + PARA_H + RAIL_CAP_H, MAT.clip);
      if (sh) {
        sbox(`lap${lap + 1} shelf floor`, -SP_SHELF_X2, -SP_SHELF_X1, -SP_SHELF_Y2, -SP_SHELF_Y1, mid - SLAB, mid, SP_MAT_LAND);
        sbox(`lap${lap + 1} shelf rail E`, -SP_SHELF_X2 - PARA, -SP_SHELF_X2, -SP_SHELF_Y2, -SP_SHELF_Y1, mid, mid + PARA_H, SP_MAT_PARA);
        sbox(`lap${lap + 1} shelf rail N`, -SP_SHELF_X2 - PARA, -SP_SHELF_X1, -SP_SHELF_Y2 - PARA, -SP_SHELF_Y2, mid, mid + PARA_H, SP_MAT_PARA);
        sbox(`lap${lap + 1} shelf rail S`, -SP_SHELF_X2 - PARA, -SP_SHELF_X1, -SP_SHELF_Y1, -SP_SHELF_Y1 + PARA, mid, mid + PARA_H, SP_MAT_PARA);
        sbox(`lap${lap + 1} shelf cap E`, -SP_SHELF_X2 - PARA, -SP_SHELF_X2, -SP_SHELF_Y2 - PARA, -SP_SHELF_Y1 + PARA, mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
        sbox(`lap${lap + 1} shelf cap N`, -SP_SHELF_X2 - PARA, -SP_SHELF_X1, -SP_SHELF_Y2 - PARA, -SP_SHELF_Y2, mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
        sbox(`lap${lap + 1} shelf cap S`, -SP_SHELF_X2 - PARA, -SP_SHELF_X1, -SP_SHELF_Y1, -SP_SHELF_Y1 + PARA, mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
      }
    }

    // vendor HUB balcony (every 10th floor — all even, mirrored SW frame; the
    // breathers' own footprint so BR_FURN's asserted clearances carry over)
    if (hub) {
      const NB1 = PX + BR_DEPTH, NB2 = NB1 + PARA;
      const EB1 = PX + BR_EAST, EB2 = EB1 + PARA;
      sbox(`hub lap${lap + 1} floor`, -EB1, -CORE, -NB1, -PX, ...slabZ(mid), SP_MAT_HUBF);
      sbox(`hub lap${lap + 1} para S`, -EB2, -(CORE - PARA), -NB2, -NB1, mid, mid + PARA_H, SP_MAT_HUBP);
      sbox(`hub lap${lap + 1} cap S`, -EB2, -(CORE - PARA), -NB2, -NB1, mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
      sbox(`hub lap${lap + 1} para W`, -EB2, -EB1, -NB1, -(PX - PARA), mid, mid + PARA_H, SP_MAT_HUBP);
      sbox(`hub lap${lap + 1} cap W`, -EB2, -EB1, -NB1, -(PX - PARA), mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
      sbox(`hub lap${lap + 1} para N`, -EB1, -(PX + PARA), -PX, -(PX - PARA), mid, mid + PARA_H, SP_MAT_HUBP);
      sbox(`hub lap${lap + 1} cap N`, -EB1, -(PX + PARA), -PX, -(PX - PARA), mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
      // CORE-SIDE RAIL — the floor's inner edge only meets the core for
      // |y|<=256; the rest faces open void (the first lint run found exactly
      // this: 27 unguarded columns per hub). Same band the lounges' W wall
      // occupies, mirrored; the y[-436,-416] strip belongs to the lap's own
      // S-flight parapet, exactly as the lounge note says.
      sbox(`hub lap${lap + 1} para core`, -CORE, -(CORE - PARA), -(PX + BR_DEPTH), -(PX + PARA), mid, mid + PARA_H, SP_MAT_HUBP);
      sbox(`hub lap${lap + 1} cap core`, -CORE, -(CORE - PARA), -(PX + BR_DEPTH), -(PX + PARA), mid + PARA_H, mid + PARA_H + RAIL_CAP_H, MAT.clip);
      const [ccx, ccy] = BR_FURN.crate.org;
      addBox(`spire hub lap${lap + 1} ammo crate body`, SP_X + ccx - 37, SP_X + ccx + 38, SP_Y + ccy - 19, SP_Y + ccy + 45, mid, mid + 58, MAT.clip);
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
  sbox('summit plaza deck', -CORE, CORE, -CORE, CORE, SP_TOP2, SP_TOP2 + SLAB, SP_MAT_HUBF);
  // CAPITAL RIM RAIL — between the plaza deck and the summit stair's top
  // treads (the stair rises flush along the plaza's east edge; without this,
  // treads 13-16 sit above the capital's guard reach — first lint run). The
  // rail base is sunk 32 into the capital so it guards the top treads too;
  // it stops at y=224 so the arrival strip (y 224..256) stays open.
  sbox('summit rim rail', CORE - PARA, CORE, -CORE, 224, SP_TOP2 - 32, SP_TOP2 + SLAB + PARA_H, MAT.crownGold);
  sbox('summit rim cap', CORE - PARA, CORE, -CORE, 224, SP_TOP2 + SLAB + PARA_H, SP_TOP2 + SLAB + PARA_H + RAIL_CAP_H, MAT.clip);
  sbox('summit apron', -480, 480, CORE, 480, SP_TOP2 - SLAB, SP_TOP2, SP_MAT_HUBF);
  // apron + plaza edge rails, every run capped; the stair mouth (E end of the
  // apron's south edge, x[256,416]) and the apron->plaza seam stay open
  sbox('summit apron rail N', -500, 500, 480, 500, SP_TOP2, SP_TOP2 + PARA_H, MAT.crownGold);
  sbox('summit apron cap N', -500, 500, 480, 500, SP_TOP2 + PARA_H, SP_TOP2 + PARA_H + RAIL_CAP_H, MAT.clip);
  sbox('summit apron rail W', -500, -480, 236, 480, SP_TOP2, SP_TOP2 + PARA_H, MAT.crownGold);
  sbox('summit apron cap W', -500, -480, 236, 480, SP_TOP2 + PARA_H, SP_TOP2 + PARA_H + RAIL_CAP_H, MAT.clip);
  sbox('summit apron rail E', 480, 500, 236, 480, SP_TOP2, SP_TOP2 + PARA_H, MAT.crownGold);
  sbox('summit apron cap E', 480, 500, 236, 480, SP_TOP2 + PARA_H, SP_TOP2 + PARA_H + RAIL_CAP_H, MAT.clip);
  sbox('summit apron rail S w', -500, -256, 236, 256, SP_TOP2, SP_TOP2 + PARA_H, MAT.crownGold);
  sbox('summit apron cap S w', -500, -256, 236, 256, SP_TOP2 + PARA_H, SP_TOP2 + PARA_H + RAIL_CAP_H, MAT.clip);
  sbox('summit apron rail S e', 416, 500, 236, 256, SP_TOP2, SP_TOP2 + PARA_H, MAT.crownGold);
  sbox('summit apron cap S e', 416, 500, 236, 256, SP_TOP2 + PARA_H, SP_TOP2 + PARA_H + RAIL_CAP_H, MAT.clip);
  sbox('summit plaza rail W', -276, -256, -256, 256, SP_TOP2, SP_TOP2 + PARA_H, MAT.crownGold);
  sbox('summit plaza cap W', -276, -256, -256, 256, SP_TOP2 + PARA_H, SP_TOP2 + PARA_H + RAIL_CAP_H, MAT.clip);
  sbox('summit plaza rail S', -276, 276, -276, -256, SP_TOP2, SP_TOP2 + PARA_H, MAT.crownGold);
  sbox('summit plaza cap S', -276, 276, -276, -256, SP_TOP2 + PARA_H, SP_TOP2 + PARA_H + RAIL_CAP_H, MAT.clip);
  // NO east plaza rail on purpose: the summit stair rises flush along that
  // edge, so a constant-z rail would hang at head height over its top treads —
  // and stepping east off the plaza lands on walkable stair (<=180 drop), not
  // void. The stair's own outer rail (x[PX,PX+PARA]) guards the real edge.
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
  const SPIRE_DOORS = [];
  for (let n = 1; n <= SP_LAPS; n++) {
    const b = (n - 1) * LAP_RISE;
    const clipTop = Math.min(b + 600, SP_TOP2 - SLAB);
    if (n % 2 === 1) {
      SPIRE_DOORS.push({ n, slab: { x1: CORE, x2: PX, y1: -266, y2: -246, z1: b, z2: b + 128 }, clip: { x1: CORE, x2: PX + PARA, y1: -266, y2: -246, z1: b + 128, z2: clipTop } });
    } else {
      SPIRE_DOORS.push({ n, slab: { x1: -PX, x2: -CORE, y1: 246, y2: 266, z1: b, z2: b + 128 }, clip: { x1: -PX - PARA, x2: -CORE, y1: 246, y2: 266, z1: b + 128, z2: clipTop } });
    }
  }
  // TWO SLABS, NOT 100 (live failure 2026-08-29: "the crown alter has no
  // trigger" — G_Spawn pool exhaustion AT INIT. docs/44 §4 named the
  // ~1024-gentity table as the spire's binding constraint and budgeted the
  // ascension teardown against it — but the PEAK is at init, when the whole
  // old world and every spire slab coexist; 100 resident brushmodels tipped
  // it and the last init-time Spawn() calls failed, the crown altar's
  // trigger among them). The climb is strictly sequential and one-way, so
  // only the NEXT door of each parity ever needs a physical slab: door 1's
  // and door 2's are emitted, and _tod_spire::door_manager SLIDES each +768z
  // to its next same-parity doorway after every buy (same x/y by parity —
  // the move is a pure z translation). The anti-bypass CLIPS stay per-door:
  // they are worldspawn brushes and cost no entities.
  for (const d of SPIRE_DOORS) {
    if (d.n <= 2) {
      ent(`spire door slab ${d.n} (${d.n % 2 === 1 ? 'odd' : 'even'} parity mover)`, [
        '{', `guid "${guid()}"`,
        kv('classname', 'script_brushmodel'),
        kv('targetname', `tod_spire_door${d.n}`),
        kv('script_vector', '0 0 130'),
        kv('script_transition_time', '1.5'),
        matBrush(SP_X + d.slab.x1, SP_X + d.slab.x2, SP_Y + d.slab.y1, SP_Y + d.slab.y2, d.slab.z1, d.slab.z2, MAT.door),
        '}',
      ]);
    }
    addBox(`spire door clip ${d.n}`, SP_X + d.clip.x1, SP_X + d.clip.x2, SP_Y + d.clip.y1, SP_Y + d.clip.y2, d.clip.z1, d.clip.z2, MAT.clip);
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
    risers: [[-470, -470, 0], [336, -336, 0], [-470, 470, 0], [470, 470, 0]],
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
        brushes.push(svol(-(PX + BR_EAST + PARA), -(CORE - PARA), -(PX + BR_DEPTH + PARA), -PX, b - SLAB, b + LAP_RISE + 200));
        risers.push([-750, -460, mid], [-750, -950, mid]);
      }
    }
    SP_ZONES.push({ name: `spire_c${k}_zone`, brushes, risers, dog });
  }
  SP_ZONES.push({
    name: 'spire_summit_zone',
    brushes: [svol(-520, 520, -280, 520, SP_TOP - SLAB, SP_TOP2 + 400)],
    risers: [[180, -180, SP_TOP2 + SLAB], [-180, -180, SP_TOP2 + SLAB], [180, 100, SP_TOP2 + SLAB], [-180, 100, SP_TOP2 + SLAB]],
    dog: [0, 368, SP_TOP2],
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
    spGroup(`spire hub lap${hl}`, `tod_respawn_spire${hl}`, `spire_c${Math.ceil(hl / SP_ZONE_CHUNK)}_zone`,
      [SP_X - 400, SP_Y - 710, mz],
      BREATHER_SPAWN_XY.map(([sx, sy]) => [SP_X + sx, SP_Y + sy, mz]));
  }
  spGroup('spire summit', 'tod_respawn_spire_summit', 'spire_summit_zone',
    [SP_X, SP_Y + 368, SP_TOP2 + 28],
    [[SP_X - 240, SP_Y + 368, SP_TOP2 + 28], [SP_X + 240, SP_Y + 368, SP_TOP2 + 28], [SP_X - 360, SP_Y + 420, SP_TOP2 + 28], [SP_X + 360, SP_Y + 420, SP_TOP2 + 28]]);

  // --- 6g. lights + probes (sparse: 1 red pool per lap, gold at the hubs) ---
  light('spire light base 1', SP_X - 470, SP_Y - 470, 240, SP_LIGHT_RED, 520, 6, 1);
  light('spire light base 2', SP_X + 470, SP_Y - 470, 240, SP_LIGHT_RED, 520, 6, 1);
  light('spire light base 3', SP_X - 470, SP_Y + 470, 240, SP_LIGHT_RED, 520, 6, 1);
  light('spire light base 4', SP_X + 470, SP_Y + 470, 240, SP_LIGHT_RED, 520, 6, 1);
  light('spire light arrival', SP_X - 200, SP_Y, 200, '1 0.9 0.78', 420, 6, 1);
  for (let lap = 0; lap < SP_LAPS; lap++) {
    const mid = lap * LAP_RISE + FLIGHT_RISE;
    const s = (lap % 2 === 0) ? 1 : -1;
    light(`spire light lap${lap + 1}`, SP_X + s * 336, SP_Y + s * 336, mid + 160, SP_LIGHT_RED, 420, 6, 1);
    if ((lap + 1) % SP_HUB_EVERY === 0)
      light(`spire light hub${lap + 1}`, SP_X - 448, SP_Y - (PX + BR_DEPTH / 2), mid + 220, SP_LIGHT_GOLD, 460, 6, 1);
  }
  light('spire light summit 1', SP_X - 180, SP_Y, SP_TOP2 + 200, SP_LIGHT_GOLD, 520, 6, 1);
  light('spire light summit 2', SP_X + 180, SP_Y, SP_TOP2 + 200, SP_LIGHT_GOLD, 520, 6, 1);
  light('spire light beacon', SP_X, SP_Y, SP_TOP2 + SP_BEACON_H + 24, '1 0.25 0.2', 900, 6, 1);
  probe('probe spire base', SP_X, SP_Y, 150);
  for (let lap = 1; lap <= SP_LAPS; lap += 5) {
    const s = (lap % 2 === 1) ? 336 : -336;
    probe(`probe spire lap${lap}`, SP_X + s, SP_Y + s, (lap - 1) * LAP_RISE + FLIGHT_RISE + 150);
  }
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
  s.push(`\treturn ( org[ 0 ] > ${SP_X - 1400} && org[ 0 ] < ${SP_X + 1400} && org[ 1 ] > ${SP_Y - 1400} && org[ 1 ] < ${SP_Y + 1400} );`);
  s.push('}');
  s.push('');
  s.push('// Door n gates floor n at z=(n-1)*' + LAP_RISE + '. Same shape as tod_door_data.');
  s.push('function get_spire_door_info( n )');
  s.push('{');
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
  s.push('\tinfo.dest = "the Spire - Floor " + n;');
  s.push('\treturn info;');
  s.push('}');
  s.push(`function spire_door_z( n ) { return ( n - 1 ) * ${LAP_RISE}; }`);
  s.push('');
  s.push('// Crate shelf per floor (floors 5+; hub floors use the hub crate; the');
  s.push('// arena crate covers 1-4). undefined = no shelf on that floor.');
  s.push('function shelf_crate_org( n )');
  s.push('{');
  s.push(`\tif ( n < 5 || ( n % ${SP_HUB_EVERY} ) == 0 )`);
  s.push('\t\treturn undefined;');
  s.push(`\tmid = ( n - 1 ) * ${LAP_RISE} + ${FLIGHT_RISE};`);
  s.push('\tif ( ( n % 2 ) == 1 )');
  s.push(`\t\treturn ( ${SP_X + SP_CRATE_LX}, ${SP_Y + SP_CRATE_LY}, mid );`);
  s.push(`\treturn ( ${SP_X - SP_CRATE_LX}, ${SP_Y - SP_CRATE_LY}, mid );`);
  s.push('}');
  s.push('function shelf_crate_yaw( n ) { return ( ( ( n % 2 ) == 1 ) ? 270 : 90 ); }');
  s.push(`function arena_crate_org() { return ( ${SP_X + SP_ARENA_CRATE[0]}, ${SP_Y + SP_ARENA_CRATE[1]}, 0 ); }`);
  s.push('function arena_crate_yaw() { return 180; }   // backs the S wall, front toward +y (into the arena)');
  s.push('');
  s.push('// vendor hubs (every 10th floor, mirrored/even frame — BR_FURN anchors)');
  s.push(`function hub_laps() { return array( ${SP_HUBS.join(', ')} ); }`);
  s.push(`function hub_z( lap ) { return ( lap - 1 ) * ${LAP_RISE} + ${FLIGHT_RISE}; }`);
  s.push(`function hub_pap_org( z )  { return ( ${SP_X + BR_FURN.pap.org[0]}, ${SP_Y + BR_FURN.pap.org[1]}, z ); }`);
  s.push(`function hub_pap_trig( z ) { return ( ${SP_X + BR_FURN.pap.trig[0]}, ${SP_Y + BR_FURN.pap.trig[1]}, z ); }`);
  s.push(`function hub_pap_yaw()     { return ${BR_FURN.pap.yaw}; }`);
  s.push(`function hub_crate_org( z ){ return ( ${SP_X + BR_FURN.crate.org[0]}, ${SP_Y + BR_FURN.crate.org[1]}, z ); }`);
  s.push(`function hub_crate_yaw()   { return ${BR_FURN.crate.yaw}; }`);
  s.push('function hub_perk_pads( z )');
  s.push('{');
  s.push('\ta = [];');
  s.push(`\ta[ 0 ] = ( ${SP_X + BR_FURN.perk_e.trig[0]}, ${SP_Y + BR_FURN.perk_e.trig[1]}, z );`);
  s.push(`\ta[ 1 ] = ( ${SP_X + BR_FURN.perk_w.trig[0]}, ${SP_Y + BR_FURN.perk_w.trig[1]}, z );`);
  s.push('\treturn a;');
  s.push('}');
  s.push('');
  s.push('// arrival + arena perk pads + summit');
  s.push(`function arrival_org()     { return ( ${SP_X - 400}, ${SP_Y}, 0 ); }   // west-band centre — NEVER inside |x|<256 (the core column)`);
  s.push('function arena_perk_pads()');
  s.push('{');
  s.push('\ta = [];');
  s.push(`\ta[ 0 ] = ( ${SP_X - 130}, ${SP_Y + PERK_PARK_Y}, 0 );`);
  s.push(`\ta[ 1 ] = ( ${SP_X + 130}, ${SP_Y + PERK_PARK_Y}, 0 );`);
  s.push('\treturn a;');
  s.push('}');
  s.push(`function summit_exfil_org(){ return ( ${SP_X}, ${SP_Y - 150}, ${SP_TOP2 + SLAB + 8} ); }`);
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
out.push(kv('fsi', 'default'));
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
  const pitch = (HD - 2 * HWALL) / 7;
  for (let k = 1; k <= 6; k++) {
    const y = HS + HWALL + k * pitch;
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
c.push(`function exfil_org()       { return ${vec(cpt(0, EXFIL_Y, TOP2 + 8))}; }`);
c.push(`function exfil_radius()    { return ${EXFIL_HALF + 16}; }`);
c.push(`function hall_center()     { return ${vec(cpt(0, HYC, TOP2))}; }`);
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
// CLEARANCES RE-CHECKED at the new x (the trigger keeps its 40u face offset):
//   trigger (-624, 8308) r64 -> nearest hall pillar solid (-504, 8216) = 151u
//   3 collision clips spread +-32 along AnglesToForward (= +-y at yaw 90),
//     so they move with the model and stay clear of the same pillar
//   ammo crate on the east wall is untouched at +676 (52u off its own face)
c.push(`function station_org()     { return ${vec(cpt(-HW + HWALL + 64, HYC - 300, TOP2))}; }`);
c.push(`function station_trig_org(){ return ${vec(cpt(-HW + HWALL + 104, HYC - 300, TOP2))}; }`);
c.push(`function station_yaw()     { return ${cyaw(90)}; }`);
c.push('');
c.push('// THE HALL AMMO CRATE (v12) — spawned by _tod_ammo_crate.gsc, which reads');
c.push('// these instead of hardcoding, so the crate and its generator-emitted');
c.push('// collision clip (label "crown hall ammo crate body") can never drift.');
c.push(`function crown_crate_org() { return ${vec(cpt(CRATE_ORG[0], CRATE_ORG[1], TOP2))}; }`);
c.push(`function crown_crate_yaw() { return ${cyaw(270)}; }`);
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
c.push('// A4: the hold-out opener Panzer crashes into the hall here — clear of the');
c.push('// 160 gather ring, the dais, the pillars, the crate and the station.');
c.push(`function siege_panzer_org()        { return ${vec(cpt(280, HYC + 242, TOP2))}; }`);
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
c.push('// A4 pillar count-in hosts: above each hall pillar cap (cap tops at +176;');
c.push('// the baked quarter lights sit at +260 — the host at +200 splits the gap).');
c.push('function hall_pillar_orgs()');
c.push('{');
c.push('\ta = [];');
(() => {
  const PYL_OFF = 448;
  [[-1, -1], [1, -1], [-1, 1], [1, 1]].forEach(([sx, sy], i) => {
    c.push(`\ta[ ${i} ] = ${vec(cpt(sx * PYL_OFF, HYC + sy * PYL_OFF, TOP2 + 200))};`);
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
  bd.push('// BASE AMMO CRATE — core WEST face at the base arena, ABSOLUTE coords (no');
  bd.push('// mirror frame; the base is authored absolute). v14.3: origin lives in the');
  bd.push('// generator (BASE_CRATE), which also cuts its "base ammo crate body" clip');
  bd.push('// brush and asserts it clear of the lap-1 E flight — the Workshop navmesh');
  bd.push('// report (Pinkbrotha4310 2026-08-30) is the reason this rides the no-drift');
  bd.push('// contract instead of a hand-typed GSC literal.');
  bd.push(`function base_crate_org() { return ( ${BASE_CRATE.org[0]}, ${BASE_CRATE.org[1]}, 0 ); }`);
  bd.push(`function base_crate_yaw() { return ${BASE_CRATE.yaw}; }`);
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
