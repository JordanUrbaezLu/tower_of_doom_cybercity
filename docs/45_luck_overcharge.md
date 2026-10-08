# 45 — LUCK OVERCHARGE: the secret 150% band (v14.9, 2026-08-30)

User: "I want it to secretly go up to 150% ... When you are at 150% the luck
bar will go into an animation. Will have zaps moving around it and player will
hear a luck zap constant sound when they are maxed out. ... both options are
guaranteed to be ultimates rarity."

## The system (shipped v14.9 — full record in CHANGELOG)

Sound cap (v18.46, 2026-09-08): `TOD_LUCK_OVER_ZAP_LIMIT` limits the cue to
seven actual plays per overcharge, at the existing three-second spacing.
The bar animation continues after the sound stops. The existing no-upgrade-
headroom mute still applies; muted opportunities do not consume plays, and
regaining headroom does not refill the allowance. Leaving 150 and reaching it
again starts a fresh allowance. This supersedes the unlimited repetition in
the original sound brief below.

| piece | where | contract |
|---|---|---|
| secret tracking to 150 | `_tod_luck.gsc` TOD_LUCK_OVERMAX | set_bar's true clamp; HUD + pips still cap at TOD_LUCK_MAX 100 (pip crossings clamped to seg 10 both sides — the band is silent AND invisible) |
| odds in the band | `_tod_upgrades.gsc` roll_rarity | reads the raw bar; 101..149 quietly improves both dice |
| both-ULTIMATE at 150 | `_tod_upgrades.gsc` guarantee_both_ultimate, TOD_UPG_GUAR_BOTH_BAR | every non-tier slot promoted, v14.6 redeal PER SLOT, tier card exempt, band-honesty clamp kept |
| TIER card at 100 (v16.56) | `_tod_upgrades.gsc` tier_card_guaranteed / tier_card_roll, TOD_UPG_GUAR_TIER_BAR | full visible bar + FULL tier eligibility (PaP + floor gate + next gun) = the promotion is dealt, not rolled; floor-blocked players keep the 20% locked draw |
| animation | `_tod_luck.gsc` overcharge_driver → `_tod_upgrade_ui.gsc` set_luck_over_frame → `tod_upgrade.lua` LuckBar | todUpgLuck **11..14** = the four frames (4-bit field's spare values, ZERO new clientuimodel bits); ~7 Hz server-driven, random, never repeats (LUI models only notify on CHANGE) |
| sound | same driver | `tod_luck_overmax_zap` fired via PlayLocalSound every 20 frame ticks = **3.0s** (v14.9b — the v14.9 1.05s crackle bed was rejected by the user: "a semi deep zzz and plays every few seconds"); NEVER a looping alias (stuck-loop doctrine); per-client, a teammate's overcharge never buzzes in your ears |
| exit | driver polls | any drop below 150 (down −25, event spend, spire reset, direct writers included) ends both within 0.15s |

LOCKSTEP TRIO — move together: `TOD_LUCK_OVERMAX` (_tod_luck),
`TOD_UPG_GUAR_BOTH_BAR` (_tod_upgrades), `TOD_UPG_LUCK_OVERMAX_PCT`
(_tod_upgrade_ui).

## Assets

**BOTH REAL — NO PLACEHOLDERS REMAIN** (2026-08-30). Frames: user drop
files (68).zip — electric-blue crackle style, alignment-verified (90–92% of
sampled pixels byte-identical to i_tod_luck_10 = true composite, no base
drift). Wav: the user's ElevenLabs keeper ("A single electric za[p]" take
#3, 1.86s, arrived at contract format) + a 100ms end-fade added on install
(the raw tail sat at −10 dB and would tick at the 3s cadence); bank
consumption proven by the .all.sabl size moving +141,312 bytes. Future
replacements: drop over the same filenames — frames = FULL build (image/GDT
lane; a -GscOnly after a GDT edit makes the tree LOOK current — CLAUDE.md),
wav alone = -GscOnly, and verify by the CONTENT checks (assetconvert .iwi
mtimes / .sabl size delta), never a name-grep.

* `source_data/tod_ui_images/_images/i_tod_luck_max_01..04.png` — 1024×128,
  transparent background, 32-bit PNG.
* `sound_assets/tod/sfx/tod_luck_overmax_zap.wav` — 48 kHz / 16-bit / stereo,
  a single discrete zap ~1.3 s. HARD RULE: shorter than the 3.0 s fire
  interval (TOD_LUCK_OVER_ZAP_TICKS × 0.15) or consecutive zaps overlap.

⚠️ `gdtdb /update` currently exits 1 on this machine (duplicate install-side
pack GDT, surfaced 2026-08-30) and build_map.ps1 downgrades that to a Warn —
so after the art build, VERIFY the frames actually render in game (or
filename-grep the fresh .ff for `i_tod_luck_max` with `i_tod_luck_10` as the
control). "BUILD OK" does not prove the GDT landed.

## PROMPT 1 — the asset LLM (four zap frames)

Two-step doctrine (memory: images-over-LUI): explore one frame first, then
build out the set in the winning style. **Attach `i_tod_luck_10.png` to both
steps.**

### Step 1 — explore

> I'm attaching the "full" state of a luck meter from my neon cyber-city
> zombies game: a 1024×128 transparent PNG — angular dark navy housing, a
> dice icon in a rounded square on the left, the word LUCK on top, a molten
> gold fill bar with segment lines, and a circuit-traced arrow tip on the
> right.
>
> I need an OVERCHARGED version of this exact image: electric zaps/arcs
> crawling around the bar, as if it's holding more energy than it can
> contain. Give me 3 distinct style options of ONE overcharged frame so I can
> pick a direction:
>
> A) White-gold lightning — thin white-hot arcs with soft gold glow, leaping
>    across the fill and off the frame edges and arrow tip. Elegant, premium.
> B) Electric-blue crackle — cyan/electric-blue arcs contrasting the gold
>    fill, plus tiny spark motes floating just off the housing. Cyberpunk.
> C) Plasma bloom — the gold fill goes white-hot at its core with short
>    forked arcs bursting outward and a faint outer aura ring. Overloaded
>    reactor feel.
>
> Hard rules for every option: the base art must stay EXACTLY as attached —
> same canvas size (1024×128), same position, same scale, same colors, fully
> transparent background. Only ADD the electricity on top. Do not cover the
> LUCK wordmark or the dice icon with arcs. Keep arcs thin and readable at
> small sizes — this renders at 304×38 on screen.

