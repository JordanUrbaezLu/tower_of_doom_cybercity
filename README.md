# Tower of Doom: Cybercity

Custom Black Ops 3 zombies map (`zm_tower_of_doom`) — a classic tower map with
a twist, set in the same universe as
[Abandoned Cyber City](../abandoned_cyber_city_zombies).

**The twist: the rounds never stop.** There is no pause between rounds — the
moment the last zombie of a round spawns, the next round begins. It should feel
like one unbroken siege while you fight your way UP the tower.

## Current state (v0 scaffold)

- Street Lobby (spawn) + 2 tower levels, connected by buyable switchback
  stairwells (750 / 1250 points)
- Endless seamless rounds (`_tod_endless_rounds.gsc`)
- Stock BO3 HUD — no custom UI
- Quick Revive at spawn; Jugg on L1; Speed/Double Tap, power switch,
  Pack-a-Punch and the mystery box start on L2
- Miami night-city skybox (Nastian T9 pack) visible through clip-sealed
  window openings; stock t7 + t10 greybox materials

## Build & play

```powershell
.\tools\build_map.ps1          # full build (geometry + LED bake + linker)
.\tools\build_map.ps1 -GscOnly # fast path for script/zone-only changes
.\PLAY_NORMAL.bat              # launch through Steam
```

The `.map` is **generated** — edit the layout tables in
`tools/gen_tower_map.js` and re-run `node tools/gen_tower_map.js`; never
hand-edit the `.map`.

Working notes and conventions: [CLAUDE.md](CLAUDE.md). Portable BO3 mapmaking
reference: [docs/BO3_MAPMAKING_KB.md](docs/BO3_MAPMAKING_KB.md).
