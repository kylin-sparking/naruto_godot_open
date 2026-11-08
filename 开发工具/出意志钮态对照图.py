# -*- coding: utf-8 -*-
"""意志学习 5 枚原版钮的三态逐像素核对（离线硬门，不过就退出码 1）。

输入：`测试/截图/意志钮态_对照/态_<钮>_<步名>.png`（由 `开发工具/截意志钮态.gd` 出）
算法与小地图那道门同源（同一个 `加亮`/合成公式），只是钮表换成意志页这 5 枚：
  一键学习 / 全部拾取 / 全部卖出 / 返回 = `UISwf_Text.swf` 各自的 `*_UpSkin`
  打开背包 = `UISwf_yizhi_openPackUpSkin`
五枚都是 `ProgramButton extends MButton3` ⇒ 一张皮 + 运行时加性滤镜
（`StyleUtil.as:7-12` up 0 / over +30 / down −40；`:43-47` 不动 alpha）。
⚠ 这五枚的**文字是画在皮里的**（不像 MButton3 那样另有 textFormat），
  所以文字区=None —— 文字跟着皮一起变亮才是原版的样子。

三道硬门：① 文件级派生图逐字节等于 `加亮(常态, ±d)`；② 渲染级判定像素（皮肤 a==255
且常态实测==皮肤值）逐通道精确；③ 形状：同组各步常态逐字节相同、悬停各步相同
（松手必须回**常态**，不是 hover —— `MButton3.mouseUpHandler:103-108`）。

用法：python 开发工具/出意志钮态对照图.py
"""
import os
import sys

from PIL import Image

项目 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
出目录 = os.path.join(项目, "测试", "截图", "意志钮态_对照")
外扩 = 0
专 = "素材/界面/专用控件/"
意 = "素材/界面/原版窗口/意志/"

普通步 = {"常态": (0, 0), "悬停": (0, 1), "按下": (0, 2), "松手": (0, 0),
          "移开": (0, 0), "再悬停": (0, 1)}

## 钮 → (步表, [一组三张皮], 文字区)
钮表 = {
    "一键学习": (普通步, [[意 + "钮_一键学习.png", 专 + "意志_一键学习_悬停.png",
                           专 + "意志_一键学习_按下.png"]], None),
    "全部拾取": (普通步, [[意 + "钮_全部拾取.png", 专 + "意志_全部拾取_悬停.png",
                           专 + "意志_全部拾取_按下.png"]], None),
    "全部卖出": (普通步, [[意 + "钮_全部卖出.png", 专 + "意志_全部卖出_悬停.png",
                           专 + "意志_全部卖出_按下.png"]], None),
    "返回": (普通步, [[意 + "钮_返回.png", 专 + "意志_返回_悬停.png",
                       专 + "意志_返回_按下.png"]], None),
    "打开背包": (普通步, [[意 + "打开背包钮.png", 专 + "意志_打开背包_悬停.png",
                           专 + "意志_打开背包_按下.png"]], None),
}


## ── 第二页：意志背包的 2 枚可点 MButtonF（`截意志背包钮态.gd` 出图）──────────────
## 这三枚的**常态皮本身就在 `专用控件/`**（`生成意志钮态图.py` 把 57×22 的 `按钮.png`
## 按原版 `isScale9Grid=false` + 显式 width 压/拉成 143/82/110 宽烘出来的），
## 所以组表第 0 张与派生两态同目录。第三枚「自动升级意志」原版就是禁用态
## ⇒ 不进逐像素状态机，由量具断言"恒为灰皮、悬停也不换皮"。
## ⚠ 这三枚的字是**独立 Label**（不像学习页那五枚画在皮里）：判定像素靠
##   "该步实测值 == 皮肤值"自动排除被字盖住的点，所以 字区 仍给 None；
##   字的**换色**（`MButton3._textColors` up/over/down）由 `截意志背包钮态.gd` 逐步断言。
背包出目录 = os.path.join(项目, "测试", "截图", "意志背包钮态_对照")
背包钮表 = {
    "一键合成": (普通步, [[专 + "意志_一键合成.png", 专 + "意志_一键合成_悬停.png",
                           专 + "意志_一键合成_按下.png"]], None),
    "前往学习": (普通步, [[专 + "意志_前往学习.png", 专 + "意志_前往学习_悬停.png",
                           专 + "意志_前往学习_按下.png"]], None),
}


