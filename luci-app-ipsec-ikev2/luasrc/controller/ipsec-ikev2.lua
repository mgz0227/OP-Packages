module("luci.controller.ipsec-ikev2", package.seeall)

local fs = require "nixio.fs"
local http = require "luci.http"

function index()
    if not fs.access("/etc/config/luci-app-ipsec-ikev2") then
        return
    end

    local root = {"admin", "vpn"}
    entry(root, firstchild(), _("VPN"), 45).dependent = false

    entry({"admin","vpn","ipsec-ikev2"}, firstchild(), _("IKEv2"), 10).dependent = false
    entry({"admin","vpn","ipsec-ikev2","settings"}, cbi("ipsec-ikev2/settings"), _("基本设置"), 10).leaf = true
    entry({"admin","vpn","ipsec-ikev2","pools"},    cbi("ipsec-ikev2/pools"),    _("地址池"),   20).leaf = true
    entry({"admin","vpn","ipsec-ikev2","psk"},      cbi("ipsec-ikev2/psk"),      _("PSK 用户"), 30).leaf = true
    entry({"admin","vpn","ipsec-ikev2","status"},   template("ipsec-ikev2/status"), _("状态/诊断"), 40).leaf = true

    entry({"admin","vpn","ipsec-ikev2","export"}, call("export_conf"), _("导出配置"), 50).leaf = true
end

function export_conf()
    local path = "/etc/swanctl/swanctl.conf"
    http.header('Content-Disposition', 'attachment; filename="swanctl.conf"')
    http.prepare_content("text/plain; charset=utf-8")
    if nixio.fs.access(path) then
        http.write(nixio.fs.readfile(path))
    else
        http.write("# swanctl.conf 尚未生成。请在页面保存并应用。\n")
    end
end
