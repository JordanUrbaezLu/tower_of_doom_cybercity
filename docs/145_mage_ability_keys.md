# Mage ability key overlay

2026-09-16: native diagnosis of the blank Blink/Healing Aura tutorial key.

## Confirmed cause

`Engine.Localize("[{+frag}]")` returned these bytes in the running game:
`21,91,123,43,102,114,97,103,125,93,20`.
That is byte 21, the **unexpanded** token, and byte 20. Localization does not
resolve the binding into a string Lua can trim. UIText resolves it later while
rendering. Taking its first byte produces an invisible control character.
The native probe completed without an exception, so this was not a draw-order
or missing-glyph-helper failure. Screenshot: `tmp/mage_key_overlay/probe_loaded.png`.

This supersedes the earlier claims that Localize returns `G OR MIDDLE MOUSE`
or a controller picture directly to Lua. Tests that mocked Localize that way
could not reproduce the native failure.

## Fix

`AetheriumLoadout.lua` uses the stock key-binder signature
`Engine.GetKeyBindingLocalizedString(controller, command, 0, false, false)`
to request keyboard binding text, trims an OR-separated alternate when the
API returns resolved text, then fits it in the map's glyph font. Full
key names survive (F10 must not become F). For a controller, UIText receives
the complete localized binding token. `Engine.LastInput_Gamepad(controller)`
is the stock live-device query; the `LastInput` model refreshes the overlay
when devices change. The d-pad latch is not used.

The key covers the existing tile, above its artwork. The badge requires a
positive usable charge count and fewer than three successful casts of that
ability. The existing server counter still increments only when the ability
is spent. Blink and Healing Aura retire independently. The server already
re-sends HUD state every five seconds; removing readiness was unnecessary.

## Verification

`tools/test_mage_hud.lua` now models the observed deferred-token bytes and
covers readiness, cooldown, all three tutorial uses, independent retirement,
controller token preservation, keyboard rebinds and long key names. The HUD
global guard and UI lifecycle tests also pass.

Native controller rendering confirmed: `tmp/mage_key_overlay/sequence_7.png`
shows LT over Blink with Healing Aura's badge retired at its fixture count of
three. Phase 4 has no ready charges; phase 6 retires both. These are rendering
fixture states, not real ability casts.

Keyboard verification remains open: `bindIndex=0` is `CoD.BIND_PLAYER`
(binding context), not a first-key index. The later API-variant probe was
closed before results were captured. Deferred keyboard text falls back to
native rendering and may still display alternate bindings. Do not claim
keyboard trimming or map typography fully verified in the native game.

## Clean normal-run handoff

The user requested removal of on-screen diagnostic text and a normal Mage
run. All temporary PHASE labels, API probes, timers and forced charges/use
counts were removed from the live widget. The fixture had competed with
real server state and caused flashing; unchanged live badges now also skip
repainting. Production readiness and independent three-cast counters remain.
Dev/god flags remain off and the development harness remains commented out.
The agent-owned probe process was closed and its console log archived in
`tmp/elite_tracking/runs/20260916_011826_660_00179475`.

HUD regression, global guard and lifecycle checks pass. The clean normal-run
build passed (`BUILD OK`, 149,986,688-byte fastfile); all 147 deployed
script/UI/zone-source files match with no freshness errors. Evidence:
`tmp/mage_key_overlay/final_build.log` and `final_verification.json`. No further
native test is being launched: the next playtest belongs to the user.
This is not a Workshop publication or a complete release certification.
