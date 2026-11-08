#!/bin/bash
# 跑**一条**在线用例，夹具存档集中放在 `测试/输出/夹具存档/`，**跑完即删**。
#
# 为什么要有这个脚本（用户 2026-10-09 提的）：
#   以前是手敲 `--root ./.fixture_xxx`，一条用例一个根、跑完不删 ⇒ 工程根里堆了 26 个
#   `.fixture_*` 目录（`.fixture_a`…`.fixture_x`）。现在统一走这里：
#     * 根集中在 `测试/输出/夹具存档/<用例名>/`，不污染工程根；
#     * 默认**跑完就删**；出问题要留证据时加 `--keep`（也认 `--保留`）。
#
# ⚠️⚠️ 工程根的 `.fixture` 是**启动游戏.bat 在用的真实存档**（玩家的家族/角色都在里面），
#     任何用例都不许指它、更不许带 `--reset`。本脚本会挡住这种写法。
#     （顺带修掉一个地雷：`开发工具/跑在线用例.ps1` 的夹具根默认值原来就是 `.fixture`
#      且带 `--reset` —— 直接用默认值跑一次就会清掉玩家存档，已改成这里的集中目录。）
#
# ⚠️ **bash 不把中文当合法变量名**（`用例=…` 会被当成命令执行），所以本脚本的变量名
#    一律 ASCII —— 这个坑本工程踩过两次（见 `测试/跑全部离线门.sh` 顶部）。
#
# 用法：
#   bash 测试/跑在线门.sh 家族安插族旗在线回归测试.gd --main-family
#   bash 测试/跑在线门.sh 商城购买族书在线回归测试.gd
#   bash 测试/跑在线门.sh 家族安插族旗在线回归测试.gd --main-family --keep
#
# 环境可覆盖：NARUTO_GAME_ROOT / NARUTO_PY / NARUTO_GODOT
set -u

cd "$(dirname "$0")/.." || exit 1

# 原版 2.2.3 目录：默认是本工程旁的 `2.2.3/`，可用 NARUTO_GAME_ROOT 覆盖。
# ⚠️ 给夹具（Python）的路径建议用 Windows 风格 `<盘>:/…` 或相对工程根的写法。
GAME_ROOT_WIN="${NARUTO_GAME_ROOT:-2.2.3}"
GAME_ROOT_BASH="${NARUTO_GAME_ROOT_BASH:-2.2.3}"
PY="${NARUTO_PY:-python}"
GODOT="${NARUTO_GODOT:-godot}"
PORT=18684

CASE="${1:-}"
if [ -z "$CASE" ]; then
  echo "用法：bash 测试/跑在线门.sh <用例脚本名.gd> [夹具额外参数…] [--keep]"
  echo "例：  bash 测试/跑在线门.sh 家族安插族旗在线回归测试.gd --main-family"
  exit 1
fi
shift

KEEP=0
EXTRA=()
for a in "$@"; do
  if [ "$a" = "--keep" ] || [ "$a" = "--保留" ]; then
    KEEP=1
  else
    EXTRA+=("$a")
  fi
done

ROOT="测试/输出/夹具存档/${CASE%.gd}"

# ⚠️ 端口上留着的旧服务端会让**新夹具绑不上端口**，而用例会静默连到那个旧服务端上
#    （症状是一堆莫名其妙的断言失败，排查时极易带偏）。先清掉。
for p in $(netstat -ano 2>/dev/null | grep "127.0.0.1:${PORT}" | grep LISTENING | awk '{print $NF}' | sort -u); do
  taskkill //PID "$p" //F >/dev/null 2>&1 && echo "[清端口] 已结束占用 ${PORT} 的进程 $p"
done
sleep 2

mkdir -p "$ROOT"
echo "[跑] $CASE   夹具根=$ROOT   额外参数=${EXTRA[*]:-（无）}"
NARUTO_GAME_ROOT="$GAME_ROOT_WIN" "$PY" 开发工具/本地服务端夹具.py \
  --root "./$ROOT" --reset "${EXTRA[@]}" \
  --run "res://测试/$CASE" --godot "$GODOT"
CODE=$?

if [ "$KEEP" = "1" ]; then
  echo "[留] 夹具存档保留在 $ROOT（--keep）"
else
  rm -rf "$ROOT"
  echo "[清] 已删除夹具存档 $ROOT"
fi
exit $CODE
