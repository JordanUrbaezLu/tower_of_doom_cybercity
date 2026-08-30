# Steam Workshop description — zm_tower_of_doom

**Steam Workshop accepts only these tags** (map 1's §1, verified there):
`[b] [i] [u] [strike] [h1] [h2] [h3] [url] [img] [list]/[olist]/[*] [quote]
[code] [spoiler] [hr][/hr]`. No comments, no CSS, no nesting beyond these.

This revision (2026-08-28) drops the `[img]` placeholders the previous draft
carried — add screenshots back by uploading them to the Workshop item first and
pasting the Steam-CDN URLs into `[img]` lines between sections.

## Every claim below was re-read from source on 2026-08-28

Six errors were found and fixed in the previous draft. If any of these change,
this file is wrong again:

| Claim | Source |
|---|---|
| 50 floors | `gen_tower_map.js:157` `LAPS = 50` |
| rest stops at 10/20/30/40 | `gen_tower_map.js:688` `BREATHER_LAPS` |
| **they are enclosed ROOMS, not balconies** (v13, 2026-08-28) | `gen_tower_map.js:701` — roof + walls + window bands, one colour each (10 blue / 20 green / 30 orange / 40 gold, `BREATHER_THEME:771`). Say "rooms"/"lounges", never "balconies" or "platforms". |
| window voids: `clip_player` but bullets pass | `gen_tower_map.js:712` — you can shoot out, and be shot |
| teleporter is OUTSIDE the room on an exposed gantry | `gen_tower_map.js:731` — spur has no roof and no risers |
| **rest stops DO spawn zombies** (2 risers each) | `gen_tower_map.js:3239` — added v10.12 on user request 2026-08-23, reversing the original zero-riser design. The old draft still said "nothing spawns on them"; a Workshop comment called it out. |
| 7 perks scatter, Quick Revive pinned at base | `_tod_perk_scatter.gsc:21,88` |
| perk reshuffle every 4 rounds (5, 9, 13…) | `_tod_perk_scatter.gsc:232` — decoupled from the Panzer, and from climbing |
| PaP makes TIER cards eligible; it does not itself promote | `_tod_upgrades.gsc` tier card = 20% of deals once the class gun is packed |
| upgrade event every 4th round, 15s to pick | `TOD_UPG_EVERY_N_SHIP 4`, `TOD_UPG_CHOICE_TIMEOUT 15` |
| **the world pause FREEZES zombies** (`ignoreall`, anim rate 0.05) | `_tod_upgrades.gsc::set_world_pause` — they do not "finish the leap"; the personal upgrade station is the one that does not pause |
| 33 live upgrade domains | `grep -c '^\s*add_domain('` = 33 (36 includes retired ids) |
| Panzer every 5 | `TOD_PANZER_INTERVAL 5` |
| Protector unlocked by the **floor-10 door**, then every 3 rounds | `_tod_doors.gsc::breather_unlock` `enter_lap10` |
| Reaver unlocked by the **floor-20 door**, then every **4** rounds | `breather_unlock` `enter_lap20`, `TOD_REAVER_INTERVAL 4` |
| **ARMORED SPRINTERS unlocked by the floor-30 door**, then every 3 rounds (v13.7, 2026-08-29) | `breather_unlock` `enter_lap30` -> "sprinter", `_tod_sprinter.gsc` — smoke-trailing armored converts, +10-round speed (was +15 -> +12 -> +10 same day), bullets ×0.33 |
| hellhounds unlocked by the **floor-40 door**, then every 3 rounds (moved from 30 in the same re-deal) | `breather_unlock` `enter_lap40` |
| music bands change at floors **10 / 23 / 37** | `_tod_atmosphere::register_music_bands` — only floor 10 is a rest floor, so "hand off as you pass the rest floors" was wrong |
| **EXTRACTION is bought on the TERRACE**, at the start of the road | `_tod_finale.gsc:18` — the crown is the destination, not the vendor |
| extraction 12,000 | `TOD_FINALE_COST 12000` |
| road 90s, then the crown door seals for a 101s hold-out | `TOD_FINALE_ROAD_SECS 90`, `crown_door_close()`, song = 191s |

---

```
[h1]TOWER OF DOOM: CYBERCITY[/h1]

Fifty floors. The staircase spirals up the [b]outside[/b] of the tower - open air, a long drop on one side, the horde on the other, nothing to hide behind.

[b]And the rounds never stop.[/b] The instant a round's last zombie spawns, the next round is already coming. No break, no fanfare, no moment to breathe you didn't pay for.

[b]But this one you can win.[/b] At the top of the tower there is a way out - if you can survive one last wave.

[h2]CLIMB OR DIE[/h2]

Buy your way up, door by door. Every tenth floor opens into a room you will have earned - the only walls in fifty floors of open air, open to the sky, each one lit in its own colour. The full Cold War Pack-a-Punch machine on one wall - animated, glowing, the works - an upgrade terminal on the next, an ammo crate on the third. There's a crate down at spawn too - cheap refills for a stock gun, double once it's Packed.

It is shelter, not safety. They come up through the floor in here too, and the window bands are open - you can shoot out through them at whatever is climbing past, and it can reach in. The teleporter home isn't even indoors: it sits out on an exposed gantry off the back of the room, over the drop.

The perks are up there as well - the Black Ops 6 and 7 machines, dark until you flip the power, including [b]BO7's Wisp Tea[/b] - earn it and your kills can summon a wisp that hunts beside you. [b]Eight of the nine scatter at random and reshuffle every few rounds[/b] - only Quick Revive keeps a fixed spot, down at the base. No memorised route. Every run, you hunt them down again.

[h2]YOUR GUN IS YOUR BUILD[/h2]

No mystery box. No wallbuys. Draft one of four classes - [b]Skirmisher, Assault, Heavy, Slasher[/b] - and carry its weapon ladder from a starter gun to monsters like the Death Machine and a leviathan axe. Pack-a-Punch your class gun and [b]TIER[/b] cards start turning up in the deal; take one and you jump to the next weapon on the ladder. Your gun grows because you did.

[b]Every fourth round the world stops dead[/b] - spawning halts, the horde stands down - and you get fifteen seconds to pick one of two upgrade cards: damage, fire rate, penetration, giant slayer, luck and more. Kills, headshots, revives and doors fill a luck bar that decides how strong the deal is.

Want a card sooner? The upgrade terminals sell you one mid-climb - but nothing freezes for those. You read your options with the stairs still filling up behind you.

[h2]THE TOWER FIGHTS BACK[/h2]

A Panzer drops in every fifth round, with his own soundtrack. And the tower unlocks a new hunter at every rest floor you buy your way into: [b]Rogue Protectors from floor 10, Reavers from 20, smoke-trailing armored sprinters from 30, hellhound packs from 40[/b] - each one joining the rotation for good. The zombies themselves only get faster.

The music climbs with you too: four tracks that hand off as you gain altitude, and the Panzer brings his own.

[h2]ONE LAST WAVE[/h2]

Reach the terrace at the top of the tower and buy [b]EXTRACTION[/b]. The gate drops and the closing song starts - and that song is the only clock you get.

Ninety seconds to run a forked, ambushed bridge out to the floating citadel while everything the tower has left comes at you from both sides. Then the citadel door slams behind you and you hold the hall until the final chord.

[b]Survive the song and you escape. Don't, and the tower keeps you.[/b]

[h2]BEYOND THE CROWN — THE ENDLESS SPIRE[/h2]

Beat the game and a choice appears in the citadel: [b]EXTRACT[/b] and take
your victory - or step onto the teleporter and [b]ASCEND[/b].

One way. No return. You arrive at the base of a second tower burning red in
the far distance - the one you've been wondering about the whole climb - with
[b]every perk, your class maxed out, and your tier-3 weapon Pack-a-Punched[/b].
100 floors. The horde never stops coming, and it comes fast. Ammo on every
floor, golden vendor hubs every 10th, your perk machines climbing with you.

Die, and you fall as a sovereign. Reach floor 100 and buy the extraction, and
you'll have done something almost nobody will.

Solo or co-op. Found a bug? Leave a comment and I'll fix it. Enjoy the climb.

[h2]Credits[/h2]

[b]Music[/b]
[list]
[*]"Password Infinity" - Evgeny Bardyuzha
[*]"Cyberpunk Futuristic City" - lnplusmusic
[*]"Cyber Relay" and "Data Spike" - Psychronic
[*]"Cyber Eclipse" - bykenneth
[*]"You See Big Girl" - Hiroyuki Sawano / Gemie
[*]"Neon Static" - generated with Suno (The Endless Spire)
[/list]

[b]Art & UI[/b]
[list]
[*]Nastian - Miami night skybox
[*]emox - MWIII Vertigo materials
[*]Owen-C137 - Aetherium HUD kit (with KingsLayerKyle, Shidouri & Madgaz)
[*]Westchief596 & ZeRoY - ammo crate model ([West] packs)
[/list]

[b]Weapons & enemies[/b]
[list]
[*]TheSkyeLord - weapon ports (with Azsry, Scobalula, TomBMX, Jari, Blak, raptroes, Thomas Cat, JBird632, .115 Cal, DTZxPorter, Collie, Ray1235, xSanchez78 & lilrobot)
[*]Kingslayer Kyle - armored sprinter body (Blood of the Dead pack)
[*]pmr360 - BOCW Combat Knife & Wakizashi
[*]WetEgg, M5_Prodigy, J.G., DeLeon & Santa Monica Studio - Leviathan Axe
[*]Spiki - mechz pack (Panzer)
[*]HB21 - Apothicon Fury (Reaver)
[*]HarryBo21 - Civil Protector v2 (Rogue Protector)
[*]GentlemanCheeseMan - Gift of Death pack (with Gerardo Justel, Saritasa, Orvani Sounds, MidgetBlaster)
[*]ZoekMeMaar - thunderstorm FX and free Pack-a-Punch
[*]NSZ - Zombie Blood
[*]Logical & NateSmithZombies - Time Warp and Infinite Ammo
[*]WetEgg & SAT - Black Ops 6/7 perk machines, perk icons & the Wisp Tea perk (with Scobalula, DTZxPorter, Dest1yo, echo000, Kingslayer Kyle, Rex, Sphynx, rayjiun, shidouri, XcDylan93 & garrett)
[*]Madgaz & Owen C137 (model, anims, sounds) with RiDD_Alexis31, JoaoSlideCancelo, Prov3ntus, Shidouri, Resxt, CF4_99, Rayjiun & devraw (script) - CW-BO6 Pack-a-Punch
[*]Unknown author - the Chaos-style Pack-a-Punch mesh on the upgrade altars. If this is your work, please reach out and I'll credit you properly.
[/list]

[i]Built with the Treyarch Black Ops III Mod Tools.[/i]
```
