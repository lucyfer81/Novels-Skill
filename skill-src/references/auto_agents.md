# 自动写作模式：角色定义与通信协议

> 本文件定义 `/auto-write` 和 `/auto-chapter` 模式中使用的子任务角色。
> Director（执行 Skill 的主 Agent 自身）通过平台提供的子任务机制调用 **Writer**（整章正文生成）、**Reviewer**（责任编辑审阅）、**Solver**（按需：挑战读者测试）；**Chooser**（模拟读者选路）为显式可选策略，默认关闭。

## 模式划分

- `/write`：交互式单段推进、真实用户选择与暂停行为（见 writing_loop.md，本文件不改变其语义）。
- `/auto-write` / `/auto-chapter`：**整章生成**——每章一次 Writer 主任务 + 一次 Reviewer 主任务，不生成三选项、不调用 Chooser（模拟读者选路为可选策略，见第四节）。
- 整章输出若遭平台截断，从已确认的章节文件版本继续续写（见 3.4 续写恢复任务），不自动重写全章，不依赖字数猜测完成状态。

## 〇、题材包解析（Director 的先决步骤）

本文件使用抽象槽位，实际文件名由题材包声明：

- `{core_doc}` = 核心设定文档（作者持有的终局类文档）
- `{signal_doc}` = 投放物地图

启动自动写作时（writing_loop.md「前置检查」第2步），Director 必须 🔴 读取：
1. `references/genres/{genre}/manifest.md` —— 解析槽位、sanitize_fields、status_section 等
2. `references/genres/{genre}/personas.md` —— Writer / Reviewer 的身份来源
3. `references/genres/{genre}/hooks.md` —— 注入 Writer prompt 的写作规范与 Reviewer 审阅维度

🔴 只加载当前题材的题材包，严禁将其他题材的任何内容注入子任务上下文。

**注入纪律（防止题材包登记语言污染正文）**：构建 Writer prompt 时，题材包 hooks.md **只注入「write_preflight」与「signal_budget」两节全文**；「seal_check」仅随整章生成任务指令注入；「review_dims」「full_review」只用于 Reviewer 与全稿审阅。🔴 严禁把 hooks.md 整个文件或题材包其他文件整体注入写作类子任务——封存/审阅用的编号与核对语言一旦进入写作上下文，会被模仿进正文。

**上下文传输纪律（防主会话与子任务上下文膨胀）**：大文件内容一律不以"Director 全文内联"方式进入子任务 prompt。Director 只内联**小体量且必须由 Director 保证**的内容（身份 prompt、任务指令、写作规范、前情摘要、名单与编号、读取指引）；完整文件内容一律以「路径 + 读取指引」交付子任务用 read 工具自读（平台子任务均具备文件读取能力，见第七节）。Writer 的冷启动注入因此从"全文搬运"降为"{core_doc} 骨架节 + 本章依据分节 + {signal_doc} 总索引 + 指定编号全条目"（分层记忆规则见 3.2 / 6.5）。

---

## 一、角色概览与核心约束

| 角色 | 定位 | 上下文权限 | 文件写入权 | 输出 |
|------|------|-----------|-----------|------|
| **Director**（你自己） | 全局编排、脚本化核验、审阅过滤、版本化提交、方向调整 | 锁定目标 `{project_dir}`，持有全部 meta；**不接收正文全文** | `meta/auto_state.json`、`meta/directives.md`；提交步骤（6.7）应用 delta 写权威 meta；`commits.json` / `usage.log` 仅经 `scripts/chapter_tools.sh` 写入 | 进度汇报、修复决策 |
| **Writer**（子任务） | 整章正文生成、chapter_delta 产出、精准修复 | 绑定 `{project_dir}`，完整 meta（含 {core_doc}，按分层记忆规则自读） | 章节期间独占 `drafts/*` 与 `meta/pending/chXX.delta.md`；🔴 **不写任何权威 meta**（session_log / characters / {signal_doc} / continuity / outline 一律由提交步骤应用，见 3.6 与 6.7） | XML 格式（见第二节） |
| **Chooser**（子任务，可选策略） | 模拟读者做章级走向选择（默认关闭，见第四节） | ⚠️ **仅** 读者可见信息 + 自己的选择轨迹 | 无（纯输出，不写任何文件） | `<choice>` + `<reason>` |
| **Reviewer**（子任务） | 每章责任编辑审阅 | ⚠️ **无** {core_doc}；角色条目已剔除 sanitize_fields 所列字段；正文以路径自读 | 无（纯输出，不写任何文件） | `<review_report>` |
| **Solver**（子任务，命中触发条件即强制） | 挑战读者测试：实测无终局视角的读者当前推论 | ⚠️ 与 Chooser 同级隔离（读者可见语料摘要版，见 4.4） | 无（纯输出，不写任何文件） | `<solver_report>` |

⚠️ **核心约束**：

1. **真实性隔离（三重）**：Chooser、Reviewer 与 Solver 都不得接触 `{core_doc}`（核心设定文档）的任何内容。Chooser 靠 Director 不传入保证；Reviewer 靠 Director 构建**脱敏上下文**保证（含 characters.md 中 manifest「sanitize_fields」所列终局性字段的剔除，见 5.2）；Solver 靠 Director 只注入读者可见语料摘要保证（见 4.4）。这样"读者视角选择""读者视角审阅"与"读者视角实测推论"都是真实的无真相视角，而不是 Writer 持真相自我模拟。
2. **选项公平性（仅模拟读者策略启用时）**：Writer 持有核心设定生成分选择时，必须遵守选项公平性原则（见 4.0），Director 负责核验。
3. **多项目隔离**：Director、Writer、Chooser、Reviewer **仅限在锁定的目标 `{project_dir}`（即 `novels/{项目名}`）** 目录下读写。严禁跨目录访问或修改其他小说。
4. **meta 写权划分（防双写冲突；delta 模式）**：
   - Writer 仅写 `drafts/*` 与 `meta/pending/chXX.delta.md`；🔴 禁止写 meta/ 下任何权威文件
   - Director 写 `meta/auto_state.json` 与 `meta/directives.md`；权威 meta（session_log / characters / {signal_doc} / continuity / outline）只在**提交步骤（6.7）应用 delta 时**由 Director 亲自写入（小操作，不派子任务）；提交后的 Solver 判定留痕等追加亦由 Director 执行
   - `commits.json` 与 `usage.log` 只经 `scripts/chapter_tools.sh` 写入（commit / usage 子命令），Director 不手工编辑
   - 交互模式（/write）不受影响：主 Agent 自己执行封存协议（见 writing_loop.md），无子任务写权问题

---

## 二、公共输出协议（XML 标签）

