local ip = require "luci.ip"

m = Map("luci-app-ipsec-server", translate("IPSec VPN Server"))
m.template = "ipsec-server/ipsec-server_status"

local function validate_ipv4_cidr(self, value)
	if not value or value == "" then
		return nil, translate("This field is required.")
	end

	local cidr = ip.new(value)
	if not cidr or not cidr:is4() then
		return nil, translate("Expecting a valid IPv4 CIDR value, such as 192.168.100.10/24.")
	end

	return value
end

local function validate_ipv6_cidr(self, value, section)
	if m:get(section, "ikev2_ipv6_enable") == "1" and (not value or value == "") then
		return nil, translate("This field is required when IKEv2 IPv6 is enabled.")
	end

	if value and value ~= "" then
		local cidr = ip.new(value)
		if not cidr or not cidr:is6() then
			return nil, translate("Expecting a valid IPv6 CIDR value, such as fd42:42:42::10/120.")
		end
	end

	return value
end

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
clientip.optional = false
clientip.rmempty = false
clientip.validate = validate_ipv4_cidr

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

o = s:option(Flag, "ikev2_ipv6_enable", translate("Enable IPv6 for IKEv2"))
o.description = translate("Provide IPv6 virtual addresses to IKEv2 clients. Android and other dual-stack clients may request INTERNAL_IP6_ADDRESS during IKEv2. This option only affects IKEv2 PSK/EAP and does not change legacy IKEv1 Xauth.")
o.default = 0
o.rmempty = false

o = s:option(Value, "ikev2_clientip6", translate("IKEv2 IPv6 Client IP"))
o.description = translate("IPv6 starting address/prefix used for IKEv2 virtual IP assignment, such as: fd42:42:42::10/120")
o.placeholder = "fd42:42:42::10/120"
o.rmempty = false
o:depends("ikev2_ipv6_enable", "1")
o.validate = validate_ipv6_cidr

o = s:option(Value, "ikev2_serverip6", translate("IKEv2 IPv6 Server IP"))
o.description = translate("IPv6 address/prefix configured on ipsec0 when IKEv2 IPv6 is enabled, such as: fd42:42:42::1/120. The address part is also sent to clients as INTERNAL_IP6_DNS.")
o.placeholder = "fd42:42:42::1/120"
o.rmempty = false
o:depends("ikev2_ipv6_enable", "1")
o.validate = validate_ipv6_cidr

o = s:option(Flag, "ikev2_ipv6_nat6_enable", translate("Enable IPv6 masquerading for IKEv2"))
o.description = translate("Masquerade IPv6 traffic from the IKEv2 IPv6 pool so ULA/private IPv6 clients can still access the Internet through the router. Disable this if you route a public IPv6 prefix to the VPN pool instead.")
o.default = 1
o.rmempty = false
o:depends("ikev2_ipv6_enable", "1")

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
