/* Builds Reactio Draw NMR shift tables from the nmrshiftdb2 export (nmrshiftdb2withsignals.sd).
   Measured spectra only (spectra with a Program/NMRProgram entry are calculated and skipped).
   For each nucleus and sphere level: per molecule one median per environment code, then the median over molecules.
   Usage: node build.js <sd> <outdir> [holdout]   (holdout=1: leave out ~10% of molecules by InChIKey for validation) */
const fs=require('fs'),path=require('path'),C=require('./nmrcore.js');
const [,,SD,OUT,HOLD]=process.argv;const holdout=HOLD==='1';
const NUCS={'13C':'C','1H':'H','19F':'F','31P':'P','11B':'B','29Si':'Si','195Pt':'Pt','15N':'N','17O':'O'};
const VAL={C:[4],N:[3,5],O:[2],S:[2,4,6],P:[3,5],B:[3],Si:[4],F:[1],Cl:[1,3,5,7],Br:[1],I:[1,3,5],Se:[2,4,6],Ge:[4],Sn:[4],As:[3,5],Te:[2,4,6]};
function valence(el,chg,sum){let v=VAL[el];if(!v)return sum;let adj=0;
  if(el==='N'||el==='P'||el==='As')adj=chg>0?1:chg<0?-1:0;else if(el==='O'||el==='S'||el==='Se')adj=chg>0?1:chg<0?-1:0;else if(el==='C'||el==='Si')adj=chg!==0?-1:0;else if(el==='B')adj=chg<0?1:chg>0?-1:0;
  for(const x of v)if(x+adj>=sum)return x+adj;return sum;}
function parseRecord(lines){const cnt=lines[3];const na=+cnt.slice(0,3),nb=+cnt.slice(3,6);
  const A=[],B=[];for(let k=0;k<na;k++){const l=lines[4+k];A.push({el:l.slice(31,34).trim(),chg:0,iso:0});}
  for(let k=0;k<nb;k++){const l=lines[4+na+k];B.push({a:+l.slice(0,3)-1,b:+l.slice(3,6)-1,o:+l.slice(6,9)});}
  let j=4+na+nb;for(;j<lines.length&&!lines[j].startsWith('M  END');j++){const l=lines[j];if(l.startsWith('M  CHG')){const n=+l.slice(6,9);for(let t=0;t<n;t++){const ai=+l.slice(10+8*t,13+8*t)-1,v=+l.slice(14+8*t,17+8*t);A[ai].chg=v;}}}
  const F={};let cur=null;for(const l of lines.slice(j+1)){const m=/^> <([^>]+)>/.exec(l);if(m){cur=m[1];F[cur]='';continue;}if(cur!==null&&l.trim())F[cur]+=l.trim();}
  return {A,B,F};}
function idxMap(s){const d={};if(!s)return d;const re=/(\d+):([^:]*?)(?=\s\d+:|$)/g;let m;while((m=re.exec(s)))d[+m[1]]=m[2].trim();return d;}
/* heavy-atom graph with hydrogen counts; map from original atom index to heavy index (H -> its parent) */
function heavyGraph(A,B){const map=new Array(A.length).fill(-1),atoms=[];A.forEach((a,i)=>{if(a.el!=='H'){map[i]=atoms.length;atoms.push({el:a.el,chg:a.chg,h:0,sum:0});}});
  const bonds=[];const hpar=new Array(A.length).fill(-1);
  for(const b of B){const ea=A[b.a].el,eb=A[b.b].el;if(ea==='H'&&eb!=='H'){hpar[b.a]=map[b.b];atoms[map[b.b]].h++;continue;}if(eb==='H'&&ea!=='H'){hpar[b.b]=map[b.a];atoms[map[b.a]].h++;continue;}if(ea==='H'||eb==='H')continue;
    bonds.push({a:map[b.a],b:map[b.b],o:b.o});const w=b.o===4?1.5:b.o;atoms[map[b.a]].sum+=w;atoms[map[b.b]].sum+=w;}
  for(const a of atoms){const s=Math.round(a.sum+a.h);const v=valence(a.el,a.chg,s);a.h+=Math.max(0,v-s);delete a.sum;}
  A.forEach((a,i)=>{if(a.el==='H')map[i]=hpar[i];});
  return {M:{atoms,bonds},map};}
