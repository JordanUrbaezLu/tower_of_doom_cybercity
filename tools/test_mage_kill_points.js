const fs = require('fs'), vm = require('vm'), assert = require('assert/strict');
const score = fs.readFileSync('C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/share/raw/scripts/zm/_zm_score.gsc','utf8');
const up = fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_upgrades.gsc','utf8');
function body(src,name) {
  const start=src.indexOf('{',src.indexOf('function '+name+'('));
  let end=start+1, depth=1;
  while(depth) { if(src[end]==='{') depth++; if(src[end]==='}') depth--; end++; }
  return src.slice(start+1,end-1);
}
const ctx={isdefined:x=>x!==undefined, IS_TRUE:x=>x===true, IsSubStr:(s,k)=>s.includes(k)};
vm.createContext(ctx);
vm.runInContext('function mage_kill_points(player) {'+body(up,'mage_kill_points')+'}',ctx);
vm.runInContext('function bounty_kill_value(mod,hitloc,attacker,zombie) {'+body(up,'bounty_kill_value').replaceAll('zm_score::','')+'}',ctx);
Object.assign(ctx, {level:{zombie_team:'axis',zombie_vars:{allies:{zombie_powerup_insta_kill_on:0}}},
 base:()=>50, bonus:()=>0, stat:()=>{}});
const handler=body(up,'zombie_death_score')
 .replace('zm_score::get_zombie_death_player_points','base')
 .replace('self zm_score::player_add_points_kill_bonus','bonus')
 .replaceAll('self zm_stats::increment_client_stat','stat')
 .replaceAll('self zm_stats::increment_player_stat','stat');
vm.runInContext('function deathScore(self,event,mod,hit_location,zombie_team,damage_weapon) {'+handler+'}',ctx);
for(const cls of ['mage','slasher','assault',undefined])
// v19.58: stock passes NO team for an ordinary zombie kill (self._race_team is
// undefined outside race mode), so undefined must pay the Mage rate; only a
// non-horde team (here 'allies') does not.
for(const team of ['axis',undefined,'allies'])
for(const nominalBonus of [0,10,50,80])
for(const mod of ['MOD_PROJECTILE','MOD_GRENADE_SPLASH','MOD_MELEE','MOD_UNKNOWN'])
for(const insta of [0,1]) {
 ctx.bonus=()=>nominalBonus;
 ctx.level.zombie_vars.allies.zombie_powerup_insta_kill_on=insta;
 const expected=cls==='mage'&&team!=='allies'?80:50+nominalBonus*(insta&&mod==='MOD_UNKNOWN'?2:1);
 const actual=ctx.deathScore({tod_class:cls,team:'allies'},'death',mod,'torso',team,{});
 assert.equal(actual,expected);
 for(const scalar of [1,2]) assert.equal(scalar*Math.ceil(actual/10)*10,scalar*expected);
}
assert.ok(up.includes('zm_score::register_score_event( "death", &zombie_death_score )'));
assert.ok(score.includes('[[ level.a_func_score_events[ event ] ]]( event, mod, hit_location, zombie_team, damage_weapon )'));
assert.ok(!fs.existsSync('scripts/zm/_zm_score.gsc'));
assert.ok(!up.includes('zm_score::tod_mage_kill_points'));
for(const mod of ['MOD_MELEE','MOD_PROJECTILE','MOD_GRENADE_SPLASH','MOD_UNKNOWN'])
for(const hit of ['head','torso',undefined]) assert.equal(ctx.bounty_kill_value(mod,hit,{tod_class:'mage'}),80);
assert.equal(ctx.bounty_kill_value('MOD_MELEE','torso',{tod_class:'slasher'}),120);
assert.equal(ctx.bounty_kill_value('MOD_BULLET','head',{tod_class:'assault'}),100);
assert.equal(ctx.bounty_kill_value('MOD_BULLET','torso',{tod_class:'assault'}),60);
assert.ok(up.includes('bounty_kill_value( mod, hitloc, attacker, zombie )'));
assert.ok(up.includes('bounty_kill_value( self.damagemod, self.damagelocation, attacker, self )'));
// 2026-10-04: a CLEAVE kill's nominal is what it paid (tools/test_cleave_kill_pay.js covers the lane)
assert.equal(ctx.bounty_kill_value('MOD_UNKNOWN','none',{tod_class:'slasher'},{tod_cleave_kill_pts:90}),90);
assert.equal(ctx.bounty_kill_value('MOD_UNKNOWN','none',{tod_class:'slasher'},{}),60);
console.log('Mage points: 256 death-hook cases plus native multipliers; all damage types, Double Points, dogs, other classes/events and Bounty passed.');

const hud=fs.readFileSync('scripts/zm/_zm_aetherium_hud.gsc','utf8');
let popup=body(hud,'zombie_death_callback').split('// Process both regular zombies')[0];
popup=popup.replaceAll('[[ level.tod_mage_kill_points_fn ]]','level.tod_mage_kill_points_fn').replace('[[ level.tod_bounty_preview_fn ]]','level.tod_bounty_preview_fn')
 .replace('attacker LuiNotifyEvent( &"score_event", 2, &"ZM_AETHERIUM_KF_ELIMINATION", player_points );','attacker.popup = player_points;')
 .replace('zm_utility::is_player_valid( attacker )','is_player_valid( attacker )');   // v19.58 downed-killer gate
Object.assign(ctx,{IsPlayer:p=>p.player,is_player_valid:p=>!p.downed,IS_EQUAL:(a,b)=>a===b,level:{tod_mage_kill_points_fn:ctx.mage_kill_points,zombie_team:'axis',zombie_vars:{allies:{zombie_point_scalar:1}}}});
vm.runInContext('function popup(self,attacker,death,weapon,mod,sHitLoc) {'+popup+'}',ctx);
for(const scalar of [1,2]) for(const bonus of [0,10,20]) {
 ctx.level.zombie_vars.allies.zombie_point_scalar=scalar;
 ctx.level.tod_bounty_preview_fn=()=>bonus;
 const p={player:true,tod_class:'mage',team:'allies'};
 ctx.popup({team:'axis',archetype:'zombie'},p,true,{},'MOD_PROJECTILE','none');
 assert.equal(p.popup,80*scalar+bonus);
 delete p.popup;
 ctx.popup({team:'axis',archetype:'zombie'},p,false,{},'MOD_PROJECTILE','none');
 assert.equal(p.popup,undefined);
 ctx.popup({team:'axis',archetype:'dog'},p,true,{},'MOD_PROJECTILE','none');
 assert.equal(p.popup,undefined);
}
// v19.58: a downed killer is not paid by stock, so it gets no popup either.
{
 const d={player:true,tod_class:'mage',team:'allies',downed:true};
 ctx.popup({team:'axis',archetype:'zombie'},d,true,{},'MOD_PROJECTILE','none');
 assert.equal(d.popup,undefined);
}
console.log('Mage popup: actual callback agrees with payout, Bounty and Double Points; no popup for a downed killer.');
