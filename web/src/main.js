import './style.css';
import {startPreview} from './preview.js';
import {startAdmin} from './studio.js';
import {policies} from './policies.js';
import {esc} from './ui.js';
const path=location.pathname.replace(/\/$/,'')||'/';
if(path.startsWith('/admin'))startAdmin();
else if(policies[path.slice(1)]){const p=policies[path.slice(1)].ar;document.querySelector('#app').innerHTML=`<main class="legal"><a href="/app">← WudCar</a><h1>${esc(p.title)}</h1>${p.sections.map(([a,b])=>`<h2>${esc(a)}</h2><p>${esc(b)}</p>`).join('')}</main>`;}
else startPreview();
