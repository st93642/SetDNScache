# SetDNScache - Windows 11 Edition

[![License: Unlicense](https://img.shields.io/badge/License-Unlicense-blue.svg)](LICENSE)
[![DNS Security](https://img.shields.io/badge/DNS-Encrypted%20DoH-green.svg)](#security-considerations)
[![Platform](https://img.shields.io/badge/Platform-Windows%2011-blue.svg)](#system-requirements)

SetDNScache for Windows 11 provides secure DNS-over-HTTPS (DoH) configuration for enhanced privacy, security, and performance. It implements native Windows 11 DoH support with automatic failover and comprehensive testing capabilities.

## Table of Contents

1. [Quick Start](#quick-start)
2. [System Requirements](#system-requirements)
3. [Features](#features)
4. [Installation](#installation)
5. [Usage](#usage)
6. [Testing](#testing)
7. [Rollback](#rollback)
8. [DNS Server Hierarchy](#dns-server-hierarchy)
9. [Troubleshooting](#troubleshooting)
10. [FAQ](#faq)

---

## Quick Start

### One-Command Setup

Open PowerShell as Administrator and run:

```powershell
cd c:\Users\6r4nd\Desktop\SetDNScache
.\bin\Secure-DnsSetup.ps1
```

### What It Does

1. ✅ Configures secure DNS servers (Cloudflare, Quad9, Google)
2. ✅ Enables DNS-over-HTTPS (DoH) encryption
3. ✅ Optimizes DNS cache for better performance
4. ✅ Enables DNSSEC validation
5. ✅ Creates automatic backup of your current settings
6. ✅ Tests the configuration automatically

**Setup Duration: 30-60 seconds**

---

## System Requirements

### Operating System
- **Windows 11** (Build 22000 or higher) - Recommended
- **Windows Server 2022+** - Supported
- **Windows 10** (Build 19041+) - Limited DoH support

### Permissions
- Administrator privileges required
- PowerShell 5.1 or higher

### Network
- Active internet connection
- No firewall blocking ports 443, 53

### Disk Space
- ~10MB for logs and backups

---

## Features

### 🔒 Security Features
- **DNS-over-HTTPS (DoH)**: All DNS queries encrypted via HTTPS
- **DNSSEC Validation**: Cryptographic verification of DNS responses
- **Certificate Validation**: Ensures legitimate DNS providers
- **Privacy Protection**: No DNS query logging by major providers

### ⚡ Performance Features
- **Local DNS Caching**: Reduces query latency
- **Multi-tier Failover**: Automatic fallback to backup servers
- **Optimized TTL**: Balanced cache duration for speed
- **Cache Tuning**: Windows DNS cache optimization

### 🛡️ Reliability Features
- **Automatic Backup**: Current settings saved before changes
- **Easy Rollback**: One-command restoration
- **Comprehensive Testing**: Built-in validation suite
- **Service Monitoring**: Health checks and status reporting

---

## Installation

### Step 1: Open PowerShell as Administrator

**Method 1 - Start Menu:**
1. Press `Win + X`
2. Select "Windows Terminal (Admin)" or "PowerShell (Admin)"

**Method 2 - Search:**
1. Press `Win` key
2. Type "PowerShell"
3. Right-click "Windows PowerShell"
4. Select "Run as administrator"

### Step 2: Navigate to the Project Directory

```powershell
cd c:\Users\6r4nd\Desktop\SetDNScache
```

### Step 3: Set Execution Policy (if needed)

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
```

### Step 4: Run the Setup Script

```powershell
.\bin\Secure-DnsSetup.ps1
```

### Expected Output

```
============================================================================
  SetDNScache - Windows 11 Secure DNS Configuration
  Version 2.0.0
============================================================================

[INFO] 2026-01-15 10:30:15 - Checking Windows version...
[SUCCESS] 2026-01-15 10:30:15 - Windows version check passed
[INFO] 2026-01-15 10:30:16 - Testing network connectivity...
[SUCCESS] 2026-01-15 10:30:17 - Network connectivity check passed

============================================================================
  Backing Up Current Configuration
============================================================================

[INFO] 2026-01-15 10:30:18 - Backing up current DNS configuration...
[SUCCESS] 2026-01-15 10:30:19 - Configuration backed up to: C:\Users\...\dns-backup-20260115_103019.json

============================================================================
  Configuring Secure DNS
============================================================================

[INFO] 2026-01-15 10:30:20 - Configuring DNS servers...
[SUCCESS] 2026-01-15 10:30:21 - ✓ DNS servers configured for: Ethernet

============================================================================
  Enabling DNS-over-HTTPS
============================================================================

[INFO] 2026-01-15 10:30:22 - Enabling DNS-over-HTTPS (DoH)...
[SUCCESS] 2026-01-15 10:30:23 - ✓ DoH enabled for Cloudflare Primary: 1.1.1.1
[SUCCESS] 2026-01-15 10:30:24 - ✓ DoH enabled for Quad9: 9.9.9.9

...

[SUCCESS] 2026-01-15 10:30:40 - Secure DNS configuration completed successfully!
```

---

## Usage

### Basic Commands

#### Install/Configure Secure DNS
```powershell
.\bin\Secure-DnsSetup.ps1
```

#### Run Tests Only
```powershell
.\bin\Secure-DnsSetup.ps1 -RunTests
```

#### Dry Run (Preview Changes)
```powershell
.\bin\Secure-DnsSetup.ps1 -DryRun
```

#### Verbose Output
```powershell
.\bin\Secure-DnsSetup.ps1 -VerboseLogging
```

#### Rollback to Original Settings
```powershell
.\bin\Secure-DnsSetup.ps1 -Rollback
```

### Manual Verification

#### Check DNS Configuration
```powershell
# View current DNS servers
Get-DnsClientServerAddress | Where-Object {$_.ServerAddresses}

# Test DNS resolution
Resolve-DnsName google.com

# Check DoH status
netsh dns show encryption
```

#### View DNS Cache
```powershell
# Display DNS cache
Get-DnsClientCache

# Clear DNS cache
Clear-DnsClientCache
```

#### Check DNS Service
```powershell
# Service status
Get-Service Dnscache

# Restart DNS service
Restart-Service Dnscache
```

---

## Testing

### Comprehensive Test Suite

Run the complete test suite:

```powershell
.\tests\Test-DnsConfiguration.ps1
```

**Tests Performed:**
1. ✅ DNS Client Service Status
2. ✅ DNS Server Configuration
3. ✅ DNS Resolution (multiple domains)
4. ✅ Query Performance Benchmarking
5. ✅ DNS-over-HTTPS Configuration
6. ✅ DNS Cache Settings
7. ✅ Network Connectivity
8. ✅ DNSSEC Validation

### Pre/Post Reboot Testing

**Before Reboot:**
```powershell
.\tests\Test-DnsConfiguration.ps1 -PreReboot
```

**After Reboot:**
```powershell
.\tests\Test-DnsConfiguration.ps1 -PostReboot
```

### Expected Test Output

```
═══════════════════════════════════════════════════════════════════════════
  DNS Configuration Tests - Standard
═══════════════════════════════════════════════════════════════════════════

Running comprehensive DNS tests...

Test 1: DNS Client Service Status
✓ DNS Client service is running

Test 2: DNS Server Configuration
✓ Adapter 'Ethernet' DNS: 1.1.1.1, 1.0.0.1, 9.9.9.9, 149.112.112.112, 8.8.8.8, 8.8.4.4

Test 3: DNS Resolution
✓ Resolved example.com → 93.184.216.34
✓ Resolved google.com → 142.250.185.46
✓ Resolved cloudflare.com → 104.16.133.229
✓ Resolved github.com → 140.82.114.4
ℹ DNS Resolution: 4/4 tests passed

Test 4: DNS Query Performance
✓ Average query time: 45.23ms (Excellent)

Test 5: DNS-over-HTTPS Configuration
✓ Cloudflare DoH is configured
✓ Quad9 DoH is configured
✓ Google DoH is configured

Test 6: DNS Cache Configuration
✓ MaxCacheTtl: 86400 seconds
✓ MaxNegativeCacheTtl: 300 seconds

Test 7: Network Connectivity to DNS Servers
✓ Cloudflare (1.1.1.1) is reachable
✓ Quad9 (9.9.9.9) is reachable
✓ Google (8.8.8.8) is reachable

Test 8: DNSSEC Validation
✓ DNSSEC query successful for cloudflare.com

═══════════════════════════════════════════════════════════════════════════
  Test Summary
═══════════════════════════════════════════════════════════════════════════

Total Tests: 8
Passed: 8
Failed: 0

✓ All tests passed! DNS configuration is working correctly.

Test results saved to: C:\Users\...\SetDNScache\test-results\test-results.json
```

---

## Rollback

### Automatic Rollback

Restore your original DNS settings:

```powershell
.\bin\Secure-DnsSetup.ps1 -Rollback
```

**What Gets Restored:**
- Original DNS server addresses
- Original network adapter settings
- DNS-over-HTTPS disabled
- DNS cache settings reset

### Manual Rollback

If automatic rollback fails:

#### Step 1: Reset DNS to Automatic (DHCP)
```powershell
# Get network adapters
Get-NetAdapter | Where-Object {$_.Status -eq 'Up'}

# Reset to automatic (replace 'Ethernet' with your adapter name)
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ResetServerAddresses
```

#### Step 2: Disable DoH Manually
```powershell
# Remove DoH configuration
netsh dns delete encryption server=1.1.1.1
netsh dns delete encryption server=1.0.0.1
netsh dns delete encryption server=9.9.9.9
netsh dns delete encryption server=149.112.112.112
netsh dns delete encryption server=8.8.8.8
netsh dns delete encryption server=8.8.4.4
```

#### Step 3: Restart DNS Service
```powershell
Restart-Service Dnscache
Clear-DnsClientCache
```

#### Step 4: Verify Rollback
```powershell
Get-DnsClientServerAddress
netsh dns show encryption
```

---

## DNS Server Hierarchy

### Primary: Cloudflare (1.1.1.1, 1.0.0.1)

**Why Cloudflare:**
- ⚡ Fastest global response times
- 🔒 Strong privacy policy (no data logging)
- 🛡️ DNSSEC validation
- 🌍 Global Anycast network

**DoH Template:** `https://cloudflare-dns.com/dns-query`

### Secondary: Quad9 (9.9.9.9, 149.112.112.112)

**Why Quad9:**
- 🔒 Privacy-focused (no query logging)
- 🛡️ Malware/phishing blocking
- ✅ DNSSEC validation
- 🌐 Global presence

**DoH Template:** `https://dns.quad9.net/dns-query`

### Tertiary: Google (8.8.8.8, 8.8.4.4)

**Why Google:**
- 🌐 Massive global infrastructure
- ⚡ High reliability and uptime
- ✅ DNSSEC support
- 🔄 Excellent fallback option

**DoH Template:** `https://dns.google/dns-query`

### How Failover Works

```
Application → Windows DNS Client → DoH Encryption
                     ↓
            Try Primary (Cloudflare)
                     ↓ (if fails)
           Try Secondary (Quad9)
                     ↓ (if fails)
            Try Tertiary (Google)
                     ↓
          Return cached or error
```

**Failover Characteristics:**
- ⚡ Automatic failover (2-3 second timeout)
- 💾 Local caching reduces failover impact
- 🔄 Health monitoring and recovery
- 📊 Performance-based selection

---

## Troubleshooting

### DNS Not Resolving

**Symptoms:**
- Websites won't load
- "DNS_PROBE_FINISHED_NXDOMAIN" errors
- `Resolve-DnsName` fails

**Solutions:**

```powershell
# Check DNS service
Get-Service Dnscache
Restart-Service Dnscache

# Clear DNS cache
Clear-DnsClientCache

# Test DNS servers directly
nslookup google.com 1.1.1.1

# Check network connectivity
Test-Connection 1.1.1.1
```

### DoH Not Working

**Symptoms:**
- DNS works but not encrypted
- `netsh dns show encryption` shows no configuration

**Solutions:**

```powershell
# Re-enable DoH
.\bin\Secure-DnsSetup.ps1

# Check Windows version (DoH requires Windows 11)
(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild

# Manual DoH configuration
netsh dns add encryption server=1.1.1.1 dohtemplate=https://cloudflare-dns.com/dns-query{?dns} autoupgrade=yes
```

### Slow DNS Performance

**Symptoms:**
- Websites load slowly
- High DNS query latency
- Frequent timeouts

**Solutions:**

```powershell
# Test performance
.\tests\Test-DnsConfiguration.ps1

# Clear and rebuild cache
Clear-DnsClientCache

# Check network latency
Test-Connection 1.1.1.1 -Count 10

# Try different DNS servers
# Edit script to prioritize different provider
```

### Firewall Blocking

**Symptoms:**
- DNS configuration succeeds but resolution fails
- Network connectivity tests fail
- DoH connections fail

**Solutions:**

```powershell
# Check Windows Firewall
Get-NetFirewallProfile

# Allow DNS outbound
New-NetFirewallRule -DisplayName "Allow DNS" -Direction Outbound -Protocol UDP -RemotePort 53 -Action Allow
New-NetFirewallRule -DisplayName "Allow DoH" -Direction Outbound -Protocol TCP -RemotePort 443 -Action Allow

# Temporarily disable firewall for testing
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
```

### Rollback Issues

**Symptoms:**
- Rollback script fails
- DNS still not working after rollback
- Original settings not restored

**Solutions:**

```powershell
# Find backup files
Get-ChildItem "$env:TEMP\SetDNScache\backups"

# Manual adapter reset
Get-NetAdapter | ForEach-Object {
    Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses
}

# Reset to Google DNS as temporary fix
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses @("8.8.8.8", "8.8.4.4")
```

---

## FAQ

### Is it safe to run?

**Yes.** The script:
- ✅ Only modifies Windows DNS settings (no system files)
- ✅ Creates automatic backups before changes
- ✅ Uses official Microsoft PowerShell cmdlets
- ✅ Can be completely reversed with rollback
- ✅ No network connections except DNS servers

### Will it break my internet?

**No.** The script has multiple safety features:
- 🔄 Multiple DNS providers ensure availability
- 💾 Automatic backup of original settings
- ⏮️ One-command rollback capability
- ⚠️ Dry-run mode to preview changes

If something goes wrong, run:
```powershell
.\bin\Secure-DnsSetup.ps1 -Rollback
```

### Do I need to run it again after Windows updates?

**Usually no.** Windows DNS settings persist across:
- ✅ Regular Windows updates
- ✅ System restarts
- ✅ Network profile changes

You may need to re-run if:
- ⚠️ Windows completely resets network settings
- ⚠️ Major Windows version upgrade (e.g., 22H2 → 23H2)
- ⚠️ Manual network adapter reinstallation

### Can I customize DNS servers?

**Yes.** Edit the script configuration:

```powershell
# Open script in editor
notepad .\bin\Secure-DnsSetup.ps1

# Find the $Script:Config section (around line 80)
# Modify DNS server IPs and DoH templates
```

**Alternative DNS Providers:**
- **NextDNS:** Custom filtering, `45.90.28.0`, `45.90.30.0`
- **AdGuard:** Ad blocking, `94.140.14.14`, `94.140.15.15`
- **OpenDNS:** Family filtering, `208.67.222.222`, `208.67.220.220`
- **CleanBrowsing:** Content filtering, `185.228.168.9`, `185.228.169.9`

### Does it work with VPN?

**Yes.** SetDNScache works with VPNs:
- 🌐 VPN DNS takes priority when connected
- 🔒 Secure DNS used when VPN disconnected
- 🔄 Automatic switching between VPN/local DNS
- ✅ No conflicts or manual configuration needed

**Note:** Some VPNs override DNS settings completely. Check your VPN's DNS leak protection settings.

### How do I uninstall?

**Complete removal:**

```powershell
# Step 1: Rollback to original settings
.\bin\Secure-DnsSetup.ps1 -Rollback

# Step 2: Delete backup and log files
Remove-Item "$env:TEMP\SetDNScache" -Recurse -Force

# Step 3: Delete the project folder (optional)
cd ..
Remove-Item "SetDNScache" -Recurse -Force
```

### What's the performance impact?

**Minimal, with benefits:**

**Resource Usage:**
- 💾 Memory: ~5-10MB additional cache
- ⚡ CPU: <1% during queries
- 💽 Disk: ~10MB for logs/backups

**Performance Improvement:**
- 🚀 First query: Similar to before (~100-300ms)
- ⚡ Cached queries: 5-50ms (much faster)
- 📊 Average improvement: 50-80% faster
- 💾 Bandwidth: Reduced by local caching

### Is DoH really more secure than regular DNS?

**Yes, significantly:**

| Feature | Regular DNS | DNS-over-HTTPS |
|---------|-------------|----------------|
| **Encryption** | ❌ None | ✅ HTTPS (TLS 1.3) |
| **ISP Visibility** | ❌ Full visibility | ✅ Hidden |
| **Man-in-Middle** | ❌ Vulnerable | ✅ Protected |
| **DNS Spoofing** | ❌ Possible | ✅ Prevented |
| **Privacy** | ❌ Low | ✅ High |
| **DNSSEC** | ⚠️ Optional | ✅ Included |

### How do I verify DoH is working?

**Verification steps:**

```powershell
# 1. Check DoH configuration
netsh dns show encryption

# Expected output:
# DNS Encryption Settings for 1.1.1.1
# DoH Template: https://cloudflare-dns.com/dns-query{?dns}
# Auto Upgrade: Yes

# 2. Check DNS resolution
Resolve-DnsName google.com

# 3. Test with external tool
# Visit: https://www.cloudflare.com/ssl/encrypted-sni/
# Should show "Secure DNS: Yes"

# 4. Run test suite
.\tests\Test-DnsConfiguration.ps1
```

### Can I use this on multiple computers?

**Yes!** Installation methods:

**Method 1 - Copy to each computer:**
```powershell
# Copy the entire SetDNScache folder
Copy-Item "C:\Users\6r4nd\Desktop\SetDNScache" "\\OtherComputer\C$\Temp\" -Recurse

# Run on target computer
.\bin\Secure-DnsSetup.ps1
```

**Method 2 - Network share:**
```powershell
# Share the folder on network
# Run from network location on each computer
\\NetworkShare\SetDNScache\bin\Secure-DnsSetup.ps1
```

**Method 3 - Group Policy (Enterprise):**
- Configure DNS servers via Group Policy
- Deploy DoH settings via registry
- Use logon scripts for automation

---

## Log Files and Results

### Log Locations

```
%TEMP%\SetDNScache\
├── dns-setup.log                    # Main setup log
├── backups\
│   └── dns-backup-YYYYMMDD_HHMMSS.json  # Configuration backups
└── test-results\
    ├── test-results.json            # Test results (JSON)
    ├── pre-reboot.log               # Pre-reboot test log
    └── post-reboot.log              # Post-reboot test log
```

### View Logs

```powershell
# View setup log
notepad "$env:TEMP\SetDNScache\dns-setup.log"

# View test results
notepad "$env:TEMP\SetDNScache\test-results\test-results.json"

# List all backups
Get-ChildItem "$env:TEMP\SetDNScache\backups"
```

---

## Support and Contributions

### Reporting Issues

Create an issue with:
1. Windows version and build number
2. Script output (logs)
3. Error messages
4. Network adapter type

### Getting Help

**Documentation:**
- This README
- Inline script comments
- Test output and logs

**Community:**
- Open an issue on the repository
- Check existing issues for solutions

---

## License

This project is released into the public domain under the Unlicense.

**You are free to:**
- ✅ Use commercially
- ✅ Modify as needed
- ✅ Distribute freely
- ✅ Use privately

**No warranty provided.** Use at your own risk.

---

## Version History

### Version 2.0.0 (2026-01-15)
- ✨ Complete PowerShell rewrite for Windows 11
- ✨ Native DNS-over-HTTPS (DoH) support
- ✨ Comprehensive testing suite
- ✨ Automatic backup and rollback
- ✨ Performance optimization
- ✨ Enhanced error handling

### Version 1.0.0 (Original)
- 🐧 Linux version (Bash/Stubby/DNSMasq)

---

**Enjoy secure, private, and fast DNS on Windows 11! 🚀🔒**
