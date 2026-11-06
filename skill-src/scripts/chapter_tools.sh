#!/bin/bash
# chapter_tools.sh —— 自动写作流水线确定性工具（题材中立）
# 职责：文件存在性 / 哈希 / delta 必要字段 / 编号唯一性 / 版本化提交 / 重复提交检查 /
#       按已提交章节排序合稿 / 旧项目一次性迁移 / usage 追加记录
# 题材语义（编号模式、触发规则等）不在本脚本硬编码，由调用方协议层提供。
#
# 用法：bash chapter_tools.sh <子命令> <项目目录> [参数...]
#   init <dir>                              初始化 pending/history/usage.log/commits.json（幂等）
#   status <dir>                            概览短输出（phase/版本/提交/待审 delta/残留）
#   verify-draft <dir> <NN>                 章节文件核验：存在性/draft 残留/字数/编号泄漏/hash
#   verify-delta <dir> <NN>                 delta 核验：必要字段/base_revision/prose_hash 绑定
#   check-id <dir> <signal_doc> <ID>        编号结构化检索（出现次数/条目标题数/行号——同物不同物由调用方判定）
#   commit <dir> <NN> --meta-files a.md,b.md [--no-delta] [--note TXT]
#                                           幂等提交登记：同章同 hash 重跑为 no-op；hash 变化为重提交（替换条目）
#   verify-commits <dir>                    全部提交条目与磁盘正文 hash 一致性（漂移检测）
#   merge <dir> <out.md>                    按已提交章节排序合稿（逐章 hash 校验，漂移即失败）
#   migrate <dir> [--signal-doc NAME] [--force]
#                                           旧项目一次性迁移：重建 commits.json 检查点 + 必要字段检查
#   usage <dir> key=value ...               追加一行 JSONL 运行记录到 meta/usage.log
#
# 退出码：0 = 通过 / 幂等完成；1 = 错误；2 = draft 残留（应派续写恢复）；
#         3 = 版本不匹配（delta 过期，应重新对齐/重新生成）

set -u

usage_help() {
    sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
}

die() { echo "错误：$1" >&2; exit 1; }

# ---------- 通用辅助 ----------

now_ts() { date +%Y-%m-%dT%H:%M:%S; }

hash_file() { # $1=文件 → stdout: sha256 hex
    [ -f "$1" ] || die "无法计算哈希：文件不存在 $1"
    sha256sum "$1" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$1" | cut -d' ' -f1
}

num_pat='^[0-9]+$'
file_pat='^[A-Za-z0-9_-]+\.md$'

check_nn() { # $1=数字或 chNN
    local raw="$1"
    N_NUM="${raw#ch}"
    echo "$N_NUM" | grep -qE "$num_pat" || die "章节号须为数字或 chNN 格式：$raw"
    [ "$N_NUM" -le 9999 ] || die "章节号超出范围：$raw"
    NN=$(printf '%02d' "$N_NUM")
}

commits_file() { echo "$1/meta/commits.json"; }

read_state_revision() { # $1=dir → STATE_REV
    local cf; cf="$(commits_file "$1")"
    [ -f "$cf" ] || die "缺少 $cf（先运行 init 或 migrate）"
    head -n1 "$cf" | grep -q '^{' || die "$cf 格式损坏（非 JSON 开头）"
    STATE_REV=$(sed -n 's/.*"state_revision": *\([0-9]*\).*/\1/p' "$cf" | head -n1)
    echo "$STATE_REV" | grep -qE "$num_pat" || die "$cf 无法解析 state_revision（格式损坏？）"
}

commit_line_for() { # $1=dir $2=章号(数字) → stdout: 该章提交条目行（无则空）
    grep -F "{\"chapter\": $2, " "$(commits_file "$1")" 2>/dev/null | head -n1
}

field_of() { # $1=条目行 $2=字段名 → stdout: 值（去引号）
    printf '%s\n' "$1" | sed -n "s/.*\"$2\": *\([^,}]*\).*/\1/p" | head -n1 | tr -d '"'
}

