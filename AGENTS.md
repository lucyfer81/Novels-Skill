# Workspace Rules & Permissions

## File Operations Policy

1. **Auto-Execution for Creation & Modification**:
   - For all file creation and modification operations within this workspace, proceed directly without asking for extra interactive approval in chat.
   
2. **Deletion & Destructive Operations**:
   - **Strictly Prohibited without Explicit Confirmation**: Any destructive operations that delete files or directories (such as `rm`, `unlink`, removing project files) MUST explicitly describe the impact and ask for user confirmation before executing.

## Skill Source (skill-src/) Modification Rules

1. **修改后必须 lint**：任何对 `skill-src/` 的修改，完成后必须运行 `bash skill-src/scripts/lint_coupling.sh`，通过后方可执行 `install.sh` 同步（install.sh 也会前置调用 lint 拦截）。
2. **题材内容只进题材包**：共享文件（SKILL.md 正文、`references/` 根层文件、`scripts/`）严禁出现具体题材内容（题材词或题材专属行为定义）。题材相关提示词一律放入 `skill-src/references/genres/{genre}/` 题材包，核心协议通过抽象槽位（`{core_doc}` / `{signal_doc}`）与 manifest 引用题材包。
3. **接口契约**：新增/修改题材包须符合 `skill-src/references/genres/_SPEC.md`；架构设计见 `docs/genre-plugin-architecture.md`。
4. **注册同步**：新增题材须在 `references/genres/_registry.md` 登记，并将题材显示名加入 SKILL.md frontmatter description（lint 会校验两者一致）。
