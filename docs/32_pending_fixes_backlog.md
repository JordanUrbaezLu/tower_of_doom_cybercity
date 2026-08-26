# 32 — PENDING FIXES BACKLOG (frozen 2026-08-23, "push out what we have")

The user paused all open threads to ship the beta build. EVERYTHING BELOW IS
RECORDED, NOT FIXED. Work the list top-down next session; nothing here blocks
the current upload.

## 1. THE "1 FRAME" PERFORMANCE REPORT — ROOT CAUSE FOUND (hunt completed post-freeze)
24 agents, 5 confirmed / 13 refuted. THE CAUSE (2x CRITICAL, both in the
vendored Aetherium kit — map 1 hit and FIXED both on 2026-07-04; this repo
vendored the pristine unfixed kit on 2026-08-19):
- AetheriumPowerupNotification.lua:206 — compounding never-closed UITimer
  cascade per Max Ammo notification (quadratic growth; map 1 blamed this exact
  code for "gradual frame decay" + a round-26 4p state-pool crash).
- AetheriumLoadout.lua:170/248 — 2 never-closed repeating UITimers per weapon
  swap (map 1 memory: "the monotonic frame decay").
STATUS: fixed the same evening by porting map 1's proven close-before-create
hunks (the one exception to this freeze — shipping without it re-ships the
worst beta complaint). Also confirmed, RECORDED not fixed:
- [major, historical] the pre-v10.3 protector '+=' debt — already fixed; the
  verifier notes even the old build capped CONCURRENT protectors at 8, so this
  contributed stalls, not the 1-FPS death.
- [minor] ~~_tod_powerups.gsc:422~~ max_ammo_clip_watch leaked threads per
  player RESPAWN — **FIXED 2026-08-26** with the standard `tod_*_on` latch
  (function is at `max_ammo_clip_watch`, not :422). It was TWO copies per
  respawn, not one: a co-op bleed-out dispatches `on_player_spawned` twice
  (`_zm.gsc:3338` then `_globallogic_spawn.gsc:465`).
- [minor] door hint re-stamps can mint up to ~208 unique trigger-strings
  worst-case vs the ~250 cache (proximity gate mitigates; watch if more hint
  sources are added).
## 1b. RENDER/OCCLUSION HYPOTHESIS — CLOSED, REFUTED (peer's own retraction)
The peer's verifiers recomputed the actual load off the shipped .map: 17,742
brush faces / ~35k triangles across ~30 materials — trivial. 125 lights + 20
probes are emitted once and never touched at runtime. Verdict: 'does not
contribute to the reported collapse.' CLOSED so nobody spends a session on
portalling. Also refuted: any boss-actor runaway (concurrency hard-capped
1+8+3=12 against LIVE counts, no drift possible).

MARKER DECODE (keep — it unifies the reports): '2nd stage' and '3rd pap' are
the SAME ladder — the breather PaP machines at floors 10/20/30/40. Aodi's
'2nd stage' = floor 20, CZ's '3rd pap' = floor 30: progress proxies for
elapsed time AND PaP-ceremony count, exactly what the Loadout timer leak
predicts. NET: two independent workflows (one per session) converged on the
Aetherium UITimer leaks from opposite directions, with every alternative
refuted — as good as pre-live evidence gets. IF the 1-FPS reports persist
after this upload, the next move is a LIVE check (fps graph while climbing +
a no-HUD control), NOT more source reading.

BONUS (ship-build confidence): a verifier independently recomputed the door
ladder off the GENERATED door data — 10,200 / 26,400 / 48,600 to floors
10/20/30 — confirming the v10.4 economy is live in the .ff.

## 1c. CZ's '3rd PaP lag' — CORROBORATES the loadout leak (peer-confirmed)
Full thread obtained (3 reporters). CZ: 'i get to 3rd pap and lag kicks in like
crazy tried multiple times always when get upto 3rd pap.' An ORDINAL-pinned,
reproducible collapse is the signature of an EVENT-COUNT leak — exactly the
AetheriumLoadout per-weapon-name-change timer+handler leak (fixed v10.6), and
none of the other hypotheses predict it. AMPLIFIER (peer analysis, filed): this
map's give-before-take PaP makes ONE ceremony several weaponName transitions
(pistol/base -> new form -> settle + forced switch), so a PaP costs ~4-8 leaked
timers+handlers pre-fix, not 2; class draft + tier cards + grenade toggles add
more. Treat post-fix CZ feedback as the verdict on the whole cluster.
RENDER HYPOTHESIS: downgraded for CZ (peer retracted); stays weakly OPEN for
Aodi only (spatial language; no-portal open spiral is a real cost invisible to
a Lua audit) — one live check someday, not a fix.

