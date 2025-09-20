# luci-app-ipsec-ikev2

这是基于 `luci-app-ipsec-server` 重构后的 **IKEv2（strongSwan，PSK，多身份）** LuCI 插件，
已改名为 **luci-app-ipsec-ikev2**，并在 `uci-defaults` 中内置了从旧包名配置迁移的逻辑：
- 如检测到 `/etc/config/luci-app-ipsec-server` 且不存在 `/etc/config/luci-app-ipsec-ikev2`，则自动复制迁移。
- 首次安装也会写入 IKEv2 必需的 firewall3/iptables 规则。
