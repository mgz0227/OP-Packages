

include $(TOPDIR)/rules.mk

PKG_VERSION:=1.0.2-20240822
PKG_RELEASE:=6

LUCI_TITLE:=LuCI support for TypeCho
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+lsblk +docker +dockerd +luci-lib-taskd +luci-lib-docker

define Package/luci-app-typecho/conffiles
/etc/config/typecho
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
