@echo off
cd /d %~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_mobile_for_phone_windows.ps1"
pause
