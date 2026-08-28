# 题材包插件化架构设计

> 状态：已评审定稿（2026-08-28 brainstorm 会议结论）
> 范围：`skill-src/` 重构——将 mystery / romance 两题材提示词拆分为可独立调试的题材包（genre pack），并为第三题材的接入建立标准接口。
> 本文档是实施的唯一权威依据。

---

## 1. 背景与目标

### 1.1 问题

当前 skill 的题材相关提示词耦合在共享文件中，用户选择任一题材时，另一题材的提示词也会同步进入上下文。具体表现：

| 文件 | 耦合内容 | genre 相关行数 |
|------|---------|--------------|
| `SKILL.md` | 写作/编辑人格双版本内联在 body——skill 激活即全部进入上下文（"选一个题材导入两个提示词"的根源） | 17 |
| `references/writing_loop.md` | /write 读取清单、行为预检、投放原则、Showing 清单、封存核对、责任编辑 B 维度、/status、/clue、全稿审阅第二轮格式，全部 `[mystery]/[romance]` 双分支 | 40 |
| `references/auto_agents.md` | Writer/Reviewer 身份 prompt 双版本（与 SKILL.md 人格是复制粘贴的重复）、上下文注入分支、脱敏规则分支 | 37 |
| `references/init_flow.md` | 两套 4 轮问题全量内联、开场白硬编码题材选项、文件生成对照表 | 30 |
| `scripts/init_project.sh` | if/elif 按 genre 建文件 | 10 |

### 1.2 目标

1. **调试隔离**：调试题材 A 的提示词不影响题材 B。
2. **可扩展**：添加第三题材时只需按接口契约新增一个题材包，核心文件零改动。
3. **上下文效率**：写作时只加载当前题材的提示词（且初始化内容不进入写作上下文）。
4. **消除重复**：SKILL.md 与 auto_agents.md 之间的身份 prompt 复制粘贴关系终止，题材包成为单一事实来源。
5. **向后兼容**：`novels/` 下 20 个存量项目的 meta 文件名（`truth.md`、`romance_clues.md` 等）不变。

### 1.3 非目标

- 不做多 skill 拆分（交互路由、跨文件引用、UX 均受损，已否决）。
- 不做构建时合并（运行时需要同时服务两个题材，已否决；但保留 lint 检查作为衍生手段）。
- 不约束第三方 fork 者的修改自由——强制手段仅面向本仓库内的 Agent 误操作。

---

## 2. 已锁定的设计决策

| 决策点 | 结论 |
|--------|------|
| 题材包粒度 | 按生命周期拆 5 文件（manifest / init / personas / craft / hooks）+ templates/ |
| 核心抽象方式 | 抽象槽位 + manifest 文件名映射（存量项目兼容） |
| 隔离强制 | lint 脚本 + install.sh 前置调用（防 Agent 升级时带回耦合） |
| romance 缺失钩子 | 本次重构中补齐对称钩子（不做可选钩子） |
| 脚手架 | `_SPEC.md` + `_template/` 目录（不做 new_genre.sh） |
| 双模式 | 题材包是交互式与自动写作两种模式的单一事实来源，模式差异留在核心协议 |

---

## 3. 目标目录结构

```
skill-src/
├── SKILL.md                        # 题材中立：路由、锁定协议、指令表。人格双版本删除，改为指向题材包
├── references/
│   ├── init_flow.md                # 骨架：停止契约 + 槽位化流程；开场白题材选项从 _registry.md 生成
│   ├── writing_loop.md             # 所有 [genre] 分支 → 抽象槽位
│   ├── auto_agents.md              # 身份 prompt 从题材包读取；上下文注入/脱敏按 manifest 解析
│   ├── install_notes.md            # 不变（已是 0 耦合）
│   └── genres/
│       ├── _registry.md            # 题材注册表（id / 显示名 / 开场白选项行）
│       ├── _SPEC.md                # 接口契约：槽位定义 + 必选钩子清单（本文档第 4-5 节的运行时版本）
│       ├── _template/              # 新题材脚手架（占位符骨架，复制后按 _SPEC.md 填充）
│       │   ├── manifest.md
│       │   ├── init.md
│       │   ├── personas.md
│       │   ├── craft.md
│       │   ├── hooks.md
│       │   └── templates/
│       ├── mystery/
│       │   ├── manifest.md
│       │   ├── init.md             # 4 轮问题 + 基本信息 + 文件生成清单（自 init_flow.md 迁移）
│       │   ├── personas.md         # 写作/编辑人格（自 SKILL.md 与 auto_agents.md 3.1/5.1 合并去重）
│       │   ├── craft.md            # = 现 references/genres/genre_mystery.md
│       │   ├── hooks.md            # 预检/投放/Showing/封存核对/审阅维度（自 writing_loop.md、auto_agents.md 迁移）
│       │   └── templates/          # style_guide / truth / clues / characters / outline 五个模板
│       └── romance/
│           ├── manifest.md
│           ├── init.md
│           ├── personas.md
│           ├── craft.md            # = 现 references/genres/genre_romance.md
│           ├── hooks.md            # 迁移 + 补齐缺失钩子（见第 7 节）
│           └── templates/          # romance_style_guide / relationship_arc / romance_clues / romance_characters 四个模板
```

