module("luci.controller.ikev2", package.seeall)

local fs = require "nixio.fs"
local sys = require "luci.sys"

function index()
    if not fs.access("/etc/config/ikev2") then
        return
    end

    local root = {"admin", "vpn"}
    entry(root, firstchild(), _("VPN"), 45).dependent = false

    local page = entry({"admin", "vpn", "ikev2"}, firstchild(), _("IKEv2"), 10)
    page.icon = "vpn"

    entry({"admin", "vpn", "ikev2", "general"}, cbi("ikev2/general"), _("基本设置"), 10).leaf = true
    entry({"admin", "vpn", "ikev2", "pools"},   cbi("ikev2/pools"),   _("地址池"),   20).leaf = true
    entry({"admin", "vpn", "ikev2", "psk"},     cbi("ikev2/psk"),     _("PSK 用户"), 30).leaf = true
    entry({"admin", "vpn", "ikev2", "status"},  template("ikev2/status"), _("状态/诊断"), 40).leaf = true

    -- 导出 swanctl.conf（便于查看/备份）
    entry({"admin", "vpn", "ikev2", "export"}, call("action_export"), _("导出配置"), 50).leaf = true
end

function action_export()
    local path = "/etc/swanctl/swanctl.conf"
    luci.http.header('Content-Disposition', 'attachment; filename="swanctl.conf"')
    luci.http.prepare_content("text/plain")
    if nixio.fs.access(path) then
        luci.http.write(nixio.fs.readfile(path))
    else
        luci.http.write("# swanctl.conf 尚未生成。请在页面保存并应用。\\n")
    end
end
