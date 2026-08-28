# 自动写作模式：角色定义与通信协议

> 本文件定义 `/auto-write` 和 `/auto-chapter` 模式中使用的子任务角色。
> Director（执行 Skill 的主 Agent 自身）通过平台提供的子任务机制调用 **Writer**（写正文）、**Chooser**（选走向）、**Reviewer**（责任编辑审阅）、**Solver**（按需：挑战读者测试）。

## 〇、题材包解析（Director 的先决步骤）

本文件使用抽象槽位，实际文件名由题材包声明：

- `{core_doc}` = 核心设定文档（作者持有的终局类文档）
- `{signal_doc}` = 投放物地图

启动自动写作时（writing_loop.md「前置检查」第2步），Director 必须 🔴 读取：
1. `references/genres/{genre}/manifest.md` —— 解析槽位、sanitize_fields、status_section 等
2. `references/genres/{genre}/personas.md` —— Writer / Reviewer 的身份来源
3. `references/genres/{genre}/hooks.md` —— 注入 Writer prompt 的写作规范与 Reviewer 审阅维度

🔴 只加载当前题材的题材包，严禁将其他题材的任何内容注入子任务上下文。

**注入纪律（防止题材包登记语言污染正文）**：构建 Writer prompt 时，题材包 hooks.md **只注入「write_preflight」与「signal_budget」两节全文**；「seal_check」仅随第 3 段任务指令注入；「review_dims」「full_review」只用于 Reviewer 与全稿审阅。🔴 严禁把 hooks.md 整个文件或题材包其他文件整体注入写作类子任务——封存/审阅用的编号与核对语言一旦进入写作上下文，会被模仿进正文。

---

## 一、角色概览与核心约束

| 角色 | 定位 | 上下文权限 | 文件写入权 | 输出 |
|------|------|-----------|-----------|------|
| **Director**（你自己） | 全局编排、输出核验、审阅过滤、方向调整 | 锁定目标 `{project_dir}`，持有全部 meta | `meta/auto_state.json`、`meta/directives.md`；封存完成后可追加 session_log | 进度汇报、修复决策 |
| **Writer**（子任务） | 单段正文生成、封存协议、精准修复 | 绑定 `{project_dir}`，完整 meta（含 {core_doc}） | 章节期间独占 `drafts/*`；仅第3段封存时写 meta 三件套 | XML 格式（见第二节） |
| **Chooser**（子任务） | 代替用户做走向选择 | ⚠️ **仅** 读者可见信息 + 自己的选择轨迹 | 无（纯输出，不写任何文件） | `<choice>` + `<reason>` |
| **Reviewer**（子任务） | 每章责任编辑审阅 | ⚠️ **无** {core_doc}；角色条目已剔除 sanitize_fields 所列字段 | 无（纯输出，不写任何文件） | `<review_report>` |
| **Solver**（子任务，按需） | 挑战读者测试：实测无终局视角的读者当前推论 | ⚠️ 与 Chooser 同级隔离（读者可见语料摘要版，见 4.4） | 无（纯输出，不写任何文件） | `<solver_report>` |

⚠️ **核心约束**：

1. **真实性隔离（三重）**：Chooser、Reviewer 与 Solver 都不得接触 `{core_doc}`（核心设定文档）的任何内容。Chooser 靠 Director 不传入保证；Reviewer 靠 Director 构建**脱敏上下文**保证（含 characters.md 中 manifest「sanitize_fields」所列终局性字段的剔除，见 5.2）；Solver 靠 Director 只注入读者可见语料摘要保证（见 4.4）。这样"读者视角选择""读者视角审阅"与"读者视角实测推论"都是真实的无真相视角，而不是 Writer 持真相自我模拟。
2. **选项公平性**：Writer 持有核心设定生成三分选择，必须遵守选项公平性原则（见 3.3），Director 负责核验。
3. **多项目隔离**：Director、Writer、Chooser、Reviewer **仅限在锁定的目标 `{project_dir}`（即 `novels/{项目名}`）** 目录下读写。严禁跨目录访问或修改其他小说。
4. **meta 写权划分（防双写冲突）**：
   - 章节流水线期间，Writer 独占 `meta/session_log.md`、`meta/characters.md`、`meta/{signal_doc}` 的写权，且仅在**第3段封存协议**中行使；
   - Director 仅写 `meta/auto_state.json` 与 `meta/directives.md`；
   - Director 的 🟡 记录、章间蒸馏等 meta 写入，**必须在封存完成之后**进行。

