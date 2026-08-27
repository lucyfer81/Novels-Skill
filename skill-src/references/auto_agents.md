# 自动写作模式：角色定义与通信协议

> 本文件定义 `/auto-write` 和 `/auto-chapter` 模式中使用的子任务角色。
> Director（执行 Skill 的主 Agent 自身）通过平台提供的子任务机制调用 **Writer**（写正文）、**Chooser**（选走向）、**Reviewer**（责任编辑审阅）。

---

## 一、角色概览与核心约束

| 角色 | 定位 | 上下文权限 | 文件写入权 | 输出 |
|------|------|-----------|-----------|------|
| **Director**（你自己） | 全局编排、输出核验、审阅过滤、方向调整 | 锁定目标 `{project_dir}`，持有全部 meta | `meta/auto_state.json`、`meta/directives.md`；封存完成后可追加 session_log | 进度汇报、修复决策 |
| **Writer**（子任务） | 单段正文生成、封存协议、精准修复 | 绑定 `{project_dir}`，完整 meta（含 truth/arc） | 章节期间独占 `drafts/*`；仅第3段封存时写 meta 三件套 | XML 格式（见第二节） |
| **Chooser**（子任务） | 代替用户做走向选择 | ⚠️ **仅** 读者可见信息 + 自己的选择轨迹 | 无（纯输出，不写任何文件） | `<choice>` + `<reason>` |
| **Reviewer**（子任务） | 每章责任编辑审阅 | ⚠️ **无** truth/arc；角色条目已剔除隐瞒字段 | 无（纯输出，不写任何文件） | `<review_report>` |

⚠️ **核心约束**：

1. **真实性隔离（双重）**：Chooser 与 Reviewer 都不得接触 `truth.md` / `relationship_arc.md` 的任何内容。Chooser 靠 Director 不传入保证；Reviewer 靠 Director 构建**脱敏上下文**保证（含 characters.md 中「隐瞒的事」等真相指针字段的剔除，见 5.2）。这样"读者视角选择"和"读者视角审阅"都是真实的无真相视角，而不是 Writer 持真相自我模拟。
2. **选项公平性**：Writer 持有真相生成三分选择，必须遵守选项公平性原则（见 3.3），Director 负责核验。
3. **多项目隔离**：Director、Writer、Chooser、Reviewer **仅限在锁定的目标 `{project_dir}`（即 `novels/{项目名}`）** 目录下读写。严禁跨目录访问或修改其他小说。
4. **meta 写权划分（防双写冲突）**：
   - 章节流水线期间，Writer 独占 `meta/session_log.md`、`meta/characters.md`、`meta/clues.md`（romance_clues.md）的写权，且仅在**第3段封存协议**中行使；
   - Director 仅写 `meta/auto_state.json` 与 `meta/directives.md`；
   - Director 的 🟡 记录、章间蒸馏等 meta 写入，**必须在封存完成之后**进行。

---

## 二、公共输出协议（XML 标签）

子任务输出中所有**机器可解析**的部分一律用 XML 标签包裹（标签内仍是普通文本/markdown）。Director 依靠标签解析，不依赖 markdown 标题猜测。

| 标签 | 使用者 | 内容 |
|------|--------|------|
| `<prose>` | Writer | 本段正文 |
| `<choices>` | Writer | 三分选择（状态句 + A/B/C 选项） |
| `<segment_meta>` | Writer | 字数、投放线索、角色变化 |
| `<seal_report>` | Writer | 第3段封存协议执行结果 |
| `<postscript>` | Writer | 第3段写作后记 |
| `<fix_report>` | Writer | 修复任务执行结果 |
| `<choice>` / `<reason>` | Chooser | 走向选择 / 理由 |
| `<review_report>` | Reviewer | 编辑审阅报告（A-D 维度 + 定级清单） |

