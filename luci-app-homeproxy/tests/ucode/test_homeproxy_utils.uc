#!/usr/bin/ucode
/*
 * SPDX-License-Identifier: GPL-2.0-only
 *
 * Copyright (C) 2025 ImmortalWrt.org
 */

'use strict';

import { lsdir } from 'fs';
import { executeCommand, isValidCIDR, isValidPEM, shellQuote } from 'homeproxy';

let failures = 0,
    checks = 0;

function expect(name, actual, want) {
	checks++;
	if (sprintf('%J', actual) !== sprintf('%J', want)) {
		printf('FAIL %s: expected %J, got %J\n', name, want, actual);
		failures++;
	}
}

function fd_count() {
	let n = 0;
	for (let _entry in lsdir('/proc/self/fd'))
		n++;
	return n;
}

const ok = executeCommand('echo', 'hello');
expect('ok.exitcode', ok.exitcode, 0);
expect('ok.stdout', ok.stdout, 'hello\n');
expect('ok.stderr', ok.stderr, '');
expect('ok.binary', ok.binary, false);
expect('ok.command', ok.command, 'echo hello');

const bad = executeCommand('sh', '-c', shellQuote('echo oops >&2; exit 3'));
expect('bad.exitcode', bad.exitcode, 3);
expect('bad.stderr', bad.stderr, 'oops\n');
expect('bad.stdout', bad.stdout, '');

expect('false.exitcode', executeCommand('false').exitcode, 1);

const bin = executeCommand('sh', '-c', shellQuote('printf "\\001\\002\\003"'));
expect('bin.binary', bin.binary, true);
expect('bin.stdout', bin.stdout, null);

const big_want = 700 * 1024;
const big = executeCommand('sh', '-c', shellQuote('yes a | head -c ' + big_want));
expect('big.exitcode', big.exitcode, 0);
expect('big.length', length(big.stdout), big_want);

expect('cidr.ok', isValidCIDR('1.2.3.4/24', 4), true);
expect('cidr.bare', isValidCIDR('1.2.3.4', 4), true);
expect('cidr.bad-prefix', isValidCIDR('1.2.3.4/abc', 4), false);
expect('cidr.empty-prefix', isValidCIDR('1.2.3.4/', 4), false);
expect('cidr.out-of-range', isValidCIDR('1.2.3.4/33', 4), false);
expect('cidr.two-slashes', isValidCIDR('1.2.3.4/24/1', 4), false);
expect('cidr.injection', isValidCIDR('1.2.3.4/0 } flush ruleset; table inet x {', 4), false);
expect('cidr.v6-ok', isValidCIDR('2001:db8::/32', 6), true);
expect('cidr.v6-injection', isValidCIDR('2001:db8::/32 } flush ruleset;', 6), false);

const pem_cert = '-----BEGIN CERTIFICATE-----\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n-----END CERTIFICATE-----';
const pem_key = '-----BEGIN RSA PRIVATE KEY-----\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n-----END RSA PRIVATE KEY-----';
expect('pem.cert', isValidPEM(pem_cert, false), true);
expect('pem.cert-as-key', isValidPEM(pem_cert, true), false);
expect('pem.key', isValidPEM(pem_key, true), true);
expect('pem.key-as-cert', isValidPEM(pem_key, false), false);
expect('pem.garbage', isValidPEM('not a pem at all', false), false);
expect('pem.empty', isValidPEM('', false), false);

const before = fd_count();
for (let i = 0; i < 200; i++)
	executeCommand('true');
const after = fd_count();

checks++;
if (after > before) {
	printf('FAIL descriptor leak: %d -> %d after 200 calls\n', before, after);
	failures++;
}

printf('%d checks, %d failures\n', checks, failures);
exit(failures === 0 ? 0 : 1);
