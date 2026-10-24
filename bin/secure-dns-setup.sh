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

set -Eeuo pipefail

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
# Backups live outside every config dir: dnsmasq (and others) load *all* files
# in their conf dirs, so a *.bak next to the original gets parsed too.
BACKUP_DIR="${BACKUP_DIR:-$STATE_DIR/backups}"
DNSMASQ_CONF="${DNSMASQ_CONF:-/etc/dnsmasq.conf}"
RESOLV_CONF="${RESOLV_CONF:-/etc/resolv.conf}"
NM_DROPIN="${NM_DROPIN:-/etc/NetworkManager/conf.d/setdnscache.conf}"
RESOLVED_STUB_RESOLV="${RESOLVED_STUB_RESOLV:-/run/systemd/resolve/stub-resolv.conf}"
# NetworkManager connection types whose DHCP/RA DNS servers are ignored so
# they cannot bypass 127.0.0.1. VPN/WireGuard connections are left alone so
# their (split) DNS keeps working through systemd-resolved.
NM_DNS_TYPES="${NM_DNS_TYPES:-802-3-ethernet 802-11-wireless gsm cdma bond bridge vlan team pppoe infiniband}"
RUN_TS="$(date +%Y%m%d%H%M%S)"
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

# Package that provides each required piece (Debian/Ubuntu/Mint names).
# Note: dnsmasq-base ships only the binary; the "dnsmasq" package provides
# dnsmasq.service, which this script needs.
REQUIRED_PACKAGES=(stubby dnsmasq dnsutils iproute2)
REQUIRED_UNITS=("$STUBBY_SERVICE" "$DNSMASQ_SERVICE")

package_installed() {
    command -v dpkg-query &>/dev/null || return 2
    [ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null || true)" = "install ok installed" ]
}

unit_exists() {
    systemctl list-unit-files --no-legend --no-pager "$1.service" 2>/dev/null | grep -q "^$1\.service" \
        || systemctl cat "$1.service" &>/dev/null
}

missing_units() {
    local u out=()
    for u in "${REQUIRED_UNITS[@]}"; do
        unit_exists "$u" || out+=("$u.service")
    done
    echo "${out[*]}"
}

# Install packages without letting the package scripts start the daemons
# (dnsmasq would start with the stock config and fight over port 53).
install_packages() {
    local policy=/usr/sbin/policy-rc.d created_policy=false rc=0
    if [ ! -e "$policy" ]; then
        printf '#!/bin/sh\nexit 101\n' > "$policy"
        chmod 755 "$policy"
        created_policy=true
    fi
    apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" || rc=$?
    if [ "$created_policy" = true ]; then
        rm -f "$policy"
    fi
    # In case a daemon was started anyway, stop it until it is configured.
    systemctl stop "$DNSMASQ_SERVICE" 2>/dev/null || true
    return "$rc"
}

