# -*- coding: utf-8 -*-
"""读 SWF 符号时间轴 —— **几何真值的唯一权威源**。

背景（见《开发记录（本地）》§0.0b 的「重要更正」）：
    扁平导出（`-export sprite` 出 PNG）给的是**作者期某一帧的像素**，
    不能拿来当几何/版式依据；真值在 `-swf2xml` 的**时间轴矩阵**里。

用法：
    # 0) 先生成 XML（只需一次，33MB）
    cd 2.2.3
    ./ffdec_26.2.1/ffdec-cli.exe -swf2xml \
        "www/act_web_nya_208_isolated/asset/MainLib.swf" ".scratch/MainLib.xml"

    # 1) 看某个符号的全部子件（按 id 或类名）
    python 开发工具/读符号时间轴.py --符号 905
    python 开发工具/读符号时间轴.py --类名 SkillDetailPaneF

    # 2) 查类名 ↔ 符号 id
    python 开发工具/读符号时间轴.py --查类名 Skill
    python 开发工具/读符号时间轴.py --列符号            # 列出全部有类名的 DefineSprite

    # 3) 递归展开（子件也是 sprite 时，继续往下打一层）
    python 开发工具/读符号时间轴.py --符号 930 --深度 2

    # 4) 换素材包。符号不止在 MainLib 里，还有一套运行时素材包 UISwf_Text.swf，
    #    凡 BaseUtil.getImageText(CN.XXX) 取的图都在那边（破碎角标、热卖/新/限时图标、
    #    各类按钮皮肤…）。查不到时可换 --源 再试：
    python 开发工具/读符号时间轴.py --源 UISwf_Text --查类名 Broken
    python 开发工具/读符号时间轴.py --源 UISwf_Text --边界 105     # EqpBrokenF 25x16
    #    该包的 XML 同样先生成一次：
    #    ./ffdec_26.2.1/ffdec-cli.exe -swf2xml \
    #        "www/act_web_nya_208_isolated/swf/UISwf/UISwf_Text.swf" ".scratch/UISwf_Text.xml"

单位：XML 里是 **twips（1/20 px）**，本工具已 ÷20 输出 px。
"""

import argparse
import bisect
import re
import sys
from pathlib import Path

## 符号不止在 MainLib 里 —— 还有一套**运行时素材包** `UISwf_Text.swf`，
## 凡 `BaseUtil.getImageText(CN.XXX)` 取的图都在那边（`EqpBrokenF`、`QuanIcon`、
## `IconHot`、各类按钮皮肤…）。2026-09-21 找"破碎图"时才发现，此前一直查不到。
SWF_根 = r"2.2.3\www\act_web_nya_208_isolated"
XML_目录 = r".scratch"

## --源 <名> → (XML 路径, 出 XML 要用的 SWF 路径)
源表 = {
    "MainLib": (rf"{XML_目录}\MainLib.xml", rf"{SWF_根}\asset\MainLib.swf"),
    "UISwf_Text": (rf"{XML_目录}\UISwf_Text.xml", rf"{SWF_根}\swf\UISwf\UISwf_Text.swf"),
}
源_默认 = "MainLib"
XML_默认 = 源表[源_默认][0]

_ITEM_OPEN = re.compile(r"<item(\s[^>]*?)?(/?)>")
_ATTR = re.compile(r'([\w:]+)="([^"]*)"')


def 读XML(路径):
    return Path(路径).read_text(encoding="utf-8", errors="replace")


def 建类名表(文本):
    """SymbolClassTag：<tags> 一串 id、<names> 一串类名，按下标对应。"""
    i = 文本.find('type="SymbolClassTag"')
    名表 = {}
    while i > 0:
        块 = 文本[i : i + 4_000_000]
        j = 块.find("</tags>")
        if j < 0:
            break
        ids = re.findall(r"<item>(\d+)</item>", 块[:j])
        k = 块.find("</names>")
        names = re.findall(r"<item>([^<]*)</item>", 块[j:k])
        for n, 名 in zip(ids, names):
            if 名:
                名表[int(n)] = 名
        i = 文本.find('type="SymbolClassTag"', i + 1)
    return 名表


