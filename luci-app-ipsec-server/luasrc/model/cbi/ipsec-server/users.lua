m = Map("luci-app-ipsec-server")

s = m:section(TypedSection, "ipsec_users", "IPSec Xauth PSK " .. translate("Users Manager"))
s.description = translate("These accounts are used by IPSec Xauth PSK (IKEv1) clients. Pure IKEv2 PSK clients authenticate with the global pre-shared key only.")
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection"

o = s:option(Flag, "enabled", translate("Enabled"))
o.default = 1
o.rmempty = false

o = s:option(Value, "username", translate("Username"))
o.placeholder = translate("Username")
o.rmempty = false

o = s:option(Value, "password", translate("Password"))
o.placeholder = translate("Password")
o.rmempty = false

return m
