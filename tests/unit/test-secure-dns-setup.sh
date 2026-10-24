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
check "rollback kept the backup" 'ls "$STATE_DIR"/backups/*"$STUBBY_CONFIG" >/dev/null 2>&1'
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

# 10. Dependencies: dnsmasq-base only, missing units, start failure keeps state
cat > "$TMP/bin/dpkg-query" <<'FAKE'
#!/bin/bash
pkg="${!#}"
case " $MISSING_PKGS " in *" $pkg "*) echo -n "unknown ok not-installed" ;; *) echo -n "install ok installed" ;; esac
FAKE
cat > "$TMP/bin/systemctl" <<'FAKE'
#!/bin/bash
echo "$*" >> "$SYSTEMCTL_LOG"
case "$1" in
  list-unit-files) u="${*: -1}"; case " $MISSING_UNITS " in *" ${u%.service} "*) exit 1;; *) echo "$u enabled enabled";; esac ;;
  cat) case " $MISSING_UNITS " in *" ${2%.service} "*) exit 1;; esac ;;
  is-enabled) echo disabled; exit 1 ;;
  is-active) echo inactive; exit 3 ;;
  enable|restart) case " $FAIL_START " in *" $2 "*) echo "Failed to $1 $2" >&2; exit 1;; esac ;;
esac
exit 0
FAKE
chmod +x "$TMP/bin/dpkg-query" "$TMP/bin/systemctl"
export MISSING_PKGS="" MISSING_UNITS="" FAIL_START=""

out=$(MISSING_PKGS="dnsmasq" bash -c "source '$SCRIPT'; DRY_RUN=true; check_dependencies" 2>&1)
check "dnsmasq-base only: dnsmasq package reported missing" 'grep -q "Missing packages: dnsmasq" <<< "$out"'
check "dry-run shows apt-get install dnsmasq" 'grep -q "would run: apt-get install -y dnsmasq" <<< "$out"'

out=$(MISSING_UNITS="dnsmasq" bash -c "source '$SCRIPT'; check_dependencies" 2>&1 || echo "RC=$?")
check "missing dnsmasq.service is fatal" 'grep -q "unit(s) not found: dnsmasq.service" <<< "$out" && grep -q "RC=1" <<< "$out"'

rm -rf "${TMP:?}/etc" "${TMP:?}/state"
out=$(MISSING_PKGS="dnsmasq" bash -c "source '$SCRIPT'; check_root() { :; }; test_connectivity() { return 0; }; configure_secure_dns" 2>&1 </dev/null || echo "RC=$?")
check "declined install fails before writing config" 'grep -q "RC=" <<< "$out" && [ ! -e "$STUBBY_CONFIG" ] && [ ! -e "$DNSMASQ_D/stubby-forward.conf" ]'

rm -rf "${TMP:?}/etc" "${TMP:?}/state"; mkdir -p "$TMP/etc/stubby"; echo original > "$STUBBY_CONFIG"
out=$(FAIL_START="dnsmasq" bash -c "source '$SCRIPT'; check_root() { :; }; test_connectivity() { return 0; }; configure_secure_dns" 2>&1 || echo "RC=$?")
check "service start failure exits non-zero" 'grep -q "RC=1" <<< "$out"'
check "failure message points to --rollback" 'grep -q -- "--rollback" <<< "$out"'
check "state records stubby backup after failure" 'grep -q "^backup=$STUBBY_CONFIG|" "$STATE_DIR/state"'
check "state records created dnsmasq drop-in" 'grep -q "^created=$DNSMASQ_D/stubby-forward.conf" "$STATE_DIR/state"'
check "state records original service states" 'grep -q "^service=dnsmasq|" "$STATE_DIR/state"'
bash -c "source '$SCRIPT'; check_root() { :; }; rollback" >/dev/null 2>&1
check "rollback after failed run restores stubby config" '[ "$(cat "$STUBBY_CONFIG")" = original ] && [ ! -e "$DNSMASQ_D/stubby-forward.conf" ]'

