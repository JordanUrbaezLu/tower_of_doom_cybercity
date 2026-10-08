# 58 — ADRENALINE card art (v16 rework)

> **STATUS: COMPLETE 2026-09-01** (verified by OPENING the PNGs, not by the drop manifest). The three cards landed in user drop files (79).zip over already-wired assets, no wiring touched. They read **MULTI-KILLS GRANT SPEED** with 5 pips lit 1/2/3 — a DELIBERATE deviation from the spec below, which asked for an EMPTY value panel; kept because the line is accurate for the new trigger, carries NO numbers (so a percent or cooldown retune still owes no re-bake), and an empty panel reads as a missing asset. This status line said OPEN until 2026-09-01 while the art was already shipped — a status line is not evidence; open the PNG.
>
> <details><summary>original status</summary>
>
> **OPEN — art not baked.** The mechanic shipped 2026-09-01; the three
> cards are stale in **two** ways and both are baked into the PNG. Until they are
> re-cut the game shows a player a pip count and a promise that the code no
> longer honours.

**Everything below was read by OPENING THE SHIPPED PNG**, not from an older
prompt doc. `docs/33_upgrade_art_audit.md:113` still claims these cards say
"+6%" — they do not; they were re-baked numberless under docs/40 and that audit
never caught up.

---
>
> </details>

## What changed, and why the art has to move

ADRENALINE (domain 25, skirmisher, MP7) was: *every kill adds a stacking speed
burst, 3 stacks, 4s window, +4/6/8% per stack, max 3 levels.*

It is now: **3 kills inside 1.5s fire one 3-second speed burst, then the domain
locks out for 20 / 18 / 16 / 14 / 12 seconds by tier. Max 5 levels, +3% per tier.**

| | current PNG | required |
|---|---|---|
| Pips | **3** | **5** |
| Footer | `KILLS GRANT SPEED` | **no footer text at all** |
| Title | ADRENALINE | unchanged |
| Illustration | syringe with motion lines | unchanged *or* re-concepted |

**The pip count is not cosmetic.** In this set a domain capped at 5 or lower
draws pips equal to its cap; 6 or more draws a flat 3. Max 3 → 5 crosses that
line, so all three cards need 5 pips (1 lit / 2 lit / 3 lit by rarity).

**The footer must go, not be reworded.** "KILLS GRANT SPEED" is wrong — it is a
*multi-kill* trigger now. But the honest replacement would have to carry a
threshold (3 kills), a window (1.5s), a duration (3s), a percent (+3%/tier) AND
a cooldown ladder (20→12s), which does not fit and would go stale on the next
retune. **Ship it with no value text**, exactly as FORCED MARCH, SPRINT and
ATHLETE now do. The pause menu is server-fed and always current — it already
reads *"+N% move speed for 3s · 3 kills in 1.5s; cooldown 20s down to 12s"*.

---

## The files

Three re-bakes at identical filenames — **no wiring, no GDT rows, no zone
lines**, they are already installed and zoned:

```
i_tod_card_adrenaline_regular.png     768x1152   5 pips, 1 lit
i_tod_card_adrenaline_super.png       768x1152   5 pips, 2 lit
i_tod_card_adrenaline_ultimate.png    768x1152   5 pips, 3 lit
```

`i_tod_pause_r25.png` is a 300×44 name-only strip carrying no numbers — **it
does not change.**

⚠️ **A `.gdt`/image change is ALWAYS a FULL build**, never `-GscOnly`.
⚠️ **Batch this with ATHLETE's four images (docs/57)** — both are pending, both
need a full build, so one art pass and one build covers both.

---

## STEP 1 — THE EXPLORE PROMPT (concepts on one sheet)

> Draw a **single contact sheet, 4 concepts side by side**, for one upgrade card
> illustration in a Call of Duty: Black Ops III custom zombies map.
>
> **The upgrade is ADRENALINE.** A soldier scores three rapid kills and gets a
> short, violent burst of speed — then has to wait out a cooldown before it can
> happen again. The feeling is a *chemical surge*: earned, sudden, brief.
>
> **Art style — match it exactly:** flat vector, thick black outlines, bold
> saturated fills, subtle inner shading, a few small sparkle/dot accents. Dark
> navy background panel. Read clearly at **213×320 pixels** — no fine detail, no
> gradients beyond a soft sheen, no realism, no text anywhere in the image.
>
> **Four DISTINCT concepts, not four versions of one:**
> 1. A **syringe/injector** mid-burst — the current art's idea, refined.
> 2. A **heart or pulse motif** — a stylised heart with a spike trace tearing
>    off it, or an ECG line snapping upward.
> 3. **Speed-lines around a running silhouette** — the surge as pure motion.
> 4. A **charge/discharge motif** — something visibly *spent*, showing that this
>    is a resource with a cooldown rather than a constant buff.
>
> Number them 1-4. Same size, same framing, same palette family so they can be
> compared fairly. Dominant colour cyan/teal with a warm accent, matching a
> neon-cyberpunk UI set.

