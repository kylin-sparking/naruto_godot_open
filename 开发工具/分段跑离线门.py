# -*- coding: utf-8 -*-
"""分段跑离线门：`跑全部离线门.py` 一次跑完整套会被会话级超时掐掉（实测两次都在 4 分钟左右断），
所以这里按序号切片跑，每段单独落证据。清单仍然只认 `验证全部.ps1` 的那一份 base64（不另列，防漂移）。

用法：python 开发工具/分段跑离线门.py <起:1基> <止> [日志名]
"""
import base64, io, json, os, subprocess, sys

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("NARUTO_GODOT") or "godot"
源 = os.path.join(工程, "开发工具", "验证全部.ps1")
清单 = None
for 行 in io.open(源, encoding="utf-8-sig"):
    if "$testsBase64" in 行 and '"' in 行:
        清单 = 行.split('"')[1]
        break
套件 = json.loads(base64.b64decode(清单).decode("utf-8")) + [
    base64.b64decode("56qX5Y+j5biD5bGA5L2T5qOALmdk").decode("utf-8")]
起 = int(sys.argv[1]); 止 = int(sys.argv[2])
志 = os.path.join(工程, "测试", "_验证全部_分段_%s.log" % (sys.argv[3] if len(sys.argv) > 3 else "%d_%d" % (起, 止)))
红 = []
with io.open(志, "w", encoding="utf-8") as f:
    f.write("段 %d..%d / 共 %d 项\n" % (起, 止, len(套件)))
    for i in range(起 - 1, min(止, len(套件))):
        t = 套件[i]
        p = subprocess.run([GODOT, "--headless", "--path", 工程, "--script", "res://测试/" + t],
                           capture_output=True, text=True, encoding="utf-8", errors="replace")
        汇 = [l for l in (p.stdout or "").splitlines() if "汇：" in l or "通过" in l and "共" in l]
        f.write("\n════ [%d/%d] %s (exit %d) ════\n%s\n" % (
            i + 1, len(套件), t, p.returncode, (汇[-1] if 汇 else "")[:200]))
        if p.returncode != 0:
            红.append((i + 1, t))
        f.flush()
    f.write("\n本段红 %d 项：%s\n" % (len(红), 红))
print("段 %d..%d 完，红 %d 项 %s" % (起, 止, len(红), 红))
