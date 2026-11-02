/* ALREDFANI RETAIL ERP — Supabase cloud persistence (single-owner first phase) */
(()=>{'use strict';
const URL='https://isvnrpylwgenkqaknmhx.supabase.co';
const KEY='sb_publishable_zie0Uf87bYwjATeIwtmegQ_PTa5WChb';
const client=window.supabase.createClient(URL,KEY);
let erp=null,workspaceId=null,ready=false,timer=null,busy=false;
const $=id=>document.getElementById(id);
const status=t=>{const e=$('cloudStatus');if(e)e.textContent=t};
const message=t=>{const e=$('cloudAuthMessage');if(e)e.textContent=t};
const fail=e=>{console.error(e);message(e?.message||'تعذر الاتصال. تحقق من إعدادات Supabase ثم حاول مجدداً.');status('تعذر الاتصال')};
async function getWorkspace(userId){
 const {data,error}=await client.from('workspace_members').select('workspace_id,role').eq('user_id',userId).order('created_at',{ascending:true}).limit(1).maybeSingle();
 if(error)throw error;if(!data)throw new Error('هذا الحساب غير مرتبط بمساحة عمل. راجع مسؤول النظام.');
 if(!['owner','manager'].includes(data.role))throw new Error('هذه النسخة التجريبية السحابية مخصصة حالياً للمالك أو المدير.');
 return data.workspace_id;
}
async function loadCloud(){
 const {data,error}=await client.from('workspace_snapshots').select('payload,updated_at').eq('workspace_id',workspaceId).maybeSingle();
 if(error)throw error;
 if(data?.payload&&typeof data.payload==='object'){erp.replaceData(data.payload);message('تم تحميل بيانات مساحة العمل من السحابة.');}
 else {
  const local=erp.getData();
  const {error:saveError}=await client.from('workspace_snapshots').insert({workspace_id:workspaceId,payload:local});
  if(saveError)throw saveError;
  message('تم إنشاء النسخة السحابية الأولى باستخدام بيانات هذا المتصفح.');
 }
 ready=true;status('متصل بالسحابة');$('cloudAuth').style.display='none';
}
async function signIn(email,password){
 const {data,error}=await client.auth.signInWithPassword({email,password});
 if(error)throw error;
 workspaceId=await getWorkspace(data.user.id);
 await loadCloud();
}
function queueSave(data){
 if(!ready||!workspaceId)return;
 clearTimeout(timer);
 timer=setTimeout(async()=>{
  if(busy)return;
  busy=true;
  try{
   const {data:userData}=await client.auth.getUser();
   if(!userData?.user)throw new Error('انتهت جلسة الدخول. سجّل الدخول مجدداً.');
   const {error}=await client.from('workspace_snapshots').upsert({workspace_id:workspaceId,payload:data,updated_by:userData.user.id,updated_at:new Date().toISOString()},{onConflict:'workspace_id'});
   if(error)throw error;
   status('تم الحفظ سحابياً');
  }catch(e){fail(e);status('تعذر الحفظ السحابي');}
  finally{busy=false;}
 },700);
}
async function start(api){
 erp=api;
 $('cloudLoginForm').addEventListener('submit',async e=>{
  e.preventDefault();const button=$('cloudLoginButton');button.disabled=true;button.textContent='جارٍ التحقق...';
  try{await signIn($('cloudEmail').value.trim(),$('cloudPassword').value);}
  catch(err){fail(err);}
  finally{button.disabled=false;button.textContent='دخول آمن';}
 });
 $('cloudLogoutButton').addEventListener('click',async()=>{ready=false;workspaceId=null;await client.auth.signOut();$('cloudAuth').style.display='flex';status('تم تسجيل الخروج');});
 const {data:{session}}=await client.auth.getSession();
 if(session){try{workspaceId=await getWorkspace(session.user.id);await loadCloud();}catch(e){fail(e);}}
 else {$('cloudAuth').style.display='flex';status('بانتظار تسجيل الدخول');}
 client.auth.onAuthStateChange((event)=>{if(event==='SIGNED_OUT'){ready=false;workspaceId=null;$('cloudAuth').style.display='flex';status('تم تسجيل الخروج');}});
}
window.AlredfaniCloud={start,queueSave};
})();