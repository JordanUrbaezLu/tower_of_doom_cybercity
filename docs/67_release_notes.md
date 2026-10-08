# Tower of Doom: Cybercity — release notes, v0 to v16.25

Generated 2026-09-02 from the full `CHANGELOG.md` (252 entries, 2026-08-17 to 2026-09-02) and the Steam Workshop change-log page for item 3788921059. Every changelog entry is condensed here to what a player or tester would notice; the CHANGELOG keeps the mechanism, the postmortems and the build evidence. Newest first, like the CHANGELOG.

## Where things stand

- **Live on the Workshop: v16.5** (uploaded Sep 1, 7:47 pm). It carries everything up to the ATHLETE slide-jump, the Damage Reduction / Sprint rebalance and the eight review fixes.
- **Unpublished since then:** v16.6 – v16.25 — the Death Machine pre-spin, the breather lounge polish, the tower facelift (districts, sliding door gates, base plaza), the door invisible-wall fix, MAG SIZE +20%, KILL RELOAD retired, the Warden trials in all three shapes, ATHLETE air steering and the trial banners.
- **The working tree is an ARMED test build** (dev + god on since v16.21, plus the spire-warp harness of v16.22). The publish gate refuses it until both flags are set back to false and the harness is removed.
- **The Workshop item has never carried change notes.** All 25 uploads show an empty note on Steam; this document is the first place the history exists in one piece.
- **No v15 was ever built.** Versions jump from v14.61 to v16 (the v15 task list in docs/55 was absorbed into the v16 entries). Two entries are both labelled v9.1 and two v9.44; there is no v9.7; a few entries carry no number and are listed as written.

## Workshop publish history

Source: the Steam Workshop item's change-log page (item 3788921059: 25
uploads, posted Aug 23, last updated Sep 1, no upload carries a note)
cross-referenced with the build clocks the CHANGELOG records. Steam renders
its timestamps in Pacific time; the column below converts them to the
machine's own clock (Eastern, UTC-4). **exact** = the CHANGELOG records a
build within minutes of the upload; **probable** = the day's entries bracket
it; **approx** = only the date is known.

| # | Uploaded (Eastern) | Version on Workshop | Confidence | Evidence |
|---|---|---|---|---|
| 1 | Aug 23, 3:49 pm | v10.1 (first post) | exact | v10.2: "the beta uploaded at 15:46 was built at 15:42 and CONTAINS the v10.1 [PaP naming bug]". |
| 2 | Aug 23, 6:59 pm | v10.3 / v10.4 | probable | After v10.2 (built 4:18 pm), before the 8:58 pm v10.8 rebuild; v10.4's co-op session is titled POST-SHIP. |
| 3 | Aug 24, 7:13 pm | v10.21 | exact | "PUBLISH BUILD" (user: "do a full rebuild, I'm gonna publish this version"). |
| 4 | Aug 25, 1:38 am | v10.23 | approx | The armory fixes are the last entry dated Aug 24; the crown work begins the next entry. |
| 5 | Aug 25, 12:30 pm | v11 / v11.1 | approx | The crown circlet and its 1.4x scale-up are the Aug 25 daytime entries. |
| 6 | Aug 26, 1:10 am | v11.2 – v11.4 | approx | Crown detail pass, perk identity bugs, Gift of Death ring; all dated Aug 25. |
| 7 | Aug 26, 3:28 am | v11.5 / v12 | approx | The assault buff and the Vortex Bell + four-fears road are the early Aug 26 entries. |
| 8 | Aug 26, 2:01 pm | v12.6 | exact | "ZOMBIE BLOOD RESTORED + FULL PUBLISH BUILD", .ff at 1:40 pm. |
| 9 | Aug 26, 3:20 pm | v12.8 | exact | Language-fastfile fix built 3:14–3:16 pm; "reaches players only via a REPUBLISH". The -AllLanguages rule starts here. |
| 10 | Aug 27, 3:26 am | v12.9 | approx | The Aug 26 balance pass (ammo, luck floors, Scavenger, Tireless out). |
| 11 | Aug 27, 1:25 pm | v12.10 | probable | Opening Hand pass; v12.11 (stair ramps) was built at 2:02 pm, after this upload. |
| 12 | Aug 27, 6:25 pm | v12.15 | exact | "v12.15 SHIP — disarm + publish build"; the deployed language .ff files are stamped 6:15 pm that day. |
| 13 | Aug 29, 2:19 am | v13.14 | exact | "PUBLISH CANDIDATE #2", built 2:14 am. |
| 14 | Aug 29, 1:14 pm | v13.17 | probable | "PUBLISH CANDIDATE #3" (PaP glow root cause, AAT off, disarm). |
| 15 | Aug 29, 2:24 pm | v13.19 | approx | Death Perception replaces Elemental Pop; dated Aug 29 between candidate #3 and the Spire. |
| 16–18 | Aug 29, 3:53 / 4:00 / 4:19 pm | v14.0 / v14.1 | probable | Three uploads in 26 minutes; v14.1 is "crown-altar hardening + full disarm; PUBLISH BUILD" on top of the Endless Spire (v14.0). |
| 19 | Aug 29, 10:36 pm | v14.2 | approx | The 3-player bug batch is the only entry between the v14.1 uploads and the 1:42 am build. |
| 20 | Aug 30, 1:45 am | v14.4 | exact | "THE publish build", .ff at 1:42 am, carrying v14.2 + v14.3. |
| 21 | Aug 30, 2:47 pm | v14.16 | exact | Git commit "v14.16 publish candidate" at 2:37 pm (Wisp Tea, the 250-string fix, BO7 cans). |
| 22 | Aug 30, 5:58 pm | v14.22 – v14.23 | probable | Rampage Inducer full build at 4:35 pm, then the spire live-test fixes; v14.25 / v14.27 say "not in any build yet". |
| 23 | Aug 31, 3:07 am | v14.37 – v14.40 | approx | Fog first renders, Rampage down rule, the locked tier card, sky back to Miami; no build clocks recorded. |
| 24 | Aug 31, 8:47 pm | v14.59b | exact | v14.59 / v14.59b share one full build at 8:41 pm; written "on the eve of a publish build". |
| 25 | Sep 1, 7:47 pm | **v16.5 — LIVE** | exact | "dev + god mode DISARMED", built with -Publish at 7:33 pm. |

Everything from v16.6 onward is **unpublished**, and the working tree is an
ARMED test build (dev + god on since v16.21) that the publish gate will refuse
until both flags go back to false.

## The eras at a glance

### v16 — Athlete, the facelift, the Warden trials (Sep 1 – Sep 2; 37 entries, 1 upload)

The slasher gets ATHLETE (slide speed, jump height, then a rebuilt slide-jump that keeps momentum and a steerable air arc). Damage Reduction turns diminishing, Sprint goes rare, the MR6 PaP is halved and the slasher sidearms learn to hurt bosses. The breather lounges get their polish pass, the spiral becomes five colour districts with door gates that slide open, and the invisible wall above every bought door is finally removed on both towers. On the Endless Spire every hub becomes a Warden trial: first an outside ring, then the hub hall inside the tower, ten layouts, ten recipes, banners. Only v16.5 reached the Workshop; everything after it is unpublished and the current tree is an armed test build.

### v14 — The Endless Spire, the crash, the rebalance (Aug 29 – Sep 1; 63 entries, 9 uploads)

The post-victory Endless Spire ships, turns out to have no navigation mesh at all, and is seeded in v14.19. The 250-string crash is closed twice (v14.3 flattened the wrong thing; v14.14 moved the fix into the map). Wisp Tea replaces Deadshot, every perk drinks from a BO7 can, the Rampage Inducer arrives as opt-in hard mode, and luck gains a secret 150% overcharge band. The class rebalance makes the heavy the tank and trims the skirmisher and slasher; tier promotions gain a floor gate with a visible locked card; cards are dealt with a reveal animation; the perk cap returns with PERK SLOTS as the way past it; DISTRACTION adds a tactical slot; every priced prompt stops saying "Wall Weapon". Five uploads across the span.

### v13 — Breather lounges, BO7 machines, the sprinter (Aug 28 – Aug 29; 11 entries, 3 uploads)

The breather balconies become walled, open-top lounges with one theme colour each and a teleporter spur over the drop. All nine perk machines take BO6/BO7 models; Electric Cherry becomes Elemental Pop, then Death Perception. The Armored Sprinter completes the elite ladder (10 Protector / 20 Reaver / 30 Sprinter / 40 Hounds). The Pack-a-Punch glow that four fixes had failed to move is found drawing at the crown. Three uploads, two of them titled publish candidates.

### v12 — The Vortex Bell and the co-op failure surface (Aug 26 – Aug 27; 17 entries, 6 uploads)

The crown grows its bell underside and the finale road becomes four different kinds of fear. A week of co-op reports gets answered: reviving no longer buys things, going down during the pause no longer strands you, respawning no longer blanks the HUD, the permanent orange tint is a missing vision file, and non-English players can load the map. Stair ramps make the climb feel smooth. The finale beat system lands minus its Derez Tide, which was removed the day it shipped. Five uploads.

### v11 — The citadel becomes a crown (Aug 25 – Aug 26; 6 entries, 2 uploads)

The "castle with spikes" is replaced by a gold circlet, then scaled 1.4x so it fills the sky from the base. A detail pass fixes buried jambs, thin points and blocks standing on the causeway. PhD and Stamin-Up stop sharing an identity, the Gift of Death bells finally stop ringing, and the assault gets its first buff. Three uploads.

### v10 — The Last Mile and the first Workshop upload (Aug 23 – Aug 24; 20 entries, 4 uploads)

The ending becomes a road run timed to the closing song. The map is posted to the Workshop on Aug 23 and the first day of player reports drives ten fixes, two release audits and a stale-build scare. Keyboard card picking is root-caused (every earlier fix read an input a keyboard can never reach). The evening of launch crashes turns out to be a DualSense controller. Four uploads.

### v9 — The crown, class tiers, the Reaver (Aug 21 – Aug 23; 52 entries, 0 uploads)

The top of the map gets its crown stair, terrace, causeway and hall with a buyable ending. Class tiers arrive: three guns per class, a TIER card once the class gun is packed, a unique upgrade per gun. The Reaver joins, per-class sidearms replace the shared pistol, melee gets a clean damage ladder, music changes by floor, teleporters link the breathers to the base, and the first ship-state run is played. The Panzer is tuned three times in one night.

### v8 — The tower doubles (Aug 21; 9 entries, 0 uploads)

Fifty floors, breathers at 10/20/30/40, enemies that unlock as you climb. Thor's Thunder, Zombie Blood, the free Pack-a-Punch drop, upgrade rarity tiers and the first Pack-a-Punch retune.

### v5 – v7 — The luck bar and the baked-art UI (Aug 20; 14 entries, 0 uploads)

The luck bar decides how good the deal is; perks scatter to random pads and reshuffle. The look becomes the Tron grid. Two flights per floor instead of four, the personal upgrade station, 150 base health, and the whole UI family re-drawn as baked art (58 cards, banners, badges, tray icons). The roster settles on MP5 and Stoner 63 with a tower gauge on the HUD.

### v3 – v4 — Classes, twins, bosses (Aug 19 – Aug 20; 11 entries, 0 uploads)

Class-specific upgrade pools and a MEDIC give way to the four-class matrix. Upgrades become real gun variants. The Panzer and Rogue Protectors arrive, then settle into every-5th-round and every-3rd-round cadences with the Panzer's own music. The game-start class draft, breather balconies and the first won't-load hotfix.

### v0 – v2 — The tower stands (Aug 17 – Aug 18; 12 entries, 0 uploads)

A greybox with the endless-rounds twist from day one becomes the spiral tower, then the 25-floor tower with three classes and street-level smog. The Upgrade Tower card system, its LUI panel, rarity odds and the first card art all land in the first two days, along with the Aetherium HUD.

## Every version

Flags: **publish** = the entry itself says it was a publish build or candidate; **build** = the wall-clock time the entry recorded for its .ff (Eastern), used to match uploads; **kind** = the dominant change type. A gold line marks a Workshop upload, placed above the newest version it could contain.

### v16.32 — 2026-09-02 — Card-menu hint plates show the live keys on any device

- The upgrade panel and class draft plates now draw the exact keys or pad buttons you have bound, on either device, and follow you live if you switch devices mid-run. Four new plates from files (96).zip: a blank frame the game writes on, two keyboard re-bakes that add F as a lock key (the fallback look), and a baked UPGRADE CARDS header for the pause-menu controls line.
- The draft plate no longer claims the stick switches cards; it never did under the menu freeze.
- Untested in game beyond boot; look at the round-1 cards and the class draft on each device.

### v16.29 — 2026-09-02 — Keyboard and controller prompts show the real key

- Every prompt card — doors, perks, Pack-a-Punch, ammo crates, teleporters, the altar, extraction, spire buys, the power switch — now shows the key or button you actually have bound, instead of a hardcoded "F". Controller players see their pad glyph; keyboard players who rebound Use see their key.
- The pause menu gains an UPGRADE CARDS line under the buttons listing the live card-menu controls for your device.
- Keyboard lanes for both card menus audited and signed off (docs/69); the remaining plate gaps (default binds, Xbox-only glyphs, pad plate only after a d-pad press) are documented with the one asset that closes them.
- Untested in game beyond boot; the first door prompt on each device is the test.

### v16.25 — 2026-09-02 — Warden trial banners: TRIAL I through X
*art*

- Each Warden trial now opens with its own baked banner (TRIAL I .. TRIAL X) shown on screen for 5 s when the hall seals, replacing the printed hall name.
- "HOLD THE HALL" still prints alongside the banner.
- Full build (new images). Unverified in play as of this build.

### v16.24 — 2026-09-02 — ATHLETE air steering: momentum cone, turn rate walked back
*gameplay · build 02:59:14 -GscOnly (.ff 126,264,832 bytes)*

