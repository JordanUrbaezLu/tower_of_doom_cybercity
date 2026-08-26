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

| band | alias | wav | source |
|---|---|---|---|
| 1–19 (base) | `tod_ambient_music` | `tod_ambient_music.wav` | "Password Infinity" — Evgeny Bardyuzha |
| 20–29 | `tod_music_city` | `tod_music_city.wav` | "Cyberpunk Futuristic City" — lnplusmusic |
| 30–39 | `tod_music_relay` | `tod_music_relay.wav` | "Cyber Relay" — Psychronic |
| 40–50 | `tod_music_eclipse` | `tod_music_eclipse.wav` | "Cyber Eclipse" — bykenneth |
| boss (any floor) | `tod_boss_music` | `tod_boss_music.wav` | "Data Spike" — Psychronic |
| the finale run | `tod_music_finale` | `tod_music_finale.wav` | "You See Big Girl" — Hiroyuki Sawano / Gemie |

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
Current set: ambient −8.0, city −8.9, relay −7.8, eclipse −9.1 LUFS (1.3 dB
spread). Watch for diminishing returns: the eclipse master already peaked at
0 dB, so past about +5 dB of gain the limiter absorbs everything and you buy
squash instead of loudness. If a track will not come up, that is the signal to
stop, not to push harder.
Credit every track before publish.
