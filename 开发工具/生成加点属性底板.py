# -*- coding: utf-8 -*-
"""从原版 SWF 抽出「加点属性」面板美术（符号 985 CharAddPointPaneF），做成客户端用的底板。

为什么需要它
------------
人物面板整张底板（`素材/界面/原版窗口/人物/人物属性底板.png`）是符号 987 CharPaneF 的
第 1 帧扁平渲染。987 里「加点区」那个位置同时摆着两个互斥的子面板：

  985 CharAddPointPaneF   —— 看自己时显示（加点区，AS3 `CharPane.isMyself` 里 `addPointPane`）
  986 CharPointInfoPaneF  —— 看别人时显示（只读的属性点信息，`pointInfoPane`）

`CharPane.init()` 里 `this.addPointPane.visible = this.pointInfoPane.visible = false;`，
但第 1 帧的时间轴摆位让 FFDec 把 **986** 烘进了底板。客户端练的是「看自己」，要的是 985，
于是底板上 986 的绿条与橙色 Button 占位就穿帮了。

本脚本把 985 单独导出，并抹掉两类 **SWF 作者期的占位内容**——它们在运行时一定会被
AS3 换成真实内容，不是原版画面的一部分：

  1. 五行标签的橙色虚线占位（运行时由 `CharAddPointPane._jiaDianShuXing` /
     `CharInfoCell.init` 换成「加点属性 / 攻击型 / 防御型 / 灵巧型 / 健体型 / 潜能点」）
  2. 两个烘焙的 MButton（橙色 "Button" 字样，运行时由 MButton3 换成灰底皮肤 +
     「确定 / 推荐」，且宽度 57 → 34，见 `CharAddPointPane` 构造函数）

抹除是「同色回填」：用同一行里最近的非占位像素的颜色与透明度回填，不新造颜色。
被 MButton 压住的那一小段箱体右边框，用同一列干净处的像素补回。

用法
----
    python 开发工具/生成加点属性底板.py

产物
----
    素材/界面/原版窗口/人物/角色/加点属性底板.png   （191×136，带 alpha）
    放置位置：原版人物属性面板 (241, 226)
"""

import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FFDEC = r"ffdec-cli"
SWF = r"2.2.3\www\act_web_nya_208_isolated\asset\MainLib.swf"
符号ID = 985
产物 = os.path.join(项目根, "素材", "界面", "原版窗口", "人物", "角色", "加点属性底板.png")

# 985 局部坐标下，标签占位（橙色虚线）所在的那一列
标签列 = (4, 45)
# 985 局部坐标下，两个烘焙 MButton 占据的矩形（含右侧溢出箱体的部分）
按钮区 = (86, 112, 192, 134)  # x0, y0, x1, y1（不含 y1）
# 箱体右边框所在的列（按钮区里被压住，需要补回）
右边框列 = (171, 172)
# 用于取「干净右边框」的参考行——该行处在这两行的按钮之外
参考行 = 60


def 是占位橙(p):
    """标签占位是橙色字（含抗锯齿边缘）。

    实测该列里箱体/行底的暗棕底色 r-b 最大 25、r-g 最大 17，而占位橙
    （含边缘）r-b 最小 32、r-g 最小 20，中间是空的，取 32/20 分界。
    """
    r, g, b, a = p
    return a > 0 and r - b >= 32 and r - g >= 20


def 抹掉标签占位(im):
    px = im.load()
    x0, x1 = 标签列
    改 = 0
    for y in range(16, 134):
        行 = [px[x, y] for x in range(x0, x1)]
        for i, p in enumerate(行):
            if not 是占位橙(p):
                continue
            # 同行就近取一个非占位像素回填（先左后右）
            源 = None
            for j in range(i - 1, -1, -1):
                if not 是占位橙(行[j]):
                    源 = 行[j]
                    break
            if 源 is None:
                for j in range(i + 1, len(行)):
                    if not 是占位橙(行[j]):
                        源 = 行[j]
                        break
            if 源 is None:
                源 = (0, 0, 0, 0)
            px[x0 + i, y] = 源
            行[i] = 源  # 后面的占位像素就以刚回填的值为左邻，整条虚线一并抹平
            改 += 1
    return 改


def 抹掉烘焙按钮(im):
    px = im.load()
    x0, y0, x1, y1 = 按钮区
    x1 = min(x1, im.width)
    y1 = min(y1, im.height)
    for y in range(y0, y1):
        for x in range(x0, x1):
            px[x, y] = (0, 0, 0, 0)
    # 补回箱体右边框（它被按钮压住了，实际画面里应当存在）
    for x in 右边框列:
        if x >= im.width:
            continue
        src = px[x, 参考行]
        for y in range(y0, y1):
            px[x, y] = src
    return (x1 - x0) * (y1 - y0)


def main():
    if not os.path.exists(FFDEC):
        print("找不到 ffdec-cli：%s" % FFDEC)
        return 1
    if not os.path.exists(SWF):
        print("找不到原版 SWF：%s" % SWF)
        return 1

    临时 = tempfile.mkdtemp(prefix="addpoint_")
    try:
        r = subprocess.run(
            [FFDEC, "-selectid", str(符号ID), "-format", "sprite:png",
             "-export", "sprite", 临时, SWF],
            capture_output=True, text=True, encoding="utf-8", errors="replace")
        if r.returncode != 0 or "Exported frame" not in (r.stdout or ""):
            print("ffdec 导出失败：\n%s\n%s" % (r.stdout, r.stderr))
            return 1
        源 = None
        for 目录, _, 文件们 in os.walk(临时):
            for f in 文件们:
                if f == "1.png":
                    源 = os.path.join(目录, f)
        if 源 is None:
            print("ffdec 没有产出 1.png")
            return 1

        im = Image.open(源).convert("RGBA")
        print("导出符号 %d：%s %s" % (符号ID, im.size, os.path.basename(os.path.dirname(源))))

        改标签 = 抹掉标签占位(im)
        改按钮 = 抹掉烘焙按钮(im)
        print("抹掉标签占位像素 %d 个；抹掉烘焙 MButton 区域 %d 像素并补回右边框" % (改标签, 改按钮))

        os.makedirs(os.path.dirname(产物), exist_ok=True)
        im.save(产物)
        print("已写出 %s" % 产物)
        return 0
    finally:
        shutil.rmtree(临时, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
