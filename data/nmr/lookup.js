/* table lookup: binary file -> per level sorted entries; predict = deepest sphere level found */
function loadTable(buf,MAXL){const dv=new DataView(buf.buffer,buf.byteOffset,buf.byteLength);const counts=[];for(let i=0;i<MAXL;i++)counts.push(dv.getUint32(i*4,true));
  const levels=[];let off=4*MAXL;for(const n of counts){levels.push({off,n});off+=n*8;}return {dv,levels};}
function find(T,L,h){const {dv}=T,{off,n}=T.levels[L];let lo=0,hi=n-1;while(lo<=hi){const m=(lo+hi)>>1,v=dv.getUint32(off+m*8,true);if(v===h)return {val:dv.getInt16(off+m*8+4,true),n:dv.getUint8(off+m*8+6),sd:dv.getUint8(off+m*8+7)};if(v<h)lo=m+1;else hi=m-1;}return null;}
function predictAtom(C,T,P,atom,scale,minL){const codes=C.codesFor(P,atom);for(let L=C.MAXL-1;L>=(minL||0);L--){const r=find(T,L,C.hash(codes[L]));if(r)return {shift:r.val/scale,level:L+1,n:r.n,sd:r.sd};}return null;}
module.exports={loadTable,find,predictAtom};