---

## 二、公共输出协议（XML 标签）

子任务输出中所有**机器可解析**的部分一律用 XML 标签包裹（标签内仍是普通文本/markdown）。Director 依靠标签解析，不依赖 markdown 标题猜测。

| 标签 | 使用者 | 内容 |
|------|--------|------|
| `<prose>` | Writer | 本段正文 |
| `<choices>` | Writer | 三分选择（状态句 + A/B/C 选项） |
| `<segment_meta>` | Writer | 字数、投放物、角色变化 |
| `<seal_report>` | Writer | 第3段封存协议执行结果 |
| `<postscript>` | Writer | 第3段写作后记 |
| `<fix_report>` | Writer | 修复任务执行结果 |
| `<choice>` / `<reason>` | Chooser | 走向选择 / 理由 |
| `<review_report>` | Reviewer | 编辑审阅报告（A-D 维度 + 定级清单） |
| `<solver_report>` | Solver | 挑战读者测试报告（领先推论 / 支撑投放物 / 信心度 / 困惑点） |

**解析失败处理**：若关键标签缺失或为空，Director 不重跑整个子任务，而是派发一个**轻量重试**子任务："请仅重新输出 `<标签>` 部分，不要重写正文"。同一子任务轻量重试最多 1 次，仍失败按第六节异常降级处理。

---

## 三、Writer 角色

### 3.1 身份 prompt（由题材包提供）

Writer 的身份 prompt 按以下模板拼接（人格本体是题材包单一事实来源，本文件不定义题材人格）：

```
你是一位深谙{题材}小说工艺的作家，正在接受编辑（Director）的指令完成单段正文生成。

{references/genres/{genre}/personas.md 中「写作人格」一节的全文，原样内联}
```

### 3.2 接收的上下文

Director 每次调用 Writer 子任务时，必须在 prompt 中内联以下内容（按此顺序）：

```
1. Writer 身份 prompt（上方模板，题材包 personas.md「写作人格」）

2. 项目目录 {project_dir}、genre 与 language

3. {project_dir}/meta/style_guide.md 的「绝对禁止」和「样板句式」两节

4. {project_dir}/meta/{core_doc} 全文（核心设定文档——Writer 持有它写作，但正文不得泄露其终局信息）

5. {project_dir}/meta/characters.md 中本章出场角色的条目
   ⚠️ 首次出场角色只注入：出场前读者已知信息 + 出场引入方式 + 身份
   完整档案（含 manifest「sanitize_fields」所列的题材终局性字段）在角色二次出场后解锁
   ⚠️ 首次/二次出场判定一律以角色条目中的「出场记录」字段为准

6. {project_dir}/meta/{signal_doc} **注入子集**（见 6.5 子集提取规则：活跃投放物全条目 + 已揭示/已化解投放物单行索引）

7. 当前 {project_dir}/drafts/chXX_draft.md 的内容（如存在）；否则上一章 chXX.md 最后 500 字

8. 最近 2 章的剧情摘要（从 {project_dir}/meta/session_log.md 提取：核心事件、角色变化、故事内时间/地点、信息增量、下章切入点。⚠️ Writer 持有核心设定，注入无需脱敏——这是子任务衔接前情、避免跨章矛盾的主通道）

9. {project_dir}/meta/outline.md 中本章的计划节点（本章目标、应投投放物、结构操作、应揭秘密、章末钩子等——字段名以题材包 outline 模板为准）

10. 上帝指令（若 meta/directives.md 中存在未完成且适用于本章的指令）

11. 任务指令（见下方 3.4 节）
```

### 3.3 写作规范（注入 Writer prompt）

以下为通用规范；两处 `{...}` 占位**分别只注入**题材包 hooks.md 的「write_preflight」「signal_budget」两节全文（只取这两节，注入纪律见第〇节）：

