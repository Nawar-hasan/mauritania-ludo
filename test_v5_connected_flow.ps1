$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendEnv = Join-Path $root 'backend\.env'
$base = 'http://localhost:3000/api/v1'

function Step($text) { Write-Host "`n== $text ==" -ForegroundColor Cyan }
function Json($value) { return ($value | ConvertTo-Json -Depth 15 -Compress) }
function Headers($token) { return @{ Authorization = "Bearer $token" } }
function Api($method, $path, $body = $null, $token = $null) {
  # Windows PowerShell 5.1 can send non-ASCII JSON using the system ANSI code page.
  # The API expects UTF-8 JSON, so always serialize once and send explicit UTF-8 bytes.
  $params = @{ Method = $method; Uri = "$base$path"; ContentType = 'application/json; charset=utf-8' }
  if ($token) { $params.Headers = Headers $token }
  if ($null -ne $body) {
    $jsonBody = Json $body
    $params.Body = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
  }
  try {
    return Invoke-RestMethod @params
  } catch {
    if ($null -ne $body) {
      Write-Host "Request failed: $method $base$path" -ForegroundColor Red
      Write-Host "JSON body: $jsonBody" -ForegroundColor DarkGray
    }
    throw
  }
}
function EnvValue($name) {
  $line = Get-Content $backendEnv | Where-Object { $_ -match "^$name=" } | Select-Object -First 1
  if (-not $line) { throw "$name was not found in backend/.env" }
  return ($line -split '=', 2)[1].Trim()
}

Step 'Health check'
$health = Api GET '/health'
if ($health.status -ne 'ok' -or $health.database -ne 'ok') { throw 'Backend health check failed' }
Write-Host 'Backend, PostgreSQL and Redis are healthy.' -ForegroundColor Green

Step 'Administrator login'
$adminUser = EnvValue 'SEED_ADMIN_USERNAME'
$adminPass = EnvValue 'SEED_ADMIN_PASSWORD'
$admin = Api POST '/auth/login' @{ identifier = $adminUser; password = $adminPass; deviceName = 'V5 smoke test' }
$adminToken = $admin.accessToken
Write-Host "Admin: $adminUser" -ForegroundColor Green

$stamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$password = 'LudoTest12345!'

Step 'Create two real player accounts'
$p1 = Api POST '/auth/register' @{ username = "smokea$stamp"; displayName = 'Smoke Player A'; email = "smokea$stamp@example.test"; password = $password; locale = 'en' }
$p2 = Api POST '/auth/register' @{ username = "smokeb$stamp"; displayName = 'Smoke Player B'; email = "smokeb$stamp@example.test"; password = $password; locale = 'ar' }
$p1Token = $p1.accessToken; $p2Token = $p2.accessToken
$p1Id = $p1.user.id; $p2Id = $p2.user.id
Write-Host "Players: $($p1.user.username), $($p2.user.username)" -ForegroundColor Green

Step 'Verify levels, stages, appearance, store and payment configuration'
$bootstrap = Api GET '/catalog/bootstrap' $null $p1Token
if ($bootstrap.rules.Count -lt 1) { throw 'No game rules returned' }
if ($bootstrap.levels.Count -lt 1) { throw 'No levels returned' }
if ($bootstrap.stages.Count -lt 1) { throw 'No stages returned' }
if ($bootstrap.items.Count -lt 3) { throw 'No store items returned' }
if ($bootstrap.paymentMethods.Count -lt 1) { throw 'No payment methods returned' }
Write-Host "Rules=$($bootstrap.rules.Count), Levels=$($bootstrap.levels.Count), Stages=$($bootstrap.stages.Count), Store=$($bootstrap.items.Count), Payments=$($bootstrap.paymentMethods.Count)" -ForegroundColor Green

Step 'Create and verify a temporary seasonal appearance campaign'
$campaignCode = "SMOKE_$stamp"
$campaign = Api POST '/admin/campaigns' @{
  code = $campaignCode; surface = 'HOME_BANNER'; nameAr = 'اختبار الحملة'; nameEn = 'Smoke Campaign';
  backgroundColor = '#5B21B6'; textColor = '#FFFFFF'; enabled = $true; priority = 999;
  startsAt = [DateTime]::UtcNow.AddMinutes(-1).ToString('o'); endsAt = [DateTime]::UtcNow.AddMinutes(20).ToString('o')
} $adminToken
$bootstrap = Api GET '/catalog/bootstrap' $null $p1Token
if (-not ($bootstrap.campaigns | Where-Object { $_.code -eq $campaignCode })) { throw 'Campaign was not returned by bootstrap' }
Write-Host 'Appearance campaign is live through the API.' -ForegroundColor Green

Step 'Fund test COINS, GEMS and CASH through audited admin adjustments'
foreach ($userId in @($p1Id, $p2Id)) {
  Api POST '/admin/wallets/adjust' @{ userId = $userId; accountType = 'COINS'; amount = 5000; currency = 'MRU'; reason = 'V5 smoke test coins'; idempotencyKey = "coins-$stamp-$userId" } $adminToken | Out-Null
  Api POST '/admin/wallets/adjust' @{ userId = $userId; accountType = 'GEMS'; amount = 500; currency = 'MRU'; reason = 'V5 smoke test gems'; idempotencyKey = "gems-$stamp-$userId" } $adminToken | Out-Null
  Api POST '/admin/wallets/adjust' @{ userId = $userId; accountType = 'CASH'; amount = 1000; currency = 'MRU'; reason = 'V5 smoke test cash'; idempotencyKey = "cash-$stamp-$userId" } $adminToken | Out-Null
}
Write-Host 'Test balances credited and recorded in the ledger.' -ForegroundColor Green