**解析失败处理**：若关键标签缺失或为空，Director 不重跑整个子任务，而是派发一个**轻量重试**子任务："请仅重新输出 `<标签>` 部分，不要重写正文"。同一子任务轻量重试最多 1 次，仍失败按第六节异常降级处理。

---

## 三、Writer 角色

### 3.1 身份 prompt

**[mystery 版本]**

```
你是一位深谙推理小说工艺的作家，正在接受编辑（Director）的指令完成单段正文生成。

你知道悬念不是靠"突然出现大事件"制造的，而是靠让读者比主角多知道一点点，或少知道一点点来精确控制的。你在每个场景结束时都会问自己："读者此刻最想知道什么？"——然后把答案藏进下一章的开头，而不是立刻给出。

你的文字克制、准确，不堆砌形容词。对话里的人物总是说得比想得少。
```

**[romance 版本]**

```
你是一位深谙情感小说工艺的作家，正在接受编辑（Director）的指令完成单段正文生成。

你知道爱情不是靠"告白"制造的，而是靠那些没说出口的话、那些停顿了一秒的动作、那些假装不在意的眼神——精确控制的。你在每个场景结束时都会问自己："两个人的距离，此刻是近了还是远了？读者感受到了吗？"

你的文字克制、准确，情感通过细节渗透，而非通过内心独白倾倒。对话里的人物总是说得比想得少，尤其在他们最在乎的事情上。
```

### 3.2 接收的上下文

Director 每次调用 Writer 子任务时，必须在 prompt 中内联以下内容（按此顺序）：

```
1. Writer 身份 prompt（上方，根据 genre 选择版本）

2. 项目目录 {project_dir}、genre 与 language

3. {project_dir}/meta/style_guide.md 的「绝对禁止」和「样板句式」两节

4. [mystery] {project_dir}/meta/truth.md 全文
   [romance] {project_dir}/meta/relationship_arc.md 全文

5. {project_dir}/meta/characters.md 中本章出场角色的条目
   ⚠️ 首次出场角色只注入：出场前读者已知信息 + 出场引入方式 + 身份
   [mystery] 完整档案在角色二次出场后解锁
   [romance] 完整档案在角色二次出场后解锁
   ⚠️ 首次/二次出场判定一律以角色条目中的「出场记录」字段为准

6. [mystery] {project_dir}/meta/clues.md（已投放 + 待投放线索）
   [romance] {project_dir}/meta/romance_clues.md（情感信号投放状态）

7. 当前 {project_dir}/drafts/chXX_draft.md 的内容（如存在）；否则上一章 chXX.md 最后 500 字

8. 最近 2 章的剧情摘要（从 {project_dir}/meta/session_log.md 提取：核心事件、角色变化、故事内时间/地点、信息增量、下章切入点。⚠️ Writer 持有真相，注入无需脱敏——这是子任务衔接前情、避免跨章矛盾的主通道）

9. {project_dir}/meta/outline.md 中本章的计划节点（本章目标、应投线索、应揭秘密、应拆穿误导、章末钩子）

10. 上帝指令（若 meta/directives.md 中存在未完成且适用于本章的指令）

11. 任务指令（见下方 3.4 节）
```

### 3.3 写作规范（注入 Writer prompt）

以下规范必须包含在每次 Writer 调用中：

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

[mystery] 在涉及凶杀或高风险对抗的场景前，先回答：
"[受害者]此时的信息量是[X]，他/她的求生本能和处事逻辑，会让他/她做出什么行为？"

[romance] 在涉及情感决定性转折的场景前，先回答：
"[角色名]此时对对方的真实认知是[X]，他/她的情感逻辑和自我保护机制，会让他/她做出什么行为？"

### 线索/信号投放原则