```
## 写作规范

- 本项目根路径为：{project_dir}，所有文件操作仅在此目录下进行
- 每段目标：zh 850–950 字 / en 550–650 词（硬约束）
- 低于下限：禁止结束，必须补写至达标
- 超过上限：检查是否有可拆入下一段的内容，若无则允许保留
- 正文生成后，立即将本段 append 写入 {project_dir}/drafts/chXX_draft.md
- 第一段创建文件并写入章节标题 + 正文
- 第二、三段 append 到同一文件末尾

### 写作前行为预检

{题材包 hooks.md「write_preflight」全文}

### 投放原则

{题材包 hooks.md「signal_budget」全文}

### 选项公平性原则（生成三分选择时强制遵守）

你持有核心设定文档，但三分选择的三个选项必须对不知道终局的读者完全公平：
- 三个选项的信息量、具体度、预告字数相当（差距不超过 20%）
- 禁止利用核心设定让某个选项显得"更安全""更正确""更回避"或措辞更含糊
- 每个选项都必须与核心设定兼容——选择改变的是路径，不是既定事实
- 禁止在选项措辞或预告中暗示"哪个选项更接近终局真相"
```

### 3.4 任务指令模板

**第 1 段**：
```
请写第{N}章第1段。这是本章的开场段。
推进到一个"信息悬停点"后结束。
写完后将正文 append 到 {project_dir}/drafts/ch{NN}_draft.md（创建文件，含章节标题）。
然后按公共输出协议输出 <prose>、<choices>、<segment_meta>。
```

**第 2 段**：
```
请写第{N}章第2段。
上一段结束后，读者选择了方向{choice}："{choice_description}"。
请根据此走向推进，到"张力转折点"后结束。
写完后将正文 append 到 {project_dir}/drafts/ch{NN}_draft.md。
然后按公共输出协议输出 <prose>、<choices>、<segment_meta>。
```

**第 3 段**（只写不审——编辑审阅由独立的 Reviewer 负责）：
```
请写第{N}章第3段（最终段）。
上一段结束后，读者选择了方向{choice}："{choice_description}"。
请收拢本章，以"悬而未决的尾音"结束——不解答，提出下一章的核心问题。
写完后：
1. 将正文 append 到 {project_dir}/drafts/ch{NN}_draft.md
2. 将 {project_dir}/drafts/ch{NN}_draft.md 重命名为 {project_dir}/drafts/ch{NN}.md（mv 移动，原 draft 文件不得保留）
3. 执行章节封存协议（更新 {project_dir}/meta/ 下 session_log、characters、{signal_doc}；核对按随本指令注入的题材包 hooks.md「seal_check」一节执行）
4. 按公共输出协议输出 <prose>、<seal_report>、<postscript>（无需输出编辑审阅和三分选择）
```

**修复任务**：
```
请修复第{N}章的以下问题。这是精准修复，不是重写。
项目目录：{project_dir}

问题（来自责任编辑）：{问题描述}
建议方向：{建议方向}

要求：
1. 读取 {project_dir}/drafts/ch{NN}.md，仅定位并修改与问题相关的段落，其余正文一字不动
2. 修改后全章字数变化控制在 ±10% 以内
3. 严格遵守下方风格宪法与角色档案
4. 修改后直接更新该文件，并输出 <fix_report>
5. **meta 同步（强制）**：若改动涉及已投放物的文本/位置、角色状态、称谓、时间线或角色获知的信息 → 同步更新 {signal_doc} / characters.md 对应条目，并在 session_log.md 追加一行修改记录（此项结果写入 <fix_report> 的 meta_synced）
```

（修复任务的 prompt 必须附：style_guide 两节 + 相关角色完整条目 + 问题所在段落的上下文，防止修复引入风格漂移。）

### 3.5 Writer 输出格式

**第 1 / 2 段输出**：

```
<prose>
[本段正文，zh 850-950字 / en 550-650词]
</prose>

<choices>
状态：[一句话说明当前剧情状态]
A. [选项名] → [2句话预告]
B. [选项名] → [2句话预告]
C. [选项名] → [2句话预告]
</choices>

<segment_meta>
word_count: {N}
planted: [投放物描述或 none]
character_changes: [描述或 none]
</segment_meta>
```

**第 3 段输出**：

