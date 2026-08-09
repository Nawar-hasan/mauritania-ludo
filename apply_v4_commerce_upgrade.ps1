$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

function Run-Step([string]$Title, [scriptblock]$Action) {
  Write-Host "`n$Title" -ForegroundColor Cyan
  & $Action
  if ($LASTEXITCODE -ne 0) { throw "$Title failed with exit code $LASTEXITCODE" }
}

Write-Host "Ludo Champion V4 commerce/progression upgrade" -ForegroundColor Yellow
Write-Host "Project: $Root"

if (-not (Test-Path (Join-Path $Root 'backend\package.json'))) { throw 'Run this script from the Ludo platform root after copying the upgrade files.' }
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker is not installed or is not available in PATH.' }
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { throw 'Node.js/npm is not installed or is not available in PATH.' }
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Flutter is not installed or is not available in PATH.' }

Run-Step '[1/8] Starting PostgreSQL and Redis...' { docker compose up -d postgres redis }

$BackupDir = Join-Path $Root 'backups'
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
$Stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$BackupFile = Join-Path $BackupDir "pre_v4_$Stamp.sql"
Write-Host "`n[2/8] Creating a database backup..." -ForegroundColor Cyan
$backupCommand = "docker compose exec -T postgres pg_dump -U ludo -d ludo > `"$BackupFile`""
cmd.exe /d /c $backupCommand
if ($LASTEXITCODE -ne 0) {
  Write-Warning 'Database backup failed. The upgrade was stopped before migrations.'
  throw 'Backup failed'
}
Write-Host "Backup: $BackupFile" -ForegroundColor Green

Push-Location (Join-Path $Root 'backend')
try {
  Run-Step '[3/8] Generating Prisma client...' { npm run db:generate }
  Run-Step '[4/8] Applying the non-destructive commerce migration...' { npm run db:deploy }
  Run-Step '[5/8] Seeding default rules, levels, stages, styles and payment methods...' { npm run db:seed }
  Run-Step '[6/8] Building the backend...' { npm run build }
} finally { Pop-Location }

Push-Location (Join-Path $Root 'admin')
try {
  Run-Step '[7/8] Building the administration dashboard...' { npm run build }
} finally { Pop-Location }

Push-Location (Join-Path $Root 'mobile')
try {
  Write-Host "`n[8/8] Preparing Flutter packages..." -ForegroundColor Cyan
  flutter clean
  if ($LASTEXITCODE -ne 0) { throw 'flutter clean failed' }
  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
  Write-Host 'Running flutter analyze (informational warnings do not block this upgrade)...' -ForegroundColor DarkCyan
  flutter analyze
} finally { Pop-Location }

Write-Host "`nV4 UPGRADE COMPLETE" -ForegroundColor Green
Write-Host '1) Run .\start_all_windows.bat'
Write-Host '2) Open http://localhost:3001'
Write-Host '3) Configure Store items, Appearance, Levels, Stages, Game rules and Payments.'
Write-Host '4) Build the phone APK using .\build_mobile_for_phone_windows.bat'
