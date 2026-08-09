MAURITANIA LUDO V6

1) أغلق نوافذ Backend/Admin.
2) انسخ كل محتويات هذا التحديث إلى C:\ludo_platform_v3_connected واختر Replace files.
3) افتح PowerShell في C:\ludo_platform_v3_connected.
4) نفذ:
   Set-ExecutionPolicy -Scope Process Bypass
   Y
   Unblock-File .\apply_v6_brand_network_fix.ps1
   .\apply_v6_brand_network_fix.ps1
5) شغّل .\start_all_windows.bat
6) أوقف VPN على الكمبيوتر قبل اختبار الهاتف.
7) شغّل .\build_mobile_for_phone_windows.bat. السكربت سيكتشف IP الشبكة ويطلب منك اختبار رابط /health من متصفح الهاتف قبل أن يبني APK.

إذا لم يفتح رابط health على الهاتف، شغّل open_firewall_port_3000_as_admin.bat كمسؤول ثم أعد الاختبار.
