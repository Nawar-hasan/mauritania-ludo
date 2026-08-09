@echo off
cd /d %~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_local_windows.ps1"
if errorlevel 1 (
  echo.
  echo SETUP FAILED. Read the first red error above.
  pause
  exit /b 1
)
pause