`scripts/install.sh` 不变（整体同步）；`scripts/init_project.sh` 的 genre 分支保留（脚本按 manifest 无法运行，保持简单）。

---

## 4. 抽象槽位定义

核心协议中的题材相关文件一律用槽位名，运行时由题材包 manifest 解析为实际文件名。

| 槽位名 | 语义 | mystery 映射 | romance 映射 |
|--------|------|-------------|-------------|
| `{core_doc}` | 核心设定文档：Writer 持有、Chooser/Reviewer 严格隔离的真相类文档 | `meta/truth.md` | `meta/relationship_arc.md` |
| `{signal_doc}` | 投放物地图：线索/信号的登记与状态跟踪 | `meta/clues.md` | `meta/romance_clues.md` |

manifest 同时声明：

- **模板映射**：style_guide / characters / core_doc / signal_doc / outline 各自对应的模板文件名。
- **状态区标签**：/status 输出中题材区块的标题（"线索地图" vs "情感信号地图"）。
- **脱敏字段清单**（`sanitize_fields`）：Reviewer 上下文中必须从 characters.md 条目剔除的字段名。
  - mystery：`隐瞒的事` 及任何指向真相的字段
  - romance：`情感起点`、`情感盲区` 等与 relationship_arc.md 重复的终局性字段
- **投放物单数/复数术语**：用于核心协议行文（"线索" vs "信号"），核心模板中以 `{signal_term}` 形式引用。

### manifest.md 格式（示意）

```yaml
genre: mystery
display: 推理悬疑
core_doc: truth.md
signal_doc: clues.md
signal_term: 线索
status_section: 线索地图
sanitize_fields: [隐瞒的事]
templates:
  style_guide: style_guide_template.md
  characters: characters_template.md
  core_doc: truth_template.md
  signal_doc: clues_template.md
  outline: outline_template.md
```

---

## 5. 题材包接口契约（_SPEC.md 的内容）

每个题材包必须提供以下 5 文件 + templates/，所有钩子均为**必选**（无可选钩子——romance 的缺口在本次重构中补齐，见第 7 节）。

### 5.1 manifest.md
槽位→文件名映射、显示名、状态区标签、脱敏字段清单、模板映射。

### 5.2 init.md
- 4 轮共创问题脚本（逐字使用的固定脚本：标题、引导语、A/B/C 选项及预告）
- 基本信息收集第 3 问的题材版文案（mystery：案件是什么；romance：两人的起点）
- 项目文件生成清单（哪些 meta 文件、各读哪个模板）
- outline 章节节奏说明（mystery：假设周期；romance：12 章情感弧线节点）

生命周期：仅初始化时读取，写作/自动模式下不进入上下文。

### 5.3 personas.md
- **写作人格**：交互式模式的写作者身份 + 自动模式 Writer 子任务身份的唯一来源。
- **编辑人格**：交互式模式责任编辑身份 + 自动模式 Reviewer 子任务身份的唯一来源。
- 自动版身份的差异前缀（"正在接受编辑（Director）的指令……"）由 auto_agents.md 的 prompt 模板拼接，**不在题材包中重复**。

