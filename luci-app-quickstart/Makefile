# Copyright (C) 2016 Openwrt.org
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI support for quickstart 
LUCI_DEPENDS:=+quickstart +luci-app-ttyd +luci-i18n-ttyd-zh-cn
LUCI_PKGARCH:=all

PKG_VERSION:=0.11.1-r1
# PKG_RELEASE MUST be empty for luci.mk
PKG_RELEASE:=16

LUCI_MINIFY_CSS:=0
LUCI_MINIFY_JS:=0

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature

