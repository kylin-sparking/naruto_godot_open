# -*- coding: utf-8 -*-
"""导出**家族家徽图**（`PicTool.getJiaHuiPic` 用的那张 34×34 图标）。

为什么需要它
------------
原版这一格走的是**运行时图像包**，不在离线素材里：

    FamillyListItemRenderer.as:85  PicTool.getJiaHuiPic(flagStyle)
    PicTool.as:503                 ImgUtil.getImg(ImgType.BangHui, "flagStyle")
    ImgUtil.as:174-180             从 ImgManager.data["BangHui"]["flagStyle"][<样式>]["icon"]["value"] 取字节
    DatLoadItem.as:84-85           ……而那份数据是 HTTP 下的 `dat/BangHui/flagStyle.dat`

⚠️ 本机的 `www/act_web_nya_208_isolated/dat/` 里**没有 BangHui 这套 dat**（单机包没带），
   所以"照别的素材那样现解"这条路走不通。**但同一件美术在客户端 swf 里躺着**：
   `swf/BangHui/BangHui_flagStyle_<样式>.swf` 里那张位图的类名就叫
   **`BangHui_flagStyle_<样式>_icon`**（ffdec 导出的文件名就带这个类名），
   尺寸 **34×34** —— 与 `PicTool.as:509` 的 `drawRect(0,0,34,34)` 严丝合缝。
   ⇒ 这是**同一件素材的另一个来源**，不是替代品。

染色：**默认不染**（2026-10-15 用户拍板）
-----------------------------------------
原版 AS3 里确实有一段染金：`PicTool.as:528-558 tintJiaHuiPicWhiteToGold` ——
逐像素，**RGB ≥ 0xE0E0E0 的换成 0xFFFF8C00**（alpha 不动）。本工程 2026-09-30 照它把
200 张全染成了橘金，并按"与实机一致"写进了 `家徽图.gd` 与 `家徽显示回归测试.gd`。

**这个结论是错的**（2026-10-15 用户并排图纠偏）：

| 来源 | 方底 | 圆盘 |
|---|---|---|
| 单机版实机（用户截图 `Snipaste_2026-10-15_04-09-43.png`） | 浅蓝 `207,215,244` | **白 `255,255,255`** |
| swf 里那张位图原色（ffdec 直出，本脚本导出的就是它） | 浅蓝 `207,215,244` | **白 `255,255,255`** |
| 本工程染色版（2026-09-30 ~ 2026-10-15 用的那批） | 浅蓝 | **橘金 `255,140,0`** |

单机版实机 = **swf 原图**，没有染金 —— 也就是 AS3 那段 `tintJiaHuiPicWhiteToGold`
在实机上**看不出来**（`_loc6_.displayContent.bitmapData = _loc2_` 那步回写没生效，
或实机那份 MainLib 与 `cur_scripts_new` 反编译的这份不同；两者都只能证明"实测没染"）。
用户 2026-10-15 的原话：**"所有使用到族徽你都不应该染色，而是直接使用素材"**。

⇒ **默认导出原色**；要复现当年那批橘金（做并排对照用），显式加 `--染色`。

用法
----
    <python> 开发工具/导出家族家徽.py              # 原色（默认）
    <python> 开发工具/导出家族家徽.py --染色        # 橘金（只为对照，别提交这批）

路径解析（换机器必须能跑）
------------------------
原版参考目录按这个顺序找：`NARUTO_GAME_ROOT` 环境变量 → 本机已知位置。
ffdec 同理（`NARUTO_FFDEC` → `<根>/tools/ffdec_25.0.0` → `<根>/ffdec_26.2.1`）。
输出目录固定 = 本仓库 `素材/界面/原版窗口/家族/`（按脚本自身位置算，不用手改）。
"""

import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

# 本文件在 开发工具/，项目根是它的上一级（同 `开发工具/服务端目录.py` 的口径）。
项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
出目录 = os.path.join(项目根, "素材", "界面", "原版窗口", "家族")

# 原版参考（2.2.3）的候选位置：环境变量优先，其余是本机出现过的那几处。
根候选 = [
    os.environ.get("NARUTO_GAME_ROOT", ""),
    r"2.2.3",
    r"2.2.3",
    r"2.2.3",
]
SWF相对 = os.path.join("www", "act_web_nya_208_isolated", "swf", "BangHui")
ffdec相对候选 = [
    os.path.join("tools", "ffdec_25.0.0", "ffdec-cli.exe"),
    os.path.join("tools", "ffdec_26.2.1", "ffdec-cli.exe"),
    os.path.join("ffdec_26.2.1", "ffdec-cli.exe"),
    os.path.join("ffdec_25.0.0", "ffdec-cli.exe"),
]

## `PicTool.as:549-551`：`(pixel & 0xFFFFFF) >= 14737632` 换成 `0xFFFF8C00`
阈值 = 0xE0E0E0
金色 = (0xFF, 0x8C, 0x00)


def 找根() -> str:
    for 候选 in 根候选:
        if 候选 and os.path.isdir(os.path.join(候选, SWF相对)):
            return 候选
    raise SystemExit("找不到 2.2.3 参考目录（要含 %s）；用 NARUTO_GAME_ROOT 指一个。" % SWF相对)


def 找ffdec(根: str) -> str:
    候选 = [os.environ.get("NARUTO_FFDEC", "")]
    候选 += [os.path.join(根, 相) for 相 in ffdec相对候选]
    for 相 in 候选:
        if 相 and os.path.isfile(相):
            return 相
    raise SystemExit("找不到 ffdec-cli.exe；用 NARUTO_FFDEC 指一个（试过：%s）。"
                     % "; ".join(x for x in 候选 if x))


def 染色(图: Image.Image) -> Image.Image:
    出 = 图.copy()
    像素 = 出.load()
    for y in range(出.height):
        for x in range(出.width):
            r, g, b, a = 像素[x, y]
            if (r << 16 | g << 8 | b) >= 阈值:
                像素[x, y] = (金色[0], 金色[1], 金色[2], a)
    return 出


def 主() -> int:
    染不染 = "--染色" in sys.argv[1:]
    根 = 找根()
    ffdec = 找ffdec(根)
    SWF目录 = os.path.join(根, SWF相对)
    print(f"[家徽] 2.2.3 参考 = {根}")
    print(f"[家徽] ffdec     = {ffdec}")
    print(f"[家徽] 染色      = {'开（对照用，别提交）' if 染不染 else '关（照单机版实机：直接用素材原色）'}")
    os.makedirs(出目录, exist_ok=True)

    样式表 = []
    for 名 in sorted(os.listdir(SWF目录)):
        if 名.startswith("BangHui_flagStyle_") and 名.endswith(".swf") and "[" not in 名:
            样式表.append(int(名[len("BangHui_flagStyle_"):-len(".swf")]))
    样式表.sort()
    print(f"[家徽] 待导出 {len(样式表)} 个样式：{样式表[0]}..{样式表[-1]}")

    临时根 = tempfile.mkdtemp(prefix="jiahui-")
    尺寸统计: dict[tuple[int, int], int] = {}
    失败 = []
    try:
        for i, 样式 in enumerate(样式表, 1):
            源 = os.path.join(SWF目录, f"BangHui_flagStyle_{样式}.swf")
            临时 = os.path.join(临时根, str(样式))
            子 = subprocess.run(
                [ffdec, "-selectid", "1", "-export", "image", 临时, 源],
                capture_output=True, text=True,
            )
            # ffdec 把结果放进 <临时>/1_BangHui_flagStyle_<样式>_icon.png
            找到 = None
            if os.path.isdir(临时):
                for f in os.listdir(临时):
                    if f.endswith(".png"):
                        找到 = os.path.join(临时, f)
                        break
            if 找到 is None:
                失败.append(样式)
                continue
            with Image.open(找到) as im:
                图 = im.convert("RGBA")
            尺寸统计[图.size] = 尺寸统计.get(图.size, 0) + 1
            (染色(图) if 染不染 else 图).save(os.path.join(出目录, f"家徽_{样式}.png"))
            if i % 25 == 0:
                print(f"[家徽] {i}/{len(样式表)} …")
    finally:
        shutil.rmtree(临时根, ignore_errors=True)

    print(f"[家徽] 完成：{len(样式表) - len(失败)} 张 → {出目录}")
    print(f"[家徽] 尺寸分布：{尺寸统计}")
    if 失败:
        print(f"[家徽] ⚠️ 这 {len(失败)} 个没导出：{失败}")
    # 尺寸不是 34×34 的话，`drawRect(0,0,34,34)` 那个前提就不成立了，得复核。
    异常 = [尺寸 for 尺寸 in 尺寸统计 if 尺寸 != (34, 34)]
    if not 染不染:
        # 原色导出后必须**一张都不含金色**；含了就说明染色没关干净（或素材本身有橘）。
        含金 = []
        for 样式 in 样式表:
            路 = os.path.join(出目录, f"家徽_{样式}.png")
            if os.path.isfile(路):
                with Image.open(路).convert("RGBA") as 图:
                    像素 = 图.load()
                    if any(像素[x, y][:3] == 金色
                           for y in range(图.height) for x in range(图.width)):
                        含金.append(样式)
        if 含金:
            print(f"[家徽] ⚠️ 这 {len(含金)} 张里有染金色 {金色}：{含金[:10]}…")
            异常.append("含染金色")
    print(f"[家徽] 跑完请接一句 `Godot --headless --path . --import`（.png 变了要重导入；"
          f"素材不进 git，其他人的克隆要自己重跑本脚本）")
    return 1 if (失败 or 异常) else 0


if __name__ == "__main__":
    sys.exit(主())
