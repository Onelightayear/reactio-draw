const fs=require('fs'),C=require('./nmrcore.js'),Lk=require('./lookup.js');
const test=JSON.parse(fs.readFileSync('out-h/test.json'));const SCALE={'1H':100,'13C':10,'19F':10,'31P':10,'11B':10,'29Si':10,'195Pt':1,'15N':10,'17O':1};
const T={};for(const n in SCALE)T[n]=Lk.loadTable(fs.readFileSync('out-h/'+n+'.bin'),C.MAXL);
const st={};const cache=new Map();
for(const t of test){const s=st[t.nuc]||(st[t.nuc]={n:0,hit:0,err:[],byL:{}});s.n++;
  let P=cache.get(t.M);if(!P){P=C.prepare(t.M);cache.set(t.M,P);}
  const r=Lk.predictAtom(C,T[t.nuc],P,t.atom,SCALE[t.nuc]);if(!r)continue;s.hit++;const e=Math.abs(r.shift-t.val);s.err.push(e);(s.byL[r.level]=s.byL[r.level]||[]).push(e);}
const med=a=>{const s=a.slice().sort((x,y)=>x-y);return s[Math.floor(s.length/2)]};
for(const n in st){const s=st[n];const mae=s.err.reduce((a,b)=>a+b,0)/s.err.length;
  console.log(n,'points',s.n,'coverage',(100*s.hit/s.n).toFixed(1)+'%','MAE',mae.toFixed(2),'median',med(s.err).toFixed(2),'byLevel',Object.entries(s.byL).map(([L,a])=>L+':'+a.length+'/'+(a.reduce((x,y)=>x+y,0)/a.length).toFixed(2)).join(' '));}
const errTab={};for(const n of ['13C','1H','19F','31P']){const s=st[n];errTab[n]={};for(const L in s.byL){const a=s.byL[L];errTab[n][L]=+(a.reduce((x,y)=>x+y,0)/a.length).toFixed(n==='1H'?2:1);}errTab[n].coverage=+(100*s.hit/s.n).toFixed(1);errTab[n].mae=+(s.err.reduce((a,b)=>a+b,0)/s.err.length).toFixed(2);errTab[n].points=s.n;}
fs.writeFileSync('errtab.json',JSON.stringify(errTab));console.log(JSON.stringify(errTab));
