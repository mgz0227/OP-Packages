#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only

ROOT="${1:-.}"
ROOT="$(cd "$ROOT" && pwd)"
OUT="$(mktemp)"
FAILED=0

if ! utpl -S "$ROOT/root/etc/homeproxy/scripts/firewall_post.ut" > "$OUT" 2>"/tmp/hp-fw4tpl.err"; then
	echo "FAIL: could not render firewall_post.ut"
	head -5 "/tmp/hp-fw4tpl.err"
	rm -f "$OUT"
	exit 1
fi

for name in homeproxy_local_addr_v4 homeproxy_wan_proxy_addr_v4; do
	if ! grep -q "^set $name {" "$OUT"; then
		echo "FAIL: 'set $name {' is missing from the rendered firewall template"
		grep -n "$name" "$OUT" | head -2
		FAILED=1
	fi
done

if grep -nE "^#[^!].*homeproxy_[a-z0-9_]+ \{" "$OUT" > "/dev/null"; then
	echo "FAIL: an nft statement is glued onto a comment line"
	grep -nE "^#[^!].*homeproxy_[a-z0-9_]+ \{" "$OUT" | head -2
	FAILED=1
fi

[ "$FAILED" -eq 0 ] && echo "PASS: firewall_post.ut renders homeproxy objects as standalone nft statements"

rm -f "$OUT"
exit $FAILED