### 5.4 craft.md
题材工艺指南（现有 `genre_*.md` 内容原样迁移）：
- 根本工艺与公平性/克制性原则
- 风格宪法参数（氛围预设或正交轴合成：叙事特征/语言禁忌/样板句式）
- 投放物分类学（mystery：Hard Clue / Red Herring / Atmospheric；romance：ES / DS / AS）
- 节奏曲线与 `/check_pace` 指令逻辑
- 角色设计要点

### 5.5 hooks.md
| 钩子 | 用途 | 交互式使用点 | 自动模式使用点 |
|------|------|-------------|---------------|
| `write_preflight` | 写作前行为预检问题 | writing_loop「写作前行为预检」 | auto_agents 3.3 写作规范注入 |
| `signal_budget` | 每章投放预算与原则 | writing_loop「线索/信号投放原则」 | auto_agents 3.3 写作规范注入 |
| `showing_checklist` | 写作后记 Showing 自查清单（仅报命中项） | writing_loop 后记格式 | Writer `<postscript>` 格式 |
| `seal_check` | 封存第三步核对逻辑 | writing_loop 章节封存协议 | Writer 第 3 段封存指令 + Director 补写核验 |
| `review_dims` | 责任编辑 B 维度（读者视角模拟） | writing_loop 责任编辑机制 | auto_agents 5.3 审阅维度 |
| `full_review` | 全稿审阅：第一轮专项核查项 + 第二轮输出格式 | writing_loop 两轮全稿审阅协议 | /finish 后自动审阅 |

### 5.6 templates/
初始化时生成 meta 文件的模板，路径在 manifest 中登记。

---

## 6. 核心文件改造点映射

### 6.1 SKILL.md
- 删除「你的写作人格」「你的编辑人格」双版本节 → 改为一句：锁定题材后 🔴 完整读取 `references/genres/{genre}/personas.md`。
- 「初始化流程（摘要）」中的两题材 4 轮描述 → 中立化（"4 轮题材共创问题，脚本见 `references/genres/{genre}/init.md`"）。
- 项目文件结构图 → 中立化（`{core_doc}` / `{signal_doc}` 槽位展示，实际文件名以题材包 manifest 为准）。
- frontmatter `description` 保留题材关键词（路由触发需要），关键词清单与 `_registry.md` 同步维护。

### 6.2 init_flow.md
- 开场白 ❶ 的题材选项 → 从 `_registry.md` 生成（每个题材一行选项 + 预告）。
- 两套 4 轮问题 → 全部移入各题材 `init.md`；核心只保留流程骨架与停止契约。
- 文件生成对照表 → 移入 `init.md`；核心步骤 2 改为"按 `genres/{genre}/init.md` 的文件生成清单执行"。

### 6.3 writing_loop.md
| 现分支位置 | 改造 |
|-----------|------|
| /write 步骤 0 之 genre 分支、步骤 2/4 的 truth/clues 读取 | → 读 `{core_doc}` / `{signal_doc}`（按 manifest 解析） |
| 写作前行为预检（双版本） | → `hooks.write_preflight` |
| 线索/信号投放原则（双版本） | → `hooks.signal_budget` |
| 写作后记 Showing 清单（双版本） | → `hooks.showing_checklist` |
| 封存第三步：线索预算核对/假设链核对/揭示章断言（仅 mystery） | → `hooks.seal_check`（两题材均有） |
| 责任编辑 B 维度（双版本） | → `hooks.review_dims` |
| /status 题材区块 | → manifest 状态区标签 + `{signal_doc}` |
| /clue 类型判断与植入原则 | → craft.md 分类学 + hooks |
| /check_pace | → craft.md（现状已如此，不变） |
| 全稿审阅第一轮 E 项 / 第二轮双格式 | → `hooks.full_review` |

### 6.4 auto_agents.md
- 3.1 Writer 身份 / 5.1 Reviewer 身份（双版本）→ 从 `genres/{genre}/personas.md` 读取，模板中做自动版前缀拼接。
- 3.2 上下文注入第 4/6 项 → `{core_doc}` / `{signal_doc}`。
- 3.3 写作规范中的预检与投放分支 → `hooks.write_preflight` / `hooks.signal_budget`。
- 3.5 / 5.2 postscript Showing 清单 → `hooks.showing_checklist`。
- 5.2 脱敏字段 → `manifest.sanitize_fields`。
- 6.5 提取规则中 clues.md / romance_clues.md → `{signal_doc}` 统一表述。
- Chooser（4.1）本就题材中立，不动。

