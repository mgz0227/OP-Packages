--- a/luci-app-passwall2/root/etc/uci-defaults/luci-passwall2
+++ b/luci-app-passwall2/root/etc/uci-defaults/luci-passwall2
@@ -36,6 +36,11 @@ touch /etc/config/passwall2_show >/dev/null 2>&1
 
 chmod +x /usr/share/passwall2/*.sh
 
+[ "`which nft`" ] && {
+uci -q set passwall2.@global_forwarding[0].use_nft=1
+uci -q commit passwall2
+}
+
 rm -f /tmp/luci-indexcache
 rm -rf /tmp/luci-modulecache/
 killall -HUP rpcd 2>/dev/null

--- a/luci-app-passwall2/Makefile
+++ b/luci-app-passwall2/Makefile
@@ -32,6 +32,21 @@ LUCI_DEPENDS:=+coreutils +coreutils-base64 +coreutils-nohup +curl \
 	+ip-full +libuci-lua +lua +luci-compat +luci-lib-jsonc +resolveip +tcping \
 	+xray-core +v2ray-geoip +v2ray-geosite \
 	+unzip \
+	+PACKAGE_$(PKG_NAME)_INCLUDE_Haproxy:haproxy \
+	+PACKAGE_$(PKG_NAME)_INCLUDE_Hysteria:hysteria \
+	+PACKAGE_$(PKG_NAME)_INCLUDE_NaiveProxy:naiveproxy \
+	+PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev_Client:shadowsocks-libev-ss-local \
+	+PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev_Client:shadowsocks-libev-ss-redir \
+	+PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev_Server:shadowsocks-libev-ss-server \
+	+PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Rust_Client:shadowsocks-rust-sslocal \
+	+PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Rust_Server:shadowsocks-rust-ssserver \
+	+PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR_Libev_Client:shadowsocksr-libev-ssr-local \
+	+PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR_Libev_Client:shadowsocksr-libev-ssr-redir \
+	+PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR_Libev_Server:shadowsocksr-libev-ssr-server \
+	+PACKAGE_$(PKG_NAME)_INCLUDE_Simple_Obfs:simple-obfs \
+	+PACKAGE_$(PKG_NAME)_INCLUDE_SingBox:sing-box \
+	+PACKAGE_$(PKG_NAME)_INCLUDE_tuic_client:tuic-client \
+	+PACKAGE_$(PKG_NAME)_INCLUDE_V2ray_Plugin:v2ray-plugin \
 	+PACKAGE_$(PKG_NAME)_INCLUDE_IPv6_Nat:ip6tables-mod-nat
 
 define Package/$(PKG_NAME)/config
@@ -71,7 +86,6 @@ config PACKAGE_$(PKG_NAME)_Nftables_Transparent_Proxy
 
 config PACKAGE_$(PKG_NAME)_INCLUDE_Haproxy
 	bool "Include Haproxy"
-	select PACKAGE_haproxy
 	default y if aarch64||arm||i386||x86_64
 
 config PACKAGE_$(PKG_NAME)_INCLUDE_Hysteria
@@ -87,8 +101,6 @@ config PACKAGE_$(PKG_NAME)_INCLUDE_NaiveProxy
 
 config PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev_Client
 	bool "Include Shadowsocks Libev Client"
-	select PACKAGE_shadowsocks-libev-ss-local
-	select PACKAGE_shadowsocks-libev-ss-redir
 	default y
 
 config PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev_Server
@@ -99,7 +111,6 @@ config PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev_Server
 config PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Rust_Client
 	bool "Include Shadowsocks Rust Client"
 	depends on aarch64||arm||i386||mips||mipsel||x86_64
-	select PACKAGE_shadowsocks-rust-sslocal
 	default y if aarch64
 
 config PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Rust_Server
@@ -110,8 +121,6 @@ config PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Rust_Server
 
 config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR_Libev_Client
 	bool "Include ShadowsocksR Libev Client"
-	select PACKAGE_shadowsocksr-libev-ssr-local
-	select PACKAGE_shadowsocksr-libev-ssr-redir
 	default y
 
 config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR_Libev_Server
@@ -121,12 +130,10 @@ config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR_Libev_Server
 
 config PACKAGE_$(PKG_NAME)_INCLUDE_Simple_Obfs
 	bool "Include Simple-Obfs (Shadowsocks Plugin)"
-	select PACKAGE_simple-obfs
 	default y
 
 config PACKAGE_$(PKG_NAME)_INCLUDE_SingBox
 	bool "Include Sing-Box"
-	select PACKAGE_sing-box
 	default y if aarch64||arm||i386||x86_64
 
 config PACKAGE_$(PKG_NAME)_INCLUDE_tuic_client
@@ -137,7 +144,6 @@ config PACKAGE_$(PKG_NAME)_INCLUDE_tuic_client
 
 config PACKAGE_$(PKG_NAME)_INCLUDE_V2ray_Plugin
 	bool "Include V2ray-Plugin (Shadowsocks Plugin)"
-	select PACKAGE_v2ray-plugin
 	default y if aarch64||arm||i386||x86_64
 
 endif

--- a/luci-app-passwall2/luasrc/controller/passwall2.lua
+++ b/luci-app-passwall2/luasrc/controller/passwall2.lua
@@ -74,6 +74,7 @@ function index()
 	entry({"admin", "services", appname, "clear_all_nodes"}, call("clear_all_nodes")).leaf = true
 	entry({"admin", "services", appname, "delete_select_nodes"}, call("delete_select_nodes")).leaf = true
 	entry({"admin", "services", appname, "update_rules"}, call("update_rules")).leaf = true
+	entry({"admin", "services", appname, "ip"}, call('check_ip')).leaf = true
 
 	--[[Components update]]
 	local coms = require "luci.passwall2.com"
@@ -89,6 +90,61 @@ local function http_write_json(content)
 	http.write_json(content or {code = 1})
 end
 
+function check_site(host, port)
+    local nixio = require "nixio"
+    local socket = nixio.socket("inet", "stream")
+    socket:setopt("socket", "rcvtimeo", 2)
+    socket:setopt("socket", "sndtimeo", 2)
+    local ret = socket:connect(host, port)
+    socket:close()
+    return ret
+end
+
+function get_ip_geo_info()
+    local result = luci.sys.exec('curl --retry 3 -m 10 -LfsA "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.183 Safari/537.36" http://ip-api.com/json/')
+    local json = require "luci.jsonc"
+    local info = json.parse(result)
+    
+    return {
+        flag = string.lower(info.countryCode) or "un",
+        country = get_country_name(info.countryCode) or "Unknown",
+        ip = info.query,
+        isp = info.isp
+    }
+end
+
+function get_country_name(countryCode)
+    local country_names = {
+        US = "美国", CN = "中国", JP = "日本", GB = "英国", DE = "德国",
+        FR = "法国", BR = "巴西", IT = "意大利", RU = "俄罗斯", CA = "加拿大",
+        KR = "韩国", ES = "西班牙", AU = "澳大利亚", MX = "墨西哥", ID = "印度尼西亚",
+        NL = "荷兰", TR = "土耳其", CH = "瑞士", SA = "沙特阿拉伯", SE = "瑞典",
+        PL = "波兰", BE = "比利时", AR = "阿根廷", NO = "挪威", AT = "奥地利",
+        TW = "台湾", ZA = "南非", TH = "泰国", DK = "丹麦", MY = "马来西亚",
+        PH = "菲律宾", SG = "新加坡", IE = "爱尔兰", HK = "香港", FI = "芬兰",
+        CL = "智利", PT = "葡萄牙", GR = "希腊", IL = "以色列", NZ = "新西兰",
+        CZ = "捷克", RO = "罗马尼亚", VN = "越南", UA = "乌克兰", HU = "匈牙利",
+        AE = "阿联酋", CO = "哥伦比亚", IN = "印度", EG = "埃及", PE = "秘鲁", TW = "台湾"
+    }
+    return country_names[countryCode]
+end
+
+function check_ip()
+    local e = {}
+    local port = 80
+    local geo_info = get_ip_geo_info(ip)
+    e.ip = geo_info.ip
+    e.flag = geo_info.flag
+    e.country = geo_info.country
+    e.isp = geo_info.isp
+    e.baidu = check_site('www.baidu.com', port)
+    e.taobao = check_site('www.taobao.com', port)
+    e.google = check_site('www.google.com', port)
+    e.youtube = check_site('www.youtube.com', port)
+    luci.http.prepare_content('application/json')
+    luci.http.write_json(e)
+end
+
 function reset_config()
 	luci.sys.call('/etc/init.d/passwall2 stop')
 	luci.sys.call('[ -f "/usr/share/passwall2/0_default_config" ] && cp -f /usr/share/passwall2/0_default_config /etc/config/passwall2')

--- a/luci-app-passwall2/luasrc/model/cbi/passwall2/client/global.lua
+++ b/luci-app-passwall2/luasrc/model/cbi/passwall2/client/global.lua
@@ -411,5 +411,6 @@ for k, v in pairs(nodes_table) do
 end
 
 m:append(Template(appname .. "/global/footer"))
+m:append(Template(appname .. "/global/status_bottom"))
 
 return m

diff --git a/luci-app-passwall2/luasrc/view/passwall2/global/status_bottom.htm b/luci-app-passwall2/luasrc/view/passwall2/global/status_bottom.htm
new file mode 100644
index 000000000000..a00fff9c79b3
--- /dev/null
+++ b/luci-app-passwall2/luasrc/view/passwall2/global/status_bottom.htm
@@ -0,0 +1,128 @@
+<style>
+.pure-img {
+    max-height: 100%;
+    width: auto;
+}
+.flag .pure-img {
+    max-height: none;
+    margin-top: -0.34rem;
+}
+.status-bar {
+    position: fixed;
+    bottom: 0;
+    right: 0;
+    box-shadow: 0 0 2rem 0 rgba(136, 152, 170, .3);
+    color: #525f7f;
+    background: #fff;
+    z-index: 5;
+    box-sizing: border-box;
+}
+
+.status-bar .inner {
+    margin: 0.5em;
+}
+
+.status-bar .inner .flag {
+    height: 2.6em;
+    display: block;
+    float: left;
+    margin-right: 1em;
+}
+
+.status-bar .inner .status-info {
+    font-weight: bold;
+}
+
+.status-bar .icon-con {
+    height: 2.6em;
+    text-align: right;
+}
+
+#cbi-passwall+.cbi-page-actions.control-group.fixed {
+    bottom: 3.3rem;
+}
+
+footer{
+display:block !important;
+}
+    
+@media screen and (max-width: 700px) {
+.status-bar .icon-con {
+    height: 2.5em;
+}
+}
+</style>
+<div class="status-bar">
+    <div class="inner">
+        <div class="pure-g">
+            <div class="pure-u-1-2">
+                <span class="flag"><img src="/luci-static/passwall/flags/loading.svg" class="pure-img"></span> <span
+                    class="status-info">获取中...</span>
+            </div>
+            <div class="pure-u-1-2">
+                <div class="icon-con">
+                    <img src="/luci-static/passwall/img/site_icon1_01.png" class="pure-img i1">
+                    <img src="/luci-static/passwall/img/site_icon1_02.png" class="pure-img i2">
+                    <img src="/luci-static/passwall/img/site_icon1_03.png" class="pure-img i3">
+                    <img src="/luci-static/passwall/img/site_icon1_04.png" class="pure-img i4">
+                </div>
+            </div>
+        </div>
+    </div>
+</div>
+
+<script>
+const _ASSETS = '/luci-static/passwall/';
+const CHECK_IP_URL = '<%=url([[admin]], [[services]], [[passwall]], [[ip]])%>';
+
+let wW = window.innerWidth;
+
+function resize() {
+    wW = window.innerWidth;
+    let lw = document.querySelector(".main-left")?.offsetWidth ?? 5;
+    let statusBar = document.querySelector(".status-bar");
+    statusBar.style.width = (wW - lw) + 'px';
+    let flagElement = statusBar.querySelector(".flag");
+    flagElement.style.width = (flagElement.offsetHeight / 3 * 4) + 'px';
+
+    document.querySelectorAll(".flag-icon").forEach(function(el) {
+        if (el.offsetHeight < 60) {
+            el.parentElement.style.height = '60px';
+            el.style.width = '60px';
+        } else {
+            el.style.width = el.offsetHeight + 'px';
+        }
+    });
+}
+
+function write_status(data) {
+        document.querySelector(".flag img").src = _ASSETS + "flags/" + data.flag + ".svg";
+        document.querySelector(".status-info").innerHTML = data.ip + "<br>" + data.country + "&nbsp;" + data.isp;
+    document.querySelector(".i1").src = data.baidu ? _ASSETS + "img/site_icon_01.png" : _ASSETS + "img/site_icon1_01.png";
+    document.querySelector(".i2").src = data.taobao ? _ASSETS + "img/site_icon_02.png" : _ASSETS + "img/site_icon1_02.png";
+    document.querySelector(".i3").src = data.google ? _ASSETS + "img/site_icon_03.png" : _ASSETS + "img/site_icon1_03.png";
+    document.querySelector(".i4").src = data.youtube ? _ASSETS + "img/site_icon_04.png" : _ASSETS + "img/site_icon1_04.png";
+    setTimeout(function() {
+        let event = new Event('iploaded');
+        document.body.dispatchEvent(event);
+    }, 200);
+}
+
+XHR.poll(5, CHECK_IP_URL, null,
+        function (x, data) {
+            write_status(data);
+        }
+    );
+
+document.addEventListener('DOMContentLoaded', function() {
+    setTimeout("resize()",100)
+    fetch(CHECK_IP_URL)
+        .then(response => response.json())
+        .then(data => {
+            write_status(data);
+        })
+        .catch(error => console.error('Error:', error));
+});
+
+window.addEventListener('resize', resize);
+</script>
