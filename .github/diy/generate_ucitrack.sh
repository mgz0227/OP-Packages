#!/bin/bash

find . -type f \
    -not -path "*.github*" \
    -not -name "Makefile" \
    | while read -r file; do
    if grep -q "add ucitrack" "$file"; then
        # 提取xx的值
        xx=$(grep "add ucitrack" "$file" | awk '{print $3}' | head -1)
        
        # 构建要插入的内容
        insert_content="[ ! -f \"/usr/share/ucitrack/luci-app-${xx}.json\" ] && {
    mkdir -p /usr/share/ucitrack
    cat > /usr/share/ucitrack/luci-app-${xx}.json << EEOF
{
    \\\"config\\\": \\\"${xx}\\\",
    \\\"init\\\": \\\"${xx}\\\"
}
EEOF
}
"
        # 使用sed直接修改文件
        sed -i "1a\\${insert_content}" "$file"
        sed -i '/ ucitrack/d' "$file"
        
        echo "已处理文件: $file"
    fi
done