def _配对结束(文本, 起):
    """从 <item ...> 的起始位置起，返回该 item 的结束下标（含 </item>）。"""
    d = 0
    pos = 起
    while True:
        mo = _ITEM_OPEN.search(文本, pos)
        mc = 文本.find("</item>", pos)
        if mo and (mc < 0 or mo.start() < mc):
            自 = mo.group(2) == "/"
            if not 自:
                d += 1
                if d == 1:
                    起 = mo.start()
            pos = mo.end()
            if 自 and d == 0:
                return mo.end()
            continue
        if mc >= 0:
            if d == 0:
                return mc + 1  # 不该发生
            d -= 1
            pos = mc + 7
            if d == 0:
                return pos
        return len(文本)


def 取符号块(文本, 符号id):
    头 = re.search(r'<item type="DefineSpriteTag"[^>]*\bspriteId="%d">' % 符号id, 文本)
    if not 头:
        return None
    return 文本[头.start() : _配对结束(文本, 头.start())]


def 取任意块(文本, 字符id):
    """任意 characterId 的 item 块（shape / sprite / edittext / bitmap）。"""
    # ⚠️ 不能在 %d 后面要求 ">"：attribute 顺序不固定（DefineEditTextTag 的 characterID 在中间）
    头 = re.search(r'<item type="(Define\w+Tag)"[^>]*?\b(?:characterID|characterId|shapeId|spriteId)="%d"'
                   % 字符id, 文本)
    if not 头:
        return None, None
    return 头.group(1), 文本[头.start() : _配对结束(文本, 头.start())]


def _矩形(a):
    return (_数(a.get("Xmin")), _数(a.get("Ymin")), _数(a.get("Xmax")), _数(a.get("Ymax")))


def 字符边界(文本, 字符id, 缓存=None):
    """→ (x0,y0,x1,y1) 单位 px。sprite 会递归合并子件（按矩阵变换）。"""
    缓存 = 缓存 if 缓存 is not None else {}
    if 字符id in 缓存:
        return 缓存[字符id]
    缓存[字符id] = None  # 防环
    类, 块 = 取任意块(文本, 字符id)
    if 类 is None:
        return None
    结果 = None
    m = re.search(r'<(?:shapeBounds|bounds)\b([^>]*)>', 块) or re.search(r"<(?:shapeBounds|bounds)\b([^>]*)>", 块)
    if m and 类 != "DefineSpriteTag":
        x0, y0, x1, y1 = _矩形(dict(_ATTR.findall(m.group(1))))
        结果 = (x0 / 20.0, y0 / 20.0, x1 / 20.0, y1 / 20.0)
    elif 类 == "DefineBitsLossless2Tag" or 类 == "DefineBitsJPEG3Tag":
        w, h = _数(re.search(r'bitmapWidth="(\d+)"', 块).group(1)), _数(re.search(r'bitmapHeight="(\d+)"', 块).group(1))
        mb = re.search(r'<bounds\b([^>]*)>', 块)
        if mb:
            x0, y0, x1, y1 = _矩形(dict(_ATTR.findall(mb.group(1))))
            结果 = (x0 / 20.0, y0 / 20.0, x1 / 20.0, y1 / 20.0)
        else:
            结果 = (0.0, 0.0, w, h)
    elif 类 == "DefineSpriteTag":
        xs, ys, xe, ye = [], [], [], []
        for f in 解析时间轴(块):
            for p in f["放置"]:
                if not p["元件"]:
                    continue
                b = 字符边界(文本, p["元件"], 缓存)
                if b is None:
                    continue
                xs.append(p["x"] + b[0] * p["缩放X"])
                ys.append(p["y"] + b[1] * p["缩放Y"])
                xe.append(p["x"] + b[2] * p["缩放X"])
                ye.append(p["y"] + b[3] * p["缩放Y"])
        if xs:
            结果 = (min(xs), min(ys), max(xe), max(ye))
    缓存[字符id] = 结果
    return 结果


def _数(v, 默认=0.0):
    try:
        return float(v)
    except (TypeError, ValueError):
        return 默认


def 解析时间轴(块):
    """→ [{'序号':i,'标签':None|str,'放置':[{...}],'移除':[depth]}]"""
    帧 = [{"序号": 0, "标签": None, "放置": [], "移除": []}]
    # subTags 里逐个 item
    i = 块.find("<subTags>")
    if i < 0:
        return 帧
    正文 = 块[i:]
    pos = 0
    while True:
        m = _ITEM_OPEN.search(正文, pos)
        if not m:
            break
        头 = m.group(0)
        自 = m.group(2) == "/"
        起 = m.start()
        终 = m.end() if 自 else _配对结束(正文, 起)
        体 = 正文[起:终]
        a = dict(_ATTR.findall(头))
        t = a.get("type", "")
        pos = 终
        if t == "ShowFrameTag":
            帧.append({"序号": len(帧), "标签": None, "放置": [], "移除": []})
            continue
        if t == "FrameLabelTag":
            名 = re.search(r'name="([^"]*)"', 头) or re.search(r"<name>([^<]*)</name>", 体)
            if 名 and 帧:
                帧[-1]["标签"] = 名.group(1)
            continue
        if t == "RemoveObject2Tag":
            帧[-1]["移除"].append(int(a.get("depth", -1)))
            continue
        if t in ("PlaceObject2Tag", "PlaceObject3Tag", "PlaceObject4Tag"):
            mat = re.search(r"<matrix\b([^>]*)>?", 体)
            ma = dict(_ATTR.findall(mat.group(1))) if mat else {}
            项 = {
                "深度": int(a.get("depth", -1)),
                "元件": int(a["characterId"]) if a.get("characterId") else None,
                "名称": a.get("name"),
                "移动": a.get("placeFlagMove") == "true",
                "x": _数(ma.get("translateX")) / 20.0,
                "y": _数(ma.get("translateY")) / 20.0,
                "缩放X": _数(ma.get("scaleX"), 1.0),
                "缩放Y": _数(ma.get("scaleY"), 1.0),
                "旋转": _数(ma.get("rotateSkew0")),
                "有矩阵": mat is not None,
            }
            if a.get("placeFlagHasColorTransform") == "true":
                ct = re.search(r"<colorTransform\b([^>]*)/?>", 体)
                if ct:
                    项["颜色"] = " ".join(f"{k}={v}" for k, v in _ATTR.findall(ct.group(1)) if v not in ("0", "1.0", "256"))
            帧[-1]["放置"].append(项)
            continue
    while 帧 and not 帧[-1]["放置"] and not 帧[-1]["移除"] and 帧[-1]["标签"] is None and len(帧) > 1:
        帧.pop()
    return 帧