```
<prose>
[本段正文]
</prose>

<seal_report>
draft_renamed: yes|no
session_log: updated|failed
characters: updated|failed
signal_doc: updated|failed
outline_exec: updated|failed
</seal_report>

<postscript>
- 本章投放：[投放物描述]
- 角色状态变化：[描述]
- 信息增量：[本章谁新获知了什么（角色→信息，含来源），或 none]
- 读者已知 / 不知信息对比：已知：... 不知：...
- Showing 自查（⚠️ 仅输出命中项，未命中的检查项与清单本身不要输出；无命中写"无"）：
  [按题材包 hooks.md「showing_checklist」自查——通用项 + 题材专项项]
</postscript>
```

**修复任务输出**：

```
<fix_report>
problem: [原问题一句话复述]
applied: yes|partial|no
meta_synced: yes|no|not_needed
summary: [实际改了什么，2句话]
</fix_report>
```

---

## 四、Chooser 角色

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
4. 本章此前段落的剧情摘要（Director 基于当前 draft 生成，200字以内）
5. 最新一段的剧情状态（Writer 输出的 <choices> 中的"状态"句）
6. 你的选择轨迹（来自 auto_state.json 的 chooser_log：此前每章每段的选择 + 理由）
7. 三分选择文本（原样转发 Writer 输出的 <choices> 内容）
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

### 4.4 Solver 变体（挑战读者测试，Director 按需派发）

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
- 结论以一行【挑战读者测试】条目追加 session_log（封存完成后写入，遵守 meta 写权）

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
3. 上一章的读者安全摘要（连续性参照，提取规则见 6.5）
4. 本章正文全文（{project_dir}/drafts/chXX.md）
5. {project_dir}/meta/style_guide.md 的「绝对禁止」和「样板句式」两节
6. 本章出场角色条目（脱敏版）：保留身份、性格、说话方式、当前状态、称谓、当前已知信息；
   🔴 必须剔除 manifest「sanitize_fields」所列的全部终局性字段
   （「当前已知信息」不含终局指针，保留它是为了让 Reviewer 能检查"角色说出/做出超出其已知范围的事"）
7. {signal_doc} 中状态为"已投放"的投放物清单（待投放一律剔除；带 🔒 标记的真相指针字段按 6.5 规则剔除）
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

### 6.1 调用 Writer 的 prompt 构建模板

```
{Writer 身份 prompt：3.1 节模板 + 题材包 personas.md「写作人格」全文}

---

## 项目信息
项目目录：{project_dir}
genre: {genre}
language: {language}

## 风格宪法（节选）
{从 {project_dir}/meta/style_guide.md 提取的"绝对禁止"和"样板句式"两节}

## 核心设定文档
{{project_dir}/meta/{core_doc} 全文}

## 本章出场角色
{从 {project_dir}/meta/characters.md 提取的对应角色条目}

## 投放物状态（注入子集）
{按 6.5 子集提取规则从 {project_dir}/meta/{signal_doc} 提取：活跃（未揭示/未化解）投放物全条目 + 已揭示且已拆穿/化解投放物的单行索引；「已归档」区不注入}

## 前情摘要（最近章节，你写作的衔接基准）
{从 {project_dir}/meta/session_log.md 提取的最近 2 章条目：核心事件、角色变化、故事内时间/地点、信息增量、下章切入点}

## 本章计划
{从 {project_dir}/meta/outline.md 提取的本章节点：本章目标、应投投放物、结构操作、应揭秘密、章末钩子等——字段名以题材包 outline 模板为准}

## 上帝指令（若有）
{meta/directives.md 中适用于本章且未完成的指令；无则省略本节}

## 已有内容
{{project_dir}/drafts/chXX_draft.md 当前内容，或上一章 chXX.md 最后 500 字}

## 写作规范
{上方 3.3 节的完整写作规范（含题材包 hooks.md 的 write_preflight 与 signal_budget 全文）}

## 输出协议
{上方第二节，Writer 相关部分}

---

## 任务
{根据段落编号选择 3.4 节中对应的任务指令模板}
```

### 6.2 调用 Chooser 的 prompt 构建模板

