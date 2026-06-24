---
name: skill-maker
description: 创建和升级可复用技能。Use when: (1) 需要新建某类能力的技能, (2) 需要把对话/工作流沉淀为 SKILL.md, (3) 需要优化已有技能结构、触发词与资源组织。
version: 1.2.0
changelog: "v1.2.0: 对齐热门 Skill Maker 框架，新增 5 阶段锻造流程、决策树、自检清单和版本化规范。"
metadata:
  openclaw:
    emoji: "🔨"
    category: "creation"
---

# Skill Maker 🔨

把一次性经验锻造成可复用技能。

## Trigger

['创建skill', '新建技能', '写SKILL.md', '根据对话生成skill', '沉淀工作流', '技能抽取', 'skill-maker', '优化技能']

## 技能锻造流程（5 阶段）

1. **INTERPRET（理解）**：明确技能目标、触发人群、场景边界。  
2. **DESIGN（设计）**：确定目录结构、触发词、复杂度和资源。  
3. **FORGE（锻造）**：生成 `SKILL.md` 与配套 `reference/scripts/assets`。  
4. **TEST（测试）**：验证触发命中、执行可行性、覆盖边界条件。  
5. **POLISH（打磨）**：根据反馈修订并版本化发布。

## 决策树：这次要做什么

- **全新技能**：从阶段 1 开始完整创建。  
- **替换旧技能**：先读旧版，再保留有效部分做增量升级。  
- **克隆改造**：复制同类技能，改名后按新场景重写触发词与流程。

## 阶段 1：INTERPRET（理解）

### 核心问题

- 这个技能到底解决什么问题？  
- 用户会用什么自然语言触发它？  
- 场景属于哪个领域（文档、数据、自动化、协作）？  
- 复杂度是简单/中等/复杂？

### 自检清单

- [ ] 能用一句话描述技能能力  
- [ ] 能列出 3-8 个触发表达  
- [ ] 能说明该技能与已有技能的区别

## 阶段 2：DESIGN（设计）

### 复杂度判定

- **简单**：仅 `SKILL.md`  
- **中等**：`SKILL.md + reference/`  
- **复杂**：`SKILL.md + reference/ + scripts/ (可选 assets/)`

### 目录结构规范

```text
skill-name/
├── SKILL.md
├── reference/
│   └── reference.md
├── scripts/        # 可选
└── assets/         # 可选
```

### 触发词与描述公式

- 描述建议：`[能力说明]。Use when: (1) [场景1], (2) [场景2], (3) [场景3]。`
- 触发词必须覆盖口语化表达，避免只写技术术语。

### 自检清单

- [ ] `name` 为小写英文加连字符  
- [ ] `description` 同时包含能力与场景  
- [ ] 已确定需要哪些资源文件

## 阶段 3：FORGE（锻造）

### 生成规则

1. 根据上下文（手动提供或自动检索）提炼流程。  
2. 产出稳定结构：`Trigger / Workflow / Experience / Examples / Tool Usage / Additional Information`。  
3. 加入必要分支决策（如成功/失败兜底、输入不足补问）。  
4. 去敏处理：移除人名、账号、路径、密钥、内部代号。

### 输出路径（强制）

- 默认写入：`~/.openclaw/skills/<skill-name>/SKILL.md`  
- 禁止写入：`~/.openclaw/workspace/skills/*`  
- 若误写入，必须立即迁移并回报最终路径。

### 自检清单

- [ ] frontmatter 完整（name/description/version/changelog）  
- [ ] 正文包含可执行流程而非空泛原则  
- [ ] 示例能直接复用

## 阶段 4：TEST（测试）

### 触发测试

针对 `description` 和 `Trigger`，验证：

- 用户说「帮我做 X」能否命中？  
- 用户说「我想把 Y 自动化」能否命中？  
- 同义词/口语说法是否能命中？

### 质量门禁

- [ ] 可执行：步骤清晰、前后依赖明确  
- [ ] 可复用：不绑定一次性场景  
- [ ] 可维护：结构稳定、易迭代  
- [ ] 可定位：文件路径与命名规范

## 阶段 5：POLISH（打磨）

### 常见修复

- 命中率低：补充 `Use when` 场景和 Trigger 同义词。  
- 内容过长：将细节迁移到 `reference/reference.md`。  
- 场景覆盖不足：新增 Examples 和 Troubleshooting。  
- 版本混乱：按语义化版本号更新。

### 版本规范

- 修复 bug：`1.0.0 -> 1.0.1`  
- 新增能力（兼容）：`1.0.1 -> 1.1.0`  
- 破坏性变更：`1.1.0 -> 2.0.0`

## Example

### 示例：从对话沉淀 `meeting-notes-maker`

- 输入：最近 7 天会议相关对话 + 主题关键词 + 输出名称  
- 输出：`~/.openclaw/skills/meeting-notes-maker/SKILL.md`  
- 核心步骤：抽取目标 -> 合并上下文 -> 结构化流程 -> 去敏 -> 验收

## Tool Usage

- 文本编辑：Markdown 编辑器  
- 上下文检索：会话日志/项目文件检索  
- 发布分发：可结合 `clawhub publish` 做版本发布

## Additional Information

### 标准格式要点

- frontmatter：`name`、`description` 必填，推荐 `version`、`changelog`  
- 建议章节：`Trigger -> Workflow -> Experience -> Examples -> Tool Usage -> Additional Information`  
- 复杂技能建议配 `reference/reference.md`

### 失败兜底

- 上下文不足时，不强行生成；先输出缺失信息清单（主题、时间范围、来源范围、目标名称）。  
- 不确定路径时，默认采用 `~/.openclaw/skills`。

## See also

- [reference/reference.md](./reference/reference.md) — 自动上下文检索策略、产出模板与质量检查。