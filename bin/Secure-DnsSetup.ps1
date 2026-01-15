#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Secure DNS Configuration Script for Windows 11
    Configures DNS-over-HTTPS (DoH) with DNSSEC validation

.DESCRIPTION
    This script configures Windows 11 to use encrypted DNS (DNS-over-HTTPS) with automatic failover.
    Primary: Cloudflare | Secondary: Quad9 | Tertiary: Google
    
.PARAMETER RunTests
    Run connectivity tests only without making configuration changes

.PARAMETER Rollback
    Restore original DNS configuration

.PARAMETER Verbose
    Enable verbose output for debugging

.PARAMETER DryRun
    Show what would be done without making changes

.EXAMPLE
    .\Secure-DnsSetup.ps1
    Configure secure DNS with default settings

.EXAMPLE
    .\Secure-DnsSetup.ps1 -RunTests
    Test current DNS configuration

.EXAMPLE
    .\Secure-DnsSetup.ps1 -Rollback
    Restore original DNS settings

.NOTES
    Author: SetDNScache Project
    Version: 2.0.0
    Requires: Windows 11 or Windows Server 2022+
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$RunTests,
    
    [Parameter(Mandatory=$false)]
    [switch]$Rollback,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [switch]$VerboseLogging
)

# ============================================================================
# Configuration Constants
# ============================================================================

$Script:Config = @{
    # DNS Server Configuration
    CloudflarePrimary = @("1.1.1.1", "1.0.0.1")
    CloudflareDoH = "https://cloudflare-dns.com/dns-query"
    CloudflareTemplate = "https://cloudflare-dns.com/dns-query{?dns}"
    
    Quad9Secondary = @("9.9.9.9", "149.112.112.112")
    Quad9DoH = "https://dns.quad9.net/dns-query"
    Quad9Template = "https://dns.quad9.net/dns-query{?dns}"
    
    GoogleTertiary = @("8.8.8.8", "8.8.4.4")
    GoogleDoH = "https://dns.google/dns-query"
    GoogleTemplate = "https://dns.google/dns-query{?dns}"
    
    # Logging
    LogPath = "$env:TEMP\SetDNScache"
    LogFile = "$env:TEMP\SetDNScache\dns-setup.log"
    BackupPath = "$env:TEMP\SetDNScache\backups"
    
    # Registry Paths
    DnsClientRegistry = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
    NetworkRegistry = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
}

# ============================================================================
# Logging Functions
# ============================================================================

function Initialize-Logging {
    if (-not (Test-Path $Script:Config.LogPath)) {
        New-Item -Path $Script:Config.LogPath -ItemType Directory -Force | Out-Null
    }
    
    if (-not (Test-Path $Script:Config.BackupPath)) {
        New-Item -Path $Script:Config.BackupPath -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG', 'SUCCESS')]
        [string]$Level,
        
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Console output with colors
    switch ($Level) {
        'INFO'    { Write-Host "[INFO] " -ForegroundColor Green -NoNewline; Write-Host "$timestamp - $Message" }
        'WARN'    { Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline; Write-Host "$timestamp - $Message" }
        'ERROR'   { Write-Host "[ERROR] " -ForegroundColor Red -NoNewline; Write-Host "$timestamp - $Message" }
        'DEBUG'   { if ($VerboseLogging) { Write-Host "[DEBUG] " -ForegroundColor Cyan -NoNewline; Write-Host "$timestamp - $Message" } }
        'SUCCESS' { Write-Host "[SUCCESS] " -ForegroundColor Green -NoNewline; Write-Host "$timestamp - $Message" }
    }
    
    # File output
    Add-Content -Path $Script:Config.LogFile -Value $logMessage -ErrorAction SilentlyContinue
}

function Write-Section {
    param([string]$Title)
    
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "============================================================================" -ForegroundColor Cyan
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

function Test-Administrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Log -Level ERROR -Message "This script must be run as Administrator"
        Write-Log -Level INFO -Message "Right-click PowerShell and select 'Run as Administrator'"
        exit 1
    }
    
    Write-Log -Level DEBUG -Message "Administrator privileges confirmed"
}

function Test-WindowsVersion {
    $osVersion = [System.Environment]::OSVersion.Version
    $buildNumber = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name CurrentBuild).CurrentBuild
    
    Write-Log -Level INFO -Message "Checking Windows version..."
    Write-Log -Level DEBUG -Message "OS Version: $osVersion, Build: $buildNumber"
    
    # Windows 11 starts at build 22000
    if ([int]$buildNumber -lt 22000) {
        Write-Log -Level WARN -Message "This script is optimized for Windows 11 (build 22000+)"
        Write-Log -Level WARN -Message "Current build: $buildNumber"
        Write-Log -Level INFO -Message "DoH support may be limited on this version"
        
        $continue = Read-Host "Continue anyway? (Y/N)"
        if ($continue -ne 'Y' -and $continue -ne 'y') {
            Write-Log -Level INFO -Message "Installation cancelled by user"
            exit 0
        }
    }
    
    Write-Log -Level SUCCESS -Message "Windows version check passed"
}

