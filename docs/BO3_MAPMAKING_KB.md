# BO3 Zombies Mapmaking — Reusable Knowledge Base

> **Purpose:** everything hard-won building `zm_abandoned_cyber_city`, distilled
> into a **map-agnostic** reference so the *next* map doesn't re-fight any of it.
> Replace `<map>` with your map name (e.g. `zm_my_new_map`). This is the doc to
> copy into a new project and read first. Project-specific notes live in
> CLAUDE.md; this is the portable layer.
>
> Companion docs in this repo: `34_release_runbook.md` (e2e build/publish),
> `17_launch_runbook.md` (launch deep-dive), `16_community_techniques.md` (142
> shipped-map techniques), `14_stock_api_verification.md` (stock-API ledger),
> `20_atmosphere_and_materials.md` (sky/fog/probes), `BO3_MAPMAKING_KB.md`
> (brush-geometry editing), `BO3_MAPMAKING_KB.md` (the LED-atlas saga),
> `09_boss_items.md` (the T7-asset carve pipeline).

---

## Mindset: HACKY IS GOOD — you don't own the engine

Custom BO3 maps are **not production code**, and you control only the GSC/CSC/Radiant
surface Treyarch exposed — not the engine, not stock scripts. So **when no clean API
exists for what you want (common), the correct move is a creative hack using whatever
lever the engine *does* give you.** Hacks are encouraged, not a compromise. Pattern:
(1) confirm there's no first-class API (check the stock-API ledger + community ledger);
(2) find any engine behavior that produces the effect as a side-effect; (3) ship it;
(4) document the hack + *why* (code comment + doc + memory) so it's reused, not
re-discovered. Worked examples from this map: **"disable" volumetric fog by pushing its
start plane to ~100,000,000 units** (there is NO fog-off builtin — even stock `_art.gsc`
resorts to this); HUD via clientfields because `.csc` can't call `.gsc`; surface re-skin
by swapping the brush-face **material token** (face materials need no `.zone` line);
delivering the cold cyber-night haze through a **scripted `SetVolFog`** pass (there's no
Radiant knob for the exact look), layered over the map's **baked** neon lights +
reflection probes (§1); **finish a stock-but-unfinished
pipeline from your own side** (this map completes the shipped-broken Electric Cherry perk
in `_acc_perk_electric_cherry`). **A working hack beats a "clean" solution that's blocked
by code you can't edit.**

---

## 0. Quick reference (the commands that actually work)

```powershell
# One-command headless build (asset-gate -> sync -> cod2map64 -> LED -> linker -> verify .ff).
# The user's job is to TEST, not compile — build it yourself.
.\tools\build_map.ps1              # FULL: any .map / brush / entity / material / sky change
.\tools\build_map.ps1 -GscOnly     # FAST: GSC/CSC/.zone/.csv-only change (reuses the last BSP)
.\tools\build_map.ps1 -Run         # build, then launch on success

# Fast bake gate after ANY geometry/material/sky change (cod2map + LED; prints BAKED/CRASHED)
.\tools\_bake_test.ps1 "<tools>\map_source\zm\<map>.map"

# Launch (THE one load-bearing arg is +set_gametype zclassic)
.\tools\run_game.ps1
start "" "steam://run/311210//+set fs_game <map> +set_gametype zclassic +devmap <map> +set developer 1 +set logfile 1"
```

`build_map.ps1` wraps the raw pipeline below (run by hand if you need to):

```powershell
.\tools\sync_to_modtools.ps1                      # linker builds the DEPLOYED copy, not your repo
# GSC-only change: just the linker (geometry/BSP reused):
& "<tools>\bin\linker_modtools.exe" -language english -modsource <map>
# GEOMETRY changed — full pipeline, in order (cod2map64 MUST run with cwd = <tools>\bin):
& "<tools>\bin\cod2map64.exe" -platform pc -navmesh -navvolume -loadFrom "<tools>\map_source\zm\<map>.map" "<tools>\share\raw\maps\zm\<map>.d3dbsp"
& "<tools>\bin\radiant_modtools.exe" -ledSilent +medium +localprobes +forceclean +recompute "<tools>\map_source\zm\<map>.map"
& "<tools>\bin\linker_modtools.exe" -language english -modsource <map>
```

`<tools>` on the dev box = `C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130` (Steam appends the AppID `455130` on name collision — the game itself is the folder without it). Detect the tools root by the presence of `bin\modlauncher.exe`, never by folder name.

---

## 1. Build pipeline

The Mod Tools build is **4 stages**; `build_map.ps1` runs them headless (no Launcher GUI):

| Stage | Tool | Produces | Re-run when |
|---|---|---|---|
| GDT DB | `gdtdb.exe /update` | asset DB | GDTs changed |
| Map/BSP | `cod2map64.exe ... -navmesh -navvolume` | `.d3dbsp` + navmesh/navvolume `.hkt` | **geometry** changed |
| Lighting | `radiant_modtools.exe -ledSilent +recompute` | LED lightmap (`.led`) | geometry/lights/probes changed |
| Link | `linker_modtools.exe -modsource <map>` | the `.ff` fastfile | **any** change (compiles GSC + packs) |