## 1d. Gabyto51: 'No picks No clicks' — NOT A BUG (marketing)
Workshop idiom: 'no pics, no clicks' — the item page has no screenshots. File
under release: take 4-6 in-game shots (base arena, spiral, breather, crown,
Tron-grid look, finale road) and add to the Workshop page. The user already
asked Gabyto to explain and should reply once shots are up.

## 1e. ASK THE USER: their own reply 'Seems like its impacting all the games'
is ambiguous (all playthroughs affected vs all games on their machine lag).
Clarify before it steers anything.

## 1f. NEEDS-VERIFICATION: tier card taken while holding the PISTOL
CZ: "if holding your pistol and you get the option for a new gun it will swap
your other gun for it" — that is the TIER CARD replacing the class primary,
which is the intended rule. NOT yet traced: that a promotion accepted while a
sidearm is in hand can never leave the player holding a stale old form
(give-before-take + eaten SwitchToWeapon paths). One trace, low priority.

NOTE ON ALL WORKSHOP COMMENTS SO FAR: every report is against the FIRST
published build; the per-item question is "still present in tonight's push?",
not "is it a bug". Status per report is inline above.

## 2. PERK ICONS — reverted to stock names; the white-square subset unknown
v10.5 restored the stock shader names (user directive). Facts established:
usermap packs NONE of the specialty_* materials; renderable ones come from
always-loaded base ffs; the white ones are DLC-ff-only; mod tools ship no raw
sources; the game ffs are ENCRYPTED so no offline census is possible; the user
does not know which machines white-squared. ROBUST FIX (needs no knowledge of
the subset): obtain the official icon art for all 8 perks as transparent PNGs,
install as i_tod_perk_<name> image assets (the proven cherry lane), swap the 8
mapping names in AetheriumPerks.lua. Art source: user-supplied rips/wiki, or a
fetch attempt (one-URL CDN test 404'd — inconclusive). Cherry stays custom
(stock ships no cherry shader).

## 3. "STAIRS SUCKS" — needs one sentence of specifics from any player
Candidates if it recurs: climb tedium (design), rail-cap bumps while hopping,
zombie pathing on flights.

## 4. LIVE-VERIFY LIST (all build-clean, none player-proven)
- Vendor PaP: class gun, sidearm lane, Enfield, knife
- KNIFE SPEED card actually swinging faster
- KBM card switching + jump-release gates (both menus)
- Teleporters: 0.8s charge, two-way, lock gates, no arrival bounce
- Breather respawn groups (co-op deaths)
- THE LAST MILE finale end-to-end (song timing, ambush, survivor-at-crown)
- THE FORKED CAUSEWAY (v10.12, built + baked + geometry-linted, never walked).
  The static geometry is now PROVEN clean by tools/lint_tod_geometry.js — zero
  holes, zero invisible walls, walkable end to end — so what is left to test is
  everything a .map parse cannot see. In priority order:
  1. The GATE. Before buying: the causeway mouth is a solid wall you cannot pass
     and cannot shoot past, and no zombie is standing out on the road. On buy:
     it vanishes with a derez burst and the road is walkable end to end.
     (The lint CANNOT check this — the gate is an entity and script-driven.)
  2. THE CLOCK — computed, not guessed, and it has room. Shortest line through
     the road is 8580 units (the generator prints it). The slowest class is
     HEAVY at class_speed_base() 0.75, and the SPEED upgrade domain and
     adrenaline only multiply UP from there. At BO3's sprint speed (~250 u/s,
     and this map has unlimited sprint) that is ~46 s of movement against a
     191 s song; even at a walk it is ~82 s. So the clock carries 2-4x slack and
     is NOT the thing to worry about.
     What to actually watch is being PINNED — the failure mode is a player who
     cannot move at all for 60 s, not one who moves slowly. Boss roof is 4 and
     the spawn-delay floor is 0.1 s; if a Panzer plus a protector wave can hold
     a 160-wide bridge shut, the run ends there. Test that, not the walking.
  3. Every lane at BOTH forks walkable in both directions — v12 shapes: the
     RIDGE's two crest corners, the BROKEN STAIR's pockets and long climb, THE
     NARROWS' 120-wide pinch, the UNDERCROFT's stair V and cistern, the
     120-wide PLANK (now +256), and the WEAVE's eight blind corners.
  4. Zombie PATHING on the v12 road — bunching at THE NARROWS (the deliberate
     single-file choke: does the horde feed through it or dam it shut?), the
     weave's corners, the undercroft's 24-tread flights. The lint proves a
     PLAYER can walk it; zombies use the navmesh, which is a different
     structure built by cod2map.
  5. Risers fire on every lane (32 flat pieces now, incl. the cistern and all
     nine weave pieces), not just the on-axis stretches.
  6. Panzer front-spawn still lands ON the road (PositionQuery_Source_Navigation
     should keep it honest; the mid-air FALLBACK is now re-anchored on the player,
     but the happy path is unverified). v12 note: altitude-sorting sends the
     Panzer at the HIGHEST player — i.e. onto the 120-wide PLANK. Confirm the
     mechz actually paths that width during a finale run; if it refuses, the
     plug beat degrades to a beside-spawn (graceful, but watch for it).

