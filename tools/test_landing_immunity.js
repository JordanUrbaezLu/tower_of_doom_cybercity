// Execute both actual landing-damage loops with mocked actors/native physics.
const fs=require('fs'),vm=require('vm'),assert=require('assert/strict'),path=require('path');
const root=path.resolve(__dirname,'..');
const robot=fs.readFileSync(path.join(root,'scripts/zm/zm_zod_robot.gsc'),'utf8');
const bosses=fs.readFileSync(path.join(root,'scripts/zm/zm_tower_of_doom/_tod_bosses.gsc'),'utf8');
function body(src,name){
 src=src.replace(/\/\/[^\n]*/g,'');
 let a=src.indexOf('{',src.indexOf('function '+name+'(')),b=a+1,d=1;
 while(d){if(src[b]==='{')d++;if(src[b]==='}')d--;b++;}return src.slice(a+1,b-1);
}
const env={IS_TRUE:x=>x===true,isdefined:x=>x!==undefined,IsAlive:x=>x.alive,
 level:{},endon:()=>{},SQR:x=>x*x,
 GetAITeamArray:()=>env.actors,getAITeamArray:()=>env.actors,
 DistanceSquared:(a,b)=>(a-b)**2,distanceSquared:(a,b)=>(a-b)**2,
 closest:(origin,actors,a,b,radius)=>actors.filter(x=>x&&Math.abs(x.origin-origin)<=radius),
 damage:(a,n,point,attacker)=>env.hits.push({a,n,attacker}),
 ragdoll:a=>env.ragdolls.push(a),launch:a=>env.launched.push(a)};
env.isDefined=env.isdefined;env.isalive=env.IsAlive;
vm.createContext(env);
vm.runInContext(`function landing_splash_immune(actor){${body(robot,'landing_splash_immune')}}`,env);
function transpile(src,name){return body(src,name)
 .replace(/level endon\(/g,'endon(').replace(/\.size/g,'.length')
 .replace(/foreach \( ai_zombie in a_ai_zombies \)/g,'for (const ai_zombie of a_ai_zombies)')
 .replace(/array::get_all_closest/g,'closest').replace(/zm_zod_robot::/g,'')
 .replace(/v_fling = [^;]+;/g,'v_fling = 0;')
 .replace(/ai_zombie (doDamage|DoDamage)\(/g,'damage(ai_zombie,')
 .replace(/ai_zombie (startRagdoll|StartRagdoll)\(\)/g,'ragdoll(ai_zombie)')
 .replace(/ai_zombie (launchRagdoll|LaunchRagdoll)\(/g,'launch(ai_zombie,');}
vm.runInContext(`function tower(v_origin,e_boss){let n_radius,a_ai,i,ai_zombie,v_fling;${transpile(bosses,'landing_kill_splash')}}
function civil(v_origin,e_attacker,n_radius){let a_ai_zombies,n_distance_sqr,n_dist_mult,v_fling,n_size;${transpile(robot,'zod_robot_do_landing_damage')}}`,env);
const actor=(name,fields={})=>({name,origin:20,health:100,alive:true,...fields});
const protectedActors=[
 actor('armored sprinter',{tod_is_sprinter:true}),actor('boss flag',{is_boss:true}),
 actor('legacy boss',{acc_is_boss:true}),actor('legacy elite',{acc_is_mini_boss:true}),
 ...['panzer','protector','reaver','hellhound','warden_king','future_elite'].map(tod_boss_kind=>actor(tod_boss_kind,{tod_boss_kind})),
 actor('dead',{alive:false}),
];
const trash=actor('ordinary'),edge=actor('edge',{origin:350}),far=actor('outside',{origin:351});
env.actors=[undefined,...protectedActors,trash,edge,far];
for(const mode of ['tower','civil'])for(const attacker of [undefined,actor('caller')]){
 env.hits=[];env.ragdolls=[];env.launched=[];
 if(mode==='tower')env.tower(0,attacker);else env.civil(0,attacker,350);
 assert.deepEqual(env.hits.map(x=>x.a.name),['ordinary','edge']);
 assert.deepEqual(env.ragdolls.map(x=>x.name),['ordinary','edge']);
 assert.deepEqual(env.launched.map(x=>x.name),['ordinary','edge']);
 assert(env.hits.every(x=>x.n===10100),'ordinary entrance kills retained');
 if(mode==='civil')assert(env.hits.every(x=>x.attacker===attacker),'attribution preserved');
}
env.actors=[trash];env.hits=[];env.tower(0,trash);assert.equal(env.hits.length,0,'lander protected even without flags');
console.log('Landing immunity passed in both live loops: armored sprinters, all boss/elite markers, no damage or ragdoll; ordinary zombies, radius boundary and attribution preserved.');
