import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const read = (file) => readFileSync(resolve(root, file), 'utf8');

test('추천 규칙은 도메인이 아니라 할당된 규칙 ID로 해제한다', () => {
  const script = read('root/usr/libexec/smartsafehub-device');
  const page = read('frontend/src/pages/SafeShieldRulesPage.tsx');
  assert.match(script, /devices\/recommended-rules\/\$rule_id\/revoke/);
  assert.match(script, /reconcile_recommended_response "\$out"/);
  assert.match(page, /onRevokeRecommendedRule\?\:/);
  assert.match(page, /revokeTarget\.id/);
  assert.match(page, /aria-modal="true"/);
  assert.match(page, /다른 추천 규칙에 필요한 도메인은 유지/);
});

test('인증된 공유기에서만 적용 해제 RPC가 호출되고 공개 데모는 차단된다', () => {
  const app = read('frontend/src/app/App.tsx');
  const page = read('frontend/src/pages/SafeShieldRulesPage.tsx');
  const api = read('frontend/src/api/smartsafehub.ts');
  const rpc = read('root/usr/share/rpcd/ucode/smartsafehub.uc');
  const acl = read('root/usr/share/rpcd/acl.d/luci-app-smartsafehub.json');
  assert.match(app, /onRevokeRecommendedRule=\{revokeRecommendedRule\}/);
  assert.match(api, /device_recommended_rules_revoke/);
  assert.match(rpc, /require_root_password\(function\(request\)/);
  assert.match(acl, /device_recommended_rules_revoke/);
  assert.doesNotMatch(page, /from ['"]\.\.\/api\//);
  assert.doesNotMatch(read('frontend/src/demo/main.tsx'), /onRevokeRecommendedRule=/);
});

// rpcd-mod-ucode handlers receive named arguments in request.args.
// Calling `ubus call smartsafehub device_recommended_rules_revoke '{"rule_id":1}'`
// must not be rejected because the handler looked for request.rule_id.
test('추천 규칙 해제 RPC는 request.args에서 ID를 읽는다', () => {
  const rpc = read('root/usr/share/rpcd/ucode/smartsafehub.uc');
  const handler = read('root/usr/share/rpcd/ucode/smartsafehub/device-registration.uc');
  assert.match(rpc, /device_recommended_rules_revoke:\s*\{\s*args:\s*\{\s*rule_id:\s*0/);
  assert.match(handler, /const rule_id = request\?\.args\?\.rule_id;/);
  assert.doesNotMatch(handler, /const rule_id = request\?\.rule_id;/);
});
