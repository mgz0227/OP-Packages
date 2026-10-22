#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
DEMO="$ROOT/frontend/src/demo/main.tsx"
FIXTURES="$ROOT/frontend/src/demo/data.ts"
CONFIG="$ROOT/frontend/vite.demo.config.ts"

for path in "$DEMO" "$FIXTURES" "$CONFIG"; do
  [ -f "$path" ] || { echo "missing demo source: $path" >&2; exit 1; }
done

grep -Fq "<HomePage" "$DEMO"
grep -Fq "<SafeShieldPage" "$DEMO"
grep -Fq "<ConnectedDevicesPage" "$DEMO"
for page in ActivityPage WanPage LanPage WifiPage SafeShieldRulesPage UpdatePage; do
  grep -Fq "<$page" "$DEMO"
done
grep -Fq "demo={demo}" "$ROOT/frontend/src/components/AppShell.tsx"
grep -Fq "!demo ?" "$ROOT/frontend/src/components/ProductNavigation.tsx"
grep -Fq "base: '/static/router-demo/'" "$CONFIG"

# No fake bootstrap or real RPC in the public demo entry.
if grep -Eq 'callApi|callRpc|fetch\(|probeLuciSession|__SMARTHUB_BOOTSTRAP__|/cgi-bin/' "$DEMO" "$FIXTURES"; then
  echo 'Public demo must not call any router APIs' >&2
  exit 1
fi

# Keep the Node.js test runner output out of ShellSpec stdout on success.
# Preserve its full diagnostics on stderr if any runtime contract fails.
node_test_log="$(mktemp)"
trap 'rm -f "$node_test_log"' 0
if ! node --test "$ROOT/tests/runtime/router-demo.test.mjs" >"$node_test_log" 2>&1; then
  cat "$node_test_log" >&2
  exit 1
fi

# The Hub consumes a committed, separately built bundle. New developers build
# it locally, then commit the output; this test does not generate build files.
if grep -q '^frontend/demo-dist/$' "$ROOT/.gitignore"; then
  echo 'Demo build output must be committed, not ignored' >&2
  exit 1
fi
grep -Fq 'Build standalone router demo' "$ROOT/.github/workflows/ci.yml"
grep -Fq 'Validate committed router demo assets' "$ROOT/.github/workflows/ci.yml"

printf "%s\n" "PASS: router demo contract"