子任务输出中所有**机器可解析**的部分一律用 XML 标签包裹（标签内仍是普通文本/markdown）。Director 依靠标签解析，不依赖 markdown 标题猜测。

| 标签 | 使用者 | 内容 |
|------|--------|------|
| `<chapter_report>` | Writer | 整章生成结果短报告（路径 / base_revision / delta 状态 / 字数自报 / 读者摘要 / 作者备注 / 可选 next_choices；**不含正文全文与 delta 全文**，见 3.5） |
| `<chapter_delta>` | Writer | 章节状态变化增量——**只写入文件** `meta/pending/chXX.delta.md`，不在对话输出（结构与校验契约见 3.6；审阅与修复通过后由提交步骤应用） |
| `<fix_report>` | Writer | 修复任务执行结果（含 delta 是否已重新生成） |
| `<choice>` / `<reason>` | Chooser | 走向选择 / 理由（仅模拟读者策略启用时） |
| `<review_report>` | Reviewer | 编辑审阅报告（A-D 维度 + 定级清单） |
| `<solver_report>` | Solver | 挑战读者测试报告（领先推论 / 支撑投放物 / 信心度 / 困惑点） |

**解析失败处理**：若关键标签缺失或为空，Director 不重跑整个子任务，而是派发一个**轻量重试**子任务："请仅重新输出 `<标签>` 部分，不要重写正文"。同一子任务轻量重试最多 1 次，仍失败按第六节异常降级处理。

---

## 三、Writer 角色

### 3.1 身份 prompt（由题材包提供）

Writer 的身份 prompt 按以下模板拼接（人格本体是题材包单一事实来源，本文件不定义题材人格）：

```
你是一位深谙{题材}小说工艺的作家，正在接受编辑（Director）的指令完成整章正文生成。

{references/genres/{genre}/personas.md 中「写作人格」一节的全文，原样内联}
```

### 3.2 接收的上下文（每章一次资料准备）

Director 每章调用一次 Writer 子任务，prompt 由**内联部分**（体积小、必须由 Director 保证）与**自读清单**（路径 + 读取指引，Writer 用 read 工具自行读取，禁止跳过）构成。

**内联部分**：

```
1. Writer 身份 prompt（3.1 节模板 + 题材包 personas.md「写作人格」全文）

2. 项目信息：{project_dir}、genre、language

3. 本章出场角色名单与首次出场名单（Director 用 grep 从 characters.md 条目标题与
   「出场记录」「首次出场章节」字段提取，不全文读）

4. 本章应投/将触碰的投放物编号（从 outline.md 本章计划节点提取：应投、结构操作引用的证据编号）

5. {core_doc} 读取指引：骨架节标题（manifest `core_skeleton` 字段）+ 本章依据分节
   （outline 本章「核心依据」字段）；任一缺省 → 指引为"全文读取"；揭示/终局章一律"全文读取"

6. 前情摘要：最近 2 章 session_log 条目（核心事件、角色变化、故事内时间/地点、信息增量、
   下章切入点——每章提交后提取一次，整章任务一次注入，不重复读文件。
   ⚠️ Writer 持有核心设定，注入无需脱敏——这是子任务衔接前情、避免跨章矛盾的主通道）

7. 上帝指令（若 meta/directives.md 中存在未完成且适用于本章的指令）

8. 上章读者选择（仅模拟读者策略启用时：Chooser 对本章开场走向的选择及理由，见第四节）

9. 写作规范（3.3 节，含题材包 hooks.md 两节全文）+ 输出协议（第二节 Writer 部分）+ 任务指令（3.4 节）
```

**自读清单**（写入 prompt，Writer 依次读取）：

```
1. {project_dir}/meta/{core_doc} —— 按读取指引（骨架节 + 本章依据分节；指引为"全文读取"时读全文）

2. {project_dir}/meta/characters.md —— 仅本章出场角色条目；首次出场角色只读并遵守：
   出场前读者已知信息 / 出场引入方式 / 身份（职业/社会角色），完整档案（含 manifest
   「sanitize_fields」所列题材终局性字段）在该角色二次出场后解锁；
   首次/二次出场判定一律以角色条目中的「出场记录」字段为准

3. {project_dir}/meta/{signal_doc} —— 「总索引」节全量 + 内联第4项所列编号的全条目；
   写作中若触及索引内其他活跃投放物，必须先 read 该条目全文再落笔（按需加载）；
   文件无「总索引」节 → 全文读取

4. 上一章 {project_dir}/drafts/chXX.md 最后 500 字（本章为第1章时省略；
   续写恢复场景改为：本章 drafts/chXX_draft.md 已有正文全文，从其末尾续写）

5. {project_dir}/meta/outline.md 本章小节

6. {project_dir}/meta/style_guide.md 的「绝对禁止」「样板句式」两节

7. {project_dir}/meta/continuity.md（连贯性登记：场景登记 + 事实断言——防场景复写与事实矛盾）
```

### 3.3 写作规范（注入 Writer prompt）

以下为通用规范；两处 `{...}` 占位**分别只注入**题材包 hooks.md 的「write_preflight」「signal_budget」两节全文（只取这两节，注入纪律见第〇节）：

```
## 写作规范

- 本项目根路径为：{project_dir}，所有文件操作仅在此目录下进行
- 本章目标：zh 约 2700 字 / en 约 1800 词（章级目标，可由项目覆盖）
- 容差范围：zh 2300–3100 字 / en 1500–2000 词——低于下限禁止结束生成，须补写至达标；
  高于上限检查是否有可拆入下一章的内容，若无则允许保留
- 正文生成后，将整章写入 {project_dir}/drafts/chXX_draft.md（含章节标题）

### 写作前行为预检

{题材包 hooks.md「write_preflight」全文}

### 投放原则

{题材包 hooks.md「signal_budget」全文}
```

### 3.4 任务指令模板

**整章生成**：
```
请写第{N}章完整正文。依据 outline 本章计划与「前情摘要」衔接上一章末尾，
完成本章全部计划节点，以"悬而未决的尾音"收章——不解答，提出下一章的核心问题。

🔴 权威状态版本 base_revision = {R}（由任务指令注入）。你不修改 meta/ 下任何权威文件
（session_log、characters、{signal_doc}、continuity、outline）——状态变化一律记入 chapter_delta。

写完后：
1. 将整章写入 {project_dir}/drafts/ch{NN}_draft.md（创建文件，含章节标题），
   随后将该文件重命名为 {project_dir}/drafts/ch{NN}.md（必须 mv 移动，原 draft 文件不得保留）
2. 运行 sha256sum 计算 drafts/ch{NN}.md 的哈希，然后按 3.6 契约生成 <chapter_delta>，
   写入 {project_dir}/meta/pending/ch{NN}.delta.md（整章任务唯一允许写的 meta 路径）。
   signal_changes 的登记内容与核对纪律（投放预算/结构核对/终章断言——发现缺投就地补投进正文）
   按随本指令注入的题材包 hooks.md「seal_check」执行；其中"更新 {signal_doc} / 回写 outline"
   的动作一律转为 delta 对应字段，不改权威文件
3. 按公共输出协议输出 <chapter_report>（不输出正文全文与 delta 全文）
```

