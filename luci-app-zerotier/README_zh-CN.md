[ ! -f "/usr/share/ucitrack/luci-app-`uci.json" ] && {
    cat > /usr/share/ucitrack/luci-app-`uci.json << EEOF
{
    "config": "`uci",
    "init": "`uci"
}
EEOF
}
# luci-app-zerotier（JavaScript 版）

[English](README.md) | **简体中文**

OpenWrt 上 ZeroTier VPN 的现代 LuCI 界面，由原 Lua 版本转换而来并持续改进。

Fork 自 https://github.com/zhengmz/luci-app-zerotier，最初使用 VS Code 的 AUGMENT Code 插件从 Lua 转换为 JavaScript，随后通过 [OpenCode](https://opencode.ai) + GLM-5.1 持续打磨与修复。

## 特性

- **远程控制器** —— 在本路由器的 LuCI 上，开通并管理**运行在另一台服务器**（固定公网 IP）上的 ZeroTier **控制器或 Moon 根**。仅通过 SSH 转发的回环端口访问（见[远程管理](#远程管理r33)）；控制器管理令牌按需经 SSH 读取，从不在路由器上存储。
- **网络管理** —— 加入/退出 ZeroTier 网络，配置各项设置
- **Moon** —— 加入/退出私有 Moon，自动持久化（不修改 zerotier 软件包；纯靠守护进程的 `/moon` 控制面驱动）。注意上游 ZeroTier 已不再推荐私有 Moon，且不在其 SLA 支持范围内。
- **自动 NAT 客户端** —— 自动防火墙规则管理（zerotier ↔ lan，zerotier → wan）
- **接口信息** —— 结构化展示网络、对端与节点身份
- **全网 Ping** —— 批量 ping 已连接网络中的所有 IP，显示在线主机
- **实时状态** —— 轮询式实时显示服务状态与身份
- **简体中文** —— 通过 `po/zh_Hans/` 提供完整国际化支持

## RPC 方法

自定义 `luci-zerotier` RPC 对象提供以下方法（无需 `luci.exec`）：

| 方法 | 权限 | 说明 |
|---|---|---|
| `status` | 读 | 服务运行状态 + 节点地址（一次调用，无 `ps`/`uci` fork） |
| `get_networks_peers` | 读 | 一次调用返回 `listnetworks` + `listpeers` |
| `list_moons` | 读 | 已加入的 Moon 及其中哪些已持久化 |
| `ping_networks` | 读 | 并发 ping 扫描所有已分配 IP 网段 |
| `reload` | 写 | 通过 `/etc/init.d/luci-zerotier reload` 重载防火墙规则 |
| `restart_service` | 写 | 重启 zerotier 守护进程（先同步运行时状态） |
| `sync_config` | 写 | 将运行时状态持久化到配置目录；并把配置的 `local_conf_path` 导入其中 |
| `orbit_moon` | 写 | 加入 Moon（给定其 ID 和任一根地址） |
| `deorbit_moon` | 写 | 退出 Moon |
| `remote_list` | 读 | 已配置的远程主机列表（绝不返回密钥内容） |
| `remote_diagnose` | 读 | 经 SSH 对远程主机做只读体检 |
| `remote_ctl_get` | 读 | 经 SSH 隧道进行带鉴权的控制器 API 读取 |
| `remote_member_list` | 读 | 一次隧道往返读取一个网络的全部成员 |
| `remote_network_list` | 读 | 一次隧道往返读取每个网络的完整记录 |
| `remote_peer_list` | 读 | 控制器的实时 `/peer` 列表（状态、版本、延迟、路径） |
| `remote_moon_plan` | 读 | Moon 创建将要执行的精确远程命令及其摘要 |
| `remote_host_set` | 写 | 新增/更新远程主机；无存储密钥时生成专用密钥对并返回公钥（API 调用方仍可传私钥） |
| `remote_host_del` | 写 | 删除远程主机及其密钥文件 |
| `remote_network_set` | 写 | 在远程控制器上创建或更新网络 |
| `remote_network_del` | 写 | 在远程控制器上删除网络 |
| `remote_member_set` | 写 | 授权或取消授权成员 |
| `remote_moon_apply` | 写 | 创建并签名 Moon；要求回传 `remote_moon_plan` 的摘要 |

## 安装

```bash
# 通过 IPK
opkg install luci-app-zerotier_*.ipk

# 通过 OpenWrt 源码树
cp -r package/luci-app-zerotier <openwrt_source>/package/
make package/luci-app-zerotier/compile
```

## 文件结构

```
htdocs/luci-static/resources/view/zerotier/
├── general.js          # 设置页（启用、NAT、网络、高级）
├── info.js             # 信息页（身份、网络表、对端表、ping）
└── remote.js           # 远程控制器页（主机、网络、成员表）

root/usr/libexec/rpcd/
└── luci-zerotier       # RPC 守护（状态、网络、身份、对端、ping）

root/etc/init.d/
└── luci-zerotier       # 防火墙管理（区域 + 转发规则）

root/etc/uci-defaults/
└── luci-zerotier       # 安装/升级迁移、默认值播种、清理

root/usr/bin/
├── zerotier-remote.sh  # 远程控制器传输层（SSH 隧道、控制器 API）
└── zerotier-sync.sh    # 运行时状态持久化（守护进程状态目录的镜像）

root/etc/zerotier/
└── local.conf.template # 安装时播种为 /etc/zerotier/local.conf

root/usr/share/rpcd/acl.d/     # ACL 组（UCI 访问 + RPC 方法）
root/usr/share/ucitrack/       # 保存并应用时的重载注册
root/lib/upgrade/keep.d/       # sysupgrade 备份列表（/etc/zerotier*）
po/zh_Hans/                    # 简体中文翻译 + gen_tr.py（重新生成客户端目录）
htdocs/luci-static/zerotier/   # 客户端翻译目录（生成物，见 po/zh_Hans/gen_tr.py）
```

## 防火墙规则（NAT=1 时）

启用自动 NAT 后，`init.d/luci-zerotier` 会创建：

- **区域** `zerotier`：input=ACCEPT，output=ACCEPT，forward=ACCEPT，masq=1，设备通配 `zt+`
- **转发** `zerotier → lan`：ZT 客户端可访问局域网
- **转发** `lan → zerotier`：局域网设备可访问 ZT 对端
- **转发** `zerotier → wan`：ZT 客户端可将本设备用作上网网关

自 r23 起，区域使用 `zt+` 通配符匹配设备，fw4 会将其渲染为 nftables 通配
`iifname/oifname "zt*"`。因此规则能匹配当前与未来的 ZeroTier 设备，无需任何
`zerotier-cli` 设备枚举或就绪等待循环；无论控制器授权耗时多长都保持正确，
并自动覆盖新加入网络的设备。`start()` 是幂等的：期望规则已存在时什么都不做
（不写 uci，不重载防火墙）。

## 远程管理（r33）

ZeroTier **控制器**和 **Moon 根**都需要一台固定公网 IP 的机器。家用路由器很少
满足条件，所以本应用把控制器视为*活在别处*，进行远程管理。

### 为什么传输层是 SSH 隧道，且仅此一种

控制器控制面**没有 TLS** —— 对控制端口发起 https 请求永远不会完成。它还用
`local.conf` 里的 `allowManagementFrom` 拦截一切非回环调用方，而该配置**默认为空**，
所以除 localhost 之外的请求一律返回 `401`，*即使令牌正确*。在 `OneService.cpp`
里该检查是先做回环判定、再落到白名单，这解释了为什么光有令牌永远不够。

把 `allowManagementFrom` 放宽到 `0.0.0.0/0` 来迁就 LuCI，会让**控制器管理令牌
在每次请求时以明文上线**，还是从一个会变的住宅 IP 发出。因此路由器改为转发一个
回环端口：

```
127.0.0.1:<每次调用独立的端口>  --SSH-->  127.0.0.1:<控制器端口>
```

本地端按次调用选定而非配置固定，这样对同一控制器的两个请求永远不会争抢端口
（此前的代价见更新日志）。

守护进程看到的是回环对端，直接短路放行。因此控制器**完全不需要任何配置变更**，
并对 localhost 保持防火墙隔离。

在一台把 `27893` 端口开放给全网、且持有正确管理令牌的主机上实测：

| 请求 | 结果 |
|---|---|
| 从公网 `GET /controller`，无令牌 | `401` |
| 从公网 `GET /controller`，**令牌有效** | `401` |
| 经 SSH 隧道 `GET /controller` | `200` + 完整控制器响应 |

### 值得了解的推论

- **控制器令牌从不存储在路由器上。** 每次调用按需经 SSH 读取。OpenWrt 设备上
  不存在可泄漏、可备份、可渲染进页面的长期控制器级管理凭据。
- **控制器 API 调用在本地对转发端口执行 `curl`。** 浏览器提供的数据永远不会被
  拼进远程 shell 命令；隧道对端只是一根哑 TCP 管道。本应用构建的唯一远程命令是
  固定的 moon 脚本，经 stdin 送给 `sh -s`，不接受任何自由文本输入。
- **Moon 签名密钥永不离开根主机。** `moon.json`（内含 `signingKey_SECRET`）在
  远端创建、签名并保留。只有不含密钥的已签名 `.moon` 会被读回——仅仅因为成员
  没有它就无法加入 Moon。
- **端口选择只是伪装，不是管控。** 控制器跑在 `27893` 而非 `9993` 上可避免被
  批量扫描器识别。它不保护 API——那是 `allowManagementFrom` 的职责——但零成本，
  而且你的节点本来就在用非默认端口组。
- **每次远程调用耗费一次 SSH 握手**（1–3 秒），所以本页面按需刷新，不像接口
  信息页那样轮询。

### 主机前提条件

一台主机可被管理，需要：固定公网 IP · SSH 访问 · 公钥已进入远端
`authorized_keys` 的密钥对 · 该用户可**免密 sudo** · 以包含控制器功能的方式构建的
ZeroTier。

控制器必须来自真正内置它的构建版本。自 1.16.0 起默认二进制**不再**包含控制器，
且控制器转入了商业源码可得许可（`make ZT_NONFREE=1`）；1.14.2 早于这一拆分，
仍是内含控制器的单一 MPL/BSL 二进制。

### dropbear 的限制（真机验证）

OpenWrt 的 `ssh` 是 dropbear，它会**静默忽略** `ConnectTimeout`、`LogLevel`、
`IdentitiesOnly` 和 `UserKnownHostsFile` —— 只向 stderr 打一条警告然后继续。
有两个后果被显式处理：

- 没有连接超时，而本固件没有 `timeout` 小程序，因此每次 ssh 调用都用自制的
  截止时间兜底。没有它，一台不可达的主机会让 LuCI RPC 无限期挂死。
- stderr 永不并入 stdout，否则被忽略选项的警告会覆盖调用方解析的每个值——
  且退出码还是 0。

### 已知限制

- 远程主机是 Moon 的**单根**。多根会被显式拒绝，而非做一半。
- 提供 Moon *创建*；本应用不会对已存在的 Moon 重新签名或追加根。
- 控制器**规则编辑器**按设计不在范围内。

## 更新日志

### v2.2-r49

**取消授权全链路验证，以及一个像样的垃圾桶**

- **在真实成员上验证了踢出/回归周期**（测试控制器 `017c6a82b7`）：
  `authorized: true → false → true` 全部返回 `code: 0`，无异常。踢出后其 IP
  仍留在成员记录里，重新授权后恢复的是*同一个地址*（`192.168.192.69`），无需
  重新分配。撤销/恢复周期中 IP 的持久化与 r36 的测量预测完全一致。
- **取消授权图标改为垃圾桶**，以行内 SVG（罐+盖+三条纹）绘制，替代裸露的
  `✕`。ztncui 用 `glyphicon-trash`，但本 LuCI 主题不带 Bootstrap Glyphicons
  字体，因此直接画。真实浏览器验证：SVG 存在、无 `✕` 残留、排序与布局回归
  通过——5/5。
- 更正此前审计的一条记录：`allowManaged`、`allowGlobal`、`allowDefault`、
  `allowDNS` 是**客户端侧开关**，早已作为 `form.Flag` 存在于 `general.js` 基本
  设置中。它们是每客户端偏好，不是控制器侧网络配置，因此不属于远程控制器的
  网络编辑器。无需补充。
- 图标细化（未升版本号）：垃圾桶加上了盖把手，三条条纹用
  `fill-rule="evenodd"` 从罐体上挖穿，背景得以透出——对齐 ztncui 的
  `glyphicon-trash` 观感。浏览器内验证 9/9，并在 96px 与 24px 下目检通过。
- 行字号（未升版本号）：成员表改用主题自身的标题刻度渲染，而非 argon 压缩后
  的表格字号（0.75rem）。表格包在一个 `h5` 里并以 `font-size:1em` 引用，没有
  硬编码像素——主题改 h5，行号跟着走。垃圾桶图标同样以 `width/height:1em`
  随字号缩放，与 ztncui 的 glyphicon 行为一致。滚动最小宽度随大字号增至
  1400px；在 1400px 边界无串列（浏览器内 11/11，820/1400/1700px 三档截图）。
- 审计修复（未升版本号）：成员移除按钮失败时弹出通知，不再静默重载；远程主机
  标签（Label）增加校验（拒绝换行/控制字符——UCI 值容纳不下它们；判定用字节
  计数比对而非 grep，因为 grep 永远看不见 `\n`，那是它自己的行分隔符）；CJK
  中文标签不受影响。已在真机通过 ubus 端到端验证。
- 图标重设计（未升版本号）：垃圾桶采用运维者手工调校的描边几何（viewBox
  100x110，4.5 单位圆头描边，开放式罐身，三条内衬线），以 1.25em 渲染（当前
  16px 行字号下即 20px）。相对所给 SVG 的唯一适配：描边跟随 `currentColor`
  而非硬编码黑色，暗色主题下不会隐身。
- 主机列表打磨（未升版本号）：每个已配置主机的可点击名字改用页面标题
  刻度渲染——它是真正的 h2（argon 下 1.25rem，与"ZeroTier - 远程控制器"
  标题同档），仅内联清掉卡片装饰（内边距/白底/阴影），排版仍归主题。
  下方的等宽连接说明行不变，主机块之间增加下边距，不再贴在一起。
- 新增主机流程重设计（未升版本号）：向浏览器粘贴 SSH 私钥的做法取消。
  SSH 模式保存时若本路由器没有存储密钥，会就地生成专用 ed25519 密钥对
  （dropbear 的 ssh-keygen 兼容二进制——dropbear 包以无条件 ALTERNATIVES
  条目保证每个默认 OpenWrt 镜像都有它），并返回公钥半边；界面以弹窗给出
  可直接复制的 `echo '<公钥>' >> ~/.ssh/authorized_keys` 命令——操作者本来
  就有远程主机的访问权，在那里执行即可。私钥半边永不经过浏览器。编辑
  主机时展示已存的公钥。控制器端口字段同样从 SSH 模式移除：未存储时，
  helper 经同一条 SSH 通道读取远端守护进程的 `zerotier-one.port`（控制器
  API 与其共享端口），把结果写入 UCI，之后每次调用都像手填值一样读取。
  直连模式仍需填写端口（没有 SSH 可供发现）。真机端到端验证：密钥生成、
  无默认身份环境下用生成密钥认证、经应用栈读取控制器、发现的端口
  （27893）落入 UCI。浏览器内 32/32。
- 语义确认（未升版本号）：垃圾桶与已授权复选框**有意不同**。复选框只发
  `{authorized:false}`——名字与 IP 分配在撤销/恢复周期中保留。垃圾桶发整套
  重置（`name:'', authorized:false, ipAssignments:[]...`）：成员记录本身从不
  删除（不使用控制器的 DELETE 端点），但其名字与已分配 IP 会被清空。两者都
  保留"该节点曾加入"的记忆；只有垃圾桶额外清除元数据。运维者确认为预期
  行为——未来审计不要再提议"统一"它们。

### v2.2-r48

**成员表下方的"Detail for network"，对齐 ztncui**

- 每个网络页现在以 **Detail for network** 区块收尾：按键序列出控制器网络对象
  的全部字段——`authTokens`、`authorizationEndpoint`、`capabilities`、
  `clientId`、`creationTime`、`dns`、`enableBroadcast`、`id`、
  `ipAssignmentPools`、`mtu`、`multicastLimit`、`name`、`nwid`、`objtype`、
  `private`、`remoteTraceLevel`、`remoteTraceTarget`、`revision`、`routes`、
  `rules`、`rulesSource`、`ssoEnabled`、`tags`、`v4AssignMode`、`v6AssignMode`。
  它是 ztncui 成员详情的网络版。全部由 `network-list` 已返回的缓存 `netsById`
  对象构建，不耗任何 RPC。
- 真实浏览器验证：区块位于成员表下方，含 revision、creationTime、池、路由、
  规则与 v4AssignMode，另加布局与排序回归——**10/10**。

### v2.2-r47

**两条通往控制器的路：SSH 与 ZeroTier 直连**

- **每台主机现在都可以通过 ZeroTier 网络本身访问。** ZeroTier 控制器守护进程
  监听 0.0.0.0，同一网络的任何成员凭令牌即可调用其 API——前提是
  `allowManagementFrom` 覆盖调用方（默认仅回环）。直连单次调用实测 ~0.15s，
  对比合并后 SSH 连接的 ~1.2s，约快 8 倍。
- **主机编辑器新增访问模式：** `SSH 隧道`（既有路径）或 `ZeroTier 直连`
  （控制器 ZT 地址 + 端口 + API 令牌，与 SSH 密钥同等 0600 保管）。字段随
  模式显隐；主机行显示 `[Direct]` 或 `[SSH]` 徽标。
- **SSH 模式主机自动升级。** SSH 隧道建立后，helper 从控制器自己的成员记录
  推导其 ZeroTier 地址（每个网络 id 都以控制器的 10 位十六进制节点地址开头），
  把每个候选地址先过本机 ZeroTier 子网闸门，首个 200 即持久化令牌并写入直连
  标记。之后的每次调用直连；瞬时失败回落 SSH 一次且保留标记。安全闸门是承重
  的：不在本路由器 ZeroTier 子网内的候选地址永远不会被联系，因为探测公网地址
  会把控制器令牌明文送上互联网——这正是本项目当初选择隧道的原因。
- 在生产控制器与测试控制器上真机验证：显式直连（读与写，含带空格的重命名），
  以及完整自动升级周期——探测写标记、直连接管（~0s）、标记损坏回落 SSH 且
  标记保留、随后恢复。浏览器 harness：徽标、编辑器模式切换、占位符切换、保存
  参数传递，加 r43 排序回归——12/12。
- 对照 ZeroTier 源码钉死语义（1.14.2 与 1.16.2 一致）：回环永远放行；
  `allowManagementFrom` 条目是 CIDR/位掩码包含检查；**裸 IP 即掩码 0 =
  放行全部**（不是最小权限），`/32` 才是精确单主机。生产环境现运行
  `allowManagementFrom = ["192.168.192.32/32"]`——只有本路由器与回环可调用
  生产控制器。另注意这些主机上 `systemctl restart` 并不可靠地换掉守护进程
  （一个吃了 5 小时 37 分 CPU 的僵尸曾继续按旧配置服务）；必须 stop + kill +
  start。

### v2.2-r46

**ztncui 对齐：可点主机标签、成员详情、IP 管理**

- **主机标签可点击**，与 Manage 按钮共享同一处理器——点击展开详情面板（按钮
  变 *Hide*），再点收起（按钮变 *Manage*）。单一共享函数，两条路径对面板状态
  永不失步。
- **成员 ID 现在与网络 ID 同款**：页面背景上的普通等宽链接，去掉白色代码块。
  点击打开 ztncui 风格的只读*成员详情*：按键序列出控制器成员记录的每个字段，
  以及格式化打印的实时对端对象——全部来自缓存模型，零 RPC。
- **点击 IP 打开 ztncui 风格管理器**，替代编辑逗号分隔字符串：顶部成员名与
  ZeroTier 地址，每个 IP 一行带独立删除，一行输入加新增，下方只读展示网络的
  受管路由。ZeroTier API 对 `ipAssignments` 整体替换，所以删除提交"当前减一
  行"、新增提交"当前加一个"——比自由字符串贴合控制器实际能力得多。旧的内联
  编辑器已移除。
- harness 在上线前抓住一个真实作用域 bug：Add 输入框定义在 paint 闭包内，
  Add 处理器看不到它、首次使用即会抛错。修复后真实浏览器验证：标签切换、详情
  字段、ID 样式、删除/新增/非法 IP 处理、路由展示与重绘，加 r43/r44 回归套件
  ——**25/25**。

### v2.2-r45

**只在全新安装时发作的打包回归**

- `zerotier-remote.sh` 曾以 `100644` 提交，导致所有基于 `git clone` 的构建把
  `/usr/bin/zerotier-remote.sh` 装成**不可执行**。本项目每次 scp 部署后都显式
  chmod，所以这个 bug 一直隐形——直到第一次整机固件构建+安装，rpcd 的
  `[ ! -x ]` 守卫把它报成*缺失*。文件从未缺失；它一直在，只是不可用。现已按
  `100755` 提交。
- rpcd 守卫现在区分两种情形：文件不存在时报 *"zerotier-remote.sh is missing"*，
  存在但不可用时报 *"zerotier-remote.sh is not executable (installed 0644;
  it must be 0755)"*，下次再发生几秒内即可定位，不用再搜。
