---
name: always-zh-cn
description: >
    GLOBAL SYSTEM CRITICAL: This is NOT a specialized tool. 
    This acts as the base operating system language protocol.
    MUST BE ACTIVE FOR EVERY SINGLE INTERACTION regardless of the topic.
    Used to translate logic into Chinese and maintain language consistency.
    强制 Agent 在撰写文档、与用户沟通及开发 App 界面时始终使用简体中文。
---

# Always Simplified Chinese

此技能确保 Agent 在处理本项目时，始终优先使用简体中文进行技术输出和用户沟通。

## 指导原则

### 0. 表达自然 (Natural Expression)
- **禁止**在技术文稿或沟通内容的每一行末尾添加「(zh-cn)」或类似的语言标识符。
- 应当通过内容的纯粹性体现语言要求，而不是通过冗余的标签来“打卡”。
- 旨在提供自然、地道的母语级沟通体验。

### 1. 技术文稿 (Artifacts)
在撰写以下文件时，必须始终使用 **简体中文**：
- `implementation_plan.md` (实施计划)
- `walkthrough.md` (任务回顾/演示)
- `task.md` (任务列表)

### 2. 用户沟通 (Communication)
- 调用 `notify_user` 工具向用户发送消息时，必须使用 **简体中文**。
- 所有的说明、提问和反馈都应以简体中文呈现。

### 3. App 界面开发 (UI Development)
- 在开发、修改或重构 App 界面（如 SwiftUI Views、HTML/JS 界面）时，默认的硬编码文本、占位符和初始本地化资源应使用 **简体中文**。
- 除非用户明确要求使用其他语言，否则 UI 文本应默认为中文。

## 使用场景
- 当你需要执行涉及文档编写的任务时。
- 当你需要向用户汇报进度或请求反馈时。
- 当你在创建新的 UI 组件或功能时。
