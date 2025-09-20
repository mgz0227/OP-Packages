# luci-app-ipsec-ikev2

OpenWrt 的 IKEv2（strongSwan，PSK，多身份）LuCI 插件。遵循官方打包规范：
- 使用 `luci.mk` 最小模板（依赖/语言包自动处理、前端资源压缩）
- procd init（/etc/init.d/luci-app-ipsec-ikev2）
- uci-defaults（首次写 firewall 规则 & 从旧包 `luci-app-ipsec-server` 迁移配置）
- ACL（/usr/share/rpcd/acl.d/luci-app-ipsec-ikev2.json）

## 依赖（Makefile 已声明）
- strongSwan（`strongswan` 或 `strongswan-full`，按分支可用性选择）
- firewall 或 firewall4（分支不同）
- firewall(fw3) 下需要 `kmod-ipt-ipsec` 与 `iptables-mod-ipsec`
- dnsmasq-full（用于向客户端下发 DNS）

## 构建
```bash
./scripts/feeds update -a && ./scripts/feeds install -a
make menuconfig  # LuCI -> Applications -> luci-app-ipsec-ikev2
make package/luci-app-ipsec-ikev2/compile V=s
```

## LuCI 页面
VPN → IKEv2 → 基本设置 / 地址池 / PSK 用户 / 状态/诊断
