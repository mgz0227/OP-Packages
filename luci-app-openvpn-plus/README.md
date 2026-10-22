# luci-app-openvpn-plus

Modern and easy web interface to configure OpenVPN servers and clients on OpenWrt.

## Description

This package provides a modern, all-in-one web interface to configure OpenVPN servers and clients quickly. Featuring a built-in key generator, setup wizard, Flood Guard protocol protection, DDNS, SSL-VPN, and profile import/export via QR-code, your VPN is ready to use immediately.

Thanks to this simple application, **anyone can build a professional SSL/TLS-VPN network now**. You do not need to understand complex crypto keys or write config files. The app does all the hard background work for you. With the step-by-step wizard, you can create secure VPN connections for travel and mobile devices in seconds.

Setting up your mobile phone is incredibly easy—just scan the secure QR-code on your screen with your smartphone camera. In the past, running a VPN behind internet provider modems was very complex. To fix this, the app includes smart Double-NAT detection and automated live port checking. This makes the installation completely effortless and brings professional, enterprise-grade VPN features straight to standard OpenWrt routers.

**High Performance for Affordable Hardware:** You don't need expensive enterprise equipment. Thanks to native **OpenVPN Data Channel Offload (DCO)** integration and our automatic MTU engine, the app achieves outstanding throughput rates—matching the speed of Wireguard even on budget-friendly wireless access points.

## 📊 Real-World Performance Benchmarks (iperf3)

We tested the real-world performance of `luci-app-openvpn-plus` using two affordable **Zyxel NWA50AX Pro** wireless access points. Both devices run as pure APs behind standard internet provider modems.

Even though the traffic has to pass through **Double-NAT** and simple port forwardings, the performance matches expensive enterprise hardware:

### 🔹 Test A: Site-to-Site Tunnel (UDP Mode)
- **Setup:** Zyxel AP ↔️ WAN Router ↔️ Internet ↔️ WAN Router ↔️ Zyxel AP
- **Network Status:** Both routers are behind Double-NAT.
- **Benchmark Result:** **450+ Mbit/s** 🚀
- *The crypto load is perfectly split across multiple CPU cores thanks to OpenVPN DCO and our automatic MTU engine.*

### 🔸 Test B: Mobile Client / Roadwarrior (TCP / SSL-VPN Mode)
- **Setup:** Zyxel AP ↔️ WAN Router ↔️ Internet ↔️ Smartphone with OpenVPN App
- **Network Status:** The server AP is behind Double-NAT
- **Benchmark Result:** **200+ Mbit/s** 📱
- *This is the absolute maximum for a single CPU core under TCP. It bypasses strict public firewalls easily while keeping your smartphone connection incredibly fast.*

## Features

- **Easy Setup:** Build fully working OpenVPN servers or clients in seconds.
- **Connection Wizard:** Simple step-by-step setup for mobile phones (Roadwarrior), laptops, and router-to-router networks (**Site-to-Site with Multi-Clients Routing**).
- **Enterprise-Grade Speeds (DCO Support):** Out-of-the-box support for OpenVPN Data Channel Offload (DCO) to shift crypto processing directly into the Linux kernel, matching Wireguard performance.
- **Smart MTU Engine:** Automatically calculates and tunes packet sizes to eliminate fragmentation, splitting the crypto load perfectly across multiple CPU cores.
- **Secure Site-to-Site Routing:** Built-in `iroute()` hook dynamically maps matching subnets and includes dynamic Anti-Loop Prevention to automatically block internal routing loops and prevent kernel freezes.
- **Instant Mobile QR-Code Scan:** Shows a secure QR-code after setup. You can scan it with your phone camera to import the settings into the OpenVPN Mobile Connect app instantly.
- **Effortless Installation & Troubleshooting:** Built-in Double-NAT detection and automated live port-open checking make the first startup easy, even behind strict provider modems.
- **OpenVPN over TCP 443 (SSL-VPN):** Special travel-friendly presets to bypass strict public firewalls by hiding VPN traffic as standard HTTPS web traffic, achieving speeds over 200 Mbps on modern networks.
- **Built-in DDNS Daemon:** Automatically updates your VPN connection using built-in support for DuckDNS, IPv64, dynv6, Dynu, and No-IP.
- **Flood Guard (Protocol Protection):** Detects, bans, and drops malicious requests and port-scanning bots in the Linux kernel before they can flood the OpenVPN process.
- **Automated Firewall Zones:** Automatically creates all needed firewall zones, traffic rules, and port forwardings.
- **High-Security Keygen & Export:** Automatically builds RSA-2048/ECC-Prime256 keys, DH parameters, and TLS-crypt-v2, then packs them into one `.ovpn` file.
- **Hardware Crypto Optimization:** Smart cipher settings select fast hardware encryption (AES-GCM) for powerful chips, or optimized software encryption (CHACHA20-POLY1305) for older routers to keep speeds high.
- **Integrated Key Editor:** View, edit, download, and check key files and expiration dates directly inside your web browser.
- **Simple Profile Import & Export:** Upload existing `.ovpn` profiles or multi-key configuration files to start new client connections instantly.
- **Clear Status Table:** Shows a small overview of running tunnels, active process IDs (PIDs), encryption types, and live data transfer.

