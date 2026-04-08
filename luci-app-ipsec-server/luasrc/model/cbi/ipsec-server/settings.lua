local sys = require "luci.sys"

m = Map("luci-app-ipsec-server", translate("IPSec VPN Server"))
m.template = "ipsec-server/ipsec-server_status"

s = m:section(TypedSection, "service")
s.anonymous = true

o = s:option(DummyValue, "ipsec-server_status", translate("Current Condition"))
o.rawhtml = true
o.cfgvalue = function(t, n)
	return '<font class="ipsec-server_status"></font>'
end

enabled = s:option(Flag, "enabled", translate("Enable"))
enabled.description = translate("Enable the IPSec VPN server and optionally expose the VPN services configured below.")
enabled.default = 0
enabled.rmempty = false

clientip = s:option(Value, "clientip", translate("VPN Client IP"))
clientip.description = translate("VPN Client reserved started IP addresses with the same subnet mask, such as: 192.168.100.10/24")
clientip.datatype = "ip4addr"
clientip.optional = false
clientip.rmempty = false

secret = s:option(Value, "secret", translate("Secret Pre-Shared Key"))
secret.password = true

o = s:option(Flag, "ikev2_psk_enable", translate("Enable IKEv2 PSK"))
o.description = translate("Use a client that supports IKEv2 PSK to connect to this server.")
o.default = 0
o.rmempty = false

o = s:option(Flag, "ikev2_eap_enable", translate("Enable IKEv2 EAP"))
o.description = translate("Use a client that supports IKEv2 EAP-MSCHAPv2 to connect to this server. A local CA and gateway certificate will be generated automatically when the service starts.")
o.default = 0
o.rmempty = false

o = s:option(Value, "ikev2_eap_id", translate("IKEv2 EAP Server ID"))
o.description = translate("Used as the gateway identity and certificate subjectAltName for IKEv2 EAP. Enter the public domain name or public IP address that clients connect to.")
o.placeholder = "vpn.example.com"
o.rmempty = false
o:depends("ikev2_eap_enable", "1")
function o.validate(self, value, section)
	if m:get(section, "ikev2_eap_enable") == "1" and (not value or value == "") then
		return nil, translate("This field is required when IKEv2 EAP is enabled.")
	end
	return value
end

o = s:option(DummyValue, "_ikev2_eap_ca_cert", translate("IKEv2 EAP CA Certificate"))
o.description = translate("Import this CA certificate into IKEv2 EAP clients so they can trust the gateway certificate.")
o.cfgvalue = function(t, n)
	return "/etc/ipsec.d/cacerts/ikev2-eap-ca-cert.pem"
end
o:depends("ikev2_eap_enable", "1")

if sys.call("command -v xl2tpd > /dev/null") == 0 then
	o = s:option(DummyValue, "l2tp_status", "L2TP " .. translate("Current Condition"))
	o.rawhtml = true
	o.cfgvalue = function(t, n)
		return '<font class="l2tp_status"></font>'
	end

	o = s:option(Flag, "l2tp_enable", "L2TP " .. translate("Enable"))
	o.description = translate("Use a client that supports L2TP over IPSec PSK to connect to this server.")
	o.default = 0
	o.rmempty = false

	o = s:option(Value, "l2tp_localip", "L2TP " .. translate("Server IP"))
	o.description = translate("VPN Server IP address, such as: 192.168.101.1")
	o.datatype = "ip4addr"
	o.rmempty = true
	o.default = "192.168.101.1"
	o.placeholder = o.default

	o = s:option(Value, "l2tp_remoteip", "L2TP " .. translate("Client IP"))
	o.description = translate("VPN Client IP address range, such as: 192.168.101.10-20")
	o.rmempty = true
	o.default = "192.168.101.10-20"
	o.placeholder = o.default

	if sys.call("ls -L /usr/lib/ipsec/libipsec* 2>/dev/null >/dev/null") == 0 then 
		o = s:option(DummyValue, "_o", " ")
		o.rawhtml = true
		o.cfgvalue = function(t, n)
			return string.format('<a style="color: red">%s</a>', translate("L2TP/IPSec is not compatible with kernel-libipsec, which will disable this module."))
		end
		o:depends("l2tp_enable", true)
	end
end

return m