cn_num() { # $1=1..99 → 中文数字
    local n="$1" out="" u="一二三四五六七八九" d
    [ "$n" -lt 100 ] 2>/dev/null || { printf '%s\n' "$n"; return; }
    if [ "$n" -ge 10 ]; then
        d=$((n / 10))
        if [ "$d" -eq 1 ]; then out="十"; else out="${u:$((d-1)):1}十"; fi
        n=$((n % 10))
        if [ "$n" -eq 0 ]; then printf '%s\n' "$out"; return; fi
    fi
    printf '%s\n' "$out${u:$((n-1)):1}"
}

emit_commits_json() { # $1=state_revision $2=条目临时文件(每行一条) $3=输出文件
    {
        printf '{\n  "version": 1,\n  "state_revision": %s,\n  "commits": [' "$1"
        if [ -s "$2" ]; then
            printf '\n'
            awk 'NR>1{printf ",\n"}{printf "    %s", $0}' "$2"
            printf '\n  ]\n}\n'
        else
            printf ']\n}\n'
        fi
    } > "$3"
}

# ---------- init ----------

cmd_init() {
    local dir="$1"; shift || usage_help
    [ -d "$dir/meta" ] || die "$dir/meta 不存在（不是已初始化的项目？）"
    mkdir -p "$dir/meta/pending" "$dir/meta/history"
    [ -f "$dir/meta/usage.log" ] || : > "$dir/meta/usage.log"
    local cf; cf="$(commits_file "$dir")"
    if [ ! -f "$cf" ]; then
        : > /tmp/ct_empty.$$
        emit_commits_json 0 /tmp/ct_empty.$$ "$cf"
        rm -f /tmp/ct_empty.$$
        echo "created: $cf"
    else
        echo "exists: $cf"
    fi
    echo "ok: pending/ history/ usage.log"
}

# ---------- status ----------

cmd_status() {
    local dir="$1"
    [ -d "$dir" ] || die "目录不存在：$dir"
    local phase="-"
    if [ -f "$dir/meta/auto_state.json" ]; then
        phase=$(sed -n 's/.*"phase": *"\([^"]*\)".*/\1/p' "$dir/meta/auto_state.json" | head -n1)
        [ -n "$phase" ] || phase="-"
    fi
    echo "phase: $phase"
    local cf; cf="$(commits_file "$dir")"
    if [ -f "$cf" ]; then
        read_state_revision "$dir"
        local n=0 last="无"
        n=$(grep -cF '{"chapter": ' "$cf" || true)
        if [ "${n:-0}" -gt 0 ]; then
            local lline; lline=$(grep -F '{"chapter": ' "$cf" | tail -n1)
            last="第$(printf '%s\n' "$lline" | sed 's/.*"chapter": \([0-9]*\).*/\1/')章 r$(field_of "$lline" "committed_revision")"
        fi
        echo "state_revision: $STATE_REV"
        echo "commits: $n (last: $last)"
    else
        echo "commits.json: 缺失（旧项目——运行 migrate 一次性迁移）"
    fi
    local pend files residue
    pend=$(ls "$dir/meta/pending" 2>/dev/null | grep -E '^ch[0-9]+\.delta\.md$' | tr '\n' ' ')
    echo "pending_deltas: ${pend:-无}"
    files=$(ls "$dir/drafts" 2>/dev/null | grep -E '^ch[0-9]+\.md$' | tr '\n' ' ')
    echo "chapters_on_disk: ${files:-无}"
    residue=$(ls "$dir/drafts" 2>/dev/null | grep -E '_draft\.md$' | tr '\n' ' ')
    [ -n "$residue" ] && echo "draft_residue: $residue（断点——续写恢复）"
    [ -f "$dir/meta/usage.log" ] && echo "usage_records: $(wc -l < "$dir/meta/usage.log")"
    return 0
}

