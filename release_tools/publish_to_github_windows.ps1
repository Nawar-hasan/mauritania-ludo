param(
  [Parameter(Mandatory=$true)][string]$RepoUrl
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git is not installed or not in PATH.' }
Write-Host 'Checking that secret env files are ignored...' -ForegroundColor Cyan
if (Test-Path 'backend/.env') { Write-Host 'backend/.env exists locally and is protected by .gitignore.' }
if (Test-Path 'admin/.env.local') { Write-Host 'admin/.env.local exists locally and is protected by .gitignore.' }
if (-not (Test-Path '.git')) { git init }
git branch -M main
git add .
$staged = git diff --cached --name-only
if ($staged -match '(^|/)\.env$|\.env\.local$|\.jks$|\.keystore$|\.p12$|\.p8$') {
  throw 'A secret-looking file is staged. Stop and inspect git status before pushing.'
}
try { git commit -m 'Prepare MAURITANIA LUDO cloud staging' } catch { Write-Host 'Nothing new to commit or commit identity not configured.' -ForegroundColor Yellow }
$origin = git remote get-url origin 2>$null
if ($LASTEXITCODE -eq 0 -and $origin) { git remote set-url origin $RepoUrl } else { git remote add origin $RepoUrl }
git remote -v
git push -u origin main
