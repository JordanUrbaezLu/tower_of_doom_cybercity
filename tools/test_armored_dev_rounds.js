// Exercise the actual round watcher/director with mocked AI lists and waits.
'use strict';
const fs=require('fs'), path=require('path'), vm=require('vm'), assert=require('assert/strict');
const root=path.join(__dirname,'..');
const source=fs.readFileSync(path.join(root,'scripts/zm/zm_tower_of_doom/_tod_sprinter.gsc'),'utf8');
const constants=Object.fromEntries([...source.matchAll(/^#define\s+(\w+)\s+([-\d.]+)/gm)].map(m=>[m[1],Number(m[2])]));
function extract(src,name) {
    const clean=src.replace(/\/\/[^\n]*/g,'');
    const match=new RegExp('function '+name+'\\(\\s*([^)]*)\\)').exec(clean);
    assert.ok(match,name);
    const start=clean.indexOf('{',match.index);
    let end=start+1, depth=1;
    while(depth) { if(clean[end]==='{')depth++; if(clean[end]==='}')depth--; end++; }
    return {params:match[1].trim(),body:clean.slice(start+1,end-1)};
}
function translated(src,name,generator=false) {
    const {params,body}=extract(src,name);
    let code=body.replace(/level endon\([^;]*;/g,'')
        .replace(/\bwait (\d+);/g,'yield $1;')
        .replace(/z thread promote_to_sprinter\(\);/g,'promote(z);')
        .replace(/z zombie_utility::is_zombie\(\)/g,'isZombie(z)')
        .replace(/tod_bosses::elite_mult\(\)/g,'eliteMult()')
        .replace(/\/#|#\//g,'').replace(/\.size\b/g,'.length');
    for(const [key,value] of Object.entries(constants))code=code.replace(new RegExp('\\b'+key+'\\b','g'),String(value));
    const locals=[...new Set([...code.matchAll(/^\s*(\w+)\s*=/gm)].map(m=>m[1]))];
    return `function${generator?'*':''} ${name}(${params}) { ${locals.length?'let '+locals.join(',')+';':''} ${code} }`;
}
function scenario(src,dev=true,np=1,mult=1,round=1) {
    const c={level:{tod_dev:dev,tod_sprinter_debt:0,round_number:round},ai:[],logs:[],promotions:[]};
    c.IS_TRUE=x=>x===true; c.isdefined=x=>x!==undefined; c.isalive=z=>z.alive===true;
    c.isZombie=z=>z.is_zombie===true; c.GetPlayers=()=>Array(np).fill({});
    c.GetAISpeciesArray=c.GetAITeamArray=()=>c.ai; c.int=Math.trunc;
    c.eliteMult=()=>mult; c.GetTime=()=>1000; c.PrintLn=line=>c.logs.push(line);
    c.promote=z=>{z.tod_is_sprinter=true;c.promotions.push({round:c.level.round_number,id:z.id});};
    vm.createContext(c);
    for(const name of ['eligible','sprinter_due','sprint_max_alive','sprinters_alive','dev_wait','dev_log'])
        vm.runInContext(translated(src,name),c);
    for(const name of ['round_watch','director'])vm.runInContext(translated(src,name,true),c);
    c.watch=c.round_watch(); c.sweep=c.director(); c.watch.next(); c.sweep.next();
    c.tick=()=>{assert.equal(c.watch.next().done,false);assert.equal(c.sweep.next().done,false);};
    c.regular=id=>({id,alive:true,is_zombie:true,archetype:'zombie'});
    return c;
}
function run(src) {
    const c=scenario(src);
    c.ai=[c.regular(1),c.regular(2),c.regular(3)]; c.tick();
    assert.equal(c.promotions.length,1,'round 1 is included without the unlock');
    for(let i=0;i<8;i++)c.tick();
    assert.equal(c.promotions.length,1,'no repeated quota in the same round');
    c.ai[0].alive=false; c.tick();
    assert.equal(c.promotions.length,1,'killing the preview does not respawn it this round');
    c.level.round_number=2; c.tick();
    assert.equal(c.promotions.length,2,'next round gets one more');
    assert.equal(c.promotions[1].round,2);
    assert.equal(c.logs.filter(x=>x.includes('ROUND_ARM')).length,2);

    const coop=scenario(src,true,4,2,8);
    coop.level.tod_enemy_unlock_round={sprinter:8};
    coop.ai=Array.from({length:12},(_,i)=>coop.regular(i)); coop.tick();
    assert.equal(coop.promotions.length,1,'late-start current round, co-op and Rampage still get ONE');

    const paused=scenario(src); paused.ai=[paused.regular(1)];
    paused.level.tod_upgrade_pause=true; paused.tick(); paused.tick();
    assert.equal(paused.promotions.length,0); assert.equal(paused.level.tod_sprinter_debt,1);
    assert.equal(paused.logs.filter(x=>x.includes('reason=upgrade_pause')).length,1,'wait logging is change-only');
    paused.level.tod_upgrade_pause=false; paused.tick(); assert.equal(paused.promotions.length,1);

    const waiting=scenario(src); waiting.tick(); waiting.tick();
    assert.equal(waiting.promotions.length,0); assert.equal(waiting.level.tod_sprinter_debt,1);
    assert.equal(waiting.logs.filter(x=>x.includes('reason=no_eligible_zombie')).length,1);
    waiting.ai=[{...waiting.regular(1),is_boss:true},{...waiting.regular(2),archetype:'brutus'},
        {...waiting.regular(3),alive:false},waiting.regular(4)];
    waiting.tick(); assert.equal(waiting.promotions[0].id,4,'only a living settled regular zombie is converted');

    const finale=scenario(src); finale.level.tod_finale_aggro=true;
    finale.ai=[finale.regular(1)]; finale.tick(); assert.equal(finale.promotions.length,0);
    assert.ok(finale.logs.some(x=>x.includes('reason=finale')));

    const ship=scenario(src,false,4,2); ship.ai=Array.from({length:20},(_,i)=>ship.regular(i));
    ship.tick(); ship.level.round_number=2; ship.tick();
    assert.equal(ship.promotions.length,0,'ship stays locked');
    ship.level.tod_enemy_unlock_round={sprinter:4}; ship.level.round_number=4; ship.tick();
    assert.equal(ship.promotions.length,5,'normal co-op/rampage debt still respects the standing roof');
    assert.equal(ship.level.tod_sprinter_debt,3);
    assert.equal(ship.logs.length,0,'normal play has no dev preview logs');
}
run(source);
for(const [label,broken] of [
    ['missing current round',source.replace('last = -1;','last = level.round_number;')],
    ['scaled dev quota',source.replace('level.tod_sprinter_debt = 1;','level.tod_sprinter_debt = GetPlayers().size;')],
    ['rearming the same round',source.replace('r < 1 || r == last','r < 1')],
    ['ungated preview',source.replace('if ( IS_TRUE( level.tod_dev ) )\n\t\t{\n\t\t\tlevel.tod_sprinter_debt = 1;', 'if ( true )\n\t\t{\n\t\t\tlevel.tod_sprinter_debt = 1;')],
]) assert.throws(()=>run(broken),'negative control: '+label);
console.log('ARMORED_DEV_ROUNDS_OK: current round + one per later round, no repeats, co-op/Rampage quota one, pause/no-AI recovery, eligible actors only, finale guard, ship cadence preserved; four negative controls.');