**续写恢复**（整章输出被截断 / drafting 阶段中断后续跑，禁止重写全章）：
```
第{N}章生成中断。读取 {project_dir}/drafts/ch{NN}_draft.md 已有正文，
从最后一个完整段落之后继续写至本章收尾（禁止重写或改动已有部分）。
完成后按整章生成任务的步骤 1-3 执行（mv 重命名、生成 delta、输出 <chapter_report>）；
base_revision = {R}。
```

**delta 补生成**（正文已落盘但 delta 缺失 / 校验失败时的轻量任务，禁止改动正文）：
```
第{N}章正文已存在但 chapter_delta 缺失或已失效。读取 {project_dir}/drafts/ch{NN}.md 全文，
仅依据正文实际内容生成 <chapter_delta>（3.6 契约）：base_revision = {R}；
prose_hash 以你运行的 sha256sum 实测为准。写入 {project_dir}/meta/pending/ch{NN}.delta.md（覆盖旧文件）。
不改 drafts/ 下任何文件，不改权威 meta，不输出正文。完成后输出 <chapter_report>（word_count 填实测口径）。
```

**补写**（字数低于章级下限时；必须绑定目标版本与位置，禁止"重新 append"式整段重写）：
```
第{N}章正文低于章级字数下限（当前统计：{textstat 结果}）。
目标版本：{project_dir}/drafts/ch{NN}.md。
请仅在本章收尾段之内定向扩写至达标：定位现有结尾段落，就地扩写场景与细节，
不新增结构性情节，不改动其余正文。修改写入该文件后，重新运行 sha256sum 并
按 3.6 契约重新生成 delta 覆盖 {project_dir}/meta/pending/ch{NN}.delta.md
（base_revision 不变 = {R}；全章级字段按扩写后现状重算）。输出 <fix_report>。
```

**修复任务**（同样必须绑定目标版本）：
```
请修复第{N}章的以下问题。这是精准修复，不是重写。
项目目录：{project_dir}
目标版本：{project_dir}/drafts/ch{NN}.md（修复针对该版本；若文件此后被改动，先停止并报告版本冲突）

问题（来自责任编辑）：{问题描述}
建议方向：{建议方向}

要求：
1. 读取 {project_dir}/drafts/ch{NN}.md，仅定位并修改与问题相关的段落，其余正文一字不动
2. 修改后全章字数变化控制在 ±10% 以内
3. 严格遵守下方风格宪法与角色档案
4. 修改后直接更新该文件，并输出 <fix_report>
5. **delta 重生成（强制，替代旧版 meta 同步）**：正文变更后重新运行 sha256sum，
   将 <chapter_delta> 整体重新生成并覆盖 {project_dir}/meta/pending/ch{NN}.delta.md
   （base_revision 不变 = {R}；所有章节级字段按修复后全章现状重算，不只写改动部分——
   旧 delta 绑定旧正文版本，会被脚本校验拒绝）。🔴 禁止直接修改权威 meta
```

（修复/补写任务的 prompt 必须附：style_guide 两节 + 相关角色完整条目 + 问题所在段落的上下文，防止修复引入风格漂移。）

### 3.5 Writer 输出格式

**整章生成输出**（正文与 delta 全文只落盘，不进入报告）：

```
<chapter_report>
chapter: {N}
base_revision: {R——与任务指令注入值一致}
draft_path: drafts/ch{NN}.md
delta_path: meta/pending/ch{NN}.delta.md
delta: written|failed（failed → Director 按 3.4 派 delta 补生成任务）
word_count: {自报统计（zh 字数 / en 词数）——以 Director 脚本核验为准}
reader_summary: [100字以内，仅含正文已公开信息——供 Chooser/Reviewer 前情摘要复用]
author_notes: [仅报告偏差与待核查问题：计划偏离及原因、投放异常、showing 自查命中项
  （按题材包 hooks.md「showing_checklist」仅报命中项）、信息增量要点；无则写 none。
  ⚠️ 本字段不得进入 Chooser/Reviewer 读者资料包]
next_choices: [仅模拟读者策略启用时输出：状态句 + A/B/C 三个下一章开场走向（选项公平性原则见 4.2）]
status: ready_for_review
</chapter_report>
```

**修复任务输出**：

```
<fix_report>
problem: [原问题一句话复述]
applied: yes|partial|no
delta_regenerated: yes|no
summary: [实际改了什么，2句话]
</fix_report>
```

### 3.6 chapter_delta 契约（Writer 产出、Director 提交时应用）

Writer 整章/续写/delta 补生成/修复/补写任务均产出 delta，写入 `meta/pending/ch{NN}.delta.md`（覆盖旧版本）。**分界**：LLM（Writer）负责提取语义变化，脚本（chapter_tools.sh verify-delta）负责结构、字段、版本与正文绑定；脚本不能证明小说语义一致，正文新事实遗漏于 delta 属专门风险——Director 在 6.4 核验时抽查 source_passages 与正文对应。

文件格式（各节标签**全部必需**，无内容写"无"；缺任一节 verify-delta 直接拒绝）：

```
<chapter_delta>
chapter: {N}
base_revision: {R——任务指令注入的权威状态版本，提交前校验}
prose_path: drafts/ch{NN}.md
prose_hash: {sha256sum 实测——把 delta 绑定到具体正文版本}

<new_facts>
- {正文新确立的事实}｜来源: {段落定位}
</new_facts>

<revised_facts>
- {对既有事实的修订：旧断言 → 新断言}｜依据: {段落定位}
</revised_facts>

<scene_changes>
- 场景: {名}｜地点: {…}｜氛围/视角: {…}｜已用关键细节意象: {一句话}｜来源: {段落定位}
</scene_changes>

<character_state_changes>
- 角色: {名}｜变化: {位置/身体/物品/称谓/状态}｜来源: {段落定位}
</character_state_changes>

<information_acquisitions>
- 角色: {名}｜获知: {信息}｜来源: {谁/什么载体}｜章内顺序: {序号}
</information_acquisitions>

<signal_changes>
- 编号: {ID}｜操作: 新增登记｜内容: {一句话}｜正文摘录: {原文短引}
- 编号: {ID}｜操作: 状态更新（{旧状态}→{新状态}）｜依据: {正文摘录或段落定位}
- 编号: {ID}｜操作: 总索引行（新增/更新后的一行）
</signal_changes>

<outline_deviations>
- {计划偏离与原因；无则写"无"——outline 本章「实际执行」由提交步骤依据本节与计划对照回写}
</outline_deviations>

<unresolved_issues>
- {Writer 自报待核查问题；无则写"无"}
</unresolved_issues>

<source_passages>
- {new_facts/character_state_changes/information_acquisitions 各关键条目对应的正文定位：
  段首引文或「第X段·角色Y」式定位，供提交时定向核验，不复制大段正文}
</source_passages>
</chapter_delta>
```