### Step 2 — build-out (after picking a style)

> Style [X] wins. Now produce the full animation set: FOUR frames of that
> exact overcharged look, named i_tod_luck_max_01 through i_tod_luck_max_04.
>
> The game flips between these four at random, 6–7 times per second, to fake
> a live electricity animation — so the four frames must share the identical
> base image and identical overall energy level, but every arc, spark, and
> hotspot must sit at DIFFERENT positions in each frame (frame 1's arcs near
> the left third and the arrow tip, frame 2's mid-bar and top edge, frame 3's
> along the bottom edge and dice badge, frame 4's spread wide with the
> longest single arc). No frame may look "calmer" than another — when they
> cycle it should read as electricity dancing around the bar, not blinking
> on and off.
>
> Deliver: four 1024×128 PNGs, transparent background, base art untouched
> and pixel-aligned across all four (any drift makes the HUD jitter).

## PROMPT 2 — ElevenLabs (the overcharge zap sound) — v14.9b REWRITE

v14.9's "seamless crackle bed" prompt is RETIRED — the user tested that
direction and rejected it ("doesnt really sounds pleasing. Like a semi deep
zzz and plays every few seconds"). The sound is now a SINGLE DISCRETE ZAP
fired every 3.0s, and the buzz body — the "zzz" — is the star, not sparkle.

Use the **Sound Effects** generator, duration **1.5 seconds** (hard cap: must
stay under the 3.0 s fire interval), prompt influence ~65%. Generate 4–6
takes and pick by ear.

> A single electric zap sound effect for a video game: a semi-deep, resonant
> "bzzzzzt" — a low, meaty electrical buzz like a heavy tesla-coil arc, with
> a soft crackling fizz layered quietly on top. The buzz is the star:
> sustained, vibrating, satisfying, pitched low-mid — not high, not thin,
> not sizzly. Quick soft attack, about one second of strong buzzing, then a
> short natural fade-out. Warm and rounded, pleasing to hear again and again,
> no harshness, no piercing highs, no deep bass boom, no melody, no whoosh,
> no riser. 1.5 seconds.

Keep criteria (it fires every 3 s for as long as the player holds 150% —
"pleasing on the 20th repeat" outranks "impressive once"):
* the ZZZ body dominates — if it reads as "tssss" it's too high; "bzzzz" is
  right (roughly the 100–300 Hz register carrying the weight);
* one clear zap event with a real ending — silence must follow before the
  next fire (no long ringing tail);
* nothing piercing above ~9 kHz (it sits under gunfire + music at alias
  vol 85);
* play the keeper ~10 times in a row before installing — that is exactly how
  the player hears it.

Install conversion (bank contract 48k/s16; measure before touching levels —
memory: audio-tooling):

```
ffmpeg -i in.mp3 -ar 48000 -ac 2 -c:a pcm_s16le -af "afade=t=out:st=0.9:d=0.2" ^
  sound_assets\tod\sfx\tod_luck_overmax_zap.wav
```

Aim its RMS near the luck pips' (aliases: pips 84/84, this 85/85 — the
audible band is 80–96; if the take lands hot, trim with `volume=` rather than
raising the alias).
