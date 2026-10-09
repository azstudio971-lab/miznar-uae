export const periods=['dawn','morning','sunset','night'];
export const defaultSlots=[{period:'dawn',start:300,end:420},{period:'morning',start:420,end:1020},{period:'sunset',start:1020,end:1140},{period:'night',start:1140,end:300}];
export function validateSlots(slots){
 if(!Array.isArray(slots)||slots.length!==4)throw Error('Four periods are required');
 const seen=new Set(),minutes=new Uint8Array(1440);
 for(const s of slots){if(!periods.includes(s.period)||seen.has(s.period))throw Error('Invalid or duplicate period');seen.add(s.period);
 if(!Number.isInteger(s.start)||!Number.isInteger(s.end)||s.start<0||s.end<0||s.start>=1440||s.end>=1440||s.start===s.end)throw Error('Invalid time range');
 for(let m=s.start;m!==s.end;m=(m+1)%1440){if(minutes[m]++)throw Error('Schedule overlap');}}
 if(minutes.some(v=>v!==1))throw Error('Schedule gap');return true;
}
export function periodAt(minute,slots=defaultSlots){validateSlots(slots);return slots.find(s=>s.start<s.end?minute>=s.start&&minute<s.end:minute>=s.start||minute<s.end)?.period;}
export function greeting(name='',hour=12,lang='ar'){const clean=String(name).trim().slice(0,40);return (lang==='ar'?(hour<12?'صباح الخير':'مساء الخير'):(hour<12?'Good morning':'Good evening'))+(clean?`، ${clean}`:'');}
export function layoutFor(width,height){if(width<=0||height<=0)throw Error('Invalid viewport');return width/height>=1.9?'ultrawide':'compact';}
export function validateMediaURL(value){try{const u=new URL(value);return u.protocol==='https:'&&!u.username&&!u.password;}catch{return false;}}
export function parseM3U(text,base){let meta=null,items=[];for(const raw of text.split(/\r?\n/)){const line=raw.trim();if(line.startsWith('#EXTINF:')){const attr=k=>line.match(new RegExp(k+'="([^"]*)"'))?.[1]||'';meta={name:line.slice(line.indexOf(',')+1)||attr('tvg-name'),group:attr('group-title'),logo:attr('tvg-logo')};}else if(line&&!line.startsWith('#')){try{const url=new URL(line,base).href;if(validateMediaURL(url))items.push({...meta,name:meta?.name||'Media',url});}catch{}meta=null;}}return items;}