# ---------- verify-draft ----------

cmd_verify_draft() {
    local dir="$1"; check_nn "$2"
    local f="$dir/drafts/ch$NN.md" residue="$dir/drafts/ch${NN}_draft.md"
    if [ ! -f "$f" ]; then
        echo "exists: no"
        if [ -f "$residue" ]; then
            echo "draft_residue: yes（生成中断——派续写恢复任务）"
            exit 2
        fi
        echo "draft_residue: no"
        exit 1
    fi
    echo "exists: yes"
    if [ -f "$residue" ]; then
        echo "draft_residue: yes（正式章节已存在——残留待清理，遵守删除确认政策）"
    else
        echo "draft_residue: no"
    fi
    local zh en
    zh=$(grep -v '^#' "$f" | grep -v '^[[:space:]]*$' | grep -oP '[\x{4e00}-\x{9fff}]' 2>/dev/null | wc -l)
    en=$(grep -v '^#' "$f" | grep -v '^[[:space:]]*$' | grep -oP "[A-Za-z]+(?:['-][A-Za-z]+)*" 2>/dev/null | wc -l)
    echo "zh_chars: $zh"
    echo "en_words: $en"
    local leak
    leak=$(grep -nE '（[A-Z]+[-－]?[0-9]+）' "$f" | head -n5 || true)
    if [ -n "$leak" ]; then
        echo "id_leak: 命中（正文出现登记编号样式——派轻量修复）"
        printf '%s\n' "$leak" | sed 's/^/  /'
    else
        echo "id_leak: none"
    fi
    echo "prose_hash: $(hash_file "$f")"
}

# ---------- verify-delta ----------

delta_required_tags="new_facts revised_facts scene_changes character_state_changes information_acquisitions signal_changes outline_deviations unresolved_issues source_passages"

verify_delta_core() { # $1=dir $2=NN → 返回 0/1/3；打印结构化结果
    local dir="$1" NN="$2"
    local dp="$dir/meta/pending/ch$NN.delta.md"
    if [ ! -f "$dp" ]; then
        echo "delta_exists: no（$dp）"
        return 1
    fi
    echo "delta_exists: yes"
    if ! grep -q '<chapter_delta>' "$dp" || ! grep -q '</chapter_delta>' "$dp"; then
        echo "delta_wrap: 缺失 <chapter_delta> 包裹标签"
        return 1
    fi
    local v
    v=$(sed -n 's/^chapter:[[:space:]]*\([0-9]\{1,4\}\).*/\1/p' "$dp" | sed -n '1p')
    if [ "$v" != "$N_NUM" ]; then
        echo "chapter: ${v:-缺失}（应为 $N_NUM——章号不符）"
        return 1
    fi
    echo "chapter: $v"
    local base count
    count=$(grep -cE '^base_revision:[[:space:]]*[0-9]+' "$dp" || true)
    base=$(sed -n 's/^base_revision:[[:space:]]*\([0-9]\{1,6\}\).*/\1/p' "$dp" | sed -n '1p')
    if [ "$count" -ne 1 ] || [ -z "$base" ]; then
        echo "base_revision: 缺失或重复"
        return 1
    fi
    read_state_revision "$dir"
    if [ "$base" != "$STATE_REV" ]; then
        echo "base_revision: $base（当前 state_revision: $STATE_REV——不匹配，需重新对齐）"
        return 3
    fi
    echo "base_revision: $base (state_revision: $STATE_REV)"
    local pp
    pp=$(sed -n 's/^prose_path:[[:space:]]*//p' "$dp" | sed -n '1p' | tr -d '[:space:]')
    if [ "$pp" != "drafts/ch$NN.md" ]; then
        echo "prose_path: ${pp:-缺失}（应为 drafts/ch$NN.md）"
        return 1
    fi
    echo "prose_path: $pp"
    local ph
    ph=$(sed -n 's/^prose_hash:[[:space:]]*//p' "$dp" | sed -n '1p' | tr -d '[:space:]')
    if ! echo "$ph" | grep -qE '^[0-9a-f]{64}$'; then
        echo "prose_hash: 缺失或非 64 位十六进制"
        return 1
    fi
    local actual; actual=$(hash_file "$dir/drafts/ch$NN.md")
    if [ "$ph" != "$actual" ]; then
        echo "prose_hash: 不匹配（delta 绑定旧版本正文——修复后须重新生成 delta）"
        echo "  delta: $ph"
        echo "  实际: $actual"
        return 3
    fi
    echo "prose_hash: ok (bound to current ch$NN.md)"
    local missing="" t
    for t in $delta_required_tags; do
        if ! grep -q "^<$t>" "$dp" || ! grep -q "^</$t>" "$dp"; then
            missing="$missing $t"
        fi
    done
    if [ -n "$missing" ]; then
        echo "missing_tags:$missing"
        return 1
    fi
    echo "required_tags: ok（$(printf '%s\n' $delta_required_tags | wc -l) 节）"
    return 0
}

