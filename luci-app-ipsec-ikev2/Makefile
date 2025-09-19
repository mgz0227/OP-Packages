# SPDX-License-Identifier: MIT
# This is free software, licensed under the MIT License.

include $(TOPDIR)/rules.mk


define Package/$(PKG_NAME)
  PKG_VERSION:=20250919
  PKG_RELEASE:=5
  LUCI_PKGARCH:=all
  PKG_MAINTAINER:=miaogongzi <miaogongzi0227@gmail.com>
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI: IKEv2 (strongSwan) PSK visual config
  DEPENDS:=+kmod-tun +luci-lib-jsonc +strongswan +strongswan-minimal \
           +strongswan-mod-kernel-libipsec +strongswan-mod-openssl +strongswan-mod-xauth-generic
endef

define Package/$(PKG_NAME)/description
  LuCI configuration interface for IKEv2 PSK using strongSwan.
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/luci-app-ipsec-ikev2
endef

include $(TOPDIR)/feeds/luci/luci.mk
