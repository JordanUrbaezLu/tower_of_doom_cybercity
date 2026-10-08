// test_v1896_secret_killconfirm_bottle.js — v18.96's three script lanes, read
// from the ACTUAL sources: the teddy-bear song hunt (_tod_secret + the music
// channel's EE gate), the elite kill confirm (_tod_killconfirm + its two hooks
// in _tod_luck) and the elite perk-bottle roll (_tod_bosses + every caller).
// Structural: these are wiring facts a build cannot check (the linker is happy
// with a hook that nobody calls).
//   node tools/test_v1896_secret_killconfirm_bottle.js
const fs = require('fs'), path = require('path'), assert = require('assert/strict');
const root = path.join(__dirname, '..');
const read = f => fs.readFileSync(path.join(root, f), 'utf8').replace(/\r\n/g, '\n');
const G = f => read('scripts/zm/zm_tower_of_doom/' + f);
const secret = G('_tod_secret.gsc'), kc = G('_tod_killconfirm.gsc'), luck = G('_tod_luck.gsc'),
      bosses = G('_tod_bosses.gsc'), atmos = G('_tod_atmosphere.gsc'), main = G('_tod_main.gsc'),
      hounds = G('_tod_hellhounds.gsc'), reaver = G('_tod_reaver.gsc'), sprinter = G('_tod_sprinter.gsc');
const zone = read('zone_source/zm_tower_of_doom.zone'), csv = read('sound/aliases/tod_ui.csv');
const num = (src, k) => Number((src.match(new RegExp('#define\\s+' + k + '\\s+([-\\d.]+)')) || [])[1]);
const str = (src, k) => (src.match(new RegExp('#define\\s+' + k + '\\s+"([^"]+)"')) || [])[1];