cmd_verify_delta() {
    local dir="$1"; check_nn "$2"
    verify_delta_core "$dir" "$NN"
    exit $?
}

# ---------- check-id ----------

cmd_check_id() {
    local dir="$1" sig="$2" id="$3"
    local f="$dir/meta/$sig"
    [ -f "$f" ] || die "投放物地图不存在：$f"
    echo "$id" | grep -qE '^[A-Za-z][A-Za-z0-9_-]*$' || die "编号格式非法：$id"
    local hits
    hits=$(grep -nF -- "$id" "$f" || true)
    if [ -z "$hits" ]; then
        echo "occurrences: 0（编号未占用——可新登记）"
        return 0
    fi
    echo "occurrences: $(printf '%s\n' "$hits" | wc -l)"
    local headings
    headings=$(printf '%s\n' "$hits" | grep -cE "^[0-9]+:#+\[?[[:space:]]*$id([^0-9A-Za-z_-]|$)" || true)
    echo "entry_headings: ${headings:-0}（应恰为 1——多于 1 即同号多条目）"
    printf '%s\n' "$hits" | head -n8 | cut -c1-90 | sed 's/^/  /'
    echo "note: 同号是否同物由调用方对照上述行内容判定"
    return 0
}

# ---------- commit ----------

cmd_commit() {
    local dir="$1"; check_nn "$2"; shift 2
    local meta_files="" note="" no_delta=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --meta-files) meta_files="$2"; shift 2 ;;
            --note) note="$2"; shift 2 ;;
            --no-delta) no_delta=1; shift ;;
            *) die "未知参数：$1" ;;
        esac
    done
    [ -n "$meta_files" ] || die "须提供 --meta-files（本次提交涉及的 meta 权威文件清单）"
    local mf json_mf="" IFS_OLD="$IFS"
    IFS=','
    for mf in $meta_files; do
        echo "$mf" | grep -qE "$file_pat" || die "meta 文件名非法：$mf（仅限项目 meta/ 下的 .md 文件名）"
        json_mf="$json_mf\"$mf\", "
    done
    IFS="$IFS_OLD"
    json_mf="[${json_mf%, }]"
    note=$(printf '%s' "$note" | tr -cd 'A-Za-z0-9 ,._:-' | sed 's/ *$//')
    local f="$dir/drafts/ch$NN.md"
    [ -f "$f" ] || die "章节文件不存在：$f"
    local h; h=$(hash_file "$f")
    read_state_revision "$dir"
    # 幂等检查先行：同章同 hash 重跑为 no-op（不重验 delta——历史 delta 的 base_revision 必然落后）
    local existing; existing=$(commit_line_for "$dir" "$N_NUM")
    if [ -n "$existing" ] && [ "$(field_of "$existing" "prose_hash")" = "$h" ]; then
        echo "idempotent: 第$N_NUM 章已于 revision $(field_of "$existing" "committed_revision") 提交（hash 一致，无变更）"
        exit 0
    fi
    local delta_path="pending/ch$NN.delta.md"
    if [ "$no_delta" -eq 0 ]; then
        verify_delta_core "$dir" "$NN"
        rc=$?
        [ $rc -eq 0 ] || { echo "提交中止：delta 校验未通过" >&2; exit $rc; }
    else
        [ -f "$dir/meta/$delta_path" ] && die "--no-delta 提交但存在 delta 文件（应走 delta 校验路径）"
        delta_path=""
    fi
    if [ -n "$existing" ]; then
        note="recommit $note"
        note=$(printf '%s' "$note" | sed 's/ *$//')
    fi
    local new_rev=$((STATE_REV + 1))
    local base_json="null"
    [ "$no_delta" -eq 0 ] && base_json="$STATE_REV"
    local newline="    {\"chapter\": $N_NUM, \"prose_hash\": \"$h\", \"prose_path\": \"drafts/ch$NN.md\", \"base_revision\": $base_json, \"committed_revision\": $new_rev, \"meta_files\": $json_mf, \"delta_path\": \"$delta_path\", \"timestamp\": \"$(now_ts)\", \"note\": \"$note\"}"
    local cf tmp all; cf="$(commits_file "$dir")"; tmp="$cf.tmp"; all=$(mktemp)
    {
        grep -F '{"chapter": ' "$cf" | grep -vF "{\"chapter\": $N_NUM, " || true
        printf '%s\n' "$newline"
    } | sed 's/^ *//; s/,$//' | sed 's/^{"chapter": \([0-9]*\),.*/\1\t&/' | sort -n | cut -f2- > "$all"
    emit_commits_json "$new_rev" "$all" "$tmp"
    mv "$tmp" "$cf"
    rm -f "$all"
    echo "committed: 第$N_NUM 章 → revision $new_rev（base: $base_json）"
    echo "prose_hash: $h"
    echo "meta_files: $meta_files"
}

