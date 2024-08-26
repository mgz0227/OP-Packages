<?php
$subscription_file = '/etc/neko/config/subscription.txt'; 
$download_path = '/etc/neko/config/'; 
$php_script_path = '/www/nekoclash/personal.php'; 
$sh_script_path = '/etc/neko/update_config.sh'; 
$cron_job = '0 3 * * * /etc/neko/update_config.sh'; 

function saveSubscriptionUrlToFile($url, $file) {
    return file_put_contents($file, $url) !== false;
}

function transformContent($content) {
    $additional_config = "
redir-port: 7892
mixed-port: 7893
tproxy-port: 7895
secret: Akun
external-ui: ui

tun:
  enable: true
  prefer-h3: true
  listen: 0.0.0.0:53
  stack: gvisor
  dns-hijack:
     - \"any:53\"
     - \"tcp://any:53\"
  auto-redir: true
  auto-route: true
  auto-detect-interface: true
  enhanced-mode: fake-ip"; 

    $search = 'external-controller: :9090';
    $replace = 'external-controller: 0.0.0.0:9090';

    $dns_config = <<<EOD
dns:
  enable: true
  ipv6: true
  default-nameserver:
    - '1.1.1.1'
    - '8.8.8.8'
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    - 'stun.*.*'
    - 'stun.*.*.*'
    - '+.stun.*.*'
    - '+.stun.*.*.*'
    - '+.stun.*.*.*.*'
    - '+.stun.*.*.*.*.*'
    - '*.lan'
    - '+.msftncsi.com'
    - msftconnecttest.com
    - 'time?.*.com'
    - 'time.*.com'
    - 'time.*.gov'
    - 'time.*.apple.com'
    - time-ios.apple.com
    - 'time1.*.com'
    - 'time2.*.com'
    - 'time3.*.com'
    - 'time4.*.com'
    - 'time5.*.com'
    - 'time6.*.com'
    - 'time7.*.com'
    - 'ntp?.*.com'
    - 'ntp.*.com'
    - 'ntp1.*.com'
    - 'ntp2.*.com'
    - 'ntp3.*.com'
    - 'ntp4.*.com'
    - 'ntp5.*.com'
    - 'ntp6.*.com'
    - 'ntp7.*.com'
    - '+.pool.ntp.org'
    - '+.ipv6.microsoft.com'
    - speedtest.cros.wr.pvp.net
    - network-test.debian.org
    - detectportal.firefox.com
    - cable.auth.com
    - miwifi.com
    - routerlogin.com
    - routerlogin.net
    - tendawifi.com
    - tendawifi.net
    - tplinklogin.net
    - tplinkwifi.net
    - '*.xiami.com'
    - tplinkrepeater.net
    - router.asus.com
    - '*.*.*.srv.nintendo.net'
    - '*.*.stun.playstation.net'
    - '*.openwrt.pool.ntp.org'
    - resolver1.opendns.com
    - 'GC._msDCS.*.*'
    - 'DC._msDCS.*.*'
    - 'PDC._msDCS.*.*'
  use-hosts: true

  nameserver:
    - '8.8.4.4'
    - '1.0.0.1'
    - "https://1.0.0.1/dns-query"
    - "https://8.8.4.4/dns-query"
EOD;

    $lines = explode("\n", $content);
    $new_lines = [];
    $dns_section = false;
    $added = false;

    foreach ($lines as $line) {
        if (strpos($line, 'dns:') !== false) {
            $dns_section = true;
            $new_lines[] = $dns_config;
            continue;
        }

        if ($dns_section) {
            if (strpos($line, 'proxies:') !== false) {
                $dns_section = false;
            } else {
                continue;
            }
        }

        $line = str_replace('secret', 'bbc', $line);

        if (trim($line) === $search) {
            $new_lines[] = $replace;
            $new_lines[] = $additional_config;
            $added = true;
        } else {
            $new_lines[] = $line;
        }
    }

    if (!$added) {
        $new_lines[] = $replace;
        $new_lines[] = $additional_config;
    }

    return implode("\n", $new_lines);
}