字段纪律：
- **信息获得事件**必须含获得者、获知内容、来源、章内顺序——知识边界核查以章初状态 + 顺序事件为基准，不能只用章末快照
- **signal_changes** 中新登记编号必须先自检未被占用（提交时 Director 以 `chapter_tools.sh check-id` 复核）；总索引行同步给出，保证"一条不少"
- **source_passages** 只写定位与短引，禁止整段复制正文（防 delta 变成第二份正文）
- delta 文件本身不含正文全文、不含 {core_doc} 内容；修复后重生成时全部字段按修复后全章现状重算

---

## 四、Chooser 角色（可选策略：模拟读者选路，默认关闭）

### 4.0 启用条件与调用时机

默认策略下自动模式不调用 Chooser（不生成三选项，不承担模拟读者成本）。仅当满足以下任一条件时启用 `strategy: simulate_reader`：

- `/auto-write --simulate-reader [项目名|new]` 显式开启
- 运行期指令（"开启/关闭模拟读者选路"）切换 auto_state.json 的 strategy 字段

启用后的调用时机：**每章一次、章级粒度**——Writer 在 `<chapter_report>` 的 next_choices 字段给出下一章开场的三分走向；本章提交后派发 Chooser 选择；选择写入 chooser_log，并注入下一章 Writer prompt 的「上章读者选择」节。

**选项公平性原则（启用时注入 Writer prompt，生成 next_choices 强制遵守）**：

```
你持有核心设定文档，但三分选择的三个选项必须对不知道终局的读者完全公平：
- 三个选项的信息量、具体度、预告字数相当（差距不超过 20%）
- 禁止利用核心设定让某个选项显得"更安全""更正确""更回避"或措辞更含糊
- 每个选项都必须与核心设定兼容——选择改变的是路径，不是既定事实
- 禁止在选项措辞或预告中暗示"哪个选项更接近终局真相"
```

### 4.1 身份 prompt

```
你是一位资深的小说读者。你正在阅读一部正在创作中的{题材显示名}小说。

你已经连续读完了目前所有已完成的章节——你对故事有连贯的记忆、偏好和期待。

你的任务是：根据当前已有的剧情内容，从作者给出的 3 个走向选项中选择你最想看到的一个。

⚠️ 你不知道真相、结局或核心设定（你从未见过它们）。你的判断完全基于已读内容的直觉。

选择标准：
- 哪个选项最让你好奇？
- 哪个最出乎意料但不违背逻辑？
- 如果三个都好，选那个让你"最不确定会发生什么"的
- 参考你之前的阅读轨迹：你想看到的故事方向是否在积累？是否到了该变化的时候？

不要分析过多。像一个沉浸在故事里的读者一样，凭直觉做出反应。
```

### 4.2 接收的上下文

Director 构建 Chooser prompt 时，**仅**传入以下内容：

```
1. Chooser 身份 prompt（上方；{题材显示名} 取自题材包 manifest 的 display）
2. genre + language
3. 前情回顾：最近 2 章的读者安全摘要（来源 session_log，仅提取"核心事件/角色变化/读者已知"字段，见 6.5 提取规则）
4. 本章正文的读者摘要（Writer 输出的 <chapter_report>.reader_summary——仅含正文已公开信息）
5. 你的选择轨迹（来自 auto_state.json 的 chooser_log：此前每章的选择 + 理由）
6. 三分选择文本（原样转发 Writer 输出的 next_choices 内容：状态句 + A/B/C 选项）
```

⚠️ **以下内容绝对不得出现在 Chooser prompt 中**：
- `{core_doc}`（核心设定文档）的任何内容
- `characters.md` 的任何内容（含 sanitize_fields 所列隐瞒字段）
- `{signal_doc}` 中标注为"待投放"的投放物
- session_log 中"读者此刻不知道"字段的内容（可能含终局指针）
- `outline.md` 中尚未写到的章节计划

### 4.3 Chooser 输出格式

```
<choice>A|B|C</choice>
<reason>[1-2句话，从读者角度]</reason>
```

### 4.4 Solver 变体（挑战读者测试；触发点命中即必须派发，见 writing_loop.md /auto-write 步骤 12）

Solver 与 Chooser 共享"读者立场 + 无真相视角"，但任务不同：Chooser 做选择，Solver **报告自己此刻的推论**——用于实测误导结构与投放物在读者端是否生效。

**身份 prompt**：

```
你是一位认真的长篇小说读者，刚刚一口气读完了这部作品目前已完成的全部章节。
你不知道任何作者设定的结局或核心设定——你只是边读边想。
现在作者问你：仅凭你已经读到的内容，你目前对"这一切的解释"得出了什么结论？

要求：
- 给出你的领先推论（可以多个，按可能性排序）
- 每条推论标注支撑它的具体细节/投放物（能想起来的都列上）
- 给出你的信心度（百分比）
- 说出最让你困惑、觉得解释不通的一点

像一位会在书页边写批注的读者一样作答。不要客气，也不要故作聪明。
```

**接收的上下文（Director 构建，摘要版——控制 token，不注入章节全文）**：

```
1. Solver 身份 prompt（上方）
2. genre + language + 已完成章节数
3. 前情索引：session_log 蒸馏后的各章单行摘要 + 最近 2 章的读者安全摘要（提取规则同 6.5）
4. {signal_doc} 中状态为"已投放"的投放物（脱敏版：内容 + 表面作用 + 投放记录摘录；
   🔴 剔除全部 🔒 真相指针字段与"待投放"条目）
```

⚠️ 与 Chooser 相同的隔离纪律：{core_doc}、待投放物、未写到的 outline 内容、session_log 的"读者此刻不知道"与"信息增量"字段，一律不得出现。

**输出格式**：

```
<solver_report>
领先推论：
1. [推论]（信心 X%）——支撑：[投放物编号/细节]
2. ...
最困惑点：[一句话]
</solver_report>
```

**Director 判定规则（对照 {core_doc} 的全书结构执行）**：

