// SPDX-License-Identifier: GPL-2.0-only
'use strict';
'require view';
'require poll';
'require dom';
'require fs';
'require ui';
'require rpc';

var STATUS_FILE = '/var/run/thermal-guard.status';

// The router's clock. Every time in the status file comes from it, and a
// router without NTP can be days apart from the browser.
var callUnixtime = rpc.declare({ object: 'luci', method: 'getUnixtime', expect: { result: 0 } });

// Status file and router clock together; a failed read gives null for either.
function readStatus() {
	return Promise.all([
		fs.read(STATUS_FILE).catch(function() { return null; }),
		callUnixtime().catch(function() { return null; })
	]);
}
// Seconds the page waits for the result of a clear: the daemon's RESET_WAIT
// for a running cycle, its RESET_BUDGET for the undo, and 60 s for the flush,
// the fence and admission, the same margin a joining "thermal-guard reset" waits.
var CLEAR_GIVE_UP = 240 + 200 + 60;

function parseStatus(text) {
	var st = {};
	(text || '').split('\n').forEach(function(line) {
		var i = line.indexOf('=');
		if (i > 0)
			st[line.substring(0, i)] = line.substring(i + 1).trim();
	});
	return st;
}

function num(v) {
	var n = parseInt(v, 10);
	return isNaN(n) ? null : n;
}

// Colour follows the configured thresholds, not a fixed scale, so the bar means
// the same thing on a passively cooled box and on one with a fan.
function tempClass(value, warn, crit) {
	if (value === null)
		return '';
	if (crit !== null && value >= crit)
		return 'tg-crit';
	if (warn !== null && value >= warn)
		return 'tg-warn';
	return 'tg-ok';
}

function gauge(value, warn, crit, max) {
	var pct = (value === null) ? 0 : Math.max(0, Math.min(100, Math.round(value * 100 / max)));
	return E('div', { 'class': 'tg-gauge' }, [
		E('div', {
			'class': 'tg-fill ' + tempClass(value, warn, crit),
			'style': 'width:%d%%'.format(pct)
		})
	]);
}

// Sensor names come straight from the kernel. Translate the ones people actually
// recognise, leave the rest as reported rather than guessing.
function sensorLabel(name) {
	var m = name.match(/^(?:mt79\d\d|mtwifi)_phy(\d)/);
	if (m)
		return _('Wi-Fi %d').format(parseInt(m[1], 10) + 1);
	if (name.indexOf('mdio_bus') === 0 || name.indexOf('phy') === 0)
		return _('Ethernet');
	if (name === 'nvme')
		return _('SSD');
	return name;
}

function extraSensors(st) {
	var out = [];
	for (var k in st) {
		if (k.indexOf('sensor.') === 0 && st[k] !== '')
			out.push([ sensorLabel(k.substring(7)), parseInt(st[k], 10) ]);
	}
	return out.sort(function(a, b) { return a[0] > b[0] ? 1 : -1; });
}

function row(label, valueNode, gaugeNode) {
	return E('div', { 'class': 'tg-row' }, [
		E('div', { 'class': 'tg-label' }, label),
		gaugeNode || E('div', { 'class': 'tg-gauge tg-empty' }, []),
		E('div', { 'class': 'tg-value' }, valueNode)
	]);
}

// Stage 2 and 3 do whatever the Actions tab says, so the banner has to read the
// configured action instead of naming the default.
function actionLabel(action) {
	switch (action) {
		case 'modem_radio_off': return _('modem radio off');
		case 'wifi_off':        return _('Wi-Fi off');
		case 'interface_down':  return _('network interface down');
		case 'command':         return _('custom command');
		case 'none':            return _('no action');
		default:                return action || _('unknown action');
	}
}

// fan_control is the fan the daemon drives now, a recorded one after the
// settings changed included. Older status files only carry fan_mode.
function stageText(stage, st) {
	switch (stage) {
		case 0: return (st.fan_control || st.fan_mode) === 'none'
			? _('Stage 1 of 3 active: warning, fan left to its own controller')
			: _('Stage 1 of 3 active: fan at full speed');
		case 1: return num(st.t1)
			? _('Stage 2 of 3 active since %s: %s').format(fmtClock(st.t1), actionLabel(st.stage1_action))
			: _('Stage 2 of 3 active: %s').format(actionLabel(st.stage1_action));
		case 2: return _('Stage 3 of 3 active: %s').format(actionLabel(st.stage2_action));
		default: return _('No intervention, temperatures within range');
	}
}

// Why the page might be showing something other than a live reading. The daemon
// stamps every write with "now": a file that stopped being written means the
// service is gone, while a fresh file holding an old reading means it is
// running but not measuring.
function serviceState(st, now) {
	var written = parseInt(st.now, 10),
	    interval = parseInt(st.interval, 10) || 30,
	    age = written ? now - written : null;

	// Three missed writes, with a floor so a short interval is not jumpy.
	if (age !== null && age > Math.max(90, interval * 3))
		return 'stopped';
	if (st.enabled === '0')
		return 'paused';
	return 'running';
}

function fmtAge(ts, now) {
	var n = parseInt(ts, 10);
	if (!n)
		return '-';
	var age = Math.max(0, now - n);
	if (age < 90)
		return _('%d s ago').format(age);
	return _('%d min ago').format(Math.round(age / 60));
}

// Router timestamp as a local wall clock time, for "since" in the banner.
function fmtClock(ts) {
	var n = parseInt(ts, 10);
	return n ? new Date(n * 1000).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '-';
}

// What happens next with stage 2 of 3. The daemon decides it (recover_state)
// from its own state and clock, so the page only words it, and a browser with
// a wrong clock cannot skew the time (recover_at against now).
function recoveryText(st) {
	var at = num(st.recover_at), now = num(st.now);
	switch (st.recover_state) {
		case 'cpu':
			return _('The processor was warm during this incident, so it is not undone automatically. Clear it once the cause is fixed.');
		case 'nomodem':
			return _('The modem had no reading when this stage began, so it is not undone automatically.');
		case 'nocause':
			return _('No recorded cause, so it is not undone automatically. Clear it once the cause is fixed.');
		case 'fan':
			return _('The fan taken over has no usable record, so it is not undone automatically. Check the fan, clear the stage, then run thermal-guard fan-forget on the router.');
		case 'action':
			return st.stage1_action === 'command'
				? _('A custom script ran, so it is not undone automatically.')
				: _('The action of stage 2 of 3 changed or cannot be undone, so it is not undone automatically.');
		case 'capped':
			return _('Automatic undo limit reached (%d in 24 hours), so it stays until you clear it. Clear it once the cause is fixed.').format(num(st.recover_n) || 0);
		case 'planned':
			if (at !== null && now !== null)
				return _('Undone automatically in about %d min if the modem stays cool.').format(Math.max(1, Math.ceil((at - now) / 60)));
			return _('Undone automatically once the modem has read cool for %d min.').format(num(st.recover_minutes) || 10);
		case 'cooling':
			return _('Undone automatically once the modem has read cool for %d min.').format(num(st.recover_minutes) || 10);
		default:
			return null;
	}
}

// Whether stage 2 of 3 is going to clear itself, which the generic "stays
// until you clear it" line must not contradict.
function clearsItself(st) {
	return st.recover_state === 'planned' || st.recover_state === 'cooling';
}

// A reset holds the lock, so the daemon writes no status file while it runs. A
// reset killed from outside leaves "running" for good, so the mark counts only
// for as long as the page would wait for a clear.
function clearRunning(st, now) {
	var ts = num(st.reset_ts);
	return st.reset_state === 'running' && ts !== null && now - ts <= CLEAR_GIVE_UP;
}

// What the status says about the request the page waits for: null while it
// says nothing, else its state and its own failure list. Only the boot and the
// request id identify it, never a time, so a clock step cannot fake a result.
function clearOutcome(wait, st) {
	if (!wait.boot || !wait.id || !st)
		return null;
	// A new boot has no request record until its first clear, so the daemon's
	// own boot id tells. Older daemons do not write it.
	if (st.boot_id && st.boot_id !== wait.boot)
		return { state: 'restarted' };
	// No record yet: a snapshot from before the request.
	if (!st.reset_boot)
		return null;
	// Generations and pids start again with every boot, so a record of another
	// boot tells nothing about this request.
	if (st.reset_boot !== wait.boot)
		return { state: 'restarted' };
	// reset_failed is the warning a later stage empties; the request keeps its
	// own list. Older daemons publish only the warning.
	if (st.reset_id === wait.id)
		return { state: st.reset_state, failed: ('reset_req_failed' in st
			? st.reset_req_failed : st.reset_failed) || '' };
	if (st.reset_prev_id === wait.id)
		return { state: st.reset_prev_state, failed: st.reset_prev_failed || '' };
	// The record keeps two requests. Both later than this one means its result
	// was pushed out and will not come back.
	var gen = num(st.reset_gen), prev = num(st.reset_prev_gen);
	if (wait.gen !== null && gen !== null && prev !== null && gen > wait.gen && prev > wait.gen)
		return { state: 'evicted' };
	return null;
}

