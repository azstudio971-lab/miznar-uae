import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Window} from 'happy-dom';
import {policies} from '../web/src/policies.js';
import {defaultSlots,validateSlots,greeting} from '../shared/domain.js';
test('web DOM: bilingual navigation, theme choice, greeting and cloud-unavailable state',()=>{
 const window=new Window({url:'https://wudcar.test/preview'});window.document.body.innerHTML='<div id="app"></div>';
 const source=readFileSync('web/src/main.js','utf8').replace(/^import[^\n]+\n/gm,'');
 const execute=new Function('window','document','location','history','localStorage','db','policies','defaultSlots','validateSlots','greeting','rows','save','remove',source);
 execute(window,window.document,window.location,window.history,window.localStorage,null,policies,defaultSlots,validateSlots,greeting,()=>{},()=>{throw Error('Unexpected write');},()=>{});
 const d=window.document;assert.equal(d.documentElement.dir,'rtl');
 const name=d.querySelector('#preview-name');name.value='راشد';name.dispatchEvent(new window.Event('input'));assert.match(d.querySelector('.clock').textContent,/راشد/);
 d.querySelector('[data-period="night"]').click();assert.match(d.querySelector('#scene img').src,/ultrawide\/night.png$/);assert.match(d.querySelector('.clock').textContent,/راشد/);
 d.querySelector('#shape').click();assert.match(d.querySelector('#scene img').src,/compact\/night.png$/);
 d.querySelector('#lang').click();assert.equal(d.documentElement.dir,'ltr');
 d.querySelector('a[href="/admin"]').click();assert.equal(d.querySelector('#login button').disabled,true);
 assert.match(d.body.textContent,/Cloud connection is not configured/);
 for(const route of ['privacy','terms','support','delete']){d.querySelector(`a[href="/${route}"]`).click();assert.ok(d.querySelector('h1').textContent.length>0);}
 window.happyDOM.abort();
});
test('phone preview saves a name, renders it on Home and blocks invalid media URLs',()=>{
 const window=new Window({url:'https://wudcar.test/app'});window.document.body.innerHTML='<div id="app"></div>';
 let source=readFileSync('web/src/phone-preview.js','utf8').replace(/^import[^\n]+\n/gm,'').replaceAll('export function','function');
 const build=new Function('document','localStorage','FormData','URL','validateMediaURL',source+';return {phonePreview,bindPhonePreview};');
 const {phonePreview,bindPhonePreview}=build(window.document,window.localStorage,window.FormData,URL,value=>{try{return new URL(value).protocol==='https:';}catch{return false;}});
 const render=()=>{window.document.querySelector('#app').innerHTML=phonePreview('ar');bindPhonePreview(render,()=>{});};render();
 const d=window.document;d.querySelector('[data-p-tab="settings"]').click();
 d.querySelector('#p-settings input[name="name"]').value='راشد';d.querySelector('#p-settings').dispatchEvent(new window.Event('submit',{cancelable:true}));
 d.querySelector('[data-p-tab="home"]').click();assert.match(d.querySelector('.p-hello').textContent,/راشد/);
 d.querySelector('[data-p-moment="night"]').click();assert.match(d.querySelector('.p-scene>img').src,/night.png$/);
 d.querySelector('[data-p-tab="library"]').click();d.querySelector('input[name="name"]').value='Test';d.querySelector('input[name="url"]').value='javascript:alert(1)';d.querySelector('#p-source-form').dispatchEvent(new window.Event('submit',{cancelable:true}));assert.match(d.querySelector('#p-source-error').textContent,/HTTPS/);
 d.querySelector('input[name="url"]').value='https://example.com/music.mp3';d.querySelector('#p-source-form').dispatchEvent(new window.Event('submit',{cancelable:true}));assert.equal(d.querySelectorAll('.p-source').length,1);
 d.querySelector('[data-p-tab="subscription"]').click();
 assert.match(d.querySelector('#p-trial-status').textContent,/30:00/);
 assert.equal(d.querySelector('#p-trial-minute').disabled,true);
 d.querySelector('#p-trial-pause').click();d.querySelector('#p-trial-minute').click();
 assert.match(d.querySelector('#p-trial-status').textContent,/29:00/);
 d.querySelector('#p-trial-pause').click();assert.equal(d.querySelector('#p-trial-minute').disabled,true);
 d.querySelector('[data-p-tab="home"]').click();d.querySelector('[data-p-tab="subscription"]').click();
 assert.match(d.querySelector('#p-trial-status').textContent,/29:00/);
 const mode=d.querySelector('#p-trial-mode');mode.value='paid';mode.dispatchEvent(new window.Event('change'));
 assert.match(d.querySelector('#p-trial-status').textContent,/اشتراك/);assert.equal(d.querySelector('#p-trial-minute').disabled,true);
 d.querySelector('#p-trial-mode').value='expired';d.querySelector('#p-trial-mode').dispatchEvent(new window.Event('change'));
 assert.match(d.querySelector('#p-trial-status').textContent,/انتهت/);

 window.happyDOM.abort();
});
