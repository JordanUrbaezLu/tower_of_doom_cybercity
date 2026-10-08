// Guard the requested DPS-preserving swaps, native rates and full upgrade ladders.
const fs=require('fs'),assert=require('assert/strict');
const source=fs.readFileSync('source_data/tod_weapon_twins.gdt','utf8');
const blocks=new Map([...source.matchAll(/"([^"\n]+)" \( "bulletweapon.gdf" \)\s*\{([\s\S]*?)\n\t\}/g)].map(m=>[m[1],Object.fromEntries([...m[2].matchAll(/"([^"\n]+)" "([^"\n]*)"/g)].map(f=>[f[1],f[2]]))]));
for(const [stem,count,rate,damage,packed,clip,reserve,previous] of [
 ['t6_msmc',32,.08,210,264,32,11,[142/.054,178/.0432]],
 ['t6_mk48',6,.096,275,344,60,6,[215/.075,269/.06]],
]){
 const forms=[...blocks].filter(([n])=>n.startsWith(stem+'_'));
 assert.equal(forms.length,count);
 for(const [name,f] of forms){
  const up=name.includes('_up'),axis=Number(name.match(/_f(\d)/)?.[1]||0);
  assert.equal(+f.damage,up?packed:damage);
  assert.equal(+f.clipSize,up?Math.round(clip*1.25):clip);
  assert.equal(+f.maxAmmo,reserve);
  assert.equal(+f.startAmmo,reserve);
  if(axis===0){
   assert(Math.abs(+f.fireTime-rate*(up?.8:1))<.00001);
   assert(Math.abs(+f.damage/+f.fireTime/previous[up?1:0]-1)<.002,'DPS within 0.2% of retired starter');
  }
  if(stem==='t6_mk48'){
   assert.equal(+f.reloadTime,up?4.95:6.6);
   assert.equal(+f.reloadEmptyTime,up?4.95:6.6);
   assert(Math.abs(+f.reloadAddTime-5.45*(6.6/8)*(up?.75:1))<.0001);
   assert.equal(f.reloadAddTime,f.reloadEmptyAddTime);
  }
  assert.equal(f.altWeapon,'');
 }
}
assert(!blocks.has('t9_mac10_f0h0'));assert(!blocks.has('t9_stoner63_p0'));
const rows=fs.readFileSync('sound/aliases/tod_ports.csv','utf8').split(/\r?\n/).map(r=>r.split(','));
for(const [stem,count] of [['t6_msmc',8],['t6_mk48',14]]){
 const aliases=rows.filter(r=>r[0].startsWith('wpn_'+stem+'_'));
 assert.equal(aliases.length,count);
 for(const row of aliases)assert(fs.existsSync('sound_assets/'+row[3].replace(/\\/g,'/')));
}
console.log('Starter swaps: 38 forms, native fire rates, preserved magazines/reserves, base/PaP DPS within 0.2%, and 22 sound aliases PASS.');

