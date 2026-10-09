import {createClient} from '@supabase/supabase-js';
import {SUPABASE_URL,SUPABASE_KEY} from './config.js';
const url=import.meta.env.VITE_SUPABASE_URL||SUPABASE_URL,key=import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY||SUPABASE_KEY;
export const db=url&&key?createClient(url,key):null;
export async function rows(table){if(!db)throw Error('Cloud connection is not configured / الاتصال السحابي غير مهيأ');const {data,error}=await db.from(table).select('*');if(error)throw error;return data;}
export async function save(table,record){if(!db)throw Error('Cloud connection is not configured / الاتصال السحابي غير مهيأ');const{error}=await db.from(table).upsert(record);if(error)throw error;}
export async function remove(table,id){const{error}=await db.from(table).delete().eq('id',id);if(error)throw error;}
