# -*- coding: utf-8 -*-
"""导出**全部意志**的图标与图鉴数据表（用户 2026-09-28 要求："把意志也做出来，
不需要连服务端，美术端有这些意志就行，群主接服务端时能直接学出来"）。

三份真值，逐条有出处：
  * `原版源数据/GameData.dat.json` 的 `Spirit.items`（47 条）
      - `spec.attrType` 属性类型、`spec.color` 品质名、`spec.attrValues.levelN` 各阶数值
      - `info.price` 售价、`info.reqLevel` 需求等级
      - `info.icon.value.className` = `Spirit_<id>_info_icon` ⇒ 图标**不在 dat 里**，是运行期 SWF 的位图
  * 同文件 `String.Spirit`（47 条）：`name` / `desc`（`StringTool.getYiZhiString(id)` 读的就是这张）
  * 图标：`<原版目录>/www/act_web_nya_208_isolated/swf/Spirit/Spirit_<id>_info.swf`
      用 `ffdec -format image:png -export image` 解，实测 **56×56 RGBA**
      —— 正好等于意志格里的图标位（`YiZhiStudyCell:73-75` 的 `_icon` x=y=3、格 62×62）

品质色映射（逐行核过，不许换成"看着像"的调色板）：
  `YiZhiData.setColor:175-201`  dat 字符串 → SpiritColor
  `YiZhiData.setTextColor:204-239`  SpiritColor → textColor + speed（图标转圈速度）
  常量值在 `UIConfig.as:926-940`。

产出两样：
  `素材/界面/意志图标/<id>.png`（原名一并留在 元件图 归档里）
  `数据/意志图鉴.json`  {id: {name, desc, detailDesc, color, textColor, speed, attrType,
                              attrValues, price, reqLevel, icon}}

用法：python 开发工具/导出意志图鉴.py
"""
import json
import os
import shutil
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8")

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
根 = os.path.dirname(工程)
原版根 = os.environ.get("NARUTO_GAME_ROOT") or os.path.join(根, "2.2.3")
数据源 = os.environ.get("NARUTO_DATA_JSON") or os.path.join(根, "原版源数据", "GameData.dat.json")
图标包 = os.path.join(原版根, "www", "act_web_nya_208_isolated", "swf", "Spirit")
ffdec = os.environ.get("FFDEC_CLI") or "ffdec-cli.exe"
归档 = os.path.join(os.environ.get("NARUTO_ELEMENT_ROOT")
	or os.path.join(根, "原版源数据", "元件图"), "Spirit")
出图 = os.path.join(工程, "素材", "界面", "意志图标")
出表 = os.path.join(工程, "数据", "意志图鉴.json")

## `SpiritColor.as:6-20`：品质序号（原版 `YiZhiIntroduceWindow.drawList:70` 的
## `sortOn("color", NUMERIC|DESCENDING)` 就是按它从高到低排行）
品阶 = {"gray": 1, "green": 2, "blue": 3, "pueple": 4, "pink": 5, "yellow": 6, "red": 7, "lpink": 8}

## `YiZhiData.setTextColor:204-239` + `UIConfig.as:926-940`（十进制常量原样抄，别手算成近似）
品质 = {
    "gray":   (10066329, 0),      # #999999
    "green":  (65280, 1),         # UI_GREEN  #00FF00
    "blue":   (2003199, 3),       # UI_BLUE   #1E90FF
    "pink":   (16733336, 5),      # UI_PINK   #FF359C
    "yellow": (16773120, 3),      # UI_YELLOW #FFF000
    "pueple": (12190201, 5),      # UI_ZHI_SE #BA55D3（dat 里就拼作 pueple，别"改正"）
    "red":    (16711680, 7),      # UI_RED    #FF0000
    "lpink":  (16766720, 7),      # #FFE300
}


def 导图标(id, 讯):
    """按数据里**真正写的**图标引用解位图：`info.icon.value` = {className, swfName}。
    ⚠ 不能拿 id 去拼包名 —— 602 用的是 `Spirit_601_info`、801/802 都用 `Spirit_701_info`
      （[阴]/[阳]六道之力共用同一张图）。按 id 拼会误报"缺图标"。"""
    引 = (讯.get("icon") or {}).get("value") or {}
    包名 = 引.get("swfName") or ("Spirit_%s_info" % id)
    符号 = 引.get("className") or ("%s_icon" % 包名)
    swf = next((os.path.join(图标包, f) for f in sorted(os.listdir(图标包))
                if f.startswith(包名) and f.endswith(".swf")), None)
    if swf is None:
        return None, "缺 SWF（%s）" % 包名
    暂 = os.path.join(工程, "测试", "_暂存_意志")
    if os.path.isdir(暂):
        shutil.rmtree(暂)
    os.makedirs(暂)
    subprocess.run([ffdec, "-format", "image:png", "-export", "image", 暂, swf],
                   check=True, capture_output=True)
    张 = [f for f in os.listdir(暂) if f.endswith(".png")]
    if len(张) != 1:
        return None, "解出 %d 张（期望 1 张 %s_info_icon）" % (len(张), id)
    源 = os.path.join(暂, 张[0])
    目 = os.path.join(归档, "Spirit_%s" % id)
    os.makedirs(目, exist_ok=True)
    shutil.copyfile(源, os.path.join(目, 张[0]))            # 只读归档留一份原件
    os.makedirs(出图, exist_ok=True)
    工 = os.path.join(出图, "%s.png" % id)
    shutil.copyfile(源, 工)
    shutil.rmtree(暂)
    return 工, 张[0]


