# SPDX-License-Identifier: MIT
# This is free software, licensed under the MIT License.

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-ipsec-ikev2
PKG_VERSION:=2025.09.19
PKG_RELEASE:=9

PKG_MAINTAINER:=miaogongzi <miaogongzi0227@gmail.com>
LUCI_PKGARCH:=all

define Package/$(PKG_NAME)
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI: IKEv2 (strongSwan) PSK visual config
  LUCI_DEPENDS:=+kmod-tun +luci-lib-jsonc +luci-base +luci-compat +strongswan-full +kmod-ipt-ipsec +iptables-mod-ipsec +dnsmasq-full +firewall
# LUCI_PKGARCH defaults to 'all' (from luci.mk) for non-binary packages
endef



define Package/$(PKG_NAME)/conffiles
/etc/config/luci-app-ipsec-ikev2
endef
 
include $(TOPDIR)/feeds/luci/luci.mk

$(eval $(call BuildPackage,$(PKG_NAME)))