---

## STEP 2 — THE BUILD-OUT PROMPT (paste once a concept is chosen)

> Produce **three upgrade cards** for a Call of Duty: Black Ops III custom
> zombies map. They are re-bakes of an existing card set and must be
> **indistinguishable in style** from the cards already in it.
>
> **Study these shipped files first — they are the target style AND the target
> layout:**
> ```
> source_data/tod_ui_images/_images/i_tod_card_adrenaline_regular.png   (the card being replaced)
> source_data/tod_ui_images/_images/i_tod_card_giant_slayer_regular.png (the 5-pip reference)
> source_data/tod_ui_images/_images/i_tod_card_sprint_regular.png       (a card with NO value text)
> ```
>
> **Format:** 768×1152 RGBA PNG, transparent outside the card's rounded frame.
> Output at the exact filenames below, overwriting.
>
> **Card anatomy, top to bottom:** orange gradient title plate with the name in
> white outlined slab caps · dark navy illustration panel with flat vector art
> and thick black outlines · rarity banner reading `REGULAR +1`, `SUPER +2` or
> `ULTIMATE +3` with a circular medallion at the panel's lower-right · a bottom
> VALUE PANEL · a row of pips beneath it.
>
> **Rarity styling — per file, keep exactly:** REGULAR = silver medallion, grey
> banner, no outer glow. SUPER = gold medallion, violet banner, violet outer
> glow. ULTIMATE = gold medallion, orange-gold banner, warm outer glow.
>
> **THE TWO THINGS THAT MUST CHANGE FROM THE CURRENT CARD:**
>
> 1. **FIVE PIPS, not three.** `i_tod_card_giant_slayer_regular.png` already
>    carries 5 — match its dot size, spacing and centring exactly. Lit pips:
>    **1** on regular, **2** on super, **3** on ultimate.
> 2. **THE VALUE PANEL IS EMPTY.** Draw the panel exactly as it appears on the
>    other cards — same box, same inner border, same inset — but with **no text
>    inside it**. The current card says "KILLS GRANT SPEED"; that line is gone
>    and nothing replaces it. `i_tod_card_sprint_regular.png` is a card whose
>    value panel carries only words and no numbers; here even the words go.
>
> **Title plate:** `ADRENALINE` (unchanged).
> **Illustration:** [PASTE THE CHOSEN CONCEPT FROM STEP 1 HERE].
>
> **Files:**
> ```
> i_tod_card_adrenaline_regular.png
> i_tod_card_adrenaline_super.png
> i_tod_card_adrenaline_ultimate.png
> ```
>
> **Proofread before returning:** 5 pips on all three · lit counts 1/2/3 · value
> panel present but EMPTY on all three · no numbers anywhere · title unchanged ·
> rarity colours per file · filenames identical to the originals.

---

## Install order

These are re-bakes of already-wired assets, so it is simply:

1. Drop the three PNGs into `source_data/tod_ui_images/_images/`, overwriting.
2. **FULL build** (`.\tools\build_map.ps1`, no `-GscOnly`).
3. Prove they packed: a **fresh content-hash `.iwi` per file plus an untouched
   control**. A `.ff` raw grep is invalid (compressed) and a stale `.iwi` passes
   every other gate.

Nothing to add in `CARD_SLUG`, the GDT, or the zone — `CARD_SLUG[25]` and the
three zone lines already exist. **This differs from ATHLETE (docs/57)**, which
is new art and does need that wiring, with the trap that `CARD_SLUG` and
`PAUSE_PLATE_MAX` may only be touched *after* the PNGs are installed and zoned.

---

## While the art is out: what the code already says

Shipped and correct as of 2026-09-01, so the prompt above can be trusted against
it:

| | value | site |
|---|---|---|
| tiers | 5 | `add_domain( "adrenaline", ..., 5, ... )` |
| per tier | +3% of scale | `TOD_ADREN_PCT_PER_LV 0.03` |
| trigger | 3 kills / 1.5s | `TOD_ADREN_MK_NEED 3` / `_MK_WINDOW_MS 1500` |
| burst | 3s exactly | `TOD_ADREN_MS 3000` + `adren_expire()` |
| cooldown | 20/18/16/14/12s | `TOD_ADREN_CD_MAX_MS 20000` / `_STEP 2000` / `_MIN 12000` |
| cue | 3 synth heartbeats, 1.42s, 2d player-only | `TOD_ADREN_SFX "tod_adren_pulse"` |
