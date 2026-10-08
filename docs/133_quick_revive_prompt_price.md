# Quick Revive prompt price ? September 13, 2026

The user reported a solo game displaying 1500 while deducting 500.

## Cause and change

The server fix in `_tod_perk_lights::solo_qr_price_fix` sets the vending
trigger cost and restamps its hint with 500. Stock `_zm_perks` buys using
`self.cost`. Those server writes do not control the custom prompt's number:
`ZMCursorHintNew` previously passed only the `AetheriumPerks` row to
`PromptPerks.UpdatePerkInfo`, throwing away the hint's price. The widget
independently selected the table's 1500 or `soloCost` using a `tod_party`
dvar read. Unavailable reads returned co-op. Older fixes changed the price,
restamped the hint, or substituted a different party-count API while leaving
this independent pricing path in place.

The router now forwards the same `hudItems.cursorHintText` it classified.
The widget strips color codes and parses its bracketed `[Cost: N]` field.
It no longer reads player count or `tod_party`. Fixed-price perks retain a
table fallback if no cost is present; variable-price Quick Revive clears the
number in that case, avoiding an invented price or the previous perk's value.
No purchase, power, life, perk-cap, party-dvar or gameplay flags changed.
The existing router is English-based; this change does not add localization.

## Diagnostics

`[TOD_PERK_PRICE] rev=hint1` uses stock LUI `DebugPrint`, the developer console
channel, on price/perk/source transitions only. Fields: perk specialty,
shown price, source (`hint` or `missing_hint_cost`), full native hint.
One previous signature per widget; no timer or growing history.
The launcher already enables developer logging. Archive through
`tools/capture_ai_logs.ps1`; its existing filter includes this tag.

## Verification

`tools/test_perk_prompt_price.lua` executes the actual Lua updater and the
router's actual handoff body in Lua 5.1. Cases: unavailable dvars, 500 solo,
1500 co-op, color codes, numeric key bindings, changing prices, zero cost,
missing/malformed hints, fixed-price fallback, clearing the prior perk and
bounded logging. Passing this test is not proof of native rendering.

Script/UI build completed at 22:47:17 Eastern, FF 178,860,032 bytes.
All 144 script/UI/zone source files match deployed; none is newer than FF.
Geometry hash matches the unchanged prior full-build source.
Evidence: `tmp/qr_price/build_verification.json`.
User-confirmed in game: "it works" after taking over the solo playtest.
The agent stopped input at the user's request before completing its own
purchase check. Co-op pricing is covered by Lua tests, not a native co-op run.
Diagnostic code is covered by tests; native DebugPrint output was not verified.
Screenshots and build evidence remain in `tmp/qr_price/`.
No further game input, launch or build is needed for this confirmation.


## Follow-up, September 15, 2026 (v19.11): co-op charged 500

The server-side `solo_qr_price_fix` decided solo from `GetPlayers().size` the
moment the first player existed. In co-op the host connects alone for a beat,
so the fix ran in a two-player game and re-asserted 500 for 20 s over stock's
1500. It now waits for stock's `all_players_connected` flag and reads the
`solo_game` decision; both prices are asserted the same way (500 solo, 1500
co-op). `[TOD_QR_PRICE]` dev log records the settled party and every re-assert.
The prompt widget is unchanged: it shows the `[Cost: N]` the server stamps.
Not yet tested in native co-op.
