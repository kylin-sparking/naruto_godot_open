#!/usr/bin/env bash
# 公开仓最小门：贡献者提交 PR 前的自检。
#
# 不依赖游戏素材，只跑公开仓能独立验证的部分：
#   1. 源码健全性回归测试
#   2. 木叶村NPC回归测试
#   3. 本次改动不混入素材/二进制/生成物/大文件
#   4. 本次改动不写本机绝对路径、不引用内部资料
#   5. 本次改动没有控制字符
#
# 用法（优先读项目根目录的 本机配置.ini；也可以设环境变量）：
#   复制 本机配置.example.ini 为 本机配置.ini，填写 Godot=
#   export NARUTO_GODOT=/path/to/Godot_v4.7.x-stable_mono_win64_console
#   bash 测试/公开仓最小门.sh
#
# 没有素材时界面/地图相关门会按已知限制失败，这是预期行为；完整门由维护者
# 在补齐素材的完整开发环境里跑。
#
# 注意：bash 变量和函数名只能用 ASCII；中文只放在注释和输出文字里。
set -u

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Godot 路径：本机配置.ini 的 Godot= > 环境变量 NARUTO_GODOT > PATH。
if [ -z "${NARUTO_GODOT:-}" ] && [ -f "$root/本机配置.ini" ]; then
    config_value="$(sed -n 's/^[[:space:]]*[Gg][Oo][Dd][Oo][Tt][[:space:]]*=[[:space:]]*//p' "$root/本机配置.ini" | head -n 1 | tr -d '\r')"
    config_value="${config_value%\"}"
    config_value="${config_value#\"}"
    [ -n "$config_value" ] && NARUTO_GODOT="$config_value"
fi
G="${NARUTO_GODOT:-godot}"

# Git Bash 里 NARUTO_GODOT 常写成 D:\...；转成 D:/... 才能被 exec 认。
case "$G" in
    [A-Za-z]:\\*) G="${G//\\//}" ;;
esac

if ! command -v "$G" >/dev/null 2>&1 && [ ! -f "$G" ]; then
    echo "!! 找不到 Godot：$G"
    echo "   请复制 本机配置.example.ini 为 本机配置.ini 并填写 Godot=，"
    echo "   或设置 NARUTO_GODOT 指向 Godot 4.7.x console 版，或把 godot 加入 PATH。"
    exit 2
fi

# Windows 版 Godot 不认 Git Bash 的 /d/... 路径，转成 D:\...
root_godot="$root"
if command -v cygpath >/dev/null 2>&1; then
    root_godot="$(cygpath -w "$root")"
fi

tmp="$(mktemp -d)" || { echo "!! 无法创建临时目录"; exit 2; }
trap 'rm -rf "$tmp"' EXIT
fail=0

run_gate() {
    local name="$1"
    local log="$tmp/$name.log"
    echo "== $name"
    if ! "$G" --headless --path "$root_godot" --script "res://测试/$name.gd" >"$log" 2>&1; then
        echo "!! $name 失败，最后 20 行："
        tail -n 20 "$log"
        fail=1
    else
        grep -E '通过|红 [0-9]+' "$log" | tail -n 2 || tail -n 2 "$log"
    fi
}

run_gate "源码健全性回归测试"
run_gate "木叶村NPC回归测试"

