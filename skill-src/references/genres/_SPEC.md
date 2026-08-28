# 题材包接口契约（_SPEC）

> 本文件定义一个题材包（`references/genres/{genre}/`）必须提供的全部文件与钩子。所有钩子均为**必选**。
> 新增题材 = 复制 `_template/` 骨架 → 按本契约逐项填充 → 在 `_registry.md` 登记 → 更新 SKILL.md description 关键词。
> 设计全文见 `docs/genre-plugin-architecture.md`。

---

## 1. 目录结构（必须）

```
{genre}/
├── manifest.md    # 槽位映射与元信息
├── init.md        # 初始化：4轮问题脚本 + 基本信息 + 文件生成清单
├── personas.md    # 写作人格 + 编辑人格（交互式与自动模式共用）
├── craft.md       # 题材工艺指南（风格宪法参数 / 投放物分类学 / 节奏曲线 / 角色设计 / 植入原则 / check_pace）
├── hooks.md       # 写作 / 封存 / 审阅钩子（6 个）
└── templates/     # meta 文件模板
```

## 2. manifest.md（必须）

采用 `key: value` 行格式（脚本与 LLM 均可解析）：

| 字段 | 含义 |
|------|------|
| `genre` / `display` | 题材 id 与显示名（须与 `_registry.md` 一致） |
| `core_doc` | **核心设定文档**文件名：作者持有、Chooser/Reviewer 严格隔离的真相/终局类文档 |
| `signal_doc` | **投放物地图**文件名：投放物的登记与状态跟踪 |
| `signal_term` | 投放物单数术语（如"线索"/"信号"），供核心协议行文 |
| `status_section` | `/status` 输出中题材区块的标题 |
| `sanitize_fields` | 构建 Chooser/Reviewer 上下文时必须从 characters.md 条目剔除的字段名（逗号分隔） |
| `templates.*` | style_guide / characters / core_doc / signal_doc / outline 各 meta 文件对应的模板文件名（相对于本包 `templates/`） |

## 3. init.md（必须）

- **第1-4轮问题脚本**：逐字使用的固定脚本（标题 / 引导语 / A/B/C 选项及预告 / "也可以告诉我你有完全不同的想法"行）。交互停止契约见核心 `init_flow.md`，此处不重复。
- **总结确认的4项标签**（如：世界 / 诡计性质 / 核心张力 / 结局基调）。
- **基本信息收集第3问**的题材版文案（200字以内的核心起点描述）。
- **项目文件生成清单**：每个 meta 文件 × 对应模板（含生成时的题材要求）。
- **outline 章节节奏说明**：全书推进的结构模型与每章计划字段。

## 4. personas.md（必须）

- **「写作人格」**：交互式写作身份 + 自动模式 Writer 子任务身份的唯一来源。
- **「编辑人格」**：交互式责任编辑身份 + 自动模式 Reviewer 子任务身份的唯一来源。
- 模式差异前缀（"正在接受编辑（Director）的指令……"等）由核心 `auto_agents.md` 的 prompt 模板拼接，**题材包不写**。

## 5. craft.md（必须）

- 题材根本工艺原则（公平性 / 克制性等）
- 风格宪法参数：氛围预设或正交轴合成（叙事特征 / 语言禁忌 / 样板句式）——前者按常见选择组合给出预设，后者让各轮选择定义独立轴、任意组合叠加合成（避免预设矩阵覆盖不全）
- **投放物分类学**：类型定义的**唯一来源**（hooks.md 只引用不重定义）
- 节奏曲线与 `/check_pace` 指令逻辑（核心 `writing_loop.md` 的 /check_pace 按此执行）
- 角色设计要点
- `/clue` 植入原则

## 6. hooks.md（必须，6 个钩子）

| 钩子 | 触点 | 用途 |
|------|------|------|
| `write_preflight` | 每次 /write 与 Writer 子任务 | 写作前行为预检问题 |
| `signal_budget` | 同上 | 每章投放预算与原则 |
| `showing_checklist` | 章节写作后记 / `<postscript>` | Showing 自查清单（仅报命中项） |
| `seal_check` | 章节封存第三步 | 投放预算核对 + 结构核对 + 终章断言 |
| `review_dims` | 责任编辑审阅 B 维度 | 读者视角模拟（无真相视角） |
| `full_review` | 全稿两轮审阅 | 第一轮题材专项核查项 + 第二轮输出格式 |

钩子写作要求：

- `seal_check` 必须包含三类核对：①投放预算核对（对照 outline 本章计划，禁止无声遗漏）②结构核对（对照 core_doc 的全书结构，如假设链/情感弧线）③终章断言（下一章进入终局章时的逐条补齐义务）
- `showing_checklist` 含"通用"与"题材专项"两组
- 🔴 **编号不入正文**（强制）：`signal_budget` 必须包含"登记编号与结构术语只出现在 meta 与写作后记、正文与对白一律不得出现"的硬规则；`showing_checklist` 必须含编号/结构术语自查项；`review_dims` 必须含残留检查项
- 🔴 **回写定位**（强制）：`seal_check` 的回写指令必须定位到 outline.md 本章标题小节（`### 第X章`）下的「实际执行」字段，严禁写入其他章节小节
- 钩子中引用的 outline 每章字段名必须与本包 outline 模板的字段名一致

## 7. templates/（必须）

- 至少包含 `manifest.templates` 登记的全部模板
- characters 模板必须包含核心协议依赖的通用字段：`当前已知信息`、`出场记录`、`首次出场章节`、`出场前读者已知信息`、`出场引入方式`、`称谓`、`当前状态`、`说话方式`
- `sanitize_fields` 所列字段必须真实存在于 characters 模板中
