# The Hoop — a bat target above the Heavenly Gift Altar (v19.18 → v19.18d)

## 2026-09-22 - unwanted camera movement in dev playtests

The archived user run `tmp/unexpected_input_20260922/runs/20260922_101436_536_1f0c656f/console_mp.log`
records `PROBE armed ... every=6` followed by 24 `PROBE kill` records.
The old `hoop_probe` calibration loop ran automatically under `tod_dev`,
set player zero's view angles, and killed a nearby zombie with bat damage
regardless of the player's held weapon. This was map script, not evidence
of a live agent sending keyboard/controller input. Thunder Smash did not cast.

Removed the loop, its startup call, cadence constant and unused flag import.
Passive launch/arc/score logging and normal bat/hoop play remain. Startup now
logs `INIT rev=7 manual_hits_only=1`. The existing bat build gate rejects
camera writes and damage calls in the cleanup module, including negative controls.
Script build passed 2026-09-22 10:27:58 Eastern (147,130,240-byte FF;
207,523,840-byte sound bank). All 297 deployed inputs match the original
pre-build snapshot, with no later sync; all 17 other cleanup functions are
unchanged. A peer edited Mage balance after the FF was written: that newer
source is not in this package and was left intact. Evidence/report:
`tmp/unexpected_input_20260922/combined_deployment.json`. No agent game input
or launch; the user performs the next native playtest.

Status: BUILT/UNPLAYED status is in CHANGELOG v19.18 and the CLAUDE.md brief;
this doc is the mechanism and the tuning recipe.

User (2026-09-16): a hole in the tower above the Heavenly Gift Altar on the
base floor, between the altar and the floor-2 stairs, that pays 20 points per
zombie a Slasher launches into it with the bat. A packed bat throws further,
so it lands more often — same 20, more of them.

## Where it is

- Recess 96 wide x 96 tall x 64 deep in the core's SOUTH face: x -48..48,
  y -256..-192, z 240..336. Cyan rim (12 thick, 16 proud, y -272..-256) and a
  cyan backboard 4 thick at the back.
- Above the base upgrade station (model (0,-320,0), 127 tall, trigger cylinder
  32..132) by 108; under the floor-2 south flight (lowest tread over the
  opening bottoms out at z 644) by 296.
- Source: `tools/gen_tower_map.js` section 3, the `HOOP` block and
  `addBoxMinus()`. Lap 1's `spine NS` / `SW` / `SE` core boxes are the only
  ones cut (asserted). The box is emitted to `_tod_breather_data.gsc` as
  `base_hoop_lo()` / `base_hoop_hi()`; the script never restates it.

## What the first probe found (2026-09-16, agent-run, dev build)

Twelve bat kills through `hoop_probe` (aimed from the body at the hoop's
centre) and every `FLIGHT` line read the same: `a:0 t:1/~20..50 c:0 ct:0` —
the actor's origin never moved, its spine tag rose 20–50 units (the death
pose settling), no `actor_corpse` ever fired, and the corpse lanes stayed
undefined. **The server does not track a ragdoll started on a DEAD actor.**
v19.18 launched from the death callback, so the fling every player sees is a
client-side picture the server cannot read, and no box test could ever pay.
Archive: `tmp/elite_tracking/runs/20260916_115710_587_61390fe4`.

Stock's own gravity spikes (`_zm_weap_gravityspikes.gsc`) are the recipe that
works: `StartRagdoll` + `LaunchRagdoll` on a **live** zombie, kill it a
frame later, then read the corpse's origin (`corpse_off_navmesh_watcher`) —
a read that is only meaningful if the server tracks that body.

## What the second probe found (v19.18c, same day)

Ragdolling the body while ALIVE and killing it a frame later — the
gravity-spikes order — read exactly the same on the server: origin static
(`a:0`), spine tag +12 then settling (`t:1/19..46`), no `actor_corpse`
(`c:-`). Archive `tmp/elite_tracking/runs/20260916_130909_510_a4dbbbfb`.
**The server never sees a ragdoll's flight, alive or dead.** The pre-death
lane was retired whole (memory `dead-actor-ragdoll-is-client-only`).

## v19.20c — the death-frame trace (16:54 run, 39 flings, 12 client baskets, 0 paid)

Every server ARC ended at `t=0.08` with `end == from`: the first BulletTrace
started inside the still-solid ragdoll on its death frame. `hoop_arc` now
waits one frame and every trace ignores the body. Diagnostic: an ARC whose
`hit` equals `from` is a trace that began inside something, not a wall.

## v19.20b — MEASURED (2026-09-16 16:34 run, 29 paired flights)

`tools/hoop_calibrate.py <console_mp.log>`: K_z median 4.40, K_h median 3.10.
The ragdoll keeps vertical speed and bleeds ~a third of horizontal, so the
server flies `v = (ix·KH, iy·KH, iz·KZ)` — `TOD_HOOP_ARC_KH` 3.1,
`TOD_HOOP_ARC_KZ` 4.4 — one arc, no fan, slop 24 (rim-clip tolerance). Offline
replay of the 29 against the client's verdict: 5 true / 1 false / 0 missed.
The v19.20 fan (2.8..6.0) with slop 48 paid 16/29. The cue is the map's 2D
`tod_headshot_ding` on the swinger; `"purchase"` was never shipped (silent).
Retune rule: read the next log with the tool, move KH/KZ, never the slop.

## The first real run (v19.18d, 2026-09-16 ~15:00) and v19.20

The client logger worked: ~60 flights, apex 86..308, 5 `in_box=1`, many
landings on the face just under the hole. The server paid nothing: K 3.2 was
too low (the data says ~4.6), so every computed arc ended under the hole.
v19.20: hole lowered to z 200..296, slop 48, and **a FAN** — `hoop_arc`
traces every K in `TOD_HOOP_ARC_K_MIN..MAX` (2.8..6.0 step 0.4, one per
frame) and pays if ANY enters the box, on the swinger's thread
(`hoop_pay_after`). `tools/hoop_calibrate.py <log>` does the pairing below
automatically. ⚠️ Archive the log the moment a run ends — a launch of any map
rewrites `console_mp.log` (the v19.18d run was lost that way).

## How it scores (v19.18d) — THE SERVER SCORES THE ARC IT LAUNCHED

- `bat_home_run` (death callback) → `bat_fling`: roll, impulse,
  `StartRagdoll` + `LaunchRagdoll`, `clientfield::set("tod_hoop_watch", 1)`,
  then `self thread hoop_arc( attacker, impulse, scale, crit )`.
- `hoop_arc`: `p0 = origin + (0,0,TOD_HOOP_ARC_LIFT 32)`,
  `v = impulse × TOD_HOOP_ARC_K`, and every server frame
  (`TOD_HOOP_ARC_DT` 0.05, up to `TOD_HOOP_ARC_SECS` 3):
  `q = p0 + v t − ½ g t²` (`TOD_HOOP_GRAVITY` 800). First `q` inside the box
  (grown `TOD_HOOP_SLOP` 16) → basket. Otherwise `BulletTrace(p, q)` (world
  only): a hit ends the arc, basket only if the hit point is inside the box.
  Falls 256 below the launch floor → down. Real time, so the payout lands
  about when the body visibly arrives. Line: `[TOD_HOOP] ARC`.
