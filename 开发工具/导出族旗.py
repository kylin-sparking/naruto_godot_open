# -*- coding: utf-8 -*-
"""导出**地图上的家族族旗**旗面（`BangHui_<等级>_stand.swf` → `素材/世界/族旗/旗_<等级>_<帧>.png`）。

原版口径
--------
    FlagHandler.addFlag(oid, info)            `game/world/handlers/FlagHandler.as:134-159`
        new Flag(info) → x/y = info.x/info.y，再按 (x, y-30) 找脚下 foothold
    Flag.initializeLook()                     `roles/Flag.as:307-322`
        mAnimation.skin = flag_level          ← **美术按"旗等级"取**（不是家徽样式）
        setAction(MobAction.stand)            ← 站着不动，只有飘动动画
        _namePane.y = 20（旗名+N级）/ _bangPane.y = 38（家族:族名）/ _iconPane（家徽 34→18）
    Flag.showHp(percent)                      `roles/Flag.as:352-366`
        头顶 CommonHpBar，10 秒后自己收

美术来源
--------
`www/act_web_nya_208_isolated/swf/BangHui/BangHui_<等级>_stand.swf` —— 里面 4 张
**DefineBitsJPEG3**（JPEG + 独立 zlib alpha）就是飘动的 4 帧。
⚠️ 本机 `dat/` 里没有 BangHui 那套 dat，所以**拿不到原版的帧偏移/注册点**，
   注册点只能自己按图量（见下面 `量旗杆` 的说明）——这一点在文件末尾也标了。

用法： python 开发工具/导出族旗.py
"""

import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib.util

_直解路 = os.path.join(os.path.dirname(os.path.abspath(__file__)), "swf位图直解.py")
_规格 = importlib.util.spec_from_file_location("swf直解", _直解路)
直解 = importlib.util.module_from_spec(_规格)
_规格.loader.exec_module(直解)

## ⚠ 原来是**一条写死的路径**（分支作者机器上的），本机没有 ⇒ 这个导出器在这台
##   机器上根本跑不起来（家族支合过来后实测）。改成候选列表，口径与
##   `导出族徽底框.py` / `导出家族家徽.py` 一致：环境变量优先，其余按"本机真有"挑。
##   ⚠ 路径字面量必须写**原始串**（r"..."）—— `\2` 会被 Python 当成八进制转义（实测踩过）。
_工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_候选根 = [
    os.environ.get("NARUTO_GAME_ROOT", ""),
    os.path.join(_工程, "..", "2.2.3"),
]
服务端根 = next(
    (根 for 根 in _候选根
     if 根 and os.path.isdir(os.path.join(根, "www", "act_web_nya_208_isolated", "swf", "BangHui"))),
    _候选根[1],
)
SWF目录 = os.path.join(服务端根, "www", "act_web_nya_208_isolated", "swf", "BangHui")
出目录 = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "素材", "世界", "族旗")
等级们 = list(range(0, 11))


def 量旗杆(图: Image.Image) -> tuple[int, int]:
    """量出旗杆的**底部中心**（= 注册点：立在地上时该点落在坐标处）。

    ⚠️ 原版这个偏移来自 `dat/BangHui/stand.dat` 的帧数据，本机没有那份 dat，
       所以只能从图里量：旗杆是一根**竖直木条**，取最下面若干行里"不透明像素的水平中位"，
       再取最底下那一行不透明像素的 y。这是**重建**，不是原值 —— 若将来拿到 dat 应改回原值。
    """
    甲 = 图.split()[-1]
    宽, 高 = 图.size
    底 = -1
    for y in range(高 - 1, -1, -1):
        if any(甲.getpixel((x, y)) > 8 for x in range(宽)):
            底 = y
            break
    if 底 < 0:
        return 宽 // 2, 高
    xs = [x for x in range(宽) if 甲.getpixel((x, 底)) > 8]
    return sum(xs) // len(xs), 底


def 主() -> int:
    if not os.path.isdir(SWF目录):
        print("找不到 %s —— 先校准 服务端根" % SWF目录)
        return 1
    os.makedirs(出目录, exist_ok=True)
    临 = tempfile.mkdtemp(prefix="旗_")
    总 = 0
    for 级 in 等级们:
        路 = os.path.join(SWF目录, "BangHui_%d_stand.swf" % 级)
        if not os.path.isfile(路):
            print("跳过 %d 级：没有 %s" % (级, os.path.basename(路)))
            continue
        批 = os.path.join(临, str(级))
        os.makedirs(批, exist_ok=True)
        直解.main(路, 批)
        帧 = []
        for 名 in os.listdir(批):
            m = re.match(r"(\d+)_BangHui_%d_stand_(\d+)\.png$" % 级, 名)
            if m:
                帧.append((int(m.group(2)), os.path.join(批, 名)))
        帧.sort()
        for 号, 源 in 帧:
            图 = Image.open(源).convert("RGBA")
            x, y = 量旗杆(图)
            图.save(os.path.join(出目录, "旗_%d_%d.png" % (级, 号)))
            print("  旗_%d_%d.png  %dx%d  注册点(杆底中心)=(%d,%d)"
                  % (级, 号, 图.width, 图.height, x, y))
            总 += 1
    shutil.rmtree(临, ignore_errors=True)
    print("共导出 %d 张到 %s" % (总, 出目录))
    return 0


if __name__ == "__main__":
    raise SystemExit(主())
