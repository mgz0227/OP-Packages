

include $(TOPDIR)/rules.mk

PKG_VERSION:=1.1.0-1
PKG_RELEASE:=7
PKG_MAINTAINER:=jjm2473 <jjm2473@gmail.com>

LUCI_TITLE:=LuCI realtime client bandwidth monitor
LUCI_PKGARCH:=all

define Package/luci-app-rtbwmon/prerm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
    /usr/libexec/rtbwmon.sh prerm
fi
exit 0
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
