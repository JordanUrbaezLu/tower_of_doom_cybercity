# 172 — The level pips on every upgrade card

STATUS: BUILT 2026-10-04 (v19.74 - build facts in CHANGELOG v19.74 / CLAUDE.md). UNPLAYED.

User, 2026-10-04: *"One issue we have right now is that players arent really aware of
what basic, super, and ultimate even mean and will pick up a basic instead of ultimate
when in long run the ultimate is way better. All i want from you is a visual upgrade on
all the cards that has to be custom and not part of the actual card but should look
like it. This visual should match what we do in tower of doom 2 where it shows all the
levels of that upgrade, fills in the level you are and then shows what the upgrade will
take you ... level 2 and get a super card: Fill Fill Purple Purple Empty ... maybe even a
small pulse animation on the purple dots ... highest quality ... blends in perfect with
the upgrade cards. I dont think this impacts dark upgrades at all."*

## What the player sees

Every dealt upgrade card carries ONE live row of dots, exactly where the card art's own
dots sat (bottom panel, under the effect text):

| dot | meaning | look |
|---|---|---|
| CYAN | a level you already own | the pause menu's own level-pip colour, so "cyan = mine" reads the same on every screen |
| RARITY colour, pulsing | a level THIS card adds | white = REGULAR (+1), violet = SUPER (+2), gold = ULTIMATE (+3): the colours the card's band and text already wear; the card art's halo ring around it |
| dark | room left in the upgrade | the card art's own empty dot |

The row has one dot per level of the upgrade at the player's REAL cap (per class: DMG
REDUCTION is 3 / 5 / 9 / 10). So level 2 of 5 + a SUPER card = cyan cyan violet violet
dark — the user's "Fill Fill Purple Purple Empty".