- **Build success = a FRESH `.ff` was written, NOT the linker exit code.** The linker prints `ERROR: … not found in gdtDB` for missing-but-substituted assets and exits nonzero, yet still packs a valid `.ff`. `build_map.ps1` waives those and fails only if no fresh `.ff` lands. Concrete case (2026-08-23): `Material gfx_teleport_tube_em_scroll_nocull was not found in gdtDB` from the kino teleport FX's beam — the material exists only as a beam reference in stock `t7_beams.gdt`, and the beam still renders in game. Treat a NEW line of this class as "verify the visual once, then waive", not as a build failure.
- **The linker compiles GSC from the DEPLOYED `usermaps\<map>\scripts` copy, NOT your repo.** Edit → **sync** → build, every time. Skipping the sync silently builds stale code and you chase a ghost ("I changed it but nothing changed in game"). Cost us hours. Verify a deploy landed (file size/mtime) before trusting a build.
- For **GSC-only** changes, `-GscOnly` runs *only the linker* — the BSP from the last `cod2map64` is reused. ~seconds. NOT valid if any brush/entity/material moved.
- **A build packs the whole SHARED tree, not just your change.** With several sessions editing one working tree, "no linker / no game running" is NOT "safe to build": on 2026-08-23 a peer's `-GscOnly` build shipped a `BUILD OK` .ff whose scripts placed perk machines and a teleporter pad off the OLD balcony geometry — the generator had been edited but the .map not yet regenerated. Before ANY build ask every peer whether a regen is pending; a claim list naming `gen_tower_map.js` means a geometry change is in flight → FULL build only, by the session that owns it.
- **`cod2map64` MUST run with cwd = `<tools>\bin`** or navmesh gen aborts (`ERROR: Unable to load navigation mesh generation settings`) **while still writing the `.d3dbsp`** — the build looks fine but `_navmesh.hkt` is stale → zombies path the OLD geometry. (`build_map.ps1` handles the cwd.)
- **The navmesh IGNORES all entities** (`radiant\configs\navmesh.json` `exclusions`: `misc_model`, `script_model`, `script_brushmodel`, `dyn_model`, `clip_player/missile/weapon/vehicle/physics`, triggers, volumes). Only **worldspawn brushes** cut the mesh at compile (`clip` and `clip_ai` are NOT excluded; carve-only materials exist: `clip_carver`/`clip_navmesh_carver`/`clip_navvolume_carver` — nav cut without player collision). So ANY entity-based collision (a script_brushmodel clip, a script_model with a `_col` LOD) is a solid the pathfinder can't see: **zombies path onto the footprint and grind on the prop until their target moves** (stock targeting never re-picks a merely-unreachable target). The runtime fix is stock's own: **`<ent> DisconnectPaths()`** — every stock perk machine (`_zm_perks.gsc:1551-1555`) and PaP (`_zm_pack_a_punch.gsc:114-118`) spawns collision then immediately disconnects; door slabs auto-disconnect (`_zm_blockers.gsc:272-275`). Pair every later `NotSolid()` with `ConnectPaths()`. (The API doc says a script_brushmodel needs the DYNAMICPATH spawnflag for this — in practice plain .map-authored brushmodels take it fine.) No other dynamic ground-nav primitive exists in T7 (no NavTrace/SpawnNavObstacle/BlockNavmesh). Ours: `_acc_map_randomizer.gsc::manage_prop_clip_navmesh` sweeps all `acc_clip_*`/`acc_box_clip_*`. Full ledger entry: docs/16 "Navmesh ignores ALL entity collision". Debug render: `developer 1` + `ai_shownavmesh 1`.
- Link order matters: geometry/gfx assets convert **before** scriptparsetree GSC compiles. A geometry-asset error aborts the build before GSC is ever tested — clear geometry errors first.
- The linker **stops at the first error** and compiles `#using`'d modules in order. A clean run validates everything up to the break point.
- `cod2map64` warns "NavVolume generation is skipped" when there's no `nav_volume` brush — harmless for ground-only zombies.
- **STALE LIGHTING BAKE = generated brushes that draw BLACK or NOT AT ALL while template brushes look fine (Shadowlight, 2026-09-06, hit at least four times).** The `.led` is indexed by surface. Relink (`-SkipBake` / `-GscOnly`) after ANY `.map` change and every surface past the divergence has no lightmap: "black except at grazing angles" (specular only), or simply absent, floor present. Looks like a rendering/occlusion bug; it is a stale artefact. **Rule: a build script must refuse the skip-bake path unless the `.map` hashes identical to the one the last bake saw** (Shadowlight's `build.ps1` writes `<map>.led.mapsha` after each bake and compares). Two sessions sharing one install make this trap automatic: whoever relinks after the other's geometry change ships it.
- **STALE OCCLUSION CACHE = walls, floor and ceiling that VANISH BY VIEW ANGLE (Shadowlight, 2026-09-06).** The linker's `UmbraConvert` step builds the occlusion-culling tome at LINK time from tiles cached PER MAP NAME under `<tools>\share\assetconvert\umbra\cod2map\<map>\`, and never invalidates them. A map whose first build under its name was tiny/empty (a renamed control map) keeps linking `UmbraConvert: computing 0 tiles` / `N tiles loaded from cache` — a tome for the old geometry applied to the new: big triangular holes in walls, whole walls and the floor disappearing depending on where you stand, while collision still works. Looks like bad brushes or z-fighting; is neither. **Fix: delete that cache directory before every build** (`build.ps1` step 1b does). The linker also caches the finished tome by BSP content, so an unchanged BSP relinks with no Umbra lines at all — expected. Removing the `umbra_volume` entity makes it WORSE (`UMBRA volume NOT set`); keep it.

### The LED lightmap-atlas ceiling (durable reference)

BO3 lighting is **baked** — a `.led` lightmap (~75 MB) is computed by the Radiant lightmapper and bundled into the `.ff` at link. On some maps the bake **hard-crashes**:

```
SANITY CHECK FAILURE (Result == ((HRESULT)0L))
…\bin\Radiant_modtools.exe   q:\t7\pc\code\tools\radiant\brush.cpp:1860
```

Under `-ledSilent` the crash modal is **not** suppressed, so it presents as a 200s+ **hang** with no `.led` written. This is **NOT a per-brush geometry defect** — adding a *clone of a known-good brush*, or a plain box in an empty room, crashes an otherwise-clean map identically. It is a **lightmap-ATLAS overflow**:

- A script-generated `.map` emits the unpacked placeholder `lightmap_gray 16384 16384 0 0 0 0` on **every lit face** → ~90% of faces pile on the same atlas offset `(0,0)`. (A shipped, Radiant-authored map like `zm_alien_isolation` bakes thousands of faces fine — its lit faces all carry **unique packed** lightmap UVs; only clip/tool faces sit at `0,0`.)
- Radiant repacks those colliding charts at bake time; with the uniform placeholder scale the atlas fills at a low, **fragile** surface budget → adding almost any surface overflows a per-page D3D `CreateTexture` allocation → the assert. The ceiling is **content/packing-specific, not a scalar triangle count** — a map with *fewer* triangles than a baking baseline can still crash.

What works vs what doesn't:
- ✅ **Stay under the surface budget.** Reverting over-budget geometry back below the ceiling restores the bake — this project's map **bakes again today**, so `build_map.ps1` runs the LED pass **by default** and **`-SkipLED` is a RED FLAG** that hides a lightmapper regression, not a routine switch. Heavy new geometry can re-hit the wall — gate every geometry change with `_bake_test.ps1`.
- ❌ **Rewriting the `.map` lightmap offsets in text is INERT** (`tools/pack_lightmap_uvs.js` proved this): Radiant re-derives its own atlas from geometry/materials and **ignores** the `.map` offsets. The only in-tool repack is Radiant **GUI** Select-All → recompute → Save, which the headless pipeline can't drive.
- ❌ **Deleting the `.led`** links fine but renders **fullbright pure white** (greybox base color is `1.0`, so with no baked light every face is blown out).
- **Historical (atlas-crisis era):** while the bake was down, the dark look could ride **LED-free** levers — scripted fog + a runtime `VisionSetNaked` grade (linker-only, overwriting the baked light) — so baked-light *quality* wasn't on the critical path. **That is no longer the stance:** the map **bakes today** and the shipped look now leans on **baked neon lights + reflection probes** (§4), with the custom vision grade **dormant** (`_acc_atmosphere.gsc` `ACC_VISION_ON 0` — it read worse than stock on flat greybox, so the map ships base-game colours). Full saga + the ~50-bake investigation: `BO3_MAPMAKING_KB.md`.

---

## 2. Launch & run (the saga, distilled)

Four independent gotchas; all four must be satisfied to get a playable match:

1. **Split-install junction.** Linker writes the `.ff` into the *tools* `usermaps`, but the game loads `usermaps` from the *game* folder. Junction them: `mklink /J "<game>\usermaps" "<tools>\usermaps"`. (`sync_to_modtools.ps1` auto-creates it.)
2. **Steam DRM.** A raw `BlackOps3.exe` launch is refused ("Steam must be running" → exits). Need `steam_appid.txt` = `311210` next to the exe **and** launch *through Steam* (`steam://run/311210//<args>`), not the raw exe. The Mod Tools Launcher's **"Run" checkbox launches the raw exe → don't use it** on a split install.
3. **Gametype = `+set_gametype zclassic`, NOT `+set g_gametype zclassic`.** `g_gametype` is a dvar the engine **resets to the session default** (`callbacks_shared.gsc`: `zclassic` for ZM, `tdm` for MP), so a plain `+set` never survives → falls back to `tdm` → `Com_ERROR: Script file not found: 'scripts/zm/gametypes/tdm.gsc'` → **black screen**. `set_gametype` is the engine command the Launcher itself uses (its "Set a gametype to load with map" knob); it sticks.
4. **Steam Launch Options must be EMPTY** when using `steam://run//<args>` — Steam *appends* them, producing a **doubled command line** that re-corrupts the gametype. Pick ONE arg source.

**Canonical launch:** see §0. Repo wraps it in `PLAY_NORMAL.bat` / `tools\run_game.ps1`.

**Steam launch-jam (automation hazard):** force-killing `BlackOps3.exe` (`Stop-Process`) + rapid `steam://run` relaunches makes Steam **silently ignore** launch requests (no process, no log). Fix: fully restart Steam (`steam.exe -shutdown`, relaunch, wait for full connect). Interactive user launches are unaffected. Don't hammer relaunches in a loop.

---

## 3. GSC dialect (BO3 ≠ WaW/BO1/BO2)

**Three languages / one asset format.** **GSC** = GameScript, server-side gameplay (~95% of custom code). **CSC** = ClientScript — same language, separate VM, runs on each player's machine (HUD glue, local FX/sound). **LUI** = a Lua UI framework for menus/HUD widgets. **GDT** = Game Data Table, plain key/value asset definitions (weapons, materials, sounds, FX), edited through APE. You write mostly GSC; touch LUI only for a real UI; edit GDTs to define assets.

- `function` keyword on **every** definition. `#using` not `#include`. `#insert` for `.gsh`/`.gsh` macros. `&func` / `&ns::func` for pointers; call a pointer as `obj [[ ptr ]]( args )`.
- `#namespace x;` **after** every `#using`/`#insert`/`#define`/`#precache` (it terminates the preamble). A `#using` after `#namespace` = `unexpected TOKEN_USING`.
- Stock namespaces drop the file's leading underscore: `_zm_utility.gsc` → `zm_utility::`. Convention here: `_acc_main.gsc` → `acc_main::`.
- **No `_zm::main()`.** Usermaps bootstrap via `zm_usermap::main()` (calls `load::main()`). Entry scripts live in `scripts/zm/`, NOT `maps/zm/`.
- **Ternary must be fully paren-wrapped:** `( cond ? a : b )`. Bare `= cond ? a : b` or `return cond ? a : b` fail. No general ternary operator — it's a parenthesized-primary production.
- **No `.field` on a parenthesized expression:** `( call() ).name` errors; `call().name` is fine. Use a temp var for the paren case.
- **Reserved keywords:** `class` (TOKEN_CLASS), likely `new`. `type` is NOT reserved (stock uses it as a param).
- **Cross-module call needs BOTH** the `#using` AND the function to exist. Stock macro needs its `#insert`. `tools/lint_gsc_xref.js` statically verifies all four classes — run it before every build.
- **`.csc` (client VM) cannot call `.gsc` (server VM).** HUD/clientfield work that must be client-side needs real `.csc` modules; the *only* server→client channel is a clientfield (§5).
- **State conventions:** `self` = the entity the fn runs on; `level` = world/global; `game` = cross-restart. No classes — use `spawnstruct()` for records; fields spring into being on assignment. Prefix custom state `self.acc_*` / `level.acc_*` and custom events `acc_*` so they never collide with stock.
- **`isdefined()` everywhere.** Accessing an undefined field throws a script runtime error; a `string/entity == undefined` comparison itself throws — guard with `isdefined()` (including disconnected players in snapshot arrays).
- **Threading / endon discipline:** `thread fn()` = concurrent coroutine; `wait(n)` (real seconds); `waittill("evt", args…)`; `notify("evt", args…)`; `endon("evt")` kills the thread when the event fires. **Always** `endon("disconnect")` on a player thread, `endon("death")` on an entity thread, `endon("end_game")` on a level thread — a leaked loop outlives its owner and throws on freed state.
- `IPrintLnBold` on a player shows in `console_mp.log` as `[ SCRIPTER] [msg]...` — great for proof-of-life. The `/# … #/` dev-block (`/# println("…") #/`, dev builds only) does NOT reliably route to that log.

---

## 4. Map anatomy (Radiant entity recipes, verified)

Stock prefabs live in `<tools>\map_source\_prefabs\zm\zm_core\`. Inline structs are equivalent to the prefabs (shipped maps do both). Radiant map sources live in `<tools>\map_source\zm\`, never under `usermaps\`.

- **Player spawns:** `script_struct` targetname `initial_spawn_points` (script_int 1..4, noteworthy `initial_spawn`).
- **Zones:** `info_volume` noteworthy `player_volume`, targetname `<zone>`, target `<zone>_spawners`. A zone only exists once `zone_init` runs — reached via `zm_zonemgr::add_adjacent_zone(a, b, flag)` or the `manage_zones` init list. The entry script wires the graph in `<map>::main()`.
- **Zombie spawn locations:** `script_struct` targetname `<zone>_spawners`, noteworthy `riser_location` / `dog_location`. One `actor_spawner_zm_factory_zombie` per map drives them.
- **Buyable doors:** `trigger_use` targetname `zombie_door`, `target <door_slab>`, `zombie_cost <n>`, `script_flag <enter_x>`. The `<door_slab>` = `script_brushmodel` (same targetname as the trigger's `target`) with `script_vector "0 0 130"` + `script_transition_time` (slides up on purchase). Stock `_zm_blockers::door_init` `flag::init`s the `script_flag` during load.
  - **To re-close a door in script (e.g. a lockdown seal), FIRST check how the map OPENED it** — the inverse op differs:
    - **Force-opened in place** (a dev/auto "open whole map" that does `slab ConnectPaths(); NotSolid(); Hide()`): the slab **never moved**, it's hidden at its closed origin z[0,128]. Re-close = `slab Show(); slab DisconnectPaths(); slab Solid();` IN PLACE. **Do NOT `MoveTo`** — the slab is already at closed-position, so moving it `origin − script_vector` drops it through the floor and it stops blocking.
    - **Stock buy path** (player bought it with points): `_zm_blockers::door_classify` auto-sets `script_string="move"`, so on purchase the slab `MoveTo`s `origin + (0 0 130)` and stays solid UP at z+130. There, `show/solid` in place floats a slab above the gap — instead drive the stock CLOSE `slab.door_moving = undefined; slab thread zm_blockers::door_activate(time, false)` (MoveTo back down).
  - **Crush-safety either way:** never `Solid()` a slab a player is standing in (it can stick→eject→OOB-kill). Gate it: only `Solid()` when no `GetPlayers()[i] IsTouching(slab)` (stock `door_solid_thread`, `_zm_blockers.gsc:1104`); re-assert on a ~1s loop so it solidifies once the doorway clears.
- **Perk machines:** `script_struct` targetname `zm_perk_machine`, `script_noteworthy` = specialty (e.g. `specialty_armorvest`), `model` = vending model, optional `script_string` location filter (`<gametype>_perks_<location>`).
- **Pack-a-Punch:** `misc_prefab` model `_prefabs/zm/zm_core/vending_weapon_upgrade_spawnable.map`, `script_string <gametype>_perks_<location>`.
- **Wallbuys:** `script_struct` targetname `weapon_upgrade` (`zombie_weapon_upgrade` = class weapon name, `target` → a second struct carrying the world `model`). Chalk decal optional.
- **Mystery box:** `zbarrier_zmcore_MagicBox` (+ `treasure_chest_use` trigger, `zombie_cost`). Single-chest maps ignore `level.start_chest_name`.
- **Power switch:** `_prefabs/zm/zm_core/power_switch.map`. Power = the `"power_on"` FLAG.
- **Template skybox trap:** the stock zm template `volume_sun` ships MP sky (`ssi1/ssi2` = `mp_havoc`, `ssi1_runtime_override` = `mp_havoc_overide`) → hard link error `xmodel 'skybox_mp_havoc_override' is missing`. Set all three to `default_day`. **Every new map from the template needs this.**

### Editing baked brush geometry (the `.map` plane format)

Portable whenever your `.map` is **script-generated text** (as this map's is — that's why hand-editing is safe and Radiant round-tripping is not).

**A brush = 6 plane lines in a FIXED order:** bottom (`z1`), top (`z2`), SOUTH (`-Y`/`y1`), EAST (`+X`/`x2`), NORTH (`+Y`/`y2`), WEST (`-X`/`x1`). On each plane, **only the constant-axis number is real** — the 1st number of each point (X) on E/W planes, the 2nd (Y) on N/S, the 3rd (Z) on top/bottom. Every *other* number is a **byte-identical hardcoded placeholder** emitted on every brush in the file (zero positional info) — never touch it. The plane normal is mathematically **independent** of the constant you edit (it cancels in both edge vectors), so changing `x1/x2/y1/y2/z1/z2` keeps the outward normal.

**Validity rules you can break (the only ones):**
1. Keep `x1<x2`, `y1<y2`, `z1<z2`. Crossing them makes the opposing half-spaces stop overlapping → an empty solid the BSP culls (a half-space *offset* failure, not a "normal inversion").
2. Minimum wall **20u thick / 256u tall / floor slab 16u** (20u compiled clean; thinner is untested).
3. Never make two points in one plane line coincide → the plane normal zeroes → degenerate brush.

**Hand-edit the plane constants directly** (each `Edit` is a unique-string match that fails loudly on a mis-read). **Do NOT round-trip an axis-aligned shrink through Radiant** — it re-exports ~1000 unrelated faces and rewrites every GUID/formatting, breaking by-GUID cross-checks. A by-GUID rewrite tool is worth building only when scaling the same edit across all zones.

**Watch for multiple brush families.** Different generators emit incompatible windings (e.g. a placeholder-plane family at 20u/256u vs a full-corner family at 16u/128u). Never apply one family's winding to the other.

**Fixed-vs-free wall — the core DOF rule.** A wall carrying a door/corridor **gap is FIXED** perpendicular — you can't move it without dragging the corridor floor + door slab + trigger + gap with it. A **gapless wall is FREE** to move inward, bounded only by the band the gaps occupy. If every corridor runs E-W, all gaps live on E/W walls → **N/S walls are always free; an E/W wall is free only if it carries no gap.**

**Cross-check duplicated footprints.** Room footprints get copied across several generators + the baked `.map` with no engine-level single source of truth. Keep a `source_data/rooms.json` SoT + `tools/validate_rooms.js` asserting every copy agrees — ours catches a real bug: a **double-shell** (a second generator shell overlapping the canonical room — larger in X, misaligned door gaps, a coplanar double floor + false ceiling + solid geometry poking into the live corridor). Canonical = the greybox outer room; delete the stray shell. Full mechanics + the per-zone shrink playbook: `BO3_MAPMAKING_KB.md`.

Build note: any brush move is **BSP-baked** → full pipeline (§1). A coordinate-only move needs **NO `.zone` edit** (face material tokens are never zone-listed; geometry rides in via the `col_map`/`gfx_map` `.d3dbsp` lines). Forgetting the navmesh regen (cwd=bin trap) leaves a stale `_navmesh.hkt` → zombies path the OLD footprint even though the `.ff` builds clean.

### Materials, sky & fog (atmosphere) — verified

Full plan for THIS map: `20_atmosphere_and_materials.md`. The portable rules:

- **A brush face's material token IS the GDT material asset name.** In the `.map`, the name after a face's 3 plane points (greybox default `script_wall` / `script_floor_ceiling`) is the material; `cod2map64` bakes it into the BSP and the linker resolves it from any GDT in the project. Re-skin = change the token (Radiant material browser, or bulk find/replace in the plain-text `.map`).
- **Face materials need NO `.zone` line.** A shipped map (`zm_alien_isolation`) has **2** `material,` lines for **~1017** materials. Rule: referenced *by a face* → auto-pulls from the GDT, no line. Referenced only by **worldspawn/SSI/script/model** (LUT, sky material, sky xmodel, HDR image, script-decal, FX) → needs an explicit `material,`/`image,`/`xmodel,` line.
- **Stock materials ship free** (already in installed fastfiles): no GDT, no `.tif`, no `.zone` line, no license issue — just the right name. Stock libraries on disk: `<tools>\texture_assets\t7_{concrete,metal,glass,brick,asphalt,plastic,techart}.gdt` + `t7_decal_*`. Verified usable dark/wet names: `t7_concrete_bare_dark_01_wet`, `t7_concrete_floor_garage_cracked_wet_nw`, `t7_metal_duct_insulation_01_grey`, `t7_asphalt_damaged_dark_wet`. **Do NOT** copy another community map's material names (e.g. alien's `black1_plaster`/`ayz_floor`) — they're that author's *custom* GDT, absent here → "missing material", and unlicensed.
- **Sky = SSI + skyboxmodel, not a brush.** worldspawn `skyboxmodel` (inverted-sphere xmodel) + the `volume_sun` `ssi*` keys (sun-set-info asset, one per light state, carries its own skyboxmodel/sun/exposure). **Fastest ZM-safe night look, zero custom assets:** set `ssi*` to stock **`default_night`** + `skyboxmodel` to **`skybox_default_night`** (both verified present; never `mp_havoc`). Custom HDRI sky = a `sky_latlong_hdr` material + `.exr` HDR image + sky xmodel + custom SSI, and DOES need `xmodel,`/`material,`/`image,` `.zone` lines (not face-referenced).
- **Fog is script, separate from sky + vision.** `SetVolFog( startDist, halfwayDist, halfwayHeight, baseHeight, r, g, b, maxOpacity )` — 8-arg global, **0..1 float** RGB+opacity (stock `load_shared.gsc:807`). A `.vision` rawfile does color-grade ONLY (no fog), applied via `SetVisionSet`. A bare server-side `VisionSetNaked(name, blend)` sets the GLOBAL naked vision for all players (stock `_emp.gsc:428-431`; new joiners inherit it). This map's fog + optional grade: `_acc_atmosphere.gsc` (dvar-tunable; the custom grade ships OFF because it read worse than stock on flat greybox).
- **Reflection probes** (`reflection_probe` entities, injected by `tools/gen_reflection_probes.js` — this map ships ~15, one per zone + trench; ~157 `light` entities via `gen_neon_lights.js` / `gen_underground_lights.js`) are what make wet ground read as "cyberpunk city." They're **baked by the LED pass**, so a FULL LED build is required for them to appear (`-GscOnly` won't).
- **Build-step order:** world/material/sky/`volume_sun`/skybox/reflection-probe changes are **BSP-baked** → `sync` → `cod2map64` → `radiant_modtools -ledSilent +recompute` (**LED relight mandatory** or the new lighting/reflections don't appear) → `linker`; new GDT assets also need `gdtdb /update`. **Pure-script** fog/`.vision` = **linker-only**.
- **Workshop licensing:** ship only stock, self-authored, or **CC0** (ambientCG / Poly Haven / ShareTextures / Kenney — all allow bundling raw files in a game). **Never** ship textures.com/Poliigon/Quixel-Megascans/Fab (their terms forbid mod redistribution) or assets baked into another community map.

---

## 5. Verified stock APIs (the traps)

From `14_stock_api_verification.md` — read it before touching stock interfaces.

- **Event callbacks (dispatch verified):** `callback::on_connect(&fn)` (player joins; `self`=player), `callback::on_spawned(&fn)` (respawn/round-start/revive), `callback::on_disconnect(&fn)`, `callback::on_ai_spawned(&fn)` (any AI; `self`=actor, **no args**) all fire. **`callback::on_ai_damage` / `callback::on_ai_killed` are register-only, NEVER dispatched** in stock — a documented trap (the 13-arg "AI damage callback" on forums belongs to a *different* system). Use the real hooks below.
- **Modifying AI damage:** `zm::register_actor_damage_callback(&fn)` — `self`=victim; signature `(inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, psOffsetTime, boneIndex, surfaceType)`; **`return -1`** leaves damage unchanged AND lets later callbacks evaluate; any other return becomes the final damage and short-circuits the rest. (In a **player**-damage chain the stock loop returns the FIRST non-`-1` result — a naive `return iDamage` starves god mode/effects, so read-only hooks MUST `return -1`.)
- **Per-zombie death:** `zm_spawner::register_zombie_death_event_callback(&fn)` — `self`=the dead zombie, arg=attacker; mod/hitloc live on `self.damagemod` / `self.damagelocation`. **TRAP:** `"zombie_killed"` is notified ONLY on the player, no args, and only in the insta-kill path — a `level waittill("zombie_killed")` never fires.
- **Flags:** `"power_on"` and `"initial_blackscreen_passed"` are FLAGS — use `flag::wait_till` (a bare `waittill` hangs / misses an already-set flag). `flag::exists/init/set/get`. Rounds: `level.round_number` + `level waittill("between_round_over")`.
- **Score/points:** never write `player.score` (it desyncs `pers["score"]`); use `zm_score::add_to_player_score(points)` (the "+100" floater/VO/stats; **rounds UP to a multiple of 10** — pre-quantize shares) and `zm_score::minus_to_player_score(points)` (honors the free-purchase GobbleGum). Reading `player.score` is fine.
- **Perk machines leave an INVISIBLE WALL when they go away (tod v9.31, 2026-08-23):** struct-spawned machines get a solid `zm_collision_perks1` script_model as their collision (`_zm_perks.gsc:1551`, `t_use.clip`). Stock's solo Quick Revive epilogue (`_zm_perk_quick_revive::revive_solo_fx`) flies the machine off after the 3rd use and then only `machine_clip Hide()`s the clip — **`Hide()` stops rendering, it does NOT clear collision** — so the spot stays blocked for the run (invisible on stock maps because QR sits in an alcove). Any time a machine model is deleted/ghosted (`turn_perk_off`, `Ghost()`), its clip must be `NotSolid()`'d too (and `Solid()`'d again on unhide). Pattern: `_tod_perk_scatter.gsc::qr_clip_watch` (mirror the model's `ishidden` onto the clip). Same rule for any entity pair you spawn: `Hide()`/`Ghost()` ≠ `NotSolid()`.
- **Perks:** cost lives in `level._custom_perks[specialty].cost` — set it before the first purchase/machine read (in `main()`). `level.perk_purchase_limit` removes the 4-perk cap. ZM specialties: `specialty_doubletap2`, `specialty_staminup`, `specialty_armorvest`(Jug), `specialty_quickrevive`, `specialty_fastreload`(Speed), `specialty_additionalprimaryweapon`(Mule), `specialty_deadshot`, `specialty_widowswine`. **The stock `_zm_perk_electric_cherry` pipeline ships UNFINISHED — you can complete it from your own side** (this map ships a real Electric Cherry on `specialty_combat_efficiency` via `_acc_perk_electric_cherry`, and re-uses the freed `specialty_electriccherry` for a custom perk — PhD Flopper).
- **Player sprint meter (longer / unlimited sprint) — TWO knobs, two sides (tod v9.15, 2026-08-22):** the meter is predicted on the CLIENT from the client's own `player_sprintTime` dvar, which stock sets per client ONCE at connect (`zm/gametypes/_globallogic_player.gsc:125` `self SetClientPlayerSprintTime( level.playerSprintTime )`, gametype value 4). The server-side `self SetSprintDuration( n )` does NOT reach that dvar — map 1's "The Flash" (6 s) and tod's first two tireless fixes (specialty only, then `SetSprintDuration(60)`) all changed nothing. Set BOTH to the same seconds: `self SetSprintDuration( n ); self SetClientPlayerSprintTime( n );` (official API: "Sets player_sprintTime dvar only on this client") and restore both to stock on un-grant (client side from `level.playerSprintTime`, fallback 4). Per-client, so it can stay class/level-gated. Stock Stamin-Up touches neither knob (pure engine specialty). Pattern: `_tod_upgrades.gsc::tireless_apply/clear`.
- **Weapons are objects** (`weapon.name`); BO3 names are class-based (`ar_accurate`=ICR-1, `shotgun_fullauto`=Haymaker, `pistol_standard`) — never `<name>_zm`. **Ported `_zm` assets — the suffix rule (tod v9.29 boot, 2026-08-23):** the engine STRIPS `_zm` at load, so the `.zone` line takes the ASSET name (`weapon,t9_amp63_rdw_up_zm`) while the weapons CSV (`zm_levelcommon_weapons.csv`, both columns) and every GSC name take the RUNTIME name (`t9_amp63_rdw_up`). A CSV `upgrade_name` that keeps `_zm` resolves to nothing at init → the map fastfile loads (`XZONE_LOADED`), then `Unloading assets from fastfile … creating default assets stubs` → `AddUsermap: none` → silently back to the frontend, no script error, no dump. Precedent in-repo: the combat knife (`t9_me_knife_american_zm` in the zone, `t9_me_knife_american` in the CSV). **The same rule governs GDT weapon REFERENCES** (`DualWieldWeapon`, `altWeapon`, `parentWeaponName`…): the engine appends `_zm` to the referenced name itself, so a reference that keeps `_zm` resolves to `<name>_zm_zm` → `Com_ERROR: could not find alt dualwield '<x>_zm_zm' for attachment '<y>_zm'` and the same silent abort-to-frontend (tod 2026-08-23, the AMP63 whose PaP is a dual-wield PAIR: zone BOTH halves — `_rdw_up_zm` and `_ldw_up_zm` — and point both `DualWieldWeapon` fields at the runtime names). Such fixes land in the INSTALL-SIDE GDT (tools root `source_data\`), which a Mod Tools verify silently reverts — keep a `.orig` and note it in the zone. Diagnose with the GAME-root `console_mp.log` (truncated on every launch — read it before relaunching): `XZONE_LOADED` → `Com_ERROR …` → `ShutdownGame` → `Unloading assets … default assets stubs` → `AddUsermap: none`. PaP base lookup: `zm_weapons::get_base_weapon(weapon)` (table-driven; note `weapon.rootWeapon.name` KEEPS the `_upgraded` suffix — don't use it for base lookup).
- **Clientfields (the ONLY server→client HUD channel):** `clientfield::register(str_type, str_name, n_version, n_bits, str_format_type)` in `init()` on the server. `str_type` scope: `"toplayer"` (per-player), `"allplayers"` (broadcast), `"world"`, `"clientuimodel"` (HUD binding). `n_bits` sizes the value (1=bool, 7=0-127). Format `"int"/"float"/"counter"`. Set with `self clientfield::set_to_player("name", value)`; read in `.csc` (or LUI via UIModel bindings). Pattern: `_acc_lui.gsc` (registers the `"clientuimodel"` HUD fields in both VMs). Note: `_acc_data_shards.gsc` is NOT an example — its old GSC-only `clientfield::register` was a map-load crash (stock registers every `"toplayer"` field in BOTH VMs) and was replaced by a server-side hudelem (reconciled to code 2026-07-11).
- **Zombies-per-round (`level.max_zombie_func`):** stock resolves the final count via `n = [[ level.max_zombie_func ]]( n_max, n_round )`. To retune, **save** the previous pointer, install your wrapper, and **delegate** to the saved pointer (preserve stock behavior), *then* multiply/cap — don't replace it wholesale. Chain it in a `post_zm_main()` (after `zm_usermap::main()`, still inside entry `main()`) so it's live before round 1. Pattern: `_acc_early_round_pacing.gsc`.
- **Zones:** `level.zones[name].volumes` (info_volume ents); `player IsTouching(volume)` tests occupancy.
- **HUD (raw hudelems, when not using a LUI kit):** `player hud::createFontString(font, scale)` (needs `#using scripts\shared\hud_util_shared`); `elem hud::setPoint("TOP_RIGHT", "TOP_RIGHT", x, y)` (underscored point names — `"BOTTOMLEFT"` silently anchors center). `elem SetText("DMG " + n)` accepts concatenated strings; `SetValue(n)` for numbers. Through-walls world marker: a hudelem with `SetShader("white", w, h)` + `SetWaypoint(true)` + `SetTargetEnt(ent)` (`"white"` is the engine built-in, zero asset risk). **`hud::create*` returns undefined on hudelem-pool-full — guard the return.**
- **Custom perk-machine hint** that isn't localized shows the raw `&"TOKEN"`. Quick fix: `trigger SetCursorHint("HINT_NOICON"); trigger SetHintString("raw text")`, re-applied on a loop (the perk think re-sets hints on power changes). Proper fix: a `.str` localize pass.

---

## 6. Model upgrades & the T7-asset carve pipeline

Swapping a placeholder world model for a better-fitting stock BO3 xmodel. Full checklist + the shipped station remodel: `09_boss_items.md`; memory `t7-assets-dump-prop-carving`.

- **Stock xmodels need NO bundling** — they load by NAME from the base game. An upgrade = change the `setmodel()` / `model=` reference (+ its `#precache`) and, if not already present, add an `xmodel,<name>` line to your `.zone`. Build = **`-GscOnly`** (a name swap touches no geometry/BSP/lightmap — **no LED bake**).
- **The build ERRORLOG is the oracle for "does it pack."** A non-packable model logs `xmodel '<name>' is missing` and shows nothing / falls back. **Always confirm a new model in the ERRORLOG before keeping it.** Campaign-only props (many `p7_medical_*`, `*_safehouse_*`, DLC-only) log `is missing` in ZM.
- **THE TRAP: an in-GAME asset catalog (Greyhound, a Zombies session model dump) is NOT the set the LINKER can pack.** The catalog lists models loaded at *runtime*; the linker needs the model's **source asset** in the install's GDT/asset DB. For most catalog models that source is absent → `is missing`. "This whole family (zod/…) packs" is false reasoning — `p7_zm_zod_nitrous_tank` packs because *its* source happens to be installed, not because the family does.

**The escape — carve the model out of the T7 Assets dump into a GDT you own.** The multi-GB "T7 Assets" rip is an on-demand library for ANY stock BO3 prop; two repo tools author a packable GDT straight from the raw `.xmodel_bin`s:
- **`tools/xmodel_bin_inspect.js`** — decode a `.xmodel_bin` (LZ4 block after the `*LZ4*` magic): `--strings` = material names + `color:` hints; `--bounds` = vertex bounds (4-aligned token `83 93 00 00` + 3 floats) so you **size the prop from real geometry**, not by eyeballing.
- **`tools/gen_t7_carve_gdt.js`** — auto-authors the carve GDT from the bins: scans **ALL LODs** (LOD1+ can use materials LOD0 never references), material regex includes **`mtl_`/`t7_`/`sky_`/`global_`** prefixes (the non-`mtl_` trap), skips materials already in the gdtDB (the existing-asset haystack MUST include **`texture_assets\`** — stock materials do NOT live in `source_data\`), emits `BulletCollisionLOD High`.

Carve gotchas (all reusable):
- **Zone-probe first** — some DLC props already pack stock; a `-GscOnly` build with just the `xmodel,` line tells you before you carve anything.
- **Stage in a SHORT path** — the rip's deep folder names blow `MAX_PATH` on Windows.
- **`SetScale` does NOT rescale a `script_model`'s collision** — spawn props at **scale 1.0** so collision == visual, then re-cut collision clips to the new footprint (`tools/add_prop_clips.js`; `brushmodel: true` clips are LED-exempt at any depth).
- **NEVER `SetScale` a live AI / boss reskin — it's a `0xC0000005` CTD.** Reskin a boss with a headless `SetModel` (Detach the charred head, Attach a stock head) at scale 1.0; distinguish it with an eye-tint clientfield + a `.csc` body-glow FX instead of size.
- Register the carved GDT + `model_export` folders in your external-assets manifest + CREDITS (they're game-rip, **not** for redistribution).

**From-scratch props — WORKING, 23 shipped in game 2026-09-06** (Shadowlight Arena: 12 pickups — mag,
horned helmet, shoes, boots, 3 armor tiers, tire, potion, drum mag, lightning bolt, mystery mark — and 11
room-furniture pieces: fireplace, chandelier, lantern, table, stool, bar, bookshelf, barrel, crate, trophy,
portal ring; each solid one backed by a worldspawn `clip` brush since the navmesh ignores entity collision). No rip,
no hand modelling and no third-party service: Blender 5.2 headless builds the mesh + a procedural
material, bakes colour / tangent normal / gloss, writes `XMODEL_EXPORT` v6, `export2bin` →
`.xmodel_bin`, a generated GDT, one `xmodel,` zone line, then a `misc_model` in the `.map` or a
script-spawned pickup. **A prop is ONE Python file**; tools live in test+map: `tools/make_prop.py`
(driver), `tools/prop_lib.py` (geometry + material helpers), `tools/cod_xmodel.py` (writer),
`tools/regen_props_gdt.py` (GDT repair), `tools/props/<prop>.py` (the prop). Detail ceiling is
patience, not the pipeline — the helmet carries dents, rivets, a strap and horns in 21k triangles
with steel/horn/leather masked into one material. **Full playbook** in that repo's
`docs/17_custom_props_pipeline.md`; the facts that were NOT obvious, verified against the install:
- **TRI corners are CLOCKWISE vs the normal** (200/200 on a stock export); Blender is CCW → swap corners 1/2.
- **UV V is flipped** (`v = 1 - v`). `VERT` is position only; normal/colour/UV are per face-corner.
- 1 Blender unit = 1 game unit (player 72). One `tag_origin` bone with an identity block is enough.
- GDT = the carve recipe above (`lit_plus`, `$white_ao`, `$gray_32_one_channel`, `glossRangeMax 13`,
  images `_c` diffuseMap / `_n` normalMap / `_g` glossMap with gloss = 1 − roughness), all four LOD
  slots → the same bin. `BulletCollisionLOD High` → solid with no clip brushes, but the collision
  mesh is **as dense as LOD0** (~27k triangles for a detailed prop). Use `"None"` — the stock
  majority, 2522 uses vs 676 — for pickups, decoration and anything you never shoot; the linker
  lists every offender in `zone_source/all/assetinfo/<map>_bulletreport.csv`, so read that after
  adding props.
- **The linker never refreshes the asset DB** — run `gdtdb.exe /update` (cwd `<tools>\gdtdb`) after
  syncing the GDT; it exits 1 with `Duplicate 'image' asset` noise from other packs. Noise; filter it,
  and run it under `ErrorActionPreference Continue` or its stderr kills the build script.
- **The agent looks at the rendered `preview.png` before building** — that is the self-check,
  but ONLY for silhouette/geometry: emission blows the preview out, and the bake captures
  colour/normal/roughness only, so judge COLOUR from the baked `_images/i_<name>_c.png`.
- **`rstrip("}
")` on a GDT is a trap** — it strips a character SET, so appending a prop ate
  the closing `	}` of the previously-last entry and the linker then reported
  `xmodel '<other prop>' is missing` while its material/image entries were fine. The error
  names the victim, never the writer. Keep a from-scratch GDT regenerator around
  (test+map `tools/regen_props_gdt.py`) and lock the file if props build in parallel.
- **RIGGED custom characters on the stock skeleton** (built 2026-09-06, see test+map
  `docs/18_custom_characters.md`): animations bind by bone NAME, so a mesh skinned to a bit-exact
  copy of the stock zombie skeleton (78 bones, read out of the Mod Tools' own
  `model_export/t7_characters/zombies/zombies/c_zom_der_zombie_body1_lod0.xmodel_bin` with the
  blender-cod PyCoD reader) plays every stock zombie anim. Swap it on at spawn: chain
  `level.zombie_init_done`, wait 0.3 s, `DetachAll(); SetModel(body); self.no_gib = true`. The
  GDT xmodel entry must carry `hitBoxModel xmodel_multiplayer\multiPlayer_HitBoxModelChar.xmodel_bin`
  **and `"type" "animated"`** - without `type animated` the converter emits a RIGID xmesh (vertices
  parented to single bones, no skinning): torso and legs stay stiff while single-bone parts
  move. Offline tell: `share/assetconvert/xmesh/v6/<model>_f0_..._geo_<hash>` = skinned,
  `..._geo_rigid_<hash>` = not. A 14-body bisect cost half a day to learn this; read the cache.
  **`surfaceType` must be a real engine surface** (`flesh`, `cloth`, `metal`...): an unknown one
  (`"bone"`) makes the linker throw a MODAL "SANITY CHECK FAILURE" dialog and the headless build
  hangs until a human clicks it.
- **The same recipe works on ANY stock skeleton** (2026-09-06, test+map roster v2: wolf on the
  hellhound rig, bear on the Panzer rig, robot officer on the SoE Civil Protector rig, witch on the
  Avogadro rig). Dump the rig from the pack's own source (`tools/dump_skeleton.py` SOURCES lists
  the install-side paths; 58 / 255 / 186 / 115 bones), build the body in that rig's bind pose, and
  `SpawnActor(aitype, org, ang, targetname, true)` + `DetachAll(); SetModel(body)` at runtime.
  **Facing differs per rig:** zombie and hellhound bind poses face -y, Panzer / robot / Avogadro
  face +x. Per-AI rules: `level.dog_health` BEFORE the dog SpawnActor; Panzer attacks are removed
  by re-registering the BT script API by name (`mechzShouldShootFlame` -> never); the Avogadro pack
  fires `"avo_send_bolt"` on the actor at release, so a custom projectile is one `waittill`.
  **A bare SpawnActor'd pack AI that "just stands there"** has one of three causes, each already
  solved in a shipped map: (a) the aitype GDT's `defaultGoalRadius` is 2048 (Panzer, SoE robot) so
  every nearby goal is "reached" - set `goalRadius = 64` on the actor; (b) the pack's per-actor setup
  only runs on the spawner path - call it yourself (`mechz_spiki::acc_setup_mechz`,
  `zm_ai_avogadro::avogadro_spawn(boss, true)`); (c) the archetype never hunts or fires on its own
  (companion robot) - drive `favoriteenemy` + `SetGoal` and `MagicBullet(self.weapon, ...)` from script.
  **Fur / spikes:** loose 3D tufts explode the smart-project into ~18k UV islands and the bake
  goes black; attached fringe strips (triangle teeth on a web strip) stay at ~6 islands per loop.
  **The bake atlas is island-count bound, not triangle bound:** Blender `smart_project`'s
  `island_margin=0.015` (SCALED) hands every UV island a ~60 px cell at 2048, so a 1,500-island
  body bakes as dots on black. Use `island_margin=0.005, margin_method='FRACTION'` (~10 px, just
  over the 8 px bake dilation) and keep ornament single-sided / consolidated. Judge from the baked
  `_c.png`, never from a preview that renders the live material.
- **Custom AI animations without Blender** (2026-09-06, test+map `tools/make_anim.py`): stock AI xanims
  are 30 fps, one PART per bone, WORLD-space per frame, closure frame = frame 0 with `tag_origin`
  advanced (root motion -> ground speed via the mocomp; measure the stock speed with PyCoD
  `LoadFile_Bin` and match it or the AI skates). Plug in by copying the aitype's `.ai_am` alias table
  under `usermaps/<map>/animtables/` - the usermap copy SHADOWS share/raw at link time (the `.deps`
  records which path won) - and re-pointing the locomotion aliases. Two enemies on one aitype share a
  table: give one a full aitype block copy in your own GDT (derived `[ "parent" ]` entries cannot
  cross GDT files) with its own `animMappingTableName`.
- **Hovering / spinning / glowing pick-up drops** (proven same day): `script_model` +
  `RotateYaw(360, t)` loop + eased `MoveZ(±amp, t, t/2, t/2)` loop run TOGETHER on one
  entity; glow = the stock powerup FX (`level._effect["powerup_on" | "_solo" | "_caution"
  | "_red"]` — four colours free, a rarity palette) via `PlayFXOnTag`; pickup =
  `trigger_radius_use` with ONE constant hint. A from-scratch prop's origin is its FLOOR
  point, so play the glow on a `tag_origin` helper `LinkTo`'d at half the model height or
  it hangs under the item. See test+map `_sla_items.gsc`.
- In scope hands-off: hard-surface props (crates, mags, helmets, balls, altars, machines) with baked
  procedural textures and rigged bodies on any stock skeleton. Out: viewmodel weapons with anims
  and custom animations (keep porting those).

---

## 7. Dev/test mode (ONE hardcoded flag, not a console)

Bake the whole test sandbox behind **a single flag resolved once at map init into a global bool** — not a pile of per-feature dvars, and never a runtime console the user has to poke. In this repo: `acc_resolve_dev_flags()` (first thing in entry `main()`) hardcodes **`level.acc_dev`** as a **compile-time boolean** (ship = `level.acc_dev = false;`; arming a test session = flip it to `= true;` + rebuild — there is NO dvar/launch-flag path since 2026-07-16, and the launch scripts pass engine args only) and drives the legacy sub-dvars off that one flag. To add a dev behavior, branch on `IS_TRUE(level.acc_dev)` and hardcode the value — never introduce a new toggle. **Never tell the user to "set dvar X in the console" to test something.**

**Put proof-of-life in the ENTRY script `main()`** — it provably runs (the map loads) independent of any module init, so a banner/effect there isolates "build live?" from "module init failed?". Set `level.acc_init_complete = true` at the end of your orchestrator `init()` and show it in the entry banner to distinguish "module chain finished" from "a module init threw."

Reusable dev behaviors (all gated on `level.acc_dev`):
- **Unlimited money:** loop, `if cur < floor: player zm_score::add_to_player_score(target - cur)`.
- **Unlimited shards / currency:** loop, top up your custom counter via its grant fn (clamps + syncs HUD).
- **Auto-power:** `if !(level flag::get("power_on")) level flag::set("power_on")` after `initial_blackscreen_passed` — perks/PaP/traps all gate on it.
- **Open the whole map:** for each `zombie_door` trigger, `flag::set(door.script_flag)` (guard with `flag::exists`), then on the slab do `ConnectPaths(); NotSolid(); Hide();`, then `door TriggerEnable(false)`. Walk everywhere from spawn.
- **Damage indicators:** register a read-only `zm::register_actor_damage_callback` (returns `-1`), accumulate per-player DPS, render to a HUD on a 0.2s loop.
- **Zone signage:** poll `player IsTouching` each `level.zones[z].volumes`; on change, set a top HUD + `IPrintLnBold` with the zone's display name.
- **Disable lethal hazards for free-roam:** a decontamination/zone-seal that `DoDamage`s players will kill you on an open map. Gate it off in dev; still emit any "complete" notifies downstream systems depend on.
- **Test boss on demand:** spawn a buffed normal zombie early (**announce it** with `IPrintLnBold` — it looks normal), drop reward currency in bulk on its death. (Portable technique for a NEW map's bring-up — THIS map deleted its early test spawns 2026-07-16; dev here runs the real boss cadence.)

---

## 8. Verification & debugging

- **`console_mp.log`** (`<game>\console_mp.log`, needs `+set logfile 1`) is the runtime oracle. The **last** lines are the fatal error. The wall of "Could not find material/fx" (margwa/mech/DLC/`*_zm` weapon-table entries) is **normal usermap asset noise**, not the failure. `abort_on_error TRUE` (dev mode) makes any script runtime error fatal — so a *clean load* proves every init ran without throwing. (On some boxes the logfile writes nothing — fall back to persistent on-screen dev-HUD probes; a `Com_ERROR` leaves no Windows Event either.)
- **Runtime traps that pass build+lint then throw:** `string/entity == undefined` throws (guard with `isdefined`); no bare `getdvar` (use `getdvarstring(name, default)`); a `SpawnActor`'d custom aitype needs `ArchetypeZombieBlackboardInit` to locomote; `spawn_zombie` / `hud::create*` return undefined on pool-full — guard EVERY return.
- **Lints (run before every build):** `node tools/lint_gsc_xref.js` (xref/#using/macro/paren-field) + `tools/preflight_windows.ps1` (brace/paren balance, `#namespace` order, ternary paren-wrap, reserved keywords, zone↔module consistency, LF endings, install detection, `validate_rooms.js`).
- **Adversarial pipeline audits** were decisive for the stale-deploy bug — when "the code looks right but behaves wrong," an independent audit of the *pipeline/deploy* (not just the code) finds it.

---

## 9. Gotchas catalog (every trap we hit)

| Symptom | Cause | Fix |
|---|---|---|
| "changed code, nothing changed in game" | linker built the un-synced **deployed** copy | sync before every build |
| black screen, log ends `tdm.gsc` | `g_gametype` reset to MP default | `+set_gametype zclassic` |
| black screen, doubled command line | Steam Launch Options appended | empty Launch Options |
| "Steam must be running" popup, exits | raw-exe DRM | `steam_appid.txt` + launch via Steam |
| nothing opens, no log/dump | split-install, `.ff` in tools not game | usermaps junction |
| game won't launch via automation | Steam launch-handler jam from force-kills | restart Steam |
| link error `skybox_mp_havoc_override missing` | template `volume_sun` MP sky | set `ssi*` to `default_day` |
| LED bake hangs 200s, no `.led`, `brush.cpp:1860` | lightmap-atlas overflow (unpacked placeholder UVs) | stay under the surface budget (the map bakes today); crisis-only fallback = `-SkipLED` + scripted fog (§1) |
| world renders fullbright white | `.led` deleted / missing | keep a lightmap (the shipped path); crisis-only fallback = scripted-fog dark look (§1) |
| `xmodel '<name>' is missing` | catalog model's source not in the install DB | carve it (`gen_t7_carve_gdt.js`) or pick a packable one (§6) |
| AI/boss CTD `0xC0000005` on spawn | `SetScale` on a live actor | never SetScale AI; reskin via `SetModel` + eye-tint |
| door slab floats above the gap / drops through floor | wrong inverse op (map force-opened *in place* vs stock *moved*) | match the close op to how it opened (§4) |
| random death mid-roam | decontamination/zone-seal `DoDamage` | gate behind a disable flag for testing |
| AI below z=-1000 silently dies ~30s in (movement irrelevant) | stock `round_spawn_failsafe` rides EVERY zombie-spawner spawn (`_zm_gametype.gsc:909` spawn function); its below-world branch (`zombie_utility.gsc:1857`) `DoDamage`-kills any actor under `zombie_vars["below_world_check"]` (-1000) each 30s tick | playable space below -1000 → move the var under the deepest floor (one live-read write in any post-`zm::main` init, e.g. `level.zombie_vars["below_world_check"] = -2000;`); per-actor `ignore_round_spawn_failsafe = true` also covers the moved<24u branch |
| perk machine shows `ZOMBIE_PERK_TOKEN` | unlocalized hint istring | `SetHintString` override / `.str` |
| `Primitive expression field object...` | `.field` on parenthesized expr | temp var |
| `unexpected TOKEN_USING` | `#using` after `#namespace` | `#namespace` last |
| `unexpected TOKEN_CONDITIONAL` | ternary not fully paren-wrapped | `( cond ? a : b )` |
| god mode / damage effects stop working | a player-damage callback `return`ed a value ≠ `-1` | read-only hooks must `return -1` |
| gdtdb `GDT ParseError … Unknown token` on a `//` line, then linker `Object reference not set` on every weapon field | a `.gdt` tolerates NO comment lines (the asset DB parser has no comment syntax) — the entry is dropped and the linker links a null weapon | keep the commentary in the generator script / doc; the `.gdt` is `{ "name" ( "x.gdf" ) { fields } }` only |
| a custom / ported gun takes no attachments — `GetWeapon(name,[att])` returns the BARE gun (`weapon.attachments.size` 0) | it has no `au_<attachmentUnique base>_<type>` attachment-unique assets the engine can find. Known-good on a projectile weapon: `attachmentUnique` = runtime name + one `au_<name>_<type>` (`attachmentunique.gdf`, clone `au_smg_standard_none`) per type, zone `attachment,<type>` + `attachmentunique,<au>`. A Skye-ported BULLET weapon with the same wiring still took nothing; suspect its `acv_<type>` cosmetic-variant refs to stock assets not in the fastfile (being tested, sla 2026-09-06). Judge by `attachments.size` and the variant’s stats — `supportedAttachments` can read empty on a working gun | set `attachmentUnique`, declare the `au_` uniques, blank the port’s `acv_*` fields, rebuild |

---

## 10. Repo tooling (portable scripts)

- `tools/build_map.ps1` — one-command headless build (`-GscOnly` fast path, `-Run` to launch, `-SkipLED` is a RED FLAG).
- `tools/_bake_test.ps1` — fast LED gate (cod2map + LED, prints BAKED / CRASHED).
- `tools/sync_to_modtools.ps1` — repo ↔ Mod Tools mirror; auto-creates the junction + `steam_appid.txt` on split installs. `-Reverse` pulls `.map` edits back.
- `tools/preflight_windows.ps1` — ~25 readiness checks (run any time).
- `tools/lint_gsc_xref.js` — static GSC cross-reference/dialect lint.
- `tools/validate_rooms.js` — asserts every duplicated room-footprint copy agrees with `source_data/rooms.json`.
- `tools/run_game.ps1` / `PLAY_NORMAL.bat` — DRM-safe launch (the canonical command).
- `tools/check_external_assets.ps1` — must be all-green before a build (game-rip packs aren't in git).
- Model carve: `tools/xmodel_bin_inspect.js`, `tools/gen_t7_carve_gdt.js`, `tools/add_prop_clips.js` (§6).
- From-scratch props (Blender headless → xmodel → GDT): `tools/make_prop.py`, `tools/cod_xmodel.py`, `tools/props/*.py` in test+map (§6).
- Atmosphere: `tools/gen_reflection_probes.js`, `tools/gen_neon_lights.js`.
- Local stock-scripts mirror (agents/greps depend on it):
  `git clone --depth 1 https://github.com/zeroy99/bo3_modtools tmp/bo3_stock_ref`
- Ground-truth sources (public GitHub, verified 2026-06): pristine zm template `FanaticSoftware/Skye-Weapon-Templates` → `rex/templates/01. ZM - Base/`; shipped map w/ source `MattFiler/zm_alien_isolation`; stock GDTs `shidouri/T7-GDT-Backup`. Drop-in kits catalogued in `16_community_techniques.md`.

## 11. Presentation assets (map card / Workshop thumbnail / loading screen)

Verified 2026-07-18 against the Launcher templates, the 7 Workshop maps installed on this box, and
the decompiled retail LUI (`KingslayerKyle/T7LuaRepo`, `Dumps/PC_Ship_2025-05-31/`). **Portable —
applies to any BO3 usermap.**

**All of these are LOOSE FILES in `usermaps\<map>\zone\`. None is a fastfile asset:** no `.zone`
line, no GDT, no material, no rebuild. Edit → sync → republish. (Corollary: `zone\` is uploaded to
subscribers **verbatim** — anything parked there ships, including junk. Gate it.)

| Surface | File | Spec |
|---|---|---|
| Steam Workshop web thumbnail | any path you point `workshop.json` `"Thumbnail"` at | square, 512×512; **must be an ABSOLUTE path** |
| In-game map card (map-select, bottom-left) | `zone\previewimage.png` | **600×340** (both ZM and MP Launcher templates ship exactly this) |
| In-game loading screen | — | **not achievable for a usermap** |

**Don't let one file serve two surfaces.** `workshop.json`'s `Thumbnail` accepts any absolute path
anywhere on disk, so give Steam its own square file (e.g. `zone\workshopimage.png`) and leave
`previewimage.png` at 600×340 for the in-game card. Pointing `Thumbnail` at `previewimage.png` and
then resizing it for Steam silently stretches the in-game card.

**Map card mechanism:** `ui/uieditor/modifyFunctions.lua:1519` — `MapNameToMapImage()` calls
`CoD.GetMapValue(map, "previewImage", "$black")`. A usermap is in no stock maptable → returns
`$black` → engine falls through to `Engine.UpdateModPreviewImage(<ugcName>)`, repointing the fixed
`img_t7_mod_preview` slot at that map's art. Non-600×340 renders stretched, not broken.

**Loading screen: `zone\loadingimage.png` IS INERT — do not waste a day on it.** It exists in every
template, ships in every published item, and does nothing. Evidence: (1) `MapNameToMapLoadingImage()`
short-circuits `if Engine.IsUsingUsermap() then return "img_t7_mod_loading"` and **no
`Engine.UpdateModLoadingImage` exists anywhere in the LUI** — the preview slot has a per-map engine
refresh, the loading slot does not; (2) the file is byte-identical (md5 `f4536617…`) across the ZM
template, the MP template, and multiple shipped third-party maps — nobody has ever successfully
changed it; (3) zero hits for `loadingimage` in any tools binary (ASCII **and** UTF-16); (4)
Treyarch put all 41 loadscreen images in `core_patch.ff`, not in map fastfiles, and a usermap's
linker `.deps` says `ignore,core_patch`. Overriding it requires a separate `core_mod.ff` product
that replaces the loading screen for *every* map the subscriber plays — not shippable with a map.

**The supported alternative — a loading MOVIE (SOLO ONLY):** `ui_mp/T6/HUD/Loading.lua:391-395`
has a usermap-only branch calling `Engine.StartLoadingCinematic(Engine.GetCurrentMap() .. "_load")`.
Ship `zone\video\<mapname>_load.mkv` — H.264, 720p30, **all audio tracks stripped**, HandBrake
**v1.0.3** (newer reportedly crashes). No `.zone` line, no script. Shipped precedent:
`MattFiler/zm_alien_isolation`. ⚠️ Gated `GetLobbyClientCount(LOBBY_TYPE_GAME) <= 1` — **co-op
players get nothing**. ⚠️ Unverified whether the Launcher's publisher uploads `zone\video\` at all.

**Method note:** the repo's `tools/ff_grep.js` inflates T7 fastfile block chains and makes **stock
LUI greppable** — the Mod Tools ship zero stock `.lua`, so this is the only way to read the real
UI code. The LUI-bearing fastfiles are `core_patch.ff` (richest — holds `modifyFunctions` +
`Loading`), `core_ui.ff`, `core_frontend.ff`, `core_frontend_patch.ff`. Note `BlackOps3.exe` and
`linker_modtools.exe` are Arxan-packed, so string analysis of them proves nothing in either
direction.

## Weapon-price registry is separate from weapon asset registrations (Tower, 2026-09-08)

A fresh fastfile and a passing weapon asset ledger do not establish a booting
match. Stock CSC `_zm_weapons::include_weapon` stores one `level.weapon_costs`
entry per distinct weapon-name string, including upgraded names from the CSV.
`on_player_connect` calls native SetWeaponCosts for each one. Tower's 304 keys
produced 43 `Too many weapon costs added to weapon cost list` script exceptions
at match startup even though the map packed only 235 authored weapon assets.
Unused stock CSV rows count too. Removing 33 unobtainable stock gun rows reduced
the table to 238 keys while preserving all 95 generated PaP mappings. The new
240-key build budget leaves room for script/stock additions; it is conservative,
not proof of the native limit. Count BOTH name columns and deduplicate exact
keys. Check before generator outputs are written and on every build. Native
boot verification of the correction is still pending as of this entry.

Follow-up 2026-09-09: the user resumed play on the unchanged build. These cost
exceptions therefore do not establish the cause of the original load stall.
The table cleanup is still pending rebuild and runtime verification.
