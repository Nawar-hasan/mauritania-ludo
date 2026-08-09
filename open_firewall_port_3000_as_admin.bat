@echo off
net session >nul 2>&1
if errorlevel 1 (
  echo Right-click this file and choose Run as administrator.
  pause
  exit /b 1
)
netsh advfirewall firewall delete rule name="Ludo Champion Local API" >nul 2>&1
netsh advfirewall firewall add rule name="Ludo Champion Local API" dir=in action=allow protocol=TCP localport=3000
if errorlevel 1 (
  echo Could not create the firewall rule.
  pause
  exit /b 1
)
echo Port 3000 is now allowed for the local connected phone test.
pause
