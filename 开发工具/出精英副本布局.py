# -*- coding: utf-8 -*-
"""算「精英副本」窗（原版 `EliteCopyWindow.as` 500×426）的逐件布局
→ `数据/界面/精英副本_布局.json`。

**为什么单独落一份 JSON**：原版那套格子排布是 `createCell()`（`:101-149`）里一个
**带状态的循环**（`colCount` 从 4 偷偷变成 5、`i==5` 被单独排除、第 4 枚之后 x 少加一个 84），
用 GDScript 的 `const` 写不出来（const 不许是表达式），用 Python 再抄一遍又会和量具漂。
所以只算一次、三方（量具 / 生成器 / 控制器）共读这一份。

原版算法逐行照抄（**包括那两个看着像 bug 的地方**，不许"顺手修好"）：
    var _loc2_ = 0; var _loc3_ = 5; var colCount = 4; hgap = 10
    for each (data in maps):
        if (i % colCount == 0 && i > 0 && i != 5)            # :114
            line = LineHPicF; line.x = 0; line.y = _loc3_+120+8; line.width = 滚动区宽; line.height = 2
            _loc3_ = line.y + line.height + 8                # :122
        if (i >= 4) {
            if (i == 4) { x = 84*(i%colCount) + hgap*(i%colCount); colCount = 5 }   # :126-129
            else        { x = 84 + 84*(i%colCount) + hgap*(i%colCount) }            # :133
        } else              { x = 84 + 84*(i%colCount) + hgap*(i%colCount) }        # :138
        y = _loc3_
    ⇒ 第 1 行只有 4 枚（x=84/178/272/366），第 2 行起 5 枚、且**该行的第一枚落在 x=0**
      （正好压在左侧副本名下面）—— 5 枚以上的那几页实机就是这个样子。

副本名（`:300-305`）：`height = textHeight + 5`、`y = 子面板.y + (110 − height)/2`；
文字 = `ELITECOPY_WINDOW_COPYNAME` 填 (name, reqLevel)，宽 84 居中折行。
"""
import io
import json
import math
import os
import sys

from PIL import Image

sys.stdout.reconfigure(encoding="utf-8")
工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(工程, "开发工具"))
import 原版数据  # noqa: E402

落 = os.path.join(工程, "数据", "界面", "精英副本_布局.json")
配置 = json.load(io.open(os.path.join(工程, "数据", "副本.json"), encoding="utf-8"))
文案 = json.load(io.open(os.path.join(工程, "数据", "界面", "副本_文案.json"), encoding="utf-8"))
怪物 = json.load(io.open(os.path.join(工程, "数据", "怪物.json"), encoding="utf-8"))
头像 = json.load(io.open(os.path.join(工程, "数据", "角色", "怪物头像.json"), encoding="utf-8"))

## 与 `导出副本配置.py` 同一个源根：头像的 `link` 兜底要读 GameData 的 Mob 段，
## `数据/怪物.json` 里没有 `link` 字段。
源根 = os.environ.get("NARUTO_FUBEN_ROOT") or os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "..", "2.2.3")
_Mob: dict = {}


def Mob段() -> dict:
    global _Mob
    if not _Mob:
        dat = os.path.join(源根, "www", "act_web_nya_208_isolated", "dat", "GameData.dat")
        if not os.path.isfile(dat):
            raise SystemExit("找不到 GameData.dat：" + dat)
        原版数据.原版根 = 源根
        原版数据.dat目录 = os.path.dirname(dat)
        原版数据.数据源 = dat
        _Mob = {k: 原版数据.解载荷(v) for k, v in 原版数据.取顶层段("Mob").items()}
    return _Mob