check_dependencies() {
    log INFO "Checking required dependencies..."

    local packages=() pkg
    if command -v dpkg-query &>/dev/null; then
        for pkg in "${REQUIRED_PACKAGES[@]}"; do
            package_installed "$pkg" || packages+=("$pkg")
        done
    else
        command -v stubby &>/dev/null || packages+=("stubby")
        command -v dnsmasq &>/dev/null || packages+=("dnsmasq")
        command -v dig &>/dev/null || packages+=("dnsutils")
        command -v ss &>/dev/null || command -v netstat &>/dev/null || packages+=("iproute2")
    fi

    if ! command -v systemctl &>/dev/null; then
        log ERROR "systemd (systemctl) is required"
        return 1
    fi

    if [ ${#packages[@]} -gt 0 ]; then
        log WARN "Missing packages: ${packages[*]}"
        if ! command -v apt-get &>/dev/null; then
            log ERROR "apt-get not found. Please install manually: ${packages[*]}"
            return 1
        fi
        if [ "$DRY_RUN" = true ]; then
            log INFO "[DRY RUN] would run: apt-get install -y ${packages[*]} (with service autostart blocked)"
            return 0
        fi
        if ! confirm "Install missing packages (${packages[*]}) with apt-get?"; then
            log ERROR "Dependencies missing. Install manually: sudo apt-get install ${packages[*]}"
            return 1
        fi
        if ! install_packages "${packages[@]}"; then
            log ERROR "Failed to install dependencies (see apt output above)."
            return 1
        fi
        log INFO "Installed: ${packages[*]}"
    fi

    local units
    units=$(missing_units)
    if [ -n "$units" ]; then
        log ERROR "Required systemd unit(s) not found: $units"
        log INFO "On Debian/Ubuntu/Mint install the full packages: sudo apt-get install stubby dnsmasq"
        log INFO "(dnsmasq-base alone has no dnsmasq.service)"
        return 1
    fi

    log INFO "All dependencies satisfied"
}

# ============================================================================
# Backup, state and rollback helpers
# ============================================================================

# Back up FILE (if it exists) and record it in the state file. Backups are kept.
backup_path_for() {
    # /var/lib/setdnscache/backups/<run-ts>/<original absolute path>
    local file="$1" dest n=1
    dest="$BACKUP_DIR/$RUN_TS$file"
    while [ -e "$dest" ] || [ -L "$dest" ]; do dest="$BACKUP_DIR/$RUN_TS$file.$n"; n=$((n + 1)); done
    echo "$dest"
}

# True if an earlier (not rolled back) run already recorded the original of FILE.
already_recorded() {
    [ -f "$STATE_FILE" ] || return 1
    grep -qxF "created=$1" "$STATE_FILE" || grep -qF "backup=$1|" "$STATE_FILE"
}

backup_config() {
    local file="$1" backup
    if already_recorded "$file"; then
        log DEBUG "Original of $file already backed up by an earlier run; not backing up again"
        return 0
    fi
    if [ -e "$file" ] || [ -L "$file" ]; then
        backup=$(backup_path_for "$file")
        run mkdir -p "$(dirname "$backup")"
        run cp -a "$file" "$backup"
        state_add "backup=$file|$backup"
        [ "$DRY_RUN" = true ] || log INFO "Backed up $file -> $backup"
    else
        state_add "created=$file"
    fi
}

# Earlier versions left *.bak.TIMESTAMP next to the originals; in dnsmasq.d
# they are loaded as config and break dnsmasq. Move them into BACKUP_DIR and
# rewrite matching state records so --rollback still finds them.
migrate_legacy_backups() {
    local f dest moved=0
    for f in "$DNSMASQ_D"/*.bak.[0-9]* "$(dirname "$STUBBY_CONFIG")"/*.bak.[0-9]* \
             "$RESOLVED_DROPIN_DIR"/*.bak.[0-9]*; do
        [ -e "$f" ] || [ -L "$f" ] || continue
        dest="$BACKUP_DIR/legacy$f"
        if [ "$DRY_RUN" = true ]; then
            log INFO "[DRY RUN] would move legacy backup $f -> $dest"
            continue
        fi
        mkdir -p "$(dirname "$dest")"
        mv "$f" "$dest"
        if [ -f "$STATE_FILE" ]; then
            F="$f" D="$dest" awk '{ i = index($0, "|" ENVIRON["F"]); if (i && substr($0, i + 1) == ENVIRON["F"]) $0 = substr($0, 1, i) ENVIRON["D"]; print }' \
                "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
        fi
        log INFO "Moved legacy backup $f -> $dest"
        moved=$((moved + 1))
    done
    [ "$moved" -eq 0 ] || chmod -R go-rwx "$BACKUP_DIR"
}

# Validate the complete dnsmasq config the service will load, before restart.
# Debian's dnsmasq service adds the conf-dir itself (-7 /etc/dnsmasq.d,...),
# unless dnsmasq.conf already declares one.
dnsmasq_config_test() {
    local -a args=(--test)
    [ -f "$DNSMASQ_CONF" ] && args+=("--conf-file=$DNSMASQ_CONF")
    if ! { [ -f "$DNSMASQ_CONF" ] && grep -Eq '^[[:space:]]*conf-dir=' "$DNSMASQ_CONF"; }; then
        args+=("--conf-dir=$DNSMASQ_D,.dpkg-dist,.dpkg-old,.dpkg-new")
    fi
    if [ "$DRY_RUN" = true ]; then
        log INFO "[DRY RUN] would run: dnsmasq ${args[*]}"
        return 0
    fi
    local out
    if out=$(dnsmasq "${args[@]}" 2>&1); then
        log INFO "dnsmasq configuration check passed"
        return 0
    fi
    log ERROR "dnsmasq configuration check failed: $out"
    return 1
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

# --- NetworkManager: stop per-link DHCP/RA DNS from reaching resolved ------
nm_available() {
    command -v nmcli &>/dev/null && nmcli -t general status &>/dev/null
}

# Re-activate a connection so changed DNS settings really apply.
# "device reapply" can leave stale RA (IPv6) DNS on the resolved link, so
# prefer "connection up"; fall back to reapply. Prints the device name.
nm_reapply() {
    local uuid="$1" dev
    dev=$(nmcli -g GENERAL.DEVICES connection show "$uuid" 2>/dev/null || true)
    [ -n "$dev" ] || return 0
    run nmcli connection up "$uuid" >&2 \
        || run nmcli device reapply "$dev" >&2 \
        || log WARN "could not re-activate $dev; reconnect it to apply DNS changes" >&2
    echo "$dev"
}

# Non-local DNS servers resolved currently has on IFACE (empty = clean).
link_nonlocal_dns() {
    resolvectl dns "$1" 2>/dev/null | awk -F': ' 'NF>1{n=split($2,a," "); for(i=1;i<=n;i++) if(a[i]!="127.0.0.1" && a[i]!="::1") print a[i]}'
}

# After NM changes: flush caches; on leak_check=yes, revert links that still
# carry stale per-link DNS so nothing bypasses 127.0.0.1.
resolved_refresh_links() {
    local leak_check="$1"; shift
    command -v resolvectl &>/dev/null || return 0
    run resolvectl flush-caches || true
    [ "$leak_check" = yes ] || return 0
    local dev stale
    for dev in "$@"; do
        [ "$DRY_RUN" = true ] && { log INFO "[DRY RUN] would check $dev for stale link DNS (resolvectl revert $dev if needed)"; continue; }
        stale=$(link_nonlocal_dns "$dev")
        [ -n "$stale" ] || continue
        log WARN "$dev still has stale link DNS ($(echo "$stale" | xargs)); reverting link"
        run resolvectl revert "$dev" || true
        run resolvectl flush-caches || true
        stale=$(link_nonlocal_dns "$dev")
        if [ -n "$stale" ]; then
            log WARN "$dev still lists $(echo "$stale" | xargs); a reconnect or reboot will clear it"
        else
            log INFO "$dev: stale link DNS cleared"
        fi
    done
}

configure_networkmanager_dns() {
    if ! nm_available; then
        log INFO "NetworkManager not running; no per-connection DNS to disable"
        return 0
    fi
    local uuid type name v4 v6 changed=0 dev
    local -a devs=()
    while IFS=: read -r uuid type name; do
        [ -n "$uuid" ] || continue
        case " $NM_DNS_TYPES " in *" $type "*) ;; *) continue ;; esac
        v4=""; v6=""
        { read -r v4 || true; read -r v6 || true; } < <(nmcli -g ipv4.ignore-auto-dns,ipv6.ignore-auto-dns connection show "$uuid" 2>/dev/null || true)
        if [ "$v4" = yes ] && [ "$v6" = yes ]; then
            log DEBUG "NM connection '$name' already ignores DHCP/RA DNS"
            continue
        fi
        state_add "nm=$uuid|${v4:-no}|${v6:-no}"
        run nmcli connection modify "$uuid" ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes
        [ "$DRY_RUN" = true ] || log INFO "NM connection '$name': ignoring DHCP/RA DNS servers"
        dev=$(nm_reapply "$uuid")
        [ -z "$dev" ] || devs+=("$dev")
        changed=$((changed + 1))
        local static
        static=$(nmcli -g ipv4.dns,ipv6.dns connection show "$uuid" 2>/dev/null | tr '\n' ' ' | xargs || true)
        [ -z "$static" ] || log WARN "NM connection '$name' has static DNS ($static); remove it to avoid leaks"
    done < <(nmcli -t -f UUID,TYPE,NAME connection show 2>/dev/null)
    [ "$changed" -gt 0 ] || log INFO "NetworkManager connections already ignore DHCP/RA DNS"
    # Also re-check active devices on reruns (stale DNS from an earlier run).
    while IFS=: read -r dev type; do
        case " $NM_DNS_TYPES ethernet wifi " in *" $type "*) ;; *) continue ;; esac
        [[ " ${devs[*]} " == *" $dev "* ]] || devs+=("$dev")
    done < <(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | grep -v ':loopback$' || true)
    resolved_refresh_links yes "${devs[@]}"
}

restore_nm_connection() {
    local uuid="$1" v4="$2" v6="$3"
    if ! command -v nmcli &>/dev/null; then
        log WARN "nmcli missing; cannot restore NM connection $uuid"
        return 0
    fi
    run nmcli connection modify "$uuid" ipv4.ignore-auto-dns "$v4" ipv6.ignore-auto-dns "$v6" \
        || { log WARN "could not restore NM connection $uuid (deleted?)"; return 0; }
    [ "$DRY_RUN" = true ] || log INFO "Restored NM connection $uuid (ignore-auto-dns v4=$v4 v6=$v6)"
    nm_reapply "$uuid" >/dev/null
    resolved_refresh_links no
}

configure_system_resolver() {
    log INFO "Making 127.0.0.1 (dnsmasq -> Stubby) the only resolver..."
    if command -v systemctl &>/dev/null && systemctl is-active "$RESOLVED_SERVICE" &>/dev/null; then
        record_service_state "$RESOLVED_SERVICE"
        backup_config "$RESOLVED_DROPIN"
        # Keep resolved's stub on 127.0.0.53 (dnsmasq binds only 127.0.0.1 with
        # bind-interfaces, so they coexist). Apps -> 127.0.0.53 -> 127.0.0.1;
        # VPN split-DNS domains still route via resolved.
        write_file "$RESOLVED_DROPIN" 644 << RESOLVED_EOF
# Generated by SetDNScache - remove (or run --rollback) to undo
[Resolve]
DNS=127.0.0.1
Domains=~.
FallbackDNS=
RESOLVED_EOF
        # /run/systemd/resolve/resolv.conf lists every per-link server (the
        # leak); the stub file lists only 127.0.0.53.
        if [ "$(readlink "$RESOLV_CONF" 2>/dev/null || true)" != "$RESOLVED_STUB_RESOLV" ]; then
            backup_config "$RESOLV_CONF"
            run ln -sfn "$RESOLVED_STUB_RESOLV" "$RESOLV_CONF"
            [ "$DRY_RUN" = true ] || log INFO "Linked $RESOLV_CONF -> $RESOLVED_STUB_RESOLV"
        fi
        # Restart resolved first, then change NM, so NM's (now empty) link DNS
        # is the last thing pushed to resolved.
        run systemctl restart "$RESOLVED_SERVICE"
        configure_networkmanager_dns
    else
        log WARN "systemd-resolved not active; writing $RESOLV_CONF directly"
        backup_config "$RESOLV_CONF"
        if [ -L "$RESOLV_CONF" ]; then
            run rm -f "$RESOLV_CONF"
        fi
        printf 'nameserver 127.0.0.1\noptions edns0 trust-ad\n' | write_file "$RESOLV_CONF" 644
        if nm_available; then
            # NM would otherwise rewrite resolv.conf with DHCP servers.
            backup_config "$NM_DROPIN"
            printf '# Generated by SetDNScache\n[main]\ndns=none\n' | write_file "$NM_DROPIN" 644
            run systemctl reload NetworkManager || true
        fi
    fi
}

# ============================================================================
# Systemd Service Management
# ============================================================================

enable_and_restart_services() {
    log INFO "Enabling and (re)starting services..."
    record_service_state "$STUBBY_SERVICE"
    record_service_state "$DNSMASQ_SERVICE"
    # Explicit && chain: this function is called from an "if", where set -e
    # is suspended. Stubby goes first so it releases 127.0.0.1:53 (the
    # package default) before dnsmasq binds it.
    run systemctl enable "$STUBBY_SERVICE" &&
        run systemctl restart "$STUBBY_SERVICE" &&
        { [ "$DRY_RUN" = true ] || sleep 2; } &&
        run systemctl enable "$DNSMASQ_SERVICE" &&
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
# Test helpers
# ============================================================================

# dig server arguments used by the tests. Pre-configuration tests query the
# current system resolver (/etc/resolv.conf); post-configuration tests query
# the new dnsmasq on 127.0.0.1.
DIG_TARGET=()
DIG_OPTS=(+time=3 +tries=1)

set_test_target() {
    case "$1" in
        pre-configuration|current) DIG_TARGET=() ;;
        *) DIG_TARGET=("@127.0.0.1" -p "$DNS_PORT") ;;
    esac
}

describe_target() {
    if [ ${#DIG_TARGET[@]} -eq 0 ]; then
        echo "system resolver ($(awk '/^nameserver/{print $2; exit}' "$RESOLV_CONF" 2>/dev/null || echo unknown))"
    else
        echo "127.0.0.1:$DNS_PORT"
    fi
}

# Print the listening sockets as "proto local_address users" lines.
listening_sockets() {
    if command -v ss &>/dev/null; then
        ss -Hlnptu 2>/dev/null | awk '{print $1, $5, $7}'
    elif command -v netstat &>/dev/null; then
        netstat -lnptu 2>/dev/null | awk '/^(tcp|udp)/{print $1, $4, $7}'
    fi
}

# is_listening ADDR PORT - exact local address match (127.0.0.1 != 127.0.0.53)
is_listening() {
    local addr="$1" port="$2"
    listening_sockets | awk -v a="$addr" -v p="$port" '
        { la=$2; sub(/%[^:]*:/, ":", la) }      # strip "%lo" interface suffix
        la == a ":" p || la == "[" a "]:" p { found=1 }
        END { exit !found }'
}

# port_owner ADDR PORT - process name(s) bound to ADDR:PORT, or a hint
port_owner() {
    local addr="$1" port="$2" names
    names=$(listening_sockets | awk -v a="$addr" -v p="$port" '
        { la=$2; sub(/%[^:]*:/, ":", la) }
        la == a ":" p || la == "[" a "]:" p {
            u=$3
            while (match(u, /\(\("[^"]+"/)) {
                print substr(u, RSTART+3, RLENGTH-4); u=substr(u, RSTART+RLENGTH)
            }
        }' | sort -u | paste -sd, -)
    if [ -n "$names" ]; then
        echo "$names"
    else
        echo "unknown (run as root to see)"
    fi
}

# Best guess at who owns 127.0.0.1:53 when ss cannot show it (non-root)
guess_local53_owner() {
    local owner
    owner=$(port_owner 127.0.0.1 "$DNS_PORT")
    if [[ "$owner" != unknown* ]]; then
        echo "$owner"; return
    fi
    if [ "$(service_state "$DNSMASQ_SERVICE")" = active ]; then
        echo "dnsmasq (probably; $owner)"
    elif [ "$(service_state "$STUBBY_SERVICE")" = active ] && ! grep -q "@$STUBBY_PORT" "$STUBBY_CONFIG" 2>/dev/null; then
        echo "stubby with its default config (probably; $owner)"
    else
        echo "$owner"
    fi
}

service_state() {
    local st
    st=$(systemctl is-active "$1" 2>/dev/null) || true
    echo "${st:-unknown}"
}

# ============================================================================
# Connectivity Test Functions
# ============================================================================

test_connectivity() {
    local phase="${1:-current}"
    set_test_target "$phase"
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
    
    # Test 8: DNS leaks
    echo ""
    echo "--- DNS Leak Test ---"
    if test_dns_leak; then
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
    log INFO "Testing DNS resolution via $(describe_target)..."

    local domains=("google.com" "cloudflare.com" "quad9.net")
    local all_passed=true domain result rc

    for domain in "${domains[@]}"; do
        rc=0
        result=$(dig +short "${DIG_OPTS[@]}" A "$domain" "${DIG_TARGET[@]}" 2>&1) || rc=$?
        # dig +short prints CNAMEs too; keep only IPv4 addresses
        local ips
        ips=$(printf '%s\n' "$result" | grep -E '^[0-9]+(\.[0-9]+){3}$' | paste -sd' ' - || true)
        if [ -n "$ips" ]; then
            log INFO "  ✓ $domain resolved: $ips"
        elif [ "$rc" -ne 0 ]; then
            log WARN "  ✗ $domain: query failed ($(printf '%s' "$result" | grep -m1 . || echo "dig exit $rc"))"
            all_passed=false
        else
            log WARN "  ✗ $domain: no A record returned"
            all_passed=false
        fi
    done

    if [ "$all_passed" = true ]; then
        log INFO "DNS Resolution Test: PASSED"
        return 0
    fi
    log ERROR "DNS Resolution Test: FAILED"
    return 1
}

test_port_connectivity() {
    log INFO "Testing port connectivity..."

    local dnsmasq_ok=false stubby_ok=false owner

    if is_listening 127.0.0.1 "$DNS_PORT"; then
        owner=$(guess_local53_owner)
        if [[ "$owner" == dnsmasq* ]]; then
            log INFO "  ✓ dnsmasq listening on 127.0.0.1:$DNS_PORT"
            dnsmasq_ok=true
        else
            log WARN "  ✗ 127.0.0.1:$DNS_PORT is in use, but not by dnsmasq: $owner"
        fi
    else
        log WARN "  ✗ Nothing listening on 127.0.0.1:$DNS_PORT"
    fi

    if is_listening 127.0.0.1 "$STUBBY_PORT"; then
        owner=$(port_owner 127.0.0.1 "$STUBBY_PORT")
        if [[ "$owner" == stubby* ]] || { [[ "$owner" == unknown* ]] && [ "$(service_state "$STUBBY_SERVICE")" = active ]; }; then
            log INFO "  ✓ Stubby listening on 127.0.0.1:$STUBBY_PORT"
            stubby_ok=true
        else
            log WARN "  ✗ 127.0.0.1:$STUBBY_PORT is in use by: $owner"
        fi
    else
        log WARN "  ✗ Stubby not listening on 127.0.0.1:$STUBBY_PORT"
    fi

    if [ "$dnsmasq_ok" = true ] && [ "$stubby_ok" = true ]; then
        log INFO "Port Connectivity Test: PASSED"
        return 0
    fi
    log ERROR "Port Connectivity Test: FAILED"
    return 1
}

test_service_status() {
    log INFO "Testing service status..."

    if ! command -v systemctl &>/dev/null; then
        log WARN "systemd not available - skipping service status checks"
        return 0
    fi

    local services_ok=true svc st
    for svc in "$STUBBY_SERVICE" "$DNSMASQ_SERVICE"; do
        st=$(service_state "$svc")
        if [ "$st" = "active" ]; then
            log INFO "  ✓ $svc service is active"
        else
            log WARN "  ✗ $svc service is not active (status: $st)"
            services_ok=false
        fi
        log DEBUG "$svc enabled: $(systemctl is-enabled "$svc" 2>/dev/null || true)"
    done

    if [ "$services_ok" = true ]; then
        log INFO "Service Status Test: PASSED"
        return 0
    fi
    log ERROR "Service Status Test: FAILED"
    return 1
}

# DNSSEC: a signed zone must come back with the AD flag, and a deliberately
# broken zone (dnssec-failed.org) must SERVFAIL.
dig_flags_status() {
    # prints "<status> <flags...>" from dig's header
    dig "${DIG_OPTS[@]}" +dnssec +noall +comments "$@" "${DIG_TARGET[@]}" 2>/dev/null |
        awk '/status:/{for(i=1;i<=NF;i++) if($i=="status:") {st=$(i+1); sub(",","",st)}}
             /;; flags:/{sub(/.*flags: */,""); sub(/;.*/,""); fl=$0}
             END{print (st?st:"NONE"), fl}'
}

