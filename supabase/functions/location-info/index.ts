import {headers,json} from '../_shared/http.ts';
const cache=new Map<string,{expires:number,value:unknown}>();
Deno.serve(async request=>{
 if(request.method==='OPTIONS')return new Response(null,{headers:headers(request)});
 if(request.method!=='GET')return json(request,405,{error:'Method not allowed'});
 const u=new URL(request.url),lat=Number(u.searchParams.get('lat')),lon=Number(u.searchParams.get('lon')),method=Number(u.searchParams.get('method')||8),timezone=u.searchParams.get('timezone')||'Asia/Dubai';
 if(!u.searchParams.has('lat')||!u.searchParams.has('lon')||!Number.isFinite(lat)||!Number.isFinite(lon)||Math.abs(lat)>90||Math.abs(lon)>180||![3,4,8,16].includes(method))return json(request,400,{error:'Invalid location'});
 try{new Intl.DateTimeFormat('en',{timeZone:timezone}).format();}catch{return json(request,400,{error:'Invalid timezone'});}
 const key=[lat.toFixed(2),lon.toFixed(2),timezone,method].join('|'),hit=cache.get(key);if(hit&&hit.expires>Date.now())return json(request,200,hit.value);
 const day=new Intl.DateTimeFormat('en-GB',{timeZone:timezone,day:'2-digit',month:'2-digit',year:'numeric'}).format(new Date()).replaceAll('/','-');
 const result=await Promise.allSettled([
  fetch(`https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=${lat.toFixed(2)}&lon=${lon.toFixed(2)}`,{headers:{'User-Agent':'WudCar/1.1.1 https://wudcar.netlify.app (az.studio971@gmail.com)'},signal:AbortSignal.timeout(12000)}).then(async r=>{if(!r.ok)throw Error('Weather unavailable');const d=await r.json(),s=d.properties.timeseries[0];return {temperature:s.data.instant.details.air_temperature,symbol:s.data.next_1_hours?.summary.symbol_code||'cloudy',updated_at:d.properties.meta.updated_at,attribution:'MET Norway',license:'https://creativecommons.org/licenses/by/4.0/',source:'https://www.met.no/'};}),
  fetch(`https://api.aladhan.com/v1/timings/${day}?latitude=${lat.toFixed(2)}&longitude=${lon.toFixed(2)}&method=${method}&timezonestring=${encodeURIComponent(timezone)}`,{signal:AbortSignal.timeout(12000)}).then(async r=>{if(!r.ok)throw Error('Prayer unavailable');const d=await r.json();if(d.code!==200)throw Error('Prayer unavailable');return Object.fromEntries(Object.entries(d.data.timings).map(([k,v])=>[k,String(v).slice(0,5)]));})
 ]);
 const value={weather:result[0].status==='fulfilled'?result[0].value:null,prayer:result[1].status==='fulfilled'?result[1].value:null,day,timezone,prayer_source:'AlAdhan',method};
 if(cache.size>500)cache.clear();cache.set(key,{expires:Date.now()+600000,value});return json(request,200,value);
});
