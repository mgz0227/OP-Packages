# Copyright (C) 2016 Openwrt.org
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI support for floatip
LUCI_DEPENDS:=+floatip
LUCI_PKGARCH:=all
PKG_VERSION:=0.1.3-r1
# PKG_RELEASE MUST be empty for luci.mk
PKG_RELEASE:=6

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature

