# SPDX-License-Identifier: MIT
# This is free software, licensed under the MIT License.

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-ipsec-ikev2
PKG_VERSION:=2025.09.20
PKG_RELEASE:=10

PKG_LICENSE:=MIT
PKG_MAINTAINER:=miaogongzi <miaogongzi0227@gmail.com>

LUCI_TITLE:=LuCI: IPsec IKEv2 (strongSwan) Server

# 兼容不同分支/构建：
# - strongswan-full 或 strongswan（二选其一）
# - firewall 或 firewall4
# - 只有 firewall(fw3) 时才拉取 iptables/ipsec 模块
LUCI_DEPENDS:= \
  +luci-compat \
  +PACKAGE_strongswan-full:strongswan-full \
  +PACKAGE_strongswan:strongswan \
  +PACKAGE_firewall:firewall +PACKAGE_firewall4:firewall4 \
  +PACKAGE_firewall:kmod-ipt-ipsec +PACKAGE_firewall:iptables-mod-ipsec \
  +strongswan-minimal \
  +strongswan-mod-kernel-libipsec 
  +kmod-tun
  +dnsmasq-full

define Package/$(PKG_NAME)/conffiles
/etc/config/luci-app-ipsec-ikev2
endef

include $(TOPDIR)/feeds/luci/luci.mk

$(eval $(call BuildPackage,$(PKG_NAME)))
