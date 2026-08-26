# Steam Workshop description — zm_tower_of_doom

Mirrors map 1's `docs/38_steam_workshop_marketing.md` house style: `[h1]` section
heads with a leading glyph, `[hr][/hr]` between sections, `[list]/[*]` for
bullets, `[b]` for emphasis.

**Steam Workshop accepts only these tags** (map 1's §1, verified there):
`[b] [i] [u] [strike] [h1] [h2] [h3] [url] [img] [list]/[olist]/[*] [quote]
[code] [spoiler] [hr][/hr]`. No comments, no CSS, no nesting beyond these.

**The `[img]` lines are PLACEHOLDERS.** Replace each `REPLACE-WITH-STEAM-CDN-URL`
with a real Steam-CDN link (upload the shot to the Workshop item first, then copy
its image URL). Any you forget render visibly broken, which is how you will
notice.

Every number below was read from source on 2026-08-25: 36 upgrade domains
(`_tod_upgrades.gsc`), 22 generated weapons (`gen_tod_twins.js`), 45 concurrent
zombies (`_tod_corpse_cleanup.gsc`), Panzer every 5 / Protector every 3 /
hellhounds every 3 (`_tod_bosses.gsc`, `_tod_hellhounds.gsc`), upgrade event
every 4 rounds (`_tod_upgrades.gsc`), extraction 12,000 (`_tod_finale.gsc`).
Re-check them if any of those change.

---

```
[img]REPLACE-WITH-STEAM-CDN-URL/header-shot.jpg[/img]

[h1]TOWER OF DOOM: CYBERCITY[/h1]
[b]Fifty floors up the outside of the building. The rounds never stop.[/b]

The staircase spirals up the [b]outside[/b] of the tower, so every step of the climb is in
the open air with a long drop on one side and nothing to hide behind. And the moment the
last zombie of a round spawns, the next round begins — no break, no round-change fanfare,
no window to reset your setup.

[b]How far up can you get?[/b]

[hr][/hr]

[img]REPLACE-WITH-STEAM-CDN-URL/climb-shot.jpg[/img]

[h1]⬆ THE CLIMB THAT NEVER LETS UP[/h1]
There is no pause between rounds. The horde keeps arriving while you keep climbing, and it
arrives [b]45 strong at once[/b] — nearly double a normal map. Every floor is bought with
points, every floor is open to the sky, and the only way out is up.

[hr][/hr]

[img]REPLACE-WITH-STEAM-CDN-URL/classes-shot.jpg[/img]

[h1]🔫 FOUR CLASSES. TWENTY-TWO GUNS.[/h1]
Draft a class at the start and commit to it. Each one has its own move speed, a three-tier
primary ladder [b]and[/b] a three-tier sidearm ladder:
[list]
[*][b]SKIRMISHER[/b] — MAC-10 · MP5 · MP7, with a Bulldog, SG12 and SPAS-12 on the side
[*][b]ASSAULT[/b] — Enfield · Krig 6 · AK-47, backed by a Magnum, MOG 12 and Executioner
[*][b]HEAVY[/b] — Stoner 63 · HK21 · Death Machine, plus an RPG and a nail gun
[*][b]SLASHER[/b] — Combat Knife · Wakizashi · Stormbreaker, with a UDM and RK7
[/list]
[b]No mystery box. No wallbuys.[/b] Your class gun is your gun — you upgrade what you are
holding, or you earn the next tier.

[hr][/hr]

[img]REPLACE-WITH-STEAM-CDN-URL/upgrade-shot.jpg[/img]

[h1]⚙ BUILD IT AS YOU CLIMB[/h1]
Every fourth round the world stops and you pick [b]one of two cards[/b] — fifteen seconds,
no take-backs. Thirty-six upgrade domains: damage, fire rate, penetration, reload speed,
life steal, luck and more, each stacking level on level.

A [b]luck bar[/b] built from your kills, your headshots and your revives decides how strong
the roll is. Play well and the tower offers you better.

[hr][/hr]

[img]REPLACE-WITH-STEAM-CDN-URL/boss-shot.jpg[/img]

[h1]☠ THE TOWER FIGHTS BACK[/h1]
[list]
[*][b]Panzers every 5 rounds[/b] — and they follow you up
[*][b]Rogue Protector waves every 3[/b], scaling with the round and the party
[*][b]Reavers and hellhounds[/b] once you have climbed far enough to let them in
[*][b]All 8 perk machines are scattered at random[/b] and reshuffle as you climb — there is
no memorised route, you find them again every run
[/list]

[hr][/hr]

[img]REPLACE-WITH-STEAM-CDN-URL/breather-shot.jpg[/img]

[h1]🛗 REST FLOORS[/h1]
Every ten levels the tower gives you a balcony worth stopping on: [b]ammo crate[/b],
[b]upgrade terminal[/b], [b]Pack-a-Punch[/b] and [b]two-way teleporters[/b] linking to a
bought bay back at the base.
Nothing spawns on them. They are the only rest you get.

The soundtrack climbs with you too — four tracks that hand off as you pass the rest floors,
and the Panzer brings his own.

[hr][/hr]

[img]REPLACE-WITH-STEAM-CDN-URL/finale-shot.jpg[/img]

[h1]🏆 THE LAST SONG[/h1]
Reach the terrace at the top and buy [b]EXTRACTION[/b]. The gate opens, the closing song starts, and the
tower gauge on your right empties out and becomes your clock — it fills as the song plays,
and when it is full the map is over.

You get [b]ninety seconds[/b] to run the bridge to the citadel while everything left in the
tower comes at you from both sides. Then the door seals behind you and you hold the crown
until the final chord.

[b]Survive the song and you escape. Don't, and the tower keeps you.[/b]

[hr][/hr]

[h1]DROP IN[/h1]
[list]
[*]Solo or 4-player co-op
[*]Endless rounds — no downtime, ever
[*]4 classes, 22 weapons, 36 upgrade domains
[*]Randomised perk placement, so no two runs are the same
[*]A real ending with a real win condition
[/list]

[b]How far up can you get?[/b] Subscribe, climb, and find your floor.

[hr][/hr]

[h1]CREDITS[/h1]
[b]Music[/b]
[list]
[*]"Password Infinity" — Evgeny Bardyuzha
[*]"Cyberpunk Futuristic City" — lnplusmusic
[*]"Cyber Relay" and "Data Spike" — Psychronic
[*]"Cyber Eclipse" — bykenneth
[*]"You See Big Girl" — Hiroyuki Sawano / Gemie
[/list]
[b]Art & UI[/b]
[list]
[*]Nastian — Miami night skybox
[*]emox — MWIII Vertigo materials
[*]Owen-C137 — Aetherium HUD kit
[/list]
[b]Weapons & enemies[/b]
[list]
[*]Skye — weapon ports
[*]pmr360 — BOCW Wakizashi
[*]WetEgg, M5_Prodigy, J.G., DeLeon & Santa Monica Studio — Leviathan Axe
[*]Spiki — mechz pack (Panzer)
[*]HB21 — Apothicon Fury (Reaver)
[*]HarryBo21 — Civil Protector v2 (Rogue Protector)
[*]GentlemanCheeseMan — Gift of Death pack
[*]ZoekMeMaar — thunderstorm FX and free Pack-a-Punch
[*]NSZ — Zombie Blood
[/list]
[i]Built with the Treyarch Black Ops III Mod Tools.[/i]
```
