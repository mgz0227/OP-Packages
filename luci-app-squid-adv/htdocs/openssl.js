'use strict';
'require ui';
'require view';
'require uci';
'require form';
'require rpc';
'require tools.widgets as widgets';

return view.extend({
	bits: null,
	days: null,
	country: null,
	state: null,
	organization: null,
	is_valid: false,
	valid: null,

	cert_valid: rpc.declare({
		object: 'luci.squid-adv',
		method: 'cert_info',
	}),
	generate: rpc.declare({
		object: 'luci.squid-adv',
		method: 'generate',
        params: [ 'bits', 'days', 'country', 'state', 'locality', 'organization' ],
	}),

	// Loading function:
    load: function () {
        return Promise.all([
            this.cert_valid(),
        ]);
    },

	// Rendering function:
	render: function(data) {
		var s, o, m, t;
		m = new form.Map('squid', _('OpenSSL Certificate'));
		this.valid = data[0].valid;

		s = m.section(form.TypedSection, 'squid', _("Certificate Valid Period"));
		s.anonymous = true;

		o = s.option(form.Value, "_notBefore", _("Current Certificate Valid Starting:"))
		o.cfgvalue = function() { return data[0].notBefore != undefined ? data[0].notBefore : 'Invalid'; }
		o.write = null;
		o.readonly = true;

		o = s.option(form.Value, "_notAfter", _("Current Certificate Not Valid After:"))
		o.cfgvalue = function() { return data[0].notAfter != undefined ? data[0].notAfter : 'Invalid'; }
		o.write = null;
		o.readonly = true;

		//-- generate = o = s.option(form.Button, "", "Generate Certificates")

		/*-- OpenSSL Configuration

		o = s.option(form.DummyValue, '', '').template = "squid/openssl-config"
*/

		s = m.section(form.TypedSection, 'squid', _("Certificate Settings"));
		s.anonymous = true;

		o = s.option(form.ListValue, "rsa_key_bits", _("RSA Key Bit Size:"))
		o.value("4096", "4096 bits (" + _("Best") + ")")
		o.value("2048", "2048 bits (" + _("Better") + ")")
		o.value("1024", "1024 bits (" + _("Not Recommended") + ")")
		o.value("512", "512 bits (" + _("Not Recommended") + ")")
		o.write = null;
		o.rmempty = false
		o.cfgvalue = function() { return data[0].bits != undefined ? data[0].bits : '4096'; }
		this.bits = o;

		o = s.option(form.Value, "days", _("Days The Certificate Is Good For:"))
		o.default = "3650"
		o.datatype = 'integer';
		o.cfgvalue = function() { if (data[0].days != undefined) { return data[0].days; } }
		o.write = null;
		this.days = o;
		
		o = s.option(form.Value, "countryName", _("Country Name:"))
		o.cfgvalue = function() { return data[0].countryName != undefined ? data[0].countryName : 'XX'; }
		o.write = null;
		this.country = o;

		o = s.option(form.Value, "stateOrProvinceName", _("State Or Province Name:"))
		o.cfgvalue = function() { return data[0].stateOrProvinceName != undefined ? data[0].stateOrProvinceName : 'Unspecified'; }
		o.write = null;
		this.state = o;

		o = s.option(form.Value, "localityName", _("Locality Name:"))
		o.cfgvalue = function() { return data[0].localityName != undefined ? data[0].localityName : 'Unspecified'; }
		o.write = null;
		this.locality = o;

		o = s.option(form.Value, "organizationName", _("Organization Name:"))
		o.cfgvalue = function() { return data[0].organizationName != undefined ? data[0].organizationName : 'OpenWrt Router'; }
		o.write = null;
		this.organization = o;

		return m.render();
	},
	
	generate_cert: function() {
		// Gather information:
		var bits = this.bits.textvalue();
		var days = this.days.textvalue();
		var country = this.country.textvalue();
		var state = this.state.textvalue();
		var locality = this.locality.textvalue();
		var organization = this.organization.textvalue();

		// Create a promise for the OpenSSL Certificate Generation task:
		var tasks = [
			this.generate( bits, days, country, state, locality, organization ),
		];
		return Promise.all(tasks).then(function() {
			classes.ui.changes.apply(false);
		});
	},

	get_ipinfo: function() {
		alert("Not implemented yet");
	},

	addFooter: function() {
		return E('div', { 'class': 'cbi-page-actions' }, [
			E('button', {'class': 'cbi-button cbi-button-save', 'click': L.ui.createHandlerFn(this, 'generate_cert')}, [ _('Generate Certificate') ]),
			E('button', {'class': 'cbi-button cbi-button-reset', 'click': L.ui.createHandlerFn(this, 'get_ipinfo')}, [ _('Populate Fields') ])
		]);
	}
})

