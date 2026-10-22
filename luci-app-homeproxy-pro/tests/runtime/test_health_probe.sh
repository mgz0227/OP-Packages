#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
#
# Functional health probes (runtime/health.sh).
#
# The process/listener gate answers "is the instance up and does it own its
# ports?".  It cannot answer "does it actually serve?", and the probes that do
# are on the same code path a rollback is decided on - so the one property that
# must not regress is that they only *report* by default.  A probe that fails
# because the uplink is down, or because this target has no nslookup/nc, must
# never be able to fail the gate: a rollback loop is worse than the condition
# being probed for.
#
# `health_probe_strict` (UCI) is the opt-in that turns a probe failure into a
# gate failure.  "Cannot probe here" stays non-fatal even then - there is
# nothing to conclude from a missing tool.
#
# Reporting correctly is only half of it.  service_started() runs the probes
# while the reload still holds the procd lock, so a probe that never RETURNS
# blocks every later status and reload behind `flock` - and no amount of
# "failures are only warnings" helps a loop that never finishes.  hp_probe_tcp
# therefore has to survive the two nc flavours it actually meets: one that hangs
# unless it is told to close on stdin EOF, and one (busybox) that accepts no
# options at all and would answer a usage error instead of a verdict.  The two
# stubs below are shaped to fail if the probe is invoked the way that would hang
# or warn in the field.
#
# The probes take explicit ports and shell out to nslookup/nc, so this runs
# anywhere without ucode, procd or a router.
#
# Usage: sh tests/runtime/test_health_probe.sh <repo-root>

ROOT="${1:-.}"
ROOT="$(cd "$ROOT" && pwd)"
RUNTIME="$ROOT/root/etc/homeproxy-pro/scripts/runtime"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/hp-probes.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT INT TERM

FAILED=0
CHECKS=0
FAILURES=0

expect() {
	# expect <name> <actual> <expected>
	CHECKS=$((CHECKS + 1))
	if [ "$2" = "$3" ]; then
		echo "PASS: $1"
	else
		echo "FAIL: $1 (expected '$3', got '$2')"
		FAILED=1
		FAILURES=$((FAILURES + 1))
	fi
}

if [ ! -f "$RUNTIME/health.sh" ]; then
	echo "FAIL: runtime/health.sh is missing under $RUNTIME"
	exit 1
fi

# log() comes from init.d on a router; the probes only call it to report, so
# the test records the lines and asserts on them.
PROBE_LOG="$WORK/probe.log"
: > "$PROBE_LOG"
log() { printf '%s\n' "$*" >> "$PROBE_LOG"; }

# shellcheck source=/dev/null
. "$RUNTIME/health.sh"

# --- stub PATH -------------------------------------------------------------
# The probes are written against `command -v nslookup` / `command -v nc`, so
# the sandbox decides what exists. Each stub's behaviour follows a marker file,
# which keeps the call sites readable.
BIN_OK="$WORK/bin-ok"
BIN_NONE="$WORK/bin-none"
mkdir -p "$BIN_OK" "$BIN_NONE"

cat > "$BIN_OK/nslookup" <<'EOF'
#!/bin/sh
[ -f "$HP_PROBE_STUB_DIR/dns_ok" ] || exit 1
exit 0
EOF
cat > "$BIN_OK/nc" <<'EOF'
#!/bin/sh
[ -f "$HP_PROBE_STUB_DIR/tcp_ok" ] || exit 1
exit 0
EOF
chmod +x "$BIN_OK/nslookup" "$BIN_OK/nc"

HP_PROBE_STUB_DIR="$WORK"
export HP_PROBE_STUB_DIR

PATH="$BIN_OK:$PATH"
export PATH

echo "== hp_probe_dns =="
: > "$WORK/dns_ok"
hp_probe_dns 5333 example.com
expect "dns: an answering inbound is 0" "$?" "0"

rm -f "$WORK/dns_ok"
hp_probe_dns 5333 example.com
expect "dns: a silent inbound is 1" "$?" "1"

hp_probe_dns "" example.com
expect "dns: no port means cannot-probe (2), not failure" "$?" "2"

echo "== hp_probe_tcp =="
: > "$WORK/tcp_ok"
hp_probe_tcp 5330
expect "tcp: an accepting listener is 0" "$?" "0"

rm -f "$WORK/tcp_ok"
hp_probe_tcp 5330
expect "tcp: a refusing listener is 1" "$?" "1"

hp_probe_tcp ""
expect "tcp: no port means cannot-probe (2), not failure" "$?" "2"