def 头像编号(boss: int) -> tuple:
    """`PicTool.getMonsterObject`（`PicTool.as:52-92`）的 `info.link` 分支（`:76-88`）：

        else if (o && o.info && o.info.link) {
            base = ImgUtil.getImg(ImgType.Mob, o.info.link);
            o = deepClone(base);  o.info = 自己.info;
            if (base.info && base.info.portrait != null) o.info.portrait = base.info.portrait;
        }

    ⇒ **BOSS 自己没有头像时，画的是它 link 的那个基础怪的头像**。
    2026-10-03 实测：5200001~5200014、5200045 这 15 个精英副本 BOSS 自己 `info.portrait` 都是
    null，但 `info.link` 分别指向 1000016 / 2000001~2000023 那些**有头像**的怪 ⇒
    不接这条兜底就会满屏空圈（用户报的 bug1）。返回 (取图用的怪号, 链接到的怪号)。
    """
    o = Mob段().get(str(boss)) or {}
    info = (o.get("info") or {}) if isinstance(o.get("info"), dict) else {}
    if info.get("portrait"):
        return boss, None
    链 = info.get("link")
    if 链:
        底 = Mob段().get(str(int(链))) or {}
        底info = (底.get("info") or {}) if isinstance(底.get("info"), dict) else {}
        if 底info.get("portrait"):
            return int(链), boss
    return boss, None

格宽, 格高 = 84, 124
滚动宽 = 478		# `newBackground` `:380` background3.width = 内容底宽 − 10 = 488 − 10
子面板y = 65
行高字 = 17
名宽 = 84
每行字 = 6		# 84 宽 / 12px 汉字 = 7 字，但 Flash 的 7 字 textWidth 超 84 ⇒ 实机折成 6+1
缺图 = []


def 格排(枚数):
    """照抄 `createCell()` 的循环，返回 [(x, y, 是否新行线)] 与内容高。"""
    列, 距, y, 出, 线 = 4, 10, 5, [], []
    for i in range(枚数):
        if i % 列 == 0 and i > 0 and i != 5:
            线.append([0, y + 120 + 8, 滚动宽, 2])
            y = 线[-1][1] + 2 + 8
        if i >= 4:
            if i == 4:
                x = 格宽 * (i % 列) + 距 * (i % 列)
                列 = 5
            else:
                x = 格宽 + 格宽 * (i % 列) + 距 * (i % 列)
        else:
            x = 格宽 + 格宽 * (i % 列) + 距 * (i % 列)
        出.append([x, y])
    return 出, 线, (出[-1][1] + 格高 if 出 else 0)


def 名文本(条):
    """`ELITECOPY_WINDOW_COPYNAME` 填两个占位符 ⇒ 绿名 + 蓝（N级），中间一个换行。"""
    return (文案["ELITECOPY_WINDOW_COPYNAME"]
            .replace("%1", 条["name"]).replace("%2", str(条["reqLevel"])))


