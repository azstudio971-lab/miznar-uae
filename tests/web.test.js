import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Window} from 'happy-dom';
import {esc,icon,validURL} from '../web/src/ui.js';
test('preview keeps RTL tabs, persists greeting, switches library, rejects unsafe links',async()=>{
 const w=new Window({url:'https://wudcar.test/app'});w.document.body.innerHTML='<div id="app"></div>';
 let source=readFileSync('web/src/preview.js','utf8').replace(/^import[^\n]+\n/gm,'').replace('export async function','async function');
 const db={auth:{getSession:async()=>({data:{session:null}})}};
 const fetch=async()=>({ok:true,json:async()=>({themes:[],library:[{id:'yt',name_ar:'YouTube',name_en:'YouTube',kind:'website',url:'https://youtube.com'}],music:[],updates:[],settings:{}})});
 const build=new Function('document','localStorage','matchMedia','Audio','db','SUPABASE_URL','SUPABASE_KEY','VERSION','esc','icon','toast','modal','field','validURL','fetch','setInterval','navigator','window',source+';return startPreview;');
 const start=build(w.document,w.localStorage,w.matchMedia.bind(w),class{pause(){}},db,'https://example.com','public','1.1.1',esc,icon,()=>{},()=>{},()=>'',validURL,fetch,()=>0,w.navigator,w);
 await start();const d=w.document;
 assert.deepEqual([...d.querySelectorAll('.phone-tabs button')].map(x=>x.dataset.tab),['home','themes','library','settings']);
 d.querySelector('[data-tab="settings"]').click();const n=d.querySelector('#username');n.value='راشد';n.dispatchEvent(new w.Event('change'));d.querySelector('[data-tab="home"]').click();assert.match(d.querySelector('.welcome').textContent,/راشد/);assert.match(d.querySelector('.car-hero').textContent,/راشد/);
 d.querySelector('[data-tab="library"]').click();assert.match(d.querySelector('.phone-scroll').textContent,/YouTube/);d.querySelector('[data-kind="live"]').click();assert.match(d.querySelector('.phone-scroll').textContent,/مكتبتك تبدأ/);
 assert.equal(validURL('javascript:alert(1)'),null);assert.equal(validURL('https://user:pass@example.com'),null);assert.equal(validURL('https://example.com'),'https://example.com/');
 await w.happyDOM.abort();
});
