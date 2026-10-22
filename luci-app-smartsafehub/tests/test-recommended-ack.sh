#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Verify lightweight confirmation reporting without relying on a host Python version.
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
DEVICE="$ROOT/root/usr/libexec/smartsafehub-device"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

fail() {
  printf 'FAIL: recommended ack: %s\n' "$1" >&2
  exit 1
}

# Exercise the production function with mocked transport and JSON queries.
sed -n '/^recommended_fast_sync() {/,/^}/p' "$DEVICE" > "$TMP/fast.sh"
[ -s "$TMP/fast.sh" ] || fail 'production function not found'
. "$TMP/fast.sh"

RUNTIME_DIR="$TMP"
# Use a fixture-owned executable: /bin/true exists on many Linux systems,
# but macOS ships true in /usr/bin. The production fast-sync function
# explicitly checks this helper path with [ -x ], so an absent helper
# makes the test fail before it can make its first mocked API request.
RECOMMENDED_HELPER="$TMP/recommended-helper"
printf '#!/bin/sh\nexit 0\n' > "$RECOMMENDED_HELPER"
chmod 0755 "$RECOMMENDED_HELPER"
[ -x "$RECOMMENDED_HELPER" ] || fail 'mock recommended helper is not executable'
STATE_FILE="$TMP/device.json"
RECOMMENDED_STATE="$TMP/state"
RECOMMENDED_CATALOG="$TMP/catalog.json"
RECOMMENDED_RECEIPT="$TMP/receipt.json"
RECOMMENDED_ACK_STATE="$TMP/reported"
API_BASE_URL='https://example.test/api/v1'
REVISION="$(printf '%064d' 1)"
RULES_REVISION="$(printf '%064d' 2)"

printf '{"accountRegistered":true}\n' > "$STATE_FILE"
printf '%s\n' "$REVISION" > "$RECOMMENDED_STATE"
printf '{"rules_revision":"%s"}\n' "$RULES_REVISION" > "$RECOMMENDED_CATALOG"
printf '{"revision":"%s","status":"confirmed","domains":[]}\n' "$REVISION" > "$RECOMMENDED_RECEIPT"

CLOCK=1000
SERVER_ACK=true
now_epoch() { printf '%s' "$CLOCK"; }
credential_token() { printf '%s' ssh_dev_mock; }

# Parse only the scalar fields used in these fixtures with POSIX awk.
# In particular, avoid relying on BSD/GNU grep or sed regex behavior for
# quoted JSON values. The production JSON parser is not replaced by this mock.
json_value() {
  [ -f "$1" ] || return 0
  awk -v key="${2#@.}" '
    {
      marker = "\"" key "\""
      at = index($0, marker)
      if (!at) next
      value = substr($0, at + length(marker))
      sub(/^[[:space:]]*:[[:space:]]*/, "", value)
      if (substr(value, 1, 1) == "\"") {
        value = substr(value, 2)
        closing = index(value, "\"")
        if (closing) print substr(value, 1, closing - 1)
      } else if (substr(value, 1, 4) == "true") {
        print "true"
      } else if (substr(value, 1, 5) == "false") {
        print "false"
      }
      exit
    }
  ' "$1"
}

# Validate the mocked inputs before invoking the production function. On a
# platform that parses a fixture differently, print the cause rather than an
# unhelpful 'initial fast sync failed'.
[ "$(json_value "$STATE_FILE" '@.accountRegistered')" = true ] || fail 'mock account registration unreadable'
[ "$(json_value "$RECOMMENDED_RECEIPT" '@.revision')" = "$REVISION" ] || fail 'mock receipt revision unreadable'
[ "$(json_value "$RECOMMENDED_RECEIPT" '@.status')" = confirmed ] || fail 'mock receipt status unreadable'
[ "$(json_value "$RECOMMENDED_CATALOG" '@.rules_revision')" = "$RULES_REVISION" ] || fail 'mock rules revision unreadable'

write_recommended_sync_status() { :; }
log_message() { :; }
post_json() {
  cp "$2" "$TMP/request.json" || fail 'could not capture request'
  printf '{"changed":false,"revision":"%s","acknowledged":%s}\n' "$REVISION" "$SERVER_ACK" > "$3"
}
assert_request_has_ack() {
  grep -Fq '"recommended_rules_ack"' "$TMP/request.json" || fail "$1: missing confirmation"
}
assert_request_has_no_ack() {
  if grep -Fq '"recommended_rules_ack"' "$TMP/request.json"; then
    fail "$1: sent an unnecessary confirmation"
  fi
}
assert_report_time() {
  [ -f "$RECOMMENDED_ACK_STATE" ] || fail "$1: missing acknowledged marker"
  actual="$(awk '{print $3}' "$RECOMMENDED_ACK_STATE")"
  [ "$actual" = "$2" ] || fail "$1: marker time '$actual' differs from '$2'"
}

# Print the last request/response only on failure, with fixture-controlled
# data. No real device credential or production response is ever logged here.
run_fast_sync() {
  phase="$1"
  if recommended_fast_sync; then return 0; fi
  printf 'FAIL: recommended ack: %s fast sync failed\n' "$phase" >&2
  for file in "$TMP/request.json" "$TMP"/recommended-poll-response.*.json; do
    if [ -f "$file" ]; then
      printf 'DEBUG: %s: ' "${file##*/}" >&2
      cat "$file" >&2
    fi
  done
  exit 1
}

run_fast_sync initial
assert_request_has_ack initial
assert_report_time initial 1000

run_fast_sync unchanged
assert_request_has_no_ack unchanged

CLOCK=1601
SERVER_ACK=false
run_fast_sync unacknowledged
assert_request_has_ack unacknowledged
assert_report_time unacknowledged 1000

SERVER_ACK=true
run_fast_sync retry
assert_request_has_ack retry
assert_report_time retry 1601

# Never report a receipt that has disappeared or failed to match local state.
rm -f "$RECOMMENDED_RECEIPT"
SERVER_ACK=false
recommended_fast_sync || true
[ -f "$TMP/request.json" ] || fail 'missing request after receipt removal'
assert_request_has_no_ack missing-receipt

printf 'PASS: lightweight recommended confirmation and retry contract\n'