- 注意 `root/etc/hotplug.d/net/99-luci-zerotier` 有意保持 `0644`：OpenWrt 的
  `/sbin/hotplug-call` 对脚本是 *source* 执行（`[ -f $script ] && . $script`），
  从不 exec，因此该权限本来就正确。

### v2.2-r44

**布局：工作内容优先**

- **"远程管理的工作原理"移到页面底部。** 它是说明文字而非日常工具；页面现在
  直接从已配置主机开始。
- **展开主机后的顺序是 网络 → Moon → 诊断。** 查看已配置网络的成员是管理员
  的日常任务，最少用的面板排最后。
- **每个网络 ID 现在是可点链接，行为与 Members 按钮完全一致。** 两者走同一
  共享处理器——点击打开成员表，再点收起——两条路径不会漂移。无新增可翻译
  字符串：链接的 title 复用既有 "Members" msgid。
- 真实浏览器驱动真实视图代码验证：页面区块顺序、主机详情顺序、ID 点击与按钮
  同等地开合成员面板，加 r43 排序回归套件——10/10。

### v2.2-r43

**成员列可排序**

- **每个成员列都可排序。** 点表头升序，再点降序，点其他列按该列升序。活动列
  带 ▲/▼。排序读取缓存模型、绝不访问控制器——与过滤器同一条规则，任何点击
  都不耗 SSH 往返。
