

include $(TOPDIR)/rules.mk

PKG_VERSION:=1.0.0-20240822
PKG_RELEASE:=7

LUCI_TITLE:=LuCI support for Penpot
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+lsblk +docker +dockerd +luci-lib-taskd +docker-compose

define Package/luci-app-penpot/conffiles
/etc/config/penpot
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
