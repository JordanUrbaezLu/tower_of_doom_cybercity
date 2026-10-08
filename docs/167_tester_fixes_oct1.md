# 167 — Tester fixes, 2026-10-01 (post v19.66)

Source: the lead tester's list relayed by the user on 2026-10-01, plus Nikolai's
screenshot of the party-row gap. Work order: checklist first, implement, tick on
implementation, then review every change (no game launch — the user tests).

Legend: `[ ]` open · `[x]` implemented · `[R]` implemented + reviewed (tests/gates, no game) · `[~]` partial · `[-]` not done (reason given)

## Checklist

| # | Item | Status |
|---|---|---|
| 1 | Mage HEALING AURA: green ground ring showing the aura's range and how long it has left | [R] |
| 2 | Healing Aura Lv6 revive: green "+" signs burst on the REVIVED player's screen | [R] |
| 3 | Mage + Widow's Wine: HUD indicator for "protection ready" vs "recharging" | [R] |
| 4 | Staff seen from a distance: parts vanish, the rest floats in the hand | [R] |
| 5 | Slasher: weapon inspect shares the USE key — blocks doors/ammo/perks and attacks | [R] |
| 6 | Slasher: bat lunge too long, cannot be cancelled by swinging again | [R] |
| 7 | Slasher: grenade pistol while downed | [R] |
| 8 | Slasher: hoop reward 20 -> 50 | [R] |
| 9 | Restart freezes on one frame (menu still navigable), restarts ~1 min later (9b: solo/split-screen back on the kit's own restart) | [R] |
| 10 | Split-screen: Restart missing from the pause menu (only End Game) | [R] |
| 11 | Party rows: one-row gap between the nearest teammate and your own row | [R] |
| 12 | Scoreboard + end screen: "Round Based Zombies" under the round -> map name / floor | [R] |
| 13 | Loading screen: "bring back the Tower of Doom loading screen" | [-] |
| 14 | Mouse wheel does not scroll the upgrades list | [~] |
| 15 | Xbox controller icons bleed into the chat on the scoreboard (Tab/Select) | [R] |
| 16 | Heavenly altar: top circle/logo breaks when backing toward the teleporter room | [R] |

## Build

FULL BUILD OK 2026-10-01 11:13:27 Eastern, FF 147,492,544 B (own cod2map + LED bake;
navmesh gate: both towers one walk). scripts / zone_source / ui diffs clean, nothing
synced after the .ff, tools-root tod_weapon_twins / tod_staff_origins / tod_staff_pap /
tod_heavenly_altar GDTs == repo. Sound bank 197.9 MB (one known retry, recovered);
the 10 waived linker messages only; 109/109 weapon models linked; 0 missing techsetdef.
Ledger: fx tod/mage/fx_healing_aura_ring packed; tod_staff_world + the three ice world
models lodCount 1 at full triangles (was 6 LODs); altar 7 LODs unchanged geometry.
Log tmp/tester_fixes_20261001/build.log. Dev / god / TOD_MOCK_PARTY still ARMED (the
v19.66b test setup - the mock rows show the new party spacing). UNPLAYED.

RESTART SECOND PASS (9b): -GscOnly BUILD OK 12:06:47 Eastern, FF 147,493,696 B; both restart gates ran inside it (Restart lane OK, 28 controls; restart menu test 11 cases); scripts / zone_source / ui diffs clean, nothing synced after the .ff, bank 197.9 MB (one known retry, recovered), the 10 waived only, 109/109 weapon models. Dev / god / TOD_MOCK_PARTY still ARMED (the v19.66b test setup - restart does not depend on them). Log tmp/restart_kit_20261001/build2.log. UNPLAYED.

## Findings and changes

Every change below was reviewed without running the game: the code was re-read, and
each item has an executed test (Lua 5.1 under lupa, or node/python against the real
sources) or a build gate, with a negative control where the bug could be reproduced.
In-game look and feel is the user's test.

**1. Healing Aura ground ring.** 12 green markers on THIS cast's radius (256..416 by
level) around the caster's feet, following them. The ring is also the clock: one
marker goes out every 5 s / 12, clockwise from the caster's facing at the cast, and
the last goes out with the last pulse. A root entity follows by MoveTo (a LinkTo to
the player would spin the ring with the camera); the root's own thread owns and
deletes every marker on expiry / death / disconnect. Marker FX
`tod/mage/fx_healing_aura_ring` = the luck soul's proven core emitter (same Origins
donor) recoloured green, 24 u, no light / child / cloud (`tools/gen_heal_ring_fx.py`,
`--check` in the build). Logs `[TOD_HEAL] RING_ON` / `RING_OFF` (dev).
_tod_mage_elements.gsc, zm_tower_of_doom.zone.

