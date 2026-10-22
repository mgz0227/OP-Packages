# Upstream submission

Target: `openwrt/luci`, branch `master`, directory
`applications/luci-app-device-manager/`.

The independent repository retains development tests, SDK build workflows and
SSH deployment tooling. They are not copied to the upstream repository root.
The configuration initializer lives under `tools/` for source deployments;
packages ship `/etc/config/device_manager` directly. The exported README uses
official-feed installation commands, while standalone build instructions stay
in the independent repository.
Export reviewed package files into a fresh LuCI feature branch:

```sh
git clone https://github.com/openwrt/luci.git /tmp/luci-device-manager-upstream
git -C /tmp/luci-device-manager-upstream switch -c add-device-manager
git -C /tmp/luci-device-manager-upstream config user.name "zhiyong zhang"
git -C /tmp/luci-device-manager-upstream config user.email "zhang747@126.com"
python3 -B tools/prepare-upstream.py /tmp/luci-device-manager-upstream
git -C /tmp/luci-device-manager-upstream diff --check
```

The exporter refuses an existing application directory and does not change
Git history, commit or push. It uses the standard relative `luci.mk` include
and exports only package sources, PO files, licenses and package documentation.

Suggested commit title:

```text
luci-app-device-manager: add LAN device management
```

Suggested commit body:

```text
Add a JavaScript LuCI view for LAN device discovery and metadata management.
Combine host hints, DHCP leases, wireless associations and kernel neighbors.
Save names, remarks, groups and manual type overrides by MAC address.

Unlike the existing host list, this application maintains custom device
metadata and groups, including saved devices that are currently offline.

Keep ordinary refreshes passive. Provide an explicit write-authorized scan
limited to configured netifd interfaces and their actual IPv4 prefixes.
Bound concurrent probes, scan duration and the shared scan cooldown.

Use native LuCI message extraction and separately built translation packages.
Include pinned Material Design Icons attribution and Apache-2.0 notices.

Signed-off-by: zhiyong zhang <zhang747@126.com>
```

Submission commits use `zhiyong zhang <zhang747@126.com>` for the author,
committer and Signed-off-by identity. Configure this identity locally in the
LuCI checkout before committing, as shown above. Existing contributor
attribution must be preserved; these tools do not rewrite historical commits.

Suggested PR description:

```text
Add a LAN device manager with MAC-keyed custom names, remarks, groups and
manual device types. Discovery combines native LuCI host/lease/wireless RPCs
with kernel neighbor data and distinguishes online, offline and unknown.

Refresh is passive. An explicit Scan LAN operation requires write permission
and scopes ICMP probes to configured netifd interfaces and actual prefixes.
Chinese translations are built by luci.mk; other languages use native LuCI
catalogues and English fallback.

Validation:
- 100 Node and 8 Python regression tests passed.
- 33 RPC regressions passed with SDK-native jshn and isolated network inputs.
- Official LuCI message extraction, gettext checks and ESLint passed.
- Built main and Chinese language APKs in the official x86/64 SNAPSHOT SDK.
- Verified official SNAPSHOT and 24.10.4 BusyBox ip/flock compatibility;
  33 RPC regressions passed with each binary and SDK-native jshn.
- Checked resolved dependencies without extra ip or flock packages.
- Checked package license texts, configuration preservation metadata and LMO.

Real-router installation, upgrades, account enforcement, UI acceptance and
a stable-release SDK build remain unverified.
```

Review the recorded validation results before sending the PR.
Local tests do not certify real-router or upstream acceptance.
