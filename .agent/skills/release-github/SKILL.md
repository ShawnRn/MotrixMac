---
name: release-github
description: ipaDown 全平台 Release 发布流程（macOS 双架构 + iOS + Sparkle + GitHub Release）。Use when: (1) 需要发布新版本到 GitHub, (2) 需要打包 macOS/iOS 并生成 appcast.xml, (3) 准备 Release 更新日志。
version: 1.1.0
changelog: "v1.1.0: 新增 appcast.xml 校验环节，防止 sign_update 重复 length 属性导致 Sparkle 解析失败。"
---

# Release GitHub 🚀

ipaDown 完整发布流程：更新日志 → 版本号 → 全平台构建 → Sparkle 签名 → GitHub Release。

## Trigger

['发布', 'release', '打包', '上线', '发新版', 'release-github', '发布到github', '准备发布']

## 前置条件

- 所有代码变更已经过验证（build + 手动测试）
- Git 工作目录已清楚哪些变更需要包含
- `gh` CLI 已安装并登录（`gh auth status`）
- `create-dmg` 已安装（`brew install create-dmg`），否则降级为 zip

## 完整 Release 流程

### 阶段 1：更新日志（需用户审核）

1. **查看自上次 release 以来的所有变更**：
   ```bash
   git tag --sort=-creatordate | head -5     # 确认最近的 tag
   git log v<上一版本>..HEAD --oneline       # 列出所有新提交
   ```

2. **编写更新日志草稿**：
   - 创建 artifact `changelog_draft.md` 供用户审核
   - 将提交按类别整理：新功能、修复、优化、重构
   - 使用简洁的中文描述，面向终端用户
   - 每条以动词开头（修复、新增、优化、重构）

3. **提交审核**：通过 `notify_user` 发送草稿供用户确认
   - ⚠️ **必须等用户确认后才能继续**

### 阶段 2：更新版本号

> [!IMPORTANT]
> 版本号涉及三处，必须全部同步更新。

4. **确定新版本号**（语义化版本，如 `1.3` → `1.4`）

5. **更新 Xcode 项目 `MARKETING_VERSION`**：
   ```bash
   # 查看当前版本号
   grep 'MARKETING_VERSION' ipaDown-for-Apple.xcodeproj/project.pbxproj
   # 替换为新版本号
   sed -i '' 's/MARKETING_VERSION = <旧版本>;/MARKETING_VERSION = <新版本>;/g' ipaDown-for-Apple.xcodeproj/project.pbxproj
   ```

6. **更新 Xcode 项目 `CURRENT_PROJECT_VERSION`（Build 号）**：
   - 格式为日期序号：`YYYYMMDD01`（如 `2026032201`）
   - **必须大于或等于 `appcast.xml` 中现有的 `<sparkle:version>` 值**，否则 Sparkle 不会触发更新
   ```bash
   # 查看当前 Build 号
   grep 'CURRENT_PROJECT_VERSION' ipaDown-for-Apple.xcodeproj/project.pbxproj
   # 查看 appcast.xml 中的 Build 号
   grep '<sparkle:version>' appcast.xml
   # 替换
   sed -i '' 's/CURRENT_PROJECT_VERSION = <旧Build号>;/CURRENT_PROJECT_VERSION = <新Build号>;/g' ipaDown-for-Apple.xcodeproj/project.pbxproj
   ```

7. **更新 `ChangelogView.swift`**：
   - 在 `changelogs` 数组的**最前面**插入新的 `ChangelogItem`
   - 格式参考：
   ```swift
   ChangelogItem(
       version: "<版本号>",
       date: "<YYYY-MM-DD>",
       changes: [
           "新增/修复/优化描述...",
       ]
   ),
   ```

### 阶段 3：全平台构建

8. **执行全平台构建脚本**：
   ```bash
   bash scripts/build_all.sh
   ```
   该脚本会自动完成以下步骤：
   - 预检 Build 号（防止版本回退）
   - 编译 macOS arm64 + x86_64 双架构 → 分别生成 DMG
   - 编译 iOS → 生成 IPA（Payload 格式，适配巨魔/侧载）
   - 使用 Sparkle `sign_update` 工具生成 EdDSA 签名
   - 自动生成/覆盖 `appcast.xml`

   **⏱ 预计耗时 5–10 分钟（三次 clean archive）**

9. **验证构建产物**：
   ```bash
   ls -la build_output/
   # 应包含:
   #   ipaDown_<版本>_arm64.dmg
   #   ipaDown_<版本>_x86_64.dmg
   #   ipaDown_<版本>_iOS.ipa
   ```

10. **校验 appcast.xml**（⚠️ 关键步骤，跳过可能导致 Sparkle 更新失败）：
    ```bash
    # 1) XML 语法校验 — 确保没有重复属性或格式错误
    xmllint --noout appcast.xml && echo "XML valid ✅" || echo "XML invalid ❌"
    
    # 2) 内容校验 — 人工确认关键字段
    cat appcast.xml
    # 检查:
    #   <sparkle:version> 为新 Build 号
    #   <sparkle:shortVersionString> 为新版本号
    #   两个 <enclosure> 分别指向 arm64 和 x86_64 DMG
    #   edSignature 不是占位符
    #   每个 <enclosure> 中 length 属性只出现一次
    ```
    > ⚠️ 如果 `xmllint` 报错，最常见原因是 `sign_update` 输出已包含 `length`，
    > 而模板又额外添加了一次，导致属性重复。此问题已在 `build_all.sh` 中修复，
    > 但仍建议每次发布都执行此校验。

