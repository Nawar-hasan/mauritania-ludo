$ErrorActionPreference='Continue'
Write-Host 'MAURITANIA LUDO - local connection diagnosis' -ForegroundColor Cyan
Write-Host '\n[1] Docker containers'
docker compose ps
Write-Host '\n[2] Local API'
try { Invoke-RestMethod http://localhost:3000/api/v1/health -TimeoutSec 4 | ConvertTo-Json } catch { Write-Host $_.Exception.Message -ForegroundColor Red }
Write-Host '\n[3] Active VPN-like adapters'
$vpn=Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq 'Up' -and ($_.Name -match 'VPN|Proton|WireGuard|TAP|TUN|Tailscale' -or $_.InterfaceDescription -match 'VPN|Proton|WireGuard|TAP|TUN|Tailscale')}
if($vpn){$vpn | Format-Table Name,InterfaceDescription,Status; Write-Host 'Disable VPN for local phone testing.' -ForegroundColor Yellow}else{Write-Host 'No active VPN adapter detected.' -ForegroundColor Green}
Write-Host '\n[4] Physical LAN/Wi-Fi IPv4 candidates'
Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object {$_.IPv4DefaultGateway -ne $null -and $_.IPv4Address -ne $null -and $_.InterfaceAlias -notmatch 'VPN|Proton|WireGuard|TAP|TUN|vEthernet|Docker|WSL|Hyper-V|Virtual|Loopback|Tailscale'} | ForEach-Object { Write-Host "$($_.InterfaceAlias): $($_.IPv4Address.IPAddress)" -ForegroundColor Green }
Write-Host '\nUse the physical Wi-Fi/Ethernet address when building the phone APK.'