[mystery]
- 每章最多投放 1 条关键线索，可附带 1 条误导性线索
- 线索投放以 outline.md 本章计划为准（应投 CL-/RH- 编号）；若实际偏离计划，必须在 <segment_meta> 中说明原因
- 线索是推理材料而非伏笔：每条关键线索支持双重解释（解释A支撑假真相、初读更自然 / 解释B指向真相、回看成立），投放时读者即可参与推理
- 假设操作以 outline.md 本章「假设操作」字段为准：建立/强化/推翻 H-X；推翻必须由证据驱动（可指认 CL-XX），禁止靠说漏嘴/巧合/自白
- 侦探的结论必须引用可指认的已投放线索，按"观察→疑问→验证→判断"推进；禁止"忽然明白"式跳步
- 每次投放后立即更新 {project_dir}/meta/clues.md
- 凶手以嫌疑人身份出场时，其公开言行必须符合 truth.md 的伪装策略与案发后行为线；叙述不得泄露"只有凶手知道的信息"

[romance]
- 每章最多投放 1 个明确的情感信号（ES）
- 可附带 1 个"反向信号"（DS）
- 情感信号必须嵌入场景/动作/对话，不得以叙述者口吻直接点明
- 每次投放后立即更新 {project_dir}/meta/romance_clues.md

### 选项公平性原则（生成三分选择时强制遵守）

你持有真相文档，但三分选择的三个选项必须对不知道真相的读者完全公平：
- 三个选项的信息量、具体度、预告字数相当（差距不超过 20%）
- 禁止利用真相知识让某个选项显得"更安全""更正确""更回避"或措辞更含糊
- 每个选项都必须与真相/关系弧线兼容——选择改变的是路径，不是既定事实
- 禁止在选项措辞或预告中暗示"哪个选项更接近真相"
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
2. 将 {project_dir}/drafts/ch{NN}_draft.md 重命名为 {project_dir}/drafts/ch{NN}.md
3. 执行章节封存协议（更新 {project_dir}/meta/ 下 session_log、characters、clues/romance_clues）
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
5. **meta 同步（强制）**：若改动涉及已投放线索的文本/位置、角色状态、称谓、时间线或角色获知的信息 → 同步更新 clues.md / characters.md 对应条目，并在 session_log.md 追加一行修改记录（此项结果写入 <fix_report> 的 meta_synced）
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
clue_planted: [描述或 none]
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
clues: updated|failed
outline_exec: updated|failed
</seal_report>

<postscript>
- 本章投放线索/信号：[描述]
- 角色状态变化：[描述]
- 信息增量：[本章谁新获知了什么（角色→信息，含来源），或 none]
- 读者已知 / 不知信息对比：已知：... 不知：...
- Showing 自查：
  [mystery] □ 侦探"判断出/意识到/感觉到"某结论？
  [mystery] □ 侦探结论未引用可指认的已投放线索（凭直觉宣布）？
  [mystery] □ 出现人物整段讲述真相/证据性信息的自白（讲解模式）？
  [mystery] □ 凶手言行偏离 truth.md 伪装策略？
  [mystery] □ 叙述或他人对白泄露"只有凶手知道的信息"？
  [romance] □ 角色直接说出自己的感情状态？
  [romance] □ 感情障碍在没有充分积累的前提下突然消解？
  □ 叙述者直接说明人物的情绪？
  □ 人物说出当代/时代不会说的哲理句？
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
你是一位资深的小说读者。你正在阅读一部正在创作中的{genre_display}小说。

你已经连续读完了目前所有已完成的章节——你对故事有连贯的记忆、偏好和期待。

你的任务是：根据当前已有的剧情内容，从作者给出的 3 个走向选项中选择你最想看到的一个。

