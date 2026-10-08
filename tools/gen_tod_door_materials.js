#!/usr/bin/env node
// =============================================================================
// gen_tod_door_materials.js — THE MATTE DOOR MATERIALS (v18.99g, 2026-09-13)
//
// User, on a screenshot of the base arena: "ALso fix this door. It has a
// reflection bug." The buyable door slab was rendering as a smeared mirror with
// the neon skyline in it.
//
// IT IS NOT TRANSPARENT AND IT IS NOT A LIGHTING BUG. Measured out of
// <modtools>/source_data/_emox/emox_mwiii_vertigo_assets.gdt: every one of the
// pack's 30 materials — the ENTIRE world kit, floors, walls, treads and door
// slabs alike — is configured as a polished flat mirror:
//
//     colorMap            $white_diffuse      pure-white albedo
//     specColorMap        $white_specular     full-white specular
//     specAmount          1                   at full strength
//     specColorStrength   100
//     cosinePowerMap      i_..._g             a gloss map measured 97% WHITE,
//                                             i.e. gloss pinned at maximum
//     glossRangeMax       16
//     reflectionProbeAmount 1                 full environment reflection
//     envMapMin/Max/Exponent  1 / 1 / 1       flat, NO fresnel falloff
//     normalMap           ""                  NO normal map at all
//     transparent         0                   (so: not see-through — a mirror)
//
// White albedo + max gloss + no normal map + full probe = a perfectly flat
// mirror plane with zero surface breakup, which is exactly the recipe for an
// undistorted, smeared environment reflection on a big flat brush face.
//
// WHY THE DOOR SHOWS IT WORST, of all the surfaces that share this: the door
// slab is `<hue>_tinted_edge`, the DIMMEST rung of the pack's brightness ladder
// (scaleRGB 5, against the arena wall's 15), and it is the FILLED tile texture
// with no grid lines to break a reflection up. A constant-strength reflection
// laid over the dimmest, flattest, largest surface in the room wins.
//
// THE FIX, and why it is a NEW material rather than an edit to the pack: the
// vertigo GDT is a SHARED tools-root file (memory shared-gdt-crosses-maps) and
// `_tinted_edge` is also every landing, breather floor, the terrace, the
// causeway deck and the extraction pad. Editing it in place would take the
// reflections off half the map's FLOORS as a side effect of fixing a door. So
// this clones the five DISTRICT hues into our own source_data/tod_materials.gdt
// as `tod_door_<hue>` — byte-identical to their donors except the name and a
// zeroed specular/reflection block — and only the DOOR SLAB emission sites in
// gen_tower_map.js point at them. Everything else keeps the look it shipped.
//
// ⚠️ A MATERIAL NAME NOTHING DECLARES IS SUBSTITUTED **SILENTLY** by the linker
// (memory vertigo-pack-is-two-textures). The proof a new one converted is its
// ABSENCE from the linker's known-waived warning list in a run whose waived
// count is unchanged — 10 as of this build. tod_hall_* (v17.86) is the
// precedent that this lane works.
//
// ALSO FOUND AND NOT FIXED HERE — THE PROBE BOXES ARE A SEPARATE, MAP-WIDE BUG.
// gen_tower_map.js's probe() emits every one of the map's 46 reflection probes
// with Radiant's DEFAULT parallax box, `size_min`/`size_max` "72 72 72", i.e. a
// 144-unit cube — inside a 1,120-unit arena and a 1,536-unit crown hall. Map 1
// is the counter-example and its generator comment says so out loud: "GROW the
// box to each zone's extent"; its probes carry real room-sized boxes
// (size_max "712.25 544.75 198.25" / size_min "634.5 548.5 73.25") and no
// `radius` key at all. A parallax box that small projects the cubemap onto a
// tiny volume next to the camera, which is what makes the reflection SMEAR
// rather than sit on the geometry. Fixing it changes reflections across the
// whole map and needs a fresh LED bake, so it is the user's call, not a
// side effect of a door fix.
//
// Usage:  node tools/gen_tod_door_materials.js         (rewrites the block)
//         node tools/gen_tod_door_materials.js --check (verifies, exits 1 on drift)
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const REPO = path.resolve(__dirname, '..');
const OUT = path.join(REPO, 'source_data', 'tod_materials.gdt');

// The mod tools root, detected exactly the way build_map.ps1 does.
function modTools() {
  const guesses = [
    'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Call of Duty Black Ops III 455130',
    'D:\\SteamLibrary\\steamapps\\common\\Call of Duty Black Ops III 455130',
    'E:\\SteamLibrary\\steamapps\\common\\Call of Duty Black Ops III 455130',
  ];
  for (const g of guesses) if (fs.existsSync(path.join(g, 'bin', 'modlauncher.exe'))) return g;
  throw new Error('mod tools root not found (looked for bin/modlauncher.exe)');
}

