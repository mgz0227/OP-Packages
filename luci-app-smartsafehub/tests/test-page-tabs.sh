#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
APP="$ROOT_DIR/frontend/src/app/App.tsx"
SETTINGS="$ROOT_DIR/frontend/src/pages/SettingsPage.tsx"
DEMO="$ROOT_DIR/frontend/src/demo/main.tsx"
HOOK="$ROOT_DIR/frontend/src/hooks/usePageTabs.ts"
HASH="$ROOT_DIR/frontend/src/hooks/useHashRoute.ts"
TABS="$ROOT_DIR/frontend/src/components/PageTabs.tsx"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
for file in "$APP" "$SETTINGS" "$DEMO" "$HOOK" "$HASH" "$TABS"; do
  [ -f "$file" ] || fail "missing ${file#$ROOT_DIR/}"
done

grep -Fq "'#network/lan': 'network'" "$HASH" || fail 'LAN deep link must open network route'
grep -Fq "'#settings/time': 'settings'" "$HASH" || fail 'time deep link must open settings route'
grep -Fq "'#settings/management': 'settings'" "$HASH" || fail 'management deep link must open settings route'
grep -Fq "'#wan': 'network'" "$HASH" || fail 'legacy WAN link must work'
grep -Fq "'#lan': 'network'" "$HASH" || fail 'legacy LAN link must work'
grep -Fq "hash === '#lan' || hash === '#network/lan'" "$HOOK" || fail 'legacy LAN link must activate LAN panel'
grep -Fq "return 'diagnostics';" "$HOOK" || fail 'diagnostics must be settings default'
grep -Fq "window.addEventListener('hashchange', onHashChange)" "$HOOK" || fail 'tabs must react to history/back/forward'
grep -Fq 'activeTab={tabs.settings}' "$APP" || fail 'settings tab must be selected from URL'

grep -Fq 'label="설정 메뉴"' "$SETTINGS" || fail 'missing settings tabs'
grep -Fq "{ id: 'diagnostics', label: '진단 및 지원', href: '#settings' }" "$SETTINGS" || fail 'diagnostics must appear as first tab'
grep -Fq "{ id: 'time', label: '시간 및 예약', href: '#settings/time' }" "$SETTINGS" || fail 'time tab must be directly addressable'
grep -Fq "{ id: 'management', label: '관리 및 복구', href: '#settings/management' }" "$SETTINGS" || fail 'management tab must be directly addressable'
grep -Fq "hidden={activeTab !== 'diagnostics'}" "$SETTINGS" || fail 'diagnostics content must be hidden on other tabs'
grep -Fq "hidden={activeTab !== 'time'}" "$SETTINGS" || fail 'time content must be hidden on other tabs'
grep -Fq "hidden={activeTab !== 'management'}" "$SETTINGS" || fail 'management content must be hidden on other tabs'
grep -Fq 'loading && !data' "$SETTINGS" || fail 'diagnostics should handle status loading gracefully'
if grep -Fq '<InfoCard' "$SETTINGS"; then fail 'settings still repeats dashboard system status'; fi

# Keep all existing form components mounted across tab changes: no unmounting
# means unsaved PPPoE, LAN, scheduled reboot and password inputs survive.
grep -Fq "hidden={tabs.network !== 'internet'}" "$APP" || fail 'WAN form must be retained while LAN is selected'
grep -Fq "hidden={tabs.network !== 'lan'}" "$APP" || fail 'LAN form must be retained while WAN is selected'
grep -Fq '<WanPage' "$APP" || fail 'WAN form missing'
grep -Fq '<LanPage' "$APP" || fail 'LAN form missing'
grep -Fq '<TimeSettingsCard' "$SETTINGS" || fail 'time form missing'
grep -Fq '<AdministratorPasswordCard' "$SETTINGS" || fail 'administrator form missing'
grep -Fq 'hidden={tabs.network !==' "$DEMO" || fail 'demo network tabs should mirror router UI'

grep -Fq 'role="tablist"' "$TABS" || fail 'accessible tab list missing'
grep -Fq 'aria-selected={selected}' "$TABS" || fail 'selected tab announcement missing'
grep -Fq 'aria-controls=' "$TABS" || fail 'tab/panel association missing'
grep -Fq "'ArrowLeft', 'ArrowRight', 'Home', 'End'" "$TABS" || fail 'keyboard traversal missing'
grep -Fq 'grid-cols-3' "$TABS" || fail 'mobile-friendly settings tab grid missing'
grep -Fq 'grid w-full min-w-0 gap-2' "$TABS" || fail 'tabs should fill available width on mobile'
grep -Fq 'sm:max-w-[592px]' "$TABS" || fail 'three settings tabs should be capped to 192px each on wider screens'
grep -Fq 'sm:max-w-[392px]' "$TABS" || fail 'two network tabs should be capped to 192px each on wider screens'
grep -Fq 'min-w-0' "$TABS" || fail 'tab layout must avoid mobile overflow'

echo 'PASS: settings/network tabs, direct links, keyboard access, mobile widths and preserved forms'
