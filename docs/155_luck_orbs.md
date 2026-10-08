# Luck sources and homing souls

2026-09-22. User requested an orb from every luck source to its recipient,
with luck awarded on contact. Panzer luck stays killer-only (explicit reply).
2026-09-23 retest: user confirmed the orbs are visible and requested enemy orbs
only for elites/Panzers. Ordinary zombie and headshot rewards now pay directly;
door, revive and duplicate-pickup souls keep their existing delivery behavior.

## Complete source audit

These are the live positive paths in `_tod_luck.gsc`, before gain-rate bonuses.
All enter `add`, which applies the gain-rate bonus once. Ordinary zombie and
headshot rewards immediately call `set_bar`; all other rewards enter
`tod_luck_orbs::emit` and pay through `orb_received -> set_bar` on contact.

| Source | Base luck | Recipient and location |
| --- | --- | --- |
| Ordinary zombie kill | `18 * players / round_zombie_total` | Killing player; immediate, no orb |
| Headshot kill, including helmet/neck | Above kill value x1.5 | Killing player; immediate, no orb |
| Rogue Protector | 4 | Killing player; corpse +40 Z |
| Reaver/Fury | 6 | Killing player; corpse +40 Z |
| Elite Hellhound | 3 | Killing player; corpse +40 Z |
| Armored Sprinter | 4 elite bonus | Killing player; corpse +40 Z; normal zombie-death component is immediate, only the elite bonus has an orb |
| Panzer, including Spire guards/Trial Wardens/King | 20 | Killing player; last corpse position +40 Z |
| Purchased tower door (lap, roof, power, teleport bay) | 10 | Buyer; generated `d.tod_org`, never the brush entity's unusable origin |
| Reviving another player | 15 | Reviver; revived teammate +32 Z |
| Duplicate free PaP drop | 20 | Grabber; pickup origin; only the existing no-packable-primary/held-weapon consolation branch |
| Duplicate perk bottle | 10 | Grabber; pickup origin; existing random-map-perk helper returns undefined |

Ordinary kill values gain **4% of the base rate per round above 15**, linearly:
`1 + 0.04 * (round - 15)`. The LUCK card increases **all positive sources** by
`1 + 0.10 * luck_level`. Both are fixed when the reward is generated, not
recomputed in flight. The LUCK card itself changes a rate; it is not a direct
bar grant. Existing normalization uses the published round rate.

The perk fallback also covers a player at their current perk-slot cap, even if
not all nine map perks are owned: the existing helper returns undefined for
either condition. This change preserves that behavior and its ammo consolation.

Separate Spire door buys do **not** currently award luck (`spire_door_buy` has
no luck call). Trial/King victory purses, extraction, normal perk/PaP purchases,
loose change and ordinary powerups have no direct luck grant. They gain none
from this change. A Panzer's shared points are separate from its personal luck.

Going down still immediately subtracts 15. Card deals still consume the bar;
the existing 150 true cap / 100 visible cap, rarity rules and overcharge remain.
The retired Rampage party drain remains disabled.

## Delivery and limits

`_tod_luck_orbs.gsc` is a leaf module initialized by luck with its arrival
callback. It uses a non-solid `tag_origin` mover and native looping
`tod/fx_luck_soul`; it adds no clientfields or weapon assets. All players can
see souls, but only the fixed owner receives the reward. Kill confirmations,
points, mana and other kill bonuses retain their existing timing.

The later sound trial below removes the Apex ding from both headshot and elite
luck events. The red elite marker still appears immediately on the kill.

The installed Origins `dlc5/zmb_weapon/fx_staff_charge_souls` supplies the gold
trail and core. `tools/gen_luck_orb_fx.py` keeps two looping emitters, reduces
size/lifetime/emission, and removes one-shot flashes, smoke and collision.
The generated effect is in `share/raw/fx/tod/fx_luck_soul.efx`. A one-frame host
settle precedes FX attachment. A small initial lift and a minimum visible life
make nearby door buys/melee kills readable. The target is the owner's eye
position minus 18 Z. Credit requires the actual mover to be within 12 units;
neither a MoveTo request, a timeout, nor spawn failure grants luck.

Travel retargets every 50ms and accelerates with age/distance, including after
a player teleports. Rewards hold through death until respawn. Downed living
owners can receive them. World card pauses, frozen player menus and live-world
co-op altar picks park active FX and hold pending rewards until the old bar has
been consumed. Those orbs then contribute to the next bar. A newly arrived
reward never retroactively improves cards already rolled.

