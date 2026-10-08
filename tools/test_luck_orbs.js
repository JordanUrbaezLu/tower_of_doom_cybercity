// Execute shipping GSC queue/movement/reward functions with a native-mover
// simulation. Tests prove accounting/lifetime logic, not native FX visibility.
const fs = require('fs'), path = require('path'), vm = require('vm');
const assert = require('assert/strict');
const root = path.resolve(__dirname, '..');
const read = f => fs.readFileSync(path.join(root, f), 'utf8').replace(/\r\n/g, '\n');
const dir = 'scripts/zm/zm_tower_of_doom/';
let orb = read(dir + '_tod_luck_orbs.gsc'), luck = read(dir + '_tod_luck.gsc');
// Optional negative controls alter the loaded source in memory, never the repo.
const fault=process.argv.find(a=>a.startsWith('--fault='))?.slice(8);
if(fault==='early') orb=orb.replace('job.visible_age >= TOD_LUCK_ORB_MIN_LIFE && dist <= reach','true');
if(fault==='pause') orb=orb.replace('if ( reason != "" )','if ( false )');
if(fault==='drop') orb=orb.replace('job.amount += amount;','job.amount += 0;');
if(fault==='duplicate') orb=orb.replace('if ( !advance( slot, job ) )','if ( advance( slot, job ) || true )');
if(fault==='audio_cleanup') orb=orb.replace('job.host StopLoopSound();','');
if(fault==='audio_restart') orb=orb.replace('if ( !job.release_sound_done )','if ( true )');
if(fault==='zombie_orb') luck=luck.replace('isdefined( source ) && ( source == "zombie" || source == "headshot" )','false');
function body(src, name) {
    const match = new RegExp('function ' + name + '\\(\\s*([^)]*)\\)').exec(src);
    assert(match, name);
    const start = src.indexOf('{', match.index);
    let end = start + 1, depth = 1;
    while (depth) { if (src[end] === '{') depth++; if (src[end] === '}') depth--; end++; }
    return {params: match[1], code: src.slice(start + 1, end - 1).replace(/\/\/[^\n]*/g, '')};
}
const env = {level: {}, now: 0, hosts: [], logs: [], effects: [], paid: [], killerDings: []};
Object.assign(env, {
    isdefined: x => x !== undefined && x !== null && !x.deleted,
    isplayer: p => !!p?.player && !p.deleted,
    IsAlive: p => p.alive, IS_TRUE: x => x === true || x === 1,
    SpawnStruct: () => ({}), GetTime: () => env.now, int: Math.trunc,
    addVec: (a,b) => a.map((v,i) => v+b[i]), subVec: (a,b) => a.map((v,i) => v-b[i]),
    Distance: (a,b) => Math.hypot(...a.map((v,i) => v-b[i])), Length: a => Math.hypot(...a),
    VectorScale: (a,s) => a.map(v=>v*s),
    VectorNormalize: a => a.map(v=>v/Math.hypot(...a)),
    log: s => env.logs.push(s), get_level: p => p.luckLevel || 0,
    elite_kill: (p,kind) => env.killerDings.push({p,kind}),
    Spawn: (_,org) => {
        if (env.failSpawn) return undefined;
        const h = {origin: [...org], SetModel(m){this.model=m;}, NotSolid(){this.solid=false;},
            MoveTo(to,seconds){this.move={from:[...this.origin],to:[...to],start:env.now,end:env.now+seconds*1000};},
            PlaySound(alias){env.sounds.push({kind:'release',alias,h:this,at:env.now});},
            PlayLoopSound(alias){assert(!this.loop,'loop starts once per host');this.loop=alias;env.sounds.push({kind:'loop',alias,h:this,at:env.now});},
            StopLoopSound(){this.loop=undefined;env.sounds.push({kind:'stop',h:this,at:env.now});},
            Delete(){assert(!this.loop,'travel loop explicitly stopped before host deletion');this.deleted=true;}};
        env.hosts.push(h); return h;
    },
    PlayFXOnTag: (fx,h,tag) => env.effects.push({fx,h,tag}),
    set_bar: (p,v) => { p.tod_luck_bar = Math.max(0,Math.min(150,v)); env.paid.push({p,v:p.tod_luck_bar}); }
});
for (const src of [orb,luck]) for (const m of src.matchAll(/^#define\s+(\w+)\s+([\d.]+)/gm)) env[m[1]] = Number(m[2]);
vm.createContext(env);
function load(src,name,locals=[]) {
    let {params,code} = body(src,name);
    code = code.replace(/foreach\s*\(\s*(\w+) in ([^)]+)\)/g, 'for (const $1 of $2)')
        .replace(/\[\[ level\.tod_luck_orb_receive \]\]/g, 'level.tod_luck_orb_receive')
        .replace(/\b(?:tod_luck_orbs|tod_upgrades|tod_killconfirm)::/g, '')
        .replace(/\b([\w.]+) (GetEntityNumber|GetEye|GetVelocity|Delete|SetModel|NotSolid|MoveTo|PlaySound|PlayLoopSound|StopLoopSound|PlayLocalSound)\(/g,'$1.$2(')
        .replace(/\.size/g, '.length')
        .replace(/\( 0, 0, (32|40|12|-18) \)/g, '[0,0,$1]')
        .replace(/(player.origin|job.org|slot.player.GetEye\(\)) \+ (\[0,0,-?\d+\])/g,'addVec($1,$2)')
        .replace('org += [0,0,40]', 'org = addVec(org,[0,0,40])')
        .replace('target - job.host.origin', 'subVec(target,job.host.origin)')
        .replace('job.host.origin + VectorScale( dir, step )', 'addVec(job.host.origin, VectorScale(dir,step))');
    vm.runInContext(`function ${name}(${params}) { ${locals.length ? 'let '+locals.join(',')+';' : ''} ${code} }`,env);
}
for (const [name,locals] of [
    ['slot_for',['index','slot']], ['emit',['slot','job']], ['hold_reason',[]],
    ['park',[]], ['start_host',[]], ['start_audio',['released']], ['arrival_audio',[]],
    ['advance',['target','dist','reach','before','speed','step','dir','sound_played']],
    ['tick_slot',['reason','next','pending']], ['clear_slot',['amount']], ['on_disconnect',['index','slot']]
]) load(orb,name,locals);
for (const [name,locals] of [
    ['bar_of',[]],['add',['lvl','gain','before']],['orb_received',[]],['dupe_award',['n']],
    ['on_zombie_kill',['amt','source']],['boss_kill',[]],['door_buy',[]],['drain',[]],['spend',[]],['segment_alias',[]]
]) load(luck,name,locals);
function reset() {
    env.level = {_effect:{tod_luck_soul:'tod/fx_luck_soul'},tod_luck_orb_slots:[],tod_luck_orb_seq:0,tod_luck_orb_receive:env.orb_received,tod_luck_per_kill:2};
    env.now=0; env.hosts=[]; env.logs=[]; env.effects=[]; env.paid=[]; env.killerDings=[]; env.failSpawn=false;
    env.sounds=[];
}
function player(index=0) {
    return {player:true,alive:true,index,origin:[0,0,0],tod_luck_bar:0,luckLevel:0,
        PlayLocalSound(alias){env.sounds.push({kind:'arrival',alias,p:this,at:env.now,bar:this.tod_luck_bar});},
        GetEntityNumber(){return this.index;},GetEye(){return env.addVec(this.origin,[0,0,60]);},
        GetVelocity(){return this.velocity||[0,0,0];}};
}
function ticks(n=1,move) {
    for(let i=0;i<n;i++) {
        env.now+=50;
        if(move)move();
        for(const h of env.hosts) if(!h.deleted&&h.move) {
            const m=h.move, f=Math.min(1,(env.now-m.start)/(m.end-m.start));
            h.origin=m.from.map((v,i)=>v+(m.to[i]-v)*f);
        }
        for(const slot of env.level.tod_luck_orb_slots) env.tick_slot(slot);
        assert(env.hosts.filter(h=>!h.deleted).length<=24,'hard mover cap');
    }
}
function finish(max=1000) {
    for(let i=0;i<max;i++) {
        if(env.level.tod_luck_orb_slots.every(s=>!s||!s.active.length&&!s.pending.length)) return;
        ticks();
    }
    assert.fail('undelivered queue');
}

reset(); const p=player(), teammate=player(1);
env.door_buy(p,[500,0,42]);
assert.equal(p.tod_luck_bar,0,'purchase cannot pay');
ticks(); assert.equal(p.tod_luck_bar,0,'spawn cannot pay');
assert.equal(env.sounds.length,0,'wait for settled visible host before audio');
assert.deepEqual([...env.hosts[0].origin],[500,0,42],'source copied');
ticks(3); assert.equal(p.tod_luck_bar,0,'lift cannot pay');
finish(); assert.equal(p.tod_luck_bar,10); assert.equal(env.paid.length,1); assert.equal(teammate.tod_luck_bar,0);
ticks(30); assert.equal(env.paid.length,1,'no duplicate payment after cleanup');
assert.equal(env.hosts.filter(h=>!h.deleted).length,0);
assert.equal(env.effects.length,1,'FX attached to the first settled host');
assert.equal(env.effects[0].fx,'tod/fx_luck_soul','FX comes through registered effect handle');
assert.equal(env.effects[0].h,env.hosts[0],'FX follows the reward mover');
assert(env.logs.some(s=>s.startsWith('FX_ATTACH id=1 ')),'FX attachment logged');
for(const kind of ['release','loop','stop','arrival']) assert.equal(env.sounds.filter(s=>s.kind===kind).length,1,kind+' once');
assert.equal(env.sounds.find(s=>s.kind==='arrival').p,p,'arrival is recipient-local');
assert.equal(env.sounds.find(s=>s.kind==='arrival').bar,10,'arrival sound follows credit');
assert.equal(env.segment_alias(10),'tod_luck_soul_full','pack completion replaces tenth pip');
for(let seg=1;seg<10;seg++)assert.equal(env.segment_alias(seg),'tod_luck_pip0'+seg,'lower pips retained');

for(const [kind,amount] of [['protector',4],['panzer',20],['reaver',6],['hellhound',3],['sprinter',4]]) {
    reset(); const a=player(0), b=player(1); a.luckLevel=5;
    env.boss_kill(a,kind,[300,10,0]);
    assert.equal(a.tod_luck_bar,0); assert.equal(b.tod_luck_bar,0);
    assert.equal(env.killerDings.length,1,'kill confirm remains at death');
    a.luckLevel=0; finish(); assert.equal(a.tod_luck_bar,amount*1.5,'gain rate latched once');
    assert.equal(b.tod_luck_bar,0,'Panzer and elites remain killer-only');
}
for(const [kind,amount] of [['pap',20],['perk',10]]) {
    reset(); const a=player(); env.dupe_award(a,kind,[60,0,30]);
    assert.equal(a.tod_luck_bar,0); finish(); assert.equal(a.tod_luck_bar,amount);
}
for(const head of [false,true]) {
    reset(); const a=player(), b=player(1); a.luckLevel=5;
    env.on_zombie_kill(a,head,[100,0,32]);
    assert.equal(a.tod_luck_bar,head?4.5:3,'ordinary kill pays immediately with existing headshot/gain bonuses');
    assert.equal(b.tod_luck_bar,0,'ordinary kill remains killer-only');
    assert.equal(env.level.tod_luck_orb_seq,0,'ordinary kill creates no queued orb');
    ticks(40);
    assert.equal(env.hosts.length,0,'ordinary kill creates no mover');
    assert.equal(env.effects.length,0,'ordinary kill creates no FX');
    assert.equal(env.sounds.length,0,'ordinary kill creates no soul audio');
    assert.equal(env.paid.length,1,'ordinary kill is not paid twice');
    assert(env.logs.some(s=>s.startsWith('DIRECT p=0 source='+(head?'headshot':'zombie'))),'direct credit logged');
}
// Sprinters also use the normal zombie-death callback: only the elite bonus flies.
reset(); const sprinterKiller=player();
env.on_zombie_kill(sprinterKiller,true,[100,0,32]);
env.boss_kill(sprinterKiller,'sprinter',[100,0,0]);
assert.equal(sprinterKiller.tod_luck_bar,3,'normal component is immediate');
assert.equal(env.level.tod_luck_orb_seq,1,'only elite bonus queues a soul');
finish(); assert.equal(sprinterKiller.tod_luck_bar,7,'elite bonus waits for contact');
reset(); const fullKill=player(); fullKill.tod_luck_bar=149;
env.on_zombie_kill(fullKill,true,[100,0,32]);
assert.equal(fullKill.tod_luck_bar,150,'direct kills retain the overcharge cap');
reset(); const reviver=player(); env.add(reviver,15,[40,0,32],'revive');
finish(); assert.equal(reviver.tod_luck_bar,15);

// All owners can be moving, teleporting, or sharing the same source location.
reset(); const party=[0,1,2,3].map(player);
for(const a of party)for(let i=0;i<20;i++) env.emit(a,1,[300,0,42],'hellhound');
ticks(8); assert.equal(env.hosts.filter(h=>!h.deleted).length,24);
party[0].origin=[10240,0,20000];
ticks(80,()=>{party[1].origin[0]+=12;}); finish();
for(const a of party) assert.equal(a.tod_luck_bar,20,'owned rewards after movement/teleport');
for(const a of party) {
    const arrivals=env.sounds.filter(s=>s.kind==='arrival'&&s.p===a);
    assert(arrivals.length>0,'each owner hears collection');
    for(let i=1;i<arrivals.length;i++) assert(arrivals[i].at-arrivals[i-1].at>=150,'arrival burst throttle');
}

// Card resets cannot consume undelivered value, including a co-op altar menu.
for(const mode of ['world','menu','solo','dead']) {
    reset(); const a=player(); a.tod_luck_bar=70; env.door_buy(a,[500,0,42]); ticks(4);
    if(mode==='world')env.level.tod_upgrade_pause=true;
    if(mode==='menu')a.tod_menu_frozen=true;
    if(mode==='solo')a.tod_solo_upg_active=true;
    if(mode==='dead')a.alive=false;
    ticks(80); assert.equal(a.tod_luck_bar,70,mode+' cannot collect');
    assert.equal(env.hosts.filter(h=>!h.deleted).length,0,mode+' parks FX');
    a.tod_luck_bar=0; a.origin=[1000,200,500];
    env.level.tod_upgrade_pause=false; a.tod_menu_frozen=false; a.tod_solo_upg_active=false; a.alive=true;
    finish(); assert.equal(a.tod_luck_bar,10,mode+' retained for next bar');
    assert.equal(env.sounds.filter(s=>s.kind==='release').length,1,mode+' does not replay release');
    assert.equal(env.sounds.filter(s=>s.kind==='loop').length,2,mode+' travel resumes');
    assert.equal(env.sounds.filter(s=>s.kind==='stop').length,2,mode+' every loop stops');
}

reset(); const down=player(); down.downed=true; down.tod_luck_bar=50;
env.door_buy(down,[0,0,42]); env.drain(down,15);
assert.equal(down.tod_luck_bar,35,'down penalty stays immediate');
finish(); assert.equal(down.tod_luck_bar,45,'downed owner can receive an earned reward');

reset(); const capped=player(); capped.tod_luck_bar=149; env.door_buy(capped,[100,0,42]);
finish(); assert.equal(capped.tod_luck_bar,150,'existing overcharge ceiling');
reset(); const wasFull=player(); wasFull.tod_luck_bar=150; env.door_buy(wasFull,[500,0,42]);
env.drain(wasFull,15); finish(); assert.equal(wasFull.tod_luck_bar,145,'full at source is not silently discarded');

reset(); const failed=player(); env.failSpawn=true; env.door_buy(failed,[100,0,42]);
ticks(100); assert.equal(failed.tod_luck_bar,0,'no timeout or invisible fallback credit');
assert.equal(env.sounds.length,0,'allocation failure is silent');
assert(env.logs.filter(s=>s.startsWith('RETRY')).length<=5,'bounded failure diagnostics');
env.failSpawn=false; finish(); assert.equal(failed.tod_luck_bar,10,'allocation retry retains amount');

reset(); const slow=player(); env.emit(slow,4,[100,0,42],'protector'); ticks();
const stuck=env.hosts[0]; stuck.MoveTo=()=>{};
ticks(400); assert.equal(slow.tod_luck_bar,0,'stalled mover cannot time out into a grant');
assert.equal(env.logs.filter(s=>s.startsWith('SLOW')).length,1);
stuck.deleted=true; finish(); assert.equal(slow.tod_luck_bar,4,'lost host is re-created');

reset(); const leaving=player(); env.door_buy(leaving,[500,0,42]); ticks(4);
env.self=leaving; env.on_disconnect(); ticks(5);
assert.equal(env.hosts.filter(h=>!h.deleted).length,0); assert.equal(leaving.tod_luck_bar,0);
const replacement=player(); env.emit(replacement,3,[30,0,42],'hellhound'); finish();
assert.equal(replacement.tod_luck_bar,3,'reused player slot cannot inherit old rewards');

reset(); const burst=player(); env.level.tod_upgrade_pause=true;
for(let i=0;i<500;i++) env.emit(burst,.01,[i,0,42],'hellhound');
assert.equal(env.slot_for(burst).pending.length,64,'bounded paused backlog');
env.level.tod_upgrade_pause=false; finish();
assert(Math.abs(burst.tod_luck_bar-5)<1e-9,'overflow preserves every fractional reward');

reset(); const end=player(); env.door_buy(end,[100,0,42]); ticks(4);
env.clear_slot(env.slot_for(end),'end_game');
assert.equal(env.hosts.filter(h=>!h.deleted).length,0); assert.equal(end.tod_luck_bar,0);
env.emit(undefined,10,[0,0,0],'door'); env.emit(end,0,[0,0,0],'door');
assert.equal(env.level.tod_luck_orb_seq,1,'invalid/zero grants do not create jobs');

// 2026-09-22 (bug review F20): a soul must land on a SPRINTING player. With a
// fixed 12-unit reach the mover trailed one tick of player movement (15 u at
// 300 u/s) forever; the reach now grows by one tick of the player's velocity.
reset(); const runner=player(); runner.velocity=[300,0,0];
env.door_buy(runner,[-40,0,42]);
let paidAt=-1;
for(let i=0;i<400&&paidAt<0;i++){ ticks(1,()=>{runner.origin=env.addVec(runner.origin,[15,0,0]);}); if(runner.tod_luck_bar>0)paidAt=i; }
assert(paidAt>=0,'a soul reaches a player sprinting in a straight line');
assert.equal(env.hosts.filter(h=>!h.deleted).length,0,'sprint arrival cleans its host');

// Wiring checks cover the live call sites that a mover simulation cannot.
assert(body(luck,'revive_watcher').code.includes('add( reviver, TOD_LUCK_REVIVE, self.origin + ( 0, 0, 32 ), "revive" )'));
assert(body(luck,'on_zombie_death').code.includes('on_zombie_kill( attacker, b_head, self.origin + ( 0, 0, 32 ) )'));
assert(read(dir+'_tod_doors.gsc').includes('tod_luck::door_buy( player, d.tod_org )'));
for(const [file,fn,kind] of [['_tod_bosses.gsc','death_watch','protector'],['_tod_reaver.gsc','death_watch','reaver'],['_tod_sprinter.gsc','death_watch','sprinter'],['_tod_hellhounds.gsc','hound_death_watch','hellhound']]) {
    const b=body(read(dir+file),fn).code;
    assert(b.includes('org = source.org;'));
    assert(b.indexOf('track_source( self )')<b.indexOf('waittill( "death"'));
    assert(b.includes(`tod_luck::boss_kill( attacker, "${kind}", org )`));
}
assert(read(dir+'_tod_bosses.gsc').includes('tod_luck::boss_kill( killer, "panzer", org )'));
for(const kind of ['pap','perk']) assert(read(dir+'_tod_powerups.gsc').includes(`[[ level.tod_luck_dupe_fn ]]( player, "${kind}", self.origin )`));
assert.equal((orb.match(/\[\[ level\.tod_luck_orb_receive \]\]/g)||[]).length,1,'one arrival writer');
const zone=read('zone_source/zm_tower_of_doom.zone');
assert(zone.includes('scriptparsetree,scripts/zm/zm_tower_of_doom/_tod_luck_orbs.gsc'));
assert(zone.includes('fx,tod/fx_luck_soul'));
assert(body(orb,'init').code.includes('level._effect[ "tod_luck_soul" ] = "tod/fx_luck_soul"'),'map-standard server FX handle');
assert(body(orb,'advance').code.includes('PlayFXOnTag( level._effect[ "tod_luck_soul" ], job.host, "tag_origin" )'),'moving host plays registered effect');
assert(orb.includes('/# PrintLn( line ); #/'),'proven developer logger');
console.log('Luck orbs passed: ordinary/headshot kills pay immediately without souls; elite/Panzer and non-kill souls pay on arrival exactly once; four owners, movement/teleports, pauses/death/respawn, cap/retries/cleanup, bounded bursts; pack audio starts/stops, owner-local arrival after credit, overlap limits, no repeated release and full-bar cue. Native appearance/audio pending.');
