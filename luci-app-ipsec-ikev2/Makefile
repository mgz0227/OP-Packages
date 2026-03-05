# Copyright (C) 2018-2021 Lienol <lawlienol@gmail.com>
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-ipsec-ikev2
PKG_VERSION:=20250923
PKG_RELEASE:=24

PKG_MAINTAINER:=miaogongzi 

LUCI_TITLE:=LuCI support for IPSec VPN ikev2 Server
LUCI_DEPENDS:=+kmod-tun +luci-lib-jsonc +strongswan +strongswan-minimal +strongswan-mod-kernel-libipsec +strongswan-mod-openssl +strongswan-mod-xauth-generic +xl2tpd
LUCI_PKGARCH:=all

define Package/$(PKG_NAME)/conffiles
/etc/config/luci-app-ipsec-ikev2
endef

include $(TOPDIR)/feeds/luci/luci.mk

$(eval $(call BuildPackage,$(PKG_NAME)))
# call BuildPackage - OpenWrt buildroot signature
