# 安装说明：自动写作模式

自动写作模式（`/auto-write` 与 `/auto-chapter`）需要宿主环境支持子任务/Subagent 机制。
以下是针对不同平台的安装与配置指南。

---

## 1. OpenCode

### 安装步骤
1. 将 `skill-src/` 整个目录的内容安装到项目根目录下的 `.opencode/skills/interactive-novel/`：
   ```bash
   mkdir -p .opencode/skills/interactive-novel
   cp -r skill-src/* .opencode/skills/interactive-novel/
   ```

2. 开启 `task` 工具调用权限：
   在 `.opencode/opencode.json` 中配置，确保 `permission.task` 处于 `"allow"` 状态（或未被全局 deny）：
   ```json
   {
     "$schema": "https://opencode.ai/config.json",
     "permission": {
       "task": "allow"
     }
   }
   ```

3. **Subagent 机制**：
   - Director（主 Agent）会在自动模式下自动调用 OpenCode 内置的 `task` 工具来派发 Writer 和 Chooser 独立子任务。
   - Chooser 的 `truth.md` / `relationship_arc.md` 隔离已在 Skill 的 Prompt 编排层面实现硬性隔离，无需手动配置复杂的 Agent 文件权限。

---

## 2. Claude Code

### 安装步骤
1. 将 `skill-src/` 目录复制到 `.claude/skills/interactive-novel/`：
   ```bash
   mkdir -p .claude/skills/interactive-novel
   cp -r skill-src/* .claude/skills/interactive-novel/
   ```

2. **Subagent 机制**：
   - Claude Code 原生支持基于 Task/Subagent 的子会话隔离机制，无需额外的权限配置文件即可直接使用 `/auto-write` 和 `/auto-chapter`。

---

## 3. Google Antigravity (Gemini)

### 安装步骤
1. 将 `skill-src/` 目录复制到 `.agents/skills/interactive-novel/`：
   ```bash
   mkdir -p .agents/skills/interactive-novel
   cp -r skill-src/* .agents/skills/interactive-novel/
   ```

2. **Subagent 机制**：
   - Antigravity 原生提供 `invoke_subagent` 与 `send_message` 工具，Director 会自动以子代理方式执行任务分发。

---

## 4. 架构设计总结

- **源码唯一性**：所有的业务逻辑、提示词宪法与协议模板均维护在 `skill-src/` 中。
- **跨平台一致性**：Skill 本身不耦合平台专有 API，只声明角色协议（Director / Writer / Chooser）与输入输出规范。
