$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host 'MAURITANIA LUDO V6 - branding, network and performance update' -ForegroundColor Cyan
Write-Host '[1/4] Removing old reference/mock UI assets from the mobile runtime...'
$ref=Join-Path $root 'mobile\assets\reference_ui'
if(Test-Path $ref){Remove-Item $ref -Recurse -Force}
Write-Host '[2/4] Preparing Flutter packages...'
Push-Location (Join-Path $root 'mobile'); flutter pub get; if($LASTEXITCODE -ne 0){throw 'flutter pub get failed'}; Pop-Location
Write-Host '[3/4] Building backend...'
Push-Location (Join-Path $root 'backend'); npm run build; if($LASTEXITCODE -ne 0){throw 'backend build failed'}; Pop-Location
Write-Host '[4/4] Building admin...'
Push-Location (Join-Path $root 'admin'); npm run build; if($LASTEXITCODE -ne 0){throw 'admin build failed'}; Pop-Location
Write-Host 'V6 APPLY COMPLETE' -ForegroundColor Green
Write-Host 'Next: start_all_windows.bat, then build_mobile_for_phone_windows.bat.'
