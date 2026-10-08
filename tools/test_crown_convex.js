'use strict';
const assert=require('assert'),fs=require('fs'),path=require('path');
const C=require('./convex_brush');
const root=path.join(__dirname,'..');
const map=fs.readFileSync(path.join(root,'map_source/zm/zm_tower_of_doom.map'),'utf8');
const re=/^\/\/ brush \d+ [—-] (crown .*?)\r?\n\{([\s\S]*?)^\}/gm;
let m,count=0,sloped=0;const names=[];
while((m=re.exec(map))) {
  const planes=C.readPlanes(m[2]),h=C.hull(planes);names.push(m[1]);count++;
  assert(h.faces.length>=4,m[1]);
  assert(h.lo.every((v,i)=>h.hi[i]>v+0.01),m[1]+' bounds');
  const center=h.lo.map((v,i)=>(v+h.hi[i])/2);
  const edges=new Map();
  for(const f of h.faces) {
    assert(f.area>0.001,m[1]+' face area');
    for(let i=0;i<f.vertices.length;i++) {
      const a=h.vertices.indexOf(f.vertices[i]),b=h.vertices.indexOf(f.vertices[(i+1)%f.vertices.length]);
      const key=[a,b].sort((x,y)=>x-y).join(',');edges.set(key,(edges.get(key)||0)+1);
    }
  }
  assert([...edges.values()].every(v=>v===2),m[1]+' hull must be closed');
  if(planes.some(p=>p.n.filter(v=>Math.abs(v)>1e-6).length>1))sloped++;
}
assert(sloped>400,'convex crown geometry is missing');
assert(!names.some(n=>/^crown skirt [0-9]|^crown skirt tooth/.test(n)),'stepped bell returned');
assert(names.some(n=>n.startsWith('crown hall arcade')),'hall arches missing');
assert(names.some(n=>n.startsWith('crown skirt swept shell')),'sloped underside missing');
// Analytic wedge: z in [0,x] inside a 10-square footprint. Its AABB
// would incorrectly block the whole height at x=1 and fill empty corner space.
const p=(n,d)=>({n,d});
const wedge=[p([-1,0,0],0),p([1,0,0],10),p([0,-1,0],0),p([0,1,0],10),p([0,0,-1],0),p([-Math.SQRT1_2,0,Math.SQRT1_2],0)];
const w=C.hull(wedge);
assert.strictEqual(w.vertices.length,6);
assert(C.verticalSpan(wedge,1,5).every((v,i)=>Math.abs(v-[0,1][i])<1e-8));
assert.strictEqual(C.verticalSpan(wedge,-1,5),null);
const expected=100+100+2*50+100*Math.SQRT2;
assert(Math.abs(w.faces.reduce((s,f)=>s+f.area,0)-expected)<1e-7);
console.log(`PASS ${count} emitted crown hulls closed; ${sloped} shaped solids; analytic wedge area and collision span`);
