# SPDX-License-Identifier: MIT
# This is free software, licensed under the MIT License.

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-ipsec-ikev2
PKG_VERSION:=20250919
PKG_RELEASE:=1
LUCI_PKGARCH:=all
PKG_MAINTAINER:=miaogongzi <miaogongzi0227@gmail.com>


LUCI_TITLE:=LuCI: IKEv2 (strongSwan) PSK visual config

LUCI_DEPENDS:=+luci-base +luci-compat +strongswan-full +kmod-ipt-ipsec +iptables-mod-ipsec +dnsmasq-full +firewall

define Package/$(PKG_NAME)/conffiles
/etc/config/ikev2
endef

include $(TOPDIR)/feeds/luci/luci.mk
