/* Reactio Draw NMR environment encoder (rd-sphere-v1), shared by the table builder and the program.
   A molecule is {atoms:[{el,chg,h}], bonds:[{a,b,o}]} with heavy atoms only (h = attached hydrogens),
   bond order 1, 2, 3 or 4 (aromatic as given). Aromatic rings are perceived here, so Kekulé forms agree.
   Each atom gets codes for spheres 1..MAXL: the tree of all shortest paths from the atom, every node written
   as bond+element(+a if aromatic)+H count+charge, children sorted, ring closures inside a sphere marked. */
(function(root){
const MAXL=5;
function adjOf(M){const n=M.atoms.length,adj=Array.from({length:n},()=>[]);M.bonds.forEach((b,i)=>{adj[b.a].push([b.b,i]);adj[b.b].push([b.a,i]);});return adj;}
/* small rings (3..7) through bonds, by bounded DFS */
function smallRings(M,adj){const rings=[],seen=new Set(),n=M.atoms.length;
  for(let s=0;s<n;s++){const path=[s],on=new Set([s]);
    (function dfs(u){if(path.length>7)return;for(const [v] of adj[u]){if(v===s&&path.length>=3){const r=path.slice(),key=r.slice().sort((x,y)=>x-y).join(',');if(!seen.has(key)){seen.add(key);rings.push(r);}continue;}
      if(on.has(v)||v<s)continue;on.add(v);path.push(v);dfs(v);path.pop();on.delete(v);}})(s);}
  return rings;}
function bondBetween(adj,u,v){for(const [w,i] of adj[u])if(w===v)return i;return -1;}
/* aromatic perception: 5-7 rings whose atoms are all conjugated and give 4n+2 pi electrons */
function aromatic(M,adj){const arB=new Set(),arA=new Set();const rings=smallRings(M,adj).filter(r=>r.length>=5&&r.length<=7).sort((a,b)=>a.length-b.length);
  for(const b of M.bonds.keys())if(M.bonds[b].o===4)arB.add(b);
  let changed=true;
  while(changed){changed=false;
    for(const r of rings){const rb=r.map((u,k)=>bondBetween(adj,u,r[(k+1)%r.length]));if(rb.every(b=>arB.has(b)))continue;
      let pi=0,ok=true;
      for(let k=0;k<r.length&&ok;k++){const u=r[k],A=M.atoms[u];const inRingDouble=rb.some(b=>(M.bonds[b].a===u||M.bonds[b].b===u)&&(M.bonds[b].o===2));
        const inRingArom=rb.some(b=>(M.bonds[b].a===u||M.bonds[b].b===u)&&arB.has(b));
        const exoDouble=adj[u].some(([v,b])=>!r.includes(v)&&M.bonds[b].o===2);
        if(inRingDouble||inRingArom){pi+=1;continue;}
        if(exoDouble){ok=false;break;}
        if(['N','O','S','Se','P'].includes(A.el)&&A.chg<=0){pi+=2;continue;}
        if(A.el==='C'&&A.chg===-1){pi+=2;continue;}
        if((A.el==='C'||A.el==='B')&&A.chg===1||A.el==='B'){pi+=0;continue;}
        ok=false;}
      if(ok&&pi%4===2){rb.forEach(b=>arB.add(b));r.forEach(u=>arA.add(u));changed=true;}}}
  for(const b of arB){arA.add(M.bonds[b].a);arA.add(M.bonds[b].b);}
  return {arB,arA};}
function prepare(M){const adj=adjOf(M);const {arB,arA}=aromatic(M,adj);
  const sym=M.atoms.map((A,i)=>(arA.has(i)?A.el.toLowerCase():A.el)+(A.h?'H'+A.h:'')+(A.chg?(A.chg>0?'+':'-')+Math.abs(A.chg):''));
  const bsym=M.bonds.map((b,i)=>arB.has(i)?':':b.o===2?'=':b.o===3?'#':'-');
  return {adj,sym,bsym};}
/* codes for one atom: codes[L-1] describes spheres 1..L */
function codesFor(P,root,maxL){maxL=maxL||MAXL;const n=P.sym.length,dist=new Array(n).fill(-1);dist[root]=0;let fr=[root];
  for(let d=1;d<=maxL&&fr.length;d++){const nx=[];for(const u of fr)for(const [v] of P.adj[u])if(dist[v]<0){dist[v]=d;nx.push(v);}fr=nx;}
  const memo=new Map();
  function node(u,depth,lim){const key=u+'|'+depth+'|'+lim;if(memo.has(key))return memo.get(key);
    let s='';
    if(depth<lim){const kids=[],rc=[];for(const [v,b] of P.adj[u]){if(dist[v]===dist[u]+1)kids.push(P.bsym[b]+node(v,depth+1,lim));else if(dist[v]===dist[u]&&v!==u)rc.push(P.bsym[b]+'%');}
      kids.sort();rc.sort();if(kids.length||rc.length)s='('+kids.join(',')+(rc.length?';'+rc.join(''):'')+')';}
    const r=P.sym[u]+s;memo.set(key,r);return r;}
  const out=[];for(let L=1;L<=maxL;L++)out.push(node(root,0,L));return out;}
/* 32-bit FNV-1a, then a second hash folded in, to keep keys small */
function hash(str){let h=0x811c9dc5,g=0x01000193^str.length;for(let i=0;i<str.length;i++){const c=str.charCodeAt(i);h^=c;h=Math.imul(h,16777619)>>>0;g=Math.imul(g^c,2246822519)>>>0;}return ((h^(g>>>7))>>>0);}
const api={MAXL,prepare,codesFor,hash,aromatic,smallRings};
if(typeof module!=='undefined')module.exports=api;else root.RDNMR=api;
})(typeof window!=='undefined'?window:globalThis);
