@echo off
cd /d %~dp0mobile
call flutter clean
if errorlevel 1 goto :error
call flutter pub get
if errorlevel 1 goto :error
call flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1 --dart-define=SOCKET_URL=http://10.0.2.2:3000/matches
if errorlevel 1 goto :error
echo APK: %CD%\build\app\outputs\flutter-apk\app-debug.apk
pause
exit /b 0
:error
pause
exit /b 1
