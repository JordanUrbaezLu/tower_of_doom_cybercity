# 72 — CLASS TIER 3 MOVES TO FLOOR 30: badge re-bake (1 image) + the lockstep

> **STATUS: SHIPPED v16.43, 2026-09-02 — UNPLAYED.** Pack went out as
> `~/Downloads/tod_tier_gate_30_art_pack.zip`; the drop came back the same
> hour as `files (100).zip` (top-level PNG + nested `tod_tier_gate_30.zip`,
> pixel-identical, md5 4dbb18d9…). Verified before install: 420×90 colortype 6,
> reads TIER 3 AT FLOOR 30, and a per-pixel diff against the shipped file shows
> 0 of 30,600 pixels changed left of x=340 (only columns 349..371, the tens
> digit, differ); the emblem region matches `i_tod_tier_gate_2.png` exactly.
> Installed under its existing name; §4 items 1, 2 and 4 applied in the same
> commit, plus two free in-world toasts (`tier_gate_toasts`, CHANGELOG v16.43).
> FULL build 13:29:30: packing proven by the NEW content-hash
> `i_tod_tier_gate_3_QQ45TDN23IO54M6WKSPJYZ5E5A.iwi` (13:29:18) beside the
> untouched `i_tod_tier_gate_2_…` control (2026-08-30 mtime). That build also
> swept up a peer's in-progress spire-gauge zone lines (images missing,
> default-substituted), so the peer's following full build is the one to test.

**Why (user, 2026-09-02):** *"We need to move tier 3 upgrade to floor 30
instead of floor 20."* The T3 promotion now needs the class gun Pack-a-Punched
AND a climb high-water of floor 30 (was 20). Tier 2 stays at floor 10.

## 1. The ONE new asset

The floor number is BAKED into the tier-gate badge (docs/50), so the retune is
not finished until this PNG is re-baked:

| File | Reads now | Must read | Shown when |
|---|---|---|---|
| `i_tod_tier_gate_3.png` | TIER 3 AT FLOOR 20 | **TIER 3 AT FLOOR 30** | player is tier 2, gun PaP'd, high-water below floor 30 |

Same name, same 420×90 RGBA canvas, same chassis. A same-name re-bake needs
NO GDT block, NO zone line and NO Lua edit — the PNG is replaced under its
existing `tod_ui_images.gdt` block.

**Nothing else carries the number.** Checked 2026-09-02 by opening the PNGs:
the eight tier CARDS (`i_tod_card_tier_<class>_2|3`) carry TIER header, gun,
class banner, gun name and tagline only — no floor. `i_tod_tier_gate_2.png`
(TIER 2 AT FLOOR 10) is untouched. The pause-menu CLASS TIER row draws its
detail line as LUI text (docs/50 "what does NOT need art"), so it is a Lua
string, not an asset.

## 2. Hard specs (unchanged from docs/50)

- Canvas exactly **420 × 90**, PNG, RGBA, fully transparent background.
- Drawn at **280 × 60** on screen (1.5× downscale) — no hairlines, no type
  below the shipped size.
- **Pixel-identical chassis to the attached `i_tod_tier_gate_2.png`**: same
  steel pill, same amber stacked double chevron on the left disc, same sparkle
  glyphs, same typeface, cap height, letterspacing and baseline. The two badges
  swap at runtime by tier; any drift makes the badge visibly jump.
- Copy, exact: `TIER 3 AT FLOOR 30` — white, `30` in the chevron amber, `AT`
  smaller and dimmer (as shipped).

## 3. The prompt (attach `i_tod_tier_gate_3.png` — the shipped one — AND `i_tod_tier_gate_2.png`)

```text
Here is a finished Black Ops 3 zombies HUD badge (attached: i_tod_tier_gate_3.png,
reading "TIER 3 AT FLOOR 20") and its sibling (i_tod_tier_gate_2.png, reading
"TIER 2 AT FLOOR 10"). Produce a corrected version of the first one.

Canvas exactly 420 x 90 pixels, PNG, fully transparent background (RGBA) -
identical to the attached files.

Change EXACTLY ONE THING and nothing else:
- "FLOOR 20" becomes "FLOOR 30"

Everything else must be pixel-identical to the attached i_tod_tier_gate_3.png:
the same pill shape and size, the same steel-blue stroke colour and weight, the
same glow, the same amber stacked double chevron in the same position at the
same scale, the same sparkle glyphs, the same typeface, the same cap height, the
same letterspacing, the same baseline, and the same overall composition width.
"TIER 3" and "AT" and "FLOOR" do not move. Keep "30" in the same amber that "20"
is in. The badge swaps places at runtime with the attached i_tod_tier_gate_2.png,
so any drift in position or scale will make it visibly jump on screen.

Deliver as i_tod_tier_gate_3.png.
```

## 4. THE LOCKSTEP — everything that moves in the same commit as the PNG

docs/50 listed three homes for the floor. There are FOUR, and the fourth is
a latent bug at 30, not 20:

1. `_tod_upgrades.gsc:599` — `#define TOD_TIER3_FLOOR 20` → `30`. The gate.
2. `tod_upgrade.lua` `DETAIL[24].act` (~:381) — `"tier 3: Pack-a-Punch +
   floor 20"` → `floor 30`. The pause-menu CLASS TIER row (shown from tier 1).
3. `i_tod_tier_gate_3.png` — this re-bake.
4. **`tod_upgrade.lua` ~:1799 `local nextTier = math.floor( need / 10 ) + 1`.**
   That is the inverse of `(tier-1)*10` and is only right while the ladder is
   10/20. At `need = 30` it yields tier **4**, `art.tierGate[4]` is nil, and the
   panel falls back to the text line `CLASS TIER 4 - REACH FLOOR 30` — the
   badge art would silently stop drawing for every tier-2 player. Replace the
   arithmetic with an explicit inverse table `{ [10] = 2, [30] = 3 }` (default
   2), LOCKSTEP with `tier_floor_req`. docs/50's line "the tier number is not a
   fourth home" stops being true the moment the spacing is uneven.

Comment/doc mentions to update in the same pass (no behaviour): `_tod_gauge.gsc`
header + poll comment ("floor 20 for 3rd"), `_tod_powerups.gsc:223`, docs/25
§ (the user quote stays, the rule line moves), docs/50 table, CLAUDE.md line
"floor 20 for T3", and the next docs/68 patch-note section ("Class Tier 3 now
unlocks at floor 30").

`tier_floor_req`'s tier-4 fallthrough becomes `(4-1)*(30-10) = 60`; no tier 4
exists, so it is inert either way.

## 5. Install (when `files (N).zip` lands)

1. Extract to scratch; read the PNG header (420×90, colortype 6); LOOK at it;
   proofread `TIER 3 AT FLOOR 30`; diff against `i_tod_tier_gate_2.png` for
   chassis drift (overlay or pixel-compare everything left of the digits).
2. Copy over `source_data/tod_ui_images/_images/i_tod_tier_gate_3.png`.
3. Apply §4 items 1, 2 and 4 in the same commit.
4. **FULL build** (an image swap never links under `-GscOnly`).
5. Prove packing: a NEW content-hash
   `<tools>/share/assetconvert/image/v29/i_tod_tier_gate_3_<HASH>.iwi` with a
   fresh mtime, beside an untouched control (`i_tod_tier_gate_2`'s files keep
   their old mtimes).
6. Flip this STATUS to SHIPPED with the build version; CHANGELOG entry.