### 阶段 4：Git 提交与推送

11. **提交所有变更**：
    ```bash
    git add -A
    git commit -m "chore: release v<版本号>"
    git push
    ```

### 阶段 5：GitHub Release

12. **创建 GitHub Release 并上传产物**：
    ```bash
    VERSION="<版本号>"
    gh release create "v$VERSION" \
      "build_output/ipaDown_${VERSION}_arm64.dmg" \
      "build_output/ipaDown_${VERSION}_x86_64.dmg" \
      "build_output/ipaDown_${VERSION}_iOS.ipa" \
      --title "ipaDown $VERSION" \
      --notes "<更新日志正文>"
    ```

13. **推送 appcast.xml 使 Sparkle 自动更新生效**：
    ```bash
    git add appcast.xml
    git commit -m "chore: release v${VERSION} update appcast"
    git push
    ```
    > `appcast.xml` 在 `build_all.sh` 运行后已经更新过了，但 GitHub Release 创建后 URL 才真正生效，所以这一步可能不需要再修改 appcast.xml 本身，只需确保它已被推送到 main 分支。

### 阶段 6：验证发布

14. **验证 GitHub Release 页面**：
    ```bash
    gh release view "v$VERSION"
    ```

15. **验证 Sparkle 更新源可访问**：
    ```bash
    curl -sI "https://raw.githubusercontent.com/ShawnRn/ipaDown-for-Mac/main/appcast.xml" | head -5
    ```

16. **通知用户发布完成**。

## 关键细节（易出错点）

### Sparkle 自动更新

| 字段 | 来源 | 说明 |
|-----|------|------|
| `sparkle:version` | `CURRENT_PROJECT_VERSION` | Build 号，必须单调递增 |
| `sparkle:shortVersionString` | `MARKETING_VERSION` | 用户可见版本号 |
| `SUFeedURL` | `Info.plist` | 指向 `appcast.xml` 的 raw URL |
| `SUPublicEDKey` | `Info.plist` | EdDSA 公钥，与私钥配对 |
| EdDSA 签名 | `sign_update` 工具 | 从 DerivedData 中搜索 |

- `sign_update` 工具路径：`find ~/Library/Developer/Xcode/DerivedData -name "sign_update" -type f -perm +111 | head -n 1`
- 如果找不到 `sign_update`，说明 Sparkle 从未编译过，需要先 `xcodebuild build` 一次
- **EdDSA 私钥**存储在本地 Keychain 中，**严禁提交到 Git**

> [!CAUTION]
> **`sign_update` 的输出格式**：`sparkle:edSignature="..." length="..."`。
> 它已经包含了 `length` 属性！`build_all.sh` 模板中**不能再手动添加** `length`，
> 否则会产生重复属性导致 XML 无效，Sparkle 将报「解析更新信息时出现错误」。

### 双架构 DMG

- macOS 分别为 **arm64**（Apple Silicon）和 **x86_64**（Intel）生成独立 DMG
- `appcast.xml` 中通过 `sparkle:nativeArchitecture` 属性区分
- Sparkle 客户端会根据当前 Mac 架构自动选择对应的 DMG 下载

### GitHub Release 下载 URL 格式

```
https://github.com/ShawnRn/ipaDown-for-Mac/releases/download/v<VERSION>/ipaDown_<VERSION>_arm64.dmg
https://github.com/ShawnRn/ipaDown-for-Mac/releases/download/v<VERSION>/ipaDown_<VERSION>_x86_64.dmg
https://github.com/ShawnRn/ipaDown-for-Mac/releases/download/v<VERSION>/ipaDown_<VERSION>_iOS.ipa
```

> [!WARNING]
> `appcast.xml` 中的 URL **必须与 GitHub Release 上传的文件名完全一致**，否则 Sparkle 更新会 404。

### 版本号命名规范

- `MARKETING_VERSION`：语义化版本 `X.Y`（如 `1.4`）
- `CURRENT_PROJECT_VERSION`：日期序号 `YYYYMMDD01`（如 `2026032201`），同一天多次发布递增末尾数字
- Git Tag：`v` 前缀 + 版本号（如 `v1.4`）

## Troubleshooting

| 问题 | 原因 | 解决方案 |
|-----|------|---------|
| `xcpretty: command not found` | 未安装 xcpretty | 无需处理，脚本会自动降级为原始输出 |
| `sign_update` 不存在 | Sparkle 未编译过 | 先运行一次 `xcodebuild build` |
| Build 号检查失败 | Build 号小于 appcast.xml 中的值 | 增大 `CURRENT_PROJECT_VERSION` |
| DMG 未生成 | `create-dmg` 未安装 | `brew install create-dmg` |
| GitHub Release 上传失败 | `gh` 未登录 | `gh auth login` |
| Sparkle 更新 404 | URL 与文件名不匹配 | 检查 `appcast.xml` 中的 URL 和实际上传的文件名 |
| Sparkle「解析更新信息时出现错误」 | `appcast.xml` 中 XML 属性重复（如 `length` 出现两次） | 运行 `xmllint --noout appcast.xml` 检查，手动修复重复属性 |
