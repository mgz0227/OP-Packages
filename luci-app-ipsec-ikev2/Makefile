# SPDX-License-Identifier: MIT
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-ipsec-ikev2
PKG_VERSION:=2025.09.20
PKG_RELEASE:=12
PKG_MAINTAINER:=miaogongzi <miaogongzi0227@gmail.com>

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/config
	config PACKAGE_strongswan-full
		default y if PACKAGE_$(PKG_NAME)

	config PACKAGE_strongswan
		default y if PACKAGE_$(PKG_NAME) && ! PACKAGE_strongswan-full

	config PACKAGE_firewall4
		default y if PACKAGE_$(PKG_NAME)

	config PACKAGE_firewall
		default y if PACKAGE_$(PKG_NAME) && ! PACKAGE_firewall4
endef

define Package/$(PKG_NAME)
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI: IPsec IKEv2 (strongSwan) Server
  PKGARCH:=all
  DEPENDS:= \
    +luci-compat +dnsmasq-full \
    +PACKAGE_strongswan-full:strongswan-full \
    +PACKAGE_strongswan:strongswan \
    +(firewall||firewall4) \
    +PACKAGE_firewall:kmod-ipt-ipsec \
    +PACKAGE_firewall:iptables-mod-ipsec \
    +kmod-tun

  MAINTAINER:=miaogongzi <miaogongzi0227@gmail.com>
endef


define Package/$(PKG_NAME)/description
	OpenWrt LuCI for IPsec IKEv2 (strongSwan). PSK 多身份、地址池、诊断、自动防火墙规则与 NAT 检查。
endef

define Build/Prepare
	$(CP) $(CURDIR)/root $(PKG_BUILD_DIR)/
	$(CP) $(CURDIR)/luasrc $(PKG_BUILD_DIR)/
	$(foreach po,$(wildcard ${CURDIR}/po/zh_Hans/*.po), \
		po2lmo $(po) $(PKG_BUILD_DIR)/$(patsubst %.po,%.lmo,$(notdir $(po)));)
	chmod 0755 $(PKG_BUILD_DIR)/root/etc/init.d/luci-app-ipsec-ikev2
	chmod 0755 $(PKG_BUILD_DIR)/root/etc/uci-defaults/luci-app-ipsec-ikev2
	chmod 0755 $(PKG_BUILD_DIR)/root/usr/libexec/ipsec-ikev2/genconfig.sh
	exit 0
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/luci-app-ipsec-ikev2
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/*.*.lmo $(1)/usr/lib/lua/luci/i18n/
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/
	$(CP) $(PKG_BUILD_DIR)/luasrc/* $(1)/usr/lib/lua/luci/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
