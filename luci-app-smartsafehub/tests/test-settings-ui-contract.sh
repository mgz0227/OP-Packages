#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
APP="$ROOT_DIR/frontend/src/app/App.tsx"
ROUTES="$ROOT_DIR/frontend/src/app/routes.ts"
SETTINGS_PAGE="$ROOT_DIR/frontend/src/pages/SettingsPage.tsx"
APP_STYLES="$ROOT_DIR/frontend/src/styles/app.css"
UPDATE_PAGE="$ROOT_DIR/frontend/src/pages/UpdatePage.tsx"
NAVIGATION="$ROOT_DIR/frontend/src/components/ProductNavigation.tsx"
TIME_HOOK="$ROOT_DIR/frontend/src/hooks/useSystemTimeSettings.ts"
SCHEDULE_HOOK="$ROOT_DIR/frontend/src/hooks/useScheduledRebootSettings.ts"
BACKUP_HOOK="$ROOT_DIR/frontend/src/hooks/useConfigurationBackup.ts"
BACKUP_API="$ROOT_DIR/frontend/src/api/configurationBackup.ts"
HEALTH_HOOK="$ROOT_DIR/frontend/src/hooks/useHealth.ts"

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

for file in "$APP" "$ROUTES" "$SETTINGS_PAGE" "$APP_STYLES" "$UPDATE_PAGE" "$NAVIGATION" "$TIME_HOOK" "$SCHEDULE_HOOK" "$BACKUP_HOOK" "$BACKUP_API" "$HEALTH_HOOK"; do
	[ -f "$file" ] || fail "missing settings split source: ${file#$ROOT_DIR/}"
done

grep -Fq "const status = useStatus(route === 'home' || route === 'settings');" "$APP" || \
	fail 'system status polling must remain active on settings'
grep -Fq "const systemTime = useSystemTimeSettings(route === 'settings');" "$APP" || \
	fail 'settings route must load dedicated timezone settings'
grep -Fq "const scheduledReboot = useScheduledRebootSettings(route === 'settings');" "$APP" || \
	fail 'settings route must load scheduled reboot settings'
grep -Fq 'const firmware = useFirmwareUpdates(true);' "$APP" || \
	fail 'settings route must share the globally active SmartSafeHub firmware state used by update notifications'
grep -Fq 'activeTab={tabs.settings}' "$APP" || \
	fail 'settings must receive its selected tab'
grep -Fq 'const configurationBackup = useConfigurationBackup();' "$APP" || \
	fail 'settings route must wire configuration backup and restore actions'
grep -Fq "case 'system':" "$APP" || fail 'update route must remain registered in App'
grep -Fq '<UpdatePage' "$APP" || fail 'system/update route must render UpdatePage'
grep -Fq "case 'settings':" "$APP" || fail 'settings route must be registered in App'
grep -Fq '<SettingsPage' "$APP" || fail 'settings route must render SettingsPage'
grep -Fq "if (route === 'system')" "$APP" || fail 'update refresh branch must exist'
grep -Fq 'void Promise.all([updates.refresh(), firmware.refresh()]);' "$APP" || fail 'update refresh must refresh software and firmware updater state together'
grep -Fq "if (route === 'settings')" "$APP" || fail 'settings refresh branch must exist'
grep -Fq 'scheduledReboot.refresh(),' "$APP" || \
	fail 'settings refresh must refresh scheduled reboot settings together with system/time state'
grep -Fq 'firmware.refresh(),' "$APP" || \
	fail 'settings refresh must refresh firmware identity together with system state'

grep -Fq "label: '설정'" "$ROUTES" || fail 'settings route must be visible in product navigation'
grep -Fq "description: '기기의 펌웨어와 관리 소프트웨어 업데이트를 관리합니다.'" "$ROUTES" || \
	fail 'update route description must remain update-only'
grep -Fq "description: '시스템 상태와 시간대를 확인하고 장치 관리 및 진단 기능을 설정합니다.'" "$ROUTES" || \
	fail 'settings route description must describe timezone and device management'

