# -*- coding: utf-8 -*-
"""把打坐那两批原版素材落到工程里，并生成**帧数据表**（每帧对齐点 + 时长）。

为什么要有这个脚本（而不是手摆图）：
  · 光环那九帧是 `Effect_healNew.swf` 里的 **9 张 DefineBitsJPEG3**（不是 sprite、没有时间轴），
    真正的播放信息在 `GameData.dat` 的 `Etc.effects.healNew`：**每帧各有 origin（注册点）与 delay**。
    第 0 帧 delay=12000（那是常驻的底座光环），1~8 帧各 200 毫秒 ⇒ 一圈 13.6 秒。
  · 九帧**尺寸互不相同**（实测 150×79 ~ 219×199）⇒ 不许拼 `AnimatedTexture`
    （它要求同尺寸，尺寸不齐时采样越界、部分机器上出白块 —— 见 真值/窗口/掉落物.md §4）。
    所以这里**原样落图**，运行期按表逐帧换贴图 + 摆 origin。

跑法：`python 开发工具/落打坐素材.py`（幂等；重跑覆盖成同样内容）
"""
import io
import json
import os
import shutil
import subprocess
import sys

# ⚠ 数据源钉 **2.2.3 优化版**（用户令：按 2.2.3 优化版做，不按分发版）。
# 默认取工程旁的 `2.2.3/`；可用 NARUTO_GAME_ROOT 显式覆盖。
_工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault("NARUTO_GAME_ROOT", os.path.join(_工程, "..", "2.2.3"))

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import 原版数据 as Y
from PIL import Image

工程 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
光环出 = os.path.join(工程, "素材", "特效", "打坐光环")
球出 = os.path.join(工程, "素材", "界面", "打坐四钮")
数据出 = os.path.join(工程, "数据", "界面", "打坐光环.json")
ffdec = r"ffdec\ffdec-cli.exe"
光环swf = os.path.join(Y.原版根, "www", "act_web_nya_208_isolated", "swf", "Effect", "Effect_healNew.swf")
球swf = os.path.join(Y.原版根, "www", "act_web_nya_208_isolated", "swf", "UISwf", "UISwf_ButtonsWindow.swf")


def 导(swf, 出目录, 型="image"):
    if os.path.isdir(出目录):
        shutil.rmtree(出目录)
    os.makedirs(出目录, exist_ok=True)
    subprocess.run([ffdec, "-export", 型, 出目录, swf],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    return [os.path.join(根, f) for 根, _, 名 in os.walk(出目录) for f in 名 if f.lower().endswith(".png")]


def 主():
    for d in (光环出, 球出):
        os.makedirs(d, exist_ok=True)
    效 = Y.解载荷(Y.取顶层段("Etc").get("effects"))
    h = 效["healNew"]
    临时 = os.path.join(os.environ.get("TEMP", "/tmp"), "healnew_raw")
    图 = 导(光环swf, 临时)
    # ffdec 出的是 `<序号>_<类名>.png`，序号是**倒着**的（1_…_8 … 9_…_0）⇒ 按类名里的数字归位
    按类 = {}
    for p in 图:
        名 = os.path.basename(p)
        号 = 名.rsplit("_", 1)[-1].split(".")[0]
        按类[int(号)] = p
    表 = {"出处": "GameData.dat `Etc.effects.healNew`（`Character.as:2742-2765 tickHealAnimation`）",
          "帧": []}
    for 号 in sorted(int(k) for k in h):
        项 = h[str(号)] if str(号) in h else h[号]
        源 = 按类.get(号)
        if 源 is None:
            raise SystemExit("第 %d 帧没导出来（类名 %s）" % (号, 项["value"]["className"]))
        落 = os.path.join(光环出, "打坐光环_%d.png" % 号)
        shutil.copyfile(源, 落)
        尺 = Image.open(落).size
        表["帧"].append({"文件": "res://素材/特效/打坐光环/打坐光环_%d.png" % 号,
                     "类名": 项["value"]["className"],
                     "宽": 尺[0], "高": 尺[1],
                     "原点x": int(项["origin"]["x"]), "原点y": int(项["origin"]["y"]),
                     "停毫秒": int(项["delay"])})
    球 = [p for p in 导(球swf, os.path.join(os.environ.get("TEMP", "/tmp"), "ball_raw"), "sprite")
          if "ButtonsWindow_Btn" in os.path.basename(os.path.dirname(p))]
    if not 球:
        raise SystemExit("UISwf_ButtonsWindow_Btn 没导出来")
    原 = Image.open(球[0])
    尺 = 原.size
    # ⚠ **ffdec 导出来的是"美术包围盒"，不是"注册点画布"**：这张 43x37 里左右各 3 像素是全透边，
    #   真正的圆只有 37x37。按画布左上角贴 ⇒ 球往右 3 像素，而字是**按 37 宽的命中框居中**的
    #   （`MButton3.as:434` `tf.x = (_width - tf.width)/2`，`btn_width_two = 37`）
    #   ⇒ 球心比字心右 3 像素。用户 10-12 夜先说"字歪"再说"球整体往右"，就是这一条。
    #   拿他给的原版实拍量过：原版球心与字心只差 0.7~1.7 像素（=同一个点）。
    #   ⇒ 裁掉透明边存成 37x37，让"球心 = 字心 = 命中框中心"三者重合。
    包 = 原.getchannel("A").getbbox()
    裁 = 原.crop(包) if 包 else 原
    if 裁.size != (37, 37):
        raise SystemExit("球皮裁完是 %s，不是预期的 37x37（透明边结构和推断不一样，别硬用）" % (裁.size,))
    裁.save(os.path.join(球出, "球钮.png"))
    尺 = 裁.size
    表["球皮"] = {"文件": "res://素材/界面/打坐四钮/球钮.png", "宽": 尺[0], "高": 尺[1],
               "出处": "UISwf_ButtonsWindow.swf 符号 6 `UISwf_ButtonsWindow_Btn`（ButtonsWindow.as:88-102）；"
                       "ffdec 原始画布 %dx%d、透明边包围盒 %s ⇒ 裁成 37x37" % (尺[0], 尺[1], 包)}
    io.open(数据出, "w", encoding="utf-8").write(json.dumps(表, ensure_ascii=False, indent=1))
    print("光环 %d 帧（一圈 %d 毫秒）+ 球皮 %s → %s" % (
        len(表["帧"]), sum(f["停毫秒"] for f in 表["帧"]), 尺, 数据出))
    for f in 表["帧"]:
        print("  %s origin=(%d,%d) delay=%d 尺寸=%dx%d" % (
            os.path.basename(f["文件"]), f["原点x"], f["原点y"], f["停毫秒"], f["宽"], f["高"]))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    主()