- 领先推论 = 当前应生效的假象/误导结构 → ✅ 结构生效，无需动作
- 领先推论 = 终局事实 → ⚠️ 提前泄漏：检查近期投放物指向性是否过强，考虑调整后续投放顺序（更新 outline「章节计划变更记录」并写明原因）
- 领先推论 = 早已被推翻的旧结构，或无法组织任何推论 → ⚠️ 支撑不足：下章补维持性证据，或让主角做一次梳理
- 结论以一行【挑战读者测试】条目追加 session_log（提交完成后写入，遵守 meta 写权——自动模式下 Solver 在提交后派发，见 writing_loop /auto-write 步骤 12）

---

## 五、Reviewer 角色（责任编辑）

### 5.1 身份 prompt（由题材包提供）

Reviewer 的身份 prompt 按以下模板拼接（编辑人格本体是题材包单一事实来源）：

```
{references/genres/{genre}/personas.md 中「编辑人格」一节的全文，原样内联}

你正在审阅一部新作的最新一章。你没有读过任何剧情大纲或核心设定文档——这正是你最大的优势：你体验的，就是读者会体验的。
```

### 5.2 接收的上下文（Director 构建，全部脱敏）

```
1. Reviewer 身份 prompt（上方模板，题材包 personas.md「编辑人格」）
2. genre + language + 章节号
3. 上一章的读者安全摘要（连续性参照，提取规则见 6.5）；本章衔接可加 Writer 的 reader_summary
4. 本章正文路径：{project_dir}/drafts/chXX.md（Reviewer 用 read 工具自读——Director 不内联全文）
5. {project_dir}/meta/style_guide.md 的「绝对禁止」和「样板句式」两节（路径 + 定向读取指引）
6. 本章出场角色条目（脱敏版）：保留身份、性格、说话方式、当前状态、称谓、当前已知信息；
   🔴 必须剔除 manifest「sanitize_fields」所列的全部终局性字段
   （「当前已知信息」不含终局指针，保留它是为了让 Reviewer 能检查"角色说出/做出超出其已知范围的事"）
7. {signal_doc} 中状态为"已投放"的投放物清单（待投放一律剔除；带 🔒 标记的真相指针字段按 6.5 规则剔除）
8. 本章新投放物清单（来自 meta/pending/chXX.delta.md 的 signal_changes——delta 在审阅时尚未提交，
   {signal_doc} 停留在上一章状态；delta 的 signal_changes 只含编号/内容/正文摘录，无 🔒 字段，可安全注入。
   供 Reviewer 对照本章投放公平性与读者可用性）
```

⚠️ Reviewer prompt 中**绝对不得出现**：{core_doc}、待投放物、未写到的 outline 内容、characters.md 中的 sanitize_fields 所列字段。Reviewer 与 Chooser 一样是无真相视角。

### 5.3 审阅维度

与交互模式的责任编辑机制一致：

- **A. 风格一致性**：对照风格宪法，指出具体漂移位置
- **B. 读者视角模拟**：按题材包 `hooks.md` 的「review_dims」执行
- **C. 人物声音检查**：逐一核查本章角色对白是否与角色档案（脱敏版）一致（说话方式 + 称谓；言行是否超出「当前已知信息」边界）
- **D. 问题定级清单**：🔴 必须修改 / 🟡 建议修改 / 🟢 观察记录

### 5.4 Reviewer 输出格式

```
<review_report>
A. 风格一致性
[具体发现，或"本章无明显漂移"]

B. 读者视角模拟
[以第一次阅读本章的读者身份作答]

C. 人物声音检查
[逐一核查结果]

D. 问题定级清单
🔴 [具体问题 + 所在位置] → [建议方向]
🟡 [具体问题 + 所在位置] → [建议方向]
🟢 [观察记录]
（无问题则对应级别写"无"）
</review_report>
```

---

## 六、Director 编排协议

### 6.1 调用 Writer 的 prompt 构建模板（每章一次）

> 体积纪律：本模板只内联小体量内容；大文件一律走「自读清单」（见第〇节上下文传输纪律）。

```
{Writer 身份 prompt：3.1 节模板 + 题材包 personas.md「写作人格」全文}

---

## 项目信息
项目目录：{project_dir}
genre: {genre}
language: {language}

## 本章参数
- 出场角色：{名单}；首次出场：{名单（三字段纪律见自读清单第2项）}
- 应投/将触碰投放物编号：{编号列表，或"无"}
- base_revision: {R——meta/commits.json 的 state_revision 实读值；Writer 不得读写 commits.json}
- {core_doc} 读取指引：{骨架节标题（manifest core_skeleton）} + {outline 本章「核心依据」字段指向的分节}；任一缺省或本章为揭示/终局章 → "全文读取"

## 前情摘要（你写作的衔接基准）
{最近 2 章条目：核心事件、角色变化、故事内时间/地点、信息增量、下章切入点}
{上一章末尾原文见自读清单第4项}

## 上帝指令（若有）
{meta/directives.md 中适用于本章且未完成的指令；无则省略本节}

## 上章读者选择（仅模拟读者策略启用时）
{Chooser 对本章开场走向的选择与理由；默认策略下省略本节；第1章省略}

## 自读清单（用 read 工具依次完整读取，禁止跳过；正文衔接以自读结果为准）
{3.2 节自读清单的实例化：各文件路径 + 上方读取指引}

## 写作规范
{上方 3.3 节的完整写作规范（含题材包 hooks.md 的 write_preflight 与 signal_budget 全文）}

## 输出协议
{上方第二节，Writer 相关部分}

---

## 任务
{3.4 节整章生成模板（或续写恢复/补写/修复模板，按场景选择）}
{模拟读者策略启用时，任务末尾追加：本章 chapter_report 须含 next_choices 字段（公平性原则见 4.0）}
```

### 6.2 调用 Chooser 的 prompt 构建模板（仅 simulate_reader 策略）

```
{Chooser 身份 prompt}

---

你正在阅读一部{题材显示名}小说，使用{language_display}写作。

## 前情回顾（你已读过的最近章节）
{最近 2 章的读者安全摘要}

## 本章发生了什么
{Writer 输出的 <chapter_report>.reader_summary——仅含正文已公开信息；
🔴 禁止为生成摘要重读 draft 文件，禁止使用 author_notes}

## 你的选择轨迹
{chooser_log 逐条：第X章：选了B——理由摘录}

## 三个走向选项（下一章开场）
{Writer 返回的 next_choices 原文：状态句 + A/B/C 选项}

---

请从 A、B、C 中选择一个走向，输出 <choice> 和 <reason>。
```

### 6.3 调用 Reviewer 的 prompt 构建模板

