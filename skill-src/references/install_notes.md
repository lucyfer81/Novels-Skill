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

自动写作模式需要 `task` 工具派发 Writer / Chooser / Reviewer 子任务。在 `.opencode/opencode.json` 中配置：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "task": "allow"
  }
}
```

### Subagent 机制

- Director（主 Agent）通过 OpenCode 内置的 `task` 工具派发子任务，调用时指定 `subagent_type: "general"`，角色定义（Writer/Chooser/Reviewer 身份 prompt）由 Director 写入子任务 prompt。
- Chooser 与 Reviewer 的 `truth.md` / `relationship_arc.md` 隔离在 Skill 的 Prompt 编排层面实现（Director 不传入 + 主动脱敏角色条目），无需手动配置 Agent 文件权限。
- 注意：OpenCode 会同时发现 `.opencode/`、`.claude/`、`.agents/` 三处目录中的同名 skill。**请只保留一份并保持同步**（install.sh 会同步全部三处），避免多副本内容不一致导致加载到旧版本。

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
- **四角色协议**：Director（编排核验）/ Writer（写正文，持真相）/ Chooser（选走向，无真相+读者记忆）/ Reviewer（每章审阅，无真相）。真实性隔离统一靠 Director 的 prompt 编排保证，跨平台一致。
- **跨平台一致性**：Skill 本身不耦合平台专有 API，只声明角色协议与输入输出规范（XML 标签协议），各平台宿主 Agent 自行映射子任务调用。