const DONOR_GDT = path.join(modTools(), 'source_data', '_emox', 'emox_mwiii_vertigo_assets.gdt');

// The five DISTRICT hues, LOCKSTEP with DISTRICTS in gen_tower_map.js. A sixth
// name here with no district is dead weight; a missing one is a white square.
const HUES = ['blue', 'green', 'orange', 'yellow', 'red'];

// THE WHOLE POINT OF THE FILE. Every other field is copied verbatim from the
// donor so the door keeps its exact colour, texture and emissive brightness —
// only its response to the environment changes.
const MATTE = {
  specAmount: '0',
  specColorStrength: '0',
  specColorTint: '0 0 0 1',
  specColorTint1: '0 0 0 1',
  specColorTint2: '0 0 0 1',
  specColorTint3: '0 0 0 1',
  reflectionProbeAmount: '0',
  envMapMin: '0',
  envMapMax: '0',
  glossRangeMax: '0',
  glossRangeMin: '0',
};

const BEGIN = '\t// ---- BEGIN GENERATED: tod_door_* (gen_tod_door_materials.js) ----';
const END = '\t// ---- END GENERATED: tod_door_* ----';

function donorBlock(name) {
  const src = fs.readFileSync(DONOR_GDT, 'utf8');
  const head = `\t"${name}" ( "material.gdf" )`;
  const i = src.indexOf(head);
  if (i < 0) throw new Error(`donor material not found: ${name}`);
  const open = src.indexOf('{', i + head.length);
  if (open < 0) throw new Error(`donor block malformed: ${name}`);
  // The blocks are flat (one level of braces), so the first closing brace at
  // the block's own indent ends it. Scan with a depth counter anyway.
  let depth = 0, end = -1;
  for (let k = open; k < src.length; k++) {
    if (src[k] === '{') depth++;
    else if (src[k] === '}') { depth--; if (depth === 0) { end = k; break; } }
  }
  if (end < 0) throw new Error(`donor block unterminated: ${name}`);
  return src.slice(open, end + 1);
}

function build() {
  const out = [BEGIN];
  out.push('\t// Matte clones of the buyable-door hues: identical to');
  out.push('\t// mwiii_vertigo_retro_synth_<hue>_tinted_edge except that the specular and');
  out.push('\t// environment-reflection response is zeroed, so a door slab stops acting as');
  out.push('\t// a mirror. Read the header of tools/gen_tod_door_materials.js before');
  out.push('\t// editing anything here BY HAND — this block is regenerated.');
  for (const hue of HUES) {
    let body = donorBlock(`mwiii_vertigo_retro_synth_${hue}_tinted_edge`);
    for (const [field, value] of Object.entries(MATTE)) {
      const re = new RegExp(`("${field}")\\s+"[^"]*"`, 'g');
      // PRESENCE, not change: several of these fields are already "0" in the
      // donor, and an unchanged body is the correct outcome for those. Testing
      // for a change would false-alarm on exactly the fields needing no edit.
      if (!re.test(body)) throw new Error(`field not present in donor, cannot zero it: ${field} (${hue})`);
      re.lastIndex = 0;
      body = body.replace(re, `$1 "${value}"`);
    }
    out.push(`\t"tod_door_${hue}" ( "material.gdf" )`);
    out.push(body.split('\n').map(l => l).join('\n'));
  }
  out.push(END);
  return out.join('\n');
}

function main() {
  const check = process.argv.includes('--check');
  const gdt = fs.readFileSync(OUT, 'utf8');
  const block = build();

  let next;
  const i = gdt.indexOf(BEGIN);
  if (i >= 0) {
    const j = gdt.indexOf(END, i);
    if (j < 0) throw new Error('generated block has a BEGIN with no END — repair tod_materials.gdt by hand');
    next = gdt.slice(0, i) + block + gdt.slice(j + END.length);
  } else {
    // Insert before the file's final closing brace.
    const close = gdt.lastIndexOf('}');
    if (close < 0) throw new Error('tod_materials.gdt has no closing brace');
    next = gdt.slice(0, close) + block + '\n' + gdt.slice(close);
  }

  if (check) {
    if (next !== gdt) {
      console.error('tod_door_* materials are STALE — run: node tools/gen_tod_door_materials.js');
      process.exit(1);
    }
    console.log(`tod_door_* materials OK (${HUES.length} matte door hues)`);
    return;
  }
  fs.writeFileSync(OUT, next, 'utf8');
  console.log(`wrote ${OUT}  (${HUES.length} matte door materials: ${HUES.map(h => 'tod_door_' + h).join(', ')})`);
}

main();