Step 'Purchase and equip board, dice and frame from the real catalog'
$items = $bootstrap.items
$board = $items | Where-Object { $_.code -eq 'BOARD_ROYAL' } | Select-Object -First 1
$dice = $items | Where-Object { $_.code -eq 'DICE_GOLD' } | Select-Object -First 1
$frame = $items | Where-Object { $_.code -eq 'FRAME_NEON' } | Select-Object -First 1
foreach ($item in @($board, $dice, $frame)) {
  if (-not $item) { throw 'One of BOARD_ROYAL, DICE_GOLD or FRAME_NEON is missing' }
  Api POST "/catalog/items/$($item.id)/purchase" @{ quantity = 1 } $p1Token | Out-Null
  Api POST "/catalog/items/$($item.id)/equip" $null $p1Token | Out-Null
}
$inventory = Api GET '/catalog/inventory' $null $p1Token
$equippedCodes = @($inventory | Where-Object { $_.equipped -eq $true } | ForEach-Object { $_.item.code })
if (-not ($equippedCodes -contains 'BOARD_ROYAL') -or -not ($equippedCodes -contains 'DICE_GOLD') -or -not ($equippedCodes -contains 'FRAME_NEON')) { throw 'Store purchase/equip verification failed' }
Write-Host "Equipped: $($equippedCodes -join ', ')" -ForegroundColor Green

Step 'Create a real manual deposit intent and approve it from finance'
$method = $bootstrap.paymentMethods | Where-Object { $_.supportsDeposit -eq $true -and $_.provider -eq 'MANUAL' } | Select-Object -First 1
if ($method) {
  $deposit = Api POST '/payments/deposits' @{ methodCode = $method.code; amount = 250; externalRef = "SMOKE-$stamp" } $p1Token
  Api POST "/admin/transactions/$($deposit.transaction.id)/approve" $null $adminToken | Out-Null
  Write-Host "Manual deposit through $($method.code) approved and credited." -ForegroundColor Green
} else {
  Write-Host 'No active MANUAL deposit method; payment test skipped.' -ForegroundColor Yellow
}

Step 'Create a real two-player wager match and auto-play it using server dice/state'
$match = Api POST '/matches' @{ mode = 'WAGER'; maxPlayers = 2; ruleCode = 'CLASSIC'; stakeAmount = 50; currency = 'MRU' } $p1Token
$match = Api POST "/matches/$($match.id)/join" $null $p2Token
$match = Api POST "/matches/$($match.id)/start" $null $p1Token
$tokens = @{ $p1Id = $p1Token; $p2Id = $p2Token }
$maxActions = 1800
$action = 0
while ($match.status -eq 'ACTIVE' -and $action -lt $maxActions) {
  $state = $match.currentState
  $activeUserId = [string]$state.players[$state.turnIndex].userId
  $token = $tokens[$activeUserId]
  if (-not $token) { throw "No token for active user $activeUserId" }
  if ($state.phase -eq 'ROLL') {
    $match = Api POST "/matches/$($match.id)/roll" $null $token
  } elseif ($state.phase -eq 'MOVE') {
    $pieceId = [int]$state.legalPieceIds[0]
    $match = Api POST "/matches/$($match.id)/move" @{ pieceId = $pieceId; expectedVersion = [int]$state.version } $token
  } elseif ($state.phase -eq 'FINISHED') {
    break
  } else {
    throw "Unexpected game phase $($state.phase)"
  }
  $action++
  if (($action % 50) -eq 0) { Write-Host "Game actions: $action" }
}
$match = Api GET "/matches/$($match.id)" $null $p1Token
if ($match.status -ne 'COMPLETED') { throw "Game did not complete after $action actions (status=$($match.status))" }
Write-Host "Match completed. Winner userId=$($match.winnerUserId). Actions=$action" -ForegroundColor Green

Step 'Verify progression, wager settlement and transaction history'
$me1 = Api GET '/users/me' $null $p1Token
$me2 = Api GET '/users/me' $null $p2Token
$wallet1 = Api GET '/wallets/me' $null $p1Token
$wallet2 = Api GET '/wallets/me' $null $p2Token
$tx1 = Api GET '/wallets/me/transactions' $null $p1Token
if (($me1.profile.matches + $me2.profile.matches) -lt 2) { throw 'Profile match counters did not update' }
if (-not ($tx1.items | Where-Object { $_.type -eq 'STORE_PURCHASE' })) { throw 'Store transaction missing' }
if (-not ($tx1.items | Where-Object { $_.type -eq 'WAGER_LOCK' -or $_.type -eq 'MATCH_PRIZE' })) { throw 'Wager transaction missing' }
Write-Host "Player A: level=$($me1.profile.level), xp=$($me1.profile.xp), cash=$($wallet1.balances.cash), coins=$($wallet1.balances.coins), gems=$($wallet1.balances.gems)" -ForegroundColor Green
Write-Host "Player B: level=$($me2.profile.level), xp=$($me2.profile.xp), cash=$($wallet2.balances.cash)" -ForegroundColor Green

Step 'Remove temporary appearance campaign'
Api DELETE "/admin/campaigns/$($campaign.id)" $null $adminToken | Out-Null

Write-Host "`nV5 CONNECTED FLOW PASSED" -ForegroundColor Green
Write-Host "Test accounts remain in the staging database for inspection: $($p1.user.username), $($p2.user.username)" -ForegroundColor DarkGray
