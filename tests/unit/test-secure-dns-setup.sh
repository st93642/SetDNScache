#!/bin/bash
# shellcheck disable=SC2034  # "out" is read inside eval in check()
# Unit tests for bin/secure-dns-setup.sh. Safe: no root, no system changes.
# Uses a temp dir for all paths and a fake systemctl on PATH.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/bin/secure-dns-setup.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

ok()  { echo "ok   - $1"; pass=$((pass + 1)); }
bad() { echo "FAIL - $1"; fail=$((fail + 1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# Fake systemctl that logs calls and reports fixed states
mkdir -p "$TMP/bin"
cat > "$TMP/bin/systemctl" <<'FAKE'
#!/bin/bash
echo "$*" >> "$SYSTEMCTL_LOG"
case "$1" in
  is-enabled) case "$2" in stubby) echo disabled; exit 1;; *) echo enabled;; esac ;;
  is-active)  case "$2" in stubby) echo inactive; exit 3;; *) echo active;; esac ;;
esac
exit 0
FAKE
chmod +x "$TMP/bin/systemctl"
export PATH="$TMP/bin:$PATH" SYSTEMCTL_LOG="$TMP/systemctl.log"

# 1. Counters survive set -e when starting at zero (finding 2)
out=$(bash -c "set -euo pipefail; source '$SCRIPT'
  test_dns_resolution() { return 1; }; test_port_connectivity() { return 1; }
  test_service_status() { return 0; }; test_dnssec_validation() { return 0; }
  test_latency() { return 0; }; test_fallback_servers() { return 0; }
  test_conflict_detection() { return 0; }
  rc=0; test_connectivity unit >/dev/null || rc=\$?; echo \"rc=\$rc\"")
check "test_connectivity counts failures and does not abort" '[ "$out" = "rc=2" ]'

# 2. Argument parsing order independence and conflicts
out=$(bash -c "source '$SCRIPT'; parse_args --rollback --verbose --dry-run -y; echo \"\$ACTION \$VERBOSE \$DRY_RUN \$ASSUME_YES\"")
check "flags after action are parsed" '[ "$out" = "rollback true true true" ]'
if bash "$SCRIPT" --rollback --run-tests >/dev/null 2>&1; then bad "conflicting actions rejected"; else ok "conflicting actions rejected"; fi
if bash "$SCRIPT" --bogus >/dev/null 2>&1; then bad "unknown option rejected"; else ok "unknown option rejected"; fi
check "--help exits 0" 'bash "$SCRIPT" --help >/dev/null'

# 3. Generated configs: no pins, port 5453, proxy-dnssec, hosts honoured
export STUBBY_CONFIG="$TMP/etc/stubby/stubby.yml" DNSMASQ_D="$TMP/etc/dnsmasq.d" \
       RESOLVED_DROPIN_DIR="$TMP/etc/resolved.conf.d" STATE_DIR="$TMP/state"
bash -c "source '$SCRIPT'; generate_stubby_config; generate_dnsmasq_config" >/dev/null
check "stubby config has no pinset" '! grep -q tls_pubkey_pinset "$STUBBY_CONFIG"'
check "stubby listens on 5453" 'grep -q "127.0.0.1@5453" "$STUBBY_CONFIG"'
check "stubby lists 6 upstreams" '[ "$(grep -c address_data "$STUBBY_CONFIG")" -eq 6 ]'
check "dnsmasq forwards to 5453" 'grep -qx "server=127.0.0.1#5453" "$DNSMASQ_D/stubby-forward.conf"'
check "dnsmasq uses proxy-dnssec, not dnssec" 'grep -qx proxy-dnssec "$DNSMASQ_D/stubby-forward.conf" && ! grep -qx dnssec "$DNSMASQ_D/stubby-forward.conf"'
check "dnsmasq does not set no-hosts" '! grep -q "^no-hosts" "$DNSMASQ_D/stubby-forward.conf"'
if command -v stubby >/dev/null; then
  check "stubby -i accepts config" '! stubby -C "$STUBBY_CONFIG" -i 2>&1 | grep -q "Could not"'
fi
DM=$(command -v dnsmasq || echo /usr/sbin/dnsmasq)
if [ -x "$DM" ]; then
  check "dnsmasq --test accepts config" '"$DM" --test -C "$DNSMASQ_D/stubby-forward.conf" >/dev/null 2>&1'
fi

# 4. Dry run writes nothing
rm -rf "${TMP:?}/etc" "${TMP:?}/state"; : > "$SYSTEMCTL_LOG"
bash -c "source '$SCRIPT'; DRY_RUN=true; backup_config '$TMP/x'; generate_stubby_config; generate_dnsmasq_config; enable_and_restart_services" >/dev/null
check "dry run created no files" '[ ! -e "$TMP/etc" ] && [ ! -e "$TMP/state" ]'
check "dry run made no mutating systemctl calls" '! grep -qE "^(enable|restart|start|stop|disable)" "$SYSTEMCTL_LOG"'

