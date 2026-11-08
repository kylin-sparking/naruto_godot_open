# -*- coding: utf-8 -*-
"""把 MButton3 每张皮肤烘成 _悬停 / _按下 两张派生图，并做**文件级逐字节自检**。

真值（逐字来自只读归档）：
  StyleUtil.as:7-12   skinFilters = {up:0, over:30, down:-40}
  StyleUtil.as:43-47  getLightFilter(d) = ColorMatrixFilter(单位矩阵 + 第 5 列 R/G/B 各加 d)
                      ⇒ 加性偏移、逐通道 clamp、alpha 那一行 0,0,0,1,0 = 不动
整数 + 整数 ⇒ 结果仍是整数，没有舍入歧义，所以这里要求"逐字节等于公式"。

一处**有意偏离**：a==0 的全透像素 rgb 不动。按矩阵字面执行会把 (0,0,0,0) 变成
(30,30,30,0) —— 看不见的 rgb 被提亮，一旦这张图走线性过滤就渗出一圈亮边。Flash 内部
走预乘 alpha，全透像素的预乘 rgb 恒为 0，本来就不会亮；所以"a==0 不动"才是原版实际表现。

只烘 `MButton3` 族（每组一张皮 + 运行时滤镜）。有独立 overSkin/downSkin 的族
（如 MButton 的 按钮.png / 按钮按下.png）**不要烘** —— 用原版那张皮。

用法：
    python 烘态图.py --工程 <工程目录>
    python 烘态图.py --工程 ... --出目录 _tmp/试烘     # 试跑：不往工程写素材
改这里：源表（要烘哪些皮肤）、态（偏移，一般不动）。
"""
import os
import sys

from PIL import Image

## (源, 输出目录, 输出基名)。源/输出目录写 res:// 相对路径或绝对路径均可。
## 输出基名省略 = 源文件名去掉 .png。保持"三态 = 同一基名加 _悬停/_按下"这条规则，
## 逐像素那道门才能统一判。
## ⚠ 派生件不要倒进共享目录（如 原版窗口/通用控件/）——落页面私有目录。
## 「召唤」是 `BaseUtil.getButton()` 造的 `MButtonF extends MButton3`（共享皮 `按钮.png` 57×22），
## 但 `TeacherCell:57-64` 显式 `isScale9Grid = false` + `width = btn_width_two = 37`
## ⇒ 原版是**整张非等比压扁**成 37×22，不是九宫格。先在离线把这一步烘成一张 37×22 的常态皮
## （Flash 位图缩放默认带平滑 ⇒ BILINEAR），三态再在它上面加滤镜：
## 加性偏移与线性插值可交换，所以"先压后亮"和原版的"先亮后显"像素一致。
预烘 = [
	("res://素材/界面/原版窗口/通用控件/按钮.png", "意志_召唤", (37, 22)),
	# 意志背包页的三枚 MButtonF：`isScale9Grid=false` + 显式 width ⇒ 同样是整张非等比压/拉
	("res://素材/界面/原版窗口/通用控件/按钮.png", "意志_一键合成", (143, 22)),	# PW:186-191
	("res://素材/界面/原版窗口/通用控件/按钮.png", "意志_前往学习", (82, 22)),	# PW:193-197 btn_width_six
	("res://素材/界面/原版窗口/通用控件/按钮.png", "意志_自动升级", (110, 22)),	# PW:475-482
	# 装备打造页（`EquipStrengthWindow`）三枚 MButtonF：`isScale9Grid` 未置 true + 显式 width
	#   ⇒ 同样是**整张非等比拉伸**（原生 57×22）。出处：`ESW:396-400` 强化钮 btn_width_four=61、
	#   `ItemDropBox.as:31,49-51` 投放钮 61、`ItemCaiLiaoBox.as:88-92` 购买钮 btn_width_two=37。
	("res://素材/界面/原版窗口/通用控件/按钮.png", "打造_强化钮", (61, 22)),
	("res://素材/界面/原版窗口/通用控件/按钮.png", "打造_投放钮", (61, 22)),
	("res://素材/界面/原版窗口/通用控件/按钮.png", "打造_购买钮", (37, 22)),
]


def 压扁(工程):
    for 源, 基, 尺 in 预烘:
        径 = 绝对(工程, 源)
        底 = Image.open(径).convert("RGBA")
        出 = os.path.join(绝对(工程, "res://素材/界面/专用控件/"), "%s.png" % 基)
        底.resize(尺, Image.BILINEAR).save(出)
        print("压扁 %s %s → %s %s" % (os.path.basename(源), 底.size, 基 + ".png", 尺))


源表 = [
    # 意志学习页 5 枚钮：全是 `ProgramButton extends MButton3`（一组一张皮 + 运行时加性滤镜）。
    # 皮来自运行期包 `UISwf_Text.swf`（前缀规则见 BaseUtil.getLocalPath:74-77）与
    # `UISwf_yizhi.swf` 的 openPackUpSkin；文字**画在皮里**（不像 MButton3 那样另有 textFormat），
    # 所以只派生皮肤图、不换文字色。
    ("res://素材/界面/原版窗口/意志/钮_一键学习.png", "res://素材/界面/专用控件/", "意志_一键学习"),
    ("res://素材/界面/原版窗口/意志/钮_全部拾取.png", "res://素材/界面/专用控件/", "意志_全部拾取"),
    ("res://素材/界面/原版窗口/意志/钮_全部卖出.png", "res://素材/界面/专用控件/", "意志_全部卖出"),
    ("res://素材/界面/原版窗口/意志/钮_返回.png", "res://素材/界面/专用控件/", "意志_返回"),
    ("res://素材/界面/原版窗口/意志/打开背包钮.png", "res://素材/界面/专用控件/", "意志_打开背包"),
    # 「召唤」钮（MButtonF，压扁后的 37×22 常态见上）
    ("res://素材/界面/专用控件/意志_召唤.png", "res://素材/界面/专用控件/", "意志_召唤"),
    ("res://素材/界面/专用控件/意志_一键合成.png", "res://素材/界面/专用控件/", "意志_一键合成"),
    ("res://素材/界面/专用控件/意志_前往学习.png", "res://素材/界面/专用控件/", "意志_前往学习"),
    ("res://素材/界面/专用控件/意志_自动升级.png", "res://素材/界面/专用控件/", "意志_自动升级"),
    ("res://素材/界面/专用控件/打造_强化钮.png", "res://素材/界面/专用控件/", "打造_强化钮"),
    ("res://素材/界面/专用控件/打造_投放钮.png", "res://素材/界面/专用控件/", "打造_投放钮"),
    ("res://素材/界面/专用控件/打造_购买钮.png", "res://素材/界面/专用控件/", "打造_购买钮"),
]

## 态名 → 偏移（= StyleUtil.skinFilters，逐通道加性）
态 = [("悬停", 30), ("按下", -40)]

## `MButton3.updateState():335-339`：**disabled 不是加性偏移，是换 `getGrayFilter()`**
## （`StyleUtil.as:25-29`，三通道都换成 0.3086R+0.6094G+0.082B、alpha 行 0,0,0,1,0 不动）。
## 原版 `YiZhiPackWindow:481` 一造出来就 `enabled=false` ⇒ 「自动升级意志」钮要一张灰皮。
## 「购买」（`ItemCaiLiaoBox` 的 buyBtn）在本工程运行期也是 disabled ——
## 控制器 `_配置打造左栏:1454` 把它锁住了（原版跳商城未接），所以它显示的是**灰皮**而不是常态皮，
## 像素门量它时必须拿这张灰皮当参照，否则会把"逻辑未接"误判成"皮用错"。
## 「开始强化 / 放入装备」同理各留一张灰皮：**没穿装备时 开始强化 就是 disabled**
## （`执行.disabled = not 有装备 ...`），而 Godot 在 disabled 只读 `styles/disabled` ——
## 场景里不给这张就会落回主题那张九宫格 `按钮.png`（实测 97.4% 红）。
灰度表 = [("意志_自动升级", "意志_自动升级_灰"), ("打造_购买钮", "打造_购买钮_灰"),
          ("打造_强化钮", "打造_强化钮_灰"), ("打造_投放钮", "打造_投放钮_灰")]


