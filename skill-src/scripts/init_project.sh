#!/bin/bash
# 小说项目初始化脚本（题材中立：题材与文件名由题材包 manifest 声明）
# 用法：bash init_project.sh <项目名> <genre> <language>
# 可用 genre 见 references/genres/_registry.md（默认取注册表首项）

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GENRES_DIR="$SRC_DIR/references/genres"
REGISTRY="$GENRES_DIR/_registry.md"

PROJECT_NAME="$1"
GENRE="$2"
LANGUAGE="${3:-zh}"

# 可用题材 = 注册表登记顺序
AVAILABLE_GENRES=$(awk -F'|' '/^\| *[0-9]/{gsub(/ /,"",$3); if ($3!="") print $3}' "$REGISTRY" | tr '\n' ' ')

if [ -z "$PROJECT_NAME" ]; then
    echo "错误：请提供项目名称"
    echo "用法：bash init_project.sh <项目名> <genre> <language>"
    echo "  genre:    ${AVAILABLE_GENRES}（见 references/genres/_registry.md，默认取首项）"
    echo "  language: zh | en（默认 zh）"
    exit 1
fi

# 默认题材 = 注册表首项
if [ -z "$GENRE" ]; then
    GENRE=$(echo "$AVAILABLE_GENRES" | awk '{print $1}')
fi

MANIFEST="$GENRES_DIR/$GENRE/manifest.md"
if [ ! -f "$MANIFEST" ]; then
    echo "错误：未知题材 '$GENRE'（manifest 缺失）。可用题材：$AVAILABLE_GENRES"
    exit 1
fi

# 从 manifest 解析槽位（核心设定文档 / 投放物地图）
CORE_DOC=$(sed -n 's/^core_doc:[[:space:]]*//p' "$MANIFEST" | head -n1 | tr -d '[:space:]')
SIGNAL_DOC=$(sed -n 's/^signal_doc:[[:space:]]*//p' "$MANIFEST" | head -n1 | tr -d '[:space:]')
if [ -z "$CORE_DOC" ] || [ -z "$SIGNAL_DOC" ]; then
    echo "错误：题材包 $GENRE 的 manifest 未声明 core_doc / signal_doc"
    exit 1
fi

# 创建项目目录（在当前项目根目录下的 novels/ 子目录）
PROJECT_ROOT="$(cd "$SRC_DIR/../.." && pwd)"
PROJECT_DIR="$PROJECT_ROOT/novels/$PROJECT_NAME"

if [ -d "$PROJECT_DIR" ]; then
    echo "警告：目录 $PROJECT_DIR 已存在"
    read -p "是否继续？(y/n): " confirm
    if [ "$confirm" != "y" ]; then
        exit 0
    fi
fi

mkdir -p "$PROJECT_DIR/meta"
mkdir -p "$PROJECT_DIR/drafts"

# 写入 project_info.md 基础头部（LLM 后续填充其余内容）
cat > "$PROJECT_DIR/meta/project_info.md" << EOF
genre: $GENRE
language: $LANGUAGE
EOF

touch "$PROJECT_DIR/meta/style_guide.md"
touch "$PROJECT_DIR/meta/outline.md"
touch "$PROJECT_DIR/meta/characters.md"
touch "$PROJECT_DIR/meta/session_log.md"
touch "$PROJECT_DIR/meta/$CORE_DOC"
touch "$PROJECT_DIR/meta/$SIGNAL_DOC"

echo ""
echo "✅ 项目目录已创建：$PROJECT_DIR"
echo ""
echo "目录结构："
echo "$PROJECT_DIR/"
echo "├── meta/"
echo "│   ├── project_info.md    （项目基本信息）"
echo "│   ├── style_guide.md     （风格宪法）"
echo "│   ├── outline.md         （章节大纲）"
echo "│   ├── characters.md      （角色档案）"
echo "│   ├── $CORE_DOC"
echo "│   ├── $SIGNAL_DOC"
echo "│   └── session_log.md     （章节摘要日志）"
echo "└── drafts/"
echo "    （章节文件将存放于此）"
echo ""
echo "项目路径：$PROJECT_DIR"
