# 69 — Keyboard + mouse accessibility audit and sign-off (v16.29, 2026-09-02)

> **STATUS 2026-09-02 (v16.32): §5 ASSETS LANDED (files (96).zip, all four)
> and §6 IS IMPLEMENTED** — `USE_HINT_FRAME_ART = true` in both card menus,
> `USE_TOD_CTL_HEADER_ART = true` in the pause menu. The three §4 gaps are
> closed by construction: the plates now draw the engine's live key or glyph
> for the player's real device and binds, at every render, with no lock-in.
> The d-pad latch survives only as the hidden input gate and to shorten the
> line once the pad is proven. UNVERIFIED IN GAME — the §7 checklist plus:
> both card menus' plates read as key lines (no literal `[{+...}]`), nothing
> overflows the pill, and the pause header is the baked strip. Flag-off
> fallback = the re-baked keyed plates (now with `/ [F]`).
>
> **On "lock the device in when they lock a class" (user, same day):** it
> cannot be done server-side — the lock buttons are JUMP and USE, and both
> exist on both devices, so a lock-in proves nothing; the d-pad is the only
> device-proving input the server will ever see. The overlay is the better
> answer: the engine already knows the device and the binds and re-draws the
> plate live for the whole match, so there is nothing to lock in and nothing
> to get wrong when a player swaps devices mid-run. CHANGELOG v16.32.

User: *"probably half our player base is KBM ... make sure the button and
assets can properly reflect the input ... Assets are quite important ...
Players read and rely on them more than I would think. Whether its assets
generated as png or LUA."*

This is the audit of every place the map READS input or SHOWS a control, the
one real defect it found (fixed in this pass), the one enhancement it added,
the gaps that remain, and the exact asset that closes them.

## 1. Verdict

**The input lanes are signed off. The prompts were not, and are now.**

| Surface | KBM state | Evidence |
|---|---|---|
| Upgrade card panel — switch focus | MOUSE1 = left, MOUSE2 = right, V or R = flip; A/D and W/S as bonus lanes | `_tod_upgrade_ui.gsc::wait_for_choice` — all four action buttons edge-latched and pre-seeded |
| Upgrade card panel — lock | hold SPACE or F 0.5 s; both arm on first release | same function, `jump_armed` / `use_armed` |
| Class draft — switch / lock | MOUSE1 prev, MOUSE2 next, V/R next; hold SPACE or F | `_tod_class_select.gsc::run_select_input` |
| Card-panel hint plates | KEYBOARD plates by default; pad plates only after the server sees a d-pad press | `tod_upgrade.lua` / `tod_class_select.lua` `UsingController()` = `CoD.TodPad`, set by the `tod_input_pad` notify |
| Latch receiver timing | the receiver lives in the always-open `tod_upgrade` HUD menu, which opens 0.05 s after `initial_blackscreen_passed`; the draft panel opens 0.5 s after it, so the first d-pad press of the match is never lost | `_tod_upgrade_ui.gsc::player_lui_life`, `_tod_class_select.gsc::init` |
| Pause menu | mouse hover + click on every button (`setHandleMouse`), keyboard up/down/enter through the stock list; Options & Controls opens the PC controls page for rebinding | `AetheriumStartMenu.lua`, `AetheriumMenuButton.lua` |
| Cursor-hint cards (doors, perks, PaP, crates, teleporters, altar, extraction, spire, power) | **WAS WRONG** — a hardcoded literal `"F"` on every card. Now engine-resolved. | §2 |
| Finale / spire buys, revive, stations | hold USE through stock `trigger_radius_use`; no device dependence | — |
| Athlete slide-jump steering | reads the movement axis; a keyboard reads exactly 1, which the code documents and handles | `_tod_athlete.gsc` |

## 2. Fixed: every prompt card said "F"

The vendored Aetherium kit draws its cursor-hint footer as three elements —
`"Hold "` + `"F"` + the verb — and the `"F"` is a string literal in all eight
`ui/uieditor/widgets/HUD/ZM_CursorHint/Prompts/*.lua`. The comment beside it
says *"reactive to button binding"*. It never was. Consequences:

- every CONTROLLER player read "Hold F To Buy" at every door, perk, crate,
  teleporter and finale buy;
- every keyboard player who rebound USE (E is the common rebind) was told the
  wrong key.

Map 1 shipped the identical literal; the kit repo has it too.

**The fix lets the engine draw the key.** The footer is now ONE `UIText` set to
`Engine.Localize( "Hold ^3[{+activate}]^7 <verb>" )` — the stock idiom — through
a per-card `SetFooter( self, verb )`, re-called on every hint update so a
mid-match device swap or rebind is right again at the next prompt. One element
rather than three because the expansion's width is not ours to know (a pad
glyph, "F", "MOUSE3", "SPACE" all differ) and inline flow can never overlap the
verb.

