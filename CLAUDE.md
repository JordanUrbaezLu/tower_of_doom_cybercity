**2026-10-07 - v19.77e: DEV/GOD ARMED; ONE ARMORED ZOMBIE PER ROUND FROM ROUND 1. SCRIPT BUILD OK; .ff 2026-10-07 09:37:23 Eastern, 155,157,312 bytes; USER PLAYTEST PENDING.** User requested dev and god mode for the completed armored model. Existing settled-zombie director converts one regular zombie each round, including the current first round, bypassing the lap-30 unlock and party/Rampage wave scaling in dev only. A kill does not refill the same round. Upgrade pause/eligible-AI/concurrency guards remain; the finale still suppresses new armored tickets. Normal non-dev cadence is unchanged. [TOD_ARMORED_TEST] START / ROUND_ARM / PROMOTED / change-only WAIT / ROUND_SKIP records the test quota and outcomes; existing [TOD_CYBER] and [TOD_ARMORED_WALK] record art/gait. New actual-source behavioral test covers current/later rounds, no repeats, co-op/Rampage quota, pause/no-AI recovery, eligible actors and ship cadence, with four negative controls; now a build gate. Deployed dev/god flags are ON; 159 authored sources, 184 models and 20 maps match deployed with no compared input newer than the fastfile. The armored master is unchanged from the completed full art build. Sound bank 207,523,840 bytes; ten known waived warnings only. New per-round gate and existing walk/compiled geometry gates passed inside the build. No game launched. Details: docs/173; evidence tmp/armored_dev_rounds_20261007/.

**2026-10-07 - v19.77d: ENCLOSED ARMORED HELMET, BRILLIANT RED EYE STRIP, BACK TANK REMOVED. FULL BUILD OK; .ff 2026-10-07 01:21:05 Eastern, 155,157,248 bytes; USER PLAYTEST PENDING.** Executioner helmet closes the crown/sides/rear over all three supported skulls, with a folded jaw/brow, continuous red optic, temple cooling cassettes, captive screws, nape exhaust and MK33 repair stamp. No separate raised forehead shield. Complete pressure pack/plumbing/frame/standoffs removed (489 equipment objects); 1.30 dorsal spikes, 1.33 size, elbow-only swords and arms-down walk retained. Red slit strength 14 vs previous 3.5 (4x), hot core 16. Ref3 bake range/GDT decode 16 preserves ordinary lamp radiance; other roster ranges stay 6. Largest connected head shell preserved through all seven authored LODs; UV/normal/shape parity and actual atlas radiance checked. Master 805 equipment objects / 229,046 evaluated triangles; four attachment poses and hidden-donor/display parity pass. [TOD_CYBER] START rev=8 / ELITE_PROMOTE records helmet/tank/eye configuration. Blender refreshed. Dev/god OFF; no game launched. All 21 installed head variants/distances enclose 19,284 checked skull vertices. Source/compiled roster coverage pass; 159 authored source files, 184 models and 20 maps match deployed and predate the fastfile. Other roster hashes unchanged; only sprinter emission decode changes in the GDT. Sound bank 207,523,840 bytes; ten known waived warnings only. Seven current 1600x1760 Cycles/128-sample installed-source views include dim-light and farthest-head studies; gallery refreshed. Evidence: docs/173, tmp/armored_helmet_20261007/. Shared worn gunmetal, abraded steel edges, blackened fittings and aged black hoses unify helmet, sword plates and body armor; original donor materials unchanged. Distinct arms-down walk retained and source-gated.

**2026-10-06 - v19.77c: ARMORED ARMS-DOWN WALK + 30% BIGGER REAR SPIKES. FULL BUILD OK; .ff 2026-10-06 23:44:25 Eastern, 155,157,184 bytes; USER PLAYTEST PENDING.** Only tod_is_sprinter selects native walk/arms down through the shared speed owner; stock picks a supported stable variant. Promotion applies immediately, keep-alive repairs drift, round offset -10 and normal/rampage/slow curves remain. Boss/freeze/riser/native-slow guards precede every write. Walking root motion intentionally slows the approach. Change-only dev [TOD_ARMORED_WALK] APPLY rev=1 logs ent/gait/override/arms/variant/repaired/round/add/rate/slow/rampage; [TOD_CYBER] START rev=7. test_armored_walk.js passes, four negative controls, now a build gate. Exactly 14 pinned rear torso/collar spikes (520 vertices) scaled 1.30 at fixed root centers; hidden donors intact, visible/native transform parity checked. Back pressure pack extended 7.25 on four open slotted cantilevers, original vest feet retained, bind-pose tank clearance 1.6456. Master 1,414 equipment objects / 411,731 evaluated triangles; four pose checks pass. Mouth guard, red eye strip, elbow-only complete swords, cleared forehead and model scale 1.33 retained. Blender refreshed; no game launched, dev/god OFF. All 184 source binaries and native compiled geometry coverage pass; 22 armored binaries/5 maps changed, other roster hashes and GDT fields unchanged. Equipment LOD totals 46937 / 28448 / 15658 / 8151 / 4733 / 3103 / 1659. 159 source files + 184 models + 20 maps match deployed; no compared input newer than .ff. Sound bank 207,523,840 bytes; ten known waived warnings only. Five 1600x1760 Cycles/128-sample source previews reviewed, current gallery refreshed. Final model visibly open in Blender; docs/173, tmp/armored_spike_20261006/.

**2026-10-06 - v19.77b: FOREARMS AND HANDS BECOME SPIKE SWORDS (user clarification: "entire arm passed the elbow"). FULL BUILD OK 23:19:52 Eastern, 155,168,896 bytes; USER PLAYTEST PENDING. Superseded by the walk/rear-spike pass above.** Raised forehead shield, hinges and crown frame removed (80 head objects); red strip and mouth guard retained. Both lower arms are complete diamond-section steel spikes from elbow to tip, with sealed roots, honed edges, forged root teeth, service fasteners and amber actuator lights. Upper arms/sleeves and their shoulder gear retained; human hands and old mechanical hand removed. Original Blender donors hidden/intact. Shared elbow-descendant mask replaces exactly 1,492 forearm/hand faces and retires 1,308 unused vertices in native source; all 90 bones and retained stock faces/vertices/weights stay exact. Verification pins this exception to tod_cyber_sprinter. Four pose checks and Blender/native mask parity pass. Finger equipment retired only for this body. Red strip/mouth guard/1.33 conversion scale retained. Blender refreshed, no game launched, dev/god OFF. Docs/173 and tmp/armored_spike_20261006/.

**2026-10-06 - v19.77: ARMORED ZOMBIE REMODEL. FULL BUILD OK; .ff 2026-10-06 22:33:58 Eastern, 155,158,976 bytes; USER PLAYTEST PENDING.** Reference-three master now has a sharp folded gunmetal mouth guard, continuous ruby-red eye strip and forged sword blades on both forearms. Native GDT scale 1.33 on armored body and three heads only; NEVER use live AI SetScale (documented native crash). Original donor geometry/weights and four attachment pose checks preserved. Equipment LOD totals 45829 / 30818 / 15859 / 8440 / 5070 / 3578 / 1898; five 4096 maps rebaked. All 184 roster binaries pass verification; other roster model/map hashes unchanged. Actual source-binary renders reviewed; updated master open in Blender. Dev ELITE_PROMOTE records scale/mouth/sword/eye configuration, not native proof. Dev/god OFF; no game launched. Compiled roster coverage passed, deployed input hashes match, no compared input newer than the build; sound bank 207,523,840 bytes; ten known waived asset warnings only. User checks size, head alignment, moving-joint clearance and native glow. Reproduction, evidence and three further ideas: docs/173_armored_zombie_remodel.md.

**2026-10-06 - v19.76: THE LEAD TESTER'S OCT 4-6 LIST, TEN FIXES (user: "Okay lets fix the 10. Also I think you can make the assets yourself. ANd be careful on 8"). FULL BUILD OK, .ff 13:16:06 Eastern, 155,157,184 B; own compile (navmesh 2) + bake (.led 45,157,031 B); diffs clean, nothing synced after, .map == tools root; bank 197.9 MB, the 10 waived only; dev / god OFF. UNPLAYED.** (1) TRIAL SKIP: `_tod_spire::door_bypass_watchdog` opened a door FREE for anyone 250+ above it, trial seal or not - now a player above a TRIAL-sealed door is sent back into that hall (`trial_bypass_return`, toast 11, log `[TOD_SPIRE] TRIAL_BYPASS_BLOCKED`). (2) SUMMIT: well rail S one PARA longer each end (the two corner wedges), rim rail to the gate's north face (the slot), a clip_player in the gate entity up to the seals (27464); king_win KEEPS the gate shut + tod_trial_box = summit_box. (3) `ShouldDoInitialWeaponRaise( w, false )` on every non-staff upgrade swap (swap_primary), the Mage tier-up staff, the promoted sidearm. (4) POWER-UPS PAUSE FOR CARDS: unpaused_wait (Insta-Kill, a pause-aware Double Points grab), Zombie Blood / Infinite Ammo / Time Warp skip the tick, powerup_pause_hold holds stock's clocks. (5) tod_music_finale Pauseable=yes + probe `[TOD_FINALE] CLOCK ... drift_s` (whether the GAME clock runs through a solo pause is unproven). (6) SMOKE: the ice impact's Origins fog thinned (build_bo6_ice_fx.py simpact_thinned, scale_alpha/scale_life); NEW tools/gen_tod_riser_fx.py thinned rise_burst/billow/dust copies, assigned on BOTH VMs after zm_usermap::main (stock replays rise_dust every 0.3 s for 5.5 s on client AND server). (7) THE KING'S BOSS BAR, art made here: tools/boss_bar/build_boss_bar.py -> i_tod_boss_bar / _fill; `tod_king_bar` ( state, permille ) from king_hp_bar (change + 1 s heartbeat) and king_win; tod_upgrade.lua KING BAR hides the luck bar + the floor gauge (now ONE container, GaugeRoot). (8) DUAL WIELD: right + left via `currentWeapon.ammoInDWClip` (the v17.21 "no subscription" costing was wrong); doubling only without the model. (9) Mage key badges ABOVE their tiles (y549..566). (10) scoreboard ROUND header repaints on tod_round and takes the game-over banner's number. NEW GATES: boss_bar + riser fx --check, test_tester_fixes_1006.js / .lua, test_mage_hud.lua in the lupa step. CHANGELOG v19.76; memory tester-list-2026-10-06, dual-wield-left-clip-model. Log tmp/tester_fixes_20261006/build_full1.log. **SAME-DAY SELF-REVIEW (CHANGELOG v19.76 REVIEW): -GscOnly BUILD OK .ff 14:19:37 Eastern, 155,156,992 B, diffs clean, nothing synced after, dev/god OFF, UNPLAYED.** Fixed: a co-op respawn stranded under the shut summit gate (`summit_respawn_only` locks every non-summit respawn group at the King's seal); the boss bar's on/off now rides `_tod_gauge`'s heartbeat (`king_bar_permille` -1 = off; it could stick through map_restart); the paid 5,000 PaP machine keeps its flourish (`tod_pap_flourish_ms` stamp); dual-wield low-ammo re-learns on a pair flip (`clipPair`); the trials' near-player rise bias is fight-only (post-King spawns spread over the deck). THE USER'S CALLS ON THE THREE REVERSALS: Mage key back OVER THE WHOLE TILE (cap 20) on a 35% see-through plate (`BADGE_PLATE_ALPHA`); the King fight shows ONLY his top health bar (gauge + luck bar hidden - kept as built); TIER PROMOTIONS KEEP THEIR FIRST-RAISE SHOWCASE for every class incl. the Mage's new staff (`swap_primary( ..., showcase )` from tier_up only; "I like the first draw only for showcase on tier promo") - card swaps / free PaP drop / sidearm stay without it, the paid machine keeps it. **-GscOnly BUILD OK .ff 15:18:43 Eastern, 155,158,784 B, diffs clean, nothing synced after, dev/god OFF, UNPLAYED** (tmp/tester_fixes_20261006/build_answers.log).

**2026-10-04 - v19.75 PUBLISH BUILD VERIFIED 13:12 Eastern, .ff 155,028,160 B (written 13:12:25); FULL + -CleanPak + all twelve languages, payload 2,823,608,507 B / 48 files; bank 197.9 MB, the 10 waived only; diffs clean, nothing synced after, .map == tools root; deployed ship state: every tod_dev* / tod_god false, MOCK / HUD_DEBUG false, temp loggers 0, harness #8 parked. Notes `Update — Oct 4 (v19.75)` (11 bullets), ledger row #49, window = v19.70 .. v19.74. UPLOADED 2026-10-04 13:21 Eastern (row #49 closed 2026-10-06 by `patch_notes.js uploaded`, Steam fetch); the v19.76 build has since replaced it in the deployed tree. Not seen natively yet (the user's 12:10 dev session never exercised them): bat inspect, Death Perception on elites, cleave pay. Log tmp/publish_v1975_20261004/build.log.**

**2026-10-04 - v19.74: EVERY UPGRADE CARD SHOWS YOUR LEVELS LIVE - OWNED CYAN, THIS CARD'S LEVELS PULSING IN ITS RARITY COLOUR, ROOM LEFT EMPTY (user: "players arent really aware of what basic, super, and ultimate even mean ... a visual upgrade on all the cards that has to be custom and not part of the actual card but should look like it ... match what we do in tower of doom 2 ... level 2 and get a super card: Fill Fill Purple Purple Empty ... maybe even a small pulse animation ... I dont think this impacts dark upgrades at all"). FULL BUILD OK 12:10:32 Eastern, .ff 155,028,160 B; own compile + bake; navmesh 2 components; card_pips --check + test_card_pips.lua ran inside it; the 10 waived only; banks 71,979,648 / 207,523,840; scripts / ui / zone_source == deployed, nothing synced after; ledger: the 10 i_tod_cardpip_* + 140 FRESH painted-card .iwi beside untouched dark / class controls; dev + god ARMED (peer, at the user's request). UNPLAYED.** docs/172. One live dot row per dealt card where the art's dots sat: one dot per level at the player's REAL per-class cap, CYAN = owned (the pause pip colour), the card's RARITY colour (white / violet / gold, with the art's halo) = what this card adds, dark = room left; the added dots light one at a time as the card lands, then breathe until the pick; the taken card's new dots turn cyan; a locked promotion shows where it leads, tinted, no motion; the tier card's row = the class's tiers; DARK cards untouched (their baked red row stays). NEW `tools/card_pips/build_card_pips.py`: 10 sprites `i_tod_cardpip_*` rebuilt from the card's own dot (fitted, mean error <= 1.00/255; 48 texels = 48 card px) + the baked dot row PAINTED OUT of all 140 live cards (regular/super/ultimate + 10 tier; a cover cannot work - an unfocused card is alpha 0.4 and shows dots through any cover); originals in tmp/card_pips/originals, `--restore` undoes; its `--check` gates every build (a NEW card drop with baked dots fails by name -> run `--install`). Data: NEW eventstring `tod_upg_pips` (_tod_upgrade_ui.gsc `pips_push`, before todUpgShow): per slot domain_id*256 + max*16 + levels, zero clientfield bits. Lua: tod_upgrade.lua `CardPips` (file scope), 19 elements a card under one root in card.group, laid out only on a new signature (Render runs ~7 Hz), chains on its own metronome tweens (no UITimers). NEW lupa gate tools/test_card_pips.lua (whole deals through the real panel; 7 negative controls). Rollback: `USE_CARD_PIP_ART = false` + `--restore`. UNPROVEN NATIVELY: completion events on the bare-UIElement metronomes (dots never light/breathe = start there) and the panel's per-render completeAnimation not reaching children (a 7 Hz stutter). Log `[TOD_CARD_PIPS] DEAL` (tod_dev - ARMED by a peer at the user's request).

**2026-10-04 - v19.73: SLASHER SIDEARMS RELOAD 30% SLOWER (ALL THREE, BASE + PaP); A CLEAVE KILL PAYS 75% OF A BASE KILL AND THE POPUP SAYS SO (user: "increase the reload time on the slashe secondaries by 30% all of them. Slashers cleave kills should be 75% of base kills ... make sure the display money is proper as well"). FULL BUILD OK, .ff 11:35:19 Eastern, 155,545,216 B; own compile + bake; navmesh 2; the new gates ran inside it; bank 197.9 MB; the 10 waived only; ledger links t9_amp63_b + its _b_zm akimbo pair and no stock t9_amp63 weapon. Carries the peer's tod_dev + tod_god ARMED. UNPLAYED.** UDM / RK7: gen_tod_twins `SLASHER_SEC_RELOAD_MULT` 1.3 (tune.reload = 1.3 / SLASHER_SEC_BUFF; 20 reload lines on the 4 forms). AMP63: its GDT is SHARED WITH TOWER II, so it is now a MAP-OWNED COPY - NEW tools/gen_tod_amp63.js -> source_data/tod_amp63.gdt (`t9_amp63_b` / `t9_amp63_rdw_up_b_zm` / `t9_amp63_ldw_up_b_zm`, verbatim blocks, reload x1.3 LOCKSTEP, source SHA-pinned, `--check` gates every build); zone, weapons CSV row and TOD_SEC_SLASHER_1 moved; every name still contains "t9_amp63" so stem lookups match. CLEAVE: `cleave_kill_claim` / `cleave_kill_settle` wrap the cleave DoDamage (claim stock's deathpoints latch + tod_popup_points before, settle after; stock thundergun idiom), paying TOD_CLEAVE_KILL_FRAC 0.75 x the stock melee kill = 90 (x Double Points) on its own score event `tod_cleave_death`; BOUNTY's nominal for the kill is the 90 in both bank and popup (bounty_kill_value / bounty_preview take the victim). Was: stock's bare 50. NEW GATE tools/test_cleave_kill_pay.js (+ test_mage_kill_points.js now in the build). Log `[TOD_CLEAVE] KILL_PAY`. ⚠️ The settle's `z.health > 0 &&` guard is NOT in the 11:35 .ff (edited after its sync); a -GscOnly at 11:37 stopped at the UI art lint on a PEER's half-finished card-pip art (10 zoned i_tod_cardpip_* images, unnamed 179 -> 189), nothing linked. v19.73b (user: cleave kills "should also take into account any bounty addition"): BOUNTY on a cleave kill no longer hangs on the engine's damageweapon - ONE bank helper `bounty_bank_kill`, a cleave kill banks it ahead of on_class_gun_kill's weapon gate and bounty_preview takes the same exemption (cleave 90 + BOUNTY on 90 = 75% of 120 + BOUNTY on 120 at every level). NOW IN A BUILD: a peer's FULL BUILD OK, .ff 12:10:32 Eastern, 155,028,160 B (tmp/card_pips_20261004/build_full1.log) synced the repo at 12:01:57 and carries v19.73 + v19.73b + the settle guard (+ the peer's card pips); gen_tod_amp63 --check, test_cleave_kill_pay (95 cases) and test_mage_kill_points ran inside it; bank 197.9 MB; the 10 waived only; scripts / zone_source / ui == deployed, nothing synced after; tools-root tod_amp63.gdt + tod_weapon_twins.gdt == repo; ledger links t9_amp63_b / t9_amp63_rdw_up_b_zm / t9_amp63_ldw_up_b_zm. UNPLAYED. Memories amp63-map-owned-copy, script-kill-money-claim-settle.

**2026-10-03 - v19.71: NO STANDING SPOT THE HORDE CANNOT REACH - EVERY PROP CAPPED, EVERY LEDGE SEALED, EVERY VENDOR FLUSH (Workshop tester as the wall-running Slasher: on top of the ammo crate / Quick Revive / the Rampage switch "and cant be hit", "you can wall run through the ... sign", "the heavenly [altar] ... bumped out ... so you could run behind it"; user: "Wall running seems to have not been thought through enough ... think and resolve any potential gaps"). FULL BUILD OK 14:24 Eastern (process 14:12:32-14:24:32), .ff 155,544,448 B written 14:23:12; own compile (d3dbsp 21.7 MB 14:17:18) + bake (.led 45,145,470 B 14:20:30); navmesh 2 components (tower 50 floors / spire 70, both one walk); gates in the build: the new perch self-test + perch lint (0) + geometry lint (no regression) + hall bunkers 0; bank 197.9 MB; the 10 waived only; scripts / zone_source / ui == deployed, nothing synced after the .ff; tools-root .map == repo; deployed base_station_org (0,-276) read by _tod_upgrades, pap_org -780, station_org -436, crate_org -294, base_sign_org z 160; dev / god OFF (ship state untouched). Log tmp/perch_pass_20261003/build_full1.log. UNPLAYED.** NEW `tools/perch_core.js` = ONE perch model shared by `gen_tower_map.js` (fixes) and NEW gate `tools/lint_tod_perches.js` (+ `_selftest.js`, FULL builds step 1d; zero perches, baseline takes a family only with a written reason - it has none). PERCH = upward face, crouch headroom 48, not a deck/ramp, 19..200 above a floor within 192 with nothing rising past both ends between, no zombie swing (stock 64 3D) - and **anything 30+ up is a perch regardless (`HIT_DZ_MAX`: the tester stood unhit on the 40-tall switch)**. v19.70's map had 1,499 perch faces / 115 families. PROPS get designed caps (`perchCap` / `crateCap` / `vendorCap`, emitted LAST by `emitPerchCaps`): clip_player wedge, slope 3.5 = 74 deg (map 1: 56 standable, 72 not), high edge BURIED 16 in the wall; crates + switch keep a 20 slot over the body for the trigger sight line; perk pads read from `_tod_perk_scatter.gsc make_pad`, altars, PaPs cap from 80 up; uplink = 400 column; caps stop only under FLOORS or full covers. EVERYTHING ELSE: `perchSeal()` (clip_player boxes out of reach or to each floor's underside, 2 passes, ~1,500 seals; regen now ~60-90 s). VENDORS FLUSH: `VENDOR_STANDOFF` 20 (lounge altar y -436, PaP x -780), `CROWN_VENDOR_OFF` 24, `SP_VENDOR_OFF` 60 -> 20, base altar GENERATED `base_station_org` (0,-276) (was hand-typed (0,-320) in _tod_upgrades), crates 1 off their walls (base -294, lounges -294, crown 686, summit -666). Sign z1 100 -> 160 + clip body + cap. Spire hall gates: clip_player extension INSIDE the gate entity (was 128 tall, clearable mid-trial). Rocket fin clip = 74-deg frustum. heavenly_altar/verify_native.py pins the generated base altar. docs/171, memory perch-caps. NOT CHANGED: Blink's land-in-a-clip edge (Blink climbs at most 18 - reaches no perch); the song-hunt bears stay walk-through.

**2026-10-03 - v19.72: DEATH PERCEPTION OUTLINES EVERY ENEMY - BOSSES AND ELITES INCLUDED (user: "Can death perception be buffed to all enemies not just zombies?"). -GscOnly BUILD OK 12:59 Eastern, .ff 155,154,240 B (written 12:58:03); the new gate ran inside it; diffs clean, nothing synced after; bank 197.9 MB, the 10 waived only; ledger packs both _tod_perk_electric_cherry scriptparsetrees + both Lua rawfiles. Ship state untouched (dev / god OFF). Carries v19.70. UNPUBLISHED, UNPLAYED.** The pulse (`_tod_perk_electric_cherry.gsc`, DP's lineage filename) skipped the boss triad = every elite: Panzer (+ Warden King, spire Wardens), Rogue Protector, hellhound, Reaver. Now `dp_elite_hold()` outlines them once they have ARRIVED: seen on an earlier pulse (a counter clientfield throws on a spawn frame; the Reaver stamps completed_emerging on its spawn frame), not `tod_dropping` (drop_in Ghosts them on the landing mark), a hound not still hidden (ignoreme - HOUNDS ONLY: the Protector has ignoreme FOR LIFE via archetype_zod_companion). Client: an outline clears on death (`dp_death_watch` IsAlive poll - dead Protector / hound / Reaver stay actors 5 s) and ANY local owner lights it in split-screen (duplicate_render is per ENTITY; the old per-screen decision let player 1's perk light nothing). Card: "SEE EVERY ENEMY THROUGH WALLS" / "EVEN BOSSES AND ELITES". NEW GATE tools/test_death_perception.js (every build, shipping text, 7 negative controls). Logs `[TOD_DP]` (tod_dev) + `[TOD_DP_C] ON arch= / CLEAR_DEATH` (developer runs). A PEER SESSION labels its wall-run perch work v19.71 (tools/lint_tod_perches.js) - not in this .ff. Memory death-perception-every-enemy.

**2026-10-02 - v19.70: THE BAT HAS NO LUNGE; ITS INSPECT IS BACK ON THE LOW-READY LANE (user after playing v19.69: "We also broke the inspect on the bat. Please fix. And i think we need to remove the lunge on the bat ... [we cannot] animate out of the lunge if we have a swing ready and same with inspect"). FULL BUILD OK 17:48:25 Eastern, FF 155,197,056 B; own compile + bake (.led 45,156,979 B); diffs clean, nothing synced after, tools-root twins GDT == repo; ledger links the new module + 12 bat forms (deployed: meleeChargeRange 0 / meleeLungeRange 0 / lowReadyLoopAnim vm_t9_bat_inspect). Ship state untouched (dev / god OFF). UNPUBLISHED (v19.69 went up 17:19, ledger row #48). UNPLAYED.** LUNGE: gen_tod_twins `lunge: false` -> MELEE_NO_LUNGE on the bat (24 lines regenerated). INSPECT: BO3 has no inspect field; the clip was the uncancellable reloadAnim (emptied v19.68 - a pad's X = +usereload blocked buys) and is ALSO the bat's lowReadyLoopAnim (1.8 s). NEW `_tod_bat_inspect.gsc`: a reload press while holding the bat -> `self SetLowReady( true )` (stock _zm_magicbox uses it), a loop holds `TOD_BAT_INSPECT_SECS` 1.8 (LOCKSTEP lowReadyLoopTime, test_baseball_bat.js pins it) and leaves on attack / melee / sprint / switch / down / weapons disabled -> `SetLowReady( false )`; reload lane stays one-frame so X still buys. ⚠️ UNPROVEN NATIVELY: that SetLowReady plays the clip on a melee weapon in a usermap, and whether the engine lets a swing interrupt low-ready itself (the loop leaves on the press regardless). "Nothing plays on R" = wrong lane, not timing; log `[TOD_BAT_INSPECT]` (tod_dev). Memory bat-inspect-lowready-lane. v19.69 PUBLISHED 17:19 (row #48 closed) as the uncleaned 17:09:52 build; a -CleanPak build at 17:37 reset the pack (2.57 -> 2.06 GB) + relinked all 12 languages; the pack re-grows per full build, so the next release still goes through -Publish. `_xpak_prev` (7.5 GB of dead backups) still awaits the user's OK to delete.

**2026-10-02 - v19.68x: THE RAMPAGE SWITCH PLAYS ITS OWN ON / OFF STINGS, NO CHA-CHING (user's downloaded wavs: "slight tweak ... more cyber tone" -> "Remove the cha ching ... more uniqueness" -> "this last second sound that takes over. I dont want that"). FULL BUILD 17:09:52 Eastern, FF 155,197,056 B (own compile + bake .led 45,157,951 B; navmesh 2; bank 197.9 MB; the 10 waived only; every gate passed; diffs clean, nothing synced after; both stings in the loaded bank). Its last line reads "FAIL: The game appeared during the build" ONLY because the user launched BO3 at 17:11:05 after the link - nothing rolled back. UNPLAYED.** tools/rampage_sfx/build_rampage_sfx.py (rev unique_3) renders sound_assets/tod/sfx/tod_rampage_on|off.wav from the pinned downloads; aliases in sound/aliases/tod_ui.csv; `_tod_rampage.gsc` plays the new state's sting FROM THE DEVICE (`sting_alias` via if/else). RULE BAKED INTO THE TOOL (the user's): no added layer may out-weigh the recording in any 250 ms (`recording_leads`). NEW GATE `build_rampage_sfx.py --check` (every build): wav sha == manifest, alias FileSpecs, PlaySound reaches both, no `zmb_cha_ching`. ⚠️ An UNWRAPPED ternary as a call argument (`PlaySound( ( x ) ? a : b )`) fails the whole file ("No generated data") and lint_tod_arity misses it - wrap it in its OWN parens or use if/else. The user approves sounds by LISTENING: render, then play ON / OFF via System.Media.SoundPlayer. Log `[TOD_RAMPAGE] STING` (tod_dev).

**2026-10-02 - v19.68w: THE SIGN'S CYBERCITY WORD IS LEVEL (user: "The Y in the sign is sticking out and the B ... make it level and fix"). In b9's FULL BUILD OK 17:09:52 Eastern, FF 155,197,056 B (verified: diffs clean, nothing synced after, ledger = the levelled mesh 100,086 verts, the installed binary passes the level check). UNPLAYED.** His model had the LAST Y 3.6 proud (20.10 vs 16.53) and the FIRST Y bent back (14.2-16.7); the B was level and only read as proud beside it. tools/fan_props/build_sign_relief.py sign_relief_3: `LEVEL` / `LINE_LETTERS` / `level_line` set every pixel in front of the rods inside each letter's window to the line's face depth (16.513) before meshing; `line_level_bad()` reads the shipped binary in --check (fails on the v19.68u binary for exactly the two Ys). Level by position windows, never by colour (a colour mask missed the first Y's darker foot).

**2026-10-02 - v19.68v: PRE-PUBLISH REVIEW, FIVE FIXES (user: "make sure we dont cause any regressions, bugs, crashs ... Worse thing is to push an update that breaks the game during the busy weekend"). FULL BUILD OK, .ff 15:55:09 Eastern, 155,196,992 B; own compile + bake (.led 45,144,930 B, ceiling 39,468); diffs clean, nothing synced after, .map == tools root, geometry lint no regression, hall bunkers 0, navmesh 2 components, bank 197.9 MB, the 10 waived only. Ship state untouched (dev / god OFF). UNPLAYED.** Five reviewers over the whole v19.66..v19.68u window + the user's Oct 1-2 logs (no shipping-code script error). FIXED: (1) RUN-BREAKING - AetheriumHud's `todHide.force` latch (v19.68r) never released and THE HUD MENU SURVIVES map_restart, so every game after a game-over Restart Map had no HUD - the forceScoreboard 0 release now clears it; (2) down_pistol_give (v19.68) had REPLACED stock's zm::last_stand_pistol_swap for every class (full reserve, free own-pistol ammo) - it now chains to the saved stock handler (`level.tod_stock_zombie_last_stand`); (3) breather spawn 1 sat 4 units inside the v19.68n crate clip in all four lounges - moved to (-340,-620), generator gate `checkBreatherSpawns()`; (4) the rocket landing re-runs `clear_footprint` in the clip's own frame (solo softlock); (5) no Mage casts while riding a rocket, and a torn-down Archmage client state no longer hides the next form. NOT CHANGED (CHANGELOG v19.68v lists them): Blink can land inside a clip (crate, wreck column) - quick native check: Mage at spawn, face the core, Blink. Log tmp/prepublish_review_20261002/build_full1.log.

**2026-10-02 - v19.68u: THE SPAWN SIGN REBUILT SMOOTH + LIGHTS UP WITH THE POWER; THE POWER TERMINAL ANIMATES (user: "The sign looks a litlle janky ... It alsmot looks meshed" / "the power has no animation from on to off ... Like a knob turning or a switch or power visual going up on the screen" / "can we give the sign and on and off state and turning power on lights it up?"). FULL BUILD OK 15:18:55 Eastern, FF 155,196,992 B; own compile + bake (.led 45,144,682 B); diffs clean, nothing synced after, .map + GDTs == tools root, navmesh 2 components, bank 197.9 MB, the 10 waived only; ledger: all ten new models lodCount 1, the old sign gone. Ship state untouched (dev / god OFF). UNPLAYED.** SIGN: `tod_cybercity_sign2` from NEW tools/fan_props/build_sign_relief.py - his full-detail sign rendered straight on -> a 60K-tri relief, ONE 4096 front-projected colour sheet, no normal map, every letter SIDE a flat swatch of HIS side colour (steel blue / muted purple / dark metal) with smoothed side normals. POWER STATES = skinOverride twins `_off` (dimmed unlit glass, black glow) / `_dim` (scaleRGB 2): _tod_base_sign.gsc hangs it OFF, then 0.4 s after power_on a neon flicker into ON. TERMINAL: NEW tools/fan_props/build_power_anim.py - the HOLD button's bolt ring spins two turns and lights (`tod_power_dial` / `_on`, local pos LOCKSTEP #defines), the screens boot dark -> three RESTART GRID steps -> POWER RESTORED (`tod_power_screen` + `_dark`/`_f1..f3` twins) on stock's same press. Both tools' `--check` gate every full build. ROLLBACK: zone `xmodel,tod_cybercity_sign` + the sign script's old define; drop the seven tod_power_* zone lines + `power_anim` thread. Logs `[TOD_SIGN] INIT/LIT`, `[TOD_POWER_TERM] PIECES/BOOT_*/ON_DIRECT` (tod_dev - OFF in this build, v19.68t's ship state, untouched).

**2026-10-02 - v19.68t: FLOOR NUMBERS ON THE WALL LEFT OF EACH DOOR; A PROMPT RING ROUND EACH ROCKET; DEV + GOD OFF (user: "The Floor number should be to the left of the door and not on the ground" / "the trigger for the ascend or extract space ships should be all around the spaceship" / "disable dev and god mode. Il test one more time and then push"). FULL BUILD OK 14:14:51 Eastern, FF 155,700,864 B; diffs clean, nothing synced after, .map == tools root, navmesh gate OK, bank 197.9 MB, the 10 waived only. UNPLAYED - the user's last test before the push.** Floor numbers: upright on the CORE FACE in the door's plane (odd: south face, even: north face), right edge 12 from the corner, centre 92 over the landing, 44 tall (gen_tower_map.js floorNumberWall / floorNumberWallAt); tower floor 1 rides above the STAIRS sign (centre 138); spire floors 11/21..61 (no core there - the hub void) sit low on the hub S flight's inner wall (32 tall). checkFloorSigns() asserts all 120 against every box (new ALL_BOXES): wall behind, nothing in front, clear view from the landing. Rockets: up to 8 prompts per ship on the push ring (rkRing, any spot in a solid dropped, spot 0 = the old nave prompt), generated rocket_trigs(kind) + rocket_trig_r/h replace rocket_trig; board_trigger arms one per spot, one shared hint (95 strings). SHIP STATE: tod_dev / tod_god / tod_dev_arch_test / tod_dev_all_perks false, harness #8 parked, TOD_RK_LOG 0 - a -Publish build can run as is (notes still owed).

**2026-10-02 - v19.68s: THE ROCKET RIDE IS A CHASE CAMERA; THE WRECK LANDS ON THE CORNER FLOOR (user on v19.68r: "it should land in the corner area not the wall" + "permantely above the sip so you can see it like in third person but also see where its heading" + "always have the ship slightly seen at bottom of screen and able to see ahead of the ship"). FULL BUILD OK 13:45:17 Eastern, FF 155,592,384 B; own compile + bake (.led 45,144,682 B); navmesh 2 components; diffs clean, nothing synced after, .map + 31 GDTs == tools root; ledger: the three ships, 12 images, all 16 effects, the script + both Lua files; banks 71.2 MB / 207.5 MB. UNPLAYED.** The camera rides BEHIND AND ABOVE the ship (`_tod_rocket::rk_cam`: `ctr - d*b + u*h`, u = the ship's right hand x the flight, looking 18 deg ahead of the ship so it sits low in the frame; pad (40,300) -> climb (380,420) -> chase (600,230), settle 2.5 s); its start side must point BEHIND the heading (`RK_CAM_SIDE`) and it never looks near-vertical (the yaw spins). The ascend is ONE vertical plane: straight up to 21,000, ONE solved circle over the top, a straight 20-deg dive (a circle turns at a constant rate: the crest-bunched keys stepped 8.4 deg/frame, the circle 3.79). The wreck: nose 20 into the NW corner FLOOR (local -460, 470), the hull leaning back over the corner, whose walls are SMASHED (`RK_CORNER`: crumbled ends, 40-tall stubs with a plain-red top - a `_tinted` top made them DECK slabs with an invisible wall on them - the boundary clip down to the stubs, the wreck clip `rocket wreck body`); riser -> (-200, 488), light -> (-440, 440). `TOD_ROCKETS=0` RE-PROVEN byte-identical (a switch-dependent light assert had made it throw - gated; re-prove the switch after any ROCKETS edit). Log `INIT rev=rockets_2`. docs/170 rewritten. Test flags + TOD_RK_LOG 1 untouched - PARK + DISARM + ZERO BEFORE PUBLISH.

**2026-10-02 - v19.68r: THE ROCKETS - THE POST-CROWN CHOICE RIDES NIKOLAI'S SHIPS (user: "use the rocket ships built in the props and place at each spot. Intead of the teleporters ... they view from the rocket pov as it flies to the endless spire. Then it crashes into the ground and they spawn in" + "if you extract same thing but the extract ship goes striaght up and the game ends few seconds later"). FULL BUILD OK 12:06:11 Eastern, FF 155,799,104 B; own compile + bake (.led 45,144,814 B); navmesh 2 components; diffs clean, nothing synced after, GDT / .map == tools root; ledger: the three ships, their materials, 12 images, all 14 effects, the script + both Lua files; every rocket wav banked (loaded bank 71.2 MB, streamed 207.5 MB). The rocket art is ~127 MB of the download (4096 per ship, kept for the hull camera). UNPLAYED.** When THE CHOICE opens both ships fly DOWN into the crown hall (`tod_rocket_extract` onto sanctuary tier 2 over the pad, the colourful `tod_rocket_spire` onto the dais), the two prompts arm (the EXISTING strings - hints still 95/190), first hold wins, every living player is cut through black onto a camera mover on the hull (Tower II's PlayerLinkToDelta lane, stepped every frame two frames ahead; its letterbox/veil ported as TodRocketCine.lua + TodHudVeil.lua; AetheriumHud's hide writers are ONE rule now). EXTRACT climbs straight up and the game ends 3.7 s into the climb (riders let go at +6.0 inside stock's intermission fade). ASCEND flies to the Spire and CRASHES into the arena's NW corner pillar; `ascend_run` runs inside the white and the party stands facing the burning wreck. NEW `_tod_rocket.gsc`; the stands, clips (script_brushmodels), crash and all four flights are GENERATED (gen_tower_map.js ROCKETS block); **`TOD_ROCKETS=0 node tools/gen_tower_map.js` + FULL build = the old pad/teleporter choice, .map byte-identical**. NEW GATES every build: tools/rocket/test_rocket_ride.js (runs the shipping GSC offline over the generated keys against the .map: hull >= 34 clear, camera >= 258 from any brush, <= 6.04 deg/frame; beats; wiring; 7 controls) + tools/test_rocket_cine.lua. HARNESS #8: at ROUND 5 THE CHOICE opens in the crown hall (`tod_finale::dev_open_choice`) - ASCEND carries on to the spire pads, EXTRACT ends the game. Logs `[TOD_ROCKET]` (TOD_RK_LOG 1 prints with dev OFF - ZERO BEFORE PUBLISH; read CAM eye_err, FX, ABORT first). Test flags untouched - PARK + DISARM BEFORE PUBLISH. docs/170_rockets.md. ⚠️ THE HULL CAMERA AND THE PILLAR CRASH IN THIS ENTRY ARE SUPERSEDED BY v19.68s (a chase camera behind and above the ship; the nose in the corner FLOOR, the corner walls smashed).

**2026-10-02 - v19.68q: THE POWER SWITCH IS NIKOLAI'S GRID TERMINAL V5 (user: "We can add the grid terminal as well to replace the power switch"). FULL BUILD OK 11:46:20 Eastern, FF 150,777,216 B; diffs clean, nothing synced after, .map / GDT / model_export == tools root; ledger tod_power_terminal lodCount 1 (24,118 tris), its 3 images + material linked, the lever's p7_zm_der_pswitch_* gone, no tod_rocket_* zoned; navmesh 2 components. UNPLAYED.** The lever prefab is gone; THE SWITCH LOGIC STAYS STOCK (_zm_power::electric_switch): gen_tower_map.js POWER_TERM emits the trigger_use `use_elec_switch`, an invisible tag_origin `elec_switch` handle at the HOLD button (stock rolls it and plays the flip / turn-on sounds from it) and the `elec_switch_fx` spark struct, plus the clip `base power terminal body`; NEW _tod_power_terminal.gsc hangs `tod_power_terminal` (60 x 11 x 88, tools/fan_props `power`: `join` / `emit` / `emit_floor` / back drop) at the GENERATED base_power_terminal_org (1619.5,-464,0) yaw 180 - centred north of the song-hunt bear (y -520), under the POWER word (z 96..128, now centred on it). Log `[TOD_POWER_TERM] INIT`. CHANGELOG v19.68q.

**2026-10-02 - v19.68p: AMMO BOX V6 ON EVERY CRATE (Nikolai's Oct 2 update; user: "I think ammo crate was updated to a new clean v6" + "update the asset artifact ... shows the differneces in the new version of props compared to old version"). FULL BUILD OK 10:20:19 Eastern, FF 149,496,576 B; diffs clean, nothing synced after (re-checked 10:45), .map == tools root; ledger lodCount 1, tod_ammo_chest 26,492 tris (45,535 exported - the linker drops zero-area slivers); navmesh 2 components, hall bunkers 0. UNPLAYED.** `tod_ammo_chest` = his lidless Ammo Box V6, 98 x 69 x 29, reduced PER MATERIAL GROUP (`groups=` in tools/fan_props/build_fan_props.py: one decimate bridged its parts into black triangles). THE CRATE CONTRACT NOW: box x[-37,33] y[-49,49], trigger out 33 / lat 0 (test_tester_fixes_0924.js pins it). Gallery https://claude.ai/artifact/JfbPCEs4XXy3deaxA9t1RR is at version 2 with five Oct 2 before/after pairs, rendered by NEW tools/fan_props/render_gallery.py (Upgrade Terminal Fix 6's FBX crashes Blender's FBX importer - the renderer drops its bad Edges array). The Oct 2 Door Terminal is the uplink's exact model with DOOR TERMINAL on the screen (offered as a swap, not done). A peer added rocket props through the same tool (`fan_props_3`). CHANGELOG v19.68p.

**2026-10-02 - v19.68o: THE SURFACE REFRESH + THE SKY'S DEPTH PASS (user: "small visual enhancements ... walls floors ceilings ... on either tower ... Like a minor redesign. Also any enhancements in the skybox in terms of depth and atmosphere" + "be prepared to revert cleanly"). FULL BUILD OK 03:44:17 Eastern, FF 149,434,560 B; own compile + bake (.led 45,144,894 B, ceiling 39,468); diffs clean, nothing synced after, .map == tools root, navmesh 2 components; ledger: all 12 tod_rf_* materials via the BSP + a fresh sky .iwi. UNPLAYED.** EVERY PIECE HAS ITS OWN SWITCH and all-off reproduces the old map / sky byte-for-byte: gen_tower_map.js REFRESH block (`RF_RISERS` / `RF_SOFFITS` / `RF_FLOORNUMS` ON, `RF_STRINGERS` OFF; env `TOD_REFRESH=none|all|list` overrides) and gen_tod_sky.js `TOD_SKY_SKIP=ceiling,underglow,beamhits,plumes`; the old sky EXR is parked in tmp/visual_refresh_20261002/baseline/. Risers = a glow + light line per step in the district colour (`addBoxFaces`, per-face materials on the EXISTING brushes, zero new brushes, lit area unchanged); soffits = the district's plain grid under every stair/landing; floor numbers = 222 HUD-digit decals on the door landings (tower 1-50, spire 1-70; flicker pinned off). Art + 12 materials: NEW tools/gen_tod_refresh_assets.py -> source_data/tod_refresh.gdt, its `--check` is a NEW full-build gate (also LOCKSTEP-checks the generator's digit crops against the atlas ink). ⚠️ THE GEOMETRY LINT NOW CLASSES A BRUSH BY ITS TOP FACE (a tread is a DECK whatever its riser wears); every other face's material must still be known. Sky: towers fade into the cloud decks (cloud ceiling), the overcast is lit over downtown (UG_NEAR/UG_FAR asserted == the city clusters), beams meet the deck, six rooftop plumes; gain re-solved 0.01549 for the same score. DROPPED: core floor rings (invisible against the 64-unit grid), stringers. NEW tools/preview_views.py renders the .map from player eyes. Full sky render took ~31 min this time (not 4.5). Test flags untouched. docs/169_surface_refresh.md.

**2026-10-02 - v19.68n: NIKOLAI'S PROPS - THE SPAWN SIGN, THE CROWN UPLINK TERMINAL, THE AMMO CHEST (user: "Add the Tower of Doom Cybercity sign part of tower wall where players spawn at" / "Replace the ammo crates with the new model from props (nikolai)" / "Replace the activation for run for the crown model to the Door Terminal Idea prop" / "Make any tweaks necessary so that the models actually look like they belong on the tower"). FULL BUILD OK 02:17:24 Eastern, FF 149,425,664 B; diffs clean, nothing synced after, .map == tools root, navmesh 2 components, bank 197.9 MB, the 10 waived only; ledger: all three models lodCount 1, the West crate and the Stalingrad terminal gone. UNPLAYED.** NEW tools/fan_props/build_fan_props.py (Blender 4.2; art/fan_props/README.md has every decision): `tod_cybercity_sign` (256 x 119, the fan's own UVs) on the core's WEST face over the spawn at the GENERATED `base_sign_org()` (-256.5, 0, 100) / yaw 180, placed by NEW `_tod_base_sign.gsc`, asserted in gen_tower_map.js BASE_SIGN against lap 2's W flight and the base chest; `tod_uplink_terminal` (84 tall, screen faces model +X = EAST to the crown stair - the old one faced the empty west end) in `_tod_finale::spawn_props`; `tod_ammo_chest` (97 x 75 x 53) for EVERY crate. Terminal + chest are BAKED (decimate-on-Meshy-UVs smeared their flat panels) on a visibility-weighted unwrap. Nikolai's normal maps are DIRECTX (tools/fan_props/normal_convention.py). THE CRATE CONTRACT: box x[-37,38] y[-49,49] (asserted against art/fan_props/manifest.json), trigger out 38 / lat 0; THE ALTAR crate W(116), THE GAUNTLET crate S(186), THE KENNEL riser (-310,100); hall bunker lint 0. Gate test_tester_fixes_0924.js moved with it. Logs `[TOD_SIGN] INIT`, `[TOD_CRATE] MODEL`, `[TOD_FINALE] UPLINK_MODEL` (tod_dev). Offered, not done: the terminal screen still reads MAINTENANCE TERMINAL; no neon light spill; the spawn still faces north. Credit: CREDITS.md names Nikolai; the Meshy plan is still open. ⚠️ THE CHEST, ITS BOX AND ITS TRIGGER IN THIS ENTRY ARE SUPERSEDED BY v19.68p (Ammo Box V6, box x[-37,33], trigger out 33).

**2026-10-02 - v19.68m: THE CYBER RAMPAGE INDUCER (user: "a redesign ... more cyber like ... Use the blender mcp ... open up an instance so i can see"; "Make sure to add animations"; "it may need a clip as well"). FULL BUILD OK 01:04:58 Eastern, FF 148,582,528 B; diffs clean, nothing synced after, .map == tools root, navmesh 2 components, bank 197.9 MB, the 10 waived only. UNPLAYED.** `tod_inducer_cyber` (+ `_on` skinOverride twin) replaces BO6's `tod_inducer` (GDT/models stay on disk UNZONED = rollback, docs/168). Authored live in a visible Blender 4.2 studio over MCP **port 9884** (`tools/inducer_cyber/`, stages 00-07 re-runnable; MCP client = `../tower_of_doom_II_hellbound/tmp/gold_sword_env/Scripts/python.exe`); master `art/rampage_inducer_cyber/rampage_inducer_cyber.blend` (centre OFF, left ON, animation playing). 44 x 44 x 67, 54,370 tris, one LOD, 2048 atlas: OFF = cyan trims + dim amber core, ON = rampage red + hot core (baked glow maps `_e`/`_eon`, scaleRGB 4/12). FIVE ANIMATED BONES + two seamless loops `tod_inducer_cyber_loop_idle` (12 s) / `_loop_on` (3 s, 4x faster) from ONE spec (`anim_spec.py` drives Blender AND the xanims); `_tod_rampage.gsc::anim_set` re-plays after every SetModel (#using_animtree "tod_inducer"). BODY CLIP `base rampage inducer body` (z 0..40, generated; geometry lint MODEL_CLIP_COLUMNS) with the trigger above it at GENERATED `base_inducer_trig_lift()` 44. Sparks at the front claw tips; lamp FX at z 35. Gate `tools/inducer_cyber/verify.py` (pre + post link) replaces `tools/inducer/verify.py`. Iterate: stage -> `export_native.py` (bg Blender) -> `install_native.py` -> `verify.py` -> FULL build. Logs `[TOD_RAMPAGE] MODEL revision=cyber_core_1`, `[TOD_RAMPAGE] ANIM clip=`. Test flags untouched (still the armed setup).

**2026-10-02 - v19.68l: THE TRIAL WALLS WERE INSIDE THE WALLS (user ran Trial I: "i dont see any chnages visually"; the log had every effect playing on time). -GscOnly BUILD OK 00:33:05 Eastern, FF 147,750,720 B; diffs clean, nothing synced after. UNPLAYED.** trial_box's edge (456) is the drum's OUTER face; its inner face is SP_RM_OUT 436 and the W/N/E liner 428. Now EIGHT segment hosts on the hall floor, 24 in front of the liner (3 N, 3 E, 1 W over the NW region, 1 on the S strip) - trial_wall_segments() LOCKSTEP with gen_trial_fx.py WALL_SEGMENTS, whose --check re-derives the geometry from gen_tower_map.js. Stronger motes / haze / win shower (+ a gold pillar). RULE: place an effect against geometry from the GENERATOR's wall constants, never from a gameplay box.

**2026-10-02 - v19.68k: RAMPAGE STRIPS BURN, NOTHING SHOOTS (user: "remove the shooting lines and make the visuals on the tower a bit stronger"); THE TEST SPIRE COMES AT ROUND 5. -GscOnly BUILD OK 00:06:08 Eastern, FF 147,639,808 B; diffs clean, nothing synced after. UNPLAYED.** fx_rampage_spine = flickering hot core + stronger red halo + a wide red haze + sparks, drift <= 12 u/s; the comets and the climbing surge are gone (surge RETIRED WHOLE -> fx_rampage_flare: every strip flashes at once on the flip). gen_rampage_fx --check FAILS any strip element faster than 20 u/s. Harness #8 ascends at ROUND 5 (dev_ascend_at_round; the pad is gone). The previous session's log proved the Archmage allplayers field LOADS. Test flags unchanged - PARK + DISARM BEFORE PUBLISH.

**2026-10-01 - v19.68j: RAMPAGE SHOWS ON THE TOWER (user: "make the tower show it instead of the player ... this strip going along the sides" -> "Go"). -GscOnly BUILD OK 23:50:39 Eastern, FF 147,640,064 B; diffs clean, nothing synced after; ledger packs the five fx,tod/rampage/* + the new _tod_rampage.csc. UNPLAYED.** The strips = the column's four CORE SPINES. ON: shockwave + flash at the switch, then a surge climbs all four strips base to crown in 3.5 s; while ON comets race up them with a red glow and sparks; OFF: smoke puff, the strips calm (StopFX). NEW CLIENT MODULE _tod_rampage.csc reads the EXISTING todRampage HUD value (no new field, no server entities), runs only the laps around its own player (3 below / 5 above, none beyond 1400 from the axis). tools/gen_rampage_fx.py (gate). TEST SETUP: harness #8 now WAITS FOR A PAD beside the Rampage switch before ascending (dev_ascend_pad_wait) - Rampage first, then the trials. Flags: tod_dev / tod_god / tod_dev_arch_test / tod_dev_all_perks + harness #8 - PARK + DISARM BEFORE PUBLISH. The switch's own glow/sparks + the other same-frame hosts: still the user's call. Logs [TOD_RAMPAGE] SWITCH_FX, [TOD_RAMPAGE_C] ON/OFF/LIT.

**2026-10-01 - v19.68i: THE HALL BECOMES THE CLOCK - the Warden Trials' effects (user: "Lets build 1 first. Highest quality"; section 2, Rampage, and the same-frame sweep are NOT built - they wait for the user's call). -GscOnly BUILD OK 23:02:46 Eastern, FF 147,630,400 B; diffs clean, nothing synced after; ledger packs all 13 fx,tod/spire/*. UNPLAYED.** Seal = a rush up all four drum walls, then sparks/motes/haze/runes rising in the hall's own SP_HUE colour; frenzy = red, faster, embers + a lub-dub red light (Trial VII from the start); win = walls stop, gold shower on the Max Ammo mark; King = a red ring tightening 280->110 on 13 quickening heartbeats over the 10 s countdown. tools/gen_trial_fx.py (gate in build_map; reuses gen_archmage_fx.elem). _tod_spire.gsc: trial_fx_* / king_countdown_fx / fx_play_on_new_host (two WAIT_SERVER_FRAMEs before PlayFXOnTag). THE PURPLE TRIAL/SUMMIT GATE WALL was same-frame (never drawn) - fixed (barrier_fx_late). 16 OTHER SAME-FRAME FX HOSTS remain map-wide (list in CHANGELOG v19.68i) - the user's call. TEST BUILD: HARNESS #8 ARMED (halls variant) + tod_dev / tod_god / tod_dev_arch_test / tod_dev_all_perks - PARK + DISARM BEFORE PUBLISH. Logs [TOD_TRIAL_FX].

**2026-10-01 - v19.68h: ARCHMAGE ON THE WORLD (user: "Lets start with archmage. High quality viusals"). -GscOnly BUILD OK 20:10:17 Eastern, FF 147,627,904 B; diffs clean, nothing synced after; ledger packs all ten fx,tod/mage/fx_archmage_* + the Keeper rune and heavy ring materials. UNPLAYED.** A prism: rainbow ring (the health bar's six colours) + breathing white-gold glow + 8 gold Keeper runes that rewrite themselves + a counter-turning gold inner ring at the feet; rainbow motes spiral up the body (red feet -> violet head); a rainbow dynamic light; a white shockwave that disperses into rainbow bands at the start; the rings implode at the timer's end. Own view is quieter (no column / fountain / flash). tools/gen_archmage_fx.py (gate in build_map); server = one 2-bit ALLPLAYERS clientfield tod_arch_form (OFF/ON/FADE, arch_fx_set in demigod_run / demigod_end); _tod_mage_elements.csc plays it per local client on three client hosts that follow + TURN every frame, KillFX on end. ⚠️ NEW CLIENTFIELD = BOOT-VERIFIED ONLY: if the map does not load, read the console for a ClientField error first. TEST BUILD: tod_dev + tod_god + NEW tod_dev_arch_test (mana full at the first ARCHMAGE card and 3 s after each form; the Mage dummy shows the effect every 30 s) + tod_dev_all_perks ON, tod_dev_coop_mock OFF - DISARM BEFORE PUBLISH. Logs [TOD_ARCH_FX] / [TOD_ARCH_FX_C]. Patch notes (unstaged) carry an Archmage bullet. NEXT: the user's look, then PUBLISH (v19.69).

**2026-10-01 - v19.68g: "RESTART TWICE IN CO-OP" = THE DEV LEFTOVER-BOT DROP ENDED THE RESTARTED GAME (stock onPlayerDisconnect -> zm::checkForAllDead fires when nobody is up yet). The drop now holds stock's guard (zm_utility::increment/decrement_no_end_game_check) until a human is up. TEST-SETUP ONLY. -GscOnly BUILD OK 16:32:04 Eastern, FF 147,478,144 B (first attempt = the known WAV checksum flake, rerun clean); diffs clean, nothing synced after. USER-CONFIRMED ("Looks good"; log 20261001_185912: one press, RESTART_UP 500 ms, no second game over - local stand-in only). Healing Aura area USER-CONFIRMED. NEXT: PUBLISH (disarm tod_dev, tod_dev_coop_mock, tod_dev_all_perks; top CHANGELOG publish entry; stage v19.69; -Publish).**

**2026-10-01 - v19.68f: THE HEAL AREA WAS INVISIBLE BECAUSE ITS EFFECT WAS PLAYED IN THE SAME FRAME ITS HOST WAS CREATED (user: "No visual still"; log: AREA_ON on every cast). heal_area_run now waits two WAIT_SERVER_FRAMEs, then PlayFXOnTag (`[TOD_HEAL] AREA_FX emitted`) - the rule _tod_teleport::fx_burst already followed (docs/143). -GscOnly BUILD OK 14:41:55 Eastern, FF 147,477,760 B; diffs clean, nothing synced after. USER CONFIRMED: "Healing aura worked". RULE: a NEW fx host waits two server frames before PlayFXOnTag; a server log line proves only that the server played it.**

**2026-10-01 - v19.68e: HEALING AURA = A FLAT GREEN AREA (rim + fill + 1 s pulse + motes), one effect per radius (tools/gen_heal_area_fx.py -> fx/tod/mage/fx_healing_aura_area_<256..416>). -GscOnly BUILD OK 14:21:58 Eastern, FF 147,478,272 B; ledger packs all six + both materials. UNPLAYED.** The v19.68 12-marker ring ran (log RING_ON 12/12) but was invisible - 6-24 unit glows half inside the floor. FLAT EFX RULES (measured): oriented sprites lie flat when the host FACES UP (angles (-90,0,0); dom.csc passes the ground's up as forward); sprite size = FULL width; stock gfx_ui_ring_thin is two BRACKET ARCS - six copies 30 deg apart make an even circle; width 2.12 x radius puts its line on the radius; gravity is % of world gravity (negative rises). User test 13:52 confirmed RESTART works (co-op stand-in: REQUEST via=host_dvar -> RESTART_BACK bots=1 -> RESTART_UP 500 ms). Patch notes (unstaged) updated: aura area + co-op wipe restart.

**2026-10-01 - v19.68d: CO-OP GAME-OVER RESTART "DOES NOTHING" FIXED (user's stand-in test). -GscOnly BUILD OK 13:27:37 Eastern, FF 147,496,896 B; diffs clean, nothing synced after. TEST BUILD: tod_dev + tod_dev_coop_mock + NEW tod_dev_all_perks ON, tod_god OFF - DISARM ALL THREE BEFORE PUBLISH. UNPLAYED.** AT GAME OVER A MENU RESPONSE NEVER REACHES SCRIPT (log: game-over menu open, press, no MENU line; stock end_game has set game_ended / intermission) - that was ALSO the tester's "freeze ... 1 minute later" (the 60 s ExitLevel). The host's request now ALSO writes dvar `tod_go_request` (host machine: menu + server share one dvar table, proven both ways), read by `_tod_gameover::go_request_watch` every 0.1 s; TodGoServer sends the request FIRST, then pcall(TodGoClose). Log `[TOD_GAMEOVER] REQUEST via=host_dvar`. Dev perks: every roster perk minus Quick Revive after the dev class max (`[TOD_DEV_MAX] PERKS`). Patch notes still unstaged; add co-op to the Restart bullet only after the user's test confirms it.

**2026-10-01 - v19.68c: ⚠️ TEST BUILD FOR THE RESTART BUTTON - tod_dev ON, tod_god OFF, NEW level.tod_dev_coop_mock ON, TOD_MOCK_PARTY OFF. DISARM tod_dev + tod_dev_coop_mock BEFORE PUBLISH (-Publish refuses them). -GscOnly BUILD OK 13:00:48 Eastern, FF 147,496,384 B; diffs clean, nothing synced after. UNPLAYED.** Rounds 1-3 solo (kit restart); from round 4 the dev Mage bot is a stand-in teammate on another PC (_tod_gameover::coop_mock_teammate -> the online co-op server lane) and going down ends the game like a wiped party (_tod_dev_mage::coop_mock_wipe_watch). Logs: `[TOD_GAMEOVER] PARTY / MENU / RESTART / RESTART_BACK lane= / RESTART_UP / RESTART_WAIT / RESTART_STUCK / RESTART_BOT_DROP`, `[TOD_MAGE_DUMMY] COOP_MOCK`. PATCH NOTES WRITTEN, NOT STAGED: docs/68 + BBCode `Update — Oct 1 (v19.69)` (14 bullets, window = v19.67 / v19.68 / v19.68b). Publish = disarm, the publish CHANGELOG entry on top, `patch_notes.js stage --version v19.69` (retitle the date if not Oct 1), `build_map.ps1 -Publish`. docs/167 'Restart test setup'.

**2026-10-01 - v19.68b: RESTART - SOLO + SPLIT-SCREEN ARE BACK ON THE AETHERIUM KIT'S OWN RESTART (user: "MY main issue people are complaining about is the restart button" / "the stock aetherium HUD had this perfectly set up ... once we started tweaking i think we got lost in our own code"). -GscOnly BUILD OK 12:06:47 Eastern, FF 147,493,696 B; diffs clean, nothing synced after, bank 197.9 MB, the 10 waived only. Dev / god / TOD_MOCK_PARTY still ARMED. UNPLAYED.** Every human at this machine (solo / split-screen) -> the kit's `GoBack` + `Engine.Exec(c, "map_restart")` / disconnect VERBATIM (`TodKitRestart` / `TodKitLeave` behind `TodLocalParty`); ONLY a host with a teammate on ANOTHER machine uses the server request (unpause + StartMenuGoBack, then map_restart( true ) / ExitLevel( false )). Stock splits the same way. Fact = `party_push` host value 0 / 1 (remote teammate) / 2 (all local) from `IsLocalToHost()`; dvar `tod_party_remote` (written at level start) is the host machine's fallback; nothing known = a teammate's machine -> the server lane. The cached game-over flag is cleared on HUD build + every restart. DO NOT move solo back onto the server lane: v19.63 did and froze it. Gates: NEW tools/test_restart_menu.lua (presses the real buttons, 11 party shapes; v19.66 / kit / 11:13 shapes all fail it) + tools/test_coop_restart_lane.js (28 controls). UNPROVEN NATIVELY: the online co-op server restart; watch for last game's kills/downs on the board after it (map_restart( true ) keeps pers). docs/167 item 9b.

**2026-10-01 - v19.68: THE LEAD TESTER'S LIST, 14 OF 16 FIXED (checklist, causes, reviews: docs/167_tester_fixes_oct1.md). FULL BUILD OK 11:13:27 Eastern, FF 147,492,544 B; scripts/zone_source/ui diffs clean, nothing synced after, the 4 edited GDTs == tools root, bank 197.9 MB, the 10 waived only, 109/109 weapon models, 0 missing techsetdef. Dev / god / TOD_MOCK_PARTY STILL ARMED (the v19.66b setup) - DISARM BEFORE PUBLISH. UNPLAYED; the user tests.** Healing Aura ground ring (12 green markers on the cast radius that go out like a clock; root entity + MoveTo, never LinkTo'd to the player; fx tod/mage/fx_healing_aura_ring from tools/gen_heal_ring_fx.py) + the Lv6 revive's green "+" burst (`tod_heal_burst` -> CoD.TodHealBurst). Mage Widow's Wine: a web tile left of Blink (the Mage holds web grenades its lethal tile never showed). STAFF PIECES FLOATING = the world shaft's generated LODs decimating it away: tod_staff_world + 3 ice world models single-LOD (tools/staff_world_lods.py, gated pre-sync + post-link). BLADE INSPECT = the T9 ports' reloadAnim, and a pad's X is +usereload: all 37 blade forms now have no reload animation + a one-frame reload (the inspect is gone - a reload cannot be cancelled). Lunge kill recovery (meleeChargeFatalTime) now scales with swing speed; queue window 0.35. Slasher crawls with the map's down pistol (level.zombie_last_stand -> down_pistol_give). Hoop 50. RESTART FREEZE = `GoBack` NEVER UNPAUSES (StartMenuGoBack does): TodGoClose before every host request. SPLIT-SCREEN = one client Lua VM for both local players: party facts per controller (CoD.TodPartyBy) + server `IsHost() || IsLocalToHost()`. Party gap: baseYTop 524 -> 570.5. Scoreboard/pause line = FLOOR n / THE CROWN / SPIRE FLOOR n (`tod_floor_label`). Stock chat fades with the scoreboard. Altar crest: LOD switches 260..3200 -> 1000..4500 (measured: the emblem breaks from LOD2). NOT DONE: the loading screen (a usermap cannot replace it - map 1 KB; a solo loading movie is the only lane, offered). PARTIAL: the mouse wheel (no proven lane; `[TOD_CARD_WHEEL]` dev probe). New build gate tools/test_tester_fixes_1001.lua (lupa). Logs: `[TOD_HEAL] RING_ON/RING_OFF/REVIVE_BURST`, `[TOD_LOADOUT] DOWN_PISTOL`, `[TOD_CARD_WHEEL]`, `[TOD_GAMEOVER] MENU ... local_to_host=`.

**2026-09-30 - v19.67: TEAMMATES' SHIELD BARS (user: "other players shield bar above their health bar ... I dont want the icon as well").** A shield's health is a per-player clientuimodel only its owner receives, so `_zm_aetherium_hud::party_shield_watch` (post-func) reads every player's value back (`get_player_uimodel( "zmInventory.shield_health" )` + stock `hasRiotShield`) and broadcasts all four on ONE int (`TOD_SHIELD_BITS` 128 per slot) via `LuiNotifyEvent( &"tod_party_shield", 1, packed )`; `AetheriumPartyPlayers.lua` paints a thin bar (2 in a 4 trough, local bar's colour bands, NO icon) between the name (lifted 2.5) and the health bar. Dev previews it on unoccupied slots. LOCKSTEP `SHIELD_BASE` == `TOD_SHIELD_BITS`, gated by NEW `tools/test_party_shield.js` (build_map.ps1). Log `[TOD_SHIELD] SEND`. **-GscOnly BUILD OK 23:20:30 Eastern, FF 147,402,432 B** (still the armed dev/god/mock test build below); the new gate ran in it; diffs clean, nothing synced after, deployed GSC/Lua carry the new code; bank 197.9 MB; the 10 waived only. Log tmp/party_shield_20260930/build.log. UNPLAYED; the user looks (mock rows: slot 1 = the Mage bot, no bar; slot 2 full blue; slot 3 sweeping).

**2026-09-30 - ⚠️ TEST BUILD ARMED AFTER THE v19.66 UPLOAD: level.tod_dev + level.tod_god = true (zm_tower_of_doom.gsc) AND `TOD_MOCK_PARTY` = true (AetheriumHud.lua) - user: "rebuild with dev and god mode on and mock a 4 player game. I want to see what the UI looks like now". DISARM ALL THREE BEFORE ANY PUBLISH (-Publish refuses them).** The mock = fake GhostByte_99 / NeonNomad / ZombieJugglerPrime99 party rows (Skirmisher / Assault / Slasher medallions) + `_zm_aetherium_hud::mock_party_feed` moving their bars; it MASKS real teammates while armed. Dev also spawns the Mage preview bot (hidden behind the mock rows) and maxes the drafted class. HUD Lua tests (pause text, typography, lifetimes, global guard, Lua lint) green with the mock armed. **-GscOnly BUILD OK 23:00:33 Eastern, FF 147,400,896 B**; scripts/zone_source/ui diffs clean, nothing synced after, deployed tod_dev/tod_god true + TOD_MOCK_PARTY true, the 10 waived only, bank 197.9 MB; no peer linker during it. Log tmp/mock_party_20260930/build.log. UNPLAYED; the user looks.

**2026-09-30 - v19.66 PUBLISH BUILD VERIFIED 22:44:53 Eastern, FF 147,400,896 B; -CleanPak + all twelve languages, payload 2,622,806,139 B / 48 files; banks full, the 10 waived, diffs clean, nothing synced after, deployed tod_dev / tod_god / tod_dev_blood_shelf false. UPLOADED 2026-09-30 22:55 Eastern (row #47 CLOSED by `patch_notes.js uploaded`, Steam fetch; evidence tmp/publish_v1966_20260930/build3.log).** Row #46 (v19.62) CLOSED: it went live 2026-09-27 20:56 (user-pasted page; the v19.63 "never uploaded" note was wrong). Notes `Update — Sep 30 (v19.66)` (11 bullets) = v19.63 .. v19.65c. STILL OPEN: the Cyber Teddy credit (the fan's name; the Meshy plan - CREDITS.md). ⚠️ **LANGUAGE PASSES NOW RETRY THE WAV-CONVERTER FAULT** (build_map.ps1 `$maxLangTries` 6, `$wavFlake` signature only, plus a bank-shrink guard): two publish attempts died on it (french, englisharabic) because only the English pass retried; the passing run needed 8 retries over 6 languages. A Tower II linker from another session overlapped one pass; italian flaked with ours alone. Memory language-link-checksum-flake.

**2026-09-30 - TEST BUILD (dev + god + NEW level.tod_dev_blood_shelf) - DISARMED for the v19.66 publish above.** `_tod_powerups::dev_blood_shelf`: after the draft/first deal (and the dev Mage bot landing), four never-expiring Zombie Blood drops in a fan +-35/+-65 deg, 150 u in front of the host, on navmesh floor, 110 u clear of any other player (the Mage bot stands 128 ahead); a taken one returns after 10 s. Logs `[TOD_BLOOD] DEV_SHELF placed=/slot=/drop=` + the FX_* lines.
⚠️ **THE FIRST SHELF BUILD (-GscOnly 20:55:07, FF 147,400,640 B) CRASHED EVERY LOAD, DEV ON OR OFF** - user's screen: "server script error / cannot cast undefined to bool / Terminal script error / scripts/shared/flag_shared.gsc:0"; console stack flag_shared <- `_tod_powerups.gsc:946` <- `:153` (`__init__`) (archive tmp/elite_tracking/runs/20260930_213638_412_e8af9923). The shelf was threaded from the system `__init__` and waited on `initial_blackscreen_passed` BARE - stock runs every `__init__` from CodeCallback_PreInitialization, BEFORE level main, and `_zm.gsc` init_flags() creates that flag IN main, so the read negated undefined. The two sibling threads in the same `__init__` already carried the exists-poll and a comment about this exact crash (2026-08-25). FIXED: same exists-poll. **NEW GATE `tools/lint_tod_init_flags.js`, every build incl. -GscOnly**: no flag read (get/toggle/every wait_till*) on any system `__init__`'s synchronous path - followed into same-file calls/threads up to their first yield - without a `flag::exists`/`init` of that name first; 16 synthetic shapes self-tested each run; on the real file it catches the shelf and both siblings with their polls removed; 86 scripts / 37 pre-funcs clean. **-GscOnly BUILD OK 21:49:07 Eastern, FF 147,400,896 B**; both new gates ran inside it (init-flags OK, Zombie Blood 41 checks); scripts/zone_source/ui diffs clean, nothing synced after the .ff, deployed `dev_blood_shelf` carries the exists-poll, deployed tod_dev/tod_god/tod_dev_blood_shelf = true; bank 197.9 MB; the 10 waived only. Log tmp/zb_filter_20260930/build_shelf_fix.log. UNPLAYED; the user tests.

**2026-09-30 - v19.65b: ZOMBIE BLOOD'S TINT + A STOCK visionset_mgr BUG. -GscOnly BUILD OK 20:43:26 Eastern, FF 147,399,552 B; diffs clean, nothing synced after. UNPLAYED.** User on v19.65: "Definetly a distortion but no tint". The zombie_blood shader (techsetdef + its compiled ps, disassembled with d3dcompiler_47) reads scriptVector0 only: .x warp, .y colour + blood motes, .z colour-mask reach; stock's filter style sets one constant, so `level.vsmgr_filter_custom_enable[ "generic_filter_zombie_blood" ]` now sets all three (TOD_BLOOD_WARP/TINT/MASK, all 1.0). ⚠️ STOCK BUG the same log caught: visionset_mgr_shared.csc's FILTER switch-off indexes custom_disable[ curr_info.material_name ] with the "__none" slot -> "undefined is not an array index" before the pass is disabled (the filter sticks). `blood_filter_guard_infos()` gives every overlay info a placeholder material_name. Memory visionset-unregistered-strands-state.

**2026-09-30 - v19.65: ZOMBIE BLOOD SHOWS ITS OWN SCREEN FILTER. -GscOnly BUILD OK 19:46:36 Eastern, FF 147,399,360 B; diffs clean, nothing synced after, the new gate ran in the build, ledger still has the Cyber Teddy. UNPLAYED (the user's "no difference" test ran the 12:36 build, before this was built).** Why it was missing: the August visual activated an UNREGISTERED visionset_mgr name (zm_bgb_in_plain_sight), which killed the window thread and made one pickup a permanent god mode; the fix deleted the visual. Now Treyarch's own `generic_filter_zombie_blood` (retail zm_common, no zone line possible) as visionset_mgr overlay "tod_zombie_blood" (prio 110, 16 steps), registered in both `tod_powerups` REGISTER_SYSTEM __init__s; client maps the material id at connect/spawn. Clock = the window countdown: 0.5 s in, hold while > 1.0 s left (`zombie_blood_fx_hold`), fade ends on the expiry frame; re-grab no dip; down cuts; end_game cleans. Start/stop run in their OWN threads (the August lesson). Origins' vision grade is NOT in usermap-loadable files; In Plain Sight's was declined. NEW BUILD GATE tools/test_zombie_blood_filter.js (32 checks incl. a frame model; 3 negative controls). Logs `[TOD_BLOOD] FX_ON/FX_FADE/FX_OFF rev=zb_filter_1` (dev) + `[TOD_BLOOD_C] ... matid=` (devblock). Built 19:46:36; UNPLAYED.

**2026-09-30 - v19.64: THE SONG-HUNT BEARS ARE THE FAN'S CYBER TEDDY (user: "update the teddy bear to the cyber teddy"). FULL BUILD OK 12:37:28 Eastern, FF 147,498,240 B; scripts/zone_source/ui diffs clean, nothing synced after, bank 197.9 MB, the 10 waived only; ledger packs `xmodel,tod_cyber_teddy` + `mtl_tod_cyber_teddy` (lit_emissive_plus) + both images, zero `p7_zm_teddybear`. Carries v19.63. UNPLAYED; the user tests. Dev flags OFF.** `tools/cyber_teddy/build_cyber_teddy.py` (Blender 4.2) writes model_export/tod_cyber_teddy + source_data/tod_cyber_teddy.gdt + art/cyber_teddy/manifest.json from the md5-pinned fan FBX: rest pose, one bone, pivot at the bbox centre, front -Y, 28 units, glow map cut from its own blue-violet lights. `TOD_SECRET_LIFT` 14.0 / `_HALF_DEPTH` 7.9 MUST equal the manifest (test_v1896_secret_killconfirm_bottle.js). New sync line for model_export\tod_cyber_teddy. ⚠️ **RADIANT'S CONTROLLER PREF STALLS BAKES:** a gamepad press opened Radiant's Preferences (Controller tab) inside the hidden LED bake and froze the first attempt (user saw the popup); `HKCU\Software\Treyarch\Radiant\Prefs\Controller_Enabled` is now `false` for every tools install on this machine (backup tmp/cyber_teddy_20260930/radiant_prefs_backup.reg; memory radiant-controller-popup-stalls-bake). CHANGELOG v19.64 is now the top entry.

**2026-09-30 - v19.63: WORKSHOP BUG PASS + FIVE USER RETUNES. FULL BUILD OK 10:08:07 Eastern (second full build; the 09:50:13 one lacked the swing pass), FF 147,402,304 B; scripts/zone_source/ui diffs clean, nothing synced after, tools-root tod_weapon_twins.gdt == repo, banks 68,465,920 / 207,523,840, errorlog = the 10 waived, 109/109 weapon models, deployed GDT carries FIRE_STEP 0.90 (msmc f1 fireTime 0.072), melee 1760/5984 and bat swing 0.747; dev flags all false. UNPLAYED; the user tests. Evidence tmp/ws_bugs_20260930/ (build_full4.log, the 183 Workshop comments). SLASHER SWING +10% (second ask): `SLASHER_SWING_MULT` 0.90 on every blade's meleeTime/meleeChargeTime base (PaP + KNIFE SPEED rungs compose on top); armory BLADES mirrors it. NEW BUILD GATE `tools/test_coop_restart_lane.js` (build_map.ps1, 10 negative controls): no client-side `Engine.Exec map_restart` under ui/, Restart + host End Game on the server lane, Lua/GSC menu name + key in lockstep, IsHost + game["state"] + map_restart( true ) + ExitLevel( false ), tod_party published and read - the restart bug shipped three times because nothing checked HOW the menu restarted. ⚠️ THIS .ff REPLACES THE v19.62 PUBLISH BUILD in the deployed tree (row #46 still pending, never uploaded): a publish now needs a fresh -Publish build and a re-staged v19.63 notes section (CHANGELOG v19.63 is the top entry).**
CO-OP RESTART (Tixy Sep 7, Biffbrooks11 Sep 29 "the restart button doesn't work
... 'End Game' ... disconnects us from each other"): Restart Level / Restart Map /
the host's End Game were CLIENT console commands (Engine.Exec map_restart /
disconnect) - the host reloaded alone and the peer fell to the menu; v19.16's
"hide Restart in co-op" IS the second report. Now `tod_go|restart` / `tod_go|end`
on the StartMenu_Main menu-response lane -> `_tod_gameover::go_menu_watch`, HOST
only: `game["state"]="playing"` + `map_restart( true )` (stock's MP round-switch
recipe, every client stays connected) / `ExitLevel( false )` (party to the lobby
together). Menu closes first (solo pause = paused server). Party facts for the Lua:
`party_push( go )` -> `tod_party` ( humans, i_am_host, gameover_up ), every 5 s +
on change + once at the game-over menu; `CoD.TodParty` in AetheriumHud; dvars are
the host-only fallback. Restart shows for the HOST in solo AND co-op. Log
`[TOD_GAMEOVER] PARTY/MENU/RESTART/END` (developer runs, not tod_dev-gated). Memory:
restart-is-a-server-call. BLACK SCREEN AT THE DRAFT (reports after the v19.40 fix
shipped): `fog_off` start/halfway 100,000,000 / 100,000,001 are the SAME float32 ->
a second divide-by-zero; halfway now 200,000,000 (`TOD_FOG_OFF_HALFDIST`). SPECTATING
A MAGE showed 999: AetheriumLoadout hides both ammo cells whenever the held weapon's
category is a staff (`TOD_STAFF_CAT`). BAT "0 / 0" after a sidearm swap: the clip
models publish before the name; `todApplyWeapon` repaints both cells (`repaintAmmo`).
PARTY ROWS with a gap at 2-3 players: `AetheriumHud.TodPartyRelayout` stacks the
OCCUPIED rows bottom-up (`AetheriumPartyPlayers.TodSetRank`); the anchored scale now
sits on a wrapper per row (closed explicitly, lifetimes test green). RETUNES: FIRE
RATE twin -8% -> -10% shot time / Lv (`FIRE_STEP [1,0.90,0.80,0.70]`, card art has no
number); SLASHER +10% all around (melee 1760/3520, 3520/7040, 5984/11968 in BOTH
`MELEE_TIER_DMG` and `register_melee_dmg`; AMP63 mult 0.9375 -> 1.03125 +
`SEC_T1_REF.slasher`, so UDM/RK7 follow; test_baseball_bat pin moved); GIFT OF DEATH
+20% on elites (`XMAS_ELITE_BUFF` / `TOD_XMAS_ELITE_BUFF` 1.3 -> 1.56 lockstep pair -
Panzer, Protector, Reaver, hound; the King's divisor untouched). NOT changed, by
design or already fixed: the crown-seal straggler report (= the v19.37 F06 fix, live
since Sep 24; stragglers die at the seal by design), the Sep 15/16 Warden King crash
(the user's Sep 17 rollback), KILL RELOAD (retired), BULLET FEED on the Nail Gun (a
secondary), PS4 conversions. A Tower II build from C:\BO3Tools\TOD2Cybercity ran in
parallel at 09:26-09:43; build_map.ps1 refused to start over it (correctly), our build
began at 09:43:50 after 60 s of no compile processes.

**2026-09-27 - v19.62 PUBLISH BUILD VERIFIED 20:46:36 Eastern, FF 147,341,824 B; -CleanPak + all twelve languages, payload 2,599,317,883 B / 48 files; banks full, 10 waived errors, diffs clean, nothing synced after, deployed flags all false. AWAITING UPLOAD (evidence tmp/publish_v1962_20260927/).** Pause-menu upgrade lines get ~4 units of air between them (act line back at 45..59 / 38..50, compact eff 24..37). DEV + GOD DISARMED (zm_tower_of_doom.gsc). Carries v19.58-v19.61 + the peer's staff third-person stone glow. Notes `Update - Sep 27 (v19.62)` (20 bullets) STAGED as ledger row #46; window = everything since #45 v19.57 (user-pasted live page matches). **Owed: the upload, then `node tools/patch_notes.js uploaded`.**

**2026-09-27 - v19.61: MORE SPACE BETWEEN PAUSE-MENU UPGRADES + ARCHMAGE KEY FIX (-GscOnly BUILD OK 20:21:26 Eastern, FF 147,341,824 B; UNPLAYED).** Pause-menu row pitch is DERIVED from the room above the bottom bound (cap 12 units of air, never below the row height); text lines 2 units closer to their plate. Keyboard aim is "+toggleads_throw" in the stock binds, so "+speed_throw" read "Unbound": `TOD_KEY_ALTS` tries both, "Unbound" is never a key. Keyboard key names DO resolve in game (docs/145 settled). This .ff also carries a peer's unfinished staff 3p-glow GDT edits; their full build is still owed.

**2026-09-27 - THIRD-PERSON STAFF STONE GLOW ONLY (SOURCE READY; FULL BUILD PENDING).** User reports glow regressed after retail material restoration. World-only fire/lightning crystal skins restore pass-2 scaleRGB16/tints, including separate PaP world model definitions using the same binaries. First person/ice/geometry/sockets/gameplay unchanged. Generator + gates updated; source/state checks pass. Existing dev preview marker adds world_crystal_glow=16_world_only. docs/166; tmp/staff_3p_glow_20260927/ (backups, archived console, scoped diff, 1,408-input snapshot). USER IS STILL PLAYING (explicit reply); no build or launch. Full build owed once BO3 exits; re-snapshot before build and verify deployment.

**2026-09-27 - v19.60: ABILITY LINES "PRESS <KEY> TO <VERB> - ..." + CONTROLLER BUTTON 1.25x (-GscOnly BUILD OK 18:51:19 Eastern, FF 147,496,832 B; UNPLAYED).** AetheriumStartMenu `TodActLine` splits each ability act line at its bind token: PRESS / key / rest at one shared cap. Key is glyphs when the keyboard name resolves, else engine text sized by stock `getTextWidth()`; pad key box x1.25 (`TOD_PAD_KEY_GROW`). Aura radius + Archmage speed moved up to the effect line. `[TOD_KEYS]` dev log = the raw key lookup bytes (settles docs/145's unproven keyboard resolution). test_pause_text_all runs the real layout (276 cases) in every build. An 18:27 peer build_map process exited having written nothing.

**2026-09-27 - v19.59b: NO ENGINE-FONT TEXT LEFT ON THE PAUSE MENU OR SCOREBOARD (-GscOnly BUILD OK 17:20:44 Eastern, FF 147,496,128 B; UNPLAYED).** Mage key lines: only the key stays engine text (right-aligned slot); the words are always glyphs (keyboard key-name lookup is still unproven, docs/145). GAME TIME clock is glyphs via `_tod_upgrade_ui::game_time_push` (`tod_game_time`, CoD.TodGameSecs). NEW BUILD GATES: tools/test_pause_text_all.lua (every upgrade line, every level, plain+dark, all classes - no dropped letters, nothing under 80% size), test_typography.lua, test_ui_lifetimes.lua (now with the typeface loaded). Scoreboard salvage/Level were already hidden. Stock options popups are the engine's.

**2026-09-27 - BASE FIRE/LIGHTNING SOCKET FOLLOW-UP (FULL BUILD OK 17:09:34 Eastern; UNPLAYED).** User retest exposed incomplete base/PaP coverage. Both base view sockets were blank although the compiled animation rig parents each head at tag_tip; original BO3 also explicitly uses that socket. Both base sources + four handling twins now attach at tag_tip, preserving articulated heads and all clips. New gate checks model/animation hierarchy, rejects the previous blank socket. 48 clips / 1,636 frames reconstruct correctly offline; this is NOT native visual validation. Existing PaP/world sockets, ice, materials, geometry and combat unchanged. Dev marker base_tip_socket_3. FF 147,496,128 B; 1,408 source/deployed inputs match, native DB confirms all six base records + packed sockets, full banks, 109 weapon models, zero missing shaders. docs/166 follow-up; tmp/staff_base_20260927/. USER TESTS; no launch.

**2026-09-27 - v19.59: SOLO RESTART + READABLE PAUSE TEXT (-GscOnly BUILD OK 15:41:06 Eastern, FF 147,493,952 B; UNPLAYED).** Restart was hidden in solo DEV runs because the dev Mage preview bot counted as a player (`tod_party` 2). `party_dvar_watch` now skips test clients. Pause-menu glyph lines use their own scales (EFF_GS 1.0 / ACT_GS 0.94, measured to stay inside each row); scoreboard effect line 1.0. Keyboard key tokens in Mage act lines are resolved (`TodActKeys`) and drawn in the typeface; controller keeps engine text. A peer's mid-build `_tod_dev_mage.gsc` INIT label (tip_socket_2) is NOT in this .ff; their staff tip-socket build is still pending. Dev + god still ARMED.

**2026-09-27 - UPGRADED STAFF TIP SOCKET + RETAIL MATERIAL CORRECTION (FULL BUILD OK 15:49:47 Eastern; UNPLAYED).** User identified the round structure beyond the crystal, not the intentional side blades/spikes. Full-shaft Blender reconstruction reproduces the screenshot when the rigid upgraded head falls back 22.071 units toward the weapon root. Fix: unique unkeyed root on both packed heads + explicit tag_tip attachment in BOTH views. No geometry/ice/combat changes; base articulated merge-by-name retained. Broader retail audit also restores five metal materials from original GDT (old port incorrectly used pistol gloss/occlusion/camo maps and gloss 17 instead of 13), retail crystal scale8/tints, original fire/lightning persistent FX size; 28 original textures now repo-owned. tools/restore_staff_retail.py gate pins original fields/textures. Docs/166_staff_tip_socket.md; tmp/staff_edges_20260927/. Previous Mage playtest confirms T3, 14 eligible domains, missing=0. Logger marker tip_socket_2. FF 147,494,976 B; 1,408 inputs match deployed, nothing synced after FF; native DB verifies seven retail material blocks and both view/world sockets, 6 complete heads, 109/109 weapon models, zero missing shaders, complete banks 68,465,920 / 207,523,840. Exact retail animation/native appearance parity is not established by these source/build checks. USER TESTS; no game launch.

**2026-09-27 - COMPLETE FIRE/LIGHTNING HEADS + DEV CHOSEN-CLASS MAX (FULL BUILD OK 15:21:26 Eastern; UNPLAYED).** User reports pass-2 staffs still wrong and asks to rebuild if needed; ice accepted. Six new native heads merge the ORIGINAL head and crystal geometry, crystal vertices on head root; base slot1 + packed model0 carry complete heads, separate slot2/model1 cleared. Source round-trip preserves metal, UVs, normals, original weights and all gameplay/ice fields; no animation edits. materials keep pass-2 element glow. tools/build_staff_assembly.py + source/compiled gates; docs/165_staff_assembly.md; art/staff_assembly/geometry_review.*. Dev now maxes whichever class the player picks after the normal draft/card pause (T3, PaP, eligible domain caps), skips the preview dummy, logs TOD_DEV_MAX actual result. All five class tests pass. Inherited automatic LOD reductions removed; all six heads compile as one LOD with every source triangle retained. FF 147,492,608 B; 1,373 source/deployed hashes match, nothing synced after FF; complete banks 68,465,920 / 207,523,840 B, 109/109 referenced weapon models, zero missing shaders, ten established waived asset messages. Evidence tmp/staff_repair_20260927/build_final.log + deployment_receipt.json. Native appearance and class grants await the user test. Earlier docs/164 unbuilt label was stale: pass 2 actually built 14:31:10; this is a structural assembly repair after that playtest. Golden inducer liquid retained. No game launch; USER TESTS.

**2026-09-27 - RAMPAGE INDUCER LIQUID RESTORED (BUILT 14:31:10 Eastern; USER ACCEPTED).** User played the 13:46 clear-chamber build: looks better, but liquid disappeared. Revision amber_liquid_2 restores the BO6 yellow-gold fill (neutral tint), with stronger inner opacity and clearer outer wall; ON remains brighter. Only four liquid PNGs change; canister geometry, GDT, metal/crystal/gauge textures and brightness multipliers retained. Source checks + native Blender review pass; docs/163 follow-up; evidence tmp/inducer_liquid_20260927/. Initial guard stopped before sync during a new user match; the other staff build included this update at 14:31:10 (FF 147,408,448 B). Latest console archived in tmp/staff_repair_20260927/user_logs/ confirms amber_liquid_2; user: "it looks great" before requesting staff repairs. Keep this liquid unchanged. USER TESTS; no agent launch.

**2026-09-27 - RAMPAGE INDUCER PRESENTATION REPAIR (FULL BUILD OK 13:46:32 Eastern; UNPLAYED).** Original BO6 canister retained; four dump-local crystals moved inside its clear chamber and feet grounded. Packed normals/gloss decoded; harsh reflections restrained; opaque red fluid replaced with translucent scrolling gold energy; actual red instrument mask retained. Existing ON sparks/pulsing light and interaction/audio retained. Native Blender review: art/rampage_inducer/native_review.blend + .png; docs/163_rampage_inducer_presentation.md. Build source gate + hashes; dev marker MODEL revision=clear_chamber_1. Evidence tmp/inducer_20260927/. Initial full compile/bake succeeded, link hit the known WAV checksum flake. Retry restored both full banks, then post-link gate caught concurrently edited staff crystal GDTs absent from the initial sync; final full build includes that validated update. FF 147,402,624 B; 504 source/deployed hashes match, nothing synced after FF; banks 68,465,920 / 207,523,840; 10 waived linker messages; 111/111 weapon models linked, zero missing shaders. Both inducer states retain 32,839 compiled triangles; all six zombie/altar materials verified at depth zero in native DB with original brightness. USER TESTS; no game launch.

**2026-09-27 - CYBER EQUIPMENT + ALTAR SURFACE GLOW CORRECTION (FULL BUILD OK 13:46:32 Eastern; UNPLAYED).** User explicitly chose the Cybercity II teleporter fix: keep colored lights, remove displaced glow. Six fullspec materials now pin waterRoughness=0 (native layerDepth); installers + existing validators retain it. No gloss/emission/texture/mesh changes, including the accepted altar finish/interior. Docs/162_model_surface_glow.md; evidence tmp/surface_glow_20260927/. Initial build guard stopped before sync because BlackOps3 started. UNPLAYED; the user tests.

**2026-09-27 - v19.58: ONE THING ON SCREEN AT A TIME; THE MAP TYPEFACE ON EVERY SCREEN; DISPLAY-vs-REALITY FIXES. DEV + GOD ARMED for the user's test (zm_tower_of_doom.gsc) - DISARM BEFORE PUBLISH. v19.57 IS LIVE (uploaded 2026-09-24 22:25, row #45 closed 2026-09-27). UNPLAYED; the user tests. Evidence tmp/ui_overlap_20260927/.** -GscOnly BUILD OK 11:14:52 Eastern, FF 147,494,208 B, bank 197.9 MB (one sound-bank retry, recovered), 10 waived linker errors; scripts/zone_source/ui diffs clean, nothing synced after the .ff; deployed tod_dev/tod_god = true.
Scoreboard opened by the player -> that player's centre banners step aside
(`tod_upgrade_ui::banner_track` + `scoreboard_watch`, "tod_sb|1/0" on the
StartMenu_Main menu-response lane); the forced end board hides the upgrades
panel and the map HUD. Typeface: `CoD.TodGlyphText.Label()` is a drop-in for
LUI.UIText (TG_SANITIZE copy net; + / on the digit sheet; % : composites;
growing pools) on the pause menu, buttons, scoreboard, powerup banner; server
IPrintLnBold notices -> `tod_upgrade_ui::toast( TOD_TOAST_* )` (_tod_toast.gsh
ids, Lua TOAST words); CHOOSING line = bitmask event; end-screen lines drawn by
the forced board (`tod_gameover::end_screen_push`). ⚠️ Each glyph is an element:
scoreboard ~300 at build (was 75), full pause menu ~1,200 - native element-pool
headroom UNMEASURED. Money: Mage kills pay 80 (the team gate never fired),
nuke-caught and riot-shield kills pay, popups use the stock formula + BOUNTY,
Trailblazer popup = its 30, downed killers get no popup, elite row rounds,
Protector kills count on the board. Insta-Kill verified correct (one-hit horde,
3x elites). Staff 3p: `armminigun` + tag_weapon_right (the real Origins pb_/pt_staff clips,
resident in zm_common - nothing zoned; docs/161; fallback = bow/left). GIANT
SLAYER + GUNSLINGER count the armored sprinter (`is_card_elite`). Toasts sit at
y396..434 and wait out card deals / the draft. FULL BUILD OK 11:51:03 Eastern, FF 147,494,528 B (compile + LED bake), bank 197.9 MB, 10 waived linker errors; scripts/zone_source/ui diffs clean, nothing synced after the .ff; tools-root tod_staff.gdt + tod_weapon_twins.gdt == repo (armminigun on all 8 twins + 3 sources); deployed tod_dev/tod_god = true. UNPLAYED. Gates: tools/test_typography.lua (new),
test_mage_kill_points (fixed), lifetimes, global guard, arity, Lua/hint/asset lints.

**2026-09-24 - v19.57: THE LAP-DOOR GATE POST STANDS ON THE RAILING LINE (user, v19.56 screenshots: "the small empty slit ... Its the door frame that needs to be moved"). FULL BUILD OK 21:53:11 Eastern, FF 147,486,144 B (own compile d3dbsp 21:48:39 + bake .led 21:51:02); scripts, zone_source and ui diffs clean, tools-root .map == repo, nothing synced after, banks 68,465,920 / 207,523,840, errorlog = the 10 waived; carries v19.55 + v19.56. Dev flags OFF. UNPLAYED; the user tests. PUBLISH BUILD VERIFIED 22:16:00 Eastern, FF 147,486,144 B; -CleanPak + all twelve languages (every language .ff stamped 22:10-22:16 from this tree), payload 2,586,486,331 B / 48 files; scripts, zone_source and ui diffs clean (only the linker's own language output dirs differ), nothing synced after the .ff, tools-root .map == repo, banks 68,465,920 / 207,523,840, errorlog = the 10 waived; deployed tod_dev*/tod_god all false, TOD_STAFF_RATE_LOG / TOD_SMASH_LOG / TOD_HOOP_LOG 0, TOD_MOCK_PARTY false; ledger row #45 stamped with the .ff. AWAITING UPLOAD - then node tools/patch_notes.js uploaded. Evidence tmp/publish_v1957_20260924/.**
Post x PX..PX+PARA on the door line, floor to lintel top (lap 1: to 288, ending
the anti-bypass wall); the landing rail and the flight's first para box are
notched DOOR_POST_NOTCH 10 each side of it (`doorPostAt`). Closed slab + post =
core face to railing, no gap. Slab CORE..PX, slide 168, nothing ON the railing
(v19.56 stands). Proof: tmp/door_post_20260924/post_overlap.js (50 posts, 0/0).

**2026-09-24 - v19.56: LAP DOORS STOP AT THE RAILING - NO CAPS, NO JAMBS (user after playing v19.55: "The door should not be overlapping with the railing"). FULL BUILD OK 21:24:32 Eastern, FF 147,406,208 B (own compile d3dbsp 21:20:21 + bake .led 21:22:44); scripts, zone_source and ui diffs clean, tools-root .map == repo, nothing synced after, deployed slide 168, banks 68,465,920 / 207,523,840, errorlog = the 10 waived; carries all of v19.55. Dev flags OFF. UNPLAYED; the user tests.**
The slab is CORE..PX, its edge ON the railing's inner face; nothing in the rail
band; TOD_DOOR_SLIDE_DIST 168 (LOCKSTEP slab width + 8). The slot above the rail
beside a closed door stays OPEN BY THE USER'S CALL - v19.51 jambs and v19.54 caps
both filled it and both were rejected. Do not fill it again.

**2026-09-24 - v19.55: LEAD-TESTER FIXES (user: "Fix the first 7, and Slasher teddy bear. The rest dont fix"). -GscOnly BUILD OK 18:53:56 Eastern, FF 147,086,208 B (also carries v19.54's door caps via the 15:56 compile); diffs clean, nothing synced after, banks 68,465,920 / 207,523,840; dev flags OFF. UNPLAYED; the user tests. Evidence tmp/tester_fixes_20260924/.**
(1) NO RK5: stock's super-EE reward is `level.super_ee_weapon` (pistol_burst),
given by give_start_weapon beside the start pistol; now `= level.start_weapon`
(zm_tower_of_doom.gsc, after zm_usermap::main) + take_foreign_secondaries reaps
pistol_burst. Downed mage: mana state 4 = stock panel + ammo rows, tiles stay.
(2) Co-op QR waits for `power_on` before re-stamping its BUY hint. (3) Zombie
Blood: every boss AGGRO pick is `is_player_valid( p, true )` (Panzer retarget,
Protector hunt/fire/zap, hounds, claw) and `tod_closest_player` FILTERS ITS OWN
LIST - zombie_utility::get_closest_valid_player (the Panzer's stock service)
hands overrides every player, its cull loop is dead code. `[TOD_BLOOD]` dev log.
(4) No stock round_end music cue. (5) Crate trigger: out 44 / lat 13 / lift 60 /
r 100, generated + proven at all yaws in gen_tower_map; trigger_radius_use does a
SIGHT TRACE to its origin and clip brushes block it - keep an origin above the
clip or in open air on the approach. (6) End stats: AetheriumScoreboard answers
stock's forceScoreboard, menu waits 10 s, "Victory" title on a win. (7) Staff
name: tod_pap_tier also pushed on weapon_change. (8) Bears: a melee lane (reach
120, cone, sight). Gate: tools/test_tester_fixes_0924.js. NOT fixed by the user's
call: down pistols per class, co-op restart/End Game, Zombie Blood screen tint,
WW count for mage, staff 3p pose, bat swing, A/D + wheel. ⚠️ C: DISK WAS 100%
FULL: -CleanPak's Undo COPIES the backup back and never deletes `_xpak_prev/*`
(27 folders, 24.6 GB, deleted at the user's OK). Check `df` before a publish.

**2026-09-24 - v19.54: LAP-DOOR RAIL-BAND FILLERS ARE PART OF THE DOOR NOW (the v19.51 jambs stayed on the railing after a door opened - user screenshot). PUBLISH BUILD NEVER FINISHED: its linker hung at 15:58 (C: at 100%), stopped 18:46 at the user's call and rolled back to the v19.53 .ff (44/44 files); superseded by v19.55. Re-run + re-stage the publish after the user tests.**
Two cap brushes per lap door inside the slab entity (door material, on the rail
tops, slide + hide with it); TOD_DOOR_SLIDE_DIST 188 (LOCKSTEP: door width 180 +
8). Never put a gap-filler for a MOVING door in the world: it outlives the door.
The v19.53 publish build below was NOT uploaded (assumed; Steam 429) and is
superseded: row #45 re-staged in place as v19.54. Check any door edit with
tmp/bridge_gift_20260924/door_zfight.js (baseline 353 on the lap doors, all hidden).

**2026-09-24 - v19.53 PUBLISH BUILD VERIFIED 15:32:10 Eastern, FF 147,491,200 B; -CleanPak + all twelve languages, payload 2,586,491,323 B / 48 files. AWAITING UPLOAD.** Carries v19.51 (Enfield irons, door jambs), v19.52 (Assault DR 9), v19.53 (bridge doors, Gift pickups). Ship state re-read in the deployed tree: every dev flag false, temp loggers 0, harness parked; diffs clean, nothing synced after. Notes `Update - Sep 24 (v19.53)`, 5 bullets, staged as ledger row #45; the v19.50 section in docs/68 + BBCode now carries the LIVE page text (32 merged bullets, user-pasted). **Owed: the upload, then `node tools/patch_notes.js uploaded`.** Peers: do not re-arm a flag or build over this tree until the upload is done. Evidence tmp/publish_v1953_20260924/.

**2026-09-24 - BRIDGE DOOR FLICKER + GIFT OF DEATH PICKUPS (v19.53). FULL BUILD OK 14:49:57 Eastern, FF 147,491,200 B; diffs clean, .map == repo, nothing synced after, banks 68,465,920 / 207,523,840, errorlog = the 10 waived, 0 bridge-door overlaps in the deployed .map, Gift fix deployed (only tod_pap flagged); dev flags OFF. UNPLAYED; the user tests. Evidence tmp/bridge_gift_20260924/.**
Bridge: the causeway gate and five lane seals shared faces with the treads /
glow strips / rails they sat in (z-fight, 33 overlaps found by
tmp/bridge_gift_20260924/door_zfight.js, 0 after); DOOR_PROUD 2 in gen_tower_map
grows each 2 units on every side but the top. Run that check after touching
any script door. Gift: stock counts the powerup gun as a drink for its whole
window; the perk bottle and Zombie Blood dropped the stock no-pickup-while-
drinking flag and use drinking_besides_powerup_gun() (_tod_powerups) instead;
the PaP drop stays blocked. Dev log `[TOD_POWERUP] GIFT_GRAB`.

**2026-09-24 - ASSAULT DMG REDUCTION CAP 7 -> 9 (v19.52; the first cut was 10, the user corrected it to 9 before playing). -GscOnly BUILD OK 12:28:18 Eastern, FF 147,392,768 B; diffs clean, nothing synced after, deployed script carries "assault", 9; banks 68,465,920 / 207,523,840; errorlog = the 10 waived; ledger proofs hold (109/109 weapon models, 0 ACOG rows, world irons linked); dev flags all OFF. UNPLAYED; the user tests. Evidence tmp/dr_assault9_20260924/ (the superseded cap-10 build: tmp/dr_assault_20260924/).**
User: "make Assault go to 10 damage reduction levels", then "it should go to
9 actually". One number in `set_class_max( "dr", ... )` (_tod_upgrades.gsc);
the ladder already ran to 10 for the heavy, so level 9 pays 28% (38% dark) and
the assault's e-HP is 208.3, one rung under the heavy's 214.3 (the heavy keeps
that rung plus VITALITY / RECOVERY as its edge). Caps: skirmisher 3 / mage 3 /
slasher 5 / assault 9 / heavy 10. The pause row
and the dark +10 follow domain_max automatically; hand mirrors updated in
tod_upgrade.lua (comments), docs/armory.html (classMax + prose + the v17.2
table), docs/91. Armory / arity / Lua gates green. UNPLAYED; the user tests.

**2026-09-23 - PACKED ENFIELD: NO SCOPE (irons on both forms). LAP-DOOR SLABS STOP AT THE RAILING; THE GATE'S JAMBS CLOSE THE RAIL BAND (v19.51). FULL BUILD OK 22:03:26 Eastern, FF 147,392,768 B (the 16.9 KB drop = the two ACOG models); scripts/zone_source/ui diffs clean, tools-root GDT + .map == repo, nothing synced after, own compile (d3dbsp 21:58:48) + bake (.led 45,150,282 B 22:01:16), banks 68,465,920 / 207,523,840, errorlog = the 10 waived; ledger: 0 ACOG rows, world irons linked, 109/109 weapon models, 0 missing techsetdef; deployed slide 168 + 99 jambs; dev flags all OFF. UNPLAYED; the user tests. (The first run was killed at its bake by the agent on a false timeout worry - build1_killed_at_bake.log; the second run is the one verified.)**
User played v19.50: the v19.25 SUSAT's aim point did not match the shots ("hard
to get headshots because you don't even know where the shot is going"), and the
v19.45 slab reach read as the door sunk into the railing ("should just go up
right against the railing"). ENFIELD: noOptic() in gen_tod_twins for the packed
form - optic slots cleared, all four ADS anims = the base's iron anims (the
port's `shotty_ads_fire` went with the red dot's up/down), hideTags '' like the
base, world irons attachment restored in slot 2; 12 forms x 13 fields, nothing
else moved; Krig 6 / AK-47 ACOGs STAY (the user named the Enfield). Gate:
test_no_optics.js strict list has the Enfield; OPTIC regex knows reddot/elbit/
susat/kobra/otero and excludes iron_sight (negative control failed on the old
GDT, passes on the new). DOORS: slab CORE..PX again; two `door gate jamb` boxes
per gate in the post's material sit ON the rail tops at the door line (landing
half b+56, tread half b+80) up to the lintel; lap 1 floor-to-lintel beside the
288 wall (99 jambs / 50 doors); TOD_DOOR_SLIDE_DIST 188 -> 168 (LOCKSTEP slab
width + 8). Read the DOORS block in gen_tower_map.js before touching a door.
THE SPIRE WAS NEVER WIDENED: its slabs stop at PX with no frame - verified
unchanged. v19.50 IS LIVE: uploaded 2026-09-23 20:53 Eastern (row #44 CLOSED on the
second `uploaded` fetch; the first was a 429). Everything from here is the
v19.51 window; the next notes must retract the Enfield half of the live ACOG
bullet and reword the door bullet (see CHANGELOG v19.51). Evidence: tmp/door_enfield_20260923/.

**2026-09-23 - DEV MAGE AUTOMATIC SPAWN RECOVERY (v19.49b). -GscOnly BUILD OK 20:24:02 Eastern, FF 147,409,600 B; 385 inputs unchanged/match deployed, trees clean, nothing synced after, banks 68,465,920 / 207,523,840, ten waived errors only; final asset gates passed. UNPLAYED; no game launched.**
User could not see the preview and does not use console commands. Their native
log PROVES AddTestClient ran, the Mage loadout was granted, then stock ZM
changed playing -> spectator before the old READY guard. Old code logged
READY and REMOVE in the SAME 37500 ms frame, with zero SHOW. New wait_ready
requires player_initialized plus 1.5 s continuously playing and returns ONLY
the marked native test client via stock zm::spectator_respawn_player (up to
three attempts / 30 s wait). Stock helper may install the usual respawn
callback if unset; does not replace an existing one. No fake sessionstate.
Dev alone now enables the preview; removed separate level.tod_dev_mage_dummy
toggle. No console setup. Recompute clear ground near host after settling;
six forms still auto-cycle every 12 s. [TOD_MAGE_DUMMY] INIT rev=2 automatic=1,
WAIT/RESPAWN/FAIL/STOP include actual session/initialization/respawn state.
Source test reproduces old READY+drop, passes recovery/timeout/cancel paths.
Captured log and failed first build in tmp/staff_dummy_spawn_20260923/;
first build rejected for five missing-output-file linker errors + peer source
change. Successful retry snapshot includes peer burn-number update. Docs/160. User retest
pending, no game launched; build waited until their BlackOps3 process exited.

**2026-09-23 - BURN DAMAGE NUMBERS ORANGE (v19.50). BUILT in a PEER's -GscOnly BUILD OK 20:24:02 Eastern, FF 147,409,600 B, linked from the shared tree after these edits (deployed scripts/ui/zone_source == repo, nothing synced after, compiled _tod_upgrade_ui.gsc.gdb 20:23:50 carries TOD_DMGNUM_BURN_KEY, deployed Lua carries DMG_COLOR_BURN, banks 68,465,920 / 207,523,840, errorlog = the 10 waived). My own two linker runs (20:20, 20:23) collided with that peer build and died (converter error, then exit 0xC0000409) - NOT content failures. UNPLAYED.** tod_dmg flag bit 3 =
burn (push_dmg_num optional 5th arg, own queue key); TRAILBLAZER + FIRE BLAST burn pushes set it;
Lua DMG_COLOR_BURN, burn > red > headshot. Log `[TOD_DMGNUM] BURN`.

**2026-09-23 - STAFF THIRD-PERSON REPAIR + DEV MAGE TEST PLAYER (v19.49). FULL BUILD OK 19:58:39 Eastern, FF 147,408,192 B; 385 inputs match, source/deploy trees clean, nothing synced after, banks 68,465,920 / 207,523,840, ten waived errors only. UNPLAYED; no game launched.**
Staff source + all eight twins: playerAnimType default -> bow, keeping the
existing LEFT-HAND mount (it is correct for the upright bow frame; do not
blindly change it to right). The stock bow GDT/model is the local oracle:
rocketlauncher + bow + tag_weapon_left, identity root and +Z long axis like
the staff shafts. Fire/lightning BASE world heads lacked their tag_tip
socket; now match the PaP heads. Ice keeps tag_barrel_attach. First-person
view tags/models/clips, combat and timing unchanged. This is a conservative
STOCK POSE FALLBACK, not the missing 29 Origins pt_ clips; the user's co-op
look must judge firing/reloading/movement and the hold itself. Bindings live
in tools/staff_presentation_bindings.py (refresh, then gen_tod_twins).
User ALSO requested another Mage in dev to inspect: new _tod_dev_mage.gsc
creates one native AddTestClient after draft/first deal, real Mage body,
stationary, invulnerable, cycles base lightning/fire/ice then packed every
12 s. Requires tod_dev AND tod_dev_mage_dummy (new flag ARMED for this test,
publish gate catches it). Console tod_mage_dummy_slot 1..6 pins, 0 cycles;
tod_mage_dummy 0 removes (restart to recreate). This consumes a real player
slot; native player-count rules apply. Excluded only from upgrade choices,
its swaps pause during deals. Bounded spawn, slot/ground checks and cleanup.
[TOD_MAGE_DUMMY] INIT/ADD/READY/SHOW/FAIL/REMOVE; existing [TOD_STAFF_PAP] adds
world_rev=1 cfg_pose=bow cfg_hand=left cfg_socket=... (CONFIG, not visual
readback). test_dev_mage.js executes lifecycle/form paths with native mocks,
gated in build; world assembly gate rejects nine negative controls. Docs/160,
CHANGELOG, evidence/backups tmp/staff_third_person_20260923/. All 78 approved
clips pass. Native dummy startup and visuals await USER test; do not launch.

**2026-09-23 - v19.50 PUBLISH BUILD VERIFIED 20:50:03 Eastern, FF 147,409,664 B; -CleanPak + all twelve languages (every language .ff stamped 20:45-20:50 from this tree), payload 2,587,261,691 B / 48 files. AWAITING UPLOAD.** Ship state re-read in the DEPLOYED tree: all nine `tod_dev*`/`tod_god` false, TOD_STAFF_RATE_LOG / TOD_SMASH_LOG / TOD_HOOP_LOG 0, TOD_MOCK_PARTY false, harness #8 parked; scripts/ui/zone_source diffs clean, nothing synced after the .ff; banks 68,465,920 / 207,523,840; errorlog = the 10 waived; ledger: 0 missing techsetdef, Double Tap clips, Lua rawfile, 111/111 weapon models linked. Notes: docs/68 + BBCode `Update - Sep 23 (v19.50)`, 32 bullets (rewritten short, 4,635 chars, orange burn numbers in), STAGED as ledger row #44 (cutoff = the peer's v19.49b dev-only entry). The window since #43 v19.22 (2026-09-16 22:50) = 46 entries + the file sweep, all accounted for. **Owed: the upload, then `node tools/patch_notes.js uploaded`.** Evidence tmp/publish_v1950_20260923/ (build.log, verify_publish.log). The user's Mage preview dummy (v19.49/b) is dev-only and off in this build. Peers: DO NOT re-arm a flag or build over this tree until the upload is done.

**2026-09-23 - SIGHT AUDIT: THE PACKED MP7'S MISSING IRON SIGHT IS THE PUBLISHED v19.22; THE v19.24 FIX HAS SAT UNPUBLISHED SINCE 09-21. NOTHING HAS SHIPPED SINCE v19.22 (ledger #43, 09-16 22:50).**
User, watching playthroughs of the live build. Whole-roster audit: 105 packed
forms over 22 guns paired with their base; the only differences are deliberate
optics with their models LINKED (ARs' 2x ACOG, Magnum Otero, MOG 12 reflex,
RK7 ELO), the akimbo Executioner pair (dualWield 1, no ADS by design), melee,
and the Bulldog's port-authored `vm_s1_bulldog_up`. test_no_optics.js now
pairs the WHOLE roster (rules 1-6 in its header); NEW post-link gate
verify_weapon_models_linked.js in build_map.ps1 (111/111 models linked at the
19:58 ledger; a ledger missing one reflex fails it). Pending notes bullet
reworded (docs/68 + BBCode). No content change; -GscOnly BUILD OK 20:05:22
Eastern, FF 147,408,192 B, both gates ran inside it (tmp/sight_audit_20260923/
build.log lines 919 + 1015). Dev flags still ARMED. ⚠️ EVERYTHING FROM v19.24 ON
IS UNPUBLISHED (sights, ACOGs, Double Tap, damage numbers, pips, doors, signs,
altar shader ...): when the user says "our recent update" they mean Sep 16.
CHANGELOG v19.48c.

**2026-09-23 - DOUBLE TAP: `GetAIArray( "axis" )` THROWS - THE ENEMY CHECK REJECTED EVERY SIGHTED ZOMBIE (v19.48b). -GscOnly BUILD OK 19:40:50 Eastern, FF 147,404,480 B; diffs clean, nothing synced after, banks 68,465,920 / 207,523,840, errorlog = the 10 waived, deployed module: 0 `GetAIArray(` calls + the team-list check, ledger proofs hold (tmp/doubletap_aim_20260923/build2.log, verify_build2.log). Dev flags still ARMED. UNPLAYED.**
Second playtest log (19:32): the v19.48 aim worked on all sixteen shots
(`stage=aimed candidates=1 dist=69..112 struck=actor_spawner_zm_tod_cyber_horde
fraction=1 victim=N`) and every one read `hit=0`, with two engine EXCEPTIONS per
shot: `parameter 2 does not exist` (GetAIArray( "axis" ) - stock only calls it
BARE) then `Object must be an array` (the foreach over its undefined return).
⚠️ BO3 REPORTS THESE AS EXCEPTIONS AND KEEPS THE THREAD RUNNING, so the SHOT
line printed and the function silently returned false; grep `SCRIPTERROR` in
every playtest log, not just `[TOD_*]` tags. `enemy_actor` now walks
`GetAITeamArray( level.zombie_team )` (the pick's own call, proven in the same
log); gate pins `GetAIArray(` out of the module. `_tod_thunder_smash.gsc:360`
(retired) carries the same call. Same log, NOT bugs: outro `CANCEL` at 2.3 s =
the round-5 perk shuffle (stop-before-move by contract); Fury `assert fail`s =
the Reaver's stock ASM under developer mode. docs/154, CHANGELOG v19.48b.

**2026-09-23 - DOUBLE TAP'S COWBOY AIMS (v19.48). -GscOnly BUILD OK 19:26:27 Eastern, FF 147,404,480 B; diffs clean, nothing synced after, banks 68,465,920 / 207,523,840, errorlog = the 10 waived, ledger proofs (clips, Lua rawfile, staff gmod6, 0 missing techsetdef) hold; gate + negative control (fan admits nobody -> gate fails, file restored same hash). Dev flags still ARMED. UNPLAYED (tmp/doubletap_aim_20260923/).**
The v19.45 volley PLAYED (user's log 19:09): sixteen shots on their frames,
fire clip 2.45 s, notes on BOTH lanes (`SELF_NOTE` x16 PROVES a Self Notify
also delivers `self notify( note, param )` on the script_model) - and `hits=0`:
every trace left the muzzle in ONE fixed level line (fractions 0.77 / 0.07 /
1.0). `volley_target()` now picks the nearest live zombie in the barrel's front
fan (70 deg either side, range 12,500, dz 200) with a clear WORLD-ONLY sight
line to its chest (from 32 u down the line, stock clip ignored, fraction >=
0.95; 3 candidates per shot, `SHOT_COVER` logs a skip); the level trace is only
the empty-room fallback. Damage call unchanged. Logs `INIT rev=4 lane=aimed`,
`SHOT ... stage=aimed candidates= dist= struck=actor|player|world hit= hp=`.
Same run: damage numbers (`FLUSH zombies=2..3 sent=2..3`) and Panzer pips
(`PIP cells=1 panzers=1 elites_ignored=1`) both logged working, no UI errors.
docs/154, CHANGELOG v19.48, gate test_perk_anims.js extended.

**2026-09-23 - RIOT SHIELD CARD COPY "MORE RIOT HEALTH, FASTER RECHARGE" (v19.46). FULL BUILD OK 18:24:49 Eastern, FF 147,403,456 B; four fresh content-hash .iwi at 18:24:40-41 beside an untouched DAMAGE control; deployed PNGs == repo; scripts/ui/zone_source diffs clean, nothing synced after; banks 68,465,920 / 207,523,840. UNPLAYED.** docs/159;
originals parked in docs/159_ref/_prev_shipped/.

**2026-09-23 - TOWER DOORS REACH THE GATE POST (v19.45). FULL BUILD OK 17:44:27 Eastern, FF 147,342,976 B (also carries v19.44b ADS pins + a peer's Double Tap work); banks 68,465,920 / 207,523,840; deployed .map/doors/weapon GDT == repo. UNPLAYED.** Lap-door slabs
were 20u short of the post (a see-through slot beside every closed door). `DOOR_REACH` in
gen_tower_map + `TOD_DOOR_SLIDE_DIST` 188 in _tod_doors (LOCKSTEP: slab width + 8).
SUPERSEDED BY v19.51 THE SAME NIGHT (user: "the door goes into the railing"): the slab is
CORE..PX again, the gate's JAMBS close the rail band, slide 168 - see the top block.

**2026-09-23 - POWER WAYFINDING REVIEW (v19.46, FULL build verified; unplayed).**
Inspected all 11 DOGCANARY decals. gen_tower_map replaces four repeated arrows
with a composed POWER + curved-turn entrance sign, one hall POWER word, POWER
directly above the switch, and STAIRS + rising arrow beside the real stair gate.
Six non-colliding meshes total, four original artworks; initial decal-only regen
left other map bytes and all generated GSC unchanged. Text UVs crop only fully
transparent top/bottom quarters, retaining original aspect. No material/glow
changes. FULL BUILD OK 17:51:33 Eastern, FF 147,342,720 B; 384 inputs match,
scripts/UI/zone trees clean, no source synced after the FF. All four materials
+ images linked; old straight arrow absent; no missing shaders. Sound banks
68,465,920 / 207,523,840; ten waived errors only. First build rejected for
unexpected language-link errors and concurrent source changes; fresh full retry
includes the newer door/HUD work. No launch; user tests. Docs/158,
evidence/backups and opened flat layout preview: tmp/power_decals_20260923/.

**2026-09-23 - ASSAULT HIP SPREAD -20% / ADS MOVE PINNED 2.0 ENFIELD, 1.5 KRIG + AK (v19.44b). BUILT in the v19.45 full build 17:44:27. UNPLAYED.**
gen_tod_twins `CLASS_HIP_SPREAD_MULT` (classHandlingSets) + `ADS_MOVE_PIN` (adsMovePin, user-set absolutes):
every assault PRIMARY form, base + PaP; cone min/max only (adds/decay are fractions).

**2026-09-23 - DAMAGE NUMBERS ONE PER ZOMBIE (v19.47) + PANZER PIPS (v19.46), FULL BUILD OK 18:06:37 Eastern, FF 147,343,040 B. UNPLAYED.**
User: "if you use the fire blast ... and you hit multiple zombies, all of that
adds up and it can say like 1 million ... I don't think I ever want to see the
damage numbers combine for multiple zombies". THE SUM EXISTED BECAUSE OF THE
CHANNEL: the todDmgNum clientuimodel field carries ONE value per server frame.
The numbers now ride the int-only scriptNotify lane (`LuiNotifyEvent(
&"tod_dmg", 2, amount, flags )`, every call delivered; the owned-upgrades sync
already bursts 8/frame = TOD_SYNC_BURST), one event per ZOMBIE hit in a frame:
pellets on one zombie still merge, two zombies never do; bursts of
TOD_DMGNUM_BURST 8/frame with carry, TOD_DMGNUM_PENDING 24 ceiling (a NEW
zombie's number is dropped + logged), amounts EXACT capped at 9,999,999.
`push_dmg_num( dmg, headshot, reduced, victim )` - all 11 callers pass `self`.
The todDmgNum clientfield STAYS REGISTERED in GSC+CSC (61-bit layout proven,
untouched) but is unwritten/unread; reclaim only with a lockstep CSC change.
Lua `CoD.TodDmgNum` subscribes to scriptNotify tod_dmg (pool/scatter unchanged).
GAUGE: `boss_cells()` = distinct cells holding a live PANZER (`tod_boss_kind ==
"panzer"` OR `is_mechz`; the Protector/Reaver carry `.is_boss` too and used to
wear the pip), highest first, max TOD_GAUGE_PIPS_MAX 4; new event `tod_pips`
(2 ints, two cells each hi*64+lo, LOCKSTEP Lua decode), 4-image pool GA_PIPS
replaces GaugeBoss. ⚠️ A LUA CLOSURE ABOVE A `local` BINDS A NIL GLOBAL: the
pip helpers are declared BELOW `local gaClimbed, gaMode`. Logs: `[TOD_GAUGE]
PIP cells= highest= panzers= elites_ignored=`, `[TOD_DMGNUM] FLUSH player=
zombies= sent= carried=` / `DROP`. Gates: test_gauge_boss_pip.js +
test_dmg_numbers.js (both in build_map.ps1), test_mage_damage regex updated,
lupa test_ui_lifetimes green. Build: diffs clean, nothing synced after, banks
68,465,920 / 207,523,840, errorlog = the 10 waived, ledger carries the Lua
rawfile + the Double Tap clips + staff/Widow's proofs
(tmp/gauge_dmgnum_20260923/). Carries the peers' door/sign geometry (their
own 17:44 build FAILED on unexpected linker errors; this full build compiled
the same tree clean). Dev flags still ARMED. Notes: docs/68 + BBCode, 50
bullets, NOT staged.

**2026-09-23 - DOUBLE TAP'S VOLLEY NEVER FIRED: A CLIP NOTE WAKES THE ANIMSCRIPTED DONE-NOTIFY (v19.45).**
User: the cowboy comes out and looks like he shoots, no bullets/sound/kills.
The user's console had it in two lines: `ANIM_START clip=tod_doubletap_fire`
and `ANIM_DONE` at the SAME ms, `VOLLEY shots=0`, while the intro/outro (no
script notes) ran their full 1.2 s / 5.1 s. A SCRIPT NOTE IN AN ANIMSCRIPTED
CLIP ARRIVES ON THE CLIP'S OWN DONE-NOTIFY (note as argument; stock's idiom is
`waittillmatch( done, "end" )` / `DoNoteTracks`), so the bare `waittill( done )`
returned on the frame-1 "Self Notify", the outro replaced the fire clip in the
same frame (never rendered a frame), and the listener died on `endon( done )`
before any shot notify could reach it. Sound/Play Fx notes do NOT wake it.
FIX (script only, GDT/clips untouched): `play()` finishes only on note "end"
(logs the rest as `NOTE`), watchdog endons `tod_perk_anim_clip_over`; the 16
traces are SCHEDULED from the AnimScripted call on the clip's authored frames
(`volley_frames()`, pinned to the importer's SHOTS + GDT notes by
verify_perk_machine_presentation.py and test_perk_anims.js), levelled at muzzle
height on the pistol's heading (xanim_bin: barrels pitch -6..+9 deg; machines
front on model +X and the pistols point +X within 7 deg), with one retry 32 u
down the barrel ignoring the stock clip if a trace starts inside a solid.
Log: `VOLLEY_START`, `SHOT n= muzzle= stage= hit= fraction= victim= hp=a->b`,
`SELF_NOTE` (probe only), `VOLLEY shots=16 hits=N`; `ANIM_DONE` for the fire
clip must now trail its `ANIM_START` by ~2.4 s. FULL BUILD OK 17:33:54 Eastern,
FF 147,342,656 B (carries the peers' unbuilt v19.44b assault ADS-move GDT:
tools-root tod_weapon_twins.gdt == repo), diffs clean, nothing synced after,
banks 68,465,920 / 207,523,840, errorlog = the 10 waived, 0 missing_techsetdef,
Widow's + staff proofs still hold (tmp/doubletap_volley_20260923/). UNPLAYED;
dev flags still ARMED. Notes: docs/68 + BBCode retitled `Update - Sep 23
(v19.45)`, 49 bullets (+ the peers' assault hip-spread / ADS-move bullet that
had no player note), NOT staged. Memory: animscripted-notes-wake-done-notify.

**2026-09-23 - NAIL GUN RED DOT OFF (v19.42, source only, FULL build owed).**
PaP form only had one; noOptic() all three edits; test_no_optics.js covers it.

**2026-09-23 - BALANCE (v19.41, source only, FULL build owed).** Ice staff -5%
(TOD_MAGE_ICE_NERF 0.646); Assault primaries +5% all tiers (CLASS_DAMAGE_MULT
1.155, sidearms pinned by CLASS_SEC_CAP_MULT.assault 1.10). 80 blocks regenerated.

**2026-09-23 - ORDINARY ZOMBIE LUCK WITHOUT SOULS (built; user retest pending).**
User confirmed the luck orbs are visible, then requested enemy orbs only for
elites/Panzers. _tod_luck::add now pays zombie/headshot sources immediately
with existing bonuses/cap; no orb or soul audio. Elite/Panzer bonuses still pay
on arrival; door/revive/duplicate pickup souls remain. Sprinter normal-kill
component is direct and its elite bonus has one orb. Dev INIT rev=4 and DIRECT
credit logs; source-executing regression + negative control and arity pass.
Initially held for the running game; included and source-verified in the
17:51:33 full build (tmp/power_decals_20260923/). No launch. Docs/155 and
source backups in tmp/luck_elites_only_20260923/.

**2026-09-23 - CLASS-DRAFT BLACK SCREEN (v19.40, source only, build owed).**
fog_off's SetVolFog passed a ZERO halfway height (stock setExpFog numbers copied
into the 8-arg SetVolFog). GPU-dependent black frame from the draft onward, host
only. Now TOD_FOG_OFF_HALFHEIGHT 1e6. Never pass 0 as a SetVolFog height.

**2026-09-23 - WIDOW'S WINE POWERED PANEL WAS A MISSING SHADER; PERK MACHINE AUDIT (v19.43).**
User screenshot: the powered Widow's Wine machine's front panel flat grey, no
sign/crest/red glow. THE LINKER DOES NOT FAIL ON A MISSING TECHSETDEF: the ledger
showed `material,mc/sat_zm_machine_y_mod_01_on` built on
`techset,mc/missing_techsetdef_geometry` (nothing in the errorlog). The pack
authored it on `lit_emissive_scroll_3layer_advanced_fullspec`, a techsetdef only
the SAT CODE archive ships; this install never had it. Only that material was
affected (the ledger's other `$default` users are the two waived stock assets).
FIX: the def (stock 3layer + fullspec additions, stock shader sources) lives in
the repo under `share/raw/techsetdefs_stable{,_toolsgfx}/geometry_advanced/`;
sync COPIES both (never mirrors); verify_perk_machine_presentation.py pins the
sha256 + both installed copies; build_map.ps1 has a POST-LINK GATE that fails any
`missing_techsetdef` ledger row (baseline ZERO - never waive, install the def).
No pack GDT/model/texture touched. FULL BUILD OK 16:39:39 Eastern, FF 147,290,560 B
(carries peers' v19.40-v19.42: nail gun optic, ice -5% / assault +5%, elite-only
souls, fog-off height), diffs clean, nothing synced after, banks 68,465,920 /
207,523,840, errorlog = the 10 waived, panel material on
`lit_emissive_scroll_3layer_advanced_fullspec#e6142445` with all 7 images, zero
`$default` on the powered model, staff `_zm` proof still 8/8. UNPLAYED; user tests.
⚠️ THE USER'S "most perks use stock machines" WAS NOT TRUE AND NOTHING WAS
CHANGED FOR IT: all nine sold machines wear pack models (t10_ BO6 rips x7, sat_
customs for Widow's/Wisp), the pack has NO `jup_` BO7 machines, and every machine
clip it ships for this roster (Speed Cola / Double Tap / Wisp Tea) is wired; the
BO6 Jugg/Speed/Revive/Stamin-Up/PhD are retro re-designs that read as "stock".
Read PERK_PARK + the ledger before believing a machine-model claim. Dev flags
still ARMED (tod_dev/tod_god/tod_dev_maxed/tod_dev_quiet). Notes: docs/68 +
BBCode `Update - Sep 23 (v19.43)`, 48 bullets incl. the peers' four, NOT staged.

**2026-09-23 - PACKED STAFF LOOK NEVER RENDERED; THE STAFF ASSETS TAKE THE _zm TAIL (v19.41).**
User: base and packed staffs "still look exactly the same". They always did: the
Sep 21 gmod6 presentation (docs/150) was declared done from build artifacts and
the user's console proved the engine hands back the BARE staff (`[TOD_STAFF_PAP]
... packed_attachment=0 ERROR missing gmod6 presentation`). ALL THREE documented
attachment requirements (docs/153) were met; the FOURTH is the asset NAME: the
linker's own `.deps` showed every `weaponfull,leviathan*_zm` pulling its gmod7
uniques from the mapping table and every `weaponfull,tod_staff_*` (the map's only
unsuffixed weapons) pulling nothing from the same table; stock connects gmod
uniques to `_mp`/`_zm`-named PROJECTILE weapons, so the GDF type is not it. The
linker keys the table on the mode tail. FIX: gen_tod_twins emits
`tod_staff_<el><suffix>_zm` (8 GDT headers + 8 zpkg lines moved, CSV/mapping
rows/scripts/Lua untouched, ledger 237); verify_staff_animations strips the tail.
⚠️ READ THE `.deps` FILE, NOT THE LEDGER'S PARENT STACK, TO KNOW WHAT A WEAPON
PULLED IN: the assetinfo csv attributes an explicitly zoned AU to the zone line
even when the weaponfull also pulled it. FULL BUILD OK 16:01:37 Eastern, FF
146,799,232 B, diffs clean, nothing synced after, banks 68,465,920 / 207,523,840,
errorlog = the 10 waived; `.deps` proves all 8 staff weaponfulls now pull gmod6 +
both uniques (tmp/staff_zm_20260923/verify_build.log). THE RUNTIME HALF (the
engine composing the packed head in hand) is UNPROVEN for every weapon in this map
(the hammer was connected the same way and never cast); the user tests. Dev flags
still ARMED (tod_dev/tod_god/tod_dev_maxed/tod_dev_quiet) - a test build.

**2026-09-23 - LUCK SOUL VISIBILITY RETEST (v19.40, built; native visual retest pending).**
User saw no luck orbs. Captured raw console via tools/capture_ai_logs.ps1 in
tmp/luck_visibility_20260923/. It proves 226 rewards queued, 195 released,
189 arrived; 45 increased the bar before cap, 144 arrived at 150. The first
headshot paid 0 -> 5.0625. Maxed cards do not suppress orb FX; they leave the
luck bar unspendable at 150, so later arrivals do not move the HUD. The effect
itself was unconfirmed visually. Registered `tod/fx_luck_soul` through
level._effect like the working rampage FX, replaced the literal PlayFXOnTag
argument, enlarged the two looping golden emitters (trail 20 u / 500 ms,
core 44 u / 320 ms), and added dev-mode FX_ATTACH + detailed SLOW logs. This
is a plausibility fix pending the user's native visual retest; do NOT claim
FX rendering is verified from logs. No game launch or input from agent. The
user's BlackOps3 process was running when work began; the build waited until
it exited. GscOnly build passed, FF 147,105,792 bytes (15:27:32 local);
384 inputs match deployment, luck FX + script are linked, and sound banks
verify. No agent launch. See docs/155. Evidence and backups:
tmp/luck_visibility_20260923/.

**2026-09-23 - THUNDER SMASH REMOVED (v19.39).** User pulled the slasher's new
upgrade from the map "for now". Domain commented out in _tod_upgrades, init +
#using commented in _tod_main; module/zone/assets kept for a restore (see the
add_domain note). Spire win banner now "70 FLOORS" (docs/157). Full dev build.

**2026-09-22 - PLAYER-EXPERIENCE AUDIT: EIGHT USER-PICKED FIXES (v19.38).**
Read-only 10-agent audit; 80 verified findings in tmp/pe_audit_20260922/
(the unfixed ones are a ready backlog - read findings_verified.json first).
Fixed: bat HUD "0 / 0" (TOD_NO_MAG), PACK II/III copy spelled "percent" (the
prompt typeface has no + or %), PERK SLOTS never dealt in the spire
(set_no_spire -> domain_available; pause row reads 9 there via
CoD.TodSpireMode), crate refuses tod_staff_ weapons (charged Mages 2,500 for a
no-op), Fury alias sheet zm_ai_apothicon_fury added to the .szc (the Reaver
was silent), Thunder Smash stamps tod_no_leech, Healing Aura recast resumes
its recharge. Spire win banner bakes "100 FLOORS": ART REQUESTED, docs/157 +
Downloads zip with the original to edit. -GscOnly BUILD OK 16:15:39 Eastern,
FF 147,105,856 B; diffs clean, nothing synced after; loaded bank 68.5 MB
(+Fury), streamed 207,523,840 B. UNPLAYED; user tests, no launch.

**2026-09-22 - BUG REVIEW FIXES BUILT (v19.37; user: "fix all of this if there is little to no
risk", "No regressions").** A whole-codebase scan (11 reviewers, batched skeptics;
memory `bug-review-2026-09-22`) found 18 confirmed + 6 plausible gameplay bugs;
22 are fixed in the smallest change each (CHANGELOG v19.37 lists all by id). NOT
fixed on purpose: the crown loiter exploit (the user's accepted design, finale
header ~170) and the owned-upgrades list after a restart (unproven, needs a HUD
event). Headline fixes: a solo QR crawler in the crown no longer gets GAME OVER at
the seal (`waiting_to_revive`); the King's landing waits out a card pause and
`tod_king_landing` + `tod_trial_active` make event_scheduler SKIP scheduled deals
inside sealed trials/the King's countdown; `run_upgrade_event` is serialised by
`level.tod_upg_event_live` (a queued caller waits on tod_upg_event_over, which now
fires a second time after the latch clears) and only a real deal is a station
takeover (`tod_upg_event_takeover`); PhD zeroes explosive damage only when
self-inflicted; PaP refuses the riot shield (`tod_pap_refuses`); the co-op altar
panel no longer casts Blink/Heal/Thunder Smash (`tod_solo_upg_active` read by the
watchers); todSteamWind uses set_to_player. Dev logs: `[TOD_FINALE]` seal/straggler,
`[TOD_KING]` landing/max-out catch-up (tod_dev gated). Scripts + Lua only. Every
node gate green; lupa Lua tests by hand. My -GscOnly .ff (16:11:29) was REPLACED by
a peer's v19.38 build at 16:15:39 Eastern, 147,105,856 B, linked from a deployed tree
that == the repo (scripts/zone_source/ui diffs clean, nothing synced after, streamed
bank 207,523,840 B) - so that .ff carries these fixes plus the peer's v19.38 work.
⚠️ THE DEPLOYED TREE STILL HAS tod_dev/tod_god/tod_dev_maxed/tod_dev_quiet = true
(the 2026-09-21 test-session arming in zm_tower_of_doom.gsc) - a TEST BUILD; not
changed here, disarm before any publish. UNPLAYED; USER tests, no launch.
SAME SESSION, LATER: crown altar stays OPEN during the finale's CHOICE phase (user:
"buyable even after the fight is over ... but it should still have a max limit") -
`station_use_loop` exempts `finale_choice_open()` from the pause deny; cap unchanged
(TOD_STATION_USES_CROWN 3). Player notes for the whole window are written in docs/68 +
the BBCode file as `Update - Sep 22 (v19.38)` (45 bullets), NOT staged - stage at
publish. -GscOnly BUILD OK 17:09:10 Eastern, FF 147,105,664 B, diffs clean, nothing
synced after, banks 68,465,920 / 207,523,840 B, errorlog = the 10 waived. UNPLAYED.

**2026-09-22 - ORIGINS LUCK SOUND TRIAL, APEX DING REMOVED (v19.34).**
User requested all pack sounds, removal of the Apex ding, and will playtest.
Explicit follow-up choice: include all eight, PLAY ONLY SOUL/COLLECTION cues.
Eight original WAVs from Fanatic's Origins Soul Boxes v1.0.0 are copied intact
to sound_assets/tod/luck, with private aliases + manifest/hash/build checks.
Release/travel are quieter spatial cues on the orb; arrival is recipient-local
after credit; collection-complete replaces pip 10 at 100 luck. Pips 1..9 and
the 150-luck zap remain. Box open/close/fire/disappear are included but inactive.
Both Apex playback paths, its function and bank alias are gone; elite red
marker stays. Travel explicitly stops before host deletion/hold/teardown;
resumes without repeating release. Burst intervals 200/150 ms; max 4 native
travel voices. Logs [TOD_LUCK_ORB] INIT rev=2 audio=origins_soul_box, AUDIO_START,
AUDIO_STOP, ARRIVE arrival_sound, BAR_AUDIO. See docs/155 and the full original
file backups in tmp/luck_audio_20260922/before for a targeted rollback.
Audio/order/cleanup tests pass, including two negative controls. GSC/audio
BUILD PASSED: FF 147,080,064 bytes written 15:12:42 Eastern. Geometry hash
matches the prior full bake. All 384 snapshotted inputs match deployment and
predate FF; complete scripts/UI/zone_source trees match. All eight sound rows
and their converted assets are present; Apex alias absent. Loaded bank
60,657,024 B; full streamed bank 207,523,840 B. Existing waived warnings only.
USER tests; no agent launch or desktop audio playback. Audio is unplayed.

**2026-09-22 - LUCK ARRIVES WITH A HOMING SOUL (v19.33).**
Every existing positive luck source now reserves its value and source position
in `_tod_luck_orbs`; only actual mover contact credits the bar. User explicitly
kept Panzer luck KILLER-ONLY (its points are a separate team reward). Full source
inventory and delivery contract: docs/155_luck_orbs.md. Tower doors use `tod_org`;
Spire doors currently grant no luck. Elite death paths cache position before
corpse deletion. Stock Origins gold soul trail/core adapted to two small native
loops in `tod/fx_luck_soul`, on non-solid tag_origin movers. No new clientfields
or weapons. Six movers per player, bounded queue retaining overflow value;
death/card menus hold delivery, disconnect/end-game clears it. Multipliers
are fixed at the source. Down penalties and card spending remain immediate.
[TOD_LUCK_ORB] INIT rev=1 + QUEUE/RELEASE/ARRIVE/HOLD/MERGE/RETRY/CANCEL logs
run under existing dev mode. Actual-function accounting/travel tests and FX
closure gate builds; four negative controls checked. Evidence/backups live in
tmp/luck_orbs_20260922/. FULL BUILD PASSED: FF written 14:47:53 Eastern,
147,077,696 bytes. All 375 snapshotted inputs match deployment and predate FF;
complete scripts/UI/zone_source trees match, new script and FX packed. Loaded
bank 59,140,608 B; streamed bank 207,523,840 B. Existing waived warnings only.
USER playtests; no agent launch. Native appearance/delivery remain unplayed.

**2026-09-22 - PERK MACHINE PURCHASE FIRING/AUDIO (v19.32).**
User expects original BO6-style machine behavior and explicitly requested
Double Tap damage. Four Tower-owned purchase clips now have paired native
sound/FX/local firing notes; 16 shots include the donor's missing first cue.
Fourteen original WAVs are banked; Wisp activation sound restored. Speed
power/idle audited. No weapon/clientfield registrations added: Double Tap
uses occluded barrel-directed traces with the donor's 10,000 raw damage,
buyer attribution, and a damage mark isolating it from held-weapon procs.
Original donor projectile trail and unavailable retail door/mouth smoke are
not reproduced. This is an explicit BO3 adaptation, not proven retail parity.
Power/move/retire/pause cleanup and a 15-second completion watchdog included.
Tests and asset closure now gate build; [TOD_PERK_ANIM] INIT rev=2 + phase,
shot, hit and cancellation logs support the user's test. See docs/154 and
tmp/perk_machine_fix_20260922/. FULL BUILD PASSED 11:09:30 Eastern,
FF 147,066,944 bytes; 373 source/deployed inputs match, none newer than FF;
4 clips + 3 FX packed, all 14 sounds in compiled alias/asset lists. Loaded
bank 59,140,608 B; streamed bank 207,523,840 B. USER tests; no launch.

**2026-09-22 - UNWANTED CAMERA MOVEMENT: HOOP CALIBRATION LOOP REMOVED.**
The user's dev playtest logged PROBE armed every=6 and repeated PROBE kills.
`_tod_corpse_cleanup::hoop_probe` forced the first player's view angles and
fabricated bat kills every six seconds, even while that player held a staff.
Removed the routine, its init call, constant and unused flag import entirely.
Dev diagnostics must observe play, never control aim or manufacture damage.
Passive bat/hoop logs remain; INIT rev=7 manual_hits_only=1 identifies the fix.
Existing bat build gate now rejects SetPlayerAngles/DoDamage in cleanup.
Evidence: tmp/unexpected_input_20260922/; docs/147. Script build passed
2026-09-22 10:27:58 Eastern, FF 147,130,240 bytes, full 207,523,840-byte bank.
All 297 deployed inputs match the PRE-BUILD snapshot with no later sync.
A peer changed _tod_mage_elements AFTER this FF: that newer Mage balance
source is NOT in this package; do not call the whole current tree deployed.
The camera fix is built; user retest pending. No agent input or game launch.

**2026-09-21 - THUNDER SMASH SECOND LIVE FIX (bound_hop_3).**
The user's next log STILL reports 26 missing_cast_asset / native_gmod7=0
on the bound_hop_2 build. The prefix fix was necessary but insufficient.
Hammer attachment presentation needs ALL THREE: full au_ base, weaponfull zone line,
and unsuffixed runtime-name row in the install-side attachmentmappingsTable.csv.
The shared KB's old attachment row is incomplete; see docs/153 and the Modme
recipe cited there. Never call standalone AU presence a connected weapon.
Generator now emits weaponfull for 13 hammers + 8 staffs; sync merges only
those names into the native table with an original backup, preserving peer rows.
verify_weapon_attachments.py gates declarations/merge and checks deployed rows.
Cast AND return equip wait a frame after take/give; cast retries are bounded.
HUD casts now have real progress, then the existing cooldown countdown.
No weapon definition, animation, balance or registration-count changes.
Evidence: tmp/thunder_smash_fix2_20260921/. Full build passed 20:42:03 Eastern,
FF 147,130,624 bytes. Peer staff-damage script rebuild at 20:50:33 includes this
fix: 297 source/deployed hashes match, complete 207,523,840-byte bank; all 13
hammer weaponfull dependencies include gmod7, both AUs and the moving cast clip.
Final deployment rechecked after the peer build exited. USER tests; no launch.
Staff projectile sections
read the table without listing AU dependencies: their presentation is unplayed,
not established by these hammer checks. Thunder Smash art was not found in
Downloads (newest ZIP is already-installed Rapid Flame); filename/path asked.

**2026-09-21 - THUNDER SMASH LIVE FIX (supersedes the initial build claim below).**
User: no animation / no HUD prompt. Captured log proves rank 3 was owned,
26 missing_cast_asset denials, repeated unprecached LUI event errors.
`attachmentUnique` MUST include `au_`: weapon base + `_gmod7` must equal the
actual AU asset name. Zoning the AU separately did NOT connect it. Fixed all
13 hammer forms and the same error in 3 staff sources / 8 generated forms.
LuiNotifyEvent requires eventstring precache AND an explicit payload count:
`&"tod_thunder_smash", 3, code, percent, seconds`. Old sender got both wrong.
New closure/count regression checks, native attachment query and HUD-receipt
logs; INIT revision bound_hop_2. Keep the peer's LoadFX -> path-string fix.
Docs/evidence: docs/153 and tmp/thunder_smash_fix_20260921/. Full fix build
VERIFIED 13:18:44 Eastern, FF 147,129,600 bytes; 297 matching inputs, none newer
than FF, complete 207,523,840-byte bank. All 21 native attachment bases resolve.
UNPLAYED after correction. User tests, no launch. Art 58 still pending.

**2026-09-21 - THUNDER SMASH (domain 58): tier-3 Stormbreaker LB upgrade.**
User chose card unlock, Hellbound baseline, Mage HUD layout and art request ZIP.
Three levels, cooldown 45/35/25 s. Bat lunge fitted to hammer grip; existing
weapon roots use gmod7 firstRaise (no registrations added; ledger 237).
Hellbound gold-sword hop, Gravity Spikes + Thor effects, raw marked damage.
Details/checks/diagnostics: docs/153_thunder_smash.md. Art request docs/152,
Downloads/tod_thunder_smash_art_pack.zip. Do NOT add CARD_SLUG[58] or the new
HUD image before returned art is zoned; SM glyph fallback. Pause ceiling stays
56 until both 57/58 plates exist. TOD_SMASH_LOG=1 for normal user playtest;
zero before publish. Full build verified 11:19:36 Eastern, FF 146,475,776 bytes; all 297 deployed
inputs match and predate the FF, complete 207,523,840-byte bank. gmod7 + both
AUs + clip/FX present in ledger. UNPLAYED; USER tests, never launch.

**2026-09-21 - v19.24: A SIGHT REMOVAL IS THREE EDITS, AND THE THIRD WAS MISSING
ON FOUR GUNS. FULL BUILD VERIFIED 10:14:36 Eastern, FF 146,217,856 B, bank 197.9 MB,
scripts/zone_source/ui diffs clean, nothing synced after the .ff. UNPLAYED - the user tests.**
User: "remove sights from all skirmisher and heavy primary guns base and pap ...
make sure we dont break the ADS. Sometimes that happens", then "replace the UDM
with the MW3 MP9. UDM has had few ADS issues".
⚠️ **THERE WERE NO OPTICS LEFT TO REMOVE** - all six primaries (MSMC/MP5/MP7,
Mk 48/HK21/Death Machine) were already clear in every one of their 63 forms.
**THE REPORT WAS THE ADS, AND THE CAUSE WAS THE REMOVALS THEMSELVES.** A port's
PaP form HIDES the iron sights because its optic replaced them; v18.94 and v19.10
cleared the optic model and re-pointed the ADS anims at the irons and NEVER TOUCHED
`hideTags`. So the packed MP7, Mk 48 and HK21 raised to an iron sight that was not
being drawn, and the packed MP5 wore an empty optic rail. **THE UDM IS THE SAME BUG**
(v16.12 painted its reflex `tod_clear` = invisible, and left `am_iw7_udm_reflex_ads_up`
as the packed ADS anim) - which is what "the UDM has ADS issues" was.
**THE RULE: THE PaP FORM'S SIGHT TAGS BECOME THE BASE FORM'S.** The base is the
proven-good state - its irons are drawn and the ADS anims the PaP now borrows were
authored against them. Non-sight tags stay as the PaP authored them (the HK21 keeps
hiding `tag_clip` for its extended mag). `noOptic()` takes hideTags as its third
argument now. The whole GDT diff was 13 hideTags lines + the UDM's 2 anim lines.
⚠️ **NO MP9 EXISTS IN THE TOOLSET** - 216 skye ports across t5/t6/t8/t9/s1/s2/s4 and
one iw7 (the UDM); zero MW3/MWII/MWIII, zero files named mp9 anywhere, and the BO6
Saluki pipeline is not a route to an MW3 gun. **USER'S CALL, ASKED AND ANSWERED:
keep the fixed UDM, no substitute.** If ever reopened, the only optic-free
near-analogues are the AW MP11 and the BO2 Uzi; Skorpion EVO / OTs 9 / Diamatti /
Switchblade X9 / KAP 45 all ship a reflex and would inherit the fault being escaped.
**`tools/test_no_optics.js` GATES EVERY BUILD** (65 forms, 33 PaP pairs): no optic
model or mount tag, no optic ADS anim, aimDownSight still on with both transitions,
and PaP sight tags + ADS zoom + overlay equal to the base form's. It compares against
the BASE FORM, never a hardcoded tag list, so a port rename moves both halves and
stays green while a one-sided change fails. 12 negative controls pass.
⚠️ **A CONTROL THAT EDITS BOTH SIDES OF A COMPARISON PROVES NOTHING** - the first
sed-based controls "passed" a broken GDT because the pattern hit the base form too,
and one injected a duplicate key that the real field shadows. Mutate ONE named block.
⚠️ **A PEER SESSION WAS LIVE IN THIS REPO THROUGHOUT** (v19.25 above). Two builds died
on it: one on their half-finished `d` axis before `lint_tod_weapons.js` knew the
letter, one when their sync (zone_source mirror=True) DELETED the linker's own
`zone_source/all/assetinfo` out from under the post-link checks. Neither was a content
failure. Wait for the peer's lint to clear and for their processes to be idle.

**2026-09-21 - v19.25: ASSAULT ARs GET A 2x ACOG, RAPID FLAME, DOUBLE TAP ON ICE,
DEADSHOT RETIRED. FULL BUILD OWED (GDT edit); v19.24 was a peer session's.**
⚠️ **BO3 HAS NO ADS-FOV FIELD AND THE 2x DOES NOT MAGNIFY - DO NOT GO LOOKING
AGAIN.** All 1,230 weapon assets in the tools' `source_data` were read: no
`adsZoomFov` on `bulletweapon.gdf` OR `attachment.gdf`, `dualRenderADS` 0
everywhere, and the ZRG 20mm sniper differs from an AR only in scope BLUR and
two depth-of-field focal lengths (`adsZoomInFrac`/`_OutFrac` are the TRANSITION
fractions). The user was told and chose the look. The three PaP ARs swap their
1x (Enfield Elbit / Krig Holoscout / AK Kobra) for a 2x on the gun's OWN
authored ACOG tag - `tag_acog_2` on both CW guns (same rail height as the optic
tag they used), `tag_susat` + the port's own BO1 glass on the Enfield.
**THE ADS ANIMS ARE UNCHANGED ON PURPOSE**: an ADS anim is authored against ONE
reticle HEIGHT, none of the three guns ships an ACOG anim, so the SCOPE is
nudged in Z to land its reticle where the old one was - AK +0.485, Krig -0.181,
Enfield -0.234, all measured off `xmodel_bin` geometry (`tag_reticle_attach`, or
the reticle/lens material centroid). X stays 0: that axis is the one the eye
looks down. If the AK's scope reads as FLOATING off the rail, zero its +0.485
first. `withOptic()` beside `noOptic()` in gen_tod_twins.js owns all of it;
`hideTags` is untouched (an optic is still there). Ledger-neutral, no zone line.
**RAPID FLAME (domain 57, `mage_rate`)** - the fire staff's rate card, 5 levels,
LINEAR on the cooldown: 1573/1415/1258/1101/943/786 ms, so Lv5 is DOUBLE the
shots and MULTIPLIES with FIRE BLAST (4.4x DPS both maxed - judge them
together). Pure script because fire is `Charge Shot`;
`_tod_mage_elements::fire_recovery_ms()` is the one owner. Band A, tier-min 2,
`set_no_dark` by decision. **ART PENDING: docs/151, zip already in Downloads. Do
NOT add `CARD_SLUG[57]` before the images are zoned (GATE A).** The r57 plate is
in the request because `PAUSE_PLATE_MAX` is a CONTIGUOUS ceiling.
**DOUBLE TAP -> THE ICE STAFF COST A WEAPON TWIN, AND THE GUARD IS NOW A BET.**
BO3 has no per-player fire-rate call (this map already knew: `set_no_dark(
"firerate" )` says so) and script can only make a gun SLOWER, so ice now carries
a SECOND variant letter that is a PERK: `axes: ['q','d']`, four assets, d1 =
fireTime 0.80 -> 0.60. `_tod_upgrades::axis_level()` is the ONLY translation and
is deliberately NOT in `get_level` (that reader feeds cards, pause, scoreboard -
a perk there would read as a phantom domain). `reconcile_twin`'s existing 1 s
tick does the swap both ways; `has_perk_paused` is read beside `HasPerk`.
✅ **LEDGER_GUARD 235 -> 237 (209 generated + 28 fixed). 237 IS NOW A PROVEN
BOOTING COUNT - the user loaded and played a 237-registration build on
2026-09-21, so the ice staff's Double Tap twin is paid for and the rollback
below is RETIRED. Do not drop the guard to 235 "to be safe".** (The warning it
replaces read: if the map stops loading, put the ice staff back to `axes: ['q']`
and drop the guard. That was the right caution at 0 evidence; it is now wrong.)
⚠️ **BUT THE GUARD IS AT ITS CEILING WITH ZERO HEADROOM** - the next weapon of
any kind needs LEDGER_GUARD raised, and the raised number is unproven again
until someone boots it. Map 1 shipped a booting 229; 368 was a boot-AV; nothing
between 237 and 368 has been measured. ⚠️ AND A SUCCESSFUL LINK PROVES NOTHING
HERE: the linker packs an over-budget table happily, exactly as it packed the
v19.27 `LoadFX` unresolved external. Only a boot decides. -25% is OUR number, not the engine's; the dev log
settles whether BO3 stacks one of its own.
**DEADSHOT (id 47) RETIRED WHOLE** (user: "not liked or helpful") - domain,
rarity lock, `_tod_deadshot.gsc|.csc` + their zone lines, card image, perk-bar
crest + its zone line, the Lua slug/one-image entries and the AetheriumPerks
row. It was GAMEPAD-ONLY (`UseAlternateAimParams`) so it did nothing on M+KB,
and it was ULTIMATE-locked so it displaced the rarest assault draw. **Id 47
stays mapped** (retired-id rule) and **`i_tod_pause_r47` STAYS ZONED** - the
plate ceiling is contiguous at 56, so unzoning it would cost rows 48..56 their
plates; the lint baseline's `why` now records that (deadPlates 10 -> 11, unnamed
209 -> 179). PNGs/GDT blocks stay on disk unzoned (the art is not git-tracked).
**FULL BUILD VERIFIED 10:28:46 Eastern, FF 146,217,856 B, sound bank 197.9 MB
(full - a peer linker truncates it to ~122 MB silently); scripts/ui/zone_source
diffs clean and nothing synced after the .ff, re-checked at 10:37 with a peer
session live in the same tree. Ledger: all four tod_staff_ice_q[01]d[01], all
four ACOG models, zero deadshot art.** ⚠️ The FIRST attempt died on 5 bare
`UNRECOVERABLE ERROR:` lines; a hand relink of the same tree emitted ZERO, and
the rebuild was clean - the documented converter flake, one rerun. ⚠️ **build_map.ps1 CANNOT SHOW YOU THOSE MESSAGES** - its filter keeps lines
containing `ERROR:` and the linker puts the body on the NEXT line, so all five
printed empty. Fail twice? Tee `bin/linker_modtools.exe -language english
-modsource zm_tower_of_doom` yourself before theorising.
⚠️ **THE HOLOSCOUT IS STILL IN THE .ff AND IS NOT A MISS**: the ledger packs it
under the STOCK `t9_krig6_up`, which zm_tower_of_doom.zone:91 zones directly as
one of the 28 fixed registrations. Only Krig 6 / MP5 / Mk 48 have stock forms
zoned that way and two of those are v19.22's optic removals, so it has been
shipping. No player holds it (variant_name always suffixes). Kobra and Enfield
red dot are fully gone; the surviving Kobra rows are the AK PaP's ADS anims.
Dev log `[TOD_STAFF_RATE]` runs on ITS OWN SWITCH `TOD_STAFF_RATE_LOG` (1),
NOT on tod_dev - ship state is dev OFF, so a tod_dev gate would print nothing
in the playtest it exists for (the TOD_HOOP_LOG lesson). ⚠️ ZERO IT BEFORE A
PUBLISH. Change-gated: `RAPID_FLAME lv= cooldown_ms=` and
`DTAP perk= want_suffix= held=`. **`held` vs `want` is the real check** - a twin
that did not link leaves `reconcile_twin`'s "never take the player's gun"
fallback holding the old staff, silently. Every build gate green; ⚠️
`test_mage_fixes_0910.js` fails PRE-EXISTING (its stub lacks `tut_dev_log`, added
to `abil_send` in v19.12) and is not a build gate. -GscOnly re-verified 10:41:01, FF 146,218,112 B, bank 197.9 MB, diffs clean,
nothing synced after (the switch above). BUILD AND STOP; user tests.

**2026-09-21 - STAFF PAP PRESENTATION / FIRST-EQUIP FLOURISH.**
User clarified inspect = first-equip flourish. Neutral gmod6 unique attachments
choose packed heads/firstRaise without adding weapon registrations. They support
the concurrent ice Double Tap work (eight current staff variants).
BO3 fire/lightning upgraded meshes/clips found in local exports. BO6 ice PaP is
its four open blades (not dreward); weapon curves adapted onto approved donor
hands because no BO6 hand rest skeleton was exported. Preserve per-staff PaP,
base clip hashes, cadence and Mystical Hands timing. New source/inventory/binary
checks and [TOD_STAFF_PAP] dev diagnostics. Details: docs/150_staff_pap_presentation.md.
Shared full build passed 2026-09-21 10:17:04 Eastern; final isolated link at
10:14:36, FF 146,217,856 bytes. All 27 staff assets linked, 293 source hashes
matched, usable 207,523,840-byte sound bank; no unexpected linker errors.
Another session began a later rebuild at 10:18; do not launch during that build.
UNPLAYED; USER tests, no game launch. Evidence: tmp/staff_pap_20260921/.

**2026-09-17 - KING CRASH ROLLBACK AND TEST SETUP REVERTED AT USER REQUEST.**
User considers the report potentially isolated and requests undoing this session's
Endless Spire crash changes. Exact pre-session copies restore King phases,
Rampage bonuses/sprint/berserk, summons, extended flames and Wisp Tea/Gift damage
exceptions. Dev/god/maxed OFF, normal round/class/spawn; summit harness parked.
Removed this session's extra King/test diagnostics with their changes. Existing
September 15 UI cleanup, King message batching and Panzer flame fix retained.
Armory restored. Source restored; first build REJECTED because BlackOps3 started mid-link (PID 46872). Clean sound-cache rebuild pending game closure; user tests, no launch. Evidence/backups:
tmp/king_revert_20260917/. This supersedes the removed September 17 test notes.

**2026-09-16 - MATTE ALTAR REJECTED; PREVIOUS MATERIAL RESTORED WITH SMALLER GLOSS CHANGE.**
User's 21:54 screenshot shows the all-matte pass flattened the exterior;
user wants less gloss, not disabled materials/reflections. NEVER restore the
zero-specular/black-specular/zero-probe pass below. Installer now restores the
entire 19:54 GDT exactly except glossRangeMax 8 -> 6. Replacing 6 with 8
reproduces that prior GDT's SHA-256 exactly (change_scope.json). Specular map
and enable restored; amount .2, tint .25, probe .15; other maps/glow unchanged.
Geometry and texture files are byte-identical; original interior remains
user-confirmed. Source gate requires enabled fullspec/material maps.
Full build passed 22:04:01 Eastern, FF 146,515,200 B; 165 inputs match, no
later sync/missing assets, original portal definitions match; all seven altar
LODs and 249 cyber binaries pass. Converter database settings also verified.
Evidence: tmp/heavenly_altar_satin_restore/. Current front preview refreshed.
User log preserved and game closed under existing authorization. BUILT AND
STOPPED, no launch. User visual retest of this small gloss adjustment pending.

**2026-09-16 - ALTAR EXTERIOR NOW MATTE; ORIGINAL INTERIOR USER-CONFIRMED.**
User: original picture is good; reduced gloss was still too much (21:07 shot).
Native frame now uses $black_specular, zero specular amount/tint, zero gloss
range and zero reflection-probe contribution. Retired specular atlas is no
longer a material dependency; geometry, image files, original interior and
cyber emission remain unchanged. Installer and source gate enforce this;
converted GDT database settings verified. Current native preview is front;
older side/LOD preview shading predates this last matte-only material change.
Full build passed 21:15:16 Eastern: FF 146,514,176 B; 165 inputs match, no
later sync/missing assets, original portal definitions match, all seven altar
LODs and 249 cyber binaries pass. Evidence: tmp/heavenly_altar_matte/.
Prior close authorization used; user console preserved. BUILT AND STOPPED;
no launch. Original picture is confirmed; latest matte finish awaits user test.

**2026-09-16 - ORIGINAL ALTAR INTERIOR RESTORED; CYBER FRAME LESS GLOSSY.**
User screenshots disproved the earlier material-slot-only fix below; do not
repeat that diagnosis as a confirmed cause. Native installer now copies the
original 32 background triangles exactly (positions, UVs, normals, winding,
black vertex colors and root weights) and references `chaos_pap_background`
with its unchanged three-layer animated material/images. All seven LODs
retain the original inset; verifier compares every corner against the donor.
New frame gloss 0..8, spec amount .2, tint .25, reflection probe .15; emission
unchanged. Art master remains the approved study; native derivative uses the
original interior as requested. Current preview: game_preview/native_front.png.
Full geometry/lighting/native build completed 19:51:41; a peer sync removed
its postcheck reports. Final peer package BUILD OK 19:54:01, 146,544,640 B.
165 source/deployed inputs verified, no later sync or missing used assets,
all 7 altar LODs and 249 cyber binaries pass. Shared pack's COMPLETE used
portal/image definitions match; unrelated retired exterior aliases differ
between maps. Evidence: tmp/heavenly_altar_original_inset/build_provenance.json.
User authorized closing BO3; console preserved. BUILT AND STOPPED, no launch.
Original-picture restoration and softened frame await user's in-game retest.

**2026-09-16 - ALTAR CENTER ARTWORK MATERIAL CORRECTED AND BUILT.**
User saw a gray front panel and see-through back. The inset is intentionally
single-sided; native winding, all six faces and image files were intact.
Portal material had artwork only in its emission slot and black in colorMap;
the native unlit technique reads colorMap. Installer now binds the same
artwork to BOTH slots. Only the altar GDT changed among deployed inputs;
geometry/textures preserved. verify_native gates both bindings; preview
native_portal_unlit.png exercises the base-image path in Blender only.
Full build passed 19:24:56 Eastern, FF 146,512,640 B; all 164 snapshot inputs
match, no later sync or missing assets, all seven altar LODs and 249 cyber
binaries pass compiled checks. Evidence: tmp/heavenly_altar_portal_fix/.
BUILT AND STOPPED. User must confirm the front picture in game; no launch.

**2026-09-16 - ALL SIX HEAVENLY ALTARS REPLACED AND BUILT.**
Shared station model is now `tod_heavenly_altar`: spawn, four breather lounges,
and crown. Prices, triggers, original collision and aura sound are preserved.
Editable master: `art/heavenly_altar/heavenly_altar_cyber.blend`; original copy
and native donor remain preserved. Author through the isolated real Blender
MCP session **9878** (9876 is Tower II sword; 9877 is zombie work).
User requested visible textures: RENDERED Eevee, scene lighting and glow.
Native assets: `model_export/tod_heavenly_altar/`, map-owned GDT, eight baked
textures, three materials, seven LODs (83,194 down to 15,421 triangles).
Full geometry/LED/native build completed; a peer sync interrupted its ledger
checks. Final peer packaging passed BUILD OK at 18:50:18 Eastern, FF
146,512,640 B. Independently verified all 164 snapshot/source/deployed inputs,
no later sync/missing assets, exact compiled triangle coverage at all seven
altar LODs and all 249 existing cyber binaries. Evidence and race provenance:
`tmp/heavenly_altar_integration/build_provenance.json`. Dev/god/doors OFF.
BUILT AND STOPPED; user tests. No game launch or native visual verification.
Exterior is modeled; heavenly figures/stairs use recessed reference artwork.
Rear extrapolates the front reference. Blender renders do not establish exact
native glow/lighting. Scripts/docs: `tools/heavenly_altar/`,
`art/heavenly_altar/README.md`, `validation.json`, `review.html`.

**2026-09-16 - REFERENCE TWO BACK MACHINE BUILT 2026-09-16T14:54:25.573552.**
Full build 149,684,992 B; all 431 inputs match, no later sync/missing assets,
all 249 compiled model files retain geometry. Ref2's back was rebuilt in live
Blender MCP: paired descending purple pipes on rear-view left, separate lower
flank return, copper induction chamber, right amber regulator, layered spinal
cassettes, open side rails and a substantial upper-cell carrier. Source master
`art/cyber_reference_two_mcp/reference_two.blend`; script `two_back_machine.py`
supersedes the original mirrored-loop back from `two_torso.py`/`two_support.py`.
Other master equipment/donor meshes preserved; ref1/ref3 assets unchanged.
Dev/god/doors OFF. BUILT AND STOPPED, UNPLAYED; the user tests. Gallery has an
exported back close-up; evidence `tmp/reference_two_back_machine_20260916/`, docs/149.

**2026-09-16 - REFERENCES TWO/THREE BUILT 2026-09-16T14:20:51.530766.**
User mapping: refs 1/2 REGULAR, ref 3 ARMORED ONLY. Both new models authored
through live Blender MCP 9877, original donors/weights preserved; gallery at
`art/cyber_zombie_roster/review.html`, masters `art/cyber_reference_two_mcp/`
and `art/cyber_reference_three_mcp/`. Trooper/Relay now use ref2; sprinter uses
ref3 twin tanks, welder visor, powered arm/hand.
Armored art correction: the pack has ONE purple pressure feed and a separate
metal lifting arch, short cyan sight chambers, heavy hazard-marked lower vessels,
and a central manifold/latch. Do not restore the earlier mirrored two-hose pack.
The final correction scripts and authoring order are recorded in docs/149.
Promotion replaces only known intact heads with the SAME head identity wearing
ref3; native gib flags, unknown
heads and repeated calls are guarded. Original head/hat attachments are removed
and both gib-data layouts updated. No gameplay stats changed. Full build passed:
FF 149,687,168 B; 431 inputs match, no later sync/missing assets, all 249
authored binaries pass source and compiled geometry coverage. Dev/god/doors OFF.
BUILT AND STOPPED, UNPLAYED; user tests. See docs/149 and
tmp/reference_23_integration/deployment_verification.json. Reference one's 65
binaries are unchanged. Older notes assigning ref3 to Relay/ref2 to sprinter
are superseded. Signal's existing ref1 head/helmet accents remain.

**THE USER TESTS. NEVER LAUNCH THE GAME UNASKED (user 2026-09-16, three
times in one hour: "I never asked you to test ... I will test myself" /
"You need to stop starting the game randomly" / "Stop starting and testing.
The flow is you write logs and ill test. Thats how we solve an issue").**
The flow for every bug and every feature: the agent writes the code AND the
logs, builds, and STOPS; the user plays; the agent reads the user's
`console_mp.log` (archive it with `tools/capture_ai_logs.ps1`) and acts on
it. "Make sure" / "verify" / "check it works" mean LOGS, not a launch.
`tools/run_game.ps1` is used ONLY when the user's message explicitly asks
for an agent-run match. Because the user's own launcher (`PLAY_NORMAL.bat`)
already passes `developer 1` + `scr_mod_enable_devblock 1`, a `/# PrintLn #/`
records in their runs; gate a feature's log on its own switch when the user
is testing a dev-OFF build and the log is what they asked for. This
supersedes the 2026-09-10 "build and start authorized test matches yourself"
paragraph below wherever the two disagree: that paragraph is the HOW, this
is the WHEN, and the WHEN is "when asked".

**2026-09-16 - v19.21c STING ON THE PROVEN LANE (`tod_perk_scatter::play_sound_at_origin`, the laugh's; stock `play_sound_at_pos` played nothing audible for a custom alias). -GscOnly BUILD VERIFIED 20:08:02 Eastern, FF 146,515,200 B, bank 197.9 MB, diffs clean, dev/god OFF. UNPLAYED. ⚠️ A PEER LINKER RUNNING MID-BUILD TRUNCATES OUR SOUND BANK (122 MB, no error) - accept a build only with the full bank size and no peer linker.** RULE: a custom 3D alias is played from a spawned `script_origin` `PlaySound` - never `PlaySoundAtPosition` - in this map.

**2026-09-16 - v19.21b STING LOUDER (wav loudnorm -11 LUFS, alias 100, DistMin 1200). -GscOnly BUILD VERIFIED 19:19:36 Eastern, FF 146,512,640 B, bank 197.9 MB, diffs clean, dev/god OFF. UNPLAYED.**

**2026-09-16 - v19.21 THE HOOP WORKS (user: "it looks like it's working now"). Feed says SCORE +20; the user's success sting `tod_hoop_score` plays 3D from the teleporter bay's pad centre `TOD_HOOP_SFX_ORG` (0,-950,60). -GscOnly BUILD VERIFIED 18:50 Eastern (3rd attempt), FF 146,512,640 B, banks 197.9 MB + 56.5 MB, diffs clean, dev/god OFF. UNPLAYED. ⚠️ Attempt 2 said BUILD OK with a 122 MB bank (75 MB of sounds missing after the checksum flake) - compare the `sound bank:` size with the last good build after ANY flake; the 50 MB floor does not catch it.** `TOD_HOOP_LOG` / `TOD_HOOP_C_LOG` are still 1 - zero them before a publish.

**2026-09-16 - v19.20c THE HOOP: THE DEATH-FRAME TRACE STARTED INSIDE THE BODY. -GscOnly BUILD VERIFIED 16:59:45 Eastern, FF 149,684,672 B, diffs clean, dev/god OFF. UNPLAYED - THE USER TESTS.** 39/39 server arcs died at t=0.08 with end == from: a BulletTrace from a just-ragdolled body's origin on its death frame returns fraction 0 (still solid, hitCharacters=false does not exclude it). `hoop_arc` now waits one frame and passes the body as `ignore`. THE RULE: a trace that ends where it started is a trace that began inside something - check `end == from` before blaming the arc.

**2026-09-16 - v19.20b THE HOOP, MEASURED: `TOD_HOOP_ARC_KH` 3.1 / `_KZ` 4.4 (from 29 paired flights, `tools/hoop_calibrate.py`), SLOP 24, NO FAN, 2D `tod_headshot_ding` cue. -GscOnly BUILD VERIFIED 16:41:43 Eastern, FF 149,684,928 B, diffs clean, dev/god OFF. UNPLAYED - THE USER TESTS.** The fan + slop 48 paid 16/29 ("every hit is a false positive"); per-axis K at slop 24 replays that log 5 true / 1 false / 0 missed. `"purchase"` is a stock alias this map never ships - it was silent. The test replays five real launches. Next log: run the calibrate tool; if K drifts, move KH/KZ, never the slop.

**2026-09-16 - v19.20 THE HOOP: LOWER (z 200..296), SLOP 48, A FAN OF ARCS PAYS. FULL BUILD VERIFIED 16:23:22 Eastern, FF 149,684,672 B, diffs clean, dev/god OFF. UNPLAYED - THE USER TESTS.**
The user's first real run: client log = 5 true baskets + many landings just
under the hole, server paid NONE (K 3.2 computed every arc short; the data says
~4.6). Now `hoop_arc` traces every K in 2.8..6.0 step 0.4 (one per frame,
`hoop_trace_arc` pure) and ANY basket pays on the swinger's thread
(`hoop_pay_after`) - the user's call: false positives over false negatives.
`tools/hoop_calibrate.py` reads a console log. ⚠️ THE USER'S LOG IS ONE LAUNCH
FROM GONE: archive `console_mp.log` the moment a run ends (the 16:12 Tower II
launch erased the v19.18d run). `TOD_HOOP_LOG`/`TOD_HOOP_C_LOG` still 1 - zero
before a publish. Workshop still = v19.17.

**2026-09-16 - v19.19b SMOOTH SOLIDS SECOND LOOK. FULL BUILD VERIFIED 15:52:27 Eastern, FF 149,684,992 B, fresh sky .iwi, diffs clean, dev/god OFF. UNPLAYED - THE USER TESTS.** Full-res crops (ffmpeg on the judging PNG - the 2048 previews hide it) showed dashed floor rings + a comb fringe at every round tower's foot: the paint row now uses the EXACT height (`EYE + tan(el) * tIn`) and each z-sample paints its NEAR-edge row only. Judge solids on 1:1 crops, never on the previews.

**2026-09-16 - v19.19 THE SKY'S SMOOTH SOLIDS. FULL BUILD VERIFIED 14:54:25 Eastern, FF 149,684,992 B, diffs clean, dev/god OFF. UNPLAYED - THE USER TESTS.**
Tower II's v0.7 profile-solid pass (its docs/63) is in `tools/gen_tod_sky.js`:
`drawSolid`/`addSolid` (sec(z) marched per column, analytic circle/rect,
fractional coverage, drawBox's shading). Masts are round tapers, every setback
a sloped band (`setback()`), the ziggurat faceted; NEW shapes: a fifth of the
lattice round (per-lot hash, off the rng stream), pyramid crowns, round
mega-drums, arcology domes, twin spires. `drawBox` untouched. ⚠️ A NaN `d`
scrambles the painter sort for the WHOLE city (seen: every near tower cut at
the mist line) - `addBox`/`addSolid` throw on it now. Bisect
`TOD_SKY_SKIP=round,crown,slope`. A sky change is a FULL build. Workshop
still = v19.17.

**2026-09-16 - v19.18d THE HOOP SCORES A COMPUTED ARC. -GscOnly BUILD VERIFIED 13:17:05 Eastern, FF 149,993,024 B, diffs clean, dev/god OFF deployed. UNPLAYED - THE USER TESTS.**
Two probes proved the server never sees a launched ragdoll (dead OR alive;
memory `dead-actor-ragdoll-is-client-only`), so v19.18c's pre-death lane is
RETIRED WHOLE and `_tod_corpse_cleanup::hoop_arc` scores the ballistic arc
of the impulse the server chose (`TOD_HOOP_ARC_K` 3.2 = A FIRST GUESS, g 800,
world-only BulletTrace per frame, slop 16). `_tod_hoop.csc` (actor clientfield
`tod_hoop_watch`, lockstep) logs the REAL flight on the client:
`[TOD_HOOP_C] SAMPLE/BASKET/FLIGHT` beside `[TOD_HOOP] ARC`; docs/147
§Calibration derives K from the user's log. Both loggers print WITHOUT dev
flags (`TOD_HOOP_LOG` / `TOD_HOOP_C_LOG`, TEMPORARY - zero before a publish).
Dev/god OFF. Workshop still = v19.17.

**2026-09-16 - v19.18 THE HOOP - FULL BUILD VERIFIED 11:16:55 Eastern, FF 149,954,496 B, diffs clean, nothing synced after. UNPLAYED. v19.17 was uploaded 10:49 (row #42 closed); this build replaced it in the deployed tree and is NOT published.**
A 96x96x64 recess in the core's SOUTH face at z 240..336 above the base
upgrade station, cyan rim + backboard; a bat-flung body whose spine enters it
pays the swinger 20 (`TOD_HOOP_PTS`, `_tod_corpse_cleanup::hoop_watch`, box
from GENERATED `base_hoop_lo/_hi`). Packed bat pays no extra rate: it already
throws x1.6, so it lands more often. ⚠️ HEIGHT IS UNMEASURED - `[TOD_HOOP]
FLIGHT apex/land/tag_moved` in a dev playtest decides `HOOP_Z1` (docs/147
recipe); `tag_moved=0` means the detection lane, not the height, is wrong.
Flung bodies keep their 2 s linger under corpse panic now. Geometry/bunker/
arity lints clean, `test_baseball_bat.js` HOOP section is the lockstep gate.
Dev/god OFF: arm `tod_dev` for the height-tuning playtest or the log is silent. Also open: GUNSLINGER reads additive (+30% of
BASE per level, diluted by DAMAGE - user's own v16.99 call); the user's
400->500 matches Lv1, not Lv3. USER'S CALL 2026-09-16: LEAVE IT AS IS - mechanic
AND card text unchanged; do not re-open. The numbers: AMP63 body shot on the
Panzer at DMG Lv4 reads 398 / 483 / 569 / 654 / 740 / 825 for GS Lv0..5.

**2026-09-16 - REFERENCE-ONE MODEL BUILT 12:46:04 Eastern.** Full build passed:
FF 149,992,000 bytes; 407 snapshot/source/deployed inputs match, no later sync
and no missing assets. All 233 authored cyber binaries pass source AND compiled
coverage, preserving the original legs. Crown/shared body now uses the Blender
MCP reference-one equipment, all fifteen finger joints and both shoulders,
five 4096-square baked maps, seven equipment LODs (44,610 down to 1,776 tris).
Distance reduction preserves each connected part; microscopic collapse slivers
are cleaned before conversion, without relaxing compiled coverage. Other roster
art is unchanged. Dev/god/doors OFF. BUILT AND STOPPED, UNPLAYED; user tests.
See docs/148 and tmp/reference_one_integration/deployment_verification.json.

**2026-09-16 - REFERENCE-ONE BLENDER MCP ART STUDY.** User wants model
updates through Blender MCP, as with Tower II's gold sword, and the live Blender
window visible so they can steer. `tools/cyber_reference_one/` uses the existing
upstream addon through an actual MCP ClientSession on its OWN port 9877; sword
session 9876 is unrelated. Master/gallery: `art/cyber_reference_one_mcp/`.
Focus is reference one only: detailed powered arm/hand, head hardware, harness,
reactor, pauldrons and leg brace on the original Crown body. This is an editable
high-detail ART MASTER; its reduced/baked game derivative is now integrated
as recorded above. The dense editable master itself is never shipped directly.
See that folder's README and validation report. Keep Blender open for the user.
Reference pass two adds emissive purple fluid lines, an outboard forearm cell,
and a shaped knee/shin assembly, now included in the native derivative.

**2026-09-16 - v19.17 PUBLISH BUILD VERIFIED. AWAITING UPLOAD.** The cyber
reference equipment pass is DONE and built (the "in progress / do not build a
mixture" warning that stood here is retired). PUBLISH BUILD VERIFIED 10:36:04
Eastern, FF 150,269,376 bytes, -CleanPak + all twelve languages; payload 2.177 GB
/ 48 files. scripts/ui/zone_source diffs clean, nothing synced after the .ff,
ship state re-read in the DEPLOYED tree (all eight tod_dev*/tod_god false,
TOD_MOCK_PARTY false, harness commented). All five cyber gates + compiled ledger,
geometry/bunker/navmesh lints and the notes gate pass. UNPLAYED.
⚠️ **THE JAPANESE PASS KILLED THE FIRST ATTEMPT AND IT WAS NOT A FLAKE.** The
linker DROPS a `japaneseUnsafe` xmodel while the zone still names it; nine cyber
models inherited that flag from their donors (`c_zom_der_zombie_body1` behind
trooper/relay, `c_t8_zmb_mob_zombie_body3` behind the sprinter). Stock's own data
is inconsistent - sibling `body2` behind crown/signal is unflagged, and every
severed-limb gib we derive is unflagged while the intact bodies were not - and
accepting the exclusion would have cost a Japanese client two of the four regular
appearance slots plus the sprinter. **User's call: our derived models ship
unflagged.** The override is emitted by `install_cyber_roster.py::block()` (donor
must have carried it, xmodel only, 1 -> 0) and `verify_cyber_roster.py` permits
that ONE non-cosmetic field. **THE GDT IS GENERATED AND SHA-GATED - change the
installer and re-run it, never hand-edit `source_data/tod_cyber_roster.gdt`.**
The re-run was proven side-effect free: 258 files hashed before/after, zero
binaries changed. Attempt 2 died on the KNOWN converter flake (`Missing source
checksum`, `carpet_run_06.wav`, a 2018 stock file) - rerun once, do not hunt it.
Both failures rolled back clean. Notes: docs/68 `Update - Sep 16 (v19.17)`, 12
bullets. **Owed: the upload, then `node tools/patch_notes.js uploaded`.**
⚠️ **THE LEDGER WAS TWO ROWS BEHIND AND ONE UPLOAD WAS NEVER RECORDED AT ALL** -
reconciled 2026-09-16 from the user's pasted live page: #40 (v19.10) sat pending
through its own Sep 15 2:03 am upload and shipped SIX bullets not the eight
staged, and the Sep 15 2:28 am bat-fling upload is now row #41. ASK FOR THE LIVE
PAGE BEFORE EVERY WINDOW.

**2026-09-16 - MAGE KEY OVERLAY: NATIVE CAUSE FOUND.** `Engine.Localize`
does NOT hand Lua a resolved bind. The native probe returned byte 21 +
`[{+frag}]` + byte 20; UIText expands it later. The previous first-character
renderer drew invisible byte 21. All earlier claims below about trimming
Localize's resolved key/controller picture are superseded for this HUD.
Keyboard uses the stock `GetKeyBindingLocalizedString(controller, command,
0, false, false)` API; controller keeps the whole token in UIText. Use stock
`LastInput_Gamepad` and refresh on `LastInput`, not the d-pad latch or token
byte guessing. This corrects the old no-device-branch guidance for this badge.
Positive usable charges gate the overlay; each ability retires at three real
casts. The existing five-second resend already handles HUD reconstruction.
See docs/145 for tests, screenshots and final build status.

**2026-09-15 - CYBER EQUIPMENT V3 BUILT.** User requested fitted
wrist equipment and more gear on every regular model/sprinter. Fixed oval
brace removed: straps sample each donor arm, smaller smooth plate uses a fitted
rubber liner, and the wrist joint stays clear. Added collar capacitors, spinal
power cells, relay reserve cylinders, sprinter cooling units and helmet rear
locators. Master/script: tools/expand_cyber_roster.py; docs/144. Export/install
all five atlas sets including MVP before building. Full build passed 23:08:19
Eastern: main FF 150,027,008 B / English 801,024 B. All 144 compiled LODs and
318 snapshot/source/deployed inputs match, no later sync. Evidence in
tmp/roster_equipment_v3/completion.json. Exporters use geometric face normals
when distance reduction cancels a cuff corner normal (keep strict checks).
Dev/god/doors/harness OFF. Built and stopped; user tests. Gallery reopened.

**2026-09-15 - CYBER EQUIPMENT FINISH V2 BUILT.** All five roster studies
and the shared MVP master now have outfit-matched worn coatings, fabric mounts,
service fittings and brighter eye cores. Both exporters now bake linked shader
channels instead of flat defaults; emission is normalized to native scaleRGB 6.
Trooper/Relay use matching arm gibs: 108 roster + 36 MVP = 144 binaries, still
25 atlas maps. Main FF 150,022,080 B at 22:32:44 Eastern; English 800,960 B.
All 144 compiled LODs and 318 snapshot/source/deployed inputs pass; no later
sync. New arm-gib checker corrected for inherited eight generated LODs. No
GSC/Lua/gameplay changes. Dev/god/open-door/harness stay OFF; build and stop.
See docs/144 and tmp/roster_finish_v2 for final verification status.

**2026-09-15 - FULL CYBER ROSTER BUILT.** User approved
integrating the offline regular zombies and armored sprinter. All four factory
slots now use custom appearances with three randomized heads, separate helmet
equipment and native damage variants. MVP models remain shared dependencies;
roster adds 106 binaries/20 textures. Sprinter body is `tod_cyber_sprinter`;
promotion retains current heads/helmets, with unchanged stats/no_gib behavior.
`verify_cyber_roster.py` gates source and native compiled geometry alongside
the MVP check. Full build passed 21:58:51 Eastern: main FF 149,784,704 bytes,
English FF 800,832 bytes; 316 snapshot/source/deployed inputs match, no later
sync. All 142 authored LODs retain expected compiled geometry. Sprinter's
materials/maps live in the English companion; inspect both asset ledgers.
Keep dev/god/open-door/harness OFF. Built and stopped; no launch. Native visual
retest remains with the user. See docs/144.
Peer HUD GSC-only build subsequently completed at 22:05:14 Eastern. Final
main FF 149,784,384 bytes / English 800,768 bytes; all 142 compiled LODs and
316 fresh snapshot/source/deployed inputs reverified, no later sync. Only the
peer's AetheriumLoadout.lua changed; all cyber inputs stayed identical.
Current evidence: tmp/roster_integration/final_verification.json.

**2026-09-15 - LATEST USER: DEV AND GOD OFF.** Disable dev, god, open-door
test flag and the direct King harness. Supersedes the King-test flags below.
Keep the flame fix. Normal-play rebuild VERIFIED 21:35:42 Eastern:
149,665,856-byte FF; all 147 snapshot/source/deployed inputs match, no later
sync. Build and flame regression checks passed. No automatic dev relaunch.
Attempted FX test exited before map verification; visual confirmation remains
pending. Evidence: tmp/flame_fx_20260915/normal_verification.json, docs/143.

**2026-09-15 - PANZER FLAME FX STATE FIX (verification in progress).** Stock
mechzDelayFlame starts damage without necessarily running our start_ft
notetrack; acc_panzer_ft now follows isShootingFlame through one change-gated
writer, a per-actor watcher and the stock damage callback. Teleporter bursts
and King's extended cone now delay emission after creating their FX host.
Do not claim client delivery from server emission logs. See docs/143.

**2026-09-15 - CYBER ZOMBIES ENABLED IN ALL MODES (source ready).** User approved
removing the dev-only appearance restriction. `ignore_spawner` now always keeps
the cyber factory and excludes its stock alternative; historical map markers
remain for BSP compatibility. Still one of four regular-horde appearances,
with stock gameplay/rig/dismemberment. Only diagnostics depend on `tod_dev`.
`tools/test_cyber_zombie_spawns.js` replaces the old dev-gate test and covers
all flag values, both factory orders, initialization and diagnostics separation.
Source/model checks pass. Build pending: BO3 started during this work; do not
interrupt the active King test or build while it runs. This supersedes the
older cyber dev-only direction below. See docs/141 for current build status.

**2026-09-15 - USER AUTHORIZED KING TEST LAUNCH.** Supersedes the earlier
build-and-stop instruction for this test. Dev and god remain true; `_tod_main`
now arms `dev_spire_harness(true)`: after class selection/first deal it ascends,
opens the spire doors, marks hub trials complete and warps to the summit.
The normal summit station starts the King, including its actual max-out/card
burst; dev_maxed stays false. `[TOD_KING_TEST]` records the warp. Harness is
ARMED for this user's playtest; disarm before publishing. Native launch
verified: summit warp logged god=1 and recorder reports king=1. User is
playing; do not build or take input. Archive: 20260915_212124_121_9e4f901b.
Concurrent post-build HUD edits briefly failed double-close in TodHealthTint;
peer removed the offending PlayerInfo walk. Normal lifetimes now pass but
duplicate Loadout cleanup invalidates the missing-helper negative control.
See tmp/king_test_20260915/peer_review.md before building those changes.
They are not in the running verified build.

**2026-09-15 - CRASH INVESTIGATION: UI CHILD OWNERSHIP.** Actual Lua 5.1
construct/close tests found missing cleanup despite the earlier callback scan:
default prompt leaves 154/155 elements unclosed; player/loadout/scoreboard
negative controls leave 49/129/74. TodPromptCard now closes its children;
perk item/list close their owned UI. TodUIOwnership closes remaining direct
children after existing feature cleanup; used by HUD and overlay owners.
Install it BEFORE feature close hooks. Health tint and party track cleanup
also repaired. Tests reject duplicate closes. These are simulated explicit-close
counts, NOT native pool readings or proof of any reported crash's cause.
King event-batching from the concurrent session preserved; its final list
refresh is still unbatched. BUILD VERIFIED 21:10:55 Eastern, FF 149,663,296
bytes; 147 snapshot/source/deployed inputs match, no later sync. No launch: existing build-and-stop
instruction remains. See docs/142_crash_ui_lifetimes.md.

**2026-09-15 - v19.13: THE BADGE NEEDS THE CARD AND A CHARGE.** Gated on
`everHad` AND `charges > 0` (recorded by `slot.setCount`; `slot.count` is the
glyph ROW, not the value). Readiness is NOT re-derived in Lua - `abil_send`
already clamps the heal count to 0 for the aura lock and blink sends
`blink_charges_now()`, so "count > 0" IS "the cast would succeed". This matters
because every Mage refusal is SILENT by design, so a badge on a spent ability
would be the player's only feedback and it would be a lie.

**2026-09-15 - v19.12 SUPERSEDES THE v19.11 OVERLAY BELOW.** The ability hint is
a BADGE ON EACH ABILITY TILE (top band y568..586; the charge count keeps the
bottom right), carrying the KEY ONLY - no verb, no ability name - set in the
MAP'S TYPEFACE via `todMakeGlyphRow`, centred by MEASURING first. The key is
`CoD.TodKeycap.Name( token )`, which trims the engine's multi-bind expansion
("G OR MIDDLE MOUSE" -> "G"). ⚠️ A CONTROLLER BIND EXPANDS TO A BUTTON PICTURE,
which a 42-glyph alphabet cannot draw, so a pad (or any unglyphable character,
`measure` -1) falls back to the engine's own font - that is the only renderer
for that icon and is correct on every pad layout. NO device branch; never read
`CoD.TodPad`. Retires per ability after `TOD_MAGE_TUT_USES` 3 real casts
(counted at the SPEND). ARCHMAGE has NO badge (no tile) and keeps the mana
bar's PRESS AIM BUTTON cue. QUICK REVIVE'S CARD IS STATIC AND STATES BOTH
PRICES ("SOLO $500 ..." / "CO-OP $1500 ..."), price row cleared for that perk
ALONE - a card that states both cannot be wrong about the party because it no
longer asks; the CHARGE is still per-party via `solo_qr_price_fix`. ⚠️
`test_perk_prompt_price.lua` had been comparing `nil` to strings since v19.3
(it modelled a `perkCost` member the refactor removed) - it models `todPrice`
now. -GscOnly build + native test PENDING.

**2026-09-15 - v19.11 MAGE CONTROLS OVERLAY + QUICK REVIVE CO-OP PRICE (Workshop
comments).** Bigfsi could not tell which button cast what: three UIText lines now
sit above the ability tiles (`AetheriumLoadout.lua`, x1000..1212 y520..566) naming
BLINK / HEALING AURA / ARCHMAGE by `[{+smoke}]` / `[{+frag}]` / `[{+speed_throw}]`
BIND TOKENS - the ENGINE renders the live device's key or button picture, so there is
NO pad/keyboard branch and none may be added. Each line shows only while its ability
is unlocked and retires after 3 real casts (`TOD_MAGE_TUT_USES`, LOCKSTEP Lua
`TUT_USES`; server counts at the SPEND in `_tod_mage_elements`, pushes
`tod_mage_tut`, dev log `[TOD_MAGE_TUT]`). Pause-menu ACT lines for 52/54/55 lead
with the same tokens; `AetheriumStartMenu` Localizes the act line for it - keep tokens
OUT of `eff` (the scoreboard prints eff unlocalized). The "third ability that says 1"
is the PACK-A-PUNCH tile; docs/38's MAGE bullet now says so (paste it with the next
upload). QUICK REVIVE charged 500 IN CO-OP: `solo_qr_price_fix` read
`GetPlayers().size` before the second client connected; it now waits for stock's
`all_players_connected` and reads `solo_game` - two prices, 500 / 1500, both asserted
(memory `party-size-settles-at-all-players-connected`, log `[TOD_QR_PRICE]`).
-GscOnly BUILD VERIFIED 2026-09-15 20:38:56 Eastern, FF 149,663,232 bytes; diffs
clean, nothing synced after. UNPLAYED. `tools/test_player_feedback.lua` fails at
`TodTeleportFeedback.lua:12` BEFORE this pass (not touched here) - pre-existing.
Warden King co-op crash (barn) still has NO cause; the fight has never been run
natively in co-op.

**2026-09-15 - CYBER ZOMBIE LEGS FIX.** User reported missing legs in game.
Cause: flat PyCoD load retained donor face object IDs but wrote a shorter object
table; BO3 dropped object 3 (all 6,520 leg triangles). Installer now preserves
stock mesh objects; per-object binary validation gates builds. Never validate
only a flat load/render: it hides invalid object references. Compiled xmodel
triangle coverage must also pass (`verify_cyber_zombie.py --compiled-ledger`).
Corrected 36 exports and native LOD coverage verified; full build passed at
20:30:00 Eastern (149,659,904-byte FF), 188 matching deployed inputs, no later
inputs. Compiled body includes all 6,520 leg triangles. User's native logs
confirm `[TOD_CYBER]` output; corrected visual retest pending. No launch.
Details: docs/141. Preserve dev-only selection and normal dismemberment.

**2026-09-15 - CYBER ZOMBIE MVP: DEV ONLY.** User explicitly limited the
custom appearance to `level.tod_dev`. The generator emits stock and cyber
factories; `install_spawn_filter()` runs immediately after dev flags resolve,
BEFORE `zm_usermap::main()`. Stock `_zm_spawner::init` consumes its
`level.ignore_spawner_func`, retaining exactly one factory: stock when dev is
false/unset, cyber when true. Do not gate only diagnostics or swap models late.
`tools/test_cyber_zombie_dev_gate.js` exercises the shipping predicate, both
factory orders and bootstrap timing on every build. `spawner_zm_tod_cyber_horde`
derives the factory zombie,
changing only character slot four to `c_tod_cyber_zombie`. Native meshes include
the optic/receiver, crown module and brace, with five baked atlases, seven LODs
and native head/limb variants. Preserve stock gameplay/rig/hitboxes and ordinary
dismemberment. Armored sprinter promotion restores only an intact cyber head.
`[TOD_CYBER]` diagnostics are dev-only; native output/animation/gibs/ragdolls
are not yet verified. Final full build passed 2026-09-15 19:42:50 Eastern:
149,766,592-byte FF; 188 matching deployed inputs, no newer inputs and all
cyber assets present, including all five maps. Shader is
`lit_emissive_advanced_fullspec` (the Plus shader ignored the specular map).
User still wants BUILD AND STOP, no game launch. See docs/141 for evidence
and shared-tools optimization drift during concurrent Tower II work.
Editable model/previews: `art/cyber_zombie_mvp/`; details and reproduction:
`docs/141_cyber_zombie_mvp.md`. `tools/verify_cyber_zombie.py` verifies exported
stock geometry/bones/weights/UVs and cosmetic-only asset overrides.

**2026-09-15 - USER TAKES OVER CROWN TESTING.** Latest explicit request:
"run on dev and god mode and open all doors." `tod_dev`, `tod_god`, and
`tod_dev_doors` are ARMED for this test, superseding earlier OFF instructions.
Other optional test flags remain false. User will perform the walkthrough;
Latest follow-up: "Stop relaunching ... Just build and stop." Build only;
do not launch the game. Disarm before publishing.

**2026-09-15 - CROWN STRUCTURE PASS.** Crown architecture now uses true convex
brushes: sloped octagonal band/bell, curved arches, faceted orbs/pearls, beveled
trim, flared point heads and interior arcades. `tools/convex_brush.js` decodes
the emitted planes for preview, area, hidden-face and static collision checks.
The earlier box-only restriction in this file/docs/34 is superseded. Keep
walking slabs and gameplay anchors stable; preserve the sky-height floor and
causeway clearance assertions. `tools/test_crown_convex.js` gates full builds.
See [docs/140_crown_structure.md](docs/140_crown_structure.md) for build/native
status. Test flags follow the latest user instruction above. No new gameplay harness.

**2026-09-15 - BAT FLING: ALL LETHAL SWINGS.** User reverted lunge-only.
No input polling, range guess or consumed stamp may gate corpse launching.
Keep random distance / packed bonus / rare long launch, and elite exclusions.
Diagnostics rev=3 all_swings=1; docs/138_baseball_bat.md has current status.

**2026-09-14 - MSMC / Mk 48 starters:** Skirmisher T1 is t6_msmc (f/h),
Heavy T1 is t6_mk48 (p). User explicitly wants new GDT fire rates with damage
adjusted to preserve old DPS. Follow-up also preserves old magazines/reserves:
MSMC 32/40 + 11 mags; Mk 48 60/75 + 6 mags. `tune.reserveMags` applies AFTER
reserve multipliers. Mk 48 reload now matches Stoner: 6.6 s base / 4.95 s PaP
via tune.reload = 6.6/8.0. Ammo/reload full build passed 2026-09-14 23:26:11 Eastern; native launch failed to start BO3 twice through Steam, so the latest ammo/reload
settings still need an in-game check. BO3 is not running. `dpsReference` keeps other tiers/sidearms stable.
Both keep normal/packed presentation and one tower PaP upgrade. Read
[docs/139_starter_weapons.md](docs/139_starter_weapons.md) for validation/status.

**2026-09-14 - Slasher baseball bat:** tier one replaces the knife with the
BOCW bat, preserving damage and adding bat-only lunge and lethal-hit ragdolls.
User approved native play. Impacts use bathitball.wav; two supplied Floraphonic
whiffs share one random native alias. Details/evidence: docs/138_baseball_bat.md.
**Keep tod_dev and tod_god OFF: user objected to cheats in the initial test.**

# Tower of Doom: Cybercity — session brief

**v19.8 (2026-09-14) — THE PROMPT CARD'S BANDS COME FROM THE ART, MEASURED.**
`i_tod_prompt_chassis.png` is 924x304 for the canvas rect 544..775 x 444..520 = **exactly 4 px per
canvas unit**, so every line in it has an exact canvas position and NONE of this layout is taste:
header **446.4..460.6**, cyan underline 460.6..462.1, body **462.1..500.6**, divider rule
500.6..501.1, footer **501.1..516.6**. ⚠️ **PLACE A ROW BY MEASURING THE ART, NOT BY NUDGING** — the
footer box was 499.35..508.75, i.e. its caps STARTED above the divider rule and stopped 8.4 short of
its section's floor, which is the user's *"doesn't fit in its section properly."*
⚠️ **A GLYPH ROW FITS TO ITS OWN BOX, SO TWO ROWS ON ONE LINE DRAW AT TWO SIZES** unless something
makes them agree: "TO ACTIVATE" clamped to cap 4.56 beside a "HOLD" at 7.52. `LayoutFooter` is the one
owner now — it MEASURES the verb first (via `TodGlyphText:measure`, which walks the GENERATED metrics,
never a copied 0.81-per-char constant) and pushes one cap into both rows. Key slot 30 -> 22
(the button picture draws ~13), `FOOT_HOLD_W` -> 24, and **the verb's right edge is conditional on
whether the card has a price** (723 with, 771 without) because the price shares that row.
`LayoutDetail` does the same for the description: a pair centred as a block, a SINGLE line centred
alone — which is every door and PaP, and was 25 units of void before.
**PROVE A CARD BY RENDERING IT:** `tmp/render_card.py` walks `TodGlyphRow.set`'s own arithmetic over
the generated metrics onto the real chassis; run against the OLD numbers it reproduces the user's
screenshots exactly, which is what makes it trustworthy for the new ones.
⚠️ **A SHRINKING `.ff` IS NOT AUTOMATICALLY A LOSS (2026-09-14): 178.6 -> 149.3 MB was the LOADED
SOUND BANK moving out of the `.ff` and beside it** (`zone/snd/all/*.sabl`, 56.6 MB, ~28 MB compressed
= the whole delta; the payload grew 33.8 MB in the same step and the console shows the game allocating
its 730 entries from there). Two clean builds gave byte-identical sizes, which is what said
"reproducible, not a bad link". Same session: a **Tower of Doom II** linker was caught running against
the shared tools root mid-build — `build_map.ps1` refuses with *"Two linkers on one usermap corrupt
the sound banks"*, and that is what triggered the sound-bank retry.

**v19.5/v19.6 (2026-09-14) — THE BLANK KEY, THE TYPE SIZE, THE COIN, THE LEFT HUD.**
⚠️ **THE FOOTER KEY IS ONE ELEMENT CARRYING `[{+activate}]`, AND MUST STAY THAT WAY.** v19.3 drew it
through `CoD.TodKeycap` and it rendered BLANK on every prompt in the map — `make()` was passed a nil
fallback so every failure path drew empty, and that widget also wants the cap ART behind it, which a
footer has no room for. The engine expands the token for the live device; there is no device branch to
add back (memory `bind-token-is-never-a-string`).
**TYPE SIZE IS THE BOX** (`cap = h * capFrac`, capFrac 0.80) — there is no font number anywhere else.
v19.5 took title 10 -> 14, detail rows 7 -> 11, dead band 22 -> 9; **v19.7 CUT THAT INCREASE TO 35% OF
ITSELF** on the user's *"cut the size increase we did on everything by 65%"*: every value is
`v19.3 + 0.35 * (v19.5 - v19.3)` — title **11.4**, detail **8.4**, footer **9.4**, price **10.4**,
`FOOT_HOLD_W` 32 -> **28.1**, left HUD 1.10 -> **1.035**. ⚠️ **THE FRACTIONS ARE LOAD-BEARING** — this is
the 1280x720 virtual canvas, and rounding 448.3 to 448 makes the cut 75% on that row, not 65%.
⚠️ **THE DEAD BAND WAS NOT INTERPOLATED BACK, ON PURPOSE**: *"a ton of empty space under the
description"* is a complaint that still stands, so the footer kept the v19.5 LIFT and took only the size
cut, with the 6.5 freed units split above and below it (band 9 -> 12.25, bottom margin 6 -> 9.25).
The FOOTER VERB is WIDTH-bound, not height-bound — 153 units for "HOLD <key> TO UPGRADE" plus a price —
so it is already clamped at cap ~4.7 and neither v19.5 nor v19.7 could move it; "HOLD" is the
height-bound half, which is why `FOOT_HOLD_W` tracks the rows.
**THE MONEY GLYPH SITS ON THE BASELINE NOW.** The letters set is cap 89 / baseline 103; the v19.2 coin
was ink 37..109 — 73 tall with its bottom SIX PIXELS BELOW the baseline, which is exactly "too small and
sitting low". Recut to bottom-on-103 at 75 tall (the cell is 80 wide, so a full 89 square would overflow
its neighbour). ⚠️ `slice_hud_sheets.js` READS `_images/` BY DEFAULT — the editable masters are in
`_sheets/` and need `--src source_data/tod_ui_images/_sheets`; it re-measures advances from the art, so
never hand-edit TodGlyphMetrics.lua.
**THE LEFT PLAYER HUD IS SCALED, NOT RE-AUTHORED** — `TodScaleAt( el, ax, ay, scale )` +
`TodScalePlayerHud`, anchor **(45, 678)** measured from the widgets' own boxes, factor **1.035 since
v19.7** (1.10 in v19.6), applied to ALL FOUR widgets (local row + 3 party rows) or they drift apart. ⚠️ NOT the scale v17.9 reverted: that
was 1.15 on the LOADOUT about a bottom-RIGHT anchor while its perks-row child is bottom-CENTRE. The left
HUD is single-anchor by construction. Overlap was answered by ARITHMETIC from the rows' own offsets —
content gaps portrait 7.0 / name 30.0 / health 32.0 / points 30.0, which a bottom-anchored scale SPREADS
to 7.7 / 33.0 / 35.2 / 33.0 at 1.10 and 7.2 / 31.1 / 33.1 / 31.1 at v19.7's 1.035 — the figure only gets
safer as the factor falls. Zero overlaps; cluster top 415 at 1.10, 431 at 1.035. The row BACKGROUNDS overlap by
design (87 tall on a 43 pitch) — the content does not.
**`TOD_MOCK_PARTY` IS ARMED** for the 4-player check; `-Publish` refuses to build while it is.
⚠️ **RENAMING A HINT ORPHANS ITS MULTIPLICITY ROW** — `lint_tod_hints.js` keys on the hint TEXT, so
"the Spire" -> "the Endless Spire" silently dropped that template out of the budget and failed the build.

**EVERY PROMPT CARD HAS ONE OWNER NOW: `ui/uieditor/widgets/HUD/ZM_CursorHint/Prompts/TodPromptCard.lua`
(v19.3, 2026-09-14).** User, mid-playtest: *"we should only have to do this in one area in the HUD, and it
applies to all prompts ... there shouldn't be situations where we see half work and half life."* It owns the
chassis, the icon well **and the icon table** (which was `local` to PromptDefault, so five cards could not
reach it), the typeface, every box, the footer and the price. All six cards + `TodTeleportFeedback` are thin
shells: `Build()` once, then `SetTitle / SetDetail / SetPrice / SetIcon / SetFooter`. **ADD TO THAT FILE,
never back into a card**; no prompt card may call `setTTF`, `LUI.UIText.new` or `setImage` for chassis art.
Zero `setTTF` remains on any reachable prompt surface — the one survivor carries a controller BUTTON PICTURE,
which is not typography and must match the player's hardware.
⚠️ **IT IS ZONED IN `zm_tower_of_doom.zone:454`, NOT the zpkg, ON PURPOSE** — `lint_tod_assets` cannot read
the zpkg and a `require` of an unzoned rawfile fails SILENTLY; the first cut of this refactor would have
blanked every door prompt with no gate complaining.
⚠️ **THE TYPEFACE HAS 42 GLYPHS AND DELETES THE REST WITHOUT SAYING SO** — `( ) , / : ;` all appear in the
live perk table and would have fused the words around them. `Sanitize()` runs inside every setter; write copy
that does not need marks we do not own. It also `string.upper`s everything, which is why converting a surface
fixes every capitalization complaint by construction (read `glyph-set-deletes-what-it-cannot-draw`).
**THE PRICE IS ONE GLYPH ROW (`"$2500"`), not an image plus a text box** — that pairing is what made the coin
read tiny and sit off the digits' baseline.
**ROUND 2 LANDED THE SAME NIGHT (v19.4):** rampage / crown / PaP / perk are on disk, zoned and LIVE in
`TodPromptCard.ICONS`; 21 prompt lines were traced through the table before the build, all 21 correct.
Two orderings are load-bearing there: `already packed` sits ABOVE `heavenly gift altar` (the OBJECT the
player stands at wins over the place the copy points to), and the three crown rows sit ABOVE the
extraction rows (the uplink cycles both through one trigger). **THE LESSON FROM BEFORE THEY LANDED
STANDS:** a live table behind a `false` flag FAILED `lint_tod_assets` GATE A, correctly — the gate reads
NAMES out of source and cannot evaluate a Lua flag, so never name an unshipped asset in live code.
**A 46-PROMPT AUDIT BACKS THIS** (CHANGELOG v19.3). Two results worth keeping: the riot shield pickup hint is
registered but **never placed on a trigger**, so that prompt never draws — a gameplay gap, not a UI one; and
`CoD.PromptPAP.SetMode` HAS a live caller (`ZMCursorHintNew.lua:372`) even though its re-pack branch is
unreachable (`USE_AAT_REPACK false`).

**QUICK REVIVE PRICE DISPLAY FIXED AND USER-CONFIRMED (2026-09-13, v18.99l).**
The custom `PromptPerks` ignored the machine hint's price and guessed solo/co-op
from `tod_party`; failed reads displayed 1500 even while the server charged 500.
`ZMCursorHintNew` now forwards the native hint and the widget reads `[Cost: N]`.
Do not restore an independent UI party/price guess or treat repeated server hint
stamps as proof of what the custom card shows. Purchase/power/life behavior is
unchanged. Built 22:47:17 Eastern; user: "it works". Lua tests cover co-op;
native co-op and `[TOD_PERK_PRICE]` developer-log output were not verified.
See docs/133_quick_revive_prompt_price.md. User took over native testing and
explicitly stopped agent game inputs; no further native operation is owed here.

**v18.99k (2026-09-13) — INDUCER: TRIGGER ALL ROUND, TELL IN THE SAME FRAME, TWICE THE SPARKS.** The
use-trigger is centred ON the device (r 96, lifted 40 above the 30.6 prop; `INDUCER_TRIG_OUT` gone).
**"Sometimes the on-indication doesn't work" was a POLL**: the visuals were applied by `spark_think`'s
2–4.5 s sleep loop; `tell_apply()` (idempotent, `level.tod_rampage_tell_on`) is the one owner now and the
use loop calls it in the flip's own frame. Two spark hosts (`TOD_RAMPAGE_SPARK_HOSTS`), crackle 1.0–2.25 s.
Contrast widened: idle scaleRGB 1.2/1.5/0.4 (fluid/crystal/glass), ON 16/22/6; floor light 120 / 1500.
**PLAYED AND APPROVED (user: "looks good").** The inducer is DONE; do not retune it unasked.

**v18.99j (2026-09-13) — THE INDUCER GLOWS FROM ITS OWN SKIN.** User: *"not like the perk glow ... make the
model actually orange and the orange glows."* v18.99i was black-and-grey because the port kept ONLY colour +
normal and threw away BO6's own glow sheets. `install_inducer_bo3.py` now binds the fluid's 512 emission
sheet (hue-nudged orange) and the crystals' crack mask (tinted orange, albedo hue-rotated violet→orange) on
`lit_emissive_plus`, and the glass on `lit_emissive_transparent` (alpha = opacity — BO6's glass is 98%
clear, so the crystals show through). Steel stays `lit_plus`. **`tod_inducer_on` is the SAME mesh with a
`skinOverride` to `_on` material twins** (hotter tint, scaleRGB 3/4/1 → 10/14/3); `glow_set()` swaps the
model. The FX is the dynamic LIGHT only — the sprite is gone. **When a BO6 prop looks dead in BO3, the
missing sheets are the first suspect, not the lighting.** tod_dev / tod_god DISARMED.

**v18.99i (2026-09-13) — THE INDUCER IS FLOOR-MOUNTED AND LIGHTS ITSELF.** No pedestal (the brush is gone,
`INDUCER_PLINTH_H` 0); it stands on the arena floor at (−280, −516, 0), as BO6 places it. TWO looping
effects from map 1's amber perk aura (`tools/gen_tod_inducer_fx.py`, zoned `fx,tod/fx_tod_inducer_*`):
`fx_tod_inducer_idle` is a **dim steady** orange lamp (light flat at 200) played from spawn, and
`fx_tod_inducer_on` is a **deeper orange pulsing 300→900→300 once a second** — the ON tell.
**THE PULSE LIVES IN THE EFFECT'S OWN LIGHT CURVE, NOT A SCRIPT TIMER**, because a server-played one-shot
renders nothing and only a looping FX does. `spawnOrgZ` 18 puts the light inside the glass cylinder.
`glow_set()` owns one host and re-makes it per change (no StopFX for a tag-played loop).
tod_dev / tod_god were armed for this test and DISARMED the same night (22:05 -GscOnly).

**v18.99h (2026-09-13) — THE REAL BO6 RAMPAGE INDUCER IS PORTED AND IN THE MAP.** It is
`t10_zm_essence_container_orange` + `t10_zm_essence_container_crystal_01..04`, joined into one single-bone
static prop (15.2 x 15.2 x 30.6 in, 7 materials, 18.8 MB of 1024-capped texture) by
`tools/bo6_extraction/stage_rampage_inducer.py` + `install_inducer_bo3.py`, zoned as `xmodel,tod_inducer`.
**ITS NAME CONTAINS NEITHER "RAMPAGE" NOR "INDUCER"** (0 of 272,642 loaded BO6 assets) — it was found with
`kind:model essence`, from the wikis' "Aetherium essence canister". **SEARCH BO6 PROPS BY FICTION.** Two
earlier models were wrong: v18.99e-g's `t10_zm_aether_canister` was a name match that measured out as a
plain hazmat drum, and before that map 1's `ww2_circuit_breaker` read as a power switch. ⚠️ **A MATERIAL
NAME OVER 63 CHARS IS TRUNCATED AND SILENTLY DEFAULT-SUBSTITUTED** — the glass material shipped 65 chars in
the first build and the linker drew a default face; one shared `short_key()` now caps every name at 32.
No lit twin: BO6 drives ON with FX, and so does this map.

**v18.99g (2026-09-13) — THE DEAD TRIGGER AND THE MIRROR DOOR.**
(1) **"Way too high to even trigger" WAS NOT A HEIGHT PROBLEM.** v18.99f cut a 72-tall plinth around a
trigger whose origin stayed at the device's x/y, so the origin sat INSIDE a solid and the trigger never
prompted — the map's FOURTH payment on `trigger-origin-under-decal`. The pedestal, device and trigger now
derive from one constant block in `gen_tower_map.js`, ride into GENERATED `_tod_breather_data.gsc` as
`base_inducer_org/_trig/_yaw/_trig_r`, and the generator THROWS if the trigger lands back inside the
plinth. Trigger 56 out in front (the crate grammar); pedestal 72 → 32, re-materialled to `MAT.pilaster`.
(2) **THE DOOR IS A MIRROR, NOT GLASS — AND THERE WAS ALSO A REAL HOLE.** Nothing in the vertigo pack is
transparent; all 30 materials are polished mirrors (white albedo + a 97%-white gloss map + NO normal map +
`reflectionProbeAmount 1`). Five matte clones `tod_door_<hue>` (`tools/gen_tod_door_materials.js`) are
wired through `doorMatOf()` — DOOR SLABS ONLY. Separately the arena cornice is emitted per wall run and the
south/east walls split around their doorways, leaving open 320x20 and 120x20 slots of SKY — closed by
`base doorway lintel S`/`_E`.
⚠️ **STILL OPEN, MAP-WIDE:** all 46 reflection probes ship Radiant's DEFAULT 72-unit parallax box inside a
1,120-unit arena; map 1's generator says outright "GROW the box to each zone's extent". That is what makes
reflections SMEAR. Fixing it changes the whole map's look and needs a bake — the user's call
(memory `vertigo-materials-are-mirrors`).

**RAMPAGE HAS NO ROUND SEAL (v19.0, user: "I want to remove the round 9 rampage lock. It will be
toggleable throughout the game").** `locked()`, `TOD_RAMPAGE_LOCK_ROUND`, `lock_watcher`,
`seal_banner`, the `tod_rampage_sealed` eventstring, the Lua widget and the baked plate are all
RETIRED WHOLE; hint strings 96 -> 94 (two permanent slots back). The device always flipped both
ways — only the refusal was removed. **The header's old justification for a late seal (the device
is behind the enter_tpbay door at 1,909-3,545) had ALREADY been false since v18.99f moved it onto
the open arena floor.** Toggling OFF reverts the live levers within ~2 s; spawn-time HP is not
retroactive either way; the Warden King latches at `king_setup` and does not change mid-fight.
`test_rampage_levers.js` pins the retirement (negative control run: 4/4 re-introductions caught)
and **both rampage tests now gate the build, which ran neither before.** -GscOnly BUILD VERIFIED 2026-09-13 23:11:50 Eastern, FF 178,598,848 bytes. scripts / ui / zone_source `diff -rq` clean, nothing synced after the `.ff`. THE SEAL IS GONE FROM THE DEPLOYED TREE: zero code hits for the constant / `locked()` / `lock_watcher` / `seal_banner` / `tod_rampage_sealed` in the deployed GSC (the only two matches are this pass's own comment lines recording the retirement), zero for `TodRampageSealed` in the deployed Lua, zero for `i_tod_banner_rampage_sealed` in the deployed zone. The in-build hint lint reports **94 distinct strings of 190 budgeted** (was 96). Both rampage tests ran IN THE BUILD for the first time and passed, alongside the riot-shield, elite-pause and mage gates; ten known-waived asset warnings only. UNPLAYED.

**ICE CADENCE IS 0.8 s (v18.99d, user's call: "Move the ice staff to 0.9s per shot then" -> "0.8s actually"). It was 1.1111. THIS IS A ~39% DPS BUFF, not only a feel change — cadence IS the rate — and the post-shot weapon-switch pause is THE SAME NUMBER, so it fell 1.11 -> 0.8 with it. Every ice matchup constant (`TOD_MAGE_ICE_VS_BEAST` 2.85, `_ICE_OFF` 0.80, `_ICE_NERF` 0.68) was calibrated against the OLD cadence; if ice reads too strong now, move a matchup constant, NOT the cadence the user set.**

**⚠️ THE STEAM PAGE RENDERS YOUR OWN TIMEZONE, NOT PACIFIC (2026-09-13) — WHEN YOU READ IT IN
THE BROWSER. `patch_notes.js`'s `STEAM_TO_LOCAL_HOURS` was 3, went to 0, and is 3 AGAIN since
2026-09-16 FOR THE TOOL'S OWN ANONYMOUS FETCH ONLY (Valve's default = Pacific; the fetch read 07:49
for an upload of the 10:36 .ff). A PASTED time is Eastern and goes in through `--at` untouched.** The user read "Sep 13 @ 1:59pm" off the Workshop page; the +3
made that 16:59 Eastern, which had not happened yet (it was 15:25) — **a reconstructed upload time in the
FUTURE is the tell.** That error made the 13:59 upload look like it came AFTER three later builds, so this
session recorded a nonexistent "notes drifted from the binary" failure and netted two ice bullets out of
the published section for a reason that did not apply. The user corrected it: *"No they arent. I published
and then we made the changes. Did you check timezone"*. Rows 34-37 were all three hours late and are fixed;
the giveaway in every one is a 3-hour build->upload gap where 10-26 minutes is the norm.

**UPLOAD #37 = v18.98, 2026-09-13 13:59 Eastern, `.ff` 13:45:51.** Notes and binary MATCH. Everything built
after it is UNPUBLISHED and is the pending v19.0 row #38: the power decals, ice cadence 0.8, the two
lightning-staff ammo fixes and the riot-shield card. **AND v19.0 TAKES SOMETHING BACK IN WRITING:** the
published notes promised "No more delay switching weapons after an ice staff shot", which was TRUE of
v18.98 (ice `fireTime` 0.1) and is no longer true — v18.99c restored the native fireTime, so the swap waits
0.8 s. The v19.0 ice bullet says so in the same breath as the rate fix rather than reverting it quietly.

**PUBLISH CANDIDATE v18.99 (2026-09-13; CHANGELOG v18.99c is the SHIPPING entry, v18.98/v18.99/v18.99b are
its earlier passes). FOUR PASSES IN ONE CANDIDATE:** (1) ship state + the notes reconcile, below; (2) the BO6
ice-staff TEXTURE CAP (2048 -> 1024, gloss/AO 512 — `i_tod_bo6` 102.7 -> 21.7 MB, clean pack 1.29 GB;
`downscale_pack_textures.js --restore` on that GDT undoes it, and the REPO copy had to be capped too because
`sync_to_modtools` mirrors `model_export/tod_bo6_ice` every build); (3) THE POWER DECALS — six
`arrow_power_coldwar*` chalk-meshes from map 1's DOGCANARY pack, already in the SHARED tools root, **NO zone
line** (a brush/mesh face material rides in through the BSP), authored by map 1's winding rule (+y normal ->
columns Xmax->Xmin, u0 = viewer-left, so the LEFT arrow points EAST); (4) TWO REGRESSION FIXES — ice
`fireTime` back to native **1.1111** (a script `DisableWeaponFire` cooldown gates a `Charge Shot` press but
NOT a `Single Shot` one, so v18.94 left the staff firing at click speed; **THE SWITCH PAUSE RETURNS WITH THE
TIMING** — one field owns both, and the untried native split is `shotsBeforeRechamber` + `rechamberTime`),
and a RIOT SHIELD card now **ENDS** a recharge instead of only shortening it (the v17.10 fix covered the
holding-a-shield case only, which is why it "sometimes" worked). **Owed: the user's test, the upload, then
`node tools/patch_notes.js uploaded`.**

**v18.98 (the ship-state pass):** ship state — `tod_dev` / `tod_god` /
`tod_dev_mage_test` / `tod_dev_maxed` → false (the same-day staff-test arming), money / doors / altar already
off, harness #8 parked. Ledger row #36 (v18.85) was PENDING through its own upload AGAIN (Sep 11 7:41 pm
Pacific = 22:41 Eastern, closed from the user's pasted page — rows 34, 35, 36: three in a row; ASK FOR THE
LIVE PAGE BEFORE EVERY WINDOW). Notes `Update — Sep 13 (v18.98)`, 12 bullets over a 15-entry window
(v18.86 → v18.97: sky ×5 folded, ice staff ×6 folded, SCAVENGER old → final, red dot, the fun pass).
Carries v18.96g unbuilt-until-now (spin 4320, song −5.6 LUFS). Licence flag on "Falling To Pieces" stands
(CREDITS.md) — the user's call. PUBLISH BUILD VERIFIED 2026-09-13 13:45:51 Eastern, FF 176,242,624 bytes; `-CleanPak` + all twelve languages (every language `.ff` from this tree; the first attempt at 13:28 died at the Spanish link on a transient `Missing source checksum` for `wpn_t9_amp63_trig_pull4.wav` and the script restored; the rerun linked all twelve clean). Deployed `tod_dev*` / `tod_god` all false, harness #8 parked (both re-read in the DEPLOYED tree); scripts / zone_source / ui `diff -rq` clean, nothing synced after the `.ff` (only the linker's own traditionalchinese assetinfo outputs are newer); deployed `tod_music_ee.wav` sha = repo's; fresh content-hash `i_tod_bo6_ice_*.iwi` at 13:40 (1.29 MB for a 1024 colour map). Notes gate `check` OK; ledger row #37 stamped with the `.ff`. Gates: notes, installer `--check`, staff validation, assets lint, hints lint — green. UNPLAYED: v18.96f/g bears + the capped ice staff in hand are the user's to judge before upload. Size pass: BO6 ice textures capped 2048 → 1024 (gloss/AO 512) — pack 1.29 GB, `i_tod_bo6` 102.7 → 21.7 MB; payload 2.21 GB / 48 files. Four orphan staff `fx,` zone lines retired. **Owed: the upload, then `node tools/patch_notes.js uploaded`.**

**v18.97 — THE WHITE GLARE WAS THE IMAGE (user), docs/104 §4k:** lit edges were 200x the sky base
and the engine's bloom haloed them white — THE PREVIEW PNGS CANNOT SHOW THIS (display-referred). A
peak knee (`--knee 0.45`, max 0.62, hue kept) + `GLOW` 0.05; gain PINNED 0.01661 / `--target-score`
default 0.324 because the peaks WERE 28% of the sky-light mean — the tower's ambient is ~28% lower ON
PURPOSE; `--target-score 0.45` restores it (brighter base). FULL BUILD VERIFIED 2026-09-13 13:22:48 Eastern, FF 176,397,120 bytes; new content-hash sky `.iwi` 22,945,492 bytes at 13:21:55; deployed EXR sha256 = repo's (b2f53b12…), zero unexpected linker errors, zone_source/ui diffs clean, nothing synced after the `.ff`. ONE scripts diff: a PEER session disarmed every dev flag in `zm_tower_of_doom.gsc` at 13:21:49 (after this build's sync) for a v18.98 PUBLISH — so THIS `.ff` still carries tod_dev/tod_god/tod_dev_mage_test/tod_dev_maxed ARMED and is a test build; the peer's publish build will carry this sky (the repo EXR is this one). UNPLAYED — glare is judged IN GAME only.

**THE FUN PASS, v18.96 (2026-09-13, CHANGELOG v18.96):** four player-experience features, all
script + zone + one wav. (1) **THE WARDEN KING HAS PHASES** — at 66%/33% health he reels (stun +
`slow_elite` x0.45 2.5 s), the deck shakes, then sprint (phase 2, summons 15 s) and rage (phase 3 =
`king_rage_on()`: berserk on every summons, 13 s). The rampage levers are now HEALTH-owned;
rampage keeps them on from the landing. ONE sprint thread (`tod_king_sprint_on`), ONE berserk
call site. (2) **THE TEDDY BEAR SONG HUNT** (`_tod_secret.gsc`) — three stock `p7_zm_teddybear`
(base power hall / floor-10 window sill / floor-20 hoop top), shoot-detected; the laugh
`zmb_laugh_child` 3D at the bear; all three = "Falling To Pieces" (`tod_music_ee`, -8.0 LUFS,
279.3 s) and **NO MUSIC CAN OVERTAKE IT** — `channel_play` PARKS every other request while it
holds and replays the newest after. Once per match. Licence of the track = the user's call
(map 1's credits flagged commercial songs DO NOT PUBLISH). (3) **ELITE KILL CONFIRM**
(`_tod_killconfirm.gsc`) — red `hud_damagefeedback` snap + `tod_headshot_ding` for the KILLER on
elite deaths only (bigger on a Panzer), hooked on `tod_luck::boss_kill`; `ding()` is the one owner
of that alias. (4) **ELITE PERK BOTTLES** — `elite_bottle_roll` 10% (`TOD_ELITE_BOTTLE_PCT`) of the
map's `tod_free_pap` bottle at every elite corpse, tower + power only. Dev logs `[TOD_KING]`
`[TOD_SECRET]` `[TOD_ELITE_DROP]` `[TOD_KILLCONFIRM]`. -GscOnly BUILD VERIFIED 2026-09-13 11:57:19 Eastern, FF 176,397,056 bytes; `p7_zm_teddybear` in the assetinfo ledger, streamed bank regenerated 11:57:03 (+31.6 MB = the one new wav), deployed wav sha256 = repo's, alias row deployed; scripts/zone_source/ui diffs clean, nothing synced after the `.ff`; only the established waived linker errors. Tests: test_king_rampage.js (extended) + test_v1896_secret_killconfirm_bottle.js PASS; arity/hints/assets/sound-context lints green. NATIVE RUN 11:59 (agent-launched, PID 38544): map loaded; GAME LEFT RUNNING for the user's own test. Dev flags at launch = the peer's ice-staff set (tod_dev/tod_god/tod_dev_maxed/tod_dev_mage_test TRUE, doors/money FALSE) — unchanged by this pass. FIRST USER TEST: kill confirm fired on every elite class incl. the Panzer; bears sat INSIDE their surfaces (THE PIVOT IS THE BEAR'S CENTRE, z -14.2..13.9 — decoded from the xmodel_bin; `TOD_SECRET_LIFT` 16), the hull was unshootable with the projectile staffs (now a VIEW RAY on weapon_fired, `TOD_SECRET_RAY_R` 40), the laugh was silent (`zmb_laugh_child` is in a Kortifex CSV the map never loads — now `tod_secret_laugh`, an INTERIM Kortifex laughter wav until a Samantha wav is supplied), and the user asked for 3 s of silence before the song (`TOD_MUSIC_EE_GAP`). v18.96b BUILD: -GscOnly BUILD VERIFIED 2026-09-13 12:13:16 Eastern, FF 176,397,056 bytes; loaded bank regenerated 12:13:01 (+455 KB = the laugh wav), laugh wav + alias row deployed = repo; scripts/zone_source/ui diffs clean, nothing synced after the .ff; tests + lints green. **v18.96c:** the user's Samantha laugh (13.85 s) banked as `tod_secret_laugh.wav`; the bear RISES, HOVERS and FLIES AWAY as a scripted mover paced to it (`bear_fly_away`); the third bear kills the music at the hit, leaves under silence, sting at departure, 3 s quiet, song. -GscOnly BUILD VERIFIED 2026-09-13 12:21:20 Eastern, FF 176,397,184 bytes; loaded bank 12:21:05 (57,093,376 = +668 KB, the 13.85 s laugh), laugh wav deployed = repo; scripts/zone_source/ui diffs clean, nothing synced after the .ff; tests + lints green. **v18.96d:** laugh cut at 8.30 s (before the "bye bye"), flight re-paced 1.5/5.0/1.6 s; -GscOnly BUILD VERIFIED 2026-09-13 (see CHANGELOG v18.96d), diffs clean. **v18.96e/f:** base bear out of the east wall; all three PIXEL-PERFECT (lift 14.2 = mesh min z, 6 off a wall's inner face, front taken as local −Y — flip yaws 180 if they face the wall); the exit = one accelerating RotateYaw(2160, 8.1, 8.1) over a 6.5 s rise then the launch. -GscOnly BUILD VERIFIED 2026-09-13 (CHANGELOG v18.96f), diffs clean. **v18.96g:** `TOD_SECRET_SPIN_DEG` 2160 → 4320 (~3 turns/s at the launch); the song re-rendered `volume=-0.4dB` + limiter → −5.6 LUFS (+2.4 dB net; the limiter holds the rest, alias stays 95). FIRST BUILT INSIDE THE v18.98 PUBLISH BUILD (see the top block). The user's retest of v18.96f/g is pending.

**v18.96 — A TINY BIT DARKER (user), docs/104 §4j:** night sky levels ~18% down + `--target-score`
default 0.478 → 0.45 (the world light is 6% lower BY REQUEST — do not "restore" 0.478 without asking);
solved gain 0.01661, sky base ~20% darker, neon held within 3%. FULL BUILD VERIFIED 2026-09-13 11:55:21 Eastern, FF 176,395,520 bytes; new content-hash sky `.iwi` `i_skybox_tod_cybercity_*.iwi` 23,520,909 bytes at 11:54:13; deployed EXR sha256 = repo's (ab3609b7…), zero unexpected linker errors, gain solved 0.01661. CAVEAT: a PEER session edited seven `_tod_*.gsc` + the zone at 11:52:08 (mid-build, after this build's sync — NOT in this `.ff`) and started its own build at 11:56:18, which will replace the `.ff` with a tree that carries both its scripts and this sky (the deployed EXR is already this one). Verify THAT build before playing. Dev flags tod_dev / tod_god / tod_dev_mage_test are ARMED (the ice-staff session's). UNPLAYED.

**THE RAIL FIT PASS, v18.95 (2026-09-13, docs/104 §4i; user: "doesn't look like it fits in
well"):** the rail lines now use the CITY'S grammar — the deck is a dark gridded face with lit
rails as edges (writes depth), a truss under it (`RAIL_GIRDER`/`RAIL_BRACE_U`: posts, zigzag
braces, lit chord), gridded pylons meeting the chord, dark-glass trains with cool windows in
the line's hue + neon car ends + a lit underframe, stations with a dark platform and canopy
slab. Judge on `night_ingame_city.png` / `night_view_crosstown.png`. FULL BUILD VERIFIED 2026-09-13 05:12:29 Eastern, FF 176,395,520 bytes; new content-hash sky `.iwi` `i_skybox_tod_cybercity_AS6NUOKRQLJBDPCISLQEYL5A5K.iwi` 23,742,617 bytes at 05:11:29; repo vs deployed `diff -rq` clean for scripts / zone_source / ui, nothing synced after the `.ff`, deployed EXR sha256 = repo's (d7308755…), zero unexpected linker errors, gain solved 0.01701. Dev flags tod_dev / tod_god / tod_dev_mage_test are ARMED (the ice-staff session's test build, not this pass). UNPLAYED — native look pending.

**THE RAIL PASS, v18.88 (2026-09-13, docs/104 §4h):** the three rail lines (two rings +
a new gold CROSSTOWN across the mid city) carry TRAINS (lit cars, headlight, tail lights,
glow trail), STATIONS (platform, canopy, lit strip, glyph board, lamps), pylon heads and
lights, and a far-rim smog fade. Trains/stations sit on each line's NEAR rim — scattered
placement put them on the hazed far rim behind the towers and every aimed preview was
empty though the debug count said they drew. Aimed previews `night_view_train_*` /
`night_view_station_*` come from the real positions. FULL BUILD VERIFIED 2026-09-13 03:11:24 Eastern, FF 176,396,544 bytes; new content-hash sky `.iwi` `i_skybox_tod_cybercity_GI56P4L6MP37EY4SBYRJXVQEQ6.iwi` 23,744,757 bytes at 03:10:37; repo vs deployed `diff -rq` clean for scripts / zone_source / ui, nothing synced after the `.ff`, deployed EXR sha256 = repo's (c141648c…), zero unexpected linker errors, gain solved 0.01709. Dev flags all false, harness #8 parked. UNPLAYED — native look pending.

**THE SKY, v18.87 (2026-09-13, docs/104 §4g):** Tower II's sky quality pass is
in `tools/gen_tod_sky.js` — painted at 16384x8192 (`--ss 2`), Lanczos-2 resolve,
Catmull-Rom noise, three clamped unsharp passes tuned on the simulated IN-GAME view
(`docs/sky_preview/night_ingame_*.png`, 1080p at cg_fov 65, 0.96 texel/px — JUDGE
SHARPNESS THERE, never on the 2048 equirect), EXR written directly as half floats
(Node 24), `SKY_GAIN` SOLVED for `--target-score 0.478` (landed 0.0176; the picture is
brighter, the world's light is held). Plus the ATMOSPHERE PASS: ground mist + two haze
strata in front of every surface (`veil()`), moon shafts, a storm cell with one bolt,
two airships, an orbital tether + station, far-ring mega-billboards, deeper zenith.
**PER-LOT RNG SEEDING** — a composition lane change re-rolls only the lots inside it
(before, every lane edit moved the skyline under some OTHER planet). **THE SKY IS
RETIRED FROM THE SIZE PASS** (`optimize_tod_assets.py --retire sky`; the 2026-09-10 pass
had halved it to 4096 and its `--verify` gate would have failed the re-rendered EXR;
~+25 MB). Full render ~4.5 min. **16384x8192 IS REFUSED BY THE CONVERTER ("unsupported size", proven the same night: build FAILED, no sky in the .ff until an 8192 re-render) — 8192x4096 is the ceiling and `--width 16384` throws; at 1080p the 8192 sky is already 1 texel/px.** FULL BUILD VERIFIED 2026-09-13 02:16:27 Eastern (the 01:30:17 build re-done after the failed 16k experiment; the 8192 EXR re-rendered sha256-identical, 67081f65…), FF 176,396,544 bytes; new content-hash sky `.iwi` `i_skybox_tod_cybercity_P3KH7OEB3PWESTEZDISBMCDDT3.iwi` 23,775,050 bytes at 01:29:29 (the 2026-09-10 halved one was 3,614,719), xpak rewritten in the `.ff`'s second (1,394,835,456 bytes, append-only — a publish's `-CleanPak` re-measures it); repo vs deployed `diff -rq` clean for scripts / zone_source / ui, nothing synced after the `.ff`, deployed EXR sha256 = repo's; size-pass gate VERIFIED 260 (sky retired). Dev flags all false, harness #8 parked (unchanged). UNPLAYED — native look pending.

**THE BO6 ICE STAFF IS BOUND (v18.89, 2026-09-13; docs/bo6_ports/ICE_STAFF_MIGRATION.md
§"The binding"):** the ice staff's PRESENTATION is the BO6 assembly — models
`tod_bo6_ice_vm`/`_wm` (51,060 verts, 77 bones incl. the appended glow socket
`tag_bo6_glow`), six `mtl_tod_bo6_ice_*` materials (colour + decoded NOG + four
emission maps on `lit_emissive_plus`, `scaleRGB 6` = the first tuning knob), 14 BO6
sounds through 25 `wpn_tod_bo6_ice_*` alias rows (fire ×5 + tails, raise, putaway,
first raise, reload — the ice reload/first raise are ONE 2D-Sound note each now).
`tools/bo6_extraction/install_ice_staff_bo3.py` does all of it idempotently and
`verify_staff_animations.py` runs its `--check` on every build. **Tower II's process,
followed exactly: BO6 mesh on the DONOR's held motion, aligned by MEASURED anchors** —
the view maps 1:1 (BO6's IK locators sit 0.29 in from the fitted clips' wrists, no
shift), the world mesh is shifted +11.67 and rotated X→Z onto the donor world staff's
+Z axis (the Origins world model runs along Z, `tag_tip` frame X→Z; muzzle within 2.1
in). **NOT BO6, by finding not by laziness:** the 116 BO6 clips carry no skeleton and
the BO6 arm rest pose was never exported, so they cannot be retargeted honestly (same
as Tower II's Saug); BO6 vfx returned zero rows in the export index, so muzzle / trail
/ impact / glow stay the BO3 effects (glow moved to the new socket, CSC per-element
tag). Charge shot user-excluded. Ledger `port_gate.py check` = INCOMPLETE 9 open / 0
invalid — every stream `implemented`/`adapted`, none `verified` until the native run.
Test flags still ARMED (tod_dev, tod_god, tod_dev_maxed, tod_dev_mage_test → spawn as
Mage holding ice); spire harness parked. FULL BUILD VERIFIED 2026-09-13 03:45:19 Eastern,
FF 176,107,328 bytes; 28 fresh content-hash `i_tod_bo6_ice_*.iwi`, both xmodels + six
materials in the assetinfo ledger, all 14 wav stems in the fresh `.sabl` beside controls;
scripts/zone_source/ui diffs clean, nothing synced after the `.ff`. NATIVE RUN 03:50–03:51
(agent-launched, PID 30776): map loaded, Mage auto-drafted with ice, the BO6 staff rendered in
hand textured + glowing and fired (`tmp/bo6_ice_staff/native_*.png`), no tod_bo6/sound/script
errors; GAME LEFT RUNNING for the user. Look/alignment/sound levels = the user's call, PENDING.
Then disarm the flags before publish.
**v18.90 — THE SHOT FX ARE BO6-INSPIRED, NOT BO6** (user: "it looks like the same fx" — it was):
Saluki has NO particle/vfx asset type and the name dictionaries hold no `vfx_*staff_ice*`, so
BO6's effects CANNOT be exported here — do not re-open that hunt. `tools/bo6_extraction/
build_bo6_ice_fx.py` composes `share/raw/fx/tod/bo6/fx_bo6_ice_{muzzle_1p,muzzle_3p,trail,
impact}` from BO3 emitters (our trimmed set + Winter's Howl flash/impact + the stock Origins
impact) with a cyan-white tint; bound on the ice weapon + q0/q1, zoned, pinned by `--check`
in the staff gate. The glare rule stands (1p core flash 18, no light/lens flare). Ledger
`adapted`. FULL BUILD VERIFIED 2026-09-13 04:23:38 Eastern, FF 176,347,712 bytes; the four fx
in the assetinfo ledger; diffs clean, nothing synced after the `.ff`; logger label folded in.
NATIVE RUN 04:26 (PID 31784): loaded, fx rendered (crystal spray, frost, sparkling trail —
`tmp/bo6_ice_staff/native_fx_*.png`), no errors; GAME LEFT RUNNING. Frost mist reads heavy after
several corridor shots = first knob (`frost` scale, impact snow-fog). **v18.91 — user: "a big puff
and flash on the player's screen, the only part I don't like": the 1p muzzle now has NO core flash
and NO frost puff (crystals only), the trail no frost wisp; 3p and impact unchanged. THE 1P RULE
IS NOW TWICE-EARNED (v18.75 glare, v18.91 puff): nothing big or bright spawns at the shooter's
camera.** FULL BUILD VERIFIED 2026-09-13 04:33:18 Eastern, FF 176,347,712 bytes; trimmed fx in the
ledger (1p 23,072 B / 16 emitters); diffs clean. NATIVE RUN 04:36 (PID 20104): crystal spray
only, no flash/puff on screen (`tmp/bo6_ice_staff/native_fx2_muzzle.png`); GAME LEFT RUNNING.
**v18.92 (user: "still there" → "have the projectile grow as it goes", "I like the powder haze,
just not in my face", "make the crystal glow more"):** trail body sprites are gated on distance
from the camera (`spawn_min` 96/136/176/216 + 48-unit fade-in: the bolt leaves as sparkles and
fills out a few feet away), the 1p muzzle's haze/glow one-shots are pushed 48 units down the
shaft (`org_x`), the tip crystal materials' `scaleRGB` 6 → 14 (per-material `EMISSIVE_SCALE`).
Impact and muzzle contents otherwise as v18.91. FULL BUILD VERIFIED 2026-09-13 04:44:06 Eastern,
FF 176,347,712 bytes; deployed inputs carry the change; diffs clean. NATIVE RUN 04:47 (PID
37180): sparkles at the tip, haze lands ahead, no screen flash (`tmp/bo6_ice_staff/native_fx3_*.png`);
GAME LEFT RUNNING. User judgement on bolt growth / crystal brightness PENDING.
**v18.93 — THE "FLASH IN MY FACE" WAS A LAUNCH-POINT BUG, NOT AN EFFECT** (user: "just move
where the shot starts"): the ice volley's two side missiles were `MagicBullet`ed from
`self GetEye()` — the camera — so three rounds of effect trimming (v18.91/92) could not fix
it. Now `TOD_MAGE_ICE_VOLLEY_START` 88 ahead of the eye, and the centre bolt / 1p flash
origin `tag_flash` is shifted +48 along the shaft INSIDE the 24 ice clips
(`tools/bo6_extraction/shift_ice_flash.py`, originals parked, manifest re-hashed) because
BO3 has no weapon-level spawn offset and clips pin the tag. **When a 1p effect is "in the
face", read where the script SPAWNS it before touching the effect.** Same build: the three
tip glows at 125% (`fx_tod_staff_glow_*`, CSC repointed; user: "25% more ... color and
personality"). FULL BUILD VERIFIED 2026-09-13 04:54:30 Eastern, FF 176,398,336 bytes; glows in
the ledger, deployed ice clips = shifted clips, diffs clean. NATIVE RUN 04:56 (PID 30152, user
playing): fire staff's 125% glow seen (`tmp/bo6_ice_staff/native_fx4_idle.png`); user: "Okay
looks good." **v18.94 — ICE SWITCH DELAY = THE FIRE STAFF'S OLD BUG:** ice's native `fireTime`
was its whole 1.1111 s cadence and the engine holds the weapon switch for the firing state.
Now `fireTime` 0.1 and `TOD_MAGE_ICE_RECOVERY_MS` 1111 on the fire cooldown controller
(`tod_mage_ice_ready_ms`, `DisableWeaponFire` only). Lightning still has a real native
fireTime (0.2294) — short enough that nobody has reported it; if they do, same recipe.
__BO6_FX5_BUILD_STATUS__

**UI element-pool report (2026-09-10, follow-up after publish candidate):**
Steam round-19 crash report has no class/co-op/action details. Exact crash
not reproduced. Pause-menu cleanup omitted OptionsList plus upgrade/control
elements: actual constructor/close under Lua 5.1 leaves 157/176 direct elements
unclosed with 18 test rows; complete direct-child cleanup leaves zero. Score
popups normally close correctly; now capped at eight concurrent popups per
owner to bound bursts/interrupted clips. 400 pause cycles and 7,500 popup
cases pass. Experimental UI telemetry was removed: client output unverified,
and a temporary PrintInfo probe produced UI Error 85029. No such call, label
probe, notify, relay or diagnostic module remains. Existing AI logging retained.
See docs/133_ui_element_pool.md. BUILD VERIFIED 23:44:40 Eastern, FF
176,322,176 bytes; 1,533 input/deploy/freshness checks pass. Native HUD, class
selection and pause open/close passed; test ended in ordinary round-2 death
while idle. No native pool measurement or round-19 reproduction. Dev/god false;
verification game closed. The 23:05 publish candidate predates these changes.

**PUBLISH CANDIDATE (2026-09-11, v18.84):** ship state — all seven `tod_dev*` /
`tod_god` **false**, HARNESS #8 parked, both re-proven in the DEPLOYED tree. PUBLISH
BUILD VERIFIED 2026-09-11 01:13:35 Eastern, FF 176,322,176 bytes, payload 2,119,324,411
bytes / 48 files, pack 1,328,939,008; `-CleanPak` + all twelve languages, every language
`.ff` stamped 01:09–01:13 from this tree. Gates all green. Player notes:
`Update — Sep 11 (v18.84)`, 33 bullets, SHORT AND PLAIN.
**Owed: the upload, then `node tools/patch_notes.js uploaded`.**
**THE LIGHTNING STAFF'S DOUBLE RELOAD (v18.84) WAS NOT THE SHOT COUNTER** — the staffs
are `segmentedReload` and topped up `reloadAmmoAdd` 999 against `clipSize` 1000, so a
reload STARTING EMPTY came up one round short and the engine ran a second segment. The
optional reload never showed it: it starts at `clipSize - 1` and clamps full in one
pass. `verify_staff_animations.py` ASSERTED the 999 under the comment "one full reload
segment" and failed the build — **a gate written before the forced reload existed, still
asserting the old start state.** A gate is a statement about the world when it was
written; when one fails a change you believe in, read what it was actually protecting.
⚠️ **A PUBLISH RESULT IS A STATEMENT ABOUT A TREE AT AN INSTANT.** The v18.82 candidate
passed at 23:05 and a peer session built v18.83 over it at 23:44, so "are we good to
publish?" had to be RE-RUN, not recalled: deployed flags, repo-vs-deployed diff, nothing
newer than the `.ff`, the notes gate, and the pack's own index. Two of those five had
moved. And when the pack report was read to blame the peer build for 60 MB, the rebuild
disproved it — a CLEAN pack here still carries ~52 MB of holes and 2 shadow trees; the
peer build's real cost was 8.7 MB. Read the whole report, not one field.

**Elite freeze cause and fix (2026-09-10):** native run
`tmp/elite_tracking/runs/20260910_224229_229_a18a10ca` records a world pause
ON AND OFF at 69550 ms, exactly when a moving hound freezes. Dev round events
admit a maxed player with dark cards remaining, then roll_options refuses the
empty hand without dark_guarantee. Both pause edges occur in one frame. The
writer stamps ASM rate 0.05; the 250 ms elite watcher misses the pulse and
never restores it. Regular zombies have a speed sweep; these elites do not.
FIX: freeze writer latches tod_elite_pause_pending; boss_pause_watch consumes
it on release even without an observed rising edge. Existing entrance/pause
ownership retained; unexpired elite slows retained; no continuous rate reset.
Actual-function test reproduces the old fault and passes short/long/repeated
pauses, Fury park, entrance and slow cases; required in build_map.ps1.
Earlier claim "maxed empty deals always return before pause" was INCOMPLETE:
read the dark admission vs dark guarantee checks. Native entity rate=1 and
ASM status=running do NOT prove the ASM pause rate was restored.
Recorder schema 2/tag 20260910f logs exact pause writes/restores and
PAUSE_RESTORE missed_edge=1. Prefix/devblock output proven in run e for all
five families. Shared requested-state hook saw zero calls and was removed.
Initial unwrapped PrintLn fatal and missing devblock launch flag were OUR
logger mistakes, corrected. Separate Mage undefined/lightning guard fixed;
bolt test now models native undefined comparisons. Earlier Fury assertions
remain unlocalized; first-hall path errors are separate unresolved evidence.
See docs/131_elite_tracking_diagnostics.md. BUILD VERIFIED 22:44:11 Eastern,
FF 176,322,176 bytes; 1,533 input/deploy/freshness checks passed. NATIVE FIX
VERIFIED: run 20260910_224853_099_384014b1, pause on/off=118050, hound and
Protector restores at 118100 followed by movement. Next pulse143050 restores
seven elites in 50-150 ms. Nine missed-edge restores, all five families sampled,
zero script exceptions. Game left running for user retest. No claim that this
repairs every unrelated navigation stall.
The agent-run launch procedure is now recorded below and in docs/132; AGENTS.md
points Codex to it. Persistent window helpers live under tools/.

**Mage staff likeness (2026-09-10, v18.81):** all six baked mage assets
re-drawn over their existing names — icons `i_tod_hud_gun_staff1|2|3`, cards
`i_tod_card_class_mage` / `i_tod_card_tier_mage_2|3` — because the drawn
staffs did not resemble the ported Origins staffs actually held. **A SUBJECT
gap, not a style gap: docs/124 had already fixed the icons' treatment, so the
constraint was that the treatment must not move while the object changed.**
Re-measured with `tools/gen_staffhud_ref.js`'s own `stat()`: still 3 tones and
the `#0A1020`/`#E8EEF6`/`#62779C` palette, saturated share HALVED toward the
gun mean, ice's ink coverage up off 29.8%. Their PNGs are ~2.6x the bytes and
that is anti-alias fringe (distinct RGB 180 -> 310, every added value <0.4% of
ink), not colour — do not read file size as a style regression. Cards changed
only inside the art window except the class card's name plate, which was
re-set to two lines and accepted for legibility at its real 186x279.
Read docs/128 before re-commissioning any of the six. FULL BUILD VERIFIED
2026-09-10 21:07:04 Eastern, FF 176,321,152 bytes; six fresh content-hash
`.iwi` at 21:06:54 against 9,942 untouched, all three source diffs clean,
nothing synced after the `.ff`. The six replaced originals are parked at
`docs/128_staff_ref/_prev_shipped_20260910/` and **these images are not git
tracked, so that folder is the only copy.** UNPLAYED; harness #8 and the dev
flags stay ARMED.

**PaP tier icons, ROUND 4 SHIPPED (2026-09-10, v18.82, docs/131)** — the
chevron stack, one flat chevron per tier in the three `DISTRICTS` hues
(`#3FD8E8` / `#F5C542` / `#F0524B` exact), installed over
`i_tod_hud_pap_1|2|3`. **Saturated ink 9.0% -> 49.9%** against a 29.3%
blink/heal bar; ink 49.9%, 3 tones, bbox 80.7%, every docs/131 gate cleared.
A "thinnest horizontal run = 1 px" reading there is a DIAGONAL ARTIFACT, not a
violation — do not chase it (round 3 scored 2 px for the same reason). Round 3
parked at `docs/131_pap_ref/_prev_shipped/`, the only copy. The commission that
produced it is below and its reasoning still governs any future round:

**PaP tier icons, ROUND 4 COMMISSIONED (2026-09-10, docs/131)** — user, on
seeing round 3 in game: *"Our pap icon looks like ass in game. But both blink
and healing aura look great ... Creative and obvious to the player what tier
pap they are."* **THE SIZE IS NOT THE PROBLEM AND THE NEXT SESSION MUST NOT
"FIX" IT THAT WAY:** the PaP glyph box is **26x26** canvas units
(`AetheriumLoadout.lua:1443`) against the offhand icons' **24x24** (:1346), so
the badge already gets MORE room than the two icons that beat it, and ink
coverage is effectively equal (43.3% vs 45.9%). The measured gap is **saturated
ink 9.0% against 29.3%** — the icons are drained of colour — plus two half-scale
objects in one cell and a tier signal that is a COUNTING task at 39 px.
`tools/gen_pap_icon_ref.js` prints all of it and writes the true-on-screen row;
an obvious largest-connected-blob hypothesis was tested and REFUTED there (all
five score one blob, because the fist and its badge touch). docs/131 asks for
one flat geometric emblem per tier escalating on BOTH hue and silhouette, on a
three-step slice of the `DISTRICTS` ladder (cyan `#3FD8E8` / gold `#F5C542` /
red `#F0524B`; never green — that is the heal icon). **The level DIGIT is
already drawn by the game beside the glyph, so no numeral may be baked in.**
Zip in Downloads; nothing installed, no build needed until it returns.

**PaP icon readability (2026-09-10, v18.79d):** installed PNGs matched the
older 13:13 art drop, despite docs/125 recording the newer 19:19 set as shipped.
Restored the exact newer delivered files and enlarged the glyph box 24 -> 26
canvas units, centred inside the existing plate. Visible artwork width at
1080p is now ~34 px instead of ~25 px. All three sources remain 128x128;
uncompressed/noPicMip settings retained. None was in the size-pass manifest.
HUD Lua 5.1 parse and dark/bright layout preview pass. FULL BUILD VERIFIED
2026-09-10 20:03:42 Eastern, FF 176,182,656 bytes; all 1,529 input hashes,
complete deployed trees and timestamps pass. Native visual check pending.
No gameplay or geometry source edits.

**PaP staff HUD names simplified (2026-09-10, v18.79c):** the existing
`tod_pap_tier` event now carries the HELD staff ID with its tier. Lua selects
the base/packed name directly from one local table; engine display-name text
and the old inventory mask no longer determine the staff label. Same-tier
staff switches trigger updates. Gameplay, damage and PaP ownership unchanged.
Thirty actual GSC update packets pass the Lua 5.1 receiver/name checks,
including missing/stale engine names; HUD startup/global guards pass.
Script/UI BUILD VERIFIED 2026-09-10 19:47:55 Eastern, FF 176,182,656 bytes;
all 1,529 input hashes and complete deployed trees match and predate FF.
Geometry MD5 unchanged d08da883c2322730475d3d7682250dcf. Native label check
PENDING: Steam launch confirmation remains open; BO3 did not start.

**Download size pass (2026-09-10, v18.79):** complete deployed upload folder
**2,708,843,259 -> 2,117,743,099 bytes**, saving **591.1 MB / 21.82%**.
236 included texture sources reduced selectively; material references share
29 duplicate image names; nine raw camo/PaP images use supported compression.
Labels/sights, sprinter colors, hall crests, geometry, gameplay and audio retained.
FULL CLEAN ALL-LANGUAGE BUILD VERIFIED 2026-09-10 18:53:58 Eastern, final FF
176,182,656 bytes at 18:53:55. All 1,527 input hashes/deployed targets and
freshness checks pass; all 13 pack indexes checked. No unexplained removed
image names or removed non-image names; mesh bytes unchanged. UNPLAYED,
not uploaded; dev/god/open doors remain armed. Read docs/129 for measured
breakdown and visual checks; docs/128_download_size_audit is the original review.
`tools/optimize_tod_assets.py --verify` checks the installed/repo sources;
`--restore` restores this pass, then FULL -CleanPak rebuild. Originals/manifest
are outside build inputs at `<modtools>/_tod_size_originals/20260910/`.
`-CleanPak` now cleans ALL 13 packs and implies all languages; previous
packs/FFs/banks are kept until the last language passes. Unexpected English
or language linker errors fail. Only the two existing Japanese model
exclusions are accepted after checking their actual japaneseUnsafe flags.
The complete payload report is `usermaps/zm_tower_of_doom/last_payload.json`,
outside the upload folder. Do not describe this texture pass as visually
regression-free before native testing.

Floor-10 overlook removed (2026-09-10): User rejected the Sky Lounge
extension. Restored the shared original room geometry/polish, theme lights
and haze on floor 10; removed extension zone volumes and lounge lookup
bounds. Deleted tools/breather10.js and regenerated map/breather data.
Existing service, spawn and teleporter anchors retained. Full rebuild passed 2026-09-10 16:25:22 Eastern, including geometry,
navigation and lighting; all 1,165 input hashes match deployed and predate
the FF. Native walkthrough pending. This build also includes the previously
tested Protector damage-feed fix.

**THE ROOMS (2026-09-10, v18.80, user after playing three v18.78 halls: "I can
barely tell what unique changes you made ... better uniquely design each trial"):**
every trial hall is now a different SPACE, not a different set of furniture — one
room-scale idea each, with height: THE RING a 48-up stepped STAGE, THE KENNEL a six-pen
CAGE BLOCK with corridors, THE FIRING LINE a 344-wide parapet PLATFORM with a stair at
each end, THE ALTAR a railed CHANCEL across the room, THE MAZE two pinwheel RINGS of
160 walls, THE GAUNTLET three walls COMBING a serpentine, THE THRONE a 72-up railed
PLATFORM with one grand stair and the seat on it. New `SP_RM_LAYOUTS` kinds `stage` /
`deck` / `seat` (generator; docs/130 §B) — **a raised top is a <= 64 SLAB over a
body or lint_tod_geometry calls it a wall, a stair's foot lands on OPEN floor, and a
one-stair platform carries a riser ON it.** The bunker lint scans every level to +140
now (selftest 6/6); 0 bunkers, 0 unguarded edges, 0 detached. Read docs/130 before
touching a hall. FULL BUILD VERIFIED 2026-09-10 20:30:58 Eastern, FF 176,321,152 bytes; in-build hall bunker lint 0/7, geometry lint no regression, navmesh gate OK (both towers one walk); scripts/zone_source/ui diffs clean, nothing synced after the .ff, the compiled map md5-identical to the repo's. Harness #8 + dev flags still ARMED (test build). UNPLAYED.

**THE OPEN HALLS (2026-09-10, v18.78, user: "Everyone just bunker up in the
little cubby"):** every spire trial hall now owns its SHELL as well as its room —
`SP_RM_LAYOUTS[i].furn` (PaP / crate wall presets `SP_PAP_AT` / `SP_CRATE_AT`),
`.risers` (three shell porch risers incl. THE DOORWAY'S CORNER + one INSIDE every
pocket), `.spawns`, `.alcove` ('seal' block / 'open' spawn closet). The two
pockets every hall shared were the sunken PORCH behind the gate and the SE
ALCOVE under the SE landing, which was also OUTSIDE `trial_box` (now in;
exclusion 3 = the S lane; **exclusion 4 (v18.79b, first play) = the SE LANDING
ABOVE the alcove, z > +100 — it is outside the seal and carries a riser, and
letting it in put stranded zombies and frozen elites on it**). Vendor anchors are PER HUB in `_tod_spire_data`
(`hub_pap_org( hub, z )`). In a sealed hall the horde rises at the risers
nearest a random upright player 70% of the time (`TOD_TRIAL_NEAR_PCT/_K`,
`trial_near_spots`). **`tools/lint_tod_hall_bunkers.js` GATES EVERY FULL BUILD:
no one-sector pocket under 80 degrees without a riser inside it; zero, no
baseline; `--png DIR` heatmaps, `--probe X,Y[,N]`, selftest 6/6.** Flow
untouched (porch, seal, clock, recipes, mark, deal). Read docs/128 before
touching a hall; the metric lessons are in memory `hall-bunker-lint`. FULL
BUILD VERIFIED 2026-09-10 17:19:55 Eastern, FF 176,181,632 bytes, all three
freshness checks clean; dev flags still ARMED (tod_dev/tod_god/tod_dev_doors).
UNPLAYED.

**Protector staff damage/display mismatch (2026-09-10):**
The rp_damage_feed fallback called upgrade_damage_cb, leaving its same-frame
stamp behind. Subsequent fallback hits in that frame returned raw damage
without staff scaling or a popup. Controlled actual-handler reproduction:
three 20k raw hits with a 6k scaled result returned 46k but displayed 6k.
Consume the normal-chain stamp and clear the stamp after fallback processing.
All eight three-impact normal/fallback combinations now scale and display
exactly once; unchanged sentinel/non-player passthrough and Mage damage tests
pass. This is a reproduced fallback-path defect, not a capture of the user's
exact shot. Build/native verification pending: BO3 remains running.

**Staff balance (2026-09-10, v18.77):** ice fireTime 1.00 -> 1.1111 (GDT),
ICE_NERF 0.80 -> 0.68, ICE_VS_ARMOUR_ROBOT 0.60 -> 0.35, FIRE_VS_BEAST 0.50
-> 0.35, LIGHTNING_VS_PANZER 5.60 -> 4.76 (-15%). LIGHTNING RELOADS EVERY 20 SHOTS (15 until 2026-09-11): `bolt_count_shot` on weapon_fired,
`staff_clip_target` pins the clip to 0 when due (engine auto-reload), ANY
reload_start resets (`bolt_reload_reset`). `tools/test_mage_bolt_reload.js`.
FULL build, UNPLAYED. **The armory has a BALANCE tab** (13th; enemy HP × class
DPS × TTK × EHP with every stacking rule in code order, 272 checked constants);
re-run the three verify_armory_* gates after any retune and republish
be85de67.

**CONFIRMED UI Error 87927 cause (2026-09-10):** Native diagnostic HUD
captured `LUI Error: Tried to create global variable TOD_STAFF_PACKED_NAME`.
The packed-staff name table in AetheriumLoadout.lua lacked `local` at line
221. Fixed to a local table; the temporary diagnostic wrapper in
AetheriumHud.lua has been removed. test_hud_global_guard.lua loads the actual
module under a no-new-globals environment and reproduces the exact error
with the old declaration. The earlier notification-order fix was not the
cause of this reported failure. Corrected script/UI build passed at
14:53:30 Eastern; all 49 UI and 88 script files match deployed and predate
the FF. Native BO3 check passed: full Aetherium HUD visible at class select
and after choosing Mage (health, points, weapon, mana and ability tiles);
no UI error dialog or diagnostic overlay. Game left running for the user.

**HUD startup ordering fix (2026-09-10, UI Error 87927 report):**
AetheriumLoadout installed its scriptNotify subscription before creating
lethal/tactical slots. An immediate replay of tod_mage_mana dereferenced a
nil slot, including the non-Mage state 2 startup path. Move the subscription
to the end of construction, after slots, feedback frames and stock writers.
Seven eager-notify regression cases pass; negative controls reproduce the
old nil-slot error. Seven-digit damage encoding/display is unchanged.
Script/UI build passed 2026-09-10 14:30:19 Eastern, FF 175,875,968 bytes;
complete deployed scripts (88) and UI (49) match. A concurrent edit changed
ice muzzle 1p FX during linking, so this is not a verified build of that
separate FX revision. Screenshot error code has no console traceback;
native confirmation of the reported error is still pending.

**Ice shot glare reduction (2026-09-10):** User reports screen flashing
on firing. Map-owned 1p muzzle removes lens flare looping7 and dynamic
lights oneshot11/18; 3p removes lights oneshot20/21. Both muzzle glow
sprites shrink 75 -> 18.75 with alpha x0.2 and a blue opening color; the
600-unit haze shrinks to 120, lasts 220 ms instead of 508, and uses alpha
x0.2. Shared ice trail removes phosphor flash sprites oneshot3/4 and
dynamic light12, which were carried by all three missiles from near the
camera. Forty other emitters are byte-identical. Existing q0/q1 references
already use these FX. No weapon, damage, volley or impact changes. Forty
volley aim/variant cases and asset lint pass. Full build verified
2026-09-10 14:17:24 Eastern; FF 175,875,968 bytes. All 1,165
snapshot/repo/deployed input hashes match and predate FF; complete
script/UI trees match. Native flash/visibility check pending.

**Seven player-report fixes + the Mage dark cards (2026-09-10, v18.76):**
no elite behind an unbought door (`_tod_bosses::door_frontier_z`, the
GENERATED door table is the authority, tower only); ARCHMAGE tears down on
death / class change (`demigod_guard` -> one `demigod_end`); the lethal tile
dims for the aura's 5 s lock (`heal_lock_tell`); staff raise/putaway/pickup
now play our own foley (`wpn_tod_staff_*_plr`, reused WAVs); a fresh Mage sees
DIM tiles (never hidden) and one hint; reload mana paced to once per 10 s
(`TOD_MAGE_RELOAD_MANA_WINDOW_MS`); all five Mage dark cards installed,
`DARK_TEXT_ONLY` empty. ⚠️ THE KING'S FLAME RECORD BELOW WAS WRONG: king_setup
DOES swap in a 400x100x50 flame trigger (v17.70), so the hurt box is doubled
too. `tools/test_mage_fixes_0910.js`. FULL build, UNPLAYED.

**Player feedback fixes (2026-09-10):** Review items 1, 2, 4 and 5.
Dark Healing Aura clamps only its radius to Lv6 while retaining Dark strength
and revive. Dark Blink retains the distance readout. Mage tiles gain subtle
perimeter recharge progress from real paused timers and a 350 ms amber Blink
blocked-landing pulse, with no charge spent. Teleporter hints distinguish power
from destination locks; nearby players get a LUI countdown/progress indicator
inside the teleporter prompt. Three eventstrings, zero new clientfields or
image assets; fixed hint count rises by one (96/190 budget). GSC helper and
Lua 5.1 UI tests pass, including Dark range/revive, pause, class reset and
pad selection. Full build verified 2026-09-10 14:07:04 Eastern;
FF 175,868,736 bytes. All 1,165 snapshot/repo/deployed input hashes
match and predate FF; complete script/UI trees match. Existing waived
asset warnings only. Dev/god/open doors remain enabled. Native visual/
gameplay check pending.

**Warden King under RAMPAGE (2026-09-10, v18.75):** rampage barely reached
him (flat HP write below boss_hp). Now, behind `_tod_spire::king_rampage()`
only: HP x1.25 (`TOD_KING_RAMPAGE_*`), permanent SPRINT locomotion via the
blackboard with flame/claw kept (`king_sprint`; permanent BERSERK was rejected
— berserk disables flame and claw), stock berserk for 10 s on every summons,
summons 18 -> 13 s with +1 Protector +1 hound, trickle floor 0.10 (lockstep
pair with `_tod_endless_rounds`), and every ordinary zombie on the deck +10
rounds of sprint through the sprinter's `tod_zspeed_round_add` lane.
`tools/test_king_rampage.js`. His base HP is **10M per player** (the brief
below said 25M until today). Same pass: the SCOREBOARD's owned-upgrades
`TOD_UPG_PLATE_MAX` was 47 against the pause menu's 56 (every Mage row a text
label there) — now 56, and `lint_tod_assets` GATE D fails the build if the
pair ever differs again. Built -GscOnly, UNPLAYED.

**Floor-10 walkthrough dev session (2026-09-10):** User requested dev, god
and all doors open. Armed tod_dev, tod_god and tod_dev_doors in the map
entry. Existing dev bundle provides money, maxed class upgrades and
unlimited altar uses; existing door harness opens every tower door and
breather access from the normal base spawn. Script build verified
2026-09-10 02:52:58 Eastern; FF 173,330,752 bytes. All 140
snapshot/repo/deployed inputs match and predate FF; complete script/UI
trees match. In-game walkthrough pending.

**Floor-10 Sky Lounge prototype (2026-09-10):** Structural redesign only on
the tenth-floor breather: stepped overlook adds 39.2% room floor, open low
parapets, arrival portal, shallow service canopies, lookout fins, dark-blue
floor and warm/cool light pools. Anchors and existing spawn mechanics stay.
New wing is zoned; generated shared room lookup covers arrival/relief.
Floor-10 chest haze becomes low overlook fog and high motes. All changed
world geometry labels are floor-10 breather; other stops retain their design.
Geometry/arity, 4,216 room points and 90 compiled overlook nav samples pass.
Full build verified 2026-09-10 02:06:06 Eastern; FF 173,330,752 bytes.
All 1,154 snapshot/repo/deployed hashes match; script/UI trees match. Six
pre-existing dark pause PNGs carry future 03:05:56 archive timestamps, but
match the pre-build snapshot; other 1,148 inputs predate FF. Native
appearance/walk-through pending. See docs/127.

**RAMPAGE re-hardened (2026-09-10, v18.74, user: "rampage feels easier"):**
the Sep 6/7 relief (elite roof 12 -> 5/7/9/11, horde HP table, elites -10%)
had reached hard mode because those knobs had no rampage branch. Now, ON the
breaker only: elite roof +3 (`TOD_RAMPAGE_ELITE_ROOF_ADD`, 8/10/12/14),
zombies at once +10 over the party figure (`TOD_RAMPAGE_AI_LIMIT_ADD`,
40/45/50/55 — no longer a flat 45), elites/Panzer x1.5 (`TOD_RAMPAGE_HP_MULT`,
was 1.25) and NEW horde HP x1.2 (`_tod_zombie_speed::rampage_horde_mult`,
which the sprinter divides out to take the elite bump once). Read the defines;
`tools/test_rampage_levers.js`. Built -GscOnly, UNPLAYED.

**First Mage playtest pass (2026-09-09, v18.73 — twelve calls):** ladder
x0.85 (TIER 0.6256/1.36/2.686 - READ THE DEFINES; a 2026-09-21 x0.92 on this SHARED ladder was reverted the same day, because the re-cut is PER STAFF: FIRE_NERF 0.95, FIRE_VS_BEAST 0.2625, ICE_VS_HORDE_PANZER 0.90, lightning untouched), FIRE_VS_ARMOUR 1.75, ICE_VS_BEAST 2.85,
ICE_OFF 0.80, NEW FIRE_VS_BEAST 0.50 (never tier-gated); fire splash 192,
ice shake/kick zeroed (FULL build); todDmgNum 15 bits = scale bit, cap
2,047,000, POOL 61/61 — NO BITS LEFT; mana 0.8/s + budget 32; BLINK x1.8 and
the elite-kill refund is DELETED; five mage domains DARK-CAPABLE with real
lanes (fire/ice +0.50, heal rung 7, arch, blink 3rd charge) — only HEALING
AURA has dark art, docs/126 orders the rest, the others wear DARK text;
pause dark rows say "DARK: " instead of tinting; classless players wear body
0 until the draft; packed staffs are KIMAT'S BITE / KAGUTSUCHI'S BLOOD /
ULL'S ARROW. Read the CHANGELOG v18.73 entry; nothing played yet.

**Queued Mage changes built (2026-09-09 19:58:48 Eastern):** Full build
plus script follow-up passed; fresh FF 172904832 bytes. All 1,147
snapshot/repo/deployed script/UI/zone, GDT, FX, alias, WAV and approved
animation inputs match and predate FF; complete script/UI trees match.
Includes current Chain Lightning progression and queued staff work. Native
gameplay/visual/audio check pending. Blink gain remains unimplemented.

**Mage ceiling pass (2026-09-09):** FIRE_VS_ARMOUR 3.61 -> 1.25 (tier-3 tap 15k),
ICE_VS_ARMOUR_ROBOT 0.30 -> 0.60, ARCHMAGE ladder top 2.20 -> 1.85 (LOCKSTEP
Lua row 55 + armory), dark CHAIN +2 -> +1 arc. ARCHMAGE has NO dark card
(set_no_dark); the armory used to say x2.70 was reachable. Artifact "Staff
Damage Matrix" computes the whole chain from the constants. Build pending.

**Staff lanes (2026-09-09):** TOD_MAGE_VS_HORDE 1.30 -> 1.75, TOD_MAGE_ICE_OFF
2.36 -> 1.00. Ice = beasts (3.352 unchanged), okay on hordes, ~2% of
lightning on the Panzer. Lightning = horde + Panzer. Fire = armour, unchanged.
The v18.56 "ice is the generalist" prose in _tod_mage_elements and the
armory is history now. Build pending; native check pending.

**Chain Lightning ten levels (2026-09-09):** mage_bolt max 10; normal arcs
1/2/2/3/3/4/4/5/5/6, with Dark retaining two additional arcs (eight at cap).
Chain fraction is 0.50 * (1 + 0.05 * level): 50% base, 52.5% at Lv1,
75% at Lv10. The +5% is relative to half-damage base, not +5 percentage
points of the original hit. Prior code already used half damage and skipped
attacker multipliers on marked chain callbacks; no 100% arc base was found.
Server card, Lua level/readout/Dark display and armory updated. Actual helper
and callback tests pass through all levels, Dark, rounding and sprinter armor;
once-per-shot, damage, arity, Lua lint and armory checks pass. Build/native
playtest pending BO3 closure.

**Ability first-draw replay correction (2026-09-09):** User confirms the
previous InitialWeaponRaise-on-held-staff call did NOT replay Healing Aura.
Earlier source/unit checks were not native playback proof. Shared ability
helper now uses tod_classes::camo_regive(false) to preserve exact asset, ammo
and PaP camo; ShouldDoInitialWeaponRaise(true) requests first draw on next
equip. A frame-delayed bounded equip handles swallowed same-frame switches,
stopping on death/disarm/disconnect, lost ownership or last stand. Both Aura
and Archmage use it. test_mage_ability_raise covers six variants and empty/
partial ammo with actual helpers. Arity, healing and animation assets pass.
Script build verified 2026-09-09 18:48:31 Eastern; FF 172878912 bytes.
All 140 snapshot/repo/deployed inputs match and predate FF; script/UI trees
match. Native animation verification pending; do not claim visible playback.

**Staff first raise (2026-09-09):** Winter's Howl fly_freezegun_first_raise.wav
as staff_first_raise.wav, played ONLY by the frame-1 2D Sound note; the
firstRaiseSound fields are cleared (they named an unzoned stock alias). Every
other non-fire staff sound field still names unzoned stock foley -- see the
v18.70 CHANGELOG audit before claiming any of them plays. Build pending.

**Healing Aura green slightly brighter (2026-09-09):** Aura health tint
RGB 0.20/0.62/0.32 -> 0.21/0.65/0.34, about 5% brighter with the same hue.
Only the aura color changed. Lua lint and 256 tint-state cases pass.
Script build verified 2026-09-09 18:43:25 Eastern; FF 172,903,296 bytes.
All 140 snapshot/repo/deployed script/UI/zone inputs match and predate FF.
Script/UI trees match; zone-source extras are build-generated outputs.
Native visual check pending.

**Ability first-draw animation (2026-09-09):** Shared ability_first_raise
now runs on successful Healing Aura and Archmage activation. Healing Aura
already used InitialWeaponRaise; Archmage now does too. Cancels pending
reload reward before the native gesture and preserves the held staff variant.
Arity, healing strength/FX and staff animation checks pass. Build/native
playback pending BO3 closure.

**⚠️ BLINK'S VOLUME IS NOT A KNOB — CLOSED 2026-09-10, DO NOT RE-INVESTIGATE.**
Asked for twice (+5 dB 2026-09-09, +3 dB 2026-09-10) and it is not achievable
as asked. Blink plays the STOCK aliases `zmb_bgb_abh_teleport_out` /
`_in` directly (`_tod_mage_elements.gsc:1119` and `:1124`). The 2026-09-10 pass
searched exhaustively and the result is negative on every lane:

- the alias pair is defined in **no CSV in the repo and none anywhere under the
  mod tools root** — it exists only inside BO3's base fastfile, so VolMin/VolMax
  cannot be edited the way the lightning shot aliases were (see the entry below);
- **no source WAV exists**: zero `abh` or `bgb` hits across all 4,822 WAVs in
  `<modtools>/sound_assets`, so it cannot be re-encoded 3 dB hotter;
- the stock WAVs this map already ports came from COMMUNITY PORT PACKS
  (`fly/` = Winter's Howl, `sat_ports/`, `skye_ports/`, `bo4/`, `black_ops_cw/`),
  **not** from extracting the base fastfile — there is no extraction pipeline in
  this repo, and `share/raw/sound` holds 0 WAVs.

So the volume only becomes tunable if the sound becomes MAP-OWNED, which means
substituting a different WAV. **The user was offered that on 2026-09-10 — the
`avo_warp_in/out` pair, `acc/fx/teleport_warp.wav` from map 1, or the Fury
bamf — and chose to KEEP THE STOCK SOUND at its fixed level.** That is a
decision, not a pending task. Do not re-open it, do not claim the volume
changed, and do not reach for an unverified script gain override.

**Lightning firing sound reduced (2026-09-09):** Lowered VolMin/VolMax by
3 on both lightning shot aliases (player 85/90 -> 82/87, NPC 78/80 -> 75/77)
in tod_ports.csv. Sound-context lint passes. Build and native listening check
pending BO3 closure.

**Staff reload sounds, real fix (2026-09-09):** the six staff reload /
first-raise xanim GDT blocks had NO "2D Sound" custom notes; baked notetrack
names play nothing in BO3. SOUND_NOTES in tools/import_staff_animations.py
stamps them (frames 14/29/43/59, first raise 1); verify_staff_animations.py
gates it. Full build pending BO3 closure; native check pending.

**Lightning chain gray debris removed (2026-09-09):** Chain-hit torso FX
now uses map-owned fx_staff_lightning_chain_clean in GSC, CSC and the zone.
Removed stock oneshot emitter 5 (gfx_debris_clumps_em_i8, neutral gray
RGB 0.250980), matching the powder material removed from direct impacts.
The other 70 elements are byte-identical; chain damage and cleanup unchanged.
Arity check passes; asset build and native visual check pending BO3 closure.

**Healing Aura text removed (2026-09-09):** Removed the green AURA / HP/s /
RESIST text and its HUD element. Retained the watcher lifecycle, mana bar
updates and ability charge updates. Healing, resistance and green health-bar
tint remain. Script build and native check pending BO3 closure.

**PaP HUD icons installed (2026-09-09, full build):** gun-with-chevrons set
over the same i_tod_hud_pap_1..3 names, no wiring change. Native look
pending; the user has not yet seen it on the plate in game.

**Dark card overlay + Blink text (2026-09-09, built):** text-only dark cards
(CHAIN LIGHTNING) showed the previous deal's picture underneath because the
reveal flip forced CardImg alpha 1; tod_upgrade.lua now tracks card.imgLive.
Blink's "no footing" print removed. Native check pending.

**Ice lingering icicle models removed (2026-09-09):** Map-owned
fx_staff_ice_trail_clean removes stock trail oneshot emitters 10/11, both
spawning large icicle models with five-second lifetimes. Other 13 trail
elements are byte-identical; impact effect, frost, slow and damage remain.
Source ice staff and generated q0/q1 use the clean effect; semantic byte
comparison confirms those three references are the only GDT changes. Weapon
registrations and cost CSV unchanged. Full build/native visual check pending
BO3 closure, together with lightning gray debris removal and Mystical Hands.

**Ice nerf (2026-09-09, built):** staff_mult cuts ice x0.80 everywhere and a
further x0.30 vs the armour family + Panzer (x0.24 total) --
TOD_MAGE_ICE_NERF / TOD_MAGE_ICE_VS_ARMOUR_ROBOT. Beast/horde keep x0.80.
Native check pending.

**Lightning nerf + unpause sound (2026-09-09, built):** staff_mult cuts
lightning x0.90 unpacked / x0.80 packed (TOD_MAGE_LIGHTNING_NERF /
_PAP_NERF); staff fire aliases no longer Pauseable (the guns never were) as
the best-evidence fix for shots doubling after a pause. Native check pending
for both; the "animation too" half of the report is unexplained.

**Lightning impact gray debris removed (2026-09-09):** Removed four
gray gfx_debris_clumps_em_i8 emitters from fx_tod_elec_impact_sm
(oneshot 11/19/20/21, neutral RGB 0.250980, 433ms). These are the likely
source of the reported gray powder puff. Other 96 elements are byte-identical,
including purple lightning, sparks and clouds. Both existing lightning q0/q1
variants already reference this effect. No weapon or damage changes. Asset
build and native appearance check pending BO3 closure.

**Staff reload/first-raise sound fix (2026-09-09, built):** the seven
freezegun-derived alias rows were gated on a water/over sound context this
map never sets; cleared in tod_ports.csv. NECESSARY BUT NOT SUFFICIENT --
the user still heard nothing; see the 2D Sound note entry above.
tools/lint_tod_sound_context.js gates every build.

**Mystical Hands tier gate (2026-09-09):** Added set_tier_min 2 to
mage_quickhands. Shared domain_available excludes the card at Mage tier 1
and allows it at tiers 2/3. Ultimate-only rarity, effect and persistence remain.
Armory eligibility mirrors the gate. Build pending BO3 closure.

**Max Ammo fills the mana bar (2026-09-09, built):** guarded pointer
level.tod_mage_max_ammo from _tod_powerups::max_ammo_clip_watch; requires the
first ARCHMAGE card; fills to 100 even mid-form. tools/test_mage_max_ammo.js
passes. Native check pending.

**Staff HUD icons fixed (2026-09-09, built):** the gun-bay resolver keys on
DISPLAY names (TOD_NAME_CAT in AetheriumLoadout.lua); the staff rows lived
only in the stem table, so staffs kept the spawn MR6 icon. Three display-name
rows added. Native check pending.

**Mage startup scoring fix (2026-09-09):** The 11:43 build FAILED native
startup: unresolved zm_score::tod_mage_kill_points from _tod_upgrades. Its
vendored _zm_score source did not supply that function to the runtime despite
a successful link and matching deployed sources. Removed that override and
zone entry completely. The existing public zm_score::register_score_event
hook now handles death scoring in _tod_upgrades; shared Mage price helper
lives there and the HUD calls its guarded level pointer. The callback retains
stock bonus/stat work, returns 80 (70 until 2026-09-09) for Mage kills, and lets stock scale/round/award
points. (⚠️ CORRECTED v19.58: the "dogs omit the zombie_team argument" gate was wrong - stock omits it
for ORDINARY zombies too, so Mages were paid stock money until v19.58.) Staff EX
is retained. Actual handler/popup and Lua tests pass. Rebuilt 2026-09-09
11:57:11 Eastern: FF 172,921,280 bytes; all 140 snapshot/repo/deployed
script/UI/zone inputs match and predate FF. Native BO3 launch checked: fresh
11:58 log passes script loading and initializes tower door/PaP/upgrade triggers,
with no SCRIPTERROR, unresolved external or Com_ERROR. Gameplay scoring and
EX appearance still require playtesting.
The previous build-success note is not evidence of successful game startup.

**PaP icon concepts commissioned (2026-09-09):** docs/125 orders three
distinct 128x128 HUD icon concepts (mark / machine / gun-upgrade) to replace
the bullet-shaped i_tod_hud_pap_1..3; zip in Downloads. Drop comes back as
files (N).zip: -Inspect, show the user all three on the plate, then a
follow-up doc for the chosen one. Nothing wired yet.

**Lightning staff fire rate -15% (2026-09-09, built):** fireTime 0.195 ->
0.2294 s in source_data/tod_staff.gdt; q0/q1 twins regenerated (only those
two fields changed). Damage per bolt and everything else unchanged. Full
build; native playtest pending.

**Ice staff shot SFX (2026-09-09, built):** staff_ice_shot.wav replaced with
the user's Ice Spell Impact download, trimmed 1.20-2.70 s (impact first) and
-9 dB; same aliases. Recipe in sound_assets/tod/mage/README.md. Native
level/feel check pending.

**Mage kill points and staff EX names (2026-09-09):** Ordinary Mage zombie
kills pay 70 base points via vendored _zm_score's death-only override, before
Double Points. Shared tod_mage_kill_points feeds the actual payout, popup and
Bounty base. Dogs, other classes, hit points and lump elite/boss rewards retain
their paths. PaP staffs append EX in AetheriumLoadout using all three pack bits
sent together through the existing tod_pap_tier event; no new registrations.
Scoring and Lua 5.1 HUD tests pass. Script build verified 2026-09-09 11:43:38
Eastern: FF 172,967,104 bytes; all 141 snapshot/repo/deployed script/UI/zone
inputs match and predate FF. Established waived warnings only; dev/god flags
off. Native playtest pending.

**Elite/Panzer mana bonus (2026-09-09, built):** The killer of any elite banks
5 mana and the killer of a boss-round Panzer 15, full through round 10, then
scaled by 10/round with a 0.25 floor (elite 1.25 / Panzer 3.75 from round 40).
Constants TOD_MAGE_MANA_ELITE / _PANZER / _ELITE_FULL_ROUND / _ELITE_FLOOR in
_tod_mage_elements; hook level.tod_mage_elite_mana from grant_elite_reward and
the boss-round Panzer lane. Not ARCHMAGE-scaled; normal bar gates apply.
tools/test_mage_elite_mana.js passes. Native check pending.

**Fire Blast card reduced to +20% per level (2026-09-09, built):**
Changed the six-level damage bonus from +25/50/75/100/125/150% to
+20/40/60/80/100/120% (2.20x at Lv6). Server card description, Lua
card/readout and armory now agree. Prior all-staff damage nerf remains;
fire charge payoff, firing rate, handling and other card bonuses are unchanged.
Damage regression, Lua 5.1 level readouts, arity, Lua lint and armory constants pass.
Build verified 2026-09-09 03:18:31 Eastern: FF 172,914,240 bytes; all 1,164
snapshot/repo/deployed inputs and complete script/UI/zone-source trees match
and predate FF. Fresh streamed bank 174,624,640 bytes; only established waived
asset warnings. Ready for native testing.

**All staff damage reduced another 20% (2026-09-09, built):** Multiplied
the shared Mage damage ladder by 0.80: T1 0.92 -> 0.736, T2 2.00 -> 1.60,
T3 3.95 -> 3.16. The three constants are used only by staff_mult, so every
staff direct/splash hit is reduced before the existing card, charge, PaP and
Archmage multipliers finish scaling. Existing ice-specific nerf stays in place.
Lightning chain shares use the reduced final hit and exit the callback before
attacker multipliers can apply twice. Normal integer damage rounding remains.
No weapon GDT, firing rate, splash radius, handling or target-count changes.
Updated the armory damage ladder/readouts; relative card bonuses are unchanged.
Tests compare before/after values across all three staffs, q0/q1, three tiers,
all card levels, four target families, charged shots and normal/Archmage/Dark
multipliers; chain rounding and Panzer display regressions pass. Arity and
armory constants pass.
Build verified 2026-09-09 03:07:27 Eastern: FF 172,914,240 bytes;
all 1,164 snapshot/repo/deployed inputs match and predate FF. Fresh
streamed bank 174,624,640 bytes; only the established waived asset
warnings. All dev/god flags OFF. Ready for native balance testing.


**Combined queued changes - full build verified (2026-09-09 03:01:34 Eastern):**
FF 172,914,240 bytes; fresh streamed sound bank 174,624,640 bytes. All 1,164
snapshot/repo/deployed inputs match and predate the FF; complete scripts, UI
and zone-source comparisons also pass. The packed asset list contains all six
staff variants, nine perk animation clips, the dedicated animtree/module and
green Healing Aura FX. All four reload sound aliases occur in the inflated FF.
Full BSP, navigation, lighting, script/asset/Lua gates pass; only the ten already
waived third-party asset warnings remain. All dev/god flags are OFF.
This build includes every queued change through the latest staff handling pass:
perk-machine animations, green Healing Aura FX, Winter's Howl reload foley,
ice damage/rate/radius nerfs, fire rate/radius nerfs, Archmage sprint fire and
Protector entrance elite immunity. Ready for native testing; no in-game visual,
audio or handling playtest has been performed by the agent.


**Further staff handling and ice cadence nerf (2026-09-09, built):**
User confirmed ice SHOT SPEED means FIRING RATE. Ice fireTime 0.80 -> 1.00s:
20% fewer shots per second (25% longer interval); projectile speed stays 2200.
All twelve staff lower/raise timing fields multiplied by another 1.5 across
lightning/fire/ice, then regenerated q0/q1. Normal drop+raise now
0.5625+0.9000=1.4625s; Mystical Hands 0.1875+0.3000=0.4875s. First raise
1.4625s normal / 0.4875s with card. Quick/empty/ADS-alt/swim timings also scaled;
unused zero alt times remain zero. Generator q-axis formatting now keeps five
decimals so the smaller one-third timings stay exact; other axes keep four.
Semantic comparison proves every timing exactly 1.5x the prior value in all
nine source/generated staff blocks, and only ice fireTime also changed.
Every other weapon/block, registration list and cost CSV stayed unchanged.
Normal cycling is native. Script immediate switches are bounded re-equips for
actual variant/PaP changes, not a Mage normal-cycle override; fire's cooldown
controller only gates shooting. Mage does not receive the Skirmisher HANDLING
card. Updated armory cadence and Mystical Hands timings.
Included in the verified 03:01:34 full build above; native playtest pending.


**Protector entrance elite immunity (2026-09-09, built):** The
Rogue Protector's drop-in kill already excluded the three boss flags but missed
armored sprinters, which deliberately use tod_is_sprinter instead. Added the
landing-specific zm_zod_robot::landing_splash_immune helper and use it in BOTH
_tod_bosses::landing_kill_splash and the vendored Civil Protector landing damage.
It excludes the three existing boss flags, armored sprinters, tagged
(tod_boss_kind) elites/bosses, dead actors and invalid entities BEFORE DoDamage,
StartRagdoll or LaunchRagdoll. No global boss classification or balance changes.
Ordinary zombies retain the existing 350-unit entrance kill and fling; caller
attribution, the lander's own exclusion and harmless relocation landings remain.
Both actual GSC loops pass mocked-actor tests covering all markers, sprinters,
ordinary victims, the exact radius edge and attribution. Arity passes.
Included in the verified 03:01:34 full build above; native playtest pending.


**Staff splash radius reductions (2026-09-09, built):**
Fire explosionRadius 192 -> 144 units (-25%); ice 160 -> 144 (-10%).
Regenerated all four fire/ice q0/q1 variants. Semantic comparison against the
pre-change GDTs proves only explosionRadius changed, with lightning and every
other weapon unchanged. Direct and inner/outer splash damage, minimum radius,
projectile spread, shot cadence and Mystical Hands handling remain as before.
The ice radius applies independently to each of its three real projectiles.
Updated the armory staff table. Registration count remains 235 and weapon cost
table 238/240, byte-identical to before. GDT changes require a FULL build.
Included in the verified 03:01:34 full build above; native playtest pending.


**Mage balance and Archmage sprint fire (2026-09-09, built):**
Ice damage reduced 20% for every target: beast matchup 4.19 -> 3.352 and
all-other-target matchup 2.95 -> 2.36. Those two paths cover every ice hit,
including all three volley missiles, splash and Panzer hits; card bonuses,
PaP and Archmage still multiply the reduced values. ICE SHATTER remains
+15% per level. Fire's shot interval increases 10%, 1430 -> 1573ms. The 0.10s
native state and fire-only lock are unchanged, preserving swaps and use prompts.
Archmage now grants native specialty_sprintfire through a shared
_tod_upgrades::apply_sprint_fire owner. Both the regular upgrade maintenance
and Archmage start/end use that helper, preventing the old card-only upkeep
from stripping the temporary grant. Quarter-second active checks exclude dead,
downed and disarmed Mages; class changes refresh immediately. An owned Sprint
Fire card retains its existing permission independently after Archmage expires.
Updated card/server copy and armory matchup/cadence values. All 64 native-perk
ownership/state cases, ice-before/after damage ratios across tiers/cards/forms,
fire recovery, staff asset integrity, arity and Lua structural checks pass.
Included in the verified 03:01:34 full build above; native playtest pending.


**Staff reload sound (2026-09-09, built):** All three approved
reload clips already had wpn_staff_reload_1..4 notes at frames 14/29/43/59, but
none of those aliases existed in the active sound tables. Added all four to
tod_ports, backed by four short Winter's Howl freezegun reload foley excerpts.
Sources: installed _t8/reload/fly_freezegun_mag_release.wav (first two beats)
and fly_freezegun_mag_in.wav (last two). Each excerpt is 0.28s with 8ms edge
fades, 48kHz stereo 16-bit PCM; exact ranges are in sound_assets/tod/mage/README.
Native animation notes own timing, including Speed Cola and unreached-cue
cancellation on interruption. No scripted sleeps, animation edits or new weapon
registrations. Validated all six q0/q1 staffs and four reload slots each against
the aliases/WAVs and active bank config. Reload mana regression passes.
Included in the verified 03:01:34 full build above; native playtest pending.


**Healing Aura green player FX (2026-09-09, built):** Reused the
installed Near Death Experience third-person effect as a map-owned green tint
(`share/raw/fx/tod/mage/fx_healing_aura_player.efx`). Donor is stock
`zombie/fx_bgb_near_death_3p`: only its 118 color-graph RGB keys changed;
particle motion, sizes, lifespan, camera fade and revive-symbol material remain.
The original source graph is blue, so this is a green adaptation, not a claim
that stock Near Death Experience was green. No image or sound imports needed.
Replaces the machine-light aura and repeated robot-revive hit bursts with one
upper-torso FX host per protected player. Healing pulses and overlapping auras
reuse that host. Host-owned cleanup checks actual aura protection and removes it
after expiry, downing, death or disconnect, including caster disconnects. Native
particles may fade for their original lifetime after the host is removed.
All recipients, including the caster, receive it; native near-camera fade keeps
the world effect out of first person, where the existing green health bar remains.
No new replicated fields; healing, resistance, charges, sound and cast animation
are unchanged. Actual-script lifecycle and healing-scaling tests pass; native
appearance/attachment is untested.
Included in the verified 03:01:34 full build above; native playtest pending.


**Perk machine animations (2026-09-09, built):** Wired the installed
WetEgg SAT animation assets for Speed Cola (power transitions and powered loop),
Double Tap (idle and purchase intro/finite loop/outro), and Wisp Tea (powered
idle and purchase activation). All nine source clips were parsed against their
conversion skeletons: every animated bone exists and tag_origin has zero
translation range. The other current sold machine folders contain no xanims.
Uses stock player perk_purchased, not the vendor-only activateMachineFX event.
No vendor Double Tap bonus attacks or perk balance changes were imported.
A dedicated tod_perk_machines animtree and nine zone xanim entries are included;
sync copies repo animtrees without mirroring over installed third-party trees.
Native AnimScripted playback is cancelled synchronously before shuffle movement
and retirement. Controllers resume using current origin/angles after the glide,
without replaying the power intro; power/model changes also refresh the pose.
No new clientfields or weapon registrations. Actual-script state/sequence tests
cover power, purchase flow, movement and retirement; native appearance, sound
and multiplayer synchronization remain untested.
Included in the verified 03:01:34 full build above; native playtest pending.


**Healing Aura per-level strength (2026-09-09, built):** Lv1 keeps
10 HP/s and 50% damage resistance. Each additional card level adds 1 HP/s and
2 percentage points of resistance: Lv1-6 = 10/11/12/13/14/15 HP/s and
50/52/54/56/58/60% resistance. Five-second totals = 50/55/60/65/70/75 HP.
Caster level is latched for the pulse thread and shared with all recipients.
Integer HP pulses alternate where needed, avoiding trickle_heal's per-pulse
round-up at odd HP/s levels. Existing max-health cap remains authoritative.
Resistance tracks a recent timestamp per aura level on each recipient; the
strongest fresh level wins. A weaker aura neither replaces stronger protection
nor extends its lifetime. Existing 700ms grace and per-cast healing pulses
remain. These fields are server-only, with no new clientfield registrations.
Updated live aura text, card/server descriptions, pause values and armory copy.
Duration, radius, charges, Lv6 revive and the new sound/first-raise gesture
remain. Tests cover Lv1-6, exact full-cast totals, caster-to-teammate strength,
overlap precedence/expiry and Lua readout parity. Native playtest pending.
Build VERIFIED 2026-09-09 01:58:18 Eastern: FF 172,362,496 bytes;
1,142 snapshot/repo/deployed inputs match and predate FF. Fresh sound bank
174,624,640 bytes; only established waived asset warnings.
Dev/god OFF. Ready for native testing.


**Staff card buffs and Panzer damage display (2026-09-09, built):**
FIRE BLAST now adds 25% damage per upgrade level (Lv1-6: +25/50/75/100/125/150%;
maximum multiplier 2.50). ICE SHATTER adds 15% per level (+15/30/45/60/75/90%;
maximum 1.90) and retains its slow duration. These add per level, not compound.
Updated server domain copy, Lua card descriptions/pause values and armory
ladders/current overview. Removed the misleading Fire copy promising a DOT;
its existing survivor flames are visual. Baked card art has no percentages.
Panzer staff numbers now defer from the level callback to the final Panzer
wrapper: stock armor/hit-location reductions finish before one HUD push.
A 4,000 incoming hit reduced to 2,000 displays 2,000; zero/immune results emit
no positive number. Existing direct+splash/crowd summing remains. Marker is
installed with the wrapper; other actors and non-staff HUD paths stay as before.
The previous Panzer calculation body is unchanged, including armor side effects
and lightning's 5.60 matchup multiplier. This corrects reporting, not a hidden
lightning buff. Tests exercise live staff arithmetic at Lv0-6, all six staff
variants, 60 final-result cases, untouched result returns and early HUD suppression.
Lua 5.1 parsing/level readouts, armory constants, arity and fire cooldown pass.
Native Panzer shots-to-kill still need user testing with the corrected numbers.
Build VERIFIED 2026-09-09 01:51:45 Eastern: FF 172,361,408 bytes;
1,142 snapshot/repo/deployed inputs match and predate FF. Fresh sound bank
174,624,640 bytes; only established waived asset warnings. Dev/god
OFF. Ready for native playtest; no gameplay test performed by the agent.


**Healing Aura cast presentation (2026-09-09, built):** Imported the
user's Healing_aura_#4-1788931088647.wav unchanged as
sound_assets/tod/mage/healing_aura.wav (48 kHz stereo, 16-bit PCM, 2.76s).
A distinct tod_mage_heal_activate alias plays locally on a successful cast.
The caster skips the separate first-heal receipt ping; teammates retain that
short stock cue. Locked, active and empty-charge refusals do not play either
the activation audio or gesture. The held staff's native InitialWeaponRaise
replays its existing first-equip animation without replacing the weapon.
The reload-attempt cancellation notify precedes the gesture so an interrupted
reload cannot pay mana. All six q0/q1 staff identities are preserved.
Native sound mix and repeat first-raise playback need an in-game check.
Build VERIFIED 2026-09-09 01:44:06 Eastern: FF 172,361,344 bytes;
1,142 snapshot/repo/deployed inputs match and predate FF. Fresh sound bank
174,624,640 bytes; only established waived asset warnings.
Successful/refused cast checks cover all six staff variants; reload mana and
arity checks pass. Native animation and audio playtest pending. Dev/god OFF.


**Fire recovery correction (2026-09-09, built):** Replaced the failed
swap-button workaround with a fire-only cooldown controller. Native fireTime
is 0.10s, while script retains the 1,430ms deadline via DisableWeaponFire.
No DisableWeapons, forced swaps, inventory replacement or use-trigger bypass.
Other held weapons clear our flag; returning to fire preserves the deadline.
Death/down/disarm clear our flag, and menu/laststand weapon locks are separate.
Mystical Hands still changes lower/raise only. Charge input cannot pre-bank
while recovery, reload, switching or menus block it. Native action/animation
behavior needs a playtest; script lifecycle and generated variants are checked.
Damage audit: native fire is 1,600 direct + 2,200 inner / 700 outer splash,
then the existing per-target upgrade/tier/matchup/charge multipliers. The HUD
SUMS damage across crowd targets. Fire FX on survivors are visual, not a DOT.
Ordinary-zombie callback returns the calculated damage; no zero-damage branch
was found there. Panzer stock armor applies AFTER the HUD push, so that readout
can overstate actual damage. No damage or enemy-health balance values changed.
Full build VERIFIED 2026-09-09 01:39:13 Eastern: FF 172,362,880 bytes;
1,141 snapshot/repo/deployed inputs match and predate FF, fresh sound bank
174,624,640 bytes. Only established waived asset warnings. All dev/god flags
OFF. Fire cooldown, reload, Blink, ice-volley, arity and staff asset checks
pass; native post-shot interactions and animation feel await user playtest.


**Mage follow-up (2026-09-09):** Blink recharge multiplied by 1.5 at every
level BEFORE the existing Attunement scale: Lv1..5 base 12/10.5/9/7.5/6s.
Two-charge cap from Lv3 and sequential recharge/elite refunds unchanged.
First-raise animation notes already contain wpn_lightningstaff_1straise,
wpn_firestaff_1straise and wpn_waterstaff_1straise at frame 1. Added all three
aliases to tod_ports, backed by vendored staff_first_raise.wav (stock elemental
bow equip foley donor; actual Origins staff equip WAVs were not available).
No mesh/animation changes. Chain Lightning no longer spawns an unlinked
origin+48 FX host. It deals damage, starts FX only on survivors, and refreshes
one torso-bound effect per actor/viewer. A mirrored 2-bit ACTOR int field uses
0=off, 1/2=refresh; no clientuimodel bits or weapon registrations added.
CSC KillFX on refresh, death, shutdown and 1.5s expiry; suppresses late positive
fields on dead actors. GSC timeout/death clears the field and resets state.
Tests pass for all Blink levels and charges, actual client FX lifecycle with
independent viewers, arity and Lua layout. First-equip audio and corpse FX
still need native testing.
Full build VERIFIED 2026-09-09 01:25:07 Eastern: FF 172,364,160 bytes;
1,141 snapshot/repo/deployed inputs match and predate the FF. Fresh sound
bank; only established waived asset warnings. All three first-equip aliases
and tod_mage_chain_fx are present in the inflated fastfile. Both batches of
Mage fixes are built; native playtest still required. Dev/god flags OFF.

**Mage normal-run corrections (2026-09-09):** Removed the remaining server
Archmage HUD text row (ready bind + active label); the existing LUI full-bar
PRESS AIM BUTTON cue remains. Mana income and reads require the first
mage_arch card; locked bar state 3 forces zero and suppresses readiness.
Ability notifies encode -1 for locked and 0 for unlocked/cooling down. Both
Mage offhand tiles hide until their card, dim after charges are spent, and
clear inherited everHad flags on class changes. Cast unlock gates retained.
Lightning AND ice now use guidedMissileType=None for straight flight.
Lightning explosion shake and minimum view kick are zero across q0/q1.
Lightning idle/fire/ADS-fire/hold camera tracks were inspected: all static.
Optional reloads now have real reserve ammo (clipOnly=0, nonzero segmented
reloadAmmoAdd, ammo insertion at full 1.5s animation end). A Mage-only ammo
watcher restores the held staff to clipSize-1 plus reserve while NOT reloading,
switching or downed: shooting stays free and one round of space permits an
optional reload. Separate per-element clip/reserve names prevent cross-staff
sharing. Existing completion+interruption guards award 5 mana only after
Archmage unlock. Uses native reload/Speed Cola playback, not a fixed reward
sleep or a separate fake animation. Mystical Hands still affects swaps only.
Tests: actual GSC reload/replenishment helpers, Lua 5.1 HUD setters+full-widget
parse, Blink/fire-switch/ice-volley regressions and staff/asset/arity/Lua gates
pass. Native optional reload, Speed Cola and projectile/HUD visuals need play.
Included in verified 2026-09-09 01:25:07 Eastern full build; native testing
pending. All gameplay dev/god flags remain OFF.

**Normal playtest mode (2026-09-09):** User requests development and god
mode OFF for a real run. Disabled tod_god, tod_dev_money, tod_dev_doors and
tod_dev_altar in zm_tower_of_doom::tod_resolve_dev_flags. tod_dev and
tod_dev_maxed remain false; every gameplay dev/god flag is now false.
Normal money, damage/downing, door purchases, altar limits and progression
apply. Mage and the latest staff/Chain Lightning/Archmage HUD changes remain
available.
Script build VERIFIED 2026-09-09 00:38:15 Eastern: FF 172,356,864 bytes;
142 snapshot/repo/deployed inputs match and predate FF; all deployed dev/god
flags false. Fresh sound bank; only established waived asset warnings.
Ready for the user's normal playtest; not yet played.

**Archmage rainbow health bars (2026-09-09):** Active Archmages now cycle
six rainbow colors on their local HP bar and every viewer's party row. A
single server watcher sends a four-player mask to ALL players on changes
(100ms polling) and every 2s to hydrate late/recreated HUDs. Entity numbers
match the kit's existing health/state slots. No extra clientfield bits or
per-color network events. Inactive/dead/downed/disarmed/disconnected players
are omitted; animation is presentation-only and does not change form timing.
TodHealthTint.lua owns color on a parent element, separate from the original
fill's health/bleedout shader animation. Six 180ms transitions repeat through
one animation-completion handler; no UITimer. Downed red overrides rainbow,
then Archmage overrides local healing-aura green; expiry restores the proper
base tint. Local/party widget edits replace existing calls to respect the
large PlayerInfo closure limit. One notify subscription per widget, roster
rebind by actual clientNum, close stops the animation and closes its parent.
Lua 5.1 parsing passes for all four changed Lua files. Actual helper tested
with 256 controller/player/mask combinations plus color sequence, heartbeat,
rebind, down/revive, aura priority and close. Actual GSC broadcaster tested
for recipients, mask, change/heartbeat, down and disconnect. Native color
inheritance/appearance and co-op synchronization still need a BO3 playtest.
Script build VERIFIED 2026-09-09 00:33:47 Eastern: FF 172,356,864 bytes;
142 inputs match snapshot/repo/deployed and predate FF; TodHealthTint rawfile
packed, sound bank regenerated (174,624,640 bytes). Only established waived
asset warnings. Native visual/co-op testing remains pending.

**Chain Lightning target nerf (2026-09-09):** Additional chain targets now
follow Lv0..6 = 0/1/2/2/3/3/4 (user milestones: Lv2=2, Lv4=3, Lv6=4).
Owned Dark raises the cap to FIVE (six until the 2026-09-09 ceiling pass) via the existing tod_dark bit; mage_bolt is
now eligible in the normal maxed-domain Spire Dark pool. Direct hit, 50% chain
damage, radius, nearest-target selection, Panzer exclusion and no recursion
are preserved. GSC chain_targets and Lua DETAIL/DARK readouts agree. No new
registrations, clientfields or image assets. DARK_TEXT_ONLY[53] prevents a
missing-image registration; a Dark card without art uses the composite DARK
text layout instead of the misleading Ultimate +3 picture. Pause uses the
existing tinted plate. Asset lint parses this exception and requires both the
registration and composite-render guards; negative controls exercise each.
Script build VERIFIED 2026-09-09 00:23:22 Eastern: FF 172,360,704 bytes;
227 inputs match snapshot/repo/deployed and predate FF, fresh 174,624,640-byte
sound bank. Only established waived asset warnings. GSC count checks cover
Lv0..6, Dark and cap; Lua ladder matches; asset lint negative controls pass
(17/17), Lua/arity/domain checks pass. In-game target-count test pending.

**Staff handling and fire recovery (2026-09-09):** User clarified base swaps
should take 50% LONGER. Multiplied all 12 lower/raise fields on all three base
staffs by 1.5 and regenerated q0/q1. Normal lower+raise is now 0.375+0.600s
(previously 0.250+0.400s); Mystical Hands remains one third of each new timing.
Only those timing fields changed in the source GDT; charge, fire and reload
values remain intact. Fire's 1.43s post-shot window now watches the native swap
button and requests SwitchToWeaponImmediate() once if normal switching has not
started. This bypasses outgoing recovery/drop while keeping incoming raise;
engine selects the next held weapon, preserving PaP/ammo/q1 identity. No forced
swap without input, no intervention in charge-up or other weapons. Death,
disconnect, class disarm, next shot/change, menu/pause and downed state cancel.
GSC coroutine tests cover window expiry, held input, events and guards; native
button coverage and recovery cancellation still need BO3 testing. Build guard
checks recovery duration against fireTime and all six twin handling ratios.
Full asset build completed 2026-09-09 00:10:21 Eastern. Concurrent source
edits required a script relink; that attempt hit a sound-bank lock and was
rejected. With game/build processes closed, parked sound/zone under session
TEMP and regenerated it. Final build VERIFIED 00:15:42 Eastern: fastfile
172,358,656 bytes; 227 snapshot/repo/deployed inputs match and predate FF;
86 required animation/weapon/muzzle-FX assets packed. All script tests and
staff timing guards pass. Only established waived asset warnings. Native
post-fire switching and revised handling feel still need user playtesting.
User recovered from the earlier startup issue
on the UNCHANGED build; cost exceptions were real but did not prevent eventual
play. The included cost-table cleanup is not a proven fix for the initial stall.

**Startup weapon-cost overflow (2026-09-08):** Investigated the reported
launch stall in the unchanged 23:21 build; no fatal was established. Initial 23:33 log stopped at
ModLoad done with no fatal; retry 23:46 reached match startup and exposed
43 `Too many weapon costs added to weapon cost list` exceptions from stock
`_zm_weapons.csc::on_player_connect` / SetWeaponCosts. This is a SEPARATE
registry from the 235 weapon-asset ledger. The CSV held 304 distinct base/up
price keys. Removed exactly 33 unobtainable stock gun rows: 238 keys remain,
all 95 generated PaP mappings and every retained row unchanged. No weapon
assets were retired; GDT hashes are identical. Generator removes those rows
idempotently and checks the cost budget BEFORE any outputs are written.
`tools/verify_weapon_costs.js` gates every build, with a conservative table
budget of 240 (not a claimed native capacity). Its self-test catches the old
304-key failure and upgrade-key counting; generator double-run is identical.
Also fixed ice_side_shots comparing an undefined element to a string when a
mage fired a nonstaff; this was a separate potential runtime error, not the
observed startup cost exceptions. Ice/reload-mana tests pass. Rebuild/boot test pending
BO3 closure. Failed logs saved in the session temp folder.


**Reload mana (2026-09-08):** User requests a small mana reward for a full
successful staff reload. All three staffs now award 5 mana once per completed
reload, via mana_add (100 cap, no gain during Archmage). A reload_start arms
one attempt; stock reload notification plus IsReloading clearing confirms
completion past the ammo/animation tail. Fire, weapon change, sprint, melee,
new reload, class disarm, death and disconnect cancel pending rewards. Final
state guards also reject downed/menu/paused players and changed weapons.
HUD updates through the existing mana_push path. No new sound/toast spam.
`tools/test_mage_reload_mana.js` exercises actual GSC coroutine logic with
simulated native events: no early/double award, 18 cancellation cases, state
guards and cap pass. Native notification timing remains a playtest check.
Script build verified 2026-09-08 23:21:22 Eastern: FF 172,361,728 bytes,
138 script/UI/zone inputs match snapshot/repo/deployed and predate the FF.
Only established waived linker warnings. Completion/cancellation behavior
still needs confirmation in BO3.


**Ice volley correction (2026-09-08):** Ice was one native missile with
cosmetic flying icicles in the muzzle FX. `ice_volley_watch` now adds two real
missiles per ice weapon_fired event, using the exact fired variant/player via
MagicBullet (stock multirocket pattern). Symmetric +/-8-degree view-space fan;
center remains native. Side hits use full existing per-projectile damage,
splash and normal ice slow/PaP/matchup callbacks. Overlapping explosions can
increase damage to one target; this is not a damage-neutral cosmetic change.
No extra weapon registrations or ammo deductions. Custom 1p/3p muzzle FX each
remove 13 cosmetic icicle-model emitters, keeping the other flash particles;
real missiles retain the stock trail/impact. All generated ice twins use the
new muzzle FX. `tools/test_mage_ice_volley.js` passes 40 aim/variant cases plus
non-ice filtering; engine collision and side-hit damage need playtesting.
Full build verified 2026-09-08 23:16:59 Eastern: FF 172,363,328 bytes,
fresh all.sabs 174,624,640 bytes; 224 inputs match snapshot/repo/deployed and
predate FF; 89 required staff assets packed, including both new muzzle effects.
Only established waived asset warnings; prior Enfield checksum warning did
not recur. Runtime outer-bolt collision/damage still needs playtesting.

**Staff glow follow-up (2026-09-08):** Removed the 0.4s settle timer and
replicated-field FX callback. Local client weapon_change now kills the old
particles with KillFX and immediately attaches the held staff's aura. Same-
element q0/q1 swaps also replace it; death/disconnect/entity shutdown clean up.
The existing two-bit field layout is retained with no callback, so late server
snapshots cannot restore the previous element. Full build verified 23:07:03
Eastern: FF 172,209,344 bytes; fresh sound bank 174,624,640 bytes. 222 inputs
match repo/deployed/snapshot and predate FF; 87 staff assets packed. Runtime
swap/reload/sprint verification pending. Unrelated Enfield shot2 source-checksum
warning appeared; WAV exists/parses and bank was regenerated.

**Staff playback follow-up (2026-09-08):** User requests shoot-to-interrupt
reloads while keeping their animations, and sustained sprint motion. All three
staff sources/q0/q1 now use segmentedReload=1 with the existing zero-duration
reload end; clip-only ammo and reload clips retained. All three sprint-loop
xanims now looping=1 (previously 0). 31-frame sources have real motion and
matching end/start poses. Importer/build validator preserve both requirements.
Included in the verified 23:07:03 full build; runtime reload interruption
and sustained sprint playback still need in-game confirmation.

**Staff animation migration (2026-09-08):** User approved moving all three
staffs to Tower, with a remaining fire-shot "wings" correction. Fire head now
holds its actual assembled bind shape; all shot/ADS/charge vertices checked.
78 vendored clips, 45 slots per staff, all six q0/q1 twins migrated. Original
ammo/damage/glows/timings retained; Mystical Hands remains 3x faster; ledger235.
Full build VERIFIED 22:20:35 Eastern: FF 172,209,792 bytes, sound bank
174,624,640 bytes, 87 required assets packed and 222 deployed sources matched.
Corrected shared i_generic_lookup semantic to revealMap to clear a full-link
shader failure. Fire fix is built but not yet played.
tools/import_staff_animations.py imports; verify_staff_animations.py
gates every build; assets are self-contained. See docs/117 migration section.
No further approval is required to perform this migration/build.

**Historical test results:**
**Closer staff audit (2026-09-08):** test+map/docs/28 follow-up now includes
independent model/mesh/transition checks and damaged-pose negative controls.
Caught/fixed lightning branch translation origins in first raise, hold and
melee before another build. 48 clips pass; offline meshes inspected. Test build
verified 21:47:33 Eastern, 65 assets packed and 83 sources matched. Tower migration stays pending
fire/lightning visual approval; ice approval stands.

**Staff animation testing (2026-09-08):** Tower still uses `vm_freezegun_*`.
**Follow-up:** test+map/docs/28 corrects fire/lightning's doubled forward head
offsets (their raw roots are shaft-space, unlike ice's zero-origin head).
Same actual Tower models; updated tests normalize each head's authored origin.
Tower glows now ported into the test via _sla_staff_glow. Test build verified
21:47:33 Eastern; fire/lightning approval and Tower migration remain pending.

User APPROVED ice full alignment and requested fire/lightning tests before
Tower migration. test+map/docs/27 and tools/staff_element_tests.py add
original/animated pairs for each; melee cycles FIRE A/B, LIGHTNING A/B, ICE A/B.
Approved ice preserved. 48 clips / 1,636 frames checked; test build verified
20:49:14 Eastern with all new clips packed and 80 deployed sources matched.
User authorized Tower migration CONDITIONED on fire/lightning visual approval;
do not migrate yet, and do not request ice approval again.

**History:**
User requested copying Tower's actual ice staff into test+map and adding the
staff animations. Current test: ICE A original Tower q0; ICE B same shaft and
water/ice tip with 30 staff clips and 12/120 reload-test ammo. User reports B
incorrect and hold-melee failed. Now spawn A; press/release melee to compare.
Re-audit confirms original model/attachment fields and 42 assets match.
User now confirms A complete and switching works. B idle's cradle is below the
shaft and base appears missing. Idle-only correction was closer, but equip/fire
still displaced it. test+map/docs/26 and tools/staff_ice_alignment.py now apply
the correction across 24 full-pose clips and match A's resting placement with
a uniform translation. Same meshes/scale, A intact; test build verified 20:31:05
Eastern, visual test pending.
R5 arm-spike fix is confirmed and retained. Explicit attachment tag lost the
head; Tower's blank tag is preserved. R6 fire probes were NEVER BUILT and are
superseded. Missing shaft/head appearance is still awaiting visual confirmation.
Do not move a candidate into the tower until the user confirms its appearance.

**Mystical Hands experiment (2026-09-08; formerly Quick Hands):** User authorized three extra staff
variants and a registration guard of 235 (207 generated + 28 fixed), pending
boot testing. Mage-only ultimate, domain 56, max 1, no dark version, persists
through promotions. q0/q1 staff twins differ only in lower/raise timings:
q1 takes one third as long. Reconcile every retained primary, not only the
newest staff. Approved ultimate card and pause plate r56 installed (docs/123).

**Mage PaP (2026-09-08):** Additive primaries store every PaP level, including
I, by staff stem via `_tod_classes::pap_tier` / `pap_first_grant`. Never use
the shared `tod_pap_owned` latch or empty `up_suffix` to test staff packing.
Promotion requires the current tier's staff packed; older staffs retain their
level and newly added staffs start unpacked. Staff first PaP uses the existing
`zm_cwpap::giveWeaponRepacked` take/return presentation. See docs/114.

**Blink storage (2026-09-08):** One charge at levels 1–2, two maximum from
level 3 onward, locked at level 0. `blink_charges_now()` owns both cast and HUD
readiness; the tactical tile shows the charge count. Sequential recharge uses
the existing `tod_mage_cd["mage_blink"]` timer so elite refunds still apply;
spending the second charge preserves timer progress. See docs/114 and
tools/test_mage_blink.js.

Custom BO3 zombies map `zm_tower_of_doom` — a **classic tower map with a twist**,
set in the same cyber-city universe as the user's first map
(`c:\Users\jorda\Repositories\abandoned_cyber_city_zombies`). **That repo is the
knowledge base for this one** — read `docs/BO3_MAPMAKING_KB.md` (copied here into
`docs/`, canonical copy lives in both repos) FIRST, and consult the old repo's
`CLAUDE.md`, `docs/14_stock_api_verification.md` (stock-API traps ledger) and
`docs/16_community_techniques.md` before touching stock interfaces. Do NOT
re-learn lessons that map already paid for.

## HOW TO END EVERY RESPONSE (user, 2026-09-04)

**Every response that changed anything ends with a "What changed" block:
super basic, concise, plain language, easy to understand.** Three to six short
bullets at most: what was changed, where it lives (one file or feature name
per bullet, not a path list), and whether it is built / played / still
pending. No engine talk, no version numbers, no reasoning, no history. Write
it for someone who only reads the last five lines. **If the user wants more
detail they will ask** — the full explanation goes ABOVE the block (or in the
CHANGELOG), never inside it. Example:

```
What changed
- Gun HUD icons: audited. Nothing is broken; the set is one picture per KIND of gun, so Stoner and HK21 share one.
- New art request zip in Downloads asking for 20 per-gun icons on one sheet.
- Nothing in the game changes until that art comes back. No build needed.
```

## What this map is (user, 2026-08-17)

- **SPIRAL TOWER, 50 FLOORS — v8** (user 2026-08-20: "4 stairs per floor is
  way too much"): a solid core with an open-air staircase spiralling around
  its OUTSIDE — base arena at the bottom, 50 floors of **2 flights each**
  (`LAP_RISE 384`, top z=19200), rooftop arena (PaP; Mule Kick RETIRED
  2026-08-25) on the core's
  top. PARITY spiral: odd floors climb the E+N sides (NE mid landing, NW end
  landing), even floors the W+S (mirrored); doors/zones/lights/probes all
  parity-mirrored in the generator. 52 zones; buyable doors one per lap + roof
  + power (v10.4: 750 +60/lap cap 3000, roof 7500, power 750 — the price
  rides in the GENERATED `_tod_door_data.gsc`, so a price change is a
  -GscOnly build; the `.map`'s own `zombie_cost` is a dead CONSTANT 1000
  placeholder since v14.14 and must stay constant — see below). The prompt
  shows destination AND price; the price is read live at purchase, so after a
  party-size change the sign can be stale by design.
  **TRIGGERSTRING BUDGET — A STANDING CONSTRAINT, NOT A PAST BUG (v14.14).**
  `SetHintString` mints ONE PERMANENT engine slot per DISTINCT string, cap
  **250 per match**, never freed, shared with stock; overflow fatals with
  `BG_Cache_GetIndexInternal` and **blames whoever registers NEXT**, so the
  reported site is never the cause. The map sits at **140/250**. The Aetherium
  hint pack routes on hint TEXT (`string.find` in every `is*Hint()`), so
  `SetHintString` is its ONLY input channel — every new interactive object with
  a varying prompt spends permanent slots. Two rules paid for in blood:
  (1) **never interpolate a many-valued runtime value into a hint** — a
  re-stamp keyed on party size is fine on ONE trigger (≤4 strings) and fatal
  across 53; (2) **count DISTINCT STRINGS to prove a fix** — v14.3's flatten
  ran too late to do anything and its dev print still reported success, because
  it proved the loop executed rather than that a slot was saved. Free lanes:
  constant strings, `IPrintLnBold`, clientfield → LUI. LUI `SetText` is a
  DIFFERENT cache (cap 2048) and is safe.
  **BOTH RULES ARE NOW MECHANICALLY CHECKED** — `tools/lint_tod_hints.js` runs
  on EVERY build including `-GscOnly` (a reworded hint is exactly the GSC-only
  change that skips every other gate). It counts DISTINCT STRINGS (83
  tod-authored as of v14.58; the 140/250 figure above includes stock's share,
  which no tool here can enumerate) and FAILS on any interpolated hint that has
  not declared how many strings it can mint. `lint_tod_hints_selftest.js` breaks
  the map seven ways and requires a catch on each — it caught the lint itself
  reading `TOD_NOUNS` with a bare `indexOf` that still matched a RENAMED table.
  **CURSOR-HINT ROUTING — WORDING DECIDES WHICH CARD THE PLAYER SEES (v14.58).**
  The kit picks a prompt card by pattern-matching the hint TEXT, so a wording
  choice is a UI choice. It shipped wrong for months: the wall-buy arm was
  `"[Cost:" in the text` AND `getCursorHintImage() ~= ""`, and **that image
  guard never fires** — so every PRICED NON-DOOR interactable (ammo crates, the
  Heavenly Gift Altar, CALL EXTRACTION, every spire buy) drew `PromptWallBuy`
  and its hardcoded description **"Wall Weapon"**. Doors escaped only because
  the door keyword excluded them one line earlier. Two GSC files carried
  confident comments reasoning from that dead guard — *a guard nobody has
  watched fire is not a guard*. The router is now ONE `classifyHint()` returning
  exactly one state, arm order irrelevant; WallBuy/MysteryBox/GobbleGum have no
  arm at all (this map has none of those three). **Every custom prompt must lead
  with a NOUN listed in `TOD_NOUNS`**, which is claimed before any generic
  keyword test — that is what lets the ammo crate say "Pack a Punch $5000"
  without landing on the PaP card. Hint grammar, parsed by `PromptDefault.lua`
  into a title band + two detail lines + price + footer:
  `Hold [btn] ^5<TITLE>^7 - <detail> / <detail 2> ^2[Cost: N]`.
  **THE FOOTER KEY IS ENGINE-RESOLVED (v16.29, 2026-09-02, docs/69).** Every
  `Prompts/*.lua` footer is ONE line, `Hold ^3[{+activate}]^7 <verb>`, set
  through that card's `SetFooter` — the kit's hardcoded literal `"F"` told
  every pad player and every rebinder the wrong key for months. NEVER write a
  key name into a prompt or a menu: the engine expands `[{+bind}]` tokens in
  LUI text (proof: the "HoldX" transcription of v14.58, and every stock hint).
  The pause menu's UPGRADE CARDS legend is the live-bind readout AND the probe
  for bind names other than `+activate`. **The card-panel hint plates draw the
  live binds too since v16.32**: blank frame `i_tod_hint_frame` + token text
  lines (`USE_HINT_FRAME_ART` in both card menus, ONE writer each —
  `ShowSwitchPlate` / `CardHint`); the re-baked keyed plates are the flag-off
  look. **THE COPY IS ONE LANE PER ACTION SINCE v16.84 (docs/88) — DO NOT ADD
  A SECOND.** Three individually-defensible changes (v16.32 split the plate to
  two lines, v16.57 swapped in the offhand pair, both kept a `D-PAD` tail) left
  THREE plates, FOUR lines and SEVEN key names on screen for a two-button
  decision, with LOCK said twice and no line ever saying which card a key moved
  to — user 2026-09-03: *"our last update made it more confusing and less
  simplified by adding so much to look at"*. The plates now read
  `[tac] < SWITCH > [lethal]` and `HOLD [jump] TO LOCK`, and the pause legend
  says the same. **A menu that accepts eight inputs must still ADVERTISE one**
  (stock's "Hold [X] To Buy" never lists alternatives); melee, reload, WASD,
  the stick and the d-pad all still work unadvertised. The offhand pair is the
  one named because it is read ABOVE the station's device gate, so it is the
  only pair correct on every device in every place the panel opens. **AND WHEN
  A LANE IS RETIRED, GREP EVERY READOUT THAT NAMES IT** — the pause legend
  advertised `+attack`/`+speed_throw` for a day after v16.57 removed fire and
  aim as menu inputs, so players pressed fire, saw nothing move, and concluded
  the menu was broken.
  **THE DISPLAYED CONTROL SET IS PAD OR KEYBOARD, NEVER A THIRD (v17.55,
  user 2026-09-04: "the UI should only show dpad options or KBM. Two sets
  only").** Glyph-vs-keycap is chosen by ONE reader,
  `CoD.TodKeycap.PadDevice()` = the d-pad latch OR the `[{+bind}]` expansion,
  which follows the LIVE device. ⚠️ **THAT TEST DID NOT FIRE FOR ITS FIRST
  THREE VERSIONS, because this file and the memory both had the MECHANISM
  wrong** (corrected v18.47, 2026-09-08, from a screenshot): on a pad the
  engine expands a bind into a **BUTTON ICON**, not the letters `LT`, so
  matching on the SPELLING never matched and every pad player got keycaps —
  filled, by the keycap's own text fallback, with the engine's LT / RT / A
  pictures. That is the third set, and pressing the d-pad hid it by latching
  the device a different way, so it survived every playtest. The test is now
  STRUCTURAL — `IsPadGlyph`, any byte outside printable ASCII — which is valid
  on ANY token (the A/B/X/Y ambiguity is a property of NAMES, not icons), so
  the lock plate is covered too. All three surfaces call PadDevice; never
  branch on `CoD.TodPad` directly again. **And the keycap fails closed**:
  `paint` refuses a glyph expansion rather than drawing it as text, in the
  widget AND in each menu's fail-safe stub, because the stub's fallback is
  where the icon actually got in.
  The d-pad latch (`tod_input_pad` / `CoD.TodPad`) is otherwise ONLY the input
  gate — since v16.84 no control string branches on it, so it never decides
  what art or wording is shown. "Detect the
  device at class lock-in" cannot work: jump and use exist on both devices, so
  the d-pad is the only device-proving input the server ever sees. **CORRECTED 2026-09-03 (v16.81): it is NOT a proof — `players/bindings_0.cfg` binds keyboard 1-4 to `+actionslot 1/2/4/3`, so a KBM player tapping 3 or 4 sets `tod_input_pad`; the latch now gates the STATION lanes only and round events keep every lane live for every device. Read `players/bindings_*.cfg` before any claim about what a key does.**
  **NO wallbuys** (user: "I never asked for those").
  **PERKS = the 9-machine random scatter** (`_tod_perk_scatter.gsc`): all 9
  machines (Jugg/Speed/QR/Stamin-Up/Widow's/Death Perception/DoubleTap/PhD/
  WISP TEA — v14.16 2026-08-30: Deadshot RETIRED for the BO7 Wisp Tea, a
  vendored WetEgg module on specialty_nomotionsensor, `_zm_perk_wisp_tea.gsc`)
  park at the base N wall in the .map, scatter to random pads at load and
  reshuffle every 4 rounds (v10.3; was the round after each Panzer), never
  onto the same floor; pads = **the 8 breather pads ONLY**
  (2 per balcony × floors 10/20/30/40) **plus ONE base pad where QUICK REVIVE
  is pinned** (v6.9 solo carve-out:
  ⚠️ **THE ROSTER SIZE IS LOAD-BEARING AGAIN — COUNT IT, DON'T QUOTE IT.**
  The v14.56 perk cap (base 4, +1/Lv by the **PERK SLOTS** domain id 40, max 5
  = the roster) was retired in v16.80 on the Workshop thread's verdict
  ("wasting these awesome upgrades on a DAMN PERK SLOT") — and **v17.3a
  (2026-09-03) RESTORED BOTH.** `level.perk_purchase_limit` is **4** again
  (`zm_tower_of_doom.gsc`, then re-asserted from `TOD_PERK_SLOT_BASE` with
  `level.get_player_perk_purchase_limit = &perk_slot_limit` in
  `_tod_upgrades.gsc`), and the domain is **LIVE**: a universal A-band card,
  max 5, its `add_domain` call real, `CARD_SLUG[40]` set and the three card
  images zoned. **So a tenth machine IS a lockstep edit** — 4 + 5 must equal
  the roster or the last perk is unbuyable.
  ⚠️ **THIS BLOCK SAID "the domain is retired" FOR FIVE DAYS AFTER THE
  RESTORE, and so did the comment above the Lua's own row 40** (both corrected
  2026-09-08, after the stale text sent a session hunting for a domain that
  was sitting in front of it). A RETIREMENT NOTE OUTLIVES THE RETIREMENT more
  reliably than anything else in this file: read the `add_domain` call before
  believing one, here or anywhere. Count
  `zm_perk_machine` entities in
  `map_source/` for the SIZE, and identify WHICH perk each one is by the
  `model` on the perk-park entity — **NEVER by the specialty string**, which is
  just an engine slot a custom perk got hung on, and which has rotated
  (`specialty_electriccherry` is PhD Flopper, `specialty_combat_efficiency` is
  Death Perception, `specialty_nomotionsensor` is Wisp Tea; and
  `specialty_doubletap2` carries a DIGIT that a `specialty_[a-z_]*` grep
  truncates into the real-but-wrong `specialty_doubletap`). A perk-name grep
  over the `.map` reports PhD and Death Perception ABSENT — all four readings
  wrong. Every prose list of this roster, including the one above, has
  been stale at least once (the user caught a "10 perks" claim on 2026-08-31
  that came from this file naming a retired Mule Kick). the first-breather pin costs 15,750 pts of doors to
  reach (lap 10 under the v9.43 prices), leaving solo with no self-revive for ~10k pts. Granting the perk early
  is NOT an alternative — the stock vending trigger refuses a buy while the
  player holds the perk, `_zm_perks.gsc:545`). 9 pads / 9 machines — every
  pad filled (the "one empty pad" era ended when PhD joined the pool,
  2026-08-25).
  Breathers (floors 10/20/30/40) are **WALLED, OPEN-TOP LOUNGES** (v13
  2026-08-28, docs/42; **the roof was REMOVED in v13.6** — user: "you cant
  look up and see the tower", so the lounge is walls + sky, and an earlier
  version of this line still said "grew ROOF + WALLS" for three days): the
  544×576 deck kept its footprint and grew WALLS (56 sill / open window band
  with glowing mullions, `clip_player` so bullets pass / lintel / a glowing
  cap band on the wall heads), ONE THEME COLOUR each — 10 blue, 20 green, 30
  orange, 40 gold — and the TELEPORTER moved onto its own open-air SPUR (gated
  doorway → 320 gantry → 288×288 floating pad). **v16.7 polish (2026-09-01):**
  a lit `_tinted_edge` panel in the window bay behind EVERY machine (the
  whole perk wall is one), corner finials, a floor inlay ring with a spoke to
  each amenity, pad pylons, two gantry hoops, an under-glow band + pendants
  under the slab, four accent lights, four looping ambient FX per lounge
  (`_tod_atmosphere::lounge_fx`) and a per-player first-arrival chime
  (`tod_lounge_arrive`). All brushwork, zero models; every knob is a `BR_*`
  constant in the generator's v16.7 block.
  **THE AMMO CRATE IS ONE CONTRACT (v17.38, 2026-09-04, user: "master ammo
  crates so we dont ever have to touch them again")**: facing (`CRATE_YAW_*`,
  front = yaw + 90 — the tower crates were authored BACKWARDS until v17.37),
  occupancy (`crateBox()`, the measured box rotated to the real yaw) and the
  trigger (`CRATE_TRIG_OUT` 56 in front, `CRATE_TRIG_R` 72, EMITTED into
  `_tod_breather_data.gsc` and read back by `_tod_ammo_crate::spawn_trigger`)
  all derive from one origin + yaw in the generator, for EVERY crate — base,
  breathers, crown, spire arena/shelves/hubs (94 `ammo crate body` brushes,
  zero script clips). A trigger ON the model origin was the "only at a
  certain angle" bug: an 18u band. Never add a crate any other way.
  Furniture is one-per-wall (station N, PaP W, crate E, perks S) and rides in
  GENERATED `_tod_breather_data.gsc` from the generator's `BR_FURN` table,
  which ASSERTS every trigger pair ≥ r_a+r_b+64 (the old PaP↔crate 38u rim
  gap mis-sold 5000-point buys; v16.7 nudged the PaP 24u and the station 20u
  onto their panels' axes — read the table, not this line, for coordinates).
  THREE risers per lounge (v13.2: the third
  sits mid-gantry ON the teleporter spur at even (-704,-1120), y derived from
  the arrival point so the ~165u materialize-clearance rule holds by
  construction; v10.12 added the first two after the v6.9 zero-riser
  experiment); the S riser guards the spur mouth from the room side.
  **Tron Grid look — DISTRICTS since v16.11 (2026-09-01, docs/64, artifact
  "Cybercity Tower Facelift")**: the spiral is FIVE colour districts of ten
  floors, `DISTRICTS` in the generator — blue 1-10, green 11-20, orange 21-30,
  gold 31-40, RED 41-50 — each lounge caps its district in its own colour, the
  core band per lap takes the district hue (five stacked bands from the base),
  treads alternate `_tinted`/`_tinted_edge` per floor for rhythm (parapets stay
  plain hue: a `_tinted` parapet is a DECK to the lint). The old 8-hue
  `PALETTE` cycle survives only behind `FACELIFT = false`. Same switch gates
  the DOOR GATES (post + lintel + sill per lap door, slab in the district it
  opens into; `_tod_doors.gsc` slides the slab into the core on purchase,
  `TOD_DOOR_SLIDE`), the BASE PLAZA (floor traces spawn → first door / power
  hall, core foot ring, cyan pilasters + cornice on the arena walls) and the
  TELEPORT BAY colour code (each up pad = its destination lounge's colour,
  LOCKSTEP with `up_orgs` order in `_tod_teleport.gsc`). Pre-facelift look:
  edge-lit `_tinted_edge` floors cycling 5 colors, navy
  base + glowing inlay ring, PaP-material roof floor. **THE SKY IS OURS
  (v17.71, 2026-09-05, docs/104)**: a self-authored synthwave neon-grid
  metropolis rendered by `tools/gen_tod_sky.js` (seamless by construction)
  and wired by the four blocks in `source_data/tod_skybox.gdt`
  (`skybox_tod_cybercity` + `tod_ssi_cybercity`, an ssi clone of Nastian's
  miami_night with ONLY skyboxmodel changed). Miami night (Nastian pack) was
  the sky v1–v17.70 and again v17.78–v17.80 for the yellow-cast A/B (the
  cast was the SUN VOLUME height, docs/107 — never the sky); the cybercity
  pair returned in v17.81 with the fsi, spawn light and light tint left at
  their published values. A sky change is a FULL build; the exposure knob is
  `SKY_GAIN`. **The tower has NO fog** (`apply_fog` calls `fog_off()` on the
  tower; only the spire fogs), so the sky is ~a third of every screen. Music (`_tod_atmosphere` owns the channel):
  **BANDS BY FLOOR** (v9.46) — the track changes as the party climbs past the
  breathers: 1-9 "Password Infinity" (Evgeny Bardyuzha), 10-22 "Cyberpunk
  Futuristic City" (lnplusmusic), 23-36 "Cyber Relay" (Psychronic), 37-50
  "Cyber Eclipse" (bykenneth) — the three climb tracks are spread EVENLY over
  floors 10-50, so only the floor-10 change lines up with a breather. The PANZER's
  track ("Data Spike" — Psychronic) always overrides, and resumes into whatever
  band the party has climbed into; the FINALE track ("You See Big Girl" —
  Hiroyuki Sawano / Gemie) outranks everything and IS the run's clock. One
  `add_music_band()` row per band in `register_music_bands()` — the bands are 10/23/37
  (was 20/30/40, then 10/30/40, evened out 2026-08-25). Rows must stay in
  ASCENDING floor order — band_alias() walks the array backwards. Credit all SIX
  before publish (full list: CREDITS.md). TELEPORTERS (v9.37/v10.3-4): four
  breather pads (0.8s charge, 30s cd) down to a base arrival pad + four base
  UP pads gated on each breather's own lap door — five porters at spawn; band table, wav rules
  and the loudness-matching recipe in sound_assets/tod/music/README.md.
  Bosses: Panzer every 5th round (music + luck-to-last-hit), Rogue Protector
  WAVE every 3rd round, wave size = int(players×round/3+0.5) CAPPED at the
  concurrency roof 8, debt SET not summed (v10.4). REWARDS (v14.5): every
  ELITE (Protector/Reaver/Hound/Sprinter) pays a flat 500 to the KILLER ONLY,
  ×double-points ×BOUNTY (`grant_elite_reward`, one shared TOD_ELITE_PTS);
  the PANZER alone keeps the 1000 team-wide boss jackpot. **Power switch at the BOTTOM.** The generator prints the live
  world-brush / entity / lap counts on every run — read them there rather than
  trusting a number copied into this brief. LED bake is the ceiling; generator
  `PARA_EVERY` is the bake-budget knob.
- **5 CLASSES × 3 TIERS** (`_tod_classes.gsc` `register_gun`; docs/25 —
  CLASS TIERS, 2026-08-22): **the MAGE is the fifth and it is LIVE** —
  `TOD_MAGE_ENABLED` in `_tod_mage.gsh` is **1**, and `TOD_CLS_COUNT` is
  DERIVED from it (`4 + TOD_MAGE_ENABLED`), so the draft card count cannot
  drift from the flag. Exactly one other literal exists, `MAGE_ENABLED` in
  `tod_class_select.lua`, because Lua cannot read a GSC define, and
  `build_map.ps1` Dies if the two disagree. The mage is the map's ONE
  **ADDITIVE** class (docs/114, v18.30): a promotion ADDS the next staff and
  KEEPS the ones below it (`level.tod_classes["mage"].additive`), so "tier 3"
  is a mage holding **lightning + fire + ice at once**, not an ice mage — and
  because they are held together the generator marks tiers 2/3 `flat: true`
  (NO TIER_DPS normalization) and `_tod_mage_elements` applies the same
  step to EVERY staff in script instead. ⚠️ **THAT STEP IS NO LONGER THE GUN
  LADDER AND MUST NOT BE "FIXED" BACK TO IT (v18.51).** It mirrored TIER_DPS
  (1 / 1.5625 / 2.4414) until 2026-09-08, when the user asked for a CURVE —
  *"medium ranked at early mid game, late game High ranked and Very late game
  OP"* — and ranked against the other four classes the old ladder had it exactly
  inverted (rank 2 at tier 1, rank 4 at tier 3). It is **0.92 / 2.00 / 3.95**
  now, so the mage's two promotions are the biggest power steps in the map and
  its floor-30 tier card is the most valuable card any class can draw. VERY LATE
  is not on the ladder at all — there is no tier 4 — it is carried by three
  mage-only multipliers that grow with depth: ARCHMAGE uptime (kill-fed via
  `TOD_MAGE_ARCH_MANA_KILL_LV`), the per-staff card ladders, and CHAIN
  LIGHTNING's arc density. Read the defines, never this line. The mage's
  secondary lookup returns an empty name/stem and `give_secondary`
  removes carried sidearms before granting nothing (v18.48; the old MR6
  placeholder was actually being given, then PaP'd into Death and Taxes).
  No sidearm or grenades: the loadout is three staffs, the LETHAL button casts
  HEALING AURA and the TACTICAL button is BLINK.
  **Ability rules (v18.49):** HEALING AURA needs its first card;
  level 0 has no charges and cannot cast. BLINK obeys its cooldown even with
  god/money/dev flags. Its HUD dims immediately on casting, and stock grenade
  counts/icons cannot overwrite mage tiles. The Rogue Protector's fallback
  damage callback delegates to `upgrade_damage_cb`, so it shares Insta-Kill's
  elite boost and staff multipliers instead of maintaining a partial copy.
  Staff damage uses `staff_mult` / `victim_family` in `_tod_mage_elements`:
  lightning owns the horde, fire owns Protector/armored sprinter, ice owns
  hellhound/Fury, and — since v18.52 — **lightning also owns the PANZER, which
  it was the map's worst answer to until that build** (user: *"Best weapon
  against panzers should be the lightning staff"*). ⚠️ Every prose line in this
  repo said "deliberately the worst Panzer answer in the map" and they are all
  now the OPPOSITE of true; the tax was an implementation reading that left the
  Panzer with no right answer at all. **v18.53 THEN MADE THAT ONE RULE FOR
  THE WHOLE CLASS** (user: *"what makes him OP is that his best staff is always
  top 3 against the weakness enemy"* + *"you can place him right under death
  machine DPS"* — the same instruction twice). **THE CONTRACT IS TWO STATES** (v18.54, user:
  *"his maxed out fire blast should be 1 against their weakness. Easily"* — the
  first pass folded the maxed card INTO the rank-3 target, so six cards bought
  nothing but parity). **UNINVESTED, the right staff lands RANK 3 among the five
  classes' PRIMARY weapons, just under the Death Machine; with that staff's own
  card MAXED it lands RANK 1, and not narrowly.** So the mage is never worse than
  third to anything and is first at whatever it has paid to specialise in —
  breadth by default, peak by investment. Every other class has an enemy it is
  helpless against; this one has none, and has one it is best at. **Lightning has
  no damage card**, so its growth lever is ARCHMAGE (×3.2) rather than a staff
  card, which is why the Panzer figure pinned "right under death machine" is the
  UNINVESTED one. ONE CONSTANT PER FAMILY, and they DIFFER because the staffs do
  (a shared 2.00 left fire and ice at rank 4 and lightning at rank 5):
  `TOD_MAGE_VS_HORDE` 1.30 / `_FIRE_VS_ARMOUR` 3.61 / `_ICE_VS_BEAST` 4.96 /
  `_LIGHTNING_VS_PANZER` 5.60, against `_OFF_FAMILY` 0.45 and `_OFF_PANZER`
  0.40. **Retune by RANK, never by copying one onto another.** They look large
  beside a gun's because every gun figure they are calibrated against carries the
  engine's ×3 head crit and a splash hit takes none — about a third of each is
  buying back a crit the weapon cannot land. **The Warden King is a Panzer**, so the spire's climax is a mage fight
  now. Read the constants
  there for the current matchup rates. Speed **1.00** — read `class_speed_base()`, and
  note a block comment in `_tod_upgrades.gsc` said 0.85 for a day after the
  user raised it. The other four:
  SKIRMISHER **MAC-10 → MP5 → MP7** (speed 1.1),
  ASSAULT **Enfield → Krig 6 → AK-47** (0.9), HEAVY **Stoner 63 → HK21 →
  Death Machine** (0.75), SLASHER **Combat Knife → Wakizashi → STORMBREAKER
  (Leviathan port)** (1.0 — the SKIRMISHER is the map's fastest class, swapped
  with the slasher v14.29 2026-08-30 on the user's "melee is too fast"; read
  `class_speed_base()`, never this line, before quoting a number).
  Once the class gun is PaP'd **AND the player's own climb high-water clears
  the FLOOR GATE** (v14.35 2026-08-30: floor 10 for the promotion into T2,
  floor 30 for T3 since 2026-09-02 (was 20; docs/72) — `tier_floor_ok`, fed by `_tod_gauge::floor_reached`, a
  per-player alive-only maximum that only ever RISES, so you may take the
  promotion anywhere once you have earned it; NOT waived by `tod_dev`, and the
  spire grant stamps `mark_top_reached` rather than being exempted; the player
  is TOLD — v14.39: the card is DEALT AND SHOWN **LOCKED** in its normal right
  slot (so a blocked deal that rolls the tier card is effectively ONE card —
  the user's explicit call over a free third preview slot); the roll asks
  `tier_card_ready_but_for_floor`, only the RIGHT slot is ever lockable (focus
  starts left, so a dead panel is impossible by construction) and a LONE locked
  card is never dealt; the refusal is enforced at `wait_for_choice`'s single
  `want`->`sel` commit and is AUDIBLE. The `TIER 2 AT FLOOR 10` BADGE sits under
  that locked card, or in the panel's top-left gutter (the exact mirror of the
  luck badge slot) when no card is dealt — never both — whenever the floor is
  the SOLE blocker
  (`tier_floor_pending` → the zero-bit `tod_upg_tier_need` eventstring; art
  `i_tod_tier_gate_2|3` behind `USE_TIER_GATE_ART`, docs/50, LUI text is the
  fallback), and the pause CLASS TIER row now shows from tier 1 with the
  requirement in `DETAIL[24].act` — LOCKSTEP: the floor numbers are copied into
  that Lua (the row text AND the `TIER_FLOOR_TO_TIER` floor->tier table that
  picks the badge strip — floor/10+1 broke the day T3 moved to 30, docs/72)
  AND baked into the badge art. Since 2026-09-02 two FREE in-world toasts
  (`tier_gate_toasts`, IPrintLnBold, once per tier) also say it: on PaP below
  the floor, and on clearing the floor. **The PaP prompt is a DEAD lane for
  this and any other custom copy** — `ZMCursorHintNew.lua`'s `isPAPHint` routes
  any hint containing "pack"+"punch" to a static card that never reads the
  string, unless a `TOD_NOUNS` entry claims it first; see CURSOR-HINT ROUTING
  above), 20%
  (v9.42; was 10%) of card deals
  (dev 100%) carry a TIER card (right slot, never auto-locked; **v16.56: a FULL
  luck bar (100) + FULL eligibility incl. the floor gate = dealt 100%**,
  `tier_card_roll` is the one owner on both deal paths): new gun at
  its level-0 form, every GUN-scoped domain reset, class-scoped domains kept
  (the v14.12 list in the upgrade bullet below — never enumerate it here,
  it has drifted twice; TIER_SAFE in the Lua is the mirror). Guns are GENERATED by `tools/gen_tod_twins.js` (ladder table, TIER_DPS
  normalization, never-shrink clips, altWeapon blanked on every form —
  audit it per build) under a 223-registration guard (`LEDGER_GUARD`, raised 200→220→223; 223 is the figure the map ships at with ZERO headroom — map 1's ~230 ceiling).
  Every gun: LOC_NORM 3.0, move 1.0, recoil ×1.15, ADS ×1.20, PaP = +25%.
  **HEADSHOTS ARE 3× FOR EVERY CLASS** — LOC_NORM is the whole story and script
  supplies no per-class ratio. An ASSAULT-only 4× shipped for exactly one build
  (v10.14) and the user reverted it after playing it (v10.16); the recipe for
  bringing it back is in the comment where `class_hs_scale()` used to live in
  `_tod_upgrades.gsc`. Differentiation comes ONLY from the HEADSHOT domain.
  Per-class weapon knobs live in the generator: `CLASS_DAMAGE_MULT` and
  `CLASS_RESERVE_MULT` apply to the **T1 gun only** — the higher tiers are
  normalized FROM the tuned T1, so a class knob propagates by construction and
  scaling them too double-applies it. **READ THE LIVE VALUES OUT OF
  `tools/gen_tod_twins.js`, never from this line** (2026-08-30: as of v14.33 it
  is skirmisher 1.071225, heavy 0.81, assault 1.10 — the skirmisher took two
  −10% cuts that day and will move again).
  This brief said "skirmisher 1.15, heavy 0.90" for an unknown span while the
  constant held 1.3225 / 0.81. Note 1.15² = 1.3225 and 0.90² = 0.81 EXACTLY:
  it recorded the figure for ONE application and never followed the doubling
  when each knob was applied a second time. **A brief that names a constant and
  quotes a number is a second source of truth that nothing regenerates** — name
  the constant, point at the file, and quote a value only with a date on it.
  `node tools/verify_armory_constants.js` catches this class of drift for the
  armory page; nothing yet checks this file.
  **SECONDARIES ARE COUPLED TO THIS KNOB BY DEFAULT** — every skirmisher sidearm
  is capped at `PRIMARY_T1[cls].dps × SEC_CAP_REL[tier]` and sits exactly on that
  ceiling, so moving the class knob moves the shotguns too. That was intended for
  the 2026-08-25 "primaries and secondaries" buff and wrong for the v14.32/33
  primaries-only cuts, which is why `CLASS_SEC_CAP_MULT` now pins the ceiling to
  an ABSOLUTE value. Pin, never derive from something that moves.
  Only the PISTOL (MR6) keeps a script damage multiplier (×9.6 base,
  ×5.76 PaP — the PaP form took a 40% nerf 2026-08-23).
  Move speed is keyed on the CLASS (`class_speed_base()`), not the gun, so it
  survives any roster swap. Sound aliases for all class guns are GENERATED by
  `tools/gen_tod_sounds.js` — it reads each GDT for the alias names it
  actually references (guessing from wav names is wrong in both directions)
  and skips fire families a gun lacks (the Stoner has no trig_pull). Game-start CLASS DRAFT (`_tod_class_select.gsc`
  LUI, 30s, random on timeout) + hold-USE stations at the base (moved WEST of
  the door trigger — overlap bug); switching swaps the primary, per-player
  upgrade levels persist.
- **THE TWIST — endless rounds:** there is NO pause between rounds. The moment
  the last zombie of a round SPAWNS, the next round starts — it should feel like
  the round never ended. Implemented in
  `scripts/zm/zm_tower_of_doom/_tod_endless_rounds.gsc` via the stock overridable
  pointers `level.round_wait_func` (wait for zombie_total==0, i.e. all SPAWNED,
  not all dead) + `level.zombie_round_change_custom` (no fanfare stall) +
  `level.func_get_delay_between_rounds` (returns 0).
- **Zombie speed curve** (`_tod_zombie_speed.gsc`): SPRINT animation from
  round 1 at reduced rate (floor 0.8 after live test — 0.5 read as broken),
  linear to full sprint at `TOD_ZSPEED_FULL_ROUND` (**18** as of 2026-08-29;
  7 -> 10 -> 12 -> 15 -> 18 across four user retunes, and that number is the
  end of this lever — see the block comment on the define; THIS BRIEF SAID 15
  for a week after the code said 18, so read the define), then
  `TOD_ZSPEED_STEP`/round after it, LINEAR and uncapped (**0.21%** as of
  v18.2 2026-09-06, user "lower that by twenty five percent"; 0.35 -> 0.28
  2026-08-26 -> 0.21). 1.5s keep-alive sweep re-asserts
  gait+rate (one-shot overrides decay — map 1 lesson). Spawn trickle 0.8×
  stock, floor 0.3s.
- **Perk power-on glow** (`_tod_perk_lights.gsc|.csc`, ported from map 1):
  server sets the `todPerkGlow` clientfield when "power_on" flags; client
  PlayFXOnTag's the colored aura (server-side PlayFX does NOT render). FX =
  map 1's self-authored recolors, sources in repo `share/raw/fx/acc/light/`.
- **Perk loose change** (`_tod_perk_scatter::loose_change_watch`): stock BO3
  prone-in-bump-area reward, 100 points + purchase sound, first player per
  machine per match; no purchase or power required. The existing bump follows
  each move. `level.tod_scatter_change_claimed` is keyed by the same stable perk
  key as the machine roster (one machine per perk), never by pad or player;
  shuffles, deaths and joins do not reset it. Do not also enable stock
  `zm_perks::spare_change()` or rewards would have two independent owners.
- **UPGRADE TOWER** (`_tod_upgrades.gsc`): events at rounds 1 (post-draft),
  4, 8, 12… (dev: every round) — the world pauses, each player picks 1 of 2
  rolled options (**43** live domains as of 2026-09-08 + the TIER card × rarity
  REGULAR/SUPER/ULTIMATE = +1/+2/+3
  Lv; ids run to **55** — `domain_id()` and the Lua tables are
  KEY-KEYED, so a removed domain's id STAYS mapped and only its `add_domain`
  call goes. **NEVER QUOTE THE COUNT OR THE RETIRED-ID LIST FROM THIS LINE** —
  both have been stale here more than once, most recently naming PERK SLOTS as
  retired for five days after v17.3a restored it. `node
  tools/verify_armory_domains.js` prints the live count, the persist count and
  the highest id in one second and is the only figure worth repeating). v14.11 rebalance (2026-08-30): heavy = the TANK (new VITALITY
  id 38 +10HP/Lv ×5 scope-class, new RECOVERY id 39 regen-starts-sooner ×3;
  REGEN and assault BACK ARMOR gone, MOBILITY capped 5); slasher trimmed
  (CLEAVE max 3, no SPRINT ARMOR, DR capped 5 via the bonus_max-as-override
  lane); RUN AND GUN pays free shots AND bonus damage while moving on ONE
  stage table (v16.50: 5 levels, 16/28/38/46/52% — LOCKSTEP duplicate
  constants across _tod_upgrades/_tod_runandgun plus DETAIL[23] — change all
  three; read `TOD_RNG_PCT_L*`, never this line); MOMENTUM
  removed, SECOND WIND is the MP5's unique (MP7 keeps only ADRENALINE).
  v14.12/13: HEADSHOT + SCAVENGER persist through promotions — SCAVENGER
  for the ASSAULT ONLY (set_scope's scope_class lane, v14.13;
  domain_survives_tier is the one authority). The pause reset badge is
  SERVER-COMPUTED: sync_max() packs a survives bit into every tod_upg_sync
  max arg (+100, int-packed — no 4-arg LuiNotifyEvent exists in-tree);
  TIER_SAFE in the Lua is only the nil-fallback now. Persistent set:
  DR/LUCK/SPRINT/SPRINTFIRE/SPRINTARMOR/BACKARMOR/VITALITY/HEADSHOT/
  SCAVENGER(assault).
  **CARD ART CARRIES THE NUMBERS BAKED IN, so a domain retune is not finished
  until the card is re-baked** — the card is the only place a player ever reads
  the value. Audit + prompts: `docs/33_upgrade_art_audit.md`. When auditing,
  OPEN THE PNG; the art-prompt docs go stale (docs/26 still specifies a KILL
  RELOAD card that was re-baked out from under it).
  Odds ride the **LUCK BAR** (`_tod_luck.gsc`, 0–100% per player: kills
  normalized 40×players÷round_total, headshots ×1.5, revive +15, door +8,
  down −25, boss LAST HIT takes all; FULL RESET to 0 after each event; LUCK
  domain = +10% gain rate/Lv). **OVERCHARGE (v14.9)**: the bar SECRETLY tracks
  to 150 (HUD + pips capped at 100 — the band is invisible); at exactly 150
  the bar art zap-animates (todUpgLuck spare values 11..14, server-cycled) +
  a per-client semi-deep zap fires every 3s up to seven times per overcharge
  (`TOD_LUCK_OVER_ZAP_LIMIT`; animation continues silently), and the deal guarantees BOTH
  non-tier cards ULTIMATE (LOCKSTEP TRIO: TOD_LUCK_OVERMAX /
  TOD_UPG_GUAR_BOTH_BAR / TOD_UPG_LUCK_OVERMAX_PCT; contracts + art/SFX
  prompts in docs/45). **NO-TWIN RULE: upgrades are NEVER weapon
  variants** (engine ~230-twin boot-AV ceiling, map 1 docs/21 §A) —
  damage/firerate(echo-proc)/magsize(virtual pool) are all script-side.
  UI = real LUI (`tod_upgrade.lua` + `_tod_upgrade_ui.gsc|.csc`, 18
  clientuimodel fields = **61 bits, the PROVEN ceiling — APPEND ONLY**);
  luck bar = LuckSegs segments in the frame art (todUpgLuck, live via
  `tod_upgrade_ui::set_luck_pct`); owned-upgrades list shows ONLY in the
  pause menu (int-only `LuiNotifyEvent(&"tod_upg_sync")` → `CoD.TodOwned` →
  AetheriumStartMenu.lua panel — `SetClientDvar` does NOT exist in T7).
  **PERSONAL UPGRADE STATION** (base, core south face, Chaos PaP mesh):
  solo upgrade buy at a FLAT 3000 (the 2000 +250/purchase ladder was RETIRED
  with the triggerstring-250 crash fix — the price must stay a single
  constant, or at least never reach the hint literal; see station_cost()
  and the triggerstring-250-cap memory), 5 uses per station and 3 at the
  CROWN ALTAR (id 5 — v17.37 2026-09-04; it was UNLIMITED 08-29..09-04, a
  call made while the price LADDER still bound it, and the ladder went flat
  with the crash fix. Read `station_use_cap()`, not this line); **the world pause is PARTY-SIZE CONDITIONAL since v16.84
  (2026-09-03)** — CO-OP does NOT pause (the risk, as it always was), SOLO
  freezes the world AND the buyer exactly like a round event, through the same
  `set_world_pause`/`menu_freeze` pair, because the risk model was always a
  co-op argument and one player has no teammate to absorb it. `station_freeze_wanted`
  is the ONE gate (party size, then the FINALE carve-out: the closing song is a
  clock a freeze cannot stop, so the crown altar stays live-world once
  extraction is called). Three behaviours ride `level.tod_upgrade_pause` and
  therefore flipped for free in solo — the reveal plays at FULL speed, the
  damage callback returns 0, and EVERY card-panel input lane opens (v16.81's
  d-pad-only station rule was earned by the player being mid-fight). The raw
  `tod_upgrade_pause` read STOPPED being a takeover test the moment the pause
  became self-inflicted: `level.tod_station_pause_owner` + `station_owns_pause()`
  is the difference, and `run_upgrade_event` CLAIMS the pause at its takeover
  notify so its own unpause can never clear a station's freeze. 15s timer; a
  scheduled round OVERRIDES a manual pick and the
  same cards re-present after (re-clamped — stale cards never lower levels).
- **HUD: Aetherium kit** (vendored, `zone_source/aetherium_hud.zpkg`) + our
  LUI menus. No Mega Bottles, no Data Shards — old map's systems, NOT ported.
- **THE CROWN + THE ENDING (v9, user 2026-08-21).** Above the spiral:
  CROWN STAIR (gold) → TERRACE → CAUSEWAY ("the pathway") → CROWN HALL, a
  1536-sq open-top citadel floating beside the tower, + a MAST on the core top.
  **v11 (2026-08-25) — THE CITADEL IS A LITERAL CROWN.** The user's verdict on
  the old one was "it just looks like a castle with spikes"; measured, it was a
  4°-wide blue box plus six spires under the 0.5°/384-unit legibility floor,
  standing on a `dark_blue_tinted` underside that rendered as a black square
  against the fog. It is now THE CIRCLET (`gen_tower_map.js` §5f): a
  **6128 wide x 13,888 tall gold crown** (v11.1, user: "I want the scale to be
  even more... players should be in awe") — ONE KNOB, `CR_SCALE` (1.4), scales
  the whole thing uniformly; the SOUTH FACE is PINNED at y=6912 because the
  mouth has to stay inside the causeway F approach, so the crown grows NORTH
  around the hall and `CR_CY` is derived. Flared 9° band, white
  ermine rim, 16 alternating points (8 crosses pattée / 8 fleurs-de-lis, every
  head WIDER than its shaft), a FRONT CROSS with a great ruby, two dipped
  arches → monde → cross finial → red beacon, 16 jewels, pendilia, and —
  v12 (user 2026-08-26: "they look up and see this MASSIVE building") — THE
  VORTEX BELL underside: 10 tiers on an ogee whose ring-widths accelerate
  toward the centre, corona teeth serrating the gold tiers, jewel collars on
  two brass tiers, ermine tail-spots under the south rim, pearl beading on the
  arches, and THE GIRANDOLE — a stepped ruby drop-pendant (with the crown's
  third red light) hanging below the bell, completing the red vertical axis
  (beacon above, great ruby front, girandole below). The causeway runs
  **through a 640×424 mouth cut in the rim**. THE HALL DOES NOT MOVE — floor,
  walls, gate, dais, sconces, exfil pad and every `_tod_crown_data.gsc` anchor
  are byte-identical; only `pylon_orgs()` moved. Full record + the 15-point
  "castle vs crown" checklist: `docs/34_crown_redesign.md`. Iterate with
  `tools/preview_crown.js` (6 renders, ~1s, no bake) — **if the `_under` view is
  dark, nothing else you did counts.** The 4 hall pillars are BACK as pure
  architecture (v12 — the v11 deletion was aimed at the coil MODELS; user:
  "I think the last agent thought I wanted the entire pillars removed"): gold
  base, ruby shaft, gold cap at the original ±448 spots, scenery + cover only.
  The finale's quarter-progress read STAYS on the crown's corner points
  (`pylon_orgs()` untouched). The hall also has its own AMMO CRATE (v12, east
  wall, mirror of the upgrade station) — coords ride in generated
  `_tod_crown_data.gsc::crown_crate_org()`, clip emitted by the generator.
  **Generated as lap LAPS+1 in the spiral's own parity math** — every
  crown coordinate is authored in the odd frame and mirrored by `CM`
  (`cbox/cpt/cyaw/cvolume/cspec`); the old odd-only "final landing" special
  case silently vanished when LAPS went even and left the roof unreachable.
  Never special-case the top by parity again. **THE LAST MILE (v10)** — the
  CAUSEWAY IS the finale arena; `SKY_IN` and `HS` are derived from `CW_LEN`,
  never literals. **v12 (user 2026-08-26: "the paths ... are pretty simple and
  straight forward. Lets be more creative ... scary and anxious") — 7360 long,
  160 wide, SAME span budget as v10.12 (so every crown/road assert held), but
  every lane is now a DIFFERENT KIND of fear**: gate-run (flanked by the first
  AVENUE PYLONS — jewelled gold obelisks floating in the void, the road's
  scale-rhythm markers) → fork (west THE RIDGE climbs +256 and ZIGZAGS along
  the crest — the awe lane, best crown view on the road; east THE BROKEN STAIR
  steps down through blind pockets into a 640-long hollow at −256, then one
  16-tread blind climb) → merge → **THE NARROWS** (the old spine, PINCHED to
  120 wide for its middle 320 under portal 2 — the road's one guaranteed
  single-file choke) → **three-way** fork (west THE UNDERCROFT plunges −384
  to an ambush cistern then 960 units of blind ascent; centre THE PLANK, 120
  wide, raised to +256, the riser-densest straight line; east THE WEAVE, flat
  but serpentining through 4 jogs — 9 pieces, 9 risers, the most infested
  ground) → merge → approach → a FLARE into the citadel gate. Boss
  altitude-sorting (panzer→highest player, protectors→lowest) makes the plank
  draw the Panzer and the undercroft draw the swarm — emergent, by design.
  Shortest walk ~8220 units (the generator prints the live number) against the
  90 s road phase — comfortable even for HEAVY (speed 0.75), so the risk at
  the ending is being PINNED, not being slow.
  The citadel mouth FLARES to `CW_FLARE` because the gate opening is 256 and
  the road is 160: the difference was unguarded hall floor over a 19,000-unit
  drop. The mouth PORTAL must be as wide as the flare or the rail pass plants
  bollards on the citadel floor — `roadEmit` throws on that now.
  **THE ROAD IS DECLARED, NOT DRAWN.** `roadFlat`/`roadStair`/`roadPortal`
  declare flat grid-aligned deck cells; `roadEmit()` rasterises them on a
  20-unit grid and DERIVES every rail. `ROAD_G === PARA === 20` is load-bearing:
  it makes a rail occupy exactly the one unoccupied column outside the edge it
  guards, so a rail can never land on deck. roadEmit also throws on overlapping
  cells, on any adjacency over `ROAD_STEP_MAX` (18), and if the citadel mouth is
  not reachable from the terrace mouth. Hand-cut rails (the v10.11 `face()`
  walking mouth x-centres) do NOT survive a road that turns — that is what this
  replaced.
  First and last runs are **on-axis at TOP2** — load-bearing, they meet the
  terrace mouth and the hall's gate opening. Every branch returns to TOP2 before
  a merge, so junctions are always flat. A `tod_causeway_gate` script_brushmodel
  **seals the mouth until EXTRACTION is bought** (same
  `Solid+DisconnectPaths` → `Hide+NotSolid+ConnectPaths` contract as every
  door); while it is shut `_tod_endless_rounds::finale_spawn_selection` drops
  every riser past it, or zombies strand on an unreachable bridge holding actor
  slots. Risers/lights/portals come from `causewayRunPoints()` etc. — placed
  **by shape, never by fraction of length**, since most of the road is no longer
  at x=0 or at TOP2. A CROWN RESPAWN GROUP sits on the terrace (gated on
  `roof_zone`, like the breather groups are gated on their lap zones) — without
  it a co-op death during the 191 s finale sent that player to the base arena,
  which is removal from the run, not a setback. It is on the TERRACE and not in
  the citadel deliberately: you come back at the START of the road.
  **THE BAKE IS A PASS/FAIL GATE, NOT A BUDGET METER** (corrected 2026-08-25):
  on near-identical input this map has baked at 38.2, 126.2, 35.1, 31.9, 31.3 and
  31.8 s. The 126.2 was taken ONCE, was used to justify a design limit, and NEVER
  REPRODUCED — an A/B with byte-identical geometry (only materials differing)
  ruled that suspect out too. Bake time here is dominated by HOST STATE, not map
  content. Never conclude anything from a single bake; run
  `node tools/measure_lit_area.js` for the budget question (deterministic,
  instant, groups area by map region) and read _bake_test only as BAKED/CRASHED,
  and the same map varies by 20 s run to run. Bake and read the number; never
  predict it, and never use it to justify not adding geometry.
  Finale = `_tod_finale.gsc`: buyable EXTRACTION
  **12k** (v10.11, was 25k — the price stopped being the gate once the gate
  became a literal wall) at the **terrace** (start of the road) → the closing
  song takes the channel and IS the clock → ~8220 walked units of
  ambushed road (v12; the generator prints the live number) → survive to the last chord → "YOU ESCAPED THE TOWER" via
  `custom_game_over_hud_elem`. `TOD_FINALE_SONG_SECS` + `DEPART_SECS` must
  equal the wav's length (191 + 6 = 197.4) or the LOOPING stream restarts under
  the ending. Ambush = spawn-delay floor + `_tod_bosses::finale_pressure_start`
  cycling all three boss types under a combined roof of 4 — **no stock AI limit
  is ever raised** (bosses are direct SpawnActor and bypass stock's gate).
  Anchors ride in from GENERATED `_tod_crown_data.gsc`. **Boss-fight slot:**
  `level.tod_finale_boss_fn` owns the hold-out if defined. Rails everywhere
  carry invisible clip caps (`RAIL_CAP_H`) — rail tops are not launch pads.

- **THE ENDLESS SPIRE (v14.0, 2026-08-29, docs/44)** — the post-victory
  endless mode, THE MAP'S HARD MODE by design (the v13.24 base tone-down was
  justified by its existence). The finale win no longer auto-departs: THE
  CHOICE — the exfil pad EXTRACTS (old ending) or the dais teleporter ASCENDS
  the party (first committed hold wins, ONE WAY) to a second **70-lap** tower
  at x=+10240 (generator SECTION 6, `SPIRE_ENABLED`; **`SP_LAPS` 70 since
  v17.69, 2026-09-05, docs/105 — it was 100 from v14.0; the user's "go to
  floor 70 instead of 100"**; monochrome red, gold hubs every 10th floor (7
  of them), crate shelves floors 5+, THE TOP one flight above hub 70's hall:
  **THE SUMMIT ARENA + THE WARDEN KING (v17.70, 2026-09-05, docs/106)** — a
  1408-square deck over the last hall (it ROOFS THE THRONE; generator
  `SP_SM_*`), the stair's mouth sealed by `tod_spire_summit_gate` on the
  hall-gate contract, a 1000-point crate, and ONE Panzer at 10M HP PER PLAYER (25M until the co-op curve pass; corrected here 2026-09-10) capped at four (up
  to 100M; NOT the "flat 100M" this line claimed until 2026-09-07)
  (`TOD_KING_*` in `_tod_spire.gsc`, `king_run`): everyone on the deck →
  seal → 10 s → he lands → a FROZEN max-out (`tod_upgrades::king_max_out`,
  then `king_dark_deals`: dark-only 10 s deals until nobody has one, everyone
  held frozen by `level.tod_king_hold`) → the fight (a second flame
  cone + summons every 18 s). ⚠️ **HIS FLAME IS DOUBLED IN BOTH APPEARANCE AND HURT BOX** (corrected
  2026-09-10 — the 2026-09-07 "check" that wrote the opposite here MISSED
  `king_setup`'s own `trigger_box( 400, 100, 50 )` swap, v17.70, which the
  pack's burn loop reads every tick as `self.flameTrigger`): the FX half is
  `_tod_spire::king_flame_fx`, an FX host linked `TOD_KING_FLAME_FWD` 140u
  ahead of the muzzle; the damage half is that trigger swap. There are no
  "re-registered BT twins" — `mechz_spiki`'s damage cone
  (`acc_player_flame_damage`) has no `tod_king` reader, and the ONLY readers of
  `self.tod_king` anywhere are the gauge, the upgrade max-out, the Wisp Tea tick
  cap and the Gift of Death divisor. So the visual overhangs the hurt box by
  140u. Known and deliberately deferred since v17.95 (memory
  `changelog-is-not-the-code`); v18.9 chose to fix the record, and v18.14 took
  the matching claim out of the store page → `king_win` unseals the extraction. **THE MAX-OUT FREEZE IS A REAL FREEZE SINCE v17.94** (first real run, 2026-09-05: Furys bamfed onto frozen players through the deals): `boss_pause_watch` re-asserts every elite's freeze PER TICK (the Fury archetype re-stamps its own anim rate on every bamf/teleport end), a Fury is PARKED at its tree's idle gate (`tod_bt_idle_on_pause` → `zombie_think_done = false`, the parked-riser statue mechanism used on purpose), the seal zeroes all four family debts (trial VII's leftovers were the Furys), and `set_world_pause` makes every upright player INVULNERABLE for as long as any world pause holds (`tod_pause_invuln`, released only by the pause and only if zombie blood / depart / summit win do not hold it). **THE SPIRE GAUGE
  IS HIS HEALTH BAR** (`level.tod_king_hp_frac` → `_tod_gauge::finale_cell`,
  full to the summit, draining). He is the ONLY Panzer — but the gate is
  `level.tod_trial_active`, which `king_run` sets at the seal alongside
  `tod_king_active`; the director's Panzer branch reads ONLY the former.
  `level.tod_king_active` is WRITE-ONLY (two writes, zero readers, confirmed
  2026-09-07) and this line named it as the gate until then. Read the defines, never this line;
  beacon z=27584 — visible from the whole climb, deliberately.
  `SP_LAPS` must stay EVEN, so "one more floor after the last trial" is a
  parity-mirror job on the summit block, not a number change). On ascension `_tod_spire.gsc`
  runs: THE GRANT — **v16.36 (user 2026-09-02): YOU KEEP THE BUILD YOU BEAT
  THE TOWER WITH.** The grant is now ONLY EVERY PERK (v16.80 dropped the PERK SLOTS gift)
  the map sells + ammo/health; the T3 promotion, the free-PaP latch and the
  domain max are GONE (v14.0-v16.35 granted all of it), and the luck bar is
  kept because it prices the trial deals. **PERMA PERKS:** stock still strips
  perks on a down; `perma_perks_watch` re-gives the roster after every
  revive and `on_spire_spawned` (the spire's first `callback::on_spawned`)
  after every respawn and for late joiners — NOT `_retain_perks`, which
  leaves `num_perks` zeroed by stock's spawn and the give-threads dead. Solo
  Quick Revive is a LIFE: withheld on the revive lane in solo, handed back on
  ascension and on every WON TRIAL. **A WON TRIAL IS THE SPIRE'S ONLY
  UPGRADE SOURCE** (`trial_upgrade_deal` → the real `run_upgrade_event`; the
  round clock stays suppressed). No cap arithmetic since v16.80: the perk
  limit is a constant above the roster, so every perk fits with nothing to
  grant (the PERK SLOTS gift went with the domain).
  The spire has NO upgrade altars — `station_spawn` places base 0, breathers
  1-4, crown 5 only; hub vendors are PaP + crate ONLY (`SP_FURN` — the two
  hub perk pads were RETIRED v17.56, 2026-09-04: every perk is perma-granted
  on ascension, so a spire machine was a prop that could take 4000 points for
  a perk already held), and
  PaP must stay because a tier card needs the class gun packed. Mule Kick is
  not granted (RETIRED; a bare HasPerk of it raises the weapon limit to 3), TOWER TEARDOWN (deletes the old world's
  script entities — the ~1024-gentity budget is the spire's binding
  constraint), perk machines are RETIRED at the ascension
  (`_tod_perk_scatter::retire_all`, v17.56 — parked under the spire, triggers
  disabled, watchers stopped; the roster keys survive because
  `perma_perks_give` reads them; v14.0-v17.51 migrated them onto spire pads
  instead), music → `tod_music_spire` (Suno "Neon Static", single
  band row, Panzer override intact), spawn pacing HOT (0.18 floor — lockstep
  pair in _tod_spire.gsc and _tod_endless_rounds.gsc) **and the ROUND BUDGET
  HALVED** (v16.9, user: "each round was like 15 minutes" —
  `tod_max_zombies` on stock's `max_zombie_func` hook, `TOD_SPIRE_BUDGET_DIV`,
  **1.25 as of 2026-09-04** — 3 shipped untested, the user walked it to 2 the
  same session, played it, and found the round COUNTER racing ("rounds progress
  too fast ... half it. Maybe even 60% less faster"), so 60% of the speed-up was
  given back; read the define's own LEDGER block, never this line;
  at depth the round clock is budget ÷ kill rate because spawning stalls on
  the 45 ai_limit, so the trickle floor cannot move it). Doors sequential
  (ONE live buy at a time, flat 6300 since v17.70 — 9000 v17.10, 4500 v16.30,
  3000 before — through
  door_price; the base rides GENERATED `door_cost()`, never a script literal), crates in a
  ±3-floor lazy window. Wipe = "THE CLIMB ENDS HERE"; summit extraction
  @7500 = "YOU CONQUERED THE SPIRE". _tod_finale ↔ _tod_spire talk ONLY by
  level notifies (tod_choice_begin/tod_ascend/tod_extract) — no import
  either way, each no-ops without the other. Anchors ride GENERATED
  `_tod_spire_data.gsc`. The lint carries spire-island proofs (own flood,
  arena→summit, own detachment bucket) — but a GEOMETRY flood and a NAVMESH
  flood are DIFFERENT CLAIMS, and the spire is the case that proves it: it
  shipped lint-green in v14.0 with ZERO navmesh (cod2map only flood-grows mesh
  from seed entities — navmesh.json seeds — and the detached island had none),
  so every zombie on it was inert until v14.19 seeded it (22 node_pathnodes,
  generator §6f; memory `navmesh-is-seeded-flood`). Any NEW detached region
  needs its own seed + a FULL build. **THE NAVMESH IS NOW READ, NOT INFERRED
  (2026-09-04, user: "random spots on the map zombies won't attack you ...
  around floor 42-44 ... spots where you just can't get targeted").**
  `tools/lint_tod_navmesh.js` decodes the `.hkt` cod2map wrote (faces, edges,
  vertices — format in its header) and runs as a HARD GATE after cod2map on
  every full build: each tower must be ONE connected component. The shipped
  mesh was **18 islands**, every seam inside the E flight of laps 17/19/33/39/
  43 on BOTH towers (floor 43 = that report; lap 17 = the v17.7 "no mesh above
  floor 17" ceiling, which was this seam plus pruning). Seeds, the .hkt byte
  size and cod2map's transcript all read CLEAN on that mesh — only the faces
  showed it. Cause: the ramp wedge's top passed EXACTLY through every tread's
  nosing edge, so each flight gave Havok a walkable plane with fifteen
  coplanar contact lines; its overlapping-triangle fixup left unstitched
  slivers on laps whose plane arithmetic rounded badly. Fix: `RAMP_LIFT` (2)
  in the generator lifts every wedge above the nosings — 18 → 2 components
  (tower+crown road, spire). Zombies chase `player.last_valid_position` and
  need a PATH to it, so "won't attack HERE" is always a mesh question; ask
  the lint before theorising about seeds. ⚠️ SHIPPED BOOT-VERIFIED BUT THE
  POST-WIN LADDER HAS NO REAL RUN (and could not have run before v14.19) —
  tools/spire_wip/WIRING.md §10 is the ladder, HARNESS.md the fast-path recipe.
  **THE WARDEN TRIALS (v16.15 → v16.19, docs/66) — every spire hub (floors
  10..100) is THE HUB HALL: the tower's centre opens for the fight.** At a
  hub lap the core column STOPS at the hub's mid landing and resumes 576
  higher (generator §6b segments, ending UNDER the hall slab), and a DRUM of
  plain-red walls (632 tall, 20 outside the parapet line; generator
  `SP_RM_*` + `SP_FURN`, asserted like `BR_FURN`) encloses the whole
  872-square cross-section: a hall floor at the hub landing over the core
  footprint + the E/N galleries + the NW region (which roofs the W flight's
  lower half; the flight climbs into the hall through a 160-wide STEPPED
  FAN at its top — v16.21: treads 12..15 each get a run of 12-high slabs
  rising eastward to hall level, every adjacency in the fan one step, one
  wall on its north edge — and the floor's edges over the slot carry
  on-floor rails), the hub's own S flight climbing INSIDE the drum behind a
  stepped inner wall from the corner (the lane under a stair is void; that
  lane is OUTSIDE the seal),
  the next lap's E and N flights running round the inside of the drum as
  railed galleries 192/384 up, four cover pillars (NONE in the doorway's SW
  corner), a floor ring + the TRIAL MARK, vendors on the walls, six risers.
  No crate shelf on the floor after a hub (it would jut through the drum).
  THE SEAL IS THE HALL GATE (v16.21): `tod_spire_hall_gate<hub>`, a
  script_brushmodel across the fan's mouth on the crown door's proven
  Show+Solid+DisconnectPaths contract (hidden at init, shown for the trial,
  hidden again on the win) with Shadows of Evil's ritual-barrier FX along it
  (`zombie/fx_ritual_barrier_defend_door_wide_zod_zmb`, the purple lockdown
  wall, three tag_origin hosts spread on the gate's axis at yaw 0 — the one
  number to flip if it renders edge-on). v16.19 sealed DOOR n one flight
  below instead: the floor locked, the room did not, and the first real run
  (2026-09-02) walked out of the hall onto its own stairs. `trial_box` is
  the HALL ALONE (the W flight's slot and the S lane are out). No honour
  guard at hub doors. SEVEN LAYOUTS since v17.69 (ten from v16.21 to v17.68;
  `SP_RM_LAYOUTS`: pillar/post/low wall/dais/big pillar — and since v17.86
  (docs/109, user 2026-09-05: "each one to have its own personality ... a
  story for each") TALL walls, bar FENCES, LAMP pylons, PLAT steps, a THRONE,
  LINTEL beams and wall PANELS — asserted clear of
  the approach lane, the seven gallery risers, spawns, vendors, the Warden
  drop, UNDER the E gallery flight and, for hub 70, under the summit CAPITAL
  that roofs that hall's centre at 192 — PLUS a `hue` that colours all five
  hall lights AND, since v17.86, picks the hall's whole material KIT
  (`SP_HALL_KIT`: floor, inner walls + a drum LINER band, lamps, panels,
  step, sigil — the drum's outside and the gold band stay gold), and a `sig`
  floor SIGIL inlay, asserted clear of everything. Plan views:
  `node tools/preview_trial_halls.js` (from the EMITTED brushes, ~1 s))
  matched to SEVEN RECIPES (`trial_recipe`: which elite family carries the
  adds — sprinters included — extra Wardens, the frenzy's timing): THE RING
  (gold), THE KENNEL (green), THE FIRING LINE (cyan), THE ALTAR (purple), THE
  MAZE (orange), THE GAUNTLET (white), THE THRONE (red). Names, colours and
  fights are the table in docs/105 §A.2; the banners carry the same colours.
  **FOUR TRAPS THE GEOMETRY LINT'S FLOOD CAUGHT (2026-09-02)**: a rail on
  the NE landing's inner edge sat ON the N flight's first tread — that edge
  IS the flight's mouth — and severed the climb; a wall from the hall's SW
  corner shared the doorway's 20u cell; the SW pillar left a 20-wide slot;
  the post-hub shelves cut through the drum. Bisect recipe: an env-gated
  skip per piece + a patched lint copy that lists detached nodes by brush
  (CHANGELOG v16.19). **THE HALL
  CLOSES ITSELF the moment every living player is inside it**
  (`trial_watch_all` — ONE watcher over every hub from ascension, v16.21;
  the v16.15 per-hub watcher armed on the door BUY, which is one path of
  several into a hall: a 2 s tell at the gate and the mark, then a re-check; a downed teammate outside holds
  it open — user 2026-09-01: "once everyone is in the holdout starts and
  gets locked off from leaving"; the v16.15 hold-USE altar is GONE) and
  runs a `TOD_TRIAL_SECS` (70 since v17.8 — 60 for an hour that evening, 90 before, 120 originally; `TOD_TRIAL_FRENZY_SECS` is DERIVED as a third of it, so the length is one number) hold-out: wipe, seal, WARDENS (Panzers via
  the honour-guard direct-spawn
  lane: one per player, +1 in the last `TOD_TRIAL_FRENZY_SECS`, cap 4,
  replaced `TOD_TRIAL_WARDEN_REDROP` after a fall), adds per the hub's
  recipe (protector/reaver/hound/sprinter debts), every elite spawned inside
  ×`TOD_TRIAL_HP_MULT`
  (boss_hp reads `level.tod_trial_hp_mult`; THE LADDER, re-set TWICE from
  real runs and therefore the LAST thing to quote from memory — read the
  `TOD_TRIAL_*` defines at the top of `_tod_spire.gsc`: v16.21 took the
  v16.15 numbers ×0.85 with a 1.07 step, v17.8 took THOSE ×0.75 with a 1.08
  step (trial I HP ×0.956 / tick 5.75 s, trial X ×1.911), v17.69
  COMPACTED TEN STEPS INTO SEVEN at the SAME TOP: step 1.1225 (= 1.08^9 ^
  1/6), so trial I was unchanged and trial VII was the old trial X — user
  2026-09-05: "compact 1-10 difficulties into 7 ... bigger jumps"; and
  **v18.2 2026-09-06 FLATTENED THE RAMP, step 1.1225 -> 1.09** (user: "many
  people are complaining about how hard the trials get as you continue to go
  up ... lets make it a bit easier as you continue") — trial I still does not
  move, trial VII goes ×1.911 -> ×1.603, and the same pass's -10% on every
  elite lands on top of it; earlier
  users: "toned down about 15% … 7% increments", then "starting off way too
  hard … about 25% easier … 8% harder each level"), trickle at
  `TOD_TRIAL_SPAWN_FLOOR` 0.12 (LOCKSTEP pair with `_tod_endless_rounds`),
  its OWN track (`tod_music_trial`, "Chaos Unleashed" — v17.8; it was the
  boss track until then, and it is level-matched to that track rather than to
  the band tracks, since it replaces it at the same alias volume),
  the tower gauge as the clock (the finale's `tod_finale_song_*` lane —
  `finale_cell` sizes itself with `cells_for_mode()`, so a trial fills all 35
  spire cells and `trial_win` clearing the two fields drops it back to
  altitude), and
  the door ABOVE the hub (11, 21 … 61) plus the summit extraction for hub 70
  SEALED until the clock runs out (`trial_seal_window`, one shared literal).
  The win's purse is 5000 + 1500 per tier past the first (trial VII 14000 —
  the old trial X's purse; 1000/tier until v17.69).
  **NO CEILING IS RAISED**: the Wardens get FIRST CLAIM on
  `TOD_ELITE_ROOF_ALL` through `level.tod_trial_reserve` (read by
  `elites_over_roof`), and `level.tod_trial_box` contains every spawn —
  risers in `finale_spawn_selection`, bosses in `pick_spawn_point` — inside
  the ring, the sealed-crown `in_hall` rule one flight up. Wardens pay the
  elite rate (`tod_spire_guard`); the win pays `TOD_TRIAL_WIN_PTS` 5000
  team-wide + a Max Ammo on the mark + **AN UPGRADE CARD DEAL to every living
  player (v16.36, `trial_upgrade_deal` — the spire's only upgrade source)** +
  the perk top-up (a no-op under perma perks except the solo Quick Revive life).
  **THE REWARD IS A FROZEN WORLD FROM THE LAST CHORD (v17.61, user
  2026-09-04: "make sure to freeze the game during the trials reward")**:
  `trial_win` calls `set_world_pause( true )` BEFORE any reward lands and the
  deal releases it after the last pick (`trial_upgrade_deal` releases it
  itself on the empty-deal path). Before v17.61 only the deal froze, 3 s after
  the win, and those 3 s were a live hall under the WON plate. Players are
  NOT frozen by the win — the cards freeze participants as ever. The summit
  extraction refuses during any freeze (same gate as every spire door). The
  Max Ammo drops with stock's `b_stay_forever` and gets stock's own
  `powerup_timeout` started on it when the freeze lifts (`trial_ammo_drop`) —
  its ~26 s real-time life used to run out under the cards.
  ⚠️ ONE REAL RUN (2026-09-02, dev build, hub 10 only): the fight ran, the
  lock was in the wrong place, the entrance was too small — all three
  reshaped in v16.21 and UNPLAYED since; the harness in
  HARNESS.md plus a warp to a hub is the fast path. Copy lockstep: the
  frenzy has NO on-screen print since v17.46 (user 2026-09-04: "I dont want
  that display" — the "THE FRENZY" IPrintLnBold is gone; the mechanic is
  unchanged and unannounced). The ten TRIAL I..X banners LANDED in
  v16.25 (`trial_banner( tier )` at the seal — verified by the content-hash
  `.iwi` rule); **v17.69 retired 8..10 WHOLE (precache, zone, GDT, PNGs)
  and re-commissioned 1..7 with the new names + hall colours (docs/105,
  LANDED v17.70 the same night)**; the clamp in `trial_banner` reads
  `hub_laps().size`; the WON
  plate landed in v16.44 (`tod_trial_won`, `trial_banner( 0, "tod_trial_won" )`
  at the win). **THE GAUGE HAS A SPIRE MODE since v16.44 (docs/71)**: 35
  cells at pitch 30 since v17.69 (50 at pitch 21 for the 100-floor spire —
  LOCKSTEP TRIO: the slicer's spire profile, `SP_CELLS/SP_PITCH` in the Lua,
  `TOD_GAUGE_SPIRE_CELLS/LAPS` in the GSC; the docs/105 art LANDED v17.70 —
  cut with `--band-tol 140` because that delivery draws plates edge-to-edge,
  a documented override, not a green-by-number), a gold hub plate every 5th, the summit on top,
  a WHITE down tile —
  `_tod_gauge::gauge_mode()` reads `level.tod_spire_active` / `tod_spire_won`
  (never add a second latch); before it the bar sat full with the crown lit
  from spire floor 51 to 100. Both gauge sets are cut by
  `tools/slice_gauge.js` (profiles) from registered masters — a re-bake is
  one command plus a full build.

## Conventions

- Map name `zm_tower_of_doom`; script prefix **`tod`** (`_tod_*.gsc` modules,
  `tod_*::` namespaces, `level.tod_*` state) — mirrors the old map's `acc`.
- Entry scripts `scripts/zm/zm_tower_of_doom.gsc|.csc`; modules under
  `scripts/zm/zm_tower_of_doom/`; every module needs a `scriptparsetree` line in
  `zone_source/zm_tower_of_doom.zone`.
- **The `.map` is GENERATED** by `tools/gen_tower_map.js` from the layout tables
  at the top of that file. The generator ALSO emits
  `scripts/zm/zm_tower_of_doom/_tod_door_data.gsc` (door buy-trigger coords) so
  the .map and GSC can never drift. Regenerate BOTH with
  `node tools/gen_tower_map.js` after any layout change; hand-edits to the .map
  will be clobbered by a regen, so put changes in the generator.
- **DEV TEST HARNESS: REMOVED** (2026-08-25, verified 2026-08-26).
  `_tod_main::dev_crown_test` and the dev finale clock are GONE — the user had
  the throwaway harness reverted before publish (`_tod_main.gsc:63` records
  it). `level.tod_dev` still exists and still gates the money loop, early
  Panzer/boss intervals, 100% tier-card odds and unlimited station uses — but
  nothing warps to the terrace and the finale clock is the same 191 s in every
  build. If the ending needs testing again, write a fresh harness (recipe in
  the _tod_main comment: stock power entry
  `zm_power::turn_power_on_and_open_doors` + `zm_perks::perk_unpause_all_perks`
  — poking "power_on" by hand leaves perk machines paused — open every zone
  flag + the causeway gate, warp on spawn AND respawn), and remove it again
  before publish.
- Dev/test = ONE compile-time flag, `level.tod_dev` in
  `zm_tower_of_doom.gsc::tod_resolve_dev_flags()` (hardcode `= true;` +
  rebuild to arm a test session; ship state `= false;`). NEVER add dev dvars or
  tell the user to set console dvars — same doctrine as the old map (its
  CLAUDE.md "Dev/test mode" section).
- **Current test setup (2026-09-10, HARNESS #8 LIVE):** `tod_dev`, `tod_god`
  and `tod_dev_doors` armed (`tod_resolve_dev_flags`, unchanged since the
  floor-10 session) AND `_tod_main::init` threads `dev_spire_harness`: the
  draft runs, the round-1 deal clears, power on, every tower door open, the
  party ASCENDS with no finale, every spire door opens, and EIGHT WARP PADS
  appear — beside the arrival (-> hub 10) and on every hub's door landing
  (-> the next hub, 70 wraps to 10; refused mid-trial). Tier 3 + maxed comes
  from `dev_maxed_harness` (implied by `tod_dev`), not from #8. The warp lands
  you on the landing BEFORE the door facing the W flight (fixed 2026-09-10;
  it used to be the first tread past the door, facing back). Park #8 again
  (comment the one thread line) and disarm the flags before any publish.
  -GscOnly BUILD VERIFIED 2026-09-10 19:15:12 Eastern, FF 176,182,656 bytes; scripts/zone_source/ui diffs clean, nothing synced after the .ff; deployed _tod_main threads the harness and tod_dev/tod_god/tod_dev_doors read true. UNPLAYED.
- **Test setup history (2026-09-08, v18.57 — superseded by the bullet above):** `tod_god`, `tod_dev_money`,
  `tod_dev_doors` and **`tod_dev_altar`** are enabled in `tod_resolve_dev_flags`;
  `tod_dev` and `tod_dev_maxed` stay false, so the loadout is a normal tier 1 and
  upgrades are still earned. `tod_dev_altar` = UNLIMITED station buys at EVERY
  terminal, not just the spawn one (station_depleted; the not-scoped-to-spawn call
  is deliberate and its reasoning is at the flag). All four are caught by
  build_map.ps1:250, which refuses `-Publish` while any is armed. Read the live assignments
  before changing them; do not restore the earlier all-three-staff grant.

## PUBLISH PREP = BUILD + PATCH NOTES (user 2026-09-02)

**"When I ask for a full build for publish prep we need to generate patch
notes as well ... record the notes by day and time to be accurate."** The
Workshop item shipped 25 times without a single change note; that ends here,
and it is a GATE, not a memory: `build_map.ps1 -Publish` refuses to build
until `node tools/patch_notes.js check` passes.

The ledger `docs/publish_ledger.json` holds one row per Workshop upload —
upload time (machine clock, Eastern; Steam's page renders Pacific, +3 h),
`.ff` time, version label, and the NEWEST `CHANGELOG.md` header that upload
contained. Everything above that header is unreleased, and that is the window
the next notes cover. The player-facing notes live in `docs/68_patch_notes.md`
(one `## Update — <Mon D> (<version>)` section per upload, headings New /
Balance / Improvements / Fixes) with the same section as a paste-ready block
at the top of `docs/68_patch_notes_steam_bbcode.txt`. `docs/67_release_notes.md`
is the DEV history (every entry, condensed) — never paste that to players.

The flow, every publish, in this order:
1. Write the publish build's own CHANGELOG entry (it must be the TOP entry —
   the cutoff is captured from it).
2. `node tools/patch_notes.js window` → `docs/patch_notes_window.md`: every
   CHANGELOG entry newer than the last upload, with the clocks each recorded,
   plus the newest docs/68 section as the style reference. READ IT WHOLE.
3. Write the new section at the top of docs/68 and the BBCode file. Player
   voice only: no builds, versions, harnesses, "unverified", engine talk, docs,
   art prompts. Keep the numbers players feel. NET the window — a change made
   and undone inside it is dropped; a number moved twice reads old → final.
   Dev/test-only entries contribute nothing. `check` rejects bullets that
   carry dev vocabulary.
   **SHORT AND PLAIN (user, 2026-09-10: "reduce any jargon and make it super
   simple for players ... We dont need a billion characters for change
   notes"). ONE LINE PER BULLET, 200 characters at most — `stage` FAILS on a
   longer one (`MAX_BULLET` in tools/patch_notes.js) and prints the longest
   offenders.** Say WHAT changed, never how or why; group related knobs into
   one bullet instead of listing each; cut any second clause that only
   justifies the first. The Sep 10 2026 section is the reference — everything
   above it in docs/68 is the older, longer style, left as it went out.
   Reaching for the ceiling is a smell: that release covered a 16-entry
   window in 30 bullets, most of them under a hundred characters.
4. `node tools/patch_notes.js stage --version vX.Y` (heading date = today,
   or `--any-date`).
5. `.\tools\build_map.ps1 -Publish` — the gate runs `check`; after BUILD OK the
   script stamps the pending row with the `.ff` time (`built`).
6. **PASTE THE BBCODE BLOCK INTO THE CHAT, VERBATIM, IN A FENCED CODE BLOCK** (user 2026-09-13: "When i say prep
   for publish and get the patch notes I expect the patch notes to be pasted here in steam syntax so i can simply
   copy and paste" — pointing at the file is NOT delivery). Then the user uploads and pastes it into the Workshop change note.
   Then `node tools/patch_notes.js uploaded` pulls the Steam time, refuses if
   it predates the `.ff` (not uploaded yet), closes the row and writes the
   time into the docs/68 section line. If the session ends before the upload,
   the next session runs it — `status` shows a pending row.

⚠️ **`window` ONLY READS CHANGELOG.md, AND PEER SESSIONS DO NOT WRITE THERE (2026-09-16).**
The art sessions in this repo record in CLAUDE.md + docs/ and write no CHANGELOG entry, so a shared
day's work is INVISIBLE to the window and the notes ship short. v19.22's first cut missed ALL SIX
REBUILT HEAVENLY ALTARS and the reference one/two/three cyber roster - both already in the `.ff` -
and the user caught it ("What about the new altar look ... Did you miss stuff?"). **Before staging,
diff the tree as well as the CHANGELOG:**
`find scripts ui source_data localizedstrings sound sound_assets zone_source -type f -newermt "<the last uploaded row's .ff time>"`
and account for EVERY file it lists. A changed `source_data/*.gdt` or `model_export/` tree is a
player-visible art change even when no script moved.

**RECONCILE AGAINST THE LIVE PAGE BEFORE WRITING ANYTHING (2026-09-10).** A
PENDING row that outlives its own upload is the one failure no gate here can
catch: `stage` overwrites the pending row IN PLACE and `check` only compares it
to the CHANGELOG, so once an upload goes out against a row that stays pending,
every later `window` runs from a cutoff that is already public and hands back
bullets players have already read. That is how row #34 sat pending through the
Sep 9 v18.72 Mage release while the docs/68 section grew to 47 bullets mixing
shipped and unshipped work. NOTHING IN THE REPO CAN TELL YOU — ask the user for
the live Workshop notes (or fetch them) and match them against the last
**uploaded** row, never the pending one. One bullet dated that upload: "packed
staffs show EX after their name", which the next day's build replaced with the
true staff names. Fix = flip the row to `uploaded` with `confidence:
reconstructed`, split docs/68 so one section is exactly what players saw, and
stage ONLY at publish time so the ledger never carries a promise the Workshop
has not been given.

If the CHANGELOG moves after staging (a peer's entry, a late fix), `check`
fails on purpose: fold the new entries into the section if players would
notice them, then re-stage. `-SkipNotesGate` exists for an emergency and
prints a warning that the upload is going out without notes again.

## ART REQUEST PACKS = ONE DOC, ONE TOOL, ONE ZIP (user 2026-09-02)

**"Lets finalize this process of zipping up reference images and
instructions ... I can just send the zip to my asset generator and they can
easily know the task and goal."** Every baked-art request now goes out as
`~/Downloads/tod_<name>_art_pack.zip`, built by `tools/make_art_pack.ps1`
from a repo brief — never a hand-rolled zip, never a prompt pasted in chat.

- **The brief is a repo doc, `docs/NN_<thing>_art_prompt.md`, and it is the
  ONLY source.** It carries an `<!-- art-pack ... -->` header (`name:`,
  `refs:` = the CURRENT shipped files to match, each with a one-line role,
  `preview:` = the on-screen WxH) and a `<!-- PACK:BEGIN -->…<!-- PACK:END -->`
  section that becomes `INSTRUCTIONS.md` verbatim. docs/73 is the worked
  example; the tool's header documents the format.
- **INSTRUCTIONS.md is generator-facing:** deliverables table with EXACT
  filenames + sizes, hard rules, the exact text to bake, paste-ready prompts
  that name which `reference/` files to attach, a delivery checklist, a
  do-NOT list. No repo internals (the tool WARNs), no absolute paths (the tool
  FAILS — a generator cannot open `C:\` anything).
- **The tool** copies the refs to `reference/`, writes `reference/README.md`
  from the roles, renders every PNG ref at its real on-screen size into
  `preview_onscreen_<WxH>/` (what the player sees is what the generator
  should judge against), checks PNG headers, and zips. Run it after EVERY
  edit to the doc — the zip is a build product, the doc is the source.
- **The drop** comes back as `~/Downloads/files (N).zip` (newest N; often the
  PNGs loose AND a nested zip). `.\tools\make_art_pack.ps1 -Inspect
  'files (N).zip'` extracts it (nested zips too) and prints size / colour
  type / md5 / whether a same-named repo image exists and differs. It
  installs NOTHING: LOOK at every image, proofread baked text, overlay
  against the shipped file, then copy into `source_data/tod_ui_images/_images/`.
  Same name = no wiring; new name = GDT block + zone `image,` line + Lua slug.
  FULL build always; proof = a fresh content-hash `.iwi` beside an untouched
  control. Flip the doc's STATUS to SHIPPED with the build version.

## Match the effort to the question (user 2026-08-28)

**"Why is it taking a whole research team to turn a machine model?"** — a fair
callout, and the rule now: **DO NOT spin up a multi-agent workflow for a
question with one small answer.** Rotating a model is one number. Four
research agents plus verifiers to find "-90" is waste, and it delays the fix
past the point the user could have just looked at it in game.

The test before delegating: *how many distinct places must be read, and what
does being wrong cost?*
- **One number / one file / one obvious call site → just do it.** A wrong yaw
  costs one 4-minute `-GscOnly`. That is cheaper than the research.
- **Reversible + instantly visible in game → prefer shipping a guess** over
  proving it on paper. The user testing IS the measurement, and they are
  faster at it than any parser.
- **Fan out only when the answer genuinely lives in many places at once** —
  the map-wide trigger/UI-copy audit was the right call (5 systems x every
  runtime state, 32 findings, one of them a live regression nobody would have
  found by reading one file). Sweeps, audits, and "what did we miss" earn it.
- Never let a running workflow become the reason a known-broken thing sits
  unfixed. If the fix is obvious, ship it and let the research land later.

TWO AXES, NOT ONE (both-sessions postmortem, same night). Scale the WORK to
cost/reversibility — but never scale down the CHECKING of a factual claim.
The same evening produced both failures: research prices paid for a one-number
yaw (over-delegation), and a confident "there is no crown PaP" told to the
user off a name-grep while the emission site sat open in the editor
(under-checking). A wrong yaw reverts with one build; a wrong CLAIM
propagates into what people believe and act on, and does not revert.
**CHEAP TO CHANGE IS NOT THE SAME AS CHEAP TO BE WRONG ABOUT** — before
asserting what the code does or contains, read the site that produces it.

## Dev-mode diagnostics for feature work (user 2026-09-10)

**Make useful dev logs a normal part of building features and fixing bugs.**
For most gameplay features, stateful UI features and substantive fixes, include
enough diagnostics that a normal dev-mode playtest leaves evidence another
agent can use. The user should not have to repeat a session just because the
first implementation recorded nothing useful. Scale this to the change: a
static text or art edit usually needs no new instrumentation.

- **Run automatically with dev mode.** Gate server diagnostics on the existing
  `IS_TRUE( level.tod_dev )`; use the established dev/logging channel for the
  relevant VM. No extra feature toggle, console command or special user action
  should be needed. Keep useful diagnostics with the feature for future tests.
- **Log decisions and outcomes.** Prioritize initialization, important state
  changes, activation/completion, denied actions with their reason, timeouts,
  failed lookups and cleanup/restoration. Include a consistent feature tag
  such as `[TOD_TELEPORT]`, game time, relevant player/entity identity, and
  the values needed to explain the decision. For example: resource before/after,
  cooldown remaining, requested destination/result, or expected/actual state.
  Include an operation or lifetime identifier when events can overlap or an
  entity slot can be reused. Avoid context-free messages such as "failed".
- **Record at the source of a transition.** A periodic snapshot can miss an
  entire operation between samples, as the same-frame elite pause did. Log or
  stamp critical writes and their matching release/completion at the actual
  call sites. Trace both sides of a server-to-HUD handoff when that handoff is
  what needs diagnosing, using each VM's supported channel.
- **Keep logs cheap and separate from gameplay.** Prefer changes/events over
  per-frame output; throttle repeated failures and use bounded summaries for
  loops or large collections. Diagnostics must not change targets, goals,
  timers or gameplay state, invoke callbacks with side effects, or introduce
  a growing history in memory. Guard missing/deleted entities. Use the console
  log rather than player chat, floating text or a debug overlay by default.
- **Verify that the useful records actually appear.** Compilation alone does
  not establish that a logger runs. During the authorized native test, check a
  startup/revision marker and representative success/failure or state-change
  records with populated fields. If a path could not be exercised, say so;
  do not claim that every diagnostic branch or the whole feature was tested.
- **Preserve and explain the evidence.** Use the existing launcher/capture
  workflow before relaunch. Search the raw archived console by the feature tag;
  the filtered extract includes uppercase `[TOD_*]` feature tags as well as
  AI/native errors. Extend it when needed. Record the tag, important
  fields and capture location in the feature's notes so the next agent can
  read a user's completed playtest without rediscovering the instrumentation.

For server GSC, use the proven PrintLn pattern below inside the feature's
existing module; do not import an unrelated gameplay module just to log.
The module needs its usual `shared.gsh` insert for `IS_TRUE`.

```c
function dev_log( msg )
{
    if ( !IS_TRUE( level.tod_dev ) ) return;
    line = "[TOD_FEATURE] ms=" + GetTime() + " " + msg;
    /#
    PrintLn( line );
    #/
}
```

Replace the example tag with the feature name. **Assemble the full string
outside the developer block; keep PrintLn inside it.** The native loader
rejected an unwrapped call despite a successful compile, and literal strings
assembled inside the block were blank in a tested run. The existing launchers
already supply `developer 1`, `logfile 2` and `scr_mod_enable_devblock 1`.
Follow [docs/132_native_game_verification.md](docs/132_native_game_verification.md)
for native verification and log preservation; diagnostics do not waive the
rule against rebuilding while the game is running.

## Agent-operated native game verification (user 2026-09-10) — ONLY WHEN ASKED (2026-09-16)

⚠️ Read the top of this file first: the user tests, the agent writes logs.
This section is the recipe for the case where the user explicitly asks for
an agent-run match in that message; it is not a standing authorization.

**Build and start authorized test matches yourself.** The user explicitly asked
that both Claude and Codex know how to do this, instead of handing launch steps
back to them. Follow [docs/132_native_game_verification.md](docs/132_native_game_verification.md):
`tools/run_game.ps1` launches through Steam with the correct gametype and devmap,
archives the old console, and enables the actual developer-block logger. Use
`tools/focus_game_window.ps1` and `tools/game_window.ps1` to focus, inspect and
click Steam's custom-arguments Continue dialog, then inspect the native game
and logs. Handle that dialog yourself for an already-authorized launch. A
process or a memory-threshold message is not proof that the map loaded.

Never build while BO3 runs. Do not interrupt an active user match without their
okay. The user judges subjective visuals/gameplay; agents handle builds,
launches and objective native checks. Check every helper's exit code, use DPI-
correct window-relative coordinates, and stop input if focus fails. Do not use
unguarded SendKeys or type console commands as player chat. Preserve logs before
relaunch and report whether the final build was actually tested in game.

## Build / run (same pipeline as the old map)

- `.\tools\build_map.ps1` — full headless build (sync → cod2map64 [cwd=bin] →
  Radiant LED bake → linker → verify fresh `.ff`). `-GscOnly` for
  GSC/.zone-only changes. **Build it yourself; the user's job is to TEST.**
  Build success = a FRESH `.ff`, NOT the linker exit code.
- **THE XPAK IS APPEND-ONLY — CLEAN IT BEFORE EVERY PUBLISH (2026-09-03,
  docs/86).** The linker never removes anything from `zone\<map>.xpak`: every
  full build leaves the previous build's reflection probes / probe volumes /
  sun-shadow tree behind under the SAME names, every replaced asset leaves an
  un-indexed hole, a retired asset keeps its entry. Measured that day: a 9.5 GB
  pack of which ~5.3 GB was history (47 shadow trees under one name, 221 probe
  sets for 55 probes, 1.4 GB of holes), and that pack IS the Workshop download.
  `-Publish` implies **`-CleanPak`**, which now rebuilds ALL main/language packs
  and implies `-AllLanguages` (moves packs out of `zone\`, preserves old FFs/
  banks until every language passes, restores on failure; `-KeepPak` opts out).
  `last_payload.json` beside `zone\` records the complete final folder size.
  **Answer any
  size question with `node tools/xpak_report.js`** — it reads the pack's own
  index and attributes every byte; docs/61 #8 reasoned from the asset list and
  was wrong by 5 GB. Our `i_tod_*` UI art is NOT in the pack (it rides the
  `.ff`), so its `uncompressed` setting is not a lever **FOR DOWNLOAD SIZE**.
  ⚠️ **IT WAS AN ENORMOUS LEVER FOR RESIDENT RAM, AND THAT COST WENT UNSEEN FOR
  MONTHS BECAUSE THIS SENTENCE READ AS "not a lever" FULL STOP (fixed v19.8,
  2026-09-14).** Uncompressed art is cheap on disk (LZ4 inside the `.ff`) and
  ruinous in memory: it expands to raw RGBA8, and 731.0 MiB of the map's 920.6
  MiB resident was `i_tod_*` UI art — 79.4%, of which 596 MiB was 177 upgrade
  cards at 3.38 MB each. Flipping the div-4 ones to `compressed high color`
  (BC7, format byte 0x1f — NOT the DXT5 that v16.97/docs/89 object to) took the
  map to 377.8 MiB. **DISK SIZE AND RESIDENT SIZE ARE DIFFERENT QUESTIONS WITH
  DIFFERENT LEVERS; `xpak_report.js` answers the first and the linker's
  assetinfo ledger answers the second.** Tools: `set_image_compression.js`
  (`--restore`) and `verify_image_compression.js`. Third-party texture
  RESOLUTION is: `tools/downscale_pack_textures.js` caps a pack's sources with
  the originals parked in `<modtools>\_tod_texture_originals\` (`--restore`
  undoes it); the nine sold perk machines were capped at 1024 that day.
- **KEEP THE BUILD SMALL — IT IS A GATE NOW, NOT A GOOD INTENTION (user
  2026-09-03: "keep this process of minimizing the build ... we somehow had
  7GB of random stuff not even used").** The item went 9.61 GB → ~2.4 GB in a
  day, but **be accurate about where it went**, because the three causes have
  three different fixes and only two are automated:
  (1) **build history inside the pack — ~5.3 GB, the bulk of it.** The linker
  APPENDS to `zone\<map>.xpak` forever. Fixed by `-CleanPak`, implied by
  `-Publish`. Prove with `node tools/xpak_report.js`.
  (2) **texture resolution on assets the map DOES use — ~1.2 GB.** Perk
  machines at 4096², the Leviathan axe's uncompressed TIFFs, the riot shield's
  13 materials at 2048². Fixed per-pack with
  `tools/downscale_pack_textures.js --cap N <gdt> --apply` (originals in
  `<modtools>\_tod_texture_originals\`, `--restore` undoes it). NOT automated —
  it is a judgement call about how close a thing is ever seen.
  (3) **genuinely unused assets — only ~130 MB**, and that is the honest
  number: the Street Sweeper (a retired class's gun), the Mahem rocket (a
  function with no caller), 12 cards for retired domains. Hunt them with
  `node tools/audit_zone_usage.js` (reads "computed? prefix" as USED — perk
  cans, `_up` PaP forms and `_on` machine models are all built at runtime).
  **`tools/lint_tod_assets.js` now gates the recurring case on every build**
  (see the UI-art lint bullet below).
  **THE RULE THAT KEEPS IT SMALL: when you retire anything, retire it whole.**
  A domain is its `add_domain` AND its `CARD_SLUG` slug AND its card zone
  lines; a weapon is its zone lines AND its alias rows AND any script lane that
  named it. Half a retirement is either dead weight (art with no code) or a
  WHITE SQUARE (code with no art). Five domains were retired half-way before
  anything checked. **And never delete on a name-grep alone** — read the site
  that would use it: the gift gun looked unused because nothing calls
  `GiveWeapon` for it (it is the Death Machine powerup, redirected through
  `level.zombie_powerup_weapon`), while the Mahem rocket looked used because
  its function existed (nothing had called it since 2026-08-20). Full record
  and the numbers behind every claim: `docs/86_xpak_size.md`.
- **UI ART LINT — `tools/lint_tod_assets.js`, runs on EVERY build incl.
  `-GscOnly`** (both its failure modes are pure zone/Lua edits). GATE A, hard
  fail: an image a live path names with no `image,` line — the linker is silent
  and the game draws a WHITE SQUARE. GATE B, gated on regression against
  `lint_tod_assets.baseline.json`: a `CARD_SLUG` slug whose domain is dead, a
  zoned card no slug declares, a dead pause plate. Cards are `uncompressed`
  768x1152, so **one dead card is 3.4 MB of LOAD RAM** — that, not disk, is why
  this matters. The baseline's `why` block records which current numbers are
  accepted (the 10 retired-domain pause plates are deliberate, ~0.5 MB) —
  **never raise a number to make it green.** It parses `domain_id`,
  `add_domain`, `CARD_SLUG`, `CARD_ONE_IMAGE` and `PAUSE_PLATE_MAX` out of the
  live sources, so renames follow automatically. It does NOT model materials,
  GSC-only image refs, or names built from tables it does not read — a pass
  means the modelled lanes agree, not that every image is reachable.
  `tools/lint_tod_assets_selftest.js` breaks the map eight ways (six that must
  fire, two shapes that must not) — run it whenever the lint is edited.
- **THE SUN VOLUME MUST NEVER SHRINK BELOW `SUN_VOLUME_TOP_MIN` (v17.80,
  2026-09-05, docs/107).** `SKY_TOP` in the generator sizes the sky seal AND
  the `volume_sun` brush (the map-wide sun / light-grid volume) as a `max()`
  over the tallest geometry. When v17.69 cut the spire from 100 to 70 laps
  the crown took over, the volume dropped 39,468 → 29,196, and THE WHOLE
  TOWER LIT YELLOW-OLIVE — every surface, the viewmodel, the zombies — on
  default light parameters (light positions honoured, colour and lighting
  state not). Six builds of sky / fog / light / flag reverts changed nothing
  because none of those had changed; the published build had the tall
  volume by accident. Confirmed by a bisect the user looked at both ways;
  the bake's `.led` size is the fingerprint (45,041,494 B good, 44,592,07x
  yellow). The floor is an extra `max()` term; the generator prints
  `ceiling` on every run — 39,468 is right. **When every direct lever fails,
  diff the DERIVED numbers against the published build** (its pack and `.ff`
  are on disk under `steamapps\workshop\content\311210\3788921059`), and
  build the control map (`Repositories\test+map`, the Mod Tools template,
  one look) FIRST, not sixth. Radiant is a GUI exe: `Start-Process -Wait`
  it, or the linker links without a `.led` and prints "Falling back to
  preview lighting".
- **LED bake is a gate** after any geometry change — `tools/_bake_test.ps1`
  prints BAKED/CRASHED (the brush.cpp:1860 lightmap-atlas ceiling; see KB §1).
  **READ IT AS BAKED/CRASHED AND NOTHING ELSE.** Its TIMING is not a budget
  meter: on near-identical input this map has come back 38.2, 126.2, 35.1, 31.9,
  31.3 and 31.8 s — a 4x spread, and the 126.2 was a one-off that never
  reproduced (an A/B with byte-identical geometry ruled out the material
  distribution as the cause). Timing here is dominated by HOST STATE. A single
  bake reading justifies NOTHING; if a number is going to decide something, bake
  twice and A/B it. For the actual budget question run
  `node tools/measure_lit_area.js` — deterministic, instant, and it groups lit
  area by region so you can see what changed (the crown was 67% of the map's on
  2026-09-14 — RUN THE TOOL, the share moves whenever either tower changes).
- **Two ADVISORY crown tools** (not gates, but run them after any crown edit):
  `node tools/measure_lit_area.js` groups lit surface area by region — the crown
  was **67%** on 2026-09-14 (949M of 1409M u²), not the 84% this brief claimed
  for months; that figure predates the spire, which both diluted the share and
  shrank the crown itself. Run the tool rather than quoting a number.
  ⚠️ **AND IT IS A LIGHTMAP-BAKE / VRAM FIGURE, NOT A PER-FRAME DRAW FIGURE** —
  the tool says so in its own header. It was cited as evidence about a runtime
  GPU hang during the 2026-09-14 freeze investigation and answers no such
  question. `node tools/audit_hidden_faces.js` samples every face and
  reports what nothing can see; it found panel stiles, jewel bosses, a keystone,
  an arch segment and the mouth jambs all sealed inside other brushes. Two cases
  are always wrong: buried on ALL SIX faces (pure cost), and a visible face
  COPLANAR with a neighbour in another material (a z-fight). Everything else is
  advisory — a tenon keyed into a wall is supposed to be buried.
- **NOTHING MAY STAND ON THE CAUSEWAY.** The J4 landing is 960 wide (x +-480,
  y 6720-6880 at TOP2) and the crown face is 32 north of it, so anything pushed
  proud lands on walkable deck. NO LINT CATCHES THIS — the misplaced-wall check
  only fires on `clip` with no visible solid, a VISIBLE solid silently drops the
  node, and the flood still walks the middle of a 960-wide landing. gen_tower_map
  section 5f.9 asserts it against the emitted brushes; keep that assert.
- **`tools/lint_tod_geometry.js` is the other geometry gate** — HOLES and
  MISPLACED WALLS, run automatically by `build_map.ps1` before cod2map. Proves,
  whole-map in ~1 s: no invisible blocker where a player stands, no unguarded
  edge, and base→terrace + terrace→citadel still walkable. Gates on REGRESSION
  against `tools/lint_tod_geometry.baseline.json` (currently zero of
  everything). `tools/lint_tod_geometry_selftest.js` breaks the map six ways and
  requires the lint to catch each — run it whenever the lint is edited.
  **If it goes red on a map somebody has WALKED, suspect the lint** (that
  happened twice the day it was written and both times the check was wrong, not
  the map). Never edit the baseline to make it green. It cannot see
  script-spawned collision, prefabs, or the navmesh.
- **IS THE `.ff` ACTUALLY BUILT FROM THIS TREE?** Three different freshness
  checks have now been trusted and been WRONG, so use this one and only this one:
  ```
  diff -rq scripts     <modtools>/usermaps/zm_tower_of_doom/scripts
  diff -rq zone_source <modtools>/usermaps/zm_tower_of_doom/zone_source
  diff -rq ui          <modtools>/usermaps/zm_tower_of_doom/ui
  ```
  (ignore the generated `all/`, `english/`, `loc/` output dirs). Empty = the
  linker consumed exactly this source. The `ui` line was added 2026-08-30
  (v14.18 postmortem): Lua rides in `ui/` as zoned rawfiles, so a Lua-carrying
  change was invisible to the old two-line check — scripts/+zone_source/ clean
  proved nothing about it (sync_to_modtools.ps1:159 mirrors ui/, so it was
  never at RISK, but the doctrine check must COVER what it claims to prove).
  **Do NOT "improve" it by adding
  map_source/** — after any `-GscOnly` the sync makes deployed .map == repo
  .map while the `.ff`'s compiled BSP is a regen behind, so a map_source diff
  passes exactly when it should fail (live 2026-08-28: a `-GscOnly` synced the
  615-entity .map while the `.ff` geometry was still the 611-entity compile;
  the spur risers were "deployed" and absent). scripts/ + zone_source/ + ui/
  is the whole sanctioned check for SOURCE; geometry freshness
  is proven by the FULL build's own regen-count print, nothing else.
  **BUT THAT DIFF ANSWERS A QUESTION ABOUT THE LAST *SYNCER*, NOT THE LAST
  *BUILDER*** (added 2026-09-01, three sessions in one repo). The sync runs at
  the START of a build, so the deployed tree always reflects whoever synced most
  recently. The moment a peer starts a build, deployed == THEIR repo state, the
  diff goes green, and it is now reporting on *their* build-in-progress. Live
  that day: a clean diff was nearly read as "my build consumed this tree" when a
  peer's sync 90 s earlier had already replaced the deployed tree, function
  rename and all. **Pair it with a check that nobody synced after your `.ff`:**
  ```
  find <deployed>/{scripts,ui,zone_source} -type f -newermt "<your .ff timestamp>" \
    | grep -v -E "/all/|/english/|/loc/"
  ```
  Empty = the diff is about YOUR `.ff`. Non-empty = you are reading someone
  else's answer and your verification is **VOID, not passing**. The two are
  COMPLEMENTARY and you need both: the diff catches repo != deployed (an edit
  never synced, or the mid-build edit below), while the `-newermt` catches the
  case a peer's sync would otherwise HIDE — because that sync sets repo ==
  deployed and turns the diff green over everything.
  **An mtime gate cannot answer this**:
  `build_map.ps1` SYNCS AT THE START, so a file edited mid-build is older than
  the `.ff` and newer than the sync — a peer edit 25 s before the `.ff` was
  written was not in it, and `find -newer` called the tree clean.
  And "synced" is not "packed": **a `.gdt` edit is ALWAYS a full build.** The
  MECHANISM claim that used to live here ("-GscOnly runs no gdtdb /update") is
  WRONG for today's script and was corrected 2026-08-30 (v14.16 publish, 87's
  live observation + verified in build_map.ps1: the gdtdb step at ~:226 runs
  on EVERY build, before the -GscOnly branch at :282, and image assets
  demonstrably converted during a -GscOnly). The rule survives on the still-
  true grounds: -GscOnly skips cod2map64 + the LED bake, so anything a GDT
  feeds into the BSP/lighting (materials, model surfaces) links against a
  stale compile — and per-asset conversion coverage under -GscOnly is
  UNPROVEN, not proven-safe. Full-build after GDT edits, same as ever; just
  don't cite the gdtdb line as the reason. (Contrast door PRICES, which
  really are `-GscOnly`.)
- Launch: `PLAY_NORMAL.bat` or `.\tools\run_game.ps1` (steam://run/311210 +
  `+set_gametype zclassic` — the ONE load-bearing arg; never raw exe, never
  Steam Launch Options).
- Mod tools root: `...\Call of Duty Black Ops III 455130` (detected via
  `bin\modlauncher.exe`). Linker builds the DEPLOYED usermaps copy — sync
  before every build (build_map.ps1 does it).

## Hard-won facts inherited from map 1 (the short list — full set in the KB)

- Map-authored `zombie_door` trigger_use entities are DEAD for generated maps —
  `_tod_doors.gsc` disables them and spawns `trigger_radius_use` on BOTH sides
  of each doorway (script-spawned use-triggers need `TriggerIgnoreTeam()`).
  Buy = charge points, set the zone script_flag, hide+notsolid+connectpaths the
  slab. Slab starts `solid(); disconnectpaths();`. **THE ANTI-VAULT CLIP OVER
  A DOOR RIDES IN THE SLAB ENTITY (v16.13)** — a worldspawn clip is permanent
  and outlived the purchase: players jumping down a flight hit "an invisible
  wall above where the door would be" for the rest of the match (both towers,
  153 doors). A clip that must vanish with the door is a second brush of the
  script_brushmodel, never a worldspawn brush.
- GSC dialect: `function` keyword, `#using` before `#namespace`, `#precache`
  only AFTER every `#using`/`#insert` (misplacing it IS a compile kill, live
  2026-08-20 — but **"No generated data for '<file>.gsc'" is NOT a
  precache-specific message**, corrected 2026-08-31: it is what the linker
  prints for ANY compile failure in that file. A dangling variable reference
  produced it verbatim that night. Read it as "this file failed to compile,
  cause unstated" and diff the file against its last building state — never
  as "your #precache is misplaced", or you will audit the one thing that is
  fine. Note `lint_tod_arity.js` PASSES a file with this class of error: it
  checks call arity and symbol resolution, not variable liveness, so the
  linker is the only gate that catches it), ternary fully
  paren-wrapped, no `.field` on parenthesized expr, `class` reserved,
  `"power_on"`/`"initial_blackscreen_passed"` are FLAGS (`flag::wait_till`),
  never write `player.score` (use `zm_score::`), read-only damage callbacks
  MUST `return -1`.
- Navmesh ignores ALL entity collision → any script-spawned solid needs
  `DisconnectPaths()` (and `ConnectPaths()` when cleared).
- Playable space below z=-1000 triggers the stock below-world zombie failsafe —
  this tower goes UP, so not an issue here.
