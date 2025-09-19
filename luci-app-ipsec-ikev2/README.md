# luci-app-ipsec-ikev2

IKEv2（strongSwan，PSK & 多身份）LuCI 插件，遵循 OpenWrt 打包规范：
- 使用 `luci.mk`（自动 i18n、压缩、打包）
- 提供 `/etc/init.d/luci-app-ipsec-ikev2`（procd + reload 触发）
- `conffiles` 声明 `/etc/config/luci-app-ipsec-ikev2`
- `uci-defaults` 首次安装部署防火墙规则