- IP 分配按**数值**排序（192.168.192.9 &lt; .30 &lt; .100），不是字典序。名字按
  浏览器 `zh` 排序规则排——汉字按拼音在前、拉丁在后——第一版 harness 断言
  写反了，被浏览器抓住；Node 全量 ICU 与浏览器一致。无名、无地址、未连接的
  成员在两个方向都沉底。
- 已授权 / 主动桥接升序时未勾选在前（0 在 1 前）；对端状态按 CONTROLLER →
  ONLINE → OFFLINE 排；延迟最快在前。
- 排序在过滤与手动刷新后保持；按成员读回仍单行原位重绘，编辑不会把表格从
  光标下抽走。
- 用故意打乱的 fixture 数据在真实浏览器驱动真实视图代码验证：10/10 断言——
  默认 id 序、IP 升/降、名字升/降、状态、延迟、桥接、已授权，以及过滤+排序
  交互。最初两个失败是 harness 自身预期写错（zh 排序与稳定排序次序）；代码
  是对的，改的是预期。

### v2.2-r42

**简体中文，端到端**

- **翻译 227 条字符串**（继承原应用残缺目录的 104 条，新增 123 条——整个远程
  控制器页面从未被翻译过）。一个 po，两条投递路径，因为本固件上翻译经两条
  不同机制到达用户，而这两条对本应用都是坏的。
- **服务端路径**：ucode dispatcher 按请求从 `/usr/lib/lua/luci/i18n/` 加载
  `<domain>.<lang>.lmo` 并翻译菜单标题。本应用没有 `.lmo`，所以它的菜单项是
  全中文菜单里仅有的英文。`po2lmo` 工具在任何可拉取的上游路径都不存在了，
  于是从固件自带的 `base.zh-cn.lmo` 逆向了二进制格式：16 字节大端索引条目
  `(hash, 1, offset, length)`，按 hash 排序，hash 0 处是复数表达式，尾部 u32
  是索引偏移。构建前先用六对已知译文（Log in→登录、Dismiss→忽略……）验证。
- **客户端路径**：JS 视图经 cbi.js 的 `_()` 翻译，它查 `window.TR[sfh(trimws(s))]`
  ——而本固件上**从未有任何东西填充 window.TR**。dispatcher 不填、header 模板
  不填、主题资源也不填；登录页是中文只因它服务端渲染。于是本应用自带目录
  （`tr-zh-cn.js`，键为 cbi.js 哈希的确切十六进制形态），由每个视图在需要
  第一条字符串前装好，按文档语言门控。对将来长出桥接的固件幂等无害。
- 用路由器**真实的 cbi.js `_()`/`sfh` 代码**对生成的目录验证：227 条中 226
  条精确往返（第 227 条是 `Remove`/`Remove ` 在 trimws 下碰撞——同一个词，
  尾随空格）。也是这个 harness 抓住了第一版坏目录：键用成了十进制而 cbi.js
  哈希是十六进制，检查机制存在前一个空的中间产物已被部署。现在检查放最后
  而不是最前。
- `po/zh_Hans/gen_tr.py` 从 po 重新生成客户端目录（幂等；已提交，下次加字符
  串不用再做逆向）。

### v2.2-r41

**复审的三项加固，一项诚实退役**

- **ctl-get 与 peer-list 曾把控制器返回的内容原样嵌入。** 被劫持的控制器可以
  提前闭合 JSON 信封、向页面注入顶层字段——`code`、`body`、`error`。两者现在
  都走 `r_emit_val`：不是单个完整 JSON 值的响应体以转义字符串投递，无法再
  添加结构。`r_json_ok` 从仅对象泛化为对象或数组，因为两者都是真实的控制器
  响应。对已部署函数做对抗性单元验证：信封逃逸、尾随垃圾、截断、类型不匹配
  的闭合全部拒绝；仅含花括号的字符串原样放行。其中一条测试起初失败，因为为
  它写的"恶意"响应体 `{"]":1}` 是合法 JSON——键就是字符串 `"]"`。函数是对的；
  测试错了。
- **浏览器提供的 section 名可以指认任意 `zerotier.*` UCI 节**，其选项会被当作
  连接参数读取。`r_load` 现在要求 section 类型必须是 `remote`，uci 直接可查。
