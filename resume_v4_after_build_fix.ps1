$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

function Run-Step([string]$Title, [scriptblock]$Action) {
  Write-Host "`n$Title" -ForegroundColor Cyan
  & $Action
  if ($LASTEXITCODE -ne 0) { throw "$Title failed with exit code $LASTEXITCODE" }
}

Write-Host "Ludo Champion V4 - resume after TypeScript build fix" -ForegroundColor Yellow
Write-Host "Project: $Root"

if (-not (Test-Path (Join-Path $Root 'backend\package.json'))) { throw 'Copy this patch into the Ludo platform root first.' }

Push-Location (Join-Path $Root 'backend')
try {
  Run-Step '[1/3] Building the backend...' { npm run build }
} finally { Pop-Location }

Push-Location (Join-Path $Root 'admin')
try {
  Run-Step '[2/3] Building the administration dashboard...' { npm run build }
} finally { Pop-Location }

Push-Location (Join-Path $Root 'mobile')
try {
  Write-Host "`n[3/3] Preparing Flutter packages..." -ForegroundColor Cyan
  flutter clean
  if ($LASTEXITCODE -ne 0) { throw 'flutter clean failed' }
  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
  Write-Host 'Running flutter analyze (informational warnings are allowed)...' -ForegroundColor DarkCyan
  flutter analyze
} finally { Pop-Location }

Write-Host "`nV4 RESUME COMPLETE" -ForegroundColor Green
Write-Host 'Run .\start_all_windows.bat next.'
Write-Host 'Then open http://localhost:3001 and http://localhost:3000/docs'
