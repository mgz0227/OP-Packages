# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026 OneNAS/RouteONE, Jackie264 (jackie@onenas.space).

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-beszel-agent
PKG_LICENSE:=AGPL-3.0-or-later
PKG_CPE_ID:=cpe:/a:Jackie264:luci-app-beszel-agent
PKG_MAINTAINER:=Jackie264 <OneNAS-space>

LUCI_TITLE:=LuCI support for Beszel Agent
LUCI_URL:=https://github.com/OneNAS-space/luci-app-beszel-agent/
LUCI_DESCRIPTION:=Provides Web UI (found under Services/Beszel Agent) to config Beszel Agent
LUCI_DEPENDS:=+beszel-agent
LUCI_PKGARCH:=all

PKG_UNPACK:=/bin/sh $(CURDIR)/.prepare.sh $(PKG_NAME) $(CURDIR) $(PKG_BUILD_DIR)

define Package/$(PKG_NAME)/config
# shown in make menuconfig <Help>
help
	$(LUCI_TITLE)
	.
	Version: $(PKG_VERSION)-$(PKG_RELEASE)
endef

define Package/luci-app-beszel-agent/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || { 
    rm -f /tmp/luci-indexcache.*
    rm -rf /tmp/luci-modulecache/
    /etc/init.d/rpcd reload 2>/dev/null
}
exit 0
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
