

include $(TOPDIR)/rules.mk

PKG_VERSION:=1.0.1-20240822
PKG_RELEASE:=6

LUCI_TITLE:=LuCI support for Vaultwarden
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+lsblk +docker +dockerd +luci-lib-taskd

define Package/luci-app-vaultwarden/conffiles
/etc/config/vaultwarden
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
