# luci-app-ipsec-ikev2

OpenWrt 的 IKEv2（strongSwan，PSK，多身份）LuCI 插件。
使 `Depends:` 在 IPK 控制文件中明确包含 strongSwan/firewall/dnsmasq-full 等依赖。

## 构建
```bash
./scripts/feeds update -a && ./scripts/feeds install -a
make menuconfig  # LuCI -> Applications -> luci-app-ipsec-ikev2
make package/luci-app-ipsec-ikev2/compile V=s
```
