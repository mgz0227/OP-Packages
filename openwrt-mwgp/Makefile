include $(TOPDIR)/rules.mk

PKG_NAME:=mwgp
PKG_VERSION:=2.1.7
PKG_RELEASE:=4

PKG_SOURCE_PROTO:=git
PKG_SOURCE:=v$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/apernet/mwgp
PKG_SOURCE_VERSION:=bd3cbaa3b81f0b081c425de9ac15a54a6da5ef9a
PKG_HASH:=skip

PKG_MAINTAINER:=Apernet
PKG_LICENSE:=GPL-3.0
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0

PKG_BUILD_DEPENDS:=golang/host
include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

define Package/mwgp
	SECTION:=net
	CATEGORY:=Network
	SUBMENU:=VPN
	TITLE:=Multiple WireGuard Proxy
	URL:=https://github.com/apernet/mwgp
	DEPENDS:=$(GO_ARCH_DEPENDS) +ca-bundle
endef

define Package/mwgp/description
	mwgp is a proxy software for WireGuard traffic that supports port 
	multiplexing and experimental traffic obfuscation.
endef

# Use standard OpenWrt Go build parameters
GO_PKG:=github.com/apernet/mwgp
GO_PKG_BUILD_VARS:=CGO_ENABLED=0

# --- Size Minimization Magic ---
# -s: Omit the symbol table and debug information.
# -w: Omit the DWARF symbol table.
# -buildmode=pie: Generates position-independent executables if required.
GO_PKG_LDFLAGS:=-s -w

define Build/Prepare
	$(call Build/Prepare/Default)
	$(CP) ./files/Makefile.project $(PKG_BUILD_DIR)/Makefile
endef

define Package/mwgp/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/build/mwgp $(1)/usr/bin/mwgp
	$(INSTALL_DIR) $(1)/etc/init.d/
	$(INSTALL_BIN) ./files/mwgp.init $(1)/etc/init.d/mwgp
endef

$(eval $(call BuildPackage,mwgp))
