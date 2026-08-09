@echo off
cd /d %~dp0
where docker >nul 2>nul || (echo Docker is not installed.& pause & exit /b 1)
docker compose up -d || (echo Docker Desktop is not running.& pause & exit /b 1)
echo.
echo NOTE: For phone testing, disable VPN on this computer.
start "MAURITANIA LUDO API" cmd /k "cd /d %~dp0backend && npm run start:dev"
start "MAURITANIA LUDO Admin" cmd /k "cd /d %~dp0admin && npm run dev"
echo API and Admin were opened in two separate windows.
echo Swagger: http://localhost:3000/docs
echo Admin:   http://localhost:3001
echo Wait until both windows say they are ready before testing the mobile app.
pause
