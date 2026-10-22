#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
PAGE="$ROOT_DIR/frontend/src/pages/ActivityPage.tsx"
fail() { echo "FAIL: $*" >&2; exit 1; }

# Cloud controls must precede the arbitrarily long local event stream.
cloud_line=$(grep -n 'id="activity-cloud-title"' "$PAGE" | head -n 1 | cut -d: -f1)
history_line=$(grep -n 'id="activity-history-title"' "$PAGE" | head -n 1 | cut -d: -f1)
[ -n "$cloud_line" ] && [ -n "$history_line" ] && [ "$cloud_line" -lt "$history_line" ] ||   fail 'Cloud preferences must be above the local activity timeline'

# The toggle and its ineligibility/error messaging must remain visible while details are closed.
switch_line=$(grep -n 'aria-label="Cloud 활동 기록 전송 사용"' "$PAGE" | head -n 1 | cut -d: -f1)
details_line=$(grep -n '<details class=' "$PAGE" | head -n 1 | cut -d: -f1)
[ -n "$switch_line" ] && [ -n "$details_line" ] && [ "$switch_line" -lt "$details_line" ] ||   fail 'Cloud setting must stay outside the collapsible details'
grep -Fq 'disabled={saving || !canToggle}' "$PAGE" || fail 'Cloud toggle must respect eligibility and pending requests'
grep -Fq 'role="switch"' "$PAGE" || fail 'Cloud switch accessibility semantics removed'
grep -Fq 'actionError || actionMessage' "$PAGE" || fail 'Cloud save feedback must remain visible'
grep -Fq 'Cloud 전송을 끄면 아직 전송하지 않은 대기 기록이 삭제됩니다.' "$PAGE" || fail 'Turning off Cloud upload must disclose the pending-event deletion before toggling'
grep -Fq 'cloud.lastErrorCode' "$PAGE" || fail 'Cloud sync failures must remain visible'
grep -Fq 'Cloud 동기화 상세 정보' "$PAGE" || fail 'Collapsible Cloud details missing'
grep -Fq 'SmartSafeHub 계정에 연결된 Free는 최근 7일' "$PAGE" || fail 'Cloud retention explanation missing'

# Data loading and pagination affect presentation only; the RPC still returns up to 128 records.
grep -Fq 'const [visibleCount, setVisibleCount] = useState(20);' "$PAGE" || fail 'Activity page must initially show 20 events'
grep -Fq 'const visibleEvents = events.slice(0, visibleCount);' "$PAGE" || fail 'Activity list must use display-only slicing'
grep -Fq '<ActivityTimeline events={visibleEvents} />' "$PAGE" || fail 'Paginated events must drive the timeline'
grep -Fq 'Math.min(current + 20, events.length)' "$PAGE" || fail 'More button must advance by 20 without exceeding the available data'
grep -Fq 'onClick={() => setVisibleCount(20)}' "$PAGE" || fail 'Expanded list must be collapsible again'
grep -Fq '이전 활동 더 보기' "$PAGE" || fail 'Older activities must be discoverable'
grep -Fq '재부팅하면 초기화됩니다' "$PAGE" || fail 'Local retention disclaimer must remain'

echo 'PASS: Cloud-first recent activity and incremental local history contracts'
