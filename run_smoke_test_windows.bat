@echo off
cd /d %~dp0backend
set API_URL=http://localhost:3000/api/v1
call npm run smoke
pause
