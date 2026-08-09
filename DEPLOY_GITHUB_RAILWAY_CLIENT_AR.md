# MAURITANIA LUDO — GitHub + Railway + Android + iOS

هذا الدليل للنسخة التجريبية السحابية. لا ترفع ملفات `.env` أو كلمات المرور أو مفاتيح الدفع إلى GitHub.

## 0) ما الذي سيرتفع إلى GitHub؟
المستودع واحد Monorepo ويحتوي:
- `backend/` — NestJS + Prisma
- `admin/` — Next.js لوحة التحكم
- `mobile/` — Flutter
- `docs/` وملفات النشر

لا يتم رفع `node_modules`, `.next`, `dist`, `build`, `.env`, مفاتيح Android/iOS، أو uploads المحلية.

---

## 1) إنشاء مستودع GitHub خاص
1. افتح GitHub > New repository.
2. الاسم المقترح: `mauritania-ludo`.
3. اختر **Private**.
4. لا تضف README أو .gitignore من GitHub لأن المشروع يحتويهما.
5. اضغط Create repository.
6. انسخ رابط HTTPS مثل:
   `https://github.com/USERNAME/mauritania-ludo.git`

### الرفع من Windows PowerShell
داخل مجلد المشروع:
```powershell
cd C:\ludo_platform_v3_connected
Set-ExecutionPolicy -Scope Process Bypass
Y
Unblock-File .\release_tools\publish_to_github_windows.ps1
.\release_tools\publish_to_github_windows.ps1 -RepoUrl "https://github.com/USERNAME/mauritania-ludo.git"
```
إذا طلب GitHub تسجيل الدخول، أكمل تسجيل الدخول من نافذة المتصفح/Git Credential Manager.

### بديل يدوي
```powershell
git init
git branch -M main
git add .
git status
git commit -m "Prepare MAURITANIA LUDO cloud staging"
git remote add origin https://github.com/USERNAME/mauritania-ludo.git
git push -u origin main
```
إذا قال `remote origin already exists`:
```powershell
git remote set-url origin https://github.com/USERNAME/mauritania-ludo.git
git push -u origin main
```

---

## 2) إنشاء مشروع Railway
1. افتح Railway > New Project > Empty Project.
2. اسم المشروع: `MAURITANIA-LUDO-STAGING`.
3. أضف PostgreSQL من `+ New` > Database > PostgreSQL.
4. أضف Redis من `+ New` > Database > Redis.

## 3) نشر Backend
1. داخل المشروع أضف Empty Service وسمّه `Backend`.
2. Settings > Source > Connect Repo واختر مستودع `mauritania-ludo`.
3. Settings > Root Directory = `/backend`.
4. Settings > Config as Code path = `/backend/railway.toml`.
5. Variables: استخدم `backend/.env.railway.example` كمرجع.
6. أهم الربط:
   - `DATABASE_URL=${{Postgres.DATABASE_URL}}`
   - `REDIS_URL=${{Redis.REDIS_URL}}`
7. أنشئ سري JWT مختلفين وطويلين (32+ حرف).
8. ضع بيانات admin تجريبية قوية.
9. في أول نشر يمكن إبقاء `CORS_ORIGINS=http://localhost:3001` مؤقتاً.
10. Deploy ثم Settings > Networking > Generate Domain.
11. سجل رابط Backend، مثال `https://backend-production-xxxx.up.railway.app`.
12. افتح `/api/v1/health` و`/docs` للتأكد.

ملاحظة: `railway.toml` يشغّل migrations ثم seed. Seed في هذه الحزمة آمن افتراضياً ولا يعيد ضبط المحتوى الموجود إلا إذا فعّلت `SEED_OVERWRITE_DEFAULTS=true`، ولا يعيد كلمة مرور المدير إلا إذا فعّلت `SEED_RESET_ADMIN_PASSWORD=true`.

## 4) Volume للصور والملفات
لأن filesystem العادي في Railway غير دائم:
1. Backend service > Volumes > Add Volume.
2. Mount path = `/app/uploads`.
3. Backend variable `UPLOAD_DIR=/app/uploads`.
هذا يحافظ على صور المستخدمين والعناصر بعد إعادة النشر.

## 5) نشر لوحة التحكم Admin
1. أضف Empty Service جديد باسم `Admin`.
2. اربطه بنفس GitHub repo.
3. Root Directory = `/admin`.
4. Config as Code path = `/admin/railway.toml`.
5. Variables:
   `NEXT_PUBLIC_API_URL=https://BACKEND-DOMAIN/api/v1`
6. Deploy.
7. Generate Domain للـAdmin.
8. سجل الرابط، مثال `https://admin-production-xxxx.up.railway.app`.
9. ارجع Backend > Variables وعدّل:
   - `CORS_ORIGINS=https://ADMIN-DOMAIN`
   - `PUBLIC_APP_URL=https://ADMIN-DOMAIN`
   - `PUBLIC_API_URL=https://BACKEND-DOMAIN`
10. Deploy التغييرات.
11. اختبر تسجيل الدخول إلى لوحة التحكم.

## 6) بناء APK للعميل على Windows
من جذر المشروع:
```powershell
Set-ExecutionPolicy -Scope Process Bypass
Y
Unblock-File .\release_tools\build_android_from_railway.ps1
.\release_tools\build_android_from_railway.ps1 -BackendUrl "https://BACKEND-DOMAIN"
```
الملف:
`mobile\build\app\outputs\flutter-apk\app-release.apk`

هذه نسخة Release أسرع من Debug ومناسبة لإرسالها للعميل للاختبار. التوقيع الحالي ما زال Debug signing؛ قبل Google Play ننشئ keystore إنتاجياً ولا نضعه في GitHub.

### بناء APK من GitHub بدون جهازك
في GitHub repository > Settings > Secrets and variables > Actions > Variables أضف:
- `API_BASE_URL=https://BACKEND-DOMAIN/api/v1`
- `SOCKET_URL=https://BACKEND-DOMAIN/matches`
ثم Actions > `Build Android Client APK` > Run workflow. بعد النجاح نزّل Artifact.

## 7) نسخة iPhone
لا يمكن إنشاء IPA قابل للتثبيت/ TestFlight من Windows وحده. تحتاج macOS + Xcode، وحساب Apple Developer وتوقيع صحيح.

على Mac:
```bash
cd /path/to/mauritania-ludo
./release_tools/prepare_ios_on_mac.sh https://BACKEND-DOMAIN
```
ثم:
1. افتح `mobile/ios/Runner.xcworkspace` في Xcode.
2. Runner > Signing & Capabilities > اختر Team.
3. ضع Bundle ID فريداً مثل `com.mauritanialudo.app`.
4. اسم العرض `MAURITANIA LUDO`.
5. نفّذ:
```bash
cd mobile
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://BACKEND-DOMAIN/api/v1 \
  --dart-define=SOCKET_URL=https://BACKEND-DOMAIN/matches
```
6. ارفع IPA إلى App Store Connect/TestFlight من Xcode أو Transporter.
7. أضف بريد العميل كـ Tester في TestFlight.

## 8) ماذا نرسل للعميل؟
- Android: `app-release.apk` مباشرة.
- iPhone: دعوة TestFlight، وليس إرسال IPA عشوائياً، إلا إذا كان لديك Ad Hoc provisioning ومسجل UDID للجهاز.
- رابط لوحة التحكم لا ترسله إلا إذا كان العميل يحتاج دور إدارة؛ أنشئ له حساباً محدود الصلاحية بدلاً من superadmin.

## 9) بعد أول اختبار للعميل
دوّن الملاحظات تحت 4 مجموعات:
1. UI/UX واللغة.
2. قوانين وحركة لودو.
3. أداء واتصال ومباريات مباشرة.
4. Wallet/Store/Payments/Admin.
ثم نفذ التعديلات على branch جديد وليس مباشرة على `main`.

## 10) قواعد أمان مهمة
- GitHub Private.
- لا ترفع `.env`.
- لا ترفع `SEED_ADMIN_PASSWORD` الحقيقي أو JWT secrets.
- لا ترفع مفاتيح الدفع.
- لا تفعّل `real_money_enabled` قبل المراجعة القانونية/التشغيلية المناسبة.
- لا تستخدم superadmin للعميل.
