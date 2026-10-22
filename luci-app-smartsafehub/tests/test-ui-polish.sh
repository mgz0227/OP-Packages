#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
IPTV="$ROOT/frontend/src/pages/IptvPage.tsx"
DEV="$ROOT/frontend/src/pages/ConnectedDevicesPage.tsx"
SHIELD="$ROOT/frontend/src/pages/SafeShieldPage.tsx"
STATS="$ROOT/frontend/src/components/SafeShieldStatisticsPanel.tsx"
SETTINGS="$ROOT/frontend/src/pages/SettingsPage.tsx"
fail() { echo "FAIL: $*" >&2; exit 1; }

grep -Fq '적용된 IPTV 중계 서비스와 멀티캐스트 전달 상태입니다.' "$IPTV" || fail 'IPTV runtime explanation missing'
grep -Fq 'flex min-w-0 flex-col gap-3 lg:flex-row lg:items-center lg:justify-between' "$DEV" || fail 'device filter/search shared toolbar missing'
grep -Fq 'role="group" aria-label="기기 필터"' "$DEV" || fail 'device filter semantics missing'
grep -Fq 'lg:w-72 lg:shrink-0 xl:w-80' "$DEV" || fail 'search sizing at desktop missing'
grep -Fq 'xl:grid-cols-[minmax(0,1.08fr)_minmax(0,0.92fr)]' "$SHIELD" || fail 'protection-data width ratio missing'
grep -Fq 'action={' "$STATS" || fail 'statistics control must move into section-heading action slot'
grep -Fq 'aria-label={targetEnabled ?' "$STATS" || fail 'statistics collection switch missing'
grep -Fq 'disabled={action !== null}' "$STATS" || fail 'statistics switch busy-state guard removed'
grep -Fq 'titleActions={ ' "$SETTINGS" && fail 'unexpected whitespace near title actions'
grep -Fq 'titleActions={' "$SETTINGS" || fail 'remote reporting badge/switch header missing'
grep -Fq 'reporterMembershipLabel(reporter)' "$SETTINGS" || fail 'remote reporting plan missing'
grep -Fq 'aria-label="원격 상태 보고 사용"' "$SETTINGS" || fail 'remote reporting switch missing'
grep -Fq 'class="grid min-w-0 content-start gap-4"' "$SETTINGS" || fail 'remote/privacy stacked grouping missing'
! grep -Fq '기본값은 꺼짐이며 언제든지 다시 끌 수 있습니다.' "$SETTINGS" || fail 'unneeded default-state text remains'
grep -Fq 'title="개인정보 보호"' "$SETTINGS" || fail 'privacy content missing'
echo 'PASS: four-screen UI polish and control contracts'
