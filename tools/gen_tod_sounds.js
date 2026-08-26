#!/usr/bin/env node
// =============================================================================
// gen_tod_sounds.js — generate sound/aliases/tod_weapons.csv for every class gun.
//
// Supersedes gen_krig_sounds.js (which only handled the Krig and copied the
// ak74u/m60 rows verbatim from map 1). The v7 roster swapped SKIRMISHER to the
// MP5 and HEAVY to the Stoner 63 (user 2026-08-20) — neither gun has alias
// rows anywhere in either repo, so both are generated here from their own wavs.
//
// THE RECIPE (map 1's, proven by the Krig):
//   FIRE CHAIN — every Skye t9 port ships the same fire wav set (shot1-6,
//     trig_pull1-6, mech1-6, sub, pap_flux), so map 1's t9_ak47 fire rows are
//     cloned and renamed. Guns missing a family (the Stoner has NO trig_pull)
//     declare it in `skipFire` so we never emit an alias pointing at a wav
//     that does not exist.
//   FOLEY — differs per gun, so rows are emitted from the gun's OWN wav list
//     using an ak47 foley row as the column template. Numbered wav families
//     collapse under ONE alias token (map 1's silent-reload trap: several wavs
//     must share a token to round-robin) — cloth2a/2b -> cloth2,
//     mvmnt/2/3/4 -> mvmnt. inspect_partN stay SEPARATE (distinct anim events,
//     matching the proven ak74u row set).
//
// Templates (wpn_t9_shot_plr etc.) resolve from the installed
// share\raw\sound\templates\template_skye_t9_sounds.csv — no rows needed here.
// Run: node tools/gen_tod_sounds.js   (regenerates the CSV; safe to re-run)
// =============================================================================

'use strict';

const fs = require('fs');
const path = require('path');

const SRC = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies/sound/aliases/acc_skye_box_weapons.csv';
const TOOLS = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const OUT = path.join(__dirname, '..', 'sound', 'aliases', 'tod_weapons.csv');

// Guns whose aliases this file owns. `wavDir` is the skye_ports folder name.
// CLASS TIERS (docs/25): only the Skye CW (t9) guns ride this recipe — the
// BO1/BO2 ports (Enfield, HK21, MP7, Death Machine) ship their alias rows in
// their zip README and are copied verbatim into sound/aliases/tod_ports.csv.
// `enabled` gates emission so a gun's rows land in the SAME build as its
// zone lines (one gun per build).
const GUNS = [
  { asset: 't9_krig6',    wavDir: 't9_krig6',    skipFire: [],             enabled: true },
  { asset: 't9_mp5',      wavDir: 't9_mp5',      skipFire: [],             enabled: true },
  { asset: 't9_stoner63', wavDir: 't9_stoner63', skipFire: ['trig_pull'],  enabled: true },
  // MAC-10 (skirmisher T1): full t9 fire set (shot1-6, trig_pull1-6, mech1-6,
  // sub, pap_flux) + 12 foley wavs matching the GDT's 12 foley aliases 1:1.
  { asset: 't9_mac10',    wavDir: 't9_mac10',    skipFire: [],             enabled: true },   // Phase 2a
  // AK-47 (assault T3): the fire template IS t9_ak47 (identity rename); 17 foley wavs.
  { asset: 't9_ak47',     wavDir: 't9_ak47',     skipFire: [],             enabled: true },   // Phase 2e
  // PER-CLASS SECONDARIES (2026-08-23). Only the two CW (t9) sidearms ride this
  // recipe. The third secondary, the AW s1_bulldog, does NOT: it is an
  // old-style port with just 2 fire wavs (shot + pap_shot) and 5 foley, so it
  // cannot satisfy the t9 shot/trig_pull/mech/sub/pap_flux family layout. Its
  // 9 alias rows are hand-authored in sound/aliases/tod_ports.csv instead —
  // which is exactly what that file is for (see the header note above about
  // non-t9 ports). Do not add s1_bulldog here.
  // AMP63 (slasher sidearm): full family set incl. trig_pull.
  { asset: 't9_amp63',    wavDir: 't9_amp63',    skipFire: [],             enabled: true },
  // MAGNUM (assault sidearm): a revolver — NO trig_pull family, same shape as
  // the Stoner. Listing it here is what stops the generator emitting rows that
  // point at wavs which do not exist.
  { asset: 't9_magnum',   wavDir: 't9_magnum',   skipFire: ['trig_pull'],  enabled: true },
];

