include $(TOPDIR)/rules.mk

PKG_NAME:=MeowWrt-keyring
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/MeowWrt-keyring
  SECTION:=base
  CATEGORY:=Base system
  TITLE:=MeowWrt APK repository keyring
endef

define Package/MeowWrt-keyring/description
  Install MeowWrt APK public key into /etc/apk/keys.
endef

Build/Compile=

define Package/MeowWrt-keyring/install
	$(INSTALL_DIR) $(1)/etc/apk/keys
	$(INSTALL_DATA) $(CURDIR)/files/MeowWrt-Public-key.pem $(1)/etc/apk/keys/
endef

$(eval $(call BuildPackage,MeowWrt-keyring))