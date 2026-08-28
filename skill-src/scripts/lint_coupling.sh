#!/bin/bash
# 题材耦合检查（lint）
# 检查共享文件（核心协议）中是否出现具体题材内容——防止题材提示词回流核心文件。
# 白名单：references/genres/ 全目录（题材包、注册表、契约、脚手架）
# 附加校验：_registry.md 中登记的题材显示名必须出现在 SKILL.md description（路由触发关键词同步）
# 用法：bash skill-src/scripts/lint_coupling.sh
# 退出码：0 = 通过；1 = 发现耦合/失步

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$(cd "$SCRIPT_DIR/.." && pwd)"

PATTERN='mystery|romance|推理|爱情|言情|悬疑'
FAIL=0

report() { echo "❌ $1"; FAIL=1; }

# --- 1. SKILL.md 正文（剥离 frontmatter；description 保留题材关键词用于路由，白名单）---
BODY=$(awk '/^---$/{c++; next} c>=2' "$SRC/SKILL.md")
HITS=$(printf '%s\n' "$BODY" | grep -inE "$PATTERN" || true)
[ -n "$HITS" ] && { report "SKILL.md 正文出现题材内容（应移入题材包）:"; printf '%s\n' "$HITS" | sed 's/^/   /'; }

# --- 2. references 根层文件 ---
for f in "$SRC"/references/*.md; do
  HITS=$(grep -inE "$PATTERN" "$f" || true)
  [ -n "$HITS" ] && { report "$f 出现题材内容（应移入题材包）:"; printf '%s\n' "$HITS" | sed 's/^/   /'; }
done

# --- 3. scripts（本脚本自身除外）---
for f in "$SRC"/scripts/*.sh; do
  [ "$(basename "$f")" = "lint_coupling.sh" ] && continue
  HITS=$(grep -inE "$PATTERN" "$f" || true)
  [ -n "$HITS" ] && { report "$f 出现题材内容:"; printf '%s\n' "$HITS" | sed 's/^/   /'; }
done

# --- 4. 注册表 ↔ SKILL.md description 同步校验 ---
REGISTRY="$SRC/references/genres/_registry.md"
DESC=$(grep '^description:' "$SRC/SKILL.md" || true)
if [ -z "$DESC" ]; then
  report "SKILL.md 缺少 description"
else
  for display in $(awk -F'|' '/^\| *[0-9]/{gsub(/ /,"",$4); if ($4!="") print $4}' "$REGISTRY"); do
    case "$DESC" in
      *"$display"*) ;;
      *) report "注册表题材「$display」未出现在 SKILL.md description（路由触发关键词失步）" ;;
    esac
  done
fi

# --- 5. 题材包完整性：每个注册题材必须有 manifest + 5 文件 + templates ---
for genre in $(awk -F'|' '/^\| *[0-9]/{gsub(/ /,"",$3); if ($3!="") print $3}' "$REGISTRY"); do
  PACK="$SRC/references/genres/$genre"
  for req in manifest.md init.md personas.md craft.md hooks.md templates; do
    [ -e "$PACK/$req" ] || report "题材包 $genre 缺少 $req"
  done
  # manifest 必须声明全部槽位字段
  if [ -f "$PACK/manifest.md" ]; then
    for key in genre display core_doc signal_doc signal_term status_section sanitize_fields; do
      grep -q "^${key}:" "$PACK/manifest.md" || report "题材包 $genre 的 manifest 缺少字段 $key"
    done
  fi
done

if [ "$FAIL" -eq 0 ]; then
  echo "✅ 题材耦合检查通过：核心文件题材中立，题材包完整，注册表同步"
else
  echo ""
  echo "修复指引：题材内容移入 references/genres/{genre}/ 对应文件；核心协议改用槽位引用（见 genres/_SPEC.md 与 docs/genre-plugin-architecture.md）"
fi
exit $FAIL
