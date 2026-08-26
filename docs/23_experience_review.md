# Experience review — fun, seamlessness, presentation (2026-08-20)

A read of the whole map's code + concepts, looking for what would make a run
feel better rather than what is broken. Findings are ordered by impact, not by
effort. Nothing here is a bug report — the systems all work; these are gaps
between what the systems do and what a *tower* run should feel like.

---

## The verdict in one line

The progression systems (classes, 18 upgrade domains, luck, twins, station) are
deeper than most released custom maps. **The tower itself is the part not yet
pulling its weight** — it is currently a one-way staircase with perks bolted to
four of its landings, and the front door (map card) is a placeholder.

---

## A. Things that will hurt a live run

### A1. Solo has no safety net for ~9,900 points  (highest impact)

Quick Revive is pinned to the **floor-5 breather** (`_tod_perk_scatter.gsc:84`),
a consequence of the "perks in breathers only" change. To stand on that landing
a solo player must buy every door from lap 1 to lap 5:

| door | cost | cumulative |
|---|---|---|
| lap 1 | 1,125 | 1,125 |
| lap 2 | 1,500 | 2,625 |
| lap 3 | 1,875 | 4,500 |
| lap 4 | 2,250 | 6,750 |
| lap 5 | 2,625 | **9,375** |

Plus 500 for the machine = **~9,875 points before a solo player owns a single
self-revive.** Until then one down ends the run outright. With endless rounds
denying any safe buy window, that is a long, unforgiving opening — and it is
accidental, not designed.

Options (pick one):

- **Carve-out**: put QR back on a base pad only (it was there in v6 before the
  breather change) — the stock solo machinery already wanted it there.
- **Move the first breather to floor 3** — cheaper ladder (4,500), keeps the
  breathers-only rule intact.
- **Grant one free self-revive** that burns on first use and is replaced by the
  real machine once bought.

### A2. Powerups have no vertical handling

Drops land at the zombie's death origin. On a 160-wide open staircase with a
56-unit parapet, a drop that lands on a step can slide, and one that lands near
an opening is gone — while the pickup timer keeps running. There is **no
snap-to-landing or floor clamp anywhere in the codebase** (`_tod_powerups.gsc`,
`_tod_bosses.gsc` drop sites). In a vertical map this quietly eats Max Ammos.

Fix shape: on spawn, snap the drop to the nearest walkable landing/step surface
within the player's current floor band, and never below the floor the kill
happened on.

### A3. The breathers are not breathers

Every lap gets 2 risers, **including laps 5/10/15/20**
(`tools/gen_tower_map.js:410-415`). So the balconies named "breather" spawn
zombies exactly like every other floor. In a map whose entire identity is *the
rounds never stop*, the four balconies are the natural place to put the only
pacing beat in the design — and they currently do not have one.

Fix: drop the risers on breather laps (or halve them). Costs nothing, changes
the rhythm of the whole climb.

---

## B. The tower is not a loop (the biggest fun idea)

### B1. Nothing ever brings you back down

Perks are on floors 5/10/15/20, PaP is on the roof, and the **personal upgrade
station is at the base**. Once you are on floor 12, the station you just built
is a twelve-floor round trip away through open doors with the horde live. It
will be used for the first few rounds of a run and then never again.

Cheapest fix: **a station on every breather** — they are already described in
the generator as "restock stops," and the per-player price escalation makes
multiple terminals safe (the cost rides the player, not the machine).

### B2. The core is 9,600 units of dead volume — put a descent in it

The solid 512×512 column runs the full height of the map and does nothing but
hold up the stairs. A **fast descent route** is the single missing verb of this
map, and it fixes B1, makes the perk scatter meaningful (you can go *back* for
the Jugg that landed on floor 5), and is thematically free in a cyber city:

- **Drop shaft** — step in at any breather, ride to the base (fan/updraft catch
  at the bottom, or a stock-style teleport). One-way, no cost.
