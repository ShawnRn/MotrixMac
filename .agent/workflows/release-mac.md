---
description: 自动化提取归档、打 DMG 包、生成 Sparkle 双架构签名并发布至 GitHub Release
---

# `MotrixMac` 自动化打包与发布流程

本工作流将帮助您自动化执行 macOS 应用的新版本构建、创建不同架构(`x86_64` / `arm64`) 的 DMG 安装包，更新 `appcast.xml`（插入两种 CPU 架构各自的下载地址及安全签名），以及提交新包到 GitHub Release。

> [!IMPORTANT]
> **发布顺序至关重要**：必须严格按照 **推代码 → 创建 Release → 推 appcast** 的顺序执行，否则 Release 附带的源代码将是旧的。

## 前置要求
1. **GitHub CLI (`gh`)**：确保您已经登录（`gh auth status`）。
2. **发布环境准备完毕**：请确认代码业务逻辑已提交。

## 执行步骤

### 第一步：修改版本信息
编辑 `version.env` 更新版本号和构建流水号：
```
MARKETING_VERSION=1.2.3
BUILD_NUMBER=2026030300
```
> `Info.plist` 已配置为读取 `$(MARKETING_VERSION)` 和 `$(CURRENT_PROJECT_VERSION)` 变量，无需手动修改 plist。

### 第二步：推送全部源代码
确保所有代码变更已 commit 并 push 到 GitHub：
```bash
git add -A && git commit -m "feat: vX.Y.Z - 更新描述" && git push
```

### 第三步：自动化打包 DMG
执行以下全量编译及自动利用 `create-dmg` 打包命令。这将分别跑两遍归档，产出不同架构的 DMG。

// turbo
```bash
./scripts/build.sh release
```

### 第四步：创建 GitHub Release
调用 GitHub CLI 一次性把两种架构的 DMG 和更新日志发布出去。
*(⚠️ 需要将 `<VERSION>` 替换为实际版本号)*

```bash
VERSION="<VERSION>"
gh release create "v$VERSION" "releases/MotrixMac_${VERSION}_arm64.dmg" "releases/MotrixMac_${VERSION}_x86_64.dmg" \
  --title "MotrixMac $VERSION" \
  --notes "## 更新日志\n\n- ..."
```

### 第五步：生成 appcast 与签名，推送
执行发布脚本生成 Sparkle 签名并更新 `appcast.xml`，然后推送：

```bash
./scripts/release.sh <VERSION>
git add appcast.xml
git commit -m "chore: update appcast.xml for v<VERSION>"
git push
```
执行完毕后，应用端就能够接收到相应 CPU 架构推送的最佳更新包了。
