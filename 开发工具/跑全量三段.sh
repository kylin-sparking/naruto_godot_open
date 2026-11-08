#!/bin/bash
# 全量离线门分三段跑（整包跑会被 4 分钟超时掐掉）。
# ⚠ shell 变量名不许用中文：bash 认不了 `段`，会打 "not a valid identifier"
#   然后**一段都不跑就退出 0**（2026-10-11 实测踩过一次"假完成"）。
cd "$(dirname "$0")/.." || exit 2
for SEG in "1 32 段1" "33 64 段2" "65 96 段3"; do
	echo "########## $SEG"
	python -u 开发工具/分段跑离线门.py $SEG 2>&1 | tail -6
done
echo "########## 全量三段跑完"
