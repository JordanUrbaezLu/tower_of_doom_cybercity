# 66 — THE WARDEN TRIALS: sealed boss arenas on every spire hub (v16.15)

**Status 2026-09-01: IMPLEMENTED, LINT-GREEN, BUILT (CHANGELOG v16.15;
v16.18 replaced the altar with an auto-closing ring + the SoE purple ritual
barrier), NOT PLAYED.** No trial has ever run in game. The ladder is §7.

## The ask (user, 2026-09-01, verbatim)

> "Can we look into enhance the spire where we add mini boss fights every
> breather zone and this also means that we should redesign the breather
> zone. The next door should be locked until you defeat the boss round hold
> out which should be 2 minutes. And it should be quite difficult. Already
> harder than the endless spire."

Read as four requirements: (1) a boss fight at every spire hub (the spire's
"breather zones" are the vendor hubs on floors 10, 20 … 100); (2) the hub
geometry redesigned around that fight; (3) the door after the hub locked
until a 2-minute hold-out is survived; (4) harder than the spire's own
baseline — which is already the map's hard mode (docs/44 §6a).

## §1 The design in one paragraph

Every hub balcony is now a **sealed 928-square boss ring** off the hub
floor's SW mid landing. The vendors (PaP, crate, two perk pads) stand on its
walls. **The ring closes itself the moment every living player is inside
it** (v16.18, user: "typically when you do hold outs there is this purple
aura where you get blocked off from leaving … once everyone is in the
holdout starts" — a 2-second tell at the mouth first, and a player stepping
back out in that window keeps it open; a downed teammate outside holds it
open until revived). Then the board is wiped, Shadows of Evil's purple
**ritual barrier** rises across the landing mouth over a hidden solid slab,
and a **120-second clock** starts on the tower gauge. For those two minutes
the ring is the whole world:
**WARDENS** (Panzers, one per player, one more in the last 30 seconds) drop
in front of the red Warden Gate and are replaced as they fall; protector,
reaver and hound adds keep the elite roof full; every elite spawned inside
carries ×1.5 HP; the trickle runs at 0.12 s, the hottest floor in the map.
When the clock runs out the gate opens for good, the party is paid 5000 each
plus a Max Ammo, and the door above the hub (or, at hub 100, the summit
extraction) unseals. **No ceiling is raised anywhere.**

## §2 Geometry (generator SECTION 6c, `SP_AR_*` / `SP_FURN`) — SUPERSEDED by §9 (v16.19: the fight moved inside the tower; the outside arena below no longer exists)

All authored in the even frame (negative x/y — every hub lap is even, which
the generator asserts). Local coordinates below; add `SP_X` (10240).

| element | where | material / class |
|---|---|---|
| arena floor | x[-1184,-256] × y[-1344,-416] at hub mid z | yellow `_tinted_edge` (DECK) |
| ring rail + cap | outside every floor edge, 56 + 112 clip | plain yellow (BLOCK) + clip |
| core-side rail | x[-256,-236] — the floor does NOT meet the core there | plain yellow |
| cover pillars ×4 | quarter points (±232 from the centre), 96 sq × 192 | red shaft, gold plinth + cap, all PLAIN |
| corner pylons ×3 | NW, SW, SE corners; the NE corner is the mouth's jamb | plain gold, red head |
| floor ring + trial mark | half-size 176 gold seam; 112-sq red mark at the centre | 1u-proud inlays (base-inlay grammar) |
| Warden gate | red posts at y −1160 / −1280 on the W wall, gold lintel, red keystone | scenery; the drop point is the mechanism |
| THE GATE | `tod_spire_trial_gate<N>` script_brushmodel, x[-416,-256] y[-426,-406] z[mid, mid+128] + permanent clip above to mid+600 | the door recipe verbatim |
| risers ×6 | W wall ×2, S wall ×2, core-side ×1, centre-south ×1 | `SP_AR_RISERS` |
| respawn spawns ×4 | north-centre, between the NE/NW pillars | `SP_ARENA_SPAWN_XY` |
| lights | gold over the altar + red on each pillar cap | +4 per hub |

