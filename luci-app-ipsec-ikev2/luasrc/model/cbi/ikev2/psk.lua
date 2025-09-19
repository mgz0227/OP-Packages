m = Map("ikev2", translate("PSK 用户"),
    translate("为不同远端身份（IDi）配置各自的预共享密钥。若留空全局 PSK，则只有此处列出的身份可连接。"))

s = m:section(TypedSection, "psk_user", translate("PSK 条目"))
s.addremove = true
s.anonymous = false
s.template = "cbi/tsection"

idv = s:option(Value, "id", translate("远端身份 (IDi)"),
    translate("例如 user1、alice@example.com、或某 FQDN；需与客户端“本机 ID/远端身份”一致。"))
idv.datatype = "string"

psk = s:option(Value, "psk", translate("预共享密钥"))
psk.password = true

note = s:option(Value, "note", translate("备注（可选）"))
note.datatype = "string"

return m