- **转发端口在 pid 之外混入随机 uuid。** 诚实地说：自 r40 起就绪信号是我们
  自己 ssh 的 stdout，预绑定端口只值一次重试——复审的端口劫持发现早已被构造
  性消灭，不是靠这个。熵是针对强迫重试骚扰的纵深防御。

### v2.2-r40

**每次调用一条 ssh 连接**

- **过去每次远程调用开两条 ssh 连接**：隧道一条，再开一条读令牌。现在合并——
  隧道的 ssh 直接执行 `printf "X-ZT1-Auth: "; sudo -n cat authtoken.secret;
  sleep 60`，令牌与转发同一条连接到达，而 ssh 只在转发绑定后才执行命令：
  头文件非空即证明本隧道存活。一次性替代了第二条连接与就绪探测。生产主机
  实测：**单次调用 2.39-2.81s 降到 1.30-1.84s**；三个并发调用——过去按六条
  连接撞上远端 sshd 的 `MaxStartups 10:30:100` 而失败——现在三条稳定通过。
- **被替代的探测曾信任端口上的任意监听者。** 本地进程预绑定 pid 派生端口即可
  应答就绪 curl、收下 `X-ZT1-Auth` 令牌并向页面投喂伪造 JSON。我们自己 ssh 的
  stdout 伪造不了，所以 r38-r39 复审的拦截发现在构造上死亡，而非靠补丁。
- 令牌如今走 `ssh stdout -> 0600 mktemp 文件 -> curl -H @file`，绝不出现在
  进程命令行（以前经 `/proc` 全局可读）或 shell 变量里。
- 本次合并的第一版打挂过生产，读 diff 没发现：令牌读取必须像 `rrsh` 一直做
  的那样在 `sudo -n` 下执行，因为生产主机上令牌对 ssh 用户不可读。真机重测
  抓住了它——裸 `cat` 对 root 登录的测试机有效、对生产 401。
- **孤儿隧道有了上限。** `ssh -N` 不会自行退出，被整个杀掉的 helper 也无从
  清理；早前测试中积累了十条孤儿。尾部 `sleep 60` 让会话自然终结——实测：
  读令牌途中被 SIGKILL 的 helper 留下的孤儿恰好活了 60s——泄漏的头文件
  （内含令牌）由下次调用清扫，按文件名里嵌的 pid 对照 `/proc`。

### v2.2-r39

**成员读取失败曾伪装成成功**

- **整网成员读取全失败时，页面渲染成"还没有成员加入该网络"。**
  `member-list` 跳过读不出的成员、输出 code 200 的空数组，页面只能读成空
  网络——正是 `network-list` 通过 `skipped` 列表报告的那种失败。
  `member-list` 现在同样报告，表格计数器显示 `显示数 / 已知数`（已知数计入
  不可读成员），全部失败画错误而不是空网络提示。
- **刷新按钮曾能撒两次谎。** 刷新失败静默保留旧行——这没错——但仍移动了
  *updated* 时间戳，把陈旧数据当新鲜数据呈现。时间戳现在只在成员表真正被
  替换时移动，刷新失败会出声。
- **`r_tunnel_up` 没有总预算。** 对黑洞主机八次十二轮询的重试可烧 ~96s——
  是本项目真机测得的 rpcd ~30s 放弃时长的三倍——把干净失败变成客户端超时，
  rpcd 放弃后 helper 还在空转。现在整个函数受 `R_SSH_TIMEOUT` 约束，轮询中
  检查。
- 文档追上代码：RPC 方法表补上 r38 的 `remote_network_list` 行；r36 的日志
  拆分被发现是把条目*复制*进 r36 而非移动（r35 条目把 r36 的功劳据为己有
  ——已去重）；文件结构一节自 r33 起漏掉的 `remote.js` 与
  `zerotier-remote.sh` 终于列出。

### v2.2-r38

**每次调用一条隧道，成员不再逐个读**

- **过去所有远程调用共享一个本地转发端口。** `local_port` 来自 UCI——每主机
  单值——而成员表页同时发两个调用、列表页每网络一个。败者的 `ssh -L` 死于
  `Address in use`，但它的就绪探测摸到了*胜者*的隧道并报成功，胜者拆隧道后
  败者读到空响应体：**6 次并发里 2 次**产出空缺的成员表且无任何报错。换端口
  重试救不了——借用发生在任何重试之前。端口现在由 pid 派生，并发调用构造上
  即不相交，`r_tunnel_up` 在被占时逐个向前走。`local_port` UCI 选项随之移除
  ——UI 从未设置过它。
- **成员表曾按 30 个成员发 30 个串行请求。** 单次读取便宜，往返不便宜。经
  单一转发端口每次并发六个，30 成员的生产网络从 **15.2s 到 2.8s**，页面最慢
  一步变得和最快一步一样。输出与控制器自身记录逐字段比对：无缺失、无多余、
  无字段差异。
- **网络列表曾按网络逐个要详情**，各自开隧道读令牌——正是 `member-list`
  要避免的同一 N+1。新增 `network-list` 子命令经一条隧道取全部详情，读取
  失败的网络现在**在页面上点名**，而不是从表里无声消失。
- 裸 `wait` 也会等隧道——同 shell 的子进程、被杀前不退出——所以并读的第一版
  一直阻塞到调用超时：30s 空响应体。现在每个 curl 按 pid 等待。
- 并读需要的暂存目录由 trap 而非成功路径末尾清理，因为 `r_die` 会退出、
  `rpcd` 会放弃跑久的调用。用去掉 trap 的构建对 `SIGTERM` 验证过泄漏。
- **已知天花板，既有且未变：** 三个并发调用（六条 SSH 连接）开始在对
  `MaxStartups 10:30:100` 的主机上失败。对上一版的 A/B 在同一水平同样失败，
  所以这是远端主机的连接节流，不是端口方案。本页最多两并发，实测多轮零失败。
  每次调用仍开两条 SSH 连接（隧道、令牌）；合并可再减半压力，代价是重做令牌
  获取方式。

### v2.2-r37

**带空格的名字根本存不进去**

- **RPC 层曾把命令行拼成字符串、再让 shell 拆回参数。** `rpcd` 把校验过的
  字段收进 `_args`，以 `zerotier-remote.sh $_args` 调用 helper，行内注释断言
  拆分安全，因为每个字段都校验过。section 名、网络 id、成员 id 确实如此——
  `body` 不是，它是浏览器交来的自由 JSON。body 一含空格 shell 就把它拆成
  两半，helper 的 `'{'*'}'` 守卫只见第一段，调用以 *member body must be a
  JSON object* 被拒。什么都没写入，而报错指向了错误的元凶。参数现在用
  `set --` 构造、以 `"$@"` 传递，每个参数完整到达 helper。这不是边缘案例：
  生产网络 29 个有名字的成员里 **28 个名字带空格**；唯一能改名的恰是唯一
  不带空格的。其他每次改名都在这样失败，而报告的症状——一次被拒的写入——
  还是最温和的版本。`ctl-network-set` 同路，带空格的网络名一样坏。
- **改名失败后被拒文本留在输入框里**，比失败本身更糟：表格显示新名字，编辑
  看似已生效，实际没有。写入被拒时现在从成员记录回填。IP 编辑器有意不动——
  那里敞开的编辑器留住输入以便再试才是正确行为，Escape 本就回退。
- 对真实控制器而非 stub 验证：三个都能打挂旧路径的名字（一个空格、*连续*
  空格、一个转义引号）现在从控制器逐字节读回一致，五个畸形 body 仍被拒。
  连续空格案例排除了诱人的 `$*` 一行修法——它会把名字里的连续空格悄悄压扁。

### v2.2-r36

**读回变更的那一个，并等地址真正到达**

- **变更后只重读变更的成员，授权被特判，因为地址不随响应到达。** 真实 1.14.2
  控制器实测：`authorized` 标志 1ms 内翻转、立即可读回，但 `ipAssignments`
  在 +1s、+2s、+4s 均为空，**+8s** 才有值——节点要重新拉网络配置并上线后
  控制器才分配。POST 后立刻回读必然读到空表、看似失败，所以该行标记
  *assigning address...* 并在 11s 后重读一次。撤销无需等待：状态已定，且
  控制器在撤销/恢复周期中保持 `ipAssignments` 不动（生产成员上验证过），地址
  在取消授权后仍可见——参考 UI 显示的也是这样。
- **重读按成员而非按表进行**，这既是体验决定也是成本决定。每次远程调用耗
  ~2.05s SSH 握手，而握手——不是成员数——就是成本：1 个成员和 31 个成员都
  落在 ~2.05s，多出的 30 次抓取合计只加 ~0.6s。单成员重读连同对端列表实测
  2.06s 几乎无抖动，全量列表 2.59s（抖动 2.05-2.67s）。单行重绘也是保住用户
  正在输入的输入框、过滤文本与滚动位置的关键。
- 成员面板带手动**刷新**与 *updated* 时间戳。该按钮有意做全量重载、不像按
  成员路径：它为"同一控制器正在被另一个工具编辑"的场景而存在——这正是
  `ztncui` 当初不得不把成员名存在控制器之外的原因。

### v2.2-r35