Why plain materials on the pillars: a `_tinted` shaft would make every pillar
top a floating unguarded deck to `lint_tod_geometry` (the parapet rule).
Why the ring radius is 176: it touches each pillar plinth at exactly one edge
and never runs under one, so no inlay face is buried or z-fighting.

The generator asserts, before emitting anything: every vendor trigger pair
≥ r_a + r_b + 64 apart (the `BR_FURN` rule); every riser and respawn spawn
on the floor and clear of every pillar; the Warden drop 64 clear of the walls
and 80 clear of the SW pillar; the four gather points clear of pillars; the
`in_spire` bound (now ±1500) enclosing the arena with 100 to spare. The
Warden-drop assert fired on the first regen (the point was 72 from a pillar
corner) — a guard that has been watched going red.

Cost: +280 world brushes, +100 entities (10 gates, 40 lights, 10 probes, 40
risers), lit area +22M u² (+1.6%). Geometry lint: 0 misplaced walls, 0
unguarded edges, spire arena → summit walkable, no baseline regression.

## §3 Script (`_tod_spire.gsc`, plus three small edits elsewhere)

Lifecycle per hub `n`:

1. **door n opens** → `trial_watch(n)`: polls every 0.25 s for "everyone
   in" — every player who is alive and playing on the spire is inside the
   arena box (`trial_all_in`; spectators skipped, last stand counts as
   alive, so a crawler outside holds the ring open). No entities.