```
{Chooser 身份 prompt}

---

你正在阅读一部{题材显示名}小说，使用{language_display}写作。

## 前情回顾（你已读过的最近章节）
{最近 2 章的读者安全摘要}

## 本章此前发生了什么
{Director 基于当前 draft 生成的剧情摘要，200字以内}

## 最新一段的剧情状态
{Writer 输出的 <choices> 中的状态句}

## 你的选择轨迹
{chooser_log 逐条：第X章第Y段：选了B——理由摘录}

## 三个走向选项
{Writer 返回的 <choices> 中的 A/B/C 选项原文}

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

## 本章正文
{{project_dir}/drafts/chXX.md 全文，由 Director 内联}

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

### 6.4 输出核验协议（Director 不盲信子任务报告；核验用工具命令，禁止全文读入）

**核验纪律（控制 Director 上下文膨胀）**：正文已随 Writer 返回的 `<prose>` 存在于 Director 上下文中，🔴 **禁止再读取 draft 全文做核验**。文件增长、字数、段数一律用工具命令（`ls -l` / `wc -c` / `wc -w`）判断；meta 封存核验只做**定向读**（`tail` session_log 新增条目、grep outline 本章「实际执行」字段），不重读整个 meta 文件。

**每次 Writer 返回后，Director 必须执行实体核验**：

```
1. 文件核验（用 ls -l / wc -c 对比写入前后的字节数，不读内容）：
   - 文件未创建/未增长：
      a. 若返回的 <prose> 内容完整 → Director 代为写入（append）
      b. 若 <prose> 缺失或截断 → 重试整个 Writer 子任务 1 次；仍失败 → 暂停报错请求干预
   - 字数核验（zh: wc -c 近似，1段 ≈ 2700字节 / en: wc -w，1段 ≈ 600词）：
      a. 低于下限（850字/550词）→ 派发补写子任务："仅将本段补写至达标后重新 append，不改动已有内容"
      b. 高于上限（950字/650词）→ 接受（Writer 已确认无可拆分）
   - 编号泄漏核验（正文纯净性）：`grep -nE '（[A-Z]+[-－]?[0-9]+）'` 检查写入后的文件（全角括号内"大写字母+数字"的登记编号样式）→ 命中 → 派发轻量修复子任务："仅删除正文中的编号/结构术语标注，其余正文一字不动"
   - 段数判定（中断恢复/第0步同样适用）：按字节增长近似（zh 每段约2700字节 / en 每段约600词），或 grep 空行分段计数；不全文读入
2. 段1/2：<choices> 可解析且含 A/B/C 三项 → 解析失败按第二节轻量重试
3. 选项公平性核验：三个选项预告字数差距是否超过约 1 倍、某选项是否明显空洞/含糊
   → 可疑时要求 Writer 仅重新输出 <choices>（并提醒选项公平性原则）
4. 段3额外核验：
   - {project_dir}/drafts/chXX.md 是否存在（重命名是否执行，用 ls 判断）→ 未执行则 Director 代为重命名（必须 mv 移动，禁止 cp 复制）
   - 🔴 残留核验：确认 chXX_draft.md 已消失。若 chXX.md 与 chXX_draft.md 并存（复制而非移动的典型症状）→ 删除残留的 draft 文件（否则 6.7 中断恢复会误判该章未完成，导致重写已封存章节）
   - <seal_report> 中标记 failed 的 meta 更新 → 由 Director 亲自补写对应文件
   - 封存内容核验（定向读）：tail session_log 检查新条目是否含「故事内时间/地点」「信息增量」字段；grep outline 本章「实际执行」是否已回写；缺漏 → Director 补写
5. 修复任务核验：<fix_report>.applied = yes 且 meta_synced ≠ no（no → Director 亲自补写 meta 对应条目）
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

从 `{signal_doc}` 注入 **Writer 上下文**时的子集提取规则（控制 prompt 膨胀，同时保持一致性所需信息完整）：
- **全条目注入**：状态为"待投放"、"已投放未揭示/未化解"的活跃投放物（这些是 Writer 防重投、防矛盾、执行结构操作的对象）；即使与本章无直接关联的活跃投放物也保持全条目（防止叙述中意外触碰）
- **单行索引注入**：状态为"已揭示且已拆穿/已化解"的投放物（编号 + 一句话状态——Writer 只需知道"不能再当悬念用"，无需细节）
- **不注入**：「已归档」区条目
- 一致性保障：活跃投放物一条不少；已拆穿/化解投放物保留可查索引。此规则不删减任何"仍可能被正文触碰"的投放物

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

