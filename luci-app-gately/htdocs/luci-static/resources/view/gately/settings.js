'use strict';
'require view';
'require form';

return view.extend({
	render: function() {
		var m, s, o;

		m = new form.Map('gately', _('Gately Settings'), _('Gately is an open-source, auditable network gateway toolkit (Lucky alternative) integrating DDNS, STUN, port forwarding, reverse proxy, ACME certificates, and WAF.'));

		s = m.section(form.NamedSection, 'main', 'gately', _('Global Settings'));
		s.anonymous = true;
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', _('Enable'));
		o.rmempty = false;

		o = s.option(form.Value, 'configdir', _('Config Directory Path'));
		o.rmempty = false;
		o.default = '/etc/gately';
		o.placeholder = '/etc/gately';

		o = s.option(form.Value, 'initial_password', _('Initial Admin Password'));
		o.password = true;
		o.rmempty = false;
		o.default = 'admin123456';
		o.placeholder = 'admin123456';
		o.datatype = 'minlength(8)';
		o.description = _('Admin password (at least 8 characters, default: admin123456). Modifying this and clicking Save & Apply will update the admin password immediately.');

		s = m.section(form.TypedSection, 'gately', _('Admin Panel Settings'));
		s.anonymous = true;
		s.addremove = false;

		o = s.option(form.Value, 'admin_port', _('Admin Web Listen Port'));
		o.datatype = 'port';
		o.rmempty = false;
		o.default = '16680';
		o.placeholder = '16680';

		o = s.option(form.Value, 'admin_safe_url', _('Admin Safe URL'));
		o.placeholder = '/secret-entry';
		o.validate = function(section_id, value) {
			if (!value) return true;
			var v = value.trim();
			if (v.charAt(0) !== '/') v = '/' + v;
			if (v.length < 4) {
				return _('Safe URL must be at least 3 characters after "/"');
			}
			if (v === '/api' || v.indexOf('/api/') === 0 || v.indexOf('/assets') === 0 || /[ ?#]/.test(v)) {
				return _('Safe URL cannot start with /api or /assets, nor contain spaces, ? or #');
			}
			return true;
		};

		o = s.option(form.Flag, 'admin_internet', _('Allow Internet Access'));
		o.rmempty = false;
		o.default = '0';

		return m.render();
	}
});