- `hoop_score`: unchanged — once per body, 20 through `zm_score`, kill-feed
  "Swish", `purchase` cue at the basket point. (2026-10-01: `TOD_HOOP_PTS`
  20 -> 50 on the lead tester's "too unnoticeable" — docs/167 item 8.)
- **`TOD_HOOP_ARC_K` 3.2 IS A FIRST GUESS.** The engine does not publish what
  a `LaunchRagdoll` impulse is in units/s; the client log below is the ruler.

## The client flight log (`_tod_hoop.csc`)

The client DOES see the ragdoll (stock's `ragdoll_impact_watch` samples
`self.origin` on the client). Actor clientfield `tod_hoop_watch` (1 bit,
registered on both VMs, set to 1 at the launch) starts `flight_watch` on
every client: `self.origin` every 0.05 s for 3 s, `[TOD_HOOP_C] SAMPLE` every
0.25 s, `BASKET` on the first sample inside the (lockstep, slop-grown) box,
and a `FLIGHT ent=.. from=.. apex=.. land=.. dist=.. in_box=..` summary.
Diagnostics only — it pays, plays and draws nothing.

## Calibration (do this from the user's log, never from a guess)

Both loggers print WITHOUT any dev flag (`TOD_HOOP_LOG` / `TOD_HOOP_C_LOG`,
temporary) because the user's launcher already enables devblock prints.
Archive the run (`tools/capture_ai_logs.ps1`), then per entity number:

1. Pair `[TOD_BAT] LAUNCH ent=N impulse=(ix,iy,iz)` with
   `[TOD_HOOP_C] FLIGHT ent=N from=(..,..,z0) apex=A dist=R`.
2. Vertical: `K_z = sqrt( 2 g (A − z0 − 32) ) / iz`.
   Horizontal (a clean flight with no wall hit): with the flight time
   `T = 2 iz K / g`, `R ≈ |(ix,iy)| K T`, so `K_h = sqrt( R g / (2 iz |ixy|) )`.
   They should agree to ~15 %; take the vertical one (the box is a height).
3. Set `TOD_HOOP_ARC_K` to the median over a dozen launches, `-GscOnly`.
4. Compare `[TOD_HOOP_C] ... in_box=1` against `[TOD_HOOP] ARC ... result=`
   for the same entity: they should agree on most bodies. Disagreements on
   bodies that clipped the rim are expected; disagreements on clean flights
   mean K (height) or `TOD_HOOP_ARC_LIFT` (start point) is off.
5. Once calibrated, set `TOD_HOOP_LOG` / `TOD_HOOP_C_LOG` to 0 (or gate on
   `tod_dev`) before a publish.

## Diagnostics (on their own switch while calibrating; `tod_dev` otherwise)

| line | when | fields |
| --- | --- | --- |
| `[TOD_HOOP] INIT rev=3` | module init | pts, k, g, lift, slop, lo, hi |
| `[TOD_BAT] LAUNCH` | every fling | ent, player, weapon, lane, crit, scale, impulse |
| `[TOD_HOOP] ARC` | every fling, when its arc ends | ent, from, impulse, k, v, result (basket/miss), t, apex, end, hit |
| `[TOD_HOOP_C] SAMPLE` (client) | every 0.25 s of a flight | ent, n, org |
| `[TOD_HOOP_C] BASKET` (client) | the real body entered the box | ent, n, org |
| `[TOD_HOOP_C] FLIGHT` (client) | 3 s after the launch | ent, from, apex, land, dist, in_box |
| `[TOD_HOOP] SCORE` | basket | player, pts, point, scale, crit |

Search the archived console for `TOD_HOOP` (`docs/132` workflow).

## Tuning recipe — READ THE LOG FIRST

Nothing in this repo records how far `LaunchRagdoll`'s impulse carries a
body, so z 240..336 is a first placement. After one dev playtest of a few
dozen swings (base and packed):

1. Every lane `0` on every FLIGHT line WITH `lane=live` launches → the
   server still does not track the body even when ragdolled alive. Then the
   only lanes left are an analytic arc from the impulse (needs a calibration
   the engine does not publish) or a physics proxy entity; the height is not
   the problem.
2. A lane moves and its `apex` is consistently below 240 → lower `HOOP_Z1` (the
   assert keeps it 64+ above the station's trigger top of 132) or raise
   `TOD_BAT_FLING_UP`. Above 336 on plain swings → raise it. Target: a plain
   swing's apex band should straddle the opening so a good swing scores and a
   sloppy one does not; the packed x1.6 should clear it comfortably.
3. Moving `HOOP_Z1` / `HOOP_H` is a FULL build (geometry). Moving
   `TOD_HOOP_PTS` / `_WATCH_MS` is `-GscOnly`.

## The bar over the bay door (v19.18c)

From the teleport bay the 20-tall cyan `base doorway lintel S` (z 128..148)
and the invisible `base clip S` (z 128..1600, spanning the whole south wall)
sat exactly on the line from a player on the pad to the hoop — user: *"this
bar that blocks all my shots."* The lintel is gone and the clip is split into
`base clip S w` / `base clip S e` outside x ±160, so the notch above the bay
door is open. The door's own anti-vault clip rides in the slab and still seals
the doorway until it is bought. Geometry lint: no regression.

## Tests

`tools/test_baseball_bat.js` (build gate) — the death hook is run with
`bat_fling` inlined; both lanes launch through it, the pre-death pointer is
published and the damage chain withholds/re-sends (regex on the source).
HOOP section: watcher threaded after the launch and once per fling;
`hoop_inside` inclusive at the slop-grown edge; `hoop_inside` inclusive per axis;
`hoop_score` pays once with one popup and one cue, unpaid without a swinger;
LOCKSTEP against the emitted `.map` (rim bars frame `base_hoop_lo/_hi`, recess
pieces on lap 1 only) and the string table + precache.
