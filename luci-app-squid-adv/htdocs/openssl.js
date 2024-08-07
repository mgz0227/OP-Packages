'use strict';
'require ui';
'require view';
'require uci';
'require form';
'require rpc';
'require tools.widgets as widgets';

return view.extend({
	cert_valid: rpc.declare({
		object: 'luci.squid-adv',
		method: 'cert_valid',
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

		s = m.section(form.TypedSection, 'squid', _("Certificate Settings"));
		s.anonymous = true;

		o = s.option(form.Value, "_notBefore", _("Current Certificate Not Valid Before:"))
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

		o = s.option(form.ListValue, "rsa_key_bits", _("RSA Key Bit Size:"))
		o.value("4096", "4096 bits (" + _("Best") + ")")
		o.value("2048", "2048 bits (" + _("Better") + ")")
		o.value("1024", "1024 bits (" + _("Not Recommended") + ")")
		o.value("512", "512 bits (" + _("Not Recommended") + ")")
		o.rmempty = false
		o.cfgvalue = function() { return data[0].bits != undefined ? data[0].bits : '4096'; }

		o = s.option(form.Value, "days", _("Days The Certificate Is Good For:"))
		o.default = "3650"
		o.datatype = 'integer';
		o.cfgvalue = function() { if (data[0].days != undefined) { return data[0].days; } }
		
		o = s.option(form.Value, "countryName", _("Country Name:"))
		o.cfgvalue = function() { return data[0].countryName != undefined ? data[0].countryName : 'XX'; }

		o = s.option(form.Value, "stateOrProvinceName", _("State Or Province Name:"))
		o.cfgvalue = function() { return data[0].stateOrProvinceName != undefined ? data[0].stateOrProvinceName : 'Unspecified'; }

		o = s.option(form.Value, "localityName", _("Locality Name:"))
		o.cfgvalue = function() { return data[0].localityName != undefined ? data[0].localityName : 'Unspecified'; }

		o = s.option(form.Value, "organizationName", _("Organization Name:"))
		o.cfgvalue = function() { return data[0].organizationName != undefined ? data[0].organizationName : 'OpenWrt Router'; }

		return m.render();
	}
})