## 4b. ADVERSARIAL REVIEW OF THE ROAD — ACCEPTED BUT NOT ACTIONED (2026-08-23)
Six lenses, every finding attacked by an independent skeptic. These survived
refutation and are DESIGN calls rather than defects, so they are recorded rather
than fixed. Each needs the user's judgement, not a patch.
- THE PANZER PLUG. A front-spawned Panzer on a 160-wide railed road with no
  alcove in 8,600 units cannot be walked past. The user ASKED for this ("Panzer
  included should spawn in front of you"), so it is intended difficulty until
  they say otherwise — but it is the most likely way a run ends to something the
  player could not answer. Watch for it in the first playtest.
- THE SONG CAN RESTART UNDER THE ENDING. TOD_FINALE_SONG_SECS is 191 and the
  alias LOOPS (deliberately — a non-looping streamed one-shot is engine-
  unstoppable). A party that survives the song but has not reached the citadel
  keeps waiting in `while (!survivor_at_crown())`, and the track starts again.
  So 191s is a floor, not a hard clock. Cosmetic, but it undercuts "the song IS
  the clock". Fix would be a fade or a held final chord, not a timer change.
- BOSS TYPE IS KEYED TO ALTITUDE. anchor_player picks on z, so on a forked road
  where one branch is +256 and another -256, boss types sort themselves onto
  branches. Probably unnoticeable; listed so it is not rediscovered as a bug.
- THE FORKS ARE ALL DOWNSIDE FOR A CO-OP PARTY. Split players can see each other
  across a fork but cannot reach or revive across it, and there is no reward for
  splitting. Consider whether that is the intended tension or an accident.
- ZOMBIE PATHING ON THE 120-WIDE PLANK is the one unproven width in the map
  (everything else is 160+). If zombies avoid it, the fast lane silently becomes
  the safe lane and the second fork loses its point. First thing to look at on
  the road.
- ⚠️ DIFFICULTY JUMP: the zombie-health multiplier was inert since birth and is
  LIVE for the first time in this build (x1.25 solo … x1.70 quad) ON TOP of the
  door-ladder cut (750 +60/lap cap 3000). Watch: (a) the ROUND extraction
  becomes buyable (before ~15 = ladder overshot; knob = DOOR_COST_STEP);
  (b) reserve ammo rounds 15-20 in a 3-4 player lobby — if it breaks it reads
  as "guns feel terrible", not as a health change.

## 5. RELEASE PROCESS
- ~~PublisherID~~ RESOLVED at the freeze: the Launcher never wrote it back, but
  the 15:46 upload IS live (a player commented), and the item id 3788921059 was
  recovered from Steam workshop_log.txt and written into zone/workshop.json —
  the next publish updates the existing item. VERIFY after publishing: the
  Launcher should say Update, not Create.
- Storefront still says [WIP]; decide [BETA] deliberately.
- CREDITS.md: two TODO author handles (xmas gun; zod companion port) — gate
  PUBLIC only.

## 6. DEFERRED AUDIT MINORS/NOTES (verified real, low stakes)
- Scatter same-floor repair ignores unassigned pad slots (rare fallback).
- Electric Cherry perk row — UNDRIVEN, and its row should therefore be ABSENT,
  not white: nothing writes hudItems.perks.electric_cherry because
  _tod_perk_electric_cherry.gsc:18-21 deliberately skips
  register_perk_clientfields (clientuimodel budget: 57 of a proven-booted 61;
  overflow = map load aborts to lobby). So cherry is the LEADING CANDIDATE for
  CZ's white square, NOT confirmed.
  COST CORRECTED 2026-08-23 (peer session, read off stock): a perk HUD row is
  driven by ONE clientfield::register( "clientuimodel", "hudItems.perks.<name>",
  VERSION_SHIP, 2, "int", ... ) — TWO BITS, 57 -> 59, still under the proven 61.
  Earlier notes here (and in _tod_finale) called it a "perk-row mask rewire"
  borrowed from map 1; that was wrong and made the fix look bigger than it is.
  It is still a CLIENTFIELD change, i.e. the map-load-abort class, so the
  condition stands: do it on its own with a boot test, NEVER riding a geometry
  build. Not attempted yet.
  ⚠️ ONE QUESTION TO CZ SETTLES TWO BACKLOG ITEMS: 'which perk was the white
  square?' (or a screenshot) resolves this AND the §2 which-specialty-materials-
  load-on-a-usermap dead end in a single answer.
- ~~Card header/footer framing loosened by the 15% shrink (banner gap 39px).~~
  CLOSED 2026-08-24: the 15% shrink itself was reverted (v10.16, user: "its too
  small now and it was actually in a good spot"), so the framing is back to what
  it was and the gap goes with it.
- armory.html predates v10.3+ balance (protector cap, door scaling, perk
  limit, teleporters).
- Generator header comment drift (docs numbers), scatter/bosses comment drift.

## OPEN — ELECTRIC CHERRY: NO BUY TRIGGER (2026-08-24, needs ONE dev run)

User, mid-playtest: "Also electric cherry machine has no trigger to buy it."

**NOT DIAGNOSED.** v10.16 shipped a self-heal + a diagnostic, not a fix, because
reading the code cleared every link in the chain:

| checked | verdict |
|---|---|
| .map struct: script_struct, targetname zm_perk_machine, model + script_noteworthy + script_string matching "zclassic_perks_start_room" | accepted by perk_machine_spawn_init |
| does the trigger need the perk registered? | **NO** — `_zm_perks.gsc:1511` spawns "zombie_vending" unconditionally for any accepted struct. Rules out the whole "perk did not register" family. |
| register_perk_machine installs ec_machine_setup as .perk_machine_set_kvps | yes, `_zm_perks.gsc:1854` |
| does that callback fix the machine identity? | yes — stock leaves BOTH t_use.target and perk_machine.targetname as "vending_sleight" until it runs, which WOULD cause exactly this, and cherry's callback sets both correctly |
| power path: standard_powered_items -> perk_power_on -> getVendingMachineNotify -> "<alias>_on" -> perk_machine_think | resolves correctly for specialty_combat_efficiency |
| turn_perk_off Delete-respawning the model out from under the cached t.machine | already defused by b_keep_when_turned_off in capture_and_open |

WHAT SHIPPED INSTEAD, in `_tod_perk_scatter.gsc`:
- `machine_for( t )` re-resolves a dead machine pointer via `t.target`;
  `move_machine` now calls it instead of bailing — a dead pointer used to freeze
  that machine's moves forever, stranding its trigger at the last pad, which is one
  of the two shapes this report can take.
- `coherence_watch()` re-aligns a trigger that has drifted >96u from its
  machine, every 5 s. QR excluded: its solo epilogue flies the machine away on
  purpose, so a drift check would chase the trigger into the sky.
- Both `dev_print` what they find.

**TO CLOSE IT:** one run with `level.tod_dev = true`. The print distinguishes the
three live possibilities — cherry DRIFTED, cherry has NO MACHINE ENTITY, or cherry
was NEVER CAPTURED (that last one prints from capture_and_open's "only N/8 machines
captured"). Whichever it is names the real bug. Until then assume the self-heal is
masking, not fixing.
