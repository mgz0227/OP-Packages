'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn, spawnSync } = require('node:child_process');
const { root } = require('./helpers/runtime');

function fixture(t, command, prefix) {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'device-manager-probe-'));
    t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
    const clock = path.join(directory, 'uptime');
    fs.writeFileSync(clock, '100.00 0.00\n');
    fs.writeFileSync(path.join(directory, 'arp'), '192.168.1.200 0x1 0x2 aa:bb:cc:11:22:33 * br-lan\n');
    fs.writeFileSync(path.join(directory, 'leases'), '123 aa:bb:cc:11:22:33 192.168.1.200 known *\n123 aa:bb:cc:11:22:44 192.168.3.20 other *\n');
    const source = fs.readFileSync(path.join(root, 'root/usr/libexec/rpcd/luci.device-manager'), 'utf8')
        .replaceAll('. /usr/share/libubox/jshn.sh', '. "$AUDIT_JSHN"')
        .replaceAll('/tmp/luci-device-manager-probe', path.join(directory, 'probe'))
        .replaceAll('/proc/uptime', clock)
        .replaceAll('/proc/net/arp', path.join(directory, 'arp'))
        .replaceAll('/tmp/dhcp.leases', path.join(directory, 'leases'))
        .replaceAll('/var/dhcp.leases', path.join(directory, 'leases'));
    const wrapper = `
ip() {
    if [ "$1" = -o ]; then
        case "$6" in
            br-lan) printf '%s\\n' "2: br-lan inet $AUDIT_LAN_CIDR scope global br-lan" ;;
            br-guest) printf '%s\\n' "3: br-guest inet $AUDIT_GUEST_CIDR scope global br-guest" ;;
        esac
    elif [ "$1" = -4 ]; then
        printf '%s\\n' '198.51.100.0/24 dev eth0 scope link'
    else
        printf '%s\\n' '192.168.1.200 dev br-lan lladdr aa:bb:cc:11:22:33 REACHABLE'
    fi
}
uci() { printf '%s\\n' "$AUDIT_INTERFACES"; }
ubus() {
    [ "$AUDIT_NO_INTERFACE" = 1 ] && return 1
    case "$2" in
        network.interface.lan) printf '%s\\n' '{"l3_device":"br-lan"}' ;;
        network.interface.guest) printf '%s\\n' '{"l3_device":"br-guest"}' ;;
        *) return 1 ;;
    esac
}
ping() {
    previous=""; interface=""
    for argument in "$@"; do
        [ "$previous" = -I ] && interface="$argument"
        previous="$argument"; target="$argument"
    done
    case "$interface" in br-lan|br-guest) ;; *) return 2 ;; esac
    case "$target" in
        192.168.1.200|192.168.3.20) sleep "\${AUDIT_KNOWN_START_DELAY:-0}" ;;
    esac
    printf 'start %s\\n' "$target" >> "$AUDIT_PING_LOG"
    sleep "$AUDIT_PING_DELAY"
    if [ -n "$AUDIT_ADVANCE" ]; then printf '%s.00 0.00\\n' "$AUDIT_ADVANCE" > "$AUDIT_CLOCK"; fi
    printf 'end %s\\n' "$target" >> "$AUDIT_PING_LOG"
    return 1
}
` + source;
    let sequence = 0;
    return {
        clock,
        directory,
        run(extra = {}, method = 'scan_devices') {
            const id = sequence++;
            const log = path.join(directory, 'pings-' + id);
            const child = spawn(command, [...prefix, '-c', wrapper, 'probe-test', 'call', method], {
                env: Object.assign({}, process.env, {
                    AUDIT_JSHN: process.env.TEST_JSHN_PATH || path.join(root, 'test/helpers/jshn.sh'),
                    AUDIT_NODE: process.execPath,
                    AUDIT_JSON_ENCODER: path.join(root, 'test/helpers/json-encoder.js'),
                    AUDIT_JSON_LOG: path.join(directory, 'json-' + id),
                    AUDIT_PING_LOG: log, AUDIT_PING_DELAY: '0.02', AUDIT_KNOWN_START_DELAY: '0',
                    AUDIT_ADVANCE: '', AUDIT_CLOCK: clock, AUDIT_INTERFACES: 'lan guest', AUDIT_NO_INTERFACE: '0',
                    AUDIT_LAN_CIDR: '192.168.1.1/24', AUDIT_GUEST_CIDR: '192.168.2.1/24'
                }, extra)
            });
            let stdout = '', stderr = '';
            child.stdout.on('data', data => { stdout += data; });
            child.stderr.on('data', data => { stderr += data; });
            const timer = setTimeout(() => child.kill('SIGKILL'), 10000);
            const done = new Promise((resolve, reject) => {
                child.on('error', reject);
                child.on('close', code => {
                    clearTimeout(timer);
                    if (code !== 0) { reject(new Error(stderr || 'RPC exit: ' + code)); return; }
                    resolve({ reply: JSON.parse(stdout), log });
                });
            });
            return { done, log };
        }
    };
}

