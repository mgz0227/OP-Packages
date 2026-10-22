'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { root } = require('./helpers/runtime');

function temporary(fn) {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'device-manager-test-'));
    return Promise.resolve().then(() => fn(directory)).finally(() => fs.rmSync(directory, { recursive: true, force: true }));
}
function rpc(command, prefix, directory, neighbors, exit = '0', method = 'get_online_status', language = 'auto', uciExit = '0') {
    const source = fs.readFileSync(path.join(root, 'root/usr/libexec/rpcd/luci.device-manager'), 'utf8')
        .replaceAll('. /usr/share/libubox/jshn.sh', '. "$AUDIT_JSHN"')
        .replaceAll('/tmp/luci-device-manager-probe', path.join(directory, 'probe'));
    const wrapper = 'ip() { [ "$1" = -4 ] && return 0; printf "%s\\n" "$AUDIT_NEIGH"; return "$AUDIT_IP_EXIT"; }\n' +
        'uci() { [ "$3" = network.lan.ipaddr ] && return 1; if [ "$AUDIT_UCI_EXIT" = 0 ]; then printf "%s\\n" "$AUDIT_LANGUAGE"; fi; return "$AUDIT_UCI_EXIT"; }\n' +
        'ping() { return 1; }\n' + source;
    return spawnSync(command, [...prefix, '-c', wrapper, 'luci.device-manager', 'call', method], { encoding: 'utf8', env: {
        ...process.env, AUDIT_NEIGH: neighbors, AUDIT_IP_EXIT: exit, AUDIT_LANGUAGE: language, AUDIT_UCI_EXIT: uciExit,
        AUDIT_JSHN: process.env.TEST_JSHN_PATH || path.join(root, 'test/helpers/jshn.sh'), AUDIT_NODE: process.execPath,
        AUDIT_JSON_ENCODER: path.join(root, 'test/helpers/json-encoder.js'), AUDIT_JSON_LOG: path.join(directory, 'json.log')
    } });
}
for (const [command, prefix] of [['sh', []], ['busybox', ['sh']]]) {
    const available = spawnSync(command, [...prefix, '-c', 'exit 0']).status === 0;
    test(`${command}: RPC preserves MAC-less FAILED/INCOMPLETE and safely encodes strings`, { skip: !available }, () => temporary(directory => {
        const result = rpc(command, prefix, directory,
            '192.168.1.20 dev br-lan FAILED\n192.168.1.21 dev br-lan INCOMPLETE\nfe80::1 dev br-"lan lladdr aa:bb:cc:11:22:33 STALE proto kernel');
        assert.equal(result.status, 0, result.stderr);
        const reply = JSON.parse(result.stdout);
        assert.equal(reply.ok, true); assert.equal(reply.neighbors.length, 3);
        assert.equal(reply.neighbors[0].state, 'FAILED'); assert.equal(reply.neighbors[0].mac, '');
        assert.equal(reply.neighbors[1].state, 'INCOMPLETE');
        assert.equal(reply.neighbors[2].state, 'STALE'); assert.equal(reply.neighbors[2].dev, 'br-"lan');
    }));
    test(`${command}: RPC reports an unavailable ip command separately from an empty table`, { skip: !available }, () => temporary(directory => {
        const failed = rpc(command, prefix, directory, '', '127');
        assert.equal(JSON.parse(failed.stdout).ok, false);
        const empty = rpc(command, prefix, directory, '');
        assert.deepEqual(JSON.parse(empty.stdout), { ok: true, neighbors: [] });
    }));
}
function initialize(directory, content, failure = false) {
    const config = path.join(directory, 'config');
    if (content !== null) fs.writeFileSync(config, content);
    const source = fs.readFileSync(path.join(root, 'tools/initialize-config.sh'), 'utf8').replaceAll('/etc/config/device_manager', config);
    const wrapper = 'uci() { printf "%s\\n" "$*" >> "$AUDIT_UCI_LOG"; if [ "$2" = batch ]; then cat >> "$AUDIT_UCI_LOG"; fi; return "$AUDIT_UCI_EXIT"; }\n' + source;
    const result = spawnSync('busybox', ['sh', '-c', wrapper], { encoding: 'utf8', env: {
        ...process.env, AUDIT_UCI_LOG: path.join(directory, 'uci.log'), AUDIT_UCI_EXIT: failure ? '1' : '0'
    } });
    return { result, config, log: path.join(directory, 'uci.log') };
}
test('initializer preserves populated and intentionally empty configurations', () => temporary(directory => {
    for (const content of ['', "config device 'saved'\n\toption name 'Existing TV'\n"]) {
        const { result, config, log } = initialize(directory, content);
        assert.equal(result.status, 0); assert.equal(fs.readFileSync(config, 'utf8'), content);
        assert.equal(fs.existsSync(log), false);
    }
}));
test('first installation creates default groups exactly once', () => temporary(directory => {
    const { result, config, log } = initialize(directory, null);
    assert.equal(result.status, 0, result.stderr); assert.equal(fs.existsSync(config), true);
    const first = fs.readFileSync(log, 'utf8'); assert.match(first, /smart_home/); assert.match(first, /commit device_manager/);
    initialize(directory, null); assert.equal(fs.readFileSync(log, 'utf8'), first);
}));
test('failed initialization removes the new incomplete configuration for retry', () => temporary(directory => {
    const { result, config } = initialize(directory, null, true);
    assert.notEqual(result.status, 0); assert.equal(fs.existsSync(config), false);
}));
function deploy(directory, args, failure = false) {
    const bin = path.join(directory, 'bin'); fs.mkdirSync(bin, { recursive: true });
    for (const command of ['ssh', 'scp']) {
        fs.writeFileSync(path.join(bin, command), '#!/bin/sh\nprintf "%s: %s\\n" "'+command+'" "$*" >> "$AUDIT_COMMAND_LOG"\nexit "$AUDIT_REMOTE_EXIT"\n', { mode: 0o755 });
    }
    return spawnSync('bash', [path.join(root, 'tools/deploy.sh'), ...args], { encoding: 'utf8', env: {
        ...process.env, PATH: bin + ':' + process.env.PATH,
        AUDIT_COMMAND_LOG: path.join(directory, 'commands.log'), AUDIT_REMOTE_EXIT: failure ? '1' : '0'
    } });
}
test('deployment succeeds with mocked remote commands and copies all frontend modules', () => temporary(directory => {
    const result = deploy(directory, ['-p', '2222', 'audit.invalid']);
    assert.equal(result.status, 0, result.stderr);
    const log = fs.readFileSync(path.join(directory, 'commands.log'), 'utf8');
    assert.match(log, /resources\/device-manager /); assert.match(log, /view\/device-manager\/devices.js/);
    assert.match(log, /-P 2222/); assert.match(log, /rm -f \/etc\/uci-defaults\/80_device_manager/);
    assert.doesNotMatch(result.stderr, /EOF/);
}));
test('deployment rejects missing or invalid SSH ports before connecting', () => temporary(directory => {
    for (const args of [['-p'], ['-p', 'bad', 'audit.invalid'], ['-p', '0', 'audit.invalid'], ['-p', '65536', 'audit.invalid']]) {
        const result = deploy(directory, args);
        assert.notEqual(result.status, 0); assert.match(result.stderr, /SSH port must/);
    }
    assert.equal(fs.existsSync(path.join(directory, 'commands.log')), false);
}));
test('failed SSH connectivity prevents deployment', () => temporary(directory => {
    const result = deploy(directory, ['audit.invalid'], true);
    assert.notEqual(result.status, 0); assert.match(result.stderr, /Failed to connect/);
    assert.doesNotMatch(fs.readFileSync(path.join(directory, 'commands.log'), 'utf8'), /scp:/);
}));

test('development deployment uses native translations and removes legacy bundled resources', () => temporary(directory => {
    const result = deploy(directory, ['audit.invalid']);
    assert.equal(result.status, 0, result.stderr);
    const log = fs.readFileSync(path.join(directory, 'commands.log'), 'utf8');
    assert.match(log, /rm -f .*device-manager-builtin.zh-cn.lmo/);
    assert.doesNotMatch(log, /scp:.*device-manager-builtin/);
    assert.match(log, /i18n.js.*translations.js/);
}));
