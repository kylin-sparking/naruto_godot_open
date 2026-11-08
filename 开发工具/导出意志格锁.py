# -*- coding: utf-8 -*-
"""导出**意志背包格锁图标**（`UISwf_BailianCopy_Lack`，84×81）—— 背包锁态格上那把锁。

为什么需要它
------------
原版背包格的锁态不是"隐藏"，是 `YiZhiCell.lockCell:185-193` 实打实画出来的：

    this._state = 0;
    this.clear();
    this._bgSkin.visible = false;                                  // 格底隐
    this._icon = new UISwfMovieClipAgent("UISwf_BailianCopy_Lack",true).mcIgnoreLoading;
    this._icon.x = -10;
    this._icon.y = -16;
    addChildAt(this._icon,1);                                      // 锁画在格底层之上

对应关系（`updatePackLimit:516-534` 逐格 `lockCell/unLockCell`）：
  * 锁格 = `packLimit` 之外的格（初值 5 ⇒ 6..30 全锁）；
  * 开格 = `unLockCell:168-176`：去锁图、格底显、把悬停框加回子列表。

⚠ 坐标口径：ffdec 导出的 PNG 是**整个 sprite 的 bounds**（84×81），
  画面（那把锁）在不透明包围盒 (10,15)-(74,79) = 64×64 里。
  `_icon.x=-10 / y=-16` 是把 **MC 注册点**（bounds 左上）往左上挪，
  挪完画面正好落在格子的 (0,-1)..(64,63) —— 即工程侧照抄
  `position=(-10,-16)` + `size=(84,81)` 就是原版几何，别裁剪、别重算居中。

用法
----
    <python> 开发工具/导出意志格锁.py        # → 素材/界面/原版窗口/意志背包/格锁.png（84×81）

寻径同 `开发工具/导出族徽底框.py`（`NARUTO_GAME_ROOT` → 本机候选）。
⚠️ 素材不进 git，新克隆要自己跑一次。
"""

import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image

项目根 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
出目录 = os.path.join(项目根, "素材", "界面", "原版窗口", "意志背包")
出文件 = os.path.join(出目录, "格锁.png")

根候选 = [
    os.environ.get("NARUTO_GAME_ROOT", ""),
    r"2.2.3",
    r"2.2.3",
    r"2.2.3",
]
SWF相对 = os.path.join("www", "act_web_nya_208_isolated", "swf", "UISwf", "UISwf_BailianCopy.swf")
ffdec相对候选 = [
    os.path.join("tools", "ffdec_25.0.0", "ffdec-cli.exe"),
    os.path.join("tools", "ffdec_26.2.1", "ffdec-cli.exe"),
    os.path.join("ffdec_26.2.1", "ffdec-cli.exe"),
    os.path.join("ffdec_25.0.0", "ffdec-cli.exe"),
]

## `UISwf_BailianCopy.swf` 的 SymbolClass 表：`6;"UISwf_BailianCopy_Lack"`
符号号 = "6"
## DefineSprite 6 的 bounds：0..2520 × 0..2430 twip ÷ 30 = 84×81 px
期望尺寸 = (84, 81)
## `lockCell` 把注册点放去 (-10,-16)；画面（64×64）因此落在格内 (0,-1)..(64,63)
期望落点 = (-10, -16)


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
    print(f"[意志格锁] 2.2.3 = {根}")
    print(f"[意志格锁] UISwf 库 = {SWF}")

    临时 = tempfile.mkdtemp(prefix="lack-")
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
            raise SystemExit("ffdec 没导出 PNG（符号号变了？先在 UISwf_BailianCopy.swf 上跑 "
                             "`ffdec -export symbolClass` 看 symbols.csv）")
        with Image.open(找到) as im:
            图 = im.convert("RGBA")
        if 图.size != 期望尺寸:
            raise SystemExit(f"导出的尺寸是 {图.size}，与 `DefineSprite 6` 的 bounds 不符"
                             f"（应为 {期望尺寸}）—— 别拿它当素材，先复核符号号。")
        # 全透明 = 画面在子符号里（ffdec 对这类符号会导空），也得拦下
        不透明 = sum(1 for p in 图.getdata() if p[3] > 0)
        if 不透明 == 0:
            raise SystemExit("导出的图整张全透明（画面在子符号里的那类符号）—— 别当素材用。")
        图.save(出文件)
        print(f"[意志格锁] 完成：{图.size} 不透明像素 {不透明} → {出文件}")
        print(f"[意志格锁] 运行期挂法：TextureRect position={期望落点} size={期望尺寸} "
              f"（照 `YiZhiCell.lockCell:190-192` 的 `_icon.x/y`）")
        print("[意志格锁] 跑完请接 `Godot --headless --path . --import`")
    finally:
        shutil.rmtree(临时, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(主())
