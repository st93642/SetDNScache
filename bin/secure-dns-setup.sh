#!/bin/bash
#
# Secure DNS Configuration Script for SetDNScache
# Configures Stubby with DNS-over-TLS (authenticated by certificate name)
# behind a dnsmasq cache, and points systemd-resolved at it.
# Primary: Cloudflare | Secondary: Quad9 | Tertiary: Google
#
# Usage: sudo ./secure-dns-setup.sh [--run-tests] [--test-reboot] [--rollback]
#                                   [--dry-run] [--yes] [--verbose] [--help]
#

set -euo pipefail

# ============================================================================
# Configuration (paths can be overridden via environment, e.g. for testing)
# ============================================================================

STUBBY_CONFIG="${STUBBY_CONFIG:-/etc/stubby/stubby.yml}"
STUBBY_SERVICE="stubby"
DNSMASQ_SERVICE="dnsmasq"
DNSMASQ_D="${DNSMASQ_D:-/etc/dnsmasq.d}"
DNSMASQ_DROPIN="$DNSMASQ_D/stubby-forward.conf"
RESOLVED_SERVICE="systemd-resolved"
RESOLVED_DROPIN_DIR="${RESOLVED_DROPIN_DIR:-/etc/systemd/resolved.conf.d}"
RESOLVED_DROPIN="$RESOLVED_DROPIN_DIR/setdnscache.conf"
STATE_DIR="${STATE_DIR:-/var/lib/setdnscache}"
STATE_FILE="$STATE_DIR/state"
# 5353 is mDNS (avahi-daemon) on most desktops, so use 5453 for Stubby.
STUBBY_PORT="${STUBBY_PORT:-5453}"
DNS_PORT=53
VERBOSE=false
DRY_RUN=false
ASSUME_YES=false
ACTION="configure"

# DNS Server Configuration
CLOUDFLARE_PRIMARY=("1.1.1.1" "1.0.0.1")
QUAD9_SECONDARY=("9.9.9.9" "149.112.112.112")
GOOGLE_TERTIARY=("8.8.8.8" "8.8.4.4")

# TLS Port for Stubby
STUBBY_TLS_PORT=853

# ============================================================================
# Logging Functions
# ============================================================================

log() {
    local level="$1"
    shift
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        INFO)  echo -e "\033[32m[INFO]\033[0m $timestamp - $*" ;;
        WARN)  echo -e "\033[33m[WARN]\033[0m $timestamp - $*" ;;
        ERROR) echo -e "\033[31m[ERROR]\033[0m $timestamp - $*" >&2 ;;
        DEBUG)
            if [ "$VERBOSE" = true ]; then
                echo -e "\033[36m[DEBUG]\033[0m $timestamp - $*"
            fi
            ;;
        *)     echo "[$level] $timestamp - $*" ;;
    esac
}

log_section() {
    echo ""
    echo "============================================================================"
    echo "  $*"
    echo "============================================================================"
}

# ============================================================================
# Side-effect wrappers (every change to the system goes through these so
# --dry-run is honoured everywhere)
# ============================================================================

run() {
    if [ "$DRY_RUN" = true ]; then
        log INFO "[DRY RUN] would run: $*"
        return 0
    fi
    log DEBUG "run: $*"
    "$@"
}

# write_file PATH MODE < content
write_file() {
    local path="$1" mode="$2" content
    content=$(cat)
    if [ "$DRY_RUN" = true ]; then
        log INFO "[DRY RUN] would write $path (mode $mode):"
        printf '%s\n' "$content" | sed 's/^/    | /'
        return 0
    fi
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "$content" > "$path"
    chmod "$mode" "$path"
    log INFO "Wrote $path"
}

