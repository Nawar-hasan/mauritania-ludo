$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

function Run-Step([string]$Title, [scriptblock]$Action) {
  Write-Host "`n$Title" -ForegroundColor Cyan
  & $Action
  if ($LASTEXITCODE -ne 0) { throw "$Title failed with exit code $LASTEXITCODE" }
}

Write-Host 'Ludo Champion V5 - connected flow hardening and test preparation' -ForegroundColor Yellow
Write-Host "Project: $Root"

if (-not (Test-Path (Join-Path $Root 'backend\package.json'))) { throw 'Copy the V5 patch contents into the Ludo platform root first.' }

Push-Location (Join-Path $Root 'backend')
try {
  Run-Step '[1/4] Re-seeding protected CLASSIC rules and configured content...' { npm run db:seed }
  Run-Step '[2/4] Building backend...' { npm run build }
} finally { Pop-Location }

Push-Location (Join-Path $Root 'admin')
try {
  Run-Step '[3/4] Building administration dashboard...' { npm run build }
} finally { Pop-Location }

Push-Location (Join-Path $Root 'mobile')
try {
  Write-Host "`n[4/4] Preparing connected Flutter application..." -ForegroundColor Cyan
  flutter clean
  if ($LASTEXITCODE -ne 0) { throw 'flutter clean failed' }
  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
  Write-Host 'Running flutter analyze. Existing style warnings are informational and do not block this patch.' -ForegroundColor DarkCyan
  flutter analyze
} finally { Pop-Location }

Write-Host "`nV5 APPLY COMPLETE" -ForegroundColor Green
Write-Host 'Start services with: .\start_all_windows.bat'
Write-Host 'Then run: .\test_v5_connected_flow.ps1'
