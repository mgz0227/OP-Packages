
include $(TOPDIR)/rules.mk

PKG_VERSION:=1.0.5-20241208
PKG_RELEASE:=5
PKG_MAINTAINER:=jjm2473 <jjm2473@gmail.com>

LUCI_TITLE:=Easy Access AP / Modem
LUCI_PKGARCH:=all

define Package/luci-app-ap-modem/conffiles
/etc/config/ap_modem
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