def 主():
    d = json.load(open(数据源, encoding="utf-8"))
    物 = d["Spirit"]["items"]
    名 = d["String"]["Spirit"]
    得, 坏 = {}, []
    for id in sorted(物, key=lambda x: int(x)):
        记 = 物[id]
        规 = 记.get("spec", {})
        讯 = 记.get("info", {})
        色 = 规.get("color", "")
        if 色 not in 品质:
            坏.append("%s: 品质 %r 不在 setColor 的八个分支里" % (id, 色))
            continue
        字 = 名.get(id, {})
        路, 说 = 导图标(id, 讯)
        if 路 is None:
            坏.append("%s: 图标导出失败（%s）" % (id, 说))
            continue
        文, 转 = 品质[色]
        # `YiZhiData.introduceDesc:103-113` = String.Spirit[id].desc 里的 `#value#`
        # 换成 `attrValue(2) − attrValue(1)`（即"每升一级加多少"）。没占位符的原样返回。
        值 = int(规.get("attrValues", {}).get("level2", 0)) - int(规.get("attrValues", {}).get("level1", 0))
        得[id] = {
            "name": 字.get("name", ""),
            "desc": 字.get("desc", ""),
            # `YiZhiData.detailDesc:144,244` = `StringTool.getYiZhiString(id,"detailDesc")`
            # ⇒ 就是 `String.Spirit[id].detailDesc`（意志格提示 `YiZhiTip:85,94` 用它）
            "detailDesc": 字.get("detailDesc", ""),
            "color": 色,
            "textColor": "#%06X" % 文,
            "speed": 转,
            "attrType": 规.get("attrType", ""),
            "colorRank": 品阶[色],
            "introduceDesc": 字.get("desc", "").replace("#value#", str(值)),
            "attrValues": {int(k.replace("level", "")): v for k, v in (规.get("attrValues") or {}).items()},
            "price": 讯.get("price", 0),
            "reqLevel": 讯.get("reqLevel", 0),
            "icon": "res://素材/界面/意志图标/%s.png" % id,
            # 真正引用的符号名（可能与 id 不同：602→Spirit_601_info_icon、801/802→701）
            "iconSymbol": ((讯.get("icon") or {}).get("value") or {}).get("className", ""),
            "iconSwf": ((讯.get("icon") or {}).get("value") or {}).get("swfName", ""),
        }
    if not 得:
        print("!! 一条都没导出来"); raise SystemExit(1)
    缺名 = [k for k, v in 得.items() if not v["name"]]
    if 缺名:
        坏.append("这些 id 在 String.Spirit 里没名字：%s" % 缺名)
    得["_出处"] = ("GameData.dat.json 的 Spirit.items + String.Spirit；图标 = ffdec 解 "
                    "swf/Spirit/Spirit_<id>_info.swf；品质色映射见 YiZhiData.setColor/setTextColor "
                    "与 UIConfig:926-940。由 开发工具/导出意志图鉴.py 生成，别手改。")
    得["_条数"] = len(得) - 1
    json.dump(得, open(出表, "w", encoding="utf-8"), ensure_ascii=False, indent=1, sort_keys=False)
    张数 = len([f for f in os.listdir(出图) if f.endswith(".png")])
    print("出 %s：%d 条；图标 %d 张在 %s" % (os.path.relpath(出表, 工程), 得["_条数"], 张数,
                                            os.path.relpath(出图, 工程)))
    计 = {}
    for v in 得.values():
        if isinstance(v, dict):
            计[v["color"]] = 计.get(v["color"], 0) + 1
    print("品质分布：", 计)
    样例 = [k for k in 得 if isinstance(得[k], dict)][:2]
    for k in 样例:
        print("  样例 %s：%s" % (k, json.dumps(得[k], ensure_ascii=False)[:200]))
    if 坏:
        print("!! %d 条有问题：" % len(坏))
        for b in 坏[:10]:
            print("   ", b)
        raise SystemExit(1)


if __name__ == "__main__":
    主()
