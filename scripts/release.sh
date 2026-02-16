#!/bin/bash

# MotrixMac Sparkle 自动化发布脚本
# 用法: ./scripts/release.sh <版本号>
# 示例: ./scripts/release.sh 1.0.7

VERSION=$1

if [ -z "$VERSION" ]; then
    echo "错误: 请提供版本号 (例如: 1.0.7)"
    exit 1
fi

# 1. 配置路径
PROJECT_DIR="/Users/shawnrain/MotrixMac"
RELEASE_DIR="$PROJECT_DIR/releases"
APPCAST_FILE="$PROJECT_DIR/appcast.xml"
DMG_FILE="$RELEASE_DIR/MotrixMac_$VERSION.dmg"
# 定位签名工具
SIGN_TOOL="/Users/shawnrain/Library/Developer/Xcode/DerivedData/MotrixMac-gqavjquvbfxvifcfxtigizyaxydi/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"

# 检查 DMG 是否存在
if [ ! -f "$DMG_FILE" ]; then
    echo "错误: 找不到 DMG 文件: $DMG_FILE"
    echo "请先将导出的 DMG 放置在 $RELEASE_DIR 文件夹下，并确保文件名为 MotrixMac_$VERSION.dmg"
    exit 1
fi

echo "--- 开始为版本 $VERSION 准备发布 ---"

# 2. 生成基于日期的 Build 号 (YYYYMMDDxx)
echo "正在生成流水号 Build 号..."
TODAY=$(date +"%Y%m%d")
# 从 appcast.xml 中查找今天已有的最高版本号
LAST_BUILD=$(grep -oE "<sparkle:version>${TODAY}[0-9]{2}</sparkle:version>" "$APPCAST_FILE" | grep -oE "${TODAY}[0-9]{2}" | sort -nr | head -n 1)

if [ -z "$LAST_BUILD" ]; then
    SPARKLE_VERSION="${TODAY}00"
else
    # 提取最后两位并加 1
    SUFFIX=${LAST_BUILD:8:2}
    NEXT_SUFFIX=$(printf "%02d" $((10#$SUFFIX + 1)))
    SPARKLE_VERSION="${TODAY}${NEXT_SUFFIX}"
fi

echo "生成的 Build 号 (sparkle:version): $SPARKLE_VERSION"

# 3. 生成签名
echo "正在生成 EdDSA 签名..."
SIGNATURE=$($SIGN_TOOL "$DMG_FILE")
if [ -z "$SIGNATURE" ]; then
    echo "错误: 签名生成失败，请确保 Sparkle 私钥已配置。"
    exit 1
fi
echo "签名: $SIGNATURE"

# 4. 获取文件大小和日期
FILE_SIZE=$(stat -f%z "$DMG_FILE")
PUB_DATE=$(date -R)
DOWNLOAD_URL="https://github.com/ShawnRn/MotrixMac/releases/download/v$VERSION/MotrixMac_$VERSION.dmg"

echo "文件大小: $FILE_SIZE"
echo "发布日期: $PUB_DATE"

# 5. 更新 appcast.xml (简单替换方案，假设只有一个 item)
# 如果需要多版本记录，这里可以改为更复杂的 XML 编辑
echo "正在更新 appcast.xml..."

cat <<EOF > "$APPCAST_FILE"
<?xml version="1.0" encoding="utf-8"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>MotrixMac</title>
        <item>
            <title>$VERSION</title>
            <pubDate>$PUB_DATE</pubDate>
            <sparkle:version>${SPARKLE_VERSION//./}</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>15.6</sparkle:minimumSystemVersion>
            <enclosure url="$DOWNLOAD_URL" type="application/octet-stream" $SIGNATURE/>
        </item>
    </channel>
</rss>
EOF

# 5. 完成提示
echo "--- 准备完成！ ---"
echo "appcast.xml 已更新，请后续手动进行 git 提交与推送。"
echo "请前往 GitHub 创建版本号为 v$VERSION 的 Release 并上传 $DMG_FILE"