## Configuration Layout

The application manages settings inside `/etc/config/openvpn`:

```ini
config openvpn 'instance1'
	option enabled '0'
	option role 'server'
	option config '/etc/openvpn/luci/instance1.conf'
```

## Screenshots

<table>
  <tr>
	<td><img width="2442" height="1844" alt="01" src="https://github.com/user-attachments/assets/5f215704-c18e-42ba-9228-c100635d3836" /></td>
    <td><img width="2398" height="1700" alt="03" src="https://github.com/user-attachments/assets/10ee2c26-6ca8-42c5-9f1e-04f73fb9c91c" /></td>
	<td><img width="2384" height="1706" alt="04" src="https://github.com/user-attachments/assets/86f7c341-37e2-4be9-8b7a-458cff1cc722" /></td>
  </tr>
  <tr>
	<td><img width="1796" height="556" alt="09" src="https://github.com/user-attachments/assets/c2d2b23d-b3b8-40f3-a1bf-b9d57f1ca4e3" /></td>
    <td><img width="1798" height="496" alt="10" src="https://github.com/user-attachments/assets/30ff6070-def5-4dd8-a5a9-4de11fa14706" /></td>
	<td><img width="1798" height="754" alt="13" src="https://github.com/user-attachments/assets/9d4d897c-18b1-44dc-93de-035984acf5db" /></td>
  </tr>	
  <tr>
	<td><img width="1800" height="1352" alt="11" src="https://github.com/user-attachments/assets/ae0c5c01-10f3-496a-b687-7b6a734ad322" /></td>
    <td><img width="1798" height="1728" alt="12" src="https://github.com/user-attachments/assets/f5023929-99b5-438a-94e2-6042c3d352a9" /></td>
	<td><img width="2412" height="1692" alt="08" src="https://github.com/user-attachments/assets/937b8f11-4743-4aca-bf63-8b5003ce7cda" /></td>
  </tr>
</td>
    <td><img width="2406" height="1834" alt="14" src="https://github.com/user-attachments/assets/f9d64535-4177-4b86-bd6a-f1611dc41da8" /></td>
	<td><img width="2394" height="1808" alt="06" src="https://github.com/user-attachments/assets/008c6f5b-0636-43e2-afe6-1de835eab4af" /></td>
	<td><img width="2382" height="1792" alt="05" src="https://github.com/user-attachments/assets/5694833e-2b03-43a2-b1ff-8f3afe11c8e0" /></td>
  </tr>		
</table>

## Directory Structure

```text
luci-app-openvpn-plus/
├── Makefile
├── LICENSE
├── README.md
├── po/
│   ├── de/
│   │   └── luci-app-openvpn-plus.po
│   ├── zh-cn/
│   │   └── luci-app-openvpn-plus.po
└── root/
	├── etc/
	│   ├── config/
	│   └── hotplug.d/
	│   │   ├── iface/
	│   │   │   └── 35-luci-app-openvpn-plus-bootup
	│   │   └── openvpn/
	│   │       └── 35-luci-app-openvpn-plus-lifecycle
	│   ├── openvpn/
	│   │   ├── keys/
	│   │   └── luci/
	│   │       ├── default.nft
	│   │       ├── client.default.conf
	│   │       └── server.default.conf
	├── usr/
	│   ├── libexec/
	│   │   └── luci-app-openvpn-plus
	│   └── share/
	│       ├── luci/menu.d/
	│       │   └── luci-app-openvpn-plus.json
	│       └── rpcd/acl.d/
	│           ├── luci-app-openvpn-plus.json
	│           └── luci-app-openvpn-plus-status.json
	└── www/
		└── luci-static/resources/view/
			├── status/include/
			│   └── 35_openvpn.js
			└── vpn/
				├── openvpn.js
				├── openvpn-keygen.js
				├── openvpn-status.js
				└── openvpn-wizard.js
```

## License

Licensed under the Apache License 2.0.