def 灰(数):
    """getGrayFilter 的字面实现：三通道都换成 luma，alpha 不动；a==0 整像素不动。"""
    出 = []
    for q in 数:
        if q[3] == 0:
            出.append(q)
            continue
        亮 = int(round(q[0] * 0.3086 + q[1] * 0.6094 + q[2] * 0.082))
        出.append((亮, 亮, 亮, q[3]))
    return 出


def 绝对(工程, 路径):
    return os.path.join(工程, 路径[len("res://"):].replace("/", os.sep)) \
        if 路径.startswith("res://") else 路径


def 加亮(数, 偏移):
    """getLightFilter 的字面实现：R/G/B 各加 偏移 并 clamp 到 0~255；alpha 不动；a==0 整像素不动。"""
    return [p if p[3] == 0 else
            tuple(min(255, max(0, c + 偏移)) for c in p[:3]) + (p[3],) for p in 数]


def 主(工程, 出目录覆盖=None):
    压扁(工程)
    for 基, 出名 in 灰度表:
        径 = os.path.join(绝对(工程, "res://素材/界面/专用控件/"), "%s.png" % 基)
        底 = Image.open(径).convert("RGBA")
        期 = Image.new("RGBA", 底.size)
        期.putdata(灰(list(底.getdata())))
        目标 = os.path.join(os.path.dirname(径), "%s.png" % 出名)
        期.save(目标)
        回 = list(Image.open(目标).convert("RGBA").getdata())
        差 = sum(1 for a, b in zip(灰(list(底.getdata())), 回) if a != b)
        print("%-20s 灰度 → %dx%d｜与 getGrayFilter 差 %d" % (出名, 底.width, 底.height, 差))
        if 差:
            raise SystemExit(1)
    张 = 0
    坏 = 0
    for 源, 出目录, 基 in 源表:
        径 = 绝对(工程, 源)
        if not os.path.isfile(径):
            raise SystemExit("源不存在：%s" % 源)
        底 = Image.open(径).convert("RGBA")
        基 = 基 or os.path.basename(源)[:-len(".png")]
        出 = 绝对(工程, 出目录) if not 出目录覆盖 else 出目录覆盖
        if not os.path.isdir(出):
            os.makedirs(出)
        for 态名, 偏移 in 态:
            目标 = os.path.join(出, "%s_%s.png" % (基, 态名))
            期 = Image.new("RGBA", 底.size)
            期.putdata(加亮(list(底.getdata()), 偏移))
            期.save(目标)
            回 = Image.open(目标).convert("RGBA")
            回数 = list(回.getdata())
            差 = sum(1 for a, b in zip(加亮(list(底.getdata()), 偏移), 回数) if a != b)
            不透 = sum(1 for p in list(底.getdata()) if p[3] == 255)
            变 = sum(1 for a, b in zip(list(底.getdata()), 回数) if a != b)
            print("%-24s %-4s %+d → %dx%d 不透明 %d 个｜与公式差 %d｜相对原图变了 %d"
                  % (基, 态名, 偏移, 底.width, 底.height, 不透, 差, 变))
            if 差:
                坏 += 差
            张 += 1
    print("")
    if 坏:
        print("!!! 写盘结果与 getLightFilter 公式不一致：%d 个像素" % 坏)
        raise SystemExit(1)
    print("OK：%d 张态图，全部逐字节等于 getLightFilter 的加性公式。" % 张)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    工程 = None
    出目录 = None
    for 参数 in sys.argv[1:]:
        if 参数.startswith("--工程"):
            工程 = 参数.split("=", 1)[1] if "=" in 参数 else sys.argv[sys.argv.index(参数) + 1]
        if 参数.startswith("--出目录"):
            出目录 = 参数.split("=", 1)[1] if "=" in 参数 else sys.argv[sys.argv.index(参数) + 1]
    if not 工程:
        raise SystemExit("必须给 --工程=<Godot 工程根>")
    主(工程.replace("\\", "/"), 出目录)
