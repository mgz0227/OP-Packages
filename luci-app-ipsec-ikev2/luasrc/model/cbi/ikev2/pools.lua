m = Map("ikev2", translate("地址池"),
    translate("为远端用户分配虚拟地址，可用 CIDR（10.10.10.0/24）或范围（10.10.10.10-10.10.10.200）。"))

s = m:section(TypedSection, "pool", translate("地址池条目"))
s.addremove = true
s.anonymous = false
s.template = "cbi/tsection"

addrs = s:option(Value, "addrs", translate("地址段/CIDR/范围"))
addrs.datatype = "string"
addrs.placeholder = "10.10.10.0/24"

dns = s:option(DynamicList, "dns", translate("DNS（可选，覆盖全局）"))
dns.datatype = "ipaddr"

return m
