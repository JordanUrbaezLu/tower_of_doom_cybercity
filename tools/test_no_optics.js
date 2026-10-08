// SKIRMISHER + HEAVY PRIMARIES CARRY NO OPTIC, AND STILL HAVE SOMETHING TO AIM
// DOWN (v19.22, 2026-09-21).
//
// User: "remove sights from all skirmisher and heavy primary guns base and pap
// ... make sure we dont break the ADS. Sometimes that happens."
//
// The removal is three edits per gun and the third was missing for two passes -
// see the noOptic() block in gen_tod_twins.js. This gate pins all three on EVERY
// emitted variant of all six primaries, base and PaP:
//
//   A. no attachment slot references an optic model or mounts on an optic tag
//   B. no ADS animation is an optic animation
//   C. the PaP form's sight tags equal the base form's
//
// C is the one that catches a BROKEN ADS rather than a visible dot. hideTags is
// what draws or hides the iron sights, so a PaP form hiding a tag its base shows
// is a gun whose restored ADS pose raises it to a sight nobody is drawing. That
// reads as "ADS is broken" in game and is invisible in a hip-pose screenshot.
//
// It compares against the BASE FORM, never a hardcoded tag list, so a port
// update that legitimately renames a tag moves both halves together and stays
// green - while one that changes only the PaP half fails here instead of in the
// user's playtest.
const fs = require('fs');
const assert = require('assert/strict');

// "sight" catches optic names like ..._sight_reflex; IRON sights are the one
// "sight" a no-optic gun is supposed to carry (the Enfield's world irons are an
// attachment, `wm_t5_enfield_iron_sights` on `tag_iron_sights`), so they are
// excluded by the lookbehind. reddot/elbit/susat/kobra/otero are the ports' own
// optic names that the generic words miss (the Enfield's red dot ADS anims are
// `am_t5_enfield_reddot_ads_*`).
const OPTIC = /reflex|reddot|red_dot|aimpoint|quickdot|snappoint|microflex|holo|acog|scope|elbit|susat|kobra|otero|(?<!iron_)sight/i;

// Tags a PaP form may hide that its base does not, with the reason. These are
// NOT sights - they are geometry a PaP-only attachment covers. Anything else
// that differs is a sight-picture change and fails.
const ATTACHMENT_TAGS = {
  tag_clip: 'the HK21 PaP wears an extended mag over the built-in clip',
};

// The six skirmisher/heavy primaries. Tier 9 entries in the ladder are
// secondaries and are out of scope - the user asked for primaries. The Death
// Machine never had an optic and is here to keep it that way.
const GUNS = [
  // The assault's tier-1 ENFIELD (v19.51, 2026-09-23, user after playing the
  // v19.25 SUSAT: "the tip of the ACOG is not aligned with where it actually
  // shoots"): both forms aim down the irons now. Its base carries the irons as
  // a WORLD attachment (`wm_t5_enfield_iron_sights`), which is why OPTIC above
  // excludes "iron_sight". The Krig 6 and AK-47 keep their ACOGs and stay out.
  { cls: 'assault', tier: 1, stem: 't5_enfield' },
  { cls: 'skirmisher', tier: 1, stem: 't6_msmc' },
  { cls: 'skirmisher', tier: 2, stem: 't9_mp5' },
  { cls: 'skirmisher', tier: 3, stem: 't6_mp7' },
  { cls: 'heavy', tier: 1, stem: 't6_mk48' },
  { cls: 'heavy', tier: 2, stem: 't5_hk21' },
  { cls: 'heavy', tier: 3, stem: 't6_death_machine' },
  // The slasher's UDM secondary is here because it had the SAME half-removed
  // sight (v19.24): v16.12 painted its red dot invisible and left the packed
  // form raising to the optic's eye height. Not a primary, but the identical
  // defect, so it belongs under the identical gate.
  { cls: 'slasher', tier: 'sec', stem: 'iw7_udm' },
  // The heavy's tier-3 NAIL GUN sidearm (2026-09-23, user: "make sure its on
  // neither"): its PaP form wore the port's Microflex reflex. It is a
  // projectileweapon, which is why the block reader below takes both gdfs.
  { cls: 'heavy', tier: 'sec', stem: 't9_nail_gun' },
];

