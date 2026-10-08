# 52 — THE CARD REVEAL (v14.52, retimed v14.53/54, aura v14.55, one-sting v14.57, 2026-08-31)

> User: *"add an animation and cool sound effect when you pull a super or
> ultimate ... like when you pull a super cool camo in CSGO or something like
> Apex Legends crates. You get cool animations and awesome sound effects that
> make the experience addicting. Like if a slot is ultimate it can be empty for
> 0.5s and then grow into its ultimate card and then make an epic noise like you
> are doing something rare and epic. Our whole point and goal is to enhance the
> player experience when they pull upgrade cards."*

Before this, every deal appeared **finished**: the panel faded up with two
completed cards already on it. Nothing about pulling an ULTIMATE was different
from pulling a regular except the frame colour on a card that was already there.

---

## 1. The shape

The panel opens on **empty sockets** and each slot lands on its own beat.

```
 0.000 panel up, both sockets empty          tod_deal_open
 0.175 slot A begins its HOLD                tod_reveal_charge  (rarity >= 2)
       ...  0.05s regular / 0.20s super / 0.30s ULTIMATE  ...
       STING FIRES EARLY by its own lead (per-ASSET, not per-rarity):
         ultimate 0.10s early | super 0.20s early | regular on the card
 +hold slot A LANDS — socket blows apart,
       card flips open out of its own spine
 +0.14 slot B begins its HOLD                (same, its own rarity)
 +hold slot B LANDS
 +0.15 focus arrives, input opens, countdown starts
```

**THE HOLD IS THE FEATURE.** The wait is longer the rarer the card, so the
delay itself is the tell — you know something good is coming *before you can
see what it is*. That is the whole loot-box grammar, and it is why the timing
table is not uniform. The riser SFX sits on top of the same wait.

**REGULAR IS DELIBERATELY DULL** — 0.05s, no riser, no burst, no aura, a dry
tick on landing. If every pull flashes, no pull is special. The escalation only
reads because the common case is boring.

