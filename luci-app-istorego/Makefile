# Copyright (C) 2016 Openwrt.org
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI support for istorego 
LUCI_DEPENDS:=+docker +dockerd +luci-lib-taskd
LUCI_PKGARCH:=all

PKG_VERSION:=0.0.3
# PKG_RELEASE MUST be empty for luci.mk
PKG_RELEASE:=3

LUCI_MINIFY_CSS:=0
LUCI_MINIFY_JS:=0

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature

