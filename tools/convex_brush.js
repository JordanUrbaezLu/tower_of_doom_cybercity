'use strict';
// BO3 brush halfspaces: outward normal = (p1-p2) x (p3-p2).
// Shared by preview, area measurement and collision sampling. Read actual planes,
// never generator metadata, so a malformed emitted solid cannot pass by assertion.
const sub=(a,b)=>a.map((v,i)=>v-b[i]);
const dot=(a,b)=>a.reduce((s,v,i)=>s+v*b[i],0);
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const norm=a=>{const l=Math.hypot(...a); if(l<1e-9) throw Error('degenerate brush plane'); return a.map(v=>v/l);};
function plane(v,mat) {const n=norm(cross(sub(v[0],v[1]),sub(v[2],v[1])));return {n,d:dot(n,v[0]),mat,v};}
function hull(planes) {
  const vertices=[];
  for(let i=0;i<planes.length;i++)for(let j=i+1;j<planes.length;j++)for(let k=j+1;k<planes.length;k++) {
    const a=planes[i],b=planes[j],c=planes[k],bc=cross(b.n,c.n), det=dot(a.n,bc);
    if(Math.abs(det)<1e-8)continue;
    const ca=cross(c.n,a.n),ab=cross(a.n,b.n);
    const p=bc.map((v,t)=>(v*a.d+ca[t]*b.d+ab[t]*c.d)/det);
    if(planes.some(q=>dot(q.n,p)>q.d+0.02))continue;
    if(!vertices.some(q=>Math.hypot(...sub(q,p))<0.02))vertices.push(p);
  }
  if(vertices.length<4)throw Error('empty/unbounded convex brush');
  const faces=[];
  for(const q of planes) {
    const vs=vertices.filter(p=>Math.abs(dot(q.n,p)-q.d)<0.03);
    if(vs.length<3)continue;
    const center=[0,1,2].map(t=>vs.reduce((s,p)=>s+p[t],0)/vs.length);
    const u=norm(sub(vs[0],center)),v=cross(q.n,u);
    vs.sort((a,b)=>Math.atan2(dot(sub(a,center),v),dot(sub(a,center),u))-Math.atan2(dot(sub(b,center),v),dot(sub(b,center),u)));
    let area=0;for(let i=1;i<vs.length-1;i++)area+=Math.hypot(...cross(sub(vs[i],vs[0]),sub(vs[i+1],vs[0])))/2;
    faces.push({...q,vertices:vs,center,area});
  }
  const lo=[0,1,2].map(i=>Math.min(...vertices.map(v=>v[i]))),hi=[0,1,2].map(i=>Math.max(...vertices.map(v=>v[i])));
  return {planes,vertices,faces,lo,hi,x1:lo[0],x2:hi[0],y1:lo[1],y2:hi[1],z1:lo[2],z2:hi[2]};
}
function readPlanes(text) {
  const out=[];const re=/^\s*\(\s*([^)]*)\)\s*\(\s*([^)]*)\)\s*\(\s*([^)]*)\)\s+(\S+)/gm;let m;
  while((m=re.exec(text)))out.push(plane(m.slice(1,4).map(s=>s.trim().split(/\s+/).map(Number)),m[4]));
  return out;
}
function verticalSpan(planes,x,y) {
  let lo=-Infinity,hi=Infinity;
  for(const {n,d} of planes) {const rest=d-n[0]*x-n[1]*y;
    if(Math.abs(n[2])<1e-8){if(rest < -0.01)return null;}
    else if(n[2]>0)hi=Math.min(hi,rest/n[2]);else lo=Math.max(lo,rest/n[2]);
  }return hi>lo+0.01?[lo,hi]:null;
}
module.exports={sub,dot,cross,norm,plane,hull,readPlanes,verticalSpan};
