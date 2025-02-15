
local fs = require "nixio.fs"
local uci=luci.model.uci.cursor()
local a, t, e
a = Map("advancedplus")
a.title = translate("Advanced Setting")
a.description = translate("The enhanced version of the original advanced settings allows for unified setting and management of background images for kucat/Agron/Opentopd themes, without the need to upload them separately. Color schemes for kucat/Agron/design themes can be set.<br>")..
translate("At the same time, important plugin parameters can be compiled. At the same time, some system parameters can also be set, such as display and hide settings.")..
translate("</br>For specific usage, see:")..translate("<a href=\'https://github.com/sirpdboy/luci-app-advancedplus.git' target=\'_blank\'>GitHub @sirpdboy/luci-app-advancedplus </a>")

t = a:section(TypedSection, "basic", translate("Settings"))
t.anonymous = true

e = t:option(Flag, "usshmenu",translate('No backend menu required'), translate('OPENWRT backend and SSH login do not display shortcut menus'))

e = t:option(Flag, "wizard",translate('Hide Wizard'), translate('Show or hide the setup wizard menu'))
e.default = "0"
e.rmempty = false

e = t:option(Flag, "tsoset",translate('TSO optimization for network card interruption'), translate('Turn off the TSO parameters of the INTEL225 network card to improve network interruption'))
e.default = "1"
e.rmempty = false

e = t:option(Flag, "set_ttyd",translate('Allow TTYD external network access'))
e.default = "0"

e = t:option(Flag, "set_firewall_wan",translate('Set firewall wan to open'))
e.default = "0"

e = t:option(Flag, "dhcp_domain",translate('Add Android host name mapping'), translate('Resolve the issue of Android native TV not being able to connect to WiFi for the first time'))
e.default = "0"

return a