echo "== 改动检查"
if ! git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "   （不是 git 仓库，跳过改动检查；只跑了上面的门）"
else
    changed="$tmp/changed.txt"
    : > "$changed"
    if git -C "$root" rev-parse --verify -q origin/master >/dev/null 2>&1; then
        git -C "$root" -c core.quotepath=false diff --name-only --diff-filter=ACMR origin/master...HEAD >> "$changed" 2>/dev/null || true
    elif git -C "$root" rev-parse --verify -q master >/dev/null 2>&1; then
        git -C "$root" -c core.quotepath=false diff --name-only --diff-filter=ACMR master...HEAD >> "$changed" 2>/dev/null || true
    fi
    git -C "$root" -c core.quotepath=false diff --name-only --diff-filter=ACMR HEAD >> "$changed" 2>/dev/null || true
    git -C "$root" -c core.quotepath=false ls-files --others --exclude-standard >> "$changed" 2>/dev/null || true
    sort -u "$changed" -o "$changed"

    if [ ! -s "$changed" ]; then
        echo "   （没有检测到改动）"
    else
        # 1) 素材、二进制、生成物
        forbidden_path='^(\.godot/|运行时/|素材_2x/|素材_4x/|\.fixture|测试/截图/)'
        hits=$(grep -E "$forbidden_path" "$changed" || true)
        if [ -n "$hits" ]; then
            echo "!! 这些文件不应该进公开仓："
            echo "$hits" | sed 's/^/     /'
            fail=1
        fi

        forbidden_ext='\.(png|jpe?g|webp|bmp|ttf|ttc|otf|wav|mp3|ogg|ogv|swf|dat|dll|exe|pdb|zip|7z|rar)$'
        hits=$(grep -Ei "$forbidden_ext" "$changed" || true)
        if [ -n "$hits" ]; then
            echo "!! 改动里含素材/二进制文件（素材不随公开仓分发）："
            echo "$hits" | sed 's/^/     /'
            fail=1
        fi

        # 2) 大文件
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            [ -f "$root/$f" ] || continue
            bytes=$(wc -c < "$root/$f" | tr -d ' ')
            if [ "$bytes" -gt 5242880 ]; then
                echo "!! 大文件（>5MB）：$f（$bytes 字节）"
                fail=1
            fi
        done < "$changed"

        # 3) 本机绝对路径（硬失败）
        private_path='([A-Za-z]:[\\/](Users|work|单机|火影|godot_tools)|/d/(work|单机|火影|godot)|/mnt/[a-z]/(work|单机|火影)|E:[\\/]单机)'
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            [ -f "$root/$f" ] || continue
            grep -IqE "$private_path" "$root/$f" 2>/dev/null || continue
            echo "!! 本机绝对路径：$f"
            grep -InE "$private_path" "$root/$f" | head -n 5 | sed 's/^/     /'
            fail=1
        done < "$changed"

        # 4) 内部资料引用（提示，不阻断；评审时确认）
        internal_ref='(移植进度与计划\.md|给接手开发者\.md|素材增量清单\.md|docs/编年史_|开发工具/_|测试/_核对)'
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            [ -f "$root/$f" ] || continue
            grep -IqE "$internal_ref" "$root/$f" 2>/dev/null || continue
            echo "提示：$f 引用了内部开发资料，提交前确认是否应改写。"
        done < "$changed"

        # 5) 控制字符
        PY=""
        command -v python >/dev/null 2>&1 && PY=python
        [ -z "$PY" ] && command -v python3 >/dev/null 2>&1 && PY=python3
        if [ -z "$PY" ]; then
            echo "   （未找到 Python，跳过控制字符检查）"
        else
            root_py="$root"
            list_py="$changed"
            if command -v cygpath >/dev/null 2>&1; then
                root_py="$(cygpath -w "$root")"
                list_py="$(cygpath -w "$changed")"
            fi
            if ! "$PY" - "$root_py" "$list_py" <<'PY'
import os
import sys

root, listfile = sys.argv[1], sys.argv[2]
bad = []
for line in open(listfile, encoding="utf-8"):
    rel = line.strip()
    if not rel:
        continue
    path = os.path.join(root, rel)
    if not os.path.isfile(path) or os.path.getsize(path) > 5_000_000:
        continue
    data = open(path, "rb").read()
    hits = sorted({b for b in data if b < 32 and b not in (9, 10, 13)})
    if hits:
        bad.append((rel, hits[:8]))
for rel, hits in bad:
    print("!! 控制字符：%s %s" % (rel, hits))
sys.exit(1 if bad else 0)
PY
            then
                fail=1
            fi
        fi
    fi
fi

echo
if [ "$fail" -ne 0 ]; then
    echo "公开仓最小门：失败"
    exit 1
fi
echo "公开仓最小门：通过"