const src = fs.readFileSync('source_data/tod_weapon_twins.gdt', 'utf8');
const blocks = new Map(
  [...src.matchAll(/"([^"\n]+)" \( "(?:bullet|projectile)weapon.gdf" \)\s*\{([\s\S]*?)\n\t\}/g)].map(
    m => [m[1], Object.fromEntries(
      [...m[2].matchAll(/"([^"\n]+)" "([^"\n]*)"/g)].map(f => [f[1], f[2]]))]));

const sightTags = f => new Set(
  (f.hideTags || '').split(/\\r\\n|\\n|\\r/).map(s => s.trim())
    .filter(Boolean).filter(t => !(t in ATTACHMENT_TAGS)));

let checked = 0, forms = 0;

for (const { cls, tier, stem } of GUNS) {
  const mine = [...blocks].filter(([n]) => n === stem || n.startsWith(stem + '_'));
  assert(mine.length > 0, `${cls} T${tier}: no emitted forms for ${stem} - did the ladder rename it?`);

  // Pair every PaP form with the base form of the same axis suffix, so a gun
  // with an axis ladder is checked rung by rung rather than against rung 0.
  for (const [name, f] of mine) {
    forms++;
    const where = `${cls} T${tier} ${name}`;

    // A. no optic model, and no attachment mounted on an optic tag.
    for (const [key, val] of Object.entries(f)) {
      if (!/^attach(View|World)Model(Tag)?\d+$/.test(key) || !val) continue;
      assert(!OPTIC.test(val),
        `${where}: attachment ${key}="${val}" is an optic. Clear it through noOptic() in the generator.`);
    }

    // B. no optic ADS animation. An optic anim raises the gun to the optic's
    // eye height; with the optic gone the irons sit below the eye line.
    for (const key of ['adsUpAnim', 'adsDownAnim', 'adsFireAnim', 'adsLastShotAnim', 'adsUpOtherScopeAnim']) {
      const val = f[key];
      if (!val) continue;
      assert(!OPTIC.test(val),
        `${where}: ${key}="${val}" is an optic ADS animation - the ADS pose would aim above the irons.`);
    }

    // ADS itself must still work. This is the "don't break the ADS" half: a
    // sight removal must never reach for aimDownSight 0.
    assert.equal(f.aimDownSight, '1', `${where}: aimDownSight is off - the gun cannot ADS at all.`);
    assert(f.adsUpAnim && f.adsDownAnim, `${where}: missing an ADS transition animation.`);

    // C. PaP sight tags == base sight tags.
    if (!name.includes('_up')) continue;
    // The MP7's dark HANDLING rung (h4) is PaP-only, so the same-rung base form
    // does not exist. Fall back to the stem's first base form: an axis rung tunes
    // handling and recoil, never the sight picture, so any rung is a valid model.
    let baseName = name.replace('_up', '');
    let base = blocks.get(baseName);
    if (!base) {
      const first = mine.find(([n]) => !n.includes('_up'));
      assert(first, `${where}: ${stem} emits no base form at all to compare sight tags against.`);
      [baseName, base] = first;
    }

    // An optic carries its own zoom. The PaP forms here aim down the base's
    // irons now, so they must zoom like the base too - the map's PaP bonus is
    // faster ADS transitions and less kick, never a different magnification.
    for (const key of ['adsZoom1_focalLength', 'adsZoom1_fStop', 'adsZoom2_focalLength',
                       'adsZoom3_focalLength', 'adsZoomInFrac', 'adsZoomOutFrac', 'adsOverlayShader']) {
      assert.equal(f[key], base[key],
        `${where}: ${key}="${f[key]}" but ${baseName} has "${base[key]}" - that is an optic's ADS view on a gun with iron sights.`);
    }

    const up = sightTags(f), bs = sightTags(base);
    const hidden = [...up].filter(t => !bs.has(t));   // PaP hides a sight the base shows
    const shown = [...bs].filter(t => !up.has(t));    // PaP shows a sight the base hides

    assert.equal(hidden.length, 0,
      `${where}: hides ${hidden.join(', ')} but ${baseName} does not. ` +
      `The PaP borrows the base's ADS pose, so a sight the base aims down must be drawn here too. ` +
      `Pass the base's hideTags to noOptic(), or add the tag to ATTACHMENT_TAGS if a PaP attachment covers it.`);
    assert.equal(shown.length, 0,
      `${where}: shows ${shown.join(', ')} but ${baseName} hides it. ` +
      `With the optic gone that is bare mounting hardware on the gun.`);
    checked++;
  }
}