**ztncui 风格的行内成员表，实时对端状态**

- 成员表改为**就地编辑**，对齐用户日常依赖的 ztncui 界面。名字、授权、主动
  桥接与受管 IP 各自在 blur 或回车提交（复选框点击即交），且只提交**变更的
  字段**；逐行 Save 按钮取消。控制器对存在性检查的标量做合并，ztncui 在生产
  中就是对同一控制器发单字段，所以部分 body 是正确形态而非偷懒。
- 新增两个实时列——这才是需要新传输层的部分：**对端状态**（`ONLINE
  (v1.16.2)` / `OFFLINE` / `CONTROLLER`）与**对端地址/延迟**
  （`49.232.226.145/55878 (13 ms)`），均来自控制器的 `/peer` 端点。
- **r34 的 N+1 正是本版本得以成立的原因。** 成员详情无法由控制器批量给出：
  `GET /controller/network/<nwid>` **没有 `members` 键**（对照 1.14.2 磁盘网络
  JSON 与服务 schema 验证），列表端点只回 `{id: revision}`，每个成员要单独
  抓取。`remote_member_list` 把 SSH 成本压缩到**两**条连接——令牌读一次、
  隧道开一次，映射与每个成员都经回环 curl——`remote_peer_list` 再加一调用、
  与之并行。目标硬件（CWWK CW-MBX-AD12，OpenWrt 25.12.5，x86_64，dropbear）
  对 31 成员测试网络、经 LuCI 真实 ubus 路径实测：

  | | |
  |---|---|
  | 单次 `ctl-get`（r34 的成本单位） | 2.05s |
  | r34 N+1，32 次调用 | **65.4s** |
  | r35 `remote_member_list` | **2.57s** |
  | r35 `remote_peer_list` | 2.05s |

  即 **~25 倍**，每次画表省约 63 秒；`member-list` 成本几乎等于单次
  `ctl-get`，因为 31 次成员抓取都是回环请求而非握手。该数字依赖传输，所以
  必须按目标实测：从快链路上的笔记本对比只有 4.5s 对 4.0s（~1.1 倍），因为
  那里 OpenSSH 握手 70-370ms，dropbear ~2s。在错误的宿主上测得的批量化收益
  毫无意义——SSH 握手就是全部成本，数字随客户端走。
- 成员行不是自分隔字符串。`member-list` 把每个控制器响应体原样嵌进一个数组，
  所以每个体先由 awk 校验器确认是**完整** JSON 对象：跟踪字符串与转义状态、
  要求容器按**类型与次序**闭合。朴素的头尾字符检查不够：数组中途截断、`]`
  闭 `{`、尾随 `}` 都能骗过它并毁掉其他所有成员的行。校验失败的体被跳过而非
  嵌入——丢一行可恢复，表不可解析不可恢复。
- 在线判定是"至少一条 `expired !== true` 的路径"。列表中缺席的对端与路径
  全过期的对端都意味着当前未连接，都渲染 `OFFLINE`。控制器自身节点按
  **nwid 前 10 位十六进制**识别，且在在线测试*之前*判——节点永不与自己对端，
  否则永远显示 OFFLINE。
- PLANET 与根对端的 `versionMajor` 是 `-1`，未测得时 `latency` 为 `0` 或负。
  两者都渲染为缺席——`ONLINE` 不带版本、`(-)` 而非 `0 ms`——而不是一条坏
  版本串。
- `/peer` 调用失败时每行渲染 `-` 加一条弱化提示。绝**不**把整表渲染成全
  `OFFLINE`——那是把传输错误发明成状态。
- 成员表获得**客户端过滤**（名字、地址、受管 IP）与已显示/总数计数器。它
  过滤已抓取的数组、绝不重新查询，因为一次击键就要付 SSH 握手的过滤没法用。
- 网络名通过一个小字形就地重命名，blur 或回车提交 `{"name": ...}`，不再只在
  整个网络表单保存时才持久化。
- 取自控制器的成员 id 在进入 URL 前重新校验为恰好 10 位十六进制，
  `member-list` 拒绝非 16 位十六进制的 nwid。映射是远端控制的输入而本脚本
  以 root 运行，URL 安全落在这道校验上、而非其上游的提取上。
- 两个新子命令只发 **GET**，新 `rfetch` helper 方法被钉死、长不成写路径。
  `rctl` 有意未动，r33 的 `ctl-get` 路径保持原样、原样可信。
- **一个 rpcd 方法要三处修改而非两处**，第三处最容易漏，因为没有任何警告：
  ACL 条目（否则浏览器调不到）、`call)` 分发臂（否则报错）、`list)` 声明块
  （否则 rpcd 不注册它、每次调用返回 Method not found 而磁盘上的脚本看起来
  完美）。只有真机 ubus 调用抓住了这个——桩掉 `rpc.declare` 的 DOM harness
  只检查 JavaScript 拨的名字，不检查方法是否存在。

### v2.2-r34

**受管 IP、地址池与路由**

- 网络编辑器新增 **IP 地址池**与**路由**——成员的地址因此可知。此前成员只
  显示节点地址，无法回答"这个节点的 IP 是什么？"。
- 成员表新增**受管 IP** 列，读取控制器的 `ipAssignments`，外加成员名、客户端
  版本与授权状态。空单元格永不含糊：`never connected` 表示节点尚未在该网络
  上线（`vMajor < 0`），`no pool assigned` 表示已上线但没有池覆盖它。
- 成员详情按成员单独抓取而非来自列表（列表只回 `{id: revision}`）。这些调用
  **串行而非并行**——每个都要开 SSH 隧道，30 个并发会砸穿路由器。
- 保存语义由实验确立、非假设。读 1.14.2 的 `networkUpdateFromPostData` 后
  实测确认：标量字段**合并**（每个字段有存在性守卫，省略的字段存活），但
  `routes` 与 `ipAssignmentPools` 是**整体替换的数组**。所以表单把这两者按
  完整清单编辑、按完整清单写回，标量直接发。
- **`v4AssignMode.zt` 不为真时池什么也不分配。** 这是最沉默的一条：`zt` 为
  假时池存了、路由存了、UI 报成功，而任何成员永远收不到地址。现在它总是与
  池一起发送。在 1.14.2 上双向复现——同样的池和路由，没有它得
  `ipAssignments: []`，有它得 `10.88.88.39`。
- 无路由覆盖池子网时，保存前表单警告，否则结果是一个无地址网络且毫无线索。
- `v4AssignMode` 以对象形式 `{"zt": true}` 发送。公开教程写的是字符串
  `"zt"`，但 schema 定义的是对象、守护进程对错误类型静默忽略——照抄教程在
  这里悄悄失败。
- 远端**不**要求控制器模式。管理经 SSH 转发回环端口进行，路由器无需加入
  自己管理的网络；这避开了"要成员资格才能授予成员资格"的自举问题。
- 截图真实页面发现的布局缺陷，而非读代码发现：网络 id 一行一个十六进制字符，
  因为 `.table` 默认 `table-layout:auto`、列被压到最窄不可断内容宽。每网络的
  编辑器还嵌在那个表里，宽池表单与 id 列抢宽度。编辑器现在作为兄弟块移到表
  外，两表都改固定布局。
- 两个面板硬编码浅色背景，在 LuCI 暗色主题下几乎不可读。改用边框并继承主题
  颜色。

### v2.2-r33

**远程控制器 / Moon 管理**

- 新的 **VPN → ZeroTier → 远程控制器** 页。控制器或 Moon 根需要固定公网 IP，
  家用路由器罕有——所以控制器被视为活在另一台服务器上、从这里开通与管理。
  本地 Zerotier 服务不受影响。
- 传输是 **SSH 转发的回环端口**，理由是实测而非假设：控制面无 TLS，
  `allowManagementFrom` 默认为空，所以*每个*非回环请求都是 `401`，即使管理
  令牌有效。在端口对全网开放的主机上验证过——公网带令牌仍 `401`，同一请求
  经隧道 `200`。因此控制器无需任何配置变更，并对 localhost 保持防火墙隔离。
- 控制器**authtoken 按 SSH 现场读取、从不存储在路由器**，OpenWrt 设备上没有
  可泄漏的长期控制器级管理凭据。
- 控制器 API 调用对转发端口在**本地**执行 `curl`，任何浏览器提供的值都不会
  拼进远程 shell 命令。转发路径限定在 `/controller` 之下，`..` 与编码分隔符
  被拒。每个操作员提供的字段都按严格字符类校验（主机、用户、端口、密钥路径、
  16 位十六进制网络 id、10 位十六进制成员 id），拒绝而非转义。
- **网络与成员**可列出、创建、重命名、开关广播、删除、授权/取消授权——替代
  ztncui 的操作集。
- **Moon 创建**：`remote_moon_plan` 返回将要执行的精确命令及摘要；
  `remote_moon_apply` 除非回传该摘要否则拒绝执行，签名操作不可能未经展示就被
  触发。`moon.json`——内含 `signingKey_SECRET`——在远端创建、签名并保留；
  只有不含密钥的已签名 `.moon` 被读回，UI 提供下载以供分发。
