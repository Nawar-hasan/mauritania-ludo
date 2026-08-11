param(
  [Parameter(Mandatory=$true)][string]$BackendUrl
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$mobile = Join-Path $root 'mobile'
$api = $BackendUrl.TrimEnd('/') + '/api/v1'
$socket = $BackendUrl.TrimEnd('/') + '/matches'
Push-Location $mobile
try {
  flutter clean
  flutter pub get
  flutter build web --release --dart-define=API_BASE_URL=$api --dart-define=SOCKET_URL=$socket
  Write-Host "WEB READY: $mobile\build\web" -ForegroundColor Green
} finally { Pop-Location }
