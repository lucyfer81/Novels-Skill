#!/bin/bash
# interactive-novel skill 一键安装/同步脚本
# 将 skill-src/ 同步到各平台运行时目录（.opencode / .claude / .agents）
# 安装前自动执行题材耦合检查（lint），失败即中止
# 用法：bash scripts/install.sh [目标项目根目录]
#   不带参数 → 同步到本仓库根目录；带参数 → 同步到指定项目根目录（如安装到其他写作工作台）

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/.."
ROOT="$(cd "$SRC/.." && pwd)"
DEST_ROOT="${1:-$ROOT}"
DEST_ROOT="$(cd "$DEST_ROOT" && pwd)"
cd "$ROOT"

# 前置：题材耦合检查（共享文件必须题材中立，题材包必须完整）
echo "▶ 运行题材耦合检查..."
bash "$SCRIPT_DIR/lint_coupling.sh"
echo ""

TARGETS=(
  ".opencode/skills/interactive-novel"
  ".claude/skills/interactive-novel"
  ".agents/skills/interactive-novel"
)

for t in "${TARGETS[@]}"; do
  # 清理旧构建产物后整体同步（运行时目录均为构建产物；
  # 先删再拷，防止已移除/改名的源文件残留为过期副本）
  rm -rf "$DEST_ROOT/$t"
  mkdir -p "$DEST_ROOT/$t"
  cp -r "$SRC/." "$DEST_ROOT/$t/"
  echo "✅ 已同步: $DEST_ROOT/$t"
done

# OpenCode 专属：角色档位 agents（可选增强，仅 opencode 平台）
# novel-* 子代理定义绑定各角色的模型与思考档位（见 references/install_notes.md）
if [ -d "$SRC/platform/opencode/agents" ]; then
  mkdir -p "$DEST_ROOT/.opencode/agents"
  cp "$SRC"/platform/opencode/agents/novel-*.md "$DEST_ROOT/.opencode/agents/"
  echo "✅ 已部署 OpenCode 角色档位 agents: $DEST_ROOT/.opencode/agents/ (novel-writer / novel-writer-max / novel-chooser / novel-reviewer / novel-solver)"
fi

echo ""

# OpenCode: 检查 task 权限（自动写作模式依赖子任务机制）
if [ -f "$DEST_ROOT/.opencode/opencode.json" ]; then
  if ! grep -q '"task"' "$DEST_ROOT/.opencode/opencode.json"; then
    echo "⚠️  $DEST_ROOT/.opencode/opencode.json 未配置 task 权限，自动写作模式（/auto-write）需要子任务机制。"
    echo "    请在 opencode.json 的 permission 对象中添加："
    echo '        "task": "allow"'
  else
    echo "✅ $DEST_ROOT/.opencode/opencode.json 已配置 task 权限"
  fi
fi

echo ""
echo "安装完成（目标：$DEST_ROOT）。重启 opencode / claude / antigravity 会话后生效。"
