# -*- coding: utf-8 -*-
"""「八卦阵有没有一比一重合」的可复用判据库（打坐光环那条特效专用）。

为什么单独成一份（不再往 叠红绿看第8帧.py 里塞）：这条判据要被**对账脚本**和**门**同时用，
两边各写一份配准 = 迟早对不上。

核心口径（2026-10-13 定）：
· **基准 = 第 0 帧那块盘**（用户原话："以打坐后显示的打坐光环的八卦阵为基准"）。
· 判据不挑地标：把第 0 帧与第 n 帧都按"注册点落在同一点"铺进同一张叠图，
  只取**画实的像素**（alpha > 200 —— 辉光是半透明的，切掉），在 ±6 内搜"重叠区色差最小"的整数位移。
· 每次量都要带**两条自检**，缺一条这数就不许用：
    ① 阳性对照：先把第 n 帧故意压 5 像素再搜 ⇒ 必须报出 −5（认不出位移的量法，报 (0,0) 是假阴性）
    ② 峰尖度：竖直方向色差曲线两端最差 ÷ 谷底 ⇒ 越大越尖；<1.15 算平、平则不可信
      （上一轮 配盘定基准.py 就是栽在"九帧偏移全 (0,0)"却没报峰尖）。

· **符号口径（2026-10-13 用 `开发工具/验盘配准符号.py` 实测钉死，不许靠推）**：
  `铺()` 的 `顶/左` 是"从画布第几行/列开始取" ⇒ 它增大 = 内容在屏幕上**往左上**走，与 position
  的方向**差一层反号**。实测：把第 6 帧内容整体往下搬 5 像素（= position_y +5），工具报的 dy
  跟着 **+5** ⇒ 所以 `应加` 是"叠图里该往哪挪"，**要换算成 position 修正必须取反**。
  ⇒ 下游一律读 `position修正`（已取好反号），不要再自己拿 `应加` 去加 position。
  （差点在这上面翻车：给用户的坐标第一版就是反的，挪错方向会比不挪更糟。）

用法：
    import 盘配准
    量 = 盘配准.量全部(工程)   # {帧号: {"应加","position修正","重叠","色差","峰尖","对照"}}
"""
import io
import json
import os
import sys

import numpy as np
from PIL import Image

带 = (-30, 30, -40, 30)		# 相对注册点取的叠图窗口：(列起, 列止, 行起, 行止)
实亮阈 = 200				# 只认"画实"的像素（辉光半透明，切掉）
搜窗 = 6					# ±6 像素


def 读帧(工程, 帧):
    """返回 (注册点x, 注册点y, RGBA 数组)。`文件` 是 res:// 串 ⇒ 换成工程下的真实路径。"""
    路 = os.path.join(工程, str(帧["文件"])[len("res://"):])
    像 = Image.open(路).convert("RGBA")
    return int(帧["原点x"]), int(帧["原点y"]), np.asarray(像, dtype=np.float64)


def 铺(色, 原x, 原y, 顶=0, 左=0):
    """把整张位图按"注册点落在叠图原点 + (左,顶)"铺进固定窗口，返回 (高,宽,4) 数组。"""
    高, 宽 = 带[3] - 带[2], 带[1] - 带[0]
    布 = np.zeros((高, 宽, 4), dtype=np.float64)
    行起 = 原y + 带[2] + 顶
    列起 = 原x + 带[0] + 左
    for y in range(高):
        画y = 行起 + y
        if 画y < 0 or 画y >= 色.shape[0]:
            continue
        for x in range(宽):
            画x = 列起 + x
            if 画x < 0 or 画x >= 色.shape[1]:
                continue
            布[y, x] = 色[画y, 画x]
    return 布