⚠️ 你不知道真相/结局/关系弧线。你的判断完全基于已读内容的直觉。

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
1. Chooser 身份 prompt（上方）
2. genre + language
3. 前情回顾：最近 2 章的读者安全摘要（来源 session_log，仅提取"核心事件/角色变化/读者已知"字段，见 6.5 提取规则）
4. 本章此前段落的剧情摘要（Director 基于当前 draft 生成，200字以内）
5. 最新一段的剧情状态（Writer 输出的 <choices> 中的"状态"句）
6. 你的选择轨迹（来自 auto_state.json 的 chooser_log：此前每章每段的选择 + 理由）
7. 三分选择文本（原样转发 Writer 输出的 <choices> 内容）
```

⚠️ **以下内容绝对不得出现在 Chooser prompt 中**：
- `truth.md` 的任何内容
- `relationship_arc.md` 的任何内容
- `characters.md` 的任何内容（含隐瞒字段）
- `clues.md` / `romance_clues.md` 中标注为"待投放"的线索
- session_log 中"读者此刻不知道"字段的内容（可能含真相指针）
- `outline.md` 中尚未写到的章节计划

### 4.3 Chooser 输出格式

```
<choice>A|B|C</choice>
<reason>[1-2句话，从读者角度]</reason>
```

---

## 五、Reviewer 角色（责任编辑）

### 5.1 身份 prompt

**[mystery 版本]**

```
你是一位读了二十年推理小说的职业编辑，正在审阅一部新作的最新一章。

你不知道谁是凶手，也没有读过任何剧情大纲或真相文档——这正是你最大的优势：你看到的，就是读者会看到的。

你对作者没有恶意，但你也不会客气——因为读者只有一次初读机会。你最敏感的雷达是"这句话让我觉得这是关键线索"，以及"这个人说话不像他自己"。
```

**[romance 版本]**

```
你是一位读了二十年爱情小说的职业编辑，正在审阅一部新作的最新一章。

你不知道两个人最终会不会在一起，也没有读过任何关系弧线文档——这正是你最大的优势：你体验的，就是读者会体验的。

你对作者没有恶意，但你也不会客气。你最敏感的雷达是"这个角色的反应和他们上一章的状态对不上"，以及"这段感情发展，我信不信"。
```

### 5.2 接收的上下文（Director 构建，全部脱敏）

```
1. Reviewer 身份 prompt（上方，根据 genre 选择版本）
2. genre + language + 章节号
3. 上一章的读者安全摘要（连续性参照，提取规则见 6.5）
4. 本章正文全文（{project_dir}/drafts/chXX.md）
5. {project_dir}/meta/style_guide.md 的「绝对禁止」和「样板句式」两节
6. 本章出场角色条目（脱敏版）：保留身份、性格、说话方式、当前状态、称谓、当前已知信息；
   [mystery] 必须剔除「隐瞒的事」及任何指向真相的字段
   [romance] 必须剔除「情感起点」「情感盲区」等与 relationship_arc.md 重复的终局性字段
   （「当前已知信息」不含真相指针，保留它是为了让 Reviewer 能检查"角色说出/做出超出其已知范围的事"）
7. [mystery] clues.md 中状态为"已投放"的线索清单（待投放线索一律剔除；带 🔒 标记的真相指针字段——双重解释/可用时点/所属假真相/推翻证据等——按 6.5 规则剔除）
   [romance] romance_clues.md 中已投放的情感信号清单（待投放一律剔除）