- Replaces v16.23's unlimited air steering: you keep full launch speed only while heading within 120 degrees ahead of your launch direction; past that speed is capped, falling to 35% of launch speed on a full reversal (90 deg 84%, 120 deg 68%, 150 deg 51%, 180 deg 35%). No more sliding then flying backwards at max speed.
- Speed lost in a turn is not refunded by turning back; the cap never drops below walking pace (200 u/s), and a boss fling re-anchors it instead of being fought.
- Air turn rate is now 180/240/300/360/420 deg/s at ATHLETE Lv1-5 (v16.23's 360 deg/s per level zigzagged), scaled by how far the stick is pushed.
- Pause-menu ATHLETE row now reads "air steer N deg/s; full momentum within 120 deg ahead".
- A 10 ms poll is not possible: the game's script tick is 50 ms, so smoothness comes from the per-frame step.
- Test build: dev + god still armed, not for publish.
- Unverified in play as of this build.

### v16.22 — 2026-09-02 — Warden trials shortened to 90 seconds
*balance*

- Every Warden trial hold-out is now 90 s (was 120 s); the gauge clock follows.
- The frenzy is still the last 30 s, so it now begins at the 60 s mark; THE ALTAR's halfway frenzy starts at 45 s, THE SUMMIT HALL is frenzy the whole way.

### v16.23 — 2026-09-02 — ATHLETE: slide-jump speed boost removed, comical air steering added
*gameplay · build 02:31:41 -GscOnly (.ff 126,136,832 bytes)*

- Fixes the "speed boost when you jump out of a slide": the old script carry that re-accelerated you to full slide speed at the jump is gone. Momentum is now preserved, never added.
- Slide start: speed = base x (1 + 10% per ATHLETE level), and chained slide-hops no longer compound toward the 800 speed wall.
- Jump edge: the launch is left alone unless it is more than 15% off your last grounded speed, in which case it is corrected (up or down).
- NEW air steering: while airborne your heading turns toward the movement stick at 360 deg/s per ATHLETE level (Lv5 reverses in 100 ms) — deliberately comical per the user, to be tuned later (walked back in v16.24).
- Jump height unchanged (higher per ATHLETE level).
- Pause-menu ATHLETE text now: "slide faster, jump higher, steer in the air" with the live deg/s figure; card art unchanged.
- Test build: dev + god still armed, not for publish. Co-op rubber-banding of airborne players is a known risk.
- Unverified in play as of this build.

### v16.21 — 2026-09-02 — Warden trials reshaped after the first real run
*gameplay*

- After the first real run (hub 10): the hall now actually locks. A hall gate with the purple ritual barrier seals the hall entrance itself (v16.19 sealed the door one flight below, so players could walk out onto the stairs).
- The hall entrance is 160 wide (was 64): a stepped fan of slabs joins the last five stair treads to the hall floor.
- Ten unique hall layouts, one per hub: THE RING, THE CROSS, THE COLONNADE, THE DAIS, THE BAFFLES, THE INNER RING, THE CHECKER, THE GAUNTLET, THE ALTAR, THE SUMMIT HALL — each with its own boss recipe (which elite family brings the adds, sprinters included; extra Wardens on VI +1, VIII +1, IX +2, X +3, cap 4; IX frenzies from halfway, X the whole trial).
- Difficulty toned down ~15% at the base (elite HP x1.275, adds every 4.6 s), then +7% per trial compounding — trial X is x1.84 of trial I. Replaces v16.20's per-tier steps.
- Winning a trial now grants EVERY perk the map sells, on top of the 5000 points and Max Ammo.
- Seal prints the hall's name (e.g. "TRIAL IV - THE DAIS / HOLD THE HALL") pending the banners.
- Full build. Hall gate, fan and all layouts above hub 10 unverified in play as of this build.

### v16.22 — 2026-09-02 — Test harness: spawn straight into the Endless Spire
*internal*

- Dev test harness only: spawn ascends the party into the Endless Spire and a warp pad opens doors 1-10 free to land at hub 10 (test build, not for publish; must be deleted before publishing).

### v16.22 — 2026-09-02 — Class badges and class icons re-baked
*art · build 01:48:01 FULL (.ff 126.1 MB)*

- The four class badges (Skirmisher/Assault/Heavy/Slasher) redrawn: glow fades cleanly, off-centre pill fixed, medallion emblems redrawn as filled bevelled icons.
- New class icon set installed (not yet drawn in game).
- Four class medallion discs from another session ride this build.
- This build is the v16.21 armed test build (dev + god on), not for publish.

### v16.21 — 2026-09-02 — Armed test build: dev + god, spawn as maxed Slasher
*internal*

- Dev and god mode armed; spawn as a maxed Slasher (Stormbreaker, PaP'd, all domains maxed, no perks). Test build, not for publish — both flags must go back off.

### v16.20 — 2026-09-02 — Warden trials scale with hub height; arrival chime
*balance*

- Trials escalate by hub: +1 Warden at hubs 40-70, +2 at 80-100 (cap 4 still holds); adds arrive faster per tier (every 4.0 s at hub 10 down to 1.75 s at hub 100, floor 1.5 s); elite HP climbs 5% per tier (x1.50 to x1.95).
- A chime plays the first time each player steps into a hub hall.
- The 2 s "closing" tell now sounds at the hall's centre as well as at the door below.
- Unverified in play as of this build.

### v16.20 — 2026-09-02 — Upgrade card art batches 03 and 04 installed (96 cards)
*art · build 01:15:13 FULL (.ff 125.8 MB)*

- 36 fact-fix cards (batch 03) and 60 of 66 art-pass cards (batch 04) re-baked and installed.
- Pip counts now correct: 5 pips on LUCK, SCAVENGER, LEECH, KNIFE SPEED, OVERDRIVE, SECOND WIND, BACK ARMOR, FORCED MARCH, VITALITY, RECOVERY; 1 pip on SPRINT FIRE; BACK ARMOR and VITALITY numberless; CLEAVE ultimate reads on the family line.
- Held back: MAG SIZE art-pass cards (they bake +30/60/90, the domain now pays +20/40/60) and KILL RELOAD (retired).

### v16.19 — 2026-09-02 — The Hub Hall: Warden trials move inside the tower
*geometry*

- Supersedes v16.15's outside boss ring: every 10th spire floor the tower's centre opens into a walled hall — the core column stops at the hub landing and resumes 576 up, a red drum wall encloses it.
- Inside: hall floor, railed galleries on the next lap's stairs, four cover pillars, a floor ring with the trial mark, PaP on the west wall, ammo crate east, perk pads north, six spawn risers, respawn points in the north gallery.
- Doorway is the top of the west flight (64 wide); invisible walls that used to rise ~600 over the hub door and stair rail are gone.
- The trial gate is now the hub door's own slab, re-sealed behind the purple barrier; Wardens drop from the open core; no honour guard at hub doors.
- Four stair/pathing breaks found and fixed before build. Full build.
- Unverified in play as of this build.

### docs, on v16.18 — 2026-09-02 — Armory page audited and republished
*internal*

- No game change: the armory reference page re-checked against the source; four stale notes fixed (ATHLETE, luck down rule, registration guard) and an Endless Spire / Warden Trials knobs block added.

### v16.18 — 2026-09-01 — Warden trial ring closes itself behind a purple barrier
*gameplay*

- No more altar: the trial starts on its own once every living player is inside the arena (a downed teammate outside holds it open). A 2 s teleporter-charge tell plays at the mouth; stepping out cancels.
- Shadows of Evil's purple ritual barrier now seals the arena mouth; an invisible slab behind it is what actually blocks you. Both clear on the win.
- The "BEGIN THE TRIAL" hold prompt and the gather-in are gone.
- Unverified in play as of this build.

### v16.17 — 2026-09-01 — MAG SIZE cards re-baked to +20/+40/+60%
*art*

- The three MAG SIZE upgrade cards now show +20% / +40% / +60% (matching v16.14's nerf); magazine redrawn in steel/gold, the ULTIMATE gets a drum. Full build.

### v16.16 — 2026-09-01 — Ending and Spire hero art re-baked
*art*

- Seven ending/spire images redrawn: the win banner (tower/crown scene), the win and spire emblems (filled badges that survive the small draw), the EXTRACT/ASCEND choice banner (equal weight, exfil-pad scene), and the three spire banners (heavier rails, gold bloom + summit beacon). Text unchanged. Full build.

### v16.15 — 2026-09-01 — The Warden Trials: a sealed 2-minute boss arena at every spire hub
*gameplay*

- Every Endless Spire hub (floors 10, 20 .. 100) is rebuilt as a 928-square sealed boss ring with cover pillars, corner pylons, a trial mark and a Warden gate; the next door (11, 21 .. 91) and the summit extraction stay sealed until the trial is won.
- Hold the altar on the mark to start: the party gathers, the gate seals, the tower gauge becomes a 120 s clock, boss music plays.
- WARDENS (Panzers), one per player, +1 in the last 30 s (cap 4), replaced 6 s after a fall; adds (protectors/reavers/hounds) every 4 s, every 2 s in the frenzy; every elite inside has x1.5 HP.
- Win at T=0: 5000 points team-wide + a Max Ammo, the door unseals.
- No enemy limits raised; the Wardens take first claim on the elite roof.
- Unverified in play as of this build.

### v16.14 — 2026-09-01 — KILL RELOAD retired; MAG SIZE nerfed to +20% per level
*balance*

- KILL RELOAD (assault: a free magazine every 55th/40th/30th kill) is removed from the card pool — "no one likes it". Every other assault card is dealt ~18% more often.
- MAG SIZE now +20% / +40% / +60% (was +30/60/90): Enfield 30 -> 36/42/48, Krig 33 -> 40/46/53, AK-47 36 -> 43/50/58. Card art stale until v16.17.
- A third RECOIL tier is NOT possible without trading MAG SIZE down to 2 levels (weapon-registration budget is full).
- Full build. Unverified in play as of this build.

### v16.13 — 2026-09-01 — Invisible wall above every door fixed; core spines
*fix · build 23:00:09 FULL (.ff 116.58 MB)*

- Fixes the invisible wall players hit jumping down stairs above a bought door, on BOTH towers (153 doors): the anti-vault blocker now slides away with the door instead of staying forever.
- Shut doors still cannot be vaulted.
- Tower look: each core band now carries a lit vertical spine in its district colour, so four unbroken lit lines run from the base to the crown.
- Unverified in play as of this build.

### v16.13 — 2026-09-01 — FULL STEAM arms at 0.8 s, screen wash reduced
*balance · build 22:57:12 -GscOnly*

- FULL STEAM (heavy) now kicks in after 0.8 s of unbroken sprint (was 1 s).
- Its cyan screen wash reduced from 15% to 10%.
- Pause-menu text updated.

### v16.12 — 2026-09-01 — Slasher sidearms +25%; UDM sight removed
*balance · build 22:29:16 FULL (.ff 122.22 MB)*

- Slasher sidearms UDM (T2) and RK7 (T3), base and PaP: damage +25%, fire rate +25%, clip +25% (UDM 14 -> 18, RK7 15 -> 19), reserve mags +25%, reload 25% faster. Combined DPS x1.56 (UDM 1,717 -> 2,688; RK7 2,682 -> 4,186).
- The T1 AMP63 got only the damage buff (its other numbers are not reachable from this map).
- The UDM's grey square on ADS is gone: the whole sight is removed, the slide is bare when aiming.
- Unverified in play as of this build.

### v16.11 — 2026-09-01 — Tower facelift: districts, sliding door gates, base plaza, colour-coded bay
*geometry · build 22:22:09 FULL (.ff 116.55 MB)*

- The spiral is now five ten-floor colour districts: blue 1-10, green 11-20, orange 21-30, gold 31-40, red 41-50; treads, parapets, core bands and lights follow, and each new district's colour appears first on the landing where you buy its door.
- Every lap door gets a glowing post, lintel and sill in the colour of the floors it opens into, and the slab now SLIDES into the core over 1.2 s with a de-rez burst and door sound.
- Base plaza: glowing floor traces lead from spawn to the first door and to the power hallway; cyan pilasters and a cornice on the arena walls; a foot ring around the core.
- Teleport bay: each up pad wears its destination lounge's colour (front-left 10, front-right 20, back-left 30, back-right 40) with a matching pool light.
- Nothing changes play. Unverified in play as of this build.

### v16.10 — 2026-09-01 — FULL STEAM wind and ADRENALINE pulse louder
*audio · build 21:42:49 -GscOnly (.ff 121.87 MB)*

- FULL STEAM wind loop is louder (wav normalised to -1 dBFS, alias 74 -> 80).
- ADRENALINE pulse is louder (+3 dB limited, alias 92 -> 100), roughly +2-3 dB.
- FULL STEAM pause row now rounds to whole percents: +6 / +11 / +14 / +18 / +22%.
- Unverified in play as of this build.

### v16.9 — 2026-09-01 — Endless Spire rounds turn over about twice as fast
*balance · build - (v16.10 entry records a 21:39:26 .ff for v16.9)*

- Endless Spire rounds asked for too many kills (~15 min each): the spire's per-round zombie budget is now HALVED (floor 12). Shipped at one-third for one build, then set to half at the user's call before testing.
- How many zombies stand at once is unchanged; the round just ends sooner.
- The round already running when you ascend is clamped to the spire budget too.
- Luck per kill doubles in the spire so a full clear still pays the same; upgrade events and the speed curve arrive ~2x sooner in wall-clock time.
- Unverified in play as of this build.

### v16.8 — 2026-09-01 — FULL STEAM +20%
*balance · build 21:31:11 -GscOnly (.ff 121.87 MB)*

- FULL STEAM (heavy) sprint bonus is 20% larger: 6 / 10.8 / 14.4 / 18 / 21.6 speed points at Lv1-5; a rolling heavy tops out at 1.016 (was 0.98) — about +3.7% actual move speed at cap.
- SPRINT and FORCED MARCH unchanged.
- Pause-menu row now states "after 1s of unbroken sprint; a hit breaks it" and rounds to whole percents.
- Unverified in play as of this build.

### v16.7 — 2026-09-01 — Breather lounge polish: lit panels, finials, ambience, arrival chime
*geometry · build 21:17:19 FULL (.ff 116.23 MB)*

- Every breather lounge machine (PaP, ammo crate, upgrade station, perks) now has a lit backboard panel in the window bay behind it; the whole perk wall is one lit panel. The PaP and station shifted a few units to sit centred on their panels (the Endless Spire hubs follow the same layout).
- Glow finials on the four room corners, a glowing floor inlay ring with a spoke pointing at each amenity, four glow pylons on the teleporter pad, and two door-height hoops over the gantry.
- The gap under the lounge walls (visible from the flights below and the base) is filled with a glow band, three stepped pendants and a thruster block under the pad.
- Four theme-coloured accent lights per lounge and four looping ambient effects (dust motes from the open top, interior haze, ground fog on the pad, a soft steam vent at the gate).
- A 2-second rising chime plays the first time each player steps into each lounge (at most four per run).
- Left for the user to decide: making the upgrade station pause the world, a guaranteed Max Ammo on each breather door, per-perk info plaques.
- Revert switches were added for both the geometry and the ambience/chime (they ride the next build).
- Unverified in play as of this build.

### v16.6 — 2026-09-01 — Death Machine spins on aim; PaP nail gun explosion removed
*gameplay · build 21:06:48 FULL (.ff 121.88 MB)*

- Death Machine (all tiers, base and PaP): holding AIM now pre-spins the barrels (0.25 s spin-up) so the trigger fires instantly; releasing winds them down over 0.5 s.
- PaP nail gun (Pneumatic Irruptor): the grenade-style explosion flash, boom sound and screen shake are gone. Cosmetic only — it never dealt splash damage; damage 575, clip 50, fire rate and nail trail unchanged.
- This build's .ff came out ~6 MB larger than expected for no identified reason; superseded by the v16.7 build, which carries these edits.
- Unverified in play as of this build.

> **WORKSHOP UPLOAD #25 — Sep 1, 7:47 pm (Eastern) — v16.5** (exact). dev + god disarmed and built with -Publish at 7:33 pm; the live version.

### v16.5 — 2026-09-01 — Dev and god mode disarmed
*internal · build 19:33:58 -GscOnly (.ff 115.89 MB)*

- Dev and god mode switched off (upgrades every 4th round, Panzer at round 5 then every 5th, 20% tier cards, 5 station uses, real economy, downs live). The v16.1–v16.2 movement changes stay active but their debug readouts are off; disarmed test build — a Workshop upload still needs a fresh FULL build.

### v16.4 — 2026-09-01 — Endless Spire door seal shortened to 12 seconds
*balance*

- The Endless Spire hold-the-floor seal after a door buy drops from 30 s to 12 s.
- The honour guard (up to four Panzers, 3.5 s apart) still lands entirely inside the window, last arrival at 10.5 s.

### v16.3 — 2026-09-01 — Eight review fixes: sprinter armor, slow hounds, altar sound, keyboard prompts
*fix*

- Armored Sprinters now take their reduced damage from every player — a fresh player with no upgrades was doing full damage while the crosshair number showed one third.
- Hellhounds no longer stay frozen at 5% speed after an upgrade pause ("dog rounds bugged").
- Upgrade altar: when a paid roll does not deal the promotion card, the refund now plays a refusal sound instead of silent cha-ching / −3000 / +3000.
- Pause-menu THOR'S THUNDER row shows the real numbers (16–64% / 4.5–1.5 s, was the pre-nerf 20–80% / 3.8–1.3 s).
- The class badge on the deal panel is right from the moment the class locks; the loss screen now reads "GAME OVER - FLOOR N" (highest floor the party reached).
- Keyboard players no longer see "HOLD A": keyboard prompts by default, controller prompts after the first d-pad press (a pad player sees keyboard text until then — test both).
- Steam Workshop description corrected in the repo (rest stops, tier unlock wording, sprinters, Endless Spire, credits) so the next publish does not push the stale text; the publish build now refuses armed dev/god flags.

### v16.2 — 2026-09-01 — Landing stumble switched off
*gameplay · build 18:07:35 -GscOnly (.ff 115.89 MB)*

- The engine's post-jump landing slowdown is disabled for every class (the same setting Treyarch's old-school mode uses), so you no longer lose forward speed on landing after a slide-jump.
- Still the armed dev build; unverified in play as of this build (v16, v16.1 and this are unplayed).

### v16.1 — 2026-09-01 — ATHLETE slide-jump rebuilt on the engine's own lever
*gameplay · build 17:57:36 -GscOnly (.ff 115.89 MB)*

- The engine's clamp on the launch speed of a jump entered from a slide is lifted (global — every class keeps its slide speed into the jump); ATHLETE decides how much speed there is to keep. Replaces v16's after-the-fact speed restore, which caused the dip-then-jerk and did not fire at all for strong slides.
- ATHLETE slide: horizontal speed ×(1 + 10% per level) on the first sliding tick; v16's slide-start kick and speed-scale lane are folded into this single multiply.
- A direct slide-jump (within 150 ms of sliding) carries its full speed with no braking floor, plus three airborne re-asserts; the speed wall rises 500 → 800.
- Jump height unchanged.
- Co-op behaviour of the engine setting is inferred, not proven — watch for non-host rubber-banding.
- Dev build prints the movement numbers. Unverified in play as of this build.

### v16 — 2026-09-01 — ATHLETE: keep your speed when jumping out of a slide
*gameplay · build 11:58:43 -GscOnly (.ff 115.72 MB)*

- Slashers with ATHLETE keep their slide speed when they jump out of a slide (500 ms grace after the slide, topped up before launch); it only ever raises speed and keeps your steering direction.
- A 500 u/s wall bounds both the slide kick and the carry so chained slide-jumps cannot compound speed (a guess pending measurement: a capped/notchy slide-jump means it is too low).
- Build script gained a guard against building during another session's bake (internal).
- Unverified in play as of this build.

### tooling — 2026-09-01 — Weapon generator refuses to write when over budget
*internal*

- Internal: the weapon generator now aborts before writing anything when the registration count (measured 223, guard 220) is exceeded; HANDLING stays at 3 tiers by user decision (4/5 tiers would exceed the ~230 weapon ceiling). No game change.

### v16 — 2026-09-01 — Damage Reduction diminishing and common, Sprint rare, Double Tap 3500
*balance*

- DMG REDUCTION is now a diminishing ladder: −6 / −11 / −15 / −18 / −20% damage taken at Lv1–5 (was flat −5%/Lv, cap −25%). First card worth more, last two worth less; a 150-HP class at cap goes 200 → 187.5 effective HP.
- DMG REDUCTION moves from S band to A (dealt ~2.5× as often, richer rarity); SPRINT moves from A to S (~60% rarer, skewed to REGULAR).
- Double Tap costs 3500 (was 3000).
- The Panzer/boss damage lanes now use the same DR formula as everything else (a hand-copied constant that had already drifted is gone).
- DR cards will read "TAKE LESS DAMAGE" with no number (art prompt written, not yet delivered); the pause menu keeps the exact level-aware figure.

### v16 — 2026-09-01 — MR6 PaP damage halved, slasher sidearms ×2.25 on bosses, text audit
*balance · build 04:55 / 04:58 -GscOnly (.ff 115.74 MB)*

- PaP'd MR6 "Death & Taxes" damage halved (multiplier 2.16 → 1.08); the un-packed MR6 is unchanged.
- Slasher class sidearms deal ×2.25 damage to bosses and elites (Panzer, Protector, Reaver, Hound, Sprinter) — the class's answer to a Panzer is now the sidearm, not fifteen swings.
- Pause-menu text corrected: FULL STEAM arms in 1 s (not 1.5 s), SCAVENGER persists for every class that can roll it, OVERDRIVE ramps over 3.75 s base / 3 s PaP'd.
- Armory page: 36 corrections; with the DAMAGE error fixed, the assault AK T3 is the highest DPS peak on the page.
- Still owed: FULL STEAM cards still read "SPRINT 1.5S FOR SPEED"; HANDLING stays at 3 tiers.

### v16 — 2026-09-01 — ATHLETE art installed, ADRENALINE cards re-baked
*art · build 03:39:20 FULL (.ff 115.54 MB; current .ff 03:42:32)*

- ATHLETE's three upgrade cards and pause-menu plate are installed — it is no longer a text-only card.
- ADRENALINE cards re-baked: 5 pips (max is now 5) and the value line reads "MULTI-KILLS GRANT SPEED".
- All 34 live upgrade domains now have card art.

### v16 — 2026-09-01 — ATHLETE: new slasher mobility upgrade
*gameplay · build 02:26:59 -GscOnly (current .ff 02:28:15, 114.38 MB)*

- New SLASHER-only upgrade ATHLETE (A band, max 5, survives tier promotions): +10% slide speed per level and +25% jump height per level (Lv5 = 2.25× height).
- A forward impulse at slide start (50 per level, up to 250) adds slide distance; the first knob to cut if slides feel floaty.
- Strictly per-player — one slasher's jump boost does not affect the rest of the lobby.
- Ships as a text card and text pause row until the art lands (see the ART entry above).
- Pause-menu DISTRACTION text fixed to "MAX AMMO gives +1, carry 3".

### v14.61 — 2026-09-01 — DISTRACTION: Max Ammo gives +1 grenade, not a refill
*fix*

- Max Ammo now adds ONE Cymbal Monkey / Li'l Arnie instead of refilling to full; carry cap back to 3 (v14.59's 4 was a guess — the engine's real cap measured 3).
- A Max Ammo never hands out a grenade the upgrade has not unlocked.
- In-game tells if it misbehaves: Max Ammo still filling to 3 = the opt-out did not take; Max Ammo doing nothing = wrong ammo store.

### v14.60 — 2026-08-31 — Endless Spire: late joiners get the full 9 perk slots
*fix*

- A player who joins or reconnects after the party ascends the Endless Spire was capped at 4 perks while teammates sat at 9 (a v14.56 regression); the spire now guarantees a 9-perk floor for everyone.
- The "PERK SLOTS FULL" refusal can no longer appear on the spire, where its advice was impossible to act on.
- Raised, not fixed: a weapon swap in flight at ascension can permanently freeze the tier grant; solo ascension can burn the third Quick Revive; dead players are granted perks but not teleported.
- Unverified in play as of this build (the spire ladder has never had a real run).

> **WORKSHOP UPLOAD #24 — Aug 31, 8:47 pm (Eastern) — v14.59b** (exact). v14.59 / v14.59b share one full build at 8:41 pm; written "on the eve of a publish build".

### v14.59b — 2026-08-31 — IMPACT ROUNDS and SPRINT ARMOR retired; seven bands moved
*balance · build 20:41 FULL (same .ff as v14.59)*

- IMPACT ROUNDS (assault) and SPRINT ARMOR are retired entirely — their cards no longer deal and their effects are removed.
- Rarity bands moved: BOUNTY → S, PERK SLOTS → A, BULLET FEED → A, LUCK → A, PENETRATION → B, DRAW CUT → B, LEECH → B.
- Shipped in the same build as v14.59 (one build, two entries).

### v14.59 — 2026-08-31 — DISTRACTION: Cymbal Monkeys and Li'l Arnies for the assault
*gameplay · build 20:41 FULL (per v14.59b)*

- New assault-only S-band upgrade DISTRACTION (max 2, survives tier promotions): Lv1 grants the Cymbal Monkey, Lv2 replaces it with Li'l Arnies and carries the held count over.
- Carry cap 4 with Max Ammo refilling fully (both revised in v14.61 to cap 3 / +1 per Max Ammo).
- A free Pack-a-Punch drop grabbed mid-throw can no longer eat the class gun.
- No ULTIMATE card can ever be dealt for it; it is the rarest card in the deck.
- Ships as a text card until its art is installed.
- Unverified in play as of this build.

### v14.58 — 2026-08-31 — Prompts fixed: no more "Wall Weapon", readable hint cards
*fix*

- Every priced non-door prompt (ammo crates, Heavenly Gift Altar, Call Extraction, every Endless Spire buy) was showing the text "Wall Weapon" — fixed; doors were the only prompts that looked right.
- Prompts are now a structured card: a title band, up to two detail lines, a price row and a "Hold [F] To Buy/Use" footer. The ammo crate reads AMMO CRATE over "Regular $2500" and "Pack a Punch $5000".
- The squashed "HoldXAMMOCRATE" text (spaces missing, text crammed into a narrow box) is fixed — two things were writing the same text field and the raw one won.
- Reworded to the new grammar: Call Extraction ("opens the road to the crown"), the altar ("take an upgrade card"), teleporter offline/recharging states, Rampage's sealed states, Ascend ("one way, no return"), the Uplink pointer.
- All ammo crates are now one object — the six static crates and every spire crate behave and read identically.
- Spire ammo crate prompts now end cleanly when a crate is removed (long-climb stability).

### v14.57 — 2026-08-31 — One reveal sting for Super and Ultimate; aura is the difference
*audio*

- Ultimate card pulls now play the same sting as Super pulls (the user preferred it); Ultimate volume 100 → 95 so the two match.
- The Ultimate's sting lead moved 0.10s → 0.20s to match the new sound's swell-in, so the hit still lands on the card.
- Rarity now reads through the aura: only an Ultimate brings the altar aura, plus its longer hold (0.30s vs 0.20s), bigger burst and lingering glow.
- Aura slightly louder: left/right 80 → 85, both-cards 88 → 92.

### v14.56 — 2026-08-31 — Perk cap back to 4; new PERK SLOTS upgrade card
*gameplay · build 19:58:09 FULL*

- Perk cap is back to 4 (the stock number).
- New universal upgrade domain PERK SLOTS: +1 perk slot per level over the base 4, max 5 levels (4 + 5 = 9 = every perk the map sells). Regular/Super/Ultimate cards give +1/+2/+3 slots. It appears in round-event deals and at the altars alike.
- PERK SLOTS persists through death and through class-tier promotions.
- Same evening (v14.59) its draw weight was raised from tier S to tier A on the user's call — about 2.5x more likely to be dealt.
- Endless Spire ascension grant no longer hands out the retired Mule Kick perk, which was silently raising the weapon limit to 3 and risking a dropped gun at the hardest point in the run. The grant is now exactly the nine perk machines.
- Card art (3 cards) and the pause-menu plate landed the same day (full build 19:58:09), so the domain never shipped on text fallback.
- Roster confirmed at NINE perks (Juggernog, Speed Cola, Quick Revive, Stamin-Up, Widow's Wine, Double Tap, PhD Flopper, Death Perception, Wisp Tea) — earlier "10 perks" claims were wrong.

### v14.55 — 2026-08-31 — Ultimate cards hum with the altar aura; all music down 5%
*audio*

- When an ULTIMATE card is dealt, you (and only you) hear the Heavenly Altar's aura, panned to the side the card landed on — left, right, or a louder centred version when BOTH cards are Ultimate ("an epic decision must be made").
- The aura is 2D and pinned to the screen so it does not drift as you turn; it stops when the panel closes, on disconnect, on a down at the station, or when a round event takes over, and has a hard pass ceiling so it can never get stuck.
- A floor-locked Class Tier card gets no aura.
- All music lowered 5%: floor tracks, city, relay, eclipse and the Spire track 95 → 90; boss and finale tracks 100 → 95.

### v14.54 — 2026-08-31 — Super card sting lands 0.2s earlier
*audio*

- The Super reveal sting now fires 0.20s before its card lands, cancelling the sound's own swell-in so the punch hits on the card instead of a fifth of a second after.
- With the lead equal to the hold, the riser and the Super sting now overlap for the Super's whole hold (the Ultimate still gets 0.20s of riser alone first).

### v14.53 — 2026-08-31 — Card reveal twice as fast; Ultimate sting earlier and louder
*audio*

- All card-reveal delays halved: panel open 0.35 → 0.175s; empty-socket holds 0.10/0.40/0.60 → 0.05/0.20/0.30s (regular/super/ultimate); gap 0.28 → 0.14s; tail 0.30 → 0.15s. A double-Ultimate deal now takes 1.07s (was 2.13s); two regulars 0.57s (was 1.13s).
- Card flip animation 120 → 60ms, socket 110 → 55ms so the flip survives the faster station deals.
- The Ultimate's sting fires 0.10s before its card; the sting is louder (re-rendered at -0.2 dBFS, volume 96 → 100) and the riser is ducked 90 → 86 so it punches through. Super untouched.
- The rarity burst was NOT halved (now 200/380ms) so it still reads.

### v14.52 — 2026-08-31 — Upgrade cards are now dealt, with rarity animation and sound
*art*

- The upgrade panel now opens on two EMPTY sockets and each card lands on its own beat; the wait is longer the rarer the card — 0.10s regular / 0.40s SUPER / 0.60s ULTIMATE — so the delay itself tells you something good is coming.
- A riser sound plays during the wait, the socket bursts, the card flips open with a bounce, then throws a rarity burst and leaves a lingering aura. REGULAR is deliberately plain: no riser, no burst, no aura, just a dry tick.
- The personal upgrade station runs the whole reveal at half speed (the world is not paused there); a floor-locked Class Tier card reveals as a regular; the countdown and tier badge stay hidden until you can actually pick.
- Five sounds, three newly authored (dark synth-bass direction — the first bells-and-choir pass was rejected as "too childish"); one shared riser, no double-Ultimate fanfare.
- Internal: a Lua syntax lint now runs on every build so a broken HUD script cannot ship silently.

### v14.51 — 2026-08-31 — GIANT SLAYER buffed to 8% per level
*balance*

- GIANT SLAYER boss damage 5% → 8% per level; a maxed card is now +40% (was +25%).
- Card art re-baked: +8 / +16 / +24 BOSS DAMAGE for Regular / Super / Ultimate; pause-menu text and armory page updated to match.
- Full build (image assets).

### v14.50 — 2026-08-31 — Downed teammates light their section of the tower gauge red
*gameplay*

- Any section of the tower gauge holding a downed teammate turns a solid red tile — even above where you have climbed — so you can see where to go.
- Works for any number of downed players at once, including two on the same section.
- A down below the first section (base arena) or above the last (roof, road, crown) snaps to the nearest real section instead of vanishing.
- Only last-stand players show; your own down never lights for you, and a bled-out player's spot clears (they cannot be revived). The red clears the moment a revive completes.
- Off during the finale (the gauge is the song clock there). Re-armed after your own respawn so you see current downs immediately.
- New red gauge tile art; full build.

### v14.49 — 2026-08-31 — Rampage seals at round 9; banner only, smaller, pinned to top
*gameplay*

- Rampage now locks in at round 9 (was 8).
- Flipping the Rampage breaker no longer prints any on-screen text; feedback is the cha-ching, the breaker's own prompt, its sparks and the red luck-bar art.
- The seal banner is 20% smaller (600×300 → 480×240) and moved to the top of the screen (about 3% from the top edge) instead of the middle.
- The Rampage banner is now the only thing the mode ever draws on screen.

### v14.48 — 2026-08-31 — Finale road spawns: three bands, nothing inside the crown
*balance*

- Replaces v14.47's far/near split after play-testing: zombies were spawning INSIDE the crown hall, so the road read empty until you reached the end.
- Nothing spawns past the crown gate during the road run any more.
- Every finale road spawn now rolls one of three bands (thirds of the road): solo, Rampage off = 40% crown gate / 30% middle / 30% beginning — the user's own distribution. Four players: 49/30/21. Rampage on (3–4 players): 52/30/18.
- Elites use the same roll, except the "beginning" share stays near/behind the party so a Panzer never wastes one of the four finale slots 7,000 units away.
- Unverified in play as of this build.

### v14.47 — 2026-08-31 — The crown-end wall: the finale road can no longer be sprinted past
*balance*

- Most finale road zombies now spawn at the crown end regardless of where the party is, so a horde builds between you and the objective and walks back at you. (Superseded by v14.48 the same day.)
- Share sent to the crown end scales with players and Rampage: 65/69/73/77% for 1–4 players, 77/81/85/88% with Rampage on, capped at 88% so something is always at your back.
- Elites (Panzer, Protector, Reaver, hounds) follow the same rule.
- Both rules stand down once the crown seals for the hold-out.

### v14.46 — 2026-08-31 — Music slider works; no boss track on the Spire; silent OFF seal
*audio*

- The in-game Music volume slider now actually lowers the map's music (all seven tracks were grouped as menu audio and ignored it).
- No Panzer/boss music on the Endless Spire — the Spire keeps its own track (the door honour guards would otherwise make the boss track permanent).
- Reverts v14.40's text line: when Rampage is OFF at the seal round nothing is shown at all; if you see anything at the seal, Rampage is on.
- Needs rebuilt sound banks (streamed music aliases).

### v14.45 — 2026-08-31 — Relocated zombies now climb out of the ground instead of popping in
*fix*

- Zombies that are too far away and get relocated to you now play the normal climb-out at their new spawn point — ghost, riser FX, dig-out animation — instead of simply appearing behind you.
- The round-speed sweep pauses while a zombie is mid-rise and resumes the moment it finishes, so relocated zombies keep the right gait.
- Plugs a leak in stock's own rise routine (an invisible anchor left behind if the zombie dies mid-rise), which matters over a long Spire climb.
- Unverified in play as of this build.

### v14.44 — 2026-08-31 — Boss music no longer sticks; armored sprinters slowed
*fix*

- Boss music stuck on after killing both Panzers (seen on Rampage) — fixed; the track now releases when the last Panzer dies. The same bug would have made the boss track permanent after the first Endless Spire door.
- Armored sprinters now run at -10 rounds of speed instead of +10: e.g. round 15 rate 1.020 → 0.847, round 30 1.062 → 1.006. Their armor and 20× health stay.
- Under Rampage the ramp is steeper and the slowdown bites harder early (round 15 ≈ 0.889).

> **WORKSHOP UPLOAD #23 — Aug 31, 3:07 am (Eastern) — v14.37 – v14.40** (approx). fog first renders, Rampage down rule, the locked tier card, sky back to Miami; no build clocks recorded.

### v14.40 — 2026-08-31 — Sky reverted to Miami night; the Spire is the dark place
*art*

- Reverts v14.37's dark skybox: the tower is back to the Miami night sky. A baked sky cannot be Spire-only, and the Spire's own fog hides the sky entirely, so the contrast on ascending is the effect.
- Tower fog stays ON at 0.38 opacity; the Spire's near-black red fog is unaffected.
- Full build (baked world setting).

### v14.39 — 2026-08-31 — Class Tier: the locked card is dealt and shown
*gameplay*

- When the Class Tier card rolls but you are below its floor gate (floor 10 for Tier 2, floor 20 for Tier 3), the card is now DEALT and shown LOCKED in the right slot — dimmed with a cold grey-blue tint and the "TIER 2 AT FLOOR 10" badge stamped across the gun illustration — instead of hidden (v14.35).
- Trying to select it plays a deny sound; it cannot be taken, so that deal is effectively one card. The user chose this over a free third preview slot.
- Only the right slot can lock and a lone locked card is never dealt, so a dead panel is impossible.
- The badge sits on the locked card when one is dealt, otherwise in the top-left gutter — never both. A draw-order bug that would have hidden the badge behind the card was fixed.
- Locked-card dim retuned 0.22 → 0.55 so the gun name stays readable.

### v14.38 — 2026-08-30 — Rampage: a down halves everyone's luck
*balance*

- With Rampage on, any player going down halves EVERY player's luck bar (including the downed player, who also pays the normal -25). At a full bar the downed player loses 62.5, everyone else 50.
- An OVERCHARGE at 150 halves to 75 and drops out of the guaranteed-Ultimate band.
- Applies in solo too (62.5 off a full bar instead of 25). Two downs in one tick fire twice.
- Rampage off: no change.

### v14.37 — 2026-08-30 — Fog renders for the first time; darker sky
*art*

- The map (and map 1 before it) had NEVER rendered volumetric fog — the fog call's "opacity" slot was actually a fade time. Fixed; fog now draws.
- Tower fog on at 0.38 opacity (retuned down from the authored 0.55 since nobody has seen it in game yet).
- Endless Spire: on ascension the sky goes near-black red — fog opacity rises 0 → 0.90 over ~6s and holds the whole climb, no horizon.
- Sky swapped to a dark skybox (reverted to Miami night in v14.40).
- Full build required.
- Unverified in play as of this build.

### v14.36 — 2026-08-30 — Endless Spire back to one door per floor
*gameplay*

- The Endless Spire now has 100 doors, one per floor (was 50, one per pair of floors in v14.23), alternating sides to match the main tower's cadence. Reverts v14.23's 50-door compromise.
- A full spire climb now costs 300,000 points (100 doors × flat 3000) and triggers the v14.31 Panzer honour guard 100 times with 100 × 30 s sealed holds.
- Enemies now wake one floor above the highest bought door (was two floors), so they cannot spawn ahead of the party.
- Test build with dev + god mode armed to measure entity headroom and diagnose the crown altar prompt (which has never worked in any build) — test build, not for publish.
- Unverified in play as of this build.

### v14.35 — 2026-08-30 — Class tier promotions now require reaching floors 10 and 20
*gameplay*

- The class TIER card now needs the class gun Pack-a-Punched AND the player's own highest floor reached: floor 10 for tier 2, floor 20 for tier 3. Closes the shortcut where a free-PaP powerup drop in the base arena made a player tier-eligible with no doors bought.
- The floor record only ever rises and counts alive/downed players only (spectating a climbing teammate does not count); once earned, the promotion can be taken anywhere.
- Ascending to the Endless Spire still grants full tiers regardless of floor. Dev mode does not skip the gate.
- New "TIER 2 AT FLOOR 10" / "TIER 3 AT FLOOR 20" badge on the upgrade panel (top-left, mirror of the luck badge), shown only when the floor is the sole thing blocking the tier card. Baked art: steel pill with amber chevron.
- The pause menu CLASS TIER row now shows from tier 1 and states the next requirement ("tier 2: Pack-a-Punch + floor 10", etc.).
- Full build (new images).

### v14.33 — 2026-08-30 — Skirmisher nerf: damage resistance cap and another −10% damage
*balance*

- Skirmisher DAMAGE REDUCTION now caps at level 5 (−25% incoming) instead of 10; assault and heavy still reach −50%, slasher was already capped at 5.
- Skirmisher primaries −10% again (×0.81 of start of day): MAC-10 167→150 (PaP 209→188), MP5 338→304 (PaP 423→380), MP7 483→434 (PaP 604→543).
- Skirmisher shotgun secondaries unchanged.
- Note: skirmisher effective HP while sprinting with Sprint Armor drops from 400 to 267 — second-squishiest class and the fastest.

### v14.31 — 2026-08-30 — Endless Spire hard mode: 4× elites, Panzer honour guard, 30 s door seal
*gameplay*

- Elite spawn throughput on the Endless Spire is 4× (8× with the Rampage Inducer); the concurrency cap (12 live elites) is unchanged, so the roof stays saturated instead of being hit once a wave.
- Every spire door purchase drops one Panzer per living player (max 4) onto the floor just opened, staggered 3.5 s apart.
- Honour-guard Panzers pay the elite rate (500 points to the killer + a guaranteed Max Ammo) instead of the 1000-point team jackpot; boss-round Panzers keep the jackpot.
- Spire doors 2 onward open SEALED for 30 s before they can be bought (door 1 exempt); trying to buy during the seal plays the deny sound.
- Unverified in play as of this build.

### v14.30 — 2026-08-30 — Slasher nerf: melee −20%, Thor's Thunder −20%
*balance*

- Melee damage ×0.8 on every blade, base and PaP: Combat Knife 1600/3200, Wakizashi 3200/6400, Stormbreaker 5440/10880 (backstab follows at ×1.5: max 16320, was 20400).
- Melee hits on the Panzer, Rogue Protector and Reaver now pay one third (was one half) — combined with the cut above, a blade lands at 0.264× its previous damage on those three.
- THOR'S THUNDER: damage 16/28/40/52/64% of victim max HP (was 20–80), radius 64–192 u (was 80–240), cooldown 4.50→1.50 s across levels (was 3.75→1.25); victims per strike stays 2–6.
- Full build (melee numbers are baked into weapon data).

### v14.29 — 2026-08-30 — Armored Sprinter resists all damage; skirmisher is now the fastest class
*balance*

- The Armored Sprinter's 1/3 damage armor now applies to EVERY damage source (melee, explosives, blades, splash) — previously only bullets, so the slasher killed it 3× faster than intended. Ricochet sound and red damage numbers now fire on melee/explosive hits too.
- Fixes a pre-existing hole where IMPACT ROUNDS splash ignored sprinter armor entirely; CLEAVE splash is armored too. Wisp Tea's damage is deliberately NOT armored.
- Base speed swap: skirmisher 1.0→1.1, slasher 1.1→1.0. Order is now heavy 0.75 · assault 0.9 · slasher 1.0 · skirmisher 1.1; max SPRINT ceilings become skirmisher 1.65, slasher 1.50.
- Upgrade panel on controller becomes d-pad only once a d-pad press is detected (from the class draft onward); keyboard navigation is unchanged. Restores the v10.21 directive undone by v10.19/v10.20.

### v14.28 — 2026-08-30 — Fixed Juggernog wiping out Vitality and base health
*fix*

- Fixed: every round change, revive or Jugg loss rebuilt max HP from the stock 100 base, so Jugg gave 200 (not 250) and VITALITY levels vanished ("I have 210 but level 3 vitality... went back down to 200").
- Base health now correctly 150; expected max HP: VIT 3 = 180, Jugg = 250, Jugg + VIT 3 = 280, Jugg + VIT 5 = 300, surviving round flips, revives and Jugg rebuys.

> **WORKSHOP UPLOAD #22 — Aug 30, 5:58 pm (Eastern) — v14.22 – v14.23** (probable). Rampage Inducer full build 4:35 pm, then the spire live-test fixes; v14.25 / v14.27 say "not in any build yet".

### v14.23 — 2026-08-30 — Endless Spire fixes from the first real run: 50 real doors, no more instakill
*fix · build 16:35:56 (the .ff the reported run tested, not this version's build)*

- Root cause of most reported spire bugs: the two sliding door slabs never re-seated after their first use, so doors 3+ did not exist, zones past the first stayed disabled, and the game's out-of-bounds failsafe (Samantha laugh + unrevivable kill) hit anyone past ~floor 6.
- Spire doors are now 50 real resident slabs (one per two floors, on the east face), each opened once on purchase; full climb costs 150,000 points (50 × 3000).
- Bypass watchdog: if a player is ever found 250+ units up a sealed door's stairs, that door opens free rather than leaving zones disabled.
- The "weird headboards" lintels over spire doorways (v14.20) are removed.
- Fixed 20-unit bottomless gaps between landings and crate shelves; shelf ammo crates get a single collider (no more buggy ledge/trigger); all spire crates rotated 180° (verify facing by eye).
- Full build. Unverified in play as of this build.

### v14.25 — 2026-08-30 — Rampage: elites and bosses get 1.25× health
*balance*

- With the Rampage Inducer on, the Panzer, Rogue Protector, Reaver, Hellhound and Armored Sprinter all get ×1.25 health, stacking with co-op scaling (a quad-player rampage Panzer is 3.5× the solo baseline).
- Watch the Armored Sprinter: its effective HP vs bullets goes from ~×60 to ~×75.
- Code only, not in any build yet. Unverified in play as of this build.

### v14.26 — 2026-08-30 — Fixed Wisp Tea triggering Thor's Thunder and cleave
*fix*

- Fixed (live since v14.16): every wisp hit counted as the player's own melee swing, so it fired THOR'S THUNDER lightning, rolled CLEAVE splash, drew damage numbers for hits nobody made, and applied upgrade multipliers that let a wisp solo a Panzer again.
- Wisp damage now passes through raw, so its hits-to-kill numbers (v14.19c) mean what they say.

### v14.24 — 2026-08-30 — Overcharge zap sound stops when you have nothing left to upgrade
*fix*

- The every-3-seconds overcharge zap no longer nags a player with max luck who has no upgrades left to take; it resumes on its own if a tier promotion hands headroom back.
- The luck bar's overcharge animation still plays (silently); the bar remains pinned at full.

### v14.27 — 2026-08-30 — Rampage: two Panzers on boss rounds
*gameplay*

- With the Rampage Inducer on, boss rounds field 2 Panzers at once (normal: 1). They count against the shared 12-elite cap, spawn 3 s apart in different spots, and share the boss music.
- The finale road is excluded — only one Panzer follows the party there.
- Code only, not in any build yet. Unverified in play as of this build.

### v14.22 — 2026-08-30 — The Rampage Inducer: opt-in hard mode
*gameplay · build 16:35 FULL (16:25:40 .ff shipped a stale SFX bank)*

- New RAMPAGE INDUCER switch (circuit-breaker model from the first map) on the back wall of the teleport bay; it sparks for the rest of the game when on and locks in at round 8.
- Rampage: zombies hit full sprint at round 10 (normal 18), elite waves 2×, spawn delay ×0.664 with a 0.20 s floor (spire floor 0.16), and the luck bar turns red with a purple max. Works in the Endless Spire.
- New shared cap of 12 live elites in every mode fixes a pre-existing overrun (up to 18 at four players).
- Built and asset-verified; nobody has booted it — check the breaker's facing first. Unverified in play as of this build.

### v14.21 — 2026-08-30 — AK-47 and Krig 6 +5% damage
*balance*

- Krig 6: 344→361 (PaP 430→451). AK-47: 430→452 (PaP 538→565). Enfield unchanged.
- Internal: the weapon-registration guard (223 vs 220) now trips at the end of gun generation — pre-existing from v14.17, not a live bug, deliberately not raised.

### v14.20 — 2026-08-30 — Glowing lintels over every Endless Spire doorway
*geometry*

- A red glowing header band over each of the spire's 100 doorways so the door positions are visible (Workshop report: "doors missing but I still got the $3000 prompt"). Sloped top, no gameplay change.
- Not built — parked for the next full build. (Removed again in v14.23.)

### v14.19c — 2026-08-30 — Wisp Tea no longer melts bosses; Wisp Tea and Death Perception cost 2000
*balance*

- Fixed: the wisp did a flat 1000/hit to bosses (killing a round-5 Panzer in 11 s, a Rogue Protector in 3 s) and ignored the Armored Sprinter's 20× health.
- Wisp damage is now hits-to-kill by tier: trash 3 hits, elites 12, Panzer 60 (more than a wisp can land in its 30 s life, so it can never solo a boss).
- Wisp Tea price 300→2000; Death Perception 1500→2000.
- Perk-drop powerup correctly grants Wisp Tea (verified).

### v14.19b — 2026-08-30 — Scripted perk-drink sounds retired
*audio*

- The map's own cap-pop/gulp drink sounds are switched off, since the BO7 cans (v14.17) carry their own foley — no more bottle sounds layered over can sounds.

### v14.19 — 2026-08-30 — Endless Spire zombies can finally path and attack
*fix · build 15:05:10 FULL*

- Fixed: the Endless Spire had NO navigation mesh at all, so every zombie there was inert ("zombies will not attack players or target them"). 22 mesh seeds added, one per spire zone.
- Full build; mesh verified to have doubled in size. Unverified in play as of this build (chasing/attacking on the spire not yet seen).

### v14.18 — 2026-08-30 — Assault buff: HEADSHOT and GIANT SLAYER 5% per level
*balance · build 15:22:22 FULL*

- HEADSHOT (assault): +5%/Lv, +50% at cap (was +4%/+40%). GIANT SLAYER (assault): +5%/Lv, +25% at cap vs bosses/elites (was +4%/+20%).
- Real effect on a maxed assault: +5.4% on a boss headshot, +3.8% on a horde headshot, +2.1% on a boss body shot.
- All six card images re-baked to +5/+10/+15; pause-menu lines updated.

### v14.17 — 2026-08-30 — Every perk now drinks from its BO7 can
*art*

- All nine other perks (Jugg, Speed, Quick Revive, Stamin-Up, Double Tap, Widow's Wine, Death Perception, PhD, Mule Kick) now use the BO7 can drink animation like Wisp Tea.
- Can foley (grab/open/drink/throw/land) rides in the animation itself, so audio always matches; this also fixes Wisp Tea's silent drink.
- Full build. Verify in game: drink anim + sounds on each perk.

> **WORKSHOP UPLOAD #21 — Aug 30, 2:47 pm (Eastern) — v14.16** (exact). git commit "v14.16 publish candidate" at 2:37 pm (Wisp Tea, the 250-string fix, BO7 cans).

### v14.16 — 2026-08-30 — Wisp Tea replaces Deadshot
*gameplay*

- Deadshot Daiquiri is retired; the BO7 Wisp Tea perk takes its slot (stone-shrine machine, teacup emblem).
- Wisp Tea: hitting zombies rolls 1-in-20 to summon a wisp companion that chases and chunks zombies near you for 30 s; 2-minute cooldown; 300 points (retuned to 2000 in v14.19c).
- Three bugs in the vendored perk fixed (orphaned effects, wisp stranded on disconnect, stacking follow threads). Blacklight machine glow passes from Deadshot to Wisp Tea; new HUD crest icon.
- Full build. Verify in game: machine facing, wisp summon + effects, icon, jingle.

### v14.15 — 2026-08-30 — Red damage vignette no longer outlives the heal
*fix*

- Fixed: with RECOVERY (faster regen) or a VITALITY purchase heal, the screen kept flashing red for seconds after reaching full health. The overlay now clears the moment health is full.
- RECOVERY's regen delay no longer resets from friendly-fire hits.

### v14.14 — 2026-08-30 — The "250 items" crash is closed for good
*fix*

- Fixes the mid-match "Exceeded '250' items for type 'triggerstring'" crash that players hit after buying a door in the Endless Spire and in 4-player games (it crossed around floor 45 after two party-size changes).
- The v14.3 door-price flattening turned out to do nothing at all; it is deleted and the fix now lives in the map itself (41 distinct door values collapsed to 1). No door price a player pays changed.
- Door prompts no longer re-stamp when the party size changes; they keep showing BOTH the destination and the price.
- Accepted trade: after a player joins or leaves mid-match, a door sign can show the old price while the purchase charges the live one (a smaller party pays less than shown, a larger party more).
- Finale extraction, spire and teleporter prompts still show live prices.
- Net budget 180 of 250 slots down to 140, and it can no longer grow with run length.

### v14.13 — 2026-08-30 — SCAVENGER stays through promotions for the Assault only
*gameplay*

- Corrects v14.12: SCAVENGER now survives a class-tier promotion for the ASSAULT only; a Skirmisher or Heavy taking a tier card loses it again as before.
- The pause menu's "reset on promotion" badge is now computed per player (by class), so it can never disagree with what a promotion actually resets.
- Pause-menu SCAVENGER text now reads "primary kills; assault keeps on promotion".

### v14.12 — 2026-08-30 — HEADSHOT and SCAVENGER survive tier promotions
*gameplay*

- HEADSHOT and SCAVENGER upgrades no longer reset when you take a class-tier card (the Assault's two staple grinds were being wiped by every promotion).
- SCAVENGER persistence spilled over to the Skirmisher and Heavy as well in this build (corrected in v14.13).
- Persistent-through-promotion set is now ten rows: DMG REDUCTION, LUCK, SPRINT, SPRINT FIRE, SPRINT ARMOR, BACK ARMOR, VITALITY, HEADSHOT, SCAVENGER plus the tier row.
- Pause-menu copy: HEADSHOT and SCAVENGER rows say "survives promotion"; the tier card's fallback text now says "class-wide upgrades kept" instead of listing names.

### v14.11b — 2026-08-30 — VITALITY, RECOVERY and RUN AND GUN card art installed
*art*

- The two new Heavy upgrades (VITALITY, RECOVERY) now show full card art and pause-menu plates instead of plain text.
- RUN AND GUN cards re-baked to show both halves (free shots AND bonus damage on the move).
- Full build (image assets changed).

### v14.11 — 2026-08-30 — Ten-point class rebalance: Heavy becomes the tank
*balance*

- RUN AND GUN now also adds +20/35/50% damage to shots fired while moving (same ladder as its free-ammo half).
- MOMENTUM removed. SECOND WIND moves from the MP7 to the MP5 (MP7 keeps ADRENALINE).
- NEW Heavy upgrade VITALITY: +10 max HP per level, 5 levels (+50 over the 150 base); kept for the whole game, even across promotions.
- NEW Heavy upgrade RECOVERY: health regen starts 10% sooner per level, 3 levels (30% at cap).
- REGEN removed (Heavy). BACK ARMOR removed from the Assault (Heavy-only now). SPRINT ARMOR removed from the Slasher (Skirmisher-only now).
- MOBILITY max 10 to 5: Heavy speed ceiling 1.125 to 0.9375, now the slowest in the map.
- DMG REDUCTION caps at 5 for the Slasher (10 for everyone else); CLEAVE max 6 to 3.
- VITALITY and RECOVERY shipped on text-only cards until the art landed (v14.11b).

### v14.9b — 2026-08-30 — Real luck-overcharge zap art, deeper spaced zap sound
*art*

- The four electric-blue zap frames for the 150% luck overcharge state are now real art, drawn over the actual bar (no HUD jitter).
- The overcharge zap sound now fires as a single ~1.3 s semi-deep buzz every 3.0 s instead of a continuous crackle bed (user rejected the continuous version).

### v14.10 — 2026-08-30 — Stray zombies relocate near the player instead of stalling
*fix*

- Zombies left far behind (e.g. after you teleport down the tower) are now quietly moved to a spawn near the player instead of running the whole tower and stalling the round. Nothing is killed and the round count is untouched.
- Bosses and elites are excluded from relocation.
- Also fires after a teleporter ride, and copes with two rides within 1.5 s.
- Relocated zombies are spread across different spots, never piled onto one tile, and never popped in inside your view.
- This module had been sitting in earlier builds completely inert; it is wired for the first time here.
- Unverified in play as of this build.

### v14.7 — 2026-08-30 — Hellhound eyes and fire trail; elites stop teleporting onto you
*fix · build 02:30 (time given in the v14.8 entry, not this one)*

- Hellhounds now have their glowing eyes and fire trail (they had rendered plain since they were added).
- Fixes elites "randomly spawning at you when you are too far away": a breather teleporter ride was fooling the stuck-boss watchdog into relocating a boss that was never stuck.
- When a relocation IS warranted the elite now ARRIVES (Panzer/Protector by sky drop, hound/Reaver with a ground tell and a walk-in) instead of appearing.
- Relocations no longer trigger the landing shockwave that would have silently nuked the horde beside you for zero points.
- Still open: hellhound corpses leak actor slots.

### v14.9 — 2026-08-30 — Luck overcharge: the secret 150% band
*gameplay*

- The luck bar now secretly keeps climbing to 150%; the HUD still caps at 100% and nothing sounds between 101 and 149.
- At exactly 150% the bar zap-animates and a crackle zap sound plays until luck drops below 150 (a down, an upgrade event, or the spire reset ends it).
- Pulling upgrade cards at 150% luck guarantees BOTH non-tier cards are ULTIMATE (redealing a card that has no +3 headroom).
- Luck between 101 and 149 quietly improves the rarity dice.
- Zap art and sound are placeholders in this build (replaced in v14.9b).

### v14.8b — 2026-08-30 — Gift of Death +30% against bosses and elites
*balance*

- The Death Machine powerup ("Gift of Death") hits bosses and elites 30% harder: shots to kill Panzer 20 to 16, Protector 6 to 5, Reaver 5, hellhound 3.
- The Reaver and hellhound previously had no Gift of Death lane at all (the Gift did negligible damage to them); both now have one.
- The Armored Sprinter now pays its own luck value (4) on kill.

### v14.8 — 2026-08-30 — Duplicate drops pay luck
*gameplay*

- Grabbing a Pack-a-Punch drop when every gun you hold is already packed now gives +20% luck (Max Ammo consolation kept).
- Grabbing a free perk bottle when you already own every perk the map sells gives +10% luck (Max Ammo consolation kept).
- Both are boosted by the LUCK upgrade's gain rate and sound the luck pips like any other source.
- Confirmed: the v14.6 guaranteed-rarity redeal happens before the cards are shown, so you never see a card swap.

### v14.6 — 2026-08-30 — Full luck bar now truly guarantees an ULTIMATE card
*fix*

- Fixes "had max luck and didn't get an ultimate card": the guarantee could only upgrade the two dealt cards, and a hand of low-cap upgrades (PENETRATION/RECOIL cap 2, SPRINT FIRE cap 1) had nothing that could hold +3.
- Now the weakest dealt card is REDEALT from upgrades with enough headroom, then promoted; the tier card is never touched.
- The same mechanism enforces the 50%-luck SUPER floor and the opening-hand SUPER.
- Only when NO available upgrade has +3 headroom (deep late-game) does the honest lower label still show.

### v14.5 — 2026-08-30 — Elite kills pay 500 to the killer only
*balance*

- Every ELITE kill (Rogue Protector, Reaver, Hellhound, Armored Sprinter) now pays a flat 500 points to the player who landed the kill, scaled by Double Points and the BOUNTY upgrade (+5%/Lv).
- Replaces the quiet team-wide payouts (Protector 250, Reaver 400, Hound 150, Sprinter 400).
- No killer (trap, cleanup, boss-on-boss) means no money. Luck still goes to the last hit.
- The Panzer is the BOSS, not an elite: it keeps its 1000-point team-wide jackpot.

> **WORKSHOP UPLOAD #20 — Aug 30, 1:45 am (Eastern) — v14.4** (exact). "THE publish build", .ff at 1:42 am, carrying v14.2 + v14.3.

### v14.4 — 2026-08-30 — Base ammo crate collision built into the map; publish build
*geometry · publish=yes · build 01:42:42 full*

- The base ammo crate's collision is now real map geometry, guaranteed clear of the lap-1 stair (+24u margin) with at least 128u of walkway to its west, so the v13.23 navmesh break cannot recur.
- All six static ammo crates lose their script-spawned clips (six fewer entities at load, easing the pressure behind the v14.1 crown-altar incident).
- Supersedes the 01:33 build as the publish artifact; carries v14.2 + v14.3 + this.
- Full rebuild with navmesh and lighting; walkability proofs pass with the crate in place.

### v14.3 — 2026-08-30 — First pass at the 250-string crash; frozen hellhounds fixed; publish build
*fix · publish=yes · build 01:33:47 full*

- Targets the Workshop-reported "Exceeded '250' items for type 'triggerstring'" crash "when getting far" (ledger was ~242 of 250 on a long co-op run).
- The Personal Upgrade Station / crown altar is now a FLAT 3000 per buy (was 2000 +250 per purchase, which minted a new prompt string every buy). Unlimited buys unchanged, so it is a price cut past buy #5.
- The Endless Spire's 100 per-floor door prompts collapsed to one string (it would have crashed about eight doors after ascension).
- Hellhounds no longer freeze in place for the rest of the match after their target downs, spectates or goes invulnerable ("dog rounds bugged" - there are no dog rounds; these are the elite hounds). Frozen hounds were also blocking new ones from spawning.
- Attempted to flatten stock's 41 unread door-price strings at load; flagged unverified in the entry, and v14.14 later found it did nothing.
- Still open after this build: hounds have no glowing eyes or fire trail (fixed v14.7).

> **WORKSHOP UPLOAD #19 — Aug 29, 10:36 pm (Eastern) — v14.2** (approx). the 3-player bug batch is the only entry between the v14.1 uploads and the 1:42 am build.

### v14.2 — 2026-08-30 — 3-player bug batch: targeting, Death Perception leak, crate pricing
*fix*

- Base ammo crate moved off the lap-1 east stair to the core's west face; its collision had cut the stair navmesh so first-room zombies would not climb and upstairs zombies would not come down.
- Insta-Kill is now a true one-hit on regular zombies (Armored Sprinters included); bosses and elites keep the 3x damage instead.
- Zombie targeting rewritten: zombies pick the closest player by straight line instead of getting stuck on one player (the host) in 3-player games.
- The free-perk bottle no longer hands out perks no machine sells (a Mule Kick roll was lighting the Death Perception icon with no effect).
- Death Perception's wallhack outlines no longer leak to every player in the lobby.
- Ammo crates now correctly charge 5000 for a Pack-a-Punched gun (2500 base) - PaP'd class guns were being sold at the base price.

> **WORKSHOP UPLOAD #18 — Aug 29, 4:19 pm (Eastern) — v14.0 / v14.1** (probable). third of three uploads in 26 minutes; v14.1 is titled PUBLISH BUILD (Endless Spire + crown altar hardening).

> **WORKSHOP UPLOAD #17 — Aug 29, 4:00 pm (Eastern) — v14.0 / v14.1** (probable). second of the three (re-upload; likely the thumbnail/description or a rebuilt .ff).

> **WORKSHOP UPLOAD #16 — Aug 29, 3:53 pm (Eastern) — v14.0 / v14.1** (probable). first of the three.

### v14.1 — 2026-08-29 — Crown altar hardening and publish disarm; publish build
*fix · publish=yes*

- The crown's upgrade altar ("untriggerable") should now get its trigger: the Endless Spire's 100 resident door slabs are cut to 2 (the climb is sequential), relieving the entity pressure that was starving the last-placed station, and the altar's trigger now installs first and self-heals on a 1 s retry.
- Retracted the theory that a subscribed Workshop copy was shadowing dev builds.
- Dev/god flags off, test harness and diagnostic prints removed for publish.
- Unverified in play as of this build (the altar fix was never confirmed by the user).

### v14.0 — 2026-08-29 — The Endless Spire: post-victory endless mode
*gameplay*

- Winning the finale no longer ends the run automatically: choose the exfil pad to EXTRACT (the old ending) or the dais teleporter to ASCEND the whole party, one way, to the Endless Spire (first committed hold wins).
- The Spire is a second 100-floor tower off to the east, visible from the whole climb: monochrome red, gold vendor hubs every 10th floor, ammo-crate shelves from floor 5, a gold summit with a red beacon.
- On ascension every player is fully kitted: Tier-3 class gun Pack-a-Punched, every eligible upgrade maxed, all ten perks, full ammo and health.
- Spire doors open in sequence at a flat 3000 each; spawn pacing is hot (this is the map's hard mode).
- New music loop "Neon Static" and five new screens (choice / arrival / death / summit win / emblem).
- Wipe = "THE CLIMB ENDS HERE"; summit extraction for 7500 = "YOU CONQUERED THE SPIRE".
- Perk purchase limit 9 to 10.

> **WORKSHOP UPLOAD #15 — Aug 29, 2:24 pm (Eastern) — v13.19** (approx). Death Perception replaces Elemental Pop; dated Aug 29 between candidate #3 and the Spire.

### v13.19 — 2026-08-29 — Death Perception replaces Elemental Pop
*gameplay*

- Elemental Pop is gone; its machine slot now sells DEATH PERCEPTION: see the horde through walls as green outlines (bosses and elites excluded). Late buys, perk loss and fresh spawns all self-correct within about 2 s.
- Costs 1500 (Elemental Pop was 2000). New machine model and crest icon; HUD text "Sense the horde through walls".
- Luck-pip and headshot-ding sounds ride the same build.
- Dev/god flags temporarily re-armed for the user's quick verify (test build, not for publish).

> **WORKSHOP UPLOAD #14 — Aug 29, 1:14 pm (Eastern) — v13.17** (probable). "PUBLISH CANDIDATE #3" (PaP glow root cause, AAT off, disarm).

### v13.17 — 2026-08-29 — Pack-a-Punch glow finally on every vendor; publish candidate #3
*fix · publish=candidate*

- Every Pack-a-Punch vendor (crown + four breather lounges) now shows its own glow and animations; every machine's FX had been drawing at the crown 19k units away, so four earlier server fixes looked like they did nothing. User confirmed.
- The pack's elemental re-pack (AAT) is disabled: no machine offers the 2500 double-pack lane any more.
- Perk-drink sound cues locked at their tuned levels; new teleporter fire/ready cues.
- All dev flags and harnesses removed for publish prep.

> **WORKSHOP UPLOAD #13 — Aug 29, 2:19 am (Eastern) — v13.14** (exact). "PUBLISH CANDIDATE #2", built 2:14 am.

### v13.14 — 2026-08-29 — Armored Sprinter confirmed live; publish candidate #2
*fix · publish=candidate*

- Armored Sprinter confirmed in play: chain-armor body, smoke, +12-round sprint, 1/3 bullet damage with red damage numbers and ricochet sounds.
- Fixes a boot crash in the Pack-a-Punch pack's power watch that killed the 03:22 build.
- Unified five-machine Pack-a-Punch network, red damage numbers, ricochet and perk-drink sounds, and the luck-bar art all ride this candidate (supersedes the 02:14 candidate).
- Round-1 test flood and dev flags removed.

### v13.8 — 2026-08-29 — Balance pass off the first enemy table
*balance*

- Zombie base health multiplier 1.25 to 1.15 (solo approx 3.1k HP at round 20, 8.1k at 30, 21k at 40); the co-op +0.15 per player is unchanged.
- Armored Sprinter softened: bullets do 1/3 damage (was 1/4) and it runs at round +12 speed (was +15).
- Reaver HP at round 20 cut 20k to 15k (32.4k at r30, 69.9k at r40, 150.9k at r50).

### v13.7 — 2026-08-29 — The Armored Sprinter joins as elite #3; the ladder is complete
*gameplay*

- NEW elite, the ARMORED SPRINTER: from the lap-30 door, every 3rd round, 1 + players/2 of the round's own zombies (cap 3 alive) are promoted - chain-armor body, steam jets, runs at round +15 speed, regular zombie health, bullets do 1/4 damage with a clank (melee and explosives full).
- Elite ladder is now door-gated at 10 Protector / 20 Reaver / 30 Sprinter / 40 Hellhound (hounds moved to the lap-40 slot).
- The Fury Reaver is restored exactly as it was (an intermediate build had replaced it with the sprinter; reverted on the user's "add, don't replace").
- Sprinters count toward the round, get no gauge pip (the smoke is the tell), and play no role in the finale.
- Sprinter kill: luck to last hit plus a quiet 400-point team reward (changed in v14.5).

### v13.6 — 2026-08-29 — Six live-test fixes: solo Quick Revive, new Pack-a-Punch, roofs off, teleporter rules
*gameplay*

- Solo Quick Revive reworked (the v13.5 version failed in game): now correctly 500 points and gated on power.
- Pack-a-Punch machines replaced with the animated CW/BO6-style ALXS machine at the crown and all four breather vendors (FX and animations kept). Crown machine facing still to be verified live.
- Breather lounge roofs REMOVED (open-top: you can look up and see the tower); a glowing cap band on the wall heads keeps the colour outline.
- Tower shell removed after one build (reverts v13.5's shell).
- Teleporters: down-pads are gated only by power now (bay-door gate removed); up-pads keep their door gates; cooldown 30 to 45 s. Porting down before the bay door is bought lands you inside the sealed bay (the 750 door buys from either side).
- Elemental Pop icon remade to match the circle set.
- Panzer 4-player health multiplier 2.6 to 2.8 (Protectors ride the same table).

### v13.4 — 2026-08-28 — Elemental Pop replaces Electric Cherry
*gameplay*

- The Electric Cherry machine now sells ELEMENTAL POP (the BO6/BO7 effect); the reload shock-nova is gone.
- With Elemental Pop, every bullet hit has a 6% chance (at most once per 1.5 s per player) to proc a random element on a non-boss zombie.
- SHOCK: chain zap on up to 4 zombies within 140 units, stuns, deals 35% of round health. FIRE: 4 burn ticks. FROST: slows the zombie to 0.45x for 3 s.
- A proc sting sound plays for the buyer; the HUD perk row is renamed and re-described, and the Elemental Pop cabinet finally sells what its sign says.
- Build-breaking duplicate perk-machine asset registrations removed. Machine facing confirmed correct; Deadshot's unpowered model sits 90 degrees off (accepted, cosmetic before power). Machine purchase animations deliberately not wired yet.

### v13.3 — 2026-08-28 — Boss spawn fixes, BO7 perk machines, crown PaP confirmed
*fix*

- Rogue Protectors no longer spawn with their feet buried in the stairs: every boss is now stood on the first solid surface under its spawn point.
- The Panzer's "died instantly then respawned" bug is fixed: it is hidden, invulnerable and fully flagged from its spawn frame, so it can no longer be shredded (or splash-killed by a landing Protector) before its real health lands.
- All nine perk machines are now BO7/BO6 machine models (an Elemental Pop cabinet stands in for Electric Cherry; Widow's Wine wears its "WIDOW'S WINE" plate), each swapping to a lit version when power comes on. Six never-seen perk-row lights retired.
- The crown hall's real Pack-a-Punch exists after all (the earlier "no crown PaP" claim was a search mistake); it moved to the same 64-unit wall standoff as the upgrade station, so the hall holds a real PaP AND an upgrade station.
- The UDM sidearm's opaque sight (missing reflex lens materials) is fixed, closing the open linker-error item from v11.5.
- Unverified in play as of this build (perk machine facing, footprint and seams still on the in-game verify list).

### v13.2 — 2026-08-28 — Teleporter spur zombie spawn, crown station out of the wall
*geometry · build 19:52 -GscOnly (peer) + full build*

- Each breather lounge gains a zombie riser on the open gantry between the lounge and its teleporter pad, so the spur is no longer a one-entrance pocket (176 units from the teleporter arrival point).
- Crown hall upgrade station pulled out of the wall (standoff 33 -> 64 units) after "Pap is inside the wall".
- Comments claiming the crown PaP had been removed — CORRECTED the same night in v13.3 (the crown PaP does exist). No gameplay change from that item.

### v13.1 — 2026-08-28 — Death Machine buff, power hall spawn, lounge corner fix
*balance*

- Death Machine: +1 magazine and +5% damage on base and PaP forms. Damage 350 -> 368 (PaP 438 -> 460), min damage 295 -> 310 (PaP 369 -> 388), magazines 3 -> 4. No other gun changed.
- A zombie riser added deep in the power-switch hallway, behind the usual camping line (189 units clear of the switch), so camping the hall is no longer safe; the hall goes live as its own zone when the power door is bought.
- The breather lounges' roof no longer floats over a hole at the doorway corner: a corner pier fills it on all four lounges and doubles as the doorway jamb.
- Lounge polish: a glowing ceiling halo ring under each roof and a glow ring inlaid in the teleporter pad.

### v13 — 2026-08-28 — The breather lounges: roof, walls, colours, teleporter spur
*geometry*

- Breather floors 10/20/30/40 are now enclosed lounges: full walls with an open window band (bullets pass, players stay in) and a dark roof with a glowing trim ring.
- One colour per lounge: 10 blue, 20 green, 30 orange, 40 gold; room lights follow the theme.
- The teleporter moves off the lounge floor onto its own spur: gated doorway -> 320-long open-air gantry -> floating 288x288 pad.
- Wrong-buy fix: PaP and ammo crate triggers sat 38 units apart (both 5000). Furniture is now one per wall (station N, PaP W, crate E, perks S); closest pair 249 units.
- The breather PaP now verifies it can actually upgrade your gun before charging, and refunds the 5000 if the upgrade fails.

### (unversioned, rides v12.12) — 2026-08-27 — Perk prices retuned; altar shows each player their own price
*balance · build 15:19:04 -GscOnly*

- Perk prices: Electric Cherry 2000, Deadshot 1500, PhD 2000. Full table: Quick Revive 500 solo / 1500, Stamin-Up 2000, Jugg 2500, Speed Cola 3000, Double Tap 3000, Widow's Wine 4000. HUD perk cards match.
- Fixed a latent shipped bug: Jugg, Speed Cola, Quick Revive, Stamin-Up, Double Tap and Deadshot buy prompts had very likely shown a BLANK price since the map first shipped.
- The Heavenly Gift Altar now shows every player their OWN price, spent state and maxed state (with two players in range it used to fall back to a priceless generic prompt).
- Unverified in play as of this build (co-op altar: two players must each see their own number).

> **WORKSHOP UPLOAD #12 — Aug 27, 6:25 pm (Eastern) — v12.15** (exact). "v12.15 SHIP"; the deployed language fastfiles are stamped 6:15 pm that day.

### v12.15 SHIP — 2026-08-27 — Publish build with test flags off
*internal · publish=yes*

- All test arms removed (dev/god off, terrace warp harness deleted); full rebuild ships the day's work: stair and road ramps, the finale beat system minus the tide, plus the altar/perk/card/hound fixes.

### v12.15 — 2026-08-27 — The Derez Tide removed from the finale
*gameplay · build 17:59 (v12.14 curtain build, superseded)*

- Reverts v12.13's Derez Tide (the red front sweeping up the finale road): invisible it read as nothing ("Red wave?"), and with the full visible body (v12.14: three red riders + 88 derez eruptions) the verdict was "not a big fan". Fully deleted.
- Accepted consequence: the finale road's loiter exploit returns.
- Kept: the avenue lights — blue at the extraction buy, green strobe on the win, no red phase. Everything else from v12.13 stands (boss beats, phased pressure, the Arrival, heartbeat, weather, lane lottery).

### v12.13 — 2026-08-27 — The finale beat system: tide, boss beats, lane lottery
*gameplay*

- THE DEREZ TIDE: from 12 s into the finale song a front advances up the road, reaching the citadel exactly at the 90 s seal (94 u/s, 66% of Heavy's walk speed). Sustained 4 s deep inside it kills, with a rumble/chime warning. 11 avenue lights ignite blue at the buy and flip red as the front swallows each — they ARE the clock. (Removed the same day, v12.15.)
- Terrace respawners during the tide warp forward to the rearmost living teammate.
- Authored boss beats: spawn pressure ramps at 25 s and 60 s of the song; the Panzer drops on the Narrows at the first musical hit; two Protectors drop on the gate approach.
- The Arrival: the first survivor through the gold portal lights the hall front-to-back, pillar hosts count the party in, the seal slam quakes, and the hold-out opens with a Panzer drop.
- Crown heartbeat (red pulse, quickening per portal crossed) and a weather turn (fog to ember over 15 s at the buy).
- Lane lottery: at the buy one lane per fork is sealed and red-lit, so the memorised speedline dies.
- Test build with dev/god/terrace harness ARMED — not for publish.

### v12.12 — 2026-08-27 — Finale road stairs get the smooth ramps too
*geometry · build - (pending build)*

- All 9 stair spans on the finale road (ridge, broken stair, hollow climb, undercroft, plank) now carry the same invisible smooth-walk ramps as the tower stairs.
- Zombies, bullets and rails unchanged; 110 ramps map-wide verified.
- Pending build at time of writing.

### v12.11 — 2026-08-27 — Smooth stair ramps; rail ankle gaps closed
*geometry · build 14:02:40 full (bake BAKED 38.9 s)*

- Every tower flight (100) plus the crown stair now has an invisible sloped ramp over the treads, so players walk smoothly instead of on stepped collision ("It feels amazing now"). Zombies, bullets and grenades unchanged.
- About 800 see-through ankle-height slots under the stair rails are closed.

> **WORKSHOP UPLOAD #11 — Aug 27, 1:25 pm (Eastern) — v12.10** (probable). Opening Hand pass; v12.11 (stair ramps) was built at 2:02 pm, after this upload.

### v12.10 — 2026-08-27 — Opening hand floor, Scavenger capstone, green doors, spawn move
*balance*

- Your first upgrade deal after the class draft always contains at least a SUPER card (it was REGULAR+REGULAR 64% of the time).
- Scavenger ladder: Lv1 1 round per 5 kills, Lv2 1/4, Lv3 1/3, Lv4 1/2, Lv5 1/1, Lv6 (Assault only) 3 rounds per 2 kills. Class primary only — sidearm kills pay nothing.
- Starting spawn points moved to the west side of the base, 572 units from the nearest buy prompt (six of eight used to sit inside a door trigger during the draft).
- Buyable doors now glow green grid on every floor (they were red-on-red on 6 of 50 floors).
- Teleporter room deepened by 160 units so the arrival decal no longer overlaps the pads.
- Skirmisher: SPRINT and SPRINT FIRE now survive a class tier-up (SPRINT also for the slasher).
- Pause menu marks every upgrade a tier-up will reset (only 4 of 33 survive); cards 10% larger (234x351); 31 cards re-baked; Workshop text corrected to 33 domains.
- Reverted in the same pass: a brush-built extraction obelisk that swallowed the extraction buy.

> **WORKSHOP UPLOAD #10 — Aug 27, 3:26 am (Eastern) — v12.9** (approx). the Aug 26 balance pass (ammo, luck floors, Scavenger, Tireless out).

### v12.9 — 2026-08-26 — Balance pass: ammo, luck guarantees, knife money, Scavenger
*balance*

- +1 spare magazine on every gun, base and PaP (the ammo crate refills to the new max). The two shared T1 sidearms are not covered.
- Luck bar guarantees: a full bar (100) means at least one ULTIMATE card; 50+ means at least one SUPER. The lower-rarity card gets the promotion, so max-luck deals come up ULTIMATE+SUPER 70% of the time (was 52%).
- Melee kill money 130 -> 120.
- Scavenger needs one kill fewer per level (Lv1 7 -> 6 ... Lv5 3 -> 2, Assault Lv6 2 -> 1).
- TIRELESS (unlimited sprint at SPRINT Lv5) removed after three failed attempts; SPRINT is now +5% move speed per level only. Sprint cards re-baked.

> **WORKSHOP UPLOAD #9 — Aug 26, 3:20 pm (Eastern) — v12.8** (exact). language-fastfile fix built 3:14–3:16 pm; "reaches players only via a REPUBLISH".

### v12.8 — 2026-08-26 — Non-English players could not load the map
*fix · build 15:14-15:16*

- Players running the game in French, German, Italian, Spanish, Portuguese, Russian or Japanese failed at map load ("Could not find zone 'fr_zm_tower_of_doom'"); language files are now built for all of them.
- Still open: simplified/traditional Chinese clients cannot load until the right build token is found.
- The fix reaches players only with the next Workshop republish.

### v12.7 — 2026-08-26 — Late-game zombie speed growth nerfed
*balance*

- Per-round zombie sprint growth after round 15 reduced 0.35% -> 0.28%: round 30 1.0525x -> 1.042x, round 50 1.1225x -> 1.098x, round 100 1.2975x -> 1.238x. Rounds 1-15 unchanged. Full rebuild.

> **WORKSHOP UPLOAD #8 — Aug 26, 2:01 pm (Eastern) — v12.6** (exact). "ZOMBIE BLOOD RESTORED + FULL PUBLISH BUILD", .ff at 1:40 pm.

### v12.6 — 2026-08-26 — Zombie Blood restored; full publish build
*fix · publish=yes · build 1:40:30 PM full (.ff 99.27 MB)*

- Reverts v12.5: the Zombie Blood powerup is back, identical to its v12.3 debugged state.
- The neutral map vision file from v12.4 stays. The orange-tint verdict is inconclusive ("maybe its just my eyes"); next test is whether the tint fades as you climb (designed street-level smog) or persists at altitude.
- Publish-grade full build; credits list to verify on the Workshop page before upload.

### v12.5 — 2026-08-26 — Zombie Blood removed as a tint experiment
*fix*

- The Zombie Blood powerup is removed entirely from the game to test whether it causes the orange screen tint (expected temporary; restored in v12.6).

### v12.4 — 2026-08-26 — Permanent orange screen tint root-caused
*fix · build 12:47 PM -GscOnly*

- The Origins-style orange wash on screen from boot was the engine's fallback for a missing map vision file; a neutral one now ships. The tint predates Zombie Blood and was never caused by it.

### v12.3 — 2026-08-26 — Reviving no longer buys things; Zombie Blood fixes
*fix*

- Holding USE to revive a teammate no longer also buys the door, PaPs your gun, drains the ammo crate, starts the finale or fires the teleporter. Downed players can no longer buy doors. Teleporter refusals now make a sound. (A downed body in a doorway pins that door until revived — accepted.)
- Zombie Blood: grabbing it within 2 s of a revive no longer loses 13 of its 15 s of invisibility; its expiry no longer makes a freshly revived player instantly targetable; a stale guard no longer strips your last-stand protection rounds later.
- Finale spawn waves no longer steer toward a downed player.
- Co-op respawns no longer stack duplicate ammo-clip watchers.

### v12.2 — 2026-08-26 — Upgrade pause vs players going down
*fix*

- Teleporters, the ammo crate and the upgrade stations now play a refusal sound during the upgrade-event world pause (they refused silently before — the "teleporter wasn't activated" report).
- Going down with cards up: the card wait now ends on last stand (~0.75 s instead of up to 15.7 s unable to fire the crawl pistol); the upgrade is not forfeited.
- A downed player no longer gets jump back while crawling.
- A disconnect mid-pick no longer freezes the lobby for the full 20 s.
- Players excluded from an upgrade event (down or dead) no longer lose their luck bar.
- Bleed-out time spent during the world pause is credited back (the bleedout bar may read empty while you are still revivable — cosmetic).

### v12.1 — 2026-08-26 — Respawn UI loss fixed; Zombie Blood in the powerup tray
*fix*

- After spectating and respawning, the upgrade cards, luck bar, tower gauge, damage numbers and finale banner no longer vanish for the rest of the match.
- Zombie Blood now shows in the powerup tray with its 15 s countdown and expiring flash.

> **WORKSHOP UPLOAD #7 — Aug 26, 3:28 am (Eastern) — v11.5 / v12** (approx). the assault buff and the Vortex Bell + four-fears road are the early Aug 26 entries.

### v12 — 2026-08-26 — The Vortex Bell underside and the four-fears finale road
*geometry*

- The crown's underside is redesigned as a 10-tier bell with corona teeth, jewel collars, pearl beading and a hanging ruby girandole carrying a third red light; the crown bottom lowers 15008 -> 13696.
- Finale road: gate-run flanked by jewelled pylons -> fork (the Ridge +256 zigzag / the Broken Stair -256 hollow) -> the Narrows (120-wide choke) -> three-way (the Undercroft -384 cistern / the Plank +256 / the Weave 4 jogs) -> citadel. Walk ~8220 units.
- The crown hall's four pillars are restored as gold/ruby/gold cover.
- A fifth ammo crate on the crown hall's east wall.

### v11.5 — 2026-08-26 — Assault buff: Headshot, Giant Slayer, Recoil
*balance · build 20:22:51 full (2026-08-28 addendum fix, not this version)*

- HEADSHOT +3% -> +4% per level (max 10); GIANT SLAYER +3% -> +4% per level (max 5); RECOIL -8/-16% -> -10/-20%. Assault only.
- Net effect at max on a boss headshot: 2.65x -> 2.80x (+5.7% total damage).
- Maxed RECOIL is now a real 8% cut below the source gun (it was 0.966x, a partial refund); the Krig 6 stays 44% above its port.
- Nine cards re-baked with the new numbers; pause-menu text updated.
- Closed 2026-08-28: the UDM sidearm's opaque sight (missing reflex lens materials) fixed, never waived.

> **WORKSHOP UPLOAD #6 — Aug 26, 1:10 am (Eastern) — v11.2 – v11.4** (approx). crown detail pass, the perk identity bugs, the Gift of Death ring; all dated Aug 25.

### v11.4 — 2026-08-25 — Gift of Death's permanent ringing finally silenced
*fix · build - (-GscOnly, no clock)*

- The endless sleigh-bell rattle after a Gift of Death pickup wears off (reported around round 28, high in the tower) is fixed: the bells are now truly stopped instead of only muted.
- Picking up a second Gift of Death no longer stacks a new set of bells over the old one, which is what made the ring unkillable.
- The stop signal is now retried several times so it can't be lost on a bad frame.
- Replaces v10.9's ringing fix, which turned out to do nothing.

### v11.3 — 2026-08-25 — PhD used Stamin-Up's machine; Electric Cherry icon missing
*fix*

- PhD Flopper was wearing Stamin-Up's identity (same machine name and jingle), so the two machines collided; PhD now has its own identity and uses the retired Mule Kick's jingle and sting.
- The Electric Cherry HUD icon never appeared after buying the perk; it now shows (it takes over retired Mule Kick's HUD slot). PhD shows the PhD icon, and the two no longer share a row.
- A follow-up audit caught the first PhD fix making PhD unbuyable (the perk was stripped one second after purchase); corrected before shipping.
- The four crown beacons that light up per quarter of the finale song were spawning inside solid gold; they now sit visibly above the jewel.
- Dev-only: the test harness now opens doors the real way (slab, zone, breather unlocks).

### v11.2 — 2026-08-25 — Crown detail pass: ermine, jewels, panels, visible gate
*geometry · build - (LED bake 34.7 s, full geometry build)*

- The crown gains ermine spots on its white rim, gold courses that brighten toward the top, sunken panels on the south bays, a cut great ruby in four gold claws, banded shafts, dentils and plinths.
- The gate jambs at the crown's mouth were completely buried inside the front wall and did not exist visually; they now stand proud, and the mouth keystone / z-fighting faces are cleaned up.
- The 16 crown points were collapsing back into thin spires when seen from the base arena; they are widened so every head flares wider than its shaft.
- The last causeway portal now wears the crown's gold instead of cyan, so the colour change still marks the arrival.
- Four gold blocks were standing on the causeway's final landing (walkable deck, passing through the guard rail); fixed, with a generator check so it can't recur.
- Point stone colours were keyed side to side (ruby on one side, emerald on the other); now consistent.

> **WORKSHOP UPLOAD #5 — Aug 25, 12:30 pm (Eastern) — v11 / v11.1** (approx). the crown circlet and its 1.4x scale-up are the Aug 25 daytime entries.

### v11.1 — 2026-08-25 — The crown grows 1.4x: 6128 wide, 13,888 tall
*geometry · build - (full geometry build, LED BAKED)*

- The whole crown scales up uniformly by 1.4x: 4096 -> 6128 wide, 9920 -> 13,888 tall, filling 14.8 degrees of sky from the base arena (was 10.6; the old citadel was 4.0).
- The crown's south face stays where the road enters it; the crown grows north around the hall, and the hall floor, walls and pad do not move.
- Fixed a visible step in the monde sphere and a seam in the underside you look straight up at from the street.
- A one-time 126.2 s bake reading originally attributed to this change was never reproduced; the scale is a design choice, not a cost limit.

### v11 — 2026-08-25 — The citadel becomes a giant gold crown
*geometry · build - (full geometry build, LED BAKED 38.2 s)*

- The "castle with spikes" citadel is replaced by a 4096-wide gold circlet around the crown hall: a flared band with a white ermine rim, 16 alternating points (8 crosses, 8 fleurs-de-lis), a front cross carrying a 512-unit great ruby, two dipped arches, a monde, a cross finial and a red beacon star.
- The underside, which rendered as a black square in the fog, is now ten tiers of alternating gold and brass down to a glowing red core.
- The finale road now runs through a 640 x 424 mouth cut in the crown's rim, with jambs, corbels, a keystone and a stepped pediment.
- The four pipe-topped pillars inside the hall are gone; the finale's quarter-progress lights now ignite the crown's four corner points instead.
- Hall walls go from blue to purple velvet; a small 8-point crown sits on the tower's mast.
- The hall floor, gate, dais, extraction pad, crown door and upgrade station are unchanged.

> **WORKSHOP UPLOAD #4 — Aug 25, 1:38 am (Eastern) — v10.23** (approx). the armory fixes are the last entry dated Aug 24; the crown work begins the next entry.

### v10.23 — 2026-08-24 — Armory fixes: Magnum, penetration, backstab, bash lunge, ammo
*balance · build - (full build, .ff 96.13 MB)*

- Magnum body damage cut so headshots are 3x like every other gun: body 1,000 -> 417 (PaP 4,500 -> 1,750); headshot damage unchanged at 1,251 / 5,250.
- HK21 penetration large -> medium and MP7 small -> medium, so a tier promotion no longer loses penetration levels.
- Backstab is now 1.5x the blade's frontal damage on every blade (the PaP knife's 20,000 backstab is gone; the Stormbreaker had none); the top backstab is the PaP Stormbreaker's 20,400.
- Gun bash no longer lunges you forward on any bullet weapon.
- Zombie speed growth after round 15 raised 0.3% -> 0.35% per round (round 50: 1.105x -> 1.123x).
- The global +40% reserve ammo is removed (Stoner 7 -> 5 mags, MAC-10 15 -> 10, Enfield 10 -> 7); the breather ammo crates are the intended supply.
- LMG damage cut another 10% (Stoner T1 239 -> 215, HK21 502, Death Machine 350).

> **WORKSHOP UPLOAD #3 — Aug 24, 7:13 pm (Eastern) — v10.21** (exact). "PUBLISH BUILD" — user: "do a full rebuild, I'm gonna publish this version".

### v10.21 — 2026-08-24 — PUBLISH BUILD; the 7-hour crash was a DualSense controller
*internal · publish=yes · build - (full build)*

- Publishes the 2026-08-24 run: v10.14 balance pass, v10.15 Gift of Death and powerup durations, v10.16 playtest fixes, v10.17 FORCED MARCH art, v10.18-20 keyboard fix (MOUSE1/MOUSE2/V/R to switch, hold SPACE/F to lock); dev/god off, no debug text.
- Shipping knowingly: five cards (SUPPRESSING FIRE, KNIFE SPEED, LEECH, SPRINT, MOBILITY) still show old numbers, and the Electric Cherry buy-trigger bug is unconfirmed (self-heal active). The evening's launch crashes were a DualSense controller's phantom audio device, not the map.

### v10.20 — 2026-08-24 — Keyboard card picking finally works
*fix · publish=candidate · build - (-GscOnly)*

- Upgrade cards and the class draft now switch with MOUSE1 / MOUSE2 (or V / R) and lock with hold SPACE / F; controller uses RT / LT / melee / reload, with d-pad and hold-A/X unchanged.
- Root cause: every earlier keyboard fix (v10.3 A/D, v10.18 W/S, v10.19 bridge) read inputs a keyboard can never reach in a frozen menu; the "working" input was always the controller d-pad.
- v10.19's keyboard bridge menu is deleted; on-screen hints now say "SWITCH: [MOUSE1] [MOUSE2] or [V]  LOCK: HOLD [ SPACE / F ]" instead of promising WASD.
- Dev and god hardcoded off; publish candidate.

### v10.19 — 2026-08-24 — Keyboard bridge for card menus (superseded by v10.20)
*fix · build - (-GscOnly)*

- Adds an invisible menu that binds WASD, arrows, SPACE, ENTER and F while a card or draft choice is on screen; keyboard becomes press-to-lock.
- Also adds MOUSE1/MOUSE2 to switch and hold-F to lock on the server path.
- Deleted in v10.20: overlay menus never receive key presses, so this could not work.
- Dev and god ARMED for the user's retest — test build, not for publish.

### v10.18 — 2026-08-24 — WASD in the upgrade and draft menus; dev + god armed
*fix · build - (full build, GDT)*

- Upgrade panel: W/S flips to the other card alongside A/D; class draft: W/S cycles the four cards like A/D. Arrow keys work only if bound to movement.
- Menu hints updated to "SWITCH: WASD / ARROWS - LOCK: HOLD [ SPACE ]" (v10.20 later found these lanes cannot deliver keyboard input).
- First build to pack the FORCED MARCH card art.
- Dev and god ARMED for the user's retest — test build, not for publish.

### v10.17 — 2026-08-24 — FORCED MARCH card art; publish prep; crash was the game install
*art · publish=candidate · build - (crash-hunt rebuilds at 02:00 / 02:03 / 02:12 / 02:21 would not load; final full build has no clock)*

- FORCED MARCH upgrade card art installed: boot with amber chevrons, +5/+10/+15% MOVE SPEED, AK-47 only, 1/2/3 pips.
- Five cards still show old numbers pending re-bakes (SUPPRESSING FIRE 12/24/36, KNIFE SPEED -10/-16/-20, LEECH +4/+6/+8, SPRINT and MOBILITY +5/+10/+15).
- The overnight "map won't load" crashes were the game install dying before any map mounted; a redownload fixed it.
- Dev and god hardcoded off and the perk-scatter debug print re-gated for publish; the Electric Cherry self-heal ships active.

### v10.16 — 2026-08-24 — First playtest pass: menu size, headshots, Panzer, drops
*balance · build 01:54 full (.ff 95.00 MB, shared with v10.15)*

- Upgrade menu restored to its original size (reverts v10.3's 15% shrink).
- Assault headshots back to 3x (reverts v10.14's 4x).
- Panzer damage eased from a 50% cut to a 40% cut (x0.5 -> x0.6 of base); his electroball burst goes 36 -> 44 against 150 HP, still four bursts to kill.
- Pack-a-Punch and Death Machine drops halved (the mix changes, the total drop rate does not); the perk-bottle drop keeps its old rate.
- Locked teleporters now say "This teleporter is offline" instead of "LINK OFFLINE - open this floor's breather door".
- Electric Cherry "no buy trigger" report: a self-heal now re-aligns each perk's trigger to its machine every 5 s if it drifts; the root cause is still unknown.

### v10.15 — 2026-08-24 — Gift of Death slower with 80 rounds; Infinite Ammo and Time Warp shorter
*balance · build 01:54 full (shared with v10.16)*

- Gift of Death fire rate 250 -> 150 rpm (0.24 -> 0.40 s per shot), a 40% slower cycle; 0.40 is a judgement call, not a restored original.
- Gift of Death ammo 120 -> 80 (about 32 s of continuous fire, ~40 zombies).
- Infinite Ammo and Time Warp last 21 s instead of 30 s; Insta-Kill, Double Points and Fire Sale are untouched.

### v10.14 — 2026-08-24 — Balance pass: LMGs, HK21, Stormbreaker, FORCED MARCH, chain lunge out
*balance · build - (full build, .ff 95.00 MB)*

- LMG line -10% damage (Stoner 265 -> 239, HK21 558, Death Machine 389).
- HK21 belt 125 -> 94, which also drops carried ammo 750 -> 564.
- Stormbreaker -15% (6,800 / 13,600 PaP); one-hit reach round 29 -> 28.
- Assault class headshots 4x (every other class 3x) — reverted in v10.16.
- PENETRATION upgrade moves from the HK21 to the Death Machine; SUPPRESSING FIRE 25/40/55% -> 12/24/36%.
- New FORCED MARCH upgrade for the assault: AK-47 only, +5% move speed per level up to +15%.
- ADRENALINE and MOMENTUM swap between MP5 and MP7 (momentum is now MP5-only); the CHAIN LUNGE upgrade is removed from the game.
- Card art audit: five cards show outdated numbers (SUPPRESSING FIRE, KNIFE SPEED, LEECH, SPRINT, MOBILITY); seven pause-menu descriptions no longer wrongly say "class gun only".

### v10.9 — 2026-08-23 — Co-op ringing found; thin finale road; zombies spawn in front
*gameplay · build 21:44 full (.ff 94.46 MB)*

- The constant ringing after a Gift of Death was a co-op-only bug: the stop was only sent to the holder, so everyone else kept hearing the bells all match. The stop now reaches every player (v11.4 later found this still incomplete).
- The causeway is 160 wide instead of 576 — the same width as the tower's stairs — reversing v10's widening; rails stay.
- During the finale, zombies spawn in front of the leading player, in the direction they face.
- The Panzer spawns about 700 units ahead of the party during the run, standing between them and the crown.
- Navmesh rebuilt for the narrower road.

### v10.8 — 2026-08-23 — Pre-ship verification: stale build caught, co-op respawns were dead
*fix · build 20:58 full (.ff 94.37 MB; an earlier 20:37 link was stale)*

- A build declared ship-ready was missing the EXTRACTION prompt fix (the "game couldn't end because of an uplink issue" report), the Bulldog nerf removal and the solo Quick Revive price fix; rebuilt with all of them.
- v10.4's co-op breather respawn points never unlocked, so bled-out players were still sent to the base arena; they now unlock with each lap's door.
- Duplicate "+10" score popups after a lobby change or map restart fixed.
- The Panzer's flamethrower burn no longer goes out when you break line of sight, and Rogue Protectors no longer fire full effects for zero damage through cover.

### v10.7 — 2026-08-23 — Vendor PaP: the pistol could steal the purchase
*fix*

- The breather Pack-a-Punch vendor now always packs your class gun first; paying with the pistol out no longer buys a PaP'd pistol while the class gun stays plain.
- Once the class gun is packed, the vendor still packs the MR6.

### v10.6 — 2026-08-23 — Frame-rate death fix: two HUD timer leaks
*fix*

- Two HUD leaks behind the beta's "memory leak, 1 frame by 2nd stage" report fixed: every Max Ammo notification spawned an ever-growing cascade of timers, and every weapon swap (including grenade throws) leaked two more.
- Whether a separate height-linked frame drop remains is left open for post-fix reports.

### v10.5 — 2026-08-23 — Perk icons revert to the stock set
*art*

- Reverts v10.3's Ronan icon swap: perk HUD icons are the stock shaders again (Electric Cherry keeps its custom icon, since stock has none).
- Some DLC-perk icons may still render as white squares on a usermap; the fix path is supplying official icon art per machine.

### v10.4 (co-op audit session) — 2026-08-23 — Co-op respawns, honest finale, cheaper doors
*fix · build - (needs full build; pending peer coordination)*

- Bled-out co-op players respawn at the highest unlocked breather instead of the base arena (four new respawn groups; v10.8 found these inert until fixed).
- The finale can no longer be won by hiding: a living, upright player must be inside the citadel when the song ends; the ready prompt reads "REACH THE CROWN".
- Extraction price now scales with party size like the doors.
- Door ladder cut: base 1125 -> 750, +60/lap (was +100), cap 3000 (was 6000); total doors 186,975 -> 106,680; floor 10 15,750 -> 10,200, floor 40 123,000 -> 76,680.
- Downed and dead players are no longer dealt upgrade cards (they were holding the world paused).
- Holding jump when a card panel opens no longer auto-picks the left card; the class draft needs a release first.
- Door prompts only re-price when a player is within 512 units, avoiding the engine's prompt-string cap.

> **WORKSHOP UPLOAD #2 — Aug 23, 6:59 pm (Eastern) — v10.3 / v10.4** (probable). after v10.2 (4:18 pm) and before the 8:58 pm v10.8 rebuild; v10.4's co-op session is titled POST-SHIP.

### v10.4 (main session) — 2026-08-23 — Release audit: six majors fixed, zombie health goes live
*fix · build - (pending peer coordination)*

- The zombie health multiplier had been inert since it was written — now live: +25% solo, +15% per extra player. The game is harder than any build played so far.
- The breather PaP vendor refused sidearms after the class gun was packed; fixed.
- The finale boss cap is now enforced (up to 12 bosses were possible, starving zombie spawns).
- Reaver waves no longer stack unpaid debt (same fix as the v10.3 Protector backlog).
- Perk prompts showed wrong prices: Double Tap 3000, Deadshot 3500, Electric Cherry 3000 corrected.
- Teleporter pads on floors 30/40 moved off the power-door trigger and spawn points; gather radius 100 -> 120; up-riders land offset so they aren't bounced straight back.
- The uplink refuses to start during an upgrade-event pause.

### v10.3 — 2026-08-23 — Published-beta playtest: ten fixes
*fix · build - (full geometry build, bake 41.2 s)*

- Breather PaP vendor now packs sidearms via the stock path and refuses rather than eating points on a gun it can't upgrade; Enfield/knife PaP fixed via v10.2.
- Upgrade menu shrunk 15% (reverted v10.16); no perk limit — all 9 perks buyable.
- White-square perk icons replaced with the Ronan icon set (reverted v10.5); knife speed now works on the combat knife.
- Perk scatter every 4 rounds (5, 9, 13...) instead of the round after each Panzer, and machines no longer just swap slots on the same floor.
- ~30 Rogue Protectors on round 18 fixed: waves cap at 8 and a new wave replaces leftover debt instead of adding to it.
- Keyboard A/D card switching added (v10.20 later found it could not work).
- Teleporters: charge 2.2 -> 0.8 s, cooldown 60 -> 30 s, and now two-way — four UP pads at the base, each locked until that breather's door is bought ("LINK OFFLINE").
- The invisible knee-high barrier along the base arena's east side removed.

### v10.2 — 2026-08-23 — v10.1's PaP name fix was backwards and broke the knife
*fix · build 16:18 full (.ff 94.37 MB)*

- Reverts v10.1's weapon-name change, which broke Pack-a-Punch on the knife; blades PaP again.
- A self-repair pass now re-links any class gun whose PaP form failed to resolve, so the machine can't take points and hand back nothing.
- The Enfield's original PaP failure is still not root-caused; the repair pass covers it either way.
- The beta uploaded at 15:46 was built at 15:42 and contains the broken knife; a re-upload from this build is needed.

> **WORKSHOP UPLOAD #1 — Aug 23, 3:49 pm (Eastern) — v10.1** (exact). first post. v10.2: "the beta uploaded at 15:46 was built at 15:42 and CONTAINS the v10.1 bug".

### v10.1 — 2026-08-23 — Pack-a-Punch fix and co-op scaling for the beta
*fix · publish=candidate · build 15:42 full (.ff 94.37 MB; v10.2 records this build as the beta uploaded at 15:46)*

- Enfield and all three blades could not be Pack-a-Punched and KNIFE SPEED never affected a blade; fixed (v10.2 found the blade half inverted and reverted it).
- Horde health +15% per extra player on top of the 1.25 base (solo 1.25 / duo 1.40 / trio 1.55 / quad 1.70); bosses exempt (v10.4 found this inert until then).
- Zombie AI limit 24 solo, +2 per extra player, cap 30.
- Door prices scale with player count: x1.00 solo / x1.27 duo / x1.82 trio / x2.36 quad; prompts update when the party changes.

### v10 — 2026-08-23 — The finale becomes a long road run timed to the closing song
*gameplay*

- The ending is reworked: buy EXTRACTION at the top of the stair (the terrace), then run a 6400-unit open road to the citadel while the finale song ("You See Big Girl") plays. Survive to the last chord to win.
- Replaces the old ending (buy an uplink at the hall dais, hold out 90 s, then gather everyone on the extraction pad and hold USE). The extraction pad is now just a destination; holding USE on it does nothing.
- The finale road is 10x longer and 576 wide (was 224), with zombie spawn points on alternating flanks the whole way, so you get ambushed from all sides instead of only front and back.
- Run length is 191 s + a 6 s departure = the song's length; the win screen lands on the last chord.
- During the run, zombie spawning refills the instant a slot empties, and all three boss types cycle in under a combined cap of 4 — no enemy limit was raised.
- Upgrade card events are skipped for the whole run so nothing pauses the world out of sync with the song.
- Unverified in play as of this build.

### v9.47 — 2026-08-23 — New music track for floors 40 and up
*audio*

- A fourth music band: "Cyber Eclipse" (bykenneth) plays from floor 40 to the top.
- Music bands are now floors 1-19 ambient / 20-29 city / 30-39 relay / 40-50 eclipse; the floor 10 breather intentionally keeps the opening track.
- The new track was loudness-matched to the rest of the set (within ~1.3 dB).

### v9.46 — 2026-08-23 — Background music changes as you climb past the breathers
*audio*

- The background track now changes by floor: 1-19 "Password Infinity", 20-29 "Cyberpunk Futuristic City", 30-50 "Cyber Relay".
- The music mark only ever rises: walking back down never rewinds or restarts the track.
- Panzer music always overrides the band; when the Panzer dies the music resumes into whatever band the party has climbed into (it used to drop back to the opening track).
- The three tracks are loudness-matched so a band swap never sounds like a volume bug.

### v9.45 — 2026-08-23 — Assault upgrade pass: two new cards, several retunes
*balance*

- NEW card GIANT SLAYER (assault): +3% damage per level against bosses and elites only, 5 levels.
- NEW card BACK ARMOR (assault + heavy): -10% damage per level from hits landing in a 140-degree arc behind you, 3 levels; survives a tier promotion.
- RECOIL is now 2 levels at -8% / -16% (was 3 levels at -10/-20/-30%).
- IMPACT ROUNDS is now 10 levels at 3% each (was 3 levels at 10%); same 30% ceiling, slower climb.
- HEADSHOT nerfed to +3% per level (was +4%); the Rogue Protector lane is corrected to match.
- KILL RELOAD dropped from S tier to B tier, so it is offered about 5x as often.
- Zombies reach full sprint at round 15 (was round 12).
- Card art for all of the above landed in the same build (new GIANT SLAYER and BACK ARMOR cards, re-baked HEADSHOT / RECOIL / IMPACT ROUNDS cards).

### v9.44 — 2026-08-23 — SMG upgrade scopes reshuffled; door price step lowered
*balance*

- FIRE RATE is now MAC-10 only; HANDLING applies to every SMG (MAC-10, MP5, MP7); MAG SIZE no longer appears for the skirmisher at all (assault only).
- Door prices now rise 100 per lap (was 200): 1125 / 1225 / ... capped at 6000, roof 7500, power 750.

### v9.43 — 2026-08-23 — Kill Reload reworked into a rare full-magazine refill
*balance*

- KILL RELOAD now refills your magazine to full (from reserve) every 100th / 75th / 50th kill at Lv1 / 2 / 3, instead of a per-kill percentage. Replaces v9.41's reserve-fed per-kill refund.
- Reason: the per-kill version effectively deleted reloading (a 10/7/5-kill first cut still did); at 100/75/50 the magazine always drains over time.
- The kill counter resets when you take a TIER card.
- Still applies to all three assault guns. Card art and pause-menu text for this card are stale until re-baked.

### v9.42 — 2026-08-23 — Tier card chance doubled to 20%
*balance*

- Once your class gun is Pack-a-Punched, each card deal has a 20% chance (was 10%) to carry a TIER card.

### v9.41 — 2026-08-23 — Kill Reload stops minting ammo; doors +200 per lap
*balance*

- KILL RELOAD's per-kill refill (25/50/75% of the mag per level) now comes out of your reserve instead of creating ammo. Total ammo carried never changes; an empty reserve gives nothing.
- Door prices now rise 200 per lap (was 375): lap 1 1125, cap 6000 reached at lap 26. Total climb to the roof door 238,125 (was 265,875).

### v9.40 — 2026-08-23 — Melee lunge really removed; Quick Revive invisible wall fixed
*fix · build 12:47:05 full*

- The knife lunge-and-snap is finally gone on every blade (v9.32 zeroed the wrong field; the charge range was still 100).
- The invisible wall at the base north wall near Quick Revive is fixed: perk machines could be scattered before their collision existed, leaving the collision behind at the park spot. Machines now wait for their collision before moving.

### v9.44 — 2026-08-23 — Pause menu art: wider header and a proper empty pip
*art*

- New hollow "empty" pip art in the pause menu's upgrade list (unspent levels used to be a dimmed filled pip).
- The pause-menu header plate re-cut at twice the width so it no longer looks undersized in the two-column panel.
- New ASSAULT class card art (scoped rifle).
- Pause-menu KILL RELOAD rows updated to the frequency ladder (shown as every 10th / 7th / 5th kill at the time of this entry).

### v9.39 — 2026-08-23 — Pause menu now explains what each upgrade does
*gameplay*

- Every owned upgrade in the pause menu now shows two lines: what it does at YOUR current level, and how it activates.
- Numbers are level-aware (e.g. SCAVENGER Lv4 reads "1 reserve round back per 4 kills").
- Panel is now two columns of 7 rows; pips show your level filled and the cap dimmed so "am I maxed?" is visible at a glance.
- Fix: headshots on the Rogue Protector were paying +10% per HEADSHOT level instead of +4% since 2026-08-22.

### v9.38 — 2026-08-23 — Assault upgrades apply to every assault gun
*balance*

- RECOIL, MAG SIZE, IMPACT ROUNDS and KILL RELOAD now roll on all three assault guns (Enfield, Krig 6, AK-47) instead of one gun each.
- Trade: PENETRATION is heavy-only again; the AK-47 gave up its penetration ladder (its base penetration is unchanged from the roster default).

### v9.37 — 2026-08-23 — Breather teleporters; breather platforms doubled in size
*gameplay · build 12:10:40 PM full (superseded a 12:05:23 PM -GscOnly)*

- Breather platforms at floors 10/20/30/40 are now 544x576 (was 384x400), roughly twice the floor.
- Each breather has a one-way TELEPORTER back to the base arena: hold USE, 2.2 s charge, everyone standing on the pad warps.
- 60 s cooldown per pad; a recharging pad shows "Teleporter recharging..." and refuses the press.
- Downed or spectating players never ride; presses during an upgrade pause are ignored.
- User-verified in game.

### v9.37a — 2026-08-23 — Card art for Second Wind, Momentum and the Overdrive re-bake
*art · build 12:10:40 PM full*

- SECOND WIND and MOMENTUM now deal baked cards and show pause-menu plates instead of text rows.
- OVERDRIVE card re-drawn as a minigun with belt feed (it now belongs to the Death Machine); text reads "+12% PER 10 ROUNDS / SUSTAINED FIRE, 5 STACKS".

### v9.36 — 2026-08-23 — Damage upgrade applies to sidearms; +30% reserve ammo on every gun
*balance*

- The DAMAGE card now boosts your sidearm (and any non-class gun such as the Death Machine powerup). HEADSHOT, tier uniques, CLEAVE and THOR stay class-gun-only.
- Reserve ammo +30% on every class gun and sidearm, rounded to whole magazines (e.g. MP5 8 -> 10 mags, Stoner 5 -> 7, AMP63 7 -> 9, Magnum 12 -> 16).
- Not covered: the heavy's starter pistol keeps its stock reserve.

### v9.35 — 2026-08-23 — Echo Rounds and Meat Grinder removed; two new skirmisher cards
*balance · build 11:52:02 AM -GscOnly*

- ECHO ROUNDS (heavy, chance to hit twice) removed.
- MEAT GRINDER (heavy) removed; OVERDRIVE moves from the MP7 to the Death Machine (sustained-fire ramp capped at +60%, where Meat Grinder reached +100%).
- NEW card SECOND WIND (MP7 only): heal 1% of max HP per level per second while sprinting, 5 levels.
- NEW card MOMENTUM (skirmisher, any gun): up to +5% damage per level while moving at full run speed, 5 levels.
- These two new cards show as text cards until art lands.

### v9.34 — 2026-08-23 — The invisible wall beside the first flight is now visible
*fix*

- The full-height barrier sealing the east gutter beside the first flight was drawn in the neon-edge material and read as a faint glow line; it now uses the arena wall material so it is clearly a wall.

### v9.33 — 2026-08-23 — Melee damage ladder: the katana no longer one-hits the whole game
*balance · build 3:40:11 AM -GscOnly*

- Melee damage is now a clean x2 ladder: Combat Knife 2000 (PaP 4000), Wakizashi 4000 (8000), Stormbreaker 8000 (16000). Was knife 1700/20000, katana 20000/40000, stormbreaker 40000/80000.
- A Pack-a-Punched tier-1 knife used to hit as hard as the tier-2 katana and one-hit zombies to round ~38; now each tier buys ~7-8 more rounds of one-hitting and melee stops being a free win around round 36.

### v9.32 — 2026-08-23 — No melee lunge; Bulldog and starter pistol retuned
*balance · build 3:32:27 AM -GscOnly*

- Melee lunge range set to 0 on every blade (the knife had 100, the Wakizashi 70, Stormbreaker 0), so a tier promotion no longer changes your reach.
- Skirmisher Bulldog damage raised from x0.5 to x0.75 (90/pellet base, 180 PaP). Reverts half of v9.29's Bulldog nerf.
- Heavy starter pistol buffed 20% (x8.0 -> x9.6).

### v9.31 — 2026-08-23 — Fix: invisible wall where Quick Revive stood (solo)
*fix*

- In solo, after Quick Revive's third use flies the machine away, its collision stayed solid on the base north wall. The collision now goes non-solid when the machine leaves and solid again if it returns.

### v9.30 — 2026-08-23 — Sprint Armor card art installed
*art*

- SPRINT ARMOR now deals baked cards (-5/-10/-15% DAMAGE TAKEN, "WHILE SPRINTING - 5% PER LEVEL") and shows a baked pause-menu plate.

### v9.29a — 2026-08-23 — Fix: the map would not load
*fix · build 2:57:04 AM -GscOnly*

- The v9.29 build failed to load (the slasher's AMP63 Pack-a-Punch name was misspelled in the weapons table); one-row fix, map loads again.

### v9.29 — 2026-08-23 — Every class gets its own sidearm; zombie sprint ramp eased
*gameplay · build 2:48:39 AM -GscOnly (failed to load; fixed in v9.29a)*

- Per-class secondaries replace the shared starter pistol: SKIRMISHER AW Bulldog, ASSAULT CW Magnum, HEAVY starter pistol, SLASHER CW AMP63. Each has a base and a Pack-a-Punch form, no upgrade variants.
- The Bulldog is deliberately an emergency-only gun: x0.5 damage (60/pellet), point-blank only.
- Switching class at a base station now strips the previous class's sidearm.
- All three ported sidearms have full gun sounds.
- Zombies reach full sprint at round 12 (was 10).

### v9.28 — 2026-08-23 — New card: Sprint Armor
*gameplay*

- NEW card SPRINT ARMOR (skirmisher + slasher): -5% damage taken per level while sprinting, 5 levels; stacks multiplicatively with DMG REDUCTION and survives a tier promotion.
- Known gap: the Panzer's fire is not reduced by it.
- Shows as a text card until art lands (art arrived in v9.30).

### v9.27 — 2026-08-23 — Panzers no longer pile up; AR/LMG slower; bounty in score popup
*fix · build 1:39:55 AM -GscOnly*

- Fix: Panzers were never capped, so every 5th round stacked another one if the last was still alive. Now at most 1 Panzer alive and at most 1 owed; boss music only ends when the last one dies.
- ASSAULT move speed 0.9 -> 0.85, HEAVY 0.8 -> 0.75.
- The centre-screen score popup now includes the BOUNTY bonus (e.g. +110 instead of +100 on a headshot).
- Upgrade stations: 5 uses per player per terminal (was 3), price ladder 2000 + 500 per purchase (was +1000); buy #10 is 6,500 instead of 11,000.

### v9.26 — 2026-08-23 — Music stops at game over
*fix*

- The looping music (ambient, Panzer or finale track) no longer keeps playing under the game-over screen and the Restart Map / End Game menu.

### v9.25 — 2026-08-23 — Panzer electroball damage halved
*balance · build 1:02:06 AM -GscOnly*

- Panzer electroball damage 24 -> 12 per ball; he throws bursts of three that land together, so a burst is now 36 instead of 72 against 150 HP (was a two-burst death).

### v9.24 — 2026-08-23 — Game-over menu: Restart Map or End Game
*gameplay · build 12:39:35 AM -GscOnly*

- After a wipe (or the finale win) a menu opens with Restart Map and End Game instead of dumping you to the lobby after 15 s.
- No choice within 60 s exits to the lobby as before. In co-op the host sees this menu; other players get the normal pause list.
- Unverified in play as of this build.

### v9.23 — 2026-08-23 — Panzer 15k base health; his fire halved
*balance · build 12:39:35 AM -GscOnly (per v9.24)*

- Panzer health at round 5 solo is now 15k (was 25k): r10 23k / r20 55k / r30 129k / r40 306k. Co-op multipliers unchanged.
- Both of the Panzer's fire sources (flame cone and ground fire) now do half damage: a flame tag totals 54 (was 108, a guaranteed no-Jugg down), the ground pool 45 (was 90).

### v9.22 — 2026-08-23 — Ship state: dev and god mode off for the first real run
*internal*

- Dev and god flags disarmed: upgrade events every 4th round, Panzer at round 5 then every 5, Reaver every 4 rounds, 10% tier cards, 3 station uses, 90 s uplink hold-out, real economy, real downs. First build ever played in ship state.
- The Reaver has never been seen in a game in any mode. Unverified in play as of this build.

### v9.21 — 2026-08-22 — Enemy spawn banners removed
*gameplay*

- All on-screen "enemy incoming" banners (Panzer, Protectors, Reaver) are gone; enemies announce themselves only through sound, FX and the floor gauge's red boss pip.
- The class-draft and upgrade-event headers are kept; only enemy spawn captions were removed.
- Standing rule: no future elite gets a caption banner; tells are sound or FX.

### v9.20 — 2026-08-22 — New elite: the Reaver
*gameplay*

- New elite enemy, the Reaver (an Apothicon Fury): dormant until the floor-20 breather door is bought, then arrives every 4th round.
- Spawns 1 + players/2 at a time (solo 1, four players 3), at most 3 alive; HP sits between a Protector and a Panzer (solo ~20k at round 20, ~43k at 30, ~93k at 40).
- It teleports straight onto its target (400-750 units, every ~4.5-6 s) but cannot teleport through floors on the spiral.
- Arrives on a sky meteor visible from floors away; pays 400 points team-wide and +6 luck to the last hit.
- Immune to slows, stuns, splash and speed-curve effects like other bosses; shows as a boss pip on the floor gauge.
- Also fixed a hidden dependency the Panzer needed to keep working after a Mod Tools verify.
- Credit owed before publish: HarryBo21 (Apothicon Fury pack).
- Unverified in play as of this build.

### v9.19 — 2026-08-22 — Bosses spawn near players and drop in from above
*gameplay*

- The Panzer now spawns near the HIGHEST living player; Rogue Protectors near the LOWEST (replaces the base-ring spawn rule from 08-20).
- A stuck boss relocates by the same rule (Panzer back up to the highest player, Protector down to the lowest).
- Both bosses get a drop-in entrance: a 2 s ground tell, then the boss falls from up to 320 units above with a sky trail, landing with a quake, landing FX and a kill splash.
- Panzer music now starts at the ground tell so the first hit lands with the slam.
- Known cosmetic limit: the falling boss uses its idle pose, not a flying animation.

### v9.18 — 2026-08-22 — Class gun no longer confiscated; mystery box removed
*fix · build 22:15:42 FULL*

- Fixed players randomly losing their class gun and being left with only the pistol (the "teddy bear" laugh): the stock too-many-weapons anti-cheat was firing during legitimate upgrade swaps. It is now permanently disabled.
- New watchdog: if the class gun ever goes missing for 3 s, it is re-given at the correct upgrade/PaP form.
- The mystery box has been removed from the map entirely (it could also delete the class gun on a pull).

### v9.17 — 2026-08-22 — Load fix for v9.16; breather Pack-a-Punch reworked
*fix · build 16:13:11 FULL*

- Fixed the map not loading in v9.16 (a second stock Pack-a-Punch prefab fatals the load). Reverts v9.16's four prefab machines.
- Pack-a-Punch on floors 10/20/30/40 is now a script-driven vendor: 5000 points, needs power, works on the class gun (swaps to the PaP form within about 1 s).
- The breather PaP sits on the north edge of each balcony, facing into the floor; it is not solid so the horde cannot grind on it.

### v9.16 — 2026-08-22 — Pack-a-Punch on every breather balcony
*gameplay · build 15:54:07 FULL*

- Fixed the CLASS TIER card being unreachable: the only Pack-a-Punch was in the crown hall, and the tier card requires a PaP'd class gun.
- Added a Pack-a-Punch to each breather balcony (floors 10/20/30/40), power-gated like any PaP. (Superseded by v9.17 — this build did not load.)
- Note: the TIER card is opt-in; a maxed player must HOLD select to take it, a timeout applies nothing.

### v9.15 — 2026-08-22 — Tireless sprint finally works
*fix*

- Skirmisher SPRINT Lv5 (tireless) now actually gives near-unlimited sprint (999 s meter, recharges); earlier fixes set a value the client never read.
- The effect is re-applied on every respawn and removed the moment eligibility is lost (class switch, tier promotion), without stripping a bought Stamin-Up.

### v9.14 — 2026-08-22 — Tier guns rebalanced; roof Pack-a-Punch fixed; tier art live
*balance · build 14:23:20 -GscOnly*

- Tier promotions are damage-only: each tier gun matches the DPS of the previous tier's PaP form (replaces v9.13's rule, which made every promotion a DPS downgrade). Damage now MP5 284, MP7 405, Krig 313, AK-47 391, HK21 618, Death Machine 431; clips unchanged.
- The roof Pack-a-Punch machine now works on class guns (previously only the pistol could be packed).
- MAG SIZE now offered to the Skirmisher (MP7) and PENETRATION to the Assault (AK-47).
- SUPPRESSING FIRE no longer pops Widow's Wine cocoons back to full speed; DRAW CUT now procs reliably within 0.4 s of a sprint.
- Sound fixes: Enfield/HK21 PaP tails, Combat Knife swing whoosh (silent since 08-20), Stormbreaker swing whoosh.
- Art installed: 8 tier cards, 21 unique-upgrade cards, pause plates, MAC-10/Enfield class cards.

### v9.13 — 2026-08-22 — All 8 tier guns and 7 unique upgrades are live
*gameplay · build 13:42:33 -GscOnly (per-gun builds 13:22-13:38)*

- Class ladders are real: Skirmisher MAC-10 > MP5 > MP7; Assault Enfield > Krig 6 > AK-47; Heavy Stoner 63 > HK21 > Death Machine; Slasher Combat Knife > Wakizashi > Stormbreaker (arrives with Thor's Thunder Lv1). The draft now hands out the MAC-10 / Enfield.
- Tier stats: MP5 227 dmg/35 clip, Krig 250/33 (clip nerf retired), MP7 259, HK21 495 @ 536 rpm/125 rd, AK-47 250/36, Death Machine 276 @ 1200 rpm/150 rd, Wakizashi 20000/40000, Stormbreaker 40000/80000. PaP = +25% everywhere.
- Seven per-gun unique upgrades: ADRENALINE (MP5: kills stack a 4 s +4/6/8% speed burst x3), OVERDRIVE (MP7: +5/8/12% per 10 consecutive rounds), KILL RELOAD (Krig: kills refill 25/50/75% of the mag), IMPACT ROUNDS (AK-47: 10/20/30% of hits burst to nearby zombies), SUPPRESSING FIRE (HK21: hits slow 25/40/55% for 1.5 s), MEAT GRINDER (Death Machine: +2/3/4% per 5 rounds up to +50/75/100%), DRAW CUT (Wakizashi: +50/100/150% on a swing within 0.4 s of a sprint).
- Chain lunge's landing hit now deals the held blade's damage.
- Death Machine (class gun) got loop-fire sounds; Wakizashi port installed with its own sounds.
- Card art for the tier and unique upgrades still on the text fallback this build (landed in v9.14).

### v9.12 — 2026-08-22 — Class tier card is live (system only, same guns)
*gameplay · build 12:16:22 -GscOnly (Phase 0 11:46:44)*

- Roster locked: Skirmisher MAC-10 > MP5 > MP7; Assault Enfield > Krig 6 > AK-47; Heavy Stoner 63 > HK21 > Death Machine; Slasher Combat Knife > katana > Stormbreaker.
- The CLASS TIER card now deals: 10% of card deals (once the class gun is PaP'd) offer a promotion in the right slot; it is opt-in and never taken on a timeout, and a refused tier pick falls back to the other card.
- Taking a promotion resets every gun-bound upgrade to 0, keeps DMG REDUCTION and LUCK, clears PaP, swaps to the next gun at level 0 with full ammo, and grants that gun's unique upgrade at Lv1.
- Thor's Thunder leaves the knife's pool: it is Stormbreaker-only from here.
- This build runs a null ladder: every tier is still today's T1 gun, so the card flow could be proven with zero new guns.
- Enfield and HK21 ports installed for the coming builds.

### v9.11 — 2026-08-22 — Class tiers design document
*internal*

- Design only, no code: class tiers spec (10% tier card once PaP'd, three tiers per class, gun-bound uniques, ids 24-32 reserved).

### v9.10 — 2026-08-22 — Scavenger is a kill counter; louder clink; boss track intro trimmed
*balance*

- SCAVENGER now refunds 1 round every N kills, never more than one round per shot: Lv1 every 7 kills, Lv2 6, Lv3 5, Lv4 4, Lv5 3, Lv6 2 (Assault only reaches Lv6). Replaces the fractional bank that could hand back 4 rounds on one penetrating shot.
- The Scavenger clink is much louder (alias volume 62 to 92) and can fire every 0.6 s instead of 1.1 s.
- The Panzer track "Data Spike" now starts at its first hit (4.5 s of quiet intro cut), so the boss no longer walks around in near silence.

### v9.9 — 2026-08-22 — Thor's Thunder cooldown x2.5, victim cap; chain lunge rewritten
*balance*

- Thor's Thunder procs 2.5x less often: cooldown 3750 / 3125 / 2500 / 1875 / 1250 ms by level (was 1500 down to 500). Infinite Ammo still removes the gate.
- Thor now shocks only the nearest 2 / 3 / 4 / 5 / 6 zombies by level instead of everything in radius.
- CHAIN LUNGE rewritten after "doesn't work": fire OR melee triggers it (the knife is the primary), the dash is a real homing hop (120-unit pop, re-aimed every 50 ms), you stop on the zombie and the hit counts as a real knife hit (CLEAVE/THOR/LEECH/BOUNTY fire). Same-flight targets only; a whoosh plays as the tell.
- Panzer HP now 25k at round 5, x1.09 per round (was 24k, x1.075).

### v9.8 — 2026-08-22 — Scavenger card art complete
*art · build 01:25:25 -GscOnly*

- Scavenger upgrade cards and pause plate re-baked with the new name ("SCAVENGER / AMMO BACK ON KILLS"); all 23 upgrade domains now have final card art.

### v9.6 — 2026-08-22 — Chain Lunge card art
*art · build 00:29:39 -GscOnly (Run and Gun art 00:34:34)*

- CHAIN LUNGE cards and pause plate now render real art instead of the text fallback.
- RUN AND GUN art landed right after in a follow-up build; the card set is complete for all 23 domains, except the Scavenger card still reads "RESERVE" until v9.8.

### v9.5 — 2026-08-22 — Reserve renamed Scavenger; card art drop
*art · build 00:25:07 -GscOnly*

- The RESERVE upgrade is renamed SCAVENGER (it refunds ammo on kills, it never raised capacity); description now "kills refund ammo: +1 per 4 kills / Lv". Card art still reads RESERVE until re-baked.
- CLEAVE and BULLET FEED cards re-baked with the current numbers ("33% chance per level", "2.0s to 0.4s per round").
- SPRINT FIRE now has real card art and a pause plate.
- CHAIN LUNGE and RUN AND GUN still on the text fallback.

### v9.4 — 2026-08-22 — Run and Gun: the Skirmisher's ammo saver
*gameplay*

- New Skirmisher upgrade RUN AND GUN (3 levels): every class-gun shot fired while running has a 20 / 35 / 50% chance to cost no ammo. Standing still or ADS-creeping pays full price; the pistol and wonder weapon always pay.
- Card art landed the same day in a second build.

### v9.3 — 2026-08-22 — Reserve opened to all gun classes; Headshot nerfed
*balance · build 00:11:25 (rode in session 8e's build)*

- RESERVE (ammo back on kills) is now available to Skirmisher, Assault and Heavy at max Lv5, with Assault able to reach Lv6. Slasher excluded.
- HEADSHOT nerfed from +10% to +4% per level (Lv10 = +40%, on top of the flat 3x base).
- SPRINT FIRE now shows in the pause-menu upgrade list.

### v9.2 — 2026-08-22 — Chain Lunge: new Slasher upgrade
*gameplay*

- New Slasher upgrade CHAIN LUNGE (5 levels): a knife kill opens a 1.5 s (+0.25 s/Lv) window; press melee with a zombie in front within 220 units (+60/Lv) to launch onto it and land a full knife hit. Chains while targets remain.
- Bosses, frozen zombies and non-zombies are never targets; no lunge while downed or during a pause.
- Card art pending (text fallback).

### v9.1 — 2026-08-22 — Headshot 3x for every gun; PaP +25%; Sprint Fire SMG-only
*balance · build 23:59:17 -GscOnly*

- Every gun now has the same 3x head/helmet/neck multiplier (standing rule: no gun varies unless asked). Previously Krig 6x, Stoner 5x, knife 1.4x, and the MP5's PaP form had a secret 2x chest zone. Krig base headshot drops 1170 to 585.
- Pack-a-Punch is now +25% across the board (replaces v8.9's +15%): damage and clip x1.25, +25% rpm, reload/ADS/recoil x0.75. Knife melee damage stays 20000.
- SPRINT FIRE is Skirmisher-only again (was all three gun classes for one build).
- Held: the separate reserve-capacity upgrade (would blow the engine's weapon-variant ceiling).

### v9.0 — 2026-08-21 — Sprint Fire is an earned upgrade
*gameplay · build 23:53:02 -GscOnly*

- Firing while sprinting is no longer a Skirmisher innate; it is a new binary upgrade card SPRINT FIRE (max 1) for Skirmisher/Assault/Heavy.
- Fixed a card-art bug where an upgrade with no art showed the PREVIOUS card's picture; such cards now render as text.
- Skirmisher class-select card now reads "fastest fire rate + speed".

### v8.9 — 2026-08-21 — PaP +15%, upgrade rarity tiers, Cleave nerf, Bullet Feed buff
*balance · build 23:41:35 -GscOnly*

- Pack-a-Punch is now a uniform +15% on every stat (damage/clip x1.15, +15% rpm, reload/ADS/recoil x0.85). PaP damage DROPPED versus the ports' ~1.7x: MP5 280 to 184, Krig 330 to 224, Stoner 345 to 305. Knife stays 20000.
- Upgrades now have S/A/B rarity: S cards are offered 1/5 as often and roll SUPER/ULTIMATE half as much; a stacked S+ULTIMATE is 2.5% at empty luck, 7.5% on a full bar. S = DAMAGE, DMG REDUCTION, LUCK, ECHO ROUNDS, THOR'S THUNDER, CLEAVE.
- CLEAVE is a chance ladder: +33% per level, every 3 levels one guaranteed extra target, max Lv6 = always +2 (3 zombies per swing).
- BULLET FEED buffed: 2.0 s per round at Lv1, linear to 0.4 s at Lv10.
- Diagnosed (no change): the Krig hits harder than the MP5 because of its 6x headshot multiplier.

### v8.8 — 2026-08-21 — Thor's Thunder Lv1 toned down, real cooldown gap
*balance · build 18:53:40 -GscOnly*

- Thor's Thunder Lv1 is now a small local zap: sky bolt and flash from Lv2, storm cloud from Lv3. Radius 80 at Lv1 (160 Lv3, 240 Lv5); damage 20% of max HP at Lv1 (50% Lv3, 80% Lv5).
- Cooldown lengthened so the gap is felt: 1500 ms at Lv1, 1000 at Lv3, 500 at Lv5.

### v8.7 — 2026-08-21 — First-door stuck zombies fixed; Krig recoil up
*fix · build 17:48:54 FULL*

- Zombies no longer pile up at a wall near the first stair door on floor 0: a boxed-in spawn point was moved onto the open walkway.
- Krig 6 recoil stacked another +25% (about 1.8x stock kick in total).
- Build note: a two-linker collision produced a discarded .ff; the 17:48:54 rebuild is the clean one.

### v8.6 — 2026-08-21 — Thor cooldown ramp, Zombie Blood pulled, Thor pause plate
*balance · build 12:51:02 -GscOnly*

- Thor's Thunder cooldown scales with level: 900 ms at Lv1 down to 300 ms at Lv5; INFINITE AMMO removes the cooldown for the melee class. Splash is 27% to 75% of nearby zombies' max HP, radius 90-210.
- ZOMBIE BLOOD drop disabled: under endless rounds it ballooned the horde and slowed the whole game.
- Thor's Thunder now shows in the pause-menu upgrade list.
- Maxed upgrades are no longer offered on cards or at the station.

### v8.5 — 2026-08-21 — Reserve and recoil nerfs, Time Warp scope, power switch moved
*balance*

- RESERVE cut 75%: Lv1 = 1 round per 4 kills, Lv4 = 1 per kill. Cards re-baked.
- Krig 6 recoil raised (+25% on top of the roster bump); RECOIL upgrade halved to -10 / -20 / -30%.
- TIME WARP now slows only regular zombies, never the Panzer/Protectors or the player (it was stuttering the bosses).
- Power switch pulled off the wall by 17 units so it no longer clips into it.
- Skirmisher can fire while sprinting (class innate this build; became an upgrade in v9.0).
- Also carried a boot-error fix for the class-gun inventory check.

### v8.4 — 2026-08-21 — Boot fix, Thor's Thunder art, Zombie Blood
*fix · build 12:24 FULL*

- Fixed the black screen on load (a powerup script error thrown every frame).
- Thor's Thunder now has card art and a pause plate; Zombie Blood has a tray icon.
- Fixed Thor's Thunder damage call and duplicate weapon-variant rows.
- RESERVE nerfed to 0.25 rounds per kill per level; RECOIL ladder now -10/-20/-30%.
- Build guards hardened so a poisoned .ff can no longer report OK.

### v9.1 — 2026-08-21 — Station use cap, door luck up, real HP readout
*gameplay · build 12:24 (rode in v8.4's build)*

- Each personal upgrade terminal can be used only 3 times per player; after that "TERMINAL DEPLETED - climb to the next one". Price ladder unchanged. Dev mode: no cap.
- Buying a door now gives +8.75 luck to the buyer (was 5).
- The HUD health number now shows the real max (150, Jugg 250) instead of a hardcoded 100.

### v8.3 — 2026-08-21 — Free Pack-a-Punch drop, Zombie Blood, Thor's Thunder, gun-swap fix
*gameplay*

- The free Pack-a-Punch drop is back on a real pickup model (power-gated, grabber only) and now packs the class gun properly.
- New ZOMBIE BLOOD drop: 30 s of invisibility and invulnerability for the grabber; re-grab restarts it; going down ends it.
- New Slasher upgrade THOR'S THUNDER (5 levels): every melee hit calls lightning on the victim, splashing 15% (+12%/Lv) of nearby zombies' max HP in a 90 (+30/Lv) radius. Bosses exempt. Art pending.
- Fixed upgrades switching you to the pistol and stashing your gun: the swap now verifies the weapon switch before taking the old form.

### v9 — 2026-08-21 — The Crown: the top of the map and the ending
*geometry*

- Fixed the roof being unreachable after the tower went to 50 floors (the final landing and roof door were never built for an even top lap).
- Above the spiral: a gold CROWN STAIR, a TERRACE, a 640-long CAUSEWAY over 19,000 units of air with three cyan portals, and the CROWN HALL, a floating open-top citadel with corner towers, a mast and a red beacon.
- The ending is buyable: activate the UPLINK for 25,000 (needs power), hold out 90 s while rounds keep coming (four pylons ignite as progress), then every living player holds USE on the extraction pad for "YOU ESCAPED THE TOWER".
- Guard rails now carry invisible caps: you can hop onto a rail but not climb over or off the map.
- The crown hall holds Pack-a-Punch, Mule Kick, an upgrade terminal and the extraction pad.

### v8.2 — 2026-08-21 — Breather station placement and the "Hint text here" prompt
*fix*

- Fixed upgrade stations showing the literal placeholder "Hint text here"; prompts now show the real text.
- Breather upgrade terminals moved to the west wall facing east with the trigger in front, so you no longer squeeze between it and the perk machines.
- Station prompt reworded to "for an Upgrade Card".
- The free Pack-a-Punch drop stays retired until a pickup model is sourced (returned in v8.3).

### v8 — 2026-08-21 — Tower doubles to 50 floors, enemies unlock as you climb
*gameplay*

- The tower is now 50 floors (was 25), with 52 buyable doors.
- Tower gauge: one lit cell now equals 2 floors; the "your floor" marker is gone, the top of the lit trail reads as your altitude.
- Breather balconies moved to floors 10/20/30/40, each with its own personal upgrade station (price ladder stays per player, so extra stations are closer, not cheaper).
- Rogue Protectors do not exist until the floor-10 breather door is bought; their every-3-rounds cadence starts from that round.
- Fixed: the Panzer could spawn on the first stairs behind an unopened door; bosses now only spawn inside opened zones.
- SPRINT/MOBILITY upgrade buffed 3% to 5% per level (maxed skirmisher 1.50x, was 1.30x).
- Stoner 63 magazines -20%: 75 to 60 base, 110 to 88 PaP'd.
- Free-PaP drop only enters the rotation once power is on; draft text now says MP5 / Stoner 63 (class card art still shows the old guns).

### v7.0 — 2026-08-20 — New skirmisher and heavy guns, stats reset to stock
*balance*

- Skirmisher now uses the MP5 (was AK-74u); Heavy now uses the Stoner 63 (was M60).
- All class guns reset to their stock damage and recoil; the v6 per-gun multipliers (M60 x0.85 / AK-74u x1.1 / Krig x1.05) and v6.10's 25% Krig recoil cut are reverted. Starter pistol keeps x8.
- Class move speeds survive the swap: heavy 0.8 / assault 0.9 / skirmisher 1.0 / slasher 1.1.
- New tower gauge HUD: one lit cell per climbed floor, amber breather cells, a lit roof crown, your-floor marker and a red pip on the lowest live boss.
- Pause-menu upgrade list is now baked art plates with pips; MAG SIZE cards corrected to +30/+60/+90%.
- Both new guns have full sound sets.

### v6.10 — 2026-08-20 — Unlimited-ammo bug, Krig mags, station no longer freezes you
*fix*

- Fixed "unlimited ammo": RESERVE refunded +2 rounds per level per kill (now +1/Lv), and MAG SIZE was also inflating the reserve pool (now clip only).
- Krig 6 MAG SIZE ladder is now 30/60/90/120 (was 30/45/60/75).
- Krig 6 base recoil cut 25% at every level.
- The personal upgrade station no longer freezes you: full movement and weapons while choosing, 15s auto-lock, hold-jump still locks a card.

### v6.9 — 2026-08-20 — Quick Revive at the base, real breathers, pause-menu art
*gameplay*

- Quick Revive is now pinned at the base (it was on the floor-5 breather, 9,375 points of doors away, so solo had no self-revive). Other perks still scatter across breathers; one breather pad stays empty each run.
- Breather balconies now spawn ZERO zombies of their own; the horde has to climb to you.
- Pause-menu upgrade panel is now baked art (header, 18 domain plates, level pips).
- Electric Cherry has a proper icon (replaces the placeholder); the perk-row icon still cannot light up for it.

### v6.8 — 2026-08-20 — Personal upgrade station, 150 HP, slasher tuning
*gameplay*

- New personal upgrade station at the base: buy a solo upgrade pick for 2000 +1000 per purchase (per player). The world does NOT pause while you choose (15s timer); a scheduled upgrade round overrides your pick and the same cards come back after.
- Base health is now 150 (restores to 150, not 100, when Juggernog is lost).
- Slasher: DMG REDUCTION 4% to 5%/Lv, BOUNTY 3% to 5%/Lv, cleave radius 120 to 60, KNIFE SPEED now 5 levels at -10% each. Three card arts are stale.
- Luck odds nerfed: the bar now multiplies SUPER/ULTIMATE chances (x2 at 50%, x3 at 100%); a full bar is 40/45/15 (was 20/50/30).
- Station fixes: a paid pick can never be erased by a round event; downed during confirm still locks the card; station faces the right way; co-op hint shows no price when players owe different prices.

### v6.7 — 2026-08-20 — Floating text removed, luck nerf, perks only on breathers
*balance*

- All floating "+8 luck" style on-screen text removed (14 notices).
- Luck nerfed: per-round kill budget 40 to 18, door buy 8 to 5.
- Rogue Protector nerfed: run rate 1.0 to 0.85, bullet damage 21 to 15 (cap 45 to 32).
- Perks now live ONLY on the 4 breather balconies (8 pads for 8 machines); Quick Revive pinned to the floor-5 breather. Mule Kick + PaP stay on the roof.
- Door prices x1.5: 1125 +375 per floor, cap 6000; roof 7500; power room 750.

### v6.6 — 2026-08-20 — Protectors shoot bullets only, ammo feed fix
*balance*

- Rogue Protector now bullets only: zap pulse and rocket retired, all knockback gone, fires every 3.6s (was 3.0s).
- BULLET FEED reworked: feeds every second, 1 round/s at Lv1 up to 4/s at Lv10 (was ~1 round per 5.5s).
- Switch-hint plate and countdown redrawn at the correct aspect below the powerup tray.

### v6.5 — 2026-08-20 — Full HUD family in baked art, Panzer drops Max Ammo
*art*

- 32 new HUD images: event/draft banners, PANZER and ROGUE PROTECTORS slide-in banners, 10 luck badges, 5 controller/keyboard input-hint plates, 10 custom powerup tray icons (Death Machine slot renamed Gift of Death).
- MAG SIZE cards regenerated with "+50/100/150% REAL MAG".
- Fixed: the boss banner was invisible at round start.
- The Panzer always drops a Max Ammo at his corpse.
- Luck bar "%" text and the card "Lv X > Y" overlay are removed; perk row uses the stock BO3 perk icons (Cherry keeps the kit icon).

### v6.4 — 2026-08-20 — 58 fully baked upgrade and class cards
*art*

- 54 upgrade cards (18 domains x 3 rarities) + 4 class cards are now full portrait art with all text baked in, in both the upgrade and class-draft menus.
- Menus re-laid out in portrait; live overlays (level line, hold bar, focus accent, countdown) stay.
- Known: the 3 MAG SIZE cards still show stale "+40% bottomless" text.

### v6.3 — 2026-08-20 — Power hallway 5x longer, real mag twins, bigger damage numbers
*gameplay*

- The power-room corridor is ~5x longer, running outside the base's east wall; same 500-point door, switch at the far end.
- MAG SIZE is now a real bigger magazine on the Krig 6 (x1.5/2.0/2.5 clip), 3 levels, assault only; the virtual "bottomless" pool and the MAG +N chip are gone.
- Crosshair damage numbers now cap at 20,470 (rounded to 10s) so tripled headshots read correctly.
- Also since v6 (unlogged v6.2): insta-kill is a team-wide 3x damage window (bosses exempt), bosses spawn from the bottom with an anti-strand watchdog and no through-floor sniping, Panzer damage halved, Protector knockback removed, pistol x8, Protector waves = round(players/3 x round), class-switch stations REMOVED, Xmas Gun on the Death Machine drop, BOCW combat knife replaces the ballistic knife.

### v6 — 2026-08-20 — Two flights per floor, perks everywhere, pause-only upgrade list
*geometry*

- Each floor is now 2 flights of stairs (was 4), alternating sides; top at z=9600. Roof arrival at the NW corner.
- All wallbuys removed.
- Breathers (floors 5/10/15/20) are larger, on the mid landing.
- Perk scatter pads: 2 at the base (Quick Revive fixed west), every floor's mid landing, the 4 breathers (always filled first) and the roof. Double Tap (3000) and Deadshot (3500) join the roster (8 machines).
- Luck bar is now drawn in the HUD frame art with a "n%" readout (gold at 80%+).
- The owned-upgrades list shows only in the pause menu ("YOUR UPGRADES"), no longer on the HUD.

### v5.3 — 2026-08-20 — Tron Grid look and the luck-bar frame
*art*

- Grey concrete is gone: navy grid base floor with a glowing blue inlay ring, glowing-seam landing tiles cycling blue/green/orange/red/yellow per floor, Pack-a-Punch themed roof floor.
- Luck bar now sits inside a proper frame image (top-left) with the "LUCK" label baked in; text is just "n%".

### v5.2 — 2026-08-20 — Class speeds, softer zombie curve, gun balance
*balance*

- Class move speeds: heavy 0.8 / assault 0.9 / skirmisher 1.0 / slasher 1.1 (was 0.65/0.80/0.95/1.05).
- Zombies reach full sprint at round 10 (was 7); 0.8 floor and +0.3%/round after unchanged.
- Spawn trickle eased to 0.8x stock (floor 0.3s, was 0.5x / 0.15s); round-1 delay 1.0 to 1.6s.
- Gun balance: pistol x4.0, M60 x0.85, AK-74u x1.1, Krig x1.05; roughly pistol 100 / AK 198 / Krig 205 / M60 246 damage.

### v5.1 — 2026-08-20 — Playtest round 2 fixes
*fix*

- Music louder: ambient 68 to 85, boss 85 to 100.
- Boss stuns removed: the Protector zap no longer slows, the Panzer electroball no longer zaps. Both bosses back to base speed (Panzer 1.10 to 1.0, Protector 0.85 to 1.0).
- Holding jump to lock a card no longer makes you hop.
- Menu prompts now say "HOLD [ A ]" or "HOLD [ SPACE ]" depending on your input device.
- Fixed: using the slasher class station also bought the first door (triggers overlapped); stations moved west.
- Owned-upgrades column on the left edge (dim in play, readable over the pause menu); luck bar moved to the top-left.

### v5 — 2026-08-20 — The luck bar, perk scatter, damage reduction
*gameplay*

- New LUCK BAR (0-100% per player): kills earn a fair share per round (~+40% for clearing your share at any round), headshot kills x1.5, LAST HIT on a zombie/Protector (+4)/Panzer (+20) takes the luck, revive +15, door buy +8, going down -25. At upgrade time the bar scales card odds from 80/15/5 (0%) to 20/50/30 (100%) then fully resets.
- LUCK domain is now +10% luck gain rate per level.
- PERK SCATTER: 6 perks (Jugg, Speed, Widow's Wine, Quick Revive, Electric Cherry, Stamin-Up) land on random pads at load and reshuffle with a drop-in animation the round after each Panzer. 11 pads; Quick Revive fixed at the base west pad; Mule Kick stays on the roof; Double Tap retired.
- Widow's Wine (4000) and Electric Cherry (3000) added.
- HEALTH domain replaced by DMG REDUCTION (-4% incoming per level, including Panzer melee).
- Per-class move speed: heavy 0.65 / assault 0.80 / skirmisher 0.95 / slasher 1.05. SPRINT/MOBILITY +3%/Lv (was +2%).

### v4.6.3 — 2026-08-20 — Dev and god modes armed, upgrade cadence split
*internal*

- Dev + god modes hardcoded ON for test sessions; test build, not for publish.
- Upgrade cadence: round 1 always (dealt right after the class draft), then every 4th round when shipped (1, 4, 8, 12...); every round in dev.

### v4.6.2 — 2026-08-20 — Menu input fix, ballistic knife fix, Protector nerf, louder music
*fix*

- Fixed dead d-pad/stick in both menus (the hard freeze killed all input); menus now use a soft freeze, so you may hop in place while locking.
- Fixed the thrown ballistic knife rendering as an error triangle.
- Rogue Protectors nerfed ~25% and slowed: bullets 28 to 21 (cap 60 to 45), rocket 69 to 52, zap 10 to 7, fire interval 2.5 to 3.0s, run rate 1.0 to 0.85.
- Music was near-inaudible: ambient 50 to 68, boss 75 to 85.

### v4.6.1 — 2026-08-19 — Map-won't-load hotfix
*fix*

- Fixed the map failing to load and dropping back to the lobby (the class draft overflowed the shared HUD field budget).
- Draft countdown now ticks in 2s steps (30, 28, 26...); the draft's server blink is dropped; crosshair damage numbers cap at 2047 and the MAG chip at +127.

### v4.6 — 2026-08-19 — Panzer every 5th round with his own music, Protector waves
*gameplay*

- The Panzer comes every 5th round; "Data Spike" (Psychronic) plays while any Panzer lives and the ambient loop restarts from the top when the last one dies. Panzer HP re-anchored (base 24000 at round 5).
- Rogue Protectors come in WAVES every 3rd round, wave size = round x 2 (6 at round 3, 12 at round 6...), trickled in under a cap of 8 alive at once.
- Protector HP is a wave curve (7000 at round 3, x1.07/round); each pays 250 points + 1 luck, no per-kill banner.

### v4.5 — 2026-08-19 — Breather balconies and ambient music
*geometry*

- Breather balconies at floors 5/10/15/20: the landing opens north into a wide flat platform with neon parapets and its own light, on the same floors as the wallbuys.
- Boss music was built then removed the same day; the map now plays one low ambient track on loop for the whole game (placeholder track for now).

### v4.4 — 2026-08-19 — Class draft at game start, upgrade menu feel
*gameplay*

- Game-start CLASS DRAFT: after the intro every player picks from a 4-card panel (d-pad/stick to cycle, HOLD JUMP to lock); 30s cap then a random class; late joiners get a random class.
- Upgrade cards no longer flicker: steady focus with a soft pulse and a teal hold-progress bar.
- Rarity stings: revealing a SUPER plays a level-up chime, an ULTIMATE plays a jackpot sting.
- 6 new UI sounds (tick, lock, level-up, jackpot, jack-in, draft opener).
- Fixed: ghost second card on single-option rolls, invisible confirm flash, the misleading "left card auto-selected" timeout message.

### v4.3 — 2026-08-19 — The Panzer and Rogue Protectors arrive
*gameplay*

- PANZER boss: every 8 rounds from round 10 (up to 2), with electroball grenades that slow you.
- ROGUE PROTECTOR boss: every 4 rounds from round 5 (up to 3), slam-down entrance, chip bullets ramping up close, a real rocket every 5th shot, close-range zap (-30% slow for 3s).
- No boss healthbars.
- Boss kills pay luck: +1 luck / +500 points per Protector, +2 luck / +1000 per Panzer, to every player.
- Bosses spawn near a random living player anywhere on the tower and freeze during upgrade pauses.

### v4.2 — 2026-08-19 — Slasher gets the ballistic knife, ADS in HANDLING
*gameplay*

- Slasher's primary is now the Ballistic Knife (Bowie as melee); thrown blades stay retrievable.
- KNIFE SPEED upgrade is live: 3 levels (x0.88/0.78/0.68 melee time).
- HANDLING now also speeds up ADS time alongside reload and swap.
- LMG penetration upgrade declined: the M60 already has the engine maximum.

### v4.1 — 2026-08-19 — Fire rate, handling and recoil upgrades go live
*gameplay*

- Skirmisher FIRE RATE (x0.92/0.84/0.76 fire time) and HANDLING (reload+swap x0.85/0.75/0.65), and assault RECOIL (x0.75/0.55/0.35) are live as real gun variants; Pack-a-Punch works on every variant.
- Gun swaps happen in place on upgrade, keeping ammo and PaP state.
- KNIFE SPEED for the slasher is not buildable on the Bowie knife (no source data).

### v4.0 — 2026-08-19 — The four-class matrix
*gameplay*

- Classes: SKIRMISHER (AK-74u, was RECON), ASSAULT (Krig 6), HEAVY (M60), SLASHER (Bowie knife, replaces MEDIC).
- Shared upgrades: DAMAGE / HEALTH / BOUNTY / LUCK. Skirmisher: SPRINT (tireless at Lv5); assault: HEADSHOT / MAG SIZE / RESERVE; heavy: MOBILITY / BULLET FEED / ECHO / REGEN; slasher: SPRINT / LEECH / CLEAVE.
- TOUGHNESS removed. FIRE RATE / HANDLING / RECOIL / KNIFE SPEED designed but not yet in the card pool.

### v3.0 — 2026-08-19 — Class-specific upgrade pools and the MEDIC
*gameplay*

- New MEDIC class (Streetsweeper auto-shotgun); 4 class stations at the base.
- Upgrades are class-gated: 5 shared 10-level domains (DAMAGE / ECHO ROUNDS / MAG SIZE / BOUNTY / HEADSHOT) + 2 signatures per class (RECON SWIFTNESS + SCAVENGER, HEAVY VITALITY + TOUGHNESS, MEDIC REGEN with an ally aura + LEECH).
- Body upgrades persist across class switches; gun upgrades follow your current class gun.

### v2.2 — 2026-08-19 — BOUNTY and HEADSHOT upgrades
*gameplay*

- BOUNTY: +3% money per class-gun kill per level (banked and paid in exact 10s).
- HEADSHOT: +10% headshot damage per level, stacking with DAMAGE.
- 5 upgrade domains total.

### v2.1 — 2026-08-18 — First playtest fixes and the Aetherium HUD
*fix*

- Round-1 zombies read as "practically frozen": sprint floor raised 0.5 to 0.8, still full sprint by round 7.
- Fixed the bottomless MAG upgrade being eaten by auto-reload; the pool now refeeds at 2 rounds left and shows as a cyan "MAG +N" chip.
- Upgrade menu: you are now frozen while choosing, a card is always focused, switch with d-pad/stick/aim/fire, HOLD JUMP 0.5s to lock, timeout locks the focused card.
- Aetherium HUD ported; door prompts read "Open Door to <destination>".
- Crosshair damage numbers (amber normal, bigger teal headshots).

### v2.0 — 2026-08-18 — The full 25-floor tower, 3 classes, atmosphere
*geometry*

- The tower is 25 floors (was 3), 26 buyable doors (750 +250 per floor, cap 4000; roof 5000). Neon colours cycle 8 hues floor by floor.
- Progression: Jugg floor 3, Speed floor 7, Stamin-Up floor 12, Double Tap floor 18; wallbuys floors 5/10/15/20; Pack-a-Punch + Mule Kick on the roof.
- Two new classes: RECON (AK-74u) and HEAVY (M60); 3 hold-USE class stations at the base, switching swaps the primary and keeps your upgrade levels.
- City smog: dense purple-blue fog at street level thinning as you climb into clear night.
- Fixed the boot crash (corrupt sound banks from building while the game was open).
- Unverified in play as of this build.

### v1.5.1 — 2026-08-18 — Complete upgrade card art set
*art*

- Upgrade cards now use the full art set: card base plate, 3 domain icons (impact / triple bullets / mag+), title banner, plus the rarity frames.

### v1.5 — 2026-08-18 — Rarity frame art
*art*

- Upgrade cards now carry neon rarity frames: silver (regular), cyan (SUPER), amber (ULTIMATE); the rest of the card art is still pending.

### v1.4.1 — 2026-08-18 — Exact rarity odds
*balance*

- Each card rolls its rarity independently: 80% regular / 15% SUPER / 5% ULTIMATE base; each luck point -10% regular, +5% SUPER, +5% ULTIMATE.
- Luck caps at 8 (0% regular / 55% SUPER / 45% ULTIMATE); the HUD luck number always matches real odds.

### v1.4 — 2026-08-18 — Upgrade menu polish
*gameplay*

- Card selection window is 15s (was 30) with an on-screen countdown ("AUTO-SELECTS THE LEFT CARD IN Ns", red at 5s or less).
- Co-op shows "CHOOSING: name, name" for players who have not locked in.
- Fully maxed players skip upgrade events; if everyone is maxed the event is skipped entirely.
- Zombies take zero damage while frozen during the pick (no free damage window).
- The pause is capped at 20s no matter what.

### v1.3 — 2026-08-18 — Real upgrade panel, upgrades every round
*gameplay*

- Upgrade events now every round from round 2 (was every 3).
- The upgrade UI is a proper panel: title plate, two cards with rarity-coloured strips (silver / cyan SUPER / amber ULTIMATE), Lv X to Y readout, luck banner.
- Hold AIM or FIRE 0.5s on a card to lock it; the focused card blinks; release cancels.

### v1.2 — 2026-08-18 — Class system and the Upgrade Tower
*gameplay*

- Classes: Assault = Krig 6 + pistol, given on every spawn.
- THE UPGRADE TOWER: every 3 rounds (4, 7, 10...) the world pauses and each player picks 1 of 2 cards: DAMAGE (+12%/Lv), FIRE RATE (+10%/Lv double-hit chance) or MAG SIZE (+20% clip/Lv bottomless pool), cap Lv10, rarity REGULAR +1 / SUPER +2 / ULTIMATE +3. 30s timeout.
- LUCK shifts rarity odds and resets each event.

### v1.1 — 2026-08-17 — Smaller base arena, faster rounds
*gameplay*

- Base arena shrunk to about a third of its area: a ~104-unit ring around the tower foot.
- Rounds turn over faster: zombie spawn trickle at half stock delay (floor 0.15s), round 1 at 1.0s, pre-round stall 2s to 1s.

### v1 — 2026-08-17 — The spiral tower
*geometry*

- Full redesign: an open-air staircase spiralling around a solid neon core, 3 floors, base arena below and rooftop arena (Pack-a-Punch + Double Tap) on top.
- Night-cyber neon look: cyan/purple/pink bands per floor, blue base walls, red door slabs, Miami night sky.
- 4 buyable doors (750/1000/1250/1500); power switch at the base; Quick Revive + SMG wallbuy + mystery box at ground, Jugg floor 1, AR wallbuy + Speed floor 2, Stamin-Up floor 3.
- Zombies sprint from round 1 at half rate, full sprint by round 7, then +0.3%/round forever.
- Perk machines glow in their colours once power is on.

### v0 — 2026-08-17 — Scaffold: a 3-level greybox tower
*internal*

- First greybox: Street Lobby, Mezzanine, Sky Offices with two stairwells and buyable doors (750 / 1250); the endless-rounds twist (next round starts when the last zombie spawns) is in from day one.