# ---------- verify-commits ----------

cmd_verify_commits() {
    local dir="$1" cf; cf="$(commits_file "$dir")"
    [ -f "$cf" ] || die "缺少 $cf（旧项目先 migrate）"
    read_state_revision "$dir"
    local n=0 fail=0 line ch h f actual
    while IFS= read -r line; do
        case "$line" in
            *'{"chapter": '*)
                n=$((n+1))
                ch=$(printf '%s\n' "$line" | sed 's/.*"chapter": \([0-9]*\).*/\1/')
                h=$(field_of "$line" "prose_hash")
                f="$dir/drafts/ch$(printf '%02d' "$ch").md"
                if [ ! -f "$f" ]; then
                    echo "第$ch 章: ❌ 正文文件缺失 ($f)"
                    fail=$((fail+1))
                    continue
                fi
                actual=$(hash_file "$f")
                if [ "$actual" = "$h" ]; then
                    echo "第$ch 章: ok (r$(field_of "$line" "committed_revision"))"
                else
                    echo "第$ch 章: ❌ hash 漂移——正文在提交后被修改，须重新提交"
                    echo "  记录: $h"
                    echo "  实际: $actual"
                    fail=$((fail+1))
                fi
                ;;
        esac
    done < "$cf"
    echo "state_revision: $STATE_REV | checked: $n | drift: $fail"
    [ $fail -eq 0 ] || exit 1
}

# ---------- merge ----------

