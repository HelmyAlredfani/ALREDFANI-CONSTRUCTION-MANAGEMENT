<?php
declare(strict_types=1);
$cf=__DIR__.'/config/local.php';if(!is_file($cf)){http_response_code(500);exit('أنشئ config/local.php من local.example.php أولاً');}
$c=require $cf;date_default_timezone_set($c['app']['timezone']??'Asia/Aden');session_name('alredfani_retail');session_set_cookie_params(['httponly'=>true,'secure'=>!empty($_SERVER['HTTPS']),'samesite'=>'Lax']);if(session_status()!==PHP_SESSION_ACTIVE)session_start();
try{$d=$c['db'];$pdo=new PDO("mysql:host={$d['host']};dbname={$d['name']};charset=utf8mb4",$d['user'],$d['pass'],[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC,PDO::ATTR_EMULATE_PREPARES=>false]);}catch(Throwable $e){http_response_code(500);exit('فشل الاتصال بقاعدة البيانات. راجع الإعدادات.');}
function h($v):string{return htmlspecialchars((string)$v,ENT_QUOTES|ENT_SUBSTITUTE,'UTF-8');}
function token():string{if(empty($_SESSION['csrf']))$_SESSION['csrf']=bin2hex(random_bytes(32));return $_SESSION['csrf'];}
function check_token():void{if($_SERVER['REQUEST_METHOD']==='POST'&&!hash_equals($_SESSION['csrf']??'',$_POST['_token']??'')){http_response_code(419);exit('رمز الحماية غير صالح. أعد تحميل الصفحة.');}}
function need_login():void{if(empty($_SESSION['u'])){header('Location: index.php?p=login');exit;}}
function manager():bool{return in_array($_SESSION['u']['role']??'', ['owner','manager','system_admin','supervisor'],true);}
function audit_event(PDO $pdo,string $a,string $e='',int $id=0):void{$u=$_SESSION['u']??null;if(!$u)return;$q=$pdo->prepare('INSERT INTO audit_logs(workspace_id,user_id,action,entity,entity_id) VALUES(?,?,?,?,?)');$q->execute([$u['workspace_id'],$u['id'],$a,$e?:null,$id?:null]);}
function cash($n):string{return number_format((float)$n,2);}