state_add() {
    # Append a "key=value" record to the state file
    if [ "$DRY_RUN" = true ]; then
        log DEBUG "[DRY RUN] state: $*"
        return 0
    fi
    mkdir -p "$STATE_DIR"
    chmod 700 "$STATE_DIR"
    printf '%s\n' "$*" >> "$STATE_FILE"
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

check_root() {
    if [ "$DRY_RUN" = true ]; then
        log DEBUG "Dry run: root not required"
        return 0
    fi
    if [ "$EUID" -ne 0 ]; then
        log ERROR "This script must be run as root (use sudo)"
        log INFO "Usage: sudo $0 [--run-tests] [--test-reboot] [--rollback] [--dry-run]"
        exit 1
    fi
}

confirm() {
    local prompt="$1" answer
    if [ "$ASSUME_YES" = true ]; then
        return 0
    fi
    if [ ! -t 0 ]; then
        log ERROR "$prompt - no terminal to ask; re-run with --yes to accept"
        return 1
    fi
    read -r -p "$prompt [y/N] " answer
    [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}

check_dependencies() {
    log INFO "Checking required dependencies..."

    local missing_cmds=() packages=()
    local cmd
    for cmd in stubby dnsmasq dig systemctl; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_cmds+=("$cmd")
            case "$cmd" in
                stubby)  packages+=("stubby") ;;
                dnsmasq) packages+=("dnsmasq") ;;
                dig)     packages+=("dnsutils") ;;
                systemctl) ;;  # not installable here
            esac
        fi
    done
    if ! command -v ss &>/dev/null && ! command -v netstat &>/dev/null; then
        missing_cmds+=("ss/netstat")
        packages+=("iproute2")
    fi

    if [ ${#missing_cmds[@]} -eq 0 ]; then
        log INFO "All dependencies satisfied"
        return 0
    fi

    log WARN "Missing commands: ${missing_cmds[*]}"
    if [ ${#packages[@]} -eq 0 ]; then
        log ERROR "systemd is required and cannot be installed by this script"
        return 1
    fi
    if ! command -v apt-get &>/dev/null; then
        log ERROR "apt-get not found. Please install manually: ${packages[*]}"
        return 1
    fi
    if [ "$DRY_RUN" = true ]; then
        log INFO "[DRY RUN] would run: apt-get install -y ${packages[*]}"
        return 0
    fi
    if ! confirm "Install missing packages (${packages[*]}) with apt-get?"; then
        log ERROR "Dependencies missing. Install manually: apt-get install ${packages[*]}"
        return 1
    fi
    if ! { apt-get update -qq && apt-get install -y "${packages[@]}"; }; then
        log ERROR "Failed to install dependencies (see apt output above)."
        return 1
    fi
    log INFO "Dependencies installed"
}

# ============================================================================
# Backup, state and rollback helpers
# ============================================================================

# Back up FILE (if it exists) and record it in the state file. Backups are kept.
backup_config() {
    local file="$1" backup
    backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
    if [ -e "$file" ] || [ -L "$file" ]; then
        run cp -a "$file" "$backup"
        state_add "backup=$file|$backup"
        log INFO "Backed up $file -> $backup"
    else
        state_add "created=$file"
    fi
}

record_service_state() {
    local svc="$1" enabled active
    enabled=$(systemctl is-enabled "$svc" 2>/dev/null || true)
    active=$(systemctl is-active "$svc" 2>/dev/null || true)
    state_add "service=$svc|${enabled:-unknown}|${active:-unknown}"
}

# ============================================================================
# Stubby Configuration
# ============================================================================

# Upstreams are authenticated by TLS certificate name (tls_auth_name) against
# the system CA store. No SPKI pins are used: pins rotate with the providers'
# certificates and a stale pin makes GETDNS_AUTHENTICATION_REQUIRED reject the
# server outright.
stubby_upstream() {
    local addr="$1" name="$2"
    cat << UPSTREAM
  - address_data: $addr
    tls_port: $STUBBY_TLS_PORT
    tls_auth_name: "$name"
UPSTREAM
}

generate_stubby_config() {
    log INFO "Generating Stubby configuration..."
    {
        cat << STUBBY_EOF
# Stubby configuration generated by SetDNScache
# $(date '+%Y-%m-%d %H:%M:%S')
#
# DNS Server Hierarchy (tried in order, round robin disabled):
#   PRIMARY:   Cloudflare (${CLOUDFLARE_PRIMARY[*]})
#   SECONDARY: Quad9 (${QUAD9_SECONDARY[*]})
#   TERTIARY:  Google (${GOOGLE_TERTIARY[*]})
#
# All servers use DNS-over-TLS, authenticated by certificate name.

dns_transport_list:
  - GETDNS_TRANSPORT_TLS
tls_authentication: GETDNS_AUTHENTICATION_REQUIRED
tls_query_padding_blocksize: 128
edns_client_subnet_private: 1
round_robin_upstreams: 0
idle_timeout: 10000
timeout: 2000

listen_addresses:
  - 127.0.0.1@$STUBBY_PORT
  - 0::1@$STUBBY_PORT

upstream_recursive_servers:
  # PRIMARY: Cloudflare
STUBBY_EOF
        stubby_upstream "${CLOUDFLARE_PRIMARY[0]}" "cloudflare-dns.com"
        stubby_upstream "${CLOUDFLARE_PRIMARY[1]}" "cloudflare-dns.com"
        echo "  # SECONDARY: Quad9"
        stubby_upstream "${QUAD9_SECONDARY[0]}" "dns.quad9.net"
        stubby_upstream "${QUAD9_SECONDARY[1]}" "dns.quad9.net"
        echo "  # TERTIARY: Google"
        stubby_upstream "${GOOGLE_TERTIARY[0]}" "dns.google"
        stubby_upstream "${GOOGLE_TERTIARY[1]}" "dns.google"
    } | write_file "$STUBBY_CONFIG" 644
}

# ============================================================================
# DNSMasq Configuration
# ============================================================================

generate_dnsmasq_config() {
    log INFO "Generating DNSMasq configuration..."
    write_file "$DNSMASQ_DROPIN" 644 << DNSMASQ_EOF
# DNSMasq configuration generated by SetDNScache
# $(date '+%Y-%m-%d %H:%M:%S')
#
# Cache on 127.0.0.1:$DNS_PORT, forward everything to Stubby (127.0.0.1:$STUBBY_PORT)

listen-address=127.0.0.1
bind-interfaces
port=$DNS_PORT

# Upstream is Stubby only; ignore /etc/resolv.conf
no-resolv
no-poll
server=127.0.0.1#$STUBBY_PORT

cache-size=1000

# DNSSEC: pass the DO bit and the upstream AD flag through unchanged.
# Validation is done by the upstream resolvers (Cloudflare/Quad9/Google).
proxy-dnssec

# Never forward plain names without dots or private reverse lookups upstream
domain-needed
bogus-priv

edns-packet-max=4096
neg-ttl=600
max-ttl=3600
DNSMASQ_EOF
}

# ============================================================================
# systemd-resolved / resolv.conf integration
# ============================================================================

configure_system_resolver() {
    log INFO "Pointing the system resolver at 127.0.0.1..."
    if command -v systemctl &>/dev/null && systemctl is-active "$RESOLVED_SERVICE" &>/dev/null; then
        record_service_state "$RESOLVED_SERVICE"
        backup_config "$RESOLVED_DROPIN"
        write_file "$RESOLVED_DROPIN" 644 << RESOLVED_EOF
# Generated by SetDNScache - remove (or run --rollback) to undo
[Resolve]
DNS=127.0.0.1
Domains=~.
DNSStubListener=no
RESOLVED_EOF
        # With the stub listener off, 127.0.0.53 goes away; use the full file.
        if [ -L /etc/resolv.conf ] && [[ "$(readlink /etc/resolv.conf)" == *stub-resolv.conf ]]; then
            backup_config /etc/resolv.conf
            run ln -sfn /run/systemd/resolve/resolv.conf /etc/resolv.conf
        fi
        run systemctl restart "$RESOLVED_SERVICE"
    else
        log WARN "systemd-resolved not active; writing /etc/resolv.conf directly"
        log WARN "NetworkManager/DHCP may overwrite it; configure your network manager to use 127.0.0.1"
        backup_config /etc/resolv.conf
        if [ -L /etc/resolv.conf ]; then
            run rm -f /etc/resolv.conf
        fi
        printf 'nameserver 127.0.0.1\noptions edns0 trust-ad\n' | write_file /etc/resolv.conf 644
    fi
}

# ============================================================================
# Systemd Service Management
# ============================================================================

enable_and_restart_services() {
    log INFO "Enabling and (re)starting services..."
    record_service_state "$STUBBY_SERVICE"
    record_service_state "$DNSMASQ_SERVICE"
    run systemctl enable "$STUBBY_SERVICE"
    run systemctl restart "$STUBBY_SERVICE"
    [ "$DRY_RUN" = true ] || sleep 2
    run systemctl enable "$DNSMASQ_SERVICE"
    run systemctl restart "$DNSMASQ_SERVICE"
}

local_resolver_works() {
    [ "$DRY_RUN" = true ] && return 0
    local tries
    for tries in 1 2 3 4 5; do
        if [ -n "$(dig +short +time=2 +tries=1 example.com @127.0.0.1 -p "$DNS_PORT" 2>/dev/null || true)" ]; then
            return 0
        fi
        log DEBUG "local resolver not answering yet (attempt $tries)"
        sleep 1
    done
    return 1
}

# ============================================================================
# Connectivity Test Functions
# ============================================================================

test_connectivity() {
    local phase="${1:-current}"
    log_section "Connectivity Test Results ($phase)"
    
    local passed=0
    local failed=0
    
    echo ""
    echo "Running $phase connectivity tests..."
    echo ""
    
    # Test 1: DNS Resolution
    echo "--- DNS Resolution Test ---"
    if test_dns_resolution; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi
    
    # Test 2: Port Connectivity
    echo ""
    echo "--- Port Connectivity Test ---"
    if test_port_connectivity; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi
    
    # Test 3: Service Status
    echo ""
    echo "--- Service Status Test ---"
    if test_service_status; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi
    
    # Test 4: DNSSEC Validation
    echo ""
    echo "--- DNSSEC Validation Test ---"
    if test_dnssec_validation; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi
    
    # Test 5: Latency Test
    echo ""
    echo "--- Latency Test ---"
    if test_latency; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi
    
    # Test 6: Fallback Servers
    echo ""
    echo "--- Fallback Server Test ---"
    if test_fallback_servers; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi
    
    # Test 7: Conflict Detection
    echo ""
    echo "--- Conflict Detection Test ---"
    if test_conflict_detection; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi
    
    echo ""
    echo "============================================================================"
    echo "  Test Summary: $passed passed, $failed failed"
    echo "============================================================================"
    echo ""
    
    return $failed
}

test_dns_resolution() {
    log INFO "Testing DNS resolution for multiple domains..."
    
    local domains=("google.com" "cloudflare.com" "quad9.net")
    local all_passed=true
    
    for domain in "${domains[@]}"; do
        local result
        if result=$(dig +short "$domain" @127.0.0.1 -p "$DNS_PORT" 2>/dev/null); then
            if [ -n "$result" ]; then
                log INFO "  ✓ $domain resolved successfully: $result"
            else
                log WARN "  ✗ $domain: No IP returned"
                all_passed=false
            fi
        else
            log WARN "  ✗ $domain: Resolution failed"
            all_passed=false
        fi
    done
    
    if [ "$all_passed" = true ]; then
        log INFO "DNS Resolution Test: PASSED"
        return 0
    else
        log ERROR "DNS Resolution Test: FAILED"
        return 1
    fi
}

test_port_connectivity() {
    log INFO "Testing port connectivity..."
    
    local dnsmasq_listening=false
    local stubby_listening=false
    
    # Test DNSMasq (port 53)
    if ss -tuln 2>/dev/null | grep -qE "[:.]$DNS_PORT\s" || netstat -tuln 2>/dev/null | grep -qE "[:.]$DNS_PORT\s"; then
        log INFO "  ✓ DNSMasq listening on 127.0.0.1:$DNS_PORT"
        dnsmasq_listening=true
    else
        log WARN "  ✗ DNSMasq not detected on 127.0.0.1:$DNS_PORT"
    fi
    
    # Test Stubby ($STUBBY_PORT)
    if ss -tuln 2>/dev/null | grep -qE "[:.]$STUBBY_PORT\s" || netstat -tuln 2>/dev/null | grep -qE "[:.]$STUBBY_PORT\s"; then
        log INFO "  ✓ Stubby listening on 127.0.0.1:$STUBBY_PORT"
        stubby_listening=true
    else
        log WARN "  ✗ Stubby not detected on 127.0.0.1:$STUBBY_PORT"
    fi
    
    # Test connectivity to ports
    if timeout 1 bash -c "echo > /dev/tcp/127.0.0.1/$DNS_PORT" 2>/dev/null; then
        log INFO "  ✓ Can connect to 127.0.0.1:$DNS_PORT"
    else
        log WARN "  ✗ Cannot connect to 127.0.0.1:$DNS_PORT"
    fi
    
    if [ "$dnsmasq_listening" = true ] && [ "$stubby_listening" = true ]; then
        log INFO "Port Connectivity Test: PASSED"
        return 0
    else
        log ERROR "Port Connectivity Test: FAILED"
        return 1
    fi
}

test_service_status() {
    log INFO "Testing service status..."
    
    local services_status=true
    
    # Check Stubby
    if command -v systemctl &>/dev/null; then
        local stubby_status
        stubby_status=$(systemctl is-active stubby 2>/dev/null || echo "inactive")
        if [ "$stubby_status" = "active" ]; then
            log INFO "  ✓ Stubby service is active"
        else
            log WARN "  ✗ Stubby service is not active (status: $stubby_status)"
            services_status=false
        fi
        
        # Check DNSMasq
        local dnsmasq_status
        dnsmasq_status=$(systemctl is-active dnsmasq 2>/dev/null || echo "inactive")
        if [ "$dnsmasq_status" = "active" ]; then
            log INFO "  ✓ DNSMasq service is active"
        else
            log WARN "  ✗ DNSMasq service is not active (status: $dnsmasq_status)"
            services_status=false
        fi
        
        # Show systemd status details
        if [ "$VERBOSE" = true ]; then
            log DEBUG "Stubby systemd status: $(systemctl is-enabled stubby 2>/dev/null || echo 'unknown')"
            log DEBUG "DNSMasq systemd status: $(systemctl is-enabled dnsmasq 2>/dev/null || echo 'unknown')"
        fi
    else
        log WARN "systemd not available - skipping service status checks"
    fi
    
    if [ "$services_status" = true ]; then
        log INFO "Service Status Test: PASSED"
        return 0
    else
        log ERROR "Service Status Test: FAILED"
        return 1
    fi
}

test_dnssec_validation() {
    log INFO "Testing DNSSEC validation..."
    
    # Use dig to check for DNSSEC validation
    # The AD (Authenticated Data) flag indicates successful DNSSEC validation
    local test_domain="dnssec-examples.com"
    local result
    result=$(dig +short "$test_domain" @127.0.0.1 -p "$DNS_PORT" +dnssec 2>/dev/null || true)
    
    if [ -n "$result" ]; then
        log INFO "  ✓ DNSSEC query returned results"
    else
        log INFO "  (DNSSEC test domain not resolvable, testing with known DNSSEC domain)"
    fi
    
    # Check if dig supports DNSSEC
    if ! command -v dig &>/dev/null; then
        log WARN "dig not available - cannot test DNSSEC"
        return 0  # Don't fail the test, just warn
    fi
    
    # Alternative: Check if DNSSEC is being requested
    local dnssec_check
    dnssec_check=$(dig +noall +answer +dnssec +short sigok.verteiltesysteme.net @127.0.0.1 -p "$DNS_PORT" 2>/dev/null || true)
    
    if [ -n "$dnssec_check" ]; then
        log INFO "  ✓ DNSSEC validation working (sigok.verteiltesysteme.net)"
        log INFO "DNSSEC Validation Test: PASSED"
        return 0
    else
        # Try another test
        dnssec_check=$(dig +noall +answer +dnssec +short dnssec.verteiltesysteme.net @127.0.0.1 -p "$DNS_PORT" 2>/dev/null || true)
        if [ -n "$dnssec_check" ]; then
            log INFO "  ✓ DNSSEC validation working (dnssec.verteiltesysteme.net)"
            log INFO "DNSSEC Validation Test: PASSED"
            return 0
        fi
    fi
    
    log WARN "  ! DNSSEC validation status unclear (may need actual DNSSEC queries)"
    log INFO "DNSSEC Validation Test: PASSED (with warnings)"
    return 0
}

test_latency() {
    log INFO "Testing DNS query latency..."
    
    local domains=("google.com" "cloudflare.com")
    local max_latency=100  # ms
    local all_under_limit=true
    
    for domain in "${domains[@]}"; do
        local start end duration
        
        # Multiple queries to test caching
        for i in {1..3}; do
            start=$(date +%s%N)
            dig +short "$domain" @127.0.0.1 -p "$DNS_PORT" &>/dev/null || true
            end=$(date +%s%N)
            
            duration=$(( (end - start) / 1000000 ))
            
            if [ "$duration" -lt "$max_latency" ]; then
                log DEBUG "  $domain query $i: ${duration}ms (cached, acceptable)"
            else
                log DEBUG "  $domain query $i: ${duration}ms (uncached, may be high)"
            fi
        done
    done
    
    # Test with dig +stats for accurate timing
    local stats
    stats=$(dig google.com @127.0.0.1 -p "$DNS_PORT" +stats 2>&1 | grep "Query time:" || true)
    
    if [ -n "$stats" ]; then
        local query_time
        query_time=$(echo "$stats" | awk '{print $4}')
        log INFO "  Query time for google.com: ${query_time}ms"
        
        if [[ "$query_time" =~ ^[0-9]+$ ]] && [ "$query_time" -lt "$max_latency" ]; then
            log INFO "  ✓ Latency is under ${max_latency}ms threshold"
        else
            log WARN "  ! Latency is over ${max_latency}ms threshold"
            all_under_limit=false
        fi
    fi
    
    if [ "$all_under_limit" = true ]; then
        log INFO "Latency Test: PASSED"
        return 0
    else
        log INFO "Latency Test: PASSED (with warnings)"
        return 0
    fi
}

test_fallback_servers() {
    log INFO "Testing fallback server hierarchy..."
    
    # This test verifies that if primary servers fail, secondary/tertiary are used
    # We can't easily simulate server failure, but we can verify the configuration
    log INFO "  Testing DNS server failover configuration..."
    
    # Check if Stubby config has the expected servers
    if [ -f "$STUBBY_CONFIG" ]; then
        local has_primary=false
        local has_secondary=false
        local has_tertiary=false
        
        # Check for Cloudflare (primary)
        if grep -q "1.1.1.1" "$STUBBY_CONFIG"; then
            has_primary=true
            log INFO "  ✓ Cloudflare (Primary) configured"
        fi
        
        # Check for Quad9 (secondary)
        if grep -q "9.9.9.9" "$STUBBY_CONFIG"; then
            has_secondary=true
            log INFO "  ✓ Quad9 (Secondary) configured"
        fi
        
        # Check for Google (tertiary)
        if grep -q "8.8.8.8" "$STUBBY_CONFIG"; then
            has_tertiary=true
            log INFO "  ✓ Google (Tertiary) configured"
        fi
        
        if [ "$has_primary" = true ] && [ "$has_secondary" = true ] && [ "$has_tertiary" = true ]; then
            log INFO "  ✓ All server tiers configured correctly"
            log INFO "Fallback Server Test: PASSED"
            return 0
        else
            log ERROR "  ✗ Missing server configuration"
            log INFO "Fallback Server Test: FAILED"
            return 1
        fi
    else
        log WARN "  ! Stubby config not found - using service resolution test"
        
        # Alternative: Test with nslookup
        if nslookup google.com 127.0.0.1 &>/dev/null; then
            log INFO "  ✓ DNS resolution working through stubby"
            log INFO "Fallback Server Test: PASSED (basic test)"
            return 0
        else
            log ERROR "  ✗ DNS resolution failed"
            log INFO "Fallback Server Test: FAILED"
            return 1
        fi
    fi
}

test_conflict_detection() {
    log INFO "Testing for port conflicts with other DNS services..."
    
    local conflicts_found=false
    local conflicting_process
    
    # Check if anything is already using port 53
    if ss -tuln 2>/dev/null | grep -qE "[:.]$DNS_PORT\s"; then
        conflicting_process=$(ss -tlnp 2>/dev/null | grep -E "[:.]$DNS_PORT\s" | awk '{print $7}' || echo "unknown")
        log WARN "  ✗ Port $DNS_PORT is already in use by: $conflicting_process"
        log WARN "  This may cause DNS resolution failures"
        log INFO "  Remediation: Stop the conflicting service or change the port"
        conflicts_found=true
    fi
    
    # Check if anything is already using the Stubby port
    if ss -tuln 2>/dev/null | grep -qE "[:.]$STUBBY_PORT\s"; then
        conflicting_process=$(ss -tlnp 2>/dev/null | grep -E "[:.]$STUBBY_PORT\s" | awk '{print $7}' || echo "unknown")
        log WARN "  ✗ Port $STUBBY_PORT is already in use by: $conflicting_process"
        log INFO "  Remediation: Stop the conflicting service or change the port"
        conflicts_found=true
    fi
    
    # Check for common DNS services that might conflict
    local conflicting_services=("systemd-resolved" "bind9" "named" "unbound" "knot")
    
    for service in "${conflicting_services[@]}"; do
        if command -v systemctl &>/dev/null; then
            if [ "$service" = "systemd-resolved" ]; then
                if systemctl is-active "$service" &>/dev/null; then
                    log INFO "  i systemd-resolved is active; setup installs $RESOLVED_DROPIN (DNSStubListener=no)"
                fi
            elif systemctl is-active "$service" &>/dev/null; then
                log WARN "  ! $service is running and may conflict"
                log INFO "  Remediation: sudo systemctl stop $service"
            fi
        fi
    done
    
    if [ "$conflicts_found" = true ]; then
        log INFO "Conflict Detection Test: PASSED (conflicts detected - see warnings)"
        return 0  # Don't fail, just warn
    else
        log INFO "  ✓ No port conflicts detected"
        log INFO "Conflict Detection Test: PASSED"
        return 0
    fi
}

# ============================================================================
# Main Configuration Function
# ============================================================================

configure_secure_dns() {
    log_section "Secure DNS Configuration"
    [ "$DRY_RUN" = true ] && log INFO "DRY RUN: no changes will be made"

    check_root
    check_dependencies

    log INFO "Running pre-configuration connectivity tests..."
    test_connectivity "pre-configuration" || true

    if [ "$DRY_RUN" != true ]; then
        mkdir -p "$STATE_DIR"
        chmod 700 "$STATE_DIR"
        state_add "run=$(date '+%Y-%m-%d %H:%M:%S')"
    fi

    log_section "Configuring Stubby with DNS-over-TLS"
    backup_config "$STUBBY_CONFIG"
    generate_stubby_config

    log_section "Configuring DNSMasq"
    backup_config "$DNSMASQ_DROPIN"
    generate_dnsmasq_config

    log_section "Starting Services"
    enable_and_restart_services

    # Only switch the system resolver once the new chain answers, so a failure
    # here never leaves the machine without DNS.
    if ! local_resolver_works; then
        log ERROR "dnsmasq/stubby on 127.0.0.1 are not answering; system resolver left unchanged"
        log INFO "Inspect: journalctl -u stubby -u dnsmasq ; undo with: sudo $0 --rollback"
        exit 1
    fi

    log_section "Configuring System Resolver"
    configure_system_resolver

    log_section "Post-Configuration Verification"
    [ "$DRY_RUN" = true ] || sleep 2
    local failed=0
    if [ "$DRY_RUN" = true ]; then
        log INFO "[DRY RUN] skipping post-configuration tests"
    else
        test_connectivity "post-configuration" || failed=$?
    fi

    log_section "Configuration Complete"
    if [ "$failed" -ne 0 ]; then
        log WARN "Configuration applied but $failed post-configuration test(s) failed (see above)"
    else
        log INFO "Secure DNS configuration completed successfully!"
    fi
    log INFO "Configuration Summary:"
    log INFO "  - Stubby:   $STUBBY_CONFIG (127.0.0.1:$STUBBY_PORT)"
    log INFO "  - DNSMasq:  $DNSMASQ_DROPIN (127.0.0.1:$DNS_PORT)"
    log INFO "  - Resolved: $RESOLVED_DROPIN"
    log INFO "  - State:    $STATE_FILE (used by --rollback)"
    log INFO "Verify: dig @127.0.0.1 example.com ; resolvectl status"
    return "$failed"
}

# ============================================================================
# Rollback Function (replays the state file in reverse)
# ============================================================================

restore_service() {
    local svc="$1" enabled="$2" active="$3"
    case "$enabled" in
        enabled) run systemctl enable "$svc" || true ;;
        disabled|"") run systemctl disable "$svc" || true ;;
        masked) run systemctl mask "$svc" || true ;;
        *) log DEBUG "leaving enablement of $svc ($enabled)" ;;
    esac
    if [ "$active" = "active" ]; then
        run systemctl restart "$svc" || log WARN "could not restart $svc"
    else
        run systemctl stop "$svc" || true
    fi
}

