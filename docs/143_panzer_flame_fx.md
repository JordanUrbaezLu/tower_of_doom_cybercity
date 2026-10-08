# Panzer flame visibility, September 15, 2026

Reported: flame animation and burn damage sometimes play without the cone.

Stock `shared/ai/mechz.gsc::mechzDelayFlame` starts its own `mechz_ft`
clientfield, sets `isShootingFlame`, and sets the deadline. Its behavior-tree
update invokes our damage callback. Our visible SHIP field `acc_panzer_ft`
was only enabled by the separate `start_ft` animation notetrack. Therefore
the stock attack could burn correctly without enabling our visible cone.
This is a source-confirmed uncovered path; the individual reported incident
was not captured with both server and client instrumentation.

`acc_ft_visual_state` now change-gates the SHIP field. The stock damage
callback synchronizes it before applying burns, and one guarded per-actor
50 ms watcher follows all stock starts/stops, including interruptions and
death. Animation start/stop also use the same writer. Damage values, durations,
clientfield layout, and the existing client FX asset remain unchanged.
Dev log `[TOD_PANZER_FX]` records entity, time and on/off transitions.

The teleporter already delayed arrival by two server frames. Its `fx_burst`
still created a host and emitted the effect in the same frame. It now lets
the host replicate for two frames before emission, retains its full requested
FX lifetime, and logs emitted/host_failed/host_lost in dev mode. The King's
extended-cone host receives the same delay, with death/attack-state checks
after the yield. This is timing hardening, not proof of client delivery.
The historical comment claiming audible sound definitively excludes entity
exhaustion overstates that evidence: separate allocations can differ. The
new failure diagnostics distinguish host allocation from successful emission.

`tools/test_panzer_flame_fx.js` executes the shipping setter and watcher with
stock-only starts, repeated attacks, interruption, steady-state deduplication,
and death. Build gate includes it. Final normal-play build passed at 21:35:42
Eastern, FF 149,665,856 bytes; all 147 snapshot/source/deployed files match,
none synced later. Dev, god, open-door flags and King shortcut are OFF at the
user's latest request. The attempted dev launch exited before map/visual
verification; no successful native flame or teleport check is claimed.
Logs: tmp/elite_tracking/runs/20260915_213405_288_f9f8df2d.
Build evidence: tmp/flame_fx_20260915/build_normal.log and normal_verification.json.
