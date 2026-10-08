# Thunder Smash

Requested September 21, 2026. The upgrade unlocks tactical / LB for tier-three
Slasher while holding Stormbreaker. Three levels: 45 / 35 / 25 seconds. No
automatic grant, no dark form. Domain 58, gun scope, band A, tier minimum 3.
The locked tile, cooldown border and binding-aware first-three-use tutorial
reuse the Mage ability layout. UI art is requested in docs/152; the HUD uses
the map's own `SM` letter glyphs until the icon arrives. No unzoned image name
or card slug is installed. Pause plate ceiling is 57 after Rapid Flame arrived; 58 awaits Thunder Smash art.

Hellbound's gold-sword movement is copied from `_tod_gold_sword.gsc` functions
`arc_position`, `arc_path_clear`, `try_smash_arc`, `update_smash_arc`: 56-unit
height, up to 128-unit travel, 750 ms flight, floor and body-corridor traces,
128/64/0 fallback distances. Unsupported ledges refuse the hop. Engine player
collision remains active; a blocked/displaced arc releases velocity control.
Athlete yields during this cast. No gravity or view-angle override.

The bat's existing melee_in / melee_out clips are fitted to Stormbreaker's
right-wrist grip, with entry/recovery blends to the existing hammer idle.
63 frames at 30 fps; impact at 967 ms, recovery at 2100 ms. A temporary gmod7
attachment changes firstRaise on all 13 existing hammer roots. No additional
weapon registrations (ledger still 237). Neutral attachment fields explicitly
carry the hammer's location multipliers and zero range overrides, avoiding the
attachment GDF's surprising default damage values. Generator:
`tools/build_thunder_smash.py`; hashes/timing: `thunder_smash_manifest.json`.
The bat's bones and hammer grip are measured offline; how it looks in the game
is still UNPLAYED. It does not change the normal hammer swing or knife speed.

Impact uses the Gravity Spikes ground hit, electrical burst, Thor sky strike,
six nearby strikes and at most eight victim shock effects, plus the existing
clap/storm/zap sounds. Ordinary zombies in visible 300-unit range are killed;
elites use normal round zombie health times two per card level, with sprinter
armor retained. Same-frame attacker-scoped markers bypass attacker multipliers
and the Panzer's stock rejection of script hits. No Thor/Cleave recursion,
global Gravity Spikes callback override or physics launch of bosses.

The server owns cooldown and HUD progress. Upgrade pauses freeze cooldown;
held input from a menu does not queue a cast. Grenade throws cancel the cast as well. Cancellation before impact
refunds cooldown; cancellation afterward spends it. A level-owned cast uses
an operation token and spawn identity to release controls and restore only
its own inventory. PaP/knife-speed form, camo, clip and stock are preserved.
Missing attachment lookup refuses before removing anything. Tactical ammo is
reserved while this ability owns LB, with refill preservation; lethal ammo is
unchanged. The normal class roster supplies no tactical to Slasher.

Diagnostics: `[TOD_THUNDER_SMASH]` INIT, STATE, START, DENIED, ARC_START/APEX/LANDED/
RELEASE/SKIP, IMPACT and END. IDs correlate motion, hits, refund and cleanup.
They run with dev mode and temporarily with `TOD_SMASH_LOG=1` in normal user
playtests; zero this temporary switch before publishing. Native log output and
visual/movement behavior require the user's match. Never launch to verify it.
Archive that match via `tools/capture_ai_logs.ps1` before reading console_mp.log.

Offline checks: `test_thunder_smash.js` runs the actual GSC state/inventory and
target/damage code with native mocks; `verify_thunder_smash.py` checks hashes,
63 finite frames, wrist grip, neutral fields, all 13 forms and zone closure;
both gate every build. `test_thunder_smash.lua` runs the actual HUD setters in
Lua 5.1, including the whole widget's closure compilation. Existing staff,
no-optics, bat, damage guard and Mage raise/HUD checks also pass.

