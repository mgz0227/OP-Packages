#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Regression checks for the r11 follow-up layout adjustment.
set -eu
ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SAFE="$ROOT_DIR/frontend/src/pages/SafeShieldPage.tsx"
RULES="$ROOT_DIR/frontend/src/pages/SafeShieldRulesPage.tsx"
ACCOUNT="$ROOT_DIR/frontend/src/pages/SmartSafeHubAccountPage.tsx"
fail() { echo "FAIL: $*" >&2; exit 1; }

# Shared outside-heading first; buttons remain in the same card as protection state.
grep -Fq 'title="SafeShield 보호 상태"' "$SAFE" || fail 'protection heading is not a shared outside section'
grep -Fq 'class="mb-8 grid min-w-0 gap-4 xl:grid-cols-2 xl:items-start"' "$SAFE" || fail 'spacing below protection section is missing'
grep -Fq 'aria-label="보호 상태 요약"' "$SAFE" || fail 'protection controls card is missing'
grep -Fq 'aria-label="보호 데이터 요약"' "$SAFE" || fail 'protection data card is missing'
grep -Fq 'onClick={handleToggle}' "$SAFE" || fail 'protection toggle missing'
grep -Fq 'onClick={onRefreshBlocklist}' "$SAFE" || fail 'blocklist refresh missing'
grep -Fq 'RefreshProgress data={data}' "$SAFE" || fail 'progress indicator missing'

# Three independently visible summary cards, no tinted tiles floating on page background.
grep -Fq 'title="사용자 도메인 규칙"' "$RULES" || fail 'rules heading missing'
grep -Fq 'grid grid-cols-1 gap-3 sm:grid-cols-3' "$RULES" || fail 'responsive summary cards missing'
for label in '허용 도메인' '차단 도메인' '전체 등록 규칙'; do
  grep -Fq "$label" "$RULES" || fail "summary label missing: $label"
done
if grep -Fq 'rounded-xl bg-emerald-50 px-3 py-3 text-center' "$RULES"; then fail 'old floating stats remain'; fi

# Parent card is the status surface; connected and pairing states avoid a second wrapper.
grep -Fq 'title="기기 계정 연결"' "$ACCOUNT" || fail 'account heading missing'
grep -Fq 'grid items-start gap-5 xl:grid-cols-' "$ACCOUNT" || fail 'account cards should not stretch to leave blank space'
if grep -Fq 'rounded-2xl border border-emerald-200 bg-emerald-50 p-5' "$ACCOUNT"; then fail 'nested connected-state card remains'; fi
if grep -Fq 'mt-6 rounded-2xl border border-slate-200 bg-slate-50 p-4 sm:p-5' "$ACCOUNT"; then fail 'nested pairing-state card remains'; fi
grep -Fq 'SmartSafeHub 계정에 연결됨' "$ACCOUNT" || fail 'connected state missing'
grep -Fq '계정 연결 코드 복사' "$ACCOUNT" || fail 'pairing copy action missing'
echo 'PASS: SafeShield, user rules and account section refinements'