**2. Lv6 revive "+" burst.** `heal_pulse` revives through `heal_revive`: stock
`auto_revive` unchanged, then `tod_heal_burst` to the REVIVED player only (after the
revive returns; nothing if they bled out first). `CoD.TodHealBurst` (tod_upgrade.lua):
14 green "+" glyphs in the map typeface, scattered around the screen centre, rising
and fading over 1.1-1.55 s. Log `[TOD_HEAL] REVIVE_BURST` (dev).
`tools/test_player_feedback.js` (revive once, Lv6/Dark only - now through the new
name) + `tools/test_tester_fixes_1001.lua` (the burst fires only on its event).

**3. Mage + Widow's Wine.** Root cause: a Mage who buys Widow's Wine HOLDS web
grenades (stock swaps the lethal; `DisableOffhandWeapons` only stops the throw) and
each one is a contact web, but the Mage's lethal tile shows Healing Aura, so the
count had nowhere to show. New third tile left of Blink (x1110), the offhand slot's
own factory: spider icon (purple with PhD), the engine's live lethal count; bright =
webs left (protected), DIM at 0 (next hit lands), hidden for non-Mages and Mages
without the perk. Pure Lua (AetheriumLoadout.lua). Executed in
test_tester_fixes_1001.lua through every state.

**4. Staff pieces floating at range.** The third-person shaft `tod_staff_world`
(fire + lightning) and the ice staff's three world models kept the donor's
autogenerated 50/25/12/7/4% LOD chain (compiled ledger: 6 LODs, 10,424 -> 415 tris);
the heads beside them were made single-LOD on Sep 27. Decimation erases a thin shaft,
so past the first switch a teammate's staff was a full head floating at the hand.
The four world models now carry no generated LODs (`tools/staff_world_lods.py`,
in place, 5 switches x 4 blocks, nothing else; manifest pin re-stamped;
build_staff_presentation.py keeps the rule on regen). Gated before sync and
post-link (`lodCount == 1`). Full build.

**5. Blade inspect blocks doors / ammo / perks / attacks.** BO3 has no inspect
field: the T9 melee ports put the inspect clip in `reloadAnim`, so the RELOAD press
played it, and a controller's X is `+usereload` - the same button as every buy. A
reload cannot be cancelled from script. Fix (gen_tod_twins.js): every blade form
(bat, katana, Stormbreaker - 37 forms) has no reload animation and a one-frame
reload (0.05 s / 0.0375 s PaP), so the reload press has nothing to do and the button
is free for the buy. The clip stays in `lowReadyLoopAnim` (unused here).
⚠️ This REMOVES the inspect animation: the user's "the animation is awesome" is
acknowledged; making it cancellable is not possible with a reload. A script-driven,
cancellable inspect (low-ready) is a possible follow-up but needs a native test.

