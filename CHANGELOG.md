# Changelog

Newest first.

> OPEN-ITEMS FREEZE 2026-08-23: docs/32_pending_fixes_backlog.md records every
> known-open thread at the beta push (leak hunt in flight, perk-icon art path,
> live-verify list, deferred minors). Read it before starting new work.

## 2026-08-26 (v12.8) — NON-ENGLISH CLIENTS COULD NOT LOAD THE MAP (language fastfiles)

(Workshop report, French player PatesALaCarbo: "impossible to start the map:
Console bug say : ERROR: Could not find zone 'fr_zm_tower_of_doom'".)

**ROOT CAUSE: the game loads a per-language fastfile named
`<prefix>_<map>.ff`, and every build this map has ever shipped linked
`-language english` ONLY** — so the zone dir held `en_zm_tower_of_doom.ff` and
nothing else, and every client whose game runs in French/German/Spanish/etc.
failed AT MAP LOAD with exactly the reported error. Not a code bug — a
publish-pipeline gap, invisible to us because this machine's install is
English.

**FIX: `build_map.ps1 -AllLanguages`** (new switch, section 4b) — after the
verified English pass it links french, german, italian, spanish, portuguese,
russian, japanese, simplified_chinese and traditional_chinese, one SEQUENTIAL
linker pass each (the one-linker-at-a-time rule holds inside one build too).
Per-pass: a BlackOps3-running check (the mid-build game-launch poison applies
to every pass), and PREFIX-AGNOSTIC verification — a pass is good if it wrote a
fresh `*_<map>.ff`, no hardcoded fr/ge/sp table to go stale. After all passes
the `.all.sabs` bank guard is RE-ASSERTED, because the flaky wav converter can
strand a stub bank on any pass while exiting 0 (the 2026-08-24 failure class) —
a late language pass must not silently undo a build the English pass verified.
Each language ff is ~230 KB (localized strings only; our .str files are
English-only so other languages fall back to English text — the standard
Workshop-map arrangement).

**PUBLISH RULE GOING FORWARD: publish builds use `-AllLanguages`.** The fix
reaches players only via a REPUBLISH — the Workshop item must carry the new
language ffs.

**LIVE RESULTS (build 15:14-15:16):** 7 of 9 tokens accepted — fr_ ge_ it_
es_ bp_ (portuguese = Brazilian prefix) ru_ ja_ all written at ~230 KB
(japanese 300 KB), bank re-verified healthy (100.3 MB) after all passes.
**OPEN: `simplified_chinese` / `traditional_chinese` were REJECTED (exit
1000001) — the linker uses some other token for the two Chinese variants.**
User call 2026-08-26: French is the reported breakage, ship what we have;
Chinese-locale clients still cannot load the map until someone finds the right
token (try the launcher's own language checkboxes and read the command it
issues, or probe candidates: chinese_s/chinese_t, schinese/tchinese,
chineses/chineset).

## 2026-08-26 (v12.7) — zombie late-game speed growth nerfed 0.35% -> 0.28%/round

(User: "Lets make that 0.28%. Slight nerf on zombies. Then full rebuild.")

`TOD_ZSPEED_STEP` 0.0035 -> **0.0028** (`_tod_zombie_speed.gsc`) — the
post-round-15 sprint-rate growth, uncapped as before. The 0.8 -> 1.0 climb over
rounds 1-15 is untouched. Effect compounds with depth: round 30 goes 1.0525x ->
1.042x, round 50 goes 1.1225x -> 1.098x, round 100 1.2975x -> 1.238x. Also
fixed while in there: the `rate_for_round` tail comment had said "+0.3%" across
three retunes of the define (the exact drift the function's own header warns
about) — it now defers to the define. CLAUDE.md brief updated to match.
Full rebuild (user-requested publish-grade; the change itself is script-only).

## 2026-08-26 (v12.6) — ZOMBIE BLOOD RESTORED + FULL PUBLISH BUILD

(User, after testing the v12.5 removal: "Okay you can add it back. Doesnt seem
fixed. Maybe its just my eyes. Lets add it back and the full rebuild to
publish.")

**Zombie Blood is back, byte-identical to its final debugged v12.3 state** —
wholesale restore of the five v12.5 backup files (tray timer + refcount-safe
clear + scoped laststand guard + keep-alive loop + the revive-press guard all
intact; verified: 5 gsc refs, csc pair, tray row, zone lines, packed CSV rows
5453-5455). The GDTs/sounds were never touched, which is what made this a pure
code restore. The v12.4 NEUTRAL MAP-NAME VISION STAYS regardless of the tint
verdict — the file is a stock contract (`visionset_mgr` resolves the map-name
vision for every client) and shipping it is correct even if it turns out not to
have been the tint.

**THE TINT VERDICT IS INCONCLUSIVE** ("doesn't seem fixed. Maybe its just my
eyes"). Recorded honestly for the next session: the removal test's design means
BOTH hypotheses (zombie blood, which is now exonerated by construction — the
tint persisted with it fully absent — and possibly the missing-vision theory)
need the follow-up discriminator. THE ONE-MINUTE TEST NEXT SESSION: stand in
the base arena, then climb to mid-tower. The map's DESIGNED look includes dense
purple-blue smog at street level that clears with altitude
(`_tod_atmosphere.gsc`) — if the "tint" fades as you climb, it was the designed
fog all along; if a warm orange grade persists at altitude (where the air is
deliberately clear), the vision theory is wrong too and the hunt reopens with
three eliminations banked (scripts were exonerated by 4 independent sweeps,
blood by the v12.5 removal, and the vision file now provably ships — packed CSV
row 600).

**FULL BUILD** (publish-grade): geometry lint green (zero regressions), cod2map
BSP 7.8 MB + navmesh @ 1:39:21 PM, Radiant LED recompute BAKED, linker OK —
fresh 99.27 MB `.ff` @ 1:40:30 PM, deployed tree diff-verified IDENTICAL. The
3 reflex_reddot warnings remain the documented pre-existing un-waived set.
**BEFORE THE ACTUAL WORKSHOP PUBLISH: CREDITS.** The zone/docs carry
credit-before-publish notes for Nastian (skybox), NSZ (zombie blood model/vox +
powerup pack sounds), ZoekMeMaar (free PaP model), Logical +
NateSmithZombies (powerups), GentlemanCheeseMan et al. (Xmas gun), Skye (CW
weapon ports), pmr360 (combat knife), Owen-C137 (Aetherium HUD), the six music
artists (CREDITS.md), and Treyarch mod tools. Verify CREDITS.md covers all of
these on the Workshop page text.

## 2026-08-26 (v12.5) — ZOMBIE BLOOD FULLY REMOVED (tint-isolation experiment, expected temporary)

(User: "Completely remove zombie blood from the game again. No mentions or
references of it in code. Then rebuild and ill test. If i still see the tint we
can bring it back and revert the removal.")

The powerup is GONE from the shipped game: the `_tod_powerups.gsc` define +
registration block + all four functions, the `.csc` include/add pair (the
toplayer clientfield unregisters symmetrically on both halves), the Aetherium
tray row, and the three zone asset lines (`xmodel,zombie_blood`,
`material,zombie_blood`, `image,i_tod_pu2_zombie_blood` — verified ZERO
zombie_blood rows in the packed CSV). Comment mentions scrubbed from
`_tod_endless_rounds`, the zone vision block and the sync script.
DELIBERATELY untouched (data, not code — and what makes the revert a pure
-GscOnly code restore): `nsz_zombie_blood.gdt`, the `tod_ui_images.gdt` icon
entry, the sound aliases + wavs, docs, CHANGELOG.

**Byte-exact pre-removal copies of all five touched files (blood in its final
v12.3 debugged state) + the revert recipe: `docs/zombie_blood_removal_backup_v12_5/`.**

HOW TO READ THE TEST — the v12.4 vision fix (the diagnosed root cause) is ALSO
in this build, so the tint should be gone regardless of this removal:
- tint GONE: expected; the user's planned RE-ADD is the step that closes the
  case (tint stays gone with blood back = blood exonerated, vision fix was it).
- tint STILL THERE: both the vision diagnosis AND the blood suspicion are
  wrong, and the hunt reopens with two hypotheses eliminated.

## 2026-08-26 (v12.4) — THE PERMANENT ORANGE TINT: the map-name vision never existed

(User: "ever since we added zombie blood there has been a weird tint on the
screen ... It's the typical tint ... orange red ... Origins was known for
having that. As soon as the game starts it seems like you have zombie blood
enabled." + their own hunch: "Maybe its part of the base game already" — which
was exactly right.)

**ROOT CAUSE — THE ENGINE SETS EVERY CLIENT'S BASE VISION BY MAP NAME, AND THIS
MAP NEVER SHIPPED ONE.** `visionset_mgr_shared.csc::finalize_initialization`
(stock, runs on every map) does `init_fog_vol_to_visionset_monitor(
GetDvarString( "mapname" ), 0 )` — so the base naked vision is literally the
asset `vision/zm_tower_of_doom.vision`, restored per-client by the manager
(including after every down/revive). No such file ever existed in this repo, in
the deployed tree, or in the packed `.ff` (the linker CSV had zero vision
rows). The engine resolved a MISSING vision and rendered its warm-orange
fallback: a permanent, boot-to-end, Origins-zombie-blood-style wash.

**WHY NOBODY COULD FIND IT: no script applies it, so every script-side search
was structurally guaranteed to come up empty.** The exoneration sweep that
preceded the find (13 checks, all clean) is itself the evidence trail: no
visionset call in any tod module or vendored pack, no stock asset-name
collision from the NSZ gdt, fog unchanged since v2.0, skybox/SSI since v1, all
LUI roots alpha-0 gated, no menu blur flags, no vision assets in any zpkg. The
tint also predates zombie blood — the file has been missing since v1; the
2026-08-21 attribution was coincidence (same-day full build / when co-op
scrutiny started). Zombie blood's own window is deliberately visionset-free
and never touched the screen.

**FIX — map 1's rule, ported verbatim** (its 2026-06-24 "gray screen on revive"
was the same mechanism from the other direction): ship
`vision/zm_tower_of_doom.vision` as a `rawfile,` zone line, byte-content ==
stock `default.vision` (copied from map 1's proven neutral file). NEUTRAL is
load-bearing, not a taste choice: the engine FORCE-RESTORES this file
per-client on every revive, bypassing any scripted `VisionSetNaked` — a tint
authored here would become a stuck-after-revive grade, which is precisely map
1's old bug. New `vision` mapping in `tools/sync_to_modtools.ps1` (COPY, not
mirror — map 1's rule). Verified packed: linker CSV row 600
`rawfile,vision/zm_tower_of_doom.vision`. GscOnly build, 12:47 PM.

If the map ever wants a REAL colour grade: author it as a separate vision asset
driven by `VisionSetNaked` from `_tod_atmosphere` (map 1's dormant-grade
pattern), and leave the map-name file neutral forever.

## 2026-08-26 (v12.3) — A REVIVE PRESS IS NOT A PURCHASE + Zombie Blood vs stock's refcount

(Second half of the "players going down" audit — module sweep, then six
adversarial verifiers. One claim REFUTED and deliberately not shipped.)

**EVERY SCRIPT-SPAWNED USE TRIGGER FIRED THROUGH A REVIVE (all six now
guarded).** Stock refuses every buy while the presser stands in a downed
player's revive trigger (`_zm_blockers.gsc:307`, `_zm_perks.gsc:407`,
`_zm_magicbox.gsc:570`, `_zm_traps.gsc:318`, `_zm_unitrigger.gsc:908` — its
comment is literally "revive triggers override trap triggers"). None of this
map's triggers did. The verifier's key correction: reviving is NOT arbitrated
by the engine's prompt selection — stock polls the raw USE button every frame
(`_zm_laststand.gsc:1129`), so the outcome was **BOTH**: the press that revived
a teammate ALSO bought the door / packed a gun / drained the crate / started
the finale / fired the teleporter. And a CRAWLER could buy doors himself — his
own revive trigger is `SetInvisibleToPlayer( self )` (`_zm_laststand.gsc:853`),
so the door trigger was his only use-ent, and `buy_trigger_wait` had NO
player-state gate at all (ECO-05, docs/24 — now closed). Worst case was never
points: a door buy calls `breather_unlock()`, which introduces a NEW ENEMY TYPE
irreversibly; the uplink spends 12k AND starts the 191 s finale with a body on
the ground. Guards added (`zm_utility::in_revive_trigger()`, arity 0, method):
doors (+ `is_player_valid` — silent, the player is HOLDING use), breather PaP,
ammo crate, uplink, personal stations (new `#using scripts\zm\_zm_utility` —
stock, no cycle; calls must stay `zm_utility::`-qualified, `zombie_utility`
ships a same-shaped `is_player_valid`), and the teleporter pads (SOUNDED — mute
pad refusals are exactly what the "wasn't activated" report was). ACCEPTED
COST: a body square in a doorway pins that door for the bleedout — the bubble
is 75 units, not the landing; stock accepts the same. `UseTriggerRequireLookAt`
deliberately NOT added (stock ships it commented out on every blocker path).

**ZOMBIE BLOOD vs STOCK'S IGNOREME REFCOUNT — three edits that land as one.**
Stock owns `.ignoreme` through a count (`ignorme_count` — STOCK'S OWN TYPO, no
second "e", verified by eye) and clears it 2 s AFTER every revive. (1)
`zombie_blood_clear()` no longer writes a hard `false` over a held refcount —
it recomputes from the count exactly as `_zm_utility.gsc:3852` does; a raw
false was destroying the 2 s post-revive grace, making a freshly revived player
instantly targetable. Deliberately NOT increment/decrement — clear() can run
twice per window and a double decrement would steal stock's last-stand
reference. (2) The countdown loop now RE-ASSERTS `ignoreme = true` each tick
(gated on `tod_in_blood`, which zombie_blood_clear undefines — a mid-window
down stops the re-assert): grab blood within 2 s of ANY revive (solo Quick
Revive included) and stock's pending decrement used to kill 13 of the 15 s of
invisibility while invulnerability stayed on — "blood did nothing". (3) The
laststand guard now checks `tod_in_blood` before clearing: it outlived its own
window (nothing notifies it at normal expiry) and fired on an unrelated down
ROUNDS later, stripping stock's last-stand ignoreme + the HUD state. That
also makes `tod_in_blood` a real guard — until now it had two writes and zero
reads repo-wide, the tell for what it was always meant to be.

**FINALE WAVES NO LONGER AIM AT CRAWLERS** (`_tod_endless_rounds`): the focus
picker used bare `isalive`, which is TRUE in last stand (stock sets health 1),
so a downed player could steer every spawn — at a 0.1 s floor that is half of
all spawns in a 2-player game — while stock's `set_ignoreme(true)` meant those
zombies would not even target him. Now requires upright (new
`#using laststand_shared`). Deliberately NOT `is_player_valid` with the
ignoreme flag — that would also drop an upright player in a blood window, who
should still draw spawns.

**`max_ammo_clip_watch` RESPAWN LATCH** (backlog item, now closed): the
on_spawned registration was unlatched and a co-op bleed-out respawn dispatches
`on_player_spawned` TWICE (`_zm.gsc:3338` then `_globallogic_spawn.gsc:465`),
so every respawn added TWO immortal copies. Standard `tod_*_on` field latch,
in the function so it covers any future caller. NOT
`callback::remove_on_spawned` — that deregisters for every player.

**REFUTED — bled-out players do NOT keep jump/offhand disabled on respawn.**
The script gap is real (no spawn path calls `AllowJump(true)`), but
`DisableWeaponCycling` is stranded by identical logic and bled-out players
demonstrably weapon-switch after respawn on every stock map — the engine's
player Spawn() clears this flag family. The "belt-and-braces" spawn re-assert
is a NET NEGATIVE: it would hand jump back to a player `menu_freeze`
deliberately took it from. Do not add it.

## 2026-08-26 (v12.2) — THE WORLD PAUSE vs PLAYERS GOING DOWN

(User: "what happened to the teleporter — a player died and i got to a floor 30
with teleporter and it wasnt activated, but before that I was using teleporters
fine" + "we need to investigate players going down and how that impacts the
game. There are a few bugs we see cause of this".)

Two audit agents swept the tree, then **seven adversarial verifiers each tried to
REFUTE one finding**. That pass earned its keep: it killed two headline claims on
reachability, corrected the severity of two more, and found one bug the original
audit missed. Only what survived is implemented here. Every item is GSC-only.

**THE TELEPORTER WAS REFUSING CORRECTLY, IN COMPLETE SILENCE — and the window is
far wider than "someone died".** `_tod_teleport.gsc` refused every use while
`level.tod_upgrade_pause` was set with a bare `continue`: no sound, no hint
change, beam still lit. Indistinguishable from a dead trigger. The reason it is
reachable **every fourth round** rather than being a freak coincidence:
`run_upgrade_event` holds the pause until every participant picks or 20 s elapse,
but `player_choice_flow` calls `menu_freeze( false )` **per player** the instant
that player locks a card — so the first player to choose is unfrozen and walking
around a still-paused world for the remaining ~13-18 s. A player who was DOWN or
DEAD when the event fired is excluded from the event entirely, so they are never
frozen at all and hit the window from its first second. That is the death link in
the report. Fixed by making the refusal audible (`zmb_no_purchase`, matching every
other refusal in the same loop) in all three affected devices: the teleporters,
the ammo crate and the personal upgrade stations. **The neighbouring laststand and
`is_player_valid` branches deliberately stay SILENT** — a downed player is holding
the use key trying to get revived, and a deny sound there would machine-gun in
their ear for the whole crawl. No fourth "paused" state was added to the pad
`refresh()`: it would flicker the beam every four rounds for no gain.

**GOING DOWN WITH THE CARDS UP DISARMED YOU FOR UP TO 15.7 s.** `menu_freeze`'s
laststand check is a ONE-SHOT ENTRY test — it refuses to freeze someone already
down and never looks again — while `wait_for_choice` ends only on `disconnect`.
The killer detail, verified against stock rather than assumed: **stock's last-stand
path never calls `EnableWeapons()`.** It uses `DisableWeaponCycling` /
`EnableWeaponCycling` (`_zm_laststand.gsc:290`, `:369-403`); nothing on the down,
bleedout or revive path clears a `DisableWeapons()` flag. Stock itself uses that
builtin as a firing lock (`_zm.gsc:4855`). So the crawl pistol was given, switched
to, held on screen — and could not be fired. `wait_for_choice` now `break`s on
laststand into its existing timeout exit, dropping the window to ~0.75 s. **The
upgrade is NOT forfeited**: `apply_upgrade` only refuses a timed-out TIER card and
`player_choice_flow` already falls back to the other card. Reachable despite the
AI freeze because the Panzer's FLAMETHROWER BURN is stock `_burnplayer.gsc`'s own
per-player damage loop and knows nothing about the pause — and with Panzers every
5th round, events every 4th, and endless rounds starting the next round while the
last Panzer still lives, that overlap is routine.

**`menu_freeze( false )` HANDED JUMP BACK TO A CRAWLING PLAYER** — the mirror-image
bug, found by the verifier and missed by the original audit. The unfreeze ran
unconditionally, undoing stock's own last-stand restriction (`_zm.gsc:2497`) and
leaving a downed player hopping while crawling. Now guarded. Safe because stock
restores jump itself on every revive path (`_zm_laststand.gsc:965`, `:1372`).
`EnableOffhandWeapons` is deliberately left alone — it would need its own
stock-restore audit for a smaller payoff, and stock's `revive_give_back_weapons`
already calls it.

**A DISCONNECT MID-PICK FROZE THE LOBBY FOR THE FULL 20 s.** `player_choice_flow`
carries `self endon( "disconnect" )` and does its `level.tod_upg_pending--` last,
so a leaver's decrement is lost and the wait loop ran to `TOD_UPG_CHOICE_TIMEOUT
+ 5`. The loop now re-derives the count from `participants` each tick and
**clamps DOWN only** — authoritative against any future incrementing path, and it
can never resurrect a finished pause. `tod_upg_done` is set immediately before
each decrement with no yield between (verified at both sites), so the derived
count equals the counter for every connected player. `player_choice_flow`, both
its endons and both decrement sites are byte-identical — no pick behaviour
changed. Deliberately NOT fixed by swapping the endon for a disconnect watcher
(double-decrement risk), and `end_game` was NOT added to `run_upgrade_event`:
that would skip the `set_world_pause( false )` and freeze the world forever.

**GOING DOWN AT A ROUND BOUNDARY SILENTLY WIPED YOUR WHOLE LUCK BAR.** The
`p.tod_luck_bar = 0` reset rode a `GetPlayers()` loop, so a player excluded from
the event by the downed/dead filter — dealt no cards, given no roll — still paid
the full bar for it. Now scoped to `participants`.

**BLEEDOUT RAN DURING THE PAUSE.** Stock's `Laststand_Bleedout` decrements on a
real-time `wait(1)` and knows nothing about the world pause, so a player already
crawling burned up to 20 s of a ~30 s clock while every living teammate was pinned
at `SetMoveSpeedScale( 0.001 )` and physically could not reach them. The paused
seconds are now credited back. Safe against stock's anti-cheese clamp:
`Laststand_Bleedout` captures its comparison value ONCE before its loops
(`_zm_laststand.gsc:538`), so the snap-back at `:545-551` cannot be tripped by a
later field write, and both loops re-read the field each iteration. **Accepted
cosmetic limit: the Aetherium bleedout bar animates a fixed client-side tween, so
credited seconds do not show — the bar can read empty while the player is still
revivable. Do NOT extend the Lua to chase this.**

**Two small ones.** `swap_primary`'s ≤1 s re-switch retry loop now `break`s on
laststand — the engine owns the weapon during a crawl and re-issuing
`SwitchToWeaponImmediate` only yanks the pistol away. **`break`, never
`return false`**: the swap must still complete atomically through its
`TakeWeapon`, or the player is left holding both gun forms. And
`solo_upgrade_flow`'s both-cards-dead exit now clears `todUpgShow` — the one exit
that could leave a lit card panel up, because the round event that killed the
in-flight pick never repaints for a player it excluded. **Correct in that branch
and nowhere else**: clearing on the pause check's early return would blank a live
event's freshly painted cards.

**REFUTED — deliberately NOT implemented, with reasons, so nobody re-proposes
them.** (1) A `menu_freeze` respawn-side watchdog: both endons on
`player_choice_flow` are terminal to the match or the player, death does not kill
the flow, and both input loops are provably bounded — no live defect. **And the
intuitive version is an active trap: clearing `tod_menu_frozen` on spawn makes
`menu_freeze( false )` early-return, skipping `EnableWeapons()` and creating a
PERMANENT soft-lock.** If anyone proposes "just clear the latch on respawn", say
no. (2) A laststand guard on `tier_up` itself — six guards already close that
path; only the `swap_primary` race was real. (3) docs/24's "defer the event while
anyone is down" — strictly worse, it keeps the horde live on the downed player's
bleedout clock. (4) `tod_swap_busy` / `tod_tier_busy` self-heal — the latches are
per-player entity fields destroyed with the entity, and every `end_game` site is a
terminal game-over, leaving only an unsubstantiated runtime-error path; the
recipe is in the workflow output if a trigger ever shows up.

## 2026-08-26 (v12.1) — player-report batch: respawn UI loss + Zombie Blood tray timer

(Workshop reports: "when you get finished and you spectate your team and
respawn half of the UI go away — you can't choose the upgrade, you can't see
the luck, you can't see where are you in the map and some more" / "zombie
blood doesn't show in the bar".)

- **RESPAWN UI LOSS — the per-life overlay rebuild (map 1's fix, finally
  ported).** The engine closes a player's `OpenLUIMenu` menus on the
  death→spectate transition, and `ensure_menu()`'s guard reads
  `self.tod_upg_menu` — a server field that transition never clears — so a
  respawned player lost the whole `tod_upgrade` overlay (upgrade cards, luck
  bar, tower gauge, damage numbers, finale banner) for the rest of the match;
  upgrade events kept running server-side, chosen blind. Map 1 hit the
  identical bug 2026-06-24 and fixed it in `_acc_lui::player_lui_init`; the
  2026-08-23/26 kit audits ported the LUA fixes but this one lives in GSC and
  was missed. Ported to `_tod_upgrade_ui::player_lui_life`: on connect, a
  per-life loop (waits on `spawned_player`) closes the stale handle, reopens
  the menu after a 0.5 s respawn settle (0.05 s at match start), then re-arms
  every change-gated feed so it re-pushes current state into the fresh menu —
  `_tod_gauge`'s three per-player trackers cleared (floor cell + boss pip +
  the Aetherium max-HP readout re-send within one 0.35 s tick) and the luck
  bar re-asserted from `tod_luck_bar`. The upgrade cards and finale banner
  self-heal (events re-set every field from scratch; the banner blink
  re-pushes each cycle). The Aetherium kit itself never had this bug — it
  replaces `T7Hud_zm_factory`, whose lifecycle the engine re-runs per spawn.
- **ZOMBIE BLOOD NOW SHOWS IN THE POWERUP TRAY.** The tray row existed in
  `AetheriumPowerupsContainer.lua` since v8.4 but was a dead entry — no
  clientfield ever drove it (the icon asset `i_tod_pu2_zombie_blood` was
  always in the GDT/zone; no new art needed). Wired through the STOCK
  timed-powerup lane, mirroring the proven timewarp/infiniteammo shape:
  `add_zombie_powerup` on BOTH halves now carries the `tod_zombie_blood`
  clientfield (gsc adds time/on var names, csc adds the matching
  registration — 2-bit "toplayer", VERSION_SHIP, lockstep), and
  `zombie_blood_window()` drives the per-player contract stock's
  `powerup_hud_monitor` reads for grabber-only powerups:
  `zombie_vars["zombie_powerup_zombie_blood_on"/"_time"]` +
  `_show_solo_hud = true` (the stock Death Machine idiom), counting the 15 s
  down in 0.05 steps so the monitor runs the expiring flash itself.
  `zombie_blood_clear()` zeroes both vars and drops `_show_solo_hud` only if
  no minigun/Gift-of-Death window still needs it (IS_TRUE-guarded — that var
  is never inited on this map, the v8.4 boot-fix rule). NOTE: this is the
  map's first NEW "toplayer" field beyond the vendored packs — if the next
  boot dies with an out-of-space clientfield error, this is the suspect.
- **Kit-fix audit re-run (memory recipe: grep map 1 for `ACC FIX|kit bug|kit
  hardcoded|LEAK FIX`)**: all previously-flagged sites verified PRESENT in
  this repo's copies — both UITimer state-pool leaks (PowerupNotification,
  Loadout ×2), the PartyPlayers bgb-handler leak + 30 s bleedout, the
  PlayerInfo `player_state_0` co-op fix + 30 s bleedout + shield dead-node
  CreateModel guard. The two ZMCursorHintNew entries are map-1-specific
  (wallbuy copy / Paradise box price) and do not apply here.

## 2026-08-26 (v12) — THE VORTEX BELL + THE FOUR FEARS: crown underside redesign, causeway redesign, hall pillars restored, hall ammo crate

(User: "I want even more granular detail and an even more sense of leaving the
player in awe ... the paths to get to the crown building are pretty simple and
straight forward. Lets be more creative ... the run over to it should be scary
and anxious driving ... players climb the tower and ... can see the bottom of
the crown building as they get higher. Maybe a cool design on bottom is
something worth thinking about. They look up and see this MASSIVE bulding.")

**THE UNDERSIDE (the climb's 60%-of-pixels surface) — THE VORTEX BELL.**
The v11 skirt was 8 tiers at a uniform 0.8 taper: correct, but SMOOTH — a
smooth object has no size. Now 10 tiers on an ogee (slow-fast-slow factors),
so the side silhouette is a bell and, from below, the visible ring widths
accelerate toward the centre — the dome-coffer depth illusion. Corona TEETH
(brass, 320 wide — 2.5× the rejected radial-rib size, an outline break not a
field rib) serrate the gold tiers' south lips; JEWEL COLLARS stud two brass
tiers; the ermine rim gets an UNDERSIDE row of tail-spots; the arches get
PEARL BEADING (white, segments 2/4/6 — 7 skipped, the arches cross there).
THE GIRANDOLE replaces the 544-sq core cube: an 8-stage chandelier drop
(collar → chain → stepped ruby ORB → flaring coronet → pip → drop stone,
every stage wider than the one it hangs from) below CR_SKIRT_BOT, with the
crown's THIRD red light — the red vertical axis is now beacon / great ruby /
girandole. Crown bottom moves 15008 → 13696. Lit area 1000 → 1118M u²;
bake BAKED 38.4 s; audit_hidden_faces: no new all-six-buried brushes.

**THE ROAD — same spans, four new fears** (see CLAUDE.md for the full shape):
RIDGE (+256 zigzag crest, the awe lane) / BROKEN STAIR (blind pockets, −256
hollow, one long blind climb) / THE NARROWS (spine pinched to 120 for 320
units — the guaranteed choke, portal 2 rides the pinch at xo 80) / UNDERCROFT
(−384 V with an ambush cistern, new CW_DEEP) / PLANK (raised 192 → +256) /
WEAVE (flat 4-jog serpentine, 9 risers). roadDogleg deleted — mirrored forks
cannot surprise twice. 8 AVENUE PYLONS (jewelled obelisks, sapphire = the
road's colour language) float beside the gate-run and the narrows. cwSpan
UNCHANGED, so 5f.1/5f.9/CR_S_FACE all held without re-derivation; walked
length 8620 → ~8220 (more slack under the 90 s road phase); road z now
19008..19648 (beyond_gate's CW_ZMIN follows automatically). Lint: 0/0/0/0,
both routes walkable. NOTE: the undercroft's −384 slightly exceeds the ±256
envelope the finale's yaw-only "ahead" tests were tuned for — graceful
degradation only (spawns land beside instead of ahead); ceiling recorded in
the generator.

**THE HALL — the pillars are back, as pure architecture.** The v11 deletion
was aimed at the deathray-coil MODELS; the user: "I think the last agent
thought I wanted the entire pillars removed." Restored at the original ±448
spots and 176 height (the hold-out's only cover), finished for the
velvet-and-gold room: gold base (112 sq), ruby shaft (80 sq, the original
glass), gold cap. `pylon_orgs()` is UNTOUCHED — the quarter-progress read
stays on the circlet's corner points; these are scenery. Verified: gather
ring (160) clear by ~290, hall risers' nearest face 56 away, caps 84 below
the quarter-point lights.

**THE HALL AMMO CRATE** — fifth crate, east wall, mirror of the west-wall
upgrade station, same two-sided contract as the breather four: script model +
trigger from `_tod_ammo_crate.gsc`, invisible clip from the generator (label
`crown hall ammo crate body`, the lint's MODEL_CLIP_COLUMNS whitelist). NEW:
the coords ride in generated `_tod_crown_data.gsc::crown_crate_org()/yaw()`
(the door-data no-drift pattern) — the GSC change is additive only.

Also: CLAUDE.md's DEV TEST HARNESS section corrected — `dev_crown_test` was
removed 2026-08-25 (`_tod_main.gsc:63`); no dev clock exists in any build.

## 2026-08-26 (v11.5) — ASSAULT BUFF: headshot 4%/Lv, GIANT SLAYER 4%/Lv, RECOIL −10/−20%

(User: "So the Assault class need a minor buff. The headshot damage needs to be
4% for each level and boss damage also 4% per level. Recoil will go to 10% per
level. We will need pause menu description updates. We will need new prompts to
get the updated assets for the upgrade menu.")

All three are ASSAULT-only domains, so this is a clean class buff with no
spill-over onto the other three classes.

| domain | id | max | was | now | where the number actually lives |
|---|---|---|---|---|---|
| HEADSHOT | 6 | 10 | +3%/Lv | **+4%/Lv** | `TOD_UPG_HS_PER_LVL` **+ a hand-copied literal in `_tod_bosses::rp_damage_feed`** |
| GIANT SLAYER | 35 | 5 | +3%/Lv | **+4%/Lv** | `TOD_UPG_BOSSDMG_PER_LVL` (both boss lanes read it through `boss_damage_bonus()`) |
| RECOIL | 17 | 2 | −8/−16% | **−10/−20%** | `gen_tod_twins.js` `RECOIL_STEP` — **weapon GDT data, not script** |

**THE HEADSHOT NUMBER EXISTS TWICE AND THE SECOND COPY HAS GONE STALE BEFORE.**
A GSC `#define` is file-local, so `_tod_bosses::rp_damage_feed` (the Rogue
Protector lane) carries a literal. The 2026-08-22 nerf missed it and paid 2.5×
for a day. Moved in the same commit this time; the comment there now records the
full 0.10 → 0.04 → 0.03 → 0.04 chain.

**RECOIL IS A GENERATOR FACT, NOT A SCRIPT ONE.** `RECOIL_STEP [1, 0.92, 0.84]`
→ `[1, 0.90, 0.80]`, then `node tools/gen_tod_twins.js`. Verified numerically
rather than trusting the regen: the emitted GDT diff is **752 lines, all of them
kick keys**, in exactly two ratio buckets — 376 at ×0.9783 (r1: 0.92→0.90) and
376 at ×0.9524 (r2: 0.84→0.80). `tod_twins.zpkg` came back **byte-identical**,
so no asset names moved and the registration ledger is unchanged at 213/220.

**RECOIL CROSSES A THRESHOLD, NOT JUST A NUMBER.** Every gun carries
`RECOIL_BUMP` 1.15. The old maxed ladder landed at 1.15 × 0.84 = 0.966 — the
card bought back part of the roster bump and was never actually a reduction. At
1.15 × 0.80 = **0.92** it is, for the first time, a real 8% cut below the source
weapon. That invalidated a headline finding in `docs/armory.html`, which has been
rewritten rather than patched. It is uneven, though: the Krig 6 also carries
`KRIG_RECOIL_BUMP` 1.5625, so its maxed form is 1.4375 — still 44% ABOVE its
port. Same card, a reduction on the Enfield and AK-47, a partial refund on the
Krig.

**THE BUFF IS SMALLER THAN "3% → 4%" SOUNDS.** Both domains are ADDITIVE into
the same `mult` sum as DAMAGE's +120%, and there is no clamp anywhere in the
callback. A maxed assault landing a headshot on a boss goes
`1.00 + 1.20 + 0.30 + 0.15 = 2.65×` → `1.00 + 1.20 + 0.40 + 0.20 = 2.80×`:
**+5.7% total damage**, not +33%. Worth knowing before anyone concludes it did
nothing and re-tunes it again.

Display, all updated in lockstep (the pause menu the user asked about is the
`DETAIL` table):

- `tod_upgrade.lua` `DOMAIN[6]/[17]/[35]` desc, `DETAIL[6]/[17]/[35]` val
  (`3*l`→`4*l`, `{8,16}`→`{10,20}`, `3*l`→`4*l`), plus the `-- 17` note.
- `add_domain` desc strings for all three.
- Six stale comments across `_tod_upgrades.gsc`, `_tod_upgrade_ui.gsc` and
  `_tod_bosses.gsc`.
- `docs/armory.html` — 12 sites, including two findings whose CONCLUSIONS
  changed. NB `RECOIL_STEP [1,0.92,0.84]` shares a line with
  `FIRE_STEP [1,0.92,0.84,0.76]`; anchor any replace on the recoil cell.
- `docs/33` reopened + count 26→23, `docs/31` marked superseded,
  `docs/upgrade_system.md` headshot line de-staled (it still claimed +10%/Lv).

**THE NINE CARDS ARE DONE TOO** (user drop `files (44).zip`, same day). Card art
carries the numbers baked in, so a domain retune is not finished until the card
is re-baked — this one was, within the hour. All nine at exact filenames, all
768×1152, md5-verified into `source_data/tod_ui_images/_images/`. The contact
sheet proofread clean on all six checks: HEADSHOT +4/+8/+12 with "4% PER LEVEL",
GIANT SLAYER +4/+8/+12 on five pips keeping both subline clauses, RECOIL
−10/−20/−20 on two pips with the **wide minus (U+2212)** and `· MAX` on SUPER and
ULTIMATE only. Three spot-checked at full size against the outgoing art:
pixel-faithful, only the two value-plate lines moved. Zero wiring — every one
already had its zone line and GDT block. Pause *plates*
(`i_tod_pause_r06/r17/r35.png`) are name-only and did NOT change.

Prompts, per-card text and the checklist: **`docs/35_assault_buff_art_prompts.md`**.

Found in passing and fixed: the BOUNTY block comment in `_tod_upgrades.gsc` said
"+3%/Lv money per kill" and has been wrong since the 2026-08-20 buff to 0.05.

**OPEN — 3 UNEXPECTED LINKER ERRORS, NOT WAIVED ON PURPOSE.** This full build
flagged `reflex_reddot_camo`, `reflex_reddot_lens_ads` and
`reflex_stencil_outline` as missing from gdtDB. **They are NOT from this change**
— the pre-change GDT backup and the regenerated one both carry exactly 432
`reflex*` references, so the count is unmoved; they are reflex-sight optic
materials riding in with the ported guns, and they surfaced now only because
this is the first FULL build in a while (the last few were `-GscOnly`, which
does less asset conversion). Left OUT of `$WaivedLinkerErrors` deliberately:
every other entry in that list cites a reason and most cite an in-game
verification, and waiving something nobody has looked at in game is how a real
missing asset gets hidden. Expect them on every full build until someone
confirms the optics render, then waive with that evidence.

## 2026-08-25 (v11.4) — the Gift of Death ring: `StopLoopSound` is TWO DIFFERENT FUNCTIONS

(User: "There is for sure a ringing noise bug related to the Gift of Death…
got to round 28 ish and towards top of the tower and got ring of death and had
a permanent rattle ring sound that didnt go away.")

**THE 2026-08-23 FIX FOR THIS WAS A NO-OP, AND THE REASON IS A SIGNATURE SPLIT
BETWEEN THE TWO VMs.** `StopLoopSound` takes a **FADE TIME** server-side
(`mechz_spiki.gsc:1755` `self.m_claw StopLoopSound(1)`) and the **SOUND HANDLE
RETURNED BY `PlayLoopSound`** client-side. Stock proves the client form twice
and there is no counter-example anywhere in the shipped tree:

- `share/raw/scripts/shared/weapons/_hive_gun.csc:93,120` —
  `sound = self PlayLoopSound("wpn_gelgun_hive_hunt_lp")` … `self StopLoopSound( sound )`
- `share/raw/scripts/shared/ai/mechz.csc:149,158` —
  `self.sndLoopID = self PlayLoopSound(…)` … `self stoploopsound( self.sndLoopID )`

`zm_weap_xmas_gun.csc` discarded the handle at every `PlayLoopSound` and then
called `entity StopLoopSound(fade_time)` with `fade_time == 3` — an integer
handed to a parameter that wants a handle. **It stopped nothing.** Every set of
three LOOPING sleigh-bell voices ever started stayed alive for the rest of the
match, merely MUTED, because `SetLoopState` is alias-keyed and only changes
VOLUME. The moment a SECOND pickup started a second generation on the same
entity, the first generation stopped being addressable by alias at all — and
rang forever at whatever volume it was last set to. Gift of Death is a 50% roll
on the Death Machine drop, so ~28 rounds is several pickups: exactly the
reported symptom, and exactly why it is not reproducible on the first pickup.

FIXED, three parts:

1. **Keep the handles, stop by handle** (`bells_stop()`). This is the only
   thing in the file that actually silences a voice; the alias mute is retained
   as a fallback for voices a handle latch cannot know about.
2. **Never stack a generation** — `bells_stop()` runs before any start, so the
   unaddressable-orphan state is now unreachable rather than merely unlikely.
3. **The stop gets RETRIES.** The engine dispatches a client system only when
   its state CHANGES (`callbacks_shared.csc::CodeCallback_StateChange`), so the
   server re-sending a byte-identical stop string every 0.2s forever collapsed
   into ONE delivery per ON→OFF transition — and a delivery landing on a frame
   where the client could not resolve the emitter was lost for good, with the
   handler killed by the method-call-on-undefined error. The server now varies
   the third field (ignored by the client on a `-1`) for the first 8 sends so
   each is a genuine state change, then goes quiet; the client returns cleanly
   on an unresolved entity instead of dying, so those retries are reachable.
   Bonus: this also stops an unchanging state being written O(players²) times a
   second for the whole match.

Also guarded `self.bellSoundModel` going undefined, which would throw on
`GetEntityNumber()` and kill the whole tracking thread — leaving the bells
running with no code left to stop them.

Files: `scripts/zm/zm_weap_xmas_gun.csc`, `scripts/zm/zm_weap_xmas_gun.gsc`.
`-GscOnly`; both are `scriptparsetree` lines in `zone_source/xmas_gun.zpkg`.

## 2026-08-25 (v11.3) — two perk bugs, and both were STOCK copy-paste, not ours

(User: "We have an issue where phd is using staminup machine?? This should be
fixed" / "Also electric cherry icon doesnt show up in HUD when you get it")

**1. PhD WAS WEARING STAMIN-UP'S IDENTITY, AND IT IS A TREYARCH BUG.**
`_zm_perk_electric_cherry.gsc`'s `electric_cherry_perk_machine_setup` is a
VERBATIM copy of `_zm_perk_staminup.gsc`'s that nobody renamed — all six lines
identical, including `use_trigger.target` and `perk_machine.targetname` both set
to `vending_marathon`, `script_string` to `marathon_perk`, and the jingle to
`mus_perks_stamin_jingle`. PhD Flopper rides the stock cherry specialty on this
map (our Electric Cherry lives on `specialty_combat_efficiency` instead), so PhD
inherited the whole Stamin-Up identity. Two machines answered to
`vending_marathon`, and `_tod_perk_scatter` resolves a machine through
`GetEntArray( t.target, "targetname" )` — so the collision was not cosmetic.

FIXED: `_tod_perk_phd.gsc` now DIRECT-OVERWRITES `perk_machine_set_kvps` (the
`register_perk_machine` helper only assigns when undefined, and stock's was
already in) with its own identity — `tod_vending_phd` / `tod_phd_perk` /
`tod_phd_vending`, plus MULE KICK's jingle and sting, which are real shipped
aliases and unowned since Mule Kick was retired on 2026-08-25.

**2. THE ELECTRIC CHERRY HUD ICON WAS NEVER WIRED**, for two independent reasons.
`_tod_perk_electric_cherry.gsc` skipped `register_perk_clientfields` on the
belief that "stock HUD shows the perk natively off the specialty" — it does not,
`zm_perks::set_perk_clientfield` (`_zm_perks.gsc:968`) is a NO-OP without a
registered `clientfield_set`. And the Lua row pointed at `combat_efficiency`,
which is not a registered uimodel in either VM, so a write would have gone
nowhere even once one existed.

FIXED by borrowing MULE KICK's field: `hudItems.perks.additional_primary_weapon`
is registered in BOTH VMs by `_zm_perk_additionalprimaryweapon` (which this map
already `#uses`) and is written by nothing since Mule Kick was retired.
**Zero new clientuimodel bits** — which matters, because that pool has a
documented boot ceiling (61 proven; we sit at 15 fields / 58 bits) and a new
field would need a matched, order-sensitive append in BOTH VMs for a cosmetic
icon. The perk's `clientfield_register` is deliberately EMPTY: the framework
calls it for every registered perk (`_zm_perks.gsc:1638`), and re-registering an
existing field is a duplicate-clientfield boot failure. `EC_HUD_CLIENTFIELD` and
the Lua row must stay in lockstep.

Net effect in the HUD: PhD shows the PhD icon (it keeps the cherry field, which
it genuinely sets), Electric Cherry shows the cherry icon, and the two no longer
share a row. arity + xref lints OK; all nine Lua `clientFieldName`s verified
unique.

### ADDENDUM — a verification pass caught the PhD fix BREAKING PhD

The user asked "did you fix everything I asked for?", which triggered an
independent audit of the whole session against the tree. It found that the R7
fix above, as first written, **made PhD unbuyable** — a worse bug than the
cosmetic one it fixed. Three defects, all now closed:

  * **`radiant_machine_name` DID NOT MOVE WITH THE RENAME.** Stock's
    `perk_machine_think` (`_zm_perks.gsc:124-125`) resolves BOTH the machine and
    its use trigger through that one name:
    `getentarray( radiant_machine_name, "targetname" )` and
    `GetEntArray( radiant_machine_name, "target" )`. Renaming the entities to
    `tod_vending_phd` while `register_perk_host_migration_params` still said
    `vending_electriccherry` made both lookups return EMPTY — so no SetModel, no
    Solid, no perk_fx, and fatally no `set_power_on(true)` (`:148`). `.power_on`
    is written nowhere else in this map, so `vending_trigger_post_think`
    (`:661`) takes the `!IS_TRUE(self.power_on)` branch: one second after buying,
    `perk_pause` UnsetPerks PhD from every player and `has_perk_paused` stops the
    machine re-selling it. It worked BEFORE the fix only because PhD's trigger
    rode Stamin-Up's array. Now one `#define TOD_PHD_RADIANT_MACHINE`, used in
    all three places — the same invariant `_tod_perk_electric_cherry` keeps with
    `EC_RADIANT_MACHINE`.
  * **The override could land too late to matter.** `perk_machine_set_kvps` is
    consumed by `perk_machine_spawn_init()` inside `zm_perks::init()`
    (`_zm.gsc:362`), and the PhD override was installed from a THREADED
    `install()` that can `wait`. It happens to win today only because of
    `#using` order — an ordering assumption between two autoexec systems that
    `install()`'s own comment says not to make. Now called deterministically from
    `zm_tower_of_doom.gsc::main()` before `zm_usermap::main()`, the same window
    `_zombie_custom_add_weapons` uses. The threaded path re-asserts it, idempotently.
  * **The four finale beacons were entombed.** `CROWN_BEACON_Z` summed
    shaft+head+cap and stopped — the pip's BOTTOM face — so all four
    quarter-progress beacons spawned inside a 400-wide solid brush, model and
    aura both. Now above the jewel stone; verified the origin is inside no brush.

**Also corrected, because they would mislead the next session:**
`tools/gen_tower_map.js` still stated the RETRACTED 126.2 s bake reading as fact
and drew "do not scale further" policy from it — corrected in the docs but not in
the generator, which is the file anyone actually reads before touching the crown.
And `_tod_perk_electric_cherry.gsc`'s header still claimed the HUD reads the perk
natively off the specialty, directly contradicting the code beneath it.

**And the dev harness was only half-opening the map.** Setting the `enter_*`
flags is NOT "the same as buying every door": a real buy also runs
`breather_unlock` (without which Protector, Reaver and the hellhound unlock stay
DORMANT all session), opens the slab (`Hide/NotSolid/ConnectPaths` — flags alone
leave 53 solid barriers and a severed navmesh), retires the triggers, and there
is a 53rd flag (`enter_power`) that was missed. Replaced with
`tod_doors::dev_open_all_doors()`, which walks the real door entities so it
cannot drift from the generator's door list.

## 2026-08-25 (v11.2) — the crown's detail pass: six real defects, and the discovery that this map's materials are SELF-LIT

(User: "Its scale is perfect. It looks fantastic. Now I want to review the design
and add some details to it. To make it look nicer and more pleasing and
impressive.")

**THE FINDING THAT REWROTE THE PASS: EVERY MATERIAL IN THE PACK IS SELF-LIT.**
All 30 in `emox_mwiii_vertigo_assets.gdt` are `lit_emissive_*` (27
`lit_emissive_advanced`, 3 scroll variants). A face pointing down and a face
pointing at the sky emit identically, and the crown carries exactly two light
entities on its whole fabric. **So geometry does not self-shadow here.** A
corbel, a ledge, a moulding or a collar produces NO value change on its own.
Relief only pays when it (a) breaks the silhouette, or (b) CARRIES A DIFFERENT
MATERIAL. The entire pass was rebuilt on the material value ladder — measured
from colorTint x scaleRGB: yellow 13.5, white 13.1, orange 8.5, yellow_tinted
7.8, orange_tinted 5.8, yellow_tinted_edge 3.9, purple_tinted 2.9, dark_white
2.8, off 0.0.

**AND THE PREVIEWER HAD BEEN LYING.** It shaded faces by direction with a
0.45-1.15 spread and collapsed `yellow`, `yellow_tinted` and `yellow_tinted_edge`
to one swatch — so it flattered every ledge in every render AND made the value
ladder invisible in the very images being used to judge it. Fixed: near-flat
face shading (0.88-1.06) and a palette keyed to the measured emissive values,
suffix-ordered so `_tinted_edge` resolves before `_tinted` before the plain.

### SIX DEFECTS, all found by measuring the generated .map rather than by eye

  * **The mouth jambs were 100% BURIED.** Jamb x[448,576] y[6912,7216] sat
    entirely inside frontispiece x[448,944] y[6912,7136] — and their south faces
    were COPLANAR, i.e. a z-fight between two materials. The element the design
    record credits with "turning a hole in the rim into a gate" did not exist
    visually. Jambs now stand CS(240) proud, the frontispiece is pushed back to
    CS(16), and the depth order out from the band is jamb 240 > rib 224 >
    ermine 96 > rim 64 > frontispiece 16 > C4 0.
  * **Two of the sixteen jewel bosses were sealed inside the frontispiece** —
    448-wide coloured slabs entirely enclosed in solid gold, pure bake cost. The
    frontispiece owns those two bays by design, so the inner south pair is
    skipped; the north face keeps all four.
  * **The ribs were NARROWER than the points they carry** (256 under a 384 shaft,
    416 under a 496 one), so all sixteen points overhung their own buttress by
    40-64 a side. Now CS(144)/CS(176), wider than their load.
  * **Every articulating element lived in a 96-unit slot** on a 6128-wide
    elevation — ribs 80 proud, rim 64, upper astragal 16. That is 1.6% of the
    width, and it is why the band read as one flat plate up close. Fixed for FREE
    by splitting rib depth by axis: silhouette rule H is about the X profile, so
    a south or north rib may protrude in Y without touching it. S/N ribs now
    stand 320 proud; E/W stay inside the ermine.
  * **The spire came back, sixteen times.** Tall points ran 400 -> 896 -> 496 ->
    **208** -> 320: a 4.3:1 collapse, and 208 units is 0.54 deg from the base
    arena, sitting on the shimmer floor the whole redesign exists to escape. Pip
    widened to 400, stone to 448 so it FLARES. The fleur's centre lobe was 336
    against its own 384 shaft — a direct violation of "every head wider than its
    shaft" — now 448, tip 176 -> 288.
  * **The last causeway portal stood INSIDE the crown's throat.** Portal 3 is at
    y 7344-7376; the band's inner face is 7328. In cyan it was the brightest
    object in the arrival shot and the only foreign hue at the most important
    framing moment in the map. It now wears the crown's gold; the other two keep
    the road's cyan, so the colour change still IS the arrival.

### THE DETAIL, placed only where a player can stand

Every reachable close view of this crown is from the SOUTH — the terrace, **the
plank** (the raised centre route of the second fork, and the real money view),
the mouth, and the hall floor. The E/W/N band faces are only ever seen from
22,000 units, where sub-degree detail shimmers, so they got nothing.

  * **ERMINE SPOTS** — two staggered rows of `dark_white` studs on the white rim,
    the widest line in the silhouette and previously a blank bar. Heraldic ermine
    is white WITH DARK TAILS; that pattern is the whole reason a white band reads
    as fur. `dark_white` over `off` deliberately: pure black on a night skybox
    reads as a hole punched in the crown.
  * **THE BAND CLIMBS THE VALUE LADDER** — C1 brass, C2/C3 gold panel, C4 bright
    gold. All four used to be one material, so the flare, the move the whole
    silhouette rests on, was invisible on every face.
  * **SUNKEN PANELS** in the outer south bays — raised frames implying a recess,
    because additive boxes cannot cut one. The number-one complaint in all four
    critiques.
  * **THE CULLINAN IS A CUT STONE** — a stepped cabochon in four gold claws
    instead of one flat 896-wide slab.
  * **SHAFT BANDING** — gold/brass/gold on every tall and corner shaft, replacing
    a `collar` box that was 40 units proud in the same colour as the shaft and
    therefore invisible from everywhere while still costing bake.
  * Dentils under the south rim, boss collets, jamb bases and capitals, mouth
    vault ribs, and plinths under the south and corner points.
  * **Bays are now derived from where the points ACTUALLY are** (midpoints
    between adjacent points) rather than from a fraction of the wall — the
    fraction form put the outer bosses at 2028 while the corner point sits at
    2344, so widening the ribs partly buried them.

### TOOLING

  * **NEW: `tools/measure_lit_area.js`** — sums lit face area from the generated
    .map and groups it by region. Deterministic and instant, where the bake is
    neither. It reports the crown at **84% of the map's entire lit area** (the
    2,709-brush spiral is 5.4%), which is the number that should drive geometry
    decisions up there.
  * `preview_crown.js`: honest shading and the measured palette (above); two new
    views (`detail`, `interior`); and the `gate` camera fixed — it had been
    anchored on a hardcoded `CR_HY` from `CR_SCALE` 1.0 plus the selection's
    bounding box, so the one view whose job is to prove close-up quality was
    rendering from a distance that changed with the `--filter` string.
  * **`TOD_MAP_OUT`** on the generator, so a variant .map can be generated and
    baked via `_bake_test.ps1 -TestMap` without touching the shipped one. Added
    to A/B a bake reading that would not reproduce — see the correction below.

### ROUND TWO — a four-lens design review of the SHIPPED pass found eleven more

**THE ONE THAT MATTERED: four gold blocks were standing on the causeway.**
Pushing the mouth jambs CS(240) proud took them to y 6672, and the causeway's J4
LANDING is 960 wide (x +-480) running y 6720-6880 at TOP2 — so the jamb and its
base sat on walkable deck and passed straight through the landing's north guard
rail. **No existing gate could see it:** lint_tod_geometry's misplaced-wall check
only fires on a `clip` brush with no visible solid beside it, and a VISIBLE solid
silently drops the node from `stand`, while the reachability flood still walked
the middle of a 960-wide landing. Fixed by splitting the projection — MP1 (6912)
for anything reaching down to the deck, MP_DEEP (6672) only for the cap and
corbels, which oversail above head height, which is what corbelling IS. And
**section 5f.9 now ASSERTS it against the emitted brushes** (any crown brush south
of cwY[8], within CW_LAND, below TOP2+96 throws) — that assert caught a leftover
64-unit overhang on the base the moment it was written.

Also fixed: the mouth keystone was ~93% behind the Cullinan's bezel (deleted);
`crown arch NS south 1` was 90% inside the front cross (skipped); the beacon
needle was WIDER than the finial pip it stood on; the rib back faces were coplanar
with C4's inner face — brass against gold, on the surface the hold-out looks
straight at; point stone colours were keyed on ARRAY INDEX, and since CR_POINTS
lists the corners last that made the south face ruby on one side and emerald on
the other; the front cross's ruby was 720 tall against a 448 arm, so the PATTEE
flare never appeared; and 20 brushes carried fractional coordinates against a
generator whose whole discipline is the 16-grid.

**NEW TOOL: `tools/audit_hidden_faces.js`.** Four of those burials were found BY
HAND, by a human reading coordinates out of the .map — that does not scale and it
does not repeat. This samples every face of every brush in a label group and
reports what nothing can see. It immediately found what hand-inspection missed:
**both stiles of every sunken panel were 100% buried**, because the panel was
centred on the bay midpoint with a literal half-width, putting its sides behind
the very buttresses that define the bay. A frame with no sides is not a frame.
The panel and the dentil course now derive their spans from the real
obstructions. ADVISORY, not a gate — a tenon keyed into a wall is supposed to be
buried; what it is for is the two cases that are always wrong (buried on all six
faces, or a visible face coplanar with a neighbour in another material).
Known and accepted after pricing: 16 chamfer steps inside the corner posts,
5.2M u^2 = **0.52%** of the crown.

4,749 world brushes. Lit area 962M -> ~1,010M (+5%). Geometry lint GREEN
whole-map against the all-zero baseline, parity GREEN at CM=-1, lint self-test
GREEN (a material was added, so it was mandatory), arity/xref/weapons OK, LED
**BAKED** (34.7 s).

## 2026-08-25 (v11.1) — CR_SCALE: the crown goes to 6128 wide, and the LED bake finally tells us what it costs

(User, on seeing v11: "Excellent stuff. I want the scale to be even more. I want
players to be in awe when they see the crown. Lets give it one more iteration.
This one is for the players!")

Renders of the SHIPPED crown: `docs/crown_v12_*.png` (and `docs/crown_v12_road_gate.png`,
the view from the causeway walking into the mouth). `docs/crown_v11_*.png` is the
same set one scale step back, and `docs/crown_now_*.png` is the original citadel.

**ONE KNOB, NOT A REDESIGN.** Every proportion in the crown was derived against
the heraldic canon and against the 384-unit legibility floor, and the LOOK had
already been signed off — so the right way to make it bigger is to multiply, not
to re-litigate ratios one at a time. `CR_SCALE` (1.4) plus
`CS(v) = round(v * CR_SCALE / 16) * 16` now scales every dimension of section 5f
while keeping it on the 16-grid.

|  | v11 | **v11.1** | the old citadel |
|---|---|---|---|
| width | 4096 | **6128** | 1568 |
| total height | 9920 | **13,888** | 2688 |
| angular width from the base arena | 10.6 deg | **14.8 deg** | 4.0 deg |
| LED bake | 38.2 s | **126.2 s** | — |

  * **THE SOUTH FACE IS PINNED AND THE CROWN GROWS NORTH AROUND THE HALL.** The
    south band has to land inside the causeway's F APPROACH — the one stretch
    that is flat, on-axis and at TOP2 — and that stretch is only 800 deep, so at
    v11's CR_HY the ring was already within 32 units of the J4 merge. There was
    no room to grow southward AT ALL. `CR_S_FACE` is now a constant and `CR_CY`
    is derived from it, so the crown is anchored to the ROAD rather than centred
    on the hall. Invisible: every sight line is from the south, depth does not
    read, and from the hall floor the 576 wall subtends 37 deg against the ring's
    inner face at 22 deg — you cannot see the ring from in there at all.
  * **TWO THINGS DELIBERATELY DO NOT SCALE.** `BAND_T` stays 320, because band
    thickness is the DEPTH OF THE TUNNEL the causeway walks through (already the
    map's deepest passage against a hall gate of 40) and you never see a band's
    thickness, only its face — scaling it would buy nothing and deepen a known
    navmesh risk. And `CR_S_FACE`, above.
  * **EVERYTHING ELSE IS NOW DERIVED RATHER THAN WRITTEN DOWN**, because a
    literal is a bug waiting for the next scale change: point positions come off
    PT_X/PT_Y quarter-points, jewel and pendilia bays off the same halves, the
    skirt tier height off (CR_ERM_Z1 - CR_SKIRT_BOT), the monde slab height off
    (CR_MONDE_Z2 - CR_ARCH_CROWN), the mouth's z off courses C2/C3, the Cullinan's
    z off C4 and the rim strip, and the beacon mount off the point tier heights.
    Two of those were already wrong at 1.4 before being derived: a literal 128
    monde slab left a 32-unit step in the sphere, and a literal 256 skirt tier
    left a seam in the one surface you look straight up at from the street.
  * **THE SEAL NOW ASSERTS AGAINST THE CROWN'S REAL BOUNDING BOX.** `addBox`
    accumulates `crownBB` for every crown/mast-labelled brush, and section 5f.9
    tests THAT against the sky ceiling, the sky wall, the sky floor and the
    umbra/fpstool lid. The derived constants were understating the truth: the
    east and west point HEADS stand 200 units proud of the band they sit on, so
    `CR_OUT_X` was already 104 short at v11 before anything was scaled. An
    element sticking out further than its own constant implies is exactly the bug
    a seal assert exists to catch. The generator now prints the crown's measured
    box on every run, alongside the sky wall and ceiling it was checked against.
  * New assert on the arch ribbon: `ARCH_RISE * sin(90/8 deg)` must not exceed
    `ARCH_TH`, or the dipped arch breaks into a dotted line. Both scale together,
    so it holds — but it is checked rather than assumed.

**ON THE BAKE — SEE THE v11.2 ENTRY ABOVE BEFORE QUOTING ANYTHING FROM HERE.**
This entry originally reported "38.2 s at CR_SCALE 1.0 and 126.2 s at 1.4, 3.3x
the time for 2x the lit area" and concluded that 1.4 was the ceiling. **The
126.2 s reading was taken once and never reproduced.** v11.2 measured the same
map at 35.1 / 31.9 / 31.8 s and ran an A/B on byte-identical geometry that came
in at 31.3 s, so neither scale nor material distribution explains it. Bake timing
on this map is dominated by host state. `CR_SCALE` remains 1.4 because the crown
looks right at 1.4, which is a design reason, not a bake one.

Gates: geometry lint GREEN whole-map, parity GREEN at CM=-1, arity/xref/weapons
OK, LED **BAKED**, BUILD OK with the deployed tree byte-identical to the repo.

## 2026-08-25 (v11) — THE CROWN IS A CROWN: a 4096-wide gold circlet with the hall inside it

(User: "At the top of this tower we have a crown building. It doesnt look as scary
or visually pleasing as I hopped. Can you make the crown larger and more gold and
look more like a crown. When players see it they should be magnitized towards it.
We dont need to edit the floor of the room or space... It sjust clooks like a
castle with sppikes. We can do soo soo soo much better if we take our time and
actually puiyt the effort in." Plus, mid-turn: "Also inside we have these 4
pillars with this weird looking pipe level model on top. Lets remove that. So
weird.")

Full design record, with every number and why it is that number:
**docs/34_crown_redesign.md**. Before/after renders: `docs/crown_now_*.png` and
`docs/crown_v11_*.png`.

**THE COMPLAINT WAS MEASURABLE, AND IT MEASURED WORSE THAN IT FELT.** Every sight
line to the crown from anywhere on the tower is from the south and from below. At
the base-arena slant distance of 22,079 units one degree of arc is 29.5 px and the
legibility floor is about half a degree — **nothing narrower than ~384 units can
carry any part of the read**. Against that ruler the old citadel was one 4-degree
blue box plus a fringe of things that were literally invisible: gate spire tip 20
units (0.05 deg, **1.5 px**), pilaster tip 24, corner-tower tip 40, corner tower
body 192 (0.50 deg, 15 px). Six of the nine spires could not be seen from any
point in the map. And the UNDERSIDE — 60% of the pixels a player below actually
sees, because the near rim occludes everything behind it — was `dark_blue_tinted`,
within a few percent of the atmosphere's own fog colour, so it rendered as a
**black square** (kept as docs/crown_now_under.png).

  * **NEW TOOL: `tools/preview_crown.js`.** Parses the generated .map and renders
    six views to SVG **and PNG** — street (the magnetise test), approach, gate,
    under, elevation, plan — in about a second, with no bake and no game launch.
    Self-contained: its own scanline rasteriser and PNG writer via node's zlib.
    This is what the redesign was iterated against, and the diagnosis above came
    out of it rather than out of an opinion.
  * **THE CIRCLET** (gen_tower_map.js section 5f, ~460 new brushes). A
    4096 x 3264 x 9920 rectangular gold crown CENTRED ON THE HALL — 5.7x the play
    floor's footprint and 11.4x its wall height — so the floor sits inside it the
    way a head sits inside a circlet, with 544 units of air on the y sides and 960
    on the x. **The floor, walls, gate, dais, sconces and extraction pad do not
    move**; every constant is additive and outboard.
  * **THE BAND FLARES 9 DEGREES** (1856 -> 2048 over 1216) with a white ERMINE RIM
    proud below it. A plumb wall of constant thickness is the definition of a
    curtain wall, and that is exactly what the old citadel had.
  * **SIXTEEN POINTS, ALTERNATING, EVERY HEAD WIDER THAN ITS SHAFT.** 8 tall
    crosses pattee and 8 short fleurs-de-lis, so five teeth read across the south
    face at 43-49 px each with sky between them. New helper `cfleuron()` exists
    because `cspike()` can only make a NARROWING stack — and a shape that narrows
    to a point is a spire, which is the castle token this whole change exists to
    kill.
  * **A FRONT.** The south mid point is a FRONT CROSS, 576 taller than its
    neighbours, standing on the near rim where the crown's own band can never
    occlude it, carrying a 512-unit GREAT RUBY in a gold bezel. Forts are
    omnidirectional; crowns have a face.
  * **IT CLOSES.** Two dipped arches spring at 0.55 H from the side-mid crosses, a
    stepped MONDE with a gold equator fillet at 0.79 H, a cross-pattee FINIAL at
    1.00 H, and a BEACON STAR whose tip clears the near rim's occlusion line by
    1,392 units **from the floor of the base arena**. The star is a cross of
    horizontal plates and not a needle, because the first cut *was* a 160-wide
    needle and 160 units at 22,079 is 0.41 deg = 12 px — under the floor — and
    from directly below a vertical member presents almost no area at all (the
    previewer's street view rendered the whole upper crown as a hairline). The
    finial's arms run on both axes for the same reason. A crown converges; a castle
    terminates in a wall-walk. The reveal is staged across the climb: teeth, ruby
    and beacon from the ground, the monde at floor 7, the arches at floor 18, the
    vault overhead when you walk in.
  * **THE UNDERSIDE IS NOW THE BEST SURFACE ON THE MAP.** Ten proportional tiers
    (x0.80 both axes, chamfered), alternating bright gold and brass, 3136 deep,
    down to a glowing red core — concentric rings radiating out from it. Not the
    glowing-seam family, and that is measured: `_tinted_edge` is scaleRGB 5 where
    `_tinted` is 10 and plain is 15, so the seam materials are the DIMMEST in the
    pack. Over 22,000 units and 20-25% fog wash, brightness beats texture.
  * **THE ROAD RUNS THROUGH THE RIM.** A 640 x 424 mouth is cut through band
    courses C2 and C3 only — C1 stays whole (it is below the road) so the ermine
    ring is unbroken from below, and C4 becomes the lintel — with jambs, corbels,
    a keystone, a three-course stepped pediment and a glowing-seam lining. CR_HY
    is 1632 and not 1728 because the south band has to land inside the causeway's
    F APPROACH, the one stretch that is flat, on-axis and at TOP2; a generator
    assert throws rather than shipping a road that ends in a wall.
  * **MORE GOLD IS A VALUE LADDER, NOT A COLOUR.** The vertigo pack has 30
    materials and no metal, so the gold is built out of brightness: plain `yellow`
    (15) for points and arches, `yellow_tinted` (10) for band courses,
    `orange_tinted` brass as the dark foil, `yellow_tinted_edge` for close-up
    inlays, `purple_tinted` velvet, `white` ermine. Roughly 60% gold /
    25% velvet-brass / 10% white / 5% jewel, against the old ~70% blue. The hall
    walls went blue -> velvet: invisible from outside now, but they are the whole
    interior of the hold-out and purple-and-gold is what the inside of a crown
    looks like.
  * **THE TOWER WEARS A SMALL CROWN.** Eight points around the mast's shoulder at
    TOP2+320 — 320 above the core top, so nothing is walkable or blocked, and
    MAST_TOP does not move (the finale puts a beacon prop at mast_tip_org()). It
    is the one piece directly over the base-arena player's head.
  * **DELETED:** 4 corner towers, 3 mid pilasters, 2 gate spires, 3 ziggurat tiers
    + gravity core, 4 hall under-fascias. All of them either sub-degree, or the
    black square.

**THE FOUR PIPE PYLONS ARE GONE.** The hall's four 176-tall plinths carrying
`p7_zm_ctl_deathray_sphere_coil` are deleted, with PYL_OFF / PYL_HALF / PYL_H and
MAT.pylonPad. Their JOB survives: they were the finale's quarter-progress read,
one igniting per quarter of the closing song. `pylon_orgs()` keeps its name — so
_tod_finale.gsc needed a model swap, not a rewrite — and now returns the
CIRCLET's four corner point caps, so the progress read is the crown lighting up
around you. The model reuses the mast beacon's light cage: it sits 2,432 above the
floor, the AURA is the read, and it costs no new asset. The dead
`xmodel,p7_zm_ctl_deathray_sphere_coil` zone line went with it. The four hall
lights that hung over the plinths moved to the floor's quarter points.

**THE SKY SEAL WAS SILENTLY UNGUARDED AND IS NOT ANY MORE.** SKY_IN was
`max(2900, HN + 384)` — derived from HN in **y only** — and SKY_TOP was
`MAST_TOP + 300`, derived from the **mast only**; the two existing asserts test
the CAUSEWAY and never the crown. Nothing would have fired when the beacon needle
went 4,564 units through the roof of the world. Both are now max()'d over the
crown's real extents, VOL_R follows, and section 5f.1 asserts the crown against
the sky ceiling, the sky wall, the sky floor AND the umbra/fpstool lid — plus the
road, the hall clearance and the arch height.

**GATES.** `lint_tod_geometry` GREEN whole-map against the all-zero baseline (0
misplaced walls, 0 unguarded edges, 0 detached, base->terrace and
terrace->citadel both walkable); `lint_tod_geometry_parity` GREEN (the circlet is
authored in the odd frame and mirrors by CM, so it welds at LAPS=49 too); arity,
xref and weapons all OK. **LED bake BAKED in 38.2 s at 4,680 world brushes; the shipped map is 4,700** —
*faster* than the 47.5-68.5 s the map took at 4,245, which is one more datum for
"the bake tracks atlas packing, not brush count; measure it, never predict it".

`mwiii_vertigo_retro_synth_white` was added to `lint_tod_geometry.js`'s material
table as BLOCK — an unclassified material is a hard abort, and the ermine needed
it. The rule that governed every new brush: **any horizontal element 64 units
thick or thinner must use a plain colour**, because `_tinted`/`_tinted_edge` are
DECK and become walkable floor at or under MAX_SLAB. That is why the mouth soffit
is 80 thick and not 24.

**NOT TOUCHED, AND VERIFIED SO:** `in_crown()`, `in_hall()`, `exfil_org()`,
`crown_door_org()`, `gate_org()`, `dais_org()`, `station_org()`, `mast_tip_org()`,
`causeway_gate_org()`, `beyond_gate()` and the twelve sconces are byte-identical
in the regenerated _tod_crown_data.gsc. The win test, the extraction pad, the
crown door and the upgrade station are untouched.

## 2026-08-24 (v10.23) — the eight armory flags, all validated before fixing

(User: "Fix all of these. But please dont cause a regression. The game is good
with no major issues so small fuxes should not break the game. Validate each
probelm before fixingg" — plus three more added mid-turn.)

Every one of the five flags was reproduced in the EMITTED GDT first, not taken
on trust from the armory tables. All five were real.

**1. THE MAGNUM WAS THE ONLY WEAPON IN THE MAP THAT WAS NOT 1x BODY / 3x HEAD.**
Measured across all 172 emitted assets the roster is uniformly torso/limb 1,
head/helmet/neck 3. The Magnum port shipped 4.0 torso / 2.0 limb / 5.0 head, and
its PaP form 6.0 / 4.0 / 7.0 with a stray **8.0 helmet**. At the muzzle a PaP
body shot was 750 x 6 = **4,500**, against the AMP63's 135 and the PaP Bulldog's
300 — the strongest weapon in the map was a sidearm, and its headshot was worth
only 1.17x its own body shot in a map whose stated law is 3x for everything.

  * FIXED BY CLONING IT, not by editing the shared GDT. `skye_t9_magnum.gdt`
    lives in the mod-tools source_data; map 1 has **zero** references to it
    (checked, same finding as the AMP63), so an install-side edit was safe on
    that axis — but it is still outside the repo, where a Mod Tools verify
    reverts it silently. Cloning is what the Bulldog did in v10.8.
  * **DAMAGE COMPENSATED SO THE HEADSHOT NUMBER DOES NOT MOVE**: folding the old
    head multiplier into `damage` (250 x 5 / 3 = 417; 750 x 7 / 3 = 1750) leaves
    head damage at **1,251 and 5,250 — exactly where it is today** — while body
    drops 1,000 -> 417 and 4,500 -> 1,750. The gun's ceiling is untouched; only
    the spray-the-torso case is nerfed, which is what a 6x torso multiplier was
    buying. Aiming is now worth 3x on this gun for the first time.
  * NEW GENERATOR FLAG `papKeepSource`: the Magnum is NOT a ladder rung and was
    not asked to be retuned, so its _up form keeps every stat the port shipped.
    Without it the uniform PaP rule would have re-derived ~40 stats off the base
    and quietly shipped damage 750 -> 312, clip 12 -> 8, reserve 23 -> 16, plus
    free reload/ADS/recoil buffs. Only `tune.setUp` moves.
  * `TOD_SECONDARY_ASSAULT` -> `t9_magnum_b`. Ledger 194 -> 196 (guard 220).

**2 + 3. TWO PENETRATION DEAD-ENDS, both created by a promotion.**
  * HK21 was `large` (its port's value, frozen since it lost the p-ladder) while
    the Death Machine starts at `small` — so the TIER 2 -> TIER 3 promotion cost
    two levels of penetration and needed two upgrades just to break even. HK21
    -> **medium**: one level recovers it, two beat it.
  * MP7 (skirmisher TIER 3) was permanently `small` while the MAC-10 (T1) and
    MP5 (T2) both ship `medium`, and PENETRATION is not a skirmisher domain, so
    there was no way back. MP7 -> **medium**, level with the rungs below it.

**4. BACKSTAB WAS INCOHERENT IN THREE DIRECTIONS AT ONCE.**
`meleeFromBehindDamage` came straight off each port and nothing normalized it:

| blade | frontal | behind | verdict |
|---|---|---|---|
| knife | 2,000 | 1,700 | backstab **weaker** than a frontal hit |
| knife PaP | 4,000 | **20,000** | a TIER 1 weapon's 5x one-shot |
| wakizashi | 4,000 | 1,700 | backstab under half a frontal hit |
| wakizashi PaP | 8,000 | 20,000 | identical to the T1's, two tiers up |
| stormbreaker | 6,800 | **0** | the top blade had none at all |

Now DERIVED from `MELEE_TIER_DMG`, never authored: a uniform **x1.5** of that
form's own frontal damage, so it is monotonic up the ladder and stays in
lockstep the next time the tier damages move. **x1.5 specifically so the map's
backstab CEILING DOES NOT RISE** — the highest backstab in the game was the PaP
knife's 20,000 and the highest now is the PaP Stormbreaker's 20,400: the same
number, moved onto the weapon that should own it. One knob (`BACKSTAB_MULT`).

**5. EVERY BULLET WEAPON STILL LUNGED ON A GUN BASH.** The roster-wide "remove
the lunge swing" pass was gated `if (gun.melee)`, so it only ever reached the
blades — all 136 non-melee assets kept `meleeChargeRange 120`. Gate dropped;
the histogram across all 174 emitted assets is now **{"0": 174}**. The bash
itself is unaffected: it still connects at `meleeRange`, exactly as it has on
the blades since that pass shipped.

**AND THE THREE ADDED MID-TURN:**
  * **Speed curve 0.3% -> 0.35%/round** after round 15. Compounding and
    unbounded, so the gap widens with depth: round 30 1.045x -> 1.053x, round 50
    1.105x -> 1.123x, round 80 1.195x -> 1.228x. Floor and the round-15 ramp
    untouched.
  * **The +40% global reserve buff is GONE** (`RESERVE_MULT` 1.4 -> 1.0). It
    existed because this map has no mystery box and no wallbuys, so the reserve
    was the only ammo in the game; the breather AMMO CRATES are now that supply.
    Stoner 7 -> 5 mags, MAC-10 15 -> 10, Enfield 10 -> 7. The skirmisher keeps
    its own class x1.3 (a separate decision about the SMG line), landing at 1.3x
    source rather than 1.82x.
  * **LMG damage -10% again** (`CLASS_DAMAGE_MULT.heavy` 0.90 -> **0.81**, i.e.
    19% below the raw port). Stoner T1 239 -> 215, and it propagates by
    construction — HK21 502, Death Machine 350 are normalized FROM the tuned T1.
    Context: the armory audit had HEAVY top of the DPS table at every tier while
    ASSAULT sat 33-37% below both other classes.

**Gates:** arity lint OK (54 files), geometry lint OK (0 misplaced walls, 0
unguarded edges, base->terrace->citadel walkable, no regression vs baseline),
CSV/zone cross-check OK (87 rows), registration ledger 196/220, full build
(GDT changed, so `-GscOnly` would have been worse than nothing), fresh .ff
96.13 MB, banks 100.3 MB, deployed tree `diff`-identical to the repo.
`level.tod_dev` and `level.tod_god` both `false`.

## 2026-08-24 (v10.21) — PUBLISH BUILD; and the 7-hour crash was a DualSense controller

(User: "Okay do a full rebuild. Im gonna publish this version.")

**THE CRASH THAT ATE THE EVENING WAS NEVER THIS MAP.** BO3 refused to launch
from ~12:00 onward. Chased, in order and all WRONG: poisoned sound banks, then
`level.tod_dev`, then usermap memory pressure (16 GB machine carrying 8.5 GB of
usermap xpaks - a true observation, not the cause), then ASUS Armoury Crate /
AURA SYNC (its lighting service really did die 8 s before a crash dump -
coincidence). Root cause, found by finally reading the crash dumps properly:
**the DualSense controller's phantom Bluetooth audio endpoints.** BO3 null-derefs
on them during startup audio enumeration. Disconnecting the controller fixed it
instantly.

The evidence that would have ended it in one step, had I started there:
  * every dump: `0xC0000005`, **READ from 0x0** (a null deref - NOT out of
    memory, so the 90-97% memory spike the user reported was BO3's own load
    allocation, a red herring), always at `blackops3.exe+0x1d1b891`;
  * histogramming ALL 107 dumps: that exact signature has fired **49 times since
    2026-04-18**, the day BO3 was installed. **It predates every line of today's
    work by four months** - which instantly exonerates the map, the banks, the
    dev flags and the builds;
  * `console_mp.log` died right after the SOUND load states, naming the
    subsystem.
Written up in memory as [[bo3-startup-crash-dualsense]] with the diagnostic
recipe (parse the minidumps; histogram the signature FIRST; `read=0x0` means
null, not OOM). **Also recorded there: I renamed the game's LPC folder aside as
a "diagnostic" and told the user it would re-download automatically. It did not.
That broke the install further and cost a full game redownload.** Never move
files out of a user's game install on a hunch.

**PUBLISH PRE-FLIGHT (all verified, not assumed):**
  * `level.tod_dev` / `tod_god` = false
  * all three debug `IPrintLn` sites confirmed dev-gated (hellhound dbg, scatter
    debug_dump, the upgrade input probe) - no on-screen text for players
  * CREDITS.md: ZERO TODOs. The two open handles were resolved from the pack
    readmes (GentlemanCheeseMan - Gift of Death; HarryBo21 - Civil Protector),
    and the stale header line claiming handles still needed verifying is gone
  * arity lint clean across 53 files; full build (cod2map + LED + linker) with
    the bank guard, linker auto-retry and game watchdog all active

**SHIPPING KNOWINGLY BROKEN, both cosmetic and both tracked in docs/33 & 32:**
  1. Five cards advertise numbers the code no longer pays - SUPPRESSING FIRE,
     KNIFE SPEED, LEECH, SPRINT, MOBILITY. The re-bakes never arrived as PNGs
     (contact sheet only, numbers proofread correct). Pure drop-in when they do.
  2. ELECTRIC CHERRY's missing buy trigger is UNCONFIRMED either way - the
     self-heal (machine_for + coherence_watch) ships active, but with dev off
     the diagnostic never ran, so it has no named root cause.

Contents of this publish: the full 2026-08-24 run - v10.14 balance pass, v10.15
Gift of Death + powerup durations, v10.16 playtest fixes, v10.17 FORCED MARCH
art, v10.18-20 the keyboard root-cause fix (action buttons: MOUSE1/MOUSE2/V/R to
switch, hold SPACE/F to lock).

## 2026-08-24 (v10.20) — KEYBOARD, ROOT-CAUSED AT LAST: the working input was always the D-PAD

(User, after the third failed keyboard attempt: "look at how its suppose to be
done. Aetherium HUD does it, things like this are already solved. Should be
straight forward. Maybe cause its not in pause menu we arent initializing
something." Answered by a 6-agent research workflow over stock LUI, the
Aetherium kit, map 1, community packs and the GSC/usercmd API docs.)

**ROOT CAUSE — and every previous fix missed it because it was in the OTHER
half of the input code.** Focus movement had exactly two sources and a keyboard
can reach NEITHER:

1. `ActionSlotThreeButtonPressed` / `ActionSlotFourButtonPressed` **ARE THE
   CONTROLLER D-PAD.** Proof from stock, not inference —
   `share\raw\scripts\shared\util_shared.gsc:2404`:
   `level._button_funcs[ BUTTON_RIGHT ] = &ActionSlotFourButtonPressed;`
   BO3 PC binds no keyboard key to an action slot in zombies, so these are
   permanently false on KBM. **"Controller works perfectly" was the d-pad the
   whole time** — which is why every keyboard fix that added another
   movement-based read changed nothing.
2. `GetNormalizedMovement()` is documented as "the player's **MOVEMENT**
   normalized" — not the movement INPUT — and every card flow wraps
   `present_choice` in `menu_freeze()`, which pins `SetMoveSpeedScale( 0.001 )`.
   A movement-derived read under a 0.001 pin is ~0 **for both devices**; the pad
   never noticed because the d-pad carried it. Treyarch calls this function
   ZERO times in all of `share\raw`.

So: v10.3's A/D, v10.18's W/S and v10.19's mouse widening were all bolted to
lanes that could not deliver. The bug was never "which key" — it was "which
API".

**THE FIX — action buttons, the lane BOTH devices bind, with the author's own
shipped keyboard proof.** Map 1's leaderboard consent card
(`_acc_leaderboard.gsc:588-596`) is an in-game, played, hold-to-choose picker
driven by `MeleeButtonPressed()` + `AdsButtonPressed()` and nothing else — a
live KBM precedent sitting in this codebase all along. Both menus now read FOUR
action buttons, each edge-latched and pre-seeded:
  * MOUSE1 / RT -> left card (draft: previous)
  * MOUSE2 / LT -> right card (draft: next)
  * MELEE (V / R3) -> flip / next
  * RELOAD (R / X) -> flip / next
Four rather than two **deliberately**: `menu_freeze` calls `DisableWeapons()`,
and if that ever suppresses attack/ads, melee/reload are an independent path to
the same result. D-pad kept untouched for the pad; hold JUMP/USE lock untouched
(SPACE/F on keyboard, A/X on pad — both already arm-on-release).
`GetNormalizedMovement` is KEPT as a free bonus lane but nothing depends on it.

**THE v10.19 LUI BRIDGE IS DELETED** — file, zone rawfile, CSC LuiLoad, both
`#precache`es, both OpenLUIMenu/listener/close blocks. It was never going to
work, and the research says why: a menu opened with `OpenLUIMenu` is a
HUD-layer overlay that is not on the focused menu stack, so its
`AddButtonCallbackFunction` handlers are never dispatched to. Every
`OpenLUIMenu` in stock, in map 1 and in this map is display-only; even
Aetherium's own in-game HUD binds zero buttons. The pause menu works because it
takes focus explicitly — `AetheriumStartMenu.lua:367-391` calls
`Engine.SetUIActive( controller, true )` on `menu_opened`, which no HUD menu
does. **The user's instinct ("we aren't initializing something") was exactly
right; the missing init is a focus grab that is unsafe to do mid-round** — it
would take over the screen, and in solo an open menu pauses the server, stalling
the very GSC loop that runs the choice timeout. Recorded as Plan B:
`LuiEnable( localclientnum, menuname )` / `LuiDisable` (documented at
`docs_modtools\bo3_scriptapifunctions.htm:2084-2086`, client-side, ZERO stock
callers) — unexercised ground, not for a publish build.

**HINTS NOW STATE ONLY THE PROVEN LANE**: "SWITCH: [MOUSE1] [MOUSE2] or [V]
LOCK: HOLD [ SPACE / F ]". The old hints promised WASD/arrows, which was a
promise the engine could not keep.

Also evaluated and REJECTED: `notifyOnPlayerCommand` — not a T7 API (zero hits
in `share\raw`, absent from the API doc). Map 1 reached the same conclusion
and shipped an ADS+melee chord instead.

**dev + god hardcoded OFF** (user request) — publish candidate. Consequence: the
Electric Cherry `perk_scatter:` diagnostic and the input probes go silent, so
the cherry bug (docs/32) still has no named root cause; its SELF-HEAL ships
active. `-GscOnly` build (scripts + Lua + zone rawfile only).

## 2026-08-24 (v10.19) — THE KEYBOARD BRIDGE: card menus take keys at the LUI layer, the pause-menu way

(User, after the v10.18 retest: "Still doesnt work. In the aetherium pause menu
hud it works. This should be straight forwards." They were right on all three
counts.)

**WHY EVERY PRIOR "KBM FIX" FAILED: they all rode the same unverified reads.**
v10.3's A/D, v10.18's W/S, the mouse/F widening — every one polled server-side
GAMEPLAY reads (GetNormalizedMovement / JumpButtonPressed / Attack / Use), and
NONE of those has ever been live-verified to deliver KEYBOARD input in the
menu-freeze state. Map 1's freeze lesson and every menu test since were
CONTROLLER runs; the controller working proved only the controller's half. The
user's pause-menu observation named the difference: the Aetherium menu binds
keys AT THE LUI LAYER — AddButtonCallbackFunction( ..., LUI_KEY_NONE, "ESCAPE",
fn ) with raw key-name strings — which is why keyboard works there and nowhere
else in the map.

**THE BRIDGE (new file ui/uieditor/menus/hud/tod_menu_input.lua):** an invisible
dedicated menu binding W/A/S/D, all four arrows, SPACE, ENTER and F via the
Aetherium idiom (LUI_KEY_NONE = keyboard-only; controller bindings untouched).
Each press forwards to the SERVER over plumbing that is 100% stock and already
half-used by this repo: Engine.SendMenuResponse (the Aetherium menu calls it) ->
stock CodeCallback_MenuResponse (callbacks_shared.gsc:889) -> player notify
( "menuresponse", action, arg ). A per-choice listener translates our tod_*
tokens into self.tod_lui_cmd; the existing input loops consume it. The server
remains the sole authority on focus and lock.

**SCOPING IS LOAD-BEARING:** the bindings exist ONLY while a choice is on
screen — GSC opens tod_menu_input at present_choice / run_select_input entry and
closes it on every exit (lock, LUI lock, timeout; panel: choice_input_close,
draft: cls_input_close). Key bindings on an always-open menu could eat A/D/SPACE
from normal gameplay, and tod_upgrade (always open — it hosts the damage numbers
and luck bar) was therefore never the place for them. During a choice the world
is frozen, so eating movement keys is the desired behaviour.

**SEMANTICS:** keyboard = PRESS-TO-LOCK (SPACE/ENTER/F, instant — the hold gate
is a controller anti-fatfinger and stays on the jump/use path). Panel: A/LEFT =
left card, D/RIGHT = right, W/S/UP/DOWN = flip (two cards — vertical means "the
other one"). Draft: left/up = previous, right/down = next, wrapping. Hints:
"SWITCH: WASD / ARROWS   LOCK: [ SPACE / ENTER ]".

**PROOF INSTRUMENTATION (dev builds):** every bridge token prints
"lui inp: tod_left" on arrival — one keypress verifies the lane end-to-end —
and v10.19a's usercmd probe ("inp mv=..") still prints, which will finally
answer whether GetNormalizedMovement ever reaches the server from a keyboard.
HONEST LIMIT: AddButtonCallbackFunction mid-gameplay on a HUD-layer menu is a
first for this repo (the proven use is the pause context); the dev line settles
it in one press.

Also this pass (v10.19a, superseded-but-kept server-side widening): mouse1/
mouse2 switch + hold-F lock on the usercmd path (seeded latches; USE arms on
release because the STATION is bought with hold-F — without arming, the buy
press would insta-lock), plus the dev usercmd probe. Harmless on controller,
kept as belt-and-braces.

4-file contract for the new menu: GSC #precache in BOTH _tod_upgrade_ui.gsc and
_tod_class_select.gsc + OpenLUIMenu, CSC LuiLoad (zm_tower_of_doom.csc), zone
rawfile line, the .lua. -GscOnly build (scripts + Lua + zone rawfile only).
dev+god still ARMED for the user's retest — OFF before publish.

## 2026-08-24 (v10.18) — FULL-WASD menus (beta comments); dev+god armed for the user's retest

(User: "the upgrade menu needs to be fully keyboard accessable. WASD, up left
down right and then hold space bar to select. Im getting comments saying its
not" + "Please turn on god and dev mode and rebuild. I want a full retest on
my end".)

**WHY THE COMMENTS ARE RIGHT: the published beta predates the KBM fix.** The
workshop item went up 2026-08-23 and "KBM can't pick cards" was finding #8 of
v10.3 — the pass AFTER an hour on the published item. The A/D read has only
ever existed locally, so every keyboard player on the beta literally cannot
move focus. This publish is what delivers the fix; today's pass also widens it:

- **UPGRADE PANEL (present_choice): W/S now moves focus.** The forward axis
  (mv[0]) joins the strafe read. With exactly TWO cards side by side there is
  no "up card", so a fresh W or S press flips to the OTHER card — every
  direction key does something, none is dead. Sign is irrelevant to a flip, so
  W-vs-S can never invert. Own PER-SOURCE edge latch (the draft's cross-fire
  lesson, one shared latch misfires between sources).
- **CLASS DRAFT: W/S cycles the 4 cards like A/D** (W previous, S next, row
  wraps). Same per-source latch. The draft matters as much as the panel — it is
  the FIRST menu a keyboard player ever sees.
- **ARROW KEYS: supported exactly as far as the engine allows.** GSC has no
  raw-key read; arrows ride GetNormalizedMovement only for players whose arrow
  keys are BOUND to movement. WASD is the guaranteed lane; the hint says both.
- **Hints updated** (both Lua files): "SWITCH: WASD / ARROWS · LOCK: HOLD
  [ SPACE ]". Hold-SPACE itself was already correct (JumpButtonPressed + the
  v10.8 release-arming gate) and is untouched.

**DEV + GOD ARMED** for the user's retest — remember: BACK TO false BEFORE THE
PUBLISH BUILD. This armed run doubles as the two experiments the crash night
left open: (1) if this build LOADS, the "dev breaks the load" theory is dead
(the install was dying; redownload fixed it); if it does not load, the theory is
confirmed on a healthy install and docs/32's three suspects get bisected.
(2) dev_print is gated on tod_dev, so the ELECTRIC CHERRY diagnostic prints
again — first ~10s, top-left, "perk_scatter:" names the bug (never captured /
no machine entity / trigger drifted).

First build to PACK the FORCED MARCH art (v10.17 wired it after the 02:21
build). Full build (GDT). Pack credits hunt: dropped at the user's direction.

## 2026-08-24 (v10.17) — FORCED MARCH card art installed; publish prep; THE CRASH WAS THE INSTALL

(User: "Okay getting the assets now" -> "Images are downloaded. Please implement"
-> "lets just implement everything ... make sure dev and god are both hardcoded
off ... Then lets do a full rebuild and ill publish ... I did a redownload of the
game and it works now".)

**THE OVERNIGHT CRASH MYSTERY, CLOSED: it was the game INSTALL, not the map.**
Full arc, because three wrong theories got changelogged on the way and the record
should end honest:
  * v10.15+16 built at 01:54 and played fine. The 02:00 -GscOnly (dev+god armed,
    at the user's request) would not load. Neither would 02:03, nor a 02:12 full
    rebuild onto freshly deleted sound banks, nor 02:21 back in ship state.
  * Theory 1 (sound banks poisoned by my build overlapping the user's session —
    a mistake I really did make): bank ritual + full rebuild. Still crashed.
  * Theory 2 (arming level.tod_dev breaks the load — the only code diff between
    working and broken): reverted to ship flags. Still crashed.
  * EVIDENCE, finally: console_mp.log (unbuffered, logfile 2) ended at
    "Loading fastfile 'core_ui'" — the game dying while booting ITS OWN MENU,
    before any usermap is mounted. PLAY_NO_FLAGS.bat — the bisect that script's
    own header describes — did not boot either. Engine/install level, ours ruled
    out. The user redownloaded the game; it works.
  * The dev-flag theory is therefore UNCONFIRMED, not vindicated — the 02:00
    crash may well ALSO have been the dying install. memory and docs/32 updated:
    the dev-mode suspicion needs one deliberate armed build on the healthy
    install before anyone treats it as real. The three ranked suspects
    (dev_money_loop's player.score read, debug_dump's unguarded pad.disp, the
    dev boss cadences) stand as the checklist for that run.
  * Kept from the wreckage: crash diagnosis starts at console_mp.log and the
    PLAY_NO_FLAGS bisect, not at theories; blackops3.start is a crash marker
    (present = last run died); BO3 has months of .dmp files on this machine, so
    "it crashed" alone is weak evidence of anything.

**FORCED MARCH ART INSTALLED + WIRED (files (39).zip).** Contact sheets
proofread first, per the process: the march sheet is APPROVED (boot + amber
chevrons, +5/+10/+15% MOVE SPEED in per-rarity colours, AK-47 ONLY · ALWAYS ON,
pips 1/2/3) and the full docs/25 §10 chain is done — 4 PNGs into
source_data/tod_ui_images/_images/, 4 image.gdf blocks (exact clones of the
proven card/plate shape; GDT re-verified brace-balanced, 232 image blocks), 4
zone image lines, CARD_SLUG[37] = "march", PAUSE_PLATE_MAX 36 -> 37.

**THE 15 RE-BAKES ARE STILL OUTSTANDING** — files (39).zip carried only their
CONTACT SHEET (all fifteen numbers proofread CORRECT: suppressing fire 12/24/36,
knife speed -10/-16/-20, leech +4/+6/+8, sprint and mobility +5/+10/+15) but not
the full-size PNGs. When they arrive they are pure drop-ins (identical
filenames, zero wiring) + a full rebuild. Until then those five cards keep
advertising their old numbers — docs/33 remains the tracker.

**PUBLISH PREP:**
  * level.tod_dev / tod_god verified hardcoded false.
  * _tod_perk_scatter::dev_print RE-GATED on level.tod_dev — it had been
    un-gated for one build during the crash hunt, and a published map must not
    print yellow debug text at spawn. Cost: the Electric Cherry diagnostic
    (docs/32) now needs a deliberate dev build to run, which is the same build
    that settles the dev-flag question above. The cherry SELF-HEAL (machine_for
    + coherence_watch) ships active regardless — only the prints are gated.
  * Full build required and run (GDT changed — the -GscOnly trap).

## 2026-08-24 (v10.16) — first-playtest pass: menu size reverted, assault 4x reverted, panzer eased, PaP + Death Machine drops halved, teleporter wording, cherry self-heal

(User, after playing the v10.14 build. Six items, five of them one-liners and one
of them a bug: "I think we reduced the size of the upgrade menu by 15%. Whatever
we did lets revert that", "Assault class had a 3x and we moved headshot to 4x.
Lets move that back down to 3x actually", "Previously we nerfed the panzers moves
by 50% or something. Lets change that too 40%", "We need to reduce the rate of
pap drops ... lets half the rate ... And we need to drop the rate of death machine
drop too", "Teleporter text should be more specific when you havent unlocked the
area", "Also electric cherry machine has no trigger to buy it".)

Shipped in ONE build together with v10.15 (the Gift of Death and powerup-duration
changes) — the game was still open when that batch finished, so it waited.

**UPGRADE MENU BACK TO ITS OLD SIZE.** The v10.3 shrink ("takes up so much of the
screen") went 213x320 -> 181x272; the user's verdict after living with it was that
the original was right. All four numbers restored — CARD_Y0/Y1 230/550,
CARD_AX0/AX1 390/603, CARD_BX0/BX1 677/890 — re-expanded about each card's own
centre so the pair keeps its layout. Those four ARE the whole knob: every overlay
(icon inset, hint plates, hold bar, fallback text) is keyed off them, in both
directions. No art change either — the cards are 768x1152 PNGs scaled into the
rect.

**ASSAULT HEADSHOTS BACK TO 3x — a full revert, not a stub.** class_hs_scale()
and BOTH its call sites are gone, so the per-hit damage path is byte-for-byte
what it was before v10.14. A function pinned at 1.0 would have left a
multiply-by-one in two hot damage callbacks; the comment left where it lived
carries the recipe instead (one function returning wanted/3.0, multiplied into
raw damage in upgrade_damage_cb and _tod_bosses::rp_damage_feed, on each lane's
own headshot test). CLAUDE.md and the class-draft blurb reverted with it, and
docs/33's group C — an assault class-card re-bake that existed ONLY to advertise
the 4x — is struck out so nobody bakes it.

**PANZER DAMAGE 0.5 -> 0.6.** TOD_PANZER_DMG_MULT was the 2026-08-20 "halve ALL
panzer damage"; a 40% cut instead of 50% is +20% on every number he deals. NOTE
which lever this was: TOD_PANZER_ANIM_RATE is 1.0 and always has been ("put them
back at base", 2026-08-20), so his MOVEMENT was never nerfed — the only 50% panzer
nerf in the tree was damage, which is what moved. It reaches the ELECTROBALL too:
45 x EXPLOSIVE_MULT 0.55 x this = 36 -> 44 per burst-of-three against 150 HP, so
still four bursts to kill where the 2-hit death that caused the original nerf was
144 per two bursts.

**PaP AND DEATH MACHINE DROPS HALVED — via the should-drop callback, not a weight
table.** Stock picks a drop by shuffling level.zombie_powerups and taking the
first entry whose func_should_drop_with_regular_powerups returns true, and on a
false it picks AGAIN in a while(1) (_zm_powerups.gsc:377-386). So a gate that
returns true half the time gives that powerup exactly half its former share and
the re-roll hands the other half to the rest of the pool — no stock edit, and the
total drop RATE is unchanged, only the mix. The loop still terminates because the
always-drop powerups never refuse.
  * tod_pap gets its own should_drop_pap (power gate + coin flip). The PERK BOTTLE
    (tod_free_pap) deliberately keeps the plain power gate and its old rate — it
    shares the same drop model but grants a random PERK, not a PaP, and "pap
    drops" is what was asked about.
  * The Death Machine's stock gate is CAPTURED, not replaced —
    level.tod_minigun_stock_should_drop, the same latch idiom as
    level.tod_mechz_stock_damage_func — so stock's "somebody is already holding
    one" rule keeps working underneath our coin flip.

**TELEPORTER: "^1This teleporter is offline".** Was "^1LINK OFFLINE^7 - open this
floor's breather door". Two problems, one string: "LINK OFFLINE" is jargon, and
the trailing clause reads as a price/requirement, which is what "no cost text"
was about. HONEST LIMIT: there is no cost text anywhere in the teleporter path —
grepped _tod_teleport.gsc (SetCursorHint HINT_NOICON, no zombie_cost, no
script_cost) and the generator (the pads are script-spawned; no teleporter
entities in the .map). The "[Cost: N]" string in this map is authored by
_tod_doors.gsc, not appended by the engine. So if a cost still shows on a locked
pad, it is a DOOR prompt bleeding through and I need to know which pad.

**ELECTRIC CHERRY: A SELF-HEAL AND A DIAGNOSTIC, NOT A DIAGNOSIS.** Say that part
plainly, because the honest state of it matters more than a confident-sounding
fix. Cherry's whole paper trail was walked and every link checks out:
  * the .map struct is a script_struct / targetname zm_perk_machine with model +
    script_noteworthy + a script_string that matches "zclassic_perks_start_room",
    so stock's perk_machine_spawn_init accepts it;
  * that function builds the "zombie_vending" trigger UNCONDITIONALLY for any
    accepted struct (_zm_perks.gsc:1511) — there is no perk-registration gate on
    the trigger at all, which rules out the whole "the perk didn't register"
    family;
  * register_perk_machine really does install ec_machine_setup as
    .perk_machine_set_kvps (_zm_perks.gsc:1854), and that callback really does
    give the machine its unique radiant name and point the trigger's .target at
    it — stock leaves BOTH as "vending_sleight" until it runs, which WOULD produce
    exactly this symptom, and it is wired correctly;
  * standard_powered_items registers every zombie_vending trigger it can see at
    "start_zombie_round_logic", cherry included, and the alias -> "<alias>_on"
    notify that perk_machine_think waits on resolves correctly through
    getVendingMachineNotify;
  * and the turn_perk_off trap — stock Delete-respawns the machine model, which
    would strand our cached t.machine — was already defused by
    b_keep_when_turned_off in capture_and_open.

What the SYMPTOM proves regardless of cause is that a machine MODEL and its USE
TRIGGER ended up in different places, because that is the only way to see a
machine and have nothing to press. So _tod_perk_scatter now enforces the
invariant it is supposed to maintain rather than guessing at the cause:
  * machine_for( t ) re-resolves the machine by t.target when the cached pointer
    has died. move_machine calls it instead of bailing out — a dead pointer used
    to mean that machine silently stopped moving forever, leaving its trigger
    behind at the last pad, which is one of the two shapes this report can take.
  * coherence_watch() checks every 5 s that each captured perk's trigger sits
    TOD_SCATTER_TRIG_Z above its machine, and re-aligns the TRIGGER to the
    MACHINE when it drifts past 96u (the trigger's own 40u radius plus slack).
    The model is the source of truth: it is what the player can see.
    QUICK REVIVE IS EXCLUDED and that exclusion is load-bearing — its solo
    epilogue flies the machine away on purpose, so a drift check would chase the
    trigger into the sky.
  * Under dev it PRINTS what it found, which is the actual point: one dev run now
    distinguishes "cherry drifted", "cherry has no machine entity" and "cherry
    was never captured", and the guesswork ends.

Build: full (a .gdt had changed in the v10.15 batch). Geometry lint clean, arity
lint clean across 53 files, LED bake OK, .ff 95.00 MB @ 01:54.

## 2026-08-24 (v10.15) — Gift of Death: slower fire animation + 80 rounds; Infinite Ammo and Time Warp -30%

(User: "We need to slow down the animation of the Gift Of Death. We sped it up
but way too much", "the ammo should be 80 max instead of 120", "Infinite ammo and
timewarp last way too long. Can we reduce time by 30% on both".)

**THE GIFT OF DEATH'S FIRE ANIMATION IS ITS `fireTime`.** `xmas_gun_fire`'s xanim
block carries no framerate override, so the engine scales the animation to the
weapon's fireTime — there is no separate anim-rate knob to turn, in the GDT or in
script (`zm_weap_xmas_gun.gsh` has no timing constants). **0.24 -> 0.40**, i.e.
250 rpm -> 150 rpm, a 40% longer cycle.

How that field was identified as the one that had been hand-tuned: every other
timing in the whole weapon block is a stock default — raise 0.43, drop 0.36,
reload 1.75, firstRaise 0.30, ADS 0.30/0.60 — and 0.24 was the lone outlier. The
repo has no pristine copy of `xmas_gun.gdt` to diff against (source_data is
untracked past the initial commit, and the file's only mtime is the 2026-08-22
"Gift of Death GDT timing fix"), so **0.40 is a judgement, not a restoration.**
Say the word if it wants to be slower still — it is one field and one full build.

**AMMO 120 -> 80**, on all three of `clipSize` / `maxAmmo` / `startAmmo`, which
this asset keeps equal because the gun is one belt with no meaningful reload. At
the new fire rate that is 32 seconds of continuous fire (was 19 at 120 rounds and
0.24) and ~40 zombies at XMAS_ZOMBIE_SHOTS 2. Nothing in script assumes the old
number — grepped `_tod_powerups.gsc` and the pack's own scripts for it.

Also scaled the PaP form, `"xmas_gun_up_zm" [ "xmas_gun_zm" ]`, 225 -> 150 by the
same 80/120. That is a DERIVED asset: it inherits fireTime (so the slowdown
reaches it for free) but overrides the ammo pool. It is **unreachable** on this
map — `_tod_powerups.gsc` refuses to PaP a temporary weapon-powerup gun — so this
is coherence rather than balance: a derived block sitting at 225 under an 80-round
parent is exactly the sort of contradiction that bites the day something makes it
reachable.

**INFINITE AMMO + TIME WARP: 30 s -> 21 s.** The two modules are vendored into
this repo, and each now carries its own `#define` (`TOD_INFINITEAMMO_SECS`,
`TOD_TIMEWARP_SECS`) instead of reading `N_POWERUP_DEFAULT_TIME`.

**WHY NOT JUST EDIT THE SHARED CONSTANT:** `N_POWERUP_DEFAULT_TIME` is stock's 30
and it also drives INSTA-KILL — which on this map is the 3x damage window in
`_tod_powerups::instakill_3x_override` — plus DOUBLE POINTS, FIRE SALE and
BONFIRE SALE. One edit there would have quietly cut four powerups nobody asked
about. The two the user named are the two that moved.

The HUD countdown needed no second edit: it reads
`level.zombie_vars[ "zombie_powerup_<name>_time" ]`, which `powerup_grab` sets
from this value, so the on-screen timer follows automatically.

## 2026-08-24 (v10.14) — balance pass: LMG/HK/Stormbreaker nerfs, assault 4x headshots, FORCED MARCH, chain lunge OUT, and a full card-art audit

(User, one item at a time across the session: "The LMG class needs a damage nerf
by 10%", "HK needs a clip and reserve nerf by 25%", "Storm breaker needs an all
around nerf by like 15%", "BY default assault class gets 4x headshot multiplier
while all other classes have 3x", "remove chain lunge from the game. It doesnt
work", "remove penetration from HK21 and add to the death machine", "nerf
supressing fire to 12%, 24%, 36%", "AK 47 will need a speed boost. The only AR
that gets a speed upgrade and it only goes 3 levels", "Adrenaline and momentum
upgrades will be swapped on mp5 and mp7", then: "go through each upgrade 1 by 1
and decide if its illustration needs any update".)

**LMG LINE -10% DAMAGE, ONE KNOB.** `CLASS_DAMAGE_MULT.heavy = 0.90` in
gen_tod_twins.js, which lands on the STONER only — computeTierOverrides
normalizes the HK21 and the Death Machine from the TUNED T1, so the cut
propagates up the ladder by construction and the 1 / 1.5625 / 2.4414 tier
spacing is preserved exactly. Emitted: Stoner 265 -> 239, HK21 558, DM 389.
Scaling the higher tiers directly as well would have compounded to -19% on them.

**HK21 CLIP -25%, AND THAT IS ALSO THE RESERVE NERF.** 125 -> 94. The ask was
"clip and reserve", and the honest answer was that maxAmmo/startAmmo are counted
in MAGAZINES: shrinking the belt takes the carried rounds down with it, 750 ->
564, so BOTH numbers on the HUD fall exactly 25% off one knob. Asked which
reading was meant before building; the alternative (also cutting the mag COUNT
6 -> 4) would have compounded to -46% of carried rounds, 875 -> 470.
`gun.clipMult` is applied AFTER the never-shrink floor — the floor exists to
stop a promotion shrinking your magazine, so an explicit nerf has to win over it
or be silently clamped back up. `gun.reserveMult` exists in baseTune for the day
a gun really does need its magazine count cut; nothing sets it.

**STORMBREAKER -15%:** MELEE_TIER_DMG[3] 8000/16000 -> 6800/13600, in the
generator AND in `_tod_classes::register_melee_dmg` (two copies of one number,
the asset's meleeDamage and script DoDamage). One-hit reach r29 -> r28, PaP
r36 -> r35. This is the one rung that now breaks "tier N base = tier N-1 PaP" —
a PaP'd katana (8000) out-hits a fresh axe (6800) until the axe is PaP'd. ~1
round, accepted as the direct cost of nerfing the top rung alone.

**ASSAULT HEADSHOTS ARE 4x, AND IT IS A CLASS PROPERTY.** `class_hs_scale()`
next to `class_speed_base()` in _tod_upgrades.gsc, same doctrine: keyed on the
CLASS so it survives a roster swap. Every generated gun ships
locHead/locHelmet/locNeck 3.0 (LOC_NORM) and the ENGINE has already applied it
by the time a damage callback sees the hit, so this returns a scale ON TOP —
4/3 for the assault, 1.0 for everyone else — landing an assault headshot at
exactly 4.0x. The per-gun locHead alternative would have been exactly 4.0 on
today's three assault rungs and silently wrong the first time the roster moved.
Both lanes that can pay a headshot call it: `upgrade_damage_cb` (the horde, and
the Panzer — his wrap re-scales the value we return, so it carries) and
`_tod_bosses::rp_damage_feed` (the fallback lane), and the boss lane calls the
FUNCTION rather than copying the number, for exactly the reason its own comment
block warns about.

**PENETRATION MOVED HK21 -> DEATH MACHINE.** Three views of one fact, all three
changed together or the script asks GetWeapon for a form that was never emitted:
the LADDER `axes` in gen_tod_twins.js, `register_gun` in _tod_classes.gsc, and
`set_guns( "penetration" )` in _tod_upgrades.gsc. Ledger-neutral — the p-ladder's
3 levels x 2 forms = 6 registrations just changed stem. Total still 194/220.

**SUPPRESSING FIRE 25/40/55 -> 12/24/36.** Base and step are both 0.12 now, so
the ladder is linear instead of front-loaded. FOUR copies of these numbers, all
moved: the two `#define`s, the add_domain description, `DOMAIN[29].desc` and
`DETAIL[29].val` in the Lua — and the CARD ART, which is the one that needs a
re-bake (see below).

**FORCED MARCH (domain 37) — the assault finally has a speed door.** SPRINT is
skirmisher + slasher, MOBILITY is heavy, and the assault had nothing. Gun-bound
to t9_ak47, 3 levels, riding the SAME +5%/Lv lane as SPRINT and MOBILITY in
`apply_move_speed()` rather than inventing a second speed multiplier. Caps at
+15%, taking the assault 0.9 -> 1.035: just past the skirmisher's BASE, still
short of a skirmisher who has spent anything on SPRINT. No card art yet — 37 is
past PAUSE_PLATE_MAX, so the pause menu draws a text row and the draft falls
back to the DOMAIN row's text. Both are supported paths.

**ADRENALINE <-> MOMENTUM, MP5 <-> MP7.** Adrenaline was MP5-bound; momentum was
not gun-bound AT ALL (a skirmisher class domain rollable on all three rungs), so
this does not just move it, it NARROWS it to the MP5 — the only reading under
which "mp5 momentum" is not a no-op. SECOND WIND stays on the MP7, which now
carries two uniques.

**CHAIN LUNGE IS OUT** (reported broken twice; the second time ended it).
Unwired in four places — the zone scriptparsetree, _tod_main's #using + init,
_tod_upgrades' #using + add_domain + reset line + on_class_gun_kill hook, and the
Lua's CARD_SLUG[22] + DETAIL[22]. `_tod_lunge.gsc` is KEPT ON DISK with a RETIRED
header naming all four: scripts/ is untracked past the initial commit, so a
delete there is unrecoverable, and its steering loop is the only working
reference for flying a player on this map. DOMAIN[22] and `domain_id( "lunge" )`
stay mapped, same as "echo" and "grinder" — key-keyed maps, a stale entry is
inert, and disturbing them would shift ids the pause plates depend on. The three
`i_tod_card_chain_lunge_*` zone lines DID go: unreachable art is dead weight in
the .ff, unlike a Lua row. `tod_classes::melee_dmg()` was this module's only
caller and is now unconsumed — flagged in place rather than deleted, with a note
to delete it if nothing claims it by the next melee pass.

**THE CARD-ART AUDIT — and the lesson it turned up.** Every live domain's card
was OPENED and its baked text read against the shipping GSC numbers. Five cards
are stale, and only ONE of them is today's fault:

| card | says | should say | stale since |
|---|---|---|---|
| SUPPRESSING FIRE | 25 / 40 / 55% | 12 / 24 / 36% | today |
| KNIFE SPEED | -10 / -20 / -30% | -10 / -16 / -20% | v10.13 (log ladder) |
| LEECH | +4 / +8 / +12 HP | +4 / +6 / +8 HP | the stage table |
| SPRINT | +3 / +6 / +9% | +5 / +10 / +15% | 2026-08-21 (3% -> 5%/Lv) |
| MOBILITY | +3 / +6 / +9% | +5 / +10 / +15% | same |

**A domain retune has to schedule its own re-bake.** "All text baked in — the
game reads nothing from the art, but players do" (docs/31) cuts both ways: the
card is the ONLY place a player ever reads the number, so a nerf that moves a
`#define` and stops has shipped a card that lies. Four of the five above had been
lying for days. Prompts + the full pass/fail table: **docs/33_upgrade_art_audit.md**.

Two process notes from the audit, both worth keeping:
- **Read the PNG, not the prompt doc.** docs/26 still specifies KILL RELOAD as
  "+25/+50/+75% MAG BACK · ON EVERY KILL" — the card was re-baked to "EVERY 75TH
  KILL / MAG BACK TO FULL" after v9.43 and the doc never caught up. Trusting the
  doc would have queued a re-bake of a card that is already correct.
- **The gun moves and the weapon nerfs need no art at all.** No card, class card
  or tier card carries a weapon stat or names a gun for a unique, so
  HK21->Death Machine, MP5<->MP7, the LMG -10%, the HK clip and the Stormbreaker
  -15% are all invisible to the art.

**COPY FIXES SHIPPED WITH THE BUILD (Lua only, no re-bake).** The audit also
caught seven `DETAIL` rows still saying a domain was "class gun only": 3 BOUNTY,
6 HEADSHOT, 8 SCAVENGER, 25 ADRENALINE, 27 KILL RELOAD, 29 SUPPRESSING FIRE,
35 GIANT SLAYER. The 2026-08-23 widening put every weapon on one damage lane and
un-gated `on_class_gun_kill`, so all seven had been describing a restriction the
code stopped enforcing — DETAIL[1] DAMAGE was updated at the time and its
siblings were missed. LEECH (13) keeps its gate and its wording; the TWIN domains
(15/16/17/19) really are class-gun-only, because the variant forms only exist for
that gun. Also `tod_class_select.lua`: the HEAVY blurb still advertised
"echo rounds", a domain deleted 2026-08-23 (fallback-only text — the baked class
cards carry what players see — but it was a lie in the source), and the ASSAULT
blurb now reads "4x headshots + recoil".

Build: full (a .gdt changed, so -GscOnly would have been worse than nothing).
Geometry lint clean, arity lint clean across 53 files, LED bake OK, ledger
194/220, .ff 95.00 MB, deployed tree diffs empty against the repo.

## 2026-08-23 (v10.9) — THE STUCK SOUND FOUND (co-op only), thin road, spawns in front

(session d537d3a9. User: "constant ringing and never went away. Maybe has to do
with gift of death machine gun" — their guess was right, and better than they
knew. Also: "make the path to the castle very thin", "zombies need to
aggressively spawn in front of you", "Panzer included should spawn in front".)

**THE RINGING: the Gift of Death sleigh bells, and it is a CO-OP-ONLY bug.**
35-agent hunt, 2 independent agents converged on the same two lines. The ON
state is BROADCAST to every player (foreach GetPlayers), but the OFF state was
sent to SELF ONLY — util_shared third arg is the RECIPIENT. So every OTHER
client started three LOOPING sleigh-bell aliases and was never told to stop:
once anyone picked up the Gift of Death and lost it, everyone else heard bells
at that player-s hand for the rest of the match, with no recovery path in
script. **Solo is clean by construction** (GetPlayers() is the holder), which
is exactly why it survived testing. Fixed by symmetry: the stop now goes
wherever the start went. Also fixed the second half both agents flagged — the
client -off- path was SetLoopState volume 0, a MUTE not a stop, leaving three
voices running per player per match forever; it now fades, stops for real, and
clears the latch so a later pickup re-plays instead of stacking.
The Death Machine powerup is remapped to the Gift of Death here, so every
pickup is a timed grant with a guaranteed take-back — the trigger fires
constantly. Verified correctly-stopped by the same sweep: protector hover hum
(both sites), music channel, Panzer claw loops.

**THE ROAD IS THIN NOW.** CW_HALF 288 -> 80 (576 -> 160 wide) = EXACTLY the
tower-s own stair width, so the causeway reads as one last flight rather than a
plaza. This reverses my own v10 widening, which existed to make -ambushed in all
directions- survivable; the encounter is now -they come up in front of you-, so
the flanking room it bought is no longer what the fight is built on. Rails stay
— at 160 wide over 19,000 units of air they are the difference between a
gauntlet and a coin flip. The causeway risers moved to the CENTRELINE (x=0):
at the new width the old +/-180 was off the road entirely, spawning nothing
reachable.

**SPAWNS COME FROM IN FRONT.** level.zm_custom_spawn_location_selection is
stock-s own supported override (_zm_spawner.gsc:2950, shipped precedent
zm_giant.gsc:1014) — we are not patching the spawn path, only choosing from the
candidates stock already built. During the run: find the LEADING player (largest
|y| in the crown frame = furthest along the road), then take the nearest
candidate inside the half-plane they are FACING (dot > 0.35, yaw-only). Facing
rather than road-direction is deliberate: turn to fight what is behind you and
the next wave arrives in your face too. **Outside the finale it returns
array::random(spots) — verbatim stock behaviour** — because the hook is global
and consulted on every zombie of every round; getting that wrong would silently
re-pace the entire map.

**THE PANZER BLOCKS THE ROAD.** During the run his spawn query anchors
TOD_PANZER_FRONT_DIST (700u) AHEAD of the anchor player along their facing
instead of on them — turning him from something chasing the party up the tower
into the thing standing between them and the Crown. pick_spawn_point still does
the real work (navmesh, enabled zones, clearance), so an unreachable forward
point falls through its existing two passes rather than stranding him.

Navmesh REBUILT for the narrower road (160 wide is the same width Panzers
already path on all 50 flights, which is why that width was chosen). Full build
94.46 MB @ 9:44:14 PM, zero errors, LED fresh, staleness gate clean, and the
peer session-s Mule Kick icon packed (2 i_tod_perk images in the assetinfo).

## 2026-08-23 (v10.8) — pre-ship verification of the peer's edits: 1 critical + 3 majors caught

(session d537d3a9. I own the linker, so I adversarially verified the peer
session's just-landed edits instead of building on trust — 30 agents, 8
confirmed / 17 refuted. The single most valuable finding was about MY OWN
process, not their code.)

**CRITICAL — I declared a stale build ship-ready.** The .ff linked at 20:37:25
predated a _tod_finale.gsc write at 20:37:46 by 21 SECONDS, and _tod_upgrades.gsc
by four minutes. In a two-session tree, 'I just built' is NOT 'the build
contains the tree'. Missing from that .ff: the uplink beacon + corrected
EXTRACTION hint (the fix for the user-reported 'game couldn't end cause of some
uplink issue' — a MAP-ENDING BLOCKER), the Bulldog nerf removal, and both
halves of the solo Quick Revive price fix. NEW STANDING GATE, now run before
every ship claim: must return EMPTY. It does for this build.

**MAJOR — the peer's one CHECKED-AND-LEFT call was wrong**, and it is the good
kind of wrong to catch. They left AetheriumPlayerInfo's scoreModel subscription
bare because map 1 leaves it bare too — correct observation, wrong conclusion:
map 1 can leave it bare ONLY because it guards the whole block with a
once-per-clientNum early return that the tower never had. So it IS a rebind
path: 7 score subscriptions re-added per rebind (roster change, and our own
game-over RESTART MAP button's map_restart) => N duplicate '+10' popups per
score event plus the same leak family. Guard ported verbatim.

**MAJOR — the v10.4 co-op breather respawns were 100% INERT.** manage_zones()
LOCKS every player_respawn_point at init, and the only unlock in the stock zm
tree is enable_zone matching  — the four
generated groups carried no script_noteworthy at all, so they could never
unlock and bled-out co-op players kept getting exiled to the base arena: the
exact bug v10.4 claims to fix. Added , which
also delivers the door-gating the original comment believed it got for free
(the zone only enables when that lap's door is bought). Verified all four KVPs
match their zone targetnames exactly.

**MINORS in the new through-wall trace, both fixed.** (a) It also gated
MOD_BURNED, so a player who broke line of sight had the Panzer's flamethrower
burn silently EXTINGUISH — a nerf to one of his two main attacks, not a
through-wall fix; DoT is now exempt on the same fail-open-on-already-landed
logic as melee. (b) The fire gate traced from +55 and the damage gate from +45,
so a Rogue Protector could pass the fire check and fail the damage check —
firing with full FX for exactly zero, which reads as broken hit detection
rather than as cover working. Heights aligned.

VERIFIED CORRECT (refuted concerns worth recording): SightTracePassed arity is
4 and TRUE means LOS CLEAR — the peer's usage matches stock exactly
(ai_sniper_shared.gsc:743's identical shape, _zm_laststand.gsc:1113's
near-identical ZM offsets), so no boot risk and no inverted logic; the splash
trace-from-inflictor is correct; both Lua handle+remove sites match the five
already-correct sites in their own files.

Full build (cod2map + navmesh + LED + linker): 94.37 MB @ 8:58:53 PM, zero
unexpected linker errors, LED newer than BSP, and the new staleness gate clean.

## 2026-08-23 (v10.7) — vendor PaP: the pistol could steal the purchase (peer catch off CZ's report)

(session d537d3a9 + peer session. CZ's "the assault rifle didn't seem like it
gets pap'd" was the ORIGINAL v10.2 vendor hole against the first build — but
the peer traced tonight's v10.3 fix and found its replacement hole: the lane
keyed purely off the weapon IN HAND, so paying while holding the PISTOL bought
a PaP'd pistol while the class gun stayed dry. Same player experience, points
burned on the wrong thing. The sidearm lane now opens ONLY once the class gun
is already packed (tod_pap_owned): the class gun is always the vendor's first
sale regardless of the held weapon — the latch lane packs it even with a
sidearm out — and the MR6-after-class-gun case stays served. Note this is
deliberately NOT stock behavior: stock PaP upgrades the weapon in hand, but
this map's combat identity is the class gun and CZ's report shows that is
what players expect the 5000 to buy.)

## 2026-08-23 (v10.6) — THE FRAME-DEATH FIX: two vendored-kit UITimer leaks, regressions of map 1's own 2026-07-04 fixes

(session d537d3a9. The ONE exception to the same-evening open-items freeze —
the leak-hunt workflow (24 agents, 5 confirmed / 13 refuted) landed minutes
after the freeze build and root-caused the beta's worst report, 'memory leak,
1 frame by 2nd stage', to two CONFIRMED-critical leaks. Shipping without them
would re-ship the exact complaint.)

Both live in the vendored Aetherium HUD, and both are fixes MAP 1 ALREADY
SHIPPED on 2026-07-04 — the tower vendored the pristine, unfixed kit on
2026-08-19 and silently regressed them:

1. **AetheriumPowerupNotification.lua** — every Max Ammo notification added a
   never-closed repeating 3s UITimer whose handler re-played the hide clip AND
   minted another never-closed 300ms timer on every 3s fire, forever — a
   COMPOUNDING cascade (quadratic in wall-clock). Map 1's fix comment blames
   this exact code for 'gradual frame decay' and a live round-26 4-player
   'Failed to allocate from state pool' crash.
2. **AetheriumLoadout.lua** — two never-closed repeating UITimers (130ms /
   100ms) per weapon swap; grenade throws toggle the weapon TWICE. Map 1's
   memory: 'the monotonic frame decay'. This map's gun churn (class swaps,
   tier cards, PaP give-before-take) makes it strictly worse than map 1 had it.

Fix = map 1's proven shape, ported surgically (wholesale copy rejected — map
1's copies carry acc-specific HUD edits): one handle per timer role on self,
close-before-create, close-inside-handler so each fires exactly once. Zero
bare UITimer creations remain in either file (asserted by the port script).

Filed OPEN in docs/32 §1b (peer steer): both frame reports are height-linked
and 'always at the same point', which a RENDER cause fits as well as a leak —
the proven leaks are fixed, the render question is judged from post-fix beta
reports. §1c: an unconfirmed second report ('3rd-PaP lag') awaits its text.

## 2026-08-23 (v10.5) — perk icons REVERTED to the stock shaders (user directive)

(session d537d3a9. User: "Why did you switch to the other perk icons. I want
original perk icons from stock game. Dont switch this. My callout was that some
where not the stock images. Please fix.")

The v10.3 Ronan swap over-reached: the callout meant "make the broken ones
stock", not "restyle all of them". Reverted wholesale — the mapping carries the
stock shader names again (verified character-for-character against the stock
perk .gsh SHADER defines, all 8), the 8 i_acc_perk zone lines are gone, the
vendored acc_perk_shaders GDT + PNGs are out of this repo (map 1 keeps its own),
and Ronan is off CREDITS.md since nothing of his ships here now.

**What is now KNOWN about the white squares** (from the packed asset list, not
theory): a usermap's ff packs NONE of the specialty_* materials — the perk
modules' own #precache lines do not force them in (confirmed: zero specialty
materials in assetinfo). The icons that render come from base-game ffs the
engine always loads; the white ones exist only in ffs it does not. The mod
tools ship NO raw sources for any of them (materials/, texture_assets/, images/
all empty of specialty/perk icons), so they cannot be packed from here. A
string census of the shipped ffs is not possible either (compressed).

**The path for the still-white icons**: the user names which machines white-
squared, supplies the official icon art as PNGs, and each lands as an
i_tod_perk_<name> image asset (the proven i_tod_perk_cherry lane) with a
one-name swap in the mapping. That shows the ACTUAL stock art, packed by us.
Until then the map renders exactly what the stock names resolve to at runtime —
the same behaviour the user already saw, minus nothing.

Cherry deliberately keeps i_tod_perk_cherry: stock ships NO cherry shader (its
.gsc literally defines the QR icon as its shader), so "stock" for cherry would
draw two Quick Revive icons.

## 2026-08-23 (v10.4, co-op audit session) — POST-SHIP AUDIT FIXES: the co-op failure surface

(Two sessions landed v10.4 work in the same hour; the "main session" entry
below records the release audit + merge. One build ships both.)

(Applied from the pre-beta audit artifact, after the map had already shipped.
The Rogue Protector debt — the audit's #1 blocker — was already fixed in this
tree by a concurrent session before this pass began, both halves of it: debt SET
not summed, and `protector_due` capped at `TOD_RP_MAX_ALIVE`. That one is
theirs. Everything below is what was still open.)

**RESPAWN EXILE — the worst co-op bug in the map (`gen_tower_map.js`).**
The map emitted exactly ONE `player_respawn_point`, in the base arena, and no
spawn-override callback anywhere in `scripts/` (grepped `check_valid_spawn_override`,
`check_for_valid_spawn_near_team_callback`, `custom_spawnPlayer`, `_retain_perks`
— zero hits). Stock's selector therefore had a one-element candidate list, so
every bled-out co-op player returned to z=28 no matter how high the party had
climbed: a floor-40 death is a 53,088-unit re-ascent past every door, unperked.
Worse, breather balconies deliberately emit no risers, so the lone returning
player drew most of the spawn budget onto himself the whole way up. He did not
climb — he looped the arrival pad.
- **Four new respawn groups**, one per breather balcony, four child spawn structs
  each (20 entities; 489 -> 509).
- **The gating is free.** Stock only considers a group whose origin sits inside an
  ENABLED zone (`_zm.gsc:3399`), so a breather group is ineligible until that
  lap's door is bought — a party can never respawn past a door it has not paid
  for, with no script support at all.
- `script_string` is **deliberately omitted**: `get_player_spawns_for_gametype`
  (`_zm_gametype.gsc:589`) adds a struct to every location when it carries no
  gametype string. The base group carries `zclassic_start_room ...` because it IS
  the start room; these are not. `locked` is omitted for the same reason the base
  group omits it — stock never initialises it, and only maps that want a spawn
  disabled ever set it (`zm_giant.gsc:413`).
- Placement verified against the zone volume, not eyeballed: all four breather
  laps are EVEN so every balcony is the mirrored SW one, floor x[-800,-256]
  y[-992,-416] inside a volume of x[-820,-236] y[-1012,-416]. The points sit east
  of the teleporter ring (x[-723,-557]), north of the perk wall (y=-959), clear of
  the PaP at (-320,-470) and the station at x=-760. Heights land at 3676 / 7516 /
  11356 / 15196 — mid-landing top +28, matching the base spawns' height above
  their own floor.
- **This is a geometry change: it needs a full build and an LED bake gate.**

**THE FINALE COULD BE WON BY HIDING (`_tod_finale.gsc`).**
`finale_run` threaded `depart()` unconditionally the moment the song ended, and
`depart()` had no liveness check and no position check. Two consequences, both
worse than the bug itself: the 6400-unit gauntlet was **opt-in** (buy the uplink,
retreat one flight down a 160-wide stairwell fed by two risers, win 197s later —
strictly better than holding a 576-wide deck with seven flanking risers under a
0.1s spawn floor), and a party spread down the tower all "escaped" while three of
them were forty floors below. The ending now waits on `survivor_at_crown()` — an
upright, living player within `TOD_FINALE_ARRIVE_RAD` of the pad. The radius is
1536, the hall's own dimension, measured from the pad: it reaches every corner of
the interior (far south corners ~1486) and the south gate (~1252), so it means
"inside the citadel", not "standing on the pad" — the pad has been a destination
rather than a control since v10. The ambush keeps running while stragglers close;
a wipe on the road fires stock's `end_game` and this thread dies on its endon,
which is the correct outcome for not making it. The "ready" hint changed from
"EXTRACTION INBOUND" to "REACH THE CROWN" to match.

**EXTRACTION NOW SCALES WITH PARTY SIZE (`_tod_finale.gsc`).** It was the one
party-wide price the v9.x scaling pass missed — a flat 25,000 charged to a single
wallet while the 52-door ladder in front of it scaled x1.00/x1.27/x1.82/x2.36. It
runs through the doors' own `door_price()` so the map has one pricing rule rather
than two; solo is untouched by construction. The hint re-stamps on a party-size
change (one trigger, at most four strings).

**THE DOOR LADDER WAS THE MAP'S REAL LENGTH (`gen_tower_map.js`).** Summed, not
estimated: 52 rows totalled **186,975**, and the flat 25,000 extraction made the
minimum win path **211,975**. The fastest solo class does not cross that until
round 27-28 (~29 with a realistic perk + PaP kit) — 90-120 minutes with no
between-round pause, landing on top of the ammo curve going negative on a map with
no box and no wallbuys. The finale is the best content here and essentially nobody
was reaching it. The perverse part: BO3 pays 10 per damaging HIT, so building
damage REDUCES income (a PaP'd DAMAGE-Lv5 MAC-10 cuts points/zombie ~42%) — the
player who builds correctly arrives LATER.
One lever, pulled hard: **base 1125 -> 750, step 100 -> 60, cap 6000 -> 3000.**
Roof and power deliberately untouched to keep the surface small.

      ladder    178,725 -> 106,680 (57%)     win path  211,975 -> 139,930 (66%)
      floor 10   15,750 ->  10,200           floor 20   41,500 ->  26,400
      floor 30   77,250 ->  48,600           floor 40  123,000 ->  76,680
      cap now binds at lap 39 (it bound at lap 50 before, i.e. never in practice)

Floor 10 still costs a real climb, so the first non-QuickRevive perk is still
earned. **The number to playtest is the round extraction becomes buyable**, not
the door price.

**DOWNED AND DEAD PLAYERS WERE UPGRADE PARTICIPANTS (`_tod_upgrades.gsc`).** The
filter checked only `player_has_domains_left`/`tier_card_eligible` — no laststand
check, no `IsAlive`. So a crawling player was dealt cards nobody could pick while
`run_upgrade_event` held the world paused waiting on him, and stock's bleedout
loop does not pause with the world (grep for any bleedout override across the tod
modules: zero hits) — the freeze he was stuck in was the freeze running his own
clock out. A dead spectator did the same thing to the whole lobby on every event
for the rest of the run. `menu_freeze` already refuses to freeze a laststand
player; this is the other half of that rule, one level up.

**HOLD-TO-LOCK AUTO-PICKED THE LEFT CARD (`_tod_upgrade_ui.gsc`,
`_tod_class_select.gsc`).** Both input loops seeded `held = 0` and sampled
`JumpButtonPressed()` before any wait, with no press-edge and no release gate, so
a player already holding jump when a panel opened locked the left card ~0.3s
later. `menu_freeze` uses `AllowJump(false)`, which suppresses the hop but not the
read. Two systematic triggers, not corner cases: the round-1 event drops its cards
while players who locked their class early are free-running the base, and the
personal station does not pause the world at all, so a dodge-hop mid-fight buys a
card. Both loops now require the button to be seen RELEASED before a hold counts.
The class-draft site matters more — class picks are permanent, and a jump held
through the load would have locked SKIRMISHER every time.

**DOOR HINT STRINGS CHURNED THE TRIGGER-STRING TABLE (`_tod_doors.gsc`).**
`door_price_watch` re-stamped EVERY unbought door the instant the party size
changed — 52 doors, each with a distinct destination AND a distinct cost, so 52
brand-new strings per change on top of the 52 minted at init. A lobby that fills
to four and bleeds back to one walks the multiplier through all four values and
burns ~208 strings on doors nobody is near. The re-stamp now waits until a player
is within `TOD_DOOR_HINT_RANGE` (512), dropping live distinct strings from "all
52" to "the doors the party is standing at". The price is still read live at
purchase, so hint and charge still cannot disagree.

**THE WEAPONS-CSV PURGE REGEX (`tools/gen_tod_twins.js`) — the one that was
silently getting worse every regen.** The stale-row pattern required a comma
immediately after the ladder suffix, so `t9_me_knife_american_k0_zm,` never
matched (`_z` is not `[a-z]\d`). Rows written in the `_zm`-suffixed era survived
every purge AND the current set was appended beside them, so **each regen added 18
duplicate blade rows**: the file was caught growing 145 -> 163 lines mid-audit,
and stood at 180 rows with 36 stale ones (18 names x2) naming assets that no
longer exist. An optional `(?:_zm)?` before the comma fixes it; regenerating
removed exactly those 36 rows and added nothing (GDT and zpkg byte-identical), 144
rows now. **Verified idempotent** — two further regens produce a byte-identical
CSV, which is the actual bug.
Note this was *not* the load-blocker the audit could not settle: the map is
shipped and loads, so the dead rows were log noise. The hazard was latent — the
day a blade is retired or re-laddered, a `GetWeapon()` on a dead name at level
init is the frontend-dump case.

**DOC DRIFT** (all verified against code, all wrong in `CLAUDE.md` or a module
header): protector wave is `int(players*round/3+0.5)` capped at 8, not `round x
2`; the station is +500/buy and 5 uses, not +1000 and 3; HEAVY move speed is 0.75,
not 0.8; the dev-flag ship-delta block said the TIER card drops to 10% (it is 20)
and the uplink was a "90s hold-out" (v10 replaced that with the 191s song);
`_tod_finale.gsc` claimed "~270k of doors" (186,975, now 114,930).

**Lints after the pass:** arity OK across 52 files; weapons OK — 12 guns, 170
GSC-requested names, 144 CSV rows, all resolving; xref OK. Registration ledger 192
against a guard of 220.

**NOT DONE, deliberately.** The ammo curve (no box, no wallbuys, T1-PaP guns go
ammo-negative around round 17-18, and `_tod_finale.gsc` still provides no ammo for
a 191-second three-boss road) is a design call, not a bug — it wants a points ->
ammo sink, which is the user's decision. The DAMAGE domain is still `scope="gun"`
so a tier promotion still zeroes the counter to that curve. Perk scatter is still
silent (`announce_scatter()` still has a deleted body) and Juggernog is still a
2/8 lottery with an expected floor of 25.

**CONCURRENCY NOTE.** This pass ran alongside another session editing the same
tree; `_tod_reaver.gsc`, `_tod_bosses.gsc` and several others moved underneath it.
The reaver debt fix in this tree is the other session's and is better than the one
this pass wrote (it adds the concurrency cap and a finale-aggro guard). Verify no
peer regen is pending before building.

## 2026-08-23 (v10.4, main session) — the release audit: 40 verified findings, every major fixed

(session d537d3a9, answering "all is fixed? Any remaining issues?" with a
68-agent adversarial audit — 9 subsystem auditors, every claim independently
re-verified; 40 findings CONFIRMED, 18 refuted — instead of a recalled answer.
Concurrently, the co-op audit peer session [06f0d9] landed its own fixes on the
same tree; this entry records both, and the merge.)

### The six confirmed MAJORS, all fixed

1. **Vendor PaP still had a hole** (_tod_powerups): the tod_pap_owned refusal
   sat ABOVE the v10.3 lane split, so once the class primary was packed the
   breather vendor refused EVERYTHING — including sidearms the stock lane
   handles. The latch check moved inside the class-gun lane, where it belongs.
2. **The finale boss roof was advisory** (_tod_bosses): TOD_FINALE_BOSS_ROOF
   only gated the pressure loop's own top-ups — both round_watches kept writing
   debts during the run, so 12 live bosses (8+1+3) were reachable and stock's
   31-actor gate then STARVED zombie spawns at the exact moment the run
   promises saturation. finale_pressure_start now clamps banked debts and the
   aggro flag suspends both round-scheduled debt writers; coop_ai_limit leaves
   4 actors of boss headroom during the run (cap 27).
3. **Reaver debt still summed** (_tod_reaver): the exact ~30-protector backlog
   bug, in reaver form — v10.3 fixed protector+panzer and missed this one.
   Now set-to-max, capped at TOD_REAVER_MAX_ALIVE, and finale-suspended.
   (The peer session landed set-to-max concurrently; normalized here to carry
   the cap + aggro-skip too.)
4. **Perk prompts lied about prices** (AetheriumPerks.lua): the Aetherium
   cursor-hint hides the ENGINE hint (which carries the true cost) and prints
   the mapping's static cost — stale for three perks (DT shown 2000/charged
   3000, Deadshot 1500/3500, Cherry 2000/3000). Corrected; QR keeps 1500 (a
   static field cannot show 500-solo/1500-coop — over-display is the harmless
   direction).
5. **The zombie health multiplier was INERT — since it was written**
   (_tod_zombie_speed): on_ai_spawned dispatches BEFORE the spawner's own
   spawn_funcs, and stock zombie_spawn_init writes self.health there with no
   wait — clobbering the inline scale on every stock-queued zombie. Neither
   the 1.25 base (requested 2026-08-22, "scale the zombies health a bit more")
   nor v10.1's co-op +15%/player ever landed. Now applied on a one-frame
   deferred thread. ⚠️ THE GAME JUST GOT HARDER THAN ANY BUILD YET PLAYED —
   +25% zombie health solo goes live for the first time.
6. **PublisherID still uncaptured** — process, not code: capture after the
   next confirmed upload or the uploader mints a duplicate item.

### Minors fixed in the same pass
- Teleporters: gather 100→120 (a rim activation could exclude its own rider);
  up-riders land +140 off the breather down-pad (mid-charge arrivals were
  bounce-warped straight back); pads relocated — f30 (150,-400) had swallowed
  the power-door buy trigger and f40 (-280,-430) had two INITIAL SPAWN POINTS
  inside its radius; the trigger-less arrival takes the tight SW spot and the
  old arrival spot becomes the f40 pad. Every use-trigger now 220u+ from its
  nearest triggered neighbour, 340u+ from the spawn band.
- Card input: d-pad reads edge-latched (a held direction fought the strafe
  latch); jump hold requires a release-first arm (a pre-held jump auto-locked
  the default card ~0.3s in — peer landed the gate, we added the latches).
- Hint plate art height 30→26px (aspect at the shrunken card width).
- The uplink refuses during an upgrade-event world pause (the song clock must
  never start while pickers stand frozen).
- CLAUDE.md de-staled (scatter cadence, protector math, teleporters, six
  music credits); CREDITS.md created — the pre-PUBLIC checklist the audit
  found scattered across four files with two packs uncredited anywhere.

### Merged from the co-op audit peer session (kept, verified)
Breather RESPAWN GROUPS in the generator (bled-out co-op players respawn at
the highest door-unlocked breather instead of z=28 — door-gated by zone
enablement, no script support needed; entities 489→509); finale
survivor-at-crown win gate (the run was OPT-IN — buy, retreat one flight,
win; now a living upright player must be at the citadel) + party-scaled
extraction price through door_price(); doors hint proximity gate (the price
re-stamp minted ~208 trigger strings against the engine's ~250 cache);
downed/dead players excluded from upgrade events (a bleeding-out picker held
the world paused while his own clock ran); the twins CSV purge regex hardened
(pre-v10.2 _zm-era rows survived every purge and re-duplicated 18 blade rows
per regen).

Both generators re-run for coherence; lints clean; 12 modules brace-balanced;
CSV 144 rows 0 dupes. Build pending peer-session coordination (one linker at
a time).

### Confirmed-but-deferred (notes, tracked)
Same-floor scatter repair ignores unassigned pad slots (rare, benign);
Cherry's perk-row icon cannot light (pre-existing, needs the perk-row mask
rewire); header/footer framing around the shrunken cards; comment/doc drift
in armory.html + generator headers; storefront still says [WIP].

## 2026-08-23 (v10.3) — the published-beta playtest pass: ten fixes

(session d537d3a9. User, after an hour on the published item: eight numbered
findings + the teleporter rework + the base-floor invisible barrier.)

1. **PaP vendor (Enfield / Knife / MR6)** — the report's MR6 detail cracked it:
   the breather vendor latched `tod_pap_owned` UNCONDITIONALLY, and only
   `reconcile_twin` acts on that latch — which only ever touches the CLASS
   PRIMARY. Paying with a sidearm in hand took the points and did nothing; the
   free-PaP drop always worked because `grab_pap` has a second stock-path lane.
   The vendor now has the same two lanes (class gun -> latch; anything else ->
   stock upgrade inline, refusing rather than eating points when a weapon can't
   upgrade). Enfield/Knife through the vendor were the v10.2 name-resolution
   bug — `weapon_or_zm` + the repair pass ship in this build.
2. **Upgrade menu -15%** — cards 213x320 -> 181x272, scaled about each card's
   centre; every overlay keys off the four rect constants so nothing else moved.
3. **No perk limit** — `level.perk_purchase_limit = 9` (all 9 sellable perks)
   set after `zm_usermap::main()` so it overrides stock's 4.
4. **White-square perk icons** — the mapping referenced stock `specialty_*`
   shader MATERIALS; the vanilla four resolve from base-game ffs, the DLC ones
   (widows/deadshot/staminup/mule) do not on a usermap -> white. Replaced with
   map 1's SHIPPED-PROVEN Ronan Cyberpunk icon set: GDT + PNGs vendored
   (identical path/content to map 1's deploy, so the gdtDB dedupes), 8 zone
   image lines, mapping rewritten to `i_acc_perk_*_base`. Cherry keeps its
   existing custom icon. Credit Ronan before publish.
5. **Knife speed dead on the combat knife** — the v10.2 `weapon_or_zm`
   reconcile fix (this build is the first published one to carry it).
6. **Perk scatter** — cadence was the round AFTER each Panzer (= every 5);
   minus one = every 4, decoupled from the Panzer (rounds 5, 9, 13...). Pads
   now carry a floor id and the shuffle repairs same-floor draws by swapping
   with a later machine (the breathers hold two pads each, which is exactly how
   "moved to the other slot on the same floor" kept happening).
7. **~30 Protectors on round 18** — two compounding bugs: the wave size
   `players*round/3` was unbounded (duo r18 = 12, quad = 24), and the debt was
   ACCUMULATED (`+=`) so uncleared waves stacked (12+15+18 uncleared = 30
   owed, drained 8-at-a-time for minutes). Wave now caps at TOD_RP_MAX_ALIVE
   (8) and a new wave REPLACES the remaining debt (max, not sum) — the same
   rule the Panzer debt cap already encoded.
8. **KBM can't pick cards** — `wait_for_choice` was D-pad only (a 2026-08-21
   controller directive that removed the stick reads wholesale because they
   flipped per-tick while strafing). A/D (strafe axis) restored EDGE-LATCHED,
   the class draft's proven pattern: a fresh push flips once, holding to dodge
   does not repeat-flip. KBM access outranks the residual single flip (user).
9. **Teleporters** — charge 2.2s -> 0.8s, cooldown 60s -> 30s, and TWO-WAY:
   the base arena now has FIVE porters — the shared arrival pad plus four UP
   pads (one per breather), each locked behind that breather's own lap door
   flag so teleporting up can never skip a door the climb still owes. Third
   hint state ("LINK OFFLINE") on locked pads; constant strings only.
10. **The base-floor invisible barrier** — found: `lap1 rail cap E`, the
    generic per-lap clip whose bottom is `b + PARA_H` = z56 (KNEE height) —
    and at lap 1, `b` is the ARENA FLOOR. An invisible 20-thin wall stood at
    x=416 across the whole east band, over and past the (visible since v9.34)
    anti-bypass slab, including under the NE landing. At ground level it
    protected nothing (hopping the first flight's rail lands on the arena
    floor), so lap 1's cap now starts at the wall top (288) over the wall and
    at the landing-rail top (248) beside the landing. +1 brush; bake gate
    BAKED 41.2s.

All lints clean; full geometry build.

## 2026-08-23 (v10.2) — PaP: v10.1's name "fix" was BACKWARDS and broke the knife; reverted, plus a self-repair pass

(session d537d3a9. User: "Pap is still not working with the knife. This is very
bad must be fixed.")

**v10.1 got the naming rule inverted and regressed the blades.** Recording the
rule properly so this cannot happen a third time:

> **The engine STRIPS a trailing `_zm` from a weapon asset name.** Zone lines
> name the ASSET (`t9_me_knife_american_k0_zm`); the weapons CSV and every
> `GetWeapon()` call use the BARE name.

Four independent shipped sources say so, and v10.1 checked none of them:
- map 1 zones ONLY `leviathan_zm` / `leviathan_up_zm` and its CSV row is
  `leviathan,leviathan_up` — and map 1 ships with a working Leviathan;
- same shape for `freezegun_zm` / `freezegun_upgraded_zm`;
- THIS map's hand-authored sidearm row is `t9_amp63,t9_amp63_rdw_up` against an
  asset `t9_amp63_rdw_up_zm` — note `_rdw` is KEPT, so it is that one suffix
  and not a general "strip decorations" rule;
- `_tod_classes::register_guns` has carried a comment saying exactly this the
  whole time ("asset ids may carry a trailing _zm the engine strips ... runtime
  names are bare").
The live proof was in front of us too: the slasher has always had a working
blade while the script asked `GetWeapon` for `<stem>_k0` against an asset named
`<stem>_k0_zm`. If the bare name did not resolve, the slasher would have
spawned with no primary at all.

Reverted: `set_tails` and the per-gun tails are gone, `variant_name()` returns
the bare name again, and the generator strips a trailing `_zm` when it writes
the CSV. The weapons table is byte-identical to its pre-v10.1 state.
`variant_name()` itself STAYS — one assembler is still right, it was the tails
fed into it that were wrong.

**What v10.1 actually got right and what it did not.** The generator now
deriving CSV names from `forms[].name()` instead of hardcoding them is kept
(with the `_zm` strip) — that removes a real drift risk. But **the Enfield's
original failure is NOT explained by naming, and is still not root-caused.**
With the correct rule, its row `t5_enfield_r0m0,t5_enfield_up_r0m0` was always
right. v10.1 claimed a fix it had not proven; this entry withdraws that claim.

**THE SELF-REPAIR PASS** (`_tod_classes::repair_weapon_table`) is the answer to
being unable to root-cause it before a beta. Stock resolves PaP purely through
`level.zombie_weapons[base].upgrade`, and when a row's `upgrade_name` does not
resolve stock stores **weaponNone** there — which, being a defined value, makes
`can_upgrade_weapon()` answer TRUE. The machine then takes the points and hands
back nothing, silently. After the table is built we walk it, and for any row
belonging to one of OUR class guns whose upgrade is missing we re-point it at
the linked weapon via `weapon_or_zm()` (bare name first, `_zm` fallback). Rows
that are already correct are left untouched.

**This is correct under BOTH hypotheses**, which is the point: if the bare name
resolves, the table was already right and the pass is a no-op; if it does not,
the pass repairs exactly the rows that would have failed. `weapon_or_zm()` gives
the GSC side the same tolerance.

`tools/lint_tod_weapons.js` header rewritten around the correct rule and made
`_zm`-insensitive. Build 94.37 MB @ 4:18:01 PM, lints clean.

⚠️ **The beta uploaded at 15:46 was built at 15:42 and CONTAINS the v10.1
regression** — its knife is broken. Re-upload from this build.

## 2026-08-23 (v10.1) — PACK-A-PUNCH FIX (Enfield + all three blades) and co-op scaling

(session d537d3a9, beta prep. User: "why couldnt i pap my enfield", "Should get
harder more players", "Door cost should scale with amount of zombies spawning".)

### The PaP bug — bigger than one gun

**The Enfield and ALL THREE BLADES could not be Pack-a-Punched, and KNIFE SPEED
had never moved a blade on any of them.** Neither failed loudly: the map built,
linked and booted, PaP just refused, and `reconcile_twin` took its "variant not
linked" early-out in silence.

THREE places spell a variant asset name, and two of them were wrong:

| | source | was |
|---|---|---|
| 1 | `gen_tod_twins.js` `forms[].name()` | correct — writes the GDT block + zone line |
| 2 | `gen_tod_twins.js` CSV row | **hardcoded** `stem + "_up" + suffix` |
| 3 | `_tod_classes` / `_tod_upgrades` | **hand-concatenated** `stem + up_suffix + suffix` |

Some ports tail their assets with **`_zm` AFTER the ladder suffix**, and the
tail differs between a gun's base and PaP forms — the Enfield is
`t5_enfield_r0m0` / `t5_enfield_up_r0m0_zm` (base bare, PaP tailed) while the
blades are `<stem>_k0_zm` / `<stem>_up_k0_zm` (**both** tailed). (1) knew;
(2) and (3) did not. So the weapons table advertised an `upgrade_name` that
existed nowhere (stock PaP refuses), and for the blades even the BASE name was
wrong, so `GetWeapon` returned `weaponNone` and the ladder never walked.

Fixes, all at the source rather than per-gun:
- **Generator**: CSV names now come from the same `form.name()` that writes the
  zone line. The three can no longer disagree.
- **GSC**: `_tod_classes::variant_name( g, is_up, suffix )` is now the ONLY
  place a name is assembled, fed by per-gun `set_tails()` (Enfield `"" / "_zm"`;
  the three blades `"_zm" / "_zm"`). Both hand-concatenation sites in
  `_tod_upgrades` route through it.
- **Two new gates, because this class of bug is invisible at runtime:**
  the generator now cross-checks every CSV name against the assets it emitted
  and THROWS; and `tools/lint_tod_weapons.js` parses `register_gun` +
  `set_tails` out of the GSC, reproduces `variant_name` exactly, and verifies
  all 170 names the script can ever request are linked. **Negative-tested** —
  removing one `set_tails` line makes it fail with the exact 12 Enfield names.
  Run it before every release.

### Co-op scaling

The audit found difficulty scaled (boss HP 1.0/1.7/2.3/2.6, wave sizes by player
count, luck normalised) but the HORDE and the ECONOMY did not.

- **Horde health** `+15%` per extra player on top of the 1.25 base — solo 1.25 /
  duo 1.40 / trio 1.55 / quad 1.70. Bosses exempt (they carry `coop_hp_mult`;
  stacking both would double-dip). Costs no AI slots.
- **`zombie_ai_limit`** 24 solo, +2 per extra player, capped 30.
  **`zombie_actor_limit` (31) is untouched, and that is the whole safety
  argument**: stock's spawn loop gates on BOTH, ai_limit counting only its own
  zombies and actor_limit counting EVERY actor including our directly-spawned
  bosses. Lifting ai_limit only lets zombies claim more of a budget that is
  still enforced at 31; lifting actor_limit is the one that would earn the
  user's crash warning.
- **Door prices scale with the zombie count**, exactly as asked: the multiplier
  is `zombies_at_N_players / zombies_at_1` from stock's own
  `get_zombie_count_for_round`, so it tracks stock's curve instead of a table
  we would have to maintain. Sampled at a FIXED reference round (10) because the
  ratio steepens with the round and prices that inflated over time would fight
  the +100/lap ladder. Gives **solo x1.00 / duo x1.27 / trio x1.82 / quad
  x2.36** — the 186,975-point ladder becomes ~441k for a quad, ~110k a head
  against solo's 187k. Solo is untouched by construction. The price is a
  FUNCTION, not a number baked at spawn, so the hint and the charge can never
  disagree when someone joins or drops; a watcher re-writes the hint only when
  the visible number actually changes.

Full geometry build (cod2map + navmesh + LED bake + linker): **94.37 MB @
3:42:10 PM**, zero unexpected linker errors, all three lints clean.

## 2026-08-23 (v10) — THE LAST MILE: the ending is a 6400-unit gauntlet timed to the closing song

(session d537d3a9. User: "Last song is you see big girl wav ... the music starts
and game ends when songs ends and you win ... the road to the pyramid needs to
be long ... players get to the top and players have around 3:40 minutes to get
to the building ... they get ambushed in all directions max aggressivness on
spawns and all types of enemies. Remember there is a limit on enemies so we dont
want the game to crash here.")

The ending was: buy the uplink at the hall dais, hold out 90s, then gather every
survivor on the extraction pad and hold USE. It is now: buy extraction at the
TOP OF THE STAIR, and run 6400 units of open road to the citadel while the song
plays. Survive to the last chord and you have won.

**GEOMETRY (`gen_tower_map.js`, full build + LED bake).**
- `CW_LEN` **640 -> 6400**, `CW_HALF` **112 -> 288** (224 wide -> 576). The
  width is not cosmetic: a 224-wide bridge can only be attacked from ahead and
  behind, which is the exact opposite of "ambushed in all directions".
- `SKY_IN` is now **derived** (`max(2900, HN + 384)` = 8800), not a literal.
  The hall's outer face moved from y=2656 to y=8416, and a future `CW_LEN`
  edit must never be able to leave the citadel outside the skybox — that would
  be a hole in the world, not a cosmetic bug.
- Portal frames and causeway risers both **scale with the length** (one per 800
  units: 7 of each). Three frames spread over 6400 would have read as nothing.
- **The road had NO risers before**, so anything on it had to walk in from
  either end — a queue, not an ambush. It now carries risers on ALTERNATING
  FLANKS (x = +/-180) the whole way.
- Cost: **+12 world brushes, +7 entities** (3178 -> 3190 / 482 -> 489).
  **LED bake gate: BAKED, 39.8s.** Ran before any script work, because the
  atlas ceiling (KB §1) is content-specific and this is now the largest lit
  surface on the map.

**THE ENEMY CAP — the thing the user warned about.** No limit was raised.
Stock sets `zombie_ai_limit` 24 / `zombie_actor_limit` 31 and gates its own
spawn queue on both, but **our three bosses are direct `SpawnActor` calls and
are invisible to that gate** — 24 zombies plus the per-type roofs (1 Panzer + 8
Protectors + 3 Reavers) is 36 actors, well past stock's own 31, with nothing to
stop it. So aggression is bought two ways that cost no actors:
1. **RATE** — `tod_spawn_delay` floors at 0.1s during the run, so the 24 slots
   refill the instant one empties. Saturation, not a bigger pool.
2. **VARIETY + DIRECTION** — `finale_pressure_loop` cycles all three boss
   types (round-robin, so no one kind fills the budget) under a NEW combined
   `TOD_FINALE_BOSS_ROOF = 4` across all types, deliberately far below the sum
   of their individual roofs. The road's risers supply the directions.
The Reaver's live count reaches `_tod_bosses` through a **level field**
(`level.tod_reaver_alive_n`), not an import: `_tod_reaver` imports
`_tod_bosses`, so importing back would be the cycle the KB forbids.

**THE SONG IS THE CLOCK.** `tod_music_finale` ("You See Big Girl", Hiroyuki
Sawano / Gemie — credit before publish), converted to the bank contract and
loudness-matched to the rest of the set at **-7.7 LUFS**.
- **`TOD_FINALE_SONG_SECS = 191`, and the 191 is arithmetic, not taste:**
  191 run + `TOD_FINALE_DEPART_SECS` 6 = **197**, against a 197.395s wav. The
  win screen lands with ~0.4s of track left — on the last chord.
- **The first cut used 197 and was wrong.** The alias is LOOPING (it must be —
  a non-looping streamed one-shot is engine-unstoppable, the map-1 music saga),
  so the 6s departure would have played over the song's SECOND INTRO. Caught by
  doing the arithmetic before the live test, not after.
- `finale_track_start` plays this track instead of the boss track, and the
  existing finale latch means a Panzer spawning mid-run cannot steal the
  channel. (v9.46's "boss music always overrides" governs the BAND tracks; the
  finale outranks everything.)
- **Upgrade events are suppressed for the whole run** (`level.tod_upgrades_
  suppressed`, honoured in `event_scheduler`). A freeze stops the world but
  NOT a music stream, so every card pick would slide the ending out of sync with
  the track. They are SKIPPED, not deferred — `last` still advances, so nothing
  queues up to fire in a burst.

**THE UPLINK MOVED TO THE TERRACE** (`uplink_org()`, emitted pre-mirrored as
always). It starts the run, so it belongs where players arrive, not at the far
end of the thing they are about to run. Placed west of the causeway mouth so it
never blocks the road. The old hall-dais point survives as `dais_org()` — the
dais brush still has a named centre and a future boss fight still has the hall's
focal point.

**THE EXTRACTION PAD IS A DESTINATION, NOT A CONTROL.** `exfil_use_loop`,
`all_survivors_on_pad`, `refuse_flash` and their two defines are **deleted,
not left dormant**: a live use-trigger that still called `depart()` would be a
second path into the end screen, racing the song timer, and two threads both
notifying `end_game` is the kind of double-fire that stays invisible until it
happens in front of the user. The pad keeps its light, its aura and its hint.

**Open for the live test.** 6400 units is ~26s of unopposed sprint out of a
191s run, so the shape is a dangerous crossing followed by a siege inside the
citadel — not 3 minutes of walking. If the crossing wants to be the whole song,
`CW_LEN` is the one knob, and it must be followed by a bake-gate run.

## 2026-08-23 (v9.47) — the floor 40 band: "Cyber Eclipse"

(session d537d3a9. User: "next level will be cyber eclipse wav".)

One `add_music_band( 40, "tod_music_eclipse" )` row, one alias cloned from
`tod_music_relay`, one wav — exactly the extension shape v9.46 was built for,
with no other code touched. Bands are now **1-19** ambient / **20-29** city /
**30-39** relay / **40-50** eclipse ("Cyber Eclipse", bykenneth — credit with
the rest).

That also resolves the band count: the user's three breather bands are **20 /
30 / 40**, and the base ambient carries everything below 20. The floor 10
breather has no row **by design**, not as a gap — the TODO left in
`register_music_bands()` is replaced with that statement so nobody 'fixes' it
later.

Loudness: source was 44.1 kHz at **-11.0 LUFS** peaking at 0 dB. Landed at
**-9.1 LUFS** with +5 dB and the limiter, giving a set spread of 1.3 dB
(ambient -8.0 / city -8.9 / relay -7.8 / eclipse -9.1). **Stopped at +5 dB on
purpose**: +4.3 dB produced -9.4 and +5.0 produced -9.1, so the limiter was
already absorbing most of each extra decibel. Past that point more gain buys
squash and pumping, not loudness — a track that will not come up is telling you
to stop, and 0.2 dB from the city track is well inside inaudible.

## 2026-08-23 (v9.46) — MUSIC BANDS: the background track changes as you climb past the breathers

(session d537d3a9. User: "at each 10 level there is a breather station. On each
of these levels we will change the background track. We have one currently for
first 10 levels ... Boss music will always override this. Level 20 will be
futuristic city wav and level 30 will be psychronic relay".)

**The table is the whole feature.** `_tod_atmosphere::register_music_bands()`
holds one `add_music_band( <first floor>, "<alias>" )` row per band;
`band_alias()` scans them high-to-low and returns the first whose floor the
party has reached, falling back to the base `tod_ambient_music`. **A band with
no track simply has no row** — the band below it keeps playing. That is why the
two unsupplied breathers (10 and 40) cost nothing: no silence, no alias that
does not exist, and adding them later is one line + one alias row + one wav.

Live bands: **1-19** ambient ("Password Infinity", Evgeny Bardyuzha) · **20-29**
`tod_music_city` ("Cyberpunk Futuristic City", lnplusmusic) · **30-50**
`tod_music_relay` ("Cyber Relay", Psychronic). Credit all three plus the boss
track before publish.

- **The mark is LATCHED.** `music_band_watch()` polls every 2s for the highest
  floor any player stands on and never lets it fall. Walking back down the
  stairs must not rewind the music: a stream cannot seek, so every re-cue
  restarts the track from zero, and an un-latched version would re-cue on every
  crossing while players milled around a breather. No laststand filter, for the
  same reason — a player who went down on floor 31 did reach floor 31.
- **Boss always wins**, as asked. While a Panzer holds the channel (or the
  finale has latched it) the band still UPDATES but never swaps the stream.
  `boss_track_end()` now resumes into `band_alias()` instead of the
  hardcoded `"tod_ambient_music"` — the party may have climbed one or three
  breathers while he was alive, and before this it would have dropped them back
  to the opening track.
- Floor math is local (`TOD_MUSIC_LAP_RISE 384`, mirroring
  `gen_tower_map.js`). `_tod_gauge::floor_of` was NOT reused: it returns a
  gauge CELL (2 floors per cell, 1..26), not a floor, so there is nothing there
  to share — and importing the HUD to get one integer would couple the music
  channel to it.

**Audio prep — loudness, not alias volume.** The bands HARD-SWAP the stream, so
a track mastered quieter than its neighbour reads as a bug rather than a
choice. Both sources were measured and gain-matched to the base track rather
than trusted: ambient **-8.0 LUFS**, city **-8.9**, relay **-7.8** (within
~1 dB; alias volume stays 95 for all three, inside the 80-96 audible band).
First attempt used `loudnorm ... linear=true`, which refused nearly all the
gain because the city master already peaked at **+1.16 dBTP** — it landed at
-11.1 LUFS, still 3 dB under. Redone as explicit `volume=<target minus
measured>dB` + `alimiter`. Both converted to the bank contract (48 kHz,
16-bit, stereo — 44.1k is rejected outright with "wav is not 48k sample rate").

Wavs are named for their CONTENT (`tod_music_city` / `tod_music_relay`), not
their floor, so re-ordering the bands is a one-line table edit and never a file
rename. Aliases cloned from `tod_ambient_music` with only Name and FileSpec
changed (STREAMED / LOOPING / BUS_MUSIC / snp_never_duck).

Verify note: a streamed alias does NOT enter the fastfile, so the `.ff` stayed
byte-identical at 94.16 MB and that is not evidence of a no-op. Confirmed the
right way — both aliases are present in the built streamed bank
(`zone/snd/all/zm_tower_of_doom.all.sabs`) next to the existing two.
`sound_assets/tod/music/README.md` carries the band table and the loudness
recipe.

## 2026-08-23 (v9.45) — AR pass: GIANT SLAYER + BACK ARMOR added, RECOIL to 2 levels, IMPACT ROUNDS to 10, HEADSHOT and KILL RELOAD nerfed

(session d537d3a9. User, in one run of asks: "We need upgrade updates for ARs
... more damage to boss and elites, 3% per level, level 5 ... impact rounds can
be 10 levels but each level needs to be nerfed, smaller steps per level ... kill
reload is B or A tier ... recoil should be two levels only, 8% and 16% ...
headshot needs to be nerfed to 3%", then: "for AR and LMG we need a new upgrade
where getting hit from behind does 10% less damage and can go 3 levels".)

Six changes to the assault pool, two of them new domains.

**GIANT SLAYER (id 35, assault, A, max 5, +3%/Lv)** — bonus damage against
bosses and elites only. Rides in the SAME additive `mult` sum as DAMAGE and
HEADSHOT (so Lv5 is +15% of base, not +15% of an already-multiplied total) and
pays nothing on the horde, which is what keeps it A rather than S. The
boss/elite test is the map-wide triad `is_boss` / `acc_is_boss` /
`acc_is_mini_boss` — the Panzer, the Rogue Protector and the Reaver all set it
on their spawn frame, so all three are covered and a future elite that sets the
triad is covered for free.
- Both boss-damage lanes carry it: `upgrade_damage_cb` (the actor chain — what
  fires for the Panzer and the Reaver; his `actor_damage_func` wrap runs after
  us and re-scales by hit-location RATIOS, so a bonus applied here survives it)
  and `_tod_bosses::rp_damage_feed` (the Rogue Protector's aiOverrideDamage
  fallback).
- It goes through a FUNCTION, `tod_upgrades::boss_damage_bonus( attacker,
  victim )`, not a hand-copied literal. That is deliberate: rp_damage_feed
  cannot see a file-local `#define`, and both literals already in that lane are
  the reason it carries a warning block — the headshot copy was stale for a day
  and paid 2.5x. New constant, new call.
- Also added `tod_upgrades::is_boss_or_elite( ent )` — the map spelled the
  triad inline in nine places; new call sites use this.

**BACK ARMOR (id 36, assault + heavy, A, max 3, -10%/Lv)** — the two SLOW
classes (assault 0.9, heavy 0.8 move speed) finally get the defensive card the
two fast ones already had. SPRINT ARMOR pays you for outrunning the horde; this
pays the classes that cannot, for the hits they take because they cannot turn
round fast enough.
- "Behind" is a BEARING, not a state: the attacker must sit in a 140-degree rear
  arc (`TOD_BACK_ARC_DOT -0.34`) around the player's VIEW forward, yaw only.
  Yaw-only is exact where flattening a full 3D forward degenerates to nothing
  when you look straight down, and 2D is load-bearing on a spiral — a Panzer two
  flights below you is not behind you, he is under you. 140 rather than 90
  because the horde surrounds you on a landing and a literal cone would never
  pay; still strictly narrower than a hemisphere, so a shoulder hit is not
  "behind".
- Scope `class` (survives a tier promotion) with DR and SPRINT ARMOR — the user's
  standing rule is that damage resistance is the family that persists.
- Applied in BOTH player-damage lanes, multiplying AFTER DMG REDUCTION exactly
  like SPRINT ARMOR, so the three stack multiplicatively rather than summing
  into one flat cut (DR 10 + SPRINT ARMOR 5 + BACK ARMOR 3, all maxed, from
  behind, while sprinting = x0.2625 — deep, but it needs three maxed cards and a
  specific situation).
- `apply_player_mitigations` (the Panzer-melee short-circuit) grew a second
  parameter for the attacker, and `mechz_spiki.gsc` passes its `eattacker`
  through the `level.tod_player_mitigations_fn` pointer. The param is optional
  by design — GSC pads a missing argument with undefined and `back_armor_mult`
  returns 1.0 for an undefined attacker, so the older call shape degrades to
  pre-v9.45 behaviour instead of erroring. (T7 resolves by name+arity: MORE args
  than the callee declares is a boot-time Unresolved external, so the callee's
  2-param signature is now load-bearing. `lint_tod_arity.js` clean.)

**RECOIL: 3 levels -> 2, -10/-20/-30% -> -8/-16%.** This one is a GENERATOR
fact, not just a cap — `AXIS.r.levels` decides which weapon assets exist, so
`RECOIL_STEP` -> `[1, 0.92, 0.84]` and `levels: 2` moved together with
`add_domain`'s max. Regen verified: zero `_r3` forms remain, 24 `_r2`
forms, each assault gun at 24 assets (3 r x 4 m x 2 forms), AK-47
`adsGunKickPitchMax` 11.5 / 10.58 / 9.66 = exactly x0.92 / x0.84.
**Registration ledger 194 -> 170 generated, 170 + 22 = 192 (guard 220)** — the
change BUYS 24 assets back. A SUPER/ULTIMATE roll on a 2-level domain is already
handled (levels clamp to `domain_max - cur`, the PENETRATION precedent).

**IMPACT ROUNDS: 3 levels at 10% -> 10 levels at 3%.** Same 30% ceiling, ten
times the climb, and each individual level is now a third of the proc rate it
used to buy. `TOD_IMPACT_PCT_PER_LV` 10 -> 3. The level field is 4 bits
(0..15), so 10 needed no clientfield change.

**HEADSHOT: +4%/Lv -> +3%/Lv** (+40% -> +30% at the 10-level cap).
`TOD_UPG_HS_PER_LVL` 0.04 -> 0.03 **and the hand-copied 0.04 in
`rp_damage_feed` in the same commit** — that copy has gone stale once before
(0.10 there against 0.04 here, 2026-08-22 to 2026-08-23) and paid 2.5x on the
Rogue Protector for a day.

**KILL RELOAD: tier S -> B.** The user offered "B or A"; B is right. The v9.43
rework left it a pure ammo-economy card — a magazine topped back up out of your
OWN reserve every 100th/75th/50th kill, which mints nothing and (by that
build's arithmetic) never outruns consumption at any level or round number.
That is precisely the band SCAVENGER, BULLET FEED and RUN AND GUN sit in. It
held S only because it was S back when it *was* game-defining. Effect: draw
weight 20 -> 100 (offered 5x as often) and its SUPER/ULTIMATE slice stops being
halved (`tier_rarity_factor` 0.50 -> 1.0).

Wiring for the two new domains: `domain_id` 35/36, Lua `DOMAIN` +
`DETAIL` rows, and the id field is 6 bits (1..63) so no clientfield change.
**`CARD_SLUG` and `PAUSE_PLATE_MAX` are deliberately NOT set yet** — the art
is not baked, and `RegisterImage` of a missing image is undefined behavior. The
two render as composite-text cards and text pause rows until the drop lands;
flip the slug and the plate max in the same commit as the images.

**ART LANDED THE SAME HOUR** (`files (38).zip`, 17 files, all at the exact
names and sizes). Both contact sheets proofread clean before install. Re-bakes
(`headshot` +3/+6/+9% with a new "3% PER LEVEL" light line, `recoil`
-8/-16/-16% on **two** pips with MAX on SUPER and ULTIMATE per the PENETRATION
precedent, `impact_rounds` 3/6/9%) reuse their existing GDT blocks and zone
lines — PNG replacement only. New art (`giant_slayer`, `back_armor`, plates
r35/r36) got 8 `image.gdf` blocks + 8 zone lines, `CARD_SLUG[35]/[36]` and
`PAUSE_PLATE_MAX = 36`. So the two new domains ship as full art rows, not text.
Prompts and the proofreading checklist: `docs/31_ar_upgrade_art_prompts.md`.

Build note: the art-install build threw **6 UNEXPECTED linker errors** — three
`skye_ports` wavs (`t9_magnum_shot2`, `t9_ak47_start`, `t9_mp5_mvmnt`),
each paired with "Object reference not set to an instance of an object". All
three files are present and valid (RIFF/WAVE, 48 kHz, 16-bit), no game or second
linker was running, and nothing in this change touches sound. A plain rebuild
came back **clean, at the byte-identical 94.16 MB** — so it was a null-ref in
the linker's sound stage, not a dropped asset. If it recurs: rebuild once and
compare the .ff size before investigating the wav. Do NOT ship the .ff from a
build that reported it — a half-converted sound bank is the silent 0xC0000005 /
black-screen-hang failure mode.

**Also in this build — zombie sprint ramp: full sprint at round 12 -> 15**
(user: "lets change sprint speed to round 15", after correctly pointing out the
live value was 12, not the 10 `CLAUDE.md` claimed — that line is fixed too).
History on `TOD_ZSPEED_FULL_ROUND` is now 7 -> 10 -> 12 -> 15. **15 is the end
of this lever**: the ramp divides the 0.8-to-1.0 climb across FULL_ROUND-1
steps, so pushing it further makes the per-round increment small enough that
rounds 1-8 read as one flat speed. If it still runs fast, the next lever is
`TOD_ZSPEED_START_RATE` (floor ~0.7 — 0.5 read as "practically frozen" in the
2026-08-18 live test) or `TOD_ZSPEED_STEP`, not this number. The
`rate_for_round` comment that had rotted through two retunes was rewritten
against the constants rather than their values.

Also corrected in `docs/armory.html` while the tables were open: the ASSAULT
block listed **Penetration** (heavy-only since 2026-08-23, the AK traded its
p-axis for r+m) and the HEAVY block listed **Sprint Armor** (skirmisher +
slasher only). Both rows were false; the Kill Reload row still carried the
superseded v9.41 "25/50/75% per kill" wording.

## 2026-08-23 (v9.44) — SMG class update: FIRE RATE = MAC-10 only, HANDLING = every SMG, MAG SIZE off the class

(session f2e3ffc8. User: "SMG class updates — 1. Fire rate increase is mac10
only. 2. Handling is for all smgs. 3. Magsize we can remove from class.")

All three are TWIN-AXIS facts (FIRE RATE = `f`, HANDLING = `h`, MAG SIZE =
`m` ladders in `gen_tod_twins.js`), so the change is the generator + the
matching `register_gun` axes + the domain gates — three places that must
agree on axis letters AND order:
- `gen_tod_twins.js` LADDER.skirmisher: MAC-10 `['f']` → `['f','h']`, MP5
  `['f','h']` → `['h']`, MP7 `['m']` → `['h']`. Regen diff = exactly 48 zone
  lines out / 48 in, all three SMG stems, nothing else touched; weapons CSV
  rows changed only for those stems; 194 blocks before and after; every
  `altWeapon` blank (194/194). **Ledger unchanged: 194 + 22 = 216 (guard
  220)** — MAC-10 8→32, MP5 32→8, MP7 8→8.
- `_tod_classes.gsc` `register_gun`: MAC-10 `axes2(firerate f, handling h)`,
  MP5 `axes1(handling h)`, MP7 `axes1(handling h)`.
- `_tod_upgrades.gsc`: FIRE RATE `set_guns [t9_mac10]`; HANDLING keeps
  class_keys skirmisher and its `set_guns` list is DELETED (all three SMGs
  carry h, no gun outside the class does — the class gate is exact, RECOIL
  precedent); MAG SIZE class_keys → assault only and its `set_guns` list is
  DELETED (only the three assault guns carry m now).
- Spot-checked the emitted GDT (the `scaled === 0` guard can't catch a gun
  missing the handling keys): MP7 h0→h3 reload 1.8→1.17 s, ADS 0.3→0.195,
  raise 0.5→0.325; MAC-10 the same, and its f-ladder alone moves fireTime
  0.054→0.041; the MP5 has zero `f` forms left.
- docs/25 §9.1 rows updated; armory per-class/ledger tables are session 2a's
  (numbers handed over). Card art unaffected (no gun names on those cards).
- Also in this build (session 2a, user): door step 200 → **100**/lap
  (`DOOR_COST_STEP`), prices 1125 / 1225 / … cap 6000, roof 7500, power 750.

## 2026-08-23 (v9.43) — KILL RELOAD reworked: a magazine REFILL every 100th/75th/50th kill

(session 7f62697c. User, rejecting the v9.41 reserve fix as insufficient: "Its
still crazy even if it comes out of reserve ... You basically never have to
reload. We really need to think through this and not just apply a lazy fix.")

v9.41 made the refill come out of the RESERVE, which fixed the ammo economy —
the card stopped minting ammo. It did NOT fix what the user was actually
describing, because the problem was never the economy. It was that **the card
deleted reloading**, and no percentage could have saved it.

**Why the old ladder was fake.** A per-kill refund removes reloading whenever
refund-per-kill >= rounds-SPENT-per-kill. Measured on the Krig (33-round mag,
313 damage) at round 20: a headshot kill costs 4 rounds, while **Lv1 alone
handed back 8**. The refund only lost that race once a single kill cost more
than 75% of a magazine — round ~29 on body shots, ~40+ on headshots, later
still with DAMAGE stacked or PaP. So all three levels spelled one effect, "you
never reload", and 25/50/75% was decoration on a binary.

- **The ladder is RARITY now, not size.** A proc tops the magazine back up to
  FULL (`want = cap - clip`, pulled from reserve and clamped to what the reserve
  holds — so at 3/4 full you get a quarter mag, not a whole one); the LEVEL buys
  FREQUENCY: **100 / 75 / 50 kills** (`TOD_KILLRELOAD_KILLS_LV1..LV3`, read
  through `killreload_kills_needed()`). Mechanic chosen by the user from three
  candidate reworks (the others were banked spendable charges, and a rename to
  COMBAT RELOAD = faster reloads and no free magazines at all).
- Counter is `player.tod_killreload_kills`, mirroring SCAVENGER's idiom, and it
  **resets in `reset_gun_state()`** — KILL RELOAD is a gun-scoped domain, so a
  TIER card must not carry progress toward a free magazine across a promotion.
- **Scope untouched: all three assault guns.** The temptation on a card this
  strong is to re-bind it to the Krig, which would silently revert the user's
  2026-08-23 instruction #4. The fix is the mechanic, never the scope.
- **THE FIRST CUT OF THIS REWORK SHIPPED 10 / 7 / 5 AND WAS STILL BROKEN** (user:
  "yeah this is still broken"). Recorded because the reasoning is not obvious: a
  refill every 5 kills still outran consumption early, since a kill can cost as
  little as 1 round in the opening rounds — 5 kills spent 5 and handed back up
  to 33. It only began losing that race around round ~16 (body) / ~26
  (headshot), so it still deleted reloading for the entire early game. A smaller
  hole than the percentage version, but the same hole. **100 / 75 / 50 (user:
  "lets make it unrealistic like 100 / 75 / 50") has no hole, and that is
  arithmetic rather than taste:** take the cheapest kill anyone can construct, a
  one-round headshot, and Lv3 still spends 50 rounds to earn at most one
  33-round refill — net -17 per cycle, less whenever the proc lands on a
  part-full mag. Every level, every round number, the magazine drains. Raising
  these constants is safe; lowering them re-opens the hole.
- **Tier flagged, not changed:** at 50-100 kills per refill this is no longer a
  `TOD_TIER_S` "wins the run on its own" card, and leaving it in the S pool
  crowds out cards that are. Recommend dropping it to `TOD_TIER_B` — left alone
  pending the user's call, since tier feeds the LUCK-weighted roll odds.
- **Card art is now WRONG and needs a re-bake** — the baked plates read
  "+25/50/75% MAG BACK / ON EVERY KILL". Three files:
  `i_tod_card_kill_reload_{regular,super,ultimate}.png`. Filenames unchanged, so
  it is a pure PNG overwrite (no GDT block, no zone line, no Lua change). Prompt
  handed to the user. `tod_upgrade.lua` DOMAIN[27] + the pause-panel DETAIL[27]
  row carry the old numbers too — handed to the session that owns that file.
- No sound cue on the proc yet: no existing `tod_*` alias fits "a fresh
  magazine slams in", and inventing one needs a wav + alias row + bank rebuild.
  The ammo counter jumping to full is the only feedback today.

## 2026-08-23 (v9.42) — TIER card chance 10% → 20%

(session f2e3ffc8; -GscOnly build. User: "Once your class gun is
Pack-a-Punched, every card deal has a 10% chance to carry a TIER card; Increase
this to 20%. 10% was too low.")

- `_tod_upgrades.gsc` `TOD_TIER_CARD_PCT` 10 → 20. One define; every deal
  lane reads it through `tier_card_pct()` (round events, station buys, the
  maxed-player tier-only deal), dev builds still 100. Eligibility rules
  unchanged (class gun PaP'd, below the top tier). CLAUDE.md brief updated;
  armory.html's three "10%" mentions handed to session 2a (their file).

## 2026-08-23 (v9.41) — KILL RELOAD pulls from reserve (no more minted ammo); doors +200/lap

(session f2e3ffc8; FULL build. User: "1. Kills refill 25% of mag is crazy. We
need to really think about this. You basically never run out of ammo. 2. Doors
cost too much. Lets make it so they increase by 200 every level.")

- **KILL RELOAD — the mechanic, not the scope.** The kill handler did
  `SetWeaponAmmoClip(clip + 25%·Lv of the mag)` and never touched the reserve:
  it MINTED ammo — 75% of a magazine per kill at Lv3, no cooldown, on an
  endless-round map. Since v9.38 it also rolls on all three assault guns (a
  user instruction the same day — KEPT) and compounds with MAG SIZE, so it
  became reachable from tier 1. Now the rounds come OUT OF THE RESERVE
  (`SetWeaponAmmoClip` + `SetWeaponAmmoStock`): a kill is a free, instant
  partial reload — 25/50/75% of the mag per level, clamped to the mag's room
  AND to what the reserve holds. Total ammo is exactly what you carried; an
  empty reserve means nothing happens; Max Ammo and the PaP refill matter
  again. SCAVENGER remains the ONE ammo-creating domain. Percentages unchanged
  → the baked "+25/50/75% MAG BACK · ON EVERY KILL" card art stays accurate;
  the in-game desc now reads "kills pull 25/50/75% of your mag up from
  reserve" (GSC `add_domain`; the Lua [27] desc + DETAIL entry and the armory
  rows are session 2a's files — wording handed over).
- **Doors +200/lap** (`gen_tower_map.js` `DOOR_COST_STEP` 375→200; lap-1 door
  1125 and the 6000 cap unchanged). Laps 1–25 cost 1125…5925; laps 26–50 sit
  at the cap (it used to bind at lap 14). Climb total to the roof door
  238,125 (was 265,875) + the 7500 roof door. For the user: the cap is now
  the dominant cost — 150k of the 238k is the top 25 doors — `DOOR_COST_CAP`
  is the next knob if the climb still feels expensive.
- **Door prices ride in the generated `_tod_door_data.gsc`** (`cost` field,
  same table that writes the .map's `zombie_cost`) and `_tod_doors.gsc` now
  prefers it over the map entity (whose value is frozen into the BSP at
  cod2map time). From here a price change is a `-GscOnly` build. This one is
  FULL anyway so BSP and data agree.
- CLAUDE.md's stale door line (750 +250/lap cap 4000, roof 5000 — pre-×1.5)
  corrected to the live numbers.

## 2026-08-23 (v9.40) — the lunge, and the invisible wall by Quick Revive

(session bc1a80d8; shipped inside session b83a9c19's 12:47:05 full build. User,
mid-run: "There is an invisible wall at the corner near quick revive... ALso the
lunge animation was never removed. Im still lounging with teh combat knife. We
were able to remove from leviathan axe on the other map.")

Two live bugs, both previously "fixed" and neither actually fixed.

- **The lunge was the wrong FIELD, not the wrong value.** `MELEE_NO_LUNGE` in
  `tools/gen_tod_twins.js` zeroed `meleeLungeRange`. The attribute that actually
  drives the lunge-and-snap is **`meleeChargeRange`**, and it was still at the
  port's `100`. The user's own pointer is what found it: map 1's LIVE axe GDT
  carries `meleeChargeRange "0"`, while the pristine copy our generator reads
  carries `"100"` — so map 1's fix was made by hand, downstream, and never
  crossed into the generated pipeline. Both fields are now zeroed. Verified: 72
  melee range fields across the 3 blades x 12 forms, **NON-ZERO: 0**. Ledger
  194 generated + 22 fixed = 216, guard 220.
- **The invisible wall was a RACE, not a stray brush.** Stock
  `_zm_perks.gsc:1551-1559` spawns each perk machine's clip at
  `s_spawn_pos.origin` — the `.map` park position — and only *then* assigns
  `t_use.clip`. The scatter polls for vending triggers, which exist from frame
  0, so it could move a machine while `move_machine`'s `if (isdefined(t.clip))`
  was still false. The machine left; its collision stayed at the north wall,
  where all 8 park at `PERK_PARK_Y = 500` and where Quick Revive is pinned at
  `(-75, 500, 0)`. `capture_and_open()` now waits for every machine's `.clip`
  to exist before moving anything, bounded at 10s so a machine that genuinely
  has no collision can never hang the opening layout.
- **The first attempt at the wall fix was overbuilt and was thrown away.** It
  was a 61-line `clip_reconcile_watch()` that re-checked clip positions on a
  loop. The user: "Just initailize them somewhere else?? that sounds super
  simple than doing all ths weird stuff." Correct instinct, and the reconciler
  is gone. The park spot itself was deliberately NOT moved: those machines
  parking somewhere reachable is the module's documented graceful-degradation
  path ("if capture ever fails, they remain buyable there"), so parking them
  out of bounds converts a capture failure from "perks look wrong" into "no
  perks exist, and solo has no Quick Revive". Waiting on the precondition fixes
  the same race without spending that safety net.

**Build-hygiene note that outlived the build it came from.** v9.37a recorded
"10 unexpected linker errors instead of 9" as the tell for an incoherent tree.
That heuristic is now RETIRED and actively misleading: `-75` added
`gfx_teleport_tube_em_scroll_nocull` to `$WaivedLinkerErrors`, so 10 waived / 0
unexpected is the new clean baseline. **Watch the UNEXPECTED count, never the
waived count.**

## 2026-08-23 (v9.44) — pause panel art drop: wide header + a real empty pip

(session b83a9c19; needs a FULL build — one NEW image asset. User art drop
files (36).zip, requested in v9.39 below.)

- **`i_tod_pause_pip_empty` (24x24) — NEW.** A hollow unlit ring for an unspent
  level. v9.39 faked it by drawing the FILLED pip at alpha 0.22, which read as a
  ghost of a filled pip rather than an empty slot. GDT entry + `image,` zone
  line added; the panel now picks the asset per pip instead of dimming.
- **`i_tod_pause_hdr` RE-CUT 500x70 -> 1000x70.** Same asset name, so no zone
  change. The old plate rendered at 232x32 and looked undersized once the panel
  went two-column. Now 700x49 — aspect 14.286, held EXACTLY — and the first row
  moved y=168 -> y=176 to clear it. 14 rows still end at y=554, well clear of
  the signature strip at y=637.
- **`i_tod_card_class_assault` replaced** (new scoped-rifle art, same name and
  768x1152, already zoned). Cosmetic, drop-in, no code change.
- The drop also contained `cyber_city_pause_kit.zip` and
  `cyber_city_card_set.zip`. **Neither was installed:** all 34 row plates, the
  filled pip, and 102 of 103 card images hash byte-identical to what is already
  in the repo — they are a repackage, not a re-bake. `cosmetics_check.png` is a
  QA contact sheet, not an asset. Only the three files above were new.
- Verified every `i_tod_*` image referenced by both menus has png + GDT entry +
  zone line. The only names without repo assets are 9 `i_mtl_*`, which are stock
  BO3 images and correctly have none.

### Also — KILL RELOAD DETAIL rows re-synced to v9.43

The exact drift the v9.39 header comment warns about, caught by the session that
made the change rather than by a player reading a wrong number.

- v9.43 turned KILL RELOAD from a per-kill percentage into a FREQUENCY ladder,
  so the pause rows had to move with it: now "every 10th / 7th / 5th kill
  refills your mag from reserve", value = kills-per-proc via `({10,7,5})[l]`.
- **This is the one row whose number DESCENDS with level** — a higher level
  shows a smaller number.
- Wording checked against the code, not the hand-off note: `unique_on_kill` does
  `want = cap - clip` clamped to stock, so the proc **tops the mag up to full**
  and is capped by the reserve. "A free full magazine" would have oversold it at
  partial ammo.
- All 32 DETAIL rows were diffed against their authored text; id 27 was the only
  one that had moved.

## 2026-08-23 (v9.39) — pause menu tells you what every upgrade DOES

(session b83a9c19; GSC-only — two rawfile .lua edits, no geometry. User: "When
you pause the game you can see what upgrades you have. Sometimes players forget
or dont know exactly what each upgrade does. Lets revamp the menu to also
describe what each upgrade does. SHould be short but very precise on what it
each upgrade does and how it actiavtes.")

The YOUR UPGRADES panel listed a name plate and level pips and nothing else — a
player holding SCAVENGER Lv4 had no way to learn what it did, let alone what it
did *at Lv4*. Every owned row now carries two authored lines: **what it does at
your current level** (cyan) and **how it activates** (dim).

- **The numbers are LEVEL-AWARE, not the per-level rule.** SCAVENGER Lv4 reads
  "1 reserve round back per 4 kills", not "1 kill fewer / Lv". New `DETAIL`
  table + `CoD.TodDomainDesc( id, lvl )` accessor in `tod_upgrade.lua`, read by
  `AetheriumStartMenu.lua` the same way it already reads `CoD.TodDomainInfo` —
  same client Lua VM, no new channel, no new clientfield bits.
- **Every entry was read off the real apply hook, not the desc strings.** All 31
  live domains were audited against `_tod_upgrades.gsc` and friends, then
  adversarially re-verified. Eight came back corrected. The ones that mattered:
  **CLEAVE is not a "chance"** — its ladder passes 100% at Lv3 (a guaranteed
  extra target) and caps at 200% = +2, so the old wording was wrong above Lv3;
  **LEECH is blade-only in practice** (the slasher's primary is a blade at every
  tier); **PENETRATION is a tier, not a number**, and Lv0 = "small" is BELOW the
  roster default, so only Lv>=1 is ever printed.
- **Two columns, 7 rows each.** The old single-column comment claimed "at most 8
  domains" — stale by ~2x. The true ceiling is 14 (4 always-available + the
  skirmisher's largest reachable set + the CLASS TIER row), and the four
  signature images are `addElement`'d AFTER the panel so they PAINT OVER
  anything below y=637. Rows now end at y=546 with 14 shown; an overflow
  counter catches any future 15th domain instead of silently dropping it.
- **Pips now show the CAP too** — filled to your level, dim to `domain_max`, so
  "am I maxed?" is answerable at a glance.
- **No unproven LUI in the change.** This build has no text-measurement and no
  wrap API (verified repo-wide: zero uses of `setFontSize`/`setWrap`/
  `getTextWidth`), so line breaks are authored and the table carries hard
  character budgets (eff <= 40 with the value substituted, act <= 44). `setScale`
  is the only sizing lever and it is already proven in `tod_upgrade.lua`.
  `math.min` was dropped for a plain comparison — it would have been the only
  use in the repo.
- **Drift hazard, written into the file header:** these numbers are hardcoded
  client-side because the client cannot read GSC constants. Change a domain's
  per-level constant in GSC and the DETAIL entry must change in the SAME commit
  or the panel actively lies to the player. (Checked against the v9.38 assault
  rework landing in parallel — no per-level constants moved, all entries hold.)

### Also in v9.39 — Rogue Protector headshot overpay (found by the audit above)

The domain audit turned up a live damage bug in a file the pause menu never
touches, so it is fixed here rather than filed.

- **`rp_damage_feed` paid 2.5x on headshots.** `_tod_bosses.gsc` carried a
  literal `0.10` for the HEADSHOT domain under a `// = TOD_UPG_HS_PER_LVL`
  comment, but that constant became `0.04` in the 2026-08-22 nerf ("the krig's
  headshot was carrying the run"). The nerf missed this copy, so from
  2026-08-22 until today a headshot on the Rogue Protector paid **+10%/Lv
  instead of +4%/Lv — +100% vs +40% at Lv10** — on whichever lane fired. The
  actor chain (`upgrade_damage_cb`) used the constant correctly the whole time,
  so the two lanes disagreed. Now `0.04`.
- **Why the copy exists at all, and why it drifted:** a GSC `#define` is
  FILE-LOCAL and there is no project `.gsh` (only stock `shared.gsh` is
  `#insert`'d), so this lane cannot reference the constant symbolically. The
  three `// = TOD_UPG_*` comments asserted an equality nothing enforced. They
  now read `// copy of <NAME>`, record this miss as the precedent, and require
  the literals to move in the same commit as the `#define`. The two DAMAGE
  copies (`0.12`) were verified still equal.
- **Cite names, not line numbers.** The first version of that comment pointed
  at `_tod_upgrades.gsc:80/:84` and those numbers were stale before the edit was
  even finished — a parallel session had shifted the `#define` block. All line
  references stripped in favour of the `#define` names.
- Unrelated and NOT fixed, pending a trace: `mechz_spiki.gsc` claims the Panzer
  flame DoT bypasses the DR domain, but `_burnplayer.gsc:90` delivers each tick
  via `dodamage(..., "MOD_BURNED", ...)`, which enters the player-damage chain,
  and `boss_player_damage`'s DR hunk has no MOD gate. If DR does apply, the
  2026-08-23 flame halving rests on a false premise and the flame is
  double-discounted. Untouched until `MOD_BURNED` callback ordering is traced —
  the chain stops at the first callback returning != -1.

## 2026-08-23 (v9.38) — ASSAULT parity: recoil / mag size / impact / kill reload on every assault gun

(session 7f62697c; FULL build — regenerated weapon twins. User: "1. Recoil
upgrade should be for all assault not just enfield and krig. 2. Impact rounds
should be for all assault not just AK. 3. Mag size should be for all assault
guns not just krig. 4. Kill reload should be for all assault not just krig.")

Four assault upgrades were bound to ONE gun each. They are now CLASS-WIDE. Two
were free; two cost weapon assets, and paying for them forced one trade.

- **KILL RELOAD + IMPACT ROUNDS — un-bound, zero cost.** Both are pure script
  (`unique_on_kill` / `unique_on_hit` read the attacker's level and the damage
  weapon — neither ever looked at the gun stem), so the fix is two deleted
  `set_guns` lines in `_tod_upgrades::register_domains`; `class_keys
  array( "assault" )` is now the only gate. Both stay `scope "gun"`, so a TIER
  card still resets them like every other gun upgrade.
- **RECOIL + MAG SIZE — real twin ladders, so every assault gun had to GROW
  one.** `gen_tod_twins.js`: the Enfield's axes `['r'] -> ['r','m']`, the
  AK-47's `['p'] -> ['r','m']`; `_tod_classes::register_gun` mirrors both with
  `axes2( "recoil", "r", "magsize", "m" )`. RECOIL's `set_guns` line is GONE
  (all three assault guns carry r, no gun outside the class does, so
  `class_keys` alone is the exact gate); MAG SIZE's list grows to
  enfield/krig/ak47/mp7 — it keeps a list only because of the skirmisher half
  (the MP7 has an m-ladder, the MAC-10 and MP5 do not).
- **THE TRADE: PENETRATION is HEAVY-ONLY again — the AK-47 gave up its
  p-ladder.** Axes MULTIPLY: p x r x m = 3 x 4 x 4 = 48 combos x 2 forms = 96
  registrations for the AK alone, which lands the ledger at 273 — past map 1's
  measured 230-boots / 368-crashes wall (docs/21 §A). With r+m only, the AK
  costs 32 like its classmates. **The AK is not weaker for it:** every source
  GDT ships `penetrateType "medium"` and the p-ladder STARTS at "small", so a
  p0 AK shot through LESS than any gun with no ladder at all — it now sits at
  the roster default permanently and trades a 2-level card for two 3-level
  ones. (Same wart still applies to the Stoner and HK21 at p0 — logged, not
  touched.)
- **LEDGER 166 -> 216** (194 generated + 22 fixed); assault twins 46 -> 96.
  `LEDGER_GUARD` raised 200 -> 220 with the arithmetic written down. Map 1
  shipped a BOOTING .ff carrying 229 weapon assets total (docs/21 §A) and its
  measured wall is 230-booted / 368-crashed, so 216 total sits under a
  known-good TOTAL with ~14 of margin. **Do not raise it again to buy a third
  axis on any gun** — a third axis on a 2-axis gun costs +64 by itself, and the
  skirmisher's f/h/m would need 384.
- **The ledger tool was lying by 7 and now self-counts** (flagged by a peer
  session, verified here). `LEDGER_FIXED` was a hardcoded 15 that nobody bumped
  when the six per-class secondaries (v9.29) and the AMP63 `ldw` half (v9.29a)
  were zoned — the real fixed count is 22 (20 in `zm_tower_of_doom.zone` + 2 in
  `xmas_gun.zpkg`). It is COUNTED now, from the main zone plus every zpkg it
  `include,`s minus our own output, and printed with a per-file breakdown. A
  guard fed a stale constant is not a guard: at the old 200 the true figure was
  already 216 with the tool reporting green.
- **No new art.** All four cards were already baked and gun-neutral (RECOIL =
  crosshair + chevrons, MAG SIZE = a magazine, IMPACT ROUNDS = a bullet burst,
  KILL RELOAD = a magazine + return arrow + skull); no card names, numbers,
  level counts or pip counts changed, and no gun is named on any of them.
- Stale-comment sweep in `_tod_upgrade_ui::domain_id` (26 still said "MP7"
  after OVERDRIVE moved to the Death Machine on 2026-08-23).

## 2026-08-23 (v9.37) — Breather TELEPORTERS + breathers ~2× larger

(session f2e3ffc8; FULL build — geometry + new module. User: "Every platform
will have a teleporter that will link back to the first starting floor. There
will be a wait period before you can use it again so you cant just spam it. We
have this implementation in the other map with models and everything and fx
... Wait period is 1 minute. Only players on the teleporter will be
teleported." + "the breather platforms are too small and need to be expanded
as well.")

- **Breathers 384×400 → 544×576** (`gen_tower_map.js` `BR_DEPTH` 400→576,
  `BR_EAST` 224→384 — ~2× the floor on laps 10/20/30/40; parapets, rail caps,
  zone volumes and the balcony light all hang off the two constants). Brush
  count unchanged (3178), door/crown data unchanged (52 doors, crown lap 51).
  Scripted furniture re-backed to the moved walls — these four must stay in
  lockstep with `BR_*`: perk pads y −783→−959 (`_tod_perk_scatter`), upgrade
  station model/trigger x −600/−544 → −760/−704 (`_tod_upgrades`), PaP stays
  on the N edge (`_tod_powerups`, comment refreshed), teleporter pad (below).
- **TELEPORTERS** — new `_tod_teleport.gsc`, a port of map 1's
  `_acc_teleporter`: one assembled Der Eisendrache pad (4 stock
  `p7_zm_der_teleporter` wedges + wires + glass, SetScale 2.5, sunk −52) per
  breather at (−640,−800) in the balcony's free SE quarter, ONE-WAY to an
  arrival pad on the base arena's west ring at (−400,0,0); riders land on a
  48u ring facing south. Hold-USE → 2.2 s CHARGE (charge FX + hum, nobody is
  locked) → DISCHARGE (flash + de-rez + warp boom) → everyone within 100u
  (±80 z) of the pad AT FIRE TIME warps; arrival = kino materialize beam +
  discharge. **60 s cooldown per pad**, armed BEFORE the warp (no double-fire):
  recharging = idle beam removed (beam on = ready) + "Teleporter
  recharging..." hint + the stock no-purchase sound on a press. No toasts;
  two constant hint strings (250-unique cap). Downed/spectating players never
  ride; presses during the upgrade pause are ignored. Every FX on a
  tag_origin host (bare PlayFX doesn't render). Stock models ×4 + FX ×4
  precached AFTER the #using block and force-packed by zone lines;
  `tod_teleport_charge` alias (tod_ui.csv, 3d, 86–90) + both wavs vendored
  into `sound_assets/acc/fx/`.
- Build note: the linker prints `Material gfx_teleport_tube_em_scroll_nocull
  was not found in gdtDB` — the kino arrival beam's tube material, which
  exists only as a beam reference in stock `t7_beams.gdt`. Known non-fatal
  class (KB: substituted, the .ff still packs; map 1 shipped the same FX).
  User-verified in game 2026-08-23 ("Seems good, the teleporters") → added
  to `build_map.ps1`'s waiver list (10 waived lines from here on).
- Incident: session 2a shipped a `-GscOnly` .ff (12:05:23 PM) carrying these
  scripts against the OLD geometry — perk machines and the pad floating off
  the old balconies. Superseded by this full build. Lesson for the build
  guard: "no process running" ≠ "tree is coherent" — a generator edit with a
  regen pending is a geometry change, full build only.

## 2026-08-23 (v9.37a) — CARD ART for SECOND WIND + MOMENTUM, and the OVERDRIVE re-bake

(session bc1a80d8; art wiring only, no gameplay change. Rode into session f2e3ffc8's v9.37 FULL
build — fresh `zm_tower_of_doom.ff` 92.64 MB @ 12:10:40 PM. See the BUILD DISCIPLINE note at the
end: this entry also records a mistake worth not repeating.)

- **User-supplied art installed** (files (35).zip), all verified before wiring — 9 cards at
  768×1152, 2 pause plates at 300×44, and the baked text proofread against the live constants:
  - **NEW (8 assets)**: `i_tod_card_second_wind_{regular,super,ultimate}`,
    `i_tod_card_momentum_{regular,super,ultimate}`, `i_tod_pause_r33`, `i_tod_pause_r34` — each
    got a PNG, an `image.gdf` block cloned from the sprint_armor pattern, and one `image,` zone
    line.
  - **OVERWRITE ONLY (3)**: `i_tod_card_overdrive_{regular,super,ultimate}`. Per the install rule,
    an EXISTING filename means replace the PNG and **stop** — the GDT block and zone line already
    exist and a second one is a duplicate asset. Verified exactly one block and one line each
    afterwards.
  - `CARD_SLUG[33] = "second_wind"`, `[34] = "momentum"`, and `PAUSE_PLATE_MAX` 32 → **34** so both
    render as plates rather than text rows in the pause menu.
- **The OVERDRIVE re-bake was the point of that overwrite**: the card had been drawn for the MP7
  and the domain moved to the Death Machine in v9.35. The new art shows a six-barrel minigun with
  a belt feed, and its baked text — "+12% PER 10 ROUNDS / SUSTAINED FIRE, 5 STACKS" — matches
  `overdrive_pct` Lv3 (0.12), `TOD_OVERDRIVE_PER` (10) and `TOD_OVERDRIVE_STACKS` (5) exactly.
  Checked rather than assumed, because a card that states the wrong number is worse than no card.
- **VERIFIED in the shipped fastfile**: 3 second_wind + 3 momentum + 3 overdrive rows and both
  pause plates present in the packed assetinfo; zero image errors in the linker log.

### BUILD DISCIPLINE — a real mistake, recorded so it is not repeated

Before this landed, this session built a `-GscOnly` fastfile (12:05:23) that was **incoherent**
and had to be superseded. The tree contained another session's *partially* landed work: their
teleporter module, entry-script wiring and **breather coordinate moves** (perk pads y −959,
station x −760) were on disk, but the **regenerated geometry those coordinates require was not**.
The result was perk machines and a teleporter pad floating in the air off the old 384×400
balconies.

- **The pre-build check that was performed**: no `BlackOps3.exe`, no `linker_modtools.exe`.
- **The check that was missing**: whether the working tree was *coherent* — i.e. whether every
  on-disk edit's dependencies had also landed. **In a shared repo those are different questions,
  and "no process running" is not "safe to build".**
- **The tell, which was present and read too late**: the linker reported **10** unique errors
  instead of the usual 9, and `build_map.ps1` explicitly printed "1 UNEXPECTED linker error". An
  unexpected-error count is a signal that the tree contains something the build did not expect —
  treat a change in that count as a stop-and-look, not a footnote.
- **The rule going forward**: when another session has announced work in flight, either wait for
  their DONE or confirm with them that the tree is buildable — regardless of what `tasklist` says.

*(Footnote on the extra error: `gfx_teleport_tube_em_scroll_nocull` was NOT caused by the
incoherent tree. It exists only as a beam reference in stock `t7_beams.gdt` with no material GDT
anywhere — the KB's known non-fatal/substituted class, and map 1 ships the same FX. It appears in
the clean v9.37 build too and is deliberately left out of the waiver list until the arrival beam
is eyeballed in game: if it renders, waive it; if not, it is a real bug.)*

## 2026-08-23 (v9.36) — DAMAGE domain applies to sidearms; +30% reserve on every gun

(session f2e3ffc8; -GscOnly build. User: "the damage upgrade should apply to
secondaries as well. And also all guns need a reserve increase by 30%. Be
careful with these changes. They are straight forward but touch many areas.")

- **DAMAGE → secondaries.** Two lanes gated the domain to the class gun; both
  now give the sidearm (and any non-class gun, e.g. the Death Machine
  powerup) the DAMAGE multiplier — DAMAGE ONLY; HEADSHOT, the tier uniques,
  CLEAVE and THOR stay class-gun-only:
  1. `_tod_upgrades::upgrade_damage_cb` non-primary branch: `final = damage
     × (1 + 0.12·Lv) × dmult`, and the early-out guard now includes
     `dmg_lvl > 0` — without that a sidearm hit DAMAGE had just modified
     would be returned as "untouched" (-1) and the raw value would land.
  2. `_tod_bosses::rp_damage_feed` (the Protector's own fallback lane): new
     `else if (isdefined(weapon))` branch with the same multiplier, so the
     two lanes agree whichever fires.
  The Panzer and the Reaver ride the generic actor chain (lane 1). The Gift
  of Death keeps its fixed-shots callback (registered ahead of this chain,
  short-circuits it). Balance note (session 2a's flag, relayed to the user):
  it COMPOUNDS with `gun_balance_mult` — DAMAGE 10 takes the heavy's pistol
  from ×9.6 to ~×21 effective.
- **+30% reserve.** `maxAmmo`/`startAmmo` are in MAGAZINES, so ×1.3 rounds
  to whole mags (`scaleSets`, INT_KEYS):
  - **class guns** — `gen_tod_twins.js` `RESERVE_MULT 1.3` on
    `RESERVE_KEYS {maxAmmo, startAmmo}` in `baseTune`'s base pass; the
    `_up` forms inherit via `PAP_COPY_KEYS`/`computePapSet`, ladders never
    touch these keys, melee forms stay 0. Regen diff = exactly 108 maxAmmo
    + 108 startAmmo lines (the 108 gun forms of 144 assets); weapons CSV
    byte-identical; ledger 159 generated (unchanged). Samples: MP5 8 → 10
    mags, Stoner 5 → 7 (rounding makes small counts land at +25…+40%).
  - **sidearms** — install-side Skye GDTs patched by script with
    `.tod-reserve-orig` backups (map 1 uses none of the three): AMP63 7 → 9,
    rdw_up 15 → 20 (start clamped 16 → 20), ldw 0 stays 0; Magnum 12 → 16,
    _up 18 → 23; Bulldog 12 → 16, _up 12 → 16.
  - **NOT covered: `pistol_standard`** (the heavy's sidearm) — a stock asset
    with no GDT source; it keeps the stock reserve unless a clone is built
    (+2 registrations). Flagged to the user.

## 2026-08-23 (v9.35) — ECHO ROUNDS and MEAT GRINDER removed, OVERDRIVE moved to the Death Machine, two new Skirmisher domains

(session bc1a80d8; `-GscOnly`. Fresh `zm_tower_of_doom.ff` 89.34 MB @ 11:52:02 AM, lint clean
across 51 files, errorlog = the 9 known-waived errors, nothing new.)

All four changes are one balance pass: the HEAVY was carrying two near-permanent damage
doublings, and the MP7 was carrying a duplicate of a mechanic that belonged on the minigun.

- **ECHO ROUNDS (id 11) REMOVED** (user: "we need to remove echo rounds"). Heavy-only,
  +10%/Lv chance to strike twice — a **flat ×2 at Lv10**, stacked on top of DAMAGE's +120%.
  **It had TWO copies of the roll**: `_tod_upgrades::upgrade_damage_cb` and a duplicate in
  `_tod_bosses::rp_damage_feed`. Stripping only the first would have left it firing on the boss
  lane alone — the kind of half-removal that reads as "sometimes it still procs".
- **MEAT GRINDER (id 30) REMOVED and OVERDRIVE MOVED** skirmisher/MP7 → heavy/**Death Machine**
  (user: "overdrive should be an upgrade of the death machine. Remove meat grinder and replace
  with overdrive"). The two were always the same mechanic — hold the trigger, hit harder — so the
  roster carried a duplicate across two classes. Consolidating is also a real heavy nerf, which
  is the point: **MEAT GRINDER capped at +100%** and a 150-round belt reached that cap trivially,
  while **OVERDRIVE tops out at +60%**. Between this and ECHO, the heavy loses roughly a ×4
  ceiling and keeps one capped ramp.
- **NEW — SECOND WIND (id 33)**, skirmisher, **MP7-bound** (user: "you heal as you run. 5% health
  per second. starts at 1% up to level5 at 5%"). 1% of max HP per level per second **while
  sprinting**, 5 levels — 1.5 HP/s at Lv1 up to 7.5 HP/s at Lv5 against the 150 base, so a full
  recovery takes ~20s of sustained sprinting at cap. Rides the existing 1s `body_systems_loop`
  tick beside REGEN via `trickle_heal`, so "per second" is literal rather than approximate.
  **Sprint-gated deliberately**: BO3 will not let you fire while sprinting, so the heal costs you
  your entire damage output for as long as you take it. That trade is the design.
- **NEW — MOMENTUM (id 34)**, skirmisher **class** domain, any gun (user: "I like momentum too.
  Lets add both one as skirmisher upgrade and one unique to MP7"). Damage scales with real 2D
  ground speed: nothing below 120 u/s, full bonus at 190 u/s, linear between, +5%/Lv at full
  speed over 5 levels. Speed constants mirror `_tod_runandgun`'s calibration so the two domains
  agree on what "moving" means.
  - **Keyed on RUN velocity, not sprint, and that is load-bearing** — the same engine rule that
    makes SECOND WIND a real cost makes a sprint-gated *damage* bonus worthless: you cannot fire
    while sprinting, so it would never once have applied.
  - It also had to be computed **above** the fire-streak gate in `unique_damage_mult`, and that
    gate's early return changed from `return 0` to `return add`. MOMENTUM has nothing to do with
    holding the trigger, so a lapsed streak must not zero it — left alone it would have been dead
    on most shots.
- **STALE ENTRIES KEPT ON PURPOSE.** `domain_id()` still maps `"echo"→11` and `"grinder"→30`, and
  the Lua still carries `DOMAIN[11]`/`[30]`. Both are **key/id-keyed maps, not ordered lists**, so
  a stale entry is inert and unreachable — the server can never send those ids again — while
  deleting one risks disturbing the ids the pause plates depend on. Documented in both files so
  nobody "tidies" them into a bug later.
- **VERIFIED before building**: all 31 registered domains have BOTH a `domain_id` case and a Lua
  row; the only orphan Lua rows are 11, 30 (removed) and 24 (the TIER card, which is not an
  `add_domain`). Deployed copy confirms `overdrive` bound to `t6_death_machine`, and `echo` /
  `grinder` present only as comment records with zero live `add_domain`.
- **ART OWED**: SECOND WIND and MOMENTUM have no baked cards, so they render as composite text
  and as TEXT rows in the pause menu (`PAUSE_PLATE_MAX` is still 32). OVERDRIVE's existing card
  art depicts an SMG and now belongs to the Death Machine, so it wants a re-bake. Prompts supplied
  to the user 2026-08-23.

## 2026-08-23 (v9.34) — FIX: the "invisible wall" beside the first flight is now a visible wall

(session f2e3ffc8; FULL build — the first since v9.18, so the LED bake is
exercised again. User, after the v9.31 QR-clip fix: "FYI the invisible
wall was a wall near quick revive. It wasn't quick revive ... a wall that
seems attached to the stairs near that tight hallway going from the quick
revive side to the wall that is attached to the wall to the power switch.")

- **Where:** the east gutter — the 104u corridor between the lap-1 E
  flight's outer edge (x=436) and the arena's east wall (x=540), from the
  N wall down to the Power Room's north wall (y=-400). Parsed every brush,
  brush-entity and point entity in it: the ONLY solid beside the 56u
  parapets is the generator's deliberate `lap1 E parapet (anti-bypass
  wall)` — x[416,436], y[-256,256], **z[0,288]** — the full-height slab
  that seals the gutter so nobody hops onto the first flight past the
  first door (gen_tower_map.js's SE-riser note documents it as the
  gutter's seal).
- **Why "invisible":** it wore `paraMatOf(0)`, the lap palette's neon-edge
  material, which at night renders as a faint glow line — a 288u barrier
  players could not see. **Fix:** that one box now uses `MAT.baseWall`
  (`mwiii_vertigo_retro_synth_blue`, the arena walls) so it reads as a
  wall on sight. Verified after `node tools/gen_tower_map.js`: the .map
  diff is exactly the 6 faces of that brush (cyan → blue); brush/entity
  counts unchanged (3178 / 482); `_tod_door_data.gsc` and
  `_tod_crown_data.gsc` byte-identical by cmp — no gameplay coordinate
  moved, bake budget unchanged.
- The v9.31 QR-clip fix stays (correct for solo, unrelated to this wall).
  Open design note for the user: the east gutter is a dead-end pocket by
  construction (this wall + the Power Room's north wall); making it a real
  walkway would be a layout change, not this fix.

## 2026-08-23 (v9.33) — MELEE DAMAGE LADDER: the katana no longer one-hits the rest of the game

(session bc1a80d8; `-GscOnly` plus a twins regen. Fresh `zm_tower_of_doom.ff` 89.34 MB @
3:40:11 AM, lint clean across 51 files, errorlog = the 9 known-waived errors, nothing new.)

User: "the damage that these do... they are scaling way too high. So once you get the katana you
can one hit rest of game. Lets make the knife 2k... I think i see 20k which is crazy."

- **THE REAL FLAW WAS THE FIRST STEP, NOT THE TOP END.** Old ladder: knife 1700/**20000**,
  katana 20000/40000, stormbreaker 40000/80000. Every tier step doubled *except* the knife's
  PaP, which was a **×11.8 jump** — so a Pack-a-Punched **TIER-1** knife already hit exactly as
  hard as the tier-2 katana. The "20k" the user spotted was reachable at tier 1.
- **Measured against this map's real zombie HP** — the stock curve (150 @ r1, +100/round to r9,
  then ×1.1 compounding) × `TOD_ZHEALTH_MULT` **1.25**, i.e. r20 ≈ 3.4k, r30 ≈ 8.8k, r40 ≈ 22.8k,
  r50 ≈ 59k — 20000 one-hits to **round 38**, or **round 54** with the DAMAGE domain maxed
  (×2.2). That is the entire practical game, exactly as reported.
- **NEW: a clean ×2 ladder that mirrors the GUN rule** (tier N base = tier N−1 PaP):

  | blade | base | PaP | one-hits to (raw) | with DAMAGE 10 |
  |---|---|---|---|---|
  | Combat Knife | **2000** | 4000 | r14 → r21 | r30 |
  | Wakizashi | **4000** | 8000 | r21 → r29 | r37 |
  | Stormbreaker | **8000** | 16000 | r29 → r36 | r44 |

  Every tier now buys ~7–8 more rounds of one-hitting, and melee stops being a free win around
  r36 — strong, never permanent. The Slasher keeps CLEAVE, CHAIN LUNGE and THOR'S THUNDER as its
  scaling, which is where a melee class's late game should come from.
- **FOUR places carry this number; all four updated.** Anyone touching melee needs this list:
  1. `register_melee_dmg()` in `_tod_classes.gsc` — drives `DoDamage` (swings and the chain lunge).
  2. `MELEE_TIER_DMG` in `tools/gen_tod_twins.js` — drives the ASSET's `meleeDamage`.
     **These two are two copies of one number and must stay in lockstep.**
  3. `melee_dmg()`'s unknown-blade fallback, which was **20000** — after this retune that would
     have made an unrecognised blade hit 5× harder than the top tier's base. Now 2000, the floor
     of the ladder. A fallback belongs at the bottom of a ladder, never above its ceiling.
  4. `TOD_LUNGE_DMG` in `_tod_lunge.gsc` — documentation only: `do_lunge()` already calls
     `tod_classes::melee_dmg( knife )`, so the chain lunge tracks the ladder automatically and
     needed no functional change. The constant was left reading the old 20000, which would have
     misled the next reader.
- **VERIFIED in the deployed assets**: `tod_weapon_twins.gdt` now holds 6 × 2000, 12 × 4000,
  12 × 8000, 6 × 16000 across the 36 melee forms, with no 1700 / 20000 / 40000 / 80000 anywhere.
  Deployed `_tod_classes.gsc:129-131` reads the new ladder.
- `docs/armory.html` updated to match (compare table, the tier-promise table, the per-tier melee
  row) and given a new **one-hit reach** row, since the raw damage number alone never told a
  reader the thing they actually care about.

## 2026-08-23 (v9.32) — NO MELEE LUNGE (the blades disagreed), Bulldog and pistol retune

(session bc1a80d8; `-GscOnly` plus a twins regen. Fresh `zm_tower_of_doom.ff` 89.34 MB @
3:32:27 AM, lint clean across 51 files, errorlog = the 9 known-waived errors, nothing new.)

- **`meleeLungeRange` FORCED TO 0 ON ALL MELEE** (user: "Remove the lunge swing from all
  melee. It makes them inconsistent"). `meleeLungeRange` is the automatic step-toward-the-target
  the engine adds to a swing. **The generator never set it**, so each blade inherited whatever
  its port shipped — and they disagreed:

  | blade | was | now |
  |---|---|---|
  | Combat Knife (T1) | **100** | 0 |
  | Wakizashi (T2) | **70** | 0 |
  | Stormbreaker (T3) | 0 | 0 |

  That is precisely the inconsistency the user felt: the same swing at the same distance
  connects on one tier and whiffs on the next, and a **promotion silently changed your reach**.
  A blade's reach is now purely its own `meleeRange`, so a tier step changes damage and swing
  speed and nothing about where the swing lands.
- **Implemented as ONE roster-wide rule, not three per-gun edits**: a `MELEE_NO_LUNGE` str
  override applied inside `gen_tod_twins.js::baseTune` whenever `gun.melee`. Both form paths and
  every k-ladder twin pass through `baseTune` (the twin path is `ladderScale( gun, baseTune(...) )`),
  so all 144 generated assets are covered and a future fourth blade inherits it automatically.
  Guns already shipped 0, so the rule only ever touches melee. VERIFIED: the deployed
  `tod_weapon_twins.gdt` reads `meleeLungeRange 0` on **144 of 144** assets, with no other value
  present anywhere in the file.
- **BULLDOG ×0.5 → ×0.75** (user: "Reduce the nerf of bulldog from 50% to 75% damage"). The
  emergency-only ×0.5 lasted exactly one build. Now 90/pellet base and 180/pellet PaP, still
  inside a `maxDamageRange` of 325 — a less punishing point-blank answer, still not a ranged one.
- **STARTER PISTOL ×8.0 → ×9.6** (user: "buff the original pistol that LMG class use by 20%
  damage"). It is the HEAVY class's sidearm since secondaries went per-class. Its stock GDT is
  not in the tools tree, so this multiplier remains the only damage figure about it that anyone
  can actually verify.
- **TWO GENERATOR FACTS, learned here, worth knowing before hand-editing anything it owns:**
  1. `gen_tod_twins.js` **patches and REORDERS**
     `gamedata/weapons/zm/zm_levelcommon_weapons.csv` on every run (72 PaP-mapping rows). It
     PRESERVED the three hand-added secondary rows this time — they moved to lines 58-60 with
     the AMP63 still correctly `t9_amp63_rdw_up` — but the safe order is generator first,
     hand-rows second, verify after.
  2. Its **REGISTRATION LEDGER printout is stale and actively misleading**: it prints
     "144 + 15 = 159" because `LEDGER_FIXED` (`gen_tod_twins.js:165`) was never bumped for the
     six secondary registrations. The real figure is **166** (144 generated + 19 map-zone + 2
     xmas_gun + the AMP63 ldw half). Harmless against a 200 guard, but do not trust the number
     it prints.
- **NOT DONE, deliberately**: the CHAIN LUNGE upgrade domain (id 22, slasher, S-tier) is
  untouched. "The lunge swing" was read as the weapon-level field above, because that is the
  thing that made the three blades inconsistent *with each other*. CHAIN LUNGE is a separate
  opt-in card that lunges you onto the next zombie after a knife kill; deleting a whole S-tier
  domain is the user's call, not an inference. Flagged to the user rather than assumed. (If it
  is ever removed: domain ids are order-derived in `level.tod_domains`, but `domain_id()` is a
  key-based switch, so the LUI mapping does NOT shift — remove the `add_domain` line, the
  `tod_lunge::open_window` call and the module init; the Lua `DOMAIN[22]` row can stay harmlessly.)

## 2026-08-23 (v9.31) — FIX: the invisible wall where Quick Revive stood (solo)

(session f2e3ffc8; rides in session 2a's -GscOnly build of the same hour —
the sync carried the on-disk edit. User: "On the first floor there is some
invisible wall at the corner near quick revive.")

- **Ruled out first:** the generated geometry. Parsed every `clip` brush in
  the base N-wall band at player height (the generator writes one real
  coordinate per face — z1,z2,y1,x2,y2,x1 — so bounds are exact): only the
  base walls (0-128), the clips above them (128+), the inlay and the floor.
  No stray clip in either corner pocket. So the wall was an entity.
- **THE CAUSE is stock.** `_zm_perk_quick_revive::revive_solo_fx`: after the
  third solo use the machine flies up and away, then `machine_clip Hide()` +
  `ConnectPaths()`. `Hide()` only stops RENDERING — the `zm_collision_perks1`
  model stock spawned as the machine's collision stays SOLID, so QR's spot
  is an invisible block for the rest of the run. Stock never NotSolid()s it
  (`unhide_quickrevive` only `Show()`s it). On stock maps QR sits in an
  alcove where nobody walks through the gap; ours stands free on the base
  N wall at (-75, 500), so the block is right in the path.
- **FIX** (`_tod_perk_scatter.gsc::qr_clip_watch`, threaded from init): a
  0.5s poll that mirrors the machine's hidden state onto its clip —
  `NotSolid()` the moment the model is gone (deleted by `turn_perk_off`) or
  its replacement is flagged `ishidden`; `Solid()` again when stock unhides
  it (hot-join). Handles: stock's `level.quick_revive_machine(_clip)` first,
  the scatter's captured QR trigger as the fallback. Edge-triggered, so it
  is a no-op on every tick where nothing changed; co-op (no fly-away) never
  sets the clip handle, so stock behaviour is untouched there.

## 2026-08-23 (v9.30) — SPRINT ARMOR card art installed (files (32).zip)

(session f2e3ffc8. On-disk wiring; rides in session 2a's next FULL build
(v9.29 per-class secondaries — its sound-bank rebuild covers the image
assets too). Numbered above v9.29 by agreement; no separate build.)

- The user's drop carried exactly the four files docs/29 asked for, at the
  exact names and sizes: `i_tod_card_sprint_armor_{regular,super,ultimate}`
  768×1152 + `i_tod_pause_r32` 300×44, plus a contact sheet. Proofread on
  the sheet: title SPRINT ARMOR ×3, ribbons REGULAR +1 / SUPER +2 /
  ULTIMATE +3 on the matching frames, bold -5% / -10% / -15% DAMAGE TAKEN,
  light line "WHILE SPRINTING · 5% PER LEVEL", FIVE pips lit 1/2/3, plate
  r32 — clean.
- Wired per the install rule (NEW filenames): 4 `image.gdf` blocks appended
  to `tod_ui_images.gdt`, 4 `image,` zone lines after `i_tod_pause_r31`,
  `CARD_SLUG[32] = "sprint_armor"` (`tod_upgrade.lua`), `PAUSE_PLATE_MAX =
  32` (`AetheriumStartMenu.lua`). Domain 32 now deals a baked card and shows
  a baked pause plate; the text rows stay as the no-art fallback.

## 2026-08-23 (v9.29a) — FIX: the map would not load (a `_zm` suffix in the weapons CSV)

(session bc1a80d8; `-GscOnly`. The 2:48:39 AM v9.29 fastfile FAILED TO LOAD. One-row fix,
rebuilt at 2:57:04 AM — fresh `.ff` 89.32 MB, 9 known-waived errors, nothing new.)

- **THE RULE, because this is the second time the `_zm` suffix has bitten this project:**
  - **zone lines = ASSET name, which KEEPS `_zm`** -> `weapon,t9_amp63_rdw_up_zm`
  - **weapons CSV + every GSC name = RUNTIME name, `_zm` STRIPPED** -> `t9_amp63_rdw_up`
  The engine strips `_zm` at load. The in-repo precedent was sitting two lines above the
  mistake: zone `t9_me_knife_american_zm` -> CSV `t9_me_knife_american`. Now written into the
  zone beside the secondaries block, where someone adding a port is actually standing.
- **What happened**: v9.29 shipped `gamedata/weapons/zm/zm_levelcommon_weapons.csv` row 130 as
  `t9_amp63,t9_amp63_rdw_up_zm`. That runtime name does not exist. Stock resolves EVERY
  `upgrade_name` while building the weapon table, so the unresolvable one aborted init.
- **Why it was hard to read from the symptom** (worth keeping): the fastfile loaded fine
  (`XZONE_LOADED in 2003ms`), the sound banks loaded fine (states 1->7, `.sabs`/`.sabl` both
  allocated), there was **NO script-error line and no crash dump** — just an unload/abort at
  +1.8s back to the frontend. It presents as a fastfile or bank problem and is neither.
  Ruled out on the way: altWeapon (all six new assets screened `"altWeapon" ""`, matching the
  known-good t9_mp5) and corrupt banks (the game launched at 2:51:05, well after the 2:48:39
  build — no overlap, and banks give a hang or silent crash, not a clean return to menu).
- **Process note**: a peer session's tasklist showed clear and mine a second later showed the
  game running, so a BUILD START was announced and retracted without writing anything. The
  builder's own process check immediately before the linker is the load-bearing one; a peer's
  all-clear is a snapshot that can go stale in the gap.

## 2026-08-23 (v9.29) — PER-CLASS SECONDARIES (AMP63 / Magnum / pistol / Bulldog) + zombie ramp nerf

(session bc1a80d8; `-GscOnly` — see the build note at the end. Built alongside
session f2e3ffc8's v9.30 SPRINT ARMOR art. Fresh `zm_tower_of_doom.ff`
**89.32 MB** @ 2:48:39 AM, sound banks rebuilt @ 2:47:53, lint clean across 51
files, errorlog = the 9 known-waived errors, nothing new.)

- **Every class now gets its own sidearm** (user: "we need to look into
  secondarys now..."). Was ONE global `TOD_CLASS_SECONDARY "pistol_standard"`
  for all four classes.

  | Class | Sidearm | Base → PaP | GDT damage |
  |---|---|---|---|
  | SKIRMISHER | AW Bulldog | `s1_bulldog` → `s1_bulldog_up` | 120/pellet **× 0.5** |
  | ASSAULT | CW Magnum | `t9_magnum` → `t9_magnum_up` | 250, 6-round clip |
  | HEAVY | starter pistol | `pistol_standard` → `_upgraded` | ~25, keeps its ×8 |
  | SLASHER | CW AMP63 | `t9_amp63` → `t9_amp63_rdw_up_zm` | 135, ~650 RPM, 15-round clip |

  **Base + PaP only — explicitly NO twins** (user: "They will all have PaP
  versions but thats about it"), so none of these enter `gen_tod_twins.js` or
  carry a variant ladder. Ledger 159 → **165** against the 200 guard.
- **TWO NAME CORRECTIONS**, both verified against the installed GDTs before
  anything was written: the CW machine pistol is the **AMP63**, not "APM63";
  and the only Bulldog installed is the **Advanced Warfare** port
  (`s1_bulldog`), not the Ghosts one. Both are shotguns, so the intent carries.
- **Damage: only the Bulldog is touched.** The starter pistol keeps ×8 because
  its GDT damage is ~25 and the opening rounds are unplayable without it; the
  three Skye ports arrive with real numbers and need no help. The Bulldog is the
  one deliberate nerf — user chose EMERGENCY-ONLY, so ×0.5 = 60/pellet with
  `maxDamageRange` 325, i.e. a point-blank panic shot still saves you and
  nothing at range is worth firing. Half rather than lower because the
  Skirmisher already has the best mobility and ammo economy (RUN AND GUN); its
  sidearm should be the weakest of the four, not a second primary.
- **`take_foreign_secondaries()` — a bug this feature would otherwise have
  shipped.** Sidearms sit in PRIMARY slots and the base stations let a player
  switch class mid-run, so without a strip one switch leaves you holding two —
  and the stock too-many-weapons monitor that would normally reap the extra is
  deliberately OFF on this map (v9.18, it was confiscating class guns). Matched
  on the STEM so the PaP forms are caught too, not just the base assets.
- **The AMP63's PaP asset breaks the port convention**: it is
  `t9_amp63_rdw_up_zm`, NOT `t9_amp63_up`. Harmless, because the weapons CSV
  carries an explicit `upgrade_name` column (field 2) and PaP resolves by table
  lookup rather than by suffix. Commented at both the define and the zone line
  so nobody "corrects" it later.
- **SOUND — the part that had a real trap in it.** All three are ports, so
  without alias rows they link fine and fire **silently**.
  - The two CW guns ride the existing recipe: added to `gen_tod_sounds.js`
    (`GUNS` + `GDT_OF`) and regenerated — AMP63 72 fire + 26 foley, Magnum 60
    fire + 13 foley. The **Magnum has no `trig_pull` family** (a revolver, same
    shape as the Stoner) and is flagged `skipFire: ['trig_pull']`; without that
    the generator emits rows pointing at wavs that do not exist.
  - **The BULLDOG cannot use that recipe at all.** It is an old-style port with
    just **2 fire wavs** (`shot`, `pap_shot`) and 5 foley, against the t9
    layout's shot/trig_pull/mech/sub/pap_flux families. Its **9 aliases are
    hand-authored in `sound/aliases/tod_ports.csv`** — which is precisely what
    that file exists for (its header documents non-t9 ports taking rows
    verbatim). Rows were cloned field-for-field from the `t5_hk21` templates
    (102 fields) with `Secondary` blanked, because the Bulldog ships no `_tail`
    wav and a dangling alias reference is fatal.
  - **VERIFIED: all 180 new alias rows resolve to a real wav on disk, zero
    missing** (9 bulldog + 98 amp63 + 73 magnum), and both CSVs are registered
    in `zm_tower_of_doom.szc`. Sound banks rebuilt at 2:47:53, before the
    fastfile packed at 2:48:39.
- **ZOMBIE SPEED RAMP** (separate user request, same build): full sprint round
  **10 → 12**. NOTE the user believed it was still 7 when asking — it moved 7 →
  10 back on 2026-08-20 — so this is gentler than intended. If it still reads
  fast the next lever is `TOD_ZSPEED_START_RATE`'s 0.8 floor or flattening
  `TOD_ZSPEED_STEP`, not pushing this further out; past ~15 the early game stops
  escalating at all. Also fixed a stale comment there that still claimed "0.5 at
  round 1 -> 1.0 at round 7" long after both constants had changed; it is
  written against the constants now so it cannot rot again.
- **BUILD NOTE, correcting an earlier claim in this session**: secondaries do
  NOT need a full build. `-GscOnly` skips only `cod2map64` and the LED bake —
  the **linker still rebuilds the sound banks** from the `.szc`, which is all
  the alias work required. Nothing geometric moved, so the fast path was both
  correct and safer (no LED bake exposure).

## 2026-08-23 (v9.28) — NEW DOMAIN: SPRINT ARMOR (-5%/Lv damage taken while sprinting; skirmisher + slasher)

(session f2e3ffc8. On-disk edits, built in the next -GscOnly build with
session 2a's v9.27 Panzer roof. User: "an upgrade where you take less
damage when you are running, 5% each level, 5 levels max. Only for melee
and skirmisher. We would need a prompt as well to get the image assets.")

- **Domain `sprintarmor` / "SPRINT ARMOR"** (`_tod_upgrades.gsc`): max 5,
  class keys skirmisher + slasher, tier A (strong but conditional), scope
  **"class"** — it is damage resistance, the thing the user said survives a
  tier-up, so it persists like DMG REDUCTION. `domain_id` **32**
  (`_tod_upgrade_ui.gsc`; the 6-bit field allows 1..63).
- **Effect:** `tod_upgrades::sprint_armor_mult( player )` = `1 - 0.05*Lv`
  while the engine reports the player sprinting (`IsSprinting`, the
  server builtin), else 1.0; floored at 0.05. Multiplied into BOTH of
  `_tod_bosses`' player-damage lanes right after the DR block —
  `boss_player_damage` (the normal chain: zombies, RP bullets, electroball)
  and `apply_player_mitigations` (Panzer melee, the pack's short-circuit) —
  so it stacks multiplicatively with DMG REDUCTION (Lv5 of both while
  sprinting = ×0.75 × 0.75). Known gap inherited from the chain: the
  Panzer's two FIRE sources bypass every tod lane (session 2a's audit), so
  sprint armor does not reduce burn either.
- **UI:** `tod_upgrade.lua` DOMAIN[32] text row (composite-card fallback,
  pause-menu text row) — **no baked art yet**; `CARD_SLUG[32]` and
  `PAUSE_PLATE_MAX` stay put until the drop lands. The image prompt is
  `docs/29_sprint_armor_art_prompt.md` (3 cards + plate r32, exact
  filenames/text).
- Docs: armory row, `upgrade_system.md` line.

## 2026-08-23 (v9.27) — PANZER CONCURRENCY ROOF (a real ship-state bug), AR/LMG speed, BOUNTY in the score popup, station retune

(session bc1a80d8; `-GscOnly`, built alongside session f2e3ffc8's v9.24/v9.26/
v9.28 work in one fastfile. Fresh `zm_tower_of_doom.ff` 88.16 MB @ 1:39:55 AM,
lint clean across 51 files, errorlog = the 9 known-waived errors, nothing new.)

- **PANZERS NEVER STOPPED ACCUMULATING — found by the ship-state audit, then
  hand-verified.** `director()`'s Panzer branch had **no concurrency roof**; the
  Protector branch one line below it always had one (`protectors_alive() <
  TOD_RP_MAX_ALIVE`). Nothing in this map or the vendored pack despawns or
  leashes a Panzer. And `level.tod_panzer_alive` was initialised at `:init`,
  incremented and decremented correctly in `panzer_life`, and **read nowhere** —
  a dead variable. The roof was clearly intended and never wired up.
  So an unkilled Panzer was permanent and every 5th round stacked another: #2 at
  r10 (~23k), #3 at r15 (~35k), #4 at r20 (~55k), all alive at once on an open
  staircase. **Both dev flags hid it perfectly** — god meant the count never
  mattered, dev money meant each one died on arrival — so it only became
  reachable the moment ship state went in at v9.22, one build earlier.
  - `TOD_PANZER_MAX_ALIVE 1` (he is "THE boss", singular, per this module's own
    header), and the director branch now gates on it.
  - **Debt cap**, the other half: without it a player who stalls through rounds
    10/15/20 banks a queue that all pops the instant the first one dies — the
    same flood by a slower route. Owing at most one means a slow kill costs you
    the Panzer you already have, not a backlog.
  - **Music gate**: `panzer_life` called `boss_track_end()` on EVERY death with
    the comment "last Panzer down". The code never checked, so with the roof
    missing the first kill cut the boss track while others were still hunting.
    Now gated on the count actually reaching 0 — correct at roof 1, and it
    survives the roof being raised later.
- **AR + LMG move speed −0.05** (user): ASSAULT 0.9 → **0.85**, HEAVY 0.8 →
  **0.75**. Skirmisher (1.0) and Slasher (1.1) untouched, so the spread widens.
  Keyed on the CLASS in `class_speed_base()`, not the gun, so it holds across
  each tier ladder and survives a roster swap.
- **BOUNTY now shows in the centre-screen score popup** (user: "im getting 110
  on headshot but it shows +100. It should show +110"). Cause was a callback
  ordering quirk: the Aetherium kit draws that popup from a
  `zm::register_zombie_damage_override` callback — fired on the KILLING BLOW —
  and **recomputes** the kill value itself, while BOUNTY pays from a
  `zm_spawner::register_zombie_death_event` callback that fires AFTER. At popup
  time the bonus does not exist yet, so no same-frame stash can reach back for
  it.
  - Fix is **display-only**: a read-only `bounty_preview()` that banks nothing,
    awards nothing and changes no state, reached from the kit through
    `level.tod_bounty_preview_fn` — a level function pointer, not a `#using`,
    because the vendored kit must never import a tod module (the cycle rule, same
    dodge as `level.tod_player_mitigations_fn`).
  - The prediction is **exact**, not an estimate: the bank is deterministic given
    its current value plus this kill, and `on_class_gun_kill` runs the identical
    arithmetic off a now-SHARED `bounty_kill_value()` helper milliseconds later.
    Extracting that helper is what stops the two ever drifting.
  - Added **after** the `zombie_point_scalar` multiply on purpose: BOUNTY is
    awarded as raw unscaled score, so adding it there is what makes the popup
    equal the actual score change rather than merely closer to it.
- **UPGRADE STATION retune** (user): `TOD_STATION_USES_PER` 3 → **5** per player
  per terminal (six terminals = 30 buys per climb, was 18), and the price ladder
  `2000 + 1000*n` → **`2000 + 500*n`**. The ladder stays GLOBAL per player, so
  more terminals still only make upgrades closer, never cheaper. Buy #10 was
  11,000, now 6,500. NOTE the per-station cap has only been enforceable at all
  since v9.22 — `station_depleted()` returns false outright while `tod_dev` is
  on, so every dev build had unlimited uses. The dead-card refund still returns
  both the price step and the use.

## 2026-08-23 (v9.26) — Music stops at game over (it played on under the end screen)

(session f2e3ffc8; on-disk edit, NOT built separately — rides in the next
-GscOnly build like v9.24 did. Found by session 2a's ship-state readiness
audit; the symptom only ever shows on the v9.24 game-over menu.)

- `_tod_atmosphere.gsc`: `channel_stop()` was only ever reached THROUGH
  `channel_play()`, so the looping music emitter (ambient or the Panzer /
  finale boss track) outlived `end_game` and kept playing under stock's
  game-over sting — and under the Restart Map / End Game menu. New
  `music_end_watch()` (threaded from `ambient_music`, its own thread because
  `ambient_music`'s `endon("end_game")` would kill it) does
  `level waittill("end_game"); channel_stop();` — win or wipe. Nothing can
  restart the channel afterwards: every `channel_play` caller (the Panzer
  refcount in `_tod_bosses`, the finale latch) runs under a level
  `endon("end_game")`.
- Noted from the same audit, BY DESIGN (mirrors map 1): in solo an open
  pause menu pauses the server and freezes the 60s game-over countdown; a
  player who closes the menu and idles past 60s is `ExitLevel`'d to the
  lobby like stock.

## 2026-08-23 (v9.25) — PANZER: the ELECTROBALL halved

(session bc1a80d8; `-GscOnly`. User, from the live run: "Same with his zap. He
threw his zaps and i died in 2 hits. Lets cut that in half damage as well.")

- **`TOD_PANZER_EXPLOSIVE_MULT` 1.1 → 0.55.** Applied electroball damage is
  `GDT damage × this × TOD_PANZER_DMG_MULT`, so per ball it goes **24 → 12**.
- **WHY 24/ball was killing in "2 hits" — the per-ball number was the wrong
  unit.** Three things compound, and only the first was obvious:
  1. The GDT (`mechz_spiki.gdt`, `electroball_grenade_zm`) does a **FLAT 45**
     anywhere inside a 200u radius — `explosionInnerDamage` and
     `explosionOuterDamage` are both 45, so there is **no falloff**. Standing at
     the edge of the blast is worth exactly as much as standing on it.
  2. He throws a **BURST OF THREE** (stock `MECHZ_GRENADE_BURST_SIZE` 3, up to 9
     active, `MECHZ_GRENADE_DELAY` 6000ms between bursts).
  3. `_tod_bosses::electroball_bounce_detonate()` — **our own addition** — pops
     each ball on its FIRST BOUNCE rather than letting it fuse, so all three
     land clustered at the player's feet instead of scattering.
  Net: the real unit is the BURST, not the ball. At 24/ball a burst was **72**,
  and against `TOD_UPG_BASE_HP` **150** that is a two-burst death — exactly what
  the user reported. Now 12/ball = **36/burst**, so four-plus bursts, i.e. 24s+
  of sustained exposure at the 6s burst cadence.
- **Verified the lane actually fires before trusting the constant** (the v9.23
  fire bug was precisely a multiplier that never applied): `acc_is_panzer` IS
  set on spawn (`_tod_bosses.gsc:762`), the weapon is a `grenadeweapon.gdf` so
  the `IsSubStr( sMeansOfDeath, "GRENADE" )` gate catches it, and the script
  itself applies NO zap damage — `electroball_watch/impact/bounce_detonate` only
  drive detonation, all damage is engine/GDT-side through this one lane. So
  unlike the flame, there is no second unscaled path here.
- **If it still bites, the next lever is the clustering, not this number** —
  noted in the constant's comment block.
- **VERIFIED**: `lint_tod_arity` clean (51 files); BUILD OK; fresh
  `zm_tower_of_doom.ff` 88.15 MB @ 1:02:06 AM; errorlog = the 9 known-waived
  errors, nothing new; log re-grepped for `gameover`/`StartMenu` (session
  f2e3ffc8's v9.24 work rides in this build unchanged) — clean. Ship state
  preserved: dev/god still off.

## 2026-08-23 (v9.24) — GAME-OVER MENU: Restart Map / End Game instead of the lobby dump

(session f2e3ffc8. Shipped INSIDE session 2a's v9.23 build — the sync
mirrored these on-disk edits into it: -GscOnly, BUILD OK, **88.15 MB @
12:39:35 AM**, linker log grepped clean for gameover/startmenu; no separate
build, the .ff would be byte-identical. User: "We need a fast restart menu
after a game loss. Or else this is just annoying that you have to go back
and everything. The other map had something like this.")

- **WHAT STOCK DID:** a wipe shows GAME OVER / survived N rounds, forces the
  scoreboard, waits `zombie_vars["zombie_intermission_time"]` (15s) and
  `ExitLevel(false)`s everyone to the BO3 lobby (`_zm.gsc:6043-6250`) —
  retrying meant the whole usermap reload round-trip. The pause menu's own
  **Restart Level** (`Engine.Exec map_restart`, an in-place script restart)
  already existed but stock DISABLES the ingame menu at end_game
  (`setMatchFlag("disableIngameMenu", 1)`, :6043).
- **NEW `_tod_gameover.gsc`** — port of map 1's retry-on-death v3
  (`_acc_leaderboard.gsc::offer_retry_on_death`, docs/40) minus the
  leaderboard plumbing. On `end_game` (a wipe OR the finale's win): the
  intermission wait is stretched to 120 synchronously on the notify (stock
  reads it at :6208, so its exit is parked); 3s settle; `LUINotifyEvent
  force_scoreboard 1,0` (stock's own release, :6244); dvar `tod_go_active=1`;
  `SetMatchFlag("disableIngameMenu", 0)`; `OpenMenu("StartMenu_Main")` on
  every player. No choice in 60s → `ExitLevel(false)`; an independent 90s
  failsafe exits if the main thread ever died; stock's parked wait is the
  last net — the game can never sit on the death screen forever. The dvar
  is scrubbed at init (dvars persist across `map_restart`; a stale "1"
  would turn the next game's mid-run pause menu into the two-entry list).
- **`AetheriumStartMenu.lua` game-over mode** (dvar-gated, every read
  pcall'd through a try-list): the button list is exactly **Restart Map**
  (the kit's Restart Level lane verbatim — `GoBack` + `map_restart`) and
  **End Game** (the Leave Game disconnect lane verbatim); title "Game Over";
  the settings-icon row hidden AND `makeNotFocusable` (so up/down can never
  land on an invisible list); initial focus on the two-entry list. ESC
  closes it like any pause menu and reopens it (the ingame menu stays
  enabled). Host-side dvar → co-op peers get the normal pause list (Leave
  works there; restarting is the host's call).
- Wiring: `zm_tower_of_doom.gsc` `#using` + `level thread
  tod_gameover::init()` after the finale; `.zone` scriptparsetree line.
  Doctrine kept: no dev dvars, no live-disable switch, no new assets, no
  clientfields/eventstrings (`force_scoreboard` is stock-precached).
- **Do NOT rebuild this as a cloned `Intermission_Main.lua`** — map 1 tried
  that first (2026-06-19) and it broke the map load unrecoverably; the
  re-enabled pause menu is the proven shape. Map 1's v3 itself was
  lint/hksc-verified but never logged an in-game retest — this is the first
  live test of the menu-mode mechanism. Worst case is not a fatal: if the
  menu fails to open, the death screen lingers 60s instead of 15s before
  the normal lobby exit.

## 2026-08-23 (v9.23) — PANZER: 15k base, and his FIRE halved (both sources)

(session bc1a80d8; `-GscOnly`. User: "What is the panzers health on solo round
5?" → "Yeah that should be 12k and his fire should do half damage it currently
does" → "Lets say 15k actually".)

- **HP: `TOD_PANZER_HP_BASE` 25000 → 15000** at the round-5 anchor, exponent
  1.09 unchanged. Solo now r5 **15k** / r10 23k / r20 55k / r30 129k / r40 306k
  (was 25k / 38k / 91k / 216k / 511k). Co-op still ×1.7 / 2.3 / 2.6 via
  `coop_hp_mult()`. Effective TTK is higher than the raw number in both cases —
  body hits scale to `TOD_PANZER_BODY_SCALE` 0.35 and the head to 0.9, so round
  5 is ~43k of body damage or ~17k of faceplate.
- **FIRE HALVED — and this uncovered a real drift bug.** The Panzer has **TWO
  independent fire damage sources**, and both call
  `burnplayer::SetPlayerBurning` DIRECTLY, so **both bypass every tod mitigation
  lane**: `_tod_bosses::apply_player_mitigations` (the melee short-circuit that
  carries `TOD_PANZER_DMG_MULT` 0.5) *and* `_tod_bosses::boss_player_damage`
  (the electroball lane **and the DR upgrade domain**). That is precisely why
  the 2026-08-20 "Panzer hitting too hard — halve ALL panzer damage" pass never
  touched the flame at all:
  - `mechz_spiki::acc_player_flame_damage` (~:1544) — the **flameTrigger cone**.
    Was scaled by an `acc_panzer_flame_mult` dvar defaulting to **1.21** (map 1's
    +10% flamethrower and +10% all-Panzer passes, stacked).
  - `mechz_spiki::function_3389e2f3` (~:743) — the **ground-fire pool**, ignited
    by the 10Hz proximity sweep (~:710). **Never scaled by anything** — it sat at
    the raw stock 30/20 through every "too hard" pass.
- **THE DOT MATH, which is the actual reason this mattered.** ~3 ticks run to
  completion once you are tagged; the burn cannot be outrun and is **not**
  reduced by the DR domain. Per-ignite total against a 100 HP player:
  - cone at 1.21 = 36/tick = **108 total → a GUARANTEED no-Jugg down from one
    tag.** Map 1's own comment in this file had flagged exactly that number as
    unacceptable and dropped back to 1.0; the two later +10% passes silently
    walked it back past that line and nobody re-did the arithmetic.
  - cone now 0.605 = 18/tick = **54 total** (Jugg 12/tick = 36).
  - ground pool now = 15/tick = **45 total** (Jugg 10/tick = 30); was 90 / 60.
- **One shared constant so they cannot drift again**: `TOD_PANZER_FIRE_MULT 0.5`
  at the top of `mechz_spiki.gsc`, applied at both sites. The
  `acc_panzer_flame_mult` **dvar is folded away** with it — this map's doctrine
  is compile-time constants, never dvars.
- **VERIFIED**: `node tools/lint_tod_arity.js` clean (51 files); BUILD OK; fresh
  `zm_tower_of_doom.ff` 88.15 MB; errorlog = the 9 known-waived errors, nothing
  new. Build remains SHIP state (dev/god off, v9.22).
- **NOTE — this build also carries session f2e3ffc8's on-disk game-over work**
  (`_tod_gameover.gsc` + its zone/entry lines + `AetheriumStartMenu.lua`), which
  was already committed to disk when this build ran; the sync mirrors `scripts/`
  and `zone_source/`, so it could not be excluded without clobbering their work.
  It compiled clean — the linker log shows nothing about `_tod_gameover.gsc` or
  StartMenu — and that session was told so it can verify. Their CHANGELOG entry
  is v9.24.

## 2026-08-23 (v9.22) — SHIP STATE: dev + god OFF (first real run)

(session bc1a80d8; `-GscOnly`. User: "okay turn off dev and god mode. Im going
to play a real run." `scripts/zm/zm_tower_of_doom.gsc::tod_resolve_dev_flags()`
— `level.tod_dev` and `level.tod_god` both `true` → `false`.)

- **This is the first time the map has been played in ship state.** Every build
  in its history was tested with both flags armed, so the ship path is the
  less-exercised one. The twelve flag readers were traced before flipping —
  `_tod_bosses.gsc:186,452,453,1523`, `_tod_finale.gsc:265`, `_tod_main.gsc:50`,
  `_tod_perk_scatter.gsc:479,497`, `_tod_reaver.gsc:117`,
  `_tod_upgrades.gsc:1130,1513,2463` — and all twelve are plain ternaries or
  guards with a sane ship side. The two `!IS_TRUE( level.tod_dev )` readers in
  `_tod_perk_scatter` are early-returns in debug PRINTERS, not ship-only
  behaviour, so nothing changes there but the absence of console spam.
- **What actually changes for the player:**

  | | dev (all prior testing) | SHIP (now) |
  |---|---|---|
  | Upgrade events | every round | every 4th (`TOD_UPG_EVERY_N_SHIP`) |
  | Panzer | round 3, then every 3 | round 5, then every 5 |
  | Reaver | every 2 rounds | every 4 (still gated on the lap-20 door) |
  | TIER card | 100% of deals | 10% (`TOD_TIER_CARD_PCT`) |
  | Upgrade stations | unlimited uses | 3 each (`TOD_STATION_USES_PER`) |
  | Uplink hold-out | 20s | 90s (`TOD_FINALE_CHARGE_SECS`) |
  | Money | `dev_money_loop` keeps everyone rich | the real economy |
  | Damage | demigod — health floors at 1, never a down | downs and bleedouts live |

- The dev-flag comment block now carries that table inline, so the next session
  can see the ship deltas without tracing the readers again.
- **VERIFIED**: `node tools/lint_tod_arity.js` clean; BUILD OK; fresh
  `zm_tower_of_doom.ff` 88.16 MB; the DEPLOYED
  `usermaps/zm_tower_of_doom/scripts/zm/zm_tower_of_doom.gsc:299-300` reads
  `false` / `false` (the flag is compile-time, so the deployed copy is the thing
  that matters); errorlog = the 9 known-waived errors, nothing new.
- **NOT play-tested**: the REAVER (v9.20) has never been seen in a game, in any
  mode. It is gated behind the lap-20 breather door, so a short run will not
  reach it.

## 2026-08-22 (v9.21) — ENEMY SPAWN BANNERS REMOVED

(session bc1a80d8; `-GscOnly` build — GSC + Lua + zone, no geometry, no LED
bake. User: "Actually I want to remove all the announcement banners for the
enemies spawning in. Its unnecessary.")

- **THE WHOLE LANE IS GONE**, server to client to asset:
  - `_tod_bosses.gsc` — deleted `banner()` (already dead — defined, never
    called), `banner_notify_all()`, `boss_banner_show()`,
    `boss_banner_show_seq()`, the three call sites in `round_watch()`, and the
    `#precache( "eventstring", "tod_boss_banner" )`. The module no longer calls
    `LuiNotifyEvent` at all.
  - `_tod_reaver.gsc` — deleted `TOD_REAVER_BANNER_ID` and its
    `boss_banner_show` call. (It shipped one build ago in v9.20; net effect is
    that the Reaver never announced itself in a play session.)
  - `tod_upgrade.lua` — deleted the boss-banner `UIImage` + `UIText` elements,
    the id→art tables and the `"tod_boss_banner"` scriptNotify subscription,
    i.e. the entire v9.20 table rework, one build after writing it.
  - `zone` — dropped `image,i_tod_banner_panzer` and
    `image,i_tod_banner_protectors`.
- **KEPT, deliberately**: `i_tod_banner_choose_class` (the class draft) and
  `i_tod_banner_upgrade` (the upgrade event). Those are UI headers for menus the
  player opened, not enemy spawn captions. The `.tga` sources for the two dropped
  banners stay in the repo in case the call is ever reversed.
- **WHY IT IS SAFE TO HAVE NO CAPTION**: every enemy already announces itself
  diegetically, which is the map's existing doctrine (the same one that removed
  floaty kill text, boss-spawn text and the dev `IPrintLnBold`). The Panzer takes
  over the music channel; the Reaver arrives on a sky meteor visible floors away;
  the Protectors drop in with a slam, quake and rumble; and the HUD floor gauge
  already paints a red pip on the nearest live boss's floor cell. **Nothing about
  enemy legibility depended on the banner.**
- **STANDING RULE ADDED** (comment above `_tod_bosses::director` and in
  `docs/28`): do NOT re-add a banner lane for the remaining elites. If an enemy
  needs a tell, give it a sound or an FX, not a caption.
- **VERIFIED**: `node tools/lint_tod_arity.js` clean; a 4-lens adversarial audit
  (GSC structure / Lua structure / asset references / regression + intent) over
  the edited files; `-GscOnly` BUILD OK; fresh `.ff`; errorlog = the 9
  known-waived errors, nothing new.

## 2026-08-22 (v9.20) — NEW ELITE #1: THE REAVER (lap-20 breather unlock)

(session bc1a80d8; `-GscOnly` build — zone + GSC + Lua, no geometry, no LED
bake. Answers `docs/27_new_elites_research_brief.md`; full research report,
picks and specs in `docs/28_new_elites_research_and_design.md`. ONE ENEMY PER
BUILD — the Breacher and Bulwark are specified but NOT built.)

- **THE RESEARCH.** The brief asked what enemy AI this toolset can actually
  give us. Answer, measured off disk rather than remembered:
  `<TOOLS>\share\raw\behavior\` ships **eleven behaviour trees, total**. Two
  are already in use (`mechz*` = Panzer, `zod_robot_companion` = Rogue
  Protector), three are plain zombies/dogs, one (`zm_avogadro`) is a brain
  with no body — its BT/ASM/animtables/FX/sound CSV survive from map 1 but the
  Dick_Nixon character GDT is gone from `source_data`. That leaves
  **`zm_genesis_apothicon_fury` as the only fully-formed unused AI on the
  machine.** Margwa / thrasher / direwolf / clone / riotshield have
  `archetype_*.gsc` SCRIPTS in `share\raw` and nothing else — no BT, no ASM, no
  animtables, no character. RAPS and wasp are **vehicle** AI, not actor AI.
  Chomper and dragon GDTs declare xmodels only. So there is no out-of-the-box
  roster to raid: the Fury is the entire free lunch, and elites 2-3 have to be
  script-built on the zombie chassis.
- **THE REAVER** (`_tod_reaver.gsc`, NEW): an Apothicon Fury run as a tower
  ELITE, not a boss. Dormant until the **LAP 20 breather door** is bought —
  the first of the three reserved `_tod_doors::breather_unlock` slots to be
  filled. Cadence anchors to that round, then every **4th** round (dev: 2nd).
  Count `1 + players/2` (solo 1, quad 3), concurrency roof **3**, debt-drained
  one per director tick so the AI budget keeps feeding zombies.
  HP `boss_hp(round, 20, 20000, 1.08)` × `coop_hp_mult()` — solo r20 20k /
  r30 43k / r40 93k, i.e. between a Protector and a Panzer. Pays **400 pts**
  team-wide and **luck +6** to the last hit (`TOD_LUCK_REAVER`, new).
- **THE VERB — it erases distance.** Everything else on this map takes the
  stairs behind you; the Reaver BAMFS onto its enemy, 400–750u instantly, every
  ~4.5–6s. **The planned z-clamp was dropped as unnecessary**: reading
  `archetype_apothicon_fury.gsc:825` showed the bamf already demands mutual 50°
  FOV, both endpoints on the navmesh, a clear `TracePassedOnNavMesh` AND a
  successful `FindPath` — on a spiral that gates it by construction, because a
  player one flight up has no straight navmesh line. It cannot bamf through
  floors. Less code than planned, same outcome.
- **Entrance** = the pack's own `apothicon_fury_meteor_fx()` (sky meteor +
  ground tell, ~1.5s), deliberately NOT the tower's `drop_in()`: the archetype's
  client FX are authored around it, and on an open spiral the falling streak
  telegraphs from floors away.
- **Integration is the `is_boss` triad and nothing else.** `is_boss` /
  `acc_is_boss` / `acc_is_mini_boss` are set SYNCHRONOUSLY on the spawn frame
  (map 1's Shielded spawn-order race — the frame-N+1 `callback::on_ai_spawned`
  speed hook must already see them). Those three fields are what exempt it,
  with zero edits elsewhere, from all eight consumers: the zombie speed curve,
  SUPPRESSING FIRE, IMPACT ROUNDS splash, Thor's Thunder, the timewarp powerup,
  the powerup drop roll, the Electric Cherry stun and the zod landing splash.
  It also gets the floor-gauge boss pip for free.
- **Traps honoured** (each already paid for by the sister map):
  `ignore_enemy_count` set the same frame as the spawn, never in the threaded
  tune (the pack spawns it `is_zombie=1`); the HP set waits out the pack's
  threaded `apothicon_fury_health_init()` or its 1.2/1.5/1.7 round tier wins;
  `ignore_round_spawn_failsafe` against the stock 30s below-world culler; the
  vendored archetype keeps its `acc_bamf_ghost_failsafe` (an interrupted bamf
  otherwise strands it invisible AND unhittable forever).
- **Fixed a live single point of failure unrelated to this feature.**
  `<TOOLS>\share\raw\scripts\shared\ai\systems\animation_state_machine_utility.gsc`
  is HB21's **617-byte** override implementing `RequestState` /
  `SearchAnimationMap` (stock ships them as no-ops). **The PANZER already
  depends on it** and nothing in this repo carried it — a Mod Tools "verify"
  would have reverted the install copy and silently broken the Panzer. Now
  vendored at the stock path, where the usermap copy wins at compile.
- **Boss banner LUI was a two-enemy design.** `tod_upgrade.lua` selected art
  with `id == 1 and panzer or protectors`, so ANY id other than 1 drew the
  Protector banner — the new elite ids could not be added without mislabelling.
  Replaced with id→art **tables**, and the text element is now built always
  (not only in the no-art build), so an elite whose baked banner has not shipped
  yet announces in words instead of drawing a blank material. The Reaver ships
  on the text path ("REAVER INBOUND") until `i_tod_banner_reaver` art exists;
  adding an elite is now one row per table. The hide path still fades, and now
  fades BOTH elements so a text banner can never strand at alpha 1.
- **Zone**: `aitype,spawner_zm_genesis_apothicon_fury` (the `spawner_` form —
  the naming contract that cost map 1 a build), six vendored pack
  scriptparsetrees, the ASM-utility override, `_tod_reaver.gsc`, ten FX and the
  dissolve character. Two corrections vs the first draft of the plan: it
  proposed omitting `fx_apothicon_fury_spawn_in_exp` (a misread — map 1 zones
  it; what map 1 swapped off that FX was its unrelated PhD Flopper nova, and the
  pack's `.csc` `#precache`s it unconditionally, so omitting it would have been
  a dangling ref = fatal), and `fx_apothicon_fury_death` is added because the
  client archetype precaches it and map 1 never listed it. All ten verified
  present on disk before zoning.
- **VERIFIED**: `node tools/lint_tod_arity.js` clean (50 files); `-GscOnly`
  BUILD OK; **fresh `zm_tower_of_doom.ff` 88.21 MB** (was 84.14 MB at v9.19 —
  the +4 MB is the Fury asset set); **283** apothicon_fury rows in the packed
  assetinfo; errorlog = exactly the 9 known-waived errors, **zero** fury /
  reaver / ASM lines. NOT yet play-tested — test script in docs/28 §7.
- **CREDIT OWED BEFORE PUBLISH**: HarryBo21 (Apothicon Fury pack v1.1.0).

## 2026-08-22 (v9.19) — BOSS SPAWNS: Panzer near the HIGHEST player, Protectors near the LOWEST, drop-in entrances

(session f2e3ffc8; -GscOnly build, `_tod_bosses.gsc` only — no zone / GDT /
CSV / Lua / .map changes, no new assets. User: "the panzer spawns at the
bottom of the tower — he needs to spawn near the top-most player. Also the
protectors should spawn near the bottom-most player. The spawn-in
animations need to be implemented ... carefully, this could break the
map.")

- **THE REVIEW.** Both bosses were anchored to a BASE RING point
  (`base_spawn_origin`, user 2026-08-20 "bosses spawn at the bottom and
  climb") → `pick_spawn_point` (400u navmesh scatter, ≥100u from players,
  ≥150u from bosses, zone-gated) → bare `SpawnActor`. The Panzer popped in
  with no entrance at all; the Protector had a 3s ground-tell FX then
  popped in with landing FX/quake/kill-splash (no descent). The pack's own
  fly-in (`mechz_spiki::spawn_mechz(..., flyin=1)` →
  `scene::play("cin_zm_castle_mechz_entrance")`) needs `level.mechz_spawners`
  — a .map spawner, which crashes this map (bake AND load); the zod entrance
  scene spawns a duplicate frozen robot (map 1, live). So neither stock
  entrance is usable as-is.
- **ANCHORS** (`anchor_player(kind)`): PANZER → the living player with the
  HIGHEST origin z; PROTECTOR → the LOWEST (on the spiral, z is "how far up
  the climb"). Downed players are excluded (`is_player_valid`). Replaces
  the 2026-08-20 base-ring rule (`base_spawn_origin` removed). The
  anti-strand watchdog relocates by the same rule (a stalled Panzer goes
  back up to the highest player, a stalled Protector down to the lowest).
- **`pick_spawn_point` is two-pass now** (400u, then 800u): anchors are
  player positions on a narrow flight, and the old single pass fell
  straight through to "spawn on the player" when every near candidate was
  behind a closed door or inside the clearance rings. Zone gate + budget
  unchanged (per pass).
- **DROP-IN ENTRANCE for both** (`drop_in`, shared): the real actor is
  spawned and fully set up at the landing point, then **ghosted,
  `SetCanDamage(false)`, `ignoreall`, goal-pinned, anim rate 0.05** (the
  same freeze the upgrade pause uses); a `script_model` PROXY wearing
  `boss.model` + his attachments (`GetAttachSize/ModelName/TagName`) spawns
  up to 320u above (`drop_clearance` BulletTraces the clear air — the lap
  above is 384u up), rides the zod `robot_sky_trail` FX + the
  `fly_civil_protector_loop` hum, and `MoveTo`s down over 0.8s
  (accelerating) after a 2.0s ground-tell. On impact: proxy + trail
  deleted, `Show()`, damage back on, rate restored (left frozen if the
  upgrade pause began mid-fall — `boss_pause_watch` restores on the unpause
  edge), quake + `robot_landing` FX + `landing_kill_splash` + rumble. Under
  120u of clear air = no descent, just tell + slam. Returns false if the
  actor vanished mid-fall (pack-side Delete) — the caller treats it as a
  failed spawn, debt retained. Every driver thread (goal/retarget/hunt/fire/
  pause/stuck) starts AFTER the reveal. Panzer music starts at the tell so
  "Data Spike" hits with the slam. Ground tell is its own model/timer
  (`tell_fx`) — the vendored one retires on a LEVEL notify that a
  concurrent entrance would trip early. The Protector's old 3s
  `robot_landed` telegraph/abort path is gone with it.
- Known cosmetic limit: the proxy falls in the boss's idle pose (no
  jet-thruster anim) — a real flying anim needs the scene bundles above.

## 2026-08-22 (v9.18) — FIX: stock anti-cheat was confiscating the class gun; mystery box removed

(session e7dfdcb8; FULL build 84.16 MB @ 10:15:42 PM, BUILD OK, LED bake ran,
9 known-waived warnings, errorlog clean. User: "I just played with assault
class and i randomly lost my enfield ... I kept hearing the teddy bear tho.
Like when mystery box moves or you are OOB" / left holding "Only the pistol".)

- **ROOT CAUSE — stock `player_too_many_weapons_monitor`** (`_zm.gsc`, threaded
  on every player). Every 3s it counts primaries that are
  `is_weapon_included || is_weapon_upgraded`; above `get_player_weapon_limit()`
  (2 without Mule Kick) it runs the takeaway sequence:
  `playlocalsound( level.zmb_laugh_alias )` **twice**, then `SwitchToWeapon` +
  `TakeWeapon` on **EVERY** primary, a points penalty, and a fresh
  `pistol_standard`. That laugh is the "teddy bear" the user heard, and "only
  the pistol" is literally what the sequence leaves you holding.
- **Why it fired:** our twin / tier / PaP swaps are GIVE-before-TAKE by design
  (map 1 proven order), so the player legitimately holds a transient THIRD
  primary (pistol + base form + new form) for up to ~1s whenever
  `SwitchToWeaponImmediate` is eaten (mid-sprint / mid-raise / mid-reload /
  ADS) — and `player_choice_flow` unfreezes weapons ONE LINE before the swap,
  so mid-raise is the common case after every upgrade pick.
- **Why it only started now:** the monitor was INERT until v9.14. Without the
  `stringtable,gamedata/weapons/zm/zm_levelcommon_weapons.csv` zone line,
  `level.zombie_weapons` had no class-gun rows and the monitor list was always
  empty. The v9.14 roof-PaP fix armed the confiscation. Net: v9.14 fixed PaP
  and simultaneously handed the anti-cheat a reason to eat the class gun.
- **FIX:** `level.player_too_many_weapons_monitor = false;` in
  `zm_tower_of_doom.gsc::main()` right after `zm_usermap::main()` — this map
  OWNS the player inventory, and a public-matchmaking cheat detector has no
  business policing a swap we perform deliberately. Must stay off.
- **CLASS-GUN WATCHDOG** (`_tod_upgrades::body_systems_loop`, beside
  `reconcile_twin`): the class gun was only ever GIVEN at spawn, so ANY take
  stranded the player for the whole run (god mode removes the down/respawn
  re-give). Now, if no form of the class gun is in the inventory for 3
  consecutive ticks, it is re-given at the form the levels + PaP latch demand
  (falling back to the level-0 form). Gated on `tod_swap_busy` /
  `tod_tier_busy` / last stand / powerup gun so it never fights a swap.
- **MYSTERY BOX REMOVED** (user: "I also never asked you to include it in the
  map"). It was a scaffold placement in `gen_tower_map.js`. It was also a real
  latent hole: stock `zm_weapons::weapon_give` at the 2-primary limit takes the
  weapon you are HOLDING, so a box pull with the class gun out deleted it —
  and the class gun carries every upgrade, the tier ladder and the PaP state.
  (NOTE: the box was NOT what hit the user — that was the monitor above. The
  first diagnosis in this session wrongly blamed the box.)
- Adversarial hunt wf_5c99776e (3 lenses, 17 agents): 6 confirmed findings, all
  converging on the two fixes above; 1 refuted (`swap_primary` taking the old
  gun on the not-held path).

## 2026-08-22 (v9.17) — FIX: v9.16 would not load (2nd stock PaP zbarrier); breather PaP is now a script vendor

(session e7dfdcb8; FULL build 84.07 MB @ 4:13:11 PM, BUILD OK, LED bake clean,
9 known-waived warnings, errorlog free of PaP/script lines. User: "Map didnt
load.")

- **ROOT CAUSE OF THE v9.16 LOAD FAILURE (mine).** v9.16 placed 4 stock
  `vending_weapon_upgrade_spawnable` prefabs on the breathers = **5
  `zm_pack_a_punch` zbarriers**. Stock `_zm_pack_a_punch::spawn_init` renames
  EVERY such zbarrier to the shared `vending_packapunch`, then
  `vending_weapon_upgrade()` does a **SINGULAR `GetEnt("vending_packapunch")`,
  which errors with two or more → the map fatals at load**. There is NO
  build-time signal: the linker said BUILD OK, the bake passed, the errorlog
  was clean. **Map 1 had already paid for this exact lesson** (its CHANGELOG,
  "Working 2nd Pack-a-Punch in Paradise") — CLAUDE.md says not to re-learn
  those, and this one was re-learned the hard way.
- **REVERTED** the 4 prefabs from `gen_tower_map.js`; the regenerated .map is
  **byte-identical to the pre-v9.16 geometry** (diff-verified) and carries
  exactly ONE PaP zbarrier (the crown). A permanent warning comment sits where
  the block was so it is never re-added.
- **REIMPLEMENTED as a standalone script vendor** (map 1 pattern),
  `_tod_powerups.gsc::breather_pap_spawn`: per breather (floors 10/20/30/40) a
  `script_model` (`p7_zm_vending_packapunch_on`, assetlist-verified +
  precached) plus its own `trigger_radius_use` (`TriggerIgnoreTeam`,
  `HINT_NOICON`). It **never carries the `zm_pack_a_punch` targetname**, so
  stock singleton lookup — and the crown machine — are untouched. Cost 5000,
  gated on power / not-downed / not-already-packed / no powerup gun in hand.
  It packs by latching `player.tod_pap_owned` (the SAME lane `grab_pap` uses)
  and `reconcile_twin` swaps the class gun to its `_up` form within 1s — a
  direct call would be a circular `#using`.
- Placement: north edge of each balcony at `(-320,-470,z)`, trigger
  `(-320,-526,z)`, yaw 359.999 (faces south into the floor); ~236u from the
  upgrade-station trigger and ~286u+ from both perk pads. Deliberately NOT
  solid — the navmesh ignores entity collision (KB), so a solid machine on a
  small balcony would just be a grinding spot for the horde.
- Spawn is threaded from `__init__` (system registration, earlier than the tod
  `init()` chain), so it waits for `initial_blackscreen_passed` to **exist**
  before waiting on it.

## 2026-08-22 (v9.16) — CLASS TIER card was unreachable: Pack-a-Punch now on every breather

(session e7dfdcb8; FULL build — geometry + LED bake — 84.05 MB @ 3:54:07 PM,
BUILD OK, LED bake clean, 9 known-waived warnings. User: "I maxed out my
Enfield and was never able to upgrade my class." + "double check all your
work.")

- **ROOT CAUSE (adversarial trace wf_45d24361, two verifiers CONFIRMED).**
  The CLASS TIER card requires the class gun Pack-a-Punched
  (`tier_card_eligible`: `IsSubStr( w.name, "_up" )` OR `tod_pap_owned`), but
  the map had **exactly one PaP — in the crown hall, above all 50 laps** +
  crown stair/terrace/causeway (the finale). Upgrade cards never PaP (NO-TWIN
  rule). So a player who climbs and maxes the gun via cards holds an all-base
  form (`t5_enfield_r{lvl}`), eligibility is false every event, no tier card
  is ever dealt — until the apex, by which point the run is essentially over.
  The only in-climb PaP was the random `tod_pap` free drop. Exactly the
  reported symptom. This is a REACHABILITY gap, not a bug in the tier code.
- **FIX (user's call): a Pack-a-Punch on every breather balcony** (floors
  10/20/30/40), `gen_tower_map.js` — a separate emission pass after `entities`
  is initialized (the lap loop only builds world brushes; `prefab()` writes to
  `entities`, and both `entities` and `PERK_LOC` are out of scope there —
  hard-won: two TDZ crashes while wiring it). Placed on the inner strip at
  `(±448, ±620, mid)`, parity-mirrored like the balcony (all four breather
  FLOORS are even → SW side), 185u clear of the two perk-scatter pads (outer
  edge, y ±783) and the mid-landing walk-on; faces the arriving player. Stock
  `_zm_pack_a_punch::spawn_init` walks `GetEntArray("zm_pack_a_punch")` and
  gives EACH zbarrier its own use-trigger, so the 4 breather machines coexist
  with the crown one (5 total). Needs power (base switch), same as any PaP.
- **Why the stock machine now works on class guns** (it didn't before v9.14):
  `can_upgrade_weapon` gates on `level.zombie_weapons[rootWeapon].upgrade`,
  populated from `zm_levelcommon_weapons.csv` — which only reached the game
  once v9.14 added the `stringtable,` zone line. The Enfield rows
  (`t5_enfield_r0..r3 -> t5_enfield_up_r0..r3`) resolve; the pistol (also
  `in_box=FALSE`) already PaP'd, so the flag was never the blocker. `grab_pap`'s
  "never PaP'd the class guns" comment predates the stringtable fix and is now
  stale.
- **Review by-product:** the v9.14 regression lens (magsize/penetration class
  gates, the Widow's-Wine `slow()` guard, DRAW CUT, the sound-alias appends,
  the stringtable line, the 37 art blocks, the Lua flags) found **no surviving
  regression** — the v9.14 edits are clean.
- **Known nuance, not changed:** the TIER card is opt-in (right slot, a timeout
  never auto-takes it — user's "never auto-promote" rule). A maxed player is
  dealt it as the sole card; take it by HOLDING select (a timeout applies
  nothing). Left as designed; revisit if it reads as stuck.

## 2026-08-22 (v9.15) — TIRELESS SPRINT finally works: the meter is a CLIENT dvar

(session f2e3ffc8; -GscOnly build. User: "skirmisher should get unlimited
running with sprint lv 5 but it doesn't work still. We have tried to fix this
multiple times.")

- **ROOT CAUSE.** The sprint meter is predicted on the CLIENT from the
  client's own `player_sprintTime` dvar. Stock sets that dvar per client ONCE
  at connect, to the gametype's 4 s
  (`zm/gametypes/_globallogic_player.gsc:125`
  `self SetClientPlayerSprintTime( level.playerSprintTime )`). Every earlier
  fix — the specialty-only first cut, then the server-side
  `SetSprintDuration( 60 )` re-asserted each tick — set a value the client
  never reads, so the meter kept draining at 4 s. (Map 1's "The Flash"
  `SetSprintDuration( 6 )` was the same non-fix; it was later removed for
  design reasons, never diagnosed.) The official API doc
  (`docs_modtools/bo3_scriptapifunctions.htm`) lists the per-client setter:
  `<player> SetClientPlayerSprintTime(<time>)` — "Sets player_sprintTime dvar
  only on this client". Stock Stamin-Up touches neither knob (pure engine
  specialty).
- **FIX** (`_tod_upgrades.gsc`): `tireless_apply()` sets BOTH the server
  `SetSprintDuration` and `SetClientPlayerSprintTime` to
  `TOD_UPG_TIRELESS_SECS` (60 → **999**: ~16 min of continuous sprint, meter
  recharges — reads as unlimited); the staminup specialty stays. Latched on
  `tod_tireless_on`: applied once on grant, re-sent on every `spawned_player`
  (`tireless_spawn_watch`, insurance — stock only writes the dvar at
  connect), and **cleared the moment eligibility is lost** — the body loop's
  new else-branch (class switch at the station, tier-up level reset) and
  `reset_gun_state` both call `tireless_clear()`, which restores both sides
  to stock (client from `level.playerSprintTime`, fallback 4) and strips the
  specialty unless Stamin-Up was BOUGHT (`perks_active`). The old code had
  no un-apply path outside `reset_gun_state`. Still SKIRMISHER-ONLY.
- Docs: KB §5 entry (the two-knob rule), `upgrade_system.md` SPRINT line.

## 2026-08-22 (v9.14) — CLASS TIERS: tier art live, damage-only tier rule, review fixes, roof PaP FIXED

(session e7dfdcb8. -GscOnly **84.04 MB @ 2:23:20 PM**, BUILD OK, 9
known-waived warnings. Ledger 159 / 200 unchanged. 4-lens adversarial
review of v9.13 (wf_58349e16): 18 raw → 6 confirmed + 1 unverified-but-real
(the stringtable) all fixed here; 3 refuted; the UI lens and one verifier
died on an API safeguard, so the Lua contract was re-checked by hand while
wiring the art.)

- **TIER STEP = DAMAGE ONLY (user rule):** "the next tier gun should have
  the same DPS as the PaP version of the tier under … only touch the damage
  numbers, no other stats". `gen_tod_twins.js` `TIER_DPS = [1, 1.5625,
  2.4414]` (= PaP's +25% damage × +25% rate, squared for T3), applied to
  `damage` at the gun's OWN fire time; fire time / reload / recoil / clip
  floor untouched. v9.13 shipped `[1, 1.25, 1.5625]` (rate ignored) — every
  promotion was a DPS DOWNGRADE until re-PaP'd. Now: MP5 227→**284** (4057
  DPS vs MAC-10 PaP 4051), MP7 259→**405** (6328 vs MP5 PaP 6339), Krig
  250→**313** (3130 vs Enfield PaP 3125), AK-47 250→**391** (4888 vs Krig
  PaP 4888), HK21 495→**618** (5518 vs Stoner PaP 5517), Death Machine
  276→**431** (8620 vs HK21 PaP 8627). Clips unchanged (35/40/33/36/125/150).
- **ROOF PaP MACHINE NOW WORKS ON CLASS GUNS** (review finding, verified in
  the packed assetlist): the zone never had
  `stringtable,gamedata/weapons/zm/zm_levelcommon_weapons.csv`, so
  `custom_add_weapons`' TableLookup read the STOCK table out of
  zm_levelcommon.ff — no class-gun rows, `is_weapon_included()` false,
  `can_upgrade_weapon()` false. That is the "PaP'd the PISTOL fine but
  never the class guns" mystery `_tod_powerups.gsc` recorded. Map 1's zone
  line 1319 was the precedent. The free-PaP latch path is unchanged;
  `reconcile_twin`/`tier_card_eligible` already accept `_up` by name.
- **Review fixes (GSC):** MAG SIZE `class_keys` += skirmisher and
  PENETRATION += assault — `domain_available` is class AND gun, so the
  MP7's m-ladder and the AK-47's p-ladder (12 zoned forms) were unreachable;
  `gun_keys` still keeps them off the MAC-10/MP5/Enfield/Krig. SUPPRESSING
  FIRE `tod_zombie_speed::slow()`/`slow_expire()` now respect
  `under_anim_slow()` (an HK21 hit popped a Widow's Wine cocoon from 0.1×
  to 0.75× then FULL rate). DRAW CUT window: `_tod_uniques` also stamps
  `tod_sprint_seen_ms` (last poll that SAW sprinting) and the melee branch
  procs on `IsSprinting()` at impact OR seen ≤ 0.4s ago — covers all three
  engine orderings (stock `_challenges.gsc` hedges the same way).
- **Review fixes (sound):** `wpn_t5_gen_pap_flux_plr/npc` (Secondary of
  the Enfield + HK21 PaP tails) were never defined — the 2 "BO1 Common" rows
  from `Skye_BO1_Weapon_Common/README.txt` appended to `tod_ports.csv`;
  the Combat Knife's `wpn_t9_knife_swing_plr/npc` (8 rows, knife pack
  READ_ME 165-172, trailing comma stripped) appended to
  `tod_combat_knife.csv` — every knife swing was whoosh-less since
  08-20; the Stormbreaker's `fireaxe` whoosh (`wpn_melee_fireaxe_whoosh_*`,
  stock MP set, absent from ZM) pre-empted with 6 rows cloned from the
  Wakizashi swing aliases; `gen_tod_sounds.js` blanks a Secondary that
  names a `skipFire` family (14 dangling `wpn_t9_stoner63_trig_pull_*`
  refs gone). All verified in `zm_tower_of_doom.all.alias.sz`.
- **ART INSTALLED (docs/26, user drop `files (31).zip`):** 8 TIER cards
  (platinum frame, arabic-numeral medal), 7 unique trios (21), plates
  r24–r31, MAC-10 / ENFIELD class-card re-bakes — 39/39 at exact
  names/sizes, proofread clean. 37 `image.gdf` blocks (199 total) + zone
  lines; `USE_TIER_CARD_ART = true`, `CARD_SLUG[25..31]`,
  `PAUSE_PLATE_MAX = 31`. Assetlist: 37/37 packed.
- **Not acted on (nits):** `t9_streetsweeper` + `_up` still zoned but
  unreachable (2 ledger slots, `gen_tod_sounds.js` keeps its rows on
  purpose); the DM's `pap_flux` is referenced from the GDT (fine).
- Armory artifact rebuilt: fire time + rpm on every form, FIRE RATE /
  HANDLING ladders, a "promise check" table, v9.14 numbers.

## 2026-08-22 (v9.13) — CLASS TIERS Phase 2 + 3: all 8 tier guns + the 7 uniques are LIVE

(session e7dfdcb8; user: "go ahead and implement everything". ONE GUN PER
BUILD, each checked against the linker errorlog/assetlist: 2a MAC-10
1:22:02 PM → 2b Enfield 1:25:40 (the 1:24:26 build was superseded — see
below) → 2c HK21 1:26:59 → 2d MP7 1:28:38 → 2e AK-47 1:29:44 → 2f Death
Machine 1:33:42 → 2g Stormbreaker 1:35:50 → 2h Wakizashi 1:38:35 → Phase 3
uniques **75.96 MB @ 1:42:33 PM** = the build to test. Registration ledger
**159 / 200 guard** (163 `weapon,` lines packed incl. stock).)

- **THE LADDERS ARE REAL** (`_tod_classes.gsc` register_gun rows):
  SKIRMISHER **MAC-10 `t9_mac10` (f) → MP5 (f×h) → MP7 `t6_mp7` (m)**;
  ASSAULT **Enfield `t5_enfield` (r) → Krig 6 (r×m) → AK-47 `t9_ak47` (p)**;
  HEAVY **Stoner 63 (p) → HK21 `t5_hk21` (p) → Death Machine
  `t6_death_machine` (no ladder, `_b`)**; SLASHER **Combat Knife (k) →
  Wakizashi `t9_me_wakizashi` (k) → STORMBREAKER `leviathan` (k, arrives with
  THOR'S THUNDER Lv1)**. The draft now hands out the MAC-10 / Enfield;
  `tod_class_select.lua` labels + ladder strings updated. `gun_keys`: FIRE
  RATE mp5+mac10, RECOIL krig+enfield, MAG SIZE krig+mp7, PENETRATION
  stoner+hk21+ak47, KNIFE SPEED knife+wakizashi+leviathan, THUNDER leviathan.
- **Tier balance, as generated** (`gen_tod_twins.js` TIER_DPS / never-shrink
  clip): MP5 T2 160→**227** dmg, clip 30→35; Krig T2 195→**250**, clip
  25→**33** (the clip nerf is retired — `KRIG_CLIP = undefined`); MP7 T3
  **259**; HK21 T2 310→**495** @ 536 rpm, 125-rd; AK-47 T3 **250**, clip
  21→**36**; Death Machine T3 260→**276** @ 1200 rpm minigun, 150-rd;
  Wakizashi 20000/40000, Stormbreaker 40000/80000 (the port's 5000/20000
  overridden; pristine `acc-balance0709-orig` source: continuousFire 0,
  chargeRange 100, move 1.0). PaP = base +25% everywhere incl. `minDamage`
  (new — the ports' PaP falloff floors were arbitrary). Every gun: LOC_NORM
  3.0 head/helmet/neck, move 1.0, recoil ×1.15, ADS ×1.20; `altWeapon` blank
  on EVERY form (audited per build — see the Enfield incident).
- **THE ENFIELD INCIDENT (caught by the per-build audit):** the first 2b
  build (1:24:26 PM) left the Masterkey `altWeapon "t5_enfield_shotty_zm"` on
  the PaP variants — the generator's string overrides only ran on the base
  form. That is the exact map-1 boot-trap class (hard Com_ERROR at load).
  Fixed in `baseTune` (string overrides on every form), rebuilt 1:25:40,
  audit = 0 across all variants. Never shipped.
- **Ports:** Enfield + HK21 extracted from the user's `Skye_BO1_*.zip`
  (no-clobber); MAC-10 + MP7 were already installed byte-identical; the
  **Wakizashi** (pmr360's BOCW port, `BOCW Wakizashi.rar`) installed with its
  GDT vendored to `source_data/t9_weapons/melee/wpn_t9_me_wakizashi.gdt`
  (its shared GDTs are identical to the knife pack's — not re-copied). AK-47
  + Leviathan are generated from their pristine `.acc-*orig` backups (map 1
  had patched the live GDTs in place).
- **Sounds:** new `sound/aliases/tod_ports.csv` (+ `.szc` source) = the
  BO1/BO2 packs' README alias rows verbatim (HK21 27, Enfield 28, MP7 8),
  the Wakizashi's 8 wav-backed rows, and 10 HAND-AUTHORED loop-fire rows for
  the Death Machine (start/loop/stop plr+npc with `Looping`=LOOPING on the
  two loops, pap_flux, spin, tap — templated on the MP7 rows; the pack has
  no `_npc` start wav so that alias points at the `_plr` one). t9 guns
  (MAC-10, AK-47) via `gen_tod_sounds.js` (now has `enabled` per gun; the
  MAC-10's GDT basename has a hyphen — `GDT_OF` matters). Every referenced
  wav verified on disk. One build (2f) logged two "Object reference not set"
  sound-converter errors on unrelated, valid wavs; a no-change rebuild was
  clean and the packed banks were verified (sizes + written-before-ff) —
  a converter transient.
- **Waived:** `'knife_melee_surface'` in `build_map.ps1` — the Leviathan's
  stock fire-axe surface-sound defs are not in the gdtDB; map 1 shipped the
  same axe with the identical two lines (its CHANGELOG: "pre-existing pack
  noise"). The axe's swing/impact audio is the stock MP fire-axe set —
  verify in-game.
- **PHASE 3 — the 7 uniques** (`_tod_upgrades.gsc` add_domain 25..31, each
  `gun_keys`-bound to one gun; new `_tod_uniques.gsc` keeps
  `tod_fire_streak`/`tod_fire_last_ms` (per-shot `weapon_fired`, 500 ms gap
  ends a streak) and `tod_sprint_end_ms` (20 Hz IsSprinting poll) on the
  player): **ADRENALINE** (MP5, A, 3) kills stack a 4s speed burst
  +4/6/8% ×3 (`adren_bonus` in `apply_move_speed`); **OVERDRIVE** (MP7, S,
  3) +5/8/12% per 10 consecutive rounds ×5; **KILL RELOAD** (Krig, S, 3)
  kills refill 25/50/75% of the mag; **IMPACT ROUNDS** (AK-47, S, 3)
  10/20/30% of hits burst 40% of the hit into ≤6 zombies within 64u (cleave
  mark = no recursion, bosses exempt); **SUPPRESSING FIRE** (HK21, A, 3)
  hits slow 25/40/55% for 1.5s via a new `tod_zombie_speed::slow()` timed
  playback-rate multiplier the keep-alive sweep honours; **MEAT GRINDER**
  (Death Machine, S, 3) +2/3/4% per 5 consecutive rounds up to +50/75/100%,
  gone the moment the trigger rests; **DRAW CUT** (Wakizashi, S, 3) a swing
  within 0.4s of a sprint +50/100/150%. CHAIN LUNGE's landing hit now deals
  the HELD blade's damage (`tod_classes::melee_dmg`: knife 1700/20000,
  katana 20000/40000, Stormbreaker 40000/80000).
- **Art still outstanding** (prompts in docs/25 §10): 8 tier cards, 7
  unique card trios, plates r24–r31, the REQUIRED class-card re-bake (the
  draft now shows MAC-10 / Enfield). Everything renders on the text fallback
  meanwhile.

## 2026-08-22 (v9.12) — CLASS TIERS Phase 0 + 1: the tier card is LIVE (null ladder)

(session e7dfdcb8. Phase 0 shipped alone first: -GscOnly **73.89 MB @
11:46:44 AM** — the clientfield widening, boot-tested separately. Phase 1:
-GscOnly **73.92 MB @ 12:16:22 PM**, 7 known-waived warnings, gdtdb now
exits 0. Adversarially reviewed before the build (3 lenses + refute pass);
the review's substantive findings are in the tree: a refused/timed-out
TIER pick falls back to the OTHER card (round event and station — a buy is
never consumed for nothing), `tier_up` waits for an in-flight body-loop
swap and commits NOTHING (no reset, no tier, no latch) if the weapon swap
bails, deferred station cards are re-checked against `domain_available`
(a promotion can darken gun-bound cards), a maxed player's tier chance is
pre-rolled BEFORE the world pauses (no 90%-empty events), and the tireless
sprint METER always resets (only the specialty respects a bought
Stamin-Up). Pause-menu loop now scans the full 6-bit id range (1..63).)

- **ROSTER LOCKED (user 2026-08-22):** SKIRMISHER MAC-10 → MP5 → MP7;
  ASSAULT Enfield → Krig 6 → AK-47; HEAVY Stoner 63 → HK21 → Death Machine;
  SLASHER Combat Knife → katana/sword (port TBD) → STORMBREAKER (the
  installed Leviathan port). The T1 guns CHANGE (MAC-10, Enfield) — their
  builds come first in Phase 2. User decisions: body domains reset, keep both
  Death Machines (class gun + the powerup), tier steps never shrink the mag,
  Thor's Thunder is Stormbreaker-only (Lv1 granted on arrival).
- **PHASE 0 — clientuimodel widening** (`_tod_upgrade_ui.gsc/.csc`, lockstep):
  `todUpgAD`/`todUpgBD` 5 → **6 bits** (domain ids 1..63), paid for by the
  dead `todMagBonus` 7 → **1** (the mag pool died 2026-08-20; the field has
  read 0 since). 61 → **57** custom bits, order unchanged. `domain_id`
  24..31 reserved: 24 CLASS TIER, 25 ADRENALINE, 26 OVERDRIVE, 27 KILL
  RELOAD, 28 IMPACT ROUNDS, 29 SUPPRESSING FIRE, 30 MEAT GRINDER, 31 DRAW
  CUT. `tod_upgrade.lua` DOMAIN rows 24..31 (text fallback), `TIER_LADDER`
  names the promotion on the tier card from its level field
  (`(class-1)*2 + (tier-2)`), `USE_TIER_CARD_ART` flag (off until the 8
  `i_tod_card_tier_*` images land). Pause menu loop 1..23 → 1..31.
- **PHASE 1 — the system, on a NULL LADDER** (every tier = today's T1 gun, so
  the card / reset / swap / latch flow is proven with ZERO new assets):
  - `_tod_classes.gsc` REWRITTEN: `register_class` (identity only) +
    `register_gun( class, tier, stem, pap_suffix, axes, alt, grant )`; every
    "what gun does this player hold" question goes through `gun(player)` /
    `gun_stem` / `next_gun` / `base_weapon` / `tier` / `class_id`. The old
    class-level `c.primary`/`up_suffix`/`alt_primary` are gone (9 call sites
    migrated). `give_class_loadout` hands out the CURRENT tier's level-0
    variant (`_f0h0` / `_r0m0` / `_p0` / `_k0`, raw stem as fallback).
    Stem-prefix clash check at init (dev print).
  - `_tod_upgrades.gsc`: `twin_suffix()` is GENERIC (letter+level per
    registered axis; `_b` for an axis-less gun); `add_domain` rows carry
    `scope` ("class" = survives a tier-up: DMG REDUCTION + LUCK; everything
    else "gun") and `gun_keys` (rollable only while holding a listed stem —
    the twin ladders are bound to the guns that have them, **THOR'S THUNDER
    → `leviathan` only**, so it left the knife's pool this build).
    `domain_available` honours `gun_keys`. The swap is factored out of
    `reconcile_twin` into `swap_primary( old, want, fresh )` (the proven
    give → verify-switch → ammo → take-last order, +`tod_swap_busy` latch so
    the 1s body-loop walk can never start a second swap mid-flight).
  - **THE TIER CARD:** `tier_card_eligible` (below tier 3, next gun
    registered AND its level-0 asset linked, current gun PaP'd by `_up` name
    or the free-PaP latch, no powerup gun in hand); `roll_options` rolls
    `TOD_TIER_CARD_PCT` **10** (dev 100) ONCE per deal and puts the card in
    the **RIGHT** slot (or alone for a maxed player); `apply_upgrade` refuses
    a timed-out tier pick (opt-in only); `tier_up` resets every gun-scoped
    domain to 0 (syncs `(id,0,max)` so the pause list drops the rows),
    `reset_gun_state` un-applies tireless/lunge/thor/feed/bounty/scavenger
    state (never strips a BOUGHT Stamin-Up — `perks_active` check), tier++,
    **clears `tod_pap_owned`** (or reconcile would re-PaP the new gun
    instantly), swaps to the next gun's level-0 form with full start ammo,
    swaps alt weapons if they differ, applies the gun's `grant` domain at
    Lv1, re-syncs the pause list (CLASS TIER row = id 24, pips = tier) and
    plays the ULTIMATE sting. `player_has_upgrades_left` counts tier
    eligibility so a maxed player stays in events/stations for the chance.
    Station deals re-clamp a deferred tier card (`solo_refresh_option`:
    dead when downed or no longer eligible).
- **Ports installed** (from the user's Downloads, no-clobber): Skye BO1
  **Enfield** (`t5_enfield` / `t5_enfield_up_zm`; the PaP form's Masterkey
  `altWeapon` will be BLANKED by the generator — boot trap + parity) and BO1
  **HK21** (`t5_hk21`, 125-rd belt, `altWeapon` empty). MAC-10 + MP7 were
  already installed byte-identical.
- **gdtdb `/update` exit 1 EXPLAINED + FIXED:** three `entitysoundimpacts`
  blocks (`t9_melee_knife_lunge_impact_{npc,plr,vic}`) were defined in BOTH
  vendored knife GDTs (`t9_me_surfacesounddef.gdt` AND
  `wpn_t9_me_knife_combat.gdt`, byte-identical). Removed from the
  surfacesounddef copy. The WARN had been there since the knife landed
  2026-08-20 and was harmless — until a NEW gun's GDT failed to register.

## 2026-08-22 (v9.11) — CLASS TIERS: design doc only (no code, no build)

(session e7dfdcb8; DESIGN ONLY — nothing built, nothing in the tree changed
except `docs/25_class_tiers_design.md` and this entry.)

- **NEW DESIGN: CLASS TIERS** (user 2026-08-22): once the class gun is PaP'd,
  every card deal has a 10% chance to show a TIER card (right slot, never
  auto-locked on timeout) that promotes the class to the next of 3 tiers — a
  NEW gun whose base ≈ the old gun's PaP form (`TIER_DPS` 1 / 1.25 / 1.5625
  via damage normalization in the generator), every GUN-scoped domain reset
  to 0, DMG REDUCTION + LUCK kept. Per-gun unique upgrades ride a new
  `gun_keys` gate on `add_domain`; Thor's Thunder leaves the knife pool and
  becomes the STORMBREAKER transform's exclusive (Combat Axe → Leviathan port,
  which IS installed under `<tools>\_custom\wetegg\`).
- Measured constraints the plan sits inside: weapon ledger **97 / 230**
  (design adds 64 → 161, generator guard at 200); clientuimodel **61 bits**
  (domain-id fields 5→6 bits paid for by shrinking the dead `todMagBonus`
  7→1 — Phase 0, its own build); no combat-axe port exists on the box (user
  sources one, or T2 = the Leviathan itself).
- Roster proposal: SKIRMISHER MP5 → MAC-10 → PPSh-41 drum; ASSAULT Krig 6 →
  AK-47 → Galil; HEAVY Stoner 63 → RPD → Death Machine; SLASHER Combat Knife
  → Combat Axe (⟶ Stormbreaker) → Apothicon Sword (feasibility spike).
  Domain ids reserved **24 CLASS TIER … 32 REND** (append-only; 24 is next
  free as of v9.8). Image prompts (8 tier cards, 8 unique sets, plates
  r24–r32) are in the doc §10. Decisions for the user in §12.

## 2026-08-22 (v9.10) — SCAVENGER rebuilt as a kill ladder, louder clink; boss track intro trimmed

- **SCAVENGER IS NOW A KILL COUNTER, ONE ROUND AT A TIME** (user: "it
  sometimes gives me 4 bullets on one shot. This is way too much ... max 1
  bullet back on one shot ... 1 bullet every N kills, slowly goes down, 2
  kills is the most it'll go ... start at 1 bullet every 7 kills"). Why 4:
  the old rate was a FRACTIONAL bank, 0.25 rounds per kill per level — at
  Lv6 that is 1.5 rounds PER KILL, and a penetrating shot that kills 3 lands
  4.5 -> 4 rounds in one frame. Replaced in `_tod_upgrades.gsc`
  (`on_class_gun_kill`):
  - `TOD_SCAV_KILLS_LV1` 7 / `TOD_SCAV_KILLS_MIN` 2: kills per refunded
    round = `7 - (lvl-1)`, floored at 2 → **Lv1 7 / Lv2 6 / Lv3 5 / Lv4 4 /
    Lv5 3 / Lv6 2**. Only ASSAULT (the one class with the Lv6 cap) reaches
    the 2-kill ceiling; skirmisher/heavy top out at 3 kills per round.
  - **Never more than ONE round per shot**: penetration / echo multi-kills
    deliver several kill callbacks in the same server frame, so a payout
    latches `GetTime()` and later kills that frame only COUNT. Past the
    threshold the counter is held at `need-1` ("one kill away") — a 10-kill
    shot is one round now and one on the next kill, never a stack.
  - Counter `tod_scav_kills` survives level-ups (the threshold just shrinks
    under it). `tod_reserve_bank` / `TOD_UPG_RESERVE_PER_LVL` are gone.
  - Desc strings updated (GSC card, `tod_upgrade.lua`, armory, docs).
- **SCAVENGER CLINK AUDIBLE** (user: "I can barely hear the SFX"). The wav
  already peaks at -0.5 dBFS — no headroom in the file — so the quietness
  was the alias: `tod_scavenger` VolMin/Max **62 -> 92** in `tod_ui.csv`
  (every other UI cue sits at 80-96). Also cut the wav's dead tail: the
  clink is ~370 ms but the file ran 945 ms (575 ms of silence), which is what
  forced the 1100 ms sound throttle. File is now 500 ms (30 ms fade-out),
  `TOD_SCAV_SND_GAP_MS` 1100 -> 600 — feedback keeps up with a Lv6 train.
- **BOSS TRACK INTRO TRIMMED** (user: "a lot of empty air and the panzer is
  already walking around"). "Data Spike" opened with 4.5 s of low pad before
  the first hit; `boss_track_start` fires the instant the Panzer spawns, so
  he walked for 4.5 s in near-silence. `tod_boss_music.wav` now starts
  4.490 s in (10 ms fade-in, first hit lands at +25 ms): 206.05 -> 201.56 s,
  still 48k/16-bit stereo. The loop seam also improves — the track now wraps
  from its outro straight into the hit instead of the pad. Reproduce from
  the source track with
  `ffmpeg -i in.wav -af "atrim=start=4.490,asetpts=PTS-STARTPTS,afade=t=in:st=0:d=0.010" -ar 48000 -ac 2 -sample_fmt s16 out.wav`.

## 2026-08-22 (v9.9) — SLASHER pass: Thor's Thunder x2.5 cooldown + victim cap, CHAIN LUNGE rewritten

(session 323a3d8e; shipped in b7's foreground -GscOnly build at the user's
"build" instruction, alongside b7's Gift of Death GDT timing fix + the new
Scavenger reload sound and 8e's Panzer HP change — credit below.)

- **THOR'S THUNDER PROCS x2.5 LESS OFTEN** (user: "procs way too often —
  double that time ... tempted to say 2.5x"). The cooldown is a 3-constant
  ramp (`MAX - (lvl-1)*STEP`, clamped at `MIN`), so ALL THREE scaled or the
  floor would swallow the nerf at Lv4-5: `TOD_THOR_CD_MAX_MS` 1500 -> 3750,
  `STEP` 250 -> 625, `MIN` 500 -> 1250. Per level: 3750 / 3125 / 2500 / 1875
  / 1250 ms (was 1500..500). The Infinite Ammo no-cooldown bypass (user
  2026-08-21) is untouched.
- **THOR HITS A LIMITED NUMBER OF ZOMBIES** (user: "it just kills everything
  in that radius — limited amount, increasing with level"): `thor_strike`
  now gathers every live non-boss in radius and shocks only the NEAREST
  `2 + (lvl-1)` of them — Lv1 2 / Lv2 3 / Lv3 4 / Lv4 5 / Lv5 6
  (`TOD_THOR_MAX_HIT_BASE/PER_LV`; a `used[]` mask, no array-shrink
  reliance). Desc strings updated (GSC + Lua).
- **CHAIN LUNGE REWRITTEN** (user: "doesn't work"). Three independent faults
  in the first cut, all fixed in `_tod_lunge.gsc`:
  1. INPUT — the combat knife is the Slasher's PRIMARY, so "knife again" is
     the FIRE button; the old loop edge-detected only `MeleeButtonPressed()`.
     Now a swing = rising edge of `AttackButtonPressed() || MeleeButtonPressed()
     || IsMeleeing()`, with a 120 ms grace so the killing swing's own press
     never counts.
  2. FLIGHT — one `SetVelocity` with a 40u z-pop died in a frame (the
     movement code rewrites a grounded player's velocity every frame — map
     1's `_acc_movement` finding). Now a real hop (`Z_POP` 120) and the
     horizontal velocity is RE-AIMED at the moving target every 50 ms until
     arrival: a homing dash.
  3. LANDING — reliable arrival (90u) and the momentum is killed so you stop
     ON the zombie; the hit is the stock 8-arg
     `DoDamage(dmg, org, attacker, inflictor, "none", "MOD_MELEE", 0, knife)`
     (`_zm_ai_wasp.gsc:1309`) so CLEAVE/THOR/LEECH/BOUNTY fire and the kill
     credit re-opens the window. Added: same-flight-only targeting (|dz| <=
     96 — never a lunge onto another lap), the scatter's `tod_warp` whoosh as
     the tell. Adversarially verified (3 lenses) before shipping — see the
     follow-up bullets if any fixes landed.
- Credit: "Panzer HP 25k @ r5, x1.09/round (was 24k @ 1.075) — user
  2026-08-22, session 09c3" (`_tod_bosses.gsc` TOD_PANZER_HP_BASE/EXP).

## 2026-08-22 (v9.8) — SCAVENGER card art: the set is COMPLETE

(session 0b53d4a2; -GscOnly foreground **73.89 MB @ 1:25:25 AM**.)

- SCAVENGER (domain 8) card set + pause plate re-baked with the NEW name, from
  user drop files (29).zip. Verified before install — the card reads
  "SCAVENGER" / "AMMO BACK ON KILLS" with an ammo-pouch-and-return-arrow icon.
- **Installed as a PURE PNG OVERWRITE** — `i_tod_card_reserve_*` and
  `i_tod_pause_r08` are the pre-existing filenames (kept deliberately when the
  display string was renamed in v9.5), so NO GDT blocks, NO zone lines, NO
  CARD_SLUG[8], NO PAUSE_PLATE_MAX change. Verified after: still 3 reserve card
  blocks + 1 r08 block in both the GDT and the zone — nothing duplicated.
- **ART SET COMPLETE: all 23 domains have correct card art and pause plates.**
  CARD_SLUG covers 1..23 with no holes; PAUSE_PLATE_MAX 23; next free domain
  id is **24**.
- THE RULE that kept three sessions out of trouble across five art builds
  tonight, worth keeping: **an EXISTING filename is a PNG overwrite and
  nothing else; a NEW filename needs GDT block + zone line + CARD_SLUG (and
  PAUSE_PLATE_MAX only if its own rNN plate shipped in the same drop).**

## 2026-08-22 (v9.6) — CHAIN LUNGE card art

(session 09c3/8e installed + built; -GscOnly **73.10 MB @ 12:29:39 AM**,
+0.85 MB = the 4 new images. Verified independently by 0b53d4a2: 4 GDT blocks,
4 zone lines, `CARD_SLUG[22]="chain_lunge"`, `PAUSE_PLATE_MAX` 21 -> 22.)

- CHAIN LUNGE (domain 22) now renders REAL card art + a pause plate instead of
  the text fallback: `i_tod_card_chain_lunge_{regular,super,ultimate}` (768x1152)
  + `i_tod_pause_r22` (300x44), from user drop files (27).zip.
- **No duplicate wiring** — files (27) contained no SCAVENGER re-bake, and the
  reserve assets were left alone (still 3 card blocks + 1 r08 block, not
  doubled). Worth keeping as the pattern: a re-bake at an EXISTING filename is
  a pure PNG overwrite; only NEW filenames get GDT blocks + zone lines +
  CARD_SLUG.
- ART STATUS — **the card set is now COMPLETE: all 23 domains have baked card
  art and a pause plate** (RUN AND GUN landed right after, session 47, .ff
  73.84 MB @ 12:34:34 AM; verified: 4 GDT blocks, 4 zone lines,
  `CARD_SLUG[23]`, `PAUSE_PLATE_MAX` 23; CARD_SLUG covers 1..23 with no gaps).
  The ONE remaining cosmetic gap is that **domain 8's art still READS
  "RESERVE"** — the card renders fine, it just shows the pre-rename name until
  the re-bake lands as a PNG overwrite at the existing filenames.
  Verified across all three art builds that the reserve assets were never
  duplicated (still 3 card blocks + 1 r08 block).

## 2026-08-22 (v9.5) — card art drop + RESERVE renamed to SCAVENGER

(session 0b53d4a2; -GscOnly foreground build **72.25 MB @ 12:25:07 AM** — up
from 71.42, the jump being the 4 new image assets. Single build, three
sessions' work, no watcher.)

- **RESERVE renamed -> SCAVENGER** (user 2026-08-22: "Reserve doesn't make
  sense"). It never raised reserve CAPACITY — it refunds ammo off kills — so
  the name promised the wrong thing, and it collided conceptually with the
  S-tier capacity upgrade that got held on the twin ceiling (v9.3).
  **DISPLAY STRING ONLY: the internal key stays `"reserve"`**, so `domain_id`
  8, `CARD_SLUG[8]`, and every existing image filename are untouched — the
  rename cost zero wiring. Desc now "kills refund ammo: +1 per 4 kills / Lv".
  KNOWN COSMETIC GAP: the card art + pause plate still read "RESERVE" until a
  re-bake lands at the same filenames (`i_tod_card_reserve_*`,
  `i_tod_pause_r08`); prompt sent, drop-in when it arrives.
- **CLEAVE + BULLET FEED cards re-baked** (this session, from user drop
  files (26).zip): their baked text quoted the pre-v8.9 numbers. Verified the
  new renders before install — cleave now reads "33% CHANCE PER LEVEL",
  bullet feed "2.0s TO 0.4s PER ROUND". Same filenames = zero wiring; the six
  PNGs were already zoned + in the GDT. Old art backed up to the scratchpad.
- **SPRINT FIRE card set + r21 pause plate installed** (session 09c3/8e):
  4 image.gdf blocks appended to `tod_ui_images.gdt` (154 image blocks now),
  4 `image,` zone lines, `CARD_SLUG[21]="sprint_fire"`, `PAUSE_PLATE_MAX`
  20 -> 21. So domain 21 now renders REAL card art instead of the text
  fallback.
- Still on the text fallback (art outstanding): 22 CHAIN LUNGE,
  23 RUN AND GUN. Both play fine — the PaintCard `else` branch (v9.0) carries
  them.

## 2026-08-22 (v9.4) — RUN AND GUN: the Skirmisher's ammo saver (domain 23)

(session 323a3d8e; -GscOnly foreground build, single builder / no watcher.)

- **NEW SKIRMISHER DOMAIN — RUN AND GUN** (user: "if you shoot while you run
  you take up less bullets — 3 levels"). New module `_tod_runandgun.gsc`: a
  per-player `weapon_fired` watcher; every CLASS-GUN shot fired while
  RUNNING (`IsSprinting()` OR 2D speed >= 120 u/s — so it pays out on plain
  running and merely stacks with SPRINT FIRE, never depends on it) has a
  **20 / 35 / 50 %** chance to cost nothing: the round goes straight back
  into the mag (`SetWeaponAmmoClip`, capped at `weapon.clipSize`, so MAG
  SIZE twins are honoured). Standing still or ADS-creeping pays full price;
  the pistol and the wonder weapon always pay.
- Wiring: `add_domain("runandgun", ... 3, skirmisher, TOD_TIER_B)` (the
  ammo-economy band, with RESERVE / BULLET FEED), **id 23** in
  `_tod_upgrade_ui::domain_id` + `tod_upgrade.lua DOMAIN[23]` (22 is CHAIN
  LUNGE — ids are APPEND-ONLY), `tod_runandgun::init()` from `_tod_main`,
  zone `scriptparsetree`, pause-menu loop 1..23. **No `CARD_SLUG[23]` yet** —
  the card renders via the composite text fallback until
  `i_tod_card_run_and_gun_{regular,super,ultimate}` + `i_tod_pause_r23` are
  installed AND zoned (prompts delivered to the user). `lint_tod_arity`: OK
  across 46 files.
- **ART LANDED** (user drop `files (28).zip`, same day): the three RUN AND
  GUN cards (768x1152) + `i_tod_pause_r23` (300x44) installed to
  `source_data/tod_ui_images/_images`, 4 `image.gdf` blocks appended to
  `tod_ui_images.gdt`, 4 `image,` zone lines, `CARD_SLUG[23] = "run_and_gun"`,
  `PAUSE_PLATE_MAX` 22 -> 23. Visually QA'd against the CLEAVE set: frame,
  plate, medal, ribbon and pip colours per rarity all match. Second -GscOnly
  build.

## 2026-08-22 (v9.3) — RESERVE opened up (per-class caps), HEADSHOT nerfed

(session 0b53d4a2; NOT separately built — these edits were already in the tree
when session 8e linked at 00:11:25, and the DEPLOYED script was verified to
carry them: domain_max/bonus_class count matches the repo and HS_PER_LVL reads
0.04. One build covers this and CHAIN LUNGE.)

- **RESERVE keeps the ammo-back-on-kills mechanic and opens to every gun
  class** (user 2026-08-22, after the twin-ceiling hold: "we have to keep our
  reserve system. So keep it level 5 for all gun classes and assault can go to
  level 6"). Was assault-only max 5 -> now
  `array("skirmisher","assault","heavy")` max 5, ASSAULT reaching 6. Slasher
  excluded: a knife has no reserve to refund.
- **NEW MECHANISM — per-class level caps.** `add_domain()` gained two optional
  trailing args after tier: `bonus_class`, `bonus_max`. `domain_max(player,d)`
  resolves the cap for a given player. **RULE: in any per-player context read
  `domain_max(player,d)`, NEVER `d.max`** — otherwise the bonus class silently
  loses its extra level. All four call sites converted: `roll_options`,
  `player_has_upgrades_left`, `make_option` (o.max + the level clamp) and
  `refresh_upgrade_list` (the pause sync). `apply_upgrade` and
  `solo_refresh_option` already read `o.max`, so they inherit it.
- **HEADSHOT nerfed +10% -> +4% per level** (user: "head shot for krig needs to
  be nerfed to 4% not 10% each level"). `TOD_UPG_HS_PER_LVL` 0.10 -> 0.04, so
  Lv10 is +40% not +100%, on top of the now-flat x3.0 base multiplier. Domain
  desc + tod_upgrade.lua DOMAIN[6] updated to match.
- Sprint Fire (21) now actually appears in the pause-menu list — 8e's loop bump
  to `1, 22` (PAUSE_PLATE_MAX left at 20 so 21/22 take the text path) closed a
  gap this session introduced when it added domain 21 without touching the cap.
- **DOMAIN ID REGISTER (three sessions are appending here — check before you
  claim one):** 21 = SPRINT FIRE, 22 = CHAIN LUNGE, 23 = RUN AND GUN, 24 = next free.

## 2026-08-22 (v9.2) — CHAIN LUNGE (slasher upgrade, domain 22)

(session 09c3; -GscOnly build. Was "DEFERRED, logged" in v8.9 / armory.html.)

- **CHAIN LUNGE** — new SLASHER domain (id 22, 5 Lv, tier S), its own module
  `_tod_lunge.gsc`: a knife kill opens a LUNGE WINDOW (1.5s +0.25s/Lv);
  press melee again with a zombie in front (60° cone) and in reach (220u
  +60u/Lv) and you are launched onto it (`SetVelocity`, speed = gap×4 clamped
  700–1400 u/s + a 40u lift so friction cannot eat it — map 1's rocket-shield
  slide-kick idiom). On arrival (≤80u, ≤0.7s flight) the blade lands as a
  REAL knife hit: `DoDamage(20000, …, "MOD_MELEE", knife)` so DAMAGE /
  CLEAVE / THOR / LEECH / BOUNTY all fire as for a swing and the kill
  re-opens the window — chain indefinitely while targets remain. Melee input
  is EDGE-detected so the killing press can't double as the lunge. Bosses,
  frozen (upgrade-pause) zombies and non-zombies are never targets; no lunge
  while downed / menu-frozen / world-paused.
- Wiring: `on_class_gun_kill` → `tod_lunge::open_window(lvl)` (level handed
  in — the module never imports _tod_upgrades, KB cycle rule);
  `_tod_upgrade_ui::domain_id` 22; `tod_upgrade.lua` DOMAIN[22] (composite
  text until `i_tod_card_chain_lunge_*` land — CARD_SLUG[22] deliberately
  NOT added yet); pause-list loop 1..20 → 1..22 so SPRINT FIRE (21) and
  CHAIN LUNGE rows finally appear (as text; PAUSE_PLATE_MAX stays 20 until
  r21/r22 plates exist); zone scriptparsetree line; `tod_main::init` threads
  `tod_lunge::init`.

## 2026-08-22 (v9.1) — hit multipliers normalized, PaP 25%, Sprint Fire SMG-only

(session 0b53d4a2; -GscOnly foreground build 71.38 MB @ 11:59:17 PM, single
builder / no watcher.)

- **HIT-LOCATION MULTIPLIERS NORMALIZED ACROSS THE ROSTER** — new STANDING
  RULE (user: "headshot multiplier needs to be 3x for all guns. This can't be
  different. Class upgrades can make them different but base 3x is what we
  need. **No guns should vary unless I explicitly say so**"). New `LOC_NORM`
  in `gen_tod_twins.js` pins locHead / locHelmet / locNeck to **3.0** and
  locTorsoUpper to **1**, on base AND PaP forms, for all four weapons.
  The sweep (all `loc*` fields, not just locHead) caught FOUR violations:
    * locHead   mp5 3.0 | krig **6.0** | stoner **5.0** | knife **1.4**
    * locHelmet mirrored locHead, so armoured zombies varied identically
    * locNeck   3.0 / **4.0** / **4.0** / 1.0
    * locTorsoUpper — the **MP5's `_up` form ALONE** carried **2.0**, a secret
      double-damage chest zone on PaP that its own base form did not have.
  Consequence: the Krig's headshot drops 1170 -> 585 at base (it was carrying
  a x6 nobody asked for). Hit multipliers are now COPIED not scaled into PaP
  (`PAP_COPY_KEYS`), so PaP can never out-multiply its own base again.
- **PACK-A-PUNCH 15% -> 25%** (user: "PaP needs to give 25% increase across the
  board. Not 15%."): `PAP_UP` 1.25 / `PAP_FAST` 1/1.25 / `PAP_TRIM` 0.75.
  Verified base->PaP ratios: damage & clip x1.25, fireTime x0.80 (= +25% rpm),
  reload/ADS/recoil x0.75. Knife meleeDamage still exempt (20000).
- **SPRINT FIRE narrowed to SKIRMISHER ONLY** (user: "sprint fire is only for
  smg class upgrades") — was skirmisher/assault/heavy for one build. Still an
  earned card (max 1, tier A), just SMG-gated again.
- **HELD: the RESERVE split** (user asked for ammo-on-kills + a separate S-tier
  capacity upgrade with real twins, 3 levels / assault 4, all gun classes).
  NOT BUILT — the matrix math blows the engine ceiling: a 5-value reserve axis
  is a CROSS PRODUCT, so MP5 fire(4) x handling(4) x reserve(5) = 80/form and
  the roster lands at **362 twins** against map 1's measured **230 good / 368
  boot access-violation** (docs/21 §A). Options priced for the user: script
  virtual-ammo pool (full spec, 0 twins), real twins at 2 levels (222), or
  real twins 4 levels assault-only (210). User: "we can hold on this then."

## 2026-08-21 (v9.0) — SPRINT FIRE is an upgrade, not a class innate

(session 0b53d4a2; -GscOnly foreground build 71.38 MB @ 11:53:02 PM, single
builder / no watcher. Held the build while the game was open rather than
arming a watcher — see the v8.7 self-collision note.)

- **SPRINT FIRE promoted to an earned upgrade** (user 2026-08-21: "fire while
  sprinting is an upgrade. This needs to be changed. It's not just part of the
  class"). Was 8e's skirmisher INNATE — `body_systems_loop` granted
  `specialty_sprintfire` on `c.key == "skirmisher"`. Now gated on
  `get_level(self,"sprintfire") > 0`, registered as domain **21**
  (`add_domain("sprintfire","SPRINT FIRE","fire your weapon while sprinting",
  1, [skirmisher/assault/heavy], TOD_TIER_A)`). BINARY (max 1) — the engine
  specialty is on/off, so a SUPER/ULTIMATE roll still just grants the level.
  Slasher excluded (melee primary). `domain_id` 21 (5-bit field caps at 31 —
  room left), `DOMAIN[21]` in tod_upgrade.lua. The unset branch now MATTERS:
  a player without the card must never keep the specialty.
- **PaintCard no-art fallback** (bug found doing the above): with the baked
  card set on, a domain with no `art.cards[id]` entry left the CardImg
  element showing the **previous card's image** — silently the wrong upgrade.
  Added the `else` branch: hide the image, render the composite text stack
  (name/desc/rarity tag) instead. Any future domain can now ship before its
  art. `CARD_SLUG[21]` deliberately NOT added yet — RegisterImage of a
  missing image is undefined behavior; it goes in when the PNGs land.
- **Class-select copy fix**: the SKIRMISHER card still advertised "fires while
  sprinting", now false — changed to "fastest fire rate + speed".
- **Art prompts sent** for i_tod_card_sprint_fire_{regular,super,ultimate}
  (768x1152) + i_tod_pause_r21 (300x44), plus CLEAVE and BULLET FEED card
  re-bakes (their baked text quotes the pre-v8.9 numbers). Session 8e owns
  install + wiring. NOTE: 8e and this session both sent SPRINT FIRE prompts
  before the hand-off settled — same filenames, so either set drops in.
- `docs/armory.html` + the artifact updated (the user reads the LOCAL file —
  the artifact URL does not load for them; keep docs/armory.html current).

## 2026-08-21 (v8.9) — PaP = base+15%, S/A/B upgrade tiers, cleave nerf, feed buff

(session 0b53d4a2; -GscOnly foreground build 71.39 MB @ 11:41:35 PM, single
builder / no watcher.)

- **PACK-A-PUNCH IS NOW GENERATED AS BASE +15% ACROSS THE BOARD** (user: "the
  pap version of each gun should be a 15% buff across the board ... a 15%
  increase on every gdt stat"). `gen_tod_twins.js` grew a PaP machinery
  (`computePapSet`/`papApply`): each gun's `_up` form now derives EVERY tuned
  stat from the TUNED BASE form — damage/clip x1.15, fire time /1.15 (+15%
  rpm), reload/swap/ADS/recoil x0.85, reserve MAGAZINES copied (reserve rounds
  still grow with the clip), moveSpeedScale pinned 1.0. The Skye ports' own
  PaP stats and the hand-tuned Stoner PaP overrides (`STONER_PAP_DMG/CLIP/
  MAGS`) are retired.
  **CONSEQUENCE, FLAGGED TO THE USER:** the ports shipped PaP at ~1.7x base
  damage; the uniform rule is 1.15x, so PaP damage DROPPED — MP5 280->184,
  Krig 330->224, Stoner 345->305. Knob to revisit = `PAP_UP`.
  **KNIFE EXEMPTION:** `PAP_EXEMPT` keeps meleeDamage at the authored 20000
  (base 1700). A flat +15% = 1955 would stop the Slasher one-shotting around
  round ~18 and gut the class; its timing stats DO follow the rule.
  Also fixed: `isUp` was `/_up$/`, which missed the knife's `_up_zm` tail —
  the entire knife PaP form had been silently un-tuned.
- **UPGRADE TIERS S/A/B** (user: "add a rarity on each upgrade ... which
  upgrades can make you OP — we want those to be S"). `add_domain()` takes a
  tier; it gates TWICE: draw weight (S 20 / A 50 / B 100 — S is offered 1/5 as
  often, via the new `weighted_draw()` replacing the flat `array::randomize`)
  AND a rarity gate (`tier_rarity_factor` shrinks the SUPER+ULTIMATE slice
  x0.50 for S, x0.75 for A), so a stacked S+ULTIMATE is the rarest event in
  the game — 2.5% at empty luck, 7.5% on a full bar.
  S = DAMAGE, DMG REDUCTION, LUCK, ECHO ROUNDS, THOR'S THUNDER, CLEAVE.
  A = SPRINT, MOBILITY, HEADSHOT, MAG SIZE, FIRE RATE, KNIFE SPEED, REGEN,
  LEECH, PENETRATION.  B = BOUNTY, RESERVE, BULLET FEED, HANDLING, RECOIL.
- **CLEAVE nerfed to a CHANCE ladder** (user: "33% chance each level ... 3
  enemies max, so 6 max levels"): was a guaranteed +1 target/Lv to 5 (6
  targets). Now +33%/Lv, every 3 levels banking one guaranteed extra —
  Lv1 33%, Lv2 67%, Lv3 always +1, Lv4 +1&33%, Lv5 +1&67%, Lv6 always +2.
  Max 6, hard cap +2 extras (3 zombies/swing).
- **BULLET FEED buffed** (user: "starts at 2s then improves linearly all the
  way to 0.4s"): `TOD_UPG_FEED_BASE_SECS` 3.0->2.0, `STEP` 0.25->0.1778,
  `MIN` 0.25->0.4 — Lv1 2.0s/round, linear to exactly 0.4s at Lv10.
- **DIAGNOSED the "Krig hits way harder than the MP5" report** (user item 1,
  no code change): it is `locHead`, the per-gun HEADSHOT MULTIPLIER, which the
  old armory table never showed — MP5 **x3.0**, Stoner x5.0, Krig **x6.0**.
  Headshot damage: MP5 480, Krig 1170 (**2.44x the MP5**), Stoner 1325. The
  MP5's x3.0 comes from the Skye port, not our tuning. Two fixes offered
  (raise MP5 locHead to 5.0, or raise its base damage); awaiting the call.
- **DEFERRED, logged:** CHAIN LUNGE (knife-kill -> fast lunge onto the next
  zombie, chainable) — user flagged it as a big piece to do after this batch.
- Artifact + `docs/armory.html` rebuilt with all of the above.

## 2026-08-21 (v8.8) — Thor's Thunder: Lv1 toned down + a real cooldown gap

(session 0b53d4a2; -GscOnly foreground build 71.39 MB @ 6:53:40 PM, single
builder / no watcher after the earlier self-collision. _tod_upgrades.gsc only.)

- **Lv1 made small, so Lv1 vs Lv3 read distinctly** (user: "reduce the effect
  and impact of level 1 — Lv1 & Lv3 too close"). Lv1 is now just a localized
  zap: the descending SKY BOLT + impact flash are Lv2+, the lingering storm
  CLOUD is Lv3+, and the storm-boom sound is Lv2+ (Lv1 gets a quiet
  `tod_thor_zap` crackle). Splash radius 120→80u at Lv1 (base 90→40, +40/Lv →
  Lv3 160, Lv5 240) and damage 27%→20% max-hp at Lv1 (base .15→.05, +15%/Lv →
  Lv3 50% unchanged/"fine", Lv5 80%).
- **Cooldown lengthened so the delay is actually felt** (user: "no delay
  between when the lightning triggers on hit — did we not add that in?"). The
  gate WAS there (added v8.6) but 900ms at Lv1 was shorter than the ~1.1s
  bolt+cloud afterglow, so strikes blended into a continuous storm and read as
  ungated. `TOD_THOR_CD_MAX` 900→1500 / `MIN` 300→500 / `STEP` 150→250 →
  Lv1 1500ms (clear gap > fx lifetime), Lv3 1000, Lv5 500. Infinite-Ammo still
  removes the gate for the melee class; `TOD_THOR_MAX_LIVE` 6 unchanged.

## 2026-08-21 (v8.7) — first-door spawner unstuck + Krig recoil stack

(session 0b53d4a2; clean single-builder FULL build 71.39 MB @ 5:48:54 PM —
geometry changed, so cod2map64 + LED bake ran. Also carries 8e's sprintfire
block + tod_class_select desc, already in the tree.)

- **FIRST-DOOR STUCK ZOMBIES — base SE riser unpocketed** (user: "zombies
  getting stuck at a wall near the first stair door, floor 0"): the Power Room
  was carved into the base SE corner, and its north wall (y=-400) + the lap1
  anti-bypass wall (x416..436) + the E arena wall boxed the SE riser
  (470,-360) into a dead-end stub of the east gutter — zombies rose there with
  no path out and milled at the first-door corner. An earlier relocation
  (470,-470 -> 470,-360) had only moved it deeper into the same trap. Moved to
  (336,-336) on the open walkway ring south of the E-flight base, where it
  paths freely. `tools/gen_tower_map.js` risers table; regenerated the .map.
- **KRIG RECOIL — stacked another +25%** (user confirmed via prompt it was
  additive, not a re-count): `KRIG_RECOIL_BUMP` 1.25 -> 1.5625 in
  `gen_tod_twins.js`, so total krig kick = 1.15 * 1.5625 = x1.797 stock
  (adsGunKickPitchMax 14.375 -> 17.969, verified 1.25x). Base + all twins;
  regenerated the twin GDT/zpkg/CSV.
- **BUILD NOTE — self-inflicted two-linker collision (TaskStop did not kill
  the watcher).** Root cause confirmed from the task logs: watcher #1
  (armed 17:24:30) was TaskStop'd when the Krig question came up, but the
  stop did NOT terminate its poll loop — it survived, fired at game-close
  (17:35:54) and completed BUILD OK at 17:38:57, WHILE the re-armed watcher #2
  (17:35:56) ran the same full build concurrently — two linkers, same BSP
  write at 17:36:15, #2's linker crashed 0xC0000005. Both peers were clean;
  the collision was two of THIS session's own builds. #1's 17:38:57 .ff
  "reported OK" but is a two-linker product (poison risk), so it was
  discarded: sound\zone ritual + a clean SINGLE-builder rebuild (17:48:54),
  which 8e's -GscOnly card repack (18:17:59) now sits on. LESSON: TaskStop on
  a background watcher may leave its spawned build running — verify the
  process is actually gone, don't trust the stop.

## 2026-08-21 (v8.6) — playtest batch 3: Thor cooldown, Zombie Blood pulled, Thor pause plate

(session 0b53d4a2; GscOnly build 71.39 MB @ 12:51:02 PM on top of 8e's 12:45
full build — no geometry/zone/image touched)

- **THOR'S THUNDER — level-scaled cooldown** (user: "should need a cooldown and
  the higher you upgrade the less of a cooldown"): the flat 450ms gate is now
  a ramp — `thor_cooldown_ms()` = 900ms at Lv1 down to a 300ms floor at Lv5
  (`TOD_THOR_CD_MAX/MIN/STEP`). **INFINITE AMMO removes the gate entirely** for
  the melee class (user, mid-turn) — `zombie_powerup_infiniteammo_on`
  container-guarded; `TOD_THOR_MAX_LIVE` 6 still caps the concurrent bolt
  storm so an un-gated knife can't spawn unbounded fx/entities. (Confirmed for
  the user: Thor DOES deal splash — 27%→75% of each nearby zombie's max HP,
  radius 90→210u; that part was already live.)
- **ZOMBIE BLOOD drop DISABLED** (user: "remove blood money or fix it — slows
  the whole game, not just zombies"): under the endless-rounds twist a 30s
  ignoreme+invulnerability window balloons the horde (rounds keep spawning
  while nothing dies) and the ignoreme repath storm on a big horde tanks the
  server frame — felt game-wide. Drop un-registered server- AND client-side
  (`_tod_powerups.gsc` + `.csc`); grab/window code kept for a tuned re-add
  (short window, capped horde).
- **THOR pause-menu plate now renders** (user: "missing images for thor's
  thunder pause display"): art (`i_tod_pause_r20`), zone entry, `domain_id`
  20 and `PAUSE_PLATE_MAX` 20 were all correct — but the owned-rows loop in
  `AetheriumStartMenu.lua` ran `for id = 1, 19`, so domain 20 never became a
  row. Bumped to 20.
- **Maxed stats already excluded** (user report): `roll_options` filters
  `get_level < d.max` and the station gates `player_has_upgrades_left` — both
  already in the tree; the tested 12:24 build predated them. Ships in this
  build, no new code.

## 2026-08-21 (v8.5) — playtest batch 2: reserve/recoil nerfs, Time Warp scope, power switch flush

FULL build (cod2map + LED + linker) — the power switch moved in the .map.
Session 09c3 (the one that fixed the `class_primary_in_inventory( self )`
arity boot error at 02:20 — a 0-arg self-method called with 1 arg = the
"Unresolved external ... with 1 parameters" Com_Error; `tools/lint_tod_arity.js`
now catches that class across every GSC/CSC incl. stock callees, and
PLAY_NORMAL.bat / run_game.ps1 log UNBUFFERED (`logfile 2`) so a hang can no
longer hide the last lines in the log buffer).

- **RESERVE −75%** (user: "too strong"): 1 → **0.25 reserve rounds per kill
  per level**, banked per player (`tod_reserve_bank`, the BOUNTY idiom) and
  paid in whole rounds — Lv1 = 1 round per 4 kills, Lv4 = 1 per kill, Lv5 =
  5 per 4. History 2 → 1 → 0.25. Cards re-baked by the user from my prompt
  ("+1 AMMO PER 4 KILLS" / "+1 PER 2" / "+3 PER 4"), same filenames.
- **KRIG RECOIL**: `KRIG_RECOIL_BUMP` 1.25 multiplies the roster-wide 1.15
  bump on the krig's 16 kick keys (×1.4375 stock). **RECOIL upgrade halved**
  (user "like 50%"): `RECOIL_STEP` −25/−45/−65% → **−10/−20/−30%**. Lua
  DOMAIN[17] + add_domain desc + docs + new cards ("−10% / −20% / −30%
  RECOIL") all in lockstep. (Twins were regenerated by session b7's 12:24
  build with these constants — kick 7.19 base → 5.03 at r3.)
- **TIME WARP scope** (user: "slows down the whole game now and not just the
  zombies"): the pack's loop slowed EVERY axis AI — Panzer + Rogue
  Protectors included (custom-locomotion bosses stutter/freeze when their
  rate is stomped) — and called the player-only `SetMoveSpeedScale` on AI
  20×/s. Now `tod_warp_target()`: regular `is_zombie()` actors only, never
  bosses / frozen (upgrade pause) zombies; anim rate is the single lever;
  re-assert at 4 Hz instead of every frame. If the user's "whole game" means
  their OWN movement slowed, that is a second cause still to find.
- **POWER SWITCH FLUSH** (user: "not up against the wall ... some space in
  between"): the stock prefab's body clip spans local y[−8,+7] and yaw 270
  maps local +Y → world +X, so the back sat at 1596+7 = 1603 against a wall
  face at 1620 — a 17u gap. Origin → **1613**; the use trigger lands at
  x[1589,1608], still inside the hall. `.map` regen diff = that one origin;
  door/crown data re-emitted byte-identical.
- **SHOOT WHILE SPRINTING — SKIRMISHER innate** (user): the engine's Gung-Ho
  specialty `specialty_sprintfire` (MP's perk; `util_shared.gsc:4054` names
  it) granted to every skirmisher on the `body_systems_loop` 1s tick next to
  the staminup re-assert (perks strip on death), unset if the class ever
  differs. No twin, no GDT edit — it is a player specialty, so it applies to
  whatever the skirmisher holds. Class-select desc1 now "fires while
  sprinting"; the class card's "FAST AND NIMBLE" subline is the user's
  re-bake (prompt sent).

## 2026-08-21 (v8.4) — BOOT FIX + Thor's Thunder art + Zombie Blood + concurrent batch

Built once (71.39 MB, 12:24) from a tree three sessions edited concurrently;
verified before link (lint OK/44 files, _tod_upgrades braces 132/132, no dup
#defines, zero dup weapon keys). Attribution noted per item.

- **BOOT FIX — the black screen** (this session): the vendored Logical's
  Powerups threw "cannot cast undefined to bool" EVERY server frame per
  player, black-screening the load. `solo_hud_fix()`'s `A || minigun_on`
  read `zombie_vars["zombie_powerup_minigun_on"]`, which this map never sets
  (Death Machine redirected to the Gift of Death). With ammo_on=0 (falsy)
  the `||` evaluated the undefined minigun var and threw. Null-guarded all
  three reads with IS_TRUE in `_zm_powerup_infiniteammo.gsc` +
  `_zm_powerup_timewarp.gsc`. Found via the unbuffered (`logfile 2`) launch
  after the buffered log's cut point misled the whole triage toward the
  weapon table / banks.
- **THOR'S THUNDER art** (this session): cards ×3 + pause row `r20` + the
  Zombie Blood tray icon `i_tod_pu2_zombie_blood`, wired (GDT/zone/CARD_SLUG/
  DOMAIN[20]/PAUSE_PLATE_MAX 20/tray entry). UI-kit re-export was
  byte-identical to installed — nothing else changed.
- **Thor DoDamage arity** (this session): `_tod_upgrades.gsc` thor_shock had
  an 8-arg DoDamage (string where boneIndex int goes) → stock 3-arg form.
- **Twin dedup + regen** (this session): `gen_tod_twins.js` variantRe never
  matched the stoner forms, so every regen appended duplicate/dead rows
  (t9_stoner63_b ×3, _p0/1/2 ×2). Fixed the regex; regenerated — CSV now has
  zero duplicate keys.
- **RESERVE nerf** (session 8e / 09c3f628): `TOD_UPG_RESERVE_PER_LVL`
  1 → 0.25, fractional bank paid in whole rounds (1 per 4 kills/Lv);
  RECOIL twin ladder → [1,0.90,0.80,0.70] + `KRIG_RECOIL_BUMP` 1.25 (krig
  base kick 7.19); DOMAIN desc strings. (Recoil realized in this build's
  regen; 8e need not re-regen.)
- Session 323a3d8e's station-cap / door-luck / HP-readout work also rode in
  this build — see its own v9.1 section below for the details.
- **Build guards hardened** (this session, from the 02:23 two-linker
  corruption): `build_map.ps1` now refuses to start if another
  `linker_modtools.exe` is alive, and fails hard post-link if the game
  appeared mid-build or the alias bank was locked — a poisoned .ff no longer
  reports "OK".

## 2026-08-21 (v9.1) — station use cap, door luck x1.75, real HP readout

(session 323a3d8e; rides in b7's combined -GscOnly build with the Logical
powerups boot fix, the Thor DoDamage fix, the twins dedup/recoil regen and
8e's RESERVE nerf)

- **PERSONAL STATION: 3 USES PER PLAYER PER TERMINAL** (user: "each player
  can only use a specific upgrade station 3 times; after that they need to
  go up and use the next one — to push players up the tower").
  `_tod_upgrades.gsc`: every terminal gets an id at spawn (base 0,
  breathers 1-4, crown 5; `level.tod_station_count`), each player carries
  `tod_station_uses[id]`; `station_depleted()` refuses a 4th buy at that
  terminal and the hint reads "TERMINAL DEPLETED - climb to the next one"
  (co-op mismatch still shows the generic). The PRICE ladder is untouched
  (it keeps counting across terminals) — the cap changes where you buy, not
  what you pay. A refunded buy (both cards dead) gives the use back. **DEV
  (`level.tod_dev`): no cap** (user) — `station_depleted` early-returns.
- **DOOR LUCK x1.75** (user): `_tod_luck.gsc` `TOD_LUCK_DOOR` 5 -> 8.75,
  buyer only (unchanged — `_tod_doors` passes the purchasing player).
- **HP READOUT SHOWS THE REAL MAX** (user: "players start with 150 HP but
  the HUD says 100"). Root cause: the Aetherium kit's `player_health_X`
  clientfield is a 0..1 FRACTION (`_zm_aetherium_hud.gsc:105`) and
  `AetheriumPlayerInfo.lua` multiplied it by a hardcoded 100. Fix: the
  server now pushes each player's `int(maxhealth)` on change over the
  int-only LuiNotifyEvent lane (`_tod_gauge.gsc`, eventstring `tod_maxhp`,
  zero clientuimodel bits — the 61-bit budget is untouched); the widget
  multiplies the fraction by that value (default 150 until the first push).
  Jugg's 250 and any future max-HP change display correctly too.

## 2026-08-21 (v8.3) — PaP + Zombie Blood drops, THOR'S THUNDER, the swap hole

- **FREE PACK-A-PUNCH DROP IS BACK, on a real pickup model.** A 31-agent
  search (local disk + UGX/ModMe + git + precedent + prop packs, every
  candidate link-verified) found exactly one purpose-built asset:
  ZoekMeMaar's `free_packapunch` (NSZ powerups megathread, MEGA). Measured
  16.75 x 12.16 x 22.13u, origin INSIDE the mesh — vs the chaos machine's
  119u base-pivot frame. `mtl_x2icon_gold` resolved from stock at link (no new
  warning). Powerup id `tod_pap`, power-gated, grabber-only. CREDIT
  ZoekMeMaar + NateSmithZombies.
  THE GRANT NO LONGER USES THE STOCK UPGRADE PATH: it latches
  `player.tod_pap_owned` and `reconcile_twin` swaps to the `_up` twin on its
  next 1s tick (a name the generator PROVABLY emitted). No direct call — that
  would be a circular #using (_tod_upgrades already imports _tod_powerups).
  Non-class guns still take the stock path, which demonstrably works for them.
- **ZOMBIE BLOOD** (NSZ model + vox, credit NSZ): 30s grabber-only window —
  `player.ignoreme` (the stock AI target lever, not the pack's enemy-override
  hook) + invulnerability + the in-plain-sight overlay. Re-grab RESTARTS the
  window (one thread, never two clearing each other); going down mid-window
  clears it (else permanently invisible). Not power-gated — it is the panic
  button.
- **THOR'S THUNDER — new SLASHER domain (id 20, 5 Lv)**: every melee hit calls
  lightning down on the victim. Fusion of ZoekMeMaar's sky-bolt
  (`thunderstorm_effect` mover from +500z) and map 1's Cyberjack micro-storm
  SERVER half (tesla shock + eyes bursts, `cj_thunder` clap, `cj_zap`). The DE
  funnel/orb/bolt are NOT portable (hb21 bow clientfields this map does not
  load). Scales per level: radius 90 +30/Lv, damage 15% +12%/Lv of each
  victim's MAX HEALTH (round-independent by construction), loudness (Lv3+
  the clap stacks, Lv5 both storm rolls). Bosses exempt. 450ms per-player
  cooldown, 6 concurrent strikes level-wide. Cleave-splash hits do not
  re-trigger it (one swing = one strike). Card art + pause plate PENDING —
  falls back to composite card / text row until it lands.
- **THE TWIN-SWAP HOLE** (user: "it takes away your gun and places it in your
  inventory... always switches to my pistol"). Map 1's give->switch->delta->
  take order was already ours; the hole is that `SwitchToWeaponImmediate` is
  silently EATEN in several states (mid-sprint/raise/reload/ADS). Then `want`
  lands holstered, TakeWeapon(old) removes the CURRENT gun, the engine falls
  back to the pistol — and no later reconcile fixes it (it sees the right twin
  owned and returns). Map 1 survived only because its reconcile re-fired on
  weapon_change_complete. FIX: verify-and-retry the switch every frame (<=1s)
  BEFORE the take, so the pistol never even flashes; a transitional "none"
  current weapon now counts as held; and `ensure_equipped` re-asserts for
  1.5s after the take as the last line of defence.
- Vendored to the REPO this time (not just the tools root): all new wavs
  (`sound_assets/_ZoekMeMaar`, `_NSZ`, `acc/fx/cj_*`) and the storm .efx.

## 2026-08-21 (v9) — THE CROWN: the top of the map, the ending, rail caps

- **THE ROOF WAS UNREACHABLE — root cause and fix.** The roof arrival
  landing + its rails + the `enter_roof` door were an ODD-lap-only special
  case inside the generator's flight loop ("lap 25 ends via the N flight").
  v8 doubled LAPS to 50 — an EVEN final lap — so that branch never ran: no
  arrival was emitted and the roof door slab hung in open air on the wrong
  side of the tower ("the last platform isn't even connected to the stairs",
  user). The crown is now generated as ONE MORE LAP (`CROWN_LAP = LAPS+1`)
  in the same parity math as the spiral: every crown coordinate is authored
  in the odd frame and point-mirrored through the tower axis (`cbox`/`cpt`/
  `cyaw`/`cvolume`/`cspec`, factor `CM`) when the crown lap is even. The
  final flight welds to whichever landing the spiral actually ended on, for
  ANY value of LAPS.
- **THE CROWN** (user: "a path way to a sick looking crown house ... huge
  huge huge out of galaxy scale"). Above the spiral, in route order:
  CROWN STAIR (gold treads, final landing -> z=19392) -> TERRACE (960x224
  forecourt along the capital's arrival face, glow tiles + under-glow) ->
  CAUSEWAY ("the pathway": 224 wide, 640 long, on-axis, three cyan portal
  frames, glowing underside, over 19,000 units of air) -> CROWN HALL: a
  1536x1536 open-top citadel FLOATING beside the tower — 576-tall walls,
  4 corner towers with tapering needles to z+1600, 3 pilaster spikes, a
  twin-spired gate, cyan cornice, inverted-ziggurat underbelly ending in a
  glowing gravity core. On the core top: a 5-tier MAST to z=21312 with a red
  beacon. Inside: PaP + Mule Kick flank the gate, an upgrade terminal on the
  west wall, the UPLINK dais dead centre, 4 pylon plinths with coils, the
  EXTRACTION PAD at the north end, 12 wall sconces. Sky widened 1900 ->
  2900 and raised to clear the mast. **LED bake PASSED at 44.8s** (v8 was
  44.5s — +334 brushes cost nothing measurable).
- **THE ENDING — buyable** (user: "boss fight we wouldn't implement, maybe a
  buyable ending for now"), `_tod_finale.gsc`, fully diegetic: (1) THE
  UPLINK needs power, costs 25,000; (2) CHARGE/HOLD-OUT 90s (dev 20s) while
  the endless rounds keep coming — the 4 pylons ignite one per quarter
  (yellow aura) so the room is the progress bar; the boss track takes the
  music channel and keeps it (`tod_atmosphere::finale_track_start` latch);
  the clock pauses during upgrade freezes; (3) ONLINE — pylons go green,
  the pad light swaps red->green with a green aura + strike burst; (4)
  EXTRACT — hold USE on the pad; EVERY living survivor must be on it (downed
  players are left behind; the pad's hint flashes why); 6s of invulnerable
  departure with strobing pylons, then `end_game` on a custom **"YOU
  ESCAPED THE TOWER"** screen via stock's `level.custom_game_over_hud_elem`
  (stock still prints the rounds line). **FUTURE BOSS FIGHT SLOT:** a module
  that sets `level.tod_finale_boss_fn` owns the hold-out; the charge waits
  on its return. Anchor points are GENERATED (`_tod_crown_data.gsc`, from
  the same tables that cut the brushes). Props are carved T7 stock models
  already in the tools GDT DB (binaries verified on disk), script-spawned.
- **RAIL CAPS** (user: "you can just jump on top of the guard rails on the
  stairs and jump off the map"). Rails stay 56 tall (the city stays
  visible) and get an invisible `clip` cap (`RAIL_CAP_H` 112) over the
  airspace above every rail run — one box per flight (232 total, not one
  per rail segment), breather balconies included, doorways into balconies
  left open. You can still hop onto a rail; you cannot get higher or
  outward. Visible height is a one-constant change (`PARA_H`) if preferred.
- Final lap's zone volumes now stop at TOP+100 so the crown stair/terrace
  read as `roof_zone`, not `lap50_zone`. roof_zone risers: 4 in the hall
  quarters + 2 on the terrace ends.

## 2026-08-21 (v8.2) — breather station design, the placeholder-prompt bug

- **"Hint text here" — THE PROMPT BUG** (user: "they have text that doesn't
  really make sense"). `PromptDefault.lua:47` hardcoded
  `setText(Engine.Localize("Hint text here"))` and NEVER subscribed to the
  hint model, so every interactable the Aetherium dispatcher does not
  special-case — i.e. all four upgrade stations — rendered that placeholder
  verbatim. It now subscribes to `hudItems.cursorHintText` (the PromptDoors
  idiom) and strips the `^N` colour codes + the `[{+activate}]` token, since
  the prompt draws its own button glyph.
- **BREATHER STATION PLACEMENT** (user: "odd spot and the trigger is broken").
  Real balcony footprint (gen_tower_map.js:291, even-parity): floor
  x[-640,-256] y[-816,-416], entered at the NE corner. The first pass put the
  terminal mid-floor at yaw 180 (facing north) with its trigger at y=-540 —
  BEHIND the machine, so you had to squeeze between it and the perk machines.
  New layout: perk machines keep the south wall (y=-783), the station moves to
  the WEST wall (x=-600) facing EAST (yaw 90) with its trigger 56u in front on
  the walk-in line. Nearest perk machine ~185u — clear of the 64u radius.
- **STATION HINT REWORDED** to "for an Upgrade Card": the Aetherium dispatcher
  routes on keywords — `door`/`open` -> door card, `pack`+`punch` or
  `upgrade`+`weapon` -> PaP card, `[cost:` WITH an icon -> wall-buy card. The
  new wording plus HINT_NOICON keeps it on the (now working) default prompt.
- **PaP DROP: no model exists.** Checked `hb21_pack_a_punches_v1.0.0.rar` —
  castle + origins PaP MACHINES only (with fxanim parts), nothing
  pickup-sized. Every stock powerup model is already in our rotation except
  `p7_zm_power_up_widows_wine` (a bottle, would clash with the perk bottle).
  User will source a pivot-centred PaP pickup xmodel; drop stays retired until
  then. NOTE for the rewrite: the old grant PaP'd the PISTOL fine but not the
  class guns (user report) — the pistol has a plain stock CSV upgrade row,
  while the class guns are twins and the old `TakeWeapon` -> `weapon_give`
  path silently gave the original back on a failed give. Mirror the stock PaP
  machine flow instead of reusing it.

## 2026-08-21 (v8) — the tower DOUBLES, breather unlocks, boss zone gate

- **TOWER DOUBLED: 25 -> 50 FLOORS** (user). 2844 world brushes (was 1444),
  top z=19200, 52 doors. **The LED bake was the risk and it PASSED at 44.5s**
  (was 21.9s at 1444) — bake-gated BEFORE the full build, per the KB rule.
  `usermap_test_zone_init` laps bumped to 50 in lockstep with the generator.
- **GAUGE: 1 CELL = 2 FLOORS.** The bar art still has 25 cells, so
  `_tod_gauge::floor_of` now returns the CELL (ceil(floor/2)) — "you need to
  open double the doors to see progress on the tower bar". The player FOCUS
  MARKER is removed (user); the top of the lit trail reads as altitude.
- **BREATHERS RESPACED to laps 10/20/30/40** (still 4, still 2 perk pads each,
  all EVEN laps so every balcony is the mirrored SW side). Perk pad z values
  updated to 3648 / 7488 / 11328 / 15168.
- **UPGRADE STATION ON EVERY BREATHER** (user; also review item B1): the base
  terminal is joined by one per balcony, on the inboard strip (y=-500) clear
  of both perk machines. The price ladder is PER PLAYER, so extra terminals
  never make upgrades cheaper — only closer.
- **ENEMY UNLOCKS — the tower gets harder as you climb** (user): opening a
  BREATHER door introduces a new enemy type. Protectors no longer exist until
  `enter_lap10` is bought; `_tod_doors::breather_unlock` stamps the round and
  `protector_due` anchors its every-3-rounds cadence to THAT round (not the
  old global round-3 grid). Slots for breathers 2-4 are wired and commented,
  awaiting enemy types 2-4.
- **BOSS ZONE GATE — "Panzer spawned on the first set of stairs even though
  the door was not opened"** (user). Root cause: `PositionQuery_Source_
  Navigation` searches a 400-unit RADIUS and `DisconnectPaths` does NOT delete
  navmesh polys (it only blocks pathing THROUGH the slab), so the query
  returned points behind a closed door — and the base ring is within 400u of
  the lap-1 stairs. `pick_spawn_point` now rejects any candidate not inside an
  ENABLED zone (`zm_zonemgr::get_zone_from_position(p, false)`, budgeted at 12
  checks since each spawns a temp entity) and falls back to the ANCHOR rather
  than an unvetted point. Closes the same hole in the anti-strand watchdog,
  which could teleport a stalled boss to a player anywhere in the tower.
- **SPEED BUFF**: `TOD_UPG_SPEED_PER_LVL` 3% -> **5%/Lv** (user: "buff mobility
  for skirmisher"). NB the skirmisher's speed domain is SPRINT, not MOBILITY
  (that is heavy's) — they share the constant, so both moved. Maxed skirmisher
  is now 1.50x base (was 1.30x).
- **STONER MAGS -20%**: base 75 -> 60, PaP 110 -> 88.
- **FREE-PaP DROP IS POWER-GATED** (user): `should_drop_free_pap` replaces the
  stock always-drop, so the bottle only enters the rotation once "power_on"
  flags. (It was already POWERUP_ONLY_AFFECTS_GRABBER.)
- **CLASS LABELS**: draft text fallback said "AK-74u SMG" / "M60 LMG" -> MP5 /
  STONER 63. The two class CARD ARTS still show the retired guns — regen
  prompt delivered. Upgrade cards are gun-agnostic and needed no change.

## 2026-08-20 (v7.0) — gun roster swap + stats reset to stock

- **SKIRMISHER = CW MP5** (was AK-74u), **HEAVY = CW Stoner 63** (was M60),
  both already present in the installed Skye pack and both altWeapon-screened
  clean (the boot trap). Swapped in `_tod_classes.gsc`, the zone weapon lines,
  and `zm_levelcommon_weapons.csv` (15 stale ak74u twin rows removed).
- **ALL CLASS GUNS RESET TO STOCK GDT** (user: "restore back to original GDT.
  We will tweak from there. Only thing I want to keep is speed with gun"):
  - `gun_balance_mult` no longer touches class guns (the v6 pass — m60 x0.85 /
    ak74u x1.1 / krig x1.05 — is retired). The starter PISTOL keeps x8: it is
    not a class gun and stock base damage is ~25.
  - `RECOIL_STEP[0]` back to **1.0** — the 25% base-recoil cut is reverted, so
    `_r0m0` is a byte-identical duplicate and is skipped again; `twin_suffix`
    early-outs at 0/0 for assault. Twins 72 -> 70.
  - **MOVE SPEED SURVIVES**, as asked: `class_speed_base()` is keyed on the
    CLASS (heavy .8 / assault .9 / skirmisher 1.0 / slasher 1.1), not the gun,
    so it carried across the roster swap untouched.
- **SOUND ALIASES GENERATED FOR BOTH NEW GUNS** — neither exists in either
  repo's CSV. New `tools/gen_tod_sounds.js` (supersedes `gen_krig_sounds.js`,
  deleted: re-running it would clobber the new set) covers krig + mp5 +
  stoner. Two traps it handles that a naive port would not:
  - the Stoner ships **no trig_pull wavs**, so that fire family is skipped
    rather than emitting aliases pointing at missing files (`skipFire`);
  - **the GDT is the authority on foley alias names, not the wav names.** The
    Krig's GDT wants ONE `mvmnt` fed by mvmnt1-4 (round-robin); the MP5's
    wants mvmnt, mvmnt2, mvmnt3, mvmnt4 as FOUR separate aliases. The
    generator reads each GDT's referenced aliases and binds them to wavs
    (exact basename, else the numbered family), so both are correct.
  Verified: 0 missing wav references across all three guns.
- **TOWER GAUGE** (files (16).zip) — the HUD floor indicator: dark backing
  with one lit cell stamped per climbed floor, amber breather cells, lit roof
  crown, a marker on your floor and a red pip on the lowest live boss. LUI has
  no UV/crop, so the cell tiles are sliced out of the lit artwork at build
  time. Fed by `_tod_gauge.gsc` over the int-only LuiNotifyEvent lane (costs
  ZERO clientuimodel bits — the 61-bit budget is full). Delivers review items
  C1 (floor readout) and C2 (boss proximity) at once.
- **PAUSE PANEL + CARD ART**: 58-card set reinstalled with corrected MAG SIZE
  text (+30/+60/+90%); pause-menu upgrade list is now baked plates + pips.

## 2026-08-20 (v6.10) — playtest batch: ammo economy, krig feel, station freeze

- **"WHY DO I HAVE UNLIMITED AMMO"** — two compounding causes, both fixed:
  RESERVE refunded +2 rounds/Lv on EVERY kill (Lv5 = +10/kill, which
  out-earns what a krig spends) -> now +1/Lv; and the MAG SIZE twin was
  scaling `maxAmmo` (reserve CAPACITY) by the same multiplier as the clip ->
  `MAG_KEYS` is now `clipSize`+`startAmmo` only. Mag size never touches the
  reserve pool again.
- **KRIG MAG LADDER 30/60/90/120** (user expected these exact numbers; was
  30/45/60/75): `MAG_STEP` [1,1.5,2,2.5] -> [1,2,3,4].
- **KRIG BASE RECOIL CUT 25%** (user): the base gun's GDT lives in the tools
  root (not version-controlled), so the cut is baked into the GENERATED
  ladder instead — `RECOIL_STEP` is now [0.75, 0.5625, 0.4125, 0.2625] and
  **`_r0m0` is generated as a real variant** (the r==0&&m==0 skip is gone,
  and `twin_suffix` no longer early-outs at 0/0 for assault). Every assault
  player rides a twin from spawn; `body_systems_loop`'s 1s reconcile pulls
  them onto it. Verified hipGunKickPitchMax: stock 5.0 -> r0m0 3.75 -> r3
  1.3125. Twin total 70 -> 72 (ceiling ~230).
- **PERSONAL STATION NO LONGER FREEZES YOU** (user: "it pauses you but
  doesn't pause zombies so you are helpless"): the station flow never touches
  `menu_freeze` now — full movement, weapons and jump while the cards are up.
  You fight WHILE you choose, or the 15s timer auto-locks. HOLD-jump is still
  the lock so an ordinary hop cannot pick a card. The takeover path still must
  never call `menu_freeze(false)` — on a scheduled round event the EVENT owns
  the (flat, non-nested) freeze flag.

## 2026-08-20 (v6.9) — experience review pass: solo revive, real breathers, pause art

Driven by `docs/23_experience_review.md` (full read of the map's code + concepts).

- **QUICK REVIVE MOVED TO THE BASE** (review A1, user pick): QR was pinned to
  the floor-5 breather, which costs **9,375 points of doors** to reach — so a
  solo player had NO self-revive for ~10k points and one down ended the run.
  It is now pinned to the revive machine's own base N-wall parking spot (it
  never moves). Every other machine still scatters across breathers only; 9
  pads / 8 machines means one breather pad is empty each run.
  NOT viable alternative, for the record: granting the perk early — the stock
  vending trigger refuses any purchase while the player holds the perk
  (`_zm_perks.gsc:545`), which would have locked them out of buying lives.
- **BREATHERS ARE ACTUALLY BREATHERS** (review A3): laps 5/10/15/20 had 2
  risers each like every other floor, so the "breather" balconies spawned
  zombies normally and the map's one pacing beat did not exist. Breather laps
  now emit ZERO risers (58 -> 50) — the horde has to climb to you. Safe with
  no risers because the zone volume's `target` also resolves to the
  dog-location struct sharing that targetname.
- **PAUSE-MENU UPGRADE PANEL = BAKED ART** (files (12).zip): header plate + 18
  domain name plates (indexed by `_tod_upgrade_ui::domain_id`) + a level pip
  repeated per level, replacing the LUI text rows. True aspect throughout;
  `USE_PAUSE_ART=false` falls back to the old text path.
- **ELECTRIC CHERRY ICON** installed (replaces the Borderlands placeholder).
  Also fixed the mapping's `specialty` (was `specialty_electriccherry`; this
  map's cherry rides `specialty_combat_efficiency`). KNOWN LIMIT: that
  specialty has no stock `hudItems.perks.*` uimodel, so the perk row still
  cannot light it — map 1 solved this by rewiring the whole row onto a custom
  clientuimodel mask, which is not ported here.

## 2026-08-20 (v6.8) — personal upgrade station, slasher tuning, 150 HP

- **PERSONAL UPGRADE STATION** (user): buyable solo-upgrade terminal at the
  base (Chaos PaP mesh, core south face, script-spawned — no map regen).
  Cost 2000 +1000 per purchase, PER PLAYER. The world does NOT pause — the
  buyer is menu-frozen at the terminal while the horde stays live (the
  risk); the 15s auto-lock timer still runs. A scheduled upgrade round
  OVERRIDES a manual pick (takeover notify kills the solo menu before the
  event touches the shared card fields) and the SAME cards re-present with
  a fresh timer afterward — re-clamped vs current levels so a stale card
  can never lower a level (both cards dead-maxed → refund + price steps
  back). Downed mid-pick → default card auto-locks. Solo rolls spend the
  buyer's luck bar, same as event rolls.
- **150 BASE HP** (user): spawn grant + jugg-aware 1s maintain (stock jugg
  is additive; restores to 150, not 100, on perk loss).
- **SLASHER TUNING** (user): DMG REDUCTION 4→5%/Lv, BOUNTY 3→5%/Lv, cleave
  radius 120→60, KNIFE SPEED now 5 levels at -10% each (twin ladder
  regenerated: knife k1-k5, 70 twin assets total). 3 card arts pending
  regen (stale baked percentages).
- **LUCK ODDS NERF** (user): the bar now MULTIPLIES the SUPER/ULT chances
  (x2 at 50%, x3 at 100%) instead of the steep linear ramp — full bar is
  40/45/15 REG/SUP/ULT (was 20/50/30).
- **STATION VERIFY FIXES** (adversarial pass, 10 findings → 6 distinct):
  apply_upgrade is now MONOTONIC (re-reads cur, clamps at max, never writes
  downward — kills the lock-vs-event one-frame race where the round event's
  stale snapshot could erase a paid solo pick); menu_freeze(false) on the
  completed path is gated on the pause flag (flat-flag ownership); downed
  during the confirm flash now keeps the card actually locked (0.8s grace);
  deferred cards refresh + dead cards drop BEFORE re-present (both dead →
  refund); station yaw 270→359.999 (vending convention — 270 faced west);
  co-op hint goes priceless when 2+ in range owe different prices; door
  recipe deny/cha-ching sounds on the use gates.

## 2026-08-20 (v6.7) — text purge, luck/RP tuning, breather-only perks, door costs

- **NO FLOATY TEXT** (user: "+8 luck and things like that — remove all"):
  14 IPrintLnBold sites stripped (luck feed ×4, boss-down points, upgrade
  apply/timeout/maxed notices, class random ×3, intro line, scatter notice,
  insta 3X announce). Dev-gated diags kept. TRAP for next time: 5 of the
  prints were braceless-if bodies — replacing the statement with a comment
  dangles the if and kills the compile ("No generated data").
- **LUCK NERF** (solo maxed every event): kill budget 40→18, door 8→5.
- **PROTECTOR NERF**: anim rate 1.0→0.85, bullet dmg 21→15 cap 45→32 (on
  top of bullets-only/-20% freq from v6.6).
- **PERKS = BREATHERS ONLY** (user): 2 pads per balcony ×4 breathers = 8
  pads for 8 machines; base/per-floor/roof pads removed; QR pinned to the
  floor-5 breather (fixed_spec). Mule Kick + PaP remain the roof reward.
- **DOOR COSTS ×1.5**: 1125 +375/floor cap 6000; roof 7500; power room 750
  (regen + full geometry build — costs live in BSP entities). .ff 60.77 MB.

## 2026-08-20 (v6.6) — RP bullets-only, belt feeder rework, UI polish

- **ROGUE PROTECTOR = bullets only** (user): zap pulse + mahem rocket retired,
  ALL knockback gone, fire interval 3.0s → 3.6s (-20% frequency).
- **BULLET FEED reworked** (user: "too slow and seems broken" — it fed 1
  round per ~5.5s at Lv1): now feeds EVERY second, amount 1+(Lv-1)/3
  (Lv1 1/s → Lv10 4/s).
- **UI**: the switch-hint plate was drawn at 10:1 vs the art's 6.6:1
  (stretched) AND the "AUTO IN Ns" countdown rendered on top of it —
  true-aspect 280×43 at bottom-center below the powerup tray, countdown
  beneath; same aspect fix on the draft screen. .ff 60.77 MB.

## 2026-08-20 (v6.5) — the full UI family in baked art + QoL batch

- **UI FAMILY ART** (files (11).zip, 32 images): event/draft banners replace
  title text; PANZER + ROGUE PROTECTORS slide-in banners (LuiNotifyEvent
  "tod_boss_banner" 1/2/0, server-timed hide, sequenced on double rounds,
  text fallback) replace the IPrintLnBold announcements; 10 luck badges
  (per-10%) replace the luck text; 5 input-hint plates (controller/KBM
  auto-detect) replace bind/switch text; 10 custom powerup tray icons
  (Death Machine slot renamed Gift of Death); mag_size cards regenerated
  with rarity-specific "+50/100/150% REAL MAG". Adversarial verify: 9
  confirmed fixes incl. a CRITICAL (boss banner parented inside the
  alpha-gated upgrade panel = invisible at round start — moved to the menu
  root). GSC trap logged: #precache between #using lines = "No generated
  data" compile kill.
- **QoL batch (same day)**: Panzer always drops Max Ammo at his corpse; the
  luck bar "%" text and the card "Lv X > Y" overlay are REMOVED (no-LUI-text
  doctrine); perk row reverted to the stock BO3 perk shaders (cherry keeps
  the kit icon — stock has no cherry shader, even Treyarch placeholders QR).
  .ff 60.75 MB.

## 2026-08-20 (v6.4) — the 58-card baked art set (images-over-LUI)

- **FULL-CARD ART** (user drop files (10).zip; the standing images-over-LUI
  doctrine): 54 upgrade cards (18 domains × 3 rarities) + 4 class cards,
  768×1152 portrait cartoon art with ALL text baked in, replace the LUI
  composites in BOTH menus. tod_upgrade.lua + tod_class_select.lua re-laid
  PORTRAIT (upgrade cards 213×320 at y230–550; draft 4×210-wide at y210–525);
  LUI keeps only layout + live overlays (Lv line inside the art's desc plate,
  bind hint + hold bar below the card, rarity/class accent strips for focus,
  countdown). USE_CARD_SET_ART / USE_CLASS_CARD_ART primary flags; composite
  paths survive as fallbacks. Assets: i_tod_card_<slug>_<rarity> +
  i_tod_card_class_<key> in tod_ui_images.gdt + 58 zone image lines.
  Adversarial verify: 5 minor fixes (Lv position measured against the real
  art, per-render strip alpha/accent re-baselines, stale docs, one leftover
  "use a base station" string). KNOWN: the 3 mag_size cards carry stale
  "+40% bottomless" text — regenerate with "REAL MAG +50/+100/+150%".
  .ff 60.49 MB.

## 2026-08-20 (v6.3) — playtest round 3: power room 5x, real mag twins, tens damage numbers

- **POWER ROOM 5x** (user: "hallway needs to be like 5x longer"): the corridor
  now punches through the arena's east wall and runs OUTSIDE the base to
  x=1620 (~1340u, ~5.2x) — same 500pt door, 3 cyan lights down the run,
  switch at the far end facing back down the corridor. Skybox widened
  (SKY_IN 1200→1900), VOL_R→1700, base_zone got a hallway volume brush.
  1444 brushes, bake fresh.
- **MAG SIZE = REAL TWINS** (user: "I don't want bottomless magsize — this
  should be a twin"): the virtual pool + mag_watcher + MAG +N chip are GONE.
  Assault-only domain → krig-only matrix: r{R}m{M} (recoil × mag, 15 combos
  ×2 forms; clipSize/startAmmo/maxAmmo ×1.5/2.0/2.5, INT-rounded). MAG SIZE
  is now 3 levels (the gun-data rule). twin_suffix assault branch is
  "_r{R}m{M}"; 66 total twins. todMagBonus clientfield stays registered
  (budget stability) but is never set.
- **DAMAGE NUMBERS: TENS ENCODING** (user: insta-kill headshot "2k" vs 1.2k
  regular — the 13-bit raw cap at 2047 was flattening tripled headshots; the
  3x WAS applying): push_dmg_num now sends dmg/10 and the Lua displays ×10 —
  cap 20,470, rounded to the nearest 10.
- Earlier same-day (v6.2, unlogged): power switch into a hallway room +
  facing fix (yaw 270; 180 pointed it INTO the wall), pause-menu upgrades fix
  (missing #precache eventstring "tod_upg_sync" — LuiNotifyEvent silently
  never fired), insta-kill reworked to a team-wide 3x damage window
  (level.insta_kill_powerup_override + level.tod_dmg_mult, bosses exempt),
  boss bottom-spawns + anti-strand watchdog + vertical fire gate (no
  through-floor sniping, TOD_BOSS_FIRE_ZDELTA 300) + damage-side shield,
  protector bullet knockback removed, panzer damage halved
  (TOD_PANZER_DMG_MULT 0.5), pistol ×8, protector waves =
  round(players/3 × round), base clips capped at 1600 (they cut invisible
  walls across the enlarged breathers), breather edge seals, class-switch
  stations REMOVED, Gift of Death fixed-shots guards (damage>0 + same-frame
  dedupe), free-PaP always consumes (bottle model; GiveMaxAmmo fallback),
  luck frame v2 art (window remeasured), v6 weapon/art batch (Xmas Gun on
  the Death Machine drop 2/10/30 fixed shots, BOCW combat knife replaces the
  ballistic knife, powerup tray icons).

## 2026-08-20 (v6) — half-lap tower, perks everywhere, LUI luck bar, pause-only upgrades

- **v6 PARITY SPIRAL — 2 flights per floor** (user: "4 is way too much"):
  LAP_RISE 384, top z=9600 (was 19200). Odd floors climb E+N (NE mid / NW
  end landing), even floors W+S mirrored; doors, zone risers/dog, lights,
  probes and breathers all parity-mirrored in the generator. Roof arrival
  at the NW corner. **All wallbuys removed** (user: "I never asked for
  those"). Breathers (floors 5/10/15/20) LARGER — 400×224 exterior — on
  the mid landing. 1430 brushes, **BAKED 21.9s**; full build 43.13 MB .ff.
- **Perk scatter v6**: pads = base ×2 (QR fixed west) + **every floor's mid
  landing** (25, parity-mirrored) + the 4 breather balconies as **priority
  pads (always filled first — a breather always holds a perk)** + roof.
  Machine floor now 8: **Double Tap (3000) + Deadshot (3500)** wired into
  the park, the scatter pool and tod_set_perk_costs (glow colors were
  already in the perk-lights table).
- **Luck bar → all-LUI** (fit fix): the server hudelem fill/label are GONE;
  `_tod_luck` pushes bar/10 through the EXISTING todUpgLuck clientfield
  (`tod_upgrade_ui::set_luck_pct`, zero new bits) and tod_upgrade.lua
  renders 10 segments seated in the frame art's window + a "n%" readout
  (gold at 80%+). Never opens the HUD menu pre-blackscreen.
- **Upgrade list is PAUSE-MENU-ONLY now** (user: it cluttered the HUD): the
  hudelem column is deleted. `refresh_upgrade_list` sends one **int-only**
  `LuiNotifyEvent(&"tod_upg_sync", 3, id, lvl, max)` per owned domain (map
  1's kill-feed lane — `SetClientDvar` does NOT exist in T7, and host
  dvars never replicate to co-op peers; string args would leak
  CS_LOCALIZED_STRINGS config-string slots forever on an endless map).
  tod_upgrade.lua accumulates `CoD.TodOwned`; AetheriumStartMenu.lua
  renders a "YOUR UPGRADES" column (left side, under the logo) on every
  pause open, names from the HUD's own DOMAIN table (`CoD.TodDomainInfo`).

## 2026-08-20 (v5.3) — TRON GRID look + the luck-bar frame art

- **TRON GRID design pass** (user pick from 3 surveyed options): the grey
  concrete is gone — base arena floor = navy grid tiles
  (`dark_blue_tinted`) with a glowing blue-seam perimeter inlay ring (1u
  proud, +4 brushes); every landing + breather balcony = the pack's
  `_tinted_edge` glowing-seam tiles cycling blue/green/orange/red/yellow
  per lap; the rooftop gets the `_pap` themed payoff floor (+1 overlay
  brush). 2780 brushes, **BAKED 28.1s**. All material swaps otherwise —
  zero nav/layout change.
- **Luck-bar frame art wired** (user drop "files (7).zip"): 1024×128 PNG,
  window transparency VERIFIED (alpha ~5), installed as
  `i_tod_luck_frame` via the card-art image pipeline, drawn top-left from
  the always-on HUD Lua; the hudelem fill + percent readout re-seated
  inside the frame's transparent window (window fractions 9.8–88.4% ×
  22–78%). The frame carries the "LUCK" label; the text is now just "n%".

## 2026-08-20 (v5.2) — difficulty + balance tuning (user session)

- **Class speeds retuned**: 0.65/0.80/0.95/1.05 → **0.8 / 0.9 / 1.0 / 1.1**
  (heavy/assault/skirmisher/slasher).
- **Zombie sprint curve softened**: full sprint at round **10** (was 7);
  same 0.8 floor, same +0.3%/round after.
- **Round aggression toned down**: the seamless-round spawn trickle goes
  from 0.5× stock (floor 0.15s) to **0.8× stock (floor 0.3s)**; round-1
  delay 1.0 → 1.6s. The endless twist stays — the trickle just breathes.
- **GUN BALANCE PASS** (user: "pistol was doing 6 while the m60 did 100+"):
  script-side per-gun multipliers on raw damage (the Skye GDTs are shared
  with map 1 — never edited). GDT bases measured: ak74u 180 / krig 195 /
  m60 290-no-falloff / stock pistol ~25 with heavy falloff. Multipliers:
  **pistol_standard ×4.0, m60 ×0.85, ak74u ×1.1, krig ×1.05** — resulting
  spread ≈ pistol 100 / ak 198 / krig 205 / m60 246 (ballistic melee 500
  untouched). Applies to base + PaP + twins; non-class weapons keep the
  balance but no class multipliers. One tuning table:
  `gun_balance_mult()` in _tod_upgrades.gsc.

## 2026-08-20 (v5.1) — playtest round 2 fixes

- **Music louder**: ambient 68→85, boss 85→100 (the alias volume scale is a
  loudness curve; two live tests calibrated it).
- **Boss stuns REMOVED** (user: map-1-only mechanic): the RP zap no longer
  slows — pure chip damage + SFX; the Panzer electroball no longer zaps
  players at all (its GDT explosion damage stands). The whole
  tod_boss_slow_until plumbing is gone. **Bosses back to BASE speed**:
  Panzer anim 1.10→1.0, RP 0.85→1.0 AND map 1's permanent sprint lock
  removed (natural walk/sprint gait).
- **Menu jump suppressed**: menu_freeze now AllowJump(false) — holding
  A/JUMP to lock no longer hops the player (stock builtin; reads stay live).
- **Per-input menu text**: controller vs keyboard wording per player,
  detected client-side ("HOLD [ A ]" vs "HOLD [ SPACE ]"; nil-guarded with
  controller fallback). PS-vs-Xbox glyphs are NOT possible on PC BO3 — the
  engine only exposes gamepad-vs-KBM.
- **Door+class-switch bug FIXED**: the slasher station's r64 use-trigger
  overlapped the lap-1 door's r96 buy trigger — one USE press fired both.
  Station row moved west (x −390…−60, all ≥300u from the door triggers).
- **Upgrade list HUD**: a left-edge column ("UPGRADES / DAMAGE 4/10 …"),
  dim in play, `hidewheninmenu = false` so it reads over the pause menu
  (map 1's perks/objectives-panel mechanism).
- **Luck bar moved to TOP-LEFT** ("TOPLEFT" is a valid concatenated setPoint
  token — the BOTTOM family is not); image-frame art slot prompt sent to
  the user.

## 2026-08-20 (v5) — THE LUCK BAR + PERK SCATTER + shared-domain rework

- **THE LUCK BAR** (user design session): per-player 0..100%, bottom-left
  hudelem bar (`_tod_luck.gsc` — zero clientfield cost; the pool is at its
  61-bit ceiling). **Balance core**: per-kill luck = 40 × players ÷
  round_zombie_total (the stock spawn-budget formula) — a fair-share round
  clear earns ~+40% at ANY round number and ANY lobby size; more zombies per
  round automatically means less luck per kill. Headshot kills ×1.5.
  **LAST HIT TAKES ALL** (user): zombie, Protector (+4) or Panzer (+20) —
  the killer gets the luck; boss POINTS stay team-wide. Revive +15 (the
  reviver), door buy +8 (the buyer), going down −25. At upgrade time the
  bar scales the card odds linearly: 0% → 80/15/5 (regular/super/ultimate),
  100% → 20/50/30 — then **fully resets to 0** (user pick). The LUCK domain
  became **+10% luck gain rate per level** (user pick); the old integer
  event-luck is gone. Card readout: "LUCK n0% BOOSTED THESE ROLLS".
- **PERK SCATTER** (map 1's proven relocation engine ported to
  `_tod_perk_scatter.gsc`): 6 perks — Jugg, Speed, **Widow's Wine**, Quick
  Revive, **Electric Cherry**, Stamin-Up — land on RANDOM pads at load
  (silent, pre-blackscreen) and **reshuffle with the drop-in animation**
  (60u materialize-glide, de-rez bursts, warp booms, landing ka-chunk) on
  the round after each Panzer (6, 11, 16… ship / 4, 7, 10… dev). 11 pads:
  base ×2, NW landings 3/7/12/18, breather balconies 5/10/15/20, rooftop.
  QR is FIXED at the base-west pad (map 1's solo-revive carve-out); Mule
  Kick stays a roof fixture; DoubleTap retired from the roster. Map 1's
  correctness rules preserved (two-phase nav cut, keep-on-power-off flag,
  instant trigger/clip snap, player unstick); tower deltas: pads are
  shuffled too (pads > perks now) and pads live in GSC, not dvars.
  Machines PARK along the base N wall in the .map (graceful fallback);
  Widow's + Cherry placed as raw zm_perk_machine structs (no prefab exists —
  map 1's exact recipe), the rest via stock prefabs.
- **Widow's Wine + Electric Cherry wired** (map 1's finished custom cherry
  module on specialty_combat_efficiency, West-pack model, stock pipeline
  #usings in both entries for the tesla FX, costs 4000/3000, purple glow).
- **Shared-domain rework**: HEALTH → **DMG REDUCTION** (−4%/Lv all incoming,
  incl. Panzer melee via the mitigation hook). **Per-class base move speed**
  (user): HEAVY 0.65 / ASSAULT 0.80 / SKIRMISHER 0.95 / SLASHER 1.05 —
  script-side in the speed owner (the gun GDTs are shared with map 1, never
  edited). SPRINT/MOBILITY now **+3%/Lv** (was +2%).

## 2026-08-20 (dev kit) — v4.6.3: DEV + GOD MODES ARMED, upgrade cadence split

- **Dev + god modes** (map 1's doctrine — hardcoded in
  `tod_resolve_dev_flags()`, NEVER launch flags/dvars): **both TRUE right
  now** for the test sessions; flip false + rebuild to ship. God = demigod
  (all damage lands, health floors at 1 — the boss_player_damage clamp +
  the bridged mechz melee clamp).
- **Upgrade cadence split** (user): **round 1 ALWAYS** — the first cards are
  dealt the moment everyone locks a class (the draft flow runs the event
  while the world is still held: class pick → upgrade pick → round 1
  begins); then DEV = every round / SHIP = every 4th round. Full ship
  sequence: **1, 4, 8, 12, ...** Dev also keeps the early Panzer (round 3,
  every 3).

## 2026-08-20 (live-test fixes) — v4.6.2: input, ballistic triangle, RP nerf, silent music

- **Menu input FIXED** (live test: dpad/stick dead in both menus, timeout
  random-picked): `FreezeControls` zeroes the ENTIRE input snapshot — every
  button/stick read goes dead. Replaced with the SOFT FREEZE
  (`tod_upgrades::menu_freeze`): move speed pinned 0.001 via the move-speed
  owner + weapons/offhands disabled; input reads stay live. Jump-hop in
  place while locking = known + accepted.
- **Ballistic knife triangle FIXED**: the thrown blade rendered the
  error-triangle because stock ships only a dead 116-byte
  `_zm_weap_ballistic_knife.gsc` stub in usermaps — map 1's vendored full
  handler (thrown/retrievable machinery + world model) copied in + zoned;
  stock `_zm_weapons` #usings the namespace so no entry wiring needed.
- **Rogue Protectors nerfed ~25% + slowed** (user: "too good"): bullets
  28→21, cap 60→45, rocket 69→52, zap pulse 10→7, fire interval 2.5→3.0s,
  mahem cooldown 3.0→3.5s, run rate 1.0→0.85.
- **Silent music fixed**: alias volumes ride a loudness curve — 50 was
  near-inaudible under gunfire. Ambient 50→68, boss 75→85; the emitter also
  moved out of the solid core brush to open air at the spawn area
  (belt-and-braces — the aliases are 2d).
- (The Steam won't-quit hang recurred once and self-resolved; map 1 solved
  it before — port that fix if it comes back.)

## 2026-08-19 (hotfix) — v4.6.1: CLIENTFIELD OVERFLOW = the map-won't-load fix

- **Load-to-lobby fixed.** console_mp.log oracle: `Com_ERROR: Attempting to
  register ClientField zmhud.swordState ... clientuimodel is out of space` —
  the v4.4 class-draft fields pushed our custom clientuimodel usage to 83
  bits and the SHARED pool (stock zmhud.* + Aetherium register there too)
  overflowed; a stock field failed to register and the engine aborted the
  map load back to the lobby.
- **Fix = back to the proven 61-bit budget**: the class draft and the
  upgrade panel are never on screen together, so the draft now RIDES
  `todUpgFocus`/`todUpgTime`/`todUpgHold` and owns only `todClsShow` (2
  bits). Draft countdown is halved into the 4-bit time field (Lua displays
  ×2 — ticks 30, 28, 26…); the picked class = focus at show==2; the draft's
  server blink dropped (steady bright accent + the hold bar carry focus).
  Trims: `todDmgNum` 18→13 bits (crosshair numbers display-cap 2047),
  `todMagBonus` 8→7 (chip caps +127; the real pool is server-side).
- **The budget is now documented at the registration site**: 61 custom bits
  total; adding any field needs an equal trim.

## 2026-08-19 (waves) — v4.6: PANZER MUSIC + THE FINAL BOSS CADENCE

- **PANZER = every 5th round, with his own track** (user: "when it spawn in
  this music plays... when killed the game music starts back up"): "Data
  Spike" by Psychronic (48k already, vol 75) owns the channel while any
  Panzer lives; the ambient loop resumes when the last one dies. Refcounted
  channel swap in `_tod_atmosphere` (boss_track_start/end — the module owns
  ALL music now); the ambient restarts from the top on resume (streams can't
  pause — by design). HP re-anchored to round 5 (base 24000).
- **ROGUE PROTECTOR WAVES = every 3rd round, wave size = round × 2** (user:
  "multiply by 2x to get the amount spawning in"): round 3 = 6, round 6 = 12,
  round 9 = 18... The debt trickles them one per director tick under a
  **concurrency roof of 8 alive** (counted live off the AI list — the engine's
  AI budget must keep feeding zombies or endless rounds starve); the rest of
  the wave enters as the front line dies. Per-unit HP dropped to a WAVE curve
  (7000 @ r3, ×1.07/round — the old solo-boss curve would make a wall);
  per-unit reward 250 pts + 1 luck, QUIET (no per-kill banners — the
  wave-arrival banner + real luck gains carry it; add_luck no longer prints
  at the cap). Panzer outranks the wave in the spawn queue.
- Credits: "Data Spike" — Psychronic (with "Password Infinity" — Evgeny
  Bardyuzha; both in CLAUDE.md's pre-publish list).

## 2026-08-19 (tower) — v4.5: BREATHER LANDMARKS + BOSS MUSIC

- **BREATHER BALCONIES at laps 5/10/15/20** (user: "every 5 or so levels you
  have a breather landmark"): the NE landing opens north into a wide flat
  platform (288×272 usable, lap-neon parapets, own light) — the SAME laps as
  the wallbuys, so every breather is a restock stop; the rooftop is lap 25's.
  Generator-side (`BREATHER_LAPS`/`BR_DEPTH`/`BR_EAST` tables): floor flush
  with the landing (navmesh merges), the landing parapet opens into it, an
  extra zone-volume brush per breather lap, umbra/fpstool bounds widened to
  cover. Net +12 brushes (2775 total) — **LED bake PASSES (27.6s)**.
- **MUSIC (redirected same-day)**: boss music was built (map 1's refcounted
  channel) then REMOVED on the user's call — the map instead plays **one low
  ambient track on repeat for the whole game**
  (`_tod_atmosphere::ambient_music`, alias `tod_ambient_music` @ vol 50,
  LOOPING/STREAMED/2d, PlayLoopSound on a script_origin from blackscreen —
  never stopped, game-long by design). Placeholder wav = map 1's calm city
  track; the real song drops at `sound_assets/tod/music/` (README there) +
  a FileSpec swap. `sync_to_modtools.ps1` now syncs repo `sound_assets/` to
  the tools root so the future wav deploys from the repo.

## 2026-08-19 (ui) — v4.4: CLASS DRAFT + UPGRADE-UI FEEL (focus, hold bars, stings)

- **GAME-START CLASS DRAFT** (user: "each player must select a class before
  the game starts... 30s max... random if not selected"): after the intro
  fade the world holds (the upgrade-pause mechanism — round 1 won't spawn),
  every player gets a 4-card panel (`tod_class_select.lua` + 
  `_tod_class_select.gsc`, the proven 4-file LUI contract): per-class neon
  identity colors, role/gun/upgrade-path text, D-pad/stick cycling with
  per-source edge latches, HOLD JUMP to lock with a fill bar, server-driven
  accent pulse. 30s cap → random class. Early lockers get controls back;
  hot-joiners after the draft get a random class; the base stations sleep
  until the draft closes (two-primary race fix) and remain the switch path.
- **UPGRADE-UI FEEL**: the focused card no longer opacity-flickers — full
  presence + a soft accent pulse; a teal **hold-progress bar** fills while
  locking (`todUpgHold`); focus moves click, locks confirm. **RARITY
  STINGS**: revealing a SUPER plays a level-up chime, an ULTIMATE plays the
  jackpot sting (highest rarity on the table wins).
- **6 UI sounds** = map 1's proven wav kit via `sound/aliases/tod_ui.csv`
  (glass tick, implant lock, level-up, diamond-found, cyber jack-in,
  reactor-online draft opener) — all install-side wavs, aliases baked.
- Clientfields: +6 appended in lockstep (`todUpgHold`, `todClsShow/Focus/
  Time/Pick/Hold`) — `_tod_upgrade_ui` gsc/csc stays the ONE registration
  home.
- **Adversarially verified** (3-skeptic pass), fixed: ghost second card on
  single-option rolls; the confirm flash being invisible under frame art;
  stale accent alphas; the draft/station two-primary race; d-pad/stick latch
  cross-talk; icon-mode layout collision (pre-cleared for the class icons);
  the lying "left card auto-selected" timeout message; stale lockstep-contract
  comments. Accepted: the stock ROUND 1 fanfare plays mid-draft (cosmetic).

## 2026-08-19 (bosses) — v4.3: PANZER + ROGUE PROTECTORS (boss kills = luck)

- **Two bosses ported from map 1** (user: "add a panzer... and some rogue
  protector robots every so often... steal this from the other map"):
  - **PANZER** (Spiki mechz pack, vendored `mechz_spiki.gsc/.csc` with map 1's
    crash fixes intact): every 8 rounds from round 10 (count scales, cap 2).
    Run rate 1.10, body-damage rebuffed 0.1→0.35, honest headshots (0.9× on
    j_faceplate r36 / head hitlocs), melee pass-through, electroball grenades
    impact-detonate + apply the boss zap slow, +10% explosive lane.
  - **ROGUE PROTECTOR** (HB21 civil protector re-teamed axis via the
    install-side `acc_zod_robot_boss` clone GDT; vendored zod script set with
    the floating-name strip): every 4 rounds from round 5 (cap 3). Slam-down
    entrance (boss-excluding kill splash — the map 1 spawn-die-loop fix),
    sprint-locked hunt, script-driven fire (4 chip bullets base 28
    proximity-ramped ×3 capped 60, 5th shot = a real s1_mahem rocket capped
    69, knockback), close-range zap (-30% slow 3s + 10 AoE).
  - **NO healthbars** (user) — only the attack-FX pulse clientfields were
    ported (`_tod_boss_fx.gsc/.csc`: shot/zap/mahem client-side FX + the
    "Civil Protector" name stomp).
- **THE HOOK — boss kills pay event luck**: every player gets +1 luck / +500
  pts per Protector, +2 luck / +1000 pts per Panzer (`tod_upgrades::add_luck`
  — shifts the next upgrade card's rarity odds; luck spends on the roll).
- **Spawns are player-anchored** (the fight climbs 25 laps — no fixed anchor):
  bare `SpawnActor` at a navmesh point near a random living player, clear of
  players (100u) and living bosses (150u). NO .map spawner entities — both
  aitypes crash them (map 1 proven).
- **Upgrade-pause integration**: bosses freeze with the axis sweep; spawn
  paths gate on the pause (the RP aborts mid-telegraph); a symmetric per-boss
  pause watcher applies/restores ignoreall + anim rate (covers mid-pause
  arrivals); Protector damage numbers/multipliers ride an event-stamp latch
  so the actor chain and the per-boss feed can never double-apply.
- **Adversarially verified** (4-skeptic pass): fixed the mechz↔driver #using
  cycle (KB rule — now a level function pointer), the double-multiplier feed,
  the spawn-into-pause races, the -25%→-30% zap slow drift, the missing
  jet-leg FX line, the luck-at-cap banner. Waived-by-precedent (map 1 shipped
  identically): 6 linker asset errors (electroball materials, mechz.zpkg,
  p7_zm_zod_fuse — now in build_map.ps1's waived list) + a handful of
  unresolvable vendored aliases.
- Build: 38.41 MB .ff (+5 MB, the mechz pack's predicted size); 248 mechz /
  461 zod / 537 companion manifest entries; both boss aitypes packed.

## 2026-08-19 (ballistic) — v4.2: BALLISTIC SLASHER + ADS + penetration verdict

- **SLASHER re-primaried to the Ballistic Knife** (`knife_ballistic`, PaP
  form `_upgraded`) with the Bowie riding along as alt melee — solving the
  "bowie untwinnable" dead end via the user's map 1 memory: the ballistic's
  source GDT exists (`wpn_t7_loot_ballistic_knife.gdt`, latin1,
  projectileweapon.gdf) and map 1's Berzerker recipe proves
  meleeTime/meleeChargeTime twins work. **KNIFE SPEED (id 18, 3 Lv,
  ×0.88/0.78/0.68) is LIVE** — 6 new variants `knife_ballistic[_upgraded]_k1-3`
  (asset names carry `_zm`, stripped at runtime). Thrown twin blades stay
  retrievable via `_tod_ballistic.gsc`
  (zm_weapons::add_retrievable_knife_init_name per variant). Sounds =
  map 1's alias CSV, wired in the .szc (alias.sz grew 251,480→267,148 —
  baked). reconcile_twin now honors per-class `up_suffix`.
- **ADS folded into HANDLING** (user request): the h1-3 handling axis now
  scales the ADS-time keys alongside reload+swap (grid regenerated).
- **PENETRATION for the LMG: honestly declined** — the M60 base GDT already
  ships `penetrateType "large"`, the engine max; no ladder exists. RANGE
  (damageRangeScale) documented as the alternative.
- Ledger: **50 registrations** = 8 gun forms + 42 twins (~180 headroom).
  Errorlog: only the 16 `mtl_wpn_t7_knife_combat` no-techset warnings —
  byte-identical to map 1's shipped errorlog (knife rendered fine there);
  waived by precedent.

## 2026-08-19 (twins) — v4.1: THE TWIN INTEGRATION (36 real gun-data variants)

- **All buildable twin domains are LIVE**, per the 3-level gun-data rule:
  skirmisher FIRE RATE (fireTime ×0.92/0.84/0.76) × HANDLING (reload+swap
  ×0.85/0.75/0.65) as a 15-combo grid; assault RECOIL (kick ×0.75/0.55/0.35).
  36 variant assets (base+_up each) generated by `tools/gen_tod_twins.js`
  (map 1's proven field sets/extraction; INT-damage trap honored), zoned via
  `include,tod_twins`, CSV-mapped so Pack-a-Punch works on every variant
  (in_box FALSE — marker-free CSV patch, comment rows would poison the table
  parser). Verified: 1157 manifest entries, 0 errorlog hits.
- **In-place swaps**: `reconcile_twin()` — instant on upgrade + a 1s
  self-healing pass in the body loop (covers respawn re-gives, class
  switches, PaP transitions); preserves clip/reserve/PaP form/held state;
  never takes the gun if the target variant isn't linked.
  `is_class_primary` now substring-matches so variants keep every gun-bound
  domain (damage/echo/mag/bounty...) working.
- KNIFE SPEED verdict: **untwinnable** — the stock bowie ships compiled-only
  (no source GDT anywhere, incl. the T7 GDT backup); slasher keeps 3 active
  signatures. Domain-id fields widened to 5 bits (ids 15-17).
- Ledger: **44 registrations** (~194 headroom under the ~230 budget).

## 2026-08-19 (later) — v4.0: the class matrix (user redesign)

- Roster: **SKIRMISHER** (AK-74u, was RECON), ASSAULT (Krig 6), HEAVY (M60),
  **SLASHER (melee — stock bowie_knife, replaces MEDIC)**. Streetsweeper
  stays zoned but unassigned.
- Shared core: DAMAGE / HEALTH / BOUNTY / **LUCK (permanent, stacks with
  event luck)**. Signatures: skirmisher SPRINT (+ tireless at Lv 5 via
  staminup specialty — no engine sprint-meter lever); assault HEADSHOT /
  MAG SIZE / RESERVE; heavy MOBILITY / **BULLET FEED (reserve→mag trickle)** /
  ECHO / REGEN; slasher SPRINT / LEECH / **CLEAVE (melee AoE, recursion-
  guarded)**. TOUGHNESS dropped (not in the new spec).
- Twin-phase domains (FIRE RATE, HANDLING, RECOIL, KNIFE SPEED) designed +
  costed but NOT registered (no dead cards). Ledger: 8 registrations, 0 twins.
- docs/upgrade_system.md rewritten to v4.

## 2026-08-19 — v3.0: class-specific upgrade pools + MEDIC (4 classes, 11 domains)

- **MEDIC class** (Streetsweeper auto-shotgun — altWeapon-screened, map 1
  sound rows copied, CSV+zone wired); 4 select stations re-spaced.
- **Class-gated domains with per-domain depths** (user design): 5 shared
  10-level core (DAMAGE / ECHO ROUNDS [the honest rename of the old
  fire-rate double-hit] / MAG SIZE / BOUNTY / HEADSHOT) + 2 signatures per
  class: RECON SWIFTNESS 10 + SCAVENGER 5, HEAVY VITALITY 10 + TOUGHNESS 5,
  MEDIC REGEN 10 (with 256u half-strength ally aura) + LEECH 5. ASSAULT's
  FIRE RATE 3 + HANDLING 3 = the real twin-swap phase, designed and costed
  (~30 registrations, assault-only) but NOT yet built. Body domains persist
  across class switches; gun domains auto-scope to the current class gun.
- Plumbing: domain-id fields widened to 4 bits (gsc/csc lockstep), Lua DOMAIN
  table carries per-domain caps so card level previews clamp correctly.
- Full reference: docs/upgrade_system.md. Twin ledger: 8 registrations,
  0 twins.

## 2026-08-19 — v2.2: BOUNTY + HEADSHOT upgrade domains (5 total)

- **BOUNTY** (+3% money per class-gun kill per level): rides the real
  per-zombie death callback; bonus computed off the nominal kill value
  (melee 130 / headshot 100 / bullet 60) and BANKED — zm_score rounds up to
  10s (KB trap), so fractions accumulate and pay out in exact 10s.
- **HEADSHOT** (+10% headshot damage per level): additive with DAMAGE in the
  damage-callback multiplier, applies on head/helmet hits.
- Domain-id clientfields todUpgAD/BD widened 2→3 bits (gsc+csc lockstep;
  5 domains need ids 1..5); Lua DOMAIN table mirrored; missing domain icons
  hide their slot instead of falling back to the damage icon.

## 2026-08-18 (post-first-playtest) — v2.1: live-feedback fixes + Aetherium HUD

First real playtest of the full tower (after the 19-day-uptime reboot fixed
the stock-boot crash). User feedback, all addressed:

- **Zombie speed**: round-1 sprint rate 0.5 read "practically frozen"
  (root-motion playback scales ground speed too) — floor lifted to 0.8,
  still full sprint at round 7.
- **Virtual mag FIXED**: the engine auto-reloads at clip=0 and was eating the
  refeed. Pool now refeeds at <= 2 rounds left (counter visibly jumps back up
  mid-burst), and the pool size shows as a cyan "MAG +N" chip by the ammo
  counter (new todMagBonus clientfield).
- **Upgrade UI rework** (user: "not intuitive, you can still run around"):
  players are now FROZEN during the choice (skipped in laststand); a card is
  ALWAYS focused (left default) and blinks; switch with D-PAD left/right, the
  move stick/strafe keys, or aim/fire; HOLD JUMP (A / space) 0.5s to lock
  (blink speeds up while holding); timeout locks the FOCUSED card.
- **Aetherium HUD ported** (pristine Owen-C137 kit — NOT map 1's acc-rewired
  fork): fonts/localizedstrings/kit gsc+csc/full ui tree + zone
  `include,aetherium_hud`; kit model_export assets were already installed
  install-side by map 1. The kit self-inits via REGISTER_SYSTEM (README's
  #using-above-zm_usermap in both entries). Fixed the kit's zm_aetherium.str
  missing the VERSION/CONFIG header (map 1's documented zero-strings trap —
  took their fixed copy). Door hints reworded to "Open Door to <dest>" so the
  kit's door card parses the destination.
- **Crosshair damage numbers ported** (map 1's design): pool of 12 scattered
  rising/fading numbers at the crosshair, amber normal / teal+bigger
  headshots; new 18-bit todDmgNum clientfield (dmg*4+headshot*2+parity),
  fed from the upgrade damage callback for ALL player hits.

## 2026-08-18 (overnight) — v2.0: THE FULL TOWER (25 laps, 3 classes, atmosphere)

User mandate before bed: "finish out the map — up to 25 layers, two new
classes, nice atmosphere." All built + full-pipeline verified; NOT yet
boot-tested (see the boot-crash note below).

- **25-lap tower** (was 3): top z=19200, 2763 brushes / 314 entities — and it
  BAKES (LED 21.3s, the atlas ceiling did not bite; `PARA_EVERY` in the
  generator is the fallback knob if future geometry regresses it). 27 zones
  (base + 25 laps + roof) wired by loop in the entry script; 26 buyable doors
  (750 +250/lap, capped 4000; roof 5000). Neon palette CYCLES 8 colors lap by
  lap (cyan→purple→pink→green→orange→yellow→red→blue; all GDT-verified).
  Progression ladder: Jugg lap 3, Speed lap 7, Stamin-Up lap 12, Double Tap
  lap 18; wallbuys laps 5/10/15/20 (AR/SMG/CQB-AR/shotgun); rooftop payoff =
  Pack-a-Punch + Mule Kick. Reflection probes every 3rd lap.
- **Two new classes** (`_tod_classes.gsc`): RECON = AK-74u (`t9_ak74u`),
  HEAVY = M60 (`t9_m60`) — both altWeapon-screened (boot-safe), weapon CSV
  rows + zone lines added, sound aliases copied verbatim from map 1's proven
  CSV (incl. the ak74u's cross-named t5_tishina foley). Sound bank grew
  3.3→8.6 MB, 0 errorlog hits. **Class-select stations**: 3 hold-USE triggers
  along the core's south face in the base arena — switching swaps the primary
  (old class gun taken), upgrade levels stay per-player.
- **Atmosphere** (`_tod_atmosphere.gsc`): scripted volumetric city smog
  (SetVolFog, map 1's verified 8-arg recipe) — cold purple-blue, dense at
  street level, halving every 1200u of altitude: you climb OUT of the smog
  into clear night under the Miami dome. Linker-only; can't regress the bake.
- **BOOT-CRASH ROOT CAUSE FIXED** (the "game isn't loading" report, crashes
  1:41 + 1:42 AM): silent 0xC0000005 mid-DB-load = map 1's documented
  CORRUPT SOUND BANK incident (a build regenerated banks while the game held
  the .sabs lock). Fix: game-closed bank nuke + clean regen (CachedBanks
  layout now matches map 1's working install) + **build_map.ps1 now REFUSES
  to build while BlackOps3 is running** (the missing guard).
- Boot verification attempted overnight: the game would not LAUNCH headlessly
  (Steam was fully closed; a cold silent Steam start drops launch requests —
  no new dumps/logs, so no evidence of a game-side failure). First morning
  launch = the real test.

## 2026-08-18 (art drop 2) — v1.5.1: COMPLETE card art set

- The remaining 5 assets arrived ("files (6).zip") and are live: card base
  plate (1024×512 dark hex-glass, chamfered, header band), 3 domain icons
  (256×256 white-on-cyan-glow: impact burst / triple bullets / mag+),
  title plate (1024×128 tapered cyan banner). Frames byte-identical to drop 1
  (untouched). All 8 `i_tod_*` assets in the GDT + zone; all 4 Lua art flags
  ON — the flat-glass fallback is now dormant code. Verified: 8/8 in the
  packed-asset manifest, 0 errorlog image errors, .ff 23.96→24.44 MB.

## 2026-08-18 (art drop 1) — v1.5: rarity frame art wired in

- **The 3 rarity card frames are LIVE** (user's "files (2).zip": 1024×512 RGBA,
  transparent centers — silver/cyan/amber neon borders with gems). Installed
  as `i_tod_frame_*` image assets (`source_data/tod_ui_images.gdt`, the map 1
  image.gdf recipe: uncompressed, sRGB3chAlpha, noMipMaps, PNGs vendored at
  `source_data/tod_ui_images/_images/`), 3 `image,` zone lines. Verified: 0
  errorlog image errors, all 3 in the packed-asset manifest, .ff grew
  23.37→23.96 MB.
- **Lua art flags are now per-piece** (`USE_FRAME_ART` on; base plate / domain
  icons / title plate still pending from the art pass — flat-glass fallback
  composites under the PNG frames, which is the intended layered look anyway).
- **Pipeline upgrades**: sync_to_modtools now deploys repo `source_data\` GDTs
  (COPY, never mirror) and build_map runs `gdtdb /update` automatically when
  repo GDTs exist (the linker never refreshes the DB itself — map 1's
  deploy_perk_shaders lesson, now built into the standard build).

## 2026-08-18 (later still) — v1.4.1: exact rarity odds

- Rarity roll is now the user-specified table, rolled independently PER CARD:
  base 80% regular / 15% SUPER / 5% ULTIMATE; each luck tier −10% regular,
  +5% SUPER, +5% ULTIMATE (always sums to 100; RandomInt(100) direct).
  Luck caps at 8, where regular hits 0% (55% SUPER / 45% ULTIMATE);
  add_luck clamps to the cap so the HUD luck number always matches real odds.
  (User's 2-luck example said 50% regular — the stated deltas give 60%;
  implemented the self-consistent version.)

## 2026-08-18 (later) — v1.4: upgrade UX polish + art-ready

- **15s selection window** (user; was 30) with an on-screen countdown under
  the cards ("AUTO-SELECTS THE LEFT CARD IN Ns", red at ≤5s) via a new
  `todUpgTime` clientfield (10th field, appended last in gsc+csc lockstep).
- **"CHOOSING: name, name" waiting line** (co-op only): everyone sees who
  hasn't locked in yet — server hudelems, change-guarded, bounded strings
  (≤4 player names, string-cache safe); cleaned up when the event ends.
- **Timeout messaging**: an auto-selected player is told "^3Time! The left
  card was auto-selected:" before the upgrade confirm line.
- **Edge cases**: event pause caps at 20s no matter what (disconnect leak
  guard); fully-maxed players are excluded from events and told ONCE (no
  per-round spam); when EVERYONE is maxed the event skips entirely (no
  pause); zombies take ZERO damage while frozen (upgrade_damage_cb returns 0
  during the pause — kills the free-damage-window degenerate strategy);
  ADS+ATTACK held together = no pick.
- **Art drop-in pre-wired** (`USE_ART` flag in tod_upgrade.lua): base plate /
  per-rarity frames / domain icons / title plate render as LUI.UIImage slots
  the moment the 8 `i_tod_*` image assets are installed + zoned; flat panels
  remain the shipped fallback until then.

## 2026-08-18 — v1.3: real LUI upgrade panel + every-round upgrades

- **Upgrade cadence: EVERY round** (user; was every 3) — from round 2 on.
- **The upgrade UI is now real LUI** (`ui/uieditor/menus/hud/tod_upgrade.lua`,
  map 1's 4-file contract + clientuimodel bridge): dark-glass title plate +
  two side-by-side cards with rarity-colored accent strips (regular
  silver / SUPER cyan / ULTIMATE amber), Lv X→Y readout, effect line, luck
  banner, fade tweens. 9 all-INT clientfields (25 bits — todUpgShow/AD/AR/AL/
  BD/BR/BL/Luck/Focus), registered in gsc+csc lockstep
  (`_tod_upgrade_ui.gsc|.csc`); every visible string lives client-side in the
  Lua (zero istring/BG-cache cost). L3akMod compiled it clean (fresh .ff).
- **Hover states** (user): HOLD-to-confirm input — holding AIM/FIRE focuses
  that card, the focused card BLINKS opacity (server toggles the focus
  clientfield at ~7 Hz — client UITimers are the map 1 leak trap), 0.5s hold
  locks in ("LOCKING..."), release cancels, chosen card teal-flashes. Also
  prevents accidental picks (FIRE still shoots).
- Card art is engine-text-only for now; PNG art slots in later via
  RegisterImage (image-gen prompt handed to the user).

## 2026-08-18 — v1.2: class system + THE UPGRADE TOWER (Krig 6)

- **Class system** (`_tod_classes.gsc`): scalable registry — a class = primary
  gun + secondary, given on every spawn. v1 ships Assault = **Krig 6**
  (`t9_krig6`, Skye CW port, installed; altWeapon screened empty = boot-safe)
  + pistol secondary. Wiring per map 1's docs/21 runbook: zone weapon lines,
  custom `gamedata/weapons/zm/zm_levelcommon_weapons.csv` (stock + krig row),
  sound aliases `sound/aliases/tod_weapons.csv` GENERATED by
  `tools/gen_krig_sounds.js` (clones map 1's proven t9_ak47 fire-chain rows —
  identical wav sets — + krig foley with round-robin collapse; templates ride
  the installed template_skye_t9_sounds.csv). Sound bank grew 1.0→3.3 MB ✓.
- **THE UPGRADE TOWER** (`_tod_upgrades.gsc` + `_tod_upgrade_ui.gsc`): every 3
  rounds (4, 7, 10…) the world pauses (stock `world_is_paused` flag halts
  spawning; live zombies frozen + ignoreall) and each player picks ONE of TWO
  rolled options: domain (damage / fire rate / mag size, cap Lv 10) × rarity
  (REGULAR +1 / SUPER +2 / ULTIMATE +3 Lv). LUCK (`tod_upgrades::add_luck`,
  fed by future boss kills/tasks) shifts rarity odds, resets each event.
  UI v1 = hudelem cards, AIM = top / FIRE = bottom, 30s timeout;
  presentation isolated in `_tod_upgrade_ui` for a future LUI swap.
- **NO-TWIN ARCHITECTURE** (the scalability answer): upgrades NEVER create
  weapon variants — map 1 measured the engine's ~230-twin boot-AV ceiling
  (docs/21 §A); a 10-level matrix would be thousands. One asset per class gun:
  damage = actor-damage-callback multiplier (+12%/Lv); fire rate = DT2-style
  echo-bullet proc (+10%/Lv chance to double-hit — true ROF is asset-baked);
  mag size = virtual bottomless-mag pool (+20% base clip/Lv, clip auto-refeeds
  at 0, real reload refills the pool). Adding a class or domain costs zero
  weapon slots.

## 2026-08-17 (night) — v1.1: small base ring + faster round turnover

- **Base arena shrunk** (user: "small square area to walk around, ~1/3 of last
  time"): half-extent 704 → 540, leaving a 104u-wide ground ring around the
  tower footprint (walkable area ≈ 1/3 of v1). Spawns/perks/box/power/lights/
  risers/probe all pulled in to fit.
- **Faster round turnover** (user: "rounds didn't seem to start up as
  quickly"): the seamless-round clock is really the per-zombie spawn trickle —
  stock 2.0s (solo R1) decaying 0.95/round. Now chained at HALF the stock
  delay (floor 0.15s), round 1 pre-set to 1.0s, the one-time pre-round-1 stall
  2s → 1s, and tod_round_wait overhead trimmed (0.5s settle + 0.1s polls).

## 2026-08-17 (later) — v1: THE SPIRAL TOWER

- **Full geometry redesign** (user clarified "tower map" = spiral): solid
  256-half-extent neon core, open-air staircase spiralling CCW around it
  (3 laps × 4 flights of 16×12u steps + corner landings), base arena at the
  bottom, rooftop arena (PaP + Double Tap) on the core top; final landing
  overlaps the core's SE top corner so the roof connects walkably. Parapets
  (+ a tall lap-1 anti-bypass wall and clip blades over every door) keep
  everyone on the path. 343 brushes, 86 entities — bakes clean (5 MB .led).
- **Colorful night-cyber theme**: eMoX Vertigo neon-grid emissives — core/step
  bands + parapets cyan→purple→pink per lap, blue base walls, red door slabs,
  yellow roof rail; colored omni per landing; Miami night skybox all around
  (no outer shell — the sky enclosure is the seal).
- **Zones/doors**: base_zone → lap1/2/3_zone → roof_zone; 4 buyable doors
  (750/1000/1250/1500) at each lap start + the rooftop flight.
- **Power switch moved to the BASE** (user); Quick Revive + SMG wallbuy +
  mystery box + power at ground, Jugg lap 1, AR wallbuy + Speed lap 2,
  Stamin-Up lap 3, PaP + Double Tap on the roof.
- **Zombie speed curve** (`_tod_zombie_speed.gsc`, user spec): sprint anim from
  round 1 at 0.5 rate → 1.0 linearly by round 7, then +0.3%/round unbounded;
  1.5s keep-alive re-assert (map 1's decay lesson), boss/slow guards kept.
- **Perk power-on glow ported from map 1** (`_tod_perk_lights.gsc|.csc`):
  todPerkGlow clientfield → client-side colored auras on power-on, per-perk
  colors + PaP teal via invisible tag_origin host; proximity re-kick replaces
  map 1's depth-band re-kick. FX sources vendored in `share/raw/fx/acc/light/`
  (synced to the tools share tree by sync_to_modtools.ps1).

## 2026-08-17 — v0 scaffold: the tower stands

- **Repo scaffolded** from the abandoned_cyber_city_zombies playbook (its
  `docs/BO3_MAPMAKING_KB.md` copied here; tools ported: `build_map.ps1`,
  `sync_to_modtools.ps1`, `run_game.ps1`, `_bake_test.ps1`, `PLAY_NORMAL.bat`).
- **Generated tower greybox** (`tools/gen_tower_map.js` →
  `map_source/zm/zm_tower_of_doom.map`): Street Lobby (spawn) + Mezzanine (L1)
  + Sky Offices (L2), 1408×1408 footprint, 384u floor-to-floor, two switchback
  stairwells (12+12 steps of 16u rise / 28u tread), buyable stairwell doors
  (750 / 1250), clip-sealed window openings per floor, 20 baked lights,
  3 reflection probes, sky enclosure. Skybox `skybox_t9_mp_miami` +
  `acc_ssi_miami_night` (Nastian T9 pack, installed in Mod Tools).
- **Zones**: start_zone → level1_zone (`enter_level1`) → level2_zone
  (`enter_level2`); 4 risers + dog struct per zone.
- **Placements**: Quick Revive + SMG wallbuy + mystery box start (L0), Jugg +
  AR wallbuy (L1), Speed Cola / Double Tap / power switch / Pack-a-Punch (L2).
- **THE TWIST — endless rounds** (`_tod_endless_rounds.gsc`): next round starts
  when the last zombie of the current round SPAWNS. Overrides
  `level.round_wait_func` (wait for zombie_total==0, not all-dead),
  `level.zombie_round_change_custom` (no fanfare stall),
  `level.func_get_delay_between_rounds` (0s). Verified against the stock
  `_zm.gsc` mirror.
- **Doors** (`_tod_doors.gsc` + generated `_tod_door_data.gsc`): the map 1
  script-spawned dual-trigger buy recipe (map triggers are dead for generated
  maps; TriggerIgnoreTeam required; slab Solid+DisconnectPaths until bought).
- **Entry scripts** from the stock template + map 1 hooks: dog rounds off,
  500 start points, pistol start, `tod_dev`/`tod_god` compile-time dev flags
  (ship = false).
- No Aetherium HUD, no Mega Bottles, no Data Shards — stock BO3 HUD only.
