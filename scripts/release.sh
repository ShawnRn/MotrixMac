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
DMG_ARM64="$RELEASE_DIR/MotrixMac_${VERSION}_arm64.dmg"
DMG_X86_64="$RELEASE_DIR/MotrixMac_${VERSION}_x86_64.dmg"
# 定位签名工具
SIGN_TOOL="/Users/shawnrain/Library/Developer/Xcode/DerivedData/MotrixMac-gqavjquvbfxvifcfxtigizyaxydi/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"

# 检查 DMG 是否存在
if [ ! -f "$DMG_ARM64" ] || [ ! -f "$DMG_X86_64" ]; then
    echo "错误: 找不到 DMG 文件。"
    echo "请确保 $DMG_ARM64 和 $DMG_X86_64 都存在于 $RELEASE_DIR 文件夹下"
    exit 1
fi

echo "--- 开始为版本 $VERSION 准备发布 ---"

# 2. 从项目设置中获取当前的 Build 号 (sparkle:version)
echo "正在从项目设置中提取流水号 Build 号..."
XCODE_SETTINGS=$(xcodebuild -showBuildSettings -project "$PROJECT_DIR/MotrixMac.xcodeproj" -scheme "MotrixMac" -configuration "Release" 2>/dev/null)
SPARKLE_VERSION=$(echo "$XCODE_SETTINGS" | grep " CURRENT_PROJECT_VERSION =" | head -n 1 | awk '{print $3}')

if [ -z "$SPARKLE_VERSION" ]; then
    echo "警告: 无法从项目设置获取 CURRENT_PROJECT_VERSION，回退到日期生成方案..."
    SPARKLE_VERSION=$(date +"%Y%m%d%H")
fi

echo "提取到的 Build 号 (sparkle:version): $SPARKLE_VERSION"

# 3. 生成签名与获取大⼩
echo "正在为双架构生成 EdDSA 签名..."
SIG_ARM64=$($SIGN_TOOL "$DMG_ARM64")
SIG_X86_64=$($SIGN_TOOL "$DMG_X86_64")

if [ -z "$SIG_ARM64" ] || [ -z "$SIG_X86_64" ]; then
    echo "错误: 签名生成失败，请确保 Sparkle 私钥已配置。"
    exit 1
fi

SIZE_ARM64=$(stat -f%z "$DMG_ARM64")
SIZE_X86_64=$(stat -f%z "$DMG_X86_64")
PUB_DATE=$(date -R)

URL_ARM64="https://github.com/ShawnRn/MotrixMac/releases/download/v$VERSION/MotrixMac_${VERSION}_arm64.dmg"
URL_X86_64="https://github.com/ShawnRn/MotrixMac/releases/download/v$VERSION/MotrixMac_${VERSION}_x86_64.dmg"

echo "arm64 签名: $SIG_ARM64, 大小: $SIZE_ARM64"
echo "x86_64 签名: $SIG_X86_64, 大小: $SIZE_X86_64"
echo "发布日期: $PUB_DATE"

# 5. 更新 appcast.xml (简单替换方案，单 item 多 enclosure)
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
            <enclosure url="$URL_ARM64" length="$SIZE_ARM64" type="application/octet-stream" sparkle:os="macos" sparkle:nativeArchitecture="arm64" $SIG_ARM64/>
            <enclosure url="$URL_X86_64" length="$SIZE_X86_64" type="application/octet-stream" sparkle:os="macos" sparkle:nativeArchitecture="x86_64" $SIG_X86_64/>
        </item>
    </channel>
</rss>
EOF

# 6. 完成提示
echo "--- 准备完成！ ---"
echo "appcast.xml 已更新。"
echo "请执行:"
echo "gh release create \"v\$VERSION\" \"$DMG_ARM64\" \"$DMG_X86_64\" --title \"MotrixMac \$VERSION\" --notes \"请从 AboutView 同步更新日志\""