echo "== hp_probe_tcp: the probe has to RETURN, not just succeed =="
# The probe runs inside service_started() while the reload still holds the procd
# lock, so a probe that never returns blocks every later status and reload
# behind `flock`.  A test cannot observe a real hang, so each stub below is
# built to FAIL if it is invoked the way that would hang in the field:
#
#   * the GNU stub refuses to answer unless it is passed -c, which is what the
#     real GNU netcat needs to leave an inbound that accepts and then holds the
#     connection open.  It also refuses -w, because -w is spent on the connect
#     and does not bound that loop - so "fixing" it with -w alone fails here.
#   * the busybox stub rejects every option the way ImmortalWrt's build does,
#     so passing -w/-z/-c costs the probe its result.
#
# Both record how they were called, so the test pins the invocation and not
# just the verdict.
BIN_GNU="$WORK/bin-gnu"
BIN_BBB="$WORK/bin-busybox"
mkdir -p "$BIN_GNU" "$BIN_BBB"
NC_ARGS="$WORK/nc_args"

cat > "$BIN_GNU/nc" <<'EOF'
#!/bin/sh
# GNU netcat 0.7.1: advertises --close/--wait, and needs -c to stop watching a
# socket the peer is holding open.  -w is accepted but does not help.
case "$1" in
-h|--help)
	echo "GNU netcat 0.7.1"
	echo "        --close                 close on EOF from stdin"
	echo "        --wait SEC              timeout for connects and final net reads"
	exit 1
	;;
esac
printf '%s\n' "$*" >> "$HP_PROBE_STUB_DIR/nc_args"
case "$*" in
-c\ *) ;;
*) exit 2 ;;  # without -c the real nc would still be running
esac
[ -f "$HP_PROBE_STUB_DIR/tcp_ok" ] || exit 1
exit 0
EOF
cat > "$BIN_BBB/nc" <<'EOF'
#!/bin/sh
# ImmortalWrt 25.12.2 (busybox 1.37.0): nc advertises no --close and accepts
# no option at all - -z/-w/-c/-l are all usage errors.  It exits on stdin EOF
# by itself, so the bare invocation is both correct and sufficient.
case "$1" in
-h|--help)
	echo "Usage: nc [IPADDR PORT]"
	exit 1
	;;
-*)
	echo "Usage: nc [IPADDR PORT]"
	exit 1
	;;
esac
printf '%s\n' "$*" >> "$HP_PROBE_STUB_DIR/nc_args"
[ -f "$HP_PROBE_STUB_DIR/tcp_ok" ] || exit 1
exit 0
EOF
chmod +x "$BIN_GNU/nc" "$BIN_BBB/nc"

SAVED_PATH="$PATH"

: > "$WORK/tcp_ok"
: > "$NC_ARGS"
PATH="$BIN_GNU:$SAVED_PATH"
hp_probe_tcp 5330
expect "gnu nc: an accepting listener is 0" "$?" "0"
expect "gnu nc: it is called with -c, so the probe can return" \
	"$(head -1 "$NC_ARGS" | cut -d' ' -f1)" "-c"
expect "gnu nc: the target is the mixed inbound, not the capability probe" \
	"$(head -1 "$NC_ARGS" | awk '{print $(NF-1), $NF}')" "127.0.0.1 5330"

rm -f "$WORK/tcp_ok"
: > "$NC_ARGS"
hp_probe_tcp 5330
expect "gnu nc: a refusing listener is still 1" "$?" "1"

: > "$WORK/tcp_ok"
: > "$NC_ARGS"
PATH="$BIN_BBB:$SAVED_PATH"
hp_probe_tcp 5330
expect "busybox nc: an accepting listener is 0" "$?" "0"
expect "busybox nc: it is called bare, because busybox accepts no options" \
	"$(head -1 "$NC_ARGS")" "127.0.0.1 5330"

rm -f "$WORK/tcp_ok"
hp_probe_tcp 5330
expect "busybox nc: a refusing listener is still 1" "$?" "1"

PATH="$SAVED_PATH"
export PATH

echo "== missing tooling is 'cannot probe', not 'failed' =="
# PATH is replaced, not prepended to: the host this runs on may well have its
# own nslookup/nc (macOS ships both), and a prepended empty directory would
# still find them behind `command -v`.
SAVED_PATH="$PATH"
PATH="$BIN_NONE"
hp_probe_dns 5333 example.com
rc_dns_missing=$?
hp_probe_tcp 5330
rc_tcp_missing=$?
PATH="$SAVED_PATH"
expect "dns: no nslookup is 2" "$rc_dns_missing" "2"
expect "tcp: no nc is 2" "$rc_tcp_missing" "2"
export PATH