def 打时间轴(符号id, 块, 类名表, 文本, 深度, 最多深度, 前缀="", 已见=None):
    已见 = 已见 or set()
    gm = re.search(r'frameCount="(\d+)"', 块)
    类 = 类名表.get(符号id)
    名 = f"{符号id}" + (f"  {类}" if 类 else "")
    行 = [f"{前缀}符号 {名}  帧数={gm.group(1) if gm else '?'}"]
    帧s = 解析时间轴(块)
    子件 = []
    for f in 帧s:
        if f["标签"]:
            行.append(f"{前缀}  [标签] 帧{f['序号']} = {f['标签']}")
        if f["移除"]:
            行.append(f"{前缀}  帧{f['序号']}: 移除 depth {f['移除']}")
        if f["放置"]:
            行.append(f"{前缀}  帧{f['序号']}:")
            for p in f["放置"]:
                pc = 类名表.get(p["元件"]) if p["元件"] else None
                标 = f"#{p['元件']}" + (f" {pc}" if pc else "")
                if p["元件"] is None:
                    标 = "(沿用上一帧)"
                缩 = ""
                if abs(p["缩放X"] - 1) > 1e-6 or abs(p["缩放Y"] - 1) > 1e-6:
                    缩 = f" 缩放({p['缩放X']:g},{p['缩放Y']:g})"
                移 = " [move]" if p["移动"] else ""
                名2 = f" name={p['名称']}" if p["名称"] else ""
                色 = f" {p['颜色']}" if p.get("颜色") else ""
                行.append(
                    f"{前缀}    d{p['深度']:>3}  {标:<28} @({p['x']:g},{p['y']:g}){缩}{名2}{移}{色}"
                )
                if p["元件"]:
                    子件.append(p["元件"])
    print("\n".join(行))
    if 深度 < 最多深度:
        换 = "\n"
        for cid in sorted(set(子件)):
            if cid in 已见:
                continue
            b = 取符号块(文本, cid)
            if not b:
                continue  # 不是 sprite（shape/图形）
            print(f"{前缀}  └─ 展开 #{cid}")
            打时间轴(cid, b, 类名表, 文本, 深度 + 1, 最多深度, 前缀 + "  ", 已见 | {cid})


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("--符号", type=int)
    ap.add_argument("--类名")
    ap.add_argument("--查类名", dest="查类名")
    ap.add_argument("--列符号", action="store_true")
    ap.add_argument("--边界", type=int, help="算某字符的包围盒（px，符号坐标系）")
    ap.add_argument("--深度", type=int, default=0)
    ap.add_argument("--源", default=源_默认, help="素材包：%s（默认 %s）" % ("/".join(源表), 源_默认))
    ap.add_argument("--xml", default=None, help="直接指定 XML（覆盖 --源）")
    ap.add_argument("-h", "--help", action="help")
    参 = ap.parse_args()

    if 参.xml is not None:
        pass
    elif 参.源 in 源表:
        参.xml = 源表[参.源][0]
    else:
        sys.exit("未知的 --源 %r，可用：%s" % (参.源, "、".join(源表)))

    if not Path(参.xml).is_file():
        提示 = ""
        if 参.源 in 源表:
            swf = 源表[参.源][1]
            提示 = ("\n先生成（只需一次）：\n"
                    "  cd 2.2.3\n"
                    '  ./ffdec_26.2.1/ffdec-cli.exe -swf2xml "%s" "%s"' % (swf, 参.xml))
        sys.exit("找不到 XML：%s%s" % (参.xml, 提示))

    文本 = 读XML(参.xml)
    类名表 = 建类名表(文本)
    反查 = {}
    for k, v in 类名表.items():
        反查.setdefault(v, k)

    if 参.列符号:
        for k in sorted(类名表):
            if f'spriteId="{k}"' in 文本:
                print(f"{k}\t{类名表[k]}")
        return

    if 参.查类名:
        for 名, k in sorted(反查.items()):
            if 参.查类名.lower() in 名.lower():
                print(f"{k}\t{名}")
        return

    if 参.边界 is not None:
        b = 字符边界(文本, 参.边界)
        if b is None:
            sys.exit(f"算不出 #{参.边界} 的边界（不存在或不可解析）")
        类, _ = 取任意块(文本, 参.边界)
        print("#%d %s 包围盒 (%g,%g)-(%g,%g)  %g x %g"
              % (参.边界, 类 or "?", b[0], b[1], b[2], b[3], b[2] - b[0], b[3] - b[1]))
        return

    符号id = 参.符号
    if 参.类名:
        符号id = 反查.get(参.类名)
        if 符号id is None:
            for 名, k in 反查.items():
                if 参.类名.lower() in 名.lower():
                    print(f"未精确命中，候选：{k} {名}", file=sys.stderr)
            sys.exit(f"找不到类名 {参.类名}")
    if 符号id is None:
        ap.print_help()
        return
    块 = 取符号块(文本, 符号id)
    if not 块:
        sys.exit("XML 里没有 spriteId=%d 的 DefineSpriteTag（可能不是 sprite）。\n"
                 "⚠️ 也可能它在**另一个素材包**里 —— 换 --源 再试：%s"
                 % (符号id, "、".join(源表)))
    打时间轴(符号id, 块, 类名表, 文本, 0, 参.深度)


if __name__ == "__main__":
    main()
