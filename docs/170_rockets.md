# 170 — The Rockets: the post-crown EXTRACT / ASCEND rides

**STATUS (2026-10-02): v19.68s — the CHASE camera and the crash ON the corner floor (after the user saw v19.68r). FULL BUILD OK 13:45:17 Eastern, FF 155,592,384 B; UNPLAYED. The user tests (harness #8: THE CHOICE opens in the crown hall at round 5).**

User, 2026-10-02:

> "I wonder if we can enhance the extract or ascend meaning we use the rocket ships built in the props and place at
> each spot. Intead of the teleporters after the crown fight is over. Then the colorful one goes to endless spire but
> we can also add some cinematic animtion scene where the rocket lifts of once players select ascned and they view from
> the rocket pov as it flies to the endless spire. Then it crashes into the ground and they spawn in and it starts. Of
> ocurse visuals, sounds, and everything for qualit eed to be accounted for"
>
> "I know tower 2 has a cinematic view but not sure how helpful that is for us"
>
> "And if you extract same thing but the extract ship goes striaght up and the game ends few seconds later"

Then, on v19.68r (a screenshot of the wreck standing in the corner wall):

> "Looks good but it should land in the corner area not the wall"
>
> "Also i think the camera pov should be like permantely above the sip so you can see it like in third person but also
> see where its heading"
>
> "Cinemaview should walywas have the ship slightly seen at bottom of screen and able to see ahead of the ship"

Tower of Doom II's first-jump cinematic turned out to be the whole camera lane (one mover per rider, linked, stepped
every server frame, a letterbox + HUD veil on the scriptNotify lane). Everything below it is new.

## 1. The flow