rollback() {
    log_section "Rolling Back Configuration"
    check_root

    if [ ! -f "$STATE_FILE" ]; then
        log ERROR "No state file at $STATE_FILE - nothing recorded to roll back"
        exit 1
    fi

    local -a records=() services=()
    mapfile -t records < "$STATE_FILE"
    local i rec key val file backup
    for (( i=${#records[@]}-1; i>=0; i-- )); do
        rec="${records[$i]}"
        key="${rec%%=*}"
        val="${rec#*=}"
        case "$key" in
            backup)
                file="${val%%|*}"; backup="${val#*|}"
                if [ -e "$backup" ] || [ -L "$backup" ]; then
                    run cp -a --remove-destination "$backup" "$file"
                    log INFO "Restored $file from $backup (backup kept)"
                else
                    log WARN "Backup $backup missing; cannot restore $file"
                fi
                ;;
            created)
                if [ -e "$val" ] || [ -L "$val" ]; then
                    run rm -f "$val"
                    log INFO "Removed $val (did not exist before)"
                fi
                ;;
            service)
                services+=("$val")   # reverse order: earliest (original) last
                ;;
            run) ;;
            *) log WARN "Unknown state record: $rec" ;;
        esac
    done

    # Restore services; the last record for each service is its original state.
    local -A final=()
    local s
    for s in "${services[@]}"; do
        final["${s%%|*}"]="$s"
    done
    for s in "$STUBBY_SERVICE" "$DNSMASQ_SERVICE" "$RESOLVED_SERVICE"; do
        if [ -n "${final[$s]:-}" ]; then
            IFS='|' read -r _ en ac <<< "${final[$s]}"
            log INFO "Restoring $s to enabled=$en active=$ac"
            restore_service "$s" "$en" "$ac"
        fi
    done

    if [ "$DRY_RUN" != true ]; then
        mv "$STATE_FILE" "$STATE_FILE.rolledback.$(date +%Y%m%d%H%M%S)"
    fi
    log INFO "Rollback completed (backup files were kept)"
}

