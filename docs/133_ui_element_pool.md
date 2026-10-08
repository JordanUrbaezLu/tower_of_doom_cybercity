# UI element-pool crash investigation — September 10, 2026

Report relayed by Jordan: Steam user PostiveMentalAttitude gets a crash around
round 19, `failed to allocate from element pool`. No class, player count, action
at the crash, or reporter log is available. The exact reported crash has NOT
been reproduced. Do not claim that round 19 itself triggers it, or that this
report proves the earlier AI world-pause bug is involved.

## Findings and changes

`AetheriumStartMenu.lua` constructed upgrade plates, level pips, descriptions,
control hints and an Options UIList on every pause-menu open. Its fixed close
list omitted all of those. The real constructor and close callback, executed
under Lua 5.1 with lightweight native element stubs, allocated 176 direct
elements with 18 representative upgrade rows and left 157 without a close call.
This count excludes stock UIList internals and uses the keycap text fallback;
it is NOT a measurement of the native pool or a hardware limit.

The close callback now walks every direct child and invokes its own `close`,
including the Options UIList's subscription/item cleanup. The same test leaves
zero elements unclosed. Saving the next sibling before closing avoids changing
the traversal underneath it. No UIList behavior is replaced.

Normal score-popup cleanup was checked separately: 1,000 completed popups
allocated and closed all 10,000 elements. That path is NOT a confirmed leak.
However, concurrency was unbounded, and stock clip completion ignores ordinary
interrupted animations. Each custom-lettering popup uses ten elements. The
new `AetheriumPlusPointsContainer.Show` retains at most eight live popups per
owner, closing the oldest before allocating another, and closes any remaining
popups when their owner closes. Values, colors and animations are unchanged;
under a heavy burst the newest eight popups take priority. This is a bound on
transient pressure/interrupted clips, not proof those caused the report.

Relevant stock reference: [T7 UIElement implementation](https://github.com/KingslayerKyle/T7LuaRepo/blob/main/Dumps/PC_Ship_2025-05-31/ui/LUI/LUIElement.lua)
(`close`, `clipFinished`, `childClipFinished`, event registration) and
[CoDMenu.close](https://github.com/KingslayerKyle/T7LuaRepo/blob/main/Dumps/PC_Ship_2025-05-31/ui/T6/CoDMenu.lua).
Native `closeElementInC` internals are not modeled by the test.

## Diagnostics scope

An experimental UI logger was removed before the final build. Server heartbeat
records appeared, but client telemetry was not verified; an unconditional
PrintInfo probe caused UI Error 85029 in a temporary test build. That call,
its label probes, notify event, server relay and Lua module are all removed.
Do not interpret those test heartbeats as proof of client cleanup or native
pool counts. The user asked to end this detour and finish the actual fixes.
Existing AI logs and the requested CLAUDE.md/AGENTS.md dev-logging guidance
remain. `capture_ai_logs.ps1` still recognizes all uppercase TOD feature tags.

## Verification

`tools/test_ui_lifetimes.lua` passes under Lua 5.1: 400 full pause constructor/
close cycles with 0/5/18/56 owned rows, 5,000 completed score popups, 2,500
interrupted/burst popups, independent owners, owner teardown. A missing-OptionsList-close
negative control is detected. Lua structural lint passes for all 49 UI files.

Local test invocation used:

```powershell
python -c "import sys; sys.path.insert(0,'tmp/element_pool/deps'); from lupa.lua51 import LuaRuntime; LuaRuntime().execute(open('tools/test_ui_lifetimes.lua').read())"
```

The local dependency is Lupa 2.8 (`python -m pip install --target
tmp/element_pool/deps lupa==2.8`); a regular Lua 5.1 interpreter can run the
test directly from the repository root.

Final script/UI build passed at 23:44:40 Eastern: FF 176,322,176 bytes.
All 1,533 snapshot/source/deployed input checks, full tree equality and
pre-FF timestamps pass. Geometry reused from the unchanged full build.
Dev/god flags are false, spire harness parked. Native smoke check passed for HUD/class selection, opening and closing pause,
and returning to the upgrade picker. The final test ran Mage with 500 starting
points and dev/god off, then ended in an ordinary round-2 death while idle.
Repeated Escape inputs after that are not evidence of five successful menu
cycles. No UI error dialog or matching script/UI/element-pool error was captured.
No claim of native pool measurements or a round-19/co-op reproduction.
Evidence: `tmp/elite_tracking/runs/20260910_234858_182_4efc4cd6/console_mp.log`
and `tmp/element_pool/final_class.png`, `final_pause.png`, `final_resumed.png`,
`final_cycles.png`. The packed fastfile contains `todPointPopups` and the child
traversal, and no TodUIDiagnostics/LUA_ATTACH/TOD_UI_RELAY markers. The earlier 23:05 publish
candidate predates these changes and does not contain them. Preserve that
distinction in any handoff or upload notes.