// ---- THE SECRET -------------------------------------------------------------
assert.equal(num(secret, 'TOD_SECRET_COUNT'), 3, 'three bears');
assert.equal((secret.match(/spots\[ \d \] = spot\(/g) || []).length, 3, 'three placed spots');
// v19.64: the fan's Cyber Teddy replaced the stock p7_zm_teddybear. The model, its
// GDT, its sync lane and the two size defines are one lockstep chain; the numbers
// come from the build tool's manifest, never from a hand measurement.
assert.equal(str(secret, 'TOD_SECRET_MODEL'), 'tod_cyber_teddy');
assert.ok(secret.includes('#precache( "model", "tod_cyber_teddy" );'), 'model precached');
assert.ok(zone.includes('\nxmodel,tod_cyber_teddy\n'), 'model zoned');
assert.ok(!/^xmodel,p7_zm_teddybear\s*$/m.test(zone) && !/p7_zm_teddybear" \);|"p7_zm_teddybear"\s*$/m.test(secret), 'the stock bear is retired whole (no zone line, no precache, no define)');
{
  const man = JSON.parse(read('art/cyber_teddy/manifest.json'));
  const gdt = read('source_data/tod_cyber_teddy.gdt'), sync = read('tools/sync_to_modtools.ps1');
  const crypto = require('crypto');
  assert.equal(str(secret, 'TOD_SECRET_REVISION'), man.revision, 'the INIT log names the built revision');
  assert.equal(num(secret, 'TOD_SECRET_LIFT'), man.lift, 'LIFT = the Cyber Teddy mesh -min z (manifest)');
  assert.equal(num(secret, 'TOD_SECRET_HALF_DEPTH'), man.half_depth, 'HALF_DEPTH = its back extent (manifest)');
  assert.ok(man.half_depth >= man.bounds[1][1], 'the back never sinks into a wall');
  assert.ok(man.size[1] <= 20, 'fits the floor-20 hoop lintel (20 deep)');
  assert.ok(gdt.includes('"tod_cyber_teddy" ( "xmodel.gdf" )') && gdt.includes('"filename" "tod_cyber_teddy\\\\tod_cyber_teddy.xmodel_bin"'), 'GDT declares the model');
  assert.ok(/"BulletCollisionLOD" "None"/.test(gdt), 'no bullet collision, like the stock bear (the hunt hits by view ray)');
  assert.ok(gdt.includes('"materialType" "lit_emissive_plus"') && gdt.includes('"colorMap00" "i_tod_cyber_teddy_e"'), 'the glow map is bound');
  for (const [rel, want] of Object.entries(man.files)) {
    const got = crypto.createHash('sha256').update(fs.readFileSync(path.join(root, rel))).digest('hex');
    assert.equal(got, want, rel + ' is the build tool output the manifest recorded');
  }
  assert.ok(sync.includes('"model_export\\tod_cyber_teddy"'), 'sync carries the model folder to the tools root');
  assert.ok(secret.includes('dev_log( "INIT model=" + TOD_SECRET_MODEL + " rev=" + TOD_SECRET_REVISION'), 'INIT log');
}
assert.ok(zone.includes('scriptparsetree,scripts/zm/zm_tower_of_doom/_tod_secret.gsc') && zone.includes('scriptparsetree,scripts/zm/zm_tower_of_doom/_tod_killconfirm.gsc'), 'both modules zoned');
assert.ok(secret.includes('self SetCanDamage( true );') && secret.includes('self waittill( "damage", amount, attacker, dir, point, mod );'), 'shoot detection');
assert.ok(secret.includes('if ( !isdefined( attacker ) || !isplayer( attacker ) )'), 'only a player counts');
assert.equal(str(secret, 'TOD_SECRET_LAUGH'), 'tod_secret_laugh', 'OUR laugh alias (the stock one is in a CSV this map never loads)');
assert.ok(csv.split('\n').some(l => l.startsWith('tod_secret_laugh,') && l.includes('tod\\sfx\\tod_secret_laugh.wav') && l.includes('3d')), 'laugh alias row, 3D');
assert.ok(fs.existsSync(path.join(root, 'sound_assets/tod/sfx/tod_secret_laugh.wav')), 'laugh wav present');
// v18.96b: centre pivot -> every spot lifted; view-ray detection on every shot; the 3 s gap before the song
assert.equal((secret.match(/\+ TOD_SECRET_LIFT \)/g) || []).length, 3, 'all three spots lifted');
assert.ok(secret.includes('callback::on_spawned( &shot_watch );') && secret.includes('self waittill( "weapon_fired" );') && secret.includes('BulletTracePassed( eye, bear.origin, false, self )'), 'view-ray lane');
assert.ok(secret.includes('if ( IS_TRUE( self.tod_secret_hit ) )\n\t\treturn;\n\tself.tod_secret_hit = true;'), 'both lanes latch once');
assert.equal(num(atmos, 'TOD_MUSIC_EE_GAP'), 3, '3 s of silence');
assert.ok(/channel_stop\(\);\s*level thread ee_song_run\(\);/.test(atmos) && /wait TOD_MUSIC_EE_GAP;\s*channel_play\( "tod_music_ee" \);\s*wait TOD_MUSIC_EE_SECS;/.test(atmos), 'stop, gap, song, length');
assert.ok(secret.includes('tod_perk_scatter::play_sound_at_origin( org, TOD_SECRET_LAUGH, TOD_SECRET_LAUGH_SECS );'), 'laugh at the bear');
assert.ok(secret.includes('tod_atmosphere::ee_song_start( TOD_SECRET_RISE_SECS + TOD_SECRET_FLY_SECS )'), 'the third bear arms the song with the flight as its lead');
// v18.96c: the rise-and-flight is paced inside the laugh, and the lead runs before the gap
assert.ok(num(secret, 'TOD_SECRET_RISE_SECS') + num(secret, 'TOD_SECRET_FLY_SECS') <= num(secret, 'TOD_SECRET_LAUGH_SECS'), 'flight fits inside the laugh emitter life');
assert.ok(secret.includes('function bear_fly_away( bear, last )') && secret.includes('bear MoveTo( dest, TOD_SECRET_FLY_SECS') && secret.includes('bear RotateYaw( TOD_SECRET_SPIN_DEG, TOD_SECRET_RISE_SECS + TOD_SECRET_FLY_SECS, TOD_SECRET_RISE_SECS + TOD_SECRET_FLY_SECS, 0 );'), 'one accelerating spin over the whole exit');
assert.ok(secret.includes('spot( ( 1620 - TOD_SECRET_HALF_DEPTH, -520, 0 + TOD_SECRET_LIFT ), ( 0, 270, 0 )'), 'base bear: back to the east wall, facing west');
assert.ok(secret.includes('spot( ( -800 + TOD_SECRET_HALF_DEPTH, -900, zs[ 0 ] + TOD_SECRET_LIFT ), ( 0, 90, 0 )'), 'floor-10 bear: on the floor, back to the outer wall, facing east');
assert.ok(/wait level\.tod_music_ee_lead;\s*wait TOD_MUSIC_EE_GAP;/.test(atmos), 'lead then gap');
{ const lw = path.join(root, 'sound_assets/tod/sfx/tod_secret_laugh.wav'); const lh = fs.readFileSync(lw).subarray(0, 44); const lsecs = (fs.statSync(lw).size - 44) / (48000 * 2 * 2); assert.ok(lh.readUInt32LE(24) === 48000 && lsecs > 8 && lsecs < 9, 'the Samantha laugh wav (8.30 s, cut before the bye-bye) is the one banked'); }
assert.ok(!/IPrintLnBold|SetHintString|iprintln/i.test(secret), 'no on-screen text, no triggerstrings');
assert.ok(main.includes('tod_secret::init();') && main.includes('tod_killconfirm::init();'), 'both inits threaded from _tod_main');
// the song: alias row + wav on the bank contract + the measured length in the define
const row = csv.split('\n').find(l => l.startsWith('tod_music_ee,'));
assert.ok(row, 'tod_music_ee alias row');
assert.ok(row.includes('tod\\music\\tod_music_ee.wav') && row.includes('STREAMED') && row.includes('LOOPING') && row.includes('2d'), 'row shape = the band rows');
const wavPath = path.join(root, 'sound_assets/tod/music/tod_music_ee.wav');
assert.ok(fs.existsSync(wavPath), 'the song wav exists');
const hdr = fs.readFileSync(wavPath).subarray(0, 44);
assert.equal(hdr.readUInt32LE(24), 48000, 'wav 48 kHz');
assert.equal(hdr.readUInt16LE(22), 2, 'wav stereo');
assert.equal(hdr.readUInt16LE(34), 16, 'wav 16-bit');
const secs = num(atmos, 'TOD_MUSIC_EE_SECS');
const dataBytes = fs.statSync(wavPath).size - 44, wavSecs = dataBytes / (48000 * 2 * 2);
assert.ok(Math.abs(wavSecs - secs) < 1.0, `TOD_MUSIC_EE_SECS ${secs} vs wav ${wavSecs.toFixed(2)} s`);
// NO MUSIC CAN OVERTAKE IT: the gate is in channel_play itself, and the resume replays the parked request.
assert.ok(/function channel_play\( alias \)\s*\{\s*if \( IS_TRUE\( level\.tod_music_ee \) && isdefined\( alias \) && alias != "tod_music_ee" \)\s*\{\s*level\.tod_music_ee_pending = alias;[^\n]*\n\s*return;/.test(atmos), 'channel_play parks every other request while the song holds');
assert.ok(atmos.includes('next = level.tod_music_ee_pending;'), 'the parked request resumes');
assert.ok(atmos.includes('level.tod_music_ee_played = true;'), 'once per match');
assert.ok(atmos.includes('IS_TRUE( level.tod_music_ee )') && /boss_music_blocked\(\)\s*\{[\s\S]*?tod_music_ee[\s\S]*?\}/.test(atmos), 'boss track blocked under the song');

// ---- THE KILL CONFIRM ---------------------------------------------------------
assert.ok(/function boss_kill\( killer, kind, org \)\s*\{\s*if \( !isdefined\( killer \) \|\| !isplayer\( killer \) \)\s*return;[\s\S]*?tod_killconfirm::elite_kill\( killer, kind \);/.test(luck), 'elite_kill hangs on boss_kill');
assert.ok(!luck.includes('tod_killconfirm::ding('), 'headshot luck no longer requests the Apex ding');
assert.ok(!kc.includes('PlayLocalSound') && !kc.includes('function ding('), 'elite marker is visual only');
assert.ok(!csv.split('\n').some(l=>l.startsWith('tod_headshot_ding,')), 'Apex ding removed from the sound bank');
assert.ok(kc.includes('e SetShader( "damage_feedback", w, w * 2 );') && kc.includes('e.color = ( 1, 0.18, 0.18 );') && kc.includes('e FadeOverTime( hold );'), 'the red snap on the stock element');
assert.ok(kc.includes('e.color = ( 1, 1, 1 );'), 'colour handed back to white');
assert.ok(num(kc, 'TOD_KC_BOSS_W') > num(kc, 'TOD_KC_ELITE_W') && num(kc, 'TOD_KC_BOSS_HOLD') > num(kc, 'TOD_KC_ELITE_HOLD'), 'the boss marker is bigger and longer');
// no per-hit / ordinary-zombie marker anywhere in the map's own scripts
for (const f of fs.readdirSync(path.join(root, 'scripts/zm/zm_tower_of_doom')).filter(f => f.endsWith('.gsc') && f !== '_tod_killconfirm.gsc'))
  assert.ok(!G(f).includes('hud_damagefeedback'), f + ' must not drive the marker (elites only, one owner)');

// ---- THE PERK BOTTLE ----------------------------------------------------------
assert.equal(num(bosses, 'TOD_ELITE_BOTTLE_PCT'), 10, '10%');
assert.ok(bosses.includes('function grant_elite_reward( name, attacker, org )'), 'org param');
assert.ok(bosses.includes('elite_bottle_roll( name, attacker, org );'), 'roll called from the one payout');
const roll = bosses.slice(bosses.indexOf('function elite_bottle_roll('));
assert.ok(roll.includes('if ( IS_TRUE( level.tod_spire_active ) )') && roll.includes('flag::get( "power_on" )'), 'tower only, power on');
assert.ok(roll.includes('if ( roll >= TOD_ELITE_BOTTLE_PCT )') && roll.includes('zm_powerups::specific_powerup_drop( "tod_free_pap", org )'), 'the bottle is the map\'s own perk-bottle powerup');
// every elite death site hands its origin over, guarded against the same-frame reap
for (const [name, src, call] of [['protector', bosses, 'grant_elite_reward( "ROGUE PROTECTOR", attacker, org )'],
                                 ['guard panzer', bosses, 'grant_elite_reward( "PANZER", killer, org )'],
                                 ['hound', hounds, 'tod_bosses::grant_elite_reward( "HELLHOUND", attacker, org )'],
                                 ['reaver', reaver, 'tod_bosses::grant_elite_reward( "REAVER", attacker, org )'],
                                 ['sprinter', sprinter, 'tod_bosses::grant_elite_reward( "SPRINTER", attacker, org )']]) {
  assert.ok(src.includes(call), name + ' passes org');
  if (name !== 'guard panzer') assert.ok(src.includes('if ( isdefined( self ) )\n\t\torg = self.origin;'), name + ' guards the corpse read');
}
assert.equal((bosses.match(/grant_elite_reward\( "[A-Z ]+", \w+ \);/g) || []).length, 0, 'no two-arg elite reward call left in _tod_bosses');
assert.equal(((hounds + reaver + sprinter).match(/grant_elite_reward\( "[A-Z ]+", attacker \);/g) || []).length, 0, 'no two-arg call left in the elite modules');

console.log('v18.96: 3 bears (shoot-detect, laugh 3D, once-per-match song that NOTHING overtakes; wav 48k/16/stereo, ' + wavSecs.toFixed(1) + 's), elite kill confirm (red snap, no Apex ding, elites only), 10% perk bottle from every elite death site (tower, power on). PASS');
