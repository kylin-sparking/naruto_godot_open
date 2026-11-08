# -*- coding: utf-8 -*-
"""对证库 —— 各页 `出*对照图.py` 共用的比对/出图原语（numpy 向量化）。

为什么要有这个文件：每页的对照脚本以前都自带一份 `九宫格拉伸/文件级/比对/条`，
一是重复劳动（9 份近亲脚本），二是 `比对` 用 `getdata()` 纯 Python 逐像素循环、
还要在 ±2 像素里搜 25 个偏移 ⇒ 一页几分钟。这里改成 numpy 数组运算，同一批判定
从分钟级降到秒级，判定口径一字未改（阈值、容差、环带、垫底、搜偏移全照旧）。

**等价性怎么保证**：`开发工具/出宝石工艺对照图.py` 已改成调用本库，重跑必须仍是
「红项 0」；那条页就是这个库的回归样本。

三个容易搞错、必须留在这里的口径：
  * `文件级` 的 RGB 阈值是 **6**，不是 0 —— 工程里的 PNG 与元件图各自重编码过，
    实测通用控件的最大通道差正好 6、超阈值 0 像素。拿 0 当门会把所有既有素材判红。
  * `比对` 只判**参照不透明**的位置，并且要能只判**边带**（`环=`）：面板中间压着文字和格子，
    整块比 = 拿皮肤去比别人的字，必然全红。`不判顶/底/右` 用来摘掉某一条被**别的件**压住的带
    （如 资讯查询 内面板的上带正好压着 LineHPicF 分隔线），摘哪条必须在调用处写清出处。
  * 半透明的皮（`MPane_background` 的边）必须先按同一套九宫格**垫上真实底**再比（`垫底=`），
    否则比的是"我合成的底"对"实机的底"。
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

__all__ = ["加亮", "九宫格拉伸", "数组", "文件级", "比对", "条", "窗口截图", "红计数类"]

_字 = None


def 字体():
    global _字
    if _字 is None:
        _字 = ImageFont.truetype(r"C:\Windows\Fonts\simhei.ttf", 14)
    return _字


def 数组(图):
    """PIL → numpy (h,w,4) uint8，RGBA。"""
    return np.asarray(图.convert("RGBA"), dtype=np.uint8)


def 加亮(图, 偏移):
    """原版 `StyleUtil.getLightFilter(d)`：R/G/B 各加 d 并 clamp，alpha 行不动。

    a==0 的全透像素 rgb 不动 —— Flash 走预乘 alpha，全透处预乘 rgb 恒 0，本来就不会亮；
    按矩阵字面执行会把 (0,0,0,0) 变成 (30,30,30,0)，一过线性过滤就渗出一圈亮边。
    """
    a = 数组(图).astype(np.int16)
    不透 = a[:, :, 3] != 0
    a[:, :, :3] += np.where(不透[:, :, None], 偏移, 0)
    np.clip(a, 0, 255, out=a)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def 九宫格拉伸(图, 宽, 高, 边距):
    """Flash `ScaleSprite` 的 `width=/height=` 语义：四角固定、四边单轴拉、中间双向拉。"""
    左, 右, 上, 下 = [int(v) for v in 边距]
    原宽, 原高 = 图.size
    右w, 下h = max(1, 原宽 - 右), max(1, 原高 - 下)
    块 = {
        "tl": (0, 0, 左, 上), "tr": (右w, 0, 原宽, 上),
        "bl": (0, 下h, 左, 原高), "br": (右w, 下h, 原宽, 原高),
        "t": (左, 0, 右w, 上), "b": (左, 下h, 右w, 原高),
        "l": (0, 上, 左, 下h), "r": (右w, 上, 原宽, 下h),
        "c": (左, 上, 右w, 下h),
    }
    目标 = {
        "tl": (0, 0, 左, 上), "tr": (宽 - 右, 0, 宽, 上),
        "bl": (0, 高 - 下, 左, 高), "br": (宽 - 右, 高 - 下, 宽, 高),
        "t": (左, 0, 宽 - 右, 上), "b": (左, 高 - 下, 宽 - 右, 高),
        "l": (0, 上, 左, 高 - 下), "r": (宽 - 右, 上, 宽, 高 - 下),
        "c": (左, 上, 宽 - 右, 高 - 下),
    }
    out = Image.new("RGBA", (宽, 高))
    for k, 源 in 块.items():
        标 = 目标[k]
        if 源[2] <= 源[0] or 源[3] <= 源[1] or 标[2] <= 标[0] or 标[3] <= 标[1]:
            continue
        out.alpha_composite(图.crop(源).resize((标[2] - 标[0], 标[3] - 标[1]), Image.LANCZOS),
                            (标[0], 标[1]))
    return out


def 叠(底, 上):
    出 = 底.copy()
    出.alpha_composite(上)
    return 出


class 窗口截图:
    """把某页的整窗 PNG 装进来，按**页面局部**框裁块（内部 +抬）。裁块越界时自动夹到图内。"""

    def __init__(self, 目录, 页表=(0,), 前缀="客户端_页", 抬=29, 底片前缀="底片_页"):
        self.目录 = 目录
        self.抬 = 抬
        self.图 = {}
        self.底 = {}
        for 页 in 页表:
            路 = os.path.join(目录, "%s%d.png" % (前缀, 页))
            self.图[页] = Image.open(路).convert("RGBA")
            底路 = os.path.join(目录, "%s%d.png" % (底片前缀, 页))
            # 由 `量具基类._步拍底片/_步存底片` 产出：窗口藏起来拍的同一矩形。
            # 半透皮肤的参照必须叠在它上面，否则整窗参照系统性偏暗（见那两个函数的注释）。
            if os.path.exists(底路):
                self.底[页] = Image.open(底路).convert("RGBA")

    def 铺底(self, 合成, 页=0):
        """把「从透明黑往上叠」的整窗参照铺到真实底片上 ⇒ 与客户端同一口径。"""
        底 = self.底.get(页)
        if 底 is None:
            return 合成
        出 = 底.convert("RGBA").copy()
        出.alpha_composite(合成, (0, 0))
        return 出

    def 尺寸(self, 页=0):
        return self.图[页].size

    def 裁(self, 框, 页=0):
        图 = self.图[页]
        x, y, w, h = [int(round(v)) for v in 框]
        左 = max(0, min(图.width - 1, x))
        上 = max(0, min(图.height - 1, y + self.抬))
        return 图.crop((左, 上, min(图.width, 左 + w), min(图.height, 上 + h)))


def 文件级(客户图, 参照图, 阈值=6):
    """导入件 vs 元件图原件。RGB 与 alpha 分开报，不混一个数。
    返回 (过?, 文本)。`过` = 超阈值像素为 0 且尺寸一致。"""
    if 客户图.size != 参照图.size:
        return False, "尺寸不同 导入%s 原版%s" % (客户图.size, 参照图.size)
    a = 数组(客户图).astype(np.int16)
    b = 数组(参照图).astype(np.int16)
    色 = np.abs(a[:, :, :3] - b[:, :, :3]).max(axis=2)
    透 = np.abs(a[:, :, 3] - b[:, :, 3])
    色异 = int((色 > 阈值).sum())
    a异 = int((透 > 0).sum())
    总 = a.shape[0] * a.shape[1]
    return 色异 == 0, ("RGB 最大差 %d（超阈值 %d/%d 像素，阈值 %d）｜alpha 最大差 %d（%d 像素不同）" % (
        int(色.max()), 色异, 总, 阈值, int(透.max()), a异))


def 比对(客户图, 参照图, 环=None, 不判底=False, 不判右=False, 不判顶=False, 不判区=None, 搜=2, 容差=12, 参照只看不透明=True):
    """实机裁块 vs 元件渲染件。只判参照不透明处（可选再限制到边带），在 ±搜 像素里搜最佳偏移。
    `不判底 / 不判右` ⇒ 把那条边带从判定里去掉：原版有些文本盒**故意**比面板宽
    （如 `JiNengCompositeWindow` 的说明 = `340−16=324` 从 x=8 起，右端超出 330 宽的面板 2px），
    文字压在皮上，那条边带比的就不是皮。返回 (超数, 判数, 最佳偏移)。
    `不判区` ⇒ 一组裁块坐标矩形 `(x0, y0, x1, y1)`，从判定里**挖掉**：
    当某个**另有归属的控件**（如 `装备打造` 材料框下沿压着的「自动强化」勾选框）盖住皮时，
    整条边去掉太宽、不去就是假红，挖掉它 + 在日志里写明理由最省争议。"""
    客 = 数组(客户图).astype(np.int16)
    参 = 数组(参照图).astype(np.int16)
    高, 宽 = 参.shape[0], 参.shape[1]
    掩 = np.ones((高, 宽), dtype=bool) if 环 is None else (
        (np.arange(宽)[None, :] < 环) | (np.arange(宽)[None, :] >= 宽 - 环)
        | (np.arange(高)[:, None] < 环) | (np.arange(高)[:, None] >= 高 - 环))
    if 不判底 and 环 is not None:
        掩 = 掩 & (np.arange(高)[:, None] < 高 - 环)
    if 不判右 and 环 is not None:
        掩 = 掩 & (np.arange(宽)[None, :] < 宽 - 环)
    if 不判顶 and 环 is not None:
        掩 = 掩 & (np.arange(高)[:, None] >= 环)
    for 区 in (不判区 or []):
        x0, y0, x1, y1 = [int(v) for v in 区]
        掩[max(0, y0):min(高, y1), max(0, x0):min(宽, x1)] = False
    if 参照只看不透明:
        掩 = 掩 & (参[:, :, 3] > 0)
    判全 = int(掩.sum())
    客高, 客宽 = 客.shape[0], 客.shape[1]
    最佳 = None
    for dy in range(-搜, 搜 + 1):
        for dx in range(-搜, 搜 + 1):
            # 参照格 (y,x) 要拿客户端 (y+dy, x+dx) 来比 ⇒ 目标区间从 -d 起算，源 = 目标 + d。
            # （写反过一次：目标用 max(0,d) 起算 ⇒ 整行错位，实测把 (0,1) 判成 (0,-1) 且多出一行假红。）
            片 = np.zeros_like(客)
            上 = max(0, -dy)
            下 = min(高, 客高 - dy)
            左 = max(0, -dx)
            右 = min(宽, 客宽 - dx)
            if 下 <= 上 or 右 <= 左:
                continue
            片[上:下, 左:右] = 客[上 + dy:下 + dy, 左 + dx:右 + dx]
            # 偏移后参照边缘那一行/列在截图里没有对应像素 ⇒ 不判它。
            # （漏了这条会把空白当黑色比，实测凭空多出一整行的假红：220/1848、83/3420。）
            可判 = np.zeros_like(掩)
            可判[上:下, 左:右] = True
            可判 &= 掩
            差 = np.abs(片[:, :, :3] - 参[:, :, :3]).max(axis=2)
            判 = int(可判.sum())
            超 = int(((差 > 容差) & 可判).sum())
            if 最佳 is None or 超 < 最佳[0]:
                最佳 = (超, 判, (dx, dy))
    return 最佳 if 最佳 else (判全, 判全, (0, 0))


def 条(项目, 出, 标题, 标签宽=18, 起始x=320, 底色=(24, 24, 28)):
    """把 [(标签, PIL图, 备注)] 排成一条横向对照带，左侧标签、中间图、右侧备注。"""
    字 = 字体()
    行高 = max(im.height for _, im, _ in 项目) + 22
    宽 = max(sum(im.width + 16 for _, im, _ in 项目) + 400, 640)
    画布 = Image.new("RGB", (宽, 行高 * len(项目) + 30), 底色)
    笔 = ImageDraw.Draw(画布)
    笔.text((10, 6), 标题, font=字, fill=(255, 220, 140))
    for 行, (标签, im, 备注) in enumerate(项目):
        y = 30 + 行 * 行高
        笔.text((10, y + 4), "%-*s" % (标签宽, 标签), font=字, fill=(160, 220, 155))
        画布.paste(im, (起始x, y + 4), im if im.mode == "RGBA" else None)
        笔.text((起始x + im.width + 14, y + 4), 备注, font=字, fill=(200, 200, 200))
    os.makedirs(os.path.dirname(出), exist_ok=True)
    画布.save(出)
    return 出, 画布.size


def 并排(图列, 出, 标题行, 高偏=28, 间隔=10, 底色=(24, 24, 28)):
    """整窗并排：图列 = [(标题, PIL图)]。"""
    字 = 字体()
    高 = max(im.height for _, im in 图列)
    画布 = Image.new("RGB", (sum(im.width for _, im in 图列) + 间隔 * (len(图列) + 1),
                             高 + 高偏 + 6), 底色)
    笔 = ImageDraw.Draw(画布)
    x = 间隔
    for 题, im in 图列:
        笔.text((x, 6), 题, font=字, fill=(255, 220, 140))
        画布.paste(im.convert("RGB"), (x, 高偏))
        x += im.width + 间隔
    os.makedirs(os.path.dirname(出), exist_ok=True)
    画布.save(出)
    return 出, 画布.size


class 红计数类:
    """收集红项并落一份 `对照输出.txt`；`退出码()` 给脚本当硬门。"""

    def __init__(self):
        self.行 = []
        self.红 = 0

    def 记(self, 文本):
        self.行.append(文本)
        print(文本)

    def 红项(self, 名, 话):
        self.红 += 1
        self.记("!! %s：%s" % (名, 话))

    def 落盘(self, 路径):
        os.makedirs(os.path.dirname(路径), exist_ok=True)
        with open(路径, "w", encoding="utf-8") as f:
            f.write("\n".join(self.行) + "\n")

    def 退出码(self):
        return 1 if self.红 else 0
