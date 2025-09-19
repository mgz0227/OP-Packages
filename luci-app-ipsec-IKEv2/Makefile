# SPDX-License-Identifier: MIT
# This is free software, licensed under the MIT License.

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-ipsec-ikev2
PKG_VERSION:=2025.09.19
PKG_RELEASE:=1

PKG_LICENSE:=MIT

PKG_MAINTAINER:=miaogongzi <miaogongzi0227@gmail.com>


LUCI_TITLE:=LuCI: IKEv2 (strongSwan) PSK visual config (中文优化)

LUCI_DEPENDS:=+luci-base +luci-compat +strongswan-full +kmod-ipt-ipsec +iptables-mod-ipsec +dnsmasq-full +firewall

define Package/$(PKG_NAME)/conffiles
/etc/config/ikev2
endef

include $(TOPDIR)/feeds/luci/luci.mk
