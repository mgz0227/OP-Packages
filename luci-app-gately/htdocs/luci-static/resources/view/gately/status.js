'use strict';
'require view';
'require rpc';
'require ui';
'require dom';
'require poll';

var callGetInfo = rpc.declare({ object: 'luci.gately', method: 'get_info', expect: { } });
var callGetStatus = rpc.declare({ object: 'luci.gately', method: 'get_status', expect: { } });
var callService = rpc.declare({ object: 'luci.gately', method: 'service', params: ['action'], expect: { } });

return view.extend({
	load: function() {
		return callGetInfo();
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null,

	handleServiceAction: function(action) {
		ui.showModal(null, [ E('p', { class: 'spinning' }, _('Executing service action...')) ]);
		var self = this;
		var startTime = Date.now();
		var shouldBeRunning = (action === 'start' || action === 'restart');

		return callService(action).then(function() {
			function waitForReady() {
				if (Date.now() - startTime > 20000) {
					ui.hideModal();
					ui.addNotification(null, E('p', _('Operation timeout, please refresh the page')), 'error');
					return;
				}
				callGetStatus().then(function(res) {
					var isRunning = res && res.state && res.state !== 'stopped';
					if (shouldBeRunning ? isRunning : !isRunning) {
						ui.hideModal();
						ui.addNotification(null, E('p', _('Service action executed successfully')), 'info');
						self.updateStatus(res);
						if (isRunning) {
							callGetInfo().then(function(info) {
								self.updateInfo(info);
							});
						}
					} else {
						setTimeout(waitForReady, 500);
					}
				});
			}
			waitForReady();
		});
	},

	updateStatus: function(res) {
		var statusEl = document.getElementById('_status');
		if (statusEl) {
			var isRunning = res && res.running;
			dom.content(statusEl, [
				E('span', { 'style': 'color:' + (isRunning ? 'green' : 'red') + ';font-weight:bold;' },
					isRunning ? _('Running') : _('Not Running')
				),
				' ',
				E('button', {
					'class': 'cbi-button cbi-button-' + (isRunning ? 'reset' : 'apply'),
					'click': ui.createHandlerFn(this, function() {
						return this.handleServiceAction(isRunning ? 'stop' : 'start');
					})
				}, isRunning ? _('Stop') : _('Start')),
				' ',
				E('button', {
					'class': 'cbi-button cbi-button-action',
					'click': ui.createHandlerFn(this, function() {
						return this.handleServiceAction('restart');
					})
				}, _('Restart'))
			]);
		}
	},

	updateInfo: function(info) {
		if (!info) return;
		var gatelyInfo = {};
		try { gatelyInfo = JSON.parse(info.gatelyInfo || '{}'); } catch(e) {}

		var el;
		el = document.getElementById('_gatelyVersion');
		if (el) dom.content(el, gatelyInfo.Version || '-');

		el = document.getElementById('_gatelyArch');
		if (el) dom.content(el, info.gatelyArch || '-');

		el = document.getElementById('_gatelyUser');
		if (el) dom.content(el, info.adminUser || 'admin');

		el = document.getElementById('_gatelyPassword');
		if (el) dom.content(el, info.adminPassword || 'admin123456');

		if (info.running && info.adminPort) {
			var url = 'http://' + window.location.hostname + ':' + info.adminPort + (info.adminSafeUrl || '');
			el = document.getElementById('_gatelyAdminLink');
			if (el) dom.content(el, E('a', { href: url, target: '_blank', style: 'font-weight:bold; color:blue;' }, url));
		} else {
			el = document.getElementById('_gatelyAdminLink');
			if (el) dom.content(el, E('em', {}, _('Service not running')));
		}
	},

	render: function(info) {
		var running = info.running;

		var container = E('div', { class: 'cbi-map' }, [
			E('h2', {}, _('Gately') + ' - ' + _('Overview')),
			E('div', { class: 'cbi-map-descr' }, _('Overview of your Gately network gateway service status, real-time statistics, and control settings.'))
		]);

		var gatelyInfo = {};
		try { gatelyInfo = JSON.parse(info.gatelyInfo || '{}'); } catch(e) {}

		var adminLinkContent;
		if (running && info.adminPort) {
			var url = 'http://' + window.location.hostname + ':' + info.adminPort + (info.adminSafeUrl || '');
			adminLinkContent = E('a', { href: url, target: '_blank', style: 'font-weight:bold; color:blue;' }, url);
		} else if (running) {
			adminLinkContent = E('em', {}, _('Loading...'));
		} else {
			adminLinkContent = E('em', {}, _('Service not running'));
		}

		container.appendChild(
			E('fieldset', { class: 'cbi-section' }, [
				E('legend', {}, _('Service Status')),
				E('div', { class: 'cbi-section-node' }, [
					E('table', { class: 'table' }, [
						E('tr', { class: 'tr' }, [
							E('td', { class: 'td left', width: '33%' }, _('Current Status')),
							E('td', { class: 'td left', id: '_status' }, E('em', {}, _('Loading...')))
						])
					])
				])
			])
		);

		var infoSection = E('fieldset', { class: 'cbi-section' }, [
			E('legend', {}, _('Application Information')),
			E('div', { class: 'cbi-section-node' }, [
				E('table', { class: 'table cbi-section-table' }, [
					E('tr', { class: 'tr' }, [
						E('td', { class: 'td left', width: '33%' }, _('Version')),
						E('td', { class: 'td left', id: '_gatelyVersion' }, gatelyInfo.Version || '-')
					]),
					E('tr', { class: 'tr' }, [
						E('td', { class: 'td left' }, _('Architecture')),
						E('td', { class: 'td left', id: '_gatelyArch' }, info.gatelyArch || '-')
					]),
					E('tr', { class: 'tr' }, [
						E('td', { class: 'td left' }, _('Admin Account')),
						E('td', { class: 'td left', id: '_gatelyUser' }, info.adminUser || 'admin')
					]),
					E('tr', { class: 'tr' }, [
						E('td', { class: 'td left' }, _('Admin Password')),
						E('td', { class: 'td left', id: '_gatelyPassword' }, info.adminPassword || 'admin123456')
					]),
					E('tr', { class: 'tr' }, [
						E('td', { class: 'td left' }, _('Admin Panel')),
						E('td', { class: 'td left', id: '_gatelyAdminLink' }, adminLinkContent)
					])
				])
			])
		]);

		container.appendChild(infoSection);
		this.updateStatus(info);

		var self = this;
		poll.add(function() {
			return callGetInfo().then(function(res) {
				self.updateStatus(res);
				self.updateInfo(res);
			});
		}, 5);

		return container;
	}
});