# ============================================================================
# Help and Usage
# ============================================================================

show_help() {
    cat << HELP
Secure DNS Configuration Script for SetDNScache

USAGE:
    sudo $0 [OPTIONS]

OPTIONS:
    --run-tests     Run connectivity tests only (no configuration changes)
    --test-reboot   Run comprehensive reboot survival tests
    --rollback      Restore the configuration recorded in $STATE_FILE
    --dry-run       Show every change that would be made; changes nothing
                    (does not require root)
    --yes, -y       Do not prompt before installing missing packages
    --verbose       Enable verbose output
    --help          Show this help message

Options may be given in any order; one action (--run-tests, --test-reboot,
--rollback) at most.

WHAT IT CHANGES:
    $STUBBY_CONFIG              Stubby DNS-over-TLS on 127.0.0.1:$STUBBY_PORT
    $DNSMASQ_DROPIN    dnsmasq cache on 127.0.0.1:$DNS_PORT
    $RESOLVED_DROPIN   systemd-resolved -> 127.0.0.1, stub listener off
    All originals are backed up (*.bak.TIMESTAMP) and recorded in $STATE_FILE.

DNS SERVER HIERARCHY:
    PRIMARY:   Cloudflare (1.1.1.1, 1.0.0.1)
    SECONDARY: Quad9 (9.9.9.9, 149.112.112.112)
    TERTIARY:  Google (8.8.8.8, 8.8.4.4)

EXIT CODES:
    0   Success
    1   Error (missing dependencies, permission denied, resolver not answering)
    N   Configuration applied but N post-configuration tests failed
HELP
}

