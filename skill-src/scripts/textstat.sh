#!/bin/bash
# 正文统计（题材中立）：统一字数口径
# zh: 统计汉字字符数；en: 统计英文词数；均排除标题行与空行
# 用法: bash textstat.sh <文件>
# 输出: zh_chars / en_words 两行计数（调用方自行对照容差阈值）

set -u

FILE="$1"

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    echo "错误：文件不存在或未提供（用法: bash textstat.sh <文件>）" >&2
    exit 1
fi

BODY=$(grep -v '^#' "$FILE" | grep -v '^[[:space:]]*$')

ZH_CHARS=$(printf '%s\n' "$BODY" | grep -oP '[\x{4e00}-\x{9fff}]' 2>/dev/null | wc -l)
EN_WORDS=$(printf '%s\n' "$BODY" | grep -oP "[A-Za-z]+(?:['-][A-Za-z]+)*" 2>/dev/null | wc -l)

echo "zh_chars: $ZH_CHARS"
echo "en_words: $EN_WORDS"