assert(forms > 30, `only ${forms} forms matched - the stem names look stale against the ladder.`);

// ---------------------------------------------------------------------------
// THE WHOLE ROSTER (2026-09-23; user, watching v19.22 playthroughs: "the iron
// sights of a lot of our guns also got removed ... we need to find all the
// occasions of this and fix it"). The section above covers the guns whose
// optics were REMOVED. This one pairs EVERY packed form the generator emits
// with its base form - primaries, sidearms, the akimbo pair, melee - and holds
// the rules that are true for any gun whatever its optic policy:
//   1. the packed form can aim down sights (unless it is dual-wield or melee);
//   2. an optic ADS animation needs an optic MODEL in an attachment slot (the
//      UDM's invisible dot, v19.24: the pose rose to a sight nobody drew);
//   3. a sight tag the base draws may be hidden by the packed form ONLY when
//      an optic model replaces it (the MP7 / Mk 48 / HK21 bug shipped in v19.22);
//   4. a rail or mount tag the base hides may be shown by the packed form ONLY
//      when an optic model sits on it (the MP5's bare rail in v19.22);
//   5. without an optic, the packed form's ADS zoom and overlay equal the base's;
//   6. the packed form uses the base's first-person model (gunModel).
// The optics that pass today pass because their MODEL is attached, never by
// name: the assault rifles' 2x ACOG (v19.25), the Magnum's Otero reflex, the
// MOG 12's reflex, the RK7's ELO. Whether those models were actually BUILT is
// the post-link half, verify_weapon_models_linked.js.
const OPTIC_ANIM  = /reflex|reddot|red_dot|aimpoint|quickdot|snappoint|microflex|holo|acog|scope|_elo_|otero|kobra|elbit|susat/i;
const OPTIC_MODEL = /reflex|reddot|aimpoint|quickdot|snappoint|microflex|holo|acog|scope|_elo$|_elo_|otero|kobra|elbit|susat/i;
const SIGHT_TAG   = /sight|iron|reticle/i;
const MOUNT_TAG   = /rail|mount|scope/i;
const ALIAS = { t6_executioner_rdw: 't6_executioner' };   // the packed Executioner is the akimbo pair's right half
const gen = fs.readFileSync('tools/gen_tod_twins.js', 'utf8');
const MELEE = new Set([...gen.matchAll(/stem: '([^']+)'[^\n]*melee: true/g)].map(m => m[1]));
assert(MELEE.size >= 3, 'the generator no longer marks melee stems with melee: true on the stem line - update this gate.');
const tagSet = f => new Set((f.hideTags || '').split(/\\r\\n|\\n|\\r/).map(s => s.trim()).filter(Boolean));

let pairs = 0, withOptic = 0, exempt = 0;
const stemsPaired = new Set();
for (const [name, f] of blocks) {
  if (!name.includes('_up')) continue;
  const stem0 = name.slice(0, name.indexOf('_up'));
  const stem = ALIAS[stem0] || stem0;
  const baseForms = [...blocks].filter(([n]) => (n === stem || n.startsWith(stem + '_')) && !n.includes('_up'));
  assert(baseForms.length > 0, `${name}: no base form for stem ${stem} - a packed gun with nothing to compare against.`);
  const same = baseForms.find(([n]) => n === name.replace('_up', ''));
  const [baseName, base] = same || baseForms[0];
  stemsPaired.add(stem);
  const where = `${stem}: ${name} vs ${baseName}`;
  const akimbo = f.dualWield === '1';
  const melee = MELEE.has(stem);
  const opticModels = Object.entries(f).filter(([k, v]) => /^attachViewModel\d+$/.test(k) && v && OPTIC_MODEL.test(v)).map(([, v]) => v);
  const hasOptic = opticModels.length > 0;
  const opticAnims = ['adsUpAnim', 'adsDownAnim', 'adsFireAnim', 'adsLastShotAnim'].filter(k => OPTIC_ANIM.test(f[k] || ''));

  if (akimbo || melee) {
    exempt++;
  } else {
    assert.equal(f.aimDownSight, '1', `${where}: the packed form cannot aim down sights (rule 1).`);
    assert(f.adsUpAnim && f.adsDownAnim, `${where}: missing an ADS transition animation (rule 1).`);
    assert(!opticAnims.length || hasOptic,
      `${where}: ${opticAnims.map(k => k + '="' + f[k] + '"').join(', ')} raise to an optic but no optic model is attached (rule 2, the v19.24 UDM bug).`);
    // Rule 6 allows the port's OWN packed model (base name + "_up": the AW
    // Bulldog ships one), which is the port author's packed look and links
    // (verify_weapon_models_linked.js); anything else is a different gun.
    assert(f.gunModel === base.gunModel || f.gunModel === base.gunModel + '_up',
      `${where}: first-person model "${f.gunModel}" is neither the base's "${base.gunModel}" nor its _up twin (rule 6).`);
  }

  const up = tagSet(f), bs = tagSet(base);
  const hiddenSights = [...up].filter(t => !bs.has(t) && SIGHT_TAG.test(t));
  const shownMounts = [...bs].filter(t => !up.has(t) && MOUNT_TAG.test(t));
  assert(!hiddenSights.length || hasOptic,
    `${where}: hides ${hiddenSights.join(', ')} that the base draws, with no optic model replacing it (rule 3, the v19.22 MP7 / Mk 48 / HK21 bug).`);
  assert(!shownMounts.length || hasOptic,
    `${where}: shows ${shownMounts.join(', ')} that the base hides, with no optic sitting on it (rule 4, the v19.22 MP5 bare rail).`);

  if (!hasOptic && !akimbo && !melee) {
    for (const key of ['adsZoom1_focalLength', 'adsZoom1_fStop', 'adsZoom2_focalLength',
                       'adsZoom3_focalLength', 'adsZoomInFrac', 'adsZoomOutFrac', 'adsOverlayShader']) {
      assert.equal(f[key], base[key],
        `${where}: ${key}="${f[key]}" but the base has "${base[key]}" - an optic's ADS view on a gun without one (rule 5).`);
    }
  }
  pairs++;
  if (hasOptic) withOptic++;
}
assert(pairs >= 40, `only ${pairs} packed forms paired - the generated GDT looks truncated.`);

console.log(`No-optic gate: ${forms} no-optic gun forms (Enfield, skirmisher + heavy primaries, UDM, Nail Gun) carry no optic model or optic ADS anim, ` +
            `all can ADS, and ${checked} PaP forms match their base form's sight picture. ` +
            `Roster: ${pairs} packed forms over ${stemsPaired.size} guns paired with their base (${withOptic} carry an optic model, ` +
            `${exempt} akimbo/melee exempt from the ADS rules): no hidden sight without an optic, no bare rail, no optic pose without an optic. PASS.`);
