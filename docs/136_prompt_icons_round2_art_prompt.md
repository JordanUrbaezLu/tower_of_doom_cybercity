# 136 — PROMPT ICONS, ROUND 2: the four objects round 1 left on stock art

<!-- art-pack
name: prompt_icons_round2
refs:
  i_tod_prompt_icon_crate.png | ROUND 1's ammo crate — THE STYLE TO MATCH EXACTLY. Outline weight, palette, light direction and margin all come from this.
  i_tod_prompt_icon_door.png | round 1's door, the other most-seen icon: same construction, different subject
  i_tod_prompt_icon_extract.png | round 1's extraction beacon — the one that uses gold, showing how a warm accent sits in this set
  i_tod_prompt_icon_power.png | round 1's power switch, for how a mechanical object reads at this size
  i_tod_prompt_chassis.png | the card these sit in. The icon drops into the recessed well on its left.
preview: 66x66
-->

> **STATUS: SHIPPED 2026-09-14 (v19.4).** All four delivered at 256x256 RGBA and
> installed: PNGs in `_images/`, GDT blocks cloned from the round-1 door icon, zone
> lines beside round 1, and rows wired into `TodPromptCard.ICONS`. The drop carried
> each icon TWICE (loose + a nested folder); the pairs are PIXEL-IDENTICAL (decoded
> and compared, the byte difference is PNG compression), so the loose copies were
> taken. Margins were measured against the shipped six and sit inside their range —
> `altar` also touches the top edge, and `power` is as narrow as the new `perk`.
> The perk bottle is the GENERIC well art only: the nine machines keep their own
> per-perk `i_tod_perk_*` images, which are better.
> the card chassis and six icons and is in the game. This is the gap list found by
> running every live prompt string in the map through the icon table: four objects
> still draw either the kit's stock glyph or kit art, on our new chassis, which is
> exactly the inconsistency round 1 set out to remove.
>
> **THE TWO REAL GAPS** — these draw the stock "documents" glyph today:
> `RAMPAGE - currently ON/OFF` (the inducer in the base arena, which the player can now
> toggle at any round) and `RUN FOR THE CROWN` / `REACH THE CROWN` (the finale states on
> the Uplink, i.e. the most dramatic minute in the map).
>
> **THE TWO KIT-ART FAMILIES** — recognisable but drawn in the other game's style:
> Pack-a-Punch (`PromptPAP`) and the perk machines (`PromptPerks`, which maps a
> different image per perk). The perk set is nine images and is deliberately NOT in
> this round; one generic perk bottle is requested instead, to be used only if the
> per-perk art is ever dropped.
>
> **INSTALL:** identical to round 1 — copy into `source_data/tod_ui_images/_images/`,
> one GDT block + one zone `image,` line each, then add a row to `TOD_PROMPT_ICONS` in
> `PromptDefault.lua` (rampage, crown) and repoint `PromptPAP` / `PromptPerks`.

<!-- PACK:BEGIN -->

# PROMPT ICONS, ROUND 2 — 4 images

You already made a set of six object icons for this game's interaction prompts. These
four finish the set. **They must look like they were drawn in the same hour as the
first six** — attach every file in `reference/` and match them exactly: same outline
weight, same flat vector construction, same palette, same light from above, same
margin inside the square.

All four are **256 x 256, PNG, transparent background**, and are seen at about
**66 x 66 on screen**, so they must read as bold silhouettes.

| Filename | The object | Notes |
|---|---|---|
| `i_tod_prompt_icon_rampage.png` | **a glowing canister of unstable orange energy** in a heavy steel frame — a hazard device the player switches on to make the game harder | The one icon in the set that is **orange/amber**, not cyan. It should feel dangerous and deliberate: this is a switch you choose to pull. |
| `i_tod_prompt_icon_crown.png` | **a golden crown** | Use gold, matching the beacon in `reference/`. Simple regal silhouette, front-on, a couple of jewels at most. It marks the final objective. |
| `i_tod_prompt_icon_pap.png` | **a weapon upgrade machine** — a heavy industrial press or forge with a glowing slot where a gun is inserted | Cyan glow. Should read as a machine, not a workbench. |
| `i_tod_prompt_icon_perk.png` | **a perk bottle** — a stubby glass soda bottle with a cap and a bright liquid inside | Generic, no logo or lettering on the label. Cyan or green liquid. |

## Hard rules

1. **Exactly 256 x 256 each.** No other size.
2. **Transparent background.** The card has a recessed well behind them.
3. **No text, letters, numbers or logos anywhere** — including on the bottle label.
4. **Match the attached set.** If one of these is placed next to the crate icon and
   looks like a different artist drew it, it is wrong.
5. One object per icon, centred, filling most of the square with a small margin.

## Prompt you can paste

Attach all five files in `reference/` — `i_tod_prompt_icon_crate.png`,
`i_tod_prompt_icon_door.png`, `i_tod_prompt_icon_extract.png`,
`i_tod_prompt_icon_power.png` (the four icons to match) and
`i_tod_prompt_chassis.png` (the card they sit in):

> Four game UI object icons, each 256 x 256 pixels, PNG with a transparent background,
> drawn to match the attached reference icons exactly: flat bold vector shapes, heavy
> dark navy outline, soft inner shading, cyan accent lighting, light from above.
> The four objects: (1) a glowing canister of volatile orange energy held in a heavy
> steel frame, the only warm-coloured icon in the set, reading as a dangerous device;
> (2) a simple golden crown, front-on, regal, with minimal jewels; (3) a heavy
> industrial weapon-upgrade machine with a glowing cyan slot where a gun is inserted;
> (4) a stubby glass soda bottle with a metal cap and bright glowing liquid inside, no
> label text. Each centred with a small margin, bold enough to read at 66 pixels.
> No text, no numbers, no logos.

## Delivery checklist

- [ ] 4 PNGs, exact filenames, 256 x 256, transparent
- [ ] no text or logos in any of them
- [ ] placed beside the reference icons they look like one set
- [ ] the rampage canister is the only warm-coloured one

## Do NOT

- Do not restyle or redeliver the six icons from round 1; they are already in the game.
- Do not put a brand, word or number on the perk bottle.
- Do not make the crown ornate — it is 66 pixels on screen.

<!-- PACK:END -->