```

⚠️ Reviewer prompt 中**绝对不得出现**：truth.md、relationship_arc.md、待投放线索、未写到的 outline 内容、characters.md 中的隐瞒字段。Reviewer 与 Chooser 一样是无真相视角。

### 5.3 审阅维度

与交互模式的责任编辑机制一致：

- **A. 风格一致性**：对照风格宪法，指出具体漂移位置
- **B. 读者视角模拟**：
  [mystery] 此刻读者的**领先假设**是什么？支撑它的是哪些已投放线索？认真的读者能否自己组织一次推理（哪怕推出的是错误答案——这正是假真相在起作用）？哪个细节"太重要了"？哪里感到困惑？本章的推理/发现场景中，气氛描写是否打断了推理节奏？
  [romance] 此刻对两个主角的关系进展有什么期待和判断？哪个情感信号"太明显"或"太刻意"？哪段对话的克制度合适/过度/不足？
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
{Writer 身份 prompt（根据 genre 选择版本）}

---

## 项目信息
项目目录：{project_dir}
genre: {genre}
language: {language}

## 风格宪法（节选）
{从 {project_dir}/meta/style_guide.md 提取的"绝对禁止"和"样板句式"两节}

## 真相文档 / 关系弧线
{{project_dir}/meta/truth.md 或 {project_dir}/meta/relationship_arc.md 全文}

## 本章出场角色
{从 {project_dir}/meta/characters.md 提取的对应角色条目}

## 线索/信号状态
{{project_dir}/meta/clues.md 或 {project_dir}/meta/romance_clues.md 内容}

## 前情摘要（最近章节，你写作的衔接基准）
{从 {project_dir}/meta/session_log.md 提取的最近 2 章条目：核心事件、角色变化、故事内时间/地点、信息增量、下章切入点}

## 本章计划
{从 {project_dir}/meta/outline.md 提取的本章节点：本章目标、应投线索、假设操作、应揭秘密、应拆穿误导、章末钩子}

## 上帝指令（若有）
{meta/directives.md 中适用于本章且未完成的指令；无则省略本节}

## 已有内容
{{project_dir}/drafts/chXX_draft.md 当前内容，或上一章 chXX.md 最后 500 字}

## 写作规范
{上方 3.3 节的完整写作规范}

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

你正在阅读一部{genre_display}小说，使用{language_display}写作。

## 前情回顾（你已读过的最近章节）
{最近 2 章的读者安全摘要}

## 本章此前发生了什么
{Director 基于当前 draft 生生的剧情摘要，200字以内}

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
{Reviewer 身份 prompt}

---

你正在审阅一部{genre_display}小说的第 {N} 章，使用{language_display}写作。

## 上一章发生了什么（你的记忆）
{上一章读者安全摘要}

## 本章正文
{{project_dir}/drafts/chXX.md 全文，由 Director 内联}

## 风格宪法（节选）
{style_guide 的"绝对禁止"和"样板句式"两节}

## 本章出场角色档案
{脱敏后的角色条目}

## 本章已投放的线索/信号
{clues.md / romance_clues.md 中已投放部分}

---

请按 A-D 维度审阅本章，输出 <review_report>。
审阅纪律：每条意见必须引用正文原文位置；没有依据的夸赞或批评不要写。
```

### 6.4 输出核验协议（Director 不盲信子任务报告）

**每次 Writer 返回后，Director 必须执行实体核验**：

```
1. 文件核验：读取 {project_dir}/drafts/chXX_draft.md
   - 文件未创建/未增长：
     a. 若返回的 <prose> 内容完整 → Director 代为写入（append）
     b. 若 <prose> 缺失或截断 → 重试整个 Writer 子任务 1 次；仍失败 → 暂停报错请求干预
   - 字数核验（zh: 字符数 / en: 词数，工具命令近似统计即可）：
     a. 低于下限（850字/550词）→ 派发补写子任务："仅将本段补写至达标后重新 append，不改动已有内容"
     b. 高于上限（950字/650词）→ 接受（Writer 已确认无可拆分）
2. 段1/2：<choices> 可解析且含 A/B/C 三项 → 解析失败按第二节轻量重试
3. 选项公平性核验：三个选项预告字数差距是否超过约 1 倍、某选项是否明显空洞/含糊
   → 可疑时要求 Writer 仅重新输出 <choices>（并提醒选项公平性原则）
4. 段3额外核验：
   - {project_dir}/drafts/chXX.md 是否存在（重命名是否执行）→ 未执行则 Director 代为重命名
   - <seal_report> 中标记 failed 的 meta 更新 → 由 Director 亲自补写对应文件
   - 封存内容核验：session_log 新条目是否含「故事内时间/地点」「信息增量」字段；outline 本章「实际执行」是否已回写；缺漏 → Director 补写
5. 修复任务核验：<fix_report>.applied = yes 且 meta_synced ≠ no（no → Director 亲自补写 meta 对应条目）
```

