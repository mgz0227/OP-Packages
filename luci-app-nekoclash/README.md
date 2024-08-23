<h1 align="center">
  <img src="https://raw.githubusercontent.com/Thaolga/neko/main/img/neko.png" alt="neko" width="500">
</h1>

<div align="center">
 <a target="_blank" href="https://github.com/Thaolga/luci-app-nekoclash/releases"><img src="https://img.shields.io/github/downloads/nosignals/neko/total?label=Total%20Download&labelColor=blue&style=for-the-badge"></a>
 <a target="_blank" href="https://dbai.team/discord"><img src="https://img.shields.io/discord/1127928183824597032?style=for-the-badge&logo=discord&label=%20"></a>
</div>


<p align="center">
  XRAY/V2ray, Shadowsocks, ShadowsocksR, etc.</br>
  Mihomo based Proxy
</p>

# 项目更新公告：自 1.1.33 版本起引入 Sing-box 支持
---
## 我们很高兴地宣布，自 1.1.33 版本起，项目新增了对 Sing-box 的全面支持，Sing-box 需要与 firewall4 + nftables 防火墙管理功能配合使用。这一更新极大地提升了系统的灵活性与安全性，使得用户可以更加精确地控制流量管理策略。

- Sing-box 支持：集成了 Sing-box，并要求配合 firewall4 + nftables 使用，为您带来更加智能化和高效的流量管理方案。

## 值得注意的是，尽管此版本大幅增强了系统功能，原 Mihomo 相关功能保持不变，用户依然可以享受稳定的服务体验。


# openwrt一键安装脚本
---

```bash
wget -O /root/nekoclash.sh https://raw.githubusercontent.com/Thaolga/luci-app-nekoclash/main/nekoclash.sh && chmod 0755 /root/nekoclash.sh && /root/nekoclash.sh

```

# openwrt编译
---
## 克隆源码 :
---

```bash
git clone https://github.com/luci-app-nekoclash  package/luci-app-nekoclash

```

## 编译 :
---

```bash
make package/luci-app-nekoclash/{clean,compile} V=s
```
# Screenshoot
---
<details><summary>Home</summary>
 <p>
 <img src="https://raw.githubusercontent.com/Thaolga/neko/main/img/ge.png" alt="home" >
 </p>
</details>

 <details><summary>Dasboard</summary>
 <p>
 <img src="https://raw.githubusercontent.com/Thaolga/neko/main/img/im.png" >
 </p>
</details>
