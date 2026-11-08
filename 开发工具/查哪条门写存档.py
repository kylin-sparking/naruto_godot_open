# -*- coding: utf-8 -*-
"""查：全量清单里究竟哪一条离线门在写 `user://玩家数据.json`。

背景（会复发，别删这段）：规矩是「离线门不许写存档」，但跑完整套之后存档的 md5 变了两次
（10-11 23:29 那次落在段3=64..95 的运行窗口内），而单跑新门不变 ⇒ 套里有一条(或多条)门在写真存档。
这会让"新号开局带旧东西"这种假象反复出现（#166 同族），所以先定位、再决定怎么修。

用法：python 开发工具/查哪条门写存档.py <起:1基> <止>
产物：测试/_查存档_起_止.txt（逐条：门名 / 退出码 / 变了哪些 json 文件）
⚠ 跑完会把 `user://` 下这几个 json **还原成本工具开跑前读到的字节**（先整份快照进 _tmp/bak_save/），
  不还原的话这条工具自己就成了"写存档"的又一处。
"""
import base64, glob, hashlib, io, json, os, shutil, subprocess, sys

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("NARUTO_GODOT") or "godot"
名 = io.open(os.path.join(工程, "project.godot"), encoding="utf-8").read()
项目名 = [l.split('"')[1] for l in 名.splitlines() if l.startswith("config/name=")][0]
用户目录 = os.path.join(os.environ["APPDATA"], "Godot", "app_userdata", 项目名)

def md(p):
    return hashlib.md5(open(p, "rb").read()).hexdigest() if os.path.exists(p) else "缺"

def 普查():
    return {os.path.basename(p): md(p) for p in glob.glob(os.path.join(用户目录, "*.json"))}

# 清单只认 验证全部.ps1 那一份 base64（与 分段跑离线门.py 同源，防漂移）
源 = os.path.join(工程, "开发工具", "验证全部.ps1")
清单 = None
for 行 in io.open(源, encoding="utf-8-sig"):
    if "$testsBase64" in 行 and '"' in 行:
        清单 = 行.split('"')[1]
        break
套件 = json.loads(base64.b64decode(清单).decode("utf-8")) + [
    base64.b64decode("56qX5Y+j5biD5bGA5L2T5qOALmdk").decode("utf-8")]
起 = int(sys.argv[1]); 止 = int(sys.argv[2])

备份 = os.path.join(工程, "_tmp", "bak_save")
if not os.path.isdir(备份):
    os.makedirs(备份)
前 = 普查()
快 = {}
for b, h in 前.items():
    p = os.path.join(用户目录, b)
    if os.path.exists(p):
        副本 = os.path.join(备份, b)
        shutil.copyfile(p, 副本)
        快[b] = 副本
志 = os.path.join(工程, "测试", "_查存档_%d_%d.txt" % (起, 止))
犯 = []
with io.open(志, "w", encoding="utf-8") as f:
    f.write("用户目录 %s\n开跑前 %s\n\n" % (用户目录, 前))
    for i in range(起 - 1, min(止, len(套件))):
        t = 套件[i]
        a = 普查()
        p = subprocess.run([GODOT, "--headless", "--path", 工程, "--script", "res://测试/" + t],
                           capture_output=True, text=True, encoding="utf-8", errors="replace")
        b = 普查()
        变 = sorted(k for k in set(list(a) + list(b)) if a.get(k) != b.get(k))
        f.write("[%d/%d] %-34s exit %d  变=%s\n" % (i + 1, len(套件), t, p.returncode, 变))
        f.flush()
        if 变:
            犯.append((i + 1, t, 变))
    f.write("\n写存档的门 %d 条：\n" % len(犯))
    for x in 犯:
        f.write("  %s\n" % (x,))
print("查完：%d 条门里 %d 条写了 user:// 的 json" % (min(止, len(套件)) - 起 + 1, len(犯)))
for x in 犯:
    print("  ", x)
# 还原
sys.stdout.flush()
for b, h in 前.items():
    p = os.path.join(用户目录, b)
    if h == "缺":
        continue
    if md(p) != h and b in 快:
        shutil.copyfile(快[b], p)
后 = 普查()
print("还原后与开跑前是否一致：", 后 == 前, "" if 后 == 前 else ("仍不同 %s" % 后))
