'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync, spawn } = require('node:child_process');
const { root } = require('./helpers/runtime');
const mac = 'AA:BB:CC:11:22:33';

function fixture(t, command, prefix) {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'device-manager-single-ping-'));
    t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
    const leases = path.join(directory, 'leases'); fs.writeFileSync(leases, '');
    const source = fs.readFileSync(path.join(root, 'root/usr/libexec/rpcd/luci.device-manager'), 'utf8')
        .replaceAll('. /usr/share/libubox/jshn.sh', '. "$AUDIT_JSHN"')
        .replaceAll('/tmp/luci-device-manager-single-ping', path.join(directory, 'single-ping'))
        .replaceAll('/tmp/dhcp.leases', leases).replaceAll('/var/dhcp.leases', leases);
    const wrapper = `
ip() { printf '%s\\n' "$AUDIT_NEIGH"; return "$AUDIT_IP_EXIT"; }
ping() { printf '%s\\n' "$@" >> "$AUDIT_PING_LOG"; sleep "$AUDIT_DELAY"; printf '%s\\n' "$AUDIT_OUTPUT"; return "$AUDIT_PING_EXIT"; }
ping6() { ping "$@"; }
` + source;
    let sequence = 0;
    function options(extra) {
        const id = sequence++;
        const log = path.join(directory, 'pings-' + id);
        return { log, options: { encoding: 'utf8', timeout: 10000, env: Object.assign({}, process.env, {
            AUDIT_JSHN: process.env.TEST_JSHN_PATH || path.join(root, 'test/helpers/jshn.sh'), AUDIT_NODE: process.execPath,
            AUDIT_JSON_ENCODER: path.join(root, 'test/helpers/json-encoder.js'),
            AUDIT_JSON_LOG: path.join(directory, 'json-' + id), AUDIT_PING_LOG: log,
            AUDIT_NEIGH: '192.168.1.20 dev br-lan lladdr aa:bb:cc:11:22:33 REACHABLE',
            AUDIT_IP_EXIT: '0', AUDIT_PING_EXIT: '0', AUDIT_DELAY: '0', AUDIT_OUTPUT: '1 packet received, time=0.5 ms'
        }, extra) } };
    }
    return {
        directory, leases,
        run(request = { mac }, extra = {}) {
            const cfg = options(extra);
            const result = spawnSync(command, [...prefix, '-c', wrapper, 'ping-test', 'call', 'ping_device'],
                Object.assign({}, cfg.options, { input: JSON.stringify(request) }));
            assert.equal(result.status, 0, result.stderr);
            return { reply: JSON.parse(result.stdout), args: fs.existsSync(cfg.log) ? fs.readFileSync(cfg.log, 'utf8').trim().split('\n') : [] };
        },
        start(extra = {}) {
            const cfg = options(extra);
            const child = spawn(command, [...prefix, '-c', wrapper, 'ping-test', 'call', 'ping_device'], cfg.options);
            child.stdin.end(JSON.stringify({ mac }));
            let stdout = '', stderr = '';
            child.stdout.on('data', data => { stdout += data; }); child.stderr.on('data', data => { stderr += data; });
            const done = new Promise((resolve, reject) => {
                child.on('error', reject);
                child.on('close', code => code === 0 ? resolve(JSON.parse(stdout)) : reject(new Error(stderr)));
            });
            return { done, log: cfg.log };
        }
    };
}

for (const [command, prefix] of [['sh', []], ['busybox', ['sh']]]) {
    const available = spawnSync(command, [...prefix, '-c', 'command -v flock >/dev/null']).status === 0;
    test(`${command}: single-device Ping resolves the MAC, ignores caller targets and reports reply versus timeout`, { skip: !available }, t => {
        const f = fixture(t, command, prefix);
        const result = f.run({ mac, ip: '8.8.8.8', command: 'touch /tmp/unsafe' });
        assert.equal(result.reply.reachable, true); assert.equal(result.reply.ip, '192.168.1.20');
        assert.equal(result.args.at(-1), '192.168.1.20'); assert.ok(result.args.includes('br-lan'));
        assert.deepEqual(result.args.slice(0, 6), ['-c', '1', '-w', '3', '-W', '2']);
        const timeout = f.run({ mac }, { AUDIT_PING_EXIT: '1' });
        assert.equal(timeout.reply.ok, true); assert.equal(timeout.reply.reachable, false);
        const error = f.run({ mac }, { AUDIT_PING_EXIT: '2', AUDIT_OUTPUT: 'invalid option' });
        assert.equal(error.reply.ok, false); assert.equal(error.reply.error, 'Ping could not be completed');
    });
    test(`${command}: invalid and unknown MACs never launch Ping`, { skip: !available }, t => {
        const f = fixture(t, command, prefix);
        for (const value of ['', null, 'aa:bb:cc:11:22:33; touch /tmp/unsafe', 'AA:BB:CC:11:22:33\ninvalid', "AA:BB:CC:11:22:33'$(touch /tmp/unsafe)'", 'FF:FF:FF:FF:FF:FF', '00:00:00:00:00:00', '11:22:33:44:55:66']) {
            const result = f.run({ mac: value });
            assert.equal(result.reply.ok, false); assert.deepEqual(result.args, []);
        }
        assert.deepEqual(f.run({ mac }, { AUDIT_IP_EXIT: '127' }).args, []);
    });
    test(`${command}: DHCP fallback and IPv6-only link-local neighbors use a single numeric destination`, { skip: !available }, t => {
        const f = fixture(t, command, prefix);
        fs.writeFileSync(f.leases, '123 aa:bb:cc:11:22:33 192.168.1.50 device *\n');
        const lease = f.run({ mac }, { AUDIT_NEIGH: '' });
        assert.equal(lease.reply.ip, '192.168.1.50'); assert.equal(lease.reply.interface, '');
        const reassigned = f.run({ mac }, { AUDIT_NEIGH: '192.168.1.50 dev br-lan lladdr aa:bb:cc:44:55:66 REACHABLE' });
        assert.equal(reassigned.reply.ok, false); assert.deepEqual(reassigned.args, []);
        fs.writeFileSync(f.leases, '');
        const v6 = f.run({ mac }, { AUDIT_NEIGH: 'fe80::1234 dev br-lan lladdr aa:bb:cc:11:22:33 STALE' });
        assert.equal(v6.reply.ip, 'fe80::1234'); assert.equal(v6.reply.interface, 'br-lan');
        assert.equal(v6.args.at(-1), 'fe80::1234'); assert.ok(v6.args.includes('-I'));
        fs.writeFileSync(f.leases, '123 aa:bb:cc:11:22:33 999.1.2.3 invalid *\n');
        assert.equal(f.run({ mac }, { AUDIT_NEIGH: '' }).reply.ok, false);
    });
    test(`${command}: a global nonblocking lock prevents concurrent detail probes`, { skip: !available }, async t => {
        const f = fixture(t, command, prefix);
        const first = f.start({ AUDIT_DELAY: '0.3' });
        for (let attempt = 0; attempt < 100 && !fs.existsSync(first.log); attempt++) await new Promise(resolve => setTimeout(resolve, 10));
        assert.ok(fs.existsSync(first.log));
        const second = f.run();
        assert.equal(second.reply.ok, false); assert.match(second.reply.error, /Another device/); assert.deepEqual(second.args, []);
        await first.done;
        assert.equal(f.run().reply.reachable, true, 'lock must be released after the probe');
    });
}