At most six movers per player / 24 for a four-player party. Each player has a
64-entry pending queue. Beyond that exceptional backlog, incoming value merges
into the last queued orb; its source position stays that queued source's
position, and the MERGE log identifies added sources. No fractional value is
discarded. Normal bursts remain individual orbs. Missing hosts retry, with
allocation failures throttled to once a second. Disconnect/end-game cancels
owned pending value and deletes hosts; entity-slot reuse starts a fresh queue.

Elite death handlers preserve a small position record at 100ms intervals while
alive, ending on death/shutdown/game end. They use the exact death origin if it
still exists, else the cached position. Panzer already has its own lifetime
position cache. Pickup callbacks copy their origin before stock consumes them.

## Origins Soul Box sound trial (2026-09-22)

User requested the whole sound pack and removal of the Apex ding, then chose
**include all eight; play only the soul/collection sounds**. Both downloaded
Fanatic v1.0.0 archives contain matching FX/scripts/audio aliases. Their
`fx_staff_charge_souls` is byte-identical to our installed visual donor.

`tools/import_luck_orb_audio.py` copies all eight original WAVs unchanged into
`sound_assets/tod/luck/`. Hashes, source members, lengths and credits are in
`docs/luck_orb_audio_manifest.json`. Build checks use these frozen inputs,
without requiring Downloads or re-extracting the archive. Credits: Fanatic,
Scobalula, HarryBo21, Treyarch; recorded in CREDITS.md.

| Sound in pack | Duration | Trial use |
| --- | ---: | --- |
| `evt_souls_flush` | 1.173 s | Release at the orb; 3D |
| `evt_souls_full_loop` | 1.831 s loop | Travel on the moving orb; 3D |
| `evt_tube_stop` | 0.971 s | Arrival, only to the recipient, after luck credit |
| `evt_souls_full` | 4.257 s | Crossing 100 luck, replacing the tenth pip |
| `challenge_box_open` | 3.565 s | Included, inactive |
| `challenge_box_close_r3` | 2.546 s | Included, inactive |
| `challenge_box_fire_r3` | 4.992 s loop | Included, inactive |
| `disappear` | 4.944 s | Included, inactive |

Tower-owned aliases use softer volumes (release 72, travel 58, arrival 76,
completion 78), with per-owner release/arrival intervals of 200/150 ms.
Native travel aliases allow four simultaneous voices total. Gameplay still
pays every orb; these limits apply only to sound. Release starts after the
host settles, at most once per reward, including pause/death/host recreation.
The travel loop explicitly stops before every normal host deletion: arrival,
menu/death hold, disconnect, end-game and owner replacement. Resuming a held
orb restarts travel only. Native aliases also stop on entity death.

The Apex playback function, both headshot/elite call paths and its bank alias
are removed. Existing pips 1..9 and the 150-luck overcharge zap remain. The old
Apex WAV and tenth-pip WAV remain on disk for rollback; the Apex alias is not
banked. Sound-only backups: `tmp/luck_audio_20260922/before/`.

## Diagnostics and verification

Logs run automatically under `level.tod_dev`, using the proven developer
PrintLn block. Tag **[TOD_LUCK_ORB]**, startup **INIT rev=2** with
`audio=origins_soul_box`.

- QUEUE: id, player, source, final amount, world origin, pending count.
- RELEASE: same id, origin, value and time spent queued; also on host recreation.
- ARRIVE: id, owner, source, amount, bar before/after, actual contact distance,
  active age and number of combined rewards. The 150 cap may reduce net credit.
- HOLD: state transition and queue counts for cards/death, then resume.
- MERGE / RETRY / SOURCE_FALLBACK / SLOW / CANCEL: backlog, allocation,
  missing source, stalled travel and teardown evidence with ids/values/reasons.
- AUDIO_START / AUDIO_STOP: release played/suppressed, travel requested and
  explicit stop before host deletion. ARRIVE includes arrival_sound (played or
  suppressed by the burst interval). BAR_AUDIO records the collection cue.

`tools/test_luck_orbs.js` executes the actual queue, travel and reward GSC
functions in a simulated native environment. Coverage includes every source,
four-player ownership, moving/teleporting owners, once-only/arrival-only credit,
latched multipliers, card resets, death/respawn, downs, overcharge clamping,
allocation/stall retries, host deletion, disconnect/reuse/end cleanup, and
conservation through a 500-reward backlog. Four in-memory negative controls
reject early credit, ignored pause, dropped overflow value and duplicate jobs.
The existing kill-confirm test now recognizes the added source-position arg.
These tests and `gen_luck_orb_fx.py --check` gate every build.
Audio coverage adds release/loop/stop/arrival ordering, recipient ownership,
burst spacing, failure silence, pause/resume without repeated release, and
completion alias selection. Two new negative controls catch missed loop stops
and repeated release sounds. `import_luck_orb_audio.py --check` also gates builds.