- 远程用户的**私钥写入 `0600` 文件**，绝不进 UCI：`/etc/config` 全局可读且
  会被卷入 sysupgrade 备份。字段留空时保留既有密钥，重命名主机不会悄悄毁掉
  它。
- dropbear 的现实，真机发现并处理而非假设：静默忽略 `ConnectTimeout`、
  `LogLevel`、`IdentitiesOnly`、`UserKnownHostsFile`。因此每次 ssh 由自制截止
  时间兜底（也没有 `timeout` 小程序，不可达主机会挂死 RPC），stderr 不并入
  stdout，警告永远不会在退出码仍为 0 时覆盖被解析的数据。
- 每条命令的行为靠运行确立、非读文档：`initmoon` 把世界定义写到 **stdout**
  （不建文件）；`genmoon` 把二进制 `.moon` 写到**当前工作目录**；
  `zerotier-cli orbit` 的种子要的是**根地址**而非文件、给文件即静默无操作
  ——这就是全新 Moon 必须直接递送文件的原因。创建路由是
  `POST /controller/network`；文档里的 `/controller/network/<10hex>______`
  在 1.14.2 源码中注册为 `createNewNetworkOldAndBusted`，返回 `400`。
- 远程控制器建议用非默认端口（`27893`，沿用既有的次/ tertiary 端口模式）。
  这是伪装性的——避免向扫描器做广告，不替代 `allowManagementFrom` 的实际管控。
- 有意**不**实现：控制器规则编辑器（按要求超出范围）；多根 Moon（显式拒绝
  而非半吊子实现）。

### v2.2-r32

**Moon：加入 / 持久化 / 退出**

- 信息页新增 **Moon** 区块：已加入的 Moon 及其根与稳定端点、*添加 Moon* 表单
  （Moon ID + 任一根的地址）与*退出*按钮。Moon 创建有意不在范围——签名密钥
  属于未来的控制器页。
- 完全基于守护进程既有 `/moon` 控制面（`zerotier-cli listmoons|orbit|deorbit`）
  加本应用已镜像的 `moons.d` 文件实现。**不触碰 zerotier 软件包。**
- ZeroTier 变更类调用的退出码不可信，所以两个都对现实核验：
  - 种子为零时 `orbit` 是**退出码 0 的静默无操作**，所以零/非十六进制种子
    上游即拒；
  - 对从未加入过的 Moon，`deorbit` 也返回 `200 deorbit OK`，所以先快照
    Moon 列表、退出后复查；
  - orbit 只有等某个根送达签名世界后才真正落地，中继后可能要等一阵——所以
    等待超时的含义是*待定*而非*失败*，UI 如实相告、不放假错误；
  - Moon ID 在 `/moon/<id>` 路由上是 10 位十六进制、上报却是左侧补零到 16
    位，所以两侧都做归一化。
- Moon 的定义一出现即镜像进 `config_path`，迟到的定义也能自动持久化，用户
  不必去另一页找*立即备份*按钮。
- UI 注明上游 ZeroTier 已不推荐私有 Moon、不在其 SLA 支持内。

**正确性**

- **端口**字段此前无任何校验（`form.Value` 在 luci.js 里没有 `datatype`
  钩子），笔误直接写进 UCI、以 `-p<值>` 到达守护进程。现在校验数字与
  1–65535 范围；`0` 保持合法，上游文档写明它是"随机选端口"。
- 未知对端版本渲染为字面量 `-1.-1.-1`（ZeroTier 的字符串形式，真值、所以
  活过了 `|| '-'`）。现在显示 `-`。
- **RPC 失败曾渲染成"未加入任何网络"/"无对端"**，rpcd 或守护进程打嗡在
  最要紧的时刻看起来像笃定的"你没连接"。失败、服务不可达、真空三态现已
  区分。

**效率**（网络/对端轮询间隔有意未动）

- `status` 曾 fork 六个进程（`ps`、`grep`、`uci get`、`uci show`、`grep`、
  `wc`）只为交付一个布尔值，其中三分之二 UI 根本不读。存活判定改为
  `zerotier-one.pid` + `/proc/<pid>/comm`——零 fork，`comm` 同时防 PID 复用。
  它顺带携带节点地址，设置页一次 RPC 顶过去两次。
- `get_networks` + `get_peers` 合并为 `get_networks_peers`。两者都是同一个
  1.2 MB 的 `zerotier-one` 二进制、每次调用重新加载并连接，且两表同一计时器
  刷新。
- `zerotier-sync.sh` 曾**每文件** fork 一个 `mkdir` 一个 `cp`（~60 次 fork，
  且每次全量重写 `peers.d` 到闪存），发生在每次保存并应用、每次服务停止、每次
  *立即备份*。现在每个状态目录一次拷贝，且不再持久化 `peers.d`——它是纯
  发现缓存、守护进程每次启动自建。陈旧条目仍会被修剪，旧版遗留自净。
- 服务状态轮询从 3s 放宽到 10s；它只在启停时变化。

**杂务**

- `PKG_RELEASE` 32。
- `uci-defaults` 曾检测 `/etc/zerotier-one/local.conf`——OpenWrt 上从未存在
  的路径（运行目录是 `/var/lib/zerotier-one`）。
- 补回从 `po/zh_Hans` 掉落的 `ZeroTier`/`Enable`/`Port` 词条，每个 UI 字符串
  都能从本包自己的目录解析。

### v2.2-r31

**显式区域设备，由 hotplug 驱动**——回到显式设备名（r23 之前的思路）但不再
有它的历史病：

- 枚举直接读 `/sys/class/net/zt*`——不用 `zerotier-cli`（其端口文件会在重启
  间消失）、没有就绪等待循环；
- 更新来自 net hotplug 钩子而非防火墙 include（include 重入 fw4 锁导致死锁
  ——20s 等待循环只是为掩盖它引发的启动竞态而存在）；
- 区域重写是单次原子 `uci batch`，带校验与重试；
- **完全不涉及 netifd**（见 r30）。

从 r23 的 `zt+` 通配迁离，因为 LuCI 的 DeviceSelect 会把通配标为"缺失接口"
——误导性强到有人在生产机上手工"修"成冻结的显式列表。已知残留：端口转发
的来源区域选择器只渲染区域*网络*，设备匹配的区域在那里仍显示 `(空)`。

### v2.2-r30

**回退 r29**（`revert: v2.2-r29 zone membership via netifd interfaces`）。
该设计与守护进程自管地址不兼容，造成生产事故：

1. OpenWrt 24.10 上，netifd 对 `proto=none` 的 `zerotier_<nwid>` 接口的设备
   认领会**冲掉守护进程已分配给 `zt` 设备的 IPv4 地址**。守护进程不会重新
   应用，节点直到守护进程重启前一直不可达。
2. 恢复期间，一次服务重启让 `zt` 设备管理性 DOWN（守护进程在线、端口文件
   缺失）——"除了这台谁都好"的状态，害人往防火墙方向白调试了几小时。

**不要再引入 netifd 对 zerotier 自管设备的所有权。**

### v2.2-r29

**经 netifd 接口的区域成员**——用每网络 `proto=none` 接口节替代 `zt+` 通配。
*r30 已回退；保留记录是因为部署期间发现的两个 bug 塑造了 r31。*

1. **uci 列表解析**：`uci show` 把列表值打包成一行 `network='v1' 'v2'`；
   逐行 `sed` 永远匹配不上、校验无法通过、提交后的重载从未执行，而区域已被
   重写——留下一个什么都匹配不到的区域。
2. **非原子切换**：区域与成员分开提交，中间任何失败都留下空区域。

### v2.2-r28

**自动消失的操作反馈**——操作后的横幅曾用 `ui.addNotification()`，它要手动
消除，且其 Dismiss 按钮依赖主题不保证触发的 `transitionend` 事件（bootstrap
把 `.fade-out` 实现为 CSS *animation*、触发 `animationend`；argon 干脆没有
`.fade-out` 规则，于是横幅赖着不走、Dismiss 像死了）。六处调用点全部改用
`ui.addTimeLimitedNotification()`——成功 5000ms、失败 10000ms——其移除是
无条件的 `setTimeout`。

### v2.2-r27

**应用链路整备与状态同步加固（仅下游，未动上游）**

- `init.d/luci-zerotier`：显式定义 `reload()`。rc.common 的默认是 `restart`
  （stop+start），所以每次 LuCI 保存并应用都把同步 + 规则拆建循环跑两遍
  （ucitrack + general.js 的显式 RPC reload）——`reload_service()` 从来是死
  代码，那个钩子只对 procd 脚本存在。reload 现在是它本该是的轻量幂等
  `start()`（规则就位时不写 uci、不重载防火墙、不同步）。
- 保存并应用现在在**任何**提交之前同步运行时状态。提交 zerotier 配置会触发
  守护进程的 procd reload，其上游 `stop_service` 清空 `/var/lib/zerotier-one`。
  ucitrack/procd 触发次序不确定，所以唯一顺序安全的位置是提交之前、旧运行
  目录尚完好时——过去这条路径绕过全部同步钩子，可能丢弃未同步的控制器/
  Moon 状态。
