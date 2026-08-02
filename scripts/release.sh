#!/usr/bin/env bash

# MotrixMac Sparkle 自动化发布脚本
# 用法: ./scripts/release.sh <版本号>
# 示例: ./scripts/release.sh 1.0.7

set -euo pipefail

VERSION=${1:-}

if [ -z "$VERSION" ]; then
    echo "错误: 请提供版本号 (例如: 1.0.7)"
    exit 1
fi

# 1. 配置路径
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$PROJECT_DIR/releases"
APPCAST_FILE="$PROJECT_DIR/appcast.xml"
DMG_ARM64="$RELEASE_DIR/MotrixMac_${VERSION}_arm64.dmg"
DMG_X86_64="$RELEASE_DIR/MotrixMac_${VERSION}_x86_64.dmg"
# 定位签名工具。允许通过环境变量覆盖，默认从当前 DerivedData 中查找。
SIGN_TOOL="${SIGN_TOOL:-}"
if [ -z "$SIGN_TOOL" ]; then
    SIGN_TOOL=$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update" -type f 2>/dev/null | head -n 1 || true)
fi
if [ -z "$SIGN_TOOL" ] || [ ! -x "$SIGN_TOOL" ]; then
    echo "错误: 找不到 Sparkle sign_update。请先构建项目或设置 SIGN_TOOL=/path/to/sign_update"
    exit 1
fi

# 检查 DMG 是否存在
if [ ! -f "$DMG_ARM64" ] || [ ! -f "$DMG_X86_64" ]; then
    echo "错误: 找不到 DMG 文件。"
    echo "请确保 $DMG_ARM64 和 $DMG_X86_64 都存在于 $RELEASE_DIR 文件夹下"
    exit 1
fi

echo "--- 开始为版本 $VERSION 准备发布 ---"

# 2. 从项目设置中获取当前的 Build 号 (sparkle:version)
echo "正在从 version.env 中提取版本和 Build 号..."
SPARKLE_VERSION=""
if [[ -f "$PROJECT_DIR/version.env" ]]; then
    source "$PROJECT_DIR/version.env"
    SPARKLE_VERSION="${BUILD_NUMBER:-}"
fi

if [ -z "$SPARKLE_VERSION" ]; then
    echo "正在从项目设置中提取流水号 Build 号..."
    XCODE_SETTINGS=$(xcodebuild -showBuildSettings -project "$PROJECT_DIR/MotrixMac.xcodeproj" -scheme "MotrixMac" -configuration "Release" 2>/dev/null)
    SPARKLE_VERSION=$(echo "$XCODE_SETTINGS" | grep " CURRENT_PROJECT_VERSION =" | head -n 1 | awk '{print $3}')
fi

if [ -z "$SPARKLE_VERSION" ]; then
    echo "警告: 无法从项目设置获取 CURRENT_PROJECT_VERSION，回退到日期生成方案..."
    SPARKLE_VERSION=$(date +"%Y%m%d%H")
fi

REMOTE_VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/motrixmac-release-verify.XXXXXX")"
cleanup() {
    rm -rf "$REMOTE_VERIFY_DIR"
}
trap cleanup EXIT

echo "提取到的 Build 号 (sparkle:version): $SPARKLE_VERSION"

# 3. 校验 GitHub 资产并生成签名
PUB_DATE=$(date -R)
URL_ARM64="https://github.com/ShawnRn/MotrixMac/releases/download/v$VERSION/MotrixMac_${VERSION}_arm64.dmg"
URL_X86_64="https://github.com/ShawnRn/MotrixMac/releases/download/v$VERSION/MotrixMac_${VERSION}_x86_64.dmg"

REMOTE_ARM64="$REMOTE_VERIFY_DIR/MotrixMac_${VERSION}_arm64.dmg"
REMOTE_X86_64="$REMOTE_VERIFY_DIR/MotrixMac_${VERSION}_x86_64.dmg"

TARGET_ARM64="$DMG_ARM64"
TARGET_X86_64="$DMG_X86_64"

echo "正在校验 GitHub Release 上实际可下载的资产..."
if curl -L --fail --retry 3 --retry-delay 1 --retry-all-errors -o "$REMOTE_ARM64" "$URL_ARM64" 2>/dev/null; then
    echo "提示: 使用从 GitHub Release 下载的真实 arm64 资产进行签名和计算大小。"
    TARGET_ARM64="$REMOTE_ARM64"
else
    echo "警告: 无法从 GitHub 预下载 arm64 资产，退回使用本地 arm64 资产。"
fi

if curl -L --fail --retry 3 --retry-delay 1 --retry-all-errors -o "$REMOTE_X86_64" "$URL_X86_64" 2>/dev/null; then
    echo "提示: 使用从 GitHub Release 下载的真实 x86_64 资产进行签名和计算大小。"
    TARGET_X86_64="$REMOTE_X86_64"