Full build verified 2026-09-21 11:19:36 Eastern: FF 146,475,776 bytes; all 297 source/deployed hashes match, none newer than the FF; gmod7, both attachments, cast clip and Gravity Spikes FX are linked; complete 207,523,840-byte sound bank. Evidence: tmp/thunder_smash_20260921/build_final.log and deployment.json. No game launch; native playtest pending.

Deployment check caught that gmod5 is a gadget-only table entry, with no normal
attachment asset in gdtdb or the output ledger. Use gmod7: its native fields
match the already proven gmod6 exactly except name/type/displayName. The
explicit attachment must appear in the final asset ledger, alongside its AU.

## September 21 native failure and correction

User reported no animation and no LB indicator. Archived live log:
`tmp/thunder_smash_fix_20260921/runs/20260921_125647_947_eafab465/console_mp.log`.
It proves STATE 2 / rank 3 (the upgrade WAS owned), 26 missing_cast_asset denials,
and repeated `LUI event name (string) is not precached` errors. No cast started.

Three native contracts were wrong in the first implementation:
- `attachmentUnique` is the FULL base, including `au_`. Native examples in the
  installed DB are `ar_standard_upgraded_companion_zm -> au_ar_standard` and
  `sla_enfield -> au_sla_enfield`. `tod_thunder_smash` did not connect the hammer
  to `au_tod_thunder_smash_gmod7`, even though both assets were individually
  zoned. All 13 hammer variants now use `au_tod_thunder_smash`. The same defect
  existed in the three staff PaP sources/eight variants; those now use
  `au_tod_staff_<element>`. All other weapon fields are byte-value identical.
- LUI notification names require `#precache("eventstring", ...)` in BO3.
  `lui_notify_event` compiled but never registered this event.
- Argument 2 of LuiNotifyEvent is the DATA COUNT: send `3, code, percent, seconds`.
  The old call put the state there. Fixing precache alone would leave a malformed
  payload. `send_hud` and its test now enforce both parts of the native contract.

Cast validation uses the documented WeaponHasAttachment query. Failed lookups
now record resolved name and native attachment result. `bound_hop_2` INIT,
EQUIPPED and `[TOD_THUNDER_SMASH_HUD]` state logs distinguish resolution,
first-raise selection and HUD receipt on the next user test. The peer's LoadFX
boot fix is retained. The game was running during investigation; it exited
before this full build began. Never launch on the user's behalf.

The native mock now reads the emitted attachment base and resolves against
actual AU names; it reproduces the old missing-prefix denial. Registration and
payload-count negative controls reject the old HUD mistakes. Both presentation
asset gates verify exact base-plus-suffix resolution, beyond mere zone presence.
State/animation, Lua 5.1 Mage/Smash HUD, staff presentation, optics and arity
checks pass. Full fix build verified 2026-09-21 13:18:44 Eastern: FF 147,129,600 bytes; all 297 deployed inputs match source and predate the FF; complete 207,523,840-byte sound bank. All 21 native hammer/staff attachment bases resolve. Evidence: tmp/thunder_smash_fix_20260921/build.log, deployment.json, native_bindings.json and fix_scope.json. No game launch; user retest pending.

## Second native failure: the missing linker steps

The 13:30 user capture (`tmp/thunder_smash_fix2_20260921/runs/20260921_133031_185_dd71b7b5/console_mp.log`)
loads bound_hop_2, owns rank 3 and records 26 missing_cast_asset denials with
native_gmod7=0. No START, EQUIPPED or IMPACT occurred. No unprecached LUI errors
remain. This disproves the previous claim that source DB binding resolution
established a usable native attachment.

