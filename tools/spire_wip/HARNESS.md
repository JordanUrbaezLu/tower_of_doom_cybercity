# The spire verify harness (recipe — write fresh, apply, test, REMOVE)

The spire's post-win ladder (WIRING.md §10) needs a real run, and reaching
the win at ship cadences is a 1-2h climb. This is the fast path, per the
map's harness doctrine (_tod_main.gsc comment: written fresh + removed same
session, FIVE times now — never left dormant).

## Apply (then FULL build — the flag flip is compile-time)
1. `zm_tower_of_doom.gsc::tod_resolve_dev_flags()`: `level.tod_dev = true;`
   (+ `tod_god = true` if the user wants the safety net). Dev money covers
   the 12k extraction and the spire doors.
2. Fresh harness thread in `_tod_main::init()` (the recipe comment there):
   - stock power entry `zm_power::turn_power_on_and_open_doors` +
     `zm_perks::perk_unpause_all_perks` (never poke "power_on" by hand)
   - `tod_doors::dev_open_all_doors()` after `level.tod_doors_ready`
   - warp every player to the TERRACE on spawn AND respawn
   Player then: buys extraction (12k, dev money), runs the 90s road +
   survives the siege (tod_god makes this safe), and THE CHOICE appears.

## The ladder to walk (from WIRING.md §10)
choice banners up + hall quiet -> EXTRACT hold (verify old ending still
lands) on run A; run B: ASCEND hold -> teleport + arrival banner -> grant
audit (v16.36: PERK SLOTS at 5 in the pause menu, all 9 perks, ammo/health; the class gun, PaP state and every other domain UNCHANGED) ->
music = Neon Static -> door 1 buyable @3000 (party-scaled), sequential ->
crates materialize floors 5+ -> hub 10 (PaP powers on, 2 perk pads occupied
some hubs, crate) -> a down + respawn on the spire -> boss cadence + Panzer
music override -> wipe screen ("THE CLIMB ENDS HERE") -> summit extraction
("YOU CONQUERED THE SPIRE") — summit needs a warp or a long climb; consider
extending the harness with a spire-summit warp for that leg.

## Remove
Revert BOTH edits (flags false, harness thread deleted), FULL rebuild,
verify with the freshness diff + a flags grep. The recipe comment in
_tod_main survives; the code never does.
