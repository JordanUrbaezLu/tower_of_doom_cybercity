# BO6 complete migration contract

User direction, September 12, 2026: asking to add something from BO6 includes
the entire experience. The user must not have to ask separately for sound,
animation, color, special abilities or the small details. This applies to new
ports and the unfinished Mangler, swords, Doppelghast and Amalgam work.

## Default scope and ownership

One request starts one continuous migration: discovery, acquisition, conversion,
integration, build, native testing, corrections and a complete handoff. Internal
build/test iterations are expected. Do not stop at an export, a Blender preview,
a playable mesh or a successful link and call the request finished. Preserve
original files, record exact source-to-output mappings and resume validated work.

Create the mandatory ledger before converting:

`python tools/bo6_extraction/port_gate.py init <asset_id> --kind enemy`

Use `--kind weapon` for a weapon. The generated nine workstreams include specific
enemy/weapon motion and audio families. Populate **individual** source components,
states, events, texture slots and dependencies under `items`; a category checkbox
is insufficient. Discover from original banks/models/animations/material metadata
and recorded source gameplay. A name search or the exported-file count is not a
complete retail inventory. Resolve hashed dependencies and secondary sound aliases.

## Required conversion and verification

1. Inventory the exact variant and every visible component, rig, attachment, UV,
   color layer, texture and LOD. Record every retained, converted or omitted part.
2. Reconstruct materials: source color and alpha semantics, normal channels and
   orientation, gloss/roughness, metal/specular, occlusion, emission, detail layers,
   masks, tint and transparency. Keep source resolution unless a documented engine
   limit requires conversion. A flat normal, white AO or generic gray shader is an
   **open defect** when corresponding source detail exists. No arbitrary global
   brightening or tint is a substitute for restoring the actual material.
3. Convert all applicable motion states and transitions, including loops, root
   motion, attack/contact timing and notification-driven sound/FX. Check intended
   parent transforms and weighted vertices across every frame; checking only bone
   transforms missed the stretched Amalgam arm. Test actual locomotion after attacks.
4. Export/validate every required sound payload and variant. Resolve event meaning,
   aliases and secondary layers, then wire and listen to them in BO3. Installed or
   archived WAVs do not prove event coverage. Check footfalls, voice, idle loops,
   ready/windup/release/contact/impact and stop/delete ordering.
   For the current enemy set, `import_enemy_audio.py --plan` resolves every variant
   and recursively follows `alias2`, including hashed layers. It refuses
   inconsistent secondary mappings and lists missing dependencies. Export the
   resulting exact hashes with `export_ledger_audio.py --inventory-plan <plan>`.
   The importer preserves original PCM bytes, validates mono copy timing, and
   carries secondary relationships into BO3. `build_enemy_audio_events.py` binds
   original animation frame cues; exported sound counts still do not close audio.
5. Reproduce the source abilities, AI movement patterns and FX state transitions.
   Record deliberate Hellbound balance choices. Test first/third-person appearance,
   sockets, charged states, projectile collisions, sound distance and cleanup.
   Validate sockets under the actual held animations: the September 12 Caliburn
   test found a correct rest-pose `tag_knife_fx` overridden by the donor animation,
   placing fire on the donor blade's location. Check the whole ability FX chain;
   orange blade art does not fix a purple projectile/impact donor. Multi-stroke
   animation requires matching contact, miss and sound timing for every stroke.
   A GSC `#precache("fx", ...)` declaration does **not** add that effect to the
   map fastfile. Explicitly zone the entire flight/impact/burn/death chain and
   compare it with the linker's asset list and the stock base packages. September
   13 found Caliburn's arrow-trail/impact FX absent despite working damage logs;
   its burning FX was already in `zm_common`. `verify_port_deployment.py` now
   checks every FX precache in the three BO6 runtime modules and explicitly
   accounts for that stock torso-fire dependency.
6. Verify spawn/equip/progression, HUD/inventory icons and names, keyboard/controller
   prompts, switch/pause/down/death, interruption/recovery,
   collision and solo/co-op behavior. Use cheap `level.tod_dev` diagnostics.
   Custom actor factories must also reach kill-driven weapon/class progression.
   Starting `enemy_death_detection` does not start `zombie_death_event`: the
   September 13 boss-only test could spend its free Caliburn charge once and
   never recharge. Verify a second special earned from actual kills, preserve
   fatal-hit weapon attribution and prevent duplicate kill credit.
7. Build and launch using the repository tools. Verify a fresh fastfile and matching
   deployed sources/banks, actual map load and representative behavior. Preserve
   neutral-light closeups, motion captures, listening notes and console evidence.
   A blood-covered screen cannot close a color review. Retest affected paths after
   changes; tie evidence to the implementation and fastfile hashes actually tested.

## Completion gate

`python tools/bo6_extraction/port_gate.py check`

Exit 0 requires all registered ports' workstreams and individual items verified
or justified as genuinely inapplicable, with existing SHA256-pinned evidence.
Native evidence must include build, deployment, console, visual, listening,
behavior, lifecycle and implementation records. Replacing evidence invalidates
its pinned hash. A human still has to inspect/listen and assess source coverage;
the checker cannot infer fidelity from file counts or manufacture that review.

`--development` permits unfinished work to be built/tested but always reports it
as INCOMPLETE. Invalid completion claims still fail. The ordinary build invokes
this gate; `-Dev` permits iteration and shipping-mode builds require completion.

`adapted`, `unavailable`, `implemented` and `pending` all keep the full migration
open. A donor animation or approximation must be named explicitly. If BO3 cannot
reproduce a feature exactly, finish the best supported implementation, show the
specific difference and keep exact parity unresolved; never silently reduce scope
or promise a universal one-click 100% converter. Escalate an actual constraint
after completing independent work, not a missing checklist category.

Before any final handoff, run the strict gate and report every user ask, all
remaining gaps, the tested final build and next concrete action. Do not equate
"102 WAVs exported" with "all sword sounds work" or written cast code with a
successful native three-fireball cast. The current ports remain incomplete.

For sword native logs, run `python tools/bo6_extraction/audit_native_port_log.py
<console.log> --output <report.json>`. This rejects script exceptions and requires
three timed releases, all impacts, observed health loss and inventory cleanup.
It verifies only those exercised behaviors; visual, listening, interruption and
source-completeness reviews remain separate requirements. The September 12 cast
logged eight hits while applying no damage because DoDamage's fifth argument was
wrong. Event names and hit counters alone cannot close behavior verification.

The build also requires both resident and streamed banks (`.all.sabs/.sabl`) and
both English banks. Known converter checksum/null-reference faults trigger bounded
link retries with the game closed; a fresh fastfile with missing banks fails.
