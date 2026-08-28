#!/bin/bash
# interactive-novel skill 一键安装/同步脚本
# 将 skill-src/ 同步到各平台运行时目录（.opencode / .claude / .agents）
# 安装前自动执行题材耦合检查（lint），失败即中止
# 用法：bash scripts/install.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/.."
ROOT="$(cd "$SRC/.." && pwd)"
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
  # 清理旧构建产物后整体同步（运行时目录均为 gitignore 的构建产物；
  # 先删再拷，防止已移除/改名的源文件残留为过期副本）
  rm -rf "$t"
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