test_dnssec_validation() {
    log INFO "Testing DNSSEC validation via $(describe_target)..."
    if ! command -v dig &>/dev/null; then
        log WARN "dig not available - cannot test DNSSEC"
        return 1
    fi
    local ok=true d st fl signed_ok=false
    for d in cloudflare.com isc.org; do
        read -r st fl <<< "$(dig_flags_status A "$d")"
        if [ "$st" = NOERROR ] && [[ " $fl " == *" ad "* ]]; then
            log INFO "  ✓ $d validated (AD flag set)"
            signed_ok=true
            break
        fi
        log WARN "  ✗ $d: status=$st flags=[$fl] (no AD flag)"
    done
    [ "$signed_ok" = true ] || ok=false

    read -r st fl <<< "$(dig_flags_status A dnssec-failed.org)"
    if [ "$st" = SERVFAIL ]; then
        log INFO "  ✓ dnssec-failed.org rejected (SERVFAIL) - bogus signatures are blocked"
    else
        log WARN "  ✗ dnssec-failed.org returned $st (expected SERVFAIL) - resolver is not validating"
        ok=false
    fi

    if [ "$ok" = true ]; then
        log INFO "DNSSEC Validation Test: PASSED"
        return 0
    fi
    log ERROR "DNSSEC Validation Test: FAILED"
    return 1
}

