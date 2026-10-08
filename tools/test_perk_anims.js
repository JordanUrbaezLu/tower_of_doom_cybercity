// Actual GSC state/sequence logic with mocked native animation calls.
// This checks transitions and movement guards, not engine rendering.
//
// 2026-09-23 (v19.44): the Double Tap volley is SCHEDULED from the fire clip's
// start on the clip's authored shot frames. The clip's script notes wake the
// AnimScripted done-notify (the user's log: the fire clip's wait returned in
// 0 ms, shots=0), so a clip finishes only on the "end" note and no shot may
// ever be driven by a note. This file pins both rules and the frame table.
const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const path = require('path');
const root = path.resolve(__dirname, '..');
const src = fs.readFileSync(path.join(root, 'scripts/zm/zm_tower_of_doom/_tod_perk_anims.gsc'), 'utf8');
function body(name) {
    const at = src.indexOf('function ' + name + '(');
    assert(at >= 0, name);
    const start = src.indexOf('{', at);
    let end = start + 1, depth = 1;
    while (depth) { if (src[end] === '{') depth++; if (src[end] === '}') depth--; end++; }
    return src.slice(start + 1, end - 1)
        .replace(/(\w+) GetEntityNumber\(\)/g, 'GetEntityNumber($1)')
        .replace(/foreach \( enemy in GetAITeamArray\( team \) \)/g, 'for (const enemy of GetAITeamArray(team))')
        .replace(/foreach \( z in ai \)/g, 'for (const z of ai)')
        .replace(/victim DoDamage\(/g, 'DoDamage(victim, ')
        .replace(/(\w+) \+ (direction|line) \* (TOD_DOUBLE_TAP_\w+)/g, 'rayEnd($1, $2, $3)')
        // v19.48 aimed-shot vector arithmetic (GSC vectors; JS needs helpers)
        .replace(/(\w+)\.origin - origin\b/g, 'vsub($1.origin, origin)')
        .replace(/chest - origin\b/g, 'vsub(chest, origin)')
        .replace(/(\w+)\.origin \+ \( 0, 0, TOD_DOUBLE_TAP_AIM_Z \)/g, 'vadd($1.origin, [0, 0, TOD_DOUBLE_TAP_AIM_Z])')
        .replace(/\( to\[ 0 \], to\[ 1 \], 0 \)/g, '[to[0], to[1], 0]')
        .replace(/\( aim\[ 0 \], aim\[ 1 \], 0 \)/g, '[aim[0], aim[1], 0]')
        .replace(/\( 0, self\.angles\[ 1 \], 0 \)/g, '[0, self.angles[1], 0]')
        .replace(/\.size\b/g, '.length')
        .replace(/(?:self|level) endon\(/g, 'endOn(')
        .replace(/self thread (\w+)\(/g, 'startThread("$1", ')
        .replace(/self play\(([^;]+)\);/g, 'yield [$1];')
        .replace(/self rest_pose\(/g, 'yield* rest_pose(')
        .replace(/self (\w+)\(/g, '$1(')
        .replace(/wait ([^;]+);/g, 'yield $1;');
}
const env = {IS_TRUE:v => v === true, isdefined:v => v !== undefined,
    dev_log:line => env.logs.push(line), GetEntityNumber:e => e ? e.id : 0,
    IsAlive:e => !!e?.alive, IsPlayer:e => !!e?.player,
    // ONE zombie list for both the pick and the enemy check (v19.48b). The engine threw on
    // GetAIArray( "axis" ) every shot of the second playtest; it is pinned out below.
    GetAITeamArray:team => {assert.equal(team,'axis'); return env.zombies;},
    Distance:(a,b) => Math.hypot(a[0]-b[0],a[1]-b[1],a[2]-b[2]), Abs:Math.abs, SpawnStruct:() => ({}),
    vsub:(a,b) => a.map((v,i) => v-b[i]), vadd:(a,b) => a.map((v,i) => v+b[i]),
    TOD_DOUBLE_TAP_AIM_COS:Number(src.match(/#define TOD_DOUBLE_TAP_AIM_COS\s+([\d.]+)/)[1]),
    TOD_DOUBLE_TAP_AIM_Z:Number(src.match(/#define TOD_DOUBLE_TAP_AIM_Z\s+(\d+)/)[1]),
    TOD_DOUBLE_TAP_AIM_DZ:Number(src.match(/#define TOD_DOUBLE_TAP_AIM_DZ\s+(\d+)/)[1]),
    TOD_DOUBLE_TAP_AIM_TRIES:Number(src.match(/#define TOD_DOUBLE_TAP_AIM_TRIES\s+(\d+)/)[1]),
    TOD_DOUBLE_TAP_LOS_FRAC:Number(src.match(/#define TOD_DOUBLE_TAP_LOS_FRAC\s+([\d.]+)/)[1]),
    GetTagOrigin:tag => {env.tags.push(tag); return [100,200,40];},
    GetTagAngles:tag => {env.tags.push(tag); return [5,90,0];},   // pitch 5 marks "the animated pistol"; the machine facing is (0, yaw, 0)
    AnglesToForward:angles => {assert.equal(angles[1],90); return angles[0]===5 ? env.aim : [0,1,0];},
    Length:v => Math.hypot(...v), VectorNormalize:v => {const L = Math.hypot(...v) || 1; return v.map(c => c / L);},
    rayEnd:(a,b,length) => a.map((v,i)=>v+b[i]*length),
    BulletTrace:(start,end,characters,ignored) => {env.traces.push({start,end,characters,ignored}); return env.traceAt(start,end,characters,ignored);},
    GetWeapon:name => name, GetTime:() => env.time, int:Math.trunc, array:(...items) => items,
    DoDamage:(victim,...args) => {assert.equal(victim.tod_perk_machine_hit,true); victim.health -= args[0]; env.damage.push({victim,args});},
    TOD_DOUBLE_TAP_DAMAGE:Number(src.match(/#define TOD_DOUBLE_TAP_DAMAGE (\d+)/)[1]),
    TOD_DOUBLE_TAP_RANGE:Number(src.match(/#define TOD_DOUBLE_TAP_RANGE (\d+)/)[1]),
    TOD_DOUBLE_TAP_FPS:Number(src.match(/#define TOD_DOUBLE_TAP_FPS (\d+)/)[1]),
    TOD_DOUBLE_TAP_RETRY_STEP:Number(src.match(/#define TOD_DOUBLE_TAP_RETRY_STEP (\d+)/)[1]),
    endOn:e => env.ends.add(e), notify:e => env.events.push(e),
    StopAnimScripted:(blend, immediate) => { assert.equal(immediate,true); env.stops++; },
    startThread:(name,...args) => env.threads.push([name,...args])};
vm.createContext(env);
for (const [name,args,locals,generator] of [
    ['kind_for','specialty','',false], ['powered','trigger','spec',false],
    ['stop','','',false], ['pause_for_move','seconds','',false], ['retire','','',false],
    ['resume_after_move','seconds','',true], ['rest_pose','on,power_changed','kind',true],
    ['purchase_sequence','buyer,trigger','',true],
    ['machine_watch','trigger','last_power,last_model,on,power_changed',true],
    ['shot_denial','buyer,trigger','',false], ['enemy_actor','victim','team',false],
    ['volley_frames','','',false], ['volley_muzzle','index','',false], ['volley_pistol','index','',false],
    ['doubletap_volley','buyer,trigger,start_ms','frames,i,due,remaining',true],
    ['volley_target','origin,direction,trigger','pick,team,ai,tried,n,best,best_d,id,d,to,flat,chest,line,blocker,from,trace',false],
    ['doubletap_shot','buyer,trigger,index','reason,muzzle,pistol,origin,aim,direction,pick,dist,stage,trace,blocker,retry_from,victim,hit,victim_id,before,after,struck',false],
]) vm.runInContext(`function${generator?'*':''} ${name}(${args}) { ${locals?'let '+locals+';':''} ${body(name)} }`, env);
function reset(kind='speed') {
    Object.assign(env,{self:{id:12,tod_perk_anim_kind:kind,model:'on',angles:[0,90,0]},
        level:{machine_assets:{test:{on_model:'on'}}},ends:new Set(),events:[],threads:[],stops:0,
        logs:[],tags:[],traces:[],damage:[],zombies:[],time:1000,aim:[0,1,0],
        traceAt:() => ({fraction:1,position:[100,12700,40]})});
    return {machine:env.self,script_noteworthy:'test',power_on:true};
}
let t=reset();
assert.equal(env.powered(t),true);
for(const key of ['machine','script_noteworthy','power_on']) {
    const bad={...t}; delete bad[key]; assert.equal(env.powered(bad),false);
}
env.self.model='off'; assert.equal(env.powered(t),false);
assert.equal(env.kind_for('specialty_fastreload'),'speed');
assert.equal(env.kind_for('specialty_doubletap2'),'doubletap');
assert.equal(env.kind_for('specialty_nomotionsensor'),'wisp');
assert.equal(env.kind_for('specialty_armorvest'),undefined);
function sequence(kind,on,changed) {
    reset(kind); return [...env.rest_pose(on,changed)].map(x=>x[0]);
}
assert.deepEqual(sequence('speed',true,true),['p9_fxanim_zm_gp_speed_cola_initiate','p9_fxanim_zm_gp_speed_cola_loop']);
assert.deepEqual(sequence('speed',true,false),['p9_fxanim_zm_gp_speed_cola_loop']);
assert.deepEqual(sequence('speed',false,true),['p9_fxanim_zm_gp_speed_cola_initiate_off']);
assert.deepEqual(sequence('wisp',false,true),[]);
for(const [kind,clips] of [
    ['doubletap',['tod_doubletap_intro','tod_doubletap_fire','tod_doubletap_outro','t10_fxanim_zm_machine_d_mod_idle']],
    ['wisp',['tod_wisp_activate','anim_68e0495f3599ef44']],
]) {
    const trigger=reset(kind); const co=env.purchase_sequence({id:0,player:true,alive:true},trigger);
    assert.equal(co.next().value[0],clips[0]); assert.equal(env.self.tod_perk_anim_busy,true);
    const rest=[]; let step=co.next();
    while(!step.done) {
        rest.push(step.value[0]);
        if(kind==='doubletap' && step.value[0]==='tod_doubletap_fire') {
            assert.equal(env.self.tod_perk_anim_firing,true,'firing is armed while the fire clip plays');
            assert.deepEqual(env.threads.map(x=>x[0]),['doubletap_note_probe','doubletap_volley'],'the volley is scheduled before the fire clip starts');
            assert.equal(env.threads[1][3],env.time,'the volley is timed from the frame the fire clip starts');
        }
        step=co.next();
    }
    assert.deepEqual(rest,clips.slice(1));
    assert.equal(env.self.tod_perk_anim_busy,false);
    assert(env.ends.has('tod_perk_anim_cancel'));
    if(kind==='doubletap') {
        assert.equal(env.self.tod_perk_anim_firing,false);
        assert(env.events.includes('tod_perk_anim_volley_over'),'the volley threads are released when the fire clip ends');
        assert.equal(env.threads.length,2,'nothing else is threaded by a purchase');
    }
}
t=reset(); const watcher=env.machine_watch(t); watcher.next();
assert.equal(env.threads.length,1); watcher.next(); assert.equal(env.threads.length,1);
env.self.tod_perk_anim_playing=true; env.pause_for_move(0.85);
assert.equal(env.stops,1); assert.equal(env.self.tod_perk_anim_moving,true);
watcher.next(); assert.equal(env.threads.length,2,'no rest pose during movement');
const resume=env.resume_after_move(0.85); assert.equal(resume.next().value,0.85);
env.self.origin=[100,200,300]; resume.next(); watcher.next();
assert.equal(env.self.tod_perk_anim_moving,false);
assert.equal(env.threads.at(-1)[0],'rest_pose'); assert.equal(env.threads.at(-1)[2],false,'no repeated power intro');
t.power_on=false; watcher.next(); assert.equal(env.threads.at(-1)[1],false);
env.self.tod_perk_anim_playing=true; env.retire();
assert.equal(env.stops,2); assert.equal(watcher.next().done,true);
assert(env.events.includes('tod_perk_anim_cancel')); assert(env.events.includes('tod_perk_anim_retired'));
assert(env.ends.has('tod_perk_anim_move_restart'));

// THE CLIP CONTRACT: a clip is over only when its done-notify says "end".
const play=body('play');
assert(play.includes('waittill( done, note )'),'play reads the note carried by the done-notify');
assert(play.includes('if ( note == "end" ) break;'),'only "end" finishes a clip');
const code=src.replace(/\/\/.*$/gm,'');   // comments may quote the old idiom; code may not use it
assert(!/waittill\( done \)/.test(code),'a bare waittill( done ) returns on the first script note');
assert(play.indexOf('if ( note == "end" ) break;')<play.indexOf('notify( "tod_perk_anim_clip_over" )'),'the watchdog is released after "end"');
assert(body('animation_timeout').includes('endOn( "tod_perk_anim_clip_over" )'),'the watchdog outlives note notifies');
assert(!body('animation_timeout').includes('endOn( done )'));

// THE SHOT TABLE: lockstep with the clip's authored notes in the GDT.
const gdt=fs.readFileSync(path.join(root,'source_data/tod_perk_machines.gdt'),'utf8');
const fireAt=gdt.indexOf('"tod_doubletap_fire" ( "xanim.gdf" )');
const fireBlock=gdt.slice(fireAt,gdt.indexOf('\n\t}',fireAt));
const authored=[];
for(const m of fireBlock.matchAll(/"customnote(\d+)action" "Self Notify"/g)) {
    const n=m[1];
    authored.push({frame:Number(fireBlock.match(new RegExp(`"customnote${n}frame" "(\\d+)"`))[1]),
        muzzle:fireBlock.match(new RegExp(`"customnote${n}actionparam2" "([^"]+)"`))[1]});
}
authored.sort((a,b)=>a.frame-b.frame);
const frames=env.volley_frames();
assert.equal(frames.length,16);
assert.deepEqual(frames,authored.map(a=>a.frame),'GSC shot frames match the clip notes');
assert.deepEqual(frames.map((f,i)=>env.volley_muzzle(i)),authored.map(a=>a.muzzle),'GSC muzzle parity matches the clip notes');
assert.deepEqual(frames.map((f,i)=>env.volley_pistol(i)),authored.map(a=>a.muzzle.replace('_muzzle','')));
for(let i=1;i<frames.length;i++) assert(frames[i]>frames[i-1],'frames ascend');

// THE VOLLEY: one trace per frame, timed from the clip's start, never early.
function ready() {
    const trigger=reset('doubletap');
    Object.assign(env.self,{tod_perk_anim_busy:true,tod_perk_anim_firing:true,tod_perk_anim_shots:0,tod_perk_anim_hits:0});
    return {trigger,buyer:{id:0,player:true,alive:true}};
}
let {trigger,buyer}=ready();
// This zombie stands BEHIND the machine, so the aimed pick never takes it and
// these cases exercise the level lane (a walker crossing the barrel line).
const zombie={id:100,alive:true,health:20000,classname:'actor',origin:[100,-300,0]};env.zombies=[zombie];
env.traceAt=() => ({fraction:0.01,entity:zombie,position:[100,325,40]});
const volley=env.doubletap_volley(buyer,trigger,1000);
const waits=[], firedAt=[];
let step=volley.next();
while(!step.done) {
    waits.push(step.value);
    env.time+=Math.round(step.value*1000);
    const shots=env.self.tod_perk_anim_shots;
    step=volley.next();
    if(env.self.tod_perk_anim_shots>shots) firedAt.push(env.time);
}
assert.equal(env.self.tod_perk_anim_shots,16,'sixteen scheduled shots');
assert.equal(env.traces.length,16);
for(const w of waits) assert(w>=0.05-1e-9,'never waits less than a server frame: '+w);
const due=frames.map(f=>1000+Math.trunc(f*1000/env.TOD_DOUBLE_TAP_FPS));
assert.equal(firedAt.length,16,'one shot per resume, none doubled up');
for(let i=0;i<16;i++) assert(firedAt[i]>=due[i] && firedAt[i]-due[i]<=50,'shot '+i+' within one frame of frame '+frames[i]);
for(let i=1;i<16;i++) assert(firedAt[i]>firedAt[i-1],'shots fire in order');
assert.deepEqual(env.tags.filter(t=>t.endsWith('_muzzle')),frames.map((f,i)=>env.volley_muzzle(i)),'left, right, left ... from the left pistol');
assert.equal(env.self.tod_perk_anim_hits,16);
assert.equal(env.damage.length,16);
assert(env.logs.some(l=>l.includes('VOLLEY_START')));
assert.equal(env.logs.filter(l=>l.startsWith('SHOT ')).length,16,'one SHOT record per trace (the mock logs the bare message)');
assert(env.logs.some(l=>l.includes('hp=20000->10000')),'the shot log records the victim health before and after');
const volleyBody=body('doubletap_volley');
for(const event of ['entityshutdown','tod_perk_anim_cancel','tod_perk_anim_volley_over','end_game']) assert(volleyBody.includes('"'+event+'"'));
assert(!volleyBody.includes('tod_doubletap_loop_done'),'the volley must not die on the note-driven done-notify');
assert(!volleyBody.includes('waittill'),'shots are scheduled, never note-driven');
const probe=body('doubletap_note_probe');
assert(probe.includes('waittill( "tod_doubletap_shot"') && !probe.includes('doubletap_shot('),'the probe only records');
assert(!src.includes('level waittill'),'events stay local to the firing machine');

// THE SHOT: owner attribution, wall/friendly filtering, levelled aim, retry
// out of a start-solid, and the moving/power/menu lifecycle.
({trigger,buyer}=ready());
env.zombies=[zombie]; zombie.health=20000;
env.traceAt=() => ({fraction:0.01,entity:zombie,position:[100,325,40]});
env.doubletap_shot(buyer,trigger,0);
assert.equal(env.damage.length,1);assert.equal(env.self.tod_perk_anim_hits,1);
assert(env.logs.some(l=>l.startsWith('SHOT ') && l.includes('stage=level') && l.includes('candidates=0') && l.includes('struck=actor') && l.includes('hp=20000->10000')),'a walker crossing the barrel line is hit on the level lane');
assert.equal(env.damage[0].args[0],10000);
assert.equal(env.damage[0].args[2],buyer,'purchase owner receives credit');
assert.equal(env.damage[0].args[3],env.self,'machine is inflictor');
assert.equal(env.damage[0].args.at(-1),'none','no held-weapon damage/procs');
assert.equal(zombie.tod_perk_machine_hit,undefined,'mark cleared synchronously');
assert.deepEqual(env.tags,['j_pistol_le_muzzle','j_pistol_le']);
assert.deepEqual(Array.from(env.traces[0].end),[100,12700,40],'rotated barrel ray begins at current machine, not world origin');
assert.equal(env.traces[0].characters,true);assert.equal(env.traces[0].ignored,env.self);
({trigger,buyer}=ready()); env.aim=[0,0.8,0.6]; env.zombies=[zombie];
env.doubletap_shot(buyer,trigger,1);
assert.deepEqual(env.tags,['j_pistol_ri_muzzle','j_pistol_ri'],'odd shots come from the right pistol');
assert.deepEqual(Array.from(env.traces[0].end).map(v=>Math.round(v)),[100,12700,40],'a pitched barrel is levelled at muzzle height');
({trigger,buyer}=ready()); env.aim=[0,0,1];
env.doubletap_shot(buyer,trigger,0);
assert.deepEqual(Array.from(env.traces[0].end),[100,12700,40],'a vertical barrel falls back to the machine facing');
({trigger,buyer}=ready()); trigger.clip={id:77}; env.zombies=[zombie]; zombie.health=20000;
env.traceAt=start => start[1]===200 ? {fraction:0,position:start,entity:trigger.clip} : {fraction:0.02,entity:zombie,position:[100,450,40]};
env.doubletap_shot(buyer,trigger,0);
assert.equal(env.traces.length,2,'a start-solid trace is retried once');
assert.deepEqual(Array.from(env.traces[1].start),[100,200+env.TOD_DOUBLE_TAP_RETRY_STEP,40],'the retry begins down the barrel');
assert.equal(env.traces[1].ignored,trigger.clip,'the retry ignores the stock perk clip');
assert.equal(env.damage.length,1,'the retried shot still lands');
assert(env.logs.some(l=>l.includes('stage=retry')));
({trigger,buyer}=ready()); env.zombies=[zombie];
env.traceAt=start => ({fraction:0,position:start});
env.doubletap_shot(buyer,trigger,0);
assert.equal(env.traces[1].ignored,env.self,'with no clip the retry still ignores the machine');
assert.equal(env.damage.length,0);
({trigger,buyer}=ready()); env.zombies=[zombie]; zombie.alive=true;
env.traceAt=() => ({fraction:0.02,position:[100,450,40]}); // Wall occludes farther zombies.
env.doubletap_shot(buyer,trigger,1);
env.traceAt=() => ({fraction:0.02,position:[100,450,40],entity:{alive:true,player:true}});env.doubletap_shot(buyer,trigger,0);
env.traceAt=() => ({fraction:0.02,position:[100,450,40],entity:{alive:true,companion:true}});env.doubletap_shot(buyer,trigger,1);
zombie.alive=false;env.traceAt=() => ({fraction:0.02,position:[100,450,40],entity:zombie});env.doubletap_shot(buyer,trigger,0);
assert.equal(env.damage.length,0,'walls, players, friendly actors and dead actors never damaged');
assert.equal(env.self.tod_perk_anim_shots,4,'blocked shots still count as fired');
zombie.alive=true;

// THE AIMED SHOT (v19.48): the first real volley fired sixteen level traces and
// hit nothing (the user's log: hit=0 x16). A shot now picks the nearest live
// zombie in the barrel's front fan, on this deck, with a clear world-only sight
// line to its chest; the level trace is only the fallback for an empty room.
// Muzzle [100,200,40], barrel heading north [0,1,0] (the mocks above).
function zed(id,origin,extra={}) { return {id,alive:true,health:20000,classname:'actor',origin,...extra}; }
function aimedEnv(zombies,los=() => 1) {
    const r=ready(); env.zombies=zombies;
    env.traceAt=(start,end,characters) => characters ? {fraction:1,position:end} : {fraction:los(end),position:end};
    return r;
}
const near=zed(101,[130,450,0]), far=zed(102,[100,800,0]), behind=zed(103,[100,-200,0]), dead=zed(104,[100,300,0],{alive:false});
({trigger,buyer}=aimedEnv([far,dead,near,behind]));
env.doubletap_shot(buyer,trigger,0);
assert.equal(env.damage.length,1);
assert.equal(env.damage[0].victim,near,'the nearest live zombie in front takes the shot (dead and behind are skipped)');
assert.equal(env.damage[0].args[0],10000);assert.equal(env.damage[0].args[2],buyer);assert.equal(env.damage[0].args[3],env.self);assert.equal(env.damage[0].args.at(-1),'none');
assert.equal(near.tod_perk_machine_hit,undefined,'mark cleared synchronously on the aimed lane too');
assert.equal(env.traces.length,1);
assert.equal(env.traces[0].characters,false,'the sight line is world-only: a player in front never shields the zombie');
assert.equal(env.traces[0].ignored,env.self);
assert.deepEqual(Array.from(env.traces[0].end),[130,450,env.TOD_DOUBLE_TAP_AIM_Z],'aimed at chest height above the feet');
const sight=env.VectorNormalize([30,250,0]);
assert.deepEqual(Array.from(env.traces[0].start).map(v=>Math.round(v*1000)/1000),[100+sight[0]*env.TOD_DOUBLE_TAP_RETRY_STEP,200+sight[1]*env.TOD_DOUBLE_TAP_RETRY_STEP,40].map(v=>Math.round(v*1000)/1000),'the sight line starts clear of the machine footprint');
assert.equal(env.self.tod_perk_anim_hits,1);
assert(env.logs.some(l=>l.startsWith('SHOT ') && l.includes('stage=aimed') && l.includes('candidates=1') && l.includes('struck=actor') && l.includes('dist=254') && l.includes('hp=20000->10000')),'the SHOT record names stage, candidates, 3D distance (sqrt(30^2+250^2+40^2)=254.9), classname and hp');
({trigger,buyer}=aimedEnv([near])); trigger.clip={id:77};
env.doubletap_shot(buyer,trigger,1);
assert.equal(env.traces[0].ignored,trigger.clip,'the sight line ignores the stock perk clip when the trigger has one');
assert.equal(env.damage.length,1);
// Cover: the nearest is behind a wall, so the next-nearest takes the shot.
({trigger,buyer}=aimedEnv([far,near],end => end[1]===450 ? 0.4 : 1));
env.doubletap_shot(buyer,trigger,0);
assert.equal(env.damage.length,1);assert.equal(env.damage[0].victim,far,'a covered zombie is passed over for the next-nearest');
assert.equal(env.traces.length,2);
assert(env.logs.some(l=>l.startsWith('SHOT_COVER') && l.includes('candidate=101') && l.includes('fraction=0.4')));
assert(env.logs.some(l=>l.startsWith('SHOT ') && l.includes('stage=aimed') && l.includes('candidates=2')));
// Everybody covered: AIM_TRIES sight lines, then the level fallback (which can still hit a walker in the line).
const third=zed(105,[100,1200,0]), fourth=zed(106,[100,1500,0]);
({trigger,buyer}=aimedEnv([near,far,third,fourth],() => 0.2));
env.doubletap_shot(buyer,trigger,0);
assert.equal(env.traces.length,env.TOD_DOUBLE_TAP_AIM_TRIES+1,'AIM_TRIES sight lines, then one level trace');
assert.equal(env.traces.at(-1).characters,true);assert.deepEqual(Array.from(env.traces.at(-1).end),[100,12700,40]);
assert.equal(env.damage.length,0);
assert(env.logs.some(l=>l.startsWith('SHOT ') && l.includes('stage=level') && l.includes('candidates='+env.TOD_DOUBLE_TAP_AIM_TRIES) && l.includes('struck=world')));
assert.equal(env.logs.filter(l=>l.startsWith('SHOT_COVER')).length,env.TOD_DOUBLE_TAP_AIM_TRIES);
// The fan, the deck and the range: outside any of them means nobody is in front.
const beside=zed(107,[400,220,0]);                                   // 86 degrees off the barrel
const below=zed(108,[100,450,-(env.TOD_DOUBLE_TAP_AIM_DZ+50)]);       // the flight below
const beyond=zed(109,[100,200+env.TOD_DOUBLE_TAP_RANGE+10,0]);
({trigger,buyer}=aimedEnv([beside,below,beyond,behind]));
env.doubletap_shot(buyer,trigger,0);
assert.equal(env.traces.length,1);assert.equal(env.traces[0].characters,true,'nobody in front: the level trace');
assert.equal(env.damage.length,0);
const inFan=zed(110,[100+300*Math.sin(Math.PI/3),200+300*Math.cos(Math.PI/3),0]);          // 60 degrees off
const outFan=zed(111,[100+290*Math.sin(Math.PI*80/180),200+290*Math.cos(Math.PI*80/180),0]); // 80 degrees off, nearer
({trigger,buyer}=aimedEnv([outFan,inFan]));
env.doubletap_shot(buyer,trigger,0);
assert.equal(env.damage.length,1);assert.equal(env.damage[0].victim,inFan,'60 degrees off the barrel is in the fan, 80 is not');
// A whole volley at one zombie standing in front: sixteen aimed hits.
({trigger,buyer}=aimedEnv([zed(120,[100,500,0],{health:200000})]));
const aimedVolley=env.doubletap_volley(buyer,trigger,1000);
for(let s=aimedVolley.next();!s.done;s=aimedVolley.next()) env.time+=Math.round(s.value*1000);
assert.equal(env.self.tod_perk_anim_shots,16);assert.equal(env.self.tod_perk_anim_hits,16);
assert.equal(env.zombies[0].health,200000-16*env.TOD_DOUBLE_TAP_DAMAGE,'every scheduled shot lands on the zombie in front');
assert(env.traces.every(t=>t.characters===false));
const targetBody=body('volley_target');
assert(targetBody.includes('BulletTrace( from, chest, false, blocker )'),'the sight line is world-only');
assert(!targetBody.includes('wait'),'target selection never yields');
for (const [label,mutate] of [
    ['idle',()=>env.self.tod_perk_anim_firing=false],
    ['cancelled',()=>env.self.tod_perk_anim_busy=false],
    ['moving',()=>env.self.tod_perk_anim_moving=true],
    ['retired',()=>env.self.tod_perk_anim_retired=true],
    ['off',()=>trigger.power_on=false], ['off model',()=>env.self.model='off'],
    ['replaced',()=>trigger.machine={model:'on'}],
    ['paused',()=>env.level.tod_upgrade_pause=true],
    ['dead buyer',()=>buyer.alive=false], ['non-player',()=>buyer.player=false],
    ['disconnected',()=>buyer=undefined], ['deleted trigger',()=>trigger=undefined],
]) {
    ({trigger,buyer}=ready());mutate();env.doubletap_shot(buyer,trigger,0);
    assert.equal(env.traces.length,0,label);assert.equal(env.damage.length,0,label);
    assert.equal(env.self.tod_perk_anim_shots,0,label+' is not counted');
    assert(env.logs.some(line=>line.includes('SHOT_SKIP')),label+' logs reason');
}
({trigger,buyer}=ready());const pauseWatcher=env.machine_watch(trigger);pauseWatcher.next();
env.self.tod_perk_anim_busy=true;env.self.tod_perk_anim_firing=true;env.level.tod_upgrade_pause=true;
pauseWatcher.next();assert.equal(env.self.tod_perk_anim_firing,false);assert.equal(env.self.tod_perk_anim_busy,false);
assert(env.logs.some(line=>line.includes('reason=world_pause')));
const purchase=body('purchase_sequence');
assert(purchase.indexOf('startThread("doubletap_volley"')<purchase.indexOf('yield [ "tod_doubletap_fire"'),'volley scheduled before the first frame');
assert(purchase.indexOf('yield [ "tod_doubletap_fire"')<purchase.indexOf('notify( "tod_perk_anim_volley_over" )'));
const damageSource=fs.readFileSync(path.join(root,'scripts/zm/zm_tower_of_doom/_tod_upgrades.gsc'),'utf8');
const damageGate=damageSource.indexOf('if ( IS_TRUE( self.tod_perk_machine_hit ) )');
assert(damageGate>0);assert(damageSource.slice(damageGate,damageGate+210).includes('sprinter_armor_frac'));
const scatter=fs.readFileSync(path.join(root,'scripts/zm/zm_tower_of_doom/_tod_perk_scatter.gsc'),'utf8');
const move=scatter.slice(scatter.indexOf('function move_machine('));
assert(move.indexOf('[[ level.tod_perk_anim_move ]]')<move.indexOf('old_org ='));
const retired=scatter.slice(scatter.indexOf('function retire_all('),scatter.indexOf('function move_machine('));
assert(retired.indexOf('[[ level.tod_perk_anim_retire ]]')<retired.indexOf('m.origin = park'));
const zone=fs.readFileSync(path.join(root,'zone_source/zm_tower_of_doom.zone'),'utf8');
const tree=fs.readFileSync(path.join(root,'animtrees/tod_perk_machines.atr'),'utf8');
const names=[...src.matchAll(/#precache\( "xanim", "([^"]+)"/g)].map(m=>m[1]);
assert.equal(names.length,9);
for(const name of names) { assert(zone.includes('xanim,'+name)); assert(tree.includes(name)); }
assert(src.includes('"perk_purchased", specialty'));
assert(!/MagicBullet|MagicMissile|machineAttacks|doubletap_attacks/.test(src));
// v19.48b: the user's second log had the engine throw "parameter 2 does not exist" on
// GetAIArray( "axis" ) and "Object must be an array" on the foreach over its undefined
// result, on every shot - a sighted zombie read hit=0 sixteen times. Team form only.
assert(!/GetAIArray\(/.test(code),'GetAIArray( "axis" ) throws in the engine; the team list is GetAITeamArray( team )');
assert(body('enemy_actor').includes('GetAITeamArray(team)'),'the enemy check reads the same team list the aimed pick does');
console.log('Perk animations pass: purchase/power/movement/pause/retirement, "end"-only clip completion, 16 scheduled shots on the clip frames (GDT lockstep), aimed shots (nearest in the front fan, world-only sight line, cover skip, fan/deck/range limits, sixteen aimed hits), level fallback + start-solid retry, ownership, blocked/friendly hits, cancellation, nine clips. Native rendering remains for user playtest.');
