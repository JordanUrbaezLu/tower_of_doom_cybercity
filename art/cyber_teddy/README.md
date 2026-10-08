# Cyber Teddy (the song-hunt bear)

The three teddy bears of the song hunt (`_tod_secret.gsc`) use this model since
v19.64 (2026-09-30). It replaced the stock mystery-box bear `p7_zm_teddybear`.

## Source

- `source/cyber_teddy_walking.fbx`, md5 `0cdea9bee11f5360fe6cd63c51f4e619`.
- From a fan's model pack delivered 2026-09-30 as three Google Drive zips
  (`3D Models-20260930T132111Z-1-00{1,2,3}.zip`), file
  `3D Models/Random Ideas/Cyber Teddy and animations/Cyber Teddy_Bear_Walking.fbx`.
  The pack carried three byte-identical copies of it.
- Made with Meshy AI: auto-rigged (24 bones), one 32-frame walk, one embedded
  2048 base-colour texture, 9,919 triangles. No normal, gloss or emission map.
- The fan's note grants permission to alter any model. Credit: see CREDITS.md
  (their name and the Meshy plan are still to confirm before a public upload).

## What the game gets

`tools/cyber_teddy/build_cyber_teddy.py` (Blender 4.2) writes everything:

| Output | What |
|---|---|
| `model_export/tod_cyber_teddy/tod_cyber_teddy.xmodel_bin` | the REST pose, baked; one bone `tag_origin`; pivot at the bounding-box centre; 28 units tall; front = local -Y |
| `.../_images/i_tod_cyber_teddy_c.png` | the fan's texture, byte for byte |
| `.../_images/i_tod_cyber_teddy_e.png` | glow map cut from its own blue-to-violet lights (eye, chest core, arm panels), 0.6% of the texture |
| `source_data/tod_cyber_teddy.gdt` | image, material (`lit_emissive_plus`, glow scaleRGB 4) and model blocks; BulletCollisionLOD None like the stock bear |
| `manifest.json` | size, LIFT, HALF_DEPTH, hashes |
| `preview_*.jpg` | renders of the WRITTEN binary: front, 3/4, side, and a dim room to show the glow |

The rig and the walk are not used: the hunt's rise, spin and flight are
scripted movers. The walk could be converted later with the repo's xanim
pipeline if the bear should ever walk.

## Rebuild

```
"C:\Program Files\Blender Foundation\Blender 4.2\blender.exe" -b -noaudio --python tools/cyber_teddy/build_cyber_teddy.py
```

Then copy `lift` and `half_depth` from `manifest.json` into `TOD_SECRET_LIFT` /
`TOD_SECRET_HALF_DEPTH` in `_tod_secret.gsc` if they changed;
`node tools/test_v1896_secret_killconfirm_bottle.js` fails until they match
and until every file equals the hash the manifest recorded. A model or GDT
change is a FULL build.

Blender previews do not establish the in-game glow or lighting: judge that in game.