if grep -Fq 'title="업데이트 관리"' "$SETTINGS_PAGE"; then
	fail 'settings page must not duplicate the dedicated update-page navigation card'
fi
if grep -Fq 'href="#system"' "$SETTINGS_PAGE"; then
	fail 'settings page must not retain a redundant update-page shortcut'
fi
grep -Fq 'title="시간 및 시간대"' "$SETTINGS_PAGE" || \
	fail 'settings page must expose time and timezone controls'
grep -Fq "'지금 동기화'" "$SETTINGS_PAGE" || \
	fail 'settings page must expose immediate NTP synchronization'
grep -Fq 'title="장치 진단"' "$SETTINGS_PAGE" || \
	fail 'diagnostic download must remain in its own card'
grep -Fq '원격 상태 보고' "$SETTINGS_PAGE" || \
	fail 'settings diagnostics must expose paid/trial remote health reporting'
grep -Fq '장치의 최소 상태 정보와 이상 코드만 서버로 전송합니다.' "$SETTINGS_PAGE" || \
	fail 'remote health reporting must explain the information transmitted'
grep -Fq '직접 켜고 언제든지 끌 수 있습니다.' "$SETTINGS_PAGE" || \
	fail 'remote health reporting must explain explicit opt-in and opt-out without default-state copy'
! grep -Fq '기본값은 꺼짐이며 언제든지 다시 끌 수 있습니다.' "$SETTINGS_PAGE" || \
	fail 'remote health reporting must not repeat unnecessary default-state copy'
grep -Fq '개인정보 보호' "$SETTINGS_PAGE" || \
	fail 'remote health reporting must expose a recognizable privacy section'
grep -Fq '진단에 필요한 최소한의 상태 정보만 전송하며, 네트워크 식별 정보와 이용 내용은 보내지 않습니다.' "$SETTINGS_PAGE" || \
	fail 'remote health reporting must summarize its data-minimization policy'
grep -Fq '기기 상태 수치' "$SETTINGS_PAGE" || \
	fail 'remote health reporting must group transmitted device metrics'
grep -Fq '메모리 · 부하 · 저장 공간' "$SETTINGS_PAGE" || \
	fail 'remote health reporting must list transmitted device metrics clearly'
grep -Fq '개인 식별 · 네트워크 정보' "$SETTINGS_PAGE" || \
	fail 'remote health reporting must group excluded network identifiers'
grep -Fq '호스트명 · WAN IP · Wi-Fi SSID/MAC' "$SETTINGS_PAGE" || \
	fail 'remote health reporting must list excluded network identifiers clearly'
grep -Fq '이용 내용 및 원문 데이터' "$SETTINGS_PAGE" || \
	fail 'remote health reporting must group excluded request and log contents'
grep -Fq 'DNS 요청 내용 · 시스템 로그 원문' "$SETTINGS_PAGE" || \
	fail 'remote health reporting must list excluded content and raw logs clearly'
grep -Fq 'border border-teal-200 bg-teal-50 p-3.5' "$SETTINGS_PAGE" || \
	fail 'non-transmitted information must use a distinct privacy surface'
grep -Fq ".ssh-app[data-theme='dark'] [class~='bg-teal-50']" "$APP_STYLES" || \
	fail 'privacy emphasis surface must retain a dark-theme background mapping'
grep -Fq "[class~='border-teal-200']" "$APP_STYLES" || \
	fail 'privacy emphasis border must retain a dark-theme mapping'
grep -Fq "[class~='text-teal-800']" "$APP_STYLES" || \
	fail 'privacy emphasis text must retain dark-theme contrast'
grep -Fq "const health = useHealth(route === 'home' || route === 'settings');" "$APP" || \
	fail '설정 페이지와 대시보드가 같은 로컬 Health 리소스를 불러와야 합니다'
