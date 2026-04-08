m = Map("luci-app-ipsec-server")

s = m:section(TypedSection, "ipsec_users", translate("IPSec Xauth PSK / IKEv2 EAP Users Manager"))
s.description = translate("These accounts can be used for both IPSec Xauth PSK and IKEv2 EAP-MSCHAPv2.")
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