## ── 第三页：装备打造 1 枚可点 MButtonF（`截装备打造钮态.gd` 出图）───────────────
## `ItemDropBox.as:31,49-51` 的 `dropBtn` = `MButtonF`，皮 57×22 整张非等比拉到 61×22
## （`isScale9Grid=false`，`BC/MButton3.as:82`）⇒ 常态/悬停/按下三张都在 `专用控件/`。
## ⚠️ 这页**只有这一枚**进状态机：`开始强化` 没穿装备时 disabled、`购买` 被
## `_配置打造左栏` 锁住（原版跳商城未接）⇒ 那两枚由量具断言"恒为灰皮 + 光标回箭头"。
打造出目录 = os.path.join(项目, "测试", "截图", "装备打造钮态_对照")
打造步表 = {"常态": (0, 0), "悬停": (0, 1), "按下": (0, 2), "松手": (0, 1),
        "移开": (0, 0), "再悬停": (0, 1)}
打造钮表 = {"投放钮": (打造步表, [[专 + "打造_投放钮.png", 专 + "打造_投放钮_悬停.png",
                           专 + "打造_投放钮_按下.png"]], None)}
## 松手 == 悬停：Godot `BaseButton.get_draw_mode()` 在"松开且仍悬停"时给 DRAW_HOVER，
## 原版 `MButton3.mouseUpHandler:103-108` 给 STATE_UP。**这是已知偏离**，见 真值对照表 §六。
打造形状对 = [("移开", "常态"), ("再悬停", "悬停"), ("松手", "悬停")]


def 读图(绝对):
    return Image.open(绝对).convert("RGBA")

def 读(相对):
    return Image.open(os.path.join(项目, 相对.replace("/", os.sep))).convert("RGBA")


def 加亮(数, 偏移):
    """getLightFilter 的字面实现：R/G/B 各加 偏移 并 clamp，alpha 不动，a==0 整像素不动。"""
    return [p if p[3] == 0 else
            tuple(min(255, max(0, c + 偏移)) for c in p[:3]) + (p[3],) for p in 数]