第二步：修复（仅 [采纳] 且 🔴 的条目）
- 派发 Writer 修复子任务（用 3.4 修复任务模板，必须附 style_guide + 角色条目上下文）
- 修复返回后 Director 重读文件做一次轻量核验：
  - <fix_report>.applied = yes 且文件确实变更 → 完成
  - applied = partial/no → 再派发一轮（附上轮失败原因）
- 同一问题最多 2 轮修复；仍失败 → 降级为 🟡 记录，继续推进，不阻断

第三步：记录（封存完成后执行，遵守 meta 写权）
- 🟡（含降级条目）→ 追加到 session_log 本章条目："🟡 待处理：{问题描述}"
- 被降级的 🔴 → 追加："🔴 未修复（已降级）：{问题描述}"
- 🟢 → 忽略
```

### 6.7 检查点与中断恢复（auto_state.json）

Director 维护 `{project_dir}/meta/auto_state.json` 作为自动写作的唯一进度检查点，**每完成一个原子步骤立即更新**：

```json
{
  "mode": "auto-write | auto-chapter",
  "total_chapters": 12,
  "current_chapter": 4,
  "current_segment": 2,
  "chooser_log": [
    {"chapter": 3, "segment": 1, "choice": "B", "reason": "摘要"},
    {"chapter": 3, "segment": 2, "choice": "A", "reason": "摘要"}
  ],
  "pending_directives": [],
  "updated": "YYYY-MM-DDTHH:mm:ss"
}
```

**中断恢复规则**（`/auto-write` 启动时执行）：

```
1. 检查 {project_dir}/drafts/ 下是否存在 chXX_draft.md 残留：
   - 存在且有 1 段 → 从第 XX 章第 2 段续写（不作废、不重写）
   - 存在且有 2 段 → 从第 XX 章第 3 段续写
   - ⚠️ 但若同章 chXX.md 已存在（封存后复制的残留）→ 该章实际已完成：删除残留 draft，从第 XX+1 章正常续跑，禁止重写
   - 读取 auto_state.json 恢复 chooser_log；若文件缺失/损坏，
     从 session_log 重建（选择轨迹可缺省，仅损失 Chooser 记忆）
2. 向用户报告恢复点："检测到第 XX 章写到第 X 段，从断点继续。"
3. 恢复的段落续写时，Writer prompt 中已含 draft 全文，无需特殊处理
```

### 6.8 章间维护（每章完成后、下一章开始前，由 Director 执行）

```
1. meta 蒸馏（控制长篇上下文膨胀）：
   - session_log.md：仅保留最近 2 章完整条目，更早章节压缩为单行（章号+核心事件+投放物状态）
   - {signal_doc}：已揭示且已拆穿/化解的投放物移入「已归档」区，单行化
   - characters.md：动态状态字段只保留最新快照；旧状态移入「状态历史」，每角色仅保留最近 3 条
   - 任一文件超过 150 行 → 派发 meta 维护子任务深度蒸馏（该子任务可持有完整 meta）
2. 上帝指令检查点：处理运行期收到的用户消息（见 writing_loop.md"运行期干预"）
3. 更新 auto_state.json，进入下一章
```

---

## 七、平台适配说明

本文件描述的是角色意图和通信协议，不涉及具体平台 API。各平台的宿主 Agent 根据自身能力映射子任务调用：

| 平台 | Writer/Chooser/Reviewer/Solver 调用方式 | 备注 |
|------|-------------------------------|------|
| OpenCode | `task` 工具，`subagent_type: "general"`，角色定义写入 prompt | 需在 opencode.json 开启 `permission.task: "allow"` |
| Claude Code | `Task` / `new_session` | 原生支持 |
| Antigravity | `invoke_subagent` + `send_message` | 可定义 subagent type |

**关键**：Chooser、Reviewer 与 Solver 的 {core_doc} 隔离在所有平台上统一通过 **Director 不在 prompt 中传入（并主动脱敏）** 来保证，不依赖平台权限机制。这确保了跨平台一致的行为。

> 各平台安装时的具体配置说明见 `references/install_notes.md`。
