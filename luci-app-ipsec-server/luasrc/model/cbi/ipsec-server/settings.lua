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
enabled.description = translate("Enable the IPSec VPN server and expose the IPSec remote-access services configured below.")
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
o.description = translate("Use a client that supports pure IKEv2 PSK to connect to this server. Native Windows does not support IKEv2 PSK; use IKEv2 EAP there instead.")
o.default = 0
o.rmempty = false

o = s:option(Flag, "ikev2_eap_enable", translate("Enable IKEv2 EAP"))
o.description = translate("Use a client that supports IKEv2 EAP-MSCHAPv2 to connect to this server. The gateway certificate is read from the OpenWrt ACME package under /etc/ssl/acme. Windows native IKEv2 commonly proposes AES256/SHA1 for ESP, so this server keeps that proposal enabled for compatibility.")
o.default = 0
o.rmempty = false

o = s:option(Value, "ikev2_eap_id", translate("IKEv2 EAP Server ID"))
o.description = translate("Used as the gateway identity for IKEv2 EAP and should match a subjectAltName on the ACME certificate. Enter the public domain name clients connect to.")
o.placeholder = "vpn.example.com"
o.rmempty = false
o:depends("ikev2_eap_enable", "1")
function o.validate(self, value, section)
	if m:get(section, "ikev2_eap_enable") == "1" and (not value or value == "") then
		return nil, translate("This field is required when IKEv2 EAP is enabled.")
	end
	return value
end

o = s:option(Value, "ikev2_eap_acme_name", translate("ACME Certificate Name"))
o.description = translate("Main domain / filename stem of the ACME certificate stored under /etc/ssl/acme. Leave blank to reuse the IKEv2 EAP Server ID.")
o.placeholder = "vpn.example.com"
o.rmempty = true
o:depends("ikev2_eap_enable", "1")

local function acme_name(section)
	local name = m:get(section, "ikev2_eap_acme_name")
	if not name or name == "" then
		name = m:get(section, "ikev2_eap_id")
	end
	return name
end

o = s:option(DummyValue, "_ikev2_eap_acme_cert", translate("Expected ACME Certificate Path"))
o.description = translate("Configure and issue this certificate in the ACME app first. The IPSec service will read the certificate from this path when IKEv2 EAP is enabled.")
o.cfgvalue = function(t, n)
	local name = acme_name(n)
	if not name or name == "" then
		return "/etc/ssl/acme/<domain>.crt"
	end
	return "/etc/ssl/acme/" .. name .. ".crt"
end
o:depends("ikev2_eap_enable", "1")

o = s:option(DummyValue, "_ikev2_eap_acme_key", translate("Expected ACME Key Path"))
o.cfgvalue = function(t, n)
	local name = acme_name(n)
	if not name or name == "" then
		return "/etc/ssl/acme/<domain>.key"
	end
	return "/etc/ssl/acme/" .. name .. ".key"
end
o:depends("ikev2_eap_enable", "1")

o = s:option(DummyValue, "_ikev2_eap_acme_chain", translate("Expected ACME Chain Path"))
o.description = translate("If present, the issuer chain will also be linked into strongSwan so clients receive the intermediate CA certificates.")
o.cfgvalue = function(t, n)
	local name = acme_name(n)
	if not name or name == "" then
		return "/etc/ssl/acme/<domain>.chain.crt"
	end
	return "/etc/ssl/acme/" .. name .. ".chain.crt"
end
o:depends("ikev2_eap_enable", "1")

return m