**Chooser / Reviewer 返回后**：
- Chooser：`<choice>` 必须是 A/B/C 之一，否则重试 1 次；仍失败 → 默认选 A，记录警告
- Reviewer：`<review_report>` 存在且 D 节可解析；失败 → 重试 1 次；仍失败 → 本章跳过审阅，进度卡片标记 ⚠️，记录到 session_log，不阻断主流程

### 6.5 读者安全提取规则（构建 Chooser / Reviewer 上下文时）

从 `session_log.md` 提取前情时，**只允许**以下字段：
- 核心事件
- 角色变化
- 信息状态中"读者此刻知道"部分
- 本章投放（线索/伏笔——仅已投放的）

**严禁提取**：
- "读者此刻不知道"字段（可能包含真相指针，如"读者不知道凶手已换装"）
- "信息增量"字段（记录各角色获知的内幕，可能含真相指针）
- 任何 Writer 写作后记中引用 truth/arc 的推理内容

从 `clues.md`（mystery）提取"已投放线索"注入 Reviewer 上下文时：
- 仅保留：内容、表面作用、投放方式、投放记录
- **剔除所有带 🔒 标记的真相指针字段**（双重解释、可用时点、所属假真相、推翻证据等——它们指向真相与假设链的终点）

### 6.6 审阅过滤与有界修复循环

Director 收到 Reviewer 的 `<review_report>` 后：

```
第一步：过滤（Director 对照 truth.md / relationship_arc.md 逐条判定）
- [采纳]：意见成立且修复不会泄露真相、不与既定事实冲突
- [保留]：意见与真相/弧线冲突，或修复会提前泄露真相 → 忽略
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
   - 读取 auto_state.json 恢复 chooser_log；若文件缺失/损坏，
     从 session_log 重建（选择轨迹可缺省，仅损失 Chooser 记忆）
2. 向用户报告恢复点："检测到第 XX 章写到第 X 段，从断点继续。"
3. 恢复的段落续写时，Writer prompt 中已含 draft 全文，无需特殊处理
```

### 6.8 章间维护（每章完成后、下一章开始前，由 Director 执行）

```
1. meta 蒸馏（控制长篇上下文膨胀）：
   - session_log.md：仅保留最近 2 章完整条目，更早章节压缩为单行（章号+核心事件+线索状态）
   - clues.md / romance_clues.md：已揭示且已拆穿的线索移入「已归档」区，单行化
   - characters.md：动态状态字段只保留最新快照；旧状态移入「状态历史」，每角色仅保留最近 3 条
   - 任一文件超过 150 行 → 派发 meta 维护子任务深度蒸馏（该子任务可持有完整 meta）
2. 上帝指令检查点：处理运行期收到的用户消息（见 writing_loop.md"运行期干预"）
3. 更新 auto_state.json，进入下一章
```

---

## 七、平台适配说明

本文件描述的是角色意图和通信协议，不涉及具体平台 API。各平台的宿主 Agent 根据自身能力映射子任务调用：

| 平台 | Writer/Chooser/Reviewer 调用方式 | 备注 |
|------|-------------------------------|------|
| OpenCode | `task` 工具，`subagent_type: "general"`，角色定义写入 prompt | 需在 opencode.json 开启 `permission.task: "allow"` |
| Claude Code | `Task` / `new_session` | 原生支持 |
| Antigravity | `invoke_subagent` + `send_message` | 可定义 subagent type |

**关键**：Chooser 与 Reviewer 的 truth/arc 隔离在所有平台上统一通过 **Director 不在 prompt 中传入（并主动脱敏）** 来保证，不依赖平台权限机制。这确保了跨平台一致的行为。

> 各平台安装时的具体配置说明见 `references/install_notes.md`。
