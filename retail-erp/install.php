<?php
declare(strict_types=1);
require __DIR__.'/bootstrap.php';
$usersCount=(int)$pdo->query('SELECT COUNT(*) FROM users')->fetchColumn();
$error=''; $created=false;
$values=['workspace'=>'ALREDFANI RETAIL ERP','branch'=>'الفرع الرئيسي','name'=>'مدير النظام','username'=>'alredfani'];
if($_SERVER['REQUEST_METHOD']==='POST'){
 check_token();
 if($usersCount>0){$error='تم إعداد النظام مسبقاً. احذف install.php وسجّل الدخول.';}
 else{
  foreach($values as $key=>$default){$values[$key]=trim((string)($_POST[$key]??$default));}
  $password=(string)($_POST['password']??'');
  if(!$values['workspace']||!$values['branch']||!$values['name']||strlen($values['username'])<3||strlen($password)<10){$error='أكمل الحقول، واجعل اسم المستخدم 3 أحرف على الأقل وكلمة المرور 10 أحرف على الأقل.';}
  else{
   try{
    $pdo->beginTransaction();
    $q=$pdo->prepare('INSERT INTO workspaces(name,slug) VALUES(?,?)');$q->execute([$values['workspace'],'ws-'.bin2hex(random_bytes(8))]);$workspaceId=(int)$pdo->lastInsertId();
    $q=$pdo->prepare('INSERT INTO branches(workspace_id,name,code,is_default) VALUES(?,?,?,1)');$q->execute([$workspaceId,$values['branch'],'MAIN']);$branchId=(int)$pdo->lastInsertId();
    $q=$pdo->prepare("INSERT INTO users(workspace_id,branch_id,name,username,password_hash,role,status) VALUES(?,?,?,?,?,'owner','active')");
    $q->execute([$workspaceId,$branchId,$values['name'],$values['username'],password_hash($password,PASSWORD_DEFAULT)]);
    $pdo->commit();$created=true;
   }catch(Throwable $e){if($pdo->inTransaction())$pdo->rollBack();$error='تعذر إكمال التهيئة. تحقق من قاعدة البيانات ثم أعد المحاولة.';}
  }
 }
}
?>
<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex,nofollow"><link rel="stylesheet" href="assets/app.css"><title>تهيئة ALREDFANI RETAIL ERP</title></head>
<body class="center"><section class="card narrow"><h1>تهيئة ALREDFANI RETAIL ERP</h1>
<?php if($created):?><div class="alert good">تم إنشاء مساحة العمل والفرع وحساب المالك بصلاحية كاملة.</div><p>اسم المستخدم: <b><?=h($values['username'])?></b></p><p class="muted">احذف ملف install.php من الاستضافة فوراً، ثم افتح صفحة تسجيل الدخول.</p><a class="btn" href="index.php?p=login">تسجيل الدخول</a>
<?php elseif($usersCount>0):?><div class="alert">النظام مهيأ بالفعل. احذف ملف install.php من الاستضافة.</div><a class="btn" href="index.php?p=login">الدخول</a>
<?php else:?><?php if($error):?><div class="alert bad"><?=h($error)?></div><?php endif;?>
<p class="muted">أنشئ حساب المالك الأول. كلمة المرور تُخزّن مشفّرة داخل قاعدة البيانات ولا تُكتب في ملفات المصدر.</p>
<form method="post" autocomplete="off"><input type="hidden" name="_token" value="<?=h(token())?>">
<label>اسم المنشأة<input name="workspace" required maxlength="160" value="<?=h($values['workspace'])?>"></label>
<label>الفرع الرئيسي<input name="branch" required maxlength="160" value="<?=h($values['branch'])?>"></label>
<label>اسم المدير<input name="name" required maxlength="160" value="<?=h($values['name'])?>"></label>
<label>اسم المستخدم<input name="username" required minlength="3" maxlength="80" value="<?=h($values['username'])?>" autocomplete="username"></label>
<label>كلمة المرور<input type="password" name="password" required minlength="10" autocomplete="new-password"></label>
<button class="btn">إنشاء حساب المدير</button></form><?php endif;?></section></body></html>