cmd_merge() {
    local dir="$1" out="$2"
    [ -d "$dir/drafts" ] || die "$dir/drafts 不存在"
    local files cf cf_exists=1
    files=$(ls "$dir/drafts" 2>/dev/null | grep -E '^ch[0-9]+\.md$' | sort)
    [ -n "$files" ] || die "drafts/ 下没有章节文件"
    cf="$(commits_file "$dir")"
    [ -f "$cf" ] || cf_exists=0
    local uncommitted="" n=0 ch nn f h entry title toc="" body_tmp
    body_tmp=$(mktemp)
    : > "$body_tmp"
    for f in $files; do
        nn="${f#ch}"; nn="${nn%.md}"; ch=$((10#$nn))
        n=$((n+1))
        entry=""
        [ "$cf_exists" -eq 1 ] && entry=$(commit_line_for "$dir" "$ch")
        if [ -n "$entry" ]; then
            h=$(hash_file "$dir/drafts/$f")
            if [ "$h" != "$(field_of "$entry" "prose_hash")" ]; then
                echo "❌ 第$ch 章 hash 漂移：正文与提交记录不一致——先重新提交再合稿" >&2
                rm -f "$body_tmp"
                exit 1
            fi
        else
            uncommitted="$uncommitted $ch"
        fi
        title=$(grep -m1 '^#[^#]' "$dir/drafts/$f" | sed 's/^#[[:space:]]*//')
        [ -n "$title" ] || title="第$(cn_num "$ch")章（无标题）"
        toc="$toc- $title"$'\n'
        cat "$dir/drafts/$f" >> "$body_tmp"
        printf '\n\n---\n\n' >> "$body_tmp"
    done
    local book
    book=$(sed -n 's/^- \*\*书名\*\*：[*《]*\([^》*]*\)[》*]*$/\1/p' "$dir/meta/project_info.md" 2>/dev/null | head -n1)
    [ -n "$book" ] || book=$(basename "$out" .md)
    {
        printf '# 《%s》\n\n---\n\n## 目录\n\n' "$book"
        printf '%s' "$toc"
        printf -- '\n---\n\n'
        cat "$body_tmp"
    } > "$out"
    rm -f "$body_tmp"
    local zh=0 t
    for f in $files; do
        t=$(grep -v '^#' "$dir/drafts/$f" | grep -v '^[[:space:]]*$' | grep -oP '[\x{4e00}-\x{9fff}]' 2>/dev/null | wc -l)
        zh=$((zh + t))
    done
    echo "merged: $out"
    echo "chapters: $n | zh_chars_total: $zh"
    if [ -n "$uncommitted" ]; then
        echo "⚠️ 未登记提交的章节（按文件现状合入）:$uncommitted"
    fi
    if [ "$cf_exists" -eq 1 ]; then
        read_state_revision "$dir"
        echo "verified_against: commits.json (state_revision $STATE_REV)"
    else
        echo "verified_against: 无 commits.json（旧项目/交互模式——建议 migrate 登记）"
    fi
}

# ---------- migrate ----------

cmd_migrate() {
    local dir="$1"; shift || usage_help
    local sig="" force=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --signal-doc) sig="$2"; shift 2 ;;
            --force) force=1; shift ;;
            *) die "未知参数：$1" ;;
        esac
    done
    [ -d "$dir/meta" ] || die "$dir/meta 不存在（不是已初始化的项目？）"
    local cf; cf="$(commits_file "$dir")"
    if [ -f "$cf" ] && [ "$force" -ne 1 ]; then
        echo "already_migrated: $cf 存在（迁移只执行一次；确需重建用 --force）"
        return 0
    fi
    local files; files=$(ls "$dir/drafts" 2>/dev/null | grep -E '^ch[0-9]+\.md$' | sort)
    mkdir -p "$dir/meta/pending" "$dir/meta/history"
    [ -f "$dir/meta/usage.log" ] || : > "$dir/meta/usage.log"
    local n=0 all; all=$(mktemp)
    : > "$all"
    if [ -n "$files" ]; then
        local f ch nn h
        for f in $files; do
            nn="${f#ch}"; nn="${nn%.md}"; ch=$((10#$nn))
            n=$((n+1))
            h=$(hash_file "$dir/drafts/$f")
            printf '{"chapter": %s, "prose_hash": "%s", "prose_path": "drafts/%s", "base_revision": %s, "committed_revision": %s, "meta_files": [], "delta_path": "", "timestamp": "%s", "note": "legacy-backfill"}\n' \
                "$ch" "$h" "$f" "$((n-1))" "$n" "$(now_ts)" >> "$all"
        done
    fi
    emit_commits_json "$n" "$all" "$cf"
    rm -f "$all"
    echo "migrated: $cf（$n 章补录，state_revision=$n）"
    local warn=0
    if [ -n "$sig" ]; then
        if grep -q '^## *总索引' "$dir/meta/$sig" 2>/dev/null; then
            echo "index: ok（$sig 含「总索引」节）"
        else
            echo "⚠️ $sig 缺少「总索引」节——Director 须一次性补建（此后每章不再退回全文读取）"
            warn=1
        fi
    fi
    grep -q 'genre' "$dir/meta/project_info.md" 2>/dev/null || { echo "⚠️ project_info.md 缺 genre 字段"; warn=1; }
    grep -q 'language' "$dir/meta/project_info.md" 2>/dev/null || { echo "⚠️ project_info.md 缺 language 字段"; warn=1; }
    [ -f "$dir/meta/session_log.md" ] || { echo "⚠️ 缺 session_log.md"; warn=1; }
    [ -f "$dir/meta/auto_state.json" ] || echo "note: 无 auto_state.json（首次 /auto-write 会创建）"
    echo "checkpoint: 可恢复（后续中断按 commits.json + auto_state.phase 组合判定）"
    return 0
}

# ---------- usage ----------

cmd_usage() {
    local dir="$1"; shift || usage_help
    [ -f "$dir/meta/usage.log" ] || : > "$dir/meta/usage.log"
    local mode="unknown"
    [ -f "$dir/meta/auto_state.json" ] && mode=$(sed -n 's/.*"mode": *"\([^"]*\)".*/\1/p' "$dir/meta/auto_state.json" | head -n1)
    [ -n "$mode" ] || mode="unknown"
    local pairs="" k v kv
    for kv in "$@"; do
        case "$kv" in
            *=*) k="${kv%%=*}"; v="${kv#*=}" ;;
            *) die "usage 记录须为 key=value 形式：$kv" ;;
        esac
        echo "$k" | grep -qE '^[a-z_][a-z0-9_]*$' || die "键名非法：$k"
        echo "$v" | grep -qE '^[A-Za-z0-9_.:+-]+$' || die "值含非法字符（禁止引号/空格/反斜杠）：$v"
        if echo "$v" | grep -qE "$num_pat"; then
            pairs="$pairs\"$k\": $v, "
        else
            pairs="$pairs\"$k\": \"$v\", "
        fi
    done
    printf '{"ts": "%s", "mode": "%s", %s}\n' "$(now_ts)" "$mode" "${pairs%, }" >> "$dir/meta/usage.log"
    echo "recorded: $*"
}

# ---------- main ----------

[ $# -ge 2 ] || usage_help
CMD="$1"; DIR="$2"
case "$CMD" in
    init)           cmd_init "$DIR" "${@:3}" ;;
    status)         cmd_status "$DIR" ;;
    verify-draft)   [ $# -ge 3 ] || usage_help; cmd_verify_draft "$DIR" "$3" ;;
    verify-delta)   [ $# -ge 3 ] || usage_help; cmd_verify_delta "$DIR" "$3" ;;
    check-id)       [ $# -ge 4 ] || usage_help; cmd_check_id "$DIR" "$3" "$4" ;;
    commit)         [ $# -ge 3 ] || usage_help; cmd_commit "$DIR" "$3" "${@:4}" ;;
    verify-commits) cmd_verify_commits "$DIR" ;;
    merge)          [ $# -ge 3 ] || usage_help; cmd_merge "$DIR" "$3" ;;
    migrate)        cmd_migrate "$DIR" "${@:3}" ;;
    usage)          [ $# -ge 3 ] || usage_help; cmd_usage "$DIR" "${@:3}" ;;
    *)              usage_help ;;
esac
