# The hotkey chart: docs/hotkeys-chart.png and docs/Reactio Draw - Hotkeys.reactio, drawn by the program itself.
from playwright.sync_api import sync_playwright
import os
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'..'))
PAGE='file://'+os.path.join(ROOT,'index.html')
OUT=os.path.join(ROOT,'docs')
import json
END=[('1','Digit1',0,'bond, turning left'),('`','Backquote',0,'bond, turning right'),('0','Digit0',0,'branch, hotspot stays'),('2','Digit2',0,'acetyl'),('3 / a','Digit3',0,'phenyl'),('4','Digit4',0,'wedged methyl'),('5','Digit5',0,'hashed methyl'),
     ('6','Digit6',0,'cyclohexyl'),('7','Digit7',0,'cyclopentyl'),('8','Digit8',0,'vinyl'),('9','Digit9',0,'isopropyl'),('z','KeyZ',0,'ethynyl'),('Z','KeyZ',1,'azide'),
     ('v','KeyV',0,'cyclopropyl'),('u','KeyU',0,'cyclobutyl'),('k','KeyK',0,'sulfonyl + C'),('K','KeyK',1,'tert-butyl'),('+','Equal',0,'charge +'),('−','Minus',0,'charge −'),('r','KeyR',0,'radical'),('j (twice)','KeyJ',0,'η5-Cp sandwich'),('J','KeyJ',1,'η6-benzene')]
LAB=[('o / q','KeyO',0,'OH'),('O','KeyO',1,'OMe'),('n / w','KeyN',0,'NH2'),('N','KeyN',1,'NO2'),('s','KeyS',0,'SH'),('S','KeyS',1,'SiH3'),('p','KeyP',0,'PH2'),('P','KeyP',1,'Ph'),
     ('f','KeyF',0,'F'),('F','KeyF',1,'CF3'),('l / C','KeyL',0,'Cl'),('L','KeyL',1,'Li'),('b','KeyB',0,'Br'),('B','KeyB',1,'BH2'),('h','KeyH',0,'H'),('H','KeyH',1,'Cbz'),
     ('y','KeyY',0,'Boc'),('Q','KeyQ',1,'Fmoc'),('m','KeyM',0,'Me'),('M','KeyM',1,'MgBr'),('c','KeyC',0,'CH3 shown'),('i','KeyI',0,'I'),('d','KeyD',0,'D'),('A','KeyA',1,'Ac'),('e','KeyE',0,'Et'),('E','KeyE',1,'CO2Me')]
MID=[('2','Digit2',0,'C=O'),('9','Digit9',0,'gem-dimethyl'),('K','KeyK',1,'wedge + hash'),('0','Digit0',0,'branch'),('6','Digit6',0,'spiro 6'),('7','Digit7',0,'spiro 5'),('v','KeyV',0,'spiro 3'),('u','KeyU',0,'spiro 4')]
BOND=[('1','Digit1',0,'single'),('2','Digit2',0,'double'),('3','Digit3',0,'triple'),('w','KeyW',0,'wedge'),('h / W','KeyH',0,'hashed wedge'),('H','KeyH',1,'hashed'),('b','KeyB',0,'bold'),('d','KeyD',0,'dashed'),('y','KeyY',0,'wavy'),
      ('a','KeyA',0,'fused benzene'),('z','KeyZ',0,'fused cyclopentadiene'),('v','KeyV',0,'fused cyclopropane'),('4','Digit4',0,'fused 4-ring'),('5','Digit5',0,'fused 5-ring'),('6','Digit6',0,'fused 6-ring'),('7','Digit7',0,'fused 7-ring'),('8','Digit8',0,'fused 8-ring'),('o','KeyO',0,'ring circle; + − its charge')]
NAV=[('← → ↑ ↓','move the hotspot: atom, bond, atom over the structure'),('Shift+arrow','to the last atom that way: along the chain, or straight across a ring'),('Alt+Shift+arrow','to the next structure'),
     ('Enter','edit the label'),('[ then ]','bond two atoms (ring closure): [ on the first, ] on the second'),('Ctrl+Shift+L','two atoms selected: bond them and clean up'),
     ('Esc','no hotspot (a click on empty sheet does the same)'),(', / .','one hydrogen fewer, one more'),('l / r / c','on a double bond: second line left, right or centred'),
     ('f','bond in front at a crossing')]
