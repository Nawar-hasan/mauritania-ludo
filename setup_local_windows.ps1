$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

function Require-Command([string]$Name, [string]$InstallHint) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "$Name is not installed. $InstallHint"
  }
}

Require-Command 'node' 'Install Node.js 22 or newer.'
Require-Command 'npm' 'Install Node.js 22 or newer.'
Require-Command 'docker' 'Install Docker Desktop and start it.'

$nodeMajor = [int]((node --version).TrimStart('v').Split('.')[0])
if ($nodeMajor -lt 22) { throw 'Node.js 22 or newer is required.' }

docker info *> $null
if ($LASTEXITCODE -ne 0) { throw 'Docker Desktop is installed but is not running.' }

Write-Host '[1/6] Starting PostgreSQL and Redis...' -ForegroundColor Cyan
docker compose up -d

$backend = Join-Path $Root 'backend'
$envPath = Join-Path $backend '.env'
if (-not (Test-Path $envPath)) {
  Copy-Item (Join-Path $backend '.env.example') $envPath
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $accessBytes = New-Object byte[] 48
    $refreshBytes = New-Object byte[] 48
    $rng.GetBytes($accessBytes)
    $rng.GetBytes($refreshBytes)
    $access = [Convert]::ToBase64String($accessBytes)
    $refresh = [Convert]::ToBase64String($refreshBytes)
  } finally {
    $rng.Dispose()
  }
  $content = Get-Content $envPath -Raw
  $content = $content -replace 'JWT_ACCESS_SECRET=.*', "JWT_ACCESS_SECRET=$access"
  $content = $content -replace 'JWT_REFRESH_SECRET=.*', "JWT_REFRESH_SECRET=$refresh"
  Set-Content -Path $envPath -Value $content -Encoding UTF8
  Write-Host 'Created backend/.env with random local JWT secrets.' -ForegroundColor Green
}

Write-Host '[2/6] Installing backend packages...' -ForegroundColor Cyan
Set-Location $backend
npm install --no-audit --no-fund

Write-Host '[3/6] Generating Prisma client...' -ForegroundColor Cyan
npm run db:generate

Write-Host '[4/6] Applying database migrations...' -ForegroundColor Cyan
npm run db:deploy

Write-Host '[5/6] Seeding rules, settings and the initial administrator...' -ForegroundColor Cyan
npm run db:seed

Write-Host '[6/6] Preparing the admin dashboard...' -ForegroundColor Cyan
$admin = Join-Path $Root 'admin'
$adminEnv = Join-Path $admin '.env.local'
if (-not (Test-Path $adminEnv)) { Copy-Item (Join-Path $admin '.env.example') $adminEnv }
Set-Location $admin
npm install --no-audit --no-fund

Set-Location $Root
Write-Host ''
Write-Host 'SETUP COMPLETE' -ForegroundColor Green
Write-Host 'Admin URL after startup: http://localhost:3001'
Write-Host 'Swagger after startup: http://localhost:3000/docs'
Write-Host 'Local admin username: superadmin'
Write-Host 'Local admin password is in backend/.env under SEED_ADMIN_PASSWORD.'
Write-Host 'Run start_all_windows.bat next.' -ForegroundColor Yellow