def 搜(底n, 原nx, 原ny, 底0, 实0, 预顶=0, 预左=0):
    """在 ±搜窗 里找"重叠区色差最小"的整数位移。返回 (dx, dy, 重叠数, 色差, 对齐后的那张)。"""
    最 = None
    for dy in range(-搜窗, 搜窗 + 1):
        for dx in range(-搜窗, 搜窗 + 1):
            铺n = 铺(底n, 原nx, 原ny, 预顶 + dy, 预左 + dx)
            同 = np.logical_and(实0, 铺n[..., 3] > 实亮阈)
            if int(同.sum()) < 50:
                continue
            差 = float(np.abs(铺n[..., :3] - 底0[..., :3]).max(axis=2)[同].mean())
            if 最 is None or (-差, int(同.sum())) > 最[4]:
                最 = (dx, dy, int(同.sum()), 差, (-差, int(同.sum())), 铺n)
    if 最 is None:
        return None
    return {"应加": (最[0], 最[1]), "重叠": 最[2], "色差": 最[3], "对齐图": 最[5]}


def 峰尖(底n, 原nx, 原ny, 底0, 实0, dx):
    """固定 dx、扫 dy，报"两端最差 ÷ 谷底"。"""
    曲 = []
    for dy in range(-搜窗, 搜窗 + 1):
        铺n = 铺(底n, 原nx, 原ny, dy, dx)
        同 = np.logical_and(实0, 铺n[..., 3] > 实亮阈)
        if int(同.sum()) < 50:
            曲.append(-1.0)
            continue
        曲.append(float(np.abs(铺n[..., :3] - 底0[..., :3]).max(axis=2)[同].mean()))
    有 = [c for c in 曲 if c >= 0]
    if len(有) < 3:
        return 0.0, 曲
    谷 = min(有)
    return (max(有[0], 有[-1]) / 谷) if 谷 > 0 else 999.0, 曲


def 量全部(工程, 表路=None, 基准=0):
    """返回 {帧号: 结果}。基准帧自己那条 = 全 0（它就是尺子）。"""
    表路 = 表路 or os.path.join(工程, "数据", "界面", "打坐光环.json")
    表 = json.load(io.open(表路, encoding="utf-8"))
    帧们 = 表["帧"]
    原0, 原0y, 色0 = 读帧(工程, 帧们[基准])
    底0 = 铺(色0, 原0, 原0y)
    实0 = 底0[..., 3] > 实亮阈
    出 = {}
    for i, 帧 in enumerate(帧们):
        if i == 基准:
            出[i] = {"应加": (0, 0), "position修正": (0, 0), "重叠": int(实0.sum()),
                     "色差": 0.0, "峰尖": 999.0, "对照": True, "基准": True}
            continue
        原x, 原y, 色 = 读帧(工程, 帧)
        果 = 搜(色, 原x, 原y, 底0, 实0)
        if 果 is None:
            出[i] = {"应加": None, "position修正": None, "重叠": 0, "色差": None,
                     "峰尖": 0.0, "对照": False}
            continue
        尖, 曲 = 峰尖(色, 原x, 原y, 底0, 实0, 果["应加"][0])
        对 = 搜(色, 原x, 原y, 底0, 实0, 预顶=5, 预左=0)
        dx, dy = 果["应加"]
        出[i] = {"应加": 果["应加"], "position修正": (-dx, -dy),
                 "重叠": 果["重叠"], "色差": 果["色差"],
                 "峰尖": 尖, "曲线": 曲,
                 "对照": 对 is not None and 对["应加"][1] == -5}
    return 出, 表


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    出, 表 = 量全部(工程)
    print("帧  叠图应加(dx,dy)  ⇒ position 该加  重叠实亮像素  平均色差  峰尖度  阳性对照")
    for i in sorted(出):
        r = 出[i]
        print("%d  %-16s  %-14s  %6d      %7.1f  %6.2f   %s%s" % (
            i, str(r["应加"]), str(r["position修正"]), r["重叠"],
            r["色差"] if r["色差"] is not None else -1,
            r["峰尖"], "过" if r["对照"] else "**不过**",
            "  ← 基准" if r.get("基准") else ""))
