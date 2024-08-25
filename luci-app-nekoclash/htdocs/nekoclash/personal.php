<?php
$subscription_file = 'subscription.txt';
$download_path = '/etc/neko/config/';

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

    $lines = explode("\n", $content);
    $new_lines = [];
    $added = false;

    foreach ($lines as $line) {
        if (strpos($line, 'DOMAIN-SUFFIX,isasecret.com') !== false) {
            continue;
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

$result = '';
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    if (isset($_POST['subscription_url']) && isset($_POST['filename'])) {
        $subscription_url = $_POST['subscription_url'];
        $filename = $_POST['filename'];
        if (empty($filename)) {
            $filename = 'config.yaml';
        }

        if (saveSubscriptionUrlToFile($subscription_url, $subscription_file)) {
            $result = saveSubscriptionContentToYaml($subscription_url, $filename);
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
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mihomo 订阅程序</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f4f4f4;
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
            text-align: left; /* Align text to the left */
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
        <h1>Mihomo 订阅程序 (个人版）</h1>
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
                <li>操作成功后，去配置文件选择config.yaml启动，就是你的自定义配置了。</li>
            </ul>
        </div>
        <div class="result">
            <?php
            if ($result) {
                echo htmlspecialchars($result);
            }
            ?>
        </div>
    </div>
</body>
</html>