[The original Modme guide](https://github.com/dtzxporter/ModmeWiki/blob/master/wiki/black_ops_3/guides/Setting-Up-Weapon-Attachments.md)
and the local test-map September 6 attachment investigation document three
requirements: full AU base, weaponfull loading and attachment mapping rows.
The last two were absent here. Generator emits weaponfull for the 21 roots.
Sync runs verify_weapon_attachments.py --install, merging only this map's exact
runtime-name families into share/raw/gamedata/weapons/common/attachmentmappingsTable.csv.
It saves the previous file beside it and preserves every unrelated row byte for
byte. This is a linker input; no runtime stringtable replacement is zoned.
Only gmod7 (hammer) or gmod6 (staff) is permitted on these rows.

The same-frame cast switch could also be swallowed, as the Mage first-raise
code already documents. Cast setup now waits a frame then retries up to ten
frames; ordinary return also waits after its take/give. Ownership/life checks
remain in force, including across waits. INIT bound_hop_3 and EQUIPPED logs
identify the revision, actual native attachment and equip delay; the named
first-raise clip in that log is the EXPECTED clip, not proof of rendering.
The tactical border fills while casting using server animation elapsed time,
then returns to cooldown progress and seconds. No extra UI elements or art.

Checks cover actual weaponfull zone names, exact AU resolution, ignoreAttachments,
mapping preservation/idempotence, native source event registration/count,
26 weapon/ammo combinations, delayed equips, failed-equip timeout/refund,
input/menu handling, damage, aborts and Lua states. Existing staff/Mage/optic
checks remain active. The entire generated weapon GDT is byte-identical to
before this correction; no new weapon registrations or balance changes.
Full build pending. User tests; no game launch.

Build/deployment follow-up: full build passed at 20:42:03 Eastern (FF
147,130,624 bytes). A peer changed only the Mage tier damage multipliers after
that build and began a script rebuild. Its 20:50:33 package carries the same
Thunder Smash fix plus that change; combined_deployment.json verifies all 297
current inputs, no newer deployed inputs, complete 207,523,840-byte bank.
linked_dependencies.json verifies ALL 13 hammer weaponfull nodes actually depend
on gmod7 and both AUs, and the cast AU depends on tod_thunder_smash_cast.
This is stronger than the previous GDT-database-only check. The right wrist
moves 33.64 units from its starting pose and the hammer tag 36.55 (motion_check.json),
so the accepted clip is not static. Actual in-game playback remains untested.

Do not generalize that dependency result to the staffs: projectile weaponfull
nodes read the mapping table but list no AU dependency. Their native PaP
presentation still requires the user's test; no assertion of success is made.

User reported downloaded assets during the build. make_art_pack.ps1 -Inspect
found only the already-installed Rapid Flame set in the newest returned ZIP,
files - 2026-09-21T115409.834.zip. Scanning Downloads ZIP entry names found no
returned Thunder Smash PNGs. Asked for filename/path; no art installed or
replaced. The SM glyph fallback remains while the download is unresolved.

Final recheck after the peer build process exited: combined_deployment.json and
linked_dependencies.json both pass unchanged. No game/build processes remain.
Ready for the user's Thunder Smash retest; returned artwork still needs its path.

## 2026-09-23: the FOURTH requirement, found on the staffs

"ALL THREE" above was necessary and still not sufficient. The staffs had all
three and the linker's own `.deps` file showed every `weaponfull,tod_staff_*`
reading the mapping table and pulling nothing, while every
`weaponfull,leviathan*_zm` pulled its gmod7 attachment and both uniques. The
difference is the asset name's game-mode tail: the linker derives the
mapping-table key from it, and the staffs were the map's only weapons named
without `_zm`. Stock connects gmod uniques to `_mp`/`_zm`-named projectile
weapons (launchers, crossbow, discgun), so the GDF type is not the gate. Fixed
in v19.41 by emitting `tod_staff_<el><suffix>_zm` (docs/150 status section).
The hammer never needed this because its forms already carried `_zm`; its
runtime cast remains unproven (no archived run ever cast after bound_hop_3).
