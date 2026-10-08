// Execute actual client FX callbacks with fake particles and death events.
const fs=require('fs'), vm=require('vm'), assert=require('assert/strict');
const src=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_mage_elements.csc','utf8');
function body(name) {
    const start=src.indexOf('{',src.indexOf('function '+name+'('));
    let end=start+1, depth=1;
    while(depth) { if(src[end]==='{')depth++; if(src[end]==='}')depth--; end++; }
    return src.slice(start+1,end-1)
        .replace(/self thread chain_fx_cleanup\( localClientNum \);/g,'startCleanup(localClientNum);')
        .replace(/self util::waittill_any_timeout\( 1.5, "death", "entityshutdown" \);/g,'yield "death-or-timeout";')
        .replace(/self endon\(/g,'endOn(').replace(/self notify\(/g,'notify(')
        .replace(/self (\w+)\(/g,'$1(');
}
const env={self:{}, level:{_effect:{tod_mage_chain:'torso'}}, alive:true, kills:[], plays:[], jobs:{}, serial:0};
Object.assign(env,{
    isdefined:v=>v!==undefined, IsAlive:()=>env.alive,
    KillFX:(client,id)=>env.kills.push([client,id]),
    PlayFXOnTag:(client,fx,target,tag)=>{ assert.equal(target,env.self);assert.equal(tag,'j_spineupper'); env.plays.push(client);return ++env.serial; },
    notify:event=>{const client=event.split('_').at(-1);if(env.jobs[client])env.jobs[client].return();},
    endOn:()=>{}, startCleanup:client=>{env.jobs[client]=env.cleanup(client);env.jobs[client].next();},
});
vm.createContext(env);
vm.runInContext(`function chain_fx_stop(localClientNum) {${body('chain_fx_stop')}}
function callback(localClientNum,oldVal,newVal) {${body('chain_fx_cb')}}
function* cleanup(localClientNum) {${body('chain_fx_cleanup')}}`,env);
env.callback(0,0,1);assert.equal(env.serial,1);
env.callback(1,0,1);assert.equal(env.serial,2);
env.callback(0,1,2);assert.deepEqual(env.kills,[[0,1]],'refresh kills only this viewer old particles');
env.jobs[0].next();assert.deepEqual(env.kills.at(-1),[0,3],'death/shutdown/timeout kills particles');
assert.equal(env.self.tod_chain_fx[1],2,'other viewer remains independent');
env.alive=false;env.callback(1,1,2);assert.deepEqual(env.kills.at(-1),[1,2]);
assert.equal(env.serial,3,'late positive field cannot play on a dead zombie');
env.alive=true;env.callback(0,0,1);env.callback(0,1,0);
assert.equal(env.self.tod_chain_fx[0],undefined,'server expiry clears particles');
console.log('Chain FX passed: torso attachment, refresh, death/expiry cleanup, late dead snapshot and independent viewers.');
