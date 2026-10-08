# CREDITS — required before any PUBLIC release

Beta (Friends-Only) does not gate on this; the PUBLIC flip does. Compiled
2026-08-23 from the release audit; all author handles VERIFIED from the pack
readmes 2026-08-24 (GentlemanCheeseMan, HarryBo21). No open items.

## Music
- "Neon Static" — generated with Suno v5.5 for this map (The Endless Spire)
- "Falling To Pieces" — user-supplied 2026-09-13 (the teddy bear song, `tod_music_ee`). ⚠️ LICENCE UNCONFIRMED: a commercial recording; map 1's credits marked its commercial EE songs DO NOT PUBLISH. Confirm before a public upload.
- "Password Infinity" — Evgeny Bardyuzha (ambient, floors 1-9)
- "Cyberpunk Futuristic City" — lnplusmusic (floors 10-22)
- "Cyber Relay" — Psychronic (floors 23-36)
- "Cyber Eclipse" — bykenneth (floors 37-50)
- "Data Spike" — Psychronic (Panzer)
- "Chaos Unleashed" — generated with Suno for this map (the Warden Trials; its 3:29 version is the Warden King's track)
- "You See Big Girl" — Hiroyuki Sawano / Gemie (finale)

## Sound effects
- Origins Soul Boxes pack: Fanatic (scripts/package), Scobalula (Greyhound),
  HarryBo21 (FX pack), Treyarch (original assets). All eight supplied sounds
  are copied unchanged; the luck soul visual adapts its traveling soul FX.
- Baseball bat whiffs: user-supplied Floraphonic clips `swing-whoosh-5-198498`
  and `swing-whoosh-weapon-1-189819`, copied unchanged from the downloaded WAVs.
- Baseball bat impact — user-supplied `bathitball.wav`, September 14, 2026.
  Used unchanged for every bat contact; source author not provided.
- `tod_full_steam_wind` — generated for this map (FULL STEAM, the heavy's
  sustained-sprint speed boost). Source file trimmed to its steadiest 7.25 s and
  closed into a seamless 7.000 s loop with a constant-power crossfade; the
  generator's fade-in and fade-out were removed, since either one pulses audibly
  once a bed is looped.
- `staff_lightning_shot` — "Laser Zap 2" by Freesound Community (via Pixabay),
  the mage's lightning staff shot since 2026-09-08. Resampled 24 k -> 48 k and cut
  to its first 170 ms: 35 ms in, just ahead of the transient, out at 205 ms with a
  40 ms fade so it ends rather than being clipped. **170 ms is not a taste
  decision** — the lightning staff fired every 195 ms when it was cut (229 ms
  since 2026-09-09's 15% rate cut), and a sample longer than
  the fire interval overlaps itself, which is the ringing the previous shot sound
  was reported for. Peak-normalised to 0.0 dBFS, matching the file it replaced, so
  the alias volume did not have to move.
- `staff_ice_shot` — "Ice Spell Impact" by Dragon Studio (via Pixabay,
  dragon-studio-ice-spell-impact-448563), the mage's ice staff shot since
  2026-09-09 on the user's request. The download is 4.70 s with a 1.2 s riser
  before the impact and a quiet tail; cut to 1.20-2.70 s (the impact leads, 10 ms
  in, 350 ms out) and gained -9 dB so its overall RMS (-17.4 dBFS) sits near the
  clip it replaced (-20.6) without moving the alias volume. 1.5 s against a 1.0 s
  fire interval: only the fading last half-second overlaps the next shot (10
  instances, oldest stolen).

## Art / UI
- **Nikolai** (a fan of the map; probably, not confirmed, the Workshop commenter
  of that name whose ideas shaped the base column's checker floor) — the
  "3D Models" pack, made with Meshy AI
  and shared with permission to alter anything. In the map: the Cyber Teddy (the
  song-hunt bear, `tod_cyber_teddy`, since 2026-09-30) and, since 2026-10-02
  (v19.69), the TOWER OF DOOM / CYBERCITY neon sign over the spawn
  (`tod_cybercity_sign`), the crown uplink terminal (`tod_uplink_terminal`, his
  "Door Terminal Idea") and every ammo crate (`tod_ammo_chest`, his Cyber Ammo
  Chest) — reduced, re-baked and given glow maps for the engine
  (tools/fan_props, art/fan_props/README.md). The user named him on 2026-10-02
  ("the new model from props (nikolai)"). ⚠️ OPEN BEFORE A PUBLIC UPLOAD: how he
  wants the credit worded, and which Meshy plan made the models (a free-plan
  model is CC BY 4.0 and must also credit Meshy; a paid-plan model belongs to
  him).
- pmr360 — BOCW Baseball Bat port (Treyarch/Raven Software originals), including
  models, materials, animations and sound setup. Port readme credits the T9-to-T7
  rig by Thomas Cat / TheBlackDeath / DamianoTBM; Scobula, DTZxPorter, ID-Daemon,
  Eric Maynard, JBird632, Logical Edits, Harry Bo21, TheSkyeLord, lilrobot,
  Ray1235, MakeCents and MikeyRay for extraction, tooling and support.
- WetEgg / SAT — Black Ops 6/7 perk machine models, the perk icon set, and
  the Wisp Tea perk script, machine purchase animations, firing FX and audio
  (SATPerksAssets + SATPerksCode packs: all nine
  machines incl. Death Perception and the BO7 Wisp Tea, the crest HUD icons
  since 2026-08-29, and the vendored `_zm_perk_wisp_tea` module since
  2026-08-30). Per the code pack's instructions.txt (found 2026-08-30 — it IS
  the readme the assets pack lacked), credit also: Scobalula, DTZxPorter,
  Dest1yo, echo000 (Saluki and Cordycep); Kingslayer Kyle (vertex color
  materials); Rex (PHD Slider script and FX); Sphynx (original Death
  Perception script); rayjiun, shidouri, XcDylan93 (script assistance);
  garrett (improved Wisp Tea wisp FX); TNT, MoiCestTOM, Midgetblaster,
  Syndikate, Nastian, eMoX (testing).
- Nastian — T9 skybox pack: the map's sky was its Miami night (skybox_t9_mp_miami
  + acc_ssi_miami_night) through v17.70; since v17.71 our own sky still rides
  on a clone of that pack's sun/sky info (tod_ssi_cybercity) and the T6 dome
  mesh the pack installed
- emox — MWIII Vertigo material/asset pack (the Tron Grid look)
- DOGCANARY — "Images arrow coldwar dogcanary" power-direction wall decals
  (11 `arrow_power_coldwar*` materials / 11 images). 🔴 The art is Treyarch **BOCW**
  dark-aether wall scrawl (`i_mtl_t9_powerarrows_dark_aether_*` rips). Used since
  v18.99 for the six POWER / arrow decals that point players at the power switch.
  The same pack map 1 uses, installed in the SHARED tools root, not in either repo
  (`model_export/codimages/arrow_coldwar_dogcanary/`). **Credit DOGCANARY +
  Treyarch (BOCW) before Public** — map 1's CREDITS carries the identical flag.
- Owen-C137 — Aetherium HUD kit, with KingsLayerKyle, Shidouri & Madgaz (the
  kit renders all FOUR author signatures in the pause menu,
  AetheriumStartMenu.lua:1035-1060 — credit all four, publish-sweep find
  2026-08-29)
- Westchief596 & ZeRoY — [West] Ammo Crates (the ammo crate model,
  west_ammo_crate_model, built on ZeRoY's S4 crate) + [West] Community Perk
  Collection v2.7 (electric_cherry_model). Both force-packed; map 1's ledger
  recorded the pack's crediting request — publish-sweep find 2026-08-29.
- Unknown author — the "Chaos" Pack-a-Punch mesh worn by the six Heavenly
  Gift Altars (chaos_pack_a_punch.gdt; ximage_* extraction-named textures).
  No recorded author here or in map 1; shipped 2026-08-29 with an open
  "reach out to be credited" line in the Workshop description (user
  decision). If the source pack is ever identified, replace this entry.

- Logical — the cyberpunk Riot Shield mesh (`logical_m_shield_full` and its
  PBR set, the pack's own `log_riotshield_zm` weapon def): the RIOT SHIELD
  upgrade's level-5 "new model" since v16.63 (2026-09-02). Logical's ORIGINAL
  art (map 1 used the same mesh as a reskin; the pack's BO4 crafting bench is
  installed on the build box but NOT used or packed). Credit Logical.
- Treyarch — the level 1-4 shield is the stock Shadows of Evil rocket shield
  (`zod_riotshield`), same-game asset.

## Weapons / enemies
- Skye (TheSkyeLord) — the weapon ports (MSMC, Mk 48, MAC-10, MP5, Enfield, Krig 6, AK-47,
  Stoner 63, HK21, Magnum, AMP63, Ghosts Bulldog, Five-Seven, BO2 MP7,
  IW UDM...). Per the packs' README condition ("add the people on my modme
  post"), the Master Hub credits (recovered 2026-08-29 from the modme
  archive, thread 2565): Azsry (maya scripts, rigs), Scobalula (Greyhound,
  CoD Image Util, Camo Chairs, CoD Maya Tools), TomBMX (.ff exporter), Jari &
  Blak (mix map materials), raptroes, Thomas Cat (MW rig, IK help), JBird632
  (tutorials), .115 Cal (game shares), DTZxPorter (Kronos/ExportX, SE Tools,
  Wraith Archon, modme itself), Collie (IW7/WW2 conversion rigs),
  Ray1235 (CoD Maya Tools), xSanchez78 (IW7 conversion rig), lilrobot
  (inspectable weapons script)
- pmr360 — BOCW Wakizashi (KATANA)
- WetEgg / M5_Prodigy / J.G. / DeLeon / Santa Monica Studio — Leviathan Axe
  (STORMBREAKER)
- Kingslayer Kyle — the ARMORED SPRINTER's body (c_t8_zmb_mob_zombie_body3,
  Blood of the Dead character pack; readme's "Make sure you credit me" per
  map 1's ledger — publish-sweep find 2026-08-29)
- Spiki — mechz pack (the Panzer)
- HB21 — Apothicon Fury (the Reaver)
- ZoekMeMaar — thunderstorm FX + free-Pack-a-Punch powerup
- NSZ — Zombie Blood powerup
- Logical + NateSmithZombies — Time Warp + Infinite Ammo powerups (vendored
  2026-08-20; the zone file's credit-before-publish note — this line was the
  one gap in the 2026-08-23 audit, closed 2026-08-26 when the Workshop
  description gained its credits section)
- GentlemanCheeseMan — "Gift of Death" Xmas Gun pack (per its INSTRUCTIONS.txt;
  gun model Gerardo Justel, ornaments/bow Saritasa, sounds Orvani Sounds, some
  assets from MidgetBlaster's T7 pack; readme grants reuse permission)
- HarryBo21 — Civil Protector v2.0.0 companion pack (the Rogue Protector; pack
  CREDITS.txt lists ~40 contributors incl. TheSkyeLord, Scobalula, DTZxPorter;
  robot model/anims Treyarch, BO3 Shadows of Evil)

## Engine / tools
- Treyarch — Black Ops III Mod Tools + stock assets

## ALXS CW/BO6 Pack-a-Punch (v13.6)
- PaP model and anims: Madgaz, Owen C137
- PaP script: RiDD_Alexis31, JoaoSlideCancelo, Prov3ntus, Shidouri, Resxt, CF4_99, Rayjiun, devraw, and mod tools servers support
- PaP sounds: Owen C137
- Pack: "ALXS - CW-BO6 PAP" v1.1.2

## Pack-a-Punch camos (v17.50 onward)
- The three tier camos (gold / red anodized hex / Element 115) are stock
  Black Ops III camo materials, reached through the weapon camo tables each
  ported pack ships (Skye's packs, and WetEgg's Leviathan axe for the
  Stormbreaker). No custom camo art ships. The v17.35-v17.49 custom camo
  attempt (procedural art over Madgaz's `mtl_origins_camo_alt` material
  recipe) never rendered and is retired; the generator stays in the repo as
  a record only.
- Mage staff first-raise foley: Winter's Howl (freezegun) port's fly_freezegun_first_raise.wav, unchanged (WetEgg port; Treyarch / BO4 source). Reload beats: the same port's mag_release / mag_in clips (see sound_assets/tod/mage/README.md).
