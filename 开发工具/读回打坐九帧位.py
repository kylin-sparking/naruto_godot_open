# -*- coding: utf-8 -*-
"""读回 `场景/角色/打坐光环.tscn` 里九帧的 position，出**两张对账表**：

① 与 AS3 字面公式 `(−原点x, −原点y)` 的差量（= 用户手拖了多少）；
② **盘重合判据**：以第 0 帧那块八卦阵为尺子，量每一帧的盘还差多少才与它一比一重合。
   （`开发工具/盘配准.py` —— 不挑地标、只认画实的像素，每条都带阳性对照 + 峰尖度自检）

为什么要第②张表（2026-10-13）：用户在编辑器里逐帧切着看说"不飘"，游戏里却说"飘"。
把游戏里那条特效**逐引擎帧采样**量完，结论是玩家节点/相机/光环根全程一个值 ⇒ 不是运行期抖动，
只剩"帧与帧之间本来就没重合"这一条。而原版素材里**第 6、7 帧的盘比第 0 帧偏右下 2/3 像素**
⇒ 这就是他看到的"最后那一两帧动、幅度不大"。⇒ 现在这张表直接告诉他每帧该拖到哪。

⚠ 只读 `.tscn` **文本**，不读运行期值 —— 运行期值是自己算给自己的，等于没验（工程老规矩）。

用法：python 开发工具/读回打坐九帧位.py
退出码：0 = 九帧全在且盘全重合；1 = 有帧缺节点/读不到 position；2 = 有帧的盘不重合。
"""
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
import 盘配准

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
场 = os.path.join(工程, "场景", "角色", "打坐光环.tscn")
表路 = os.path.join(工程, "数据", "界面", "打坐光环.json")


def main():
    表 = json.load(io.open(表路, encoding="utf-8"))
    文 = io.open(场, encoding="utf-8").read()
    写 = 0
    差表 = []
    实表 = {}
    print("① 帧  字面公式(−原点)   场景里的 position     差量(手拖量)        可见")
    for i, 帧 in enumerate(表["帧"]):
        应 = (-int(帧["原点x"]), -int(帧["原点y"]))
        m = re.search(r'\[node name="第%d帧"[^\n]*\n(.*?)(?:\n\[|\Z)' % i, 文, re.S)
        if not m:
            print("第%d帧  场景里查无此节点 ⇒ 重跑 生成打坐九帧场景.py" % i)
            写 += 1
            差表.append((0.0, 0.0))
            continue
        块 = m.group(1)
        p = re.search(r'position = Vector2\(([-\d.]+), ([-\d.]+)\)', 块)
        if not p:
            print("第%d帧  节点没有 position 行（= 停在 (0,0)，一定是错的）" % i)
            写 += 1
            差表.append((0.0, 0.0))
            continue
        实 = (float(p.group(1)), float(p.group(2)))
        实表[i] = 实
        v = re.search(r'visible = (\w+)', 块)
        差 = (实[0] - 应[0], 实[1] - 应[1])
        差表.append((实[0] - 应[0], 实[1] - 应[1]))
        print("%d   (%d,%d)        (%g,%g)          (%+g,%+g)        %s"
              % (i, 应[0], 应[1], 实[0], 实[1], 差[0], 差[1], v.group(1) if v else "true(默认)"))
    动 = []
    for i, 帧 in enumerate(表["帧"]):
        if 差表[i] != (0.0, 0.0):
            动.append("第%d帧(%+g,%+g)" % (i, 差表[i][0], 差表[i][1]))
    print("")
    print("⇒ 差量非 0 的帧：%s" % (动 if 动 else "无（九帧全在字面公式上）"))
    if 写:
        raise SystemExit("%d 帧读不到 ⇒ 场景与帧表不同步" % 写)

    # ── ② 盘重合判据：以第 0 帧那块阵为尺子 ────────────────────────────────
    print("")
    print("② 以第 0 帧的八卦阵为基准，逐帧量「盘还差几像素才一比一重合」")
    print("   （`盘配准.py`：只认画实的像素 alpha>200，±6 搜最小色差，每条带阳性对照 + 峰尖度）")
    量, _ = 盘配准.量全部(工程, 表路, 基准=0)
    if 0 not in 实表:
        print("   !! 读不到第 0 帧的 position ⇒ 这一节判不了")
        return
    # ⚠ 口径（两处踩过坑，都写死在这里）：
    #   ① `应加` 是**叠图里** 顶/左 的量，与 position **反号**（`验盘配准符号.py` 实测：内容往下搬
    #      5 像素、工具的 dy 跟着 +5）⇒ 一律用库算好的 `position修正 = −应加`，别自己拿 应加 去加。
    #   ② 各帧 position 互不相同（= −各帧原点）是"把注册点都摆到角色原点"的**设计结果**，不是错位。
    #      真正的错位 = 素材残余错位 + 注册点落点差，而 落点差 = 手拖_n − 手拖_0
    #      （手拖_i = 场景 position_i − 字面_i = 注册点落在哪）。
    #   拿 `position_n − position_0` 直接比 `应加` 会把原点差（第 1 帧就有 −35,−67）当成盘差，
    #   七帧全报不重合 —— 那是假红，而且红得离谱。
    字面 = {i: (-int(帧["原点x"]), -int(帧["原点y"])) for i, 帧 in enumerate(表["帧"])}
    手拖 = {i: (实表[i][0] - 字面[i][0], 实表[i][1] - 字面[i][1]) for i in 实表}
    不重合 = []
    print("   帧  素材错位(叠图)  注册点落点差   position 该加   结论 / 该拖到的 position    自检")
    for i in sorted(量):
        r = 量[i]
        if i not in 实表:
            print("   %d  查无 position 行" % i)
            不重合.append(i)
            continue
        if r["应加"] is None:
            print("   %d  配准搜不到足够重叠 ⇒ 这一帧的盘不在叠图窗口里" % i)
            不重合.append(i)
            continue
        落 = (手拖[i][0] - 手拖[0][0], 手拖[i][1] - 手拖[0][1])
        该加 = -(r["应加"][0] + 落[0]), -(r["应加"][1] + 落[1])
        标 = "" if r["对照"] else "  !!阳性对照不过 ⇒ 这数不可信"
        if r["峰尖"] < 1.15:
            标 += "  !!峰是平的(%.2f) ⇒ 这数不可信" % r["峰尖"]
        print("   %d  (%+d,%+d)      (%+g,%+g)      (%+g,%+g)     %s%s%s" % (
            i, r["应加"][0], r["应加"][1], 落[0], 落[1], 该加[0], 该加[1],
            "重合" if 该加 == (0, 0) else "不重合 ⇒ 拖到 (%g,%g)" % (
                实表[i][0] + 该加[0], 实表[i][1] + 该加[1]),
            "  ← 基准（尺子）" if r.get("基准") else "", 标))
        if 该加 != (0, 0) and not 标:
            不重合.append(i)
    print("")
    print("   ⇒ 盘还没重合的帧：%s" % (["第%d帧" % i for i in 不重合] if 不重合 else "无（全重合）"))
    if 不重合:
        raise SystemExit(2)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