grep -Fq 'title="설정 백업 및 복원"' "$SETTINGS_PAGE" || \
	fail 'settings page must expose first-class configuration backup and restore management'
grep -Fq '설정 백업 다운로드' "$SETTINGS_PAGE" || \
	fail 'settings page must expose native configuration backup download'
grep -Fq '업로드 및 검증' "$SETTINGS_PAGE" || \
	fail 'restore flow must upload and validate an archive before confirmation'
grep -Fq '설정 복원 및 재부팅' "$SETTINGS_PAGE" || \
	fail 'restore flow must clearly communicate the reboot side effect'
grep -Fq 'Wi-Fi 비밀번호, 관리자 설정, VPN 키나 기기 인증 정보' "$SETTINGS_PAGE" || \
	fail 'backup UI must warn that preserved configuration can contain secrets'
grep -Fq 'function ScheduledRebootSection(props:' "$SETTINGS_PAGE" || \
	fail 'settings page must expose scheduled reboot management as an embedded section'
grep -Fq 'aria-labelledby="scheduled-reboot-heading"' "$SETTINGS_PAGE" || \
	fail 'scheduled reboot section must expose an accessible section label'
if ! sed -n '/^function TimeSettingsCard/,/^function healthTone/p' "$SETTINGS_PAGE" | grep -F '<ScheduledRebootSection' >/dev/null; then
	fail 'scheduled reboot controls must be grouped inside the time and timezone card'
fi
grep -Fq 'scheduledRebootData={scheduledRebootData}' "$SETTINGS_PAGE" || \
	fail 'time settings card must receive scheduled reboot state'
if grep -Fq '<ScheduledRebootCard' "$SETTINGS_PAGE"; then
	fail 'scheduled reboot must not remain as a standalone system-management card'
fi
grep -Fq ".ssh-app[data-theme='dark'] [class~='bg-slate-50']" "$APP_STYLES" || \
	fail 'scheduled reboot inset background must retain a dark-theme mapping'
grep -Fq ".ssh-app[data-theme='dark'] [class~='bg-slate-100']" "$APP_STYLES" || \
	fail 'scheduled reboot section icon background must retain a dark-theme mapping'
grep -Fq "[class~='border-slate-200']" "$APP_STYLES" || \
	fail 'scheduled reboot divider must retain a dark-theme border mapping'
grep -Fq "[class~='text-slate-500']" "$APP_STYLES" || \
	fail 'scheduled reboot secondary text must retain dark-theme contrast mapping'
grep -Fq '저장되지 않음' "$SETTINGS_PAGE" || \
	fail 'scheduled reboot must visibly mark unsaved local changes'
grep -Fq 'role="status"' "$SETTINGS_PAGE" || \
	fail 'scheduled reboot unsaved marker must expose status semantics'
grep -Fq 'aria-live="polite"' "$SETTINGS_PAGE" || \
	fail 'scheduled reboot unsaved marker must announce state changes without interrupting the user'
grep -Fq 'border-amber-200 bg-amber-50' "$SETTINGS_PAGE" || \
	fail 'scheduled reboot unsaved marker must use warning styling rather than error styling'
grep -Fq ".ssh-app[data-theme='dark'] [class~='bg-amber-50']" "$APP_STYLES" || \
	fail 'scheduled reboot unsaved marker background must retain a dark-theme mapping'
grep -Fq "[class~='text-amber-800']" "$APP_STYLES" || \
	fail 'scheduled reboot unsaved marker text must retain dark-theme contrast mapping'
grep -Fq 'function SystemToolsCard(props:' "$SETTINGS_PAGE" || \
	fail 'reboot and advanced actions must be grouped into one compact system tools card'
grep -Fq 'title="시스템 도구"' "$SETTINGS_PAGE" || \
	fail 'system management must expose the combined system tools card'
grep -Fq 'aria-labelledby="router-reboot-heading"' "$SETTINGS_PAGE" || \
	fail 'router reboot must remain an accessible first-class action inside system tools'
