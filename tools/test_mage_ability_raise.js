const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const src=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_mage_elements.gsc','utf8');
const cls=fs.readFileSync('scripts/zm/zm_tower_of_doom/_tod_classes.gsc','utf8');
function body(s,n){s=s.replace(/\/\/[^\n]*/g,'');let a=s.indexOf('{',s.indexOf('function '+n+'(')),z=a+1,d=1;while(d){if(s[z]==='{')d++;if(s[z]==='}')d--;z++;}return s.slice(a+1,z-1);}
function translate(s){return s.replace(/self thread (\w+)\(/g,'self.$1(').replace(/self (?:\w+::)?(\w+)\(/g,'self.$1(').replace(/\bwait 0\.05;/g,'yield 0.05;').replace(/\bcamo_stamp\(/g,'self.camo_stamp(').replace(/\bpap_camo_options\(/g,'self.pap_camo_options(');}
let ctx={isdefined:v=>v!==undefined,IS_TRUE:v=>v===true,level:{weaponNone:null},staff_element:w=>w&&w.staff?1:undefined};vm.createContext(ctx);
vm.runInContext('function regive(weapon,raise,initial_raise){let clip,stock;'+translate(body(cls,'camo_regive'))+'}\nfunction cast(){let weapon;'+translate(body(src,'ability_first_raise'))+'}\nfunction* equip(weapon){let i;'+translate(body(src,'ability_first_raise_equip'))+'}',ctx);
for(const el of ['lightning','fire','ice'])for(const q of [0,1])for(const ammo of [0,7]){
 const w={staff:true,name:el+'_q'+q};let owned=true,clip=ammo,stock=42,current=w,events=[],camo=3;
 ctx.self={GetCurrentWeapon:()=>current,HasWeapon:()=>owned,GetWeaponAmmoClip:()=>clip,GetWeaponAmmoStock:()=>stock,TakeWeapon:()=>{owned=false;current=null;},GiveWeapon:(x,opts)=>{assert.equal(x,w);assert.equal(opts,camo);owned=true;clip=99;stock=99;},SetWeaponAmmoClip:(x,n)=>clip=n,SetWeaponAmmoStock:(x,n)=>stock=n,pap_camo_options:()=>camo,camo_stamp:()=>{},notify:n=>events.push(n),endon:()=>{},camo_regive:(x,r)=>ctx.regive(x,r),ShouldDoInitialWeaponRaise:(x,v)=>{assert(owned);assert.equal(x,w);assert.equal(v,true);events.push('first');},ability_first_raise_equip:x=>{ctx.pending=ctx.equip(x);},player_is_in_laststand:()=>false,SwitchToWeaponImmediate:x=>{events.push('switch');current=x;}};
 ctx.cast();assert.equal(clip,ammo);assert.equal(stock,42);assert.equal(events[0],'tod_mage_reload_attempt');assert(events.includes('first'));ctx.pending.next();assert(!events.includes('switch'));ctx.pending.next();assert.equal(current,w);ctx.pending.next();assert.equal(events.filter(x=>x==='switch').length,1);
}
console.log('Ability re-equip: all six staff variants, empty/partial ammo, camo preservation, reload cancellation and delayed equip pass. Native animation still needs playtest.');