// asset -> its source GDT basename in the tools source_data. NOTE the MAC-10's
// basename has a HYPHEN (skye_t9_mac-10) — a wrong value makes gdtAliases()
// return null and the generator silently falls back to 1:1 wav naming.
const GDT_OF = {
  t9_krig6: 'skye_t9_krig_6',
  t9_mp5: 'skye_t9_mp5',
  t9_stoner63: 'skye_t9_stoner_63',
  t9_mac10: 'skye_t9_mac-10',
  t9_ak47: 'skye_t9_ak-47',
  t9_amp63: 'skye_t9_amp63',
  t9_magnum: 'skye_t9_magnum',
};


const lines = fs.readFileSync(SRC, 'utf8').split(/\r?\n/);
const header = lines[0];

const foleyTemplate = lines.find(l => l.startsWith('wpn_t9_ak47_bolt_back,'));
if (!foleyTemplate) throw new Error('no ak47 foley template row found');

// The GDT is the AUTHORITY on which foley aliases exist — guessing a collapse
// rule from wav names is wrong in both directions (the Krig's GDT wants ONE
// `mvmnt` fed by mvmnt1-4; the MP5's wants mvmnt, mvmnt2, mvmnt3, mvmnt4 as
// four SEPARATE aliases). So: read the referenced alias names out of the GDT,
// then bind each to its wav(s) — exact basename match first, else every
// numbered/lettered variant of that stem (which is what makes a token
// round-robin, map 1's silent-reload trap).
function gdtAliases(gdtPath, asset) {
  if (!fs.existsSync(gdtPath)) return null;
  const text = fs.readFileSync(gdtPath, 'utf8');
  const s = new Set();
  for (const m of text.matchAll(new RegExp('"(wpn_' + asset + '_[a-z0-9_]+)"', 'g'))) s.add(m[1]);
  return s;
}

function wavsForAlias(alias, prefix, bases) {
  const stem = alias.slice(prefix.length);
  if (bases.includes(stem)) return [stem];                 // exact wav
  const re = new RegExp('^' + stem.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '(\\d+[ab]?|[ab])$');
  return bases.filter(b => re.test(b));                    // numbered family
}

const out = [header];
const report = [];

for (const gun of GUNS) {
  if (gun.enabled === false) { report.push(gun.asset + ': DISABLED (not emitted)'); continue; }
  // ---- fire chain ---------------------------------------------------------
  const fireRe = new RegExp('^wpn_t9_ak47_(shot|trig_pull|mech|sub|tail|pap_flux|pap_shot)_(plr|npc),');
  const fireRows = lines
    .filter(l => {
      const m = l.match(fireRe);
      if (!m) return false;
      return !gun.skipFire.includes(m[1]);
    })
    .map(l => {
      const cols = l.replace(/t9_ak47/g, gun.asset).split(',');
      // Column 9 (index 8) = Secondary. The ak47 template chains shot/pap_flux
      // rows to its trig_pull family; for a gun that SKIPS that family the
      // renamed Secondary would name an alias no row defines (review
      // 2026-08-22: 14 dangling wpn_t9_stoner63_trig_pull_* refs). Blank it.
      if (cols[8] && gun.skipFire.some(f => cols[8].includes('_' + f + '_'))) cols[8] = '';
      return cols.join(',');
    });
  if (fireRows.length === 0) throw new Error('no ak47 fire rows found — source CSV moved?');

  // ---- foley: GDT-referenced aliases bound to this gun's wavs -------------
  const foleyDir = path.join(TOOLS, 'sound_assets', 'skye_ports', gun.wavDir, 'foley');
  const prefix = 'wpn_' + gun.asset + '_';
  const foleyRows = [];
  const unbound = [];

  if (fs.existsSync(foleyDir)) {
    const bases = fs.readdirSync(foleyDir)
      .filter(f => f.endsWith('.wav'))
      .map(f => path.basename(f, '.wav'))
      .filter(b => b.startsWith(prefix))          // cross-named foley: skip
      .map(b => b.slice(prefix.length))
      .sort();

    const gdtName = GDT_OF[gun.asset];
    const refs = gdtAliases(path.join(TOOLS, 'source_data', gdtName + '.gdt'), gun.asset);
    // Fire-chain aliases are already emitted above; foley is everything else.
    const fireNames = new Set(fireRows.map(l => l.split(',')[0]));
    const wanted = refs
      ? [...refs].filter(a => !fireNames.has(a)).sort()
      : bases.map(b => prefix + b);               // no GDT: fall back 1:1

    for (const alias of wanted) {
      const wavs = wavsForAlias(alias, prefix, bases);
      if (wavs.length === 0) { unbound.push(alias); continue; }
      for (const w of wavs) {
        const cols = foleyTemplate.split(',');
        cols[0] = alias;
        cols[3] = 'skye_ports\\' + gun.wavDir + '\\foley\\' + prefix + w + '.wav';
        foleyRows.push(cols.join(','));
      }
    }
  } else {
    console.log('WARNING: no foley dir for ' + gun.asset + ' (' + foleyDir + ')');
  }

  out.push(...fireRows, ...foleyRows);
  report.push(gun.asset + ': ' + fireRows.length + ' fire + ' + foleyRows.length + ' foley'
    + (unbound.length ? '   [no wav, will be silent: ' + unbound.join(', ') + ']' : ''));
}