grep -Fq 'id="advanced-tools-heading"' "$SETTINGS_PAGE" || \
	fail 'advanced tools must remain clearly labeled inside system tools'
grep -Fq '고급 도구' "$SETTINGS_PAGE" || \
	fail 'advanced LuCI and log actions must remain visible inside system tools'
if grep -Fq 'title="공유기 재부팅"' "$SETTINGS_PAGE"; then
	fail 'router reboot must not remain as a separate full ActionCard'
fi
if grep -Fq 'title="고급 설정"' "$SETTINGS_PAGE"; then
	fail 'advanced settings must not remain as a separate full ActionCard'
fi
grep -Fq "luciAdminUrl('/admin/system')" "$SETTINGS_PAGE" || \
	fail 'SettingsPage must retain the LuCI advanced-settings fallback'
grep -Fq 'LuCI 고급 설정 열기' "$SETTINGS_PAGE" || \
	fail 'LuCI fallback must be explicitly presented as an advanced action'
grep -Fq 'SmartSafeHub에서 아직 제공하지 않는 상세 시스템 설정이나 원본 로그' "$SETTINGS_PAGE" || \
	fail 'settings page must explain why LuCI fallback still exists'
if grep -Fq '설정 백업·복원 등 아직 SmartSafeHub에서 제공하지 않는' "$SETTINGS_PAGE"; then
	fail 'settings page must not send backup and restore users back to stock LuCI'
fi
if grep -Fq "luciAdminUrl('/admin/system/flash')" "$SETTINGS_PAGE"; then
	fail 'settings page must not send firmware upgrades to the stock LuCI flash page'
fi
if grep -Fq '고급 설정' "$NAVIGATION"; then
	fail 'navigation chrome must not keep the old standalone advanced-settings menu'
fi
if grep -Fq 'SoftwareUpdatesCard' "$SETTINGS_PAGE"; then
	fail 'settings page must not embed the software update experience'
fi

if grep -Fq 'label="Firmware"' "$SETTINGS_PAGE"; then
	fail 'settings must not duplicate dashboard firmware/memory/load summary cards'
fi
grep -Fq 'id="diagnostics-panel"' "$SETTINGS_PAGE" || fail 'diagnostics must have its own panel'
grep -Fq 'id="time-panel"' "$SETTINGS_PAGE" || fail 'time and scheduled reboot must have their own panel'
grep -Fq 'id="management-panel"' "$SETTINGS_PAGE" || fail 'management must have its own panel'
grep -Fq 'Device settings' "$SETTINGS_PAGE" || \
	fail 'settings page must visually separate device settings from system management'
grep -Fq '시간 기준과 예약 재부팅을 SmartSafeHub에서 직접 관리합니다.' "$SETTINGS_PAGE" || \
	fail 'device settings description must include scheduled reboot after regrouping'
grep -Fq 'System management' "$SETTINGS_PAGE" || \
	fail 'settings page must retain a dedicated system management section'
grep -Fq 'grid min-w-0 grid-cols-1 gap-4 lg:grid-cols-2' "$SETTINGS_PAGE" || \
	fail 'settings action groups must use responsive two-column layout on desktop'
grep -Fq 'title="관리자 비밀번호"' "$SETTINGS_PAGE" || \
	fail 'system management must expose administrator password management as a first-class card'
if sed -n '/^function ConfigurationBackupCard/,/^function SystemToolsCard/p' "$SETTINGS_PAGE" | grep -F 'className="lg:col-span-2"' >/dev/null; then
	fail 'configuration backup must share the first desktop row with administrator password management'
fi
sed -n '/^function ConfigurationBackupCard/,/^function SystemToolsCard/p' "$SETTINGS_PAGE" | grep -F 'grid min-w-0 grid-cols-1 gap-3' >/dev/null || \
	fail 'configuration backup internals must use a compact vertical layout at half-row width'
grep -Fq '<SystemToolsCard' "$SETTINGS_PAGE" || \
	fail 'system management must retain the combined system tools card'