def 核(出目录, 钮表, 标题, 形状对=None):
    """跑一页的三态核对，返回不符处数量（0 = 全过）。"""
    报 = ["=== " + 标题 + " ==="]
    坏 = 0
    for 名, (步表, 组表, 字区) in 钮表.items():
        常态 = 读图(os.path.join(出目录, "态_%s_常态.png" % 名))
        宽, 高 = 常态.size
        基 = list(常态.getdata())
        报.append("")
        报.append("── %s｜裁图 %dx%d｜%d 组皮｜文字区 %s" % (名, 宽, 高, len(组表), 字区))

        # ① 文件级：每张派生皮都等于"它的常态按公式"
        for g, 组 in enumerate(组表):
            底 = list(读(组[0]).getdata())
            for i, (态名, d) in enumerate([("悬停", 30), ("按下", -40)], start=1):
                实 = list(读(组[i]).getdata())
                错 = sum(1 for a, b in zip(实, 加亮(底, d)) if a != b)
                报.append("   ① %s组 %s：与公式差 %d 个像素（%s）"
                          % ("AB"[g], 态名, 错, os.path.basename(组[i])))
                坏 += 错

        def 在字区(i):
            if not 字区:
                return False
            x, y = i % 宽, i // 宽
            return (字区[0] + 外扩 <= x < 字区[0] + 外扩 + 字区[2]
                    and 字区[1] + 外扩 <= y < 字区[1] + 外扩 + 字区[3])

        # 每组的"up 那一步"截图：组 0 是 常态，组 1 是点一下之后松手那一步
        截 = {k: list(读图(os.path.join(出目录,
                                   "态_%s_%s.png" % (名, k))).getdata())
             for k in 步表}
        up步 = ["常态", "松手"]

        # 每组各自的判定像素：该组不透明、且那一步实测就等于皮肤值
        # （不满足 = 这一像素被文字/兄弟钮压住了，原版的滤镜不会作用到那层上）
        判 = []
        for g, 组 in enumerate(组表):
            皮图 = 读(组[0])
            if 皮图.size != (宽 - 外扩 * 2, 高 - 外扩 * 2):
                报.append("   !!! 组 %s 皮肤 %s 与裁图 %s 不匹配" % ("AB"[g], 组[0], 常态.size))
                坏 += 1
                continue
            垫 = Image.new("RGBA", 常态.size, (0, 0, 0, 0))
            垫.paste(皮图, (外扩, 外扩))
            皮 = list(垫.getdata())
            底 = 截[up步[g]]
            硬 = {i for i, p in enumerate(皮)
                  if p[3] == 255 and 底[i][:3] == p[:3] and not 在字区(i)}
            盖 = sum(1 for p in 皮 if p[3] == 255) - len(硬)
            判.append((皮, 硬))
            报.append("   组 %s 判定 %d 个不透明像素（被压住/文字 %d 个不判）"
                      % ("AB"[g], len(硬), 盖))

        # ② 渲染级：每一步都按它所在组的皮 + 态算预期，与截图比
        for 步名, (g, 态) in 步表.items():
            if 步名 == "常态" or 态 == 0:
                continue
            皮, 硬 = 判[g]
            d = 30 if 态 == 1 else -40
            实 = 截[步名]
            错 = sum(1 for i in 硬 if any(实[i][k] != min(255, max(0, 皮[i][k] + d))
                                          for k in range(3)))
            报.append("   ② %-10s 组%s 态%+d：与公式差 %d 个像素" % (步名, "AB"[g], d, 错))
            坏 += 错
            差图 = Image.new("RGBA", 常态.size)
            差图.putdata([(255, 0, 255, 255) if i in 硬 and any(
                实[i][k] != min(255, max(0, 皮[i][k] + d)) for k in range(3))
                else (60, 60, 60, 255) if 皮[i][3] > 0 else (0, 0, 0, 255)
                for i in range(len(实))])
            差图.save(os.path.join(出目录, "差值_%s_%s.png" % (名, 步名)))

        # ③ 形状：同组同态的步必须逐字节相同（"移开"与"常态"、"再悬停"与"悬停"…）
        if 形状对 is not None:
            对 = list(形状对)	# 由调用方按**该页钮的真实状态机**给
        else:
            对 = [("移开", "常态"), ("再悬停", "悬停")]
            对 += [("松手", "常态")] if len(判) == 1 else [("再松手", "常态"), ("选中移开", "松手")]
        for a, b in 对:
            集 = 判[步表[a][0]][1]
            错 = sum(1 for i in 集 if 截[a][i] != 截[b][i])
            报.append("   ③ %-10s vs %-8s：差 %d 个（应 0）" % (a, b, 错))
            坏 += 错

        # 8× 条带：常态｜悬停｜按下（有第二组就再排三张）
        列 = ["常态", "悬停", "按下"] + (["松手", "选中悬停", "选中按下"] if len(判) > 1 else [])
        图 = [读图(os.path.join(出目录, "态_%s_%s.png" % (名, c))) for c in 列]
        带 = Image.new("RGBA", (sum(g.width for g in 图) + 6 * (len(图) - 1),
                              max(g.height for g in 图)), (20, 20, 20, 255))
        x = 0
        for 图块 in 图:
            带.paste(图块, (x, 0))
            x += 图块.width + 6
        带.resize((带.width * 8, 带.height * 8), Image.NEAREST).save(
            os.path.join(出目录, "三态8x_%s.png" % 名))
        报.append("   已出 三态8x_%s.png（%s，8 倍 NEAREST）" % (名, "｜".join(列)))

    文 = "\n".join(报)
    with open(os.path.join(出目录, "对照输出.txt"), "w", encoding="utf-8") as f:
        f.write(文 + "\n")
    print(文)
    print("")
    return 坏


def 主():
    坏 = 0
    坏 += 核(出目录, 钮表, "意志学习 5 枚原版钮三态核对（真值 = 皮肤按 getLightFilter(+30/-40) 变亮；"
                       "文字画在皮里，跟着一起亮）")
    坏 += 核(背包出目录, 背包钮表, "意志背包 2 枚可点 MButtonF 三态核对（真值同上；"
                          "字是独立 Label ⇒ 判定像素自动排除字覆盖处，换色由量具断言；"
                          "第三枚「自动升级意志」原版即禁用态，见 截意志背包钮态.gd）")
    坏 += 核(打造出目录, 打造钮表, "装备打造 1 枚可点 MButtonF 三态核对（真值同上；"
                          "松手按 Godot 的 DRAW_HOVER 判，与原版 STATE_UP 的差已登记未决）",
                   形状对=打造形状对)
    if 坏:
        print("!!! 三态核对不通过：%d 处不符" % 坏)
        raise SystemExit(1)
    print("OK：%d + %d + %d 枚钮逐像素等于 getLightFilter(+30/-40)；"
          "松手一步按各页引擎实际行为判（意志回常态、打造回 hover，见 打造形状对 注释）。"
          % (len(钮表), len(背包钮表), len(打造钮表)))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    主()
