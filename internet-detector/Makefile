#
# (с) 2025 gSpot (https://github.com/gSpotx2f/luci-app-internet-detector)
#

include $(TOPDIR)/rules.mk

PKG_NAME:=internet-detector
PKG_VERSION:=1.6.1
PKG_RELEASE:=19
PKG_MAINTAINER:=gSpot <https://github.com/gSpotx2f/luci-app-internet-detector>

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Internet detector
  URL:=https://github.com/gSpotx2f/luci-app-internet-detector
  PKGARCH:=all
  DEPENDS:=+lua +luaposix +libuci-lua
endef

define Package/$(PKG_NAME)/description
  Internet-detector is a small daemon
  for checking Internet availability.
  Written in Lua using the luaposix library.
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/internet-detector
/etc/internet-detector/down-script.internet
/etc/internet-detector/up-script.internet
/etc/internet-detector/public-ip-script.internet
/etc/internet-detector/regular-script.internet
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/internet-detector $(1)/etc/config/internet-detector
	$(INSTALL_DIR) $(1)/etc/internet-detector
	$(INSTALL_DATA) ./files/etc/internet-detector/down-script.internet $(1)/etc/internet-detector/down-script.internet
	$(INSTALL_DATA) ./files/etc/internet-detector/up-script.internet $(1)/etc/internet-detector/up-script.internet
	$(INSTALL_DATA) ./files/etc/internet-detector/public-ip-script.internet $(1)/etc/internet-detector/public-ip-script.internet
	$(INSTALL_DATA) ./files/etc/internet-detector/regular-script.internet $(1)/etc/internet-detector/regular-script.internet
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/internet-detector $(1)/etc/init.d/internet-detector
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/internet-detector $(1)/usr/bin/internet-detector
	$(INSTALL_DIR) $(1)/usr/lib/lua/internet-detector
	$(INSTALL_DATA) ./files/usr/lib/lua/internet-detector/main.lua $(1)/usr/lib/lua/internet-detector/main.lua
	$(INSTALL_DATA) ./files/usr/lib/lua/internet-detector/init.lua $(1)/usr/lib/lua/internet-detector/init.lua
	$(INSTALL_DIR) $(1)/usr/lib/lua/internet-detector/modules
	$(INSTALL_DATA) ./files/usr/lib/lua/internet-detector/modules/mod_led_control.lua $(1)/usr/lib/lua/internet-detector/modules/mod_led_control.lua
	$(INSTALL_DATA) ./files/usr/lib/lua/internet-detector/modules/mod_reboot.lua $(1)/usr/lib/lua/internet-detector/modules/mod_reboot.lua
	$(INSTALL_DATA) ./files/usr/lib/lua/internet-detector/modules/mod_network_restart.lua $(1)/usr/lib/lua/internet-detector/modules/mod_network_restart.lua
	$(INSTALL_DATA) ./files/usr/lib/lua/internet-detector/modules/mod_public_ip.lua $(1)/usr/lib/lua/internet-detector/modules/mod_public_ip.lua
	$(INSTALL_DATA) ./files/usr/lib/lua/internet-detector/modules/mod_user_scripts.lua $(1)/usr/lib/lua/internet-detector/modules/mod_user_scripts.lua
	$(INSTALL_DATA) ./files/usr/lib/lua/internet-detector/modules/mod_regular_script.lua $(1)/usr/lib/lua/internet-detector/modules/mod_regular_script.lua
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
