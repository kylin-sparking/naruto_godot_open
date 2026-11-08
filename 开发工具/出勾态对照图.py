# -*- coding: utf-8 -*-
"""挂机页复选框交互态的**逐像素**门：把 `开发工具/量挂机勾态.gd` 拍回来的逐态裁图，
跟「原版那张皮 ±滤镜」的算式对死。

为什么行为门（读节点属性）不够，必须再上一道像素门（用户 2026-10-19 打回「没有点击效果、很死板」
之后建的）：
 1. `texture.resource_path` 只是**声明**，屏幕上那一块画的是什么才是玩家看到的；
    中间还隔着 `expand_mode`、`scale`、主题样式、`modulate`（记忆第十六种「量具读声明值、
    屏幕读解算值」）。
 2. 这一族有一个**反例可测**的分支：那颗 `Button` 是 `flat=true`，而 Godot 的 flat **只免画
    `normal` 一张**，`hover`/`pressed` 仍照共享主题画（`按钮.png` 整行铺过去）。
    那种「有了反馈、但是错的反馈」在节点属性上完全看不出来 —— 只有像素能看出来。

算式（`StyleUtil.as:43-47` `getLightFilter`：单位矩阵第 5 列 R/G/B 各加 d ⇒ 加性、逐通道 clamp）：
屏幕上那一点是 `out = (a·皮 + (255−a)·底下那层)/255`，`底下那层` 未知但换态时**不变**，
两式相减把它消掉 ⇒ `out' = out + a·(clamp(皮+d) − 皮)/255`；
`a == 255` 时化简成 **`out' = clamp(皮 + d)`** ⇒ 本门只判**顶那张皮 alpha=255** 的像素，
逐通道精确等于算式。半透像素（0<a<255）只报数不判：勾上那枚时上下两张皮会**同时**换档，
"底下不变"这个前提在那些点上不成立，硬判就是假红（记忆「半透像素只报数、不判」）。

三道门：
 ① **公式门** 框区 a==255 的像素逐通道 == `clamp(皮+d)`
    （d 的出处 `StyleUtil.as:7-12`：up 0 / over +30 / down −40；禁用档 `MButton3.as:333` 走
    `getGrayFilter`，系数 0.3086/0.6094/0.082，不许换成 Rec.601）。
 ② **形状门** 同一枚勾、**同一档 d=0、顶皮与文字都相同**的两张裁图必须**逐字节相同**
    （原版 `MButton3.as:103-108` 松手回 STATE_UP、`:467-470` 重新可用也回 STATE_UP）；
    并且**文字区 x≥22 在各态之间不许有一个像素变化** —— 这一条同时钉住
    「不许换字色」（`textColor` 四档同一个值）与「主题的 Button/hover 皮不许铺到这一行上」。
 ③ **阳性对照** `悬停`/`按下`/`禁用` 的框区必须**真的变了**，而且方向要对
    （悬停变亮的像素数 > 变暗的；按下相反）⇒ 只有"有差"没有方向 = 两档写反也不红（记忆第卅二种）。

退出码契约：**0**=跑到的门全过；**1**=确有像素不符；**2**=缺输入（清单/裁图/皮任一张不在）。
**2 不是通过。**
"""
import io
import os
import sys

from PIL import Image

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
出目录 = os.path.join(工程, "测试", "截图", "挂机勾态")
皮目录 = os.path.join(工程, "素材", "界面", "原版窗口", "通用控件")

## 态 → (d, 是否灰度)。
态偏 = {"常态": (0, False), "悬停": (30, False), "按下": (-40, False), "松手": (0, False),
        "移开": (0, False), "再悬停": (30, False), "禁用": (0, True), "恢复": (0, False)}
序 = ["常态", "悬停", "按下", "松手", "移开", "再悬停", "禁用", "恢复"]
文左 = 22		# 组件里 `文本` 的 offset_left = 22.0（`原版复选项.tscn`）
容差 = 6		# 逐通道；真卡一档是 ±30/−40，远超它；半透边缘的重采样噪声在 ±1 级


def 灰度(p):
    灰 = int(round(p[0] * 0.3086 + p[1] * 0.6094 + p[2] * 0.082))
    return (max(0, min(255, 灰)),) * 3 + (p[3],)