JS=r'''
([END,LAB,MID,BOND,NAV])=>{const K=window.__rd,m=K.mol;ReactioAPI.run("clear",{});
 const GREEN='#2fb344',INK='#1d2733',MUTED='#5a6879',CW=118,COLS=9,W=20+COLS*CW;let Y=36;
 const txt=(s,x,y,o)=>{o=o||{};const t={id:m.next++,x,y,text:s,size:o.size||11,fs:!!o.fs,nochem:true};if(o.bold)t.bold=true;if(o.color)t.color=o.color;m.texts.push(t);return t;};
 const ctr=(t,cx)=>{t.x=cx-K.textW(t)/2;return t;};
 const line=(x1,y1,x2,y2,w,c)=>m.arrows.push({id:m.next++,x1,y1,x2,y2,head:'none',w:w||0.8,col:c||'#c3cad4'});
 /* a key drawn as a keycap; 'a / b' gives two caps */
 const caps=(lab,cx,y)=>{const ks=lab.split(/ \/ | then /),seps=(lab.match(/ \/ | then /g)||[]).map(x=>x.trim()==='/'?'or':'then'),parts=ks.map(k=>{const t=txt(k,0,y+16,{size:13,bold:true,color:INK});return {t,w:Math.max(24,K.textW(t)+14)};});
   const gap=14,tot=parts.reduce((a,p)=>a+p.w,0)+seps.reduce((a,q)=>a+(q==='then'?28:gap),0);let x=cx-tot/2;
   parts.forEach((p,i)=>{m.arrows.push({id:m.next++,kind:'shp',sh:'rrect',st:'plain',x1:x,y1:y,x2:x+p.w,y2:y+22,w:1,col:'#8d99a8'});ctr(p.t,x+p.w/2);x+=p.w;
     if(i<parts.length-1){const sw=seps[i]==='then'?28:gap;ctr(txt(seps[i],0,y+15,{size:9,color:MUTED}),x+sw/2);x+=sw;}});};
 const head=s=>{Y+=8;txt(s,20,Y,{size:16,bold:true,color:INK});line(20,Y+9,W-10,Y+9,1.6,'#5a6879');Y+=30;};
 const bboxOf=(as)=>{let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;for(const a of as){const r=a.label?12:a.el!=='C'?9:3;x0=Math.min(x0,a.x-r);x1=Math.max(x1,a.x+r);y0=Math.min(y0,a.y-r);y1=Math.max(y1,a.y+r);}return {x0,y0,x1,y1};};
 /* one row of cells: keycap, the drawing just under it, the caption just under the drawing */
 const grid=(items,make,desc)=>{for(let r0=0;r0<items.length;r0+=COLS){const row=items.slice(r0,r0+COLS),cells=[];if(r0){line(20,Y-16,W-10,Y-16,1.1,'#bcc4ce');Y+=4;}
     row.forEach((it,i)=>{const cx=20+CW/2+i*CW;caps(it[0],cx,Y);const na=m.atoms.length;make(it,cx,Y+200);const as=m.atoms.slice(na);cells.push({it,cx,as});});
     /* each drawing moved up to sit 14 under its keycap, centred in its cell */
     let bottom=Y+40;for(const c of cells){if(!c.as.length)continue;const b=bboxOf(c.as),dx=c.cx-(b.x0+b.x1)/2,dy=Y+30-b.y0;for(const a of c.as){a.x+=dx;a.y+=dy;}bottom=Math.max(bottom,b.y1+dy);}
     if(desc!==false)for(const c of cells)ctr(txt(c.it[3],0,bottom+18,{size:10.5,color:MUTED}),c.cx);
     Y=bottom+(desc!==false?52:48);}
   Y+=6;};
 const bond=(a,b,o)=>m.bonds.push({id:m.next++,a:a.id,b:b.id,order:o||1,stereo:null});
 const hl=a=>{if(a&&m.atoms.includes(a)&&!a.label&&!a.chg&&a.el==='C')a.hl=GREEN;};
 const ev=(code,sh)=>({code,shiftKey:!!sh,key:''});
 txt('Reactio Draw hotkeys',20,Y,{size:22,bold:true,color:INK});Y+=24;
 txt('Point at an atom or a bond and press a key. Green marks the hotspot, where the next key acts. A capital letter means the key with Shift.',20,Y,{size:11.5,color:MUTED});Y+=26;
 head('Atom at the end of a chain');
 grid(END,([lab,code,sh],cx,cy)=>{const A=K.newAtom(cx-30,cy+18,'C'),B=K.newAtom(cx,cy,'C');bond(A,B);let r;
   if(code==='Equal'){B.chg=1;r=B;}else if(code==='Minus'){B.chg=-1;r=B;}else if(code==='KeyR'){B.rad=1;r=B;}else if(code==='KeyJ'){m.bonds.pop();m.atoms.splice(m.atoms.indexOf(A),1);B.el=sh?'Cr':'Fe';K.atomKey(B,ev(code,sh));if(!sh)K.atomKey(B,ev(code,sh));r=null;}else r=K.atomKey(B,ev(code,sh));hl(r);});
 head('Labels and elements on that atom');
 grid(LAB,([lab,code,sh],cx,cy)=>{const A=K.newAtom(cx-30,cy+18,'C'),B=K.newAtom(cx,cy,'C');bond(A,B);if(code==='KeyC')K.setLabel(B,'CH3');else K.atomKey(B,ev(code,sh));},false);
 head('Atom in the middle of a chain');
 grid(MID,([lab,code,sh],cx,cy)=>{const A=K.newAtom(cx-32,cy+18,'C'),B=K.newAtom(cx,cy,'C'),C=K.newAtom(cx+32,cy+18,'C');bond(A,B);bond(B,C);const r=K.atomKey(B,ev(code,sh));hl(r);});
 head('Bond');
 grid(BOND,([lab,code,sh],cx,cy)=>{let b;
   if(/^Digit[1-3]$|Key[WHBDY]/.test(code)){const A=K.newAtom(cx-18,cy+10,'C'),B=K.newAtom(cx+18,cy-10,'C');bond(A,B);b=m.bonds[m.bonds.length-1];}
   else{const R=26,at=[];for(let i=0;i<5;i++){const g=Math.PI/2+i*2*Math.PI/5;at.push(K.newAtom(cx+R*Math.cos(g),cy+12+R*Math.sin(g),'C'));}for(let i=0;i<5;i++)bond(at[i],at[(i+1)%5]);
     b=m.bonds.find(q=>(q.a===at[2].id&&q.b===at[3].id)||(q.a===at[3].id&&q.b===at[2].id));}
   K.bondKey(b,ev(code,sh));b.hl=GREEN;});
 head('Moving around');
 for(const [k,d] of NAV){caps(k,20+70,Y);const t=txt(d,180,Y+15,{size:11.5,color:INK});Y+=34;}
 Y+=6;txt('Every key can be changed in Settings → Hotkeys.',20,Y+12,{size:11.5,color:MUTED});
 K.commit();return {atoms:m.atoms.length,texts:m.texts.length};}
'''
with sync_playwright() as p:
    b=p.chromium.launch();pg=b.new_page(viewport={'width':1400,'height':900});pg.route('**/fonts.g*/**',lambda r:r.abort());errs=[];pg.on('pageerror',lambda e:errs.append(str(e)))
    pg.goto(PAGE,timeout=90000);pg.wait_for_function('()=>window.__rd',timeout=90000)
    print(pg.evaluate(JS,[END,LAB,MID,BOND,NAV]))
    open(OUT+'/Reactio Draw - Hotkeys.reactio','w').write(pg.evaluate('()=>JSON.stringify({rd:1,state:window.__rd.S},null,1)'))
    svg=pg.evaluate('()=>window.__rd.svgOf()')
    pg.set_content('<body style="margin:0;background:#fff">'+svg+'</body>');pg.evaluate("()=>{const s=document.querySelector('svg');s.style.width='2200px';s.style.height='auto'}")
    pg.set_viewport_size({'width':2200,'height':900});pg.screenshot(path=OUT+'/hotkeys-chart.png',full_page=True)
    print(errs)
