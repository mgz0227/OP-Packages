

include $(TOPDIR)/rules.mk

PKG_VERSION:=1.1.1-20240822
PKG_RELEASE:=6

LUCI_TITLE:=LuCI support for jackett
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+lsblk +docker +dockerd +luci-lib-taskd

define Package/luci-app-jackett/conffiles
/etc/config/jackett
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature

