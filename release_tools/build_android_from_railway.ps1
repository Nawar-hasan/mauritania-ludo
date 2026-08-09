param(
  [Parameter(Mandatory=$true)][string]$BackendUrl
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$mobile = Join-Path $root 'mobile'
$backend = $BackendUrl.TrimEnd('/')
$api = "$backend/api/v1"
$socket = "$backend/matches"
Write-Host "Building MAURITANIA LUDO Android release" -ForegroundColor Cyan
Write-Host "API: $api"
Write-Host "Socket: $socket"
Set-Location $mobile
flutter clean
if ($LASTEXITCODE -ne 0) { throw 'flutter clean failed' }
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
flutter build apk --release --dart-define="API_BASE_URL=$api" --dart-define="SOCKET_URL=$socket"
if ($LASTEXITCODE -ne 0) { throw 'APK build failed' }
$apk = Join-Path $mobile 'build\app\outputs\flutter-apk\app-release.apk'
Write-Host "APK READY: $apk" -ForegroundColor Green