Why this is known to work, given no stock Lua is readable on this box:

1. The v14.58 raw-write bug poured the untouched hint through exactly this
   call (`Engine.Localize( rawHint )` into a `UIText`) and the user transcribed
   the result as **"HoldXAMMOCRATE"** — an X, the pad glyph, not the token and
   not an F. The token expanded, the colour codes were consumed.
2. Every stock zombies hint ("Hold ^3[{+activate}]^7 to open Door [Cost: &&1]")
   reaches the screen through the same LUI pipeline with its key gold and
   device-correct.

Files: `PromptDefault`, `PromptDoors`, `PromptPerks`, `PromptPAP`,
`PromptPowerSwitch` (the five `classifyHint()` can route to) plus
`PromptMysteryBox`, `PromptBBG`, `PromptWallBuy` (unreachable on this map;
patched so no literal key name survives anywhere in `Prompts/`).

## 3. Added: the pause-menu UPGRADE CARDS legend

`AetheriumStartMenu.lua`, under the button list (y 576–611, right column).
Two lines: the header `UPGRADE CARDS` and the live controls:

- keyboard (and a pad before the latch): `SWITCH: [{+attack}] [{+speed_throw}]
  or [{+melee}]    LOCK: HOLD [{+gostand}] or [{+activate}]`
- pad, after the latch: `SWITCH: D-PAD    LOCK: HOLD [{+gostand}]`

Every token is expanded by the engine for the player's current device and
binds. This is the one place the LIVE binds are readable (the card plates are
baked with the defaults), and it is also **the probe for the other bind
names**: `+activate` is proven; `+attack`, `+speed_throw` (aim), `+melee`,
`+gostand` (jump) are the standard names and are unproven on this engine until
this line has been seen. **If any token renders as literal `[{+...}]` text,
that name is wrong** — fix the legend and do NOT use that name in §5's frame
plate.

## 4. What remains, and why it is one asset

Three gaps, all in the card-panel hint plates, all with the same cause: the
plates are PNGs with the keys baked in.

1. **Default binds only.** A rebinder reads MOUSE1 / MOUSE2 / V / SPACE
   whatever they bound.
2. **Xbox glyphs only.** A PlayStation-layout pad reads "A" while its own
   button says "X".
3. **Pad plate only after a d-pad press.** A pad player who navigates the
   draft with the stick reads "HOLD SPACE" through the whole draft.

All three close the same way the prompt cards were fixed: a plate with NO keys
baked in, and the key line drawn over it with engine tokens. The engine knows
the device and the binds; we do not, and cannot (no server-side device read
exists — `bo3-menu-input-apis` memory, fact 4). That needs ONE new asset (§5A).

The overlay path is deliberately **not written dormant** in this pass: it
cannot be tested without the art, and the bind names it would use are not
proven until §3's legend has been seen in game. Sequence: see the legend →
make the frame → implement §6 → one `-GscOnly` build → test.

**Known one-way, staying:** a player who latches the pad (first d-pad press)
and then switches to keyboard mid-match keeps d-pad-only card switching for the
rest of that match. Lock still works on SPACE / F, so the menu is never dead —
the left card locks. No server-side read can tell the devices apart, so the
latch cannot be two-way without reintroducing the awkwardness the pad players
reported (v14.20). Rare, bounded, documented.

## 5. Assets

### 5A. `i_tod_hint_frame` — the blank hint plate (REQUIRED for §4)

One PNG, **460 × 70**, transparent background, the exact plate of
`i_tod_hint_switch_kbm.png` with everything inside it removed. Same pill
shape, same dark navy fill, same thin cyan-white rim glow, same corner radius,
same drop shadow. No text, no keycaps, no icons, no separators. Drawn at
280 × 43 (switch line) and ~200 × 30 (under each card), so it must read clean
at both — no fine interior detail.

Prompt:

> A wide rounded rectangular UI plate for a video game HUD, 460 by 70 pixels,
> PNG with transparent background. Dark navy-black fill, a thin glowing
> cyan-white rim along the edge, soft outer glow, subtle inner vignette,
> cyberpunk neon style. COMPLETELY EMPTY inside — no text, no icons, no
> buttons, no dividers. It is a background plate that text will be drawn on
> top of later. Match the exact proportions and style of the attached plate
> [attach `i_tod_hint_switch_kbm.png`], with all of its contents erased.

Install: `source_data/tod_ui_images/_images/i_tod_hint_frame.png`, a GDT
entry cloned from `i_tod_hint_switch_kbm` (same flags), one `image,`
zone line. **Full build** (a `.gdt` edit is always a full build).

### 5B. Optional re-bakes of the existing KBM plates (only if §5A is NOT done)

If the baked plates stay, two small improvements:

- `i_tod_hint_lock_kbm` — "HOLD **SPACE** / **F** TO LOCK". F is the
  interact key every CoD keyboard player already holds at doors; today the
  plate never tells them it works here.