Worst case (double ultimate, world paused): **1.07s** before input. Common case
(two regulars): **0.57s**. Halved in v14.53 (user: *"the game is fast paced ...
can we cut all the delays in half"*) — all six timings moved together, so every
ratio and the whole rarity ladder survived the cut.

### Timing table

| | regular | super | ultimate |
|---|---|---|---|
| empty hold | 0.05s | 0.20s | 0.30s |
| riser SFX | — | `tod_reveal_charge` (under the sting throughout) | `tod_reveal_charge` (0.20s alone, then under the sting) |
| land SFX | `tod_card_land` | `tod_super_sting` | `tod_ultimate_sting` *(same wav since v14.57)* |
| burst peak alpha | 0 (none) | 0.55 | 0.92 |
| sting timing | on land | **0.20s early** | **0.20s early** |
| burst grow | — | 18px | 34px |
| burst duration | — | 200ms | 380ms |
| lingering aura | 0 | 0.22 | 0.40 |
| altar aura SFX | — | — | **yes, panned to its side** |

---

## 2. It costs ZERO clientuimodel bits

The pool sits at **60 of its proven 61** (16 of 18 fields) — a new field was
not affordable. None was needed. The reveal is derived from three facts the
panel already carried:

| signal | meaning |
|---|---|
| `todUpgShow == 1` **and** `todUpgFocus == 0` | the reveal is running |
| `todUpg{A,B}R >= 1` while `todUpg{A,B}D == 0` | that slot is an empty socket, charging toward rarity R |
| `todUpg{A,B}D` goes `0 -> N` | that slot's card **lands now**, at rarity R |

`show == 1 && focus == 0` is a **server contract** and is unreachable any other
way: every path that raises `show` to 1 sets focus 1..4 in the same breath, and
`wait_for_choice` never writes 0. `present_choice` holds focus at 0 for exactly
the length of the reveal and sets it to 1 when input opens.

`R == 0` is the fourth state and it means **no card is coming to this slot** —
that is how a one-card deal draws one socket instead of two. Rarity 0 was
previously unused on a 2-bit field, so this was free.

### The two-wave push, and why the gap is load-bearing

Rarity lands at the **start** of a slot's hold, domain at the **end**, separated
by a real `wait`. They can therefore never arrive in one snapshot — which is
what makes reading rarity on the domain edge safe. Model callbacks fire in
clientfield **registration order** (`todUpgAD` before `todUpgAR`), so pushed
together, a card would land wearing the *previous* deal's rarity for a frame.

---

## 3. Client-side rules that were paid for

**Only alpha and rects are ever tweened.** Those are the two lanes this file and
the vendored Aetherium kit it copies from have actually shipped
(`AetheriumPowerupNotification` tweens both; nothing in-tree tweens colour). An
RGB tween would be a guess, so every colour is *stamped* and only its alpha
moves. The socket's charge is the rim brightening into a colour it already
wears, not a colour crossfade.

**No UITimers, no completion callbacks.** The reveal's phase is derived from
server state, not timed client-side — so it cannot drift from the server, and
there is no timer to leak (the map 1 trap this file's header warns about). The
tweens are pure garnish; if one is interrupted, the state is still correct.

**`self:completeAnimation()` moved to the TOP of `Render()`.** LUI's
`completeAnimation` is documented nowhere in this tree and *may* snap child
animations as well as the element's own. Called at the bottom, as it used to be,
it would end a card tween on the frame it began — silently, with everything
still looking right in the code. Run first, the question stops mattering.

**The focus block is skipped during the reveal, not adapted.** It writes an
alpha to every element of both cards on every paint, which is exactly what a
reveal tween cannot survive, and it has nothing to say yet — no card is focused
until the deal finishes.

**No `Render()` can land inside the 60ms flip.** The flip must stay under the
server's shortest gap between two pushes. At the station's half speed that floor
is `min(GAP, TAIL) * 0.5`. **Change one of those three numbers and check the
other two** — v14.53 is exactly why that warning is here. Halving the server
timings moved the floor from `min(280,300)*0.5 = 140ms` to
`min(140,150)*0.5 = **70ms**`, and the old 120ms flip would then have been legal
on a round event and **snapped at the station**: an animation that silently
stops existing in one of the two places it runs, with nothing failing anywhere.
60ms keeps 10ms of margin in both.

**Sockets arm off the reveal's own `0 -> 1` edge, not off slot data.** A deal can
re-open with the same rarity in the same slot — no field change, no edge, no
socket. Reachable in practice: a round event kills an in-flight station pick
(`tod_global_upg_takeover`) and re-presents without `show` ever returning to 0.

**`RevealHide` restores the card face's RECT, not just its alpha.** A deal
aborted mid-flip otherwise leaves `CardImg` parked at whatever sliver the tween
reached, and the *next* deal paints a correct image into a wrong rect — a bug
that would only ever appear on the second card.

---

## 4. Design calls worth knowing

**The station runs the show at half speed** (`TOD_REVEAL_LIVE_SCALE 0.5`). Round
events run under `level.tod_upgrade_pause` where the reveal is free; the personal
upgrade station is the deliberate-risk lane with the world still live, so every
tenth of a second of un-pickable card is real danger.

**A floor-gated CLASS TIER card reveals as a REGULAR.** It carries rarity 3 so it
draws the ultimate art, but it cannot be taken — giving it the full ultimate
build-up and then refusing the pick is a tease, not a reward. `reveal_rarity()`
is the one place that decision lives.

**The countdown and the tier-gate badge are suppressed during the reveal.**
"AUTO IN 15s" over two empty sockets promises a clock that is not ticking yet
(`wait_for_choice` runs *after* the reveal). The gate badge would otherwise sit
in the gutter and then jump onto card B the instant it lands.

---

## 5. Where it lives

| file | what |
|---|---|
| `scripts/zm/zm_tower_of_doom/_tod_upgrade_ui.gsc` | `reveal_deal` / `reveal_slot` / `reveal_rarity`, `TOD_REVEAL_*` timing, the rewritten field push in `present_choice` |
| `ui/uieditor/menus/hud/tod_upgrade.lua` | `SocketOpen` / `LandCard` / `RevealDrive` / `RevealHide`, `REVEAL_*` constants, the per-card Glow / SockRim / SockFill / Flare elements |
| `sound/aliases/tod_ui.csv` | 5 aliases, **3 authored**, 2 pointed at existing audio (§6) |
| `tools/lint_tod_lua.js` (+ selftest) | new — a structural gate for the Lua, wired into `build_map.ps1` |

⚠️ **LOCKSTEP**: `TOD_REVEAL_HOLD_*` (GSC, seconds) and `REVEAL_HOLD_MS` (Lua,
ms). The socket rim ramps over the same span the server waits. Drift does not
break anything — it just stops looking deliberate.

---

## 6. Sound — five aliases, THREE authored

Cut from seven on 2026-08-31 (user: *"Do we need 7 sounds? Can we do the minimal
while keeping the experience?"*). It was the right question — four of the seven
were ceremony around the two that carry the feature.

**ALL THREE AUTHORED WAVS ARE INSTALLED** (2026-08-31, ElevenLabs, user-generated
from the prompts below). 48 kHz / 16-bit / stereo, matching the house format.

| alias | length | file | vol |
|---|---|---|---|
| `tod_deal_open` | — | `acc\fx\reactor_online.wav` *(shared, final)* | 82 |
| `tod_card_land` | — | `acc\fx\glass_cling.wav` *(shared, final)* | 86 |
| `tod_reveal_charge` | 0.60s | `tod\sfx\tod_reveal_charge.wav` | 86 |
| `tod_super_sting` | 0.86s | `tod\sfx\tod_super_sting.wav` | 95 |
| `tod_ultimate_sting` | 1.50s | `tod\sfx\tod_ultimate_sting.wav` | **100** |

**The loudness ladder is in the WAVS, not just the alias volumes** — mean −16.7 /
−10.9 / −5.5 dB riser → super → ultimate, so the escalation survives any later
volume retune.

### What the raw ElevenLabs files needed, and how it was found

**MEASURE BEFORE INSTALLING.** All three came back peaking at exactly 0.0 dBFS
and none was usable as delivered. None of this was audible from the filenames:

- **SUPER's hit was 0.64s INTO THE FILE.** Dead silence to −67 dB at 0.625s,
  then the real event. Installed raw it would have fired two thirds of a second
  *after* the card landed. Fixed with `atrim=start=0.640` (`atrim`, not `-ss` —
  see the audio-tooling notes). 1.50s → 0.86s.
- **ULTIMATE stopped at full scale.** Brickwalled at 0.0 dBFS for its entire
  length — the final 50 ms window still read 0.0 dB — which is a guaranteed
  click on playback. 250 ms fade-out added; it now decays −1 → −16 dB.
- **The RISER does not rise in level at all** — flat ~−10 dB across all 1.2s, so
  the "rise" is pitch and filter only. Truncating it to the 0.60s hold would
  have chopped the sweep mid-flight, so `atempo=2.0` fits the WHOLE sweep into
  the hold instead. 30 ms fade-in, because it starts at full level and a hard
  start clicks.

**The probe lied first, and that is the trap worth remembering.** `ffmpeg -v
error -af volumedetect` prints *nothing* — the filter reports at INFO level, so
`-v error` silently suppresses the very numbers being asked for. The first pass
returned empty for all four files, which reads exactly like four silent files.
An all-absent result means a broken probe, not an absent subject.

### What was cut, and why it cost nothing

**The second riser.** There was one for SUPER and one for ULTIMATE. The HOLD
already separates them: a single 0.6s riser **completes exactly as an ULTIMATE
lands**, and a SUPER's shorter 0.4s hold **cuts it off mid-sweep**. The ultimate
is therefore the only build the player ever hears resolve — which *is* the tell,
bought with one asset instead of two.

**The double-ultimate fanfare.** The overcharge deal already announces itself
with two ultimate stings ~0.9s apart, which no other deal in the game can
produce. A third sound on top earns nothing the pair does not already say. One
alias and one line in `reveal_deal` if it is ever wanted back.

**Panel-open and regular-land stopped being placeholders and became final.**
`reactor_online` is what `tod_class_open` plays — the *other* choice panel
opening, so the same voice is correct rather than merely convenient.
`glass_cling` is `tod_ui_tick`'s: literally a card-on-glass tick, which is
exactly the deliberately-plain thing a REGULAR wants. Neither is worth an
authored asset.

⚠️ **Every wav named above already resolves.** Three are in `sound_assets/`;
the other two are proven by shipping aliases in this same CSV
(`tod_class_open` → `reactor_online`, `tod_ui_tick` → `glass_cling`). Never
point an alias at a wav that does not exist yet — `tod_reveal_charge` was
briefly aimed at its own unwritten `tod\sfx\` file, which is a dangling asset
reference in the build.

### The three prompts

**DIRECTION: DARK SYNTH BASS, NOT BELLS** (user 2026-08-31, on a first pass
built around chimes and choir: *"These are too bright. The last two. I want more
synth bass wave reveal rather than a bell or chime. That's too childish"*). The
correct reference is a synth patch loading in a neon city, not a treasure chest
opening — this map is Tron grid, Miami night skybox and city smog. A bright
crystalline sting is the single easiest way to make a cyberpunk map read as a
mobile game, and it is the reason the first three prompts were thrown away.
**No bells, no chimes, no choir, no orchestral swell, no sparkle.** Weight and
menace do the work that brightness was doing.

**`tod_reveal_charge` — 0.6s**
> Dark rising synth charge. A low detuned saw drone sweeping upward through an
> opening filter, with electrical crackle and a faint metallic whine underneath,
> building heavy anticipation. Cold, analog, menacing. Ends at its peak with NO
> impact — the build only.

**`tod_super_sting` — 1.0s**
> Dark cyberpunk unlock stab. A punchy filtered analog synth bass hit with a
> fast downward pitch bend, a tight sub thump underneath and a short detuned saw
> tail. Cold, heavy, electronic, restrained.

**`tod_ultimate_sting` — 1.8s**
> Massive dark synth reveal. A deep sub-bass drop lands on the downbeat under a
> huge distorted analog saw swell with the filter sweeping slowly open, a brief
> reversed pre-hit leading into it, and a long dark decaying tail with subtle
> metallic resonance. Ominous, powerful, expensive — a legendary unlock in a
> neon cyberpunk world.

**Generate the two stings in ONE sitting, as a pair.** SUPER has to read as
ULTIMATE's lesser sibling — same synth voice, less weight — not as an unrelated
noise. That relationship is most of what makes the rarity ladder legible and it
is the hardest thing to repair afterwards.

**Keep the punch at 60–120 Hz, not below 50.** These play on the 2d UI bus. Pure
sub content vanishes on laptop speakers and the sting lands as nothing at all;
the body has to live in the low-mids with the saw carrying the rest.

### Install contract for the three authored wavs

- **48 kHz, 16-bit PCM, mono** → `sound_assets/tod/sfx/<alias>.wav`
  (ElevenLabs returns 44.1 kHz — it must be resampled; see
  `docs/43_sound_audit.md` and the audio-tooling notes).
- Repoint that alias's `FileSpec` to `tod\sfx\<alias>.wav`. One field each.
- Volumes are already in the 80–96 band, the audible range for this map. The
  riser sits deliberately *under* both stings.
- **Generate the two stings in one session, as a pair.** SUPER has to read as
  the lesser sibling of ULTIMATE, not as an unrelated noise — that relationship
  is most of what makes the rarity ladder legible.

### The riser overlaps its sting at the station

At half speed an ultimate's sting fires 0.30s in while the riser runs 0.6s. That
is intentional — a riser tail under an impact is normal — but it is why the
riser must **peak early and decay soft**, never end on a hard transient.

---

## 7. Art — optional, the flat-panel path ships without it

The socket, burst and aura are currently drawn from `CoD.TextWithBg` panels: a
rarity-tinted rect with a dark rect inset over it (a 3px rim, the only way to
draw a border out of that widget), a full-card panel that flashes and expands,
and an oversized panel behind the card for the lingering aura. That is complete
and shippable.

Per the standing images-over-LUI rule, baked art would beat all three. The
upgrade path is four PNGs and a `USE_REVEAL_ART` flag:

| asset | canvas | what |
|---|---|---|
| `i_tod_card_socket` | 768x1152 | the face-down slot — a dark cyber card back with a glowing circuit rim, neutral colour so the rim tint can be applied over it |
| `i_tod_card_burst_super` | 1024x1024 | radial burst, cyan, transparent centre |
| `i_tod_card_burst_ultimate` | 1024x1024 | radial burst with shards, gold/amber, transparent centre |
| `i_tod_card_glow` | 1024x1024 | soft rectangular bloom, white (tinted per rarity at runtime) |

Same install path as every other UI image: PNG into
`source_data/tod_ui_images/_images`, entry in `tod_ui_images.gdt`, `image,` line
in the `.zone`, and a **FULL build** (a GDT edit is always a full build).
