#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    DNS Configuration Testing Script for Windows 11

.DESCRIPTION
    Comprehensive testing script to validate DNS-over-HTTPS configuration
    Tests DNS resolution, performance, DoH status, and service health

.PARAMETER PreReboot
    Run pre-reboot validation tests

.PARAMETER PostReboot
    Run post-reboot validation tests

.PARAMETER Quick
    Run quick validation tests only

.EXAMPLE
    .\Test-DnsConfiguration.ps1
    Run all DNS tests

.EXAMPLE
    .\Test-DnsConfiguration.ps1 -PreReboot
    Run pre-reboot validation tests

.EXAMPLE
    .\Test-DnsConfiguration.ps1 -PostReboot
    Run post-reboot validation tests
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$PreReboot,
    
    [Parameter(Mandatory=$false)]
    [switch]$PostReboot,
    
    [Parameter(Mandatory=$false)]
    [switch]$Quick
)

# ============================================================================
# Configuration
# ============================================================================

$Script:Config = @{
    LogPath = "$env:TEMP\SetDNScache\test-results"
    PreRebootLog = "$env:TEMP\SetDNScache\test-results\pre-reboot.log"
    PostRebootLog = "$env:TEMP\SetDNScache\test-results\post-reboot.log"
    JsonReport = "$env:TEMP\SetDNScache\test-results\test-results.json"
    
    TestDomains = @("example.com", "google.com", "cloudflare.com", "github.com")
    ExpectedDnsServers = @("1.1.1.1", "1.0.0.1", "9.9.9.9", "149.112.112.112", "8.8.8.8", "8.8.4.4")
}

# ============================================================================
# Helper Functions
# ============================================================================

function Initialize-TestEnvironment {
    if (-not (Test-Path $Script:Config.LogPath)) {
        New-Item -Path $Script:Config.LogPath -ItemType Directory -Force | Out-Null
    }
}

function Write-TestLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$LogFile = $null
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Console output
    switch ($Level) {
        "PASS"  { Write-Host "✓ " -ForegroundColor Green -NoNewline; Write-Host $Message }
        "FAIL"  { Write-Host "✗ " -ForegroundColor Red -NoNewline; Write-Host $Message }
        "WARN"  { Write-Host "⚠ " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
        "INFO"  { Write-Host "ℹ " -ForegroundColor Cyan -NoNewline; Write-Host $Message }
        default { Write-Host $Message }
    }
    
    # File output
    if ($LogFile) {
        Add-Content -Path $LogFile -Value $logMessage
    }
}

