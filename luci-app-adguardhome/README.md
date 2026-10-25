## luci-app-adguardhome
#### (Modified version based on the official source code)


### Overview of changes
- Migrate from lua to luci standard js
- Add a global switch
- Add the UI interface to create/modify AGH password function
- Add UI interface to modify AGH management binding ip:port function
- You can choose AGH as dnsmasq upstream, redirect 53 port, switch dnsmasq 53 port or do nothing
- Update the kernel to choose the Latest/Beta version, download from AGH mirror station/AGH github station
- Dynamically obtain ***WAN*** interface passed to nft rules
- Core update hardened: verified downloads, no URL stored in UCI, no unsaved-changes prompt (see [Security hardening](#security-hardening))
- Automatic migration of the old `update_url` option on upgrade

### Core update
The update source is stored in UCI as a fixed key, not as a URL:

| Option | Values | Default |
|---|---|---|
| `core_version` | `latest`, `beta` | `latest` |
| `update_source` | `official` (AdTidy mirror), `github` (GitHub Releases) | `official` |

`update_core.sh` maps these keys to hard-coded download URLs, so nothing read from UCI or from the network is ever expanded or executed. The beta channel is only available from GitHub; selecting it together with `official` automatically falls back to GitHub.

The script accepts optional arguments, which the LuCI page uses to pass the current selection without touching UCI (so no *unsaved changes* are left behind):
```
update_core.sh [force] [latest|beta] [official|github]
```

> [!NOTE]
> The old `update_url` option is no longer used. On upgrade it is migrated automatically by `uci-defaults`: a `github.com` URL becomes `update_source=github`, anything else becomes `update_source=official`, and `update_url` is removed. Custom download URLs are no longer supported.

### Security hardening
This package runs several scripts as root while AdGuard Home itself runs as an unprivileged user that owns its configuration directory. Anything read from that directory, from UCI, or from the network is therefore treated as untrusted.

**Core update (`update_core.sh`)**
- TLS certificate verification is always on (the previous `curl -k` / `wget --no-check-certificate` are gone); downloads are HTTPS only
- The archive's SHA-256 is checked against the `checksums.txt` published with the matching GitHub release; if the checksum cannot be fetched or does not match, the update is refused
- No `eval`; the release tag must match `vX.Y.Z[-suffix]`
- Private `mktemp -d` working directory; only the single expected member (`AdGuardHome/AdGuardHome`, with or without a leading `./`) is extracted
- The new binary is test-run (`--version`) before it replaces the installed one, and is installed with an atomic rename, so a failed or interrupted update leaves the current core untouched
- A lock directory prevents concurrent updates; *force* only terminates a verified previous instance
- The service is restarted only if it is enabled

**LuCI page (`config.js`)**
- No HTML built from untrusted strings: values are escaped or built with DOM nodes (WebUI link, version, update result)
- The WebUI link host/port are validated; release links are only rendered if they point to the project's own GitHub releases
- `jail_mount` / `jail_mount_rw` entries must be absolute paths without `..`; the root filesystem and critical system directories cannot be mounted read-write
- A new password can only be saved as a bcrypt hash, so a plain-text password can never reach UCI
- A warning is shown when the WebUI listens on all interfaces over plain HTTP

**YAML helper and redirect control (`helper.sh`, `control.sh`)**
- `config_editor` no longer builds shell commands from YAML content or values (the old `system("sed ...")` allowed command injection as root); it rewrites the file in awk, refuses symlinks and values containing line breaks
- The DNS port read from the YAML is validated (1–65535) before it is used in nft rules, UCI values or the state file
- The state file is parsed and validated instead of being sourced
- `redirect` is checked against a whitelist; the dnsmasq upstream entry is matched exactly (no `#53` vs `#5353` confusion)

**Known limitations**
- AdGuard Home's WebUI listens on `0.0.0.0:3008` over plain HTTP by default; bind it to a LAN address if the device is exposed
- The configuration directory is owned by the service user (required for AdGuard Home to save its settings), so root scripts that write there cannot be made fully immune to file replacement races
- `control.sh` is not serialized with a lock; concurrent invocations are possible

### Default behaviors
> [!TIP]
> Use the following rules to exclude inbound traffic from **WAN** to avoid exposing the router to !!️ **Public Parser**!!️
> 
> This function is only effective in "Redirect" mode.
> ```
> iifname { __WAN_EXCLUDES__ } return
> ```
> 
> The rest of the `53` port traffic that matches the `target is local` will be redirected to the listening port of **AdGuard Home**
> ```
> fib daddr type local udp dport 53 redirect to :__AGH_PORT__
> fib daddr type local tcp dport 53 redirect to :__AGH_PORT__
> ```

> [!CAUTION]
> *Only suitable for the OpenWRT official version, and questions generated by third parties will not be answered*
> 
> *Only `nftables` is supported, the one is still using `iptables` may have problems*
> 
> *The device name can be viewed through `ip a` / `ifconfig`*

### Attribution
#### Reference
- [OpenWRT official luci](https://github.com/openwrt/luci/tree/master/applications/luci-app-adguardhome) 
- [OpenWRT official packages](https://github.com/openwrt/packages/tree/master/net/adguardhome)

#### Acknowledgment
Inspired by 
- [@w9315273 nft version](https://github.com/w9315273/luci-app-adguardhome)
- [@rufengsuixing](https://github.com/rufengsuixing/luci-app-adguardhome)

#### Notice
If the author of the original code has any objections, please contact me to deal with it.
