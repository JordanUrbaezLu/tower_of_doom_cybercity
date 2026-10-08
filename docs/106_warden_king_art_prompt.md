# 106 — THE WARDEN KING: the summit boss's two plates (art pack)

<!-- art-pack
name: warden_king
refs:
  i_tod_trial_7.png | THE TRIAL VII banner, THE THRONE — the last hall before the king; the series chassis (crimson Tron-grid plate, gold tracery, red numeral + rim) the two new plates continue. Attach to every prompt.
  i_tod_trial_1.png | THE TRIAL I banner — the same series at its gold end. Attach for the family look.
  i_tod_trial_won.png | THE TRIAL IS WON plate — the gold-shifted rim, the radial burst behind white letters. The KING IS DEAD plate is its bigger sibling. Attach to prompt B.
  i_tod_spire_banner.png | THE SPIRE arrival banner — the wide-format banner that opens the mode. Context.
preview: 600x150
-->

> **STATUS: SHIPPED v17.71 (drop `files - 2026-09-05T023723.610.zip`, 02:37, installed the same hour) — UNPLAYED.** Both plates proofread (THE SUMMIT / THE WARDEN KING; THE SUMMIT / THE KING IS DEAD), alpha profile identical to the trial banners' (transparent outside the plate), wired exactly as the install note below says; review sheet kept at `docs/106_king_ref_review.png`.
>
> **(Original) STATUS: COMMISSIONED 2026-09-05 (v17.70).** User: *"the boss fight will be
> one panzer ... He will have a health bar ... His health bar will actually be
> the spire bar."* The bar needs no art (it is the spire gauge, full and
> draining). What the fight still prints as plain text are its two moments:
> the king's arrival at the seal and his death — both are `IPrintLnBold`
> placeholders in `_tod_spire.gsc` (`king_run` / `king_win`) until these two
> plates land. Pack built by `.\tools\make_art_pack.ps1
> docs\106_warden_king_art_prompt.md` → `~/Downloads/tod_warden_king_art_pack.zip`.
>
> **Install when the drop comes back** (new names, so this is wiring, not a
> copy): `i_tod_king_banner.png` + `i_tod_king_dead.png` into
> `source_data/tod_ui_images/_images/`; GDT: clone the `i_tod_trial_7` /
> `tod_trial_7` image+material pair twice with the two names; zone: `image,`
> + `material,` lines beside the trial banners' block; `_tod_spire.gsc`:
> `#precache( "material", "tod_king_banner" )` and `"tod_king_dead"`, then
> `level thread trial_banner( 0, "tod_king_banner" )` in place of the
> `IPrintLnBold( "THE WARDEN KING" )` and `trial_banner( 0, "tod_king_dead" )`
> in place of `IPrintLnBold( "THE KING IS DEAD - THE WAY IS OPEN" )`. FULL
> build; proof = fresh content-hash `.iwi` beside an untouched control. Flip
> this STATUS to SHIPPED.

## The fight, for context (repo-facing)

Floor 70's hall is THE THRONE, trial VII. One gold flight up is THE TOP — a
1408-square arena deck over the last hall with the beacon mast at its centre,
four cover pillars, a 1000-point crate and the extraction pad. When every
living player is on the deck, the stair's mouth seals (the ritual barrier),
ten seconds pass, and THE WARDEN KING drops — one Panzer, 100M health, twice
the flame, twice the zap range, his summons on a cadence; the spire gauge on
the right edge is his health bar, lit to the summit and draining. Before the
fight the world freezes: every upgrade is maxed, then the dark cards are dealt
ten seconds at a time until nobody has one left. Kill him and the extraction
unseals.

<!-- PACK:BEGIN -->
# TOWER OF DOOM: CYBERCITY — THE WARDEN KING (2 files)

You are the art director and image generator for the HUD of **Tower of Doom:
Cybercity**, a Call of Duty: Black Ops III custom zombies map. You delivered
the seven **TRIAL I..VII banners** (open `reference/i_tod_trial_7.png` — THE
THRONE, the last of them — and `i_tod_trial_1.png`) and **THE TRIAL IS WON**
plate (`reference/i_tod_trial_won.png`). This job is **two more plates in that
exact series** for the fight that comes after the seventh trial: **THE WARDEN
KING**, a single giant boss (an armoured mech with a flamethrower) who holds
the top of the tower.

Both are **2048 × 512**, PNG-32, transparent outside the plate, shown at
600 × 150 on a 1280 × 720 layout (900 × 225 at 1080p), centred above the
middle of the screen for five seconds. Same plate, same margins, same
typeface, same gold circuit tracery as the trial banners.

## Deliverables (exact filenames)

| # | file | size | what it is |
|---|---|---|---|
| A | `i_tod_king_banner.png` | 2048 × 512 | THE WARDEN KING — shown as the gate seals and he drops |
| B | `i_tod_king_dead.png` | 2048 × 512 | THE KING IS DEAD — shown when he falls |

**Prompt A — `i_tod_king_banner.png`** (attach `i_tod_trial_7.png`,
`i_tod_trial_1.png`; `i_tod_spire_banner.png` is the mode's opening banner —
context for the wide format, not to be redrawn):

> A wide HUD event banner, exactly 2048 by 512 pixels, PNG with a transparent
> background outside the plate, in the identical style as the attached trial
> banners: the same black-to-crimson Tron-grid plate with thin gold circuit
> tracery, the same margins and typeface. This is the BOSS plate that follows
> the seventh trial. Left third: instead of a roman numeral, a large glowing
> line-art CROWN in gold neon (#FFD959) with a red inner stroke — five points,
> the centre point tallest, jewel dots on the points. Right two-thirds: the
> word "THE SUMMIT" small in gold above the name "THE WARDEN KING" in white
> neon, condensed all-caps, larger than any trial name. The plate's rim glow
> is red and gold together — red on the lower edge, gold on the upper.
> Behind the text a faint line-art glyph of a mech helmet with a single
> visor slit, in red at low opacity. No characters, no other text.

**Prompt B — `i_tod_king_dead.png`** (attach `i_tod_trial_won.png`,
`i_tod_trial_7.png`):

> A wide HUD event banner, exactly 2048 by 512 pixels, PNG with a transparent
> background outside the plate, in the identical style as the attached THE
> TRIAL IS WON plate: the same dark crimson Tron-grid plate with gold circuit
> tracery, the same margins. The plate reads a small gold word "THE SUMMIT"
> above a large white glowing title "THE KING IS DEAD", with a gold radial
> burst behind the letters twice as strong as the attached plate's, and the
> plate's rim glow fully gold. In the left third, faint at low opacity, the
> same gold line-art crown as the king's banner, tipped over on its side.
> No other text, no characters.

## Delivery checklist

- Exact filenames, lower-case. **2048 × 512** both. Do not pad, crop or add
  a border.
- PNG-32 with an 8-bit alpha channel; transparent outside the plate.
- Proofread: "THE WARDEN KING" and "THE KING IS DEAD" exactly, "THE SUMMIT"
  as the small gold word on both.
- Open both at 30 %: the crown reads, the names read, the plates sit beside
  `i_tod_trial_7.png` as the same series.
- One zip. Two files.

## What NOT to do

- No numeral on either plate — the numerals were the trials'.
- No photo-real mech, no character art; a line-art helmet glyph at low
  opacity is the most figure allowed.
- No new plate shape or typeface; no drop shadow outside the plate; no text
  smaller than the trial banners' "TRIAL" word.
<!-- PACK:END -->