def 主():
    页 = []
    for 序, 条 in enumerate(配置["精英"]):
        位, 线, 高 = 格排(len(条["maps"]))
        名行 = max(1, math.ceil(len(条["name"]) / float(每行字))) + 1
        名高 = 行高字 * 名行 + 5
        格 = []
        for i, 图 in enumerate(条["maps"]):
            怪 = 怪物.get(str(图["bossId"]), {})
            全名 = str(怪.get("name", ""))
            # ⚠ 头像按 `getMonsterObject` 的 link 兜底取（见 头像编号() 的注）：
            #   名字用 BOSS 自己的（木叶叛忍），脸用 link 那个基础怪的（2000001 的头像）。
            用号, 链号 = 头像编号(int(图["bossId"]))
            头 = 头像.get(str(用号))
            # `PortraitHead.as:80-89` + `:94`：`_w/_h` 传的是 -1 ⇒ **不缩放**，位图按**自己原生尺寸**
            # 画，再用 `_origin` 把「原点」对到 PortraitHead 那个位置（`EliteCopyWindowCell.as:60-61`
            # x = 84>>1 = 42、y = (81>>1)−4 = 36）⇒ 格内左上角 = (42−origin.x, 36−origin.y)。
            # ⚠ 每张头像的原生尺寸都不一样（实测 62×62 / 54×54 / 54×53 / 41×54 / 51×51 …），
            #   塞进一个固定 62×62 的框里拉伸会把小的放大变形（用户 2026-10-03 报的图1 vs 图2）。
            头尺 = [0, 0]
            头位 = [0, 0]
            图路 = ""
            if 头 is not None:
                类名 = 头["class"]
                图路 = "res://素材/原版直解/Mob/%s.swf_1_%s.png" % (类名, 类名)
                盘 = os.path.join(工程, "素材", "原版直解", "Mob",
                                  "%s.swf_1_%s.png" % (类名, 类名))
                if not os.path.isfile(盘):
                    raise SystemExit("头像索引说 %s 有图但文件不在：%s" % (用号, 盘))
                头尺 = list(Image.open(盘).size)	# 原生像素尺寸，不缩放
                头位 = [42 - int(头["origin"]["x"]), 36 - int(头["origin"]["y"])]
            格.append({
                "序号": i + 1, "x": 位[i][0], "y": 位[i][1],
                "copyId": 图["copyId"], "mapid": 图["mapid"], "bossId": 图["bossId"],
                # `EliteCopyWindowCell.as:48-55`：名字表里的「【BOSS】」前缀要剥掉（6 个字符）
                "名": 全名[6:] if 全名.startswith("【BOSS】") else 全名,
                "章": 文案["CHAPTER"].replace("%1", str(i + 1)),
                "次数": 文案["ELITE_COPY_CELL_COUNT"].replace("%1", "0").replace("%2", "3"),
                "头像": 图路,
                "头像怪": 用号, "链接自": 链号,
                "头像尺寸": 头尺, "头像位": 头位,
                "头像原点": 头["origin"] if 头 else None})
            if 头 is None:
                缺图.append("%s（第%d章 %s）" % (图["bossId"], i + 1, 条["tabName"]))
        页.append({"页号": 序, "页签": 条["tabName"], "副本名": 条["name"],
                   "reqLevel": 条["reqLevel"], "名文本": 名文本(条), "名行": 名行, "名高": 名高,
                   "名y": 子面板y + int((110 - 名高) / 2.0),
                   "格": 格, "线": 线, "内容高": max(336, 高)})
    体 = {"_说明": "由 `开发工具/出精英副本布局.py` 按 `EliteCopyWindow.as:101-149` 现算，别手改。",
          "_公式": {"格": [格宽, 格高], "起始y": 5, "列数初值": 4, "列数改值": 5, "hgap": 10,
                   "线宽": 滚动宽, "线高": 2, "线前留": 120, "线后留": 8,
                   "名宽": 名宽, "名行高": 行高字, "名每行字": 每行字, "名居中框": 110,
                   "子面板y": 子面板y},
          "页": 页}
    io.open(落, "w", encoding="utf-8", newline="\n").write(json.dumps(体, ensure_ascii=False, indent=1))
    print("出 %s：%d 页、格 %d 枚" % (os.path.relpath(落, 工程), len(页),
                                          sum(len(p["格"]) for p in 页)))
    for p in 页:
        print("  页%d %-8s 名y=%d 名高=%d 格 %s 线 %d 内容高 %d" % (
            p["页号"], p["页签"], p["名y"], p["名高"],
            [(g["x"], g["y"]) for g in p["格"]], len(p["线"]), p["内容高"]))
    尺寸种 = sorted({(g["头像尺寸"][0], g["头像尺寸"][1])
                    for 页 in 页 for g in 页["格"] if g["头像尺寸"]})
    print("  头像原生尺寸共 %d 种：%s" % (
        len(尺寸种), " ".join("%dx%d" % t for t in 尺寸种)))
    for 页 in 页:
        for g in 页["格"]:
            print("    %-6s 第%d章 %-12s 取图 %s  %dx%d @(%d,%d)" % (
                页["页签"], int(g["序号"]), g["名"], g["头像怪"],
                g["头像尺寸"][0], g["头像尺寸"][1], g["头像位"][0], g["头像位"][1]))
    if 缺图:
        print("!! 缺头像 %d 个（原版这三页实机有图、本机三份素材库都没有 ⇒ 格内头像留空）：" % len(缺图))
        for 项 in 缺图:
            print("   ", 项)


if __name__ == "__main__":
    主()