---

## 7. romance 补齐钩子（本次新增设计）

对齐 mystery 的 `seal_check` 与全稿第一轮 E 项，为 romance 设计对称物：

### 7.1 seal_check（爱情版）
- **信号预算核对**（对照 outline.md 本章计划）：计划投放的 ES/DS 是否已投？未投 → 就地补投，或显式修改 outline 计划并在「章节计划变更记录」写明原因。禁止无声遗漏（与 mystery 同构）。
- **弧线核对**：对照 relationship_arc.md 本章情感状态目标——本章结束时两人距离是否符合弧线预期（靠近/后退/停滞）？偏离 → 就地调整或在 outline 回写偏差及原因。
- **结局章断言**：若下一章进入结局章，逐条断言关键 ES 均已投放、最后的 DS 已被化解或明确保留（依据结局基调），缺口在本章内补齐。

### 7.2 全稿审阅第一轮 E 项（爱情版）
- 关键情感信号（ES）回看是否成立：每次靠近是否有前置行为/细节积累，还是"作者需要所以爱上了"？
- DS 的化解是否付出代价：角色是否改变了某个认知或放下了某个保护壳，还是障碍被情节便利消解？
- 关系基准线是否在第 1-2 章建立：读者是否先看到"正常"，才可能感知"不正常"？
- 双视角项目：两个视角的信息差是否被利用（而非仅是轮换叙述）？

> 实施时此节内容细化后写入 `genres/romance/hooks.md`，此处为设计基线。

---

## 8. 防 Agent 误操作回归耦合

威胁模型：将来由 Agent（如 opencode 本身）升级 skill 时无意把题材词写回共享文件。

- **`scripts/lint_coupling.sh`**：检查以下范围内出现题材词（`mystery`、`romance`、`推理`、`爱情`、`言情`、`悬疑`）即报错退出非零：
  - `skill-src/SKILL.md` 的正文（frontmatter `description` 行白名单——路由触发需要题材关键词）
  - `skill-src/references/` 根层文件（init_flow / writing_loop / auto_agents / install_notes）
  - `skill-src/scripts/*.sh`（install.sh 已是 0 耦合；init_project.sh 的 genre 字面量白名单或改为从目录名推导）
  - 白名单：`references/genres/` 全目录（含 `_registry.md`、`_SPEC.md`、`_template/`）
- **install.sh 前置调用 lint**：失败即拒绝同步到三个平台目录——Agent 改完跑安装即被拦截。
- **AGENTS.md 追加一条**：修改 `skill-src/` 后必须运行 `bash skill-src/scripts/lint_coupling.sh` 通过后方可安装。

---

## 9. 实施顺序

1. 建 `references/genres/` 骨架：`_SPEC.md`、`_registry.md`、`_template/`。
2. 抽取 mystery 题材包（纯迁移，不改写内容）。
3. 抽取 romance 题材包 + 按第 7 节补齐钩子（新增内容需单独审阅）。
4. 核心四文件（SKILL / init_flow / writing_loop / auto_agents）槽位化改写。
5. `lint_coupling.sh` + install.sh 集成 + AGENTS.md 更新。
6. `install.sh` 同步三平台目录，并用存量项目做冒烟验证（/write 一段、/check_pace、/auto-chapter 一章）。

步骤 2/3 与步骤 4 无强依赖，可并行推进；步骤 5 依赖 4 完成。

---

## 10. 风险与对策

| 风险 | 对策 |
|------|------|
| 指令链变长（writing_loop → genres/{genre}/hooks.md），LLM 漏读风险上升 | 沿用现有 🔴 强制完整读取标注风格；题材包路径在多个核心文件重复指认 |
| manifest 解析失败（LLM 未读 manifest 就执行） | 核心协议将"读取 manifest"设为锁定题材后的第一步 🔴 指令；/write 步骤 0 保留"读 project_info.md 确认 genre"作双保险 |
| 题材包文件间内容漂移（hooks 引用 craft 的分类学术语不一致） | _SPEC.md 规定术语单一来源：分类学只在 craft.md 定义，hooks 引用之 |
| 存量项目 genre 字段值与新注册表不匹配 | _registry.md 的 id 沿用现值（`mystery` / `romance`），不引入新命名 |
