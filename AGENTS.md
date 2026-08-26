# Workspace Rules & Permissions

## File Operations Policy

1. **Auto-Execution for Creation & Modification**:
   - For all file creation and modification operations within this workspace, proceed directly without asking for extra interactive approval in chat.
   
2. **Deletion & Destructive Operations**:
   - **Strictly Prohibited without Explicit Confirmation**: Any destructive operations that delete files or directories (such as `rm`, `unlink`, removing project files) MUST explicitly describe the impact and ask for user confirmation before executing.
