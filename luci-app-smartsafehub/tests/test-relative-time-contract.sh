#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
COMPONENT="$ROOT/frontend/src/components/RelativeTimestamp.tsx"
FORMAT="$ROOT/frontend/src/app/format.ts"
FIRMWARE="$ROOT/frontend/src/components/FirmwareUpdatesCard.tsx"
SOFTWARE="$ROOT/frontend/src/components/SoftwareUpdatesCard.tsx"
SAFE="$ROOT/frontend/src/pages/SafeShieldPage.tsx"
RULES="$ROOT/frontend/src/pages/SafeShieldRulesPage.tsx"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
for file in "$COMPONENT" "$FORMAT" "$FIRMWARE" "$SOFTWARE" "$SAFE" "$RULES" "$ROOT/tests/runtime/relative-time.test.mjs"; do
  [ -f "$file" ] || fail "상대 시간 소스가 없습니다: $file"
done

grep -Fq 'formatRecentTimestamp(timestamp, nowTimestamp)' "$COMPONENT" || fail '공통 경과 시간 계산이 필요합니다'
grep -Fq 'window.setInterval(' "$COMPONENT" || fail '시간이 지나면 화면을 갱신해야 합니다'
grep -Fq '60_000' "$COMPONENT" || fail '1분 주기로 갱신해야 합니다'
grep -Fq 'window.clearInterval(timer)' "$COMPONENT" || fail '페이지 이탈 시 타이머를 정리해야 합니다'
grep -Fq 'dateTime={new Date(timestamp * 1000).toISOString()}' "$COMPONENT" || fail '표준 time 요소에 정확한 시각이 필요합니다'
grep -Fq 'aria-label="정확한 날짜 및 시간 확인"' "$COMPONENT" || fail '모바일/키보드에서도 정확한 시각을 확인해야 합니다'
grep -Fq 'group-open:inline-block' "$COMPONENT" || fail '클릭 시 날짜와 시각을 보여줘야 합니다'
grep -Fq 'nowTimestamp - timestamp >= 7 * 86_400' "$FORMAT" || fail '7일 이상 지난 시간은 날짜로 표시해야 합니다'
grep -Fq '<RelativeTimestamp fallback="아직 없음" timestamp={data.lastCheckAt} />' "$FIRMWARE" || fail '펌웨어 마지막 확인 경과 시간을 표시해야 합니다'
grep -Fq '<RelativeTimestamp fallback="아직 없음" timestamp={data.lastCheckAt} />' "$SOFTWARE" || fail '소프트웨어 마지막 확인 경과 시간을 표시해야 합니다'
grep -Fq '<SummaryFact label="Last refresh" value={<RelativeTimestamp timestamp={data.timestamps.lastSuccess} />} />' "$SAFE" || fail 'SafeShield 마지막 갱신 경과 시간을 표시해야 합니다'
grep -Fq 'parseArtifactVersionTimestamp(version)' "$SAFE" || fail '보호 데이터 버전의 UTC 시각을 파싱해야 합니다'
grep -Fq '<RelativeTimestamp timestamp={timestamp} />' "$SAFE" || fail '보호 데이터 마지막 업데이트를 경과 시간으로 표시해야 합니다'
grep -Fq 'label="다음 갱신" value={formatTimestamp(data.timestamps.nextRefreshAt)}' "$SAFE" || fail '다음 갱신 예정 시각은 절대 시간으로 유지해야 합니다'
grep -Fq '<RelativeTimestamp timestamp={recommendedStatus.lastCheckedAt} />' "$RULES" || fail '추천 규칙의 최근 확인은 상대 시간으로 표시해야 합니다'
if grep -Fq 'new Date(recommendedStatus.lastCheckedAt * 1000).toLocaleString' "$RULES"; then
  fail '추천 규칙 최근 확인에 절대 시각을 직접 표시해서는 안 됩니다'
fi

printf 'PASS: relative time presentation contract\n'
