# ALREDFANI RETAIL ERP — GitHub Pages

هذه نسخة واجهة ثابتة منفصلة عن تطبيق PHP الأصلي. تعمل على GitHub Pages ولا تحتاج PHP أو MySQL.

## النشر
1. من المستودع افتح Settings ثم Pages.
2. في Build and deployment اختر GitHub Actions كمصدر.
3. افتح Actions وشغّل Deploy Retail ERP to GitHub Pages، أو ادفع تحديثاً إلى مجلد retail-erp-pages.
4. بعد نجاح workflow سيظهر رابط الموقع في Settings → Pages. الرابط المتوقع لمستودع مشروعك:
   https://helmyalredfani.github.io/ALREDFANI-CONSTRUCTION-MANAGEMENT/

## الوظائف المتاحة محلياً
- واجهة عربية RTL متجاوبة.
- إضافة منتجات وأرصدة افتتاحية.
- نقطة بيع محلية وتسجيل الفواتير وخصم المخزون.
- سجل المبيعات ومؤشرات إجمالية.
- تصدير واستعادة نسخة JSON.

## قيود مهمة
- البيانات في Local Storage على الجهاز والمتصفح الحالي فقط.
- لا توجد مصادقة أو صلاحيات مستخدمين حقيقية.
- لا توجد قاعدة بيانات مشتركة أو تزامن بين الأجهزة والفروع.
- لا يوجد تحقق خادمي؛ يمكن تعديل بيانات المتصفح، لذلك لا تعتمد عليها لمحاسبة متجر حقيقي.
- النسخة الأصلية PHP/MySQL في retail-erp/ لم يتم حذفها أو استبدالها.

## البدائل اللازمة للوظائف الكاملة
- MySQL مركزي: Supabase PostgreSQL أو Firebase Firestore.
- تسجيل الدخول: Supabase Auth أو Firebase Authentication.
- التحقق من البيع والمخزون والمعاملات: Supabase Edge Functions أو Firebase Cloud Functions.
- عزل المنشآت والفروع والصلاحيات: سياسات Row Level Security في Supabase أو Firestore Security Rules.
- الصور والمرفقات: Supabase Storage أو Firebase Storage.
- التقارير والنسخ الاحتياطي: قاعدة بيانات سحابية مع سياسات نسخ احتياطي.

لا تضع كلمات مرور أو مفاتيح سرية في ملفات JavaScript المنشورة. يلزم تصميم الخادم وقواعد الصلاحيات قبل حفظ بيانات حقيقية.
