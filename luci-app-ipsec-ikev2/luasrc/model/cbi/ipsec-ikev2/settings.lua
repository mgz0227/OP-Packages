local sys  = require "luci.sys"
local uci  = require "luci.model.uci".cursor()
local dsp  = require "luci.dispatcher"
local fs   = require "nixio.fs"

m = Map("luci-app-ipsec-ikev2", translate("IKEv2 (strongSwan) - PSK"),
    translate("通过 LuCI 可视化配置 IKEv2 PSK（预共享密钥）。保存并应用后自动生成 swanctl.conf 并重载 strongSwan。"))

m.apply_on_parse = true

s = m:section(TypedSection, "global", translate("全局设置"))
s.anonymous = true
s.addremove = false

en = s:option(Flag, "enabled", translate("启用"))
en.rmempty = false
en.default = en.enabled

listen = s:option(Value, "listen", translate("监听地址"),
    translate("留空=自动；可填 IPv4/IPv6 或 %any。通常监听在 WAN 地址。"))
listen.placeholder = "%any"

leftid = s:option(Value, "leftid", translate("服务端 ID (LeftID)"),
    translate("建议使用你的 VPN 域名或唯一标识，客户端“远程 ID/服务器 ID”需与之匹配。"))
leftid.placeholder = "vpn.example.com"

-- 业务模式
mode = s:option(ListValue, "mode", translate("业务模式"),
    translate("全量出口=客户端访问内网并经内网访问外网；仅内网=只访问内网；自定义=自行填写分流网段。"))
mode:value("full", translate("全量出口（访问内网 + 经内网访问外网）"))
mode:value("lan",  translate("仅内网访问"))
mode:value("custom", translate("自定义"))
mode.default = "full"

global_psk = s:option(Value, "global_psk", translate("全局 PSK（可选）"),
    translate("如果填写，则所有客户端可使用该密钥；若留空，则只允许“PSK 用户”表中的身份连接。"))
global_psk.password = true

ikep = s:option(Value, "ike_proposals", translate("IKE 提议"))
ikep.placeholder = "aes256-sha256-prfsha256-modp2048,aes256gcm16-prfsha256-modp2048"

espp = s:option(Value, "esp_proposals", translate("ESP 提议"))
espp.placeholder = "aes256-sha256-modp2048,aes256gcm16-modp2048"

mobike = s:option(Flag, "mobike", translate("启用 MOBIKE"))
mobike.default = mobike.enabled

frag = s:option(Flag, "fragmentation", translate("启用 IKEv2 分片"))
frag.default = frag.enabled

dpd  = s:option(Value, "dpd_delay", translate("DPD 间隔 (秒)"))
dpd.datatype = "uinteger"
dpd.placeholder = "30"

pool = s:option(ListValue, "pool", translate("地址池"))
uci:foreach("luci-app-ipsec-ikev2", "pool", function(sec) pool:value(sec[".name"]) end)
pool.rmempty = false

dns = s:option(DynamicList, "dns", translate("推送 DNS 服务器"),
    translate("为空则不下发；也可在地址池中单独设置。默认会尝试使用路由器 LAN IP。"))
dns.datatype = "ipaddr"

split = s:option(DynamicList, "split_subnets", translate("内网分流网段（自定义模式专用）"),
    translate("仅当“业务模式=自定义”时生效。示例：192.168.1.0/24、10.0.0.0/8、::/0。"))
split.datatype = "ipaddr"

rekey = s:option(Value, "rekey_time", translate("ChildSA 重协商间隔 (秒)"))
rekey.datatype = "uinteger"
rekey.placeholder = "3600"

start_action = s:option(ListValue, "start_action", translate("启动动作"))
start_action:value("trap", "trap（按需建立）")
start_action:value("start", "start（启动即建立）")
start_action.default = "trap"

ensure_masq = s:option(Flag, "ensure_wan_masq", translate("确保 WAN 出口 NAT (MASQUERADE)"))
ensure_masq.default = ensure_masq.enabled

function m.on_after_commit(self)
    sys.call("/etc/init.d/luci-app-ipsec-ikev2 reload >/dev/null 2>&1")
end

-- 预填 LAN IP 为 DNS
local lan_ip = uci:get("network", "lan", "ipaddr")
if lan_ip then
    dns:value(lan_ip)
end

return m
