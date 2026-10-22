// SPDX-License-Identifier: GPL-3.0-or-later
'use strict';
import * as fs from 'fs';
import { failure, run_command, success } from './core.uc';
const STATE_FILE = '/tmp/smartsafehub/device.json';
const HELPER = '/usr/libexec/smartsafehub-device';
function read_state() {
 const raw = fs.readfile(STATE_FILE);
 if (raw == null || length(raw) == 0) return { schema:1, component:'device', phase:'pending', lastResult:'never', lastErrorCode:null, accountRegistered:null, plan:null, pairingCode:null, pairingExpiresAt:null, protectionRefreshPending:false, nextSyncAt:0, lastSuccessAt:0 };
 try { return json(raw); } catch (e) { return null; }
}
// Local state only: the hub owns the list of recommended rules, while
// the router exposes the domains actually owned by the reconciler.
const RECOMMENDED_FILE = '/etc/smartsafehub/recommended-rules.state';
const RECOMMENDED_RECEIPT = '/tmp/smartsafehub/recommended-rules.receipt.json';
const RECOMMENDED_CATALOG = '/tmp/smartsafehub/recommended-rules.catalog.json';
const RECOMMENDED_SYNC_STATUS = '/tmp/smartsafehub/recommended-rules.sync.json';
function read_json_file(path) {
 const raw = fs.readfile(path);
 if (raw == null || length(raw) == 0) return null;
 try { return json(raw); } catch (e) { return null; }
}
export function read_recommended_rules_status(request) {
 const raw = fs.readfile(RECOMMENDED_FILE);
 let revision = null;
 let domains = [];
 if (raw != null && length(raw) > 0) {
  const lines = split(raw, '\n');
  const saved = lines[0];
  if (saved != '-' && match(saved, /^[0-9a-f]{64}$/) == null) return failure('RECOMMENDED_STATE_INVALID', '추천 규칙 상태가 올바르지 않습니다.');
  revision = saved == '-' ? null : saved;
  for (let i = 1; i < length(lines); i++) {
   let domain = lines[i];
   if (domain == '') continue;
   if (match(domain, /^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$/) == null) return failure('RECOMMENDED_STATE_INVALID', '추천 규칙 상태가 올바르지 않습니다.');
   push(domains, domain);
  }
 }
 const receipt = read_json_file(RECOMMENDED_RECEIPT);
 const sync = read_json_file(RECOMMENDED_SYNC_STATUS);
 const catalog = read_json_file(RECOMMENDED_CATALOG);
 const rules = catalog?.revision == revision && type(catalog?.rules) == 'array' ? catalog.rules : [];
 const device = read_state();
 const confirmed = revision != null && receipt?.status == 'confirmed' && receipt?.revision == revision;
 // The receipt records SafeShield's verified allow list. A transient Hub poll
 // failure does not undo that local confirmation, nor does an unrelated 5-minute
 // device/account sync failure. Failed reconciliation removes the receipt.
 // A busy SafeShield refresh is pending work, not an application failure.
 // Keep an older verified receipt for its revision without treating a newer
 // in-progress operation as already complete.
 const syncStatus = sync?.status == 'pending' ? 'pending' :
  confirmed ? 'confirmed' : sync?.status == 'delayed' ? 'delayed' :
  sync?.status == 'failed' ? 'failed' : 'pending';
 const syncWarning = confirmed && (sync?.status == 'failed' || sync?.status == 'delayed');
 const confirmedDomains = confirmed && type(receipt?.domains) == 'array' ? receipt.domains : [];
 return success({
  revision: revision,
  domains: domains,
  rules: rules,
  confirmedDomains: confirmedDomains,
  syncStatus: syncStatus,
  syncWarning: syncWarning,
  syncStage: sync?.stage ?? null,
  syncReason: sync?.reason ?? null,
  lastCheckedAt: sync?.checkedAt ?? 0,
  lastDeviceSyncAt: device?.lastSuccessAt ?? 0,
  nextDeviceSyncAt: device?.nextSyncAt ?? 0,
  accountRegistered: device?.accountRegistered ?? false
 });
};
export function refresh_recommended_rules_status(request) {
 // The blocklist download and the Hub device sync are different operations.
 // Reuse the authenticated device sync, never the SafeShield blocklist refresh.
 if (!run_command([ HELPER, 'recommended-sync' ], 25000)) {
  const latest = read_json_file(RECOMMENDED_SYNC_STATUS);
  if (latest?.status != 'pending' && latest?.status != 'delayed')
   return failure('RECOMMENDED_SYNC_UNAVAILABLE', 'SmartSafeHub 서버와 동기화하지 못했습니다. 잠시 후 다시 시도해 주세요.');
 }
 return read_recommended_rules_status(request);
};
export function revoke_recommended_rule(request) {
 const rule_id = request?.args?.rule_id;
 if (rule_id == null || match(sprintf('%s', rule_id), /^[1-9][0-9]{0,9}$/) == null)
  return failure('INVALID_RULE_ID', '적용 해제할 추천 규칙을 선택해 주세요.');
 if (!run_command([ HELPER, 'recommended-revoke', sprintf('%s', rule_id) ], 25000))
  return failure('RECOMMENDED_REVOKE_FAILED', '규칙 해제 또는 SafeShield 반영에 실패했습니다. 서버 변경은 다음 동기화에서 반영될 수 있습니다.');
 return read_recommended_rules_status(request);
};
export function read_device_registration_status(request) { const state = read_state(); return state != null ? success(state) : failure('DEVICE_STATE_INVALID', '기기 등록 상태를 읽지 못했습니다.'); };
export function refresh_device_registration_status(request) { if (!run_command([ HELPER, 'status-sync' ], 25000)) return failure('DEVICE_SYNC_FAILED', 'SmartSafeHub 계정 연결 상태를 확인하지 못했습니다.'); const state = read_state(); return state != null ? success(state) : failure('DEVICE_STATE_INVALID', '기기 등록 상태를 읽지 못했습니다.'); };
export function refresh_device_pairing(request) { if (!run_command([ HELPER, 'pairing-session' ], 15000)) return failure('DEVICE_PAIRING_FAILED', 'SmartSafeHub 계정 연결 코드를 발급하지 못했습니다.'); const state = read_state(); return state != null ? success(state) : failure('DEVICE_STATE_INVALID', '기기 등록 상태를 읽지 못했습니다.'); };
