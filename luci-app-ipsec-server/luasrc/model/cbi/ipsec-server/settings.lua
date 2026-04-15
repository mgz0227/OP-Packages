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
enabled.description = translate("IPSec VPN connectivity using the native built-in VPN Client on iOS or Andriod (IKEv2 PSK & IKEv1 Xauth PSK)<br />IKEv2 Client Mention:<br />Android Client Plsease Set IPsec Identifier With PSK<br />IOS Client Plsease Set Remote ID With PSK")
enabled.default = 0
enabled.rmempty = false

clientip = s:option(Value, "clientip", translate("VPN Client IP"))
clientip.description = translate("VPN Client reserved started IP addresses with the same subnet mask, such as: 10.0.10.0/24")
clientip.datatype = "ip4addr"
clientip.optional = false
clientip.rmempty = false

serverip = s:option(Value, "serverip", translate("VPN Server IP"))
serverip.description = translate("VPN Server reserved started IP addresses with the same subnet mask, such as: 10.0.0.1/24")
serverip.datatype = "ip4addr"
serverip.optional = false
serverip.rmempty = false

secret = s:option(Value, "secret", translate("Secret Pre-Shared Key"))
secret.password = true

return m