function starts(log) {
    if (!fs.existsSync(log)) return [];
    return fs.readFileSync(log, 'utf8').trim().split('\n')
        .filter(line => line.startsWith('start ')).map(line => line.slice(6));
}

for (const [command, prefix] of [['sh', []], ['busybox', ['sh']]]) {
    const available = spawnSync(command, [...prefix, '-c', 'command -v flock >/dev/null']).status === 0;
    test(`${command}: active probes are bounded, deduplicated, cooled down and resume the sweep`, { skip: !available }, async t => {
        const f = fixture(t, command, prefix);
        const seen = new Set();
        for (let pass = 0; pass < 4; pass++) {
            fs.writeFileSync(f.clock, `${100 + pass * 30}.00 0.00\n`);
            // Delay known-host children to expose assertions that depend on scheduling order.
            const result = await f.run({ AUDIT_KNOWN_START_DELAY: '0.08' }).done;
            assert.equal(result.reply.ok, true); // Failed ICMP must still return the neighbor snapshot.
            const addresses = starts(result.log);
            assert.equal(addresses.length, 128);
            assert.equal(new Set(addresses).size, 128);
            if (pass === 0) {
                // Children may log in any order; the batch barrier preserves batch membership.
                const firstBatch = ['192.168.1.200',
                    ...Array.from({ length: 15 }, (_, i) => '192.168.1.' + (i + 2))];
                assert.deepEqual(addresses.slice(0, 16).sort(), firstBatch.sort(),
                    'known hosts must be included in the first batch');
            }
            if (pass === 1) assert.ok(addresses.every(ip => !seen.has(ip)), 'second pass must resume, not restart');
            addresses.forEach(ip => seen.add(ip));
            let active = 0, peak = 0;
            for (const line of fs.readFileSync(result.log, 'utf8').trim().split('\n')) {
                active += line.startsWith('start ') ? 1 : -1;
                peak = Math.max(peak, active);
            }
            assert.ok(peak <= 16, `peak concurrency was ${peak}`);
            assert.equal(active, 0, 'all probes must finish before releasing the lock');
            const cooldown = await f.run().done;
            assert.equal(cooldown.reply.ok, true);
            assert.deepEqual(starts(cooldown.log), []);
        }
        assert.equal(seen.size, 506, 'selected /24 subnets exclude router addresses and out-of-scope known hosts');
    });

    test(`${command}: overlapping RPCs share one scan and the lock is released afterwards`, { skip: !available }, async t => {
        const f = fixture(t, command, prefix);
        const first = f.run({ AUDIT_PING_DELAY: '0.05' });
        for (let attempt = 0; attempt < 100 && starts(first.log).length === 0; attempt++) {
            await new Promise(resolve => setTimeout(resolve, 10));
        }
        assert.ok(starts(first.log).length > 0, 'first request must have acquired the scan lock');
        const second = await f.run().done;
        assert.equal(second.reply.ok, true);
        assert.deepEqual(starts(second.log), []);
        await first.done;
        fs.writeFileSync(f.clock, '130.00 0.00\n');
        const next = await f.run().done;
        assert.equal(starts(next.log).length, 128, 'next eligible request must acquire the released lock');
    });

    test(`${command}: elapsed-time budget stops a scan before its address limit`, { skip: !available }, async t => {
        const f = fixture(t, command, prefix);
        const result = await f.run({ AUDIT_ADVANCE: '108' }).done;
        assert.equal(result.reply.ok, true);
        assert.equal(starts(result.log).length, 16);
        assert.equal(fs.readFileSync(path.join(f.directory, 'probe.state'), 'utf8'), '108 16\n');
        fs.writeFileSync(f.clock, '130.00 0.00\n');
        assert.deepEqual(starts((await f.run().done).log), [], 'cooldown starts after the scan finishes');
    });
    test(command + ': passive reads never probe and unavailable LANs never fall back to WAN', { skip: !available }, async t => {
        const f = fixture(t, command, prefix);
        const passive = await f.run({}, 'get_online_status').done;
        assert.equal(passive.reply.ok, true);
        assert.deepEqual(starts(passive.log), []);
        const unavailable = await f.run({ AUDIT_NO_INTERFACE: '1' }).done;
        assert.equal(unavailable.reply.ok, false);
        assert.deepEqual(starts(unavailable.log), []);
    });
    test(command + ': /25 and /23 probes respect subnet boundaries and exclude router addresses', { skip: !available }, async t => {
        for (const cidr of ['192.168.1.130/25', '192.168.1.1/23']) {
            const f = fixture(t, command, prefix);
            const result = await f.run({ AUDIT_INTERFACES: 'lan', AUDIT_LAN_CIDR: cidr }).done;
            assert.equal(result.reply.ok, true);
            const addresses = starts(result.log);
            assert.ok(addresses.length > 0);
            assert.ok(!addresses.includes(cidr.split('/')[0]));
            assert.ok(!addresses.some(ip => ip.startsWith('198.51.100.') || ip.startsWith('192.168.3.')));
            if (cidr.endsWith('/25')) {
                assert.equal(addresses.length, 125);
                assert.ok(addresses.every(ip => ip.startsWith('192.168.1.') && Number(ip.split('.')[3]) >= 129 && Number(ip.split('.')[3]) <= 254));
            } else {
                assert.ok(addresses.every(ip => ip.startsWith('192.168.0.') || ip.startsWith('192.168.1.')));
            }
        }
    });
    test(command + ': a /16 probes known LAN hosts only and ignores invalid interface names', { skip: !available }, async t => {
        const f = fixture(t, command, prefix);
        const result = await f.run({ AUDIT_INTERFACES: 'lan ../wan', AUDIT_LAN_CIDR: '192.168.1.1/16' }).done;
        assert.equal(result.reply.ok, true);
        assert.deepEqual(starts(result.log).sort(), ['192.168.1.200', '192.168.3.20']);
    });

    test(command + ': /31 addresses and disabled scanning do not expand to a /24', { skip: !available }, async t => {
        const f = fixture(t, command, prefix);
        const result = await f.run({ AUDIT_INTERFACES: 'lan', AUDIT_LAN_CIDR: '192.168.1.130/31' }).done;
        assert.equal(result.reply.ok, true);
        assert.deepEqual(starts(result.log), ['192.168.1.131']);
        fs.writeFileSync(f.clock, '130.00 0.00\n');
        const disabled = await f.run({ AUDIT_INTERFACES: '' }).done;
        assert.equal(disabled.reply.ok, false);
        assert.deepEqual(starts(disabled.log), []);
    });

}
