#
# (с) 2025 gSpot (https://github.com/gSpotx2f/luci-app-internet-detector)
#

include $(TOPDIR)/rules.mk

PKG_NAME:=internet-detector-mod-telegram
PKG_VERSION:=1.6.1
PKG_RELEASE:=2
PKG_MAINTAINER:=gSpot <https://github.com/gSpotx2f/luci-app-internet-detector>

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Telegram messenger module for internet-detector
  URL:=https://github.com/gSpotx2f/luci-app-internet-detector
  PKGARCH:=all
  DEPENDS:=+internet-detector +curl
endef

define Package/$(PKG_NAME)/description
  Telegram messenger support for internet-detector.
endef

define Package/$(PKG_NAME)/conffiles
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/internet-detector/modules
	$(INSTALL_DATA) ./files/usr/lib/lua/internet-detector/modules/mod_telegram.lua $(1)/usr/lib/lua/internet-detector/modules/mod_telegram.lua
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