```
{Reviewer 身份 prompt：5.1 节模板 + 题材包 personas.md「编辑人格」全文}

---

你正在审阅一部{题材显示名}小说的第 {N} 章，使用{language_display}写作。

## 上一章发生了什么（你的记忆）
{上一章读者安全摘要}

## 本章正文（用 read 工具自读，禁止跳过）
{project_dir}/drafts/chXX.md

## 风格宪法（节选）
{style_guide 的"绝对禁止"和"样板句式"两节}

## 本章出场角色档案
{脱敏后的角色条目（已剔除 manifest「sanitize_fields」所列字段）}

## 本章已投放的投放物
{{signal_doc} 中已投放部分（已剔除 🔒 真相指针字段）}

---

请按 A-D 维度审阅本章，输出 <review_report>。
审阅纪律：每条意见必须引用正文原文位置；没有依据的夸赞或批评不要写。
```

### 6.4 输出核验协议（Director 不盲信子任务报告；结构化核验一律调 scripts/chapter_tools.sh，禁止全文读入正文）

**核验纪律（控制 Director 上下文膨胀）**：Writer 只返回 `<chapter_report>`，正文全文与 delta 全文仅存在于磁盘——Director **不接收、不核验、不转交正文全文**。存在性、体量、hash、版本、字段结构、编号唯一性一律用 `chapter_tools.sh` / `textstat.sh` 判断；提交前的 meta 核验只做**定向读**（grep 本章关键字段），不重读整个 meta 文件。路径、长度、hash、版本以脚本实际结果为准，不盲信模型自报。

**Writer 返回后，Director 必须执行实体核验**：

```
1. 正文核验：bash scripts/chapter_tools.sh verify-draft {project_dir} {NN}
   - exit 2（ch{NN}_draft.md 残留、正式文件缺失）→ 派发续写恢复任务（3.4 模板）
   - exit 1（两者均无）→ 重试整个 Writer 子任务 1 次；仍失败 → 暂停报错请求干预
   - zh_chars / en_words 低于章级下限（zh 2300 / en 1500）→ 派发补写任务（3.4 模板）
   - 高于上限（zh 3100 / en 2000）→ 接受（Writer 已确认无可拆分）
   - id_leak 命中（正文残留登记编号样式）→ 派轻量修复子任务：
     "仅删除正文中的编号/结构术语标注，其余正文一字不动"（修复后按 3.4 修复模板要求重生成 delta）
2. delta 核验：bash scripts/chapter_tools.sh verify-delta {project_dir} {NN}
   - 字段/标签缺失（exit 1）→ 轻量重试：派 delta 补生成任务（3.4 模板）
   - base_revision 不匹配（exit 3）→ 权威状态已前进：以当前 state_revision 重新注入派 delta 补生成
   - prose_hash 不匹配（exit 3）→ delta 绑定旧版正文（修复后未重生成）→ 派 delta 补生成任务
3. <chapter_report> 可解析：draft_path / delta_path / base_revision / status 必填且
   status = ready_for_review、base_revision 与注入值一致；delta=failed → 派 delta 补生成任务
4. 章首衔接查重（第2章起；防"章首重写上章末"式重述接缝）：
   对照 `tail -n 15 上一章chXX-1.md` 与 `head -n 15 本章chXX.md`（Director 只读这约30行）——
   出现整句级重述（同一对白/叙述近乎原样重说、上章末场景被重新描写）→ 派发轻量修复子任务：
   "仅改写本章开头衔接段，删除与上章末重复的交代与描写，其余正文一字不动"（修复后重生成 delta）
5. 抽查 source_passages：对 delta 的 new_facts / information_acquisitions 各抽 1 条，
   按其定位定向读正文对应段落（grep 段首引文），确认事实确在正文中成立
   （防"正文有而 delta 无"或"delta 记了正文没有的事"）
6. 编号唯一性（防同号不同物）：对 delta signal_changes 中每个新增编号执行
   bash scripts/chapter_tools.sh check-id {project_dir} {signal_doc} {ID}
   - occurrences: 0 → 编号可用（提交时登记）
   - entry_headings > 1 → 同号多条目 → 责成 Writer 改用新编号（delta 补生成）
   - 已存在 1 条 → 对照输出行内容判定同物（更新状态）还是不同物（换编号）
7. 修复任务核验：<fix_report>.applied = yes 且 delta_regenerated = yes，且
   verify-draft 的 prose_hash 已变化、verify-delta 重跑通过（旧 hash 失效自动拦截）
8. 模拟读者策略启用时：next_choices 可解析且含 A/B/C 三项；选项公平性核验——
   三个选项预告字数差距是否超过约 1 倍、某选项是否明显空洞/含糊
   → 可疑时要求 Writer 仅重新输出 next_choices（并提醒选项公平性原则）
```

**Chooser / Reviewer / Solver 返回后**：
- Chooser：`<choice>` 必须是 A/B/C 之一，否则重试 1 次；仍失败 → 默认选 A，记录警告
- Reviewer：`<review_report>` 存在且 D 节可解析；失败 → 重试 1 次；仍失败 → 本章跳过审阅，进度卡片标记 ⚠️，记录到 session_log，不阻断主流程
- Solver：`<solver_report>` 存在且含至少一条推论；失败 → 重试 1 次；仍失败 → 跳过本次测试，标记 ⚠️，不阻断主流程

### 6.5 读者安全提取规则（构建 Chooser / Reviewer / Solver 上下文时）

从 `session_log.md` 提取前情时，**只允许**以下字段：
- 核心事件
- 角色变化
- 信息状态中"读者此刻知道"部分
- 本章投放（投放物/伏笔——仅已投放的）

**严禁提取**：
- "读者此刻不知道"字段（可能包含终局指针，如"读者不知道某人已知晓终局事实"）
- "信息增量"字段（记录各角色获知的内幕，可能含终局指针）
- 任何 Writer 写作后记中引用 {core_doc} 的内容（可能含终局指针）

从 `{signal_doc}` 为 **Writer** 提供「总索引 + 指定条目 + 按需加载」（控制注入体积，同时保证知晓完整——这是 Writer 上下文投放物信息的**唯一读取语义**）：
- **总索引节全量**：每条投放物一行（编号 + 一句话内容 + 状态）——Writer 对全部投放物"知晓存在"，这是防重投、防矛盾、防叙述意外触碰的底线
- **全条目仅注入**：outline 本章计划标注的编号（应投 / 将触碰 / 结构操作引用的证据编号）
- **按需加载**：写作中触及索引内其他活跃投放物时，Writer 必须先 read 该条目全文再落笔
- **不涉及**：「已归档」区条目
- 兼容：{signal_doc} 无「总索引」节（旧项目）→ Writer 自读全文
- 一致性保障：知晓靠总索引（一条不少），细节靠按需加载。此规则不删减任何"仍可能被正文触碰"的投放物——只把"全量细节搬运"改为"全量索引 + 按需细节"

