param(
  [string]$ProjectRoot = 'C:\MAURITANIA_LUDO'
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)

function Run-Native([string]$Label, [scriptblock]$Command) {
  Write-Host ''
  Write-Host "== $Label ==" -ForegroundColor Cyan
  & $Command
  if ($LASTEXITCODE -ne 0) { throw "$Label failed with exit code $LASTEXITCODE" }
}

if (-not (Test-Path (Join-Path $ProjectRoot 'backend\package.json'))) { throw "Backend not found: $ProjectRoot" }
if (-not (Test-Path (Join-Path $ProjectRoot 'admin\package.json'))) { throw "Admin not found: $ProjectRoot" }
if (-not (Test-Path (Join-Path $ProjectRoot 'mobile\pubspec.yaml'))) { throw "Mobile app not found: $ProjectRoot" }

Write-Host 'MAURITANIA LUDO V8 final validation' -ForegroundColor Green
Write-Host "Project: $ProjectRoot"

# Fast repository checks first.
Push-Location $ProjectRoot
try {
  Run-Native 'Git whitespace check' { git diff --check }

  $migration = Join-Path $ProjectRoot 'backend\prisma\migrations\20260811073000_final_product_modules\migration.sql'
  if (-not (Test-Path $migration)) { throw 'V8 Prisma migration is missing.' }

  $localization = Join-Path $ProjectRoot 'mobile\lib\core\localization.dart'
  $text = [IO.File]::ReadAllText($localization, [Text.Encoding]::UTF8)
  if ($text.Contains([char]0xFFFD)) { throw 'localization.dart contains invalid replacement characters. Encoding is damaged.' }

  Push-Location (Join-Path $ProjectRoot 'backend')
  try {
    Run-Native 'Backend Prisma generate' { npm run db:generate }
    Run-Native 'Backend TypeScript check' { npm run typecheck }
    Run-Native 'Backend tests' { npm test -- --runInBand }
    Run-Native 'Backend production build' { npm run build }
  } finally { Pop-Location }

  Push-Location (Join-Path $ProjectRoot 'admin')
  try {
    Run-Native 'Admin TypeScript check' { npm run typecheck }
    Run-Native 'Admin production build' { npm run build }
  } finally { Pop-Location }

  if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Flutter is not available in PATH.' }
  Push-Location (Join-Path $ProjectRoot 'mobile')
  try {
    Run-Native 'Flutter dependencies' { flutter pub get }
    Run-Native 'Flutter analyzer' { flutter analyze --no-fatal-infos --no-fatal-warnings }
  } finally { Pop-Location }

  Write-Host ''
  Write-Host 'V8 VALIDATION PASSED.' -ForegroundColor Green
  Write-Host 'No push was performed. Review git status, then commit/push only after this pass.' -ForegroundColor Yellow
} finally {
  Pop-Location
}
