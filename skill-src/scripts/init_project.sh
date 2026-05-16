#!/bin/bash
# 小说项目初始化脚本
# 用法：bash init_project.sh <项目名> <genre> <language>
# 例：bash init_project.sh 白月光 romance zh
#     bash init_project.sh TheLastClue mystery en

PROJECT_NAME="$1"
GENRE="${2:-mystery}"
LANGUAGE="${3:-zh}"

if [ -z "$PROJECT_NAME" ]; then
    echo "错误：请提供项目名称"
    echo "用法：bash init_project.sh <项目名> <genre> <language>"
    echo "  genre:    mystery | romance（默认 mystery）"
    echo "  language: zh | en（默认 zh）"
    exit 1
fi

# 创建项目目录（在当前项目根目录下的 novels/ 子目录）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
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

# 按 genre 创建专属文件
if [ "$GENRE" = "mystery" ]; then
    touch "$PROJECT_DIR/meta/truth.md"
    touch "$PROJECT_DIR/meta/clues.md"
elif [ "$GENRE" = "romance" ]; then
    touch "$PROJECT_DIR/meta/relationship_arc.md"
    touch "$PROJECT_DIR/meta/romance_clues.md"
fi

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

if [ "$GENRE" = "mystery" ]; then
    echo "│   ├── truth.md           （真相文档）"
    echo "│   └── clues.md           （线索地图）"
elif [ "$GENRE" = "romance" ]; then
    echo "│   ├── relationship_arc.md （关系弧线文档）"
    echo "│   └── romance_clues.md    （情感信号地图）"
fi

echo "│   └── session_log.md     （章节摘要日志）"
echo "└── drafts/"
echo "    （章节文件将存放于此）"
echo ""
echo "项目路径：$PROJECT_DIR"
