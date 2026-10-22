#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
PAGE="$ROOT_DIR/frontend/src/pages/SafeShieldRulesPage.tsx"

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

grep -Fq 'border-2 border-slate-300 bg-slate-50 px-4' "$PAGE" || \
	fail 'new-domain inputs must use the emphasized text-input surface'

grep -Fq 'shadow-inner' "$PAGE" || \
	fail 'rules inputs must retain inset affordance'

grep -Fq 'absolute inset-y-0 left-0 flex w-11 items-center justify-center' "$PAGE" || \
	fail 'search icon must use a vertically centered flex wrapper'

grep -Fq 'pl-11' "$PAGE" || \
	fail 'search input must reserve space for the centered icon'

if grep -Fq 'absolute top-1/2 left-3.5 size-4 -translate-y-1/2' "$PAGE"; then
	fail 'search icon must not use transform-based vertical positioning'
fi

# The add form must clear after the rules API confirms persistence, not
# after the slower SafeShield local DNS apply has completed (up to 45 s).
HOOK="$ROOT_DIR/frontend/src/hooks/useSafeShieldRules.ts"
grep -Fq 'onPersisted?.();' "$HOOK" || \
  fail 'persisted rule must notify the form before DNS apply finishes'
grep -Fq "mutate('add', action, domain, onPersisted)" "$HOOK" || \
  fail 'addRule must forward the persistence callback'
grep -Fq 'await onAddRule(kind, domain, () => {' "$PAGE" || \
  fail 'rule form must clear from persistence callback, not final DNS result'
grep -Fq "setInput((current) => normalizeDomain(current) === domain ? '' : current)" "$PAGE" || \
  fail 'successful saves must clear only the submitted value'
if grep -Fq 'if (saved)' "$PAGE"; then
  fail 'input must not wait for final DNS apply before clearing'
fi
# Verify acknowledgement is after the API call and before DNS verification.
if ! awk '
  /await addSafeShieldRule\(action, domain, true\)/ { api = NR }
  /onPersisted\?\.\(\)/ { acknowledged = NR }
  /outcome = await waitForLocalApply\(baseline\)/ { applied = NR }
  END { exit !(api > 0 && acknowledged > api && applied > acknowledged) }
' "$HOOK"; then
  fail 'save acknowledgement must happen after API success but before DNS apply'
fi

grep -Fq 'const latestMutationId = useRef(0);' "$HOOK" || \
  fail 'DNS polling must track the newest mutation when users add another rule'
grep -Fq 'if (latestMutationId.current === mutationId)' "$HOOK" || \
  fail 'an earlier DNS result must not overwrite newer save feedback'
grep -Fq 'DNS 적용 상태를 확인하지 못했습니다.' "$HOOK" || \
  fail 'DNS status lookup failure must be reported separately from save failure'

# Both add and delete keep their DNS result reporting; only add clears a draft.
grep -Fq 'onDeleteRule(kind, domain)' "$PAGE" || \
  fail 'delete action must continue to work independently of form clearing'

# Theme-aware group headers must not leak a light teal background in dark mode.
grep -Fq 'ssh-rule-group-toggle bg-slate-50' "$PAGE" || fail 'both rule groups must use the theme-aware slate surface'
if grep -Fq 'bg-teal-50/60' "$PAGE"; then
  fail 'semi-transparent light rule group background bypasses the dark theme mapping'
fi
grep -Fq ".ssh-app[data-theme='dark'] .ssh-rule-group-toggle:hover" "$ROOT_DIR/frontend/src/styles/app.css" || \
  fail 'hovered rule headers must remain dark in the dark theme'

echo 'PASS: SafeShield rules input, persistence and DNS apply contracts are present'
