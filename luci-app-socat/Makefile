# Copyright (C) 2020 Lienol <lawlienol@gmail.com>
#
# This is free software, licensed under the GNU General Public License v3.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-socat
PKG_VERSION:=1.0
PKG_RELEASE:=17

PKG_MAINTAINER:=Lienol <lawlienol@gmail.com>

LUCI_TITLE:=LuCI support for Socat
LUCI_DEPENDS:=+socat
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