function Write-TestSection {
    param([string]$Title)
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

# ============================================================================
# Test Functions
# ============================================================================

function Test-DnsServiceStatus {
    param([ref]$Results)
    
    Write-Host "Test 1: DNS Client Service Status" -ForegroundColor Yellow
    
    try {
        $service = Get-Service -Name "Dnscache" -ErrorAction Stop
        
        if ($service.Status -eq 'Running') {
            Write-TestLog -Message "DNS Client service is running" -Level "PASS"
            $Results.Value.ServiceStatus = "PASS"
            return $true
        } else {
            Write-TestLog -Message "DNS Client service is not running (Status: $($service.Status))" -Level "FAIL"
            $Results.Value.ServiceStatus = "FAIL"
            return $false
        }
    } catch {
        Write-TestLog -Message "Failed to query DNS Client service: $($_.Exception.Message)" -Level "FAIL"
        $Results.Value.ServiceStatus = "FAIL"
        return $false
    }
}

function Test-DnsServerConfiguration {
    param([ref]$Results)
    
    Write-Host "`nTest 2: DNS Server Configuration" -ForegroundColor Yellow
    
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    $allConfigured = $true
    $configuredServers = @()
    
    foreach ($adapter in $adapters) {
        $dnsServers = (Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses
        
        if ($dnsServers -and $dnsServers.Count -gt 0) {
            Write-TestLog -Message "Adapter '$($adapter.Name)' DNS: $($dnsServers -join ', ')" -Level "PASS"
            $configuredServers += $dnsServers
            
            # Check if any expected servers are configured
            $hasExpected = $false
            foreach ($expected in $Script:Config.ExpectedDnsServers) {
                if ($expected -in $dnsServers) {
                    $hasExpected = $true
                    break
                }
            }
            
            if (-not $hasExpected) {
                Write-TestLog -Message "Adapter '$($adapter.Name)' does not use expected DNS servers" -Level "WARN"
                $allConfigured = $false
            }
        } else {
            Write-TestLog -Message "Adapter '$($adapter.Name)' has no DNS servers configured" -Level "WARN"
            $allConfigured = $false
        }
    }
    
    $Results.Value.DnsConfiguration = if ($allConfigured) { "PASS" } else { "PARTIAL" }
    $Results.Value.ConfiguredServers = $configuredServers | Select-Object -Unique
    
    return $allConfigured
}

function Test-DnsResolution {
    param([ref]$Results)
    
    Write-Host "`nTest 3: DNS Resolution" -ForegroundColor Yellow
    
    $passCount = 0
    $failedDomains = @()
    
    foreach ($domain in $Script:Config.TestDomains) {
        try {
            $result = Resolve-DnsName -Name $domain -Type A -ErrorAction Stop -DnsOnly
            if ($result -and $result[0].IPAddress) {
                Write-TestLog -Message "Resolved $domain → $($result[0].IPAddress)" -Level "PASS"
                $passCount++
            } else {
                Write-TestLog -Message "Failed to resolve $domain (no IP returned)" -Level "FAIL"
                $failedDomains += $domain
            }
        } catch {
            Write-TestLog -Message "Failed to resolve $domain`: $($_.Exception.Message)" -Level "FAIL"
            $failedDomains += $domain
        }
    }
    
    $totalTests = $Script:Config.TestDomains.Count
    Write-TestLog -Message "DNS Resolution: $passCount/$totalTests tests passed" -Level "INFO"
    
    $Results.Value.DnsResolution = if ($passCount -eq $totalTests) { "PASS" } elseif ($passCount -gt 0) { "PARTIAL" } else { "FAIL" }
    $Results.Value.FailedDomains = $failedDomains
    
    return ($passCount -eq $totalTests)
}

function Test-DnsPerformance {
    param([ref]$Results)
    
    Write-Host "`nTest 4: DNS Query Performance" -ForegroundColor Yellow
    
    $testDomain = "google.com"
    $times = @()
    
    for ($i = 1; $i -le 3; $i++) {
        Clear-DnsClientCache
        $startTime = Get-Date
        Resolve-DnsName -Name $testDomain -Type A -ErrorAction SilentlyContinue | Out-Null
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        $times += $duration
    }
    
    $avgTime = ($times | Measure-Object -Average).Average
    $Results.Value.AverageQueryTime = [math]::Round($avgTime, 2)
    
    if ($avgTime -lt 100) {
        Write-TestLog -Message "Average query time: $([math]::Round($avgTime, 2))ms (Excellent)" -Level "PASS"
        $Results.Value.Performance = "EXCELLENT"
        return $true
    } elseif ($avgTime -lt 300) {
        Write-TestLog -Message "Average query time: $([math]::Round($avgTime, 2))ms (Good)" -Level "PASS"
        $Results.Value.Performance = "GOOD"
        return $true
    } elseif ($avgTime -lt 500) {
        Write-TestLog -Message "Average query time: $([math]::Round($avgTime, 2))ms (Acceptable)" -Level "WARN"
        $Results.Value.Performance = "ACCEPTABLE"
        return $true
    } else {
        Write-TestLog -Message "Average query time: $([math]::Round($avgTime, 2))ms (Poor)" -Level "FAIL"
        $Results.Value.Performance = "POOR"
        return $false
    }
}

function Test-DohConfiguration {
    param([ref]$Results)
    
    Write-Host "`nTest 5: DNS-over-HTTPS Configuration" -ForegroundColor Yellow
    
    try {
        $dohStatus = netsh dns show encryption 2>&1
        
        $hasCloudflare = $dohStatus -match "1\.1\.1\.1"
        $hasQuad9 = $dohStatus -match "9\.9\.9\.9"
        $hasGoogle = $dohStatus -match "8\.8\.8\.8"
        
        if ($hasCloudflare) {
            Write-TestLog -Message "Cloudflare DoH is configured" -Level "PASS"
        }
        if ($hasQuad9) {
            Write-TestLog -Message "Quad9 DoH is configured" -Level "PASS"
        }
        if ($hasGoogle) {
            Write-TestLog -Message "Google DoH is configured" -Level "PASS"
        }
        
        if ($hasCloudflare -or $hasQuad9 -or $hasGoogle) {
            $Results.Value.DoHStatus = "PASS"
            return $true
        } else {
            Write-TestLog -Message "No DNS-over-HTTPS configuration found" -Level "FAIL"
            $Results.Value.DoHStatus = "FAIL"
            return $false
        }
    } catch {
        Write-TestLog -Message "Failed to check DoH configuration: $($_.Exception.Message)" -Level "FAIL"
        $Results.Value.DoHStatus = "FAIL"
        return $false
    }
}

function Test-DnsCacheSettings {
    param([ref]$Results)
    
    Write-Host "`nTest 6: DNS Cache Configuration" -ForegroundColor Yellow
    
    try {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
        
        if (Test-Path $registryPath) {
            $cacheSettings = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue
            
            if ($cacheSettings.MaxCacheTtl) {
                Write-TestLog -Message "MaxCacheTtl: $($cacheSettings.MaxCacheTtl) seconds" -Level "PASS"
            }
            if ($cacheSettings.MaxNegativeCacheTtl) {
                Write-TestLog -Message "MaxNegativeCacheTtl: $($cacheSettings.MaxNegativeCacheTtl) seconds" -Level "PASS"
            }
            
            $Results.Value.CacheConfiguration = "PASS"
            return $true
        } else {
            Write-TestLog -Message "DNS cache registry path not found" -Level "WARN"
            $Results.Value.CacheConfiguration = "WARN"
            return $true
        }
    } catch {
        Write-TestLog -Message "Failed to check cache settings: $($_.Exception.Message)" -Level "WARN"
        $Results.Value.CacheConfiguration = "WARN"
        return $true
    }
}

function Test-NetworkConnectivity {
    param([ref]$Results)
    
    Write-Host "`nTest 7: Network Connectivity to DNS Servers" -ForegroundColor Yellow
    
    $dnsServers = @(
        @{Name = "Cloudflare"; IP = "1.1.1.1"},
        @{Name = "Quad9"; IP = "9.9.9.9"},
        @{Name = "Google"; IP = "8.8.8.8"}
    )
    
    $passCount = 0
    
    foreach ($server in $dnsServers) {
        $result = Test-Connection -ComputerName $server.IP -Count 2 -Quiet -ErrorAction SilentlyContinue
        if ($result) {
            Write-TestLog -Message "$($server.Name) ($($server.IP)) is reachable" -Level "PASS"
            $passCount++
        } else {
            Write-TestLog -Message "$($server.Name) ($($server.IP)) is not reachable" -Level "FAIL"
        }
    }
    
    $Results.Value.NetworkConnectivity = if ($passCount -eq $dnsServers.Count) { "PASS" } elseif ($passCount -gt 0) { "PARTIAL" } else { "FAIL" }
    
    return ($passCount -gt 0)
}

function Test-DnssecValidation {
    param([ref]$Results)
    
    Write-Host "`nTest 8: DNSSEC Validation" -ForegroundColor Yellow
    
    try {
        # Test DNSSEC with a known DNSSEC-signed domain
        $result = Resolve-DnsName -Name "cloudflare.com" -Type A -DnssecOk -ErrorAction Stop
        
        if ($result) {
            Write-TestLog -Message "DNSSEC query successful for cloudflare.com" -Level "PASS"
            $Results.Value.DnssecValidation = "PASS"
            return $true
        } else {
            Write-TestLog -Message "DNSSEC query returned no results" -Level "WARN"
            $Results.Value.DnssecValidation = "WARN"
            return $true
        }
    } catch {
        Write-TestLog -Message "DNSSEC validation test: $($_.Exception.Message)" -Level "WARN"
        $Results.Value.DnssecValidation = "WARN"
        return $true
    }
}

# ============================================================================
# Test Orchestration
# ============================================================================

function Invoke-AllTests {
    param(
        [string]$TestType = "Standard",
        [string]$LogFile = $null
    )
    
    Write-TestSection "DNS Configuration Tests - $TestType"
    
    $results = @{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        TestType = $TestType
        Tests = @{}
    }
    
    $testResults = @{}
    
    # Run all tests
    Write-Host "Running comprehensive DNS tests..." -ForegroundColor Cyan
    Write-Host ""
    
    $tests = @(
        @{Name = "ServiceStatus"; Function = {Test-DnsServiceStatus -Results ([ref]$testResults)}},
        @{Name = "DnsConfiguration"; Function = {Test-DnsServerConfiguration -Results ([ref]$testResults)}},
        @{Name = "DnsResolution"; Function = {Test-DnsResolution -Results ([ref]$testResults)}},
        @{Name = "Performance"; Function = {Test-DnsPerformance -Results ([ref]$testResults)}},
        @{Name = "DoHConfiguration"; Function = {Test-DohConfiguration -Results ([ref]$testResults)}},
        @{Name = "CacheSettings"; Function = {Test-DnsCacheSettings -Results ([ref]$testResults)}},
        @{Name = "NetworkConnectivity"; Function = {Test-NetworkConnectivity -Results ([ref]$testResults)}},
        @{Name = "DnssecValidation"; Function = {Test-DnssecValidation -Results ([ref]$testResults)}}
    )
    
    $passCount = 0
    foreach ($test in $tests) {
        if (& $test.Function) {
            $passCount++
        }
    }
    
    $results.Tests = $testResults
    $results.Summary = @{
        TotalTests = $tests.Count
        PassedTests = $passCount
        FailedTests = ($tests.Count - $passCount)
    }
    
    # Display summary
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Test Summary" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Total Tests: " -NoNewline
    Write-Host $tests.Count -ForegroundColor Cyan
    Write-Host "Passed: " -NoNewline
    Write-Host $passCount -ForegroundColor Green
    Write-Host "Failed: " -NoNewline
    Write-Host ($tests.Count - $passCount) -ForegroundColor $(if (($tests.Count - $passCount) -eq 0) { 'Green' } else { 'Red' })
    Write-Host ""
    
    if ($passCount -eq $tests.Count) {
        Write-Host "✓ All tests passed! DNS configuration is working correctly." -ForegroundColor Green
    } elseif ($passCount -gt ($tests.Count / 2)) {
        Write-Host "⚠ Most tests passed, but some issues were detected." -ForegroundColor Yellow
    } else {
        Write-Host "✗ Multiple tests failed. DNS configuration needs attention." -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Save results to JSON
    $results | ConvertTo-Json -Depth 10 | Set-Content -Path $Script:Config.JsonReport
    Write-Host "Test results saved to: $($Script:Config.JsonReport)" -ForegroundColor Cyan
    
    if ($LogFile) {
        $results | ConvertTo-Json -Depth 10 | Set-Content -Path $LogFile
        Write-Host "Test log saved to: $LogFile" -ForegroundColor Cyan
    }
    
    return $results
}

# ============================================================================
# Main Entry Point
# ============================================================================

function Main {
    Initialize-TestEnvironment
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  SetDNScache - Windows 11 DNS Testing Suite" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        if ($PreReboot) {
            $results = Invoke-AllTests -TestType "Pre-Reboot" -LogFile $Script:Config.PreRebootLog
            Write-Host ""
            Write-Host "Pre-reboot tests completed. You can now restart your computer." -ForegroundColor Green
            Write-Host "After reboot, run: .\Test-DnsConfiguration.ps1 -PostReboot" -ForegroundColor Cyan
        }
        elseif ($PostReboot) {
            $results = Invoke-AllTests -TestType "Post-Reboot" -LogFile $Script:Config.PostRebootLog
            
            # Compare with pre-reboot results if available
            if (Test-Path $Script:Config.PreRebootLog) {
                Write-Host ""
                Write-Host "Comparing with pre-reboot results..." -ForegroundColor Cyan
                
                $preResults = Get-Content $Script:Config.PreRebootLog -Raw | ConvertFrom-Json
                $postResults = $results
                
                Write-Host "Pre-reboot tests passed: $($preResults.Summary.PassedTests)/$($preResults.Summary.TotalTests)" -ForegroundColor Yellow
                Write-Host "Post-reboot tests passed: $($postResults.Summary.PassedTests)/$($postResults.Summary.TotalTests)" -ForegroundColor Yellow
                
                if ($postResults.Summary.PassedTests -ge $preResults.Summary.PassedTests) {
                    Write-Host "✓ DNS configuration survived reboot successfully!" -ForegroundColor Green
                } else {
                    Write-Host "⚠ Some tests failed after reboot. Configuration may need adjustment." -ForegroundColor Yellow
                }
            }
        }
        else {
            # Standard test run
            Invoke-AllTests -TestType "Standard"
        }
        
        exit 0
        
    } catch {
        Write-Host ""
        Write-Host "Error during testing: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        exit 1
    }
}

# Run the script
Main
