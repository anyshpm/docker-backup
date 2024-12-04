#!/bin/sh

# 使用 find 查找所有 .backupignore 文件
find . -maxdepth 4 -name "*.backupignore" | while IFS= read -r file; do
    base_dir=$(dirname "$file")
    
    # 读取 .backupignore 文件中的每一行
    while IFS= read -r pattern; do
        # 忽略空行和以 # 开头的注释行
        if [[ -n "$pattern" && ! "$pattern" =~ ^# ]]; then
            # 构建完整的路径并去除开头的 ./
            echo "${base_dir}/${pattern}" | sed 's#^./##g'
        fi
    done < <(grep -v "^#" "$file" | grep -v "^$")
done
