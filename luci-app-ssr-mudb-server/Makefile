# Copyright (C) 2018-2020 Lienol <lawlienol@gmail.com>
#
# This is free software, licensed under the GNU General Public License v3.
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI support for SSR Mudb Server
LUCI_DEPENDS:=+libsodium +luci-lib-jsonc +python3
LUCI_PKGARCH:=all
PKG_VERSION:=11
PKG_RELEASE:=10
PKG_DATE:=20211211

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
