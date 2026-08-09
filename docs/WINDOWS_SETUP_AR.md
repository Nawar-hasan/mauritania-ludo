# تشغيل الباكند ولوحة التحكم على Windows

## البرامج المطلوبة

- Node.js 22 أو أحدث.
- Docker Desktop.
- Git اختياري.

## 1. التجهيز لأول مرة بالطريقة الأسهل

شغّل الملف التالي من المجلد الرئيسي:

```text
setup_local_windows.bat
```

يتحقق السكربت من Node وDocker، وينشئ أسرار JWT محلية عشوائية، ثم يثبت الحزم ويطبق قاعدة البيانات ويجهز لوحة التحكم.

بعد نجاحه شغّل:

```text
start_all_windows.bat
```

## 2. التشغيل اليدوي للباكند

```powershell
cd backend
Copy-Item .env.example .env
npm install
npm run db:generate
npm run db:deploy
npm run db:seed
npm run start:dev
```

بعد النجاح افتح:

```text
http://localhost:3000/docs
```

## 3. تشغيل لوحة التحكم

افتح PowerShell ثانية داخل المشروع:

```powershell
cd admin
Copy-Item .env.example .env.local
npm install
npm run dev
```

افتح:

```text
http://localhost:3001
```

استخدم بيانات المدير الموجودة في ملف `backend/.env`. غيّر كلمة المرور قبل أي نشر خارجي.

## أوامر التحقق

من داخل `backend`:

```powershell
npm run build
npm test
```

ومن داخل `admin`:

```powershell
npm run build
```


## اختبار الهاتف على الشبكة المحلية

قبل بناء APK للهاتف الحقيقي، شغّل `open_firewall_port_3000_as_admin.bat` بزر الفأرة اليمين ثم **Run as administrator** مرة واحدة. بعد ذلك شغّل `build_mobile_for_phone_windows.bat` وأدخل IPv4 للكمبيوتر.

## التحقق السريع

بعد فتح الباكند ولوحة التحكم شغّل `check_services_windows.bat`، ثم `run_smoke_test_windows.bat`.
