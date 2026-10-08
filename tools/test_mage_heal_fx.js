// Run the live GSC FX ownership/cleanup logic with mocked entities.
// The engine must still be used to assess the appearance and particle fade.
const fs=require('fs'), path=require('path'), vm=require('vm'), assert=require('assert/strict');
const root=path.resolve(__dirname,'..');
const source=fs.readFileSync(path.join(root,'scripts/zm/zm_tower_of_doom/_tod_mage_elements.gsc'),'utf8');
function body(name) {
    const start=source.indexOf('{',source.indexOf('function '+name+'('));
    let end=start+1,depth=1;
    while(depth) { if(source[end]==='{')depth++; if(source[end]==='}')depth--; end++; }
    return source.slice(start+1,end-1)
        .replace(/host thread heal_visual_lifetime\( self \);/g,'threads.push({host,player:self});')
        .replace(/self endon\(/g,'endOn(')
        .replace(/player laststand::player_is_in_laststand\(\)/g,'player.down')
        .replace(/\b(host|self) (SetModel|LinkTo|Delete)\(/g,'$1.$2(')
        .replace(/\( 0, 0, 0 \)/g,'[0,0,0]')
        .replace(/wait 0.1;/g,'yield "tick";');
}
const env={threads:[],hosts:[],effects:[],stops:[],level:{_effect:{tod_mage_heal:'green'}},
    isdefined:e=>e!==undefined&&!e?.deleted,IsAlive:p=>p.alive,
    aura_level:p=>p.protection, endOn:e=>env.stops.push(e),
    Spawn:()=>{
        if(env.failSpawn)return undefined;
        const h={SetModel(m){this.model=m;},LinkTo(p,tag){this.parent=p;this.tag=tag;},Delete(){this.deleted=true;}};
        env.hosts.push(h);return h;
    },PlayFxOnTag:(fx,host,tag)=>env.effects.push({fx,host,tag})};
vm.createContext(env);
vm.runInContext(`function touch(){let host;${body('heal_visual_touch')}}
function* lifetime(player){${body('heal_visual_lifetime')}}`,env);
function player(){return {alive:true,down:false,protection:1,origin:[0,0,0]};}
function touch(p){env.self=p;env.touch();return p.tod_mage_heal_host;}
const caster=player(),teammate=player();
const a=touch(caster),b=touch(teammate);
for(let i=0;i<20;i++){assert.equal(touch(caster),a);assert.equal(touch(teammate),b);}
assert.equal(env.hosts.length,2);assert.equal(env.effects.length,2,'pulses/overlaps never pile up FX');
assert.equal(a.parent,caster);assert.equal(b.parent,teammate);assert.equal(a.tag,'j_spineupper');
for(const reason of ['expiry','down','death','disconnect']) {
    const p=player(),h=touch(p);env.self=h;const co=env.lifetime(p);
    assert.equal(co.next().value,'tick');
    p.protection=6;assert.equal(co.next().value,'tick','stronger overlapping aura keeps same host');
    if(reason==='expiry')p.protection=0;
    if(reason==='down')p.down=true;
    if(reason==='death')p.alive=false;
    if(reason==='disconnect')p.deleted=true;
    assert.equal(co.next().done,true,reason);assert.equal(h.deleted,true,reason+' reaps host');
    if(reason!=='disconnect')assert.equal(p.tod_mage_heal_host,undefined);
}
caster.protection=0;env.self=a;assert.equal(env.lifetime(caster).next().done,true);
caster.protection=1;assert.notEqual(touch(caster),a,'re-entry creates a fresh host');
env.failSpawn=true;assert.equal(touch(player()),undefined,'spawn failure is harmless');
assert(env.stops.includes('entityshutdown'));
const effect=fs.readFileSync(path.join(root,'share/raw/fx/tod/mage/fx_healing_aura_player.efx'),'utf8');
assert(effect.includes('gfx_ui_zmb_bgb_revive_em'),'stock revive icon');
assert(effect.includes('spawnLooping 100 0;'));
assert(effect.includes('fadeOutRange 15.000000 65.000000;'),'native near-camera fade');
assert(source.includes('p heal_visual_touch();'));
assert(!source.includes('tod_mage_heal_hit'));
console.log('Healing Aura FX pass: one torso host per recipient, overlapping pulses, expiry/down/death/disconnect cleanup, re-entry and spawn failure. Native visuals pending.');