- `i_tod_hint_switch_kbm` — "SWITCH: [mouse L] / [mouse R] / **V** │ LOCK:
  HOLD **SPACE** / **F**".

Prompt (per plate): *the same plate as the attached, same font, same keycap
style, same colours, with the text changed to "<text above>"; keep the width
460 and height 70; PNG, transparent background.*

These become redundant the moment §5A ships — the overlay line writes
`HOLD [{+gostand}] / [{+activate}] TO LOCK` by itself.

### 5C. Nothing else

No card art, badge, banner or pause plate carries an input glyph. Verified by
grep over every `RegisterImage` in the two card menus and the pause menu, and
by opening the five `i_tod_hint_*` PNGs (§1). The class draft banner's
"PERMANENT FOR THIS RUN" has no key in it.

## 6. The overlay path (implement when §5A lands — one build)

`tod_upgrade.lua` and `tod_class_select.lua`, gated by a new
`USE_HINT_FRAME_ART` flag next to the other `USE_*_ART` flags:

1. `art.hintFrame = RegisterImage( "i_tod_hint_frame" )` under the flag.
2. `SwitchHintImg` (upgrade: 280 × 43 at y 650; draft: y 568): keep the
   image element, set it to `art.hintFrame`, and add ONE `UIText` child over
   the same rect inset 14 px, `fonts/ltromatic.ttf`, centered, alpha driven
   together with the image. Text:
   - keyboard / pre-latch: `^5SWITCH:^7 ^3[{+attack}]^7 ^3[{+speed_throw}]^7 ^3[{+melee}]^7   ^5LOCK:^7 HOLD ^3[{+gostand}]^7`
   - pad (after `CoD.TodPad`): `^5SWITCH:^7 D-PAD   ^5LOCK:^7 HOLD ^3[{+gostand}]^7`
   - draft pad line keeps `/ STICK` (the draft never gates the stick).
3. `card.HintImg` (under the focused card): frame + a `card.HintText` child,
   text `HOLD ^3[{+gostand}]^7 / ^3[{+activate}]^7 TO LOCK`; the LOCKED plate
   (`art.hintLocked`) stays baked — it has no key on it — and hides the text.
4. Every place that does `HintImg:setImage( UsingController() and pad or kbm )`
   (four sites: two per menu) becomes `if USE_HINT_FRAME_ART then frame + text
   else <unchanged>`.
5. Re-set the text whenever the plate is shown, never only at construction —
   the expansion happens when the string is set.

The `UsingController()` latch stays for the INPUT gating; under this path it
only decides the D-PAD wording.

## 7. Test checklist (the user's job — boot is all the build proves)

Keyboard:
- [ ] Walk to the first door: card reads **Hold F To Open** with the F gold,
      one line, no overlap with the price.
- [ ] Rebind USE to E in Options & Controls, walk back: **Hold E To Open**.
- [ ] Perk machine (power on): **Hold F To Buy**. Ammo crate: **Hold F To
      Buy**. Teleporter: **Hold F To Use**. Power switch: **Hold F To
      Activate**.
- [ ] Pause menu, right column under the buttons: **UPGRADE CARDS / SWITCH:
      MOUSE1 MOUSE2 or V   LOCK: HOLD SPACE or F**. Every token rendered as a
      key name — no literal `[{+...}]` anywhere. Note any that fail; that is
      the §3 probe result.
- [ ] Round-1 cards: MOUSE1/MOUSE2 switch, hold SPACE locks, hold F locks.

Controller (Xbox layout, then a DualShock if one is around):
- [ ] Door card shows the pad glyph (X / Square), not "F".
- [ ] Pause legend after a d-pad press: **SWITCH: D-PAD   LOCK: HOLD [A]**
      with the engine glyph; before any d-pad press it shows the keyboard
      line with RT / LT / R3 glyphs — that is correct, those lanes are live
      until the latch.

## 8. Recommendations not applied (user decisions)

1. **Draft timeout picks a RANDOM class, not the focused one** (docs/61 §
   finding, still open). A first-time keyboard player who browses to HEAVY,
   never realises the lock is a HOLD, and hits 0:00 gets a random class for a
   50-floor run. The upgrade panel locks the focused card on timeout; the
   draft could do the same — one line in `run_select_input` (`return sel`
   instead of `return 0`). It contradicts the standing "random on timeout"
   rule, so it is a call, not a fix.
2. **Workshop description has no controls line.** Suggested BBCode for
   `zone/workshop.json` (paste-ready):
   `[b]Keyboard:[/b] card menus switch with MOUSE1 / MOUSE2 or V, lock by holding SPACE or F. [b]Controller:[/b] d-pad switches, hold A locks. Every prompt shows the key you actually have bound.`
3. **Advertise F on the lock plate** — §5B, or free with §5A.
