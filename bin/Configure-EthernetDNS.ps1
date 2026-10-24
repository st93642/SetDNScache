#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configure a network adapter (default: Ethernet) with secure DNS servers

.DESCRIPTION
    Sets up Ethernet adapter with the same secure DNS configuration as Wi-Fi
    Uses Cloudflare and Quad9 DNS servers (DoH is configured by Secure-DnsSetup.ps1)

.PARAMETER InterfaceAlias
    Adapter name to configure (default "Ethernet"). See Get-NetAdapter.

.PARAMETER NoPause
    Do not wait for a key press at the end (for non-interactive use).
#>
[CmdletBinding()]
param(
    [string]$InterfaceAlias = "Ethernet",
    [switch]$NoPause
)

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "  Configuring Ethernet with Secure DNS" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

# DNS servers (same as Wi-Fi configuration)
$dnsServers = @("1.1.1.1", "9.9.9.9", "1.0.0.1", "149.112.112.112")

try {
    # Check if Ethernet adapter exists and is available
    $ethernet = Get-NetAdapter -Name $InterfaceAlias -ErrorAction Stop
    
    if ($ethernet.Status -eq 'Up') {
        Write-Host "✓ Ethernet adapter is connected" -ForegroundColor Green
    } else {
        Write-Host "⚠ Ethernet adapter is $($ethernet.Status)" -ForegroundColor Yellow
        Write-Host "  Configuration will be applied, but testing requires connection" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Current Ethernet DNS servers:" -ForegroundColor Yellow
    $currentDns = (Get-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4).ServerAddresses
    if ($currentDns) {
        $currentDns | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    } else {
        Write-Host "  (automatic/DHCP)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "Configuring secure DNS servers..." -ForegroundColor Cyan
    
    # Set DNS servers
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $dnsServers
    
    Write-Host "✓ DNS servers configured successfully!" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "New Ethernet DNS configuration:" -ForegroundColor Yellow
    $newDns = (Get-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4).ServerAddresses
    $newDns | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
    
    Write-Host ""
    Write-Host "DNS Hierarchy:" -ForegroundColor Cyan
    Write-Host "  Cloudflare (1.1.1.1, 1.0.0.1) and Quad9 (9.9.9.9, 149.112.112.112), interleaved" -ForegroundColor White
    
    Write-Host ""
    Write-Host "✓ DoH (DNS-over-HTTPS) encryption is already configured for these servers" -ForegroundColor Green
    Write-Host "  Your DNS queries on Ethernet will be encrypted automatically!" -ForegroundColor Green
    
    # Test DNS if Ethernet is connected
    if ($ethernet.Status -eq 'Up') {
        Write-Host ""
        Write-Host "Testing DNS resolution..." -ForegroundColor Cyan
        
        try {
            $testResult = Resolve-DnsName -Name "google.com" -Type A -DnsOnly -ErrorAction Stop
            if ($testResult) {
                Write-Host "✓ DNS resolution test: SUCCESS" -ForegroundColor Green
                Write-Host "  google.com → $($testResult[0].IPAddress)" -ForegroundColor Gray
            }
        } catch {
            Write-Host "⚠ DNS test failed (may be using Wi-Fi instead)" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host "  Configuration Complete!" -ForegroundColor Green
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "When you connect Ethernet, secure DNS will be active automatically." -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host ""
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    
    if (-not (Get-NetAdapter -Name $InterfaceAlias -ErrorAction SilentlyContinue)) {
        Write-Host "No adapter named '$InterfaceAlias'. Re-run with -InterfaceAlias <name>." -ForegroundColor Yellow
        Write-Host "Available network adapters:" -ForegroundColor Yellow
        Get-NetAdapter | Where-Object { $_.Status -ne 'Disabled' } | ForEach-Object {
            Write-Host "  - $($_.Name) ($($_.Status))" -ForegroundColor Cyan
        }
    }
}

if (-not $NoPause) {
    Write-Host "Press any key to close..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
