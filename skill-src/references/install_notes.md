# 安装说明：自动写作模式

自动写作模式（`/auto-write` 与 `/auto-chapter`）需要宿主环境支持子任务/Subagent 机制。
以下是针对不同平台的安装与配置指南。

> **一键安装**：在仓库根目录执行 `bash skill-src/scripts/install.sh`，自动将 skill-src 同步到下方三个平台目录。

---

## 1. OpenCode

### 安装步骤

**方式A（推荐）：一键脚本**
```bash
bash skill-src/scripts/install.sh
```

**方式B：手动复制**
```bash
mkdir -p .opencode/skills/interactive-novel
cp -r skill-src/* .opencode/skills/interactive-novel/
```

### 配置子任务权限

自动写作模式需要 `task` 工具派发 Writer / Reviewer 子任务（Chooser 为可选策略、Solver 按需触发）。在 `.opencode/opencode.json` 中配置：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "task": "allow"
  }
}
```

### Subagent 机制

- Director（主 Agent）通过 OpenCode 内置的 `task` 工具派发子任务。推荐使用 install.sh 自动部署的 `novel-*` 角色 agents（见下方"角色档位 agents"）；未部署时回退 `subagent_type: "general"`，角色定义（Writer/Chooser/Reviewer 身份 prompt）由 Director 写入子任务 prompt。
- Chooser 与 Reviewer 的核心设定文档（`{core_doc}`）隔离在 Skill 的 Prompt 编排层面实现（Director 不传入 + 主动脱敏角色条目），无需手动配置 Agent 文件权限。
- 注意：OpenCode 会同时发现 `.opencode/`、`.claude/`、`.agents/` 三处目录中的同名 skill。**请只保留一份并保持同步**（install.sh 会同步全部三处），避免多副本内容不一致导致加载到旧版本。

### 角色档位 agents（可选增强，仅 OpenCode 平台）

install.sh 会把 `skill-src/platform/opencode/agents/` 下的 `novel-*.md` 部署到 `.opencode/agents/`，为四个子任务角色绑定各自的模型与思考档位（调度规则见 `references/auto_agents.md` 第七节）：

| agent | 模型 | 思考档 | 温度 | 用途 |
|-------|------|--------|------|------|
| `novel-writer` | zhipuai-coding-plan/glm-5.3 | high | 0.7 | Writer 常规章节 |
| `novel-writer-max` | zhipuai-coding-plan/glm-5.3 | max | 0.7 | Writer 收敛/揭示/终局章（深档变体） |
| `novel-chooser` | zhipuai-coding-plan/glm-5.3-flash | low | 0.8 | Chooser 读者直觉选择（仅模拟读者策略启用时调用） |
| `novel-reviewer` | zhipuai-coding-plan/glm-5.3 | high | 0.2 | Reviewer 责任编辑审阅 |
| `novel-solver` | zhipuai-coding-plan/glm-5.3-flash | high | 0.4 | Solver 挑战读者测试 |

说明与自定义：

- **思考档实现**：`reasoningEffort` 为透传参数（agent 配置的 Additional 字段直通 provider）。opencode 对 zhipuai 系 provider 会自动注入 `thinking: {type: "enabled"}`；`reasoningEffort` 在其上叠加档位（实测 opencode 1.18.25 透传无报错）。若你的 endpoint 不支持档位参数，删掉该行即可——行为退化为默认思考，无副作用。
- **换模型/供应商**：改 agent 文件里的 `model:` 为你的 `provider/model-id`（`opencode models` 可查）。旗舰/轻量的划分建议保留：Writer/Reviewer 用旗舰，Chooser/Solver 可用轻量。
- **不部署的行为**：删除这些文件后 Director 回退 `general` 子任务，全部角色使用主会话模型——协议行为完全不变，只是没有档位区分。
- 这些 agent 均为 `hidden: true`（不出现在 @ 补全菜单，仅由 Director 经 task 工具调用）。

---

## 2. Claude Code

### 安装步骤

**方式A（推荐）：一键脚本**
```bash
bash skill-src/scripts/install.sh
```

**方式B：手动复制**
```bash
mkdir -p .claude/skills/interactive-novel
cp -r skill-src/* .claude/skills/interactive-novel/
```

### Subagent 机制

- Claude Code 原生支持基于 Task/Subagent 的子会话隔离机制，无需额外的权限配置文件即可直接使用 `/auto-write` 和 `/auto-chapter`。

---

## 3. Google Antigravity (Gemini)

### 安装步骤

**方式A（推荐）：一键脚本**
```bash
bash skill-src/scripts/install.sh
```

**方式B：手动复制**
```bash
mkdir -p .agents/skills/interactive-novel
cp -r skill-src/* .agents/skills/interactive-novel/
```

### Subagent 机制

- Antigravity 原生提供 `invoke_subagent` 与 `send_message` 工具，Director 会自动以子代理方式执行任务分发。

---

## 4. 架构设计总结

- **源码唯一性**：所有的业务逻辑、提示词宪法与协议模板均维护在 `skill-src/` 中，运行时目录（`.opencode/`、`.claude/`、`.agents/`）均为构建产物，已加入 .gitignore。修改一律改 `skill-src/`，然后运行 `install.sh` 重新同步。
- **确定性脚本**：`scripts/textstat.sh`（统一字数口径）与 `scripts/chapter_tools.sh`（verify-draft / verify-delta / check-id / commit / verify-commits / merge / migrate / usage）承担自动流水线中一切结构化核验、版本化提交与合稿；commits.json / usage.log 只经脚本写入。
- **题材包插件化**：题材差异（人格、初始化问题、工艺、钩子、模板）全部封装在 `references/genres/{genre}/` 题材包中；核心协议题材中立，通过抽象槽位（`{core_doc}` / `{signal_doc}`）与 manifest 引用题材包。接口契约见 `references/genres/_SPEC.md`；`install.sh` 安装前会运行 `scripts/lint_coupling.sh` 拦截核心文件的题材耦合回归。
- **角色协议**：Director（编排与脚本化核验）/ Writer（整章正文生成，持核心设定）/ Reviewer（每章审阅，无真相）/ Solver（按需：挑战读者测试）；Chooser 为可选模拟读者策略（默认关闭）。真实性隔离统一靠 Director 的 prompt 编排保证，跨平台一致。
- **跨平台一致性**：Skill 本身不耦合平台专有 API，只声明角色协议与输入输出规范（XML 标签协议），各平台宿主 Agent 自行映射子任务调用。
