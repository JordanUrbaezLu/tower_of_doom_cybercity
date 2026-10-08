# 43 — Sound audit: every SFX moment in the map

**2026-08-29.** A map-wide sweep of what the player HEARS, run because the user
bought an ElevenLabs subscription and wants bespoke SFX. 17 agents swept 8
subsystems and verified each other; 170 unique moments survive below, plus a
completeness pass that found the powerups subsystem nobody had covered.

**How to use this:** each row has an ID. Work them one at a time — pick an ID,
get an ElevenLabs prompt written for it, bake the wav, install it with the
recipe in §3. Do NOT try to do them in bulk; every sound wants its own listen.

---

## 0. PROGRESS

| item | what | status |
|---|---|---|
| `ECON` teleporter | 2.2s warp at the pad on trigger | **DONE 2026-08-29** USER-VERIFIED. — `tod_teleport_fire`, `_tod_teleport.gsc:496`. Emitted at SRC; rider hears the first 0.8s, then the arrival discharge. Side effect: `tod_warp` now only marks the two discharges, so departure and arrival differ. |
| `ECON` teleporter ready | recharge-complete chime as the beam relights | **DONE 2026-08-29** USER-VERIFIED. — `tod_teleport_ready`, `_tod_teleport.gsc:426`. Gated on the recharge->ready EDGE only: `refresh()` also runs once per pad at spawn, and ungated it would have chimed every teleporter in the map during spawn-in. Tighter falloff (2000) than the warp (2800) so a pad 15 floors down is not audible. |
| `UPG` headshot ding | Apex ding on a headshot KILL | **DONE 2026-08-29** USER-VERIFIED (the asset's two transients were kept — the user signed off on the double). — `tod_headshot_ding`, `_tod_luck.gsc:283`. Map 1 asset (`accxheadshot_ding.wav`) at the user's request, now VENDORED into this repo. Alias row is a byte-shape clone of map 1's proven `acc_headshot_ding`; UIN_MOD's LimitCount=2/oldest is what keeps the 2.25s tail from stacking, so it was deliberately NOT "improved" with pitch variance. |
| `UPG` luck ladder | rising pip per HUD luck segment | **DONE 2026-08-29** USER-VERIFIED at vol 84. — `tod_luck_pip01..10`, `_tod_luck.gsc:235`. ONE generated pip, ten rungs derived in ffmpeg as a major scale over 16 semitones (asetrate + atempo, equal length). Fires on UPWARD segment crossings only, so the post-event reset to 0 is silent. 0.12s delay so it answers the headshot ding rather than colliding with it. |
| `PRK` perk drink | bottle cap-pop + gulp on a perk buy | **DONE 2026-08-29** — `_tod_perk_drink.gsc`, aliases `tod_perk_open` / `tod_perk_gulp`. Timing tuned by the user in game over three passes; USER-VERIFIED 2026-08-29 at 0.65 / 0.90, cap wav trimmed to its transient (fizz removed). |

**Timing is settled, and how it settled is the useful part.**

| knob | final | 
|---|---|
| `TOD_DRINK_OPEN_DELAY` | **0.65** — bottle cap, after `perk_purchased` |
| `TOD_DRINK_GULP_DELAY` | **0.90** — gulp, after `perk_purchased` |

Both are ABSOLUTE from the buy. The first pass anchored the gulp on the engine
event `weapon_change_complete` — reasoning that a real event beats a tuned
constant. That was wrong in a way worth remembering: the event fires when the
bottle is already back DOWN, so it marks the end of the drink, not the moment it
reaches the lips. **An event anchor only beats a constant when the event marks the
moment you actually want** — anchoring to the nearest available event and nudging
with an offset just hides a constant behind a false guarantee.

**TRIM TO THE TRANSIENT BEFORE YOU TUNE.** The cap wav originally held two blocks —
a cap crack (0->0.16) and a swelling carbonation fizz (0.31->0.94) — so the
constants did not correspond to when anything was audible: the number said 0.55
and the player heard the pop at ~0.85, with the fizz running on under the gulp.
The wav is now the crack only (0.20s, starting on the transient), so the constant
IS the moment. Apply this to every future cue: an untrimmed lead-in makes every
timing number wrong by however much silence the asset carries.

Retunes stayed cheap throughout: the wavs were in the bank after one FULL build, so
each timing pass was a `-GscOnly` (~4 min). That is the pattern for every remaining
row — pay the FULL build once for the asset, then walk the timing in.

**Bank-verification note for every future sound in this doc:** do NOT verify a
new sound landed by comparing `.sabs` sizes. `.sabs` is the STREAMED bank and only
moves for rows carrying `Storage=STREAMED` (the six music beds). One-shot SFX go
to `.sabl`. The size-independent check is to grep the packed `.sabl` for the WAV
FILENAME (banks index the file, not the alias) — a control that should return 0
is `tod_ui_tick`, whose FileSpec is `glass_cling.wav`.
---

## 1. THE THREE REAL BUGS — fix these first, they cost no credits

The audit's most valuable output is not a wish-list, it is three aliases that
**do not exist**, so the calls that name them play nothing. All three were
found by reasoning "not in any CSV the szc loads", and that reasoning produced
**seven false alarms for every two true ones** — see §2 — so each of these was
re-checked against (a) every alias CSV in the repo AND the tools root, (b) map
1's shipped-asset dump (`docs/stock_models_full.txt`, 157 `zmb_*` sounds), and
(c) whether any stock Treyarch script references it.

| # | alias | call sites | evidence it is undefined | fix |
|---|---|---|---|---|
| **B1** | `zmb_no_purchase` | **23**, across 6 modules — every refusal in the map | absent from all CSVs, absent from the stock dump, **0** references in any stock Treyarch script. The real stock alias is `zmb_no_cha_ching` (used by `_zm.gsc`, present in the dump). | sed the 23 sites to `zmb_no_cha_ching`. One-word change, `-GscOnly` build. |
| **B2** | `cw_mus_perks_packa_sting` / `cw_mus_perks_packa_jingle` | `zm_cwpap.gsc:111,142,384` + `_tod_powerups.gsc:475` | the vendored pack defines these **without** the `cw_` prefix — `mus_perks_packa_sting` / `mus_perks_packa_jingle` are both in `tools/share/raw/sound/aliases/zm_cwpap_sound.csv`. The `cw_`-prefixed names exist nowhere. | drop the `cw_` prefix at the 4 call sites. Pack-a-Punch gets its jingle back. |
| **B3** | Panzer arrival cue never fires | `mechz_spiki.gsc:2852` | the sound is built, precached, loaded and wired to a client callback (`mechz_spiki.csc:344` plays `zmb_mechz_spawn_nofly`), but the `clientfield::increment("mechz_fx_spawn")` that triggers it is in a function nothing calls. | one line. **No new asset needed** — the Panzer's own arrival roar is already in the build, just unreachable. |

**B1 is the highest-value line in this whole document.** 23 call sites, one
word, and it is the difference between "the map has no deny feedback" and "the
map has deny feedback". It is also **10 seconds to confirm in game**: stand at
any door with too few points and press USE. If you hear nothing, B1 is real.
Per the repo's own doctrine — reversible + instantly visible in game → ship the
guess, the user testing IS the measurement.

**Caveat, stated plainly:** the stock dump is map 1's asset listing and is not
guaranteed to enumerate every shipped alias. Three independent signals agree
for B1, but the in-game test is decisive and costs nothing. B2 is certain (the
prefix mismatch is visible in the CSV). B3 is certain (the call site is absent).

---

## 2. WHAT THE AUDIT GOT WRONG — read this before trusting any "BROKEN" row

Multiple agents independently concluded that `zmb_cha_ching` is undefined and
therefore **"THE ENTIRE ENDING IS SILENT"**. That is false. Stock aliases
resolve from the shipped game banks, not from the usermap's CSVs, and
`zmb_cha_ching` is used by stock `_zm_blockers.gsc` for every stock door buy.

Every claimed-undefined alias, resolved:

| alias | agents said | actually |
|---|---|---|
| `zmb_cha_ching` | UNDEFINED — ending is silent | **stock, fine** |
| `zmb_rocketshield_imp` | UNDEFINED | **stock, fine** |
| `zmb_perks_power_on` | UNDEFINED | **stock, fine** |
| `zmb_perks_machine_loop` | UNDEFINED | **stock, fine** |
| `zmb_perks_bump_bottle` | UNDEFINED | **stock, fine** |
| `zmb_switch_flip`, `zmb_turn_on` | UNDEFINED | **stock, fine** |
| `evt_perk_deny` | UNDEFINED | **defined** in `acc_audio.csv` |
| `zmb_powerup_grab` | UNDEFINED — powerups silent | **misread**; stock calls `zmb_powerup_grabbed`, which is defined |
| `zmb_no_purchase` | UNDEFINED | **correct — B1** |
| `cw_mus_perks_packa_*` | UNDEFINED | **correct — B2** |

So: the `cha_ching` rows below are **recycled, not broken**. They are still
worth fixing — a cash register announcing the finale is a real problem — but it
is an aesthetic problem, not a bug. Nothing in the ending is silent.

This is the repo's own "cheap to change is not the same as cheap to be wrong
about" rule, live: a wrong yaw reverts with one build, a wrong claim sends you
hunting a phantom.

---

## 3. THE INSTALL RECIPE — how one ElevenLabs wav becomes a sound in the map

**Step 1 — bake the wav to spec.** The bank builder hard-rejects anything else:

```
ffmpeg -i eleven.mp3 -ar 48000 -sample_fmt s16 -ac 2 sound_assets/tod/sfx/tod_<name>.wav
```

48000 Hz, 16-bit PCM. 44.1k fails with `wav is not 48k sample rate`.

**Step 2 — add ONE row to `sound/aliases/tod_ui.csv`.** The CSV has 102
columns and almost all stay blank. Copy an existing row and change only `Name`
and `FileSpec`:

*2D — a UI sound, in the player's head, full volume, no falloff (7 columns):*

| Name | FileSpec | Template | VolMin | VolMax | PanType | Looping |
|---|---|---|---|---|---|---|
| `tod_your_name` | `tod\sfx\tod_your_name.wav` | `UIN_MOD` | `92` | `92` | `2d` | `NONLOOPING` |

*3D — a world sound that attenuates (adds 9 more):* also set `ReverbSend=0`,
`CenterSend=0`, `DistMin`, `DistMaxDry`, `DistMaxWet`, `StartDelay=0`,
`EnvelopMin/Max/Percent=0`, and `PanType=3d`. Model row is `tod_warp`
(`DistMin 250 / DistMaxDry 2800 / DistMaxWet 3200`).

**Step 3 — call it.** Which call matters as much as the sound:

| call | who hears it | use for |
|---|---|---|
| `player PlayLocalSound( alias )` | that player only, 2D, full volume | UI, cards, your own procs |
| `player PlaySound( alias )` | everyone, 3D at the player | buys, denials |
| `PlaySoundAtPosition( alias, org )` | everyone, 3D at a point | world events with no entity |
| `ent PlayLoopSound( alias )` | 3D loop — **needs the stop ritual** | idles, hums, beds |

Loops are the trap: stopping one wrong leaves it ringing forever. The recipe is
in `_tod_atmosphere.gsc:60-70` — `StopLoopSound(0)` + `StopSound(alias)` +
`StopSounds()` + a deferred `Delete()`. Client-side `StopLoopSound` takes the
**handle** `PlayLoopSound` returned; server-side it takes a fade time. That
signature difference already cost this map one beta bug
(`zm_weap_xmas_gun.csc:102-150`).

**Step 4 — build.** A new alias row is a **FULL build**, never `-GscOnly` —
`-GscOnly` runs no sound-bank step, so it copies the CSV and packs nothing,
leaving a tree that *looks* current. (Door prices really are `-GscOnly`; sound
never is.)

**Ceilings:** no alias-count limit like the ~200 weapon-twin guard — the szc
loads 12 alias CSVs today and `tod_weapons.csv` alone carries 762 rows. But
**`Template=UIN_MOD` silently caps every sound at 2 simultaneous copies and
pitch variation 0** (`share/raw/sound/templates/template_mod.csv:3`). For
anything that can fire in bursts — cleave, impact rounds, footstep-adjacent
procs — set `LimitCount` and `PitchMin/PitchMax` explicitly on the row.

---

## 4. THE TABLE

`pri` H/M/L. `state`: **silent** = no sound call on that path at all;
**recycled** = a stock or map-1 sound standing in; **bug?** = suspected
non-functional (re-verify against §2 before acting). `work`: `alias` = swap the
wav only, `alias+1line` = new row + one GSC line, `code` = real logic,
`map regen` = generator change + full rebuild.


### FIN — The ending — extraction, the road, the crown  (33)

| id | pri | state | the moment | site | plays now | work |
|---|---|---|---|---|---|---|
| `FIN-01` | **H** | recycled | You spend 12,000 points at the terrace uplink and start the ending — the 191-second run for the Crown, irreversible, one per game. It sounds exactly l | `_tod_finale.gsc:596` | `zmb_cha_ching` | alias+1line |
| `FIN-02` | **H** | recycled | Five more finale beats that all play the same cash register: the causeway gate opening, a pylon igniting (x4 during the siege), the hall lighting itse | `_tod_finale.gsc:375` | `zmb_cha_ching` | alias+1line |
| `FIN-03` | **H** | recycled | Extraction is live. The banner says RUN FOR THE CROWN and the map's single most important instruction — the one thing the design brief says a player g | `_tod_finale.gsc:829` | `zmb_cha_ching` | alias+1line |
| `FIN-04` | **H** | recycled | You are standing on the terrace and haven't bought extraction yet. Every 4 seconds the uplink terminal flashes and goes 'cha-ching'. | `_tod_finale.gsc:499` | `zmb_cha_ching` | alias+1line |
| `FIN-05` | **H** | recycled | 90 seconds of road are over. The citadel's gate crashes down behind you, the ground shakes, and you are sealed inside the crown for the siege. | `_tod_finale.gsc:423` | `zmb_cha_ching` | alias+1line |
| `FIN-06` | **H** | silent | The song's last chord. You survived 191 seconds of ambushed road and a sealed siege, the pad turns green, six seconds of departure — and 'YOU ESCAPED  | `_tod_finale.gsc:1602` | `—` | alias+1line |
| `FIN-07` | **H** | silent | The six-second departure: you're invulnerable, the crown's four points strobe green, the whole avenue of pylons down the dead road strobes green with  | `_tod_finale.gsc:1629` | `—` | alias+1line |
| `FIN-08` | **H** | silent | Running the road, you look up and the ruby pendant hanging under the crown is pulsing red — and it pulses FASTER the closer you get, until you're unde | `_tod_finale.gsc:1387` | `—` | alias+1line |
| `FIN-09` | **H** | recycled | You cross the last gold portal into the crown's throat and the citadel accepts you — a ripple of light walks the floor from the gate to the dais and t | `_tod_finale.gsc:1295` | `zmb_cha_ching` | alias+1line |
| `FIN-10` | **H** | silent | Bought extraction; three cyan portal frames and eight jewelled gold obelisks flanking the road all light up blue at once — the avenue switching on to  | `_tod_finale.gsc:1171` | `—` | code |
| `FIN-11` | **H** | silent | Walking the road itself: the fork, the Ridge crest, the Broken Stair's blind pockets, the Narrows pinching to single-file, the Undercroft's plunge int | `none — no call site exists` | `—` | code |
| `FIN-12` | **H** | silent | The song's first drop. The sky tears open over the Narrows and the Panzer comes down astride the choke, right as you reach it. | `_tod_bosses.gsc:513` | `—` | alias+1line |
| `FIN-13` | **H** | recycled | ADDED — the buy frame itself: pressing USE on the uplink fires up to FIVE copies of one stock alias inside a single server frame. | `_tod_finale.gsc:618` | `zmb_cha_ching` | code |
| `FIN-14` | **H** | bug? | The Crown's gate slams shut behind you, sealing the party inside the citadel for the hold-out. You hear a cash register. | `_tod_finale.gsc:423` | `zmb_cha_ching` | alias+1line |
| `FIN-15` | **H** | bug? | Standing on the terrace before you buy extraction, the uplink beacon pulses at you every 4 seconds — with the purchase cash-register sound. | `_tod_finale.gsc:499` | `zmb_cha_ching` | alias+1line |
| `FIN-16` | **H** | bug? | The road ambush: a lane you were about to take slams shut behind a red-lit seal, forcing you down a different branch of the causeway mid-run. Cash reg | `_tod_finale.gsc:1486` | `zmb_cha_ching` | alias+1line |
| `FIN-17` | **H** | silent | You wipe. The screen cuts to the intermission camera, GAME OVER fades in over your body, and the map goes completely quiet — the climb music you have  | `_tod_gameover.gsc:58` | `—` | alias+1line |
| `FIN-18` | **H** | bug? | You buy a door, an ammo crate refill, a Pack-a-Punch, an upgrade at the personal station, a teleport, the 12k EXTRACTION — and hear NOTHING. No cha-ch | `_tod_doors.gsc:329` | `zmb_cha_ching — UNDEFINED in t` | alias |
| `FIN-19` | **H** | bug? | You stand at a door with 200 points and press USE. Nothing. No deny buzz, no feedback — indistinguishable from a broken trigger. Same at every crate,  | `_tod_doors.gsc:324` | `zmb_no_purchase — UNDEFINED in` | alias |
| `FIN-20` | **H** | bug? | THE ENTIRE ENDING IS SILENT. You buy extraction, the causeway gate dissolves, four pylons ignite one by one, the sconces sweep the hall, the crown doo | `_tod_finale.gsc:375` | `zmb_cha_ching` | alias+1line |
| `FIN-21` | M | silent | The song ends and NOBODY is inside the citadel — everyone died on the road or in the doorway. The run is over and you lost it. | `_tod_finale.gsc:730` | `—` | alias+1line |
| `FIN-22` | M | recycled | Extraction fires and, somewhere out on the road you can't see yet, two of the six lanes wall themselves off — the run rerolls which paths exist. | `_tod_finale.gsc:1486` | `zmb_cha_ching` | alias+1line |
| `FIN-23` | M | recycled | One quarter of the siege survived. A point on the crown 4,400 units above you lights up gold. Four of these are your only progress read on the hold-ou | `_tod_finale.gsc:1123` | `zmb_cha_ching` | alias+1line |
| `FIN-24` | M | recycled | You're the first one into the crown; as each teammate makes it through the gate behind you, one of the four hall pillars snaps from red to green. | `_tod_finale.gsc:1377` | `zmb_cha_ching` | alias+1line |
| `FIN-25` | M | silent | The road phase ends and you are yanked off the causeway into the middle of the crown hall, facing inward, a fraction of a second before the gate slams | `_tod_finale.gsc:981` | `—` | alias+1line |
| `FIN-26` | M | silent | You bled out on the road during the finale, respawn at the round turnover — and get instantly teleported into the sealed crown to rejoin the siege. | `_tod_finale.gsc:1065` | `—` | alias+1line |
| `FIN-27` | M | recycled | The song ends, you survived the siege, and the extraction pad at the back of the hall flips from red to green — EXTRACTION INBOUND. | `_tod_finale.gsc:789` | `zmb_cha_ching` | alias+1line |
| `FIN-28` | M | silent | You spend the whole 90-second road run heading for one thing — the extraction pad at the far end of the crown hall. It makes no sound at any point unt | `_tod_finale.gsc:304` | `—` | alias+1line |
| `FIN-29` | M | recycled | You buy the last door, climb the crown stair, and step onto the terrace — the first time you see the crown, the causeway and the drop. | `_tod_doors.gsc:329` | `zmb_cha_ching` | code |
| `FIN-30` | M | recycled | ADDED — the seal's 3D sound plays at a spot the party was teleported away from one frame earlier. | `_tod_finale.gsc:707` | `zmb_cha_ching` | alias+1line |
| `FIN-31` | M | recycled | You climb 10 floors of open-air staircase and step through a doorway into an enclosed breather lounge — roof, walls, window band, one theme colour. Yo | `sound/zoneconfig/zm_tower_of_doom.szc:77` | `global_urban_outdoor` | code |
| `FIN-32` | M | silent | You buy EXTRACTION at the terrace. Over the next fifteen seconds the whole sky turns from cold purple-blue to ember red and the void under the causewa | `_tod_atmosphere.gsc:315` | `none on the weather ramp itsel` | alias+1line |
| `FIN-33` | L | ok | The uplink refuses you — no power, not enough points, or an upgrade event is running. | `_tod_finale.gsc:568` | `zmb_no_purchase` | alias |

### UPG — The upgrade cards + luck bar  (41)

| id | pri | state | the moment | site | plays now | work |
|---|---|---|---|---|---|---|
| `UPG-01` | **H** | silent | The upgrade event fires: mid-fight, the whole world stops. Zombies freeze mid-lunge at 5% animation rate, spawning halts, every device in the map refu | `_tod_upgrades.gsc:1790` | `—` | alias+1line |
| `UPG-02` | **H** | silent | Two cards deal onto your screen. If neither rolled SUPER or ULTIMATE — which is the common case — they arrive in total silence. | `_tod_upgrade_ui.gsc:430` | `—` | alias+1line |
| `UPG-03` | **H** | recycled | A card comes up ULTIMATE — +3 levels, the jackpot, and at a full luck bar it is guaranteed. | `_tod_upgrade_ui.gsc:438` | `tod_ultimate_sting` | alias |
| `UPG-04` | **H** | recycled | You draw the CLASS TIER card and take it: your gun is destroyed and replaced with the next rung of your class ladder — MAC-10 becomes MP5, Krig become | `_tod_upgrades.gsc:2566` | `tod_ultimate_sting` | alias+1line |
| `UPG-05` | **H** | recycled | You hold jump (or F) for a third of a second and the card locks in. This is the commit — the one irreversible input in the whole event. | `_tod_upgrade_ui.gsc:693` | `tod_ui_lock` | alias |
| `UPG-06` | **H** | silent | You are still reading the two cards, the 15-second timer runs out, and the focused card locks itself in. Nothing marks it — the panel just flashes and | `_tod_upgrade_ui.gsc:758` | `—` | alias+1line |
| `UPG-07` | **H** | silent | Your luck bar fills all run — every kill, every headshot at 1.5x, every revive, every door you buy — and then empties to zero the instant an upgrade e | `_tod_luck.gsc:207` | `—` | code |
| `UPG-08` | **H** | silent | Your luck bar crosses 50%, then 100%. At 50 your next deal is guaranteed to contain a SUPER; at 100 it is guaranteed to contain an ULTIMATE. The playe | `_tod_upgrades.gsc:2157` | `—` | code |
| `UPG-09` | **H** | silent | You pick IMPACT ROUNDS, and from then on some of your bullets burst into up to six nearby zombies for 40% of the hit. There is no explosion sound, no  | `_tod_upgrades.gsc:3008` | `—` | code |
| `UPG-10` | **H** | silent | You pick CLEAVE, and your blade starts carrying through into one or two extra zombies beside the one you swung at. They die without a sound — no secon | `_tod_upgrades.gsc:3285` | `—` | alias+1line |
| `UPG-11` | **H** | silent | You pick KILL RELOAD. Every 50th, 75th or 100th kill, a full magazine slams into your gun mid-fight. Your ammo counter jumps to full and you hear abso | `_tod_upgrades.gsc:3582` | `—` | alias+1line |
| `UPG-12` | **H** | silent | You take a twin upgrade — FIRE RATE, RECOIL, MAG SIZE, HANDLING, PENETRATION or KNIFE SPEED — and the game silently swaps the weapon in your hands for | `_tod_upgrades.gsc:1587` | `—` | alias+1line |
| `UPG-13` | **H** | recycled | You walk up to the HEAVENLY GIFT ALTAR, hold F, and pay 2,000+ points for a card roll. It goes cha-ching — the same cha-ching as buying a door, buying | `_tod_upgrades.gsc:4011` | `zmb_cha_ching` | alias+1line |
| `UPG-14` | **H** | silent | You kill the Panzer. He was the round's centrepiece, he had his own music track, and the last hit takes the entire luck bar. The music swaps back to t | `_tod_bosses.gsc:1423` | `—` | alias+1line |
| `UPG-15` | **H** | silent | CLEAVE fires: your blade carries through the zombie you hit into one or two more standing beside it. | `_tod_upgrades.gsc:3305` | `—` | alias+1line |
| `UPG-16` | M | silent | The cards vanish, the world snaps back, and forty zombies that were standing still resume sprinting at you all at once. | `_tod_upgrades.gsc:1904` | `—` | alias+1line |
| `UPG-17` | M | recycled | A SUPER-rarity upgrade card is dealt — the second-loudest progression sting in the map, heard several times a run from round 1 onward. | `_tod_upgrade_ui.gsc:440` | `tod_super_sting` | alias |
| `UPG-18` | M | recycled | You tap the d-pad (or A/D, or melee/reload) and the highlight jumps from the left card to the right one. | `_tod_upgrade_ui.gsc:674` | `tod_ui_tick` | alias |
| `UPG-19` | M | silent | You press and hold to lock a card. A progress bar fills under it over 0.325s and the card's blink doubles in speed. There is no sound at all until it  | `_tod_upgrade_ui.gsc:689` | `—` | code |
| `UPG-20` | M | silent | The 15-second choice timer ticks down from 15 to 0 in the corner of the card panel while zombies stand frozen around you. | `_tod_upgrade_ui.gsc:543` | `—` | alias+1line |
| `UPG-21` | M | silent | You pick BULLET FEED as the heavy. From then on, single rounds trickle into your magazine on their own — every 3 seconds at Lv1, every 0.75s at Lv10 — | `_tod_upgrades.gsc:1435` | `—` | alias+1line |
| `UPG-22` | M | silent | You pick LEECH as the slasher and every blade kill heals you. Health returns with no sound — the only cue is the health vignette receding. | `_tod_upgrades.gsc:3498` | `—` | alias+1line |
| `UPG-23` | M | silent | You pick ADRENALINE and every kill stacks a burst of movement speed, up to three stacks for four seconds. You get faster and faster and nothing tells  | `_tod_upgrades.gsc:3510` | `—` | code |
| `UPG-24` | M | silent | A Panzer hits you from behind while you have BACK ARMOR, or a zombie hits you mid-sprint while you have SPRINT ARMOR. The damage is cut by up to 30%.  | `_tod_upgrades.gsc:1118` | `—` | code |
| `UPG-25` | M | silent | You pick DRAW CUT and your katana swings out of a sprint hit for up to +150%. The big swing sounds exactly like the small swing. | `_tod_upgrades.gsc:2947` | `—` | alias+1line |
| `UPG-26` | M | silent | You pick SUPPRESSING FIRE with the HK21 and your bullets slow the horde by up to 36% for a second and a half. The zombies just... move slower. Nothing | `_tod_upgrades.gsc:2999` | `—` | code |
| `UPG-27` | M | recycled | You try to use an altar and it refuses — you cannot afford it, you have spent this one five times, everything is already maxed, or a round event is ru | `_tod_upgrades.gsc:3979` | `zmb_no_purchase` | alias+1line |
| `UPG-28` | M | silent | You pay for an altar roll, both cards turn out to be dead (a round event maxed those domains while you were deciding), and the game silently refunds y | `_tod_upgrades.gsc:4254` | `—` | alias+1line |
| `UPG-29` | M | silent | You walk past a Heavenly Gift Altar. It is a large glowing Pack-a-Punch machine standing against the tower core, and it makes no sound at all — you ca | `_tod_upgrades.gsc:3671` | `—` | alias+1line |
| `UPG-30` | M | recycled | An armored, chain-mailed zombie sprints at you far faster than the horde, and your bullets do a third damage. Its only audio identity is a generic rio | `_tod_upgrades.gsc:2831` | `zmb_rocketshield_imp` | code |
| `UPG-31` | M | bug? | The world freezes for an upgrade card pick — zombies stop mid-stride, everything holds still — and the Rogue Protectors' hover hums keep humming at fu | `_tod_upgrades.gsc:2634` | `fly_civil_protector_loop` | code |
| `UPG-32` | M | silent | You bled out, watched the fight from above for a while, and then you are just back — standing on a respawn pad, alive, with no transition of any kind. | `tmp/bo3_stock_ref/scripts/zm/_zm.gsc:3231` | `—` | alias+1line |
| `UPG-33` | M | bug? | You empty an LMG into a sprinting zombie and the bullets that get eaten by the sprint-armor upgrade make no ricochet clank — the mitigation is invisib | `_tod_upgrades.gsc:2831` | `zmb_rocketshield_imp — UNDEFIN` | alias |
| `UPG-34` | M | silent | Reaching SLASHER tier 3 also grants THOR'S THUNDER at level 1 — a brand-new power you did not pick. | `_tod_upgrades.gsc:2541` | `—` | alias+1line |
| `UPG-35` | M | recycled | THOR'S THUNDER strikes — the SLASHER tier-3 payoff, a lightning bolt on a melee kill. | `_tod_upgrades.gsc:3189` | `tod_thor_clap` | alias |
| `UPG-36` | L | silent | You go down. On top of everything else, 25% of your luck bar drains away. | `_tod_luck.gsc:285` | `—` | alias+1line |
| `UPG-37` | L | ok | ADDED BY VERIFICATION — the counter-example the audit missed. You pick THOR/TESLA and call lightning down: at Lv1 a localized zap, at Lv2+ a randomize | `_tod_upgrades.gsc:3183` | `tod_thor_storm1 / tod_thor_sto` | alias |
| `UPG-38` | L | ok | ADDED BY VERIFICATION — the throttle precedent, stated exactly. SCAVENGER pays you ammo every Nth kill and clinks, but only when ammo actually landed  | `_tod_upgrades.gsc:851` | `tod_scavenger` | alias |
| `UPG-39` | L | recycled | You use an upgrade altar for the fifth time and it is permanently spent for you — the map's mechanism for pushing you further up the tower. The hint t | `_tod_upgrades.gsc:3941` | `zmb_no_purchase` | alias+1line |
| `UPG-40` | L | silent | The last player locks in, the frozen zombies unfreeze, the world resumes and round 1 actually begins. | `_tod_class_select.gsc:108` | `—` | alias+1line |
| `UPG-41` | L | recycled | Walking the spiral as a HEAVY (move scale 0.75) versus as a SLASHER (1.1) — the two extremes of the roster, 47% apart in speed. | `_tod_upgrades.gsc:991` | `stock BO3 zombie-mode footstep` | code |

### PRK — Perks  (28)

| id | pri | state | the moment | site | plays now | work |
|---|---|---|---|---|---|---|
| `PRK-01` | **H** | silent | You buy a stairwell door — the slab that was blocking the flight simply blinks out of existence and you walk through. 53 times a run. | `_tod_doors.gsc:341` | `—` | alias+1line |
| `PRK-02` | **H** | recycled | You step on a teleporter pad, it charges and fires — and you arrive at the far end to the exact same sound you just left behind. | `_tod_teleport.gsc:518` | `tod_warp` | code |
| `PRK-03` | **H** | recycled | You throw the power switch at the bottom of the tower — the run's biggest single state change (every perk, every Pack-a-Punch, every teleporter comes  | `tools/gen_tower_map.js:4135` | `zmb_switch_flip + zmb_turn_on` | code |
| `PRK-04` | **H** | bug? | You buy Elemental Pop and it sings SPEED COLA's cue at you — and the real Speed Cola machine, somewhere else in the tower, sings the same one. | `_tod_perk_electric_cherry.gsc:238` | `mus_perks_speed_jingle / mus_p` | alias+1line |
| `PRK-05` | **H** | silent | You flip the power switch at the bottom of the tower. Nine perk machines light up across fifty floors — and you, standing at the switch, hear essentia | `_tod_perk_lights.gsc:264` | `—` | code |
| `PRK-06` | **H** | silent | You fall — off the spiral, off a breather balcony, off the causeway — and PhD Flopper saves you. Nineteen thousand units of drop and you land with zer | `_tod_perk_phd.gsc:248` | `—` | alias+1line |
| `PRK-07` | **H** | silent | Every four rounds the perk machines all pick up and move. If you are not standing on a breather balcony at that exact moment, nothing tells you it hap | `_tod_perk_scatter.gsc:789` | `—` | code |
| `PRK-08` | **H** | recycled | A perk machine dematerializes off its pad during a reshuffle. | `_tod_perk_scatter.gsc:710` | `tod_warp` | alias+1line |
| `PRK-09` | **H** | recycled | A perk machine materializes 60 units above an empty pad and glides down onto it. | `_tod_perk_scatter.gsc:712` | `tod_warp` | alias+1line |
| `PRK-10` | **H** | silent | You are shooting and a zombie suddenly bursts into flame and burns down over three seconds — with no sound of any kind. | `_tod_perk_electric_cherry.gsc:365` | `—` | alias+1line |
| `PRK-11` | **H** | silent | You are shooting and a zombie suddenly slows to a crawl for three seconds — with no sound and no visual. | `_tod_perk_electric_cherry.gsc:385` | `—` | alias+1line |
| `PRK-12` | **H** | silent | You go down. Every perk you bought — five, six, eight thousand points each — is stripped off you, and nothing makes a sound. | `_tod_perk_scatter.gsc:200` | `—` | code |
| `PRK-13` | **H** | recycled | An Elemental Pop proc fires. All three of its wildly different outcomes — a chain lightning arc, a zombie set on fire, a zombie frozen solid — announc | `_tod_perk_electric_cherry.gsc:306` | `tod_elemental_pop_proc` | code |
| `PRK-14` | M | silent | You walk up to a dark, unpowered perk machine before the switch is on, press USE, and absolutely nothing happens — no clunk, no deny, no acknowledgeme | `_tod_perk_lights.gsc:76` | `—` | code |
| `PRK-15` | M | recycled | A machine's 0.8-second glide touches down on its new pad with a ka-chunk. | `_tod_perk_scatter.gsc:769` | `zmb_perks_power_on` | alias+1line |
| `PRK-16` | M | silent | You are standing on a breather pad when a machine materializes on top of you and the game shoves you sideways out from under it. | `_tod_perk_scatter.gsc:773` | `—` | alias+1line |
| `PRK-17` | M | recycled | Every perk machine in the tower periodically sings its full Treyarch jingle to itself — over the top of the map's own climb music. | `_tod_perk_lights.gsc:264` | `mus_perks_jugganog / speed` | code |
| `PRK-18` | M | silent | PhD Flopper triggers: you hit the floor in last stand and detonate, killing everything around you. | `_tod_perk_phd.gsc:288` | `—` | alias+1line |
| `PRK-19` | M | recycled | An Elemental Pop shock proc arcs into a cluster of zombies and stuns or kills them. | `_tod_perk_electric_cherry.gsc:322` | `zmb_elec_jib_zombie` | alias+1line |
| `PRK-20` | M | recycled | PhD Flopper's machine sings Mule Kick's jingle — a perk that no longer exists on this map. | `_tod_perk_phd.gsc:234` | `mus_perks_mulekick_jingle / mu` | alias+1line |
| `PRK-21` | M | silent | On solo, at the power flip, Quick Revive quietly swaps to its lit mesh and becomes buyable — while every other machine in the tower gets stock's power | `_tod_perk_lights.gsc:121` | `—` | alias+1line |
| `PRK-22` | M | bug? | A perk machine glides across the map during the every-4-rounds scatter and touches down on a breather pad. It shakes, the derez burst fires — and it l | `_tod_perk_scatter.gsc:769` | `zmb_perks_power_on — UNDEFINED` | alias |
| `PRK-23` | L | recycled | ADDED WHILE VERIFYING. Every 4 rounds the eight perk machines derez off their pads and rematerialise somewhere else in the tower. Departure and arriva | `_tod_perk_scatter.gsc:710` | `tod_warp` | alias |
| `PRK-24` | L | recycled | You press USE on a perk you already own, or without enough points — and get a stock buzzer plus a stock character voice line sighing at you. | `_tod_perk_scatter.gsc:200` | `evt_perk_deny` | code |
| `PRK-25` | L | recycled | Solo, after your third Quick Revive purchase, the machine lifts off the base floor, wobbles, flies away and vanishes in a puff. | `_tod_perk_scatter.gsc:225` | `zmb_box_move + zmb_whoosh + zm` | code |
| `PRK-26` | L | UNVERIFIED | You brush past a perk machine and the bottles inside rattle. Except we do not actually know whether they do. | `_tod_perk_scatter.gsc:730` | `zmb_perks_bump_bottle` | code |
| `PRK-27` | L | silent | The run starts. The perk machines have already been dealt to random pads across four breather balconies while the blackscreen was up, and nothing ever | `_tod_perk_scatter.gsc:474` | `—` | code |
| `PRK-28` | L | recycled | Three of the map's authored UI sounds are not this map's sounds. The class draft opens on map 1's reactor, every menu tick is map 1's glass cling, and | `sound/aliases/tod_ui.csv:2` | `tod_ui_tick -> acc\fx\glass_cl` | alias+1line |

### BOSS — Bosses + special enemies  (18)

| id | pri | state | the moment | site | plays now | work |
|---|---|---|---|---|---|---|
| `BOSS-01` | **H** | recycled | The Panzer is falling. You look up and hear him coming. | `_tod_bosses.gsc:484` | `fly_civil_protector_loop` | alias+1line |
| `BOSS-02` | **H** | silent | The Panzer sets you on fire. His flame cone sprays out and you start burning — and the flamethrower itself makes no noise at all. The only thing you h | `mechz_spiki.csc:153` | `—` | alias+1line |
| `BOSS-03` | **H** | silent | A boss drops out of the sky and slams into the stairs in front of you. The floor shakes, the controller rumbles, debris FX bursts, every zombie within | `_tod_bosses.gsc:513-516` | `—` | alias+1line |
| `BOSS-04` | **H** | silent | Two full seconds before anything arrives, a glowing marker appears on the ground where a boss is about to land. It is your entire warning, and it is c | `_tod_bosses.gsc:436` | `—` | alias+1line |
| `BOSS-05` | **H** | recycled | A Rogue Protector lands and greets you with a cheerful, friendly robot voice announcing that it is activated — the exact same line the ALLY Civil Prot | `_tod_bosses.gsc:1641 — level thread zm_zod_rob` | `vox_crbt_robot_activated_0..4` | alias+1line |
| `BOSS-06` | **H** | silent | You finally break the Panzer's faceplate — the thing that has been eating every headshot you land — and you get no confirmation. Nothing cracks, nothi | `mechz_spiki.csc:101` | `—` | alias+1line |
| `BOSS-07` | **H** | silent | A meteor falls out of the sky, streaks past the open stairwell, and detonates on the deck in front of you to deliver the Reaver. The screen shakes, th | `_tod_reaver.gsc:240 → scripts/zm/zm_genesis_ap` | `—` | alias+1line |
| `BOSS-08` | **H** | silent | A pack of three to five hellhounds appears around you. Real hellhound rounds announce themselves with a lightning strike, a howl and a thunderclap; he | `_tod_hellhounds.gsc:291` | `—` | alias+1line |
| `BOSS-09` | **H** | silent | A Rogue Protector dies. This is a 43,000-HP enemy at round 30 that you have been shooting for the better part of twenty seconds. It stops, drops, and  | `_tod_bosses.gsc:1890` | `—` | alias+1line |
| `BOSS-10` | **H** | recycled | A Panzer descends toward you on a burning sky trail — and sounds like a small hovering police drone the whole way down. | `_tod_bosses.gsc:484` | `fly_civil_protector_loop` | alias+1line |
| `BOSS-11` | **H** | bug? | The Panzer's own arrival sound is fully built, precached, loaded and wired to a client callback in this map's own script — and the one function that t | `mechz_spiki.gsc:2848` | `zmb_mechz_spawn_nofly` | one-line-gsc (no new asset) |
| `BOSS-12` | **H** | recycled | A zombie claws up out of the deck in front of you — on a glowing glass landing 40 floors up, or on a floating causeway with nothing but sky underneath | `_tod_endless_rounds.gsc:92` | `zmb_zombie_spawn` | alias+1line |
| `BOSS-13` | M | recycled | Five Rogue Protectors are standing on the stairs around you and you cannot tell where any of them are by ear — you hear a vague hum, but not five dist | `_tod_bosses.gsc:1639` | `fly_civil_protector_loop` | alias+1line |
| `BOSS-14` | M | silent | The Panzer's armor plates shear off his knees and shoulders as you shoot them apart. Plates the size of car doors detach from a mech and hit the stair | `mechz_spiki.csc:102-108` | `—` | alias+1line |
| `BOSS-15` | M | recycled | The Panzer lobs a burst of three glowing 115 grenades at your feet and they all pop the instant they touch the ground. Each one detonates with a stock | `_tod_bosses.gsc:1532` | `wpn_taser_mine_zap` | gdt-edit (FULL build, not -GscOnly) |
| `BOSS-16` | M | bug? | Two of the three custom sound aliases the map ships specifically for its bosses can never be heard in a shipped game — the code paths that played them | `_tod_bosses.gsc:1851` | `acc_phantom_zap and wpn_s1_mah` | alias+1line |
| `BOSS-17` | M | bug? | A Rogue Protector shoots you from across a stairwell. The bullet arrives; the report does not — his weapon is only audible for the closest 1000 units  | `sound/aliases/tod_bosses.csv row 1` | `wpn_s1_rw1_shot_npc` | alias-row-edit-only |
| `BOSS-18` | L | silent | A boss slams down and every zombie within 350 units is killed and ragdoll-flung outward in one frame — a dozen bodies going airborne at once with no s | `_tod_bosses.gsc:1659` | `—` | alias+1line |

### ECON — Doors, crates, teleporters, PaP  (11)

| id | pri | state | the moment | site | plays now | work |
|---|---|---|---|---|---|---|
| `ECON-01` | **H** | silent | You open the floor-10 / 20 / 30 / 40 breather door and a brand-new enemy type is now in the game for the rest of the run — Rogue Protectors, then the  | `_tod_doors.gsc:460` | `—` | alias+1line |
| `ECON-02` | **H** | bug? | The Pack-a-Punch purchase 'show' — lever down, machine roars, gun goes in. The musical sting that is supposed to punctuate it never plays, on any of t | `_tod_powerups.gsc:475` | `cw_mus_perks_packa_sting` | alias |
| `ECON-03` | **H** | recycled | Every refusal in the map — broke, no power, already own it, nothing to refill, already full, station spent, everything maxed, teleporter recharging, t | `_tod_ammo_crate.gsc:175` | `zmb_no_purchase` | alias+1line |
| `ECON-04` | **H** | silent | You pay 5,000 points at the ammo crate and your reserve fills. The crate does not open, rattle, or clunk — nothing moves and nothing sounds. | `_tod_ammo_crate.gsc:198` | `zmb_cha_ching` | alias+1line |
| `ECON-05` | **H** | bug? | You Pack-a-Punch a gun. The machine animates, the lever moves, but the Pack-a-Punch jingle and the upgrade sting never play — the iconic musical hook  | `zm_cwpap.gsc:108` | `cw_mus_perks_packa_sting / cw_` | alias |
| `ECON-06` | M | recycled | You pay 5,000 points at a breather Pack-a-Punch and a voice announces a FREE Pack-a-Punch. | `_tod_powerups.gsc:639` | `free_packapunch_vox` | alias+1line |
| `ECON-07` | M | silent | The power comes on and the breather Pack-a-Punch transforms — dead grey box becomes a lit, animating machine. No transition cue: a hum simply appears  | `_tod_powerups.gsc:439` | `—` | alias |
| `ECON-08` | M | silent | A teleporter pad standing ready. Its beam is lit — that is the ready signal — and it is completely silent. | `_tod_teleport.gsc:285` | `—` | code |
| `ECON-09` | M | silent | A teleporter finishes its 60-second recharge and comes back online. Nothing announces it — you have to be looking at the pad to know. | `_tod_teleport.gsc:410` | `—` | alias+1line |
| `ECON-10` | M | silent | You ride a breather teleporter down before buying the bay, land in the sealed room, and the wall in front of you silently vanishes — the map has just  | `_tod_doors.gsc:375` | `—` | alias+1line |
| `ECON-11` | M | recycled | A teammate teleports onto a breather balcony and a perk machine lands on the same balcony — and the two events make one identical sound. | `_tod_teleport.gsc:467` | `tod_warp` | alias+1line |

### ROUND — Rounds + the twist  (7)

| id | pri | state | the moment | site | plays now | work |
|---|---|---|---|---|---|---|
| `ROUND-01` | **H** | silent | The round ticks over. The horde is still coming, the number in the top-right corner changes from 12 to 13, and you keep shooting. Nothing announces it | `_tod_endless_rounds.gsc:351` | `—` | alias+1line |
| `ROUND-02` | M | silent | Zombies sprint at you from round one and get relentlessly faster forever — but a round-50 zombie sounds exactly like a round-1 zombie, and because rou | `_tod_zombie_speed.gsc:245` | `—` | code |
| `ROUND-03` | M | DEAD CODE | The last zombie of the round spawns in. At that exact instant — with the round still in full flow and the horde at its thickest — the map fires stock' | `_tod_endless_rounds.gsc:345` | `zm_audio::sndMusicSystem_PlayS` | alias+1line |
| `ROUND-04` | M | silent | Round 5. Round 10. Round 20. Round 35. Round 50. In every other zombies map these are the moments the game marks. Here they pass exactly like round 6  | `_tod_endless_rounds.gsc:353` | `—` | alias+1line |
| `ROUND-05` | M | silent | You buy the door on floor 24 and climb it. The tower gauge on the right side of the HUD stamps one more lit cell — the map's only readout of how far u | `_tod_gauge.gsc:105` | `—` | alias+1line |
| `ROUND-06` | M | silent | A red pip appears near the bottom of the tower gauge and starts climbing. Somewhere below you a Panzer or a Rogue Protector wave has spawned and is co | `_tod_gauge.gsc:173` | `—` | alias+1line |
| `ROUND-07` | L | silent | You kill a zombie. Its body drops, lies there for a beat, and then simply stops existing — either popping out mid-frame, or blinking invisible when th | `_tod_corpse_cleanup.gsc:154` | `—` | alias+1line |

### ATMO — Atmosphere, ambience, footsteps  (4)

| id | pri | state | the moment | site | plays now | work |
|---|---|---|---|---|---|---|
| `ATMO-01` | **H** | silent | You are on floor 34 of an open-air staircase, 13,000 units above a neon city, wind-exposed on every side. It sounds exactly like standing in the base  | `_tod_atmosphere.gsc:42` | `—` | code |
| `ATMO-02` | **H** | bug? | Every footstep you take for the entire game. 100 flights of stairs, every landing, every balcony, every deck on the causeway — and every bullet that h | `tools/gen_tower_map.js:508` | `the stock GLASS surface set on` | map regen |
| `ATMO-03` | M | silent | [SILENT] The tower has no ambient bed at all — 50 floors of open-air staircase over a neon city, and between gunfire the world makes no sound. And the | `sound/zoneconfig/zm_tower_of_doom.szc:77-84` | `—` | alias+1line |
| `ATMO-04` | L | bug? | Every music change: floor 10, floor 23, floor 37, and every time a Panzer spawns or dies. The track you have been listening to stops dead mid-bar and  | `_tod_atmosphere.gsc:260` | `none — the swap is a bare chan` | alias+1line |

### CLASS — Classes, guns, melee  (22)

| id | pri | state | the moment | site | plays now | work |
|---|---|---|---|---|---|---|
| `CLASS-01` | **H** | silent | You swing the STORMBREAKER (the slasher's tier-3 axe, the top of the whole melee ladder) and it connects with a zombie. | `_tod_classes.gsc:179` | `—` | alias |
| `CLASS-02` | **H** | recycled | You swing the STORMBREAKER through the air — the whoosh of the biggest weapon in the map. | `sound/aliases/tod_ports.csv:85` | `wpn_melee_fireaxe_whoosh_plr` | alias |
| `CLASS-03` | **H** | recycled | The class draft opens: the screen dims, four class cards fade in, and every player in the lobby is choosing who they are for the whole run. This is th | `_tod_class_select.gsc:142` | `tod_class_open` | alias |
| `CLASS-04` | **H** | silent | You reach SKIRMISHER tier 3 — the MP7, the top of the SMG ladder — and open fire on an open-air stair landing 15,000 units above the city. | `sound/aliases/tod_ports.csv:57` | `wpn_t6_mp7_shot_plr` | alias |
| `CLASS-05` | **H** | silent | The HEAVY's tier-3 Death Machine: you pull the trigger and the barrels spool up before the first round leaves, then wind down after you let go. | `sound/aliases/tod_ports.csv:81` | `wpn_t6_death_machine_spin` | code |
| `CLASS-06` | **H** | silent | You Pack-a-Punch your blade — 5000 points for the SLASHER's upgrade. | `_tod_classes.gsc:177` | `—` | code |
| `CLASS-07` | M | recycled | The slasher class kills with the knife and instantly lunges to the next zombie — the map's signature melee verb — and it sounds like a perk machine te | `_tod_lunge.gsc:265` | `tod_warp` | alias+1line |
| `CLASS-08` | M | silent | The blackscreen lifts. You are standing in the base arena at the foot of a 50-floor tower in a fogged neon city, and the game has just started. There  | `_tod_main.gsc:59` | `—` | alias+1line |
| `CLASS-09` | M | recycled | You go down. The screen desaturates, you flop onto your back on a staircase 30 floors up, and what you hear is a generic Black Ops 3 low-health whoosh | `tmp/bo3_stock_ref/scripts/zm/_zm_audio.csc:313` | `chr_health_laststand_enter / c` | alias |
| `CLASS-10` | M | bug? | [BROKEN] Eleven of the map's sounds have no wav in this repository — six UI cues AND the slasher's tier-2 Wakizashi foley. The build only works becaus | `sound/aliases/tod_ui.csv:2` | `tod_ui_tick` | alias |
| `CLASS-11` | M | recycled | You cycle between the four class cards with A/D, W/S, the d-pad, the stick, mouse1/2, melee or reload — eight input lanes, all mapped to the same tick | `_tod_class_select.gsc:299` | `tod_ui_tick` | alias |
| `CLASS-12` | M | silent | The draft's 30-second timer enters its last six seconds — the on-screen countdown turns RED and you are about to have a class rolled for you. | `_tod_class_select.gsc:224` | `—` | alias+1line |
| `CLASS-13` | M | recycled | The 30 seconds run out and the game rolls a class for you — you are now a HEAVY for the next hour and you did not choose it. | `_tod_class_select.gsc:153` | `tod_class_jackin — the same al` | alias+1line |
| `CLASS-14` | M | recycled | You lock your class in — the confirm flash fires, your gun arrives, and a second later the round-1 upgrade cards deal. | `_tod_class_select.gsc:164` | `tod_class_jackin` | alias |
| `CLASS-15` | M | recycled | You hit a zombie with the KATANA (slasher tier 2). | `source_data/t9_weapons/melee/wpn_t9_me_wakizas` | `fly_melee_swipe_t9_knife_h / f` | code |
| `CLASS-16` | M | silent | You first draw the STORMBREAKER after a tier-up, and every time you hit reload on it (a melee weapon's 'flourish' animation). | `_tod_classes.gsc:179` | `—` | alias |
| `CLASS-17` | M | silent | The HEAVY's opening gun, the Stoner 63, firing full-auto. | `tools/gen_tod_sounds.js:46` | `wpn_t9_stoner63_shot_plr` | code |
| `CLASS-18` | L | silent | You are moving and firing — sprinting up a flight with the trigger held — and Run and Gun refunds a round straight back into the magazine. The counter | `_tod_runandgun.gsc:93` | `—` | alias+1line |
| `CLASS-19` | L | silent | You hold JUMP or USE for half a second to lock your class — the hold bar fills on screen. | `_tod_class_select.gsc:313` | `—` | alias+1line |
| `CLASS-20` | L | silent | Co-op: you have locked your class and are walking the base arena while up to three teammates are still deciding. Someone locks in. | `_tod_class_select.gsc:164` | `—` | alias+1line |
| `CLASS-21` | L | recycled | Your class weapon is put in your hands for the first time — a MAC-10, an Enfield, a Stoner 63 or a combat knife, depending on who you just became. | `_tod_classes.gsc:681` | `fly_generic_first_raise_plr — ` | alias+1line |
| `CLASS-22` | L | recycled | CHAIN LUNGE — knife-kill into a fast dash onto the next zombie. Currently not in the game at all; flagged because the parent brief asks about it and b | `_tod_lunge.gsc:265` | `tod_warp` | code |

### MISC — Everything else  (6)

| id | pri | state | the moment | site | plays now | work |
|---|---|---|---|---|---|---|
| `MISC-01` | **H** | bug? | [ADDED — BROKEN] You buy the power room, walk to the back and flip the breaker. The lever throws, the lights come up, eight perk machines wake across  | `map_source/zm/zm_tower_of_doom.map:57994-58001` | `zmb_switch_flip` | alias |
| `MISC-02` | **H** | bug? | [ADDED — BROKEN] The eight perk machines are completely mute. No idle hum to find one by ear, no power-on ka-chunk when the breaker flips, no refusal  | `share/raw/scripts/zm/_zm_perks.gsc:142` | `zmb_perks_power_on` | alias |
| `MISC-03` | M | UNVERIFIED | The Reaver blinks 400-750 units across the stairs and is suddenly on top of you. The teleport has stock audio wired up at both ends — but the alias ba | `scripts/shared/ai/archetype_apothicon_fury.csc` | `zmb_fury_bamf_teleport_in / zm` | alias+1line |
| `MISC-04` | M | bug? | You land a headshot on a Rogue Protector — the every-3-rounds boss — and there is no hit confirmation at all. On a 13k-43k HP target with no health ba | `archetype_zod_companion.csc:50` | `prj_bullet_impact_robot_headsh` | alias |
| `MISC-05` | M | recycled | You miss a swing and the blade hits the tower — the metal stair deck, a rail cap, the core wall, or a breather lounge's glowing glass window band. | `source_data/t9_weapons/melee/t9_me_surfacesoun` | `fly_melee_imp_knife_npc_metal` | code |
| `MISC-06` | L | ok | You open the pause menu to check what upgrades you own. The YOUR UPGRADES panel renders your whole build — every domain, its level, its pips. | `ui/uieditor/menus/StartMenu/AetheriumStartMenu` | `menu_open` | alias |

---

## 5. NOT IN THE TABLE (deliberately)

- **Music.** Already solved — 4 climb bands + boss + finale, credited in CREDITS.md.
  One cleanup worth noting: all six beds have `FadeIn`/`FadeOut` blank, so every
  band change at floors 10/23/37 and every Panzer spawn is a hard cut. Setting
  those two columns is an alias edit, no new asset.
- **Announcer VO.** The map has no announcer. Stock `sndAnnouncerPlayVox` fires
  on powerup grabs but resolves through `level.zmAnnouncerPrefix`, which this
  map never sets. Whether MAX AMMO is called out is a 10-second in-game test.
- **Gun fire sounds.** Generated by `tools/gen_tod_sounds.js` from real ports.
  Two gaps did surface and ARE in the table: the MP7 has no tail rows, and the
  Stoner 63 has an empty `Secondary` (no trig_pull layer).

## 6. REPO HYGIENE (unrelated to SFX, found on the way)

- 11 aliases reference wavs present only in the Mod Tools root, not vendored
  here: `tod_ui_tick`, `tod_ui_lock`, `tod_super_sting`, `tod_ultimate_sting`,
  `tod_class_jackin`, `tod_class_open` + 5 wakizashi rows. Builds fine on this
  machine; a fresh clone would not. Six of those are on the replace-list anyway.
- `sound_assets/tod/music/README.md` band table is stale — says 20/30/40, the
  live bands are 10/23/37 (`register_music_bands()`).