# 5. Rollback replays state in reverse and restores services
rm -rf "${TMP:?}/etc" "${TMP:?}/state"; : > "$SYSTEMCTL_LOG"
mkdir -p "$TMP/etc/stubby"; echo original > "$STUBBY_CONFIG"
bash -c "source '$SCRIPT'
  mkdir -p \"\$STATE_DIR\"
  record_service_state stubby; record_service_state dnsmasq
  backup_config \"\$STUBBY_CONFIG\"; echo generated > \"\$STUBBY_CONFIG\"
  backup_config \"\$DNSMASQ_D/stubby-forward.conf\"; generate_dnsmasq_config
  backup_config \"\$RESOLVED_DROPIN\"; mkdir -p \"\$RESOLVED_DROPIN_DIR\"; echo x > \"\$RESOLVED_DROPIN\"
  check_root() { :; }; rollback" >/dev/null
check "rollback restored stubby config" '[ "$(cat "$STUBBY_CONFIG")" = original ]'
check "rollback kept the backup" 'ls "$STUBBY_CONFIG".bak.* >/dev/null 2>&1'
check "rollback removed created dnsmasq drop-in" '[ ! -e "$DNSMASQ_D/stubby-forward.conf" ]'
check "rollback removed resolved drop-in" '[ ! -e "$TMP/etc/resolved.conf.d/setdnscache.conf" ]'
check "rollback restored stubby to disabled+stopped" 'grep -qx "disable stubby" "$SYSTEMCTL_LOG" && grep -qx "stop stubby" "$SYSTEMCTL_LOG"'
check "rollback restored dnsmasq to enabled+active" 'grep -qx "enable dnsmasq" "$SYSTEMCTL_LOG" && grep -qx "restart dnsmasq" "$SYSTEMCTL_LOG"'
check "state file archived" 'ls "$STATE_DIR"/state.rolledback.* >/dev/null 2>&1 && [ ! -e "$STATE_DIR/state" ]'

# 6. Socket matching: exact address, owner names, non-root fallback
cat > "$TMP/bin/ss" <<'FAKE'
#!/bin/bash
cat "$SS_FIXTURE"
FAKE
chmod +x "$TMP/bin/ss"
export SS_FIXTURE="$TMP/ss.txt"
cat > "$SS_FIXTURE" <<'SS'
udp UNCONN 0 0 127.0.0.53%lo:53 0.0.0.0:* users:(("systemd-resolve",pid=1,fd=1))
tcp LISTEN 0 4096 127.0.0.54:53 0.0.0.0:* users:(("systemd-resolve",pid=1,fd=2))
udp UNCONN 0 0 0.0.0.0:5353 0.0.0.0:* users:(("avahi-daemon",pid=2,fd=3))
SS
check "resolved stub is not 127.0.0.1:53" '! bash -c "source \"$SCRIPT\"; is_listening 127.0.0.1 53"'
check "127.0.0.53%lo:53 is matched exactly" 'bash -c "source \"$SCRIPT\"; is_listening 127.0.0.53 53"'
check "owner name parsed from users:((...))" '[ "$(bash -c "source \"$SCRIPT\"; port_owner 127.0.0.53 53")" = systemd-resolve ]'
echo 'tcp LISTEN 0 16 127.0.0.1:53 0.0.0.0:*' >> "$SS_FIXTURE"
check "127.0.0.1:53 detected" 'bash -c "source \"$SCRIPT\"; is_listening 127.0.0.1 53"'
check "owner unknown without root" '[ "$(bash -c "source \"$SCRIPT\"; port_owner 127.0.0.1 53")" = "unknown (run as root to see)" ]'
out=$(bash -c "source '$SCRIPT'; service_state() { echo inactive; }; test_port_connectivity" 2>&1 || true)
check "port test does not claim dnsmasq when it is inactive" '! grep -q "dnsmasq listening" <<< "$out"'
out=$(bash -c "source '$SCRIPT'; test_conflict_detection" 2>&1)
check "resolved stub reported as info, not conflict" 'grep -q "systemd-resolved.s stub" <<< "$out"'
check "conflict owner is never empty" '! grep -qE "in use by: *$" <<< "$out"'

# 7. service_state prints a single word
check "service_state single line for inactive" '[ "$(bash -c "source \"$SCRIPT\"; service_state stubby")" = inactive ]'

# 8. Test target: pre-config uses system resolver, post-config uses 127.0.0.1
check "pre-configuration uses system resolver" '[ "$(bash -c "source \"$SCRIPT\"; set_test_target pre-configuration; echo \${#DIG_TARGET[@]}")" = 0 ]'
check "post-configuration uses 127.0.0.1" '[ "$(bash -c "source \"$SCRIPT\"; set_test_target post-configuration; echo \${DIG_TARGET[0]}")" = "@127.0.0.1" ]'

# 9. Dry run never claims a backup was made
echo x > "$TMP/f"
out=$(bash -c "source '$SCRIPT'; DRY_RUN=true; backup_config '$TMP/f'" 2>&1)
check "dry-run backup logs no 'Backed up'" '! grep -q "Backed up" <<< "$out" && grep -q "would run: cp" <<< "$out"'
check "dry-run left no backup file" '! ls "$TMP"/f.bak.* >/dev/null 2>&1'

echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