| When | What happens | Owner |
|---|---|---|
| `tod_choice_begin` (the song is over, the hall wiped and paused) | both ships come DOWN out of the sky on their own flames: the extract ship onto sanctuary tier 2 over the extraction pad (0 s → 6.2 s), the colourful one onto the uplink dais (1.4 s → 7.6 s). Anyone under a ship is moved just off its footprint 0.9 s before touchdown. Touchdown: dust ring, vents, a thud, a shake, the ship's clip goes solid, an idle hum. | `_tod_rocket::rockets_arrive` |
| both ships down | the two boarding prompts arm, in open air on the nave side of each ship (feet radius + 56). They reuse the EXISTING strings (`EXTRACT - leave the tower`, `ASCEND - to THE ENDLESS SPIRE / one way, no return`): the rockets mint no hint string. The old pad trigger stands down (it is inside the extract ship's clip); the dais teleporter is never built. | `rockets_arm`, `_tod_finale::choice_phase`, `_tod_spire::choice_watch` |
| first committed hold | the party's choice (the approved first-hold-wins rule): `tod_extract` or `tod_ascend`, both prompts retire. | `board_watch` |
| THE BOARDING | letterbox on, fade to black (350 ms), every living player is linked to their own camera mover inside the black (downed players are revived for free first), `systems online`, fade back (500 ms) - the camera beside the ship on its pad, which settles into a CHASE view behind and above it as it lifts (§5). | `ride_run`, `rider_board` |
| EXTRACT | ignition, the engine lights, liftoff, STRAIGHT UP out of the crown (a 13° drift clear of the arch crossing). 3.7 s into the climb the bars go and the game ends - YOU ESCAPED THE TOWER - with the ship still climbing behind the end screen. The riders are let go inside stock's intermission fade. | `beats_extract`, `_tod_finale::depart` |
| ASCEND | ignition, liftoff, straight up out of the crown, ONE long arc over the top toward the Endless Spire (the camera swinging up behind the ship) into a straight dive at the spire's foot, the ALARM (sparks off the hull, the engine burning), the dive's scream, and the CRASH nose-down into the arena's north-west corner FLOOR, the two corner walls smashed where the hull leans out over them: white, the boom - and the riders are standing at the Spire's arrival looking at the burning wreck as the white burns away. `ascend_run` flips the world inside the white. | `beats_spire`, `crash`, `_tod_spire::ascend_run` |

## 2. The ships (Nikolai's models)

`tools/fan_props/build_fan_props.py` (Blender 4.2, revision `fan_props_3`) builds both from the fan's Meshy FBXs
(`art/fan_props/source/rocket_colorful`, `rocket_outline`): decimate, fresh unwrap, Cycles bake at 4096
(colour / normal 4096, spec / gloss 1024, glow 2048 cut from the windows' and thrusters' hue bands), fullspec.

- `tod_rocket_spire` (the colourful one) and `tod_rocket_extract` (the cyber outline), both **440 tall**, exported
  **lying down**: nose = model +X, pivot on the axis at the fins' feet. A ship in flight is aimed with
  `VectorToAngles( nose )`; standing on a pad it is pitch −90.
- `tod_rocket_wreck` = the spire ship with a `skinOverride` onto burnt twins (`WRECK_DARK` 0.30, desaturated 0.65,
  soot noise, an ember glow 0.55): the same mesh, no second model.
- `rocket_measure()` writes the hull into `art/fan_props/manifest.json`: 41 body-radius stations (60th percentile —
  the fins are not the body), the max radius per station (fins included), the bell, the feet radius (106.6 /
  105.32), the max radius (~110). The generator and the camera read these numbers, never a guess.

## 3. Where they stand, the clips, the crash (GENERATED)

`tools/gen_tower_map.js`, the ROCKETS block (search `THE ROCKETS (2026-10-02, docs/170)`), emits everything into
`_tod_crown_data.gsc` (`rocket_*`) and `_tod_spire_data.gsc` (`rocket_crash_tip`, `rocket_wreck_org/_angles`,
`rocket_arrival_yaw`):

- the spire ship on the dais `(0, HYC, TOP2 + DAIS_H)`, the extract ship on sanctuary tier 2 `(0, EXFIL_Y, TOP2 + 32)`
  — asserted onto their footing and 24+ clear of the reredos;
- each ship's clip: two octagon prisms (fins: apothem 100 to +100; body: apothem 66 to the nose) in ONE
  `script_brushmodel` per ship (`tod_rocket_clip_spire` / `_extract`), emitted LAST so only the worldspawn guid moves.
  `_tod_rocket::init` opens both (NotSolid + ConnectPaths); a ship's goes solid at its touchdown and opens again at
  boarding. A world clip would have stood on the dais through the whole crown siege;
- THE CRASH (v19.68s): the nose buried in the arena's north-west CORNER FLOOR at `RK_TIP` `(SP_X − 460, SP_Y + 470,
  6)` (80 inside the west wall, 70 inside the north wall, the cone 20 into the slab), the hull leaning back 20° along
  the flight (`RK_WRECK_LEAN`, roll 17) — out over the corner, where it SMASHES THE CORNER (`RK_CORNER`): wall W stops
  at y 400 and wall N at x −380, each crumbles down over its last 40 (100 then 72 tall), a 40-tall stub of each runs
  on under the hull (its top in the plain parapet red, the class of a wall top under a clip cap), the boundary clip
  comes down to the stub (the arena stays closed), and the wreck wears its own clip column `rocket wreck body`
  (x −540..−424, y 432..540, z 0..160: a script_model has no collision; geometry lint `MODEL_CLIP_COLUMNS`). The
  corner's riser moved to `(−200, 488)` and the corner light to `(−440, 440)`. Asserted: the tip in the corner floor,
  the break no wider than it must be, every stub and crumbled end ≥ 8 from the hull, the clip not reaching under the
  NW landing, clear of the stair footprint and the light. The arrival faces the wreck (`rocket_arrival_yaw` 102.4).
  (v19.68r buried the nose in the corner PILLAR with the hull out over the void — the user: "it should land in the
  corner area not the wall");
- the flight KEYS (ship-pivot points + unit tangents) for all four flights, `CM === 1` asserted (the flights are
  authored for the crown north of the tower; a LAPS parity change must re-author them).

**THE SWITCH:** `TOD_ROCKETS=0 node tools/gen_tower_map.js` (or off / false / no / none) → `rocket_enabled()` false
and no clip entities: the `.map` is the pre-rocket map byte for byte (proven by diff), `_tod_rocket::init` returns at
once, and the old pad + dais teleporter choice runs. A FULL build either way.

## 4. The flights

`_tod_rocket.gsc` walks a cubic Hermite through the keys (tangents scaled by each chord) on an arc-length table (32
samples a segment), on a piecewise-linear speed profile scaled to the path's length — the SHAPE of a ride (slow off
the pad, fast across the sky) is authored, its length is the path's. Every server frame the ship and every rider's
mover get a `MoveTo` / `RotateTo` aimed TWO frames ahead (Tower II's fix: the client always has a segment that
outlives the 50 ms snapshot, so a late snapshot never clamps and jumps).

| flight | path | time | top speed | min hull clearance | camera |
|---|---|---|---|---|---|
| ASCEND (`spire`) | 31,258 | 12.6 s from the reveal (liftoff at 2.2) | 5,949 u/s | 40.6 | ≥ 93 from any brush, ≤ 3.79°/frame |
| EXTRACT | 16,732 (only ~5.6 s of it is seen) | 13.9 s | ~1,760 u/s | 41.8 | ≥ 67, ≤ 2.22°/frame |
| land spire | 9,578 | 6.2 s | ~3,550 u/s | 41.3 | — |
| land extract | 9,622 | 6.2 s | ~3,570 u/s | 34.1 | — |

THE ASCEND IS ONE VERTICAL PLANE (v19.68s), heading `RK_SH` from the dais to the crash: straight up to `RK_ARC_Z`
21,000, then ONE CIRCLE from straight up over the top (level at ~23,460) into the dive direction — its radius SOLVED
(~2,460) so it ends exactly on the dive line — then a STRAIGHT dive 20° off vertical (~22,800 units) into the corner.
A circle turns at a constant v / R, which a chase camera can follow; v19.68r's keys bunched the turn at the crest
and dropped the ship near-vertically before its dive (harmless for a camera on the hull, a whipping view above it).
The engine fails ~1.9 s into the 5.5 s dive. The extract drifts 13° out from under the arch crossing (the pad is
under both arches) and then goes straight up to 36,000.

## 5. The camera (THE RIDE)

One `tag_origin` mover per rider; `PlayerLinkToDelta( mover, "tag_origin", 1, 0, 0, 0, 0 )` (no view arc — the
player looks where the shot looks); the mover sits at the camera point minus 60 (eye height). Never
`SetPlayerAngles` while linked.

**THE CHASE CAMERA (v19.68s; the user: "permanently above the ship ... like in third person but also see where its
heading" + "always have the ship slightly seen at bottom of screen and able to see ahead").** `rk_cam`, every frame:

- `d` = the flight direction, `ctr` = the hull's middle, `u` = normalize(`R` × `d`), where `R` is the ship's RIGHT
  HAND (generated per ride, `rocket_cam_right`: horizontal, `R = z × S` for the camera's start side `S`). The camera
  is `ctr − d·b + u·h`: `b` behind the ship along its flight, `h` out on the `u` side — ABOVE it in level flight.
- It LOOKS at the hull's middle turned `tilt` (18°) toward the flight, so the ship sits low in the frame and the
  middle of the screen is where it is going.
- `(b, h)`: on the pad `(40, 300)` — beside the ship (behind it would be under the floor); climbing straight up
  `(380, 420)` — below and out to the side, so the view never looks straight up (a near-vertical view spins on its
  yaw); level or diving `(600, 230)` — behind and above. Blended by how vertical the flight is (`cz_climb` 0.95 →
  `cz_cruise` 0.5) and settled from the pad over `settle` 2.5 s from liftoff (smoothstep).
- `S` must point BEHIND the flight's heading, or "up" turns over in the cruise: the spire ship's is straight behind
  its heading (so the whole ascend, ship and camera, stays in one vertical plane); the extract ship's is south-west of
  its pad, between the sanctuary's west piers and the dais.

v19.68r rode the HULL itself (three shots: the hull, the nose, the dive), 30–46 units off the skin; that look is
gone, and the 4096 hull art it justified now reads from 230–600 away.

## 6. The screen — `TodRocketCine.lua` (+ `TodHudVeil.lua`, Tower II's)

`LuiNotifyEvent( &"tod_rocket_cine", 2, state, ms )` to every player (one sender, `cine_all`):
0 off (everything) · 1 on (2.35:1 letterbox, the HUD veiled) · 3 black in · 4 black out · 5 white in + hold ·
6 white out through fire-orange. The overlays draw UNDER the bars; an overlay state on a free screen is ignored; a
32 s WATCHDOG drops everything if the 0 is ever lost (LOCKSTEP `TOD_RK_CINE_WATCHDOG_MS`); closing the HUD releases
the veil. `AetheriumHud.lua`'s hide writers became ONE rule (`todHide` + `TodHudApply`, Tower II's): the scoreboard,
stock's forced end board (latched), the UI bit and the veil; the veil also hides the button prompt, the kill feed and
the third-person crosshair.

## 7. What a rider is spared

`self.tod_rocket_riding` (set FIRST at boarding):
- stock's out-of-playable-area kill (a 3 s poll; the ride leaves every zone) — `level.player_out_of_playable_area_monitor_callback`
  answers spare for a rider and defers to any earlier callback;
- damage — `ride_damage_guard` is FIRST in `level.player_damage_callbacks` (stock returns the first result that is not
  −1, so 0 is final);
- targeting — `zm_utility::increment_ignoreme` / `decrement_ignoreme` (paired once);
- `_tod_finale::crown_containment_watch` skips a rider (and everyone once the crash has set them down at the Spire);
- the body: `Ghost()`, the viewmodel hidden, weapons off (unless a card menu owns them), no crouch / prone / jump,
  standing.
A downed player at boarding is revived for free (`zm_laststand::auto_revive`): the party won the crown. A dead
co-op player (spectating) does not ride; they see the letterbox through whoever they follow.

## 8. Effects and sounds

| beat | effects (host: +X = forward) | sounds |
|---|---|---|
| landing | `tod/rocket/fx_rk_flame` (Tower II's afterburner, on the bell, +X aft), Der Eisendrache's `fx_rocket_exhaust_torch` for the braking burn (from 62%), `fx_dust_landingpad` + `fx_steam_hpressure_md_castle` at touchdown | `tod_rk_roar` (3D loop), stock `zmb_mechz_arrive_land`, `tod_rk_idle` |
| ignition | `fx_rocket_spark_ignition` | `tod_rk_ignite` (the Stinger M7 shot, pitched down) |
| engine | the flame, `fx_rocket_smk_afterburn` on the pad | `tod_rk_roar` |
| liftoff | `fx_rocket_smk_donut_fast` (ring + fire shockwave), the torch for 2.6 s | `tod_rk_liftoff` (the bazooka, pitched way down), `tod_rk_rumble` |
| the climb | `dlc5/zmhd/fx_geotrail_jet_contrail` | `tod_rk_wind` on each rider's mover (spire) |
| the failure (spire) | `fx_elec_sparks_burst_xlg_os` + `fx_mech_dmg_sparks` off the hull, `killstreaks/fx_vtol_exp_smoke_trail` | stock `zmb_ai_mechz_incoming_alarm` |
| the dive | | `tod_rk_charge` (the scream into the ground) |
| the crash | `dlc5/tomb/fx_tomb_mech_death` (+ a second one down the hull 0.3 s later), `fx_mech_jump_landing`, the donut ring | `tod_rk_boom`, `tod_rk_rumble`, stock `zmb_ai_mechz_destruction` |
| the wreck | `smoke/fx_smk_crashed_veh_dmg` on the hull, `fire/fx_fire_ground_rubble_50x50` at the nose (Z-up, as TRAILBLAZER plays it), `smoke/fx_smk_column_wind_slow_lg_dark`; the fires burn down after 150 s, the column stays | `tod_rk_fire` |

Tower II's sounds (`sound_assets/tod/rocket/`, its jump set) + `sound/aliases/tod_rocket.csv` (10 rows). The two
Stalingrad effects first chosen for the crash (`fx_exp_artillery_lg`, `fx_drop_pod_impact`) were swapped before the
build: they reference campaign-only models (`evt_vtolhallway_*`, `p7_street_curb_*`) that are not in the tools'
gdtDB — a link risk. Every new effect's materials were checked against the gdtDB / this map's last `.deps`.

## 9. The gates (every build, `-GscOnly` included)

- `tools/rocket/test_rocket_ride.js` — (1) flies all four flights with the SHIPPING GSC (`tools/rocket/gsc_eval.js`,
  Tower II's interpreter, extended) over the GENERATED data against the generated `.map` (`map_clearance.js`: a
  lower-bound distance to every visible brush, so a pass is a proof): hull margin 12, camera margin 28, camera step
  ≤ 7.5°/frame, inside the sky seal; (2) the timeline (extract END 2–6 s into the climb, the riders freed 5.8–6.05 s
  after it, the spire beats in order, the chase camera settled before the failure, the watchdog ≥ the longest ride + 8 s
  and LOCKSTEP with the Lua); (3) the wiring (zone lines, real `.efx` sources — no 5 KB stubs —, alias rows + wavs,
  the szc, the generated functions, the clip targets in the `.map`, the GDT blocks, the callers, the hint strings);
  (4) seven negative controls (a camera snap — `settle` 0.1 s —, a landing through the floor, a missing fx zone
  line, a lost alias row, a new hint string, a short watchdog, riders freed after stock sets them down).
- `tools/test_rocket_cine.lua` (lupa) — the widget under the no-new-globals rule: the veil held for exactly a ride,
  overlays under the bars and never on a free screen, black in/out, white hold/out, OFF clears, the watchdog, close;
  three negative controls; zoned + built LAST + precached + one sender.

Re-authoring a flight: `tools/rocket/ride_check.js` + `ride_sim.buildPlans( R, keysOverride )`.

## 10. Testing it (dev) and the logs

Harness #8 (armed): at ROUND 5 `tod_finale::dev_open_choice()` sets the party on the hall's gather ring with THE
CHOICE open as if the crown fight had just been won — the ships come down, the prompts arm. ASCEND → the ride → the
Spire (the harness's spire doors + warp pads follow); EXTRACT → the ride → the game ends. Restart to try the other.

`[TOD_ROCKET] ms=...` (`TOD_RK_LOG 1` prints with dev OFF too — ZERO IT BEFORE A PUBLISH): `INIT rev=rockets_2`,
`ARRIVE`, `LAND_START` / `PUSH` / `LAND`, `ARRIVE_DONE`, `ARM`, `CHOICE kind= by=`, `RIDE`, `REVIVE`, `BOARD riders=
cam0=`, `BEAT IGNITE / LIFTOFF / END_GAME / FAIL / SCREAM / IMPACT`, `CAM t= ship= eye= plan_eye= eye_err= ang=
plan_ang=` (every 2 s of a ride: where the eye really is vs the plan), `FLIGHT_END worst_eye_err=`, `IMPACT`,
`WRECK`, `FREE`, `FX <key> at=`, `CLIP`, `ABORT ... why=`. `[TOD_FINALE] DEV_OPEN_CHOICE`.

**Read first after the user's run:** `CAM ... eye_err` (a large error = the link is not following the mover),
`FX` lines for every key, `ABORT` (none expected), and SCRIPTERROR anywhere.

## 11. Not proven (the user's run decides)

- The ride's smoothness in the engine (Tower II played this lane at lower speeds; this ride peaks ~6,000 u/s).
- The chase camera's framing on screen (the ship's size and place in the frame at the player's own FOV) and the
  smashed corner's look — the user's eye.
- Each effect's orientation is read from its own fields (X-up vs Z-up), not seen: the flame / torch aft, the landing
  dust, the crash, the wreck's smoke and fire.
- The Der Eisendrache launch set, the contrail and the vtol smoke trail link in this map for the first time.
- The extract hand-off: the riders stay linked under stock's end screen and are freed at +6.0 s, inside the fade,
  before stock sets the intermission origin (~+6.15 s).
- Sound levels.

## 12. Knobs

- `_tod_rocket.gsc` defines: the beats (`TOD_RK_X_*`, `TOD_RK_S_*`), the landing (`TOD_RK_LAND_*`, `TOD_RK_PUSH_*`,
  `TOD_RK_LAND_TORCH_AT`, `TOD_RK_TORCH_SECS`), the boarding (`TOD_RK_BLACK_*`), the sounds (`TOD_RK_SND_*`),
  `TOD_RK_LOG`.
- The speed profiles: `plan_ride` / `plan_land` (shape only — the path length scales them).
- The chase camera: `rk_cam_plan` (`b0/h0` the pad, `bc/hc` the climb, `b1/h1` the chase, `cz_climb/cz_cruise`, the
  `tilt`, the `settle`); its start side: the generator's `RK_CAM_SIDE` (the spire's = straight behind its heading).
- The flights, the stands, the crash: the generator's ROCKETS block — `RK_ARC_Z` (where the ascend leaves the
  vertical), `RK_TIP` / `RK_WRECK_LEAN` (the crash, the dive's angle), `RK_CORNER` / `RK_STUB_H` (the break) — then
  re-run `test_rocket_ride.js`.
- The art: `build_fan_props.py` (`GLOW` bands, `ROCKET_H`, the `WRECK_*` burn).
