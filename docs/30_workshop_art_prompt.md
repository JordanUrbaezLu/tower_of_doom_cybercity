# 30 — Workshop / map-card key art: the prompt (2026-08-23)

> **STATUS: PROMPT READY — art not yet delivered.** Two deliverables, both
> LOOSE FILES in `usermaps\zm_tower_of_doom\zone\` (KB §11: no zone line, no
> GDT, no rebuild — edit → sync → republish):
>
> | Surface | File | Final size | Generate at |
> |---|---|---|---|
> | Steam Workshop thumbnail (square) | `zone\workshopimage.png` (pointed at by `workshop.json` `"Thumbnail"`, ABSOLUTE path) | **512×512** | 2048×2048, downscaled here |
> | In-game map card (map-select, bottom-left) | `zone\previewimage.png` | **600×340** exactly (anything else renders stretched) | 2400×1360 (same 30:17 ratio), downscaled here |
>
> Never let one file serve both surfaces (the square stretched onto the card
> is the classic mistake). The loading screen is NOT achievable for a usermap
> — do not ask for one.

User brief: "an exaggerated tower leaning from the left-bottom corner of the
image towards the top right ... a cartoonish deck of cards on the left top
corner. Tower on the right side, luck cards upper left. 3 versions to choose
from. It's supposed to catch eyeballs while keeping the essence of the map."

Two-step, as with the card sets: PROMPT 1 = three directions of the SQUARE on
one contact sheet; PROMPT 2 = the chosen direction built out as the square +
the landscape card.

---

## PROMPT 1 — three directions (square, contact sheet)

Attach as references: `i_tod_card_luck_ultimate.png`,
`i_tod_card_sprint_super.png`, `i_tod_card_damage_regular.png` (the card
style), plus 2–3 in-game screenshots of the spiral tower at night (the base
arena in the smog, a mid-tower balcony with the edge-lit floors, the crown
at the top) if you have them.

> Key art for a Call of Duty: Black Ops III custom zombies map called
> **TOWER OF DOOM: CYBERCITY**. Square canvas, 2048×2048. Make THREE
> distinct versions on one contact sheet (A / B / C), each a complete
> composition — I will pick one.
>
> **The map's essence (keep this in every version):** a single colossal
> tower in a neon cyber-city at night — a solid dark core with an OPEN-AIR
> STAIRCASE SPIRALLING around its outside, floor after floor, every floor
> edge lit in a different glowing colour that cycles up the tower (cyan,
> magenta, amber, green, violet) like a Tron grid. The base sits in thick
> purple-blue street smog shot through with neon; the higher the tower
> climbs, the clearer the air, until the top breaks into a clean night sky
> over a Miami-style skyline glow. At the very top floats a small glowing
> CITADEL — a square open-top fortress with four corner towers, two gate
> spires, a cyan cornice and an inverted-ziggurat underbelly — joined to the
> tower by a short causeway, with an antenna mast on the tower's crown.
> Zombies (hordes, tiny at this scale) pour up the spiral; a hulking armored
> PANZER mech with a glowing faceplate stands on one landing. Palette: deep
> navy and black, neon cyan and magenta, hot amber, a purple smog floor.
>
> **Composition (mandatory in all three):** the tower is EXAGGERATED — far
> taller and more dramatic than any real building — and it LEANS
> diagonally: its base is planted in the lower-left of the frame and it
> sweeps up and to the right so its crown and the citadel sit in the TOP
> RIGHT, with a slight curve and forced perspective as if shot from the
> street looking up. The tower owns the RIGHT side of the frame. The UPPER
> LEFT is open sky, and in it floats a **cartoonish fanned DECK OF CARDS**
> — the map's upgrade cards: dark navy card bodies, a rounded outer frame
> with four corner screws, an amber title plate on top, an inset screen
> with a flat bold-outlined icon, a ribbon and a round star medal, and a
> row of pips (use the attached cards — do not invent a new card design);
> three to five cards fanned like a poker hand, the front one glowing gold
> (ULTIMATE), one purple (SUPER), the rest plain, with a few sparkles and
> a faint amber "luck" glow behind them, slightly tilted toward the tower
> as if being dealt to it. The title **"TOWER OF DOOM"** in big bold
> rounded caps (white with a thick dark outline, the same lettering as the
> cards' title plates) with **"CYBERCITY"** smaller beneath it in neon
> cyan, placed where the composition leaves room (lower-left over the smog
> is the natural spot) — never covering the cards or the citadel.
>
> **Style:** bold, saturated, poster-like — a stylized semi-cartoon
> illustration with clean thick outlines on the cards and crisp neon
> bloom on the tower, NOT photoreal, NOT a screenshot. It must read
> instantly as a 512-pixel Workshop thumbnail: one huge silhouette (the
> leaning tower), one bright focal (the cards), one title. High contrast,
> no clutter, no tiny text, no watermark.
>
> **Make the three versions differ in ATTITUDE, not in the brief:**
> **A** "street view" — camera low in the smog, the tower's base huge and
> near, extreme upward lean, citadel tiny and far; **B** "poster" — the
> whole tower visible with a clean curved lean, skyline behind, the most
> balanced of the three; **C** "chaos" — zombies visibly flooding the
> lower spiral, the Panzer mid-frame, neon sparks and card sparkles
> crossing the diagonal, the most energetic. Label each A / B / C on the
> sheet.

---

## PROMPT 2 — build-out (after choosing A / B / C)

> Lock version **X** from the contact sheet. Produce two finished files:
>
> 1. **`workshopimage.png` — 2048×2048 square**, the chosen composition
>    exactly as shown, title included, no contact-sheet label, fully
>    rendered.
> 2. **`previewimage.png` — 2400×1360 landscape (30:17)**, the SAME scene
>    re-composed for the wide frame: the leaning tower still anchored
>    lower-left sweeping to the top right and owning the right half, the
>    fanned cards in the upper left, the skyline stretching across the
>    extra width. **No title text on this one** — the game prints the map
>    name beside it — but keep the cards' own baked text. Nothing important
>    within 5% of any edge (the card sits in a rounded frame).
>
> Same palette, same lettering, same card design as the sheet. Deliver both
> at full size as PNG.

---

## After the drop (what the session will do)

Downscale the square to exactly **512×512** → `zone\workshopimage.png`;
downscale the landscape to exactly **600×340** → `zone\previewimage.png`
(ffmpeg, lanczos). Sync. `workshop.json` `"Thumbnail"` must point at the
square by ABSOLUTE path. Proof the in-game card in the map-select screen
(600×340 = no stretch) before republishing.