function median(v){const s=v.slice().sort((x,y)=>x-y),n=s.length;return n%2?s[(n-1)/2]:(s[n/2-1]+s[n/2])/2;}
function heldOut(key){let h=0;for(const c of key)h=(h*31+c.charCodeAt(0))>>>0;return h%10===0;}
/* collect */
const tables={};for(const n in NUCS)tables[n]=Array.from({length:C.MAXL},()=>new Map());
const test=[];let nrec=0,nskip=0;
const txt=fs.readFileSync(SD,'latin1');let start=0;
while(true){const e=txt.indexOf('$$$$',start);if(e<0)break;const lines=txt.slice(start,e).split(/\r?\n/);start=txt.indexOf('\n',e)+1;
  /* the molfile header is 3 lines; records start right after $$$$ */
  let rec;try{rec=parseRecord(lines);}catch(err){nskip++;continue;}nrec++;
  const {A,B,F}=rec;const prog=idxMap(F['Program']),nprog=idxMap(F['NMRProgram']);
  if(A.length>200){nskip++;continue;}
  let G;try{G=heavyGraph(A,B);}catch(err){nskip++;continue;}
  if(!G.M.atoms.length)continue;
  const key=(F['INChI key']||'').slice(0,14)||('id'+F['nmrshiftdb2 ID']);const isTest=holdout&&heldOut(key);
  let P=null,codes=null;
  for(const k in F){const m=/^Spectrum (\S+) (\d+)$/.exec(k);if(!m||!NUCS[m[1]])continue;const nuc=m[1],idx=+m[2];if(idx in prog||idx in nprog)continue;
    if(!P){P=C.prepare(G.M);codes=new Array(G.M.atoms.length);}
    /* per molecule: values per heavy atom */
    const per=new Map();for(const s of F[k].split('|')){if(!s)continue;const f=s.split(';');const v=parseFloat(f[0]),ai=+f[f.length-1];if(!isFinite(v)||!(ai>=0)||ai>=A.length)continue;
      const hi=G.map[ai];if(hi<0||hi===undefined)continue;const at=G.M.atoms[hi];
      if(nuc==='1H'){if(!at.h)continue;}else if(at.el!==NUCS[nuc])continue;
      if(!per.has(hi))per.set(hi,[]);per.get(hi).push(v);}
    if(isTest){for(const [hi,vals] of per)test.push({nuc,key,M:G.M,atom:hi,val:median(vals)});continue;}
    const byCode=Array.from({length:C.MAXL},()=>new Map());
    for(const [hi,vals] of per){if(!codes[hi])codes[hi]=C.codesFor(P,hi);for(let L=0;L<C.MAXL;L++){const c=codes[hi][L];if(!byCode[L].has(c))byCode[L].set(c,[]);byCode[L].get(c).push(median(vals));}}
    for(let L=0;L<C.MAXL;L++)for(const [c,vals] of byCode[L]){const t=tables[nuc][L];const h=C.hash(c);let e=t.get(h);if(!e){e={v:[],mols:new Set(),code:c};t.set(h,e);}else if(e.code!==c)e.clash=true;if(!e.mols.has(key)){e.mols.add(key);e.v.push(median(vals));}}}
}
console.error('records',nrec,'skipped',nskip,'test points',test.length);
fs.mkdirSync(OUT,{recursive:true});
/* compact binary per nucleus: for each level, entries sorted by hash: u32 hash, i16 shift*S, u8 molecules (capped), u8 spread*S/ (capped) */
const SCALE={'1H':100,'13C':10,'19F':10,'31P':10,'11B':10,'29Si':10,'195Pt':1,'15N':10,'17O':1};
/* two different environments with the same 32-bit key would mix their shifts: such a key is left out, so the
   prediction falls back to the shallower environment of that atom */
let clashes=0;const summary={};
for(const nuc in tables){const S=SCALE[nuc];const parts=[];let total=0;
  for(let L=0;L<C.MAXL;L++){const arr=[];for(const [h,e] of tables[nuc][L]){const n=e.mols.size;if(e.clash){clashes++;continue;}if(L>=2&&n<2)continue;const md=median(e.v);
      const sd=e.v.length>1?Math.sqrt(e.v.reduce((s,x)=>s+(x-md)*(x-md),0)/(e.v.length-1)):0;arr.push([h,Math.round(md*S),Math.min(255,n),Math.min(255,Math.round(sd*S/ (nuc==='1H'?10:1)))]);}
    arr.sort((a,b)=>a[0]-b[0]);const buf=Buffer.alloc(arr.length*8);arr.forEach((r,i)=>{buf.writeUInt32LE(r[0],i*8);buf.writeInt16LE(Math.max(-32768,Math.min(32767,r[1])),i*8+4);buf.writeUInt8(r[2],i*8+6);buf.writeUInt8(r[3],i*8+7);});
    parts.push(buf);total+=arr.length;}
  const head=Buffer.alloc(4*C.MAXL);parts.forEach((p,i)=>head.writeUInt32LE(p.length/8,i*4));
  const all=Buffer.concat([head,...parts]);fs.writeFileSync(path.join(OUT,nuc+'.bin'),all);summary[nuc]={entries:total,bytes:all.length};}
console.log(JSON.stringify(summary));console.error('hash clashes left out',clashes);
if(holdout)fs.writeFileSync(path.join(OUT,'test.json'),JSON.stringify(test));
