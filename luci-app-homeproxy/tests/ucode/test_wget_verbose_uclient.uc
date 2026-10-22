#!/usr/bin/ucode
/*
 * SPDX-License-Identifier: GPL-2.0-only
 *
 * Copyright (C) 2026 ImmortalWrt.org
 */

'use strict';

import { wGETVerbose, wgetFlavor } from 'homeproxy';

let failures = 0, checks = 0;

function expect(name, actual, want) {
	checks++;
	if (sprintf('%J', actual) !== sprintf('%J', want)) {
		printf('FAIL %s: expected %J, got %J\n', name, want, actual);
		failures++;
	}
}

expect('flavor', wgetFlavor(), 'compat');

const res = wGETVerbose('http://127.0.0.1:1/subs', 'HomeProxy test UA');
expect('no content', res.content, null);
expect('not an option error', match(res.error || '', /unrecognized option/) == null, true);
expect('error carries the exit code', match(res.error || '', /^wget exited with status \d+: /) != null, true);

printf('%d checks, %d failures\n', checks, failures);
exit(failures === 0 ? 0 : 1);
