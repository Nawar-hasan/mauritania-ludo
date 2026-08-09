$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "MAURITANIA LUDO - phone build" -ForegroundColor Cyan

try {
  $health = Invoke-RestMethod -Uri 'http://localhost:3000/api/v1/health' -TimeoutSec 4
  Write-Host "Backend local health: OK" -ForegroundColor Green
} catch {
  Write-Host "Backend is not reachable on localhost:3000." -ForegroundColor Red
  Write-Host "Run start_all_windows.bat first." -ForegroundColor Yellow
  exit 1
}

$vpn = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
  $_.Status -eq 'Up' -and ($_.Name -match 'VPN|Proton|WireGuard|TAP|TUN|Tailscale' -or $_.InterfaceDescription -match 'VPN|Proton|WireGuard|TAP|TUN|Tailscale')
}
if ($vpn) {
  Write-Host "WARNING: An active VPN adapter was detected:" -ForegroundColor Yellow
  $vpn | ForEach-Object { Write-Host " - $($_.Name)" -ForegroundColor Yellow }
  Write-Host "Turn VPN off before building/testing the local phone APK, otherwise the wrong IP can be used." -ForegroundColor Yellow
}

$configs = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object {
  $_.IPv4DefaultGateway -ne $null -and $_.IPv4Address -ne $null -and
  $_.InterfaceAlias -notmatch 'VPN|Proton|WireGuard|TAP|TUN|vEthernet|Docker|WSL|Hyper-V|Virtual|Loopback|Tailscale'
}
$ips = @($configs | ForEach-Object { $_.IPv4Address.IPAddress } | Where-Object { $_ -and $_ -notlike '169.254.*' } | Select-Object -Unique)

if ($ips.Count -eq 0) {
  Write-Host "Could not auto-detect a physical LAN/Wi-Fi IPv4 address." -ForegroundColor Yellow
  $pcIp = Read-Host 'Enter the computer LAN IPv4 address (example 192.168.1.50)'
} else {
  Write-Host "Detected LAN/Wi-Fi addresses:" -ForegroundColor Cyan
  for ($i=0; $i -lt $ips.Count; $i++) { Write-Host " [$($i+1)] $($ips[$i])" }
  $defaultIp = $ips[0]
  $entered = Read-Host "Press Enter to use $defaultIp, or type another LAN IPv4 address"
  $pcIp = if ([string]::IsNullOrWhiteSpace($entered)) { $defaultIp } else { $entered.Trim() }
}

if ([string]::IsNullOrWhiteSpace($pcIp)) { throw 'No IP address was selected.' }

$lanHealth = "http://$pcIp`:3000/api/v1/health"
try {
  $null = Invoke-RestMethod -Uri $lanHealth -TimeoutSec 4
  Write-Host "API through LAN IP: OK ($lanHealth)" -ForegroundColor Green
} catch {
  Write-Host "The API is not reachable through $pcIp on port 3000." -ForegroundColor Red
  Write-Host "Right-click open_firewall_port_3000_as_admin.bat and choose Run as administrator, then retry." -ForegroundColor Yellow
  exit 1
}

Write-Host "Before installing the APK, open this exact URL in the PHONE browser:" -ForegroundColor Cyan
Write-Host $lanHealth -ForegroundColor White
Write-Host "You must see JSON with status=ok. The phone and PC must be on the same Wi-Fi." -ForegroundColor Cyan
$continue = Read-Host 'Type Y after the phone browser test works (or N to stop)'
if ($continue -notmatch '^[Yy]$') { Write-Host 'Build cancelled.'; exit 1 }

Push-Location (Join-Path $root 'mobile')
try {
  flutter clean
  if ($LASTEXITCODE -ne 0) { throw 'flutter clean failed' }
  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
  flutter build apk --debug "--dart-define=API_BASE_URL=http://$pcIp`:3000/api/v1" "--dart-define=SOCKET_URL=http://$pcIp`:3000/matches"
  if ($LASTEXITCODE -ne 0) { throw 'APK build failed' }
  Write-Host "APK READY:" -ForegroundColor Green
  Write-Host (Join-Path (Get-Location) 'build\app\outputs\flutter-apk\app-debug.apk') -ForegroundColor Green
} finally { Pop-Location }
