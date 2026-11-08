# -*- coding: utf-8 -*-
"""抓「Nya火影世界 - 游戏窗口」的连续录屏器 —— 给「逐帧对照原版」当真值采集端。

为什么截屏幕区域而不是 PrintWindow
--------------------------------
Flash 是 ActiveX 子窗口、走自己的渲染路径，`PrintWindow` 对它经常回一张黑图。
对照真值要的是**玩家看到的那一屏**，所以直接 BitBlt 桌面 DC 上那块矩形 ——
代价是窗口被别的东西盖住时会拍到那个东西，因此每帧顺手记下「这块区域最上面
的窗口是不是游戏窗口」，事后能判哪几帧被污染、该丢。

用法
----
    python 开发工具/录原版窗口.py 开始            # 后台跑，每 --间隔 秒存一帧
    python 开发工具/录原版窗口.py 停
    python 开发工具/录原版窗口.py 单帧 [备注]      # 只拍一张，用来对齐时刻

产物：--出目录（默认 原版实录/<时间戳>/）下的 frame_<序号>_<时刻ms>.png
      + 同名的 index.txt（序号 / 时刻 / 窗口是否在最前 / 客户区尺寸）。
"""
import ctypes
import ctypes.wintypes as W
import io
import json
import os
import sys
import time

sys.stdout.reconfigure(encoding="utf-8")

user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32

SRCCOPY = 0x00CC0000
CAPTUREBLT = 0x40000000
TITLE_MARK = "Nya火影世界"


class RECT(ctypes.Structure):
    _fields_ = [("l", W.LONG), ("t", W.LONG), ("r", W.LONG), ("b", W.LONG)]


class BITMAPINFOHEADER(ctypes.Structure):
    ## ctypes.wintypes 在部分 Python 构建里**不导出** BITMAPINFOHEADER（本机实测），
    ## 自己按 MSDN 摆字段，别指望 import 到。
    _fields_ = [("biSize", W.DWORD), ("biWidth", W.LONG), ("biHeight", W.LONG),
                ("biPlanes", W.WORD), ("biBitCount", W.WORD), ("biCompression", W.DWORD),
                ("biSizeImage", W.DWORD), ("biXPelsPerMeter", W.LONG),
                ("biYPelsPerMeter", W.LONG), ("biClrUsed", W.DWORD),
                ("biClrImportant", W.DWORD)]


def 找游戏窗口():
    命中 = []

    @ctypes.WINFUNCTYPE(W.BOOL, W.HWND, W.LPARAM)
    def 回调(句柄, _):
        if not user32.IsWindowVisible(句柄):
            return True
        n = user32.GetWindowTextLengthW(句柄)
        if n == 0:
            return True
        缓冲 = ctypes.create_unicode_buffer(n + 1)
        user32.GetWindowTextW(句柄, 缓冲, n + 1)
        if TITLE_MARK in 缓冲.value:
            框 = RECT()
            user32.GetWindowRect(句柄, ctypes.byref(框))
            命中.append((句柄, 缓冲.value, 框.l, 框.t, 框.r - 框.l, 框.b - 框.t))
        return True

    user32.EnumWindows(回调, 0)
    return 命中


def 客户区(句柄):
    框 = RECT()
    user32.GetClientRect(句柄, ctypes.byref(框))
    点左 = W.POINT(0, 0)
    点右 = W.POINT(框.r, 框.b)
    user32.ClientToScreen(句柄, ctypes.byref(点左))
    user32.ClientToScreen(句柄, ctypes.byref(点右))
    return 点左.x, 点左.y, 点右.x - 点左.x, 点右.y - 点左.y


