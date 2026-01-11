# SetDNScache - Secure DNS with Local Caching

[![License: Unlicense](https://img.shields.io/badge/License-Unlicense-blue.svg)](LICENSE)
[![DNS Security](https://img.shields.io/badge/DNS-Encrypted%20%2B%20DNSSEC-green.svg)](#security-considerations)
[![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey.svg)](#system-requirements)

SetDNScache provides secure DNS over TLS with local caching for enhanced privacy, security, and performance. It implements a robust DNS hierarchy with automatic failover, DNSSEC validation, and comprehensive testing capabilities.

## Table of Contents

1. [Project Overview](#project-overview)
2. [Quick Start Guide](#quick-start-guide)
3. [DNS Server Hierarchy](#dns-server-hierarchy-explanation)
4. [Pre-Deployment Checklist](#pre-deployment-checklist)
5. [Installation & Configuration](#installation--configuration)
6. [Local Connectivity Testing](#local-connectivity-testing)
7. [Reboot Survival Testing](#reboot-survival-testing)
8. [Usage & Command Reference](#usage--command-reference)
9. [Verification & Debugging](#verification--debugging)
10. [Configuration Customization](#configuration-customization)
11. [Troubleshooting Guide](#troubleshooting-guide)
12. [Security Considerations](#security-considerations)
13. [Performance Notes](#performance-notes)
14. [Rollback & Uninstallation](#rollback--uninstallation)
15. [Advanced Topics](#advanced-topics)
16. [FAQ](#faq)
17. [Log File Reference](#log-file-reference)
18. [File Structure Reference](#file-structure-reference)
19. [Support & Contributing](#support--contributing)
20. [Examples & Use Cases](#examples--use-cases)

---

## Project Overview

### What SetDNScache Does

SetDNScache is a comprehensive DNS security solution that implements **DNS over TLS (DoT)** with local caching to provide:

- **Privacy**: All DNS queries are encrypted using TLS, preventing ISP surveillance and man-in-the-middle attacks
- **Security**: DNSSEC validation ensures DNS response integrity and authenticity
- **Performance**: Local DNS caching reduces query latency and network traffic
- **Reliability**: Multi-tier DNS server hierarchy with automatic failover

### Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Applications  │    │   Applications  │    │   Applications  │
│                 │    │                 │    │                 │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────┬─────────────────────┬───────┘
                         │                     │
                  ┌──────▼──────┐      ┌──────▼──────┐
                  │   DNSMasq   │      │   DNSMasq   │
                  │   Port 53   │      │   Port 53   │
                  │ (Local DNS) │      │ (Local DNS) │
                  └──────┬──────┘      └──────┬──────┘
                         │                     │
                  ┌──────▼──────┐      ┌──────▼──────┐
                  │    Stubby   │      │    Stubby   │
                  │   Port 5353 │      │   Port 5353 │
                  │ (DNS over   │      │ (DNS over   │
                  │   TLS)      │      │   TLS)      │
                  └──────┬──────┘      └──────┬──────┘
                         │                     │
              ┌──────────┼─────────────────────┼──────────┐
              │          │                     │          │
         ┌────▼─────┐ ┌──▼────┐           ┌───▼────┐ ┌───▼────┐
         │Cloudflare│ │ Quad9 │           │ Google │ │ Google │
         │Port 853 │ │Port 853│           │Port 853│ │Port 853│
         │(Primary)│ │(Sec.) │           │(Tert.) │ │(Tert.) │
         └──────────┘ └───────┘           └────────┘ └────────┘
```

**Key Components:**
- **Stubby**: Handles DNS-over-TLS connections to upstream servers
- **DNSMasq**: Provides local DNS caching and serves requests to applications
- **DNSSEC**: Validates DNS response signatures for security

### Why It Matters

- **Privacy Protection**: Your ISP cannot see or log your DNS queries
- **Security Enhancement**: DNSSEC validation prevents DNS spoofing attacks
- **Performance Boost**: Local caching reduces repeated query latency
- **Network Reliability**: Multiple DNS providers ensure service availability

### System Requirements

- **Operating System**: Debian-based Linux distributions
  - Ubuntu 18.04 LTS or newer
  - Debian 9 (Stretch) or newer
  - Linux Mint 19 or newer
  - Pop!_OS 18.04 or newer
  - Elementary OS 5.0 or newer

- **Access Level**: Root or sudo privileges required
- **Disk Space**: ~50MB for packages and configuration
- **Network**: Internet connection for DNS over TLS
- **Memory**: ~20MB additional RAM usage
- **Services**: Must be able to stop conflicting DNS services

### Supported Distributions

| Distribution | Version | Status | Notes |
|--------------|---------|--------|-------|
| Ubuntu | 18.04+ | ✅ Fully Supported | Recommended |
| Ubuntu | 20.04+ | ✅ Fully Supported | Latest LTS recommended |
| Ubuntu | 22.04+ | ✅ Fully Supported | Latest stable |
| Debian | 9+ | ✅ Fully Supported | Stable releases |
| Linux Mint | 19+ | ✅ Fully Supported | Based on Ubuntu 18.04+ |
| Pop!_OS | 18.04+ | ✅ Fully Supported | System76 optimized |
| Elementary OS | 5.0+ | ✅ Fully Supported | Ubuntu-based |
| Zorin OS | 15+ | ✅ Fully Supported | Ubuntu-based |

**Note**: Other Debian-based distributions may work but are not officially tested.

---

## Quick Start Guide

### One-Command Setup

Execute the following command to set up secure DNS with local caching:

```bash
sudo bash bin/secure-dns-setup.sh
```

### What Happens During Setup

1. **Pre-flight Checks** (10-15 seconds)
   - Validates root/sudo access
   - Checks system compatibility
   - Verifies network connectivity
   - Backs up existing DNS configuration

2. **Dependency Installation** (30-60 seconds)
   - Installs Stubby (DNS over TLS client)
   - Installs DNSMasq (local DNS cache)
   - Installs testing utilities (dig, nslookup)

3. **Service Configuration** (20-30 seconds)
   - Configures Stubby with TLS endpoints
   - Sets up DNSMasq for local caching
   - Creates system service configurations
   - Backs up original `/etc/resolv.conf`

4. **Service Activation** (10-15 seconds)
   - Stops conflicting DNS services
   - Starts Stubby on port 5353
   - Starts DNSMasq on port 53
   - Updates system resolver configuration

5. **Validation Tests** (15-20 seconds)
   - DNS resolution tests
   - Port connectivity verification
   - Service health checks
   - DNSSEC validation

### Expected Output/Logs

**Typical successful setup output:**
```
============================================================================
  SetDNScache - Secure DNS Setup
============================================================================
[INFO] 2024-01-11 13:52:15 - Starting secure DNS configuration...
[INFO] 2024-01-11 13:52:15 - This script must be run as root (use sudo)
[INFO] 2024-01-11 13:52:15 - Checking required dependencies...
[INFO] 2024-01-11 13:52:16 - Installing dependencies...
[INFO] 2024-01-11 13:52:45 - Configuring Stubby with DNS-over-TLS...
[INFO] 2024-01-11 13:52:46 - Configuring DNSMasq for local caching...
[INFO] 2024-01-11 13:52:47 - Starting services...
[INFO] 2024-01-11 13:52:48 - Running connectivity tests...
[INFO] 2024-01-11 13:52:50 - DNS resolution test: PASS
[INFO] 2024-01-11 13:52:50 - DNSSEC validation test: PASS
[INFO] 2024-01-11 13:52:51 - Setup completed successfully!
```

**Complete setup duration: 90-140 seconds (1.5-2.5 minutes)**

### Success Indicators

✅ **All tests pass** with green checkmarks  
✅ **Services active** - both Stubby and DNSMasq running  
✅ **DNS resolution working** - can resolve domains  
✅ **No error messages** in output  
✅ **Log file created** at `/var/log/dns-setup.log`

---

## DNS Server Hierarchy Explanation

### Primary: Cloudflare (1.1.1.1, 1.0.0.1)

**Why Cloudflare as Primary:**
- **Fastest Response Times**: Global Anycast network
- **Privacy Focused**: No query logging, no sale of data
- **High Availability**: 99.99% uptime SLA
- **Security Features**: DNSSEC validation, malware blocking
- **TLS 1.3 Support**: Latest encryption standards

**Features:**
- DNS over TLS (DoT) on port 853
- DNSSEC signing enabled
- Malware protection available
- IPv4 and IPv6 support
- Built-in rate limiting

**Performance Characteristics:**
- Average latency: <20ms globally
- Cache hit ratio: >95%
- Global presence: 200+ data centers

### Secondary: Quad9 (9.9.9.9, 149.112.112.112)

**Why Quad9 as Secondary:**
- **Privacy Focused**: No personal data collection
- **Security Oriented**: Blocks malicious domains
- **Global Network**: 150+ locations worldwide
- **DNSSEC Validation**: Ensures response integrity
- **Open Source**: Transparent operations

**Features:**
- DNS over TLS (DoT) on port 853
- DNSSEC validation
- Malware/threat intelligence blocking
- IPv4 and IPv6 support
- Privacy by design (no logging)

**When Quad9 is Used:**
- Primary Cloudflare unavailable
- Manual failover configuration
- Geographic routing optimization

### Tertiary: Google (8.8.8.8, 8.8.4.4)

**Why Google as Tertiary:**
- **Reliability**: Massive infrastructure
- **Performance**: Extensive global network
- **Fallback Option**: When other providers fail
- **Features**: DNSSEC, safe browsing
- **Availability**: Most stable DNS provider

**Features:**
- DNS over TLS (DoT) on port 853
- DNSSEC validation
- Safe browsing features
- IPv4 and IPv6 support
- High-performance global network

**When Google is Used:**
- Both Cloudflare and Quad9 unavailable
- Manual configuration fallback
- Emergency resolution backup

### How Failover Works

```
Request Flow:
1. Application queries DNSMasq (port 53)
2. DNSMasq checks local cache
3. If not cached, queries Stubby (port 5353)
4. Stubby tries Cloudflare (primary)
5. If Cloudflare fails, tries Quad9 (secondary)
6. If Quad9 fails, tries Google (tertiary)
7. Response cached by DNSMasq for future requests
8. Response returned to application
```

**Automatic Failover Characteristics:**
- **Timeout-based**: 2-3 second timeout per server
- **Health checking**: Continuous availability monitoring
- **Caching behavior**: Successful responses cached for performance
- **No data loss**: Previous successful responses retained

### Why This Hierarchy

**1. Speed Optimization**
- Cloudflare: Fastest response times globally
- Quad9: Good performance with privacy focus
- Google: Reliable fallback with excellent coverage

**2. Reliability Assurance**
- Multiple providers reduce single point of failure
- Geographic distribution ensures local availability
- Diverse infrastructure prevents correlated outages

**3. Privacy Balance**
- Cloudflare: Privacy-focused but not perfect
- Quad9: Strong privacy guarantees
- Google: Good performance but privacy concerns

**4. Security Coverage**
- All providers support DNSSEC validation
- Each has different threat intelligence
- Multiple security perspectives reduce blind spots

### Customizing Servers (Advanced)

**Editing DNS Servers:**

```bash
sudo nano /etc/stubby/stubby.yml
```

**Configuration Structure:**
```yaml
upstream_recursive_servers:
  - address_data: 1.1.1.1
    tls_auth_name: "cloudflare-dns.com"
    tls_port: 853
  - address_data: 9.9.9.9
    tls_auth_name: "dns.quad9.net"
    tls_port: 853
```

**Requirements for Custom Servers:**
- Must support DNS over TLS (DoT)
- Must support DNSSEC validation
- Should have reliable global connectivity
- Must use TLS port 853 (standard DoT port)

**Recommended Custom Providers:**
- **NextDNS**: Custom filtering and privacy
- **CleanBrowsing**: Family-safe filtering
- **AdGuard**: Ad blocking DNS
- **OpenDNS**: Enterprise security features

---

## Pre-Deployment Checklist

### 1. Verify Root/Sudo Access

**Check current privileges:**
```bash
# Check if running as root
whoami

# Check sudo access
sudo -l

# Test sudo with a simple command
sudo ls /etc
```

**Expected Results:**
- `whoami` shows `root` or you can use sudo
- `sudo -l` shows no restrictions or minimal restrictions
- `sudo ls /etc` executes without password prompts (or with cached credentials)

**If no sudo access:**
```bash
# Add user to sudo group (requires existing sudoer)
sudo usermod -aG sudo $USER

# Alternative: create sudo password
sudo passwd $USER
```

### 2. Check for Existing DNS Services

**Identify conflicting services:**
```bash
# Check systemd-resolved status
systemctl status systemd-resolved

# Check for bind9
systemctl status bind9

# Check for custom DNS services
ps aux | grep -E "(named|bind|dnsmasq|unbound)"

# Check current DNS configuration
cat /etc/resolv.conf

# Check for other DNS processes
netstat -tuln | grep :53
```

**Expected Results:**
- `systemctl status systemd-resolved` shows service status
- No other DNS services should be listening on port 53
- Current DNS servers listed in `/etc/resolv.conf`

**If conflicts found:**
```bash
# Stop systemd-resolved temporarily (backup current config first)
sudo systemctl stop systemd-resolved

# Disable systemd-resolved from starting on boot
sudo systemctl disable systemd-resolved

# Check what other services need to be stopped
sudo systemctl stop bind9
sudo systemctl disable bind9
```

### 3. Ensure Network Connectivity

**Test internet connectivity:**
```bash
# Test basic connectivity
ping -c 3 8.8.8.8

# Test DNS resolution
nslookup google.com

# Test HTTPS connectivity
curl -I https://cloudflare-dns.com

# Check firewall status
sudo ufw status
sudo iptables -L
```

**Expected Results:**
- Ping to external IPs successful
- DNS resolution working before setup
- HTTPS connections to cloudflare-dns.com successful
- Firewall allows outbound connections on port 853

**If connectivity issues:**
```bash
# Check network interfaces
ip addr show

# Check routing
ip route show

# Test specific DNS servers
dig @1.1.1.1 google.com
dig @9.9.9.9 google.com
```

### 4. Backup Current /etc/resolv.conf

**Create backup:**
```bash
# Backup current DNS configuration
sudo cp /etc/resolv.conf /etc/resolv.conf.backup.$(date +%Y%m%d_%H%M%S)

# Verify backup was created
ls -la /etc/resolv.conf.backup.*

# Show current configuration
cat /etc/resolv.conf
```

**Expected backup location:**
- `/etc/resolv.conf.backup.YYYYMMDD_HHMMSS`
- Original permissions and ownership preserved

**Restoring if needed:**
```bash
# Restore original configuration
sudo cp /etc/resolv.conf.backup.YYYYMMDD_HHMMSS /etc/resolv.conf

# Restart network services if needed
sudo systemctl restart networking
```

### 5. Verify Disk Space

**Check available disk space:**
```bash
# Check root filesystem
df -h /

# Check if enough space for packages
df -h /var/lib/apt

# Check memory availability
free -h

# Check tmp space
df -h /tmp
```

**Expected Requirements:**
- **Root filesystem**: At least 200MB free space
- **APT cache**: At least 100MB free space
- **Memory**: At least 500MB RAM available
- **Temporary space**: At least 50MB in /tmp

**If low on space:**
```bash
# Clean package cache
sudo apt clean
sudo apt autoclean

# Remove old kernels
sudo apt autoremove

# Clean temporary files
sudo rm -rf /tmp/*
```

### 6. Note Current DNS Configuration

**Document existing setup:**
```bash
# Record current DNS servers
echo "=== Current DNS Configuration ===" > /tmp/dns-backup-info.txt
date >> /tmp/dns-backup-info.txt
cat /etc/resolv.conf >> /tmp/dns-backup-info.txt

# Record active DNS services
echo -e "\n=== Active DNS Services ===" >> /tmp/dns-backup-info.txt
systemctl list-units --all | grep dns >> /tmp/dns-backup-info.txt

# Record network configuration
echo -e "\n=== Network Configuration ===" >> /tmp/dns-backup-info.txt
ip route show >> /tmp/dns-backup-info.txt

# Display the information
cat /tmp/dns-backup-info.txt
```

**Information to Record:**
- Current DNS servers (nameserver entries)
- Active DNS-related services
- Network routing configuration
- Domain search paths
- DNS timeout settings

---

## Installation & Configuration

### Step-by-Step Setup Instructions

#### Step 1: Navigate to Project Directory

```bash
# Clone or navigate to SetDNScache directory
cd /path/to/SetDNScache

# Verify project structure
ls -la
```

#### Step 2: Make Scripts Executable

```bash
# Ensure scripts have execute permissions
chmod +x bin/secure-dns-setup.sh
chmod +x tests/*.sh
```

#### Step 3: Run the Setup Script

```bash
# Full installation with configuration
sudo bash bin/secure-dns-setup.sh
```

**For verbose output:**
```bash
sudo bash bin/secure-dns-setup.sh --verbose
```

**For testing only (no changes):**
```bash
sudo bash bin/secure-dns-setup.sh --run-tests
```

#### Step 4: Verify Installation

```bash
# Check service status
systemctl status stubby
systemctl status dnsmasq

# Test DNS resolution
nslookup google.com

# Check listening ports
netstat -tuln | grep -E ":53|:5353"
```

### What Each Step Does

#### Pre-flight Checks
- **Root validation**: Ensures script runs with proper privileges
- **Dependency verification**: Checks for required system tools
- **Network connectivity**: Validates internet access
- **System compatibility**: Confirms OS and version support

#### Dependency Installation
- **Stubby installation**: Adds DNS-over-TLS client
- **DNSMasq installation**: Adds local DNS caching daemon
- **Testing utilities**: Installs dig, nslookup for validation
- **System configuration**: Prepares service configurations

#### Service Configuration
- **Stubby YAML configuration**: Sets up TLS endpoints and authentication
- **DNSMasq configuration**: Defines cache settings and upstream servers
- **Service file creation**: Enables systemd service integration
- **Permission setup**: Ensures proper file ownership and access

#### Service Activation
- **Conflicting service stopping**: Disables existing DNS services
- **Stubby service start**: Launches DNS-over-TLS client
- **DNSMasq service start**: Activates local DNS cache
- **Resolver update**: Points system to new DNS infrastructure

### Configuration File Locations

| Component | Configuration File | Purpose |
|-----------|-------------------|---------|
| **Stubby** | `/etc/stubby/stubby.yml` | DNS-over-TLS settings, upstream servers |
| **DNSMasq** | `/etc/dnsmasq.conf` | Cache settings, local DNS options |
| **DNSMasq** | `/etc/dnsmasq.d/dns-stubby.conf` | Integration with Stubby |
| **System Resolver** | `/etc/resolv.conf` | System-wide DNS configuration |
| **Service Files** | `/etc/systemd/system/stubby.service` | Stubby systemd service |
| **Service Files** | `/etc/systemd/system/dnsmasq.service` | DNSMasq systemd service |

### Port Assignments

| Service | Port | Purpose | Protocol |
|---------|------|---------|----------|
| **DNSMasq** | 53 | Local DNS service | UDP/TCP |
| **Stubby** | 5353 | Local DNS-over-TLS proxy | UDP/TCP |
| **Upstream DoT** | 853 | Encrypted DNS to providers | TCP |
| **System Resolver** | 53 | Application DNS queries | UDP/TCP |

**Port Conflict Resolution:**
- **Port 53**: Stops any existing DNS service
- **Port 5353**: Typically unused by default
- **Port 853**: External TLS connections only

### Service Dependencies

```
Application Requests
        ↓
System Resolver (/etc/resolv.conf)
        ↓
DNSMasq Service (dnsmasq.service)
        ↓
Stubby Service (stubby.service)
        ↓
Upstream DNS-over-TLS (Port 853)
        ↓
DNS Providers (Cloudflare/Quad9/Google)
```

**Service Startup Order:**
1. **stubby.service**: Must start first (provides DNS-over-TLS)
2. **dnsmasq.service**: Starts after stubby (consumes DoT service)
3. **network.target**: Dependencies for connectivity

### How Idempotency Works

The setup script is **idempotent**, meaning it can be run multiple times safely:

**What happens on re-runs:**
- **Existing configuration preserved**: No changes if already correct
- **Services restarted**: Updated configuration applied
- **Dependencies checked**: Missing packages installed
- **Tests re-run**: Validation performed each time

**Safe re-execution scenarios:**
```bash
# Update configuration
sudo bash bin/secure-dns-setup.sh --verbose

# Test after manual changes
sudo bash bin/secure-dns-setup.sh --run-tests

# Restore after rollback
sudo bash bin/secure-dns-setup.sh
```

**Benefits of idempotency:**
- **Recovery from failures**: Can re-run after interruption
- **Configuration updates**: Safe to apply changes
- **Troubleshooting**: Can re-run tests without full reinstall
- **Multiple installations**: Works across different systems

---

## Local Connectivity Testing

### Running Tests with --run-tests Flag

Execute comprehensive connectivity testing:

```bash
# Run all connectivity tests
sudo bash bin/secure-dns-setup.sh --run-tests

# Run tests with verbose output
sudo bash bin/secure-dns-setup.sh --run-tests --verbose
```

**Expected test duration:** 30-60 seconds  
**Test location:** Performed locally without configuration changes

### Understanding Test Output

**Successful test output example:**
```
============================================================================
  DNS Connectivity Tests
============================================================================
[INFO] 2024-01-11 13:52:15 - Starting connectivity tests...
[INFO] 2024-01-11 13:52:15 - Checking required dependencies...
[INFO] 2024-01-11 13:52:16 - All dependencies found: dig, nslookup, systemctl
[INFO] 2024-01-11 13:52:17 - Testing DNS resolution...
[INFO] 2024-01-11 13:52:18 - DNS resolution for google.com: PASS
[INFO] 2024-01-11 13:52:18 - DNS resolution for cloudflare.com: PASS
[INFO] 2024-01-11 13:52:19 - DNS resolution for example.com: PASS
[INFO] 2024-01-11 13:52:20 - Testing port connectivity...
[INFO] 2024-01-11 13:52:20 - Port 53 (DNSMasq): OPEN
[INFO] 2024-01-11 13:52:21 - Port 5353 (Stubby): OPEN
[INFO] 2024-01-11 13:52:22 - Testing service status...
[INFO] 2024-01-11 13:52:22 - DNSMasq service: ACTIVE
[INFO] 2024-01-11 13:52:23 - Stubby service: ACTIVE
[INFO] 2024-01-11 13:52:24 - Testing DNSSEC validation...
[INFO] 2024-01-11 13:52:25 - DNSSEC validation test: PASS
[INFO] 2024-01-11 13:52:26 - Measuring latency...
[INFO] 2024-01-11 13:52:27 - Average query latency: 45ms
[INFO] 2024-01-11 13:52:28 - Testing fallback servers...
[INFO] 2024-01-11 13:52:29 - Cloudflare connectivity: PASS
[INFO] 2024-01-11 13:52:30 - Quad9 connectivity: PASS
[INFO] 2024-01-11 13:52:31 - Google connectivity: PASS
[INFO] 2024-01-11 13:52:32 - All tests completed successfully!
```

### What Each Test Verifies

#### 1. DNS Resolution Test

**Purpose:** Validates that DNS queries can be resolved through the secure DNS chain

**Test domains:** google.com, cloudflare.com, example.com

**What it tests:**
- Local DNS resolution through DNSMasq
- Stubby connectivity to upstream servers
- End-to-end query resolution
- Response validity and completeness

**Success criteria:**
- All test domains resolve to valid IP addresses
- No timeout or connection errors
- Consistent results across multiple domains

**Sample successful output:**
```
[INFO] 2024-01-11 13:52:18 - Testing DNS resolution...
[INFO] 2024-01-11 13:52:18 - DNS resolution for google.com: PASS
[INFO] 2024-01-11 13:52:18 - DNS resolution for cloudflare.com: PASS
[INFO] 2024-01-11 13:52:19 - DNS resolution for example.com: PASS
```

#### 2. Port Connectivity Test

**Purpose:** Confirms required network ports are listening and accessible

**Ports tested:**
- **Port 53**: DNSMasq local DNS service
- **Port 5353**: Stubby DNS-over-TLS proxy

**What it tests:**
- DNSMasq service is listening on port 53
- Stubby service is listening on port 5353
- No port conflicts or access restrictions
- Firewall rules permit local connections

**Success criteria:**
- Both ports show as "OPEN" or "LISTENING"
- No "Address already in use" errors
- Local connections accepted

**Sample successful output:**
```
[INFO] 2024-01-11 13:52:20 - Testing port connectivity...
[INFO] 2024-01-11 13:52:20 - Port 53 (DNSMasq): OPEN
[INFO] 2024-01-11 13:52:21 - Port 5353 (Stubby): OPEN
```

#### 3. Service Status Test

**Purpose:** Verifies systemd services are running and healthy

**Services tested:**
- **stubby.service**: DNS-over-TLS client
- **dnsmasq.service**: Local DNS caching daemon

**What it tests:**
- Services are enabled to start on boot
- Services are currently active (running)
- No systemd service errors or failures
- Service restart capabilities

**Success criteria:**
- Both services show "active (running)" status
- No recent service failures
- Services can be queried without errors

**Sample successful output:**
```
[INFO] 2024-01-11 13:52:22 - Testing service status...
[INFO] 2024-01-11 13:52:22 - DNSMasq service: ACTIVE
[INFO] 2024-01-11 13:52:23 - Stubby service: ACTIVE
```

#### 4. DNSSEC Validation Test

**Purpose:** Confirms DNSSEC validation is working for DNS response integrity

**Test method:** Uses `dig +dnssec` to query DNSSEC-signed domains

**What it tests:**
- DNSSEC validation is enabled in Stubby
- Valid signatures are being verified
- Invalid/compromised responses are rejected
- Trust chain validation works correctly

**Success criteria:**
- DNSSEC responses show validation flags
- No "Bogus" or validation failure messages
- AD (Authenticated Data) flag present in responses

**Sample successful output:**
```
[INFO] 2024-01-11 13:52:24 - Testing DNSSEC validation...
[INFO] 2024-01-11 13:52:25 - DNSSEC validation test: PASS
```

**Manual verification:**
```bash
# Check DNSSEC validation manually
dig +dnssec cloudflare.com

# Look for AD flag in output
# Should show: flags: qr rd ra ad; ...
```

#### 5. Latency Measurement

**Purpose:** Measures query response times to assess performance

**Test method:** Multiple DNS queries with timing statistics

**What it measures:**
- Average query latency
- Cache hit vs. cache miss performance
- Server response consistency
- Overall DNS performance impact

**Success criteria:**
- Latency under 100ms for cached queries
- Latency under 500ms for uncached queries
- Consistent performance across multiple queries

**Sample successful output:**
```
[INFO] 2024-01-11 13:52:26 - Measuring latency...
[INFO] 2024-01-11 13:52:27 - Average query latency: 45ms
```

**Performance benchmarks:**
- **Excellent**: < 30ms
- **Good**: 30-60ms
- **Acceptable**: 60-100ms
- **Poor**: > 100ms

#### 6. Fallback Server Verification

**Purpose:** Tests connectivity to all configured DNS providers

**Servers tested:**
- **Cloudflare**: Primary DNS provider
- **Quad9**: Secondary DNS provider
- **Google**: Tertiary DNS provider

**What it tests:**
- Each provider's DoT endpoint is reachable
- TLS connections can be established
- Providers respond to DNS queries
- Failover capabilities are available

**Success criteria:**
- All providers respond successfully
- TLS connection establishment works
- DNS queries return valid responses
- No timeout or connection failures

**Sample successful output:**
```
[INFO] 2024-01-11 13:52:28 - Testing fallback servers...
[INFO] 2024-01-11 13:52:29 - Cloudflare connectivity: PASS
[INFO] 2024-01-11 13:52:30 - Quad9 connectivity: PASS
[INFO] 2024-01-11 13:52:31 - Google connectivity: PASS
```

### Interpreting Test Results

#### Success Indicators

**All Tests Pass (Green):**
- ✅ DNS resolution: All domains resolve successfully
- ✅ Port connectivity: Required ports open and accessible  
- ✅ Service status: Both services active and running
- ✅ DNSSEC validation: Security signatures verified
- ✅ Latency: Response times within acceptable ranges
- ✅ Fallback servers: All DNS providers reachable

**Configuration Status:**
- Secure DNS is properly configured
- All components are functional
- System is ready for production use

#### Warning Indicators

**Partial Failures (Yellow):**
- ⚠️ Some DNS providers unreachable (but others work)
- ⚠️ Slightly elevated latency (but still functional)
- ⚠️ Non-critical service dependencies missing

**Actions Required:**
- Monitor for degraded performance
- Consider troubleshooting network issues
- May still be usable for production

#### Failure Indicators

**Critical Failures (Red):**
- ❌ DNS resolution fails for all domains
- ❌ Required ports not accessible
- ❌ Services not running or failing
- ❌ DNSSEC validation broken
- ❌ No DNS providers reachable

**Actions Required:**
- Do not use for production
- Run troubleshooting procedures
- May need to rollback configuration
- Investigate root cause immediately

### Troubleshooting Failed Tests

#### DNS Resolution Failures

**Symptoms:**
```
[ERROR] 2024-01-11 13:52:18 - DNS resolution for google.com: FAIL
```

**Diagnosis steps:**
```bash
# Test manual DNS resolution
nslookup google.com

# Check DNSMasq status
systemctl status dnsmasq

# Check Stubby status  
systemctl status stubby

# Test direct Stubby query
nslookup -port=5353 google.com localhost
```

**Common causes and solutions:**
- **Service not running**: Start missing services
- **Port conflicts**: Check for other DNS services
- **Network connectivity**: Verify internet access
- **Firewall blocking**: Allow DNS traffic

#### Port Connectivity Failures

**Symptoms:**
```
[ERROR] 2024-01-11 13:52:20 - Port 53 (DNSMasq): CLOSED
```

**Diagnosis steps:**
```bash
# Check which process is using port 53
sudo netstat -tulpn | grep :53

# Check DNSMasq configuration
sudo dnsmasq --test

# Restart services
sudo systemctl restart dnsmasq
sudo systemctl restart stubby
```

**Common causes and solutions:**
- **DNSMasq not started**: Start the service
- **Port already in use**: Stop conflicting service
- **Configuration errors**: Check config files

#### Service Status Failures

**Symptoms:**
```
[ERROR] 2024-01-11 13:52:22 - DNSMasq service: INACTIVE
```

**Diagnosis steps:**
```bash
# Check service logs
sudo journalctl -u dnsmasq -n 20

# Check service configuration
sudo systemctl cat dnsmasq

# Test service manually
sudo dnsmasq --test
```

**Common causes and solutions:**
- **Configuration errors**: Fix YAML/config syntax
- **Missing dependencies**: Install required packages
- **Permission issues**: Check file ownership/permissions

---

## Reboot Survival Testing

### Why Reboot Testing is Important

Reboot testing ensures your DNS configuration **persists across system restarts**, which is critical for:

- **Production reliability**: DNS must work after server reboots
- **Configuration persistence**: Settings survive system updates
- **Service automation**: Services start automatically on boot
- **Network recovery**: DNS works after network interruptions
- **Maintenance scenarios**: Configuration survives planned reboots

### Running Pre-Reboot Check

**Execute the pre-reboot test:**

```bash
# Run pre-reboot validation
sudo bash tests/pre-reboot-check.sh

# Save results for comparison
sudo bash tests/pre-reboot-check.sh > /tmp/pre-reboot-results.txt 2>&1
```

**Expected pre-reboot output:**
```
============================================================================
  Pre-Reboot DNS Configuration Check
============================================================================
[2024-01-11 13:52:15] Starting pre-reboot DNS validation...
[2024-01-11 13:52:16] Testing DNS resolution...
✓ DNS resolution for example.com: PASS
✓ DNS resolution for google.com: PASS
✓ DNS resolution for cloudflare.com: PASS
[2024-01-11 13:52:17] Checking service status...
✓ DNSMasq service: ACTIVE
✓ Stubby service: ACTIVE
[2024-01-11 13:52:18] Verifying port connectivity...
✓ Port 53 (DNSMasq): OPEN
✓ Port 5353 (Stubby): OPEN
[2024-01-11 13:52:19] Testing DNSSEC validation...
✓ DNSSEC validation: PASS
[2024-01-11 13:52:20] Pre-reboot check completed successfully!
```

**What the test records:**
- Current DNS configuration state
- Service status and configuration
- Performance metrics baseline
- Configuration file checksums
- Network connectivity status

### Reboot Instructions

**Step 1: Prepare for reboot**

```bash
# Ensure all changes are saved
sync

# Verify no users are connected (for servers)
who

# Check for running processes that shouldn't be interrupted
ps aux | grep -v grep | grep -E "(database|web server|critical app)"
```

**Step 2: Execute reboot**

```bash
# Standard reboot (recommended)
sudo reboot

# Alternative: shutdown and restart
sudo shutdown -r now

# For remote systems, schedule reboot
sudo shutdown -r +5 "System reboot in 5 minutes for DNS maintenance"
```

**Step 3: Reboot confirmation**

After reboot, verify:
- System boots successfully
- Login is possible
- Network connectivity established
- DNS services are running

**Step 4: Wait for system stabilization**

```bash
# Wait for system to fully boot (1-2 minutes)
sleep 60

# Check system is responsive
uptime

# Verify network is up
ping -c 3 8.8.8.8
```

### Running Post-Reboot Check

**Execute the post-reboot test:**

```bash
# Run post-reboot validation
sudo bash tests/post-reboot-check.sh

# Generate comparison report
sudo bash tests/post-reboot-check.sh > /tmp/post-reboot-results.txt 2>&1

# Compare pre and post reboot results
diff /tmp/pre-reboot-results.txt /tmp/post-reboot-results.txt
```

**Expected post-reboot output:**
```
============================================================================
  Post-Reboot DNS Configuration Check
============================================================================
[2024-01-11 14:05:22] Starting post-reboot DNS validation...
[2024-01-11 14:05:23] Testing DNS resolution...
✓ DNS resolution for example.com: PASS
✓ DNS resolution for google.com: PASS
✓ DNS resolution for cloudflare.com: PASS
[2024-01-11 14:05:24] Checking service status...
✓ DNSMasq service: ACTIVE
✓ Stubby service: ACTIVE
[2024-01-11 14:05:25] Verifying port connectivity...
✓ Port 53 (DNSMasq): OPEN
✓ Port 5355 (Stubby): OPEN
[2024-01-11 14:05:26] Testing DNSSEC validation...
✓ DNSSEC validation: PASS
[2024-01-11 14:05:27] Comparing with pre-reboot state...
[2024-01-11 14:05:28] Configuration comparison: IDENTICAL
[2024-01-11 14:05:29] Post-reboot check completed successfully!
```

### Interpreting Comparison Reports

#### Successful Reboot Survival

**What "Success" looks like:**

```
PRE-BOOT vs POST-BOOT COMPARISON:
=================================
✓ DNS Resolution Tests: IDENTICAL
✓ Service Status: IDENTICAL  
✓ Port Connectivity: IDENTICAL
✓ DNSSEC Validation: IDENTICAL
✓ Configuration Files: UNCHANGED
✓ Performance Metrics: WITHIN NORMAL RANGE

CONCLUSION: DNS configuration survived reboot successfully
```

**Interpretation:**
- All tests pass both before and after reboot
- Configuration files unchanged
- Services auto-started correctly
- Performance metrics consistent
- **System is production-ready**

#### Partial Success (Warnings)

**What "Partial Success" looks like:**

```
PRE-BOOT vs POST-BOOT COMPARISON:
=================================
⚠️  DNS Resolution Tests: MINOR DIFFERENCES
⚠️  Service Status: ACTIVE (but delayed startup)
⚠️  Port Connectivity: IDENTICAL
⚠️  DNSSEC Validation: IDENTICAL
⚠️  Configuration Files: UNCHANGED
⚠️  Performance Metrics: SLIGHTLY DEGRADED

ISSUE DETECTED: Services started but with delay

RECOMMENDATION: Monitor for a few more reboots
```

**Interpretation:**
- Core functionality works but has issues
- May indicate timing dependencies
- Could be acceptable for some use cases
- **Recommendation: Investigate further**

#### Complete Failure

**What "Failure" looks like:**

```
PRE-BOOT vs POST-BOOT COMPARISON:
=================================
❌ DNS Resolution Tests: FAILED
❌ Service Status: INACTIVE
❌ Port Connectivity: CLOSED
❌ DNSSEC Validation: FAILED
❌ Configuration Files: MODIFIED
❌ Performance Metrics: N/A

ISSUE DETECTED: DNS configuration did not survive reboot

RECOMMENDATION: Run rollback and investigate
```

**Interpretation:**
- DNS configuration completely failed
- Services not auto-starting
- Manual intervention required
- **System is NOT production-ready**

### Expected Behavior After Reboot

#### Immediate Post-Reboot (0-30 seconds)

**Expected timeline:**
- **0-5 seconds**: System boots, network interface comes up
- **5-15 seconds**: Network connectivity established
- **15-25 seconds**: systemd starts services in dependency order
- **25-30 seconds**: DNS services fully operational

**Services startup order:**
1. `network.target` - Network interfaces ready
2. `stubby.service` - DNS-over-TLS client starts
3. `dnsmasq.service` - Local DNS cache starts  
4. `systemd-resolved.service` - (if disabled, stays stopped)

#### Post-Reboot Verification (30-60 seconds)

**DNS functionality should work:**
```bash
# Quick DNS test (should work immediately)
nslookup google.com

# Should resolve to Google's IP (e.g., 142.250.185.46)

# Check services are running
systemctl is-active stubby dnsmasq

# Should return: active
```

#### Performance After Reboot (1-5 minutes)

**Expected behavior:**
- **0-1 minutes**: Cold cache, queries take longer (500ms-2s)
- **1-3 minutes**: Cache warming, response times improve
- **3-5 minutes**: Full performance, typical latency restored

**Cache warming process:**
```bash
# First queries are slow (uncached)
time nslookup google.com    # May take 1-2 seconds

# Subsequent queries are fast (cached)
time nslookup google.com    # Should be <50ms

# Different domains still slow (uncached)
time nslookup cloudflare.com    # May take 1-2 seconds
```

---

## Usage & Command Reference

### Running the Main Setup Script

#### Basic Usage

```bash
# Full installation and configuration
sudo bash bin/secure-dns-setup.sh
```

#### Command Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `--help` | Display usage information | `sudo bash bin/secure-dns-setup.sh --help` |
| `--run-tests` | Run connectivity tests only (no changes) | `sudo bash bin/secure-dns-setup.sh --run-tests` |
| `--test-reboot` | Run comprehensive reboot survival tests | `sudo bash bin/secure-dns-setup.sh --test-reboot` |
| `--rollback` | Restore previous configuration | `sudo bash bin/secure-dns-setup.sh --rollback` |
| `--verbose` | Enable detailed output | `sudo bash bin/secure-dns-setup.sh --verbose` |
| `--dry-run` | Show what would be done (no changes) | `sudo bash bin/secure-dns-setup.sh --dry-run` |

#### Detailed Option Descriptions

##### `--help`

Display comprehensive usage information:

```bash
sudo bash bin/secure-dns-setup.sh --help
```

**Output includes:**
- Command syntax and options
- DNS server hierarchy explanation
- Available test types
- Configuration file locations
- Example commands
- Troubleshooting information

##### `--run-tests`

Execute connectivity testing without making any changes:

```bash
# Basic test run
sudo bash bin/secure-dns-setup.sh --run-tests

# Verbose test output
sudo bash bin/secure-dns-setup.sh --run-tests --verbose

# Test with specific timeout
timeout 300 sudo bash bin/secure-dns-setup.sh --run-tests
```

**Tests performed:**
- DNS resolution validation
- Port connectivity verification
- Service health checks
- DNSSEC validation testing
- Performance benchmarking
- Fallback server connectivity

##### `--test-reboot`

Run comprehensive reboot survival testing:

```bash
# Full reboot test sequence
sudo bash bin/secure-dns-setup.sh --test-reboot

# Verbose reboot testing
sudo bash bin/secure-dns-setup.sh --test-reboot --verbose
```

**Test sequence:**
1. Pre-reboot state validation
2. System reboot execution
3. Post-reboot state validation
4. Configuration comparison
5. Performance comparison
6. Detailed report generation

##### `--rollback`

Restore system to pre-installation state:

```bash
# Restore previous DNS configuration
sudo bash bin/secure-dns-setup.sh --rollback

# Rollback with verification
sudo bash bin/secure-dns-setup.sh --rollback --verbose
```

**Rollback actions:**
- Stop DNSMasq and Stubby services
- Restore original `/etc/resolv.conf`
- Remove service configurations
- Clean up custom configurations
- Re-enable previous DNS services

##### `--verbose`

Enable detailed logging and output:

```bash
# Standard setup with verbose output
sudo bash bin/secure-dns-setup.sh --verbose

# Test with verbose output
sudo bash bin/secure-dns-setup.sh --run-tests --verbose

# Dry run with detailed preview
sudo bash bin/secure-dns-setup.sh --dry-run --verbose
```

**Verbose output includes:**
- Configuration file contents
- Service startup details
- Network connection attempts
- Detailed test results
- Step-by-step execution logs

##### `--dry-run`

Preview actions without making changes:

```bash
# Preview setup actions
sudo bash bin/secure-dns-setup.sh --dry-run

# Preview with verbose details
sudo bash bin/secure-dns-setup.sh --dry-run --verbose
```

**Dry run shows:**
- Files that would be created/modified
- Services that would be started/stopped
- Configuration changes that would be made
- Commands that would be executed
- Estimated execution time

### Testing Scripts

#### Connectivity Testing

**Run comprehensive connectivity tests:**

```bash
# Execute all connectivity tests
sudo bash bin/secure-dns-setup.sh --run-tests

# Test specific components
sudo bash bin/secure-dns-setup.sh --run-tests --verbose
```

**Test components:**
- DNS resolution through secure chain
- Port accessibility (53, 5353)
- Service health status
- DNSSEC validation functionality
- Performance benchmarking
- Fallback server connectivity

#### Pre-Reboot Validation

**Validate DNS configuration before system reboot:**

```bash
# Run pre-reboot check
sudo bash tests/pre-reboot-check.sh

# Save results for comparison
sudo bash tests/pre-reboot-check.sh > /tmp/pre-reboot.log 2>&1

# Quick validation check
sudo bash tests/pre-reboot-check.sh --quick
```

**Pre-reboot validation includes:**
- DNS resolution tests with multiple domains
- Service status verification
- Port connectivity validation
- Configuration file integrity checks
- Performance baseline measurement

#### Post-Reboot Validation

**Validate DNS configuration after system reboot:**

```bash
# Run post-reboot check
sudo bash tests/post-reboot-check.sh

# Generate comparison report
sudo bash tests/post-reboot-check.sh > /tmp/post-reboot.log 2>&1

# Compare with pre-reboot state
diff /tmp/pre-reboot.log /tmp/post-reboot.log
```

**Post-reboot validation includes:**
- Same tests as pre-reboot check
- Comparison with previous state
- Service auto-start verification
- Performance impact assessment
- Detailed difference analysis

#### Reboot Test Helper

**Assist with reboot testing workflow:**

```bash
# Run complete reboot test sequence
sudo bash tests/reboot-test-helper.sh

# Schedule automated reboot test
sudo bash tests/reboot-test-helper.sh --schedule "2 minutes"

# Manual reboot test steps
sudo bash tests/reboot-test-helper.sh --manual-steps
```

**Helper functionality:**
- Automated pre/post reboot testing
- Result comparison and analysis
- Automated report generation
- Error detection and reporting
- Test scheduling and coordination

### Manual Verification Commands

#### DNS Resolution Testing

**Basic DNS queries:**

```bash
# Simple DNS resolution test
nslookup google.com

# Query specific DNS server (DNSMasq on localhost)
nslookup google.com localhost

# Query Stubby directly (port 5353)
nslookup -port=5353 google.com localhost

# Detailed query with statistics
dig google.com

# Query with timing statistics
dig google.com +stats

# DNSSEC validation query
dig google.com +dnssec
```

**Expected successful output:**
```
Server:		127.0.0.1
Address:	127.0.0.1#53

Non-authoritative answer:
Name:	google.com
Address: 142.250.185.46
```

#### Service Status Checking

**Systemd service status:**

```bash
# Check Stubby service status
systemctl status stubby

# Check DNSMasq service status  
systemctl status dnsmasq

# Check if services are enabled for boot
systemctl is-enabled stubby dnsmasq

# Check service dependencies
systemctl list-dependencies stubby
systemctl list-dependencies dnsmasq
```

**Expected active output:**
```
● stubby.service - DNS-over-TLS client
   Loaded: loaded (/etc/systemd/system/stubby.service; enabled; vendor preset: enabled)
   Active: active (running) since Wed 2024-01-11 13:52:15 UTC; 2h 15min ago
```

#### Log Monitoring

**View setup and service logs:**

```bash
# View setup log
tail -f /var/log/dns-setup.log

# View Stubby logs
journalctl -u stubby -f

# View DNSMasq logs
journalctl -u dnsmasq -f

# View system logs for DNS
journalctl | grep -E "(stubby|dnsmasq|dns)"
```

**Log file locations:**
- Setup logs: `/var/log/dns-setup.log`
- Service logs: `journalctl -u stubby`
- Service logs: `journalctl -u dnsmasq`
- System logs: `journalctl | grep dns`

#### Port and Network Testing

**Check listening ports:**

```bash
# Check DNS ports
netstat -tuln | grep -E ":53|:5353"

# Alternative with ss command
ss -tuln | grep -E ":53|:5353"

# Check port ownership
sudo lsof -i :53
sudo lsof -i :5353

# Test local connectivity
telnet localhost 53
telnet localhost 5353
```

**Expected port status:**
```
tcp        0      0 0.0.0.0:53              0.0.0.0:*               LISTEN      1234/dnsmasq
tcp        0      0 127.0.0.1:5353          0.0.0.0:*               LISTEN      1235/stubby
```

#### DNSSEC Validation Testing

**Test DNSSEC functionality:**

```bash
# Basic DNSSEC validation test
dig +dnssec cloudflare.com

# Check for AD (Authenticated Data) flag
dig +dnssec cloudflare.com | grep -E "(flags:|AD;)"

# Test DNSSEC chain validation
dig +dnssec +trace cloudflare.com

# Test DNSSEC with verbose output
dig +dnssec cloudflare.com +short +verbose
```

**Expected DNSSEC response:**
```
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 12345
;; flags: qr rd ra ad; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
```

#### Performance and Latency Testing

**Measure DNS performance:**

```bash
# Query with timing statistics
time dig google.com

# Multiple queries for average timing
for i in {1..5}; do time dig google.com; done

# Test cache performance
dig google.com  # First query (slow)
dig google.com  # Second query (fast, cached)

# Test with different domains
for domain in google.com cloudflare.com github.com; do
    echo "Testing $domain:"
    time dig $domain
done
```

**Performance benchmarks:**
- **Excellent**: < 30ms
- **Good**: 30-100ms
- **Acceptable**: 100-500ms
- **Poor**: > 500ms

---

## Verification & Debugging

### Manual DNS Test

**Basic DNS resolution test:**

```bash
# Test DNS resolution through the secure DNS chain
nslookup google.com

# Expected output should show successful resolution:
# Server:     127.0.0.1
# Address:    127.0.0.1#53
# 
# Non-authoritative answer:
# Name:   google.com
# Address: 142.250.185.46
```

**Troubleshooting failed resolution:**

```bash
# Test direct DNSMasq query
nslookup google.com localhost

# Test Stubby directly (port 5353)
nslookup -port=5353 google.com localhost

# Test upstream DNS directly
nslookup google.com 1.1.1.1

# Check DNSMasq configuration
sudo dnsmasq --test

# View DNSMasq logs
sudo journalctl -u dnsmasq -n 20
```

### Check Service Status

**Verify systemd services:**

```bash
# Check Stubby service
systemctl status stubby

# Check DNSMasq service
systemctl status dnsmasq

# Check if services are enabled for boot
systemctl is-enabled stubby dnsmasq

# Restart services if needed
sudo systemctl restart stubby
sudo systemctl restart dnsmasq
```

**Expected active service output:**
```
● stubby.service - DNS-over-TLS client
   Loaded: loaded (/etc/systemd/system/stubby.service; enabled)
   Active: active (running) since Wed 2024-01-11 13:52:15 UTC; 2h 15min ago
 Main PID: 1234 (stubby)
   Status: "Running as configured"
    Tasks: 3 (limit: 4632)
   Memory: 15.2M
      CPU: 2.345s
   CGroup: /system.slice/stubby.service
           └─1234 /usr/sbin/stubby -C /etc/stubby/stubby.yml
```

**Troubleshooting inactive services:**

```bash
# Check why service failed
sudo systemctl status stubby --no-pager -l

# Check service logs for errors
sudo journalctl -u stubby --no-pager -n 50

# Test service configuration manually
sudo stubby -C /etc/stubby/stubby.yml -t

# Check file permissions
ls -la /etc/stubby/stubby.yml
sudo chown root:root /etc/stubby/stubby.yml
sudo chmod 644 /etc/stubby/stubby.yml
```

### View Logs

**Monitor setup and service logs:**

```bash
# View setup log in real-time
tail -f /var/log/dns-setup.log

# View Stubby service logs
sudo journalctl -u stubby -f

# View DNSMasq service logs
sudo journalctl -u dnsmasq -f

# View recent DNS-related logs
sudo journalctl | grep -E "(stubby|dnsmasq|dns)" | tail -20
```

**Log file locations:**
- Setup script logs: `/var/log/dns-setup.log`
- Stubby service logs: `sudo journalctl -u stubby`
- DNSMasq service logs: `sudo journalctl -u dnsmasq`
- System logs: `sudo journalctl | grep dns`

**Common log entries:**

**Successful Stubby startup:**
```
Jan 11 13:52:15 server stubby[1234]: [stubby] Starting stubby version 1.4.0
Jan 11 13:52:15 server stubby[1234]: [stubby] Read 3 upstream servers
Jan 11 13:52:15 server stubby[1234]: [stubby] Opening listen sockets on 127.0.0.1 port 5353
Jan 11 13:52:16 server stubby[1234]: [stubby] Listening on 127.0.0.1 port 5353
```

**Successful DNSMasq startup:**
```
Jan 11 13:52:16 server dnsmasq[1235]: started, version 2.80 cachesize 10000
Jan 11 13:52:16 server dnsmasq[1235]: compile time options: IPv6 GNU-getopt DBus no-i18n IDN DHCP DHCPv6 no-Lua TFTP no-conntrack no-ipset no-auth no-DNSSEC loop-detect
Jan 11 13:52:16 server dnsmasq[1235]: using nameserver 127.0.0.1#5353
Jan 11 13:52:16 server dnsmasq[1235]: reading /etc/resolv.conf
Jan 11 13:52:16 server dnsmasq[1235]: using nameserver 127.0.0.1#5353
Jan 11 13:52:16 server dnsmasq[1235]: using nameserver 127.0.0.1#5353
```

### Check Listening Ports

**Verify network ports:**

```bash
# Check DNS ports are listening
netstat -tuln | grep -E ":53|:5353"

# Alternative with ss command
ss -tuln | grep -E ":53|:5353"

# Check which process owns each port
sudo lsof -i :53
sudo lsof -i :5353

# Test port connectivity locally
telnet localhost 53
telnet localhost 5353
```

**Expected port status:**
```
tcp        0      0 0.0.0.0:53              0.0.0.0:*               LISTEN      1234/dnsmasq
tcp        0      0 127.0.0.1:5353          0.0.0.0:*               LISTEN      1235/stubby
```

**Troubleshooting port issues:**

```bash
# Check for port conflicts
sudo netstat -tulpn | grep -E ":53|:5353"

# Kill conflicting processes if needed
sudo kill -9 <PID>

# Test if ports are accessible
nc -zv localhost 53
nc -zv localhost 5353

# Check firewall rules
sudo ufw status
sudo iptables -L | grep -E "53|5353"
```

### Test DNSSEC

**Validate DNSSEC functionality:**

```bash
# Basic DNSSEC validation test
dig +dnssec cloudflare.com

# Check for AD (Authenticated Data) flag
dig +dnssec cloudflare.com | grep "flags:"

# Expected output should include "ad" flag:
# flags: qr rd ra ad; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

# Test DNSSEC chain validation
dig +dnssec +trace cloudflare.com

# Test with verbose output
dig +dnssec cloudflare.com +verbose
```

**Manual DNSSEC validation:**

```bash
# Query root servers for DNSSEC chain
dig . @a.root-servers.net +dnssec +trace

# Query com servers
dig com @a.gtld-servers.net +dnssec +trace

# Query authoritative server
dig cloudflare.com @ns3.cloudflare.com +dnssec
```

**Expected DNSSEC response:**
```
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 12345
;; flags: qr rd ra ad; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags: do; udp: 4096
```

**Troubleshooting DNSSEC issues:**

```bash
# Check if DNSSEC is enabled in Stubby
grep -i dnssec /etc/stubby/stubby.yml

# Expected setting: dnssec: 1

# Test with known DNSSEC-signed domain
dig +dnssec isc.org

# Check for validation failures
dig +dnssec cloudflare.com | grep -E "(BOGUS|FAILED)"
```

### Measure Latency

**Benchmark DNS performance:**

```bash
# Query with timing statistics
dig google.com +stats

# Measure average latency over multiple queries
echo "Testing DNS latency..."
for i in {1..10}; do
    time dig google.com
    echo "---"
done

# Test cache performance
echo "Cache performance test:"
dig google.com  # First query (slow, uncached)
sleep 1
dig google.com  # Second query (fast, cached)

# Test different domains for cold cache performance
domains=("google.com" "cloudflare.com" "github.com" "stackoverflow.com")
for domain in "${domains[@]}"; do
    echo "Testing $domain:"
    time dig $domain
    echo "---"
done
```

**Expected performance benchmarks:**

**Cache hits (subsequent queries to same domain):**
- **Excellent**: < 10ms
- **Good**: 10-30ms
- **Acceptable**: 30-50ms
- **Poor**: > 50ms

**Cache misses (first query to new domain):**
- **Excellent**: < 100ms
- **Good**: 100-300ms
- **Acceptable**: 300-500ms
- **Poor**: > 500ms

**Performance improvement verification:**
```bash
# Test the same domain twice
time dig google.com  # Should be slower (cache miss)
time dig google.com  # Should be faster (cache hit)

# Compare times - cache hit should be significantly faster
```

### View DNSMasq Cache Stats

**Monitor cache performance:**

```bash
# Query DNSMasq statistics (if supported)
echo "dump-nodes" | nc localhost 53
echo "dump-ram" | nc localhost 53
echo "cache-stats" | nc localhost 53

# Alternative: check DNSMasq status
systemctl status dnsmasq | grep -i cache

# Monitor cache growth over time
watch -n 5 'echo "cache-stats" | nc localhost 53'
```

**Manual cache testing:**

```bash
# Test cache effectiveness
for i in {1..5}; do
    dig google.com +stats | grep -E "(Query time|when:)"
    echo "---"
    sleep 2
done

# Should show decreasing "Query time" for cached responses
```

**Cache size and behavior:**

```bash
# Check DNSMasq cache configuration
grep cache-size /etc/dnsmasq.conf

# Monitor cache usage
watch -n 10 'ps aux | grep dnsmasq | grep -v grep'
```

### Common Issues and Solutions

#### DNS Not Resolving

**Symptoms:**
- `nslookup google.com` fails
- Applications can't resolve domain names
- Web browsers show "DNS_PROBE_FINISHED_BAD_CONFIG"

**Diagnosis:**
```bash
# Test basic DNS resolution
nslookup google.com

# Check service status
systemctl status stubby dnsmasq

# Check port connectivity
netstat -tuln | grep -E ":53|:5353"

# Test upstream connectivity
nslookup google.com 1.1.1.1
```

**Solutions:**

**Service not running:**
```bash
sudo systemctl restart stubby
sudo systemctl restart dnsmasq
sudo systemctl enable stubby
sudo systemctl enable dnsmasq
```

**Port conflicts:**
```bash
# Find process using port 53
sudo netstat -tulpn | grep :53

# Stop conflicting service
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
```

**Network connectivity:**
```bash
# Test upstream DNS servers
ping -c 3 1.1.1.1
ping -c 3 9.9.9.9

# Check firewall
sudo ufw status
sudo iptables -L
```

#### Services Not Starting

**Symptoms:**
- `systemctl status stubby` shows "inactive" or "failed"
- Service logs show configuration errors
- Ports are not listening

**Diagnosis:**
```bash
# Check service status
systemctl status stubby --no-pager -l

# Check service configuration
sudo stubby -C /etc/stubby/stubby.yml -t

# Check file permissions
ls -la /etc/stubby/stubby.yml
```

**Solutions:**

**Configuration errors:**
```bash
# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('/etc/stubby/stubby.yml'))"

# Fix common YAML issues
sudo nano /etc/stubby/stubby.yml

# Restart service
sudo systemctl restart stubby
```

**Permission issues:**
```bash
# Fix file ownership
sudo chown root:root /etc/stubby/stubby.yml
sudo chmod 644 /etc/stubby/stubby.yml

# Restart service
sudo systemctl restart stubby
```

#### Port Conflicts

**Symptoms:**
- "Address already in use" errors
- Services fail to start
- `netstat` shows port already bound

**Diagnosis:**
```bash
# Check which process is using the port
sudo netstat -tulpn | grep :53
sudo lsof -i :5353

# Check systemd-resolved status
systemctl status systemd-resolved
```

**Solutions:**

**Stop systemd-resolved:**
```bash
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# Restart DNS services
sudo systemctl restart stubby
sudo systemctl restart dnsmasq
```

**Kill conflicting processes:**
```bash
# Find and kill process
sudo kill -9 $(sudo lsof -t -i:53)

# Or disable the service
sudo systemctl stop bind9
sudo systemctl disable bind9
```

#### High Latency

**Symptoms:**
- DNS queries take > 500ms
- Web browsing feels slow
- DNS timeouts occur

**Diagnosis:**
```bash
# Measure query latency
time dig google.com

# Test upstream server latency
time dig @1.1.1.1 google.com
time dig @9.9.9.9 google.com
time dig @8.8.8.8 google.com

# Check cache performance
dig google.com  # First query
dig google.com  # Should be faster
```

**Solutions:**

**Cache configuration:**
```bash
# Increase DNSMasq cache size
echo "cache-size=10000" | sudo tee -a /etc/dnsmasq.conf

# Restart DNSMasq
sudo systemctl restart dnsmasq
```

**Server performance:**
```bash
# Test different upstream servers
dig @1.1.1.1 google.com +stats
dig @9.9.9.9 google.com +stats

# Reorder servers by performance in stubby.yml
```

**Network optimization:**
```bash
# Check network connectivity
ping -c 10 1.1.1.1

# Test with different network interfaces
ip route show
```

#### Cache Issues

**Symptoms:**
- DNS queries always slow (no caching)
- Cache statistics show no hits
- Memory usage grows without bound

**Diagnosis:**
```bash
# Check cache statistics
echo "dump-nodes" | nc localhost 53

# Monitor cache growth
watch -n 5 'ps aux | grep dnsmasq'

# Check cache configuration
grep cache /etc/dnsmasq.conf
```

**Solutions:**

**Clear cache:**
```bash
# Restart DNSMasq to clear cache
sudo systemctl restart dnsmasq

# Test cache clearing
dig google.com  # Should be slow (cache cleared)
dig google.com  # Should be fast (cached)
```

**Configuration issues:**
```bash
# Check DNSMasq configuration
sudo dnsmasq --test

# Fix cache settings
echo "cache-size=10000" | sudo tee -a /etc/dnsmasq.conf
echo "no-hosts" | sudo tee -a /etc/dnsmasq.conf

# Restart service
sudo systemctl restart dnsmasq
```

---

## Configuration Customization

### Changing DNS Servers

**Edit Stubby configuration:**

```bash
# Backup current configuration
sudo cp /etc/stubby/stubby.yml /etc/stubby/stubby.yml.backup

# Edit configuration
sudo nano /etc/stubby/stubby.yml
```

**Configuration structure:**
```yaml
# /etc/stubby/stubby.yml
dnssec:
  getaddrinfo: 1
  trustAnchor: https://www.internic.net/domain/root.key

round_robin_upstreams: 1

upstream_recursive_servers:
  # Primary: Cloudflare
  - address_data: 1.1.1.1
    tls_auth_name: "cloudflare-dns.com"
    tls_port: 853
  - address_data: 1.0.0.1
    tls_auth_name: "cloudflare-dns.com"
    tls_port: 853
  
  # Secondary: Quad9
  - address_data: 9.9.9.9
    tls_auth_name: "dns.quad9.net"
    tls_port: 853
  - address_data: 149.112.112.112
    tls_auth_name: "dns.quad9.net"
    tls_port: 853
  
  # Tertiary: Google
  - address_data: 8.8.8.8
    tls_auth_name: "dns.google"
    tls_port: 853
  - address_data: 8.8.4.4
    tls_auth_name: "dns.google"
    tls_port: 853
```

**Alternative DNS providers:**

**NextDNS (custom filtering):**
```yaml
  - address_data: 45.90.28.0
    tls_auth_name: "your-account.nextdns.io"
    tls_port: 853
  - address_data: 45.90.30.0
    tls_auth_name: "your-account.nextdns.io"
    tls_port: 853
```

**CleanBrowsing (family-safe):**
```yaml
  - address_data: 185.228.168.9
    tls_auth_name: "cleanbrowsing.org"
    tls_port: 853
  - address_data: 185.228.169.9
    tls_auth_name: "cleanbrowsing.org"
    tls_port: 853
```

**Apply changes:**
```bash
# Validate configuration
sudo stubby -C /etc/stubby/stubby.yml -t

# Restart Stubby service
sudo systemctl restart stubby

# Test new configuration
nslookup google.com
dig google.com +stats
```

### Adjusting Cache Size

**Edit DNSMasq configuration:**

```bash
# Edit DNSMasq configuration
sudo nano /etc/dnsmasq.conf
```

**Cache size settings:**
```bash
# Set cache size (default: 150 entries)
cache-size=10000

# Set cache timeout (default: 120 seconds)
local-ttl=300

# Enable verbose logging for debugging
log-queries
log-facility=/var/log/dnsmasq.log

# Cache negative responses
cache-ttl=60

# Don't read /etc/hosts
no-hosts

# Don't read /etc/resolv.conf (use Stubby only)
no-resolv
```

**Apply cache changes:**
```bash
# Test configuration
sudo dnsmasq --test

# Restart DNSMasq
sudo systemctl restart dnsmasq

# Monitor cache performance
tail -f /var/log/dnsmasq.log
```

**Cache size recommendations:**

| Use Case | Cache Size | Memory Usage | Benefit |
|----------|------------|--------------|---------|
| **Desktop** | 1,000-5,000 | ~10-50MB | Good performance |
| **Server** | 10,000-50,000 | ~100-500MB | High performance |
| **Enterprise** | 50,000+ | ~500MB+ | Maximum performance |

### Adding Local DNS Entries

**Create local DNS records:**

```bash
# Edit hosts file
sudo nano /etc/hosts

# Add custom entries
127.0.0.1 localhost
192.168.1.10   myserver.local
192.168.1.20   database.local
10.0.0.15      api.internal

# Or create separate file for DNSMasq
sudo nano /etc/dnsmasq.d/local-domains.conf

# Add entries in DNSMasq format
address=/myserver.local/192.168.1.10
address=/database.local/192.168.1.20
address=/api.internal/10.0.0.15
```

**Domain configuration:**
```bash
# Wildcard domains
address=/.local/192.168.1.1
address=/.internal/10.0.0.1

# CNAME records
cname=www.mysite.com,mysite.com

# MX records for local domains
mx-host=local,mail.local,10
```

**Restart and test:**
```bash
# Restart DNSMasq
sudo systemctl restart dnsmasq

# Test local entries
nslookup myserver.local
nslookup www.mysite.com
```

### Changing Stubby Port

**Modify Stubby port configuration:**

```bash
# Edit Stubby configuration
sudo nano /etc/stubby/stubby.yml
```

**Change listen address:**
```yaml
# Listen on different port
listen_addresses:
  - 127.0.0.1@5555
  - 127.0.0.1@5556

# Or listen on all interfaces (not recommended)
listen_addresses:
  - 0.0.0.0@5555
```

**Update DNSMasq configuration:**
```bash
# Edit DNSMasq upstream configuration
sudo nano /etc/dnsmasq.d/dns-stubby.conf

# Update upstream server port
server=127.0.0.1#5555
```

**Apply changes:**
```bash
# Test configuration
sudo stubby -C /etc/stubby/stubby.yml -t
sudo dnsmasq --test

# Restart services
sudo systemctl restart stubby
sudo systemctl restart dnsmasq

# Verify port change
netstat -tuln | grep 5555
```

### Enabling/Disabling Logging

**Stubby logging configuration:**

```bash
# Edit Stubby configuration
sudo nano /etc/stubby/stubby.yml

# Add logging settings
log_level:
  - 0

# OR verbose logging for debugging
log_level:
  - 5
```

**DNSMasq logging:**

```bash
# Edit DNSMasq configuration
sudo nano /etc/dnsmasq.conf

# Enable query logging
log-queries
log-facility=/var/log/dnsmasq.log
log-async=50

# Debug logging (very verbose)
log-queries-extra
```

**Log file management:**
```bash
# View real-time logs
sudo tail -f /var/log/dnsmasq.log

# Rotate logs manually
sudo logrotate -f /etc/logrotate.conf

# Clean old logs
sudo find /var/log -name "*.log" -mtime +7 -delete
```

### DNSSEC Settings

**Configure DNSSEC validation:**

```bash
# Edit Stubby configuration
sudo nano /etc/stubby/stubby.yml

# Enable DNSSEC
dnssec:
  getaddrinfo: 1
  trustAnchor: https://www.internic.net/domain/root.key
```

**DNSSEC troubleshooting:**
```bash
# Test DNSSEC validation
dig +dnssec cloudflare.com

# Check for validation errors
dig +dnssec cloudflare.com | grep -E "(BOGUS|FAILED)"

# Test DNSSEC chain
dig +dnssec +trace cloudflare.com
```

**DNSSEC validation modes:**

**Strict validation (recommended):**
```yaml
dnssec:
  getaddrinfo: 1
  trustAnchor: https://www.internic.net/domain/root.key
  # Reject unsigned responses
  # This provides maximum security
```

**Relaxed validation:**
```yaml
dnssec:
  getaddrinfo: 1
  # Allow unsigned domains
  # This provides compatibility with unsigned domains
```

### Rate Limiting Configuration

**DNSMasq rate limiting:**

```bash
# Edit DNSMasq configuration
sudo nano /etc/dnsmasq.conf

# Limit queries per second
limit-queries-per-second=10

# Limit concurrent queries
limit-queries-total=100

# Rate limiting per client
dhcp-authoritative
dhcp-range=192.168.1.100,192.168.1.200,255.255.255.0,1h
```

**Per-client rate limiting:**
```bash
# Rate limit by IP address
# Edit /etc/dnsmasq.d/rate-limit.conf
dhcp-host=192.168.1.100,set:client1
dhcp-host=192.168.1.101,set:client2

# Different limits for different clients
tag:client1,set=limit-5-per-sec
tag:client2,set=limit-20-per-sec
```

### IPv6 Support Setup

**Enable IPv6 in Stubby:**

```bash
# Edit Stubby configuration
sudo nano /etc/stubby/stubby.yml

# Add IPv6 upstream servers
upstream_recursive_servers:
  # IPv6 Cloudflare
  - address_data: 2606:4700:4700::1111
    tls_auth_name: "cloudflare-dns.com"
    tls_port: 853
  - address_data: 2606:4700:4700::1001
    tls_auth_name: "cloudflare-dns.com"
    tls_port: 853
  
  # IPv6 Quad9
  - address_data: 2620:fe::fe
    tls_auth_name: "dns.quad9.net"
    tls_port: 853
  - address_data: 2620:fe::9
    tls_auth_name: "dns.quad9.net"
    tls_port: 853
  
  # IPv6 Google
  - address_data: 2001:4860:4860::8888
    tls_auth_name: "dns.google"
    tls_port: 853
  - address_data: 2001:4860:4860::8844
    tls_auth_name: "dns.google"
    tls_port: 853
```

**DNSMasq IPv6 configuration:**
```bash
# Edit DNSMasq configuration
sudo nano /etc/dnsmasq.conf

# Enable IPv6 support
enable-ipv6

# IPv6 DNSMasq settings
dhcp-range=::,constructor:eth0,ra-only

# IPv6 address ranges
dhcp-range=192.168.1.0,static,255.255.255.0
```

**Test IPv6 connectivity:**
```bash
# Test IPv6 DNS resolution
dig AAAA google.com

# Test IPv6 stubby connectivity
nslookup -port=5353 -family=inet6 google.com localhost
```

---

## Troubleshooting Guide

### DNS Not Resolving

**Symptoms:**
- `nslookup google.com` returns "can't find" errors
- Web browsers show DNS-related error messages
- Applications cannot connect to remote services
- Ping works but DNS queries fail

**Immediate diagnosis:**
```bash
# Test basic DNS resolution
nslookup google.com

# Check if using local DNS server
cat /etc/resolv.conf

# Test upstream DNS directly
nslookup google.com 1.1.1.1

# Check service status
systemctl status stubby dnsmasq
```

**Common causes and solutions:**

**1. Services not running:**
```bash
# Check service status
systemctl status stubby dnsmasq

# Start missing services
sudo systemctl start stubby
sudo systemctl start dnsmasq

# Enable for automatic startup
sudo systemctl enable stubby
sudo systemctl enable dnsmasq
```

**2. Port conflicts:**
```bash
# Check what's using port 53
sudo netstat -tulpn | grep :53

# Stop conflicting services
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
```

**3. Configuration errors:**
```bash
# Validate Stubby configuration
sudo stubby -C /etc/stubby/stubby.yml -t

# Validate DNSMasq configuration
sudo dnsmasq --test

# Check configuration file syntax
python3 -c "import yaml; yaml.safe_load(open('/etc/stubby/stubby.yml'))"
```

**4. Network connectivity issues:**
```bash
# Test internet connectivity
ping -c 3 1.1.1.1

# Check DNS server reachability
dig @1.1.1.1 google.com

# Verify firewall rules
sudo ufw status
sudo iptables -L
```

**Step-by-step resolution:**
1. Verify services are running
2. Check port availability
3. Test configuration files
4. Verify network connectivity
5. Review logs for errors

### Services Not Starting

**Symptoms:**
- `systemctl status stubby` shows "inactive" or "failed"
- Service startup logs contain error messages
- Port 53 or 5353 not listening
- Configuration test commands fail

**Diagnosis:**
```bash
# Check detailed service status
systemctl status stubby --no-pager -l

# Check service logs
sudo journalctl -u stubby --no-pager -n 50

# Test configuration manually
sudo stubby -C /etc/stubby/stubby.yml -t

# Check file permissions
ls -la /etc/stubby/stubby.yml
```

**Common causes and solutions:**

**1. Configuration syntax errors:**
```bash
# Test YAML syntax
python3 -c "import yaml; yaml.safe_load(open('/etc/stubby/stubby.yml'))"

# Check for common YAML issues:
# - Inconsistent indentation
# - Missing quotes around special characters
# - Invalid boolean values

# Fix and restart
sudo systemctl restart stubby
```

**2. Permission issues:**
```bash
# Check file ownership
ls -la /etc/stubby/stubby.yml

# Fix ownership and permissions
sudo chown root:root /etc/stubby/stubby.yml
sudo chmod 644 /etc/stubby/stubby.yml

# Restart service
sudo systemctl restart stubby
```

**3. Missing dependencies:**
```bash
# Check for required commands
which stubby dnsmasq

# Install missing packages
sudo apt update
sudo apt install stubby dnsmasq

# Verify installation
stubby --version
dnsmasq --version
```

**4. Resource constraints:**
```bash
# Check system resources
free -h
df -h

# Check for memory issues
sudo journalctl | grep -i "out of memory"

# Increase resource limits if needed
sudo systemctl edit stubby
```

**Service startup debugging:**
```bash
# Start service in debug mode
sudo systemctl stop stubby
sudo stubby -C /etc/stubby/stubby.yml -v

# Check for specific error messages
sudo journalctl -u stubby --since "5 minutes ago"
```

### Port Conflicts

**Symptoms:**
- "Address already in use" errors during startup
- Services fail to bind to required ports
- `netstat` shows ports already in use
- Service status shows startup failures

**Diagnosis:**
```bash
# Check port usage
sudo netstat -tulpn | grep -E ":53|:5353"

# Find process using port 53
sudo lsof -i :53

# Find process using port 5353
sudo lsof -i :5353

# Check systemd services
systemctl list-units --all | grep dns
```

**Common conflicts and solutions:**

**1. systemd-resolved on port 53:**
```bash
# Check if systemd-resolved is running
systemctl status systemd-resolved

# Stop and disable
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# Restart DNS services
sudo systemctl restart stubby
sudo systemctl restart dnsmasq
```

**2. bind9 on port 53:**
```bash
# Check bind9 status
systemctl status bind9

# Stop and disable
sudo systemctl stop bind9
sudo systemctl disable bind9

# Remove bind9 if not needed
sudo apt remove bind9
```

**3. Custom DNS services:**
```bash
# Find custom DNS processes
ps aux | grep -E "(dns|bind|unbound)"

# Stop custom services
sudo killall dnsmasq
sudo killall named

# Disable custom services
sudo systemctl stop custom-dns
sudo systemctl disable custom-dns
```

**Port conflict resolution:**
```bash
# Force stop processes on conflicting ports
sudo fuser -k 53/tcp
sudo fuser -k 5353/tcp

# Verify ports are free
sudo netstat -tulpn | grep -E ":53|:5353"

# Restart DNS services
sudo systemctl restart stubby
sudo systemctl restart dnsmasq
```

### High Latency

**Symptoms:**
- DNS queries take > 500ms consistently
- Web browsing feels slow or unresponsive
- DNS timeouts occur frequently
- Cache hit rates are low

**Diagnosis:**
```bash
# Measure DNS query latency
dig google.com +stats

# Test multiple queries
for i in {1..5}; do
    time dig google.com
    echo "---"
done

# Test upstream server performance
dig @1.1.1.1 google.com +stats
dig @9.9.9.9 google.com +stats
dig @8.8.8.8 google.com +stats

# Check network connectivity
ping -c 10 1.1.1.1
```

**Common causes and solutions:**

**1. Slow upstream servers:**
```bash
# Test different DNS providers
time dig @1.1.1.1 google.com
time dig @9.9.9.9 google.com
time dig @8.8.8.8 google.com

# Reorder servers by performance in stubby.yml
# Put fastest servers first
```

**2. Network connectivity issues:**
```bash
# Check network interface
ip addr show

# Check routing
ip route show

# Test different network paths
traceroute 1.1.1.1
```

**3. Cache not working:**
```bash
# Check cache statistics
echo "cache-stats" | nc localhost 53

# Verify DNSMasq is using Stubby
cat /etc/dnsmasq.d/dns-stubby.conf

# Increase cache size
echo "cache-size=10000" | sudo tee -a /etc/dnsmasq.conf
sudo systemctl restart dnsmasq
```

**4. Too many cache misses:**
```bash
# Test cache performance
dig google.com  # Should be slow (cache miss)
dig google.com  # Should be fast (cache hit)

# Clear and test again
sudo systemctl restart dnsmasq
dig google.com  # Should be slow (cache cleared)
dig google.com  # Should be fast (cache populated)
```

**Performance optimization:**
```bash
# Increase DNSMasq cache size
echo "cache-size=15000" | sudo tee -a /etc/dnsmasq.conf

# Adjust cache TTL
echo "local-ttl=600" | sudo tee -a /etc/dnsmasq.conf

# Enable additional optimizations
echo "query-type=any" | sudo tee -a /etc/dnsmasq.conf

# Restart service
sudo systemctl restart dnsmasq
```

### Cache Issues

**Symptoms:**
- DNS queries always slow (no caching effect)
- Cache statistics show no growth
- Memory usage increases without bound
- Repeated queries to same domain remain slow

**Diagnosis:**
```bash
# Check cache statistics
echo "dump-nodes" | nc localhost 53
echo "cache-stats" | nc localhost 53

# Monitor cache behavior
for i in {1..5}; do
    time dig google.com
    sleep 1
done

# Check DNSMasq configuration
grep -i cache /etc/dnsmasq.conf
```

**Common causes and solutions:**

**1. Cache size too small:**
```bash
# Check current cache size
grep cache-size /etc/dnsmasq.conf

# Increase cache size
echo "cache-size=15000" | sudo tee -a /etc/dnsmasq.conf

# Restart DNSMasq
sudo systemctl restart dnsmasq

# Test cache improvement
time dig google.com  # First query
time dig google.com  # Should be faster
```

**2. Cache disabled:**
```bash
# Check for cache-disabling options
grep -i no-cache /etc/dnsmasq.conf
grep -i no-hosts /etc/dnsmasq.conf

# Remove cache-disabling options
sudo sed -i '/no-cache/d' /etc/dnsmasq.conf
sudo sed -i '/no-hosts/d' /etc/dnsmasq.conf

# Restart service
sudo systemctl restart dnsmasq
```

**3. Cache conflicts:**
```bash
# Check for multiple DNSMasq instances
ps aux | grep dnsmasq

# Stop duplicate instances
sudo killall dnsmasq
sudo systemctl start dnsmasq
```

**4. Memory issues:**
```bash
# Check memory usage
free -h
ps aux | grep dnsmasq

# Reduce cache size if memory constrained
echo "cache-size=5000" | sudo tee -a /etc/dnsmasq.conf

# Restart service
sudo systemctl restart dnsmasq
```

**Cache performance testing:**
```bash
# Clear cache and test
sudo systemctl restart dnsmasq

# Test cache miss (slow)
time dig google.com +stats

# Test cache hit (fast)
time dig google.com +stats

# Test cache persistence
sleep 300
time dig google.com +stats  # Should still be fast
```

### systemd-resolved Conflicts

**Symptoms:**
- Port 53 already in use errors
- systemd-resolved interferes with DNSMasq
- Dual DNS services causing conflicts
- System resolver points to wrong DNS servers

**Diagnosis:**
```bash
# Check systemd-resolved status
systemctl status systemd-resolved

# Check current resolver configuration
cat /etc/resolv.conf

# Check for DNS service conflicts
systemctl list-units --all | grep dns
```

**Resolution steps:**

**1. Stop and disable systemd-resolved:**
```bash
# Stop the service
sudo systemctl stop systemd-resolved

# Disable from automatic startup
sudo systemctl disable systemd-resolved

# Mask the service to prevent activation
sudo systemctl mask systemd-resolved
```

**2. Backup and restore resolv.conf:**
```bash
# Backup current configuration
sudo cp /etc/resolv.conf /etc/resolv.conf.backup

# Create new resolv.conf pointing to DNSMasq
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf
```

**3. Prevent systemd-resolved interference:**
```bash
# Edit DNS stub for systemd-resolved
sudo mkdir -p /etc/systemd/resolved.conf.d
echo -e "[DNS]\nDNS=127.0.0.1" | sudo tee /etc/systemd/resolved.conf.d/dns.conf

# Restart systemd services
sudo systemctl daemon-reload
```

**4. Verify resolution:**
```bash
# Test DNS resolution
nslookup google.com

# Check service status
systemctl status dnsmasq
systemctl status stubby

# Verify resolv.conf points to local DNS
cat /etc/resolv.conf
```

### Network Connectivity Loss

**Symptoms:**
- Complete DNS resolution failure
- No internet connectivity despite network interface up
- DNS queries timeout to all upstream servers
- Network appears connected but no DNS resolution

**Diagnosis:**
```bash
# Check network interface status
ip addr show
ip route show

# Test basic connectivity
ping -c 3 8.8.8.8
ping -c 3 1.1.1.1

# Test DNS server reachability
dig @1.1.1.1 google.com
dig @9.9.9.9 google.com
```

**Common causes and solutions:**

**1. Network interface issues:**
```bash
# Check interface status
ip link show

# Restart network interface
sudo ip link set eth0 down
sudo ip link set eth0 up

# Alternative: restart networking service
sudo systemctl restart networking
```

**2. Routing problems:**
```bash
# Check routing table
ip route show

# Add default route if missing
sudo ip route add default via 192.168.1.1 dev eth0

# Check gateway connectivity
ping -c 3 192.168.1.1
```

**3. DNS server unreachable:**
```bash
# Test different DNS servers
dig @8.8.8.8 google.com
dig @208.67.222.222 google.com

# Check if DNS providers are down
ping -c 5 1.1.1.1
ping -c 5 9.9.9.9
ping -c 5 8.8.8.8
```

**4. Firewall blocking:**
```bash
# Check firewall status
sudo ufw status
sudo iptables -L

# Allow DNS traffic
sudo ufw allow out 53
sudo ufw allow out 853

# Or temporarily disable firewall for testing
sudo ufw disable
```

**Recovery procedures:**
```bash
# Full network restart
sudo systemctl restart networking
sudo systemctl restart NetworkManager

# Restart DNS services
sudo systemctl restart stubby
sudo systemctl restart dnsmasq

# Test recovery
nslookup google.com
dig google.com +stats
```

### Permission Denied Errors

**Symptoms:**
- "Permission denied" when reading configuration files
- Services fail to start due to access issues
- Configuration validation fails
- File ownership problems

**Diagnosis:**
```bash
# Check file ownership and permissions
ls -la /etc/stubby/stubby.yml
ls -la /etc/dnsmasq.conf

# Check service user permissions
ps aux | grep stubby
ps aux | grep dnsmasq
```

**Common causes and solutions:**

**1. Wrong file ownership:**
```bash
# Fix ownership for Stubby config
sudo chown root:root /etc/stubby/stubby.yml
sudo chmod 644 /etc/stubby/stubby.yml

# Fix ownership for DNSMasq config
sudo chown root:root /etc/dnsmasq.conf
sudo chmod 644 /etc/dnsmasq.conf

# Restart services
sudo systemctl restart stubby
sudo systemctl restart dnsmasq
```

**2. SELinux/AppArmor issues:**
```bash
# Check SELinux status
getenforce

# Check AppArmor status
sudo aa-status

# Temporarily disable for testing
sudo setenforce 0
sudo systemctl restart stubby
```

**3. Service user permissions:**
```bash
# Check service configuration
sudo systemctl cat stubby

# Ensure services run as correct user
# Edit service file if needed
sudo systemctl edit stubby
```

### "Address Already in Use" Errors

**Symptoms:**
- Service startup fails with "Address already in use"
- Port binding errors in logs
- Multiple instances of same service
- Cannot bind to required ports

**Diagnosis:**
```bash
# Find process using the port
sudo netstat -tulpn | grep :53
sudo netstat -tulpn | grep :5353

# Find process by name
ps aux | grep stubby
ps aux | grep dnsmasq
```

**Resolution steps:**

**1. Kill conflicting processes:**
```bash
# Find and kill process using port 53
sudo fuser -k 53/tcp

# Find and kill process using port 5353
sudo fuser -k 5353/tcp

# Alternative: kill by process name
sudo killall stubby
sudo killall dnsmasq
```

**2. Stop conflicting services:**
```bash
# Stop and disable systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# Stop and disable bind9
sudo systemctl stop bind9
sudo systemctl disable bind9
```

**3. Remove stale processes:**
```bash
# Remove zombie processes
sudo pkill -f stubby
sudo pkill -f dnsmasq

# Wait and restart
sleep 2
sudo systemctl start stubby
sudo systemctl start dnsmasq
```

**4. Check for port conflicts:**
```bash
# List all DNS-related processes
sudo netstat -tulpn | grep dns

# Verify ports are free
sudo netstat -tuln | grep -E ":53|:5353"

# Restart DNS services
sudo systemctl restart stubby
sudo systemctl restart dnsmasq
```

---

## Security Considerations

### TLS Certificate Pinning

**Cloudflare Certificate Validation:**

Stubby uses TLS certificate pinning to ensure you're connecting to legitimate DNS providers:

```yaml
# /etc/stubby/stubby.yml
upstream_recursive_servers:
  - address_data: 1.1.1.1
    tls_auth_name: "cloudflare-dns.com"  # Certificate validation
    tls_port: 853
```

**What this prevents:**
- Man-in-the-middle attacks
- DNS server impersonation
- Malicious redirect of DNS queries
- Unauthorized monitoring of DNS traffic

**Quad9 Certificate Validation:**
```yaml
  - address_data: 9.9.9.9
    tls_auth_name: "dns.quad9.net"  # Certificate validation
    tls_port: 853
```

**Google Certificate Validation:**
```yaml
  - address_data: 8.8.8.8
    tls_auth_name: "dns.google"  # Certificate validation
    tls_port: 853
```

### DNSSEC Validation

**DNS Security Extensions (DNSSEC):**

SetDNScache enables DNSSEC validation to ensure DNS response integrity:

```yaml
# /etc/stubby/stubby.yml
dnssec:
  getaddrinfo: 1
  trustAnchor: https://www.internic.net/domain/root.key
```

**DNSSEC Benefits:**
- **Response Authenticity**: Ensures DNS responses haven't been tampered with
- **Domain Validation**: Verifies responses come from legitimate DNS servers
- **Chain of Trust**: Validates entire DNS resolution path
- **Spoofing Prevention**: Prevents malicious DNS response injection

**What DNSSEC Protects Against:**
- DNS cache poisoning attacks
- Malicious DNS redirect attacks
- Man-in-the-middle DNS interception
- Domain hijacking attempts

**Testing DNSSEC:**
```bash
# Test DNSSEC validation
dig +dnssec cloudflare.com

# Check for AD (Authenticated Data) flag
dig +dnssec cloudflare.com | grep "flags:"

# Should show: flags: qr rd ra ad; (ad = authenticated data)
```

### DNS over TLS Benefits

**Why DNS over TLS is Secure:**

**Traditional DNS (unencrypted):**
```
Client → ISP DNS Server → Internet
```
- ❌ ISP can see all DNS queries
- ❌ Governments can monitor DNS traffic
- ❌ Attackers can intercept DNS responses
- ❌ Queries can be modified in transit

**DNS over TLS (encrypted):**
```
Client → DNSMasq → Stubby → [TLS encrypted] → Cloudflare/Quad9/Google
```
- ✅ All DNS queries encrypted in transit
- ✅ No ISP visibility into DNS content
- ✅ Immune to network-level surveillance
- ✅ Response integrity guaranteed

**TLS Encryption Details:**
- **Encryption**: AES-256 encryption for all DNS traffic
- **Authentication**: Server certificate validation
- **Forward Secrecy**: Ephemeral key exchange
- **Port**: Standard DoT port 853

### Privacy Features

**Privacy Protection Mechanisms:**

**1. No Query Logging to Public Servers:**
- Cloudflare: "We don't track you across sites"
- Quad9: "Privacy by design, no logging"
- Google DNS: Minimal retention policies
- All providers: No personal data collection

**2. Local DNS Caching:**
```bash
# DNSMasq keeps queries local
# Queries stay on your system
# No external exposure of browsing patterns
```

**3. DNS Query Encryption:**
- All queries encrypted with TLS 1.3
- Perfect forward secrecy
- Certificate-based authentication

**Privacy Comparison:**

| DNS Provider | Logging Policy | Privacy Level | Data Collection |
|--------------|---------------|----------------|-----------------|
| **Cloudflare** | Minimal, anonymized | High | None (stated) |
| **Quad9** | No logging | Very High | None (verified) |
| **Google DNS** | Aggregated only | Medium | None (stated) |
| **ISP DNS** | Full logging | Low | Extensive |

### Running as Root Necessity

**Why Root Access is Required:**

**Service Binding Requirements:**
- DNSMasq needs to bind to port 53 (privileged port)
- Stubby needs to bind to port 5353 (if using system port)
- System resolver modification requires root privileges
- Service configuration installation requires root access

**Security Implications:**
- Script runs with elevated privileges for setup only
- Services run as dedicated system users after startup
- No persistent root access required for operation
- Services run with minimal required privileges

**Risk Mitigation:**
```bash
# Verify script integrity before running
sha256sum bin/secure-dns-setup.sh

# Review script content
less bin/secure-dns-setup.sh

# Run with minimal privileges
sudo bash bin/secure-dns-setup.sh
```

### Firewall Implications

**Required Firewall Rules:**

**Outbound Traffic:**
- Port 853: DNS-over-TLS to upstream servers
- Port 53: System resolver queries (if configured)
- Port 80/443: Package updates and certificate validation

**Inbound Traffic:**
- Port 53: Local DNS service (localhost only)
- Port 5353: Stubby service (localhost only)

**UFW Configuration:**
```bash
# Allow outbound DNS over TLS
sudo ufw allow out 853

# Allow system resolver
sudo ufw allow out 53

# Restrict local DNS to localhost only
sudo ufw deny 53
sudo ufw allow from 127.0.0.1 to any port 53
```

**iptables Configuration:**
```bash
# Allow DNS over TLS outbound
iptables -A OUTPUT -p tcp --dport 853 -j ACCEPT

# Allow local DNS only
iptables -A INPUT -p tcp --dport 53 -s 127.0.0.1 -j ACCEPT
iptables -A INPUT -p udp --dport 53 -s 127.0.0.1 -j ACCEPT
```

### Best Practices

**Security Best Practices:**

**1. Regular Updates:**
```bash
# Keep system updated
sudo apt update && sudo apt upgrade

# Update DNS software
sudo apt install --only-upgrade stubby dnsmasq
```

**2. Configuration Validation:**
```bash
# Validate configuration files
sudo stubby -C /etc/stubby/stubby.yml -t
sudo dnsmasq --test

# Check service status
systemctl status stubby dnsmasq
```

**3. Monitoring:**
```bash
# Monitor DNS logs
sudo tail -f /var/log/dns-setup.log

# Check for suspicious activity
sudo journalctl | grep -i error
```

**4. Access Control:**
```bash
# Restrict configuration file access
sudo chmod 600 /etc/stubby/stubby.yml
sudo chmod 600 /etc/dnsmasq.conf

# Audit service permissions
ps aux | grep stubby
ps aux | grep dnsmasq
```

**5. Network Segmentation:**
```bash
# If using multiple interfaces, restrict DNS service
# Edit /etc/stubby/stubby.yml
listen_addresses:
  - 127.0.0.1@5353  # Localhost only
  - 192.168.1.1@5353  # Internal network only
```

**6. Regular Security Audits:**
```bash
# Test DNSSEC validation regularly
dig +dnssec cloudflare.com

# Verify TLS connections
openssl s_client -connect 1.1.1.1:853 -servername cloudflare-dns.com

# Check certificate validity
echo | openssl s_client -connect 1.1.1.1:853 2>/dev/null | openssl x509 -noout -dates
```

**Security Monitoring Checklist:**
- [ ] TLS certificate validation working
- [ ] DNSSEC validation enabled and working
- [ ] No unauthorized DNS services running
- [ ] Firewall rules properly configured
- [ ] Log files monitored for anomalies
- [ ] Regular security updates applied
- [ ] Configuration files properly secured
- [ ] Service accounts have minimal privileges

---

## Performance Notes

### Typical Query Response Times

**Performance Benchmarks:**

**Cache Hits (Cached DNS Records):**
- **Excellent**: < 10ms
- **Good**: 10-30ms
- **Acceptable**: 30-50ms
- **Poor**: > 50ms

**Cache Misses (First Query to New Domain):**
- **Excellent**: < 100ms
- **Good**: 100-300ms
- **Acceptable**: 300-500ms
- **Poor**: > 500ms

**Performance Testing:**
```bash
# Test cache performance
dig google.com +stats  # First query (slow, cache miss)
sleep 2
dig google.com +stats  # Second query (fast, cache hit)

# Expected: Second query should be significantly faster
```

**Factors Affecting Performance:**

**1. Network Latency:**
- Geographic distance to DNS servers
- Internet connection speed
- Network congestion
- ISP routing efficiency

**2. Cache Effectiveness:**
- Cache size configuration
- Query patterns (repeated vs unique domains)
- Cache TTL settings
- Memory availability

**3. DNS Server Performance:**
- Server load and capacity
- Geographic proximity
- Network infrastructure quality
- Response optimization

### Cache Behavior and Warming

**Cache Lifecycle:**

**1. Cold Cache (First Startup):**
```
User Query → DNSMasq → Stubby → Upstream → Response → Cache → User
Duration: 500ms-2000ms (slowest)
```

**2. Cache Hit (Repeated Queries):**
```
User Query → DNSMasq → Local Cache → Response → User
Duration: <50ms (fastest)
```

**3. Cache Miss (New Domains):**
```
User Query → DNSMasq → Stubby → Upstream → Response → Cache → User
Duration: 100-500ms (depends on upstream)
```

**Cache Warming Process:**

**Phase 1: Initial Population (0-5 minutes)**
```bash
# Popular domains get cached quickly
dig google.com  # Cache miss
dig cloudflare.com  # Cache miss
dig github.com  # Cache miss

# Cache starts building
echo "cache-stats" | nc localhost 53  # Shows cache entries
```

**Phase 2: Active Warming (5-30 minutes)**
```bash
# Common queries build cache
dig facebook.com  # Cache miss → Cache hit
dig youtube.com  # Cache miss → Cache hit
dig wikipedia.org  # Cache miss → Cache hit

# Cache hit ratio improves
for i in {1..10}; do dig google.com; done  # All cache hits
```

**Phase 3: Stable Operation (30+ minutes)**
```bash
# 80-95% cache hit rate expected
# Average query latency stabilizes
# Performance reaches optimal levels

# Monitor cache effectiveness
dig +stats google.com | grep "Query time"
```

**Cache Statistics:**
```bash
# View cache performance
echo "dump-nodes" | nc localhost 53
echo "cache-stats" | nc localhost 53

# Monitor cache growth over time
for i in {1..10}; do
    echo "cache-stats" | nc localhost 53
    sleep 60
done
```

### Expected CPU/Memory Usage

**Resource Consumption:**

**CPU Usage:**
- **Idle**: 0-1% CPU usage
- **Active**: 2-5% CPU usage during queries
- **Peak**: 5-10% CPU usage during cache population
- **Average**: 1-2% CPU usage in normal operation

**Memory Usage:**
- **DNSMasq**: 15-25MB RAM (base + cache)
- **Stubby**: 10-20MB RAM (connection management)
- **Total**: 25-45MB RAM typical usage

**Memory Configuration:**
```bash
# Monitor memory usage
ps aux | grep -E "(stubby|dnsmasq)"
free -h

# Configure cache size based on available memory
# Available RAM: 2GB+ → cache-size=10000
# Available RAM: 1-2GB → cache-size=5000
# Available RAM: <1GB → cache-size=2000

echo "cache-size=10000" | sudo tee -a /etc/dnsmasq.conf
```

**Resource Monitoring:**
```bash
# Monitor resource usage
top -p $(pgrep stubby),$(pgrep dnsmasq)

# Check service memory limits
systemctl show stubby | grep -i memory
systemctl show dnsmasq | grep -i memory

# Monitor over time
watch -n 10 'ps aux | grep -E "(stubby|dnsmasq)"'
```

### Network Bandwidth Reduction

**Bandwidth Savings:**

**Without DNS Caching:**
```
Each domain query = ~100-200 bytes per request
1000 queries = 100-200KB bandwidth usage
```

**With DNS Caching:**
```
First query = 100-200 bytes
Subsequent queries = 0 bytes (local cache)
1000 queries = ~200 bytes bandwidth usage
```

**Bandwidth Savings Calculation:**
```bash
# Estimate savings based on query patterns
# Assume 80% cache hit rate

Queries per day: 10,000
Without caching: 10,000 × 150 bytes = 1.5MB
With caching: (2,000 × 150) + (8,000 × 0) = 300KB
Savings: 1.2MB per day (80% reduction)
```

**Network Impact Analysis:**
```bash
# Monitor DNS traffic
sudo tcpdump -i any port 53
sudo tcpdump -i any port 5353

# Measure DNS bandwidth usage
iftop -i eth0 -f "port 53 or port 5353"
```

**Optimization for Bandwidth:**
```bash
# Increase cache size for better hit rates
echo "cache-size=15000" | sudo tee -a /etc/dnsmasq.conf

# Adjust TTL for longer cache retention
echo "local-ttl=3600" | sudo tee -a /etc/dnsmasq.conf

# Restart service
sudo systemctl restart dnsmasq
```

### Optimization Tips

**Performance Optimization Strategies:**

**1. Cache Size Optimization:**
```bash
# Configure cache size based on use case
# Desktop: cache-size=5000
# Server: cache-size=10000
# Heavy usage: cache-size=20000

echo "cache-size=10000" | sudo tee -a /etc/dnsmasq.conf
sudo systemctl restart dnsmasq
```

**2. DNS Server Selection:**
```bash
# Test and select fastest servers
time dig @1.1.1.1 google.com +stats
time dig @9.9.9.9 google.com +stats
time dig @8.8.8.8 google.com +stats

# Reorder servers in stubby.yml by performance
```

**3. Network Interface Optimization:**
```bash
# Use fastest network interface
# Edit /etc/stubby/stubby.yml
listen_addresses:
  - 127.0.0.1@5353  # Use localhost

# Avoid remote interfaces for local DNS
```

**4. TTL Optimization:**
```bash
# Increase TTL for frequently accessed domains
echo "local-ttl=3600" | sudo tee -a /etc/dnsmasq.conf  # 1 hour
echo "max-ttl=86400" | sudo tee -a /etc/dnsmasq.conf  # 24 hours

sudo systemctl restart dnsmasq
```

**5. Performance Monitoring:**
```bash
# Regular performance testing
#!/bin/bash
for domain in google.com cloudflare.com github.com; do
    echo "Testing $domain:"
    time dig $domain
    echo "---"
done

# Set up automated monitoring
# Add to cron: */10 * * * * /path/to/dns-performance-test.sh
```

### Benchmarking

**DNS Performance Benchmarking:**

**1. Basic Performance Test:**
```bash
#!/bin/bash
# dns-benchmark.sh

DOMAINS=("google.com" "cloudflare.com" "github.com" "stackoverflow.com" "reddit.com")

echo "DNS Performance Benchmark"
echo "========================="

for domain in "${DOMAINS[@]}"; do
    echo "Testing $domain:"
    
    # Cold cache test
    sudo systemctl restart dnsmasq
    time dig $domain
    
    # Warm cache test
    sleep 2
    time dig $domain
    
    echo "---"
done
```

**2. Cache Effectiveness Test:**
```bash
#!/bin/bash
# cache-test.sh

echo "Cache Effectiveness Test"
echo "======================="

# Clear cache
sudo systemctl restart dnsmasq

# Test cache miss
echo "Cache miss test:"
time for i in {1..10}; do
    dig google.com +time=1 > /dev/null
done

# Test cache hit
echo "Cache hit test:"
time for i in {1..10}; do
    dig google.com +time=1 > /dev/null
done
```

**3. Upstream Performance Comparison:**
```bash
#!/bin/bash
# upstream-test.sh

SERVERS=("1.1.1.1" "9.9.9.9" "8.8.8.8")

echo "Upstream Server Performance"
echo "==========================="

for server in "${SERVERS[@]}"; do
    echo "Testing $server:"
    
    # Test with multiple queries
    time for i in {1..5}; do
        dig @$server google.com +time=1 > /dev/null
    done
    
    echo "---"
done
```

**Performance Analysis:**
```bash
# Collect performance data
dns-performance-test.sh > /tmp/dns-perf.log

# Analyze results
grep "real" /tmp/dns-perf.log | awk '{sum+=$2; count++} END {print "Average:", sum/count, "seconds"}'

# Compare cache vs non-cache performance
grep -A1 "Cold cache" /tmp/dns-perf.log
grep -A1 "Warm cache" /tmp/dns-perf.log
```

**Performance Baselines:**
```
Target Performance Benchmarks:
- Cache hit latency: < 30ms
- Cache miss latency: < 300ms
- Cache hit rate: > 80%
- Service availability: 99.9%
- Memory usage: < 50MB total
```

---

## Rollback & Uninstallation

### Using --rollback Flag

**Execute rollback procedure:**

```bash
# Complete rollback to pre-installation state
sudo bash bin/secure-dns-setup.sh --rollback

# Rollback with verbose output
sudo bash bin/secure-dns-setup.sh --rollback --verbose

# Rollback with confirmation
sudo bash bin/secure-dns-setup.sh --rollback --verbose
```

**Expected rollback output:**
```
============================================================================
  SetDNScache - Rollback Procedure
============================================================================
[INFO] 2024-01-11 15:30:15 - Starting rollback procedure...
[INFO] 2024-01-11 15:30:15 - Stopping DNS services...
[INFO] 2024-01-11 15:30:16 - Removing custom configurations...
[INFO] 2024-01-11 15:30:17 - Restoring original resolv.conf...
[INFO] 2024-01-11 15:30:18 - Re-enabling previous DNS services...
[INFO] 2024-01-11 15:30:19 - Cleaning up log files...
[INFO] 2024-01-11 15:30:20 - Rollback completed successfully!
[INFO] 2024-01-11 15:30:20 - Your system DNS configuration has been restored.
```

**What the rollback does:**

1. **Stops Services**
   - `systemctl stop stubby`
   - `systemctl stop dnsmasq`

2. **Removes Configurations**
   - `/etc/stubby/stubby.yml`
   - `/etc/dnsmasq.d/dns-stubby.conf`
   - Service files in `/etc/systemd/system/`

3. **Restores Original DNS**
   - Restores `/etc/resolv.conf` from backup
   - Re-enables `systemd-resolved` (if previously enabled)
   - Restores original DNS server settings

4. **Cleanup**
   - Removes log files
   - Cleans up temporary files
   - Removes custom configurations

### Manual Rollback Steps

**If automatic rollback fails, perform manual rollback:**

#### Step 1: Stop Services

```bash
# Stop DNS services
sudo systemctl stop dnsmasq
sudo systemctl stop stubby

# Disable services from auto-starting
sudo systemctl disable dnsmasq
sudo systemctl disable stubby

# Verify services are stopped
systemctl status dnsmasq stubby
```

#### Step 2: Restore Original resolv.conf

```bash
# Find the backup file
ls -la /etc/resolv.conf.backup*

# Restore the most recent backup
sudo cp /etc/resolv.conf.backup.YYYYMMDD_HHMMSS /etc/resolv.conf

# Or create a basic resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf
```

#### Step 3: Remove Custom Configurations

```bash
# Remove Stubby configuration
sudo rm -f /etc/stubby/stubby.yml

# Remove DNSMasq custom configuration
sudo rm -f /etc/dnsmasq.d/dns-stubby.conf

# Remove service files
sudo rm -f /etc/systemd/system/stubby.service
sudo rm -f /etc/systemd/system/dnsmasq.service
```

#### Step 4: Re-enable Previous Services

```bash
# Re-enable systemd-resolved (if it was enabled before)
sudo systemctl enable systemd-resolved
sudo systemctl start systemd-resolved

# Alternative: Re-enable other DNS services
sudo systemctl enable bind9
sudo systemctl start bind9
```

#### Step 5: Reload Systemd and Clean Up

```bash
# Reload systemd daemon
sudo systemctl daemon-reload

# Remove log files
sudo rm -f /var/log/dns-setup.log
sudo rm -f /tmp/dns-setup-*.log

# Clean up any temporary files
sudo rm -f /tmp/stubby-*
sudo rm -f /tmp/dnsmasq-*
```

### Restoring Original resolv.conf

**Manual resolv.conf restoration:**

```bash
# Backup current resolv.conf
sudo cp /etc/resolv.conf /etc/resolv.conf.current

# List available backups
ls -la /etc/resolv.conf.backup*

# Restore from specific backup
sudo cp /etc/resolv.conf.backup.YYYYMMDD_HHMMSS /etc/resolv.conf

# Verify restoration
cat /etc/resolv.conf
```

**Common original configurations:**

**Ubuntu/Debian with systemd-resolved:**
```bash
# Typical systemd-resolved configuration
sudo tee /etc/resolv.conf << EOF
nameserver 127.0.0.53
options edns0
EOF

# Start systemd-resolved
sudo systemctl start systemd-resolved
sudo systemctl enable systemd-resolved
```

**Basic ISP DNS configuration:**
```bash
# Generic ISP DNS setup
sudo tee /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
options timeout:2 attempts:3
EOF
```

**Custom DNS configuration:**
```bash
# Cloudflare DNS only
sudo tee /etc/resolv.conf << EOF
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

# Quad9 DNS only
sudo tee /etc/resolv.conf << EOF
nameserver 9.9.9.9
nameserver 149.112.112.112
EOF
```

### Removing Services

**Complete service removal:**

```bash
# Stop and disable services
sudo systemctl stop stubby dnsmasq
sudo systemctl disable stubby dnsmasq

# Remove service files
sudo rm -f /etc/systemd/system/stubby.service
sudo rm -f /etc/systemd/system/dnsmasq.service

# Reload systemd
sudo systemctl daemon-reload

# Optionally uninstall packages
sudo apt remove stubby dnsmasq
sudo apt autoremove
```

**Verify service removal:**
```bash
# Check services are removed
systemctl list-units --all | grep -E "(stubby|dnsmasq)"

# Check no processes running
ps aux | grep -E "(stubby|dnsmasq)"

# Check ports are free
netstat -tuln | grep -E ":53|:5353"
```

### Cleanup Commands

**Complete system cleanup:**

```bash
# Remove all configuration files
sudo rm -f /etc/stubby/stubby.yml
sudo rm -f /etc/dnsmasq.d/dns-stubby.conf
sudo rm -f /etc/dnsmasq.d/cache-settings.conf

# Remove log files
sudo rm -f /var/log/dns-setup.log
sudo rm -f /var/log/dnsmasq.log
sudo find /var/log -name "*dns*" -delete

# Remove temporary files
sudo rm -f /tmp/dns-setup*.log
sudo rm -f /tmp/stubby*.log
sudo rm -f /tmp/dnsmasq*.log

# Remove backup files (optional)
sudo find /etc -name "*stubby*backup*" -delete
sudo find /etc -name "*dnsmasq*backup*" -delete
```

**Network cleanup:**
```bash
# Clear DNS cache (if any)
sudo systemd-resolve --flush-caches 2>/dev/null || true

# Restart network services
sudo systemctl restart networking
sudo systemctl restart NetworkManager

# Clear browser DNS cache (if needed)
# Firefox: about:networking#dns → Clear DNS cache
# Chrome: chrome://net-internals/#dns → Clear host cache
```

### Verification After Rollback

**Test system after rollback:**

```bash
# Test DNS resolution
nslookup google.com

# Check service status
systemctl status systemd-resolved

# Verify resolv.conf
cat /etc/resolv.conf

# Test internet connectivity
ping -c 3 8.8.8.8
dig google.com
```

**Expected results after rollback:**

```bash
# DNS should work with original configuration
$ nslookup google.com
Server:		8.8.8.8
Address:	8.8.8.8#53

Non-authoritative answer:
Name:	google.com
Address: 142.250.185.46

# Services should be restored
$ systemctl status systemd-resolved
● systemd-resolved.service - Network Name Resolution
   Loaded: loaded (/lib/systemd/system/systemd-resolved.service; enabled)
   Active: active (running)
```

**Final verification checklist:**
- [ ] DNS resolution works with original configuration
- [ ] `systemctl status` shows original DNS service active
- [ ] `/etc/resolv.conf` points to original DNS servers
- [ ] No SetDNScache processes running
- [ ] Ports 53 and 5353 are free
- [ ] Internet connectivity fully functional
- [ ] Log files cleaned up

**If issues persist after rollback:**
```bash
# Restart network services
sudo systemctl restart networking
sudo systemctl restart systemd-resolved

# Clear DNS cache
sudo systemd-resolve --flush-caches

# Reboot system if needed
sudo reboot
```

---

## Advanced Topics

### Custom Upstream Servers with DNSSEC

**Configure alternative DNS providers with DNSSEC:**

**NextDNS (Custom Filtering):**
```bash
# Edit Stubby configuration
sudo nano /etc/stubby/stubby.yml

# Add NextDNS configuration
upstream_recursive_servers:
  - address_data: 45.90.28.0
    tls_auth_name: "your-account.nextdns.io"
    tls_port: 853
    tls_pubkey_pinset:
      - digest: "sha256"
        value: "YOUR_CERTIFICATE_HASH"
  - address_data: 45.90.30.0
    tls_auth_name: "your-account.nextdns.io"
    tls_port: 853
    tls_pubkey_pinset:
      - digest: "sha256"
        value: "YOUR_CERTIFICATE_HASH"

# Enable DNSSEC
dnssec:
  getaddrinfo: 1
  trustAnchor: https://www.internic.net/domain/root.key
```

**CleanBrowsing (Family-Safe DNS):**
```bash
# Add CleanBrowsing configuration
upstream_recursive_servers:
  - address_data: 185.228.168.9
    tls_auth_name: "cleanbrowsing.org"
    tls_port: 853
  - address_data: 185.228.169.9
    tls_auth_name: "cleanbrowsing.org"
    tls_port: 853
```

**AdGuard DNS (Ad Blocking):**
```bash
# Add AdGuard DNS configuration
upstream_recursive_servers:
  - address_data: 94.140.14.14
    tls_auth_name: "dns.adguard.com"
    tls_port: 853
  - address_data: 94.140.15.15
    tls_auth_name: "dns.adguard.com"
    tls_port: 853
```

**Quad9 with Enhanced Security:**
```bash
# Quad9 with DNSSEC and threat intelligence
upstream_recursive_servers:
  - address_data: 9.9.9.9
    tls_auth_name: "dns.quad9.net"
    tls_port: 853
  - address_data: 149.112.112.112
    tls_auth_name: "dns.quad9.net"
    tls_port: 853
```

**Certificate Pinning for Enhanced Security:**
```bash
# Get certificate hash for pinning
echo | openssl s_client -servername cloudflare-dns.com -connect 1.1.1.1:853 2>/dev/null | openssl x509 -outform PEM | openssl x509 -noout -fingerprint -sha256

# Add to configuration
upstream_recursive_servers:
  - address_data: 1.1.1.1
    tls_auth_name: "cloudflare-dns.com"
    tls_port: 853
    tls_pubkey_pinset:
      - digest: "sha256"
        value: "CERTIFICATE_FINGERPRINT_HERE"
```

### DNS over HTTPS (DoH) Configuration

**Installing DoH Support:**

While SetDNScache uses DNS over TLS (DoT), you can add DoH support for specific use cases:

```bash
# Install cloudflared for DoH
sudo apt install cloudflared

# Configure cloudflared
sudo mkdir -p /etc/cloudflared
sudo tee /etc/cloudflared/config.yml << EOF
proxy-dns: true
proxy-dns-address: 127.0.0.1
proxy-dns-port: 5053
proxy-dns-upstream:
  - https://1.1.1.1/dns-query
  - https://9.9.9.9/dns-query
EOF

# Start cloudflared service
sudo systemctl start cloudflared
sudo systemctl enable cloudflared
```

**DNSMasq Integration with DoH:**
```bash
# Configure DNSMasq to use DoH proxy
sudo tee /etc/dnsmasq.d/doh-proxy.conf << EOF
# Use cloudflared DoH proxy
server=127.0.0.1#5053

# Fallback to DoT if DoH fails
server=127.0.0.1#5353
EOF

# Restart DNSMasq
sudo systemctl restart dnsmasq
```

**Testing DoH Configuration:**
```bash
# Test DoH resolution
dig @127.0.0.1 -p 5053 google.com

# Check DoH service status
systemctl status cloudflared

# Monitor DoH traffic
sudo tail -f /var/log/cloudflared.log
```

### IPv6 Setup

**Enable IPv6 DNS Support:**

```bash
# Edit Stubby configuration for IPv6
sudo nano /etc/stubby/stubby.yml

# Add IPv6 upstream servers
upstream_recursive_servers:
  # IPv4 Cloudflare
  - address_data: 1.1.1.1
    tls_auth_name: "cloudflare-dns.com"
    tls_port: 853
  - address_data: 1.0.0.1
    tls_auth_name: "cloudflare-dns.com"
    tls_port: 853
  
  # IPv6 Cloudflare
  - address_data: 2606:4700:4700::1111
    tls_auth_name: "cloudflare-dns.com"
    tls_port: 853
  - address_data: 2606:4700:4700::1001
    tls_auth_name: "cloudflare-dns.com"
    tls_port: 853
  
  # IPv6 Quad9
  - address_data: 2620:fe::fe
    tls_auth_name: "dns.quad9.net"
    tls_port: 853
  - address_data: 2620:fe::9
    tls_auth_name: "dns.quad9.net"
    tls_port: 853
  
  # IPv6 Google
  - address_data: 2001:4860:4860::8888
    tls_auth_name: "dns.google"
    tls_port: 853
  - address_data: 2001:4860:4860::8844
    tls_auth_name: "dns.google"
    tls_port: 853
```

**DNSMasq IPv6 Configuration:**
```bash
# Enable IPv6 in DNSMasq
sudo tee -a /etc/dnsmasq.conf << EOF

# IPv6 support
enable-ipv6
domain-needed
bogus-priv

# IPv6 address ranges
dhcp-range=::,ra-only

# IPv6 DNS settings
dhcp-option=option6:dns-server,[::]
EOF

# Restart DNSMasq
sudo systemctl restart dnsmasq
```

**IPv6 Testing:**
```bash
# Test IPv6 DNS resolution
dig AAAA google.com

# Test IPv6 Stubby connectivity
dig @127.0.0.1 -p 5353 AAAA google.com

# Check IPv6 network connectivity
ping6 2606:4700:4700::1111
```

### Multi-System Setup

**Network-wide DNS Configuration:**

**Configure Router/Firewall:**
```bash
# Set router to use local DNS server
# Configure router DHCP to distribute local DNS server IP

# Example for router configuration:
# Primary DNS: 192.168.1.1 (local DNSMasq)
# Secondary DNS: 1.1.1.1 (fallback)
```

**DNS Forwarding Configuration:**
```bash
# Configure DNSMasq to accept external queries
sudo tee -a /etc/dnsmasq.conf << EOF

# Allow queries from local network
listen-address=127.0.0.1,192.168.1.1

# Accept queries from local network
bind-interfaces

# Set domain for local network
local=/local/
domain=local
EOF

# Restart DNSMasq
sudo systemctl restart dnsmasq
```

**Firewall Configuration for Network Access:**
```bash
# Allow DNS queries from local network
sudo ufw allow from 192.168.1.0/24 to any port 53

# Allow DNS over TLS from local network
sudo ufw allow from 192.168.1.0/24 to any port 5353

# Or use iptables
sudo iptables -A INPUT -p tcp --dport 53 -s 192.168.1.0/24 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 53 -s 192.168.1.0/24 -j ACCEPT
```

**Client Configuration:**
```bash
# Configure clients to use local DNS server
# Edit /etc/resolv.conf on client systems
echo "nameserver 192.168.1.1" | sudo tee /etc/resolv.conf

# For DHCP clients, configure router DHCP settings
```

### Integration with Other Tools

**Pi-hole Integration:**
```bash
# Install Pi-hole alongside SetDNScache
curl -sSL https://install.pi-hole.net | bash

# Configure Pi-hole to use Stubby
sudo tee /etc/pihole/setupVars.conf << EOF
PIHOLE_DNS_1=127.0.0.1#5353
PIHOLE_DNS_2=127.0.0.1#5353
EOF

# Restart Pi-hole
sudo systemctl restart pihole-FTL
```

**Unbound Integration:**
```bash
# Install Unbound for additional DNS features
sudo apt install unbound

# Configure Unbound to use Stubby
sudo tee /etc/unbound/unbound.conf.d/secure-dns.conf << EOF
forward-zone:
  name: "."
  forward-addr: 127.0.0.1@5353
EOF

# Restart Unbound
sudo systemctl restart unbound
```

** systemd-resolved Integration:**
```bash
# Configure systemd-resolved to use Stubby
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/secure-dns.conf << EOF
[Resolve]
DNS=127.0.0.1:5353
DNSStubListener=no
EOF

# Restart systemd-resolved
sudo systemctl restart systemd-resolved
```

### Performance Tuning

**Advanced Performance Configuration:**

**DNSMasq Performance Tuning:**
```bash
# Edit DNSMasq configuration
sudo tee -a /etc/dnsmasq.conf << EOF

# Increase cache size
cache-size=20000

# Set local TTL (reduce upstream queries)
local-ttl=300
max-ttl=3600
max-cache-ttl=86400

# Query optimization
query-rrs=RR
no-negcache
dns-forward-max=300
cache-querieshost
EOF
```

**Stubby Performance Tuning:**
```bash
# Edit Stubby configuration
sudo tee -a /etc/stubby/stubby.yml << EOF

# Connection optimization
connection-reuse: 1
timeout: 3

# TLS optimization
tls_cipher_list: 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256'
tls_ciphersuites: 'TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256'

# Performance settings
appdata_dir: '/var/lib/stubby'
EOF

# Restart Stubby
sudo systemctl restart stubby
```

**System-level Optimization:**
```bash
# Increase file descriptor limits
sudo tee -a /etc/security/limits.conf << EOF
stubby soft nofile 65535
stubby hard nofile 65535
dnsmasq soft nofile 65535
dnsmasq hard nofile 65535
EOF

# Optimize network settings
sudo tee -a /etc/sysctl.conf << EOF
# DNS performance
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
EOF

# Apply settings
sudo sysctl -p
```

### Custom Logging Configuration

**Advanced Logging Setup:**

**DNSMasq Logging:**
```bash
# Configure detailed logging
sudo tee -a /etc/dnsmasq.conf << EOF

# Logging configuration
log-queries-extra
log-facility=/var/log/dnsmasq.log
log-async=50

# Log rotation
log-rotate
max-logsize=10m
EOF

# Create log rotation configuration
sudo tee /etc/logrotate.d/dnsmasq << EOF
/var/log/dnsmasq.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        systemctl reload dnsmasq
    endscript
}
EOF
```

**Stubby Logging:**
```bash
# Configure Stubby logging
sudo tee -a /etc/stubby/stubby.yml << EOF

# Logging configuration
log_level:
  - 5  # Verbose logging

# Log file location
log_file: /var/log/stubby.log

# Audit configuration
audit_file: /var/log/stubby-audit.log
EOF

# Create log rotation for Stubby
sudo tee /etc/logrotate.d/stubby << EOF
/var/log/stubby.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        systemctl reload stubby
    endscript
}
EOF
```

**Centralized Logging:**
```bash
# Install rsyslog for centralized logging
sudo apt install rsyslog

# Configure rsyslog for DNS logs
sudo tee /etc/rsyslog.d/50-dns.conf << EOF
# DNS logs
local0.*    /var/log/dns.log
local1.*    /var/log/dns-debug.log
EOF

# Restart rsyslog
sudo systemctl restart rsyslog
```

**Log Analysis:**
```bash
# Analyze DNS query patterns
grep "query\[A\]" /var/log/dnsmasq.log | awk '{print $6}' | sort | uniq -c | sort -nr | head -20

# Monitor failed queries
grep "query\[A\]" /var/log/dnsmasq.log | grep "NXDOMAIN"

# Performance monitoring
grep "query time" /var/log/dnsmasq.log | tail -10
```

---

## FAQ

### Is it safe to run?

**Yes, SetDNScache is safe to run for several reasons:**

**Security Benefits:**
- ✅ **Encrypted DNS**: All DNS queries use TLS encryption
- ✅ **DNSSEC Validation**: DNS responses are cryptographically verified
- ✅ **Certificate Pinning**: Only legitimate DNS servers are trusted
- ✅ **No Query Logging**: Major providers don't log your queries
- ✅ **Local Caching**: DNS queries stay on your system

**Code Transparency:**
- ✅ **Open Source**: All scripts are readable and auditable
- ✅ **No Malware**: No network connections except to DNS providers
- ✅ **Minimal Privileges**: Only uses root during installation
- ✅ **Reversible**: Complete rollback capability

**Safety Verification:**
```bash
# Review the script before running
less bin/secure-dns-setup.sh

# Verify script integrity
sha256sum bin/secure-dns-setup.sh

# Check for network connections
sudo netstat -tulpn | grep -E "(stubby|dnsmasq)"
```

**Trust Level:**
- **High Trust**: All major DNS providers are established companies
- **No Data Collection**: Cloudflare, Quad9, and Google don't collect personal DNS data
- **Auditable Code**: You can review exactly what the script does

### Will it break my internet?

**No, SetDNScache is designed with safety mechanisms:**

**Built-in Safety Features:**
- **Automatic Rollback**: `--rollback` flag restores original configuration
- **Service Monitoring**: Checks service health continuously
- **Fallback Protection**: Multiple DNS providers ensure availability
- **No Permanent Changes**: All changes are reversible

**What happens if something goes wrong:**

**Scenario 1: Service fails to start**
```
Result: Internet continues working with original DNS
Action: System automatically falls back to backup DNS
User Impact: None
```

**Scenario 2: Network connectivity issues**
```
Result: DNS services stop, system uses backup DNS
Action: Automatic failover to secondary DNS servers
User Impact: Minimal (slight latency increase)
```

**Rollback Safety:**
```bash
# If anything goes wrong, rollback is immediate
sudo bash bin/secure-dns-setup.sh --rollback

# System returns to original DNS configuration
# No permanent changes or damage
```

**Testing Before Production:**
```bash
# Test functionality without changes
sudo bash bin/secure-dns-setup.sh --run-tests

# Test reboot survival
sudo bash bin/secure-dns-setup.sh --test-reboot

# Safe to run - changes can be easily reversed
```

### Can I customize DNS servers?

**Yes, extensive customization is supported:**

**Built-in Server Options:**
```bash
# Default configuration includes:
# Primary: Cloudflare (1.1.1.1, 1.0.0.1)
# Secondary: Quad9 (9.9.9.9, 149.112.112.112)  
# Tertiary: Google (8.8.8.8, 8.8.4.4)
```

**Popular Alternative Configurations:**

**Privacy-Focused (Quad9 only):**
```yaml
upstream_recursive_servers:
  - address_data: 9.9.9.9
    tls_auth_name: "dns.quad9.net"
    tls_port: 853
  - address_data: 149.112.112.112
    tls_auth_name: "dns.quad9.net"
    tls_port: 853
```

**Family-Safe (CleanBrowsing):**
```yaml
upstream_recursive_servers:
  - address_data: 185.228.168.9
    tls_auth_name: "cleanbrowsing.org"
    tls_port: 853
  - address_data: 185.228.169.9
    tls_auth_name: "cleanbrowsing.org"
    tls_port: 853
```

**Custom Provider (NextDNS):**
```yaml
upstream_recursive_servers:
  - address_data: 45.90.28.0
    tls_auth_name: "your-account.nextdns.io"
    tls_port: 853
  - address_data: 45.90.30.0
    tls_auth_name: "your-account.nextdns.io"
    tls_port: 853
```

**How to Modify:**
```bash
# Edit the configuration file
sudo nano /etc/stubby/stubby.yml

# Test configuration
sudo stubby -C /etc/stubby/stubby.yml -t

# Restart service
sudo systemctl restart stubby
```

**Requirements for Custom Servers:**
- Must support DNS over TLS (DoT) on port 853
- Must support DNSSEC validation
- Should have reliable global connectivity
- TLS certificate authentication required

### What about IPv6?

**IPv6 support is fully available and recommended:**

**Built-in IPv6 Support:**
- ✅ Cloudflare IPv6: `2606:4700:4700::1111`
- ✅ Quad9 IPv6: `2620:fe::fe`
- ✅ Google IPv6: `2001:4860:4860::8888`

**Enable IPv6 Configuration:**
```bash
# IPv6 is enabled by default in current versions
# Check IPv6 support
dig AAAA google.com

# Test IPv6 DNS resolution
dig @127.0.0.1 -p 5353 AAAA google.com
```

**IPv6 Benefits:**
- **Dual Stack**: Works with both IPv4 and IPv6
- **Future-Proof**: Ready for IPv6-only networks
- **Performance**: Often faster IPv6 routes available
- **Redundancy**: Additional DNS providers for reliability

**IPv6 Configuration Check:**
```bash
# Verify IPv6 is working
dig AAAA google.com | grep -A5 "ANSWER SECTION"

# Test IPv6 connectivity
ping6 2606:4700:4700::1111

# Check network interface
ip -6 addr show
```

### Does it work with VPNs?

**Yes, SetDNScache works seamlessly with VPNs:**

**How VPN Integration Works:**
- **Local DNS Unchanged**: DNSMasq still serves local DNS requests
- **VPN DNS**: VPN client can use secure DNS through tunnel
- **No Conflicts**: Services run independently

**VPN Compatibility:**
- ✅ **OpenVPN**: Fully compatible
- ✅ **WireGuard**: Fully compatible
- ✅ **IPSec**: Fully compatible
- ✅ **Commercial VPNs**: Generally compatible

**VPN Configuration Examples:**

**With OpenVPN:**
```bash
# VPN DNS is handled by VPN client
# SetDNScache provides local DNS resolution
# No conflicts - both can coexist

# Test VPN DNS while SetDNScache running
nslookup google.com  # Uses SetDNScache
nslookup internal-vpn-domain.com  # Uses VPN DNS
```

**With WireGuard:**
```bash
# WireGuard can use secure DNS providers
# SetDNScache continues to provide local caching
# VPN traffic uses encrypted DNS through tunnel

# Verify both work together
dig +short google.com  # Local DNS cache
dig +short internal.company.com  # VPN DNS
```

**Troubleshooting VPN Issues:**
```bash
# If VPN DNS conflicts with local DNS
# Edit VPN client configuration to use different DNS

# Or modify DNSMasq to handle VPN domains
echo "server=/vpn-domain.com/10.0.0.1" | sudo tee -a /etc/dnsmasq.d/vpn.conf
```

### Can I disable it?

**Yes, easy disable and re-enable capabilities:**

**Temporary Disable:**
```bash
# Stop services (keeps configuration)
sudo systemctl stop stubby
sudo systemctl stop dnsmasq

# System will fall back to original DNS
# Services can be restarted anytime
```

**Complete Disable:**
```bash
# Full rollback to original configuration
sudo bash bin/secure-dns-setup.sh --rollback

# System returns to pre-installation state
# No traces of SetDNScache remain
```

**Selective Disable:**
```bash
# Disable only DNSMasq (use upstream directly)
sudo systemctl stop dnsmasq
# Applications will use Stubby directly on port 5353

# Disable only Stubby (fallback to traditional DNS)
sudo systemctl stop stubby
# DNSMasq will use system resolver
```

**Re-enable After Disable:**
```bash
# Re-enable all services
sudo bash bin/secure-dns-setup.sh

# Or start individual services
sudo systemctl start stubby
sudo systemctl start dnsmasq
sudo systemctl enable stubby
sudo systemctl enable dnsmasq
```

**Verification After Disable:**
```bash
# Check services are stopped
systemctl status stubby dnsmasq

# Verify original DNS is working
cat /etc/resolv.conf
nslookup google.com
```

### Why port 5353 for Stubby?

**Port 5353 is used for architectural reasons:**

**Port Selection Rationale:**

**Port 53 (System DNS Port):**
- **Used by**: System resolver and most DNS clients
- **Conflict**: Would interfere with system DNS
- **Privilege**: Requires root for binding
- **Issue**: Would replace system DNS functionality

**Port 5353 (IANA Registered):**
- **Designated for**: DNS over TLS proxy services
- **Non-privileged**: Can bind without root (with capability)
- **Isolated**: Separate from system DNS operations
- **Flexible**: Can be changed if needed

**Architecture Benefits:**
```
Application → DNSMasq (port 53) → Stubby (port 5353) → TLS (port 853) → Internet
                ↑                        ↑
            System DNS              Encrypted DNS Proxy
```

**Port Flexibility:**
```bash
# If port 5353 conflicts, change it
# Edit /etc/stubby/stubby.yml
listen_addresses:
  - 127.0.0.1@5555  # Use custom port

# Update DNSMasq to use new port
# Edit /etc/dnsmasq.d/dns-stubby.conf
server=127.0.0.1#5555
```

### What's the performance impact?

**Minimal performance impact with significant benefits:**

**Resource Usage:**
- **Memory**: ~25-45MB RAM total
- **CPU**: 1-2% average usage
- **Disk**: ~50MB for software
- **Network**: Reduces overall DNS traffic by 80-95%

**Performance Comparison:**

**Without SetDNScache:**
```
Query: google.com
Duration: 100-500ms (depending on upstream)
Cache: None (every query goes to internet)
```

**With SetDNScache:**
```
First query: 100-500ms (goes to encrypted upstream)
Subsequent queries: <30ms (local cache)
Cache hit rate: 80-95%
```

**Performance Benefits:**
- **Faster Resolution**: Local cache speeds up repeated queries
- **Reduced Latency**: Eliminates network round trips
- **Bandwidth Savings**: 80-95% reduction in DNS traffic
- **Offline Capability**: Cached domains resolve without internet

**Performance Testing:**
```bash
# Test cache performance
time dig google.com  # First query (slow)
time dig google.com  # Second query (fast)

# Measure average improvement
for i in {1..10}; do time dig google.com; done
```

**Performance Monitoring:**
```bash
# Monitor service performance
systemctl status stubby dnsmasq

# Check resource usage
ps aux | grep -E "(stubby|dnsmasq)"
free -h

# Test latency
dig +stats google.com | grep "Query time"
```

### Is it DNSSEC validated?

**Yes, DNSSEC validation is enabled by default and strongly recommended:**

**DNSSEC Protection:**
- ✅ **Enabled by Default**: All configurations include DNSSEC
- ✅ **Cryptographic Validation**: DNS responses are cryptographically verified
- ✅ **Chain of Trust**: Validates entire DNS resolution path
- ✅ **Tampering Protection**: Prevents DNS response modification

**How DNSSEC Works:**
```
DNS Query → Stubby → DNSSEC Validation → Encrypted Response → Client
                ↓
           Signature Verification
                ↓
           Trust Chain Validation
                ↓
           ✅ Valid Response → Client
           ❌ Invalid Response → Rejected
```

**Testing DNSSEC Validation:**
```bash
# Test DNSSEC on known DNSSEC domains
dig +dnssec cloudflare.com

# Check for AD (Authenticated Data) flag
dig +dnssec cloudflare.com | grep "flags:"

# Expected: flags: qr rd ra ad; (ad = authenticated data)
```

**DNSSEC Validation Test Results:**

**Successful Validation:**
```
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 12345
;; flags: qr rd ra ad; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
                                                    ↑
                                            AD flag present
```

**Failed Validation:**
```
;; ->>HEADER<<- opcode: QUERY, status: SERVFAIL, id: 12345
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 0, ADDITIONAL: 0
                                                    ↑
                                            No AD flag
```

**What DNSSEC Protects Against:**
- **DNS Spoofing**: Prevents malicious DNS responses
- **Cache Poisoning**: Stops fake DNS entries in cache
- **Man-in-the-Middle**: Blocks intercepted and modified DNS queries
- **Domain Hijacking**: Prevents unauthorized domain resolution

**DNSSEC Configuration:**
```yaml
# /etc/stubby/stubby.yml
dnssec:
  getaddrinfo: 1
  trustAnchor: https://www.internic.net/domain/root.key
```

**DNSSEC Validation Levels:**
- **Strict**: Rejects unsigned domains (most secure)
- **Relaxed**: Allows unsigned domains (better compatibility)
- **Disabled**: No validation (not recommended)

**Troubleshooting DNSSEC Issues:**
```bash
# Check if DNSSEC is working
dig +dnssec +cd cloudflare.com

# Test DNSSEC chain
dig +dnssec +trace cloudflare.com

# Check root key validation
dig . @a.root-servers.net +dnssec
```

**DNSSEC Benefits Summary:**
- ✅ **Security**: Cryptographic verification of DNS responses
- ✅ **Integrity**: Ensures DNS data hasn't been tampered with
- ✅ **Authenticity**: Verifies responses come from legitimate sources
- ✅ **Trust**: Establishes chain of trust from root to domain

---

## Log File Reference

### Log Location

**Primary Log Files:**

| Log File | Service | Purpose | Format |
|----------|---------|---------|--------|
| `/var/log/dns-setup.log` | Setup Script | Installation and configuration logs | Text |
| `/var/log/stubby.log` | Stubby | DNS-over-TLS client logs | Text |
| `/var/log/dnsmasq.log` | DNSMasq | Local DNS cache logs | Text |

**System Journal Logs:**

| Command | Service | Purpose |
|---------|---------|---------|
| `sudo journalctl -u stubby` | Stubby | Systemd service logs |
| `sudo journalctl -u dnsmasq` | DNSMasq | Systemd service logs |
| `sudo journalctl \| grep dns` | All DNS | System-wide DNS activity |

**Test Logs:**

| Log File | Purpose | Creation |
|----------|---------|----------|
| `/tmp/dns-setup-preboot.log` | Pre-reboot test results | Pre-reboot check script |
| `/tmp/dns-setup-postboot.log` | Post-reboot test results | Post-reboot check script |
| `/var/log/dns-reboot-test-results.json` | Structured test results | Reboot testing |

### Log Format

**Setup Script Log Format (`/var/log/dns-setup.log`):**
```
[YYYY-MM-DD HH:MM:SS] [LEVEL] Message
[2024-01-11 13:52:15] [INFO] Starting secure DNS configuration...
[2024-01-11 13:52:16] [INFO] Checking dependencies...
[2024-01-11 13:52:17] [INFO] Installing stubby...
[2024-01-11 13:52:45] [INFO] Configuring DNS-over-TLS...
[2024-01-11 13:52:46] [INFO] Configuring DNSMasq...
[2024-01-11 13:52:47] [INFO] Starting services...
[2024-01-11 13:52:50] [INFO] DNS resolution test: PASS
[2024-01-11 13:52:51] [INFO] Setup completed successfully!
```

**Stubby Log Format:**
```
[Timestamp] [Level] [Component] Message
Jan 11 13:52:15 stubby[1234]: [stubby] Starting stubby version 1.4.0
Jan 11 13:52:15 stubby[1234]: [stubby] Read 3 upstream servers
Jan 11 13:52:16 stubby[1234]: [stubby] Opening listen sockets on 127.0.0.1 port 5353
Jan 11 13:52:16 stubby[1234]: [stubby] Listening on 127.0.0.1 port 5353
Jan 11 13:52:17 stubby[1234]: [stubby] TLS connection established to 1.1.1.1
```

**DNSMasq Log Format:**
```
[Timestamp] [Level] Message
Jan 11 13:52:16 dnsmasq[1235]: started, version 2.80 cachesize 10000
Jan 11 13:52:16 dnsmasq[1235]: compile time options: IPv6 GNU-getopt DBus
Jan 11 13:52:16 dnsmasq[1235]: using nameserver 127.0.0.1#5353
Jan 11 13:52:17 dnsmasq[1235]: query[A] google.com from 127.0.0.1
Jan 11 13:52:17 dnsmasq[1235]: forwarded google.com to 127.0.0.1#5353
Jan 11 13:52:18 dnsmasq[1235]: reply google.com is 142.250.185.46
```

### Understanding Log Messages

**Setup Script Messages:**

| Message Type | Meaning | Action Required |
|--------------|---------|-----------------|
| `[INFO]` | Normal operation message | None |
| `[WARN]` | Warning but not critical | Monitor |
| `[ERROR]` | Error occurred | Check troubleshooting |
| `[DEBUG]` | Detailed debugging info | Usually none |

**Stubby Messages:**

| Message | Meaning | Action |
|---------|---------|--------|
| `Starting stubby version X.X.X` | Service initialization | None |
| `Read X upstream servers` | Configuration loaded | None |
| `Opening listen sockets on port X` | Service binding to port | None |
| `TLS connection established to X.X.X.X` | Successful encrypted connection | None |
| `Connection to X.X.X.X failed` | Cannot reach DNS server | Check network |
| `Certificate verification failed` | TLS security issue | Check certificate |

**DNSMasq Messages:**

| Message | Meaning | Action |
|---------|---------|--------|
| `started, version X.X.X` | Service started | None |
| `query[A] domain.com from IP` | DNS query received | None (normal) |
| `reply domain.com is IP` | DNS response returned | None (normal) |
| `forwarded domain.com to IP:PORT` | Query forwarded upstream | None (normal) |
| `cannot resolve addresses` | Cannot resolve domain | Check network/DNS |
| `address already in use` | Port conflict | Check other DNS services |

### How to Filter Logs

**By Log Level:**
```bash
# Show only ERROR messages
grep "\[ERROR\]" /var/log/dns-setup.log

# Show WARN and ERROR messages
grep -E "\[(WARN|ERROR)\]" /var/log/dns-setup.log

# Show only Stubby INFO messages
grep "\[INFO\]" /var/log/stubby.log
```

**By Time Range:**
```bash
# Show last hour of logs
sudo journalctl --since "1 hour ago" -u stubby

# Show logs from specific date range
sudo journalctl --since "2024-01-11 13:00:00" --until "2024-01-11 14:00:00" -u dnsmasq

# Show recent setup logs
tail -50 /var/log/dns-setup.log
```

**By Service:**
```bash
# Show only Stubby logs
sudo journalctl -u stubby --no-pager

# Show only DNSMasq logs
sudo journalctl -u dnsmasq --no-pager

# Show DNS-related system logs
sudo journalctl | grep -E "(stubby|dnsmasq|dns)" | tail -20
```

**By Message Type:**
```bash
# Show DNS queries only
grep "query\[" /var/log/dnsmasq.log

# Show failed connections
grep -i "failed\|error" /var/log/stubby.log

# Show setup progression
grep "\[INFO\]" /var/log/dns-setup.log | head -10
```

**Complex Filtering:**
```bash
# Show ERROR logs with context
grep -A2 -B2 "\[ERROR\]" /var/log/dns-setup.log

# Show DNS resolution failures
grep -i "cannot resolve\|nxdomain" /var/log/dnsmasq.log

# Show TLS connection issues
grep -i "tls\|certificate" /var/log/stubby.log
```

### Log Rotation Recommendations

**DNSMasq Log Rotation:**
```bash
# Configure log rotation
sudo tee /etc/logrotate.d/dnsmasq << EOF
/var/log/dnsmasq.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        systemctl reload dnsmasq
    endscript
}
EOF
```

**Stubby Log Rotation:**
```bash
# Configure Stubby log rotation
sudo tee /etc/logrotate.d/stubby << EOF
/var/log/stubby.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        systemctl reload stubby
    endscript
}
EOF
```

**Setup Log Rotation:**
```bash
# Configure setup log rotation
sudo tee /etc/logrotate.d/dns-setup << EOF
/var/log/dns-setup.log {
    monthly
    rotate 3
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF
```

**Systemd Journal Rotation:**
```bash
# Configure journald rotation
sudo tee -a /etc/systemd/journald.conf << EOF
# DNS log retention
SystemMaxUse=100M
SystemKeepFree=50M
MaxRetentionSec=2week
EOF

# Restart journald
sudo systemctl restart systemd-journald
```

### Archiving Logs

**Manual Log Archiving:**
```bash
# Create timestamped log archive
LOG_DATE=$(date +%Y%m%d_%H%M%S)
sudo tar -czf /tmp/dns-logs-${LOG_DATE}.tar.gz \
    /var/log/dns-setup.log \
    /var/log/stubby.log \
    /var/log/dnsmasq.log \
    /tmp/dns-setup-*.log

# Verify archive
sudo tar -tzf /tmp/dns-logs-${LOG_DATE}.tar.gz
```

**Automated Log Archiving:**
```bash
# Create archive script
sudo tee /usr/local/bin/archive-dns-logs.sh << EOF
#!/bin/bash
LOG_DATE=\$(date +%Y%m%d_%H%M%S)
ARCHIVE_DIR="/var/log/dns-archives"
mkdir -p "\$ARCHIVE_DIR"

tar -czf "\$ARCHIVE_DIR/dns-logs-\$LOG_DATE.tar.gz" \
    /var/log/dns-setup.log \
    /var/log/stubby.log \
    /var/log/dnsmasq.log

# Keep only last 30 days of archives
find "\$ARCHIVE_DIR" -name "dns-logs-*.tar.gz" -mtime +30 -delete
EOF

sudo chmod +x /usr/local/bin/archive-dns-logs.sh

# Add to cron for weekly archiving
echo "0 2 * * 0 root /usr/local/bin/archive-dns-logs.sh" | sudo tee -a /etc/crontab
```

**Log Analysis Script:**
```bash
# Create log analysis script
sudo tee /usr/local/bin/analyze-dns-logs.sh << EOF
#!/bin/bash
LOG_FILE="/var/log/dns-setup.log"
ANALYSIS_FILE="/tmp/dns-analysis-$(date +%Y%m%d_%H%M%S).txt"

echo "DNS Log Analysis Report" > "\$ANALYSIS_FILE"
echo "=======================" >> "\$ANALYSIS_FILE"
echo "Generated: \$(date)" >> "\$ANALYSIS_FILE"
echo "" >> "\$ANALYSIS_FILE"

echo "Setup Duration:" >> "\$ANALYSIS_FILE"
grep "Setup completed" "\$LOG_FILE" >> "\$ANALYSIS_FILE"

echo "" >> "\$ANALYSIS_FILE"
echo "Error Count:" >> "\$ANALYSIS_FILE"
grep -c "\[ERROR\]" "\$LOG_FILE" >> "\$ANALYSIS_FILE"

echo "" >> "\$ANALYSIS_FILE"
echo "Warning Count:" >> "\$ANALYSIS_FILE"
grep -c "\[WARN\]" "\$LOG_FILE" >> "\$ANALYSIS_FILE"

echo "" >> "\$ANALYSIS_FILE"
echo "Recent Errors:" >> "\$ANALYSIS_FILE"
grep "\[ERROR\]" "\$LOG_FILE" | tail -5 >> "\$ANALYSIS_FILE"

cat "\$ANALYSIS_FILE"
EOF

sudo chmod +x /usr/local/bin/analyze-dns-logs.sh
```

---

## File Structure Reference

### Project Directory Structure

```
SetDNScache/
├── README.md                          # This documentation file
├── LICENSE                            # Unlicense license file
├── .gitignore                         # Git ignore rules
├── bin/                               # Main application scripts
│   └── secure-dns-setup.sh            # Primary setup and configuration script
├── tests/                             # Testing and validation scripts
│   ├── pre-reboot-check.sh            # Pre-reboot validation script
│   ├── post-reboot-check.sh           # Post-reboot validation script
│   └── reboot-test-helper.sh          # Reboot testing helper script
└── docs/                              # Additional documentation (if created)
```

### Configuration File Locations

**Stubby Configuration:**
```
/etc/stubby/stubby.yml                    # Main Stubby configuration
├── Upstream DNS servers
├── TLS settings
├── DNSSEC configuration
└── Listen addresses
```

**DNSMasq Configuration:**
```
/etc/dnsmasq.conf                         # Main DNSMasq configuration
/etc/dnsmasq.d/                          # Additional DNSMasq configurations
├── dns-stubby.conf                      # Integration with Stubby
├── cache-settings.conf                  # Cache configuration
└── local-domains.conf                   # Local DNS entries
```

**System Configuration:**
```
/etc/resolv.conf                          # System resolver configuration
/etc/systemd/system/                     # Systemd service files
├── stubby.service                      # Stubby systemd service
└── dnsmasq.service                     # DNSMasq systemd service
```

### Log File Locations

**Application Logs:**
```
/var/log/dns-setup.log                   # Setup script execution log
/var/log/stubby.log                      # Stubby service log
/var/log/dnsmasq.log                     # DNSMasq service log
```

**Systemd Logs:**
```
# Accessed via journalctl:
sudo journalctl -u stubby                 # Stubby systemd journal
sudo journalctl -u dnsmasq                # DNSMasq systemd journal
sudo journalctl | grep dns                # All DNS-related logs
```

**Test Logs:**
```
/tmp/dns-setup-preboot.log               # Pre-reboot test results
/tmp/dns-setup-postboot.log              # Post-reboot test results
/var/log/dns-reboot-test-results.json    # Structured test results
```

### Backup File Locations

**Configuration Backups:**
```
/etc/resolv.conf.backup.YYYYMMDD_HHMMSS   # Original system resolver backup
/etc/stubby/stubby.yml.backup            # Original Stubby config backup
/etc/dnsmasq.conf.backup                 # Original DNSMasq config backup
```

**Automatic Backups:**
```bash
# Backups are created during setup
ls -la /etc/resolv.conf.backup*

# Manual backup before changes
sudo cp /etc/resubb.conf /etc/stubby/stubby.yml.backup.$(date +%Y%m%d_%H%M%S)
```

### Test Script Locations

**Test Scripts:**
```
tests/pre-reboot-check.sh                 # Pre-reboot validation
tests/post-reboot-check.sh                # Post-reboot validation
tests/reboot-test-helper.sh               # Reboot testing utilities
```

**Running Tests:**
```bash
# From project directory
sudo bash tests/pre-reboot-check.sh
sudo bash tests/post-reboot-check.sh
sudo bash tests/reboot-test-helper.sh

# From main script
sudo bash bin/secure-dns-setup.sh --run-tests
sudo bash bin/secure-dns-setup.sh --test-reboot
```

### Runtime File Locations

**Service Runtime Files:**
```
/var/lib/stubby/                          # Stubby runtime data
/var/run/stubby/                          # Stubby runtime sockets
/var/lib/dnsmasq/                         # DNSMasq runtime data
└── /var/lib/dnsmasq/hosts                # DNSMasq hosts file
```

**Cache Files:**
```
# DNSMasq creates runtime cache files
/var/lib/dnsmasq/                         # DNSMasq runtime directory
```

### Temporary File Locations

**Setup Temporary Files:**
```
/tmp/dns-setup-*.log                      # Setup script temporary logs
/tmp/stubby-*.tmp                         # Stubby temporary files
/tmp/dnsmasq-*.tmp                        # DNSMasq temporary files
```

**Package Management:**
```
/var/lib/apt/lists/                       # APT package lists
/var/cache/apt/                           # Downloaded packages
└── /var/cache/apt/archives/              # Package cache
```

### System Integration Files

**Network Configuration:**
```
/etc/hosts                                # System hosts file
/etc/hostname                             # System hostname
/etc/network/interfaces                   # Network interface configuration
└── /etc/systemd/resolved.conf.d/         # systemd-resolved configuration
```

**Service Integration:**
```
/etc/systemd/system/multi-user.target.wants/
├── stubby.service                        # Stubby auto-start enable
└── dnsmasq.service                      # DNSMasq auto-start enable
```

---

## Support & Contributing

### Reporting Issues

**How to Report Problems:**

**1. Gather Information:**
```bash
# Collect system information
uname -a
lsb_release -a
systemctl --version

# Check service status
systemctl status stubby dnsmasq

# Collect logs
sudo journalctl -u stubby --no-pager -n 50 > stubby.log
sudo journalctl -u dnsmasq --no-pager -n 50 > dnsmasq.log
sudo tail -100 /var/log/dns-setup.log > setup.log

# Test connectivity
sudo bash bin/secure-dns-setup.sh --run-tests
```

**2. Create Issue Report:**
```markdown
## System Information
- OS: [Ubuntu/Debian version]
- Architecture: [x86_64/arm64]
- SetDNScache version: [if known]

## Problem Description
[Clear description of the issue]

## Steps to Reproduce
1. [First step]
2. [Second step]
3. [Third step]

## Expected Behavior
[What should happen]

## Actual Behavior
[What actually happened]

## Logs
[Include relevant log excerpts]

## Configuration Files
[Include relevant config file contents]

## Additional Context
[Any other relevant information]
```

**3. Common Issue Categories:**
- **Installation Problems**: Setup script fails
- **Service Issues**: Services won't start or keep crashing
- **Network Problems**: DNS resolution not working
- **Performance Issues**: Slow DNS queries or high resource usage
- **Compatibility Issues**: Conflicts with other software

### Requesting Features

**Feature Request Process:**

**1. Check Existing Issues:**
- Search existing issues for similar requests
- Review current documentation for workarounds
- Consider if feature fits project scope

**2. Feature Request Template:**
```markdown
## Feature Description
[Clear description of the feature]

## Use Case
[Why is this feature needed? What problem does it solve?]

## Proposed Implementation
[How you think this could be implemented]

## Alternative Solutions
[Any alternative approaches you've considered]

## Additional Context
[Any other relevant information]
```

**3. Prioritization Criteria:**
- **Security Enhancement**: Features improving DNS security
- **Performance Optimization**: Performance-related improvements
- **User Experience**: Better usability and configuration
- **Compatibility**: Support for additional systems or software
- **Monitoring**: Better logging, metrics, and diagnostics

### Contributing Improvements

**How to Contribute:**

**1. Code Contributions:**
```bash
# Fork and clone the repository
git clone <repository-url>
cd SetDNScache

# Create feature branch
git checkout -b feature/your-feature-name

# Make changes
# Test thoroughly
sudo bash bin/secure-dns-setup.sh --run-tests

# Commit changes
git add .
git commit -m "Add: Brief description of changes"

# Push and create pull request
git push origin feature/your-feature-name
```

**2. Documentation Contributions:**
- Improve existing documentation
- Add examples and use cases
- Fix typos and formatting
- Translate documentation
- Create tutorials

**3. Testing Contributions:**
- Test on different distributions
- Create additional test cases
- Improve error handling
- Performance testing
- Security testing

**Contribution Guidelines:**
- **Code Style**: Follow existing bash scripting conventions
- **Testing**: Include tests for new functionality
- **Documentation**: Update docs for any changes
- **Security**: No security regressions
- **Backwards Compatibility**: Maintain existing functionality

### License Information

**License Details:**
- **Type**: Unlicense (Public Domain)
- **File**: `LICENSE`
- **Usage**: Free to use, modify, and distribute
- **Commercial Use**: Allowed
- **Attribution**: Not required (but appreciated)

**Unlicense Summary:**
```
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any means.
```

### Repository Links

**Current Repository Structure:**
- **Main Branch**: `docs/readme-setdnscache`
- **Documentation Focus**: README and user guides
- **Scripts**: `bin/` and `tests/` directories

**File Locations:**
- **Source Code**: `bin/secure-dns-setup.sh`
- **Tests**: `tests/*.sh`
- **Documentation**: `README.md`
- **License**: `LICENSE`

### Community Support

**Getting Help:**

**1. Documentation First:**
- Read this README thoroughly
- Check the troubleshooting section
- Review FAQ for common issues
- Examine log files for error messages

**2. Self-Help Tools:**
```bash
# Run diagnostic tests
sudo bash bin/secure-dns-setup.sh --run-tests

# Check service status
systemctl status stubby dnsmasq

# Review logs
sudo journalctl -u stubby -f
sudo tail -f /var/log/dns-setup.log

# Test connectivity
nslookup google.com
dig google.com +stats
```

**3. Support Channels:**
- **Documentation**: This README and FAQ
- **Community**: Open an issue for bugs or feature requests
- **Professional Support**: Consider commercial DNS services for enterprise needs

**Best Practices for Support:**
- Search existing documentation first
- Try basic troubleshooting steps
- Provide detailed system information
- Include relevant log excerpts
- Be specific about expected vs actual behavior

---

## Examples & Use Cases

### Home Network Setup

**Complete Home Network DNS Security:**

**Scenario:** Family home with multiple devices (laptops, phones, tablets, smart TV)

**Benefits:**
- All devices get secure DNS automatically via DHCP
- Faster browsing through local DNS caching
- Protection from DNS-based malware and ads
- Privacy from ISP DNS logging

**Implementation:**
```bash
# 1. Set up SetDNScache on router/gateway
sudo bash bin/secure-dns-setup.sh

# 2. Configure router DHCP to use local DNS
# Router admin panel: DHCP Settings
# Primary DNS: 192.168.1.1 (your router IP)
# Secondary DNS: 1.1.1.1 (fallback)

# 3. Configure firewall for network access
sudo ufw allow from 192.168.1.0/24 to any port 53

# 4. Test from multiple devices
nslookup google.com  # From any device on network
```

**Expected Results:**
- **All devices** use encrypted DNS automatically
- **Cache sharing** across devices for better performance
- **Malware protection** through DNS filtering
- **Privacy protection** from ISP DNS monitoring

### Server Setup

**Production Server DNS Security:**

**Scenario:** Web server, database server, or application server requiring reliable DNS

**Benefits:**
- No external DNS dependencies during outages
- Faster DNS resolution for applications
- DNSSEC validation for security
- Local cache reduces load on DNS providers

**Implementation:**
```bash
# 1. Set up SetDNScache with high cache size
sudo bash bin/secure-dns-setup.sh

# 2. Optimize for server usage
echo "cache-size=20000" | sudo tee -a /etc/dnsmasq.conf
echo "local-ttl=600" | sudo tee -a /etc/dnsmasq.conf
sudo systemctl restart dnsmasq

# 3. Configure monitoring
# Add to /etc/monitoring/agents:
*/5 * * * * root /usr/local/bin/dns-health-check.sh

# 4. Set up log rotation
sudo tee /etc/logrotate.d/dns-server << EOF
/var/log/dnsmasq.log {
    daily
    rotate 30
    compress
    postrotate
        systemctl reload dnsmasq
    endscript
}
EOF
```

**Monitoring Script:**
```bash
#!/bin/bash
# /usr/local/bin/dns-health-check.sh
DNS_RESOLVE=$(nslookup google.com localhost | grep -c "Address: 142.250.185.46")
if [ "$DNS_RESOLVE" -eq 0 ]; then
    echo "CRITICAL: DNS resolution failed" | logger
    systemctl restart dnsmasq
fi
```

### Desktop Privacy Setup

**Individual Desktop Privacy Configuration:**

**Scenario:** Privacy-conscious user wanting encrypted DNS on personal computer

**Benefits:**
- Complete DNS query encryption
- No ISP visibility into browsing patterns
- Protection from DNS surveillance
- Local caching for performance

**Implementation:**
```bash
# 1. Install SetDNScache
sudo bash bin/secure-dns-setup.sh

# 2. Configure for maximum privacy
sudo tee -a /etc/stubby/stubby.yml << EOF
# Use only privacy-focused providers
upstream_recursive_servers:
  # Quad9 (no logging)
  - address_data: 9.9.9.9
    tls_auth_name: "dns.quad9.net"
    tls_port: 853
  - address_data: 149.112.112.112
    tls_auth_name: "dns.quad9.net"
    tls_port: 853
EOF

sudo systemctl restart stubby

# 3. Configure DNSMasq with privacy settings
sudo tee -a /etc/dnsmasq.conf << EOF
# Don't log queries
no-resolv
no-hosts

# Maximum privacy
log-queries-extra=2
log-facility=/var/log/dnsmasq-privacy.log
EOF

sudo systemctl restart dnsmasq
```

**Privacy Verification:**
```bash
# Verify DNS encryption
dig google.com +stats | grep "Query time"

# Check that ISP DNS is not being used
cat /etc/resolv.conf
# Should show: nameserver 127.0.0.1

# Monitor privacy logs
sudo tail -f /var/log/dnsmasq-privacy.log
```

### Multi-User System Setup

**Enterprise/Multi-User DNS Configuration:**

**Scenario:** Office or multi-user system where different users have different DNS needs

**Benefits:**
- Centralized DNS management
- User-specific DNS policies
- Bandwidth optimization
- Compliance with security policies

**Implementation:**
```bash
# 1. Set up SetDNScache with advanced features
sudo bash bin/secure-dns-setup.sh

# 2. Configure user-specific DNS policies
sudo tee /etc/dnsmasq.d/user-policies.conf << EOF
# Admin users get full DNS access
dhcp-host=192.168.1.10,set:admin,admin-users

# Regular users get filtered DNS
dhcp-host=192.168.1.20,set:regular,regular-users

# Guest users get restricted DNS
dhcp-host=192.168.1.30,set:guest,guest-users

# Different DNS policies per group
server=/work-sites.com/127.0.0.1#5353
server=/entertainment.com/9.9.9.9
EOF

# 3. Configure monitoring and reporting
sudo tee /etc/dnsmasq.d/monitoring.conf << EOF
# Log all DNS queries for analysis
log-queries-extra
log-facility=/var/log/dns-audit.log

# Per-user query logging
local-ptr=/1.168.192.in-addr.arpa/=user-prefix-
EOF

sudo systemctl restart dnsmasq
```

**User Management Script:**
```bash
#!/bin/bash
# /usr/local/bin/user-dns-policy.sh
USER=$1
POLICY=$2

case $POLICY in
    "admin")
        echo "User $USER configured with admin DNS policy"
        ;;
    "filtered")
        echo "User $USER configured with filtered DNS"
        ;;
    "restricted")
        echo "User $USER configured with restricted DNS"
        ;;
    *)
        echo "Unknown policy: $POLICY"
        ;;
esac
```

### Docker Container Setup (Future)

**Containerized DNS Security:**

**Note:** This is a planned feature for future versions

**Scenario:** Running SetDNScache in Docker for containerized environments

**Benefits:**
- Isolated DNS service for containers
- Consistent DNS across container orchestration
- Easy deployment and scaling
- Resource isolation

**Planned Implementation:**
```dockerfile
# Dockerfile (planned)
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \\
    stubby dnsmasq iptables \\
    && rm -rf /var/lib/apt/lists/*

COPY bin/secure-dns-setup.sh /usr/local/bin/
COPY config/ /etc/stubby/

EXPOSE 53 5353

CMD ["/usr/local/bin/secure-dns-setup.sh"]
```

**Planned Docker Compose:**
```yaml
# docker-compose.yml (planned)
version: '3.8'
services:
  dns:
    build: .
    ports:
      - "53:53/udp"
      - "53:53/tcp"
      - "5353:5353"
    volumes:
      - ./config:/etc/stubby
      - ./logs:/var/log
    restart: unless-stopped

  app:
    image: myapp:latest
    dns:
      - 172.20.0.1  # DNS service IP
    depends_on:
      - dns
```

### Testing Secure DNS Before Full Deployment

**Testing Environment Setup:**

**Scenario:** Testing SetDNScache before deploying to production

**Benefits:**
- Validate functionality without system-wide changes
- Test performance impact
- Verify compatibility with existing services
- Train users on new DNS behavior

**Implementation:**
```bash
# 1. Test without installation
sudo bash bin/secure-dns-setup.sh --run-tests

# 2. Dry run to see what would happen
sudo bash bin/secure-dns-setup.sh --dry-run --verbose

# 3. Install in test environment
sudo bash bin/secure-dns-setup.sh

# 4. Test reboot behavior
sudo bash bin/secure-dns-setup.sh --test-reboot

# 5. Monitor performance
for i in {1..10}; do
    echo "Test $i:"
    time dig google.com
    echo "---"
done

# 6. Test applications
curl -I https://google.com
ping -c 3 google.com
```

**Performance Benchmarking:**
```bash
#!/bin/bash
# dns-performance-test.sh

echo "DNS Performance Benchmark"
echo "========================="

# Test domains
DOMAINS=("google.com" "cloudflare.com" "github.com" "stackoverflow.com")

for domain in "${DOMAINS[@]}"; do
    echo "Testing $domain:"
    
    # Cold cache test
    sudo systemctl restart dnsmasq
    echo "Cold cache:"
    time dig $domain
    
    # Warm cache test
    echo "Warm cache:"
    time dig $domain
    
    echo "---"
done
```

**Validation Checklist:**
```bash
#!/bin/bash
# dns-validation-checklist.sh

echo "SetDNScache Validation Checklist"
echo "================================="

# 1. Service status
echo "1. Service Status:"
systemctl is-active stubby dnsmasq

# 2. DNS resolution
echo "2. DNS Resolution:"
nslookup google.com > /dev/null && echo "✓ Google" || echo "✗ Google"
nslookup cloudflare.com > /dev/null && echo "✓ Cloudflare" || echo "✗ Cloudflare"

# 3. Port accessibility
echo "3. Ports:"
netstat -tuln | grep -q ":53" && echo "✓ Port 53" || echo "✗ Port 53"
netstat -tuln | grep -q ":5353" && echo "✓ Port 5353" || echo "✗ Port 5353"

# 4. DNSSEC validation
echo "4. DNSSEC:"
dig +dnssec cloudflare.com | grep -q "ad;" && echo "✓ DNSSEC working" || echo "✗ DNSSEC failed"

# 5. Performance
echo "5. Performance:"
time dig google.com | grep "Query time"

echo "Validation complete!"
```

**Rollback Testing:**
```bash
# Test rollback functionality
sudo bash bin/secure-dns-setup.sh --rollback

# Verify rollback worked
nslookup google.com
cat /etc/resolv.conf

# Reinstall for production
sudo bash bin/secure-dns-setup.sh
```

---

*This documentation is comprehensive and covers all aspects of SetDNScache. For the latest updates and additional examples, please refer to the project repository.*