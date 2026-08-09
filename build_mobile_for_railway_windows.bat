@echo off
setlocal
cd /d %~dp0mobile
set /p API_HOST=Enter the Railway API host without a trailing slash, for example https://api-example.up.railway.app: 
if "%API_HOST%"=="" goto :error
call flutter clean
if errorlevel 1 goto :error
call flutter pub get
if errorlevel 1 goto :error
call flutter build apk --release --dart-define=API_BASE_URL=%API_HOST%/api/v1 --dart-define=SOCKET_URL=%API_HOST%/matches
if errorlevel 1 goto :error
echo APK: %CD%\build\app\outputs\flutter-apk\app-release.apk
pause
exit /b 0
:error
echo Build failed or no Railway host was entered.
pause
exit /b 1