function saveSubscriptionContentToYaml($url, $filename) {
    global $download_path;

    if (preg_match('/[^A-Za-z0-9._-]/', $filename)) {
        return "文件名包含非法字符，请使用字母、数字、点、下划线或横杠。";
    }

    if (!is_dir($download_path)) {
        if (!mkdir($download_path, 0755, true)) {
            return "无法创建目录：$download_path";
        }
    }

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
    $subscription_data = curl_exec($ch);

    if (curl_errno($ch)) {
        $error_msg = curl_error($ch);
        curl_close($ch);
        return "cURL 错误: $error_msg";
    }
    curl_close($ch);

    if ($subscription_data === false || empty($subscription_data)) {
        return "无法获取订阅内容。请检查链接是否正确。";
    }

    if (base64_decode($subscription_data, true) !== false) {
        $decoded_data = base64_decode($subscription_data);
    } else {
        $decoded_data = $subscription_data;
    }

    $transformed_data = transformContent($decoded_data);

    $file_path = $download_path . $filename;
    if (file_put_contents($file_path, $transformed_data) !== false) {
        return "内容已成功保存到：$file_path";
    } else {
        return "文件保存失败。";
    }
}

function generateShellScript() {
    global $subscription_file, $download_path, $php_script_path, $sh_script_path;

    $sh_script_content = <<<EOD
#!/bin/bash

SUBSCRIPTION_FILE='$subscription_file'
DOWNLOAD_PATH='$download_path'
DEST_PATH='/etc/neko/config/config.yaml'
PHP_SCRIPT_PATH='$php_script_path'

if [ ! -f "\$SUBSCRIPTION_FILE" ]; then
    echo "未找到订阅文件: \$SUBSCRIPTION_FILE"
    exit 1
fi

SUBSCRIPTION_URL=\$(cat "\$SUBSCRIPTION_FILE")

php -f "\$PHP_SCRIPT_PATH" <<EOF
POST
subscription_url=\$SUBSCRIPTION_URL
filename=config.yaml
EOF

UPDATED_FILE="\$DOWNLOAD_PATH/config.yaml"
if [ ! -f "\$UPDATED_FILE" ]; then
    echo "未找到更新后的配置文件: \$UPDATED_FILE"
    exit 1
fi

mv "\$UPDATED_FILE" "\$DEST_PATH"

if [ \$? -eq 0 ]; then
    echo "配置文件已成功更新并移动到 \$DEST_PATH"
else
    echo "配置文件移动到 \$DEST_PATH 失败"
    exit 1
fi
EOD;

    if (file_put_contents($sh_script_path, $sh_script_content) !== false) {
        shell_exec("chmod +x $sh_script_path");
        return "Shell 脚本已成功创建并赋予执行权限。";
    } else {
        return "无法创建 Shell 脚本文件。";
    }
}

function setupCronJob() {
    global $sh_script_path, $cron_job;

    $cron_entry = "$cron_job\n";
    $current_cron = shell_exec('crontab -l 2>/dev/null');
    if (strpos($current_cron, $sh_script_path) === false) {
        $new_cron = $current_cron . $cron_entry;
        file_put_contents('/tmp/crontab.txt', $new_cron);
        shell_exec('crontab /tmp/crontab.txt');
        return "Cron 作业已成功设置。";
    } else {
        return "Cron 作业已存在。";
    }
}

$result = '';
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    if (isset($_POST['subscription_url']) && isset($_POST['filename'])) {
        $subscription_url = $_POST['subscription_url'];
        $filename = $_POST['filename'];
        if (empty($filename)) {
            $filename = 'config.yaml';
        }

        if (saveSubscriptionUrlToFile($subscription_url, $subscription_file)) {
            $result .= saveSubscriptionContentToYaml($subscription_url, $filename) . "<br>";
            $result .= generateShellScript() . "<br>";
            $result .= setupCronJob() . "<br>";
        } else {
            $result = "保存订阅链接失败。";
        }
    } else {
        $result = "请填写所有字段。";
    }
}

