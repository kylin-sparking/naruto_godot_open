import io
import json
import os
import shutil
import sys

"""重算 `数据/NPC.json` 的 **dialogue**（并按服务端覆盖修 76 的 name）——口径逐字照服务端。

服务端 `2.2.3优化版/HYSJ/tools/fake_flash_server.py`：

- `:9014-9027 _load_npc_strings`：`name = raw["name"] or "神秘忍者"`、
  **`dialogue = raw["d0"] or raw["n0"] or f"你好，我是{name}。"`** ⇒ **`d0` 优先、`n0` 只是兜底**。
- `:8913-8916`：模板 **76** 显式覆盖 `name = "转职导师"`、
  `dialogue = "我可以帮助你更换忍术流派。请准备一张转职凭证，并提前留出背包空间。"`（它不在木叶村）。

工程这份 `数据/NPC.json` 当年按 **`n0`** 存的 ⇒ **76 枚里 62 枚台词是错的**。
用户 2026-10-05 拿富岳实机图打回时抓到：图上是 d0「警所事务繁忙，要来帮忙吗？」，
表里是 n0「“团扇”是代表宇智波家荣誉的家徽！」。⇒ 这条不是"某一页摆错"，是**全工程 NPC 台词条**。

`title` 那一列取的是 `func`（服务端 `_load_npc_functions:9029-9040` 的第二个返回值 = 服务名），
运行期 上格 只显示 `name` ⇒ 不影响画面，本工具不碰（76 除外：服务端整条覆盖）。

用法：python 开发工具/出NPC台词.py [--干跑]
"""

sys.stdout.reconfigure(encoding="utf-8")
项目 = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
源 = os.path.join(os.path.dirname(项目), "真值文档", "GameData", "String.json")
标 = os.path.join(项目, "数据", "NPC.json")
干跑 = "--干跑" in sys.argv

S = json.load(io.open(源, encoding="utf-8"))["items"]["Npc"]
N = json.load(io.open(标, encoding="utf-8"))

改 = []
缺 = []
for 号, v in N.items():
    s = S.get(号)
    if not isinstance(s, dict):
        缺.append(号)
        continue
    名 = str(s.get("name") or "神秘忍者")
    真 = str(s.get("d0") or s.get("n0") or ("你好，我是" + 名 + "。"))
    if 号.endswith("00000076"):		# 服务端 :8913-8916 整条覆盖，d0 轮不到
        名, 真 = "转职导师", "我可以帮助你更换忍术流派。请准备一张转职凭证，并提前留出背包空间。"
    if 真 != v.get("dialogue", ""):
        改.append((号, v.get("name"), v.get("dialogue", ""), 真))
        v["dialogue"] = 真
    if 名 != v.get("name", ""):
        print("   name 也修：%s「%s」⇒「%s」" % (号, v.get("name"), 名))
        v["name"] = 名

print("String.json 里查无此枚：%d 条 %s" % (len(缺), 缺[:6]))
print("台词按 d0→n0→兜底（76 走服务端覆盖）重算：改 %d / 共 %d" % (len(改), len(N)))
for t in 改[:4]:
    print("   %s %s：「%s」⇒「%s」" % t)
if 干跑:
    print("--干跑：没写盘")
    raise SystemExit(0)
备 = 标 + ".bak_台词重算"
if not os.path.exists(备):
    shutil.copyfile(标, 备)
io.open(标, "w", encoding="utf-8", newline="").write(
    json.dumps(N, ensure_ascii=False, separators=(",", ":")))
print("已写", 标, "（旧版备份：", 备, "）")
