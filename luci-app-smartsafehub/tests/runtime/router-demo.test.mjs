import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve, dirname, extname } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../frontend/src');
const visited = new Set();

function inspectImports(path) {
  if (visited.has(path)) return;
  visited.add(path);
  const source = readFileSync(path, 'utf8');
  // Follow executable imports only; TypeScript `import type` never reaches JS.
  const regex = /^\s*import\s+(?!type\b)(?:[^;]*?\bfrom\s+)?["'](\.[^"']+)["']/gm;
  for (const [, local] of source.matchAll(regex)) {
    const base = resolve(dirname(path), local);
    const target = extname(base) ? base : `${base}.tsx`;
    let resolved = target;
    try { readFileSync(resolved); } catch { resolved = `${base}.ts`; }
    assert.ok(!resolved.includes('/api/'), `API dependency in demo: ${resolved}`);
    assert.ok(!resolved.includes('/auth/'), `Authentication dependency in demo: ${resolved}`);
    inspectImports(resolved);
  }
}

test('standalone demo has no executable RPC/auth dependency', () => {
  inspectImports(resolve(root, 'demo/main.tsx'));
  assert.ok(visited.size > 10, 'Presentational components must be traversed');
});

test('fictional MAC addresses and documentation IP ranges are used', () => {
  const fixtures = readFileSync(resolve(root, 'demo/data.ts'), 'utf8');
  assert.match(fixtures, /02:00:00:00:00:01/);
  assert.match(fixtures, /198\.51\.100\.20/);
  assert.doesNotMatch(fixtures, /172\.16\.3\./);
});

test('public demo routes and fixture-backed pages match navigation', () => {
  const routes = readFileSync(resolve(root, 'app/routes.ts'), 'utf8');
  const app = readFileSync(resolve(root, 'demo/main.tsx'), 'utf8');
  const sidebar = readFileSync(resolve(root, 'components/ProductNavigation.tsx'), 'utf8');
  const required = ['home', 'activity', 'network', 'wifi', 'devices', 'safeshield', 'rules', 'system'];
  for (const route of required) {
    assert.match(routes, new RegExp(`'${route}'`));
    if (route !== 'home') assert.ok(app.includes(`case '${route}':`), `missing demo route ${route}`);
  }
  for (const component of ['ActivityPage', 'WanPage', 'LanPage', 'WifiPage', 'SafeShieldRulesPage', 'UpdatePage']) {
    assert.ok(app.includes(`<${component}`), `missing real page ${component}`);
  }
  assert.ok(sidebar.includes('DEMO_ROUTES.includes(name)'), 'navigation must share allowed demo routes');
  assert.match(app, /text-teal-800/, 'dark theme must map the notice text color');
  assert.doesNotMatch(app, /text-teal-900/, 'notice would become illegible in dark mode');
});

test('demo actions never call RPC and Wi-Fi credentials are injected', () => {
  const app = readFileSync(resolve(root, 'demo/main.tsx'), 'utf8');
  const qr = readFileSync(resolve(root, 'components/WifiQrDialog.tsx'), 'utf8');
  const data = readFileSync(resolve(root, 'demo/data.ts'), 'utf8');
  assert.match(app, /const disabledAction = async \(\): Promise<boolean> => \{/);
  assert.match(app, /return false;/);
  for (const prop of ['onSave', 'onUpdate', 'onUpdateGuest', 'onAddRule', 'onDeleteRule', 'onSaveSettings', 'onUpload']) {
    assert.ok(app.includes(`${prop}={disabledAction}`) || (prop === 'onUpload' && app.includes('upload: disabledAction')), `unsafe demo action: ${prop}`);
  }
  assert.doesNotMatch(qr, /from ['"]\.\.\/api\//);
  assert.match(qr, /void load\(\)\.then/);
  assert.match(data, /demoWifiQr = async/);
  assert.match(data, /demoGuestWifiQr = async/);
});

// The shared rules page must remain presentational: only the authenticated
// app supplies the status reader, never the fixture-backed public demo.
test('추천 규칙 API 조회는 실제 공유기 앱에서만 주입된다', () => {
  const page = readFileSync(resolve(root, 'pages/SafeShieldRulesPage.tsx'), 'utf8');
  const app = readFileSync(resolve(root, 'app/App.tsx'), 'utf8');
  const demo = readFileSync(resolve(root, 'demo/main.tsx'), 'utf8');
  assert.doesNotMatch(page, /from ['"]\.\.\/api\//);
  assert.match(page, /if \(!onLoadRecommendedRulesStatus\) return;/);
  assert.match(app, /onLoadRecommendedRulesStatus=\{fetchRecommendedRulesStatus\}/);
  assert.doesNotMatch(demo, /onLoadRecommendedRulesStatus=/);
});