function getSubscriptionUrlFromFile($file) {
    if (file_exists($file)) {
        return file_get_contents($file);
    }
    return '';
}

$current_subscription_url = getSubscriptionUrlFromFile($subscription_file);
?>

<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mihomo 订阅程序</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #87ceeb;
            color: #333;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
        }
        .container {
            background: #fff;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
            width: 100%;
            max-width: 600px;
            box-sizing: border-box;
        }
        h1 {
            font-size: 24px;
            margin-bottom: 20px;
            text-align: center;
        }
        .result {
            display: <?php echo $result ? 'block' : 'none'; ?>;
            margin-bottom: 20px;
            padding: 10px;
            background-color: #eaf7e3;
            border: 1px solid #d4edda;
            border-radius: 4px;
            color: #155724;
            text-align: center;
        }
        .help {
            margin-bottom: 20px;
            padding: 15px;
            background-color: #f0f9ff;
            border: 1px solid #d1ecf1;
            border-radius: 4px;
            color: #0c5460;
            text-align: left;
        }
        .help h2 {
            font-size: 20px;
            margin-top: 0;
            margin-bottom: 10px;
        }
        .help p {
            margin: 0 0 10px 0;
        }
        .help ul {
            margin: 0;
            padding-left: 20px;
        }
        .help li {
            margin-bottom: 5px;
        }
        label {
            display: block;
            margin-bottom: 8px;
        }
        input[type="text"] {
            width: calc(100% - 22px);
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 4px;
            margin-bottom: 10px;
        }
        button {
            width: 100%;
            padding: 10px;
            border: none;
            border-radius: 4px;
            background-color: #007bff;
            color: #fff;
            font-size: 16px;
            cursor: pointer;
        }
        button:hover {
            background-color: #0056b3;
        }
        .back-button {
            background-color: #6c757d;
            margin-top: 10px;
        }
        .back-button:hover {
            background-color: #5a6268;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Mihomo 订阅程序（个人版）</h1>
        <form method="post" action="">
            <label for="subscription_url">输入订阅链接:</label>
            <input type="text" id="subscription_url" name="subscription_url" 
                   value="<?php echo htmlspecialchars($current_subscription_url); ?>" 
                   required><br>
            
            <label for="filename">输入保存文件名 (默认: config.yaml):</label>
            <input type="text" id="filename" name="filename" 
                   value="<?php echo htmlspecialchars(isset($_POST['filename']) ? $_POST['filename'] : ''); ?>" 
                   placeholder="config.yaml"><br>
            
            <button type="submit">更新</button>
            <button type="button" class="back-button" onclick="history.back()">返回上一级</button>
        </form>
        <div class="help">
            <h2 style="text-align: center;">帮助说明</h2>
            <p>欢迎使用 Mihomo 订阅程序！请按照以下步骤进行操作：</p>
            <ul>
                <li><strong>输入订阅链接:</strong> 在文本框中输入您的Clash订阅链接。</li>
                <li><strong>输入保存文件名:</strong> 指定保存配置文件的文件名，默认为 "config.yaml"。</li>
                <li>点击 "更新" 按钮，系统将下载订阅内容，并进行转换和保存。</li>
                <li>操作成功后，去配置文件选择config.yaml启动，就能使用你的自定义配置了。</li>
                <li>创建脚本，默认更新会创建自动更新脚本设置为每天3点更新，要修改请移步计划任务</li>
                <li>配置文件，内置通用模板 tuanbe.yaml 优点是兼容性好无需转换，个人版订阅只支持Clash格式，可以自行设置.yaml 的名称，在配置选择启用，不要用中文名，config.json为Sing-box的配置文件不能修改</li>
            </ul>
        </div>
        <div class="result">
            <?php echo nl2br(htmlspecialchars($result)); ?>
        </div>
    </div>
</body>
</htm