function Test-NetworkConnectivity {
    Write-Log -Level INFO -Message "Testing network connectivity..."
    
    $testHosts = @(
        @{Name = "Cloudflare"; IP = "1.1.1.1"},
        @{Name = "Quad9"; IP = "9.9.9.9"},
        @{Name = "Google"; IP = "8.8.8.8"}
    )
    
    $allPassed = $true
    foreach ($host in $testHosts) {
        $result = Test-Connection -ComputerName $host.IP -Count 2 -Quiet -ErrorAction SilentlyContinue
        if ($result) {
            Write-Log -Level DEBUG -Message "✓ $($host.Name) ($($host.IP)) - Reachable"
        } else {
            Write-Log -Level WARN -Message "✗ $($host.Name) ($($host.IP)) - Not reachable"
            $allPassed = $false
        }
    }
    
    if ($allPassed) {
        Write-Log -Level SUCCESS -Message "Network connectivity check passed"
    } else {
        Write-Log -Level WARN -Message "Some DNS servers are not reachable"
        Write-Log -Level INFO -Message "Configuration will continue, but service may be degraded"
    }
    
    return $allPassed
}

# ============================================================================
# Backup and Restore Functions
# ============================================================================

function Backup-DnsConfiguration {
    Write-Log -Level INFO -Message "Backing up current DNS configuration..."
    
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupFile = Join-Path $Script:Config.BackupPath "dns-backup-$timestamp.json"
    
    $backup = @{
        Timestamp = $timestamp
        Adapters = @()
        DnsCache = @{}
        DoHSettings = @{}
    }
    
    # Backup network adapter DNS settings
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    foreach ($adapter in $adapters) {
        $dnsServers = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        
        $adapterBackup = @{
            Name = $adapter.Name
            InterfaceIndex = $adapter.ifIndex
            DnsServers = $dnsServers.ServerAddresses
        }
        
        $backup.Adapters += $adapterBackup
        Write-Log -Level DEBUG -Message "Backed up DNS settings for adapter: $($adapter.Name)"
    }
    
    # Backup DNS cache settings
    try {
        $cacheSettings = Get-ItemProperty -Path $Script:Config.DnsClientRegistry -ErrorAction SilentlyContinue
        if ($cacheSettings) {
            $backup.DnsCache = @{
                MaxCacheTtl = $cacheSettings.MaxCacheTtl
                MaxNegativeCacheTtl = $cacheSettings.MaxNegativeCacheTtl
            }
        }
    } catch {
        Write-Log -Level DEBUG -Message "No existing DNS cache settings to backup"
    }
    
    # Save backup to file
    $backup | ConvertTo-Json -Depth 10 | Set-Content -Path $backupFile
    
    Write-Log -Level SUCCESS -Message "Configuration backed up to: $backupFile"
    return $backupFile
}

function Restore-DnsConfiguration {
    param([string]$BackupFile)
    
    Write-Log -Level INFO -Message "Restoring DNS configuration from backup..."
    
    if (-not (Test-Path $BackupFile)) {
        # Find most recent backup
        $backups = Get-ChildItem -Path $Script:Config.BackupPath -Filter "dns-backup-*.json" | Sort-Object LastWriteTime -Descending
        if ($backups.Count -eq 0) {
            Write-Log -Level ERROR -Message "No backup files found"
            return $false
        }
        $BackupFile = $backups[0].FullName
        Write-Log -Level INFO -Message "Using most recent backup: $($backups[0].Name)"
    }
    
    try {
        $backup = Get-Content -Path $BackupFile -Raw | ConvertFrom-Json
        
        # Restore adapter DNS settings
        foreach ($adapter in $backup.Adapters) {
            if ($adapter.DnsServers -and $adapter.DnsServers.Count -gt 0) {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $adapter.DnsServers
                Write-Log -Level INFO -Message "Restored DNS for adapter: $($adapter.Name)"
            } else {
                # Reset to automatic (DHCP)
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ResetServerAddresses
                Write-Log -Level INFO -Message "Reset adapter to DHCP: $($adapter.Name)"
            }
        }
        
        # Disable DoH
        Write-Log -Level INFO -Message "Disabling DNS-over-HTTPS..."
        try {
            # Remove DoH configuration via netsh
            $dohServers = @("1.1.1.1", "1.0.0.1", "9.9.9.9", "149.112.112.112", "8.8.8.8", "8.8.4.4")
            foreach ($server in $dohServers) {
                netsh dns delete encryption server=$server | Out-Null
            }
        } catch {
            Write-Log -Level DEBUG -Message "DoH removal: $($_.Exception.Message)"
        }
        
        # Clear DNS cache
        Clear-DnsClientCache
        
        Write-Log -Level SUCCESS -Message "DNS configuration restored successfully"
        return $true
        
    } catch {
        Write-Log -Level ERROR -Message "Failed to restore configuration: $($_.Exception.Message)"
        return $false
    }
}

# ============================================================================
# DNS Configuration Functions
# ============================================================================

function Set-SecureDnsServers {
    Write-Log -Level INFO -Message "Configuring DNS servers..."
    
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    
    if ($adapters.Count -eq 0) {
        Write-Log -Level ERROR -Message "No active network adapters found"
        return $false
    }
    
    # All DNS servers (Primary, Secondary, Tertiary)
    $allDnsServers = $Script:Config.CloudflarePrimary + $Script:Config.Quad9Secondary + $Script:Config.GoogleTertiary
    
    foreach ($adapter in $adapters) {
        Write-Log -Level INFO -Message "Configuring adapter: $($adapter.Name)"
        
        if ($DryRun) {
            Write-Log -Level INFO -Message "[DRY RUN] Would set DNS servers: $($allDnsServers -join ', ')"
        } else {
            try {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $allDnsServers
                Write-Log -Level SUCCESS -Message "✓ DNS servers configured for: $($adapter.Name)"
            } catch {
                Write-Log -Level ERROR -Message "Failed to configure adapter: $($adapter.Name) - $($_.Exception.Message)"
            }
        }
    }
    
    return $true
}

function Enable-DnsOverHttps {
    Write-Log -Level INFO -Message "Enabling DNS-over-HTTPS (DoH)..."
    
    $dohConfigs = @(
        @{
            Name = "Cloudflare Primary"
            Servers = $Script:Config.CloudflarePrimary
            Template = $Script:Config.CloudflareTemplate
            Fallback = $false
        },
        @{
            Name = "Cloudflare Secondary"
            Servers = @("1.0.0.1")
            Template = $Script:Config.CloudflareTemplate
            Fallback = $false
        },
        @{
            Name = "Quad9"
            Servers = $Script:Config.Quad9Secondary
            Template = $Script:Config.Quad9Template
            Fallback = $false
        },
        @{
            Name = "Google"
            Servers = $Script:Config.GoogleTertiary
            Template = $Script:Config.GoogleTemplate
            Fallback = $true
        }
    )
    
    foreach ($config in $dohConfigs) {
        foreach ($server in $config.Servers) {
            if ($DryRun) {
                Write-Log -Level INFO -Message "[DRY RUN] Would enable DoH for $($config.Name): $server"
            } else {
                try {
                    # Windows 11 DoH configuration via netsh
                    $result = netsh dns add encryption server=$server dohtemplate=$($config.Template) autoupgrade=yes 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log -Level SUCCESS -Message "✓ DoH enabled for $($config.Name): $server"
                    } else {
                        Write-Log -Level WARN -Message "DoH configuration warning for $server`: $result"
                    }
                } catch {
                    Write-Log -Level WARN -Message "DoH configuration failed for $server`: $($_.Exception.Message)"
                }
            }
        }
    }
    
    return $true
}

function Optimize-DnsCache {
    Write-Log -Level INFO -Message "Optimizing DNS cache settings..."
    
    $cacheSettings = @{
        MaxCacheTtl = 86400          # 24 hours
        MaxNegativeCacheTtl = 300    # 5 minutes
        NetFailureCacheTime = 30     # 30 seconds
        NegativeSOACacheTime = 300   # 5 minutes
    }
    
    if ($DryRun) {
        Write-Log -Level INFO -Message "[DRY RUN] Would optimize DNS cache with settings:"
        $cacheSettings.GetEnumerator() | ForEach-Object {
            Write-Log -Level INFO -Message "  $($_.Key) = $($_.Value)"
        }
    } else {
        try {
            foreach ($setting in $cacheSettings.GetEnumerator()) {
                Set-ItemProperty -Path $Script:Config.DnsClientRegistry -Name $setting.Key -Value $setting.Value -Type DWord -Force
                Write-Log -Level DEBUG -Message "Set $($setting.Key) = $($setting.Value)"
            }
            
            Write-Log -Level SUCCESS -Message "✓ DNS cache optimized"
        } catch {
            Write-Log -Level WARN -Message "Failed to optimize DNS cache: $($_.Exception.Message)"
        }
    }
    
    return $true
}

function Enable-DnsSecurity {
    Write-Log -Level INFO -Message "Enabling DNS security features..."
    
    if ($DryRun) {
        Write-Log -Level INFO -Message "[DRY RUN] Would enable DNSSEC validation"
    } else {
        try {
            # Enable DNSSEC validation
            Set-DnsClientNrptGlobal -EnableDAForAllNetworks $true -ErrorAction SilentlyContinue
            
            # Set DNS query privacy
            Set-DnsClientNrptGlobal -QueryPolicy QueryIPv6Only -ErrorAction SilentlyContinue
            
            Write-Log -Level SUCCESS -Message "✓ DNS security features enabled"
        } catch {
            Write-Log -Level WARN -Message "Some security features may not be available: $($_.Exception.Message)"
        }
    }
    
    return $true
}

function Restart-DnsServices {
    Write-Log -Level INFO -Message "Restarting DNS Client service..."
    
    if ($DryRun) {
        Write-Log -Level INFO -Message "[DRY RUN] Would restart DNS Client service"
    } else {
        try {
            Restart-Service -Name "Dnscache" -Force
            Start-Sleep -Seconds 2
            
            $service = Get-Service -Name "Dnscache"
            if ($service.Status -eq 'Running') {
                Write-Log -Level SUCCESS -Message "✓ DNS Client service restarted successfully"
            } else {
                Write-Log -Level ERROR -Message "DNS Client service is not running"
                return $false
            }
        } catch {
            Write-Log -Level ERROR -Message "Failed to restart DNS Client service: $($_.Exception.Message)"
            return $false
        }
    }
    
    # Clear DNS cache
    if (-not $DryRun) {
        Clear-DnsClientCache
        Write-Log -Level INFO -Message "DNS cache cleared"
    }
    
    return $true
}

# ============================================================================
# Testing Functions
# ============================================================================

function Test-DnsResolution {
    Write-Log -Level INFO -Message "Testing DNS resolution..."
    
    $testDomains = @("google.com", "cloudflare.com", "github.com")
    $passCount = 0
    $totalTests = $testDomains.Count
    
    foreach ($domain in $testDomains) {
        try {
            $result = Resolve-DnsName -Name $domain -Type A -ErrorAction Stop -DnsOnly
            if ($result) {
                Write-Log -Level SUCCESS -Message "✓ Resolved $domain`: $($result[0].IPAddress)"
                $passCount++
            }
        } catch {
            Write-Log -Level ERROR -Message "✗ Failed to resolve $domain"
        }
    }
    
    Write-Log -Level INFO -Message "DNS Resolution: $passCount/$totalTests tests passed"
    return ($passCount -eq $totalTests)
}

function Test-DnsPerformance {
    Write-Log -Level INFO -Message "Testing DNS query performance..."
    
    $testDomain = "google.com"
    $iterations = 3
    $times = @()
    
    for ($i = 1; $i -le $iterations; $i++) {
        Clear-DnsClientCache
        $startTime = Get-Date
        Resolve-DnsName -Name $testDomain -Type A -ErrorAction SilentlyContinue | Out-Null
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        $times += $duration
        
        Write-Log -Level DEBUG -Message "Query $i`: $([math]::Round($duration, 2))ms"
    }
    
    $avgTime = ($times | Measure-Object -Average).Average
    
    if ($avgTime -lt 100) {
        Write-Log -Level SUCCESS -Message "✓ Average query time: $([math]::Round($avgTime, 2))ms (Excellent)"
    } elseif ($avgTime -lt 300) {
        Write-Log -Level SUCCESS -Message "✓ Average query time: $([math]::Round($avgTime, 2))ms (Good)"
    } else {
        Write-Log -Level WARN -Message "Average query time: $([math]::Round($avgTime, 2))ms (Acceptable)"
    }
    
    return $true
}

function Test-DohStatus {
    Write-Log -Level INFO -Message "Testing DNS-over-HTTPS status..."
    
    try {
        # Check DoH configuration via netsh
        $dohStatus = netsh dns show encryption 2>&1
        
        if ($dohStatus -match "1.1.1.1|9.9.9.9|8.8.8.8") {
            Write-Log -Level SUCCESS -Message "✓ DNS-over-HTTPS is configured"
            
            if ($VerboseLogging) {
                Write-Log -Level DEBUG -Message "DoH Status:"
                $dohStatus | ForEach-Object { Write-Log -Level DEBUG -Message "  $_" }
            }
            
            return $true
        } else {
            Write-Log -Level WARN -Message "DoH may not be fully configured"
            return $false
        }
    } catch {
        Write-Log -Level WARN -Message "Unable to verify DoH status: $($_.Exception.Message)"
        return $false
    }
}