def 拍一帧(出目录, 序号, 备注="", 缩宽=960):
    们 = 找游戏窗口()
    if not 们:
        return None, "查无标题含「%s」的可见窗口" % TITLE_MARK
    句柄, 标题, _l, _t, _w, _h = 们[0]
    x, y, w, h = 客户区(句柄)
    if w <= 0 or h <= 0:
        return None, "客户区尺寸 %dx%d 不合法（窗口可能最小化了）" % (w, h)
    屏 = user32.GetDC(0)
    源 = gdi32.CreateCompatibleDC(屏)
    位 = gdi32.CreateCompatibleBitmap(屏, w, h)
    旧 = gdi32.SelectObject(源, 位)
    gdi32.BitBlt(源, 0, 0, w, h, 屏, x, y, SRCCOPY | CAPTUREBLT)
    信息 = BITMAPINFOHEADER()
    信息.biSize = ctypes.sizeof(BITMAPINFOHEADER)
    信息.biWidth, 信息.biHeight = w, -h
    信息.biPlanes, 信息.biBitCount, 信息.biCompression = 1, 24, 0
    容量 = ((w * 3 + 3) // 4) * 4 * h
    缓冲 = ctypes.create_string_buffer(容量)
    得 = gdi32.GetDIBits(源, 位, 0, h, 缓冲, ctypes.byref(信息), 0)
    gdi32.SelectObject(源, 旧)
    gdi32.DeleteObject(位)
    gdi32.DeleteDC(源)
    user32.ReleaseDC(0, 屏)
    if 得 == 0:
        return None, "GetDIBits 失败"
    时刻 = time.time()
    名 = "frame_%04d_%d.png" % (序号, int(时刻 * 1000))
    路 = os.path.join(出目录, 名)
    _写bmp(路, 缓冲, w, h)
    ## 存成舞台宽（默认 960）：原版 Flash 舞台就是 960×560，
    ## 窗口是它的整数倍放大 ⇒ 缩回 960 宽 ≈ 舞台 1:1，一张从 ~5MB 降到 ~1MB，
    ## 连录几分钟才不会把盘写满。
    if 缩宽 and w > 缩宽:
        _缩(路, 缩宽)
    顶 = user32.GetForegroundWindow()
    with io.open(os.path.join(出目录, "index.txt"), "a", encoding="utf-8") as 志:
        志.write("%s\t%.3f\t%dx%d\t最前=%s\t%s\t%s\n" % (
            名, 时刻, w, h, "Y" if 顶 == 句柄 else "N", 标题, 备注))
    return 路, ""


def _缩(路, 宽):
    try:
        from PIL import Image
    except ImportError:
        return
    图 = Image.open(路).convert("RGB")
    图 = 图.resize((宽, max(1, int(round(图.height * 宽 / 图.width)))), Image.LANCZOS)
    图.save(路.replace(".png", "_tmp.png"))
    os.replace(路.replace(".png", "_tmp.png"), 路)


def _写bmp(路, 像素, w, h):
    """把 GetDIBits 的 top-down 缓冲存成 PNG。

    ⚠ 以前这里手拼 BMP 头、`biHeight` 写成**正数**，而缓冲是按 `biHeight = -h`
      （top-down）取的 ⇒ 文件被标成 bottom-up，读出来整张**上下翻转**，
      一次 318 帧的原版实录全废。现在直接用 PIL 的负 stride、不拼头，
      这类错没有藏身处。缓冲是 BGR ⇒ frombuffer 用 "BGR"。
    """
    from PIL import Image
    行 = ((w * 3 + 3) // 4) * 4
    Image.frombuffer("RGB", (w, h), bytes(像素[:行 * h]), "raw", "BGR", 行, -1).save(路)


def 主():
    令 = sys.argv[1] if len(sys.argv) > 1 else "单帧"
    出 = None
    for a in sys.argv[2:]:
        if a.startswith("--出目录="):
            出 = a.split("=", 1)[1]
    if 令 == "列窗口":
        print(json.dumps([{"标题": t, "hwnd": h, "x": x, "y": y, "w": w, "h": hh}
                          for h, t, x, y, w, hh in 找游戏窗口()], ensure_ascii=False, indent=1))
        return
    if 令 == "停":
        标 = os.path.join(出 or _默认出(), "STOP")
        io.open(标, "w").write("1")
        print("已写停止标记", 标)
        return
    if 令 == "单帧":
        备 = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith("--") else "手动"
        目 = 出 or _默认出()
        os.makedirs(目, exist_ok=True)
        路, 错 = 拍一帧(目, 0, 备)
        print(路 or ("失败：" + 错))
        return
    目 = 出 or _默认出()
    os.makedirs(目, exist_ok=True)
    间隔 = 0.5
    缩宽 = 960
    for a in sys.argv[2:]:
        if a.startswith("--间隔="):
            间隔 = float(a.split("=", 1)[1])
        elif a.startswith("--缩宽="):
            缩宽 = int(a.split("=", 1)[1])
    print("开始录制 → %s（间隔 %.2fs，Ctrl+C 或 `停` 结束）" % (目, 间隔), flush=True)
    i = 0
    停标 = os.path.join(目, "STOP")
    while not os.path.exists(停标):
        路, 错 = 拍一帧(目, i, "", 缩宽)
        if 错:
            print("第 %d 帧：%s" % (i, 错), flush=True)
        i += 1
        time.sleep(间隔)
    print("共 %d 帧 → %s" % (i, 目))


def _默认出():
    return os.path.join("原版实录", time.strftime("%Y%m%d-%H%M%S"))


if __name__ == "__main__":
    主()
