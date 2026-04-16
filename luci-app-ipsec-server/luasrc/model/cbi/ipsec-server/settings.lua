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

domain = s:option(Value, "domain", translate("VPN Domain"))
domain.description = translate("Domain name used for IKEv2 certificate and Remote ID, such as: ns.miaogongzi.cc")
domain.datatype = "host"
domain.optional = false
domain.rmempty = false
domain.placeholder = "ns.miaogongzi.cc"

certs_name = s:option(Value, "certs_name", translate("Certificate File Name"))
certs_name.description = translate("Server certificate file name under /etc/ipsec.d/certs/, such as: server.pem")
certs_name.optional = false
certs_name.rmempty = false
certs_name.placeholder = "server.pem"

private_key = s:option(Value, "private_key", translate("Private Key File Name"))
private_key.description = translate("Server private key file name under /etc/ipsec.d/private/, such as: server_key.pem")
private_key.optional = false
private_key.rmempty = false
private_key.placeholder = "server_key.pem"

secret = s:option(Value, "secret", translate("Secret Pre-Shared Key"))
secret.password = true

return m