**6. Bat lunge too long / cannot cancel.** The lunge's kill recovery
(`meleeChargeFatalTime`) was in no speed set: SLASHER_SWING_MULT, PaP and KNIFE SPEED
shortened the swing and left the lunge at 0.6 s (0.7 s on PaP, which kept the port
value). Now in MELEE_KEYS with the left-hand variants: base 0.54, PaP 0.405, PaP +
KNIFE SPEED 5 0.30 - never longer than the swing (gated in test_baseball_bat.js). The
melee queue window 0.2 -> 0.35 s on every blade, so a second press during a lunge
fires the next swing the moment the blade is free.

**5 + 6, FOLLOW-UP (2026-10-02, after the user played v19.69):** "We also broke the
inspect on the bat. Please fix. And i think we need to remove the lunge on the bat. We
tried to fix multiple times where we can animate out of the lunge if we have a swing
ready and same with inspect but just doesnt seem we can solve." THE LUNGE IS GONE
(gen_tod_twins.js `lunge: false` -> the roster-wide MELEE_NO_LUNGE: meleeChargeRange /
meleeLungeRange 0 on all 12 bat forms; every swing is the plain swing, nothing to
cancel). THE INSPECT IS BACK ON A DIFFERENT LANE: the clip was always ALSO the bat's
`lowReadyLoopAnim` (1.8 s), and low-ready is a script-controlled weapon state
(`self SetLowReady( true/false )`, stock _zm_magicbox uses it). NEW
`_tod_bat_inspect.gsc`: a reload press (R / a pad's X) while holding the bat enters
low-ready, a loop holds it for the clip and leaves it EARLY on attack / melee / sprint
/ weapon switch / down / weapons disabled - cancellable by construction. The reload
lane stays one-frame, so X at a door still buys. UNPROVEN natively: that SetLowReady
plays the clip on a melee weapon in a usermap, and whether the engine lets the swing
interrupt low-ready itself (the loop leaves it on the press either way). Log
`[TOD_BAT_INSPECT]` (tod_dev). Gate: test_baseball_bat.js (lunge 0/0, low-ready
lockstep 1.8 s, the module's exits, wiring).

**7. Slasher downed pistol.** Stock's last-stand pick takes the FIRST pistol-class
weapon carried; all three Slasher sidearms are pistol-class, so a downed Slasher
crawled with its machine pistol. `level.zombie_last_stand` (stock's replace hook in
`laststand_give_pistol`) -> `tod_classes::down_pistol_give`: a Slasher gets the
map's down pistol (`level.laststandpistol`, the PaP'd MR6 the tester calls the
grenade pistol); `hadpistol` cleared so stock's revive takes it back and the
sidearm is there again. Every other class: stock's give, line for line. Log
`[TOD_LOADOUT] DOWN_PISTOL` (dev).

**8. Hoop 20 -> 50.** `TOD_HOOP_PTS`; the popup reads the same constant.

**9. Restart freeze.** Root cause (stock T7 Lua dump): `GoBack` only pops the menu;
`StartMenuGoBack` is what clears `cl_paused`. v19.63 closed with `GoBack`, so in
SOLO the server stayed paused and the `tod_go|restart` request waited - one frozen
frame with a live UI - until something else unpaused (reopen + close the menu).
`TodGoClose` = `cl_paused 0` + `StartMenuGoBack` before every host request (Restart
Level, Restart Map, End Game), stock's own popup order.

**9b. Restart, second pass (user: "MY main issue people are complaining about is the
restart button ... I believe the stock aetherium HUD had this perfectly set up ...
once we started tweaking i think we got lost in our own code").** History, read from
the code and the Workshop comments: the kit's Restart (`GoBack` + `Engine.Exec(c,
"map_restart")`, shown to everyone) worked in solo for months; its one complaint was
CO-OP (Tixy, Sep 7: "it kicks the other player out"). v19.16 hid it in co-op (that hid
it in split-screen too, and Biffbrooks11 Sep 29 read it as broken); v19.63 moved EVERY
restart onto a server request and caused the solo freeze. **Now:** every human at this
machine (solo / split-screen) -> the kit's restart and leave VERBATIM
(`TodKitRestart` / `TodKitLeave`); a host with a teammate on ANOTHER machine -> the
server request (unpause + close first), the only lane that keeps that teammate.
Stock does the same split: its RestartGamePopup runs a console command for OFFLINE /
SYSTEMLINK and a server menu response otherwise (T7 Lua dump, OverlayUtility.lua).
The deciding fact: `party_push` host value 0 (not the host machine) / 1 (host +
remote teammate) / 2 (host + all local), from `IsLocalToHost()` per human; dvar
`tod_party_remote` is the host machine's instant fallback (written at level start); with neither, it is a teammate's machine in its first seconds -> the server request, which the server ignores for a non-host. A newly
built HUD and every restart clear the cached game-over flag (the Lua VM outlives a
restart; a stale `go` opened the next pause menu as Restart Map / End Game).
Checks: `tools/test_restart_menu.lua` (NEW, lupa, in the build) loads the real menu
and presses every button in 11 party shapes, recording the engine calls; the v19.66
shape, the kit shape and the 11:13 v19.68 shape each FAIL it.
`tools/test_coop_restart_lane.js` re-written for the contract, 28 negative controls.
**Still unproven natively:** the online co-op server restart (`map_restart( true )`,
stock's MP round-switch call) has never run in this map. If it works but the
scoreboard keeps the last game's kills / downs, that is `map_restart( true )` keeping
player stats (stock only fills undefined stats) - one-line follow-up.

**10. Split-screen Restart missing.** `CoD.TodParty` was one table in the one client
Lua VM both local players share; the guest's host=0 landed last and hid Restart on
both screens. Party facts are now also filed per controller (`CoD.TodPartyBy`) and
read that way; the server's host test is `go_is_host()` = `IsHost() ||
IsLocalToHost()` (stock offers Restart to everyone at the lobby-host machine).
`tools/test_coop_restart_lane.js`: 16/16 negative controls incl. the exact v19.63
GoBack shape.

**11. Party row gap.** The kit's slot 1 (`baseYTop` 524) dates from the 87-tall
party PLATE whose content sat in its lower half; v17.4 removed the plate and packed
the content into the top, leaving a 51-unit hole above the local row in every party
size (v19.63's rank stacking could not close it). 524 -> 570.5: the nearest
teammate's name is one 43 pitch above the local name, like every other step.
test_tester_fixes_1001.lua: all 7 occupancy shapes; the old value fails at 89.5.

**12. "Round Based Zombies".** Both lines (scoreboard + pause / game-over header)
now name where you are: FLOOR n / THE CROWN / SPIRE FLOOR n / THE SUMMIT (map name
until the first push). New int event `tod_floor_label` from the gauge heartbeat
(`_tod_gauge::floor_label_code`, change-gated + 5 s re-send), cached per controller.

**13. Loading screen - NOT DONE (engine limit).** A usermap cannot replace the static
loading image: map 1's KB has four independent proofs (the LUI short-circuits to
`img_t7_mod_loading` with no per-map refresh; `loadingimage.png` is inert; the 41
loadscreens live in core_patch.ff, which usermaps `ignore`). This map never shipped
one - there is nothing to "bring back". The supported alternative is a loading MOVIE
(`zone/video/zm_tower_of_doom_load.mkv`, H.264 720p30, no audio) shown in SOLO only;
an encode the engine rejects can break the load, so it needs the user's test.

**14. Mouse wheel through the cards - PARTIAL.** The wheel's default binds are
`weapnext` / `weapprev` (one-shot commands, no button state) and the card panel is
HUD-layer (it receives no LUI input), so no proven lane exists. Added: the
weapon-switch button (Y / X) as a flip lane, and a dev probe `[TOD_CARD_WHEEL]` that
logs every candidate lane per tick during a pick - one KBM test settles it.

**15. Controller icons over the scoreboard.** Stock's chat moves INTO the board's
bottom-left when it opens (ScoresUp / ScoresForceUp, y470..720) and was the one
element the board's HUD hide never covered. The chat containers now fade with the
board and return when it closes (their own states never touch the container
alpha). Cause inferred (no screenshot of the icons) - if they persist, a screenshot
says which element draws them.

**16. Altar crest breaks backing into the teleport bay.** Measured on the shipped
LOD binaries (front-view depth maps of the crest): the triangle emblem and inner rings
change from LOD2 and are mostly gone by LOD3 - and the switches sat at 500 / 850,
exactly the distances from the base altar (0,-320) into the bay (380..960). LOD
switches now 1000 / 1500 / 2100 / 2800 / 3600 / 4500: LOD0 everywhere in the arena
and the bay. `heavenly_altar/verify_native.py` asserts LOD1 >= 1000 and the order.

## Restart test setup (2026-10-01, test build - DISARM before publish)

User: "Ill also need a way to test coop so maybe we can mock players best possible. I
need to test the restart button." Flags: `tod_dev` ON, `tod_god` OFF (to reach the
game-over menu you must die), NEW `tod_dev_coop_mock` ON, `TOD_MOCK_PARTY` OFF.

- **Rounds 1-3 = solo.** Restart Level and the game-over Restart Map take the kit's
  console restart. Log: `[TOD_GAMEOVER] RESTART_BACK lane=kit` then `RESTART_UP`.
- **Round 4 on = online co-op host.** The dev Mage bot joins and counts as a teammate
  on another PC (`[TOD_GAMEOVER] PARTY humans=2 remote=1 restart_lane=server`,
  `[TOD_MAGE_DUMMY] COOP_MOCK JOINED`). Restart Level -> `MENU ... want=restart`,
  `RESTART map_restart`, then in the new level `RESTART_BACK lane=server` (its
  `bots=` says whether the stand-in stayed connected through the restart - the
  analog of a real teammate) and `RESTART_UP`. Going down ends the game like a wiped
  party (`COOP_MOCK WIPE`); the game-over menu's Restart Map / End Game use the
  same server lane (End Game = `END ExitLevel`, back to the menu).
- **A restart that freezes** shows `RESTART_BACK` with no `RESTART_UP`, and
  `RESTART_WAIT` lines every 5 s with `playing= expected= connected=` - the counts
  stock's start-up is waiting on. `RESTART_BOT_DROP` = a leftover bot removed (dev).
- What the stand-in is NOT: a real second machine. The network side of an online
  co-op restart (a real teammate's client reloading) is only proven by a real co-op
  test.

**9c. Co-op game-over Restart "does nothing" (stand-in test, 13:10 log).** The game-over menu's
response never reached the server (no `MENU` line); stock's end_game has already marked the match
ended. The host's request now also writes dvar `tod_go_request` (the host machine's menu and server
share one dvar table), read by `go_request_watch`; request first, then close. Log `REQUEST via=host_dvar`.
Build 13:27:37, FF 147,496,896 B. Same build: dev gives every perk except Quick Revive (`[TOD_DEV_MAX] PERKS`).

**1b. Healing Aura area, second pass (user: "Should be a green pulse or area that looks nice for the radius").**
The 12-marker ring ran (RING_ON 12/12 in the log) but its 6-24 unit glows sat half inside the floor.
Now one FLAT effect per radius (tools/gen_heal_area_fx.py): a green rim exactly on the radius (stock
Domination ring x6 turned 30 deg - the texture is two bracket arcs), a soft bokeh fill, a pulse from the
caster to the rim each second, rising green motes; the host faces up and follows the caster. Logs
`[TOD_HEAL] AREA_ON / AREA_FX / AREA_OFF`. Build 14:21:58 (invisible: effect played in the host's first frame),
fixed 14:41:55 (two-frame wait); USER CONFIRMED "Healing aura worked". The restart fixes were confirmed by the
user's 13:52 stand-in run.
