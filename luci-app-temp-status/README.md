# luci-app-temp-status
Temperature sensors data for the LuCI status page (OpenWrt webUI).

OpenWrt >= 21.02.

**Dependences:** lua, luci-lib-nixio, luci-lib-jsonc.

## Installation notes

    wget --no-check-certificate -O /tmp/luci-app-temp-status_0.5.4-r1_all.ipk https://github.com/gSpotx2f/packages-openwrt/raw/master/current/luci-app-temp-status_0.5.4-r1_all.ipk
    opkg install /tmp/luci-app-temp-status_0.5.4-r1_all.ipk
    rm /tmp/luci-app-temp-status_0.5.4-r1_all.ipk
    /etc/init.d/rpcd reload

i18n-ru:

    wget --no-check-certificate -O /tmp/luci-i18n-temp-status-ru_0.5.4-r1_all.ipk https://github.com/gSpotx2f/packages-openwrt/raw/master/current/luci-i18n-temp-status-ru_0.5.4-r1_all.ipk
    opkg install /tmp/luci-i18n-temp-status-ru_0.5.4-r1_all.ipk
    rm /tmp/luci-i18n-temp-status-ru_0.5.4-r1_all.ipk

## Screenshots:

![](https://github.com/gSpotx2f/luci-app-temp-status/blob/master/screenshots/01.jpg)