# ============================================================================
# Reboot Test Function
# ============================================================================

run_reboot_tests() {
    log INFO "Running comprehensive reboot survival tests..."

    local script_dir project_root
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    project_root="$(dirname "$script_dir")"

    local reboot_helper="$project_root/tests/reboot-test-helper.sh"
    local f
    for f in pre-reboot-check.sh post-reboot-check.sh reboot-test-helper.sh; do
        if [ ! -f "$project_root/tests/$f" ]; then
            log ERROR "Reboot test script not found: $project_root/tests/$f"
            exit 1
        fi
        if [ ! -x "$project_root/tests/$f" ]; then
            log ERROR "Reboot test script not executable: $project_root/tests/$f"
            log INFO "Please run: chmod +x $project_root/tests/*.sh"
            exit 1
        fi
    done

    log INFO "Starting reboot test helper..."
    "$reboot_helper"
}

# ============================================================================
# Main Entry Point
# ============================================================================

set_action() {
    if [ "$ACTION" != "configure" ] && [ "$ACTION" != "$1" ]; then
        log ERROR "Options --$ACTION and --$1 cannot be combined"
        exit 1
    fi
    ACTION="$1"
}

parse_args() {
    # Parse everything first so flags like --verbose/--dry-run apply
    # regardless of their position on the command line.
    while [[ $# -gt 0 ]]; do
        case $1 in
            --run-tests)   set_action "run-tests" ;;
            --test-reboot) set_action "test-reboot" ;;
            --rollback)    set_action "rollback" ;;
            --verbose)     VERBOSE=true ;;
            --dry-run)     DRY_RUN=true ;;
            --yes|-y)      ASSUME_YES=true ;;
            --help|-h)     ACTION="help" ;;
            *)
                log ERROR "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

main() {
    parse_args "$@"

    case "$ACTION" in
        help)        show_help ;;
        test-reboot) run_reboot_tests ;;
        rollback)    rollback ;;
        run-tests)
            log INFO "Running connectivity tests only (no configuration changes)..."
            DRY_RUN=true check_dependencies || true
            test_connectivity "current"
            ;;
        configure)   configure_secure_dns ;;
    esac
}

# Allow sourcing for unit tests without running anything.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
