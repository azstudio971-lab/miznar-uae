// Run on a trusted machine. Set service-role credentials in the environment, never in Git.
import {createClient} from '@supabase/supabase-js';
import readline from 'node:readline';
const url=process.env.SUPABASE_URL,key=process.env.SUPABASE_SERVICE_ROLE_KEY;
if(!url||!key)throw Error('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in your trusted shell.');
const rl=readline.createInterface({input:process.stdin,output:process.stdout,terminal:true});
const email=await new Promise(resolve=>rl.question('Owner email: ',resolve));
process.stdout.write('Initial password (input hidden): ');rl._writeToOutput=()=>{};
const password=await new Promise(resolve=>rl.once('line',resolve));rl.close();process.stdout.write('\n');
if(password.length<8)throw Error('Password must contain at least eight characters.');
const db=createClient(url,key,{auth:{persistSession:false}});
const {data,error}=await db.auth.admin.createUser({email,password,email_confirm:true});
if(error)throw error;const user=data.user;if(!user)throw Error('Auth user missing');
const {error:roleError}=await db.from('staff_accounts').insert({user_id:user.id,role_key:'super_admin',enabled:true});
if(roleError){await db.auth.admin.deleteUser(user.id);throw roleError;}
console.log('Owner account created. Change the password in Admin → Settings when desired.');