- `local_conf_path` 改为**导入而非软链**：`sync_config`（每次应用前也运行）
  把配置文件拷入 `config_path/local.conf`。上游用裸 `ln -s` 链接，当
  `config_path` 已提供 `local.conf`（本应用会播种）时静默失败——导入让上游
  `cp -r` 交付正确内容而无需补丁上游。`uci-defaults` 相应地不再在设置了
  `local_conf_path` 时播种 `local.conf`。（UI 描述同步更新。）
- `zerotier-sync.sh`：守护进程状态目录的镜像语义（`networks.d`、`moons.d`、
  `peers.d`、`controller.d`）——守护进程已删除的持久化文件（如退网后的
  `<id>.conf`）会被删掉，而不是下次启动时被复活回运行目录（幽灵重连：那里
  存在 `<id>.conf` 即意味着"加入"）。顶层文件（`planet`、`local.conf`、
  `identity.secret`……）绝不删除。软链模式的 `config_path`
  （`copy_config_path=0`）经 readlink 识别并跳过，不往自己身上拷。
- `ping_networks`：EXIT trap 只在锁仍属本进程时移除（活过期限的扫描否则会
  删掉更新进程的锁、放行第三个并发扫描），期限更新原子化（临时文件 +
  rename——并发申请者否则可能读到写一半的锁文件而误判过期）。
- 菜单：设置页现在也依赖 `luci-app-zerotier-rpc` ACL 组——其状态/身份/
  重载/备份 RPC 都在那里，只持 `luci-app-zerotier` 的会话过去看到的是 RPC
  全挂的页面。

**关于手工重启**：从 shell 执行 `/etc/init.d/zerotier restart` 仍会丢弃未同步
的运行时状态（上游行为，且是有意为之——运行目录设计上就是易失的）。状态要紧
时请用 UI、`ubus call luci-zerotier restart_service`，或先跑
`zerotier-sync.sh`。

### v2.2-r26

**备份模型变更：按需替代定时**

- 彻底移除每小时的 `zerotier-sync` cron（uci-defaults 升级时也会清理）。
  运行时状态持久化现在发生在：
  - **手动**，通过设置页高级选项卡新增的**"立即备份"**按钮（由新
    `sync_config` RPC 支撑）；
  - **生命周期钩子**——`init.d` 的 `stop()`/`shutdown()` 与
    `restart_service` RPC 在动运行目录前先同步。
- 真正需要备份的时机：用 `zerotier orbit` 加 Moon 之后（UI 没有 Moon 配置，
  该状态只活在运行目录里），以及**控制器节点**——成员数据只存在于运行目录
  的 `controller.d`，丢了控制器就空了。普通客户端完全不需要备份：身份由
  UCI `secret` 保证，`local.conf` 从配置重建。docker 容器上优雅关闭路径永不
  执行，每小时的 cron 曾是那里唯一的机制——对大多无关紧要的数据暴露整整
  一小时。

### v2.2-r25

**校验器与路径**
- `config_path` 限定在 `/etc/zerotier`：目录缺失时守护进程拒绝启动，易失的
  `/tmp` 路径会让每次重启后它都死着。两个校验器都删掉了 OpenWrt 上从未存在
  的 `/var/lib/zerotier`。`local_conf_path` 保留 `/tmp` 与
  `/etc/zerotier.conf`，后者改为精确锚定（此前表单接受
  `/etc/zerotier.conf/任意`，而 init 脚本随后拒绝它）。
- sysupgrade 保留清单现覆盖 `/etc/zerotier.conf`。
- `zerotier-sync.sh` 尊重 `zerotier.global.config_path` 而非硬编码持久目录
  （过去即使配置了自定义目录，状态仍写进 `/etc/zerotier`），并在此指向运行
  目录本体时跳过自同步。

**Shell 加固（全部在 busybox ash 1.36 上复现/验证）**
- `ping_networks`：CIDR 前缀在任何 test/算术之前先 glob 校验——非数字前缀
  让两个范围测试双双报错（于是*没有*被跳过），`$((32 - cidr))` 随即按 32
  求值，产生以 root 身份跑 ~40 亿次迭代的 ping 循环。
- `ping_networks` 锁原子化（`set -C` noclobber 创建，消灭 check-then-create
  竞态）、存放按扫描规模重算的绝对期限（多网络扫描不再活过固定 120s 而被
  误判失效）、EXIT/INT/TERM trap 拆分使信号真正终止脚本而不是清理完继续跑、
  并去掉 `mktemp` 后多余的 `rm`（结果文件保持 0600 模式）。
- `restart_service` RPC 现在先同步再重启——zerotier init 的 `stop_service`
  会 `rm -rf /var/lib/zerotier-one`，过去这条路径最多丢一小时未同步状态。
- UCI 配置整体缺失时 init 脚本失效关闭（未设的 `$enabled`/`$nat` 曾让两道
  守卫双双报错、跌落到装规则）。`STOP=98` + 专用 `shutdown()`（仅同步）在
  断电时持久化运行时状态而不搅动防火墙。

**UI 与打包**
- 密钥终于可以从 UI 清除（空提交移除选项；守护进程下次启动生成全新身份）。
  字段描述相应更新。
- 守护进程不在时，设置页身份显示不再卡死在"收集身份中……"（同信息页显示
  `-`）。
- 网格不再强迫用户发明后端从不使用的 section 名（`anonymous = true`，对齐
  原 Lua 应用）。
- 菜单项声明 `depends.acl`，只对持有相应 ACL 组的会话显示；删掉未用的
  `luci getInitList` 授权。
- `uci-defaults` 只在确实移除了陈旧 include 注册时才 commit 防火墙（每次
  commit 都触发异步 fw4 渲染），且不再重启 uhttpd（它杀死了正在装包的
  LuCI 会话本身）。
- `local.conf.template` 不再钉死 `primaryPort: 9993`——本应用的 `端口` 选项
  是唯一事实源（local.conf 的 `primaryPort` 会与守护进程的 `-p` 参数打架）。
  模板注释更新。
- 移除 `po/zh-cn/`：`luci.mk` 只认 `zh_Hans`，该目录从未被构建。更新
  `po/zh_Hans`：补上缺失的 `Allow Managed`/`Allow Global`/`Allow Default
  Route`/`Allow DNS` 词条、新校验器/密钥字符串，清除孤儿条目。

### v2.2-r24

**缺陷修复**
- `general.js`：服务重载现在在 `ui.changes.apply()` 提交配置**之后**执行。
  此前自定义 `m.save` 钩子在 `Map.save()` 后立刻重载——那只是把变更暂存进
  ubus 会话——init 脚本读到的是*上一份*已提交配置，而通知显示的是尚未应用
  的值。现在重载近乎免费：r23 的幂等 `start()` 让规则就位时它等于空操作。
- `info.js`：Ping 按钮标签经 `textContent` 更新——`E('button')` 建的是
  `<button>` 元素，设置 `.value` 没有视觉效果、"Pinging..." 从不显示。补上
  缺失的 `resultEl` 空值守卫，且全离线结果（`Online: 0`）渲染为橙色而非
  绿色。

**杂务**
- README：`get_peers` 描述更正为 `zerotier-cli listpeers`。
- 移除包里游离的空文件 `root/etc/zerotier/zerotier.log`。

### v2.2-r23

**防火墙重做（在 OpenWrt 24.10.7 / fw4-2024.12.18 上复现并验证）**

- **彻底移除 `firewall.include`。** include 在每次 fw4 reload 时重启
  `luci-zerotier`，而 `init.d/luci-zerotier` 又调用
  `/etc/init.d/firewall reload`——在 fw4 持有 `/var/run/fw4.lock` 期间重入
  （fw4 全程持锁，*包括* includes 阶段）。嵌套 fw4 死锁 30s 直到 ucode
  SIGKILL 掉 include，孤儿嵌套 fw4 随即开启**自持的重载级联**：~36s 一个
  周期、不断增长进程积压（每个 stop+start 排队 2 个嵌套 reload、锁每周期
  只排空 1 个）、zerotier 区域反复增删、每周期都写闪存（sync + uci
  commit）。include 的注册也由 `uci-defaults` 升级时清理。
- **区域设备改用 `zt+` 通配**，替代运行时 `zerotier-cli` 枚举 + 20s 就绪
  等待循环。fw4 把 `list device 'zt+'` 渲染为 nftables 通配
  `iifname/oifname "zt*"`，匹配当前*与未来*的设备：没有时序依赖（冷启动时
  控制器授权可能很慢）、init 脚本不依赖 `zerotier-cli`/`jsonfilter`、新加入
  网络的设备自动覆盖。
- **开箱即用的开机持久化**：`uci-defaults` 现在执行
  `/etc/init.d/luci-zerotier enable`。此前没有任何东西启用该服务，保存时装
  上的规则重启即失，直到下次手工保存。
- **`start()` 幂等**：期望的区域/转发已存在时什么都不做——不写 uci、不重载
  防火墙（启动更快、重复保存不刷重载）。遗留的静态设备区域会在首轮用通配
  重建。
- **陈旧规则清理**：关闭 `enabled` 或 `nat` 现在*移除*区域/转发，而不是留在
  身后。