else
    echo "警告: 无法从 GitHub 预下载 x86_64 资产，退回使用本地 x86_64 资产。"
fi

echo "正在生成 EdDSA 签名..."
sign_update_file() {
    local source_file="$1"
    local raw_output

    if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
        if ! raw_output=$(printf '%s' "$SPARKLE_PRIVATE_KEY" | "$SIGN_TOOL" --ed-key-file - -p "$source_file" 2>&1); then
            echo "错误: 签名生成失败: $raw_output" >&2
            return 1
        fi
    else
        if ! raw_output=$("$SIGN_TOOL" -p "$source_file" 2>&1); then
            echo "错误: 签名生成失败: $raw_output" >&2
            return 1
        fi
    fi

    local signature
    signature=$(printf '%s\n' "$raw_output" | grep -Eo '[A-Za-z0-9+/]{80,}={0,2}' | tail -n 1 || true)

    if [ -z "$signature" ] || printf '%s\n' "$raw_output" | grep -qiE 'ERROR|Signing key not found'; then
        echo "错误: sign_update 未返回有效 EdDSA 签名: $raw_output" >&2
        return 1
    fi

    printf '%s' "$signature"
}

SIG_ARM64=$(sign_update_file "$TARGET_ARM64")
SIG_X86_64=$(sign_update_file "$TARGET_X86_64")

if [ -z "$SIG_ARM64" ] || [ -z "$SIG_X86_64" ]; then
    echo "错误: 双架构签名生成失败，请确保 Sparkle 私钥已配置。"
    exit 1
fi

SIZE_ARM64=$(stat -f%z "$TARGET_ARM64")
SIZE_X86_64=$(stat -f%z "$TARGET_X86_64")

echo "arm64 签名: $SIG_ARM64, 大小: $SIZE_ARM64"
echo "x86_64 签名: $SIG_X86_64, 大小: $SIZE_X86_64"
echo "发布日期: $PUB_DATE"

# 5. 更新 appcast.xml (增量保留历史)
echo "正在更新 appcast.xml..."

ITEM_XML="        <item>
            <title>$VERSION</title>
            <pubDate>$PUB_DATE</pubDate>
            <sparkle:version>${SPARKLE_VERSION//./}</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>15.6</sparkle:minimumSystemVersion>
            <enclosure url=\"$URL_ARM64\" length=\"$SIZE_ARM64\" type=\"application/octet-stream\" sparkle:os=\"macos\" sparkle:nativeArchitecture=\"arm64\" sparkle:edSignature=\"$SIG_ARM64\"/>
            <enclosure url=\"$URL_X86_64\" length=\"$SIZE_X86_64\" type=\"application/octet-stream\" sparkle:os=\"macos\" sparkle:nativeArchitecture=\"x86_64\" sparkle:edSignature=\"$SIG_X86_64\"/>
        </item>"

python3 - "$APPCAST_FILE" "${SPARKLE_VERSION//./}" "$VERSION" "$ITEM_XML" <<'PY'
import re
import sys
from pathlib import Path

appcast_path = Path(sys.argv[1])
sparkle_version = sys.argv[2]
short_version = sys.argv[3]
item_xml = sys.argv[4]

if appcast_path.exists():
    content = appcast_path.read_text(encoding="utf-8")
else:
    content = ""

items = re.findall(r"<item>.*?</item>", content, re.S)
items = [
    item
    for item in items
    if f"<sparkle:version>{sparkle_version}</sparkle:version>" not in item
    and f"<sparkle:shortVersionString>{short_version}</sparkle:shortVersionString>" not in item
]

rebuilt = "\n".join(
    [
        '<?xml version="1.0" encoding="utf-8"?>',
        '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">',
        "    <channel>",
        "        <title>MotrixMac</title>",
        item_xml,
        *["        " + item.replace("\n", "\n        ").strip() for item in items],
        "    </channel>",
        "</rss>",
        "",
    ]
)

appcast_path.write_text(rebuilt, encoding="utf-8")
PY

if command -v xmllint >/dev/null 2>&1; then
    xmllint --noout "$APPCAST_FILE" || {
        echo "错误: appcast.xml XML 校验失败，已中止发布。"
        exit 1
    }
    echo "appcast.xml 校验通过"
fi

# 6. 完成提示
echo "--- 准备完成！ ---"
echo "appcast.xml 已更新。"
echo "请执行:"
echo "gh release create \"v\$VERSION\" \"$DMG_ARM64\" \"$DMG_X86_64\" --title \"MotrixMac \$VERSION\" --notes \"请从 AboutView 同步更新日志\""
