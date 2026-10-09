import { service } from './http.ts';
export async function authenticate(request: Request) {
 const jwt=request.headers.get('Authorization')?.match(/^Bearer (.+)$/i)?.[1];
 if(!jwt)throw new Error('Authentication required');
 const db=service();const {data:{user},error}=await db.auth.getUser(jwt);
 if(error||!user)throw new Error('Session invalid');
 const {data:profile}=await db.from('profiles').select('account_status').eq('user_id',user.id).maybeSingle();
 if(profile?.account_status==='suspended')throw new Error('Account unavailable');
 return {db,user,jwt};
}