return view.extend({
	load: function() {
		return readStatus();
	},

	render: function(data) {
		var style = E('style', {}, [
			'.tg-row{display:flex;align-items:center;gap:.6em;margin:.35em 0}',
			'.tg-label{flex:0 0 12em}',
			'.tg-value{flex:0 0 7em;text-align:right;font-weight:bold}',
			'.tg-gauge{flex:1 1 auto;height:1.1em;background:rgba(128,128,128,.25);border-radius:.55em;overflow:hidden;min-width:6em}',
			'.tg-gauge.tg-empty{background:transparent}',
			'.tg-fill{height:100%;border-radius:.55em;transition:width .4s}',
			'.tg-ok{background:#4caf50}.tg-warn{background:#ff9800}.tg-crit{background:#f44336}',
			'.tg-banner{padding:.6em .8em;border-radius:.3em;margin-bottom:1em}',
			'.tg-banner.tg-active{background:rgba(244,67,54,.15);border-left:4px solid #f44336}',
			'.tg-banner.tg-idle{background:rgba(76,175,80,.12);border-left:4px solid #4caf50}',
			'.tg-banner.tg-warn-banner{background:rgba(255,152,0,.15);border-left:4px solid #ff9800}',
			'.tg-meta{opacity:.7;font-size:90%;margin-top:.8em}'
		].join('\n'));

		var body = E('div', { 'id': 'tg-body' }, []);
		var container = E('div', { 'class': 'cbi-map' }, [
			style,
			E('h2', {}, _('Thermal Guard')),
			E('div', { 'class': 'cbi-map-descr' },
				_('Current temperatures and protection state. Thresholds and actions are configured under System, Thermal Guard.')),
			body
		]);

		this.update(body, data[0], data[1]);

		poll.add(L.bind(function() {
			return readStatus().then(L.bind(function(d) { this.update(body, d[0], d[1]); }, this));
		}, this), 5);

		return container;
	},

	// routerNow: the router's clock in seconds. Without it the browser's stands
	// in, which is only right where both clocks agree.
	update: function(body, text, routerNow) {
		var st = (text === null) ? null : parseStatus(text);
		var now = (typeof routerNow === 'number' && routerNow > 0)
			? routerNow : Math.floor(Date.now() / 1000);
		this.checkClear(st);
		if (st === null) {
			dom.content(body, E('div', { 'class': 'alert-message warning' },
				_('No data yet. Check whether the Thermal Guard service is running.')));
			return;
		}

		var cpu = num(st.cpu_c), modem = num(st.modem_c), stage = num(st.stage);
		var cpuWarn = num(st.cpu_warn), cpuCrit = num(st.cpu_crit);
		var modemWarn = num(st.modem_warn), modemCrit = num(st.modem_crit);
		var fanState = num(st.fan_state), fanMax = num(st.fan_max), rpm = num(st.fan_rpm);

		var rows = [
			row(_('Processor temperature'),
				cpu === null ? '-' : '%d °C'.format(cpu),
				gauge(cpu, cpuWarn, cpuCrit, num(st.cpu_emergency) || 100))
		];

		if (st.modem_src !== '' || modem !== null)
			rows.push(row(_('Modem temperature'),
				modem === null ? _('no reading') : '%d °C'.format(modem),
				gauge(modem, modemWarn, modemCrit, (num(st.modem_crit) || 90) + 10)));

		// The profile row gives the profile's own thresholds; without one, the
		// thresholds in force: defaults only while neither limit is configured.
		if (st.modem_model) {
			rows.push(row(_('Modem model'), st.modem_model, null));
			rows.push(row(_('Modem profile'), st.modem_profile
				? _('%d / %d °C (%s)').format(num(st.modem_profile_warn),
					num(st.modem_profile_crit), st.modem_profile)
				: ((st.modem_warn_src === 'default' && st.modem_crit_src === 'default')
					? _('none, defaults %d / %d °C')
					: _('none, configured %d / %d °C')).format(modemWarn, modemCrit), null));
		}

		extraSensors(st).forEach(function(s) {
			rows.push(row(s[0], '%d °C'.format(s[1]), gauge(s[1], null, null, 100)));
		});

		// fan_view is what can be read, even where fan_mode leaves the fan to
		// another controller. Older status files only carry fan_mode.
		var fanView = st.fan_view || st.fan_mode;
		if (fanView && fanView !== 'none') {
			// The daemon computes the percentage because only it knows which way
			// the raw scale runs; an inverted board reports full speed as 0.
			var fanPercent = num(st.fan_percent);
			var fanLabel = (fanPercent !== null)
				? '%d %%'.format(fanPercent)
				: (fanState === null ? '-'
					: (fanMax ? _('fan step %d of %d').format(fanState, fanMax) : String(fanState)));
			if (rpm !== null && rpm > 0)
				fanLabel += ' (%d rpm)'.format(rpm);
			rows.push(row(_('Fan'), fanLabel,
				(fanPercent !== null) ? gauge(fanPercent, null, null, 100)
					: ((fanState !== null && fanMax) ? gauge(fanState, null, null, fanMax) : null)));

			// A release that did not read back leaves the daemon's own values in
			// place until the next clear; that is no other service.
			if (st.fan_foreign === '1' && st.fan_restore_pending !== '1')
				rows.push(row(_('Fan control'),
					_('Another service is controlling this fan'), null));
		}

		// Only shown where this service manages the kernel's switching
		// temperatures; elsewhere they are none of its business.
		if (st.trip_state === 'active') {
			var tripDelta = num(st.trip_delta);
			rows.push(row(_('Fan switching temperatures'),
				(st.trip_now || '-').replace(/\//g, ' / ') + ' °C', null));
			if (tripDelta)
				rows.push(row('', _('lowered by %d K for the modem').format(tripDelta), null));
		}

		var active = (stage !== null && stage >= 0),
		    state = serviceState(st, now),
		    noSensor = (st.no_sensor === '1'),
		    banner = [ E('strong', {}, noSensor
				? _('This device does not report any temperature')
				: stageText(stage, st)) ];

		// Not a fault to chase: some boards expose no thermal zone and no hwmon
		// temperature input at all. Saying so beats a page full of dashes.
		if (noSensor)
			banner.push(E('div', {},
				_('No thermal sensor was found, so the processor is not watched on this hardware. The modem thresholds still apply while the modem reports a temperature.')));

		// A stage that is still applied while nothing is watching is the one
		// thing an operator has to be told about, so it comes before the rest.
		if (state === 'stopped' && (this.clearWait || clearRunning(st, now)))
			banner.push(E('div', {}, _('Clearing is running, readings resume afterwards.')));
		else if (state !== 'running' && !noSensor)
			banner.push(E('div', {}, state === 'stopped'
				? (active
					? _('The service is not running. Protection stages stay applied and the fan is not handed back.')
					: _('The service is not running. Temperatures are not being watched.'))
				: (active
					? _('The service is paused. Protection stages stay applied and the fan is not handed back.')
					: _('The service is paused. Temperatures are not being watched.'))));

		if (st.trip_dt_changed === '1')
			banner.push(E('div', {},
				_('The firmware brings new fan switching temperatures (%s °C). Your own values still apply; review them under System, Thermal Guard, Fan.').format((st.trip_dt || '').replace(/\//g, ', '))));

		var recovery = recoveryText(st);
		if (recovery)
			banner.push(E('div', {}, recovery));

		// The stage is gone but something it did is still in force.
		var resetFailed = st.reset_failed || '';
		// A clear without a stage tries the fan release again and nothing else,
		// so only a failed fan brings the button back.
		var failedItems = resetFailed.split(',');
		var fanRetry = failedItems.indexOf('fan') >= 0;
		var notFan = failedItems.filter(function(t) { return t !== '' && t !== 'fan'; }).length > 0;
		if (resetFailed)
			banner.push(E('div', {},
				_('Still in force after a clear: %s. Check the device.').format(resetFailed)));
		if (notFan)
			banner.push(E('div', {},
				_('Only the fan release can be tried again with Clear. Anything else stays listed here until the next protection stage or a reboot.')));

		if (active || fanRetry) {
			var clear = [];
			if (active && !clearsItself(st))
				clear.push(E('div', {}, _('Protection stages stay active until you clear them. Clear them once the cause is fixed, for example a replaced fan.')));
			clear.push(E('button', {
				'class': 'btn cbi-button cbi-button-reset',
				'style': 'margin-top:.5em',
				'click': ui.createHandlerFn(this, 'handleClear')
			}, _('Clear protection stages')));
			banner.push(E('div', {}, clear));
		}

		dom.content(body, [
			E('div', {
				'class': 'tg-banner ' + ((state !== 'running' || noSensor) ? 'tg-warn-banner'
					: (active ? 'tg-active' : (resetFailed ? 'tg-warn-banner' : 'tg-idle')))
			}, banner),
			E('div', {}, rows),
			E('div', { 'class': 'tg-meta' }, [
				_('Last reading: %s').format(fmtAge(st.ts, now)),
				st.modem_src ? ' · ' + _('modem source: %s').format(st.modem_src) : '',
				st.fan_mode ? ' · ' + _('fan mode: %s').format(st.fan_mode) : '',
				st.version ? ' · ' + _('version %s').format(st.version) : ''
			].join(''))
		]);
	},

	// Starts the reset detached: rpcd would kill one that waits for a cycle or
	// undoes slowly. The result arrives with the status file, see checkClear.
	handleClear: function() {
		return fs.exec('/usr/sbin/thermal-guard', [ 'reset-start' ]).then(L.bind(function(res) {
			if (res.code !== 0) {
				ui.addNotification(null, E('p', {}, _('Clearing failed: %s').format(res.stderr || res.stdout || res.code)), 'error');
				return;
			}
			// A start that joined a running clear prints that request, so the
			// wait is the same either way.
			var req = parseStatus(res.stdout);
			this.clearWait = {
				boot: req.reset_boot || '',
				id: req.reset_id || '',
				gen: num(req.reset_gen),
				until: Date.now() + CLEAR_GIVE_UP * 1000
			};
			ui.addNotification(null, E('p', {}, _('Clearing started, the result follows in a moment.')), 'info');
		}, this)).catch(function(err) {
			ui.addNotification(null, E('p', {}, _('Clearing failed: %s').format(err)), 'error');
		});
	},

	// Called on every poll while a clear runs. Only the request reset-start
	// named ends the wait, as the current or the previous one in the record;
	// whatever else the status shows, nothing reads as success.
	checkClear: function(st) {
		var wait = this.clearWait;
		if (!wait)
			return;
		var res = clearOutcome(wait, st) || {}, failed = res.failed;
		var msg, type = 'warning';
		switch (res.state) {
			case 'done':
				type = 'info';
				// The list also names what an earlier clear left and this one did
				// not try again: a clear with only those is done, not failed.
				msg = failed
					? _('Protection stages cleared. Still in force from an earlier clear: %s').format(failed)
					: _('Protection stages cleared.');
				break;
			case 'failed':
				msg = _('Clearing could not undo everything. Still in force: %s').format(failed || '-');
				break;
			case 'busy':
				msg = _('The daemon is busy with a stage action, try again in a minute.');
				break;
			case 'aborted':
				msg = _('Clearing was aborted.');
				break;
			case 'restarted':
				msg = _('The router restarted while clearing, the result is unknown.');
				break;
			case 'evicted':
				msg = _('The result of this clear is no longer available. See the status and the log.');
				break;
			default:
				// Starting, running or not in the status yet.
				if (Date.now() <= wait.until)
					return;
				msg = _('No result for this clear arrived in time, the outcome is unknown.');
		}
		this.clearWait = null;
		ui.addNotification(null, E('p', {}, msg), type);
	},

	handleSave: null,
	handleSaveApply: null,
	handleReset: null
});