grep -Fq 'className="lg:col-span-2"' "$SETTINGS_PAGE" || \
	fail 'system tools must span the full desktop row below administrator password and backup cards'
if grep -Fq 'className={props.className}' "$SETTINGS_PAGE"; then
	fail 'optional ActionCard className must not pass explicit undefined with exactOptionalPropertyTypes'
fi
grep -Fq '{...(props.className !== undefined ? { className: props.className } : {})}' "$SETTINGS_PAGE" || \
	fail 'system tools must omit the optional ActionCard className prop when it is undefined'

grep -Fq "const BACKUP_DOWNLOAD_ENDPOINT = '/cgi-backup';" "$BACKUP_API" || \
	fail 'backup downloads must use the authenticated cgi-backup endpoint'
grep -Fq "const BACKUP_UPLOAD_PATH = '/tmp/smartsafehub/config-backup.tar.gz';" "$BACKUP_API" || \
	fail 'restore uploads must target the dedicated temporary archive path'
grep -Fq 'await requestConfigurationBackupValidation(file.name);' "$BACKUP_HOOK" || \
	fail 'uploaded backups must be validated by the backend before restore is enabled'
grep -Fq 'if (!validated)' "$BACKUP_HOOK" || \
	fail 'restore hook must reject attempts without a validated archive'

# Consistent, responsive three-tab UI (the health and time cards share the existing grid geometry).
grep -Fq 'title="장치 진단"' "$SETTINGS_PAGE" || fail 'local diagnostics must have their own card'
grep -Fq 'title="원격 상태 보고"' "$SETTINGS_PAGE" || fail 'remote health reporting must have its own card'
grep -Fq 'headerActions?: ComponentChildren;' "$SETTINGS_PAGE" || \
  fail 'ActionCard must offer an independent right-aligned header control slot'
grep -Fq 'justify-between gap-3' "$SETTINGS_PAGE" || \
  fail 'ActionCard header must push the remote-report switch to the right edge'
grep -Fq '{props.headerActions ? <div class="shrink-0">{props.headerActions}</div> : null}' "$SETTINGS_PAGE" || \
  fail 'Remote reporting switch must use a right-aligned action area'
# Membership remains attached to the title, but the switch is a separate header action.
reporter_header=$(sed -n '/title="원격 상태 보고"/,/^    >/p' "$SETTINGS_PAGE")
printf '%s\n' "$reporter_header" | grep -Fq 'titleActions={' || fail 'Remote-report PRO badge must remain adjacent to its title'
printf '%s\n' "$reporter_header" | grep -Fq 'headerActions={' || fail 'Remote-report switch must use a distinct header action slot'
printf '%s\n' "$reporter_header" | grep -Fq 'aria-label="원격 상태 보고 사용"' || fail 'Remote-report switch semantics must remain intact'
grep -Fq 'title="개인정보 보호"' "$SETTINGS_PAGE" || fail 'privacy policy must have its own card'
grep -Fq 'class="grid min-w-0 content-start gap-4"' "$SETTINGS_PAGE" || fail 'privacy policy must sit directly below remote health reporting'
if grep -Fq 'max-w-4xl' "$SETTINGS_PAGE"; then
  fail 'settings time tab must use the common content width'
fi
[ "$(grep -Fc 'grid min-w-0 grid-cols-1 gap-4 lg:grid-cols-2' "$SETTINGS_PAGE")" -ge 3 ] || \
  fail 'diagnostics, time and management must use the same responsive two-column grid'
grep -Fq 'ssh-password-input' "$SETTINGS_PAGE" || fail 'password fields must include dedicated autofill styling'
grep -Fq ".ssh-app[data-theme='dark'] .ssh-password-input:-webkit-autofill" "$APP_STYLES" || \
  fail 'dark theme must normalize browser password autofill background'

echo 'PASS: settings page keeps backup/restore, timezone and device management with safe system controls'
