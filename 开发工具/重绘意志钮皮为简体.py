# -*- coding: utf-8 -*-
"""把意志学习窗三枚钮皮上的**繁体字重绘成简体**（用户 2026-10-23 报：「最后把意志这部分
用到的繁体中文都改成简体」——截图里钮上皮印的是「一鍵學習/一鍵拾取/一鍵賣出」）。

背景：这三张皮（`钮_一键学习.png` / `钮_全部拾取.png` / `钮_全部卖出.png`）是从原版
运行期包 `UISwf_Text.swf` 导出的，**文字直接画在皮里**（`MButton3` 族一张皮自带字，
不是运行时 textFormat；见 `生成意志钮态图.py` 源表注释）⇒ 原版 lang 表是繁体，皮上
就跟着是繁体。要改 UI 文字只能重绘位图；移植版其余文案（json/场景 Label）早已是简体。

皮的结构（逐张像素实测）：**透明底 + 左侧小图标 + 右侧横排 4 个美术字**
（米黄填充 #F0E0B0 一族 + 深棕描边 #906030 一族，描边约 1px）。
⇒ 重绘 = 擦掉右侧文字区（alpha 清 0，底本就是透明的，不用补背景）+ 用系统粗体
   按同一颜色/同一中心重画简体，左侧图标与整体尺寸**原样不动**。
「钮_返回」（返回，繁同简）与「打开背包钮」（皮上只有图标、无字）**不在表里**。

派生三态（_悬停/_按下）由 `生成意志钮态图.py` 从常态皮加滤镜烘出 ⇒ 本工具跑完后
必须再跑一次那个，否则悬停/按下还是繁体。用法：
    python 重绘意志钮皮为简体.py --工程 <工程目录> [--试跑]
「--试跑」只打印参数与产出到 .scratch，不往工程写。
"""
import os
import sys
from collections import Counter

from PIL import Image, ImageDraw, ImageFont

## (文件名, 新文字串, 左图标右界 x 闭区间, 字色, 描边色) —— 字色/描边色 None = 从旧字像素采样
表 = [
    ("钮_一键学习.png", "一键学习", 11, None, None),
    ("钮_全部拾取.png", "一键拾取", 11, None, None),
    ("钮_全部卖出.png", "一键卖出", 11, None, None),
]

目录 = "素材/界面/原版窗口/意志"
字体候选 = [
    r"C:\Windows\Fonts\msyhbd.ttc",   # 微软雅黑 Bold：最接近原版圆胖美术字
    r"C:\Windows\Fonts\simhei.ttf",   # 黑体：等粗兜底
    r"C:\Windows\Fonts\msyh.ttc",
]


def 绝对(工程, 相对):
    return 相对 if os.path.isabs(相对) else os.path.join(工程, 相对.replace("res://", ""))


def 采样旧字(im, 文字区):
    """在文字区里分「亮/暗」两簇取主色：亮 = 填充，暗 = 描边。"""
    亮, 暗 = Counter(), Counter()
    px = im.load()
    x0, x1 = 文字区
    for y in range(im.height):
        for x in range(x0, x1 + 1):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            if r + g + b > 480:
                亮[(r, g, b)] += 1
            elif r + g + b < 330:
                暗[(r, g, b)] += 1
    return (亮.most_common(1)[0][0] if 亮 else (245, 228, 190),
            暗.most_common(1)[0][0] if 暗 else (140, 92, 44))


def 旧字y范围(im, 文字区):
    px = im.load()
    x0, x1 = 文字区
    ys = [y for y in range(im.height) for x in range(x0, x1 + 1) if px[x, y][3] > 128]
    return (min(ys), max(ys)) if ys else (0, im.height - 1)


def 推图标右界(im, 手写界):
    """图标 vs 文字的分界列：字是「中间一条窄带」（y 跨度小），图标是「上下堵满的块」
    （y 跨度 ≈ 图高）⇒ 取最后一列「亮像素 y 跨度 > 图高 60%」的列 + 1。
    手写界只作兜底（自动推断失效时）。"""
    px = im.load()
    亮列 = []
    for x in range(im.width):
        ys = [y for y in range(im.height) if px[x, y][3] > 128
              and px[x, y][0] + px[x, y][1] + px[x, y][2] > 480]
        if ys:
            亮列.append((x, min(ys), max(ys)))
    界 = 0
    for x, a, b in 亮列:
        if b - a >= im.height * 0.6:
            界 = x + 1
    return max(界, 手写界)


def 重绘(工程, 名, 新串, 图标右界, 字色, 描边色, 试跑):
    径 = 绝对(工程, os.path.join(目录, 名))
    im = Image.open(径).convert("RGBA")
    界 = 图标右界		# 自动推断（推图标右界）会被「一」字骗——横贯字 y 跨度比图标还大
    文字区 = (界, im.width - 1)
    填充, 描边 = 采样旧字(im, 文字区)
    if 字色:
        填充 = 字色
    if 描边色:
        描边 = 描边色
    y0, y1 = 旧字y范围(im, 文字区)
    旧字高 = y1 - y0 + 1
    # 雅黑字模高 ≈ 0.72em ⇒ 反推字号；再按 4 字总宽不超过文字区宽收一档
    字号 = max(8, int(旧字高 / 0.72))
    while 字号 > 8 and len(新串) * 字号 > (文字区[1] - 文字区[0] + 1):
        字号 -= 1
    字体 = None
    for 径f in 字体候选:
        if os.path.exists(径f):
            字体 = ImageFont.truetype(径f, 字号)
            break
    if 字体 is None:
        print("!! 找不到中文字体（%s）" % " / ".join(字体候选))
        return False
    # 擦旧字（alpha 清 0）——只擦文字区，左图标与描边外的半透明锯齿不动
    px = im.load()
    for y in range(im.height):
        for x in range(文字区[0], 文字区[1] + 1):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 0)
    画 = ImageDraw.Draw(im)
    cx = (文字区[0] + 文字区[1]) // 2
    cy = (y0 + y1) // 2
    画.text((cx, cy), 新串, font=字体, fill=填充 + (255,),
            anchor="mm", stroke_width=1, stroke_fill=描边 + (255,))
    print("%s：新串=「%s」 文字区 x[%d..%d] 旧字 y[%d..%d] 高=%d ⇒ 字号=%d 填充=%s 描边=%s"
          % (名, 新串, 文字区[0], 文字区[1], y0, y1, 旧字高, 字号, 填充, 描边))
    if 试跑:
        im.save(os.path.join(工程, ".scratch", "重绘试跑_" + 名))
    else:
        im.save(径)
        print("   已写回 %s" % 径)
    return True


def 主():
    args = sys.argv[1:]
    工程 = os.getcwd()
    试跑 = "--试跑" in args
    for i, a in enumerate(args):
        if a.startswith("--工程"):
            工程 = a.split("=", 1)[1] if "=" in a else args[i + 1]
    os.makedirs(os.path.join(工程, ".scratch"), exist_ok=True)
    好 = True
    for 名, 新串, 界, 填, 描 in 表:
        好 = 重绘(工程, 名, 新串, 界, 填, 描, 试跑) and 好
    if 好 and not 试跑:
        print("⇒ 记得再跑 `python 开发工具/生成意志钮态图.py --工程 %s` 重烘三态（悬停/按下）" % 工程)
    return 0 if 好 else 1


if __name__ == "__main__":
    sys.exit(主())
