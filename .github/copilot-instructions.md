# SetDNScache AI Agent Instructions

## Project Overview

SetDNScache is a Bash-based DNS security solution implementing DNS-over-TLS with local caching. The system configures two key services:
- **Stubby** (port 5353): Handles DNS-over-TLS queries to upstream providers (Cloudflare primary, Quad9 secondary, Google tertiary)
- **DNSMasq** (port 53): Provides local DNS caching and DNSSEC validation, forwards queries through Stubby

## Architecture Essentials

**Core Data Flow**: Applications → DNSMasq (local cache) → Stubby (TLS encryption) → Upstream DNS providers

**Key Components in [bin/secure-dns-setup.sh](../bin/secure-dns-setup.sh)**:
- **Configuration sections**: Stubby YAML config (upstream server hierarchies), DNSMasq config (caching rules, DNSSEC settings)
- **Service management**: Enable/disable/restart systemd services with proper startup ordering (Stubby first, then DNSMasq)
- **Testing framework**: Built-in validation modes (`--run-tests`, `--test-reboot`) for post-deployment verification

**Testing Hierarchy** ([tests/](../tests/) directory):
1. **pre-reboot-check.sh**: Validates DNS resolution, service status, port listening, TLS connectivity
2. **post-reboot-check.sh**: Confirms persistence of configuration and service auto-start
3. **reboot-test-helper.sh**: Orchestrates full reboot cycle testing

## Critical Workflows

### Installation Flow
```bash
sudo ./secure-dns-setup.sh  # Main setup: check deps → backup configs → write configs → restart services
```

### Testing Workflows
- `--run-tests`: Execute pre-reboot checks (DNS resolution, service verification, TLS connection tests)
- `--test-reboot`: Full reboot survival test (pre-boot snapshot → reboot → post-boot verification)
- `--rollback`: Restore from timestamped backups (format: `filename.bak.YYYYMMDDHHmmss`)

### Configuration Files Modified
- `/etc/stubby/stubby.yml`: Upstream DNS server definitions with TLS port 853
- `/etc/dnsmasq.conf` and `/etc/dnsmasq.d/stubby-forward.conf`: Local caching, DNSSEC, forwarders

## Project Conventions

### Script Patterns
- **Error handling**: `set -euo pipefail` used throughout; use `|| true` for non-critical failures
- **Logging**: Standardized `log()` function with levels (INFO, WARN, ERROR, DEBUG); colored output via ANSI codes
- **Backups**: Auto-timestamped backups before config writes (`filename.bak.TIMESTAMP`); critical for rollback
- **Root requirement**: All operations require sudo; `check_root()` validates early

### DNS Server Configuration
- **Primary**: Cloudflare (1.1.1.1, 1.0.0.1) with DNSSEC support
- **Secondary**: Quad9 (9.9.9.9, 149.112.112.112) as failover
- **Tertiary**: Google (8.8.8.8, 8.8.4.4) as final fallback
- TLS port: Always 853 for DoT connections

### Testing Conventions
- Output uses color codes: ✓ (GREEN) for pass, ✗ (RED) for fail
- JSON report generation to `/var/log/dns-reboot-test-results.json`
- Log files: `/tmp/dns-setup-preboot.log`, `/tmp/dns-setup-postboot.log`
- Critical test domains: example.com, google.com, cloudflare.com

## Dependencies & External Integration

**System Dependencies** (auto-installed): stubby, dnsmasq, dnsutils, systemctl

**Systemd Integration Points**:
- Service files: `stubby.service`, `dnsmasq.service`
- Services must be enabled and started in correct order (Stubby before DNSMasq)
- Status checks use `systemctl is-active` and `systemctl is-enabled`

**Network Validation**:
- Port listening checks via `ss -tuln` (Stubby:5353, DNSMasq:53)
- DNS queries via `dig` and `nslookup`
- TLS connectivity validation to upstream providers

## Common Tasks

**Adding new DNS server**: Modify array definitions (CLOUDFLARE_PRIMARY, QUAD9_SECONDARY, etc.) and regenerate Stubby config in the configuration function

**Debugging DNS issues**: Check service status → verify ports listening → test upstream connectivity with dig → review logs

**Extending tests**: Add new test functions following the pattern in [tests/pre-reboot-check.sh](../tests/pre-reboot-check.sh); integrate into main test orchestration

## Testing Infrastructure Notes

**Critical Fixes Applied**:
- ✅ Path detection now uses dynamic `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` instead of hardcoded `/home/engine/project`
- ✅ JSON report generation fixed: proper comma placement between array elements, DNSSEC validation tests added
- ✅ Test files include both pre-reboot (8 tests) and post-reboot validation (11 tests with persistence checks)

**Test Execution Notes**:
- Pre-reboot generates: `/tmp/dns-setup-preboot.log` (text) + appends to `/var/log/dns-reboot-test-results.json`
- Post-reboot validates against pre-reboot state and checks DNSSEC persistence across reboot
- Test helper functions: `measure_startup_time()` and `compare_with_preboot()` track configuration persistence

**Test Coverage by File**:
- **pre-reboot-check.sh** (8 tests):
  1. Stubby service verification
  2. DNSMasq service verification
  3. Port 53 listening check
  4. Port 5353 listening check
  5. Configuration files verification
  6. DNS resolution test (example.com, google.com, cloudflare.com)
  7. Symlink integrity check
  8. DNSSEC validation check

- **post-reboot-check.sh** (11 tests): All pre-reboot tests plus:
  9. Service startup time measurement
  10. Pre-reboot state comparison
  11. DNSSEC persistence verification

**Common Issues Fixed**:
- Hardcoded `/home/engine/project` paths now resolve relative to script location
- JSON reports now have valid syntax with proper comma placement
- Both pre and post-reboot now test DNSSEC to ensure security features survive restart

## Files to Understand First

1. [README.md](../README.md) - Architecture diagrams, use cases, troubleshooting
2. [bin/secure-dns-setup.sh](../bin/secure-dns-setup.sh) - Core logic: lines 200-300 (Stubby config), 300-400 (DNSMasq config), 940-980 (reboot test handler with dynamic path detection)
3. [tests/pre-reboot-check.sh](../tests/pre-reboot-check.sh) - Test patterns: 8 validation tests, JSON report generation (line 170+)
4. [tests/post-reboot-check.sh](../tests/post-reboot-check.sh) - Extended tests: 11 validations, state comparison functions
5. [TESTING_FIXES.md](../TESTING_FIXES.md) - Complete details on code review findings and fixes applied