2. **everyone in** → the teleporter-charge FX + sound at the mouth for
   `TOD_TRIAL_CLOSE_SECS` (2 s), a re-check (stepping out cancels), then
   `trial_run(n)`:
   - `wipe_all_zombies()` (the seal's recipe — anything alive is behind the
     party, holding slots the ring needs)
   - level state first: `tod_trial_active`, `tod_trial_box`,
     `tod_trial_hp_mult`, the direct `zombie_spawn_delay` write (0.12 — the
     ascension's mid-round lesson)
   - the barrier: three `tag_origin` hosts along the mouth at floor level,
     each looping `zombie/fx_ritual_barrier_defend_door_wide_zod_zmb` (the
     purple SoE ritual lockdown wall; yaw 90 = the face looks out through
     the mouth — the one number to flip if it renders edge-on), and the
     hidden slab behind them goes `Solid + DisconnectPaths` (never shown:
     the FX is what you see, the slab is what stops you, DisconnectPaths
     is what stops the horde); quake + teleport-fire sound
   - the clock: `tod_finale_song_start/end` — the gauge's finale lane, 25
     cells filling over 120 s, zero new LUI bits
   - music: `channel_play("tod_boss_music")` directly (the Panzer refcount
     is blocked on the spire, so Warden deaths cannot yank the channel)
   - `trial_wardens` + `trial_adds` threads; at T−30 s `tod_trial_frenzy`
3. **`trial_win(n)`** after 120 s: `tod_trial_end` notify, every flag
   cleared (and only here), the barrier hosts deleted and the slab
   `NotSolid + ConnectPaths` for good, `tod_spire_trial_won[n] = true`, 5000
   team-wide + a Max Ammo on the trial mark, music back to the spire loop,
   de-rez bursts at the mark and the mouth.

**Wardens** (`trial_wardens`): holds `level.tod_panzer_alive` at
`want = players (+1 in the frenzy), cap 4`. Spawned DIRECTLY through
`spawn_panzer` with `tod_boss_force_org` (the honour-guard lane — the
director would deliver one), 6 s after a fall, only while
`elites_all_alive() < elite_roof_all()`. They carry `tod_spire_guard` so they
pay the elite rate, not the 1000 boss jackpot (ten trials × four Wardens at
1000 team-wide would end the climb's economy). `level.tod_trial_reserve =
want − alive` is published every tick.

**Adds** (`trial_adds`): `finale_pressure_loop`'s cycle minus its Panzer arm —
protector debt 2 / reaver 1 / hound 2, set-not-summed, every 4 s (2 s in the
frenzy), skipped while `elites_over_roof()`.

**Doors**: `door_manager` threads `trial_seal_window` instead of the 12 s
`seal_window` for doors 11, 21 … 91 (`trial_hub_of_door`); it stamps one
shared literal ("SEALED - win the trial in the arena below"), sets
`tod_spire_trial_seal` (read by `seal_active`, so the buy refuses with the
deny sound), polls `tod_spire_trial_won[hub]`, then stamps the price.
`summit_station` does the same for hub 100 before entering its buy loop.

### The three edits outside `_tod_spire`

| file | what | why |
|---|---|---|
| `_tod_bosses.gsc` `elites_over_roof` | roof −= `level.tod_trial_reserve` | the Wardens' first claim on `TOD_ELITE_ROOF_ALL` — a LOWER ceiling for the adds, never a higher one for anything; new public `elite_roof_all()` |
| `_tod_bosses.gsc` `boss_hp` | × `level.tod_trial_hp_mult` | the single HP choke point; keeps `level.mechz_health` equal to the Panzer's spawn HP by construction |
| `_tod_bosses.gsc` `pick_spawn_point` | reject candidates outside `tod_trial_box` | the 800u pass reaches through the shut gate onto the stairs — the sealed-crown `in_hall` case one flight up |
| `_tod_endless_rounds.gsc` riser filter | keep only risers inside `tod_trial_box` (fail-safe if none) | a zombie risen outside the gate is the stranded-actor trap |
| `_tod_endless_rounds.gsc` `tod_spawn_delay` | return `TOD_SPIRE_TRIAL_SPAWN_FLOOR` 0.12 while active | LOCKSTEP pair with `_tod_spire` |
| `ZMCursorHintNew.lua` | `TOD_NOUNS += "trial"` | the altar prompt routes to the default card |

Hint budget: +2 distinct strings (the altar and the shared SEALED literal),
85 tod-authored of 190 budgeted. No interpolation anywhere.

## §4 Difficulty, stated as arithmetic

Against the spire's baseline (docs/44 §6a/§6b: 0.18 trickle, halved round
budget, honour guard = one Panzer per player per door, elite debts ×4,
combined roof 12):

- **continuity**: the honour guard is one drop per door; the Wardens are
  held at count for 120 s and replaced 6 s after a fall — a party that kills
  fast faces MORE Wardens, not fewer.
- **containment**: no kiting up the spiral. The ring is 928 square with four
  pillars; the finale hall (the only other sealed fight) is 1536 square.
- **HP**: ×1.5 on every elite spawned inside, stacking with rampage (×1.25)
  and the co-op table.
- **the frenzy**: +1 Warden and a 2 s adds tick for the last 30 s.
- **trickle**: 0.12 s vs 0.18 (0.16 on rampage); under the twist the round
  clock compounds the speed curve faster too.
- what does NOT change: `TOD_ELITE_ROOF_ALL` 12, `TOD_ACTOR_LIMIT`,
  `zombie_ai_limit`, every per-type MAX_ALIVE. The Wardens take their slots
  from the adds' share, not from the horde's.

Every knob is a `#define` at the top of `_tod_spire.gsc` (`TOD_TRIAL_*`).
The user's own read after a run decides the numbers; 1.5 / 4 / 6 / 0.12 /
5000 are first guesses, chosen to be obviously harder without being an
actor-pool failure.

## §5 What could go wrong (things to watch on the first run)

- **The seal.** The slab is never shown; it goes Solid while hidden. A
  hidden brushmodel keeps its collision (that is why every door needs
  NotSolid as well as Hide), so this should hold — but no spire brushmodel
  has ever changed solidity live (the v14.1 movers never re-seated). If it
  fails, the trial still runs (it is a timer), it is just not sealed. Tell:
  you can walk through the purple wall.
- **The barrier's orientation.** The ritual-barrier FX is authored for a
  doorway; the hosts stand at yaw 90 (face looking out through the mouth).
  If it draws as a thin edge or lies flat, flip the yaw in
  `trial_barrier_up` — one number, `-GscOnly`.
- **Closing on entry.** With no altar, walking into the ring to buy PaP or
  ammo starts the 2 s countdown. Solo players will feel this immediately;
  the tell (charge FX + teleporter sound at the mouth) and the step-out
  cancel are the mitigation. If it reads as a trap, `TOD_TRIAL_CLOSE_SECS`
  is the knob.
- **Zombies outside the ring.** The riser filter and the boss containment
  are both box tests on generated bounds; if either misses, zombies stand
  on the stairs outside the gate holding slots. Tell: the horde thins mid-
  trial while `act` stays high in the dev probe.
- **Wardens not dropping.** `spawn_panzer` refuses under `tod_upgrade_pause`
  (never on the spire) and when no anchor player is valid. Tell: no Panzer
  in the first 10 s.
- **The gauge.** `finale_cell` forces the boss pip and down cells off while
  the clock runs — that is the finale's behaviour and correct here too.
- **Respawn placement.** The hub group's spawns moved into the ring; stock
  picks the group closest to a living teammate inside an enabled zone.

## §6 Owed follow-ups

1. **Baked banner art** (the images-over-LUI rule): `tod_trial_banner`
   ("THE TRIAL BEGINS") and `tod_trial_won_banner` ("THE TRIAL IS WON") as
   server hudelems on the spire banner's geometry (600×150 at y−130). The
   interim is `IPrintLnBold`. Prompts in §8. Each is a `.gdt` change = FULL
   build.
2. ~~**A trial track.**~~ **DONE v17.8** — "Chaos Unleashed" (Suno), alias
   `tod_music_trial`, cloned from the `tod_boss_music` row so the mixer
   treatment is identical, and gained +3.7 dB to sit on that track's
   −12.2 LUFS so the swap is not heard as a level change.
3. **Per-hub variety.** Every trial is the same recipe scaled by round. A
   `TRIAL_TABLE` (hub → Warden count / add mix / HP mult) is a 20-line
   change once the base recipe has been played.
4. **Armory page**: nothing to add (no domain, no gun); the spire section
   could carry the trial knobs.

## §7 Verification ladder (nothing below has run)

Fast path: `tools/spire_wip/HARNESS.md` (dev flag + terrace warp), then win
the finale with `tod_god`, ASCEND, buy doors 1–10 (dev money). Then:

1. hub 10: door 11 reads the SEALED trial literal and refuses with the deny
   sound; standing on the stairs outside the ring, nothing happens.
2. walk in (everyone): the charge FX + teleporter sound at the mouth, and
   2 s later everything dies, the purple ritual barrier fills the mouth, the
   mouth is solid (walk into it), the quake fires, the gauge empties and
   starts filling, boss music plays. Step out during the 2 s tell: nothing
   closes.
3. within ~10 s a Panzer drops in front of the Warden gate; adds arrive;
   zombies rise ONLY inside the ring (walk to the gate and look out).
4. kill a Warden: the elite payout, a replacement ~6 s later.
5. T−30: "THIRTY SECONDS" print, a second Warden (solo).
6. T=0: the purple wall vanishes and the mouth is passable, +5000, a Max
   Ammo on the trial mark, spire music returns, door 11 shows the price.
7. a co-op death mid-trial respawns INSIDE the ring.
8. hub 100: the summit pad reads SEALED until trial 100 is won.

## §8 Art prompts (send as files per the standing rule)

**tod_trial_banner** (2048×512, transparent, shown 600×150):
> Cyberpunk zombies-map event banner, 4:1. Bold condensed all-caps title
> "THE TRIAL BEGINS" in glowing blood-red neon with a thin gold inner
> stroke, on a black-to-crimson Tron-grid backplate with faint gold
> circuit tracery, a small gold crown mark centred above the title, edge
> glow bleeding off the plate. Transparent background outside the plate.
> No photoreal, no characters, no extra text.

**tod_trial_won_banner** (2048×512, transparent):
> Same plate and typography as the trial banner, title "THE TRIAL IS WON"
> in glowing gold neon with a red inner stroke, the crown mark now lit
> green, subtle radial burst behind the letters. Transparent outside the
> plate. No characters, no extra text.

## §9 v16.19 — THE HUB HALL: the trial moves inside the tower

User (2026-09-02): *"instead of a breather the hub battle should actually be
inside the tower. so every 10 floors the center of the tower open up for the
battle."* The outside arena of §2 is gone. Everything in §3–§7 still holds
except where this section says otherwise.

### The shape (generator §6b + the hub block, `SP_RM_*` / `SP_FURN`, even frame, tower axis at 0,0)

| element | where | notes |
|---|---|---|
| the void | core column ends at hub mid (under the hall slab), resumes 576 higher | hub 100: ends at the capital |
| the drum | four walls x,y = ±436..±456, z hall−16 .. hall+632, plain red + a gold band at +280..+320 | flush with the next lap's NW landing parapets |
| hall floor | NW piece x[-436,-256] y[64,436]; core+N x[-256,256] y[-256,436]; E x[256,436] y[-436,436]; SW strip x[-436,-256] y[-436,-416]; all at hub mid | yellow `_tinted_edge` |
| the notch | x[-436,-256] y[-256,64]: no floor — the W flight's upper half climbs into the hall | treads under the NW piece are i ≤ 6 (≥ 104 headroom) |
| THE DOORWAY | x = −256, y[-256,-192]: W-flight treads 15–16 at grade with the hall | 64 wide; on-floor rails guard the rest (notch rail N at y[64,84], notch rail E at x[-256,-236] from y = −192 north) |
| S flight inner wall | y[-256,-236] from x = −224 (tread 2) east, floor to each tread's rail top, stepped; lane end wall x[236,256] under the SE landing | tread 1 is one step above the hall; a wall from the corner shared the doorway cell |
| galleries | next lap's E flight (+192..+384) with inner rail x[236,256]; N flight (+384..+576) with inner rail y[236,256]; NO rail on the NE landing (both inner sides are flight mouths) | hub 100: none (summit stair, capital beside it) |
| pillars | (160,160), (−160,160), (160,−160), (−16,−160): gold plinth, red shaft, gold cap, 192 tall | the SW one moved east out of the doorway lane |
| ring + mark | ring R 104 W 16; mark 96 sq at (0,0) | inlays 1u proud |
| vendors | PaP W wall (−376,200) facing east; crate E wall (376,60); perk pads N wall (−100/−276, 414) facing south (yaw 269.999) | SP_FURN asserts trigger gaps, floor membership, pillar clearance |
| risers | (−340,300) (−80,300) (340,200) (340,−340) (60,−40) (−100,60) | the only risers a trial keeps live |
| respawns | N gallery east half (60..140, 360..396) | inside the seal |
| lights | gold at (0,0,+420) r 760; red at (±300,±300,+160) r 460 | probe at (0,0,+150) |
| door n | clip cut at the hall floor; the W flight's rail cap likewise | both used to rise ~600 = invisible walls in the hall |
| shelves | none on hub floors OR the floor after a hub | the post-hub shelf jutted through the drum |

### The seal
The gate is **door n's own slab**: hidden since the buy, `Solid +
DisconnectPaths` for the trial, `NotSolid + ConnectPaths` on the win. The
barrier FX hosts stand at the door's opening at floor level (`trial_gate_org`
= the W face at y = +256, one flight below the hall). `trial_box` is the drum
footprint from door n's threshold + 40 to the SE landing + 100, minus the E
lane beyond door n+1 (the next lap's flight — behind a door; `in_box` applies
the exclusion, so nothing lands there). No honour guard at hub doors.

### What the lint's flood caught (bisect record)
1. A rail along the NE landing's inner (W) edge — that edge is the N
   flight's mouth; tread 1 spans x[224,256] and the rail stood on it.
   Summit unreachable at every hub.
2. The S flight's inner wall starting at the hall's SW corner shared the
   doorway's 20u cell with the doorway.
3. The SW cover pillar at (−160,−160) left a 20-wide slot between its
   plinth, that wall and the notch rail: every hall read detached (12,545
   nodes).
4. The nine post-hub crate shelves were cut off by the drum wall (225 nodes).

Recipe: an env-gated skip per piece in the hub block (`HALL_SKIP=nw,drum,…`,
removed after), and a patched copy of `lint_tod_geometry.js` that lists
detached spire nodes by brush label. Both are ten-minute tools; use them
before reasoning about a flood failure by hand.

### First-run tells (add to §7)
- From the top of the W flight you can walk east into the hall (64-wide
  doorway) and the hall floor is at grade.
- The purple wall stands in door n's opening BEHIND you, one flight down.
- The S flight is walled from the hall on its inner side; the next lap's
  flights are visible overhead inside the drum.
- Zombies rise inside the hall only; the Warden drops from the open core.

## §10 v16.20 — escalation by tier, chime, audible tell

Tier = hub / 10. Per tier past the first: adds tick −0.25 s (floored 1.5),
elite HP +5%; one extra Warden per 4 tiers (hubs 40–70 +1, 80–100 +2, cap 4
unchanged). All in `TOD_TRIAL_TIER_*`. The first-entry chime is the lounges'
`tod_lounge_arrive`, once per player per hub. The 2 s closing tell now also
sounds at the hall's centre. What a solo run owes by hub, before the frenzy:

| hub | Wardens (solo) | adds tick | HP × |
|---|---|---|---|
| 10 | 1 | 4.0 | 1.50 |
| 40 | 2 | 3.25 | 1.65 |
| 80 | 3 | 2.25 | 1.85 |
| 100 | 3 | 1.75 | 1.95 |

(§10's per-tier steps were replaced in v16.21 by the 7% ladder and the ten
recipes below.)

## §11 v16.21 — the first real run, and what it changed

User (2026-09-02, dev build, hub 10): *"this boss fight should be toned down
about 15% and each level should have its own unique structure for this
arena. And last the entrance to get into the arena is tiny. And once players
go in it should lock up. I was able to easily walk in and out. Trials should
progressively get harder and harder and you should be granted max perks on
completion. They should increase in difficulty about 7% increments."* Then:
*"really design these uniquely for each floor … Maybe even in bosses too …
as long as they incrementally get more difficult"* and *"assets like TRIAL 1
banner all the way to 10 once the hold out starts."*

### Why the lock never held
The v16.19 seal was **door n's slab, one flight below the hall**. The trial
ran (the dev warp fires the door-buy notifies, so the watcher armed and the
Wardens came), but the sealed region was the whole floor, and the hall's own
doorway had no barrier: walking out of the room onto the stairs was allowed
by design, and read as "no lock". Two changes:

- **The seal is now THE HALL GATE**: `tod_spire_hall_gate<hub>`, a
  script_brushmodel across the entrance (the x = −256 line, y[−236,−96],
  from under the lowest porch step to hall + 128), on the crown door's
  proven Show + Solid + DisconnectPaths contract; hidden at init, shown for
  the trial, hidden again on the win. The ritual barrier FX plays along it
  (three hosts spread on y, facing +x into the hall).
- **`trial_box` is the hall alone**: the drum footprint north of the S lane
  (y ≥ −256), minus the W flight's slot (a second exclusion box) and minus
  the next lap's E flight. The S flight's inner wall now runs from the
  corner — tread 1 was a second way in and out.
- **One watcher for every hub** (`trial_watch_all`, armed at ascension)
  instead of a per-hub watcher armed by the door buy. Presence is the only
  condition; the dev warp, a bypass, anything, arms it.

### The entrance: a stepped fan (160 wide)
Tread k of the W flight (12..15) sits 12·(16−k) below the hall. Its row gets
(16−k−1) slabs stepping up 12 each eastward until the hall floor takes over
(6 slabs total), so every adjacency inside the fan — east, west, north,
south — is exactly one step: the flood walks it in every direction, nothing
inside needs a guard, and the hall meets the flight along all five treads.
Only the fan's north edge (over tread 11 and below) carries a wall up from
the lowest slab. My first cut walled the fan's east side too, and with the
inner wall closing the corner the hall sealed itself off from its own
entrance — 12,067 detached nodes, caught by the lint before a build.

### Ten halls, ten recipes
Geometry (`SP_RM_LAYOUTS`, a feature vocabulary of pillar / post / low wall /
dais / big pillar, every layout asserted clear of the approach lane, the
seven risers, the spawns, the vendor triggers and its own Warden drop) and
script (`trial_recipe`) share the names and the index:

| # | hub | hall | structure | adds (debt per tick) | Wardens |
|---|---|---|---|---|---|
| I | 10 | THE RING | four corner pillars | protectors 2 | 1/player |
| II | 20 | THE CROSS | a + of low walls, open centre | hounds 3, prot 1 | 1/player |
| III | 30 | THE COLONNADE | two rows of three pillars | protectors 3 | 1/player |
| IV | 40 | THE DAIS | a 3-tier stepped platform | reavers 2, hound 1, prot 1 | 1/player |
| V | 50 | THE BAFFLES | four staggered walls | sprinters 3, hound 1, prot 1 | 1/player |
| VI | 60 | THE INNER RING | a square ring wall with four gaps | hounds 2, prot 2 | +1 |
| VII | 70 | THE CHECKER | six thin posts | reavers 2, sprinters 2, prot 2, hound 2 | 1/player |
| VIII | 80 | THE GAUNTLET | a walled lane + two flank pillars | prot 3, sprinters 2, hound 2, reaver 1 | +1 |
| IX | 90 | THE ALTAR | the dais + four pillars | reavers 2, sprinters 2, prot 2, hound 2; frenzy from the halfway mark | +2 |
| X | 100 | THE SUMMIT HALL | one huge central pillar, nothing else | everything at 3/2/3/3; the whole trial is a frenzy | +3 (cap 4) |

The ladder: base = v16.15 × 0.85 (`TOD_TRIAL_HP_MULT` 1.275, adds tick
4.6 s) and `TOD_TRIAL_STEP` 1.07 per trial, compounding, on elite HP and on
the adds' cadence (trial X = ×1.84 of trial I). The sprinter director is a
fourth adds family now (`level.tod_sprinter_debt`). The win grants every
perk the map sells (the live scatter roster, the ascension grant's own lane)
on top of the jackpot and the Max Ammo.

### 90 seconds (v16.22)
`TOD_TRIAL_SECS` 120 → 90 at the user's word. The frenzy still covers the
last 30 s (so from 60 s in), THE ALTAR's halfway frenzy is at 45 s, THE
SUMMIT HALL is a frenzy throughout. Every "two minutes" above reads 90 s now.

### Review pass (v16.26)
Four bugs found by reading, none of which a lint could see: the seal could
close on a player standing in the slab's own thickness (the "in" region now
starts 40 past the gate line); the Max Ammo would spawn inside the dais on
THE DAIS / THE ALTAR (mark and Warden points now carry the dais's lift);
perks were granted into last stand (skipped); the scatter's reshuffle could
pull a perk machine out of a sealed hall (held while a trial runs). Plus the
win now pays 5000 + 1000 per trial past the first. Open design notes: elite
HP compounds per round with no cap, so at depth Wardens are pressure rather
than kills; one AFK teammate outside stalls the seal by the "everyone in"
rule; the TRIAL WON plate landed in v16.44 (2026-09-02, `files (99).zip`
alongside the Spire gauge, docs/71): `i_tod_trial_won` / material
`tod_trial_won`, shown by `trial_banner( 0, "tod_trial_won" )` at the win.

### 70 seconds, a track of its own, and a 25% easier first rung (v17.8)

User: *"the trials will now only last 60 seconds ... Also the trials are
starting off way to hard. They should start off about 25% easier. Then build up
from there. I think I said 8% harder each level."*

**Every duration in the body of this document is now 70 s**, the same way the
v16.22 note above overrode "two minutes". `TOD_TRIAL_SECS` 90 → 60 → **70**:
60 first, then 70 an hour later once the trial track's length surfaced
(`tod_music_trial` is 79.5 s, so 60 never reached its last third). The length
is NOT pinned to the wav — the track loops, so it is free to move for feel.

**The frenzy is now DERIVED: `TOD_TRIAL_FRENZY_SECS` = `( TOD_TRIAL_SECS / 3.0 )`**,
~23.3 s at 70. It has been the LAST THIRD since it was authored (30 of 90), and
as a literal it silently reshaped the fight every time the length moved — at 30
of a 60 s trial it is the last HALF, a difficulty *increase* inside the change
asked to be easier. Two length changes in one evening earned it the derivation.
THE ALTAR's halfway frenzy is now at 35 s and THE SUMMIT HALL is still a frenzy
throughout; both already derived from `TOD_TRIAL_SECS`.

**The ladder, re-set from the second real run.** Both axes, as v16.21 did it —
elite HP ×0.75 and the adds tick ×1.25 (slower is easier):

| knob | v16.21 | v17.8 |
|---|---|---|
| `TOD_TRIAL_HP_MULT` | 1.275 | **0.956** |
| `TOD_TRIAL_TICK` | 4.6 | **5.75** |
| `TOD_TRIAL_FRENZY_TICK` | 2.3 | **2.875** (still exactly half the tick) |
| `TOD_TRIAL_STEP` | 1.07 | **1.08** |

Ladder: **I ×0.956, II ×1.032, V ×1.301, X ×1.911** (was 1.275 / 1.364 / 1.672 /
2.344). Trial I sits just BELOW 1.0 — 25% off 1.275 is 0.956 — so a first-trial
elite is a hair weaker than a plain spire elite; that is the arithmetic of the
ask, and the ladder is back over 1.0 by trial II. `TOD_TRIAL_TICK_MIN` (1.5) is
untouched: it is a late-trial floor and trial X's tick (5.75 / 1.911 = 3.0 s)
does not reach it — it did not before either.

**The gauge needed no change and was verified rather than assumed.**
`trial_begin` sets `tod_finale_song_start/end` to a `TOD_TRIAL_SECS` span;
`_tod_gauge`'s loop calls `finale_cell()` unconditionally and `finale_cell`
sizes itself with `cells_for_mode()`, so on the spire a trial fills all **50**
cells (the "25 cells" in §3 above is the tower's count and was never right for
a spire trial). `trial_win` clears both fields and `finale_cell` returns −1, so
the bar drops back to spire altitude on the win.

**A stale lockstep note was removed from the constants block.** It demanded
`TOD_TRIAL_FRENZY_SECS` and the frenzy print move together because the print
said "THIRTY SECONDS"; v16.25 had already replaced that with the constant "THE
FRENZY". A lockstep note guarding a string that no longer exists only sends the
next reader hunting.

**Still UNPLAYED**, and now doubly so: the trials have had exactly one real run
(hub 10, 2026-09-02) which predates the v16.21 reshape, and the spire gauge has
never been seen at all.

### TRIAL I–X banners — LANDED v16.25 (the section below is the recipe that was followed)
The user generated all ten from the prompts; they are in
`source_data/tod_ui_images/_images/` and wired (GDT pairs, zone lines,
precaches, `trial_banner( tier )`). The contact sheet read as one series:
numeral left in red neon with a gold stroke, TRIAL small in gold, the hall
name in white, the glyph faint behind it.

### TRIAL I–X banners (the original recipe)
At the seal the script prints the recipe's name (`TRIAL IV - THE DAIS`) and
`HOLD THE HALL`. When the ten PNGs exist: `image,i_tod_trial_<n>` +
`material,tod_trial_<n>` zone lines, GDT `image.gdf` + 2d_blend material
pairs (mirror `tod_spire_banner`'s), `#precache("material", …)` ×10 in
`_tod_spire.gsc`, and a hudelem on `arrival_banners`' geometry (600×150 at
y−130, 5 s) called from `trial_run` after the sting. FULL build (GDT).

Prompt, one per hall (2048×512, transparent outside the plate; keep the
series consistent — same plate, same typeface, the numeral dominant):
> Cyberpunk zombies-map event banner, 4:1. A black-to-crimson Tron-grid
> plate with thin gold circuit tracery and edge glow bleeding off it. Left
> third: a huge glowing roman numeral "**{N}**" in blood-red neon with a
> gold inner stroke. Right two-thirds: "**TRIAL**" small in gold above the
> hall's name "**{NAME}**" in white neon, condensed all-caps. Behind the
> text a faint line-art glyph of the hall: {GLYPH}. No characters, no other
> text.

| n | {N} | {NAME} | {GLYPH} |
|---|---|---|---|
| 1 | I | THE RING | four small squares at the corners of a square |
| 2 | II | THE CROSS | a plus sign with its centre missing |
| 3 | III | THE COLONNADE | two vertical rows of three dots |
| 4 | IV | THE DAIS | three concentric squares |
| 5 | V | THE BAFFLES | four short staggered horizontal bars |
| 6 | VI | THE INNER RING | a square outline broken at the middle of each side |
| 7 | VII | THE CHECKER | six scattered small diamonds |
| 8 | VIII | THE GAUNTLET | two long parallel vertical lines |
| 9 | IX | THE ALTAR | three concentric squares with a dot at each outer corner |
| 10 | X | THE SUMMIT HALL | one large solid square, centred |
