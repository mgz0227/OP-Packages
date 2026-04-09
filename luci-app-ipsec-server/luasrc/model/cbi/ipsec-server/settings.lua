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

local o = s:option(DummyValue, "ipsec-server_status", translate("Current Condition"))
o.rawhtml = true
o.cfgvalue = function(t, n)
	return '<font class="ipsec-server_status"></font>'
end

enabled = s:option(Flag, "enabled", translate("Enable"))
enabled.description = translate("Enable the IPSec VPN server. This service keeps the original IPSec Xauth PSK (IKEv1) support and also exposes pure IKEv2 PSK remote-access support.")
enabled.default = 0
enabled.rmempty = false

clientip = s:option(Value, "clientip", translate("VPN Client IP"))
clientip.description = translate("VPN client IPv4 pool start address and subnet mask, such as: 192.168.100.10/24")
clientip.optional = false
clientip.rmempty = false
clientip.validate = validate_ipv4_cidr

secret = s:option(Value, "secret", translate("Secret Pre-Shared Key"))
secret.description = translate("This PSK is shared by both IKEv1 Xauth PSK and IKEv2 PSK clients.")
secret.password = true
secret.rmempty = false

local note = s:option(DummyValue, "_ikev2_note", translate("IKEv2 Support"))
note.rawhtml = true
note.cfgvalue = function()
	return translate("IKEv2 PSK is enabled automatically together with the IPSec service. Unlike IKEv1 Xauth PSK, pure IKEv2 PSK does not use the per-user username/password list below.")
end

local ipv6 = s:option(Flag, "ikev2_ipv6_enable", translate("Enable IPv6 for IKEv2"))
ipv6.description = translate("Assign IPv6 virtual addresses to IKEv2 clients. Android and other dual-stack clients may request INTERNAL_IP6_ADDRESS during IKEv2, so enabling this avoids INTERNAL_ADDRESS_FAILURE when clients ask for IPv6.")
ipv6.default = 1
ipv6.rmempty = false

local clientip6 = s:option(Value, "clientip6", translate("IKEv2 IPv6 Client IP"))
clientip6.description = translate("VPN client IPv6 pool start address and prefix, such as: fd42:42:42::10/120")
clientip6.placeholder = "fd42:42:42::10/120"
clientip6.rmempty = true
clientip6:depends("ikev2_ipv6_enable", "1")
clientip6.validate = validate_ipv6_cidr

return m
