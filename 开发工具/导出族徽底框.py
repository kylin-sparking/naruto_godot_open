# -*- coding: utf-8 -*-
"""导出**族徽底框**（`Effect_CharStatus_Kuang`，20×20）—— 族徽块外面那圈框。

为什么需要它
------------
原版族徽块（角色头顶 `setBangHuiFlagStyle`、地图族旗 `Flag.setIcon`）都是**两层**：

    Character.as:1447-1451   _banghuiFlgStyle.addChild(createInstance("Effect_CharStatus_Kuang"))
                             _banghuiFlgStyle.addChild(getJiaHuiPic(style))   // 18/34、(1,1)
    Flag.as:413-427          _iconPane.addChild(createInstance("Effect_CharStatus_Kuang"))
                             _iconPane.addChild(家徽)                          // 18/34、(1,1)

本工程 2026-10-14（§3.135）只画了里面那层家徽，底框当时记成"素材库里没有、本机也没有 swf 源"⇒
按"宁可不画也不编"跳过了。**2026-10-15 复查：素材在盘上，只是不在 MainLib 里**：

  * `InstanceManager.createInstance("Effect_CharStatus_Kuang")` 走的是**运行时加载的效果库**；
  * 本机 `www/act_web_nya_208_isolated/asset/effect.fws.swf` 里的 **SymbolClass 表第 4 号**
    就是它（`ffdec -export symbolClass` 出来的 `symbols.csv`：`4;"Effect_CharStatus_Kuang"`）；
  * 该 sprite 只有 1 帧、1 个子件：`DefineSprite 4 → DefineShape 3`，矩阵为单位阵（平移 0,0），
    **形状的 shapeBounds = 0..6000 twip = 20×20 px** ⇒ 原版就是在 20×20 里画这圈框，
    家徽 `18×18` 摆在内缩 1px 处（`(1,1)`），两者严丝合缝。

用法
----
    <python> 开发工具/导出族徽底框.py        # → 素材/界面/原版窗口/家族/族徽底框.png（20×20）

寻径同 `开发工具/导出家族家徽.py`（`NARUTO_GAME_ROOT` → 本机候选）。
⚠️ 素材不进 git，新克隆要自己跑一次（族徽那 200 张同理）。
"""

import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
出目录 = os.path.join(项目根, "素材", "界面", "原版窗口", "家族")
出文件 = os.path.join(出目录, "族徽底框.png")

根候选 = [
    os.environ.get("NARUTO_GAME_ROOT", ""),
    r"2.2.3",
    r"2.2.3",
    r"2.2.3",
]
SWF相对 = os.path.join("www", "act_web_nya_208_isolated", "asset", "effect.fws.swf")
ffdec相对候选 = [
    os.path.join("tools", "ffdec_25.0.0", "ffdec-cli.exe"),
    os.path.join("tools", "ffdec_26.2.1", "ffdec-cli.exe"),
    os.path.join("ffdec_26.2.1", "ffdec-cli.exe"),
    os.path.join("ffdec_25.0.0", "ffdec-cli.exe"),
]

## `symbols.csv` 里那行：`4;"Effect_CharStatus_Kuang"`
符号号 = "4"
## `DefineShape 3` 的 shapeBounds：0..6000 twip ÷ 20 = 20 px
期望尺寸 = (20, 20)


def 主() -> int:
    根 = ""
    for 候选 in 根候选:
        if 候选 and os.path.isfile(os.path.join(候选, SWF相对)):
            根 = 候选
            break
    if not 根:
        raise SystemExit("找不到 2.2.3 参考目录（要含 %s）；用 NARUTO_GAME_ROOT 指一个。" % SWF相对)
    ffdec = ""
    for 相 in [os.environ.get("NARUTO_FFDEC", "")] + [os.path.join(根, x) for x in ffdec相对候选]:
        if 相 and os.path.isfile(相):
            ffdec = 相
            break
    if not ffdec:
        raise SystemExit("找不到 ffdec-cli.exe；用 NARUTO_FFDEC 指一个。")
    SWF = os.path.join(根, SWF相对)
    print(f"[族徽底框] 2.2.3 = {根}")
    print(f"[族徽底框] effect 库 = {SWF}")

    临时 = tempfile.mkdtemp(prefix="kuang-")
    try:
        子 = subprocess.run(
            [ffdec, "-selectid", 符号号, "-format", "sprite:png", "-export", "sprite", 临时, SWF],
            capture_output=True, text=True,
        )
        找到 = None
        for 根目录, _, 文件们 in os.walk(临时):
            for f in 文件们:
                if f.endswith(".png"):
                    找到 = os.path.join(根目录, f)
        if 找到 is None:
            print(子.stdout[-500:])
            print(子.stderr[-500:])
            raise SystemExit("ffdec 没导出 PNG（符号号变了？先在 effect.fws.swf 上跑 "
                             "`ffdec -export symbolClass` 看 symbols.csv）")
        with Image.open(找到) as im:
            图 = im.convert("RGBA")
        if 图.size != 期望尺寸:
            raise SystemExit(f"导出的尺寸是 {图.size}，与 `DefineShape 3` 的 bounds 不符"
                             f"（应为 {期望尺寸}）—— 别拿它当素材，先复核符号号。")
        # 全透明 = 画面在子符号里（ffdec 对这类符号会导空），也得拦下
        不透明 = sum(1 for p in 图.getdata() if p[3] > 0)
        if 不透明 == 0:
            raise SystemExit("导出的图整张全透明（画面在子符号里的那类符号）—— 别当素材用。")
        图.save(出文件)
        print(f"[族徽底框] 完成：{图.size} 不透明像素 {不透明} → {出文件}")
        print("[族徽底框] 跑完请接 `Godot --headless --path . --import`")
    finally:
        shutil.rmtree(临时, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(主())