Full build **passed**. Fastfile written 2026-09-22 14:47:53 Eastern:
147,077,696 bytes. All 375 pre-build input hashes match source/deployment,
none newer than the FF. Full scripts/UI/zone_source tree comparison has no
missing, extra or changed files (generated all/english/loc folders excluded).
Compiled asset lists contain the orb script, gold FX and its material/image
dependencies. Full streamed bank 207,523,840 bytes; loaded bank 59,140,608
bytes. Existing ten waived asset warnings only; all build gates passed.

Native visual/network behavior and representative live logs remain unplayed:
the user tests, the agent does not launch. Preserve the
user's resulting console with `tools/capture_ai_logs.ps1` and compare matching
QUEUE/RELEASE/ARRIVE ids. Suggested user checks: door, headshot, each elite,
revive/duplicate drops, moving away, teleport, and a card deal mid-flight.
Evidence and original source backups: `tmp/luck_orbs_20260922/`.

The sound-trial GSC/audio rebuild **passed**, FF written 2026-09-22 15:12:42
Eastern, 147,080,064 bytes. The map hash matches the prior full bake. All 384
pre-build inputs match source/deployment, none newer than the FF; complete
scripts/UI/zone_source trees match. All eight sound aliases and converted
assets are present; the Apex alias is absent. Loops compile as `.LL100.pc.snd`,
one-shots as `.LN100.pc.snd`, both checked. Loaded bank 60,657,024 bytes; full
streamed bank 207,523,840 bytes. Existing ten waived warnings only.
Current audio build evidence: `tmp/luck_audio_20260922/`. User playtests; no
agent launch or desktop audio playback. Native audio/visual acceptance pending.

## 2026-09-23 user test: souls were delivered but not visible

Preserved the user's raw console at
`tmp/luck_visibility_20260923/logs/20260923_151515_185_67eb16c3/`.
The session logged one orb-system INIT, 226 queued rewards, 195 released
movers, 189 actual arrivals, and six slow movers. Forty-five arrivals raised
the luck bar; the other 144 arrived while the true bar was already at 150.
The very first headshot soul raised luck from 0 to 5.0625. Maxed class/cards
do not stop soul generation or delivery. They prevent spending the bar once
no upgrade is available, so the bar eventually stays at 150 and further
arrivals cannot change the HUD. The user saw **no orb visual** even before 150;
that remains a separate native rendering failure.

The first FX pass kept only two small Origins emitters (10-unit trail,
18-unit core). Its native `PlayFXOnTag` call used a literal while the map's
working server FX modules register a `level._effect` handle before playing.
This pass adds the registered handle, an FX_ATTACH log for each actual playback
request, and a larger but still bounded effect (20-unit/500 ms trail,
44-unit/320 ms core). SLOW logs now include host/target positions and player
velocity, to diagnose the six stalled chases without assuming their cause.
This visual change is not native-verified: only the user plays the match.
The build waited until their BlackOps3 session ended, then passed GscOnly at
15:27:32 local with a 147,105,792-byte FF. The deployment audit found no
mismatches among 384 inputs, confirmed the luck FX and orb script in assetinfo,
and verified the loaded/streamed sound banks. This does not prove native visual
rendering. Source backups and build evidence: `tmp/luck_visibility_20260923/`.

## 2026-09-23 user retest: visible; remove ordinary zombie souls

The user confirmed the orb visual now renders, then restricted enemy souls to
elites and Panzers. `add` now credits `zombie`/`headshot` sources immediately
after the existing gain-rate calculation, before any queue/mover/FX/audio is
created. Headshot bonus, round scaling, ownership and the 150 cap remain.
Sprinters still receive the direct normal-kill component plus one soul for the
elite bonus. Door, revive and duplicate-pickup souls are unchanged.

Dev logs identify this revision with `INIT rev=4 ordinary_kills=direct` and
record direct credits as `DIRECT p/source/amount/before/after`; elite rewards
retain their QUEUE/RELEASE/ARRIVE records. The source-executing simulation
checks immediate normal/headshot payment with bonuses, no queued jobs/FX/soul
audio, the mixed Sprinter reward, killer ownership and the cap. A negative
control restoring ordinary-kill orbs correctly fails. Arity lint passes.
Initially held because the user's game was running; included and source-verified
in the 2026-09-23 17:51:33 full build (evidence in
`tmp/power_decals_20260923/`). This ordinary-kill change remains unplayed by
the agent; the user tests. No game launch.
Backups and the pre-change playtest log: `tmp/luck_elites_only_20260923/`.
