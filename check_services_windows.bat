@echo off
setlocal
powershell -NoProfile -Command "$ErrorActionPreference='SilentlyContinue'; $h=Invoke-RestMethod http://localhost:3000/api/v1/health; if($h){Write-Host 'API HEALTH: OK' -ForegroundColor Green}else{exit 1}"
if errorlevel 1 (
  echo API is not reachable at http://localhost:3000/api/v1/health
  pause
  exit /b 1
)
powershell -NoProfile -Command "try{(Invoke-WebRequest http://localhost:3001 -UseBasicParsing).StatusCode | Out-Null; Write-Host 'ADMIN: OK' -ForegroundColor Green}catch{exit 1}"
if errorlevel 1 echo Admin dashboard is not reachable yet at http://localhost:3001
pause