Motion (Tower of Doom II's pull, adapted):
1. The row fades in as the card face finishes opening (60 ms + 100 ms).
2. The added dots light ONE AT A TIME (first at +90 ms, then every 120 ms), each stamping
   in from 1.6x (Bounce) with a flash of its glow and a core shine.
3. A beat later they BREATHE until the pick: a soft glow swells and fades around each
   added dot and its core brightens, 1.24 s a cycle (eased).
4. On the pick the taken card's new dots turn CYAN with one last pop — they are yours now.
   The passed card goes quiet. When the panel closes the dots fade out with it.

- A LOCKED promotion (tier card below its floor gate) shows held tiers + the tier it leads
  to, tinted like the card, and never lights or breathes.
- The TIER card's row is the class's tiers: tiers held cyan, the new tier white-on-gold.
- DARK cards are untouched: no live row, their baked red dots stay (user's call).
- Ten-level upgrades (DAMAGE, the heavy's DR, CHAIN LIGHTNING...) fit between the panel's
  screws: up to seven dots keep the art's pitch and size, eight and nine tighten the pitch,
  ten shrink the dots to 90%.

## How it is built

### The art — `tools/card_pips/build_card_pips.py`
- TEN SPRITES (`i_tod_cardpip_empty / owned / gain_regular / gain_super / gain_ultimate /
  gain_tier / glow_regular / glow_super / glow_ultimate / shine`), rebuilt from the card's
  own dot: core r 11.5, black outline to r 16.5, rarity halo to r 22.1, a feathered
  highlight at (-3,-3). Fitted against the baked dots: mean error 0.16 (empty), 1.00
  (super), 0.91 (ultimate), 0.93 (tier) of 255. 48 texels = 48 card px, so a sprite has
  exactly the card art's texel density and filters like the card it sits on.
- THE CARDS: every zoned regular / super / ultimate card and the ten class-tier cards
  had a BAKED dot row (the rarity's +N, never the player's level). 140 cards had it
  painted out with their own flat panel colour inside a measured band (x 160..607,
  y 992..1060), after proving every changed pixel belonged to a detected dot on the baked
  58 px grid (zero refusals). A cover sprite cannot do this job: an unfocused card is
  drawn at alpha 0.4, and anything layered over a translucent card lets the baked dots
  show through and reads as a patch. Dark cards were not touched.
- Originals: `tmp/card_pips/originals/` + `tmp/card_pips/manifest.json` (sha256 before /
  after). `--restore` puts them back.
- Wiring: ten `image.gdf` blocks appended to `source_data/tod_ui_images.gdt` (compressed
  high color, like every UI image) and a GENERATED block in the zone after
  `image,i_tod_pause_pip_empty`. The `i_tod_cardpip_` prefix keeps them out of every
  `i_tod_card_<slug>_<rarity>` pattern (lint_tod_assets' dead-card gate, card tools).

```
python tools/card_pips/build_card_pips.py --install    sprites + GDT + zone + paint out dots
python tools/card_pips/build_card_pips.py --check      verify, write nothing (BUILD GATE)
python tools/card_pips/build_card_pips.py --preview D  mock cards with live rows -> D/*.png
python tools/card_pips/build_card_pips.py --restore    put every parked original back
```

**A NEW CARD DROP ARRIVES WITH BAKED DOTS.** `--check` (every build, `-GscOnly`
included) fails on it by name; `--install` paints them out. It also pins the sprites to the
generator, the GDT blocks, the zone block and the Lua's `PIP_*` geometry.

### The data — `_tod_upgrade_ui.gsc pips_push`
The card fields already carry the current level (`todUpgAL/BL`). The player's real cap
(`o.max` = `domain_max`) and the levels the card truly pays (`o.levels`: the headroom
clamp, and the rarity lock that deals MYSTICAL HANDS as an ULTIMATE paying 1) ride ONE int
per slot on the int-only event lane — zero clientfield bits (the pool is 61 of 61):

    code = domain_id * 256 + max * 16 + levels      (0 = no card in that slot)
    LuiNotifyEvent( &"tod_upg_pips", 2, codeA, codeB )   -- before todUpgShow = 1

The domain id rides along so a stale value can never paint another card. Dev log:
`[TOD_CARD_PIPS] DEAL player= a=<key>/lv<cur>+<levels>of<max>/r<rarity>/code<n>[/dark][/locked] b=...`
(tod_dev).

### The row — `tod_upgrade.lua` (`CardPips`, file scope)
- `CardPips.Build` per card: a root (joins `card.group`, so the row takes every alpha the
  card takes) holding 3 glows, 10 dots, 3 shines and two invisible metronomes; the root
  closes its own children (`TodUIOwnership`, LUI close never cascades). 19 elements a card.
- `CardPips.Info( dom, rar, cur, ev )`: the cap is the event's (when its domain matches),
  else `CoD.TodOwned`'s synced cap, else `DOMAIN.max`; the gain is the event's levels,
  else the rarity's +N. The CAP wins a disagreement (the server clamps rarity to the room
  left), but an OWNED level is never hidden.
- `CardPips.Sync` once per Render per card: it lays the row out ONLY on a new signature
  (Render runs ~7 Hz during the focus blink and must never restart the motion). A landing
  during the reveal (the slot was empty) plays the light-up; anything else — the cap
  arriving late, a re-present — settles instantly.
- Every chain is a tween completing on an element the module owns (no UITimer); flags are
  cleared BEFORE any `completeAnimation`, and interrupted events never advance a chain.
- `CoD.TodCardPips` is exposed for the test; `panel.todPipRows = { a, b }`.

## Tests
- `tools/test_card_pips.lua` (lupa, in the build): layout for 1..10 dots, the wire
  (round trip, precache, sent before the panel opens), card info (the user's example,
  per-class cap, fallbacks, dark, tier, MYSTICAL HANDS, clamps), whole deals through the
  real panel (light-up order, breathing, 20 focus renders leave it alone, late cap, pick →
  cyan, passed card quiet, lone card, dark skipped, locked promotion quiet + tinted,
  unlocked tier lights), sprite names zoned + registered, and lifetimes. 7 negative
  controls: 6 caught, the 7th (locked + instant layout still breathing) is an equivalent
  mutant — `PulseStart` has its own lock guard.
- `tools/test_ui_lifetimes.lua` covers the rows with the rest of the menu (zero unclosed).

## Not proven natively
- That a tween on a bare `LUI.UIElement` (the metronomes) fires its completion event in the
  engine. Tower II's pull rides the same pattern; the test mock cannot prove the engine.
  If the dots light but never breathe, or never light at all, this is the first suspect.
- That the Panel's own per-render `completeAnimation()` does not reach its children. The
  stock `complete_animation` handler explicitly dispatches to children, which says the
  native call does not; if the breathing stutters at ~7 Hz while the cards are up, that is
  the cause (see the note in docs/52).

## Rollback
`USE_CARD_PIP_ART = false` in tod_upgrade.lua hides the live row (the cards then show NO
dots — the baked rows are painted out); `--restore` brings the baked rows back. Both =
the pre-docs/172 cards exactly.
