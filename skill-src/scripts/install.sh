#!/bin/bash
# interactive-novel skill 一键安装/同步脚本
# 将 skill-src/ 同步到各平台运行时目录（.opencode / .claude / .agents）
# 用法：bash scripts/install.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/.."
ROOT="$(cd "$SRC/.." && pwd)"
cd "$ROOT"

TARGETS=(
  ".opencode/skills/interactive-novel"
  ".claude/skills/interactive-novel"
  ".agents/skills/interactive-novel"
)

for t in "${TARGETS[@]}"; do
  mkdir -p "$t"
  cp -r "$SRC/." "$t/"
  echo "✅ 已同步: $t"
done

echo ""

# OpenCode: 检查 task 权限（自动写作模式依赖子任务机制）
if [ -f .opencode/opencode.json ]; then
  if ! grep -q '"task"' .opencode/opencode.json; then
    echo "⚠️  .opencode/opencode.json 未配置 task 权限，自动写作模式（/auto-write）需要子任务机制。"
    echo "    请在 opencode.json 的 permission 对象中添加："
    echo '        "task": "allow"'
  else
    echo "✅ .opencode/opencode.json 已配置 task 权限"
  fi
fi

echo ""
echo "安装完成。重启 opencode / claude / antigravity 会话后生效。"