def 加亮(p, d):
    if p[3] == 0:
        return p		# Flash 走预乘 alpha，全透像素本来不参与发光
    return tuple(max(0, min(255, c + d)) for c in p[:3]) + (p[3],)


def 读(p):
    return Image.open(p).convert("RGBA")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    清单路 = os.path.join(出目录, "清单.txt")
    if not os.path.isfile(清单路):
        print("缺清单：%s（先跑 `开发工具/量挂机勾态.gd`，**不能加 --headless**）" % 清单路)
        raise SystemExit(2)
    行 = []
    with io.open(清单路, encoding="utf-8") as f:
        for s in f.read().splitlines():
            s = s.strip()
            if s:
                p = s.split("|")
                if len(p) < 14:
                    print("清单有一行字段不齐（%d 个）：%s" % (len(p), s))
                    raise SystemExit(2)
                ## 末列 = 顶皮基名（量具写的），文本列可能含 `|` ⇒ 用"首尾定位"而不是固定下标。
                行.append(p[:12] + ["|".join(p[12:-1]), p[-1]])
    缺 = []
    皮 = {}
    for 名 in sorted({r[13] for r in 行}):
        路 = os.path.join(皮目录, 名 + ".png")
        if not os.path.isfile(路):
            缺.append(路)
        else:
            皮[名] = 读(路)
    图 = {}
    for r in 行:
        路 = os.path.join(工程, r[2].replace("\\", "/"))
        if not os.path.isfile(路):
            缺.append(路)
        else:
            图[(r[0], r[1])] = 读(路)
    if 缺:
        print("缺输入 %d 项：" % len(缺))
        for x in 缺:
            print("   " + x)
        print("（退出码 2 = 缺输入，**不是通过**）")
        raise SystemExit(2)

    红 = []
    报 = []
    件表 = sorted({r[0] for r in 行})
    for 件名 in 件表:
        表 = {r[1]: r for r in 行 if r[0] == 件名}
        if "常态" not in 表:
            红.append("%s：没有常态裁图 ⇒ 这一枚的相对判据全部作废" % 件名)
            continue
        基 = 图[(件名, "常态")]
        for 态 in [t for t in 序 if t in 表 and t != "常态"]:
            r = 表[态]
            d, 是灰 = 态偏[态]
            顶名 = r[13]		# 量具登记"盖在最上面的是哪张常态皮"；期望值仍由**素材文件本身**算
            底 = 皮[顶名]
            框x, 框y = int(float(r[6])), int(float(r[7]))
            框w, 框h = int(float(r[8])), int(float(r[9]))
            裁 = 图[(件名, 态)]
            if 裁.size != 基.size:
                红.append("%s %s：裁图尺寸 %s ≠ 常态 %s" % (件名, 态, str(裁.size), str(基.size)))
                continue
            判了 = 半透 = 不符 = 变了 = 亮 = 暗 = 0
            for y in range(框y, min(框y + 框h, 裁.size[1])):
                for x in range(框x, min(框x + 框w, 裁.size[0])):
                    p = 底.getpixel((x - 框x, y - 框y))
                    if p[3] == 0:
                        continue
                    实 = 裁.getpixel((x, y))
                    旧 = 基.getpixel((x, y))
                    ## "变了"按**超容差**算，不按字节算：实测同档两张裁图会有几个像素差 ±1
                    ## （半透边缘的重采样/抖动），字节相同的形状门会假红；而真卡档是差 ±30，
                    ## 远超容差 ⇒ 容差 6 既能滤掉噪声又测得出卡档。
                    if max(abs(实[c] - 旧[c]) for c in range(3)) > 容差:
                        变了 += 1
                        未 = (实[0] + 实[1] + 实[2]) - (旧[0] + 旧[1] + 旧[2])
                        if 未 > 0:
                            亮 += 1
                        elif 未 < 0:
                            暗 += 1
                    if p[3] < 255:
                        半透 += 1
                        continue
                    判了 += 1
                    期 = 灰度(p) if 是灰 else 加亮(p, d)
                    if 实[:3] != 期[:3]:
                        不符 += 1
            报.append("%s %s：顶皮=%s(勾=%s) 框区判 %d 个不透明像素、不符 %d；"
                    "与常态相比变了 %d（亮 %d / 暗 %d），半透 %d 个只报不判" % (
                    件名, 态, 顶名, r[5], 判了, 不符, 变了, 亮, 暗, 半透))
            if 不符:
                红.append("%s %s：%d/%d 个不透明像素不等于 clamp(%s%s)" % (
                        件名, 态, 不符, 判了, 顶名,
                        "→getGrayFilter" if 是灰 else "%+d" % d))
            ## 阳性对照 + 方向。
            if 态 in ("悬停", "再悬停", "按下", "禁用"):
                if 变了 == 0:
                    红.append("%s %s：框区与常态**一个像素都没差** ⇒ 要么皮没换、要么这一档根本没生效" % (
                            件名, 态))
                elif 态 in ("悬停", "再悬停") and 亮 <= 暗:
                    红.append("%s %s：应当是变亮的一档（亮 %d ≤ 暗 %d）⇒ ±30/−40 写反了也照样"
                            "「有变化」，所以方向必须单独判" % (件名, 态, 亮, 暗))
                elif 态 == "按下" and 暗 <= 亮:
                    红.append("%s 按下：应当是变暗的一档（暗 %d ≤ 亮 %d）" % (件名, 暗, 亮))
        ## 形状门①：同档（d=0）、顶皮相同、文字相同的两张裁图必须逐像素相同（容差 6）。
        def 超差(A, B, 区=None):
            a = A.crop(区) if 区 else A
            b = B.crop(区) if 区 else B
            if a.size != b.size:
                return 10 ** 6
            数a, 数b = list(a.getdata()), list(b.getdata())	# 取一次；在推导式里反复 getdata() 会 O(n^2)
            return sum(1 for i in range(len(数a))
                       if max(abs(数a[i][c] - 数b[i][c]) for c in range(3)) > 容差)

        零档 = [t for t in 序 if t in 表 and 态偏[t][0] == 0]
        for a in range(len(零档)):
            for b in range(a + 1, len(零档)):
                甲, 乙 = 表[零档[a]], 表[零档[b]]
                if 甲[5] != 乙[5] or 甲[12] != 乙[12]:
                    continue		# 顶皮/文字本来就不同（点了一下、或 VIP 那行加了字），不是状态残留
                n = 超差(图[(件名, 零档[a])], 图[(件名, 零档[b])])
                if n:
                    红.append("%s：%s 与 %s 都是常态档、顶皮与文字也一样，却有 %d 个像素超容差 ⇒ 有档卡在旧态上" % (
                            件名, 零档[a], 零档[b], n))
        ## 形状门②：文字区不许变（除文字本身改过的那些态 —— 那是原版的 "(VIP5)" 后缀，不是反馈）。
        ## 只对**带文字的件**（那一行行勾）判；那颗 X 的裁图里没有文字，套这条只会因抗噪容差而假红。
        宽, 高 = 基.size
        if 件名.startswith("复选") and 宽 > 文左 + 8:
            区 = (文左, 0, 宽, 高)
            for 态 in 表:
                if 态 == "常态" or 表[态][12] != 表["常态"][12]:
                    continue
                n = 超差(图[(件名, 态)], 基, 区)
                if n:
                    红.append("%s %s：文字区（x≥%d）有 %d 个像素与常态不一样 ⇒ 要么文字换了色，"
                            "要么主题的 Button/hover 皮铺到了这一行上（原版两样都没有）" % (件名, 态, 文左, n))

    for s in 报:
        print(s)
    print("")
    for s in 红:
        print("红   " + s)
    print("勾与关钮态像素门：判 %d 张裁图（%d 个件：挑的 3 枚勾 + 主窗壳那颗 X），红 %d 条" % (len(行), len(件表), len(红)))
    with io.open(os.path.join(出目录, "对照输出.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(报 + [""] + ["红 " + x for x in 红] +
                        ["勾与关钮态像素门：判 %d 张裁图（%d 个件：挑的 3 枚勾 + 主窗壳那颗 X），红 %d 条" % (len(行), len(件表), len(红))]) + "\n")
    raise SystemExit(1 if 红 else 0)


if __name__ == "__main__":
    main()
