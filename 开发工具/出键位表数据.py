# -*- coding: utf-8 -*-
"""从 `KeyDef.as` 抽键位表 → `数据/界面/键位表.json`（快捷键窗的格标签/宽/可绑性真值）。

为什么单独抽：`KeyboardCell.init(data)` 显示的名字、格的宽、能不能绑，全部来自
`KeyDef.KEYBOARD_TEXTS[i] ↔ KEYBOARD_BTNS[i]`（`KU.as:15-26` 按下标配对成字典，
KF.as:79-108 用**实例名去掉尾缀 Cell** 当键去查）。⇒ 自造标签就是造假，必须按表取。

用法：python 开发工具/出键位表数据.py
"""
import io
import json
import os
import re
import sys

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
原版根 = os.environ.get("NARUTO_GAME_ROOT") or os.path.join(工程, "..", "2.2.3")
源 = os.path.join(os.environ.get("NARUTO_AS_ROOT")
    or os.path.join(原版根, "map_extract", "out", "mainlib_as", "scripts"),
    "com", "mxw", "common", "gameCommon", "KeyDef.as")
出 = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                  "数据", "界面", "键位表.json")

s = io.open(源, encoding="utf-8", errors="replace").read()
i = s.index("KEYBOARD_TEXTS:Array = [")
texts = [x.strip().strip('"') for x in
         re.search(r"KEYBOARD_TEXTS:Array = \[(.*?)\];", s[i:], re.S).group(1).split(",") if x.strip()]
j = s.index("KEYBOARD_BTNS:Array = [")
尾 = s.index("BASE_SHORTCUT_KEYS", j)
项 = re.findall(r"\{(.*?)\}", s[j:尾], re.S)


def 取(块, 式, 默=None):
    m = re.search(式, 块)
    return m.group(1) if m else 默


列 = []
for o in 项:
    列.append({
        "name": 取(o, r'"name":"(.*?)"', ""),
        "width": int(取(o, r'"width":(\d+)', "40")),
        "canSet": 取(o, r'"canSet":(true|false)', "true") == "true",
        "keyCode": 取(o, r'"keyCode":([A-Za-z0-9_.]+)', ""),
        "keyId": 取(o, r'"keyId":([A-Za-z0-9_]+)', ""),
    })
if len(texts) != len(列):
    raise SystemExit("TEXTS %d 与 BTNS %d 条数不等，按下标配对的表不能信" % (len(texts), len(列)))
表 = {texts[k]: 列[k] for k in range(len(texts))}
# 31 条「动作槽」= 右侧列表格要显示的东西（`KeyDef.BASE_SHORTCUT_KEYS:817-1009`，
# 字段 position / name(语言键) / defaultKeyId）。列表格 i 按 position 填，ESC 是 −1 占位。
k = s.index("BASE_SHORTCUT_KEYS:Array = [")
槽块 = re.findall(r"\{(.*?)\}", s[k:k + 40000], re.S)
槽 = []
for o in 槽块:
    g = lambda pat, 默=None: (re.search(pat, o).group(1) if re.search(pat, o) else 默)
    槽.append({"position": int(g(r'"position":(-?\d+)', "-1")),
              # 名字两种写法：`CN.KEY_x`（编译期常量）与 `LangUtil.get("KEY_x")`（运行期取）——
              # 后者实测只有 1 条（拾取旗子），别以为都带 CN. 就漏掉它
              "语言键": (g(r'"name":CN\.([A-Za-z0-9_]+)', "") or
                     g(r'"name":LangUtil\.get\("([A-Za-z0-9_]+)"', "")),
              "type": g(r'"type":([A-Za-z0-9_]+)', ""),
              "defaultKeyId": g(r'"defaultKeyId":([A-Za-z0-9_]+)', "")})
槽 = [x for x in 槽 if x["position"] >= 0]
# 槽名一律回语言表取（`KEYBOARD_SHORTCUT_KEY_*`），查不到就 raise，不自造中文
语 = {}
for 档 in ("core.json", "ui.json", "message.json"):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import 原版数据 as _语言源  # 语言表取自 AS3 字面量，与本工程同一条链
    for k, v in _语言源.读语言表(档.removesuffix(".json")).items():
        for kk, vv in json.load(f).items():
            if isinstance(vv, str):
                语.setdefault(kk, vv)
缺 = [x["语言键"] for x in 槽 if x["语言键"] not in 语]
if 缺:
    raise SystemExit("动作槽缺语言键，别自造文案：%s" % 缺[:6])
for x in 槽:
    x["文"] = 语[x["语言键"]]
io.open(出, "w", encoding="utf-8").write(json.dumps(
    {"序": texts, "表": 表, "槽": 槽,
     "出处": "KeyDef.as:297-815（KEYBOARD_TEXTS/KEYBOARD_BTNS 按下标配对）、817-1009（BASE_SHORTCUT_KEYS）"},
    ensure_ascii=False, indent=1))
print("键位表：%d 条、动作槽 %d 条 → 数据/界面/键位表.json；不可绑 %d 条"
      % (len(表), len(槽), sum(1 for v in 表.values() if not v["canSet"])))
for k in ("esc", "space", "shiftLeft", "arrowUp"):
    print("   %-10s %s" % (k, 表[k]))