echo "== hp_run_probes: reporting is the default =="
: > "$PROBE_LOG"
rm -f "$WORK/dns_ok" "$WORK/tcp_ok"
HP_PROBE_STRICT=0
export HP_PROBE_STRICT
hp_run_probes "client" 5333 5330
expect "reporting: both probes failing still returns 0" "$?" "0"
expect "reporting: the DNS failure is logged" \
	"$(grep -c 'the client DNS inbound (127.0.0.1:5333) did not answer' "$PROBE_LOG")" "1"
expect "reporting: the TCP failure is logged" \
	"$(grep -c 'nothing accepted a connection on the client mixed inbound (127.0.0.1:5330)' "$PROBE_LOG")" "1"

echo "== hp_run_probes: strict turns a failure into a gate failure =="
: > "$PROBE_LOG"
HP_PROBE_STRICT=1
export HP_PROBE_STRICT
hp_run_probes "client" 5333 5330
expect "strict: a failed probe returns 1" "$?" "1"
expect "strict: the strict path is named in the log" \
	"$(grep -c 'health_probe_strict is on' "$PROBE_LOG")" "1"

echo "== hp_run_probes: strict does not fire on a healthy service =="
: > "$WORK/dns_ok"
: > "$WORK/tcp_ok"
: > "$PROBE_LOG"
hp_run_probes "client" 5333 5330
expect "strict: a passing probe returns 0" "$?" "0"
expect "strict: a passing probe logs nothing" "$(wc -l < "$PROBE_LOG" | tr -d ' ')" "0"

echo "== hp_run_probes: 'cannot probe' never fails the gate =="
rm -f "$WORK/dns_ok" "$WORK/tcp_ok"
: > "$PROBE_LOG"
HP_PROBE_STRICT=1
export HP_PROBE_STRICT
PATH="$BIN_NONE"
hp_run_probes "client" 5333 5330
rc_no_tools=$?
PATH="$SAVED_PATH"
export PATH
expect "strict: a probe that cannot run still returns 0" "$rc_no_tools" "0"
expect "strict: the missing tooling is reported" \
	"$(grep -c 'cannot probe the client' "$PROBE_LOG")" "2"

echo "== hp_config_port_for_tag =="
# The generator writes one field per line (%.J); the sed in the helper also has
# to accept the compact shape, because a config that came from anywhere else
# (or a fixture) must not silently yield "no port" - that is how the probes
# would end up probing nothing at all.
cat > "$WORK/pretty.json" <<'EOF'
{
	"inbounds": [
		{
			"tag": "dns-in",
			"listen": "127.0.0.1",
			"listen_port": 5333
		},
		{
			"tag": "mixed-in",
			"listen": "::",
			"listen_port": 5330
		},
		{
			"tag": "tproxy-in",
			"listen_port": 5332
		}
	],
	"outbounds": [
		{
			"tag": "direct-out",
			"type": "direct"
		}
	]
}
EOF
cat > "$WORK/compact.json" <<'EOF'
{"inbounds":[{"tag":"dns-in","listen_port":5333},{"tag":"mixed-in","listen_port":5330}],"outbounds":[{"tag":"direct-out","type":"direct"}]}
EOF

expect "port_for_tag: dns-in from a pretty config" \
	"$(hp_config_port_for_tag "$WORK/pretty.json" 'dns-in')" "5333"
expect "port_for_tag: mixed-in from a pretty config" \
	"$(hp_config_port_for_tag "$WORK/pretty.json" 'mixed-in')" "5330"
expect "port_for_tag: a third inbound is not confused with the first" \
	"$(hp_config_port_for_tag "$WORK/pretty.json" 'tproxy-in')" "5332"
expect "port_for_tag: an outbound tag is not read as a listener" \
	"$(hp_config_port_for_tag "$WORK/pretty.json" 'direct-out')" ""
expect "port_for_tag: an absent tag yields nothing" \
	"$(hp_config_port_for_tag "$WORK/pretty.json" 'nope-in')" ""
expect "port_for_tag: compact JSON yields the same port" \
	"$(hp_config_port_for_tag "$WORK/compact.json" 'dns-in')" "5333"

expect "config_ports: both listeners are reported" \
	"$(hp_config_ports "$WORK/pretty.json" | tr '\n' ' ' | sed 's/ $//')" "5333 5330 5332"

printf '%d checks, %d failures\n' "$CHECKS" "$FAILURES"
[ "$FAILED" = 0 ] && echo "HEALTH PROBE TESTS PASSED"
exit "$FAILED"
