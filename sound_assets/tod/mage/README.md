
Healing Aura (2026-09-09): healing_aura.wav is the user-supplied download
Healing_aura_#4-1788931088647.wav, copied byte-for-byte. 48 kHz, stereo,
16-bit PCM, 2.76 seconds. tod_mage_heal_activate plays it locally once per successful
aura activation. Original author/license metadata was not supplied.

Ice staff shot (2026-09-09): staff_ice_shot.wav is cut from the user's
download dragon-studio-ice-spell-impact-448563.wav ("Ice Spell Impact",
Dragon Studio, Pixabay). Source: 4.704 s, 48 kHz stereo 16-bit PCM, peak
0 dBFS, with a swell from -52 dBFS at 0.0 s to the impact at ~1.3 s and a
tail below -45 dBFS from 3.7 s. Cut 1.20-2.70 s so the impact leads
(10 ms fade in, 350 ms fade out from 1.15 s), then -9 dB: result 1.50 s,
peak -9.0 dBFS, RMS -17.4 dBFS (the previous clip was -20.6). Aliases
wpn_tod_staff_ice_plr/_npc in tod_ports.csv are unchanged. Only the fading last
0.5 s overlaps the 1.0 s ice fire interval.

Staff reload / first-raise aliases were CONTEXT-GATED (2026-09-09): the seven
rows copied from stock freezegun_sounds.csv (wpn_staff_reload_1..4 and the
three *_1straise aliases) carried ContextType=water / ContextValue=over. Stock
maps set that sound context; this map never does (no SetContext anywhere in the
map or the stock shared scripts), so the engine never played them although the
clips carry the right notetracks. Cleared on all seven; every other alias in
the map has no context. tools/lint_tod_sound_context.js gates every build.

Staff reload (2026-09-09): staff_reload_1..4.wav are short Winter's Howl
foley excerpts from the installed freezegun port (wpn/energy/freezegun/_t8/reload).
1 = mag_release 0.00-0.28s; 2 = mag_release 0.88-1.16s;
3 = mag_in 0.06-0.34s; 4 = mag_in 0.78-1.06s.
Each has an 8ms edge fade to avoid clicks, preserving 48kHz stereo 16-bit PCM.
Aliases wpn_staff_reload_1..4 match the existing animation notes at frames
14/29/43/59 on all three approved staff reloads. Native playback times the
cues, including Speed Cola, and cancels unreached cues when interrupted.
No full-length reload recording is layered four times.

## First raise = Winter's Howl (2026-09-09)

staff_first_raise.wav is now `<tools>\sound_assets\wpn\energy\freezegun\_t8\reload\fly_freezegun_first_raise.wav`
copied UNCHANGED (0.98 s, 48 kHz stereo 16-bit, peak 0.69) -- user: "use winters
howl first time sfx for that". It replaces the elemental-bow equip donor. The
three *_1straise aliases are unchanged and play from the frame-1 2D Sound note
on each first-raise clip; the weapon firstRaiseSound/Player fields are now EMPTY
(they named fly_shoulder_first_raise_*, a stock alias no table here ships, and
were silent), so there is exactly one lane and no doubling.

## Why the reload/first-raise foley was silent (2026-09-09)

The aliases, wavs and baked notetracks were all fine. BO3 only plays a
viewmodel clip sound that is declared as a "2D Sound" custom note on the xanim
GDT block (customnoteNaction / actionparam1 = alias / frame). SOUND_NOTES in
tools/import_staff_animations.py stamps them; `python tools/import_staff_animations.py --notes-only`
re-applies them to source_data/tod_staff_approved_anims.gdt, and
tools/verify_staff_animations.py fails the build if they go missing.

## BO6 Ice Staff set (2026-09-13, v18.89) — `bo6/`

The 14 wavs under `bo6/` are BO6 (t10) payloads exported by Saluki
(`docs/bo6_ports/manifests/ice_staff_audio_export.json`), cut and level-matched
by `tools/bo6_extraction/install_ice_staff_bo3.py`; every trim / fade / gain and
the before/after peak+RMS is in `manifests/ice_staff_bo3_install.json`.
`ice_fire_1..5` = `wpn_ice_staff_base_fire_plr` variants (1.25 s, fade 0.25,
capped at -1 dBFS peak so RMS lands ~-15.5, 2 dB hotter than staff_ice_shot);
`ice_fire_tail_1..5` = the `_tail` layer on the Secondary column; `ice_raise`
= `fly_ice_staff_pullout` untouched; `ice_putaway` (1.2 s); `ice_first_raise`
(2.75 s, -4.8 dB) and `ice_reload` (2.0 s, -2.6 dB) each play as ONE `2D Sound`
note at frame 1 of the fitted ice clips. Aliases `wpn_tod_bo6_ice_*` sit
between the `#BO6 ICE STAFF` markers in tod_ports.csv; the rows are clones of
the existing staff rows' mix settings, not BO6 settings. Lightning and fire
keep the Winter's Howl set above.
