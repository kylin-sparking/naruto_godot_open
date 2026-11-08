# -*- coding: utf-8 -*-
"""打印客户端角色动画元数据里某个角色/动作每帧的 origin 与尺寸，供与原版对照。

用法: python 开发工具/查角色动画元数据.py [角色id] [动作]
默认 00000001 stand
"""
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
P = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "数据", "角色", "动画元数据.json")

with open(P, encoding="utf-8-sig") as f:
    meta = json.load(f)
print("顶层 kind:", list(meta.keys()))
kind = "character"
cid = sys.argv[1] if len(sys.argv) > 1 else "00000001"
act = sys.argv[2] if len(sys.argv) > 2 else "stand"
chars = meta.get(kind, {})
print("%s 角色数=%d；%s 的动作=%s" % (kind, len(chars), cid, list(chars.get(cid, {}).keys())))
frames = chars.get(cid, {}).get(act, {})
for k in sorted(frames, key=lambda s: int(s) if s.isdigit() else 0):
    fr = frames[k]
    body = fr.get("body", fr)
    print("  %s: origin=%s value=%s delay=%s" % (k, body.get("origin"), body.get("value"), fr.get("delay")))
