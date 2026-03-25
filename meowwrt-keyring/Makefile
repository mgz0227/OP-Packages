include $(TOPDIR)/rules.mk

PKG_NAME:=meowwrt-keyring
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/meowwrt-keyring
  SECTION:=base
  CATEGORY:=Base system
  TITLE:=MeowWrt APK repository keyring
endef

define Package/meowwrt-keyring/description
  Install MeowWrt APK public key.
endef

Build/Compile=

define Package/meowwrt-keyring/install
	$(INSTALL_DIR) $(1)/etc/apk/keys
	$(INSTALL_DATA) $(CURDIR)/files/MeowWrt-Public-key.pem $(1)/etc/apk/keys/
endef

$(eval $(call BuildPackage,meowwrt-keyring))