// The Streetsweeper stays linked (zone weapon lines) though nothing can reach
// it yet — keep its proven rows so the linker never loses them.
const KEEP_RE = /^wpn_t9_streetsweeper/;
const kept = lines.slice(1).filter(l => KEEP_RE.test(l));
out.push(...kept);
report.push('streetsweeper copied: ' + kept.length);

// ---- SIMPLE PORTS — the secondary ladder's non-t9 guns (2026-08-24) --------
// The recipe above only fits SKYE CW (t9) ports: they all ship the same fire
// family (shot1-6 / trig_pull1-6 / mech1-6 / sub / pap_flux) and the ak47 rows
// can be cloned onto any of them. Seven of the eight guns on the new secondary
// ladder are BO2/BO4/VG ports that ship TWO fire wavs and a handful of foley —
// the same shape as the s1_bulldog, whose nine rows have been hand-written in
// sound/aliases/tod_ports.csv since v10.8.
//
// Hand-writing nine more rows per gun, seven times, is how a gun ships silent:
// there is NO build error for a missing alias, the weapon just makes no noise.
// So these are generated from the wavs on disk, using the BULLDOG'S OWN ROWS as
// the column template — the same trick the t9 recipe plays with an ak47 row.
//
// ALIAS NAMES COME FROM THE GDT, NOT FROM THE WAV NAMES. Each of these guns
// references exactly four fire aliases — <stem>_shot_npc/_plr and
// <stem>_pap_shot_npc/_plr — and that stem is NOT always the asset name: the
// Nail Gun's assets are t9_nail_gun* while every sound it references, and its
// whole wav directory, are t9_nailgun. Same class of trap as the MAC-10's
// hyphen, which is why sndStem is its own field.
//
// NUMBERED WAV FAMILIES COLLAPSE ONTO ONE ALIAS: several rows sharing an alias
// name is how this engine round-robins (map 1's silent-reload trap). The Nail
// Gun's shot1..shot6 become six rows all called wpn_t9_nailgun_shot_plr.
//
// PaP FALLBACK: the Nail Gun and the Klauser ship a pap_flux instead of a
// pap_shot wav, so their pap_shot aliases point at the NORMAL shot wavs — the
// Pack-a-Punched form sounds like the gun rather than like nothing.
// `donor` — a first_raise (weapon-draw) wav BORROWED from another port, because
// this one shipped none of its own.
//
// THIS IS NOT A PORTING DEFECT, it is how those games are built (user 2026-08-25:
// "try to find something from a similar gun"). Measured across the whole
// skye_ports library: AW (s1) 42 of 47 ports carry a first_raise/start/end wav
// and CW (t9) 41 of 47 — but BO2 (t6) only 11 of 65 and BO4 (t8) only 3 of 41.
// Six of our eight secondaries are t6/t8, so they land in the majority that
// never had one. Every comparable shotgun in the library (t6_ksg, t6_m1216,
// t6_olympia, t8_m1897, t8_rampart_17) is missing it too.
//
// DONORS ARE CHOSEN BY WEAPON CLASS FIRST, GENERATION SECOND, because the draw
// sound is the sound of THAT KIND OF GUN being lifted:
//   shotguns  -> t6_blundergat  (the only BO2/BO4 shotgun with a first_raise)
//   revolver  -> t6_remnewmodel (Remington New Model Army — exact class match)
//   pistol    -> t6_b23r
//   launcher  -> t6_m82a1       (no launcher in the library has one; the Barrett
//                                is the nearest heavy shoulder weapon)
//
// THE ALIAS NAME IS INFERRED, and that is a deliberate, cheap bet: all 14 t6/t8
// ports that do ship one name it exactly wpn_<asset>_first_raise, so that is the
// name the notetracks call. If a given gun's animation does not call it, the row
// is simply inert — an unused alias costs nothing. It cannot make a gun quieter.
const SIMPLE_PORTS = [
  { wavDir: 't8_mog12',       sndStem: 't8_mog12',       donor: ['t6_blundergat',  'wpn_t6_blundergat_first_raise.wav'] },
  { wavDir: 't8_sg12',        sndStem: 't8_sg12',        donor: ['t6_blundergat',  'wpn_t6_blundergat_first_raise.wav'] },
  { wavDir: 't8_rk7',         sndStem: 't8_rk7',         donor: ['t6_b23r',        'wpn_t6_b23r_first_raise.wav'] },
  { wavDir: 't6_executioner', sndStem: 't6_executioner', donor: ['t6_remnewmodel', 'wpn_t6_remnewmodel_first_raise.wav'] },
  { wavDir: 't6_spas12',      sndStem: 't6_spas12',      donor: ['t6_blundergat',  'wpn_t6_blundergat_first_raise.wav'] },
  { wavDir: 't6_rpg',         sndStem: 't6_rpg',         donor: ['t6_m82a1',       'wpn_t6_m82a1_first_raise.wav'] },
  { wavDir: 't9_nailgun',     sndStem: 't9_nailgun' },   // assets are t9_nail_gun*; ships its own
  { wavDir: 'iw7_udm',        sndStem: 'iw7_udm' },      // IW UDM — ships its own first_raise
];

{
  // Column templates lifted from the Bulldog's own rows: a 2d player fire row, a
  // 3d npc fire row (which carries the DistMin/DistMax columns the 2d row leaves
  // empty), and a 2d foley row with no volume columns at all. Only column 0
  // (alias name) and column 3 (FileSpec) are ever rewritten — every other column
  // stays byte-identical to a row that is already proven in a shipped build.
  // FileSpec paths in these CSVs are BACKSLASH-separated regardless of host OS —
  // they are engine-relative asset paths, not filesystem paths, so path.join is
  // the wrong tool here and would emit forward slashes on a non-Windows box.
  const SEP = '\\';
  const portsCsv = path.join(__dirname, '..', 'sound', 'aliases', 'tod_ports.csv');
  const tmpl = fs.readFileSync(portsCsv, 'utf8').split(/\r?\n/);
  const pick = (n) => {
    const r = tmpl.find(l => l.startsWith(n + ','));
    if (!r) throw new Error('template row missing from tod_ports.csv: ' + n);
    return r;
  };
  const T_PLR = pick('wpn_s1_bulldog_shot_plr');
  const T_NPC = pick('wpn_s1_bulldog_shot_npc');
  const T_FOLEY = pick('wpn_s1_bulldog_end');
  const row = (t, name, wav) => {
    const c = t.split(',');
    c[0] = name;
    c[3] = wav;
    return c.join(',');
  };

  for (const g of SIMPLE_PORTS) {
    const dir = path.join(TOOLS, 'sound_assets', 'skye_ports', g.wavDir);
    const fireDir = path.join(dir, 'fire');
    const foleyDir = path.join(dir, 'foley');
    if (!fs.existsSync(fireDir)) throw new Error('no fire wav dir for ' + g.wavDir);
    const fire = fs.readdirSync(fireDir).filter(f => f.endsWith('.wav'));
    const rel = (sub, f) => ['skye_ports', g.wavDir, sub, f].join(SEP);

    const shots = fire.filter(f => new RegExp('^wpn_' + g.sndStem + '_shot[0-9]*[.]wav$').test(f)).sort();
    if (!shots.length) throw new Error('no shot wav for ' + g.wavDir);
    let paps = fire.filter(f => new RegExp('^wpn_' + g.sndStem + '_pap_shot[0-9]*[.]wav$').test(f)).sort();
    const fellBack = paps.length === 0;
    if (fellBack) paps = shots;

    for (const f of shots) {
      out.push(row(T_PLR, 'wpn_' + g.sndStem + '_shot_plr', rel('fire', f)));
      out.push(row(T_NPC, 'wpn_' + g.sndStem + '_shot_npc', rel('fire', f)));
    }
    for (const f of paps) {
      out.push(row(T_PLR, 'wpn_' + g.sndStem + '_pap_shot_plr', rel('fire', f)));
      out.push(row(T_NPC, 'wpn_' + g.sndStem + '_pap_shot_npc', rel('fire', f)));
    }
    // foley 1:1 — the alias name IS the wav basename, the convention these
    // ports' animation notetracks were authored against.
    let foley = 0, collapsed = 0;
    if (fs.existsSync(foleyDir)) {
      const wavs = fs.readdirSync(foleyDir).filter(x => x.endsWith('.wav')).sort();
      for (const f of wavs) {
        out.push(row(T_FOLEY, f.slice(0, -4), rel('foley', f)));
        foley++;
      }

      // ---- COLLAPSED FAMILIES — the SILENT RELOAD fix (2026-08-25) ---------
      // User: "I noticed spas doesnt have a reload sound effect."
      //
      // The SPAS ships wpn_t6_spas12_shell_in1..6 and its reload notetrack asks
      // for wpn_t6_spas12_shell_in — the UNNUMBERED name. 1:1 rows alone define
      // six aliases none of which the animation ever calls, so the shell inserts
      // are silent while the pump (which IS unnumbered) plays. That is exactly
      // map 1's silent-reload trap, and the t9 recipe above already collapses
      // numbered families for this reason; the simple-port path did not.
      //
      // BOTH SPELLINGS ARE EMITTED, deliberately. Several rows sharing one alias
      // name is how this engine round-robins, so the collapsed alias gets all N
      // wavs and varies per insert; and the numbered rows stay in case a given
      // port's notetracks do call them. Duplicating a handful of foley rows is
      // free next to a gun that reloads in silence.
      //
      // inspect_partN IS EXEMPT and must stay separate — those are DISTINCT
      // animation events (part 1, part 2, part 3 of one inspect), not variations
      // of one sound. Collapsing them would round-robin the three parts at
      // random. Same carve-out the t9 recipe makes.
      const fam = new Map();
      for (const f of wavs) {
        const base = f.slice(0, -4);
        const stem = base.replace(/\d+$/, '');
        if (stem === base) continue;              // not numbered
        if (/inspect_part$/.test(stem)) continue; // distinct anim events
        if (!fam.has(stem)) fam.set(stem, []);
        fam.get(stem).push(f);
      }
      for (const [stem, members] of fam) {
        for (const f of members) out.push(row(T_FOLEY, stem, rel('foley', f)));
        collapsed++;
      }
    }
    // ---- borrowed draw sound ------------------------------------------------
    let borrowed = '';
    if (g.donor) {
      const [dDir, dWav] = g.donor;
      const dPath = path.join(TOOLS, 'sound_assets', 'skye_ports', dDir, 'foley', dWav);
      // HARD FAIL, never a silent skip: a donor that has been renamed or removed
      // must stop the build, not quietly go back to a silent gun. That is the
      // whole failure mode this table exists to fix.
      if (!fs.existsSync(dPath)) throw new Error('donor wav missing for ' + g.wavDir + ': ' + dPath);
      const ownRaise = 'wpn_' + g.sndStem + '_first_raise';
      out.push(row(T_FOLEY, ownRaise, ['skye_ports', dDir, 'foley', dWav].join(SEP)));
      borrowed = ' + first_raise borrowed from ' + dDir;
    }

    report.push('simple port ' + g.wavDir + ': ' + shots.length + ' shot + ' + paps.length
      + ' pap' + (fellBack ? ' (fell back to shot wavs)' : '') + ' + ' + foley + ' foley + ' + collapsed + ' collapsed' + borrowed);
  }

  // ---- SHARED aliases these ports reference but do not own -----------------
  // The RPG's GDT names wpn_t6_rocket_explosion_npc/_plr on BOTH its forms, and
  // nothing in this repo or in the installed alias CSVs defines them — so the
  // rocket would detonate in total silence, which is the single worst thing that
  // can happen to a launcher. The wav ships in the shared t6_common folder
  // (there is no per-gun copy), hence a separate list: it is keyed by the ALIAS
  // the GDT asks for, not by a gun.
  //
  // Explosions are 3d for both listener types — the npc template is the one with
  // the distance columns filled in, and a player-fired rocket that lands 40 feet
  // away should still fall off with distance. That is why both rows use T_NPC.
  const SHARED_ALIASES = [
    { alias: 'wpn_t6_rocket_explosion', wav: ['skye_ports', 't6_common', 'wpn_t6_rocket_explosion.wav'].join(SEP) },
  ];
  for (const sa of SHARED_ALIASES) {
    out.push(row(T_NPC, sa.alias + '_plr', sa.wav));
    out.push(row(T_NPC, sa.alias + '_npc', sa.wav));
    report.push('shared alias ' + sa.alias + ': 2 rows');
  }
}

out.push('');
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, out.join('\n'), 'utf8');
console.log('wrote ' + OUT);
for (const r of report) console.log('  ' + r);