- **Zipline** from a breather down to the base arena.
- **Powered elevator** — the power switch already exists at the bottom and
  currently does very little for its 750 points.

This is the highest fun-per-hour item in the review.

---

## C. Orientation and tension

### C1. There is no floor readout

25 floors and the player has no idea which one they are on. The zone name is
known server-side (`lap14_zone`), so the data is free. A floor indicator is the
single biggest orientation win available — and it is an *image* opportunity
(see D3).

### C2. The boss climb is invisible

Panzer and the Protector waves spawn at the base and climb (`base_spawn_origin`,
plus the 18s anti-strand watchdog). The player has no signal that a Panzer is
six floors below and coming. No healthbars was the right call — but **proximity
is not a healthbar**, it is dread. A small plate reading "PANZER — 6 FLOORS
BELOW" turns dead climb time into tension.

### C3. One music loop for an entire run

`_tod_atmosphere.gsc` owns the channel and plays one ambient loop for the whole
game, with the Panzer track taking over while he lives. The fog already tells
height-as-progress beautifully (thick smog at street level, clear night air by
mid-tower). **The music should do the same** — 2-3 altitude layers (base / mid /
high) swapped on floor bands would make the climb *sound* like progress. The
channel-owner module already has the stoppable-stream primitive solved.

### C4. No run summary on death

This is a score-attack map with endless rounds — the run ends at a round number
and a floor. Right now that moment is the stock death screen. A styled summary
(floor reached, round, kills, headshots, upgrades taken, class) is the single
best retention hook available and it is pure art + LUI, no gameplay risk.

---

## D. Presentation and image upgrades

### D1. The map card is a placeholder (first thing anyone ever sees)

`zone/previewimage.png` is **3,825 bytes** — a near-empty placeholder at the
correct 600x340. It is the art shown in the in-game map-select card. Real key
art here does more for perceived quality than any code in this review.

### D2. The Workshop thumbnail is the wrong shape *and* a duplicate

`zone/workshopimage.png` is **byte-identical** to `previewimage.png` (same 3,825
bytes, same 600x340). Steam wants **square 512x512** — this is the exact mistake
KB section 11 warns about ("don't let one file serve two surfaces"). Needs its
own art.

### D3. A vertical tower gauge (new art)

The floor readout from C1, done as art instead of text: a slim stylized tower
silhouette on the HUD edge, a lit marker at your altitude, pips at the four
breathers, PaP crown at the top. Reads at a glance, tells the whole map's shape,
and is exactly the images-over-LUI direction.

### D4. Boss proximity plate (new art)

Companion to C2 — same slide-in family as the existing PANZER / PROTECTORS
banners, with a floors-below readout.

### D5. Run summary card frame (new art)

Companion to C4 — one frame plate plus the existing numeral treatment.

### D6. Already-open image debts

- **3 stale upgrade cards** — DMG REDUCTION (-5%), BOUNTY (+5%), KNIFE SPEED
  (-10%/Lv) x 3 rarities = 9 images. Prompt already delivered.
- **Electric Cherry perk icon** — still on the Borderlands placeholder; no stock
  T7 cherry shader exists. (Prompt A, never sent.)
- **Pause-menu upgrade panel set** — header + 18 row labels + pip. (Prompt B,
  never sent.)

### D7. Loading movie (solo only, per KB section 11)

`zone/video/zm_tower_of_doom_load.mkv` — a tower flythrough. The loading *image*
is inert for usermaps (the KB proved it); the movie branch is real but gated to
solo lobbies. Low priority, high polish.

---

## Suggested order

1. **A1** solo revive gate — one-line placement change, biggest live-run impact
2. **A3** breather risers — free, changes pacing immediately
3. **D1 + D2** map card + Workshop art — the front door
4. **C1 / D3** floor gauge
5. **A2** powerup snap
6. **B1** stations on breathers
7. **C2 / D4** boss proximity
8. **C3** altitude music layers
9. **C4 / D5** run summary
10. **B2** the descent route — biggest idea, biggest build