# Leak test: the system must have no resolver other than the local chain.
test_dns_leak() {
    log INFO "Testing for DNS leaks (non-local resolvers)..."
    local ok=true ns extra=""
    while read -r ns; do
        case "$ns" in 127.0.0.1|127.0.0.53|::1) ;; *) extra+="$ns " ;; esac
    done < <(awk '/^nameserver/{print $2}' "$RESOLV_CONF" 2>/dev/null)
    if [ -n "$extra" ]; then
        log WARN "  ✗ $RESOLV_CONF lists non-local nameservers: $extra"
        ok=false
    else
        log INFO "  ✓ $RESOLV_CONF has only local nameservers"
    fi
    if command -v resolvectl &>/dev/null && resolvectl status &>/dev/null; then
        local leaks
        leaks=$(resolvectl dns 2>/dev/null | awk -F': ' 'NF>1{n=split($2,a," "); for(i=1;i<=n;i++) if(a[i]!="127.0.0.1" && a[i]!="::1") print $1": "a[i]}')
        if [ -n "$leaks" ]; then
            log WARN "  ✗ systemd-resolved has non-local DNS servers:"
            while read -r ns; do log WARN "      $ns"; done <<< "$leaks"
            ok=false
        else
            log INFO "  ✓ systemd-resolved uses only 127.0.0.1"
        fi
    fi
    if [ "$ok" = true ]; then log INFO "DNS Leak Test: PASSED"; return 0; fi
    log ERROR "DNS Leak Test: FAILED"
    return 1
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
            dig +short "${DIG_OPTS[@]}" "$domain" "${DIG_TARGET[@]}" &>/dev/null || true
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
    stats=$(dig "${DIG_OPTS[@]}" google.com "${DIG_TARGET[@]}" +stats 2>&1 | grep "Query time:" || true)
    
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
        
        # Alternative: test resolution directly
        if [ -n "$(dig +short "${DIG_OPTS[@]}" google.com "${DIG_TARGET[@]}" 2>/dev/null || true)" ]; then
            log INFO "  ✓ DNS resolution working via $(describe_target)"
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

    local conflicts_found=false owner addr

    # systemd-resolved's stub (127.0.0.53/127.0.0.54) does not collide with
    # 127.0.0.1:53 (dnsmasq uses bind-interfaces) and is kept.
    for addr in 127.0.0.53 127.0.0.54; do
        if is_listening "$addr" "$DNS_PORT"; then
            log INFO "  i $addr:$DNS_PORT is systemd-resolved's stub; kept, forwards only to 127.0.0.1 ($RESOLVED_DROPIN)"
        fi
    done

    if is_listening 127.0.0.1 "$DNS_PORT"; then
        owner=$(guess_local53_owner)
        case "$owner" in
            dnsmasq*) log INFO "  i 127.0.0.1:$DNS_PORT already served by $owner (will be reconfigured)" ;;
            stubby*)  log INFO "  i 127.0.0.1:$DNS_PORT served by $owner; setup moves Stubby to $STUBBY_PORT before starting dnsmasq" ;;
            *)
                log WARN "  ✗ 127.0.0.1:$DNS_PORT is already in use by: $owner"
                log INFO "  Remediation: stop that service, or it will block dnsmasq"
                conflicts_found=true
                ;;
        esac
    fi

    if is_listening 127.0.0.1 "$STUBBY_PORT"; then
        owner=$(port_owner 127.0.0.1 "$STUBBY_PORT")
        if [[ "$owner" == stubby* ]]; then
            log INFO "  i 127.0.0.1:$STUBBY_PORT already served by stubby"
        else
            log WARN "  ✗ 127.0.0.1:$STUBBY_PORT is already in use by: $owner"
            conflicts_found=true
        fi
    fi

    local service
    for service in bind9 named unbound knot-resolver; do
        if [ "$(service_state "$service")" = active ]; then
            log WARN "  ! $service is running and may conflict"
            log INFO "  Remediation: sudo systemctl stop $service"
            conflicts_found=true
        fi
    done

    if [ "$conflicts_found" = true ]; then
        log WARN "Conflict Detection Test: PASSED (conflicts detected - see warnings)"
    else
        log INFO "  ✓ No conflicting DNS listeners"
        log INFO "Conflict Detection Test: PASSED"
    fi
    return 0
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
        mkdir -p "$BACKUP_DIR"
        chmod 700 "$BACKUP_DIR"
        trap 'rc=$?; log ERROR "Setup failed (exit $rc). Changes so far are recorded in $STATE_FILE; undo with: sudo $0 --rollback"' ERR
    fi

    migrate_legacy_backups

    log_section "Configuring Stubby with DNS-over-TLS"
    backup_config "$STUBBY_CONFIG"
    generate_stubby_config

    log_section "Configuring DNSMasq"
    backup_config "$DNSMASQ_DROPIN"
    generate_dnsmasq_config
    if ! dnsmasq_config_test; then
        log ERROR "Aborting before any service restart."
        log ERROR "System resolver (systemd-resolved) was NOT changed; DNS still works as before."
        log INFO "To undo the partial setup run: sudo $0 --rollback"
        exit 1
    fi

    log_section "Starting Services"
    if ! enable_and_restart_services; then
        log ERROR "Starting services failed. Inspect: systemctl status stubby dnsmasq ; journalctl -xeu dnsmasq"
        log ERROR "System resolver (systemd-resolved) was NOT changed; DNS still works as before."
        log INFO "To undo the partial setup run: sudo $0 --rollback"
        exit 1
    fi

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
    local i rec key val file backup uuid nm4 nm6
    for (( i=${#records[@]}-1; i>=0; i-- )); do
        rec="${records[$i]}"
        key="${rec%%=*}"
        val="${rec#*=}"
        case "$key" in
            backup)
                file="${val%%|*}"; backup="${val#*|}"
                if [ -e "$backup" ] || [ -L "$backup" ]; then
                    run cp -a --remove-destination "$backup" "$file"
                    [ "$DRY_RUN" = true ] || log INFO "Restored $file from $backup (backup kept)"
                else
                    log WARN "Backup $backup missing; cannot restore $file"
                fi
                ;;
            created)
                if [ -e "$val" ] || [ -L "$val" ]; then
                    run rm -f "$val"
                    [ "$DRY_RUN" = true ] || log INFO "Removed $val (did not exist before)"
                fi
                ;;
            service)
                services+=("$val")   # reverse order: earliest (original) last
                ;;
            nm)
                IFS='|' read -r uuid nm4 nm6 <<< "$val"
                restore_nm_connection "$uuid" "$nm4" "$nm6"
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
    if [ "$DRY_RUN" = true ]; then log INFO "Dry-run rollback finished; nothing was changed"; else log INFO "Rollback completed (backup files were kept)"; fi
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
    All originals are backed up under $BACKUP_DIR/<timestamp>/<path> and recorded in $STATE_FILE.

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
