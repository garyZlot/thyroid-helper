#!/bin/bash

# 脚本：移除 Xcode 用户特定文件的 Git 跟踪并更新 .gitignore

# 要移除的文件列表
FILES_TO_REMOVE=(
    "ThyroidHelper.xcodeproj/project.xcworkspace/xcuserdata/gdliumbp.xcuserdatad/UserInterfaceState.xcuserstate"
    "ThyroidHelper.xcodeproj/xcuserdata/gdliumbp.xcuserdatad/xcdebugger/Breakpoints_v2.xcbkptlist"
)

# 检查 .gitignore 文件是否存在，如果不存在则创建
if [ ! -f ".gitignore" ]; then
    echo "创建 .gitignore 文件"
    touch .gitignore
fi

# 添加 Xcode 用户特定文件的忽略规则到 .gitignore
echo "添加忽略规则到 .gitignore"
cat <<EOT >> .gitignore
# Xcode 用户特定文件
*.xcuserstate
*.xcuserdatad/
*.xcuserdata/
*.xcbkptlist
EOT

# 移除文件的 Git 跟踪
for file in "${FILES_TO_REMOVE[@]}"; do
    if [ -f "$file" ]; then
        echo "正在移除文件跟踪: $file"
        git rm --cached "$file"
    else
        echo "文件不存在，跳过: $file"
    fi
done

# 提交更改
echo "提交 .gitignore 和移除的文件"
git add .gitignore
git commit -m "移除 Xcode 用户特定文件跟踪并更新 .gitignore"

echo "操作完成！请检查 git status，并推送更改到远程仓库（如果需要）："
echo "git push origin main"
