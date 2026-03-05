-- Copyright 2018-2020 Lienol <lawlienol@gmail.com>
module("luci.controller.ipsec-ikev2", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/luci-app-ipsec-ikev2") then
		return
	end

	entry({"admin", "vpn"}, firstchild(), "VPN", 45).dependent = false
	entry({"admin", "vpn", "ipsec-ikev2"}, alias("admin", "vpn", "ipsec-ikev2", "settings"), _("IPSec VPN Server"), 49).dependent = false
	entry({"admin", "vpn", "ipsec-ikev2", "settings"}, cbi("ipsec-ikev2/settings"), _("General Settings"), 10).leaf = true
	entry({"admin", "vpn", "ipsec-ikev2", "users"}, cbi("ipsec-ikev2/users"), _("Users Manager"), 20).leaf = true
	entry({"admin", "vpn", "ipsec-ikev2", "l2tp_user"}, cbi("ipsec-ikev2/l2tp_user")).leaf = true
	entry({"admin", "vpn", "ipsec-ikev2", "online"}, cbi("ipsec-ikev2/online"), _("L2TP Online Users"), 30).leaf = true
	entry({"admin", "vpn", "ipsec-ikev2", "status"}, call("act_status")).leaf = true
end

function act_status()
	local e = {}
	e["ipsec_status"] = luci.sys.call("/usr/bin/pgrep ipsec >/dev/null") == 0
	e["l2tp_status"] = luci.sys.call("top -bn1 | grep -v grep | grep '/var/etc/xl2tpd' >/dev/null") == 0
	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end
