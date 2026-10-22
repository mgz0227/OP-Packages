'use strict';
'require view';
'require rpc';
'require poll';
'require dom';
'require ui';

var callGetLog = rpc.declare({ object: 'luci.gately', method: 'get_log', expect: { } });

return view.extend({
	render: function() {
		var logView = E('textarea', {
			id: 'logView',
			style: 'width:100%; height:500px; background:#f4f4f4; color:#333; padding:10px; border:1px solid #ccc; font-family:monospace;',
			readonly: true
		}, [ _('Loading logs...') ]);

		var container = E('div', { class: 'cbi-map' }, [
			E('h2', {}, _('Gately') + ' - ' + _('Log')),
			E('div', { class: 'cbi-map-descr' }, _('Real-time query of the Gately running logs to diagnose DDNS updates, STUN traversal, and reverse proxy rules.')),
			E('fieldset', { class: 'cbi-section' }, [
				E('legend', {}, _('Logs')),
				E('div', { class: 'cbi-section-node' }, logView)
			])
		]);

		poll.add(function() {
			return callGetLog().then(function(res) {
				var textarea = document.getElementById('logView');
				if (textarea && res && typeof(res.log) === 'string') {
					var isAtBottom = (textarea.scrollHeight - textarea.clientHeight <= textarea.scrollTop + 1);
					textarea.value = res.log || _('No log available.');
					if (isAtBottom) textarea.scrollTop = textarea.scrollHeight;
				}
			});
		}, 5);

		return container;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