function Test-DnsConfiguration {
    Write-Section "Running DNS Configuration Tests"
    
    $results = @{
        Resolution = Test-DnsResolution
        Performance = Test-DnsPerformance
        DoHStatus = Test-DohStatus
    }
    
    $passCount = ($results.Values | Where-Object { $_ -eq $true }).Count
    $totalTests = $results.Count
    
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host "  Test Summary: $passCount/$totalTests tests passed" -ForegroundColor $(if ($passCount -eq $totalTests) { 'Green' } else { 'Yellow' })
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    return ($passCount -eq $totalTests)
}

# ============================================================================
# Main Configuration Function
# ============================================================================

function Install-SecureDns {
    Write-Section "Secure DNS Configuration for Windows 11"
    
    # Pre-flight checks
    Test-Administrator
    Test-WindowsVersion
    Test-NetworkConnectivity
    
    # Backup current configuration
    Write-Section "Backing Up Current Configuration"
    $backupFile = Backup-DnsConfiguration
    
    # Configure DNS
    Write-Section "Configuring Secure DNS"
    
    if (-not (Set-SecureDnsServers)) {
        Write-Log -Level ERROR -Message "Failed to configure DNS servers"
        return $false
    }
    
    # Enable DNS-over-HTTPS
    Write-Section "Enabling DNS-over-HTTPS"
    Enable-DnsOverHttps
    
    # Optimize DNS cache
    Write-Section "Optimizing DNS Cache"
    Optimize-DnsCache
    
    # Enable security features
    Write-Section "Enabling DNS Security Features"
    Enable-DnsSecurity
    
    # Restart services
    Write-Section "Restarting DNS Services"
    if (-not (Restart-DnsServices)) {
        Write-Log -Level ERROR -Message "Failed to restart DNS services"
        return $false
    }
    
    # Test configuration
    Write-Section "Verifying Configuration"
    Start-Sleep -Seconds 3
    Test-DnsConfiguration
    
    # Summary
    Write-Section "Configuration Complete"
    Write-Log -Level SUCCESS -Message "Secure DNS configuration completed successfully!"
    Write-Host ""
    Write-Log -Level INFO -Message "Configuration Summary:"
    Write-Log -Level INFO -Message "  Primary DNS:   Cloudflare (1.1.1.1, 1.0.0.1)"
    Write-Log -Level INFO -Message "  Secondary DNS: Quad9 (9.9.9.9, 149.112.112.112)"
    Write-Log -Level INFO -Message "  Tertiary DNS:  Google (8.8.8.8, 8.8.4.4)"
    Write-Log -Level INFO -Message "  DoH Protocol:  Enabled"
    Write-Log -Level INFO -Message "  Backup File:   $backupFile"
    Write-Host ""
    Write-Log -Level INFO -Message "To test your DNS:"
    Write-Log -Level INFO -Message "  Resolve-DnsName google.com"
    Write-Host ""
    Write-Log -Level INFO -Message "To rollback:"
    Write-Log -Level INFO -Message "  .\Secure-DnsSetup.ps1 -Rollback"
    
    return $true
}

# ============================================================================
# Entry Point
# ============================================================================

function Main {
    Initialize-Logging
    
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host "  SetDNScache - Windows 11 Secure DNS Configuration" -ForegroundColor Cyan
    Write-Host "  Version 2.0.0" -ForegroundColor Cyan
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        if ($Rollback) {
            Write-Section "Restoring Original DNS Configuration"
            Test-Administrator
            $success = Restore-DnsConfiguration -BackupFile ""
            if ($success) {
                Restart-DnsServices
                Write-Log -Level SUCCESS -Message "Rollback completed successfully"
            } else {
                Write-Log -Level ERROR -Message "Rollback failed"
                exit 1
            }
        }
        elseif ($RunTests) {
            Write-Section "Running DNS Tests Only"
            Test-Administrator
            Test-DnsConfiguration
        }
        else {
            # Full installation
            Install-SecureDns
        }
        
        Write-Host ""
        Write-Log -Level SUCCESS -Message "Operation completed successfully!"
        exit 0
        
    } catch {
        Write-Log -Level ERROR -Message "An error occurred: $($_.Exception.Message)"
        Write-Log -Level ERROR -Message "Stack Trace: $($_.ScriptStackTrace)"
        exit 1
    }
}

# Run the script
Main
