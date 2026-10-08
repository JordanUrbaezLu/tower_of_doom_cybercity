# 118 — MAGE STAFF SOUNDS: request brief (ElevenLabs), 2026-09-07

STATUS: OPEN. User: *"the sound seems pretty bad. If we cant fix that we can make
our own sound effect with eleven labs."*

## What ships today (all borrowed stock wavs)

| cue | alias | wav now | verdict |
|---|---|---|---|
| lightning staff shot | `wpn_tod_staff_lightning_plr/npc` | `wpn/energy/staff/lightning/lightning_ball_01.wav` | too soft / mushy for a bolt |
| fire staff shot | `wpn_tod_staff_fire_plr/npc` | `wpn/energy/staff/fire/shot/shot_front.wav` | acceptable |
| ice staff shot | `wpn_tod_staff_ice_plr/npc` | `wpn/elemental_bow/storm/pfx_stormbow_arrowhead.wav` | a whoosh, not ice — nothing crystalline exists in the tools |
| healing aura cast + "you were healed" | `tod_mage_heal` | `sat_ports/perks/evt_elemental_pop_activate.wav` | placeholder |

## Deliverables (exact names, drop them in `sound_assets/tod/mage/`)

| file | length | what it is |
|---|---|---|
| `staff_lightning_shot.wav` | 0.4–0.7 s | a sharp electric crack with a short thunder tail; transient-heavy, no music |
| `staff_fire_shot.wav` | 0.5–0.8 s | a fireball launch: low whoomp + flame whoosh |
| `staff_ice_shot.wav` | 0.5–0.8 s | crystalline: a glassy chime-crack into a frosty whoosh |
| `staff_heal_cast.wav` | 1.0–1.5 s | a warm rising shimmer (the caster's cue) |
| `staff_heal_tick.wav` | 0.3–0.5 s | one soft bright ping (the healed player's cue) |

**Format, hard rule:** WAV PCM, **48 kHz, 16-bit, MONO** for the three shots (they
are 3D aliases), stereo allowed for the two heal cues (2D). Peak −1 dBFS, no
silence padding, no reverb tail longer than the length above. Loudness-match the
three shots to each other (same integrated LUFS within 1 dB).

## Prompts (one per file)

- lightning: "close-range electric crack of a lightning bolt fired from a staff,
  sharp snap, tiny thunder tail, game weapon sound, dry, no music"
- fire: "fireball launched from a mage staff, deep whoomp then a short flame
  whoosh, game weapon sound, dry"
- ice: "ice shard fired from a mage staff, glassy crystalline crack then a cold
  frost whoosh, game weapon sound, dry"
- heal cast: "warm magical healing aura activation, rising shimmer, one second,
  game UI sound"
- heal tick: "single soft bright magical ping, healing received, short, game UI"

## Wiring (repo side, after the drop)

Replace the FileSpec on the five alias rows above (`sound/aliases/tod_ports.csv`
for the shots, `tod_ui.csv` for the heal pair) with `tod\mage\<file>.wav`.
Aliases are linker-side: a `-GscOnly` build packs them. Verify with the alias
listing (`sound\zone\*.all.alias.sz`) and by ear.