# 11. Backups outside config dirs, dnsmasq --test, legacy .bak migration
cat > "$TMP/bin/dnsmasq" <<'FAKE'
#!/bin/bash
echo "$*" >> "$TMP_DNSMASQ_LOG"
[ -n "${DNSMASQ_TEST_FAIL:-}" ] && { echo "dnsmasq: illegal repeated keyword at line 3 of x.bak" >&2; exit 1; }
echo "dnsmasq: syntax check OK."
FAKE
chmod +x "$TMP/bin/dnsmasq"
export TMP_DNSMASQ_LOG="$TMP/dnsmasq.log" DNSMASQ_CONF="$TMP/etc/dnsmasq.conf"
RUN='source '"$SCRIPT"'; check_root() { :; }; test_connectivity() { return 0; }; local_resolver_works() { return 0; }; configure_system_resolver() { echo RESOLVER_TOUCHED; }; configure_secure_dns'

rm -rf "${TMP:?}/etc" "${TMP:?}/state" "$TMP_DNSMASQ_LOG"; mkdir -p "$TMP/etc/stubby" "$DNSMASQ_D"
echo original > "$STUBBY_CONFIG"; echo old > "$DNSMASQ_D/stubby-forward.conf"
echo legacy > "$DNSMASQ_D/stubby-forward.conf.bak.20261024031951"
out=$(bash -c "$RUN" 2>&1 || echo "RC=$?")
check "no backup files left in config dirs" '[ -z "$(find "$TMP/etc" -name "*.bak*")" ]'
check "backups stored under STATE_DIR/backups/<ts>/<path>" 'ls "$STATE_DIR"/backups/[0-9]*"$STUBBY_CONFIG" "$STATE_DIR"/backups/[0-9]*"$DNSMASQ_D/stubby-forward.conf" >/dev/null'
check "legacy .bak moved out of dnsmasq.d" '[ -f "$STATE_DIR/backups/legacy$DNSMASQ_D/stubby-forward.conf.bak.20261024031951" ]'
check "dnsmasq --test ran with conf-dir" 'grep -q -- "--test.*--conf-dir=$DNSMASQ_D" "$TMP_DNSMASQ_LOG"'
check "successful run reaches resolver step" 'grep -q RESOLVER_TOUCHED <<< "$out"'
bash -c 'source "'"$SCRIPT"'"; check_root() { :; }; rollback' >/dev/null 2>&1
check "rollback restores from backup dir" '[ "$(cat "$STUBBY_CONFIG")" = original ] && [ "$(cat "$DNSMASQ_D/stubby-forward.conf")" = old ]'

: > "$SYSTEMCTL_LOG"; rm -rf "${TMP:?}/etc" "${TMP:?}/state" "$TMP_DNSMASQ_LOG"; mkdir -p "$TMP/etc/stubby"; echo original > "$STUBBY_CONFIG"
out=$(DNSMASQ_TEST_FAIL=1 bash -c "$RUN" 2>&1 || echo "RC=$?")
check "dnsmasq --test failure aborts" 'grep -q "RC=1" <<< "$out" && grep -q "illegal repeated keyword" <<< "$out"'
check "no service restarted after failed --test" '! grep -q "^restart" "$SYSTEMCTL_LOG"'
check "resolver untouched after failed --test" '! grep -q RESOLVER_TOUCHED <<< "$out" && grep -q -- "--rollback" <<< "$out"'

: > "$SYSTEMCTL_LOG"; rm -rf "${TMP:?}/etc" "${TMP:?}/state"; mkdir -p "$TMP/etc/stubby"; echo original > "$STUBBY_CONFIG"
out=$(FAIL_START="dnsmasq" bash -c "$RUN" 2>&1 || echo "RC=$?")
check "start failure: resolver untouched + rollback hint" '! grep -q RESOLVER_TOUCHED <<< "$out" && grep -q "NOT changed" <<< "$out" && grep -q -- "--rollback" <<< "$out"'

echo "conf-dir=/etc/dnsmasq.d/,*.conf" > "$DNSMASQ_CONF"; : > "$TMP_DNSMASQ_LOG"
bash -c 'source "'"$SCRIPT"'"; dnsmasq_config_test' >/dev/null 2>&1
check "no duplicate conf-dir when dnsmasq.conf has one" '! grep -q -- "--conf-dir" "$TMP_DNSMASQ_LOG"'

echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
