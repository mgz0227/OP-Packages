#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only

ROOT="${1:-.}"
WORK="${2:-/tmp/hp-generator-test}"

ROOT="$(cd "$ROOT" && pwd)"
FAILED=0

run_case() {
	name="$1"
	fixture="$2"
	generator="$3"
	outfile="$4"
	local_rs="$5"
	dir="$WORK/$name"

	rm -rf "$dir"
	mkdir -p "$dir/config" "$dir/run" "$dir/scripts" "$dir/resources" "$dir/ruleset"
	: > "$dir/resources/direct_list.txt"
	: > "$dir/resources/proxy_list.txt"

	if [ "$local_rs" = "1" ]; then
		printf '%s' '{"version":1,"rules":[{"domain_suffix":["example.com"]}]}' > "$dir/rs-src.json"
		if ! sing-box rule-set compile "$dir/rs-src.json" -o "$dir/resources/geoip_cn.srs" \
			|| ! sing-box rule-set compile "$dir/rs-src.json" -o "$dir/resources/geosite_cn.srs"; then
			echo "FAIL: $name: could not compile the local rule-set fixture"
			FAILED=1
			return
		fi
	fi

	if grep -q "__RULESET_DIR__" "$fixture"; then
		printf '%s' '{"version":1,"rules":[{"domain_suffix":["example.com"]}]}' > "$dir/ruleset/src.json"
		if ! sing-box rule-set compile "$dir/ruleset/src.json" -o "$dir/ruleset/test.srs"; then
			echo "FAIL: $name: could not compile the local rule-set fixture"
			FAILED=1
			return
		fi
		sed "s#__RULESET_DIR__#$dir/ruleset#" "$fixture" > "$dir/config/homeproxy"
	else
		cp "$fixture" "$dir/config/homeproxy"
	fi

	sed -e "s#^export const HP_DIR = '/etc/homeproxy';#export const HP_DIR = '$dir';#" \
	    -e "s#^export const RUN_DIR = '/var/run/homeproxy';#export const RUN_DIR = '$dir/run';#" \
	    "$ROOT/root/etc/homeproxy/scripts/homeproxy.uc" > "$dir/scripts/homeproxy.uc"

	sed -e "s#const uci = cursor();#const uci = cursor('$dir/config');#" \
	    "$ROOT/root/etc/homeproxy/scripts/$generator" > "$dir/scripts/$generator"

	if ! ( cd "$dir/scripts" && ucode "$generator" ); then
		echo "FAIL: $name: $generator exited non-zero"
		FAILED=1
		return
	fi

	if [ ! -f "$dir/run/$outfile" ]; then
		echo "FAIL: $name: $outfile was not generated"
		FAILED=1
		return
	fi

	if ! sing-box check --config "$dir/run/$outfile"; then
		echo "FAIL: $name: sing-box rejected the generated $outfile"
		FAILED=1
		return
	fi

	echo "PASS: $name ($(wc -c < "$dir/run/$outfile") bytes)"
}

run_case client "$ROOT/tests/fixtures/generators/client.uci" generate_client.uc sing-box-c.json

CLIENT_GOLDEN="$ROOT/tests/snapshots/client.generated.json"
CLIENT_OUT="$WORK/client/run/sing-box-c.json"
if [ ! -f "$CLIENT_GOLDEN" ]; then
	echo "FAIL: client: golden snapshot $CLIENT_GOLDEN is missing"
	FAILED=1
elif sed "s#$WORK/client#__WORKDIR__#g" "$CLIENT_OUT" > "$WORK/client/normalized.json" \
	&& cmp -s "$CLIENT_GOLDEN" "$WORK/client/normalized.json"; then
	echo "PASS: client generator matches the golden snapshot"
else
	echo "FAIL: client generator output differs from the golden snapshot (normalized output: $WORK/client/normalized.json)"
	if command -v diff > "/dev/null" 2>&1; then
		diff -u "$CLIENT_GOLDEN" "$WORK/client/normalized.json" | head -40
	fi
	FAILED=1
fi

if grep -q '"detour": "direct-out"' "$WORK/client/run/sing-box-c.json"; then
	echo "FAIL: client: a remote rule-set would still be downloaded directly"
	FAILED=1
fi
if ! grep -q '"detour": "main-out"' "$WORK/client/run/sing-box-c.json"; then
	echo "FAIL: client: no remote rule-set is configured to download through main-out"
	FAILED=1
fi

run_case client-local "$ROOT/tests/fixtures/generators/client.uci" generate_client.uc sing-box-c.json 1
if grep -q '"type": "local"' "$WORK/client-local/run/sing-box-c.json" \
	&& ! grep -q '"type": "remote"' "$WORK/client-local/run/sing-box-c.json"; then
	echo "PASS: client-local uses the local rule-sets"
else
	echo "FAIL: client-local did not switch the preset rule-sets to local files"
	FAILED=1
fi

run_case custom "$ROOT/tests/fixtures/generators/custom.uci" generate_client.uc sing-box-c.json
run_case custom_no_default "$ROOT/tests/fixtures/generators/custom-no-default-outbound.uci" generate_client.uc sing-box-c.json

CUSTOM_OUT="$WORK/custom_no_default/run/sing-box-c.json"

assert_json() {
	label="$1"
	pattern="$2"
	if grep -q -- "$pattern" "$CUSTOM_OUT"; then
		echo "PASS: $label"
	else
		echo "FAIL: $label (no match for: $pattern)"
		FAILED=1
	fi
}

assert_json "custom/no-default: a global domain resolver is declared" '"default_domain_resolver"'
assert_json "custom/no-default: the user DNS server survived" '"cfg-DNS_Server_Proxy-dns"'
assert_json "custom/no-default: the user DNS rule survived" 'dns-rule-marker.example.com'
assert_json "custom/no-default: the urltest group survived" '"cfg-Routing_Node_Proxy-out"'
assert_json "custom/no-default: its member nodes survived" '"cfg-n_hk-out"'
assert_json "custom/no-default: the user rule-set survived" '"cfg-rs_cn-rule"'
assert_json "custom/no-default: the user routing rule survived" 'routing-rule-marker.example.com'
assert_json "custom/no-default: dns.final follows default_server" '"final": "default-dns"'

run_case server "$ROOT/tests/fixtures/generators/server.uci" generate_server.uc sing-box-s.json

exit $FAILED
