import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Window} from 'happy-dom';
import {policies} from '../web/src/policies.js';
import {defaultSlots,validateSlots,greeting} from '../shared/domain.js';
test('web DOM: bilingual navigation, theme choice, greeting and cloud-unavailable state',()=>{
 const window=new Window({url:'https://wudcar.test/preview'});window.document.body.innerHTML='<div id="app"></div>';
 const source=readFileSync('web/src/main.js','utf8').replace(/^import[^\n]+\n/,'');
 const execute=new Function('window','document','location','history','localStorage','db','policies','defaultSlots','validateSlots','greeting','rows','save','remove',source);
 execute(window,window.document,window.location,window.history,window.localStorage,null,policies,defaultSlots,validateSlots,greeting,()=>{},()=>{throw Error('Unexpected write');},()=>{});
 const d=window.document;assert.equal(d.documentElement.dir,'rtl');
 const name=d.querySelector('#preview-name');name.value='راشد';name.dispatchEvent(new window.Event('input'));assert.match(d.querySelector('.clock').textContent,/راشد/);
 d.querySelector('[data-period="night"]').click();assert.match(d.querySelector('#scene img').src,/ultrawide\/night.png$/);
 d.querySelector('#shape').click();assert.match(d.querySelector('#scene img').src,/compact\/night.png$/);
 d.querySelector('#lang').click();assert.equal(d.documentElement.dir,'ltr');
 d.querySelector('a[href="/admin"]').click();assert.equal(d.querySelector('#login button').disabled,true);
 assert.match(d.body.textContent,/Cloud connection is not configured/);
 for(const route of ['privacy','terms','support','delete']){d.querySelector(`a[href="/${route}"]`).click();assert.ok(d.querySelector('h1').textContent.length>0);}
 window.happyDOM.abort();
});
