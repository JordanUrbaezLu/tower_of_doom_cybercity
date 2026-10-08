# September 15 crash investigation: UI ownership

Reports: Sep 10 round-19 element-pool allocation failure; Sep 14 tower-top
whole-PC freeze; Sep 15 random crashes and immediate co-op Warden King crash.
These reports are not assumed to share one cause. No reporter crash log or
native reproduction is available. The bat and Sep 14 prompts cannot explain
the earlier Sep 10 report by themselves.

## Reproduced defects

The stock Lua UIElement.close unsubscribes/removes the element and calls
closeElementInC; it does not invoke child Lua close handlers. Custom widgets
must close their own children. See preserved reference
`tmp/element_pool/stock/LUIElement.lua:228` and docs/133_ui_element_pool.md.
The prior callback-allocation scan did not test this ownership contract.

Executing real constructors/close under Lua 5.1 with non-recursive native
stubs reproduced these unclosed-element counts:

- PromptDefault: 154 of 155, including the teleporter overlay.
- PlayerInfo without the ownership hook: 49 of 52.
- Loadout without the ownership hook: 129 of 130.
- Scoreboard without the ownership hook: 74 of 75.
- PerkItem: its image lacked any close call on item removal.

These are explicit-close counts in a test, NOT native pool usage or a proven
causal trace of a player's crash. UIList internals and native C allocation are
not simulated. Existing GSC documents overlay recreation on death/spectate
in `_tod_upgrade_ui.gsc::menu_respawn_watch`; ordinary card deals reuse the
menu, so do not claim a new menu is allocated on every deal.

## Changes

TodPromptCard owns direct-child cleanup for every prompt shell, including
feedback attached after construction. PerkItem closes its icon and the perk
container closes its UIList through the stock close method.

TodUIOwnership attaches BEFORE feature close hooks. The later hooks run first,
then remaining direct children close through their own methods. It never
recursively bypasses a child owner or recloses detached elements. Applied to
HUD root, loadout, local player info, round counter, scoreboard and its player
rows, powerup tray/notification, upgrade menu and its panels, and class menu.
Health tint closes its remaining fill before its parent; party rows also close
the health track. Existing popup teardown, list cleanup, timers and animations
retain their owners. Layout, rendering, perk behavior and gameplay unchanged.

Diagnostics use the existing guarded stock DebugPrint channel:
`[TOD_UI_LIFETIME] rev=20260915 ownership_loaded`, then close records with
widget id and number of remaining direct children closed. No pool count is
claimed. No timers, extra UI, new server relay or PrintInfo call. Native output
has not been verified; current project instruction is build and stop.

## Validation

`tools/test_ui_lifetimes.lua`: 400 pause cycles, 5,000 completed popups,
2,500 interrupted/burst popups, 150 prompt lifetimes, 500 perk removals,
140 HUD widget lifetimes and 50 complete upgrade/class-menu rebuilds.
No unclosed elements or duplicate closes on fixed paths. Missing-cleanup
negative controls reproduce the owner defects. Stock TextWithBg is stubbed
with its own child cleanup; this does not simulate native UIList behavior.
Archmage tint, Mage HUD eager-notify/startup and forbidden-global tests pass.
Every UI Lua file compiles under Lua 5.1; asset and structural lint pass.

Run: `python -c "import sys; sys.path.insert(0,'tmp/element_pool/deps'); from lupa.lua51 import LuaRuntime; LuaRuntime().execute(open('tools/test_ui_lifetimes.lua').read())"`

## Separate King mitigation

A concurrent session added eight-event batches to king_max_player. Preserved.
Its final refresh_upgrade_list still sends the owned rows as one burst, so
this is not a global eight-events-per-frame limit. Neither event throughput
nor the co-op crash cause has been measured. No King behavior or gameplay
balance was changed by this UI pass.

## Build and native status

Script/UI build passed September 15 at 21:10:55 Eastern: FF 149,663,296
bytes. All 147 source/deployed files in scripts, ui and zone_source match
the pre-build snapshot; no deployed input is newer than the FF. Geometry
is unchanged from the 20:27 BSP / 20:28 LED full build. Native game absent.
Build transcript, test output and verification JSON are preserved under
`tmp/crash_20260915/`. Only the established waived asset warnings occurred.
No game launched; current CLAUDE.md records the user's explicit
build-and-stop instruction. Required follow-up: native death/spectate/respawn,
perk loss/regrant, HUD/pause/scoreboard, extended co-op and King arrival/combat.
The whole-PC freeze also remains unlocalized. Do not advertise all reported
crashes as fixed based on these tests.
