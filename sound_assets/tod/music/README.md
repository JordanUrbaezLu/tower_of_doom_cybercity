# tod\music — the map's own music wavs

Drop the game-long ambient track here as `tod_ambient_music.wav`.
**Format is enforced by the bank builder: 48000 Hz, 16-bit PCM** (44.1k is
rejected with "wav is not 48k sample rate" — resample:
`ffmpeg -i in.wav -ar 48000 -sample_fmt s16 -ac 2 out.wav`).
It loops raw, so it should loop reasonably cleanly.
Then point the `tod_ambient_music` alias row in `sound/aliases/tod_ui.csv`
at `tod\music\tod_ambient_music.wav` (FileSpec column) and run a full build.
The sync step copies this tree to the Mod Tools root `sound_assets\`, which
is where alias FileSpec paths resolve at sound-bank build.

Until then the alias points at map 1's calm city track as a placeholder.

## Band tracks (v9.46, 2026-08-23)

The music changes as the party climbs past the breather floors. Each band is
ONE row in `_tod_atmosphere::register_music_bands()` — `add_music_band( <first
floor>, "<alias>" )` — plus an alias row in `sound/aliases/tod_ui.csv` (clone
`tod_ambient_music`, change only Name and FileSpec) plus the wav here.

**The floors below were STALE for a week** (20/30/40 — the pre-2026-08-25
split). Read `register_music_bands()`, not this table, if the two ever
disagree again; the code is the only place a band floor is decided.

| band | alias | wav | source |
|---|---|---|---|
| 1–9 (base) | `tod_ambient_music` | `tod_ambient_music.wav` | "Password Infinity" — Evgeny Bardyuzha |
| 10–22 | `tod_music_city` | `tod_music_city.wav` | "Cyberpunk Futuristic City" — lnplusmusic |
| 23–36 | `tod_music_relay` | `tod_music_relay.wav` | "Cyber Relay" — Psychronic |
| 37–50 | `tod_music_eclipse` | `tod_music_eclipse.wav` | "Cyber Eclipse" — bykenneth |
| boss (any floor) | `tod_boss_music` | `tod_boss_music.wav` | "Data Spike" — Psychronic |
| the finale run | `tod_music_finale` | `tod_music_finale.wav` | "You See Big Girl" — Hiroyuki Sawano / Gemie |
| the Endless Spire | `tod_music_spire` | `tod_music_spire.wav` | "Neon Static" — Suno v5.5, for this map |
| a WARDEN TRIAL | `tod_music_trial` | `tod_music_trial.wav` | "Chaos Unleashed" — **source to confirm** (CREDITS.md) |
| THE WARDEN KING (the summit boss, v17.70) | `tod_music_king` | `tod_music_king.wav` | "Chaos Unleashed" (the 3:29 version) — the same source as the trial track; matched to -12.2 LUFS like it (+0.6 dB, limiter at 0.891, level=0 — the limiter's auto-level is OFF or it re-normalises to -11) |
| THE TEDDY BEAR SONG (v18.96 — shoot the three bears; NOTHING overtakes it, `channel_play` parks other requests) | `tod_music_ee` | `tod_music_ee.wav` | "Falling To Pieces" (user-supplied 2026-09-13, `Downloads/01. Falling To Pieces.wav` 44.1k) — measured -4.6 LUFS / 0.0 dB peak, v18.96g: +3 dB over the bands (user: "Volume is a knob") — `volume=-0.4dB,alimiter=limit=0.891` → -5.6 LUFS, peak -0.6 dB (the limiter takes the last 0.6 dB; pushing harder only squashes the mix), 279.33 s = `TOD_MUSIC_EE_SECS` |

**The last two are not bands** — nothing in `register_music_bands()` names
them. The spire track is latched by `_tod_spire` on ascension and the trial
track by `trial_begin`; both are plain `channel_play( alias )` calls, which is
all a non-band track needs. `band_alias()` is what puts the spire track back
when a trial is won.

**The finale track is a CLOCK, not a mood.** `_tod_finale.gsc` ends the game
when it ends, so its length is load-bearing: `TOD_FINALE_SONG_SECS` +
`TOD_FINALE_DEPART_SECS` must equal the measured wav length (currently
191 + 6 = 197, wav 197.395s). Every alias here is LOOPING — it has to be, a
non-looping streamed one-shot is engine-unstoppable — so a timer that runs
LONGER than the wav plays the ending over the song's second intro. If this
track is ever swapped, re-measure and re-derive both numbers in the same
commit.

**The floor 10 breather has no track** and that is the design: the user's bands
are 20 / 30 / 40, with the base ambient carrying everything below 20. A band
with no row simply isn't in the table, so the previous one keeps playing.

**LOUDNESS MATTERS MORE THAN THE ALIAS VOLUME.** The bands hard-swap the
stream, so a track mastered quieter than its neighbour reads as a bug. Match
integrated loudness to the base track (measure, don't guess):
`ffmpeg -i x.wav -af ebur128=framelog=quiet -f null -` then gain + limit:
`ffmpeg -i in.mp3 -af "volume=<target - measured>dB,alimiter=limit=0.891" -ar 48000 -sample_fmt s16 -ac 2 out.wav`.
Current set: ambient −8.0, city −8.9, relay −7.8, eclipse −9.1, spire −8.0
LUFS (1.3 dB spread). The two ALIAS-100 tracks sit lower and always have:
boss −12.2 and trial −12.2.

**MATCH THE TRACK YOU REPLACE, not the loudest one in the table** (v17.8). The
trial track arrived at −15.9 LUFS and took `volume=3.7dB` to land on the boss
track's −12.2 — because the trial track REPLACES the boss track in that exact
moment, at the same alias volume, so matching it makes the swap inaudible as a
level change. Pushing it to the band tracks' −8.0 would have wanted +7.9 dB
against only 5.4 dB of peak headroom, which is the squash the paragraph above
warns about. Peak landed at −1.7 dB and the limiter never engaged.

⚠️ `alimiter` AUTO-LEVELS BY DEFAULT and will overshoot your target by about a
dB. The first pass here asked for +3.7 and measured +4.7. Use
`alimiter=limit=0.891:level=disabled` and then re-measure — always re-measure,
the filter chain is not the receipt. Watch for diminishing returns: the eclipse master already peaked at
0 dB, so past about +5 dB of gain the limiter absorbs everything and you buy
squash instead of loudness. If a track will not come up, that is the signal to
stop, not to push harder.
Credit every track before publish.