从 `{signal_doc}` 提取"已投放"部分注入 **Reviewer 上下文**时：
- 仅保留：内容、表面作用、投放方式、投放记录
- **剔除所有带 🔒 标记的真相指针字段**（双重解释、可用时点、所属结构、推翻/化解证据等——它们指向核心设定的终点）

### 6.6 审阅过滤与有界修复循环

Director 收到 Reviewer 的 `<review_report>` 后：

```
第一步：过滤（Director 对照 {core_doc} 逐条判定）
- [采纳]：意见成立且修复不会泄露终局、不与既定事实冲突
- [保留]：意见与核心设定冲突，或修复会提前泄露终局 → 忽略
- [观察]：🟢 级别或不影响阅读的意见 → 忽略或记录

第二步：修复（同章全部 [采纳] 且 🔴 的条目合并为一次修复任务）
- 派发 Writer 修复子任务（用 3.4 修复任务模板，必须附 style_guide + 角色条目上下文，
  目标版本锁定当前 chXX.md、注入当前 base_revision；多条问题在任务中逐条列出）
- 修复返回后 Director 做一次轻量核验（6.4 第 7 项）：
  - <fix_report>.applied = yes 且 delta_regenerated = yes，且重跑 verify-draft
    （prose_hash 已变化）与 verify-delta（delta 重新绑定新版本、base_revision 仍匹配）
    均通过 → 完成
  - applied = partial/no，或复核发现改动区域仍有问题 → 追加一轮修复
    （仅针对改动区域与依赖事实，附上轮失败原因；每轮修复都必须重生成 delta）
- 合并修复 + 追加复核各最多 1 轮；仍失败 → 降级为 🟡 记录，继续推进，不阻断；
  🔴 硬性正确性问题（知识越界/核心事实矛盾）降级时必须在进度看板显式提示，不得静默标为通过
- ⚠️ 审阅结果只对审阅时的正文版本有效：修复改动正文后，旧审阅结论不得视为对新版本的覆盖
  （prose_hash 绑定使 verify-delta 自动拦截跨版本的 delta 与审阅混用）

第三步：记录（提交步骤中执行，遵守 meta 写权）
- 🟡（含降级条目）→ 提交时写入 session_log 本章条目："🟡 待处理：{问题描述}"
- 被降级的 🔴 → 提交时写入："🔴 未修复（已降级）：{问题描述}"
- 🟢 → 忽略
```

### 6.7 版本化提交协议（Director 亲自执行，不派子任务）

审阅与修复通过后进入提交阶段（phase=committing）。多文件写入不是原子操作——用提交记录与版本号使"部分完成"可识别、可恢复。权威状态版本 `state_revision` 与提交记录存于 `meta/commits.json`，**只经 `scripts/chapter_tools.sh` 读写**。

```
前置（全部通过才继续；任一失败回到对应阶段）：
1. bash scripts/chapter_tools.sh verify-draft {project_dir} {NN}   → exit 0 且字数在容差内
2. bash scripts/chapter_tools.sh verify-delta {project_dir} {NN}   → exit 0
   （base_revision 与 state_revision 匹配、delta 绑定当前正文版本——失效审阅/旧 delta 在此拦截）

应用 delta（按序写入权威 meta，Director 亲自执行）：
3. 幂等预检（中断恢复重入时防重复追加）：
   - grep session_log 是否已有本章「第N章」摘要条目 / characters 是否已有本章出场记录追加
   - 已存在的写入跳过，只补缺失部分（例如重提交时只追加【修改记录】行，不重写摘要）
4. session_log.md：按 writing_loop 章节摘要日志格式追加本章条目
   （含「故事内时间/地点」「信息增量」；字数用 textstat 实测值，不用自报）
5. characters.md：按 character_state_changes 更新「当前状态」「当前已知信息」快照，
   并在条目「状态历史」追加一行「第N章：{变化}」（无该小节则创建；历史不裁剪，见 6.9）
6. {signal_doc}：按 signal_changes 登记条目/更新状态，同步维护「总索引」行（一条不少）；
   每个新登记编号执行 check-id 复核唯一性
7. continuity.md：scene_changes → 「场景登记」表；new_facts/revised_facts → 「事实断言」表
8. outline.md：本章小节回写「实际执行」（outline_deviations 为"无"→ 按计划完成；有 → 偏差及原因）

登记提交：
9. bash scripts/chapter_tools.sh commit {project_dir} {NN} --meta-files "{本次实际写入的文件清单}"
   （幂等：同章同 hash 重跑为 no-op；正文修复过 → hash 变化 → 自动按重提交替换条目，版本前进）
10. 更新 auto_state.json：phase=committed（🔴 正文与权威状态都提交完毕才允许置 committed）

中断恢复规则（phase=committing 时启动恢复）：
- commits.json 无本章条目 → 从第 3 步幂等预检起重入（已应用的写入被跳过），继续 commit
- 有条目且 verify-commits hash 匹配 → 提交已完成，仅补 phase=committed，不重写任何文件
- 有条目但 hash 漂移 → 正文在提交后被改过：回到 6.4/6.6（重审 → 修复+delta 重生成 → 重新提交）
```

**运行记录（P0 遗留项，每章提交后执行）**：

```
bash scripts/chapter_tools.sh usage {project_dir} chapter={N} writer={1|0} writer_max={0|1} \
  reviewer={1|0} fix_rounds={0|1|2} solver={0|1} chooser={0|1} retries={轻量重试数} result={committed|recommitted|degraded}
```
追加式 JSONL（meta/usage.log），只记可观测计数，不回显正文；供成本对照（文档 §9.2）与回归分析。

### 6.8 检查点与中断恢复（auto_state.json）

Director 维护 `{project_dir}/meta/auto_state.json` 作为自动写作的唯一进度检查点，**每完成一个原子步骤立即更新 phase**（禁止用字节数/空行猜测进度）：

```json
{
  "mode": "auto-write | auto-chapter",
  "strategy": "default | simulate_reader",
  "total_chapters": 12,
  "current_chapter": 4,
  "phase": "drafting | reviewing | fixing | committing | committed | finished",
  "chooser_log": [
    {"chapter": 3, "choice": "B", "reason": "摘要"}
  ],
  "pending_directives": [],
  "updated": "YYYY-MM-DDTHH:mm:ss"
}
```

phase 语义：`drafting` = Writer 整章生成与 delta 产出中；`reviewing` = 正文与 delta 已落盘并通过 6.4 核验、待 Reviewer 审阅；`fixing` = 审阅过滤后修复中（每轮修复重生成 delta）；`committing` = 提交步骤中（6.7：应用 delta + 登记提交）；`committed` = 本章正文与权威状态均已提交（commits.json 有条目）；`finished` = 全书全部章节 committed 且 /finish 收尾（合稿+审阅+最终修复+重合稿）完成——**全书终态，禁止自造枚举值**。

**中断恢复规则**（`/auto-write` 启动时执行）：

```
1. 读取 auto_state.json（缺失/损坏 → 从磁盘重建：
   a. commits.json 有第N章条目且 verify-commits hash 匹配 → 该章 committed（以提交记录为准，
      优于 session_log 目测——不得因正式章节文件存在就认定封存、审阅、修复均已完成）
   b. 否则该章 drafting；chooser_log 可缺省，仅损失 Chooser 记忆
   c. 全程运行 bash scripts/chapter_tools.sh verify-commits —— 发现 hash 漂移的章节须先
      重新走"修复+delta 重生成+重新提交"，不得带着漂移继续写作）
2. 组合判定（phase × 文件状态）：
   - phase=drafting 且 chXX_draft.md 存在 → 派发续写恢复任务（3.4 模板：自读已有正文，
     从最后一个完整段落后继续，禁止重写全章）
   - phase=drafting 且 chXX.md 已存在（Writer 已落盘但状态未及更新）→ 不重写正文；
     运行 verify-delta：通过 → 进入 reviewing；缺失/失效 → 派 delta 补生成任务后进入 reviewing
   - phase=reviewing → 重新派发 Reviewer（针对当前 chXX.md 版本；其 hash 可从
     verify-draft 输出记录留痕）
   - phase=fixing → 重派修复任务（目标版本 = 当前 chXX.md；修复后重生成 delta）
   - phase=committing → 按 6.7 中断恢复规则（幂等重入或仅补 phase）
   - phase=committed → 从下一章正常续跑
   - phase=finished → 全书已完成：不重跑流水线，报告当前状态；如需再审阅走 /review
3. 向用户报告恢复点："检测到第 XX 章处于{阶段}，从断点继续。"
```

### 6.9 章间维护（每章提交完成后、下一章开始前，由 Director 执行）

三层分离（§5.1）：**原始历史**不因 prompt 预算丢弃；**当前快照**保持短小；**本章工作资料包**（6.1 模板实例化的最小资料集）从两者选取、可重建，不落盘为权威数据。

```
1. 历史归档与快照维护：
   - session_log.md：压缩前先把被压缩的完整条目整体追加到 meta/history/session_log_archive.md
     （先归档后压缩，顺序不可倒——原始历史是全稿审阅与角色知识回溯的依据）；随后仅保留
     最近 2 章完整条目，更早章节压缩为单行。🔴 压缩行格式（字段不得丢弃）：
     `第X章｜{故事内时间→时间}｜{地点}｜{核心事件一句话}｜{信息增量一句话}｜{投放物状态}`
   - {signal_doc}：已揭示且已拆穿/化解的投放物移入「已归档」区，单行化（活跃区与总索引保持一条不少）
   - characters.md：「当前状态」「当前已知信息」为章末快照；「状态历史」按章追加、
     🔴 不裁剪不删除（废除旧版"每角色仅保留最近 3 条"——完整历史留在条目内，
     Writer 本就只定向读取本章出场角色条目）
2. 🔴 蒸馏触发条件重构：文件超过 150 行或 12KB **不再是**派发 LLM 蒸馏的充分条件
   （历史大 ≠ 工作集大）。仅当工作资料包构建实际受阻（如单个角色条目/单节自身超长，
   导致 6.1 内联部分超预算）时，才派发**定向**蒸馏子任务——只蒸馏该条目/该节，
   蒸馏产物回写前先把原文追加到 meta/history/ 对应归档文件
3. 追加幂等（防重复写入）：向 session_log 追加任何条目或【修改记录】前，先确认同章同内容不存在；
   提交步骤的 delta 应用与 Solver 判定留痕不得重复追加同一条记录
4. 运行记录：bash scripts/chapter_tools.sh usage {project_dir} ...（见 6.7 末尾）追加本章运行计数
5. 上帝指令检查点：处理运行期收到的用户消息（见 writing_loop.md"运行期干预"）
6. 更新 auto_state.json，进入下一章
```

---

## 七、平台适配说明

本文件描述的是角色意图和通信协议，不涉及具体平台 API。各平台的宿主 Agent 根据自身能力映射子任务调用：

| 平台 | Writer/Chooser/Reviewer/Solver 调用方式 | 备注 |
|------|-------------------------------|------|
| OpenCode | `task` 工具，`subagent_type` 用已部署的 `novel-*` 角色 agents（推荐，见下方"角色档位"）；未部署时回退 `"general"`，角色定义写入 prompt | 需在 opencode.json 开启 `permission.task: "allow"` |
| Claude Code | `Task` / `new_session` | 原生支持 |
| Antigravity | `invoke_subagent` + `send_message` | 可定义 subagent type |

**角色档位（可选的平台增强，协议中立）**：支持按子任务绑定模型/思考档位的平台，可按以下档位部署角色变体。**未部署的平台一律用默认模型与通用子任务，协议行为完全不变**：

| 角色 | 档位 | 理由 |
|------|------|------|
| Writer（常规章） | 旗舰模型 · 高档思考 | 创作质量最敏感，不可降级 |
| Writer（深档变体） | 旗舰模型 · 最高档思考 | 用于证据收敛 / 推导揭示 / 对峙终局章——论断须逐步回指已投放细节，逻辑密度最高 |
| Chooser | 轻量模型 · 低档思考 | 读者直觉模拟，过度思考反而失真（仅 simulate_reader 策略启用时调用） |
| Reviewer | 旗舰模型 · 高档思考 | 风格漂移/声音一致性是文学判断 |
| Solver | 轻量模型 · 高档思考 | 认真读者的批注式分析，中轻量级即可 |

- **深档 Writer 调度规则**：Director 派发 Writer 前查 outline 本章的结构操作/所属阶段——本章属证据收敛、推导揭示或对峙终局章 → 派发深档变体；其余章节用常规档
- OpenCode 参考实现（`novel-writer` / `novel-writer-max` / `novel-chooser` / `novel-reviewer` / `novel-solver`）由 install.sh 自动部署到 `.opencode/agents/`，模型与档位配置见 `references/install_notes.md`

**关键**：Chooser、Reviewer 与 Solver 的 {core_doc} 隔离在所有平台上统一通过 **Director 不在 prompt 中传入（并主动脱敏）** 来保证，不依赖平台权限机制。这确保了跨平台一致的行为。

> 各平台安装时的具体配置说明见 `references/install_notes.md`。
