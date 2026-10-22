#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
RPC="$ROOT_DIR/root/usr/share/rpcd/ucode/smartsafehub/firmware.uc"
FIRMWARE_TYPES="$ROOT_DIR/frontend/src/types/firmware.ts"
FIRMWARE_CARD="$ROOT_DIR/frontend/src/components/FirmwareUpdatesCard.tsx"
SOFTWARE_CARD="$ROOT_DIR/frontend/src/components/SoftwareUpdatesCard.tsx"
UPDATE_PAGE="$ROOT_DIR/frontend/src/pages/UpdatePage.tsx"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

# Firmware resolve contract must prefer the published release field while still
# supporting metadata nested under Hub's firmware build record.
grep -Fq 'release?.bundled_software ?? release?.metadata?.bundled_software' "$RPC" || fail 'Hub bundled version is not read'
grep -Fq 'match(bundled_version, /^[0-9]+\.[0-9]+\.[0-9]+(-r[0-9]+)?$/)' "$RPC" || fail 'Hub bundled version must be validated'
grep -Fq 'bundledSoftware: bundled_version != null ? { smartsafehub: bundled_version } : null' "$RPC" || fail 'bundled software version must be exposed on firmware status'
grep -Fq 'bundledSoftware?: { smartsafehub: string } | null' "$FIRMWARE_TYPES" || fail 'typed bundled version missing'
grep -Fq 'software={data}' "$UPDATE_PAGE" || fail 'installed software status not passed to firmware card'
grep -Fq 'firmware={firmware.data}' "$UPDATE_PAGE" || fail 'firmware status not passed to management card'
grep -Fq 'data-section="firmware-bundled-software"' "$FIRMWARE_CARD" || fail 'bundled software display missing'
grep -Fq 'data-section="software-firmware-match"' "$SOFTWARE_CARD" || fail 'management software explanation missing'
grep -Fq "firmware?.updateAvailable" "$SOFTWARE_CARD" || fail 'management hint must depend on available firmware'
grep -Fq 'data.updateCount === 0 && !updateCheckStale' "$SOFTWARE_CARD" || fail 'stale/pending software updates must not claim no update needed'

# Real comparison logic: unchanged, newer/older, missing or unexpected versions.
ROOT_DIR="$ROOT_DIR" node --disable-warning=ExperimentalWarning --experimental-strip-types --input-type=module <<'JS'
import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
const root = process.env.ROOT_DIR;
const { compareBundledVersion } = await import(pathToFileURL(`${root}/frontend/src/utils/firmwareBundling.ts`).href);
assert.equal(compareBundledVersion('0.2.28-r4', '0.2.28-r4'), 'same');
assert.equal(compareBundledVersion('0.2.28-r5', '0.2.28-r4'), 'newer');
assert.equal(compareBundledVersion('0.2.28-r1', '0.2.28-r4'), 'older');
assert.equal(compareBundledVersion('0.2.29-r1', '0.2.28-r9'), 'newer');
assert.equal(compareBundledVersion('0.2.27-r9', '0.2.28-r1'), 'older');
assert.equal(compareBundledVersion('0.2.28', '0.2.28-r0'), 'same');
assert.equal(compareBundledVersion('0.2.28-rc1', '0.2.28-r1'), 'different');
assert.equal(compareBundledVersion(null, '0.2.28-r4'), 'unknown');
assert.equal(compareBundledVersion('0.2.28-r4', null), 'unknown');
JS
printf '%s\n' 'PASS: bundled firmware software version pipeline and comparison rules'
