# 仓库指南 (MotrixMac)

## 项目结构与模块详细说明

### 1. 核心应用 (`MotrixMac/`)
- `MotrixMacApp.swift`: 应用程序入口，负责初始化核心服务（Aria2Service, DownloadManager, EngineProcess）并维护生命周期。
- `Engine/EngineProcess.swift`: 核心执行引擎。负责管理底层 `aria2c` 二进制进程的启动、停止和状态监控。
- `Handlers/`:
    - `URLSchemeHandler.swift`: 处理磁力链接 (magnet:) 和 aria2 协议链接。
    - `NativeMessagingManager.swift`: 提供与浏览器扩展通信的能力。
- `Services/`: **业务逻辑层**
    - `Aria2Service.swift`: 处理 RPC 通信。通过 WebSocket 与 aria2 交互，封装了 JSON-RPC 协议。
    - `DownloadManager.swift`: **核心控制器**。协调任务状态同步、偏好设置持久化、自动删除逻辑等高层业务。
    - `GeoIPService.swift`: 使用 MaxMindDB 提供 IP 地理位置查询，用于显示下载节点来源。
    - `TrackerService.swift`: 自动维护和更新 Tracker 服务器列表，优化下载速度。
- `Models/`:
    - `AppModels.swift`: 定义了 `DownloadTask`、`GlobalStats`、`PreferenceSettings` 等核心数据模型。
- `Utilities/Utils/`:
    - `LocalizationManager.shared`: **唯一**的本地化管理类。所有 UI 文本必须通过此管理器获取。
- `Views/`: **SwiftUI 视图层**
    - `SidebarView.swift`: 导航侧边栏，管理下载状态分类（正在下载、已停止、等待中）。
    - `TaskListView.swift` / `TaskItemView.swift`: 下载列表的核心 UI 实现。
    - `TaskDetailView.swift`: 详细信息页，显示节点信息、Tracker、文件列表等。
    - `AddTaskSheet.swift`: 新建下载任务的浮层界面。
    - `Preferences/`: 偏好设置模块。

### 2. 构建与自动化 (`scripts/`)
- `build.sh`: 主构建脚本。**自动同步版本号**: 脚本会自动从 Xcode 项目文件提取 `Version` 和 `Build` 号，确保命令行构建产物与 Xcode 设置完全一致。
- `run.sh`: 一键构建并启动 App 的基础脚本。
- `compile_and_run.sh`: **推荐的开发辅助脚本**。采用结构化日志输出，包含自动化构建、清理旧进程、启动新包并校验运行状态。
- `release.sh`: 生产打包脚本，处理 Sparkle 更新、签名与 DMG 打包。
- `version.env`: (可选) 版本覆盖文件。如需手动覆盖 Xcode 项目设置，可在此文件定义变量。

## 开发最佳实践

### 本地化 (Localization)
- **禁止硬编码**: 任何 UI 字符串必须添加到 `Resources/Localizable.xcstrings`。
- **调用方式**: 优先在视图中使用 `Text(.localized(for: "key"))` 或在逻辑层使用 `LocalizationManager.shared.localized(for: "key")`。

### 状态管理
- 状态更新应尽量通过 `DownloadManager` 触发，避免直接在 View 中操作 `Aria2Service` 的原始 RPC 调用。
- 偏好设置修改后会自动保存并应用到 `DownloadManager` 维护的运行快照中。

### 构建验证
- 即使是文档或简单的 UI 修改，在提交前也务必运行 `./scripts/build.sh debug`。
- 如果遇到 "Module not found" 错误，请先执行 `rm -rf ~/Library/Developer/Xcode/DerivedData/MotrixMac-*` 清理缓存，然后重试。

### 更新日志 (Changelog) 撰写规范
更新日志应保持简洁、专业且以用户为中心。
- **结构**: 版本号、日期、更改列表。
- **动词开头**: 优先使用“修复”、“新增”、“优化”、“重构”、“微调”等动词。
- **示例**:
    - `修复了下载完成不弹出通知的 bug。`
    - `新增「单列表模式」：合并下载中和已完成任务，专注当前任务。`
    - `重构了删除确认弹窗的数据传递机制，提升稳定性。`
- **语气**: 友好且准确，必要时可使用 emoji（如 😃）。

## 发布流程约定 (Release Workflow)

### 发布顺序（必须遵守 - 铁律）

> [!CAUTION]
> **`appcast.xml` 必须是全流程中最后一个被 `push` 到远程仓库的文件。** 
> 如果在 GitHub Release 创建并上传 DMG 之前就推送了包含新版本信息的 `appcast.xml`，会导致用户在更新时因为找不到文件而报错。

1. **更新代码并推送 (不包含 `appcast.xml`)**：提交业务修改和版本号更新，推送到 GitHub。
2. **创建 GitHub Release**：手动或通过 `gh` CLI 创建 Release，并上传生成的 `MotrixMac_x.x.x.dmg`。
3. **运行发布脚本更新本地 `appcast.xml`**：运行 `./scripts/release.sh`。
4. **单独推送 `appcast.xml` (最后一步)**：只有在确认 Release 已发布且链接可访问后，再 `git commit` 并 `push` 这一单个文件。

### 版本号一致性
- GitHub Release 的 `version/build` 必须与 Xcode 工程一致：
  - `MARKETING_VERSION`
  - `CURRENT_PROJECT_VERSION`
- `version.env` 如存在，需与上述值保持一致，不允许出现版本回退或不一致。

### 更新日志一致性
- GitHub Release 的更新日志必须与 `AboutView` 中当前版本（`changelogs` 首项）的内容完全同步。
- 同步时以代码文件中的最新文案为准，不使用旧草稿或临时文案。

### 发布前确认
- 在执行正式 Release 创建前，需先向用户确认一次，获得用户确认后再执行发布动作。
