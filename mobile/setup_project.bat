@echo off
setlocal
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter was not found in PATH.
  echo Install Flutter, then reopen this folder and run this file again.
  pause
  exit /b 1
)
flutter create . --platforms=android,ios,web
if errorlevel 1 goto :error
flutter pub get
if errorlevel 1 goto :error
echo.
echo Project setup completed successfully.
echo Run: flutter run
pause
exit /b 0
:error
echo.
echo Setup failed. Review the error above.
pause
exit /b 1
