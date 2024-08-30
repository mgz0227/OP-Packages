--- a/luci-app-nekoclash/htdocs/nekoclash/devinfo.php
+++ b/luci-app-nekoclash/htdocs/nekoclash/devinfo.php
@@ -75,6 +75,7 @@
         }
 
         #player {
+            display:none !important;
             width: 320px;
             height: 320px;
             margin: 50px auto;
@@ -649,16 +650,6 @@ function fetchWeather() {
                 })
                 .catch(error => console.error('获取天气数据时出错:', error));
         }
-
-        window.onload = function() {
-            speakMessage('欢迎使用语音播报系统！');
-            checkWebsiteAccess(websites);
-            speakCurrentTime();
-            fetchWeather();
-            speakRandomPoem(); 
-            setInterval(updateTime, 1000);
-            speakMessage('您的音乐播放已暂时关闭，按下 ESC 键即可重新启用音乐播放。Your music playback has been paused. Press the ESC key to resume.');
-        };
     </script>
 </body>
 </html>