- **fw4 锁守卫**：所有防火墙重载走 `fw_reload()`，fw4 正持锁时跳过显式
  reload（持锁者已渲染完刚提交的 uci 状态，跳过是安全的）。
- **uci 事务竞态加固**：每次 `uci commit firewall` 都触发 procd 的配置
  触发器、fw4 异步重渲染。上一轮 commit 的渲染还在途时，后续单条 `uci`
  命令间歇性失败（`uci: Invalid argument`），已提交状态静默丢选项（复现：
  区域的 `name` 消失；fw4 随即跳过该区域*连同*全部转发——NAT 全断）。每个
  阶段的全部编辑现在合并为单次 `uci batch`，提交结果带重试循环验证（5/5
  连续重启压力中重试触发并自愈）。
- **同步 cron 自愈**：`init.d/luci-zerotier start()` 发现每小时的
  `zerotier-sync` cron 条目缺失时重新补上，因为恢复配置备份会清空 crontab
  而 `uci-defaults` 只跑一次。
- **ucitrack 迁往 JSON**：保存并应用的重载注册改经
  `/usr/share/ucitrack/luci-app-zerotier.json`（procd 配置触发）。
  `uci-defaults` 里旧的 `uci add ucitrack` 注册是死代码：现代 ucitrack 只读
  `/usr/share/ucitrack/*.json`，且在 `/etc/config/ucitrack` 不存在的系统上
  `uci add` 直接报错（24.10.7 验证）。
- **`local_conf` 更名 `local_conf_path`**（修复一个长期静默失败）：LuCI 表单
  把 local.conf 路径存在 `local_conf` 下，而 zerotier 软件包的 init 脚本只认
  `local_conf_path`——该设置从未到达守护进程。`uci-defaults` 升级时迁移既有
  值。同时修复占位符/校验器不匹配：`/etc/zerotier.conf`（上游软件包的惯用
  位置、用作字段占位符）曾被两个校验器双双拒绝；现在仅对 `local_conf_path`
  显式放行。

### v2.2-r22

**缺陷修复**
- 修复 `firewall.include` 不可执行：fw3 在 `type=script` 且 `reload=1` 时经
  `execve()` 调用 include 脚本，没有 `+x` 就被静默跳过。`uci-defaults` 现在
  显式 `chmod +x`。
- 修复 include 与区域重名：include 注册为 `firewall.zerotier`（与运行时区域
  同名）。首次防火墙 reload 时 `init.d/luci-zerotier` 为建区域而删
  `firewall.zerotier`——把 include 自己也删了，后续 reload 永不再触发脚本。
  include 更名 `firewall.zerotier_include`。

**JSON 迁移（可靠性）**
- 所有 `zerotier-cli` 调用改用 `-j`（JSON 输出），替代文本模式 `awk` 列
  解析：
  - `get_identity`：`zerotier-cli -j info` → `jsonfilter -e '@.address'`
    （原 `awk '{print $3}'`）
  - `get_networks` / `get_peers`：返回原始 JSON，前端 `JSON.parse()` 取代
    脆弱的 `split(/\s+/)` 文本解析
  - `ping_networks`：`zerotier-cli -j listnetworks | jsonfilter -e
    '$[*].assignedAddresses[*]'` 取代 `while read | set -- | $9` 管道
  - `init.d` 设备探测：`jsonfilter -e '$[*].portDeviceName'` 取代
    `awk '$8 ~ /^zt/'`
- 对端表：移除 `Last TX`/`Last RX` 列（原始 epoch 时间戳没有用处）；`link`
  状态改由 `peer.tunneled` / `paths[].active` JSON 字段推导，不再依赖脆弱的
  文本列。

**加固**
- `ping_networks`：以 **FIFO 计数信号量**取代批-等待并发（`MAX_PARALLEL=32`，
  一个慢 ping 拖住整批）。预填充令牌的命名管道；每个 `ping_one()` 阻塞在
  `read -u 9` 上等空位，后台子 shell 完成后归还令牌。**MAX_RUNNING 自适应**：
  由 `MemAvailable / 3 / 每槽300kB` 推导（实测每并发槽 ~150 kB RSS、2 倍安全
  余量、仅用三分之一可用内存），夹在 [16, 512]。1GB 内存路由器（~750 MB
  可用）得 512，/23（512 IP）单波跑完（~3s）。128 MB 设备（~64 MB 可用）
  仍得 512。只有极低内存（可用 < 16 MB）才降档。在 busybox ash 1.35
  （OpenWrt `/bin/sh`）、R2S（1 GB RAM）与 OpenWrt VM 上测试。
- `secret` 字段：值改为掩码显示（前 4 位 + 圆点 + 后 4 位），不再明文。完整
  提交值仍在用户替换时写入 `/etc/config/zerotier`；空提交或未变的掩码值保留
  既有密钥（不会误覆盖）。
- 服务端路径校验：`init.d/luci-zerotier` 在 reload 时校验 `local_conf` 与
  `config_path` 的 UCI 值，拒绝 `/etc/zerotier`、`/var/lib/zerotier`、
  `/tmp` 之外的路径（镜像 general.js 的客户端正则）。针对绕过前端的纵深
  防御。
- 网络 ID：新增格式校验（必须 16 位十六进制）。
- ACL 清理：移除遗留的 `rpcd/zerotier` 后端（死代码，还在用
  `ifconfig | grep`）。RPC ACL 文件中的 ACL 组键从 `"luci-app-zerotier"`
  改名 `"luci-app-zerotier-rpc"`，避免两个 ACL 文件定义同键时静默互相覆盖。

**文档**
- `local.conf.template`：移除非法默认值
  `"tcpFallbackRelay": "<RELAY_SERVER_IP>/443"`（占位符不是合法 IP、破坏
  ZeroTier 解析）。生成的 `local.conf` 不再携带 `tcpFallbackRelay`；需要 TCP
  回退的用户按内嵌说明取消注释并填入自己的中继 IP（如
  `10.10.10.10/443`）。
- `ping_networks`：补充设计注释，记录 /23 扫描上限——更大子网（/22、/21、
  /16）只扫描所在 /24，因为 /23 已覆盖典型 ZeroTier 部署、扫数千主机超出
  范围（请改用 nmap）。

### v2.2-r21

**前端重写（info.js）**
- 纯 textarea 换成结构化网络与对端表格
- 增加彩色指示：状态（绿/红/橙）、角色（PLANET/MOON/LEAF）、链路
  （DIRECT/RELAY）
- 增加"全网 Ping"按钮：并发子网扫描与在线主机展示
- 增加节点身份（地址）展示，10s 轮询

**前端清理（general.js）**
- 移除啰嗦的 `console.log` 调试输出
- 移除 5 秒 `setTimeout` 延迟——保存时服务重载即刻执行
- 为 `local_conf` 与 `config_path` 增加路径校验（须位于 `/etc/zerotier`、
  `/var/lib/zerotier` 或 `/tmp` 之下）
- 设置页增加节点身份展示

**RPC 守护（luci-zerotier）**
- 以专用的 `get_networks`、`get_identity`、`get_peers`、`ping_networks`
  取代 `get_interfaces`
- 新增 `ping_networks` 方法：解析已分配 IP、并发派生 ping 进程、返回
  OK/FAIL 结果
- 使用 POSIX here-doc（而非 bash 进程替换）保证 shell 兼容
- 进程探测从 `pgrep` 改为 `ps | grep`（更可移植）

**Init 脚本（luci-zerotier）**
- 修复：设备探测改用 `zerotier-cli listnetworks | awk '$8 ~ /^zt/'`，取代
  `ifconfig | grep 'zt'`
  - 只匹配真实 `zt` 设备名、滤掉 `-`（未就绪占位）
  - 避免把非法接口名写进防火墙区域设备列表
- 修复：增加 2s×10 轮询、超时兜底的设备就绪等待
- 修复：增加 `zerotier-one` 守护进程检查（不只看 init 脚本状态）
- 修复：变量正确加引号（`"$enabled"` 而非裸 `$enabled`）
- 新增：`zerotier → wan` 转发规则（ZT 对端的网关模式）
- 新增：`reload_service()` 函数
- 清理 `stop()`：无条件删除全部防火墙规则

**安全**
- 从 ACL 权限移除 `luci.exec`
- 从所有代码路径移除危险的 `exec` RPC 方法

**遗留 RPC（zerotier）**
- 修复：`grep 'zt'` → `grep '^zt'`，避免误匹配无关接口

**翻译（po/zh_Hans）**
- 为全部新增 UI 字符串补录 40+ 词条

### v2.2-r20（初始 JavaScript 转换）

- 使用 AUGMENT Code 完成 Lua → JavaScript 全量转换
- 自定义 `luci-zerotier` RPC 对象取代 `luci.exec`
- 自动 NAT 客户端与服务重载
- 基础接口信息展示（基于 textarea）

## 许可证

Apache License 2.0

## 致谢

- 原 Lua 版本：https://github.com/zhengmz/luci-app-zerotier
- ZeroTier：https://www.zerotier.com
- OpenWrt LuCI 框架
